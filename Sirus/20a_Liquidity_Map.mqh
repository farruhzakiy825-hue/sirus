//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20a_Liquidity_Map                               |
//| Plan stage 3: one persistent liquidity map across M5..H4 + key   |
//| levels, with status, age, touches, multi-TF sweep strength,      |
//| sweep (wick) quality and the champion level each side.           |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// The event engine sees sweeps one timeframe at a time and forgets a pool once it is used: an H1
// high that is also an H4 high and a previous-day high was "an M15 sweep" if M15 saw it first. Here
// every swing high / low of M5, M15, H1 and H4, plus the previous day's high / low, goes into one map;
// levels within a fraction of ATR(M15) merge and keep a mask of the timeframes that made them.
//
//  STATUS      FRESH (untouched) -> PARTIAL (touched, or closed beyond once) -> SWEPT (pierced and
//              closed back) -> RE-SWEPT (twice) | TAKEN (two M5 closes beyond: accepted - a failed
//              sweep if it was swept just before, i.e. a trap).
//  STRENGTH    from the mask: LOCAL (M5) . STRONG LOCAL (M15) . MAJOR (H1) . HTF MAJOR (H4 / key) .
//              EXTREME (H1 + H4/key + M15/M5). Equal highs / lows lift one class (to HTF MAJOR at most).
//  SWEEP       a sweep of a map level is recorded per side with its class, its wick quality (wick share
//              of the bar, close in the far half) and the next bar's confirmation; sweeps of the same
//              side within 30 min and half an ATR(M15) combine into one multi-timeframe event.
//  CHAMPION    the untaken level each side that matters most now: class x age / distance.
//
// Speed: harvested once per M5 bar (four CopyRates), status from the closed M5 bar. Nothing per tick.

input group "47a — LIKVIDLIK XARITASI (reja 3-bosqich)"
input bool   EnableMBLiquidityMap       = true;   // Bitta likvidlik xaritasi: M5/M15/H1/H4 swing'lari + PDH/PDL, holati (toza/tegilgan/sweep/qayta sweep/olingan), kuchi (LOCAL..EXTREME), eng muhim daraja
input bool   MBLiquidityPrintOnUse      = true;   // MAJOR+ sweep va tuzoqlarni jurnalga yozish ([SIRUS LIQUIDITY])

#define LQ_MAX        64
#define LQ_FRESH      0
#define LQ_PARTIAL    1
#define LQ_SWEPT      2
#define LQ_RESWEPT    3
#define LQ_TAKEN      4

#define LQ_M5         1
#define LQ_M15        2
#define LQ_H1         4
#define LQ_H4         8
#define LQ_KEY        16

struct SLqLevel
{
   double   level;
   int      side;         // +1 buy-side (a high), -1 sell-side (a low)
   int      mask;         // LQ_M5 | LQ_M15 | ...
   bool     eq;           // equal highs / lows (two swings of one timeframe)
   int      status;
   int      touches;
   int      sweeps;
   int      accepts;
   datetime born;
   datetime last_touch;
   datetime last_sweep;
   datetime taken_at;
   int      pass_mask;    // timeframes that found it in this harvest pass (twice = equal levels)
};

SLqLevel G_LQ[LQ_MAX];
int      G_LQ_N      = 0;
datetime G_LQ_BAR_M5 = 0;
int      G_LQ_VERSION = 0;

// The last (combined) sweep per side: [0] = sell-side lows swept (favours BUY), [1] = buy-side highs swept.
datetime G_LQ_SW_TIME[2];
double   G_LQ_SW_LEVEL[2];
double   G_LQ_SW_EXT[2];
int      G_LQ_SW_MASK[2];
int      G_LQ_SW_CLASS[2];
int      G_LQ_SW_Q[2];          // 1 plain, 2 strong wick, 3 confirmed by the next bar
bool     G_LQ_SW_TRAP[2];       // accepted beyond right after: the sweep failed

int MBLqSideIdx(const int side) { return (side > 0) ? 1 : 0; }

int MBLqClass(const int mask, const bool eq)
{
   bool m5 = (mask & LQ_M5) != 0, m15 = (mask & LQ_M15) != 0, h1 = (mask & LQ_H1) != 0;
   bool big = (mask & (LQ_H4 | LQ_KEY)) != 0;
   int c = 1;
   if(big && h1 && (m15 || m5)) c = 5;
   else if(big)                 c = 4;
   else if(h1)                  c = 3;
   else if(m15)                 c = 2;
   if(eq && c < 4) c++;
   return c;
}

string MBLqClassName(const int c)
{
   switch(c)
   {
      case 1: return "LOCAL";
      case 2: return "KUCHLI LOKAL";
      case 3: return "MAJOR";
      case 4: return "HTF MAJOR";
      case 5: return "EXTREME";
   }
   return "-";
}

string MBLqMaskText(const int mask)
{
   string t = "";
   if((mask & LQ_M5) != 0)  t += "M5+";
   if((mask & LQ_M15) != 0) t += "M15+";
   if((mask & LQ_H1) != 0)  t += "H1+";
   if((mask & LQ_H4) != 0)  t += "H4+";
   if((mask & LQ_KEY) != 0) t += "PD+";
   if(StringLen(t) > 0) t = StringSubstr(t, 0, StringLen(t) - 1);
   return t;
}

string MBLqStatusName(const int st)
{
   switch(st)
   {
      case LQ_FRESH:   return "toza";
      case LQ_PARTIAL: return "tegilgan";
      case LQ_SWEPT:   return "sweep";
      case LQ_RESWEPT: return "qayta sweep";
      case LQ_TAKEN:   return "olingan";
   }
   return "-";
}

// Add a level, or merge it into one within tol on the same side (OR the mask; the same timeframe
// twice = equal highs / lows). An existing level keeps its status.
void MBLqPut(const double lvl, const int side, const int bit, const int status, const int sweeps, const datetime born, const double tol)
{
   for(int i = 0; i < G_LQ_N; i++)
   {
      if(G_LQ[i].side != side || MathAbs(G_LQ[i].level - lvl) > tol)
         continue;
      if((G_LQ[i].pass_mask & bit) != 0)
         G_LQ[i].eq = true;   // a second swing of the same timeframe in this pass: equal highs / lows
      G_LQ[i].pass_mask |= bit;
      G_LQ[i].mask |= bit;
      // The more extreme price represents the pool (the stops sit just beyond it).
      if(side > 0 ? lvl > G_LQ[i].level : lvl < G_LQ[i].level)
         G_LQ[i].level = lvl;
      return;
   }
   if(G_LQ_N >= LQ_MAX)
      return;
   int k = G_LQ_N++;
   G_LQ[k].level = lvl;
   G_LQ[k].side = side;
   G_LQ[k].mask = bit;
   G_LQ[k].eq = false;
   G_LQ[k].status = status;
   G_LQ[k].touches = 0;
   G_LQ[k].sweeps = sweeps;
   G_LQ[k].accepts = 0;
   G_LQ[k].born = born;
   G_LQ[k].last_touch = 0;
   G_LQ[k].last_sweep = 0;
   G_LQ[k].taken_at = 0;
   G_LQ[k].pass_mask = bit;
}

// Swings of one timeframe, with their history since: taken (a close beyond) -> skipped; pierced and
// closed back -> SWEPT.
void MBLqHarvestTF(const ENUM_TIMEFRAMES tf, const int bit, const int bars, const int len, const double atr_tf,
                   const double px, const double window, const double tol)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, tf, 0, bars, r);
   if(n < 2 * len + 5 || atr_tf <= 0.0)
      return;
   double pierce = MathMax(0.05 * atr_tf, 2.0 * _Point);
   for(int k = len + 1; k <= n - 1 - len; k++)
   {
      bool is_hi = true, is_lo = true;
      for(int j = 1; j <= len; j++)
      {
         if(r[k].high <= r[k - j].high || r[k].high < r[k + j].high) is_hi = false;
         if(r[k].low  >= r[k - j].low  || r[k].low  > r[k + j].low)  is_lo = false;
      }
      for(int pass = 0; pass < 2; pass++)
      {
         int side = (pass == 0) ? 1 : -1;
         if(side > 0 && !is_hi) continue;
         if(side < 0 && !is_lo) continue;
         double L = (side > 0) ? r[k].high : r[k].low;
         if(MathAbs(L - px) > window)
            continue;
         bool taken = false;
         int sw = 0;
         for(int j = k - 1; j >= 1 && !taken; j--)
         {
            if(side * (r[j].close - L) > pierce) taken = true;
            else if(side * ((side > 0 ? r[j].high : r[j].low) - L) > pierce) sw++;
         }
         if(taken)
            continue;
         MBLqPut(L, side, bit, (sw >= 2 ? LQ_RESWEPT : (sw == 1 ? LQ_SWEPT : LQ_FRESH)), sw, r[k].time, tol);
      }
   }
}

void MBLqRecordSweep(const int i, const double ext, const int q, const datetime t)
{
   int k = MBLqSideIdx(G_LQ[i].side);
   double atr15 = ((G_MB_ATR[2] > 0.0) ? G_MB_ATR[2] : G_MB_ATR[1] * 2.0) * _Point;
   int cls = MBLqClass(G_LQ[i].mask, G_LQ[i].eq);
   // AUDIT FIX: a new sweep never merges into a record already marked a trap - it is its own event.
   bool combine = (G_LQ_SW_TIME[k] > 0 && t - G_LQ_SW_TIME[k] <= 1800 && MathAbs(G_LQ_SW_LEVEL[k] - G_LQ[i].level) <= 0.5 * atr15 &&
                   !G_LQ_SW_TRAP[k]);
   if(combine)
   {
      G_LQ_SW_MASK[k] |= G_LQ[i].mask;
      G_LQ_SW_CLASS[k] = MathMax(G_LQ_SW_CLASS[k], MathMax(cls, MBLqClass(G_LQ_SW_MASK[k], false)));
      G_LQ_SW_EXT[k] = (G_LQ[i].side > 0) ? MathMax(G_LQ_SW_EXT[k], ext) : MathMin(G_LQ_SW_EXT[k], ext);
      G_LQ_SW_Q[k] = MathMax(G_LQ_SW_Q[k], q);
   }
   else
   {
      G_LQ_SW_MASK[k] = G_LQ[i].mask;
      G_LQ_SW_CLASS[k] = cls;
      G_LQ_SW_EXT[k] = ext;
      G_LQ_SW_Q[k] = q;
      G_LQ_SW_LEVEL[k] = G_LQ[i].level;
      G_LQ_SW_TRAP[k] = false;
   }
   G_LQ_SW_TIME[k] = t;
   G_LQ_VERSION++;
   if(MBLiquidityPrintOnUse && VerboseLogs && G_LQ_SW_CLASS[k] >= 3)
      PrintFormat("[SIRUS LIQUIDITY] %s liquidity swept @ %s | %s (%s)%s | wick %s",
                  (G_LQ[i].side > 0 ? "BUY-SIDE" : "SELL-SIDE"), DoubleToString(G_LQ[i].level, _Digits),
                  MBLqClassName(G_LQ_SW_CLASS[k]), MBLqMaskText(G_LQ_SW_MASK[k]), (G_LQ[i].eq ? ", equal levels" : ""),
                  (q >= 2 ? "strong" : "plain"));
}

// The closed M5 bar against every live level.
void MBLqStatusUpdate(const datetime bar_time)
{
   double o = iOpen(_Symbol, PERIOD_M5, 1), h = iHigh(_Symbol, PERIOD_M5, 1), l = iLow(_Symbol, PERIOD_M5, 1), c = iClose(_Symbol, PERIOD_M5, 1);
   double atr5 = G_MB_ATR[1] * _Point;
   if(o <= 0.0 || h <= l || atr5 <= 0.0)
      return;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double pierce = MathMax(MBSweepMinATR * atr5, spread);

   // Next-bar confirmation of the last sweeps: this bar closed further away from the swept level.
   for(int k = 0; k <= 1; k++)
   {
      int side = (k == 1) ? 1 : -1;
      if(G_LQ_SW_TIME[k] > 0 && bar_time - G_LQ_SW_TIME[k] == PeriodSeconds(PERIOD_M5) && side * (c - G_LQ_SW_LEVEL[k]) < 0.0 &&
         side * (c - iClose(_Symbol, PERIOD_M5, 2)) < 0.0)
         G_LQ_SW_Q[k] = 3;
   }

   for(int i = 0; i < G_LQ_N; i++)
   {
      if(G_LQ[i].status == LQ_TAKEN || G_LQ[i].born >= bar_time)
         continue;
      int s = G_LQ[i].side;
      double L = G_LQ[i].level;
      double ext = (s > 0) ? h : l;
      if(s * (ext - L) >= pierce)
      {
         if(s * (c - L) < 0.0)
         {
            // Pierced and closed back: a sweep. Wick quality: the wick beyond the body is at least half
            // the bar and the close sits in the far half.
            double wick = (s > 0) ? (h - MathMax(o, c)) : (MathMin(o, c) - l);
            double pos = (c - l) / (h - l);
            int q = (wick >= 0.5 * (h - l) && (s > 0 ? pos <= 0.5 : pos >= 0.5)) ? 2 : 1;
            G_LQ[i].sweeps++;
            G_LQ[i].accepts = 0;
            G_LQ[i].status = (G_LQ[i].sweeps >= 2) ? LQ_RESWEPT : LQ_SWEPT;
            G_LQ[i].last_sweep = bar_time;
            MBLqRecordSweep(i, ext, q, bar_time);
         }
         else
         {
            G_LQ[i].accepts++;
            if(G_LQ[i].accepts >= 2)
            {
               G_LQ[i].status = LQ_TAKEN;
               G_LQ[i].taken_at = bar_time;
               int k = MBLqSideIdx(s);
               // Accepted right after it was swept: the sweep was a trap, the move goes on.
               if(G_LQ[i].last_sweep > 0 && bar_time - G_LQ[i].last_sweep <= 3600 && G_LQ_SW_TIME[k] == G_LQ[i].last_sweep)
               {
                  G_LQ_SW_TRAP[k] = true;
                  if(MBLiquidityPrintOnUse && VerboseLogs)
                     PrintFormat("[SIRUS LIQUIDITY] TRAP - the %s sweep @ %s failed: two M5 closes beyond it",
                                 (s > 0 ? "buy-side" : "sell-side"), DoubleToString(L, _Digits));
               }
               G_LQ_VERSION++;
            }
            else if(G_LQ[i].status == LQ_FRESH)
               G_LQ[i].status = LQ_PARTIAL;
         }
      }
      else
      {
         // Closed beyond once and came back inside without a new pierce: a two-bar fake break.
         if(G_LQ[i].accepts == 1 && s * (c - L) < 0.0)
         {
            G_LQ[i].sweeps++;
            G_LQ[i].accepts = 0;
            G_LQ[i].status = (G_LQ[i].sweeps >= 2) ? LQ_RESWEPT : LQ_SWEPT;
            G_LQ[i].last_sweep = bar_time;
            MBLqRecordSweep(i, ext, 1, bar_time);
         }
         else if(s * (ext - (L - s * 0.1 * atr5)) >= 0.0 && bar_time - G_LQ[i].last_touch >= 600)
         {
            G_LQ[i].touches++;
            G_LQ[i].last_touch = bar_time;
            if(G_LQ[i].status == LQ_FRESH)
               G_LQ[i].status = LQ_PARTIAL;
         }
      }
   }
}

void MBLiquidityMapUpdate()
{
   if(!EnableMBLiquidityMap || !EnableMarketBrainEngines)
   {
      G_LQ_N = 0;   // AUDIT FIX: switched off - nothing stale survives into the other layers
      ArrayInitialize(G_LQ_SW_TIME, 0);
      return;
   }
   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 <= 0 || m5 == G_LQ_BAR_M5)
      return;
   bool first = (G_LQ_BAR_M5 == 0);
   G_LQ_BAR_M5 = m5;
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr5 = G_MB_ATR[1] * _Point, atr15 = G_MB_ATR[2] * _Point, atr1h = G_MB_ATR[3] * _Point, atr4h = G_MB_ATR[4] * _Point;
   if(px <= 0.0 || atr5 <= 0.0 || atr15 <= 0.0)
      return;
   if(atr1h <= 0.0) atr1h = 2.0 * atr15;
   if(atr4h <= 0.0) atr4h = 2.0 * atr1h;

   // The closed bar first (levels already known), then the harvest (new swings with their own history).
   if(!first)
      MBLqStatusUpdate(iTime(_Symbol, PERIOD_M5, 1));

   double window = MathMax(8.0 * atr15, 4.0 * atr1h);
   double tol = 0.2 * atr15;
   for(int i = 0; i < G_LQ_N; i++)
      G_LQ[i].pass_mask = 0;
   MBLqHarvestTF(PERIOD_M5,  LQ_M5,  120, 3, atr5,  px, window, tol);
   MBLqHarvestTF(PERIOD_M15, LQ_M15, 100, 3, atr15, px, window, tol);
   MBLqHarvestTF(PERIOD_H1,  LQ_H1,  80,  2, atr1h, px, window, tol);
   MBLqHarvestTF(PERIOD_H4,  LQ_H4,  60,  2, atr4h, px, window, tol);
   // Previous day's high and low.
   double pdh = iHigh(_Symbol, PERIOD_D1, 1), pdl = iLow(_Symbol, PERIOD_D1, 1);
   double th = iHigh(_Symbol, PERIOD_D1, 0), tl = iLow(_Symbol, PERIOD_D1, 0);
   datetime d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(pdh > 0.0 && MathAbs(pdh - px) <= window)
      MBLqPut(pdh, 1, LQ_KEY, (th > pdh ? (px > pdh ? LQ_TAKEN : LQ_SWEPT) : LQ_FRESH), (th > pdh ? 1 : 0), d1, tol);
   if(pdl > 0.0 && MathAbs(pdl - px) <= window)
      MBLqPut(pdl, -1, LQ_KEY, (tl > 0.0 && tl < pdl ? (px < pdl ? LQ_TAKEN : LQ_SWEPT) : LQ_FRESH), (tl > 0.0 && tl < pdl ? 1 : 0), d1, tol);

   // Drop what no longer matters: taken more than two hours ago, or out of the window.
   int keep = 0;
   for(int i = 0; i < G_LQ_N; i++)
   {
      bool drop = (MathAbs(G_LQ[i].level - px) > 1.5 * window) ||
                  (G_LQ[i].status == LQ_TAKEN && G_LQ[i].taken_at > 0 && TimeCurrent() - G_LQ[i].taken_at > 7200) ||
                  (G_LQ[i].status == LQ_TAKEN && G_LQ[i].taken_at == 0);
      if(drop) continue;
      if(keep != i) G_LQ[keep] = G_LQ[i];
      keep++;
   }
   G_LQ_N = keep;
}

// The last combined sweep that favours dir (sell-side lows swept favour BUY): within max_age seconds,
// class >= min_class, not a trap.
bool MBLqSweepFor(const int dir, const int min_class, const int max_age, datetime &t, int &cls, double &ext, int &q)
{
   t = 0; cls = 0; ext = 0.0; q = 0;
   if(!EnableMBLiquidityMap || dir == 0)
      return false;
   int k = MBLqSideIdx(-dir);
   if(G_LQ_SW_TIME[k] <= 0 || G_LQ_SW_TRAP[k] || G_LQ_SW_CLASS[k] < min_class || TimeCurrent() - G_LQ_SW_TIME[k] > max_age)
      return false;
   t = G_LQ_SW_TIME[k];
   cls = G_LQ_SW_CLASS[k];
   ext = G_LQ_SW_EXT[k];
   q = G_LQ_SW_Q[k];
   return true;
}

// The champion level on a side (+1 above price, -1 below): untaken, unswept, the most weight -
// class x age x (equal levels) / distance in ATR(M15).
double MBLqChampion(const int side, const double px, string &what)
{
   what = "";
   double atr15 = G_MB_ATR[2] * _Point;
   if(!EnableMBLiquidityMap || atr15 <= 0.0 || px <= 0.0)
      return 0.0;
   double best = 0.0, best_sc = 0.0;
   for(int i = 0; i < G_LQ_N; i++)
   {
      if(G_LQ[i].side != side || G_LQ[i].status >= LQ_SWEPT) continue;
      if(side * (G_LQ[i].level - px) <= 0.0) continue;
      int cls = MBLqClass(G_LQ[i].mask, G_LQ[i].eq);
      long age_h = (TimeCurrent() - G_LQ[i].born) / 3600;
      double age_f = (age_h < 12) ? 1.0 : ((age_h < 48) ? 0.8 : 0.6);
      double sc = cls * age_f / (1.0 + MathAbs(G_LQ[i].level - px) / atr15);
      if(sc > best_sc)
      {
         best_sc = sc;
         best = G_LQ[i].level;
         what = MBLqMaskText(G_LQ[i].mask) + (G_LQ[i].eq ? " teng" : "") + ", " + MBLqStatusName(G_LQ[i].status);
      }
   }
   return best;
}

// The nearest untaken map level ahead in dir of at least min_class (a leg's target).
double MBLqNearestAhead(const int dir, const double px, const int min_class)
{
   if(!EnableMBLiquidityMap)
      return 0.0;   // AUDIT FIX: a map frozen by switching it off must not feed other layers
   double best = 0.0;
   for(int i = 0; i < G_LQ_N; i++)
   {
      if(G_LQ[i].side != dir || G_LQ[i].status >= LQ_SWEPT) continue;
      if(dir * (G_LQ[i].level - px) <= 0.0) continue;
      if(MBLqClass(G_LQ[i].mask, G_LQ[i].eq) < min_class) continue;
      if(best <= 0.0 || MathAbs(G_LQ[i].level - px) < MathAbs(best - px))
         best = G_LQ[i].level;
   }
   return best;
}

string MBLiquidityPanelText()
{
   if(!EnableMBLiquidityMap)
      return "";
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string wu = "", wd = "";
   double up = MBLqChampion(1, px, wu), dn = MBLqChampion(-1, px, wd);
   string t = "Likvidlik:";
   t += (up > 0.0) ? StringFormat(" ▲ %s (%s)", DoubleToString(up, _Digits), wu) : " ▲ -";
   t += (dn > 0.0) ? StringFormat(" · ▼ %s (%s)", DoubleToString(dn, _Digits), wd) : " · ▼ -";
   // The most recent combined sweep.
   int k = (G_LQ_SW_TIME[1] > G_LQ_SW_TIME[0]) ? 1 : 0;
   if(G_LQ_SW_TIME[k] > 0 && TimeCurrent() - G_LQ_SW_TIME[k] <= 7200)
      t += StringFormat(" · sweep %s %s %d daq%s", (k == 1 ? "▲" : "▼"), MBLqClassName(G_LQ_SW_CLASS[k]),
                        (int)((TimeCurrent() - G_LQ_SW_TIME[k]) / 60), (G_LQ_SW_TRAP[k] ? " (tuzoq)" : ""));
   return t;
}
