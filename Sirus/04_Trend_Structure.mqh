//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 04_Trend_Structure                              |
//| Trend confidence, VWAP, momentum, local structure                |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// ============================================================================
// V31.6z31 UPGRADE: GLOBAL vs LOCAL TREND ALIGNMENT - deepened after direct feedback that the
// first version was too simplistic (direction-only voting, fixed lookup table of 6 hardcoded
// scores). Now genuinely continuous: both Global and Local produce a SIGNED CONFIDENCE
// (-1.0 fully against, 0 neutral, +1.0 fully for) that scales with ADX MAGNITUDE, not just
// direction - a barely-qualifying ADX and a strongly-trending one no longer get treated
// identically. The final alignment score is a real WEIGHTED BLEND of the two confidences
// (global weighted higher, per the user's DD-duration request), with an added non-linear
// adjustment for the specific ambiguous case that matters most: global trend still favors us,
// but local is pushing back HARD - the STRONGER that local push, the more it could be an
// early reversal warning rather than a harmless pullback, and the score now reflects that
// gradient instead of a single flat number for every "pullback" regardless of severity.
// ============================================================================

// GLOBAL: D1 close-trend + H4 ADX (direction AND magnitude) + H4 close-trend, blended into a
// signed confidence rather than a simple vote-count.
//
// V31.6z56 REBUILD: two real defects found via audit of exactly what the "global" read looks at.
//   1) H1 was COMPLETELY ABSENT. The global picture consulted D1 and H4 only - the H1 trend,
//      the natural bridge between the big picture and the local M15 read, had no voice at all.
//   2) The weighting was backwards and double-counted. H4 contributed TWO of the three votes
//      (its ADX direction AND its close-comparison), while D1 - the biggest, most persistent
//      picture - got only one. Worse, those two H4 votes measure the SAME timeframe, so they
//      usually agree and effectively counted one piece of information twice: the exact
//      double-counting problem corrected elsewhere this session.
// Now each timeframe contributes ONE signed confidence, weighted by its structural importance
// (D1 > H4 > H1), with ADX magnitude driving conviction and a deliberately weak close-based
// fallback when ADX doesn't qualify.
double GlobalTFConfidence(const ENUM_TIMEFRAMES tf, const int direction, const int simple_lookback)
{
   double adx = 0.0, plus = 0.0, minus = 0.0;
   CachedADXSnapshot(tf, GlobalTrendADXPeriod, adx, plus, minus);
   int adx_dir = (plus > minus) ? 1 : ((minus > plus) ? -1 : 0);

   if(adx >= GlobalTrendMinADX && adx_dir != 0)
   {
      double mag = MathMax(0.0, MathMin(1.0, (adx - GlobalTrendMinADX) / MathMax(1.0, GlobalTrendADXFullStrength)));
      double signed_conf = (adx_dir == direction) ? mag : -mag;

      // FEATURE(global-trend-momentum): fade check on the primary global TF - a weakening macro trend
      // precedes the big reversals. Only measured / flagged on the primary global TF.
      if(EnableGlobalTrendMomentum && tf == GlobalTrendPrimaryTF)
      {
         double adx_prev = SirusADX(tf, GlobalTrendADXPeriod, 0, 1 + MathMax(1, GlobalTrendADXSlopeBars));
         if(adx_prev > 0.0 && (adx_prev - adx) >= GlobalTrendADXFadeDelta)
         {
            G_GLOBAL_TREND_FADING = true;
            signed_conf *= MathMax(0.0, MathMin(1.0, GlobalTrendFadeDampen));
         }
      }

      return signed_conf;
   }

   // FEATURE(local-trend-range-floor): same range guard on the global TFs - very low ADX means no
   // trend, so don't let a stray close-comparison manufacture a weak global bias out of a range.
   // FIX(global-notrend-floor): was LocalTrendNoTrendADX (tuned for M15) - now uses the dedicated
   // GlobalTrendNoTrendADX floor, since D1/H4/H1 ADX needs a different threshold to mean "range".
   if(adx > 0.0 && adx < GlobalTrendNoTrendADX)
      return 0.0;

   int simple = SimpleTFDirection(tf, simple_lookback);
   if(simple == direction)  return GlobalTrendWeakConfirmValue;
   if(simple == -direction) return -GlobalTrendWeakConfirmValue;
   return 0.0;
}

double GlobalTrendConfidenceRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableGlobalLocalTrendSplit || direction == 0)
      return 0.0;

   G_GLOBAL_TREND_FADING = false;    // FEATURE(global-trend-momentum): recomputed below on the primary global TF
   G_GLOBAL_TREND_TURNING = false;

   double weighted_sum = 0.0;
   double total_weight = 0.0;

   // D1 - the biggest, most persistent picture. Heaviest weight.
   double d1_conf = GlobalTFConfidence(PERIOD_D1, direction, MathMax(2, HunterD1LookbackDays));
   weighted_sum += d1_conf * GlobalTrendWeightD1;
   total_weight += GlobalTrendWeightD1;

   // H4 - the main swing structure.
   double h4_conf = GlobalTFConfidence(PERIOD_H4, direction, GlobalTrendH4LookbackBars);
   weighted_sum += h4_conf * GlobalTrendWeightH4;
   total_weight += GlobalTrendWeightH4;

   // H1 - NEW. The bridge between the big picture and the local read.
   double h1_conf = GlobalTFConfidence(PERIOD_H1, direction, GlobalTrendH1LookbackBars);
   weighted_sum += h1_conf * GlobalTrendWeightH1;
   total_weight += GlobalTrendWeightH1;

   if(total_weight <= 0.0)
      return 0.0;

   double confidence = MathMax(-1.0, MathMin(1.0, weighted_sum / total_weight));

   // FEATURE(global-trend-momentum): turning check on the primary global TF - fast window vs the
   // weighted global sign. If they disagree, the macro trend is flipping, so flag and dampen.
   if(EnableGlobalTrendTurning && direction != 0 && MathAbs(confidence) > 0.0001)
   {
      int conf_sign = (confidence > 0.0) ? direction : -direction;
      int fast_dir  = SimpleTFDirection(GlobalTrendPrimaryTF, GlobalTrendFastLookbackBars);
      if(fast_dir != 0 && fast_dir != conf_sign)
      {
         G_GLOBAL_TREND_TURNING = true;
         confidence *= MathMax(0.0, MathMin(1.0, GlobalTrendTurningDampen));
      }
   }

   detail = StringFormat("global=%.2f(D1=%.2f,H4=%.2f,H1=%.2f%s%s)", confidence, d1_conf, h4_conf, h1_conf,
                         (G_GLOBAL_TREND_FADING ? ",FADING" : ""), (G_GLOBAL_TREND_TURNING ? ",TURNING" : ""));
   return confidence;
}

double GlobalTrendConfidence(const int direction, string &detail)
{
   static int    gtc_cache_bar = -1;
   static int    gtc_cache_dir = 0;
   static double gtc_cache_score = 0.0;
   static string gtc_cache_detail = "";
   static bool   gtc_cache_fading = false;    // FEATURE(global-trend-momentum): cached with the score
   static bool   gtc_cache_turning = false;
   if(gtc_cache_bar > G_BARS_SEEN) gtc_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(gtc_cache_bar != G_BARS_SEEN || gtc_cache_dir != direction)
   {
      gtc_cache_score = GlobalTrendConfidenceRaw(direction, gtc_cache_detail);
      gtc_cache_fading = G_GLOBAL_TREND_FADING;
      gtc_cache_turning = G_GLOBAL_TREND_TURNING;
      gtc_cache_bar = G_BARS_SEEN;
      gtc_cache_dir = direction;
   }

   G_GLOBAL_TREND_FADING = gtc_cache_fading;    // restore for callers even on a cache hit
   G_GLOBAL_TREND_TURNING = gtc_cache_turning;
   detail = gtc_cache_detail;
   return gtc_cache_score;
}

// LOCAL: M15 (or configured LocalTrendTF), ADX magnitude directly drives confidence since
// there's only one timeframe source here - a barely-qualifying local ADX reads as a WEAK
// signal, not the same as a strongly-confirmed one.
// V31.6z57 REBUILD: real asymmetry found via audit of the lower timeframes. The GLOBAL read
// consults three corroborating timeframes (D1/H4/H1, weighted), but LOCAL relied on a SINGLE
// unconfirmed M15 ADX reading - the noisiest kind of input, standing completely alone. Worse,
// the two timeframes that sit either side of it were absent from every trend read in the bot:
//   M5  - the natural bridge from the M1 signal timeframe up to M15
//   M30 - the natural bridge from M15 up to the H1 global read
// M30 in particular appeared NOWHERE outside the Zone Map. So the bot's view of "what is
// happening right now" rested on one timeframe's opinion, with structural blind spots directly
// above and below it. Now mirrors the global read's proven weighted, multi-TF structure.
double LocalTFConfidence(const ENUM_TIMEFRAMES tf, const int direction, const int simple_lookback)
{
   double adx = 0.0, plus = 0.0, minus = 0.0;
   CachedADXSnapshot(tf, LocalTrendADXPeriod, adx, plus, minus);
   int adx_dir = (plus > minus) ? 1 : ((minus > plus) ? -1 : 0);

   if(adx >= LocalTrendMinADX && adx_dir != 0)
   {
      double mag = MathMax(0.0, MathMin(1.0, (adx - LocalTrendMinADX) / MathMax(1.0, LocalTrendADXFullStrength)));
      double signed_conf = (adx_dir == direction) ? mag : -mag;

      // FEATURE(local-trend-momentum): is this trend building or fading? Compare ADX to a few bars
      // back. A meaningful DROP means the trend is losing steam - trim conviction and flag caution.
      // Only evaluated / flagged on the primary local TF so the global flag stays coherent.
      if(EnableLocalTrendMomentum && tf == LocalTrendTF)
      {
         double adx_prev = SirusADX(tf, LocalTrendADXPeriod, 0, 1 + MathMax(1, LocalTrendADXSlopeBars));
         if(adx_prev > 0.0 && (adx_prev - adx) >= LocalTrendADXFadeDelta)
         {
            G_LOCAL_TREND_FADING = true;
            signed_conf *= MathMax(0.0, MathMin(1.0, LocalTrendFadeDampen));
         }
      }

      return signed_conf;
   }

   // FEATURE(local-trend-range-floor): a genuine range (ADX below the no-trend floor) has no trend to
   // read - don't let a stray close-comparison label it a weak up/down trend and invite range entries.
   if(adx > 0.0 && adx < LocalTrendNoTrendADX)
      return 0.0;

   int simple = SimpleTFDirection(tf, simple_lookback);
   if(simple == direction)  return LocalTrendWeakConfirmValue;
   if(simple == -direction) return -LocalTrendWeakConfirmValue;
   return 0.0;
}

double LocalTrendConfidenceRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableGlobalLocalTrendSplit || direction == 0)
      return 0.0;

   G_LOCAL_TREND_FADING = false;   // FEATURE(local-trend-momentum): recomputed below via the primary-TF ADX slope

   double weighted_sum = 0.0;
   double total_weight = 0.0;
   double m5_conf = 0.0, m30_conf = 0.0;

   // M5 - closest corroboration to the M1 signal timeframe. Lightest weight: it is the
   // noisiest of the three and shouldn't dominate.
   if(EnableLocalTrendM5)
   {
      m5_conf = LocalTFConfidence(PERIOD_M5, direction, LocalTrendM5LookbackBars);
      weighted_sum += m5_conf * LocalTrendWeightM5;
      total_weight += LocalTrendWeightM5;
   }

   // M15 (or configured LocalTrendTF) - the primary local read, heaviest weight.
   double m15_conf = LocalTFConfidence(LocalTrendTF, direction, LocalTrendLookbackBars);
   weighted_sum += m15_conf * LocalTrendWeightMain;
   total_weight += LocalTrendWeightMain;

   // M30 - NEW. Bridge up toward the H1 global read; previously absent from every trend check.
   if(EnableLocalTrendM30)
   {
      m30_conf = LocalTFConfidence(PERIOD_M30, direction, LocalTrendM30LookbackBars);
      weighted_sum += m30_conf * LocalTrendWeightM30;
      total_weight += LocalTrendWeightM30;
   }

   if(total_weight <= 0.0)
      return 0.0;

   double confidence = MathMax(-1.0, MathMin(1.0, weighted_sum / total_weight));

   // FEATURE(local-trend-turning): compare a FAST window against the main read on the primary local
   // TF. If the recent (fast) direction disagrees with the confidence sign, the local trend is
   // turning - the main window is still weighted by now-stale bars. Flag it and dampen confidence so
   // a stale trend can't drive a full-conviction decision into a fresh reversal.
   G_LOCAL_TREND_TURNING = false;
   if(EnableLocalTrendTurning && direction != 0 && MathAbs(confidence) > 0.0001)
   {
      int conf_sign = (confidence > 0.0) ? direction : -direction;   // net market lean (not entry dir)
      int fast_dir  = SimpleTFDirection(LocalTrendTF, LocalTrendFastLookbackBars);
      if(fast_dir != 0 && fast_dir != conf_sign)
      {
         G_LOCAL_TREND_TURNING = true;
         confidence *= MathMax(0.0, MathMin(1.0, LocalTrendTurningDampen));
      }
   }

   detail = StringFormat("local=%.2f(M5=%.2f,M15=%.2f,M30=%.2f%s)", confidence, m5_conf, m15_conf, m30_conf,
                         (G_LOCAL_TREND_TURNING ? ",TURNING" : ""));
   return confidence;
}

double LocalTrendConfidence(const int direction, string &detail)
{
   static int    ltc_cache_bar = -1;
   static int    ltc_cache_dir = 0;
   static double ltc_cache_score = 0.0;
   static string ltc_cache_detail = "";
   static bool   ltc_cache_turning = false;   // FEATURE(local-trend-turning): cached with the score so a cache hit doesn't leave the flag stale
   static bool   ltc_cache_fading  = false;   // FEATURE(local-trend-momentum): same, for the fading flag
   if(ltc_cache_bar > G_BARS_SEEN) ltc_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ltc_cache_bar != G_BARS_SEEN || ltc_cache_dir != direction)
   {
      ltc_cache_score = LocalTrendConfidenceRaw(direction, ltc_cache_detail);
      ltc_cache_turning = G_LOCAL_TREND_TURNING;   // captured from the Raw call we just made
      ltc_cache_fading  = G_LOCAL_TREND_FADING;
      ltc_cache_bar = G_BARS_SEEN;
      ltc_cache_dir = direction;
   }

   G_LOCAL_TREND_TURNING = ltc_cache_turning;   // restore for callers even on a cache hit
   G_LOCAL_TREND_FADING  = ltc_cache_fading;
   detail = ltc_cache_detail;
   return ltc_cache_score;
}

// THE SYNTHESIS: a genuine weighted blend of two continuous, magnitude-aware confidences -
// global weighted higher (per the user's DD-duration request) - PLUS a non-linear adjustment
// for the specific case that matters most: global still favors us, but local pushes back hard.
// The STRONGER that local opposition, the more the score tapers toward "this might not be a
// harmless pullback" - a genuine gradient, not a single flat number regardless of severity.
double GlobalLocalAlignmentScoreRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableGlobalLocalTrendSplit || direction == 0)
      return 0.5;

   string g_detail = "", l_detail = "";
   double global_conf = GlobalTrendConfidence(direction, g_detail);
   double local_conf  = LocalTrendConfidence(direction, l_detail);

   // FEATURE(adaptive-alignment-weight): interpolate the weights from the scalp defaults (local-led)
   // toward the deep-basket weights (global-led) as the order count rises. 1 order = pure scalp
   // weighting; AdaptiveAlignFullShiftOrders = full deep-basket weighting.
   double w_global = GlobalLocalWeightGlobal;
   double w_local  = GlobalLocalWeightLocal;
   if(EnableAdaptiveAlignWeight)
   {
      // Safety: the deep-basket global weight must be >= the scalp global weight. The whole point is
      // to INCREASE global protection as the basket deepens; a misconfiguration where deep < scalp
      // would instead weaken protection exactly when the basket is most dangerous. Clamp it.
      double deep_wg = MathMax(GlobalLocalWeightGlobal, MathMin(1.0, DeepBasketWeightGlobal));

      int orders = G_BASKET_ORDERS;
      int full   = MathMax(2, AdaptiveAlignFullShiftOrders);
      double t   = MathMax(0.0, MathMin(1.0, (double)(orders - 1) / (double)(full - 1)));  // 0 at 1 order, 1 at full
      double wg  = GlobalLocalWeightGlobal + (deep_wg - GlobalLocalWeightGlobal) * t;
      w_global = MathMax(0.0, MathMin(1.0, wg));
      w_local  = 1.0 - w_global;
   }

   double blended = global_conf * w_global + local_conf * w_local;

   // The key nuance: global confidently FOR, but local confidently AGAINST - the classic
   // "pullback or early reversal?" ambiguity. Taper down non-linearly as local opposition
   // strengthens, rather than a single fixed penalty regardless of how hard local is pushing.
   if(global_conf >= GlobalLocalPullbackGlobalMin && local_conf <= -GlobalLocalPullbackLocalMin)
   {
      double local_severity = MathAbs(local_conf) - GlobalLocalPullbackLocalMin;
      blended -= local_severity * GlobalLocalPullbackTaperRate;
      detail += "pullback-severity-adjusted ";
   }

   double score = 0.5 + blended * 0.45;
   score = MathMax(0.0, MathMin(1.0, score));

   detail += StringFormat("ALIGN=%.2f | %s | %s", score, g_detail, l_detail);
   return score;
}

double GlobalLocalAlignmentScore(const int direction, string &detail)
{
   static int    gla_cache_bar = -1;
   static int    gla_cache_dir = 0;
   static double gla_cache_score = 0.5;
   static string gla_cache_detail = "";
   static int    gla_cache_orders = -1;   // FEATURE(adaptive-alignment-weight): order count is part of the key - weighting changes as the basket deepens within a bar
   if(gla_cache_bar > G_BARS_SEEN) gla_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(gla_cache_bar != G_BARS_SEEN || gla_cache_dir != direction || gla_cache_orders != G_BASKET_ORDERS)
   {
      gla_cache_score = GlobalLocalAlignmentScoreRaw(direction, gla_cache_detail);
      gla_cache_bar = G_BARS_SEEN;
      gla_cache_dir = direction;
      gla_cache_orders = G_BASKET_ORDERS;
   }

   detail = gla_cache_detail;
   return gla_cache_score;
}

// V31.6z21 NEW: BASKET DD ACCELERATION. Real gap found via systematic follow-up audit: the
// bot tracks DD as a % LEVEL, but never as a RATE - 35%->40% over an hour and 35%->40% over
// five minutes look identical to every threshold check in the system, even though the second
// is a genuinely different, more dangerous situation. Records one DD reading per bar into a
// small history buffer, then compares the RECENT worsening rate to an OLDER window's rate.
void RecordBasketDDHistory()
{
   if(G_BASKET_DD_HISTORY_BAR == G_BARS_SEEN)
      return;

   for(int i = SIRUS_DD_HISTORY_SIZE - 1; i > 0; i--)
      G_BASKET_DD_HISTORY[i] = G_BASKET_DD_HISTORY[i - 1];
   G_BASKET_DD_HISTORY[0] = G_BASKET_DD_PERCENT;

   if(G_BASKET_DD_HISTORY_COUNT < SIRUS_DD_HISTORY_SIZE)
      G_BASKET_DD_HISTORY_COUNT++;

   G_BASKET_DD_HISTORY_BAR = G_BARS_SEEN;
}

double BasketDDAccelerationFactor(string &detail)
{
   detail = "";
   if(!EnableBasketDDAcceleration)
      return 0.0;

   // V31.6z46 fix: found via deep audit - w is a user-configurable input, and while the
   // COUNT check below happens to bound it indirectly (count never exceeds the array size),
   // that's a fragile, non-obvious invariant. Clamping w explicitly makes the array access
   // provably safe regardless of what value the user sets, and regardless of future changes
   // to how COUNT is maintained.
   int w = MathMax(1, MathMin(BasketDDAccelWindowBars, (SIRUS_DD_HISTORY_SIZE - 1) / 2));
   if(G_BASKET_DD_HISTORY_COUNT < w * 2)
      return 0.0;

   double dd_now = G_BASKET_DD_HISTORY[0];
   double dd_mid = G_BASKET_DD_HISTORY[w];
   double dd_old = G_BASKET_DD_HISTORY[MathMin(SIRUS_DD_HISTORY_SIZE - 1, w * 2)];

   double rate_recent = (dd_now - dd_mid) / (double)w;
   double rate_older  = (dd_mid - dd_old) / (double)w;

   if(rate_recent <= 0.0)
      return 0.0;   // DD isn't even worsening right now

   if(rate_older > 0.0 && rate_recent > rate_older * BasketDDAccelRatioThreshold)
   {
      double factor = MathMin(1.0, (rate_recent - rate_older) / MathMax(0.1, rate_older));
      detail = StringFormat("DD accelerating: recent=%.2f%%/bar prior=%.2f%%/bar", rate_recent, rate_older);
      return factor;
   }

   // Older rate was zero/flat but recent rate is meaningfully positive - a fresh acceleration
   // starting from calm, which the ratio comparison above can't catch (division guard).
   if(rate_older <= 0.0 && rate_recent >= BasketDDAccelMinFreshRate)
   {
      detail = StringFormat("DD accelerating from calm: recent=%.2f%%/bar", rate_recent);
      return MathMin(1.0, rate_recent / MathMax(0.1, BasketDDAccelMinFreshRate * 2.0));
   }

   return 0.0;
}

// V31.6z21 NEW: RSI COOLING. RSI is currently only used for divergence (TrendReversalDirection)
// - it never checks a simpler, well-known signal: RSI still in EXTREME territory but LOWER
// than it was recently (overbought and cooling, or oversold and warming) - momentum fading
// while price may still be grinding in the same direction, a classic early exhaustion tell.
double RSICoolingFactor(const int direction, const ENUM_TIMEFRAMES tf, const int period, const int lookback_bars, string &detail)
{
   detail = "";
   if(!EnableRSICooling)
      return 0.0;

   double rsi_now = SirusRSI(tf, period, 1);
   double rsi_prior = SirusRSI(tf, period, MathMax(2, lookback_bars + 1));

   if(rsi_now <= 0.0 || rsi_prior <= 0.0)
      return 0.0;

   if(direction > 0)
   {
      bool still_overbought = (rsi_now >= RSICoolingOverboughtLevel);
      bool cooling = (rsi_now < rsi_prior - RSICoolingMinDrop);
      if(still_overbought && cooling)
      {
         detail = StringFormat("RSI cooling: %.0f->%.0f (still overbought)", rsi_prior, rsi_now);
         return MathMin(1.0, (rsi_prior - rsi_now) / MathMax(1.0, RSICoolingMinDrop * 3.0));
      }
   }
   else
   {
      bool still_oversold = (rsi_now <= RSICoolingOversoldLevel);
      bool warming = (rsi_now > rsi_prior + RSICoolingMinDrop);
      if(still_oversold && warming)
      {
         detail = StringFormat("RSI warming: %.0f->%.0f (still oversold)", rsi_prior, rsi_now);
         return MathMin(1.0, (rsi_now - rsi_prior) / MathMax(1.0, RSICoolingMinDrop * 3.0));
      }
   }

   return 0.0;
}

// V31.6z5 NEW: VWAP (Volume-Weighted Average Price). Unlike a plain moving average, this
// weighs each bar's typical price by its volume - one of the most-watched institutional
// reference levels, a genuinely different dimension than any moving-average-based tool we
// already have. Uses tick_volume (real volume isn't reliably available for most forex/CFD
// symbols) as the weighting proxy.
double CalculateVWAPRaw(const ENUM_TIMEFRAMES tf, const int lookback_bars)
{
   double sum_pv = 0.0;
   double sum_v = 0.0;

   for(int i = 1; i <= lookback_bars; i++)
   {
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      double c = CandleClose(tf, i);
      long vol = iVolume(_Symbol, tf, i);

      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || vol <= 0)
         continue;

      double typical_price = (h + l + c) / 3.0;
      sum_pv += typical_price * (double)vol;
      sum_v += (double)vol;
   }

   if(sum_v <= 0.0)
      return 0.0;

   return sum_pv / sum_v;
}

// Learned the lesson from yesterday - cached from the very first version, not bolted on later.
double CachedVWAP(const ENUM_TIMEFRAMES tf, const int lookback_bars)
{
   static int    vwap_cache_bar = -1;
   static double vwap_cache_value = 0.0;
   if(vwap_cache_bar > G_BARS_SEEN) vwap_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(vwap_cache_bar != G_BARS_SEEN)
   {
      vwap_cache_value = CalculateVWAPRaw(tf, lookback_bars);
      vwap_cache_bar = G_BARS_SEEN;
   }

   return vwap_cache_value;
}

// V31.6z8 NEW: IMPULSE CONFIRMATION. None of the 13 trend-continuation tools (nor Trend
// Quality Score) sense a genuine, sharp impulse candle at all - a real gap, since a single
// decisive burst (unusually large range/body vs recent ATR) is strong, direct evidence of
// real conviction behind a move, distinct from slower measures like ADX or MA order. Scans
// recent bars for the strongest qualifying impulse candle and checks its direction against
// the proposed entry: agreement is a genuine confirmation, a strong impulse the OTHER way is
// a real caution sign even if slower-moving indicators still look fine.
// ============================================================================
// V31.6z53 NEW: MOVE EXTENSION. Direct user report of a real, specific danger: "opening BUY
// right after a big bullish candle - this happens a lot in false breakouts", and "entering at
// the very bottom or very top of a trend and getting stuck".
//
// The root cause is visible in ImpulseConfirmationRaw below: it returned
//     0.6 + (best_ratio - ImpulseMinATRMultiple) * 0.15
// i.e. THE BIGGER THE IMPULSE CANDLE, THE HIGHER THE BONUS - with zero awareness of whether
// that candle appeared at the START of a move (a genuine breakout worth joining) or at the END
// of one that had already run for hours (a blow-off climax - the classic false-breakout trap,
// and exactly where a basket gets stuck at the top).
//
// The same candle means opposite things depending on WHERE it happens. This measures how far
// price has already travelled from the move's origin (recent swing extreme) in ATR units, so
// the impulse bonus can be scaled by maturity instead of size alone.
//
// Returns extension in ATR multiples: ~0 = price is at the move's origin (fresh),
// large = price has already run a long way (mature/climax risk).
// ============================================================================
double MoveExtensionATRRaw(const int direction)
{
   if(!EnableMoveExtension || direction == 0)
      return 0.0;

   // V31.6z55 fix: real limitation caught by the user's question ("does this only count one
   // candle?"). It never counted one candle - it measured from the swing origin - BUT it
   // inherited ImpulseTF (M15) with a 40-bar lookback, i.e. a window of only 10 HOURS. The
   // whole point of this check is the user's scenario "the trend has run for a LONG time", and
   // a multi-day trend's true origin sits far outside a 10-hour window: in a sustained 3-day
   // selloff, the highest high of the last 10 hours is nearly the current price, so extension
   // computed to ~nothing and no penalty ever fired - the exact case it was built for.
   // Now measured on its own timeframe (H1 x 100 bars ~ 4 days by default), with ATR taken on
   // the SAME timeframe so the ATR-multiple units stay coherent.
   // FIX(extension-unit): the swing scan spans MoveExtensionLookbackBars on MoveExtensionTF
   // (100 H1 bars ~ 4 days by default), but the ATR it was divided by was taken on that same H1
   // timeframe. Measuring a multi-DAY span in HOURLY ATR units inflates the result enormously: on
   // XAUUSD, which routinely travels $70-80 in a single day against an H1 ATR of roughly $3.5,
   // ONE day alone reads as ~21 ATR - so the 7 ATR "climax" threshold was exceeded within hours of
   // any trending session and stayed exceeded for days. That made the block a permanent veto on
   // same-direction entries, i.e. it measured "a trend exists" rather than "the move is exhausted".
   // The ATR is now taken on its own timeframe (daily by default) so the units match the window.
   ENUM_TIMEFRAMES ext_tf = MoveExtensionTF;
   double atr = ATRPointsManual(MoveExtensionATRTF, MoveExtensionATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   int lb = MathMax(5, MoveExtensionLookbackBars);

   // V122: the origin must respect trend CHANGES, not just take the extreme of the window.
   // Taking the plain lowest low over five days means that after a rally, a real correction and a
   // fresh rally, the EA still measures from the ORIGINAL low - so a young move looks like an
   // exhausted multi-day trend and good entries get blocked. Walk forward from the extreme instead:
   // if price made a correction deep enough to count as a reset (MoveExtensionResetPercent of the
   // leg), the move that matters starts at that correction's turning point.
   int    scan = MathMin(lb, 400);
   double origin = 0.0;

   if(direction > 0)
   {
      // Anchor at the lowest low, then look for a correction deep enough to restart the count.
      double leg_low = 0.0;
      int    leg_low_shift = -1;
      for(int i = scan; i >= 1; i--)
      {
         double l = CandleLow(ext_tf, i);
         if(l <= 0.0) continue;
         if(leg_low <= 0.0 || l < leg_low) { leg_low = l; leg_low_shift = i; }
      }
      if(leg_low <= 0.0 || mid <= leg_low)
         return 0.0;

      origin = leg_low;

      // From that low forward: track the running peak, and the deepest pullback after it.
      double peak = leg_low, pull_low = 0.0;
      for(int i = leg_low_shift; i >= 1; i--)
      {
         double h = CandleHigh(ext_tf, i);
         double l = CandleLow(ext_tf, i);
         if(h > 0.0 && h > peak)
         {
            peak = h;
            pull_low = 0.0;              // new high - any earlier pullback is history
         }
         if(l > 0.0 && peak > leg_low && (pull_low <= 0.0 || l < pull_low))
            pull_low = l;

         // A pullback retracing this much of the leg means the old move ended and a new one began.
         if(pull_low > 0.0 && peak > leg_low)
         {
            double leg   = peak - leg_low;
            double depth = peak - pull_low;
            if(leg > 0.0 && (depth / leg) >= MathMax(0.1, MoveExtensionResetPercent / 100.0))
               origin = pull_low;        // measure the CURRENT move from here
         }
      }

      if(mid <= origin)
         return 0.0;
      return ((mid - origin) / _Point) / atr;
   }

   // Mirror for a SELL: anchor at the highest high, restart after a deep enough bounce.
   double leg_high = 0.0;
   int    leg_high_shift = -1;
   for(int i = scan; i >= 1; i--)
   {
      double h = CandleHigh(ext_tf, i);
      if(h <= 0.0) continue;
      if(leg_high <= 0.0 || h > leg_high) { leg_high = h; leg_high_shift = i; }
   }
   if(leg_high <= 0.0 || mid >= leg_high)
      return 0.0;

   origin = leg_high;

   double trough = leg_high, bounce_high = 0.0;
   for(int i = leg_high_shift; i >= 1; i--)
   {
      double l = CandleLow(ext_tf, i);
      double h = CandleHigh(ext_tf, i);
      if(l > 0.0 && l < trough)
      {
         trough = l;
         bounce_high = 0.0;
      }
      if(h > 0.0 && trough < leg_high && (bounce_high <= 0.0 || h > bounce_high))
         bounce_high = h;

      if(bounce_high > 0.0 && trough < leg_high)
      {
         double leg   = leg_high - trough;
         double depth = bounce_high - trough;
         if(leg > 0.0 && (depth / leg) >= MathMax(0.1, MoveExtensionResetPercent / 100.0))
            origin = bounce_high;
      }
   }

   if(mid >= origin)
      return 0.0;
   return ((origin - mid) / _Point) / atr;
}

double MoveExtensionATR(const int direction)
{
   static int    mex_cache_bar = -1;
   static int    mex_cache_dir = 0;
   static double mex_cache_val = 0.0;
   if(mex_cache_bar > G_BARS_SEEN) mex_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(mex_cache_bar != G_BARS_SEEN || mex_cache_dir != direction)
   {
      mex_cache_val = MoveExtensionATRRaw(direction);
      mex_cache_bar = G_BARS_SEEN;
      mex_cache_dir = direction;
   }

   return mex_cache_val;
}

double ImpulseConfirmationRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableImpulseConfirmation || direction == 0)
      return 0.5;

   double atr = ATRPointsManual(ImpulseTF, ImpulsePeriod, 1);
   if(atr <= 0.0)
      return 0.5;

   int lookback = MathMax(1, ImpulseLookbackBars);
   double best_ratio = 0.0;
   int best_dir = 0;
   double best_level = 0.0;

   for(int i = 1; i <= lookback; i++)
   {
      double h = CandleHigh(ImpulseTF, i);
      double l = CandleLow(ImpulseTF, i);
      double o = CandleOpen(ImpulseTF, i);
      double c = CandleClose(ImpulseTF, i);
      double range = h - l;

      if(h <= 0.0 || l <= 0.0 || range <= 0.0)
         continue;

      double body = MathAbs(c - o);
      double body_ratio = body / range;
      double range_vs_atr = (range / _Point) / atr;

      if(range_vs_atr > best_ratio && body_ratio >= ImpulseMinBodyRatio)
      {
         best_ratio = range_vs_atr;
         best_dir = (c > o) ? 1 : -1;
         best_level = range_vs_atr;
      }
   }

   if(best_ratio < ImpulseMinATRMultiple || best_dir == 0)
      return 0.5;   // no qualifying impulse found either way

   if(best_dir == direction)
   {
      double base_score = MathMin(1.0, 0.6 + (best_ratio - ImpulseMinATRMultiple) * 0.15);

      // V31.6z53 fix: the line above rewards impulse SIZE with no regard for WHERE in the move
      // it happened - so the single most dangerous candle in trading (a blow-off climax at the
      // very top of an extended rally) earned the single highest BUY confidence. Scale by how
      // far the move has already run: a big candle right off the lows is a genuine breakout
      // worth joining; the same candle 6 ATR into the rally is where late buyers get trapped.
      if(EnableMoveExtension)
      {
         double ext = MoveExtensionATR(direction);

         if(ext >= MoveExtensionClimaxATR)
         {
            // Fully extended AND a large impulse candle = textbook exhaustion/climax. This is
            // not confirmation to join - it's a warning, so the score inverts below neutral.
            detail = StringFormat("impulse-CLIMAX(%.1fx ATR candle at %.1f ATR extension) ", best_level, ext);
            return MoveExtensionClimaxScore;
         }

         if(ext >= MoveExtensionMatureATR)
         {
            // Move is mature but not yet climactic - taper the bonus down toward neutral as
            // extension grows, rather than an abrupt cliff.
            double span = MathMax(0.1, MoveExtensionClimaxATR - MoveExtensionMatureATR);
            double maturity = MathMax(0.0, MathMin(1.0, (ext - MoveExtensionMatureATR) / span));
            double tapered = base_score - maturity * (base_score - 0.5);
            detail = StringFormat("impulse-agrees but mature(%.1fx ATR candle, %.1f ATR extension) ", best_level, ext);
            return tapered;
         }

         detail = StringFormat("impulse-agrees FRESH(%.1fx ATR candle, %.1f ATR extension) ", best_level, ext);
         return base_score;
      }

      detail = StringFormat("impulse-agrees(%.1fx ATR) ", best_level);
      return base_score;
   }

   detail = StringFormat("impulse-AGAINST(%.1fx ATR) ", best_level);
   return 0.15;
}

// Shared per-bar cache, same pattern as the other multi-factor senses.
double ImpulseConfirmation(const int direction, string &detail)
{
   static int    imp_cache_bar = -1;
   static int    imp_cache_dir = 0;
   static double imp_cache_score = 0.5;
   static string imp_cache_detail = "";
   if(imp_cache_bar > G_BARS_SEEN) imp_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(imp_cache_bar != G_BARS_SEEN || imp_cache_dir != direction)
   {
      imp_cache_score = ImpulseConfirmationRaw(direction, imp_cache_detail);
      imp_cache_bar = G_BARS_SEEN;
      imp_cache_dir = direction;
   }

   detail = imp_cache_detail;
   return imp_cache_score;
}

// V31.6z19 NEW: IMPULSE EXHAUSTION WARNING. Genuine, sharp real-world gap found via live
// testing: Impulse Confirmation above only checks whether a strong candle recently AGREES
// with a direction - it never checks the OPPOSITE, equally important question: is the SAME-
// direction move that's been carrying an open basket now visibly LOSING STEAM (shrinking
// bodies, growing rejection wicks at the extreme)? This is exactly the "rounding top /
// blow-off exhaustion" pattern - grid kept adding BUY right as a sharp rally was topping out,
// with zero awareness the drive itself was fading. Distinct from MultiCandleShrinkingPattern
// (which checks the OPPOSITE side fading, for reversal entries) - this checks OUR OWN side.
double ImpulseExhaustionWarningRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableImpulseExhaustionWarning || direction == 0)
      return 0.5;

   double h1 = CandleHigh(SignalTF, 1), l1 = CandleLow(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1), c1 = CandleClose(SignalTF, 1);
   double h2 = CandleHigh(SignalTF, 2), l2 = CandleLow(SignalTF, 2);
   double o2 = CandleOpen(SignalTF, 2), c2 = CandleClose(SignalTF, 2);

   double range1 = h1 - l1;
   double range2 = h2 - l2;

   if(range1 <= 0.0 || range2 <= 0.0)
      return 0.5;

   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   if(direction > 0)
   {
      // For a BUY: growing upper-wick rejection + a shrinking bullish body vs the prior bar,
      // after recent bars were genuinely pushing up - the rally is topping out right now.
      double upper_wick1 = h1 - MathMax(c1, o1);
      double upper_wick_ratio1 = upper_wick1 / range1;
      bool recent_was_bullish = (c2 > o2);
      bool rejecting = (upper_wick_ratio1 >= ImpulseExhaustionWickRatio);
      bool shrinking = (body2 > 0.0 && body1 < body2 * ImpulseExhaustionShrinkFactor);

      if(recent_was_bullish && rejecting && shrinking)
      {
         detail = StringFormat("impulse exhaustion UP: wick=%.0f%% shrinking-body ", upper_wick_ratio1 * 100.0);
         return 0.15;
      }
   }
   else
   {
      double lower_wick1 = MathMin(c1, o1) - l1;
      double lower_wick_ratio1 = lower_wick1 / range1;
      bool recent_was_bearish = (c2 < o2);
      bool rejecting = (lower_wick_ratio1 >= ImpulseExhaustionWickRatio);
      bool shrinking = (body2 > 0.0 && body1 < body2 * ImpulseExhaustionShrinkFactor);

      if(recent_was_bearish && rejecting && shrinking)
      {
         detail = StringFormat("impulse exhaustion DOWN: wick=%.0f%% shrinking-body ", lower_wick_ratio1 * 100.0);
         return 0.15;
      }
   }

   return 0.5;
}

// Shared per-bar cache, same pattern as the other multi-factor senses.
double ImpulseExhaustionWarning(const int direction, string &detail)
{
   static int    iew_cache_bar = -1;
   static int    iew_cache_dir = 0;
   static double iew_cache_score = 0.5;
   static string iew_cache_detail = "";
   if(iew_cache_bar > G_BARS_SEEN) iew_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(iew_cache_bar != G_BARS_SEEN || iew_cache_dir != direction)
   {
      iew_cache_score = ImpulseExhaustionWarningRaw(direction, iew_cache_detail);
      iew_cache_bar = G_BARS_SEEN;
      iew_cache_dir = direction;
   }

   detail = iew_cache_detail;
   return iew_cache_score;
}

// ============================================================================
// V31.6z22 UPGRADE: EXHAUSTION CONSENSUS. Feedback taken to heart: the 4 deceleration checks
// added in the last round (ADX slope, RSI cooling, DXY deceleration, basket DD acceleration)
// were each bolted on as small, ISOLATED, linear additions - genuinely too simple given how
// AUTO Hunter Suitability proved a unified, non-linear consensus catches far more than
// scattered individual checks. This combines FIVE independent deceleration signals - ADX
// slope, RSI cooling, candle-level Impulse Exhaustion, DXY deceleration, and basket DD
// acceleration - into ONE score, with the SAME "genuine multi-signal agreement compounds,
// doesn't just add" philosophy already proven in Grid Intelligence and AUTO Hunter.
// ============================================================================
int DXYProxyDirection(string &reason);
double DXYDecelerationFactor();

double ExhaustionConsensusScoreRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableExhaustionConsensus || direction == 0)
      return 0.5;

   int warning_count = 0;
   string warnings = "";

   // 1. ADX deceleration, only counted if ADX is actually confirming OUR direction right now.
   if(EnableADXDeceleration)
   {
      double adx_val = SirusADX(TrendQualityTF, TrendStrengthPeriod, 0, 1);
      double plus_di = SirusADX(TrendQualityTF, TrendStrengthPeriod, 1, 1);
      double minus_di = SirusADX(TrendQualityTF, TrendStrengthPeriod, 2, 1);
      int adx_dir = (plus_di > minus_di) ? 1 : ((minus_di > plus_di) ? -1 : 0);
      if(adx_dir == direction && adx_val > 0.0)
      {
         double decel = ADXDecelerationFactor(TrendQualityTF, TrendStrengthPeriod, ADXDecelerationLookbackBars);
         if(decel >= ExhaustionConsensusMinFactor)
         {
            warning_count++;
            warnings += "ADX ";
         }
      }
   }

   // 2. RSI still extreme but cooling/warming.
   if(EnableRSICooling)
   {
      string rsi_detail = "";
      double rsi_cool = RSICoolingFactor(direction, TrendQualityTF, TrendReversalRSIPeriod, ADXDecelerationLookbackBars, rsi_detail);
      if(rsi_cool >= ExhaustionConsensusMinFactor)
      {
         warning_count++;
         warnings += "RSI ";
      }
   }

   // 3. Immediate candle-level exhaustion (growing rejection wick + shrinking body).
   if(EnableImpulseExhaustionWarning)
   {
      string iew_detail = "";
      double iew = ImpulseExhaustionWarning(direction, iew_detail);
      if(iew <= 0.3)
      {
         warning_count++;
         warnings += "Impulse ";
      }
   }

   // 4. DXY deceleration, only counted if DXY is actually confirming OUR direction right now.
   if(EnableDXYDeceleration && EnableDXYProxy)
   {
      string dxy_reason = "";
      int dxy_dir = DXYProxyDirection(dxy_reason);
      int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;
      if(price_effect == direction)
      {
         double dxy_decel = DXYDecelerationFactor();
         if(dxy_decel >= ExhaustionConsensusMinFactor)
         {
            warning_count++;
            warnings += "DXY ";
         }
      }
   }

   // 5. Basket DD accelerating, only relevant if there's an active basket riding THIS direction.
   if(EnableBasketDDAcceleration && G_BASKET_ORDERS > 0)
   {
      int basket_dir_i = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : ((G_BASKET_DIRECTION == POSITION_TYPE_SELL) ? -1 : 0);
      if(basket_dir_i == direction)
      {
         string dd_detail = "";
         double dd_accel = BasketDDAccelerationFactor(dd_detail);
         if(dd_accel >= ExhaustionConsensusMinFactor)
         {
            warning_count++;
            warnings += "DD-Accel ";
         }
      }
   }

   // Factor 6: NEW - folds in Deep Shock Exhaustion (wick-rejection risk during an actual
   // detected volatility shock, from the separate News Volatility Brain) instead of leaving it
   // as an isolated, uncoordinated signal. Only counted if the shock itself was IN this
   // direction (a shock against us is a different, already-covered concern elsewhere).
   if(EnableDeepShockExhaustionInConsensus && G_DNV_SHOCK_ACTIVE && G_DNV_SHOCK_DIR == direction && G_DNV_EXHAUST_RISK)
   {
      warning_count++;
      warnings += "ShockExhaust ";
   }

   if(warning_count == 0)
      return 0.5;

   detail = StringFormat("EXHAUSTION-CONSENSUS(%d/6): %s", warning_count, warnings);

   // Non-linear: genuine agreement across independent signals compounds, matching the
   // established Grid Intelligence / AUTO Hunter philosophy rather than a flat per-warning sum.
   if(warning_count == 1)
      return 0.35;
   if(warning_count == 2)
      return 0.20;
   return MathMax(0.05, 0.20 - (warning_count - 2) * ExhaustionConsensusExtraPenaltyStep);
}

// Shared per-bar cache, same pattern as every other multi-factor sense today.
double ExhaustionConsensusScore(const int direction, string &detail)
{
   static int    ecs_cache_bar = -1;
   static int    ecs_cache_dir = 0;
   static double ecs_cache_score = 0.5;
   static string ecs_cache_detail = "";
   if(ecs_cache_bar > G_BARS_SEEN) ecs_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ecs_cache_bar != G_BARS_SEEN || ecs_cache_dir != direction)
   {
      ecs_cache_score = ExhaustionConsensusScoreRaw(direction, ecs_cache_detail);
      ecs_cache_bar = G_BARS_SEEN;
      ecs_cache_dir = direction;
   }

   detail = ecs_cache_detail;
   return ecs_cache_score;
}

// V29 upgrade: was a manual loop scanning every candle; now uses MT5's native iHighest/iLowest
// (same result, faster - especially now that Zone Map/Confluence call these across 6 timeframes).
double HighestHigh(const ENUM_TIMEFRAMES tf, const int lookback, const int start_shift)
{
   if(lookback <= 0)
      return 0.0;

   int idx = iHighest(_Symbol, tf, MODE_HIGH, lookback, start_shift);
   if(idx < 0)
      return 0.0;

   return CandleHigh(tf, idx);
}

double LowestLow(const ENUM_TIMEFRAMES tf, const int lookback, const int start_shift)
{
   if(lookback <= 0)
      return 0.0;

   int idx = iLowest(_Symbol, tf, MODE_LOW, lookback, start_shift);
   if(idx < 0)
      return 0.0;

   return CandleLow(tf, idx);
}

// V29 upgrade: was a manual simple-average-of-True-Range loop (choppy, drops old bars abruptly).
// Now uses MT5's native iATR (proper Wilder smoothing - the real, standard ATR) via a small
// handle cache, since MQL5 requires one handle per unique (symbol, timeframe, period) combo.
#define SIRUS_ATR_CACHE_SIZE 12
int G_ATR_CACHE_TF[SIRUS_ATR_CACHE_SIZE];
int G_ATR_CACHE_PERIOD[SIRUS_ATR_CACHE_SIZE];
int G_ATR_CACHE_HANDLE[SIRUS_ATR_CACHE_SIZE];
int G_ATR_CACHE_COUNT = 0;

// V30 fix: round-robin eviction when the cache is full (old code created a brand-new
// handle on EVERY call once full and never released it -> indicator handle leak).
int G_ATR_CACHE_EVICT_NEXT = 0;

int SirusGetATRHandle(const ENUM_TIMEFRAMES tf, const int period)
{
   for(int i = 0; i < G_ATR_CACHE_COUNT; i++)
   {
      if(G_ATR_CACHE_TF[i] == (int)tf && G_ATR_CACHE_PERIOD[i] == period)
         return G_ATR_CACHE_HANDLE[i];
   }

   int h = iATR(_Symbol, tf, period);
   if(h == INVALID_HANDLE)
      return INVALID_HANDLE;

   if(G_ATR_CACHE_COUNT < SIRUS_ATR_CACHE_SIZE)
   {
      G_ATR_CACHE_TF[G_ATR_CACHE_COUNT] = (int)tf;
      G_ATR_CACHE_PERIOD[G_ATR_CACHE_COUNT] = period;
      G_ATR_CACHE_HANDLE[G_ATR_CACHE_COUNT] = h;
      G_ATR_CACHE_COUNT++;
   }
   else
   {
      // Cache full: release the evicted slot's handle, then reuse the slot.
      int slot = G_ATR_CACHE_EVICT_NEXT;
      if(G_ATR_CACHE_HANDLE[slot] != INVALID_HANDLE)
         IndicatorRelease(G_ATR_CACHE_HANDLE[slot]);

      G_ATR_CACHE_TF[slot] = (int)tf;
      G_ATR_CACHE_PERIOD[slot] = period;
      G_ATR_CACHE_HANDLE[slot] = h;
      G_ATR_CACHE_EVICT_NEXT = (slot + 1) % SIRUS_ATR_CACHE_SIZE;
   }
   return h;
}

// V30 new: release all cached ATR handles (called from OnDeinit).
void SirusReleaseATRHandles()
{
   for(int i = 0; i < G_ATR_CACHE_COUNT; i++)
   {
      if(G_ATR_CACHE_HANDLE[i] != INVALID_HANDLE)
      {
         IndicatorRelease(G_ATR_CACHE_HANDLE[i]);
         G_ATR_CACHE_HANDLE[i] = INVALID_HANDLE;
      }
   }
   G_ATR_CACHE_COUNT = 0;
   G_ATR_CACHE_EVICT_NEXT = 0;
}

double ATRPointsManual(const ENUM_TIMEFRAMES tf, const int period, const int start_shift)
{
   if(period <= 0 || _Point <= 0.0)
      return 0.0;

   int handle = SirusGetATRHandle(tf, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, start_shift, 1, buf) != 1)
      return 0.0;

   if(buf[0] <= 0.0)
      return 0.0;

   return buf[0] / _Point;
}

//==================================================================//
//  PHASE 21.3 MODE MANAGER
//==================================================================//
ENUM_SIRUS_MODE ResolveDefaultAutoMode()
{
   if(IsValidTradingMode(DefaultAutoMode))
      return DefaultAutoMode;
   return SIRUS_MODE_BALANCED;
}

double VolatilityRegimeScore();
double HourBayesWinRate(const int h);
double TrendQualityScore(const int direction, string &detail);

// V31.6z14 UPGRADE: was two simple sequential gates (chaos check, volatility check) - genuine
// feedback that this was too simplistic given everything else built today. Now a proper
// weighted, multi-factor suitability score, same philosophy as Grid Intelligence: FIVE
// independent dimensions combined rather than binary pass/fail on just two.
double AutoHunterSuitabilityScore(string &reason)
{
   double score = 1.0;
   int concern_count = 0;
   string concerns = "";

   // Factor 1: outright market chaos.
   bool concern_chaos = (G_MARKET_STATE == MARKET_CHAOS);
   if(concern_chaos)
   {
      score -= 0.35;
      concern_count++;
      concerns += "chaos ";
   }

   // Factor 2: extreme volatility storm.
   double vr = VolatilityRegimeScore();
   bool concern_vol = (vr <= AutoHunterMinVolatilityRegime);
   if(concern_vol)
   {
      score -= 0.25;
      concern_count++;
      concerns += StringFormat("volStorm(%.2f) ", vr);
   }

   // Factor 3: active high-impact news window.
   bool concern_news = (EnableAutoHunterNewsFilter && G_CAL_ACTIVE);
   if(concern_news)
   {
      score -= 0.2;
      concern_count++;
      concerns += "news-active ";
   }

   // Factor 4: this hour's own historical track record.
   bool concern_hour = false;
   int hour_now = -1;
   double hour_wr = 0.5;
   if(EnableAutoHunterHourFilter)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      hour_now = dt.hour;
      hour_wr = HourBayesWinRate(hour_now);
      concern_hour = (hour_wr < AutoHunterMinHourWinRate);
      if(concern_hour)
      {
         score -= 0.15;
         concern_count++;
         concerns += StringFormat("hour%02d-winrate=%.0f%% ", hour_now, hour_wr * 100.0);
      }
   }

   // Factor 5: trend clarity - checks BOTH directions; if NEITHER shows a genuinely healthy
   // trend, the market is murky/directionless both ways.
   bool concern_murky = false;
   if(EnableAutoHunterTrendClarityFilter)
   {
      string tq_up_detail = "", tq_down_detail = "";
      double tq_up = TrendQualityScore(1, tq_up_detail);
      double tq_down = TrendQualityScore(-1, tq_down_detail);
      double best_clarity = MathMax(tq_up, tq_down);
      concern_murky = (best_clarity < AutoHunterMinTrendClarity);
      if(concern_murky)
      {
         score -= 0.15;
         concern_count++;
         concerns += StringFormat("murky(best=%.2f) ", best_clarity);
      }
   }

   // Factor 6: NEW - existing basket health. If a basket is ALREADY open and already in
   // meaningful drawdown, switching to the MORE aggressive mode (looser entry bar, more
   // orders) is backwards - the account is already under pressure, not a time to loosen up.
   bool concern_basket = false;
   if(EnableAutoHunterBasketHealthFilter && G_BASKET_ORDERS > 0 && G_BASKET_DD_PERCENT >= AutoHunterMaxBasketDDForHunter)
   {
      score -= 0.3;
      concern_count++;
      concern_basket = true;
      concerns += StringFormat("basketDD=%.1f%%/%.1f%% ", G_BASKET_DD_PERCENT, AutoHunterMaxBasketDDForHunter);
   }

   // NON-LINEAR consensus, same philosophy as Grid Intelligence: genuine agreement across
   // several INDEPENDENT concerns firing at once is stronger evidence than their raw sum
   // implies - this is exactly what a human "does this feel like a good time to be
   // aggressive" judgment would weigh more heavily than a simple additive checklist.
   if(concern_count >= 3)
   {
      double consensus_penalty = AutoHunterConsensusPenaltyStep * (concern_count - 2);
      score -= consensus_penalty;
      concerns += StringFormat("MULTI-CONCERN(%d) ", concern_count);
   }

   reason = (concern_count == 0) ? "all clear" : concerns;
   return MathMax(0.0, score);
}

bool AutoHunterMarketConditionOK(string &reason)
{
   if(!EnableAutoHunterMarketFilter)
   {
      reason = "market filter disabled";
      return true;
   }

   string concern_text = "";
   double suitability = AutoHunterSuitabilityScore(concern_text);
   bool ok = (suitability >= AutoHunterMinSuitabilityScore);

   reason = StringFormat("suitability=%.2f/%.2f (%s)", suitability, AutoHunterMinSuitabilityScore, concern_text);
   return ok;
}

ENUM_SIRUS_MODE EvaluateAutoModeCandidate(string &reason)
{
   ENUM_SIRUS_MODE safe_default = ResolveDefaultAutoMode();

   if(!G_ENV_READY)
   {
      reason = "ENV not ready -> BALANCED";
      return SIRUS_MODE_BALANCED;
   }

   int tick_age = TickAgeSeconds();

   if(!AllowAutoHighHunter)
   {
      reason = "AllowAutoHighHunter=false -> " + ModeToString(safe_default);
      return safe_default;
   }

   if(G_LAST_SPREAD_POINTS < 0)
   {
      reason = "spread unreadable -> BALANCED";
      return SIRUS_MODE_BALANCED;
   }

   // FIX(hunter-spread-order): this reject-gate gates on AutoBalancedSpreadLimit alone, then the
   // HIGH_HUNTER check further below tests AutoHighHunterMaxSpread. That only works as intended
   // when the hunter limit is the TIGHTER of the two (its usual, stricter role) - if a user (or a
   // future default change) sets AutoHighHunterMaxSpread LOOSER than AutoBalancedSpreadLimit,
   // spreads between the two limits never even reach the hunter check below - they get rejected
   // to BALANCED here first, silently capping the EA below the hunter threshold it was configured
   // with. Gate here on whichever limit is LOOSER, so a spread the hunter check would still accept
   // gets the chance to be evaluated by it; the hunter-specific check below remains the real gate.
   int auto_mode_spread_ceiling = (int)MathMax(AutoBalancedSpreadLimit, AutoHighHunterMaxSpread);
   if(G_LAST_SPREAD_POINTS > EffSpread(auto_mode_spread_ceiling))
   {
      reason = StringFormat("spread above auto-mode ceiling %d/%d -> BALANCED",
                            G_LAST_SPREAD_POINTS,
                            EffSpread(auto_mode_spread_ceiling));
      return SIRUS_MODE_BALANCED;
   }

   if(tick_age < 0)
   {
      reason = "no tick yet -> BALANCED";
      return SIRUS_MODE_BALANCED;
   }

   if(tick_age > AutoHighHunterMaxTickAge)
   {
      reason = StringFormat("tick age high %ds/%d -> BALANCED",
                            tick_age,
                            AutoHighHunterMaxTickAge);
      return SIRUS_MODE_BALANCED;
   }

   // FIX(hunter-spread-discriminator-dead): this test used EffSpread(AutoHighHunterMaxSpread), and
   // EffSpread() IGNORES its argument entirely while UseUnifiedMaxSpread is on - it returns
   // UnifiedMaxSpreadPoints (500) for everything. So this line and the auto-mode ceiling gate above
   // resolved to the SAME number, spread stopped discriminating between the two profiles, and
   // HIGH_HUNTER - the more aggressive one, with the lower score bar and the tighter grid - was
   // selected on any spread the EA would trade at all. The suitability score was left as the only
   // real gate.
   //   EffSpread() is the right thing for "may we trade at all" - one account-wide ceiling. It is
   // the WRONG thing for "which profile suits conditions right now", which is a comparison BETWEEN
   // two configured thresholds and is meaningless once both collapse to the same value. Mode
   // selection therefore uses the raw hunter limit, so AutoHighHunterMaxSpread means what it says
   // again: hunter only on a genuinely tight spread, balanced for everything wider. This makes AUTO
   // more selective, never looser - the unified ceiling above still caps trading overall.
   int hunter_spread_limit = MathMax(1, AutoHighHunterMaxSpread);
   if(G_LAST_SPREAD_POINTS <= hunter_spread_limit)
   {
      string market_reason = "";
      if(!AutoHunterMarketConditionOK(market_reason))
      {
         reason = StringFormat("spread clean but %s -> BALANCED", market_reason);
         return SIRUS_MODE_BALANCED;
      }

      reason = StringFormat("clean technical state: spread %d/%d + tick age %ds/%d + %s -> HIGH_HUNTER",
                            G_LAST_SPREAD_POINTS,
                            hunter_spread_limit,
                            tick_age,
                            AutoHighHunterMaxTickAge,
                            market_reason);
      return SIRUS_MODE_HIGH_HUNTER;
   }

   reason = StringFormat("spread not clean enough for hunter %d/%d -> BALANCED",
                         G_LAST_SPREAD_POINTS,
                         hunter_spread_limit);
   return SIRUS_MODE_BALANCED;
}

void UpdateModeManager(const string source)
{
   if(ModeEvaluateOnNewBarOnly && G_MODE_EVAL_BAR == G_BARS_SEEN)
      return;

   G_MODE_EVAL_BAR = G_BARS_SEEN;

   ENUM_SIRUS_MODE wanted = SIRUS_MODE_BALANCED;
   string reason = "";

   if(IsForcedMode())
   {
      wanted = SirusMode;
      reason = "manual fixed mode";
   }
   else
   {
      wanted = EvaluateAutoModeCandidate(reason);
   }

   if(!IsValidTradingMode(wanted))
   {
      wanted = SIRUS_MODE_BALANCED;
      reason = "invalid candidate -> BALANCED";
   }

   G_MODE_CANDIDATE = wanted;

   int bars_since_switch = G_BARS_SEEN - G_MODE_LAST_SWITCH_BAR;
   bool cooldown_ready = (ModeSwitchCooldownBars <= 0 || bars_since_switch >= ModeSwitchCooldownBars);

   // First initialization should not wait for cooldown
   if(G_MODE_LAST_SWITCH_TIME <= 0)
      cooldown_ready = true;

   if(wanted != G_ACTIVE_MODE)
   {
      if(cooldown_ready || IsForcedMode())
      {
         G_PREVIOUS_MODE = G_ACTIVE_MODE;
         G_ACTIVE_MODE = wanted;
         G_MODE_LAST_SWITCH_BAR = G_BARS_SEEN;
         G_MODE_LAST_SWITCH_TIME = TimeCurrent();
         G_MODE_REASON = reason;
      }
      else
      {
         G_MODE_REASON = StringFormat("candidate=%s but cooldown %d/%d bars | %s",
                                      ModeToString(wanted),
                                      bars_since_switch,
                                      ModeSwitchCooldownBars,
                                      reason);
      }
   }
   else
   {
      G_MODE_REASON = reason;
   }

   G_MODE_STATUS = StringFormat("MODE: %s -> %s | candidate=%s | reason=%s",
                                ModeToString(SirusMode),
                                ModeToString(G_ACTIVE_MODE),
                                ModeToString(G_MODE_CANDIDATE),
                                G_MODE_REASON);

   string signature = G_MODE_STATUS + "|" + IntegerToString(G_BARS_SEEN) + "|" + IntegerToString(G_LAST_SPREAD_POINTS);

   if(PrintModeOnChange && signature != G_MODE_LAST_SIGNATURE)
   {
      bool important = (wanted != G_ACTIVE_MODE || G_ACTIVE_MODE != G_PREVIOUS_MODE || G_BARS_SEEN == G_MODE_LAST_SWITCH_BAR);
      if(important || G_MODE_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 MODE] %s | bars_seen=%d | source=%s",
                     G_MODE_STATUS,
                     G_BARS_SEEN,
                     source);
      }
      G_MODE_LAST_SIGNATURE = signature;
   }

   if(G_ENV_READY)
      SetStatus("CORE + ENV + MODE READY: first entry only in Phase 21.3", "ModeManager");
}


//==================================================================//
//  PHASE 21.3 MARKET STATE ROUTER
//==================================================================//
// V29 upgrade: alpha-beta (steady-state Kalman) filter for HTF trend. Reacts to a genuine
// turn faster than the SMA slope, which has to wait for old bars to roll out of its window.
void UpdateKalmanTrendFilter()
{
   if(!EnableKalmanTrend)
      return;

   datetime bar_time = iTime(_Symbol, HTFTrendTF, 0);
   if(bar_time == G_KALMAN_LAST_BAR_TIME)
      return; // only step the filter once per newly closed HTF bar

   double z = CandleClose(HTFTrendTF, 1);
   if(z <= 0.0)
      return;

   if(G_KALMAN_BAR_COUNT == 0)
   {
      G_KALMAN_LEVEL = z;
      G_KALMAN_TREND = 0.0;
   }
   else
   {
      double predicted_level = G_KALMAN_LEVEL + G_KALMAN_TREND;
      double residual = z - predicted_level;

      G_KALMAN_LEVEL = predicted_level + KalmanAlpha * residual;
      G_KALMAN_TREND = G_KALMAN_TREND + KalmanBeta * residual;

      if((KalmanPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v29 KALMAN] bar=%d level=%.2f trend=%.2fpts/bar residual=%.2f",
                     G_KALMAN_BAR_COUNT, G_KALMAN_LEVEL, G_KALMAN_TREND / _Point, residual);
   }

   G_KALMAN_BAR_COUNT++;
   G_KALMAN_LAST_BAR_TIME = bar_time;
}

bool KalmanTrendReady()
{
   return (EnableKalmanTrend && G_KALMAN_BAR_COUNT >= MathMax(2, KalmanWarmupBars));
}

ENUM_MARKET_STATE DetectTrendState(string &reason)
{
   if(!UseTrendDetection)
   {
      reason = "trend detection disabled";
      return MARKET_UNKNOWN;
   }

   double str_close = CandleClose(StructureTF, 1);
   double str_ma    = SMA(StructureTF, TrendMAPeriod, 1);

   if(str_close <= 0.0 || str_ma <= 0.0)
   {
      reason = "trend data not ready";
      return MARKET_UNKNOWN;
   }

   bool up, down;
   double slope_points;
   double htf_close = CandleClose(HTFTrendTF, 1);

   if(KalmanTrendReady())
   {
      slope_points = G_KALMAN_TREND / _Point;

      up   = (slope_points > KalmanTrendMinPoints && str_close > str_ma);
      down = (slope_points < -KalmanTrendMinPoints && str_close < str_ma);

      reason = StringFormat("KALMAN HTF=%s close=%.2f level=%.2f trend=%.1fpts/bar | STR=%s close=%.2f ma=%.2f",
                            TFToString(HTFTrendTF),
                            htf_close,
                            G_KALMAN_LEVEL,
                            slope_points,
                            TFToString(StructureTF),
                            str_close,
                            str_ma);
   }
   else
   {
      // Fallback: original SMA-slope method (used until Kalman warms up, or if disabled).
      double htf_ma     = SMA(HTFTrendTF, TrendMAPeriod, 1);
      double htf_ma_old = SMA(HTFTrendTF, TrendMAPeriod, 1 + TrendSlopeLookback);

      if(htf_close <= 0.0 || htf_ma <= 0.0 || htf_ma_old <= 0.0)
      {
         reason = "trend data not ready";
         return MARKET_UNKNOWN;
      }

      slope_points = (htf_ma - htf_ma_old) / _Point;

      up   = (htf_close > htf_ma && str_close > str_ma && slope_points > 0.0);
      down = (htf_close < htf_ma && str_close < str_ma && slope_points < 0.0);

      reason = StringFormat("SMA HTF=%s close=%.2f ma%d=%.2f slope=%.0f | STR=%s close=%.2f ma=%.2f",
                            TFToString(HTFTrendTF),
                            htf_close,
                            TrendMAPeriod,
                            htf_ma,
                            slope_points,
                            TFToString(StructureTF),
                            str_close,
                            str_ma);
   }

   if(up)
      return MARKET_TREND_UP;

   if(down)
      return MARKET_TREND_DOWN;

   return MARKET_UNKNOWN;
}

bool DetectRangeState(string &reason)
{
   if(!UseRangeDetection)
   {
      reason = "range detection disabled";
      return false;
   }

   int lookback = RangeLookbackBars;
   if(lookback < 5)
      lookback = 5;

   double high = HighestHigh(FastContextTF, lookback, 1);
   double low  = LowestLow(FastContextTF, lookback, 1);
   if(high <= 0.0 || low <= 0.0 || high <= low)
   {
      reason = "range data not ready";
      return false;
   }

   G_MARKET_RANGE_POINTS = (high - low) / _Point;

   int max_range = (G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER ? RangeMaxPointsHunter : RangeMaxPointsBalanced);

   // FEATURE(range-breakout): remember the range boundaries whenever a range is confirmed, so the
   // breakout detector can tell when price later escapes them. Only stored on a real range so a
   // stale wide-market high/low can't masquerade as a range edge.
   bool is_range_now = (G_MARKET_RANGE_POINTS <= max_range);
   if(is_range_now)
   {
      G_RANGE_HIGH = high;
      G_RANGE_LOW  = low;
      G_RANGE_VALID_BAR = G_BARS_SEEN;
   }

   reason = StringFormat("%s range %.0f/%d points over %d bars",
                         TFToString(FastContextTF),
                         G_MARKET_RANGE_POINTS,
                         max_range,
                         lookback);

   return is_range_now;
}

// FEATURE(range-breakout): returns +1 if price has broken out ABOVE the range top, -1 if it has
// broken DOWN below the range bottom, 0 if still inside. A breakout requires the last closed bar to
// CLOSE beyond the boundary by RangeBreakoutBufferPoints AND be a strong-bodied candle (body >=
// RangeBreakoutMinBodyFraction of range) - a conviction close, not a wick poke, so fakeouts at the
// edge don't trigger it. Uses the stored G_RANGE_HIGH/LOW from the last confirmed range.
int RangeBreakoutDirection(string &reason)
{
   reason = "no range breakout";
   if(!EnableRangeBreakout || G_RANGE_HIGH <= 0.0 || G_RANGE_LOW <= 0.0 || G_RANGE_HIGH <= G_RANGE_LOW)
      return 0;

   // FIX(stale-range): G_RANGE_HIGH/LOW are only rewritten while a range is actually confirmed, so
   // once the market leaves the range they keep their last values indefinitely. Without an expiry
   // the detector would keep declaring a "breakout" of a range that ended days ago - permanently
   // hard-blocking one direction. Boundaries are only trusted for a limited number of bars after
   // the last confirmation; after that there is no current range to break out of.
   if(RangeBreakoutMaxAgeBars > 0 &&
      (G_RANGE_VALID_BAR < 0 || (G_BARS_SEEN - G_RANGE_VALID_BAR) > RangeBreakoutMaxAgeBars))
   {
      reason = "range boundaries stale - no active range";
      return 0;
   }

   // FIX(breakout-tf): confirm on the SAME timeframe the range was measured on. Reading a single
   // M1 candle against an M5-derived range let ordinary M1 noise register as a breakout, which
   // then hard-blocked the range-edge entries that the range state had just enabled.
   ENUM_TIMEFRAMES rb_tf = RangeBreakoutConfirmTF;
   double c1 = CandleClose(rb_tf, 1);
   double range1 = CandleRangePoints(rb_tf, 1);
   double body1  = CandleBodyPoints(rb_tf, 1);
   if(c1 <= 0.0 || range1 <= 0.0)
      return 0;

   double body_frac = body1 / range1;
   bool strong_body = (body_frac >= RangeBreakoutMinBodyFraction);
   double buf = MathMax(1, RangeBreakoutBufferPoints) * _Point;

   if(c1 > G_RANGE_HIGH + buf && strong_body)
   {
      reason = StringFormat("range breakout UP close=%.2f top=%.2f body=%.0f%%", c1, G_RANGE_HIGH, body_frac * 100.0);
      return 1;
   }
   if(c1 < G_RANGE_LOW - buf && strong_body)
   {
      reason = StringFormat("range breakdown DOWN close=%.2f bottom=%.2f body=%.0f%%", c1, G_RANGE_LOW, body_frac * 100.0);
      return -1;
   }
   return 0;
}

// FEATURE(spike-impulse): return +1/-1 if the most recent bar on M1 or M5 is a violent single-
// candle burst (range >= SpikeImpulseATRMultiple x its own ATR, and at least SpikeImpulseMinPoints
// in absolute size), else 0. Direction is the candle's own close-vs-open. Checks the faster TF
// first so an M1 flash is caught even when the M5 bar is only mid-formation.
int SpikeImpulseDir()
{
   if(!EnableSpikeImpulse || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tfs[2];
   tfs[0] = PERIOD_M1;
   tfs[1] = PERIOD_M5;

   for(int i = 0; i < 2; i++)
   {
      ENUM_TIMEFRAMES tf = tfs[i];
      double atr = ATRPointsManual(tf, ATRPeriod, 1);
      double range_pts = CandleRangePoints(tf, 1);
      if(atr <= 0.0 || range_pts <= 0.0)
         continue;

      bool big_vs_atr = (range_pts >= atr * SpikeImpulseATRMultiple);
      bool big_abs     = (range_pts >= (double)SpikeImpulseMinPoints);
      if(!big_vs_atr || !big_abs)
         continue;

      double o = CandleOpen(tf, 1);
      double c = CandleClose(tf, 1);
      if(o <= 0.0 || c <= 0.0 || c == o)
         continue;

      return (c > o) ? 1 : -1;
   }

   return 0;
}

// FEATURE(sustained-impulse): return +1 / -1 if the recent window is a slow-but-pullback-free move
// (high directional efficiency), else 0. Efficiency = |net move| / total path travelled. A near-
// straight decline over hours scores high even though each bar is small; choppy tape scores low.
int SustainedImpulseDir()
{
   if(!EnableSustainedImpulse)
      return 0;

   ENUM_TIMEFRAMES tf = SustainedImpulseTF;
   int lb = MathMax(3, SustainedImpulseLookbackBars);
   if(_Point <= 0.0)
      return 0;

   double c_now  = CandleClose(tf, 1);
   double c_start = CandleClose(tf, lb);
   if(c_now <= 0.0 || c_start <= 0.0)
      return 0;

   double net = c_now - c_start;
   double net_pts = MathAbs(net) / _Point;
   if(net_pts < (double)SustainedImpulseMinNetPoints)
      return 0;   // move too small to matter

   // Total path = sum of each bar's absolute close-to-close step over the window.
   double path = 0.0;
   for(int b = 1; b < lb; b++)
   {
      double cn = CandleClose(tf, b);
      double cp = CandleClose(tf, b + 1);
      if(cn <= 0.0 || cp <= 0.0)
         continue;
      path += MathAbs(cn - cp);
   }
   if(path <= 0.0)
      return 0;

   double efficiency = MathAbs(net) / path;   // 1.0 = perfectly straight, low = choppy
   if(efficiency < SustainedImpulseMinEfficiency)
      return 0;

   return (net > 0.0) ? 1 : -1;
}

// ============================================================================
// V207: CANDLE READING - one place, and the sequence rather than the candle.
// ----------------------------------------------------------------------------
// The EA measures candles in twelve different places: wick ratios for pin bars,
// body ratios for impulses, close positions for pressure, separate thresholds for
// traps, sweeps, exhaustion and breakouts. Each is correct for its own module and
// none of them talk to each other, so the same bar can be read as a rejection by
// one check and a continuation by another.
//
// More importantly, they all read ONE bar. A trader does not - a bar means something
// different depending on what came before it. An expanding range after three
// contracting ones is a breakout; the same bar after three expanding ones is
// exhaustion. An inside bar is a pause, and a pause after a strong move is a
// different thing from a pause in a range.
//
// This reads the last few bars as a sequence and produces one verdict, so the rest
// of the EA can ask a single question instead of assembling the answer from twelve
// unrelated measurements.
// ============================================================================
// V229: THE SINGLE STRONG CANDLE
// ----------------------------------------------------------------------------
// Eight modules guard against entering into an impulse and not one of them fires on
// a single bar. Consecutive pressure needs three candles. Recent thrust needs three
// dollars over fifteen bars. Spike detection needs eight. Move extension needs the
// move to already be stretched in ATR terms. Every threshold is built around a
// SEQUENCE, because that is what an impulse usually looks like.
//
// But the case that keeps costing money is one candle: a bar closes strong, a
// counter-setup appears immediately after it, and the EA takes the other side while
// whoever produced that bar is still in the market. A dollar-twenty bar with a
// seventy-five percent body is not a trend by any of these measures, and it does not
// need to be - it is enough size and enough conviction to run another dollar before
// it pauses.
//
// So this measures one bar against what one bar normally does here. Not against a
// fixed distance, which varies by session and by day, but against the recent average:
// a bar three times the size of its neighbours is significant whether that is thirty
// cents or three dollars.
//
// The response is a wait rather than a refusal. A strong bar is a timing objection -
// the direction may be right and the moment is not, and the moment passes within a
// few bars when the bar that follows fails to continue.
// ============================================================================

// How dominant was the most recent closed candle, relative to what is normal here?
//   dir      - the direction it pushed
//   returns  0..1 - how far beyond normal it was
double SingleCandleDominance(int &dir, string &detail)
{
   dir = 0;
   detail = "";

   if(!EnableSingleCandleGuard || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = SingleCandleTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0.0;

   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   double body_pts = MathAbs(c - o) / _Point;
   double body_share = MathAbs(c - o) / range;
   int    bar_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);
   if(bar_dir == 0)
      return 0.0;

   // A wide bar that closed in the middle is a fight, not a push - the body is what
   // says one side finished in control.
   if(body_share < SingleCandleMinBody)
      return 0.0;

   // Compare against the recent average rather than a fixed figure. What counts as a
   // large bar on gold at 03:00 and at 14:30 are different numbers, and a threshold
   // in points is wrong for one of them whichever value it takes.
   double sum = 0.0;
   int n = 0;
   for(int i = 2; i <= 1 + MathMax(5, SingleCandleLookback); i++)
   {
      double bh = CandleHigh(tf, i), bl = CandleLow(tf, i);
      if(bh <= 0.0 || bl <= 0.0 || bh <= bl)
         continue;
      sum += (bh - bl) / _Point;
      n++;
   }
   if(n < 4)
      return 0.0;

   double avg = sum / (double)n;
   if(avg <= 0.0)
      return 0.0;

   double ratio = (range / _Point) / avg;
   if(ratio < SingleCandleMinRatio)
      return 0.0;

   // And it has to have covered ground worth respecting in absolute terms too - three
   // times the size of four tiny bars is still a tiny bar.
   if(body_pts < (double)SingleCandleMinBodyPoints)
      return 0.0;

   // Where in its own range did it close? A bar that closed on its high was still
   // being bought at the bell; one that closed mid-range was already being faded.
   double close_pos = (bar_dir > 0) ? (c - l) / range : (h - c) / range;

   dir = bar_dir;

   double strength = MathMin(1.0, (ratio - SingleCandleMinRatio) /
                                  MathMax(0.1, SingleCandleFullRatio - SingleCandleMinRatio));
   strength *= (0.5 + 0.5 * body_share) * (0.6 + 0.4 * close_pos);

   // --- V230: where did it happen, and was anybody behind it? -----------------
   // The same bar means opposite things depending on what it started from. A strong
   // bullish bar off a support is buyers taking the level; the identical bar arriving
   // INTO a resistance is the last of the move being spent against it. And a bar on
   // thin volume is a few orders in an empty book - it retraces as easily as it came.
   string ctx = "";

   if(EnableSingleCandleContext && _Point > 0.0)
   {
      // The level the bar is heading toward, not the one behind it.
      double ahead = (bar_dir > 0) ? ZoneMapNearestResistance(c) : ZoneMapNearestSupport(c);
      if(ahead > 0.0)
      {
         double to_level = MathAbs(ahead - c) / _Point;
         double reach = ScaleAdjustedPoints(MathMax(1, SingleCandleLevelReach));
         if(to_level <= reach)
         {
            double lvl_str = ZoneMapStrengthByTouches(ahead);
            if(lvl_str >= SingleCandleLevelMinStrength)
            {
               // Running out of room. The push is real but it has somewhere to stop, which
               // makes it far less likely to continue than the size alone suggests.
               double closeness = 1.0 - (to_level / MathMax(1.0, reach));
               strength *= (1.0 - SingleCandleIntoLevelDamp * closeness);
               ctx += StringFormat(" into %.2f", ahead);
            }
         }
      }

      // And what it came off. A bar that started at a level it respected is the level
      // working, which is the strongest version of this signal.
      double behind = (bar_dir > 0) ? ZoneMapNearestSupport(o) : ZoneMapNearestResistance(o);
      if(behind > 0.0)
      {
         double from_level = MathAbs(o - behind) / _Point;
         if(from_level <= ScaleAdjustedPoints(MathMax(1, SingleCandleLevelReach)) &&
            ZoneMapStrengthByTouches(behind) >= SingleCandleLevelMinStrength)
         {
            strength *= SingleCandleFromLevelBoost;
            ctx += StringFormat(" off %.2f", behind);
         }
      }
   }

   if(EnableCandleParticipation)
   {
      double part = CandleParticipation(1);
      if(part >= CandleParticipationStrong)
      {
         // The market showed up for it.
         strength *= SingleCandleVolumeBoost;
         ctx += StringFormat(" on %.1fx volume", part);
      }
      else if(part <= CandleParticipationThin)
      {
         // A wide bar nobody participated in is stops being taken, not demand arriving.
         strength *= SingleCandleThinVolumeDamp;
         ctx += StringFormat(" on thin %.1fx volume", part);
      }
   }

   strength = MathMax(0.0, MathMin(1.0, strength));

   detail = StringFormat("%s candle %.1fx normal (%.0f pts body, closed %.0f%% up its range)%s",
                         (bar_dir > 0 ? "bullish" : "bearish"), ratio, body_pts,
                         close_pos * 100.0, ctx);
   return strength;
}

// Has the bar after a dominant one failed to continue? That is what ends the wait -
// the push either extends or it does not, and it shows within a bar or two.
bool SingleCandleFaded(const int push_dir)
{
   if(push_dir == 0 || _Point <= 0.0)
      return false;

   ENUM_TIMEFRAMES tf = SingleCandleTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;
   double range = h - l;
   if(range <= 0.0)
      return false;

   // Continuation would mean another bar closing the same way with a real body. Anything
   // else - a close against, a doji, a mostly-wick bar - is the push not extending.
   int bar_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);
   double body_share = MathAbs(c - o) / range;

   if(bar_dir == push_dir && body_share >= SingleCandleMinBody)
      return false;                  // still going

   return true;
}

// ============================================================================
// V228: WHEN THE LADDER SHOULD STOP - depth, age, and the target that moved
// ----------------------------------------------------------------------------
// MaxOrders is 7 and it is 7 in every circumstance. The ladder does not know that
// order five in a quiet range and order five into a news spike are different
// commitments, or that a basket six hours old is fighting a market that has moved on
// from the one it opened in.
//
// Three things the grid never asks:
//
//   IS THERE ROOM FOR THE REST? Seven orders at 1.30x needs a specific amount of
//   equity and a specific distance to work. If the account cannot survive the ladder
//   completing, the ladder should stop before it gets there rather than at the point
//   the stop-loss fires.
//
//   IS THIS STILL THE SAME MARKET? A basket opened in London and still open in Asia
//   was built on conditions that no longer exist. The participants changed, the range
//   changed, and the recovery the ladder was sized for assumed the old ones.
//
//   HAS THE TARGET MOVED AWAY? The situation and structure engines set a target when
//   the basket opened. If price has since travelled past it, or the level it aimed at
//   has broken, the basket is working toward something that is no longer there.
// ============================================================================

// How many orders can this ladder actually complete? Returns MaxOrders, or fewer.
int GridEffectiveMaxOrders(string &reason)
{
   reason = "";
   // V241: the shape decides how many rungs this ladder has - the setting is only the default.
   int base = MathMax(1, LadderOrders());

   if(!EnableGridDepthLimit)
      return base;

   // --- can the account survive the ladder finishing? -----------------------
   // Project the remaining rungs at their intended sizes and ask whether the
   // drawdown that implies is one this account can hold. Stopping short of a rung
   // that cannot be paid for is not caution; it is arithmetic.
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0.0 || balance <= 0.0 || _Point <= 0.0)
      return base;

   int done = MathMax(0, G_BASKET_ORDERS);
   if(done <= 0)
      return base;

   // Value of the remaining rungs, in lots.
   double remaining_lots = 0.0;
   double lot_n = StartLot * MathPow(LotMultiplier, (double)done);
   for(int k = done; k < base; k++)
   {
      remaining_lots += lot_n;
      lot_n *= LotMultiplier;
   }
   if(remaining_lots <= 0.0)
      return base;

   // Each remaining rung sits roughly a grid-distance further against us, so the
   // average adverse excursion for the set is about half the total span.
   double span_pts = (double)(base - done) * MathMax(1.0, AutoGridBaseDistance()) * 0.5;
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_val <= 0.0 || tick_sz <= 0.0)
      return base;

   double per_point = tick_val / (tick_sz / _Point);
   double projected_loss = remaining_lots * span_pts * per_point;
   double budget = balance * (BasketSLPercent / 100.0) * GridDepthBudgetShare;

   if(budget > 0.0 && projected_loss > budget)
   {
      // Work backwards to the deepest rung the budget covers.
      double running = 0.0;
      double lot_k = StartLot * MathPow(LotMultiplier, (double)done);
      int allowed = done;
      for(int k = done; k < base; k++)
      {
         double rung_span = (double)(k - done + 1) * MathMax(1.0, AutoGridBaseDistance()) * 0.5;
         double rung_cost = lot_k * rung_span * per_point;
         if(running + rung_cost > budget)
            break;
         running += rung_cost;
         allowed = k + 1;
         lot_k *= LotMultiplier;
      }
      allowed = MathMax(done, allowed);
      if(allowed < base)
      {
         reason = StringFormat("depth capped at %d - completing %d would risk %.2f against a %.2f budget",
                               allowed, base, projected_loss, budget);
         return allowed;
      }
   }

   return base;
}

// V228b: forward declarations. These live further down the file with the rest of the session
// handling, and the staleness check needs them here - MQL5 resolves a call to a function defined
// later only when it has seen a declaration first.
int SessionContext(int &minutes_to_change, string &detail);
string SessionName(const int sess);

// Has the market this basket was opened in been replaced by a different one?
//   returns 0..1
double BasketStaleness(string &detail)
{
   detail = "";
   if(!EnableBasketStaleness || G_BASKET_ORDERS <= 0)
      return 0.0;

   double stale = 0.0;
   string parts = "";

   // --- age ------------------------------------------------------------------
   int age_bars = (G_BASKET_OPEN_BAR > 0) ? (G_BARS_SEEN - G_BASKET_OPEN_BAR) : 0;
   if(age_bars > BasketStaleAfterBars)
   {
      double over = (double)(age_bars - BasketStaleAfterBars) /
                    MathMax(1.0, (double)BasketStaleFullBars - (double)BasketStaleAfterBars);
      stale += BasketStaleAgeWeight * MathMin(1.0, over);
      parts += StringFormat("%d bars old; ", age_bars);
   }

   // --- session handover -----------------------------------------------------
   // The participants who would produce the recovery are not the ones who were
   // trading when the basket was built.
   if(EnableSessionContext && G_BASKET_OPEN_SESSION >= 0)
   {
      int mins = 0;
      string sd = "";
      int now_sess = SessionContext(mins, sd);
      if(now_sess != G_BASKET_OPEN_SESSION)
      {
         stale += BasketStaleSessionWeight;
         parts += StringFormat("opened in %s, now %s; ",
                               SessionName(G_BASKET_OPEN_SESSION), SessionName(now_sess));
      }
   }

   // --- the target it was aimed at -------------------------------------------
   // If the structure the basket was working toward has broken, the target it was
   // given no longer describes anything.
   if(EnableLocalStructure && G_BASKET_TARGET_LEVEL > 0.0 && _Point > 0.0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
      int bdir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;

      if(mid > 0.0)
      {
         // Price has gone past the target without the basket closing - whatever the
         // target meant, it has been and gone.
         bool passed = (bdir > 0) ? (mid > G_BASKET_TARGET_LEVEL)
                                  : (mid < G_BASKET_TARGET_LEVEL);
         if(passed)
         {
            stale += BasketStaleTargetWeight;
            parts += StringFormat("price passed the %.2f target; ", G_BASKET_TARGET_LEVEL);
         }
      }
   }

   stale = MathMax(0.0, MathMin(1.0, stale));
   if(stale > 0.0)
      detail = StringFormat("basket %.0f%% stale: %s", stale * 100.0, parts);
   return stale;
}

// ============================================================================
// V226: MODULE HEALTH - one line that says whether any of this is working
// ----------------------------------------------------------------------------
// Twenty modules were added to this EA in a single session and not one of them was
// ever observed running. The brace counts balanced and the recursion scan was clean,
// which proves the file compiles and proves nothing about whether
// ConsecutivePressureDir finds a push or LocalStructureUpdate counts swings
// correctly. They were written, and then trusted.
//
// That is how a session ends with an EA that takes two trades in twelve hours: each
// module looked reasonable in isolation, none was verified, and the failure only
// surfaced when the account stopped trading.
//
// This checks each one against live data and reports a single number. Twenty modules
// answering is 20/20. Nineteen is 20/19, with the silent one named underneath. It
// costs one dashboard line and replaces the guesswork entirely.
//
// "Answering" means the module ran and returned something coherent - not that it
// found a signal. A pattern detector correctly finding no pattern is healthy; one
// that cannot read its own candles is not. The distinction matters, because a module
// that is simply quiet looks identical to a broken one until you ask it directly.
// ============================================================================


string G_MH_NAME[MODHEALTH_MAX];
int    G_MH_STATE[MODHEALTH_MAX];    // 1 = answering, 0 = silent, -1 = failed
string G_MH_NOTE[MODHEALTH_MAX];
int    G_MH_COUNT = 0;
int    G_MH_BAR   = -100000;


// ============================================================================
// V225: STRUCTURE ACROSS TIMEFRAMES, AND HOW FAR IT HAS ALREADY RUN
// ----------------------------------------------------------------------------
// The measured structure reads M5 and treats what it finds as the answer. It is not
// the answer; it is one answer at one scale, and the scale above usually decides what
// it means.
//
// Three lower highs on M5 inside a rising M15 sequence is a pullback - a temporary
// giving-back within a larger move up - and trading it as a downtrend means selling
// the dip of an uptrend. The same three lower highs inside a falling M15 sequence is
// the real thing, and the two are indistinguishable without looking up.
//
// Reading three timeframes also produces something none of them has alone: their
// RELATIONSHIP.
//
//   All three agreeing is the rarest and strongest condition on the chart.
//   The lower disagreeing with the two above it is a pullback, which is an entry in
//     the direction of the higher ones rather than a signal in its own.
//   The middle disagreeing with both is a transition - the move is changing and
//     nothing is settled.
//
// And distance. A structure that has already travelled four dollars is closer to
// finishing than one that has travelled one, whatever the step count says. Three
// steps covering eight dollars and three steps covering eighty cents are read
// identically today.
// ============================================================================


string TFAlignName(const int a)
{
   switch(a)
   {
      case TFALIGN_FULL:       return "aligned";
      case TFALIGN_PULLBACK:   return "pullback";
      case TFALIGN_TRANSITION: return "transition";
      case TFALIGN_SPLIT:      return "split";
   }
   return "none";
}

// A compact structure reading for any timeframe - direction and how convincing.
int StructureDirOnTF(const ENUM_TIMEFRAMES tf, double &conviction, double &travelled_pts)
{
   conviction = 0.0;
   travelled_pts = 0.0;
   if(_Point <= 0.0)
      return 0;

   int look = MathMax(30, LocalStructureLookbackBars);
   int depth = MathMax(1, LocalStructureDepth);

   double sh[6], sl[6];
   int nh = 0, nl = 0;

   for(int i = depth + 1; i <= look && (nh < 6 || nl < 6); i++)
   {
      if(nh < 6)
      {
         double hv = CandleHigh(tf, i);
         bool ok = (hv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleHigh(tf, i - k) >= hv || CandleHigh(tf, i + k) >= hv) ok = false;
         if(ok) sh[nh++] = hv;
      }
      if(nl < 6)
      {
         double lv = CandleLow(tf, i);
         bool ok = (lv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleLow(tf, i - k) <= lv || CandleLow(tf, i + k) <= lv) ok = false;
         if(ok) sl[nl++] = lv;
      }
   }

   int need = MathMax(2, LocalStructureMinSwings - 1);
   if(nh < need || nl < need)
      return 0;

   int hi_down = 0, hi_up = 0, lo_down = 0, lo_up = 0;
   for(int a = 0; a + 1 < nh; a++) { if(sh[a] < sh[a+1]) hi_down++; else break; }
   for(int a = 0; a + 1 < nh; a++) { if(sh[a] > sh[a+1]) hi_up++;   else break; }
   for(int b = 0; b + 1 < nl; b++) { if(sl[b] < sl[b+1]) lo_down++; else break; }
   for(int b = 0; b + 1 < nl; b++) { if(sl[b] > sl[b+1]) lo_up++;   else break; }

   int dir = 0, steps = 0;
   if(hi_down >= 1 && lo_down >= 1)  { dir = -1; steps = MathMin(hi_down, lo_down); }
   else if(hi_up >= 1 && lo_up >= 1) { dir =  1; steps = MathMin(hi_up, lo_up); }

   if(dir == 0)
      return 0;

   conviction = MathMin(1.0, (double)steps / MathMax(1.0, (double)LocalStructureFullSteps));

   // How far has this run? From the extreme that started it to the newest swing - the
   // measure of how much of the move is already behind us.
   int use = MathMin(MathMin(nh, nl), 6);
   if(use >= 2)
   {
      double start = (dir < 0) ? sh[use-1] : sl[use-1];
      double now   = (dir < 0) ? sl[0]     : sh[0];
      if(start > 0.0 && now > 0.0)
         travelled_pts = MathAbs(now - start) / _Point;
   }

   return dir;
}

// The three-timeframe picture and what their relationship says.
int StructureAlignment(int &dir, double &weight, string &detail)
{
   dir = 0;
   weight = 0.0;
   detail = "";

   if(!EnableStructureMTF)
      return TFALIGN_NONE;

   static int    sa_bar = -100000;
   static int    sa_state = TFALIGN_NONE;
   static int    sa_dir = 0;
   static double sa_weight = 0.0;
   static string sa_detail = "";
   if(sa_bar > G_BARS_SEEN) sa_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(sa_bar == G_BARS_SEEN)
   {
      dir = sa_dir; weight = sa_weight; detail = sa_detail;
      return sa_state;
   }

   double c_low = 0.0, c_mid = 0.0, c_high = 0.0;
   double t_low = 0.0, t_mid = 0.0, t_high = 0.0;
   int d_low  = StructureDirOnTF(LocalStructureTF,   c_low,  t_low);
   int d_mid  = StructureDirOnTF(StructureMTFMiddle, c_mid,  t_mid);
   int d_high = StructureDirOnTF(StructureMTFHigher, c_high, t_high);

   int state = TFALIGN_NONE;
   int out_dir = 0;
   double w = 0.0;

   if(d_low != 0 && d_low == d_mid && d_mid == d_high)
   {
      // The rarest and strongest condition available.
      state = TFALIGN_FULL;
      out_dir = d_low;
      w = MathMin(1.0, (c_low + c_mid + c_high) / 3.0 * StructureAlignFullBoost);
      detail = StringFormat("all timeframes %s", (out_dir > 0 ? "rising" : "falling"));
   }
   else if(d_low != 0 && d_mid != 0 && d_high != 0 &&
           d_mid == d_high && d_low == -d_mid)
   {
      // The lower timeframe is giving back within a larger move. This is a pullback,
      // and the trade it implies runs with the HIGHER timeframes, not the lower one.
      state = TFALIGN_PULLBACK;
      out_dir = d_mid;
      w = MathMin(1.0, (c_mid + c_high) / 2.0);
      detail = StringFormat("%s pullback inside a %s structure",
                            (d_low > 0 ? "rising" : "falling"),
                            (d_mid > 0 ? "rising" : "falling"));
   }
   else if(d_mid != 0 && d_low != 0 && d_high != 0 && d_mid == -d_high)
   {
      // The middle has turned against the top. Something is changing and nothing is
      // decided - the worst moment to commit to either side.
      state = TFALIGN_TRANSITION;
      out_dir = 0;
      w = MathMin(1.0, (c_mid + c_high) / 2.0);
      detail = "structure in transition - middle and higher disagree";
   }
   else if(d_low != 0 || d_mid != 0 || d_high != 0)
   {
      state = TFALIGN_SPLIT;
      out_dir = 0;
      w = 0.0;
      detail = "timeframes split";
   }

   dir = out_dir;
   weight = w;
   sa_bar = G_BARS_SEEN; sa_state = state; sa_dir = out_dir;
   sa_weight = w; sa_detail = detail;
   return state;
}

// How much of the structure's move is already behind us? 0 = just started, 1 = has
// travelled as far as these usually go.
double StructureMaturity(string &detail)
{
   detail = "";
   if(!EnableStructureMaturity || _Point <= 0.0)
      return 0.0;

   double conv = 0.0, travelled = 0.0;
   int d = StructureDirOnTF(LocalStructureTF, conv, travelled);
   if(d == 0 || travelled <= 0.0)
      return 0.0;

   double atr = ATRPointsManual(LocalStructureTF, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   // Measured in ATR rather than dollars, so it holds across quiet and volatile days.
   double in_atr = travelled / atr;
   double maturity = MathMin(1.0, in_atr / MathMax(1.0, StructureMatureATR));

   detail = StringFormat("structure has run %.1f ATR (%.0f pts)", in_atr, travelled);
   return maturity;
}

// ============================================================================
// V224: THE INVALIDATION PRICE PUT TO WORK
// ----------------------------------------------------------------------------
// V223 computes the price at which the local structure stops existing - the most
// recent lower high in a falling sequence - and then uses it for a two-point score
// bonus. That is the least valuable thing that number can do.
//
// It is the only price on the chart with a precise meaning. Above it, a downtrend is
// not a downtrend any more; that is not an opinion or a threshold, it is the
// definition. Three uses follow directly:
//
//   THE BREAK IS AN EVENT. Price closing through it is the moment a structure ends,
//   and it is the highest-information moment available - stronger than any indicator
//   reading, because the thing being measured has just changed state. The EA
//   currently notices only by recomputing the structure on the next bar and finding
//   it different.
//
//   IT IS A TARGET. A counter-trend trade is trying to reach it. That is a known
//   price, not the $2.50 estimate the EA would otherwise use.
//
//   IT MAY COINCIDE WITH A LEVEL. When the structure ends at the same price a zone
//   sits, two independent readings agree, and the price matters more than either
//   suggests alone. When they disagree, the picture is less clear than either implies.
// ============================================================================



// Watches the structure and records the moment it is broken. Called once per bar.
void LocalStructureBreakUpdate()
{
   if(!EnableStructureBreak || _Point <= 0.0)
      return;

   // V291: decide about the levels ahead while there is still time to. The slow readings - monthly
   // trend, higher structure, range position, the day itself - do not change in the seconds it takes
   // price to cover the last dollar, so computing them on arrival wastes the only thing that is
   // scarce at a level: time.
   PreparedLevelsRefresh();

   LocalStructureUpdate();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   // Was a structure in force, and has price closed through its invalidation?
   if(G_LSB_LAST_DIR != 0 && G_LSB_LAST_PRICE > 0.0)
   {
      double close_1 = CandleClose(LocalStructureTF, 1);
      if(close_1 > 0.0)
      {
         bool broken = (G_LSB_LAST_DIR < 0) ? (close_1 > G_LSB_LAST_PRICE)
                                            : (close_1 < G_LSB_LAST_PRICE);
         // V232: a break the higher timeframe has not confirmed is a break at one resolution only.
         // The same reasoning as the retest check - a structure that ended on M5 while M15 still
         // shows it intact has not ended, and treating it as an event produces exactly the entry
         // that cost money: buying a level the larger picture still calls resistance.
         if(broken && EnableBrokenRetestMTF)
         {
            double sb_htf = CandleClose(BrokenRetestConfirmTF, 1);
            if(sb_htf > 0.0)
            {
               bool sb_beyond = (G_LSB_LAST_DIR < 0) ? (sb_htf > G_LSB_LAST_PRICE)
                                                     : (sb_htf < G_LSB_LAST_PRICE);
               if(!sb_beyond)
                  broken = false;
            }
         }

         if(broken)
         {
            // The break points the opposite way to the structure it ended.
            G_LSB_BREAK_DIR = -G_LSB_LAST_DIR;
            G_LSB_BREAK_BAR = G_BARS_SEEN;
            G_LSB_BREAK_PRICE = G_LSB_LAST_PRICE;

            if((StructureBreakPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v224 BREAK] %s structure ended - closed %s %.2f",
                           (G_LSB_LAST_DIR < 0 ? "falling" : "rising"),
                           (G_LSB_LAST_DIR < 0 ? "above" : "below"), G_LSB_LAST_PRICE);

            G_LSB_LAST_DIR = 0;
            G_LSB_LAST_PRICE = 0.0;
         }
      }
   }

   // Track the current structure so the next break can be seen.
   if(G_LS_DIR != 0 && G_LS_INVALIDATE > 0.0 && G_LS_STATE != LSTRUCT_CHOPPY)
   {
      G_LSB_LAST_DIR = G_LS_DIR;
      G_LSB_LAST_PRICE = G_LS_INVALIDATE;
   }
}

// How fresh is the last structure break, and which way does it point?
//   returns the direction, or 0 when there is no recent break
int RecentStructureBreak(double &freshness, double &price)
{
   freshness = 0.0;
   price = 0.0;
   if(!EnableStructureBreak || G_LSB_BREAK_DIR == 0)
      return 0;

   int age = G_BARS_SEEN - G_LSB_BREAK_BAR;
   int window = MathMax(2, StructureBreakFreshBars);
   if(age > window)
      return 0;

   // A break matters most immediately and fades - by the time it is twenty bars old,
   // whatever it started has already happened.
   freshness = 1.0 - ((double)age / (double)window);
   price = G_LSB_BREAK_PRICE;
   return G_LSB_BREAK_DIR;
}

// Does the structure's end coincide with a zone? Returns 0..1 - how closely the two
// independent readings agree on the same price.
double StructureLevelConfluence(double &level_out, string &detail)
{
   level_out = 0.0;
   detail = "";

   if(!EnableStructureConfluence || _Point <= 0.0)
      return 0.0;

   LocalStructureUpdate();
   if(G_LS_DIR == 0 || G_LS_INVALIDATE <= 0.0)
      return 0.0;

   // The structure ends at a high for a falling sequence, so the zone that would
   // matter there is resistance.
   double level = (G_LS_DIR < 0) ? ZoneMapNearestResistance(G_LS_INVALIDATE - (10.0 * _Point))
                                 : ZoneMapNearestSupport(G_LS_INVALIDATE + (10.0 * _Point));
   if(level <= 0.0)
      return 0.0;

   double gap = MathAbs(level - G_LS_INVALIDATE) / _Point;
   double tol = ScaleAdjustedPoints(MathMax(1, StructureConfluenceTolerance));
   if(gap > tol)
      return 0.0;

   double strength = ZoneMapStrengthByTouches(level);
   double proximity = 1.0 - (gap / MathMax(1.0, tol));
   double str_f = MathMin(1.0, strength / MathMax(0.1, CandleLocationFullStrength));

   level_out = level;
   detail = StringFormat("structure ends at %.2f where a %.2f-strength zone sits (%.0f pts apart)",
                         G_LS_INVALIDATE, strength, gap);
   return MathMax(0.0, MathMin(1.0, proximity * (0.4 + 0.6 * str_f)));
}

// ============================================================================
// V223: LOCAL STRUCTURE READ AS SHAPE, NOT AS AN INDICATOR
// ----------------------------------------------------------------------------
// Local trend is currently ADX. ADX answers "is there a trend" and says nothing about
// what the trend looks like - price stepping down in measured swings and price
// collapsing in one leg produce similar readings, and they are completely different
// trades. It also lags, because it is an average.
//
// V218 added the swing sequence, which is closer to what a trader sees, but it only
// COUNTS: three lower highs. It does not measure them, and the measurements are where
// the information is.
//
//   How far is each step? Swings of twenty cents are a drift; swings of two dollars
//   are a trend with participants behind it.
//
//   Are the steps growing or shrinking? Expanding swings mean the move is being fed;
//   contracting ones mean it is running out, and the last swing before a turn is
//   almost always the smallest.
//
//   Where does it end? A sequence of lower highs has a specific price above which it
//   stops being a sequence. That is the single most useful number in the structure -
//   it defines both the invalidation and the target of any counter-trade - and the EA
//   has never computed it.
// ============================================================================


string LocalStructureName(const int st)
{
   switch(st)
   {
      case LSTRUCT_STEPPING:  return "stepping";
      case LSTRUCT_EXPANDING: return "expanding";
      case LSTRUCT_FADING:    return "fading";
      case LSTRUCT_CHOPPY:    return "choppy";
   }
   return "none";
}

// Everything the local structure knows, computed once per bar.
// (G_LS_* declared above with the other structure state - the break tracker reads them)

void LocalStructureUpdate()
{
   if(!EnableLocalStructure || _Point <= 0.0)
      return;
   if(G_LS_BAR == G_BARS_SEEN)
      return;

   G_LS_BAR = G_BARS_SEEN;
   G_LS_STATE = LSTRUCT_NONE;
   G_LS_DIR = 0;
   G_LS_STEP_AVG = 0.0;
   G_LS_STEP_TREND = 0.0;
   G_LS_INVALIDATE = 0.0;
   G_LS_CONVICTION = 0.0;
   G_LS_DETAIL = "";

   ENUM_TIMEFRAMES tf = LocalStructureTF;
   int look = MathMax(30, LocalStructureLookbackBars);
   int depth = MathMax(1, LocalStructureDepth);

   // Collect swings, newest first, keeping the bar each came from so the sequence
   // can be read in order.
   double sh[8], sl[8];
   int    sh_bar[8], sl_bar[8];
   int nh = 0, nl = 0;

   for(int i = depth + 1; i <= look && (nh < 8 || nl < 8); i++)
   {
      if(nh < 8)
      {
         double hv = CandleHigh(tf, i);
         bool ok = (hv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleHigh(tf, i - k) >= hv || CandleHigh(tf, i + k) >= hv) ok = false;
         if(ok) { sh[nh] = hv; sh_bar[nh] = i; nh++; }
      }
      if(nl < 8)
      {
         double lv = CandleLow(tf, i);
         bool ok = (lv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleLow(tf, i - k) <= lv || CandleLow(tf, i + k) <= lv) ok = false;
         if(ok) { sl[nl] = lv; sl_bar[nl] = i; nl++; }
      }
   }

   int need = MathMax(3, LocalStructureMinSwings);
   if(nh < need || nl < need)
      return;

   // --- direction: do highs and lows step the same way? ---------------------
   int hi_down = 0, hi_up = 0, lo_down = 0, lo_up = 0;
   for(int a = 0; a + 1 < nh; a++)
   {
      if(sh[a] < sh[a+1]) hi_down++; else break;
   }
   for(int a = 0; a + 1 < nh; a++)
   {
      if(sh[a] > sh[a+1]) hi_up++; else break;
   }
   for(int b = 0; b + 1 < nl; b++)
   {
      if(sl[b] < sl[b+1]) lo_down++; else break;
   }
   for(int b = 0; b + 1 < nl; b++)
   {
      if(sl[b] > sl[b+1]) lo_up++; else break;
   }

   int dir = 0, steps = 0;
   if(hi_down >= 1 && lo_down >= 1)      { dir = -1; steps = MathMin(hi_down, lo_down); }
   else if(hi_up >= 1 && lo_up >= 1)     { dir =  1; steps = MathMin(hi_up, lo_up); }

   // --- measure the steps ----------------------------------------------------
   // The size of each swing leg, newest first. This is what separates a trend with
   // participants from a drift that happens to be pointing one way.
   double legs[6];
   int nlegs = 0;
   int use = MathMin(MathMin(nh, nl), 6);
   for(int i = 0; i + 1 < use && nlegs < 6; i++)
   {
      double leg = MathAbs(sh[i] - sl[i]) / _Point;
      if(leg > 0.0)
         legs[nlegs++] = leg;
   }

   if(nlegs < 2)
      return;

   double sum = 0.0;
   for(int i = 0; i < nlegs; i++)
      sum += legs[i];
   G_LS_STEP_AVG = sum / (double)nlegs;

   // Are the legs growing or shrinking? Compare the newest against the older ones -
   // the last swing before a turn is almost always the smallest.
   double newer = legs[0];
   double older = 0.0;
   int on = 0;
   for(int i = 1; i < nlegs; i++) { older += legs[i]; on++; }
   if(on > 0) older /= (double)on;
   if(older > 0.0)
      G_LS_STEP_TREND = (newer - older) / older;

   // --- where does the structure end? ---------------------------------------
   // A sequence of lower highs stops being one at the most recent high. That price is
   // both the invalidation for a short and the first target for a long, and it is the
   // most actionable number the structure produces.
   if(dir < 0 && nh > 0)      G_LS_INVALIDATE = sh[0];
   else if(dir > 0 && nl > 0) G_LS_INVALIDATE = sl[0];

   // --- name the shape -------------------------------------------------------
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   bool meaningful = (atr <= 0.0) || (G_LS_STEP_AVG >= atr * LocalStructureMinLegATR);

   if(dir == 0 || !meaningful)
   {
      G_LS_STATE = LSTRUCT_CHOPPY;
      G_LS_DETAIL = StringFormat("choppy (legs %.0f pts, no consistent direction)", G_LS_STEP_AVG);
      return;
   }

   G_LS_DIR = dir;
   G_LS_CONVICTION = MathMin(1.0, (double)steps / MathMax(1.0, (double)LocalStructureFullSteps));

   if(G_LS_STEP_TREND >= LocalStructureExpandThreshold)
      G_LS_STATE = LSTRUCT_EXPANDING;
   else if(G_LS_STEP_TREND <= -LocalStructureFadeThreshold)
      G_LS_STATE = LSTRUCT_FADING;
   else
      G_LS_STATE = LSTRUCT_STEPPING;

   G_LS_DETAIL = StringFormat("%s %s, %d steps, legs %.0f pts (%+.0f%%), ends at %.2f",
                              (dir > 0 ? "rising" : "falling"),
                              LocalStructureName(G_LS_STATE),
                              steps, G_LS_STEP_AVG, G_LS_STEP_TREND * 100.0,
                              G_LS_INVALIDATE);
}

// The price above/below which this structure no longer exists.
double LocalStructureInvalidation()
{
   LocalStructureUpdate();
   return G_LS_INVALIDATE;
}
