//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20i_Zone_Intelligence                            |
//| Supply / demand zones from their bases: RBR, DBR, RBD, DBD on     |
//| M5, M15, H1 and H4 - lifecycle, a 100-point score, and the place  |
//| an entry or a grid rung leans on.                                 |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// WHY (owner's plan "Zone Intelligence & Supply/Demand Engine", package 10): the EA read zones in three
// places (19 role engine on swing levels, 20g HTF base + displacement, 11 zone map) and none of them knew
// HOW a zone was born. A demand zone is a base the market left with force - and what came before the base
// (a rally or a drop) says whether it is continuation (RBR, DBD) or a turn (DBR, RBD).
//
// DETECTION (closed bars only, rebuilt on each new bar of the zone's TF - no future data):
//   base      1-3 candles, each range <= ZIBaseMaxRangeATR x ATR and body <= half its range
//   leg out   within 3 candles after the base, a close >= ZIDispATR x ATR beyond the base, first candle a
//             real body (>= 50% of its range) the same way -> the zone's side (+1 demand, -1 supply)
//   leg in    the 3 candles before the base moved >= 0.5 ATR: rally (+1) or drop (-1)
//   model     RBR (+,+) DBR (-,+) demand; RBD (+,-) DBD (-,-) supply
//   bounds    demand: base low (distal) to the highest base body (proximal); supply mirrored; <= 1.5 ATR wide
// LIFECYCLE (the closed bars after it formed): FRESH (never revisited) / TESTED (1 visit, or 2 with a real
//   reaction) / WEAKENED (3+ visits or a weak reaction); a close beyond the distal edge = BROKEN, too old =
//   EXPIRED - both are dropped.
// SCORE (owner's weights): origin & impulse 20, liquidity 20, structure 20, freshness 15, candles 15,
//   location & execution 10. A starting configuration, to be checked against the trace and the autopsy.
//
// USE: the judge's location (a zone of the entry's side at or inside it, score >= ZIMinScore) and a quality
// cut for a strong fresh zone of the other side right ahead (CAUTION - the hard HTF zone rule stays in 20g);
// the grid's "rung at a structure" (24 MBStructureNear); the panel; the autopsy. It never blocks on its own.

// [tester build] input group "BRAIN ▸ Zone intelligence (RBR / DBR / RBD / DBD)"
// EnableZoneIntelligence: Supply/demand zonalari bazasidan: RBR/DBR/RBD/DBD (M5, M15, H1, H4), hayot bosqichi, 100 ballik baho - kirish joyi, grid pog'onasi joyi, panel, autopsy
const bool   EnableZoneIntelligence  = true;   // Zone intelligence: RBR / DBR / RBD / DBD with a 100-point score
// ZIMinScore: Kirish joyi sifatida qabul qilinadigan eng kichik zona bahosi
const int    ZIMinScore              = 60;   // Zone score that counts as an entry location
// ZIGridMinScore: Grid pog'onasi "struktura yonida" deb hisoblanishi uchun zona bahosi
const int    ZIGridMinScore          = 50;   // Zone score that counts as a structure for a grid rung
// ZIOpposeScore: Shu baholi YANGI qarshi zona oldinda bo'lsa - sifat pasayadi (CAUTION)
const int    ZIOpposeScore           = 80;   // A fresh opposing zone ahead at this score cuts quality
// ZIBaseMaxRangeATR: Baza shamining eng katta diapazoni (ATR x shu)
const double ZIBaseMaxRangeATR       = 0.8;   // Base candle: max range (ATR of its TF)
// ZIDispATR: Bazadan chiqish: 3 sham ichida baza chegarasidan shuncha ATR
const double ZIDispATR               = 1.5;   // Leg out: min move beyond the base (ATR of its TF)

#define ZI_MAX       96
#define ZI_FRESH     0
#define ZI_TESTED    1
#define ZI_WEAKENED  2

#define ZI_RBR 0
#define ZI_DBR 1
#define ZI_RBD 2
#define ZI_DBD 3

double   G_ZI_PROX[ZI_MAX];    // proximal edge (where price meets it first)
double   G_ZI_DIST[ZI_MAX];    // distal edge (a close beyond it breaks the zone)
int      G_ZI_DIR[ZI_MAX];     // +1 demand, -1 supply
int      G_ZI_MODEL[ZI_MAX];
int      G_ZI_TFI[ZI_MAX];     // 1 M5, 2 M15, 3 H1, 4 H4 (the brain's TF slots)
datetime G_ZI_T[ZI_MAX];       // base candle time - with the TF, the zone's ID
int      G_ZI_STATE[ZI_MAX];
int      G_ZI_TOUCH[ZI_MAX];
int      G_ZI_SCORE[ZI_MAX];
int      G_ZI_N = 0;
datetime G_ZI_BAR[MB_TF_COUNT];

string ZIModelName(const int m)
{
   switch(m)
   {
      case ZI_RBR: return "RBR";
      case ZI_DBR: return "DBR";
      case ZI_RBD: return "RBD";
      case ZI_DBD: return "DBD";
   }
   return "?";
}

string ZIStateName(const int s)
{
   if(s == ZI_FRESH)  return "fresh";
   if(s == ZI_TESTED) return "tested";
   return "weakened";
}

// Remove every zone of one TF slot (it is about to be rebuilt).
void ZIDropTF(const int tfi)
{
   int w = 0;
   for(int k = 0; k < G_ZI_N; k++)
   {
      if(G_ZI_TFI[k] == tfi)
         continue;
      if(w != k)
      {
         G_ZI_PROX[w] = G_ZI_PROX[k]; G_ZI_DIST[w] = G_ZI_DIST[k]; G_ZI_DIR[w] = G_ZI_DIR[k];
         G_ZI_MODEL[w] = G_ZI_MODEL[k]; G_ZI_TFI[w] = G_ZI_TFI[k]; G_ZI_T[w] = G_ZI_T[k];
         G_ZI_STATE[w] = G_ZI_STATE[k]; G_ZI_TOUCH[w] = G_ZI_TOUCH[k]; G_ZI_SCORE[w] = G_ZI_SCORE[k];
      }
      w++;
   }
   G_ZI_N = w;
}

void ZIScanTF(const int tfi, const int lookback, const int max_age)
{
   ENUM_TIMEFRAMES tf = MBTF(tfi);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, tf, 1, lookback, r);      // closed bars only: r[0] is the last closed one
   double atr = ATRPointsManual(tf, 14, 1) * _Point;
   if(n < 30 || atr <= 0.0)
      return;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   int b = n - 12;   // room for the leg in (3) and the 10-bar origin window before the base
   while(b >= 4 && G_ZI_N < ZI_MAX)
   {
      // --- base: 1-3 small candles, oldest at b ---
      int len = 0;
      for(int k = 0; k < 3; k++)
      {
         int i = b - k;
         if(i < 2) break;
         double rg = r[i].high - r[i].low;
         if(rg <= 0.0 || rg > ZIBaseMaxRangeATR * atr || MathAbs(r[i].close - r[i].open) > 0.5 * rg)
            break;
         len++;
      }
      if(len == 0) { b--; continue; }
      int newest = b - len + 1;                          // newest base candle
      double b_hi = -DBL_MAX, b_lo = DBL_MAX, body_hi = -DBL_MAX, body_lo = DBL_MAX;
      for(int i = newest; i <= b; i++)
      {
         b_hi = MathMax(b_hi, r[i].high);
         b_lo = MathMin(b_lo, r[i].low);
         body_hi = MathMax(body_hi, MathMax(r[i].open, r[i].close));
         body_lo = MathMin(body_lo, MathMin(r[i].open, r[i].close));
      }
      // --- leg out: up to 3 candles after the base ---
      int f = newest - 1;
      double fr = r[f].high - r[f].low;
      int out = 0;
      if(fr > 0.0 && MathAbs(r[f].close - r[f].open) >= 0.5 * fr)
         out = (r[f].close > r[f].open) ? 1 : -1;
      double disp = 0.0;
      int out_end = f;
      double out_body_max = 0.0;
      if(out != 0)
      {
         for(int i = f; i >= MathMax(0, f - 2); i--)
         {
            double rg = r[i].high - r[i].low;
            if(rg > 0.0 && ((out > 0) == (r[i].close > r[i].open)))
               out_body_max = MathMax(out_body_max, MathAbs(r[i].close - r[i].open) / rg);
            double d = (out > 0) ? (r[i].close - b_hi) : (b_lo - r[i].close);
            if(d > disp) { disp = d; out_end = i; }
         }
      }
      if(out == 0 || disp < ZIDispATR * atr)
      {
         b--;
         continue;
      }
      // --- leg in: the 3 candles before the base ---
      double in_move = r[b + 1].close - r[b + 3].open;
      int in_dir = (MathAbs(in_move) >= 0.5 * atr) ? ((in_move > 0.0) ? 1 : -1) : 0;
      if(in_dir == 0)
      {
         b -= len;
         continue;
      }
      int model = (out > 0) ? ((in_dir > 0) ? ZI_RBR : ZI_DBR) : ((in_dir > 0) ? ZI_RBD : ZI_DBD);
      // --- bounds ---
      double prox, dist;
      if(out > 0)
      {
         dist = b_lo;
         prox = (body_hi - b_lo >= 0.1 * atr) ? body_hi : b_hi;
         if(prox - dist > 1.5 * atr) dist = prox - 1.5 * atr;
      }
      else
      {
         dist = b_hi;
         prox = (b_hi - body_lo >= 0.1 * atr) ? body_lo : b_lo;
         if(dist - prox > 1.5 * atr) dist = prox + 1.5 * atr;
      }
      // --- origin: liquidity taken at the base, and the leg out breaking the prior structure ---
      double o_hi = -DBL_MAX, o_lo = DBL_MAX;
      for(int i = b + 1; i <= MathMin(n - 1, b + 10); i++)
      {
         o_hi = MathMax(o_hi, r[i].high);
         o_lo = MathMin(o_lo, r[i].low);
      }
      bool swept = (out > 0) ? (b_lo < o_lo) : (b_hi > o_hi);
      bool bos = false;
      for(int i = f; i >= out_end && !bos; i--)
         bos = (out > 0) ? (r[i].close > o_hi) : (r[i].close < o_lo);
      // --- lifecycle over the closed bars after the leg out ---
      bool broken = false;
      int touches = 0;
      bool inside = false;
      double react = 0.0, last_react = 0.0;
      for(int j = out_end - 1; j >= 0; j--)
      {
         if(out > 0 ? (r[j].close < dist) : (r[j].close > dist)) { broken = true; break; }
         bool in_now = (out > 0) ? (r[j].low <= prox) : (r[j].high >= prox);
         if(in_now && !inside) { touches++; last_react = 0.0; }
         inside = in_now;
         if(touches > 0)
         {
            double away = (out > 0) ? (r[j].high - prox) : (prox - r[j].low);
            last_react = MathMax(last_react, away / atr);
            react = MathMax(react, last_react);
         }
      }
      int age = b;
      if(broken || age > max_age)
      {
         b -= len;
         continue;
      }
      int state = (touches == 0) ? ZI_FRESH :
                  ((touches == 1 || (touches == 2 && last_react >= 1.0)) ? ZI_TESTED : ZI_WEAKENED);
      if(touches >= 3) state = ZI_WEAKENED;

      // --- score (owner's weights) ---
      double s = 0.0;
      s += MathMin(20.0, 10.0 + 10.0 * MathMax(0.0, (disp / atr - ZIDispATR) / 1.5));          // origin & impulse
      s += (swept ? 10.0 : 0.0) + (bos ? 10.0 : 0.0);                                            // liquidity
      s += (bos ? 12.0 : 0.0) + ((MBTFStateSign(tfi) == out || MBTFStateSign(MathMin(4, tfi + 1)) == out) ? 8.0 : 0.0);   // structure
      s += (state == ZI_FRESH) ? 15.0 : ((state == ZI_TESTED) ? ((react >= 1.0) ? 10.0 : 6.0) : 2.0);   // freshness
      double tight = (b_hi - b_lo) / atr;
      s += 8.0 * MathMin(1.0, out_body_max / 0.7) + 7.0 * MathMax(0.0, MathMin(1.0, (1.2 - tight) / 0.8));   // candles
      double width = MathAbs(prox - dist);
      s += ((width <= 0.8 * atr) ? 5.0 : 2.0) + ((width > 0.0 && spread <= 0.25 * width) ? 5.0 : 1.0);       // location

      int k = G_ZI_N++;
      G_ZI_PROX[k] = prox; G_ZI_DIST[k] = dist; G_ZI_DIR[k] = out; G_ZI_MODEL[k] = model;
      G_ZI_TFI[k] = tfi; G_ZI_T[k] = r[b].time; G_ZI_STATE[k] = state; G_ZI_TOUCH[k] = touches;
      G_ZI_SCORE[k] = (int)MathRound(MathMin(100.0, s));
      b -= len;
   }
}

// Once per tick; each TF is rebuilt only when it has a new closed bar.
void ZIUpdate()
{
   if(!EnableZoneIntelligence)
   {
      G_ZI_N = 0;
      return;
   }
   int lb[MB_TF_COUNT]  = {0, 288, 192, 240, 180};   // M5 1 day, M15 2 days, H1 10 days, H4 30 days
   int age[MB_TF_COUNT] = {0, 288, 192, 240, 180};
   for(int tfi = 1; tfi <= 4; tfi++)
   {
      datetime bt = iTime(_Symbol, MBTF(tfi), 0);
      if(bt <= 0 || bt == G_ZI_BAR[tfi])
         continue;
      G_ZI_BAR[tfi] = bt;
      ZIDropTF(tfi);
      ZIScanTF(tfi, lb[tfi], age[tfi]);
   }
}

string ZIDescribe(const int k)
{
   if(k < 0 || k >= G_ZI_N)
      return "";
   return StringFormat("%s %s %s %s-%s %d/100 %s", ZIModelName(G_ZI_MODEL[k]), (G_ZI_DIR[k] > 0 ? "demand" : "supply"),
                       MBTFName(G_ZI_TFI[k]), DoubleToString(MathMin(G_ZI_PROX[k], G_ZI_DIST[k]), _Digits),
                       DoubleToString(MathMax(G_ZI_PROX[k], G_ZI_DIST[k]), _Digits), G_ZI_SCORE[k], ZIStateName(G_ZI_STATE[k]));
}

// The best zone of dir's OWN side (demand for a BUY) that price stands in or within reach of its proximal
// edge (not beyond its distal edge). Highest score; on a tie the higher TF. -1 = none.
int ZIOwnZoneAt(const int dir, const double px, const double reach, const int min_score)
{
   if(!EnableZoneIntelligence || dir == 0 || px <= 0.0)
      return -1;
   int best = -1;
   for(int k = 0; k < G_ZI_N; k++)
   {
      if(G_ZI_DIR[k] != dir || G_ZI_SCORE[k] < min_score)
         continue;
      bool is_near = (dir > 0) ? (px >= G_ZI_DIST[k] && px <= G_ZI_PROX[k] + reach)
                            : (px <= G_ZI_DIST[k] && px >= G_ZI_PROX[k] - reach);
      if(!is_near)
         continue;
      if(best < 0 || G_ZI_SCORE[k] > G_ZI_SCORE[best] || (G_ZI_SCORE[k] == G_ZI_SCORE[best] && G_ZI_TFI[k] > G_ZI_TFI[best]))
         best = k;
   }
   return best;
}

// The best FRESH zone of the other side ahead of dir (supply above a BUY) within reach, or price inside it.
int ZIOpposingAhead(const int dir, const double px, const double reach, const int min_score)
{
   if(!EnableZoneIntelligence || dir == 0 || px <= 0.0)
      return -1;
   int best = -1;
   for(int k = 0; k < G_ZI_N; k++)
   {
      if(G_ZI_DIR[k] != -dir || G_ZI_SCORE[k] < min_score || G_ZI_STATE[k] != ZI_FRESH)
         continue;
      bool ahead = (dir > 0) ? (G_ZI_PROX[k] >= px - 1e-9 ? (G_ZI_PROX[k] - px <= reach) : (px <= G_ZI_DIST[k]))
                             : (G_ZI_PROX[k] <= px + 1e-9 ? (px - G_ZI_PROX[k] <= reach) : (px >= G_ZI_DIST[k]));
      if(!ahead)
         continue;
      if(best < 0 || G_ZI_SCORE[k] > G_ZI_SCORE[best])
         best = k;
   }
   return best;
}

// Panel: the best demand at / below price and the best supply at / above it.
string ZIPanelText()
{
   if(!EnableZoneIntelligence)
      return "";
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int bd = -1, bs = -1;
   double dd = DBL_MAX, ds = DBL_MAX;
   for(int k = 0; k < G_ZI_N; k++)
   {
      if(G_ZI_SCORE[k] < ZIGridMinScore)
         continue;
      if(G_ZI_DIR[k] > 0 && px >= G_ZI_DIST[k])
      {
         double d = MathMax(0.0, px - G_ZI_PROX[k]);
         if(d < dd || (d == dd && bd >= 0 && G_ZI_SCORE[k] > G_ZI_SCORE[bd])) { dd = d; bd = k; }
      }
      if(G_ZI_DIR[k] < 0 && px <= G_ZI_DIST[k])
      {
         double d = MathMax(0.0, G_ZI_PROX[k] - px);
         if(d < ds || (d == ds && bs >= 0 && G_ZI_SCORE[k] > G_ZI_SCORE[bs])) { ds = d; bs = k; }
      }
   }
   return StringFormat("Zona: %s | %s", (bd >= 0 ? ZIDescribe(bd) : "demand yo'q"), (bs >= 0 ? ZIDescribe(bs) : "supply yo'q"));
}
