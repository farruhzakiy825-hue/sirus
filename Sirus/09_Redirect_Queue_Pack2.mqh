//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 09_Redirect_Queue_Pack2                         |
//| Direction redirect, temp blocks, signal queue, Pack2/Pack3       |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  PHASE 21.3 DIRECTION REDIRECT ENGINE
//==================================================================//
void ResetRedirect(const string reason)
{
   G_REDIRECT_STATUS = "REDIRECT: WAIT | reason=" + reason;
   G_REDIRECT_REASON = reason;
   G_REDIRECT_DETAIL = "REDIRECT DETAIL: " + reason;
   G_REDIRECT_APPLIED = false;
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
   G_GRID_ATTEMPTS = 0;
   G_GRID_SUCCESSES = 0;
   G_GRID_FAILS = 0;
   G_BASKET_ORDERS = 0;
   G_BASKET_VOLUME = 0.0;
   G_BASKET_AVG_PRICE = 0.0;
   G_BASKET_PROFIT = 0.0;
   G_BASKET_POINTS = 0.0;
   G_BASKET_DD_PERCENT = 0.0;
   G_BASKET_DIRECTION = -1;
   G_BASKET_LAST_GRID_PRICE = 0.0;
   G_BASKET_ADVERSE_STREAK = 0;
   G_BASKET_DD_HISTORY_COUNT = 0;
   G_BASKET_DD_HISTORY_BAR = -1;
   G_SEE_PERSIST_BARS = 0;
   G_SEE_PERSIST_DIR = 0;
   G_LAST_DD_WARNING_LEVEL = 0.0;
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

ENUM_OPPORTUNITY_DIR OppositeDirection(ENUM_OPPORTUNITY_DIR dir)
{
   if(dir == OPP_DIR_BUY)
      return OPP_DIR_SELL;
   if(dir == OPP_DIR_SELL)
      return OPP_DIR_BUY;
   return OPP_DIR_NONE;
}

bool DirectionAlignedWithMarket(ENUM_OPPORTUNITY_DIR dir)
{
   if(!RedirectRespectMarketTrend)
      return true;

   if(G_MARKET_STATE == MARKET_TREND_UP || G_MARKET_STATE == MARKET_PULLBACK)
      return (dir == OPP_DIR_BUY);

   if(G_MARKET_STATE == MARKET_TREND_DOWN)
      return (dir == OPP_DIR_SELL);

   // Range/exhaustion/dead can redirect both ways if setup is valid.
   return true;
}

void ConsiderRedirectCandidate(ENUM_OPPORTUNITY_DIR dir,
                               ENUM_OPPORTUNITY_TYPE type,
                               int score,
                               string reason,
                               bool micro_preferred,
                               ENUM_OPPORTUNITY_DIR &best_dir,
                               ENUM_OPPORTUNITY_TYPE &best_type,
                               int &best_score,
                               string &best_reason,
                               bool &best_micro)
{
   if(dir == OPP_DIR_NONE || score <= 0)
      return;

   if(!DirectionAlignedWithMarket(dir))
      return;

   ENUM_OPPORTUNITY_GRADE grade = GradeFromScore(score, micro_preferred);
   if(grade == OPP_GRADE_NONE)
      return;

   if(!RedirectAllowMicro && grade == OPP_GRADE_C_MICRO)
      return;

   if(score < RedirectMinScore)
      return;

   if(score > best_score)
   {
      best_dir = dir;
      best_type = type;
      best_score = score;
      best_reason = reason;
      best_micro = micro_preferred;
   }
}

bool FindOppositeRedirectCandidate(ENUM_OPPORTUNITY_DIR target_dir,
                                   ENUM_OPPORTUNITY_TYPE &best_type,
                                   int &best_score,
                                   string &best_reason,
                                   bool &best_micro)
{
   ENUM_OPPORTUNITY_DIR best_dir = OPP_DIR_NONE;
   best_type = OPP_TYPE_NONE;
   best_score = 0;
   best_reason = "none";
   best_micro = false;

   string reason = "";
   int score = 0;

   if(target_dir == OPP_DIR_BUY)
   {
      if(DetectSweepBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_SWEEP_REJECTION, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectFakeBreakoutReturnBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_FAKE_BREAKOUT_RETURN, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectNearZoneReactionBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_NEAR_ZONE_REACTION, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectRangeEdgeBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_RANGE_EDGE, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectPullbackBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_PULLBACK_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMomentumBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_MOMENTUM_SCALP, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectExhaustionBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_EXHAUSTION_REVERSAL, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectBreakoutContinuationBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_BREAKOUT_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectTrendRideBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_TREND_RIDE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectSwingContinuationBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_SWING_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMABounceBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_MA_BOUNCE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectDonchianBreakoutBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_DONCHIAN_BREAKOUT, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectConsecutiveCandlesBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_CONSECUTIVE_CANDLES, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectDXYConfirmedTrendBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_DXY_CONFIRMED_TREND, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectExpandingVolatilityBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_EXPANDING_VOLATILITY, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMTFUnanimousBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_MTF_UNANIMOUS, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectEQZoneTrendBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_EQ_ZONE_TREND, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectVolumePushBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_VOLUME_PUSH, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectVWAPBounceBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_VWAP_BOUNCE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectZoneRetestBuy(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_BUY, OPP_TYPE_ZONE_RETEST, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);
   }
   else if(target_dir == OPP_DIR_SELL)
   {
      if(DetectSweepSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_SWEEP_REJECTION, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectFakeBreakoutReturnSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_FAKE_BREAKOUT_RETURN, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectNearZoneReactionSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_NEAR_ZONE_REACTION, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectRangeEdgeSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_RANGE_EDGE, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectPullbackSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_PULLBACK_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMomentumSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_MOMENTUM_SCALP, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectExhaustionSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_EXHAUSTION_REVERSAL, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectBreakoutContinuationSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_BREAKOUT_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectTrendRideSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_TREND_RIDE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectSwingContinuationSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_SWING_CONTINUATION, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMABounceSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_MA_BOUNCE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectDonchianBreakoutSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_DONCHIAN_BREAKOUT, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectConsecutiveCandlesSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_CONSECUTIVE_CANDLES, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectDXYConfirmedTrendSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_DXY_CONFIRMED_TREND, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectExpandingVolatilitySell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_EXPANDING_VOLATILITY, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectMTFUnanimousSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_MTF_UNANIMOUS, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectEQZoneTrendSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_EQ_ZONE_TREND, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectVolumePushSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_VOLUME_PUSH, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectVWAPBounceSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_VWAP_BOUNCE, score, reason, false, best_dir, best_type, best_score, best_reason, best_micro);

      if(DetectZoneRetestSell(reason, score))
         ConsiderRedirectCandidate(OPP_DIR_SELL, OPP_TYPE_ZONE_RETEST, score, reason, true, best_dir, best_type, best_score, best_reason, best_micro);
   }

   return (best_dir == target_dir && best_type != OPP_TYPE_NONE && best_score > 0);
}

void ApplyRedirectOpportunity(ENUM_OPPORTUNITY_DIR to_dir,
                              ENUM_OPPORTUNITY_TYPE type,
                              int score,
                              string reason,
                              bool micro_preferred)
{
   G_REDIRECT_APPLIED = true;
   G_REDIRECT_TO_DIR = to_dir;
   G_REDIRECT_TYPE = type;
   G_REDIRECT_SCORE = score;
   G_REDIRECT_REASON = reason;
   G_REDIRECT_SUCCESSES++;

   ENUM_OPPORTUNITY_GRADE grade = GradeFromScore(score, micro_preferred);

   G_OPP_DIR = to_dir;
   G_OPP_TYPE = type;
   G_OPP_SCORE = score;
   G_OPP_GRADE = grade;
   G_OPP_IS_MICRO = (grade == OPP_GRADE_C_MICRO || micro_preferred);
   G_OPP_REASON = "redirected: " + reason;

   G_OPP_STATUS = StringFormat("OPPORTUNITY: %s %s %s | score=%d | REDIRECTED",
                               OpportunityGradeToString(G_OPP_GRADE),
                               OpportunityDirToString(G_OPP_DIR),
                               OpportunityTypeToString(G_OPP_TYPE),
                               G_OPP_SCORE);

   G_OPP_DETAIL = "OPPORTUNITY DETAIL: redirected from opposite check | " + reason;
}

void UpdateDirectionRedirectEngine(const string source)
{
   G_REDIRECT_APPLIED = false;

   if(!UseDirectionRedirect)
   {
      ResetRedirect("UseDirectionRedirect=false");
      return;
   }

   if(!G_ENV_READY)
   {
      ResetRedirect("ENV not ready");
      return;
   }

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
   {
      ResetRedirect("no original direction");
      return;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
   {
      ResetRedirect("hard block, redirect disabled");
      return;
   }

   if(RedirectOnlyOnScoreWait && G_SCORE_DECISION != SCORE_DECISION_WAIT)
   {
      ResetRedirect("score is not WAIT");
      return;
   }

   if(!RedirectOnlyOnScoreWait && (G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS))
   {
      ResetRedirect("original signal already passed");
      return;
   }

   if(RedirectAvoidChaosImpulse && (G_MARKET_STATE == MARKET_CHAOS || G_MARKET_STATE == MARKET_IMPULSE))
   {
      ResetRedirect("market chaos/impulse");
      return;
   }

   ENUM_OPPORTUNITY_DIR from_dir = G_OPP_DIR;
   ENUM_OPPORTUNITY_DIR target_dir = OppositeDirection(from_dir);

   if(target_dir == OPP_DIR_NONE)
   {
      ResetRedirect("opposite direction unavailable");
      return;
   }

   G_REDIRECT_ATTEMPTS++;
   G_REDIRECT_FROM_DIR = from_dir;

   ENUM_OPPORTUNITY_TYPE best_type = OPP_TYPE_NONE;
   int best_score = 0;
   string best_reason = "";
   bool best_micro = false;

   bool found = FindOppositeRedirectCandidate(target_dir, best_type, best_score, best_reason, best_micro);

   if(!found)
   {
      ResetRedirect("opposite setup not valid");
   }
   else if(best_score < G_OPP_SCORE + RedirectMinImprovement)
   {
      ResetRedirect(StringFormat("opposite score not better %d vs original %d + %d",
                                 best_score,
                                 G_OPP_SCORE,
                                 RedirectMinImprovement));
   }
   else
   {
      ApplyRedirectOpportunity(target_dir, best_type, best_score, best_reason, best_micro);

      G_REDIRECT_STATUS = StringFormat("REDIRECT: %s -> %s | type=%s | score=%d",
                                       OpportunityDirToString(from_dir),
                                       OpportunityDirToString(target_dir),
                                       OpportunityTypeToString(best_type),
                                       best_score);

      G_REDIRECT_DETAIL = "REDIRECT DETAIL: " + best_reason;
   }

   string signature = G_REDIRECT_STATUS + "|" + G_REDIRECT_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintRedirectDecisions && signature != G_REDIRECT_LAST_SIGNATURE)
   {
      if(G_REDIRECT_APPLIED || G_REDIRECT_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 REDIRECT] %s | %s | source=%s",
                     G_REDIRECT_STATUS,
                     G_REDIRECT_DETAIL,
                     source);
      }
      G_REDIRECT_LAST_SIGNATURE = signature;
   }
}



//==================================================================//
//  PHASE 21.3 BLOCK EXPIRY ENGINE
//==================================================================//
int TempBlockDefaultBars(ENUM_TEMP_BLOCK_TYPE block_type)
{
   switch(block_type)
   {
      case TEMP_BLOCK_SCORE_WEAK:  return BlockExpiryScoreWeakBars;
      case TEMP_BLOCK_IMPULSE:     return BlockExpiryImpulseBars;
      case TEMP_BLOCK_SOFT_SPREAD: return 0; // spread is real-time, not bar-expiry
      case TEMP_BLOCK_ROOM_TO_TP:  return BlockExpiryRoomBars;
      case TEMP_BLOCK_MICRO_GUARD: return BlockExpiryMicroBars;
      case TEMP_BLOCK_QUEUE_WAIT:  return SignalQueueBars;
      case TEMP_BLOCK_REDIRECT:    return BlockExpiryRedirectBars;
      case TEMP_BLOCK_BOS_RETEST:  return BlockExpiryBOSBars;
      case TEMP_BLOCK_ZONE_DANGER: return BlockExpiryZoneBars;
      default:                     return 0;
   }
}

int TempBlockAgeBars()
{
   return G_BARS_SEEN - G_BLOCK_START_BAR;
}

int TempBlockAgeSeconds()
{
   if(G_BLOCK_START_TIME <= 0)
      return 999999;
   return (int)(TimeCurrent() - G_BLOCK_START_TIME);
}

void ClearTempBlock(const string reason)
{
   if(G_BLOCK_ACTIVE)
      G_BLOCK_CLEARED_COUNT++;

   G_BLOCK_ACTIVE = false;
   G_BLOCK_EXPIRED = false;
   G_BLOCK_JUST_EXPIRED = false;
   G_BLOCK_TYPE = TEMP_BLOCK_NONE;
   G_BLOCK_START_BAR = -100000;
   G_BLOCK_START_TIME = 0;
   G_BLOCK_MAX_BARS = 0;
   G_BLOCK_REASON = reason;
   G_BLOCK_SOURCE = "";
   G_GRID_STATUS = "GRID: initializing";
   G_GRID_REASON = "initial grid";
   G_GRID_DETAIL = "GRID DETAIL: initializing";
   G_GRID_LAST_SIGNATURE = "";
   // FIX(grid-cooldown-wipe): grid timing history is NOT cleared by a routine reset. Wiping
   // G_LAST_GRID_BAR to -100000 fails the `> -9999` guard on the GridCooldownBars check, so
   // the grid cooldown was skipped entirely and grid orders could fire back to back.
   G_GRID_ATTEMPTS = 0;
   G_GRID_SUCCESSES = 0;
   G_GRID_FAILS = 0;
   // AUDIT FIX: a temp-block clear is not a basket close - the live basket's stats are no longer
   // zeroed here (an open basket read as "flat" for the rest of the tick).
   G_BASKET_ADVERSE_STREAK = 0;
   G_BASKET_DD_HISTORY_COUNT = 0;
   G_BASKET_DD_HISTORY_BAR = -1;
   G_SEE_PERSIST_BARS = 0;
   G_SEE_PERSIST_DIR = 0;
   G_LAST_DD_WARNING_LEVEL = 0.0;
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
   // FIX(vps-timer-wipe): G_VPS_LAST_CHECK/LAST_AUDIT/LAST_BROKER_PRINT/TICK_WINDOW_START/TICK_WINDOW_COUNT/TICKS_PER_MINUTE deliberately NOT cleared here - these are UpdateVPSLiveValidation()'s own throttle timers. Zeroing them defeated VPSValidationSeconds/VPSNoTradeAuditSeconds/VPSBrokerSnapshotSeconds and reset the ticks-per-minute rolling window before it could accumulate a full period. (Same fix as the four sibling reset blocks; OnInit deliberately still clears them.)
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
   // FIX(pack3-timer-wipe): G_PACK3_LAST_DEAL_SCAN/LAST_AUDIT_PRINT deliberately NOT cleared here - Pack3ClosedDealAnalytics() throttles its deal-history rescan on them; zeroing them forced a full HistorySelect rescan on the next call.
   G_PACK3_EVENT_COUNT = 0;
   // FIX(pack3-timer-wipe): G_DEALS_* deliberately NOT cleared here - these are Pack3ClosedDealAnalytics()'s cached results, valid between its own throttled rescans; wiping them made the dashboard read 0 deals / 0% winrate until the next real rescan.
   G_BROKER_EFFECTIVE_STOP = 0.0;
   G_BLOCK_STATUS = "BLOCK: NONE | reason=" + reason;
   G_BLOCK_DETAIL = StringFormat("BLOCK DETAIL: cleared=%d expired=%d",
                                 G_BLOCK_CLEARED_COUNT,
                                 G_BLOCK_EXPIRED_COUNT);
}

void StartOrRefreshTempBlock(ENUM_TEMP_BLOCK_TYPE block_type, const string reason, const string source)
{
   if(block_type == TEMP_BLOCK_NONE)
      return;

   int max_bars = TempBlockDefaultBars(block_type);

   // Soft spread is displayed but not sticky, because it should clear immediately when spread normalizes.
   if(block_type == TEMP_BLOCK_SOFT_SPREAD)
   {
      G_BLOCK_ACTIVE = true;
      G_BLOCK_EXPIRED = false;
      G_BLOCK_JUST_EXPIRED = false;
      G_BLOCK_TYPE = block_type;
      G_BLOCK_START_BAR = G_BARS_SEEN;
      G_BLOCK_START_TIME = TimeCurrent();
      G_BLOCK_MAX_BARS = 0;
      G_BLOCK_REASON = reason;
      G_BLOCK_SOURCE = source;
      return;
   }

   bool same_block = (G_BLOCK_ACTIVE && G_BLOCK_TYPE == block_type);

   if(!same_block || G_BLOCK_EXPIRED)
   {
      G_BLOCK_ACTIVE = true;
      G_BLOCK_EXPIRED = false;
      G_BLOCK_JUST_EXPIRED = false;
      G_BLOCK_TYPE = block_type;
      G_BLOCK_START_BAR = G_BARS_SEEN;
      G_BLOCK_START_TIME = TimeCurrent();
      G_BLOCK_MAX_BARS = max_bars;
      G_BLOCK_REASON = reason;
      G_BLOCK_SOURCE = source;
   }
   else
   {
      // Same block remains active without resetting bar counter.
      // This is the important anti-freeze rule.
      G_BLOCK_REASON = reason;
      G_BLOCK_SOURCE = source;
   }
}

ENUM_TEMP_BLOCK_TYPE DetectCurrentTempBlock(string &reason)
{
   reason = "none";

   if(!G_ENV_READY)
   {
      reason = "ENV not ready is hard/technical, not temporary expiry";
      return TEMP_BLOCK_NONE;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
   {
      reason = "score hard block";
      return TEMP_BLOCK_NONE;
   }

   if(G_MARKET_STATE == MARKET_IMPULSE && G_SCORE_DECISION != SCORE_DECISION_PASS && G_SCORE_DECISION != SCORE_DECISION_MICRO_PASS)
   {
      reason = "fresh impulse temporary wait";
      return TEMP_BLOCK_IMPULSE;
   }

   if(G_LAST_SPREAD_POINTS > EffSpread(MaxSpreadPoints) && G_LAST_SPREAD_POINTS < CriticalSpreadPoints)
   {
      reason = StringFormat("soft spread %d/%d", G_LAST_SPREAD_POINTS, EffSpread(MaxSpreadPoints));
      return TEMP_BLOCK_SOFT_SPREAD;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_WAIT && G_SCORE_ROOM_POINTS > 0.0)
   {
      double min_room = G_SCORE_TP_TARGET * (double)ScoreMinRoomPercentOfTP / 100.0;
      if(G_SCORE_ROOM_POINTS < min_room)
      {
         reason = StringFormat("limited room %.0f/%.0f", G_SCORE_ROOM_POINTS, min_room);
         return TEMP_BLOCK_ROOM_TO_TP;
      }
   }

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS && !G_MICRO_READY)
   {
      reason = "micro guard waiting: " + G_MICRO_REASON;
      return TEMP_BLOCK_MICRO_GUARD;
   }

   if(G_QUEUE_ACTIVE && !G_QUEUE_REPLAYED)
   {
      reason = "queue hold/replay wait";
      return TEMP_BLOCK_QUEUE_WAIT;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_WAIT && UseDirectionRedirect)
   {
      reason = "redirect/score soft wait";
      return TEMP_BLOCK_REDIRECT;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_WAIT)
   {
      reason = StringFormat("score weak final=%d/%d", G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
      return TEMP_BLOCK_SCORE_WEAK;
   }

   return TEMP_BLOCK_NONE;
}

bool IsTempBlockExpired()
{
   if(!G_BLOCK_ACTIVE)
      return false;

   if(G_BLOCK_TYPE == TEMP_BLOCK_SOFT_SPREAD)
      return false;

   int age_bars = TempBlockAgeBars();
   int age_seconds = TempBlockAgeSeconds();

   if(G_BLOCK_MAX_BARS > 0 && age_bars >= G_BLOCK_MAX_BARS)
      return true;

   if(BlockExpiryMaxSeconds > 0 && age_seconds >= BlockExpiryMaxSeconds)
      return true;

   return false;
}

void ApplyExpiredBlockSoftPass()
{
   if(!BlockExpiryAllowExpiredSoftPass)
      return;

   if(!G_BLOCK_EXPIRED)
      return;

   if(G_SCORE_DECISION != SCORE_DECISION_WAIT)
      return;

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
      return;

   // Never bypass hard risk. Only convert near-pass soft waits.
   if(G_SCORE_MIN_REQUIRED <= 0)
      return;

   int boosted = G_SCORE_FINAL + ExpiredBlockScoreBoost;
   if(boosted >= G_SCORE_MIN_REQUIRED)
   {
      G_SCORE_BONUS += ExpiredBlockScoreBoost;
      G_SCORE_FINAL = boosted;
      G_SCORE_DECISION = (IsMicroOpportunity() ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS);
      G_SCORE_STATUS = StringFormat("SCORE: %s | final=%d/%d | expired block boost +%d",
                                    ScoreDecisionToString(G_SCORE_DECISION),
                                    G_SCORE_FINAL,
                                    G_SCORE_MIN_REQUIRED,
                                    ExpiredBlockScoreBoost);
      G_SCORE_DETAIL = G_SCORE_DETAIL + StringFormat(" +%d expired block boost;", ExpiredBlockScoreBoost);
   }
}

void UpdateBlockExpiryEngine(const string source)
{
   if(!UseBlockExpiryEngine)
   {
      if(G_BLOCK_ACTIVE)
         ClearTempBlock("UseBlockExpiryEngine=false");
      else
      {
         G_BLOCK_STATUS = "BLOCK: OFF";
         G_BLOCK_DETAIL = "BLOCK DETAIL: disabled";
      }
      return;
   }

   G_BLOCK_JUST_EXPIRED = false;

   string reason = "";
   ENUM_TEMP_BLOCK_TYPE detected = DetectCurrentTempBlock(reason);

   if(detected == TEMP_BLOCK_NONE)
   {
      if(G_BLOCK_ACTIVE && !G_BLOCK_EXPIRED)
         ClearTempBlock("condition cleared: " + reason);
      else if(!G_BLOCK_ACTIVE)
      {
         G_BLOCK_STATUS = "BLOCK: NONE | reason=" + reason;
         G_BLOCK_DETAIL = StringFormat("BLOCK DETAIL: cleared=%d expired=%d",
                                       G_BLOCK_CLEARED_COUNT,
                                       G_BLOCK_EXPIRED_COUNT);
      }
   }
   else
   {
      StartOrRefreshTempBlock(detected, reason, source);

      if(IsTempBlockExpired())
      {
         if(!G_BLOCK_EXPIRED)
         {
            G_BLOCK_EXPIRED = true;
            G_BLOCK_JUST_EXPIRED = true;
            G_BLOCK_EXPIRED_COUNT++;
         }
      }
   }

   if(G_BLOCK_ACTIVE)
   {
      G_BLOCK_STATUS = StringFormat("BLOCK: %s %s | age=%d/%d bars | %ds",
                                    (G_BLOCK_EXPIRED ? "EXPIRED" : "ACTIVE"),
                                    TempBlockToString(G_BLOCK_TYPE),
                                    TempBlockAgeBars(),
                                    G_BLOCK_MAX_BARS,
                                    TempBlockAgeSeconds());

      G_BLOCK_DETAIL = "BLOCK DETAIL: " + G_BLOCK_REASON + " | source=" + G_BLOCK_SOURCE;
   }

   ApplyExpiredBlockSoftPass();

   string signature = G_BLOCK_STATUS + "|" + G_BLOCK_DETAIL + "|" + IntegerToString(G_BARS_SEEN) + "|" + ScoreDecisionToString(G_SCORE_DECISION);

   if(PrintBlockExpiryEvents && signature != G_BLOCK_LAST_SIGNATURE)
   {
      if(G_BLOCK_ACTIVE || G_BLOCK_JUST_EXPIRED || G_BLOCK_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 BLOCK] %s | %s | score=%s %d/%d | source=%s",
                     G_BLOCK_STATUS,
                     G_BLOCK_DETAIL,
                     ScoreDecisionToString(G_SCORE_DECISION),
                     G_SCORE_FINAL,
                     G_SCORE_MIN_REQUIRED,
                     source);
      }
      G_BLOCK_LAST_SIGNATURE = signature;
   }
}

//==================================================================//
//  PHASE 21.3 SIGNAL QUEUE ENGINE
//==================================================================//
void ClearSignalQueue(const string reason)
{
   G_QUEUE_ACTIVE = false;
   G_QUEUE_REPLAYED = false;
   G_QUEUE_DIR = OPP_DIR_NONE;
   G_QUEUE_GRADE = OPP_GRADE_NONE;
   G_QUEUE_TYPE = OPP_TYPE_NONE;
   G_QUEUE_DECISION = SCORE_DECISION_NONE;
   G_QUEUE_MARKET_STATE = MARKET_UNKNOWN;
   G_QUEUE_OPP_SCORE = 0;
   G_QUEUE_SCORE_FINAL = 0;
   G_QUEUE_SCORE_MIN = 0;
   G_QUEUE_MODE = G_ACTIVE_MODE;
   G_QUEUE_IS_MICRO = false;
   G_QUEUE_TP_TARGET = 0.0;
   G_QUEUE_ROOM_POINTS = 0.0;
   G_QUEUE_OPP_REASON = "";
   G_QUEUE_SCORE_DETAIL = "";
   G_QUEUE_REASON = reason;
   G_QUEUE_STATUS = "QUEUE: EMPTY | reason=" + reason;
   G_QUEUE_DETAIL = "QUEUE DETAIL: " + reason;
}

bool IsScorePassedDecision(ENUM_SCORE_DECISION decision)
{
   return (decision == SCORE_DECISION_PASS || decision == SCORE_DECISION_MICRO_PASS);
}

int QueueAgeBars()
{
   return G_BARS_SEEN - G_QUEUE_SAVED_BAR;
}

int QueueAgeSeconds()
{
   if(G_QUEUE_SAVED_TIME <= 0)
      return 999999;
   return (int)(TimeCurrent() - G_QUEUE_SAVED_TIME);
}

bool IsQueueExpired(string &reason)
{
   if(!G_QUEUE_ACTIVE)
   {
      reason = "queue inactive";
      return true;
   }

   int age_bars = QueueAgeBars();
   int age_seconds = QueueAgeSeconds();

   if(SignalQueueBars > 0 && age_bars > SignalQueueBars)
   {
      reason = StringFormat("expired by bars %d/%d", age_bars, SignalQueueBars);
      return true;
   }

   if(SignalQueueMaxAgeSeconds > 0 && age_seconds > SignalQueueMaxAgeSeconds)
   {
      reason = StringFormat("expired by seconds %d/%d", age_seconds, SignalQueueMaxAgeSeconds);
      return true;
   }

   reason = "not expired";
   return false;
}

bool CurrentSignalShouldBeSaved()
{
   if(!UseSignalQueue)
      return false;

   if(!IsScorePassedDecision(G_SCORE_DECISION))
      return false;

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
      return false;

   return true;
}

void SaveCurrentSignalToQueue(const string reason)
{
   bool should_save = false;

   if(!G_QUEUE_ACTIVE)
      should_save = true;
   else if(SignalQueueRefreshBetter && G_SCORE_FINAL > G_QUEUE_SCORE_FINAL)
      should_save = true;
   else if(G_QUEUE_ACTIVE && G_OPP_DIR == G_QUEUE_DIR && G_SCORE_FINAL >= G_QUEUE_SCORE_FINAL)
      should_save = true;

   if(!should_save)
      return;

   G_QUEUE_ACTIVE = true;
   G_QUEUE_REPLAYED = false;
   G_QUEUE_SAVED_BAR = G_BARS_SEEN;
   G_QUEUE_SAVED_TIME = TimeCurrent();
   G_QUEUE_DIR = G_OPP_DIR;
   G_QUEUE_GRADE = G_OPP_GRADE;
   G_QUEUE_TYPE = G_OPP_TYPE;
   G_QUEUE_DECISION = G_SCORE_DECISION;
   G_QUEUE_MARKET_STATE = G_MARKET_STATE;
   G_QUEUE_OPP_SCORE = G_OPP_SCORE;
   G_QUEUE_SCORE_FINAL = G_SCORE_FINAL;
   G_QUEUE_SCORE_MIN = G_SCORE_MIN_REQUIRED;
   G_QUEUE_MODE = G_ACTIVE_MODE;   // V249fix(auto-mode): remember which bar authorised it
   G_QUEUE_IS_MICRO = (G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS);
   G_QUEUE_TP_TARGET = G_SCORE_TP_TARGET;
   G_QUEUE_ROOM_POINTS = G_SCORE_ROOM_POINTS;
   G_QUEUE_OPP_REASON = G_OPP_REASON;
   G_QUEUE_SCORE_DETAIL = G_SCORE_DETAIL;
   G_QUEUE_REASON = reason;
   G_QUEUE_SAVED_COUNT++;

   G_QUEUE_STATUS = StringFormat("QUEUE: SAVED %s %s %s | score=%d/%d | age=0/%d bars",
                                 OpportunityGradeToString(G_QUEUE_GRADE),
                                 OpportunityDirToString(G_QUEUE_DIR),
                                 OpportunityTypeToString(G_QUEUE_TYPE),
                                 G_QUEUE_SCORE_FINAL,
                                 G_QUEUE_SCORE_MIN,
                                 SignalQueueBars);

   G_QUEUE_DETAIL = "QUEUE DETAIL: saved reason=" + reason + " | " + G_QUEUE_SCORE_DETAIL;
}

bool QueueCanReplay(string &reason)
{
   if(!UseSignalQueue)
   {
      reason = "UseSignalQueue=false";
      return false;
   }

   if(!G_QUEUE_ACTIVE)
   {
      reason = "queue inactive";
      return false;
   }

   string exp_reason = "";
   if(IsQueueExpired(exp_reason))
   {
      reason = exp_reason;
      return false;
   }

   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return false;
   }

   if(G_LAST_SPREAD_POINTS < 0)
   {
      reason = "spread unreadable";
      return false;
   }

   if(G_LAST_SPREAD_POINTS > EffSpread(SignalQueueMaxSpreadPoints))
   {
      reason = StringFormat("queue spread high %d/%d", G_LAST_SPREAD_POINTS, EffSpread(SignalQueueMaxSpreadPoints));
      return false;
   }

   if(G_MARKET_STATE == MARKET_CHAOS)
   {
      reason = "market chaos";
      return false;
   }

   if(SignalQueueExpireOnOppositePass && IsScorePassedDecision(G_SCORE_DECISION) && G_OPP_DIR != G_QUEUE_DIR && G_OPP_DIR != OPP_DIR_NONE)
   {
      reason = "opposite passed signal detected";
      return false;
   }

   if(SignalQueueReplayWhenCurrentWait)
   {
      if(IsScorePassedDecision(G_SCORE_DECISION) && G_OPP_DIR == G_QUEUE_DIR)
      {
         reason = "current signal already passed same direction";
         return false;
      }
   }

   // V31.6z33 NEW: real gap found via systematic audit - a queued signal used to replay with
   // its ORIGINAL score untouched, completely bypassing every check that runs fresh each bar
   // (Exhaustion Consensus, Global/Local Trend Alignment, Zone proximity, and everything else
   // built this session). Up to SignalQueueBars bars (minutes) could pass between saving and
   // replaying - enough time for conditions to genuinely change. Re-validates against the two
   // most decision-relevant fresh checks before allowing a stale score to fire.
   if(EnableQueueReplayRevalidation && G_QUEUE_DIR != OPP_DIR_NONE)
   {
      // FIX(queue-dir-enum): ENUM_OPPORTUNITY_DIR is NONE=0 / BUY=1 / SELL=2, but the scoring
      // helpers below expect the +1/-1 convention and compare with `adx_dir == direction`, where
      // adx_dir is only ever -1/0/+1. Passing the raw enum meant a SELL (2) could never match, so
      // GlobalTrendConfidence() always returned a non-positive value for SELL and the alignment
      // check silently rejected EVERY sell replay while buy replays validated normally. Convert
      // once here and use the converted value for every check below.
      int q_dir_i = (G_QUEUE_DIR == OPP_DIR_BUY) ? 1 : ((G_QUEUE_DIR == OPP_DIR_SELL) ? -1 : 0);

      string ec_q_detail = "";
      double ec_q_score = ExhaustionConsensusScore(q_dir_i, ec_q_detail);
      if(ec_q_score <= QueueReplayExhaustionBlockThreshold)
      {
         reason = "replay blocked: fresh exhaustion consensus now against - " + ec_q_detail;
         return false;
      }

      string gla_q_detail = "";
      double gla_q_score = GlobalLocalAlignmentScore(q_dir_i, gla_q_detail);
      if(gla_q_score <= QueueReplayGlobalLocalBlockThreshold)
      {
         reason = "replay blocked: fresh global/local alignment now against - " + gla_q_detail;
         return false;
      }

      // FIX(queue-hardblock-bypass): ReplayQueuedSignal restores the stored decision and sets
      // G_SCORE_HARD_BLOCK to "none", so a queued signal used to fire WITHOUT re-checking any of
      // the context hard blocks. Conditions can change completely between queueing and replay -
      // price can drift onto a support that would veto a fresh SELL - and the replay would take
      // the trade anyway. Re-run the SAME shared evaluator the score engine uses, against the
      // QUEUED direction and current market state, and refuse the replay if it would now block.
      string ctx_q_why = "";
      // FIX(counter-trend-score-source): hand over the QUEUED signal's own score. This runs before
      // ReplayQueuedSignal() loads it, so the live G_SCORE_* globals describe the current scan -
      // and in the dominant case (no opportunity this bar, which is why a replay is being tried at
      // all) ResetScoreEngine has just zeroed them, which made the counter-trend release
      // unconditionally impossible for every queued signal.
      if(q_dir_i != 0 && CounterContextBlockNow(q_dir_i, ctx_q_why, false,
                                                G_QUEUE_SCORE_FINAL, G_QUEUE_SCORE_MIN))
      {
         reason = "replay blocked: context now hard-blocks this direction - " + ctx_q_why;
         return false;
      }

      // FIX(queue-soft-guard-bypass): the guards that are configured as PENALTIES (not hard blocks)
      // never surface through CounterContextBlockNow, and the replay reuses the STALE score, so their
      // penalty is never subtracted. A signal queued when it was clean can therefore replay straight
      // into a ghost / collapse extreme that formed in the meantime. Since we can't re-score a
      // replay, refuse it when a soft guard now points the same way as the queued entry.
      if(q_dir_i != 0)
      {
         if(EnableGhostZones && !GhostZoneHardBlock && GhostZoneReactionDir() == q_dir_i)
         {
            reason = "replay blocked: queued direction now runs into a ghost zone";
            return false;
         }
         if(EnableCollapseBottomGuard && !CollapseGuardHardBlock && CollapseBottomMoveDir() == q_dir_i)
         {
            reason = "replay blocked: queued direction now continues a fast move into its extreme";
            return false;
         }
      }
   }

   reason = "queue replay allowed";
   return true;
}

void ReplayQueuedSignal()
{
   // A queued signal is replayed with the direction and score it had when it was queued. Three
   // bars is not long, and it is long enough for price to have left the place that made the setup
   // worth taking - which is the whole point of queueing it rather than taking it then.
   if(EnableQueueLocationRecheck && EnableLocationBrain)
   {
      int q_dir = (G_QUEUE_DIR == OPP_DIR_BUY) ? 1 : ((G_QUEUE_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(q_dir != 0)
      {
         string q_why = "";
         if(LocationBrainVerdict(q_dir, q_why) != LB_OK)
         {
            if((QueueRecheckPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS QUEUE] replay held - %s", q_why);
            return;
         }
      }
   }

   G_OPP_DIR = G_QUEUE_DIR;
   G_OPP_GRADE = G_QUEUE_GRADE;
   G_OPP_TYPE = G_QUEUE_TYPE;
   G_OPP_SCORE = G_QUEUE_OPP_SCORE;
   G_OPP_IS_MICRO = G_QUEUE_IS_MICRO;
   G_OPP_REASON = "queue replay: " + G_QUEUE_OPP_REASON;

   G_OPP_STATUS = StringFormat("OPPORTUNITY: %s %s %s | score=%d | QUEUE_REPLAY",
                               OpportunityGradeToString(G_OPP_GRADE),
                               OpportunityDirToString(G_OPP_DIR),
                               OpportunityTypeToString(G_OPP_TYPE),
                               G_OPP_SCORE);

   G_OPP_DETAIL = "OPPORTUNITY DETAIL: replayed from queue | " + G_QUEUE_OPP_REASON;

   G_SCORE_DECISION = G_QUEUE_DECISION;
   G_SCORE_BASE = G_QUEUE_OPP_SCORE;
   G_SCORE_BONUS = 0;
   G_SCORE_PENALTY = 0;
   G_SCORE_FINAL = G_QUEUE_SCORE_FINAL;
   G_SCORE_MIN_REQUIRED = G_QUEUE_SCORE_MIN;

   // V249fix(auto-mode): a queued signal carries the bar it was authorised under. AUTO can switch
   // mode in the up-to-SignalQueueBars between saving and replaying, and the basket then FREEZES on
   // the mode live at entry - so a signal cleared at the Hunter bar of 2 could open a basket that is
   // then managed with Balanced grid geometry, on an authorisation Balanced would never have given.
   // Deliberately NOT a refusal: re-test it against the bar actually in force. A genuinely good
   // signal still trades, a marginal one that only ever cleared the looser bar does not - which is
   // the honest answer and costs nothing that deserved to be taken.
   if(NaviusMode == NAVIUS_MODE_AUTO && G_QUEUE_MODE != G_ACTIVE_MODE)
   {
      // Re-BASE, do not recompute: the stored G_QUEUE_SCORE_MIN already carries every adjustment
      // the original scan applied (regime offset, reversal-type extra, dead/range +-1, self-defence,
      // post-SL). MinScoreForContext() alone is the raw mode bar, so using it would throw all of
      // those away - loosening the test in the Balanced->Hunter direction, and corrupting the
      // margin that G_BASKET_OPENING_MARGIN and the confidence-lot span are measured against.
      // Swap only the mode component and keep the rest.
      int saved_base = (G_QUEUE_MODE == NAVIUS_MODE_HIGH_HUNTER)
                       ? (G_OPP_IS_MICRO ? MinScoreMicroHighHunter : MinScoreHighHunter)
                       : (G_OPP_IS_MICRO ? MinScoreMicroBalanced   : MinScoreBalanced);
      int replay_bar = MathMax(1, G_QUEUE_SCORE_MIN - saved_base + MinScoreForContext(G_OPP_IS_MICRO));
      G_SCORE_MIN_REQUIRED = replay_bar;
      if(G_SCORE_FINAL >= replay_bar)
      {
         G_SCORE_DECISION = (G_OPP_IS_MICRO ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS);
         G_OPP_DETAIL += StringFormat(" | mode changed %s->%s, re-tested %d/%d: still passes",
                                      ModeToString(G_QUEUE_MODE), ModeToString(G_ACTIVE_MODE),
                                      G_SCORE_FINAL, replay_bar);
      }
      else
      {
         G_SCORE_DECISION = SCORE_DECISION_WAIT;
         G_OPP_DETAIL += StringFormat(" | mode changed %s->%s, re-tested %d/%d: no longer qualifies",
                                      ModeToString(G_QUEUE_MODE), ModeToString(G_ACTIVE_MODE),
                                      G_SCORE_FINAL, replay_bar);
      }
   }
   G_SCORE_IS_MICRO = G_QUEUE_IS_MICRO;
   G_SCORE_TP_TARGET = G_QUEUE_TP_TARGET;
   G_SCORE_ROOM_POINTS = G_QUEUE_ROOM_POINTS;
   G_SCORE_HARD_BLOCK = "none";

   G_SCORE_STATUS = StringFormat("SCORE: %s | final=%d/%d | QUEUE_REPLAY",
                                 ScoreDecisionToString(G_SCORE_DECISION),
                                 G_SCORE_FINAL,
                                 G_SCORE_MIN_REQUIRED);

   G_SCORE_DETAIL = "SCORE DETAIL: replayed from queue | " + G_QUEUE_SCORE_DETAIL;

   G_QUEUE_REPLAYED = true;
   G_QUEUE_REPLAY_COUNT++;

   G_QUEUE_STATUS = StringFormat("QUEUE: REPLAYED %s %s | age=%d/%d bars",
                                 OpportunityDirToString(G_QUEUE_DIR),
                                 OpportunityTypeToString(G_QUEUE_TYPE),
                                 QueueAgeBars(),
                                 SignalQueueBars);

   G_QUEUE_DETAIL = StringFormat("QUEUE DETAIL: replay #%d | score=%d/%d | spread=%d",
                                 G_QUEUE_REPLAY_COUNT,
                                 G_QUEUE_SCORE_FINAL,
                                 G_QUEUE_SCORE_MIN,
                                 G_LAST_SPREAD_POINTS);
}

void UpdateSignalQueueEngine(const string source)
{
   if(!UseSignalQueue)
   {
      if(G_QUEUE_ACTIVE)
         ClearSignalQueue("UseSignalQueue=false");
      else
      {
         G_QUEUE_STATUS = "QUEUE: OFF";
         G_QUEUE_DETAIL = "QUEUE DETAIL: disabled";
      }
      return;
   }

   G_QUEUE_REPLAYED = false;

   if(CurrentSignalShouldBeSaved())
      SaveCurrentSignalToQueue("current score passed");

   string exp_reason = "";
   if(G_QUEUE_ACTIVE && IsQueueExpired(exp_reason))
   {
      G_QUEUE_EXPIRED_COUNT++;
      ClearSignalQueue(exp_reason);
   }

   if(G_QUEUE_ACTIVE)
   {
      if(SignalQueueExpireOnOppositePass && IsScorePassedDecision(G_SCORE_DECISION) && G_OPP_DIR != G_QUEUE_DIR && G_OPP_DIR != OPP_DIR_NONE)
      {
         G_QUEUE_EXPIRED_COUNT++;
         ClearSignalQueue("opposite passed signal invalidated queue");
      }
   }

   string replay_reason = "";
   if(G_QUEUE_ACTIVE && !IsScorePassedDecision(G_SCORE_DECISION) && QueueCanReplay(replay_reason))
   {
      ReplayQueuedSignal();
   }
   else if(G_QUEUE_ACTIVE && !G_QUEUE_REPLAYED)
   {
      G_QUEUE_STATUS = StringFormat("QUEUE: HOLD %s %s | age=%d/%d bars | reason=%s",
                                    OpportunityDirToString(G_QUEUE_DIR),
                                    OpportunityTypeToString(G_QUEUE_TYPE),
                                    QueueAgeBars(),
                                    SignalQueueBars,
                                    replay_reason);
      G_QUEUE_DETAIL = StringFormat("QUEUE DETAIL: saved score=%d/%d | savedCount=%d replay=%d expired=%d",
                                    G_QUEUE_SCORE_FINAL,
                                    G_QUEUE_SCORE_MIN,
                                    G_QUEUE_SAVED_COUNT,
                                    G_QUEUE_REPLAY_COUNT,
                                    G_QUEUE_EXPIRED_COUNT);
   }
   else if(!G_QUEUE_ACTIVE)
   {
      G_QUEUE_STATUS = "QUEUE: EMPTY | reason=" + G_QUEUE_REASON;
      G_QUEUE_DETAIL = StringFormat("QUEUE DETAIL: saved=%d replay=%d expired=%d",
                                    G_QUEUE_SAVED_COUNT,
                                    G_QUEUE_REPLAY_COUNT,
                                    G_QUEUE_EXPIRED_COUNT);
   }

   string signature = G_QUEUE_STATUS + "|" + G_QUEUE_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintQueueDecisions && signature != G_QUEUE_LAST_SIGNATURE)
   {
      if(G_QUEUE_ACTIVE || G_QUEUE_REPLAYED || G_QUEUE_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 QUEUE] %s | %s | source=%s",
                     G_QUEUE_STATUS,
                     G_QUEUE_DETAIL,
                     source);
      }
      G_QUEUE_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 21.3 MISSED TRADE MEMORY
//==================================================================//
string BuildMissedSetupSignature()
{
   return StringFormat("%s|%s|%s|%s|%s",
                       OpportunityDirToString(G_OPP_DIR),
                       OpportunityTypeToString(G_OPP_TYPE),
                       OpportunityGradeToString(G_OPP_GRADE),
                       MarketStateToString(G_MARKET_STATE),
                       ModeToString(G_ACTIVE_MODE));
}

bool ScoreDecisionPassedNow()
{
   return (G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS);
}

int ScoreGapToPass()
{
   if(G_SCORE_MIN_REQUIRED <= 0)
      return 9999;

   int gap = G_SCORE_MIN_REQUIRED - G_SCORE_FINAL;
   if(gap < 0)
      gap = 0;

   return gap;
}

bool MissedMemoryCanTrack(string &reason)
{
   if(!UseMissedTradeMemory)
   {
      reason = "UseMissedTradeMemory=false";
      return false;
   }

   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return false;
   }

   if(G_RISK_HARD_BLOCK)
   {
      reason = "risk hard block";
      return false;
   }

   if(MissedMemoryIgnoreHardBlocks && G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
   {
      reason = "score hard block ignored";
      return false;
   }

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
   {
      reason = "no opportunity direction";
      return false;
   }

   if(G_OPP_GRADE == OPP_GRADE_NONE)
   {
      reason = "no opportunity grade";
      return false;
   }

   if(ScoreDecisionPassedNow())
   {
      reason = "score already passed";
      return false;
   }

   if(G_SCORE_DECISION != SCORE_DECISION_WAIT)
   {
      reason = "score is not WAIT";
      return false;
   }

   if(MissedMemoryBoostOnlyNearPass && ScoreGapToPass() > MissedMemoryNearPassGap)
   {
      reason = StringFormat("not near pass gap=%d/%d", ScoreGapToPass(), MissedMemoryNearPassGap);
      return false;
   }

   if(G_MARKET_STATE == MARKET_CHAOS)
   {
      reason = "chaos ignored";
      return false;
   }

   reason = "trackable soft miss";
   return true;
}

void ResetMissedMemory(const string reason)
{
   G_MEMORY_REPEAT_COUNT = 0;
   G_MEMORY_SETUP_SIGNATURE = "";
   G_MEMORY_LAST_MISS_REASON = reason;
   G_MEMORY_CURRENT_BOOST = 0;
   if(G_VPS_LAST_CHECK == 0) G_VPS_STATUS = "VPS: initializing";
   if(G_VPS_LAST_CHECK == 0) G_VPS_REASON = "initial VPS validation";
   G_VPS_DETAIL = "VPS DETAIL: initializing";
   G_VPS_NO_TRADE_REASON = "NO TRADE: initializing";
   G_VPS_BROKER_DETAIL = "BROKER: initializing";
   G_VPS_LAST_SIGNATURE = "";
   // FIX(vps-timer-wipe): G_VPS_LAST_CHECK/LAST_AUDIT/LAST_BROKER_PRINT/TICK_WINDOW_START/TICK_WINDOW_COUNT/TICKS_PER_MINUTE deliberately NOT cleared here - these are UpdateVPSLiveValidation()'s own throttle timers. Zeroing them defeated VPSValidationSeconds/VPSNoTradeAuditSeconds/VPSBrokerSnapshotSeconds and reset the ticks-per-minute rolling window before it could accumulate a full period. (Same fix as the four sibling reset blocks; OnInit deliberately still clears them.)
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
   // FIX(pack3-timer-wipe): G_PACK3_LAST_DEAL_SCAN/LAST_AUDIT_PRINT deliberately NOT cleared here - Pack3ClosedDealAnalytics() throttles its deal-history rescan on them; zeroing them forced a full HistorySelect rescan on the next call.
   G_PACK3_EVENT_COUNT = 0;
   // FIX(pack3-timer-wipe): G_DEALS_* deliberately NOT cleared here - these are Pack3ClosedDealAnalytics()'s cached results, valid between its own throttled rescans; wiping them made the dashboard read 0 deals / 0% winrate until the next real rescan.
   G_BROKER_EFFECTIVE_STOP = 0.0;
   G_MEMORY_APPLIED = false;
   G_MEMORY_STATUS = "MEMORY: RESET | reason=" + reason;
   G_MEMORY_DETAIL = StringFormat("MEMORY DETAIL: totalMissed=%d boostCount=%d",
                                  G_MEMORY_TOTAL_MISSED,
                                  G_MEMORY_BOOST_COUNT);
}

void TrackMissedSetup(const string reason)
{
   string sig = BuildMissedSetupSignature();
   int bars_since = G_BARS_SEEN - G_MEMORY_LAST_BAR;

   if(sig == G_MEMORY_SETUP_SIGNATURE && bars_since <= MissedMemoryLookbackBars)
      G_MEMORY_REPEAT_COUNT++;
   else
      G_MEMORY_REPEAT_COUNT = 1;

   G_MEMORY_SETUP_SIGNATURE = sig;
   G_MEMORY_LAST_MISS_REASON = reason;
   G_MEMORY_LAST_BAR = G_BARS_SEEN;
   G_MEMORY_LAST_TIME = TimeCurrent();
   G_MEMORY_TOTAL_MISSED++;

   G_MEMORY_STATUS = StringFormat("MEMORY: TRACK %s | repeat=%d/%d | gap=%d",
                                  sig,
                                  G_MEMORY_REPEAT_COUNT,
                                  MissedMemoryRepeatThreshold,
                                  ScoreGapToPass());

   G_MEMORY_DETAIL = StringFormat("MEMORY DETAIL: final=%d/%d | reason=%s | totalMissed=%d boostCount=%d",
                                  G_SCORE_FINAL,
                                  G_SCORE_MIN_REQUIRED,
                                  reason,
                                  G_MEMORY_TOTAL_MISSED,
                                  G_MEMORY_BOOST_COUNT);
}

bool MissedMemoryCanBoost(string &reason)
{
   if(!UseMissedTradeMemory)
   {
      reason = "memory disabled";
      return false;
   }

   if(G_MEMORY_REPEAT_COUNT < MissedMemoryRepeatThreshold)
   {
      reason = StringFormat("repeat not enough %d/%d", G_MEMORY_REPEAT_COUNT, MissedMemoryRepeatThreshold);
      return false;
   }

   if(G_SCORE_DECISION != SCORE_DECISION_WAIT)
   {
      reason = "score is not WAIT";
      return false;
   }

   if(G_RISK_HARD_BLOCK || G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
   {
      reason = "hard block";
      return false;
   }

   if(G_OPP_GRADE == OPP_GRADE_C_MICRO && !MissedMemoryAllowMicroBoost)
   {
      reason = "micro boost disabled";
      return false;
   }

   int gap = ScoreGapToPass();
   if(MissedMemoryBoostOnlyNearPass && gap > MissedMemoryNearPassGap)
   {
      reason = StringFormat("gap too big %d/%d", gap, MissedMemoryNearPassGap);
      return false;
   }

   if(MissedMemoryScoreBoost <= 0)
   {
      reason = "boost value is zero";
      return false;
   }

   // V31.6z34 NEW: real philosophical conflict found via systematic audit - if the SAME reason
   // a setup keeps scoring WAIT is that today's Exhaustion Consensus or Global/Local Trend
   // Alignment correctly, repeatedly flag it as risky, "it kept almost passing" is exactly the
   // WRONG signal to reward with a forced boost - it means the sophisticated checks are doing
   // their job, not that the setup deserves a nudge. Respects their "no" as authoritative
   // rather than overriding it with repetition.
   if(MissedMemoryRespectFreshChecks)
   {
      int opp_dir_mem = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
      if(opp_dir_mem != 0)
      {
         string ec_mem_detail = "";
         double ec_mem_score = ExhaustionConsensusScore(opp_dir_mem, ec_mem_detail);
         if(ec_mem_score <= MissedMemoryExhaustionBlockThreshold)
         {
            reason = "boost blocked: fresh exhaustion consensus against - " + ec_mem_detail;
            return false;
         }

         string gla_mem_detail = "";
         double gla_mem_score = GlobalLocalAlignmentScore(opp_dir_mem, gla_mem_detail);
         if(gla_mem_score <= MissedMemoryGlobalLocalBlockThreshold)
         {
            reason = "boost blocked: fresh global/local alignment against - " + gla_mem_detail;
            return false;
         }
      }
   }

   reason = "memory boost allowed";
   return true;
}

void ApplyMissedMemoryBoost()
{
   int boost = MissedMemoryScoreBoost;
   if(MissedMemoryMaxBoost > 0)
      boost = MathMin(boost, MissedMemoryMaxBoost);

   if(boost <= 0)
      return;

   G_SCORE_BONUS += boost;
   G_SCORE_FINAL += boost;
   G_MEMORY_CURRENT_BOOST = boost;
   G_MEMORY_BOOST_COUNT++;
   G_MEMORY_APPLIED = true;

   if(G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED)
   {
      if(IsMicroOpportunity())
         G_SCORE_DECISION = SCORE_DECISION_MICRO_PASS;
      else
         G_SCORE_DECISION = SCORE_DECISION_PASS;
   }

   G_SCORE_STATUS = StringFormat("SCORE: %s | final=%d/%d | missed memory boost +%d",
                                 ScoreDecisionToString(G_SCORE_DECISION),
                                 G_SCORE_FINAL,
                                 G_SCORE_MIN_REQUIRED,
                                 boost);

   G_SCORE_DETAIL = G_SCORE_DETAIL + StringFormat(" +%d missed memory boost;", boost);

   G_MEMORY_STATUS = StringFormat("MEMORY: BOOST APPLIED +%d | repeat=%d | decision=%s",
                                  boost,
                                  G_MEMORY_REPEAT_COUNT,
                                  ScoreDecisionToString(G_SCORE_DECISION));

   G_MEMORY_DETAIL = StringFormat("MEMORY DETAIL: setup=%s | final=%d/%d | totalMissed=%d boostCount=%d",
                                  G_MEMORY_SETUP_SIGNATURE,
                                  G_SCORE_FINAL,
                                  G_SCORE_MIN_REQUIRED,
                                  G_MEMORY_TOTAL_MISSED,
                                  G_MEMORY_BOOST_COUNT);
}

void UpdateMissedTradeMemory(const string source)
{
   G_MEMORY_APPLIED = false;
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

   if(!UseMissedTradeMemory)
   {
      G_MEMORY_STATUS = "MEMORY: OFF";
      G_MEMORY_DETAIL = "MEMORY DETAIL: disabled";
      return;
   }

   if(MissedMemoryResetOnEntry && StringFind(G_ENTRY_STATUS, "SENT") >= 0)
   {
      ResetMissedMemory("entry sent");
      return;
   }

   string track_reason = "";
   if(!MissedMemoryCanTrack(track_reason))
   {
      G_MEMORY_STATUS = "MEMORY: WAIT | reason=" + track_reason;
      G_MEMORY_DETAIL = StringFormat("MEMORY DETAIL: repeat=%d totalMissed=%d boostCount=%d last=%s",
                                     G_MEMORY_REPEAT_COUNT,
                                     G_MEMORY_TOTAL_MISSED,
                                     G_MEMORY_BOOST_COUNT,
                                     G_MEMORY_LAST_MISS_REASON);
   }
   else
   {
      TrackMissedSetup(track_reason);

      string boost_reason = "";
      if(MissedMemoryCanBoost(boost_reason))
         ApplyMissedMemoryBoost();
      else
         G_MEMORY_DETAIL = G_MEMORY_DETAIL + " | boostWait=" + boost_reason;
   }

   string signature = G_MEMORY_STATUS + "|" + G_MEMORY_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintMissedMemoryEvents && signature != G_MEMORY_LAST_SIGNATURE)
   {
      if(G_MEMORY_APPLIED || G_MEMORY_REPEAT_COUNT > 0 || G_MEMORY_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 MEMORY] %s | %s | source=%s",
                     G_MEMORY_STATUS,
                     G_MEMORY_DETAIL,
                     source);
      }

      G_MEMORY_LAST_SIGNATURE = signature;
   }
}

//==================================================================//
//  PHASE 21.3 MICRO SCALP LAYER
//==================================================================//
bool IsMicroFriendlyOpportunityType()
{
   if(G_OPP_TYPE == OPP_TYPE_SWEEP_REJECTION)
      return true;
   if(G_OPP_TYPE == OPP_TYPE_RANGE_EDGE)
      return true;
   if(G_OPP_TYPE == OPP_TYPE_EXHAUSTION_REVERSAL)
      return true;
   if(G_OPP_TYPE == OPP_TYPE_NEAR_ZONE_REACTION && MicroAllowNearZoneEntry)
      return true;
   if(G_OPP_TYPE == OPP_TYPE_FAKE_BREAKOUT_RETURN)
      return true;

   return false;
}

double MicroLotFactor()
{
   double factor = (G_ACTIVE_MODE == NAVIUS_MODE_HIGH_HUNTER ? MicroLotFactorHighHunter : MicroLotFactorBalanced);
   if(factor <= 0.0)
      factor = 0.50;

   G_MICRO_LOT_FACTOR = factor;
   return factor;
}

bool MicroScalpCanRun(string &reason)
{
   G_MICRO_TP_POINTS = MicroTPPoints();
   G_MICRO_LOT_FACTOR = MicroLotFactor();

   if(!UseMicroScalpLayer)
   {
      reason = "UseMicroScalpLayer=false";
      return false;
   }

   if(G_SCORE_DECISION != SCORE_DECISION_MICRO_PASS)
   {
      reason = "score is not MICRO_PASS";
      return false;
   }

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
   {
      reason = "no micro direction";
      return false;
   }

   if(G_LAST_SPREAD_POINTS < 0)
   {
      reason = "spread unreadable";
      return false;
   }

   if(G_LAST_SPREAD_POINTS > EffSpread(MicroMaxSpreadPoints))
   {
      reason = StringFormat("micro spread high %d/%d", G_LAST_SPREAD_POINTS, EffSpread(MicroMaxSpreadPoints));
      return false;
   }

   if(MicroBlockFreshImpulse && G_MARKET_STATE == MARKET_IMPULSE)
   {
      reason = "fresh impulse risk";
      return false;
   }

   if(MicroRequireSweepOrRejection && !IsMicroFriendlyOpportunityType())
   {
      reason = "micro requires sweep/rejection/range-edge/exhaustion";
      return false;
   }

   double min_room = G_MICRO_TP_POINTS * (double)MicroMinRoomPercentOfTP / 100.0;
   if(G_SCORE_ROOM_POINTS > 0.0 && G_SCORE_ROOM_POINTS < min_room)
   {
      reason = StringFormat("micro room low %.0f/%.0f", G_SCORE_ROOM_POINTS, min_room);
      return false;
   }

   reason = StringFormat("micro ready | TP=%.0f mode=%s | lotFactor=%.2f | room=%.0f",
                         G_MICRO_TP_POINTS,
                         MicroTPModeToString(MicroTPMode),
                         G_MICRO_LOT_FACTOR,
                         G_SCORE_ROOM_POINTS);
   return true;
}

void UpdateMicroScalpLayer(const string source)
{
   string reason = "";

   if(MicroScalpCanRun(reason))
   {
      G_MICRO_READY = true;
      G_MICRO_REASON = reason;
      G_MICRO_STATUS = "MICRO: READY | " + reason;
      G_MICRO_DETAIL = StringFormat("MICRO DETAIL: opp=%s %s | score=%d/%d | TP=%.0f | spread=%d",
                                    OpportunityDirToString(G_OPP_DIR),
                                    OpportunityTypeToString(G_OPP_TYPE),
                                    G_SCORE_FINAL,
                                    G_SCORE_MIN_REQUIRED,
                                    G_MICRO_TP_POINTS,
                                    G_LAST_SPREAD_POINTS);
   }
   else
   {
      G_MICRO_READY = false;
      G_MICRO_REASON = reason;
      G_MICRO_STATUS = "MICRO: WAIT | reason=" + reason;
      G_MICRO_DETAIL = StringFormat("MICRO DETAIL: decision=%s | opp=%s %s %s | TP=%.0f | lotFactor=%.2f",
                                    ScoreDecisionToString(G_SCORE_DECISION),
                                    OpportunityGradeToString(G_OPP_GRADE),
                                    OpportunityDirToString(G_OPP_DIR),
                                    OpportunityTypeToString(G_OPP_TYPE),
                                    G_MICRO_TP_POINTS,
                                    G_MICRO_LOT_FACTOR);
   }

   string signature = G_MICRO_STATUS + "|" + G_MICRO_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintMicroDecisions && signature != G_MICRO_LAST_SIGNATURE)
   {
      if(G_MICRO_READY || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS || G_MICRO_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 MICRO] %s | %s | source=%s",
                     G_MICRO_STATUS,
                     G_MICRO_DETAIL,
                     source);
      }
      G_MICRO_LAST_SIGNATURE = signature;
   }
}



//==================================================================//
//  PHASE 21.3 RISK ENGINE FORWARD DECLARATIONS
//==================================================================//
void UpdateRiskEngine(const string source);
bool RiskAllowsNewEntry(string &reason);
bool RiskAllowsGrid(string &reason);



//==================================================================//
//  PHASE 21.3 LEGACY PACK 3 / NEWS / BROKER / ANALYTICS
//==================================================================//
int Pack3MinutesOfDay(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
}

bool Pack3ParseNewsTime(const string item, int &minutes)
{
   string s = item;
   StringTrimLeft(s);
   StringTrimRight(s);

   int p = StringFind(s, ":");
   if(p < 0)
      return false;

   string hs = StringSubstr(s, 0, p);
   string ms = StringSubstr(s, p + 1);

   int h = (int)StringToInteger(hs);
   int m = (int)StringToInteger(ms);

   if(h < 0 || h > 23 || m < 0 || m > 59)
      return false;

   minutes = h * 60 + m;
   return true;
}

bool Pack3ManualNewsActive(string &reason)
{
   reason = "manual news inactive";

   if(!NewsGuardManualSchedule)
      return false;

   if(StringLen(NewsGuardTimesCSV) <= 0)
      return false;

   string parts[];
   int n = StringSplit(NewsGuardTimesCSV, ',', parts);

   if(n <= 0)
      return false;

   int now_min = Pack3MinutesOfDay(TimeCurrent());
   int before = MathMax(0, NewsGuardMinutesBefore);
   int after  = MathMax(0, NewsGuardMinutesAfter);

   for(int i=0; i<n; i++)
   {
      int event_min = 0;
      if(!Pack3ParseNewsTime(parts[i], event_min))
         continue;

      int diff = now_min - event_min;

      // handle midnight wrap
      if(diff > 720)  diff -= 1440;
      if(diff < -720) diff += 1440;

      if(diff >= -before && diff <= after)
      {
         reason = StringFormat("manual news active %s | diff=%d min | window -%d/+%d",
                               parts[i],
                               diff,
                               before,
                               after);
         return true;
      }
   }

   return false;
}

bool Pack3NewsGuardActive(string &reason)
{
   reason = "news guard disabled";

   if(!UseLegacyPack3 || !UseNewsCalendarGuardV2)
      return false;

   string manual_reason = "";
   bool manual = Pack3ManualNewsActive(manual_reason);

   bool legacy_manual = LegacyManualNewsBlocked();

   if(manual)
   {
      reason = manual_reason;
      return true;
   }

   if(legacy_manual)
   {
      reason = "legacy manual news window";
      return true;
   }

   reason = "no news window";
   return false;
}

void Pack3UpdateNewsGuard()
{
   G_PACK3_NEWS_ACTIVE = false;
   string reason = "";

   if(Pack3NewsGuardActive(reason))
   {
      G_PACK3_NEWS_ACTIVE = true;
      G_PACK3_NEWS_UNTIL = TimeCurrent() + MathMax(NewsGuardMinutesAfter, 1) * 60;
      G_PACK3_NEWS_STATUS = "NEWS: ACTIVE | " + reason;

      if(NewsGuardCloseBasket && G_BASKET_ORDERS > 0)
      {
         if(CloseNaviusBasket("PACK3 news guard close: " + reason))
            G_PACK3_CLOSE_REQUEST = true;
      }
   }
   else if(G_PACK3_NEWS_UNTIL > TimeCurrent())
   {
      G_PACK3_NEWS_ACTIVE = true;
      G_PACK3_NEWS_STATUS = "NEWS: AFTERSHOCK until " + SafeTime(G_PACK3_NEWS_UNTIL);
   }
   else
   {
      G_PACK3_NEWS_ACTIVE = false;
      G_PACK3_NEWS_STATUS = "NEWS: CLEAR | " + reason;
   }
}

void Pack3BrokerSync()
{
   if(!UseLegacyPack3 || !UseBrokerSyncV2)
   {
      G_PACK3_BROKER_STATUS = "BROKER_SYNC: disabled";
      return;
   }

   long stop_level = 0;
   long freeze_level = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stop_level);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);

   double effective_stop = (double)MathMax((int)stop_level, (int)freeze_level);
   if(BrokerSyncMinStopLevel > 0)
      effective_stop = MathMax(effective_stop, (double)BrokerSyncMinStopLevel);

   G_BROKER_EFFECTIVE_STOP = effective_stop;

   bool spread_ok = (G_LAST_SPREAD_POINTS >= 0 && G_LAST_SPREAD_POINTS <= EffSpread(BrokerSyncMaxSpread));
   bool stop_ok = (effective_stop <= MathMax((double)GridMinDistancePoints, (double)FixedTPPoints));

   if(!spread_ok)
   {
      G_PACK3_BROKER_STATUS = StringFormat("BROKER_SYNC: spread high %d/%d | stop=%.0f",
                                           G_LAST_SPREAD_POINTS,
                                           EffSpread(BrokerSyncMaxSpread),
                                           effective_stop);
   }
   else
   {
      G_PACK3_BROKER_STATUS = StringFormat("BROKER_SYNC: OK spread=%d stop=%.0f freeze=%d",
                                           G_LAST_SPREAD_POINTS,
                                           effective_stop,
                                           (int)freeze_level);
   }

   if(!spread_ok)
   {
      G_PACK3_ENTRY_BLOCK = true;
      G_PACK3_GRID_BLOCK = true;
   }

   if(!stop_ok && BrokerSyncBlockBadFilling)
   {
      G_PACK3_ENTRY_BLOCK = true;
      G_PACK3_GRID_BLOCK = true;
   }
}

double Pack3AdaptTPPoints(const double original_tp)
{
   if(!UseLegacyPack3 || !UseBrokerSyncV2 || !BrokerSyncAdaptTPToStop)
      return original_tp;

   double min_tp = G_BROKER_EFFECTIVE_STOP + MathMax(200.0, (double)G_LAST_SPREAD_POINTS * 3.0);
   if(min_tp <= 0.0)
      return original_tp;

   return MathMax(original_tp, min_tp);
}

double Pack3AdaptGridDistance(const double original_distance)
{
   if(!UseLegacyPack3 || !UseBrokerSyncV2 || !BrokerSyncAdaptGridToStop)
      return original_distance;

   double min_grid = G_BROKER_EFFECTIVE_STOP + MathMax(300.0, (double)G_LAST_SPREAD_POINTS * 5.0);
   if(min_grid <= 0.0)
      return original_distance;

   return MathMax(original_distance, min_grid);
}

void Pack3ClosedDealAnalytics()
{
   if(!UseLegacyPack3 || !UseClosedDealAnalytics)
   {
      G_PACK3_DEAL_STATUS = "DEALS: disabled";
      return;
   }

   datetime now = TimeCurrent();
   if(G_PACK3_LAST_DEAL_SCAN > 0 && (now - G_PACK3_LAST_DEAL_SCAN) < ClosedDealRefreshSeconds)
      return;

   G_PACK3_LAST_DEAL_SCAN = now;

   datetime from = TimeCurrent() - ClosedDealLookbackDays * 86400;
   datetime to = TimeCurrent();

   G_DEALS_TOTAL = 0;
   G_DEALS_WINS = 0;
   G_DEALS_LOSSES = 0;
   G_DEALS_NET_PROFIT = 0.0;
   G_DEALS_GROSS_PROFIT = 0.0;
   G_DEALS_GROSS_LOSS = 0.0;
   G_DEALS_WINRATE = 0.0;

   if(!HistorySelect(from, to))
   {
      G_PACK3_DEAL_STATUS = "DEALS: HistorySelect failed";
      return;
   }

   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
      long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);

      if(sym != _Symbol || magic != MagicNumber)
         continue;

      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(deal, DEAL_SWAP)
                    + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      G_DEALS_TOTAL++;
      G_DEALS_NET_PROFIT += profit;

      // FIX(breakeven-counted-as-win): an exact break-even close (profit == 0.0, e.g. from
      // UseBasketBreakEvenLock) used to be counted as a WIN (`profit >= 0.0`), inflating
      // G_DEALS_WINRATE. It still counts toward G_DEALS_TOTAL (and so correctly dilutes the win
      // rate), it just no longer inflates the win side.
      if(profit > 0.0)
      {
         G_DEALS_WINS++;
         G_DEALS_GROSS_PROFIT += profit;
      }
      else if(IsMeaningfulLoss(profit))   // BOSQICH 1
      {
         G_DEALS_LOSSES++;
         G_DEALS_GROSS_LOSS += MathAbs(profit);
      }
   }

   if(G_DEALS_TOTAL > 0)
      G_DEALS_WINRATE = (double)G_DEALS_WINS / (double)G_DEALS_TOTAL * 100.0;

   G_PACK3_DEAL_STATUS = StringFormat("DEALS: %dd total=%d W=%d L=%d WR=%.1f%% net=%.2f GP=%.2f GL=%.2f",
                                      ClosedDealLookbackDays,
                                      G_DEALS_TOTAL,
                                      G_DEALS_WINS,
                                      G_DEALS_LOSSES,
                                      G_DEALS_WINRATE,
                                      G_DEALS_NET_PROFIT,
                                      G_DEALS_GROSS_PROFIT,
                                      G_DEALS_GROSS_LOSS);
}

void Pack3ServerDisasterSL()
{
   if(!UseLegacyPack3 || !UseServerDisasterSL)
      return;

   if(ServerDisasterDDPercent <= 0.0)
      return;

   if(G_RISK_EQUITY_DD_PCT >= ServerDisasterDDPercent)
   {
      G_PACK3_HARD_BLOCK = true;
      G_PACK3_REASON = StringFormat("SERVER DISASTER DD %.2f/%.2f%%",
                                    G_RISK_EQUITY_DD_PCT,
                                    ServerDisasterDDPercent);

      if(ServerDisasterCloseBasket && G_BASKET_ORDERS > 0)
      {
         CloseNaviusBasket("PACK3 server disaster SL");
         G_PACK3_CLOSE_REQUEST = true;
      }
   }
}

void Pack3ClientAudit()
{
   if(!UseLegacyPack3 || !UseClientAuditSummary)
   {
      G_PACK3_AUDIT_STATUS = "CLIENT_AUDIT: disabled";
      return;
   }

   G_PACK3_AUDIT_STATUS = StringFormat("CLIENT_AUDIT: %s | %s | %s | basket=%d DD=%.2f%% | deals WR=%.1f%% net=%.2f",
                                       G_ENV_STATUS,
                                       G_RISK_STATUS,
                                       G_VPS_STATUS,
                                       G_BASKET_ORDERS,
                                       G_RISK_EQUITY_DD_PCT,
                                       G_DEALS_WINRATE,
                                       G_DEALS_NET_PROFIT);

   datetime now = TimeCurrent();
   if(ClientAuditPrintSeconds > 0 && (G_PACK3_LAST_AUDIT_PRINT <= 0 || (now - G_PACK3_LAST_AUDIT_PRINT) >= ClientAuditPrintSeconds))
   {
      G_PACK3_LAST_AUDIT_PRINT = now;
      PrintFormat("[SIRUS v31.6 PHASE 21.3 CLIENT AUDIT] %s | %s | %s",
                  G_PACK3_AUDIT_STATUS,
                  G_PACK3_BROKER_STATUS,
                  G_PACK3_DEAL_STATUS);
   }
}

void UpdateLegacyPack3(const string source)
{
   G_PACK3_HARD_BLOCK = false;
   G_PACK3_ENTRY_BLOCK = false;
   G_PACK3_GRID_BLOCK = false;
   G_PACK3_CLOSE_REQUEST = false;

   if(!UseLegacyPack3)
   {
      G_PACK3_STATUS = "PACK3: OFF";
      G_PACK3_DETAIL = "PACK3 DETAIL: disabled";
      return;
   }

   Pack3UpdateNewsGuard();
   Pack3BrokerSync();
   Pack3ClosedDealAnalytics();
   Pack3ServerDisasterSL();
   WeekendGuardManage();   // V30.4
   RebateTimeFlatManage(); // BOSQICH 17
   Pack3ClientAudit();

   if(G_PACK3_NEWS_ACTIVE)
   {
      if(NewsGuardBlockEntry)
         G_PACK3_ENTRY_BLOCK = true;
      if(NewsGuardBlockGrid)
         G_PACK3_GRID_BLOCK = true;
   }

   G_PACK3_STATUS = StringFormat("PACK3: news=%s entryBlock=%s gridBlock=%s hard=%s",
                                 BoolText(G_PACK3_NEWS_ACTIVE),
                                 BoolText(G_PACK3_ENTRY_BLOCK),
                                 BoolText(G_PACK3_GRID_BLOCK),
                                 BoolText(G_PACK3_HARD_BLOCK));

   G_PACK3_DETAIL = G_PACK3_NEWS_STATUS + " | " + G_PACK3_BROKER_STATUS + " | " + G_PACK3_DEAL_STATUS;

   string signature = G_PACK3_STATUS + "|" + G_PACK3_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintLegacyPack3Events && signature != G_PACK3_LAST_SIGNATURE)
   {
      if(G_PACK3_ENTRY_BLOCK || G_PACK3_GRID_BLOCK || G_PACK3_HARD_BLOCK || G_PACK3_LAST_SIGNATURE == "")
      {
         G_PACK3_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 21.3 PACK3] %s | %s | audit=%s | source=%s",
                     G_PACK3_STATUS,
                     G_PACK3_DETAIL,
                     G_PACK3_AUDIT_STATUS,
                     source);
      }
      G_PACK3_LAST_SIGNATURE = signature;
   }
}

bool Pack3AllowsEntry(string &reason)
{
   if(!UseLegacyPack3)
   {
      reason = "pack3 entry pass";
      return true;
   }

   if(G_PACK3_HARD_BLOCK)
   {
      reason = "pack3 hard block: " + G_PACK3_REASON;
      return false;
   }

   if(G_PACK3_ENTRY_BLOCK)
   {
      reason = "pack3 entry block: " + G_PACK3_STATUS;
      return false;
   }

   reason = "pack3 entry pass";
   return true;
}

bool Pack3AllowsGrid(string &reason)
{
   if(!UseLegacyPack3)
   {
      reason = "pack3 grid pass";
      return true;
   }

   if(G_PACK3_HARD_BLOCK)
   {
      reason = "pack3 hard block: " + G_PACK3_REASON;
      return false;
   }

   if(G_PACK3_GRID_BLOCK)
   {
      reason = "pack3 grid block: " + G_PACK3_STATUS;
      return false;
   }

   reason = "pack3 grid pass";
   return true;
}

//==================================================================//
//  PHASE 21.3 LEGACY PACK 2 / TP CHAIN / ADVANCED RECOVERY
//==================================================================//
double Pack2BasketTPForOrders(const int orders, const double base_tp)
{
   if(!UseLegacyPack2 || !UseTPChainLegacy)
      return base_tp;

   double tp = base_tp;

   if(orders >= 5)
      tp = base_tp * (double)TPChainOrder5Percent / 100.0;
   else if(orders >= 3)
      tp = base_tp * (double)TPChainOrder3Percent / 100.0;
   else if(orders >= 2)
      tp = base_tp * (double)TPChainOrder2Percent / 100.0;

   if(tp < TPChainMinPoints)
      tp = (double)TPChainMinPoints;

   // V283: the basket floor is bypassed in rebate mode for the same reason as the first-entry one -
   // 1200 points is twelve times the target this mode exists to reach.
   if(!EnableRebateMode && tp < BasketTPMinPoints)
      tp = (double)BasketTPMinPoints;

   // V156: the regime sets how far a target can reasonably reach. A trend supports a wider one; a
   // range stalls before it; a quiet market may not travel that far at all. Applied before the
   // contextual and structural adjustments below, which then work from a regime-appropriate base.
   // V224: a counter-structure trade is trying to reach the price where the structure ends. That is
   // a specific number the EA computes every bar, and it is a better target than an estimate - the
   // trade either gets there, in which case the structure is over, or it does not.
   // V228: same correction for the structure target - the price at which the structure ends does not
   // move because an order was added.
   if(EnableStructureTarget && _Point > 0.0 &&
      (G_BASKET_ORDERS <= 0 || SituationPlanAppliesToGrid))
   {
      LocalStructureUpdate();
      // FIX(tp-dir-no-basket): G_BASKET_DIRECTION is -1 with no basket and -2 when mixed, and
      // POSITION_TYPE_BUY is 0 - so the old two-way form silently classified BOTH of those as
      // SELL, and this block then measured a first entry's structure target downward regardless of
      // which way the trade actually pointed. Harmless while the result had MathAbs applied; not
      // harmless now that the measurement below is signed against tp_dir. Three-way, and the block
      // is skipped entirely when there is no single-direction basket to measure for.
      int tp_dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1
                 : ((G_BASKET_DIRECTION == POSITION_TYPE_SELL) ? -1 : 0);

      if(tp_dir != 0 && G_LS_DIR != 0 && G_LS_DIR == -tp_dir && G_LS_INVALIDATE > 0.0 &&
         G_LS_STATE != LSTRUCT_CHOPPY)
      {
         double st_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double st_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double st_mid = (st_bid > 0.0 && st_ask > 0.0) ? (st_bid + st_ask) / 2.0 : st_bid;

         if(st_mid > 0.0)
         {
            // FIX(tp-anchor-vs-current-price): same anchor correction as SituationTargetPoints().
            // The value assigned to `tp` below is compared against CurrentBasketPoints(dir, avg),
            // so it has to be measured from the basket average, not from current price - otherwise
            // it grew as the basket sank. Signed, so a structure end already behind the basket is
            // rejected instead of coming back as a large positive target.
            double st_anchor = (G_BASKET_ORDERS > 0 && G_BASKET_AVG_PRICE > 0.0)
                               ? G_BASKET_AVG_PRICE : st_mid;
            double st_pts = (G_LS_INVALIDATE - st_anchor) * (double)tp_dir / _Point;
            if(st_pts <= 0.0)
               st_pts = 0.0;      // the range test below rejects it
            st_pts *= MathMax(0.5, MathMin(1.0, StructureTargetReachFactor));

            if(st_pts >= (double)SituationTargetMinPoints &&
               st_pts <= (double)SituationTargetMaxPoints)
            {
               if((StructureTargetPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v224 TARGET] structure ends at %.2f -> %.0f pts (was %.0f)",
                              G_LS_INVALIDATE, st_pts, tp);
               tp = st_pts;

               if(tp < BasketTPMinPoints)
                  tp = (double)BasketTPMinPoints;
               return tp;
            }
         }
      }
   }

   // V220: if the situation knows where price is going, that is the target. The adjustments below
   // scale a GUESS by session, regime and noise - reasonable when there is nothing better, and
   // pointless when the destination is a known price. A range edge rejected has its opposite edge
   // sitting at a specific number; estimating $2.50 and then multiplying it by 0.75 for Asia is
   // working around information already in hand.
   // V228: this now applies to a running ladder too, not only the first entry. The original guard
   // meant a basket got its situation target once and then fell back to the estimate chain for every
   // addition - so the target moved further away with each rung, in a direction nothing had measured.
   // The destination does not change because the ladder grew; only the average entry does.
   // FIX(tp-situation-dir-mismatch): G_SITUATION_DIR is set by the ENTRY scanner and describes the
   // setup it is currently looking at - it has nothing to do with the direction of the basket that
   // is already open. Unchecked, a bullish reading taken while a SELL basket was running handed that
   // basket a target measured the wrong way: the EA widened a losing basket's exit precisely
   // because the market had just told it price was going the other way. The sibling consumer at the
   // situation-plan guard already compares the two (G_SITUATION_DIR == -basket_dir), which is proof
   // they can and do differ. With no basket open there is nothing to match, so the first-entry use
   // is unaffected.
   int sp_bdir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1
               : ((G_BASKET_DIRECTION == POSITION_TYPE_SELL) ? -1 : 0);
   if(EnableSituationPlan && G_SITUATION != SIT_NONE && G_SITUATION_DIR != 0 &&
      (G_BASKET_ORDERS <= 0 || (SituationPlanAppliesToGrid && G_SITUATION_DIR == sp_bdir)))
   {
      string sp_detail = "";
      double sp_pts = SituationTargetPoints(G_SITUATION, G_SITUATION_DIR, sp_detail);
      if(sp_pts > 0.0)
      {
         if((SituationPlanPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v220 PLAN] %s -> %s (%.0f pts, was %.0f)",
                        SituationName(G_SITUATION), sp_detail, sp_pts, tp);
         tp = sp_pts;

         // The carry floor below still applies - a target that cannot cover what the basket has
         // already paid is not a target - but the session/regime/noise scaling does not, because
         // it exists to adjust an estimate and this is not one.
         if(EnableCarryCostAdjust)
         {
            double sp_carry = BasketCarryCostPoints();
            if(sp_carry > 0.0)
            {
               double sp_floor = sp_carry + MathMax(0.0, CarryCostMinProfitPoints);
               if(tp < sp_floor)
                  tp = sp_floor;
            }
         }
         if(tp < BasketTPMinPoints)
            tp = (double)BasketTPMinPoints;

         return tp;
      }
   }

   // V170: the five conditional adjustments below are COMBINED before any limit is applied.
   //
   // Applying them one at a time was wrong in both directions. Downward, each step clamped at
   // BasketTPMinPoints, so the first factor to reach the floor silenced every factor after it -
   // in an Asian session the regime, noise and health readings had no effect whatsoever, because
   // session alone had already bottomed out the target. Upward there was no clamp at all, so an
   // overlap trending market multiplied 1.20 by 1.25 and produced a $3.75 target on a scalper
   // configured for $2.50.
   //
   // Multiplying the factors together and clamping once fixes both: every reading contributes in
   // proportion to what it is actually saying, and the result stays inside a range this strategy
   // can work with.
   double tp_factor = 1.0;
   string tp_why = "";

   // V182: the same warning weight also shortens the target. A trade taken despite several cautions
   // is a trade with less room to be right in - asking it for the full move as well is asking twice.
   if(EnableWarningTPScaling && G_PENALTY_RAW > 0 && G_BASKET_ORDERS <= 0)
   {
      double wt_span = MathMax(1.0, (double)WarningLotFullPenalty);
      double wt_t = MathMax(0.0, MathMin(1.0, (double)G_PENALTY_RAW / wt_span));
      double f_wtp = 1.0 - (1.0 - WarningTPMinFactor) * wt_t;
      tp_factor *= f_wtp;
      if(f_wtp < 0.999) tp_why += StringFormat("warnings(%d) x%.2f ", G_PENALTY_RAW, f_wtp);
   }

   if(EnableSessionContext)
   {
      int sess_mins = 0;
      string sess_detail = "";
      int sess_now = SessionContext(sess_mins, sess_detail);
      double f = SessionTPFactor(sess_now);
      if(f > 0.0) { tp_factor *= f; if(MathAbs(f - 1.0) > 0.001) tp_why += StringFormat("session x%.2f ", f); }
   }

   double f_regime = RegimeTPFactor();
   if(f_regime > 0.0) { tp_factor *= f_regime; if(MathAbs(f_regime - 1.0) > 0.001) tp_why += StringFormat("regime x%.2f ", f_regime); }

   if(EnableNoiseFilter && G_NOISE_TP_FACTOR > 0.0)
   {
      tp_factor *= G_NOISE_TP_FACTOR;
      if(G_NOISE_TP_FACTOR < 0.999) tp_why += StringFormat("noise x%.2f ", G_NOISE_TP_FACTOR);
   }

   double f_health = BasketHealthTPFactor();
   if(f_health > 0.0) { tp_factor *= f_health; if(f_health < 0.999) tp_why += StringFormat("health x%.2f ", f_health); }

   // Bounded so no combination of conditions can turn a $2.50 scalper into something else.
   tp_factor = MathMax(TPFactorMin, MathMin(TPFactorMax, tp_factor));

   if(MathAbs(tp_factor - 1.0) > 0.001)
   {
      double adjusted = tp * tp_factor;
      if(adjusted < BasketTPMinPoints)
         adjusted = (double)BasketTPMinPoints;
      if((TPAdjustPrintOnUse && VerboseLogs) && MathAbs(adjusted - tp) > 50.0)
         PrintFormat("[SIRUS v170 TP] %.0f -> %.0f (x%.2f: %s)", tp, adjusted, tp_factor, tp_why);
      tp = adjusted;
   }

   // Carry runs last and can only raise the target: whatever the adjustments above decided, it must
   // still clear what this basket has already paid in swap - otherwise "take profit" closes for a
   // loss while reporting a win.
   if(EnableCarryCostAdjust)
   {
      double carry_pts = BasketCarryCostPoints();
      if(carry_pts > 0.0)
      {
         double floor_tp = carry_pts + MathMax(0.0, CarryCostMinProfitPoints);
         if(tp < floor_tp)
            tp = floor_tp;
      }
   }

   return tp;
}

bool Pack2IsAftershockActive()
{
   if(!UseLegacyPack2 || !UseAftershockGuard)
      return false;

   if(G_AFTERSHOCK_UNTIL <= 0)
      return false;

   return (TimeCurrent() < G_AFTERSHOCK_UNTIL);
}

void Pack2UpdateAftershockWindow()
{
   if(!UseLegacyPack2 || !UseAftershockGuard)
      return;

   if(LegacyManualNewsBlocked())
      G_AFTERSHOCK_UNTIL = TimeCurrent() + AftershockMinutes * 60;
}

double Pack2GridDistanceAdjust(const double original_distance)
{
   if(!UseLegacyPack2)
      return original_distance;

   double dist = original_distance;

   if(RecoveryStretchGridOnDD && G_BASKET_DD_PERCENT >= RecoveryDDStretchStart)
      dist *= RecoveryDDStretchMult;

   G_PACK2_DYNAMIC_GRID = dist;
   return dist;
}

bool Pack2RecoveryAllowsGrid(string &reason)
{
   if(!UseLegacyPack2 || !UseRecoverySafeModeV2)
   {
      reason = "pack2 recovery pass";
      return true;
   }

   if(Pack2IsAftershockActive())
   {
      reason = "aftershock guard until " + SafeTime(G_AFTERSHOCK_UNTIL);
      return false;
   }

   if(G_LAST_SPREAD_POINTS > EffSpread(AftershockMaxSpread) && UseAftershockGuard)
   {
      reason = StringFormat("aftershock/spread guard %d/%d", G_LAST_SPREAD_POINTS, EffSpread(AftershockMaxSpread));
      return false;
   }

   if(G_BASKET_ORDERS >= RecoverySafeStartOrder && RecoveryMaxDDForNewGrid > 0.0 && G_BASKET_DD_PERCENT >= RecoveryMaxDDForNewGrid)
   {
      reason = StringFormat("recovery DD too high %.2f/%.2f", G_BASKET_DD_PERCENT, RecoveryMaxDDForNewGrid);
      return false;
   }

   // FIX(szr-unreachable): this counter-trend check DUPLICATES the "HTF/structure against" reason
   // inside GridSafetyDangerNow() further down GridCanOpen() - but that later gate has a carefully
   // built one-shot exception (Smart Zone Recovery: price must have reached a real wall, not blown
   // through it, with a rejection candle and an order-flow veto, at a reduced lot). Because THIS
   // check runs first and has no exception, it returned false before SZR was ever evaluated - so
   // SZR was effectively dead in exactly the scenario it was designed for. When SZR is enabled and
   // its one-shot is still available, defer: skip the block here and let the SZR-aware gate decide.
   // Protection is NOT lost - if SZR's strict conditions fail, that gate still blocks the add.
   bool szr_may_rescue = (EnableSmartZoneRecovery &&
                          (SZRMaxUsesPerEpisode <= 0 || G_SZR_USES_THIS_EPISODE < SZRMaxUsesPerEpisode));

   if(RecoveryBlockAgainstHTF && !szr_may_rescue &&
      G_BASKET_DIRECTION == POSITION_TYPE_BUY && G_MARKET_STATE == MARKET_TREND_DOWN)
   {
      reason = "recovery buy blocked by HTF downtrend";
      return false;
   }

   if(RecoveryBlockAgainstHTF && !szr_may_rescue &&
      G_BASKET_DIRECTION == POSITION_TYPE_SELL && G_MARKET_STATE == MARKET_TREND_UP)
   {
      reason = "recovery sell blocked by HTF uptrend";
      return false;
   }

   reason = "pack2 recovery pass";
   return true;
}

// V31.6z11 NEW: SMART TRAIL ACCELERATION. Every other sense built today reaches entry and
// grid decisions, but exit/trailing stayed purely mechanical - a fixed follow distance no
// matter what's happening. This computes an EFFECTIVE trail step: starts at the normal
// BasketTrailStepPoints, and tightens toward SmartTrailMinStepPoints as our existing senses
// (Trend Reversal, Recent Zone Break, Impulse, Trend Quality) show warning signs against the
// basket's own direction - locking in profit faster instead of blindly giving back the full
// step while conditions are visibly deteriorating. Does NOT change when trailing arms.
int SmartTrailEffectiveStep()
{
   if(!EnableSmartTrailTightening || G_BASKET_ORDERS <= 0 ||
      (G_BASKET_DIRECTION != POSITION_TYPE_BUY && G_BASKET_DIRECTION != POSITION_TYPE_SELL))
      return BasketTrailStepPoints;

   int dir_i = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
   double warnings = 0.0;
   string reasons = "";

   string rev_reason = "";
   bool rev_div = false;
   int rev_dir = TrendReversalDirection(rev_reason, rev_div);
   if(rev_dir == -dir_i)
   {
      warnings += 1.0;
      reasons += "reversal ";
   }

   string zb_detail = "";
   int zb_dir = RecentZoneBreakDirection(zb_detail);
   if(zb_dir == -dir_i)
   {
      warnings += 1.0;
      reasons += "zonebreak ";
   }

   // V31.6z39 fix: same binary-vs-magnitude gap found throughout the session - these three
   // checks all produce a genuine continuous 0-1 score, but only their threshold-crossing was
   // counted (+1 flat) regardless of HOW FAR past the threshold they were. A score of 0.29 and
   // a score of 0.02 both just barely/hugely qualify for "impulse warning" - treating them
   // identically loses real information about just how urgent the tightening should be.
   string imp_detail = "";
   double imp_score = ImpulseConfirmation(dir_i, imp_detail);
   if(imp_score <= 0.3)
   {
      warnings += MathMax(0.5, MathMin(1.5, 0.5 + (0.3 - imp_score) / 0.3));
      reasons += "impulse ";
   }

   string tq_detail = "";
   double tq_score = TrendQualityScore(dir_i, tq_detail);
   if(tq_score <= 0.35)
   {
      warnings += MathMax(0.5, MathMin(1.5, 0.5 + (0.35 - tq_score) / 0.35));
      reasons += "trendquality ";
   }

   string iew_detail = "";
   double iew_score = ImpulseExhaustionWarning(dir_i, iew_detail);
   if(iew_score <= 0.3)
   {
      warnings += MathMax(0.5, MathMin(1.5, 0.5 + (0.3 - iew_score) / 0.3));
      reasons += "exhaustion ";
   }

   // V31.6z22 UPGRADE: the unified, non-linear Exhaustion Consensus (ADX slope, RSI cooling,
   // candle exhaustion, DXY deceleration, basket DD acceleration all agreeing) is inherently
   // stronger evidence than any single check above - let it count as MORE than one warning
   // when multiple underlying signals are firing together, not just a flat +1.
   string ec_detail = "";
   double ec_score = ExhaustionConsensusScore(dir_i, ec_detail);
   if(ec_score <= 0.20)
   {
      warnings += 2.0;
      reasons += "EXHAUSTION-CONSENSUS ";
   }
   else if(ec_score <= 0.35)
   {
      warnings += 1.0;
      reasons += "exhaustion-consensus ";
   }

   if(warnings <= 0.0)
      return BasketTrailStepPoints;

   int need = MathMax(1, SmartTrailWarningsForMaxTighten);
   double frac = MathMin(1.0, warnings / (double)need);
   int step = (int)MathRound(BasketTrailStepPoints - frac * (BasketTrailStepPoints - SmartTrailMinStepPoints));
   step = MathMax(SmartTrailMinStepPoints, MathMin(BasketTrailStepPoints, step));

   if((SmartTrailPrintOnUse && VerboseLogs) && warnings > 0)
      PrintFormat("[SIRUS v31.6z11 SMART TRAIL] dir=%d warnings=%.2f (%s) step %d -> %d",
                  dir_i, warnings, reasons, BasketTrailStepPoints, step);

   return step;
}

bool Pack2CheckBasketBreakEvenOrTrail()
{
   if(!UseLegacyPack2)
      return false;

   if(G_BASKET_ORDERS <= 0)
   {
      G_BASKET_TRAIL_ACTIVE = false;
      G_BASKET_TRAIL_PEAK = 0.0;
      G_BASKET_TRAIL_LOCK = 0.0;
      G_BASKET_BE_ACTIVE = false;
      return false;
   }

   bool closed = false;

   // V31.6z63 fix: latent logic bug found via audit - the BE lock could NEVER fire. The close
   // check lived INSIDE the arming check, requiring points >= BasketBEStartPoints (1500) AND
   // points <= BasketBEPlusPoints (1000) simultaneously - mathematically impossible. The clear
   // intent is: arm once profit reaches BEStart, then close if profit later FALLS BACK to
   // BEPlus, locking a smaller but real gain. But by the time profit fell back to 1000, the
   // outer >= 1500 test was already false, so the inner check never ran. Dormant so far only
   // because UseBasketBreakEvenLock defaults to false - it would have silently done nothing the
   // moment anyone switched it on. The arming state must persist across ticks for this to work.
   if(UseBasketBreakEvenLock)
   {
      if(G_BASKET_POINTS >= BasketBEStartPoints)
         G_BASKET_BE_ACTIVE = true;

      if(G_BASKET_BE_ACTIVE && G_BASKET_POINTS > 0.0 && G_BASKET_POINTS <= BasketBEPlusPoints)
      {
         closed = CloseNaviusBasket(StringFormat("Pack2 Basket BE lock %.0f <= +%.0f (armed at %.0f)",
                                                 G_BASKET_POINTS, (double)BasketBEPlusPoints, (double)BasketBEStartPoints));
         if(closed)
            G_PACK2_TRAIL_CLOSES++;
         return closed;
      }
   }

   // V31.6z64 fix: real structural gap found via audit of the exit path. Trailing runs BEFORE
   // the TP check each tick, and arms at a FIXED BasketTrailStartPoints (2300). But TP is not
   // fixed - BasketTPForOrderCount cuts it as the basket deepens (x0.75 at 3+ orders, x0.60 at
   // 5+, floored at BasketTPMinPoints = 2000). So for any basket with 3+ orders - i.e. every
   // basket that actually needed grid rescue - TP (2000) fires BELOW the trail arm point
   // (2300), and trailing NEVER engages at all. The dangerous case: a deep basket claws back to
   // +1900, one step short of TP, then reverses all the way down - with no trailing armed,
   // nothing captured any of it. Arming relative to each basket's OWN target instead of a fixed
   // number gives every basket proportional protection.
   double effective_trail_start = (double)BasketTrailStartPoints;

   if(EnableAdaptiveTrailArm)
   {
      // Compute this basket's TP directly rather than reading G_PACK2_DYNAMIC_TP: trailing runs
      // BEFORE the TP engine every tick, so the cached global would hold last tick's value - or,
      // right after a basket opens, a stale value left over from the previous basket entirely.
      double basket_tp = BasketTPForOrderCount(G_BASKET_ORDERS);

      // Deliberately surgical: only override when the fixed arm point is UNREACHABLE (at or
      // above this basket's TP, so TP would always fire first and trailing could never engage).
      // Where the tuned fixed value already works - shallow baskets, or any basket whose TP was
      // extended by TP Intelligence - it is left completely untouched.
      if(basket_tp > 0.0 && effective_trail_start >= basket_tp)
      {
         effective_trail_start = basket_tp * MathMax(0.1, MathMin(0.95, AdaptiveTrailArmTPFraction));

         if((SmartTrailPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6z64 ADAPTIVE TRAIL ARM] fixed arm %d >= basket TP %.0f (orders=%d) - trailing could never engage; arming at %.0f instead",
                        BasketTrailStartPoints, basket_tp, G_BASKET_ORDERS, effective_trail_start);
      }
   }

   if(UseAdvancedBasketTrailing && !(EnableRebateMode && RebateDisableTrailing) && !RebateTrailingOn() &&
      G_BASKET_POINTS >= effective_trail_start)
   {
      int smart_step = SmartTrailEffectiveStep();

      // The lock floor must sit below the arm point, or the basket would close instantly on the
      // very tick trailing arms. Scales with the arm point rather than a fixed 2000.
      double lock_floor = MathMin((double)BasketTrailLockPoints, effective_trail_start - smart_step);
      lock_floor = MathMax(0.0, lock_floor);

      if(!G_BASKET_TRAIL_ACTIVE)
      {
         G_BASKET_TRAIL_ACTIVE = true;
         G_BASKET_TRAIL_PEAK = G_BASKET_POINTS;
         G_BASKET_TRAIL_LOCK = MathMax(lock_floor, G_BASKET_POINTS - smart_step);
      }

      // FIX(trail-lock-moves-backwards): smart_step is recomputed every tick and widens again as
      // warnings clear, so on a tick where a NEW PEAK coincided with a widened step the recomputed
      // lock came out LOWER than the one already banked - the trail gave back profit while the
      // basket was still making highs. (Peak 2400 -> lock 2300; peak 2450 -> lock 2350; warnings
      // clear, step 100 -> 300, peak 2460 -> lock 2160.) A trail must never move backwards.
      if(G_BASKET_POINTS > G_BASKET_TRAIL_PEAK)
      {
         G_BASKET_TRAIL_PEAK = G_BASKET_POINTS;
         double want_lock = MathMax(lock_floor, G_BASKET_TRAIL_PEAK - smart_step);
         if(want_lock > G_BASKET_TRAIL_LOCK)
            G_BASKET_TRAIL_LOCK = want_lock;
      }
      else
      {
         // A TIGHTENED step should still be allowed to RAISE the lock on a flat tick - but never
         // to a level at or above the current result, which would close the basket immediately.
         double want_lock = MathMax(lock_floor, G_BASKET_TRAIL_PEAK - smart_step);
         if(want_lock > G_BASKET_TRAIL_LOCK && want_lock < G_BASKET_POINTS)
            G_BASKET_TRAIL_LOCK = want_lock;
      }

      if(G_BASKET_POINTS <= G_BASKET_TRAIL_LOCK)
      {
         closed = CloseNaviusBasket(StringFormat("Pack2 Basket trailing lock %.0f <= %.0f peak %.0f (armed at %.0f)",
                                                 G_BASKET_POINTS,
                                                 G_BASKET_TRAIL_LOCK,
                                                 G_BASKET_TRAIL_PEAK,
                                                 effective_trail_start));
         if(closed)
            G_PACK2_TRAIL_CLOSES++;
         return closed;
      }
   }

   return false;
}

void UpdateLegacyPack2(const string source)
{
   G_PACK2_APPLIED = false;

   if(!UseLegacyPack2)
   {
      G_PACK2_STATUS = "PACK2: OFF";
      G_PACK2_DETAIL = "PACK2 DETAIL: disabled";
      return;
   }

   Pack2UpdateAftershockWindow();

   if(G_BASKET_ORDERS <= 0)
   {
      G_BASKET_TRAIL_ACTIVE = false;
      G_BASKET_TRAIL_PEAK = 0.0;
      G_BASKET_TRAIL_LOCK = 0.0;
      G_BASKET_BE_ACTIVE = false;
   }

   // FIX(dynamic-tp-two-writers): this used to call Pack2BasketTPForOrders(orders, BaseBasketTPPoints())
   // directly, which skips the depth reduction (x0.75 / x0.60 as the ladder grows) and the TP
   // Intelligence stage that BasketTPForOrderCount() applies afterwards. Since UpdateLegacyPack2()
   // runs LATE in CoreUpdate, that wider, un-reduced number then overwrote the real one for the rest
   // of the tick - and BasketReachability() / ReachAfterNextRung(), which gate further grid
   // additions, both read this global. They were measuring the road to a target up to 1300 points
   // further away than the one the exit actually uses, and blocking additions on that basis.
   // BasketTPForOrderCount() is the single authoritative producer and sets this global itself.
   G_PACK2_DYNAMIC_TP = BasketTPForOrderCount(G_BASKET_ORDERS);

   bool trail_closed = Pack2CheckBasketBreakEvenOrTrail();
   if(trail_closed)
      G_PACK2_APPLIED = true;

   G_PACK2_REASON = StringFormat("tp=%.0f trail=%s peak=%.0f lock=%.0f BE=%s aftershock=%s",
                                 G_PACK2_DYNAMIC_TP,
                                 BoolText(G_BASKET_TRAIL_ACTIVE),
                                 G_BASKET_TRAIL_PEAK,
                                 G_BASKET_TRAIL_LOCK,
                                 BoolText(G_BASKET_BE_ACTIVE),
                                 SafeTime(G_AFTERSHOCK_UNTIL));

   G_PACK2_STATUS = "PACK2: " + G_PACK2_REASON;
   G_PACK2_DETAIL = StringFormat("PACK2 DETAIL: closes=%d dynamicGrid=%.0f DD=%.2f orders=%d",
                                 G_PACK2_TRAIL_CLOSES,
                                 G_PACK2_DYNAMIC_GRID,
                                 G_BASKET_DD_PERCENT,
                                 G_BASKET_ORDERS);

   string signature = G_PACK2_STATUS + "|" + G_PACK2_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintLegacyPack2Events && signature != G_PACK2_LAST_SIGNATURE)
   {
      if(G_PACK2_APPLIED || G_BASKET_ORDERS > 0 || G_PACK2_LAST_SIGNATURE == "")
      {
         G_PACK2_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 21.3 PACK2] %s | %s | source=%s",
                     G_PACK2_STATUS,
                     G_PACK2_DETAIL,
                     source);
      }
      G_PACK2_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 22.2 CLIENT RISK PROFILE / LOT CAP
//==================================================================//
string P4LotProfile()
{
   string p = P4MiniClientRiskProfile;
   StringTrimLeft(p);
   StringTrimRight(p);

   if(p == "CONSERVATIVE" || p == "conservative" || p == "Conservative")
      return "CONSERVATIVE";

   if(p == "AGGRESSIVE" || p == "aggressive" || p == "Aggressive")
      return "AGGRESSIVE";

   return "BALANCED";
}

void P4LotProfileValues(string &profile, double &first_cap, double &grid_cap, int &max_orders, double &max_dd)
{
   profile = P4LotProfile();

   if(profile == "CONSERVATIVE")
   {
      first_cap = P4MiniConservativeFirstLot;
      grid_cap = P4MiniConservativeGridLot;
      max_orders = P4MiniConservativeMaxOrders;
      max_dd = P4MiniConservativeMaxDD;
      return;
   }

   if(profile == "AGGRESSIVE")
   {
      first_cap = P4MiniAggressiveFirstLot;
      grid_cap = P4MiniAggressiveGridLot;
      max_orders = P4MiniAggressiveMaxOrders;
      max_dd = P4MiniAggressiveMaxDD;
      return;
   }

   first_cap = P4MiniBalancedFirstLot;
   grid_cap = P4MiniBalancedGridLot;
   max_orders = P4MiniBalancedMaxOrders;
   max_dd = P4MiniBalancedMaxDD;
}
