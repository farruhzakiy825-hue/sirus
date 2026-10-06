//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 07_Detectors                                    |
//| Noise/path density, opportunity detectors                        |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// ============================================================================
double MarketNoiseLevel(double &reachability, string &detail)
{
   reachability = 1.0;
   detail = "";

   if(!EnableNoiseFilter || _Point <= 0.0)
      return 0.0;

   static int    nz_bar = -100000;
   static double nz_noise = 0.0;
   static double nz_reach = 1.0;
   static string nz_detail = "";
   if(nz_bar > G_BARS_SEEN) nz_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(nz_bar == G_BARS_SEEN)
   {
      reachability = nz_reach;
      detail = nz_detail;
      return nz_noise;
   }

   ENUM_TIMEFRAMES tf = NoiseTF;
   int look = MathMax(10, NoiseLookbackBars);

   double path = 0.0;
   double first = CandleClose(tf, look);
   double last  = CandleClose(tf, 1);
   if(first <= 0.0 || last <= 0.0)
      return 0.0;

   for(int i = look; i > 1; i--)
   {
      double a = CandleClose(tf, i);
      double b = CandleClose(tf, i - 1);
      if(a <= 0.0 || b <= 0.0)
         continue;
      path += MathAbs(b - a);
   }
   if(path <= 0.0)
      return 0.0;

   double displacement = MathAbs(last - first);
   double efficiency = displacement / path;          // 1 = straight line, 0 = round trip
   double noise = MathMax(0.0, MathMin(1.0, 1.0 - efficiency));

   // The question that actually matters for a scalper: given how this market moves,
   // is the target realistically reachable? Displacement per bar, extrapolated over
   // the horizon a basket normally has, against what the target needs.
   double disp_per_bar = displacement / (double)look / _Point;
   double target_pts = BaseBasketTPPoints();
   double horizon = (double)MathMax(5, NoiseReachHorizonBars);
   double expected_travel = disp_per_bar * horizon;
   reachability = (target_pts > 0.0) ? MathMax(0.0, MathMin(2.0, expected_travel / target_pts)) : 1.0;

   detail = StringFormat("noise %.0f%% (moved %.0f pts to travel %.0f pts), target reachability %.0f%%",
                         noise * 100.0, displacement / _Point, path / _Point, reachability * 100.0);

   nz_bar = G_BARS_SEEN;
   nz_noise = noise;
   nz_reach = reachability;
   nz_detail = detail;
   return noise;
}

// ============================================================================
double MarketStructureScale(double &scale_atr_ratio, string &detail)
{
   scale_atr_ratio = 0.0;
   detail = "";

   if(!EnableMarketScale || _Point <= 0.0)
      return 0.0;

   // Per-bar cache - this is read by several modules and only changes on new bars.
   static int    ms_bar = -100000;
   static double ms_val = 0.0;
   static double ms_ratio = 0.0;
   static string ms_detail = "";
   if(ms_bar > G_BARS_SEEN) ms_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ms_bar == G_BARS_SEEN && ms_val > 0.0)
   {
      scale_atr_ratio = ms_ratio;
      detail = ms_detail;
      return ms_val;
   }

   ZoneMapRefreshSwingCache();

   int t = ZMTFIndex(MarketScaleTF);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT)
      return 0.0;

   // Interleave highs and lows by recency so consecutive entries are genuine
   // swing-to-swing legs rather than high-to-high distances.
   double legs[60];
   int leg_n = 0;

   int hi_n = MathMin(G_ZMC_HIGH_COUNT[t], MarketScaleMaxSwings);
   int lo_n = MathMin(G_ZMC_LOW_COUNT[t], MarketScaleMaxSwings);
   int pairs = MathMin(hi_n, lo_n);

   for(int k = 0; k < pairs && leg_n < 60; k++)
   {
      double h = G_ZMC_HIGH_PRICE[t][k];
      double l = G_ZMC_LOW_PRICE[t][k];
      if(h <= 0.0 || l <= 0.0)
         continue;
      double leg = MathAbs(h - l) / _Point;
      if(leg > 0.0)
         legs[leg_n++] = leg;
   }

   if(leg_n < MathMax(3, MarketScaleMinSwings))
   {
      detail = "scale: not enough swings yet";
      return 0.0;
   }

   double sorted[];
   ArrayResize(sorted, leg_n);
   for(int c = 0; c < leg_n; c++)
      sorted[c] = legs[c];
   ArraySort(sorted);

   // Median: one violent swing should not redefine what "normal" means here.
   double median = (leg_n % 2 == 1)
                   ? sorted[leg_n / 2]
                   : (sorted[leg_n / 2 - 1] + sorted[leg_n / 2]) / 2.0;

   // V150b: the raw median jumps as swings enter and leave the sample window, and every threshold
   // downstream would jump with it - bands regrouping mid-basket for no reason the market made.
   // Three things stabilise it:
   //   1. a slow EMA, so the scale drifts rather than steps
   //   2. a dead band, so noise-level changes are ignored entirely
   //   3. a per-bar move limit, so even a genuine regime change is walked into over several bars
   static double ms_smoothed = 0.0;

   double target = median;
   if(ms_smoothed <= 0.0)
      ms_smoothed = target;                       // first reading - adopt it directly
   else
   {
      double change = MathAbs(target - ms_smoothed) / MathMax(1.0, ms_smoothed);
      if(change >= MarketScaleDeadBandPct / 100.0)
      {
         double a = MathMax(0.01, MathMin(1.0, MarketScaleSmoothAlpha));
         double next = ms_smoothed * (1.0 - a) + target * a;

         // Cap how far the scale may move in a single bar.
         double max_step = ms_smoothed * (MarketScaleMaxStepPct / 100.0);
         if(next > ms_smoothed + max_step) next = ms_smoothed + max_step;
         if(next < ms_smoothed - max_step) next = ms_smoothed - max_step;

         ms_smoothed = next;
      }
      // else: inside the dead band - the market has not really changed scale
   }

   double smoothed = ms_smoothed;

   double atr = ATRPointsManual(MarketScaleTF, ATRPeriod, 1);
   if(atr > 0.0)
      scale_atr_ratio = smoothed / atr;

   detail = StringFormat("market scale %.0f pts (%.1f x ATR, from %d swings, raw %.0f)",
                         smoothed, scale_atr_ratio, leg_n, median);

   ms_bar = G_BARS_SEEN;
   ms_val = smoothed;
   ms_ratio = scale_atr_ratio;
   ms_detail = detail;
   return smoothed;
}

// Adapts a configured points threshold to the market's own scale. The reference is
// what the setting was tuned against; when the market swings wider or tighter than
// that, the threshold moves with it - but only within bounds, so a misread scale
// cannot distort a threshold beyond recognition.
double ScaleAdjustedPoints(const double configured_points)
{
   if(!EnableMarketScale || configured_points <= 0.0)
      return configured_points;

   double ratio = 0.0;
   string sc_detail = "";
   double scale = MarketStructureScale(ratio, sc_detail);
   if(scale <= 0.0 || MarketScaleReferencePoints <= 0)
      return configured_points;

   double factor = scale / (double)MarketScaleReferencePoints;
   factor = MathMax(MarketScaleMinFactor, MathMin(MarketScaleMaxFactor, factor));
   return configured_points * factor;
}

// ============================================================================
double PathDensityAhead(const int entry_dir, double &largest_gap_pts, int &wall_count, string &detail)
{
   largest_gap_pts = 0.0;
   wall_count = 0;
   detail = "";

   if(!EnablePathDensity || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   // V179: per-bar cache by direction. This collects up to 160 levels, sorts them and merges
   // clusters - and it is called from the score engine and the dashboard on the same tick, for
   // an answer that cannot change until a bar closes.
   static int    pd_bar[3];
   static double pd_dens[3], pd_gap[3];
   static int    pd_walls[3];
   static string pd_det[3];
   static bool   pd_init = false;
   if(!pd_init) { for(int z = 0; z < 3; z++) pd_bar[z] = -100000; pd_init = true; }
   int pd_slot = (entry_dir > 0) ? 1 : 2;
   if(pd_bar[pd_slot] == G_BARS_SEEN)
   {
      largest_gap_pts = pd_gap[pd_slot];
      wall_count      = pd_walls[pd_slot];
      detail          = pd_det[pd_slot];
      return pd_dens[pd_slot];
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   ZoneMapRefreshSwingCache();

   int t = ZMTFIndex(PathDensityTF);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT)
      return 0.0;

   // V170f: the working range scales with the market too - $10 ahead means something different
   // when the market is swinging $2 a leg than when it is swinging $8.
   double range = ScaleAdjustedPoints(MathMax(1, PathDensityRangePoints)) * _Point;
   bool look_up = (entry_dir > 0);

   // Collect every level ahead within the working range - highs above a buy, lows
   // below a sell, since those are what price has to get through.
   double walls[80];
   int n = 0;

   for(int k = 0; k < G_ZMC_HIGH_COUNT[t] && n < 80; k++)
   {
      double v = G_ZMC_HIGH_PRICE[t][k];
      if(v <= 0.0) continue;
      bool ahead = look_up ? (v > mid && (v - mid) <= range)
                           : (v < mid && (mid - v) <= range);
      if(ahead) walls[n++] = v;
   }
   for(int k = 0; k < G_ZMC_LOW_COUNT[t] && n < 80; k++)
   {
      double v = G_ZMC_LOW_PRICE[t][k];
      if(v <= 0.0) continue;
      bool ahead = look_up ? (v > mid && (v - mid) <= range)
                           : (v < mid && (mid - v) <= range);
      if(ahead) walls[n++] = v;
   }

   if(n <= 0)
   {
      detail = "path: clear ahead";
      largest_gap_pts = range / _Point;
      pd_bar[pd_slot] = G_BARS_SEEN; pd_dens[pd_slot] = 0.0;
      pd_gap[pd_slot] = largest_gap_pts; pd_walls[pd_slot] = 0; pd_det[pd_slot] = detail;
      return 0.0;                       // nothing in the way at all
   }

   double tmp[];
   ArrayResize(tmp, n);
   for(int c = 0; c < n; c++)
      tmp[c] = walls[c];
   ArraySort(tmp);                      // ascending

   // Merge levels sitting effectively on top of each other - they are one wall, not
   // several, and counting them separately would exaggerate the density.
   double merged[80];
   int m = 0;
   // V150: what counts as "the same wall" depends on how widely this market swings.
   double merge_tol = ScaleAdjustedPoints(MathMax(1, PathDensityMergePoints)) * _Point;
   for(int c = 0; c < n; c++)
   {
      if(m < 80 && (m == 0 || (tmp[c] - merged[m - 1]) > merge_tol))
         merged[m++] = tmp[c];
   }

   wall_count = m;

   // Largest gap along the path, including the stretch from price to the first wall.
   double prev = mid;
   for(int c = 0; c < m; c++)
   {
      // Walk outward from price in the direction of travel.
      int idx = look_up ? c : (m - 1 - c);
      double gap = MathAbs(merged[idx] - prev) / _Point;
      if(gap > largest_gap_pts)
         largest_gap_pts = gap;
      prev = merged[idx];
   }
   // And the stretch beyond the final wall out to the edge of the working range.
   double tail = MathAbs((look_up ? (mid + range) : (mid - range)) - prev) / _Point;
   if(tail > largest_gap_pts)
      largest_gap_pts = tail;

   double range_pts = range / _Point;
   double density = (double)m / MathMax(1.0, range_pts / 1000.0);   // walls per $1

   detail = StringFormat("path: %d walls in %.0f pts (%.2f per $1), largest gap %.0f pts",
                         m, range_pts, density, largest_gap_pts);

   pd_bar[pd_slot] = G_BARS_SEEN; pd_dens[pd_slot] = density;
   pd_gap[pd_slot] = largest_gap_pts; pd_walls[pd_slot] = wall_count; pd_det[pd_slot] = detail;
   return density;
}

// ============================================================================
int LevelParticipantProfile(const double level, double &confidence, string &detail)
{
   confidence = 0.0;
   detail = "";

   if(!EnableParticipantModel || level <= 0.0 || _Point <= 0.0)
      return 0;

   double retail_pts = 0.0;
   double inst_pts   = 0.0;

   // --- 1. Round number: the classic retail marker -------------------------------
   bool is_round = false;
   if(ZoneRoundNumberStep > 0.0)
   {
      double step = ZoneRoundNumberStep;
      double nearest = MathRound(level / step) * step;
      double dist_pts = MathAbs(level - nearest) / _Point;
      if(dist_pts <= ZoneRoundNumberTolerancePoints)
      {
         is_round = true;
         retail_pts += ParticipantRoundNumberWeight;
      }
   }

   // --- 2. How much TIME has price spent at this level? ---------------------------
   // Size accumulates through time in a band; retail levels are single points price
   // touched and left.
   int touches = (int)ZoneMapConfluenceCount(level);
   double band_lo = 0.0, band_hi = 0.0;
   string band_detail = "";
   bool inside_band = ZonePriceInsideBand(band_lo, band_hi, band_detail);
   double band_width_pts = (inside_band && band_hi > band_lo) ? (band_hi - band_lo) / _Point : 0.0;

   if(band_width_pts >= (double)ParticipantBandWidthPoints)
      inst_pts += ParticipantBandWeight;      // a real area, not a line

   // --- 3. Has it actually HELD? --------------------------------------------------
   // The decisive test. A level that has been tested several times and is still
   // there has genuine orders behind it - including a round number, which stops
   // being a magnet once it has proven it holds.
   if(touches >= ParticipantHoldTouches)
   {
      double decay = ZoneDecayFactor(level);
      if(decay <= ParticipantMaxDecayToHold)
         inst_pts += ParticipantHeldWeight;   // tested repeatedly and still standing
      else
         retail_pts += ParticipantHeldWeight * 0.5;   // tested and wearing through - it will go
   }
   else if(is_round)
   {
      // An untested round number is the purest magnet: obvious to everyone, defended
      // by no one.
      retail_pts += ParticipantUntestedRoundWeight;
   }

   double total = retail_pts + inst_pts;
   if(total <= 0.0001)
   {
      detail = "level profile: unclear";
      return 0;
   }

   int    profile = (inst_pts > retail_pts) ? 1 : -1;
   double lead    = MathMax(inst_pts, retail_pts);
   confidence = MathMax(0.0, MathMin(1.0, (lead - MathMin(inst_pts, retail_pts)) / total));

   detail = StringFormat("%s level (%.0f%% - %s%d touches, band %.0f pts)",
                         (profile > 0 ? "institutional" : "retail"),
                         confidence * 100.0,
                         (is_round ? "round, " : ""),
                         touches, band_width_pts);
   return profile;
}

// ============================================================================
double FalseBreakTrapQuality(const double level, const int break_dir, string &detail)
{
   detail = "";
   if(!EnableTrapQuality || level <= 0.0 || break_dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = SignalTF;
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   int look = MathMax(4, TrapQualityLookbackBars);

   double deepest = 0.0;      // furthest penetration beyond the level, in points
   int    bars_beyond = 0;    // how long price held on the far side

   for(int i = 1; i <= look; i++)
   {
      double c = CandleClose(tf, i);
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      if(c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;

      // break_dir > 0 means price broke ABOVE the level (a bull trap forming).
      double beyond = (break_dir > 0) ? (h - level) / _Point
                                      : (level - l) / _Point;
      if(beyond > deepest)
         deepest = beyond;

      // A CLOSE beyond the level is what convinces traders - a wick does not.
      bool closed_beyond = (break_dir > 0) ? (c > level) : (c < level);
      if(closed_beyond)
         bars_beyond++;
   }

   if(deepest <= 0.0)
      return 0.0;

   // 1. Depth relative to ATR - a break worth believing.
   double depth_atr = deepest / atr;
   double depth_q = MathMax(0.0, MathMin(1.0, depth_atr / MathMax(0.1, TrapQualityFullDepthATR)));

   // 2. Persistence - how many bars actually closed on the far side.
   double hold_q = MathMax(0.0, MathMin(1.0,
                   (double)bars_beyond / (double)MathMax(1, TrapQualityFullHoldBars)));

   // 3. Snap-back speed - how far price has already reversed from the extreme.
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   double back_pts = 0.0;
   if(mid > 0.0)
      back_pts = (break_dir > 0) ? ((level + deepest * _Point) - mid) / _Point
                                 : (mid - (level - deepest * _Point)) / _Point;
   double snap_q = MathMax(0.0, MathMin(1.0, back_pts / MathMax(1.0, deepest)));

   // Persistence is weighted highest: without it there was no trap, only a wick.
   double quality = depth_q * TrapWeightDepth
                  + hold_q  * TrapWeightHold
                  + snap_q  * TrapWeightSnap;
   double wsum = TrapWeightDepth + TrapWeightHold + TrapWeightSnap;
   if(wsum > 0.0)
      quality /= wsum;

   quality = MathMax(0.0, MathMin(1.0, quality));

   detail = StringFormat("trap %.2f (depth %.1f ATR, held %d bars, snapped %.0f%%)",
                         quality, depth_atr, bars_beyond, snap_q * 100.0);
   return quality;
}

// catches multi-candle failed breakouts using real, swing-confirmed, strength-scored walls.
bool DetectFakeBreakoutReturnBuy(string &reason, int &score)
{
   if(!EnableFakeBreakoutReturn)
   {
      reason = "fake breakout return disabled";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(bid <= 0.0)
   {
      reason = "fbr buy data not ready";
      return false;
   }

   double sup = ZoneMapNearestSupport(bid + MathMax(1, FBRBreachPoints) * _Point);
   if(sup <= 0.0)
   {
      reason = "fbr buy: no wall found";
      return false;
   }

   double strength = ZoneMapStrength(sup);
   if(strength < FBRMinZoneStrength)
   {
      reason = StringFormat("fbr buy: wall too weak %.2f/%.2f", strength, FBRMinZoneStrength);
      return false;
   }

   double breach = MathMax(1, FBRBreachPoints) * _Point;
   bool broke = false;
   int broke_ago = -1;
   for(int i = 2; i <= MathMax(2, FBRLookbackBars) + 1; i++)
   {
      double low_i = CandleLow(SignalTF, i);
      if(low_i > 0.0 && low_i < sup - breach)
      {
         broke = true;
         broke_ago = i;
         break;
      }
   }

   if(!broke)
   {
      reason = "fbr buy: no recent genuine breach";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   bool returned = (c1 > sup);
   bool bullish_close = (c1 >= o1);

   // V147: a wick that poked through and came back trapped nobody. Weight the setup by how
   // convincing the break was before it failed - depth, persistence, and the speed of the snap.
   string tq_detail = "";
   double trap_q = FalseBreakTrapQuality(sup, -1, tq_detail);   // price broke BELOW the support
   // V188: a weak trap reading no longer rejects the setup outright. Rejecting here happens BEFORE
   // the score engine sees anything, so a setup with every other quality behind it was discarded on
   // one reading - and the whole design of this EA is that warnings shape the trade rather than veto
   // it. The reading still counts: it simply arrives as score, where the rest of the picture can
   // answer it.
   bool weak_trap_buy = (EnableTrapQuality && trap_q < TrapQualityMinToTrade);

   score = 0;
   if(returned) score += 3;
   if(bullish_close) score += 1;
   if(strength >= FBRMinZoneStrength) score += 1;
   if(EnableTrapQuality && trap_q >= TrapQualityStrong) score += TrapQualityBonus;
   else if(weak_trap_buy) score -= TrapQualityWeakPenalty;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;

   reason = StringFormat("fbr buy: wall=%.2f (str=%.2f) broke %d bars ago, close=%.2f returned=%s score=%d",
                         sup, strength, broke_ago, c1, BoolText(returned), score);

   if((FBRPrintOnUse && VerboseLogs) && returned)
      PrintFormat("[SIRUS v31.6c FAKE BREAKOUT RETURN] BUY: %s", reason);

   return (broke && returned);
}

bool DetectFakeBreakoutReturnSell(string &reason, int &score)
{
   if(!EnableFakeBreakoutReturn)
   {
      reason = "fake breakout return disabled";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(ask <= 0.0)
   {
      reason = "fbr sell data not ready";
      return false;
   }

   double res = ZoneMapNearestResistance(ask - MathMax(1, FBRBreachPoints) * _Point);
   if(res <= 0.0)
   {
      reason = "fbr sell: no wall found";
      return false;
   }

   double strength = ZoneMapStrength(res);
   if(strength < FBRMinZoneStrength)
   {
      reason = StringFormat("fbr sell: wall too weak %.2f/%.2f", strength, FBRMinZoneStrength);
      return false;
   }

   double breach = MathMax(1, FBRBreachPoints) * _Point;
   bool broke = false;
   int broke_ago = -1;
   for(int i = 2; i <= MathMax(2, FBRLookbackBars) + 1; i++)
   {
      double high_i = CandleHigh(SignalTF, i);
      if(high_i > 0.0 && high_i > res + breach)
      {
         broke = true;
         broke_ago = i;
         break;
      }
   }

   if(!broke)
   {
      reason = "fbr sell: no recent genuine breach";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   bool returned = (c1 < res);
   bool bearish_close = (c1 <= o1);

   // V147: mirror of the BUY case - weight by how convincing the break was before it failed.
   string tq_detail = "";
   double trap_q = FalseBreakTrapQuality(res, 1, tq_detail);   // price broke ABOVE the resistance
   // V188: a weak trap reading no longer rejects the setup outright. Rejecting here happens BEFORE
   // the score engine sees anything, so a setup with every other quality behind it was discarded on
   // one reading - and the whole design of this EA is that warnings shape the trade rather than veto
   // it. The reading still counts: it simply arrives as score, where the rest of the picture can
   // answer it.
   bool weak_trap_sell = (EnableTrapQuality && trap_q < TrapQualityMinToTrade);

   score = 0;
   if(returned) score += 3;
   if(bearish_close) score += 1;
   if(strength >= FBRMinZoneStrength) score += 1;
   if(EnableTrapQuality && trap_q >= TrapQualityStrong) score += TrapQualityBonus;
   else if(weak_trap_sell) score -= TrapQualityWeakPenalty;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;   // REVERT(orderflow-sign): OrderFlowConvictionSign is a VOLUME-MAGNITUDE classifier (+1 = heavy/confirmed volume, -1 = thin/weak, 0 = ordinary) - it carries NO bullish/bearish direction. `> 0` = "this move traded on real volume", which confirms a sell setup exactly as it confirms a buy one. See DetectSweepBuy's own note.

   reason = StringFormat("fbr sell: wall=%.2f (str=%.2f) broke %d bars ago, close=%.2f returned=%s score=%d",
                         res, strength, broke_ago, c1, BoolText(returned), score);

   if((FBRPrintOnUse && VerboseLogs) && returned)
      PrintFormat("[SIRUS v31.6c FAKE BREAKOUT RETURN] SELL: %s", reason);

   return (broke && returned);
}

// V31.6e NEW detector (was a named-but-unimplemented opportunity type before this): Near-Zone
// Reaction. Softer and EARLIER than Sweep - price is approaching a real, strong wall but has
// NOT tested/broken it yet, only showing a small early rejection sign. Sweep requires the wall
// to already have been swept (wick through, close back); this catches the reaction BEFORE that
// happens, at the cost of a lower-conviction signal (hence the smaller wick-ratio threshold and
// requirement that a zone actually exists nearby).
bool DetectNearZoneReactionBuy(string &reason, int &score)
{
   if(!EnableNearZoneReaction)
   {
      reason = "near zone reaction disabled";
      return false;
   }

   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(bid <= 0.0)
   {
      reason = "nzr buy data not ready";
      return false;
   }

   double sup = ZoneMapNearestSupport(bid + MathMax(1, NearZoneReactionRangePoints) * _Point);
   if(sup <= 0.0 || sup > bid)
   {
      reason = "nzr buy: no support nearby";
      return false;
   }

   double dist = (bid - sup) / _Point;
   if(dist > NearZoneReactionRangePoints)
   {
      reason = StringFormat("nzr buy: distance %.0f out of range", dist);
      return false;
   }

   double strength = ZoneMapStrength(sup);
   if(strength < NearZoneReactionMinStrength)
   {
      reason = StringFormat("nzr buy: zone too weak %.2f/%.2f", strength, NearZoneReactionMinStrength);
      return false;
   }

   double l1 = CandleLow(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double lower = LowerWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(range <= 0.0)
   {
      reason = "nzr buy: no range data";
      return false;
   }

   bool small_rejection = (lower / range >= 0.20);
   bool bullish_close = (c1 >= o1);

   score = 2;
   if(small_rejection) score += 2;
   if(bullish_close) score += 1;
   if(strength >= NearZoneReactionMinStrength) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;

   reason = StringFormat("nzr buy: support=%.2f dist=%.0f str=%.2f rejection=%s score=%d",
                         sup, dist, strength, BoolText(small_rejection), score);

   return (small_rejection && bullish_close);
}

bool DetectNearZoneReactionSell(string &reason, int &score)
{
   if(!EnableNearZoneReaction)
   {
      reason = "near zone reaction disabled";
      return false;
   }

   double ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(ask <= 0.0)
   {
      reason = "nzr sell data not ready";
      return false;
   }

   double res = ZoneMapNearestResistance(ask - MathMax(1, NearZoneReactionRangePoints) * _Point);
   if(res <= 0.0 || res < ask)
   {
      reason = "nzr sell: no resistance nearby";
      return false;
   }

   double dist = (res - ask) / _Point;
   if(dist > NearZoneReactionRangePoints)
   {
      reason = StringFormat("nzr sell: distance %.0f out of range", dist);
      return false;
   }

   double strength = ZoneMapStrength(res);
   if(strength < NearZoneReactionMinStrength)
   {
      reason = StringFormat("nzr sell: zone too weak %.2f/%.2f", strength, NearZoneReactionMinStrength);
      return false;
   }

   double h1 = CandleHigh(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(range <= 0.0)
   {
      reason = "nzr sell: no range data";
      return false;
   }

   bool small_rejection = (upper / range >= 0.20);
   bool bearish_close = (c1 <= o1);

   score = 2;
   if(small_rejection) score += 2;
   if(bearish_close) score += 1;
   if(strength >= NearZoneReactionMinStrength) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;   // REVERT(orderflow-sign): volume-magnitude, not direction - see note at the fake-breakout sell above.

   reason = StringFormat("nzr sell: resistance=%.2f dist=%.0f str=%.2f rejection=%s score=%d",
                         res, dist, strength, BoolText(small_rejection), score);

   return (small_rejection && bearish_close);
}

bool DetectRangeEdgeBuy(string &reason, int &score)
{
   if(!ScannerAllowRangeEdge || (G_MARKET_STATE != MARKET_RANGE && G_MARKET_STATE != MARKET_DEAD))
   {
      reason = "not range/dead or disabled";
      return false;
   }

   double low = RecentLowForScanner();
   double high = RecentHighForScanner();
   double c1 = CandleClose(SignalTF, 1);
   double lower = LowerWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(low <= 0.0 || high <= low || c1 <= 0.0 || range <= 0.0)
   {
      reason = "range buy data not ready";
      return false;
   }

   double width_points = (high - low) / _Point;
   double dist_low = (c1 - low) / _Point;
   double edge_limit = width_points * RangeEdgePercent / 100.0;
   bool near_bottom = (dist_low >= 0.0 && dist_low <= edge_limit);
   bool rejection = (lower / range >= 0.28);

   score = 0;
   if(near_bottom) score += 2;
   if(rejection) score += 2;
   if(IsBullishCandle(SignalTF, 1)) score += 1;

   G_OPP_NEAR_LOW_DIST = dist_low;
   G_OPP_ROOM_POINTS = (high - c1) / _Point;

   reason = StringFormat("rangeBottom=%s | distLow=%.0f <= %.0f | roomUp=%.0f | lowerWick/range=%.2f | score=%d",
                         BoolText(near_bottom), dist_low, edge_limit, G_OPP_ROOM_POINTS, lower / range, score);

   return (near_bottom && rejection);
}

bool DetectRangeEdgeSell(string &reason, int &score)
{
   if(!ScannerAllowRangeEdge || (G_MARKET_STATE != MARKET_RANGE && G_MARKET_STATE != MARKET_DEAD))
   {
      reason = "not range/dead or disabled";
      return false;
   }

   double low = RecentLowForScanner();
   double high = RecentHighForScanner();
   double c1 = CandleClose(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(low <= 0.0 || high <= low || c1 <= 0.0 || range <= 0.0)
   {
      reason = "range sell data not ready";
      return false;
   }

   double width_points = (high - low) / _Point;
   double dist_high = (high - c1) / _Point;
   double edge_limit = width_points * RangeEdgePercent / 100.0;
   bool near_top = (dist_high >= 0.0 && dist_high <= edge_limit);
   bool rejection = (upper / range >= 0.28);

   score = 0;
   if(near_top) score += 2;
   if(rejection) score += 2;
   if(IsBearishCandle(SignalTF, 1)) score += 1;

   G_OPP_NEAR_HIGH_DIST = dist_high;
   G_OPP_ROOM_POINTS = (c1 - low) / _Point;

   reason = StringFormat("rangeTop=%s | distHigh=%.0f <= %.0f | roomDown=%.0f | upperWick/range=%.2f | score=%d",
                         BoolText(near_top), dist_high, edge_limit, G_OPP_ROOM_POINTS, upper / range, score);

   return (near_top && rejection);
}

bool DetectPullbackBuy(string &reason, int &score)
{
   if(!ScannerAllowPullback)
   {
      reason = "pullback disabled";
      return false;
   }

   bool market_ok = (G_MARKET_STATE == MARKET_PULLBACK || G_MARKET_STATE == MARKET_TREND_UP);
   double c1 = CandleClose(SignalTF, 1);
   double c2 = CandleClose(SignalTF, 2);
   double body = CandleBodyPoints(SignalTF, 1);

   if(!market_ok || c1 <= 0.0 || c2 <= 0.0)
   {
      reason = "not pullback/uptrend or data not ready";
      return false;
   }

   bool continuation = (c1 > c2 && IsBullishCandle(SignalTF, 1));

   score = 0;
   if(G_MARKET_STATE == MARKET_PULLBACK) score += 2;
   if(continuation) score += 3;
   if(body >= MathMax(DeadATRThresholdPoints * 0.5, 200.0)) score += 1;

   reason = StringFormat("up continuation=%s | c1=%.2f c2=%.2f body=%.0f | score=%d",
                         BoolText(continuation), c1, c2, body, score);

   return continuation;
}

bool DetectPullbackSell(string &reason, int &score)
{
   if(!ScannerAllowPullback)
   {
      reason = "pullback disabled";
      return false;
   }

   bool market_ok = (G_MARKET_STATE == MARKET_PULLBACK || G_MARKET_STATE == MARKET_TREND_DOWN);
   double c1 = CandleClose(SignalTF, 1);
   double c2 = CandleClose(SignalTF, 2);
   double body = CandleBodyPoints(SignalTF, 1);

   if(!market_ok || c1 <= 0.0 || c2 <= 0.0)
   {
      reason = "not pullback/downtrend or data not ready";
      return false;
   }

   bool continuation = (c1 < c2 && IsBearishCandle(SignalTF, 1));

   score = 0;
   if(G_MARKET_STATE == MARKET_PULLBACK) score += 2;
   if(continuation) score += 3;
   if(body >= MathMax(DeadATRThresholdPoints * 0.5, 200.0)) score += 1;

   reason = StringFormat("down continuation=%s | c1=%.2f c2=%.2f body=%.0f | score=%d",
                         BoolText(continuation), c1, c2, body, score);

   return continuation;
}

bool DetectMomentumBuy(string &reason, int &score)
{
   if(!ScannerAllowMomentum)
   {
      reason = "momentum disabled";
      return false;
   }

   if(G_MARKET_STATE != MARKET_IMPULSE && G_MARKET_STATE != MARKET_TREND_UP)
   {
      reason = "not impulse/uptrend";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double c2 = CandleClose(SignalTF, 2);
   double body = CandleBodyPoints(SignalTF, 1);
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);

   if(c1 <= 0.0 || c2 <= 0.0 || atr <= 0.0)
   {
      reason = "momentum buy data not ready";
      return false;
   }

   bool momentum = (c1 > c2 && IsBullishCandle(SignalTF, 1) && body >= atr * 0.55);

   score = 0;
   if(momentum) score += 3;
   if(G_MARKET_STATE == MARKET_TREND_UP) score += 2;

   reason = StringFormat("buy momentum=%s | body=%.0f atr=%.0f | score=%d", BoolText(momentum), body, atr, score);
   return momentum;
}

bool DetectMomentumSell(string &reason, int &score)
{
   if(!ScannerAllowMomentum)
   {
      reason = "momentum disabled";
      return false;
   }

   if(G_MARKET_STATE != MARKET_IMPULSE && G_MARKET_STATE != MARKET_TREND_DOWN)
   {
      reason = "not impulse/downtrend";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double c2 = CandleClose(SignalTF, 2);
   double body = CandleBodyPoints(SignalTF, 1);
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);

   if(c1 <= 0.0 || c2 <= 0.0 || atr <= 0.0)
   {
      reason = "momentum sell data not ready";
      return false;
   }

   bool momentum = (c1 < c2 && IsBearishCandle(SignalTF, 1) && body >= atr * 0.55);

   score = 0;
   if(momentum) score += 3;
   if(G_MARKET_STATE == MARKET_TREND_DOWN) score += 2;

   reason = StringFormat("sell momentum=%s | body=%.0f atr=%.0f | score=%d", BoolText(momentum), body, atr, score);
   return momentum;
}

// V31.6j new: Multi-Candle Pattern - was only ever checking ONE candle's wick ratio for
// exhaustion. Real exhaustion often shows across several candles: three consecutive same-
// direction candles with SHRINKING bodies (each push weaker than the last) is a classic
// deceleration signature that a single-candle check can't see.
bool MultiCandleShrinkingPattern(const int direction)
{
   if(!EnableMultiCandlePattern)
      return false;

   double o1 = CandleOpen(SignalTF, 1), c1 = CandleClose(SignalTF, 1);
   double o2 = CandleOpen(SignalTF, 2), c2 = CandleClose(SignalTF, 2);
   double o3 = CandleOpen(SignalTF, 3), c3 = CandleClose(SignalTF, 3);

   if(o1 <= 0.0 || o2 <= 0.0 || o3 <= 0.0 || c1 <= 0.0 || c2 <= 0.0 || c3 <= 0.0)
      return false;

   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   double body3 = MathAbs(c3 - o3);

   if(body1 <= 0.0 || body2 <= 0.0 || body3 <= 0.0)
      return false;

   bool shrinking = (body3 > body2 && body2 > body1);

   if(direction > 0)
   {
      // BUY exhaustion setup: three shrinking DOWN candles (selling losing steam)
      bool all_bearish = (c1 < o1) && (c2 < o2) && (c3 < o3);
      return shrinking && all_bearish;
   }

   // SELL exhaustion setup: three shrinking UP candles (buying losing steam)
   bool all_bullish = (c1 > o1) && (c2 > o2) && (c3 > o3);
   return shrinking && all_bullish;
}

bool DetectExhaustionBuy(string &reason, int &score)
{
   if(!ScannerAllowExhaustion || G_MARKET_STATE != MARKET_EXHAUSTION)
   {
      reason = "not exhaustion or disabled";
      return false;
   }

   double lower = LowerWickPoints(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(range <= 0.0)
   {
      reason = "exhaustion buy data not ready";
      return false;
   }

   bool buy_exhaust = (lower > upper && lower / range >= ExhaustionWickRatio);
   bool multi_candle = MultiCandleShrinkingPattern(1);

   score = 0;
   if(buy_exhaust) score += 4;
   if(IsBullishCandle(SignalTF, 1)) score += 1;
   if(multi_candle) score += MultiCandleBonus;

   reason = StringFormat("buyExhaust=%s | lower=%.0f upper=%.0f range=%.0f | multiCandle=%s | score=%d",
                         BoolText(buy_exhaust), lower, upper, range, BoolText(multi_candle), score);
   return buy_exhaust;
}

bool DetectExhaustionSell(string &reason, int &score)
{
   if(!ScannerAllowExhaustion || G_MARKET_STATE != MARKET_EXHAUSTION)
   {
      reason = "not exhaustion or disabled";
      return false;
   }

   double lower = LowerWickPoints(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(range <= 0.0)
   {
      reason = "exhaustion sell data not ready";
      return false;
   }

   bool sell_exhaust = (upper > lower && upper / range >= ExhaustionWickRatio);
   bool multi_candle = MultiCandleShrinkingPattern(-1);

   score = 0;
   if(sell_exhaust) score += 4;
   if(IsBearishCandle(SignalTF, 1)) score += 1;
   if(multi_candle) score += MultiCandleBonus;

   reason = StringFormat("sellExhaust=%s | upper=%.0f lower=%.0f range=%.0f | multiCandle=%s | score=%d",
                         BoolText(sell_exhaust), upper, lower, range, BoolText(multi_candle), score);
   return sell_exhaust;
}

// ============================================================================
// V31.6z1 NEW: BREAKOUT CONTINUATION - the mirror of Fake Breakout Return. Price breaks a
// real, zone-confirmed level with a strong, non-rejecting close - bet the break is genuine.
// ============================================================================
bool DetectBreakoutContinuationBuy(string &reason, int &score)
{
   if(!EnableBreakoutContinuation)
   {
      reason = "breakout continuation disabled";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double h1 = CandleHigh(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double range = h1 - l1;

   if(c1 <= 0.0 || range <= 0.0)
   {
      reason = "breakout buy data not ready";
      return false;
   }

   double res = ZoneMapNearestResistance(c1 - MathMax(1, BreakoutSearchPoints) * _Point);
   if(res <= 0.0)
   {
      reason = "no resistance to break";
      return false;
   }

   double strength = ZoneMapStrength(res);

   // V31.6z18 fix: same as the Sell version - strength now scales the required confirm-
   // distance UP instead of just adding bonus points for breaking something strong.
   double effective_confirm_points = BreakoutConfirmPoints;
   if(strength > 1.0)
      effective_confirm_points = BreakoutConfirmPoints * (1.0 + (strength - 1.0) * BreakoutStrengthConfirmScale);

   bool broke = (c1 > res + effective_confirm_points * _Point);
   double upper_wick = h1 - MathMax(c1, o1);
   bool strong_close = ((upper_wick / range) < BreakoutMaxWickRatio);
   bool bullish = (c1 > o1);

   score = 0;
   if(broke) score += 3;
   if(strong_close) score += 2;
   if(bullish) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;

   reason = StringFormat("breakout buy: broke=%s res=%.2f(str=%.1f,needed=%.0fpts) strongClose=%s score=%d",
                         BoolText(broke), res, strength, effective_confirm_points, BoolText(strong_close), score);
   return (broke && strong_close && bullish);
}

bool DetectBreakoutContinuationSell(string &reason, int &score)
{
   if(!EnableBreakoutContinuation)
   {
      reason = "breakout continuation disabled";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double h1 = CandleHigh(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double range = h1 - l1;

   if(c1 <= 0.0 || range <= 0.0)
   {
      reason = "breakout sell data not ready";
      return false;
   }

   double sup = ZoneMapNearestSupport(c1 + MathMax(1, BreakoutSearchPoints) * _Point);
   if(sup <= 0.0)
   {
      reason = "no support to break";
      return false;
   }

   double strength = ZoneMapStrength(sup);

   // V31.6z18 fix: real bug found via live testing (support broke, big DD). Strength was only
   // ever used as a BONUS - "broke a stronger zone = more confident" - completely backwards.
   // A zone proven strong across many weeks and timeframes needs to be broken MORE
   // convincingly, not rewarded with extra points just for having been strong. Scale the
   // required confirm-distance UP with strength instead.
   double effective_confirm_points = BreakoutConfirmPoints;
   if(strength > 1.0)
      effective_confirm_points = BreakoutConfirmPoints * (1.0 + (strength - 1.0) * BreakoutStrengthConfirmScale);

   bool broke = (c1 < sup - effective_confirm_points * _Point);
   double lower_wick = MathMin(c1, o1) - l1;
   bool strong_close = ((lower_wick / range) < BreakoutMaxWickRatio);
   bool bearish = (c1 < o1);

   score = 0;
   if(broke) score += 3;
   if(strong_close) score += 2;
   if(bearish) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;   // REVERT(orderflow-sign): volume-magnitude, not direction - see note at the fake-breakout sell above.

   reason = StringFormat("breakout sell: broke=%s sup=%.2f(str=%.1f,needed=%.0fpts) strongClose=%s score=%d",
                         BoolText(broke), sup, strength, effective_confirm_points, BoolText(strong_close), score);
   return (broke && strong_close && bearish);
}

// ============================================================================
// V31.6z1 NEW: TREND RIDE - classic "buy the dip in an uptrend". Strong ADX-confirmed trend
// plus a shallow pullback (within ATR multiple, not a reversal) that's now resuming.
// ============================================================================
bool DetectTrendRideBuy(string &reason, int &score)
{
   if(!EnableTrendRide)
   {
      reason = "trend ride disabled";
      return false;
   }

   double adx = 0.0, plus_di = 0.0, minus_di = 0.0;
   CachedADXSnapshot(TrendRideTF, TrendStrengthPeriod, adx, plus_di, minus_di);

   if(adx <= 0.0 || plus_di <= 0.0 || minus_di <= 0.0)
   {
      reason = "trend ride ADX not ready";
      return false;
   }

   bool strong_up = (adx >= TrendRideMinADX) && (plus_di > minus_di);
   if(!strong_up)
   {
      reason = "no strong uptrend";
      return false;
   }

   double atr = ATRPointsManual(TrendRideTF, ATRPeriod, 1);
   double recent_low = LowestLow(TrendRideTF, TrendRidePullbackLookback, 1);
   double c1 = CandleClose(TrendRideTF, 1);
   double o1 = CandleOpen(TrendRideTF, 1);

   if(atr <= 0.0 || recent_low <= 0.0 || c1 <= 0.0)
   {
      reason = "trend ride data not ready";
      return false;
   }

   double pullback_pts = (c1 - recent_low) / _Point;
   bool shallow_pullback = (pullback_pts >= 0.0 && pullback_pts <= atr * TrendRideMaxPullbackATRMult);
   bool resuming = (c1 > o1);

   score = 0;
   if(strong_up) score += 3;
   if(shallow_pullback) score += 2;
   if(resuming) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("trend ride buy: adx=%.0f pullback=%.0fpts(atr-mult ok=%s) resuming=%s score=%d",
                         adx, pullback_pts, BoolText(shallow_pullback), BoolText(resuming), score);
   return (strong_up && shallow_pullback && resuming);
}

bool DetectTrendRideSell(string &reason, int &score)
{
   if(!EnableTrendRide)
   {
      reason = "trend ride disabled";
      return false;
   }

   double adx = 0.0, plus_di = 0.0, minus_di = 0.0;
   CachedADXSnapshot(TrendRideTF, TrendStrengthPeriod, adx, plus_di, minus_di);

   if(adx <= 0.0 || plus_di <= 0.0 || minus_di <= 0.0)
   {
      reason = "trend ride ADX not ready";
      return false;
   }

   bool strong_down = (adx >= TrendRideMinADX) && (minus_di > plus_di);
   if(!strong_down)
   {
      reason = "no strong downtrend";
      return false;
   }

   double atr = ATRPointsManual(TrendRideTF, ATRPeriod, 1);
   double recent_high = HighestHigh(TrendRideTF, TrendRidePullbackLookback, 1);
   double c1 = CandleClose(TrendRideTF, 1);
   double o1 = CandleOpen(TrendRideTF, 1);

   if(atr <= 0.0 || recent_high <= 0.0 || c1 <= 0.0)
   {
      reason = "trend ride data not ready";
      return false;
   }

   double pullback_pts = (recent_high - c1) / _Point;
   bool shallow_pullback = (pullback_pts >= 0.0 && pullback_pts <= atr * TrendRideMaxPullbackATRMult);
   bool resuming = (c1 < o1);

   score = 0;
   if(strong_down) score += 3;
   if(shallow_pullback) score += 2;
   if(resuming) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("trend ride sell: adx=%.0f pullback=%.0fpts(atr-mult ok=%s) resuming=%s score=%d",
                         adx, pullback_pts, BoolText(shallow_pullback), BoolText(resuming), score);
   return (strong_down && shallow_pullback && resuming);
}

// ============================================================================
// V31.6z1 NEW: SWING CONTINUATION - the mirror of Trend Reversal. After a pullback WITHIN
// an established trend, a fresh swing point that CONTINUES the existing HH/HL (or LH/LL)
// sequence confirms the trend is intact, not reversing.
// ============================================================================
bool DetectSwingContinuationBuy(string &reason, int &score)
{
   if(!EnableSwingContinuation)
   {
      reason = "swing continuation disabled";
      return false;
   }

   int depth = MathMax(1, SwingContinuationDepth);
   int lookback = MathMax(depth * 3, SwingContinuationLookback);

   double low1 = 0.0, low2 = 0.0;
   int low1_shift = -1, low2_shift = -1;
   bool got_lows = FindLastTwoSwingLows(SwingContinuationTF, lookback, depth, low1, low1_shift, low2, low2_shift);

   double high1 = 0.0, high2 = 0.0;
   int high1_shift = -1, high2_shift = -1;
   bool got_highs = FindLastTwoSwingHighs(SwingContinuationTF, lookback, depth, high1, high1_shift, high2, high2_shift);

   if(!got_lows || !got_highs)
   {
      reason = "swing continuation: not enough swing data";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   // Higher-Low continuing an existing uptrend structure, confirmed by breaking back above
   // the most recent swing high.
   bool hh_hl_continuing = (low1 > low2 && high1 > high2 && mid > high1);

   score = 0;
   if(hh_hl_continuing) score += 4;
   if(low1 > low2) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("swing continuation buy: low %.2f->%.2f, high %.2f->%.2f, HH/HL=%s score=%d",
                         low2, low1, high2, high1, BoolText(hh_hl_continuing), score);
   return hh_hl_continuing;
}

bool DetectSwingContinuationSell(string &reason, int &score)
{
   if(!EnableSwingContinuation)
   {
      reason = "swing continuation disabled";
      return false;
   }

   int depth = MathMax(1, SwingContinuationDepth);
   int lookback = MathMax(depth * 3, SwingContinuationLookback);

   double low1 = 0.0, low2 = 0.0;
   int low1_shift = -1, low2_shift = -1;
   bool got_lows = FindLastTwoSwingLows(SwingContinuationTF, lookback, depth, low1, low1_shift, low2, low2_shift);

   double high1 = 0.0, high2 = 0.0;
   int high1_shift = -1, high2_shift = -1;
   bool got_highs = FindLastTwoSwingHighs(SwingContinuationTF, lookback, depth, high1, high1_shift, high2, high2_shift);

   if(!got_lows || !got_highs)
   {
      reason = "swing continuation: not enough swing data";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   bool lh_ll_continuing = (high1 < high2 && low1 < low2 && mid < low1);

   score = 0;
   if(lh_ll_continuing) score += 4;
   if(high1 < high2) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("swing continuation sell: high %.2f->%.2f, low %.2f->%.2f, LH/LL=%s score=%d",
                         high2, high1, low2, low1, BoolText(lh_ll_continuing), score);
   return lh_ll_continuing;
}

// ============================================================================
// V31.6z1 NEW: MOVING AVERAGE BOUNCE - price pulls back to a rising/falling MA within a
// confirmed trend and bounces. Simple, well-known trend-continuation entry.
// ============================================================================
bool DetectMABounceBuy(string &reason, int &score)
{
   if(!EnableMABounce)
   {
      reason = "MA bounce disabled";
      return false;
   }

   double sma_now = SMA(MABounceTF, MABouncePeriod, 1);
   double sma_prev = SMA(MABounceTF, MABouncePeriod, MathMax(2, MABounceSlopeLookback));

   if(sma_now <= 0.0 || sma_prev <= 0.0)
   {
      reason = "MA bounce data not ready";
      return false;
   }

   bool ma_rising = (sma_now > sma_prev);

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   double l1 = CandleLow(MABounceTF, 1);
   double c1 = CandleClose(MABounceTF, 1);
   double o1 = CandleOpen(MABounceTF, 1);
   double tol = MathMax(1, MABounceTolerancePoints) * _Point;

   bool touched_ma = (l1 <= sma_now + tol);
   bool bounced_above = (c1 > sma_now && c1 > o1);

   score = 0;
   if(ma_rising) score += 2;
   if(touched_ma) score += 2;
   if(bounced_above) score += 2;
   if(mid > sma_now) score += 1;

   reason = StringFormat("MA bounce buy: sma=%.2f rising=%s touched=%s bounced=%s score=%d",
                         sma_now, BoolText(ma_rising), BoolText(touched_ma), BoolText(bounced_above), score);
   return (ma_rising && touched_ma && bounced_above);
}

bool DetectMABounceSell(string &reason, int &score)
{
   if(!EnableMABounce)
   {
      reason = "MA bounce disabled";
      return false;
   }

   double sma_now = SMA(MABounceTF, MABouncePeriod, 1);
   double sma_prev = SMA(MABounceTF, MABouncePeriod, MathMax(2, MABounceSlopeLookback));

   if(sma_now <= 0.0 || sma_prev <= 0.0)
   {
      reason = "MA bounce data not ready";
      return false;
   }

   bool ma_falling = (sma_now < sma_prev);

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   double h1 = CandleHigh(MABounceTF, 1);
   double c1 = CandleClose(MABounceTF, 1);
   double o1 = CandleOpen(MABounceTF, 1);
   double tol = MathMax(1, MABounceTolerancePoints) * _Point;

   bool touched_ma = (h1 >= sma_now - tol);
   bool bounced_below = (c1 < sma_now && c1 < o1);

   score = 0;
   if(ma_falling) score += 2;
   if(touched_ma) score += 2;
   if(bounced_below) score += 2;
   if(mid < sma_now) score += 1;

   reason = StringFormat("MA bounce sell: sma=%.2f falling=%s touched=%s bounced=%s score=%d",
                         sma_now, BoolText(ma_falling), BoolText(touched_ma), BoolText(bounced_below), score);
   return (ma_falling && touched_ma && bounced_below);
}

// ============================================================================
// V31.6z2 NEW: DONCHIAN BREAKOUT - the simplest, most classic trend-following entry: price
// makes a new N-bar high/low.
// ============================================================================
bool DetectDonchianBreakoutBuy(string &reason, int &score)
{
   if(!EnableDonchianBreakout)
   {
      reason = "Donchian breakout disabled";
      return false;
   }

   double recent_high = HighestHigh(DonchianTF, DonchianPeriod, 2);
   double c1 = CandleClose(DonchianTF, 1);
   double o1 = CandleOpen(DonchianTF, 1);

   if(recent_high <= 0.0 || c1 <= 0.0)
   {
      reason = "Donchian buy data not ready";
      return false;
   }

   bool new_high = (c1 > recent_high);
   bool bullish = (c1 > o1);

   score = 0;
   if(new_high) score += 4;
   if(bullish) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(DonchianTF, 1) > 0) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("Donchian buy: new %d-bar high=%s (prior=%.2f, close=%.2f) score=%d",
                         DonchianPeriod, BoolText(new_high), recent_high, c1, score);
   return (new_high && bullish);
}

bool DetectDonchianBreakoutSell(string &reason, int &score)
{
   if(!EnableDonchianBreakout)
   {
      reason = "Donchian breakout disabled";
      return false;
   }

   double recent_low = LowestLow(DonchianTF, DonchianPeriod, 2);
   double c1 = CandleClose(DonchianTF, 1);
   double o1 = CandleOpen(DonchianTF, 1);

   if(recent_low <= 0.0 || c1 <= 0.0)
   {
      reason = "Donchian sell data not ready";
      return false;
   }

   bool new_low = (c1 < recent_low);
   bool bearish = (c1 < o1);

   score = 0;
   if(new_low) score += 4;
   if(bearish) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(DonchianTF, 1) > 0) score += 1;   // REVERT(orderflow-sign): volume-magnitude, not direction - see note at the fake-breakout sell above.
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("Donchian sell: new %d-bar low=%s (prior=%.2f, close=%.2f) score=%d",
                         DonchianPeriod, BoolText(new_low), recent_low, c1, score);
   return (new_low && bearish);
}

// ============================================================================
// V31.6z2 NEW: CONSECUTIVE SAME-DIRECTION CANDLES - several candles in a row closing the
// same direction is a simple, reliable momentum confirmation (uninterrupted push, not chop).
// ============================================================================
bool DetectConsecutiveCandlesBuy(string &reason, int &score)
{
   if(!EnableConsecutiveCandles)
   {
      reason = "consecutive candles disabled";
      return false;
   }

   int need = MathMax(2, ConsecutiveCandleCount);
   int count = 0;
   for(int i = 1; i <= need; i++)
   {
      if(IsBullishCandle(ConsecutiveCandlesTF, i))
         count++;
      else
         break;
   }

   bool all_same = (count >= need);

   // V31.6z21 NEW: "3 in a row" alone doesn't distinguish an ACCELERATING push (each candle
   // bigger than the last - healthy, strengthening) from a DECELERATING one (each candle
   // smaller - the same exhaustion pattern found in Impulse Exhaustion Warning, but for this
   // detector's own confirmation instead of an existing basket).
   bool accelerating = false, decelerating = false;
   if(all_same && EnableCandleSizeProgression)
   {
      double body_recent = CandleBodyPoints(ConsecutiveCandlesTF, 1);
      double body_oldest = CandleBodyPoints(ConsecutiveCandlesTF, need);
      if(body_oldest > 0.0)
      {
         // V31.6z59 fix: CandleSizeProgressionThreshold is a user-editable input - setting it
         // to 0 would divide by zero here. Found via a full-file division audit.
         double prog_thr = MathMax(1.01, CandleSizeProgressionThreshold);
         if(body_recent > body_oldest * prog_thr)
            accelerating = true;
         else if(body_recent < body_oldest / prog_thr)
            decelerating = true;
      }
   }

   score = 0;
   if(all_same) score += 4;
   if(count > need) score += 1;
   if(accelerating) score += 1;
   if(decelerating) score -= CandleSizeDecelPenalty;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(ConsecutiveCandlesTF, 1) > 0) score += 1;

   reason = StringFormat("consecutive candles buy: %d/%d bullish in a row accel=%s decel=%s score=%d",
                         count, need, BoolText(accelerating), BoolText(decelerating), score);
   return all_same;
}

bool DetectConsecutiveCandlesSell(string &reason, int &score)
{
   if(!EnableConsecutiveCandles)
   {
      reason = "consecutive candles disabled";
      return false;
   }

   int need = MathMax(2, ConsecutiveCandleCount);
   int count = 0;
   for(int i = 1; i <= need; i++)
   {
      if(IsBearishCandle(ConsecutiveCandlesTF, i))
         count++;
      else
         break;
   }

   bool all_same = (count >= need);

   bool accelerating = false, decelerating = false;
   if(all_same && EnableCandleSizeProgression)
   {
      double body_recent = CandleBodyPoints(ConsecutiveCandlesTF, 1);
      double body_oldest = CandleBodyPoints(ConsecutiveCandlesTF, need);
      if(body_oldest > 0.0)
      {
         // V31.6z59 fix: CandleSizeProgressionThreshold is a user-editable input - setting it
         // to 0 would divide by zero here. Found via a full-file division audit.
         double prog_thr = MathMax(1.01, CandleSizeProgressionThreshold);
         if(body_recent > body_oldest * prog_thr)
            accelerating = true;
         else if(body_recent < body_oldest / prog_thr)
            decelerating = true;
      }
   }

   score = 0;
   if(all_same) score += 4;
   if(count > need) score += 1;
   if(accelerating) score += 1;
   if(decelerating) score -= CandleSizeDecelPenalty;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(ConsecutiveCandlesTF, 1) > 0) score += 1;   // REVERT(orderflow-sign): volume-magnitude, not direction - see note at the fake-breakout sell above.

   reason = StringFormat("consecutive candles sell: %d/%d bearish in a row accel=%s decel=%s score=%d",
                         count, need, BoolText(accelerating), BoolText(decelerating), score);
   return all_same;
}

// ============================================================================
// V31.6z2 NEW: DXY-CONFIRMED TREND - gold-specific macro confirmation: dollar trending
// strongly AND local gold price agreeing is stronger than local price action alone.
// ============================================================================
bool DetectDXYConfirmedTrendBuy(string &reason, int &score)
{
   if(!EnableDXYConfirmedTrend || !EnableDXYProxy)
   {
      reason = "DXY confirmed trend disabled";
      return false;
   }

   string dxy_reason = "";
   int dxy_dir = DXYProxyDirection(dxy_reason);
   int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;

   if(price_effect <= 0)
   {
      reason = "DXY does not confirm bullish gold";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double c_prior = CandleClose(SignalTF, MathMax(2, DXYConfirmedTrendPriceLookback));
   bool local_up = (c1 > 0.0 && c_prior > 0.0 && c1 > c_prior);

   score = 0;
   score += 3;   // DXY macro confirmation itself
   if(local_up) score += 2;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("DXY confirmed trend buy: %s | local_up=%s score=%d", dxy_reason, BoolText(local_up), score);
   return local_up;
}

bool DetectDXYConfirmedTrendSell(string &reason, int &score)
{
   if(!EnableDXYConfirmedTrend || !EnableDXYProxy)
   {
      reason = "DXY confirmed trend disabled";
      return false;
   }

   string dxy_reason = "";
   int dxy_dir = DXYProxyDirection(dxy_reason);
   int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;

   if(price_effect >= 0)
   {
      reason = "DXY does not confirm bearish gold";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double c_prior = CandleClose(SignalTF, MathMax(2, DXYConfirmedTrendPriceLookback));
   bool local_down = (c1 > 0.0 && c_prior > 0.0 && c1 < c_prior);

   score = 0;
   score += 3;
   if(local_down) score += 2;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("DXY confirmed trend sell: %s | local_down=%s score=%d", dxy_reason, BoolText(local_down), score);
   return local_down;
}

// ============================================================================
// V31.6z2 NEW: EXPANDING VOLATILITY - ATR expanding (not contracting) in the trend
// direction means there's still room left, the trend isn't running out of steam.
// ============================================================================
bool DetectExpandingVolatilityBuy(string &reason, int &score)
{
   if(!EnableExpandingVolatility)
   {
      reason = "expanding volatility disabled";
      return false;
   }

   double atr_fast = ATRPointsManual(ExpandingVolTF, ExpandingVolFastPeriod, 1);
   double atr_slow = ATRPointsManual(ExpandingVolTF, ExpandingVolSlowPeriod, 1);

   if(atr_fast <= 0.0 || atr_slow <= 0.0)
   {
      reason = "expanding volatility data not ready";
      return false;
   }

   bool expanding = (atr_fast >= atr_slow * ExpandingVolMinRatio);
   double c1 = CandleClose(ExpandingVolTF, 1);
   double o1 = CandleOpen(ExpandingVolTF, 1);
   bool bullish = (c1 > o1);

   score = 0;
   if(expanding) score += 3;
   if(bullish) score += 2;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("expanding volatility buy: fastATR=%.0f slowATR=%.0f ratio=%.2f expanding=%s score=%d",
                         atr_fast, atr_slow, atr_fast / atr_slow, BoolText(expanding), score);
   return (expanding && bullish);
}

bool DetectExpandingVolatilitySell(string &reason, int &score)
{
   if(!EnableExpandingVolatility)
   {
      reason = "expanding volatility disabled";
      return false;
   }

   double atr_fast = ATRPointsManual(ExpandingVolTF, ExpandingVolFastPeriod, 1);
   double atr_slow = ATRPointsManual(ExpandingVolTF, ExpandingVolSlowPeriod, 1);

   if(atr_fast <= 0.0 || atr_slow <= 0.0)
   {
      reason = "expanding volatility data not ready";
      return false;
   }

   bool expanding = (atr_fast >= atr_slow * ExpandingVolMinRatio);
   double c1 = CandleClose(ExpandingVolTF, 1);
   double o1 = CandleOpen(ExpandingVolTF, 1);
   bool bearish = (c1 < o1);

   score = 0;
   if(expanding) score += 3;
   if(bearish) score += 2;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("expanding volatility sell: fastATR=%.0f slowATR=%.0f ratio=%.2f expanding=%s score=%d",
                         atr_fast, atr_slow, atr_fast / atr_slow, BoolText(expanding), score);
   return (expanding && bearish);
}

// ============================================================================
// V31.6z3 NEW: MTF UNANIMOUS TRIGGER - rare, but when all 4 timeframes agree, that's
// genuinely strong evidence on its own, not just a supporting bonus for another detector.
// ============================================================================
bool DetectMTFUnanimousBuy(string &reason, int &score)
{
   if(!EnableMTFUnanimousTrigger || !EnableMTFAlignment)
   {
      reason = "MTF unanimous disabled";
      return false;
   }

   int agree = MTFAlignmentCount(1);
   if(agree < 4)
   {
      reason = StringFormat("not unanimous (%d/4)", agree);
      return false;
   }

   score = MathMax(1, MTFUnanimousBaseScore);

   reason = StringFormat("MTF unanimous buy: 4/4 timeframes agree score=%d", score);
   return true;
}

bool DetectMTFUnanimousSell(string &reason, int &score)
{
   if(!EnableMTFUnanimousTrigger || !EnableMTFAlignment)
   {
      reason = "MTF unanimous disabled";
      return false;
   }

   int agree = MTFAlignmentCount(-1);
   if(agree < 4)
   {
      reason = StringFormat("not unanimous (%d/4)", agree);
      return false;
   }

   score = MathMax(1, MTFUnanimousBaseScore);

   reason = StringFormat("MTF unanimous sell: 4/4 timeframes agree score=%d", score);
   return true;
}

// ============================================================================
// V31.6z3 NEW: EQ ZONE TREND - "buy the dip / sell the rip WITHIN a confirmed trend": the
// Equilibrium/Premium-Discount concept read as its own entry rather than just a bonus.
// ============================================================================
bool DetectEQZoneTrendBuy(string &reason, int &score)
{
   if(!EnableEQZoneTrend || !EnableEQZone)
   {
      reason = "EQ zone trend disabled";
      return false;
   }

   double adx = 0.0, plus_di = 0.0, minus_di = 0.0;
   CachedADXSnapshot(TrendRideTF, TrendStrengthPeriod, adx, plus_di, minus_di);
   bool strong_up = (adx >= EQZoneTrendMinADX && plus_di > minus_di);

   if(!strong_up)
   {
      reason = "no confirmed uptrend for EQ zone entry";
      return false;
   }

   double range_pos = 50.0;
   int eq_dir = EQZoneBias(range_pos);
   if(eq_dir != 1)
   {
      reason = StringFormat("not in discount zone (pos=%.0f%%)", range_pos);
      return false;
   }

   score = 0;
   score += 3;   // confirmed trend
   score += 2;   // genuine discount positioning

   reason = StringFormat("EQ zone trend buy: uptrend confirmed (adx=%.0f), discount zone (%.0f%%) score=%d",
                         adx, range_pos, score);
   return true;
}

bool DetectEQZoneTrendSell(string &reason, int &score)
{
   if(!EnableEQZoneTrend || !EnableEQZone)
   {
      reason = "EQ zone trend disabled";
      return false;
   }

   double adx = 0.0, plus_di = 0.0, minus_di = 0.0;
   CachedADXSnapshot(TrendRideTF, TrendStrengthPeriod, adx, plus_di, minus_di);
   bool strong_down = (adx >= EQZoneTrendMinADX && minus_di > plus_di);

   if(!strong_down)
   {
      reason = "no confirmed downtrend for EQ zone entry";
      return false;
   }

   double range_pos = 50.0;
   int eq_dir = EQZoneBias(range_pos);
   if(eq_dir != -1)
   {
      reason = StringFormat("not in premium zone (pos=%.0f%%)", range_pos);
      return false;
   }

   score = 0;
   score += 3;
   score += 2;

   reason = StringFormat("EQ zone trend sell: downtrend confirmed (adx=%.0f), premium zone (%.0f%%) score=%d",
                         adx, range_pos, score);
   return true;
}

// ============================================================================
// V31.6z3 NEW: VOLUME PUSH CONTINUATION - sustained, one-directional tick-volume conviction
// across several bars, no sweep or reversal pattern needed - just sustained real pressure.
// ============================================================================
bool DetectVolumePushBuy(string &reason, int &score)
{
   if(!EnableVolumePush || !EnableOrderFlow)
   {
      reason = "volume push disabled";
      return false;
   }

   int need = MathMax(1, VolumePushLookbackBars);
   int count = 0;
   for(int i = 1; i <= need; i++)
   {
      if(OrderFlowConvictionSign(VolumePushTF, i) > 0)
         count++;
      else
         break;
   }

   bool sustained = (count >= need);
   if(!sustained)
   {
      reason = StringFormat("volume push not sustained (%d/%d bars)", count, need);
      return false;
   }

   double c1 = CandleClose(VolumePushTF, 1);
   double o1 = CandleOpen(VolumePushTF, 1);
   bool bullish = (c1 > o1);

   // V31.6z20 NEW: "sustained" only checked the SIGN stayed positive each bar - it never
   // checked whether the underlying CONVICTION RATIO itself was growing or fading across
   // those bars. Waning conviction (each bar weaker than the last, even if still net
   // positive) is a real difference from genuinely building pressure.
   bool waning = false;
   if(EnableVolumePushWaningCheck)
   {
      double ratio_recent = OrderFlowConvictionRatio(VolumePushTF, 1);
      double ratio_oldest = OrderFlowConvictionRatio(VolumePushTF, need);
      if(ratio_oldest > 0.0 && ratio_recent < ratio_oldest * VolumePushWaningThreshold)
         waning = true;
   }

   score = 0;
   score += 4;
   if(bullish) score += 1;
   if(count > need) score += 1;
   if(waning) score -= VolumePushWaningPenalty;

   reason = StringFormat("volume push buy: %d/%d bars sustained order-flow waning=%s score=%d",
                         count, need, BoolText(waning), score);
   return (sustained && bullish);
}

bool DetectVolumePushSell(string &reason, int &score)
{
   if(!EnableVolumePush || !EnableOrderFlow)
   {
      reason = "volume push disabled";
      return false;
   }

   int need = MathMax(1, VolumePushLookbackBars);
   int count = 0;
   for(int i = 1; i <= need; i++)
   {
      // FIX(orderflow-magnitude): a "volume push" needs HEAVY volume on both sides - the buy
      // twin uses `> 0`; this counted THIN-volume bars as a sell-side push.
      if(OrderFlowConvictionSign(VolumePushTF, i) > 0)
         count++;
      else
         break;
   }

   bool sustained = (count >= need);
   if(!sustained)
   {
      reason = StringFormat("volume push not sustained (%d/%d bars)", count, need);
      return false;
   }

   double c1 = CandleClose(VolumePushTF, 1);
   double o1 = CandleOpen(VolumePushTF, 1);
   bool bearish = (c1 < o1);

   bool waning = false;
   if(EnableVolumePushWaningCheck)
   {
      double ratio_recent = OrderFlowConvictionRatio(VolumePushTF, 1);
      double ratio_oldest = OrderFlowConvictionRatio(VolumePushTF, need);
      if(ratio_oldest > 0.0 && ratio_recent < ratio_oldest * VolumePushWaningThreshold)
         waning = true;
   }

   score = 0;
   score += 4;
   if(bearish) score += 1;
   if(count > need) score += 1;
   if(waning) score -= VolumePushWaningPenalty;

   reason = StringFormat("volume push sell: %d/%d bars sustained order-flow waning=%s score=%d",
                         count, need, BoolText(waning), score);
   return (sustained && bearish);
}

// ============================================================================
// V31.6z5 NEW: VWAP BOUNCE - price pulls back to the Volume-Weighted Average Price and
// bounces. A genuinely different reference level than any moving average, since it weighs
// by volume, not just price - closer to what institutional participants actually watch.
// ============================================================================
bool DetectVWAPBounceBuy(string &reason, int &score)
{
   if(!EnableVWAPBounce)
   {
      reason = "VWAP bounce disabled";
      return false;
   }

   double vwap = CachedVWAP(VWAPTF, MathMax(2, VWAPLookbackBars));
   if(vwap <= 0.0)
   {
      reason = "VWAP not ready";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   double l1 = CandleLow(VWAPTF, 1);
   double c1 = CandleClose(VWAPTF, 1);
   double o1 = CandleOpen(VWAPTF, 1);
   double tol = MathMax(1, VWAPTolerancePoints) * _Point;

   bool above_vwap = (mid > vwap);
   bool touched = (l1 <= vwap + tol);
   bool bounced = (c1 > vwap && c1 > o1);

   score = 0;
   if(above_vwap) score += 1;
   if(touched) score += 2;
   if(bounced) score += 3;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("VWAP bounce buy: vwap=%.2f aboveVWAP=%s touched=%s bounced=%s score=%d",
                         vwap, BoolText(above_vwap), BoolText(touched), BoolText(bounced), score);
   return (above_vwap && touched && bounced);
}

bool DetectVWAPBounceSell(string &reason, int &score)
{
   if(!EnableVWAPBounce)
   {
      reason = "VWAP bounce disabled";
      return false;
   }

   double vwap = CachedVWAP(VWAPTF, MathMax(2, VWAPLookbackBars));
   if(vwap <= 0.0)
   {
      reason = "VWAP not ready";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   double h1 = CandleHigh(VWAPTF, 1);
   double c1 = CandleClose(VWAPTF, 1);
   double o1 = CandleOpen(VWAPTF, 1);
   double tol = MathMax(1, VWAPTolerancePoints) * _Point;

   bool below_vwap = (mid < vwap);
   bool touched = (h1 >= vwap - tol);
   bool bounced = (c1 < vwap && c1 < o1);

   score = 0;
   if(below_vwap) score += 1;
   if(touched) score += 2;
   if(bounced) score += 3;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("VWAP bounce sell: vwap=%.2f belowVWAP=%s touched=%s bounced=%s score=%d",
                         vwap, BoolText(below_vwap), BoolText(touched), BoolText(bounced), score);
   return (below_vwap && touched && bounced);
}

// ============================================================================
// V31.6z43 NEW: ZONE RETEST. Direct user request - a classic, well-known, high-probability
// pattern that had partial infrastructure (ZoneMapIsPolarityFlip) but no actual entry
// detector built on it: a level breaks (e.g. resistance gives way to a bullish push),
// price pulls back to RETEST that same level from the NEW side (now acting as support), and
// shows a genuine bounce/rejection confirming the new polarity holds. This is fundamentally a
// CONTINUATION of the original break, using the retest as confirmation rather than chasing
// the initial move blind.
// ============================================================================
bool DetectZoneRetestBuy(string &reason, int &score)
{
   if(!EnableZoneRetestTrigger)
   {
      reason = "zone retest disabled";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
   {
      reason = "no price";
      return false;
   }

   double level = ZoneMapNearestSupport(mid);
   if(level <= 0.0)
   {
      reason = "no support level found";
      return false;
   }

   // Confirm this level genuinely FLIPPED (was resistance, held long enough on the new side,
   // and was demonstrably on the opposite side before that) - not just "always been support".
   // V246: a polarity flip is one way a level earns respect and not the only one. The band at
   // 4492-4494 was never support - it simply turned price away three times and defeated two
   // attempts to break it, and requiring a flip meant the EA could not see it at all.
   //
   // Either qualifies now: a level that changed sides, or one that defended itself.
   bool qualified = ZoneMapIsPolarityFlip(level, true);
   int  fb_count = 0;
   string fb_why = "";
   if(!qualified && EnableFailedBreakRead)
   {
      int fb_bars = 0;
      fb_count = FailedBreakCount(level, false, fb_bars, fb_why);
      qualified = (fb_count >= MathMax(1, RetestMinFailedBreaks));
   }

   if(!qualified)
   {
      reason = "level has neither flipped nor defended itself";
      return false;
   }

   double dist_pts = (mid - level) / _Point;
   if(dist_pts < 0.0 || dist_pts > ZoneRetestMaxDistancePoints)
   {
      reason = StringFormat("not currently retesting (dist=%.0fpts)", dist_pts);
      return false;
   }

   double tol = MathMax(1, ZoneRetestTouchTolerancePoints) * _Point;

   // V31.6z44 fix: real gap found - only ever checked the SINGLE most recent closed bar for a
   // touch. A retest that happened 2-3 bars ago, with price recovering since, was invisible.
   // Scans a small recent window for the actual touch, then checks CURRENT price for recovery.
   bool touched_level = false;
   int touch_shift = 0;
   int window = MathMax(1, ZoneRetestConfirmWindowBars);

   for(int i = 1; i <= window; i++)
   {
      double li = CandleLow(SignalTF, i);
      if(li <= 0.0)
         continue;
      if(li <= level + tol)
      {
         touched_level = true;
         touch_shift = i;
         break;
      }
   }

   if(!touched_level)
   {
      reason = "no recent touch of the flipped level";
      return false;
   }

   double h1 = CandleHigh(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double range1 = h1 - l1;

   bool recovered = (c1 > level);

   // V31.6z44 fix: "bounced" used to mean nothing more than "closed green above the level" -
   // no distinction between a genuine rejection and a coincidental green candle. Checks for an
   // actual rejection WICK (either on the current bar or the touch bar itself) as the stronger
   // confirmation, with the plain green-close as a fallback for a clean, wick-free recovery.
   bool quality_bounce = false;
   if(range1 > 0.0)
   {
      double lower_wick1 = MathMin(c1, o1) - l1;
      if((lower_wick1 / range1) >= ZoneRetestMinWickRatio)
         quality_bounce = true;
   }
   if(!quality_bounce && touch_shift > 1)
   {
      double ot = CandleOpen(SignalTF, touch_shift);
      double ct = CandleClose(SignalTF, touch_shift);
      double ht = CandleHigh(SignalTF, touch_shift);
      double lt = CandleLow(SignalTF, touch_shift);
      double ranget = ht - lt;
      if(ranget > 0.0)
      {
         double lower_wickt = MathMin(ct, ot) - lt;
         if((lower_wickt / ranget) >= ZoneRetestMinWickRatio)
            quality_bounce = true;
      }
   }

   bool simple_bounce = (c1 > o1 && c1 > level);

   if(!recovered || (!quality_bounce && !simple_bounce))
   {
      reason = StringFormat("retest in range but no bounce confirmation yet (touch=%dbars-ago recovered=%s quality=%s)",
                            touch_shift, BoolText(recovered), BoolText(quality_bounce));
      return false;
   }

   double strength = ZoneMapStrength(level);

   score = 0;
   score += 4;
   if(strength >= ZoneRetestMinStrength) score += 2;
   if(quality_bounce) score += 1;
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(1) >= 2) score += 1;

   reason = StringFormat("zone retest buy: flipped level=%.2f(str=%.1f) touch=%dbars-ago quality=%s score=%d",
                         level, strength, touch_shift, BoolText(quality_bounce), score);
   return true;
}

bool DetectZoneRetestSell(string &reason, int &score)
{
   if(!EnableZoneRetestTrigger)
   {
      reason = "zone retest disabled";
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
   {
      reason = "no price";
      return false;
   }

   double level = ZoneMapNearestResistance(mid);
   if(level <= 0.0)
   {
      reason = "no resistance level found";
      return false;
   }

   // V246: a polarity flip is one way a level earns respect and not the only one. The band at
   // 4492-4494 was never support - it simply turned price away three times and defeated two
   // attempts to break it, and requiring a flip meant the EA could not see it at all.
   //
   // Either qualifies now: a level that changed sides, or one that defended itself.
   bool qualified = ZoneMapIsPolarityFlip(level, false);
   int  fb_count = 0;
   string fb_why = "";
   if(!qualified && EnableFailedBreakRead)
   {
      int fb_bars = 0;
      fb_count = FailedBreakCount(level, true, fb_bars, fb_why);
      qualified = (fb_count >= MathMax(1, RetestMinFailedBreaks));
   }

   if(!qualified)
   {
      reason = "level has neither flipped nor defended itself";
      return false;
   }

   double dist_pts = (level - mid) / _Point;
   if(dist_pts < 0.0 || dist_pts > ZoneRetestMaxDistancePoints)
   {
      reason = StringFormat("not currently retesting (dist=%.0fpts)", dist_pts);
      return false;
   }

   double tol = MathMax(1, ZoneRetestTouchTolerancePoints) * _Point;

   bool touched_level = false;
   int touch_shift = 0;
   int window = MathMax(1, ZoneRetestConfirmWindowBars);

   for(int i = 1; i <= window; i++)
   {
      double hi = CandleHigh(SignalTF, i);
      if(hi <= 0.0)
         continue;
      if(hi >= level - tol)
      {
         touched_level = true;
         touch_shift = i;
         break;
      }
   }

   if(!touched_level)
   {
      reason = "no recent touch of the flipped level";
      return false;
   }

   double h1 = CandleHigh(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double range1 = h1 - l1;

   bool recovered = (c1 < level);

   bool quality_bounce = false;
   if(range1 > 0.0)
   {
      double upper_wick1 = h1 - MathMax(c1, o1);
      if((upper_wick1 / range1) >= ZoneRetestMinWickRatio)
         quality_bounce = true;
   }
   if(!quality_bounce && touch_shift > 1)
   {
      double ot = CandleOpen(SignalTF, touch_shift);
      double ct = CandleClose(SignalTF, touch_shift);
      double ht = CandleHigh(SignalTF, touch_shift);
      double lt = CandleLow(SignalTF, touch_shift);
      double ranget = ht - lt;
      if(ranget > 0.0)
      {
         double upper_wickt = ht - MathMax(ct, ot);
         if((upper_wickt / ranget) >= ZoneRetestMinWickRatio)
            quality_bounce = true;
      }
   }

   bool simple_bounce = (c1 < o1 && c1 < level);

   if(!recovered || (!quality_bounce && !simple_bounce))
   {
      reason = StringFormat("retest in range but no bounce confirmation yet (touch=%dbars-ago recovered=%s quality=%s)",
                            touch_shift, BoolText(recovered), BoolText(quality_bounce));
      return false;
   }

   double strength = ZoneMapStrength(level);

   score = 0;
   score += 4;
   if(strength >= ZoneRetestMinStrength) score += 2;
   if(quality_bounce) score += 1;
   // FIX(orderflow-magnitude): matches DetectZoneRetestBuy's `> 0` - volume magnitude, not direction.
   if(EnableSweepVolumeCheck && OrderFlowConvictionSign(SignalTF, 1) > 0) score += 1;
   if(EnableMTFAlignment && MTFAlignmentCount(-1) >= 2) score += 1;

   reason = StringFormat("zone retest sell: flipped level=%.2f(str=%.1f) touch=%dbars-ago quality=%s score=%d",
                         level, strength, touch_shift, BoolText(quality_bounce), score);
   return true;
}

void ConsiderOpportunity(const ENUM_OPPORTUNITY_DIR dir, const ENUM_OPPORTUNITY_TYPE type, const int score, const string reason, const bool micro_preferred)
{
   // FEATURE(bayes-auto-disable): if this detector type has proven itself a consistent loser
   // over a real sample of closed trades, ignore its signal entirely. This is the single
   // highest-leverage quality lever: it removes the trades the bot's OWN history says lose
   // money, without touching anything else. Checked first so a disabled detector never even
   // competes to become the chosen opportunity.
   if(BayesDetectorDisabled((int)type))
   {
      if((BayesAutoDisablePrintOnUse && VerboseLogs))
      {
         static datetime last_disable_print = 0;
         if(TimeCurrent() - last_disable_print > 300)   // throttle: at most once / 5 min
         {
            PrintFormat("[SIRUS BAYES AUTO-DISABLE] ignoring %s signal - win rate %.0f%% over %.0f trades (<= %.0f%% threshold)",
                        OpportunityTypeToString(type),
                        BayesWinRate((int)type) * 100.0,
                        BayesSampleCount((int)type),
                        BayesAutoDisableWinrate * 100.0);
            last_disable_print = TimeCurrent();
         }
      }
      return;
   }

   // V249fix(auto-mode), second pass: the per-detector Hunter +1 was removed so that G_SCORE_BASE
   // means the same thing in both modes - but the replacement bonus lives in UpdateSignalScoreEngine,
   // which runs AFTER this gate and is itself gated on the grade not being NONE. So removing it here
   // silently deleted whole detector families in Hunter: pullback-continuation, swing-continuation,
   // consecutive-candles and volume-push at raw 4 were discarded outright instead of grading B, and
   // fake-breakout-return at raw 2 lost its C_MICRO. Those are exactly the fast, marginal setups the
   // hunter profile exists to take.
   // The bump is applied to the GRADE only, and `score` is passed on un-bumped, so the mode
   // advantage survives where it belongs (which setups qualify) without inflating the score that
   // every absolute threshold, the grade-to-lot mapping and the calibration bands are measured on.
   int graded_score = score + ((G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER) ? 1 : 0);
   ENUM_OPPORTUNITY_GRADE grade = GradeFromScore(graded_score, micro_preferred);
   if(grade == OPP_GRADE_NONE)
      return;

   // V31.6z49 NEW: record the best score on EACH side BEFORE the winner-takes-all comparison
   // below. Real gap found via decision-flow audit, directly tied to the user's report that
   // first-entry errors are a main driver of long drawdowns: the scanner picks the single
   // highest scorer across 47 detectors, but nothing downstream ever knew whether the OPPOSING
   // side also had a strong candidate. "BUY 7, nothing on sell" (clear, one-sided conviction)
   // and "BUY 7 but SELL 6 too" (genuinely ambiguous - the market is telling both stories at
   // once) produced identical G_OPP_DIR/G_OPP_SCORE, so First Entry treated them the same. The
   // second case is exactly the setup most likely to go wrong and sit in DD.
   // CONSENSUS: count the voice before anything else decides. A detector that spoke is a detector
   // that saw something, whether or not it won.
   if(dir == OPP_DIR_BUY)  { G_OPP_VOICES_BUY++;  G_OPP_SUM_BUY  += score; }
   if(dir == OPP_DIR_SELL) { G_OPP_VOICES_SELL++; G_OPP_SUM_SELL += score; }

   if(dir == OPP_DIR_BUY && score > G_OPP_BEST_BUY_SCORE)
      G_OPP_BEST_BUY_SCORE = score;
   else if(dir == OPP_DIR_SELL && score > G_OPP_BEST_SELL_SCORE)
      G_OPP_BEST_SELL_SCORE = score;

   // FIX(buy-first-bias): the scanner evaluates every pair BUY-first, and on an EXACT tie (same
   // score AND same grade) the first-seen side used to win - which was always BUY. So on a bar
   // where BUY and SELL setups were equally strong, the bot silently always chose BUY. Break exact
   // ties by the preferred direction instead: Daily Bias if it has an opinion, else the deep HTF
   // trend. A tie that agrees with the prevailing bias is the better one to take; if neither has an
   // opinion, fall back to the original first-seen behaviour so nothing else changes.
   if(score == G_OPP_SCORE && grade == G_OPP_GRADE &&
      G_OPP_DIR != OPP_DIR_NONE && dir != G_OPP_DIR)
   {
      int pref = 0;
      if(EnableDailyBias && G_DAILY_BIAS != 0)
         pref = G_DAILY_BIAS;
      else
         pref = DeepHTFTrendDirection();

      int new_dir_sign = (dir == OPP_DIR_BUY) ? 1 : -1;
      int cur_dir_sign = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;

      // Only override the existing pick if the NEW side matches the bias and the current one does not.
      if(pref != 0 && new_dir_sign == pref && cur_dir_sign != pref)
      {
         G_OPP_DIR = dir;
         G_OPP_TYPE = type;
         G_OPP_GRADE = grade;
         G_OPP_IS_MICRO = (grade == OPP_GRADE_C_MICRO || micro_preferred);
         G_OPP_REASON = reason + " [tie->bias]";
      }
      return;
   }

   if(score < G_OPP_SCORE || (score == G_OPP_SCORE && grade <= G_OPP_GRADE))
      return;

   G_OPP_DIR = dir;
   G_OPP_TYPE = type;
   G_OPP_SCORE = score;
   G_OPP_GRADE = grade;
   G_OPP_IS_MICRO = (grade == OPP_GRADE_C_MICRO || micro_preferred);
   G_OPP_REASON = reason;
}
