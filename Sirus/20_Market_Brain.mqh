//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20_Market_Brain                                 |
//| Market Brain C: bias states, dealing range, DOL, thesis          |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// MARKET BRAIN (engine plan, phase 3)
//---------------------------------------------------------------------
// One opinion about the market instead of seventy separate votes. Built only from the facts of
// the Event and Candle engines, refreshed once per M1 bar ("what changed?"):
//
//   BIAS per timeframe (M5, M15, H1, H4), seven states:
//      BULLISH / BULLISH_WEAK / TRANSITION_UP / NEUTRAL / TRANSITION_DOWN / BEARISH_WEAK / BEARISH
//      - the last structure event decides who owns the timeframe (BOS = trend, an MSS not yet
//        followed by a BOS = transition);
//      - a confirmed opposite liquidity reversal after it, opposite pressure or a decelerating
//        move make it WEAK.
//   COMPOSITE (scalping scheme): M15 gives the direction, M5 detects a transition against it,
//      a fresh H1/H4/daily liquidity reversal is a transition by itself, H1/H4 add or remove
//      confidence.
//   DEALING RANGE: the H1 swing high and swing low around price; premium above the middle,
//      discount below.
//   DRAW ON LIQUIDITY: the nearest untouched pool (M15/H1/H4 swing, PDH/PDL, Asia) on the side
//      the bias points to - where price is expected to go next.
//   THESIS: direction, confidence, invalidation level, target, preferred entry type and its life:
//      ACTIVATED (a transition) -> CONFIRMED (a BOS in its direction) -> DONE (target reached)
//      or INVALIDATED (M5 close beyond the invalidation level). An invalidated thesis is
//      remembered: the same direction is not revived for a while without a strong bias.
//   CONTRADICTION: how much relevant evidence has appeared against the thesis since it started.
//=====================================================================

input group "44 — MARKET BRAIN: BIAS + THESIS"
input bool   EnableMarketBrain        = true;   // Bozor haqida yagona fikr: 7 holatli bias, dealing range, likvidlik maqsadi, thesis
input double MBPressureWeakGap        = 20.0;   // Bias WEAK bo'ladi: qarama-qarshi sham bosimi shuncha ko'p bo'lsa (0-100 shkala)
input int    MBInvalidationMemoryM5   = 12;     // O'lgan thesis yo'nalishi ko'pi bilan shuncha M5 bar (1 soat) bloklanadi. HIDDEN-BUG FIX: 24 -> 12, va bozor shu yo'nalishni yangi struktura bilan qayta tasdiqlasa blok darhol ochiladi
input bool   MBThesisPrintOnUse       = true;   // Thesis o'zgarishlarini jurnalga yozish ([SIRUS THESIS])
input bool   EnableLocalTrading       = true;
input int    LocalGridMaxRungs        = 3;      // Lokal (globalga qarshi) savat ko'pi bilan shuncha order
input int    LocalBasketMaxMinutes    = 20;     // Lokal savat shuncha daqiqadan keyin BE yoki foydada bo'lsa yopiladi
input int    LocalLossPauseCount      = 2;      // Ketma-ket shuncha lokal zarar ...
input int    LocalLossPauseMinutes    = 30;     // ... bo'lsa lokal savdo shuncha daqiqa to'xtaydi (global savdo davom etadi)
input bool   ShowLocalOnChart         = true;   // Lokal oyoq maqsadi va chegarasini chartda chiziq bilan ko'rsatish   // LOKAL SAVDO: global yo'nalishga qarshi LOKAL harakat (M1 / M5 struktura + bosim) aniq bo'lsa - o'sha tomonga ham kirish (veto, hakam, risk baribir tekshiradi; grid faqat tuzilma + javob bilan)
input bool   EnableRegimePlaybook     = true;   // 15-BOSQICH (D1): M15 bozor rejimi (TREND / DIAPAZON / PORTLASH / SIQILISH) va har biriga o'z kirish qoidasi
input int    RegimeLookbackM15        = 20;     // Rejim shuncha M15 bar bo'yicha o'qiladi
input double RegimeTrendER            = 0.35;   // Samaradorlik (to'g'ri yo'l / yurilgan yo'l) >= shu: TREND
input double RegimeExpansionRatio     = 1.40;   // ATR(14) / ATR(50) >= shu va oxirgi 4 bar kuchli yurgan: PORTLASH
input double RegimeCompressionATR     = 2.0;    // Oxirgi 12 bar diapazoni <= ATR x shu va ATR pasaygan: SIQILISH
input double RegimeRangeEdge          = 0.35;   // DIAPAZON: BUY pastki shu ulushda, SELL yuqori shu ulushda - chekka (yaxshi joy)

#define MB_BIAS_BEARISH          -3
#define MB_BIAS_BEARISH_WEAK     -2
#define MB_BIAS_TRANSITION_DOWN  -1
#define MB_BIAS_NEUTRAL           0
#define MB_BIAS_TRANSITION_UP     1
#define MB_BIAS_BULLISH_WEAK      2
#define MB_BIAS_BULLISH           3

#define MB_TH_NONE               0
#define MB_TH_ACTIVATED          1
#define MB_TH_CONFIRMED          2
#define MB_TH_DONE               3
#define MB_TH_INVALIDATED        4

int      G_MB_TF_STATE[MB_TF_COUNT];      // per timeframe (index 0 = M1 unused)
int      G_MB_BIAS       = MB_BIAS_NEUTRAL;
int      G_MB_BIAS_CONF  = 50;            // 0..100
string   G_MB_BIAS_WHY   = "";
datetime G_MB_BRAIN_BAR  = 0;
int      G_MB_BIAS_CAND   = MB_BIAS_NEUTRAL;   // bias waiting to be confirmed (hysteresis)
int      G_MB_BIAS_CAND_N = 0;
bool     G_MB_BRAIN_PRIMED = false;

double   G_MB_DR_HI  = 0.0;               // H1 dealing range
double   G_MB_DR_LO  = 0.0;
double   G_MB_DR_POS = 0.5;               // 0 = range low, 1 = range high
double   G_MB_DOL      = 0.0;             // draw on liquidity (target)
string   G_MB_DOL_WHAT = "";

int      G_MB_TH_DIR     = 0;
int      G_MB_TH_STATE   = MB_TH_NONE;
datetime G_MB_TH_SINCE   = 0;
bool     G_MB_TH_THREAT  = false;         // stage 16 (A7): candles say the open thesis is in danger
string   G_MB_TH_THREAT_WHY = "";
double   G_MB_TH_INVALID = 0.0;
double   G_MB_TH_TARGET  = 0.0;
int      G_MB_TH_CONTRA  = 0;             // 0 low, 1 medium, 2 high
string   G_MB_TH_TEXT    = "";
int      G_MB_DEAD_DIR   = 0;             // invalidation memory
datetime G_MB_DEAD_TIME  = 0;             // when that thesis died
datetime G_MB_DEAD_UNTIL = 0;

string MBBiasName(const int b)
{
   switch(b)
   {
      case MB_BIAS_BEARISH:         return "BEARISH";
      case MB_BIAS_BEARISH_WEAK:    return "BEARISH_WEAK";
      case MB_BIAS_TRANSITION_DOWN: return "TRANSITION_DOWN";
      case MB_BIAS_NEUTRAL:         return "NEUTRAL";
      case MB_BIAS_TRANSITION_UP:   return "TRANSITION_UP";
      case MB_BIAS_BULLISH_WEAK:    return "BULLISH_WEAK";
      case MB_BIAS_BULLISH:         return "BULLISH";
   }
   return "?";
}

string MBThesisStateName(const int st)
{
   switch(st)
   {
      case MB_TH_ACTIVATED:   return "ACTIVATED";
      case MB_TH_CONFIRMED:   return "CONFIRMED";
      case MB_TH_DONE:        return "DONE (target reached)";
      case MB_TH_INVALIDATED: return "INVALIDATED";
   }
   return "none";
}

int MBSign(const int v)
{
   if(v > 0) return 1;
   if(v < 0) return -1;
   return 0;
}

// Latest structure event (BOS/MSS) on slot tfi, any age still in the ring. -1 when none.
int MBLastStructureEvent(const int tfi)
{
   int best = -1;
   int base = tfi * MB_EV_PER_TF;
   for(int i = 0; i < MB_EV_PER_TF; i++)
   {
      int idx = base + i;
      if(G_MB_EV[idx].time <= 0) continue;
      if(G_MB_EV[idx].type != MB_EV_MSS && G_MB_EV[idx].type != MB_EV_BOS) continue;
      if(best < 0 || G_MB_EV[idx].time > G_MB_EV[best].time)
         best = idx;
   }
   return best;
}

// A confirmed liquidity reversal toward `dir` on slots [tf_lo..tf_hi] (or KEY when key=true)
// after time `after`: sweep / fake break plus a displacement, MSS/BOS or reclaim. Relevant only.
bool MBReversalAfterCalc(const int dir, const int tf_lo, const int tf_hi, const bool key, const datetime after, string &what, datetime &sweep_time)
{
   sweep_time = 0;
   // Every relevant sweep / fake break toward `dir` in range, newest first; the first one followed
   // by a confirmation wins (a newer unconfirmed sweep does not hide an older confirmed one).
   int used[];
   ArrayResize(used, MB_EV_MAX);
   ArrayInitialize(used, 0);
   while(true)
   {
      int sw = -1;
      for(int idx = 0; idx < MB_EV_MAX; idx++)
      {
         if(used[idx] != 0) continue;
         // AUDIT FIX: an event belongs after `after` when its bar CLOSED after it (event time is the
         // bar's open - an H4 sweep completing after a basket opened has an open time before it).
         if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dir) continue;
         if(G_MB_EV[idx].time + PeriodSeconds(MBEventTF(G_MB_EV[idx].tfi)) <= after) continue;
         if(G_MB_EV[idx].type != MB_EV_LIQ_SWEEP && G_MB_EV[idx].type != MB_EV_FAKE_BREAK) continue;
         int tfi = G_MB_EV[idx].tfi;
         bool in_range = (tfi >= tf_lo && tfi <= tf_hi) || (key && tfi == MB_POOL_KEY);
         if(!in_range) continue;
         if(!MBEventRelevant(idx)) continue;
         if(sw < 0 || G_MB_EV[idx].time > G_MB_EV[sw].time)
            sw = idx;
      }
      if(sw < 0)
         return false;
      used[sw] = 1;

      // AUDIT FIX: a confirmation must come after the sweep's bar closed (an M1 displacement inside an
      // H4 sweep bar may predate the pierce), and an M5+ sweep needs an M5+ confirmation.
      datetime sw_close = G_MB_EV[sw].time + PeriodSeconds(MBEventTF(G_MB_EV[sw].tfi));
      int min_rank = (MBEventRank(G_MB_EV[sw].tfi) >= 1) ? 1 : 0;
      for(int idx = 0; idx < MB_EV_MAX; idx++)
      {
         if(G_MB_EV[idx].time < sw_close || G_MB_EV[idx].dir != dir) continue;
         if(MBEventRank(G_MB_EV[idx].tfi) < min_rank) continue;
         if(!MBEventRelevant(idx)) continue;   // LOCK FIX: a confirmation that aged out confirms nothing now
         int ty = G_MB_EV[idx].type;
         if(ty == MB_EV_DISPLACEMENT || ty == MB_EV_MSS || ty == MB_EV_BOS || ty == MB_EV_RECLAIM)
         {
            sweep_time = G_MB_EV[sw].time;
            what = StringFormat("%s %s %s @ %s + %s %s", MBTFName(G_MB_EV[sw].tfi),
                                (dir > 0 ? "sell-side" : "buy-side"), MBEventName(G_MB_EV[sw].type),
                                DoubleToString(G_MB_EV[sw].level, _Digits),
                                MBTFName(G_MB_EV[idx].tfi), MBEventName(ty));
            return true;
         }
      }
   }
   return false;
}

// SPEED: the answer depends only on the events and their age, so it is remembered per (event version,
// M1 bar, arguments). The veto, the judge, the bias and the Position Brain ask it many times a tick.
#define MB_RA_SLOTS 16
int      G_RA_VER[MB_RA_SLOTS];
datetime G_RA_BAR[MB_RA_SLOTS];
int      G_RA_ARGS[MB_RA_SLOTS][4];
datetime G_RA_AFTER[MB_RA_SLOTS];
bool     G_RA_RES[MB_RA_SLOTS];
string   G_RA_WHAT[MB_RA_SLOTS];
datetime G_RA_SWT[MB_RA_SLOTS];
bool     G_RA_USED[MB_RA_SLOTS];
int      G_RA_NEXT = 0;

bool MBReversalAfter(const int dir, const int tf_lo, const int tf_hi, const bool key, const datetime after, string &what, datetime &sweep_time)
{
   datetime bar = iTime(_Symbol, PERIOD_M1, 0);
   int k_key = key ? 1 : 0;
   for(int i = 0; i < MB_RA_SLOTS; i++)
   {
      if(!G_RA_USED[i] || G_RA_VER[i] != G_MB_EV_VERSION || G_RA_BAR[i] != bar || G_RA_AFTER[i] != after) continue;
      if(G_RA_ARGS[i][0] != dir || G_RA_ARGS[i][1] != tf_lo || G_RA_ARGS[i][2] != tf_hi || G_RA_ARGS[i][3] != k_key) continue;
      if(G_RA_RES[i]) what = G_RA_WHAT[i];
      sweep_time = G_RA_SWT[i];
      return G_RA_RES[i];
   }
   string w = "";
   datetime st = 0;
   bool res = MBReversalAfterCalc(dir, tf_lo, tf_hi, key, after, w, st);
   int k = G_RA_NEXT;
   G_RA_NEXT = (G_RA_NEXT + 1) % MB_RA_SLOTS;
   G_RA_USED[k] = true;
   G_RA_VER[k] = G_MB_EV_VERSION;
   G_RA_BAR[k] = bar;
   G_RA_AFTER[k] = after;
   G_RA_ARGS[k][0] = dir; G_RA_ARGS[k][1] = tf_lo; G_RA_ARGS[k][2] = tf_hi; G_RA_ARGS[k][3] = k_key;
   G_RA_RES[k] = res;
   G_RA_WHAT[k] = w;
   G_RA_SWT[k] = st;
   if(res) what = w;
   sweep_time = st;
   return res;
}

// Seven-state bias of one timeframe (tfi 1..4).
int MBTimeframeState(const int tfi)
{
   int le = MBLastStructureEvent(tfi);
   if(le < 0)
      return MB_BIAS_NEUTRAL;

   int d = G_MB_EV[le].dir;
   datetime t_le = G_MB_EV[le].time;

   // An MSS not yet followed by a BOS the same way is a transition.
   if(G_MB_EV[le].type == MB_EV_MSS)
      return (d > 0) ? MB_BIAS_TRANSITION_UP : MB_BIAS_TRANSITION_DOWN;

   // A trend - strong unless something is already arguing with it.
   string w = "";
   datetime swt = 0;
   bool counter = MBReversalAfter(-d, MathMax(0, tfi - 1), tfi, (tfi >= 3), t_le, w, swt);
   double gap = (d > 0) ? (G_MB_BEAR[tfi] - G_MB_BULL[tfi]) : (G_MB_BULL[tfi] - G_MB_BEAR[tfi]);
   bool decel = (G_MB_ACCEL[tfi] < 0 && G_MB_ACCEL_DIR[tfi] == d);
   if(counter || gap >= MBPressureWeakGap || decel)
      return (d > 0) ? MB_BIAS_BULLISH_WEAK : MB_BIAS_BEARISH_WEAK;
   return (d > 0) ? MB_BIAS_BULLISH : MB_BIAS_BEARISH;
}

//---------------------------------------------------------------------
// STAGE 15 (D1): MARKET REGIME + PLAYBOOK
//---------------------------------------------------------------------
// The same entry is right in one regime and wrong in another: a pullback buy is the trade in a
// trend and a coin flip in the middle of a range; fading a range edge is the trade in a range and
// suicide in an expansion. Read once per M15 bar:
//   EXPANSION    ATR(14)/ATR(50) high and the last four bars travelled hard one way
//   COMPRESSION  the last twelve bars inside a narrow box and ATR falling
//   TREND        efficiency (net move / walked distance) over the lookback is high
//   RANGE        everything else, with the lookback's high / low as the box
// The Entry Judge applies the playbook (23_Entry_Engine.mqh).
#define MB_RG_NONE        0
#define MB_RG_TREND       1
#define MB_RG_RANGE       2
#define MB_RG_EXPANSION   3
#define MB_RG_COMPRESSION 4

int      G_MB_RG      = MB_RG_NONE;
int      G_MB_RG_DIR  = 0;
double   G_MB_RG_HI   = 0.0;
double   G_MB_RG_LO   = 0.0;
double   G_MB_RG_ER   = 0.0;
double   G_MB_RG_RATIO = 0.0;
datetime G_MB_RG_BAR  = 0;
double   G_MB_H4_HI   = 0.0;   // stage 17 (D5): the H4 box (last 20 H4 bars)
double   G_MB_H4_LO   = 0.0;
double   G_MB_VOL_PCT = -1.0;  // stage 17 (D7): where today's M5 ATR sits in the last 5 days, 0..100

string MBRegimeName(const int rg)
{
   switch(rg)
   {
      case MB_RG_TREND:       return "TREND";
      case MB_RG_RANGE:       return "RANGE";
      case MB_RG_EXPANSION:   return "EXPANSION";
      case MB_RG_COMPRESSION: return "COMPRESSION";
   }
   return "-";
}

void MBRangeLayersUpdate();

void MBRegimeUpdate()
{
   datetime t0 = iTime(_Symbol, PERIOD_M15, 0);
   if(t0 <= 0 || t0 == G_MB_RG_BAR)
      return;
   MBRangeLayersUpdate();   // H4 box + volatility percentile: used even with the playbook off
   if(!EnableRegimePlaybook)
   {
      G_MB_RG = MB_RG_NONE;
      G_MB_RG_BAR = t0;
      return;
   }
   int look = MathMax(10, RegimeLookbackM15);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M15, 0, MathMax(look, 50) + 3, r);
   if(n < MathMax(look, 50) + 2)
      return;
   G_MB_RG_BAR = t0;

   // True ranges of closed bars 1..50.
   double tr[];
   ArrayResize(tr, 51);
   for(int i = 1; i <= 50; i++)
      tr[i] = MathMax(r[i].high, r[i + 1].close) - MathMin(r[i].low, r[i + 1].close);
   double a14 = 0.0, a50 = 0.0;
   for(int i = 1; i <= 50; i++) { a50 += tr[i]; if(i <= 14) a14 += tr[i]; }
   a14 /= 14.0;
   a50 /= 50.0;
   if(a14 <= 0.0 || a50 <= 0.0)
      return;
   G_MB_RG_RATIO = a14 / a50;

   double walk = 0.0;
   for(int i = 1; i <= look; i++)
      walk += MathAbs(r[i].close - r[i + 1].close);
   double net = r[1].close - r[look + 1].close;
   G_MB_RG_ER = (walk > 0.0) ? MathAbs(net) / walk : 0.0;

   double hi12 = -DBL_MAX, lo12 = DBL_MAX, hi = -DBL_MAX, lo = DBL_MAX;
   for(int i = 1; i <= look; i++)
   {
      hi = MathMax(hi, r[i].high);
      lo = MathMin(lo, r[i].low);
      if(i <= 12) { hi12 = MathMax(hi12, r[i].high); lo12 = MathMin(lo12, r[i].low); }
   }
   double move4 = r[1].close - r[5].close;

   int rg = MB_RG_RANGE, dir = 0;
   if(G_MB_RG_RATIO >= RegimeExpansionRatio && MathAbs(move4) >= 1.5 * a14)
   { rg = MB_RG_EXPANSION; dir = (move4 > 0.0) ? 1 : -1; }
   else if((hi12 - lo12) <= RegimeCompressionATR * a50 && G_MB_RG_RATIO <= 0.85)
   { rg = MB_RG_COMPRESSION; hi = hi12; lo = lo12; }
   else if(G_MB_RG_ER >= RegimeTrendER)
   { rg = MB_RG_TREND; dir = (net > 0.0) ? 1 : -1; }

   if(rg != G_MB_RG && (MBThesisPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS REGIME] %s%s | ER %.2f | ATR14/50 %.2f | box %s-%s", MBRegimeName(rg),
                  (dir > 0 ? " UP" : (dir < 0 ? " DOWN" : "")), G_MB_RG_ER, G_MB_RG_RATIO,
                  DoubleToString(lo, _Digits), DoubleToString(hi, _Digits));
   G_MB_RG = rg;
   G_MB_RG_DIR = dir;
   G_MB_RG_HI = hi;
   G_MB_RG_LO = lo;
}

// REGIME DOMINANCE (A): in a RANGE or a COMPRESSION the market walks edge to edge, and a weak or
// turning global bias (|bias| <= 2) says little about the next leg. There the bias is not a veto:
// both edges are traded, and the judge asks for what a range trade needs - a place and a trigger.
bool MBRangeRules()
{
   return (EnableRegimePlaybook && (G_MB_RG == MB_RG_RANGE || G_MB_RG == MB_RG_COMPRESSION) &&
           MathAbs(G_MB_BIAS) <= 2);
}

// Stage 17 (D5 / D7): the H4 box and the M5 volatility percentile, once per M15 bar.
void MBRangeLayersUpdate()
{
   // Stage 17 (D5): the H4 box, for the three-layer cheap / expensive reading.
   MqlRates h4[];
   ArraySetAsSeries(h4, true);
   int n4 = CopyRates(_Symbol, PERIOD_H4, 1, 20, h4);
   if(n4 >= 10)
   {
      double hh = -DBL_MAX, ll = DBL_MAX;
      for(int i = 0; i < n4; i++) { hh = MathMax(hh, h4[i].high); ll = MathMin(ll, h4[i].low); }
      G_MB_H4_HI = hh;
      G_MB_H4_LO = ll;
   }

   // Stage 17 (D7): volatility percentile - the current 14-bar M5 ATR against every 14-bar M5 ATR of
   // the last five days. The same "1.2 ATR" means different things on a dead day and on a wild one;
   // the percentile says which day this is.
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   int n5 = CopyRates(_Symbol, PERIOD_M5, 1, 1460, m5);
   if(n5 >= 300)
   {
      int cnt = n5 - 1;
      double trs[];
      ArrayResize(trs, cnt);
      for(int i = 0; i < cnt; i++)
         trs[i] = MathMax(m5[i].high, m5[i + 1].close) - MathMin(m5[i].low, m5[i + 1].close);
      double run = 0.0;
      for(int i = 0; i < 14; i++) run += trs[i];
      double cur = run / 14.0;
      int below = 0, total = 0;
      for(int i = 14; i < cnt; i++)
      {
         run += trs[i] - trs[i - 14];
         if(run / 14.0 < cur) below++;
         total++;
      }
      G_MB_VOL_PCT = (total > 0) ? 100.0 * below / total : -1.0;
   }
}

// H1 dealing range: the most recent swing high above price and swing low below it.
void MBDealingRangeUpdate(const double price)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_H1, 0, 160, r);
   if(n < 20)
      return;
   int len = MathMax(1, MBSwingLenHTF);
   double hi = 0.0, lo = 0.0;
   for(int k = 1 + len; k <= n - 1 - len && (hi == 0.0 || lo == 0.0); k++)
   {
      bool is_hi = true, is_lo = true;
      for(int j = 1; j <= len; j++)
      {
         if(r[k].high <= r[k - j].high || r[k].high < r[k + j].high) is_hi = false;
         if(r[k].low  >= r[k - j].low  || r[k].low  > r[k + j].low)  is_lo = false;
      }
      if(is_hi && hi == 0.0 && r[k].high > price) hi = r[k].high;
      if(is_lo && lo == 0.0 && r[k].low < price)  lo = r[k].low;
   }
   if(hi > lo && lo > 0.0)
   {
      G_MB_DR_HI = hi;
      G_MB_DR_LO = lo;
      G_MB_DR_POS = (price - lo) / (hi - lo);
   }
}

// Nearest untouched pool beyond price on side `side` (+1 above, -1 below), on one timeframe.
void MBNearestIntactPool(const ENUM_TIMEFRAMES tf, const int bars, const int len, const int side, const double price,
                         const double min_pierce, const double eq_tol, double &best, string &what, const string tf_name)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, tf, 0, bars, r);
   if(n < 20)
      return;
   MBBuildSwingPools(r, n, 1, len, eq_tol);
   for(int p = 0; p < G_MB_PL_COUNT; p++)
   {
      if(G_MB_PL_SIDE[p] != side) continue;
      double lvl = G_MB_PL_LEVEL[p];
      if(side > 0 && lvl <= price) continue;
      if(side < 0 && lvl >= price) continue;
      // Untouched since it formed, up to and including the forming bar.
      bool intact = true;
      for(int j = 0; j < n; j++)
      {
         if(r[j].time <= G_MB_PL_FROM[p]) break;
         if(side > 0 && r[j].high > lvl + min_pierce) { intact = false; break; }
         if(side < 0 && r[j].low  < lvl - min_pierce) { intact = false; break; }
      }
      if(!intact) continue;
      if(best == 0.0 || MathAbs(lvl - price) < MathAbs(best - price))
      {
         best = lvl;
         what = StringFormat("%s %s", tf_name, MBPoolKindName(G_MB_PL_KIND[p], side));
      }
   }
}

void MBDrawOnLiquidityUpdate(const int dir, const double price)
{
   G_MB_DOL = 0.0;
   G_MB_DOL_WHAT = "";
   if(dir == 0)
      return;
   double atr5 = ((G_MB_ATR[1] > 0.0) ? G_MB_ATR[1] : 100.0) * _Point;
   double min_pierce = MBSweepMinATR * atr5;
   double eq_tol = MBEqualLevelATR * atr5;
   double best = 0.0;
   string what = "";
   MBNearestIntactPool(PERIOD_M15, 160, MathMax(1, MBSwingLenHTF), dir, price, min_pierce, eq_tol, best, what, "M15");
   MBNearestIntactPool(PERIOD_H1,  160, MathMax(1, MBSwingLenHTF), dir, price, min_pierce, eq_tol, best, what, "H1");
   MBNearestIntactPool(PERIOD_H4,  120, MathMax(1, MBSwingLenHTF), dir, price, min_pierce, eq_tol, best, what, "H4");
   // Yesterday's high / low when still untouched today.
   double pd = (dir > 0) ? iHigh(_Symbol, PERIOD_D1, 1) : iLow(_Symbol, PERIOD_D1, 1);
   double today_ext = (dir > 0) ? iHigh(_Symbol, PERIOD_D1, 0) : iLow(_Symbol, PERIOD_D1, 0);
   bool pd_intact = (dir > 0) ? (pd > 0.0 && today_ext <= pd) : (pd > 0.0 && today_ext >= pd);
   if(pd_intact && ((dir > 0 && pd > price) || (dir < 0 && pd < price)) &&
      (best == 0.0 || MathAbs(pd - price) < MathAbs(best - price)))
   {
      best = pd;
      what = (dir > 0) ? "PDH" : "PDL";
   }
   G_MB_DOL = best;
   G_MB_DOL_WHAT = what;
}

// Invalidation for a new thesis: the extreme of the sweep that started it, or the nearest
// M15 swing on the other side of price.
double MBThesisInvalidation(const int dir, const double price)
{
   double inv = 0.0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dir) continue;
      if(G_MB_EV[idx].type != MB_EV_LIQ_SWEEP && G_MB_EV[idx].type != MB_EV_FAKE_BREAK) continue;
      if(MBEventRank(G_MB_EV[idx].tfi) < 1) continue;
      int lim = (G_MB_EV[idx].tfi == MB_POOL_KEY) ? 2 * MBRelevantBarsHTF : MBRelevantLimit(G_MB_EV[idx].tfi);
      if(MBEventAgeBars(G_MB_EV[idx]) > lim) continue;
      double x = G_MB_EV[idx].extreme;
      if(dir > 0 && x < price && (inv == 0.0 || x < inv)) inv = x;
      if(dir < 0 && x > price && (inv == 0.0 || x > inv)) inv = x;
   }
   if(inv > 0.0)
      return inv;

   // HIDDEN-BUG FIX: the nearest M15 swing could sit a few dozen points away, so an ordinary pullback
   // "killed" the thesis. The line must be at least 0.8 ATR(M15) from price - a level a pullback does
   // not reach unless the story really changed.
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M15, 0, 120, r);
   int len = MathMax(1, MBSwingLenHTF);
   double min_d = 0.8 * ((G_MB_ATR[2] > 0.0) ? G_MB_ATR[2] : 2.0 * G_MB_ATR[1]) * _Point;
   for(int k = 1 + len; k <= n - 1 - len; k++)
   {
      bool is_hi = true, is_lo = true;
      for(int j = 1; j <= len; j++)
      {
         if(r[k].high <= r[k - j].high || r[k].high < r[k + j].high) is_hi = false;
         if(r[k].low  >= r[k - j].low  || r[k].low  > r[k + j].low)  is_lo = false;
      }
      if(dir > 0 && is_lo && r[k].low < price - min_d) return r[k].low;
      if(dir < 0 && is_hi && r[k].high > price + min_d) return r[k].high;
   }
   return 0.0;
}

int MBContradiction(const int dir, const datetime since)
{
   double w = 0.0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= since || G_MB_EV[idx].dir != -dir) continue;
      if(MBEventRank(G_MB_EV[idx].tfi) < 1) continue;
      if(!MBEventRelevant(idx)) continue;   // LOCK FIX: old arguments age out instead of piling up for days
      double ew = MBEventWeight(G_MB_EV[idx]);
      if(ew <= 0.0) continue;
      w += ew * G_MB_EV[idx].strength;
   }
   if(w >= 12.0) return 2;
   if(w >= 5.0)  return 1;
   return 0;
}

//---------------------------------------------------------------------
// LOCAL DIRECTION - the market under the global one (three layers)
//---------------------------------------------------------------------
//   GLOBAL  M15 / H1 / H4  - the brain's bias            (G_MB_BIAS)
//   LOCAL   M5             - the leg running now          (MBLayerLocal)
//   MICRO   M1             - the moment                   (MBLayerMicro)
// A scalper lives on the legs inside the day: a bearish day still has bullish M1 / M5 legs worth a
// few dollars each. MBLocalLevel says how strong the case is for a local leg in dir; MBLocalOkFor
// says whether it is strong ENOUGH right now, after the guards below.
// Local thesis state (filled by MBLocalThesisUpdate below).
int      G_LOC_TH_DIR    = 0;
double   G_LOC_TH_ORIGIN = 0.0;
double   G_LOC_TH_TARGET = 0.0;
double   G_LOC_TH_INVALID = 0.0;
datetime G_LOC_TH_SINCE  = 0;
string   G_LOC_TH_STATE  = "-";
datetime G_LOC_TH_END    = 0;       // when the last local thesis ended

// FIX(local-lag): the M5 structure only turns when a swing breaks - inside a range that is the end
// of the leg, not its start. The local layer now reads, in order: a live M5 impulse (not late), the
// net move of the last six M5 closes (>= 1 ATR), then the structure, then the pressure.
int MBLayerLocal()
{
   if(G_MB_IMP_DIR[1] != 0 && G_MB_SPEED[1] <= MB_SPEED_NORMAL && G_MB_SPEED[1] != MB_SPEED_NONE)
      return G_MB_IMP_DIR[1];
   double atr5 = G_MB_ATR[1] * _Point;
   double c1 = iClose(_Symbol, PERIOD_M5, 1), c7 = iClose(_Symbol, PERIOD_M5, 7);
   if(atr5 > 0.0 && c1 > 0.0 && c7 > 0.0)
   {
      if(c1 - c7 >= atr5) return 1;
      if(c7 - c1 >= atr5) return -1;
   }
   int s5 = MBSign(G_MB_TF_STATE[1]);
   if(s5 != 0) return s5;
   return MBPressureSide(1);
}

int MBLayerMicro()
{
   if(G_MB_LIVE_DIR != 0) return G_MB_LIVE_DIR;
   int p1 = MBPressureSide(0);
   if(p1 != 0) return p1;
   return G_MB_TREND[0];
}

// Local learning / protection state (results of baskets opened against the global bias).
int      G_LOC_RES[30];          // 1 win, 0 loss, -1 empty
int      G_LOC_RES_N = 0;
int      G_LOC_LOSS_STREAK = 0;
datetime G_LOC_PAUSE_UNTIL = 0;
bool     G_LOC_RES_INIT = false;

double MBLocalWinRate(int &n)
{
   if(!G_LOC_RES_INIT) { ArrayInitialize(G_LOC_RES, -1); G_LOC_RES_INIT = true; }
   int w = 0;
   n = 0;
   for(int i = 0; i < 30; i++)
      if(G_LOC_RES[i] >= 0) { n++; w += G_LOC_RES[i]; }
   return (n > 0) ? (double)w / n : -1.0;
}

// Called by the Position Brain when a local basket closes.
void MBLocalRecord(const bool won)
{
   if(!G_LOC_RES_INIT) { ArrayInitialize(G_LOC_RES, -1); G_LOC_RES_INIT = true; }
   G_LOC_RES[G_LOC_RES_N % 30] = won ? 1 : 0;
   G_LOC_RES_N++;
   G_LOC_LOSS_STREAK = won ? 0 : G_LOC_LOSS_STREAK + 1;
   if(!won && G_LOC_LOSS_STREAK >= MathMax(1, LocalLossPauseCount))
   {
      G_LOC_PAUSE_UNTIL = TimeCurrent() + MathMax(1, LocalLossPauseMinutes) * 60;   // bounded - never a freeze
      G_LOC_LOSS_STREAK = 0;
      if(VerboseLogs)
         PrintFormat("[SIRUS LOCAL] %d local losses in a row - local trading paused %d min (global trading continues)",
                     LocalLossPauseCount, LocalLossPauseMinutes);
   }
}

// 0 = no local case for dir, 1 = a local leg, 2 = a strong one.
int MBLocalLevelRaw(const int dir)
{
   if(!EnableLocalTrading || dir == 0)
      return 0;
   bool m5 = (MBSign(G_MB_TF_STATE[1]) == dir) || (MBLayerLocal() == dir);
   bool m1 = (G_MB_TREND[0] == dir);
   bool p1 = (MBPressureSide(0) == dir);
   bool p5 = (MBPressureSide(1) == dir);
   bool lvl1 = (m5 && (p1 || p5)) || (m1 && p1 && p5);
   // FIX(local-disagree): the local thesis already says a leg runs this way (target + invalidation) -
   // the entry side must not then say "no local leg".
   if(!lvl1 && G_LOC_TH_DIR == dir)
      lvl1 = true;
   if(!lvl1)
      return 0;
   if(m5 && m1 && p1 && p5)
   {
      string w = "";
      datetime t = 0;
      if(MBReversalAfter(dir, 0, 1, false, TimeCurrent() - 1800, w, t))
         return 2;
   }
   return 1;
}

// Why a local leg in dir is NOT tradable right now ("" = it may be).
string MBLocalBlockReason(const int dir)
{
   int g = MBSign(G_MB_BIAS);
   if(g == 0 || dir != -g)
      return "";                                   // not against the global bias - nothing to guard
   if(TimeCurrent() < G_LOC_PAUSE_UNTIL)
      return StringFormat("local paused %d min after losses", (int)((G_LOC_PAUSE_UNTIL - TimeCurrent()) / 60));
   // (4) the global leg is fresh: a young M5 impulse the global way - bounces against it are small.
   if(G_MB_IMP_DIR[1] == g && G_MB_SPEED[1] == MB_SPEED_EARLY)
      return "global leg fresh (young M5 impulse)";
   // (4) never against an expansion.
   if(EnableRegimePlaybook && G_MB_RG == MB_RG_EXPANSION && G_MB_RG_DIR == g)
      return "global expansion";
   // (6) only the first two local waves.
   if(G_MB_IMP_DIR[0] == dir && G_MB_IMP_WAVES[0] >= 3)
      return "local leg in its 3rd wave";
   return "";
}

// How strong a local case must be now: strongest global bias, a trend regime at a session open, or a
// poor local record each ask for the strong grade.
int MBLocalNeed(const int dir)
{
   int a = dir * G_MB_BIAS;
   int need = (a <= -3) ? 2 : 1;
   if(EnableRegimePlaybook && G_MB_RG == MB_RG_TREND && G_MB_RG_DIR == -dir && MBSessionOpenWindow())
      need = 2;                                    // (8) trend legs run at the session opens
   int n = 0;
   double wr = MBLocalWinRate(n);
   if(n >= 30 && wr < 0.40)
      need = 2;                                    // (7) the local record says be pickier
   return need;
}

int MBLocalLevel(const int dir)
{
   int lv = MBLocalLevelRaw(dir);
   if(lv > 0 && StringLen(MBLocalBlockReason(dir)) > 0)
      return 0;
   return lv;
}

bool MBLocalOkFor(const int dir)
{
   return (MBLocalLevel(dir) >= MBLocalNeed(dir));
}

//---------------------------------------------------------------------
// LOCAL THESIS (2): a counter leg has its own target and invalidation
//---------------------------------------------------------------------
// A bounce against the trend usually retraces 38-62% of the global leg. Target: half of the leg
// from the local origin up to the global leg's top (M15, last 20 bars), or the nearest opposing zone
// if that is closer. Invalidation: the local origin. Done or dead, the local thesis closes.

void MBLocalThesisUpdate(const double price)
{
   int g = MBSign(G_MB_BIAS);
   int ld = -g;
   double atr5 = G_MB_ATR[1] * _Point;
   if(G_LOC_TH_DIR != 0)
   {
      bool dead = (G_LOC_TH_DIR > 0) ? (price < G_LOC_TH_INVALID) : (price > G_LOC_TH_INVALID);
      bool done = (G_LOC_TH_TARGET > 0.0) && ((G_LOC_TH_DIR > 0) ? (price >= G_LOC_TH_TARGET) : (price <= G_LOC_TH_TARGET));
      if(dead || done || g == 0 || G_LOC_TH_DIR != ld)
      {
         G_LOC_TH_STATE = dead ? "yiqildi" : (done ? "maqsadga yetdi" : "global o'zgardi");
         G_LOC_TH_DIR = 0;
         G_LOC_TH_END = TimeCurrent();
      }
   }
   if(G_LOC_TH_DIR == 0 && g != 0 && atr5 > 0.0 && MBLocalLevelRaw(ld) >= 1)
   {
      MqlRates m1[];
      ArraySetAsSeries(m1, true);
      MqlRates m15[];
      ArraySetAsSeries(m15, true);
      if(CopyRates(_Symbol, PERIOD_M1, 1, 30, m1) < 10 || CopyRates(_Symbol, PERIOD_M15, 1, 20, m15) < 10)
         return;
      double origin = (ld > 0) ? DBL_MAX : -DBL_MAX;
      for(int i = 0; i < ArraySize(m1); i++)
         origin = (ld > 0) ? MathMin(origin, m1[i].low) : MathMax(origin, m1[i].high);
      double top = (ld > 0) ? -DBL_MAX : DBL_MAX;
      for(int i = 0; i < ArraySize(m15); i++)
         top = (ld > 0) ? MathMax(top, m15[i].high) : MathMin(top, m15[i].low);
      double target = origin + 0.5 * (top - origin);
      double zone = (ld > 0) ? ZoneMapNearestResistance(price) : ZoneMapNearestSupport(price);
      if(zone > 0.0 && MathAbs(zone - price) >= 0.5 * atr5 && ((ld > 0) ? (zone < target) : (zone > target)))
         target = zone;
      if(MathAbs(target - price) < 0.5 * atr5)
         return;   // no room for a local leg
      G_LOC_TH_DIR = ld;
      G_LOC_TH_ORIGIN = origin;
      G_LOC_TH_INVALID = origin - ld * 0.1 * atr5;
      G_LOC_TH_TARGET = target;
      G_LOC_TH_SINCE = TimeCurrent();
      G_LOC_TH_STATE = "faol";
      if(MBThesisPrintOnUse && VerboseLogs)
         PrintFormat("[SIRUS LOCAL] new local %s leg against %s | target %s | invalid beyond %s",
                     (ld > 0 ? "BULLISH" : "BEARISH"), MBBiasName(G_MB_BIAS),
                     DoubleToString(target, _Digits), DoubleToString(G_LOC_TH_INVALID, _Digits));
   }
}

// (3) HANDOFF: the local leg has run into the global side's place (its target, a premium / discount
// zone of the H1 range, or an opposing zone) and the micro layer has turned back the global way. The
// best global entry of the day: the top of the bounce.
bool MBHandoffNow(const int gdir, string &why)
{
   why = "";
   if(gdir == 0 || MBLayerLocal() != -gdir)
      return false;
   if(MBLayerMicro() != gdir)
      return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr5 = G_MB_ATR[1] * _Point;
   bool at_place = false;
   string place = "";
   if(G_LOC_TH_DIR == -gdir && G_LOC_TH_TARGET > 0.0 && MathAbs(bid - G_LOC_TH_TARGET) <= 0.3 * atr5)
   { at_place = true; place = "local target"; }
   if(!at_place && G_MB_DR_HI > G_MB_DR_LO && ((gdir < 0 && G_MB_DR_POS >= 0.60) || (gdir > 0 && G_MB_DR_POS <= 0.40)))
   { at_place = true; place = (gdir < 0 ? "H1 premium" : "H1 discount"); }
   if(!at_place && atr5 > 0.0)
   {
      double z = (gdir < 0) ? ZoneMapNearestResistance(bid) : ZoneMapNearestSupport(bid);
      if(z > 0.0 && MathAbs(z - bid) <= 0.5 * atr5) { at_place = true; place = "opposing zone"; }
   }
   if(!at_place)
      return false;
   why = StringFormat("local leg ran into %s and turned", place);
   return true;
}

string MBLocalText()
{
   for(int d = 1; d >= -1; d -= 2)
   {
      int lv = MBLocalLevelRaw(d);
      if(lv > 0)
      {
         string blk = MBLocalBlockReason(d);
         string t = StringFormat("%s %s", (d > 0 ? "▲" : "▼"), (lv >= 2 ? "kuchli" : "bor"));
         if(StringLen(blk) > 0) t += " (to'siq: " + blk + ")";
         return t;
      }
   }
   return "-";
}

void MBBrainUpdate()
{
   if(!EnableMarketBrain || !EnableMarketBrainEngines)
      return;
   datetime bar = iTime(_Symbol, PERIOD_M1, 0);
   if(bar <= 0 || bar == G_MB_BRAIN_BAR)
      return;
   G_MB_BRAIN_BAR = bar;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
      return;

   for(int tfi = 1; tfi < MB_TF_COUNT; tfi++)
      G_MB_TF_STATE[tfi] = MBTimeframeState(tfi);
   MBRegimeUpdate();   // stage 15: once per M15 bar
   G_MB_TF_STATE[0] = MB_BIAS_NEUTRAL;

   int s5 = G_MB_TF_STATE[1], s15 = G_MB_TF_STATE[2], s1h = G_MB_TF_STATE[3], s4h = G_MB_TF_STATE[4];
   int bias = s15;
   string why = StringFormat("M15 %s", MBBiasName(s15));

   if(s15 == MB_BIAS_NEUTRAL && s5 != MB_BIAS_NEUTRAL)
   {
      bias = (MathAbs(s5) == 3) ? 2 * MBSign(s5) : s5;   // M5 alone carries less authority
      why = StringFormat("M15 neutral, M5 %s", MBBiasName(s5));
   }
   else if(MBSign(s5) != 0 && MBSign(s15) != 0 && MBSign(s5) != MBSign(s15))
   {
      // FIX(bias-flip-flop): an M5 structure against M15 is usually just a pullback. Treating every
      // one as a transition flipped the bias on each M5 swing, and the permission matrix then blocked
      // one side and the other in turn - the EA hesitated between directions. A transition now needs
      // a CONFIRMED M5 liquidity reversal (sweep / fake break plus displacement, MSS or reclaim) after
      // M15 last made structure; otherwise M15 keeps the direction, one notch weaker.
      int le15b = MBLastStructureEvent(2);
      datetime since15 = (le15b >= 0) ? G_MB_EV[le15b].time : 0;
      string w5 = "";
      datetime t5 = 0;
      if(MBReversalAfter(MBSign(s5), 1, 1, false, since15, w5, t5))
      {
         bias = (s5 > 0) ? MB_BIAS_TRANSITION_UP : MB_BIAS_TRANSITION_DOWN;
         why = StringFormat("M15 %s, but M5 reversal: %s", MBBiasName(s15), w5);
      }
      else
      {
         bias = (MathAbs(s15) == 3) ? 2 * MBSign(s15) : s15;
         why = StringFormat("M15 %s, M5 pullback (%s)", MBBiasName(s15), MBBiasName(s5));
      }
   }

   // A fresh confirmed reversal at H1 / H4 / daily liquidity is a transition by itself - unless
   // M15 has since made structure the other way (the market already answered it).
   int le15 = MBLastStructureEvent(2);
   // AUDIT FIX: when both sides have one, the newer reversal wins (the second pass used to overwrite).
   datetime best_swt = 0;
   for(int d = -1; d <= 1; d += 2)
   {
      string w = "";
      datetime swt = 0;
      if(MBSign(bias) != d && MBReversalAfter(d, 3, 4, true, 0, w, swt) &&
         !(le15 >= 0 && G_MB_EV[le15].dir == -d && G_MB_EV[le15].time > swt) && swt > best_swt)
      {
         best_swt = swt;
         bias = (d > 0) ? MB_BIAS_TRANSITION_UP : MB_BIAS_TRANSITION_DOWN;
         why = "HTF liquidity reversal: " + w;
      }
   }

   // MOMENTUM CONFIRMS A TRANSITION: M15 has only turned (MSS, no BOS yet), but M5 structure, the
   // candle pressure (two of M1 / M5 / M15) and the absence of a reversal the other way all say the
   // move is already running. For entries that is a trend, not a "maybe" - waiting for the M15 BOS is
   // how a $5 fall went by with the brain still "awakening".
   if(EnableCandleDirectionLink && MathAbs(bias) == 1)
   {
      int td = MBSign(bias);
      int pc = (MBPressureSide(0) == td ? 1 : 0) + (MBPressureSide(1) == td ? 1 : 0) + (MBPressureSide(2) == td ? 1 : 0);
      string rw = "";
      datetime rt = 0;
      if(MBSign(s5) == td && pc >= 2 && !MBReversalAfter(-td, 1, 4, true, 0, rw, rt))
      {
         bias = 2 * td;
         why += StringFormat(" + M5 structure and %d/3 pressure with it (momentum confirms)", pc);
      }
   }

   // FIX(bias-flip-flop): a new bias must hold for two consecutive M1 bars before it replaces the old
   // one - except a strengthening in the same direction or an HTF liquidity reversal, which apply at
   // once. One noisy bar no longer swings the permission matrix.
   bool htf_driven = (StringFind(why, "HTF liquidity reversal") == 0);
   bool same_side_stronger = (MBSign(bias) == MBSign(G_MB_BIAS) && MathAbs(bias) >= MathAbs(G_MB_BIAS));
   if(bias != G_MB_BIAS && !htf_driven && !same_side_stronger && G_MB_BRAIN_PRIMED)
   {
      if(bias == G_MB_BIAS_CAND)
         G_MB_BIAS_CAND_N++;
      else
      {
         G_MB_BIAS_CAND = bias;
         G_MB_BIAS_CAND_N = 1;
      }
      // STAGE 13 (A1): the candles decide how long the new view must wait. A strong candle the new
      // way (displacement, rejection, liquidity grab, failed break) on M1 or M5 confirms it at once;
      // candles still pushing the old way make it wait longer. No candle opinion: two bars, as before.
      int need = 2;
      int cs = MBSign(bias);
      if(EnableCandleDirectionLink && cs != 0)
      {
         if(MBCandleConfirms(0, cs) || MBCandleConfirms(1, cs))
            need = 1;
         else if(MBCandleOpposes(0, cs) && MBCandleOpposes(1, cs))
            need = 4;
         else if(MBCandleOpposes(1, cs))
            need = 3;
      }
      if(need == 1 && G_MB_BIAS_CAND_N >= 1)
         why += " [candle-confirmed]";
      if(G_MB_BIAS_CAND_N < need)
      {
         why = G_MB_BIAS_WHY;   // keep the standing view this bar
         bias = G_MB_BIAS;
      }
   }
   else
   {
      G_MB_BIAS_CAND = bias;
      G_MB_BIAS_CAND_N = 0;
   }
   G_MB_BRAIN_PRIMED = true;

   int conf = 50 + 12 * MathAbs(bias);
   if(MBSign(s1h) != 0) conf += (MBSign(s1h) == MBSign(bias)) ? 8 : -10;
   if(MBSign(s4h) != 0) conf += (MBSign(s4h) == MBSign(bias)) ? 6 : -6;
   // STAGE 13 (A2): what the candles are actually doing on M5 and M15.
   if(EnableCandleDirectionLink && MBSign(bias) != 0)
   {
      int p5 = MBPressureSide(1), p15 = MBPressureSide(2);
      if(p15 != 0) conf += (p15 == MBSign(bias)) ? 5 : -6;
      if(p5 != 0)  conf += (p5 == MBSign(bias)) ? 3 : -3;
   }
   G_MB_BIAS = bias;
   G_MB_BIAS_WHY = why;

   MBDealingRangeUpdate(price);
   MBDrawOnLiquidityUpdate(MBSign(bias), price);
   MBLocalThesisUpdate(price);   // the local leg's own target and invalidation

   // --- Thesis life ---
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   datetime now = TimeCurrent();
   int bdir = MBSign(bias);

   if(G_MB_TH_DIR != 0 && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED))
   {
      // HIDDEN-BUG FIX: a close a hair beyond the line is noise, not a dead story - it must clear it by
      // 0.15 ATR(M5).
      double inv_buf = 0.15 * G_MB_ATR[1] * _Point;
      bool invalid = (G_MB_TH_INVALID > 0.0 && c1 > 0.0) &&
                     ((G_MB_TH_DIR > 0 && c1 < G_MB_TH_INVALID - inv_buf) || (G_MB_TH_DIR < 0 && c1 > G_MB_TH_INVALID + inv_buf));
      bool done = (G_MB_TH_TARGET > 0.0) &&
                  ((G_MB_TH_DIR > 0 && iHigh(_Symbol, PERIOD_M1, 1) >= G_MB_TH_TARGET) ||
                   (G_MB_TH_DIR < 0 && iLow(_Symbol, PERIOD_M1, 1) <= G_MB_TH_TARGET));
      if(invalid)
      {
         G_MB_TH_STATE = MB_TH_INVALIDATED;
         G_MB_DEAD_DIR = G_MB_TH_DIR;
         G_MB_DEAD_TIME = now;
         G_MB_DEAD_UNTIL = now + MathMax(1, MBInvalidationMemoryM5) * PeriodSeconds(PERIOD_M5);
         if((MBThesisPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS THESIS] %s thesis INVALIDATED: M5 closed %s beyond %s - that story is dead",
                        (G_MB_TH_DIR > 0 ? "BULLISH" : "BEARISH"), DoubleToString(c1, _Digits), DoubleToString(G_MB_TH_INVALID, _Digits));
      }
      else if(done)
      {
         G_MB_TH_STATE = MB_TH_DONE;
         if((MBThesisPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS THESIS] %s thesis DONE: target %s reached - watching for the other side's liquidity",
                        (G_MB_TH_DIR > 0 ? "BULLISH" : "BEARISH"), DoubleToString(G_MB_TH_TARGET, _Digits));
      }
      else if(G_MB_TH_STATE == MB_TH_ACTIVATED && bdir == G_MB_TH_DIR && MathAbs(bias) >= 2)
      {
         G_MB_TH_STATE = MB_TH_CONFIRMED;
         if((MBThesisPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS THESIS] %s thesis CONFIRMED (%s)", (G_MB_TH_DIR > 0 ? "BULLISH" : "BEARISH"), MBBiasName(bias));
      }
   }

   // HIDDEN-BUG FIX: the invalidation memory used to lock a direction for two hours unless the bias
   // reached its strongest grade - in a market that kept falling after one noisy M5 close, every SELL
   // was vetoed and no new bearish thesis could open. The lock now lifts as soon as the market
   // re-confirms that direction: the bias back to at least weak-trend AND a new M5+ BOS / MSS /
   // displacement / acceptance that way after the death, or a live M5+ liquidity sweep that way.
   if(G_MB_DEAD_DIR != 0 && now < G_MB_DEAD_UNTIL)
   {
      int dd = G_MB_DEAD_DIR;
      string lift = "";
      if(dd * bias >= 2)
      {
         for(int idx = 0; idx < MB_EV_MAX && StringLen(lift) == 0; idx++)
         {
            if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dd) continue;
            if(MBEventRank(G_MB_EV[idx].tfi) < 1) continue;
            int ty = G_MB_EV[idx].type;
            if(ty != MB_EV_BOS && ty != MB_EV_MSS && ty != MB_EV_DISPLACEMENT && ty != MB_EV_ACCEPTANCE) continue;
            if(G_MB_EV[idx].time + PeriodSeconds(MBEventTF(G_MB_EV[idx].tfi)) <= G_MB_DEAD_TIME) continue;
            lift = StringFormat("%s %s after the death", MBTFName(G_MB_EV[idx].tfi), MBEventName(ty));
         }
      }
      string lw = "";
      if(StringLen(lift) == 0 && G_MB_LSW_TFI >= 1 && G_MB_LSW_TIME > G_MB_DEAD_TIME && MBLiveSweepFresh(dd, lw))
         lift = lw;
      if(StringLen(lift) > 0)
      {
         G_MB_DEAD_UNTIL = 0;
         G_MB_DEAD_DIR = 0;
         if((MBThesisPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS THESIS] %s lock lifted - the market re-confirmed it (%s, %s)",
                        (dd > 0 ? "BULLISH" : "BEARISH"), MBBiasName(bias), lift);
      }
   }

   bool thesis_open = (G_MB_TH_DIR != 0 && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED));
   if(bdir != 0 && (!thesis_open || bdir != G_MB_TH_DIR))
   {
      bool dead = (bdir == G_MB_DEAD_DIR && now < G_MB_DEAD_UNTIL && MathAbs(bias) < 3);
      if(!dead)
      {
         G_MB_TH_DIR = bdir;
         G_MB_TH_STATE = (MathAbs(bias) >= 2) ? MB_TH_CONFIRMED : MB_TH_ACTIVATED;
         G_MB_TH_SINCE = now;
         G_MB_TH_THREAT = false;
         G_MB_TH_INVALID = MBThesisInvalidation(bdir, price);
         G_MB_TH_TARGET = G_MB_DOL;
         if((MBThesisPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS THESIS] new %s thesis %s | %s | target %s (%s) | invalid beyond %s",
                        (bdir > 0 ? "BULLISH" : "BEARISH"), MBThesisStateName(G_MB_TH_STATE), why,
                        (G_MB_TH_TARGET > 0.0 ? DoubleToString(G_MB_TH_TARGET, _Digits) : "-"), G_MB_DOL_WHAT,
                        (G_MB_TH_INVALID > 0.0 ? DoubleToString(G_MB_TH_INVALID, _Digits) : "-"));
      }
   }

   // STAGE 16 (A7): THREATENED - before the invalidation close, the candles already warn. A strong M5
   // displacement against the thesis, or M1 and M5 both pushing against it with M5 pressure the
   // other way. A candle confirming the thesis again lifts it. The Position Brain stops the grid
   // while it stands.
   {
      bool open_th = (G_MB_TH_DIR != 0 && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED));
      bool was = G_MB_TH_THREAT;
      if(!open_th || !EnableCandleDirectionLink)
         G_MB_TH_THREAT = false;
      else
      {
         int td = G_MB_TH_DIR;
         bool m5_disp_against = (G_MB_LAST[1].intent == MB_CI_DISPLACEMENT && G_MB_LAST[1].dir == -td);
         bool both_against = MBCandleOpposes(0, td) && MBCandleOpposes(1, td) && MBPressureSide(1) == -td;
         if(m5_disp_against || both_against)
         {
            G_MB_TH_THREAT = true;
            G_MB_TH_THREAT_WHY = m5_disp_against ? StringFormat("M5 displacement against (%.1f ATR)", G_MB_LAST[1].body_atr)
                                                 : "M1 and M5 candles and M5 pressure against";
         }
         else if(MBCandleConfirms(1, td) || (MBCandleConfirms(0, td) && MBPressureSide(1) != -td))
            G_MB_TH_THREAT = false;
      }
      if(G_MB_TH_THREAT != was && open_th && (MBThesisPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS THESIS] %s thesis %s%s", (G_MB_TH_DIR > 0 ? "BULLISH" : "BEARISH"),
                     (G_MB_TH_THREAT ? "THREATENED: " : "no longer threatened"), (G_MB_TH_THREAT ? G_MB_TH_THREAT_WHY : ""));
   }

   G_MB_TH_CONTRA = (G_MB_TH_DIR != 0) ? MBContradiction(G_MB_TH_DIR, G_MB_TH_SINCE) : 0;
   conf -= 8 * G_MB_TH_CONTRA;
   G_MB_BIAS_CONF = (int)MathMax(5, MathMin(95, conf));

   // Narrative.
   string loc = "";
   if(G_MB_DR_HI > G_MB_DR_LO)
      loc = StringFormat("%s (%.2f) of H1 range %s-%s",
                         (G_MB_DR_POS >= 0.55 ? "PREMIUM" : (G_MB_DR_POS <= 0.45 ? "DISCOUNT" : "EQUILIBRIUM")),
                         G_MB_DR_POS, DoubleToString(G_MB_DR_LO, _Digits), DoubleToString(G_MB_DR_HI, _Digits));
   string pref = "-";
   if(MathAbs(bias) == 1) pref = "reversal / reclaim entries";
   else if(MathAbs(bias) >= 2) pref = "continuation / pullback entries";
   G_MB_TH_TEXT = StringFormat("%s %d%% (%s) | M5 %s, M15 %s, H1 %s, H4 %s | %s | DOL %s %s | thesis %s %s, invalid %s, contradiction %s | prefer %s",
                               MBBiasName(bias), G_MB_BIAS_CONF, why,
                               MBBiasName(s5), MBBiasName(s15), MBBiasName(s1h), MBBiasName(s4h),
                               (StringLen(loc) > 0 ? loc : "no H1 range"),
                               (G_MB_DOL > 0.0 ? DoubleToString(G_MB_DOL, _Digits) : "-"), G_MB_DOL_WHAT,
                               (G_MB_TH_DIR > 0 ? "BULL" : (G_MB_TH_DIR < 0 ? "BEAR" : "-")), MBThesisStateName(G_MB_TH_STATE),
                               (G_MB_TH_INVALID > 0.0 ? DoubleToString(G_MB_TH_INVALID, _Digits) : "-"),
                               (G_MB_TH_CONTRA == 2 ? "HIGH" : (G_MB_TH_CONTRA == 1 ? "MEDIUM" : "LOW")),
                               pref);
}

string MBBrainText()
{
   if(!EnableMarketBrain || !EnableMarketBrainEngines)
      return "off";
   return G_MB_TH_TEXT;
}
