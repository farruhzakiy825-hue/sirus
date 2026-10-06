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

input group "49 — MEASURE: PROFILER + SHADOW LEDGER"
input bool   EnableProfiler           = true;   // Har tik necha ms ketishini o'lchash (panelda va jurnalda)
input bool   EnableShadowLedger       = true;   // Rad etilgan setuplarni yashirin kuzatish: TP ga yetardimi yoki grid kerak bo'lardimi
input int    ShadowMaxMinutes         = 30;     // Soya shuncha daqiqada natija bermasa - TIMEOUT
input bool   ShadowToFile             = true;   // Har natijani CSV ga yozish (Sirus_Shadow_<symbol>_<magic>.csv)
input int    ShadowMinSamplesToJudge  = 10;     // Filtr bo'yicha xulosa uchun kamida shuncha natija

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
};

SMBShadow G_SH[MB_SH_MAX];
int       G_SH_NEXT = 0;
int       G_SH_TALLY[MB_SH_SLOTS][3];   // today's results per gate: TP / GRID / TIMEOUT
int       G_SH_DAY = -1;
int       G_SH_LAST_BAR[2] = {-100000, -100000};

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

void MBShadowCsv(const SMBShadow &s, const int outcome, const string extra)
{
   if(!ShadowToFile)
      return;
   string name = StringFormat("Sirus_Shadow_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) == 0)
      FileWriteString(h, "time;resolved;gate;dir;entry;tp;grid_step;outcome;minutes;mfe_pts;mae_pts;brain_bias;extra\r\n");
   FileSeek(h, 0, SEEK_END);
   string oc = (outcome == MB_SH_TP) ? "TP" : ((outcome == MB_SH_GRID) ? "GRID" : ((outcome == MB_SH_TIMEOUT) ? "TIMEOUT" : "SUMMARY"));
   FileWriteString(h, StringFormat("%s;%s;%s;%s;%s;%s;%s;%s;%d;%.0f;%.0f;%d;%s\r\n",
                                   TimeToString(s.t, TIME_DATE | TIME_SECONDS), TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                   MBShadowGateName(s.gate), (s.dir > 0 ? "BUY" : (s.dir < 0 ? "SELL" : "-")),
                                   DoubleToString(s.entry, _Digits), DoubleToString(s.tp_px, _Digits), DoubleToString(s.adv_px, _Digits),
                                   oc, (int)((TimeCurrent() - s.t) / 60), s.mfe / _Point, s.mae / _Point, G_MB_BIAS, extra));
   FileClose(h);
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
   G_SH[k].active = true;
   G_SH[k].t = TimeCurrent();
   G_SH[k].dir = dir;
   G_SH[k].gate = gate;
   G_SH[k].entry = entry;
   G_SH[k].tp_px = entry + dir * tp_pts * _Point;
   G_SH[k].adv_px = entry - dir * adv_pts * _Point;
   G_SH[k].mfe = 0.0;
   G_SH[k].mae = 0.0;
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

// Every tick: resolve the shadows price has decided.
void MBShadowUpdate()
{
   if(!EnableShadowLedger)
      return;
   MBShadowDayRoll();
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
      MBShadowCsv(G_SH[i], outcome, "");
      G_SH[i].active = false;
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
   return t;
}
