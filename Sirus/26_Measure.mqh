//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 26_Measure                                      |
//| Stage 12: profiler + shadow ledger (measure before tuning)       |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// STAGE 12 (plan section 13): MEASURE FIRST
//---------------------------------------------------------------------
// Every later stage claims "more trades" or "fewer wrong-way entries" or "faster". These two
// instruments turn the claims into numbers.
//
// PROFILER   microseconds per tick, split by pipeline segment (Market Brain engines, the legacy
//            scanner, the guards, grid, entry, post-entry packs, panel). An average and a peak.
//            The panel footer shows the total and the heaviest segment; the journal gets an
//            hourly line.
//
// SHADOW     every refused setup with a direction is followed in the shadows, as if it had been
//            taken: does price reach the first-entry TP first (TP), or the first grid step first
//            (GRID - the basket would have needed averaging), or neither within the time limit
//            (TIMEOUT)? Each one is filed under the gate that refused it. Entries that were
//            really taken are followed the same way (TAKEN), so every gate can be compared with
//            the trades that got through:
//              gate's blocked setups reach TP far MORE often than taken ones -> it blocks good
//              trades (a candidate to loosen); far LESS often -> it earns its place.
//            One shadow per direction per M1 bar - a thousand refused ticks are one decision.
//            Nothing here touches trading.
//=====================================================================

input group "DIAGNOSTICS ▸ Profiler & shadow ledger"
// EnableProfiler: Har tik necha ms ketishini o'lchash (panelda va jurnalda)
input bool   EnableProfiler           = true;   // Enable profiler
// EnableShadowLedger: Rad etilgan setuplarni yashirin kuzatish: TP ga yetardimi yoki grid kerak bo'lardimi
input bool   EnableShadowLedger       = true;   // Enable shadow ledger
// ShadowMaxMinutes: Soya shuncha daqiqada natija bermasa - TIMEOUT
input int    ShadowMaxMinutes         = 30;   // Shadow max minutes
// ShadowToFile: Har natijani CSV ga yozish (Sirus_Shadow_<symbol>_<magic>.csv)
input bool   ShadowToFile             = true;   // Shadow to file (on/off)
// ShadowMinSamplesToJudge: Filtr bo'yicha xulosa uchun kamida shuncha natija
input int    ShadowMinSamplesToJudge  = 10;   // Shadow min samples to judge
// EnableShadowValve: SOYA KLAPANI: biror sifat filtri to'sgan setuplar olinganlardan ancha ko'p TP ga yetsa (>= ShadowValveMinSamples namuna), o'sha filtr vaqtincha yumshaydi. Risk / yangilik / spread / marja / yo'nalish veto'si HECH QACHON yumshamaydi
input bool   EnableShadowValve        = true;   // Enable shadow valve
// ShadowValveMinutes: Yumshatish shuncha daqiqa, keyin yangi dalil bilan qayta baholanadi
input int    ShadowValveMinutes       = 30;   // Shadow valve minutes
// ShadowValveMinSamples: Qaror uchun shu filtr bo'yicha kamida shuncha natija
input int    ShadowValveMinSamples    = 10;   // Shadow valve min samples
// EnableTempoValve: SMART TEMPO - switches on only when it is needed and the market allows it: the EA has been quiet, the setups it refused on the direction-safe side were CLEAN (TP without a deep move against) at least as often as the trades it took, and there is no news / spike / anomaly / wide spread. It then relaxes the timing / quality gates (score, judge, location, late / taken target, drift) for the direction-safe side only. If its own baskets start needing the grid, the circuit breaker turns it off. Direction gates never relax.
input bool   EnableTempoValve         = true;   // SMART TEMPO valve (restores trade flow only when it is needed)
input int    TempoQuietMinutes        = 10;   // TEMPO: quiet minutes before it may switch on (0 = whenever the evidence holds)
input int    TempoMinRefusals         = 10;   // TEMPO: recent refused direction-safe setups needed as evidence
input int    TempoCleanMAEPts         = 1500;   // TEMPO: "clean" = TP reached with the move against below this (points)
input double TempoMinCleanRate        = 0.72;   // TEMPO: refused setups must be clean at least this often ...
input double TempoCleanEdge           = 0.03;   // ... and this much more often than the trades taken
input int    TempoMinutes             = 20;   // TEMPO: how long one activation lasts
input int    TempoBreakerGridBaskets  = 2;   // TEMPO breaker: this many of its last 4 baskets needed the grid ...
input int    TempoBreakerMinutes      = 60;   // ... switches it off for this long
// EnableDailyReport: 18-BOSQICH (B6): kun yakunida bitta qator - savdolar, lot, natija, soya, LIVE SWEEP, veto, tezlik (Sirus_DailyReport_<symbol>_<magic>.csv)
input bool   EnableDailyReport        = true;   // Enable daily report

//---------------------------------------------------------------------
// PROFILER
//---------------------------------------------------------------------
ulong  G_PROF_START[MB_PROF_SEGS];
double G_PROF_AVG[MB_PROF_SEGS];      // exponential average, microseconds
ulong  G_PROF_PEAK[MB_PROF_SEGS];     // highest single reading this hour
ulong  G_PROF_N[MB_PROF_SEGS];
datetime G_PROF_HOUR = 0;

string MBProfName(const int seg)
{
   switch(seg)
   {
      case MB_PROF_TICK:    return "tick";
      case MB_PROF_PRE:     return "pre";
      case MB_PROF_BRAIN:   return "brain";
      case MB_PROF_SCAN:    return "scanner";
      case MB_PROF_GUARDS:  return "guards";
      case MB_PROF_GRID:    return "grid";
      case MB_PROF_ENTRY:   return "entry";
      case MB_PROF_POST:    return "post";
      case MB_PROF_PANEL:   return "panel";
      case MB_PROF_SHADOW:  return "shadow";
   }
   return "?";
}

string MBProfNameUz(const int seg)
{
   switch(seg)
   {
      case MB_PROF_PRE:     return "tayyorlov";
      case MB_PROF_BRAIN:   return "miya";
      case MB_PROF_SCAN:    return "skaner";
      case MB_PROF_GUARDS:  return "himoyalar";
      case MB_PROF_GRID:    return "grid";
      case MB_PROF_ENTRY:   return "kirish";
      case MB_PROF_POST:    return "post";
      case MB_PROF_SHADOW:  return "soya";
   }
   return MBProfName(seg);
}

void MBProfBegin(const int seg)
{
   if(!EnableProfiler || seg < 0 || seg >= MB_PROF_SEGS)
      return;
   G_PROF_START[seg] = GetMicrosecondCount();
}

void MBProfEnd(const int seg)
{
   if(!EnableProfiler || seg < 0 || seg >= MB_PROF_SEGS || G_PROF_START[seg] == 0)
      return;
   if(G_TICK_COUNT == 0)   // OnInit's pass replays history - not a tick
   {
      G_PROF_START[seg] = 0;
      return;
   }
   ulong us = GetMicrosecondCount() - G_PROF_START[seg];
   G_PROF_START[seg] = 0;
   G_PROF_N[seg]++;
   double k = (G_PROF_N[seg] < 50) ? 1.0 / (double)G_PROF_N[seg] : 0.02;
   G_PROF_AVG[seg] += k * ((double)us - G_PROF_AVG[seg]);
   if(us > G_PROF_PEAK[seg])
      G_PROF_PEAK[seg] = us;

   // Hourly journal line, then the peaks start again.
   if(seg == MB_PROF_TICK)
   {
      long now_s = (long)TimeCurrent();
      datetime hour = (datetime)(now_s - now_s % 3600);
      if(G_PROF_HOUR == 0)
         G_PROF_HOUR = hour;
      else if(hour != G_PROF_HOUR)
      {
         G_PROF_HOUR = hour;
         if(VerboseLogs)
         {
            string t = "";
            for(int i = 0; i < MB_PROF_SEGS; i++)
               t += StringFormat("%s %.2f/%.1f ms  ", MBProfName(i), G_PROF_AVG[i] / 1000.0, G_PROF_PEAK[i] / 1000.0);
            PrintFormat("[SIRUS PROF] avg/peak per segment: %s", t);
         }
         for(int i = 0; i < MB_PROF_SEGS; i++)
            G_PROF_PEAK[i] = 0;
      }
   }
}

// Panel footer text: "tik 1.8 ms (eng ko'p 12.0) · og'iri: skaner 1.1 ms".
// PERFORMANCE CONTRACT: a tick averaging over 30 ms is a regression - the panel line turns amber.
bool MBProfSlow()
{
   return (EnableProfiler && G_PROF_N[MB_PROF_TICK] > 0 && G_PROF_AVG[MB_PROF_TICK] > 30000.0);
}

string MBProfText()
{
   if(!EnableProfiler || G_PROF_N[MB_PROF_TICK] == 0)
      return "";
   int heavy = -1;
   for(int i = MB_PROF_PRE; i < MB_PROF_SEGS; i++)
   {
      if(i == MB_PROF_PANEL) continue;
      if(heavy < 0 || G_PROF_AVG[i] > G_PROF_AVG[heavy]) heavy = i;
   }
   string t = StringFormat("tik %.2f ms (eng ko'p %.1f)", G_PROF_AVG[MB_PROF_TICK] / 1000.0, G_PROF_PEAK[MB_PROF_TICK] / 1000.0);
   if(heavy >= 0)
      t += StringFormat(" · og'iri: %s %.2f", MBProfNameUz(heavy), G_PROF_AVG[heavy] / 1000.0);
   if(G_PROF_N[MB_PROF_PANEL] > 0)
      t += StringFormat(" · panel %.1f", G_PROF_AVG[MB_PROF_PANEL] / 1000.0);
   if(EnableScannerThrottle && G_SCAN_RUNS + G_SCAN_SKIPPED > 0)
      t += StringFormat(" · skaner %.0f%% tikda", 100.0 * G_SCAN_RUNS / (G_SCAN_RUNS + G_SCAN_SKIPPED));
   return t;
}

//---------------------------------------------------------------------
// SHADOW LEDGER
//---------------------------------------------------------------------
#define MB_SH_MAX        256
#define MB_SH_TAKEN      GATE_COUNT          // tally slot for entries that were really taken
#define MB_SH_SLOTS      (GATE_COUNT + 1)
#define MB_SH_TP         0
#define MB_SH_GRID       1
#define MB_SH_TIMEOUT    2

struct SMBShadow
{
   bool     active;
   datetime t;
   int      dir;
   int      gate;
   double   entry;
   double   tp_px;
   double   adv_px;
   double   mfe;       // best excursion, price units
   double   mae;       // worst excursion, price units
   bool     safe;      // direction-safe side when it was refused (TEMPO evidence)
};

SMBShadow G_SH[MB_SH_MAX];
int       G_SH_NEXT = 0;
int       G_SH_TALLY[MB_SH_SLOTS][3];   // today's results per gate: TP / GRID / TIMEOUT
int       G_SH_DAY = -1;
int       G_SH_LAST_BAR[2] = {-100000, -100000};
int       G_SH_ACTIVE = 0;      // SPEED: live shadows - the per-tick loop is skipped when none
string    G_SH_BUF = "";        // SPEED: CSV rows waiting for the once-a-minute flush
// Shadow valve state: blocked results per gate since its last decision, taken results, and the
// time each gate's relaxation ends.
int       G_SV_N[GATE_COUNT];
int       G_SV_TP[GATE_COUNT];
int       G_SV_TN = 0, G_SV_TTP = 0;
datetime  G_SV_UNTIL[GATE_COUNT];
datetime  G_SH_FLUSH_BAR = 0;

string MBShadowGateName(const int g)
{
   if(g == MB_SH_TAKEN) return "TAKEN";
   if(g <= GATE_NONE || g >= GATE_COUNT) return "other";
   return GateName(g);
}

string MBShadowGateUz(const int g)
{
   if(g == MB_SH_TAKEN) return "olingan";
   if(g <= GATE_NONE || g >= GATE_COUNT) return "boshqa";
   return MBGateUz(g);
}

// Rows are buffered and written once per M1 bar (and on deinit) - a fast move can resolve dozens of
// shadows on one tick, and a file open per row is milliseconds of I/O inside that tick.
void MBShadowFlush()
{
   if(StringLen(G_SH_BUF) == 0)
      return;
   string name = StringFormat("Sirus_Shadow_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) == 0)
      FileWriteString(h, "time;resolved;gate;dir;entry;tp;grid_step;outcome;minutes;mfe_pts;mae_pts;brain_bias;extra\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, G_SH_BUF);
   FileClose(h);
   G_SH_BUF = "";
}

void MBShadowCsv(const SMBShadow &s, const int outcome, const string extra)
{
   if(!ShadowToFile || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   string oc = (outcome == MB_SH_TP) ? "TP" : ((outcome == MB_SH_GRID) ? "GRID" : ((outcome == MB_SH_TIMEOUT) ? "TIMEOUT" : "SUMMARY"));
   G_SH_BUF += StringFormat("%s;%s;%s;%s;%s;%s;%s;%s;%d;%.0f;%.0f;%d;%s\r\n",
                                   TimeToString(s.t, TIME_DATE | TIME_SECONDS), TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                   MBShadowGateName(s.gate), (s.dir > 0 ? "BUY" : (s.dir < 0 ? "SELL" : "-")),
                                   DoubleToString(s.entry, _Digits), DoubleToString(s.tp_px, _Digits), DoubleToString(s.adv_px, _Digits),
                                   oc, (int)((TimeCurrent() - s.t) / 60), s.mfe / _Point, s.mae / _Point, G_MB_BIAS, extra);
   if(StringLen(G_SH_BUF) > 60000)
      MBShadowFlush();
}

// TP share of one tally slot, -1 when there is nothing to judge.
double MBShadowTPRate(const int g, int &n)
{
   n = G_SH_TALLY[g][MB_SH_TP] + G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
   if(n <= 0) return -1.0;
   return (double)G_SH_TALLY[g][MB_SH_TP] / (double)n;
}

// Day summary into the journal and the CSV, then the tallies start again.
void MBShadowDaySummary()
{
   int tn = 0;
   double taken = MBShadowTPRate(MB_SH_TAKEN, tn);
   string t = StringFormat("taken %d TP %.0f%%", tn, MathMax(0.0, taken) * 100.0);
   int blocked = 0;
   for(int g = 0; g < GATE_COUNT; g++)
   {
      int n = 0;
      double r = MBShadowTPRate(g, n);
      if(n <= 0) continue;
      blocked += n;
      string flag = "";
      if(n >= ShadowMinSamplesToJudge && tn >= ShadowMinSamplesToJudge)
      {
         if(r >= taken + 0.10) flag = " BLOCKS-GOOD";
         else if(r <= taken - 0.10) flag = " EARNS-ITS-PLACE";
      }
      t += StringFormat(" | %s %d TP %.0f%% grid %d%s", MBShadowGateName(g), n, r * 100.0, G_SH_TALLY[g][MB_SH_GRID], flag);
      if(ShadowToFile)
      {
         SMBShadow s;
         ZeroMemory(s);
         s.t = TimeCurrent();
         s.gate = g;
         MBShadowCsv(s, -1, StringFormat("day n=%d tp=%d grid=%d timeout=%d%s", n, G_SH_TALLY[g][MB_SH_TP],
                                         G_SH_TALLY[g][MB_SH_GRID], G_SH_TALLY[g][MB_SH_TIMEOUT], flag));
      }
   }
   if(tn + blocked > 0)
      PrintFormat("[SIRUS SHADOW DAY] %s", t);
}

void MBShadowDayRoll()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(G_SH_DAY == dt.day_of_year)
      return;
   MBDailyReportCheck();   // AUDIT FIX: the day report reads the shadow tallies - write it before they reset
   if(G_SH_DAY >= 0)
      MBShadowDaySummary();
   G_SH_DAY = dt.day_of_year;
   for(int g = 0; g < MB_SH_SLOTS; g++)
      for(int o = 0; o < 3; o++)
         G_SH_TALLY[g][o] = 0;
}

void MBShadowAdd(const int dir, const int gate, const double entry)
{
   double tp_pts = BaseBasketTPPoints();
   double adv_pts = MathMax(AutoGridBaseDistance(), AutoGridMinDistance());
   if(dir == 0 || entry <= 0.0 || tp_pts <= 0.0 || adv_pts <= 0.0)
      return;
   int k = G_SH_NEXT;
   G_SH_NEXT = (G_SH_NEXT + 1) % MB_SH_MAX;
   if(!G_SH[k].active)
      G_SH_ACTIVE++;          // overwriting a live slot keeps the count unchanged
   G_SH[k].active = true;
   G_SH[k].t = TimeCurrent();
   G_SH[k].dir = dir;
   G_SH[k].gate = gate;
   G_SH[k].entry = entry;
   G_SH[k].tp_px = entry + dir * tp_pts * _Point;
   G_SH[k].adv_px = entry - dir * adv_pts * _Point;
   G_SH[k].mfe = 0.0;
   G_SH[k].mae = 0.0;
   G_SH[k].safe = MBDirSafe(dir);
}

//---------------------------------------------------------------------
// STAGE 18 (B6): DAILY REPORT - one CSV line per finished day, so tuning reads numbers, not memory.
//---------------------------------------------------------------------
datetime G_DR_DAY0      = 0;
int      G_DR_LSW_BASE  = 0;
int      G_DR_VETO_BASE = 0;

datetime MBDayStart(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return t - (dt.hour * 3600 + dt.min * 60 + dt.sec);
}

void MBDailyReportWrite(const datetime from, const datetime to)
{
   int entries = 0, wins = 0, losses = 0;
   double lots = 0.0, net = 0.0;
   if(HistorySelect(from, to))
   {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(d, DEAL_MAGIC) != MagicNumber) continue;
         ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
         if(en == DEAL_ENTRY_IN)
         {
            entries++;
            lots += HistoryDealGetDouble(d, DEAL_VOLUME);
         }
         else
         {
            double p = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
            net += p;
            if(p > 0.0) wins++; else if(p < 0.0) losses++;
         }
      }
   }
   int bn = 0, btp = 0;
   for(int g = 0; g < GATE_COUNT; g++)
   {
      bn += G_SH_TALLY[g][MB_SH_TP] + G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
      btp += G_SH_TALLY[g][MB_SH_TP];
   }
   int tn = 0;
   double ttp = MBShadowTPRate(MB_SH_TAKEN, tn);
   int lsw = G_MB_LSW_COUNT - G_DR_LSW_BASE;
   int vet = G_MB_VETO_COUNT - G_DR_VETO_BASE;
   G_DR_LSW_BASE = G_MB_LSW_COUNT;
   G_DR_VETO_BASE = G_MB_VETO_COUNT;

   string row = StringFormat("%s;%d;%.2f;%.2f;%d;%d;%d;%.0f;%d;%.0f;%d;%d;%.2f",
                             TimeToString(from, TIME_DATE), entries, lots, net, wins, losses,
                             bn, (bn > 0 ? 100.0 * btp / bn : 0.0), tn, MathMax(0.0, ttp) * 100.0,
                             lsw, vet, G_PROF_AVG[MB_PROF_TICK] / 1000.0);
   PrintFormat("[SIRUS DAY REPORT] %s | entries %d lots %.2f net %.2f (+%d/-%d) | shadow blocked %d TP %.0f%% taken %d TP %.0f%% | live sweeps %d | vetoes %d | tick %.2f ms",
               TimeToString(from, TIME_DATE), entries, lots, net, wins, losses, bn, (bn > 0 ? 100.0 * btp / bn : 0.0),
               tn, MathMax(0.0, ttp) * 100.0, lsw, vet, G_PROF_AVG[MB_PROF_TICK] / 1000.0);
   string name = StringFormat("Sirus_DailyReport_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) == 0)
      FileWriteString(h, "date;entries;lots;net;win_closes;loss_closes;shadow_blocked;shadow_blocked_tp_pct;shadow_taken;shadow_taken_tp_pct;live_sweeps;vetoes;tick_ms\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, row + "\r\n");
   FileClose(h);
}

// Called every tick before the shadow tallies roll over, so the day's shadow numbers are still there.
void MBDailyReportCheck()
{
   if(!EnableDailyReport)
      return;
   datetime day0 = MBDayStart(TimeCurrent());
   if(G_DR_DAY0 == 0)
   {
      G_DR_DAY0 = day0;
      G_DR_LSW_BASE = G_MB_LSW_COUNT;
      G_DR_VETO_BASE = G_MB_VETO_COUNT;
      return;
   }
   if(day0 == G_DR_DAY0)
      return;
   MBDailyReportWrite(G_DR_DAY0, day0);
   G_DR_DAY0 = day0;
}

// A refusal: one shadow per direction per M1 bar, filed under the gate that said no.
void MBShadowOnDecision(const bool ready, const string reason)
{
   if(!EnableShadowLedger || ready || G_BASKET_ORDERS > 0)
      return;
   int dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
   if(dir == 0)
      return;
   int gate = GateClassify(reason);
   if(gate == GATE_POSITIONS)
      return;
   int sl = (dir > 0) ? 0 : 1;
   if(G_SH_LAST_BAR[sl] > G_BARS_SEEN) G_SH_LAST_BAR[sl] = -100000;   // re-init rewinds the bar count
   if(G_SH_LAST_BAR[sl] == G_BARS_SEEN)
      return;
   G_SH_LAST_BAR[sl] = G_BARS_SEEN;
   MBShadowDayRoll();
   MBShadowAdd(dir, gate, SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID)));
}

// A real first entry, followed the same way for the comparison.
void MBShadowOnEntry(const int dir, const double price)
{
   if(!EnableShadowLedger)
      return;
   MBShadowDayRoll();
   MBShadowAdd(dir, MB_SH_TAKEN, price);
}

//---------------------------------------------------------------------
// SHADOW VALVE (E): the robot corrects its own over-strict gate, on numbers
//---------------------------------------------------------------------
// Only quality gates can relax: the detector score, the location / zone / HTF-regime family and the
// Entry Judge. A gate relaxes when its refused setups reached TP 15 points more often than the trades
// that were taken (or than 55% while there are fewer than 10 taken) and at least 70% of the time,
// over ShadowValveMinSamples results. It relaxes for ShadowValveMinutes, then needs fresh evidence.
bool MBShadowValveEligible(const int g)
{
   return (g == GATE_SCORE || g == GATE_LOCATION || g == GATE_ZONE || g == GATE_REGIME || g == GATE_MBJUDGE);
}

bool MBShadowValveOn(const int g)
{
   if(g <= GATE_NONE || g >= GATE_COUNT)
      return false;
   // TEMPO relaxes every quality gate at once - for the side being judged, and only if it is direction-safe.
   if(EnableTempoValve && MBShadowValveEligible(g))
   {
      int od = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(MBTempoOnFor(od))
         return true;
   }
   if(!EnableShadowValve)
      return false;
   return (TimeCurrent() < G_SV_UNTIL[g]);
}

// SMART TEMPO, every tick (a few comparisons):
//  1. MARKET  no news window, no tick-velocity pause, no anomaly, spread within 1.5x this hour's normal -
//             otherwise TEMPO does nothing at all, even while "on".
//  2. BREAKER TempoBreakerGridBaskets of its last four baskets needed the grid -> off TempoBreakerMinutes.
//  3. NEED    quiet for TempoQuietMinutes (no basket, no entry) ...
//  4. PROOF   ... and the recent direction-safe refusals were clean (TP without going TempoCleanMAEPts
//             deep) at least TempoMinCleanRate of the time and TempoCleanEdge more often than the
//             trades taken. The owner's files: taken 69% clean, refused direction-safe 76%.
void MBTempoCheck()
{
   static datetime tempo_t0 = 0;
   if(tempo_t0 == 0)
      tempo_t0 = TimeCurrent();
   if(!EnableTempoValve)
   {
      G_TEMPO_UNTIL = 0;
      G_TEMPO_MKT_OK = false;
      return;
   }
   // 1. Market.
   string an = "";
   double norm = MBNormalSpread();
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   G_TEMPO_MKT_OK = !(EnableEconomicCalendarGuard && G_CAL_ACTIVE) &&
                    TimeCurrent() > G_VEL_BLOCK_UNTIL &&
                    !MBAnomalyBlocks(an) &&
                    !(norm > 0.0 && spr > 1.5 * norm);
   // The open TEMPO basket's depth (the breaker reads it at the close).
   if(G_TEMPO_BASKET && G_BASKET_ORDERS > G_TEMPO_BASKET_MAXORD)
      G_TEMPO_BASKET_MAXORD = G_BASKET_ORDERS;
   if(TimeCurrent() < G_TEMPO_BREAK_UNTIL || TimeCurrent() < G_TEMPO_UNTIL || G_BASKET_ORDERS > 0)
      return;
   // 3. Need.
   datetime last = MathMax(G_LAST_ENTRY_TIME, tempo_t0);
   if(TempoQuietMinutes > 0 && TimeCurrent() - last < (long)TempoQuietMinutes * 60)
      return;
   // 4. Proof.
   if(G_TEMPO_N < MathMax(3, TempoMinRefusals))
      return;
   double rate = (double)G_TEMPO_C / G_TEMPO_N;
   double base = (G_TEMPO_TK_N >= 10) ? (double)G_TEMPO_TK_C / G_TEMPO_TK_N : TempoMinCleanRate - TempoCleanEdge;
   if(rate < TempoMinCleanRate || rate < base + TempoCleanEdge)
      return;
   if(!G_TEMPO_MKT_OK)
      return;
   G_TEMPO_UNTIL = TimeCurrent() + MathMax(1, TempoMinutes) * 60;
   PrintFormat("[SIRUS TEMPO] on for %d min: quiet %d min, direction-safe refusals clean %.0f%% vs taken %.0f%% (n=%d) - timing / quality gates relaxed for the direction-safe side",
               TempoMinutes, (int)((TimeCurrent() - last) / 60), rate * 100.0, base * 100.0, G_TEMPO_N);
   G_TEMPO_N = 0;
   G_TEMPO_C = 0;
}

// Evidence, at every shadow's resolution.
void MBTempoFeed(const int g, const int outcome, const double mae_pts, const bool safe)
{
   bool clean = (outcome == MB_SH_TP && mae_pts < (double)MathMax(1, TempoCleanMAEPts));
   if(g == MB_SH_TAKEN)
   {
      G_TEMPO_TK_N++;
      if(clean) G_TEMPO_TK_C++;
      if(G_TEMPO_TK_N >= 40) { G_TEMPO_TK_N /= 2; G_TEMPO_TK_C /= 2; }
      return;
   }
   if(g <= GATE_NONE || g >= GATE_COUNT || !safe)
      return;
   G_TEMPO_N++;
   if(clean) G_TEMPO_C++;
   if(G_TEMPO_N >= 40) { G_TEMPO_N /= 2; G_TEMPO_C /= 2; }
}

// Circuit breaker: called when a basket ends. A TEMPO basket that needed the grid counts against it.
void MBTempoBasketClosed()
{
   if(!G_TEMPO_BASKET)
      return;
   G_TEMPO_HIST[G_TEMPO_HIST_POS] = (G_TEMPO_BASKET_MAXORD >= 2) ? 1 : 0;
   G_TEMPO_HIST_POS = (G_TEMPO_HIST_POS + 1) % 4;
   G_TEMPO_BASKET = false;
   G_TEMPO_BASKET_MAXORD = 0;
   int bad = 0;
   for(int i = 0; i < 4; i++)
      if(G_TEMPO_HIST[i] == 1) bad++;
   if(EnableTempoValve && bad >= MathMax(1, TempoBreakerGridBaskets))
   {
      G_TEMPO_BREAK_UNTIL = TimeCurrent() + MathMax(1, TempoBreakerMinutes) * 60;
      G_TEMPO_UNTIL = 0;
      G_TEMPO_BREAK_WHY = StringFormat("%d of its last 4 baskets needed the grid", bad);
      for(int i = 0; i < 4; i++) G_TEMPO_HIST[i] = -1;
      PrintFormat("[SIRUS TEMPO] BREAKER: %s - TEMPO off for %d min", G_TEMPO_BREAK_WHY, TempoBreakerMinutes);
   }
}

void MBShadowValveFeed(const int g, const int outcome)
{
   if(!EnableShadowValve)
      return;
   if(g == MB_SH_TAKEN)
   {
      G_SV_TN++;
      if(outcome == MB_SH_TP) G_SV_TTP++;
      if(G_SV_TN >= 60) { G_SV_TN /= 2; G_SV_TTP /= 2; }   // keep it recent
      return;
   }
   if(g <= GATE_NONE || g >= GATE_COUNT || !MBShadowValveEligible(g))
      return;
   G_SV_N[g]++;
   if(outcome == MB_SH_TP) G_SV_TP[g]++;
   int need = MathMax(5, ShadowValveMinSamples);
   if(G_SV_N[g] < need || TimeCurrent() < G_SV_UNTIL[g])
      return;
   double rate = (double)G_SV_TP[g] / G_SV_N[g];
   double base = (G_SV_TN >= 10) ? (double)G_SV_TTP / G_SV_TN : 0.55;
   if(rate >= base + 0.15 && rate >= 0.70)
   {
      G_SV_UNTIL[g] = TimeCurrent() + MathMax(1, ShadowValveMinutes) * 60;
      if(VerboseLogs)
         PrintFormat("[SIRUS SHADOW VALVE] %s relaxed %d min: its refusals reached TP %.0f%% vs %.0f%% (n=%d)",
                     GateName(g), ShadowValveMinutes, rate * 100.0, base * 100.0, G_SV_N[g]);
      G_SV_N[g] = 0;
      G_SV_TP[g] = 0;
   }
   else if(G_SV_N[g] >= 2 * need)
   {
      G_SV_N[g] /= 2;
      G_SV_TP[g] /= 2;
   }
}

string MBShadowValveText()
{
   string t = "";
   for(int g = 1; g < GATE_COUNT; g++)
      if(MBShadowValveOn(g))
         t += StringFormat("%s%s %d daq", (StringLen(t) > 0 ? ", " : ""), MBGateUz(g), (int)((G_SV_UNTIL[g] - TimeCurrent()) / 60));
   return t;
}

// Every tick: resolve the shadows price has decided.
void MBShadowUpdate()
{
   MBDailyReportCheck();   // stage 18 (B6) - before the shadow tallies roll over
   if(!EnableShadowLedger)
      return;
   MBShadowDayRoll();
   MBTempoCheck();   // TEMPO valve (a few comparisons)
   datetime fb = iTime(_Symbol, PERIOD_M1, 0);
   if(fb != G_SH_FLUSH_BAR)
   {
      G_SH_FLUSH_BAR = fb;
      MBShadowFlush();
   }
   if(G_SH_ACTIVE <= 0)
      return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;
   long max_age = (long)MathMax(1, ShadowMaxMinutes) * 60;
   for(int i = 0; i < MB_SH_MAX; i++)
   {
      if(!G_SH[i].active)
         continue;
      // A BUY is closed on the bid, a SELL on the ask.
      double px = (G_SH[i].dir > 0) ? bid : ask;
      double move = G_SH[i].dir * (px - G_SH[i].entry);
      if(move > G_SH[i].mfe) G_SH[i].mfe = move;
      if(-move > G_SH[i].mae) G_SH[i].mae = -move;

      int outcome = -1;
      if(G_SH[i].dir > 0 ? (px >= G_SH[i].tp_px) : (px <= G_SH[i].tp_px))
         outcome = MB_SH_TP;
      else if(G_SH[i].dir > 0 ? (px <= G_SH[i].adv_px) : (px >= G_SH[i].adv_px))
         outcome = MB_SH_GRID;
      else if((TimeCurrent() - G_SH[i].t) > max_age)
         outcome = MB_SH_TIMEOUT;
      if(outcome < 0)
         continue;

      int g = MathMax(0, MathMin(MB_SH_SLOTS - 1, G_SH[i].gate));
      G_SH_TALLY[g][outcome]++;
      MBShadowValveFeed(G_SH[i].gate, outcome);
      MBTempoFeed(G_SH[i].gate, outcome, G_SH[i].mae / _Point, G_SH[i].safe);
      MBShadowCsv(G_SH[i], outcome, "");
      G_SH[i].active = false;
      G_SH_ACTIVE = MathMax(0, G_SH_ACTIVE - 1);
   }
}

// Panel line: what the refused setups would have done, against what the taken ones did, and the
// gate whose refusals look best (the first suspect when the robot is too quiet).
string MBShadowPanelText()
{
   if(!EnableShadowLedger)
      return "";
   int bn = 0, tn = 0;
   int b_tp = 0;
   for(int g = 0; g < GATE_COUNT; g++)
   {
      bn += G_SH_TALLY[g][MB_SH_TP] + G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
      b_tp += G_SH_TALLY[g][MB_SH_TP];
   }
   double taken = MBShadowTPRate(MB_SH_TAKEN, tn);
   if(bn + tn == 0)
      return "Soya: hali natija yo'q";
   string t = StringFormat("Soya: to'silgan %d → TP %.0f%%  ·  olingan %d → TP %.0f%%",
                           bn, (bn > 0 ? 100.0 * b_tp / bn : 0.0), tn, MathMax(0.0, taken) * 100.0);
   // The gate whose refusals reached TP most often, once it has enough samples.
   int best = -1;
   double best_r = -1.0;
   for(int g = 0; g < GATE_COUNT; g++)
   {
      int n = 0;
      double r = MBShadowTPRate(g, n);
      if(n >= ShadowMinSamplesToJudge && r > best_r) { best_r = r; best = g; }
   }
   if(best >= 0 && tn >= ShadowMinSamplesToJudge && best_r >= taken + 0.10)
      t += StringFormat("  ·  ⚠ %s yaxshisini to'smoqda (%.0f%%)", MBShadowGateUz(best), best_r * 100.0);
   if(EnableTempoValve && TimeCurrent() < G_TEMPO_BREAK_UNTIL)
      t += StringFormat("  ·  TEMPO to'xtatildi %d daq (%s)", (int)((G_TEMPO_BREAK_UNTIL - TimeCurrent()) / 60) + 1, G_TEMPO_BREAK_WHY);
   else if(EnableTempoValve && TimeCurrent() < G_TEMPO_UNTIL)
      t += StringFormat("  ·  ⚡ TEMPO %d daq%s", (int)((G_TEMPO_UNTIL - TimeCurrent()) / 60) + 1, (G_TEMPO_MKT_OK ? "" : " (bozor ruxsat bermayapti)"));
   else
   {
      string vt = MBShadowValveText();
      if(StringLen(vt) > 0)
         t += "  ·  ⚙ yumshatildi: " + vt;
   }
   return t;
}
