//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 05_Situation_Candles                            |
//| Grid addition quality, situations, candle reading, sweeps        |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// ============================================================================
// V222: THE SIZE OF AN ADDITION SHOULD MATCH ITS QUALITY
// ----------------------------------------------------------------------------
// The ladder multiplies by 1.30 regardless of where the addition lands, which means
// the largest commitment of the entire basket - order seven, over four times the
// starting size - goes in at the deepest point of the drawdown, at whatever price
// the arithmetic produced, with no reading of whether that price is worth defending.
//
// That is the martingale premise and it is not wrong: size has to grow or the
// recovery does not work. But "grow" and "grow blindly" are different, and the EA
// already knows things about each addition that it never uses:
//
//   Is there a level here, or is this open space?
//   Has the direction held up since the basket opened?
//   How deep is the basket already, relative to what it can survive?
//
// An addition at a strong support with the direction intact deserves its full
// multiple. The same addition in open space with the swings turning deserves less -
// not because the recovery matters less, but because committing the largest size to
// the worst location is how a recoverable basket becomes an unrecoverable one.
// ============================================================================

// How good is this addition? Returns a multiplier on the intended lot.
double GridAdditionQuality(const int basket_dir, const double add_price, string &detail)
{
   detail = "";
   if(!EnableGridQualityLot || basket_dir == 0 || add_price <= 0.0 || _Point <= 0.0)
      return 1.0;

   double quality = 0.5;              // neutral starting point
   string parts = "";

   // 1. Is there a level at this price? An addition against something is defensible;
   //    one in open space is a bet that price will turn for no visible reason.
   double level = (basket_dir > 0) ? ZoneMapNearestSupport(add_price + (10.0 * _Point))
                                   : ZoneMapNearestResistance(add_price - (10.0 * _Point));
   if(level > 0.0)
   {
      double dist = MathAbs(add_price - level) / _Point;
      double tol = ScaleAdjustedPoints(MathMax(1, GridQualityLevelTolerance));
      if(dist <= tol)
      {
         double strength = ZoneMapStrengthByTouches(level);
         double str_f = MathMin(1.0, strength / MathMax(0.1, GridQualityFullStrength));
         quality += GridQualityLevelWeight * str_f;
         parts += StringFormat("level %.2f; ", level);
      }
   }

   // 2. Has the direction held up? This reuses the doubt reading rather than
   //    recomputing it, so the two cannot disagree.
   if(EnableGridDirectionCheck)
   {
      string gd_detail = "";
      double doubt = GridDirectionDoubt(basket_dir, gd_detail);
      quality -= GridQualityDoubtWeight * doubt;
      if(doubt > 0.1)
         parts += StringFormat("doubt %.0f%%; ", doubt * 100.0);
   }

   // 3c. V240: is this addition being made against the prevailing regime? The premise the size
   //     increase depends on is exactly the one a trend suspends, so the increase should be smaller
   //     where the premise is weakest.
   if(EnableGridRegimeCheck)
   {
      string rq_detail = "";
      double rq = RegimeContradiction(basket_dir, rq_detail);
      if(rq > 0.0)
      {
         quality -= GridQualityRegimeWeight * rq;
         parts += "against regime; ";
      }
   }

   // 3b. V233: is the bar in front of us going the wrong way? An addition placed during an adverse
   //     push fills at the worst price of that push, and it is the largest rung so far. Size it for
   //     what is actually happening rather than for what the ladder assumed.
   if(EnableGridCandleRead && EnableSingleCandleGuard)
   {
      int    q_dir = 0;
      string q_detail = "";
      double q_strength = SingleCandleDominance(q_dir, q_detail);
      if(q_dir == -basket_dir && q_strength >= SingleCandleMinStrength)
      {
         quality -= GridQualityBigBarWeight * q_strength;
         parts += "adverse bar; ";
      }
      else if(q_dir == basket_dir && q_strength >= SingleCandleMinStrength)
      {
         // A dominant bar in the basket's favour while it is underwater means the recovery has
         // started - a better moment to add than the ladder's arithmetic would have chosen.
         quality += GridQualityBigBarWeight * q_strength * 0.6;
         parts += "recovery bar; ";
      }
   }

   // 3. How much room is left? The deepest additions are the ones that decide whether
   //    a basket survives, and they are also the least reversible. Committing full
   //    size there when the basket is already stretched is what turns a drawdown into
   //    a stop-out.
   if(G_BASKET_DD_PERCENT > 0.0 && BasketSLPercent > 0.0)
   {
      double used = G_BASKET_DD_PERCENT / BasketSLPercent;
      if(used >= GridQualityDeepFrom)
      {
         double deep = (used - GridQualityDeepFrom) / MathMax(0.01, 1.0 - GridQualityDeepFrom);
         quality -= GridQualityDeepWeight * MathMin(1.0, deep);
         parts += StringFormat("%.0f%% of SL used; ", used * 100.0);
      }
   }

   quality = MathMax(0.0, MathMin(1.0, quality));

   // Map quality onto a lot multiplier. A neutral addition keeps its full size - the
   // ladder's arithmetic is the default, and quality moves it either way from there.
   double factor;
   if(quality >= 0.5)
      factor = 1.0 + (quality - 0.5) * 2.0 * (GridQualityMaxFactor - 1.0);
   else
      factor = 1.0 - (0.5 - quality) * 2.0 * (1.0 - GridQualityMinFactor);

   factor = MathMax(GridQualityMinFactor, MathMin(GridQualityMaxFactor, factor));

   if(StringLen(parts) > 0)
      detail = StringFormat("addition quality %.0f%% -> x%.2f (%s)", quality * 100.0, factor, parts);
   return factor;
}

// ============================================================================
// V221: THE GRID DECIDES WHERE TO ADD, NOT JUST WHEN
// ----------------------------------------------------------------------------
// The grid currently answers one question - has price moved far enough - and then
// adds. Thirty checks can stop it for account reasons, and one (GridZoneWait) makes
// it pause when price is inside an unreadable band. None of them ask the question
// that decides whether the addition is any good: is there anything HERE to add
// against?
//
// Two consequences, both expensive.
//
// A DIRECTION IT NEVER RE-EXAMINES. The first entry passes forty modules deciding
// whether the direction is right. Grid additions inherit that decision and are never
// re-tested, so a basket opened into what looked like a pullback keeps adding while
// the pullback turns out to be a trend change. Each addition is larger than the last.
//
// A PRICE CHOSEN BY ARITHMETIC. The next addition sits wherever the multiplier puts
// it. If a strong support lies fifty points below that, the grid adds above it rather
// than at it - buying the last of the fall instead of the level that stops it. The
// distance is the trigger; it should not also be the location.
// ============================================================================

// Is the basket's direction still supportable, or has the market moved against the
// premise the basket was opened on?
//   returns 0..1 - how badly the direction has deteriorated
double GridDirectionDoubt(const int basket_dir, string &detail)
{
   detail = "";
   if(!EnableGridDirectionCheck || basket_dir == 0)
      return 0.0;

   double doubt = 0.0;
   string parts = "";

   // 1. The swing shape. A basket bought into what is now a sequence of lower highs
   //    is not in a pullback - it is on the wrong side of a trend.
   if(EnableLocalSwingShape)
   {
      int    sw_steps = 0;
      double sw_conv = 0.0;
      string sw_detail = "";
      int    sw_dir = LocalSwingShape(sw_steps, sw_conv, sw_detail);
      if(sw_dir != 0 && sw_dir == -basket_dir)
      {
         doubt += GridDoubtSwingWeight * sw_conv;
         parts += StringFormat("%s; ", sw_detail);
      }
   }

   // 2. Structure. A break against the basket is the market saying the level that
   //    defined its direction no longer holds.
   if(EnableMarketStructure && G_STRUCTURE_DIR != 0 && G_STRUCTURE_DIR == -basket_dir)
   {
      doubt += GridDoubtStructureWeight;
      parts += "structure against; ";
   }

   // 3. The higher timeframe candle. The basket may have been opened on a reading
   //    that the larger candle has since contradicted.
   if(EnableCandleHTF)
   {
      double htf_body = 0.0;
      string htf_detail = "";
      if(CandleHTFAgreement(basket_dir, htf_body, htf_detail) < 0)
      {
         doubt += GridDoubtHTFWeight * htf_body;
         parts += "higher timeframe against; ";
      }
   }

   // 5. V233: what are the candles doing right now? The grid reads structure and timeframes and
   //    never looks at the bar in front of it - so an addition goes in during the exact candle that
   //    is driving price away from the basket. That is the worst moment available: the size is
   //    committed at the fastest part of the adverse move, and the next addition then has to be
   //    larger still.
   //
   //    The same readings the entry engine uses, applied to the decision it never covers.
   if(EnableGridCandleRead)
   {
      // A single dominant bar against the basket. This is the one the entry side found most
      // valuable, and the grid was blind to it entirely.
      if(EnableSingleCandleGuard)
      {
         int    gc_dir = 0;
         string gc_detail = "";
         double gc_strength = SingleCandleDominance(gc_dir, gc_detail);
         if(gc_dir == -basket_dir && gc_strength >= SingleCandleMinStrength)
         {
            doubt += GridDoubtBigBarWeight * gc_strength;
            parts += StringFormat("%s; ", gc_detail);
         }
      }

      // A run of closes going the wrong way. Adding into the third bar of a push is adding into
      // the part of it that is still being driven.
      if(EnableConsecutivePressure)
      {
         int    gp_run = 0;
         double gp_body = 0.0;
         string gp_detail = "";
         int    gp_dir = ConsecutivePressureDir(gp_run, gp_body, gp_detail);
         if(gp_dir == -basket_dir)
         {
            doubt += GridDoubtPressureWeight;
            parts += StringFormat("%s; ", gp_detail);
         }
      }

      // And the bar forming right now, weighted by how much of it has happened. Late in a bar
      // this is nearly a closed candle; early it counts for very little, which is correct.
      if(EnableLiveBarRead)
      {
         int    gl_dir = 0;
         double gl_w = 0.0;
         string gl_detail = "";
         int    gl_state = LiveBarRead(gl_dir, gl_w, gl_detail);
         if(gl_dir == -basket_dir && gl_w >= LiveBarMinWeight &&
            (gl_state == CANDLE_STATE_EXPANDING || gl_state == CANDLE_STATE_REJECTION))
         {
            doubt += GridDoubtLiveBarWeight * gl_w;
            parts += StringFormat("%s; ", gl_detail);
         }
      }
   }

   // 8. V244: would the next rung put the target out of reach? The ladder's arithmetic works against
   //    it here - every addition pulls the average further from price, so the target moves away as
   //    the basket grows. A rung that leaves the recovery needing a move the timeframe does not
   //    usually produce is not recovery; it is postponement at increasing size.
   if(EnableBasketReach)
   {
      string rn_detail = "";
      double after = ReachAfterNextRung(rn_detail);
      if(after < BasketReachDoubtBelow)
      {
         double shortfall = (BasketReachDoubtBelow - after) / MathMax(0.01, BasketReachDoubtBelow);
         doubt += GridDoubtReachWeight * shortfall;
         parts += rn_detail + "; ";
      }
   }

   // V268: a thin day is the wrong day to extend a ladder. The recovery the arithmetic assumes needs
   //    someone on the other side, and on these days the book is thinner than the spacing was sized
   //    for.
   if(EnableCalendarThinness)
   {
      string gt_detail = "";
      double gt = CalendarThinness(gt_detail);
      if(gt >= ThinGridDoubtFrom)
      {
         doubt += GridDoubtThinWeight * gt;
         parts += gt_detail;
      }
   }

   // 7. V240: does the regime itself contradict this basket? Everything the ladder does rests on
   //    price coming back, and that premise holds in a range and fails in a trend. The EA classifies
   //    the market and the grid has never read the classification - so it builds identically whether
   //    price is oscillating around a mean or walking away from one.
   //
   //    A ladder WITH a trend is fine; that is buying dips in an uptrend, which is what the
   //    arithmetic exists for. What this catches is the ladder against one, where every addition is
   //    a larger bet on something the market is currently refusing.
   if(EnableGridRegimeCheck)
   {
      string rg_detail = "";
      double rg = RegimeContradiction(basket_dir, rg_detail);
      if(rg > 0.0)
      {
         doubt += GridDoubtRegimeWeight * rg;
         parts += rg_detail;
      }
   }

   // 6. V236: how far has the move against this basket already travelled? From two live stop-outs -
   //    a buy at the top of a $24 run that then fell $48, and a sell at the bottom of a $99 decline
   //    that then rose $32. Both baskets were opened at the end of a move, and in both the grid kept
   //    adding into the reversal that followed.
   //
   //    The entry engine reads move maturity and refuses these. The grid does not, so once a basket
   //    exists the ladder walks straight into the same extended move the entry side would have
   //    rejected - and each rung is larger than the last.
   //
   //    An adverse move that has already run its usual distance is the case the ladder is worst
   //    suited to: it does not retrace on the schedule the martingale arithmetic assumes.
   if(EnableGridMaturityCheck)
   {
      if(EnableStructureMaturity)
      {
         string gm_detail = "";
         double gm = StructureMaturity(gm_detail);

         // Only counts when the mature structure runs AGAINST the basket. A mature move in the
         // basket's favour is the recovery arriving, which is the opposite situation.
         if(gm >= GridMaturityFrom && G_LS_DIR == -basket_dir)
         {
            double over = (gm - GridMaturityFrom) / MathMax(0.01, 1.0 - GridMaturityFrom);
            doubt += GridDoubtMaturityWeight * MathMin(1.0, over);
            parts += StringFormat("adverse move %s; ", gm_detail);
         }
      }

      // And the shorter-term reading of the same thing. A move past its climax point is where the
      // entry engine waits for a pullback; the grid should not be adding through it either.
      if(EnableMoveExtension)
      {
         double gx = MoveExtensionATR(-basket_dir);
         if(gx >= MoveExtensionClimaxATR)
         {
            doubt += GridDoubtExtensionWeight;
            parts += StringFormat("adverse move %.1f ATR extended; ", gx);
         }
      }
   }

   // 4b. V225: has price left the structure the basket was opened inside? The invalidation is a
   //     specific price, and once it is through, the shape that justified the basket no longer
   //     exists - which is a stronger statement than any of the readings above, because it is a
   //     definition rather than a threshold.
   if(EnableGridStructureCheck && EnableLocalStructure)
   {
      LocalStructureUpdate();
      if(G_LS_DIR != 0 && G_LS_DIR == -basket_dir && G_LS_INVALIDATE > 0.0 && _Point > 0.0)
      {
         double gs_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double gs_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double gs_mid = (gs_bid > 0.0 && gs_ask > 0.0) ? (gs_bid + gs_ask) / 2.0 : gs_bid;

         if(gs_mid > 0.0)
         {
            // The basket is fighting a structure. Additions belong INSIDE it - between price and
            // the invalidation - not beyond, where the structure would have to be wrong for the
            // basket to be right.
            bool beyond = (basket_dir > 0) ? (gs_mid < G_LS_INVALIDATE)
                                           : (gs_mid > G_LS_INVALIDATE);
            if(beyond)
            {
               doubt += GridDoubtStructureAgainst;
               parts += StringFormat("basket fighting a %s structure ending at %.2f; ",
                                     (G_LS_DIR > 0 ? "rising" : "falling"), G_LS_INVALIDATE);
            }
         }
      }
   }

   // 4. A named situation pointing the other way carries the most weight, because it
   //    is three layers agreeing rather than one indicator.
   if(EnableSituationRead && G_SITUATION != SIT_NONE && G_SITUATION_DIR == -basket_dir)
   {
      doubt += GridDoubtSituationWeight;
      parts += StringFormat("%s; ", SituationName(G_SITUATION));
   }

   doubt = MathMax(0.0, MathMin(1.0, doubt));
   if(doubt > 0.0)
      detail = StringFormat("direction doubt %.0f%%: %s", doubt * 100.0, parts);
   return doubt;
}

// ============================================================================
// V220: THE SITUATION DECIDES THE TRADE, NOT JUST THE SCORE
// ----------------------------------------------------------------------------
// V219 names what is happening and then does nothing with it beyond adjusting a
// score. But each of the four situations calls for a materially different trade, and
// the EA currently gives all of them the same $2.50 target and the same grid.
//
//   A level that HELD is a bounce: price is being turned away, so the target is the
//   distance back across the range, and the grid should be tight because the move is
//   expected to come back quickly.
//
//   A level that BROKE is a continuation: the target is the next level down, and the
//   grid should be wide because price is travelling, not oscillating.
//
//   A stretched trend REFUSED at a level is a reversal: the largest target of the
//   four, since the whole prior move is now the room available - but the smallest
//   size, because reversals fail more often than they work.
//
//   A range edge is the most measurable of all: the opposite edge is a known price,
//   so the target is arithmetic rather than estimate.
//
// The situation knows where price is going. Setting a fixed target and then adjusting
// it by session and regime is guessing at something already known.
// ============================================================================

// The target this situation implies, in points. Returns 0 when it has no view.
double SituationTargetPoints(const int sit, const int dir, string &detail)
{
   detail = "";
   if(!EnableSituationPlan || sit == SIT_NONE || dir == 0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double raw_mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(raw_mid <= 0.0)
      return 0.0;

   // FIX(tp-anchor-vs-current-price): the value this returns is consumed as a distance from the
   // BASKET AVERAGE (CurrentBasketPoints(dir, avg) >= tp_points), so the destination has to be
   // found AND measured from that same origin. Searching from current price while measuring from
   // the average is what made the target run away as a basket sank - and simply measuring from the
   // average while still searching from price would swing to the other extreme, rejecting almost
   // every level as "behind us" and switching the feature off for open ladders entirely. Both
   // origins are the anchor now: for a losing BUY the search starts at the average (above price),
   // so the level it finds is one the basket can actually exit into. With no basket the anchor IS
   // current price, so first-entry behaviour is unchanged.
   double anchor = (G_BASKET_ORDERS > 0 && G_BASKET_AVG_PRICE > 0.0) ? G_BASKET_AVG_PRICE : raw_mid;
   double mid    = (dir > 0) ? MathMax(raw_mid, anchor) : MathMin(raw_mid, anchor);

   // Where is price going, in this situation's terms?
   double target_price = 0.0;

   switch(sit)
   {
      case SIT_RANGE_EDGE_FADE:
      case SIT_TREND_TEST_HELD:
      case SIT_EXHAUSTION_AT_EDGE:
      {
         // Price was turned away from a level - it travels to the opposite one. That
         // is a known price, not an estimate.
         target_price = (dir > 0) ? ZoneMapNearestResistance(mid)
                                  : ZoneMapNearestSupport(mid);
         if(target_price > 0.0)
            detail = StringFormat("target: opposite level %.2f", target_price);
         break;
      }

      case SIT_BROKEN_LEVEL_RETEST:
      {
         // The level held from its new side, so the move that broke it resumes. The target is
         // whatever is next in that direction - the level just reclaimed is now behind the trade,
         // which is what makes this the cleanest of the five.
         target_price = (dir > 0) ? ZoneMapNearestResistance(mid)
                                  : ZoneMapNearestSupport(mid);
         if(target_price > 0.0)
            detail = StringFormat("target: next level %.2f, with %.2f now behind us",
                                  target_price, G_LSB_BREAK_PRICE);
         break;
      }

      case SIT_TREND_TEST_BROKE:
      {
         // The level gave way, so price continues to whatever is behind it. The level
         // just broken is the one to look past.
         double broken = (dir > 0) ? ZoneMapNearestResistance(mid)
                                   : ZoneMapNearestSupport(mid);
         if(broken > 0.0)
         {
            target_price = (dir > 0) ? ZoneMapNextResistanceAbove(mid, broken)
                                     : ZoneMapNextSupportBelow(mid, broken);
            if(target_price > 0.0)
               detail = StringFormat("target: next level %.2f past the broken %.2f",
                                     target_price, broken);
         }
         break;
      }
   }

   if(target_price <= 0.0)
      return 0.0;

   // FIX(tp-anchor-vs-current-price): the destination is FOUND relative to current price (correct -
   // that is where the levels are), but the number returned here is consumed by
   // Pack2BasketTPForOrders() as a distance from the BASKET AVERAGE:
   //     close when CurrentBasketPoints(dir, avg) >= tp_points
   // Measuring it from `mid` therefore mixed two different origins. As a basket sinks, `mid` moves
   // away from `avg`, so the same physical destination produced a bigger and bigger "target" - the
   // exit ran away from the basket exactly as the basket needed it to come closer. This is the very
   // thing the V228 comment at the call site says must not happen ("The destination does not change
   // because the ladder grew; only the average entry does").
   //
   // MathAbs made it worse: a destination sitting BEHIND the average came back as a large positive
   // target instead of being rejected. Signed against `dir` now, so a level price has already passed
   // is no target at all. `anchor` is the same origin the search above started from.
   double pts = (target_price - anchor) * (double)dir / _Point;
   if(pts <= 0.0)
   {
      detail = "";
      return 0.0;                     // destination is behind the basket - not a take-profit
   }

   // Stop short of the level rather than at it - the last stretch into a level is
   // where price stalls, and a target sitting exactly on it often misses by a tick.
   pts *= MathMax(0.5, MathMin(1.0, SituationTargetReachFactor));

   if(pts < (double)SituationTargetMinPoints || pts > (double)SituationTargetMaxPoints)
   {
      detail = "";
      return 0.0;                     // outside what this strategy trades
   }

   return pts;
}

// How the grid should behave in this situation, as a multiplier on the normal spacing.
double SituationGridFactor(const int sit)
{
   if(!EnableSituationPlan || sit == SIT_NONE)
      return 1.0;

   switch(sit)
   {
      // A level holding means price is expected back quickly - additions can sit
      // closer together, because the recovery is the whole premise.
      case SIT_TREND_TEST_HELD:    return SituationGridHeld;
      case SIT_RANGE_EDGE_FADE:    return SituationGridHeld;

      // A level broken means price is travelling. Additions must be further apart or
      // the ladder fills in a single leg.
      // A retest that is holding has a defined invalidation just below - additions can sit closer,
      // because if price goes back through the level the premise is gone and spacing will not save it.
      case SIT_BROKEN_LEVEL_RETEST: return SituationGridRetest;
      case SIT_TREND_TEST_BROKE:   return SituationGridBroke;

      // A reversal that fails, fails hard - the prior trend resumes. Wide spacing
      // buys room to be wrong.
      case SIT_EXHAUSTION_AT_EDGE: return SituationGridReversal;
   }
   return 1.0;
}

// And the size. Reversals are the least reliable of the four and get the smallest
// commitment; a level holding within a range is the most repeatable.
double SituationLotFactor(const int sit)
{
   if(!EnableSituationPlan || sit == SIT_NONE)
      return 1.0;

   switch(sit)
   {
      case SIT_TREND_TEST_HELD:    return SituationLotHeld;
      case SIT_RANGE_EDGE_FADE:    return SituationLotHeld;
      case SIT_BROKEN_LEVEL_RETEST: return SituationLotRetest;
      case SIT_TREND_TEST_BROKE:   return SituationLotBroke;
      case SIT_EXHAUSTION_AT_EDGE: return SituationLotReversal;
   }
   return 1.0;
}

// ============================================================================
// V219: THE THREE LAYERS READ AS ONE STORY
// ----------------------------------------------------------------------------
// Zones, candles and local structure each produce a score, and the EA adds them up.
// That is the right treatment for three independent opinions and the wrong one for
// three parts of a single observation, which is what they usually are.
//
// Falling swing highs, price arriving at a support, and a rejection wick printing
// there is not three facts worth a few points each. It is one situation - a
// downtrend testing a level that is holding - and it is worth more than the sum,
// because the parts corroborate each other.
//
// Change one part and the meaning inverts entirely. Falling highs, price at that
// same support, and the rejection wick FILLED means the level gave way and the
// downtrend continues. Same three inputs, opposite conclusion. Adding scores cannot
// express that; it produces something in the middle, which is wrong in both cases.
//
// So the layers are read together and the situation is named. A named situation
// carries its own weight, and the individual contributions that formed it are
// suppressed so the same evidence is not counted twice.
// ============================================================================


string SituationName(const int sit)
{
   switch(sit)
   {
      case SIT_TREND_TEST_HELD:    return "trend testing a level that held";
      case SIT_TREND_TEST_BROKE:   return "trend took the level";
      case SIT_EXHAUSTION_AT_EDGE: return "stretched trend refused at a level";
      case SIT_RANGE_EDGE_FADE:    return "range edge rejected";
      case SIT_BROKEN_LEVEL_RETEST: return "broken level holding from the other side";
   }
   return "none";
}

// Reads zone, candle and structure together and names what they describe.
//   dir     - the direction the situation favours
//   weight  - 0..1, how completely the parts corroborate
int ReadSituation(int &dir, double &weight, string &detail)
{
   dir = 0;
   weight = 0.0;
   detail = "";

   if(!EnableSituationRead || _Point <= 0.0)
      return SIT_NONE;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return SIT_NONE;

   // --- part 1: what shape are the swings in? -------------------------------
   int    sw_steps = 0;
   double sw_conv = 0.0;
   string sw_detail = "";
   int    sw_dir = LocalSwingShape(sw_steps, sw_conv, sw_detail);

   // --- part 2: is price at a level, and which one? --------------------------
   // The level that matters is the one the swing sequence is heading INTO - a
   // downtrend is tested by support, an uptrend by resistance.
   double level = 0.0;
   bool   at_level = false;
   double level_strength = 0.0;

   if(sw_dir < 0)      level = ZoneMapNearestSupport(mid);
   else if(sw_dir > 0) level = ZoneMapNearestResistance(mid);
   else
   {
      // No trend - use whichever edge is closer, which is the range case.
      double sup = ZoneMapNearestSupport(mid);
      double res = ZoneMapNearestResistance(mid);
      double d_sup = (sup > 0.0) ? (mid - sup) : 1e9;
      double d_res = (res > 0.0) ? (res - mid) : 1e9;
      level = (d_sup <= d_res) ? sup : res;
   }

   if(level > 0.0)
   {
      double dist = MathAbs(mid - level) / _Point;
      double reach = ScaleAdjustedPoints(MathMax(1, SituationLevelReachPoints));
      at_level = (dist <= reach);
      level_strength = ZoneMapStrengthByTouches(level);
   }

   if(!at_level || level_strength < SituationMinLevelStrength)
      return SIT_NONE;                 // no level involved - nothing to corroborate

   // --- part 3: what did the candles do there? ------------------------------
   int    cs_dir = 0;
   double cs_conf = 0.0;
   string cs_detail = "";
   int    cs_state = CandleSequenceRead(cs_dir, cs_conf, cs_detail);

   int    ev_dir = 0;
   double ev_w = 0.0;
   string ev_detail = "";
   int    evo = LiveBarEvolution(ev_dir, ev_w, ev_detail);

   bool rejected_here   = (cs_state == CANDLE_STATE_REJECTION);
   bool rejection_failed = (evo == LIVE_EVO_WICK_FAILED);
   bool absorbed        = (cs_state == CANDLE_STATE_ABSORPTION || evo == LIVE_EVO_ABSORBED);

   // --- name it --------------------------------------------------------------
   double level_factor = MathMin(1.0, level_strength / MathMax(0.1, SituationFullStrength));

   // V231: the strongest setup on the chart, and the EA could see both halves of it without ever
   // joining them. A level is taken - StructureBreak records that. Price comes back to it and holds
   // from the new side - ZoneRetest finds that. Separately they are a break and a retest; together
   // they are one thing, and it is the highest-quality continuation available: the level that was
   // resistance is now support, everyone who sold it is wrong, and the move that broke it has
   // already proven it can.
   //
   // Checked before the others because it is the most specific. A broken level being retested is
   // also technically "a trend at a level", and the generic reading would take it and lose the part
   // that matters.
   if(EnableBrokenRetest && _Point > 0.0)
   {
      double br_fresh = 0.0, br_price = 0.0;
      int    br_dir = RecentStructureBreak(br_fresh, br_price);

      if(br_dir != 0 && br_price > 0.0)
      {
         // Has price come back to the level it broke? Not past it - back TO it. Going past means
         // the break failed, which is a different situation entirely.
         double back_pts = MathAbs(mid - br_price) / _Point;
         double tol = ScaleAdjustedPoints(MathMax(1, BrokenRetestTolerance));

         bool returned = (back_pts <= tol);
         bool still_beyond = (br_dir > 0) ? (mid >= br_price - (tol * _Point))
                                          : (mid <= br_price + (tol * _Point));

         if(returned && still_beyond)
         {
            // The level has to be worth retesting. A minor swing that broke and got retested is
            // just price moving; a level with history behind it changing sides is structural.
            double br_strength = ZoneMapStrengthByTouches(br_price);

            if(br_strength >= BrokenRetestMinStrength)
            {
               // And is it holding? A retest that fails is the break failing, and the difference
               // shows in the candles right at the level.
               bool holding = true;
               if(cs_state == CANDLE_STATE_REJECTION && cs_dir == -br_dir)
                  holding = false;          // being rejected back through - the break is failing
               if(evo == LIVE_EVO_WICK_FAILED && ev_dir == -br_dir)
                  holding = false;

               // V232: was the level broken on the scale that matters, or only on the one being
               // watched? From a live loss - M1 broke through and the retest looked clean, while on
               // M5 and M15 the level had never gone anywhere. Buying it meant buying a break that
               // only existed at the resolution the EA happened to be reading.
               //
               // The break has to survive being looked at from further away. A level the higher
               // timeframe still shows as intact is not a broken level; it is a level being tested,
               // and price is on the wrong side of it.
               // V250: and does the break survive two steps up? A break real on one timeframe and
               // invisible on the one above it is the smaller scale running ahead of the larger.
               if(holding && EnableDeepBreakConfirm)
               {
                  string dc_detail = "";
                  if(!BreakConfirmedTwoLevels(br_price, br_dir, dc_detail))
                  {
                     holding = false;
                     if((BrokenRetestPrintOnUse && G_VERBOSE) && StringLen(dc_detail) > 0)
                        PrintFormat("[SIRUS v250 DEEP] %s", dc_detail);
                  }
               }

               if(holding && EnableBrokenRetestMTF)
               {
                  double htf_c = CandleClose(BrokenRetestConfirmTF, 1);
                  if(htf_c > 0.0)
                  {
                     bool htf_beyond = (br_dir > 0) ? (htf_c > br_price) : (htf_c < br_price);
                     if(!htf_beyond)
                     {
                        holding = false;
                        if((BrokenRetestPrintOnUse && G_VERBOSE))
                           PrintFormat("[SIRUS v232 RETEST] %.2f broke on %s but %s has not closed through it",
                                       br_price, EnumToString(LocalStructureTF),
                                       EnumToString(BrokenRetestConfirmTF));
                     }
                  }
               }

               // V232: and is the level where liquidity has been collecting? A long wick into a
               // level on a higher timeframe is stops sitting there - price is drawn to them, and a
               // retest that looks like support holding is often price being pulled through it.
               // The wick is the warning the retest itself cannot give.
               if(holding && EnableBrokenRetestWickCheck && _Point > 0.0)
               {
                  for(int wi = 1; wi <= MathMax(2, BrokenRetestWickBars); wi++)
                  {
                     double wh = CandleHigh(BrokenRetestConfirmTF, wi);
                     double wl = CandleLow(BrokenRetestConfirmTF, wi);
                     double wo = CandleOpen(BrokenRetestConfirmTF, wi);
                     double wc = CandleClose(BrokenRetestConfirmTF, wi);
                     if(wh <= 0.0 || wl <= 0.0 || wo <= 0.0 || wc <= 0.0) continue;
                     double wrange = wh - wl;
                     if(wrange <= 0.0) continue;

                     // The wick that matters points INTO the level from the side price is now on.
                     double wick = (br_dir > 0) ? (wh - MathMax(wo, wc)) : (MathMin(wo, wc) - wl);
                     double wick_tip = (br_dir > 0) ? wh : wl;

                     if((wick / wrange) < BrokenRetestWickMinRatio) continue;

                     // Does it reach the level being retested?
                     double wick_gap = MathAbs(wick_tip - br_price) / _Point;
                     if(wick_gap <= ScaleAdjustedPoints(MathMax(1, BrokenRetestWickTolerance)))
                     {
                        holding = false;
                        if((BrokenRetestPrintOnUse && G_VERBOSE))
                           PrintFormat("[SIRUS v232 RETEST] %.2f sits under a %.0f%% wick on %s - liquidity, not support",
                                       br_price, (wick / wrange) * 100.0,
                                       EnumToString(BrokenRetestConfirmTF));
                        break;
                     }
                  }
               }

               if(holding)
               {
                  dir = br_dir;
                  double str_f = MathMin(1.0, br_strength / MathMax(0.1, SituationFullStrength));
                  weight = MathMin(1.0, (0.5 + 0.5 * br_fresh) * (0.5 + 0.5 * str_f) *
                                        BrokenRetestWeightBoost);
                  detail = StringFormat("%.2f broke and is holding as %s (%.2f strength, %.0f%% fresh)",
                                        br_price, (br_dir > 0 ? "support" : "resistance"),
                                        br_strength, br_fresh * 100.0);
                  return SIT_BROKEN_LEVEL_RETEST;
               }
            }
         }
      }
   }

   // A trend arriving at a level that then gave way. The level's failure IS the
   // signal, and it points the way the trend was already going.
   if(sw_dir != 0 && rejection_failed && ev_dir == sw_dir)
   {
      dir = sw_dir;
      weight = MathMin(1.0, (0.4 + 0.6 * sw_conv) * (0.5 + 0.5 * level_factor) * ev_w);
      detail = StringFormat("%s, %s at %.2f gave way", sw_detail,
                            (sw_dir < 0 ? "support" : "resistance"), level);
      return SIT_TREND_TEST_BROKE;
   }

   // A trend arriving at a level that held. The rejection points against the trend,
   // which is a counter-trend trade and only worth taking when the trend is stretched.
   if(sw_dir != 0 && rejected_here && cs_dir == -sw_dir)
   {
      bool stretched = false;
      if(EnableMoveExtension)
      {
         double ext = MoveExtensionATR(sw_dir);
         stretched = (ext >= MoveExtensionMatureATR);
      }

      dir = -sw_dir;                    // with the rejection
      weight = MathMin(1.0, (0.35 + 0.65 * cs_conf) * (0.5 + 0.5 * level_factor));

      if(stretched)
      {
         weight = MathMin(1.0, weight * SituationExhaustionBoost);
         detail = StringFormat("%s but stretched, %s at %.2f held", sw_detail,
                               (sw_dir < 0 ? "support" : "resistance"), level);
         return SIT_EXHAUSTION_AT_EDGE;
      }

      detail = StringFormat("%s, %s at %.2f held", sw_detail,
                            (sw_dir < 0 ? "support" : "resistance"), level);
      return SIT_TREND_TEST_HELD;
   }

   // Absorption at a level with a trend running into it - effort meeting size.
   if(sw_dir != 0 && absorbed)
   {
      dir = -sw_dir;
      weight = MathMin(1.0, 0.5 * (0.5 + 0.5 * level_factor));
      detail = StringFormat("%s absorbed at %.2f", sw_detail, level);
      return SIT_TREND_TEST_HELD;
   }

   // No trend, price at an edge, rejection printing. The range case.
   if(sw_dir == 0 && rejected_here && cs_dir != 0)
   {
      dir = cs_dir;
      weight = MathMin(1.0, (0.3 + 0.7 * cs_conf) * (0.4 + 0.6 * level_factor));
      detail = StringFormat("no trend, %.2f rejected price", level);
      return SIT_RANGE_EDGE_FADE;
   }

   return SIT_NONE;
}

// ============================================================================
// V218: THE ENTRY BAR ITSELF, AND THE SHAPE OF THE LAST FEW SWINGS
// ----------------------------------------------------------------------------
// From a live loss: a buy opened at 4394.43 on a bar that had spiked to 4397 and
// closed back down - the entry was taken INTO the wick of a sweep, and price then
// fell four dollars.
//
// Two things allowed it.
//
// THE ENTRY BAR. Everything here reads bar 1 and later. The bar an entry actually
// opens on is never examined, so a fill in the upper third of a bar that had already
// been rejected from its high looks identical to a fill at the low of a strong one.
// The question is simple and was never asked: where in this bar are we buying?
//
// THE LOCAL SHAPE. On M5 that same move was a sequence of lower highs - 4402, then
// 4398, then 4394 - and the entry was at the third one. The EA reads trend direction
// and structure breaks, but not the plain arithmetic of "each swing high is below the
// last", which is what a trader sees immediately and which said this was a downtrend
// long before any structure break confirmed it.
// ============================================================================

// Where in the current bar would this entry fill, and has that bar already been
// rejected from the extreme we are buying toward?
//   returns 0..1 - how badly placed the fill is (0 = fine, 1 = at the top of a
//   bar that has already been pushed back)
double EntryBarPlacement(const int dir, string &detail)
{
   detail = "";
   if(!EnableEntryBarCheck || dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = EntryBarTF;
   double o = CandleOpen(tf, 0), h = CandleHigh(tf, 0), l = CandleLow(tf, 0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px = (dir > 0) ? ask : bid;
   if(o <= 0.0 || h <= 0.0 || l <= 0.0 || px <= 0.0)
      return 0.0;

   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   // Ignore bars too small to have a meaningful shape.
   double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
   if(atr > 0.0 && (range / atr) < EntryBarMinSizeATR)
      return 0.0;

   // Where in the bar's range does the fill sit, measured in the direction of the
   // trade? Buying at the high of the bar is the worst placement available.
   double pos = (dir > 0) ? (px - l) / range : (h - px) / range;
   if(pos < EntryBarBadPlacement)
      return 0.0;                     // filling in the lower part of the range - fine

   // And has the bar already been rejected from that extreme? A fill near the high is
   // acceptable when the bar is still pressing up; it is a sweep when the high was
   // made and given back.
   double c_now = CandleClose(tf, 0);
   double rejected = 0.0;
   if(dir > 0)
   {
      double wick = h - MathMax(o, c_now);
      rejected = wick / range;
   }
   else
   {
      double wick = MathMin(o, c_now) - l;
      rejected = wick / range;
   }

   double severity = pos * (EntryBarPlacementWeight + (1.0 - EntryBarPlacementWeight) *
                            MathMin(1.0, rejected / MathMax(0.05, EntryBarRejectedWick)));

   detail = StringFormat("filling at %.0f%% of the bar, %.0f%% of it already rejected",
                         pos * 100.0, rejected * 100.0);
   return MathMax(0.0, MathMin(1.0, severity));
}

// The plain arithmetic of the recent swings: are the highs stepping down and the lows
// stepping down with them?
//   returns -1 lower highs and lower lows, +1 higher highs and higher lows, 0 mixed
int LocalSwingShape(int &steps, double &conviction, string &detail)
{
   steps = 0;
   conviction = 0.0;
   detail = "";

   if(!EnableLocalSwingShape || _Point <= 0.0)
      return 0;

   static int    ls_bar = -100000;
   static int    ls_dir = 0;
   static int    ls_steps = 0;
   static double ls_conv = 0.0;
   static string ls_detail = "";
   if(ls_bar > G_BARS_SEEN) ls_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ls_bar == G_BARS_SEEN)
   {
      steps = ls_steps; conviction = ls_conv; detail = ls_detail;
      return ls_dir;
   }

   ENUM_TIMEFRAMES tf = LocalSwingTF;
   int look = MathMax(20, LocalSwingLookbackBars);
   int depth = MathMax(1, LocalSwingDepth);

   // Collect the recent confirmed swing highs and lows, newest first.
   double highs[10], lows[10];
   int nh = 0, nl = 0;

   for(int i = depth + 1; i <= look && (nh < 10 || nl < 10); i++)
   {
      if(nh < 10)
      {
         double hv = CandleHigh(tf, i);
         bool is_high = (hv > 0.0);
         for(int k = 1; k <= depth && is_high; k++)
         {
            if(CandleHigh(tf, i - k) >= hv || CandleHigh(tf, i + k) >= hv)
               is_high = false;
         }
         if(is_high)
            highs[nh++] = hv;
      }
      if(nl < 10)
      {
         double lv = CandleLow(tf, i);
         bool is_low = (lv > 0.0);
         for(int k = 1; k <= depth && is_low; k++)
         {
            if(CandleLow(tf, i - k) <= lv || CandleLow(tf, i + k) <= lv)
               is_low = false;
         }
         if(is_low)
            lows[nl++] = lv;
      }
   }

   int need = MathMax(2, LocalSwingMinSwings);
   if(nh < need && nl < need)
      return 0;

   // Count how many consecutive steps go the same way. highs[0] is the newest.
   int down_steps = 0, up_steps = 0;
   for(int a = 0; a + 1 < nh && a < 5; a++)
   {
      if(highs[a] < highs[a+1]) down_steps++;
      else break;
   }
   for(int a = 0; a + 1 < nh && a < 5; a++)
   {
      if(highs[a] > highs[a+1]) up_steps++;
      else break;
   }

   int low_down = 0, low_up = 0;
   for(int b = 0; b + 1 < nl && b < 5; b++)
   {
      if(lows[b] < lows[b+1]) low_down++;
      else break;
   }
   for(int b = 0; b + 1 < nl && b < 5; b++)
   {
      if(lows[b] > lows[b+1]) low_up++;
      else break;
   }

   // A shape only counts when highs AND lows agree - lower highs with higher lows is
   // a contraction, not a downtrend, and treating it as one is how a range gets sold
   // at its floor.
   int dir = 0;
   if(down_steps >= 1 && low_down >= 1)
   {
      dir = -1;
      steps = MathMin(down_steps, low_down);
   }
   else if(up_steps >= 1 && low_up >= 1)
   {
      dir = 1;
      steps = MathMin(up_steps, low_up);
   }

   if(dir == 0 || steps < 1)
   {
      ls_bar = G_BARS_SEEN; ls_dir = 0; ls_steps = 0; ls_conv = 0.0; ls_detail = "";
      return 0;
   }

   // More consecutive steps means a shape that is established rather than incidental.
   conviction = MathMin(1.0, (double)steps / MathMax(1.0, (double)LocalSwingFullSteps));

   detail = StringFormat("%d %s swings in a row",
                         steps, (dir > 0 ? "rising" : "falling"));

   ls_bar = G_BARS_SEEN; ls_dir = dir; ls_steps = steps; ls_conv = conviction; ls_detail = detail;
   return dir;
}

// ============================================================================
// V216: THE CANDLE LAYER LEARNS WHICH OF ITS OWN READINGS WORK
// ----------------------------------------------------------------------------
// Ten candle modules, and the EA trusts all of them equally on the strength of the
// reasoning behind them. That reasoning is sound in general and may be wrong here:
// wick authorship might read this broker's spread behaviour badly, higher-timeframe
// agreement might be the only thing that matters on gold, live-bar evolution might be
// noise at this tick rate. There is no way to know from the code.
//
// So each reading is recorded when it fires and graded by what price did afterwards.
// A module whose calls keep being right gets a louder voice; one that keeps being
// wrong gets a quieter one, and eventually contributes almost nothing without ever
// being switched off.
//
// This is deliberately per-READING rather than per-trade. A module can be right about
// direction while the trade loses for unrelated reasons, and grading it on the trade
// would teach the wrong lesson. What is graded is the only thing the module actually
// claimed: that price would go this way from here.
// ============================================================================


string CandleSourceName(const int src)
{
   switch(src)
   {
      case CSRC_SEQUENCE:      return "sequence";
      case CSRC_AUTHORSHIP:    return "wick";
      case CSRC_PARTICIPATION: return "volume";
      case CSRC_OPENING:       return "open";
      case CSRC_PATTERN:       return "pattern";
      case CSRC_HTF:           return "htf";
      case CSRC_LIVEBAR:       return "live";
      case CSRC_EVOLUTION:     return "evolution";
      case CSRC_CONFLICT:      return "conflict";
      case CSRC_BREAK:         return "break";
   }
   return "?";
}

// Candle-event tracking (V209) and pattern outcomes (V211). Declared here rather than beside their
// own modules because the persistence helpers below read them, and MQL5 resolves functions ahead of
// use but not variables.
int      G_CE_DIR[CANDLE_EVENT_SLOTS];
int      G_CE_BAR[CANDLE_EVENT_SLOTS];
double   G_CE_LEVEL[CANDLE_EVENT_SLOTS];
int      G_CE_TYPE[CANDLE_EVENT_SLOTS];
int      G_CE_COUNT = 0;
double   G_CE_REJECT_HELD = 0.0, G_CE_REJECT_FAILED = 0.0;
double   G_CE_BREAK_HELD  = 0.0, G_CE_BREAK_FAILED  = 0.0;

double   G_PAT_WON[8];
double   G_PAT_LOST[8];
int      G_PAT_JUDGE_TYPE  = 0;
int      G_PAT_JUDGE_DIR   = 0;
int      G_PAT_JUDGE_BAR   = 0;
double   G_PAT_JUDGE_PRICE = 0.0;

double G_CSRC_RIGHT[CSRC_COUNT];
double G_CSRC_WRONG[CSRC_COUNT];

// One pending judgement per source - a reading is graded before the same source is
// recorded again, which keeps the sample honest rather than counting a persistent
// state ten times.
int    G_CSRC_P_DIR[CSRC_COUNT];
int    G_CSRC_P_BAR[CSRC_COUNT];
double G_CSRC_P_PRICE[CSRC_COUNT];

void CandleSourceRecord(const int src, const int dir)
{
   if(!EnableCandleLearning || src < 0 || src >= CSRC_COUNT || dir == 0)
      return;
   if(G_CSRC_P_DIR[src] != 0)
      return;                      // already watching this source's last call

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   G_CSRC_P_DIR[src]   = dir;
   G_CSRC_P_BAR[src]   = G_BARS_SEEN;
   G_CSRC_P_PRICE[src] = mid;
}

void CandleSourceSettle()
{
   if(!EnableCandleLearning || _Point <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   for(int src = 0; src < CSRC_COUNT; src++)
   {
      if(G_CSRC_P_DIR[src] == 0)
         continue;
      if((G_BARS_SEEN - G_CSRC_P_BAR[src]) < MathMax(2, CandleLearningHorizonBars))
         continue;

      double moved = (mid - G_CSRC_P_PRICE[src]) / _Point * (double)G_CSRC_P_DIR[src];

      // Only decisive outcomes count. A reading that was followed by nothing was
      // neither right nor wrong, and forcing it into one bucket would be inventing
      // evidence.
      if(moved >= (double)CandleLearningDecisivePoints)
         G_CSRC_RIGHT[src] += 1.0;
      else if(moved <= -(double)CandleLearningDecisivePoints)
         G_CSRC_WRONG[src] += 1.0;

      double total = G_CSRC_RIGHT[src] + G_CSRC_WRONG[src];
      if(total > (double)CandleLearningMaxSamples)
      {
         double sc = (double)CandleLearningMaxSamples / total;
         G_CSRC_RIGHT[src] *= sc;
         G_CSRC_WRONG[src] *= sc;
      }

      G_CSRC_P_DIR[src] = 0;
   }
}

// How often has this source been right? -1 when there is not enough evidence.
double CandleSourceAccuracy(const int src)
{
   if(!EnableCandleLearning || src < 0 || src >= CSRC_COUNT)
      return -1.0;
   double total = G_CSRC_RIGHT[src] + G_CSRC_WRONG[src];
   if(total < (double)CandleLearningMinSamples)
      return -1.0;
   return G_CSRC_RIGHT[src] / total;
}

// The multiplier this source's score has earned. 1.0 until there is a record.
double CandleSourceWeight(const int src)
{
   double acc = CandleSourceAccuracy(src);
   if(acc < 0.0)
      return 1.0;

   // Centred on the break-even rate: at 50% a source is guessing and keeps its
   // nominal weight; above that it earns influence, below it loses influence. The
   // range is bounded so a run of luck cannot make one module dominate, and a bad
   // patch cannot silence a module that is sound.
   double edge = (acc - 0.5) / 0.5;                     // -1 .. +1
   double w = 1.0 + edge * CandleLearningSensitivity;
   return MathMax(CandleLearningMinWeight, MathMin(CandleLearningMaxWeight, w));
}

// Applies the learned weight to a score contribution, and records the call.
int CandleWeighted(const int src, const int dir, const int raw_score)
{
   if(raw_score == 0 || dir == 0)
      return 0;
   CandleSourceRecord(src, dir);
   if(!EnableCandleLearning)
      return raw_score;
   int out = (int)MathRound((double)raw_score * CandleSourceWeight(src));
   return MathMax(0, out);
}

// V217: the candle record survives a restart.
//
// Every learning system here writes to GlobalVariables for one reason: without it the record
// resets each time the EA is reattached, and an EA is reattached constantly - after a recompile,
// a settings change, an MT5 restart. A source needs eight graded calls before its record counts,
// and eight calls take hours; if the count starts from zero every session, the learning never
// arrives at anything.
//
// Keyed by symbol and magic number, so two instances on the same pair keep separate records rather
// than averaging two different strategies together.
string CandleLearnGVKey(const string suffix, const int idx)
{
   return StringFormat("NAVIUS_CANDLE_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, idx);
}

void CandleLearningSave()
{
   if(!EnableCandleLearning || !PersistCandleLearning)
      return;
   for(int src = 0; src < CSRC_COUNT; src++)
   {
      GlobalVariableSet(CandleLearnGVKey("R", src), G_CSRC_RIGHT[src]);
      GlobalVariableSet(CandleLearnGVKey("W", src), G_CSRC_WRONG[src]);
   }
}

void CandleLearningRestore()
{
   if(!EnableCandleLearning || !PersistCandleLearning)
      return;
   for(int src = 0; src < CSRC_COUNT; src++)
   {
      string kr = CandleLearnGVKey("R", src);
      string kw = CandleLearnGVKey("W", src);
      if(GlobalVariableCheck(kr)) G_CSRC_RIGHT[src] = GlobalVariableGet(kr);
      if(GlobalVariableCheck(kw)) G_CSRC_WRONG[src] = GlobalVariableGet(kw);
   }
   if(CandleLearningPrintOnRestore)
   {
      string txt = CandleLearningText();
      if(StringLen(txt) > 0)
         PrintFormat("[SIRUS v217 CANDLE LEARN] restored - %s", txt);
   }
}

// Pattern outcomes - same reasoning.
string PatternGVKey(const string suffix, const int pat)
{
   return StringFormat("NAVIUS_CPAT_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, pat);
}

void PatternRecordSave()
{
   if(!EnablePatternGrading || !PersistCandleLearning)
      return;
   for(int p = 1; p < 8; p++)
   {
      GlobalVariableSet(PatternGVKey("W", p), G_PAT_WON[p]);
      GlobalVariableSet(PatternGVKey("L", p), G_PAT_LOST[p]);
   }
}

void PatternRecordRestore()
{
   if(!EnablePatternGrading || !PersistCandleLearning)
      return;
   for(int p = 1; p < 8; p++)
   {
      string kw = PatternGVKey("W", p);
      string kl = PatternGVKey("L", p);
      if(GlobalVariableCheck(kw)) G_PAT_WON[p]  = GlobalVariableGet(kw);
      if(GlobalVariableCheck(kl)) G_PAT_LOST[p] = GlobalVariableGet(kl);
   }
}

// Rejection and break follow-through.
string FollowGVKey(const string suffix)
{
   return StringFormat("NAVIUS_CFOLLOW_%s_%d_%s", _Symbol, MagicNumber, suffix);
}

void FollowRecordSave()
{
   if(!EnableCandleFollowThrough || !PersistCandleLearning)
      return;
   GlobalVariableSet(FollowGVKey("RH"), G_CE_REJECT_HELD);
   GlobalVariableSet(FollowGVKey("RF"), G_CE_REJECT_FAILED);
   GlobalVariableSet(FollowGVKey("BH"), G_CE_BREAK_HELD);
   GlobalVariableSet(FollowGVKey("BF"), G_CE_BREAK_FAILED);
}

void FollowRecordRestore()
{
   if(!EnableCandleFollowThrough || !PersistCandleLearning)
      return;
   if(GlobalVariableCheck(FollowGVKey("RH"))) G_CE_REJECT_HELD   = GlobalVariableGet(FollowGVKey("RH"));
   if(GlobalVariableCheck(FollowGVKey("RF"))) G_CE_REJECT_FAILED = GlobalVariableGet(FollowGVKey("RF"));
   if(GlobalVariableCheck(FollowGVKey("BH"))) G_CE_BREAK_HELD    = GlobalVariableGet(FollowGVKey("BH"));
   if(GlobalVariableCheck(FollowGVKey("BF"))) G_CE_BREAK_FAILED  = GlobalVariableGet(FollowGVKey("BF"));
}

string CandleLearningText()
{
   if(!EnableCandleLearning)
      return "";
   string out = "";
   for(int src = 0; src < CSRC_COUNT; src++)
   {
      double acc = CandleSourceAccuracy(src);
      if(acc < 0.0)
         continue;
      out += StringFormat("%s %.0f%%(%.0f) ", CandleSourceName(src), acc * 100.0,
                          G_CSRC_RIGHT[src] + G_CSRC_WRONG[src]);
   }
   if(StringLen(out) == 0)
      return "";
   return "learned: " + out;
}

// ============================================================================
// V215: WHEN CANDLES MATTER, AND WHAT THEIR DISAGREEMENT MEANS
// ----------------------------------------------------------------------------
// Two things the candle layer still gets wrong, and one setting that was never right.
//
// WHEN. Candles carry most information at a level, where the question is whether it
// holds, and least in open space, where a wick is just where the bar happened to
// turn. The budget is currently the same in both, which spends the same weight on a
// reading that means everything and one that means very little.
//
// DISAGREEMENT. Ten readings, and when they conflict the EA simply adds them up. But
// "sequence says rejection, evolution says the wick failed" is not a weaker rejection
// - it is a specific event: the level was defended and the defence broke. Summing
// them cancels out the most useful thing either of them found.
//
// And the sequence timeframe is M1 while the setups are built on M5/M15 zones, so
// the candle layer has been reading a resolution finer than the decisions it informs.
// ============================================================================

// How much should candle readings count right now? Returns a multiplier on the
// candle budget: high near a level, low in open space.
double CandleRelevance(const int entry_dir, string &detail)
{
   detail = "";
   if(!EnableCandleRelevance || entry_dir == 0 || _Point <= 0.0)
      return 1.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 1.0;

   // Distance to whichever level is nearer, in either direction - a candle at support
   // matters whether the trade is a buy or a sell.
   double sup = ZoneMapNearestSupport(mid);
   double res = ZoneMapNearestResistance(mid);

   double best_dist = -1.0;
   double best_strength = 0.0;
   if(sup > 0.0)
   {
      // FIX(momentum-wall-negative-dist, same class): MathAbs - ZoneMapNearestSupport() may return
      // a level slightly above mid (V243 tolerance). The comment above says "in either direction",
      // and a signed distance silently dropped that level out of the comparison entirely.
      double d = MathAbs(mid - sup) / _Point;
      if(d >= 0.0) { best_dist = d; best_strength = ZoneMapStrengthByTouches(sup); }
   }
   if(res > 0.0)
   {
      // FIX(momentum-wall-negative-dist, same class): mirror of the support line above - the
      // resistance scan can now return a level just below mid, and a signed distance would drop it
      // out of the comparison entirely.
      double d = MathAbs(res - mid) / _Point;
      if(d >= 0.0 && (best_dist < 0.0 || d < best_dist))
      {
         best_dist = d;
         best_strength = ZoneMapStrengthByTouches(res);
      }
   }

   if(best_dist < 0.0)
      return CandleRelevanceFloor;

   double reach = ScaleAdjustedPoints(MathMax(1, CandleRelevanceReachPoints));
   if(best_dist > reach)
   {
      detail = "candles in open space - reduced weight";
      return CandleRelevanceFloor;
   }

   double proximity = 1.0 - (best_dist / MathMax(1.0, reach));
   double str_factor = MathMin(1.0, best_strength / MathMax(0.1, CandleLocationFullStrength));

   double rel = CandleRelevanceFloor +
                (CandleRelevanceCeiling - CandleRelevanceFloor) * proximity * (0.4 + 0.6 * str_factor);

   detail = StringFormat("candles %.0f%% weight (%.0f pts from a %.2f level)",
                         rel * 100.0, best_dist, best_strength);
   return MathMax(CandleRelevanceFloor, MathMin(CandleRelevanceCeiling, rel));
}

// --- reading the disagreement -------------------------------------------------

// Compares the candle readings against each other. A conflict between them is often
// more informative than either reading alone, because it names a transition.
//   dir    - direction the resolved conflict favours
//   weight - 0..1
int CandleConflictRead(int &dir, double &weight, string &detail)
{
   dir = 0;
   weight = 0.0;
   detail = "";

   if(!EnableCandleConflict)
      return CCONF_NONE;

   // Closed-bar reading.
   int    seq_dir = 0;
   double seq_conf = 0.0;
   string seq_detail = "";
   int    seq_state = CandleSequenceRead(seq_dir, seq_conf, seq_detail);

   // Intra-bar reading.
   int    evo_dir = 0;
   double evo_w = 0.0;
   string evo_detail = "";
   int    evo = LiveBarEvolution(evo_dir, evo_w, evo_detail);

   if(evo == LIVE_EVO_NONE)
      return CCONF_NONE;

   // A rejection that was then traded through. This is the case worth naming: the
   // closed bars said a level was being defended, and the live bar says the defence
   // broke. Neither reading alone says that, and summing them cancels both.
   if(seq_state == CANDLE_STATE_REJECTION && evo == LIVE_EVO_WICK_FAILED &&
      evo_dir == -seq_dir && seq_dir != 0)
   {
      dir = evo_dir;                       // the side that won the fight
      weight = MathMin(1.0, evo_w * (0.5 + 0.5 * seq_conf));
      detail = StringFormat("defence broke - %s then %s", seq_detail, evo_detail);
      return CCONF_DEFENCE_BROKE;
   }

   // A push that was read as expansion and then handed back. The move was attempted
   // and met by something larger.
   if(seq_state == CANDLE_STATE_EXPANDING && evo == LIVE_EVO_ABSORBED &&
      evo_dir == -seq_dir && seq_dir != 0)
   {
      dir = evo_dir;
      weight = MathMin(1.0, evo_w * (0.5 + 0.5 * seq_conf));
      detail = StringFormat("push stalled - %s then %s", seq_detail, evo_detail);
      return CCONF_PUSH_STALLED;
   }

   // Plain disagreement with no story behind it. Worth knowing about, because it means
   // the candle layer as a whole is undecided and should not be carrying much weight.
   if(seq_dir != 0 && evo_dir != 0 && seq_dir == -evo_dir)
   {
      dir = 0;
      weight = MathMin(1.0, evo_w);
      detail = "candle readings split";
      return CCONF_SPLIT;
   }

   return CCONF_NONE;
}

// ============================================================================
// V213: HOW THE BAR IS CHANGING - the shape's history, not its snapshot
// ----------------------------------------------------------------------------
// V212 reads the forming bar. It reads it as it is right now, which misses the more
// informative thing: how it GOT there.
//
// A bar showing a long lower wick at forty seconds and no wick at fifty-five did not
// simply change shape - the buyers who defended that low were overrun inside the
// same minute. That is a failed rejection, and it is stronger information than
// either snapshot on its own, because it says something was tried and beaten.
//
// The same applies in reverse: a body growing steadily through the bar is a push
// being sustained; a body that grew and then shrank is a push that was absorbed.
//
// So the live bar is sampled as it forms, and what the EA reads is the DIFFERENCE
// between samples rather than the latest one. Three things are worth naming:
//
//   FAILED REJECTION - a wick that existed and was then traded through.
//   SUSTAINED PUSH   - a body that keeps extending in one direction.
//   ABSORBED PUSH    - a body that extended and then gave it back.
//
// Samples reset at each new bar, since the previous bar's history belongs to the
// previous bar.
// ============================================================================



void LiveSampleReset(const datetime bar_time)
{
   G_LIVE_BAR_TIME = bar_time;
   G_LIVE_S_COUNT = 0;
   G_LIVE_S_LAST_PROG = 0.0;
   G_LIVE_PEAK_UPPER = 0.0;
   G_LIVE_PEAK_LOWER = 0.0;
   G_LIVE_PEAK_BODY = 0.0;
   G_LIVE_PEAK_BODY_DIR = 0;
}

// Called every tick. Records the forming bar's shape at intervals, so the EA has a
// history to compare against rather than only the current snapshot.
void LiveSampleUpdate()
{
   if(!EnableLiveBarEvolution || _Point <= 0.0)
      return;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   datetime bt = iTime(_Symbol, tf, 0);
   if(bt <= 0)
      return;

   if(bt != G_LIVE_BAR_TIME)
      LiveSampleReset(bt);           // new bar - the old history belongs to the old bar

   double progress = LiveBarProgress(tf);
   if(progress <= 0.0)
      return;

   // Sample at intervals rather than every tick - a hundred samples of the same shape
   // is not more information than five.
   if(G_LIVE_S_COUNT > 0 && (progress - G_LIVE_S_LAST_PROG) < LiveSampleInterval)
      return;

   double o = CandleOpen(tf, 0), c = CandleClose(tf, 0);
   double h = CandleHigh(tf, 0), l = CandleLow(tf, 0);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return;
   double range = h - l;
   if(range <= 0.0)
      return;

   double upper = (h - MathMax(o, c)) / range;
   double lower = (MathMin(o, c) - l) / range;
   double body  = MathAbs(c - o) / range;
   int    bdir  = (c > o) ? 1 : ((c < o) ? -1 : 0);

   // Track the extremes seen at any point - this is what the current shape cannot show.
   if(upper > G_LIVE_PEAK_UPPER) G_LIVE_PEAK_UPPER = upper;
   if(lower > G_LIVE_PEAK_LOWER) G_LIVE_PEAK_LOWER = lower;
   if(body > G_LIVE_PEAK_BODY)   { G_LIVE_PEAK_BODY = body; G_LIVE_PEAK_BODY_DIR = bdir; }

   if(G_LIVE_S_COUNT >= LIVE_SAMPLE_SLOTS)
   {
      for(int k = 1; k < LIVE_SAMPLE_SLOTS; k++)
      {
         G_LIVE_S_UPPER[k-1] = G_LIVE_S_UPPER[k];
         G_LIVE_S_LOWER[k-1] = G_LIVE_S_LOWER[k];
         G_LIVE_S_BODY[k-1]  = G_LIVE_S_BODY[k];
         G_LIVE_S_CLOSE[k-1] = G_LIVE_S_CLOSE[k];
         G_LIVE_S_PROG[k-1]  = G_LIVE_S_PROG[k];
         G_LIVE_S_DIR[k-1]   = G_LIVE_S_DIR[k];
      }
      G_LIVE_S_COUNT = LIVE_SAMPLE_SLOTS - 1;
   }

   int idx = G_LIVE_S_COUNT;
   G_LIVE_S_UPPER[idx] = upper;
   G_LIVE_S_LOWER[idx] = lower;
   G_LIVE_S_BODY[idx]  = body;
   G_LIVE_S_CLOSE[idx] = c;
   G_LIVE_S_PROG[idx]  = progress;
   G_LIVE_S_DIR[idx]   = bdir;
   G_LIVE_S_COUNT++;
   G_LIVE_S_LAST_PROG = progress;
}


string LiveEvolutionName(const int e)
{
   switch(e)
   {
      case LIVE_EVO_WICK_FAILED: return "wick failed";
      case LIVE_EVO_SUSTAINED:   return "sustained push";
      case LIVE_EVO_ABSORBED:    return "push absorbed";
   }
   return "none";
}

// What has changed within this bar?
//   dir    - the direction the change favours
//   weight - 0..1, scaled by how much of the bar has formed
int LiveBarEvolution(int &dir, double &weight, string &detail)
{
   dir = 0;
   weight = 0.0;
   detail = "";

   if(!EnableLiveBarEvolution || G_LIVE_S_COUNT < 3)
      return LIVE_EVO_NONE;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double progress = LiveBarProgress(tf);
   if(progress < LiveBarMinProgress)
      return LIVE_EVO_NONE;

   int last = G_LIVE_S_COUNT - 1;
   double up_now = G_LIVE_S_UPPER[last];
   double lo_now = G_LIVE_S_LOWER[last];
   double body_now = G_LIVE_S_BODY[last];
   int    dir_now = G_LIVE_S_DIR[last];

   double p_norm = (progress - LiveBarMinProgress) / MathMax(0.01, 1.0 - LiveBarMinProgress);
   double base_w = MathMax(0.0, MathMin(1.0, p_norm * p_norm));

   // --- a wick that existed and is now gone ---------------------------------
   // The strongest of the three: someone defended that extreme and was overrun inside
   // the same bar. The current shape shows none of this.
   double lost_lower = G_LIVE_PEAK_LOWER - lo_now;
   double lost_upper = G_LIVE_PEAK_UPPER - up_now;

   if(lost_lower >= LiveWickFailedDrop && G_LIVE_PEAK_LOWER >= LiveWickFailedMinPeak)
   {
      // A lower wick was there and has been traded through - buyers lost that low.
      dir = -1;
      weight = base_w * MathMin(1.0, lost_lower / MathMax(0.01, G_LIVE_PEAK_LOWER));
      detail = StringFormat("lower wick failed (%.0f%% -> %.0f%%)",
                            G_LIVE_PEAK_LOWER * 100.0, lo_now * 100.0);
      return LIVE_EVO_WICK_FAILED;
   }
   if(lost_upper >= LiveWickFailedDrop && G_LIVE_PEAK_UPPER >= LiveWickFailedMinPeak)
   {
      dir = 1;
      weight = base_w * MathMin(1.0, lost_upper / MathMax(0.01, G_LIVE_PEAK_UPPER));
      detail = StringFormat("upper wick failed (%.0f%% -> %.0f%%)",
                            G_LIVE_PEAK_UPPER * 100.0, up_now * 100.0);
      return LIVE_EVO_WICK_FAILED;
   }

   // --- body growing or giving back ------------------------------------------
   double body_lost = G_LIVE_PEAK_BODY - body_now;
   if(body_lost >= LiveBodyAbsorbedDrop && G_LIVE_PEAK_BODY >= LiveBodyMinPeak &&
      G_LIVE_PEAK_BODY_DIR != 0)
   {
      // The push extended and then handed it back - somebody was on the other side.
      dir = -G_LIVE_PEAK_BODY_DIR;
      weight = base_w * MathMin(1.0, body_lost / MathMax(0.01, G_LIVE_PEAK_BODY));
      detail = StringFormat("%s push absorbed (body %.0f%% -> %.0f%%)",
                            (G_LIVE_PEAK_BODY_DIR > 0 ? "bullish" : "bearish"),
                            G_LIVE_PEAK_BODY * 100.0, body_now * 100.0);
      return LIVE_EVO_ABSORBED;
   }

   // Body extending steadily across the samples, in one direction throughout.
   if(dir_now != 0 && body_now >= LiveBodyMinPeak)
   {
      bool steady = true;
      for(int k = MathMax(0, last - 2); k <= last; k++)
      {
         if(G_LIVE_S_DIR[k] != dir_now) { steady = false; break; }
      }
      double growth = body_now - G_LIVE_S_BODY[MathMax(0, last - 2)];
      if(steady && growth >= LiveBodyGrowthMin)
      {
         dir = dir_now;
         weight = base_w * MathMin(1.0, growth / MathMax(0.01, LiveBodyGrowthMin) * 0.5);
         detail = StringFormat("%s push sustained (body +%.0f%%)",
                               (dir_now > 0 ? "bullish" : "bearish"), growth * 100.0);
         return LIVE_EVO_SUSTAINED;
      }
   }

   return LIVE_EVO_NONE;
}

// Is price approaching a level right now, within this bar? Returns the level, or 0.
double LiveApproachingLevel(const int dir, double &distance_pts, string &detail)
{
   distance_pts = 0.0;
   detail = "";

   if(!EnableLiveApproach || dir == 0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   // The level ahead in the direction the trade would travel.
   double level = (dir > 0) ? ZoneMapNearestResistance(mid) : ZoneMapNearestSupport(mid);
   if(level <= 0.0)
      return 0.0;

   distance_pts = MathAbs(level - mid) / _Point;
   double reach = ScaleAdjustedPoints(MathMax(1, LiveApproachPoints));
   if(distance_pts > reach)
      return 0.0;

   double strength = ZoneMapStrengthByTouches(level);
   if(strength < LiveApproachMinStrength)
      return 0.0;

   detail = StringFormat("%.0f pts from %s at %.2f (strength %.2f)",
                         distance_pts, (dir > 0 ? "resistance" : "support"), level, strength);
   return level;
}

// ============================================================================
// V212: THE CANDLE THAT IS STILL FORMING
// ----------------------------------------------------------------------------
// Every reading so far waits for the bar to close. That is correct and safe, and it
// costs the EA a full minute: by the time an M1 rejection is confirmed, the move it
// signalled has been running for sixty seconds. On a scalper that is most of the
// opportunity.
//
// The forming bar carries the same information earlier - a long upper wick at thirty
// seconds is a rejection in progress. The problem is that it is not yet a fact: a
// wick at thirty seconds can be gone at fifty-five, because price came back and the
// bar closed at its high instead.
//
// So the forming bar is read, and the reading is weighted by how much of the bar has
// elapsed. Early in the bar the shape means almost nothing and is treated that way;
// near the close it is nearly a closed candle and treated as such. Nothing acts on
// the live bar alone - it adjusts a decision the closed bars already support, which
// is the difference between reading early and guessing.
// ============================================================================

// How far through the current bar are we? 0.0 at the open, 1.0 at the close.
double LiveBarProgress(const ENUM_TIMEFRAMES tf)
{
   int secs = PeriodSeconds(tf);
   if(secs <= 0)
      return 0.0;
   datetime bar_open = iTime(_Symbol, tf, 0);
   if(bar_open <= 0)
      return 0.0;
   double elapsed = (double)(TimeCurrent() - bar_open);
   return MathMax(0.0, MathMin(1.0, elapsed / (double)secs));
}

// Reads the bar currently forming.
//   dir      - which way it is shaping (0 = nothing readable)
//   weight   - 0..1, how much this reading deserves to count
//   returns the same CANDLE_STATE_* vocabulary as the closed-bar reader
int LiveBarRead(int &dir, double &weight, string &detail)
{
   dir = 0;
   weight = 0.0;
   detail = "";

   if(!EnableLiveBarRead || _Point <= 0.0)
      return CANDLE_STATE_NEUTRAL;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double progress = LiveBarProgress(tf);

   // Too early to mean anything. A bar that is 20% formed has had time for one push
   // in one direction, which is not a shape.
   if(progress < LiveBarMinProgress)
      return CANDLE_STATE_NEUTRAL;

   double o = CandleOpen(tf, 0), c = CandleClose(tf, 0);
   double h = CandleHigh(tf, 0), l = CandleLow(tf, 0);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return CANDLE_STATE_NEUTRAL;

   double range = h - l;
   if(range <= 0.0)
      return CANDLE_STATE_NEUTRAL;

   // The bar also has to be big enough to be saying something. A tick-sized range at
   // 60% through is a quiet bar, not a signal.
   double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
   if(atr > 0.0 && (range / atr) < LiveBarMinSizeATR)
      return CANDLE_STATE_NEUTRAL;

   double body  = MathAbs(c - o) / range;
   double upper = (h - MathMax(o, c)) / range;
   double lower = (MathMin(o, c) - l) / range;
   int    bar_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);

   int state = CANDLE_STATE_NEUTRAL;

   if(MathMax(upper, lower) >= CandleRejectionWickRatio && body <= 0.5)
   {
      state = CANDLE_STATE_REJECTION;
      dir = (lower > upper) ? 1 : -1;      // the side the wick was refused FROM
   }
   else if(body >= LiveBarStrongBody && bar_dir != 0)
   {
      state = CANDLE_STATE_EXPANDING;
      dir = bar_dir;
   }
   else if(body <= CandleAuthorshipIndecisionBody &&
           upper >= 0.25 && lower >= 0.25)
   {
      state = CANDLE_STATE_ABSORPTION;     // both sides active, neither winning
      dir = 0;
   }

   if(dir == 0 && state != CANDLE_STATE_ABSORPTION)
      return CANDLE_STATE_NEUTRAL;

   // The weight is the point of this whole module. Early in the bar the shape can
   // still reverse completely, so it counts for very little; near the close it is
   // almost a closed candle. Squaring the progress makes the early part of the bar
   // count for much less than the linear share would suggest, which is the honest
   // shape of the uncertainty.
   double p_norm = (progress - LiveBarMinProgress) / MathMax(0.01, 1.0 - LiveBarMinProgress);
   weight = MathMax(0.0, MathMin(1.0, p_norm * p_norm));

   detail = StringFormat("live bar %.0f%% formed: %s %s (weight %.2f)",
                         progress * 100.0, CandleStateName(state),
                         (dir > 0 ? "bullish" : (dir < 0 ? "bearish" : "")), weight);
   return state;
}

// ============================================================================
// V211: PATTERNS IN CONTEXT, GRADED, AND ACROSS TIMEFRAMES
// ----------------------------------------------------------------------------
// Three gaps left by the candle work so far.
//
// WHERE the pattern formed. A morning star at a support that has held is a turn
// beginning at the level that produces turns. The same three candles in open space
// are three candles. V208 answered this for a single wick and never for patterns.
//
// WHETHER patterns actually work here. V209 grades rejections and breaks by what
// followed them; patterns were left ungraded, so the EA trusts them on reputation
// rather than record.
//
// WHICH TIMEFRAME is speaking. The candle reader runs on M1. A bullish engulfing on
// M1 inside a bearish M5 candle is a pullback being read as a reversal - and taking
// the M1 signal against the M5 one is precisely the "strong buy candles then sell"
// mistake. The higher timeframe does not veto the lower; it decides how much the
// lower one is allowed to mean.
// ============================================================================

// Did this pattern form at a level, and how much does that level matter?
// Returns 0.0 (open space) to 1.0 (at a level that has held repeatedly).
double CandlePatternLocation(const int pat_dir, double &level_out, string &detail)
{
   level_out = 0.0;
   detail = "";

   if(!EnablePatternLocation || pat_dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;

   // A reversal pattern is anchored at the extreme it turned from - the low of the
   // three bars for an upward turn, the high for a downward one.
   double anchor = 0.0;
   for(int i = 1; i <= 3; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0)
         return 0.0;
      if(pat_dir > 0) anchor = (anchor == 0.0) ? l : MathMin(anchor, l);
      else            anchor = (anchor == 0.0) ? h : MathMax(anchor, h);
   }
   if(anchor <= 0.0)
      return 0.0;

   double level = (pat_dir > 0) ? ZoneMapNearestSupport(anchor + (10.0 * _Point))
                                : ZoneMapNearestResistance(anchor - (10.0 * _Point));
   if(level <= 0.0)
      return 0.0;

   double dist = MathAbs(anchor - level) / _Point;
   double tol = ScaleAdjustedPoints(MathMax(1, PatternLocationTolerancePoints));
   if(dist > tol)
      return 0.0;

   double proximity = 1.0 - (dist / MathMax(1.0, tol));
   double strength = ZoneMapStrengthByTouches(level);
   double str_factor = MathMin(1.0, strength / MathMax(0.1, CandleLocationFullStrength));

   level_out = level;
   detail = StringFormat("at %.2f (strength %.2f)", level, strength);
   return MathMax(0.0, MathMin(1.0, proximity * (0.35 + 0.65 * str_factor)));
}

// --- pattern outcome tracking -------------------------------------------------
// Same idea as the rejection/break grading: record the pattern, judge it later.
// (G_PAT_* declared with the other candle state above - the persistence helpers read them)

void PatternJudgeArm(const int pat, const int dir, const double price)
{
   if(!EnablePatternGrading || pat <= 0 || pat >= 8 || dir == 0 || price <= 0.0)
      return;
   if(G_PAT_JUDGE_TYPE != 0)
      return;                       // already watching one - do not stack
   G_PAT_JUDGE_TYPE  = pat;
   G_PAT_JUDGE_DIR   = dir;
   G_PAT_JUDGE_PRICE = price;
   G_PAT_JUDGE_BAR   = G_BARS_SEEN;
}

void PatternJudgeSettle()
{
   if(!EnablePatternGrading || G_PAT_JUDGE_TYPE == 0 || _Point <= 0.0)
      return;
   if((G_BARS_SEEN - G_PAT_JUDGE_BAR) < MathMax(3, PatternGradeHorizonBars))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double moved = (mid - G_PAT_JUDGE_PRICE) / _Point * (double)G_PAT_JUDGE_DIR;
   int p = G_PAT_JUDGE_TYPE;

   if(moved >= (double)PatternGradeWinPoints) G_PAT_WON[p]  += 1.0;
   else if(moved <= -(double)PatternGradeWinPoints) G_PAT_LOST[p] += 1.0;
   // Anything in between is neither - the pattern neither worked nor failed, and
   // counting it either way would be inventing a result.

   double total = G_PAT_WON[p] + G_PAT_LOST[p];
   if(total > (double)PatternGradeMaxSamples)
   {
      double sc = (double)PatternGradeMaxSamples / total;
      G_PAT_WON[p] *= sc; G_PAT_LOST[p] *= sc;
   }

   if((PatternGradePrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v211 PATTERN GRADE] %s -> %.0f pts | record %.0f/%.0f",
                  CandlePatternName(p), moved, G_PAT_WON[p], G_PAT_LOST[p]);

   G_PAT_JUDGE_TYPE = 0;
}

// How has this pattern been resolving here? -1 when there is no record yet.
double PatternWinRate(const int pat)
{
   if(!EnablePatternGrading || pat <= 0 || pat >= 8)
      return -1.0;
   double total = G_PAT_WON[pat] + G_PAT_LOST[pat];
   if(total < (double)PatternGradeMinSamples)
      return -1.0;
   return G_PAT_WON[pat] / total;
}

// --- higher timeframe agreement ------------------------------------------------
// What is the candle on the higher timeframe doing, and does the lower-timeframe
// reading sit inside it or against it?
//   returns +1 agree, 0 neutral, -1 the lower reading contradicts the higher candle
int CandleHTFAgreement(const int lower_dir, double &htf_body, string &detail)
{
   htf_body = 0.0;
   detail = "";

   if(!EnableCandleHTF || lower_dir == 0)
      return 0;

   ENUM_TIMEFRAMES htf = CandleHTFTimeframe;
   double o = CandleOpen(htf, 1), c = CandleClose(htf, 1);
   double h = CandleHigh(htf, 1), l = CandleLow(htf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0;

   double range = h - l;
   if(range <= 0.0)
      return 0;

   int    htf_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);
   htf_body = MathAbs(c - o) / range;

   if(htf_dir == 0 || htf_body < CandleHTFMinBody)
   {
      detail = "higher timeframe undecided";
      return 0;                     // the higher candle is not saying anything either
   }

   // A forming higher-timeframe candle also matters - if the current H1/M5 bar is
   // strongly one way, an M1 signal against it is a pullback, not a turn.
   double o0 = CandleOpen(htf, 0), c0 = CandleClose(htf, 0);
   double h0 = CandleHigh(htf, 0), l0 = CandleLow(htf, 0);
   int    live_dir = 0;
   // PACKAGE 3 (B-F13): only once the forming bar has some size - in its first ticks a 2-point range
   // with a 2-point body read as a "strong" candle and overruled the closed one.
   if(o0 > 0.0 && c0 > 0.0 && h0 > l0 && (h0 - l0) >= 0.5 * range)
   {
      double live_body = MathAbs(c0 - o0) / (h0 - l0);
      if(live_body >= CandleHTFMinBody)
         live_dir = (c0 > o0) ? 1 : ((c0 < o0) ? -1 : 0);
   }

   int effective = (live_dir != 0) ? live_dir : htf_dir;

   if(effective == lower_dir)
   {
      detail = StringFormat("%s candle agrees (body %.0f%%)",
                            EnumToString(htf), htf_body * 100.0);
      return 1;
   }

   detail = StringFormat("%s candle is %s (body %.0f%%) - the lower reading is a pullback",
                         EnumToString(htf), (effective > 0 ? "bullish" : "bearish"),
                         htf_body * 100.0);
   return -1;
}

// ============================================================================
// V210: PARTICIPATION, THE OPENING GAP, AND MULTI-CANDLE PATTERNS
// ----------------------------------------------------------------------------
// Three readings the candle engine could not make.
//
// PARTICIPATION. A large candle on heavy tick volume is a market that showed up; the
// same candle on thin volume is a few orders moving an empty book, and it retraces
// as easily as it came. On XAUUSD this distinction separates a real push from an
// Asian-session drift that merely looks like one.
//
// THE OPENING GAP. Where a candle opens relative to the previous close says what
// happened between them. Opening above and closing below means the market gapped up
// and was sold into - weakness that the candle's own shape does not show, because
// the body only measures open to close.
//
// MULTI-CANDLE PATTERNS. The EA reads one candle, or a run of same-direction ones.
// It cannot see the shapes that need two or three bars in a specific arrangement -
// and those are the ones that mark turns rather than continuations. They are the
// natural confirmation for a setup that is waiting: a morning star at the level a
// trade is armed against says the turn has begun.
// ============================================================================

// How much participation was behind the recent candle, relative to what is normal
// here? 1.0 = typical, above 1 = heavier than usual, below = thinner.
double CandleParticipation(const int shift)
{
   if(!EnableCandleParticipation)
      return 1.0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   long v = iVolume(_Symbol, tf, shift);
   if(v <= 0)
      return 1.0;

   long sum = 0;
   int n = 0;
   int look = MathMax(5, CandleParticipationLookback);
   for(int i = shift + 1; i <= shift + look; i++)
   {
      long vi = iVolume(_Symbol, tf, i);
      if(vi <= 0)
         continue;
      sum += vi;
      n++;
   }
   if(n < 3 || sum <= 0)
      return 1.0;

   double avg = (double)sum / (double)n;
   if(avg <= 0.0)
      return 1.0;

   return MathMax(0.1, MathMin(4.0, (double)v / avg));
}

// Where did the candle open relative to the previous close, and what did it do from
// there? Returns -1..+1: positive means the session opened and was bought, negative
// means it opened and was sold.
double CandleOpeningBias(string &detail)
{
   detail = "";
   if(!EnableCandleOpeningBias || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double prev_c = CandleClose(tf, 2);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || prev_c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0.0;

   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   double gap_pts = (o - prev_c) / _Point;
   if(MathAbs(gap_pts) < (double)CandleOpeningMinGapPoints)
      return 0.0;                    // opened where it closed - nothing to read

   // Opened higher and closed lower (or the reverse) is the case worth naming: the
   // gap was rejected. The body alone cannot show this, since it starts at the open.
   double from_open = (c - o) / range;
   double bias = 0.0;

   if(gap_pts > 0.0 && from_open < 0.0)
   {
      bias = from_open;              // gapped up, sold into - negative
      detail = StringFormat("gapped up %.0f pts and was sold", gap_pts);
   }
   else if(gap_pts < 0.0 && from_open > 0.0)
   {
      bias = from_open;              // gapped down, bought - positive
      detail = StringFormat("gapped down %.0f pts and was bought", -gap_pts);
   }
   else if(gap_pts > 0.0 && from_open > 0.0)
   {
      bias = from_open * CandleOpeningContinuationFactor;
      detail = StringFormat("gapped up %.0f pts and continued", gap_pts);
   }
   else if(gap_pts < 0.0 && from_open < 0.0)
   {
      bias = from_open * CandleOpeningContinuationFactor;
      detail = StringFormat("gapped down %.0f pts and continued", -gap_pts);
   }

   return MathMax(-1.0, MathMin(1.0, bias));
}

// --- multi-candle patterns ---------------------------------------------------
// (CPAT_* defines live at the top of the file with the other structural defines)

string CandlePatternName(const int p)
{
   switch(p)
   {
      case CPAT_MORNING_STAR:   return "morning star";
      case CPAT_EVENING_STAR:   return "evening star";
      case CPAT_THREE_SOLDIERS: return "three soldiers";
      case CPAT_THREE_CROWS:    return "three crows";
      case CPAT_HARAMI:         return "harami";
      case CPAT_TWEEZER:        return "tweezer";
   }
   return "none";
}

// Reads the last three candles for a recognised shape.
//   dir   - the direction the pattern points
//   conf  - 0..1, how cleanly it formed
int CandlePatternRead(int &dir, double &conf, string &detail)
{
   dir = 0;
   conf = 0.0;
   detail = "";

   if(!EnableCandlePatterns || _Point <= 0.0)
      return CPAT_NONE;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double o1 = CandleOpen(tf,1), c1 = CandleClose(tf,1), h1 = CandleHigh(tf,1), l1 = CandleLow(tf,1);
   double o2 = CandleOpen(tf,2), c2 = CandleClose(tf,2), h2 = CandleHigh(tf,2), l2 = CandleLow(tf,2);
   double o3 = CandleOpen(tf,3), c3 = CandleClose(tf,3), h3 = CandleHigh(tf,3), l3 = CandleLow(tf,3);
   if(o1 <= 0.0 || o2 <= 0.0 || o3 <= 0.0)
      return CPAT_NONE;

   double r1 = h1 - l1, r2 = h2 - l2, r3 = h3 - l3;
   if(r1 <= 0.0 || r2 <= 0.0 || r3 <= 0.0)
      return CPAT_NONE;

   double b1 = MathAbs(c1 - o1) / r1;
   double b2 = MathAbs(c2 - o2) / r2;
   double b3 = MathAbs(c3 - o3) / r3;
   int d1 = (c1 > o1) ? 1 : ((c1 < o1) ? -1 : 0);
   int d2 = (c2 > o2) ? 1 : ((c2 < o2) ? -1 : 0);
   int d3 = (c3 > o3) ? 1 : ((c3 < o3) ? -1 : 0);

   double min_body = CandlePatternMinBody;
   double star_body = CandlePatternStarMaxBody;

   // --- star patterns: strong, pause, strong the other way -------------------
   if(d3 != 0 && d1 != 0 && d3 == -d1 && b3 >= min_body && b1 >= min_body && b2 <= star_body)
   {
      // The reversal candle must reclaim a real share of the first one.
      double first_body = MathAbs(c3 - o3);
      double reclaim = (d1 > 0) ? (c1 - o3) : (o3 - c1);
      double share = (first_body > 0.0) ? (reclaim / first_body) : 0.0;

      if(share >= CandlePatternMinReclaim)
      {
         dir = d1;
         conf = MathMin(1.0, share * (0.5 + 0.5 * MathMin(b1, b3)));
         int pat = (d1 > 0) ? CPAT_MORNING_STAR : CPAT_EVENING_STAR;
         detail = StringFormat("%s (reclaimed %.0f%% of the first candle)",
                               CandlePatternName(pat), share * 100.0);
         return pat;
      }
   }

   // --- three in a row with real bodies and progressing closes ---------------
   if(d1 != 0 && d1 == d2 && d2 == d3 &&
      b1 >= min_body && b2 >= min_body && b3 >= min_body)
   {
      bool progressing = (d1 > 0) ? (c1 > c2 && c2 > c3) : (c1 < c2 && c2 < c3);
      if(progressing)
      {
         dir = d1;
         conf = MathMin(1.0, (b1 + b2 + b3) / 3.0);
         int pat = (d1 > 0) ? CPAT_THREE_SOLDIERS : CPAT_THREE_CROWS;
         detail = StringFormat("%s (avg body %.0f%%)", CandlePatternName(pat), conf * 100.0);
         return pat;
      }
   }

   // --- harami: a large bar, then a small one entirely inside its body -------
   if(b2 >= CandlePatternHaramiOuterBody && b1 <= CandlePatternHaramiInnerBody && d2 != 0)
   {
      double outer_hi = MathMax(o2, c2), outer_lo = MathMin(o2, c2);
      if(h1 <= outer_hi && l1 >= outer_lo)
      {
         dir = -d2;                  // momentum ending: points against the large bar
         conf = MathMin(1.0, b2 * (1.0 - b1));
         detail = StringFormat("harami - %s momentum stalling",
                               (d2 > 0 ? "bullish" : "bearish"));
         return CPAT_HARAMI;
      }
   }

   // --- tweezer: two bars refused at the same extreme ------------------------
   {
      double tol = ScaleAdjustedPoints(MathMax(1, CandlePatternTweezerTolerance)) * _Point;
      bool top    = (MathAbs(h1 - h2) <= tol) && (d1 <= 0) && (b1 <= 0.6);
      bool bottom = (MathAbs(l1 - l2) <= tol) && (d1 >= 0) && (b1 <= 0.6);
      if(top || bottom)
      {
         dir = top ? -1 : 1;
         conf = 1.0 - (MathAbs(top ? (h1 - h2) : (l1 - l2)) / MathMax(tol, _Point));
         conf = MathMax(0.2, MathMin(1.0, conf));
         detail = StringFormat("tweezer %s at %.2f", (top ? "top" : "bottom"),
                               (top ? h1 : l1));
         return CPAT_TWEEZER;
      }
   }

   return CPAT_NONE;
}

// ============================================================================
// V209: WHAT HAPPENED NEXT - candles judged by their outcome, not their shape.
// ----------------------------------------------------------------------------
// Every candle reading so far is taken at the moment the bar closes, and then
// forgotten. That is the one moment when the reading is least reliable, because a
// candle only means what the following bars let it mean.
//
// A long lower wick is a rejection - until price trades back through it, at which
// point the buyers who defended that low have been overrun and the "rejection" was
// simply where the bar happened to bottom. A large bullish candle is demand - unless
// the next bars give it all back, in which case it was stops being collected and the
// move was never real.
//
// A break through a level is the clearest case. The EA has been treating "closed
// beyond the level" as the answer, when the honest answer needs the bars after it:
// price that closes through and stays through has broken the level; price that closes
// through and comes straight back has been trapped by it.
//
// So candles are recorded when they form and graded a few bars later. What the EA
// gets is not "this looks like a rejection" but "rejections here have been holding".
// ============================================================================

// (CANDLE_EVENT_SLOTS declared at the top of the file with the other structural defines)

// (G_CE_* declared with the other candle state above)

void CandleEventRecord(const int type, const int dir, const double level)
{
   if(!EnableCandleFollowThrough || dir == 0 || level <= 0.0)
      return;

   // Ring buffer - the oldest is dropped, since a candle from twenty bars ago is
   // history rather than context.
   if(G_CE_COUNT >= CANDLE_EVENT_SLOTS)
   {
      for(int k = 1; k < CANDLE_EVENT_SLOTS; k++)
      {
         G_CE_DIR[k-1] = G_CE_DIR[k];
         G_CE_BAR[k-1] = G_CE_BAR[k];
         G_CE_LEVEL[k-1] = G_CE_LEVEL[k];
         G_CE_TYPE[k-1] = G_CE_TYPE[k];
      }
      G_CE_COUNT = CANDLE_EVENT_SLOTS - 1;
   }

   G_CE_TYPE[G_CE_COUNT]  = type;
   G_CE_DIR[G_CE_COUNT]   = dir;
   G_CE_LEVEL[G_CE_COUNT] = level;
   G_CE_BAR[G_CE_COUNT]   = G_BARS_SEEN;
   G_CE_COUNT++;
}

// Grade the recorded candles whose horizon has passed.
void CandleEventSettle()
{
   if(!EnableCandleFollowThrough || G_CE_COUNT <= 0 || _Point <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   int write = 0;
   for(int i = 0; i < G_CE_COUNT; i++)
   {
      int age = G_BARS_SEEN - G_CE_BAR[i];
      if(age < MathMax(2, CandleFollowThroughBars))
      {
         // Not judged yet - keep it.
         G_CE_TYPE[write] = G_CE_TYPE[i];
         G_CE_DIR[write] = G_CE_DIR[i];
         G_CE_LEVEL[write] = G_CE_LEVEL[i];
         G_CE_BAR[write] = G_CE_BAR[i];
         write++;
         continue;
      }

      double tol = ScaleAdjustedPoints(MathMax(1, CandleFollowThroughTolerance)) * _Point;

      if(G_CE_TYPE[i] == 1)
      {
         // Rejection wick. It held if price never traded back through the tip.
         bool violated = (G_CE_DIR[i] > 0) ? (mid < G_CE_LEVEL[i] - tol)
                                           : (mid > G_CE_LEVEL[i] + tol);
         if(violated) G_CE_REJECT_FAILED += 1.0;
         else         G_CE_REJECT_HELD   += 1.0;

         if((CandleFollowThroughPrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v209 FOLLOW] rejection at %.2f %s after %d bars",
                        G_CE_LEVEL[i], (violated ? "FAILED" : "held"), age);
      }
      else if(G_CE_TYPE[i] == 2)
      {
         // Break. It held if price stayed on the far side of the level.
         bool back_inside = (G_CE_DIR[i] > 0) ? (mid < G_CE_LEVEL[i] - tol)
                                              : (mid > G_CE_LEVEL[i] + tol);
         if(back_inside) G_CE_BREAK_FAILED += 1.0;
         else            G_CE_BREAK_HELD   += 1.0;

         if((CandleFollowThroughPrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v209 FOLLOW] break of %.2f %s after %d bars",
                        G_CE_LEVEL[i], (back_inside ? "FAILED - trapped" : "held"), age);
      }
   }
   G_CE_COUNT = write;

   // Keep the tallies recent - conditions change, and a month-old record describes a
   // market that no longer exists.
   double rej_total = G_CE_REJECT_HELD + G_CE_REJECT_FAILED;
   if(rej_total > (double)CandleFollowThroughMaxSamples)
   {
      double sc = (double)CandleFollowThroughMaxSamples / rej_total;
      G_CE_REJECT_HELD *= sc; G_CE_REJECT_FAILED *= sc;
   }
   double brk_total = G_CE_BREAK_HELD + G_CE_BREAK_FAILED;
   if(brk_total > (double)CandleFollowThroughMaxSamples)
   {
      double sc = (double)CandleFollowThroughMaxSamples / brk_total;
      G_CE_BREAK_HELD *= sc; G_CE_BREAK_FAILED *= sc;
   }
}

// How reliable have rejections been lately? -1 when there is no record yet.
double CandleRejectionReliability()
{
   double total = G_CE_REJECT_HELD + G_CE_REJECT_FAILED;
   if(total < (double)CandleFollowThroughMinSamples)
      return -1.0;
   return G_CE_REJECT_HELD / total;
}

double CandleBreakReliability()
{
   double total = G_CE_BREAK_HELD + G_CE_BREAK_FAILED;
   if(total < (double)CandleFollowThroughMinSamples)
      return -1.0;
   return G_CE_BREAK_HELD / total;
}

// How did this candle cross the level it was aimed at? A close beyond it with a small
// wick is a break; a close beyond it with a long wick against is an attempt that was
// already being pushed back inside the same bar.
//   returns 1 = clean break, 0 = unresolved, -1 = attempted and rejected
int CandleBreakQuality(const double level, const int dir, double &quality, string &detail)
{
   quality = 0.0;
   detail = "";

   if(!EnableCandleBreakQuality || level <= 0.0 || dir == 0 || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0;
   double range = h - l;
   if(range <= 0.0)
      return 0;

   bool closed_beyond = (dir > 0) ? (c > level) : (c < level);
   bool touched       = (dir > 0) ? (h > level) : (l < level);

   if(!touched)
      return 0;                      // never reached it

   if(!closed_beyond)
   {
      // Reached it and closed back inside - the level did its job.
      double push = (dir > 0) ? (h - level) : (level - l);
      quality = MathMin(1.0, push / range);
      detail = StringFormat("tested %.2f and closed back inside", level);
      return -1;
   }

   // Closed beyond. How much of the bar is left ON the far side?
   double beyond = (dir > 0) ? (c - level) : (level - c);
   double wick_back = (dir > 0) ? (h - c) : (c - l);      // wick past the close
   double body = MathAbs(c - o) / range;

   double clean = (beyond / range) * (0.5 + 0.5 * body);
   if(range > 0.0)
      clean -= (wick_back / range) * CandleBreakWickPenaltyWeight;

   quality = MathMax(0.0, MathMin(1.0, clean));

   if(quality >= CandleBreakCleanMin)
   {
      detail = StringFormat("clean break of %.2f (%.0f%% beyond, body %.0f%%)",
                            level, (beyond / range) * 100.0, body * 100.0);
      return 1;
   }

   detail = StringFormat("weak break of %.2f - long wick back (%.0f%%)",
                         level, (wick_back / range) * 100.0);
   return 0;
}

// ============================================================================
// V208: WHERE the candle happened, and WHOSE wick it is.
// ----------------------------------------------------------------------------
// Two things the candle reader could not distinguish, both of which change the
// meaning entirely.
//
// LOCATION. A long lower wick at a support is sellers being refused at a level
// that has refused them before - the strongest single bar signal there is. The
// identical candle in open space is noise: price dipped, someone bought, nothing
// was defended. The shape is the same; only one of them is information.
//
// AUTHORSHIP. A long upper wick on a BULLISH candle means buyers pushed up and
// were turned back - a warning for buyers. The same wick on a BEARISH candle means
// sellers drove price down from a high - confirmation for sellers. Reading "upper
// wick" without reading the body treats these as one thing when they are opposites.
//
// Both are reported separately from the sequence state, so they refine the reading
// rather than compete with it.
// ============================================================================

// How much does this candle's rejection matter, given where it happened?
// Returns 0.0 (nowhere in particular) to 1.0 (right at a level that has held).
double CandleLocationWeight(const int wick_dir, double &level_out, string &detail)
{
   level_out = 0.0;
   detail = "";

   if(!EnableCandleLocation || wick_dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(h <= 0.0 || l <= 0.0)
      return 0.0;

   // The wick's tip is what touched the level - not the close, not the body.
   double tip = (wick_dir > 0) ? l : h;

   double level = (wick_dir > 0) ? ZoneMapNearestSupport(tip + (10.0 * _Point))
                                 : ZoneMapNearestResistance(tip - (10.0 * _Point));
   if(level <= 0.0)
      return 0.0;

   double dist_pts = MathAbs(tip - level) / _Point;
   double tol = ScaleAdjustedPoints(MathMax(1, CandleLocationTolerancePoints));
   if(dist_pts > tol)
      return 0.0;                    // the wick reached nothing in particular

   // Closer to the level and a stronger level both make the rejection mean more.
   double proximity = 1.0 - (dist_pts / MathMax(1.0, tol));
   double strength = ZoneMapStrengthByTouches(level);
   double str_factor = MathMin(1.0, strength / MathMax(0.1, CandleLocationFullStrength));

   level_out = level;
   double weight = proximity * (0.4 + 0.6 * str_factor);

   detail = StringFormat("wick tested %.2f (%.0f pts away, strength %.2f)",
                         level, dist_pts, strength);
   return MathMax(0.0, MathMin(1.0, weight));
}

// Whose wick is it? A wick against the candle's own body is a rejection of that
// candle's direction; a wick in line with it is the move being driven from an extreme.
//   returns  +1 when the wick supports buyers, -1 when it supports sellers, 0 when neutral
int CandleWickAuthorship(double &conviction, string &detail)
{
   conviction = 0.0;
   detail = "";

   if(!EnableCandleAuthorship)
      return 0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0;

   double range = h - l;
   if(range <= 0.0)
      return 0;

   double upper = (h - MathMax(o, c)) / range;
   double lower = (MathMin(o, c) - l) / range;
   double body  = MathAbs(c - o) / range;
   int    candle_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);

   // Which wick dominates, and is it long enough to say anything?
   int wick_side = 0;
   double wick_size = 0.0;
   if(upper >= lower + CandleAuthorshipMinDominance) { wick_side = -1; wick_size = upper; }
   else if(lower >= upper + CandleAuthorshipMinDominance) { wick_side = 1; wick_size = lower; }

   if(wick_side == 0 || wick_size < CandleAuthorshipMinWick)
   {
      // Two comparable wicks with a small body is indecision, and worth naming as such:
      // both sides tried and neither finished in control.
      if(body <= CandleAuthorshipIndecisionBody &&
         upper >= CandleAuthorshipMinWick * 0.6 && lower >= CandleAuthorshipMinWick * 0.6)
      {
         detail = StringFormat("both sides rejected (%.0f%% up / %.0f%% down wick, body %.0f%%)",
                               upper * 100.0, lower * 100.0, body * 100.0);
         conviction = 0.0;
         return 0;
      }
      return 0;
   }

   // A wick against the candle's own direction is the more meaningful case: the move was
   // attempted and taken back within the same bar. In line with the body it is weaker -
   // the extreme was simply where the bar started from.
   bool against_body = (candle_dir != 0 && wick_side == -candle_dir);
   conviction = wick_size * (against_body ? 1.0 : CandleAuthorshipAlignedFactor);
   conviction = MathMin(1.0, conviction * (0.5 + 0.5 * body));

   detail = StringFormat("%s wick on a %s candle - %s (%.0f%%)",
                         (wick_side > 0 ? "lower" : "upper"),
                         (candle_dir > 0 ? "bullish" : "bearish"),
                         (against_body ? "move taken back" : "driven from the extreme"),
                         wick_size * 100.0);
   return wick_side;
}

// ============================================================================

// (CANDLE_STATE_* defines live at the top of the file with the other structural defines)

string CandleStateName(const int st)
{
   switch(st)
   {
      case CANDLE_STATE_EXPANDING:   return "expanding";
      case CANDLE_STATE_CONTRACTING: return "contracting";
      case CANDLE_STATE_INSIDE:      return "inside";
      case CANDLE_STATE_REJECTION:   return "rejection";
      case CANDLE_STATE_ABSORPTION:  return "absorption";
   }
   return "neutral";
}

// Reads the recent candles as a sequence.
//   dir    - the direction the sequence favours (0 = none)
//   conf   - how strongly, 0..1
//   returns the state that best describes what the bars are doing.
int CandleSequenceRead(int &dir, double &conf, string &detail)
{
   dir = 0;
   conf = 0.0;
   detail = "";

   if(!EnableCandleSequence || _Point <= 0.0)
      return CANDLE_STATE_NEUTRAL;

   static int    cs_bar = -100000;
   static int    cs_state = CANDLE_STATE_NEUTRAL;
   static int    cs_dir = 0;
   static double cs_conf = 0.0;
   static string cs_detail = "";
   if(cs_bar > G_BARS_SEEN) cs_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(cs_bar == G_BARS_SEEN)
   {
      dir = cs_dir; conf = cs_conf; detail = cs_detail;
      return cs_state;
   }

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   int look = MathMax(3, MathMin(8, CandleSequenceBars));

   double rng[8], body[8], upper[8], lower[8], close_pos[8];
   int    bar_dir[8];
   int n = 0;

   for(int i = 1; i <= look && n < 8; i++)
   {
      double o = CandleOpen(tf, i), c = CandleClose(tf, i);
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         break;
      double r = h - l;
      if(r <= 0.0)
         break;

      rng[n]       = r;
      body[n]      = MathAbs(c - o) / r;
      upper[n]     = (h - MathMax(o, c)) / r;
      lower[n]     = (MathMin(o, c) - l) / r;
      close_pos[n] = ((c - l) / r) * 2.0 - 1.0;    // -1 at the low, +1 at the high
      bar_dir[n]   = (c > o) ? 1 : ((c < o) ? -1 : 0);
      n++;
   }

   if(n < 3)
      return CANDLE_STATE_NEUTRAL;

   double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
   double rel_size = (atr > 0.0) ? (rng[0] / atr) : 1.0;

   // --- what shape is the sequence? -----------------------------------------
   // Compare the newest bar's range against the ones before it. Growing ranges mean
   // the move is being driven; shrinking ones mean it is running out of participants.
   double older_avg = 0.0;
   for(int k = 1; k < n; k++)
      older_avg += rng[k];
   older_avg /= (double)(n - 1);
   double size_ratio = (older_avg > 0.0) ? (rng[0] / older_avg) : 1.0;

   int state = CANDLE_STATE_NEUTRAL;

   // Inside bar: contained by the previous one. A pause - and what it means depends
   // entirely on what preceded it, which is why it is reported rather than judged.
   double h0 = CandleHigh(tf, 1), l0 = CandleLow(tf, 1);
   double h1 = CandleHigh(tf, 2), l1 = CandleLow(tf, 2);
   bool is_inside = (h0 > 0.0 && h1 > 0.0 && h0 <= h1 && l0 >= l1);

   if(is_inside)
      state = CANDLE_STATE_INSIDE;
   else if(rng[0] >= older_avg * CandleAbsorptionSizeRatio && body[0] <= CandleAbsorptionMaxBody)
      state = CANDLE_STATE_ABSORPTION;   // big range, little body: effort, no result
   else if(MathMax(upper[0], lower[0]) >= CandleRejectionWickRatio && body[0] <= 0.5)
      state = CANDLE_STATE_REJECTION;
   else if(size_ratio >= CandleExpansionRatio)
      state = CANDLE_STATE_EXPANDING;
   else if(size_ratio <= CandleContractionRatio)
      state = CANDLE_STATE_CONTRACTING;

   // --- which way does the sequence lean? ------------------------------------
   // Weight the close positions: where a bar closed within its own range is the
   // cleanest statement of who finished it in control.
   double lean = 0.0, wsum = 0.0;
   for(int k = 0; k < n; k++)
   {
      double w = 1.0 / (1.0 + (double)k * 0.6);      // newest bars weigh most
      lean += close_pos[k] * (0.5 + 0.5 * body[k]) * w;
      wsum += w;
   }
   if(wsum > 0.0)
      lean /= wsum;

   // Rejection points the way the wick was NOT - a long lower wick is buyers.
   if(state == CANDLE_STATE_REJECTION)
   {
      if(lower[0] > upper[0]) lean = MathMax(lean,  lower[0]);
      else                    lean = MathMin(lean, -upper[0]);
   }

   if(MathAbs(lean) >= CandleSequenceMinLean)
   {
      dir = (lean > 0.0) ? 1 : -1;
      conf = MathMin(1.0, MathAbs(lean));
   }

   detail = StringFormat("candles: %s, %s (lean %+.2f, size %.1fx, %.1f ATR)",
                         CandleStateName(state),
                         (dir > 0 ? "bullish" : (dir < 0 ? "bearish" : "undecided")),
                         lean, size_ratio, rel_size);

   cs_bar = G_BARS_SEEN;
   cs_state = state; cs_dir = dir; cs_conf = conf; cs_detail = detail;
   return state;
}

// V204: consecutive closing pressure - reading the candles themselves rather than the distance
// they covered.
//
// RecentThrustDir() asks whether price travelled $3 in fifteen bars. That catches a fast run, but
// misses the pattern that has been costing entries: three or four strong candles closing in the
// same direction, one after another, covering a dollar or two. The distance is unremarkable; the
// SEQUENCE is not. Bodies stacking in one direction with little rejection is a market being pushed,
// and the wrong moment to take the other side.
//
// This reads the shape directly: how many of the last few candles closed the same way, how much of
// each bar was body rather than wick, and whether the closes are progressing. It is deliberately a
// short lookback - four candles of genuine pressure is a live push, while the same four an hour ago
// is history.
//
// Returns the direction being pushed, or 0 when there is no run worth naming.
int ConsecutivePressureDir(int &run_len, double &avg_body, string &detail)
{
   run_len = 0;
   avg_body = 0.0;
   detail = "";

   if(!EnableConsecutivePressure)
      return 0;

   ENUM_TIMEFRAMES tf = ConsecutivePressureTF;
   int look = MathMax(2, MathMin(10, ConsecutivePressureLookback));

   int dir = 0;
   double body_sum = 0.0;
   int counted = 0;

   for(int i = 1; i <= look; i++)
   {
      double o = CandleOpen(tf, i);
      double c = CandleClose(tf, i);
      double h = CandleHigh(tf, i);
      double l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         break;

      double range = h - l;
      if(range <= 0.0)
         break;

      int bar_dir = (c > o) ? 1 : ((c < o) ? -1 : 0);
      if(bar_dir == 0)
         break;                       // a doji ends the run - nobody is pushing

      double body_ratio = MathAbs(c - o) / range;
      if(body_ratio < ConsecutivePressureMinBody)
         break;                       // mostly wick: attempted, not achieved

      if(dir == 0)
         dir = bar_dir;
      else if(bar_dir != dir)
         break;                       // the run has ended

      body_sum += body_ratio;
      counted++;
   }

   if(dir == 0 || counted < MathMax(2, ConsecutivePressureMinRun))
      return 0;

   run_len = counted;
   avg_body = body_sum / (double)counted;

   // The run also has to have gone somewhere - four small bodies in a tight range are consistent
   // but not forceful.
   double c_now = CandleClose(tf, 1);
   double o_start = CandleOpen(tf, counted);
   if(c_now <= 0.0 || o_start <= 0.0 || _Point <= 0.0)
      return 0;
   double covered = MathAbs(c_now - o_start) / _Point;
   if(covered < (double)ConsecutivePressureMinPoints)
      return 0;

   detail = StringFormat("%d %s candles closing through (avg body %.0f%%, %.0f pts)",
                         counted, (dir > 0 ? "bullish" : "bearish"), avg_body * 100.0, covered);
   return dir;
}

// FEATURE(recent-thrust): the middle band the other two impulse detectors leave open.
// SpikeImpulseDir  -> one violent BAR ($8+): too big / too short.
// SustainedImpulseDir -> M15 x 16 bars = 4 hours ($15+): too slow for a scalp.
// This one -> "$3+ of one-directional move over the last ~15 minutes on the signal TF", which is
// exactly the shape of price thrusting INTO a level. Returns +1 for an up-thrust, -1 for a
// down-thrust, 0 for none. Same net/path efficiency test so choppy ranges don't register.
int RecentThrustDir()
{
   if(!EnableRecentThrust || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = RecentThrustTF;
   int lb = MathMax(3, RecentThrustLookbackBars);

   double c_now   = CandleClose(tf, 1);
   double c_start = CandleClose(tf, lb);
   if(c_now <= 0.0 || c_start <= 0.0)
      return 0;

   double net     = c_now - c_start;
   double net_pts = MathAbs(net) / _Point;
   if(net_pts < (double)RecentThrustMinNetPoints)
      return 0;   // not a thrust, just drift

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

   double efficiency = MathAbs(net) / path;
   if(efficiency < RecentThrustMinEfficiency)
      return 0;   // choppy back-and-forth, not a thrust

   return (net > 0.0) ? 1 : -1;
}

// FEATURE(recent-thrust): exhaustion test for the thrust above. SustainedImpulseExhaustedDir() can't
// serve here - it is hard-wired to the sustained window (M15 x 16 bars, $15+), so a 15-minute thrust
// would never register as exhausted and its block would never release. This mirrors the same idea on
// the thrust's own timeframe: a rejection wick AGAINST the thrust on the latest closed bar means the
// thrust is stalling, and a counter-entry (reversal) becomes reasonable again. Returns the direction
// of the thrust that is stalling, or 0.
int RecentThrustExhaustedDir()
{
   if(!EnableRecentThrust || _Point <= 0.0)
      return 0;

   int thrust = RecentThrustDir();
   if(thrust == 0)
      return 0;

   ENUM_TIMEFRAMES tf = RecentThrustTF;
   double range = CandleRangePoints(tf, 1);
   if(range <= 0.0)
      return 0;

   // Wick against the thrust: an up-thrust stalls when the bar prints an upper wick, and vice versa.
   double against_wick = (thrust > 0) ? UpperWickPoints(tf, 1) : LowerWickPoints(tf, 1);
   if((against_wick / range) >= RecentThrustExhaustWickRatio)
      return thrust;   // this thrust is showing rejection - treat it as exhausted

   return 0;
}

// FEATURE(sustained-impulse-exhaustion): return the impulse direction (+1/-1) if a sustained impulse
// on that direction is now showing EXHAUSTION - a rejection wick against the move on the latest bar
// AND efficiency that has dropped below threshold - else 0. Used to penalise adding in the impulse
// direction right as it stalls. Measures on the same TF the sustained detector uses.
int SustainedImpulseExhaustedDir()
{
   if(!EnableSustainedExhaustion || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = SustainedImpulseTF;
   int lb = MathMax(3, SustainedImpulseLookbackBars);

   double c_now   = CandleClose(tf, 1);
   double c_start = CandleClose(tf, lb);
   if(c_now <= 0.0 || c_start <= 0.0)
      return 0;

   double net = c_now - c_start;
   int imp_dir = (net > 0.0) ? 1 : -1;

   // The move must have been a real one-way run to be worth calling "exhausted".
   double net_pts = MathAbs(net) / _Point;
   if(net_pts < (double)SustainedImpulseMinNetPoints)
      return 0;

   // Efficiency now (same measure as SustainedImpulseDir). Exhaustion = it has fallen BELOW the
   // threshold that defined the clean impulse, i.e. the one-way move has started to stall.
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
   double efficiency = MathAbs(net) / path;
   if(efficiency >= SustainedImpulseMinEfficiency)
      return 0;   // still running cleanly -> not exhausted yet

   // Rejection wick AGAINST the impulse direction on the latest closed bar.
   double range = CandleRangePoints(tf, 1);
   if(range <= 0.0)
      return 0;
   double against_wick = (imp_dir > 0) ? UpperWickPoints(tf, 1)   // up impulse rejected from above
                                       : LowerWickPoints(tf, 1);  // down impulse rejected from below
   double wick_ratio = against_wick / range;
   if(wick_ratio < SustainedExhaustionWickRatio)
      return 0;

   return imp_dir;   // impulse in imp_dir is showing exhaustion
}

bool DetectImpulseState(string &reason)
{
   if(!UseImpulseDetection)
   {
      reason = "impulse detection disabled";
      return false;
   }

   G_MARKET_ATR_M1 = ATRPointsManual(SignalTF, ATRPeriod, 1);
   G_MARKET_ATR_M5 = ATRPointsManual(FastContextTF, ATRPeriod, 1);
   G_MARKET_SIGNAL_RANGE = CandleRangePoints(SignalTF, 1);
   G_MARKET_SIGNAL_BODY  = CandleBodyPoints(SignalTF, 1);

   if(G_MARKET_ATR_M1 <= 0.0 || G_MARKET_SIGNAL_RANGE <= 0.0)
   {
      reason = "impulse data not ready";
      return false;
   }

   double need_by_atr = G_MARKET_ATR_M1 * ImpulseATRMultiplier;
   double need = MathMax((double)ImpulseMinPoints, need_by_atr);

   reason = StringFormat("%s last range=%.0f | ATR=%.0f | need=%.0f",
                         TFToString(SignalTF),
                         G_MARKET_SIGNAL_RANGE,
                         G_MARKET_ATR_M1,
                         need);

   // Single-bar burst OR a slow pullback-free grind (directional efficiency) both count as impulse.
   if(G_MARKET_SIGNAL_RANGE >= need)
      return true;

   int spike = SpikeImpulseDir();
   if(spike != 0)
   {
      reason = StringFormat("spike impulse dir=%s (single bar >= %.1fx ATR)",
                            (spike > 0 ? "UP" : "DOWN"),
                            SpikeImpulseATRMultiple);
      return true;
   }

   int sustained = SustainedImpulseDir();
   if(sustained != 0)
   {
      reason = StringFormat("sustained impulse dir=%s (efficiency window %d bars on %s)",
                            (sustained > 0 ? "UP" : "DOWN"),
                            SustainedImpulseLookbackBars,
                            TFToString(SustainedImpulseTF));
      return true;
   }

   return false;
}

// V29 new: catches sustained multi-candle moves a single-candle impulse check would miss
// (e.g. several medium red candles in a row, none individually large enough to trip DetectImpulseState).
bool DetectVelocityImpulse(string &reason)
{
   if(!EnableMultiBarVelocityCheck)
   {
      reason = "velocity check disabled";
      return false;
   }

   int bars = MathMax(2, VelocityLookbackBars);
   double c_now = CandleClose(SignalTF, 1);
   double c_then = CandleClose(SignalTF, 1 + bars);
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);

   if(c_now <= 0.0 || c_then <= 0.0 || atr <= 0.0)
   {
      reason = "velocity data not ready";
      return false;
   }

   double net_points = MathAbs(c_now - c_then) / _Point;
   double need = atr * VelocityATRMultiplier;

   reason = StringFormat("%s net %d-bar move=%.0f | ATR=%.0f | need=%.0f",
                         TFToString(SignalTF), bars, net_points, atr, need);

   return (net_points >= need);
}

bool DetectExhaustionState(string &reason)
{
   if(!UseExhaustionDetection)
   {
      reason = "exhaustion detection disabled";
      return false;
   }

   double range = CandleRangePoints(SignalTF, 1);
   double body  = CandleBodyPoints(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double lower = LowerWickPoints(SignalTF, 1);

   G_MARKET_SIGNAL_RANGE = range;
   G_MARKET_SIGNAL_BODY  = body;
   G_MARKET_UPPER_WICK   = upper;
   G_MARKET_LOWER_WICK   = lower;

   if(range <= 0.0)
   {
      reason = "exhaustion data not ready";
      return false;
   }

   double max_wick = MathMax(upper, lower);
   double wick_ratio = max_wick / range;

   reason = StringFormat("%s wickRatio=%.2f | upper=%.0f | lower=%.0f | range=%.0f | body=%.0f",
                         TFToString(SignalTF),
                         wick_ratio,
                         upper,
                         lower,
                         range,
                         body);

   return (wick_ratio >= ExhaustionWickRatio && range >= DeadATRThresholdPoints);
}

bool DetectDeadState(string &reason)
{
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   G_MARKET_ATR_M1 = atr;

   if(atr <= 0.0)
   {
      reason = "dead-market ATR not ready";
      return false;
   }

   reason = StringFormat("%s ATR=%.0f/%d",
                         TFToString(SignalTF),
                         atr,
                         DeadATRThresholdPoints);

   return (atr <= DeadATRThresholdPoints);
}

bool DetectPullbackState(const ENUM_MARKET_STATE trend_state, string &reason)
{
   if(!UsePullbackLogic)
   {
      reason = "pullback logic disabled";
      return false;
   }

   if(trend_state != MARKET_TREND_UP && trend_state != MARKET_TREND_DOWN)
   {
      reason = "no clear trend for pullback";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double c2 = CandleClose(SignalTF, 2);
   double c3 = CandleClose(SignalTF, 3);

   if(c1 <= 0.0 || c2 <= 0.0 || c3 <= 0.0)
   {
      reason = "pullback data not ready";
      return false;
   }

   bool pullback_against_up   = (trend_state == MARKET_TREND_UP   && c1 < c2 && c2 < c3);
   bool pullback_against_down = (trend_state == MARKET_TREND_DOWN && c1 > c2 && c2 > c3);

   reason = StringFormat("trend=%s | %s closes c1=%.2f c2=%.2f c3=%.2f",
                         MarketStateToString(trend_state),
                         TFToString(SignalTF),
                         c1, c2, c3);

   return (pullback_against_up || pullback_against_down);
}

bool DetectChaosState(string &reason)
{
   if(G_LAST_SPREAD_POINTS >= CriticalSpreadPoints)
   {
      reason = StringFormat("critical spread %d/%d", G_LAST_SPREAD_POINTS, CriticalSpreadPoints);
      return true;
   }

   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   double last_range = CandleRangePoints(SignalTF, 1);

   if(atr <= 0.0 || last_range <= 0.0)
   {
      reason = "chaos data not ready";
      return false;
   }

   if(last_range >= atr * 4.0 && last_range >= ImpulseMinPoints * 2.0)
   {
      reason = StringFormat("extreme candle range %.0f vs ATR %.0f", last_range, atr);
      return true;
   }

   reason = "no chaos";
   return false;
}

void UpdateMarketStateRouter(const string source)
{
   if(!UseMarketStateRouter)
   {
      G_MARKET_STATE = MARKET_UNKNOWN;
      G_MARKET_STATUS = "MARKET: router disabled";
      G_MARKET_REASON = "UseMarketStateRouter=false";
      return;
   }

   if(MarketEvaluateOnNewBarOnly && G_MARKET_EVAL_BAR == G_BARS_SEEN)
      return;

   G_MARKET_EVAL_BAR = G_BARS_SEEN;

   if(!G_ENV_READY)
   {
      G_PREVIOUS_MARKET_STATE = G_MARKET_STATE;
      G_MARKET_STATE = MARKET_UNKNOWN;
      G_MARKET_REASON = "ENV not ready";
      G_MARKET_STATUS = "MARKET: UNKNOWN | reason=" + G_MARKET_REASON;
      return;
   }

   string trend_reason = "";
   string range_reason = "";
   string impulse_reason = "";
   string exhaustion_reason = "";
   string dead_reason = "";
   string pullback_reason = "";
   string chaos_reason = "";

   ENUM_MARKET_STATE trend_state = DetectTrendState(trend_reason);
   bool is_range      = DetectRangeState(range_reason);
   string velocity_reason = "";
   bool is_velocity_impulse = DetectVelocityImpulse(velocity_reason);
   bool is_impulse    = DetectImpulseState(impulse_reason) || is_velocity_impulse;
   bool is_exhaustion = DetectExhaustionState(exhaustion_reason);
   bool is_dead       = DetectDeadState(dead_reason);
   bool is_pullback   = DetectPullbackState(trend_state, pullback_reason);
   bool is_chaos      = DetectChaosState(chaos_reason);

   if(is_velocity_impulse && StringLen(impulse_reason) == 0)
      impulse_reason = "velocity: " + velocity_reason;

   G_TREND_DETAIL      = "TREND: " + trend_reason;
   G_RANGE_DETAIL      = "RANGE: " + range_reason;
   G_IMPULSE_DETAIL    = "IMPULSE: " + impulse_reason;
   G_EXHAUSTION_DETAIL = "EXHAUSTION: " + exhaustion_reason;

   ENUM_MARKET_STATE new_state = MARKET_UNKNOWN;
   string main_reason = "";

   // Priority: CHAOS -> DEAD -> EXHAUSTION -> IMPULSE -> PULLBACK -> TREND -> RANGE -> UNKNOWN
   if(is_chaos)
   {
      new_state = MARKET_CHAOS;
      main_reason = chaos_reason;
   }
   else if(is_dead)
   {
      new_state = MARKET_DEAD;
      main_reason = dead_reason;
   }
   else if(is_exhaustion)
   {
      new_state = MARKET_EXHAUSTION;
      main_reason = exhaustion_reason;
   }
   else if(is_impulse)
   {
      new_state = MARKET_IMPULSE;
      main_reason = impulse_reason;

      // V29 new: classify this impulse as trend-aligned (acceleration) or a correction
      // (counter-move against the established HTF/structure trend), even though the
      // impulse itself was measured on a small TF (SignalTF).
      G_LAST_IMPULSE_BAR = G_BARS_SEEN;
      G_ESTABLISHED_TREND = trend_state;

      // FIX(impulse-direction): the direction used to come from just c1 vs c2 - a single-bar look
      // that a lone spike candle could flip, mislabelling a counter-trend pop as an "up impulse".
      // Measure the NET move across the impulse window instead (close now vs close N bars back), and
      // require the individual bars to mostly agree, so the label reflects the actual thrust, not
      // the last candle's noise. Falls back to the net two-close move if the window data is thin.
      double impulse_c1 = CandleClose(SignalTF, 1);
      double impulse_c2 = CandleClose(SignalTF, 2);

      int    imp_win   = MathMax(2, ImpulseDirectionLookbackBars);
      double imp_start = CandleClose(SignalTF, imp_win);   // close at the start of the window
      bool   impulse_up;

      if(imp_start > 0.0 && impulse_c1 > 0.0)
      {
         double net_move = impulse_c1 - imp_start;         // net thrust over the window

         // Count how many of the bars in the window pushed the same way as the net move, so a big
         // net move built from mixed bars (chop) doesn't get mislabelled as a clean impulse dir.
         int agree_up = 0, agree_dn = 0;
         for(int b = 1; b < imp_win; b++)
         {
            double cn = CandleClose(SignalTF, b);
            double cp = CandleClose(SignalTF, b + 1);
            if(cn <= 0.0 || cp <= 0.0)
               continue;
            if(cn > cp) agree_up++;
            else if(cn < cp) agree_dn++;
         }

         if(net_move > 0.0 && agree_up >= agree_dn)
            impulse_up = true;
         else if(net_move < 0.0 && agree_dn >= agree_up)
            impulse_up = false;
         else
            impulse_up = (net_move >= 0.0);   // net and bar-count disagree (choppy) -> trust net move
      }
      else
      {
         impulse_up = (impulse_c1 > impulse_c2);   // thin data -> original two-close comparison
      }

      // If THIS impulse was flagged by the spike or sustained detector, that detector's own
      // direction is the authoritative impulse direction - it can disagree with the short 3-bar
      // window (e.g. a lone UP spike inside a downtrend: the 3-bar net still reads down, but the
      // impulse event itself is the up spike). Prefer the specific detector when it has an opinion.
      int spike_dir_now     = SpikeImpulseDir();
      int sustained_dir_now = SustainedImpulseDir();
      if(spike_dir_now != 0)
         impulse_up = (spike_dir_now > 0);
      else if(sustained_dir_now != 0)
         impulse_up = (sustained_dir_now > 0);

      // V31.6f new: capture the impulse's own direction/close/range, so a later first-entry
      // signal can check "are we now in a correction (bounce) against this recent impulse?"
      G_LAST_IMPULSE_DIRECTION = impulse_up ? 1 : -1;
      G_LAST_IMPULSE_CLOSE = impulse_c1;
      G_LAST_IMPULSE_RANGE_POINTS = CandleRangePoints(SignalTF, 1);

      if(trend_state == MARKET_TREND_UP)
         G_LAST_IMPULSE_TREND_ALIGNED = impulse_up;
      else if(trend_state == MARKET_TREND_DOWN)
         G_LAST_IMPULSE_TREND_ALIGNED = !impulse_up;
      else
         G_LAST_IMPULSE_TREND_ALIGNED = false; // no established trend -> treat conservatively as correction-like

      if((ImpulseCooldownPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v29 IMPULSE] bar=%d trend=%s aligned=%s | %s",
                     G_LAST_IMPULSE_BAR, MarketStateToString(trend_state),
                     YesNoV29(G_LAST_IMPULSE_TREND_ALIGNED), main_reason);
   }
   else if(is_pullback)
   {
      new_state = MARKET_PULLBACK;
      main_reason = pullback_reason;
   }
   else if(trend_state == MARKET_TREND_UP || trend_state == MARKET_TREND_DOWN)
   {
      new_state = trend_state;
      main_reason = trend_reason;
   }
   else if(is_range)
   {
      new_state = MARKET_RANGE;
      main_reason = range_reason;
   }
   else
   {
      new_state = MARKET_UNKNOWN;
      main_reason = "no dominant state | " + range_reason + " | " + trend_reason;
   }

   G_PREVIOUS_MARKET_STATE = G_MARKET_STATE;
   G_MARKET_STATE = new_state;
   G_MARKET_REASON = main_reason;
   G_MARKET_STATUS = "MARKET: " + MarketStateToString(G_MARKET_STATE) + " | reason=" + G_MARKET_REASON;

   string signature = G_MARKET_STATUS + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintMarketOnChange && signature != G_MARKET_LAST_SIGNATURE)
   {
      bool changed = (G_PREVIOUS_MARKET_STATE != G_MARKET_STATE);
      if(changed || G_MARKET_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 MARKET] %s | mode=%s | source=%s",
                     G_MARKET_STATUS,
                     ModeToString(G_ACTIVE_MODE),
                     source);
      }
      G_MARKET_LAST_SIGNATURE = signature;
   }

   if(G_ENV_READY)
      SetStatus("CORE + ENV + MODE + MARKET READY: first entry only in Phase 21.3", "MarketStateRouter");
}


//==================================================================//
//  PHASE 21.3 OPPORTUNITY SCANNER
//==================================================================//
void ResetOpportunity(const string reason)
{
   G_OPP_DIR = OPP_DIR_NONE;
   G_OPP_GRADE = OPP_GRADE_NONE;
   G_OPP_TYPE = OPP_TYPE_NONE;
   G_OPP_SCORE = 0;
   G_OPP_BEST_BUY_SCORE = 0;
   G_OPP_BEST_SELL_SCORE = 0;
   for(int si = 0; si < 2; si++)
   {
      G_OPP_SIDE_TYPE[si] = OPP_TYPE_NONE;
      G_OPP_SIDE_GRADE[si] = OPP_GRADE_NONE;
      G_OPP_SIDE_MICRO[si] = false;
      G_OPP_SIDE_REASON[si] = "";
   }
   G_OPP_REASON = reason;
   G_OPP_DETAIL = "OPPORTUNITY DETAIL: " + reason;
   G_OPP_STATUS = "OPPORTUNITY: NONE | reason=" + reason;
   G_OPP_ROOM_POINTS = 0.0;
   G_OPP_NEAR_LOW_DIST = 0.0;
   G_OPP_NEAR_HIGH_DIST = 0.0;
   G_OPP_IS_MICRO = false;
   G_SCORE_DECISION = SCORE_DECISION_NONE;
   G_SCORE_STATUS = "SCORE: initializing";
   G_SCORE_DETAIL = "SCORE DETAIL: initializing";
   G_SCORE_LAST_SIGNATURE = "";
   G_SCORE_BASE = 0;
   G_SCORE_BONUS = 0;
   G_BONUS_TREND_ALIGN = 0;
   G_SCORE_PENALTY = 0;
   G_PENALTY_TREND_AGAINST = 0;
   G_ENTRY_WARNINGS = 0;   // V155: warnings are collected fresh for each entry judged
   G_PENALTY_CONDITIONS = 0;
   G_PENALTY_QUALITY = 0;
   G_PENALTY_IMPULSE = 0;
   G_CANDLE_BONUS = 0;
   G_CANDLE_PENALTY = 0;
   G_STRUCT_BONUS = 0;
   G_STRUCT_PENALTY = 0;
   G_SITUATION = SIT_NONE;
   G_SITUATION_DIR = 0;
   G_SCORE_FINAL = 0;
   G_SCORE_MIN_REQUIRED = 0;
   G_SCORE_TP_TARGET = 0.0;
   G_SCORE_ROOM_POINTS = 0.0;
   G_SCORE_IS_MICRO = false;
   G_SCORE_HARD_BLOCK = "none";
   G_ENTRY_STATUS = "ENTRY: initializing";
   G_ENTRY_REASON = "initial entry";
   G_ENTRY_DETAIL = "ENTRY DETAIL: initializing";
   G_ENTRY_LAST_SIGNATURE = "";
   // FIX(entry-history-wipe): the entry HISTORY is deliberately NOT cleared here. ResetOpportunity()
   // and ResetScoreEngine() run on essentially every scan that finds no candidate, so clearing it
   // meant that on any quiet tick the bot forgot it had ever traded, which silently disabled three
   // anti-churn guards: G_LAST_ENTRY_BAR went back to -100000 and failed the `> -9999` test on the
   // FirstEntryCooldownBars check (cooldown skipped); G_LAST_ENTRY_TIME went to 0 so seconds-since-
   // entry read as 999999 (MinSecondsBetweenEntries defeated); and G_ENTRY_ATTEMPTS went to 0 so
   // MaxDailyEntryAttempts could never be reached. History is initialised at declaration and in
   // OnInit, and updated on a real entry - a routine "no candidate" reset must not touch it.
   G_ENTRY_READY = false;
   G_MICRO_STATUS = "MICRO: initializing";
   G_MICRO_REASON = "initial micro";
   G_MICRO_DETAIL = "MICRO DETAIL: initializing";
   G_MICRO_LAST_SIGNATURE = "";
   G_MICRO_READY = false;
   G_MICRO_TP_POINTS = 0.0;
   G_MICRO_LOT_FACTOR = 0.0;
   G_REDIRECT_STATUS = "REDIRECT: initializing";
   G_REDIRECT_REASON = "initial redirect";
   G_REDIRECT_DETAIL = "REDIRECT DETAIL: initializing";
   G_REDIRECT_LAST_SIGNATURE = "";
   G_REDIRECT_APPLIED = false;
   G_REDIRECT_ATTEMPTS = 0;
   G_REDIRECT_SUCCESSES = 0;
   G_REDIRECT_FROM_DIR = OPP_DIR_NONE;
   G_REDIRECT_TO_DIR = OPP_DIR_NONE;
   G_REDIRECT_TYPE = OPP_TYPE_NONE;
   G_REDIRECT_SCORE = 0;
   G_QUEUE_STATUS = "QUEUE: initializing";
   G_QUEUE_REASON = "initial queue";
   G_QUEUE_DETAIL = "QUEUE DETAIL: initializing";
   G_QUEUE_LAST_SIGNATURE = "";
   // FIX(queue-reset-wipe): G_QUEUE_ACTIVE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_REPLAYED NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_SAVED_BAR NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_SAVED_TIME NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_DIR NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_GRADE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_TYPE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_DECISION NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_MARKET_STATE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_OPP_SCORE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_SCORE_FINAL NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_SCORE_MIN NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_IS_MICRO NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_TP_TARGET NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_ROOM_POINTS NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_OPP_REASON NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   // FIX(queue-reset-wipe): G_QUEUE_SCORE_DETAIL NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / ClearSignalQueue / ReplayQueuedSignal only).
   G_QUEUE_SAVED_COUNT = 0;
   G_QUEUE_REPLAY_COUNT = 0;
   G_QUEUE_EXPIRED_COUNT = 0;
   G_BLOCK_STATUS = "BLOCK: initializing";
   G_BLOCK_REASON = "initial block";
   G_BLOCK_DETAIL = "BLOCK DETAIL: initializing";
   G_BLOCK_LAST_SIGNATURE = "";
   // FIX(block-state-wipe): temp-block LIFECYCLE state is not cleared by a routine reset. These
   // helpers run on ordinary scans, before UpdateBlockExpiryEngine() re-applies the block later
   // in the same cycle - so the block was destroyed and recreated every pass, its start bar was
   // always "now", and its age never grew. That silently disabled the whole expiry feature:
   // BlockExpiryMaxBars / BlockExpiryMaxSeconds never elapsed and ApplyExpiredBlockSoftPass()
   // (the boosted escape that stops the bot getting stuck behind a stale block) never fired.
   // Block state is cleared by ClearTempBlock() and at OnInit, which is where it belongs.
   G_GRID_STATUS = "GRID: initializing";
   G_GRID_REASON = "initial grid";
   G_GRID_DETAIL = "GRID DETAIL: initializing";
   G_GRID_LAST_SIGNATURE = "";
   // FIX(grid-cooldown-wipe): grid timing history is NOT cleared by a routine reset. Wiping
   // G_LAST_GRID_BAR to -100000 fails the `> -9999` guard on the GridCooldownBars check, so
   // the grid cooldown was skipped entirely and grid orders could fire back to back.
   // PACKAGE 2 (F-C1): the basket's own state (orders, volume, DD history, adverse streak, grid
   // counters...) is NOT cleared by a per-scan reset - this ran every ~3 s and made the adverse-streak,
   // DD-acceleration and MaxDailyGridAttempts checks unreachable. RefreshGridDashboardStats clears it
   // when the basket is gone; the grid counters reset with the risk day.
   G_NEXT_GRID_PRICE = 0.0;
   G_NEXT_GRID_DISTANCE = 0.0;
   G_NEXT_GRID_LOT = 0.0;
   G_RISK_STATUS = "RISK: initializing";
   G_RISK_REASON = "initial risk";
   G_RISK_DETAIL = "RISK DETAIL: initializing";
   G_RISK_LAST_SIGNATURE = "";
   G_RISK_READY = false;
   G_RISK_HARD_BLOCK = false;
   G_RISK_CLOSE_REQUEST = false;
   // FIX(post-loss-cooldown-wipe): NOT cleared here - per-scan reset must not erase the post-loss cooldown (see ResetScoreEngine note).
   G_RISK_BLOCK_COUNT = 0;
   G_RISK_CLOSE_COUNT = 0;
   // FIX(post-loss-cooldown-wipe): prev-basket tracking NOT cleared here - needed for UpdatePostLossCooldown to detect a just-closed losing basket.
   // (prev-basket profit also preserved for the same reason)
   G_PREMIUM_STATUS = "PREMIUM: initializing";
   G_PREMIUM_SUMMARY = "initializing";
   G_NEXT_ACTION = "initializing";
   G_LAST_MAJOR_EVENT = "none";
   G_LOG_LAST_SIGNATURE = "";
   G_LOG_LAST_SNAPSHOT = 0;
   G_LOG_SNAPSHOT_COUNT = 0;
   G_LOG_EVENT_COUNT = 0;
   G_MEMORY_STATUS = "MEMORY: initializing";
   G_MEMORY_REASON = "initial memory";
   G_MEMORY_DETAIL = "MEMORY DETAIL: initializing";
   G_MEMORY_LAST_SIGNATURE = "";
   G_MEMORY_SETUP_SIGNATURE = "";
   G_MEMORY_LAST_MISS_REASON = "";
   G_MEMORY_APPLIED = false;
   G_MEMORY_REPEAT_COUNT = 0;
   G_MEMORY_TOTAL_MISSED = 0;
   G_MEMORY_BOOST_COUNT = 0;
   G_MEMORY_LAST_BAR = -100000;
   G_MEMORY_LAST_TIME = 0;
   G_MEMORY_CURRENT_BOOST = 0;
   if(G_VPS_LAST_CHECK == 0) G_VPS_STATUS = "VPS: initializing";
   if(G_VPS_LAST_CHECK == 0) G_VPS_REASON = "initial VPS validation";
   G_VPS_DETAIL = "VPS DETAIL: initializing";
   G_VPS_NO_TRADE_REASON = "NO TRADE: initializing";
   G_VPS_BROKER_DETAIL = "BROKER: initializing";
   G_VPS_LAST_SIGNATURE = "";
   // FIX(vps-timer-wipe): G_VPS_LAST_CHECK/LAST_AUDIT/LAST_BROKER_PRINT/TICK_WINDOW_START/TICK_WINDOW_COUNT/TICKS_PER_MINUTE deliberately NOT cleared here - this reset runs on essentially every scan, and these are UpdateVPSLiveValidation()'s own throttle timers. Zeroing them every scan defeated VPSValidationSeconds/VPSNoTradeAuditSeconds/VPSBrokerSnapshotSeconds and reset the ticks-per-minute rolling window before it could ever accumulate a full period.
   if(G_VPS_LAST_CHECK == 0) G_VPS_OK = false;   // BOSQICH 2
   G_VPS_WARNINGS = 0;

   G_LEGACY_STATUS = "LEGACY: initializing";
   G_LEGACY_REASON = "initial legacy";
   G_LEGACY_DETAIL = "LEGACY DETAIL: initializing";
   G_LEGACY_LAST_SIGNATURE = "";
   G_LEGACY_HARD_BLOCK = false;
   G_LEGACY_APPLIED = false;
   G_LEGACY_BONUS = 0;
   G_LEGACY_PENALTY = 0;
   G_LEGACY_NEAREST_SUPPORT = 0.0;
   G_LEGACY_NEAREST_RESIST = 0.0;
   G_LEGACY_SUPPORT_DIST = 0.0;
   G_LEGACY_RESIST_DIST = 0.0;
   G_LEGACY_ZONE_STATUS = "ZONE: initializing";
   G_LEGACY_BOS_STATUS = "BOS: initializing";
   G_LEGACY_SWEEP_STATUS = "SWEEP: initializing";
   G_LEGACY_FAKE_STATUS = "FAKE: initializing";
   G_LEGACY_EXH_STATUS = "EXH: initializing";
   G_LEGACY_SESSION_STATUS = "SESSION: initializing";
   G_LEGACY_BOS_DIR = 0;
   G_LEGACY_BOS_TIME = 0;
   G_LEGACY_BOS_LEVEL = 0.0;
   G_LEGACY_EVENT_COUNT = 0;

   G_PACK2_STATUS = "PACK2: initializing";
   G_PACK2_REASON = "initial pack2";
   G_PACK2_DETAIL = "PACK2 DETAIL: initializing";
   G_PACK2_LAST_SIGNATURE = "";
   G_PACK2_APPLIED = false;
   // FIX(basket-state-wipe): basket TRAILING / break-even state is NOT cleared by a routine
   // reset. These reset helpers run on ordinary scans, and RefreshGridDashboardStats() cannot
   // rebuild them from open positions (a high-water mark is history, not a position field).
   // Clearing TRAIL_PEAK here made the trailing lock re-anchor to the CURRENT profit on every
   // quiet tick instead of holding the peak, so locked profit followed price back down and the
   // trailing protection never actually held. Basket state is cleared where a basket ENDS.
   G_PACK2_DYNAMIC_TP = 0.0;
   G_PACK2_DYNAMIC_GRID = 0.0;
   G_PACK2_TRAIL_CLOSES = 0;
   G_PACK2_EVENT_COUNT = 0;
   // FIX(aftershock-wipe): the aftershock timer is NOT cleared by a routine reset - clearing it
   // every scan ended the protection window immediately after it was opened.

   G_PACK3_STATUS = "PACK3: initializing";
   G_PACK3_REASON = "initial pack3";
   G_PACK3_DETAIL = "PACK3 DETAIL: initializing";
   G_PACK3_NEWS_STATUS = "NEWS: initializing";
   G_PACK3_BROKER_STATUS = "BROKER_SYNC: initializing";
   G_PACK3_DEAL_STATUS = "DEALS: initializing";
   G_PACK3_AUDIT_STATUS = "CLIENT_AUDIT: initializing";
   G_PACK3_LAST_SIGNATURE = "";
   G_PACK3_HARD_BLOCK = false;
   G_PACK3_ENTRY_BLOCK = false;
   G_PACK3_GRID_BLOCK = false;
   G_PACK3_CLOSE_REQUEST = false;
   G_PACK3_NEWS_ACTIVE = false;
   G_PACK3_NEWS_UNTIL = 0;
   // FIX(pack3-timer-wipe): G_PACK3_LAST_DEAL_SCAN/LAST_AUDIT_PRINT deliberately NOT cleared here - Pack3ClosedDealAnalytics() uses them to throttle its own deal-history rescan to once per ClosedDealRefreshSeconds; zeroing them every scan made it rescan the full deal history on essentially every tick.
   G_PACK3_EVENT_COUNT = 0;
   // FIX(pack3-timer-wipe): G_DEALS_TOTAL/WINS/LOSSES/NET_PROFIT/GROSS_PROFIT/GROSS_LOSS/WINRATE deliberately NOT cleared here - these are Pack3ClosedDealAnalytics()'s cached results, valid between its own throttled rescans; wiping them every scan meant the dashboard read 0 deals/0% winrate in between real rescans instead of the last real numbers.
   G_BROKER_EFFECTIVE_STOP = 0.0;
}

ENUM_OPPORTUNITY_GRADE GradeFromScore(const int score, const bool micro_preferred)
{
   if(score >= MinOpportunityScoreA)
      return OPP_GRADE_A_PLUS;

   if(score >= MinOpportunityScoreB)
      return OPP_GRADE_B;

   if(ScannerAllowMicroC && score >= MinOpportunityScoreC && micro_preferred)
      return OPP_GRADE_C_MICRO;

   return OPP_GRADE_NONE;
}

bool IsBullishCandle(const ENUM_TIMEFRAMES tf, const int shift)
{
   return (CandleClose(tf, shift) > CandleOpen(tf, shift));
}

bool IsBearishCandle(const ENUM_TIMEFRAMES tf, const int shift)
{
   return (CandleClose(tf, shift) < CandleOpen(tf, shift));
}

double RecentHighForScanner()
{
   int lookback = ScannerLookbackBars;
   if(lookback < 5)
      lookback = 5;
   return HighestHigh(FastContextTF, lookback, 1);
}

double RecentLowForScanner()
{
   int lookback = ScannerLookbackBars;
   if(lookback < 5)
      lookback = 5;
   return LowestLow(FastContextTF, lookback, 1);
}

// FEATURE(bayes-auto-disable) forward declarations: defined later, used by the scanner above.
bool   BayesDetectorDisabled(const int opp_type);
double BayesWinRate(const int opp_type);
double BayesSampleCount(const int opp_type);

// V205: the level BEYOND the nearest one.
//
// The zone map reports a single support and a single resistance - whichever is closest. That is the
// level price will meet first, and for judging an entry it is the right answer. It is the wrong
// answer for judging a TARGET.
//
// The case that keeps costing money: price falls to a deep support, bounces off it, rises, and now
// sits above a shallower support. The EA sees only the shallow one, measures plenty of room beneath
// it, and sells - straight down into the deep support that turned price around minutes earlier. The
// level that actually matters is invisible because something smaller sits in front of it.
//
// Mirror case for buys: a shallow resistance in view while the one that has already rejected price
// twice sits just above it.
//
// This returns the NEXT level past a given one, so the EA can ask "and what is behind that?" - the
// question a trader asks automatically and the zone map could not answer.
double ZoneMapNextSupportBelow(const double price, const double above_level)
{
   if(above_level <= 0.0 || _Point <= 0.0)
      return 0.0;

   ZoneMapRefreshSwingCache();

   // Anything at or above the level we are looking past is not "next" - step under it first.
   // FIX(dead-ceiling-guard): the old `if(ceiling <= 0.0 || ceiling >= price) ceiling = ...` branch
   // recomputed `ceiling` with the exact same expression already assigned above it - a no-op
   // regardless of which way the condition went, so it never actually did the extra clamping its
   // own comment implied. Left as the single unconditional computation it always reduced to; the
   // `price` parameter is not otherwise used to bound this search below the current price - if a
   // ceiling below current price is ever needed here, that still needs to be added deliberately
   // rather than via this dead branch.
   double ceiling = above_level - MathMax(1, ZoneNextLevelGapPoints) * _Point;

   double best = 0.0;
   for(int t = 0; t < SIRUS_ZM_CACHE_TF_COUNT; t++)
   {
      for(int k = 0; k < G_ZMC_LOW_COUNT[t]; k++)
      {
         double l = G_ZMC_LOW_PRICE[t][k];
         if(l <= 0.0 || l >= ceiling)
            continue;
         if(best == 0.0 || l > best)
            best = l;      // highest level that still sits below the one we are looking past
      }
   }
   return best;
}

double ZoneMapNextResistanceAbove(const double price, const double below_level)
{
   if(below_level <= 0.0 || _Point <= 0.0)
      return 0.0;

   ZoneMapRefreshSwingCache();

   double floor_px = below_level + MathMax(1, ZoneNextLevelGapPoints) * _Point;

   double best = 0.0;
   for(int t = 0; t < SIRUS_ZM_CACHE_TF_COUNT; t++)
   {
      for(int k = 0; k < G_ZMC_HIGH_COUNT[t]; k++)
      {
         double h = G_ZMC_HIGH_PRICE[t][k];
         if(h <= floor_px)
            continue;
         if(best == 0.0 || h < best)
            best = h;      // lowest level that still sits above the one we are looking past
      }
   }
   return best;
}

// V31.6c forward declarations: Zone Map functions are defined later in the file,
// but the zone-aware sweep upgrade below needs them now.
bool ZoneMapIsPolarityFlip(const double level, const bool checking_as_support);
void MarketVerdictRead();     // fwd decl: V117 consensus reading, used by the score engine below
double ZoneMapBestWeightedResistance(const double price, const double search_limit_pts);
double ZoneMapBestWeightedSupport(const double price, const double search_limit_pts);
// ============================================================================
// V132: ZONE REACTION QUALITY - a level that threw price back hard is strong,
// even if it has only been touched once.
// ----------------------------------------------------------------------------
// Zone strength was purely a COUNT: 1.0 + touches x 0.25. With the counter-zone
// block needing 1.8, a level had to be touched FOUR times before it could stop an
// entry. Live case from the user: price had already been thrown back sharply from
// ~4236 once, that rejection was plainly visible on the chart, and the EA still
// opened a SELL right on it - because one touch scores 1.25 and the guard needs
// 1.8. The trade went straight into drawdown.
//
// Counting touches measures how OFTEN a level was tested. It says nothing about
// how HARD price was rejected, which is what actually makes a level dangerous to
// trade into. This adds that second dimension: for each touch, measure how far
// price travelled away from the level afterwards, in ATR units. One violent
// rejection now earns what four half-hearted touches earn.
// ============================================================================
// V141: ZONE DECAY - a level is consumed by the touches it survives.
// ----------------------------------------------------------------------------
// Zone strength counts touches and adds for each one: more tests, stronger level.
// The market works the opposite way. The orders resting at a level are finite; each
// test consumes some of them. A level tested four times has far less left than one
// tested once, which is why the fourth touch is so often the one that breaks.
//
// So the EA currently trusts most the levels that have been eaten most.
//
// Counting touches cannot see this - the decay shows up in the REACTIONS. A healthy
// level throws price back as hard on the third touch as on the first; a consumed one
// produces weaker and weaker bounces until it simply gives way. Comparing the early
// reactions against the recent ones measures exactly that.
//
// Returns 0.0 (fresh, no decay) to 1.0 (fully consumed).
// ============================================================================
double ZoneDecayFactor(const double level)
{
   if(!EnableZoneDecay || level <= 0.0 || _Point <= 0.0)
      return 0.0;

   // Per-bar cache: this walks the same window as ZoneReactionQuality and is called
   // from ZoneMapStrength, which runs from many places every bar.
   static int    zd_bar = -100000;
   static double zd_level[8];
   static double zd_value[8];
   static int    zd_count = 0;
   if(zd_bar > G_BARS_SEEN) zd_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(zd_bar != G_BARS_SEEN)
   {
      zd_bar = G_BARS_SEEN;
      zd_count = 0;
   }
   for(int c = 0; c < zd_count; c++)
      if(MathAbs(zd_level[c] - level) < _Point)
         return zd_value[c];

   ENUM_TIMEFRAMES tf = ZoneReactionTF;
   int lookback = MathMax(20, ZoneReactionLookbackBars);
   double tol   = MathMax(1, ZoneStrengthTolerancePoints) * _Point;
   int horizon  = MathMax(2, ZoneReactionHorizonBars);

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   // Collect every touch with its reaction size, oldest first.
   double reactions[40];
   int    rn = 0;

   for(int i = lookback; i >= horizon + 1 && rn < 40; i--)
   {
      double hi = CandleHigh(tf, i);
      double lo = CandleLow(tf, i);
      if(hi <= 0.0 || lo <= 0.0)
         continue;
      if(!(lo <= level + tol && hi >= level - tol))
         continue;

      double away_up = 0.0, away_dn = 0.0;
      for(int k = i - 1; k >= MathMax(1, i - horizon); k--)
      {
         double kh = CandleHigh(tf, k);
         double kl = CandleLow(tf, k);
         if(kh > 0.0 && (kh - level) > away_up) away_up = kh - level;
         if(kl > 0.0 && (level - kl) > away_dn) away_dn = level - kl;
      }

      reactions[rn++] = (MathMax(away_up, away_dn) / _Point) / atr;
   }

   double decay = 0.0;

   // Needs enough touches to compare an early half against a recent half.
   if(rn >= MathMax(3, ZoneDecayMinTouches))
   {
      int half = rn / 2;
      double early = 0.0, recent = 0.0;
      for(int a = 0; a < half; a++)          early  += reactions[a];
      for(int b = rn - half; b < rn; b++)    recent += reactions[b];
      early  /= MathMax(1, half);
      recent /= MathMax(1, half);

      if(early > 0.0001)
      {
         // Recent bounces this much weaker than the early ones = this much consumed.
         double ratio = recent / early;
         decay = MathMax(0.0, MathMin(1.0, 1.0 - ratio));
      }
   }

   // A level tested many times is consumed even if each bounce still looks similar -
   // the orders behind it are finite regardless.
   if(rn > ZoneDecayFreeTouches)
   {
      double count_decay = (double)(rn - ZoneDecayFreeTouches) * ZoneDecayPerExtraTouch;
      decay = MathMax(decay, MathMin(1.0, count_decay));
   }

   if(zd_count < 8)
   {
      zd_level[zd_count] = level;
      zd_value[zd_count] = decay;
      zd_count++;
   }
   return decay;
}

// ============================================================================
double ZoneReactionQuality(const double level)
{
   if(!EnableZoneReactionStrength || level <= 0.0 || _Point <= 0.0)
      return 0.0;

   // Small per-bar cache keyed on the level: ZoneMapStrength() is called from many places each
   // tick, and this scan walks a 200-bar window with an inner loop - recomputing it per call
   // would be the most expensive thing in the EA.
   static int    zrq_bar   = -100000;
   static double zrq_level[8];
   static double zrq_value[8];
   static int    zrq_count = 0;
   if(zrq_bar > G_BARS_SEEN) zrq_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(zrq_bar != G_BARS_SEEN)
   {
      zrq_bar = G_BARS_SEEN;
      zrq_count = 0;
   }
   for(int c = 0; c < zrq_count; c++)
      if(MathAbs(zrq_level[c] - level) < _Point)
         return zrq_value[c];

   ENUM_TIMEFRAMES tf = ZoneReactionTF;
   int lookback = MathMax(10, ZoneReactionLookbackBars);
   double tol   = MathMax(1, ZoneStrengthTolerancePoints) * _Point;

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   int    horizon = MathMax(2, ZoneReactionHorizonBars);
   double best_atr = 0.0;

   // Walk back through the window; whenever a bar touched the level, measure the
   // strongest move away from it over the following bars.
   for(int i = horizon + 1; i <= lookback; i++)
   {
      double hi = CandleHigh(tf, i);
      double lo = CandleLow(tf, i);
      if(hi <= 0.0 || lo <= 0.0)
         continue;

      bool touched = (lo <= level + tol && hi >= level - tol);
      if(!touched)
         continue;

      // How far did price get away from the level in the bars that followed?
      double away_up = 0.0, away_dn = 0.0;
      for(int k = i - 1; k >= MathMax(1, i - horizon); k--)
      {
         double kh = CandleHigh(tf, k);
         double kl = CandleLow(tf, k);
         if(kh > 0.0 && (kh - level) > away_up) away_up = kh - level;
         if(kl > 0.0 && (level - kl) > away_dn) away_dn = level - kl;
      }

      double away = MathMax(away_up, away_dn) / _Point;
      double in_atr = away / atr;
      if(in_atr > best_atr)
         best_atr = in_atr;
   }

   // Convert the strongest rejection into a bounded strength contribution.
   double bonus = 0.0;
   if(best_atr >= ZoneReactionMinATR)
      bonus = MathMax(0.0, MathMin(ZoneReactionMaxBonus,
                                   (best_atr - ZoneReactionMinATR) * ZoneReactionWeight));

   if(zrq_count < 8)
   {
      zrq_level[zrq_count] = level;
      zrq_value[zrq_count] = bonus;
      zrq_count++;
   }
   return bonus;
}

// V132: touch-only strength, without the rejection bonus. Used where the number is a stand-in for
// the level's CLASS rather than its danger - the ghost-zone lifetime picks D1/H1/M15 bands from it,
// and a single violent rejection on an M15 level must not promote it to a D1 lifetime.
// V235: two things a touch count cannot see.
//
// WHETHER THE LEVEL WAS RETESTED. Price visiting a price four times in one approach is not the same
// as visiting it, leaving, and coming back. The first is a pause; the second is the market
// recognising the level, and the return is worth more than the original touch because it confirms
// the original was not where price happened to stop. Counting touches treats both identically.
//
// WHETHER LIQUIDITY IS SITTING ON IT. A long wick through a level on a higher timeframe means stops
// were taken there, or are still waiting. Either way price is drawn back to it - and a level that
// attracts price is the opposite of one that repels it, which is what strength is meant to measure.
// This is the reading behind the loss where a level looked solid and price went straight through
// into the wick above it.
bool ZoneWasRetested(const double level, int &returns, string &detail)
{
   returns = 0;
   detail = "";
   if(!EnableZoneRetestCount || level <= 0.0 || _Point <= 0.0)
      return false;

   ENUM_TIMEFRAMES tf = ZoneRetestTF;
   double tol = ScaleAdjustedPoints(MathMax(1, ZoneRetestTolerance)) * _Point;
   int look = MathMax(30, ZoneRetestLookback);

   // Walk back marking whether price was AT the level or away from it. Each transition from away
   // to at is a return - which is what separates a retest from a pause.
   bool was_at = false;
   bool left_since = false;

   for(int i = 1; i <= look; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0)
         continue;

      bool at_now = (l - tol <= level && level <= h + tol);

      if(at_now)
      {
         if(left_since && !was_at)
         {
            returns++;
            left_since = false;
         }
         was_at = true;
      }
      else
      {
         double away = MathMin(MathAbs(l - level), MathAbs(h - level)) / _Point;
         if(away >= (double)ZoneRetestAwayPoints)
            left_since = true;
         was_at = false;
      }
   }

   if(returns <= 0)
      return false;

   detail = StringFormat("%d return%s", returns, (returns > 1 ? "s" : ""));
   return true;
}

double ZoneLiquidityWick(const double level, string &detail)
{
   detail = "";
   if(!EnableZoneWickCheck || level <= 0.0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = ZoneWickTF;
   double tol = ScaleAdjustedPoints(MathMax(1, ZoneWickTolerance)) * _Point;
   double worst = 0.0;

   for(int i = 1; i <= MathMax(3, ZoneWickLookback); i++)
   {
      double o = CandleOpen(tf, i), c = CandleClose(tf, i);
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;
      double range = h - l;
      if(range <= 0.0)
         continue;

      double upper = (h - MathMax(o, c)) / range;
      double lower = (MathMin(o, c) - l) / range;

      // The wick's TIP has to reach the level. A body nearby is not the same thing - the wick is
      // where price went and did not stay.
      if(upper >= ZoneWickMinRatio && MathAbs(h - level) <= tol)
         worst = MathMax(worst, upper);
      if(lower >= ZoneWickMinRatio && MathAbs(l - level) <= tol)
         worst = MathMax(worst, lower);
   }

   if(worst <= 0.0)
      return 0.0;

   detail = StringFormat("%.0f%% wick", worst * 100.0);
   return MathMin(1.0, worst);
}


// V234: which timeframe drew this level? Touch count alone cannot say - four touches on M1 and four
// on H1 produce the same number, and they are not the same level. An M1 swing is where price paused
// for a few minutes; an H1 swing is where it turned for hours, and the participants who defended it
// are still watching. This is the reading behind the loss where an M1 break looked clean while M5
// and M15 had never moved.
//
// Also: whether the level has been RETESTED. A level touched once is a price price visited. One
// touched, left, and returned to is a level the market recognises, and the second touch is worth
// more than the first because it confirms the first was not coincidence.
double ZoneMapStrengthByTouches(const double level)
{
   if(level <= 0.0)
      return 1.0;

   double base = 1.0 + ZoneMapConfluenceCount(level) * ZoneStrengthPerTouch;

   if(!EnableZoneTFWeight || _Point <= 0.0)
      return base;

   // Find the highest timeframe whose swing cache holds this price. Working down from the top
   // means the answer is the largest scale that recognises it, which is the one that matters.
   ZoneMapRefreshSwingCache();
   double tol = ScaleAdjustedPoints(MathMax(1, ZoneTFMatchTolerance)) * _Point;

   int best_tf_index = -1;
   for(int t = SIRUS_ZM_CACHE_TF_COUNT - 1; t >= 0; t--)
   {
      bool found = false;
      for(int k = 0; k < G_ZMC_HIGH_COUNT[t] && !found; k++)
         if(MathAbs(G_ZMC_HIGH_PRICE[t][k] - level) <= tol) found = true;
      for(int k = 0; k < G_ZMC_LOW_COUNT[t] && !found; k++)
         if(MathAbs(G_ZMC_LOW_PRICE[t][k] - level) <= tol) found = true;
      if(found) { best_tf_index = t; break; }
   }

   if(best_tf_index < 0)
      return base;

   // The cache runs M5, M15, M30, H1, H4, D1, M1 - so index alone is not the ordering. Weight by
   // what the timeframe actually is.
   double tf_factor = ZoneTFWeightLow;
   switch(best_tf_index)
   {
      case 0: tf_factor = ZoneTFWeightLow;    break;   // M5
      case 1: tf_factor = ZoneTFWeightMid;    break;   // M15
      case 2: tf_factor = ZoneTFWeightMid;    break;   // M30
      case 3: tf_factor = ZoneTFWeightHigh;   break;   // H1
      case 4: tf_factor = ZoneTFWeightHigher; break;   // H4
      case 5: tf_factor = ZoneTFWeightHigher; break;   // D1
      case 6: tf_factor = ZoneTFWeightLowest; break;   // M1
   }

   base *= tf_factor;

   // V235: a level left and returned to is one the market recognises. The return is worth more than
   // the first touch, because it confirms the first was not simply where price stopped.
   if(EnableZoneRetestCount)
   {
      int zr_returns = 0;
      string zr_detail = "";
      if(ZoneWasRetested(level, zr_returns, zr_detail))
         base *= (1.0 + MathMin(ZoneRetestMaxBonus, zr_returns * ZoneRetestBonusPer));
   }

   // V246: has this level defeated attempts to break it? A level that has been broken twice and
   // reclaimed both times is stronger than one never tested - the attempts are the evidence, and
   // whoever took those breaks is now trapped on the wrong side of it.
   if(EnableFailedBreakRead)
   {
      double bid_fb = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid_fb > 0.0)
      {
         string fb_detail = "";
         double fb_boost = FailedBreakStrengthBoost(level, (level > bid_fb), fb_detail);
         if(fb_boost > 1.0)
            base *= fb_boost;
      }
   }

   // V235: and a level with a long wick through it is where stops were taken or are waiting. Price
   // is drawn back to that - the opposite of what strength is meant to describe.
   if(EnableZoneWickCheck)
   {
      string zw_detail = "";
      double zw = ZoneLiquidityWick(level, zw_detail);
      if(zw > 0.0)
         base *= (1.0 - ZoneWickPenalty * zw);
   }

   return MathMax(0.1, base);
}

int DeepHTFTrendDirection();
bool CounterContextBlockNow(const int dir, string &why, const bool skip_counter_zone = false,
                            const int score_final = -1, const int score_min = -1);   // score_* let a caller pass the score of the signal being TESTED when the live globals describe a different one (queue replay)
int OrderFlowConvictionSign(const ENUM_TIMEFRAMES tf, const int shift);
double OrderFlowConvictionRatio(const ENUM_TIMEFRAMES tf, const int shift);
int TrendReversalDirection(string &reason, bool &divergence_confirmed);int MTFAlignmentCount(const int direction);
double TrendStrengthAgainst(const int dir_i);
int RecentMajorSweepDirection(string &detail);
bool FindLastTwoSwingLows(const ENUM_TIMEFRAMES tf, const int lookback, const int depth,
                          double &low1, int &low1_shift, double &low2, int &low2_shift);
bool FindLastTwoSwingHighs(const ENUM_TIMEFRAMES tf, const int lookback, const int depth,
                           double &high1, int &high1_shift, double &high2, int &high2_shift);
int EQZoneBias(double &range_position_pct);
int RecentEngulfingDirection(string &detail);
int DetectPinBarAt(const ENUM_TIMEFRAMES tf, const int shift);
int DetectEngulfingAt(const ENUM_TIMEFRAMES tf, const int shift);
int DetectStarAt(const ENUM_TIMEFRAMES tf, const int shift);
int DetectOrderBlockReaction(const ENUM_TIMEFRAMES tf);
int DetectTweezerAt(const ENUM_TIMEFRAMES tf, const int shift);
int RecentZoneBreakDirection(string &detail);
bool IsInSessionTransitionWindow(string &detail);
bool IsApproachingWeeklyClose(string &detail);
double RecentGapPointsCached(const ENUM_TIMEFRAMES tf);

// ============================================================================
// V31.6z32 NEW: REVERSAL CONSENSUS. Direct user feedback: "burilishni to'liq
// aqllilashtirmaganmiz" - Sense 1 (the HEAVIEST-weighted sense throughout Grid Intelligence
// and First Entry) only ever used ONE method to detect a reversal: swing structure (Higher-
// Low/Lower-High) + RSI divergence. Meanwhile the SAME session built THREE more genuinely
// independent ways of confirming a reversal - BOS/CHoCH (structure break), Major Sweep
// (liquidity grab + rejection), and Engulfing (candle-level control shift) - and none of them
// were ever combined with the core reversal read. Unifies all four into one non-linear
// consensus, same "genuine multi-signal agreement compounds" philosophy as Exhaustion
// Consensus and Grid Intelligence itself - a reversal confirmed by structure AND a sweep AND
// an engulfing candle simultaneously is real, strong evidence, not the same as swing+RSI alone.
// ============================================================================
double ReversalConsensusScoreRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableReversalConsensus || direction == 0)
      return 0.5;

   int confirm_count = 0;
   string confirms = "";

   string tr_reason = "";
   bool   tr_div = false;
   int    tr_dir = TrendReversalDirection(tr_reason, tr_div);
   if(tr_dir == direction)
   {
      confirm_count++;
      confirms += "Swing ";
      if(tr_div)
      {
         confirm_count++;
         confirms += "+RSIdiv ";
      }
   }

   if(EnableStructureConfluence && G_DBOS_DIR == direction)
   {
      confirm_count++;
      confirms += "BOS/CHoCH ";
   }

   string sweep_detail = "";
   int sweep_dir = RecentMajorSweepDirection(sweep_detail);
   if(sweep_dir == direction)
   {
      confirm_count++;
      confirms += "Sweep ";
   }

   string eng_detail = "";
   int eng_dir = RecentEngulfingDirection(eng_detail);
   if(eng_dir == direction)
   {
      confirm_count++;
      confirms += "Engulfing ";
   }

   // FEATURE(candlestick-models): Pin Bar (Hammer/Shooting Star) confirmation.
   if(EnablePinBarAwareness)
   {
      int pin_look = MathMax(1, CandlePatternLookbackBars);
      for(int s = 1; s <= pin_look; s++)
      {
         if(DetectPinBarAt(SignalTF, s) == direction)
         {
            confirm_count++;
            confirms += "PinBar ";
            break;
         }
      }
   }

   // FEATURE(candlestick-models): Morning/Evening Star (3-candle) confirmation.
   if(EnableStarAwareness)
   {
      int star_look = MathMax(1, CandlePatternLookbackBars);
      for(int s = 1; s <= star_look; s++)
      {
         if(DetectStarAt(SignalTF, s) == direction)
         {
            confirm_count++;
            confirms += "Star ";
            break;
         }
      }
   }

   // FEATURE(order-block): institutional order block reaction (highest-grade of the candle group).
   if(EnableOrderBlockAwareness && DetectOrderBlockReaction(SignalTF) == direction)
   {
      confirm_count++;
      confirms += "OrderBlock ";
   }

   // FEATURE(tweezer): tweezer top/bottom double-rejection.
   if(EnableTweezerAwareness)
   {
      int tw_look = MathMax(1, CandlePatternLookbackBars);
      for(int s = 1; s <= tw_look; s++)
      {
         if(DetectTweezerAt(SignalTF, s) == direction)
         {
            confirm_count++;
            confirms += "Tweezer ";
            break;
         }
      }
   }

   // FEATURE(consensus-quality) C: a reversal AT a strong S/R zone is higher quality. If any
   // signal fired and price is sitting at a strong wall in our favour, add one bonus confirmation.
   if(EnableConsensusZoneQuality && confirm_count > 0)
   {
      double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(px > 0.0)
      {
         // For a bullish reversal we lean on SUPPORT below; for bearish, RESISTANCE above.
         double zone = (direction > 0) ? ZoneMapNearestSupport(px) : ZoneMapNearestResistance(px);
         if(zone > 0.0 &&
            PointsBetween(px, zone) <= (double)ConsensusZoneProximityPts &&
            ZoneMapStrength(zone) >= ConsensusZoneMinStrength)
         {
            confirm_count++;
            confirms += "ZoneQ ";
         }
      }
   }

   // FEATURE(consensus-quality) B: a candle reversal that ALSO shows on the higher TF is more
   // reliable than one seen only on the signal TF. If a pin bar / engulfing / star / tweezer
   // agrees on StructureTF too, add one bonus confirmation.
   if(EnableConsensusMultiTF && confirm_count > 0 && StructureTF != SignalTF)
   {
      bool htf_agrees = (DetectPinBarAt(StructureTF, 1) == direction) ||
                        (DetectEngulfingAt(StructureTF, 1) == direction) ||
                        (DetectStarAt(StructureTF, 1) == direction) ||
                        (DetectTweezerAt(StructureTF, 1) == direction);
      if(htf_agrees)
      {
         confirm_count++;
         confirms += "MultiTF ";
      }
   }

   // FEATURE(consensus-quality) A: order-flow pressure agreeing with the reversal adds one bonus
   // confirmation. Kept last and as a bonus only - tick-volume order flow is the least reliable
   // proxy, so it can lift a reversal's confidence but never gate it.
   if(EnableConsensusOrderFlow && confirm_count > 0)
   {
      // FIX(orderflow-magnitude): OrderFlowConvictionSign() classifies VOLUME MAGNITUDE
      // (+1 = heavy/confirmed, -1 = thin/weak, 0 = ordinary) from iVolume alone - it carries NO
      // bullish/bearish direction. Tying it to the entry direction made the test ASYMMETRIC:
      // it demanded heavy volume to confirm a BUY but thin volume to confirm a SELL.
      if(OrderFlowConvictionSign(SignalTF, 1) > 0)
      {
         confirm_count++;
         confirms += "OrderFlow ";
      }
   }

   if(confirm_count == 0)
      return 0.5;

   detail = StringFormat("REVERSAL-CONSENSUS(%d): %s", confirm_count, confirms);

   // Non-linear: each ADDITIONAL independent confirmation is worth disproportionately more
   // than the last, matching the same philosophy used throughout today's session.
   if(confirm_count == 1) return ReversalConsensus1Score;
   if(confirm_count == 2) return ReversalConsensus2Score;
   if(confirm_count == 3) return ReversalConsensus3Score;
   return MathMin(0.98, ReversalConsensus3Score + (confirm_count - 3) * ReversalConsensusExtraStep);
}

double ReversalConsensusScore(const int direction, string &detail)
{
   static int    rc_cache_bar = -1;
   static int    rc_cache_dir = 0;
   static double rc_cache_score = 0.5;
   static string rc_cache_detail = "";
   if(rc_cache_bar > G_BARS_SEEN) rc_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(rc_cache_bar != G_BARS_SEEN || rc_cache_dir != direction)
   {
      rc_cache_score = ReversalConsensusScoreRaw(direction, rc_cache_detail);
      rc_cache_bar = G_BARS_SEEN;
      rc_cache_dir = direction;
   }

   detail = rc_cache_detail;
   return rc_cache_score;
}

// ============================================================================
// V31.6z41 NEW: SMART EARLY EXIT. Direct user request: Basket SL was a single, fixed 50%
// threshold, completely disconnected from every piece of intelligence built this session
// (Global/Local Trend, Exhaustion Consensus, Reversal Consensus, Structure Confluence). A
// basket already meaningfully underwater with EVERY sign pointing to "this isn't turning
// around soon" still had to wait the full 50% before the bot would act - even when the
// evidence was overwhelming well before that point.
//
// Explicit user guidance: NOT too early - only exit early when there is genuinely no
// opportunity left, not on a single weak signal. Deliberately conservative:
//   - DD must already be meaningfully elevated (default 32%) - well below the 50% hard floor,
//     but not so low that ordinary fluctuation could trigger it.
//   - Requires at least 3 of 4 INDEPENDENT signal types to strongly agree the adverse move has
//     real, ongoing strength with no sign of let-up - not a single indicator's opinion.
//   - Requires the condition to PERSIST for several consecutive bars (default 3), not fire on
//     one noisy reading - a genuinely deteriorating situation stays deteriorated bar to bar.
// The hard 50% Basket SL is completely untouched and remains the ultimate backstop regardless.
// ============================================================================

bool SmartEarlyExitShouldTrigger(string &reason)
{
   reason = "";
   if(!EnableSmartEarlyExit || G_BASKET_ORDERS <= 0)
   {
      G_SEE_PERSIST_BARS = 0;
      return false;
   }

   if(G_BASKET_DIRECTION != POSITION_TYPE_BUY && G_BASKET_DIRECTION != POSITION_TYPE_SELL)
   {
      G_SEE_PERSIST_BARS = 0;
      return false;
   }

   if(G_BASKET_DD_PERCENT < SmartEarlyExitMinDDPercent)
   {
      G_SEE_PERSIST_BARS = 0;
      return false;
   }

   int dir_i = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;

   int strong_against_count = 0;

   // V116: a structural turn against the basket is one of the strongest confirmations available -
   // it is the market's own sequence breaking, not an indicator reading. Counted alongside the
   // existing votes rather than overriding them, so the exit still needs broad agreement.
   if(StructureBreakCountsAsExitConfirm)
   {
      string sab_exit_detail = "";
      if(StructureAgainstBasket(sab_exit_detail))
         strong_against_count++;
   }
   string details = "";

   string g_detail = "";
   double global_conf = GlobalTrendConfidence(dir_i, g_detail);
   if(global_conf <= -SmartEarlyExitGlobalTrendMinAgainst)
   {
      strong_against_count++;
      details += "Global-firmly-against ";
   }

   // Checks exhaustion in the ADVERSE direction (against our basket) - if the move against us
   // shows NO exhaustion signs, that means it still has real, fresh strength, not fading.
   string ec_detail = "";
   double ec_against_score = ExhaustionConsensusScore(-dir_i, ec_detail);
   if(ec_against_score >= 0.5)
   {
      strong_against_count++;
      details += "adverse-move-shows-no-exhaustion ";
   }

   if((dir_i > 0 && G_DBOS_DIR < 0) || (dir_i < 0 && G_DBOS_DIR > 0))
   {
      strong_against_count++;
      details += "Structure-against ";
   }

   string rc_detail = "";
   double rc_against_score = ReversalConsensusScore(-dir_i, rc_detail);
   if(rc_against_score >= SmartEarlyExitReversalConsensusMin)
   {
      strong_against_count++;
      details += "Reversal-consensus-confirms-against ";
   }

   if(strong_against_count < SmartEarlyExitMinConfirmations)
   {
      G_SEE_PERSIST_BARS = 0;
      return false;
   }

   // Persistence check - the condition must hold across consecutive bars, not fire on one
   // noisy reading. Resets if the direction changes or a bar is skipped.
   //
   // FIX(see-persist-counts-ticks): the counter used to do a bare `G_SEE_PERSIST_BARS++` on every
   // call. This function runs from OnTick, so it counted TICKS, not bars - on XAUUSD the default
   // SmartEarlyExitPersistBars = 3 was satisfied in well under a second, and the "skipped bar"
   // reset the comment describes was never implemented at all. That turned a ~45-minute
   // confirmation requirement into three consecutive ticks, and what it authorises is
   // CloseSirusBasket() - realising the entire basket loss on a sub-second sample of three
   // indicators. Now anchored to G_BARS_SEEN: at most one increment per new bar, and a gap in the
   // run starts the count again.
   if(G_SEE_PERSIST_DIR != dir_i || G_SEE_PERSIST_BARS <= 0 || G_SEE_PERSIST_LAST_BAR < 0)
   {
      G_SEE_PERSIST_DIR      = dir_i;
      G_SEE_PERSIST_BARS     = 1;
      G_SEE_PERSIST_LAST_BAR = G_BARS_SEEN;
   }
   else if(G_BARS_SEEN > G_SEE_PERSIST_LAST_BAR)
   {
      if((G_BARS_SEEN - G_SEE_PERSIST_LAST_BAR) > 1)
         G_SEE_PERSIST_BARS = 1;      // the run was broken - this is a fresh streak
      else
         G_SEE_PERSIST_BARS++;
      G_SEE_PERSIST_LAST_BAR = G_BARS_SEEN;
   }
   // Same bar, same direction: no change. Persistence is measured in BARS, not ticks.

   if(G_SEE_PERSIST_BARS < MathMax(1, SmartEarlyExitPersistBars))
   {
      reason = StringFormat("building (%d/%d bars): %s", G_SEE_PERSIST_BARS, SmartEarlyExitPersistBars, details);
      return false;
   }

   reason = StringFormat("SMART EARLY EXIT: DD=%.1f%% (%d/4 strong against, %d bars persistent): %s",
                         G_BASKET_DD_PERCENT, strong_against_count, G_SEE_PERSIST_BARS, details);
   return true;
}

// ============================================================================
// V31.6z36 NEW: MTF ALIGNMENT CONFIDENCE - the same "binary count vs continuous magnitude"
// upgrade already applied to Global/Local Trend, found to still be missing here. The existing
// MTFAlignmentCount() stays untouched (15+ call sites use it as a simple ">=2 agree" threshold
// check, too risky to touch all of them) - this is a NEW, complementary, magnitude-aware
// reading used specifically at the two most decision-critical consumption points (Grid
// Intelligence Sense 3, Trend Quality Factor 2). A barely-positive M15 close-comparison no
// longer counts the same as a strongly ADX-confirmed H4 trend - each timeframe's vote is now
// weighted by its own conviction, not just its direction.
// ============================================================================
double MTFAlignmentConfidenceRaw(const int direction, string &detail)
{
   detail = "";
   if(!EnableMTFAlignment || !EnableMTFConfidence || direction == 0)
      return 0.0;

   double m15_conf = 0.0, h1_conf = 0.0, h4_conf = 0.0, d1_conf = 0.0;

   double m15_adx = 0.0, m15_plus = 0.0, m15_minus = 0.0;
   CachedADXSnapshot(PERIOD_M15, MTFConfidenceADXPeriod, m15_adx, m15_plus, m15_minus);
   int m15_adx_dir = (m15_plus > m15_minus) ? 1 : ((m15_minus > m15_plus) ? -1 : 0);
   if(m15_adx >= MTFConfidenceMinADX && m15_adx_dir != 0)
   {
      double mag = MathMax(0.0, MathMin(1.0, (m15_adx - MTFConfidenceMinADX) / MathMax(1.0, MTFConfidenceADXFullStrength)));
      m15_conf = (m15_adx_dir == direction) ? mag : -mag;
   }
   else
   {
      int simple = SimpleTFDirection(PERIOD_M15, MTFAlignmentM15LookbackBars);
      m15_conf = (simple == direction) ? MTFConfidenceWeakValue : ((simple == -direction) ? -MTFConfidenceWeakValue : 0.0);
   }

   if(KalmanTrendReady())
   {
      double kalman_pts = G_KALMAN_TREND / _Point;
      if(MathAbs(kalman_pts) > KalmanTrendMinPoints)
      {
         double mag = MathMax(0.0, MathMin(1.0, MathAbs(kalman_pts) / (KalmanTrendMinPoints * 3.0)));
         int k_dir = (kalman_pts > 0) ? 1 : -1;
         h1_conf = (k_dir == direction) ? mag : -mag;
      }
   }
   else
   {
      double h1_adx = 0.0, h1_plus = 0.0, h1_minus = 0.0;
      CachedADXSnapshot(PERIOD_H1, MTFConfidenceADXPeriod, h1_adx, h1_plus, h1_minus);
      int h1_adx_dir = (h1_plus > h1_minus) ? 1 : ((h1_minus > h1_plus) ? -1 : 0);
      if(h1_adx >= MTFConfidenceMinADX && h1_adx_dir != 0)
      {
         double mag = MathMax(0.0, MathMin(1.0, (h1_adx - MTFConfidenceMinADX) / MathMax(1.0, MTFConfidenceADXFullStrength)));
         h1_conf = (h1_adx_dir == direction) ? mag : -mag;
      }
      else
      {
         int simple = SimpleTFDirection(PERIOD_H1, MTFAlignmentH1LookbackBars);
         h1_conf = (simple == direction) ? MTFConfidenceWeakValue : ((simple == -direction) ? -MTFConfidenceWeakValue : 0.0);
      }
   }

   double h4_adx = 0.0, h4_plus = 0.0, h4_minus = 0.0;
   CachedADXSnapshot(PERIOD_H4, MTFConfidenceADXPeriod, h4_adx, h4_plus, h4_minus);
   int h4_adx_dir = (h4_plus > h4_minus) ? 1 : ((h4_minus > h4_plus) ? -1 : 0);
   if(h4_adx >= MTFConfidenceMinADX && h4_adx_dir != 0)
   {
      double mag = MathMax(0.0, MathMin(1.0, (h4_adx - MTFConfidenceMinADX) / MathMax(1.0, MTFConfidenceADXFullStrength)));
      h4_conf = (h4_adx_dir == direction) ? mag : -mag;
   }
   else
   {
      int simple = SimpleTFDirection(PERIOD_H4, MTFAlignmentH4LookbackBars);
      h4_conf = (simple == direction) ? MTFConfidenceWeakValue : ((simple == -direction) ? -MTFConfidenceWeakValue : 0.0);
   }

   int d1_dir = D1OverallDirection();
   d1_conf = (d1_dir == direction) ? MTFConfidenceD1Value : ((d1_dir == -direction) ? -MTFConfidenceD1Value : 0.0);

   double avg_confidence = (m15_conf + h1_conf + h4_conf + d1_conf) / 4.0;

   detail = StringFormat("MTF-conf=%.2f(M15=%.2f,H1=%.2f,H4=%.2f,D1=%.2f)",
                         avg_confidence, m15_conf, h1_conf, h4_conf, d1_conf);
   return MathMax(-1.0, MathMin(1.0, avg_confidence));
}

double MTFAlignmentConfidence(const int direction, string &detail)
{
   static int    mac_cache_bar = -1;
   static int    mac_cache_dir = 0;
   static double mac_cache_score = 0.0;
   static string mac_cache_detail = "";
   if(mac_cache_bar > G_BARS_SEEN) mac_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(mac_cache_bar != G_BARS_SEEN || mac_cache_dir != direction)
   {
      mac_cache_score = MTFAlignmentConfidenceRaw(direction, mac_cache_detail);
      mac_cache_bar = G_BARS_SEEN;
      mac_cache_dir = direction;
   }

   detail = mac_cache_detail;
   return mac_cache_score;
}

double SweepHighLevel()
{
   int lookback = SweepLookbackBars;
   if(lookback < 3)
      lookback = 3;
   double raw = HighestHigh(SignalTF, lookback, 2);

   // V31.6c robot-eyes upgrade: prefer a real, swing-confirmed, multi-TF Zone Map wall over
   // a raw recent-candle extreme, so the sweep detector reacts to genuinely significant
   // liquidity, not an arbitrary wick that happened to be the highest in the lookback.
   if(EnableZoneAwareSweep && raw > 0.0)
   {
      double zone = ZoneMapNearestResistance(raw - MathMax(1, SweepLookbackBars) * _Point);
      if(zone > 0.0 && MathAbs(zone - raw) <= (double)SweepLookbackBars * 5.0 * _Point)
         return zone;
   }

   return raw;
}

double SweepLowLevel()
{
   int lookback = SweepLookbackBars;
   if(lookback < 3)
      lookback = 3;
   double raw = LowestLow(SignalTF, lookback, 2);

   if(EnableZoneAwareSweep && raw > 0.0)
   {
      double zone = ZoneMapNearestSupport(raw + MathMax(1, SweepLookbackBars) * _Point);
      if(zone > 0.0 && MathAbs(zone - raw) <= (double)SweepLookbackBars * 5.0 * _Point)
         return zone;
   }

   return raw;
}

bool DetectSweepBuy(string &reason, int &score)
{
   if(!ScannerAllowSweep)
   {
      reason = "sweep disabled";
      return false;
   }

   double sweep_low = SweepLowLevel();
   double l1 = CandleLow(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double lower = LowerWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(sweep_low <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || range <= 0.0)
   {
      reason = "sweep buy data not ready";
      return false;
   }

   bool swept = (l1 < sweep_low && c1 > sweep_low);
   // FEATURE(wick-sweep): a genuine bullish sweep takes the low with the WICK, then the body
   // closes back above the level. If the body itself broke below, price accepted lower - that's
   // a breakdown, not a stop-hunt, so it shouldn't count as a sweep-buy setup.
   bool wick_swept = IsWickSweepLow(SignalTF, 1, sweep_low);
   bool rejection = (lower / range >= 0.35);
   bool bullish_close = (c1 >= o1);

   score = 0;
   if(swept) score += 3;
   if(rejection) score += 2;
   if(bullish_close) score += 1;
   if(G_MARKET_STATE == MARKET_RANGE || G_MARKET_STATE == MARKET_EXHAUSTION) score += 1;

   string vol_tag = "";
   if(EnableSweepVolumeCheck)
   {
      // V31.6c robot-eyes upgrade: a genuine stop-hunt sweep tends to trade on real volume
      // (stops triggering, then real buyers absorbing) - a bonus, not a requirement, since
      // Order Flow is a rough proxy and shouldn't gate an otherwise-valid pattern.
      if(OrderFlowConvictionSign(SignalTF, 1) > 0)
      {
         score += 1;
         vol_tag = " +1 volume;";
      }
   }

   // FEATURE(wick-sweep): confirmed wick sweep (body held above the level) is the real
   // stop-hunt - reward it, and require it when the filter is on.
   string wick_tag = "";
   if(wick_swept)
   {
      score += 1;
      wick_tag = " +1 wickSweep;";
   }

   reason = StringFormat("sweptLow=%s wick=%s | low=%.2f level=%.2f close=%.2f | lowerWick/range=%.2f | score=%d%s%s",
                         BoolText(swept), BoolText(wick_swept), l1, sweep_low, c1, lower / range, score, vol_tag, wick_tag);

   // FREE(sweep): wick sweep is a strong CONFIRMATION (bonus points above) but not a gate. The
   // core pattern - low pierced the level, price rejected and closed back above - is still a
   // valid sweep-buy even if the body technically nicked the level. This keeps sweeps firing
   // freely (user request) while still rewarding the cleaner wick-only version.
   return (swept && rejection);
}

bool DetectSweepSell(string &reason, int &score)
{
   if(!ScannerAllowSweep)
   {
      reason = "sweep disabled";
      return false;
   }

   double sweep_high = SweepHighLevel();
   double h1 = CandleHigh(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double o1 = CandleOpen(SignalTF, 1);
   double upper = UpperWickPoints(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(sweep_high <= 0.0 || h1 <= 0.0 || c1 <= 0.0 || range <= 0.0)
   {
      reason = "sweep sell data not ready";
      return false;
   }

   bool swept = (h1 > sweep_high && c1 < sweep_high);
   // FEATURE(wick-sweep): genuine bearish sweep takes the high with the WICK, body closes back below.
   bool wick_swept = IsWickSweepHigh(SignalTF, 1, sweep_high);
   bool rejection = (upper / range >= 0.35);
   bool bearish_close = (c1 <= o1);

   score = 0;
   if(swept) score += 3;
   if(rejection) score += 2;
   if(bearish_close) score += 1;
   if(G_MARKET_STATE == MARKET_RANGE || G_MARKET_STATE == MARKET_EXHAUSTION) score += 1;

   string vol_tag = "";
   if(EnableSweepVolumeCheck)
   {
      // FIX(orderflow-sign): a bearish sweep-sell should be confirmed by BEARISH order flow
      // (sign < 0). The old code checked > 0, rewarding a sell setup for BULLISH flow - the
      // wrong direction. Mirror of the buy path, now with the correct sign.
      // FIX(orderflow-magnitude): the FIX(orderflow-sign) note above was itself mistaken - this
      // is volume magnitude, not direction. Restored to match DetectSweepBuy's `> 0`, whose own
      // comment states the real intent: a genuine stop-hunt sweep trades on REAL VOLUME.
      if(OrderFlowConvictionSign(SignalTF, 1) > 0)
      {
         score += 1;
         vol_tag = " +1 volume;";
      }
   }

   // FEATURE(wick-sweep): reward and (when enabled) require the wick sweep.
   string wick_tag = "";
   if(wick_swept)
   {
      score += 1;
      wick_tag = " +1 wickSweep;";
   }

   reason = StringFormat("sweptHigh=%s wick=%s | high=%.2f level=%.2f close=%.2f | upperWick/range=%.2f | score=%d%s%s",
                         BoolText(swept), BoolText(wick_swept), h1, sweep_high, c1, upper / range, score, vol_tag, wick_tag);

   // FREE(sweep): wick sweep confirms but does not gate - see DetectSweepBuy note.
   return (swept && rejection);
}
