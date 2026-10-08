//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 06_Basket_Session                               |
//| Pattern memory, basket age, scale-in, basket health, sessions    |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// V31.6c NEW detector (robot-eyes upgrade): Fake Breakout Return. Was a named-but-unimplemented
// opportunity type before this - price genuinely broke a real Zone Map wall (not a wick, an
// actual breach with room), failed to hold beyond it, and has now closed back on the original
// side within a short lookback. Unlike DetectSweepBuy/Sell (single-candle wick pattern), this

// ============================================================================
// V147: TRAP QUALITY - separating a real failed breakout from ordinary noise.
// ----------------------------------------------------------------------------
// A failed breakout is the best setup on the chart, but only when it actually
// trapped someone. The existing detector fires on any wick that pokes through a
// level and comes back - which is most wicks. Those carry no information: nobody
// was positioned, so nobody has to get out.
//
// A real trap needs three things, and the third is the one that matters:
//   1. The break was MEANINGFUL - deep enough that it looked like a genuine break,
//      measured against ATR rather than a fixed number of points.
//   2. It PERSISTED - price stayed on the far side for a few bars. That is what
//      convinces traders to enter; a single wick convinces nobody.
//   3. The return was SHARP - the snap back is those traders being forced out, and
//      the speed of it is the clearest evidence that they existed.
//
// A wick that pokes through and returns immediately scores near zero here. A break
// that held for four bars and then reversed hard scores near one - and that is the
// move worth trading, because the losing side has to buy back.
// ============================================================================
// V148: WHO IS THIS LEVEL FOR? - retail levels attract, institutional levels hold.
// ----------------------------------------------------------------------------
// Two levels can look identical on the chart and demand opposite trades.
//
// A retail level - a round number, a clean obvious swing high - is where ordinary
// stops sit. Price is DRAWN to it, takes the stops, and often reverses immediately
// after. It behaves like a magnet, not a wall, and trading a bounce from it before
// the stops are taken means standing in front of the run.
//
// An institutional level - a band price spent real time inside, tested repeatedly
// without breaking - is where size actually rests. That one holds, and a bounce
// from it is worth trading.
//
// The EA currently treats a round number as EXTRA strength, which is the retail
// case read backwards: it trusts most the level most likely to be run through.
//
// The distinction is not the price itself but its HISTORY: an untested round number
// is a magnet, while a round number that has held repeatedly has become a real
// level. Same price, opposite meaning, decided by what it has already done.
//
// Returns +1 institutional (holds), -1 retail (attracts), 0 unclear.
// ============================================================================
// V149: PATH DENSITY - how much clear road is ahead, not just where the first wall is.
// ----------------------------------------------------------------------------
// The room check knows the distance to the nearest opposing level. That is the
// right question for "can the target be reached", but it says nothing about what
// lies beyond it, and those are different markets:
//
//   one wall $2 away, then nothing for $10   - break it and the move runs
//   five walls stacked every $1              - price grinds, every push stalls
//
// Both report "first wall at $2". The first is a scalp worth taking; the second is
// a chop zone where a $2.50 target has to survive five separate stalls.
//
// This counts the levels ahead within a working range and measures the largest gap
// between them. Density says how hard the path is; the biggest gap says whether
// there is a stretch of open road worth aiming at - price crosses a vacuum quickly
// precisely because there is nothing in it to react to.
// ============================================================================
// V150: MARKET SCALE - let the market state its own unit of measurement.
// ----------------------------------------------------------------------------
// Every structural threshold in this EA is a fixed number: cluster swings within
// $2.50, treat $0.70 as the same wall, call $3 a thrust. Those numbers were chosen
// against a particular market. When the market changes character they stop meaning
// what they meant - in a quiet session $2.50 groups half the chart into one band,
// and in a volatile one it splits a single zone into five.
//
// ATR is the usual answer, but ATR measures bar size, not STRUCTURE size. A market
// can print small bars while swinging widely, or large bars inside a tight range.
// What the thresholds actually need is the typical distance between the swings the
// market is currently making - its own natural unit.
//
// This measures that: the median distance between consecutive swing points. Median
// rather than mean, because one outsized swing should not redefine the scale.
//
// Returned in points, with the ATR ratio alongside so callers can see whether the
// market is swinging wider or tighter than its bar size suggests.
// ============================================================================
// V151: FORCED FLOW - telling a decision apart from a liquidation.
// ----------------------------------------------------------------------------
// Most moves are decisions: someone chose to buy or sell, and the move can pause,
// retrace, or reverse at any point. A minority are LIQUIDATIONS - margin calls,
// stop-outs, hedges being unwound. Those are not choices. The orders must be
// filled regardless of price, which is why such moves run straight, refuse to
// retrace, and then snap back hard the moment the forced supply is exhausted.
//
// The EA treats both identically: a strong move is a strong move. But they demand
// opposite handling. Fading a decision is dangerous - it can simply continue.
// Fading a liquidation once it stalls is one of the highest-quality reversals
// available, because the seller was never a willing seller and there is nothing
// behind them.
//
// Three signatures separate them, and it is the COMBINATION that matters:
//   - the move is unusually large for its timeframe
//   - it barely retraces (a decision breathes; a liquidation does not)
//   - the candles are near-full-bodied with little wick (no two-way trade at all)
//
// Returns the direction of the forced flow, with its intensity, or 0.
// ============================================================================
// V154: PATTERN MEMORY - what this shape did the last twenty times it appeared.
// ----------------------------------------------------------------------------
// Every other module reasons from theory: this is a zone, so price should react;
// this is a sweep, so a reversal is likely. Sound reasoning, but still assumption.
//
// This module asks a question none of them can: what has this market ACTUALLY done
// the last time the chart looked like this? It takes the recent bars as a shape,
// normalises away price and volatility so only the FORM remains, then scans back
// through history for the closest matches - and looks at what happened next in each.
//
// The value is that it carries no theory at all. If twenty similar shapes resolved
// downward fifteen times, that is evidence from this symbol, this timeframe, this
// behaviour - and it holds whether or not any indicator agrees.
//
// Two safeguards matter. Matches must be genuinely close, or the "evidence" is just
// noise dressed as a pattern. And the outcome must clear a threshold, since a shape
// that resolved nowhere teaches nothing.
//
// Returns bias -1..+1 (negative = history resolved downward), with the sample count.
// ============================================================================
double PatternMemoryBias(int &samples, double &match_quality, string &detail)
{
   samples = 0;
   match_quality = 0.0;
   detail = "";

   if(!EnablePatternMemory || _Point <= 0.0)
      return 0.0;

   // Per-bar cache - this is the heaviest scan in the EA and its answer only
   // changes when a bar closes.
   // Keyed on the SHAPE timeframe's bar, not the core M1 bar: the answer cannot change
   // until a new bar closes on PatternMemoryTF, so refreshing every minute would repeat
   // a 60,000-comparison scan fifteen times for an identical result.
   static datetime pm_tf_bar = 0;
   static double pm_bias = 0.0;
   static int    pm_samples = 0;
   static double pm_quality = 0.0;
   static string pm_detail = "";

   datetime tf_bar_time = iTime(_Symbol, PatternMemoryTF, 0);
   if(tf_bar_time > 0 && pm_tf_bar == tf_bar_time)
   {
      samples = pm_samples;
      match_quality = pm_quality;
      detail = pm_detail;
      return pm_bias;
   }

   ENUM_TIMEFRAMES tf = PatternMemoryTF;
   int shape = MathMax(6, PatternMemoryShapeBars);
   int horizon = MathMax(3, PatternMemoryHorizonBars);
   int history = MathMax(shape * 10, PatternMemoryHistoryBars);

   // --- build the current shape, normalised so only FORM remains ------------------
   double cur[];
   ArrayResize(cur, shape);
   double cmin = 0.0, cmax = 0.0;
   for(int i = 0; i < shape; i++)
   {
      double c = CandleClose(tf, 1 + i);
      if(c <= 0.0)
         return 0.0;
      cur[i] = c;
      if(i == 0 || c < cmin) cmin = c;
      if(i == 0 || c > cmax) cmax = c;
   }
   double crange = cmax - cmin;
   if(crange <= 0.0)
      return 0.0;
   for(int i = 0; i < shape; i++)
      cur[i] = (cur[i] - cmin) / crange;      // 0..1, price and volatility removed

   // --- scan history for the closest matches --------------------------------------
   // Keep the best N by distance. A simple insertion into a small ranked list is
   // cheaper here than sorting every candidate.
   int    keep = MathMax(3, PatternMemoryKeepMatches);
   double best_dist[32];
   double best_move[32];
   int    best_n = 0;
   if(keep > 32) keep = 32;

   double window[];
   ArrayResize(window, shape);

   for(int start = shape + horizon + 1; start <= history; start++)
   {
      double wmin = 0.0, wmax = 0.0;
      bool ok = true;
      for(int i = 0; i < shape; i++)
      {
         double c = CandleClose(tf, start + i);
         if(c <= 0.0) { ok = false; break; }
         window[i] = c;
         if(i == 0 || c < wmin) wmin = c;
         if(i == 0 || c > wmax) wmax = c;
      }
      if(!ok)
         break;                                // ran out of history

      double wrange = wmax - wmin;
      if(wrange <= 0.0)
         continue;

      double dist = 0.0;
      for(int i = 0; i < shape; i++)
      {
         double norm = (window[i] - wmin) / wrange;
         double d = norm - cur[i];
         dist += d * d;
      }
      dist = MathSqrt(dist / (double)shape);   // average per-point deviation

      if(dist > PatternMemoryMaxDistance)
         continue;                             // not similar enough to be evidence

      // What happened next? Measured from the shape's end, forward by the horizon,
      // in units of that window's own range so old and new eras compare fairly.
      double after = CandleClose(tf, start - horizon);
      double at_end = CandleClose(tf, start);
      if(after <= 0.0 || at_end <= 0.0)
         continue;
      double move = (after - at_end) / wrange;  // normalised outcome

      // Insert into the ranked list, closest first.
      if(best_n < keep)
      {
         best_dist[best_n] = dist;
         best_move[best_n] = move;
         best_n++;
      }
      else
      {
         int worst = 0;
         for(int k = 1; k < best_n; k++)
            if(best_dist[k] > best_dist[worst]) worst = k;
         if(dist < best_dist[worst])
         {
            best_dist[worst] = dist;
            best_move[worst] = move;
         }
      }
   }

   if(best_n < MathMax(3, PatternMemoryMinSamples))
   {
      pm_tf_bar = tf_bar_time; pm_bias = 0.0; pm_samples = best_n; pm_quality = 0.0;
      pm_detail = StringFormat("pattern memory: only %d close matches", best_n);
      samples = best_n; detail = pm_detail;
      return 0.0;
   }

   // --- what did those matches resolve into? --------------------------------------
   int up = 0, down = 0;
   double dist_sum = 0.0;
   for(int k = 0; k < best_n; k++)
   {
      dist_sum += best_dist[k];
      if(best_move[k] >= PatternMemoryMinOutcome)       up++;
      else if(best_move[k] <= -PatternMemoryMinOutcome) down++;
      // moves smaller than the threshold resolved nowhere and teach nothing
   }

   int decided = up + down;
   if(decided < MathMax(2, PatternMemoryMinSamples / 2))
   {
      pm_tf_bar = tf_bar_time; pm_bias = 0.0; pm_samples = best_n; pm_quality = 0.0;
      pm_detail = StringFormat("pattern memory: %d matches but no clear outcomes", best_n);
      samples = best_n; detail = pm_detail;
      return 0.0;
   }

   double bias = (double)(up - down) / (double)decided;   // -1..+1
   double avg_dist = dist_sum / (double)best_n;
   match_quality = MathMax(0.0, MathMin(1.0, 1.0 - (avg_dist / MathMax(0.01, PatternMemoryMaxDistance))));

   detail = StringFormat("pattern memory: %d matches, %d up / %d down -> %s %.0f%% (fit %.0f%%)",
                         best_n, up, down,
                         (bias > 0 ? "UP" : (bias < 0 ? "DOWN" : "flat")),
                         MathAbs(bias) * 100.0, match_quality * 100.0);

   pm_tf_bar = tf_bar_time;
   pm_bias = bias;
   pm_samples = best_n;
   pm_quality = match_quality;
   pm_detail = detail;

   samples = best_n;
   return bias;
}

// ============================================================================
// V159: BASKET PROJECTION - what this entry actually commits us to.
// ----------------------------------------------------------------------------
// The EA opens an entry and then discovers where it leads. Every risk check it has
// looks at the position as it exists NOW: current drawdown, current margin, current
// exposure. But a martingale entry is not a 0.25 lot position - it is a commitment
// to a whole ladder, and the only moment that commitment can be declined is before
// the first order exists.
//
// This walks the ladder forward before entering: if price runs against us, how many
// orders get added, at what total volume, what drawdown does that produce, and does
// the margin survive it. Then it asks the question that actually matters - is there
// a level in the way that would stop the recovery before it completes?
//
// A basket that runs out of margin at order five is not a trade that went wrong. It
// was never survivable, and that was knowable in advance.
// ============================================================================
// V160: BASKET HEALTH - one number for "how is this position actually doing?"
// ----------------------------------------------------------------------------
// The EA tracks drawdown, order count, margin, age and structure separately, and
// each has its own threshold. That works while only one of them is deteriorating.
// It fails when several are mildly bad at once - four orders used, 30% drawdown,
// eight hours old, structure turned - none of which trips its own limit, while the
// basket as a whole is clearly in trouble.
//
// A single health figure makes that state visible, and makes it actionable: a
// healthy basket should hold out for its full target, while a deteriorating one
// should be taking the first reasonable exit it is offered. The most expensive
// mistake in recovery trading is waiting for the original target long after the
// position stopped being able to reach it.
//
// AGE deserves its place here. A basket open for two days is not the same as one
// open for two hours at identical drawdown - it means the market went against the
// position and has not come back, which is precisely the situation that ends badly.
//
// Returns 1.0 (healthy) down to 0.0 (in trouble).
// ----------------------------------------------------------------------------
// V160b: how long is "too long" for a basket? The EA should not be told - it can
// measure it. A fixed 8-hour figure is wrong in both directions: for a scalper
// whose baskets normally close in twenty minutes it is far too generous, and for a
// slower configuration it would flag perfectly ordinary positions as stale.
//
// Only WINNING baskets are sampled. Those define what a normal lifetime looks like
// here; losing baskets are already the anomaly and would drag the reference toward
// exactly the behaviour being measured against.
// ----------------------------------------------------------------------------
// V170g: every persisted key now includes MagicNumber as well as the symbol. Without it, two
// instances on the same symbol - a live one and a test one, or two configurations being compared -
// write their learned statistics into the same slots and silently merge. The learning modules would
// then be drawing conclusions from a mixture of two different strategies.
string BasketAgeGVKey()
{
   return StringFormat("NAVIUS_BASKETAGE_%s_%d", _Symbol, MagicNumber);
}

void BasketAgeRecord(const int age_bars, const bool won)
{
   if(!EnableBasketHealth || !EnableAdaptiveBasketAge || age_bars <= 0)
      return;
   if(!won)
      return;                                   // losers do not define "normal"

   if(G_BASKET_AGE_TYPICAL <= 0.0)
      G_BASKET_AGE_TYPICAL = (double)age_bars;  // first sample
   else
   {
      double a = MathMax(0.01, MathMin(1.0, AdaptiveBasketAgeAlpha));
      G_BASKET_AGE_TYPICAL = G_BASKET_AGE_TYPICAL * (1.0 - a) + (double)age_bars * a;
   }

   GlobalVariableSet(BasketAgeGVKey(), G_BASKET_AGE_TYPICAL);

   if((AdaptiveBasketAgePrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v160b BASKET AGE] winning basket closed after %d bars | typical now %.0f bars",
                  age_bars, G_BASKET_AGE_TYPICAL);
}

void BasketAgeRestore()
{
   G_BASKET_AGE_TYPICAL = 0.0;
   if(!EnableAdaptiveBasketAge)
      return;
   string k = BasketAgeGVKey();
   if(GlobalVariableCheck(k))
      G_BASKET_AGE_TYPICAL = GlobalVariableGet(k);
}

// The age at which a basket counts as fully stale. Learned where possible, with the
// configured value as the fallback until enough winners have been seen.
int BasketStaleAgeBars()
{
   if(EnableAdaptiveBasketAge && G_BASKET_AGE_TYPICAL > 0.0)
   {
      double learned = G_BASKET_AGE_TYPICAL * MathMax(1.5, AdaptiveBasketAgeMultiple);
      // Bounded so one unusual basket cannot make the measure meaningless either way.
      learned = MathMax((double)AdaptiveBasketAgeMinBars,
                        MathMin((double)AdaptiveBasketAgeMaxBars, learned));
      return (int)MathRound(learned);
   }
   return MathMax(1, BasketHealthAgeBars);
}

// ============================================================================
// V161: SCALE-IN - commit fully only once the market agrees.
// ----------------------------------------------------------------------------
// The grid answers a wrong entry by adding size to it. That works when price comes
// back and is ruinous when it does not, and the EA cannot tell which case it is in
// at the moment it decides.
//
// Scale-in inverts the sequence. The first entry goes in at part size - enough to
// be in the trade, small enough that being wrong is cheap. The rest is added only
// after price has moved in favour by a meaningful amount, which is the market
// agreeing rather than the EA insisting.
//
// The trade-off is honest: when the setup is immediately right, a scale-in entry
// earns less than a full one, because part of the position was added later at a
// worse price. What it buys is that every setup which was simply wrong costs a
// fraction of what it used to - and on a martingale those are the ones that
// compound into the baskets that hurt.
//
// A completion is part of the FIRST entry, never a grid order. Without that
// distinction the ladder would multiply from the half-size part and shrink every
// subsequent lot - see EffectiveGridOrders / EffectiveLastLot.
// ============================================================================
// V161b: how much of the entry to take immediately is not a fixed number - it is a statement about
// how much the EA trusts THIS setup. A setup that barely qualified deserves a small first commitment
// and a large confirmation; one that cleared every bar by a wide margin, in a regime where the
// record says this system works, deserves most of its size straight away. A fixed fraction throws
// away information the EA already has.
double ScaleInAdaptiveFraction()
{
   double frac = MathMax(0.2, MathMin(0.95, ScaleInFirstFraction));
   if(!EnableAdaptiveScaleIn)
      return frac;

   // 1. Conviction: how far above the bar did this setup score?
   int bar = (G_SCORE_MIN_REQUIRED > 0) ? G_SCORE_MIN_REQUIRED
                                        : MinScoreForContext(G_SCORE_IS_MICRO);
   bar = MathMax(1, bar);
   int full = MathMax(bar + 1, ConfidenceLotFullScore);
   double t = (double)(G_SCORE_FINAL - bar) / (double)(full - bar);
   t = MathMax(0.0, MathMin(1.0, t));

   // A weak setup goes in at the floor fraction; a strong one at the ceiling.
   frac = ScaleInMinFraction + (ScaleInMaxFraction - ScaleInMinFraction) * t;

   // 2. Calibration: does the record actually support this score band? If a band has
   //    been losing, its conviction is not evidence and the first part stays small.
   if(EnableScoreCalibration)
   {
      int cal_n = 0;
      // Use `bar` from above, not the raw global: G_SCORE_MIN_REQUIRED is 0 on every scan that
      // reset the engine, and subtracting 0 would hand an ABSOLUTE score to a margin-banded
      // lookup - landing in the top band and reading back the wrong win rate.
      double cal_wr = ScoreBandWinRate(G_SCORE_FINAL - bar, cal_n);   // V249fix(auto-mode): margin, not absolute score
      if(cal_wr >= 0.0 && cal_wr <= CalibrationPoorWinRate)
         frac = ScaleInMinFraction;
   }

   // 3. Regime: in a volatile market the first move is least informative, so commit
   //    less up front and let the confirmation do more of the work.
   if(EnableRegimeSwitching && G_REGIME == REGIME_VOLATILE)
      frac *= MathMax(0.5, ScaleInVolatileFactor);

   return MathMax(0.2, MathMin(0.95, frac));
}

// Confirmation and abandonment distances scaled to what this market is actually doing.
// A fixed $0.80 is a meaningful move in a quiet session and noise in a fast one.
double ScaleInConfirmDistance()
{
   double base = (double)MathMax(1, ScaleInConfirmPoints);
   if(!EnableAdaptiveScaleIn)
      return base;

   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   if(atr <= 0.0)
      return base;

   // Express the configured distance as ATR multiples of the reference, then re-apply
   // it to the current ATR - so the threshold means the same thing in both regimes.
   double scaled = atr * MathMax(0.1, ScaleInConfirmATR);
   return MathMax(base * 0.4, MathMin(base * 2.5, scaled));
}

double ScaleInAbandonDistance()
{
   double base = (double)MathMax(1, ScaleInAbandonPoints);
   if(!EnableAdaptiveScaleIn)
      return base;

   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   if(atr <= 0.0)
      return base;

   double scaled = atr * MathMax(0.1, ScaleInAbandonATR);
   return MathMax(base * 0.4, MathMin(base * 2.5, scaled));
}

void ScaleInReset()
{
   G_SCALEIN_PENDING_LOT = 0.0;
   G_SCALEIN_ENTRY_PRICE = 0.0;
   G_SCALEIN_DIR = 0;
   G_SCALEIN_BAR = 0;
}

// Records that a first entry was taken at part size, with the remainder pending.
void ScaleInArm(const int dir, const double entry_price, const double remaining_lot)
{
   if(!EnableScaleIn || dir == 0 || entry_price <= 0.0 || remaining_lot <= 0.0)
      return;
   G_SCALEIN_PENDING_LOT = remaining_lot;
   G_SCALEIN_ENTRY_PRICE = entry_price;
   G_SCALEIN_DIR = dir;
   G_SCALEIN_BAR = G_BARS_SEEN;

   if((ScaleInPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v161 SCALE-IN] entered at part size, %.2f lots pending confirmation from %.2f",
                  remaining_lot, entry_price);
}

// Checks whether the pending remainder should now be added, and returns the lot to
// open (0 = nothing to do).
double ScaleInDueLot(string &reason)
{
   reason = "";
   if(!EnableScaleIn || G_SCALEIN_PENDING_LOT <= 0.0 || G_SCALEIN_DIR == 0 || _Point <= 0.0)
      return 0.0;

   // FIX(scalein-orphan): the armed completion must never outlive the basket it belongs to.
   // ScaleInReset() was only ever reached from inside CloseSirusBasket(), so a basket that ended
   // ANY other way - the broker hitting the individual first-entry TP (UseIndividualTPForFirstEntry
   // is on by default), a manual close, a stop-out, a partial close failure - left
   // G_SCALEIN_PENDING_LOT/DIR/ENTRY_PRICE armed. On the next tick this function would see the
   // price had moved far enough "in favour" (it had - that is why the TP hit), confirm, and the
   // send below would open a brand-new NAKED position, in the old direction, at the top of the move
   // that just took profit, with no TP, no SL, no basket, and none of the entry gates.
   // Read LIVE positions rather than G_BASKET_ORDERS: this runs BEFORE RefreshGridDashboardStats()
   // in the same tick, so the cached counter is a tick stale and would not see the closure.
   {
      int      si_orders = 0;
      double   si_vol = 0.0, si_avg = 0.0, si_profit = 0.0, si_lastp = 0.0, si_lastlot = 0.0;
      long     si_bdir = -1;
      datetime si_lastt = 0;
      if(!GetSirusBasketStats(si_orders, si_vol, si_avg, si_profit, si_bdir,
                               si_lastp, si_lastlot, si_lastt) || si_orders <= 0)
      {
         // CTrade::Buy returns true for TRADE_RETCODE_PLACED as well as DONE, so on async/exchange
         // execution the just-sent first entry may not be in PositionsTotal() yet. That is an
         // order in flight, not a vanished basket - do not throw the armed remainder away for it.
         if(G_LAST_ENTRY_TIME > 0 && (TimeCurrent() - G_LAST_ENTRY_TIME) <= 3)
            return 0.0;
         reason = "basket is gone - completion abandoned";
         ScaleInReset();
         G_SCALEIN_EXTRA_ORDERS = 0;
         return 0.0;
      }

      int si_bdir_i = (si_bdir == POSITION_TYPE_BUY) ? 1 : ((si_bdir == POSITION_TYPE_SELL) ? -1 : 0);
      if(si_bdir_i == 0 || si_bdir_i != G_SCALEIN_DIR)
      {
         // Mixed (-2) or a new basket in the other direction - completing would add AGAINST it.
         reason = "basket direction no longer matches the armed completion - abandoned";
         ScaleInReset();
         G_SCALEIN_EXTRA_ORDERS = 0;
         return 0.0;
      }
   }

   // No completion once the basket has moved past its first entry - by then the grid
   // is managing the position and adding more to the original entry is meaningless.
   if(G_BASKET_ORDERS > (1 + G_SCALEIN_EXTRA_ORDERS))
   {
      reason = "grid already active - completion abandoned";
      ScaleInReset();
      return 0.0;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   double moved_pts = (mid - G_SCALEIN_ENTRY_PRICE) / _Point * (double)G_SCALEIN_DIR;
   double confirm_at = ScaleInConfirmDistance();
   double abandon_at = ScaleInAbandonDistance();

   // Confirmation: price has moved our way by enough that the setup is working.
   if(moved_pts >= confirm_at)
   {
      // V161b: distance alone is a weak test - price drifting there on thin, overlapping bars is
      // not the market agreeing, it is the market wandering. Require the move to have some
      // conviction behind it, and refuse to complete into a level that is about to stop it.
      if(EnableScaleInQuality)
      {
         // 1. Did the move have body, or was it drift? Reuse the impulse reading rather than
         //    inventing a second definition of "real move".
         int thrust = RecentThrustDir();
         bool has_conviction = (thrust == G_SCALEIN_DIR);

         // 2. Is there a wall immediately ahead? Completing right into one means adding size at
         //    the worst price in the move.
         double wall = (G_SCALEIN_DIR > 0) ? ZoneMapNearestResistance(mid)
                                           : ZoneMapNearestSupport(mid);
         bool room_ok = true;
         if(wall > 0.0)
         {
            double wall_pts = MathAbs(wall - mid) / _Point;
            if(wall_pts < confirm_at * MathMax(0.5, ScaleInMinRoomFactor) &&
               ZoneMapStrength(wall) >= ScaleInWallMinStrength)
               room_ok = false;
         }

         if(!has_conviction && ScaleInRequireConviction)
         {
            reason = "price reached the confirmation distance but drifted there - waiting for a real move";
            return 0.0;
         }
         if(!room_ok)
         {
            reason = StringFormat("confirmation reached but a wall sits at %.2f - completing here would buy the high", wall);
            return 0.0;
         }
      }

      double lot = G_SCALEIN_PENDING_LOT;
      reason = StringFormat("confirmed by %.0f pts in favour (needed %.0f)", moved_pts, confirm_at);
      return lot;
   }

   // Abandoned: price went against the entry far enough that the grid will handle it.
   if(moved_pts <= -abandon_at)
   {
      reason = StringFormat("abandoned - %.0f pts against, the grid takes over", -moved_pts);
      ScaleInReset();
      return 0.0;
   }

   // Timed out: a setup that has gone nowhere is not a setup worth completing.
   if(ScaleInMaxWaitBars > 0 && (G_BARS_SEEN - G_SCALEIN_BAR) > ScaleInMaxWaitBars)
   {
      reason = "timed out - no confirmation, remainder dropped";
      ScaleInReset();
      return 0.0;
   }

   return 0.0;
}

// ============================================================================
double BasketHealthIndex(string &detail)
{
   detail = "";
   if(!EnableBasketHealth || G_BASKET_ORDERS <= 0)
      return 1.0;

   // Each component is a 0..1 "how much of this budget is spent" figure.
   double spent_dd = 0.0;
   if(BasketSLPercent > 0.0)
      spent_dd = MathMax(0.0, MathMin(1.0, G_BASKET_DD_PERCENT / BasketSLPercent));

   double spent_orders = 0.0;
   if(MaxOrders > 0)
      spent_orders = MathMax(0.0, MathMin(1.0, (double)G_BASKET_ORDERS / (double)MaxOrders));

   double spent_margin = 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin_used = AccountInfoDouble(ACCOUNT_MARGIN);
   if(equity > 0.0 && MaxBasketMarginPercent > 0.0)
      spent_margin = MathMax(0.0, MathMin(1.0, (margin_used / equity * 100.0) / MaxBasketMarginPercent));

   // Age: how long has this basket been unable to close?
   double spent_age = 0.0;
   int stale_at = BasketStaleAgeBars();
   if(G_BASKET_OPEN_BAR > 0 && stale_at > 0)
   {
      int age_bars = G_BARS_SEEN - G_BASKET_OPEN_BAR;
      spent_age = MathMax(0.0, MathMin(1.0, (double)age_bars / (double)stale_at));
   }

   // Structure: has the reason for this basket broken down?
   double spent_structure = 0.0;
   if(EnableStructureBasketExit)
   {
      string sb_detail = "";
      if(StructureAgainstBasket(sb_detail))
         spent_structure = 1.0;
   }

   double wsum = BasketHealthWeightDD + BasketHealthWeightOrders + BasketHealthWeightMargin
               + BasketHealthWeightAge + BasketHealthWeightStructure;
   if(wsum <= 0.0)
      return 1.0;

   double spent = (spent_dd        * BasketHealthWeightDD
                 + spent_orders    * BasketHealthWeightOrders
                 + spent_margin    * BasketHealthWeightMargin
                 + spent_age       * BasketHealthWeightAge
                 + spent_structure * BasketHealthWeightStructure) / wsum;

   double health = MathMax(0.0, MathMin(1.0, 1.0 - spent));

   detail = StringFormat("basket health %.0f%% (dd %.0f%%, orders %d/%d, age %d bars%s)",
                         health * 100.0, G_BASKET_DD_PERCENT,
                         G_BASKET_ORDERS, MaxOrders,
                         (G_BASKET_OPEN_BAR > 0 ? (G_BARS_SEEN - G_BASKET_OPEN_BAR) : 0),
                         (spent_structure > 0.0 ? ", structure broken" : ""));
   detail += StringFormat(" [stale at %d]", stale_at);
   return health;
}

// Target multiplier from health: a struggling basket should take what it can get.
double BasketHealthTPFactor()
{
   if(!EnableBasketHealth || G_BASKET_ORDERS <= 0)
      return 1.0;

   string h_detail = "";
   double health = BasketHealthIndex(h_detail);

   if(health >= BasketHealthGood)
      return 1.0;                                  // healthy - hold out for the full target

   // Below the healthy mark, scale the target down toward the floor. The worse the
   // basket, the more valuable simply being flat becomes.
   double span = MathMax(0.01, BasketHealthGood - BasketHealthPoor);
   double t = MathMax(0.0, MathMin(1.0, (health - BasketHealthPoor) / span));
   return BasketHealthMinTPFactor + (1.0 - BasketHealthMinTPFactor) * t;
}

// ============================================================================
double ProjectBasketRisk(const int entry_dir, const double entry_price,
                         int &proj_orders, double &proj_lots, double &proj_dd_pct,
                         double &proj_margin_pct, string &detail)
{
   proj_orders = 0; proj_lots = 0.0; proj_dd_pct = 0.0; proj_margin_pct = 0.0;
   detail = "";

   if(!EnableBasketProjection || entry_dir == 0 || entry_price <= 0.0 || _Point <= 0.0)
      return 0.0;

   // V170b: per-bar cache keyed on direction. This walks the whole ladder calling OrderCalcMargin
   // at every rung and asks the lot engine for its full chain - by some distance the most expensive
   // thing here, and it is called from both the score engine and the dashboard on every tick. The
   // answer cannot change until a bar closes or the account balance moves.
   static int    pj_bar[3];
   static double pj_sev[3];
   static int    pj_ord[3];
   static double pj_lots[3], pj_dd[3], pj_marg[3];
   static string pj_det[3];
   static bool   pj_init = false;
   if(!pj_init)
   {
      for(int z = 0; z < 3; z++) { pj_bar[z] = -100000; pj_sev[z] = 0.0; }
      pj_init = true;
   }
   int pj_slot = (entry_dir > 0) ? 1 : 2;
   if(pj_bar[pj_slot] == G_BARS_SEEN)
   {
      proj_orders     = pj_ord[pj_slot];
      proj_lots       = pj_lots[pj_slot];
      proj_dd_pct     = pj_dd[pj_slot];
      proj_margin_pct = pj_marg[pj_slot];
      detail          = pj_det[pj_slot];
      return pj_sev[pj_slot];
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double base    = (AutoLotUseEquity ? equity : balance);
   if(base <= 0.0)
      return 0.0;

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;
   double value_per_point = tick_value * (_Point / tick_size);

   ENUM_ORDER_TYPE otype = (entry_dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   int    max_orders = MathMax(1, MaxOrders);
   // V170b: ask for the UNADJUSTED lot. Without this flag the projection measures a lot it has
   // already shrunk, finds the smaller ladder survivable, allows full size again, and oscillates -
   // the entry size flipping between 0.25 and 0.135 on alternate ticks. The projection must reason
   // about the ladder the settings describe, not the one its own previous answer produced.
   G_PROJECTION_MEASURING = true;
   double lot = LotForCurrentEntry();
   G_PROJECTION_MEASURING = false;
   if(lot <= 0.0)
      lot = StartLot;

   double total_lots = lot;
   double weighted_price = entry_price;   // running average entry
   double total_margin = 0.0;
   double m0 = 0.0;
   if(OrderCalcMargin(otype, _Symbol, lot, entry_price, m0))
      total_margin = m0;

   double price = entry_price;
   double worst_dd_money = 0.0;
   int    orders = 1;

   // Walk the ladder as it would actually be built.
   for(int k = 1; k < max_orders; k++)
   {
      double dist_pts = GridDistanceForNextOrder(k);
      double regime_f = RegimeGridFactor();
      if(regime_f > 0.0)
         dist_pts *= regime_f;
      if(dist_pts <= 0.0)
         break;

      // Price moves against the basket by one grid step.
      price -= (double)entry_dir * dist_pts * _Point;

      double next_lot = NextGridLot(lot, k);
      if(next_lot <= 0.0)
         break;

      double m = 0.0;
      if(OrderCalcMargin(otype, _Symbol, next_lot, price, m))
         total_margin += m;

      // Running average entry across the ladder so far.
      weighted_price = ((weighted_price * total_lots) + (price * next_lot)) / (total_lots + next_lot);
      total_lots += next_lot;
      lot = next_lot;
      orders++;

      // Floating loss at this point: distance from average entry, on the whole size.
      double adverse_pts = MathAbs(price - weighted_price) / _Point;
      double dd_money = adverse_pts * value_per_point * total_lots;
      if(dd_money > worst_dd_money)
         worst_dd_money = dd_money;
   }

   proj_orders     = orders;
   proj_lots       = total_lots;
   proj_dd_pct     = (base > 0.0) ? (worst_dd_money / base) * 100.0 : 0.0;
   proj_margin_pct = (equity > 0.0) ? (total_margin / equity) * 100.0 : 0.0;

   // How much room does the full ladder need, and is anything in the way?
   double ladder_span_pts = MathAbs(entry_price - price) / _Point;
   double blocking = 0.0;
   string block_note = "";
   if(ProjectionCheckLevels)
   {
      // The level the recovery would have to survive: one opposing the basket,
      // sitting inside the span the ladder needs.
      double lvl = (entry_dir > 0) ? ZoneMapNearestSupport(entry_price)
                                   : ZoneMapNearestResistance(entry_price);
      if(lvl > 0.0)
      {
         double lvl_dist = MathAbs(entry_price - lvl) / _Point;
         if(lvl_dist < ladder_span_pts)
         {
            blocking = ZoneMapStrength(lvl);
            block_note = StringFormat(", %.1f-strength level at %.2f inside the ladder's span",
                                      blocking, lvl);
         }
      }
   }

   detail = StringFormat("projection: %d orders, %.2f lots, DD %.0f%%, margin %.0f%%, span %.0f pts%s",
                         proj_orders, proj_lots, proj_dd_pct, proj_margin_pct,
                         ladder_span_pts, block_note);

   // Severity: the worst of the three constraints, 0 = comfortable, 1 = at the limit.
   double dd_sev     = (BasketSLPercent > 0.0) ? (proj_dd_pct / BasketSLPercent) : 0.0;
   double margin_sev = (MaxBasketMarginPercent > 0.0) ? (proj_margin_pct / MaxBasketMarginPercent) : 0.0;
   double sev = MathMax(0.0, MathMax(dd_sev, margin_sev));

   pj_bar[pj_slot]  = G_BARS_SEEN;
   pj_sev[pj_slot]  = sev;
   pj_ord[pj_slot]  = proj_orders;
   pj_lots[pj_slot] = proj_lots;
   pj_dd[pj_slot]   = proj_dd_pct;
   pj_marg[pj_slot] = proj_margin_pct;
   pj_det[pj_slot]  = detail;

   return sev;
}

// ============================================================================
int ForcedFlowDirection(double &intensity, string &detail)
{
   intensity = 0.0;
   detail = "";

   if(!EnableForcedFlow || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = ForcedFlowTF;
   int look = MathMax(3, ForcedFlowLookbackBars);

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0;

   double c_now   = CandleClose(tf, 1);
   double c_start = CandleClose(tf, look);
   if(c_now <= 0.0 || c_start <= 0.0)
      return 0;

   double net = c_now - c_start;
   int dir = (net > 0.0) ? 1 : -1;
   double net_pts = MathAbs(net) / _Point;

   // 1. Size: is this move unusually large for the timeframe?
   double size_atr = net_pts / atr;
   if(size_atr < ForcedFlowMinSizeATR)
   {
      detail = "flow: ordinary size";
      return 0;
   }

   // 2. Retracement: a decision breathes, a liquidation does not. Measure the
   //    deepest pullback against the move as a fraction of the move itself.
   double extreme = c_start;
   double worst_pull = 0.0;
   for(int i = look; i >= 1; i--)
   {
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0)
         continue;

      if(dir > 0)
      {
         if(h > extreme) extreme = h;
         double pull = (extreme - l) / _Point;
         if(pull > worst_pull) worst_pull = pull;
      }
      else
      {
         if(l < extreme) extreme = l;
         double pull = (h - extreme) / _Point;
         if(pull > worst_pull) worst_pull = pull;
      }
   }
   double pull_frac = worst_pull / MathMax(1.0, net_pts);
   if(pull_frac > ForcedFlowMaxPullback)
   {
      detail = StringFormat("flow: retraced %.0f%% - a decision, not forced", pull_frac * 100.0);
      return 0;
   }

   // 3. Body ratio: forced fills leave full-bodied candles with little wick,
   //    because there is no two-way trade happening at all.
   double body_sum = 0.0, range_sum = 0.0;
   for(int i = 1; i <= look; i++)
   {
      double o = CandleOpen(tf, i);
      double c = CandleClose(tf, i);
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;
      body_sum  += MathAbs(c - o);
      range_sum += (h - l);
   }
   double body_ratio = (range_sum > 0.0) ? (body_sum / range_sum) : 0.0;
   if(body_ratio < ForcedFlowMinBodyRatio)
   {
      detail = StringFormat("flow: bodies only %.0f%% of range - two-way trade present", body_ratio * 100.0);
      return 0;
   }

   // All three signatures present. Intensity blends them so a marginal case scores
   // low and an unmistakable one scores high.
   double size_q = MathMax(0.0, MathMin(1.0, (size_atr - ForcedFlowMinSizeATR) / MathMax(0.1, ForcedFlowFullSizeATR - ForcedFlowMinSizeATR)));
   double pull_q = MathMax(0.0, MathMin(1.0, 1.0 - (pull_frac / MathMax(0.01, ForcedFlowMaxPullback))));
   double body_q = MathMax(0.0, MathMin(1.0, (body_ratio - ForcedFlowMinBodyRatio) / MathMax(0.01, 1.0 - ForcedFlowMinBodyRatio)));

   intensity = MathMax(0.0, MathMin(1.0, (size_q + pull_q + body_q) / 3.0));

   detail = StringFormat("forced %s flow (%.0f%%): %.1f ATR, %.0f%% pullback, %.0f%% bodies",
                         (dir > 0 ? "buying" : "selling"), intensity * 100.0,
                         size_atr, pull_frac * 100.0, body_ratio * 100.0);
   return dir;
}

// ============================================================================
// V156: REGIME - one strategy is not appropriate for every market.
// ----------------------------------------------------------------------------
// The EA runs the same settings whether price is trending, ranging, or thrashing.
// MARKET_STATE exists, but it only ever blocks - it never changes HOW the EA trades.
// So the same $2.50 target, the same $7 grid spacing and the same score bar apply
// to a market moving $80 a day and one moving $15.
//
// These are not the same problem:
//   TRENDING - moves persist. Targets can be wider, pullback entries are worth
//              taking, and fading anything is expensive.
//   RANGING  - moves stall at the edges. Targets must be tighter, levels matter
//              far more, and continuation entries fail repeatedly.
//   VOLATILE - moves are large but unreliable. Everything needs more room, and
//              fewer trades are worth taking at all.
//   QUIET    - moves are small. A normal target may simply be unreachable, and
//              the spread eats a larger share of whatever is left.
//
// Regime is deliberately slow to change: flipping settings mid-basket would be
// worse than using the wrong ones consistently, so a switch needs sustained
// evidence, not a single bar.
// ============================================================================

// (REGIME_* defines live at the top of the file with the other structural defines)


string RegimeName(const int r)
{
   switch(r)
   {
      case REGIME_TRENDING: return "TRENDING";
      case REGIME_RANGING:  return "RANGING";
      case REGIME_VOLATILE: return "VOLATILE";
      case REGIME_QUIET:    return "QUIET";
   }
   return "UNKNOWN";
}

// Reads the current regime candidate from volatility and directional persistence.
int RegimeCandidate(string &why)
{
   why = "";
   if(_Point <= 0.0)
      return REGIME_UNKNOWN;

   ENUM_TIMEFRAMES tf = RegimeTF;

   double atr_now = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr_now <= 0.0)
      return REGIME_UNKNOWN;

   // Volatility relative to its own recent norm - "large" only means anything
   // compared to what this market has been doing lately.
   double atr_ref = ATRPointsManual(tf, MathMax(ATRPeriod * 4, 40), 1);
   double vol_ratio = (atr_ref > 0.0) ? (atr_now / atr_ref) : 1.0;

   double adx = SirusADX(tf, RegimeADXPeriod, 0, 1);

   // How much of the recent range did price actually travel through? A trending
   // market covers ground; a ranging one revisits the same prices.
   int look = MathMax(10, RegimeLookbackBars);
   double hi = HighestHigh(tf, look, 1);
   double lo = LowestLow(tf, look, 1);
   double c_now = CandleClose(tf, 1);
   double c_old = CandleClose(tf, look);
   double span = (hi - lo) / _Point;
   double net  = MathAbs(c_now - c_old) / _Point;
   double efficiency = (span > 0.0) ? (net / span) : 0.0;

   if(vol_ratio >= RegimeVolatileRatio)
   {
      why = StringFormat("volatility %.2fx its norm", vol_ratio);
      return REGIME_VOLATILE;
   }
   if(vol_ratio <= RegimeQuietRatio)
   {
      why = StringFormat("volatility only %.2fx its norm", vol_ratio);
      return REGIME_QUIET;
   }
   if(adx >= RegimeTrendADX && efficiency >= RegimeTrendEfficiency)
   {
      why = StringFormat("ADX %.0f, travelled %.0f%% of range", adx, efficiency * 100.0);
      return REGIME_TRENDING;
   }
   if(adx < RegimeTrendADX && efficiency <= RegimeRangeEfficiency)
   {
      why = StringFormat("ADX %.0f, only %.0f%% of range covered", adx, efficiency * 100.0);
      return REGIME_RANGING;
   }

   why = StringFormat("ADX %.0f, efficiency %.0f%% - between regimes", adx, efficiency * 100.0);
   return REGIME_UNKNOWN;
}

// Updates the regime once per bar, requiring sustained agreement before switching.
void RegimeUpdate()
{
   static int last_bar = -100000;
   if(last_bar > G_BARS_SEEN) last_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(!EnableRegimeSwitching || last_bar == G_BARS_SEEN)
      return;
   last_bar = G_BARS_SEEN;

   string why = "";
   int cand = RegimeCandidate(why);

   if(cand == G_REGIME_CANDIDATE)
      G_REGIME_AGREE++;
   else
   {
      G_REGIME_CANDIDATE = cand;
      G_REGIME_AGREE = 1;
   }

   // Switching settings mid-basket on a single bar's reading would be worse than
   // running the wrong ones consistently.
   if(cand != REGIME_UNKNOWN && cand != G_REGIME &&
      G_REGIME_AGREE >= MathMax(2, RegimeConfirmBars))
   {
      if((RegimePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v156 REGIME] %s -> %s (%s, held %d bars)",
                     RegimeName(G_REGIME), RegimeName(cand), why, G_REGIME_AGREE);
      G_REGIME = cand;
      G_REGIME_SINCE_BAR = G_BARS_SEEN;
   }

   G_REGIME_TEXT = StringFormat("regime: %s (%s)", RegimeName(G_REGIME), why);
}

// --- regime-dependent adjustments ---------------------------------------------
// Each returns a multiplier or offset the rest of the EA applies. Kept modest:
// the regime should shift emphasis, not turn the EA into a different system.

double RegimeTPFactor()
{
   if(!EnableRegimeSwitching)
      return 1.0;
   switch(G_REGIME)
   {
      case REGIME_TRENDING: return RegimeTrendTPFactor;    // moves persist - let it run
      case REGIME_RANGING:  return RegimeRangeTPFactor;    // stalls at the edges - take less
      case REGIME_VOLATILE: return RegimeVolatileTPFactor; // wider swings, wider target
      case REGIME_QUIET:    return RegimeQuietTPFactor;    // a normal target may be unreachable
   }
   return 1.0;
}

double RegimeGridFactor()
{
   if(!EnableRegimeSwitching)
      return 1.0;
   switch(G_REGIME)
   {
      case REGIME_TRENDING: return RegimeTrendGridFactor;    // adverse runs go further
      case REGIME_RANGING:  return RegimeRangeGridFactor;    // reversion comes sooner
      case REGIME_VOLATILE: return RegimeVolatileGridFactor; // needs real room
      case REGIME_QUIET:    return RegimeQuietGridFactor;
   }
   return 1.0;
}

int RegimeScoreOffset()
{
   if(!EnableRegimeSwitching)
      return 0;
   switch(G_REGIME)
   {
      case REGIME_VOLATILE: return RegimeVolatileScoreOffset;  // demand more before committing
      case REGIME_QUIET:    return RegimeQuietScoreOffset;
   }
   return 0;
}

// ============================================================================
// V162: NOISE - price moving without going anywhere.
// ----------------------------------------------------------------------------
// There are stretches where the market is busy and pointless: bars print, ranges
// fill, every indicator produces readings, and after forty bars price is where it
// started. Nothing is wrong with the signals during those stretches - they are
// simply describing noise, and a signal describing noise is not a weak signal, it
// is a meaningless one.
//
// The EA has no defence against this. A setup can clear every filter and score 12
// in conditions where a $2.50 target was never reachable, because price is not
// travelling in any direction long enough to cover it.
//
// The measure is the ratio between DISPLACEMENT and DISTANCE TRAVELLED. Price that
// moves $8 in total to end up $6 away is trending; price that moves $8 to end up
// $0.50 away is churning. The second is where scalp targets go to die.
//
// This is deliberately separate from volatility. A quiet market can be efficient
// (small moves, but they go somewhere) and a volatile one can be pure churn - the
// regime detector reads size, this reads purpose.
//
// Returns 0.0 (clean directional movement) to 1.0 (pure churn).
// ============================================================================
// V163: PRESSURE - who is winning each bar, as distinct from where price went.
// ----------------------------------------------------------------------------
// Every directional reading in this EA is derived from RESULT: price closed higher,
// structure made a higher high, the trend is up. All true, and all backward-looking
// - they describe a move that has already happened.
//
// Each bar is a contest, and the bar itself records who won it. A bar that opens at
// its low and closes at its high was taken by buyers outright. One that spikes down
// and closes near its high was attempted by sellers and taken back. The body and
// the wicks say which side had control, independently of the net direction over the
// last hour.
//
// The useful case is when the two disagree. Price still falling while each
// successive bar is being defended harder - longer lower wicks, bodies shrinking,
// closes creeping toward the highs - is sellers running out of conviction while
// still nominally in charge. That divergence appears BEFORE the reversal shows up
// in price, structure, or any indicator built on closes.
//
// Returns pressure -1..+1 (positive = buyers), plus whether it is strengthening
// or fading relative to the direction price is actually moving.
// ============================================================================
// V164: SESSION CONTEXT - the market runs on events, not on bars.
// ----------------------------------------------------------------------------
// The EA measures time in bars, and treats every bar as equivalent. The market does
// not work that way. It runs on a schedule: Asia drifts in thin ranges, London
// opens and expands them, the New York overlap carries the day's real volume, and
// rollover is a dead zone of widened spreads where price does whatever it likes on
// no participation at all.
//
// Two things follow that bars cannot express.
//
// First, WHICH session it is changes what a setup means. A range breakout at 03:00
// and the same breakout at 09:00 are different trades - one has nobody behind it.
//
// Second, PROXIMITY to a session change matters more than anything happening now.
// Fifteen minutes before London, the current move is about to be overwritten by
// participants who are not in the market yet. Any reading taken then describes a
// market that is about to stop existing.
//
// The second point is the one bars can never capture: "20 minutes to London" is
// not a quantity of bars, it is a fact about what is coming.
// ============================================================================
// V165: SPREAD ECONOMICS - what the trade costs before it can earn anything.
// ----------------------------------------------------------------------------
// The EA checks spread against a maximum and moves on. That answers "is the spread
// acceptable" but never "is this trade worth its cost", which is the question that
// decides whether a scalp makes money.
//
// A $2.50 target at $0.35 spread gives away 14% of the move before price does
// anything. At $0.60 it is 24%. At $1.00 - which happens at rollover and around
// news - the trade needs to travel 40% further than its target implies just to
// break even. The setup quality has not changed at all; the economics have.
//
// Two consequences. A trade whose cost ratio is bad should be refused even with a
// perfect score, because the arithmetic does not work. And since spread widening is
// not random - rollover, news, session edges, thin hours - it can be anticipated
// rather than only reacted to.
//
// Returns the cost ratio (spread / target), with the reason spread is elevated.
// ============================================================================
// V166: CARRY COST, LOSS STREAKS, AND REPEATED MISTAKES
// ----------------------------------------------------------------------------
// Three gaps that share a source: the EA looks at each basket in isolation and
// never at what came before it or what it has already paid.
//
// CARRY - a basket that stays open pays swap every day. The profit figure includes
// it, but the TARGET does not: a $2.50 target on a two-day-old basket that has paid
// $3 in swap closes for a loss while reporting a win. The target has to clear what
// the position has already cost, or "take profit" stops meaning what it says.
//
// STREAKS - one loss is variance. Three consecutive losses is information: the
// market has moved into a state this system does not handle. The EA currently
// treats both identically, pausing thirty minutes after either.
//
// REPETITION - if the last two baskets both lost at the same level, the third one
// there is not a fresh opportunity. It is the same mistake with a new timestamp.
// ============================================================================
// V169: THE LAST FOUR - exit quality, slippage, daily state, and rental spread.
// ----------------------------------------------------------------------------
// Four small gaps, none of which changes how a trade is chosen, and all of which
// answer questions the EA currently cannot.
//
// EXIT QUALITY - the EA knows whether it hit its target. It does not know what
// happened next. If price keeps running after almost every exit, the target is too
// small and the EA is leaving most of each move behind. If price turns just before
// the target most times, it is too large and wins are being handed back. Only what
// happens AFTER the close can distinguish these, and nothing currently looks.
//
// SLIPPAGE - the difference between the price asked for and the price received. On
// a $2.50 target a persistent $0.10 of slippage is 4% of every trade, paid twice.
// Unmeasured, it simply looks like the strategy underperforming.
//
// DAILY STATE - most systems give back the day's gains in the last hour. Knowing
// that the day is already good is a reason to be harder to convince, not a reason
// to stop.
//
// RENTAL SPREAD - this EA is rented. If fifty copies fire on the same signal in the
// same second, they compete for the same liquidity and every one of them gets a
// worse fill. A small random delay costs nothing and removes the pile-up.
// ============================================================================

// --- exit quality ------------------------------------------------------------
double G_EXIT_WATCH_PRICE = 0.0;    // price the last basket closed at
int    G_EXIT_WATCH_BAR   = 0;
int    G_EXIT_WATCH_DIR   = 0;      // direction the closed basket had
double G_EXIT_RAN_ON      = 0.0;    // times price kept going our way after the exit
double G_EXIT_TURNED      = 0.0;    // times it turned against, meaning the exit was timely

void ExitQualityArm(const int dir, const double close_price)
{
   if(!EnableExitQuality || dir == 0 || close_price <= 0.0)
      return;
   G_EXIT_WATCH_DIR   = dir;
   G_EXIT_WATCH_PRICE = close_price;
   G_EXIT_WATCH_BAR   = G_BARS_SEEN;
}

void ExitQualitySettle()
{
   if(!EnableExitQuality || G_EXIT_WATCH_DIR == 0 || _Point <= 0.0)
      return;
   if((G_BARS_SEEN - G_EXIT_WATCH_BAR) < MathMax(3, ExitQualityHorizonBars))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double after_pts = (mid - G_EXIT_WATCH_PRICE) / _Point * (double)G_EXIT_WATCH_DIR;

   if(after_pts >= (double)ExitQualityRunOnPoints)
      G_EXIT_RAN_ON += 1.0;         // we left money on the table
   else if(after_pts <= -(double)ExitQualityRunOnPoints)
      G_EXIT_TURNED += 1.0;         // exiting when we did was right

   double total = G_EXIT_RAN_ON + G_EXIT_TURNED;
   if(ExitQualityMaxSamples > 0 && total > (double)ExitQualityMaxSamples)
   {
      double scale = (double)ExitQualityMaxSamples / total;
      G_EXIT_RAN_ON *= scale;
      G_EXIT_TURNED *= scale;
   }

   if((ExitQualityPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v169 EXIT] price went %.0f pts after the close | ran-on %.0f / turned %.0f",
                  after_pts, G_EXIT_RAN_ON, G_EXIT_TURNED);

   G_EXIT_WATCH_DIR = 0;
}

string ExitQualityText()
{
   if(!EnableExitQuality)
      return "";
   double total = G_EXIT_RAN_ON + G_EXIT_TURNED;
   if(total < 3.0)
      return "exits: not enough closed baskets yet";
   double ran = G_EXIT_RAN_ON / total;
   string verdict = (ran >= ExitQualityTargetTooSmall) ? " - target may be too small"
                  : ((ran <= (1.0 - ExitQualityTargetTooSmall)) ? " - target may be too large" : " - target looks about right");
   return StringFormat("exits: price kept running %.0f%% of the time (%.0f samples)%s",
                       ran * 100.0, total, verdict);
}

// --- slippage ----------------------------------------------------------------
double G_SLIP_TOTAL = 0.0;
double G_SLIP_COUNT = 0.0;

void SlippageRecord(const double requested, const double filled, const int dir)
{
   if(!EnableSlippageTracking || requested <= 0.0 || filled <= 0.0 || dir == 0 || _Point <= 0.0)
      return;
   // Positive = worse than asked for (paid more on a buy, received less on a sell).
   double slip = (filled - requested) / _Point * (double)dir;
   MBCostSlipRecord(slip);   // plan stage 6: slippage memory per server hour
   G_SLIP_TOTAL += slip;
   G_SLIP_COUNT += 1.0;

   if(SlippageMaxSamples > 0 && G_SLIP_COUNT > (double)SlippageMaxSamples)
   {
      double scale = (double)SlippageMaxSamples / G_SLIP_COUNT;
      G_SLIP_TOTAL *= scale;
      G_SLIP_COUNT *= scale;
   }
}

string SlippageText()
{
   if(!EnableSlippageTracking || G_SLIP_COUNT < 3.0)
      return "";
   double avg = G_SLIP_TOTAL / G_SLIP_COUNT;
   double target = BaseBasketTPPoints();
   double share = (target > 0.0) ? (MathAbs(avg) / target) * 100.0 : 0.0;
   return StringFormat("slippage: %.0f pts average (%.1f%% of target, %.0f fills)",
                       avg, share, G_SLIP_COUNT);
}

// --- daily state -------------------------------------------------------------
double G_DAY_START_BALANCE = 0.0;
int    G_DAY_STAMP = -1;

void DailyStateUpdate()
{
   if(!EnableDailyState)
      return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int stamp = dt.year * 10000 + dt.mon * 100 + dt.day;
   if(stamp != G_DAY_STAMP)
   {
      G_DAY_STAMP = stamp;
      G_DAY_START_BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

// Extra score demanded once the day is already good. Protecting a good day is worth
// more than adding to it - most systems give the day back in the last hour.
int DailyStateScoreOffset(string &detail)
{
   detail = "";
   if(!EnableDailyState || G_DAY_START_BALANCE <= 0.0)
      return 0;

   double now_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double gain_pct = ((now_bal - G_DAY_START_BALANCE) / G_DAY_START_BALANCE) * 100.0;

   if(gain_pct >= DailyGoodDayPercent)
   {
      detail = StringFormat("day already +%.1f%% - protecting it", gain_pct);
      return DailyGoodDayScoreOffset;
   }
   if(gain_pct <= -DailyBadDayPercent)
   {
      detail = StringFormat("day at %.1f%% - not trading back into it", gain_pct);
      return DailyBadDayScoreOffset;
   }
   return 0;
}

// --- rental spread -----------------------------------------------------------
// A deterministic per-account offset rather than a random one: every copy gets its
// own consistent delay instead of all of them re-rolling the same dice each tick.
int RentalEntryDelayTicks()
{
   if(!EnableRentalSpread || RentalSpreadMaxTicks <= 0)
      return 0;
   long acc = AccountInfoInteger(ACCOUNT_LOGIN);
   int offset = (int)(acc % (long)(RentalSpreadMaxTicks + 1));
   return offset;
}

// ============================================================================
// V194: SETUP ARMING - the third answer.
// ----------------------------------------------------------------------------
// Until now the EA had two responses to a warning: refuse the trade, or take it
// smaller. Both are blunt. A setup arriving into a strong opposing zone is not a
// bad setup and it is not a small-size setup - it is an EARLY one. The correct
// answer is neither "no" nor "yes, less", but "not yet".
//
// So the setup is ARMED instead of taken. The EA holds the direction and the
// reason, and then watches for the market to answer the specific objection:
//
//   Strong zone ahead    -> wait for price to reach the zone's reaction edge and
//                           show rejection there (a wick against, a close back).
//   Move overextended    -> wait for a pullback, then continuation.
//   Structure against    -> wait for price to reclaim the level it broke.
//
// If the confirmation arrives, the trade is taken at FULL size - because the
// objection has been answered, not merely tolerated. If it does not arrive within
// the window, the setup is dropped: a setup that never got its confirmation was
// never the trade it looked like.
//
// This is the difference between a bot that refuses and a bot that waits.
// ============================================================================

// (ARM_REASON_* defines live at the top of the file with the other structural defines)


// V199: a basket that just took profit is itself a confirmation - the EA read that direction
// correctly and the market paid for it. Requiring a fresh confirmation immediately afterwards
// treats the EA's own success as a reason for doubt, and on a scalper that is the most valuable
// moment there is: the move is live, the reading was right, and the next setup in the same
// direction arrives while both are still true.
int      G_LAST_WIN_DIR  = 0;      // direction of the last basket that closed in profit
int      G_LAST_WIN_BAR  = -100000;

void SetupArmClear()
{
   G_ARM_DIR = 0;
   G_ARM_REASON = ARM_REASON_NONE;
   G_ARM_BAR = 0;
   G_ARM_TRIGGER = 0.0;
   G_ARM_IS_WALL = false;
   G_ARM_SETUP_SCORE = 0.0;
   G_ARM_TEXT = "";
   G_ARM_SESSION = -1;
   G_ARM_START_SCORE = 0;
}

// Hold a setup that is right in direction but early in timing.
bool SetupArm(const int dir, const int reason_code, const double trigger_price, const string detail, const bool trigger_is_wall)
{
   // AUDIT FIX (B4): returns whether this direction is now held by an arm. The callers set WAIT only
   // then - a skipped arm (post-win, another side's objection) used to WAIT on nothing, for good.
   if(!EnableSetupArming || dir == 0)
      return false;

   // V199: do not hold a direction the market has just paid out on. A basket closing in profit is
   // the strongest confirmation available - stronger than a wick or a pullback, because it is the
   // reading having already been tested with money. Asking for another one within minutes means the
   // EA doubts itself precisely when it has been proven right, and the move it just rode is still
   // running while it waits.
   if(EnablePostWinFastEntry && G_LAST_WIN_DIR == dir &&
      (G_BARS_SEEN - G_LAST_WIN_BAR) <= PostWinFastEntryBars)
   {
      if((SetupArmPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v199 ARM] skipped - %s was confirmed by a winning basket %d bars ago",
                     (dir > 0 ? "BUY" : "SELL"), G_BARS_SEEN - G_LAST_WIN_BAR);
      return false;   // no wait - the setup goes straight to the score engine
   }

   // Do not re-arm the same thing every bar - the wait should be measured from when
   // the objection first appeared.
   if(G_ARM_DIR == dir && G_ARM_REASON == reason_code)
      return true;

   // V195: an existing wait is not replaced by a different objection. Without this the EA would
   // hold for a zone, then swap to waiting for a pullback, then to something else - each swap
   // resetting the clock, so it waits forever and never takes anything. The first objection raised
   // is the one that gets answered; if a second one is also true, it will still be true when the
   // first resolves.
   if(G_ARM_DIR != 0 && G_ARM_REASON != ARM_REASON_NONE)
   {
      int held = G_BARS_SEEN - G_ARM_BAR;
      if(held <= SetupArmMaxWaitBars)
         return (G_ARM_DIR == dir);      // still working through the current objection (this side's or not)
   }

   G_ARM_DIR = dir;
   G_ARM_REASON = reason_code;
   G_ARM_BAR = G_BARS_SEEN;
   G_ARM_TRIGGER = trigger_price;
   G_ARM_IS_WALL = trigger_is_wall;
   G_ARM_SETUP_SCORE = (double)G_SCORE_FINAL;
   G_ARM_TEXT = detail;
   G_ARM_START_SCORE = G_SCORE_FINAL;
   {
      int arm_mins = 0;
      string arm_sd = "";
      G_ARM_SESSION = EnableSessionContext ? SessionContext(arm_mins, arm_sd) : -1;
   }

   if((SetupArmPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v194 ARMED] %s held - %s (waiting for confirmation)",
                  (dir > 0 ? "BUY" : "SELL"), detail);
   return true;
}

// Has the market answered the objection? Returns true when the armed setup should
// now be taken.
bool SetupArmConfirmed(string &detail)
{
   detail = "";
   if(!EnableSetupArming || G_ARM_DIR == 0 || _Point <= 0.0)
      return false;

   int waited = G_BARS_SEEN - G_ARM_BAR;

   // V197: each objection resolves on its own timescale, so one window for all of them is either
   // too short for the slow ones or too generous for the fast. A spread narrows within a few bars;
   // a pullback on an overextended move takes considerably longer. Using a single figure meant
   // dropping valid pullback waits and holding dead spread waits.
   int window = SetupArmMaxWaitBars;
   switch(G_ARM_REASON)
   {
      case ARM_REASON_ZONE:      window = SetupArmZoneWaitBars;      break;
      case ARM_REASON_EXTENDED:  window = SetupArmPullbackWaitBars;  break;
      case ARM_REASON_STRUCTURE: window = SetupArmStructureWaitBars; break;
      // V275: a fill hold is short by design. The objection is a few points of price, not a
      // condition that has to resolve - and a setup held too long for a better entry becomes a
      // setup missed for a better entry.
      case ARM_REASON_FILL:      window = SetupArmFillWaitBars;      break;
      // V288: a pullback takes longer to arrive than a better tick does, and the setup behind it is
      // structural rather than momentary - it does not go stale in three bars.
      case ARM_REASON_LATE:      window = SetupArmLateWaitBars;      break;
   }
   window = MathMax(3, window);

   // The window closed. A setup that never got its confirmation was never the trade
   // it appeared to be.
   // V275: a fill hold ends differently from the others. The remaining reasons wait for something to
   // be PROVEN - a zone to reject, a pullback to finish - and when the window closes without proof
   // the setup was never confirmed, so dropping it is right. A fill hold is waiting for a better
   // price on a setup that was already confirmed, and a good setup at a mediocre price still beats
   // no trade. When this window closes, the trade is taken.
   // V288: a pullback hold that expires is a pullback that did not come, which means the move kept
   // going - and joining a move that kept going is a worse trade than the one that was declined, not
   // a better one. Unlike a fill hold, this one is dropped when its window closes.
   if(waited > window && G_ARM_REASON == ARM_REASON_LATE)
   {
      if((SetupArmPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v288 LATE] no pullback after %d bars - the move ran on without us", waited);
      ArmRecordOutcome(G_ARM_REASON, 0, waited);
      SetupArmClear();
      return false;
   }

   if(waited > window && G_ARM_REASON == ARM_REASON_FILL)
   {
      if((SetupArmPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v275 FILL] no better price after %d bars - taking the setup anyway", waited);
      ArmRecordOutcome(G_ARM_REASON, 1, waited);
      SetupArmClear();
      return true;
   }

   if(waited > window)
   {
      if((SetupArmPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v194 ARMED] dropped after %d/%d bars - no confirmation for %s",
                     waited, window, G_ARM_TEXT);
      ArmRecordOutcome(G_ARM_REASON, 0, waited);
      if(G_ARM_REASON == ARM_REASON_ZONE && G_ARM_IS_WALL)
      {
         G_ARM_ZONE_FAIL_BAR[(G_ARM_DIR > 0) ? 0 : 1] = G_BARS_SEEN;   // FIX(counter-zone-rearm-loop): the wait expired unanswered
      }
      SetupArmClear();
      return false;
   }

   // Give the market at least a bar to respond - confirming on the same bar the
   // objection appeared is not confirmation, it is noise.
   // V275: and it can end early. The others need a minimum wait because what they are waiting for
   // takes time to happen; a fill hold is waiting for a price, and if the price arrives on the next
   // tick there is nothing left to wait for.
   // V288: and it confirms the moment price reaches the retrace it was waiting for.
   if(G_ARM_REASON == ARM_REASON_LATE)
   {
      double la_px = (G_ARM_DIR > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool reached = (G_ARM_DIR > 0) ? (la_px <= G_ARM_TRIGGER) : (la_px >= G_ARM_TRIGGER);
      if(reached && la_px > 0.0)
      {
         if((SetupArmPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v288 LATE] pullback reached %.2f after %d bars", la_px, waited);
         ArmRecordOutcome(G_ARM_REASON, 1, waited);
         SetupArmClear();
         return true;
      }
      return false;
   }

   if(G_ARM_REASON == ARM_REASON_FILL)
   {
      double fw_better = 0.0;
      string fw_detail = "";
      double still_bad = FillQualityPenalty(G_ARM_DIR, fw_better, fw_detail);

      if(still_bad < FillTimingMinSeverity)
      {
         if((SetupArmPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v275 FILL] better price reached after %d bars", waited);
         ArmRecordOutcome(G_ARM_REASON, 1, waited);
         SetupArmClear();
         return true;
      }
      return false;
   }

   if(waited < MathMax(1, SetupArmMinWaitBars))
      return false;

   // V210: a recognised reversal pattern completes the wait on its own. This is the most direct
   // confirmation available - a morning star at the support a buy is armed against IS the turn the
   // wait was for, and waiting further for a wick to print is waiting for a weaker version of the
   // same evidence.
   if(CandlePatternConfirmsWait && EnableCandlePatterns)
   {
      int    pw_dir = 0;
      double pw_conf = 0.0;
      string pw_detail = "";
      int    pw_pat = CandlePatternRead(pw_dir, pw_conf, pw_detail);

      // Only reversal shapes confirm a wait - continuation shapes say the move is still running,
      // which is usually the objection rather than its answer.
      bool reversal = (pw_pat == CPAT_MORNING_STAR || pw_pat == CPAT_EVENING_STAR ||
                       pw_pat == CPAT_HARAMI       || pw_pat == CPAT_TWEEZER);

      // FIX(arm-wall-geometry): a wall objection is answered by price CLEARING the wall, never by
      // a reversal pattern forming while price still sits under it - that pattern is the objection
      // playing out, not its answer. Confirmation here would set skip_counter_zone and switch the
      // guard off, which is one of the doors the "opens into the wall" symptom came through.
      if(!G_ARM_IS_WALL && reversal && pw_dir == G_ARM_DIR && pw_conf >= CandlePatternWaitMinConf)
      {
         detail = pw_detail;
         return true;
      }
   }

   // V196: the independent reading, checked before the price test. Pressure, chain and history read
   // the market's intent directly and arrive earlier than price does - a wick is the market
   // announcing a turn that these three can see beginning. Two agreeing completes the wait; all
   // three disagreeing ends it, because a setup the market has turned away from will not be
   // rescued by waiting out the rest of its window.
   string cons_detail = "";
   int cons = SetupArmConsensus(cons_detail);
   // FIX(arm-wall-geometry): same reasoning - directional agreement is not evidence that a wall
   // overhead has been dealt with. The NEGATIVE branch below stays unconditional: dropping a
   // setup the market has turned away from is safe in either geometry.
   if(cons > 0 && !G_ARM_IS_WALL)
   {
      detail = cons_detail;
      return true;
   }
   if(cons < 0)
   {
      if((SetupArmPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v196 ARMED] dropped early - %s", cons_detail);
      ArmRecordOutcome(G_ARM_REASON, -1, G_BARS_SEEN - G_ARM_BAR);
      SetupArmClear();
      return false;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return false;

   // V197: is the setup still there to be taken? Waiting was never the goal - it was a way to get
   // the same trade at a better moment. Three things end that trade while the EA is still holding
   // it, and until now none of them were checked: price walking away from the level the setup was
   // built on, the session handing over to different participants, and the market simply moving on.
   if(EnableArmValidityCheck)
   {
      double moved_pts = MathAbs(mid - G_ARM_TRIGGER) / _Point;

      // Price has left the area. The zone or level this was waiting for is no longer where the
      // market is trading, so the reaction it was waiting for cannot happen there.
      if(ArmAbandonDistancePoints > 0 && moved_pts > (double)ArmAbandonDistancePoints)
      {
         if((SetupArmPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v197 ARMED] abandoned - price is %.0f pts from the level (limit %d)",
                        moved_pts, ArmAbandonDistancePoints);
         ArmRecordOutcome(G_ARM_REASON, -1, G_BARS_SEEN - G_ARM_BAR);
         SetupArmClear();
         return false;
      }

      // The session changed hands. The participants who would have produced the expected reaction
      // are not the ones in the market now, so the reasoning behind the wait no longer applies.
      if(ArmAbandonOnSessionChange && EnableSessionContext)
      {
         int sc_mins = 0;
         string sc_detail = "";
         int sess_now = SessionContext(sc_mins, sc_detail);
         if(G_ARM_SESSION >= 0 && sess_now != G_ARM_SESSION)
         {
            if((SetupArmPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v197 ARMED] abandoned - session changed to %s while waiting",
                           SessionName(sess_now));
            ArmRecordOutcome(G_ARM_REASON, -1, G_BARS_SEEN - G_ARM_BAR);
            SetupArmClear();
            return false;
         }
      }
   }

   double o = CandleOpen(SignalTF, 1);
   double c = CandleClose(SignalTF, 1);
   double h = CandleHigh(SignalTF, 1);
   double l = CandleLow(SignalTF, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;
   double range = h - l;
   if(range <= 0.0)
      return false;

   switch(G_ARM_REASON)
   {
      case ARM_REASON_ZONE:
      {
         // FIX(arm-wall-geometry): this branch serves THREE arm sites with TWO opposite geometries,
         // and only one of them was implemented.
         //   - Zone-edge / liquidity arms (G_ARM_IS_WALL == false): the trigger is a level the
         //     trade WANTS price to dip into and bounce from. The logic below is correct for those.
         //   - Counter-zone arms (G_ARM_IS_WALL == true): the trigger is the opposing WALL - the
         //     resistance ABOVE a buy, the support BELOW a sell. There, `reached` evaluated
         //     `l <= trigger` for a buy, and the M1 low is ALWAYS below a resistance sitting above
         //     price, so it was trivially true on every bar. The wick test then looked at the LOWER
         //     wick and wanted a BULLISH close - i.e. any ordinary bullish candle with a 35% lower
         //     wick "confirmed" that a wall overhead had been dealt with. Confirmation adds a score
         //     bonus AND sets skip_counter_zone, which switches the block off for that pass. So the
         //     one hard guard against entering a wall detected the wall, waited a bar, accepted an
         //     unrelated candle as proof, and then disarmed itself. This is the mechanism behind
         //     "SELL opened at support / BUY opened at resistance".
         // A wall is answered by price CLEARING it, never by a rejection off it - a rejection there
         // is evidence the objection was RIGHT, so the setup is dropped instead.
         if(G_ARM_IS_WALL)
         {
            double wall_buf = ScaleAdjustedPoints(MathMax(1, SetupArmWallClearPoints)) * _Point;
            // The zone lookups can return a level slightly the WRONG side of price (the
            // ZoneNearAboveTolerance leniency on both scans). If the trigger is already behind us
            // the "cleared" test is satisfied on the very next close and the guard switches itself
            // off without the real wall ever being examined. Treat that as a bad arm and drop it.
            bool still_ahead = (G_ARM_DIR > 0) ? (G_ARM_TRIGGER > c) : (G_ARM_TRIGGER < c);
            bool cleared = still_ahead
                           ? false
                           : ((G_ARM_DIR > 0) ? (c > G_ARM_TRIGGER + wall_buf)
                                              : (c < G_ARM_TRIGGER - wall_buf));
            if(cleared)
            {
               detail = StringFormat("cleared the wall at %.2f", G_ARM_TRIGGER);
               return true;
            }

            bool turned_back = (G_ARM_DIR > 0) ? (h >= G_ARM_TRIGGER && c < o)
                                               : (l <= G_ARM_TRIGGER && c > o);
            if(turned_back)
            {
               // The wall did exactly what the objection said it would. Stop waiting for it.
               if((SetupArmPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v194 ARMED] dropped - the wall at %.2f rejected price, objection confirmed",
                              G_ARM_TRIGGER);
               ArmRecordOutcome(G_ARM_REASON, 0, G_BARS_SEEN - G_ARM_BAR);
               G_ARM_ZONE_FAIL_BAR[(G_ARM_DIR > 0) ? 0 : 1] = G_BARS_SEEN;   // FIX(counter-zone-rearm-loop)
               SetupArmClear();
            }
            return false;
         }

         // The objection was a zone in the way. The answer is price reaching it and
         // being turned away: a wick into the level with the close back on our side.
         bool reached = (G_ARM_DIR > 0) ? (l <= G_ARM_TRIGGER) : (h >= G_ARM_TRIGGER);
         if(!reached)
            return false;

         double wick = (G_ARM_DIR > 0) ? (MathMin(o, c) - l) : (h - MathMax(o, c));
         double wick_ratio = wick / range;
         bool closed_our_way = (G_ARM_DIR > 0) ? (c > o) : (c < o);

         if(wick_ratio >= SetupArmRejectionWickRatio && closed_our_way)
         {
            detail = StringFormat("zone rejected price (%.0f%% wick, closed %s)",
                                  wick_ratio * 100.0, (G_ARM_DIR > 0 ? "up" : "down"));
            return true;
         }
         return false;
      }

      case ARM_REASON_EXTENDED:
      {
         // The objection was an overextended move. The answer is a pullback of real
         // depth followed by the move resuming in our direction.
         double pulled = (G_ARM_DIR > 0) ? (G_ARM_TRIGGER - l) / _Point
                                         : (h - G_ARM_TRIGGER) / _Point;
         if(pulled < (double)SetupArmPullbackPoints)
            return false;

         bool resumed = (G_ARM_DIR > 0) ? (c > o) : (c < o);
         if(resumed)
         {
            detail = StringFormat("pulled back %.0f pts and resumed", pulled);
            return true;
         }
         return false;
      }

      case ARM_REASON_STRUCTURE:
      {
         // The objection was structure pointing the other way. The answer is price
         // reclaiming the level that defined it.
         bool reclaimed = (G_ARM_DIR > 0) ? (c > G_ARM_TRIGGER) : (c < G_ARM_TRIGGER);
         if(reclaimed)
         {
            detail = StringFormat("reclaimed %.2f", G_ARM_TRIGGER);
            return true;
         }
         return false;
      }
   }

   return false;
}

// V197: does waiting actually work? The EA now holds setups in five different situations and
// confirms them by two different routes, and none of it is measured. Without that, the next round
// of tuning is guesswork again - exactly what produced a day of blind adjustments.
//
// Each armed setup is recorded by objection type and by how it ended: confirmed and traded,
// abandoned early, or expired unconfirmed. Confirmed ones are then graded on what price did
// afterwards, which is the only question that matters - waiting is only worth its cost if the
// trades that come out of it are better than the ones that would have been taken immediately.
// (ARM_OUTCOME_SLOTS declared at the top of the file with the other structural defines)

double G_ARM_CONFIRMED[ARM_OUTCOME_SLOTS];   // waits that produced a trade
double G_ARM_EXPIRED[ARM_OUTCOME_SLOTS];     // waits that timed out
double G_ARM_ABANDONED[ARM_OUTCOME_SLOTS];   // waits cancelled early
double G_ARM_WON[ARM_OUTCOME_SLOTS];         // of the confirmed ones, how many went our way
double G_ARM_WAIT_SUM[ARM_OUTCOME_SLOTS];    // total bars waited, for the average

// Pending grade: a confirmed wait is judged some bars later, not immediately.
int    G_ARM_JUDGE_REASON = 0;
int    G_ARM_JUDGE_BAR    = 0;
int    G_ARM_JUDGE_DIR    = 0;
double G_ARM_JUDGE_PRICE  = 0.0;

string ArmReasonName(const int r)
{
   switch(r)
   {
      case ARM_REASON_ZONE:      return "zone";
      case ARM_REASON_EXTENDED:  return "pullback";
      case ARM_REASON_STRUCTURE: return "reclaim";
      case ARM_REASON_FILL:      return "better fill";
      case ARM_REASON_LATE:      return "waiting for the pullback";
   }
   return "?";
}

void ArmRecordOutcome(const int reason_code, const int outcome, const int bars_waited)
{
   if(!EnableArmAudit || reason_code <= 0 || reason_code >= ARM_OUTCOME_SLOTS)
      return;
   if(outcome > 0)      G_ARM_CONFIRMED[reason_code] += 1.0;
   else if(outcome < 0) G_ARM_ABANDONED[reason_code] += 1.0;
   else                 G_ARM_EXPIRED[reason_code]   += 1.0;
   G_ARM_WAIT_SUM[reason_code] += (double)bars_waited;
}

// A confirmed wait is armed for judgement here, and graded once the horizon passes.
void ArmJudgeArm(const int reason_code, const int dir, const double price)
{
   if(!EnableArmAudit || dir == 0 || price <= 0.0)
      return;
   G_ARM_JUDGE_REASON = reason_code;
   G_ARM_JUDGE_DIR    = dir;
   G_ARM_JUDGE_PRICE  = price;
   G_ARM_JUDGE_BAR    = G_BARS_SEEN;
}

void ArmJudgeSettle()
{
   if(!EnableArmAudit || G_ARM_JUDGE_DIR == 0 || _Point <= 0.0)
      return;
   if((G_BARS_SEEN - G_ARM_JUDGE_BAR) < MathMax(3, ArmAuditHorizonBars))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double moved = (mid - G_ARM_JUDGE_PRICE) / _Point * (double)G_ARM_JUDGE_DIR;
   int r = G_ARM_JUDGE_REASON;
   if(r > 0 && r < ARM_OUTCOME_SLOTS && moved >= (double)ArmAuditWinPoints)
      G_ARM_WON[r] += 1.0;

   if((ArmAuditPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v197 ARM AUDIT] %s wait -> price went %.0f pts after entry",
                  ArmReasonName(r), moved);

   G_ARM_JUDGE_DIR = 0;
}

string ArmAuditText()
{
   if(!EnableArmAudit)
      return "";
   string out = "";
   for(int r = 1; r < ARM_OUTCOME_SLOTS; r++)
   {
      double total = G_ARM_CONFIRMED[r] + G_ARM_EXPIRED[r] + G_ARM_ABANDONED[r];
      if(total < 1.0)
         continue;
      double took = (G_ARM_CONFIRMED[r] / total) * 100.0;
      double wr = (G_ARM_CONFIRMED[r] > 0.0) ? (G_ARM_WON[r] / G_ARM_CONFIRMED[r]) * 100.0 : -1.0;
      double avg_wait = G_ARM_WAIT_SUM[r] / total;
      if(wr >= 0.0)
         out += StringFormat("%s %.0f%%took/%.0f%%won(%.0f) ", ArmReasonName(r), took, wr, total);
      else
         out += StringFormat("%s %.0f%%took(%.0f) ", ArmReasonName(r), took, total);
   }
   if(StringLen(out) == 0)
      return "";
   return "waits: " + out;
}

// V196: independent confirmation. Waiting for price alone is one opinion, and a slow one - price
// reaching a level says the market got there, not that it turned. Three modules already read the
// market's intent directly and none of them was allowed to speak to the wait:
//
//   Pressure divergence - control shifting our way while price still disagrees. This is the
//                         EARLIEST reading available and it fires before price confirms anything.
//   Chain expectation   - the recorded sequence of events says a turn is what usually follows.
//   Pattern memory      - the closest historical matches to this shape resolved our way.
//
// Two of the three agreeing is treated as confirmation in its own right. It does not replace the
// price test - either route can complete the wait - but it means a setup that the market has
// already turned toward is not held until a wick happens to print.
//
// The reverse matters equally: when all three point AGAINST the armed direction, the setup is
// dropped early rather than waiting out its full window for a confirmation that is not coming.
int SetupArmConsensus(string &detail)
{
   detail = "";
   if(!EnableArmConsensus || G_ARM_DIR == 0)
      return 0;

   int agree = 0, against = 0;
   string parts = "";

   // 1. Pressure - who is winning the bars right now, and is that shifting our way?
   if(EnablePressureReading)
   {
      double pr_trend = 0.0;
      bool   pr_div = false;
      string pr_detail = "";
      double pr = DominantSidePressure(pr_trend, pr_div, pr_detail);
      if(MathAbs(pr) >= PressureMinToAct)
      {
         int pr_dir = (pr > 0.0) ? 1 : -1;
         if(pr_dir == G_ARM_DIR) { agree++; parts += "pressure "; }
         else                    { against++; }
      }
   }

   // 2. Chain - does the recorded sequence expect a move our way?
   if(EnableChainExpectation)
   {
      double ch_conf = 0.0;
      string ch_detail = "";
      int    ch_pattern = 0;
      int    ch_dir = ChainExpectation(ch_conf, ch_detail, ch_pattern);
      if(ch_dir != 0 && ch_conf >= ChainExpectMinConfidence)
      {
         if(ch_dir == G_ARM_DIR) { agree++; parts += "chain "; }
         else                    { against++; }
      }
   }

   // 3. Pattern memory - how did the closest historical shapes resolve?
   if(EnablePatternMemory)
   {
      int    pm_samples = 0;
      double pm_quality = 0.0;
      string pm_detail = "";
      double pm_bias = PatternMemoryBias(pm_samples, pm_quality, pm_detail);
      if(MathAbs(pm_bias) >= PatternMemoryMinBias && pm_samples >= PatternMemoryMinSamples)
      {
         int pm_dir = (pm_bias > 0.0) ? 1 : -1;
         if(pm_dir == G_ARM_DIR) { agree++; parts += "history "; }
         else                    { against++; }
      }
   }

   if(agree >= ArmConsensusMinAgree)
   {
      detail = StringFormat("%d sources agree (%s)", agree, parts);
      return 1;
   }
   if(against >= ArmConsensusMinAgainst)
   {
      detail = StringFormat("%d sources now point the other way", against);
      return -1;
   }
   return 0;
}

string SetupArmText()
{
   if(!EnableSetupArming || G_ARM_DIR == 0)
      return "";
   int waited = G_BARS_SEEN - G_ARM_BAR;
   return StringFormat("armed: %s waiting %d/%d bars - %s",
                       (G_ARM_DIR > 0 ? "BUY" : "SELL"), waited, SetupArmMaxWaitBars, G_ARM_TEXT);
}

// ============================================================================
// V167: ZONE EDGES - a level is a region, and its two sides behave differently.
// ----------------------------------------------------------------------------
// Everything here treats a zone as one price. On a chart it is a region, and where
// inside that region price reacts is not arbitrary.
//
// The OUTER edge is the extreme - the furthest price that has traded there. It is
// where stops sit and where a wick reaches on a sweep.
// The INNER edge is where the orders actually rest - the density, the price the
// zone has been defended from repeatedly.
//
// Price routinely trades through the outer edge and turns at the inner one. That
// gap is often a dollar or more on XAUUSD, which on a $2.50 target is the
// difference between a scalp that works and one that does not:
//
//   Entering at the outer edge  - fills early, then watches price continue to the
//                                 inner edge before turning. Immediate drawdown.
//   Entering at the inner edge  - fills where the reaction actually starts.
//
// The two edges also answer different questions. Room and risk should measure to
// the OUTER edge, because price can reach it. Entries and grid placement should aim
// at the INNER edge, because that is where the turn happens.
bool ZoneEdgePrices(const double level, const bool is_support,
                    double &outer_edge, double &inner_edge, string &detail)
{
   outer_edge = level;
   inner_edge = level;
   detail = "";

   if(!EnableZoneEdges || level <= 0.0 || _Point <= 0.0)
      return false;

   // V179: small per-bar cache keyed on the level. The score engine, the dashboard and the entry
   // check each ask about the same zone on the same tick, and this walks the swing cache and sorts
   // every time.
   static int    ze_bar = -100000;
   static double ze_lvl[6], ze_out[6], ze_in[6];
   static bool   ze_ok[6];
   static string ze_det[6];
   static int    ze_n = 0;
   if(ze_bar > G_BARS_SEEN) ze_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(ze_bar != G_BARS_SEEN) { ze_bar = G_BARS_SEEN; ze_n = 0; }
   for(int zc = 0; zc < ze_n; zc++)
   {
      if(MathAbs(ze_lvl[zc] - level) < _Point)
      {
         outer_edge = ze_out[zc];
         inner_edge = ze_in[zc];
         detail     = ze_det[zc];
         return ze_ok[zc];
      }
   }

   ZoneMapRefreshSwingCache();

   int t = ZMTFIndex(ZoneEdgeTF);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT)
      return false;

   double tol = ScaleAdjustedPoints(MathMax(1, ZoneEdgeGatherPoints)) * _Point;

   // Collect the swings that make up this zone.
   double members[40];
   int n = 0;

   if(is_support)
   {
      for(int k = 0; k < G_ZMC_LOW_COUNT[t] && n < 40; k++)
      {
         double v = G_ZMC_LOW_PRICE[t][k];
         if(v > 0.0 && MathAbs(v - level) <= tol)
            members[n++] = v;
      }
   }
   else
   {
      for(int k = 0; k < G_ZMC_HIGH_COUNT[t] && n < 40; k++)
      {
         double v = G_ZMC_HIGH_PRICE[t][k];
         if(v > 0.0 && MathAbs(v - level) <= tol)
            members[n++] = v;
      }
   }

   if(n < MathMax(2, ZoneEdgeMinSwings))
   {
      if(ze_n < 6)
      {
         ze_lvl[ze_n] = level; ze_out[ze_n] = outer_edge; ze_in[ze_n] = inner_edge;
         ze_ok[ze_n] = false;  ze_det[ze_n] = ""; ze_n++;
      }
      return false;
   }

   double sorted[];
   ArrayResize(sorted, n);
   for(int c = 0; c < n; c++)
      sorted[c] = members[c];
   ArraySort(sorted);

   // Outer edge: the extreme the zone has reached. For support that is the lowest
   // low; for resistance the highest high - the side price can still wick into.
   outer_edge = is_support ? sorted[0] : sorted[n - 1];

   // Inner edge: where the swings actually cluster. The median is the honest answer -
   // it is the price the zone has been defended from most often, and unlike the mean
   // a single deep wick does not drag it outward.
   inner_edge = (n % 2 == 1) ? sorted[n / 2]
                             : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;

   double gap_pts = MathAbs(outer_edge - inner_edge) / _Point;

   detail = StringFormat("%s zone: reacts at %.2f, reaches %.2f (%.0f pts apart, %d swings)",
                         (is_support ? "support" : "resistance"),
                         inner_edge, outer_edge, gap_pts, n);
   bool ze_result = (gap_pts >= (double)ZoneEdgeMinGapPoints);
   if(ze_n < 6)
   {
      ze_lvl[ze_n] = level; ze_out[ze_n] = outer_edge; ze_in[ze_n] = inner_edge;
      ze_ok[ze_n] = ze_result; ze_det[ze_n] = detail; ze_n++;
   }
   return ze_result;
}

// The price an entry leaning on this zone should actually be aiming at.
double ZoneReactionPrice(const double level, const bool is_support)
{
   double outer = level, inner = level;
   string detail = "";
   if(ZoneEdgePrices(level, is_support, outer, inner, detail))
      return inner;
   return level;
}

// The price risk should be measured to - price can reach the extreme.
double ZoneRiskPrice(const double level, const bool is_support)
{
   double outer = level, inner = level;
   string detail = "";
   if(ZoneEdgePrices(level, is_support, outer, inner, detail))
      return outer;
   return level;
}

// ============================================================================

// --- carry cost --------------------------------------------------------------
// Swap and commission already paid by the open basket, in points of the current
// position size - so it can be compared directly against a target.
double BasketCarryCostPoints()
{
   if(!EnableCarryCostAdjust || _Point <= 0.0 || G_BASKET_ORDERS <= 0)
      return 0.0;

   double swap_money = 0.0;
   double total_vol = 0.0;
   int total_pos = PositionsTotal();

   for(int i = total_pos - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      swap_money += PositionGetDouble(POSITION_SWAP);
      total_vol  += PositionGetDouble(POSITION_VOLUME);
   }

   if(total_vol <= 0.0 || swap_money >= 0.0)
      return 0.0;                          // positive or zero swap costs us nothing

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;
   double value_per_point = tick_value * (_Point / tick_size);
   if(value_per_point <= 0.0)
      return 0.0;

   // How many points the basket must travel simply to repay what it has already spent.
   return MathAbs(swap_money) / (value_per_point * total_vol);
}

// --- loss streak -------------------------------------------------------------
int    G_LOSS_STREAK = 0;      // consecutive losing baskets
int    G_WIN_STREAK  = 0;

void StreakRecordOutcome(const bool won)
{
   if(won) { G_WIN_STREAK++;  G_LOSS_STREAK = 0; }
   else    { G_LOSS_STREAK++; G_WIN_STREAK  = 0; }

   if((StreakPrintOnUse && VerboseLogs) && G_LOSS_STREAK >= StreakCautionLosses)
      PrintFormat("[SIRUS v166 STREAK] %d consecutive losses - the market may have moved into a state this system does not handle",
                  G_LOSS_STREAK);
}

// Score penalty from the current streak. Deliberately gradual: this is a hint that
// conditions have changed, not a verdict.
int StreakPenalty()
{
   if(!EnableStreakAwareness || G_LOSS_STREAK < StreakCautionLosses)
      return 0;
   int over = G_LOSS_STREAK - StreakCautionLosses + 1;
   return MathMin(StreakMaxPenalty, over * StreakPenaltyPerLoss);
}

// --- repeated mistakes at the same level --------------------------------------
double G_LAST_LOSS_LEVEL[3];   // levels the last few losing baskets opened near
int    G_LOSS_LEVEL_COUNT = 0;

void RecordLossLevel(const double level)
{
   if(!EnableRepeatMistakeGuard || level <= 0.0)
      return;
   // Shift the ring so index 0 is the most recent.
   G_LAST_LOSS_LEVEL[2] = G_LAST_LOSS_LEVEL[1];
   G_LAST_LOSS_LEVEL[1] = G_LAST_LOSS_LEVEL[0];
   G_LAST_LOSS_LEVEL[0] = level;
   if(G_LOSS_LEVEL_COUNT < 3)
      G_LOSS_LEVEL_COUNT++;
}

// Have recent baskets already lost around this price?
int RepeatedLossesNear(const double price, string &detail)
{
   detail = "";
   if(!EnableRepeatMistakeGuard || price <= 0.0 || _Point <= 0.0 || G_LOSS_LEVEL_COUNT <= 0)
      return 0;

   // V170f: "the same place" is a structural distance - in a wider-swinging market two entries
   // $2.50 apart are neighbours; in a tight one they are unrelated.
   double tol = ScaleAdjustedPoints(MathMax(1, RepeatMistakePoints)) * _Point;
   int hits = 0;
   for(int i = 0; i < G_LOSS_LEVEL_COUNT && i < 3; i++)
   {
      if(G_LAST_LOSS_LEVEL[i] <= 0.0)
         continue;
      if(MathAbs(price - G_LAST_LOSS_LEVEL[i]) <= tol)
         hits++;
   }

   if(hits >= MathMax(2, RepeatMistakeMinHits))
      detail = StringFormat("%d of the last %d losing baskets opened within %.0f pts of here",
                            hits, G_LOSS_LEVEL_COUNT, (double)RepeatMistakePoints);
   return hits;
}

// ============================================================================
double SpreadCostRatio(string &detail)
{
   detail = "";
   if(!EnableSpreadEconomics || _Point <= 0.0)
      return 0.0;

   double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_pts <= 0.0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask > 0.0 && bid > 0.0)
         spread_pts = (ask - bid) / _Point;
   }
   if(spread_pts <= 0.0)
      return 0.0;

   double target = BaseBasketTPPoints();
   if(target <= 0.0)
      return 0.0;

   double ratio = spread_pts / target;

   // Round-trip: the spread is paid on the way in, and the exit gives up its half
   // again on most fills.
   if(SpreadCountRoundTrip)
      ratio *= 1.5;

   detail = StringFormat("cost %.0f%% of target (spread %.0f pts vs %.0f)",
                         ratio * 100.0, spread_pts, target);
   return ratio;
}

// Is spread likely to widen shortly? Widening is scheduled, not random - knowing it
// is coming is worth more than measuring it after it arrives.
bool SpreadWideningExpected(string &why)
{
   why = "";
   if(!EnableSpreadEconomics || !EnableSpreadForecast)
      return false;

   int    sc_mins = 999;
   string sc_detail = "";
   int    sess = SessionContext(sc_mins, sc_detail);

   // Rollover is the reliable one - spreads widen every day, at the same time.
   if(sess == SESSION_DEAD)
   {
      why = "rollover - spreads widen every day at this hour";
      return true;
   }

   // Approaching rollover: entering a scalp minutes before the spread triples means
   // the exit is priced under conditions the entry never accounted for.
   if(sc_mins <= SpreadForecastWarnMinutes)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int now_m = dt.hour * 60 + dt.min;
      int roll_at = MathMax(0, MathMin(23, SessionRolloverHour)) * 60;
      int to_roll = roll_at - now_m;
      if(to_roll < 0) to_roll += 1440;
      if(to_roll <= SpreadForecastWarnMinutes)
      {
         why = StringFormat("%d min to rollover - the exit will be priced at a wider spread than the entry", to_roll);
         return true;
      }
   }

   // Thin hours: a spread already elevated in a quiet session tends to stay that way.
   if(sess == SESSION_ASIA)
   {
      double cur = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(cur > 0.0 && cur >= (double)SpreadForecastThinSessionPoints)
      {
         why = StringFormat("thin session with spread already at %.0f pts", cur);
         return true;
      }
   }

   return false;
}

// ============================================================================

// (SESSION_* defines live at the top of the file with the other structural defines)

string SessionName(const int sess)
{
   switch(sess)
   {
      case SESSION_DEAD:    return "ROLLOVER";
      case SESSION_ASIA:    return "ASIA";
      case SESSION_LONDON:  return "LONDON";
      case SESSION_OVERLAP: return "OVERLAP";
      case SESSION_NY:      return "NEW YORK";
   }
   return "?";
}

// Current session, plus minutes until the next session change.
int SessionContext(int &minutes_to_change, string &detail)
{
   minutes_to_change = 999;
   detail = "";

   if(!EnableSessionContext)
      return SESSION_ASIA;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   int mins = dt.min;
   int now_m = hour * 60 + mins;

   int asia_start    = MathMax(0, MathMin(23, SessionAsiaStartHour))    * 60;
   int london_start  = MathMax(0, MathMin(23, SessionLondonStartHour))  * 60;
   int ny_start      = MathMax(0, MathMin(23, SessionNYStartHour))      * 60;
   int london_end    = MathMax(0, MathMin(23, SessionLondonEndHour))    * 60;
   int ny_end        = MathMax(0, MathMin(23, SessionNYEndHour))        * 60;
   int rollover_at   = MathMax(0, MathMin(23, SessionRolloverHour))     * 60;

   int sess = SESSION_ASIA;

   // Rollover window straddles the day boundary, so it is checked first.
   int roll_half = MathMax(5, SessionRolloverMinutes) / 2;
   int roll_dist = MathAbs(now_m - rollover_at);
   if(roll_dist > 720) roll_dist = 1440 - roll_dist;      // wrap around midnight
   if(roll_dist <= roll_half)
      sess = SESSION_DEAD;
   else if(now_m >= ny_start && now_m < london_end)
      sess = SESSION_OVERLAP;
   else if(now_m >= london_start && now_m < ny_start)
      sess = SESSION_LONDON;
   else if(now_m >= london_end && now_m < ny_end)
      sess = SESSION_NY;
   else
      sess = SESSION_ASIA;

   // Minutes until the next boundary of any kind.
   int marks[6];
   marks[0] = asia_start; marks[1] = london_start; marks[2] = ny_start;
   marks[3] = london_end; marks[4] = ny_end;       marks[5] = rollover_at;

   int best = 1441;
   for(int k = 0; k < 6; k++)
   {
      int d = marks[k] - now_m;
      if(d < 0) d += 1440;
      if(d < best) best = d;
   }
   minutes_to_change = best;

   detail = StringFormat("session: %s, %d min to next change", SessionName(sess), minutes_to_change);
   return sess;
}

// Target multiplier by session - what the market will actually deliver differs by
// hours of the day far more than by anything a signal can measure.
double SessionTPFactor(const int sess)
{
   if(!EnableSessionContext)
      return 1.0;
   switch(sess)
   {
      case SESSION_DEAD:    return SessionDeadTPFactor;
      case SESSION_ASIA:    return SessionAsiaTPFactor;
      case SESSION_LONDON:  return SessionLondonTPFactor;
      case SESSION_OVERLAP: return SessionOverlapTPFactor;
      case SESSION_NY:      return SessionNYTPFactor;
   }
   return 1.0;
}

// ============================================================================
double DominantSidePressure(double &trend, bool &divergence, string &detail)
{
   trend = 0.0;
   divergence = false;
   detail = "";

   if(!EnablePressureReading || _Point <= 0.0)
      return 0.0;

   static int    dp_bar = -100000;
   static double dp_val = 0.0;
   static double dp_trend = 0.0;
   static bool   dp_div = false;
   static string dp_detail = "";
   if(dp_bar > G_BARS_SEEN) dp_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(dp_bar == G_BARS_SEEN)
   {
      trend = dp_trend; divergence = dp_div; detail = dp_detail;
      return dp_val;
   }

   ENUM_TIMEFRAMES tf = PressureTF;
   int look = MathMax(6, PressureLookbackBars);

   double per_bar[40];
   int n = 0;

   for(int i = look; i >= 1 && n < 40; i--)
   {
      double o = CandleOpen(tf, i);
      double c = CandleClose(tf, i);
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;

      double range = h - l;
      if(range <= 0.0)
         continue;

      // Where in its own range did the bar close? This is the cleanest single
      // statement of who held control: 1 = buyers took it outright, -1 = sellers did.
      double close_pos = ((c - l) / range) * 2.0 - 1.0;

      // Body share separates a decisive bar from an indecisive one - a bar closing
      // at its high on a tiny body was not really won by anyone.
      double body_share = MathAbs(c - o) / range;

      per_bar[n++] = close_pos * (PressureBodyWeight + (1.0 - PressureBodyWeight) * body_share);
   }

   if(n < MathMax(4, PressureMinBars))
      return 0.0;

   // Recent bars matter more - control changes hands, and the latest holder is the
   // one that counts.
   double weighted = 0.0, wsum = 0.0;
   for(int k = 0; k < n; k++)
   {
      double w = 1.0 + (double)k * MathMax(0.0, PressureRecencyWeight);
      weighted += per_bar[k] * w;
      wsum += w;
   }
   double pressure = (wsum > 0.0) ? (weighted / wsum) : 0.0;

   // Is control strengthening or slipping? Compare the recent half against the older.
   int half = n / 2;
   double early = 0.0, recent = 0.0;
   for(int a = 0; a < half; a++)       early  += per_bar[a];
   for(int b = n - half; b < n; b++)   recent += per_bar[b];
   if(half > 0)
   {
      early  /= (double)half;
      recent /= (double)half;
      trend = recent - early;          // positive = shifting toward buyers
   }

   // Divergence: price going one way while control moves the other. This is the
   // reading that arrives early.
   double c_now = CandleClose(tf, 1);
   double c_old = CandleClose(tf, look);
   int price_dir = 0;
   if(c_now > 0.0 && c_old > 0.0)
   {
      double moved = (c_now - c_old) / _Point;
      if(MathAbs(moved) >= PressureMinPriceMove)
         price_dir = (moved > 0.0) ? 1 : -1;
   }

   if(price_dir != 0 && MathAbs(trend) >= PressureMinTrend)
   {
      int trend_dir = (trend > 0.0) ? 1 : -1;
      divergence = (trend_dir != price_dir);
   }

   detail = StringFormat("pressure %+.2f (%s), control %s%s",
                         pressure,
                         (pressure > 0 ? "buyers" : (pressure < 0 ? "sellers" : "even")),
                         (trend > 0 ? "shifting to buyers" : (trend < 0 ? "shifting to sellers" : "steady")),
                         (divergence ? " - DIVERGING from price" : ""));

   dp_bar = G_BARS_SEEN;
   dp_val = pressure;
   dp_trend = trend;
   dp_div = divergence;
   dp_detail = detail;
   return pressure;
}
