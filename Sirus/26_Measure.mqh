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
         if(G_VERBOSE)
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
   int      ek;        // evidence key of the gate that refused it (26c), -1 = a direction / hard gate
   int      al;        // 0 = with or neutral to the global bias, 1 = against it
   int      mask;      // TAKEN: the evidence keys that stood aside for this entry (26c)
   int      bias;      // the global bias when it was recorded
};

SMBShadow G_SH[MB_SH_MAX];
string    G_SH_WHY[MB_SH_MAX];  // PACKAGE 1: the exact rule that refused it and the H4/H1/M15 state - CSV "extra"
int       G_SH_NEXT = 0;
int       G_SH_TALLY[MB_SH_SLOTS][3];   // today's results per gate: TP / GRID / TIMEOUT
int       G_SH_DAY = -1;
int       G_SH_LAST_BAR[2] = {-100000, -100000};
int       G_SH_ACTIVE = 0;      // SPEED: live shadows - the per-tick loop is skipped when none
string    G_SH_BUF = "";        // SPEED: CSV rows waiting for the once-a-minute flush
// Shadow valve state: blocked results per gate since its last decision, taken results, and the
// time each gate's relaxation ends.
datetime  G_SH_FLUSH_BAR = 0;

string MBShadowGateName(const int g)
{
   if(g == MB_SH_TAKEN) return "TAKEN";
   if(g <= GATE_NONE || g >= GATE_COUNT) return "other";
   return GateName(g);
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
                                   oc, (int)((TimeCurrent() - s.t) / 60), s.mfe / _Point, s.mae / _Point, s.bias, extra);
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

void MBShadowAdd(const int dir, const int gate, const double entry, const int ek = -1, const int mask = 0, const string why = "")
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
   G_SH[k].ek = ek;
   G_SH[k].al = (dir * G_MB_BIAS < 0) ? 1 : 0;
   G_SH[k].mask = mask;
   G_SH[k].bias = G_MB_BIAS;
   G_SH_WHY[k] = StringFormat("%sh4=%d h1=%d m15=%d", (StringLen(why) > 0 ? "rule=" + why + " " : ""),
                              G_MB_TF_STATE[4], G_MB_TF_STATE[3], G_MB_TF_STATE[2]);
   StringReplace(G_SH_WHY[k], ";", ",");
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
   MBShadowAdd(dir, gate, SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID)), MBEGKeyOf(reason), 0, TraceRule(reason));
}

// A real first entry, followed the same way for the comparison.
void MBShadowOnEntry(const int dir, const double price)
{
   if(!EnableShadowLedger)
      return;
   MBShadowDayRoll();
   MBShadowAdd(dir, MB_SH_TAKEN, price, -1, G_EG_SKIP_MASK);
}

//---------------------------------------------------------------------
// SHADOW VALVE -> EVIDENCE GATES (26c)
//---------------------------------------------------------------------
// The old valve judged a gate by the TP share of its refusals - with a ~224-point TP against a
// ~5500-point grid step even a random entry reaches TP ~96% of the time, so it proved nothing. The
// quality gates are now judged by the evidence gates (26c) on what separates entries in this robot:
// how often they needed the grid. The hooks keep their names.
bool MBShadowValveOn(const int g)
{
   int od = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
   if(g == GATE_SCORE)   return MBEGSkip(EG_SCORE, od);
   if(g == GATE_MBJUDGE) return MBEGSkip(EG_JUDGE, od);
   return false;
}

// Every tick: resolve the shadows price has decided.
void MBShadowUpdate()
{
   MBDailyReportCheck();   // stage 18 (B6) - before the shadow tallies roll over
   if(!EnableShadowLedger)
      return;
   MBShadowDayRoll();
   MBEGTick();   // evidence gates: market check, persistence (a few comparisons)
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
      MBEGFeed(G_SH[i].gate == MB_SH_TAKEN, G_SH[i].ek, G_SH[i].al, G_SH[i].mask, outcome);
      MBShadowCsv(G_SH[i], outcome, G_SH_WHY[i]);
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
   for(int g = 0; g < GATE_COUNT; g++)
      bn += G_SH_TALLY[g][MB_SH_TP] + G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
   MBShadowTPRate(MB_SH_TAKEN, tn);
   if(bn + tn == 0)
      return "Soya: hali natija yo'q";
   // The share that needed the grid is what separates entries here (TP is reached ~90% of the time
   // whatever the entry, because the TP is tiny against the grid step).
   int b_bad = 0;
   for(int g = 0; g < GATE_COUNT; g++)
      b_bad += G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
   int t_bad = G_SH_TALLY[MB_SH_TAKEN][MB_SH_GRID] + G_SH_TALLY[MB_SH_TAKEN][MB_SH_TIMEOUT];
   string t = StringFormat("Soya: to'silgan %d → gridga %.0f%%  ·  olingan %d → gridga %.0f%%",
                           bn, (bn > 0 ? 100.0 * b_bad / bn : 0.0), tn, (tn > 0 ? 100.0 * t_bad / tn : 0.0));
   return t;
}
