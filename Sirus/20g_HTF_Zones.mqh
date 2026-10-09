//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20g_HTF_Zones                                   |
//| Higher-timeframe supply / demand zones and the M15 lower-high /   |
//| higher-low structure rule - WHERE an entry may not stand.         |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// 09-Oct 08:33: BUY 4196.811 at 77% of the H1 dealing range, under the 4207.98 top that had been swept
// at 06:00 and under the 4201.6 lower high of 08:18, inside the H4 supply the owner had drawn
// (4180..4228). The robot's zone map is a list of single swing levels - it had no idea of a supply ZONE
// with a width, nor of the M15 structure turning (a lower high under the top). Two protected rules:
//
//  HTF ZONES   H1 / H4 order blocks: the last candle before a displacement that ran HTFZoneDispATR x ATR
//              away and broke the candle's own extreme. Fresh until a close beyond its far side, worn
//              out after HTFZoneMaxTouches visits. No BUY inside a fresh supply zone or within
//              HTFZoneApproachATR15 x ATR(M15) under it, unless an M15 close has already gone above it
//              (mirrored for SELL and demand).
//  LOWER HIGH  the M15 top of the last six hours, a real pullback from it (>= 0.8 ATR15), then a lower
//              high (>= 0.3 ATR15 lower): while the last M5 close is still under that lower high and
//              price stands in the premium half of the H1 dealing range, no BUY - the market has
//              stopped making higher highs (mirrored: higher low in the discount half, no SELL).
//
// Both are direction rules: the evidence gates never relax them. Speed: zones once per H1 bar, the
// structure once per M5 bar; the checks are a few comparisons.

input group "BRAIN ▸ HTF zones & structure"
// EnableHTFZones: H1/H4 supply-demand zonalari: yangi supply ichida yoki ostida BUY yo'q (M15 undan yuqorida yopilmaguncha), demand ichida yoki ustida SELL yo'q
input bool   EnableHTFZones          = true;   // HTF supply / demand zones (H1, H4)
// HTFZoneDispATR: Zona: asos shamidan keyingi 3 bar ichida narx shuncha ATR uzoqlashgan bo'lsin
input double HTFZoneDispATR          = 1.5;   // Zone: displacement after the base (ATR of its TF)
// HTFZoneApproachATR15: Zonaga shuncha ATR(M15) yaqinlashganda ham to'siladi
input double HTFZoneApproachATR15    = 1.0;   // Blocked this close to the zone (ATR M15)
// HTFZoneMaxTouches: Shuncha marta tegilgan zona eskirgan hisoblanadi
input int    HTFZoneMaxTouches       = 3;   // A zone wears out after this many visits
// EnableLowerHighRule: M15 tepasidan keyin past tepa (lower high) - premium tomonda BUY yo'q; past tubdan keyin baland tub - discount tomonda SELL yo'q
input bool   EnableLowerHighRule     = true;   // M15 lower high / higher low structure rule
input bool   HTFZonePrintOnUse       = true;   // HTF zones print on use (on/off)

#define HZ_MAX 40
double   G_HZ_HI[HZ_MAX];
double   G_HZ_LO[HZ_MAX];
int      G_HZ_DIR[HZ_MAX];      // -1 supply, +1 demand
int      G_HZ_TF[HZ_MAX];       // 60 / 240 (minutes)
datetime G_HZ_T[HZ_MAX];        // base candle time
int      G_HZ_TOUCH[HZ_MAX];
int      G_HZ_N = 0;
datetime G_HZ_BAR = 0;

// Lower-high / higher-low state, per M5 bar: [0] for SELL (higher low under), [1] for BUY (lower high over).
double   G_LH_LEVEL[2];
double   G_LH_TOP[2];
datetime G_LH_BAR = 0;

void MBHTFZoneScan(const ENUM_TIMEFRAMES tf, const int lookback)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, tf, 1, lookback, r);
   double atr = ATRPointsManual(tf, 14, 1) * _Point;
   if(n < 20 || atr <= 0.0)
      return;
   int tfm = PeriodSeconds(tf) / 60;
   for(int b = 4; b < n && G_HZ_N < HZ_MAX; b++)   // newest bases first - they matter most
   {
      // Supply: the base candle, then within three bars a drop of HTFZoneDispATR x ATR below its low.
      double lo3 = MathMin(r[b - 1].low, MathMin(r[b - 2].low, r[b - 3].low));
      double hi3 = MathMax(r[b - 1].high, MathMax(r[b - 2].high, r[b - 3].high));
      int zdir = 0;
      if(r[b].low - lo3 >= HTFZoneDispATR * atr && hi3 <= r[b].high)
         zdir = -1;
      else if(hi3 - r[b].high >= HTFZoneDispATR * atr && lo3 >= r[b].low)
         zdir = 1;
      if(zdir == 0)
         continue;
      double zhi = (zdir < 0) ? r[b].high : MathMax(r[b].open, r[b].close);
      double zlo = (zdir < 0) ? MathMin(r[b].open, r[b].close) : r[b].low;
      if(zhi - zlo < 0.2 * atr)
      {
         if(zdir < 0) zlo = zhi - 0.2 * atr; else zhi = zlo + 0.2 * atr;
      }
      if(zhi - zlo > 1.5 * atr)
      {
         if(zdir < 0) zlo = zhi - 1.5 * atr; else zhi = zlo + 1.5 * atr;
      }
      // Fresh: no close beyond its far side since; visits counted (a new entry into the zone).
      bool broken = false;
      int touches = 0;
      bool inside = false;
      for(int j = b - 4; j >= 0; j--)
      {
         if(zdir < 0 ? (r[j].close > zhi) : (r[j].close < zlo)) { broken = true; break; }
         bool in_now = (zdir < 0) ? (r[j].high >= zlo) : (r[j].low <= zhi);
         if(in_now && !inside) touches++;
         inside = in_now;
      }
      if(broken || touches > MathMax(1, HTFZoneMaxTouches))
         continue;
      int k = G_HZ_N++;
      G_HZ_HI[k] = zhi; G_HZ_LO[k] = zlo; G_HZ_DIR[k] = zdir; G_HZ_TF[k] = tfm; G_HZ_T[k] = r[b].time; G_HZ_TOUCH[k] = touches;
   }
}

void MBHTFZonesUpdate()
{
   if(!EnableHTFZones)
   {
      G_HZ_N = 0;
      return;
   }
   datetime h1 = iTime(_Symbol, PERIOD_H1, 0);
   if(h1 <= 0 || h1 == G_HZ_BAR)
      return;
   G_HZ_BAR = h1;
   G_HZ_N = 0;
   MBHTFZoneScan(PERIOD_H4, 120);   // ~20 days
   MBHTFZoneScan(PERIOD_H1, 240);   // ~10 days
}

// The fresh zone of the other side the entry would stand inside / right under (or over). -1 = none.
int MBHTFZoneAgainst(const int dir, const double px)
{
   double atr15 = G_MB_ATR[2] * _Point;
   if(dir == 0 || px <= 0.0 || atr15 <= 0.0)
      return -1;
   double c15 = iClose(_Symbol, PERIOD_M15, 1);
   int best = -1;
   double best_d = DBL_MAX;
   for(int k = 0; k < G_HZ_N; k++)
   {
      if(G_HZ_DIR[k] != -dir)
         continue;
      double d;
      if(dir > 0)
      {
         if(c15 > G_HZ_HI[k]) continue;                         // already closed above it - taken out
         if(px > G_HZ_HI[k]) continue;
         d = (px >= G_HZ_LO[k]) ? 0.0 : G_HZ_LO[k] - px;      // inside = 0, under = the gap
      }
      else
      {
         if(c15 > 0.0 && c15 < G_HZ_LO[k]) continue;
         if(px < G_HZ_LO[k]) continue;
         d = (px <= G_HZ_HI[k]) ? 0.0 : px - G_HZ_HI[k];
      }
      if(d <= HTFZoneApproachATR15 * atr15 && d < best_d)
      {
         best_d = d;
         best = k;
      }
   }
   return best;
}

bool MBHTFZoneBlocks(const int dir, string &why)
{
   why = "";
   if(!EnableHTFZones || dir == 0)
      return false;
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int k = MBHTFZoneAgainst(dir, px);
   if(k < 0)
      return false;
   why = StringFormat("%s H%d %s zone %s-%s (fresh, %d visits) - no %s until an M15 close %s it",
                      (px >= G_HZ_LO[k] && px <= G_HZ_HI[k]) ? "inside the" : "right at the", G_HZ_TF[k] / 60,
                      (G_HZ_DIR[k] < 0 ? "supply" : "demand"), DoubleToString(G_HZ_LO[k], _Digits), DoubleToString(G_HZ_HI[k], _Digits),
                      G_HZ_TOUCH[k], (dir > 0 ? "BUY" : "SELL"), (dir > 0 ? "above" : "below"));
   return true;
}

// Once per M5 bar: the M15 top of the last six hours and the lower high after it (and the mirror).
void MBLowerHighUpdate()
{
   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 <= 0 || m5 == G_LH_BAR)
      return;
   G_LH_BAR = m5;
   G_LH_LEVEL[0] = 0.0; G_LH_LEVEL[1] = 0.0; G_LH_TOP[0] = 0.0; G_LH_TOP[1] = 0.0;
   double atr15 = G_MB_ATR[2] * _Point;
   if(!EnableLowerHighRule || atr15 <= 0.0)
      return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M15, 1, 24, r);
   if(n < 8)
      return;
   for(int side = 0; side <= 1; side++)
   {
      int up = (side == 1) ? 1 : -1;   // side 1: the top and its lower high (blocks BUY)
      int it = 0;
      for(int i = 1; i < n; i++)
         if(up > 0 ? (r[i].high > r[it].high) : (r[i].low < r[it].low)) it = i;
      if(it < 3)
         continue;                      // the extreme is the current leg - nothing after it yet
      double top = (up > 0) ? r[it].high : r[it].low;
      // The pullback after the top and the best retest after the pullback.
      int ip = it - 1;
      for(int i = it - 1; i >= 0; i--)
         if(up > 0 ? (r[i].low < r[ip].low) : (r[i].high > r[ip].high)) ip = i;
      double pull = (up > 0) ? r[ip].low : r[ip].high;
      if(up * (top - pull) < 0.8 * atr15 || ip == 0)
         continue;
      double lh = (up > 0) ? -DBL_MAX : DBL_MAX;
      for(int i = ip - 1; i >= 0; i--)
         lh = (up > 0) ? MathMax(lh, r[i].high) : MathMin(lh, r[i].low);
      if(lh == DBL_MAX || lh == -DBL_MAX || up * (top - lh) < 0.3 * atr15)
         continue;
      G_LH_LEVEL[side] = lh;
      G_LH_TOP[side] = top;
   }
}

bool MBLowerHighBlocks(const int dir, string &why)
{
   why = "";
   if(!EnableLowerHighRule || dir == 0)
      return false;
   int side = (dir > 0) ? 1 : 0;
   double lh = G_LH_LEVEL[side];
   if(lh <= 0.0)
      return false;
   double c5 = iClose(_Symbol, PERIOD_M5, 1);
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(c5 <= 0.0 || px <= 0.0 || dir * (c5 - lh) > 0.0 || dir * (px - lh) > 0.0)
      return false;                    // an M5 close beyond it already - structure restored
   // Only on the expensive side of the H1 dealing range (premium for BUY, discount for SELL).
   if(G_MB_DR_HI > G_MB_DR_LO && (dir > 0 ? G_MB_DR_POS < 0.55 : G_MB_DR_POS > 0.45))
      return false;
   why = StringFormat("M15 %s %s after the %s %s - no %s until an M5 close %s it",
                      (dir > 0 ? "lower high" : "higher low"), DoubleToString(lh, _Digits), (dir > 0 ? "top" : "bottom"),
                      DoubleToString(G_LH_TOP[side], _Digits), (dir > 0 ? "BUY" : "SELL"), (dir > 0 ? "above" : "below"));
   return true;
}

// Panel: the nearest fresh zones and the structure state.
string MBHTFZoneText()
{
   if(!EnableHTFZones && !EnableLowerHighRule)
      return "";
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int ks = -1, kd = -1;
   for(int k = 0; k < G_HZ_N; k++)
   {
      if(G_HZ_DIR[k] < 0 && G_HZ_HI[k] >= px && (ks < 0 || G_HZ_LO[k] < G_HZ_LO[ks])) ks = k;
      if(G_HZ_DIR[k] > 0 && G_HZ_LO[k] <= px && (kd < 0 || G_HZ_HI[k] > G_HZ_HI[kd])) kd = k;
   }
   string t = "HTF zona:";
   t += (ks >= 0) ? StringFormat(" supply H%d %s-%s", G_HZ_TF[ks] / 60, DoubleToString(G_HZ_LO[ks], _Digits), DoubleToString(G_HZ_HI[ks], _Digits)) : " supply -";
   t += (kd >= 0) ? StringFormat(" · demand H%d %s-%s", G_HZ_TF[kd] / 60, DoubleToString(G_HZ_LO[kd], _Digits), DoubleToString(G_HZ_HI[kd], _Digits)) : " · demand -";
   if(G_LH_LEVEL[1] > 0.0) t += StringFormat(" · past tepa %s", DoubleToString(G_LH_LEVEL[1], _Digits));
   if(G_LH_LEVEL[0] > 0.0) t += StringFormat(" · baland tub %s", DoubleToString(G_LH_LEVEL[0], _Digits));
   return t;
}
