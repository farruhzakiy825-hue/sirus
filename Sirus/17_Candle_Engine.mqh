//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 17_Candle_Engine                                |
//| Market Brain A0: candle intent, pressure, acceleration, impulse  |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// CANDLE INTELLIGENCE ENGINE (engine plan, phase 1b)
//---------------------------------------------------------------------
// A candle never gives a signal on its own - it gives the TIMING. The Market Brain answers
// "where and why?", this engine answers "now?".
//
// For each timeframe (M1, M5, M15, H1, H4), on every new bar, the last closed candles are read:
//   intent    - DISPLACEMENT, REJECTION, ABSORPTION, CONTINUATION, EXHAUSTION, INDECISION,
//               LIQUIDITY GRAB, BREAKOUT, FAKE BREAKOUT - and which side that intent favours
//   anatomy   - body/ATR, range/ATR, body share of the range, where it closed
//   pressure  - bull and bear pressure, 0..100 each, over the last three candles
//   speed     - accelerating / decelerating, from the last five ranges
//   sequence  - the colour story of the last six candles (pressure continuing / reversal forming)
// On M1 and M5 it also tracks the IMPULSE (where the last displacement started, how old it is,
// how far it has run without a real pullback -> EARLY / NORMAL / LATE / EXPIRED) and COMPRESSION.
// The forming M1 candle is read on every tick: an early displacement is flagged before the close,
// and dropped again if the candle gives its strength back.
//
// All sizes are relative to the ATR(14) of the same timeframe, so a quiet Asian tape and a fast
// New York tape are measured with the same rules. This engine only describes; nothing here
// opens, blocks or sizes a trade.
//=====================================================================

input group "41 — MARKET BRAIN: CANDLE + EVENT ENGINE"
input bool   EnableMarketBrainEngines = true;   // Sham va hodisa dvigatellari (faqat o'qiydi, savdo qaroriga hali ta'sir qilmaydi)
input double MBDispBodyATR            = 1.2;    // Displacement: sham tanasi >= ATR x shu
input double MBDispBodyRatio          = 0.60;   // Displacement: tana / diapazon >= shu
input double MBStrongDispBodyATR      = 1.8;    // Kuchli displacement: tana >= ATR x shu
input double MBRejectWickRatio        = 0.50;   // Rejection / liquidity grab: daraja tomonidagi wick >= diapazon x shu
input double MBIndecisionBodyRatio    = 0.25;   // Indecision: tana / diapazon <= shu
input double MBAbsorptionRangeATR     = 1.3;    // Absorption: diapazon >= ATR x shu ...
input double MBAbsorptionBodyRatio    = 0.35;   // ... lekin tana / diapazon <= shu
input double MBLiveDispBodyATR        = 0.8;    // Jonli (yopilmagan) M1 sham: tana >= ATR x shu = early displacement
input int    MBCompressionBars        = 10;     // Compression: oxirgi N bar ...
input double MBCompressionATR         = 1.5;    // ... diapazoni <= ATR x shu
input double MBSpeedEarlyATR          = 1.5;    // Impulse: oxirgi sog'lom pullback'dan yurilgan masofa < shu ATR = EARLY
input double MBSpeedNormalATR         = 2.5;    // < shu = NORMAL
input double MBSpeedLateATR           = 4.0;    // < shu = LATE, undan ko'p = EXPIRED
input bool   MBCandlePrintOnUse       = false;  // Har yangi M5 / M15 / H1 / H4 sham o'qilishini jurnalga yozish
input bool   EnableCandleDirectionLink = true;  // 13-BOSQICH: yo'nalish va sham bog'lanadi - almashuvni sham tasdiqlaydi (A1), M1/M5/M15 bosimi hakamga (A2)
input double MBPressureSideMin        = 15.0;   // Bosim tomoni: |buqa - ayiq| >= shu bo'lsa o'sha tomon (0..100 shkala)
input bool   EnableExhaustionVeto     = true;   // A4: charchagan impuls (3-to'lqin yoki EXPIRED + charchoq / absorbsiya / rejection shami) tomoniga yangi kirish yo'q
input bool   EnableTickVolume         = true;   // 17-BOSQICH (B1): sham tick hajmi - o'rtachadan x0.7 past displacement / breakout / continuation trigger emas, x1.5 baland - kuchli
input double VolumeWeakRatio          = 0.70;
input double VolumeStrongRatio        = 1.50;
input bool   EnableTickFlow           = true;   // 17-BOSQICH (D2): oxirgi soniyalardagi yuqoriga / pastga tiklar nomutanosibligi - kirishga qarshi kuchli oqim bo'lsa kutish
input int    TickFlowSeconds          = 30;     // Oqim shuncha soniya bo'yicha o'lchanadi
input double TickFlowBlock            = 0.40;   // Nomutanosiblik (-1..+1) kirishga qarshi shundan kuchli bo'lsa (va >= 20 tik) - kutish
input bool   EnableRejectionConfirm   = true;   // A5: rejection / liq-grab / exhaustion shami trigger bo'lishi uchun narx uning tanasi o'rtasidan o'tgan va soyasini buzmagan bo'lishi kerak

#define MB_TF_COUNT          5      // M1, M5, M15, H1, H4

#define MB_CI_NONE           0
#define MB_CI_DISPLACEMENT   1
#define MB_CI_REJECTION      2
#define MB_CI_ABSORPTION     3
#define MB_CI_CONTINUATION   4
#define MB_CI_EXHAUSTION     5
#define MB_CI_INDECISION     6
#define MB_CI_LIQ_GRAB       7
#define MB_CI_BREAKOUT       8
#define MB_CI_FAKE_BREAKOUT  9

#define MB_SPEED_NONE        0
#define MB_SPEED_EARLY       1
#define MB_SPEED_NORMAL      2
#define MB_SPEED_LATE        3
#define MB_SPEED_EXPIRED     4

struct SMBCandle
{
   datetime time;
   int      intent;       // MB_CI_*
   int      dir;          // side the intent favours: +1 bullish, -1 bearish, 0 none
   int      candle_color; // +1 green, -1 red, 0 doji
   double   body_atr;     // body / ATR
   double   range_atr;    // range / ATR
   double   body_ratio;   // body / range
   double   close_pos;    // 0 = closed at the low, 1 = at the high
   bool     strong;       // displacement at MBStrongDispBodyATR or more
   double   bull;         // bull pressure of this candle, 0..100
   double   bear;         // bear pressure, 0..100
   double   close;        // close price of the candle
   double   open;
   double   high;
   double   low;
   double   vol_ratio;    // tick volume / average of the 20 candles before it (0 = unknown)
};

SMBCandle G_MB_LAST[MB_TF_COUNT];        // last closed candle per timeframe
double    G_MB_BULL[MB_TF_COUNT];        // 3-candle weighted bull pressure
double    G_MB_BEAR[MB_TF_COUNT];        // 3-candle weighted bear pressure
int       G_MB_ACCEL[MB_TF_COUNT];       // +1 accelerating, -1 decelerating, 0 steady
int       G_MB_ACCEL_DIR[MB_TF_COUNT];   // net direction of the last five candles
string    G_MB_SEQ[MB_TF_COUNT];         // colours of the last six candles, oldest first (G/R/-)
int       G_MB_SEQ_STORY[MB_TF_COUNT];   // 0 none, 1 pressure continues after a pause, 2 reversal forming
int       G_MB_SEQ_DIR[MB_TF_COUNT];
double    G_MB_ATR[MB_TF_COUNT];         // ATR(14) in points, last closed bar
datetime  G_MB_CE_BAR[MB_TF_COUNT];      // bar already processed

// Impulse and compression, [0] = M1, [1] = M5
int       G_MB_IMP_DIR[2];
int       G_MB_IMP_AGE[2];               // bars since the displacement that started it
int       G_MB_IMP_WAVES[2];             // same-direction displacements since then
double    G_MB_IMP_ORIGIN[2];            // price where it started
double    G_MB_IMP_TRAVEL[2];            // ATRs travelled since the last healthy (>=30%) pullback
int       G_MB_SPEED[2];                 // MB_SPEED_*
bool      G_MB_COMPRESSED[2];
double    G_MB_COMP_HI[2];
double    G_MB_COMP_LO[2];

// Forming M1 candle
int       G_MB_LIVE_DIR    = 0;          // early displacement in progress: +1 / -1
int       G_MB_LIVE_FAILED = 0;          // an early displacement this bar gave its strength back: its dir
datetime  G_MB_LIVE_BAR    = 0;

ENUM_TIMEFRAMES MBTF(const int tfi)
{
   switch(tfi)
   {
      case 0: return PERIOD_M1;
      case 1: return PERIOD_M5;
      case 2: return PERIOD_M15;
      case 3: return PERIOD_H1;
      case 4: return PERIOD_H4;
   }
   return PERIOD_M5;
}

string MBTFName(const int tfi)
{
   switch(tfi)
   {
      case 0: return "M1";
      case 1: return "M5";
      case 2: return "M15";
      case 3: return "H1";
      case 4: return "H4";
      case 5: return "KEY";
   }
   return "?";
}

string MBIntentName(const int intent)
{
   switch(intent)
   {
      case MB_CI_DISPLACEMENT:  return "DISPLACEMENT";
      case MB_CI_REJECTION:     return "REJECTION";
      case MB_CI_ABSORPTION:    return "ABSORPTION";
      case MB_CI_CONTINUATION:  return "CONTINUATION";
      case MB_CI_EXHAUSTION:    return "EXHAUSTION";
      case MB_CI_INDECISION:    return "INDECISION";
      case MB_CI_LIQ_GRAB:      return "LIQ-GRAB";
      case MB_CI_BREAKOUT:      return "BREAKOUT";
      case MB_CI_FAKE_BREAKOUT: return "FAKE-BREAKOUT";
   }
   return "plain";
}

string MBSpeedName(const int sp)
{
   switch(sp)
   {
      case MB_SPEED_EARLY:   return "EARLY";
      case MB_SPEED_NORMAL:  return "NORMAL";
      case MB_SPEED_LATE:    return "LATE";
      case MB_SPEED_EXPIRED: return "EXPIRED";
   }
   return "-";
}

string MBSideText(const int dir)
{
   if(dir > 0) return "bull";
   if(dir < 0) return "bear";
   return "-";
}

int MBColor(const MqlRates &bar)
{
   if(bar.close > bar.open) return 1;
   if(bar.close < bar.open) return -1;
   return 0;
}

// Highest high / lowest low of bars [from .. from+count-1]. false when there is no such bar.
bool MBPriorExtremes(const MqlRates &r[], const int n, const int from, const int count, double &hi, double &lo)
{
   hi = -DBL_MAX;
   lo = DBL_MAX;
   int last = MathMin(n - 1, from + count - 1);
   if(from > last)
      return false;
   for(int j = from; j <= last; j++)
   {
      hi = MathMax(hi, r[j].high);
      lo = MathMin(lo, r[j].low);
   }
   return true;
}

// Reads the candle at series index s (s >= 1 for a closed candle). atr is in price units.
void MBReadCandle(const MqlRates &r[], const int n, const int s, const double atr, SMBCandle &out)
{
   out.time = r[s].time;
   out.close = r[s].close;
   out.open = r[s].open;
   out.high = r[s].high;
   out.low = r[s].low;
   out.vol_ratio = 0.0;
   {
      double vs = 0.0;
      int vn = 0;
      for(int j = s + 1; j <= s + 20 && j < n; j++) { vs += (double)r[j].tick_volume; vn++; }
      if(vn >= 5 && vs > 0.0)
         out.vol_ratio = (double)r[s].tick_volume / (vs / vn);
   }
   out.intent = MB_CI_NONE;
   out.dir = 0;
   out.candle_color = MBColor(r[s]);
   out.body_atr = 0.0;
   out.range_atr = 0.0;
   out.body_ratio = 0.0;
   out.close_pos = 0.5;
   out.strong = false;
   out.bull = 0.0;
   out.bear = 0.0;

   double o = r[s].open, h = r[s].high, l = r[s].low, c = r[s].close;
   double range = h - l;
   if(range <= 0.0 || atr <= 0.0)
      return;

   double body  = MathAbs(c - o);
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;
   int    cdir  = out.candle_color;

   out.body_atr   = body / atr;
   out.range_atr  = range / atr;
   out.body_ratio = body / range;
   out.close_pos  = (c - l) / range;

   double ph = 0.0, pl = 0.0;
   bool have_prior = MBPriorExtremes(r, n, s + 1, 10, ph, pl);
   bool have_prev  = (s + 1 < n);

   int intent = MB_CI_NONE;
   int idir = 0;

   // 1. Liquidity grab: took the prior extreme and closed back inside with a long wick there.
   if(have_prior && l < pl && c > pl && lower >= MBRejectWickRatio * range)
   { intent = MB_CI_LIQ_GRAB; idir = 1; }
   else if(have_prior && h > ph && c < ph && upper >= MBRejectWickRatio * range)
   { intent = MB_CI_LIQ_GRAB; idir = -1; }

   // 2. Fake breakout: the previous candle closed beyond its prior extreme, this one closes back
   //    inside with a real body against it.
   if(intent == MB_CI_NONE && have_prev && cdir != 0 && out.body_ratio >= 0.5)
   {
      double ph2 = 0.0, pl2 = 0.0;
      if(MBPriorExtremes(r, n, s + 2, 10, ph2, pl2))
      {
         if(r[s + 1].close > ph2 && c < ph2 && cdir < 0) { intent = MB_CI_FAKE_BREAKOUT; idir = -1; }
         else if(r[s + 1].close < pl2 && c > pl2 && cdir > 0) { intent = MB_CI_FAKE_BREAKOUT; idir = 1; }
      }
   }

   // 3. Displacement: a big body that owns its range and closes at the far end.
   if(intent == MB_CI_NONE && cdir != 0 && body >= MBDispBodyATR * atr && out.body_ratio >= MBDispBodyRatio &&
      ((cdir > 0 && out.close_pos >= 0.75) || (cdir < 0 && out.close_pos <= 0.25)))
   {
      intent = MB_CI_DISPLACEMENT;
      idir = cdir;
      out.strong = (body >= MBStrongDispBodyATR * atr);
   }

   // 4. Absorption: a lot of range, little result. The side whose push failed is the larger wick,
   //    so the candle favours the other side.
   if(intent == MB_CI_NONE && range >= MBAbsorptionRangeATR * atr && out.body_ratio <= MBAbsorptionBodyRatio)
   { intent = MB_CI_ABSORPTION; idir = (lower > upper) ? 1 : -1; }

   // 5. Rejection.
   if(intent == MB_CI_NONE && lower >= MBRejectWickRatio * range && out.close_pos >= 0.60)
   { intent = MB_CI_REJECTION; idir = 1; }
   else if(intent == MB_CI_NONE && upper >= MBRejectWickRatio * range && out.close_pos <= 0.40)
   { intent = MB_CI_REJECTION; idir = -1; }

   // 6. Exhaustion: three candles one way with shrinking ranges, then a smaller one with a wick
   //    against the run.
   if(intent == MB_CI_NONE && s + 3 < n)
   {
      int c1 = MBColor(r[s + 1]), c2 = MBColor(r[s + 2]), c3 = MBColor(r[s + 3]);
      double r1 = r[s + 1].high - r[s + 1].low;
      double r2 = r[s + 2].high - r[s + 2].low;
      double r3 = r[s + 3].high - r[s + 3].low;
      if(c1 != 0 && c1 == c2 && c2 == c3 && r3 > r2 && r2 > r1 && range < r1)
      {
         if(c1 > 0 && upper >= 0.35 * range) { intent = MB_CI_EXHAUSTION; idir = -1; }
         else if(c1 < 0 && lower >= 0.35 * range) { intent = MB_CI_EXHAUSTION; idir = 1; }
      }
   }

   // 7. Breakout: closes beyond the prior extreme with a body (smaller than a displacement).
   // A body under 0.3 ATR is noise on gold (smaller than two spreads), not a breakout or continuation.
   bool real_body = (body >= 0.3 * atr);
   if(intent == MB_CI_NONE && have_prior && out.body_ratio >= 0.5 && real_body)
   {
      if(cdir > 0 && c > ph) { intent = MB_CI_BREAKOUT; idir = 1; }
      else if(cdir < 0 && c < pl) { intent = MB_CI_BREAKOUT; idir = -1; }
   }

   // 8. Indecision.
   if(intent == MB_CI_NONE && out.body_ratio <= MBIndecisionBodyRatio && range <= 0.7 * atr)
   { intent = MB_CI_INDECISION; idir = 0; }

   // 9. Continuation: a real body in the same colour as the candle before.
   if(intent == MB_CI_NONE && have_prev && cdir != 0 && out.body_ratio >= 0.5 && real_body && MBColor(r[s + 1]) == cdir)
   { intent = MB_CI_CONTINUATION; idir = cdir; }

   out.intent = intent;
   out.dir = idir;

   // Pressure: body 30 + close location 20 + displacement 20 + structure break 15 +
   // liquidity reaction 10 + follow-through 5.
   double bodyf = MathMin(1.0, out.body_atr) * out.body_ratio;
   double bull = 0.0, bear = 0.0;
   if(cdir > 0) bull += 30.0 * bodyf;
   else if(cdir < 0) bear += 30.0 * bodyf;
   bull += 20.0 * out.close_pos;
   bear += 20.0 * (1.0 - out.close_pos);
   if(intent == MB_CI_DISPLACEMENT)
   {
      if(idir > 0) bull += 20.0; else bear += 20.0;
   }
   else if(body >= 0.8 * atr)
   {
      if(cdir > 0) bull += 10.0; else if(cdir < 0) bear += 10.0;
   }
   if(have_prior)
   {
      if(c > ph) bull += 15.0;
      if(c < pl) bear += 15.0;
   }
   if(intent == MB_CI_LIQ_GRAB || intent == MB_CI_REJECTION || intent == MB_CI_FAKE_BREAKOUT)
   {
      if(idir > 0) bull += 10.0; else if(idir < 0) bear += 10.0;
   }
   if(have_prev)
   {
      int pcol = MBColor(r[s + 1]);
      if(cdir > 0 && pcol > 0 && c > r[s + 1].close) bull += 5.0;
      if(cdir < 0 && pcol < 0 && c < r[s + 1].close) bear += 5.0;
   }
   out.bull = MathMax(0.0, MathMin(100.0, bull));
   out.bear = MathMax(0.0, MathMin(100.0, bear));
}

// Impulse, speed budget and compression for M1 (k=0) / M5 (k=1).
void MBImpulseUpdate(const int k, const MqlRates &r[], const int n, const double atr)
{
   G_MB_IMP_DIR[k] = 0;
   G_MB_IMP_AGE[k] = 0;
   G_MB_IMP_WAVES[k] = 0;
   G_MB_IMP_ORIGIN[k] = 0.0;
   G_MB_IMP_TRAVEL[k] = 0.0;
   G_MB_SPEED[k] = MB_SPEED_NONE;
   if(atr <= 0.0 || n < 20)
      return;

   int limit = MathMin(n - 4, 60);
   int d = -1;
   SMBCandle cd;
   ZeroMemory(cd);
   for(int s = 1; s <= limit; s++)
   {
      MBReadCandle(r, n, s, atr, cd);
      if(cd.intent == MB_CI_DISPLACEMENT)
      {
         d = s;
         break;
      }
   }

   if(d > 0)
   {
      int dir = cd.dir;
      // The impulse starts at the oldest same-direction displacement of the run: walk back past d
      // until an opposite displacement, a bar beyond the run's start (price came INTO the start from
      // the other side - a different move), or 15 bars without another displacement.
      int start = d;
      int waves = 1;
      SMBCandle cw;
      for(int s = d + 1; s <= limit; s++)
      {
         MBReadCandle(r, n, s, atr, cw);
         if(cw.intent == MB_CI_DISPLACEMENT && cw.dir == -dir)
            break;
         if(dir > 0 ? (r[s].high > r[start].high) : (r[s].low < r[start].low))
            break;
         if(s - start > 15)
            break;
         if(cw.intent == MB_CI_DISPLACEMENT && cw.dir == dir)
         {
            waves++;
            start = s;
         }
      }
      double origin = r[start].open;

      // Speed is measured from the last healthy pullback. Walk forward from the start, tracking the
      // running extreme; a pullback of 30% of the leg so far restarts the clock at its extreme.
      double base = origin;
      double ext = origin;
      // LOCK FIX: on M1 a pullback of 0.3 ATR(M5) also restarts the clock - in a leg that keeps
      // growing, 30% of the whole leg is a retrace a running trend never makes.
      double pb_abs = (k == 0 && G_MB_ATR[1] > 0.0) ? 0.3 * G_MB_ATR[1] * _Point : DBL_MAX;
      double pb = (dir > 0) ? DBL_MAX : -DBL_MAX;
      for(int s = start; s >= 1; s--)
      {
         if(dir > 0)
         {
            if(r[s].high > ext) { ext = r[s].high; pb = DBL_MAX; }
            else
            {
               pb = MathMin(pb, r[s].low);
               if(ext - base > 0.0 && ((ext - pb) >= 0.30 * (ext - base) || (ext - pb) >= pb_abs))
               { base = pb; ext = pb; pb = DBL_MAX; }
            }
         }
         else
         {
            if(r[s].low < ext) { ext = r[s].low; pb = -DBL_MAX; }
            else
            {
               pb = MathMax(pb, r[s].high);
               if(base - ext > 0.0 && ((pb - ext) >= 0.30 * (base - ext) || (pb - ext) >= pb_abs))
               { base = pb; ext = pb; pb = -DBL_MAX; }
            }
         }
      }
      double travel = (dir > 0) ? (r[1].close - base) / atr : (base - r[1].close) / atr;
      travel = MathMax(0.0, travel);

      G_MB_IMP_DIR[k] = dir;
      G_MB_IMP_AGE[k] = start;
      G_MB_IMP_WAVES[k] = waves;
      G_MB_IMP_ORIGIN[k] = origin;
      G_MB_IMP_TRAVEL[k] = travel;
      if(travel < MBSpeedEarlyATR)       G_MB_SPEED[k] = MB_SPEED_EARLY;
      else if(travel < MBSpeedNormalATR) G_MB_SPEED[k] = MB_SPEED_NORMAL;
      else if(travel < MBSpeedLateATR)   G_MB_SPEED[k] = MB_SPEED_LATE;
      else                               G_MB_SPEED[k] = MB_SPEED_EXPIRED;
   }

   // Compression: the last N closed bars inside a narrow box.
   double hi = 0.0, lo = 0.0;
   G_MB_COMPRESSED[k] = false;
   if(MBPriorExtremes(r, n, 1, MathMax(3, MBCompressionBars), hi, lo))
   {
      G_MB_COMPRESSED[k] = ((hi - lo) <= MBCompressionATR * atr);
      G_MB_COMP_HI[k] = hi;
      G_MB_COMP_LO[k] = lo;
   }
}

// The forming M1 candle, every tick.
void MBLiveCandleUpdate()
{
   datetime t0 = iTime(_Symbol, PERIOD_M1, 0);
   if(t0 <= 0)
      return;
   if(t0 != G_MB_LIVE_BAR)
   {
      G_MB_LIVE_BAR = t0;
      G_MB_LIVE_DIR = 0;
      G_MB_LIVE_FAILED = 0;
   }

   double atr = G_MB_ATR[0] * _Point;
   if(atr <= 0.0)
      return;

   double o = iOpen(_Symbol, PERIOD_M1, 0);
   double h = iHigh(_Symbol, PERIOD_M1, 0);
   double l = iLow(_Symbol, PERIOD_M1, 0);
   double c = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ph = iHigh(_Symbol, PERIOD_M1, 1);
   double pl = iLow(_Symbol, PERIOD_M1, 1);
   double range = h - l;
   if(o <= 0.0 || c <= 0.0 || range <= 0.0)
      return;

   double body = MathAbs(c - o);
   double pos = (c - l) / range;

   if(G_MB_LIVE_DIR == 0)
   {
      if(body >= MBLiveDispBodyATR * atr)
      {
         if(c > o && pos >= 0.75 && c > ph) G_MB_LIVE_DIR = 1;
         else if(c < o && pos <= 0.25 && c < pl) G_MB_LIVE_DIR = -1;
         if(G_MB_LIVE_DIR != 0 && G_MB_LIVE_FAILED == G_MB_LIVE_DIR)
            G_MB_LIVE_FAILED = 0;   // the strength came back the same way - the failure is over
      }
   }
   else
   {
      // Gave the strength back: the body shrank or the close slid past the middle.
      bool lost = (body < 0.4 * atr) ||
                  (G_MB_LIVE_DIR > 0 && (c <= o || pos < 0.5)) ||
                  (G_MB_LIVE_DIR < 0 && (c >= o || pos > 0.5));
      if(lost)
      {
         G_MB_LIVE_FAILED = G_MB_LIVE_DIR;
         G_MB_LIVE_DIR = 0;
      }
   }
}

//---------------------------------------------------------------------
// STAGE 13: candle readings the direction logic asks for
//---------------------------------------------------------------------
// Which side the weighted candle pressure favours on a timeframe (0 = M1, 1 = M5, 2 = M15 ...).
int MBPressureSide(const int tfi)
{
   if(tfi < 0 || tfi >= MB_TF_COUNT)
      return 0;
   double d = G_MB_BULL[tfi] - G_MB_BEAR[tfi];
   if(d >= MBPressureSideMin) return 1;
   if(d <= -MBPressureSideMin) return -1;
   return 0;
}

// The last closed candle on tfi says strongly that dir has taken over.
bool MBCandleConfirms(const int tfi, const int dir)
{
   if(dir == 0 || G_MB_LAST[tfi].dir != dir)
      return false;
   int it = G_MB_LAST[tfi].intent;
   return (it == MB_CI_DISPLACEMENT || it == MB_CI_REJECTION || it == MB_CI_LIQ_GRAB || it == MB_CI_FAKE_BREAKOUT);
}

// The last closed candle on tfi is still pushing against dir.
bool MBCandleOpposes(const int tfi, const int dir)
{
   if(dir == 0 || G_MB_LAST[tfi].dir != -dir)
      return false;
   int it = G_MB_LAST[tfi].intent;
   return (it == MB_CI_DISPLACEMENT || it == MB_CI_CONTINUATION || it == MB_CI_BREAKOUT);
}

// A4. The impulse toward dir is spent: on M1 or M5 it is in its third wave or has travelled past
// the late mark, and its last candle shows the other side arriving (exhaustion, absorption or a
// rejection against it). A fresh healthy pullback resets the speed and lifts it by itself.
bool MBExhausted(const int dir, string &why)
{
   why = "";
   if(!EnableExhaustionVeto || dir == 0)
      return false;
   for(int k = 0; k <= 1; k++)
   {
      if(G_MB_IMP_DIR[k] != dir || G_MB_SPEED[k] < MB_SPEED_LATE)
         continue;
      if(G_MB_IMP_WAVES[k] < 3 && G_MB_SPEED[k] != MB_SPEED_EXPIRED)
         continue;
      int it = G_MB_LAST[k].intent;
      if(G_MB_LAST[k].dir == -dir && (it == MB_CI_EXHAUSTION || it == MB_CI_ABSORPTION || it == MB_CI_REJECTION))
      {
         why = StringFormat("%s %s impulse spent (%d waves, %.1f ATR) and a %s candle against it",
                            (k == 0 ? "M1" : "M5"), (dir > 0 ? "bullish" : "bearish"), G_MB_IMP_WAVES[k],
                            G_MB_IMP_TRAVEL[k], MBIntentName(it));
         return true;
      }
   }
   return false;
}

// STAGE 17 (D2): tick flow - up-ticks against down-ticks of the bid over the last TickFlowSeconds,
// -1 (all down) .. +1 (all up). Read at most once a second.
double G_MB_FLOW_IMB = 0.0;
int    G_MB_FLOW_N   = 0;
datetime G_MB_FLOW_T = 0;

void MBTickFlowUpdate()
{
   if(!EnableTickFlow)
      return;
   // AUDIT FIX: throttle on the server clock - GetTickCount is wall time, so in a fast tester run the
   // flow went stale for simulated minutes.
   datetime now_t = TimeCurrent();
   if(now_t == G_MB_FLOW_T)
      return;
   G_MB_FLOW_T = now_t;
   MqlTick ticks[];
   ulong from = (ulong)((long)TimeCurrent() - MathMax(5, TickFlowSeconds)) * 1000;
   int n = CopyTicks(_Symbol, ticks, COPY_TICKS_INFO, from, 3000);
   int up = 0, dn = 0;
   for(int i = 1; i < n; i++)
   {
      if(ticks[i].bid > ticks[i - 1].bid) up++;
      else if(ticks[i].bid < ticks[i - 1].bid) dn++;
   }
   G_MB_FLOW_N = up + dn;
   G_MB_FLOW_IMB = (G_MB_FLOW_N > 0) ? (double)(up - dn) / (double)G_MB_FLOW_N : 0.0;
}

void MBCandleEngineUpdate()
{
   if(!EnableMarketBrainEngines)
      return;

   for(int tfi = 0; tfi < MB_TF_COUNT; tfi++)
   {
      ENUM_TIMEFRAMES tf = MBTF(tfi);
      datetime t0 = iTime(_Symbol, tf, 0);
      if(t0 <= 0 || t0 == G_MB_CE_BAR[tfi])
         continue;

      MqlRates r[];
      ArraySetAsSeries(r, true);
      int n = CopyRates(_Symbol, tf, 0, 90, r);
      if(n < 30)
         continue;
      double atr_pts = ATRPointsManual(tf, 14, 1);
      if(atr_pts <= 0.0)
         continue;
      G_MB_CE_BAR[tfi] = t0;
      G_MB_ATR[tfi] = atr_pts;
      double atr = atr_pts * _Point;

      SMBCandle c1, c2, c3;
      MBReadCandle(r, n, 1, atr, c1);
      MBReadCandle(r, n, 2, atr, c2);
      MBReadCandle(r, n, 3, atr, c3);
      G_MB_LAST[tfi] = c1;
      G_MB_BULL[tfi] = 0.5 * c1.bull + 0.3 * c2.bull + 0.2 * c3.bull;
      G_MB_BEAR[tfi] = 0.5 * c1.bear + 0.3 * c2.bear + 0.2 * c3.bear;

      // Speed: last five ranges, oldest first.
      double rng[5];
      double signed_sum = 0.0;
      for(int j = 0; j < 5; j++)
      {
         int s = 5 - j;
         rng[j] = r[s].high - r[s].low;
         signed_sum += r[s].close - r[s].open;
      }
      int incs = 0, decs = 0;
      for(int j = 0; j < 4; j++)
      {
         if(rng[j + 1] > rng[j]) incs++;
         if(rng[j + 1] < rng[j]) decs++;
      }
      double avg4 = (rng[0] + rng[1] + rng[2] + rng[3]) / 4.0;
      G_MB_ACCEL[tfi] = 0;
      if(incs >= 3 && avg4 > 0.0 && rng[4] >= 1.5 * avg4) G_MB_ACCEL[tfi] = 1;
      else if(decs >= 3 && avg4 > 0.0 && rng[4] <= 0.7 * avg4) G_MB_ACCEL[tfi] = -1;
      G_MB_ACCEL_DIR[tfi] = (signed_sum > 0.0) ? 1 : ((signed_sum < 0.0) ? -1 : 0);

      // Sequence: last six closed candles, oldest first.
      int col[6];
      string seq = "";
      for(int j = 0; j < 6; j++)
      {
         col[j] = MBColor(r[6 - j]);
         seq += (col[j] > 0 ? "G" : (col[j] < 0 ? "R" : "-"));
      }
      G_MB_SEQ[tfi] = seq;
      G_MB_SEQ_STORY[tfi] = 0;
      G_MB_SEQ_DIR[tfi] = 0;
      if(col[0] != 0 && col[0] == col[1] && col[1] == col[2] && col[2] == col[3] && col[4] == -col[0] && col[5] == col[0])
      {
         G_MB_SEQ_STORY[tfi] = 1;           // pressure continues after a one-candle pause
         G_MB_SEQ_DIR[tfi] = col[0];
      }
      else if(col[0] != 0 && col[0] == col[1] && col[1] == col[2] && col[4] == -col[0] && col[5] == -col[0])
      {
         double run_body = (MathAbs(r[6].close - r[6].open) + MathAbs(r[5].close - r[5].open) + MathAbs(r[4].close - r[4].open)) / 3.0;
         if(MathAbs(r[1].close - r[1].open) >= 0.8 * run_body)
         {
            G_MB_SEQ_STORY[tfi] = 2;        // reversal forming
            G_MB_SEQ_DIR[tfi] = -col[0];
         }
      }

      if(tfi < 2)
         MBImpulseUpdate(tfi, r, n, atr);

      if(tfi >= 1 && (MBCandlePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS CANDLE] %s %s %s | body %.1f ATR | pressure bull %.0f / bear %.0f | %s %s",
                     MBTFName(tfi), MBIntentName(c1.intent), MBSideText(c1.dir), c1.body_atr,
                     G_MB_BULL[tfi], G_MB_BEAR[tfi], seq,
                     (G_MB_ACCEL[tfi] > 0 ? "accelerating" : (G_MB_ACCEL[tfi] < 0 ? "decelerating" : "")));
   }

   MBLiveCandleUpdate();
   MBTickFlowUpdate();   // stage 17 (D2)
}

// One line for the journal / Reason Code.
string MBCandleText()
{
   if(!EnableMarketBrainEngines)
      return "off";
   string t = "";
   for(int tfi = 0; tfi < 3; tfi++)
   {
      t += StringFormat("%s %s %s b%.0f/s%.0f%s %s | ",
                        MBTFName(tfi), MBIntentName(G_MB_LAST[tfi].intent), MBSideText(G_MB_LAST[tfi].dir),
                        G_MB_BULL[tfi], G_MB_BEAR[tfi],
                        (G_MB_ACCEL[tfi] > 0 ? " accel" : (G_MB_ACCEL[tfi] < 0 ? " decel" : "")),
                        G_MB_SEQ[tfi]);
   }
   for(int k = 0; k < 2; k++)
   {
      if(G_MB_IMP_DIR[k] != 0)
         t += StringFormat("%s impulse %s age %d waves %d %.1fATR %s%s | ",
                           MBTFName(k), MBSideText(G_MB_IMP_DIR[k]), G_MB_IMP_AGE[k], G_MB_IMP_WAVES[k],
                           G_MB_IMP_TRAVEL[k], MBSpeedName(G_MB_SPEED[k]),
                           (G_MB_COMPRESSED[k] ? " compressed" : ""));
      else if(G_MB_COMPRESSED[k])
         t += StringFormat("%s compressed | ", MBTFName(k));
   }
   t += StringFormat("live %s%s",
                     (G_MB_LIVE_DIR != 0 ? "early-disp " + MBSideText(G_MB_LIVE_DIR) : "-"),
                     (G_MB_LIVE_FAILED != 0 ? " (failed " + MBSideText(G_MB_LIVE_FAILED) + ")" : ""));
   return t;
}
