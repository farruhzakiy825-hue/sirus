//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 28_Probability_Table                            |
//| EHTIMOL JADVALI: the market's own statistics, per situation      |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// PACKAGE 46: EHTIMOL JADVALI (probability table) - STEP 1: OBSERVE ONLY
//---------------------------------------------------------------------
// Every rule so far was written by hand from a screenshot, and every new rule fixed one picture and broke
// another. With a $0.22 target the only question that matters is: from THIS kind of moment, does price
// cover the spread + TP before it runs a grid step against the entry? The market answers it itself.
//
// On every closed M1 bar the table opens two VIRTUAL trades - a BUY at the ask and a SELL at the bid -
// with the real first-entry TP and the real first grid step. Nothing is sent. Each one ends as
//   TP      the target was reached (CLEAN when the worst excursion before it stayed within
//           PTCleanMAETP x TP - no averaging would have been needed in practice),
//   ADVERSE price ran one grid step against it first (the basket would have needed the grid),
//   TIMEOUT neither within PTMaxMinutes.
// Each result is filed under the moment's fingerprint, seen from the trade's side:
//   H1+H4 (with / mixed / against) x local layer M5+leg (with / mixed / against) x last closed M1
//   candle (with / small / against) x place in the last hour's M5 range (cheap / middle / dear for
//   that side) x volatility (ATR(M1) vs the TP: quiet / normal / fast)  = 243 cells per side, kept apart
//   for normal and cashback mode (package 48: their targets differ).
//
// The table is kept in the COMMON files folder (Sirus_PTable_<symbol>_<magic>.bin), so a Strategy
// Tester run over a month or two fills it in minutes and the live chart starts with it; a readable copy
// (Sirus_PTable_<symbol>_<magic>.csv) is written beside it. The panel shows what the table says about
// this very moment. STEP 1 TRADES NOTHING: the decision still belongs to YADRO.
//=====================================================================

input group "EHTIMOL JADVALI ▸ Probability table (step 1: observe only)"
// EnableProbTable: 46-PAKET: har M1 shamida xayoliy BUY va SELL - natija holat bo'yicha jadvalga yoziladi (savdoga ta'sir qilmaydi)
input bool   EnableProbTable          = true;   // Probability table: observe (no trading effect)
// PTMaxMinutes: Xayoliy savdo shuncha daqiqada TP ga ham, grid qadamiga ham yetmasa - TIMEOUT
input int    PTMaxMinutes             = 30;   // Probability table: virtual trade timeout, min
// PTCleanMAETP: TP gacha eng yomon qarshi yurish TP x shu ichida qolsa - TOZA TP
input double PTCleanMAETP             = 3.0;   // Probability table: clean TP = worst excursion within TP x
// PTMinSamples: Panelda foiz ko'rsatish uchun katakda kamida shuncha natija
input int    PTMinSamples             = 30;   // Probability table: samples before a cell is shown as judged

#define PT_BASE    243         // one mode's fingerprints
#define PT_CELLS   486         // package 48: x 2 modes - normal (0..242) and cashback (243..485); the TP differs
#define PT_MAXV    160          // live virtual trades (2 per M1 bar x PTMaxMinutes, with room)
#define PT_TP      0
#define PT_CLEAN   1
#define PT_ADV     2
#define PT_TIMEOUT 3

int      G_PT_N[2][PT_CELLS];          // 0 = SELL, 1 = BUY
int      G_PT_TP[2][PT_CELLS];
int      G_PT_CLEAN[2][PT_CELLS];
int      G_PT_ADV[2][PT_CELLS];
double   G_PT_SECS[2][PT_CELLS];       // summed seconds to TP (TP results only)
long     G_PT_TOTAL = 0;               // results filed, all cells

bool     G_PTV_ON[PT_MAXV];
int      G_PTV_DIR[PT_MAXV];
int      G_PTV_CELL[PT_MAXV];
double   G_PTV_ENTRY[PT_MAXV];
double   G_PTV_TP[PT_MAXV];            // target price
double   G_PTV_ADV[PT_MAXV];           // one grid step against
double   G_PTV_MAE[PT_MAXV];           // worst excursion so far, price units
datetime G_PTV_T[PT_MAXV];
int      G_PTV_LIVE = 0;
datetime G_PT_BAR = 0;
datetime G_PT_SAVED = 0;
int      G_PT_CELL_NOW[2] = {-1, -1};  // this moment's cell per side (panel)

// One factor seen from side d: +1 with, 0 mixed / neutral, -1 against -> 2 / 1 / 0.
int PTTri(const int v) { return (v > 0) ? 2 : ((v < 0) ? 0 : 1); }

// The fingerprint of this moment for side d (0..242), -1 when it cannot be read yet.
int PTCell(const int d)
{
   if(d == 0 || !EnableMarketBrain || !EnableMarketBrainEngines)
      return -1;
   int htf = PTTri(d * (MBSign(G_MB_TF_STATE[3]) + MBSign(G_MB_TF_STATE[4])));
   int loc = PTTri(d * (MBM5StructDir() + MBLayerLocal()));
   int m1  = PTTri(d * G_MB_LAST[0].dir);
   // Place in the last hour's M5 range, from the side's view: cheap (bottom third for a BUY), middle, dear.
   int ilo = iLowest(_Symbol, PERIOD_M5, MODE_LOW, 12, 1), ihi = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 12, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ilo < 0 || ihi < 0 || bid <= 0.0)
      return -1;
   double lo = iLow(_Symbol, PERIOD_M5, ilo), hi = iHigh(_Symbol, PERIOD_M5, ihi);
   if(hi <= lo)
      return -1;
   double r = (bid - lo) / (hi - lo);
   if(d < 0) r = 1.0 - r;
   int pos = (r <= 0.33) ? 2 : ((r >= 0.67) ? 0 : 1);   // 2 = cheap for this side
   // Volatility against the target: how many TPs one M1 bar covers.
   double tp = BaseBasketTPPoints();
   double atr1 = G_MB_ATR[0];
   if(tp <= 0.0 || atr1 <= 0.0)
      return -1;
   double k = atr1 / tp;
   int vol = (k < 0.6) ? 0 : ((k > 1.5) ? 2 : 1);
   // Package 48: cashback and normal mode trade different targets - their results never share a cell.
   return (((htf * 3 + loc) * 3 + m1) * 3 + pos) * 3 + vol + (RebateModeOn() ? PT_BASE : 0);
}

string PTCellText(const int c)
{
   if(c < 0)
      return "-";
   int vol = c % 3, pos = (c / 3) % 3, m1 = (c / 9) % 3, loc = (c / 27) % 3, htf = (c / 81) % 3;   // %3 drops the mode
   string t3[3] = {"qarshi", "aralash", "bilan"};
   string p3[3] = {"qimmat", "o'rta", "arzon"};
   string v3[3] = {"sokin", "oddiy", "tez"};
   return StringFormat("HTF %s · lokal %s · M1 %s · joy %s · %s", t3[htf], t3[loc], t3[m1], p3[pos], v3[vol]);
}

void PTFile(const int side, const int cell, const int outcome, const bool clean, const double secs)
{
   if(cell < 0 || cell >= PT_CELLS)
      return;
   G_PT_N[side][cell]++;
   if(outcome == PT_TP)
   {
      G_PT_TP[side][cell]++;
      if(clean) G_PT_CLEAN[side][cell]++;
      G_PT_SECS[side][cell] += secs;
   }
   else if(outcome == PT_ADV)
      G_PT_ADV[side][cell]++;
   G_PT_TOTAL++;
}

string PTFileName(const string ext)
{
   return StringFormat("Sirus_PTable_%s_%I64d.%s", _Symbol, MagicNumber, ext);
}

void PTSave()
{
   if(!EnableProbTable || G_PT_TOTAL <= 0)
      return;
   int h = FileOpen(PTFileName("bin"), FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h != INVALID_HANDLE)
   {
      FileWriteInteger(h, 48);          // format version (48: two modes)
      FileWriteInteger(h, PT_CELLS);
      for(int s = 0; s < 2; s++)
         for(int c = 0; c < PT_CELLS; c++)
         {
            FileWriteInteger(h, G_PT_N[s][c]);
            FileWriteInteger(h, G_PT_TP[s][c]);
            FileWriteInteger(h, G_PT_CLEAN[s][c]);
            FileWriteInteger(h, G_PT_ADV[s][c]);
            FileWriteDouble(h, G_PT_SECS[s][c]);
         }
      FileClose(h);
   }
   // A readable copy: one row per filled cell.
   h = FileOpen(PTFileName("csv"), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h != INVALID_HANDLE)
   {
      FileWriteString(h, "mode;side;htf;local;m1;place;vol;n;tp;clean_tp;adverse;timeout;tp_pct;clean_pct;adverse_pct;avg_sec_to_tp\r\n");
      string t3[3] = {"against", "mixed", "with"};
      string p3[3] = {"dear", "middle", "cheap"};
      string v3[3] = {"quiet", "normal", "fast"};
      for(int s = 1; s >= 0; s--)
         for(int c = 0; c < PT_CELLS; c++)
         {
            int n = G_PT_N[s][c];
            if(n <= 0) continue;
            int vol = c % 3, pos = (c / 3) % 3, m1 = (c / 9) % 3, loc = (c / 27) % 3, htf = (c / 81) % 3;
            int tpn = G_PT_TP[s][c], cl = G_PT_CLEAN[s][c], ad = G_PT_ADV[s][c];
            FileWriteString(h, StringFormat("%s;%s;%s;%s;%s;%s;%s;%d;%d;%d;%d;%d;%.1f;%.1f;%.1f;%.0f\r\n",
                                            (c >= PT_BASE ? "cashback" : "normal"),
                                            (s == 1 ? "BUY" : "SELL"), t3[htf], t3[loc], t3[m1], p3[pos], v3[vol],
                                            n, tpn, cl, ad, n - tpn - ad,
                                            100.0 * tpn / n, 100.0 * cl / n, 100.0 * ad / n,
                                            (tpn > 0 ? G_PT_SECS[s][c] / tpn : 0.0)));
         }
      FileClose(h);
   }
   G_PT_SAVED = TimeCurrent();
}

void PTLoad()
{
   if(!EnableProbTable)
      return;
   int h = FileOpen(PTFileName("bin"), FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return;
   int ver = FileReadInteger(h), cells = FileReadInteger(h);
   if(ver == 48 && cells == PT_CELLS)   // an older file (one mixed mode) is not read - it is replaced on the next save
   {
      G_PT_TOTAL = 0;
      for(int s = 0; s < 2; s++)
         for(int c = 0; c < PT_CELLS; c++)
         {
            G_PT_N[s][c]     = FileReadInteger(h);
            G_PT_TP[s][c]    = FileReadInteger(h);
            G_PT_CLEAN[s][c] = FileReadInteger(h);
            G_PT_ADV[s][c]   = FileReadInteger(h);
            G_PT_SECS[s][c]  = FileReadDouble(h);
            G_PT_TOTAL += G_PT_N[s][c];
         }
      PrintFormat("[SIRUS PTABLE] loaded %I64d results from %s", G_PT_TOTAL, PTFileName("bin"));
   }
   FileClose(h);
}

// Every tick: open the bar's two virtual trades on a new M1 bar, resolve the live ones.
void PTUpdate()
{
   if(!EnableProbTable)
      return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || _Point <= 0.0)
      return;

   // Resolve.
   if(G_PTV_LIVE > 0)
   {
      long max_age = (long)MathMax(1, PTMaxMinutes) * 60;
      for(int i = 0; i < PT_MAXV; i++)
      {
         if(!G_PTV_ON[i]) continue;
         int d = G_PTV_DIR[i];
         double px = (d > 0) ? bid : ask;   // a BUY closes on the bid, a SELL on the ask
         double against = d * (G_PTV_ENTRY[i] - px);
         if(against > G_PTV_MAE[i]) G_PTV_MAE[i] = against;
         int outcome = -1;
         if(d * (px - G_PTV_TP[i]) >= 0.0)        outcome = PT_TP;
         else if(d * (px - G_PTV_ADV[i]) <= 0.0)  outcome = PT_ADV;
         else if(TimeCurrent() - G_PTV_T[i] > max_age) outcome = PT_TIMEOUT;
         if(outcome < 0) continue;
         double tp_dist = MathAbs(G_PTV_TP[i] - G_PTV_ENTRY[i]);
         bool clean = (outcome == PT_TP && G_PTV_MAE[i] <= MathMax(0.1, PTCleanMAETP) * tp_dist);
         PTFile((d > 0) ? 1 : 0, G_PTV_CELL[i], outcome, clean, (double)(TimeCurrent() - G_PTV_T[i]));
         G_PTV_ON[i] = false;
         G_PTV_LIVE = MathMax(0, G_PTV_LIVE - 1);
      }
   }

   // Open two on each new M1 bar (the moment a closed candle can be read).
   datetime bar = iTime(_Symbol, PERIOD_M1, 0);
   if(bar <= 0 || bar == G_PT_BAR)
      return;
   G_PT_BAR = bar;
   double tp_pts = BaseBasketTPPoints();
   double step_pts = GridDistanceForNextOrder(1);
   if(tp_pts <= 0.0 || step_pts <= 0.0)
      return;
   for(int k = 0; k <= 1; k++)
   {
      int d = (k == 1) ? 1 : -1;
      int cell = PTCell(d);
      G_PT_CELL_NOW[k] = cell;
      if(cell < 0) continue;
      int slot = -1;
      for(int i = 0; i < PT_MAXV; i++)
         if(!G_PTV_ON[i]) { slot = i; break; }
      if(slot < 0) continue;
      double entry = (d > 0) ? ask : bid;
      G_PTV_ON[slot]    = true;
      G_PTV_DIR[slot]   = d;
      G_PTV_CELL[slot]  = cell;
      G_PTV_ENTRY[slot] = entry;
      G_PTV_TP[slot]    = entry + d * tp_pts * _Point;
      G_PTV_ADV[slot]   = entry - d * step_pts * _Point;
      G_PTV_MAE[slot]   = 0.0;
      G_PTV_T[slot]     = TimeCurrent();
      G_PTV_LIVE++;
   }

   // Keep what was learned: every 30 minutes (and at deinit). Not in a non-visual tester run until the end.
   if(!TesterHeadless() && TimeCurrent() - G_PT_SAVED >= 1800)
      PTSave();
}

// Panel: what the table says about this very moment, per side.
string PTSideText(const int k)
{
   int c = G_PT_CELL_NOW[k];
   if(c < 0)
      return "-";
   int n = G_PT_N[k][c];
   if(n < MathMax(1, PTMinSamples))
      return StringFormat("o'rganilmoqda (%d/%d)", n, MathMax(1, PTMinSamples));
   return StringFormat("toza TP %d/%d (%.0f%%) · grid %.0f%%", G_PT_CLEAN[k][c], n, 100.0 * G_PT_CLEAN[k][c] / n,
                       100.0 * G_PT_ADV[k][c] / n);
}

string PTPanelText()
{
   if(!EnableProbTable)
      return "";
   return StringFormat("EHTIMOL  BUY: %s  ·  SELL: %s  ·  jadval %I64d", PTSideText(1), PTSideText(0), G_PT_TOTAL);
}
