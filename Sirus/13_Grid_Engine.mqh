//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 13_Grid_Engine                                  |
//| Grid intelligence, grid lot, GridCanOpen, grid engine            |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// Shared per-bar cache, same pattern as Major Sweep / Engulfing.
// ============================================================================
// V113: ZONE BREAK SEQUENCE - the story the chart tells.
// ----------------------------------------------------------------------------
// RecentZoneBreakDirection() above stops at the FIRST break it finds, so the EA
// only ever knew "a break happened". What a trader actually reads is the
// SEQUENCE: on the live chart the user marked 4020, then 4050, then 4070, then
// 4165 - each level broken in turn, each becoming support. That staircase is the
// clearest possible statement that one side is in control, and the EA was blind
// to it.
//
// This walks the whole window and counts breaks per direction, skipping repeats
// of the same level (a zone can look "just broken" for several bars). Two or more
// breaks the same way is a staircase; breaks in both directions is churn, not a
// trend, and is reported as no sequence.
// ============================================================================
void BreakSequenceReadRaw()
{
   G_BREAK_SEQ_DIR   = 0;
   G_BREAK_SEQ_COUNT = 0;
   G_BREAK_SEQ_TXT   = "";

   if(!EnableBreakSequence || !EnableRecentZoneBreak || _Point <= 0.0)
      return;

   int lookback = MathMax(2, BreakSequenceLookbackBars);
   double tol   = MathMax(1, ZoneBreakSearchPoints) * _Point;
   double dedupe_tol = MathMax(1, BreakSequenceDedupePoints) * _Point;

   int up_breaks = 0, dn_breaks = 0;
   double up_levels[16], dn_levels[16];
   int up_n = 0, dn_n = 0;
   double first_up = 0.0, last_up = 0.0, first_dn = 0.0, last_dn = 0.0;

   // Walk from the oldest bar in the window toward the newest, so the levels are
   // collected in the order price actually broke them.
   for(int shift = lookback; shift >= 1; shift--)
   {
      double c       = CandleClose(ZoneBreakTF, shift);
      double c_prior = CandleClose(ZoneBreakTF, shift + 1);
      if(c <= 0.0 || c_prior <= 0.0)
         continue;

      // Bullish break of a strong resistance.
      double res = ZoneMapNearestResistance(c_prior - tol);
      if(res > 0.0 && c > res + tol && c_prior <= res + tol && ZoneMapStrength(res) >= ZoneBreakMinStrength)
      {
         bool seen = false;
         for(int k = 0; k < up_n; k++)
            if(MathAbs(up_levels[k] - res) <= dedupe_tol) { seen = true; break; }
         if(!seen && up_n < 16)
         {
            up_levels[up_n++] = res;
            up_breaks++;
            if(first_up <= 0.0) first_up = res;
            last_up = res;
         }
      }

      // Bearish break of a strong support.
      double sup = ZoneMapNearestSupport(c_prior + tol);
      if(sup > 0.0 && c < sup - tol && c_prior >= sup - tol && ZoneMapStrength(sup) >= ZoneBreakMinStrength)
      {
         bool seen = false;
         for(int k = 0; k < dn_n; k++)
            if(MathAbs(dn_levels[k] - sup) <= dedupe_tol) { seen = true; break; }
         if(!seen && dn_n < 16)
         {
            dn_levels[dn_n++] = sup;
            dn_breaks++;
            if(first_dn <= 0.0) first_dn = sup;
            last_dn = sup;
         }
      }
   }

   int need = MathMax(1, BreakSequenceMinCount);

   // A staircase requires the breaks to be one-sided. Breaks both ways inside the
   // window means price is chopping through levels, which is the opposite of control.
   if(up_breaks >= need && up_breaks > dn_breaks)
   {
      G_BREAK_SEQ_DIR   = 1;
      G_BREAK_SEQ_COUNT = up_breaks;
      G_BREAK_SEQ_TXT   = StringFormat("staircase UP: %d levels broken (%.2f -> %.2f)", up_breaks, first_up, last_up);
   }
   else if(dn_breaks >= need && dn_breaks > up_breaks)
   {
      G_BREAK_SEQ_DIR   = -1;
      G_BREAK_SEQ_COUNT = dn_breaks;
      G_BREAK_SEQ_TXT   = StringFormat("staircase DOWN: %d levels broken (%.2f -> %.2f)", dn_breaks, first_dn, last_dn);
   }
   else if(up_breaks > 0 || dn_breaks > 0)
      G_BREAK_SEQ_TXT = StringFormat("breaks both ways (%dup/%ddn) - no staircase", up_breaks, dn_breaks);
}

// Per-bar cache: the scan walks the whole window, so it must not run on every tick.
void BreakSequenceRead()
{
   static int last_bar = -100000;
   if(last_bar > G_BARS_SEEN) last_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(last_bar == G_BARS_SEEN)
      return;
   last_bar = G_BARS_SEEN;
   BreakSequenceReadRaw();
}

int RecentZoneBreakDirection(string &detail)
{
   static int    zb_cache_bar = -1;
   static int    zb_cache_dir = 0;
   static string zb_cache_detail = "";
   if(zb_cache_bar > G_BARS_SEEN) zb_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(zb_cache_bar != G_BARS_SEEN)
   {
      zb_cache_dir = RecentZoneBreakDirectionRaw(zb_cache_detail);
      zb_cache_bar = G_BARS_SEEN;
   }

   detail = zb_cache_detail;
   return zb_cache_dir;
}

// ============================================================================
// V31.6z NEW: TREND QUALITY SCORE - "the market moves with a trend more often than it
// reverses" synthesis layer. Combines FOUR independent measures of trend health into one
// 0.0-1.0 score for a given direction:
//   1. ADX strength + direction (is there real momentum, and whose side is it on)
//   2. Multi-TF alignment (how many timeframes agree)
//   3. Moving average order (fast > medium > slow for an uptrend, reversed for downtrend -
//      the classic "ribbon" trend-health check)
//   4. Higher-High/Higher-Low structure continuation (or Lower-High/Lower-Low for downtrend) -
//      is the swing structure itself still confirming the trend, not just price momentum
// This is designed to boost EVERY continuation-type detector (they all check this in the
// same direction they're proposing), and can also stand alone as its own confirmation.
// ============================================================================
double TrendQualityScoreRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableTrendQualityScore || direction == 0)
      return 0.5;

   double total = 0.0;
   int factors = 0;

   // --- Factor 1: ADX strength + direction ---
   double adx      = NaviusADX(TrendQualityTF, TrendStrengthPeriod, 0, 1);
   double plus_di   = NaviusADX(TrendQualityTF, TrendStrengthPeriod, 1, 1);
   double minus_di  = NaviusADX(TrendQualityTF, TrendStrengthPeriod, 2, 1);
   if(adx > 0.0 && plus_di > 0.0 && minus_di > 0.0)
   {
      int adx_dir = (plus_di > minus_di) ? 1 : -1;
      double range = MathMax(1.0, TrendStrengthStrongADX - TrendStrengthMinADX);
      double strength = MathMax(0.0, MathMin(1.0, (adx - TrendStrengthMinADX) / range));
      double adx_component = (adx_dir == direction) ? (0.5 + strength * 0.5) : (0.5 - strength * 0.5);

      // V31.6z20 NEW: ADX still numerically strong doesn't mean it's still GROWING - a
      // falling ADX after a peak (even if above the min-strength threshold) is a classic
      // exhaustion signal that the pure value check above completely missed.
      if(adx_dir == direction)
      {
         double decel = ADXDecelerationFactor(TrendQualityTF, TrendStrengthPeriod, ADXDecelerationLookbackBars);
         if(decel > 0.0)
         {
            adx_component -= decel * 0.3;
            detail += StringFormat("ADX-decelerating(%.2f) ", decel);
         }
      }

      total += adx_component;
      factors++;
      if(adx_dir == direction && strength >= 0.5)
         detail += StringFormat("ADX=%.0f(dir-agree) ", adx);
   }

   // --- Factor 1b: RSI Cooling / DXY Deceleration - two more instances of the same "still
   // strong but weakening" pattern. RSI was previously ONLY used for reversal divergence; DXY
   // was only checked for slope magnitude, never for its own deceleration. ---
   {
      double momentum_penalty = 0.0;
      string mom_detail = "";

      if(EnableRSICooling)
      {
         string rsi_detail = "";
         double rsi_cool = RSICoolingFactor(direction, TrendQualityTF, TrendReversalRSIPeriod, ADXDecelerationLookbackBars, rsi_detail);
         if(rsi_cool > 0.0)
         {
            momentum_penalty += rsi_cool * 0.2;
            mom_detail += rsi_detail + " ";
         }
      }

      if(EnableDXYDeceleration)
      {
         double dxy_decel = DXYDecelerationFactor();
         if(dxy_decel > 0.0)
         {
            momentum_penalty += dxy_decel * 0.15;
            mom_detail += StringFormat("DXY-decelerating(%.2f) ", dxy_decel);
         }
      }

      if(momentum_penalty > 0.0)
      {
         total += MathMax(0.0, 0.5 - momentum_penalty);
         factors++;
         detail += mom_detail;
      }
   }

   // --- Factor 2: Multi-TF alignment ---
   if(EnableMTFAlignment)
   {
      int mtf_agree = MTFAlignmentCount(direction);
      double mtf_component = 0.4 + (mtf_agree / 4.0) * 0.6;

      // V31.6z58 fix: last remaining place where the binary MTF count still drove a major
      // decision. TrendQualityScore feeds Grid Intelligence, TP Intelligence, Smart Trail,
      // First Entry AND the AUTO Hunter trend-clarity gate - so "4 timeframes barely drifting"
      // scoring identically to "4 timeframes strongly ADX-confirmed" propagated everywhere.
      // Blends in the magnitude-aware reading (built in z36, but only wired into Grid until now).
      if(EnableMTFConfidence)
      {
         string tq_mtf_detail = "";
         double tq_mtf_conf = MTFAlignmentConfidence(direction, tq_mtf_detail);
         double conf_component = 0.5 + tq_mtf_conf * 0.5;
         mtf_component = (mtf_component + conf_component) * 0.5;
      }

      total += mtf_component;
      factors++;
      if(mtf_agree >= 3)
         detail += StringFormat("MTF %d/4 ", mtf_agree);
   }

   // --- Factor 3: Moving average order (ribbon check) ---
   double sma_fast   = SMA(TrendQualityTF, TrendQualityFastMA, 1);
   double sma_medium = SMA(TrendQualityTF, TrendQualityMediumMA, 1);
   double sma_slow   = SMA(TrendQualityTF, TrendQualitySlowMA, 1);
   if(sma_fast > 0.0 && sma_medium > 0.0 && sma_slow > 0.0)
   {
      bool ordered_up   = (sma_fast > sma_medium && sma_medium > sma_slow);
      bool ordered_down = (sma_fast < sma_medium && sma_medium < sma_slow);
      double ma_component = 0.5;
      if((direction > 0 && ordered_up) || (direction < 0 && ordered_down))
      {
         ma_component = 0.85;
         detail += "MA-ribbon-ordered ";

         // V31.6z20 NEW: ordering alone doesn't say whether the ribbon is SPREADING (healthy,
         // strengthening trend) or CONVERGING (the MAs closing back together - a classic
         // early warning of trend loss the binary ordered/not-ordered check completely missed).
         if(EnableMAConvergenceCheck)
         {
            double spread_now = MathAbs(sma_fast - sma_slow);
            double sma_fast_prior = SMA(TrendQualityTF, TrendQualityFastMA, MAConvergenceLookbackBars + 1);
            double sma_slow_prior = SMA(TrendQualityTF, TrendQualitySlowMA, MAConvergenceLookbackBars + 1);
            if(sma_fast_prior > 0.0 && sma_slow_prior > 0.0)
            {
               double spread_prior = MathAbs(sma_fast_prior - sma_slow_prior);
               if(spread_prior > 0.0 && spread_now < spread_prior * MAConvergenceThreshold)
               {
                  ma_component -= 0.25;
                  detail += "MA-converging ";
               }
            }
         }
      }
      else if((direction > 0 && ordered_down) || (direction < 0 && ordered_up))
      {
         ma_component = 0.15;
      }
      total += ma_component;
      factors++;
   }

   // --- Factor 4: swing structure continuation (HH/HL or LH/LL) ---
   int depth = MathMax(1, TrendQualitySwingDepth);
   int lookback = MathMax(depth * 3, TrendQualitySwingLookback);

   double low1 = 0.0, low2 = 0.0;
   int low1_shift = -1, low2_shift = -1;
   bool got_lows = FindLastTwoSwingLows(TrendQualityTF, lookback, depth, low1, low1_shift, low2, low2_shift);

   double high1 = 0.0, high2 = 0.0;
   int high1_shift = -1, high2_shift = -1;
   bool got_highs = FindLastTwoSwingHighs(TrendQualityTF, lookback, depth, high1, high1_shift, high2, high2_shift);

   if(got_lows && got_highs)
   {
      bool hh_hl = (high1 > high2 && low1 > low2);   // uptrend structure still intact
      bool lh_ll = (high1 < high2 && low1 < low2);   // downtrend structure still intact

      double struct_component = 0.5;
      if((direction > 0 && hh_hl) || (direction < 0 && lh_ll))
      {
         struct_component = 0.85;
         detail += "structure-intact ";
      }
      else if((direction > 0 && lh_ll) || (direction < 0 && hh_hl))
      {
         struct_component = 0.15;
      }
      total += struct_component;
      factors++;
   }

   // --- Factor 5: Impulse Confirmation - was completely absent from this synthesis before.
   // A genuine, sharp burst is direct evidence of conviction, distinct from the slower
   // measures above (ADX, MA order, structure) which can lag a fresh move by several bars.
   if(EnableImpulseConfirmation)
   {
      string imp_detail_tq = "";
      double imp_score_tq = ImpulseConfirmation(direction, imp_detail_tq);
      total += imp_score_tq;
      factors++;
      if(imp_score_tq >= 0.6)
         detail += imp_detail_tq;
   }

   if(factors == 0)
      return 0.5;

   return MathMax(0.0, MathMin(1.0, total / factors));
}

// Shared per-bar cache - same pattern as the other multi-factor senses.
double TrendQualityScore(const int direction, string &detail)
{
   static int    tq_cache_bar = -1;
   static int    tq_cache_dir = 0;
   static double tq_cache_score = 0.5;
   static string tq_cache_detail = "";
   if(tq_cache_bar > G_BARS_SEEN) tq_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(tq_cache_bar != G_BARS_SEEN || tq_cache_dir != direction)
   {
      tq_cache_score = TrendQualityScoreRaw(direction, tq_cache_detail);
      tq_cache_bar = G_BARS_SEEN;
      tq_cache_dir = direction;
   }

   detail = tq_cache_detail;
   return tq_cache_score;
}

// V31.6z60 REBUILD: this is the ONE sense whose entire job is to answer the question that
// actually matters for a rescue mechanism - "can this basket realistically get back to
// break-even?" - and its logic was INVERTED.
//
// For a BUY basket underwater at avg 4087 with price at 4050, the path home is UPWARD, and the
// zones sitting on that path are RESISTANCES - obstacles price must break through to escape.
// The old code searched for exactly those, found the STRONGEST one, and then:
//     strong barrier found -> 0.55 + strength*0.1  = up to 0.85  ("excellent!")
//     clear path, nothing  -> 0.25                              ("bad!")
// So a major wall standing between the basket and break-even scored as a REASON TO ADD MORE,
// while a completely clear road home scored as a reason for caution. Exactly backwards.
//
// Rebuilt around the real question. A rescuer should ask: how much resistance stands between
// here and home, and how far along the path does it sit? A barrier close to break-even is far
// worse than one just above current price (which price can clear early, with room left to run).
double RecoveryPathZoneScore(const long direction, string &detail)
{
   if(!EnableRecoveryPathSearch || G_BASKET_AVG_PRICE <= 0.0)
      return 0.5;

   int dir_i = (direction == POSITION_TYPE_BUY) ? 1 : -1;

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.5;

   // FIX(recovery-path-sell): the path home always runs FROM current price TOWARD break-even -
   // for a BUY that's upward (price -> avg above it); for a SELL it's downward (price -> avg
   // below it). The old low_bound/high_bound pair was reused both as "where to start searching"
   // AND as "the far boundary to stop at", which only lines up for BUY (low_bound=price,
   // high_bound=avg). For SELL, low_bound was set to avg (the FAR boundary) and high_bound to
   // price (the START), so the search began AT break-even instead of at the current price and
   // the loop's own break-condition (zone < high_bound, i.e. zone < price) triggered on the very
   // first candidate - barrier_count could never leave 0, so every SELL basket in drawdown
   // silently scored "recovery-path CLEAR" (0.85) regardless of real walls between it and home.
   double price_ref = mid;
   double avg_ref    = G_BASKET_AVG_PRICE;

   if(dir_i > 0 && price_ref >= avg_ref)
      return 0.8;   // basket already at/near break-even - the path home is already walked
   if(dir_i < 0 && price_ref <= avg_ref)
      return 0.8;

   double total_span = MathAbs(avg_ref - price_ref);
   if(total_span <= 0.0)
      return 0.8;

   double worst_strength = 0.0;
   double worst_level = 0.0;
   int    barrier_count = 0;
   double search_from = price_ref;
   double last_zone   = 0.0;

   for(int attempt = 0; attempt < RecoveryPathMaxWaypoints; attempt++)
   {
      double zone = (dir_i > 0) ? ZoneMapNearestResistance(search_from) : ZoneMapNearestSupport(search_from);
      if(zone <= 0.0)
         break;
      if(dir_i > 0 && zone > avg_ref)
         break;
      if(dir_i < 0 && zone < avg_ref)
         break;

      // FIX(recovery-path-cascade): the step below advances search_from by only
      // RecoveryPathZoneToleranceP (50 pts), but the zone scan legitimately accepts levels up to
      // ZoneNearAboveTolerance (up to ~1600 pts after scaling) beyond the search price - so the
      // next iteration could return the SAME zone again, counting one wall up to
      // RecoveryPathMaxWaypoints times and inflating severity, while never reaching the real
      // barriers further along the path. Require the cascade to actually move forward.
      if(last_zone > 0.0)
      {
         bool advanced = (dir_i > 0) ? (zone > last_zone + _Point) : (zone < last_zone - _Point);
         if(!advanced)
            break;
      }
      last_zone = zone;

      double zstr = ZoneMapStrength(zone);
      if(zstr >= RecoveryPathMinZoneStrength)
      {
         barrier_count++;
         if(zstr > worst_strength)
         {
            worst_strength = zstr;
            worst_level = zone;
         }
      }

      search_from = zone + (dir_i > 0 ? 1.0 : -1.0) * MathMax(1.0, RecoveryPathZoneToleranceP) * _Point;
   }

   if(barrier_count == 0 || worst_level <= 0.0)
   {
      detail = "recovery-path CLEAR ";
      return 0.85;   // genuinely clear road home - the best case for a rescue attempt
   }

   // How far along the path does the worst barrier sit? 0 = right at current price (price can
   // clear it early, then run free), 1 = right at break-even (price must fight all the way and
   // still faces a wall at the finish line - much worse).
   double position_pct = MathAbs(worst_level - price_ref) / total_span;

   double severity = MathMin(1.0, (worst_strength - RecoveryPathMinZoneStrength) / MathMax(0.5, RecoveryPathSeveritySpan));
   severity = MathMax(0.15, severity);

   // Multiple separate barriers compound - each one is another place the recovery can stall.
   if(barrier_count >= 2)
      severity = MathMin(1.0, severity + (barrier_count - 1) * 0.15);

   // Weight by position: a barrier near break-even hurts most.
   double position_weight = 0.5 + position_pct * 0.5;   // 0.5 near price -> 1.0 near break-even
   double penalty = severity * position_weight;

   double score = MathMax(0.05, 0.85 - penalty * 0.7);

   detail = StringFormat("recovery-BARRIER@%.2f(str=%.1f,%d walls,%.0f%% along path) ",
                         worst_level, worst_strength, barrier_count, position_pct * 100.0);
   return score;
}

double GridIntelligenceScoreRaw(const long grid_direction, string &detail)
{
   detail = "";

   // FIX(direction-guard): grid_direction MUST be a real BUY/SELL. The old code did
   //     int dir_i = (grid_direction == POSITION_TYPE_BUY) ? 1 : -1;
   // which silently mapped ANY non-BUY value - including the -1 "no basket / unknown" sentinel
   // and -2 "mixed basket" - to -1 (SELL), then scored all 16 senses as if a SELL grid were
   // being considered. GridIntelligenceDistanceAdjust is reachable via RefreshGridDashboardStats
   // even with no basket, so this wrong-direction scoring could run and poison the per-bar cache.
   // A neutral 0.5 with no direction is the only honest answer when there is no real direction.
   if(grid_direction != POSITION_TYPE_BUY && grid_direction != POSITION_TYPE_SELL)
   {
      detail = "no valid basket direction";
      return 0.5;
   }

   int dir_i = (grid_direction == POSITION_TYPE_BUY) ? 1 : -1;

   // --- Sense 1: reversal confidence (weight 2.0) ---
   string rev_reason = "";
   bool   rev_div     = false;
   int    rev_dir      = TrendReversalDirection(rev_reason, rev_div);
   double rev_component = 0.5;

   if(rev_dir == -dir_i)
   {
      rev_component = rev_div ? 0.05 : 0.30;
      detail += StringFormat("reversal-against(div=%s) ", BoolText(rev_div));
   }
   else if(rev_dir == dir_i)
   {
      rev_component = 0.75;
      detail += "reversal-supports ";
   }

   // V31.6z32 UPGRADE: direct user feedback - fold in the unified Reversal Consensus (BOS/
   // CHoCH + Major Sweep + Engulfing combined with swing/RSI) instead of relying on swing/RSI
   // alone. Takes the MORE informative (more extreme, either direction) of the raw single-
   // method read above and the fuller multi-signal consensus.
   if(EnableReversalConsensus)
   {
      string rc_support_detail = "", rc_against_detail = "";
      double rc_support_score = ReversalConsensusScore(dir_i, rc_support_detail);
      double rc_against_score = ReversalConsensusScore(-dir_i, rc_against_detail);

      if(rc_support_score > rev_component)
      {
         rev_component = rc_support_score;
         detail += rc_support_detail + " ";
      }

      if(rc_against_score > 0.5)
      {
         double against_as_component = 1.0 - rc_against_score;
         if(against_as_component < rev_component)
         {
            rev_component = against_as_component;
            detail += rc_against_detail + " ";
         }
      }
   }

   // --- Sense 2: zone quality, blended with historical per-level reliability (weight 2.0) ---
   double zone_component = 0.5;
   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   if(mid > 0.0)
   {
      double relevant_zone = (dir_i > 0) ? ZoneMapNearestSupport(mid) : ZoneMapNearestResistance(mid);
      if(relevant_zone > 0.0)
      {
         double proximity_pts = MathAbs(mid - relevant_zone) / _Point;
         if(proximity_pts <= 300.0)
         {
            // ZoneMapStrength already includes touch-fatigue, age-weighting, FVG cluster and
            // polarity-flip - this pulls in the SEPARATE per-level historical track record too.
            double zstrength = ZoneMapStrength(relevant_zone);
            double reliability = EnableZoneReliability ? ZoneReliabilityScore(relevant_zone) : 0.0;

            if(zstrength >= 1.5)
            {
               zone_component = MathMin(1.0, 0.6 + zstrength * 0.1);
               detail += StringFormat("zone-support(str=%.1f) ", zstrength);
            }

            // reliability is -1..+1 (holds vs breaks) - nudges the component further either way
            zone_component = MathMax(0.0, MathMin(1.0, zone_component + reliability * 0.2));
            if(MathAbs(reliability) > 0.2)
               detail += StringFormat("reliability=%.2f ", reliability);
         }
      }

      // V31.6z28 fix: real, confirmed bug found via live testing - this sense only ever
      // checked the FAVORABLE zone (support for BUY, resistance for SELL), completely blind
      // to the OPPOSING zone right in front of the grid addition. A BUY grid could - and did -
      // add directly into a strong resistance that had JUST rejected price downward, with zero
      // awareness. Mirrors First Entry's Trend Continuation Zone Caution, now applied to grid.
      //
      // V31.6z29 EXTENSION: the near-range check alone (600pts) covers only ~9% of an actual
      // grid step (6500pts+) - completely blind to a MAJOR zone sitting further out but still
      // well within reach of where this grid direction is heading. Adds a second, WIDER tier
      // that only fires for genuinely major levels (much higher strength bar), so it flags
      // real "there's a wall ahead" situations without over-triggering on minor distant zones.
      //
      // V31.6z42 UPGRADE: uses the TF-weighted search (across the FULL far range) instead of
      // pure-nearest - a moderately-strong HTF zone sitting between the near and far tiers
      // (e.g. 1500pts away, strength 1.8 - too far for near-tier, not strong enough for the
      // old far-tier's high bar) used to be invisible to BOTH checks. The weighted search finds
      // the single most SIGNIFICANT candidate in range, not just the closest one.
      double opposing_zone = (dir_i > 0) ?
                             ZoneMapBestWeightedResistance(mid, GridFarZoneCautionPoints) :
                             ZoneMapBestWeightedSupport(mid, GridFarZoneCautionPoints);
      if(opposing_zone > 0.0)
      {
         double opp_proximity_pts = MathAbs(mid - opposing_zone) / _Point;
         double opp_strength = ZoneMapStrength(opposing_zone);

         bool near_danger = (opp_proximity_pts <= GridOpposingZoneCautionPoints && opp_strength >= GridOpposingZoneMinStrength);
         bool far_danger = (EnableGridFarZoneAwareness && !near_danger &&
                            opp_proximity_pts <= GridFarZoneCautionPoints && opp_strength >= GridFarZoneMinStrength);

         if(near_danger || far_danger)
         {
            double penalty_scale = near_danger ? 0.05 : 0.03;
            zone_component = MathMin(zone_component, MathMax(0.05, 0.35 - opp_strength * penalty_scale));
            detail += StringFormat("%s-OPPOSING-ZONE(str=%.1f,%.0fpts) ", near_danger ? "NEAR" : "FAR", opp_strength, opp_proximity_pts);
         }
      }
   }

   // --- Sense 3: multi-TF alignment AGAINST the grid direction (weight 1.5) ---
   // V31.6q fix: was too mild even at unanimous 4/4 agreement (floor 0.4) - four INDEPENDENT
   // timeframes all agreeing is much stronger evidence than a linear scale implies. Now
   // non-linear: near-unanimous agreement is penalized steeply, not proportionally.
   int mtf_against = EnableMTFAlignment ? MTFAlignmentCount(-dir_i) : 0;
   double mtf_component = 1.0;
   if(mtf_against == 4)      mtf_component = 0.15;
   else if(mtf_against == 3) mtf_component = 0.35;
   else if(mtf_against == 2) mtf_component = 0.55;
   else if(mtf_against == 1) mtf_component = 0.80;
   if(mtf_against >= 2)
      detail += StringFormat("MTF %d/4 against ", mtf_against);

   // V31.6z36 UPGRADE: fold in the magnitude-aware MTF Confidence - a binary "3/4 against"
   // read said nothing about whether those 3 timeframes were barely trending or strongly
   // ADX-confirmed. Takes the MORE informative (more extreme) of the binary-count component
   // above and the continuous confidence, in EITHER direction.
   if(EnableMTFConfidence)
   {
      string mtf_conf_detail = "";
      double mtf_conf = MTFAlignmentConfidence(dir_i, mtf_conf_detail);
      double mtf_conf_as_component = 0.5 + mtf_conf * 0.5;
      if(mtf_conf_as_component < mtf_component)
      {
         mtf_component = mtf_conf_as_component;
         detail += mtf_conf_detail + " ";
      }
   }

   // --- Sense 4: Order Flow conviction (weight 1.0) ---
   double flow_component = 0.5;
   if(EnableOrderFlow)
   {
      int flow_sign = OrderFlowConvictionSign(SignalTF, 1);
      double flow_ratio = OrderFlowConvictionRatio(SignalTF, 1);

      // V31.6z37 fix: same binary-vs-magnitude gap found elsewhere - the ratio itself (already
      // computed, already available) was being thrown away in favor of a fixed 0.2/0.8 once
      // the sign qualified. A ratio just barely past the threshold and one far beyond it got
      // treated identically.
      // FIX(orderflow-magnitude): was `flow_sign == -dir_i` / `== dir_i`, which inverted this
      // whole sense for SELL grids - heavy volume scored AGAINST a sell and thin volume FOR it.
      // Magnitude only: thin volume (-1) = weak conviction, heavy volume (+1) = strong.
      if(flow_sign < 0)
      {
         double against_mag = (flow_ratio > 0.0 && OrderFlowLowMultiplier > 0.0) ?
                              MathMax(0.0, MathMin(1.0, (OrderFlowLowMultiplier - flow_ratio) / OrderFlowLowMultiplier)) : 0.0;
         flow_component = MathMax(0.05, 0.30 - against_mag * 0.25);
         detail += StringFormat("orderflow-against(ratio=%.2f) ", flow_ratio);
      }
      else if(flow_sign > 0)
      {
         double for_mag = (flow_ratio > OrderFlowHighMultiplier && OrderFlowHighMultiplier > 0.0) ?
                          MathMin(1.0, (flow_ratio - OrderFlowHighMultiplier) / OrderFlowHighMultiplier) : 0.0;
         flow_component = MathMin(0.95, 0.70 + for_mag * 0.25);
      }
   }

   // --- Sense 5: DXY proxy alignment - gold-specific macro driver (weight 1.0) ---
   double dxy_component = 0.5;
   if(EnableDXYProxy)
   {
      string dxy_reason = "";
      int dxy_dir = DXYProxyDirection(dxy_reason);
      int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;
      double dxy_mag = DXYProxyMagnitude();
      if(price_effect == -dir_i)
      {
         dxy_component = MathMax(0.05, 0.25 - dxy_mag * 0.15);
         detail += StringFormat("dxy-against(mag=%.2f) ", dxy_mag);
      }
      else if(price_effect == dir_i)
      {
         dxy_component = MathMin(0.95, 0.75 + dxy_mag * 0.15);
      }
   }

   // --- Sense 6: Volatility Regime - general market-quality context (weight 0.5) ---
   double vol_component = 0.5;
   if(EnableConfidenceScore)
   {
      double vr = VolatilityRegimeScore();   // -1.0 storm, -0.3 dead, +1.0 normal
      vol_component = (vr + 1.0) / 2.0;
      if(vr < 0.0)
         detail += StringFormat("volRegime=%.1f ", vr);
   }

   // --- Sense 7: Trend Strength (ADX) - catches a strong, SUSTAINED move against grid
   // direction even with no fresh reversal pattern (weight 2.0, same as Reversal/Zone - this
   // was the actual gap live testing exposed: a plain, persistent trend with no "change of
   // character" slipped past Sense 1 silently). ---
   double strength_component = 1.0;
   if(EnableTrendStrength)
   {
      double adverse_strength = TrendStrengthAgainst(dir_i);
      if(adverse_strength > 0.0)
      {
         strength_component = 1.0 - adverse_strength * 0.9;
         if(adverse_strength >= 0.5)
            detail += StringFormat("trendStrength=%.2f ", adverse_strength);
      }
   }

   // --- Sense 8: Recovery Path Zone Search (weight 2.0) - the only FORWARD-LOOKING sense:
   // is there a real waypoint between here and break-even the market is likely to respect? ---
   string recovery_detail = "";
   double recovery_component = RecoveryPathZoneScore(grid_direction, recovery_detail);
   if(StringLen(recovery_detail) > 0)
      detail += recovery_detail;

   // --- Sense 9: Major Sweep Awareness (weight 1.5) - was a strong, zone-confirmed level
   // recently swept and rejected? Agreement with grid direction is reassuring; disagreement
   // (grid direction is the SAME as what just got swept away) is a caution sign. ---
   string sweep_detail = "";
   int sweep_dir = RecentMajorSweepDirection(sweep_detail);
   double sweep_component = 0.5;
   if(sweep_dir != 0)
   {
      if(sweep_dir == dir_i)
         sweep_component = 0.8;
      else
      {
         sweep_component = 0.2;
         detail += sweep_detail;
      }
   }

   // --- Sense 10: Equilibrium / Premium-Discount (weight 1.0) - is price currently in the
   // favorable half of its own recent range for THIS grid direction (Discount for BUY,
   // Premium for SELL), or the unfavorable half (buying/selling "expensive" within its own
   // recent swing)? A different dimension than specific levels - about broad range position. ---
   double range_pos_pct = 50.0;
   int eq_dir = EQZoneBias(range_pos_pct);
   double eq_component = 0.5;
   if(EnableEQZone)
   {
      // V31.6z38 fix: range_position_pct is a genuine continuous 0-100% value, already
      // computed - but only ever used to gate a binary threshold check (0.75/0.25 flat once
      // past the premium/discount line). Sitting at 2% (deep discount) and sitting at 33%
      // (barely past the discount threshold) got scored identically. Uses the actual
      // percentage directly now - how FAR into favorable/unfavorable territory matters.
      double favor = (dir_i > 0) ? (50.0 - range_pos_pct) : (range_pos_pct - 50.0);
      double favor_norm = MathMax(-1.0, MathMin(1.0, favor / 50.0));
      eq_component = 0.5 + favor_norm * 0.45;

      if(eq_dir != 0 && eq_dir != dir_i)
         detail += StringFormat("EQ-unfavorable(%.0f%%) ", range_pos_pct);

      if((EQZonePrintOnUse && VerboseLogs) && eq_dir != 0)
         PrintFormat("[SIRUS v31.6u EQ ZONE] range_position=%.0f%% dir=%d grid_dir=%d", range_pos_pct, eq_dir, dir_i);
   }

   // --- Sense 11: Engulfing Pattern (weight 1.5) - a decisive two-candle control shift,
   // ideally confirmed at a real zone. Agreement with grid direction is reassuring;
   // disagreement (a strong engulfing just formed the OTHER way) is a caution sign. ---
   string engulf_detail = "";
   int engulf_dir = RecentEngulfingDirection(engulf_detail);
   double engulf_component = 0.5;
   if(engulf_dir != 0)
   {
      if(engulf_dir == dir_i)
         engulf_component = 0.8;
      else
      {
         engulf_component = 0.2;
         detail += engulf_detail;
      }
      if((EngulfingPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6v ENGULFING] %s grid_dir=%d", engulf_detail, dir_i);
   }

   // --- Sense 12: Recent Zone Break (weight 2.0 - "premium", same as Reversal/Zone/Strength/
   // Recovery) - a fresh, confirmed break of a strong zone gets prominent weight here rather
   // than being buried inside the background ZoneMapStrength nudge. ---
   string zonebreak_detail = "";
   int zonebreak_dir = RecentZoneBreakDirection(zonebreak_detail);
   double zonebreak_component = 0.5;
   if(zonebreak_dir != 0)
   {
      if(zonebreak_dir == dir_i)
         zonebreak_component = 0.85;
      else
      {
         zonebreak_component = 0.15;
         detail += zonebreak_detail;
      }
      if((ZoneBreakPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6z10 ZONE BREAK] %s grid_dir=%d", zonebreak_detail, dir_i);
   }

   // --- Sense 13: Exhaustion Consensus (weight 2.0, "premium") - UPGRADED from single-signal
   // Impulse Exhaustion to the full, unified, non-linear consensus (ADX slope, RSI cooling,
   // candle-level exhaustion, DXY deceleration, basket DD acceleration). Takes the MORE
   // concerning of the immediate candle-level signal and the broader multi-signal consensus -
   // either one firing strongly is real evidence, and both firing together is compounding. ---
   string exhaust_detail = "";
   double exhaust_score = ImpulseExhaustionWarning(dir_i, exhaust_detail);
   string consensus_exhaust_detail = "";
   double consensus_exhaust_score = ExhaustionConsensusScore(dir_i, consensus_exhaust_detail);
   double exhaust_component = MathMin(exhaust_score, consensus_exhaust_score);
   if(exhaust_score <= 0.3)
   {
      detail += exhaust_detail;
      if((ImpulseExhaustionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6z19 IMPULSE EXHAUSTION] %s grid_dir=%d", exhaust_detail, dir_i);
   }
   if(consensus_exhaust_score < 0.5)
   {
      detail += consensus_exhaust_detail;
      if((ImpulseExhaustionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6z22 EXHAUSTION CONSENSUS] %s grid_dir=%d", consensus_exhaust_detail, dir_i);
   }

   // --- Sense 14: Structure/HTF Confluence (weight 1.5) - V31.6z27 UNIFICATION. Folds in the
   // genuinely independent signal sources that Adaptive Recovery Intelligence (DRI) was
   // separately, redundantly multiplying into grid distance/lot: BOS/CHoCH structure breaks,
   // higher-timeframe direction (Legacy Deep Parity), and Top Zone Trap danger. These are real,
   // different detectors than our swing/RSI Trend Reversal sense - genuinely additive
   // evidence, not duplicate signal, now properly weighted INSIDE the consensus instead of
   // multiplying blindly outside it. ---
   int struct_against_count = 0;
   string struct_detail = "";
   if(EnableStructureConfluence)
   {
      if((dir_i > 0 && G_DBOS_DIR < 0) || (dir_i < 0 && G_DBOS_DIR > 0))
      {
         struct_against_count++;
         struct_detail += "BOS/CHoCH-against ";
      }
      if((dir_i > 0 && G_DLP_HTF_DIR < 0) || (dir_i < 0 && G_DLP_HTF_DIR > 0))
      {
         struct_against_count++;
         struct_detail += "HTF-against ";
      }
      if((dir_i > 0 && G_DTZ_TOP_DANGER) || (dir_i < 0 && G_DTZ_BOTTOM_DANGER))
      {
         struct_against_count++;
         struct_detail += "ZoneTrap-danger ";
      }
   }
   double struct_component = 0.5;
   if(struct_against_count == 1)
   {
      struct_component = 0.35;
      detail += struct_detail;
   }
   else if(struct_against_count == 2)
   {
      // V31.6z38 fix: was a plain linear formula (0.5 - count*0.15) capped by a floor - too
      // mild for genuine multi-signal agreement. Two INDEPENDENT structural signals (e.g.
      // BOS/CHoCH AND a Top Zone Trap) confirming together is disproportionately stronger
      // evidence than either alone, matching the non-linear consensus philosophy used
      // throughout today's session rather than a flat per-vote deduction.
      struct_component = 0.18;
      detail += struct_detail + "STRUCT-CONSENSUS(2) ";
   }
   else if(struct_against_count >= 3)
   {
      struct_component = 0.08;
      detail += struct_detail + "STRUCT-CONSENSUS(3) ";
   }

   // --- Sense 15: Basket DD Stretch (weight 1.5) - V31.6z27 UNIFICATION. The one genuinely
   // non-redundant signal from DRI: how far into drawdown this SPECIFIC basket already is,
   // relative to its own stretch threshold - distinct from DD Acceleration (which measures the
   // RATE of change, not the absolute level). ---
   double dd_stretch_component = 0.5;
   if(EnableBasketDDStretch && G_BASKET_ORDERS > 0)
   {
      double stretch_hard = MathMax(DeepRecoveryDDHardCaution, DeepRecoveryDDStretchStart + 0.1);
      if(G_BASKET_DD_PERCENT >= DeepRecoveryDDStretchStart)
      {
         double stretch_ratio = MathMax(0.0, MathMin(1.5, G_BASKET_DD_PERCENT / stretch_hard));
         dd_stretch_component = MathMax(0.1, 0.5 - MathMin(1.0, stretch_ratio) * 0.4);
         detail += StringFormat("DD-stretch(%.1f%%) ", G_BASKET_DD_PERCENT);
      }
   }

   // --- Sense 16: Global vs Local Trend Alignment (weight 2.5, the HEAVIEST sense) - direct
   // user request. Grid additions that align with the GLOBAL (H4/D1) trend have real
   // structural odds of being pulled back toward break-even even after an adverse local move;
   // additions that fight the global trend are exactly what leaves a basket stuck in DD with
   // no underlying current working in its favor. This is the single most direct lever for
   // shortening DD duration of anything in the whole system. ---
   string gla_detail = "";
   double gla_component = GlobalLocalAlignmentScore(dir_i, gla_detail);
   if(gla_component <= 0.35 || gla_component >= 0.65)
   {
      detail += gla_detail + " ";
      if((GlobalLocalPrintOnUse && VerboseLogs) && gla_component <= 0.35)
         PrintFormat("[SIRUS v31.6z30 GLOBAL/LOCAL] %s grid_dir=%d", gla_detail, dir_i);
   }

   double total_weight = 2.0 + 2.0 + 1.5 + 1.0 + 1.0 + 0.5 + 2.0 + 2.0 + 1.5 + 1.0 + 1.5 + 2.0 + 2.0 + 1.5 + 1.5 + 2.5;
   double weighted_avg = (rev_component * 2.0 + zone_component * 2.0 + mtf_component * 1.5 +
                          flow_component * 1.0 + dxy_component * 1.0 + vol_component * 0.5 +
                          strength_component * 2.0 + recovery_component * 2.0 +
                          sweep_component * 1.5 + eq_component * 1.0 +
                          engulf_component * 1.5 + zonebreak_component * 2.0 +
                          exhaust_component * 2.0 + struct_component * 1.5 +
                          dd_stretch_component * 1.5 + gla_component * 2.5) / total_weight;

   // V31.6o NEW: Consensus/Conflict - a hunter doesn't just average conflicting signs. Genuine
   // agreement across INDEPENDENT senses is stronger evidence than the sum of parts; genuine
   // disagreement (some senses strongly for, others strongly against) is itself a danger sign -
   // ambiguous ground, not a place to commit more capital. Averaging alone hides both effects.
   double components[16] = {rev_component, zone_component, mtf_component, flow_component, dxy_component, vol_component, strength_component, recovery_component, sweep_component, eq_component, engulf_component, zonebreak_component, exhaust_component, struct_component, dd_stretch_component, gla_component};
   int strong_favorable = 0, strong_unfavorable = 0;
   for(int ci = 0; ci < 16; ci++)
   {
      if(components[ci] >= 0.65) strong_favorable++;
      if(components[ci] <= 0.35) strong_unfavorable++;
   }

   double consensus_adj = 0.0;

   // V31.6z67 fix: the same flaw just corrected in First Entry's Brain Consensus, present here
   // too in a subtler form. The bonus branch only ever asked "do enough senses agree?" - it
   // never asked "and do few enough disagree?". With 16 senses, a read of 10 favourable AND 6
   // strongly UNFAVOURABLE fell through branch 1 (6 < 9), hit branch 2 (10 >= 10) and collected
   // a full synergy BONUS - while the conflicted-signals branch below, which exists precisely
   // for that case, was never reached because it sat behind the `else`. Six senses shouting
   // "don't" were rewarded as agreement. A consensus bonus must require BOTH sides of the
   // condition: broad agreement AND little genuine opposition.
   if(strong_unfavorable >= 9)
   {
      consensus_adj = -GridIntelligenceConsensusWeight * (strong_unfavorable - 8);
      detail += StringFormat("consensus-against(%d) ", strong_unfavorable);
   }
   else if(strong_favorable >= 10 && strong_unfavorable <= GridIntelligenceConsensusMaxOpposed)
   {
      consensus_adj = GridIntelligenceConsensusWeight * 0.6 * (strong_favorable - 9);
      detail += StringFormat("consensus-for(%d,opposed=%d) ", strong_favorable, strong_unfavorable);
   }
   else if(strong_favorable >= 2 && strong_unfavorable >= 2)
   {
      consensus_adj = -GridIntelligenceConflictPenalty;
      detail += StringFormat("conflicted-signals(%d for vs %d against) ", strong_favorable, strong_unfavorable);
   }

   double score = weighted_avg + consensus_adj;
   return MathMax(0.0, MathMin(1.0, score));
}

// V31.6w speed fix: this whole 11-sense computation was being run TWICE per grid cycle
// (once from GridIntelligenceAllowsGrid, once from GridIntelligenceLotAdjust) with zero
// caching - same "recompute every call instead of once per bar" pattern already fixed for
// ADR/DXY/TrendReversal earlier, just reintroduced by all the sense additions since then.
double GridIntelligenceScore(const long grid_direction, string &detail)
{
   static int    gi_cache_bar    = -1;
   static long   gi_cache_dir    = 0;
   static double gi_cache_score  = 0.5;
   static string gi_cache_detail = "";
   if(gi_cache_bar > G_BARS_SEEN) gi_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(gi_cache_bar != G_BARS_SEEN || gi_cache_dir != grid_direction)
   {
      gi_cache_score = GridIntelligenceScoreRaw(grid_direction, gi_cache_detail);
      gi_cache_bar = G_BARS_SEEN;
      gi_cache_dir = grid_direction;
   }

   detail = gi_cache_detail;
   return gi_cache_score;
}

// V31.6z59 fix: a regression I introduced in z27 and caught in this sweep. Before that change,
// DeepRecoveryAdjustGridDistance (DRI) and RegimeTuneAdjustGridDistance (DRT) widened the grid
// step when conditions were poor. I disconnected both - correctly, since they were redundant
// and mutually unaware - but replaced them for LOT only. Grid DISTANCE was left with ZERO
// condition awareness: purely base x order-count x ATR x session, identical whether every sense
// screamed danger or all agreed it was a great spot.
//
// That matters: when the 16-sense score is poor, the right response isn't only "add a smaller
// lot" - it's also "wait for a better price before adding at all". This restores that behaviour
// under the SAME unified brain that already governs lot and the block decision, so there's one
// coherent source of judgement rather than three arguing ones.
double GridIntelligenceDistanceAdjust(const double dist, const long direction, const int current_orders)
{
   if(!EnableGridIntelligence || !EnableGridIntelligenceDistance)
      return dist;

   string detail = "";
   double gscore = GridIntelligenceScore(direction, detail);

   // Only widen on genuinely poor scores. A good score does NOT tighten the grid - tightening
   // would mean committing capital faster on optimism, which is exactly the wrong asymmetry
   // for a recovery mechanism.
   if(gscore >= 0.5)
      return dist;

   double widen = 1.0 + (0.5 - gscore) * 2.0 * MathMax(0.0, GridIntelligenceMaxDistanceWiden - 1.0);
   double out = dist * widen;

   if((GridIntelligencePrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6z59 GRID DISTANCE] score=%.2f -> widen x%.2f (%.0f -> %.0f pts)",
                  gscore, widen, dist, out);

   return out;
}

double GridIntelligenceLotAdjust(const double lot, const long direction, const int current_orders)
{
   if(!EnableGridIntelligence)
      return lot;

   string detail = "";
   double gscore = GridIntelligenceScore(direction, detail);

   // V31.6o NEW: depth-aware floor - a hunter's later shots, deeper into an already-risky
   // basket, get less benefit of the doubt even at the same score. The floor itself tightens.
   // V249fix(auto-mode): was `/ 6.0`, hard-coded for the old MaxOrders 7. At MaxOrders 5 this
   // peaked at 0.833, so the 16-sense grid brain ran at ~83% of its configured strictness exactly
   // at the deepest, most dangerous rung - the same class as the AdaptiveAlignFullShiftOrders
   // 6->5 fix. Derived from MaxOrders now, so it tracks the setting instead of a number that
   // merely used to match it.
   double depth_factor = MathMin(1.0, (double)MathMax(0, current_orders) / (double)MathMax(2, MaxOrders - 1));
   double min_factor = GridIntelligenceMinLotFactor * (1.0 - depth_factor * 0.5);

   // V31.6z35 fix: real, confirmed problem found via live testing ("maydalashib ketyapti" -
   // every grid addition collapsing to roughly the same small size). The old linear formula
   // (factor = min_factor + gscore*(1-min_factor)) cut lot by ~43% even at a completely
   // NEUTRAL score (0.5) - with 6+ more multiplicative factors in the chain, this all but
   // guaranteed hitting the overall 50% safety floor on almost every single addition,
   // regardless of whether conditions were genuinely good or bad. Lot sizing lost its
   // informative value - a great setup and a mediocre one ended up the same tiny size.
   // Redesigned so NEUTRAL stays close to full lot (only genuinely bad scores get cut hard):
   double neutral_factor = GridIntelligenceNeutralLotFactor;
   double factor;
   if(gscore >= 0.5)
      factor = neutral_factor + (gscore - 0.5) * 2.0 * (1.0 - neutral_factor);
   else
      factor = min_factor + (gscore / 0.5) * (neutral_factor - min_factor);

   if((GridIntelligencePrintOnUse && VerboseLogs) && gscore < 0.5)
      PrintFormat("[SIRUS v31.6o GRID INTELLIGENCE] score=%.2f depth=%d (%s)-> lot x%.2f", gscore, current_orders, detail, factor);

   return lot * factor;
}

bool GridIntelligenceAllowsGrid(const long direction, const int current_orders, string &reason)
{
   if(!EnableGridIntelligence)
   {
      reason = "grid intelligence off";
      return true;
   }

   string detail = "";
   double gscore = GridIntelligenceScore(direction, detail);

   // V31.6o NEW: depth-aware threshold - the bar to justify a NEW addition rises as the hunt
   // gets deeper. Order 2 can pass at the base threshold; order 7 needs meaningfully more.
   // V31.6z NEW: if the basket OPENED from a reversal-type signal (Sweep/FBR/Near-Zone/
   // Exhaustion/Range Edge) that has since proven wrong, the threshold rises FASTER with
   // depth than for a continuation-opened basket - being wrong on a reversal bet is more
   // likely to mean a real, ongoing trend, the single most dangerous scenario for grid.
   double depth_boost = GridIntelligenceDepthThresholdBoost;
   if(EnableReversalRiskDifferentiation && IsReversalOpportunityType((ENUM_OPPORTUNITY_TYPE)G_BASKET_OPENING_TYPE))
      depth_boost *= MathMax(1.0, ReversalTypeDepthBoostMultiplier);

   // V31.6z20 NEW: Basket's Own Track Record - if THIS basket's own recent grid additions
   // have shown zero sign of working (no intervening recovery, streak building), raise the
   // bar further still. This is direct, basket-specific evidence distinct from the purely
   // mechanical order-count depth boost above.
   if(EnableBasketAdverseStreakCheck && G_BASKET_ADVERSE_STREAK >= BasketAdverseStreakMinCount)
      depth_boost *= MathMax(1.0, BasketAdverseStreakBoostMultiplier);

   // V31.6z21 NEW: DD Acceleration - if the basket's drawdown is worsening at a FASTER rate
   // than before (not just worsening, but accelerating), that's a genuinely different, more
   // dangerous situation than a slow, steady DD climb - raise the bar further.
   string dd_accel_detail = "";
   double dd_accel = BasketDDAccelerationFactor(dd_accel_detail);
   if(dd_accel > 0.0)
   {
      depth_boost *= MathMax(1.0, 1.0 + dd_accel * (BasketDDAccelBoostMultiplier - 1.0));
      detail += dd_accel_detail;
   }

   // V249fix(auto-mode): was `/ 6.0`, hard-coded for the old MaxOrders 7. At MaxOrders 5 this
   // peaked at 0.833, so the 16-sense grid brain ran at ~83% of its configured strictness exactly
   // at the deepest, most dangerous rung - the same class as the AdaptiveAlignFullShiftOrders
   // 6->5 fix. Derived from MaxOrders now, so it tracks the setting instead of a number that
   // merely used to match it.
   double depth_factor = MathMin(1.0, (double)MathMax(0, current_orders) / (double)MathMax(2, MaxOrders - 1));
   double adaptive_threshold = GridIntelligenceHardBlockBelow + depth_factor * depth_boost;

   // V31.6z68 fix: the boosts above are MULTIPLICATIVE and unbounded - reversal-opened (x1.5),
   // adverse streak (x1.5) and DD accelerating (up to x1.6) compound to x3.6, pushing the
   // threshold to ~1.38 at order 6. But GridIntelligenceScore is clamped to a 0-1 range, so a
   // threshold above 1.0 is unreachable BY CONSTRUCTION: no score can ever pass, and the whole
   // 16-sense system silently degrades into a plain hard block. The log made this baffling too -
   // "score 0.85 below threshold 1.38" reads like a rejection when 0.85 is actually an
   // excellent read. Capping keeps the score meaningful: conditions can demand a near-perfect
   // read, but never an impossible one.
   if(adaptive_threshold > GridIntelligenceMaxThreshold)
   {
      detail += StringFormat("threshold capped %.2f->%.2f ", adaptive_threshold, GridIntelligenceMaxThreshold);
      adaptive_threshold = GridIntelligenceMaxThreshold;
   }

   if(gscore < adaptive_threshold)
   {
      reason = StringFormat("grid intelligence score %.2f below depth-adjusted threshold %.2f (order %d, %s)",
                            gscore, adaptive_threshold, current_orders + 1, detail);
      return false;
   }

   reason = StringFormat("grid intelligence score %.2f", gscore);
   return true;
}

// V31.6k new: Duplicate Instance detection. A completely different risk dimension - not
// market risk, but the same EA (same Magic+Symbol) accidentally running twice on the same
// terminal (two chart windows, or forgetting one is already attached). Both would think they
// own the same basket and could send conflicting orders. WARNING-ONLY by design: a hard block
// would false-positive on every normal restart (GlobalVariables persist across EA reloads),
// which would be more disruptive than the rare real duplicate going unblocked for one cycle.
void DuplicateInstanceCheck()
{
   if(!EnableDuplicateInstanceGuard)
      return;

   string key = StringFormat("NAVIUS_%I64d_%s_HEARTBEAT", MagicNumber, _Symbol);
   datetime now = TimeCurrent();

   if(!G_DUP_INSTANCE_WARNED && GlobalVariableCheck(key))
   {
      datetime last_beat = (datetime)GlobalVariableGet(key);
      int age_sec = (int)(now - last_beat);

      if(age_sec >= 0 && age_sec < MathMax(1, DuplicateInstanceStaleSeconds))
      {
         G_DUP_INSTANCE_WARNED = true;
         if((DuplicateInstancePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6k DUPLICATE GUARD] WARNING: another active instance's heartbeat is only %d sec old for Magic=%I64d Symbol=%s - check you don't have this EA attached twice (conflicting orders risk). This does NOT block trading.",
                        age_sec, MagicNumber, _Symbol);
      }
   }

   static datetime last_beat_sent = 0;
   if(now - last_beat_sent >= MathMax(1, DuplicateInstanceHeartbeatSeconds))
   {
      GlobalVariableSet(key, (double)now);
      last_beat_sent = now;
   }
}

bool BasketExposureAllowsGrid(const double next_lot, const ENUM_ORDER_TYPE order_type, string &reason)
{
   if(!EnableMaxBasketExposure)
   {
      reason = "exposure cap disabled";
      return true;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
   {
      reason = "exposure cap: equity unreadable";
      return true;
   }

   double price = (order_type == ORDER_TYPE_BUY) ?
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double used_margin = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double pvol = PositionGetDouble(POSITION_VOLUME);
      double pprice = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_ORDER_TYPE ptype = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                              ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double pmargin = 0.0;
      if(OrderCalcMargin(ptype, _Symbol, pvol, pprice, pmargin))
         used_margin += pmargin;
   }

   double next_margin = 0.0;
   if(!OrderCalcMargin(order_type, _Symbol, next_lot, price, next_margin))
      next_margin = 0.0;

   double total_margin = used_margin + next_margin;
   double cap = equity * MaxBasketMarginPercent / 100.0;

   if(total_margin > cap)
   {
      reason = StringFormat("basket exposure %.2f/%.2f margin (%.0f%% of equity %.2f)",
                            total_margin, cap, MaxBasketMarginPercent, equity);
      if((MaxBasketExposurePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6e EXPOSURE CAP] blocked: %s", reason);
      return false;
   }

   reason = "exposure ok";
   return true;
}

double GridDistanceForNextOrder(const int current_orders)
{
   double dist = AutoGridBaseDistance();
   double mult = AutoGridMultiplier();

   if(mult > 0.0 && current_orders > 1)
      dist *= MathPow(mult, current_orders - 1);

   if(AdaptiveGridDistance)
   {
      double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
      double atr_mult = AutoGridATRMult();

      if(atr > 0.0)
         dist = MathMax(dist, atr * atr_mult);
   }

   // V30.1 new: ATR REGIME scaling - old AdaptiveGridDistance only WIDENED (MathMax floor).
   // This scales BOTH ways: quiet market -> tighter grid, volatile market -> wider grid.
   // ratio = fast ATR / slow baseline ATR, clamped to [MinScale, MaxScale].
   if(EnableATRRegimeGrid)
   {
      double atr_fast = ATRPointsManual(SignalTF, ATRPeriod, 1);
      double atr_base = ATRPointsManual(SignalTF, MathMax(ATRPeriod + 1, ATRRegimeBasePeriod), 1);

      if(atr_fast > 0.0 && atr_base > 0.0)
      {
         double scale = atr_fast / atr_base;
         double lo = (ATRRegimeMinScale > 0.0 ? ATRRegimeMinScale : 0.5);
         double hi = (ATRRegimeMaxScale > lo ? ATRRegimeMaxScale : lo * 2.0);
         if(scale < lo) scale = lo;
         if(scale > hi) scale = hi;

         dist *= scale;

         if((ATRRegimePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v30.1 ATR REGIME] fast=%.0f base=%.0f scale=%.2f -> dist=%.0f",
                        atr_fast, atr_base, scale, dist);
      }
   }

   // V31.6e new: session-adaptive scaling - tighter grid in typically quiet Asia hours,
   // wider in typically more volatile London/NY hours. Applied before the final min/max
   // clamp so the absolute floor/ceiling safety bounds still hold either way.
   if(EnableSessionGridDistance)
   {
      double session_factor = SessionGridDistanceFactor();
      if(session_factor != 1.0)
      {
         dist *= session_factor;
         if((SessionGridPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6e SESSION GRID] factor=%.2f -> dist=%.0f", session_factor, dist);
      }
   }

   double min_dist = AutoGridMinDistance();
   double max_dist = AutoGridMaxDistance();

   if(min_dist > 0.0)
      dist = MathMax(dist, min_dist);

   if(max_dist > 0.0)
      dist = MathMin(dist, max_dist);

   dist = Pack2GridDistanceAdjust(dist);
   dist = Pack3AdaptGridDistance(dist);

   // V31.6z27 UNIFICATION: DeepRecoveryAdjustGridDistance (DRI) and RegimeTuneAdjustGridDistance
   // (DRT) used to multiply distance here INDEPENDENTLY of Grid Intelligence, based on largely
   // the same DD/trend/regime criteria - three parallel, mutually-unaware systems compounding
   // blindly. Their genuinely non-redundant signals now live inside Grid Intelligence as Senses
   // 14-15 instead. Disconnected here to stop the double-counting; their tracking/dashboard
   // code is untouched, only this direct multiplication is removed.
   // dist = DeepRecoveryAdjustGridDistance(dist);
   // dist = RegimeTuneAdjustGridDistance(dist);

   // V31.6z59 fix: restores condition-awareness to grid DISTANCE, which the z27 unification
   // above removed without replacement (lot got a replacement, distance did not). Now driven by
   // the same unified 16-sense brain that governs lot and the block decision.
   dist = GridIntelligenceDistanceAdjust(dist, G_BASKET_DIRECTION, current_orders);

   dist = ClientSafetyAdjustGridDistance(dist);
   dist = PresetHardeningAdjustGridDistance(dist);

   // V31.6z27 fix: a real architectural gap found via deeper audit - the min/max safety clamp
   // above ran BEFORE several later adjustments (Pack2/3, ClientSafety, PresetHardening), so
   // those could push distance beyond the intended bounds with zero final check. Re-applying
   // the clamp here guarantees the bounds actually hold no matter what ran in between.
   if(min_dist > 0.0)
      dist = MathMax(dist, min_dist);
   if(max_dist > 0.0)
      dist = MathMin(dist, max_dist);

   return dist;
}

// V161: a scale-in completion is part of the FIRST entry, not a grid addition. Without this the
// ladder would treat it as order two - shrinking every subsequent lot (the multiplier would compound
// from the half-size first part) and widening every subsequent distance. The position count the grid
// reasons about must exclude completions.
int EffectiveGridOrders(const int raw_orders)
{
   int eff = raw_orders - G_SCALEIN_EXTRA_ORDERS;
   return MathMax(1, eff);
}

// The lot the ladder should multiply from: the first entry's FULL intended size, even if it was
// filled in two parts.
double EffectiveLastLot(const double last_lot, const int raw_orders)
{
   if(G_SCALEIN_EXTRA_ORDERS > 0 && raw_orders <= (1 + G_SCALEIN_EXTRA_ORDERS))
   {
      double vol = 0.0, avg = 0.0, profit = 0.0, last_price = 0.0, last_lot_x = 0.0;
      int orders = 0;
      long direction = 0;
      datetime last_time = 0;
      if(GetNaviusBasketStats(orders, vol, avg, profit, direction, last_price, last_lot_x, last_time) && vol > 0.0)
         return vol;      // the combined first entry
   }
   return last_lot;
}

bool   G_GRID_LOT_CAUTION_FLOORED = false;   // last NextGridLot(): soft cautions wanted less than the floor
double G_GRID_LOT_SOFT_FACTOR     = 1.0;     // last NextGridLot(): combined soft caution factor vs target
int    G_GCH_ORDERS               = -1;      // caution hold: rung (order count) being held
int    G_GCH_BASKET_BAR           = -1;      // caution hold: basket it belongs to (G_BASKET_OPEN_BAR)
int    G_GCH_START_BAR            = 0;       // caution hold: bar the hold began

double NextGridLot(const double last_lot, const int current_orders)
{
   double lot = last_lot;

   if(lot <= 0.0)
      lot = StartLot;

   // V31.6p fix: save the "pure" LotMultiplier target BEFORE any caution is applied, so we
   // can floor the final result relative to it below - this is the fix for a real bug found
   // via live testing: stacking many independent caution multipliers (9 of them by now) could
   // crush the lot far below what LotMultiplier's compounding was meant to produce, breaking
   // the averaging-down math the whole grid recovery strategy depends on.
   double pure_multiplier_target = lot;
   // V241: the shape's multiplier, which is the setting unless a shape was chosen. A ladder built to
   // survive a trend grows more slowly, because it may need more rungs to get where it is going.
   double eff_mult = LadderMultiplier();
   if(eff_mult > 0.0)
   {
      pure_multiplier_target = lot * eff_mult;
      lot = pure_multiplier_target;
   }

   if(MaxLot > 0.0 && lot > MaxLot)
   {
      lot = MaxLot;
      pure_multiplier_target = MathMin(pure_multiplier_target, MaxLot);
   }

   // FIX(martingale-floor-override): the lot adjustments are two different kinds of thing, and the
   // floor below used to override both:
   //   HARD limits - the client lot cap (Pack4Mini), the client-safety throttle, preset hardening and
   //                 the margin-level guard. These are account protection; nothing may undo them.
   //   SOFT opinions - impulse/correction, spread vs ATR, grid intelligence, addition quality. These
   //                 are the market read; they may trim an addition, down to the floor.
   // Before, all of them ran first and the floor then lifted the result back to >= 80% of the
   // martingale progression - so a margin-level or client-cap cut was silently reversed. Now the soft
   // opinions run, the floor protects the averaging math against them only, and the hard limits are
   // applied LAST. When the soft opinions want an addition smaller than the floor, the result is
   // flagged (G_GRID_LOT_CAUTION_FLOORED) and GridCanOpen() holds that rung for a while instead of
   // forcing a near-full-size add into conditions every caution module disagrees with.
   // V31.6z27 UNIFICATION: DRI/DRT's lot reduction stays disconnected (double-counted Grid Intelligence).
   double soft_target = lot;

   // V31.6l fix: grid previously bypassed ALL of the newer trend/reversal-aware caution
   // built this session - it used its own separate formula, never touching
   // SwingImpulseCorrectionLotAdjust or the other lot-pipeline modules. That's exactly the
   // gap that let a grid keep adding INTO a strengthening reversal with no extra caution.
   // G_BASKET_DIRECTION is BUY/SELL for an existing basket, matching ENUM_ORDER_TYPE values.
   ENUM_ORDER_TYPE grid_dir_type = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   lot = SwingImpulseCorrectionLotAdjust(lot, grid_dir_type);
   lot = SpreadATRQualityLotAdjust(lot);
   lot = GridIntelligenceLotAdjust(lot, G_BASKET_DIRECTION, current_orders);

   // V222: and how good is this particular addition? The ladder multiplies by a fixed amount
   // regardless of where the addition lands, so the largest commitment of the basket goes in at the
   // deepest point of the drawdown with no reading of whether that price is worth defending. Size
   // still grows - the recovery depends on it - but it grows more where there is something to add
   // against and less where there is not.
   if(EnableGridQualityLot)
   {
      int    gq_dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
      double gq_price = (G_NEXT_GRID_PRICE > 0.0) ? G_NEXT_GRID_PRICE
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      string gq_detail = "";
      double gq_f = GridAdditionQuality(gq_dir, gq_price, gq_detail);
      if(gq_f > 0.0 && MathAbs(gq_f - 1.0) > 0.01)
      {
         lot *= gq_f;
         if((GridQualityPrintOnUse && VerboseLogs) && StringLen(gq_detail) > 0)
            PrintFormat("[SIRUS v222 GRID LOT] %s", gq_detail);
      }
   }   // V31.6o: continuous multi-sense + depth-aware scaling

   // V31.6p fix: floor the combined result relative to the pure LotMultiplier target. Caution
   // can still trim a grid addition significantly (down to MinGridLotFactor of the intended
   // size) but can never neuter it entirely - the recovery math still gets a meaningful step.
   //
   // V31.6z52 fix: real root cause of the user's "lot maydalashib ketyapti" report. The floor
   // above is computed from `pure_multiplier_target`, which itself derives from `last_lot` -
   // the PREVIOUS order's ALREADY-REDUCED size. So every reduction compounded into the next
   // order's baseline, and the floor drifted down right along with it, never catching the
   // cumulative drift. Worked example at StartLot=0.25 / LotMultiplier=1.3:
   //     intended:  0.25 -> 0.33 -> 0.42 -> 0.55 -> 0.71 -> 0.93 -> 1.21
   //     actual:    0.25 -> 0.28 -> 0.31 -> 0.34 -> 0.37 -> 0.41 -> 0.46   (~38% of intent)
   // and with the pre-z35 neutral factor it was far worse - lots SHRANK every step.
   // This adds an ABSOLUTE floor anchored to what the martingale progression was actually
   // configured to produce from StartLot, which cannot drift because it never references the
   // reduced chain at all.
   double floor_lot = pure_multiplier_target * MathMax(0.05, MathMin(1.0, MinGridLotFactor));

   // V31.6z62 fix: user-reported and confirmed by the math - StartLot 0.25 opened a 0.18 first
   // entry (normal, within MinFirstEntryLotFactor), but the grid then added 0.15: SMALLER than
   // the order it was supposed to be averaging down. That inverts the whole point of
   // LotMultiplier. Worked example - basket 0.18 @ 4087, price 4020:
   //     add 0.15  -> new average 4056.5
   //     add 0.234 -> new average 4049.1   (the intended 1.3x step)
   // The undersized addition takes on FULL new risk (a whole extra position, margin, exposure)
   // while barely improving the escape price - the worst of both worlds. If conditions are bad
   // enough to want an addition this small, the honest answer is to not add at all, and
   // GridCanOpen already handles that decision separately. So: once grid HAS decided to add,
   // the step must be at least as large as the order before it.
   if(EnableGridNeverBelowPrevious && last_lot > 0.0 && last_lot > floor_lot)
      floor_lot = last_lot;

   if(EnableAbsoluteGridLotFloor && LotMultiplier > 0.0 && StartLot > 0.0)
   {
      double intended_progression = StartLot * MathPow(LotMultiplier, MathMax(0, current_orders));
      if(MaxLot > 0.0)
         intended_progression = MathMin(intended_progression, MaxLot);

      double absolute_floor = intended_progression * MathMax(0.05, MathMin(1.0, AbsoluteGridLotFloorFactor));
      if(absolute_floor > floor_lot)
         floor_lot = absolute_floor;
   }

   G_GRID_LOT_SOFT_FACTOR = (soft_target > 0.0) ? (lot / soft_target) : 1.0;
   G_GRID_LOT_CAUTION_FLOORED = (lot < floor_lot * 0.99);

   if(lot < floor_lot)
   {
      if((GridIntelligencePrintOnUse && VerboseLogs) && lot < floor_lot * 0.99)
         PrintFormat("[SIRUS v31.6z52 GRID LOT FLOOR] combined caution would have cut to %.2f - floored to %.2f (orders=%d, LotMultiplier target %.2f)",
                     lot, floor_lot, current_orders, pure_multiplier_target);
      lot = floor_lot;
   }

   // Hard limits last - the floor cannot undo account protection.
   lot = Pack4MiniAdjustLot(lot, true);
   lot = ClientSafetyAdjustGridLot(lot);
   lot = PresetHardeningAdjustGridLot(lot);
   lot = MarginLevelLotAdjust(lot);

   if(MaxLot > 0.0 && lot > MaxLot)
      lot = MaxLot;

   return NormalizeVolumeSafe(lot);
}

bool IsGridAdverseMove(const long direction, const double last_price, const double distance, double &next_price)
{
   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);

   next_price = 0.0;

   if(direction == POSITION_TYPE_BUY)
   {
      next_price = last_price - distance * _Point;
      return (bid <= next_price);
   }

   if(direction == POSITION_TYPE_SELL)
   {
      next_price = last_price + distance * _Point;
      return (ask >= next_price);
   }

   return false;
}

// FEATURE(grid-reaction): true when price is reacting off a strong opposing wall right now, so an
// early grid add is justified. "Opposing wall" = the wall price is running INTO as it moves
// against the basket: a SELL basket loses as price rises, so its opposing wall is RESISTANCE
// above; a BUY basket loses as price falls, so its opposing wall is SUPPORT below. A valid
// reaction needs three things (variant B standard, on M15):
//   1. a strong wall (ZoneMapStrength >= GridReactionMinWallStrength) within proximity,
//   2. the last closed M15 candle poked that wall with its wick but closed back on our side,
//   3. that rejection wick is a real fraction of the candle's range.
// Returns false safely on any missing/invalid data - callers then just use the full distance.
bool GridReactionAtWall(const long direction, string &why)
{
   why = "";
   if(!EnableGridReactionPreference)
      return false;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
      return false;

   double proximity = MathMax(1, GridReactionWallProximityPts) * _Point;
   double wall = 0.0;

   if(direction == POSITION_TYPE_SELL)
      wall = ZoneMapNearestResistance(price);   // resistance above threatens a SELL basket
   else if(direction == POSITION_TYPE_BUY)
      wall = ZoneMapNearestSupport(price);      // support below threatens a BUY basket
   else
      return false;

   if(wall <= 0.0)
      return false;

   if(PointsBetween(price, wall) > (double)MathMax(1, GridReactionWallProximityPts))
   {
      why = "no wall in proximity";
      return false;
   }

   double strength = ZoneMapStrength(wall);
   if(strength < GridReactionMinWallStrength)
   {
      why = StringFormat("wall too weak %.2f/%.2f", strength, GridReactionMinWallStrength);
      return false;
   }

   // M15 rejection candle + wick check, mirroring the sweep standard.
   double o1 = CandleOpen(PERIOD_M15, 1);
   double c1 = CandleClose(PERIOD_M15, 1);
   double h1 = CandleHigh(PERIOD_M15, 1);
   double l1 = CandleLow(PERIOD_M15, 1);
   double range = CandleRangePoints(PERIOD_M15, 1);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || range <= 0.0)
      return false;

   if(direction == POSITION_TYPE_SELL)
   {
      // Poked resistance with the high, closed back below it, with a real upper wick.
      bool poked   = (h1 >= wall - proximity);
      bool closed_below = (c1 < wall);
      double upper_wick = UpperWickPoints(PERIOD_M15, 1);
      bool wick_ok = ((upper_wick / range) >= GridReactionWickRatioMin);
      if(poked && closed_below && wick_ok)
      {
         // FEATURE(grid-reaction-consensus): the candle rejected - now require a 2+ signal
         // BEARISH reversal consensus (price should turn DOWN to help the SELL basket). One
         // candle alone is not enough. direction -1 = looking for a downward reversal.
         if(GridReactionRequireConsensus)
         {
            string rc_detail = "";
            double rc = ReversalConsensusScore(-1, rc_detail);
            if(rc < GridReactionMinConsensusScore)
            {
               why = StringFormat("rejection ok but reversal not confirmed (%.2f<%.2f) %s",
                                  rc, GridReactionMinConsensusScore, rc_detail);
               return false;
            }
            why = StringFormat("M15 rejection at resistance %.2f (str %.1f, wick %.0f%%) + %s",
                               wall, strength, (upper_wick / range) * 100.0, rc_detail);
            return true;
         }
         why = StringFormat("M15 rejection at resistance %.2f (str %.1f, wick %.0f%%)",
                            wall, strength, (upper_wick / range) * 100.0);
         return true;
      }
      why = "waiting M15 rejection at resistance";
      return false;
   }

   // BUY: poked support with the low, closed back above it, with a real lower wick.
   bool poked   = (l1 <= wall + proximity);
   bool closed_above = (c1 > wall);
   double lower_wick = LowerWickPoints(PERIOD_M15, 1);
   bool wick_ok = ((lower_wick / range) >= GridReactionWickRatioMin);
   if(poked && closed_above && wick_ok)
   {
      // FEATURE(grid-reaction-consensus): require a 2+ signal BULLISH reversal consensus (price
      // should turn UP to help the BUY basket). direction +1 = looking for an upward reversal.
      if(GridReactionRequireConsensus)
      {
         string rc_detail = "";
         double rc = ReversalConsensusScore(1, rc_detail);
         if(rc < GridReactionMinConsensusScore)
         {
            why = StringFormat("rejection ok but reversal not confirmed (%.2f<%.2f) %s",
                               rc, GridReactionMinConsensusScore, rc_detail);
            return false;
         }
         why = StringFormat("M15 rejection at support %.2f (str %.1f, wick %.0f%%) + %s",
                            wall, strength, (lower_wick / range) * 100.0, rc_detail);
         return true;
      }
      why = StringFormat("M15 rejection at support %.2f (str %.1f, wick %.0f%%)",
                         wall, strength, (lower_wick / range) * 100.0);
      return true;
   }
   why = "waiting M15 rejection at support";
   return false;
}

// FIX(sent-is-not-filled): OrderSend()/CTrade return true when the request passed the basic checks and the
// server answered - not that the deal happened. Only these retcodes mean volume is actually on the market.
bool TradeRetcodeFilled(const uint rc)
{
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED);
}

// FIX(account-mode): the whole basket model - a grid of separate positions averaged and closed together -
// only exists on a HEDGING account. On a netting account every "grid add" would be merged into the one
// position, so order counts, the average price, partial closes and the basket TP/SL all read nonsense.
// The account type is detected automatically; on anything but hedging, new risk (first entries and grid
// additions) is refused, while management of whatever is already open keeps running.
bool G_ACCOUNT_MODE_WARNED = false;

string AccountMarginModeName()
{
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return "HEDGING";
   if(mm == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) return "NETTING";
   if(mm == ACCOUNT_MARGIN_MODE_EXCHANGE)       return "EXCHANGE";
   return "UNKNOWN";
}

bool AccountModeAllowsTrading(string &reason)
{
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      reason = "account hedging";
      return true;
   }
   reason = StringFormat("account is %s - the grid basket needs a HEDGING account; new entries and grid additions are off",
                         AccountMarginModeName());
   if(!G_ACCOUNT_MODE_WARNED)
   {
      PrintFormat("[SIRUS ACCOUNT MODE] %s", reason);
      G_LAST_WARNING = "ACCOUNT " + AccountMarginModeName() + ": trading off (needs HEDGING)";
      G_ACCOUNT_MODE_WARNED = true;
   }
   return false;
}

bool GridCanOpen(string &reason)
{
   // FIX(close-remnant-becomes-new-basket): a basket close that could not finish leaves live
   // positions behind. On the next tick the stats refresh reports them as a small, healthy basket
   // - low DD%, a wider TP, no depth cut - and without this guard the grid would happily start a
   // brand-new martingale ladder on the single worst rung of a basket that was just stopped out,
   // with that stop-out's loss already banked on the rungs that did close. Hold until it is flat.
   if(G_BASKET_CLOSE_PENDING)
   {
      reason = "basket close incomplete - no additions until the remnant is flat";
      return false;
   }

   if(!UseGridRecovery)
   {
      reason = "UseGridRecovery=false";
      return false;
   }

   if(!AllowLiveTrading)
   {
      reason = "AllowLiveTrading=false";
      return false;
   }

   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return false;
   }

   string op_grid_reason = "";
   if(!OperatorControlAllowsRecovery(op_grid_reason))
   {
      reason = op_grid_reason;
      return false;
   }

   // V31.6z12 NEW: Grid-vs-Trailing safety check - found during today's professional audit.
   // Grid Intelligence and the trailing/profit-lock system had zero awareness of each other.
   // If the basket is already in profit-trailing mode (actively locking in gains), adding
   // MORE exposure via grid is philosophically backwards - the basket is winning and being
   // protected, not fighting an adverse move. Simple, explicit belt-and-suspenders check.
   if(EnableGridTrailSafetyCheck && G_BASKET_TRAIL_ACTIVE)
   {
      reason = "basket already in profit-trailing mode - grid additions blocked";
      return false;
   }

   string dpg_grid_reason = "";
   if(!DailyProfitGovernorAllowsRecovery(dpg_grid_reason))
   {
      reason = dpg_grid_reason;
      return false;
   }

   string license_grid_reason = "";
   if(!LicenseGuardAllowsEntry(license_grid_reason))
   {
      reason = license_grid_reason;
      return false;
   }

   string setupdoc_grid_reason = "";
   if(!SetupDoctorAllowsEntry(setupdoc_grid_reason))
   {
      reason = setupdoc_grid_reason;
      return false;
   }

   string retry_grid_reason = "";
   if(!RetryEngineAllowsGrid(retry_grid_reason))
   {
      reason = retry_grid_reason;
      return false;
   }

   string risk_reason = "";
   if(!RiskAllowsGrid(risk_reason))
   {
      reason = risk_reason;
      return false;
   }

   string legacy_reason = "";
   if(!LegacyAllowsGrid(legacy_reason))
   {
      reason = legacy_reason;
      return false;
   }

   string pack2_reason = "";
   if(!Pack2RecoveryAllowsGrid(pack2_reason))
   {
      reason = pack2_reason;
      return false;
   }

   string pack3_reason = "";
   if(!Pack3AllowsGrid(pack3_reason))
   {
      reason = pack3_reason;
      return false;
   }

   string p4m_grid_reason = "";
   if(!Pack4MiniAllowsGrid(p4m_grid_reason))
   {
      reason = p4m_grid_reason;
      return false;
   }

   string p4l_grid_reason = "";
   if(!Pack4MiniLotAllowsGrid(p4l_grid_reason))
   {
      reason = p4l_grid_reason;
      return false;
   }

   string rcb_grid_reason = "";
   if(!RCSettingsAllowsGrid(rcb_grid_reason))
   {
      reason = rcb_grid_reason;
      return false;
   }

   string dcs_grid_reason = "";
   if(!SmartClientSafetyAllowsGrid(dcs_grid_reason))
   {
      reason = dcs_grid_reason;
      return false;
   }

   string dlp_grid_reason = "";
   if(!LegacyDeepParityAllowsGrid(dlp_grid_reason))
   {
      reason = dlp_grid_reason;
      return false;
   }

   string dbos_grid_reason = "";
   if(!DeepBOSAllowsGrid(dbos_grid_reason))
   {
      reason = dbos_grid_reason;
      return false;
   }

   string dtz_grid_reason = "";
   if(!DeepTopZoneAllowsGrid(dtz_grid_reason))
   {
      reason = dtz_grid_reason;
      return false;
   }

   string dnv_grid_reason = "";
   if(!DeepNewsVolatilityAllowsGrid(dnv_grid_reason))
   {
      reason = dnv_grid_reason;
      return false;
   }

   string det_grid_reason = "";
   if(!AdaptiveEntryTimingAllowsGrid(det_grid_reason))
   {
      reason = det_grid_reason;
      return false;
   }

   string dri_grid_reason = "";
   if(!AdaptiveRecoveryAllowsGrid(dri_grid_reason))
   {
      reason = dri_grid_reason;
      return false;
   }

   string weekend_grid_reason = "";
   if(!WeekendGuardAllowsGrid(weekend_grid_reason))  // V30.4
   {
      reason = weekend_grid_reason;
      return false;
   }

   string acct_grid_reason = "";
   if(!AccountModeAllowsTrading(acct_grid_reason))
   {
      reason = acct_grid_reason;
      return false;
   }

   string vel_grid_reason = "";
   if(!VelocityAllowsNewRisk(vel_grid_reason))  // V31.1: spike paytida yangi grid ham ochilmaydi
   {
      reason = vel_grid_reason;
      return false;
   }

   string drt_grid_reason = "";
   if(!MarketRegimeAutoTuneAllowsGrid(drt_grid_reason))
   {
      reason = drt_grid_reason;
      return false;
   }

   int orders = 0;
   double vol = 0.0;
   double avg = 0.0;
   double profit = 0.0;
   long direction = -1;
   double last_price = 0.0;
   double last_lot = 0.0;
   datetime last_time = 0;

   if(!GetNaviusBasketStats(orders, vol, avg, profit, direction, last_price, last_lot, last_time))
   {
      reason = "no basket";
      return false;
   }

   if(direction == -2)
   {
      reason = "mixed basket direction";
      return false;
   }

   if(orders >= MaxOrders)
   {
      reason = StringFormat("max orders reached %d/%d", orders, MaxOrders);
      return false;
   }

   if(orders + 1 < GridStartOrder)
   {
      reason = StringFormat("grid starts at order %d, next=%d", GridStartOrder, orders + 1);
      return false;
   }

   if(!AllowGridAfterMicro)
   {
      // If the first/last comment contains MICRO, grid stays disabled for that micro basket in Phase 21.3.
      // We use last entry status as a lightweight guard.
      if(StringFind(G_ENTRY_DETAIL, "MICRO") >= 0 && orders == 1)
      {
         reason = "grid after micro disabled";
         return false;
      }
   }

   int bars_since = G_BARS_SEEN - G_LAST_GRID_BAR;
   if(G_LAST_GRID_BAR > -9999 && GridCooldownBars > 0 && bars_since < GridCooldownBars)
   {
      reason = StringFormat("grid cooldown bars %d/%d", bars_since, GridCooldownBars);
      return false;
   }

   int sec_since = (G_LAST_GRID_TIME <= 0 ? 999999 : (int)(TimeCurrent() - G_LAST_GRID_TIME));
   if(GridMinSecondsBetweenOrders > 0 && sec_since < GridMinSecondsBetweenOrders)
   {
      reason = StringFormat("grid cooldown seconds %d/%d", sec_since, GridMinSecondsBetweenOrders);
      return false;
   }

   if(GridBlockFreshImpulse && G_MARKET_STATE == MARKET_IMPULSE)
   {
      reason = "fresh impulse risk";
      return false;
   }

   // V29 new: stay cautious for a few bars AFTER the impulse bar too, not just during it.
   // Trend-aligned impulses (possible acceleration) get a longer cooldown than corrections
   // (counter-moves against the established trend, which tend to resolve faster).
   if(GridBlockFreshImpulse && EnableImpulseCooldown && G_LAST_IMPULSE_BAR > -100000)
   {
      int bars_since_impulse = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
      int cooldown_needed = G_LAST_IMPULSE_TREND_ALIGNED ? ImpulseCooldownBarsTrend : ImpulseCooldownBarsCorrection;

      if(bars_since_impulse < cooldown_needed)
      {
         reason = StringFormat("impulse cooldown %d/%d bars (%s)",
                               bars_since_impulse, cooldown_needed,
                               G_LAST_IMPULSE_TREND_ALIGNED ? "trend-aligned" : "correction");
         return false;
      }
   }

   bool szr_active = false;
   string auto_grid_safety_reason = "";
   if(GridSafetyDangerNow(auto_grid_safety_reason))
   {
      // V31.6 Smart Zone Recovery: applies ONLY to the trend-against block. Every other
      // danger (DD too high, low health, news, shock, chaos) stays absolute - those are
      // returned FIRST by GridSafetyDangerNow, so reaching the trend-against reason
      // guarantees all more serious dangers were already clear.
      bool is_trend_block = (StringFind(auto_grid_safety_reason, "HTF/structure against") >= 0);

      // Episode edge tracking: a NEW continuous trend-block period re-arms the one-shot.
      if(is_trend_block && !G_SZR_BLOCK_PREV)
      {
         G_SZR_USES_THIS_EPISODE = 0;
         GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_SZRUSED", MagicNumber, _Symbol), 0.0);
      }
      G_SZR_BLOCK_PREV = is_trend_block;

      string szr_why = "";
      if(is_trend_block && SmartZoneRecoveryAllows(direction, last_price, szr_why))
      {
         szr_active = true;
         if((SZRPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6 SMART ZONE RECOVERY] trend-block overridden once: %s", szr_why);
      }
      else
      {
         reason = auto_grid_safety_reason + (StringLen(szr_why) > 0 ? " | " + szr_why : "");
         return false;
      }
   }
   else
      G_SZR_BLOCK_PREV = false;

   // V161: completions are part of the first entry, so the ladder must not count them.
   int grid_orders = EffectiveGridOrders(orders);
   double distance = GridDistanceForNextOrder(grid_orders);

   // V241: and the shape's spacing. A ladder leaning on a level sits closer; one built to survive
   // a trend sits wider, because the move it is waiting out may run.
   if(EnableLadderShaping && G_LADDER_SPACING > 0.0 && MathAbs(G_LADDER_SPACING - 1.0) > 0.01)
      distance *= G_LADDER_SPACING;

   // V220: the situation says how price is expected to move, which is exactly what grid spacing
   // should follow. A level holding means a bounce is the premise, so additions can sit closer; a
   // level broken means price is travelling, and tight additions would fill the whole ladder in a
   // single leg.
   if(EnableSituationPlan && G_SITUATION != SIT_NONE)
   {
      double sg_f = SituationGridFactor(G_SITUATION);
      if(sg_f > 0.0 && MathAbs(sg_f - 1.0) > 0.01)
         distance *= sg_f;
   }

   // V156: adverse runs go further in a trend and reverse sooner in a range - the spacing between
   // additions should reflect that rather than staying fixed.
   double regime_grid_factor = RegimeGridFactor();
   if(regime_grid_factor > 0.0 && MathAbs(regime_grid_factor - 1.0) > 0.001)
      distance *= regime_grid_factor;
   distance = GridZoneAwareDistance(direction, last_price, distance, AutoGridMinDistance());

   // FEATURE(grid-reaction): if price is rejecting off a strong opposing wall right now, this is a
   // higher-quality add than a blind full-distance step, so allow it EARLY - price only needs to
   // travel GridReactionDistanceFraction of the full distance. This is a preference, not a gate:
   // with no reaction, the full distance below is unchanged, so the basket is never left waiting.
   string grid_react_why = "";
   bool grid_reaction = GridReactionAtWall(direction, grid_react_why);
   if(grid_reaction)
   {
      double frac = MathMax(0.1, MathMin(1.0, GridReactionDistanceFraction));
      distance = distance * frac;
      if((GridReactionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS GRID REACTION] early add allowed at %.0f%% distance - %s",
                     frac * 100.0, grid_react_why);
   }

   // FIX(grid-distance-escapes-clamp): GridDistanceForNextOrder() ends by clamping the gap to
   // [AutoGridMinDistance, AutoGridMaxDistance], and LadderIsAffordable() faithfully models that
   // clamp when it decides whether the whole ladder fits inside BasketSLPercent. But the four
   // multipliers above - ladder spacing, SituationGridFactor (up to 1.50), RegimeGridFactor (up to
   // 1.35) and the zone-aware/reaction adjustments - all run AFTER it, and nothing re-clamped.
   // Combined they reach ~2.0x, which makes the real ladder roughly twice as deep as the one the
   // affordability gate approved: the 50% stop then fires at rung 4 with the last rung never placed
   // - the exact mid-ladder trap that gate exists to prevent, reachable in an ordinary volatile
   // exhaustion-at-edge state. Re-apply the same bound the projection assumed, so the promise the
   // entry gate made about this basket still holds when the rung is actually placed.
   {
      double gd_min = AutoGridMinDistance();
      double gd_max = AutoGridMaxDistance();
      if(gd_min > 0.0 && distance < gd_min)
         distance = gd_min;
      if(gd_max > 0.0 && distance > gd_max)
         distance = gd_max;
   }

   double next_price = 0.0;
   bool adverse_move_ok = IsGridAdverseMove(direction, last_price, distance, next_price);

   double dd = 0.0;
   double recovery_dd_trigger = 0.0;
   bool dd_trigger_ok = true;
   if(GridUseRecoveryDDTrigger)
   {
      dd = BasketDDPercentApprox(profit);
      recovery_dd_trigger = AutoGridRecoveryStartDD();
      dd_trigger_ok = (dd >= recovery_dd_trigger);
   }

   // V31.6 CRITICAL FIX: distance is MANDATORY for every grid order, no exceptions.
   // The old V29 "OR" logic let the DD-trigger open a new order every cooldown with ZERO
   // distance check once basket DD passed the threshold - that is exactly how 7 sells got
   // stacked 7-70 points apart in one spot. Now:
   //   - price MUST have moved the full grid distance against the basket (always), AND
   //   - if GridUseRecoveryDDTrigger is enabled, DD must ALSO be past its threshold.
   // DD can only make the grid MORE selective, never bypass the distance requirement.
   // Basket-level protection is the Basket SL's job, not the grid trigger's.
   bool distance_trigger_ok = (!GridRequireAdverseMove) || adverse_move_ok;
   // V228: how deep can this ladder actually go? MaxOrders is a setting; what the account can pay
   // for is arithmetic, and when they disagree the arithmetic wins. Stopping at the rung the budget
   // covers is better than stopping at the one the stop-loss does.
   if(EnableGridDepthLimit)
   {
      string gd_reason = "";
      int eff_max = GridEffectiveMaxOrders(gd_reason);
      G_GRID_MAX_EFFECTIVE = eff_max;

      if(G_BASKET_ORDERS >= eff_max && eff_max < MaxOrders)
      {
         reason = gd_reason;
         if((GridDepthPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v228 DEPTH] %s", gd_reason);
         return false;
      }
   }

   // V248: a release arriving mid-basket is the worst moment to add. Spreads widen, the move is
   // fast and one-directional, and the rung fills at the worst price of it.
   // SCENARIO: does the level in front of this basket usually give enough room to recover in? A
   // rung added into a bounce that has already finished is how the grind collects baskets - half an
   // ATR of reaction touches the target and leaves nothing behind it, and a hundred of those in a
   // row is the hundred-dollar fall.
   //
   // Stricter than the entry side, because a rung has to move the average price, not merely reach
   // a target.
   if(EnableScenario && ScenGridMinATR > 0.0)
   {
      // The basket's own direction - GridCanOpen takes only a reason string, so it is read from
      // the position rather than passed in.
      int sc_dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1
                 : ((G_BASKET_DIRECTION == POSITION_TYPE_SELL) ? -1 : 0);

      int sc_n = 0;
      double sc_proj = (sc_dir != 0) ? ScenarioProjection(sc_dir, sc_n) : 0.0;

      if(sc_n >= ScenarioMinSamples && sc_proj > 0.0 && sc_proj < ScenGridMinATR)
      {
         reason = StringFormat("holding - reactions here average %.1f ATR, needs %.1f",
                               sc_proj, ScenGridMinATR);
         return false;
      }
   }

   // S-FIX: through the owner, so the calendar and the live read cannot disagree here. A scheduled
   // release stops additions outright; an unscheduled one that merely looks like news does too,
   // because this side is stricter than the entry side - adding during a release is how a
   // recoverable basket becomes one that is not.
   if(EnableNewsOwner)
   {
      string gn_detail = "";
      if(NewsOwnerBlocksGrid(gn_detail))
      {
         reason = StringFormat("holding - %s", gn_detail);
         return false;
      }
   }
   else if(EnableEconomicCalendarGuard && G_CAL_ACTIVE)
   {
      // FIX(calendar-window): with the news owner off, a scheduled release used to be invisible here.
      reason = StringFormat("holding - scheduled: %s (%d min)", G_CAL_EVENT_NAME, G_CAL_MINUTES_FROM_EVENT);
      return false;
   }
   else if(EnableLiveNewsRead)
   {
      string gn_detail = "";
      double gn = NewsInProgress(gn_detail);
      if(gn >= LiveNewsGridBlock)
      {
         reason = StringFormat("holding - %s", gn_detail);
         return false;
      }
   }

   // V247: has price disproved the reason this basket exists? Not "has the money run out" - the
   // stop already answers that - but "is the case still true". A short taken inside a falling
   // structure is wrong the moment price closes above where that structure ends, and no amount of
   // remaining drawdown budget changes it.
   //
   // The basket is not closed. Closing into the move that just went against it realises the loss at
   // its worst point, and that has been the wrong answer every time. What stops is the ladder.
   if(EnableBasketThesis && G_BASKET_ORDERS > 0)
   {
      string th_detail = "";
      if(BasketPremiseDead(th_detail))
      {
         reason = StringFormat("holding - %s; no more size on a thesis that has already failed",
                               th_detail);
         return false;
      }
   }

   // V228: is this still the market the basket was opened in? A basket built in London and still
   // running in Asia was sized for a range and a set of participants that have both gone. The ladder
   // is not closed - closing into a move that went against it realises the loss at its worst point -
   // but it stops extending into conditions it was never designed for.
   if(EnableBasketStaleness && G_BASKET_ORDERS > 0)
   {
      string st_detail = "";
      double stale = BasketStaleness(st_detail);
      G_BASKET_STALENESS = stale;

      if(stale >= BasketStaleBlockLevel)
      {
         reason = StringFormat("holding - %s", st_detail);
         if((BasketStalePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v228 STALE] %s", st_detail);
         return false;
      }
   }

   bool trigger_ok = distance_trigger_ok && dd_trigger_ok;

   G_NEXT_GRID_DISTANCE = distance;
   // FIX(dead-assignment): the plain `G_NEXT_GRID_PRICE = next_price;` that used to sit here was
   // unconditionally overwritten by the V222 line below on every call - it had no effect and just
   // made a reader think next_price was used whenever G_GRID_SNAP_PRICE was unset, when in fact
   // it never was.
   G_NEXT_GRID_PRICE = (G_GRID_SNAP_PRICE > 0.0) ? G_GRID_SNAP_PRICE : next_price;   // V222
   // V161: the ladder multiplies from the first entry's FULL size and counts only real grid
   // additions - a scale-in completion is neither.
   G_NEXT_GRID_LOT = NextGridLot(EffectiveLastLot(last_lot, orders), EffectiveGridOrders(orders));

   if(!trigger_ok)
   {
      reason = StringFormat("waiting distance | need=%.0f next=%.2f last=%.2f | DD %.2f/%.2f%%",
                            distance, next_price, last_price, dd, recovery_dd_trigger);
      return false;
   }

   // FIX(martingale-floor-override): every soft caution wants this addition smaller than the floor.
   // Lifting it to the floor anyway meant adding near-full size into exactly the conditions they were
   // warning about; adding a fragment is no better (full new risk, almost no improvement of the average).
   // So hold this rung: if the cautions clear, it goes in at its proper size; if price runs a further
   // part of the grid distance, the add happens at a better price; and after GridCautionMaxHoldBars it
   // goes in at the floor regardless, so the recovery is delayed, never abandoned.
   if(EnableGridCautionHold && G_GRID_LOT_CAUTION_FLOORED)
   {
      if(G_GCH_ORDERS != orders || G_GCH_BASKET_BAR != G_BASKET_OPEN_BAR || G_GCH_START_BAR > G_BARS_SEEN)
      {
         G_GCH_ORDERS = orders;
         G_GCH_BASKET_BAR = G_BASKET_OPEN_BAR;
         G_GCH_START_BAR = G_BARS_SEEN;
      }
      double gch_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double gch_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double gch_adverse = (direction == POSITION_TYPE_BUY) ? (last_price - gch_bid) / _Point
                                                            : (gch_ask - last_price) / _Point;
      double gch_release = distance * (1.0 + MathMax(0.0, GridCautionExtraDistFraction));
      int    gch_held = G_BARS_SEEN - G_GCH_START_BAR;
      if(gch_held < MathMax(0, GridCautionMaxHoldBars) && gch_adverse < gch_release)
      {
         reason = StringFormat("holding rung - cautions cut lot to x%.2f of target (below floor) | %d/%d bars | %.0f/%.0f pts",
                               G_GRID_LOT_SOFT_FACTOR, gch_held, GridCautionMaxHoldBars, gch_adverse, gch_release);
         return false;
      }
      if(VerboseLogs)
         PrintFormat("[SIRUS GRID CAUTION HOLD] released after %d bars / %.0f pts - adding at floor lot %.2f",
                     gch_held, gch_adverse, G_NEXT_GRID_LOT);
   }

   // V31.6 Smart Zone Recovery: the smart add fires with a reduced lot, and the one-shot
   // is consumed only HERE - when every other condition (cooldowns, distance) also passed,
   // so a not-yet-ready distance check can't waste the episode's single permission.
   if(szr_active)
   {
      double szr_lot = NormalizeVolumeSafe(G_NEXT_GRID_LOT * SZRLotFactor);

      // FIX(szr-lot-floor): SZRLotFactor (0.5) was applied AFTER NextGridLot's floors, so it
      // silently shrank the grid add below the previous order - the exact 0.15 -> 0.09 in the
      // user's screenshot (0.18 floored -> x0.5 -> 0.09). An undersized add takes full new risk
      // while barely improving the average, and inverts the martingale. Re-apply the same two
      // floors NextGridLot uses so an SZR add, like any grid add, is never below the previous
      // order or the absolute martingale progression. SZR still fires; it just can't fragment.
      double szr_floor = 0.0;
      if(EnableGridNeverBelowPrevious && last_lot > 0.0)
         szr_floor = last_lot;
      if(EnableAbsoluteGridLotFloor && LotMultiplier > 0.0 && StartLot > 0.0)
      {
         double intended = StartLot * MathPow(LotMultiplier, MathMax(0, orders));
         if(MaxLot > 0.0)
            intended = MathMin(intended, MaxLot);
         double abs_floor = intended * MathMax(0.05, MathMin(1.0, AbsoluteGridLotFloorFactor));
         if(abs_floor > szr_floor)
            szr_floor = abs_floor;
      }
      if(szr_lot < szr_floor)
         szr_lot = szr_floor;
      if(MaxLot > 0.0 && szr_lot > MaxLot)
         szr_lot = MaxLot;

      G_NEXT_GRID_LOT = NormalizeVolumeSafe(szr_lot);
      G_SZR_USES_THIS_EPISODE++;
      G_SZR_ESCAPE_MODE = true;   // V31.6b: basket now aims for a fast BE+X release
      GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_SZRUSED", MagicNumber, _Symbol), (double)G_SZR_USES_THIS_EPISODE);
      GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_SZRESC", MagicNumber, _Symbol), 1.0);
   }

   // V31.6e new: total basket exposure cap - the FINAL check, using the final lot (post-SZR
   // reduction if any). Hard block by design: this exists specifically to prevent the
   // compounding LotMultiplier chain from ever risking more capital than the account can
   // reasonably absorb, regardless of account size.
   // V131 (rebuilt in V137): don't ADD while price is INSIDE a zone band.
   // ----------------------------------------------------------------------------------------
   // The original version asked the wrong question. It looked for the zone OPPOSING the basket -
   // support under a SELL, resistance over a BUY - but a grid add is placed on the far side: a SELL
   // basket adds ABOVE, where support underneath is irrelevant. So it guarded a level the addition
   // would never reach.
   //
   // The real hazard is different, and it is the one the user's chart showed: price sitting INSIDE a
   // band, where support and resistance are indistinguishable and any level read is a coin flip.
   // Adding there means committing size at a price whose meaning is unknown. Waiting until price
   // leaves the band and respects an edge costs a little time and buys a real level to lean on.
   //
   // This complements GridZoneAwareDistance/GridZoneReach rather than duplicating it: that decides
   // WHERE the add belongs once a level is readable; this decides WHETHER the level is readable yet.
   if(EnableGridZoneWait && _Point > 0.0 && G_BASKET_ORDERS > 0)
   {
      // Deep drawdown overrides the wait entirely - a basket that is already deep needs its
      // averaging now, and fill quality stops mattering once survival is the question.
      bool gz_dd_override = (GridZoneWaitMaxBasketDD > 0.0 &&
                             G_BASKET_DD_PERCENT >= GridZoneWaitMaxBasketDD);

      if(gz_dd_override)
      {
         G_GRID_ZONE_WAIT_BAR = -100000;
      }
      else
      {
         double gz_lo = 0.0, gz_hi = 0.0;
         string gz_detail = "";

         if(ZonePriceInsideBand(gz_lo, gz_hi, gz_detail))
         {
            int gz_waited = (G_GRID_ZONE_WAIT_BAR > -100000) ? (G_BARS_SEEN - G_GRID_ZONE_WAIT_BAR) : 0;
            if(G_GRID_ZONE_WAIT_BAR <= -100000)
            {
               G_GRID_ZONE_WAIT_BAR = G_BARS_SEEN;
               gz_waited = 0;
            }

            if(gz_waited < MathMax(1, GridZoneWaitMaxBars))
            {
               reason = StringFormat("waiting - %s; adding here commits size at a price with no defined level",
                                     gz_detail);
               if((GridZoneWaitPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v137 GRID ZONE WAIT] %s | waited %d/%d bars",
                              reason, gz_waited, GridZoneWaitMaxBars);
               return false;
            }

            // Waited long enough - proceed rather than strand the basket inside a band.
            if((GridZoneWaitPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v137 GRID ZONE WAIT] wait expired after %d bars - allowing the addition", gz_waited);
         }
         else
            G_GRID_ZONE_WAIT_BAR = -100000;   // price is out of any band - reset the timer
      }
   }

   string exposure_reason = "";
   ENUM_ORDER_TYPE grid_order_type = (direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!BasketExposureAllowsGrid(G_NEXT_GRID_LOT, grid_order_type, exposure_reason))
   {
      // V114: this gate fires BEFORE the margin pre-check, so without a rescue here the basket
      // freezes before it ever reaches one. Same rule as there: take the largest lot that fits, but
      // only if it is still a meaningful fraction of the intended size.
      string exp_rescue_detail = "";
      double exp_rescue_lot = MarginRescueGridLot(grid_order_type, G_NEXT_GRID_LOT, exp_rescue_detail);

      if(exp_rescue_lot > 0.0)
      {
         if((GridMarginRescuePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v114 MARGIN RESCUE] exposure gate: %s | original block: %s",
                        exp_rescue_detail, exposure_reason);
         G_NEXT_GRID_LOT = exp_rescue_lot;   // continue with the reduced size
      }
      else
      {
         if((GridMarginRescuePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v114 MARGIN RESCUE] GRID FROZEN at exposure gate | %s | %s | lot-to-balance ratio is too high for this account size",
                        exposure_reason, exp_rescue_detail);
         reason = exposure_reason + " | " + exp_rescue_detail;
         return false;
      }
   }

   // V31.6m: Grid Intelligence Score - replaces the earlier BINARY reversal block with a
   // continuous, multi-sense score (reversal confidence + MTF alignment + zone quality).
   // Only the most extreme, multi-sense-confirmed cases hard-block here; the lot itself is
   // ALSO scaled continuously via GridIntelligenceLotAdjust in NextGridLot, so most cases get
   // a proportional caution rather than a coin-flip stop.
   // EXEMPTS SZR-approved additions (szr_active): SZR already performed a MORE targeted check
   // (strong, cascade-aware zone + rejection candle + order-flow veto) specifically for the
   // "trend is against the basket" scenario. Blocking on top of that would often cancel SZR's
   // own careful exception, freezing the basket with no rescue path at all.
   if(!szr_active)
   {
      string gi_reason = "";
      if(!GridIntelligenceAllowsGrid(direction, orders, gi_reason))
      {
         reason = gi_reason;
         if((GridIntelligencePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6m GRID INTELLIGENCE BLOCK] %s", gi_reason);
         return false;
      }
   }

   // V31.6k new: broker's own Margin Level - the last safety gate, independent from our
   // internal equity-DD stops.
   string margin_level_reason = "";
   if(!MarginLevelAllowsGrid(margin_level_reason))
   {
      reason = margin_level_reason;
      return false;
   }

   reason = StringFormat("grid ready%s | profile=%s | orders=%d/%d | distance=%.0f | lot=%.2f | DD=%.2f/%.2f%%",
                         (szr_active ? " (SMART ZONE RECOVERY)" : ""),
                         AutoGridProfileText(),
                         orders,
                         MaxOrders,
                         G_NEXT_GRID_DISTANCE,
                         G_NEXT_GRID_LOT,
                         dd,
                         recovery_dd_trigger);
   return true;
}

// FEATURE(tp-sl-lines): draw / update / remove the basket TP line and the trailing-SL line.
// TP price is computed from the basket AVERAGE, so it shifts automatically when a new grid order
// moves the average. The trailing line is drawn only while trailing is armed. Objects use the
// dedicated LINE_ prefix so they are cleared here (not by dashboard/close-marker cleanup) and are
// removed the moment the basket closes.
void DrawBasketTPSLLines()
{
   // PERF: chart objects are for live monitoring only - never draw them in the tester/optimizer,
   // where redrawing every tick massively slows runs (same reason the dashboard is skipped there).
   if((bool)MQLInfoInteger(MQL_OPTIMIZATION))
      return;

   string tp_name    = G_PREFIX + "LINE_TP";
   string tp_label   = G_PREFIX + "LINE_TP_LBL";
   string sl_name    = G_PREFIX + "LINE_SL";
   string sl_label   = G_PREFIX + "LINE_SL_LBL";

   // No basket, or feature off -> make sure nothing lingers on the chart.
   if(!EnableTPSLLines || G_BASKET_ORDERS <= 0 || G_BASKET_AVG_PRICE <= 0.0 ||
      (G_BASKET_DIRECTION != POSITION_TYPE_BUY && G_BASKET_DIRECTION != POSITION_TYPE_SELL))
   {
      ObjectDelete(0, tp_name);
      ObjectDelete(0, tp_label);
      ObjectDelete(0, sl_name);
      ObjectDelete(0, sl_label);
      return;
   }

   int dir_sign = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;

   // --- TP line: average price +/- the current target in points (moves with the average) --------
   double tp_points = BasketTPForOrderCount(G_BASKET_ORDERS);
   double tp_price  = G_BASKET_AVG_PRICE + dir_sign * tp_points * _Point;

   if(ObjectFind(0, tp_name) < 0)
   {
      ObjectCreate(0, tp_name, OBJ_HLINE, 0, 0, tp_price);
      ObjectSetInteger(0, tp_name, OBJPROP_COLOR, TPLineColor);
      ObjectSetInteger(0, tp_name, OBJPROP_STYLE, TPSLLineStyle);
      ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, MathMax(1, TPSLLineWidth));
      ObjectSetInteger(0, tp_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, tp_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tp_name, OBJPROP_HIDDEN, true);
   }
   ObjectSetDouble(0, tp_name, OBJPROP_PRICE, tp_price);

   string tp_txt = StringFormat("TP %.0fpts (%d ord)", tp_points, G_BASKET_ORDERS);
   if(ObjectFind(0, tp_label) < 0)
   {
      ObjectCreate(0, tp_label, OBJ_TEXT, 0, TimeCurrent(), tp_price);
      ObjectSetInteger(0, tp_label, OBJPROP_COLOR, TPLineColor);
      ObjectSetInteger(0, tp_label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, tp_label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, tp_label, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tp_label, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, tp_label, OBJPROP_TIME, TimeCurrent());
   ObjectSetDouble(0, tp_label, OBJPROP_PRICE, tp_price);
   ObjectSetString(0, tp_label, OBJPROP_TEXT, tp_txt);

   // --- Trailing-SL line: only while trailing is armed; rides behind the locked profit ----------
   if(G_BASKET_TRAIL_ACTIVE && G_BASKET_TRAIL_LOCK != 0.0)
   {
      double sl_price = G_BASKET_AVG_PRICE + dir_sign * G_BASKET_TRAIL_LOCK * _Point;

      if(ObjectFind(0, sl_name) < 0)
      {
         ObjectCreate(0, sl_name, OBJ_HLINE, 0, 0, sl_price);
         ObjectSetInteger(0, sl_name, OBJPROP_COLOR, TrailSLLineColor);
         ObjectSetInteger(0, sl_name, OBJPROP_STYLE, TPSLLineStyle);
         ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, MathMax(1, TPSLLineWidth));
         ObjectSetInteger(0, sl_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, sl_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, sl_name, OBJPROP_HIDDEN, true);
      }
      ObjectSetDouble(0, sl_name, OBJPROP_PRICE, sl_price);

      string sl_txt = StringFormat("TRAIL SL %.0fpts", G_BASKET_TRAIL_LOCK);
      if(ObjectFind(0, sl_label) < 0)
      {
         ObjectCreate(0, sl_label, OBJ_TEXT, 0, TimeCurrent(), sl_price);
         ObjectSetInteger(0, sl_label, OBJPROP_COLOR, TrailSLLineColor);
         ObjectSetInteger(0, sl_label, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, sl_label, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, sl_label, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, sl_label, OBJPROP_HIDDEN, true);
      }
      ObjectSetInteger(0, sl_label, OBJPROP_TIME, TimeCurrent());
      ObjectSetDouble(0, sl_label, OBJPROP_PRICE, sl_price);
      ObjectSetString(0, sl_label, OBJPROP_TEXT, sl_txt);
   }
   else
   {
      // Trailing not armed yet -> no stop line.
      ObjectDelete(0, sl_name);
      ObjectDelete(0, sl_label);
   }
}

void RefreshGridDashboardStats()
{
   int orders = 0;
   double vol = 0.0;
   double avg = 0.0;
   double profit = 0.0;
   long direction = -1;
   double last_price = 0.0;
   double last_lot = 0.0;
   datetime last_time = 0;

   if(GetNaviusBasketStats(orders, vol, avg, profit, direction, last_price, last_lot, last_time))
   {
      G_BASKET_ORDERS = orders;
      G_BASKET_VOLUME = vol;
      G_BASKET_AVG_PRICE = avg;
      G_BASKET_PROFIT = profit;
      G_BASKET_DIRECTION = direction;
      G_BASKET_POINTS = CurrentBasketPoints(direction, avg);
      G_BASKET_DD_PERCENT = BasketDDPercentApprox(profit);
      RecordBasketDDHistory();
   }
   else
   {
      G_BASKET_ORDERS = 0;
      G_BASKET_VOLUME = 0.0;
      G_BASKET_AVG_PRICE = 0.0;
      G_BASKET_PROFIT = 0.0;
      G_BASKET_DIRECTION = -1;
   G_BASKET_LAST_GRID_PRICE = 0.0;
   G_BASKET_ADVERSE_STREAK = 0;
   G_BASKET_DD_HISTORY_COUNT = 0;
   G_BASKET_DD_HISTORY_BAR = -1;
   G_SEE_PERSIST_BARS = 0;
   G_SEE_PERSIST_DIR = 0;
   G_LAST_DD_WARNING_LEVEL = 0.0;
      G_BASKET_POINTS = 0.0;
      G_BASKET_DD_PERCENT = 0.0;
      G_BASKET_MODE_FROZEN = false;   // V29 fix: basket closed, next basket uses live mode again
   }

   // FEATURE(tp-sl-lines): keep the chart TP / trailing-SL lines in sync with the current basket
   // (draws when a basket is open, moves the TP as the average shifts, removes them when it closes).
   DrawBasketTPSLLines();
}

void UpdateGridRecoveryEngine(const string source)
{
   // V161: before the grid considers anything, see whether a scale-in entry has earned its
   // completion. This is not a grid addition - it finishes the first entry at the size that was
   // always intended, now that price has confirmed the setup.
   if(EnableScaleIn && G_SCALEIN_PENDING_LOT > 0.0)
   {
      string si_reason = "";
      double si_lot = ScaleInDueLot(si_reason);

      // The grid's own gate cannot be reused here - it enforces grid SPACING, which a completion
      // is not subject to. What must still be honoured are the halts: live trading off, a risk
      // block, or an environment that is not ready.
      bool si_allowed = (AllowLiveTrading && G_ENV_READY && !G_RISK_HARD_BLOCK && !G_RISK_CLOSE_REQUEST);

      // FIX(scalein-no-margin-check): this was the ONLY order-sending path in the EA with no
      // margin test. The first entry checks MarginAllowsOrder() before it opens, but the held-back
      // remainder is sent from here - potentially many bars later, by which time the account may
      // have taken on other exposure. A NO_MONEY rejection was swallowed into a log line.
      if(si_lot > 0.0 && si_allowed)
      {
         ENUM_ORDER_TYPE si_type = (G_SCALEIN_DIR > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         string si_margin_why = "";
         if(!MarginAllowsOrder(si_type, NormalizeVolumeSafe(si_lot), si_margin_why))
         {
            si_allowed = false;
            if((ScaleInPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v161 SCALE-IN] completion held - %s", si_margin_why);
         }
      }

      if(si_lot > 0.0 && si_allowed)
      {
         G_TRADE.SetExpertMagicNumber(MagicNumber);
         G_TRADE.SetDeviationInPoints(OrderSendDeviationPoints);
         G_TRADE.SetTypeFillingBySymbol(_Symbol);

         string si_comment = "Navius by Zakiy SCALE-IN";
         bool si_sent = false;
         if(G_SCALEIN_DIR > 0)
            si_sent = G_TRADE.Buy(NormalizeVolumeSafe(si_lot), _Symbol, 0.0, 0.0, 0.0, si_comment);
         else
            si_sent = G_TRADE.Sell(NormalizeVolumeSafe(si_lot), _Symbol, 0.0, 0.0, 0.0, si_comment);
         si_sent = si_sent && TradeRetcodeFilled(G_TRADE.ResultRetcode());   // FIX(sent-is-not-filled)

         if(si_sent)
         {
            G_SCALEIN_EXTRA_ORDERS++;
            ReasonCodeEntry("SCALE-IN", (G_SCALEIN_DIR > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                            G_TRADE.ResultVolume(), G_TRADE.ResultPrice(), G_TRADE.ResultOrder());
            if((ScaleInPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v161 SCALE-IN] completed with %.2f lots - %s", si_lot, si_reason);
            ScaleInReset();
         }
         else if((ScaleInPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v161 SCALE-IN] completion failed: %s (%d)",
                        G_TRADE.ResultRetcodeDescription(), (int)G_TRADE.ResultRetcode());
      }
      else if(StringLen(si_reason) > 0 && (ScaleInPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v161 SCALE-IN] %s", si_reason);
   }

   RefreshGridDashboardStats();

   // FIX(close-remnant-never-retried): the G_BASKET_CLOSE_PENDING latch stops the grid ADDING to a
   // remnant, but on its own it also freezes it: all three retry passes inside CloseNaviusBasket()
   // run within one tick at the same quote, so a requote or off-quotes rejects all three
   // identically. The real retry has to be a later tick, and nothing was re-invoking the close.
   // Meanwhile the refresh above recomputes the remnant's DD against its own (much smaller)
   // average, so BasketSLPercent and Smart Early Exit no longer fire on it either - the position
   // would sit unmanaged until it happened to reach TP or the user closed it by hand.
   if(G_BASKET_CLOSE_PENDING && G_BASKET_ORDERS > 0)
   {
      static datetime last_remnant_retry = 0;
      datetime rr_now = TimeCurrent();
      if(rr_now - last_remnant_retry >= 5 || last_remnant_retry > rr_now)
      {
         last_remnant_retry = rr_now;
         CloseNaviusBasket("remnant retry - a previous close left positions open");
         RefreshGridDashboardStats();
      }
   }

   if(CheckBasketExit())
   {
      RefreshGridDashboardStats();
      G_GRID_STATUS = "GRID: BASKET EXIT EXECUTED";
      G_GRID_REASON = "basket target/stop hit";
      G_GRID_DETAIL = StringFormat("GRID DETAIL: orders=%d profit=%.2f points=%.0f",
                                   G_BASKET_ORDERS,
                                   G_BASKET_PROFIT,
                                   G_BASKET_POINTS);
      return;
   }

   string reason = "";
   bool can_grid = GridCanOpen(reason);

   if(!can_grid)
   {
      G_GRID_STATUS = "GRID: WAIT | reason=" + reason;
      G_GRID_REASON = reason;
      G_GRID_DETAIL = StringFormat("GRID DETAIL: orders=%d volume=%.2f avg=%.2f profit=%.2f points=%.0f nextDist=%.0f nextLot=%.2f",
                                   G_BASKET_ORDERS,
                                   G_BASKET_VOLUME,
                                   G_BASKET_AVG_PRICE,
                                   G_BASKET_PROFIT,
                                   G_BASKET_POINTS,
                                   G_NEXT_GRID_DISTANCE,
                                   G_NEXT_GRID_LOT);
   }
   else
   {
      ENUM_ORDER_TYPE order_type = (G_BASKET_DIRECTION == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = 0.0, sl = 0.0, tp = 0.0;

      // Grid orders do not use individual TP; basket manager handles exit.
      double ask = 0.0, bid = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
      SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
      price = (order_type == ORDER_TYPE_BUY ? ask : bid);

      // V30 new: margin pre-check for grid orders (grid lots grow with LotMultiplier,
      // so this is where NO_MONEY rejections used to happen first).
      string grid_margin_reason = "";
      if(!MarginAllowsOrder(order_type, G_NEXT_GRID_LOT, grid_margin_reason))
      {
         // V114: before giving up, look for the largest lot that DOES fit. Freezing a basket that
         // is already in drawdown is the worst outcome - a smaller addition still averages down.
         string rescue_detail = "";
         double rescue_lot = MarginRescueGridLot(order_type, G_NEXT_GRID_LOT, rescue_detail);

         if(rescue_lot > 0.0)
         {
            if((GridMarginRescuePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v114 MARGIN RESCUE] %s | free=%.2f equity=%.2f | original block: %s",
                           rescue_detail,
                           AccountInfoDouble(ACCOUNT_MARGIN_FREE),
                           AccountInfoDouble(ACCOUNT_EQUITY),
                           grid_margin_reason);
            G_NEXT_GRID_LOT = rescue_lot;      // proceed with the reduced size
            G_GRID_DETAIL = "GRID DETAIL: " + rescue_detail;
         }
         else
         {
            // Nothing meaningful fits - the block stands, but say exactly why so the account/lot
            // mismatch is visible instead of the grid silently going quiet.
            G_GRID_STATUS = "GRID: BLOCK | reason=" + grid_margin_reason;
            G_GRID_REASON = grid_margin_reason;
            G_GRID_DETAIL = StringFormat("GRID DETAIL: nextLot=%.2f | free=%.2f | equity=%.2f | %s",
                                         G_NEXT_GRID_LOT,
                                         AccountInfoDouble(ACCOUNT_MARGIN_FREE),
                                         AccountInfoDouble(ACCOUNT_EQUITY),
                                         rescue_detail);
            if((GridMarginRescuePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v114 MARGIN RESCUE] GRID FROZEN | %s | %s | lot-to-balance ratio is too high for this account size",
                           grid_margin_reason, rescue_detail);
            SetStatus(G_GRID_STATUS, "UpdateGridRecoveryEngine");
            return;
         }
      }

      G_TRADE.SetExpertMagicNumber(MagicNumber);
      G_TRADE.SetDeviationInPoints(OrderSendDeviationPoints);
      G_TRADE.SetTypeFillingBySymbol(_Symbol);

      // V31.6z fix: was showing G_ACTIVE_MODE (live, current mode) which can differ from the
      // FROZEN mode actually used to compute this grid's distance/lot - misleading label that
      // made a correctly-behaving grid look like it switched modes mid-basket.
      ENUM_NAVIUS_MODE comment_mode = (G_BASKET_MODE_FROZEN ? G_BASKET_FROZEN_MODE : G_ACTIVE_MODE);
      string comment = StringFormat("Navius by Zakiy %s GRID", ModeToShortString(comment_mode));

      G_GRID_ATTEMPTS++;

      bool sent = false;
      if(order_type == ORDER_TYPE_BUY)
         sent = G_TRADE.Buy(G_NEXT_GRID_LOT, _Symbol, 0.0, sl, tp, comment);
      else
         sent = G_TRADE.Sell(G_NEXT_GRID_LOT, _Symbol, 0.0, sl, tp, comment);

      int retcode = (int)G_TRADE.ResultRetcode();
      string ret_desc = G_TRADE.ResultRetcodeDescription();
      sent = sent && TradeRetcodeFilled((uint)retcode);   // FIX(sent-is-not-filled)

      if(sent)
      {
         // V31.6z69 fix: my own bug from z20 - this tracking ran BEFORE the send, so a FAILED
         // order attempt (requote, insufficient margin, broker reject) still incremented the
         // adverse streak and still overwrote G_BASKET_LAST_GRID_PRICE, as though a position had
         // actually been added. The streak is meant to record "my own real additions keep
         // failing to work" - counting attempts that never became positions inflated it and
         // wrongly raised the grid threshold. G_GRID_ATTEMPTS above legitimately counts attempts;
         // this must only count what actually reached the market.
         double streak_price = (order_type == ORDER_TYPE_BUY) ?
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(G_BASKET_LAST_GRID_PRICE > 0.0 && streak_price > 0.0)
         {
            bool no_recovery = (order_type == ORDER_TYPE_BUY) ?
                               (streak_price <= G_BASKET_LAST_GRID_PRICE) :
                               (streak_price >= G_BASKET_LAST_GRID_PRICE);
            if(no_recovery)
               G_BASKET_ADVERSE_STREAK++;
            else
               G_BASKET_ADVERSE_STREAK = 0;
         }
         if(streak_price > 0.0)
            G_BASKET_LAST_GRID_PRICE = streak_price;

         G_GRID_SUCCESSES++;
         G_LAST_GRID_TIME = TimeCurrent();
         G_LAST_GRID_BAR = G_BARS_SEEN;
         G_GRID_LAST_FAIL_TIME = 0;
         G_GRID_TRANSIENT_RETRY_COUNT = 0;

         G_GRID_STATUS = StringFormat("GRID: SENT %s | lot=%.2f | order#=%d",
                                      (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                                      G_NEXT_GRID_LOT,
                                      G_BASKET_ORDERS + 1);

         G_GRID_REASON = "grid sent";
         G_GRID_DETAIL = StringFormat("GRID DETAIL: distance=%.0f | ret=%d %s | comment=%s",
                                      G_NEXT_GRID_DISTANCE,
                                      retcode,
                                      ret_desc,
                                      comment);

         PrintFormat("[SIRUS v31.6 PHASE 21.3 GRID SENT] %s | %s",
                     G_GRID_STATUS,
                     G_GRID_DETAIL);
         ReasonCodeGrid(order_type, G_NEXT_GRID_LOT, G_TRADE.ResultPrice(), G_TRADE.ResultOrder(), G_BASKET_ORDERS);
      }
      else
      {
         G_GRID_FAILS++;

         G_GRID_STATUS = StringFormat("GRID: SEND FAILED | lot=%.2f | ret=%d %s",
                                      G_NEXT_GRID_LOT,
                                      retcode,
                                      ret_desc);

         G_GRID_REASON = "grid send failed";
         G_GRID_DETAIL = StringFormat("GRID DETAIL: price=%.2f | distance=%.0f | comment=%s",
                                      price,
                                      G_NEXT_GRID_DISTANCE,
                                      comment);

         if(EnableRealRetryEngine)
         {
            bool grid_transient = IsTransientTradeRetcode(retcode);
            G_GRID_LAST_FAIL_TIME = TimeCurrent();
            G_GRID_LAST_FAIL_TRANSIENT = grid_transient;
            if(grid_transient)
               G_GRID_TRANSIENT_RETRY_COUNT++;
            else
               G_GRID_TRANSIENT_RETRY_COUNT = 0;

            if((RetryPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v29 RETRY] grid fail ret=%d transient=%s attempt=%d/%d",
                           retcode, YesNoV29(grid_transient), G_GRID_TRANSIENT_RETRY_COUNT, RetryMaxAttempts);
         }

         PrintFormat("[SIRUS v31.6 PHASE 21.3 GRID FAILED] %s | %s",
                     G_GRID_STATUS,
                     G_GRID_DETAIL);
      }
   }

   string signature = G_GRID_STATUS + "|" + G_GRID_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintGridDecisions && signature != G_GRID_LAST_SIGNATURE)
   {
      if(G_BASKET_ORDERS > 0 || G_GRID_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 GRID] %s | %s | source=%s",
                     G_GRID_STATUS,
                     G_GRID_DETAIL,
                     source);
      }
      G_GRID_LAST_SIGNATURE = signature;
   }
}
