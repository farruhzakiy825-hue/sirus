//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 11_Expectancy_MTF_News                          |
//| Expectancy, ladder shape, MTF/DXY/order flow, calendar           |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// What is this level worth, given how it has defended itself? Returns a multiplier.
double FailedBreakStrengthBoost(const double level, const bool as_resistance, string &detail)
{
   detail = "";
   int bars_since = 0;
   int failures = FailedBreakCount(level, as_resistance, bars_since, detail);

   if(failures <= 0)
      return 1.0;

   // Each defeated attempt adds, with diminishing returns - two is confirmation, six
   // means price is grinding against it and it will probably go.
   double boost = 1.0 + MathMin(FailedBreakMaxBoost,
                                (double)failures * FailedBreakBoostPer);

   // A defence that happened recently matters more than one from hours ago - the
   // traders caught by it are still positioned.
   if(bars_since > FailedBreakFreshBars)
   {
      double age_factor = 1.0 - MathMin(0.6, (double)(bars_since - FailedBreakFreshBars) /
                                             MathMax(1.0, (double)FailedBreakLookback));
      boost = 1.0 + (boost - 1.0) * age_factor;
   }

   return boost;
}


// ============================================================================
// V245: DOES THE TARGET LAND INSIDE SOMETHING?
// ----------------------------------------------------------------------------
// From a live entry: a buy at 4491.35 with the target at 4493.85, and a band running
// 4492.00 to 4494.15 that had turned price away three times that day. The target sat
// in the middle of it.
//
// RoomToTargetPoints already checks for a wall ahead, and it reads
// ZoneMapNearestResistance - a single price. Against a band it returns the near edge
// or the far one depending on which swing happened to be cached, and either way the
// answer is a point rather than a range. Here it saw 4494.15, measured $2.80 of room,
// and reported plenty for a $2.50 target.
//
// The real figure was $0.65 - the distance to where the band STARTS. Everything past
// that is inside the thing that has been rejecting price.
//
// So the question is not "is there a wall further out than my target" but "does my
// target land inside a band" - and for a band the near edge is what matters, because
// that is where price starts meeting resistance rather than where it finishes.
// ============================================================================

// Does the target fall inside a band that has been holding? Returns 0..1.
double TargetInsideBand(const int entry_dir, const double target_price,
                        double &band_lo, double &band_hi, string &detail)
{
   band_lo = 0.0; band_hi = 0.0;
   detail = "";

   if(!EnableTargetBandCheck || entry_dir == 0 || target_price <= 0.0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   // ZonePriceInsideBand looks for a band around the CURRENT price. Here the band that
   // matters is around the TARGET, which may be somewhere price is not yet - so the
   // swing cluster has to be built around that price instead.
   ENUM_TIMEFRAMES tfs[3];
   bool enabled[3];
   tfs[0] = PERIOD_M5;  enabled[0] = ZoneBandUseM5;
   tfs[1] = PERIOD_M15; enabled[1] = ZoneBandUseM15;
   tfs[2] = PERIOD_H1;  enabled[2] = ZoneBandUseH1;

   double best_lo = 0.0, best_hi = 0.0;
   int    best_count = 0;

   for(int i = 0; i < 3; i++)
   {
      if(!enabled[i])
         continue;
      double lo = 0.0, hi = 0.0;
      int cnt = 0;
      if(!ZoneBandOnTF(tfs[i], target_price, lo, hi, cnt))
         continue;
      if(cnt > best_count)
      {
         best_count = cnt;
         best_lo = lo;
         best_hi = hi;
      }
   }

   if(best_count <= 0 || best_hi <= best_lo)
      return 0.0;

   band_lo = best_lo;
   band_hi = best_hi;

   // The near edge is what the trade actually has to reach. For a buy that is the
   // bottom of the band - price starts meeting sellers there, not at the top.
   double near_edge = (entry_dir > 0) ? best_lo : best_hi;

   // How much of the intended move is real room, and how much is inside the band?
   double total = MathAbs(target_price - mid) / _Point;
   double clear = (entry_dir > 0) ? (near_edge - mid) / _Point : (mid - near_edge) / _Point;

   if(total <= 0.0)
      return 0.0;
   if(clear >= total)
      return 0.0;                    // the band starts beyond the target - not a problem

   double inside_share = 1.0 - MathMax(0.0, clear) / total;

   // A band that has held more often matters more.
   double strength = MathMax(ZoneMapStrengthByTouches(best_lo),
                             ZoneMapStrengthByTouches(best_hi));
   if(strength < TargetBandMinStrength)
      return 0.0;

   double str_f = MathMin(1.0, strength / MathMax(0.1, BandGuardFullStrength));
   double severity = inside_share * (0.4 + 0.6 * str_f);

   detail = StringFormat("target %.2f sits inside a %.2f-%.2f band - %.0f pts of clear room, not %.0f",
                         target_price, best_lo, best_hi, MathMax(0.0, clear), total);
   return MathMax(0.0, MathMin(1.0, severity));
}


// ============================================================================
// V244: CAN THIS BASKET ACTUALLY GET HOME?
// ----------------------------------------------------------------------------
// BasketHealthIndex measures what the basket has SPENT - drawdown against the stop,
// rungs against the maximum, margin against the ceiling, age against a threshold.
// Every component answers "how much is used up".
//
// None of them answers the question that decides the outcome: is the target still
// reachable? A basket five rungs deep with its target four dollars away is in a
// different position from one five rungs deep with its target forty cents away, and
// on every reading the EA currently takes they look identical.
//
// Reachability is measurable. The distance to target, expressed in the units price
// actually moves in - ATR - is an estimate of how long the basket needs. Four ATR is
// a session. Ten is a day. And the answer changes as the ladder grows, because each
// addition drags the average entry further from where price is.
//
// This is a reading, not a rule. It does not close baskets. It tells the rest of the
// EA - and whoever is watching - whether the recovery being waited for is a short
// wait or an unrealistic one.
// ============================================================================

// How far is the basket from its target, and how long would that take?
//   distance_atr - the gap in ATR units
//   returns 0..1 - how reachable the target looks (1 = close, 0 = unrealistic)
double BasketReachability(double &distance_atr, string &detail)
{
   distance_atr = 0.0;
   detail = "";

   if(!EnableBasketReach || G_BASKET_ORDERS <= 0 || _Point <= 0.0)
      return 1.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0 || G_BASKET_AVG_PRICE <= 0.0)
      return 1.0;

   // Where does the basket need price to get to? The target sits beyond the average
   // entry by the basket's TP distance.
   double tp_pts = (G_PACK2_DYNAMIC_TP > 0.0) ? G_PACK2_DYNAMIC_TP : BaseBasketTPPoints();
   if(tp_pts <= 0.0)
      return 1.0;

   int dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
   double target = G_BASKET_AVG_PRICE + (double)dir * tp_pts * _Point;

   // How far is that from here, in the direction the basket needs?
   double gap_pts = (dir > 0) ? (target - mid) / _Point : (mid - target) / _Point;

   if(gap_pts <= 0.0)
   {
      detail = "target already reached";
      return 1.0;
   }

   double atr_pts = ATRPointsManual(LocalStructureTF, ATRPeriod, 1);
   if(atr_pts <= 0.0)
      return 1.0;

   distance_atr = gap_pts / atr_pts;

   // Below the comfortable figure this is an ordinary wait; beyond the far one it is
   // asking for a move the timeframe does not usually produce.
   double reach;
   if(distance_atr <= BasketReachComfortATR)
      reach = 1.0;
   else if(distance_atr >= BasketReachFarATR)
      reach = 0.0;
   else
      reach = 1.0 - (distance_atr - BasketReachComfortATR) /
                    MathMax(0.1, BasketReachFarATR - BasketReachComfortATR);

   detail = StringFormat("%.0f pts to target (%.1f ATR)", gap_pts, distance_atr);
   return MathMax(0.0, MathMin(1.0, reach));
}

// What would the next addition do to that distance? The ladder's own arithmetic works
// against it here: every rung pulls the average further from price, so the target it
// is trying to reach moves away as the basket grows.
double ReachAfterNextRung(string &detail)
{
   detail = "";
   if(!EnableBasketReach || G_BASKET_ORDERS <= 0 || _Point <= 0.0)
      return 1.0;

   double now_atr = 0.0;
   string now_detail = "";
   double now_reach = BasketReachability(now_atr, now_detail);

   if(G_NEXT_GRID_PRICE <= 0.0 || G_BASKET_AVG_PRICE <= 0.0)
      return now_reach;

   // Where would the average land after the next rung? Approximate, using the intended
   // lot for it against the volume already in.
   double next_lot = StartLot * MathPow(LadderMultiplier(), (double)G_BASKET_ORDERS);
   double cur_vol = G_BASKET_VOLUME;
   if(cur_vol <= 0.0 || next_lot <= 0.0)
      return now_reach;

   double new_avg = ((G_BASKET_AVG_PRICE * cur_vol) + (G_NEXT_GRID_PRICE * next_lot)) /
                    (cur_vol + next_lot);

   double tp_pts = (G_PACK2_DYNAMIC_TP > 0.0) ? G_PACK2_DYNAMIC_TP : BaseBasketTPPoints();
   int dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
   double new_target = new_avg + (double)dir * tp_pts * _Point;

   double atr_pts = ATRPointsManual(LocalStructureTF, ATRPeriod, 1);
   if(atr_pts <= 0.0)
      return now_reach;

   // Measured from where the addition would happen, since that is where price is when
   // the ladder grows.
   double gap = (dir > 0) ? (new_target - G_NEXT_GRID_PRICE) / _Point
                          : (G_NEXT_GRID_PRICE - new_target) / _Point;
   double new_atr = gap / atr_pts;

   detail = StringFormat("target moves %.1f -> %.1f ATR after the next rung", now_atr, new_atr);

   if(new_atr <= BasketReachComfortATR)
      return 1.0;
   if(new_atr >= BasketReachFarATR)
      return 0.0;
   return 1.0 - (new_atr - BasketReachComfortATR) /
                MathMax(0.1, BasketReachFarATR - BasketReachComfortATR);
}


// ============================================================================
// V242: WHAT THE SYSTEM IS ACTUALLY EARNING
// ----------------------------------------------------------------------------
// A grid produces a very high win rate and that number tells you almost nothing. Most
// baskets close at target for $2.50; the occasional one stops out for $25 or more.
// Eighty-five percent wins with those figures is a losing system, and it looks like a
// winning one on every screen the EA draws.
//
//   EV = 0.85 x 2.50 - 0.15 x 25.00 = 2.125 - 3.750 = -1.625
//
// The EA tracks streaks, score bands and basket ages. It has never once computed the
// only number that says whether any of it works: what an average basket is worth.
//
// This is not a filter and it does not block trades. It is a reading - the equivalent
// of looking at the account curve rather than the last trade - and it belongs on the
// dashboard beside everything else, because a rising win rate with a falling
// expectancy is the exact pattern that ends an account, and nothing else here would
// show it.
// ============================================================================

double G_EV_WINS       = 0.0;
double G_EV_LOSSES     = 0.0;
double G_EV_WIN_SUM    = 0.0;    // total money made on winning baskets
double G_EV_LOSS_SUM   = 0.0;    // total money lost on losing ones
double G_EV_WORST      = 0.0;    // largest single loss seen

string EVGVKey(const string suffix)
{
   return StringFormat("NAVIUS_EV_%s_%d_%s", _Symbol, MagicNumber, suffix);
}

void EVSave()
{
   if(!EnableExpectancy || !PersistExpectancy)
      return;
   GlobalVariableSet(EVGVKey("W"),  G_EV_WINS);
   GlobalVariableSet(EVGVKey("L"),  G_EV_LOSSES);
   GlobalVariableSet(EVGVKey("WS"), G_EV_WIN_SUM);
   GlobalVariableSet(EVGVKey("LS"), G_EV_LOSS_SUM);
   GlobalVariableSet(EVGVKey("WORST"), G_EV_WORST);
}

void EVRestore()
{
   if(!EnableExpectancy || !PersistExpectancy)
      return;
   if(GlobalVariableCheck(EVGVKey("W")))     G_EV_WINS     = GlobalVariableGet(EVGVKey("W"));
   if(GlobalVariableCheck(EVGVKey("L")))     G_EV_LOSSES   = GlobalVariableGet(EVGVKey("L"));
   if(GlobalVariableCheck(EVGVKey("WS")))    G_EV_WIN_SUM  = GlobalVariableGet(EVGVKey("WS"));
   if(GlobalVariableCheck(EVGVKey("LS")))    G_EV_LOSS_SUM = GlobalVariableGet(EVGVKey("LS"));
   if(GlobalVariableCheck(EVGVKey("WORST"))) G_EV_WORST    = GlobalVariableGet(EVGVKey("WORST"));
}

// Called when a basket closes, with the money it made or lost.
void EVRecord(const double profit)
{
   if(!EnableExpectancy)
      return;

   if(profit > 0.0)
   {
      G_EV_WINS += 1.0;
      G_EV_WIN_SUM += profit;
   }
   else if(IsMeaningfulLoss(profit))   // BOSQICH 1
   {
      G_EV_LOSSES += 1.0;
      G_EV_LOSS_SUM += -profit;
      if(-profit > G_EV_WORST)
         G_EV_WORST = -profit;
   }

   // Keep the window recent. Conditions change, and a figure covering three months of
   // a different market describes that market rather than this one.
   double total = G_EV_WINS + G_EV_LOSSES;
   if(total > (double)ExpectancyMaxSamples)
   {
      double sc = (double)ExpectancyMaxSamples / total;
      G_EV_WINS *= sc; G_EV_LOSSES *= sc;
      G_EV_WIN_SUM *= sc; G_EV_LOSS_SUM *= sc;
   }

   EVSave();
}

// What is an average basket worth? Returns 0 when there is not enough to say.
double ExpectancyPerBasket(double &win_rate, double &avg_win, double &avg_loss)
{
   win_rate = 0.0; avg_win = 0.0; avg_loss = 0.0;

   double total = G_EV_WINS + G_EV_LOSSES;
   if(!EnableExpectancy || total < (double)ExpectancyMinSamples)
      return 0.0;

   win_rate = G_EV_WINS / total;
   avg_win  = (G_EV_WINS > 0.0)   ? (G_EV_WIN_SUM / G_EV_WINS)   : 0.0;
   avg_loss = (G_EV_LOSSES > 0.0) ? (G_EV_LOSS_SUM / G_EV_LOSSES) : 0.0;

   return win_rate * avg_win - (1.0 - win_rate) * avg_loss;
}

string ExpectancyText()
{
   double wr = 0.0, aw = 0.0, al = 0.0;
   double ev = ExpectancyPerBasket(wr, aw, al);
   double total = G_EV_WINS + G_EV_LOSSES;

   if(total < (double)ExpectancyMinSamples)
      return StringFormat("expectancy: %.0f/%d baskets", total, ExpectancyMinSamples);

   return StringFormat("expectancy: %+.2f per basket | %.0f%% win, +%.2f / -%.2f (worst -%.2f, n=%.0f)",
                       ev, wr * 100.0, aw, al, G_EV_WORST, total);
}


// ============================================================================
// V241: THE SHAPE OF THE LADDER
// ----------------------------------------------------------------------------
// The grid is always the same ladder: seven rungs, 1.30x, even spacing. Distance
// adapts through half a dozen modules; the SHAPE never does.
//
// But the right shape depends on what the basket is facing, and the differences are
// not small:
//
//   A strong level just beyond the entry - two or three rungs, close together, full
//   size. The level either holds, in which case a short ladder was all that was
//   needed, or it breaks, in which case a long one would have been a disaster.
//
//   Against a trend - more rungs, each smaller, spaced wide. Survival matters more
//   than recovery speed, because the recovery may be hours away.
//
//   Nothing readable - commit less rather than guess at a shape.
//
// Choosing at the START is the point. Every rung after the first is constrained by
// the ones before it, so by rung five the ladder's character is already set and
// adjusting the multiplier there cannot undo a first rung sized for a different
// situation.
// ============================================================================

int    G_LADDER_SHAPE     = LADDER_DEFAULT;
int    G_LADDER_ORDERS    = 0;      // rungs this shape allows
double G_LADDER_MULT      = 0.0;    // multiplier this shape uses
double G_LADDER_SPACING   = 1.0;    // spacing factor
string G_LADDER_REASON    = "";

string LadderShapeName(const int shape)
{
   switch(shape)
   {
      case LADDER_SHORT:    return "short";
      case LADDER_LONG:     return "long";
      case LADDER_CAUTIOUS: return "cautious";
   }
   return "default";
}

// Decides the ladder's shape. Called once, as the first entry is placed.
void ChooseLadderShape(const int dir)
{
   G_LADDER_SHAPE   = LADDER_DEFAULT;
   G_LADDER_ORDERS  = MaxOrders;
   G_LADDER_MULT    = LotMultiplier;
   G_LADDER_SPACING = 1.0;
   G_LADDER_REASON  = "";

   if(!EnableLadderShaping || dir == 0 || _Point <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   // Additions go AGAINST the trade, so what matters is the level below a long or
   // above a short - the thing the ladder would be adding down into.
   double anchor = (dir > 0) ? ZoneMapNearestSupport(mid) : ZoneMapNearestResistance(mid);
   bool have_anchor = false;
   double anchor_dist = 0.0;

   if(anchor > 0.0)
   {
      anchor_dist = MathAbs(mid - anchor) / _Point;
      double strength = ZoneMapStrengthByTouches(anchor);
      have_anchor = (anchor_dist <= (double)LadderAnchorMaxDistance &&
                     strength >= LadderAnchorMinStrength);
   }

   string rg_detail = "";
   double against = RegimeContradiction(dir, rg_detail);
   bool unclear = (G_MARKET_STATE == MARKET_UNKNOWN || G_MARKET_STATE == MARKET_CHAOS);

   if(against >= LadderLongFromContradiction)
   {
      // Against a trend. The recovery may be a long way off, so the ladder is built to
      // survive rather than to recover quickly.
      G_LADDER_SHAPE   = LADDER_LONG;
      G_LADDER_ORDERS  = MathMin(MaxOrders + LadderLongExtraOrders, LadderMaxOrdersCap);
      G_LADDER_MULT    = MathMax(1.05, LotMultiplier - LadderLongMultReduction);
      G_LADDER_SPACING = LadderLongSpacing;
      G_LADDER_REASON  = "long ladder: " + rg_detail;
   }
   else if(have_anchor)
   {
      // A level to lean on. Either it holds and a couple of rungs was enough, or it
      // fails - and a long ladder would have been the wrong bet either way.
      G_LADDER_SHAPE   = LADDER_SHORT;
      G_LADDER_ORDERS  = MathMax(2, LadderShortOrders);
      G_LADDER_MULT    = LotMultiplier;
      G_LADDER_SPACING = LadderShortSpacing;
      G_LADDER_REASON  = StringFormat("short ladder: %.2f is %.0f pts behind the entry",
                                      anchor, anchor_dist);
   }
   else if(unclear)
   {
      G_LADDER_SHAPE   = LADDER_CAUTIOUS;
      G_LADDER_ORDERS  = MathMax(2, MaxOrders - LadderCautiousFewerOrders);
      G_LADDER_MULT    = MathMax(1.05, LotMultiplier - LadderCautiousMultReduction);
      G_LADDER_SPACING = 1.0;
      G_LADDER_REASON  = "cautious ladder: market unreadable";
   }

   // FIX(counter-trend-needs-a-reason), tier B: an entry taken against a confirmed global trend gets
   // a SHORTER ladder. This refuses nothing - the trade is already open by the time this runs - it
   // only bounds what being wrong can cost, which matters far more here than direction-picking:
   // the win/loss ratio on a completed ladder is roughly 1:18, so a single stop-out erases eighteen
   // wins. Averaging down into a trend that is still running is precisely how that stop-out happens.
   // Also lowers the projected ladder cost, so it can never make the affordability gate stricter.
   if(G_ENTRY_AGAINST_GLOBAL && CounterTrendMaxLadderOrders > 0 &&
      G_LADDER_ORDERS > CounterTrendMaxLadderOrders)
   {
      G_LADDER_ORDERS = MathMax(2, CounterTrendMaxLadderOrders);
      G_LADDER_REASON = StringFormat("%s | capped to %d rungs - against the global trend",
                                     G_LADDER_REASON, G_LADDER_ORDERS);
      if((LadderShapePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS COUNTER-TREND] ladder capped to %d rungs - entry fights the global trend",
                     G_LADDER_ORDERS);
   }

   if((LadderShapePrintOnUse && VerboseLogs) && G_LADDER_SHAPE != LADDER_DEFAULT)
      PrintFormat("[SIRUS v241 LADDER] %s - %d rungs at %.2fx, spacing %.2f | %s",
                  LadderShapeName(G_LADDER_SHAPE), G_LADDER_ORDERS, G_LADDER_MULT,
                  G_LADDER_SPACING, G_LADDER_REASON);
}

int LadderOrders()
{
   int n = (!EnableLadderShaping || G_LADDER_ORDERS <= 0) ? MaxOrders : G_LADDER_ORDERS;

   // V282: never deeper than the budget covers. Set when the full ladder was projected to cost more
   // than the stop allows - the basket is capped rather than the entry refused, because the first
   // rungs were always affordable and it was the tail that was not.
   if(G_AFFORD_RUNG_CAP > 0 && n > G_AFFORD_RUNG_CAP)
      n = G_AFFORD_RUNG_CAP;

   return MathMax(1, n);
}

double LadderMultiplier()
{
   if(!EnableLadderShaping || G_LADDER_MULT <= 0.0)
      return LotMultiplier;
   return G_LADDER_MULT;
}


double RegimeContradiction(const int basket_dir, string &detail)
{
   detail = "";
   if(!EnableGridRegimeCheck || basket_dir == 0)
      return 0.0;

   // Which way is the market classified, and how sure is that classification?
   int regime_dir = 0;
   if(G_MARKET_STATE == MARKET_TREND_UP)        regime_dir = 1;
   else if(G_MARKET_STATE == MARKET_TREND_DOWN) regime_dir = -1;

   if(regime_dir == 0)
      return 0.0;                    // range, chaos, unknown - the premise is not being tested

   if(regime_dir == basket_dir)
   {
      // The ladder runs WITH the trend. This is the case the arithmetic was designed
      // for - adding on pullbacks inside a move that is going our way.
      detail = StringFormat("ladder runs with the %s trend",
                            (regime_dir > 0 ? "up" : "down"));
      return 0.0;
   }

   // Against. How much that matters depends on how established the trend is - a fresh
   // classification is a guess, one confirmed across timeframes is not.
   double severity = RegimeAgainstBase;
   string parts = StringFormat("basket fights the %s trend; ",
                               (regime_dir > 0 ? "up" : "down"));

   // Timeframe agreement is the strongest confirmation available: three scales saying
   // the same thing is a trend, one scale saying it is a reading.
   if(EnableStructureMTF)
   {
      int    al_dir = 0;
      double al_w = 0.0;
      string al_detail = "";
      int    al = StructureAlignment(al_dir, al_w, al_detail);
      if(al == TFALIGN_FULL && al_dir == regime_dir)
      {
         severity += RegimeAlignedBonus;
         parts += "all timeframes agree; ";
      }
   }

   // And whether the structure is still producing new extremes in that direction. A
   // trend that has stopped extending is one the ladder can survive; one still making
   // new lows against a long basket is not.
   if(EnableLocalStructure)
   {
      LocalStructureUpdate();
      if(G_LS_DIR == regime_dir && G_LS_STATE == LSTRUCT_EXPANDING)
      {
         severity += RegimeExpandingBonus;
         parts += "and still expanding; ";
      }
      else if(G_LS_DIR == regime_dir && G_LS_STATE == LSTRUCT_FADING)
      {
         // Fading against us is the one encouraging version of this - the trend is
         // running out, which is when the ladder's premise starts working again.
         severity -= RegimeFadingRelief;
         parts += "though it is fading; ";
      }
   }

   severity = MathMax(0.0, MathMin(1.0, severity));
   detail = parts;
   return severity;
}

// ============================================================================

// Is price inside a band that has been rejecting it? Returns 0..1 - how strongly.
double InsideRejectingBand(const int entry_dir, double &band_lo, double &band_hi, string &detail)
{
   band_lo = 0.0; band_hi = 0.0;
   detail = "";

   if(!EnableBandEntryGuard || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   double lo = 0.0, hi = 0.0;
   string bdetail = "";
   if(!ZonePriceInsideBand(lo, hi, bdetail))
      return 0.0;
   if(hi <= lo)
      return 0.0;

   band_lo = lo; band_hi = hi;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   // How much has this band actually held? Both edges count - a band that capped price
   // is defined by its top and its bottom together.
   double s_hi = ZoneMapStrengthByTouches(hi);
   double s_lo = ZoneMapStrengthByTouches(lo);
   double strength = MathMax(s_hi, s_lo);

   if(strength < BandGuardMinStrength)
      return 0.0;

   // V243: being inside the band is itself the problem, and the original version missed that. It
   // scored only by position - buying near the top, selling near the bottom - and let anything in
   // the middle through. From a live loss: a sell at 4485.10 inside a 4484.20-4486.00 band scored
   // 0.50 against a 0.55 threshold and passed.
   //
   // But a trade taken anywhere inside a band that has held three times has no room in front of it.
   // Selling the middle of a support shelf is selling into the thing that turns price, whether the
   // fill is at the top of that shelf or the bottom of it.
   //
   // So the position now MODIFIES a baseline rather than being the whole reading.
   double pos = (mid - lo) / (hi - lo);
   double against = (entry_dir > 0) ? pos : (1.0 - pos);

   double str_f = MathMin(1.0, strength / MathMax(0.1, BandGuardFullStrength));

   // Inside at all - the floor. Position moves it up from there.
   double severity = BandGuardInsideBase + (1.0 - BandGuardInsideBase) * against;
   severity *= (0.4 + 0.6 * str_f);

   // How much room is left before the band's far edge stops the trade? A sell with the band's
   // bottom fifty cents away has nowhere to go even if it is right about direction.
   double room = (entry_dir > 0) ? (hi - mid) : (mid - lo);
   double room_pts = room / _Point;
   if(room_pts < (double)BandGuardMinRoomPoints)
   {
      severity = MathMin(1.0, severity * BandGuardNoRoomFactor);
      detail = StringFormat("inside a %.2f-%.2f band (%.2f strength) with only %.0f pts of room",
                            lo, hi, strength, room_pts);
      return MathMax(0.0, MathMin(1.0, severity));
   }

   detail = StringFormat("inside a %.2f-%.2f band (%.2f strength), %.0f%% of the way against it",
                         lo, hi, strength, against * 100.0);
   return MathMax(0.0, MathMin(1.0, severity));
}

// Has a liquidity sweep completed and turned the structure? Returns the direction the
// reversal points, or 0.
//
// The sequence: price takes out a prior extreme, fails to continue, comes back, and
// then makes a new extreme the OTHER way without revisiting the swept level. That is
// three separate observations, and the EA had detectors for none of them in
// combination - which is why it sold into one.
int SweepReversalDir(double &strength, string &detail)
{
   strength = 0.0;
   detail = "";

   if(!EnableSweepReversal || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = SweepReversalTF;
   int look = MathMax(20, SweepReversalLookback);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0;

   // Find the extreme of the window and where it happened.
   double lowest = 0.0, highest = 0.0;
   int low_shift = -1, high_shift = -1;

   for(int i = 1; i <= look; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0) continue;
      if(lowest <= 0.0 || l < lowest)  { lowest = l;  low_shift = i; }
      if(highest <= 0.0 || h > highest) { highest = h; high_shift = i; }
   }
   if(low_shift < 0 || high_shift < 0)
      return 0;

   // --- bullish case: the low was swept and price left it behind ------------
   // The low has to be OLDER than the high, meaning price took out the low first and
   // then made its high afterwards.
   if(low_shift > high_shift)
   {
      // Was that low a sweep - did it break something before it?
      double prior_low = 0.0;
      for(int i = low_shift + 1; i <= look; i++)
      {
         double l = CandleLow(tf, i);
         if(l <= 0.0) continue;
         if(prior_low <= 0.0 || l < prior_low) prior_low = l;
      }
      bool swept = (prior_low > 0.0 && lowest < prior_low);

      // And has price stayed away from it since?
      double recovered = (mid - lowest) / _Point;
      double leg = (highest - lowest) / _Point;

      if(swept && leg > 0.0 && recovered >= leg * SweepReversalMinHold)
      {
         strength = MathMin(1.0, (recovered / MathMax(1.0, leg)));
         detail = StringFormat("%.2f swept, structure turned up (high %.2f, no return)",
                               lowest, highest);
         return 1;
      }
   }

   // --- bearish case: mirror ------------------------------------------------
   if(high_shift > low_shift)
   {
      double prior_high = 0.0;
      for(int i = high_shift + 1; i <= look; i++)
      {
         double h = CandleHigh(tf, i);
         if(h <= 0.0) continue;
         if(prior_high <= 0.0 || h > prior_high) prior_high = h;
      }
      bool swept = (prior_high > 0.0 && highest > prior_high);

      double recovered = (highest - mid) / _Point;
      double leg = (highest - lowest) / _Point;

      if(swept && leg > 0.0 && recovered >= leg * SweepReversalMinHold)
      {
         strength = MathMin(1.0, (recovered / MathMax(1.0, leg)));
         detail = StringFormat("%.2f swept, structure turned down (low %.2f, no return)",
                               highest, lowest);
         return -1;
      }
   }

   return 0;
}
// Thin wrapper so the score engine and the block list read the same way.
bool ZoneRoleAmbiguous(string &detail)
{
   double lo = 0.0, hi = 0.0;
   return ZonePriceInsideBand(lo, hi, detail);
}

double RoomToTargetPoints(const int entry_dir, string &detail)
{
   detail = "";
   if(entry_dir == 0 || _Point <= 0.0)
      return 1e9;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 1e9;

   double wall = 0.0;
   string wall_src = "";

   // 1. Nearest opposing zone.
   double zone = (entry_dir > 0) ? ZoneMapNearestResistance(mid) : ZoneMapNearestSupport(mid);
   if(zone > 0.0)
   {
      bool ahead = (entry_dir > 0) ? (zone > mid) : (zone < mid);
      if(ahead)
      {
         wall = zone;
         wall_src = "zone";
      }
   }

   // 2. The structure's continuation level, if it lies nearer than that zone.
   if(EnableMarketStructure && RoomUseStructureLevel)
   {
      MarketStructureRead();
      double cont = G_STRUCTURE_CONTINUATION;
      if(cont > 0.0)
      {
         bool ahead = (entry_dir > 0) ? (cont > mid) : (cont < mid);
         if(ahead)
         {
            bool nearer = (wall <= 0.0) ||
                          ((entry_dir > 0) ? (cont < wall) : (cont > wall));
            if(nearer)
            {
               wall = cont;
               wall_src = "structure";
            }
         }
      }
   }

   if(wall <= 0.0)
   {
      detail = "room: clear ahead";
      return 1e9;                     // nothing in the way
   }

   double room_pts = MathAbs(wall - mid) / _Point;
   detail = StringFormat("room: %.0f pts to %s %.2f", room_pts, wall_src, wall);
   return room_pts;
}

void MarketVerdictRead()
{
   static int last_bar = -100000;
   if(last_bar > G_BARS_SEEN) last_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(last_bar == G_BARS_SEEN)
      return;
   last_bar = G_BARS_SEEN;

   G_VERDICT_DIR    = 0;
   G_VERDICT_AGREE  = 0;
   G_VERDICT_ACTIVE = 0;
   G_VERDICT_TXT    = "verdict: n/a";

   if(!EnableMarketVerdict)
      return;

   int bull = 0, bear = 0, active = 0;

   // 1-2. Swing structure, both frames.
   if(EnableMarketStructure)
   {
      MarketStructureRead();
      if(G_STRUCTURE_DIR > 0)      { bull++; active++; }
      else if(G_STRUCTURE_DIR < 0) { bear++; active++; }

      if(EnableStructureHTF)
      {
         if(G_STRUCTURE_HTF_DIR > 0)      { bull++; active++; }
         else if(G_STRUCTURE_HTF_DIR < 0) { bear++; active++; }
      }
   }

   // 3. Zone behaviour - the staircase of broken levels.
   if(EnableBreakSequence)
   {
      BreakSequenceRead();
      if(G_BREAK_SEQ_DIR > 0)      { bull++; active++; }
      else if(G_BREAK_SEQ_DIR < 0) { bear++; active++; }
   }

   // 4-5. Indicator trend, both scales. Read for BUY; the sign gives the direction.
   string gv_detail = "", lv_detail = "";
   double gconf = GlobalTrendConfidence(1, gv_detail);
   if(gconf >= VerdictTrendMinConfidence)       { bull++; active++; }
   else if(gconf <= -VerdictTrendMinConfidence) { bear++; active++; }

   double lconf = LocalTrendConfidence(1, lv_detail);
   if(lconf >= VerdictTrendMinConfidence)       { bull++; active++; }
   else if(lconf <= -VerdictTrendMinConfidence) { bear++; active++; }

   G_VERDICT_ACTIVE = active;

   if(active < MathMax(2, VerdictMinActiveSources))
   {
      G_VERDICT_TXT = StringFormat("verdict: only %d source(s) reading - no call", active);
      return;
   }

   if(bull > bear)      { G_VERDICT_DIR = 1;  G_VERDICT_AGREE = bull; }
   else if(bear > bull) { G_VERDICT_DIR = -1; G_VERDICT_AGREE = bear; }
   else                 { G_VERDICT_DIR = 0;  G_VERDICT_AGREE = bull; }

   // A split decision is not a weak trend - it is a market without an owner.
   if(G_VERDICT_DIR == 0)
      G_VERDICT_TXT = StringFormat("verdict: SPLIT %dup/%ddn of %d - no owner", bull, bear, active);
   else
      G_VERDICT_TXT = StringFormat("verdict: %s %d/%d sources agree",
                                   (G_VERDICT_DIR > 0 ? "BULLISH" : "BEARISH"),
                                   G_VERDICT_AGREE, active);

   if((MarketVerdictPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v117 VERDICT] %s", G_VERDICT_TXT);
}

bool StructureAgainstBasket(string &detail)
{
   detail = "";
   if(!EnableStructureBasketExit || !EnableMarketStructure)
      return false;
   if(G_BASKET_ORDERS <= 0 || G_STRUCTURE_DIR == 0)
      return false;

   MarketStructureRead();   // per-bar cached

   int basket_dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;

   // 1. The structure the basket was riding has broken.
   if(G_STRUCTURE_DIR == basket_dir && G_STRUCTURE_EVENT == -1)
   {
      detail = StringFormat("structure supporting the basket broke (%s)", G_STRUCTURE_EVENT_TXT);
      return true;
   }

   // 2. The opposing structure just extended against us.
   if(G_STRUCTURE_DIR == -basket_dir && G_STRUCTURE_EVENT == 1)
   {
      detail = StringFormat("opposing structure extended (%s)", G_STRUCTURE_EVENT_TXT);
      return true;
   }

   return false;
}

// V277: rebate mode. The broker pays per lot traded, which changes what a trade is for. Normally a
// basket has to reach a target worth taking; here the target IS the cost of entering - the basket
// opens down by the spread, waits for price to give that back, and closes at zero. The trade earns
// nothing and the rebate earns everything.
//
// Everything else is unchanged. The same filters decide entry, the same grid rules decide additions,
// the same protections apply - a basket that goes wrong here goes wrong by the same amount, and the
// rebate does not cover losses. It covers the spread on the trades that work.
double RebateTargetPoints()
{
   if(!EnableRebateMode || _Point <= 0.0)
      return 0.0;

   double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_pts <= 0.0)
      return 0.0;

   // The spread moves. A target set to exactly the spread at open misses when it widens by a point,
   // so the multiple and the margin are not decoration - they are what makes break-even actually
   // break even.
   double target = spread_pts * RebateSpreadMultiple + (double)RebateTPMarginPoints;

   // A target built from the spread grows with it, which means the target moves furthest away at
   // exactly the moment it is hardest to reach. During a release the spread can run five or six
   // times normal and the basket is then asked for a move it was never sized for.
   //
   // The spread is an entry cost, not a measure of how far price will travel. Capped.
   if(RebateTPMaxSpreadPoints > 0 && spread_pts > (double)RebateTPMaxSpreadPoints)
   {
      double capped = (double)RebateTPMaxSpreadPoints * RebateSpreadMultiple
                    + (double)RebateTPMarginPoints;
      if((RebateTPCapPrintOnUse && VerboseLogs) && target > capped)
         PrintFormat("[SIRUS TP] spread %.0f - target held at %.0f instead of %.0f",
                     spread_pts, capped, target);
      target = capped;
   }

   // And never inside the broker's minimum stop distance, or the order is simply rejected.
   double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(min_stop > 0.0 && target < min_stop * 1.2)
      target = min_stop * 1.2;

   return target;
}

// v291a: TP NI BIROZ KICHRAYTIRISH - bitta joyda, bitta kalit bilan.
// Savat TP si ham, birinchi kirish TP si ham shu yerdan o'tadi, shuning uchun grid, kontekst TP va
// boshqa hisoblar avtomatik moslashadi. Cashback rejimi (EnableRebateMode) bunga tegmaydi - u o'z TP
// sini ishlatadi. Xavfsizlik pollari: spreadning 2 barobari va brokerning stop level'i - TP bundan
// kichik bo'lmaydi, aks holda savdo spreadni ham qoplamaydi yoki order rad etiladi.
double ApplyTPScale(const double tp)
{
   if(tp <= 0.0 || TPScale <= 0.0 || TPScale == 1.0)
      return tp;
   double scaled = tp * TPScale;
   double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double stop_pts   = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double floor_pts  = MathMax(spread_pts * 2.0, stop_pts * 1.2);
   return MathMax(scaled, floor_pts);
}

double BaseBasketTPPoints()
{
   // V277: the switch sits here deliberately. Every other target calculation in the EA reads this
   // one - the situation targets, the structure targets, the grid arithmetic - so putting it at the
   // top of the chain means they all follow without a second place to get it wrong.
   if(EnableRebateMode)
   {
      double rebate_tp = RebateTargetPoints();
      if(rebate_tp > 0.0)
         return rebate_tp;
   }

   double tp = 0.0;

   if(UseBasketTPPoints && BasketTPPoints > 0)
      tp = (double)BasketTPPoints;
   else if(UseFixedTP && FixedTPPoints > 0)
      tp = (double)FixedTPPoints;
   else
      tp = 2000.0;

   if(tp < BasketTPMinPoints)
      tp = (double)BasketTPMinPoints;

   // V138: CONTEXTUAL TARGET - ask the chart how far the basket can realistically travel, instead of
   // demanding the same fixed distance everywhere.
   // ------------------------------------------------------------------------------------------
   // A fixed 2500-point target ignores what stands in front of the position. If the nearest opposing
   // level sits 1800 points away, the basket must break that level just to reach its own target -
   // and the usual outcome is a stall right under it followed by a retrace. If instead the way is
   // clear for 6000 points, the same fixed target leaves most of the move unharvested.
   //
   // So the target is measured to the first thing that can stop it: for a BUY basket the nearest
   // resistance above, for a SELL the nearest support below, minus a buffer so the exit sits just
   // IN FRONT of the level rather than at it (price rarely reaches the exact edge). Bounded both
   // ways - never below BasketTPMinPoints (the spread would eat it), never beyond ContextTPMaxFactor
   // of the configured target (a distant wall must not turn a scalp into a swing trade).
   if(EnableContextualTP && G_BASKET_ORDERS > 0 && _Point > 0.0)
   {
      double ctp_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ctp_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double ctp_mid = (ctp_bid > 0.0 && ctp_ask > 0.0) ? (ctp_bid + ctp_ask) / 2.0 : ctp_bid;

      if(ctp_mid > 0.0)
      {
         bool ctp_is_buy = (G_BASKET_DIRECTION == POSITION_TYPE_BUY);
         // FIX(tp-anchor-vs-current-price): search from the same origin the room is measured from
         // (see SituationTargetPoints for the full reasoning) - otherwise a losing basket finds a
         // wall near current price that sits behind its own average, and the feature switches off.
         double ctp_anchor_px = (G_BASKET_ORDERS > 0 && G_BASKET_AVG_PRICE > 0.0)
                                ? G_BASKET_AVG_PRICE : ctp_mid;
         double ctp_from = ctp_is_buy ? MathMax(ctp_mid, ctp_anchor_px)
                                      : MathMin(ctp_mid, ctp_anchor_px);
         double ctp_wall = ctp_is_buy ? ZoneMapNearestResistance(ctp_from)
                                      : ZoneMapNearestSupport(ctp_from);

         if(ctp_wall > 0.0)
         {
            // "Ahead" means ahead of the ORIGIN the room is measured from, not ahead of current
            // price - for a losing basket those are different points.
            bool ctp_ahead = ctp_is_buy ? (ctp_wall > ctp_from) : (ctp_wall < ctp_from);
            double ctp_strength = ZoneMapStrength(ctp_wall);

            // Only levels worth respecting reshape the target - a random single wick should not.
            if(ctp_ahead && ctp_strength >= ContextTPMinWallStrength)
            {
               // FIX(tp-anchor-vs-current-price): third instance of the same defect. `tp` is
               // consumed as a distance from the basket AVERAGE, but the room to the wall was
               // measured from current price - and for a losing basket the wall is ahead, so as
               // price fell the "room" GREW and the target grew with it. The deeper the basket
               // sank, the further away its exit moved. Measured from the average now, signed, so
               // a wall already behind the average produces no adjustment at all.
               double ctp_room   = (ctp_wall - ctp_anchor_px) * (ctp_is_buy ? 1.0 : -1.0) / _Point;
               double ctp_target = ctp_room - MathMax(0.0, (double)ContextTPBufferPoints);

               double ctp_floor = (double)BasketTPMinPoints;
               double ctp_ceil  = tp * MathMax(1.0, ContextTPMaxFactor);
               ctp_target = MathMax(ctp_floor, MathMin(ctp_ceil, ctp_target));

               // A wall that sits behind the basket average is not "room ahead" - it says nothing
               // about where this basket can get to, so leave the estimate chain alone rather than
               // collapsing the target onto BasketTPMinPoints.
               // The room must also be big enough to survive the buffer AND the minimum: below
               // that, the MathMax(ctp_floor, ...) clamp lifts the target back ABOVE the very wall
               // it was meant to stop in front of. (Wall $1.00 past the average, buffer 400, floor
               // 1200 -> target clamped to 1200 -> exit placed $0.20 BEYOND the wall.) Only adjust
               // when the clamp did not have to lift it off the floor.
               if(ctp_room > ctp_floor + MathMax(0.0, (double)ContextTPBufferPoints) &&
                  MathAbs(ctp_target - tp) >= 100.0)   // ignore trivial adjustments
               {
                  if((ContextTPPrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v138 CONTEXT TP] %.0f -> %.0f pts | %s %.2f is %.0f pts away (strength %.1f)",
                                 tp, ctp_target,
                                 (ctp_is_buy ? "resistance" : "support"),
                                 ctp_wall, ctp_room, ctp_strength);
                  tp = ctp_target;
               }
            }
         }
      }
   }

   // V116: if the structure has turned against this basket, stop holding out for the full target.
   // The market is no longer working in the basket's favour, so take the smaller bounce that is
   // still available rather than waiting for a move the structure no longer supports. Floored at
   // BasketTPMinPoints so the target never collapses into the spread.
   string sab_detail = "";
   if(StructureAgainstBasket(sab_detail))
   {
      double reduced = tp * MathMax(0.2, MathMin(1.0, StructureBreakTPFactor));
      if(reduced < BasketTPMinPoints)
         reduced = (double)BasketTPMinPoints;

      if(reduced < tp)
      {
         if((StructureBasketExitPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v116 STRUCTURE-BASKET] TP %.0f -> %.0f pts | %s", tp, reduced, sab_detail);
         tp = reduced;
      }
   }

   return ApplyTPScale(tp);   // v291a: TP biroz kichikroq (TPScale)
}

double BasketTPForOrderCount(const int orders)
{
   double tp = BaseBasketTPPoints();

   // V290: when the premise is dead, stop asking for the full target. V247 already detects that the
   // reason for the basket has gone - price closed through the level the trade was built on - and it
   // answers by stopping the grid. That keeps the position from growing and does nothing about the
   // position itself, which sits there waiting for a target that assumed the original read was
   // right. It was not, and the market has said so.
   //
   // A basket whose premise is gone is no longer a trade; it is a position to be managed out of. The
   // first retrace back toward break-even is the exit, not a step toward a target that needs the
   // move to resume. Waiting for the full target is how a basket that should have cost a few dollars
   // becomes one that costs the stop.
   // S-BASKET: and not before the loss is deep enough to be worth it. The premise dying says the
   // reason for the trade has gone; it does not say the trade is lost. A basket three dollars down
   // with its target still close can reach that target - cutting to break-even there gives away
   // every recovery the position still had.
   //
   // So the demand falls as the loss deepens. Shallow: hold out for the real target. Deep: the
   // question stops being profit and becomes getting out whole.
   if(EnableDeadPremiseExit && G_BASKET_ORDERS > 0 && G_BASKET_PREMISE_DEAD &&
      (!RequireDrawdownForBE || G_BASKET_DD_PERCENT >= DeadPremiseBEFromDD))
   {
      double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double exit_tp = MathMax(spread_pts * 1.5, (double)DeadPremiseExitPoints);

      double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(min_stop > 0.0 && exit_tp < min_stop * 1.2)
         exit_tp = min_stop * 1.2;

      if(exit_tp < tp)
      {
         if((DeadPremiseExitPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS BASKET] premise gone and %.1f%% down - target cut %.0f -> %.0f, "
                        "leaving on the first retrace",
                        G_BASKET_DD_PERCENT, tp, exit_tp);
         return exit_tp;
      }
   }


   // V286: in rebate mode the target IS the cost of entering, and that cost does not shrink because
   // the basket grew. The reductions below bring a distant target closer as the average price moves
   // toward it - a break-even target is already as close as it can be, and cutting it by forty
   // percent puts it inside the spread, where the basket can never close.
   if(EnableRebateMode)
      return tp;

   // Recovery basket should escape faster as order count grows, but not too tiny.
   if(orders >= 3)
      tp *= 0.75;
   if(orders >= 5)
      tp *= 0.60;

   if(tp < BasketTPMinPoints)
      tp = (double)BasketTPMinPoints;

   tp = Pack2BasketTPForOrders(orders, tp);
   tp = Pack3AdaptTPPoints(tp);

   // V31.6z26 NEW: TP INTELLIGENCE. The natural complement to Smart Trail - that tightens the
   // STOP when momentum decelerates, but nothing adjusted the TARGET based on whether the
   // trend carrying the basket is still genuinely healthy or already fading. If Trend Quality
   // is strong in the basket's own direction, extend TP slightly (let a genuinely strong move
   // run further); if Exhaustion Consensus is firing, tighten TP (take what's available before
   // momentum fully fades). Purely mechanical before this - a real gap given everything else
   // built today.
   if(EnableTPIntelligence && G_BASKET_ORDERS > 0 &&
      (G_BASKET_DIRECTION == POSITION_TYPE_BUY || G_BASKET_DIRECTION == POSITION_TYPE_SELL))
   {
      int tp_dir_i = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;

      // V31.6z40 fix: same binary-vs-magnitude gap found throughout this session, this time
      // in my own recent work - a Trend Quality of 0.70 (barely qualifying) and 0.99
      // (exceptionally strong) got the identical flat TP extension. This directly affects
      // real profit outcomes, arguably the most consequential instance of this pattern found
      // today. Now scales the multiplier by how far past the threshold the score actually is.
      string tq_tp_detail = "";
      double tq_tp_score = TrendQualityScore(tp_dir_i, tq_tp_detail);
      if(tq_tp_score >= TPIntelligenceStrongTrendThreshold)
      {
         double headroom = MathMax(0.01, 1.0 - TPIntelligenceStrongTrendThreshold);
         double strength = MathMax(0.0, MathMin(1.0, (tq_tp_score - TPIntelligenceStrongTrendThreshold) / headroom));
         double extend_mult = 1.0 + strength * (TPIntelligenceExtendMultiplier - 1.0);
         tp *= extend_mult;
      }

      string ec_tp_detail = "";
      double ec_tp_score = ExhaustionConsensusScore(tp_dir_i, ec_tp_detail);
      if(ec_tp_score <= TPIntelligenceExhaustionThreshold)
      {
         double headroom2 = MathMax(0.01, TPIntelligenceExhaustionThreshold);
         double severity = MathMax(0.0, MathMin(1.0, (TPIntelligenceExhaustionThreshold - ec_tp_score) / headroom2));
         double tighten_mult = 1.0 - severity * (1.0 - TPIntelligenceTightenMultiplier);
         tp *= tighten_mult;
      }
   }

   if(tp < BasketTPMinPoints)
      tp = (double)BasketTPMinPoints;

   G_PACK2_DYNAMIC_TP = tp;

   return tp;
}

// ============================================================================
// V29 STAGE 4 - NEW ENGINEERING (not present in v24 or v28)
// Real Retry Engine / Correlation Guard / Real Economic Calendar
// All placed here so they are defined before every consumer below.
// ============================================================================

// --- V29 ported: Zone Map (nearest H1/M15/M5/M30/H4/D1 wall) - info only, used to refine TP/lot/grid, never blocks entry ---
// Moved earlier (was defined much later in the file) so Zone Map's swing-confirmation can use it.
bool LegacyIsSwingHigh(const ENUM_TIMEFRAMES tf, const int shift, const int depth)
{
   double h = CandleHigh(tf, shift);
   if(h <= 0.0) return false;

   for(int i=1; i<=depth; i++)
   {
      if(CandleHigh(tf, shift-i) >= h) return false;
      if(CandleHigh(tf, shift+i) >  h) return false;
   }
   return true;
}

bool LegacyIsSwingLow(const ENUM_TIMEFRAMES tf, const int shift, const int depth)
{
   double l = CandleLow(tf, shift);
   if(l <= 0.0) return false;

   for(int i=1; i<=depth; i++)
   {
      if(CandleLow(tf, shift-i) <= l) return false;
      if(CandleLow(tf, shift+i) <  l) return false;
   }
   return true;
}

// V29 fix (A2): raw candle-extreme fallback, kept as a safety net if no confirmed swing point exists.
// V29 new (B-block): Fair Value Gap (liquidity vacuum) detection. A 3-candle pattern where the
// 1st candle's high/low doesn't overlap the 3rd candle's low/high - an "un-traded" price gap that
// often acts as a magnet (price tends to return and fill it before continuing).
// V29 new (B-block): Order Flow proxy. MT5 has no real bid/ask order flow for most retail
// forex/CFD symbols, so this uses tick_volume (number of price changes per bar) versus its
// recent average as a rough "conviction" measure - a real, well-known technical-analysis
// principle: genuine breakouts tend to trade on above-average volume, fakeouts often don't.
// V29 new (B-block): synthetic dollar-index proxy for accounts (e.g. Exness Cent) that don't
// offer a real DXY/USDX symbol. Uses the 3 majors that dominate the real DXY basket (EUR 57.6%,
// JPY 13.6%, GBP 11.9% of the official weights) - not an exact DXY value, but a solid directional
// proxy for USD strength/weakness.
// V29 new (B-block): Broker Holiday Calendar. A manually maintained date list (thin holiday
// liquidity/erratic spreads aren't covered by the economic calendar or generic weekend-close
// checks). Caution-only by default, matching the "never scared, just sized down" philosophy.
bool BrokerHolidayIsCautionActive(string &reason)
{
   reason = "no holiday nearby";

   if(!EnableBrokerHolidayCalendar || StringLen(BrokerHolidayDates) == 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   datetime now_date_only = StringToTime(StringFormat("%04d.%02d.%02d", now_dt.year, now_dt.mon, now_dt.day));
   if(now_date_only <= 0)
      return false;

   string dates[];
   int n = StringSplit(BrokerHolidayDates, ',', dates);

   for(int i = 0; i < n; i++)
   {
      string d = dates[i];
      StringTrimLeft(d);
      StringTrimRight(d);
      if(StringLen(d) == 0)
         continue;

      datetime holiday = StringToTime(d);
      if(holiday <= 0)
         continue;

      int days_diff = (int)((now_date_only - holiday) / 86400);

      if(days_diff >= -MathMax(0, BrokerHolidayCautionDaysBefore) && days_diff <= MathMax(0, BrokerHolidayCautionDaysAfter))
      {
         reason = StringFormat("near broker holiday %s (%d days)", d, days_diff);
         return true;
      }
   }

   return false;
}

bool BrokerHolidayAllowsEntry(string &reason)
{
   if(!BrokerHolidayIsCautionActive(reason))
   {
      reason = "no holiday nearby";
      return true;
   }

   if(BrokerHolidayHardBlockOnDay)
      return false;

   return true;
}

// --- V30.4 new: WEEKEND GUARD ---
// XAUUSD regularly gaps on Monday open; a grid basket held over the weekend has no
// protection against that gap. This guard (a) blocks NEW first entries late Friday,
// (b) optionally blocks new grid orders too, (c) optionally flats the basket.
// Basket management (TP/SL/trailing) always keeps running - only NEW risk is blocked.
bool WeekendWindowActive(int &dow, int &hour)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dow = dt.day_of_week;
   hour = dt.hour;
   if((dow == 6 || dow == 0) && WeekendBlockSunEntries)      // Saturday / Sunday bars (some brokers)
      return true;
   if(dow == 5 && hour >= SafeHourClamp(WeekendBlockEntryFriHour)) // late Friday
      return true;
   return false;
}

// --- V30.5 new: FRESH-BAR ENTRY CONFIRMATION ---
bool FreshBarAllowsEntry(string &reason)
{
   reason = "fresh-bar clear";
   if(!EnableFreshBarEntry || FreshBarMaxPercentOfBar <= 0.0)
      return true;

   // V31.4 DEADLOCK FIX: SmartFill qurollangan bo'lsa, barcha gate'lar arm paytida
   // o'tgan - fresh-bar oynasi kutish davomida yopilsa ham otishga ruxsat.
   if(G_SF_ACTIVE)
   {
      reason = "fresh-bar bypassed (smart-fill armed)";
      return true;
   }

   // V30.6 frequency protection: this gate only DEFERS entries because the Signal
   // Queue replays the blocked PASS at the next bar open. If the queue is off there
   // is no safety net and a blocked signal would be lost - so the gate stands down.
   if(!UseSignalQueue)
   {
      reason = "fresh-bar skipped (signal queue off, no replay net)";
      return true;
   }

   datetime bar_open = iTime(_Symbol, SignalTF, 0);
   int bar_sec = PeriodSeconds(SignalTF);
   if(bar_open <= 0 || bar_sec <= 0)
      return true; // data not ready: never a silent block on missing data

   int age = (int)(TimeCurrent() - bar_open);
   int limit = (int)(bar_sec * MathMin(100.0, FreshBarMaxPercentOfBar) / 100.0);

   if(age > limit)
   {
      reason = StringFormat("fresh-bar window passed %d/%ds (%.0f%% of %s bar)",
                            age, limit, FreshBarMaxPercentOfBar, TFToString(SignalTF));
      if((FreshBarPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v30.5 FRESH-BAR] %s", reason);
      return false;
   }
   return true;
}

bool WeekendGuardAllowsEntry(string &reason)
{
   reason = "weekend guard clear";
   if(!EnableWeekendGuard)
      return true;
   int dow = 0, hour = 0;
   if(WeekendWindowActive(dow, hour))
   {
      reason = StringFormat("weekend guard: dow=%d hour=%d >= Fri %d", dow, hour, WeekendBlockEntryFriHour);
      return false;
   }
   return true;
}

bool WeekendGuardAllowsGrid(string &reason)
{
   reason = "weekend guard clear";
   if(!EnableWeekendGuard || !WeekendBlockGridFri)
      return true;
   int dow = 0, hour = 0;
   if(WeekendWindowActive(dow, hour))
   {
      reason = StringFormat("weekend guard: no new grid, dow=%d hour=%d", dow, hour);
      return false;
   }
   return true;
}

// ============================================================================
// BOSQICH 17: CASHBACK AYLANMASI. Cashback daromadi ochilgan lot hajmiga bog'liq - ya'ni
// AYLANMAGA. Kichik TP li savat uzoq ochiq qolsa, joy band bo'ladi va keyingi savat ochilmaydi.
// Bu funksiya faqat ZARARDA BO'LMAGAN savatni yopadi: minusdagi savatga tegmaydi, uni grid va
// risk tizimi avvalgidek boshqaradi.
// ============================================================================
void RebateTimeFlatManage()
{
   if(!EnableRebateMode || !RebateTimeFlat) return;
   if(G_BASKET_ORDERS <= 0 || G_BASKET_OPEN_BAR <= 0) return;

   int age_bars = G_BARS_SEEN - G_BASKET_OPEN_BAR;
   if(age_bars < MathMax(3, RebateMaxBasketBars)) return;
   if(G_BASKET_PROFIT < RebateTimeFlatMinProfit) return;   // minusda - tegmaymiz

   PrintFormat("[SIRUS REBATE FLAT] basket %d bars old, profit %.2f - closing to free the slot",
               age_bars, G_BASKET_PROFIT);
   CloseSirusBasket(StringFormat("Rebate turnover flat (%d bars, %.2f)", age_bars, G_BASKET_PROFIT));
}

void WeekendGuardManage()
{
   if(!EnableWeekendGuard || !WeekendCloseBasketFri)
      return;
   if(G_BASKET_ORDERS <= 0)
      return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= SafeHourClamp(WeekendCloseFriHour))
   {
      if((WeekendGuardPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v30.4 WEEKEND] Friday %02d:00 flat: closing basket before weekend", dt.hour);
      CloseSirusBasket(StringFormat("Weekend guard Friday flat (hour=%d)", dt.hour));
   }
}

// --- V30.4 new: PUSH NOTIFICATIONS ---
void SirusNotify(const string msg)
{
   if(!EnablePushNotifications)
      return;
   if(!SendNotification(StringFormat("SIRUS %s: %s", _Symbol, msg)))
      PrintFormat("[SIRUS v30.4 PUSH] SendNotification failed err=%d (check MetaQuotes ID in terminal settings)", GetLastError());
}

// ================== V31: AUTOLOT ==================
// Balans/equity'ga qarab first-entry lot. Grid lotlari birinchi lotdan kelib chiqadi,
// shuning uchun butun basket avtomatik masshtablanadi.
double AutoLotBase()
{
   double money = (AutoLotUseEquity ? AccountInfoDouble(ACCOUNT_EQUITY)
                                    : AccountInfoDouble(ACCOUNT_BALANCE));
   if(money <= 0.0)
      return 0.0;

   // Risk-percent rejimi: faqat first-entry SL yoqilgan bo'lsa ishlaydi,
   // aks holda xavfsiz balance-step rejimiga tushadi.
   if(AutoLotRiskMode && UseFirstEntrySL && FirstEntrySLPoints > 0 && RiskPercent > 0.0)
   {
      double tick_val  = 0.0, tick_size = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_val);
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE,  tick_size);
      if(tick_val > 0.0 && tick_size > 0.0 && _Point > 0.0)
      {
         double value_per_point_per_lot = tick_val * (_Point / tick_size);
         if(value_per_point_per_lot > 0.0)
         {
            double risk_money = money * RiskPercent / 100.0;
            double lot = risk_money / ((double)FirstEntrySLPoints * value_per_point_per_lot);
            if(lot > 0.0)
               return lot;
         }
      }
   }

   if(AutoLotPer1000 <= 0.0)
      return 0.0;
   return money / 1000.0 * AutoLotPer1000;
}

// ================== V31: SELF-DEFENSE THROTTLE ==================
string SelfDefenseGVKey(const string suffix)
{
   return StringFormat("NAVIUS_%I64d_%s_SD_%s", MagicNumber, _Symbol, suffix);
}

void SelfDefenseSave()
{
   if(!EnablePersistentState)
      return;
   GlobalVariableSet(SelfDefenseGVKey("LS"), (double)G_SD_LOSS_STREAK);
   GlobalVariableSet(SelfDefenseGVKey("RW"), (double)G_SD_RECOVER_WINS);
   GlobalVariableSet(SelfDefenseGVKey("ON"), (G_SD_ACTIVE ? 1.0 : 0.0));
}

void SelfDefenseLoad()
{
   if(!EnablePersistentState)
      return;
   if(GlobalVariableCheck(SelfDefenseGVKey("LS"))) G_SD_LOSS_STREAK  = (int)GlobalVariableGet(SelfDefenseGVKey("LS"));
   if(GlobalVariableCheck(SelfDefenseGVKey("RW"))) G_SD_RECOVER_WINS = (int)GlobalVariableGet(SelfDefenseGVKey("RW"));
   if(GlobalVariableCheck(SelfDefenseGVKey("ON"))) G_SD_ACTIVE       = (GlobalVariableGet(SelfDefenseGVKey("ON")) > 0.5);
   if(G_SD_ACTIVE)
      PrintFormat("[SIRUS v31 SELF-DEFENSE] restored ACTIVE state | lossStreak=%d recoverWins=%d", G_SD_LOSS_STREAK, G_SD_RECOVER_WINS);
}

// Basket yopilishini kuzatadi (post-loss cooldown'dan MUSTAQIL - u o'chiq bo'lsa ham ishlaydi).
void UpdateSelfDefense()
{
   // LOCK FIX: self-defense cleared only after wins it makes harder to get - it now expires after
   // four hours on its own.
   {
      static datetime sd_since = 0;
      if(G_SD_ACTIVE && sd_since == 0) sd_since = TimeCurrent();
      if(!G_SD_ACTIVE) sd_since = 0;
      if(G_SD_ACTIVE && sd_since > 0 && (TimeCurrent() - sd_since) > 4 * 3600)
      {
         G_SD_ACTIVE = false;
         G_SD_LOSS_STREAK = 0;
         G_SD_RECOVER_WINS = 0;
         sd_since = 0;
         SelfDefenseSave();
         if(VerboseLogs) Print("[SIRUS v31 SELF-DEFENSE] expired after 4 hours - back to normal");
      }
   }
   if(G_SD_PREV_ORDERS > 0 && G_BASKET_ORDERS == 0)
   {
      bool was_loss = IsMeaningfulLoss(G_SD_PREV_PROFIT);   // BOSQICH 1

      // V31.1 Hour-Bayes: basket natijasini ochilgan soatiga yozish
      // (Self-Defense yoqiq-o'chiqligidan qat'i nazar ishlaydi).
      if(EnableHourBayes && G_HB_OPEN_HOUR >= 0)
      {
         HourBayesRecord(G_HB_OPEN_HOUR, !was_loss);
         G_HB_OPEN_HOUR = -1;
      }

      // V31.6j Day-of-Week Bayes: same universal hook, records which day the basket opened on.
      if(EnableDayOfWeekBayes && G_BASKET_OPENING_DOW >= 0)
      {
         DayOfWeekBayesRecord(G_BASKET_OPENING_DOW, !was_loss);
         G_BASKET_OPENING_DOW = -1;
      }

      // V31.6j Post-SL same-direction cooldown: remember direction+bar only when the basket
      // closed in a LOSS (was_loss) - a win doesn't need extra caution on the next same-direction try.
      if(EnablePostSLDirectionGuard && was_loss && G_SD_PREV_DIRECTION >= 0)   // AUDIT FIX: BUY is 0
      {
         G_LAST_SL_DIRECTION = (int)G_SD_PREV_DIRECTION;
         G_LAST_SL_BAR = G_BARS_SEEN;
      }

      // V31.6j Zone Reliability: a win near the opening zone counts as the zone "holding"
      // (defended successfully), a loss counts as it "breaking".
      if(EnableZoneReliability && G_BASKET_OPENING_ZONE_LEVEL > 0.0)
      {
         ZoneReliabilityRecord(G_BASKET_OPENING_ZONE_LEVEL, !was_loss);
         G_BASKET_OPENING_ZONE_LEVEL = 0.0;
      }

      if(!EnableSelfDefense)
      {
         G_SD_PREV_ORDERS = G_BASKET_ORDERS;
         G_SD_PREV_PROFIT = G_BASKET_PROFIT;
         G_SD_PREV_DIRECTION = G_BASKET_DIRECTION;
         return;
      }

      if(was_loss)
      {
         G_SD_LOSS_STREAK++;
         G_SD_RECOVER_WINS = 0;

         if(!G_SD_ACTIVE && G_SD_LOSS_STREAK >= MathMax(1, SelfDefenseLossStreak))
         {
            G_SD_ACTIVE = true;
            if((SelfDefensePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31 SELF-DEFENSE] ON: %d ketma-ket zarar basket | lot x%.2f | minScore +%d",
                           G_SD_LOSS_STREAK, SelfDefenseLotFactor, SelfDefenseMinScoreAdd);
            SirusNotify(StringFormat("SELF-DEFENSE ON (%d loss streak): lot x%.2f", G_SD_LOSS_STREAK, SelfDefenseLotFactor));
         }
         else if((SelfDefensePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31 SELF-DEFENSE] loss basket, streak=%d/%d", G_SD_LOSS_STREAK, SelfDefenseLossStreak);
      }
      else
      {
         if(G_SD_ACTIVE)
         {
            G_SD_RECOVER_WINS++;
            if(G_SD_RECOVER_WINS >= MathMax(1, SelfDefenseRecoverWins))
            {
               G_SD_ACTIVE = false;
               G_SD_LOSS_STREAK = 0;
               G_SD_RECOVER_WINS = 0;
               if((SelfDefensePrintOnUse && VerboseLogs))
                  Print("[SIRUS v31 SELF-DEFENSE] OFF: tiklanish yakunlandi, normal rejim");
               SirusNotify("SELF-DEFENSE OFF: recovered");
            }
            else if((SelfDefensePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31 SELF-DEFENSE] win basket, recovery %d/%d", G_SD_RECOVER_WINS, SelfDefenseRecoverWins);
         }
         else
            G_SD_LOSS_STREAK = 0;
      }

      SelfDefenseSave();
   }

   G_SD_PREV_ORDERS = G_BASKET_ORDERS;
   G_SD_PREV_PROFIT = G_BASKET_PROFIT;
   G_SD_PREV_DIRECTION = G_BASKET_DIRECTION;
}

double SelfDefenseLotAdjust(const double lot)
{
   if(!EnableSelfDefense || !G_SD_ACTIVE)
      return lot;
   if(SelfDefenseLotFactor <= 0.0 || SelfDefenseLotFactor >= 1.0)
      return lot; // faqat KAMAYTIRISH ruxsat: noto'g'ri qiymat = ta'sir yo'q
   return lot * SelfDefenseLotFactor;
}

// ================== V31.1: HOUR-BAYES ==================
string HourBayesGVKey(const string suffix, const int h)
{
   return StringFormat("NAVIUS_%I64d_%s_HB_%s_%d", MagicNumber, _Symbol, suffix, h);
}

void HourBayesSave(const int h)
{
   if(!EnablePersistentState || h < 0 || h > 23)
      return;
   GlobalVariableSet(HourBayesGVKey("W", h), G_HB_WINS[h]);
   GlobalVariableSet(HourBayesGVKey("L", h), G_HB_LOSSES[h]);
}

void HourBayesLoad()
{
   if(!EnablePersistentState)
      return;
   int restored = 0;
   for(int h = 0; h < 24; h++)
   {
      if(GlobalVariableCheck(HourBayesGVKey("W", h))) { G_HB_WINS[h]   = GlobalVariableGet(HourBayesGVKey("W", h)); restored++; }
      if(GlobalVariableCheck(HourBayesGVKey("L", h))) { G_HB_LOSSES[h] = GlobalVariableGet(HourBayesGVKey("L", h)); restored++; }
   }
   if(restored > 0)
      PrintFormat("[SIRUS v31.1 HOUR-BAYES] restored %d values", restored);
}

void HourBayesRecord(const int h, const bool won)
{
   if(!EnableHourBayes || h < 0 || h > 23)
      return;
   if(won) G_HB_WINS[h]   += 1.0;
   else    G_HB_LOSSES[h] += 1.0;
   HourBayesSave(h);
}

double HourBayesWinRate(const int h)
{
   if(h < 0 || h > 23)
      return 0.5;
   double total = G_HB_WINS[h] + G_HB_LOSSES[h];
   if(total < MathMax(1, HourBayesMinSamples))
      return 0.5;

   // V31.6z48 fix: same non-Bayesian gate problem as the main BayesWinRate - shrinkage makes
   // confidence scale honestly with how much evidence actually backs the observed rate.
   if(!EnableBayesShrinkage)
      return G_HB_WINS[h] / total;

   double k = MathMax(1.0, BayesShrinkageStrength);
   return MathMax(0.0, MathMin(1.0, (G_HB_WINS[h] + 0.5 * k) / (total + k)));
}

// V31.6j new: Day-of-Week Bayes - same rolling-decay pattern as Hour-Bayes, but for which day
// of the week (0=Sunday..6=Saturday) tends to win/lose. Monday and Friday often behave very
// differently from mid-week, a distinction Hour-Bayes alone can't capture.
void DayOfWeekBayesRecord(const int dow, const bool won)
{
   if(!EnableDayOfWeekBayes || dow < 0 || dow >= SIRUS_DOW_COUNT)
      return;

   if(won) G_DOW_WINS[dow] += 1.0;
   else    G_DOW_LOSSES[dow] += 1.0;

   double total = G_DOW_WINS[dow] + G_DOW_LOSSES[dow];
   if(total > DayOfWeekBayesMaxWindow)
   {
      double scale = (double)DayOfWeekBayesMaxWindow / total;
      G_DOW_WINS[dow]   *= scale;
      G_DOW_LOSSES[dow] *= scale;
   }

   if(EnablePersistentState)
   {
      GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_DOWW%d", MagicNumber, _Symbol, dow), G_DOW_WINS[dow]);
      GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_DOWL%d", MagicNumber, _Symbol, dow), G_DOW_LOSSES[dow]);
   }
}

double DayOfWeekBayesWinRate(const int dow)
{
   if(dow < 0 || dow >= SIRUS_DOW_COUNT)
      return 0.5;
   double total = G_DOW_WINS[dow] + G_DOW_LOSSES[dow];
   if(total < MathMax(1, DayOfWeekBayesMinSamples))
      return 0.5;

   // V31.6z48 fix: same shrinkage as the other two Bayes readings - especially relevant here,
   // since day-of-week naturally accumulates samples ~5x slower than hour-of-day.
   if(!EnableBayesShrinkage)
      return G_DOW_WINS[dow] / total;

   double k = MathMax(1.0, BayesShrinkageStrength);
   return MathMax(0.0, MathMin(1.0, (G_DOW_WINS[dow] + 0.5 * k) / (total + k)));
}

// FEATURE(smart-time-filter): sample-count helpers, so the filter never acts on a thin sample.
double HourBayesSampleCount(const int h)
{
   if(h < 0 || h > 23) return 0.0;
   return G_HB_WINS[h] + G_HB_LOSSES[h];
}
double DayOfWeekBayesSampleCount(const int dow)
{
   if(dow < 0 || dow >= SIRUS_DOW_COUNT) return 0.0;
   return G_DOW_WINS[dow] + G_DOW_LOSSES[dow];
}

// FEATURE(smart-time-filter): blocks a NEW first entry when the current hour or weekday has a
// proven-bad track record on THIS account. Only gates opening fresh risk - existing baskets are
// always managed normally elsewhere. Like the detector auto-disable, it needs a real sample
// before it acts, so early/unlucky results can't wrongly lock out a whole time window.
bool SmartTimeFilterAllowsEntry(string &reason)
{
   if(!EnableSmartTimeFilter)
   {
      reason = "smart time filter off";
      return true;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h   = SafeHourClamp(dt.hour);
   int dow = dt.day_of_week;   // 0=Sunday .. 6=Saturday

   // LOCK FIX: a blocked hour never trades, so its record never changes - the same hour was shut
   // every day forever. The hour / weekday records now fade 10% a day (in memory), so a bad slot
   // drops below its sample minimum, gets traded again, and is judged on fresh results.
   {
      static int stf_day = -1;
      if(stf_day != dt.day_of_year)
      {
         if(stf_day >= 0)
         {
            for(int i = 0; i < 24; i++) { G_HB_WINS[i] *= 0.9; G_HB_LOSSES[i] *= 0.9; }
            for(int i = 0; i < SIRUS_DOW_COUNT; i++) { G_DOW_WINS[i] *= 0.9; G_DOW_LOSSES[i] *= 0.9; }
         }
         stf_day = dt.day_of_year;
      }
   }

   if(TimeFilterUseHour && EnableHourBayes)
   {
      double h_samples = HourBayesSampleCount(h);
      if(h_samples >= TimeFilterHourMinSamples)
      {
         double h_wr = HourBayesWinRate(h);
         if(h_wr <= TimeFilterHourBadWinrate)
         {
            reason = StringFormat("bad-hour filter: hour %02d win rate %.0f%% over %.0f trades (<= %.0f%%)",
                                  h, h_wr * 100.0, h_samples, TimeFilterHourBadWinrate * 100.0);
            if((SmartTimeFilterPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS SMART TIME FILTER] %s", reason);
            return false;
         }
      }
   }

   if(TimeFilterUseDayOfWeek && EnableDayOfWeekBayes)
   {
      double d_samples = DayOfWeekBayesSampleCount(dow);
      if(d_samples >= TimeFilterDowMinSamples)
      {
         double d_wr = DayOfWeekBayesWinRate(dow);
         if(d_wr <= TimeFilterDowBadWinrate)
         {
            reason = StringFormat("bad-day filter: weekday %d win rate %.0f%% over %.0f trades (<= %.0f%%)",
                                  dow, d_wr * 100.0, d_samples, TimeFilterDowBadWinrate * 100.0);
            if((SmartTimeFilterPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS SMART TIME FILTER] %s", reason);
            return false;
         }
      }
   }

   reason = "smart time filter pass";
   return true;
}

void DayOfWeekBayesLoad()
{
   if(!EnablePersistentState)
      return;
   int restored = 0;
   for(int d = 0; d < SIRUS_DOW_COUNT; d++)
   {
      string kw = StringFormat("NAVIUS_%I64d_%s_DOWW%d", MagicNumber, _Symbol, d);
      string kl = StringFormat("NAVIUS_%I64d_%s_DOWL%d", MagicNumber, _Symbol, d);
      if(GlobalVariableCheck(kw)) { G_DOW_WINS[d]   = GlobalVariableGet(kw); restored++; }
      if(GlobalVariableCheck(kl)) { G_DOW_LOSSES[d] = GlobalVariableGet(kl); restored++; }
   }
   if(restored > 0)
      PrintFormat("[SIRUS v31.6j DAY-OF-WEEK BAYES] restored %d values", restored);
}

// ================== V31.1: ADR FILTER ==================
// Bugungi diapazon o'rtacha kunlik diapazonning necha %ini egallaganini qaytaradi.
// dir_today: +1 kun ko'tarilishda, -1 tushishda, 0 aniqlanmadi.
double ADRUsedPercent(int &dir_today)
{
   dir_today = 0;
   int days = MathMax(3, ADRPeriodDays);

   double sum = 0.0;
   int count = 0;
   for(int i = 1; i <= days; i++)
   {
      double h = iHigh(_Symbol, PERIOD_D1, i);
      double l = iLow(_Symbol, PERIOD_D1, i);
      if(h <= 0.0 || l <= 0.0 || h <= l)
         continue;
      sum += (h - l);
      count++;
   }
   if(count < 3)
      return 0.0;

   double adr = sum / count;
   double th = iHigh(_Symbol, PERIOD_D1, 0);
   double tl = iLow(_Symbol, PERIOD_D1, 0);
   double to = iOpen(_Symbol, PERIOD_D1, 0);
   if(adr <= 0.0 || th <= 0.0 || tl <= 0.0 || th <= tl)
      return 0.0;

   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(to > 0.0 && bid > 0.0)
      dir_today = (bid > to ? 1 : (bid < to ? -1 : 0));

   return (th - tl) / adr * 100.0;
}

// ================== V31.1: TICK-VELOCITY GUARD ==================
// Har real tick'da chaqiriladi. Tick tezligi baseline'dan keskin oshsa VA narx qisqa
// oynada katta yursa - kalendarga tushmagan yangilik/portlash deb hisoblab, qisqa
// muddat yangi savdo ochishni to'xtatadi. Ochiq basket boshqaruviga tegmaydi.
void TickVelocityUpdate()
{
   if(!EnableTickVelocityGuard)
      return;

   ulong ms = GetTickCount64();
   if(G_VEL_LAST_MS > 0)
   {
      double dt = (double)(ms - G_VEL_LAST_MS);
      if(dt < 1.0) dt = 1.0;
      double rate = 1000.0 / dt; // tick/sekund (bir lahzalik)
      G_VEL_RATE_FAST = (G_VEL_RATE_FAST <= 0.0 ? rate : G_VEL_RATE_FAST * 0.70 + rate * 0.30);
      G_VEL_RATE_SLOW = (G_VEL_RATE_SLOW <= 0.0 ? rate : G_VEL_RATE_SLOW * 0.995 + rate * 0.005);
   }
   G_VEL_LAST_MS = ms;

   // Sekundiga bitta narx nuqtasi saqlanadi (16-slotli halqa).
   datetime now = TimeCurrent();
   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(bid <= 0.0)
      return;

   if(now != G_VEL_RING_LAST_SEC)
   {
      G_VEL_RING_POS = (G_VEL_RING_POS + 1) % 16;
      G_VEL_RING_PRICE[G_VEL_RING_POS] = bid;
      G_VEL_RING_TIME[G_VEL_RING_POS]  = now;
      G_VEL_RING_LAST_SEC = now;
   }

   if(G_TICK_COUNT < 300 || G_VEL_RATE_SLOW <= 0.0)
      return; // baseline hali pishmagan

   // Oyna boshidagi narxni topish (window sekunddan eski, eng yaqini).
   double past_price = 0.0;
   datetime best_t = 0;
   // FIX(silent-guard-off): the ring buffer only holds 16 one-second samples. If the user set
   // VelocityWindowSec >= 16, no sample is ever old enough to satisfy the window and the entire
   // velocity spike guard silently stopped working. Clamp to 14s (< 16) so it always functions.
   int win = MathMax(2, MathMin(14, VelocityWindowSec));
   for(int i = 0; i < 16; i++)
   {
      if(G_VEL_RING_TIME[i] <= 0)
         continue;
      if((now - G_VEL_RING_TIME[i]) >= win && G_VEL_RING_TIME[i] > best_t)
      {
         best_t = G_VEL_RING_TIME[i];
         past_price = G_VEL_RING_PRICE[i];
      }
   }
   if(past_price <= 0.0)
      return;

   double move_points = MathAbs(bid - past_price) / _Point;
   double ratio = G_VEL_RATE_FAST / G_VEL_RATE_SLOW;

   if(ratio < VelocitySpikeRatio || move_points < (double)VelocityMovePoints)
      return;

   // AUDIT FIX (C1): the ATR-adaptive threshold and the 5-minute budget are for FIRST entries (so a busy
   // market is not choked). A grid rung added into a spike is a different matter - the grid keeps the
   // original rule: any fixed-threshold spike pauses additions for VelocityHoldSec.
   if(now > G_VEL_GRID_UNTIL)
      G_VEL_GRID_UNTIL = now + MathMax(5, VelocityHoldSec);

   // ADAPTIVE: after a big candle the market stays busy and a 400-point move in 5 s becomes ordinary.
   // The move must also be VelocityMoveATRMult x ATR(M1) (read only here, when the cheap checks passed).
   double need_pts = (double)VelocityMovePoints;
   if(VelocityMoveATRMult > 0.0)
   {
      double atr1 = ATRPointsManual(PERIOD_M1, 14, 1);
      if(atr1 > 0.0)
         need_pts = MathMax(need_pts, VelocityMoveATRMult * atr1);
   }
   if(move_points < need_pts)
      return;

   bool fresh = (now > G_VEL_SPIKE_UNTIL);
   if(!fresh)
      return;
   // LOCK FIX: every spike tick used to push the hold forward with no cap - a long fast move kept
   // entries shut for its whole length. The hold is set once and runs out.
   G_VEL_SPIKE_UNTIL = now + MathMax(5, VelocityHoldSec);  // live spike state (LiveVelocityDirection)

   // BUDGET: re-arming spike after spike in a volatile market used to keep entries shut for many
   // minutes. Entry pauses share a budget of VelocityMaxHoldPer5Min seconds per 5 minutes.
   int hold = MathMax(5, VelocityHoldSec);
   if(VelocityMaxHoldPer5Min > 0)
   {
      if(G_VEL_BUDGET_START <= 0 || now - G_VEL_BUDGET_START >= 300)
      {
         G_VEL_BUDGET_START = now;
         G_VEL_BUDGET_USED = 0;
      }
      int left = VelocityMaxHoldPer5Min - G_VEL_BUDGET_USED;
      hold = MathMin(hold, left);
      if(hold < 5)
      {
         if((VelocityPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS VELOCITY] spike %.0f pts/%ds (need %.0f) - pause budget %ds/5min used, entries stay open",
                        move_points, win, need_pts, VelocityMaxHoldPer5Min);
         return;
      }
      G_VEL_BUDGET_USED += hold;
   }
   G_VEL_BLOCK_UNTIL = now + hold;
   if((VelocityPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.1 VELOCITY] SPIKE: tick rate x%.1f baseline, move=%.0f pts/%ds (need %.0f) -> yangi savdo %ds bloklanadi",
                  ratio, move_points, win, need_pts, hold);
   SirusNotify(StringFormat("VELOCITY SPIKE: %.0f pts/%ds, new trades paused %ds", move_points, win, hold));
}

bool VelocityAllowsNewRisk(string &reason)
{
   reason = "velocity clear";
   if(!EnableTickVelocityGuard)
      return true;
   if(TimeCurrent() <= G_VEL_BLOCK_UNTIL)
   {
      reason = StringFormat("velocity spike hold %ds left", (int)(G_VEL_BLOCK_UNTIL - TimeCurrent()));
      return false;
   }
   return true;
}

// Grid additions: the original spike rule (fixed threshold, no budget).
bool VelocityAllowsGrid(string &reason)
{
   reason = "velocity clear";
   if(!EnableTickVelocityGuard)
      return true;
   if(TimeCurrent() <= G_VEL_GRID_UNTIL)
   {
      reason = StringFormat("velocity spike hold %ds left", (int)(G_VEL_GRID_UNTIL - TimeCurrent()));
      return false;
   }
   return true;
}

// --- V31.3 new: ENTRY DRIFT GUARD ---
bool EntryDriftAllows(string &reason)
{
   reason = "drift clear";
   if(!EnableEntryDriftGuard)
      return true;
   if(!UseSignalQueue)
   {
      reason = "drift guard skipped (queue off, no replay net)"; // chastota himoyasi
      return true;
   }

   double signal_close = CandleClose(SignalTF, 1);
   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(signal_close <= 0.0 || bid <= 0.0)
      return true; // ma'lumot tayyor emas: hech qachon silent block emas

   double drift_pts = MathAbs(bid - signal_close) / _Point;
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   double limit = MathMax((double)MathMax(1, DriftMinPointsFloor),
                          (atr > 0.0 ? atr * DriftMaxATRFraction : 0.0));

   if(drift_pts > limit)
   {
      reason = StringFormat("price drifted %.0f/%.0f pts from signal close", drift_pts, limit);
      if((DriftPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.3 DRIFT] %s", reason);
      return false;
   }
   return true;
}

double BrokerHolidayLotAdjust(const double lot)
{
   string reason = "";
   if(!BrokerHolidayIsCautionActive(reason) || BrokerHolidayHardBlockOnDay)
      return lot;

   if((BrokerHolidayPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v29 HOLIDAY] %s - lot trimmed x%.2f", reason, BrokerHolidayLotFactor);

   return lot * BrokerHolidayLotFactor;
}

// V31.6e new: soft caution during the typical NY-open volatility window - applies to EVERY
// signal type equally, never blocks, just trims. Server-time hours are broker-dependent, so
// the window is adjustable rather than hardcoded to a specific UTC offset.
double NYKillzoneLotAdjust(const double lot)
{
   if(!EnableNYKillzoneCaution)
      return lot;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   // V261: New York shifts on its own dates - early March to early November, two weeks apart from
   // Europe at each end. During those two weeks the two sessions overlap differently than they do
   // for the rest of the year, which is exactly when a killzone measured in fixed hours is furthest
   // from the thing it was drawn around.
   int kz_start = AdjustedSessionHour(NYKillzoneStartHour, true);
   int kz_end   = AdjustedSessionHour(NYKillzoneEndHour, true);

   bool in_killzone = (kz_end > kz_start) && (hour >= kz_start && hour < kz_end);

   if(!in_killzone)
      return lot;

   if((NYKillzonePrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6e NY KILLZONE] hour=%d - lot trimmed x%.2f", hour, NYKillzoneLotFactor);

   return lot * NYKillzoneLotFactor;
}

// V31.6f new: Impulse Correction Guard. Closes a real gap - after a big impulse (say price
// drops hard), a bounce/correction back the OTHER way is normal. Nothing previously checked
// whether a NEW first-entry signal in the SAME direction as that impulse was firing right
// into an active correction (e.g. still selling while price is bouncing UP off the drop).
// Grid additions already had impulse-cooldown protection; first entries never did.
double ImpulseCorrectionRetracePercent()
{
   if(G_LAST_IMPULSE_BAR <= -100000 || G_LAST_IMPULSE_RANGE_POINTS <= 0.0 || G_LAST_IMPULSE_DIRECTION == 0)
      return 0.0;

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0 || G_LAST_IMPULSE_CLOSE <= 0.0)
      return 0.0;

   double moved_back_points = 0.0;
   if(G_LAST_IMPULSE_DIRECTION > 0)
      moved_back_points = (G_LAST_IMPULSE_CLOSE - mid) / _Point;   // impulse was UP, correction = price pulling back down
   else
      moved_back_points = (mid - G_LAST_IMPULSE_CLOSE) / _Point;   // impulse was DOWN, correction = price bouncing back up

   if(moved_back_points <= 0.0)
      return 0.0;

   return (moved_back_points / G_LAST_IMPULSE_RANGE_POINTS) * 100.0;
}

// V31.6j new: Spread/ATR liquidity quality. A fixed spread-points threshold doesn't adapt to
// market conditions - 300 points is huge in a quiet market, tiny during a real move. This
// checks spread AS A FRACTION of current ATR instead, so the same ratio means the same thing
// regardless of overall volatility.
double SpreadATRRatio()
{
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;
   return (double)G_LAST_SPREAD_POINTS / atr;
}

double SpreadATRQualityLotAdjust(const double lot)
{
   if(!EnableSpreadATRQuality)
      return lot;

   double ratio = SpreadATRRatio();
   if(ratio <= 0.0 || ratio < SpreadATRWarnRatio)
      return lot;

   if((SpreadATRPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6j SPREAD/ATR] ratio=%.2f (>= %.2f) - lot trimmed x%.2f",
                  ratio, SpreadATRWarnRatio, SpreadATRLotFactor);

   return lot * SpreadATRLotFactor;
}

// V31.6j new: Post-SL Same-Direction lot trim - complements the score-bar increase above with
// a matching lot cut for the same window/direction.
double PostSLDirectionLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnablePostSLDirectionGuard || G_LAST_SL_DIRECTION < 0)
      return lot;

   int bars_since_sl = G_BARS_SEEN - G_LAST_SL_BAR;
   if(bars_since_sl < 0 || bars_since_sl > MathMax(1, PostSLDirectionWindowBars))
      return lot;

   int entry_dir_sl = (order_type == ORDER_TYPE_BUY) ? (int)POSITION_TYPE_BUY : (int)POSITION_TYPE_SELL;
   if(entry_dir_sl != G_LAST_SL_DIRECTION)
      return lot;

   if((PostSLDirectionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6j POST-SL GUARD] same-direction lot trimmed x%.2f (%d/%d bars since SL)",
                  PostSLDirectionLotFactor, bars_since_sl, PostSLDirectionWindowBars);

   return lot * PostSLDirectionLotFactor;
}

double ImpulseCorrectionLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableImpulseCorrectionGuard || G_LAST_IMPULSE_BAR <= -100000 || G_LAST_IMPULSE_DIRECTION == 0)
      return lot;

   int bars_since = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
   if(bars_since > MathMax(1, ImpulseCorrectionWindowBars))
      return lot;

   int entry_dir = (order_type == ORDER_TYPE_BUY) ? 1 : -1;
   if(entry_dir != G_LAST_IMPULSE_DIRECTION)
      return lot;   // entry goes WITH the correction (against the old impulse) - that's fine

   double retrace_pct = ImpulseCorrectionRetracePercent();
   if(retrace_pct < ImpulseCorrectionMinRetracePercent)
      return lot;

   if((ImpulseCorrectionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6f IMPULSE CORRECTION] %s entry during %.0f%% retrace of recent impulse (%d bars ago) - lot trimmed x%.2f",
                  (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), retrace_pct, bars_since, ImpulseCorrectionLotFactor);

   return lot * ImpulseCorrectionLotFactor;
}

// ============================================================================
// V31.6h SWING IMPULSE CORRECTION - full replacement for the single-candle version.
// Solves the exact gap identified: a big move ($70 in the user's example) rarely happens
// in one candle - it usually spans MANY candles with small counter-moves mixed in. A
// single-candle impulse tracker misses this entirely. This version finds the last genuinely
// CONFIRMED swing high/low (noise-resistant by construction - swing points only count once
// price has turned and held), measures the real move between them, and layers five checks:
//   1. Local swing-based move - noise-resistant, works from ANY starting candle
//   2. ATR-relative "is this actually big" threshold - adapts to market conditions
//   3. Big-picture direction (unified Kalman/D1) - is the local move aligned with or against
//      the broader trend? Aligned -> correction more likely temporary -> more caution.
//      Against -> the local move itself may be reconnecting with the primary trend -> less.
//   4. Volume - heavy volume during a supposed "correction" is suspicious (maybe not a
//      correction at all)
//   5. Zone match - does price sit at a REAL wall, searched proportional to impulse size
//      (a $70 move is caught by a wall $40+ away, not just the nearest minor level)
// ============================================================================

int SwingImpulseDirection(double &impulse_range_points, double &reference_price)
{
   impulse_range_points = 0.0;
   reference_price = 0.0;

   int depth = MathMax(1, SwingImpulseDepth);
   double swing_high = 0.0, swing_low = 0.0;
   int sh_shift = -1, sl_shift = -1;

   for(int i = depth + 1; i <= MathMax(depth + 2, SwingImpulseLookbackBars); i++)
   {
      if(sh_shift < 0 && LegacyIsSwingHigh(SwingImpulseTF, i, depth))
      {
         swing_high = CandleHigh(SwingImpulseTF, i);
         sh_shift = i;
      }
      if(sl_shift < 0 && LegacyIsSwingLow(SwingImpulseTF, i, depth))
      {
         swing_low = CandleLow(SwingImpulseTF, i);
         sl_shift = i;
      }
      if(sh_shift >= 0 && sl_shift >= 0)
         break;
   }

   if(sh_shift < 0 || sl_shift < 0 || swing_high <= swing_low)
      return 0;

   impulse_range_points = (swing_high - swing_low) / _Point;

   if(sl_shift < sh_shift)
   {
      // the swing LOW is fresher -> the dominant recent move was DOWN into it
      reference_price = swing_low;
      return -1;
   }

   reference_price = swing_high;
   return 1;
}

bool SwingImpulseIsSignificant(const double impulse_range_points)
{
   double atr = ATRPointsManual(SwingImpulseTF, ATRPeriod, 1);
   if(atr <= 0.0)
      return false;
   return (impulse_range_points >= atr * SwingImpulseMinATRMultiple);
}

double SwingImpulseCorrectionLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableSwingImpulseCorrection)
      return lot;

   // V31.6k speed: same per-bar cache pattern as ADR/DXY/Trend Reversal - the swing scan
   // only changes when a new bar closes, not every tick/lot calculation.
   static int    swing_cache_bar   = -1;
   static double swing_range_c     = 0.0;
   static double swing_ref_c       = 0.0;
   static int    swing_dir_c       = 0;
   if(swing_cache_bar > G_BARS_SEEN) swing_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(swing_cache_bar != G_BARS_SEEN)
   {
      swing_dir_c = SwingImpulseDirection(swing_range_c, swing_ref_c);
      swing_cache_bar = G_BARS_SEEN;
   }

   double impulse_range = swing_range_c, ref_price = swing_ref_c;
   int impulse_dir = swing_dir_c;
   if(impulse_dir == 0 || impulse_range <= 0.0)
      return lot;

   if(!SwingImpulseIsSignificant(impulse_range))
      return lot;

   int entry_dir = (order_type == ORDER_TYPE_BUY) ? 1 : -1;
   if(entry_dir != impulse_dir)
      return lot;   // entry goes WITH the correction - not the risky case

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return lot;

   double moved_back_points = (impulse_dir > 0) ? (ref_price - mid) / _Point : (mid - ref_price) / _Point;
   if(moved_back_points <= 0.0)
      return lot;

   double retrace_pct = (moved_back_points / impulse_range) * 100.0;
   if(retrace_pct < SwingImpulseMinRetracePercent)
      return lot;

   // Layer: multi-TF confirmation via Zone Map strength at the swing's own reference price -
   // reuses the existing multi-TF confluence system rather than duplicating logic.
   double ref_strength = ZoneMapStrength(ref_price);
   bool mtf_confirmed = (!SwingImpulseRequireMTFConfirm) || (ref_strength >= SwingImpulseMTFMinStrength);
   if(SwingImpulseRequireMTFConfirm && !mtf_confirmed)
      return lot;   // the "impulse" itself isn't backed by a real structural point - skip

   // Layer: big-picture direction agreement
   double big_dir_factor = 1.0;
   if(KalmanTrendReady())
   {
      double slope = G_KALMAN_TREND / _Point;
      int kalman_dir = (slope > KalmanTrendMinPoints) ? 1 : (slope < -KalmanTrendMinPoints ? -1 : 0);
      if(kalman_dir != 0)
         big_dir_factor = (kalman_dir == impulse_dir) ? 0.85 : 1.15;
   }

   // Layer: volume sanity - heavy volume during what looks like a correction is suspicious
   // REVERT(orderflow-sign): briefly changed to `== -impulse_dir` on the mistaken belief that
   // OrderFlowConvictionSign is directional. It is not: it classifies VOLUME MAGNITUDE only
   // (+1 = heavy/confirmed, -1 = thin/weak, 0 = ordinary), from iVolume alone. `> 0` is the
   // correct and direction-agnostic test - it matches this line's own comment above, the input's
   // description ("Heavy volume during what looks like a correction is suspicious"), and the fact
   // that we only reach here when entry_dir == impulse_dir (continuing the impulse against a
   // retracement, where heavy volume on that retracement is the tell it is a real reversal).
   bool volume_suspicious = false;
   if(SwingImpulseUseVolumeCheck)
      volume_suspicious = (OrderFlowConvictionSign(SwingImpulseTF, 1) > 0);

   // Layer: zone match, searched proportional to the impulse's own size
   bool zone_match = false;
   double zone_strength_at_match = 0.0;
   if(SwingImpulseUseZoneMatch)
   {
      double search_range_points = impulse_range * MathMax(0.1, SwingImpulseZoneSearchFactor);
      double zone = (impulse_dir > 0) ?
                    ZoneMapNearestSupport(mid + search_range_points * _Point) :
                    ZoneMapNearestResistance(mid - search_range_points * _Point);

      if(zone > 0.0 && (MathAbs(mid - zone) / _Point) <= search_range_points)
      {
         zone_match = true;
         zone_strength_at_match = ZoneMapStrength(zone);
      }
   }

   double factor = zone_match ? SwingImpulseBigDirLotFactor : SwingImpulseSmallDirLotFactor;
   factor *= big_dir_factor;
   if(volume_suspicious)
      factor *= 0.8;

   factor = MathMax(0.2, MathMin(1.0, factor));

   if((SwingImpulsePrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v31.6h SWING IMPULSE] %s continuing %s-impulse (%.0fpts, %.0f%% retrace) | zoneMatch=%s(str=%.2f) volSuspicious=%s bigDir=%.2f -> lot x%.2f",
                  (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                  (impulse_dir > 0 ? "UP" : "DOWN"),
                  impulse_range, retrace_pct,
                  BoolText(zone_match), zone_strength_at_match,
                  BoolText(volume_suspicious), big_dir_factor,
                  factor);

   return lot * factor;
}

// ============================================================================
// V31.6i NEW: TREND REVERSAL (Swing Sequence) + RSI DIVERGENCE
// Stronger than the existing single-break CHoCH: tracks the actual SEQUENCE of the last two
// swing points. A downtrend keeps making Lower Lows; the first structural sign of reversal is
// a Higher Low (doesn't renew the minimum), confirmed once price breaks back above the most
// recent swing high. RSI divergence (price makes a lower low, RSI does NOT) adds a second,
// independent confirmation layer using a real oscillator, not just price geometry.
// ============================================================================

bool FindLastTwoSwingLows(const ENUM_TIMEFRAMES tf, const int lookback, const int depth,
                          double &low1, int &low1_shift, double &low2, int &low2_shift)
{
   low1 = 0.0; low1_shift = -1;
   low2 = 0.0; low2_shift = -1;

   for(int i = depth + 1; i <= lookback; i++)
   {
      if(!LegacyIsSwingLow(tf, i, depth))
         continue;

      if(low1_shift < 0)
      {
         low1 = CandleLow(tf, i);
         low1_shift = i;
      }
      else
      {
         low2 = CandleLow(tf, i);
         low2_shift = i;
         return true;
      }
   }
   return false;
}

bool FindLastTwoSwingHighs(const ENUM_TIMEFRAMES tf, const int lookback, const int depth,
                           double &high1, int &high1_shift, double &high2, int &high2_shift)
{
   high1 = 0.0; high1_shift = -1;
   high2 = 0.0; high2_shift = -1;

   for(int i = depth + 1; i <= lookback; i++)
   {
      if(!LegacyIsSwingHigh(tf, i, depth))
         continue;

      if(high1_shift < 0)
      {
         high1 = CandleHigh(tf, i);
         high1_shift = i;
      }
      else
      {
         high2 = CandleHigh(tf, i);
         high2_shift = i;
         return true;
      }
   }
   return false;
}

// +1 = confirmed bullish reversal (Higher Low + broke above recent high), -1 = bearish, 0 = none
int TrendReversalDirectionRaw(string &reason, bool &divergence_confirmed)
{
   divergence_confirmed = false;
   reason = "no reversal";

   if(!EnableTrendReversal)
      return 0;

   int depth = MathMax(1, TrendReversalSwingDepth);
   int lookback = MathMax(depth * 3, TrendReversalLookbackBars);

   double low1 = 0.0, low2 = 0.0;
   int low1_shift = -1, low2_shift = -1;
   bool got_lows = FindLastTwoSwingLows(TrendReversalTF, lookback, depth, low1, low1_shift, low2, low2_shift);

   double high1 = 0.0, high2 = 0.0;
   int high1_shift = -1, high2_shift = -1;
   bool got_highs = FindLastTwoSwingHighs(TrendReversalTF, lookback, depth, high1, high1_shift, high2, high2_shift);

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0;

   // Bullish reversal: most recent swing low is HIGHER than the previous one (Higher Low,
   // stopped renewing the minimum), confirmed by price breaking above the most recent swing high.
   if(got_lows && low1 > low2 && got_highs && mid > high1)
   {
      double rsi1 = SirusRSI(TrendReversalTF, TrendReversalRSIPeriod, low1_shift);
      double rsi2 = SirusRSI(TrendReversalTF, TrendReversalRSIPeriod, low2_shift);
      if(rsi1 > 0.0 && rsi2 > 0.0 && rsi1 > rsi2)
         divergence_confirmed = true;

      if(TrendReversalRequireDivergence && !divergence_confirmed)
      {
         reason = "bullish structure only, RSI does not confirm";
         return 0;
      }

      reason = StringFormat("bullish reversal: low %.2f->%.2f (HL), broke above %.2f%s",
                            low2, low1, high1, divergence_confirmed ? ", RSI divergence confirms" : "");
      return 1;
   }

   // Bearish reversal: most recent swing high is LOWER than the previous one (Lower High),
   // confirmed by price breaking below the most recent swing low.
   if(got_highs && high1 < high2 && got_lows && mid < low1)
   {
      double rsi1 = SirusRSI(TrendReversalTF, TrendReversalRSIPeriod, high1_shift);
      double rsi2 = SirusRSI(TrendReversalTF, TrendReversalRSIPeriod, high2_shift);
      if(rsi1 > 0.0 && rsi2 > 0.0 && rsi1 < rsi2)
         divergence_confirmed = true;

      if(TrendReversalRequireDivergence && !divergence_confirmed)
      {
         reason = "bearish structure only, RSI does not confirm";
         return 0;
      }

      reason = StringFormat("bearish reversal: high %.2f->%.2f (LH), broke below %.2f%s",
                            high2, high1, low1, divergence_confirmed ? ", RSI divergence confirms" : "");
      return -1;
   }

   return 0;
}

// V31.6l new: shared per-bar cache wrapper - ALL callers (score engine, grid) reuse the SAME
// cached result instead of each independently recomputing this expensive swing/RSI scan.
int TrendReversalDirection(string &reason, bool &divergence_confirmed)
{
   static int    cache_bar    = -1;
   static int    cache_dir    = 0;
   static string cache_reason = "";
   static bool   cache_div    = false;
   if(cache_bar > G_BARS_SEEN) cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(cache_bar != G_BARS_SEEN)
   {
      cache_dir = TrendReversalDirectionRaw(cache_reason, cache_div);
      cache_bar = G_BARS_SEEN;
   }

   reason = cache_reason;
   divergence_confirmed = cache_div;
   return cache_dir;
}

// ============================================================================
// V31.6i NEW: MULTI-TIMEFRAME STRUCTURE ALIGNMENT
// Counts how many independent timeframes (M15/H1/H4/D1) currently agree with a direction -
// a genuine meta-signal none of our individual TF checks provided on their own.
// ============================================================================
int SimpleTFDirection(const ENUM_TIMEFRAMES tf, const int lookback)
{
   double close_now = CandleClose(tf, 1);
   double close_then = CandleClose(tf, MathMax(2, lookback));
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0;

   // Original behaviour: bare 2-point net close move.
   int net_dir = 0;
   if(close_now > close_then) net_dir = 1;
   else if(close_now < close_then) net_dir = -1;

   if(!EnableStructureTrend)
      return net_dir;   // keep the old simple behaviour if disabled

   int lb = MathMax(3, lookback);

   // Check 2 - slope: compare the average of the recent half of the window to the older half. A
   // rising average over the window is a cleaner "which way is it leaning" than two lone closes.
   int half = MathMax(1, lb / 2);
   double recent_sum = 0.0, older_sum = 0.0;
   int recent_n = 0, older_n = 0;
   for(int b = 1; b <= half; b++)
   {
      double c = CandleClose(tf, b);
      if(c > 0.0) { recent_sum += c; recent_n++; }
   }
   for(int b = half + 1; b <= lb; b++)
   {
      double c = CandleClose(tf, b);
      if(c > 0.0) { older_sum += c; older_n++; }
   }
   int slope_dir = 0;
   if(recent_n > 0 && older_n > 0)
   {
      double recent_avg = recent_sum / recent_n;
      double older_avg  = older_sum / older_n;
      if(recent_avg > older_avg) slope_dir = 1;
      else if(recent_avg < older_avg) slope_dir = -1;
   }

   // Check 3 - structure: are the highs and lows stepping up (HH/HL) or down (LH/LL) across the
   // window? Count how many bars make a higher-high-and-higher-low vs lower-high-and-lower-low.
   int up_steps = 0, dn_steps = 0;
   for(int b = 1; b < lb; b++)
   {
      double h_new = CandleHigh(tf, b),   l_new = CandleLow(tf, b);
      double h_old = CandleHigh(tf, b + 1), l_old = CandleLow(tf, b + 1);
      if(h_new <= 0.0 || l_new <= 0.0 || h_old <= 0.0 || l_old <= 0.0)
         continue;
      if(h_new > h_old && l_new > l_old) up_steps++;
      else if(h_new < h_old && l_new < l_old) dn_steps++;
   }
   int struct_dir = 0;
   if(up_steps > dn_steps) struct_dir = 1;
   else if(dn_steps > up_steps) struct_dir = -1;

   // Require StructureTrendMinAgree of the three checks to point the SAME way.
   int up_votes = (net_dir == 1) + (slope_dir == 1) + (struct_dir == 1);
   int dn_votes = (net_dir == -1) + (slope_dir == -1) + (struct_dir == -1);
   int need = MathMax(2, MathMin(3, StructureTrendMinAgree));

   if(up_votes >= need && up_votes > dn_votes) return 1;
   if(dn_votes >= need && dn_votes > up_votes) return -1;
   return 0;   // checks disagree -> unclear, no false trend
}

int MTFAlignmentCount(const int direction)
{
   if(!EnableMTFAlignment || direction == 0)
      return 0;

   int agree = 0;
   if(SimpleTFDirection(PERIOD_M15, MTFAlignmentM15LookbackBars) == direction) agree++;

   // H1 uses the same Kalman-unified source as the rest of the bot when ready, for consistency.
   int h1_dir = KalmanTrendReady() ?
                ((G_KALMAN_TREND / _Point > KalmanTrendMinPoints) ? 1 :
                 (G_KALMAN_TREND / _Point < -KalmanTrendMinPoints ? -1 : 0)) :
                SimpleTFDirection(PERIOD_H1, MTFAlignmentH1LookbackBars);
   if(h1_dir == direction) agree++;

   if(SimpleTFDirection(PERIOD_H4, MTFAlignmentH4LookbackBars) == direction) agree++;
   if(D1OverallDirection() == direction) agree++;

   return agree;
}

// V31.1 fix: CENT HISOB MUAMMOSI. Cent brokerlar juftliklarni suffiks bilan nomlaydi
// (EURUSDc, EURUSD.m, EURUSDmicro...) va SymbolSelect("EURUSD") ularni topa olmaydi.
// Bu resolver avval aniq nomni sinaydi, topilmasa broker ro'yxatidan shu nom bilan
// BOSHLANADIGAN birinchi symbolni oladi. Natija keshda saqlanadi.
string G_DXY_RES1 = "";
string G_DXY_RES2 = "";
string G_DXY_RES3 = "";
bool   G_DXY_RESOLVE_TRIED = false;

string ResolveBrokerSymbol(const string base)
{
   if(StringLen(base) == 0)
      return "";
   if(SymbolSelect(base, true))
      return base;

   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      if(StringFind(name, base) == 0) // suffiksli variant: EURUSDc, EURUSD.m ...
      {
         if(SymbolSelect(name, true))
            return name;
      }
   }
   return "";
}

bool DXYProxyEnsureSymbols()
{
   if(!EnableDXYProxy)
      return false;

   if(!G_DXY_RESOLVE_TRIED)
   {
      G_DXY_RESOLVE_TRIED = true;
      G_DXY_RES1 = ResolveBrokerSymbol(DXYProxyPair1);
      G_DXY_RES2 = ResolveBrokerSymbol(DXYProxyPair2);
      G_DXY_RES3 = ResolveBrokerSymbol(DXYProxyPair3);

      // V31.6j new: explicit tester-consistency notice. DXY proxy relies on multi-symbol data
      // that may or may not be available in Strategy Tester depending on how it was set up -
      // rather than silently differing from live behavior, tell the user clearly, once.
      if((bool)MQLInfoInteger(MQL_TESTER))
      {
         bool dxy_available = (StringLen(G_DXY_RES1) > 0 && StringLen(G_DXY_RES2) > 0 && StringLen(G_DXY_RES3) > 0);
         PrintFormat("[SIRUS v31.6j DXY TESTER] Strategy Tester detected - DXY proxy is %s (needs %s/%s/%s data in this test)",
                     (dxy_available ? "AVAILABLE" : "NOT AVAILABLE - will behave as if EnableDXYProxy=false"),
                     DXYProxyPair1, DXYProxyPair2, DXYProxyPair3);
      }

      if(StringLen(G_DXY_RES1) > 0 && StringLen(G_DXY_RES2) > 0 && StringLen(G_DXY_RES3) > 0)
      {
         if((DXYProxyPrintOnUse && VerboseLogs) && (G_DXY_RES1 != DXYProxyPair1 || G_DXY_RES2 != DXYProxyPair2 || G_DXY_RES3 != DXYProxyPair3))
            PrintFormat("[SIRUS v31.1 DXY] cent/suffiks aniqlandi: %s, %s, %s", G_DXY_RES1, G_DXY_RES2, G_DXY_RES3);
      }
      else
         PrintFormat("[SIRUS v31.1 DXY] juftliklar topilmadi (%s/%s/%s) - DXY proxy o'chiq rejimda",
                     DXYProxyPair1, DXYProxyPair2, DXYProxyPair3);
   }

   return (StringLen(G_DXY_RES1) > 0 && StringLen(G_DXY_RES2) > 0 && StringLen(G_DXY_RES3) > 0);
}

double DXYProxyValue(const int shift)
{
   double eur = iClose(G_DXY_RES1, DXYProxyTF, shift);
   double gbp = iClose(G_DXY_RES2, DXYProxyTF, shift);
   double jpy = iClose(G_DXY_RES3, DXYProxyTF, shift);

   if(eur <= 0.0 || gbp <= 0.0 || jpy <= 0.0)
      return 0.0;

   // EUR/GBP quote USD as the counter currency (DXY moves inverse to them);
   // USDJPY quotes USD as the base currency (DXY moves with it). Weights normalized to sum to 1.
   return MathPow(eur, -0.693) * MathPow(gbp, -0.143) * MathPow(jpy, 0.164);
}

// +1 = dollar proxy strengthening, -1 = weakening, 0 = flat/not ready
int DXYProxyDirection(string &reason)
{
   reason = "DXY proxy disabled";
   if(!EnableDXYProxy)
      return 0;

   if(!DXYProxyEnsureSymbols())
   {
      reason = "DXY proxy symbols unavailable";
      return 0;
   }

   double now_val = DXYProxyValue(1);
   double old_val = DXYProxyValue(1 + MathMax(1, DXYProxyLookbackBars));

   if(now_val <= 0.0 || old_val <= 0.0)
   {
      reason = "DXY proxy data not ready";
      return 0;
   }

   double pct_change = (now_val - old_val) / old_val * 100.0;
   reason = StringFormat("DXY proxy %.4f -> %.4f (%.2f%%)", old_val, now_val, pct_change);

   if(pct_change >= DXYProxyMinSlopePercent)
      return 1;
   if(pct_change <= -DXYProxyMinSlopePercent)
      return -1;

   return 0;
}

// V31.6z37 NEW: same binary-vs-magnitude gap - DXYProxyDirection already computes pct_change
// internally but discards it once the threshold check passes. This exposes the magnitude
// (0-1, scaled relative to the slope threshold) so consumers can tell a barely-qualifying DXY
// move from a strongly-trending one, instead of treating them identically.
double DXYProxyMagnitude()
{
   if(!EnableDXYProxy || !DXYProxyEnsureSymbols())
      return 0.0;

   double now_val = DXYProxyValue(1);
   double old_val = DXYProxyValue(1 + MathMax(1, DXYProxyLookbackBars));
   if(now_val <= 0.0 || old_val <= 0.0)
      return 0.0;

   double pct_change = MathAbs((now_val - old_val) / old_val * 100.0);
   if(DXYProxyMinSlopePercent <= 0.0)
      return 0.0;

   return MathMax(0.0, MathMin(1.0, pct_change / (DXYProxyMinSlopePercent * 3.0)));
}

// V31.6z21 NEW: DXY DECELERATION - same pattern as ADX above, applied to the dollar proxy.
// DXYProxyDirection only checks the current slope's MAGNITUDE against a threshold; it never
// compares that slope to an OLDER window to see if the dollar move itself is losing momentum.
double DXYDecelerationFactor()
{
   if(!EnableDXYDeceleration || !EnableDXYProxy)
      return 0.0;

   if(!DXYProxyEnsureSymbols())
      return 0.0;

   int lb = MathMax(1, DXYProxyLookbackBars);
   double val_now = DXYProxyValue(1);
   double val_mid = DXYProxyValue(1 + lb);
   double val_old = DXYProxyValue(1 + lb * 2);

   if(val_now <= 0.0 || val_mid <= 0.0 || val_old <= 0.0 || val_mid == 0.0 || val_old == 0.0)
      return 0.0;

   double pct_recent = MathAbs((val_now - val_mid) / val_mid * 100.0);
   double pct_older = MathAbs((val_mid - val_old) / val_old * 100.0);

   if(pct_older <= 0.0)
      return 0.0;

   if(pct_recent < pct_older * DXYDecelerationThreshold)
      return MathMin(1.0, (pct_older - pct_recent) / MathMax(0.01, pct_older));

   return 0.0;
}

double DXYProxyLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableDXYProxy)
      return lot;

   string reason = "";
   int dxy_dir = DXYProxyDirection(reason);
   if(dxy_dir == 0)
      return lot;

   // Translate raw DXY direction into "which way it pushes THIS symbol's price".
   int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;

   bool against = (order_type == ORDER_TYPE_BUY && price_effect < 0) ||
                  (order_type == ORDER_TYPE_SELL && price_effect > 0);

   if(against)
   {
      if((DXYProxyPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v29 DXY] %s against dollar proxy trend (%s) - lot trimmed x%.2f",
                     (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), reason, DXYProxyLotFactor);
      return lot * DXYProxyLotFactor;
   }

   return lot;
}

double OrderFlowAvgVolume(const ENUM_TIMEFRAMES tf, const int lookback, const int start_shift)
{
   if(lookback <= 0)
      return 0.0;

   long sum = 0;
   int count = 0;
   for(int i = start_shift; i < start_shift + lookback; i++)
   {
      long v = iVolume(_Symbol, tf, i);
      if(v <= 0)
         continue;
      sum += v;
      count++;
   }

   if(count == 0)
      return 0.0;

   return (double)sum / count;
}

double OrderFlowConvictionRatio(const ENUM_TIMEFRAMES tf, const int shift)
{
   if(!EnableOrderFlow)
      return 1.0;

   double avg = OrderFlowAvgVolume(tf, OrderFlowLookbackBars, shift + 1);
   if(avg <= 0.0)
      return 1.0;

   long v = iVolume(_Symbol, tf, shift);
   if(v <= 0)
      return 1.0;

   return (double)v / avg;
}

// +1 = strong/confirmed volume, -1 = weak/suspicious volume, 0 = ordinary/inconclusive
int OrderFlowConvictionSign(const ENUM_TIMEFRAMES tf, const int shift)
{
   if(!EnableOrderFlow)
      return 0;

   double ratio = OrderFlowConvictionRatio(tf, shift);

   if(ratio >= OrderFlowHighMultiplier)
      return 1;
   if(ratio <= OrderFlowLowMultiplier)
      return -1;

   return 0;
}

bool FVGDetectBullish(const ENUM_TIMEFRAMES tf, const int shift, double &gap_low, double &gap_high)
{
   double c1_high = CandleHigh(tf, shift + 2);
   double c3_low  = CandleLow(tf, shift);
   if(c1_high <= 0.0 || c3_low <= 0.0)
      return false;

   if(c3_low > c1_high)
   {
      gap_low  = c1_high;
      gap_high = c3_low;
      return true;
   }
   return false;
}

bool FVGDetectBearish(const ENUM_TIMEFRAMES tf, const int shift, double &gap_low, double &gap_high)
{
   double c1_low  = CandleLow(tf, shift + 2);
   double c3_high = CandleHigh(tf, shift);
   if(c1_low <= 0.0 || c3_high <= 0.0)
      return false;

   if(c1_low > c3_high)
   {
      gap_low  = c3_high;
      gap_high = c1_low;
      return true;
   }
   return false;
}

// formed_shift is the gap's FIRST candle (c1); c2 is the displacement that made the gap and c3
// closes it off. Only candles AFTER c3 can fill it. FIX(fvg-always-filled): the scan used to start
// at c2 - the candle that spans the gap by definition - so every gap read as filled and the FVG
// zones never existed.
bool FVGIsFilled(const ENUM_TIMEFRAMES tf, const int formed_shift, const double gap_low, const double gap_high)
{
   for(int i = formed_shift - 3; i >= 1; i--)
   {
      double lo = CandleLow(tf, i);
      double hi = CandleHigh(tf, i);
      if(lo <= 0.0 || hi <= 0.0)
         continue;
      if(lo <= gap_high && hi >= gap_low)
         return true;
   }
   return false;
}

// SPEED: the unfilled gaps depend only on closed FVGTimeframe candles, so the list is built once per
// bar of that timeframe (it was a 100 x 100 candle scan on every lookup).
#define FVG_CACHE_MAX 64
double   G_FVG_BU_LO[FVG_CACHE_MAX], G_FVG_BU_HI[FVG_CACHE_MAX];
double   G_FVG_BE_LO[FVG_CACHE_MAX], G_FVG_BE_HI[FVG_CACHE_MAX];
int      G_FVG_BU_N = 0, G_FVG_BE_N = 0;
datetime G_FVG_CACHE_BAR = 0;

void FVGCacheRefresh()
{
   datetime t0 = iTime(_Symbol, FVGTimeframe, 0);
   if(t0 == G_FVG_CACHE_BAR || (t0 <= 0 && G_FVG_CACHE_BAR > 0))
      return;   // same bar, or history not loaded yet - keep the list we have
   G_FVG_CACHE_BAR = t0;
   G_FVG_BU_N = 0;
   G_FVG_BE_N = 0;
   double min_gap = MathMax(1, FVGMinGapPoints) * _Point;
   for(int shift = 1; shift <= FVGLookbackBars; shift++)
   {
      double gl = 0.0, gh = 0.0;
      if(G_FVG_BU_N < FVG_CACHE_MAX && FVGDetectBullish(FVGTimeframe, shift, gl, gh) &&
         (gh - gl) >= min_gap && !FVGIsFilled(FVGTimeframe, shift + 2, gl, gh))
      {
         G_FVG_BU_LO[G_FVG_BU_N] = gl;
         G_FVG_BU_HI[G_FVG_BU_N] = gh;
         G_FVG_BU_N++;
      }
      if(G_FVG_BE_N < FVG_CACHE_MAX && FVGDetectBearish(FVGTimeframe, shift, gl, gh) &&
         (gh - gl) >= min_gap && !FVGIsFilled(FVGTimeframe, shift + 2, gl, gh))
      {
         G_FVG_BE_LO[G_FVG_BE_N] = gl;
         G_FVG_BE_HI[G_FVG_BE_N] = gh;
         G_FVG_BE_N++;
      }
   }
}

// Nearest unfilled BULLISH gap below price - formed during an up-move, left behind as a
// potential support/magnet.
double FVGNearestSupport(const double price)
{
   if(!EnableFVGZones || price <= 0.0)
      return 0.0;
   FVGCacheRefresh();

   double best = 0.0;
   for(int i = 0; i < G_FVG_BU_N; i++)
   {
      double gh = G_FVG_BU_HI[i];
      if(gh >= price)
         continue;
      if(best == 0.0 || gh > best)
         best = gh;
   }
   return best;
}

// Nearest unfilled BEARISH gap above price - formed during a down-move, left behind as a
// potential resistance/magnet.
double FVGNearestResistance(const double price)
{
   if(!EnableFVGZones || price <= 0.0)
      return 0.0;
   FVGCacheRefresh();

   double best = 0.0;
   for(int i = 0; i < G_FVG_BE_N; i++)
   {
      double gl = G_FVG_BE_LO[i];
      if(gl <= price)
         continue;
      if(best == 0.0 || gl < best)
         best = gl;
   }
   return best;
}

double ZoneMapRawNearestResistance(const double price)
{
   double best = 0.0;

   if(EnableZoneMapM5)
      for(int i = 2; i <= ZoneMapLookbackM5; i++)
      {
         double h = CandleHigh(PERIOD_M5, i);
         if(h > price && (best == 0.0 || h < best))
            best = h;
      }
   for(int i = 2; i <= ZoneMapLookbackM15; i++)
   {
      double h = CandleHigh(PERIOD_M15, i);
      if(h > price && (best == 0.0 || h < best))
         best = h;
   }
   if(EnableZoneMapM30)
      for(int i = 2; i <= ZoneMapLookbackM30; i++)
      {
         double h = CandleHigh(PERIOD_M30, i);
         if(h > price && (best == 0.0 || h < best))
            best = h;
      }
   for(int i = 2; i <= ZoneMapLookbackH1; i++)
   {
      double h = CandleHigh(PERIOD_H1, i);
      if(h > price && (best == 0.0 || h < best))
         best = h;
   }
   if(EnableZoneMapH4)
      for(int i = 2; i <= ZoneMapLookbackH4; i++)
      {
         double h = CandleHigh(PERIOD_H4, i);
         if(h > price && (best == 0.0 || h < best))
            best = h;
      }
   if(EnableZoneMapD1)
      for(int i = 2; i <= ZoneMapLookbackD1; i++)
      {
         double h = CandleHigh(PERIOD_D1, i);
         if(h > price && (best == 0.0 || h < best))
            best = h;
      }

   return best;
}

double ZoneMapRawNearestSupport(const double price)
{
   double best = 0.0;

   if(EnableZoneMapM5)
      for(int i = 2; i <= ZoneMapLookbackM5; i++)
      {
         double l = CandleLow(PERIOD_M5, i);
         if(l > 0.0 && l < price && (best == 0.0 || l > best))
            best = l;
      }
   for(int i = 2; i <= ZoneMapLookbackM15; i++)
   {
      double l = CandleLow(PERIOD_M15, i);
      if(l > 0.0 && l < price && (best == 0.0 || l > best))
         best = l;
   }
   if(EnableZoneMapM30)
      for(int i = 2; i <= ZoneMapLookbackM30; i++)
      {
         double l = CandleLow(PERIOD_M30, i);
         if(l > 0.0 && l < price && (best == 0.0 || l > best))
            best = l;
      }
   for(int i = 2; i <= ZoneMapLookbackH1; i++)
   {
      double l = CandleLow(PERIOD_H1, i);
      if(l > 0.0 && l < price && (best == 0.0 || l > best))
         best = l;
   }
   if(EnableZoneMapH4)
      for(int i = 2; i <= ZoneMapLookbackH4; i++)
      {
         double l = CandleLow(PERIOD_H4, i);
         if(l > 0.0 && l < price && (best == 0.0 || l > best))
            best = l;
      }
   if(EnableZoneMapD1)
      for(int i = 2; i <= ZoneMapLookbackD1; i++)
      {
         double l = CandleLow(PERIOD_D1, i);
         if(l > 0.0 && l < price && (best == 0.0 || l > best))
            best = l;
      }

   return best;
}

// V31.6k CRITICAL performance fix: Zone Map's swing scan (LegacyIsSwingHigh/Low across up to
// 6 timeframes) is called from 26 different places this session alone - TP capping, momentum
// caution, grid distance, SZR, FBR, Near-Zone, Trend Reversal, Swing Impulse, Zone Reliability.
// It had ZERO caching, meaning every one of those 26 call sites re-scanned candles from scratch
// on every tick - even though swing points only change once a NEW bar closes. This caches the
// expensive part (finding every confirmed swing point) once per bar; the "nearest to this
// price" search below becomes a cheap array scan instead of a full re-scan.
// (SIRUS_ZM_CACHE_TF_COUNT / SIRUS_ZM_CACHE_MAX moved above ZoneBandOnTF - preprocessor defines must precede first use)
// (the G_ZMC_* swing cache arrays are declared with the other engine state near the top - the
// liquidity, path-density, scale and zone-edge modules all read them from well above this point)

int ZMTFIndex(const ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M5)  return 0;
   if(tf == PERIOD_M15) return 1;
   if(tf == PERIOD_M30) return 2;
   if(tf == PERIOD_H1)  return 3;
   if(tf == PERIOD_H4)  return 4;
   if(tf == PERIOD_D1)  return 5;
   if(tf == PERIOD_M1)  return 6;
   return -1;
}

void ZoneMapRefreshSwingCache()
{
   if(G_ZMC_CACHE_BAR == G_BARS_SEEN)
      return;

   int depth = MathMax(1, ZoneMapSwingDepth);

   ENUM_TIMEFRAMES tfs[7]    = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_M1};
   int lookbacks[7]          = {ZoneMapLookbackM5, ZoneMapLookbackM15, ZoneMapLookbackM30,
                                 ZoneMapLookbackH1, ZoneMapLookbackH4, ZoneMapLookbackD1, ZoneMapLookbackM1};
   bool tf_enabled[7]        = {EnableZoneMapM5, true, EnableZoneMapM30, true, EnableZoneMapH4, EnableZoneMapD1, EnableZoneMapM1};

   for(int t = 0; t < SIRUS_ZM_CACHE_TF_COUNT; t++)
   {
      G_ZMC_HIGH_COUNT[t] = 0;
      G_ZMC_LOW_COUNT[t] = 0;

      if(!tf_enabled[t])
         continue;

      for(int i = depth + 1; i <= lookbacks[t] && G_ZMC_HIGH_COUNT[t] < SIRUS_ZM_CACHE_MAX; i++)
      {
         if(LegacyIsSwingHigh(tfs[t], i, depth))
         {
            G_ZMC_HIGH_PRICE[t][G_ZMC_HIGH_COUNT[t]] = CandleHigh(tfs[t], i);
            G_ZMC_HIGH_SHIFT[t][G_ZMC_HIGH_COUNT[t]] = i;
            G_ZMC_HIGH_COUNT[t]++;
         }
      }

      for(int i = depth + 1; i <= lookbacks[t] && G_ZMC_LOW_COUNT[t] < SIRUS_ZM_CACHE_MAX; i++)
      {
         if(LegacyIsSwingLow(tfs[t], i, depth))
         {
            G_ZMC_LOW_PRICE[t][G_ZMC_LOW_COUNT[t]] = CandleLow(tfs[t], i);
            G_ZMC_LOW_SHIFT[t][G_ZMC_LOW_COUNT[t]] = i;
            G_ZMC_LOW_COUNT[t]++;
         }
      }
   }

   G_ZMC_CACHE_BAR = G_BARS_SEEN;
}

// V29 fix (A2): unifies Zone Map (6-TF breadth) with the old Legacy system's swing-point rigor
// (a level only counts if it's a genuine confirmed local extreme, not just any candle wick).
// Falls back to the raw scan above only if no confirmed swing point exists nearby.
// ============================================================================
// V110: MARKET STRUCTURE READER - reads the swing chain as a sequence.
// Uses the per-bar swing cache the zone map already builds (index 0 = most
// recent swing, ascending index = further back), so this costs almost nothing.
// Sets G_STRUCTURE_DIR / G_STRUCTURE_STEPS / G_STRUCTURE_DETAIL.
// ============================================================================
// ============================================================================
// V111: MARKET STRUCTURE READER - reads the swing chain as a sequence.
// Uses the per-bar swing cache the zone map already builds (index 0 = most
// recent swing, ascending index = further back), so this costs almost nothing.
//
// StructureReadTF() is the pure reader for ONE timeframe. MarketStructureRead()
// below runs it on the trading timeframe AND on a higher one, then combines the
// two into a single context - which is how a trader actually reads a chart:
// "H1 is bullish and M15 is pulling back" is a buy setup, while the same M15
// reading under a bearish H1 is a continuation of the larger downtrend.
// ============================================================================
void StructureReadTF(const ENUM_TIMEFRAMES tf,
                     int &dir, int &steps,
                     double &invalidation, double &continuation,
                     int &event, string &event_txt)
{
   dir = 0; steps = 0; invalidation = 0.0; continuation = 0.0; event = 0; event_txt = "";

   int t = ZMTFIndex(tf);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT)
      return;

   // Need three of each to see two consecutive steps in both the highs and the lows.
   if(G_ZMC_HIGH_COUNT[t] < 3 || G_ZMC_LOW_COUNT[t] < 3)
      return;

   double h0 = G_ZMC_HIGH_PRICE[t][0];   // newest swing high
   double h1 = G_ZMC_HIGH_PRICE[t][1];
   double h2 = G_ZMC_HIGH_PRICE[t][2];
   double l0 = G_ZMC_LOW_PRICE[t][0];    // newest swing low
   double l1 = G_ZMC_LOW_PRICE[t][1];
   double l2 = G_ZMC_LOW_PRICE[t][2];

   if(h0 <= 0.0 || h1 <= 0.0 || h2 <= 0.0 || l0 <= 0.0 || l1 <= 0.0 || l2 <= 0.0)
      return;

   // Four independent steps in the chain. Each votes bullish or bearish.
   int bull = 0, bear = 0;
   if(h0 > h1) bull++; else bear++;      // newest high vs previous high
   if(h1 > h2) bull++; else bear++;      // previous high vs the one before it
   if(l0 > l1) bull++; else bear++;      // newest low vs previous low
   if(l1 > l2) bull++; else bear++;      // previous low vs the one before it

   int need = MathMax(1, MathMin(4, MarketStructureMinSteps));

   if(bull >= need && bull > bear)      { dir = 1;  steps = bull; }
   else if(bear >= need && bear > bull) { dir = -1; steps = bear; }
   else                                 { dir = 0;  steps = MathMax(bull, bear); }

   if(dir == 0)
      return;   // mixed chain - no levels or events to report

   // Invalidation = the swing that must hold for the structure to remain true.
   // Continuation = the swing that must break for the structure to extend.
   if(dir > 0) { invalidation = l0; continuation = h0; }
   else        { invalidation = h0; continuation = l0; }

   double close_now = CandleClose(tf, 1);
   if(close_now <= 0.0)
      return;

   if(dir > 0)
   {
      if(close_now < invalidation)
      {
         event = -1;
         event_txt = StringFormat("CHoCH: closed below the higher-low %.2f", invalidation);
      }
      else if(close_now > continuation)
      {
         event = 1;
         event_txt = StringFormat("BOS: closed above the swing high %.2f", continuation);
      }
   }
   else
   {
      if(close_now > invalidation)
      {
         event = -1;
         event_txt = StringFormat("CHoCH: closed above the lower-high %.2f", invalidation);
      }
      else if(close_now < continuation)
      {
         event = 1;
         event_txt = StringFormat("BOS: closed below the swing low %.2f", continuation);
      }
   }
}

void MarketStructureRead()
{
   static int last_bar = -100000;
   if(last_bar > G_BARS_SEEN) last_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(last_bar == G_BARS_SEEN)
      return;                      // one reading per bar is enough - swings only change on close
   last_bar = G_BARS_SEEN;

   G_STRUCTURE_DIR    = 0;
   G_STRUCTURE_STEPS  = 0;
   G_STRUCTURE_DETAIL = "structure: n/a";
   G_STRUCTURE_INVALIDATION = 0.0;
   G_STRUCTURE_CONTINUATION = 0.0;
   G_STRUCTURE_EVENT        = 0;
   G_STRUCTURE_EVENT_TXT    = "";
   G_STRUCTURE_HTF_DIR      = 0;
   G_STRUCTURE_HTF_STEPS    = 0;
   G_STRUCTURE_CONTEXT      = STRUCT_CTX_UNCLEAR;
   G_STRUCTURE_CONTEXT_TXT  = "";

   if(!EnableMarketStructure)
      return;

   ZoneMapRefreshSwingCache();     // guarded internally; ensures the cache is populated

   // --- trading-timeframe structure ---
   StructureReadTF(MarketStructureTF, G_STRUCTURE_DIR, G_STRUCTURE_STEPS,
                   G_STRUCTURE_INVALIDATION, G_STRUCTURE_CONTINUATION,
                   G_STRUCTURE_EVENT, G_STRUCTURE_EVENT_TXT);

   // --- higher-timeframe structure (the context the trading TF sits inside) ---
   if(EnableStructureHTF)
   {
      double htf_inval = 0.0, htf_cont = 0.0; int htf_event = 0; string htf_evt_txt = "";
      StructureReadTF(StructureHTF, G_STRUCTURE_HTF_DIR, G_STRUCTURE_HTF_STEPS,
                      htf_inval, htf_cont, htf_event, htf_evt_txt);
   }

   // --- combine the two into one context -------------------------------------------------------
   // This is the reading a trader gives out loud. The same lower-TF structure means very different
   // things depending on the frame it sits in: a bearish M15 inside a bullish H1 is a PULLBACK (a
   // buying opportunity, and a dangerous place to sell), while the same M15 inside a bearish H1 is
   // simply the trend continuing.
   if(G_STRUCTURE_HTF_DIR != 0 && G_STRUCTURE_DIR != 0)
   {
      if(G_STRUCTURE_HTF_DIR == G_STRUCTURE_DIR)
         G_STRUCTURE_CONTEXT = (G_STRUCTURE_DIR > 0 ? STRUCT_CTX_ALIGNED_UP : STRUCT_CTX_ALIGNED_DOWN);
      else
         G_STRUCTURE_CONTEXT = (G_STRUCTURE_HTF_DIR > 0 ? STRUCT_CTX_PULLBACK_IN_UP : STRUCT_CTX_PULLBACK_IN_DOWN);
   }
   else if(G_STRUCTURE_HTF_DIR != 0 || G_STRUCTURE_DIR != 0)
      G_STRUCTURE_CONTEXT = STRUCT_CTX_PARTIAL;
   else
      G_STRUCTURE_CONTEXT = STRUCT_CTX_UNCLEAR;

   switch(G_STRUCTURE_CONTEXT)
   {
      case STRUCT_CTX_ALIGNED_UP:        G_STRUCTURE_CONTEXT_TXT = "both frames bullish";            break;
      case STRUCT_CTX_ALIGNED_DOWN:      G_STRUCTURE_CONTEXT_TXT = "both frames bearish";            break;
      case STRUCT_CTX_PULLBACK_IN_UP:    G_STRUCTURE_CONTEXT_TXT = "pullback inside a bullish HTF";  break;
      case STRUCT_CTX_PULLBACK_IN_DOWN:  G_STRUCTURE_CONTEXT_TXT = "bounce inside a bearish HTF";    break;
      case STRUCT_CTX_PARTIAL:           G_STRUCTURE_CONTEXT_TXT = "only one frame is clear";        break;
      default:                           G_STRUCTURE_CONTEXT_TXT = "no clear structure";             break;
   }

   string label = (G_STRUCTURE_DIR > 0 ? "BULL" : (G_STRUCTURE_DIR < 0 ? "BEAR" : "MIXED"));
   string htf_label = (G_STRUCTURE_HTF_DIR > 0 ? "BULL" : (G_STRUCTURE_HTF_DIR < 0 ? "BEAR" : "MIXED"));

   G_STRUCTURE_DETAIL = StringFormat("structure %s %s %d/4 | %s %s %d/4 | %s",
                                     TFToString(MarketStructureTF), label, G_STRUCTURE_STEPS,
                                     TFToString(StructureHTF), htf_label, G_STRUCTURE_HTF_STEPS,
                                     G_STRUCTURE_CONTEXT_TXT);
   if(G_STRUCTURE_DIR != 0)
      G_STRUCTURE_DETAIL += StringFormat(" | holds %.2f", G_STRUCTURE_INVALIDATION);
   if(G_STRUCTURE_EVENT != 0)
      G_STRUCTURE_DETAIL += " | " + G_STRUCTURE_EVENT_TXT;

   if((MarketStructurePrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v112 STRUCTURE] %s", G_STRUCTURE_DETAIL);
}

void ZoneMapScanTFResistance(const ENUM_TIMEFRAMES tf, const int lookback, const double price, double &best)
{
   ZoneMapRefreshSwingCache();
   int t = ZMTFIndex(tf);
   if(t < 0)
      return;

   // FIX(v243-support-only-asymmetry): V243 added ZoneNearAboveTolerance to the SUPPORT scan - "a
   // support that price has just risen through is still the support it was a minute ago" - and
   // never mirrored it here. So a SELL kept seeing a support it had just cleared (good, that is the
   // V243 intent), while a BUY discarded a resistance the moment price ticked one point above its
   // nearest member: the reported "nearest resistance" jumped to the next level up, the distance
   // grew, and the strength was read off the wrong level. That is the BUY half of "opens into the
   // wall", and it is why the SELL half looked partly fixed while the BUY half did not.
   // Ranked, not just "smallest qualifying". `best` is the MINIMUM h, so a lenient `h > price-tol`
   // would let a level BELOW price outrank the genuine resistance overhead - and because the PDH
   // and FVG fallbacks further down all test `< best`, they would then be masked too. A level
   // price has just poked above is still worth seeing (the V243 intent), but only when there is
   // nothing actually ahead.
   double h_tol = ScaleAdjustedPoints(MathMax(1, ZoneNearAboveTolerance)) * _Point;
   for(int k = 0; k < G_ZMC_HIGH_COUNT[t]; k++)
   {
      double h = G_ZMC_HIGH_PRICE[t][k];
      if(h <= 0.0 || h < price - h_tol)
         continue;
      // V201: back to plain nearest here. Ranking by strength belongs in one place, and that place
      // already exists - EnableStrongZoneOverride, which was written for exactly this and had been
      // left off. Doing it in both would mean two different rules deciding the same question.
      bool best_is_behind = (best > 0.0 && best < price);
      if(best == 0.0)
         best = h;
      else if(h >= price && (best_is_behind || h < best))
         best = h;                       // anything genuinely ahead outranks anything behind
      else if(h < price && best_is_behind && h > best)
         best = h;                       // both behind: keep the nearer one
   }
}

void ZoneMapScanTFSupport(const ENUM_TIMEFRAMES tf, const int lookback, const double price, double &best)
{
   ZoneMapRefreshSwingCache();
   int t = ZMTFIndex(tf);
   if(t < 0)
      return;

   for(int k = 0; k < G_ZMC_LOW_COUNT[t]; k++)
   {
      double l = G_ZMC_LOW_PRICE[t][k];
      // V201: plain nearest - see the resistance side. Strength ranking lives in StrongZoneOverride.
      //
      // V243: swings slightly ABOVE price still count. From a live loss - a sell at 4485.10 with
      // support swings at 4484.20, 4485.00 and 4485.80. The strict "below price" test threw away
      // the 4485.80 swing and reported 4485.00, so the level looked like a single point ninety
      // cents down rather than a shelf price was standing in the middle of. A support that price
      // has just risen through is still the support it was a minute ago.
      double l_tol = ScaleAdjustedPoints(MathMax(1, ZoneNearAboveTolerance)) * _Point;
      // FIX(support-collapse-to-price): was `best = MathMin(l, price)`. For the V243 case this
      // comment describes (l sits slightly ABOVE price, within tolerance), MathMin(l, price) always
      // evaluates to `price` itself - so the function returned the current price as "the nearest
      // support" instead of the real swing level, silently discarding exactly the level V243 was
      // added to keep. Keep the actual swing price; it's already been range-checked above.
      if(l > 0.0 && l < price + l_tol && (best == 0.0 || l > best))
         best = l;
   }
}

double ZoneMapNearestResistanceCalc(const double price)
{
   double best = 0.0;

   if(!EnableZoneMapSwingConfirm)
      best = ZoneMapRawNearestResistance(price);
   else
   {
      if(EnableZoneMapM5)
         ZoneMapScanTFResistance(PERIOD_M5, ZoneMapLookbackM5, price, best);
      ZoneMapScanTFResistance(PERIOD_M15, ZoneMapLookbackM15, price, best);
      if(EnableZoneMapM30)
         ZoneMapScanTFResistance(PERIOD_M30, ZoneMapLookbackM30, price, best);
      ZoneMapScanTFResistance(PERIOD_H1, ZoneMapLookbackH1, price, best);
      if(EnableZoneMapH4)
         ZoneMapScanTFResistance(PERIOD_H4, ZoneMapLookbackH4, price, best);
      if(EnableZoneMapD1)
         ZoneMapScanTFResistance(PERIOD_D1, ZoneMapLookbackD1, price, best);
      if(EnableZoneMapM1)
         ZoneMapScanTFResistance(PERIOD_M1, ZoneMapLookbackM1, price, best);

      if(best == 0.0)
         best = ZoneMapRawNearestResistance(price);
   }

   if(EnableFVGZones)
   {
      double fvg = FVGNearestResistance(price);
      if(fvg > 0.0 && (best == 0.0 || fvg < best))
      {
         if((FVGPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v29 FVG] unfilled bearish gap %.5f closer than swing zone %.5f", fvg, best);
         best = fvg;
      }
   }

   // FEATURE(daily-bias): the D1 swing scan above starts at shift 2 and so SKIPS yesterday's
   // high entirely. PDH is one of the most-watched intraday resistance levels, so add it here
   // as an explicit candidate: if PDH sits above price and closer than anything found so far,
   // it becomes the nearest resistance. Its extra strength is applied later in ZoneMapStrength.
   if(EnableDailyBias && EnableDailyLevelsAsZones && G_PDH > price && (best == 0.0 || G_PDH < best))
      best = G_PDH;

   // FEATURE(strong-zone-override): mirror of the support side - if a clearly stronger resistance
   // sits a little further up (within the search window) and its weighted score beats the nearest
   // one's by the required ratio, prefer it over the merely-closest level above price.
   // V203: skip the strongest-nearby search when it is what called us. Without this the two
   // functions bounce between each other until the stack runs out.
   if(EnableStrongZoneOverride && best > 0.0 && !G_ZONE_LOOKUP_BUSY)
   {
      double strong_price = ZoneMapBestWeightedResistance(price, (double)StrongZoneSearchPoints);
      if(strong_price > 0.0 && strong_price > best)   // strictly further from price (higher) than nearest
      {
         double near_score = ZoneMapStrength(best);
         double strong_str = ZoneMapStrength(strong_price);
         if(near_score > 0.0 && strong_str >= near_score * StrongZoneMinScoreRatio)
            best = strong_price;
      }
   }

   return best;
}

// V31.6z42 NEW: TF-weighted per-TF scan - cheap alternative to full ZoneMapStrength() per
// candidate (which would require an expensive multi-TF confluence scan for EVERY point in
// range - too costly to call per-candidate). Uses the TIMEFRAME ITSELF as a cheap proxy for
// structural significance (a D1 swing is inherently more significant than an M1 one) blended
// with distance, so a genuinely major HTF level slightly further away can outrank a trivial,
// barely-closer M1/M5 swing - a single pass, no nested loops, no new indicator calls.
double ZoneMapTFSignificanceWeight(const ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_D1)  return 3.0;
   if(tf == PERIOD_H4)  return 2.4;
   if(tf == PERIOD_H1)  return 1.8;
   if(tf == PERIOD_M30) return 1.3;
   if(tf == PERIOD_M15) return 1.0;
   if(tf == PERIOD_M5)  return 0.7;
   if(tf == PERIOD_M1)  return 0.4;
   return 1.0;
}

void ZoneMapScanTFResistanceWeighted(const ENUM_TIMEFRAMES tf, const double price, const double search_limit_pts,
                                      double &best_price, double &best_score)
{
   ZoneMapRefreshSwingCache();
   int t = ZMTFIndex(tf);
   if(t < 0)
      return;

   double tf_weight = ZoneMapTFSignificanceWeight(tf);

   for(int k = 0; k < G_ZMC_HIGH_COUNT[t]; k++)
   {
      double h = G_ZMC_HIGH_PRICE[t][k];
      if(h <= price)
         continue;

      double dist_pts = (h - price) / _Point;
      if(dist_pts > search_limit_pts)
         continue;

      double score = tf_weight - dist_pts * ZoneMapBestPickDistancePenalty;
      if(score > best_score)
      {
         best_score = score;
         best_price = h;
      }
   }
}

void ZoneMapScanTFSupportWeighted(const ENUM_TIMEFRAMES tf, const double price, const double search_limit_pts,
                                   double &best_price, double &best_score)
{
   ZoneMapRefreshSwingCache();
   int t = ZMTFIndex(tf);
   if(t < 0)
      return;

   double tf_weight = ZoneMapTFSignificanceWeight(tf);

   for(int k = 0; k < G_ZMC_LOW_COUNT[t]; k++)
   {
      double l = G_ZMC_LOW_PRICE[t][k];
      if(l <= 0.0 || l >= price)
         continue;

      double dist_pts = (price - l) / _Point;
      if(dist_pts > search_limit_pts)
         continue;

      double score = tf_weight - dist_pts * ZoneMapBestPickDistancePenalty;
      if(score > best_score)
      {
         best_score = score;
         best_price = l;
      }
   }
}

// The consumer-facing "best within range" finder - scans ALL enabled TFs using the weighted
// score above instead of pure nearest-wins, so a moderately-strong-but-slightly-further HTF
// level isn't invisible just because a trivial closer swing technically qualifies first.
double ZoneMapBestWeightedResistance(const double price, const double search_limit_pts)
{
   // V203: mark the lookup as in progress. Both fallbacks below call ZoneMapNearestResistance(), which
   // consults this function again through the strong-zone override - a loop with no exit, and the
   // reason the EA hit a stack overflow before receiving its first tick. The flag lets the nearest
   // lookup know it is already inside this search and skip the override.
   bool zl_outer = G_ZONE_LOOKUP_BUSY;
   G_ZONE_LOOKUP_BUSY = true;

   if(!EnableZoneMapBestPick)
   {
      double zl_r = ZoneMapNearestResistance(price);
      G_ZONE_LOOKUP_BUSY = zl_outer;
      return zl_r;
   }

   double best_price = 0.0, best_score = -999999.0;

   if(EnableZoneMapM5)  ZoneMapScanTFResistanceWeighted(PERIOD_M5, price, search_limit_pts, best_price, best_score);
   ZoneMapScanTFResistanceWeighted(PERIOD_M15, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapM30) ZoneMapScanTFResistanceWeighted(PERIOD_M30, price, search_limit_pts, best_price, best_score);
   ZoneMapScanTFResistanceWeighted(PERIOD_H1, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapH4)  ZoneMapScanTFResistanceWeighted(PERIOD_H4, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapD1)  ZoneMapScanTFResistanceWeighted(PERIOD_D1, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapM1)  ZoneMapScanTFResistanceWeighted(PERIOD_M1, price, search_limit_pts, best_price, best_score);

   if(best_price == 0.0)
   {
      double zl_fb = ZoneMapNearestResistance(price);
      G_ZONE_LOOKUP_BUSY = zl_outer;
      return zl_fb;
   }

   G_ZONE_LOOKUP_BUSY = zl_outer;
   return best_price;
}

double ZoneMapBestWeightedSupport(const double price, const double search_limit_pts)
{
   // V203: mark the lookup as in progress. Both fallbacks below call ZoneMapNearestSupport(), which
   // consults this function again through the strong-zone override - a loop with no exit, and the
   // reason the EA hit a stack overflow before receiving its first tick. The flag lets the nearest
   // lookup know it is already inside this search and skip the override.
   bool zl_outer = G_ZONE_LOOKUP_BUSY;
   G_ZONE_LOOKUP_BUSY = true;

   if(!EnableZoneMapBestPick)
   {
      double zl_r = ZoneMapNearestSupport(price);
      G_ZONE_LOOKUP_BUSY = zl_outer;
      return zl_r;
   }

   double best_price = 0.0, best_score = -999999.0;

   if(EnableZoneMapM5)  ZoneMapScanTFSupportWeighted(PERIOD_M5, price, search_limit_pts, best_price, best_score);
   ZoneMapScanTFSupportWeighted(PERIOD_M15, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapM30) ZoneMapScanTFSupportWeighted(PERIOD_M30, price, search_limit_pts, best_price, best_score);
   ZoneMapScanTFSupportWeighted(PERIOD_H1, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapH4)  ZoneMapScanTFSupportWeighted(PERIOD_H4, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapD1)  ZoneMapScanTFSupportWeighted(PERIOD_D1, price, search_limit_pts, best_price, best_score);
   if(EnableZoneMapM1)  ZoneMapScanTFSupportWeighted(PERIOD_M1, price, search_limit_pts, best_price, best_score);

   if(best_price == 0.0)
   {
      double zl_fb = ZoneMapNearestSupport(price);
      G_ZONE_LOOKUP_BUSY = zl_outer;
      return zl_fb;
   }

   G_ZONE_LOOKUP_BUSY = zl_outer;
   return best_price;
}

double ZoneMapNearestSupportCalc(const double price)
{
   double best = 0.0;

   if(!EnableZoneMapSwingConfirm)
      best = ZoneMapRawNearestSupport(price);
   else
   {
      if(EnableZoneMapM5)
         ZoneMapScanTFSupport(PERIOD_M5, ZoneMapLookbackM5, price, best);
      ZoneMapScanTFSupport(PERIOD_M15, ZoneMapLookbackM15, price, best);
      if(EnableZoneMapM30)
         ZoneMapScanTFSupport(PERIOD_M30, ZoneMapLookbackM30, price, best);
      ZoneMapScanTFSupport(PERIOD_H1, ZoneMapLookbackH1, price, best);
      if(EnableZoneMapH4)
         ZoneMapScanTFSupport(PERIOD_H4, ZoneMapLookbackH4, price, best);
      if(EnableZoneMapD1)
         ZoneMapScanTFSupport(PERIOD_D1, ZoneMapLookbackD1, price, best);
      if(EnableZoneMapM1)
         ZoneMapScanTFSupport(PERIOD_M1, ZoneMapLookbackM1, price, best);

      if(best == 0.0)
         best = ZoneMapRawNearestSupport(price);
   }

   if(EnableFVGZones)
   {
      double fvg = FVGNearestSupport(price);
      if(fvg > 0.0 && (best == 0.0 || fvg > best))
      {
         if((FVGPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v29 FVG] unfilled bullish gap %.5f closer than swing zone %.5f", fvg, best);
         best = fvg;
      }
   }

   // FEATURE(daily-bias): add PDL (yesterday's low) as an explicit support candidate, mirror of
   // the PDH logic in ZoneMapNearestResistance - the D1 swing scan skipped yesterday entirely.
   if(EnableDailyBias && EnableDailyLevelsAsZones && G_PDL > 0.0 && G_PDL < price && (best == 0.0 || G_PDL > best))
      best = G_PDL;

   // FEATURE(strong-zone-override): the scan above returned the CLOSEST support. If a clearly
   // stronger support sits a little further down (within the search window) and its weighted score
   // beats the nearest one's by the required ratio, prefer it - that older, heavier level is where
   // price is actually likely to react, and ignoring it is what let price drift into deep drawdown.
   // V203: skip the strongest-nearby search when it is what called us. Without this the two
   // functions bounce between each other until the stack runs out.
   if(EnableStrongZoneOverride && best > 0.0 && !G_ZONE_LOOKUP_BUSY)
   {
      double strong_price = ZoneMapBestWeightedSupport(price, (double)StrongZoneSearchPoints);
      if(strong_price > 0.0 && strong_price < best)   // strictly further from price (lower) than nearest
      {
         double near_score = ZoneMapStrength(best);
         double strong_str = ZoneMapStrength(strong_price);
         if(near_score > 0.0 && strong_str >= near_score * StrongZoneMinScoreRatio)
            best = strong_price;
      }
   }

   return best;
}

// SPEED: about 120 call sites ask for the nearest support / resistance, many of them with the same
// price on the same tick, and each answer is a scan of seven timeframes plus the FVG list. The answer
// cannot change inside one tick, so it is remembered per (tick, price). The strongest-nearby search
// calls back in with its own guard set and gets a different answer on purpose - that path is never
// cached.
#define ZM_MEMO_SLOTS 16
ulong  G_ZM_MEMO_TICK[2][ZM_MEMO_SLOTS];
double G_ZM_MEMO_PX[2][ZM_MEMO_SLOTS];
double G_ZM_MEMO_VAL[2][ZM_MEMO_SLOTS];
int    G_ZM_MEMO_BAR[2][ZM_MEMO_SLOTS];   // swing-cache bar the answer was built from
int    G_ZM_MEMO_NEXT[2] = {0, 0};

double ZoneMapMemo(const int side, const double price)
{
   bool usable = (G_TICK_COUNT > 0 && !G_ZONE_LOOKUP_BUSY);
   if(usable)
      for(int i = 0; i < ZM_MEMO_SLOTS; i++)
         if(G_ZM_MEMO_TICK[side][i] == G_TICK_COUNT && G_ZM_MEMO_PX[side][i] == price &&
            G_ZM_MEMO_BAR[side][i] == G_ZMC_CACHE_BAR)
            return G_ZM_MEMO_VAL[side][i];
   double v = (side == 0) ? ZoneMapNearestSupportCalc(price) : ZoneMapNearestResistanceCalc(price);
   if(usable)
   {
      int k = G_ZM_MEMO_NEXT[side];
      G_ZM_MEMO_TICK[side][k] = G_TICK_COUNT;
      G_ZM_MEMO_PX[side][k] = price;
      G_ZM_MEMO_VAL[side][k] = v;
      G_ZM_MEMO_BAR[side][k] = G_ZMC_CACHE_BAR;
      G_ZM_MEMO_NEXT[side] = (k + 1) % ZM_MEMO_SLOTS;
   }
   return v;
}

double ZoneMapNearestSupport(const double price)    { return ZoneMapMemo(0, price); }
double ZoneMapNearestResistance(const double price) { return ZoneMapMemo(1, price); }

// V29 new (B-block): Zone Strength / Confluence. Given a level already found by the functions
// above, scores how "real" it is - how many swing points across all included TFs cluster near
// it, plus a small bonus for round numbers. Returns >= 1.0 always; 1.0 = no extra confirmation.
// V31.6e new: how many OTHER unfilled gaps (bullish or bearish) overlap or sit near this
// level - a level backed by several stacked gaps has more unmet buy/sell interest than one
// with none, a genuine confluence signal our earlier FVG work didn't score.
int FVGClusterCount(const double level)
{
   if(!EnableFVGZones || !EnableFVGClusterBonus || level <= 0.0)
      return 0;

   int count = 0;
   double tol = MathMax(1, FVGClusterTolerancePoints) * _Point;
   FVGCacheRefresh();   // the same unfilled gaps the nearest-zone lookups use
   for(int i = 0; i < G_FVG_BU_N; i++)
      if(level >= G_FVG_BU_LO[i] - tol && level <= G_FVG_BU_HI[i] + tol)
         count++;
   for(int i = 0; i < G_FVG_BE_N; i++)
      if(level >= G_FVG_BE_LO[i] - tol && level <= G_FVG_BE_HI[i] + tol)
         count++;

   return count;
}

// V31.6e upgrade: was a simple bar-by-bar counter (a slow multi-bar grind at one price level
// used to count as several INDEPENDENT touches, inflating strength). Now: (1) two touches
// closer together than ZoneTouchMinSeparationBars merge into one, and (2) each touch is
// weighted by recency - a fresh touch counts close to full weight, an old one much less.
double ZoneMapCountTouches(const ENUM_TIMEFRAMES tf, const int lookback, const double level, const double tol, const int depth)
{
   ZoneMapRefreshSwingCache();
   int t = ZMTFIndex(tf);
   if(t < 0)
      return 0.0;

   // Merge the cached highs/lows (both individually sorted by ascending shift already) into
   // one ascending-shift touch list, keeping only those within tolerance of this level.
   int touch_shifts[SIRUS_ZM_CACHE_MAX * 2];
   int touch_count = 0;
   int hi = 0, li = 0;

   while((hi < G_ZMC_HIGH_COUNT[t] || li < G_ZMC_LOW_COUNT[t]) && touch_count < SIRUS_ZM_CACHE_MAX * 2)
   {
      bool take_high;
      if(hi >= G_ZMC_HIGH_COUNT[t]) take_high = false;
      else if(li >= G_ZMC_LOW_COUNT[t]) take_high = true;
      else take_high = (G_ZMC_HIGH_SHIFT[t][hi] <= G_ZMC_LOW_SHIFT[t][li]);

      if(take_high)
      {
         if(MathAbs(G_ZMC_HIGH_PRICE[t][hi] - level) <= tol)
            touch_shifts[touch_count++] = G_ZMC_HIGH_SHIFT[t][hi];
         hi++;
      }
      else
      {
         if(MathAbs(G_ZMC_LOW_PRICE[t][li] - level) <= tol)
            touch_shifts[touch_count++] = G_ZMC_LOW_SHIFT[t][li];
         li++;
      }
   }

   double weighted = 0.0;
   int last_touch_shift = -1000000;
   int prev_counted_shift = -1000000;
   int rapid_touches = 0;
   int range = MathMax(1, lookback - depth - 1);

   for(int k = 0; k < touch_count; k++)
   {
      int i = touch_shifts[k];

      if((i - last_touch_shift) < MathMax(1, ZoneTouchMinSeparationBars))
         continue;

      // V31.6j new: Zone Fatigue. A touch that's SEPARATE from the last one (passed the
      // min-separation filter above) but still close in time to it is part of a rapid-fire
      // testing cluster - repeated quick tests tend to WEAKEN a level (defenders tiring), the
      // opposite of what simply counting more touches would suggest.
      if(EnableZoneFatigue && prev_counted_shift > -1000000 &&
         (i - prev_counted_shift) <= MathMax(1, ZoneFatigueWindowBars))
         rapid_touches++;

      prev_counted_shift = i;
      last_touch_shift = i;

      // V265: age discounts a touch, and until now it discounted every touch equally - the oldest
      // one in the window kept thirty percent of its weight regardless of how good it was. So a
      // shelf touched three times nine days ago counted as roughly one touch, which is how the
      // 4305-4315 level came to read as a minor swing.
      //
      // Age is a reasonable proxy for relevance when nothing better is available. Here something
      // better IS available: how many times the level was tested. A price the market came back to
      // three separate times has been confirmed by the market itself, and that confirmation does
      // not expire on the same schedule as a single untested touch.
      //
      // So the floor rises with the touch count. One touch still fades to thirty percent; a level
      // with several holds most of its weight for as long as it stays in the window.
      double age_frac = (double)(i - depth - 1) / (double)range;

      double age_floor = ZoneAgeMinWeight;
      if(EnableZoneAgeByProof && touch_count > 1)
      {
         double proof = MathMin(1.0, (double)(touch_count - 1) /
                                     MathMax(1.0, (double)(ZoneAgeProofFullTouches - 1)));
         age_floor = ZoneAgeMinWeight + proof * (ZoneAgeProofMaxFloor - ZoneAgeMinWeight);
      }

      double weight = 1.0 - age_frac * (1.0 - age_floor);
      weighted += weight;
   }

   if(EnableZoneFatigue && rapid_touches >= MathMax(1, ZoneFatigueMinRapidTouches))
      weighted = MathMax(0.0, weighted - ZoneFatigueStrengthPenalty);

   // V31.6z17 NEW: Long-Term Zone Exhaustion - real gap found via live testing. Zone Fatigue
   // above only catches RAPID repeat testing (within ZoneFatigueWindowBars). It completely
   // missed the DIFFERENT, equally important pattern: a level tested MANY times SLOWLY over a
   // LONG period (weeks+) - a major, heavily-defended structural level. Each successful
   // defense is genuine confirmation, but past a point, repeated long-term testing also means
   // accumulating pressure - the naive "it held before, it'll hold again" assumption gets
   // more dangerous, not safer, the more times a level gets retested over a long stretch.
   // Tempers the LINEAR per-touch bonus with diminishing returns once touch count is high.
   if(EnableZoneLongTermExhaustion && touch_count >= MathMax(1, ZoneLongTermExhaustionMinTouches))
   {
      int excess_touches = touch_count - MathMax(1, ZoneLongTermExhaustionMinTouches) + 1;
      double exhaustion_penalty = MathMin(ZoneLongTermExhaustionMaxPenalty, excess_touches * ZoneLongTermExhaustionPenaltyPerTouch);
      weighted = MathMax(0.0, weighted - exhaustion_penalty);
   }

   return weighted;
}

double ZoneMapConfluenceCount(const double level)
{
   if(level <= 0.0)
      return 0.0;

   int depth = MathMax(1, ZoneMapSwingDepth);
   double tol = MathMax(1, ZoneStrengthTolerancePoints) * _Point;
   double total = 0.0;

   if(EnableZoneMapM5)
      total += ZoneMapCountTouches(PERIOD_M5, ZoneMapLookbackM5, level, tol, depth);
   total += ZoneMapCountTouches(PERIOD_M15, ZoneMapLookbackM15, level, tol, depth);
   if(EnableZoneMapM30)
      total += ZoneMapCountTouches(PERIOD_M30, ZoneMapLookbackM30, level, tol, depth);
   total += ZoneMapCountTouches(PERIOD_H1, ZoneMapLookbackH1, level, tol, depth);
   if(EnableZoneMapH4)
      total += ZoneMapCountTouches(PERIOD_H4, ZoneMapLookbackH4, level, tol, depth);
   if(EnableZoneMapD1)
      total += ZoneMapCountTouches(PERIOD_D1, ZoneMapLookbackD1, level, tol, depth);
   if(EnableZoneMapM1)
      total += ZoneMapCountTouches(PERIOD_M1, ZoneMapLookbackM1, level, tol, depth) * ZoneMapM1TouchWeight;

   // Subtract 1: the level's own defining touch (freshest, weight ~1.0) shouldn't count as
   // "extra" confirmation on top of itself.
   return MathMax(0.0, total - 1.0);
}

// V31.6j new: Per-Zone Historical Reliability. Bayes tracking so far works per DETECTOR TYPE
// (Sweep vs FBR vs NearZone) - this tracks per PRICE LEVEL instead: does THIS specific area
// tend to hold when tested, or tend to break? Bucketed by price so nearby levels share a
// history slot rather than needing an exact match.
int ZoneReliabilityBucketIndex(const double level, const bool create_if_missing)
{
   if(level <= 0.0)
      return -1;

   double tol = MathMax(1.0, ZoneReliabilityBucketPoints) * _Point;

   for(int i = 0; i < G_ZONE_RELIABILITY_COUNT; i++)
   {
      if(MathAbs(G_ZONE_RELIABILITY_KEY[i] - level) <= tol)
         return i;
   }

   if(!create_if_missing || G_ZONE_RELIABILITY_COUNT >= SIRUS_ZONE_RELIABILITY_BUCKETS)
      return -1;

   G_ZONE_RELIABILITY_KEY[G_ZONE_RELIABILITY_COUNT] = level;
   G_ZONE_RELIABILITY_HOLDS[G_ZONE_RELIABILITY_COUNT] = 0.0;
   G_ZONE_RELIABILITY_BREAKS[G_ZONE_RELIABILITY_COUNT] = 0.0;
   G_ZONE_RELIABILITY_COUNT++;
   return G_ZONE_RELIABILITY_COUNT - 1;
}

void ZoneReliabilityRecord(const double level, const bool held)
{
   if(!EnableZoneReliability || level <= 0.0)
      return;

   int idx = ZoneReliabilityBucketIndex(level, true);
   if(idx < 0)
      return;

   if(held) G_ZONE_RELIABILITY_HOLDS[idx]  += 1.0;
   else     G_ZONE_RELIABILITY_BREAKS[idx] += 1.0;

   double total = G_ZONE_RELIABILITY_HOLDS[idx] + G_ZONE_RELIABILITY_BREAKS[idx];
   if(total > ZoneReliabilityMaxWindow)
   {
      double scale = (double)ZoneReliabilityMaxWindow / total;
      G_ZONE_RELIABILITY_HOLDS[idx]  *= scale;
      G_ZONE_RELIABILITY_BREAKS[idx] *= scale;
   }
}

// Returns a -1..+1 style score: positive = this level historically HOLDS, negative = BREAKS,
// 0 = not enough data yet.
double ZoneReliabilityScore(const double level)
{
   if(!EnableZoneReliability || level <= 0.0)
      return 0.0;

   int idx = ZoneReliabilityBucketIndex(level, false);
   if(idx < 0)
      return 0.0;

   double total = G_ZONE_RELIABILITY_HOLDS[idx] + G_ZONE_RELIABILITY_BREAKS[idx];
   if(total < MathMax(1, ZoneReliabilityMinSamples))
      return 0.0;

   // V31.6z58 fix: the same non-Bayesian hard-gate weakness corrected in BayesWinRate, found
   // here too via a systematic sweep. ZoneReliabilityMinSamples defaults to just 3, and once
   // that gate is passed the raw hold-rate was trusted at 100% face value - so a level that
   // happened to hold 3 times out of 3 scored MAXIMUM reliability (1.0), exactly the same as
   // one proven across 50 touches. Three holds in a row is a coin-flip away from luck. Applies
   // shrinkage toward the neutral 0.5 prior in proportion to how little evidence exists.
   double hold_rate;
   if(EnableBayesShrinkage)
   {
      double k = MathMax(1.0, BayesShrinkageStrength);
      hold_rate = (G_ZONE_RELIABILITY_HOLDS[idx] + 0.5 * k) / (total + k);
   }
   else
   {
      hold_rate = G_ZONE_RELIABILITY_HOLDS[idx] / total;
   }

   return MathMax(-1.0, MathMin(1.0, (hold_rate - 0.5) * 2.0));
}

// ===================================================================================
// FEATURE(daily-bias): compute previous-day levels + bias. Called once per new D1 bar from the
// core update loop (cheap, cached). All reads are validated; if D1 history isn't ready yet, the
// state is left neutral/zero and every consumer treats it as "no daily info" - never garbage.
// ===================================================================================
void UpdateDailyBias()
{
   if(!EnableDailyBias)
   {
      G_DAILY_BIAS = 0;
      G_DAILY_BIAS_TXT = "daily bias: disabled";
      return;
   }

   datetime cur_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(cur_d1 <= 0)
      return;   // D1 not ready - keep whatever we had, don't corrupt state

   // Only recompute when a new D1 bar has actually formed (staleness guard).
   if(cur_d1 == G_DAILY_BIAS_BAR && G_PDH > 0.0)
      return;

   double pdh = iHigh(_Symbol,  PERIOD_D1, 1);
   double pdl = iLow(_Symbol,   PERIOD_D1, 1);
   double pdc = iClose(_Symbol, PERIOD_D1, 1);
   double pdo = iOpen(_Symbol,  PERIOD_D1, 1);
   double to  = iOpen(_Symbol,  PERIOD_D1, 0);

   // Validate EVERYTHING before committing. A single bad read (0 / negative) aborts the update
   // and leaves the previous good state intact rather than poisoning the zone system.
   if(pdh <= 0.0 || pdl <= 0.0 || pdc <= 0.0 || pdo <= 0.0 || to <= 0.0 || pdh <= pdl)
   {
      G_DAILY_BIAS_TXT = "daily bias: D1 data not ready";
      return;
   }

   G_PDH = pdh;
   G_PDL = pdl;
   G_PDC = pdc;
   G_PDO = pdo;
   G_TODAY_OPEN = to;
   G_DAILY_BIAS_BAR = cur_d1;

   // Component 1: prior-day close direction (was yesterday a bullish or bearish day?).
   int close_bias = 0;
   if(pdc > pdo)      close_bias = 1;
   else if(pdc < pdo) close_bias = -1;

   // Component 2: today's open vs prior close (gap). Within a neutral band => no tilt.
   int open_bias = 0;
   double gap_pts = (to - pdc) / _Point;
   double neutral = MathMax(0.0, DailyBiasNeutralOpenPoints);
   if(gap_pts > neutral)       open_bias = 1;
   else if(gap_pts < -neutral) open_bias = -1;

   // Combine conservatively: if the two agree, that's the bias. If they conflict, the fresher
   // signal (today's open) wins but is treated as WEAKER (still just +/-1, never amplified). If
   // today's open is neutral, fall back to the prior-day close direction.
   if(close_bias == open_bias)
      G_DAILY_BIAS = close_bias;
   else if(open_bias != 0)
      G_DAILY_BIAS = open_bias;
   else
      G_DAILY_BIAS = close_bias;

   string dir_txt = (G_DAILY_BIAS > 0 ? "BULLISH" : (G_DAILY_BIAS < 0 ? "BEARISH" : "NEUTRAL"));
   G_DAILY_BIAS_TXT = StringFormat("daily bias: %s | PDH=%.2f PDL=%.2f PDC=%.2f todayOpen=%.2f gap=%.0fpts",
                                   dir_txt, pdh, pdl, pdc, to, gap_pts);

   if((DailyBiasPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS DAILY BIAS] %s", G_DAILY_BIAS_TXT);
}

// FEATURE(daily-bias): is 'level' sitting on a previous-day level (PDH/PDL/prior close)?
// Used to grant those levels extra zone strength. Returns true only when daily data is valid.
bool IsOnDailyLevel(const double level)
{
   if(!EnableDailyBias || !EnableDailyLevelsAsZones || level <= 0.0 || G_PDH <= 0.0)
      return false;

   double tol = MathMax(1.0, DailyLevelTolerancePoints) * _Point;
   if(MathAbs(level - G_PDH) <= tol) return true;
   if(MathAbs(level - G_PDL) <= tol) return true;
   if(G_PDC > 0.0 && MathAbs(level - G_PDC) <= tol) return true;
   return false;
}

bool ZoneMapIsRoundNumber(const double level)
{
   if(!EnableZoneRoundNumberBonus || ZoneRoundNumberStep <= 0.0 || level <= 0.0)
      return false;

   double remainder = MathMod(level, ZoneRoundNumberStep);
   double tol = ZoneRoundNumberTolerancePoints * _Point;

   return (remainder <= tol || (ZoneRoundNumberStep - remainder) <= tol);
}

// V31.6j new: Zone Polarity Flip. A broken resistance often becomes new support (and vice
// versa) - a classic, proven concept we never used. Checks: has price held consistently on
// the CURRENT side of this level for a while, AND further back, was it genuinely on the
// OPPOSITE side (proving a real flip happened, not just "always been this side")?
bool ZoneMapIsPolarityFlip(const double level, const bool checking_as_support)
{
   if(!EnableZonePolarityFlip || level <= 0.0)
      return false;

   // V31.6z51 fix: real gap found via audit - this was hardcoded to PERIOD_M15 with a 60-bar
   // lookback, i.e. it could only ever see 15 HOURS of history. A major H4/D1 level that broke
   // and flipped two days ago was completely invisible to it, so the entire polarity-flip
   // concept only ever worked for very recent, small-timeframe flips - exactly the least
   // significant ones. Now configurable, defaulting to a reach that covers several days.
   ENUM_TIMEFRAMES flip_tf = PolarityFlipTF;

   int hold_bars = 0;
   int i = 1;

   for(; i <= PolarityFlipLookbackBars; i++)
   {
      double c = CandleClose(flip_tf, i);
      if(c <= 0.0)
         return false;

      bool on_current_side = checking_as_support ? (c >= level) : (c <= level);
      if(!on_current_side)
         break;
      hold_bars++;
   }

   if(hold_bars < MathMax(1, PolarityFlipMinHoldBars))
      return false;

   for(; i <= PolarityFlipLookbackBars; i++)
   {
      double c = CandleClose(flip_tf, i);
      if(c <= 0.0)
         continue;

      bool on_opposite_side = checking_as_support ? (c < level) : (c > level);
      if(on_opposite_side)
         return true;
   }

   return false;
}

double ZoneMapStrength(const double level)
{
   if(!EnableZoneStrength || level <= 0.0)
      return 1.0;

   double touches = ZoneMapConfluenceCount(level);
   double strength = 1.0 + touches * ZoneStrengthPerTouch;

   // V132: how hard price was thrown back matters as much as how often it was tested.
   // A single violent rejection is a real wall; four listless touches often are not.
   //
   // NOTE: this bonus reflects how DANGEROUS the level is to trade into, which is the right input
   // for blocks and cautions. It must NOT be used where strength is a proxy for the level's CLASS
   // (D1 vs H1 vs M15) - see ZoneMapStrengthByTouches() below, used by the ghost-zone lifetime.
   strength += ZoneReactionQuality(level);

   // V141: and then subtract what the level has spent. Orders resting at a level are finite; each
   // test consumes some. Without this the touch count works backwards - the most-eaten levels score
   // highest, which is precisely why a fourth touch so often breaks. Decay never removes the level
   // entirely (floor at ZoneDecayMinRetain) because even a worn level still holds something.
   double zd = ZoneDecayFactor(level);
   if(zd > 0.0)
   {
      double retain = MathMax(MathMax(0.05, ZoneDecayMinRetain), 1.0 - zd * MathMax(0.0, ZoneDecayWeight));
      // V200: decay is meant to fade a level the market has stopped respecting - but it was reading
   // "tested often" as "worn out", when repeated testing is what identifies a level that matters.
   // A support touched five times and held five times was being scored WEAKER than one touched
   // once. Decay now applies only where the reactions themselves have been getting weaker, and its
   // floor is raised so a genuine level cannot be discounted into invisibility.
   if(retain < ZoneDecayApplyBelow)
      strength *= MathMax(ZoneDecayMinRetain, retain);
   }

   if(ZoneMapIsRoundNumber(level))
      strength += ZoneRoundNumberBonusWeight;

   // V31.6e new: overlapping/nearby unfilled FVGs add to a level's strength.
   if(EnableFVGClusterBonus)
   {
      int cluster = FVGClusterCount(level);
      if(cluster > 0)
         strength += cluster * FVGClusterStrengthWeight;
   }

   // V31.6j new: polarity flip - direction inferred from current price vs the level.
   if(EnableZonePolarityFlip)
   {
      double bid = 0.0, ask = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
      double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

      if(mid > 0.0)
      {
         bool checking_as_support = (level < mid);
         if(ZoneMapIsPolarityFlip(level, checking_as_support))
         {
            double flip_bonus = PolarityFlipStrengthBonus;

            // V31.6z51 NEW: trend-aware flip weighting - direct user request. A flip is a
            // STRUCTURAL event with an inherent direction: resistance breaking upward and
            // becoming support is a bullish event; support breaking downward and becoming
            // resistance is bearish. A flip that agrees with the bigger picture (H4/D1) is the
            // classic, reliable continuation structure. A flip AGAINST the global trend is far
            // more likely to fail - the prevailing current will simply push back through it.
            // The old code weighted both identically.
            if(EnablePolarityFlipTrendWeighting)
            {
               int flip_dir = checking_as_support ? 1 : -1;   // support-flip = bullish structure
               string gt_detail = "";
               double global_conf = GlobalTrendConfidence(flip_dir, gt_detail);

               if(global_conf >= PolarityFlipTrendAlignedLevel)
                  flip_bonus *= PolarityFlipTrendAlignedMultiplier;
               else if(global_conf <= -PolarityFlipTrendAlignedLevel)
                  flip_bonus *= PolarityFlipTrendAgainstMultiplier;
            }

            strength += flip_bonus;
         }
      }
   }

   // V31.6j new: per-zone historical reliability - this specific price area's own track record.
   if(EnableZoneReliability)
   {
      double reliability = ZoneReliabilityScore(level);
      strength += reliability * 0.5;   // scaled modestly - a supplementary signal, not dominant
   }

   // FEATURE(daily-bias): a level sitting on PDH/PDL (or prior-day close) is a heavily-watched,
   // heavily-defended institutional level. Give it a strength bonus so the whole bot - sweep
   // detection, bounce entries, hard-blocks, grid distance - treats yesterday's extremes as the
   // major levels they are. This is the "sees yesterday's strong support/resistance" upgrade.
   if(IsOnDailyLevel(level))
      strength += MathMax(0.0, DailyLevelStrengthBonus);

   return strength;
}

// --- V29 new: Zone-aware grid distance. Only ever SHORTENS the distance toward a real H1/M15
// support/resistance level that sits closer than the geometric/ATR distance - never lengthens it,
// so it can only make the grid more opportunistic, never slower. Falls back to base_distance if no
// zone is found closer than that.
double GridZoneAwareDistance(const long direction, const double last_price, const double base_distance, const double min_distance)
{
   if(!EnableZoneMapGridAwareness || last_price <= 0.0)
      return base_distance;

   double floor_distance = MathMax(min_distance, 1.0);

   if(direction == POSITION_TYPE_BUY)
   {
      double target_price = last_price - base_distance * _Point;
      double sup = ZoneMapNearestSupport(last_price);

      // V137: the case this function never covered - a strong support sitting a little BEYOND the
      // stepped trigger. The old logic only pulled the add IN toward a nearer zone; when the zone
      // was further out, the order fired at the computed price and landed in empty space, just
      // short of the level that would actually have bounced it. Reaching slightly further to place
      // the add AT that support is what makes the addition work for the basket rather than merely
      // exist. Bounded by GridZoneSnapMaxFactor so recovery is never pushed far away.
      if(EnableGridZoneReach && sup > 0.0 && sup <= target_price)
      {
         double reach_distance = (last_price - sup) / _Point + ZoneMapGridBufferPoints;

         // V137b: how far the add may reach scales with how good the level is. A merely acceptable
         // level earns the base allowance; a genuinely strong one - many touches, or one violent
         // rejection - is worth waiting noticeably longer for, because the bounce from it is what
         // carries the basket back. Weak levels get no extra rope at all.
         double sup_strength = ZoneMapStrength(sup);
         double reach_factor = MathMax(1.0, GridZoneSnapMaxFactor);
         if(sup_strength >= GridZoneStrongLevel)
            reach_factor = MathMax(reach_factor, GridZoneStrongSnapFactor);
         double reach_limit = base_distance * reach_factor;

         if(reach_distance > base_distance &&
            reach_distance <= reach_limit &&
            sup_strength >= ZoneGridMinStrength)
         {
            if((GridZoneReachPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v137 GRID REACH] BUY basket: %.0f -> %.0f pts to place the add at support %.2f (strength %.1f)",
                           base_distance, reach_distance, sup, ZoneMapStrength(sup));
            return reach_distance;
         }
      }

      if(sup > 0.0 && sup > target_price)
      {
         double zone_distance = (last_price - sup) / _Point + ZoneMapGridBufferPoints;

         // V31.6 fix: shrinking below base needs a REAL reason.
         // First: the zone must be strong - multi-touch/confluence, not a random single wick.
         // Second: the order must actually land AT the zone. If the zone is closer than the
         //    minimum distance, flooring would place the order far PAST the zone at an
         //    arbitrary point - no justification, so keep the full base distance instead.
         if(zone_distance >= floor_distance &&
            zone_distance < base_distance &&
            ZoneMapStrength(sup) >= ZoneGridMinStrength)
            return zone_distance;
      }
   }
   else if(direction == POSITION_TYPE_SELL)
   {
      double target_price = last_price + base_distance * _Point;
      double res = ZoneMapNearestResistance(last_price);

      // V137: mirror of the BUY case - a strong resistance just beyond the stepped trigger. Reach
      // out to it rather than firing short of it into empty space.
      if(EnableGridZoneReach && res > 0.0 && res >= target_price)
      {
         double reach_distance = (res - last_price) / _Point + ZoneMapGridBufferPoints;

         // V137b: mirror of the BUY case - a stronger level earns a longer reach.
         double res_strength = ZoneMapStrength(res);
         double reach_factor = MathMax(1.0, GridZoneSnapMaxFactor);
         if(res_strength >= GridZoneStrongLevel)
            reach_factor = MathMax(reach_factor, GridZoneStrongSnapFactor);
         double reach_limit = base_distance * reach_factor;

         if(reach_distance > base_distance &&
            reach_distance <= reach_limit &&
            res_strength >= ZoneGridMinStrength)
         {
            if((GridZoneReachPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v137 GRID REACH] SELL basket: %.0f -> %.0f pts to place the add at resistance %.2f (strength %.1f)",
                           base_distance, reach_distance, res, ZoneMapStrength(res));
            return reach_distance;
         }
      }

      if(res > 0.0 && res < target_price)
      {
         double zone_distance = (res - last_price) / _Point + ZoneMapGridBufferPoints;

         if(zone_distance >= floor_distance &&
            zone_distance < base_distance &&
            ZoneMapStrength(res) >= ZoneGridMinStrength)
            return zone_distance;
      }
   }

   return base_distance;
}

// ============================================================================
// V31.6 new: SMART ZONE RECOVERY - the intelligent exception to the trend-block.
// Problem it solves: the trend-against guard rightly stops the grid from adding into
// a strong counter-move, but that leaves the basket sitting in DD until the trend
// fully turns. This module allows exactly ONE reduced-lot recovery add per block
// episode, and ONLY at the highest-probability reversal point:
//   1. price is AT a strong multi-TF confirmed wall (ZoneMapStrength >= threshold),
//   2. the wall has not failed (price not far beyond it),
//   3. the last closed M15 candle POKED the wall and closed back on our side
//      (a real rejection, not a touch mid-flight),
//   4. tick-volume conviction is not strongly pushing THROUGH the wall,
//   5. the mandatory grid distance from the last order still applies downstream.
// This improves the basket average at the wall, so even a small pullback releases
// the basket - without ever taking a loss and without spraying adds into the move.
// ============================================================================
// V31.6e helper: evaluates ONE already-in-range wall for strength/rejection/volume quality.
// Extracted so the cascade logic below can reuse it for both the nearest wall and, if that
// one failed, the next wall further out.
bool SZRCheckWallQuality(const long direction, const double wall, const double proximity, string &why)
{
   double strength = ZoneMapStrength(wall);
   if(strength < SZRMinZoneStrength)
   {
      why = StringFormat("szr: wall too weak %.2f/%.2f", strength, SZRMinZoneStrength);
      return false;
   }

   if(direction == POSITION_TYPE_SELL)
   {
      if(SZRRequireRejectionCandle)
      {
         double h1 = CandleHigh(PERIOD_M15, 1);
         double c1 = CandleClose(PERIOD_M15, 1);
         if(h1 <= 0.0 || c1 <= 0.0 || h1 < wall - proximity || c1 >= wall)
         {
            why = "szr: waiting M15 rejection close at wall";
            return false;
         }
      }

      if(SZRUseOrderFlowVeto && OrderFlowConvictionSign(PERIOD_M15, 1) > 0 && CandleClose(PERIOD_M15, 1) > wall)
      {
         why = "szr: strong volume pushing through wall";
         return false;
      }

      why = StringFormat("szr: GO at resistance %.2f (strength %.2f)", wall, strength);
      return true;
   }

   // BUY / support
   if(SZRRequireRejectionCandle)
   {
      double l1 = CandleLow(PERIOD_M15, 1);
      double c1 = CandleClose(PERIOD_M15, 1);
      if(l1 <= 0.0 || c1 <= 0.0 || l1 > wall + proximity || c1 <= wall)
      {
         why = "szr: waiting M15 rejection close at wall";
         return false;
      }
   }

   // REVERT(orderflow-sign): briefly flipped to `< 0` on the mistaken belief that this was a
   // copy-paste sign error. It was not. The BREAK DIRECTION is already carried by the close test
   // (`< wall` = support breakdown here, `> wall` = resistance breakout in the SELL branch above);
   // OrderFlowConvictionSign carries only the MAGNITUDE (+1 = heavy volume). `> 0` in both branches
   // is deliberate and correctly mirrored - the veto fires when the wall is being broken ON STRONG
   // VOLUME, which is exactly what the why-string and the input's own description say.
   if(SZRUseOrderFlowVeto && OrderFlowConvictionSign(PERIOD_M15, 1) > 0 && CandleClose(PERIOD_M15, 1) < wall)
   {
      why = "szr: strong volume pushing through wall";
      return false;
   }

   why = StringFormat("szr: GO at support %.2f (strength %.2f)", wall, strength);
   return true;
}

bool SmartZoneRecoveryAllows(const long direction, const double last_price, string &why)
{
   why = "szr: off";
   if(!EnableSmartZoneRecovery)
      return false;

   if(SZRMaxUsesPerEpisode > 0 && G_SZR_USES_THIS_EPISODE >= SZRMaxUsesPerEpisode)
   {
      why = StringFormat("szr: episode cap reached %d/%d", G_SZR_USES_THIS_EPISODE, SZRMaxUsesPerEpisode);
      return false;
   }

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(bid <= 0.0 || ask <= 0.0 || _Point <= 0.0)
   {
      why = "szr: price not ready";
      return false;
   }

   double proximity = MathMax(1, SZRZoneProximityPoints) * _Point;
   double max_beyond = MathMax(0, SZRMaxBeyondZonePoints) * _Point;
   int max_attempts = EnableZoneCascade ? 2 : 1;

   if(direction == POSITION_TYPE_SELL)
   {
      double search_from = bid;

      for(int attempt = 1; attempt <= max_attempts; attempt++)
      {
         double wall = ZoneMapNearestResistance(search_from);
         if(wall <= 0.0)
         {
            wall = ZoneMapNearestResistance(bid - max_beyond - proximity);
            if(wall <= 0.0) { why = "szr: no wall found"; return false; }
         }

         if(bid < wall - proximity)
         {
            why = "szr: wall not reached yet";
            return false;
         }

         if(bid > wall + max_beyond)
         {
            // V31.6e zone cascade: this wall already broke - if the near zone fails, the
            // farther zone should catch it, instead of giving up entirely.
            if(attempt < max_attempts)
            {
               if((SZRPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v31.6e SZR CASCADE] wall %.2f failed - checking next wall out", wall);
               search_from = wall + proximity;
               continue;
            }
            why = "szr: wall failed (price beyond)";
            return false;
         }

         return SZRCheckWallQuality(direction, wall, proximity, why);
      }

      why = "szr: no valid wall after cascade";
      return false;
   }
   else if(direction == POSITION_TYPE_BUY)
   {
      double search_from = bid;

      for(int attempt = 1; attempt <= max_attempts; attempt++)
      {
         double wall = ZoneMapNearestSupport(search_from);
         if(wall <= 0.0)
         {
            wall = ZoneMapNearestSupport(bid + max_beyond + proximity);
            if(wall <= 0.0) { why = "szr: no wall found"; return false; }
         }

         if(bid > wall + proximity)
         {
            why = "szr: wall not reached yet";
            return false;
         }

         if(bid < wall - max_beyond)
         {
            if(attempt < max_attempts)
            {
               if((SZRPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v31.6e SZR CASCADE] wall %.2f failed - checking next wall out", wall);
               search_from = wall - proximity;
               continue;
            }
            why = "szr: wall failed (price beyond)";
            return false;
         }

         return SZRCheckWallQuality(direction, wall, proximity, why);
      }

      why = "szr: no valid wall after cascade";
      return false;
   }

   why = "szr: no basket direction";
   return false;
}

// --- V29 ported: HTF Structure Commander bias (moved earlier to avoid forward-reference) ---
int HTFStructureBias()
{
   // V31.6d: unified trend source. This used to compute its OWN separate opinion (simple
   // close-vs-N-bars-back), independent from the Kalman filter that drives MARKET_STATE and
   // from Deep HTF Commander's own dual-SMA cross - three different techniques answering the
   // same "is H1 trending up or down" question, sometimes disagreeing with each other. Now
   // all three read from the SAME Kalman signal when it's ready, and each only falls back to
   // its own original (different) method during the brief warmup window.
   if(KalmanTrendReady())
   {
      double slope_points = G_KALMAN_TREND / _Point;
      if(slope_points > KalmanTrendMinPoints)  return 1;
      if(slope_points < -KalmanTrendMinPoints) return -1;
      return 0;
   }

   double close_now  = CandleClose(PERIOD_H1, 1);
   double close_then = CandleClose(PERIOD_H1, HTFStructureLookbackBars);
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0;
   if(close_now > close_then)
      return 1;
   if(close_now < close_then)
      return -1;
   return 0;
}

// V29 strengthened: was warning-only before, now also trims lot (never blocks) when the entry
// is counter to the H1 structure bias.
double HTFStructureLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableHTFStructureWarn)
      return lot;

   int bias = HTFStructureBias();
   bool counter = (order_type == ORDER_TYPE_BUY && bias < 0) || (order_type == ORDER_TYPE_SELL && bias > 0);

   if(counter)
   {
      if((HTFStructurePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v29 HTF STRUCTURE] entry %s counter to H1 bias=%d - lot trimmed x%.2f",
                     (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), bias, HTFStructureCounterLotFactor);
      return lot * HTFStructureCounterLotFactor;
   }

   return lot;
}

// --- V29 new: First Entry Trend-Against Guard. Trims lot (never blocks) when the very first
// order would open straight against a strong HTF/BOS/market-state trend. Deliberately soft:
// the reversal detectors (sweep/range-edge) are DESIGNED to buy support / sell resistance even
// inside an opposing trend, so a hard block here would fight the strategy itself.
double FirstEntryTrendGuardLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableFirstEntryTrendGuard)
      return lot;

   bool against = false;
   if(order_type == ORDER_TYPE_BUY)
      against = (G_MARKET_STATE == MARKET_TREND_DOWN || G_DLP_HTF_DIR < 0 || G_DBOS_DIR < 0);
   else if(order_type == ORDER_TYPE_SELL)
      against = (G_MARKET_STATE == MARKET_TREND_UP || G_DLP_HTF_DIR > 0 || G_DBOS_DIR > 0);

   if(against)
   {
      if((FirstEntryTrendGuardPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v29 FIRST ENTRY TREND GUARD] %s against HTF/BOS/trend - lot trimmed x%.2f",
                     (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), FirstEntryTrendAgainstLotFactor);
      return lot * FirstEntryTrendAgainstLotFactor;
   }

   return lot;
}

// --- Real Retry Engine: replaces v28's "placeholder, no Sleep()" stub with an actual backoff. ---
bool IsTransientTradeRetcode(const int code)
{
   return (code == TRADE_RETCODE_REQUOTE ||
           code == TRADE_RETCODE_REJECT ||
           code == TRADE_RETCODE_PRICE_CHANGED ||
           code == TRADE_RETCODE_TIMEOUT ||
           code == TRADE_RETCODE_CONNECTION ||
           code == TRADE_RETCODE_PRICE_OFF);
}

bool RetryEngineAllowsFirstEntry(string &reason)
{
   if(!EnableRealRetryEngine || G_FIRST_LAST_FAIL_TIME <= 0)
   {
      reason = "retry engine idle";
      return true;
   }

   int elapsed = (int)(TimeCurrent() - G_FIRST_LAST_FAIL_TIME);

   if(!G_FIRST_LAST_FAIL_TRANSIENT)
   {
      if(elapsed < RetryNonTransientCooldownSeconds)
      {
         reason = StringFormat("retry wait (non-transient) %d/%ds", elapsed, RetryNonTransientCooldownSeconds);
         return false;
      }
      reason = "retry cooldown cleared";
      return true;
   }

   if(G_FIRST_TRANSIENT_RETRY_COUNT >= RetryMaxAttempts)
   {
      if(elapsed < RetryGiveUpCooldownSeconds)
      {
         reason = StringFormat("retry attempts exhausted, cooling down %d/%ds", elapsed, RetryGiveUpCooldownSeconds);
         return false;
      }
      G_FIRST_TRANSIENT_RETRY_COUNT = 0;
      reason = "retry cooldown cleared";
      return true;
   }

   if(elapsed < RetryDelaySeconds)
   {
      reason = StringFormat("retry wait %d/%ds attempt=%d/%d", elapsed, RetryDelaySeconds, G_FIRST_TRANSIENT_RETRY_COUNT, RetryMaxAttempts);
      return false;
   }

   reason = "retry delay cleared";
   return true;
}

bool RetryEngineAllowsGrid(string &reason)
{
   if(!EnableRealRetryEngine || G_GRID_LAST_FAIL_TIME <= 0)
   {
      reason = "retry engine idle";
      return true;
   }

   int elapsed = (int)(TimeCurrent() - G_GRID_LAST_FAIL_TIME);

   if(!G_GRID_LAST_FAIL_TRANSIENT)
   {
      if(elapsed < RetryNonTransientCooldownSeconds)
      {
         reason = StringFormat("grid retry wait (non-transient) %d/%ds", elapsed, RetryNonTransientCooldownSeconds);
         return false;
      }
      reason = "grid retry cooldown cleared";
      return true;
   }

   if(G_GRID_TRANSIENT_RETRY_COUNT >= RetryMaxAttempts)
   {
      if(elapsed < RetryGiveUpCooldownSeconds)
      {
         reason = StringFormat("grid retry attempts exhausted, cooling down %d/%ds", elapsed, RetryGiveUpCooldownSeconds);
         return false;
      }
      G_GRID_TRANSIENT_RETRY_COUNT = 0;
      reason = "grid retry cooldown cleared";
      return true;
   }

   if(elapsed < RetryDelaySeconds)
   {
      reason = StringFormat("grid retry wait %d/%ds attempt=%d/%d", elapsed, RetryDelaySeconds, G_GRID_TRANSIENT_RETRY_COUNT, RetryMaxAttempts);
      return false;
   }

   reason = "grid retry delay cleared";
   return true;
}

// --- Correlation Guard: trims lot when other open positions (any symbol) compound this trade's risk. ---
double SymbolCorrelation(const string sym_a, const string sym_b, const ENUM_TIMEFRAMES tf, const int bars)
{
   double close_a[], close_b[];
   if(CopyClose(sym_a, tf, 1, bars, close_a) != bars)
      return 0.0;
   if(CopyClose(sym_b, tf, 1, bars, close_b) != bars)
      return 0.0;

   double sum_a = 0.0, sum_b = 0.0;
   for(int i = 0; i < bars; i++)
   {
      sum_a += close_a[i];
      sum_b += close_b[i];
   }
   double mean_a = sum_a / bars;
   double mean_b = sum_b / bars;

   double cov = 0.0, var_a = 0.0, var_b = 0.0;
   for(int i = 0; i < bars; i++)
   {
      double da = close_a[i] - mean_a;
      double db = close_b[i] - mean_b;
      cov   += da * db;
      var_a += da * da;
      var_b += db * db;
   }

   if(var_a <= 0.0 || var_b <= 0.0)
      return 0.0;

   return cov / MathSqrt(var_a * var_b);
}

double CorrelationGuardLotAdjust(const double lot, const ENUM_ORDER_TYPE order_type)
{
   if(!EnableCorrelationGuard)
      return lot;

   double worst_factor = 1.0;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym == _Symbol)
         continue;

      double corr = SymbolCorrelation(_Symbol, psym, CorrelationTF, CorrelationLookbackBars);
      if(MathAbs(corr) < CorrelationHighThreshold)
         continue;

      long ptype = PositionGetInteger(POSITION_TYPE);
      bool other_is_buy = (ptype == POSITION_TYPE_BUY);
      bool this_is_buy  = (order_type == ORDER_TYPE_BUY);

      bool compounding = (corr > 0.0 && other_is_buy == this_is_buy) ||
                          (corr < 0.0 && other_is_buy != this_is_buy);

      if(compounding)
      {
         double factor = CorrelationLotFactor;

         // V29 new: if the correlation reading itself is unstable (short-term vs long-term
         // disagree a lot), trust it less and cut the lot further.
         if(EnableCorrelationInstability)
         {
            double corr_short = SymbolCorrelation(_Symbol, psym, CorrelationTF, CorrelationShortWindowBars);
            double corr_long  = SymbolCorrelation(_Symbol, psym, CorrelationTF, CorrelationLongWindowBars);
            double instability = MathAbs(corr_short - corr_long);

            if(instability >= CorrelationInstabilityThreshold)
            {
               factor *= CorrelationInstabilityLotFactor;
               if((CorrelationInstabilityPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v29 CORRELATION] %s vs %s unstable (short=%.2f long=%.2f diff=%.2f) - extra cut x%.2f",
                              _Symbol, psym, corr_short, corr_long, instability, CorrelationInstabilityLotFactor);
            }
         }

         if(factor < worst_factor)
            worst_factor = factor;
         if((CorrelationPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v29 CORRELATION] %s vs %s corr=%.2f compounding exposure - lot trimmed x%.2f",
                        _Symbol, psym, corr, factor);
      }
   }

   return lot * worst_factor;
}

// --- Real Economic Calendar: uses MT5's native Calendar API. Caution (lot cut) by default, hard-block optional. ---
//
// FIX(calendar-window): three faults made the news window open late, close late, or never extend:
//   1) The fetch only looked EconomicCalendarPostMinutes back, so a release that was a big surprise
//      dropped out of the query before its extended caution window (Post + NewsSurpriseExtraCautionMinutes)
//      could ever be applied - the surprise extension never worked past the normal post window.
//   2) The window was decided only at fetch time and then frozen for EconomicCalendarRefreshSeconds (300s),
//      so it could start up to 5 minutes late, end up to 5 minutes late, and G_CAL_MINUTES_FROM_EVENT
//      (which the news auto-flat reads) was up to 5 minutes stale.
//   3) The first event found won, so an earlier release still in its post window hid the next one
//      approaching its pre window - and auto-flat never saw the upcoming event.
// The fetch now caches the important events of a wide enough span, and the window is evaluated against the
// live server clock on every call (a cheap loop over the cache). The fetch itself refreshes faster while a
// released event still has no actual value, so a surprise is recognised within a minute, not five.
void CalendarClearState()
{
   G_CAL_ACTIVE = false;
   G_CAL_BIG_SURPRISE = false;
   G_CAL_SURPRISE_PERCENT = 0.0;
   G_CAL_EVENT_NAME = "";
   G_CAL_EVENT_ID = 0;
   G_CAL_MINUTES_FROM_EVENT = 0;
}

int CalendarPostWindowSeconds(const int idx)
{
   int post_min = MathMax(0, EconomicCalendarPostMinutes);
   if(EnableNewsSurprise && idx >= 0 && idx < G_CAL_EV_COUNT && G_CAL_EV_SURPRISE[idx])
      post_min += MathMax(0, NewsSurpriseExtraCautionMinutes);
   return post_min * 60;
}

void CalendarFetch(const datetime now)
{
   G_CAL_LAST_SCAN = now;

   int back_min = MathMax(0, EconomicCalendarPostMinutes) + (EnableNewsSurprise ? MathMax(0, NewsSurpriseExtraCautionMinutes) : 0);
   int ahead_min = MathMax(MathMax(0, EconomicCalendarPreMinutes), (EnableNewsAutoFlat ? MathMax(0, NewsAutoFlatMinutesBefore) : 0));
   datetime from_time = now - (back_min + 1) * 60;
   datetime to_time   = now + ahead_min * 60 + 3600;

   MqlCalendarValue values[];
   ResetLastError();
   int total = CalendarValueHistory(values, from_time, to_time, "", EconomicCalendarCurrency);
   if(total < 0)
   {
      int err = GetLastError();
      // Keep the previous cache: a failed refresh must not silently open a window that was closed by
      // dropping an event we already knew about.
      if(!G_CAL_FETCH_FAILED || (EconomicCalendarPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS CALENDAR] fetch failed (error %d) - keeping %d cached event(s); news guard may be blind until the calendar loads",
                     err, G_CAL_EV_COUNT);
      G_CAL_FETCH_FAILED = true;
      return;
   }
   if(G_CAL_FETCH_FAILED)
      Print("[SIRUS CALENDAR] fetch recovered");
   G_CAL_FETCH_FAILED = false;

   G_CAL_EV_COUNT = 0;
   G_CAL_PENDING_ACTUAL = false;
   for(int i = 0; i < total && G_CAL_EV_COUNT < CAL_CACHE_MAX; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;

      int importance = (int)ev.importance;
      bool important_enough = (EconomicCalendarMinImportance <= 1) ?
                               (importance >= CALENDAR_IMPORTANCE_MODERATE) :
                               (importance >= CALENDAR_IMPORTANCE_HIGH);
      if(!important_enough)
         continue;

      int k = G_CAL_EV_COUNT;
      G_CAL_EV_TIME[k] = values[i].time;
      G_CAL_EV_NAME[k] = ev.name;
      G_CAL_EV_ID[k]   = values[i].id;
      G_CAL_EV_SURPRISE[k] = false;
      G_CAL_EV_SURPRISE_PCT[k] = 0.0;

      // V31.6j News Surprise Magnitude: a release far from its forecast (e.g. a big NFP beat/miss) tends
      // to set the tone for hours afterward - its caution window is extended.
      bool has_actual = (values[i].actual_value != LONG_MIN);
      if(values[i].time <= now && !has_actual)
         G_CAL_PENDING_ACTUAL = true;   // released but the figure is not in yet - refresh sooner
      if(EnableNewsSurprise && values[i].time <= now && has_actual &&
         values[i].forecast_value != LONG_MIN && values[i].forecast_value != 0)
      {
         double surprise_pct = MathAbs((double)(values[i].actual_value - values[i].forecast_value)) /
                               MathAbs((double)values[i].forecast_value) * 100.0;
         G_CAL_EV_SURPRISE_PCT[k] = surprise_pct;
         if(surprise_pct >= NewsSurpriseMinPercent)
         {
            G_CAL_EV_SURPRISE[k] = true;
            if((NewsSurprisePrintOnUse && VerboseLogs) && G_CAL_LAST_SURPRISE_ID != values[i].id)
               PrintFormat("[SIRUS v31.6j NEWS SURPRISE] %s: %.0f%% deviation from forecast - caution extended to %d min",
                           ev.name, surprise_pct,
                           MathMax(0, EconomicCalendarPostMinutes) + MathMax(0, NewsSurpriseExtraCautionMinutes));
            G_CAL_LAST_SURPRISE_ID = values[i].id;
         }
      }
      G_CAL_EV_COUNT++;
   }
}

// SETTLE RELEASE: a release is followed by a burst; once the burst is over the post window only kept
// entries shut on a normal market (30-60 min of silence per release). The post window now ends early
// when, at least NewsSettleMinMinutes after the release, the last NewsSettleBars closed M1 candles were
// all calm against the pre-news ATR(M1), the spread is back to this hour's normal and the anomaly guard
// is quiet. The decision is latched per release; the brain (council, late, lock) then picks the side.
bool CalendarEventSettled(const ulong id)
{
   for(int i = 0; i < CAL_CACHE_MAX; i++)
      if(G_CAL_SETTLED_ID[i] == id && id != 0)
         return true;
   return false;
}

bool CalendarSettleCheck(const int idx, const datetime now)
{
   if(!EnableNewsSettleRelease || idx < 0 || idx >= G_CAL_EV_COUNT)
      return false;
   ulong id = G_CAL_EV_ID[idx];
   if(CalendarEventSettled(id))
      return true;
   datetime ev_t = G_CAL_EV_TIME[idx];
   // AUDIT FIX: a big surprise sets the tone for longer - it keeps at least the normal post window and
   // only its surprise extension can be cut short by a settled market.
   int min_min = MathMax(1, NewsSettleMinMinutes);
   if(G_CAL_EV_SURPRISE[idx])
      min_min = MathMax(min_min, EconomicCalendarPostMinutes);
   if(now - ev_t < (long)min_min * 60)
      return false;
   int nb = MathMax(1, NewsSettleBars);
   int s = iBarShift(_Symbol, PERIOD_M1, ev_t, false);   // the bar the release fell into
   if(s <= nb)
      return false;                                      // not enough closed candles after it yet
   double pre_atr = ATRPointsManual(PERIOD_M1, 14, s + 1);
   if(pre_atr <= 0.0)
      return false;
   for(int k = 1; k <= nb; k++)
   {
      double rng = (iHigh(_Symbol, PERIOD_M1, k) - iLow(_Symbol, PERIOD_M1, k)) / _Point;
      if(rng <= 0.0 || rng > NewsSettleRangeATR * pre_atr)
         return false;
   }
   double norm = MBNormalSpread();
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(norm > 0.0 && spr > NewsSettleSpreadMult * norm)
      return false;
   string an = "";
   if(MBAnomalyBlocks(an))
      return false;
   G_CAL_SETTLED_ID[G_CAL_SETTLED_POS] = id;
   G_CAL_SETTLED_POS = (G_CAL_SETTLED_POS + 1) % CAL_CACHE_MAX;
   if(EconomicCalendarPrintOnUse)
      PrintFormat("[SIRUS CALENDAR] %s: market settled %d min after the release (last %d M1 candles <= %.1f x pre-news ATR %.0f, spread %.0f) - post-news pause ended",
                  G_CAL_EV_NAME[idx], (int)((now - ev_t) / 60), nb, NewsSettleRangeATR, pre_atr, spr);
   return true;
}

void UpdateEconomicCalendarGuard()
{
   if(!EnableEconomicCalendarGuard)
   {
      CalendarClearState();
      return;
   }

   // V31.6b tester-awareness: MT5's CalendarValueHistory/CalendarEventById return NOTHING
   // inside the Strategy Tester (platform limitation). Without this guard a backtest would
   // silently behave differently from live. Cleanly disable so backtests are deterministic.
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      CalendarClearState();
      return;
   }

   // Calendar times are trade-server times. TimeTradeServer() keeps running between ticks, unlike
   // TimeCurrent(), which is the last quote time and stands still on a quiet market.
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();

   int refresh = MathMax(10, EconomicCalendarRefreshSeconds);
   if(G_CAL_PENDING_ACTUAL)
      refresh = MathMin(refresh, 30);
   if(G_CAL_LAST_SCAN <= 0 || (now - G_CAL_LAST_SCAN) >= refresh || now < G_CAL_LAST_SCAN)
      CalendarFetch(now);

   // Evaluate the window on every call against the live clock. Priority: an event still ahead (it is the
   // one auto-flat must see and the one about to move price), the nearest first; otherwise the most
   // recent release whose post window has not ended.
   int pre_sec = MathMax(0, EconomicCalendarPreMinutes) * 60;
   int best_pre = -1, best_post = -1;
   // The settle check reads closed M1 candles - once per M1 bar is enough (the timer also calls this).
   datetime m1_bar = iTime(_Symbol, PERIOD_M1, 0);
   bool settle_eval = (m1_bar > 0 && m1_bar != G_CAL_SETTLE_BAR);
   if(settle_eval)
      G_CAL_SETTLE_BAR = m1_bar;
   bool any_surprise = false;
   double surprise_pct = 0.0;
   for(int i = 0; i < G_CAL_EV_COUNT; i++)
   {
      long diff = (long)(G_CAL_EV_TIME[i] - now);
      if(diff >= 0)
      {
         if(diff <= pre_sec && (best_pre < 0 || G_CAL_EV_TIME[i] < G_CAL_EV_TIME[best_pre]))
            best_pre = i;
      }
      else if(-diff <= CalendarPostWindowSeconds(i))
      {
         if(CalendarEventSettled(G_CAL_EV_ID[i]) || (settle_eval && CalendarSettleCheck(i, now)))
            continue;   // released and the market has settled - this release no longer holds entries
         if(best_post < 0 || G_CAL_EV_TIME[i] > G_CAL_EV_TIME[best_post])
            best_post = i;
         if(G_CAL_EV_SURPRISE[i])
         {
            any_surprise = true;
            surprise_pct = MathMax(surprise_pct, G_CAL_EV_SURPRISE_PCT[i]);
         }
      }
   }

   int pick = (best_pre >= 0) ? best_pre : best_post;
   ulong prev_id = G_CAL_EVENT_ID;
   bool prev_active = G_CAL_ACTIVE;

   if(pick < 0)
   {
      CalendarClearState();
      if(prev_active && (EconomicCalendarPrintOnUse && VerboseLogs))
         Print("[SIRUS CALENDAR] news window closed");
      return;
   }

   long pick_diff = (long)(G_CAL_EV_TIME[pick] - now);
   G_CAL_ACTIVE = true;
   G_CAL_EVENT_NAME = G_CAL_EV_NAME[pick];
   G_CAL_EVENT_ID = G_CAL_EV_ID[pick];
   // Whole minutes toward zero, as before: +14 = 14m ahead, -3 = 3m after.
   G_CAL_MINUTES_FROM_EVENT = (int)(pick_diff / 60);
   G_CAL_BIG_SURPRISE = any_surprise;
   G_CAL_SURPRISE_PERCENT = surprise_pct;

   // Log the transition, not every scan.
   if((EconomicCalendarPrintOnUse && VerboseLogs) && (!prev_active || prev_id != G_CAL_EVENT_ID))
      PrintFormat("[SIRUS v29 CALENDAR] high-impact window active: %s (%d min)%s",
                  G_CAL_EVENT_NAME, G_CAL_MINUTES_FROM_EVENT,
                  (any_surprise ? StringFormat(" | surprise %.0f%% - extended", surprise_pct) : ""));
}

bool EconomicCalendarAllowsEntry(string &reason)
{
   if(!EnableEconomicCalendarGuard || !G_CAL_ACTIVE)
   {
      reason = "calendar clear";
      return true;
   }
   if(EconomicCalendarHardBlockFirst)
   {
      reason = StringFormat("calendar window active: %s", G_CAL_EVENT_NAME);
      return false;
   }
   reason = "calendar caution active (lot trimmed, not blocked)";
   return true;
}

double EconomicCalendarLotAdjust(const double lot)
{
   if(!EnableEconomicCalendarGuard || !G_CAL_ACTIVE || EconomicCalendarHardBlockFirst)
      return lot;

   double adjusted = lot * EconomicCalendarLotFactor;

   // V31.6j new: a confirmed big surprise (actual far from forecast) gets extra caution on
   // top of the normal news-window trim, since a large surprise tends to mean more
   // unpredictable follow-through, not just "near an event".
   if(EnableNewsSurprise && G_CAL_BIG_SURPRISE)
      adjusted *= NewsSurpriseLotFactor;

   return adjusted;
}

// ============================================================================
// V29 D-BLOCK - MARKET CONFIDENCE SCORE
// Three independent signals (Volatility Regime, Bayes per-detector performance,
// Hurst Exponent) combine into ONE final lot multiplier - never a hard block,
// and never three separate stacking gates (the exact trap this whole rebuild
// started by fixing in v28).
// ============================================================================

// --- D1: Volatility Regime - where does today's ATR rank against recent history? ---
double VolatilityRegimeScore()
{
   if(!EnableConfidenceScore)
      return 0.0;

   int lookback = MathMax(20, VolRegimeLookbackBars);
   double current_atr = ATRPointsManual(ConfidenceATRTF, VolRegimeATRPeriod, 1);
   if(current_atr <= 0.0)
      return 0.0;

   int below_count = 0;
   int total = 0;

   for(int i = 1; i <= lookback; i++)
   {
      double a = ATRPointsManual(ConfidenceATRTF, VolRegimeATRPeriod, i + 1);
      if(a <= 0.0)
         continue;
      if(a <= current_atr)
         below_count++;
      total++;
   }

   if(total == 0)
      return 0.0;

   double percentile = (double)below_count / total * 100.0;

   // V31.6z58 fix: found via systematic sweep for simplistic logic. This function does real
   // work - computing a genuine continuous 0-100 percentile of current ATR against its own
   // recent history - and then threw that information away by collapsing it into just THREE
   // fixed values. The 51st and 84th percentile both returned exactly 1.0; the 85th and the
   // 99th both returned exactly -1.0. A market on the edge of a storm and one deep inside it
   // were indistinguishable. The endpoints below preserve the original meaning (100th = -1.0
   // storm, 0th = -0.3 dead, mid-range = 1.0 favorable) but everything between is now a real
   // gradient instead of three steps.
   if(!EnableVolRegimeContinuous)
   {
      if(percentile >= VolRegimeHighPercentile)
         return -1.0;
      if(percentile <= VolRegimeLowPercentile)
         return -0.3;
      return 1.0;
   }

   if(percentile >= VolRegimeHighPercentile)
   {
      // Storm territory - how deep? -0.6 at the threshold, -1.0 at the 100th percentile.
      double t = (percentile - VolRegimeHighPercentile) / MathMax(1.0, 100.0 - VolRegimeHighPercentile);
      return -(0.6 + 0.4 * MathMax(0.0, MathMin(1.0, t)));
   }

   if(percentile <= VolRegimeLowPercentile)
   {
      // Dead/thin territory - milder than a storm, and also graduated.
      double t = (VolRegimeLowPercentile - percentile) / MathMax(1.0, VolRegimeLowPercentile);
      return -(0.15 + 0.15 * MathMax(0.0, MathMin(1.0, t)));
   }

   // Normal band - best in the middle, tapering toward either edge rather than a flat 1.0
   // right up until the cliff.
   double mid = (VolRegimeHighPercentile + VolRegimeLowPercentile) * 0.5;
   double half_span = MathMax(1.0, (VolRegimeHighPercentile - VolRegimeLowPercentile) * 0.5);
   double dist_from_mid = MathMin(1.0, MathAbs(percentile - mid) / half_span);
   return 1.0 - dist_from_mid * 0.35;
}

// --- D3: Hurst Exponent via simplified 2-point R/S analysis. H far from 0.5 means the market
// has real structure (trending or mean-reverting) - either way, more trustworthy than a pure
// random walk (H near 0.5). ---
double HurstRSForChunkSize(const double &returns[], const int total_len, const int chunk_size)
{
   if(chunk_size < 2 || chunk_size > total_len)
      return 0.0;

   int num_chunks = total_len / chunk_size;
   if(num_chunks < 1)
      return 0.0;

   double sum_rs = 0.0;
   int valid_chunks = 0;

   for(int c = 0; c < num_chunks; c++)
   {
      int start = c * chunk_size;
      double mean = 0.0;
      for(int i = 0; i < chunk_size; i++)
         mean += returns[start + i];
      mean /= chunk_size;

      double cum = 0.0, max_cum = -1.0e18, min_cum = 1.0e18, var = 0.0;
      for(int i = 0; i < chunk_size; i++)
      {
         double dev = returns[start + i] - mean;
         cum += dev;
         if(cum > max_cum) max_cum = cum;
         if(cum < min_cum) min_cum = cum;
         var += dev * dev;
      }

      double stdev = MathSqrt(var / chunk_size);
      double r = max_cum - min_cum;

      if(stdev > 0.0)
      {
         sum_rs += r / stdev;
         valid_chunks++;
      }
   }

   if(valid_chunks == 0)
      return 0.0;

   return sum_rs / valid_chunks;
}
