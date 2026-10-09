//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20c_Location_Exhaustion                         |
//| Plan stage 2: entry location, late-entry guard, exhaustion       |
//| (reversal) pressure, taken-liquidity guard, counter-trend tax.   |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// "Strong signal != good entry." The 4081.173 SELL came at the bottom of a $100 fall, a few dollars
// above the 4070 lows the whole fall was heading for; the 4142 SELL came after the sell-side
// liquidity below had already been taken and reclaimed. Both read "the market is falling -> SELL".
// This layer asks the second question: is there still room to sell, and is selling still in control?
//
//  LEG / LOCATION   the leg toward dir is measured from its origin (the 6-hour extreme it started
//                   from) to its target (the nearest support / pool / range edge ahead). Travelled
//                   share >= LateLegPct of a leg of at least LateLegMinATR15 = LATE: no new entry
//                   that way (a fresh pullback lowers the share by itself).
//  EXHAUSTION       pressure against continuing dir, 0..100: momentum decay (20), liquidity taken
//                   the other way (20), failed continuation (20), rejection candle (15), reversal
//                   maturity / micro structure the other way (15), location (10). >= ExhaustBlockScore
//                   blocks new entries that way (it is NOT a reverse signal - the reversal needs its
//                   own proof); >= ExhaustCautionScore costs judge quality.
//  TAKEN LIQUIDITY  the liquidity ahead was swept and reclaimed (and the sweep has not failed): the
//                   move's target is spent - no new entry that way at it.
//  COUNTER-TREND    against a strong bias, without a mature reversal, the judge asks CounterTrendTax
//                   more quality.
//
// Speed: origin, target and pressure are read once per M1 bar; per tick only the travelled share is
// recomputed from the cached numbers.

input group "BRAIN ▸ Entry location & exhaustion"
// EnableLateEntryGuard: KECH KIRISH HIMOYASI: oyoq maqsadigacha LateLegPct% yurgan bo'lsa - shu tomonga yangi kirish yo'q (4081 tubida SELL xatosi)
input bool   EnableLateEntryGuard      = true;   // Enable late entry guard
// LateLegPct: Oyoqning shuncha foizi o'tilgan bo'lsa - kech
input double LateLegPct                = 85.0;   // Late leg %
// LateLegMinATR15: ... va oyoq kamida shuncha ATR(M15) bo'lsa (kichik harakatda bu qoida ishlamaydi)
input double LateLegMinATR15           = 2.5;   // Late leg min ATR 15
// ExhaustBlockScore: CHARCHASH bosimi shundan yuqori - shu tomonga yangi kirish yo'q (teskari savdo emas)
input int    ExhaustBlockScore         = 70;   // Exhaust block score
// ExhaustCautionScore: Shundan yuqori - hakam sifatiga jarima
input int    ExhaustCautionScore       = 50;   // Exhaust caution score
// EnableTakenLiquidityGuard: Oldindagi likvidlik allaqachon olingan va qaytarilgan bo'lsa - shu tomonga kirish yo'q (4142 xatosi)
input bool   EnableTakenLiquidityGuard = true;   // Enable taken liquidity guard
// TakenLiqRoomMult: the guard blocks only when the room to the taken level is less than (spread + TP) x this - with room for the TP the trade does not need the spent target
input double TakenLiqRoomMult          = 1.2;   // Taken liquidity: block when room < (spread + TP) x this
// TakenLiqBlockATR5: ... and always within this many ATR(M5) of the taken level (the reversal zone right under / over it)
input double TakenLiqBlockATR5         = 0.5;   // Taken liquidity: always block within ATR(M5) x this
// TakenLiqRangeMinutes: in a RANGE / COMPRESSION regime a taken edge is spent for this long (60 min in a trend) - range edges are retested every few minutes
input int    TakenLiqRangeMinutes      = 15;   // Taken liquidity memory in a range (min)
// CounterTrendTax: Kuchli biasga qarshi (yetilgan burilishsiz) kirishga sifat talabi shuncha ball yuqori
input int    CounterTrendTax           = 10;   // Counter trend tax

double   G_LX_ORIGIN[2];        // leg origin per direction (0 = SELL leg, 1 = BUY leg)
double   G_LX_TARGET[2];        // what the leg is heading for, 0 = nothing found
string   G_LX_TARGET_WHAT[2];
int      G_LX_PRESS[2];         // exhaustion pressure against continuing that way
string   G_LX_PRESS_WHY[2];
int      G_LX_PRESS_HIST[2][4]; // the pressure at the last four M5 bars (early warning)
bool     G_LX_TAKEN[2];         // the liquidity ahead was taken and reclaimed
string   G_LX_TAKEN_WHY[2];
double   G_LX_TAKEN_EXT[2];     // the swept extreme - the obstacle the room is measured to
double   G_LX_TP_NEED = 0.0;    // (spread + TP) x TakenLiqRoomMult, points - refreshed once per M1 bar
datetime G_LX_BAR    = 0;
datetime G_LX_BAR_M5 = 0;

int MBLxK(const int dir) { return (dir > 0) ? 1 : 0; }

// The nearest MAJOR level ahead of price in dir - what the leg is heading for: the dealing range,
// H4 and regime box edges, and M15+ / key (PDH, PDL, Asia) liquidity. Minor zones are left to the
// council (a zone right in front) - with them every trend leg would read "late" after its first leg.
double MBLxTargetAhead(const int dir, const double px, string &what)
{
   what = "";
   double best = 0.0;
   double c[5];
   string w[5] = {"-", "dealing range", "H4 qutisi", "rejim qutisi", "likvidlik"};
   c[0] = 0.0;
   c[1] = (dir > 0) ? G_MB_DR_HI : G_MB_DR_LO;
   c[2] = (dir > 0) ? G_MB_H4_HI : G_MB_H4_LO;
   c[3] = (dir > 0) ? G_MB_RG_HI : G_MB_RG_LO;
   c[4] = 0.0;
   for(int i = 0; i < G_MB_LP_N; i++)
   {
      if(G_MB_LP_DONE[i] || G_MB_LP_SIDE[i] != dir) continue;
      if(G_MB_LP_TFI[i] < 2 && G_MB_LP_KIND[i] != 1) continue;   // M15+ swings and key levels only
      double L = G_MB_LP_LEVEL[i];
      if(dir * (L - px) > 0.0 && (c[4] <= 0.0 || MathAbs(L - px) < MathAbs(c[4] - px)))
         c[4] = L;
   }
   // Plan stage 3: the nearest MAJOR+ untaken level on the liquidity map ahead.
   double lq = MBLqNearestAhead(dir, px, 3);
   if(lq > 0.0 && (c[4] <= 0.0 || MathAbs(lq - px) < MathAbs(c[4] - px)))
      c[4] = lq;
   for(int k = 0; k < 5; k++)
   {
      if(c[k] <= 0.0 || dir * (c[k] - px) <= 0.0) continue;
      if(best <= 0.0 || MathAbs(c[k] - px) < MathAbs(best - px))
      {
         best = c[k];
         what = w[k];
      }
   }
   return best;
}

// Share of the leg toward dir already travelled (0..100+), and the leg size in ATR(M15).
double MBLegPct(const int dir, double &leg_atr15)
{
   leg_atr15 = 0.0;
   int k = MBLxK(dir);
   // AUDIT FIX (B5): origin and target are bid-built levels - measure from the bid on both sides
   // (the ask made every BUY look a spread later in its leg than the same SELL).
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr15 = G_MB_ATR[2] * _Point;
   if(px <= 0.0 || atr15 <= 0.0 || G_LX_ORIGIN[k] <= 0.0)
      return 0.0;
   double travelled = dir * (px - G_LX_ORIGIN[k]);
   if(travelled <= 0.0)
      return 0.0;
   leg_atr15 = travelled / atr15;
   double T = G_LX_TARGET[k];
   if(T <= 0.0 || dir * (T - px) <= 0.0)
      return 0.0;
   double whole = dir * (T - G_LX_ORIGIN[k]);
   return (whole > 0.0) ? 100.0 * travelled / whole : 0.0;
}

// Pressure against continuing dir, 0..100.
int MBLxPressure(const int dir, string &why)
{
   why = "";
   double atr5 = G_MB_ATR[1] * _Point;
   if(atr5 <= 0.0)
      return 0;
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int p = 0;
   double leg15 = 0.0;
   double pct = MBLegPct(dir, leg15);

   // 1. Momentum decay: the last three M5 bodies its way against the three before, and a late impulse.
   double br = 0.0, bp = 0.0;
   int nr = 0, np = 0;
   for(int s = 1; s <= 6; s++)
   {
      double o = iOpen(_Symbol, PERIOD_M5, s), c = iClose(_Symbol, PERIOD_M5, s);
      if(o <= 0.0 || dir * (c - o) <= 0.0) continue;
      if(s <= 3) { br += MathAbs(c - o); nr++; } else { bp += MathAbs(c - o); np++; }
   }
   int decay = 0;
   if(leg15 >= 1.5 && np > 0 && (nr == 0 || (br / MathMax(1, nr)) < 0.6 * (bp / np))) decay += 12;
   if(G_MB_IMP_DIR[1] == dir && G_MB_SPEED[1] >= MB_SPEED_LATE) decay += 8;
   if(G_MB_ACCEL[1] < 0 && G_MB_ACCEL_DIR[1] == dir) decay += 4;
   decay = MathMin(20, decay);
   if(decay > 0) { p += decay; why += StringFormat("momentum so'nmoqda %d; ", decay); }

   // 2. Liquidity taken the other way near price (a sweep of the lows for a SELL) in the last hour.
   int liq = 0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != -dir) continue;
      int ty = G_MB_EV[idx].type;
      if(ty != MB_EV_LIQ_SWEEP && ty != MB_EV_FAKE_BREAK) continue;
      // AUDIT FIX (B6): age from the bar's CLOSE (event time is its open) - an H1 event was over an
      // hour "old" the moment it was detected and never counted.
      if(TimeCurrent() - (G_MB_EV[idx].time + PeriodSeconds(MBEventTF(G_MB_EV[idx].tfi))) > 3600) continue;
      if(MathAbs(G_MB_EV[idx].level - px) > 1.5 * atr5) continue;
      liq = MathMax(liq, (MBEventRank(G_MB_EV[idx].tfi) >= 1) ? 20 : 12);
   }
   if(G_MB_LSW_DIR == -dir && (TimeCurrent() - G_MB_LSW_TIME) <= 600) liq = 20;
   // Plan stage 3: the liquidity map's combined sweep the other way (MAJOR+ = full weight, a strong
   // wick or a confirmed one more than a plain one).
   {
      datetime lt = 0;
      int lc = 0, lq = 0;
      double le = 0.0;
      if(MBLqSweepFor(-dir, 1, 3600, lt, lc, le, lq) && MathAbs(le - px) <= 1.5 * atr5)
         liq = MathMax(liq, (lc >= 3) ? 20 : ((lq >= 2) ? 15 : 10));
   }
   if(liq > 0) { p += liq; why += StringFormat("qarshi likvidlik olindi %d; ", liq); }

   // 3. Failed continuation: the leg's extreme is four+ M5 bars old with price still near it, or the
   //    new extremes are wicks that closed back.
   int fail = 0;
   int ie = (dir < 0) ? iLowest(_Symbol, PERIOD_M5, MODE_LOW, 24, 1) : iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 24, 1);
   if(ie >= 4 && leg15 >= 1.0)
   {
      double ex = (dir < 0) ? iLow(_Symbol, PERIOD_M5, ie) : iHigh(_Symbol, PERIOD_M5, ie);
      if(ex > 0.0 && MathAbs(px - ex) <= 0.6 * atr5) fail += 12;
   }
   int wicks = 0;
   for(int s = 1; s <= 4; s++)
   {
      double l = (dir < 0) ? iLow(_Symbol, PERIOD_M5, s) : iHigh(_Symbol, PERIOD_M5, s);
      double lp = (dir < 0) ? iLow(_Symbol, PERIOD_M5, s + 1) : iHigh(_Symbol, PERIOD_M5, s + 1);
      double c = iClose(_Symbol, PERIOD_M5, s);
      if(l > 0.0 && lp > 0.0 && dir * (l - lp) > 0.0 && dir * (c - lp) < 0.0) wicks++;
   }
   if(wicks >= 1) fail += 8;
   fail = MathMin(20, fail);
   if(fail > 0) { p += fail; why += StringFormat("davom eta olmayapti %d; ", fail); }

   // 4. A rejection / exhaustion candle against it.
   int rej = 0;
   for(int k = 1; k >= 0 && rej == 0; k--)
   {
      int it = G_MB_LAST[k].intent;
      if(G_MB_LAST[k].dir == -dir && (it == MB_CI_REJECTION || it == MB_CI_LIQ_GRAB || it == MB_CI_EXHAUSTION || it == MB_CI_ABSORPTION))
         rej = (k == 1) ? 15 : 8;
   }
   if(rej > 0) { p += rej; why += StringFormat("rad etish shami %d; ", rej); }

   // 5. The structure turning the other way.
   int st = MBStructStageFor(-dir);
   int ms = (st >= 3) ? 15 : ((st == 2) ? 10 : ((st == 1) ? 5 : 0));
   if(ms == 0 && G_MB_TREND[0] == -dir) ms = 5;
   if(ms > 0) { p += ms; why += StringFormat("mikro tuzilma qarshi %d; ", ms); }

   // 6. Location: deep in the leg.
   int loc = (pct >= 85.0) ? 10 : ((pct >= 70.0) ? 5 : 0);
   if(loc > 0) { p += loc; why += StringFormat("oyoq %.0f%% %d; ", pct, loc); }

   return MathMin(100, p);
}

// The liquidity ahead was swept and reclaimed, and the sweep has not failed (no M5 close beyond its
// extreme since): the move's target is spent.
bool MBLxTakenAhead(const int dir, string &why, double &ext_out)
{
   why = "";
   ext_out = 0.0;
   // RANGE FIX: a range edge is retested every few minutes - an hour-long memory kept the BUY shut at
   // the bottom of a $7 range because its top had been swept. In a range the memory is short.
   int max_age = (EnableRegimePlaybook && (G_MB_RG == MB_RG_RANGE || G_MB_RG == MB_RG_COMPRESSION))
                 ? MathMax(1, TakenLiqRangeMinutes) * 60 : 3600;
   double atr5 = G_MB_ATR[1] * _Point;
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr5 <= 0.0 || px <= 0.0)
      return false;
   // Plan stage 3: the liquidity map's sweep ahead (not a trap - the map marks a sweep accepted beyond).
   {
      datetime lt = 0;
      int lc = 0, lq = 0;
      double le = 0.0;
      if(MBLqSweepFor(-dir, 2, max_age, lt, lc, le, lq) && dir * (px - le) <= 0.0 && MathAbs(px - le) <= 1.0 * atr5)
      {
         ext_out = le;
         why = StringFormat("%s likvidlik (%s) olindi va qaytarildi", (dir < 0 ? "sell-side" : "buy-side"), MBLqClassName(lc));
         return true;
      }
   }
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != -dir) continue;
      int ty = G_MB_EV[idx].type;
      if(ty != MB_EV_LIQ_SWEEP && ty != MB_EV_FAKE_BREAK) continue;
      // AUDIT FIX (B6): aged from the bar's close - otherwise H1 events (and M15 ones in a range, with the
      // 15-min memory) were dead on arrival.
      if(MBEventRank(G_MB_EV[idx].tfi) < 1 ||
         TimeCurrent() - (G_MB_EV[idx].time + PeriodSeconds(MBEventTF(G_MB_EV[idx].tfi))) > max_age) continue;
      double ext = G_MB_EV[idx].extreme;
      // Price still near it (within one M5 ATR of the swept extreme, on the reclaimed side).
      if(ext <= 0.0 || dir * (px - ext) > 0.0 || MathAbs(px - ext) > 1.0 * atr5) continue;
      bool failed = false;
      int sh = iBarShift(_Symbol, PERIOD_M5, G_MB_EV[idx].time, false);
      for(int s = MathMax(1, sh - 1); s >= 1 && !failed; s--)
      {
         double c = iClose(_Symbol, PERIOD_M5, s);
         if(c > 0.0 && dir * (c - ext) > 0.1 * atr5) failed = true;   // closed beyond: the sweep failed, the move goes on
      }
      if(failed) continue;
      ext_out = ext;
      why = StringFormat("%s %s %s @ %s olindi va qaytarildi", MBTFName(G_MB_EV[idx].tfi), (dir < 0 ? "sell-side" : "buy-side"),
                         MBEventName(ty), DoubleToString(G_MB_EV[idx].level, _Digits));
      return true;
   }
   return false;
}

void MBLocationUpdate()
{
   if(!EnableMarketBrain || !EnableMarketBrainEngines)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 <= 0 || m1 == G_LX_BAR)
      return;
   G_LX_BAR = m1;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;
   // AUDIT FIX: the TP the entry will really carry (cashback: the rebate target; otherwise the basket TP,
   // not the micro TP - with the micro figure the guard released where the real TP reached the taken level).
   double tp_pts = BaseBasketTPPoints();
   G_LX_TP_NEED = MathMax(MathMax(0.0, TakenLiqRoomMult) * ((double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) + MathMax(0.0, tp_pts)),
                          MathMax(0.0, TakenLiqBlockATR5) * G_MB_ATR[1]);
   bool new_m5 = false;
   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 > 0 && m5 != G_LX_BAR_M5) { G_LX_BAR_M5 = m5; new_m5 = true; }
   for(int k = 0; k <= 1; k++)
   {
      int dir = (k == 1) ? 1 : -1;
      // Origin: the six-hour extreme the leg toward dir started from.
      int io = (dir < 0) ? iHighest(_Symbol, PERIOD_M15, MODE_HIGH, 24, 0) : iLowest(_Symbol, PERIOD_M15, MODE_LOW, 24, 0);
      G_LX_ORIGIN[k] = (io >= 0) ? ((dir < 0) ? iHigh(_Symbol, PERIOD_M15, io) : iLow(_Symbol, PERIOD_M15, io)) : 0.0;
      G_LX_TARGET[k] = MBLxTargetAhead(dir, bid, G_LX_TARGET_WHAT[k]);
      G_LX_PRESS[k] = MBLxPressure(dir, G_LX_PRESS_WHY[k]);
      G_LX_TAKEN[k] = EnableTakenLiquidityGuard && MBLxTakenAhead(dir, G_LX_TAKEN_WHY[k], G_LX_TAKEN_EXT[k]);
      if(new_m5)
      {
         for(int h = 3; h > 0; h--) G_LX_PRESS_HIST[k][h] = G_LX_PRESS_HIST[k][h - 1];
         G_LX_PRESS_HIST[k][0] = G_LX_PRESS[k];
      }
   }
}

// Early warning: the pressure against dir rose by 20+ over the last three M5 bars.
bool MBLxRising(const int dir)
{
   int k = MBLxK(dir);
   return (G_LX_PRESS_HIST[k][3] > 0 || G_LX_PRESS_HIST[k][0] > 0) && (G_LX_PRESS[k] - G_LX_PRESS_HIST[k][3] >= 20);
}

int MBExhaustPressure(const int dir) { return (dir == 0) ? 0 : G_LX_PRESS[MBLxK(dir)]; }

// True = no new entry toward dir here (late in the leg, exhausted, or its target already taken).
bool MBLateBlocks(const int dir, string &why, string &uz)
{
   why = "";
   uz = "";
   if(!EnableMarketBrain || !EnableMarketBrainEngines || dir == 0 || G_LX_BAR <= 0)
      return false;
   int k = MBLxK(dir);
   string side = (dir > 0) ? "BUY" : "SELL";
   // ROOM FIX: the guard is about the move's target, but a scalp only needs its TP. With room for
   // (spread + TP) x TakenLiqRoomMult before the taken level (live price), and outside the reversal
   // zone of TakenLiqBlockATR5 x ATR(M5) under / over it, the entry is not blocked.
   bool taken_close = G_LX_TAKEN[k];
   // EVIDENCE GATE: when the taken-target filter stands aside on this side (its refusals needed the grid
   // no more often than the trades taken), only the reversal zone right under / over the level blocks.
   bool eg_taken = taken_close && MBEGSkip(EG_TAKEN, dir);
   double need_room = eg_taken ? MathMax(0.0, TakenLiqBlockATR5) * G_MB_ATR[1] : G_LX_TP_NEED;
   if(taken_close && G_LX_TAKEN_EXT[k] > 0.0 && need_room > 0.0)
   {
      // AUDIT FIX (B5): from the bid on both sides - the need already holds the spread; measuring a BUY
      // from the ask counted it twice and refused BUYs where the mirrored SELL passed.
      double epx = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double room = dir * (G_LX_TAKEN_EXT[k] - epx) / _Point;
      if(epx > 0.0 && room >= need_room)
         taken_close = false;
   }
   if(taken_close)
   {
      why = StringFormat("taken liquidity: %s - the %s target is spent", G_LX_TAKEN_WHY[k], side);
      uz = "oldindagi likvidlik olingan";
      return true;
   }
   if(ExhaustBlockScore > 0 && G_LX_PRESS[k] >= ExhaustBlockScore &&
      !(G_LX_PRESS[k] < ExhaustBlockScore + 15 && MBEGSkip(EG_EXHAUST, dir)))   // evidence: +15 room, never fully off
   {
      why = StringFormat("exhaustion %d/100 against more %s (%s)", G_LX_PRESS[k], side, G_LX_PRESS_WHY[k]);
      uz = StringFormat("charchash %d", G_LX_PRESS[k]);
      return true;
   }
   if(EnableLateEntryGuard)
   {
      double leg15 = 0.0;
      double pct = MBLegPct(dir, leg15);
      if(pct >= LateLegPct && leg15 >= LateLegMinATR15 && !MBEGSkip(EG_LATE, dir))
      {
         why = StringFormat("late entry: the %s leg has travelled %.0f%% of its way to %s %s (%.1f ATR15)", side, pct,
                            G_LX_TARGET_WHAT[k], DoubleToString(G_LX_TARGET[k], _Digits), leg15);
         uz = StringFormat("kech: oyoqning %.0f%% i", pct);
         return true;
      }
   }
   return false;
}

string MBLocationPanelText()
{
   string t = "Joy:";
   for(int k = 0; k <= 1; k++)
   {
      int dir = (k == 1) ? 1 : -1;
      double leg15 = 0.0;
      double pct = MBLegPct(dir, leg15);
      string g = "yaxshi";
      if(G_LX_TAKEN[k]) g = "likvidlik olingan";
      else if(pct >= LateLegPct && leg15 >= LateLegMinATR15) g = "juda kech";
      else if(pct >= 70.0 && leg15 >= 1.5) g = "kech";
      else if(pct >= 50.0) g = "o'rtacha";
      t += StringFormat("%s %s %s · charchash %d%s", (k == 0 ? "" : "  |"), (dir > 0 ? " BUY" : " SELL"), g, G_LX_PRESS[k],
                        (MBLxRising(dir) ? "↑" : ""));
   }
   return t;
}
