//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 18_Event_Engine                                 |
//| Market Brain A: liquidity pools and market events, every TF      |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// EVENT ENGINE (engine plan, phase 1)
//---------------------------------------------------------------------
// Facts, not signals. On every new bar of M1, M5, M15, H1 and H4 (and of the key daily levels,
// read on M5) the engine asks what the market just DID, and records it as an event with a
// direction, a level, a timeframe, a strength and an age:
//
//   LIQ_SWEEP     a liquidity pool (swing high/low, equal highs/lows, PDH/PDL, Asia high/low) was
//                 taken by less than 1 ATR and price closed back inside within 3 bars
//   FAKE_BREAK    price CLOSED beyond the pool, then closed back inside within the reclaim window
//   RECLAIM       after a sweep or a fake break, two closes held back on the right side
//   ACCEPTANCE    a genuine break: a displacement-sized break bar and 3 closes beyond the level
//   DISPLACEMENT  a displacement candle (from the Candle Engine)
//   BOS / MSS     close beyond the last swing: with the trend = BOS, against it = MSS
//   REJECTION     a rejection / liquidity-grab candle at a pool
//   COMP_RELEASE  a displacement out of a compression box (M1, M5)
//
// Direction is what the event MEANS: a sell-side sweep (lows taken, price back above) is +1
// (bullish), an acceptance below a support is -1 (bearish).
//
// Pools are rebuilt from history on each new bar, so nothing depends on state surviving a
// restart, and on the first run the recent past is replayed so that an H4 sweep two bars ago is
// already known. This engine only records; the veto that uses it is a later phase.
//=====================================================================

// MBSwingLenM1: Swing (fractal): M1 da har tomonda shuncha bar
input int    MBSwingLenM1             = 3;   // Brain swing len M1
// MBSwingLenHTF: M5 / M15 / H1 / H4 da har tomonda shuncha bar
input int    MBSwingLenHTF            = 2;   // Brain swing len HTF
// MBSweepMinATR: Sweep: havzadan kamida ATR x shu o'tishi kerak (va kamida 1 spread)
input double MBSweepMinATR            = 0.10;   // Brain sweep min ATR
// MBSweepMaxATR: Sweep: ATR x shudan ko'p o'tsa - sweep emas, break
input double MBSweepMaxATR            = 1.0;   // Brain sweep max ATR
// MBAcceptATR: Haqiqiy break: yopilishlar darajadan kamida ATR x shu narida
input double MBAcceptATR              = 0.25;   // Brain accept ATR
// MBAcceptCloses: Haqiqiy break: shuncha ketma-ket yopilish
input int    MBAcceptCloses           = 3;   // Brain accept closes
// MBAcceptBreakBodyATR: Haqiqiy break: break shamining tanasi >= ATR x shu
input double MBAcceptBreakBodyATR     = 0.8;   // Brain accept break body ATR
// MBReclaimBars: Soxta break: shuncha bar ichida qaytib yopilsa
input int    MBReclaimBars            = 5;   // Brain reclaim bars
// MBEqualLevelATR: Teng high / low: farq <= ATR x shu
input double MBEqualLevelATR          = 0.15;   // Brain equal level ATR
// MBFreshBarsM1: M1 hodisasi shuncha bargacha "yangi"
input int    MBFreshBarsM1            = 10;   // Brain fresh bars M1
// MBRelevantBarsM1: M1 hodisasi shuncha bargacha "dolzarb"
input int    MBRelevantBarsM1         = 45;   // Brain relevant bars M1
// MBFreshBarsHTF: M5..H4 hodisasi (o'z TF barlarida) shuncha bargacha "yangi"
input int    MBFreshBarsHTF           = 3;   // Brain fresh bars HTF
// MBRelevantBarsHTF: ... shuncha bargacha "dolzarb"
input int    MBRelevantBarsHTF        = 12;   // Brain relevant bars HTF
// MBAsiaStartHour: Osiyo sessiyasi (server vaqti) boshlanishi
input int    MBAsiaStartHour          = 0;   // Brain asia start hour
// MBAsiaEndHour: Osiyo sessiyasi tugashi
input int    MBAsiaEndHour            = 7;   // Brain asia end hour
// MBEventPrintOnUse: Har yangi hodisani jurnalga yozish ([SIRUS EVENT])
input bool   MBEventPrintOnUse        = true;   // Brain event print on use (on/off)
// EnableLiveSweep: 14-BOSQICH (C1): likvidlik yechilishini TIKDA ko'rish - bar yopilishini kutmasdan (M5 / M15 / H1 swing, PDH / PDL, Osiyo)
input bool   EnableLiveSweep          = true;   // Enable live sweep
// LiveSweepPierceATR: Darajadan kamida ATR(M1) x shu (va 1 spread) o'tishi kerak
input double LiveSweepPierceATR       = 0.15;   // Live sweep pierce ATR
// LiveSweepReclaimSec: Shuncha soniya ichida darajaning ichiga qaytsa - LIVE SWEEP
input int    LiveSweepReclaimSec      = 45;   // Live sweep reclaim sec
// LiveSweepValidSec: LIVE SWEEP shuncha soniya trigger bo'lib turadi (narx qaytgan tomonda qolsa)
input int    LiveSweepValidSec        = 120;   // Live sweep valid sec
// EnableRoundLevels: 17-BOSQICH (B3): yumaloq narxlar (XX00 / XX50) likvidlik hovuzi sifatida
input bool   EnableRoundLevels        = true;   // Enable round levels
// RoundLevelStep: Yumaloq daraja qadami (narx birligida, oltin uchun $50)
input double RoundLevelStep           = 50.0;   // Round level step
// NYOpenHour: 17-BOSQICH (B2): Nyu-York ochilishi (server vaqti). London = MBAsiaEndHour
input int    NYOpenHour               = 13;   // NY open hour
// SessionOpenWindowH: Ochilishdan keyin shuncha soat - "sessiya ochilishi" oynasi
input int    SessionOpenWindowH       = 2;   // Session open window h
// EnableSweepStats: 17-BOSQICH (D3): har LIVE SWEEP natijasi (hovuz turi x sessiya) eslab qolinadi; >= 30 namunada yo'nalish ehtimoli sifatida ishlatiladi
input bool   EnableSweepStats         = true;   // Enable sweep stats

#define MB_EV_NONE           0
#define MB_EV_LIQ_SWEEP      1
#define MB_EV_FAKE_BREAK     2
#define MB_EV_RECLAIM        3
#define MB_EV_ACCEPTANCE     4
#define MB_EV_DISPLACEMENT   5
#define MB_EV_BOS            6
#define MB_EV_MSS            7
#define MB_EV_REJECTION      8
#define MB_EV_COMP_RELEASE   9

#define MB_POOL_TF_COUNT     6      // M1, M5, M15, H1, H4, KEY (daily / session levels, read on M5)
#define MB_POOL_KEY          5
#define MB_POOL_MAX          48
#define MB_EV_PER_TF         40     // ring per timeframe slot, so frequent M1 events never push out an H4 sweep
#define MB_EV_MAX            240    // MB_POOL_TF_COUNT x MB_EV_PER_TF

#define MB_POOL_SWING        0
#define MB_POOL_EQUAL        1
#define MB_POOL_PDH          2
#define MB_POOL_PDL          3
#define MB_POOL_ASIA_HI      4
#define MB_POOL_ASIA_LO      5

struct SMBEvent
{
   int      type;        // MB_EV_*
   int      dir;         // +1 bullish meaning, -1 bearish meaning
   int      tfi;         // 0..4 = M1..H4, 5 = KEY
   double   level;       // the level the event happened at
   double   extreme;     // sweep extreme / break close / candle close
   datetime time;        // open time of the bar that completed the event
   double   strength;    // 0..~10, includes the timeframe weight
};

SMBEvent G_MB_EV[MB_EV_MAX];          // slot tfi*MB_EV_PER_TF + (n % MB_EV_PER_TF); time 0 = empty
string   G_MB_EV_NOTE[MB_EV_MAX];
int      G_MB_EV_N[MB_POOL_TF_COUNT];  // events ever written per timeframe slot
datetime G_MB_EV_BAR[MB_POOL_TF_COUNT];
bool     G_MB_EV_FILLED[MB_POOL_TF_COUNT];
int      G_MB_TREND[MB_POOL_TF_COUNT];        // +1 / -1 from the last BOS/MSS, 0 unknown
datetime G_MB_LAST_BROKEN_HI[MB_POOL_TF_COUNT];
datetime G_MB_LAST_BROKEN_LO[MB_POOL_TF_COUNT];
bool     G_MB_EV_REPLAYING  = false;
int      G_MB_EV_VERSION    = 0;          // SPEED: bumped on every new event - event-only answers are memoised on it

// Pools of the current evaluation (rebuilt per call)
double   G_MB_PL_LEVEL[MB_POOL_MAX];
int      G_MB_PL_SIDE[MB_POOL_MAX];   // +1 buy-side (highs), -1 sell-side (lows)
int      G_MB_PL_IDX[MB_POOL_MAX];    // series index of the bar that made it (as-of the rates array)
int      G_MB_PL_KIND[MB_POOL_MAX];
datetime G_MB_PL_FROM[MB_POOL_MAX];   // the pool must be untouched by bars opened after this time
int      G_MB_PL_COUNT = 0;

string MBEventName(const int type)
{
   switch(type)
   {
      case MB_EV_LIQ_SWEEP:    return "SWEEP";
      case MB_EV_FAKE_BREAK:   return "FAKE-BREAK";
      case MB_EV_RECLAIM:      return "RECLAIM";
      case MB_EV_ACCEPTANCE:   return "ACCEPTANCE";
      case MB_EV_DISPLACEMENT: return "DISPLACEMENT";
      case MB_EV_BOS:          return "BOS";
      case MB_EV_MSS:          return "MSS";
      case MB_EV_REJECTION:    return "REJECTION";
      case MB_EV_COMP_RELEASE: return "COMP-RELEASE";
   }
   return "?";
}

string MBPoolKindName(const int kind, const int side)
{
   switch(kind)
   {
      case MB_POOL_EQUAL:   return (side > 0 ? "equal highs" : "equal lows");
      case MB_POOL_PDH:     return "PDH";
      case MB_POOL_PDL:     return "PDL";
      case MB_POOL_ASIA_HI: return "Asia high";
      case MB_POOL_ASIA_LO: return "Asia low";
   }
   return (side > 0 ? "swing high" : "swing low");
}

double MBTFWeight(const int tfi)
{
   switch(tfi)
   {
      case 0: return 1.0;
      case 1: return 2.0;
      case 2: return 3.0;
      case 3: return 4.0;
      case 4: return 5.0;
      case 5: return 4.0;
   }
   return 1.0;
}

// The timeframe whose bars measure an event's age.
ENUM_TIMEFRAMES MBEventTF(const int tfi)
{
   if(tfi == MB_POOL_KEY)
      return PERIOD_M5;
   return MBTF(tfi);
}

int MBEventAgeBars(const SMBEvent &ev)
{
   int sec = PeriodSeconds(MBEventTF(ev.tfi));
   if(sec <= 0)
      return 0;
   long age = (long)(TimeCurrent() - ev.time) / sec;
   if(age < 0)
      age = 0;
   return (int)age;
}

int MBFreshLimit(const int tfi)    { return (tfi == 0) ? MBFreshBarsM1 : MBFreshBarsHTF; }
int MBRelevantLimit(const int tfi) { return (tfi == 0) ? MBRelevantBarsM1 : MBRelevantBarsHTF; }

// 1.0 while fresh, sliding to 0.3 at the end of the relevant window, 0 after three windows.
double MBEventWeight(const SMBEvent &ev)
{
   int age = MBEventAgeBars(ev);
   int fresh = MathMax(1, MBFreshLimit(ev.tfi));
   int rel = MathMax(fresh + 1, MBRelevantLimit(ev.tfi));
   if(age <= fresh) return 1.0;
   if(age <= rel)   return 1.0 - 0.7 * (double)(age - fresh) / (double)(rel - fresh);
   if(age <= 3 * rel) return 0.3;
   return 0.0;
}

// Key levels rank with H4.
int MBEventRank(const int tfi)
{
   return (tfi == MB_POOL_KEY) ? 4 : tfi;
}

// Still inside its relevant window (key levels: twice the HTF window, in M5 bars).
bool MBEventRelevant(const int idx)
{
   if(G_MB_EV[idx].time <= 0)
      return false;
   int tfi = G_MB_EV[idx].tfi;
   int lim = (tfi == MB_POOL_KEY) ? 2 * MBRelevantBarsHTF : MBRelevantLimit(tfi);   // key levels: 2x on M5 bars
   return (MBEventAgeBars(G_MB_EV[idx]) <= lim);
}

// Time of the latest matching event on slot tfi at or after `since`, 0 when none.
datetime MBEventTimeAt(const int type, const int dir, const int tfi, const double level, const datetime since, const double tol)
{
   datetime best = 0;
   int base = tfi * MB_EV_PER_TF;
   for(int i = 0; i < MB_EV_PER_TF; i++)
   {
      int idx = base + i;
      if(G_MB_EV[idx].time <= 0) continue;
      if(G_MB_EV[idx].type == type && G_MB_EV[idx].dir == dir &&
         G_MB_EV[idx].time >= since && MathAbs(G_MB_EV[idx].level - level) <= tol &&
         G_MB_EV[idx].time > best)
         best = G_MB_EV[idx].time;
   }
   return best;
}

bool MBEventExists(const int type, const int dir, const int tfi, const double level, const datetime since, const double tol)
{
   return (MBEventTimeAt(type, dir, tfi, level, since, tol) > 0);
}

void MBEventAdd(const int type, const int dir, const int tfi, const double level, const double extreme,
                const datetime t, const double quality, const string note)
{
   if(tfi < 0 || tfi >= MB_POOL_TF_COUNT)
      return;
   int idx = tfi * MB_EV_PER_TF + (G_MB_EV_N[tfi] % MB_EV_PER_TF);
   G_MB_EV[idx].type = type;
   G_MB_EV[idx].dir = dir;
   G_MB_EV[idx].tfi = tfi;
   G_MB_EV[idx].level = level;
   G_MB_EV[idx].extreme = extreme;
   G_MB_EV[idx].time = t;
   G_MB_EV[idx].strength = MBTFWeight(tfi) * MathMax(0.1, quality);
   G_MB_EV_NOTE[idx] = note;
   G_MB_EV_N[tfi]++;
   G_MB_EV_VERSION++;

   // M1 structure and displacement events are frequent - keep the journal to what matters.
   bool notable = (tfi >= 1) || (type == MB_EV_LIQ_SWEEP || type == MB_EV_FAKE_BREAK ||
                                 type == MB_EV_MSS || type == MB_EV_ACCEPTANCE || type == MB_EV_COMP_RELEASE);
   if(G_MB_EV_REPLAYING && tfi < 2)
      notable = false;
   if(notable && (MBEventPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS EVENT]%s %s %s %s @ %s | %s | strength %.1f | bar %s",
                  (G_MB_EV_REPLAYING ? " (history)" : ""),
                  MBTFName(tfi), MBEventName(type), (dir > 0 ? "BULLISH" : "BEARISH"),
                  DoubleToString(level, _Digits), note, G_MB_EV[idx].strength,
                  TimeToString(t, TIME_DATE | TIME_MINUTES));
}

void MBPoolAdd(const double level, const int side, const int idx, const int kind, const datetime from)
{
   if(G_MB_PL_COUNT >= MB_POOL_MAX || level <= 0.0)
      return;
   G_MB_PL_LEVEL[G_MB_PL_COUNT] = level;
   G_MB_PL_SIDE[G_MB_PL_COUNT] = side;
   G_MB_PL_IDX[G_MB_PL_COUNT] = idx;
   G_MB_PL_KIND[G_MB_PL_COUNT] = kind;
   G_MB_PL_FROM[G_MB_PL_COUNT] = from;
   G_MB_PL_COUNT++;
}

// Swing pools confirmed before bar `oldest_window` (the window being evaluated is s..oldest_window-1).
void MBBuildSwingPools(const MqlRates &r[], const int n, const int oldest_window, const int len, const double eq_tol)
{
   G_MB_PL_COUNT = 0;
   int first = oldest_window + len;          // the L bars after a swing must be older than the window
   int last = n - 1 - len;
   for(int k = first; k <= last && G_MB_PL_COUNT < MB_POOL_MAX; k++)
   {
      bool is_hi = true, is_lo = true;
      for(int j = 1; j <= len; j++)
      {
         if(r[k].high <= r[k - j].high || r[k].high < r[k + j].high) is_hi = false;
         if(r[k].low  >= r[k - j].low  || r[k].low  > r[k + j].low)  is_lo = false;
      }
      if(is_hi)
      {
         // Equal highs: merge into an existing pool on the same side.
         bool merged = false;
         for(int p = 0; p < G_MB_PL_COUNT; p++)
            if(G_MB_PL_SIDE[p] > 0 && MathAbs(G_MB_PL_LEVEL[p] - r[k].high) <= eq_tol)
            {
               G_MB_PL_LEVEL[p] = MathMax(G_MB_PL_LEVEL[p], r[k].high);
               G_MB_PL_KIND[p] = MB_POOL_EQUAL;
               merged = true;
               break;
            }
         if(!merged)
            MBPoolAdd(r[k].high, 1, k, MB_POOL_SWING, r[k].time);
      }
      if(is_lo)
      {
         bool merged = false;
         for(int p = 0; p < G_MB_PL_COUNT; p++)
            if(G_MB_PL_SIDE[p] < 0 && MathAbs(G_MB_PL_LEVEL[p] - r[k].low) <= eq_tol)
            {
               G_MB_PL_LEVEL[p] = MathMin(G_MB_PL_LEVEL[p], r[k].low);
               G_MB_PL_KIND[p] = MB_POOL_EQUAL;
               merged = true;
               break;
            }
         if(!merged)
            MBPoolAdd(r[k].low, -1, k, MB_POOL_SWING, r[k].time);
      }
   }
}

// Key levels for the day of bar time t: PDH / PDL and the Asia session range.
void MBBuildKeyPools(const datetime t)
{
   G_MB_PL_COUNT = 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   datetime day0 = t - (dt.hour * 3600 + dt.min * 60 + dt.sec);

   int d1 = iBarShift(_Symbol, PERIOD_D1, t, false);
   if(d1 >= 0)
   {
      double pdh = iHigh(_Symbol, PERIOD_D1, d1 + 1);
      double pdl = iLow(_Symbol, PERIOD_D1, d1 + 1);
      MBPoolAdd(pdh, 1, 0, MB_POOL_PDH, day0 - 1);   // untouched since today opened
      MBPoolAdd(pdl, -1, 0, MB_POOL_PDL, day0 - 1);
   }

   if(dt.hour >= MBAsiaEndHour && MBAsiaEndHour > MBAsiaStartHour)
   {
      datetime a_from = day0 + MBAsiaStartHour * 3600;
      datetime a_to = day0 + MBAsiaEndHour * 3600 - 1;
      MqlRates a[];
      int na = CopyRates(_Symbol, PERIOD_M5, a_from, a_to, a);
      if(na > 6)
      {
         double hi = -DBL_MAX, lo = DBL_MAX;
         for(int i = 0; i < na; i++)
         {
            hi = MathMax(hi, a[i].high);
            lo = MathMin(lo, a[i].low);
         }
         MBPoolAdd(hi, 1, 0, MB_POOL_ASIA_HI, a_to);   // untouched since the session ended
         MBPoolAdd(lo, -1, 0, MB_POOL_ASIA_LO, a_to);
      }
   }
}

// Was the pool already taken before the window starting at `oldest_window`?
// (pierced by more than min_pierce at any bar between its creation and the window)
bool MBPoolIntactBefore(const MqlRates &r[], const int n, const int p, const int oldest_window, const double min_pierce)
{
   double lvl = G_MB_PL_LEVEL[p];
   datetime from = G_MB_PL_FROM[p];
   for(int j = oldest_window; j < n; j++)
   {
      if(r[j].time <= from)
         break;   // series is newest-first: everything further back is older than the pool
      if(G_MB_PL_SIDE[p] > 0 && r[j].high > lvl + min_pierce) return false;
      if(G_MB_PL_SIDE[p] < 0 && r[j].low  < lvl - min_pierce) return false;
   }
   return true;
}

// Liquidity events on the bar at series index s.
void MBDetectLiquidity(const int tfi, const MqlRates &r[], const int n, const int s, const double atr, const double spread)
{
   double min_pierce = MathMax(MBSweepMinATR * atr, spread);
   double max_pierce = MBSweepMaxATR * atr;
   double accept = MBAcceptATR * atr;
   int reclaim_bars = MathMax(2, MBReclaimBars);
   int window = MathMax(MathMax(3, MBAcceptCloses), reclaim_bars) + 1;   // bars s .. s+window-1
   int oldest_window = s + window;
   if(oldest_window + 2 >= n)
      return;

   for(int p = 0; p < G_MB_PL_COUNT; p++)
   {
      double P = G_MB_PL_LEVEL[p];
      int side = G_MB_PL_SIDE[p];
      if(!MBPoolIntactBefore(r, n, p, oldest_window, min_pierce))
         continue;
      string what = MBPoolKindName(G_MB_PL_KIND[p], side);
      datetime t = r[s].time;
      datetime since = r[MathMin(n - 1, oldest_window)].time;

      if(side < 0)   // sell-side pool (lows)
      {
         double c = r[s].close;
         // ACCEPTANCE: the first time MBAcceptCloses closes sit beyond the level, the break bar
         // being a real body.
         int nc = MathMax(1, MBAcceptCloses);
         bool all_beyond = true;
         for(int j = s; j < s + nc; j++)
            if(r[j].close >= P - accept) { all_beyond = false; break; }
         if(all_beyond && r[s + nc].close >= P - accept)
         {
            int b = s + nc - 1;   // the break bar
            double body = r[b].open - r[b].close;
            if(body >= MBAcceptBreakBodyATR * atr && !MBEventExists(MB_EV_ACCEPTANCE, -1, tfi, P, since, 0.1 * atr))
               MBEventAdd(MB_EV_ACCEPTANCE, -1, tfi, P, c, t, 1.0 + body / atr,
                          StringFormat("%s broken and accepted below (%d closes)", what, nc));
         }

         if(c > P)
         {
            // Lowest point of the recent pierce, and whether it CLOSED beyond (fake break) or only wicked.
            double lowest = DBL_MAX;
            bool closed_beyond = false;
            int first_pierce = -1;
            for(int j = s; j < s + reclaim_bars && j < n; j++)
            {
               if(r[j].low < P - min_pierce)
               {
                  lowest = MathMin(lowest, r[j].low);
                  first_pierce = j;
               }
               if(j > s && r[j].close < P - accept)
                  closed_beyond = true;
            }
            bool returned_now = (s + 1 < n && (r[s + 1].close <= P || r[s].low < P - min_pierce));
            if(first_pierce >= 0 && returned_now && (P - lowest) <= max_pierce + (closed_beyond ? accept : 0.0))
            {
               if(closed_beyond)
               {
                  if(!MBEventExists(MB_EV_FAKE_BREAK, 1, tfi, P, since, 0.1 * atr))
                     MBEventAdd(MB_EV_FAKE_BREAK, 1, tfi, P, lowest, t, 1.2,
                                StringFormat("%s closed below, back above within %d bars (low %s)", what, first_pierce - s + 1, DoubleToString(lowest, _Digits)));
               }
               else if(first_pierce - s < 3)
               {
                  if(!MBEventExists(MB_EV_LIQ_SWEEP, 1, tfi, P, since, 0.1 * atr))
                     MBEventAdd(MB_EV_LIQ_SWEEP, 1, tfi, P, lowest, t, 1.0 + (P - lowest) / atr,
                                StringFormat("sell-side %s taken (low %s, %.2f ATR), closed back above",
                                             what, DoubleToString(lowest, _Digits), (P - lowest) / atr));
               }
            }
            // RECLAIM: two closes held above, both after the sweep / fake-break bar.
            if(s + 1 < n && r[s + 1].close > P)
            {
               datetime ev_t = MathMax(MBEventTimeAt(MB_EV_LIQ_SWEEP, 1, tfi, P, since, 0.1 * atr),
                                       MBEventTimeAt(MB_EV_FAKE_BREAK, 1, tfi, P, since, 0.1 * atr));
               if(ev_t > 0 && r[s + 1].time > ev_t && !MBEventExists(MB_EV_RECLAIM, 1, tfi, P, since, 0.1 * atr))
                  MBEventAdd(MB_EV_RECLAIM, 1, tfi, P, c, t, 1.0, StringFormat("%s reclaimed, 2 closes above", what));
            }
         }
      }
      else            // buy-side pool (highs)
      {
         double c = r[s].close;
         int nc = MathMax(1, MBAcceptCloses);
         bool all_beyond = true;
         for(int j = s; j < s + nc; j++)
            if(r[j].close <= P + accept) { all_beyond = false; break; }
         if(all_beyond && r[s + nc].close <= P + accept)
         {
            int b = s + nc - 1;
            double body = r[b].close - r[b].open;
            if(body >= MBAcceptBreakBodyATR * atr && !MBEventExists(MB_EV_ACCEPTANCE, 1, tfi, P, since, 0.1 * atr))
               MBEventAdd(MB_EV_ACCEPTANCE, 1, tfi, P, c, t, 1.0 + body / atr,
                          StringFormat("%s broken and accepted above (%d closes)", what, nc));
         }

         if(c < P)
         {
            double highest = -DBL_MAX;
            bool closed_beyond = false;
            int first_pierce = -1;
            for(int j = s; j < s + reclaim_bars && j < n; j++)
            {
               if(r[j].high > P + min_pierce)
               {
                  highest = MathMax(highest, r[j].high);
                  first_pierce = j;
               }
               if(j > s && r[j].close > P + accept)
                  closed_beyond = true;
            }
            bool returned_now = (s + 1 < n && (r[s + 1].close >= P || r[s].high > P + min_pierce));
            if(first_pierce >= 0 && returned_now && (highest - P) <= max_pierce + (closed_beyond ? accept : 0.0))
            {
               if(closed_beyond)
               {
                  if(!MBEventExists(MB_EV_FAKE_BREAK, -1, tfi, P, since, 0.1 * atr))
                     MBEventAdd(MB_EV_FAKE_BREAK, -1, tfi, P, highest, t, 1.2,
                                StringFormat("%s closed above, back below within %d bars (high %s)", what, first_pierce - s + 1, DoubleToString(highest, _Digits)));
               }
               else if(first_pierce - s < 3)
               {
                  if(!MBEventExists(MB_EV_LIQ_SWEEP, -1, tfi, P, since, 0.1 * atr))
                     MBEventAdd(MB_EV_LIQ_SWEEP, -1, tfi, P, highest, t, 1.0 + (highest - P) / atr,
                                StringFormat("buy-side %s taken (high %s, %.2f ATR), closed back below",
                                             what, DoubleToString(highest, _Digits), (highest - P) / atr));
               }
            }
            if(s + 1 < n && r[s + 1].close < P)
            {
               datetime ev_t = MathMax(MBEventTimeAt(MB_EV_LIQ_SWEEP, -1, tfi, P, since, 0.1 * atr),
                                       MBEventTimeAt(MB_EV_FAKE_BREAK, -1, tfi, P, since, 0.1 * atr));
               if(ev_t > 0 && r[s + 1].time > ev_t && !MBEventExists(MB_EV_RECLAIM, -1, tfi, P, since, 0.1 * atr))
                  MBEventAdd(MB_EV_RECLAIM, -1, tfi, P, c, t, 1.0, StringFormat("%s reclaimed, 2 closes below", what));
            }
         }
      }
   }
}

// BOS / MSS: the first close beyond the most recent unbroken swing.
void MBDetectStructure(const int tfi, const MqlRates &r[], const int n, const int s, const double atr, const int len)
{
   double buf = 0.05 * atr;
   // Most recent swing high / low confirmed before bar s.
   int sh = -1, sl = -1;
   for(int k = s + 1 + len; k <= n - 1 - len && (sh < 0 || sl < 0); k++)
   {
      bool is_hi = true, is_lo = true;
      for(int j = 1; j <= len; j++)
      {
         if(r[k].high <= r[k - j].high || r[k].high < r[k + j].high) is_hi = false;
         if(r[k].low  >= r[k - j].low  || r[k].low  > r[k + j].low)  is_lo = false;
      }
      if(is_hi && sh < 0) sh = k;
      if(is_lo && sl < 0) sl = k;
   }

   if(sh > 0 && r[sh].time != G_MB_LAST_BROKEN_HI[tfi])
   {
      double lvl = r[sh].high;
      bool first_close = (r[s].close > lvl + buf);
      for(int j = s + 1; j < sh && first_close; j++)
         if(r[j].close > lvl + buf) first_close = false;
      if(first_close)
      {
         int type = (G_MB_TREND[tfi] < 0) ? MB_EV_MSS : MB_EV_BOS;
         // An MSS straight after a sell-side sweep is the strongest version of it.
         datetime recent = r[MathMin(n - 1, s + 10)].time;
         bool after_sweep = MBEventExists(MB_EV_LIQ_SWEEP, 1, tfi, 0.0, recent, DBL_MAX) ||
                            MBEventExists(MB_EV_FAKE_BREAK, 1, tfi, 0.0, recent, DBL_MAX);
         MBEventAdd(type, 1, tfi, lvl, r[s].close, r[s].time, (type == MB_EV_MSS ? 1.5 : 1.0) * (after_sweep ? 1.5 : 1.0),
                    StringFormat("closed above swing high %s%s", DoubleToString(lvl, _Digits), (after_sweep ? " after a sell-side sweep" : "")));
         MBStructBreakRecord(tfi, 1, type, lvl, r, n, s, sh, atr);   // plan stage 1: structure memory
         G_MB_TREND[tfi] = 1;
         G_MB_LAST_BROKEN_HI[tfi] = r[sh].time;
      }
   }
   if(sl > 0 && r[sl].time != G_MB_LAST_BROKEN_LO[tfi])
   {
      double lvl = r[sl].low;
      bool first_close = (r[s].close < lvl - buf);
      for(int j = s + 1; j < sl && first_close; j++)
         if(r[j].close < lvl - buf) first_close = false;
      if(first_close)
      {
         int type = (G_MB_TREND[tfi] > 0) ? MB_EV_MSS : MB_EV_BOS;
         datetime recent = r[MathMin(n - 1, s + 10)].time;
         bool after_sweep = MBEventExists(MB_EV_LIQ_SWEEP, -1, tfi, 0.0, recent, DBL_MAX) ||
                            MBEventExists(MB_EV_FAKE_BREAK, -1, tfi, 0.0, recent, DBL_MAX);
         MBEventAdd(type, -1, tfi, lvl, r[s].close, r[s].time, (type == MB_EV_MSS ? 1.5 : 1.0) * (after_sweep ? 1.5 : 1.0),
                    StringFormat("closed below swing low %s%s", DoubleToString(lvl, _Digits), (after_sweep ? " after a buy-side sweep" : "")));
         MBStructBreakRecord(tfi, -1, type, lvl, r, n, s, sl, atr);  // plan stage 1: structure memory
         G_MB_TREND[tfi] = -1;
         G_MB_LAST_BROKEN_LO[tfi] = r[sl].time;
      }
   }
}

// Candle-derived events on bar s: displacement, rejection at a pool, compression release.
void MBDetectCandleEvents(const int tfi, const MqlRates &r[], const int n, const int s, const double atr)
{
   SMBCandle c;
   MBReadCandle(r, n, s, atr, c);

   if(c.intent == MB_CI_DISPLACEMENT)
   {
      // Compression release (M1 / M5): the displacement closed out of a narrow box.
      if(tfi <= 1)
      {
         double hi = 0.0, lo = 0.0;
         if(MBPriorExtremes(r, n, s + 1, MathMax(3, MBCompressionBars), hi, lo) &&
            (hi - lo) <= MBCompressionATR * atr &&
            ((c.dir > 0 && r[s].close > hi) || (c.dir < 0 && r[s].close < lo)))
            MBEventAdd(MB_EV_COMP_RELEASE, c.dir, tfi, (c.dir > 0 ? hi : lo), r[s].close, r[s].time, 1.2,
                       StringFormat("out of a %.1f ATR box", (hi - lo) / atr));
      }
      MBEventAdd(MB_EV_DISPLACEMENT, c.dir, tfi, r[s].open, r[s].close, r[s].time, c.body_atr * (c.strong ? 1.3 : 1.0),
                 StringFormat("body %.1f ATR%s", c.body_atr, (c.strong ? " (strong)" : "")));
   }

   if((c.intent == MB_CI_REJECTION || c.intent == MB_CI_LIQ_GRAB) && c.dir != 0)
   {
      // Only meaningful at a pool: the wick must reach one.
      double tol = 0.3 * atr;
      for(int p = 0; p < G_MB_PL_COUNT; p++)
      {
         double P = G_MB_PL_LEVEL[p];
         bool at_pool = (c.dir > 0) ? (r[s].low <= P + tol && r[s].low >= P - MBSweepMaxATR * atr && G_MB_PL_SIDE[p] < 0)
                                    : (r[s].high >= P - tol && r[s].high <= P + MBSweepMaxATR * atr && G_MB_PL_SIDE[p] > 0);
         if(at_pool)
         {
            MBEventAdd(MB_EV_REJECTION, c.dir, tfi, P, r[s].close, r[s].time, 1.0,
                       StringFormat("%s at %s %s", MBIntentName(c.intent), MBPoolKindName(G_MB_PL_KIND[p], G_MB_PL_SIDE[p]),
                                    DoubleToString(P, _Digits)));
            break;
         }
      }
   }
}

// Everything for timeframe slot tfi (0..4, or MB_POOL_KEY) on bar s.
void MBEvaluateBar(const int tfi, const MqlRates &r[], const int n, const int s, const double atr, const double spread)
{
   if(tfi == MB_POOL_KEY)
   {
      MBBuildKeyPools(r[s].time);
      MBDetectLiquidity(tfi, r, n, s, atr, spread);
      return;
   }

   int len = (tfi == 0) ? MathMax(1, MBSwingLenM1) : MathMax(1, MBSwingLenHTF);
   int window = MathMax(MathMax(3, MBAcceptCloses), MathMax(2, MBReclaimBars)) + 1;
   MBBuildSwingPools(r, n, s + window, len, MBEqualLevelATR * atr);
   MBDetectLiquidity(tfi, r, n, s, atr, spread);
   MBDetectStructure(tfi, r, n, s, atr, len);
   MBDetectCandleEvents(tfi, r, n, s, atr);
}

int MBBarsToLoad(const int tfi)
{
   switch(tfi)
   {
      case 0: return 220;
      case 1: return 200;
      case 2: return 160;
      case 3: return 160;
      case 4: return 120;
   }
   return 420;   // KEY, read on M5 (a full day plus the replay)
}

void MBEventEngineUpdate()
{
   if(!EnableMarketBrainEngines)
      return;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   for(int tfi = 0; tfi < MB_POOL_TF_COUNT; tfi++)
   {
      ENUM_TIMEFRAMES tf = MBEventTF(tfi);
      datetime t0 = iTime(_Symbol, tf, 0);
      if(t0 <= 0 || t0 == G_MB_EV_BAR[tfi])
         continue;

      MqlRates r[];
      ArraySetAsSeries(r, true);
      int n = CopyRates(_Symbol, tf, 0, MBBarsToLoad(tfi), r);
      if(n < 40)
         continue;
      int atr_tfi = (tfi == MB_POOL_KEY) ? 1 : tfi;
      double atr_pts = (G_MB_ATR[atr_tfi] > 0.0) ? G_MB_ATR[atr_tfi] : ATRPointsManual(tf, 14, 1);
      if(atr_pts <= 0.0)
         continue;
      double atr = atr_pts * _Point;

      if(!G_MB_EV_FILLED[tfi])
      {
         // First run: replay the recent past, oldest first, so recent HTF events are already known.
         // M5..H4 replay deeper (up to 100 bars) so the structure owner of each timeframe is known at
         // once - a timeframe with no BOS/MSS in the replay starts NEUTRAL and slows the first trades.
         int depth = MathMin(n - 40, MathMax(3, 3 * MBRelevantLimit(tfi == MB_POOL_KEY ? 0 : tfi)));
         if(tfi >= 1 && tfi <= 4)
            depth = MathMin(n - 40, MathMax(depth, 100));
         if(tfi == MB_POOL_KEY)
            depth = MathMin(n - 40, 120);
         G_MB_EV_REPLAYING = true;
         for(int s = depth; s >= 2; s--)
            MBEvaluateBar(tfi, r, n, s, atr, spread);
         G_MB_EV_REPLAYING = false;
         G_MB_EV_FILLED[tfi] = true;
      }

      // Normally one new closed bar; after a gap in ticks, every bar since the last pass.
      int from_s = 1;
      if(G_MB_EV_BAR[tfi] > 0)
      {
         int prev = iBarShift(_Symbol, tf, G_MB_EV_BAR[tfi], false);
         if(prev > 1)
            from_s = MathMin(prev, 30);
      }
      G_MB_EV_BAR[tfi] = t0;
      for(int s = from_s; s >= 1; s--)
         MBEvaluateBar(tfi, r, n, s, atr, spread);
   }
   MBLiveSweepUpdate();   // stage 14 (C1): on every tick
}

//---------------------------------------------------------------------
// STAGE 14 (C1): LIVE SWEEP - a liquidity sweep seen on the tick, not at the bar close
//---------------------------------------------------------------------
// Bar-close detection is late by up to a minute on M1 and five on M5, and in a sweep that is the
// whole trade: the run on the stops and the snap back take seconds. Once per M1 bar the untaken
// pools near price are collected (M5 / M15 / H1 swings and equal highs/lows, PDH / PDL, the Asia
// range). On every tick: price goes through a pool by a little, then comes back inside within
// LiveSweepReclaimSec -> LIVE SWEEP the other way, usable as a trigger at once. If price stays
// through it, the pool was taken and nothing is said. The bar-close engine above still records the
// confirmed SWEEP / FAKE_BREAK as before.
#define MB_LP_MAX 32
double   G_MB_LP_LEVEL[MB_LP_MAX];
int      G_MB_LP_SIDE[MB_LP_MAX];       // +1 buy-side (highs), -1 sell-side (lows)
int      G_MB_LP_TFI[MB_LP_MAX];        // pool timeframe slot (KEY for daily / session levels)
datetime G_MB_LP_PIERCE[MB_LP_MAX];     // when price went through, 0 = not yet
double   G_MB_LP_EXT[MB_LP_MAX];
bool     G_MB_LP_DONE[MB_LP_MAX];
int      G_MB_LP_KIND[MB_LP_MAX];       // 0 swing, 1 key (PDH/PDL/Asia), 2 round number
int      G_MB_LP_N = 0;
datetime G_MB_LP_BAR = 0;

int      G_MB_LSW_DIR   = 0;            // last live sweep: direction it favours
datetime G_MB_LSW_TIME  = 0;
double   G_MB_LSW_LEVEL = 0.0;
double   G_MB_LSW_EXT   = 0.0;
int      G_MB_LSW_TFI   = 0;
int      G_MB_LSW_KIND  = 0;
int      G_MB_LSW_COUNT = 0;

void MBLivePoolPut(const double level, const int side, const int tfi, const double merge_tol, const int kind = 0)
{
   if(level <= 0.0)
      return;
   for(int i = 0; i < G_MB_LP_N; i++)
      if(G_MB_LP_SIDE[i] == side && MathAbs(G_MB_LP_LEVEL[i] - level) <= merge_tol)
      {
         if(MBEventRank(tfi) > MBEventRank(G_MB_LP_TFI[i])) G_MB_LP_TFI[i] = tfi;   // keep the bigger owner
         return;
      }
   if(G_MB_LP_N >= MB_LP_MAX)
      return;
   G_MB_LP_LEVEL[G_MB_LP_N] = level;
   G_MB_LP_SIDE[G_MB_LP_N] = side;
   G_MB_LP_TFI[G_MB_LP_N] = tfi;
   G_MB_LP_PIERCE[G_MB_LP_N] = 0;
   G_MB_LP_EXT[G_MB_LP_N] = 0.0;
   G_MB_LP_DONE[G_MB_LP_N] = false;
   G_MB_LP_KIND[G_MB_LP_N] = kind;
   G_MB_LP_N++;
}

void MBLivePoolsRebuild(const double price)
{
   // AUDIT FIX: a pool pierced but not yet reclaimed is mid-sweep - the reclaim often comes after the
   // minute turns. Carry those over; the rebuild would otherwise drop them (price is beyond them and
   // the piercing bar now fails the intact check) and the sweep would never be seen.
   int keep = 0;
   for(int i = 0; i < G_MB_LP_N; i++)
   {
      if(G_MB_LP_PIERCE[i] == 0 || G_MB_LP_DONE[i])
         continue;
      G_MB_LP_LEVEL[keep] = G_MB_LP_LEVEL[i];
      G_MB_LP_SIDE[keep] = G_MB_LP_SIDE[i];
      G_MB_LP_TFI[keep] = G_MB_LP_TFI[i];
      G_MB_LP_PIERCE[keep] = G_MB_LP_PIERCE[i];
      G_MB_LP_EXT[keep] = G_MB_LP_EXT[i];
      G_MB_LP_DONE[keep] = false;
      G_MB_LP_KIND[keep] = G_MB_LP_KIND[i];
      keep++;
   }
   G_MB_LP_N = keep;
   double atr1 = G_MB_ATR[0] * _Point;
   double atr5 = G_MB_ATR[1] * _Point;
   if(atr1 <= 0.0 || atr5 <= 0.0 || price <= 0.0)
      return;
   double reach = 3.0 * atr5;               // only pools price can actually get to soon
   double merge = 0.10 * atr1 + _Point;

   for(int tfi = 1; tfi <= 3; tfi++)
   {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int n = CopyRates(_Symbol, MBTF(tfi), 0, 150, r);
      if(n < 20)
         continue;
      double atr_tf = (G_MB_ATR[tfi] > 0.0 ? G_MB_ATR[tfi] : G_MB_ATR[1]) * _Point;
      MBBuildSwingPools(r, n, 1, MathMax(1, MBSwingLenHTF), MBEqualLevelATR * atr_tf);
      // Copy out before anything rebuilds the shared pool arrays.
      int    pn = G_MB_PL_COUNT;
      double lv[MB_POOL_MAX];
      int    sd[MB_POOL_MAX], ix[MB_POOL_MAX];
      for(int p = 0; p < pn; p++) { lv[p] = G_MB_PL_LEVEL[p]; sd[p] = G_MB_PL_SIDE[p]; ix[p] = G_MB_PL_IDX[p]; }
      for(int p = 0; p < pn; p++)
      {
         if(MathAbs(lv[p] - price) > reach)
            continue;
         if(sd[p] > 0 && lv[p] <= price) continue;   // a high already below price was taken
         if(sd[p] < 0 && lv[p] >= price) continue;
         bool intact = true;
         for(int k = ix[p] - 1; k >= 1 && intact; k--)
            if((sd[p] > 0 && r[k].high > lv[p]) || (sd[p] < 0 && r[k].low < lv[p]))
               intact = false;
         if(intact)
            MBLivePoolPut(lv[p], sd[p], tfi, merge);
      }
   }

   // Daily and session levels, if still untaken today.
   MBBuildKeyPools(TimeCurrent());
   int kn = G_MB_PL_COUNT;
   double klv[MB_POOL_MAX];
   int ksd[MB_POOL_MAX];
   datetime kfrom[MB_POOL_MAX];
   for(int p = 0; p < kn; p++) { klv[p] = G_MB_PL_LEVEL[p]; ksd[p] = G_MB_PL_SIDE[p]; kfrom[p] = G_MB_PL_FROM[p]; }
   for(int p = 0; p < kn; p++)
   {
      if(MathAbs(klv[p] - price) > reach) continue;
      if(ksd[p] > 0 && klv[p] <= price) continue;
      if(ksd[p] < 0 && klv[p] >= price) continue;
      MqlRates a[];
      int na = CopyRates(_Symbol, PERIOD_M5, kfrom[p] + 1, TimeCurrent(), a);
      bool intact = true;
      for(int k = 0; k < na && intact; k++)
         if((ksd[p] > 0 && a[k].high > klv[p]) || (ksd[p] < 0 && a[k].low < klv[p]))
            intact = false;
      if(intact)
         MBLivePoolPut(klv[p], ksd[p], MB_POOL_KEY, merge, 1);
   }

   // Stage 17 (B3): round numbers within reach that the last hour has not touched.
   if(EnableRoundLevels && RoundLevelStep > 0.0)
   {
      MqlRates m[];
      ArraySetAsSeries(m, true);
      int nm = CopyRates(_Symbol, PERIOD_M1, 1, 60, m);
      double base = MathFloor(price / RoundLevelStep) * RoundLevelStep;
      for(int k = -1; k <= 2; k++)
      {
         double lvl = base + k * RoundLevelStep;
         if(lvl <= 0.0 || MathAbs(lvl - price) > reach || MathAbs(lvl - price) < merge)
            continue;
         int side = (lvl > price) ? 1 : -1;
         bool touched = false;
         for(int j = 0; j < nm && !touched; j++)
            if(m[j].high >= lvl && m[j].low <= lvl)
               touched = true;
         if(!touched)
            MBLivePoolPut(lvl, side, MB_POOL_KEY, merge, 2);
      }
   }
}

//---------------------------------------------------------------------
// STAGE 17 (B2): sessions on the server clock. 0 Asia, 1 London, 2 New York, 3 late.
//---------------------------------------------------------------------
int MBSessionNow()
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   int lon = MathMax(0, MBAsiaEndHour), ny = MathMax(lon + 1, NYOpenHour);
   if(dt.hour < lon) return 0;
   if(dt.hour < ny)  return 1;
   if(dt.hour < ny + 4) return 2;
   return 3;
}

string MBSessionUz(const int s)
{
   switch(s)
   {
      case 0: return "Osiyo";
      case 1: return "London";
      case 2: return "Nyu-York";
   }
   return "kechki";
}

// In the first SessionOpenWindowH hours of London or New York.
bool MBSessionOpenWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   int lon = MathMax(0, MBAsiaEndHour);
   int w = MathMax(1, SessionOpenWindowH);
   return ((dt.hour >= lon && dt.hour < lon + w) || (dt.hour >= NYOpenHour && dt.hour < NYOpenHour + w));
}

//---------------------------------------------------------------------
// STAGE 17 (D3): what live sweeps of each kind, in each session, went on to do. A sweep "works" when
// price then travels 1 ATR(M5) its way before 1 ATR(M5) back through its extreme; 30 minutes without
// either is not counted. Kept in terminal global variables so the record survives restarts.
//---------------------------------------------------------------------
#define MB_SS_PEND 16
datetime G_MB_SS_T[MB_SS_PEND];
int      G_MB_SS_DIR[MB_SS_PEND];
int      G_MB_SS_KIND[MB_SS_PEND];
int      G_MB_SS_SESS[MB_SS_PEND];
double   G_MB_SS_ENTRY[MB_SS_PEND];
double   G_MB_SS_ATR[MB_SS_PEND];
int      G_MB_SS_NEXT = 0;

string MBSweepStatKey(const int kind, const int sess, const bool won)
{
   return StringFormat("SIRUS_SWS_%s_%I64d_%d_%d_%s", _Symbol, MagicNumber, kind, sess, (won ? "W" : "L"));
}

// SPEED: read from the terminal once, then kept in memory; every update is written through.
double G_MB_SS_CACHE[3][4][2];
bool   G_MB_SS_LOADED = false;

double MBSweepStatGet(const int kind, const int sess, const bool won)
{
   if(kind < 0 || kind > 2 || sess < 0 || sess > 3)
      return 0.0;
   if(!G_MB_SS_LOADED)
   {
      G_MB_SS_LOADED = true;
      for(int a = 0; a < 3; a++)
         for(int b = 0; b < 4; b++)
            for(int c = 0; c < 2; c++)
            {
               string key = MBSweepStatKey(a, b, c == 1);
               G_MB_SS_CACHE[a][b][c] = GlobalVariableCheck(key) ? GlobalVariableGet(key) : 0.0;
            }
   }
   return G_MB_SS_CACHE[kind][sess][won ? 1 : 0];
}

// Win rate of live sweeps of this kind in this session, -1 below 30 samples.
double MBSweepEdge(const int kind, const int sess, int &n)
{
   double w = MBSweepStatGet(kind, sess, true), l = MBSweepStatGet(kind, sess, false);
   n = (int)(w + l);
   if(n < 30)
      return -1.0;
   return w / (w + l);
}

void MBSweepStatPush(const int dir, const int kind, const double entry)
{
   if(!EnableSweepStats)
      return;
   int k = G_MB_SS_NEXT;
   G_MB_SS_NEXT = (G_MB_SS_NEXT + 1) % MB_SS_PEND;
   G_MB_SS_T[k] = TimeCurrent();
   G_MB_SS_DIR[k] = dir;
   G_MB_SS_KIND[k] = kind;
   G_MB_SS_SESS[k] = MBSessionNow();
   G_MB_SS_ENTRY[k] = entry;
   G_MB_SS_ATR[k] = G_MB_ATR[1] * _Point;
}

void MBSweepStatUpdate(const double bid)
{
   if(!EnableSweepStats)
      return;
   for(int k = 0; k < MB_SS_PEND; k++)
   {
      if(G_MB_SS_T[k] <= 0 || G_MB_SS_ATR[k] <= 0.0)
         continue;
      double move = G_MB_SS_DIR[k] * (bid - G_MB_SS_ENTRY[k]);
      int res = -1;
      if(move >= G_MB_SS_ATR[k]) res = 1;
      else if(move <= -G_MB_SS_ATR[k]) res = 0;
      else if((TimeCurrent() - G_MB_SS_T[k]) > 1800) { G_MB_SS_T[k] = 0; continue; }
      if(res < 0)
         continue;
      string key = MBSweepStatKey(G_MB_SS_KIND[k], G_MB_SS_SESS[k], res == 1);
      double nv = MBSweepStatGet(G_MB_SS_KIND[k], G_MB_SS_SESS[k], res == 1) + 1.0;
      if(G_MB_SS_KIND[k] >= 0 && G_MB_SS_KIND[k] <= 2 && G_MB_SS_SESS[k] >= 0 && G_MB_SS_SESS[k] <= 3)
         G_MB_SS_CACHE[G_MB_SS_KIND[k]][G_MB_SS_SESS[k]][res == 1 ? 1 : 0] = nv;
      GlobalVariableSet(key, nv);
      G_MB_SS_T[k] = 0;
   }
}

// Every tick.
void MBLiveSweepUpdate()
{
   if(!EnableLiveSweep)
      return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 > 0 && m1 != G_MB_LP_BAR)
   {
      G_MB_LP_BAR = m1;
      MBLivePoolsRebuild(bid);
   }
   MBSweepStatUpdate(bid);
   double atr1 = G_MB_ATR[0] * _Point;
   if(atr1 <= 0.0)
      return;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double pierce = MathMax(LiveSweepPierceATR * atr1, spread);
   datetime now = TimeCurrent();

   for(int i = 0; i < G_MB_LP_N; i++)
   {
      if(G_MB_LP_DONE[i])
         continue;
      double lvl = G_MB_LP_LEVEL[i];
      int side = G_MB_LP_SIDE[i];
      double atr_tf = (G_MB_LP_TFI[i] >= 1 && G_MB_LP_TFI[i] <= 4 && G_MB_ATR[G_MB_LP_TFI[i]] > 0.0)
                      ? G_MB_ATR[G_MB_LP_TFI[i]] * _Point : G_MB_ATR[1] * _Point;
      if(G_MB_LP_PIERCE[i] == 0)
      {
         if((side > 0 && bid > lvl + pierce) || (side < 0 && bid < lvl - pierce))
         {
            G_MB_LP_PIERCE[i] = now;
            G_MB_LP_EXT[i] = bid;
         }
         continue;
      }
      G_MB_LP_EXT[i] = (side > 0) ? MathMax(G_MB_LP_EXT[i], bid) : MathMin(G_MB_LP_EXT[i], bid);
      // Too far through is a break, not a sweep.
      if(MathAbs(G_MB_LP_EXT[i] - lvl) > MBSweepMaxATR * atr_tf)
      {
         G_MB_LP_DONE[i] = true;
         continue;
      }
      bool back = (side > 0) ? (bid < lvl) : (bid > lvl);
      if(back)
      {
         G_MB_LP_DONE[i] = true;
         G_MB_LSW_DIR = -side;              // a buy-side sweep favours SELL, a sell-side sweep BUY
         G_MB_LSW_TIME = now;
         G_MB_LSW_LEVEL = lvl;
         G_MB_LSW_EXT = G_MB_LP_EXT[i];
         G_MB_LSW_TFI = G_MB_LP_TFI[i];
         G_MB_LSW_KIND = G_MB_LP_KIND[i];
         G_MB_LSW_COUNT++;
         MBSweepStatPush(G_MB_LSW_DIR, G_MB_LSW_KIND, bid);
         if(MBEventPrintOnUse && G_VERBOSE)
            PrintFormat("[SIRUS EVENT] LIVE SWEEP %s: %s %s pool %s taken to %s and reclaimed in %d s",
                        (G_MB_LSW_DIR > 0 ? "BULLISH" : "BEARISH"), MBTFName(G_MB_LSW_TFI),
                        (side > 0 ? "buy-side" : "sell-side"), DoubleToString(lvl, _Digits),
                        DoubleToString(G_MB_LSW_EXT, _Digits), (int)(now - G_MB_LP_PIERCE[i]));
      }
      else if((now - G_MB_LP_PIERCE[i]) > MathMax(5, LiveSweepReclaimSec))
         G_MB_LP_DONE[i] = true;            // it stayed through - the pool was simply taken
   }
}

// A live sweep the way of dir, still valid: recent, and price still on the reclaimed side.
bool MBLiveSweepFresh(const int dir, string &what)
{
   if(!EnableLiveSweep || dir == 0 || G_MB_LSW_DIR != dir)
      return false;
   if((TimeCurrent() - G_MB_LSW_TIME) > MathMax(10, LiveSweepValidSec))
      return false;
   // Price must still be on the reclaimed side - a retest of the level is fine, a return through it is not.
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slack = 0.25 * G_MB_ATR[0] * _Point;
   if(dir > 0 ? (bid < G_MB_LSW_LEVEL - slack) : (bid > G_MB_LSW_LEVEL + slack))
      return false;
   what = StringFormat("LIVE %s%s sweep @ %s", MBTFName(G_MB_LSW_TFI), (G_MB_LSW_KIND == 2 ? " round" : ""),
                       DoubleToString(G_MB_LSW_LEVEL, _Digits));
   return true;
}

// Latest event of a type and direction on timeframe slot >= min_tfi (KEY ranks with H4), still
// within its relevant age. type = MB_EV_NONE for any type, dir = 0 for any direction.
bool MBEventFind(const int type, const int dir, const int min_tfi, SMBEvent &out)
{
   int best = -1;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0) continue;
      if(type != MB_EV_NONE && G_MB_EV[idx].type != type) continue;
      if(dir != 0 && G_MB_EV[idx].dir != dir) continue;
      int tfi = G_MB_EV[idx].tfi;
      int rank = (tfi == MB_POOL_KEY) ? 4 : tfi;
      if(rank < min_tfi) continue;
      if(MBEventAgeBars(G_MB_EV[idx]) > MBRelevantLimit(tfi == MB_POOL_KEY ? 1 : tfi)) continue;
      if(best < 0 || G_MB_EV[idx].time > G_MB_EV[best].time)
         best = idx;
   }
   if(best < 0)
      return false;
   out = G_MB_EV[best];
   return true;
}

// The relevant events, newest first, for the journal / Reason Code. M1 displacements and M1
// BOS are left out (they are frequent and the Candle line already covers them).
string MBEventText(const int max_items)
{
   if(!EnableMarketBrainEngines)
      return "off";
   int used[];
   ArrayResize(used, MB_EV_MAX);
   ArrayInitialize(used, 0);
   string t = "";
   int shown = 0;
   while(shown < max_items)
   {
      int best = -1;
      for(int idx = 0; idx < MB_EV_MAX; idx++)
      {
         if(used[idx] != 0 || G_MB_EV[idx].time <= 0) continue;
         if(G_MB_EV[idx].tfi == 0 && (G_MB_EV[idx].type == MB_EV_DISPLACEMENT || G_MB_EV[idx].type == MB_EV_BOS)) continue;
         if(MBEventWeight(G_MB_EV[idx]) <= 0.0) continue;
         if(best < 0 || G_MB_EV[idx].time > G_MB_EV[best].time)
            best = idx;
      }
      if(best < 0)
         break;
      used[best] = 1;
      t += StringFormat("%s%s %s %s %s (%d bars, w%.1f)",
                        (shown > 0 ? " | " : ""),
                        MBTFName(G_MB_EV[best].tfi), MBEventName(G_MB_EV[best].type),
                        (G_MB_EV[best].dir > 0 ? "bull" : "bear"),
                        DoubleToString(G_MB_EV[best].level, _Digits),
                        MBEventAgeBars(G_MB_EV[best]), MBEventWeight(G_MB_EV[best]));
      shown++;
   }
   if(shown == 0)
      return "none relevant";
   return t;
}
