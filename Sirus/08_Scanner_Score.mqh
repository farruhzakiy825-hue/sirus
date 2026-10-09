//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 08_Scanner_Score                                |
//| Opportunity scanner and signal score engine                      |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

void UpdateOpportunityScanner(const string source)
{
   if(!UseOpportunityScanner)
   {
      ResetOpportunity("scanner disabled");
      return;
   }

   if(ScannerEvaluateOnNewBarOnly && G_OPP_EVAL_BAR == G_BARS_SEEN)
      return;

   G_OPP_EVAL_BAR = G_BARS_SEEN;

   if(!G_ENV_READY)
   {
      ResetOpportunity("ENV not ready");
      return;
   }

   // SAFE-RELAX(unknown-zone-only): previously the scanner stopped dead in MARKET_UNKNOWN, which
   // is the single biggest reason the bot sits idle - a quiet, directionless tape is "UNKNOWN"
   // very often. Rather than trade nothing, allow ONLY the zone-anchored setups here: a sweep of
   // a real S/R level, a failed breakout back through one, or a reaction at one. These do not need
   // a defined trend - they lean on a proven price level - so they are safe in an undefined market.
   // Trend / momentum / breakout / continuation detectors stay OFF in UNKNOWN (those genuinely
   // need a direction). This adds quality entries without adding reckless ones.
   bool unknown_zone_only = false;
   if(G_MARKET_STATE == MARKET_UNKNOWN)
   {
      if(!EnableUnknownZoneOnlyScan)
      {
         ResetOpportunity("market unknown");
         return;
      }
      unknown_zone_only = true;
   }

   if(G_MARKET_STATE == MARKET_CHAOS)
   {
      ResetOpportunity("market chaos");
      return;
   }

   ResetOpportunity("no candidate yet");

   string reason = "";
   int score = 0;

   if(DetectSweepBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_SWEEP_REJECTION, score, reason, true);
   if(DetectSweepSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_SWEEP_REJECTION, score, reason, true);
   if(DetectFakeBreakoutReturnBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_FAKE_BREAKOUT_RETURN, score, reason, true);
   if(DetectFakeBreakoutReturnSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_FAKE_BREAKOUT_RETURN, score, reason, true);
   if(DetectNearZoneReactionBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_NEAR_ZONE_REACTION, score, reason, true);
   if(DetectNearZoneReactionSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_NEAR_ZONE_REACTION, score, reason, true);

   // SAFE-RELAX(unknown-zone-only): in an undefined market, skip everything below (all the
   // trend/range/momentum detectors) but still fall through to the normal grade+status finaliser
   // at the end of the function, so a zone setup found above is committed correctly.
   if(!unknown_zone_only)
   {
   if(DetectRangeEdgeBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_RANGE_EDGE, score, reason, true);
   if(DetectRangeEdgeSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_RANGE_EDGE, score, reason, true);
   if(DetectPullbackBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_PULLBACK_CONTINUATION, score, reason, false);
   if(DetectPullbackSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_PULLBACK_CONTINUATION, score, reason, false);
   if(DetectMomentumBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_MOMENTUM_SCALP, score, reason, false);
   if(DetectMomentumSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_MOMENTUM_SCALP, score, reason, false);
   if(DetectExhaustionBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_EXHAUSTION_REVERSAL, score, reason, true);
   if(DetectExhaustionSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_EXHAUSTION_REVERSAL, score, reason, true);
   if(DetectBreakoutContinuationBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_BREAKOUT_CONTINUATION, score, reason, false);
   if(DetectBreakoutContinuationSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_BREAKOUT_CONTINUATION, score, reason, false);
   if(DetectTrendRideBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_TREND_RIDE, score, reason, false);
   if(DetectTrendRideSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_TREND_RIDE, score, reason, false);
   if(DetectSwingContinuationBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_SWING_CONTINUATION, score, reason, false);
   if(DetectSwingContinuationSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_SWING_CONTINUATION, score, reason, false);
   if(DetectMABounceBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_MA_BOUNCE, score, reason, false);
   if(DetectMABounceSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_MA_BOUNCE, score, reason, false);
   if(DetectDonchianBreakoutBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_DONCHIAN_BREAKOUT, score, reason, false);
   if(DetectDonchianBreakoutSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_DONCHIAN_BREAKOUT, score, reason, false);
   if(DetectConsecutiveCandlesBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_CONSECUTIVE_CANDLES, score, reason, false);
   if(DetectConsecutiveCandlesSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_CONSECUTIVE_CANDLES, score, reason, false);
   if(DetectDXYConfirmedTrendBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_DXY_CONFIRMED_TREND, score, reason, false);
   if(DetectDXYConfirmedTrendSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_DXY_CONFIRMED_TREND, score, reason, false);
   if(DetectExpandingVolatilityBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_EXPANDING_VOLATILITY, score, reason, false);
   if(DetectExpandingVolatilitySell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_EXPANDING_VOLATILITY, score, reason, false);
   if(DetectMTFUnanimousBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_MTF_UNANIMOUS, score, reason, false);
   if(DetectMTFUnanimousSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_MTF_UNANIMOUS, score, reason, false);
   if(DetectEQZoneTrendBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_EQ_ZONE_TREND, score, reason, false);
   if(DetectEQZoneTrendSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_EQ_ZONE_TREND, score, reason, false);
   if(DetectVolumePushBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_VOLUME_PUSH, score, reason, false);
   if(DetectVolumePushSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_VOLUME_PUSH, score, reason, false);
   if(DetectVWAPBounceBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_VWAP_BOUNCE, score, reason, false);
   if(DetectVWAPBounceSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_VWAP_BOUNCE, score, reason, false);
   // V31.6z43 fix: real gap found via audit - OPP_TYPE_ZONE_RETEST, its string mapping, and
   // both detector functions (DetectZoneRetestBuy/Sell) were all fully built, but never
   // actually wired into the scanner - a complete, working feature that simply never ran.
   if(DetectZoneRetestBuy(reason, score))
      ConsiderOpportunity(OPP_DIR_BUY, OPP_TYPE_ZONE_RETEST, score, reason, true);
   if(DetectZoneRetestSell(reason, score))
      ConsiderOpportunity(OPP_DIR_SELL, OPP_TYPE_ZONE_RETEST, score, reason, true);
   } // end if(!unknown_zone_only) - SAFE-RELAX(unknown-zone-only)

   // CONSENSUS: every detector has spoken. The engine picked the single highest score and never
   // counted how many agreed, so seven detectors at five lose to one outlier at eight - and the
   // outlier is the entry that gets taken.
   //
   // Seven modules seeing the same thing is better evidence than one module seeing it strongly.
   // Not always better - a genuinely strong setup keeps its place - but a lone voice should not
   // beat a crowd by three points.
   if(EnableDirectionConsensus && G_OPP_GRADE != OPP_GRADE_NONE &&
      G_OPP_VOICES_BUY > 0 && G_OPP_VOICES_SELL > 0)
   {
      int win_dir  = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      int win_n    = (win_dir > 0) ? G_OPP_VOICES_BUY  : G_OPP_VOICES_SELL;
      int lose_n   = (win_dir > 0) ? G_OPP_VOICES_SELL : G_OPP_VOICES_BUY;
      int win_best = (win_dir > 0) ? G_OPP_BEST_BUY_SCORE  : G_OPP_BEST_SELL_SCORE;
      int lose_best= (win_dir > 0) ? G_OPP_BEST_SELL_SCORE : G_OPP_BEST_BUY_SCORE;

      // The other side has a crowd and this one does not, and the score gap is small enough
      // that the crowd is the better evidence.
      if(lose_n >= win_n + ConsensusVoiceEdge &&
         (win_best - lose_best) <= ConsensusMaxScoreGap)
      {
         G_OPP_DIR    = (win_dir > 0) ? OPP_DIR_SELL : OPP_DIR_BUY;
         G_OPP_SCORE  = lose_best;
         // AUDIT FIX (A2): the new side's own setup - not the loser's type, grade and reason.
         int nsi = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : 0;
         if(G_OPP_SIDE_TYPE[nsi] != OPP_TYPE_NONE)
         {
            G_OPP_TYPE     = G_OPP_SIDE_TYPE[nsi];
            G_OPP_GRADE    = G_OPP_SIDE_GRADE[nsi];
            G_OPP_IS_MICRO = G_OPP_SIDE_MICRO[nsi];
            G_OPP_REASON   = G_OPP_SIDE_REASON[nsi];
         }
         G_OPP_REASON += StringFormat(" [consensus: %d voices against %d]", lose_n, win_n);

         if((ConsensusPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS CONSENSUS] %d detectors said %s at best %d - overriding one-sided %s at %d",
                        lose_n, (win_dir > 0 ? "SELL" : "BUY"), lose_best,
                        (win_dir > 0 ? "BUY" : "SELL"), win_best);
      }
   }

   // CONSENSUS: and how close the two sides were. The engine already knows the best score on each
   // side and has never used the difference - a BUY at eight beating a SELL at seven is not a
   // direction, it is a coin landing on its edge, and that belongs in the score.
   G_OPP_DIR_CLARITY = 0.0;
   if(EnableDirectionClarity && G_OPP_VOICES_BUY > 0 && G_OPP_VOICES_SELL > 0)
   {
      int hi = MathMax(G_OPP_BEST_BUY_SCORE, G_OPP_BEST_SELL_SCORE);
      int lo = MathMin(G_OPP_BEST_BUY_SCORE, G_OPP_BEST_SELL_SCORE);

      if(hi > 0)
         G_OPP_DIR_CLARITY = (double)(hi - lo) / (double)hi;
   }
   else if(G_OPP_VOICES_BUY > 0 || G_OPP_VOICES_SELL > 0)
   {
      // Only one side spoke at all. That is as clear as it gets.
      G_OPP_DIR_CLARITY = 1.0;
   }

   if(G_OPP_GRADE == OPP_GRADE_NONE)
   {
      ResetOpportunity("no valid setup");
   }
   else
   {
      G_OPP_STATUS = StringFormat("OPPORTUNITY: %s %s %s | score=%d | market=%s",
                                  OpportunityGradeToString(G_OPP_GRADE),
                                  OpportunityDirToString(G_OPP_DIR),
                                  OpportunityTypeToString(G_OPP_TYPE),
                                  G_OPP_SCORE,
                                  MarketStateToString(G_MARKET_STATE));
      G_OPP_DETAIL = "OPPORTUNITY DETAIL: " + G_OPP_REASON;
   }

   string signature = G_OPP_STATUS + "|" + G_OPP_DETAIL + "|" + IntegerToString(G_BARS_SEEN);
   if(PrintMarketOnChange && signature != G_OPP_LAST_SIGNATURE)
   {
      if(G_OPP_GRADE != OPP_GRADE_NONE || G_OPP_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 SCANNER] %s | %s | mode=%s | source=%s",
                     G_OPP_STATUS, G_OPP_DETAIL, ModeToString(G_ACTIVE_MODE), source);
      }
      G_OPP_LAST_SIGNATURE = signature;
   }

   if(G_ENV_READY)
      SetStatus("CORE + ENV + MODE + MARKET + SCANNER READY: first entry only in Phase 21.3", "OpportunityScanner");
}


//==================================================================//
//  PHASE 21.3 SIGNAL SCORE ENGINE + ANTI-OVERFILTER
//==================================================================//
double ClampDouble(const double value, const double min_value, const double max_value)
{
   if(value < min_value)
      return min_value;
   if(value > max_value)
      return max_value;
   return value;
}

void ResetScoreEngine(const string reason)
{
   G_SCORE_DECISION = SCORE_DECISION_NONE;
   G_SCORE_STATUS = "SCORE: NONE | reason=" + reason;
   G_SCORE_DETAIL = "SCORE DETAIL: " + reason;
   // FIX(counter-trend-needs-a-reason): this one MUST be cleared per scan. It is set only while the
   // HTF-against condition holds, and ChooseLadderShape reads it when the entry opens - left sticky,
   // a single counter-trend read would cap every later ladder for the rest of the session.
   G_ENTRY_AGAINST_GLOBAL = false;
   G_SCORE_BASE = 0;
   G_SCORE_BONUS = 0;
   G_SCORE_PENALTY = 0;
   G_SCORE_FINAL = 0;
   G_SCORE_MIN_REQUIRED = 0;
   G_SCORE_TP_TARGET = 0.0;
   G_SCORE_ROOM_POINTS = 0.0;
   G_SCORE_IS_MICRO = false;
   G_SCORE_HARD_BLOCK = "none";
   G_SCORE_HB_DIR_WHY = "";
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
   // FIX(post-loss-cooldown-wipe): NOT cleared here - ResetScoreEngine runs every scan and was
   // erasing the 30-min post-loss cooldown one tick after a losing basket closed. The prev-basket
   // tracking below is preserved too, so UpdatePostLossCooldown can still re-arm it.
   G_RISK_BLOCK_COUNT = 0;
   G_RISK_CLOSE_COUNT = 0;
   // (G_PREV_BASKET_ORDERS preserved - needed for the >0->0 losing-basket detection)
   // (G_PREV_BASKET_PROFIT preserved for the same reason)
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

bool IsBuyOpportunity()
{
   return (G_OPP_DIR == OPP_DIR_BUY);
}

bool IsSellOpportunity()
{
   return (G_OPP_DIR == OPP_DIR_SELL);
}

bool IsMicroOpportunity()
{
   if(!UseMicroScalpLayer)
      return false;

   if(G_OPP_GRADE == OPP_GRADE_C_MICRO)
      return true;

   if(!MicroOnlyCGrade && G_OPP_IS_MICRO)
   {
      if(G_OPP_GRADE == OPP_GRADE_B && MicroAllowBGradeIfPreferred)
         return true;
   }

   return false;
}

double MainTPPoints()
{
   if(UseFixedTP && FixedTPPoints > 0)
      return (double)FixedTPPoints;
   if(UseBasketTP && BasketTPPoints > 0)
      return (double)BasketTPPoints;
   return 2000.0;
}

double MicroTPPoints()
{
   double main_tp = MainTPPoints();
   double percent_tp = main_tp * (double)MicroTPPercentOfMainTP / 100.0;
   double fixed_tp = (double)FixedMicroTPPoints;

   double room = ComputeRoomToTP();
   double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);

   double dynamic_tp = percent_tp;

   if(room > 0.0)
      dynamic_tp = MathMin(dynamic_tp, room * MicroDynamicRoomFactor);

   if(atr > 0.0)
      dynamic_tp = MathMin(dynamic_tp, atr * MicroDynamicATRMult);

   if(dynamic_tp <= 0.0)
      dynamic_tp = percent_tp;

   double result = percent_tp;

   if(MicroTPMode == MICRO_TP_FIXED)
      result = fixed_tp;
   else if(MicroTPMode == MICRO_TP_MAIN_PERCENT)
      result = percent_tp;
   else if(MicroTPMode == MICRO_TP_DYNAMIC_MARKET)
      result = dynamic_tp;
   else
   {
      // AUTO: use dynamic when market room/ATR is readable, otherwise use main TP percent
      result = (dynamic_tp > 0.0 ? dynamic_tp : percent_tp);
   }

   G_MICRO_TP_POINTS = ClampDouble(result, (double)MicroTPMinPoints, (double)MicroTPMaxPoints);
   return G_MICRO_TP_POINTS;
}

int MinScoreForContext(const bool is_micro)
{
   if(is_micro)
   {
      if(G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER)
         return MinScoreMicroHighHunter;
      return MinScoreMicroBalanced;
   }

   if(G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER)
      return MinScoreHighHunter;

   return MinScoreBalanced;
}

double ComputeRoomToTP()
{
   double close_price = CandleClose(SignalTF, 1);
   if(close_price <= 0.0)
      close_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double recent_high = RecentHighForScanner();
   double recent_low  = RecentLowForScanner();

   if(close_price <= 0.0 || recent_high <= 0.0 || recent_low <= 0.0)
      return 0.0;

   if(IsBuyOpportunity())
      return MathMax(0.0, (recent_high - close_price) / _Point);

   if(IsSellOpportunity())
      return MathMax(0.0, (close_price - recent_low) / _Point);

   return 0.0;
}

bool ScoreHardBlockCheck(string &reason)
{
   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return true;
   }

   if(G_MARKET_STATE == MARKET_CHAOS)
   {
      reason = "market chaos";
      return true;
   }

   if(G_LAST_SPREAD_POINTS < 0)
   {
      reason = "spread unreadable";
      return true;
   }

   int hard_spread = ScoreHardBlockExtremeSpread;
   if(hard_spread <= 0)
      hard_spread = CriticalSpreadPoints;

   if(G_LAST_SPREAD_POINTS >= hard_spread)
   {
      reason = StringFormat("extreme spread %d/%d", G_LAST_SPREAD_POINTS, hard_spread);
      return true;
   }

   int age = TickAgeSeconds();
   if(age < 0)
   {
      reason = "no tick yet";
      return true;
   }

   if(age > MaxTickAgeSeconds)
   {
      reason = StringFormat("tick stale %ds/%d", age, MaxTickAgeSeconds);
      return true;
   }

   reason = "none";
   return false;
}

void AddScoreBonus(int &bonus, string &detail, const int value, const string reason)
{
   if(value <= 0)
      return;

   bonus += value;
   detail += StringFormat(" +%d %s;", value, reason);
}

void AddScorePenalty(int &penalty, string &detail, const int value, const string reason)
{
   if(value <= 0)
      return;

   penalty += value;
   detail += StringFormat(" -%d %s;", value, reason);
}

void ApplyAntiOverfilterScoring(int &bonus, int &penalty, string &detail)
{
   // Trend alignment: penalty, not a hard block
   if(IsBuyOpportunity())
   {
      if(G_MARKET_STATE == MARKET_TREND_UP || G_MARKET_STATE == MARKET_PULLBACK)
         AddScoreBonus(bonus, detail, ScoreBonusTrendAligned, "buy aligned with trend/pullback");
      else if(G_MARKET_STATE == MARKET_TREND_DOWN)
         AddScorePenalty(penalty, detail, ScorePenaltyTrendAgainst, "buy against trend");
   }
   else if(IsSellOpportunity())
   {
      if(G_MARKET_STATE == MARKET_TREND_DOWN || G_MARKET_STATE == MARKET_PULLBACK)
         AddScoreBonus(bonus, detail, ScoreBonusTrendAligned, "sell aligned with trend/pullback");
      else if(G_MARKET_STATE == MARKET_TREND_UP)
         AddScorePenalty(penalty, detail, ScorePenaltyTrendAgainst, "sell against trend");
   }

   if(G_MARKET_STATE == MARKET_RANGE && (G_OPP_TYPE == OPP_TYPE_RANGE_EDGE || G_OPP_TYPE == OPP_TYPE_SWEEP_REJECTION))
      AddScoreBonus(bonus, detail, ScoreBonusRangeReaction, "range edge reaction");

   if(G_MARKET_STATE == MARKET_EXHAUSTION && (G_OPP_TYPE == OPP_TYPE_EXHAUSTION_REVERSAL || G_OPP_TYPE == OPP_TYPE_SWEEP_REJECTION))
      AddScoreBonus(bonus, detail, 1, "exhaustion reaction");

   if(G_MARKET_STATE == MARKET_IMPULSE && (G_OPP_TYPE == OPP_TYPE_RANGE_EDGE || G_OPP_TYPE == OPP_TYPE_SWEEP_REJECTION))
      AddScorePenalty(penalty, detail, ScorePenaltyImpulseRisk, "fresh impulse risk");

   // FIX(hunter-spread-discriminator-dead), sibling of the mode selector: EffSpread() ignores its
   // argument while UseUnifiedMaxSpread is on, so "clean spread" meant <=500 here while mode
   // selection now means <=AutoHighHunterMaxSpread. Two contradictory definitions of clean - a
   // 450-point spread was "not clean enough for hunter" yet still collected the clean-spread bonus.
   if(G_LAST_SPREAD_POINTS >= 0 && G_LAST_SPREAD_POINTS <= MathMax(1, AutoHighHunterMaxSpread))
      AddScoreBonus(bonus, detail, ScoreBonusCleanSpread, "clean spread");
   else if(G_LAST_SPREAD_POINTS > EffSpread(MaxSpreadPoints) * 0.80)
      AddScorePenalty(penalty, detail, ScorePenaltySoftSpread, "soft spread pressure");

   double min_room = G_SCORE_TP_TARGET * (double)ScoreMinRoomPercentOfTP / 100.0;
   if(G_SCORE_ROOM_POINTS > 0.0 && G_SCORE_ROOM_POINTS >= G_SCORE_TP_TARGET)
      AddScoreBonus(bonus, detail, ScoreBonusRoomToTP, "room to TP");
   else if(G_SCORE_ROOM_POINTS > 0.0 && G_SCORE_ROOM_POINTS < min_room)
      AddScorePenalty(penalty, detail, ScorePenaltyNoRoomToTP, "limited room to TP");

   // V249fix(auto-mode): this is now the ONLY Hunter mode bonus. The per-detector copies were removed. It was applied on top of
   // the capped "High Hunter mode" bonus in the score engine, i.e. TWICE - and this copy went
   // into G_SCORE_BASE, which no cap can answer. Combined with a bar that is already 2 lower
   // (MinScoreHighHunter 2 vs MinScoreBalanced 4), Hunter's effective quality discount was 4
   // points, not the documented 2 - and it also shifted GradeFromScore, so the aggressive mode
   // graded a marginal setup as B (full lot) where Balanced graded it C_MICRO or NONE. The mode
   // bonus now lives only in the bonus pool, where the penalty caps can argue with it.
   if(G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER && G_OPP_GRADE != OPP_GRADE_NONE)
      AddScoreBonus(bonus, detail, 1, "High Hunter mode");
}

// --- V30.1 new: MULTI-TIMEFRAME CONFIRM ---
// Returns +1 (HTF uptrend), -1 (HTF downtrend), 0 (neutral / data not ready).
// Design: close vs SMA on the higher TF, with an ATR-based neutral band so tiny
// wobbles around the MA do not flip the signal. Cached per bar - cheap on ticks.
int  G_MTF_CACHE_BAR = -1;
int  G_MTF_CACHE_DIR = 0;

int MTFTrendDirection()
{
   if(!EnableMTFConfirm)
      return 0;

   if(G_MTF_CACHE_BAR == G_BARS_SEEN)
      return G_MTF_CACHE_DIR;

   G_MTF_CACHE_BAR = G_BARS_SEEN;
   G_MTF_CACHE_DIR = 0;

   int period = MathMax(5, MTFConfirmMAPeriod);
   double closes[];
   if(CopyClose(_Symbol, MTFConfirmTF, 1, period, closes) != period)
      return 0;

   double sum = 0.0;
   for(int i = 0; i < period; i++)
      sum += closes[i];
   double sma = sum / period;

   double last_close = closes[period - 1]; // CopyClose without series flag: last element = most recent requested bar

   double band = 0.0;
   double htf_atr_points = ATRPointsManual(MTFConfirmTF, 14, 1);
   if(htf_atr_points > 0.0 && MTFNeutralBandATR > 0.0)
      band = htf_atr_points * _Point * MTFNeutralBandATR;

   if(last_close > sma + band)
      G_MTF_CACHE_DIR = 1;
   else if(last_close < sma - band)
      G_MTF_CACHE_DIR = -1;

   if((MTFConfirmPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS v30.1 MTF] dir=%d | close=%.2f sma=%.2f band=%.2f | tf=%d ma=%d",
                  G_MTF_CACHE_DIR, last_close, sma, band, (int)MTFConfirmTF, period);

   return G_MTF_CACHE_DIR;
}

// ===================================================================================
// FEATURE(counter-context-guard): ONE shared evaluator for the three "entry fights the current
// market context" hard blocks. It lives in a single function on purpose: the score engine AND the
// queue-replay guard both call it, so a queued signal can never fire under conditions that would
// have blocked a fresh one, and the two paths can't drift apart as the rules are tuned later.
//
// Returns true (with a human-readable reason) when an entry in `dir` (+1 BUY / -1 SELL) should be
// hard-blocked right now, for any of:
//   1. COUNTER-ZONE  - entry straight into a strong zone it should bounce off (SELL sitting on
//      support / BUY under resistance).
//   2. HTF-AGAINST   - entry fighting the higher-timeframe trend. Requires BOTH the same HTF
//      direction the dashboard displays (DeepHTFTrendDirection - called directly, NOT the cached
//      G_DLP_HTF_DIR, because the DLP pack updates AFTER the score engine and would be stale) AND
//      a reasonably firm global-trend confidence, so a barely-sloping HTF read can't veto trades.
//      Overridden by a genuine multi-signal reversal, so real turns are still taken.
//   3. RANGE-BREAKOUT COUNTER-FADE - fading an edge of a range that price has just broken out of.
// ===================================================================================
// FEATURE(gap-fill-magnet): track a large unfilled gap and the direction price is pulled to fill
// it. Called once per new bar from the scanner. A gap UP (open far above the prior close) leaves a
// gap BELOW, so price is pulled DOWN to fill it (dir = -1) toward the prior close level; a gap DOWN
// leaves a gap ABOVE and pulls price UP (dir = +1). The magnet clears once price retraces back to
// that fill level (the gap is essentially filled) or when no gap is active.
void UpdateGapFillMagnet()
{
   if(!EnableGapFillMagnet)
   {
      G_GAP_FILL_DIR = 0;
      G_GAP_FILL_LEVEL = 0.0;
      return;
   }

   ENUM_TIMEFRAMES tf = SignalTF;

   // 1) Detect a fresh large gap between the last two closed bars (open[1] vs close[2]).
   double open_recent = CandleOpen(tf, 1);
   double close_prior = CandleClose(tf, 2);
   if(open_recent > 0.0 && close_prior > 0.0 && _Point > 0.0)
   {
      double gap_pts = MathAbs(open_recent - close_prior) / _Point;

      // V178b: a gap is a SESSION boundary event - the market closed at one price and reopened at
      // another. Comparing open[1] against close[2] on M1 finds something else: any two adjacent
      // minutes that happened to jump $2, which on gold is a fast tick. Those were re-arming the
      // magnet continuously, which also meant the age limit could never expire anything.
      //
      // A real gap has a TIME hole in it - the bars either side sit further apart than the
      // timeframe itself.
      datetime t_recent = iTime(_Symbol, tf, 1);
      datetime t_prior  = iTime(_Symbol, tf, 2);
      int tf_sec = PeriodSeconds(tf);
      bool time_hole = (t_recent > 0 && t_prior > 0 && tf_sec > 0 &&
                        (int)(t_recent - t_prior) > tf_sec * MathMax(2, GapFillMagnetMinBarGap));

      // And do not re-arm a magnet that is already tracking this same gap.
      bool same_gap = (G_GAP_FILL_DIR != 0 &&
                       MathAbs(G_GAP_FILL_LEVEL - close_prior) < (10.0 * _Point));

      if(gap_pts >= (double)GapFillMagnetMinPoints && time_hole && !same_gap)
      {
         // The fill level is the price the market gapped AWAY from - the prior close.
         G_GAP_FILL_LEVEL = close_prior;
         // Gap UP -> gap sits below -> price pulled DOWN to fill (-1). Gap DOWN -> pulled UP (+1).
         G_GAP_FILL_DIR   = (open_recent > close_prior) ? -1 : +1;
         G_GAP_FILL_ORIGIN = open_recent;   // V125: where price gapped TO - needed to measure how much of the gap has been filled
         G_GAP_FILL_BAR    = G_BARS_SEEN;   // V178: when it opened, so the magnet can expire
         G_GAP_FILL_TIME  = TimeCurrent();
      }
   }

   // 2) Clear the magnet once price has reached the fill level (gap essentially filled).
   // V178: a gap that simply never fills was blocking one direction with no way out. Monday gaps of
   // $2+ are ordinary on gold, and when price trends away instead of filling, the magnet held for
   // days - the original reasoning (price is drawn back to the gap) stops being true long before
   // that. An unfilled gap becomes part of the chart rather than a pull on it.
   if(G_GAP_FILL_DIR != 0 && GapFillMagnetMaxAgeBars > 0 && G_GAP_FILL_BAR > 0 &&
      (G_BARS_SEEN - G_GAP_FILL_BAR) > GapFillMagnetMaxAgeBars)
   {
      if((GapFillMagnetPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v178 GAP] magnet expired after %d bars unfilled - no longer treating it as a pull",
                     G_BARS_SEEN - G_GAP_FILL_BAR);
      G_GAP_FILL_DIR = 0;
      G_GAP_FILL_LEVEL = 0.0;
      G_GAP_FILL_ORIGIN = 0.0;
      G_GAP_FILL_BAR = 0;
   }

   if(G_GAP_FILL_DIR != 0 && G_GAP_FILL_LEVEL > 0.0)
   {
      double bid = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
      if(bid > 0.0)
      {
         // V125: GapFillMagnetFilledFraction was declared but never consulted - the magnet only
         // cleared on a 100% fill, so a gap that had already been 90% closed kept blocking entries
         // that were no longer fighting anything. Measure the progress from where price gapped TO
         // (origin) toward the fill level, and clear once that fraction is reached.
         bool filled = false;
         double gap_span = MathAbs(G_GAP_FILL_ORIGIN - G_GAP_FILL_LEVEL);
         if(G_GAP_FILL_ORIGIN > 0.0 && gap_span > 0.0)
         {
            // V178b: MathAbs() counted movement in EITHER direction as progress, so price running
            // $3 away from a $3 gap scored 100% filled and released the magnet at exactly the moment
            // the gap mattered most. Progress has to be movement TOWARD the fill level, which the
            // gap's own geometry defines - the level sits below the origin on a gap up, above it on
            // a gap down.
            double toward = (G_GAP_FILL_LEVEL < G_GAP_FILL_ORIGIN)
                            ? (G_GAP_FILL_ORIGIN - bid)     // gap up - filling means moving down
                            : (bid - G_GAP_FILL_ORIGIN);    // gap down - filling means moving up
            double progress = toward / gap_span;
            filled = (progress >= MathMax(0.1, MathMin(1.0, GapFillMagnetFilledFraction)));
         }
         else
         {
            // Origin unknown (e.g. after a restart) - fall back to the original full-fill test.
            filled = (G_GAP_FILL_DIR < 0) ? (bid <= G_GAP_FILL_LEVEL)
                                          : (bid >= G_GAP_FILL_LEVEL);
         }
         if(filled)
         {
            G_GAP_FILL_DIR = 0;
            G_GAP_FILL_LEVEL = 0.0;
            G_GAP_FILL_ORIGIN = 0.0;
         }
      }
   }
}

// FEATURE(collapse-bottom-guard): return the direction a fast OR sustained recent move is running,
// or 0 if none. +1 = price near the top of a spike up; -1 = near the bottom of a collapse. Two
// windows are checked so BOTH a fast panic drop (short window) and a slow day-long slide (long
// window) are caught - the short window alone misses a gentle multi-hour decline like "down all day
// from the 09:30 high". Either window qualifying is enough; the extreme-position test is the same.
int CollapseWindowDir(const int lookback_bars, const int min_points)
{
   ENUM_TIMEFRAMES tf = CollapseGuardTF;
   int lb = MathMax(2, lookback_bars);

   double hi = HighestHigh(tf, lb, 1);
   double lo = LowestLow(tf, lb, 1);
   if(hi <= 0.0 || lo <= 0.0 || _Point <= 0.0)
      return 0;

   double range_pts = (hi - lo) / _Point;
   if(range_pts < (double)min_points)
      return 0;   // move too small for this window

   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(bid <= 0.0)
      return 0;

   double pos = (bid - lo) / (hi - lo);   // 0 at the low, 1 at the high
   if(pos <= 0.33)
      return -1;   // bottom of the drop
   if(pos >= 0.67)
      return +1;   // top of the rise
   return 0;        // middle - no extreme to fade
}

int CollapseBottomMoveDir()
{
   if(!EnableCollapseBottomGuard)
      return 0;

   // Short window: fast, sharp collapse/spike.
   int fast = CollapseWindowDir(CollapseGuardLookbackBars, CollapseGuardMinPoints);
   if(fast != 0)
      return fast;

   // Long window: slow but sustained move (e.g. sliding down all day).
   return CollapseWindowDir(CollapseGuardLongLookbackBars, CollapseGuardLongMinPoints);
}

// FEATURE(ghost-zones): TTL (in seconds) for a ghost. The blended zone map can't cheaply tell us
// which TF a level came from, but a level's STRENGTH already encodes its TF significance (higher-TF
// levels score higher). So map strength to a TTL band: strong = D1/H4-like (longest), medium =
// H1-like, weak = M15-like. This restores the "bigger levels remembered longer" behaviour.
long GhostZoneTTLSecondsByStrength(const double strength)
{
   // V132: the caller must pass TOUCH-based strength here (ZoneMapStrengthByTouches), not the full
   // ZoneMapStrength. These bands stand in for the level's timeframe CLASS, and the rejection bonus
   // in the full strength measures danger instead - one sharp bounce off an M15 level would
   // otherwise earn it a D1 ghost lifetime and keep a stale ghost alive for days.
   int days = GhostZoneTTLDaysM15;                 // weakest band
   if(strength >= 2.4)      days = GhostZoneTTLDaysD1;   // D1/H4-class level
   else if(strength >= 1.8) days = GhostZoneTTLDaysH1;   // H1-class level
   else if(strength >= 1.3) days = GhostZoneTTLDaysM15; // M15/M30-class
   return (long)MathMax(1, days) * 86400;
}

// FEATURE(ghost-zones): add a broken level to the ghost list (dedupes near-identical prices, keeps
// the list capped at GhostZoneMaxCount by dropping the soonest-to-expire when full).
void AddGhostZone(const double level, const bool was_support, const double strength)
{
   if(level <= 0.0)
      return;

   double tol = MathMax(1, GhostZoneBreakPoints) * _Point;
   // TTL band uses the level's ORIGINAL strength (undo the ghost factor) so the 2.4/1.8 thresholds
   // in GhostZoneTTLSecondsByStrength refer to real zone strength, not the reduced ghost value.
   double orig_strength = (GhostZoneStrengthFactor > 0.0) ? (strength / GhostZoneStrengthFactor) : strength;

   // V132: the TTL bands stand in for the level's timeframe CLASS, so they must read TOUCH-based
   // strength. ZoneMapStrength() now also carries a rejection-quality bonus (how hard price was
   // thrown back), which measures danger rather than class - without this line, one sharp bounce
   // off an M15 level would give it a D1 ghost lifetime and leave a stale ghost blocking entries
   // for days. Fall back to the passed strength if the level can no longer be measured.
   double class_strength = ZoneMapStrengthByTouches(level);
   if(class_strength <= 0.0)
      class_strength = orig_strength;

   datetime expiry = TimeCurrent() + (datetime)GhostZoneTTLSecondsByStrength(class_strength);

   // Update an existing ghost at ~the same price instead of adding a duplicate.
   for(int i = 0; i < G_GHOST_COUNT; i++)
   {
      if(MathAbs(G_GHOST_PRICE[i] - level) <= tol)
      {
         G_GHOST_WAS_SUPPORT[i] = was_support;
         G_GHOST_STRENGTH[i]    = strength;
         G_GHOST_EXPIRY[i]      = expiry;
         return;
      }
   }

   int cap = MathMin(10, MathMax(1, GhostZoneMaxCount));   // FIX(ghost-zone-capacity): matches the G_GHOST_* array size now (was capped to 8, below the input's own 10)
   if(G_GHOST_COUNT < cap)
   {
      G_GHOST_PRICE[G_GHOST_COUNT]       = level;
      G_GHOST_WAS_SUPPORT[G_GHOST_COUNT] = was_support;
      G_GHOST_STRENGTH[G_GHOST_COUNT]    = strength;
      G_GHOST_EXPIRY[G_GHOST_COUNT]      = expiry;
      G_GHOST_COUNT++;
      return;
   }

   // Full: replace the one that expires soonest (least valuable to keep).
   int soonest = 0;
   for(int i = 1; i < G_GHOST_COUNT; i++)
      if(G_GHOST_EXPIRY[i] < G_GHOST_EXPIRY[soonest])
         soonest = i;
   G_GHOST_PRICE[soonest]       = level;
   G_GHOST_WAS_SUPPORT[soonest] = was_support;
   G_GHOST_STRENGTH[soonest]    = strength;
   G_GHOST_EXPIRY[soonest]      = expiry;
}

// FEATURE(ghost-zones): drop expired ghosts (called each scan before use).
void PruneGhostZones()
{
   datetime now = TimeCurrent();
   int w = 0;
   for(int i = 0; i < G_GHOST_COUNT; i++)
   {
      if(G_GHOST_EXPIRY[i] > now)
      {
         if(w != i)
         {
            G_GHOST_PRICE[w]       = G_GHOST_PRICE[i];
            G_GHOST_WAS_SUPPORT[w] = G_GHOST_WAS_SUPPORT[i];
            G_GHOST_STRENGTH[w]    = G_GHOST_STRENGTH[i];
            G_GHOST_EXPIRY[w]      = G_GHOST_EXPIRY[i];
         }
         w++;
      }
   }
   G_GHOST_COUNT = w;
}

// FEATURE(ghost-zones): scan H1/H4/D1 for a level price has just closed through, and remember it.
// Called once per new bar. Only these higher TFs qualify - lower TFs break constantly.
void UpdateGhostZones()
{
   if(!EnableGhostZones || _Point <= 0.0)
      return;

   PruneGhostZones();

   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(bid <= 0.0)
      return;

   // Reference price a few bars back: to call a level "broken" we need price to have been on the
   // OTHER side of it recently and now be clearly on this side. Using the current nearest zones plus
   // this past reference detects an actual cross rather than just any nearby level.
   double past_ref = CandleClose(SignalTF, MathMax(2, GhostZoneCrossLookbackBars));
   if(past_ref <= 0.0)
      return;

   double break_dist     = MathMax(1, GhostZoneBreakPoints) * _Point;
   double low_break_dist = MathMax(1, GhostZoneLowTFBreakPoints) * _Point;

   // The zone map is TF-blended, so we cannot cheaply isolate "the H1 level" vs "the H4 level" here;
   // instead we detect the single nearest broken level on EACH side using the blended nearest-zone
   // functions, and tag its TTL by the strongest enabled TF band it plausibly came from. In practice
   // the nearest resistance just above / support just below price is the level that was crossed.

   // Broken support: price was clearly ABOVE a level a few bars ago and is now clearly BELOW it.
   // That level now sits ABOVE price -> nearest resistance above current price.
   double res = ZoneMapNearestResistance(bid);
   if(res > 0.0 && past_ref > res + break_dist && bid < res - break_dist)
   {
      double str = ZoneMapStrength(res);
      // Low-TF-strength gate only matters if we could not treat it as HTF; keep it simple and let
      // any level of sufficient strength through, using H1 TTL as the default band.
      if(str >= GhostZoneLowTFMinStrength || !EnableGhostZonesLowTF)
         AddGhostZone(res, true, str * GhostZoneStrengthFactor);
   }

   // Broken resistance: price was clearly BELOW a level a few bars ago and is now clearly ABOVE it.
   // That level now sits BELOW price -> nearest support below current price.
   double sup = ZoneMapNearestSupport(bid);
   if(sup > 0.0 && past_ref < sup - break_dist && bid > sup + break_dist)
   {
      double str = ZoneMapStrength(sup);
      if(str >= GhostZoneLowTFMinStrength || !EnableGhostZonesLowTF)
         AddGhostZone(sup, false, str * GhostZoneStrengthFactor);
   }
}

// FEATURE(ghost-zones): if price is currently near a ghost zone, return the direction an entry
// would be CONTINUING into it (so the caller can block that): +1 means price is approaching a
// broken-resistance ghost from below (a BUY would run into it), -1 means approaching a broken-
// support ghost from above (a SELL would run into it). 0 = not near any active ghost.
int GhostZoneReactionDir()
{
   if(!EnableGhostZones || G_GHOST_COUNT <= 0 || _Point <= 0.0)
      return 0;

   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(bid <= 0.0)
      return 0;

   double reach = MathMax(1, GhostZoneReactionPoints) * _Point;

   for(int i = 0; i < G_GHOST_COUNT; i++)
   {
      double lvl = G_GHOST_PRICE[i];
      if(lvl <= 0.0)
         continue;
      if(MathAbs(bid - lvl) > reach)
         continue;

      // Only react if price is approaching from the side that would run INTO the ghost:
      //  - broken support (now resistance): price must be AT or BELOW it (rising up into it) -> block BUY (+1)
      //  - broken resistance (now support): price must be AT or ABOVE it (falling down into it) -> block SELL (-1)
      // If price has already pushed clearly through to the far side, the ghost no longer applies.
      //
      // Conflict guard vs polarity flip: if this level has CONFIRMED a flip (price broke it and is
      // now holding the far side as a new role), that confirmed role outranks the old-role ghost
      // memory - they'd give opposite signals. Defer to the flip and skip the ghost in that case.
      if(G_GHOST_WAS_SUPPORT[i])
      {
         // ex-support now acting as resistance; a confirmed flip here would mean it's new resistance
         // holding - but if instead price flipped it back to support, drop the ghost.
         if(ZoneMapIsPolarityFlip(lvl, true))   // confirmed as SUPPORT again -> ghost (resistance) is stale
            continue;
         // FIX(ghost-zone-side): the outer `MathAbs(bid - lvl) <= reach` guard above already forces
         // lvl-reach <= bid <= lvl+reach, so "bid <= lvl + reach" was always true here - it never
         // actually excluded the "already pushed through to the far side" case the comment describes.
         // Compare against the level itself (not lvl+reach) so price that has cleanly closed ABOVE
         // this ex-support-now-resistance no longer counts as running into it.
         if(bid <= lvl)   // at/below the ex-support-now-resistance
            return 1;             // a BUY would run up into it
      }
      else
      {
         if(ZoneMapIsPolarityFlip(lvl, false))  // confirmed as RESISTANCE again -> ghost (support) is stale
            continue;
         // FIX(ghost-zone-side): same fix as above, mirrored - compare against lvl itself, not lvl-reach.
         if(bid >= lvl)   // at/above the ex-resistance-now-support
            return -1;            // a SELL would run down into it
      }
   }
   return 0;
}

// NOTE: the default for skip_counter_zone lives on the forward declaration only.

// ============================================================================
// FIX(counter-zone-single-level): the counter-zone guard read exactly ONE price - the nearest
// opposing level - and compared its strength against a floor. That is blind to the case the
// owner actually reported: a WEAK level in front with three or four strong ones stacked just
// behind it. Each one individually scores below the floor, the shelf as a whole is a wall, and
// nothing in the entry path ever added them up (every other multi-level reader in this file is
// scoring-only or default-off).
//
// This counts the distinct opposing levels inside the same window the guard already uses and
// returns how much confirmation they carry in total. Levels closer together than
// ZoneNextLevelGapPoints are one shelf member, so the same swing seen on four timeframes counts
// once. `sum_strength` sums (strength - 1.0), i.e. only the confirmation ABOVE the "untested
// single swing" baseline, so a row of four untested wicks still sums to zero and cannot block.
// ============================================================================
int CounterZoneWallCluster(const int dir, const double from_price, const double window_pts,
                           double &sum_strength, double &nearest_level,
                           const bool ignore_feature_flag)
{
   sum_strength  = 0.0;
   nearest_level = 0.0;
   // FIX(lean-killed-by-blocking-flag): EnableCounterZoneCluster is a BLOCKING input. The lean
   // test below routes through this function, so switching the blocker off would have deleted the
   // lean's fallback and turned tier B cases into tier C refusals - turning a feature off would
   // have made the EA block MORE. Callers asking for the lean pass ignore_feature_flag.
   if(!EnableCounterZoneCluster && !ignore_feature_flag)
      return 0;      // do not pay for the scan when the feature is off
   if(dir == 0 || from_price <= 0.0 || _Point <= 0.0 || window_pts <= 0.0)
      return 0;

   // Memoised per bar per direction. ZoneMapStrength() is expensive - it pulls ZoneReactionQuality,
   // which walks ZoneReactionLookbackBars of live iHigh/iLow - and its own result caches hold only
   // 8 levels per bar. Calling it for up to 24 levels on EVERY TICK would both cost thousands of
   // timeseries reads and evict the shared cache for every other consumer in the bar. The swing
   // cache this reads is refreshed per bar, so the answer cannot change within one.
   int    cz_slot = (dir > 0) ? 0 : 1;
   static int    cz_bar[2]  = {-1, -1};
   static double cz_win[2]  = {-1.0, -1.0};   // FIX(cluster-memo-key): the two callers use DIFFERENT windows and would otherwise share a slot
   static int    cz_n[2]    = {0, 0};
   static double cz_sum[2]  = {0.0, 0.0};
   static double cz_near[2] = {0.0, 0.0};
   if(cz_bar[cz_slot] == G_BARS_SEEN && cz_win[cz_slot] == window_pts)
   {
      sum_strength  = cz_sum[cz_slot];
      nearest_level = cz_near[cz_slot];
      return cz_n[cz_slot];
   }

   ZoneMapRefreshSwingCache();

   double kept[24];
   int    kept_n = 0;
   double win    = window_pts * _Point;
   double gap    = ScaleAdjustedPoints(MathMax(1, ZoneNextLevelGapPoints)) * _Point;

   for(int t = 0; t < SIRUS_ZM_CACHE_TF_COUNT; t++)
   {
      int cnt = (dir < 0) ? G_ZMC_LOW_COUNT[t] : G_ZMC_HIGH_COUNT[t];
      for(int k = 0; k < cnt && kept_n < 24; k++)
      {
         double v = (dir < 0) ? G_ZMC_LOW_PRICE[t][k] : G_ZMC_HIGH_PRICE[t][k];
         if(v <= 0.0)
            continue;

         // Only levels the trade would run INTO: below a sell, above a buy.
         bool ahead = (dir < 0) ? (v < from_price && (from_price - v) <= win)
                                : (v > from_price && (v - from_price) <= win);
         if(!ahead)
            continue;

         bool dup = false;
         for(int q = 0; q < kept_n; q++)
         {
            if(MathAbs(v - kept[q]) <= gap)
            {
               dup = true;
               break;
            }
         }
         if(dup)
            continue;

         // Only levels that carry REAL confirmation are shelf members. Without this floor the
         // count is just "how many swing points exist within $3.50 across seven timeframes",
         // which on XAUUSD is almost always >= 3 in BOTH directions at once - and with
         // CounterZoneHardBlock on that is a total halt. A shelf means three tested levels, not
         // three wicks.
         double v_str = ZoneMapStrength(v);
         if(v_str < CounterZoneClusterMinLevelStrength)
            continue;

         kept[kept_n] = v;
         kept_n++;
         sum_strength += MathMax(0.0, v_str - 1.0);

         if(nearest_level <= 0.0 ||
            MathAbs(v - from_price) < MathAbs(nearest_level - from_price))
            nearest_level = v;
      }
   }

   cz_bar[cz_slot]  = G_BARS_SEEN;
   cz_win[cz_slot]  = window_pts;
   cz_n[cz_slot]    = kept_n;
   cz_sum[cz_slot]  = sum_strength;
   cz_near[cz_slot] = nearest_level;
   return kept_n;
}


// ============================================================================
// FIX(counter-trend-needs-a-reason): is there anything BEHIND this trade to lean on?
// For a BUY that means support below it; for a SELL, resistance above. It is the mirror of the
// counter-zone question (which asks what is in FRONT), so it reuses the same cluster scan with the
// direction flipped - and therefore the same per-bar memoisation, at no extra cost.
//
// This exists because "entry against a confirmed global trend" is not one situation but two, and
// they deserve opposite answers. A counter-trend entry taken AT a level the trend has to break is
// the strategy working as designed - five of this EA's seven detectors are reversal-type and fire
// at levels by construction. A counter-trend entry taken in open space, with no level and no
// reversal consensus, is a naked martingale bet against a trend that is still running: the single
// most dangerous position this system can hold, per its own IsReversalOpportunityType note.
// ============================================================================
bool HasSupportingLevelBehind(const int dir, string &detail)
{
   detail = "";
   if(dir == 0 || _Point <= 0.0)
      return false;

   double bid_sb = 0.0, ask_sb = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_sb);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_sb);
   double mid_sb = (bid_sb > 0.0 && ask_sb > 0.0) ? (bid_sb + ask_sb) / 2.0 : bid_sb;
   if(mid_sb <= 0.0)
      return false;

   // The single nearest level behind, on its own merit.
   // FIX(lean-displaced-by-strong-override): EnableStrongZoneOverride searches out to
   // StrongZoneSearchPoints ($20) and REPLACES the nearest level with a stronger one further away.
   // Asking "is there something behind me" and getting back a level $5 away because it is strong
   // inverts the question - the presence of a strong level would REMOVE permission. Suppress the
   // override for this lookup with the file's own flag.
   bool zl_prev = G_ZONE_LOOKUP_BUSY;
   G_ZONE_LOOKUP_BUSY = true;
   double back = (dir > 0) ? ZoneMapNearestSupport(mid_sb) : ZoneMapNearestResistance(mid_sb);
   G_ZONE_LOOKUP_BUSY = zl_prev;

   if(back > 0.0)
   {
      // FIX(lean-wrong-side): both scans accept a level up to ZoneNearAboveTolerance on the FAR
      // side of price (the V243 leniency). MathAbs would read a resistance $0.90 overhead as
      // "$0.90 behind" a BUY and grant the lean on a level that is actually in front. Signed.
      double back_off  = (dir > 0) ? (mid_sb - back) : (back - mid_sb);
      double back_dist = back_off / _Point;
      double back_str  = ZoneMapStrength(back);
      if(back_off > 0.0 &&
         back_dist <= (double)CounterTrendSupportMaxDistance &&
         back_str  >= CounterTrendSupportMinStrength)
      {
         detail = StringFormat("leaning on %.2f (str=%.1f, %.0fpts behind)", back, back_str, back_dist);
         return true;
      }
   }

   // Or a shelf behind - same test the wall side uses, mirrored.
   double bs_sum = 0.0, bs_near = 0.0;
   int    bs_n = CounterZoneWallCluster(-dir, mid_sb, (double)CounterTrendSupportMaxDistance,
                                        bs_sum, bs_near, true);
   if(bs_n >= CounterZoneClusterMinLevels && bs_sum >= CounterZoneClusterMinSum)
   {
      detail = StringFormat("leaning on a %d-level shelf (confirmation %.2f, nearest %.2f)",
                            bs_n, bs_sum, bs_near);
      return true;
   }

   return false;
}

bool CounterContextBlockNow(const int dir, string &why, const bool skip_counter_zone,
                            const int score_final, const int score_min)
{
   why = "";
   if(dir != 1 && dir != -1)
      return false;

   // --- 1. Counter-zone: entering into the wall we should be bouncing off -------------------
   // FIX(arm-confirm-scope): skip_counter_zone suppresses ONLY this section. An armed setup that
   // has just been confirmed answered THIS objection (price reached the zone and was turned away)
   // and must not be re-armed by it - but it has answered nothing about the six unrelated checks
   // below (HTF-against, range counter-fade, gap-fill magnet, collapse guard, ghost zones,
   // counter-impulse), several of which hard-block. Skipping the whole function would have walked
   // a confirmed setup straight past all of them.
   if(EnableCounterZoneFirstEntryBlock && !skip_counter_zone)
   {
      double bid_cc = 0.0, ask_cc = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_cc);
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_cc);
      double mid_cc = (bid_cc > 0.0 && ask_cc > 0.0) ? (bid_cc + ask_cc) / 2.0 : bid_cc;

      if(mid_cc > 0.0 && _Point > 0.0)
      {
         // SELL is wrong INTO support below; BUY is wrong INTO resistance above.
         double zone_cc = (dir < 0) ? ZoneMapNearestSupport(mid_cc) : ZoneMapNearestResistance(mid_cc);

         // FIX(counter-zone-single-level): a shelf of several ordinary levels is a wall even when
         // no single member clears CounterZoneBlockMinStrength on its own. Count the whole window.
         double clus_sum = 0.0, clus_near = 0.0;
         int    clus_n = CounterZoneWallCluster(dir, mid_cc, (double)CounterZoneBlockPoints,
                                                clus_sum, clus_near, false);
         bool   cluster_wall = (EnableCounterZoneCluster &&
                                clus_n >= CounterZoneClusterMinLevels &&
                                clus_sum >= CounterZoneClusterMinSum);

         if(zone_cc <= 0.0 && cluster_wall)
            zone_cc = clus_near;      // no qualifying single level, but the shelf is real

         if(zone_cc > 0.0)
         {
            double dist_cc = MathAbs(mid_cc - zone_cc) / _Point;
            double str_cc  = ZoneMapStrength(zone_cc);
            bool   single_wall = (dist_cc <= (double)CounterZoneBlockPoints &&
                                  str_cc >= CounterZoneBlockMinStrength);
            if(single_wall || cluster_wall)
            {
               if(single_wall)
                  why = StringFormat("%s into strong %s it should bounce off (%.2f, str=%.1f, %.0fpts)",
                                     (dir > 0 ? "BUY" : "SELL"),
                                     (dir < 0 ? "support" : "resistance"),
                                     zone_cc, str_cc, dist_cc);
               else
                  why = StringFormat("%s into a %s SHELF - %d levels within %.0fpts, confirmation %.2f (nearest %.2f)",
                                     (dir > 0 ? "BUY" : "SELL"),
                                     (dir < 0 ? "support" : "resistance"),
                                     clus_n, (double)CounterZoneBlockPoints, clus_sum, clus_near);
               // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
               // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
               // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
               // ham entry rad etaverdi: kuchli zonaga qarshi kirish.
               // V194: hold the setup rather than refuse it or shrink it. A trade pointing into a
               // strong zone is EARLY, not wrong - the zone is precisely where the reaction it needs
               // will take place. Arm it, and wait for price to reach the level and be turned away
               // there. That rejection is the confirmation, and it converts the objection into
               // evidence: the trade is then taken at full size because the question was answered.
               // V202: arming comes FIRST, and it applies whether or not this is configured as a hard
               // block. The two were the wrong way round: with CounterZoneHardBlock true the arm
               // branch could never be reached, so the EA only ever refused - the waiting engine
               // built for exactly this situation sat unused.
               //
               // What the hard-block flag now decides is what happens when the wait EXPIRES: with
               // it on, an unconfirmed setup is dropped; with it off, it falls through to a penalty
               // and can still be taken at reduced size. Either way the setup gets its chance to be
               // confirmed by the zone doing what the objection said it would do.
               // FIX(counter-zone-rearm-loop): the arm branch used to run unconditionally and always
               // `return true`. Both ways out of the wait therefore looped straight back into a new
               // wait - on expiry the arm is dropped, execution falls through to here, the wall is
               // still inside the window, and SetupArm() arms it fresh. The documented behaviour in
               // the comment right above ("what the hard-block flag decides is what happens when the
               // wait EXPIRES") was unreachable, and the EA could sit permanently held by a wall it
               // was never going to clear - the same shape as the 18-hour silence.
               // Now: one wait per objection per cooldown. After it expires, this pass falls
               // through to the configured decision - hard block, or penalty and a smaller trade.
               int  cz_fail_slot = (dir > 0) ? 0 : 1;
               bool zone_arm_on_cooldown =
                  (G_ARM_ZONE_FAIL_BAR[cz_fail_slot] >= 0 &&
                   (G_BARS_SEEN - G_ARM_ZONE_FAIL_BAR[cz_fail_slot]) < MathMax(0, CounterZoneReArmCooldownBars));

               if(EnableSetupArming && !zone_arm_on_cooldown)
               {
                  SetupArm(dir, ARM_REASON_ZONE, zone_cc,   // trigger_is_wall = true: this is the OPPOSING wall
                           StringFormat("strong %s at %.2f - waiting for price to clear it",
                                        (dir < 0 ? "support" : "resistance"), zone_cc), true);
                  // Only hold if the arm actually took - SetupArm declines while another objection
                  // is still being worked through, and returning true then would refuse for a
                  // reason this block never recorded.
                  // Require WALL geometry: an ARM_REASON_ZONE arm may already be live from the
                  // zone-edge or liquidity sites, which confirm on the easy dip-and-bounce test.
                  // Returning true on one of those would claim the wall is being handled while a
                  // completely different objection is actually in flight.
                  if(G_ARM_DIR == dir && G_ARM_REASON == ARM_REASON_ZONE && G_ARM_IS_WALL)
                     return true;   // held by the arm engine, not refused
               }

               // FIX(counter-zone-permanent-block): during the cooldown this must NOT hard-block.
               // The wait has already run once and was not answered; repeating the refusal on
               // every bar is how this block produced an unbounded no-trade stretch - and it sits
               // AFTER the BlockSafetyValve and BEFORE G_LAST_ENTRY_ALLOWED_BAR, so the one
               // anti-outage mechanism in the file never releases it and is consumed by it. A
               // setup that has served its wait gets to argue on score instead: the penalty is
               // real (it also shrinks lot and TP through the warning-scaling path), but a strong
               // enough setup can still be taken.
               if(zone_arm_on_cooldown)
               {
                  G_SCORE_PENALTY += CounterZoneScorePenalty;
                  G_PENALTY_QUALITY += CounterZoneScorePenalty;
               }
               else
               {
                  if(CounterZoneHardBlock)
                     return true;
                  G_SCORE_PENALTY += CounterZoneScorePenalty;
                  G_PENALTY_QUALITY += CounterZoneScorePenalty;
               }
            }
         }
      }
   }

   // --- 2. HTF-against: fighting the higher-timeframe trend ---------------------------------
   if(EnableHTFAgainstFirstEntryBlock)
   {
      int htf_dir = DeepHTFTrendDirection();   // fresh read - same source the dashboard's htf= shows

      if(htf_dir != 0 && htf_dir == -dir)
      {
         // Second opinion: the ADX-weighted global read must also be meaningfully against us.
         // Requiring both keeps a shallow HTF slope from vetoing trades on its own.
         string gtc_detail = "";
         double gtc = GlobalTrendConfidence(dir, gtc_detail);

         if(gtc <= -HTFAgainstBlockMinConfidence)
         {
            // Genuine multi-signal reversal overrides the trend block - we still catch real turns.
            string rc_detail = "";
            double rc = ReversalConsensusScore(dir, rc_detail);
            if(rc < HTFAgainstReversalOverride)
            {
// V189: this no longer refuses the entry. It is a real observation - a first entry against a
// confident higher-timeframe trend is worse than one with it - but as a hard block it bypassed
// the score entirely: a live A+ sweep-rejection scoring 11 against a bar of 4 was refused here,
// with every other module in agreement. The reversal override at 0.82 asked reversal setups for
// near-unanimous consensus, which is a standard almost nothing meets.
//
// It now carries weight instead: the penalty goes to the trend group, where the caps decide how
// much it matters alongside everything else, and the accumulated warning shrinks the lot and the
// target. A counter-trend entry still happens - smaller, and asking for less.
G_SCORE_PENALTY += HTFAgainstScorePenalty;
G_PENALTY_TREND_AGAINST += HTFAgainstScorePenalty;

               // FIX(counter-trend-needs-a-reason): the penalty above is the right answer for a
               // counter-trend entry that HAS a reason. It is not the right answer for one that has
               // none. Three tiers, and only the third is refused:
               //   A. reversal consensus rc >= HTFAgainstReversalOverride -> never reaches here.
               //   B. no consensus, but a level BEHIND to lean on -> penalty (and a shorter ladder,
               //      see G_ENTRY_AGAINST_GLOBAL in ChooseLadderShape) - the trade still happens.
               //   C. no consensus AND no level -> a naked bet against a running trend. Refused.
               // The V189 note above is the reason this is NOT a blanket block: an A+ setup scoring
               // 11 against a bar of 4 was once refused here, and that was wrong. So tier C carries
               // its own release - a setup that still clears the bar by CounterTrendExceptionalMargin
               // AFTER the penalty is exceptional by the EA's own measure and is let through. That
               // keeps this from becoming another permanent block, which is the failure mode this
               // file has hit twice.
               G_ENTRY_AGAINST_GLOBAL = true;   // read by ChooseLadderShape - tier B/C shorten the ladder

               if(EnableCounterTrendNeedsReason)
               {
                  string lean_detail = "";
                  bool   has_lean = HasSupportingLevelBehind(dir, lean_detail);

                  // FIX(counter-trend-score-source): use the score of the signal being TESTED. The
                  // queue-replay path calls this before ReplayQueuedSignal() loads the stored
                  // signal, so the live globals belong to the current scan - and in the dominant
                  // sub-case (no opportunity this bar, which is WHY a replay is being tried)
                  // ResetScoreEngine has just zeroed them, making the release impossible for every
                  // queued signal. The caller passes them explicitly there.
                  int  ct_final = (score_final >= 0) ? score_final : G_SCORE_FINAL;
                  int  ct_min   = (score_min   >= 0) ? score_min   : G_SCORE_MIN_REQUIRED;
                  // Mode-normalised: the higher of "clearly above THIS mode's bar" and a fixed
                  // absolute quality floor. AUTO moves the bar between modes (Hunter 2 vs
                  // Balanced 4, plus Hunter's +1 mode bonus), so a purely relative test would
                  // hand the aggressive mode the easier release - backwards.
                  int  ct_bar = MathMax(ct_min + CounterTrendExceptionalMargin,
                                        CounterTrendExceptionalMinScore);
                  bool exceptional = (ct_min > 0 && ct_final >= ct_bar);

                  // FIX(counter-trend-no-valve): this refusal sits AFTER BlockSafetyValve and
                  // BEFORE G_LAST_ENTRY_ALLOWED_BAR is refreshed, so the valve can neither release
                  // it nor even see it - and when the valve opens for some OTHER block it resets
                  // the clock and this still refuses, burning the release for nothing. That is the
                  // exact mechanism behind the 18-hour silence, and a strong global trend on gold
                  // lasts days. Honour the same valve: after BlockSafetyValveBars of unbroken
                  // silence one counter-trend entry goes through and gets judged on its own result.
                  bool ct_valve_open = (EnableBlockSafetyValve && G_LAST_ENTRY_ALLOWED_BAR > 0 &&
                                        (G_BARS_SEEN - G_LAST_ENTRY_ALLOWED_BAR) >= BlockSafetyValveBars);

                  if(!has_lean && !exceptional && !ct_valve_open)
                  {
                     why = StringFormat("%s against a confirmed %s trend with nothing behind it (conf %.2f, rc %.2f<%.2f, score %d, needs %d)",
                                        (dir > 0 ? "BUY" : "SELL"),
                                        (htf_dir > 0 ? "up" : "down"),
                                        gtc, rc, HTFAgainstReversalOverride,
                                        ct_final, ct_bar);
                     if((CounterTrendPrintOnUse && VerboseLogs))
                        PrintFormat("[SIRUS COUNTER-TREND] REFUSED - %s", why);
                     return true;
                  }

                  // FIX(counter-trend-print-per-tick): CoreUpdate runs on every tick, so an
                  // unguarded print here would emit thousands of lines an hour and slow the tester -
                  // the same problem PERF(tester-speed) and FIX(modhealth-per-tick) already fixed
                  // elsewhere. Once per bar per direction is enough to tune from.
                  if((CounterTrendPrintOnUse && VerboseLogs))
                  {
                     static int ct_print_bar[2] = {-1, -1};
                     int ct_ps = (dir > 0) ? 0 : 1;
                     if(ct_print_bar[ct_ps] != G_BARS_SEEN)
                     {
                        ct_print_bar[ct_ps] = G_BARS_SEEN;
                        PrintFormat("[SIRUS COUNTER-TREND] allowed - %s | ladder shortened",
                                    (has_lean ? "tier B: " + lean_detail
                                              : (ct_valve_open
                                                 ? "tier C released by the safety valve"
                                                 : StringFormat("tier C: exceptional score %d >= %d",
                                                                ct_final, ct_bar))));
                     }
                  }
               }

why = StringFormat("-%d %s against HTF trend (htf=%s, conf %.2f, reversal rc=%.2f<%.2f)",
                   HTFAgainstScorePenalty,
                                  (dir > 0 ? "BUY" : "SELL"),
                                  (htf_dir > 0 ? "BUY" : "SELL"),
                                  gtc, rc, HTFAgainstReversalOverride);
               return false;
            }
         }
      }
   }

   // --- 3. Range breakout counter-fade ------------------------------------------------------
   if(EnableRangeBreakout && RangeBreakoutBlockCounterFade)
   {
      string rb_reason = "";
      int rb_dir = RangeBreakoutDirection(rb_reason);
      if(rb_dir != 0 && dir == -rb_dir)
      {
         why = StringFormat("%s fades a confirmed %s (%s)",
                            (dir > 0 ? "BUY" : "SELL"),
                            (rb_dir > 0 ? "upside breakout" : "downside breakdown"),
                            rb_reason);
         // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
         // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
         // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
         // ham entry rad etaverdi: tasdiqlangan breakoutni so'ndirish.
         if(RangeBreakoutHardBlock)
            return true;
         G_SCORE_PENALTY += RangeBreakoutFadePenalty;
         G_PENALTY_TREND_AGAINST += RangeBreakoutFadePenalty;
      }
   }

   // --- 4. Gap-fill magnet: don't fight the pull back toward a large unfilled gap ---------------
   // If a big gap is still open, price tends to drift toward its fill level. An entry AGAINST that
   // pull (e.g. BUY while price is being pulled DOWN to fill a gap below) fights the dominant force.
   // Only hard-blocks here when configured to; otherwise the score engine applies a penalty below.
   if(EnableGapFillMagnet && GapFillMagnetHardBlock && G_GAP_FILL_DIR != 0 && dir == -G_GAP_FILL_DIR)
   {
      why = StringFormat("%s against gap-fill pull (%s toward %.2f)",
                         (dir > 0 ? "BUY" : "SELL"),
                         (G_GAP_FILL_DIR < 0 ? "down" : "up"),
                         G_GAP_FILL_LEVEL);
      return true;
   }

   // --- 5. Collapse/spike-bottom: don't continue a fast move into its likely snap-back ----------
   // If price just fell hard and fast, a SELL at the bottom continues into the reversal; likewise a
   // BUY at the top of a fast spike. dir == move_dir means we'd be adding in the move's direction,
   // right at the extreme it just reached.
   if(EnableCollapseBottomGuard && CollapseGuardHardBlock)
   {
      int move_dir = CollapseBottomMoveDir();
      if(move_dir != 0 && dir == move_dir)
      {
         why = StringFormat("%s continues a fast %s into its likely snap-back",
                            (dir > 0 ? "BUY" : "SELL"),
                            (move_dir > 0 ? "spike top" : "collapse bottom"));
         return true;
      }
   }

   // --- 6. Ghost zones: don't enter continuing INTO a recently-broken H1/H4/D1 level -----------
   // Price often reacts when it returns to a level it broke. If an entry would run straight into an
   // active ghost (BUY up into a broken-support-now-resistance, or SELL down into a broken-
   // resistance-now-support), hold off - a reversal there is likely. Only HARD-blocks here when
   // configured to; by default a ghost is a probability, so the score engine applies a penalty.
   if(EnableGhostZones && GhostZoneHardBlock)
   {
      int ghost_dir = GhostZoneReactionDir();
      if(ghost_dir != 0 && dir == ghost_dir)
      {
         why = StringFormat("%s runs into a ghost zone (recently-broken level likely to react)",
                            (dir > 0 ? "BUY" : "SELL"));
         return true;
      }
   }

   // --- 7. Counter-impulse: don't enter AGAINST a strong impulse that is still running ----------
   // A spike or sustained impulse that is still pushing (not yet exhausted) will usually continue;
   // opposing it now is the screenshot loss (SELL into a live up-thrust). Block the opposing first
   // entry unless the impulse already shows exhaustion, in which case a reversal is reasonable.
   if(EnableCounterImpulseBlock && CounterImpulseHardBlock)
   {
      int imp_dir = SpikeImpulseDir();
      if(imp_dir == 0)
         imp_dir = SustainedImpulseDir();
      bool from_thrust = false;
      if(imp_dir == 0)
      {
         imp_dir = RecentThrustDir();   // FEATURE(recent-thrust): the middle band - price thrusting into a level over the last ~15 min
         from_thrust = (imp_dir != 0);
      }

      if(imp_dir != 0 && dir == -imp_dir)
      {
         // Use the exhaustion test that matches the detector which supplied the direction: the
         // sustained test is hard-wired to its own long window and would never fire for a thrust.
         int exh_dir = from_thrust ? RecentThrustExhaustedDir() : SustainedImpulseExhaustedDir();
         bool exhausted = (exh_dir == imp_dir);   // impulse in imp_dir is stalling

         // V176: an impulse also stops being "active" simply by getting old. The exhaustion test
         // requires a rejection wick of 45% of the bar's range, which a move that fades quietly
         // never produces - so a sustained impulse measured over sixteen M15 bars could hold this
         // block for four hours while price did nothing at all. Live: half an hour of silence with
         // "BUY opposes an active down impulse" as the only reason.
         //
         // The age test is separate from exhaustion on purpose. Exhaustion says the move was
         // rejected; age says it has stopped being news. Both should release the block.
         // V177c: track how long THIS block has been holding, rather than reading
         // G_LAST_IMPULSE_BAR - that marker belongs to MARKET_IMPULSE state, which is a different
         // detector on a different timeframe. A sustained impulse measured over sixteen M15 bars can
         // be blocking while MARKET_IMPULSE was never set at all, in which case the age test read a
         // stale or zero marker and never fired.
         //
         // Counting from when the block first engaged is what the release actually needs to know.
         static int block_started_bar = -1;
         static int block_dir = 0;
         if(block_started_bar > G_BARS_SEEN) block_started_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

         if(block_dir != imp_dir)
         {
            block_dir = imp_dir;
            block_started_bar = G_BARS_SEEN;
         }

         if(!exhausted && CounterImpulseMaxAgeBars > 0 && block_started_bar >= 0)
         {
            int held = G_BARS_SEEN - block_started_bar;
            if(held > CounterImpulseMaxAgeBars)
            {
               exhausted = true;   // held long enough that it no longer describes the current market
               if((CounterImpulsePrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v177c IMPULSE] block released after %d bars (limit %d) - the move is history, not a live threat",
                              held, CounterImpulseMaxAgeBars);
            }
         }

         if(!exhausted)
         {
            why = StringFormat("%s opposes an active %s impulse (not yet exhausted)",
                               (dir > 0 ? "BUY" : "SELL"),
                               (imp_dir > 0 ? "up" : "down"));
            // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
            // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
            // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
            // ham entry rad etaverdi: faol impulsga qarshi.
            // V195: an impulse running the other way is a TIMING objection - the direction may well
            // be right, the moment is not. Fading a live impulse is how a scalp becomes a grid;
            // fading a spent one is a reversal trade. Arm it and wait for the impulse to exhaust:
            // the confirmation is a pullback that stops going and turns back our way.
            // V202: same correction as the counter-zone case - arming runs regardless of the
            // hard-block flag, which now only decides what happens if the wait expires unconfirmed.
            if(EnableSetupArming)
            {
               double arm_px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(arm_px > 0.0 &&
                  SetupArm(dir, ARM_REASON_EXTENDED, arm_px,
                           StringFormat("%s impulse still running - waiting for it to spend itself",
                                        (imp_dir > 0 ? "up" : "down")), false))
                  return true;
            }
            if(CounterImpulseHardBlock)
               return true;
            G_SCORE_PENALTY += CounterImpulseScorePenalty;
            G_PENALTY_IMPULSE += CounterImpulseScorePenalty;
         }
      }
   }

   // --- 8. Correction exhaustion: don't fade the main trend at the top of a tiring correction ------
   // Main trend = the last impulse direction. A sizeable counter-trend correction that is now
   // stalling (rejection wick against it) is about to hand the market back to the main trend, so an
   // entry in the CORRECTION's direction (i.e. against the main trend) is the right-hand screenshot
   // loss. Block it. dir opposes the impulse (dir == -impulse_dir) means the entry rides the
   // correction; require a sizeable retrace and a rejection wick to confirm the correction is topping.
   if(EnableCorrectionExhaustion && CorrectionExhaustionHardBlock &&
      G_LAST_IMPULSE_DIRECTION != 0 && dir == -G_LAST_IMPULSE_DIRECTION && _Point > 0.0)
   {
      int imp_age = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
      if(imp_age >= 0 && imp_age <= MathMax(1, CorrectionExhaustionWindowBars))
      {
         double retrace = ImpulseCorrectionRetracePercent();
         if(retrace >= CorrectionExhaustionMinRetrace)
         {
            // Rejection wick AGAINST the correction on the latest closed SignalTF bar. Correction is
            // up (main trend down) -> look for an upper wick; correction down -> lower wick.
            double range = CandleRangePoints(SignalTF, 1);
            if(range > 0.0)
            {
               // correction direction = -impulse direction = dir (entry rides it)
               double against_wick = (dir > 0) ? UpperWickPoints(SignalTF, 1)   // up correction rejected from above
                                               : LowerWickPoints(SignalTF, 1);  // down correction rejected from below
               if((against_wick / range) >= CorrectionExhaustionWickRatio)
               {
                  why = StringFormat("%s fades the main %s trend at a tiring correction top (retrace %.0f%%)",
                                     (dir > 0 ? "BUY" : "SELL"),
                                     (G_LAST_IMPULSE_DIRECTION > 0 ? "up" : "down"), retrace);
                  // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
                  // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
                  // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
                  // ham entry rad etaverdi: charchagan korreksiyada trendga qarshi.
                  if(CorrectionExhaustionHardBlock)
                     return true;
                  G_SCORE_PENALTY += CorrectionExhaustionPenalty;
                  G_PENALTY_IMPULSE += CorrectionExhaustionPenalty;
               }
            }
         }
      }
   }

   // --- 9. Recent extreme: don't enter WITH a move that has just reached its exhausted extreme ------
   // General companion to the impulse blocks: measure the net move over a short recent window; if the
   // current price sits in the extreme quarter in the move's direction AND the latest bar shows a
   // rejection wick against the move, entering in the move direction is buying the top / selling the
   // bottom. Catches the left-hand screenshot (sold into the bottom) even when it isn't a "sustained"
   // impulse. Direction of the move is inferred from the window; block only entries WITH that move.
   if(EnableRecentExtremeBlock && RecentExtremeHardBlock && _Point > 0.0)
   {
      int win = MathMax(3, RecentExtremeWindowBars);
      double c_now   = CandleClose(SignalTF, 1);
      double c_start = CandleClose(SignalTF, win);
      double hi = HighestHigh(SignalTF, win, 1);
      double lo = LowestLow(SignalTF, win, 1);
      double rng = hi - lo;

      if(c_now > 0.0 && c_start > 0.0 && rng > 0.0)
      {
         double net_pts = MathAbs(c_now - c_start) / _Point;
         int move_dir = (c_now > c_start) ? 1 : -1;   // up move or down move over the window

         // Only when the entry is WITH the move (dir == move_dir) and the move is sizeable.
         if(dir == move_dir && net_pts >= RecentExtremeMinMovePoints)
         {
            // Near the extreme in the move direction? up move -> near the high; down move -> near low.
            double near_frac = (move_dir > 0) ? (hi - c_now) / rng    // small = near high
                                              : (c_now - lo) / rng;   // small = near low
            double near_limit = MathMax(0.0, MathMin(1.0, RecentExtremeNearPercent / 100.0));

            double range = CandleRangePoints(SignalTF, 1);
            double against_wick = (move_dir > 0) ? UpperWickPoints(SignalTF, 1)   // up move rejected from above
                                                 : LowerWickPoints(SignalTF, 1);  // down move rejected from below

            if(near_frac <= near_limit && range > 0.0 && (against_wick / range) >= RecentExtremeWickRatio)
            {
               why = StringFormat("%s enters with a %s move at its exhausted extreme (net %.0f pts, rejection wick)",
                                  (dir > 0 ? "BUY" : "SELL"), (move_dir > 0 ? "up" : "down"), net_pts);
               // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
               // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
               // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
               // ham entry rad etaverdi: charchagan ekstremumda kirish.
               if(RecentExtremeHardBlock)
                  return true;
               G_SCORE_PENALTY += RecentExtremePenalty;
               G_PENALTY_IMPULSE += RecentExtremePenalty;
            }
         }
      }
   }

   // --- 10. Market structure: don't trade against a confirmed swing chain -----------------------
   // Only active when MarketStructureHardBlock is enabled (default off - the score penalty is the
   // gentler default). A confirmed chain of higher highs + higher lows means buyers control the
   // structure itself; selling into that is fighting the market's own sequence.
   if(EnableMarketStructure && MarketStructureHardBlock)
   {
      MarketStructureRead();
      // A CHoCH means this structure has already failed, so an "against" entry is the reversal -
      // blocking it there would lock the EA out of every turn. Only block while the chain still holds.
      bool structure_still_holds = !(G_STRUCTURE_EVENT == -1 && MarketStructureCHoCHReleases);
      // Same exception as the score path: if the trading-TF chain is only a pullback inside a higher
      // structure the entry agrees with, this is a dip entry, not a fight with the market.
      bool pullback_with_htf = (EnableStructureHTF && G_STRUCTURE_HTF_DIR != 0 &&
                                dir == G_STRUCTURE_HTF_DIR);
      if(G_STRUCTURE_DIR != 0 && dir == -G_STRUCTURE_DIR && structure_still_holds && !pullback_with_htf)
      {
         why = StringFormat("%s fights the %s", (dir > 0 ? "BUY" : "SELL"), G_STRUCTURE_DETAIL);
         return true;
      }
   }
   // --- 11. Fresh-impulse cooldown for FIRST ENTRIES --------------------------------------------
   // The same wait GridCanOpen applies after an impulse bar. Opening a NEW basket into a just-printed
   // impulse is the worst version of this: the fill sits at the extreme of the move, spread is at its
   // widest, and a snap-back hits a position that has no averaging behind it yet. Trend-aligned
   // impulses get the longer wait (they can accelerate), corrections the shorter one.
   if(EntryBlockFreshImpulse && EnableImpulseCooldown && G_LAST_IMPULSE_BAR > -100000)
   {
      int bars_since = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
      int need = (EntryImpulseCooldownBars > 0)
                 ? EntryImpulseCooldownBars
                 : (G_LAST_IMPULSE_TREND_ALIGNED ? ImpulseCooldownBarsTrend : ImpulseCooldownBarsCorrection);

      if(bars_since >= 0 && bars_since < need)
      {
         why = StringFormat("waiting out a fresh impulse (%d/%d bars, %s)",
                            bars_since, need,
                            (G_LAST_IMPULSE_TREND_ALIGNED ? "trend-aligned" : "correction"));
         // V190: bu blok endi o'z HardBlock flagini TEKSHIRADI. Ilgari tekshirmasdi - flag mavjud edi
         // va false qilingan edi, lekin kod unga qaramasdi, ya'ni o'chirish hech narsani o'zgartirmasdi.
         // Oltita blok shu holatda ishlagan, va aynan shuning uchun bot bloklar "o'chirilgandan" keyin
         // ham entry rad etaverdi: yangi impulsni kutish.
         if(FreshImpulseWaitHardBlock)
            return true;
         G_SCORE_PENALTY += FreshImpulseWaitPenalty;
         G_PENALTY_IMPULSE += FreshImpulseWaitPenalty;
      }
   }
   // --- 12. Room to target: refuse trades opened into a wall ------------------------------------
   // Only active when RoomHardBlock is enabled (default off - the score penalty is the softer
   // default). A trade with less space in front of it than its own target needs cannot reach that
   // target without breaking the level first, so taking it is betting on the break, not the scalp.
   if(EnableRoomCheck && RoomHardBlock)
   {
      string rb_detail = "";
      double rb_room = RoomToTargetPoints(dir, rb_detail);
      double rb_needed = BaseBasketTPPoints() * MathMax(0.1, RoomMinFactor);

      if(rb_room < rb_needed)
      {
         why = StringFormat("%s has no room - %s, target needs %.0f pts",
                            (dir > 0 ? "BUY" : "SELL"), rb_detail, rb_needed);
         return true;
      }
   }
   // --- 13. Zone role undefined: price is inside a band, not at its edge ------------------------
   // With an opposing level on BOTH sides within a short distance, price is inside a zone band. The
   // EA's role logic (above price = resistance, below = support) has no meaning there: it births a
   // buy and a sell signal simultaneously and the higher score wins by accident. Direction-agnostic
   // by design - neither side is valid until price leaves the band and respects an edge.
   if(EnableZoneRoleCheck && ZoneRoleHardBlock)
   {
      string zr_detail = "";
      if(ZoneRoleAmbiguous(zr_detail))
      {
         why = StringFormat("%s: %s", (dir > 0 ? "BUY" : "SELL"), zr_detail);
         if((ZoneRolePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v119 ZONE ROLE] blocked %s - %s", (dir > 0 ? "BUY" : "SELL"), zr_detail);
         return true;
      }
   }
   return false;
}

void UpdateSignalScoreEngine(const string source)
{
   // FIX(counter-trend-flag-stale): ResetScoreEngine() clears this, but it is only reached on the
   // two EARLY-RETURN paths below - so on any scan that actually finds an opportunity the flag was
   // never cleared at the top. It could then survive from a counter-trend read into a later,
   // WITH-trend basket and cap that basket's ladder to 3 rungs for no reason (and the queue's
   // "test" call sets it as a pure side effect even when the replay is refused). Cleared here, on
   // every entry into the scan, so it describes only the pass that set it.
   G_ENTRY_AGAINST_GLOBAL = false;

   if(!UseSignalScoreEngine)
   {
      ResetScoreEngine("score engine disabled");
      return;
   }

   if(G_OPP_GRADE == OPP_GRADE_NONE || G_OPP_DIR == OPP_DIR_NONE)
   {
      ResetScoreEngine("no opportunity");
      return;
   }

   string hard_reason = "";
   bool hard_blocked = ScoreHardBlockCheck(hard_reason);

   // V180: a safety valve over every hard block. Most of them release on a market condition -
   // price leaving a band, an impulse exhausting, a spread narrowing - and each is individually
   // reasonable. What none of them can see is the others: with eight blocks live, one condition
   // can hand over to the next and the EA sits out for hours without any single check being wrong.
   //
   // Silence past this limit is treated as evidence that the block set has stopped describing the
   // market rather than protecting against it, and ONE entry is allowed through so the position can
   // be judged on its own merits. The blocks themselves are untouched - this only stops them from
   // compounding into an indefinite halt.
   if(hard_blocked && EnableBlockSafetyValve)
   {
      // On a fresh start there is no previous entry to measure from, so the clock begins at the
      // first blocked bar instead. Without this the valve would never open on an EA that was
      // blocked from the moment it was attached - which is exactly the case it exists for.
      if(G_LAST_ENTRY_ALLOWED_BAR <= 0)
         G_LAST_ENTRY_ALLOWED_BAR = G_BARS_SEEN;

      int silent_bars = G_BARS_SEEN - G_LAST_ENTRY_ALLOWED_BAR;
      if(silent_bars >= BlockSafetyValveBars)
      {
         if((BlockSafetyValvePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v180 SAFETY VALVE] %d bars with no entry permitted - releasing one. Last block: %s",
                        silent_bars, hard_reason);
         hard_blocked = false;
         G_LAST_ENTRY_ALLOWED_BAR = G_BARS_SEEN;   // restart the clock
      }
   }

   if(hard_blocked)
   {
      G_FUNNEL_HARD_BLOCK++;
      G_SCORE_DECISION = SCORE_DECISION_HARD_BLOCK;
      // V157: record the refusal so where price went next can be checked - a block is a
      // hypothesis and this is the only way it ever gets tested.
      {
         double ba_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ba_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double ba_mid = (ba_bid > 0.0 && ba_ask > 0.0) ? (ba_bid + ba_ask) / 2.0 : ba_bid;
         // entry_dir_i is derived later in this function, so read the direction from the
         // opportunity itself - it is already resolved by the time a block can fire.
         int ba_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
         if(ba_mid > 0.0 && ba_dir != 0)
            BlockAuditRecord(ba_dir, ba_mid);
      }
      G_SCORE_HARD_BLOCK = hard_reason;
      G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + hard_reason;
      G_SCORE_DETAIL = "SCORE DETAIL: hard block is reserved only for real risk";
      G_SCORE_BASE = G_OPP_SCORE;
      G_SCORE_BONUS = 0;
      G_SCORE_PENALTY = 0;
      G_SCORE_FINAL = G_OPP_SCORE;
      G_SCORE_MIN_REQUIRED = 0;
      return;
   }

   G_SCORE_IS_MICRO = IsMicroOpportunity();
   G_SCORE_TP_TARGET = G_SCORE_IS_MICRO ? MicroTPPoints() : MainTPPoints();
   G_SCORE_ROOM_POINTS = ComputeRoomToTP();

   G_SCORE_BASE = G_OPP_SCORE;
   G_SCORE_BONUS = 0;
   G_SCORE_PENALTY = 0;
   // V156: volatile and quiet markets both justify demanding more before committing - one because
   // moves are unreliable, the other because they may not travel far enough to reach the target.
   G_SCORE_MIN_REQUIRED = MinScoreForContext(G_SCORE_IS_MICRO) + RegimeScoreOffset();

   // V31.6z NEW: reversal-type signals (Sweep, FBR, Near-Zone, Exhaustion, Range Edge) carry
   // more downstream risk in a grid system than continuation-type ones - if wrong, grid ends
   // up fighting a real trend. Hold them to a slightly higher bar rather than treating every
   // signal type identically (a gap found during the professional strategy audit).
   if(EnableReversalRiskDifferentiation && IsReversalOpportunityType(G_OPP_TYPE))
      G_SCORE_MIN_REQUIRED += MathMax(0, ReversalTypeExtraScoreReq);

   string detail = "base from scanner=" + IntegerToString(G_SCORE_BASE) + ";";

   // V194: before anything else - has an armed setup just been confirmed? If so it goes straight
   // through with a bonus, because a setup that waited for its objection to be answered is stronger
   // than one that never faced the objection at all.
   // FIX(arm-confirm-deadlock): remembers that THIS pass just confirmed an armed setup, so the
   // counter-context block further down cannot immediately re-arm and hard-block the very trade
   // the wait was held for. See the full explanation at that check.
   int arm_confirmed_dir = 0;
   if(EnableSetupArming && G_ARM_DIR != 0)
   {
      string arm_detail = "";
      // AUDIT FIX (A9): SetupArmConfirmed() itself clears the arm on its FILL / LATE confirmations, so
      // everything is captured first - and the +bonus goes only to the side that was armed. A BUY arm
      // confirming on a scan whose best setup is now SELL used to hand the SELL the BUY's bonus.
      int    armed_dir    = G_ARM_DIR;
      int    armed_bar    = G_ARM_BAR;
      int    armed_reason = G_ARM_REASON;
      string armed_text   = G_ARM_TEXT;
      int    cur_dir      = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(SetupArmConfirmed(arm_detail))
      {
         double ja_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ja_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double ja_mid = (ja_bid > 0.0 && ja_ask > 0.0) ? (ja_bid + ja_ask) / 2.0 : ja_bid;
         if(armed_dir == cur_dir)
         {
            arm_confirmed_dir = armed_dir;
            // V197: record what this wait produced, and arm the judgement of what follows.
            ArmRecordOutcome(armed_reason, 1, G_BARS_SEEN - armed_bar);
            ArmJudgeArm(armed_reason, armed_dir, ja_mid);
            G_SCORE_BONUS += SetupArmScoreBonus;
            detail += StringFormat(" +%d confirmed: %s;", SetupArmScoreBonus, arm_detail);
            if((SetupArmPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v194 ARMED] CONFIRMED - %s | %s", armed_text, arm_detail);
         }
         else if((SetupArmPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS ARMED] %s confirmed, but this scan's setup is the other side - no bonus | %s",
                        armed_text, arm_detail);
         SetupArmClear();
      }
   }


   // FEATURE(firstentry-reversal-consensus): for reversal-type entries ONLY, confirm the turn with
   // the multi-signal consensus. Bonus when 2+ signals agree, penalty when they don't. Runs only
   // for reversal types, so trend/breakout/momentum entries are never affected.
   if(EnableFirstEntryReversalConsensus && IsReversalOpportunityType(G_OPP_TYPE) &&
      (G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL))
   {
      int fe_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      string fe_rc_detail = "";
      double fe_rc = ReversalConsensusScore(fe_dir, fe_rc_detail);

      if(fe_rc >= FirstEntryConsensusMinScore)
      {
         G_SCORE_BONUS += MathMax(0, FirstEntryConsensusBonus);
         detail += StringFormat(" +%d revConsensus(%.2f);", MathMax(0, FirstEntryConsensusBonus), fe_rc);
         if((FirstEntryConsensusPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS FIRST-ENTRY CONSENSUS] %s confirmed by consensus %.2f - %s",
                        OpportunityTypeToString(G_OPP_TYPE), fe_rc, fe_rc_detail);
      }
      else
      {
         G_SCORE_PENALTY += MathMax(0, FirstEntryConsensusPenalty);
         detail += StringFormat(" -%d noRevConsensus(%.2f);", MathMax(0, FirstEntryConsensusPenalty), fe_rc);
      }
   }

   // FEATURE(range-breakout): reward a first entry taken WITH a confirmed breakout - trading the
   // break instead of fading it. Small score bonus, not a forced entry; the counter-fade block
   // below still stops entries against the break.
   if(EnableRangeBreakout && RangeBreakoutAllowWithEntry &&
      (G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL))
   {
      string rbw_reason = "";
      int rbw_dir = RangeBreakoutDirection(rbw_reason);
      int rbw_entry = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      if(rbw_dir != 0 && rbw_entry == rbw_dir)
      {
         G_SCORE_BONUS += 2;
         detail += " +2 withBreakout;";
      }
   }

   if(UseAntiOverfilterSystem)
      ApplyAntiOverfilterScoring(G_SCORE_BONUS, G_SCORE_PENALTY, detail);
   else
      detail += " anti-overfilter disabled;";

   int v31_brain_penalty = 0; // V31.2: yangi aql-modullari penaltilarini kuzatish

   // V30.1 new: multi-timeframe confirmation as SCORE adjust (never a hard block).
   if(EnableMTFConfirm)
   {
      int mtf_dir = MTFTrendDirection();
      int opp_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));

      if(mtf_dir != 0 && opp_dir != 0)
      {
         if(mtf_dir == opp_dir)
         {
            G_SCORE_BONUS += MathMax(0, MTFConfirmBonus);
            detail += StringFormat(" +%d MTF trend aligned;", MathMax(0, MTFConfirmBonus));
         }
         else
         {
            G_SCORE_PENALTY += MathMax(0, MTFConfirmPenalty);
            v31_brain_penalty += MathMax(0, MTFConfirmPenalty);
            detail += StringFormat(" -%d MTF counter-trend;", MathMax(0, MTFConfirmPenalty));
         }
      }
      else
         detail += " MTF neutral;";

      // V31.6z47 fix: real gap found via decision-flow audit - MTFAlignmentConfidence (the
      // magnitude-aware MTF reading built this session) was only ever wired into Grid
      // Intelligence, never into First Entry. The check above uses MTFTrendDirection() which
      // is direction-only: a barely-trending set of timeframes and a strongly ADX-confirmed
      // one scored identically. This adds the magnitude layer here too, so entry decisions get
      // the same depth of MTF reading that grid additions already had.
      if(EnableMTFConfidence)
      {
         int opp_dir_mc = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
         if(opp_dir_mc != 0)
         {
            string mtf_conf_detail_e = "";
            double mtf_conf_e = MTFAlignmentConfidence(opp_dir_mc, mtf_conf_detail_e);

            if(mtf_conf_e >= MTFConfidenceStrongLevel)
            {
               G_SCORE_BONUS += MTFConfidenceScoreAdjust;
               G_BONUS_TREND_ALIGN += MTFConfidenceScoreAdjust;   // V134: multi-timeframe agreement is the same "trend agrees" fact
               detail += StringFormat(" +%d %s;", MTFConfidenceScoreAdjust, mtf_conf_detail_e);
            }
            else if(mtf_conf_e <= -MTFConfidenceStrongLevel)
            {
               G_SCORE_PENALTY += MTFConfidenceScoreAdjust;
               v31_brain_penalty += MTFConfidenceScoreAdjust;
               detail += StringFormat(" -%d %s;", MTFConfidenceScoreAdjust, mtf_conf_detail_e);
            }
         }
      }
   }

   // V31.6z49 NEW: DIRECTIONAL CLARITY. Direct response to the user's observation that first-
   // entry errors are a main driver of long drawdowns. The scanner's winner-takes-all pick
   // hides a crucial distinction: was this direction the ONLY story the market was telling, or
   // did the opposite side score nearly as high at the same moment? A 7-vs-nothing setup and a
   // 7-vs-6 setup arrive here looking identical, but the second means the market is genuinely
   // ambiguous - both directions "look right" simultaneously - and that is exactly the kind of
   // entry most likely to go wrong and then sit in drawdown. Scales with how close the losing
   // side came: a near-tie is penalized hardest, a comfortable margin barely at all.
   if(EnableDirectionalClarity)
   {
      int own_score = (G_OPP_DIR == OPP_DIR_BUY) ? G_OPP_BEST_BUY_SCORE : G_OPP_BEST_SELL_SCORE;
      int opp_score = (G_OPP_DIR == OPP_DIR_BUY) ? G_OPP_BEST_SELL_SCORE : G_OPP_BEST_BUY_SCORE;

      if(own_score > 0 && opp_score >= DirectionalClarityMinOpposingScore)
      {
         int margin = own_score - opp_score;
         if(margin <= DirectionalClarityMaxMargin)
         {
            // Closer margin = stronger ambiguity = bigger penalty (non-linear, matching the
            // consensus philosophy used throughout the rest of the system).
            double ambiguity = 1.0 - (double)MathMax(0, margin) / MathMax(1.0, (double)DirectionalClarityMaxMargin + 1.0);
            int clarity_penalty = (int)MathRound(ambiguity * DirectionalClarityMaxPenalty);
            if(clarity_penalty > 0)
            {
               G_SCORE_PENALTY += clarity_penalty;
               v31_brain_penalty += clarity_penalty;
               detail += StringFormat(" -%d AMBIGUOUS(own=%d vs opposing=%d, margin=%d);",
                                      clarity_penalty, own_score, opp_score, margin);

               if((DirectionalClarityPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v31.6z49 DIRECTIONAL CLARITY] both sides scored: %s=%d vs opposing=%d margin=%d -> -%d",
                              (G_OPP_DIR == OPP_DIR_BUY ? "BUY" : "SELL"), own_score, opp_score, margin, clarity_penalty);
            }
         }
      }
   }

   // V30.5 new: Bayes detector-performance score adjust. BayesWinRate() returns 0.5
   // until BayesMinSamples is reached, so young detectors stay neutral automatically.
   if(EnableBayesScoreAdjust)
   {
      double bayes_wr = BayesWinRate((int)G_OPP_TYPE);
      if(bayes_wr >= BayesScoreGoodWinrate)
      {
         G_SCORE_BONUS += MathMax(0, BayesScoreBonus);
         detail += StringFormat(" +%d Bayes wr=%.2f;", MathMax(0, BayesScoreBonus), bayes_wr);
      }
      else if(bayes_wr <= BayesScoreBadWinrate)
      {
         G_SCORE_PENALTY += MathMax(0, BayesScorePenalty);
         v31_brain_penalty += MathMax(0, BayesScorePenalty);
         detail += StringFormat(" -%d Bayes wr=%.2f;", MathMax(0, BayesScorePenalty), bayes_wr);
      }
      else
         detail += StringFormat(" Bayes neutral wr=%.2f;", bayes_wr);
   }

   // V31.1 SOAT-BAYES: joriy soat statistikasi bo'yicha score sozlash.
   if(EnableHourBayes)
   {
      MqlDateTime hb_dt;
      TimeToStruct(TimeCurrent(), hb_dt);
      double hb_wr = HourBayesWinRate(hb_dt.hour);
      if(hb_wr >= HourBayesGoodWinrate)
      {
         G_SCORE_BONUS += MathMax(0, HourBayesBonus);
         detail += StringFormat(" +%d hour%02d wr=%.2f;", MathMax(0, HourBayesBonus), hb_dt.hour, hb_wr);
      }
      else if(hb_wr <= HourBayesBadWinrate)
      {
         G_SCORE_PENALTY += MathMax(0, HourBayesPenalty);
         v31_brain_penalty += MathMax(0, HourBayesPenalty);
         detail += StringFormat(" -%d hour%02d wr=%.2f;", MathMax(0, HourBayesPenalty), hb_dt.hour, hb_wr);
      }
   }

   // V31.6j DAY-OF-WEEK BAYES: joriy kun statistikasi bo'yicha score sozlash.
   if(EnableDayOfWeekBayes)
   {
      MqlDateTime dow_dt;
      TimeToStruct(TimeCurrent(), dow_dt);
      double dow_wr = DayOfWeekBayesWinRate(dow_dt.day_of_week);
      if(dow_wr >= HourBayesGoodWinrate)
      {
         G_SCORE_BONUS += MathMax(0, DayOfWeekBayesBonus);
         detail += StringFormat(" +%d dow%d wr=%.2f;", MathMax(0, DayOfWeekBayesBonus), dow_dt.day_of_week, dow_wr);
      }
      else if(dow_wr <= HourBayesBadWinrate)
      {
         // FIX(dow-bayes-penalty): was DayOfWeekBayesBonus (copy-paste from the bonus branch above) -
         // now uses the dedicated DayOfWeekBayesPenalty input, matching the HourBayes pair's pattern.
         G_SCORE_PENALTY += MathMax(0, DayOfWeekBayesPenalty);
         v31_brain_penalty += MathMax(0, DayOfWeekBayesPenalty);
         detail += StringFormat(" -%d dow%d wr=%.2f;", MathMax(0, DayOfWeekBayesPenalty), dow_dt.day_of_week, dow_wr);
      }
   }

   // FEATURE(daily-bias): reward entries that agree with the previous-day bias, temper those
   // that fight it. Bias is CONTEXT, so this is a small score nudge, never a hard block - it can
   // tilt a borderline decision but can't single-handedly force or forbid a trade.
   if(EnableDailyBias && EnableDailyBiasScore && G_DAILY_BIAS != 0)
   {
      int db_dir_i = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
      if(db_dir_i != 0)
      {
         if(db_dir_i == G_DAILY_BIAS)
         {
            G_SCORE_BONUS += MathMax(0, DailyBiasScoreBonus);
            detail += StringFormat(" +%d dailyBias(%s);", MathMax(0, DailyBiasScoreBonus),
                                   (G_DAILY_BIAS > 0 ? "bull" : "bear"));
         }
         else
         {
            G_SCORE_PENALTY += MathMax(0, DailyBiasScorePenalty);
            v31_brain_penalty += MathMax(0, DailyBiasScorePenalty);
            detail += StringFormat(" -%d vs dailyBias(%s);", MathMax(0, DailyBiasScorePenalty),
                                   (G_DAILY_BIAS > 0 ? "bull" : "bear"));
         }
      }
   }

   // V31.1 ADR FILTRI: kun diapazoni tugagan bo'lsa, bugungi harakat YO'NALISHIDAGI
   // (davom) entrylarga penalti. Teskari (mean-reversion) entrylarga tegilmaydi.
   if(EnableADRFilter)
   {
      // V31.2 speed: ADR bar ichida o'zgarishi sekin - bar boshiga bir marta hisoblanadi.
      static int    adr_cache_bar = -1;
      static double adr_used_c    = 0.0;
      static int    adr_dir_c     = 0;
      if(adr_cache_bar > G_BARS_SEEN) adr_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
      if(adr_cache_bar != G_BARS_SEEN)
      {
         adr_used_c = ADRUsedPercent(adr_dir_c);
         adr_cache_bar = G_BARS_SEEN;
      }

      int opp_dir_i = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));

      if(adr_used_c >= ADRExhaustPercent && adr_dir_c != 0 && opp_dir_i == adr_dir_c)
      {
         G_SCORE_PENALTY += MathMax(0, ADRPenalty);
         v31_brain_penalty += MathMax(0, ADRPenalty);
         detail += StringFormat(" -%d ADR exhausted %.0f%%;", MathMax(0, ADRPenalty), adr_used_c);
      }
   }

   // V31.1 DXY SCORE: dollar proxy trendi entry yo'nalishiga qarshi bo'lsa penalti, mos bo'lsa bonus.
   if(EnableDXYProxy && DXYProxyScoreAdjust)
   {
      // V31.2 speed: DXY H1 slope bar ichida sekin o'zgaradi - bar boshiga bir marta.
      static int dxy_cache_bar = -1;
      static int dxy_dir_c     = 0;
      if(dxy_cache_bar > G_BARS_SEEN) dxy_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
      if(dxy_cache_bar != G_BARS_SEEN)
      {
         string dxy_reason = "";
         dxy_dir_c = DXYProxyDirection(dxy_reason);
         dxy_cache_bar = G_BARS_SEEN;
      }

      if(dxy_dir_c != 0)
      {
         int price_effect = DXYProxyInverseRelationship ? -dxy_dir_c : dxy_dir_c;
         int opp_dir_d = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
         if(opp_dir_d != 0)
         {
            if(price_effect == opp_dir_d)
            {
               G_SCORE_BONUS += MathMax(0, DXYProxyScoreBonus);
               detail += StringFormat(" +%d DXY aligned;", MathMax(0, DXYProxyScoreBonus));
            }
            else
            {
               G_SCORE_PENALTY += MathMax(0, DXYProxyScorePenalty);
               v31_brain_penalty += MathMax(0, DXYProxyScorePenalty);
               detail += StringFormat(" -%d DXY against;", MathMax(0, DXYProxyScorePenalty));
            }
         }
      }
   }

   if(UseDynamicScoreThreshold)
   {
      if(G_MARKET_STATE == MARKET_DEAD && !G_SCORE_IS_MICRO)
      {
         G_SCORE_MIN_REQUIRED += 1;
         detail += " +1 min dead market;";
      }
      if(G_MARKET_STATE == MARKET_RANGE && G_SCORE_IS_MICRO)
      {
         G_SCORE_MIN_REQUIRED = MathMax(1, G_SCORE_MIN_REQUIRED - 1);
         detail += " -1 min micro range;";
      }
      // V249fix(auto-mode): floored at the Balanced bar. This was a THIRD reduction stacking on
      // Hunter's already-lower bar and its mode bonus, taking the effective Hunter requirement to 1
      // - and it fires precisely when ScorePenaltyImpulseRisk is charging for the same observation,
      // so the mode discount was larger than the risk penalty it overrode. An impulse is a reason
      // for Hunter to be FAST, not to be less selective than the conservative mode.
      if(G_MARKET_STATE == MARKET_IMPULSE && G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER &&
         G_SCORE_MIN_REQUIRED > MinScoreBalanced)
      {
         G_SCORE_MIN_REQUIRED = MathMax(1, G_SCORE_MIN_REQUIRED - 1);
         detail += " -1 min hunter impulse;";
      }
   }

   // V31 Self-Defense: himoya rejimida sifat talabi oshadi (min score +N).
   if(EnableSelfDefense && G_SD_ACTIVE && SelfDefenseMinScoreAdd > 0)
   {
      G_SCORE_MIN_REQUIRED += SelfDefenseMinScoreAdd;
      detail += StringFormat(" +%d min self-defense;", SelfDefenseMinScoreAdd);
   }

   // V31.6c HUNTER INTELLIGENCE UPGRADE, part 1: D1 overall direction filter.
   // Hunter's whole edge is a lower score bar - but nothing previously checked whether that
   // lower bar was being used WITH or AGAINST the bigger picture. If D1 direction disagrees
   // with this entry, Hunter must earn the SAME (higher) bar Balanced would require - its
   // discount only applies when the big-picture direction actually agrees.
   if(EnableHunterD1Filter && G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER && G_OPP_DIR != OPP_DIR_NONE)
   {
      int d1_dir = D1OverallDirection();
      int entry_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : -1);
      if(d1_dir != 0 && d1_dir != entry_dir)
      {
         int balanced_bar = G_SCORE_IS_MICRO ? MinScoreMicroBalanced : MinScoreBalanced;
         if(balanced_bar > G_SCORE_MIN_REQUIRED)
         {
            G_SCORE_MIN_REQUIRED = balanced_bar;
            detail += " Hunter vs D1 - Balanced bar required;";
            if((HunterD1PrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6c HUNTER D1] entry dir=%d vs D1 dir=%d - bar raised to %d",
                           entry_dir, d1_dir, balanced_bar);
         }
      }
   }

   // V31.6j new: Post-SL same-direction cooldown. Guards against "revenge trading" - if a
   // basket just closed at a LOSS, the SAME direction gets held to a higher score bar for a
   // short window afterward (the opposite direction is completely unaffected).
   if(EnablePostSLDirectionGuard && G_OPP_DIR != OPP_DIR_NONE && G_LAST_SL_DIRECTION >= 0)
   {
      int bars_since_sl = G_BARS_SEEN - G_LAST_SL_BAR;
      if(bars_since_sl >= 0 && bars_since_sl <= MathMax(1, PostSLDirectionWindowBars))
      {
         int entry_dir_sl = (G_OPP_DIR == OPP_DIR_BUY ? (int)POSITION_TYPE_BUY : (int)POSITION_TYPE_SELL);
         if(entry_dir_sl == G_LAST_SL_DIRECTION)
         {
            G_SCORE_MIN_REQUIRED += MathMax(0, PostSLDirectionExtraScoreReq);
            detail += StringFormat(" +%d min post-SL same-direction (%d/%d bars);",
                                   PostSLDirectionExtraScoreReq, bars_since_sl, PostSLDirectionWindowBars);

            if((PostSLDirectionPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6j POST-SL GUARD] same-direction entry %d bars after SL - bar raised +%d",
                           bars_since_sl, PostSLDirectionExtraScoreReq);
         }
      }
   }

   // V31.6c HUNTER INTELLIGENCE UPGRADE, part 2: early impulse sensing. A live tick-velocity
   // spike happening RIGHT NOW (still inside the current, unclosed candle) that agrees with
   // this signal's direction is real-time confirmation - reward it with a small bonus, rather
   // than only ever reacting to impulses after the candle has already closed.
   if(EnableHunterVelocitySense && G_OPP_DIR != OPP_DIR_NONE)
   {
      int live_dir = LiveVelocityDirection();
      int entry_dir_v = (G_OPP_DIR == OPP_DIR_BUY ? 1 : -1);
      if(live_dir != 0 && live_dir == entry_dir_v)
      {
         G_SCORE_BONUS += HunterVelocitySenseBonus;
         detail += StringFormat(" +%d live velocity agrees;", HunterVelocitySenseBonus);
      }
   }

   // V31.6i NEW: Trend Reversal (swing sequence + RSI divergence). Independent evidence flags,
   // gathered here for both this bonus and the Brain Consensus synergy check below.
   int entry_dir_i = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
   bool cat_reversal = false, cat_orderflow = false, cat_dxy = false, cat_bigtrend = false, cat_mtf = false;
   // FIX(dead-variable): cat_trendstrength (the FOR-agreeing variant) removed - TrendStrengthAgainst()
   // is structurally AGAINST-only (it returns 0 unless the trend opposes dir_i, see its own comment),
   // so this was declared, initialized to false, and never assigned true anywhere - only its
   // cat_trendstrength_against sibling below is ever set. Matches the same FOR/AGAINST asymmetry the
   // V31.6z66 note just below already documents for three other categories, just not called out here.
   bool cat_majorsweep = false, cat_eqzone = false, cat_engulfing = false;
   bool cat_trendquality = false;
   bool cat_impulse = false, cat_impulse_against = false;
   bool cat_zonebreak = false, cat_zonebreak_against = false;
   bool cat_reversal_against = false, cat_mtf_against = false, cat_trendstrength_against = false;
   bool cat_majorsweep_against = false, cat_eqzone_against = false, cat_engulfing_against = false;
   // V31.6z66: these three had no against-variant at all - they could only ever vote FOR.
   bool cat_orderflow_against = false, cat_dxy_against = false, cat_bigtrend_against = false;

   if(entry_dir_i != 0)
   {
      // V31.6l: TrendReversalDirection now caches internally (shared with grid callers too),
      // so this call is cheap - no need for a separate local cache here anymore.
      string reversal_reason_c = "";
      bool   divergence_c      = false;
      int    reversal_dir_c    = TrendReversalDirection(reversal_reason_c, divergence_c);

      if(EnableTrendReversal && reversal_dir_c != 0 && reversal_dir_c == entry_dir_i)
      {
         cat_reversal = true;
         G_SCORE_BONUS += TrendReversalBonus;
         detail += StringFormat(" +%d trend reversal (%s);", TrendReversalBonus, reversal_reason_c);

         if(divergence_c)
         {
            G_SCORE_BONUS += TrendReversalDivergenceBonus;
            detail += StringFormat(" +%d RSI divergence;", TrendReversalDivergenceBonus);
         }

         if((TrendReversalPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6i TREND REVERSAL] %s", reversal_reason_c);
      }
      // V31.6s fix: this was a genuine gap - a confirmed reversal AGAINST the proposed entry
      // (e.g. buying right as a bearish reversal is confirmed) previously had ZERO effect on
      // score. Only agreement was ever rewarded; disagreement was silently ignored. This is
      // very likely why bad first entries slipped through and needed grid to dig out of.
      else if(EnableTrendReversal && reversal_dir_c != 0 && reversal_dir_c == -entry_dir_i)
      {
         cat_reversal_against = true;
         int rev_penalty = divergence_c ?
                           (TrendReversalAgainstPenalty + TrendReversalAgainstDivergencePenalty) :
                           TrendReversalAgainstPenalty;
         G_SCORE_PENALTY += rev_penalty;
         v31_brain_penalty += rev_penalty;
         detail += StringFormat(" -%d reversal AGAINST entry (%s);", rev_penalty, reversal_reason_c);

         if((TrendReversalPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v31.6s TREND REVERSAL AGAINST] %s", reversal_reason_c);
      }

      // V31.6z32 NEW: Reversal Consensus - direct user feedback that reversal detection only
      // ever used ONE method (swing+RSI). This checks whether BOS/CHoCH, Major Sweep, or
      // Engulfing ALSO independently confirm a reversal (in either direction) beyond what the
      // basic swing check found - genuine additional evidence, not double-counting, since it
      // only fires extra bonus/penalty when MULTIPLE distinct methods agree simultaneously.
      //
      // V31.6z67 fix: this had the SAME `else if` flaw just corrected in Brain Consensus - and
      // it was my own code from earlier today. Reversal Consensus counts FOUR independent
      // methods, so in a choppy market it is entirely possible for two of them to confirm a
      // reversal UP while two others confirm one DOWN. The `else` meant the supporting side
      // won and the opposing confirmations were silently thrown away - awarding a bonus for
      // what is actually the most ambiguous state possible.
      if(EnableReversalConsensus)
      {
         string rc_support_e = "", rc_against_e = "";
         double rc_support_score_e = ReversalConsensusScore(entry_dir_i, rc_support_e);
         double rc_against_score_e = ReversalConsensusScore(-entry_dir_i, rc_against_e);

         bool rc_supports = (rc_support_score_e >= ReversalConsensus2Score);
         bool rc_opposes  = (rc_against_score_e >= ReversalConsensus2Score);

         if(rc_supports && rc_opposes)
         {
            G_SCORE_PENALTY += BrainConsensusConflictPenalty;
            G_PENALTY_TREND_AGAINST += BrainConsensusConflictPenalty;   // V136: same underlying fact as the other trend-conflict penalties
            v31_brain_penalty += BrainConsensusConflictPenalty;
            detail += StringFormat(" -%d reversal-CONFLICTED (both directions confirmed);", BrainConsensusConflictPenalty);
            if((GlobalLocalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z67 REVERSAL CONFLICTED] both directions confirmed (%s | %s) - ambiguous",
                           rc_support_e, rc_against_e);
         }
         else if(rc_supports)
         {
            G_SCORE_BONUS += GlobalLocalScoreBonus;
         G_BONUS_TREND_ALIGN += GlobalLocalScoreBonus;   // V134: same underlying fact as the other trend-agreement bonuses
            detail += StringFormat(" +%d %s;", GlobalLocalScoreBonus, rc_support_e);
            if((GlobalLocalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z32 REVERSAL CONSENSUS] entry dir=%d - %s", entry_dir_i, rc_support_e);
         }
         else if(rc_opposes)
         {
            G_SCORE_PENALTY += GlobalLocalScoreBonus;
            v31_brain_penalty += GlobalLocalScoreBonus;
            detail += StringFormat(" -%d %s;", GlobalLocalScoreBonus, rc_against_e);
            if((GlobalLocalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z32 REVERSAL CONSENSUS AGAINST] entry dir=%d - %s", entry_dir_i, rc_against_e);
         }
      }

      // V31.6i NEW: Multi-TF Structure Alignment. Cache the 4 raw per-TF directions once per
      // bar (the expensive part); matching against entry_dir_i is cheap and stays live.
      if(EnableMTFAlignment)
      {
         static int mtf_cache_bar  = -1;
         static int mtf_m15_dir_c  = 0;
         static int mtf_h1_dir_c   = 0;
         static int mtf_h4_dir_c   = 0;
         static int mtf_d1_dir_c   = 0;
         if(mtf_cache_bar > G_BARS_SEEN) mtf_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
         if(mtf_cache_bar != G_BARS_SEEN)
         {
            mtf_m15_dir_c = SimpleTFDirection(PERIOD_M15, MTFAlignmentM15LookbackBars);
            mtf_h1_dir_c  = KalmanTrendReady() ?
                            ((G_KALMAN_TREND / _Point > KalmanTrendMinPoints) ? 1 :
                             (G_KALMAN_TREND / _Point < -KalmanTrendMinPoints ? -1 : 0)) :
                            SimpleTFDirection(PERIOD_H1, MTFAlignmentH1LookbackBars);
         mtf_h4_dir_c  = SimpleTFDirection(PERIOD_H4, MTFAlignmentH4LookbackBars);
            mtf_d1_dir_c  = D1OverallDirection();
            mtf_cache_bar = G_BARS_SEEN;
         }

         int mtf_agree = (mtf_m15_dir_c == entry_dir_i ? 1 : 0) + (mtf_h1_dir_c == entry_dir_i ? 1 : 0) +
                         (mtf_h4_dir_c == entry_dir_i ? 1 : 0) + (mtf_d1_dir_c == entry_dir_i ? 1 : 0);

         if(mtf_agree > 0)
         {
            cat_mtf = (mtf_agree >= 3);
            int mtf_bonus = mtf_agree * MTFAlignmentBonusPerTF;
            G_SCORE_BONUS += mtf_bonus;
            detail += StringFormat(" +%d MTF alignment (%d/4 TF agree);", mtf_bonus, mtf_agree);

            if((MTFAlignmentPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6i MTF ALIGNMENT] %d/4 timeframes agree with dir=%d", mtf_agree, entry_dir_i);
         }

         // V31.6s fix: same gap as Trend Reversal above - TFs disagreeing with the entry had
         // no effect at all. Non-linear penalty (matches Grid Intelligence's Sense 3 logic):
         // near-unanimous disagreement is much stronger evidence than a proportional scale implies.
         int mtf_against = (mtf_m15_dir_c == -entry_dir_i ? 1 : 0) + (mtf_h1_dir_c == -entry_dir_i ? 1 : 0) +
                           (mtf_h4_dir_c == -entry_dir_i ? 1 : 0) + (mtf_d1_dir_c == -entry_dir_i ? 1 : 0);

         if(mtf_against >= 2)
         {
            cat_mtf_against = true;
            int mtf_penalty = (mtf_against == 4) ? MTFAgainstPenaltyUnanimous :
                              (mtf_against == 3) ? MTFAgainstPenalty3 : MTFAgainstPenalty2;
            G_SCORE_PENALTY += mtf_penalty;
            v31_brain_penalty += mtf_penalty;
            detail += StringFormat(" -%d MTF AGAINST (%d/4 TF disagree);", mtf_penalty, mtf_against);

            if((MTFAlignmentPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6s MTF AGAINST] %d/4 timeframes disagree with dir=%d", mtf_against, entry_dir_i);
         }
      }

      // V31.6s NEW: Trend Strength (ADX) for First Entry - was ONLY ever wired into Grid
      // Intelligence. A strong, SUSTAINED, ongoing trend against the proposed entry (no fresh
      // reversal needed - just persistent continuation) had zero effect on first-entry score
      // until now. This is very likely the actual root cause of entries that immediately
      // needed grid to recover from - the entry itself never saw the trend it was fighting.
      if(EnableTrendStrengthEntry && EnableTrendStrength)
      {
         double entry_adverse_strength = TrendStrengthAgainst(entry_dir_i);
         if(entry_adverse_strength > 0.0)
         {
            int strength_penalty = (int)MathRound(entry_adverse_strength * TrendStrengthEntryPenaltyMax);
            if(strength_penalty > 0)
            {
               cat_trendstrength_against = true;
               G_SCORE_PENALTY += strength_penalty;
               v31_brain_penalty += strength_penalty;
               detail += StringFormat(" -%d trend strength AGAINST (adx-strength=%.2f);", strength_penalty, entry_adverse_strength);

               if((TrendReversalPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v31.6s TREND STRENGTH AGAINST] entry dir=%d adverse_strength=%.2f -> penalty %d",
                              entry_dir_i, entry_adverse_strength, strength_penalty);
            }
         }
      }

      // V31.6t NEW: Major Sweep Awareness for First Entry - was a strong, zone-confirmed
      // level recently swept and rejected? Agreement is rewarded; a fresh entry going the
      // SAME way as what just got swept away (i.e. buying right after a bearish sweep just
      // rejected a rally, or selling right after a bullish sweep just rejected a decline) is
      // penalized - classic liquidity-grab awareness the bot never had outside the standalone
      // Sweep entry type.
      if(EnableMajorSweepAwareness)
      {
         string sweep_detail_e = "";
         int sweep_dir_e = RecentMajorSweepDirection(sweep_detail_e);
         if(sweep_dir_e != 0)
         {
            if(sweep_dir_e == entry_dir_i)
            {
               cat_majorsweep = true;
               G_SCORE_BONUS += MajorSweepScoreBonus;
               detail += StringFormat(" +%d major sweep agrees (%s);", MajorSweepScoreBonus, sweep_detail_e);
            }
            else
            {
               cat_majorsweep_against = true;
               G_SCORE_PENALTY += MajorSweepScoreBonus;
               v31_brain_penalty += MajorSweepScoreBonus;
               detail += StringFormat(" -%d major sweep AGAINST (%s);", MajorSweepScoreBonus, sweep_detail_e);
            }

            if((MajorSweepPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6t MAJOR SWEEP] entry dir=%d sweep dir=%d - %s", entry_dir_i, sweep_dir_e, sweep_detail_e);
         }
      }

      // V31.6u NEW: Equilibrium / Premium-Discount Zone for First Entry - buying deep in
      // Premium (upper half of the recent range) or selling deep in Discount is "paying up"
      // within the range even if other senses look fine. A different dimension than specific
      // levels - about WHERE price sits in the broader range.
      if(EnableEQZone)
      {
         double range_pos_pct_e = 50.0;
         int eq_dir_e = EQZoneBias(range_pos_pct_e);
         if(eq_dir_e != 0)
         {
            // V251: scale by how far into the extreme price actually is. The original gave one flat
            // point whether price sat at 66% of the range or at 98%, and those are not the same
            // trade - at 66% there is room above, at 98% the buyer is paying the top of everything
            // the range has produced. All three losing buys sat near the top.
            //
            // The module was built and wired correctly; what made it invisible was the weight. One
            // point against a band-entry penalty of six meant premium/discount could never change an
            // outcome, so the EA had the reading and no way to act on it.
            int eq_weight = EQZoneScoreBonus;
            if(EnableEQZoneScaling)
            {
               double eq_edge = (eq_dir_e > 0) ? (EQZoneDiscountThreshold - range_pos_pct_e)
                                               : (range_pos_pct_e - EQZonePremiumThreshold);
               double eq_span = MathMax(1.0, (eq_dir_e > 0) ? EQZoneDiscountThreshold
                                                            : (100.0 - EQZonePremiumThreshold));
               double eq_depth = MathMax(0.0, MathMin(1.0, eq_edge / eq_span));
               eq_weight = (int)MathRound((double)EQZoneScoreBonus + eq_depth * (double)EQZoneDeepBonus);
               eq_weight = MathMax(EQZoneScoreBonus, eq_weight);
            }

            if(eq_dir_e == entry_dir_i)
            {
               cat_eqzone = true;
               G_SCORE_BONUS += eq_weight;
               detail += StringFormat(" +%d EQ zone favorable (%.0f%%);", eq_weight, range_pos_pct_e);
            }
            else
            {
               cat_eqzone_against = true;
               G_SCORE_PENALTY += eq_weight;
               G_PENALTY_QUALITY += eq_weight;
               v31_brain_penalty += eq_weight;
               detail += StringFormat(" -%d EQ zone unfavorable (%.0f%%);", eq_weight, range_pos_pct_e);
            }

            if((EQZonePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6u EQ ZONE ENTRY] entry dir=%d range_position=%.0f%%", entry_dir_i, range_pos_pct_e);
         }
      }

      // V31.6v NEW: Engulfing Pattern for First Entry - a decisive two-candle control shift,
      // ideally confirmed at a real zone. Agreement is rewarded; a strong engulfing that just
      // formed the OTHER way is penalized.
      if(EnableEngulfingAwareness)
      {
         string engulf_detail_e = "";
         int engulf_dir_e = RecentEngulfingDirection(engulf_detail_e);
         if(engulf_dir_e != 0)
         {
            if(engulf_dir_e == entry_dir_i)
            {
               cat_engulfing = true;
               G_SCORE_BONUS += EngulfingScoreBonus;
               detail += StringFormat(" +%d engulfing agrees (%s);", EngulfingScoreBonus, engulf_detail_e);
            }
            else
            {
               cat_engulfing_against = true;
               G_SCORE_PENALTY += EngulfingScoreBonus;
               v31_brain_penalty += EngulfingScoreBonus;
               detail += StringFormat(" -%d engulfing AGAINST (%s);", EngulfingScoreBonus, engulf_detail_e);
            }

            if((EngulfingPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6v ENGULFING ENTRY] entry dir=%d - %s", entry_dir_i, engulf_detail_e);
         }
      }

      // V31.6z NEW: Trend Quality Score - "the market moves with a trend more often than it
      // reverses" synthesis (ADX + MTF + MA ribbon + HH/HL structure combined). Only rewards
      // when genuinely strong (>= threshold) and aligned - this is a confirmation booster for
      // continuation-type entries, not a standalone penalty source (no "against" case).
      if(EnableTrendQualityScore)
      {
         string tq_detail_e = "";
         double tq_score_e = TrendQualityScore(entry_dir_i, tq_detail_e);
         if(tq_score_e >= TrendQualityMinScoreForBonus)
         {
            cat_trendquality = true;
            G_SCORE_BONUS += TrendQualityBonus;
         G_BONUS_TREND_ALIGN += TrendQualityBonus;   // V134: same underlying fact as the other trend-agreement bonuses
            detail += StringFormat(" +%d trend quality %.2f (%s);", TrendQualityBonus, tq_score_e, tq_detail_e);

            if((TrendQualityPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z TREND QUALITY] entry dir=%d score=%.2f - %s", entry_dir_i, tq_score_e, tq_detail_e);
         }
      }

      // V31.6z30 NEW: Global vs Local Trend Alignment - direct user request. Distinguishes
      // the BIG PICTURE (H4/D1) from what's happening RIGHT NOW (M15/local). An entry fighting
      // the global trend has no underlying current working in its favor if it goes wrong -
      // exactly what leaves a basket stuck in DD. Applies universally (both bonus for genuine
      // alignment and penalty for fighting the bigger picture), unlike Trend Quality above
      // which only ever rewards.
      if(EnableGlobalLocalTrendSplit)
      {
         string gla_detail_e = "";
         double gla_score_e = GlobalLocalAlignmentScore(entry_dir_i, gla_detail_e);
         if(gla_score_e >= 0.65)
         {
            G_SCORE_BONUS += GlobalLocalScoreBonus;
            G_BONUS_TREND_ALIGN += GlobalLocalScoreBonus;   // V134: same underlying fact as the other trend-agreement bonuses
            detail += StringFormat(" +%d %s;", GlobalLocalScoreBonus, gla_detail_e);

            if((GlobalLocalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z30 GLOBAL/LOCAL] entry dir=%d - %s", entry_dir_i, gla_detail_e);
         }
         else if(gla_score_e <= 0.30)
         {
            G_SCORE_PENALTY += GlobalLocalScoreBonus;
            v31_brain_penalty += GlobalLocalScoreBonus;
            detail += StringFormat(" -%d %s;", GlobalLocalScoreBonus, gla_detail_e);

            if((GlobalLocalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z30 GLOBAL/LOCAL AGAINST] entry dir=%d - %s", entry_dir_i, gla_detail_e);
         }
      }

      // V31.6z7 NEW: Trend Continuation Zone Caution - real gap found via live testing. Most
      // of the newer trend-continuation detectors never check Zone Map at all, so a SELL
      // could fire right INTO a strong historical support level purely because the local
      // trend looked strong. This applies to ANY continuation-type entry, regardless of
      // which specific detector fired - a strong opposing zone right in front of the entry
      // is a real reason for caution even in a genuine trend.
      //
      // V31.6z29 EXTENSION: same gap Grid Intelligence had - a detector like Donchian Breakout
      // only looks at a LOCAL lookback window (e.g. 20 bars). Breaking that local high says
      // nothing about whether a much taller, more significant high/resistance still sits
      // overhead un-broken. Adds a second, WIDER tier that only fires for genuinely major
      // levels (much higher strength bar), catching "broke a local high but still under a real
      // ceiling" without over-triggering on every minor distant zone.
      // V31.6z50 fix: real, confirmed root cause of the user's repeated observation ("BUY at
      // resistance, SELL at support"). The `!IsReversalOpportunityType` exemption below assumed
      // reversal detectors already check their own zones - an audit proved otherwise:
      //   Sweep:        checks NEITHER support nor resistance
      //   Range Edge:   checks NEITHER
      //   Near-Zone:    checks support, NOT the opposing resistance
      //   Fake-Breakout: checks support, NOT the opposing resistance
      //   Zone Retest:  checks support, NOT the opposing resistance
      // So a reversal BUY could fire with strong resistance sitting directly overhead, and
      // nothing anywhere caught it. The opposing-zone question ("is there a wall right in front
      // of this trade?") is legitimate for EVERY entry type, not just continuations - a bounce
      // bet with no room to run is just as bad as a breakout into a wall.
      bool zone_caution_applies = EnableTrendContinuationZoneCaution &&
                                  (!IsReversalOpportunityType(G_OPP_TYPE) || EnableReversalTypeZoneCaution);

      if(zone_caution_applies)
      {
         double bid_zc = 0.0, ask_zc = 0.0;
         SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_zc);
         SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_zc);
         double mid_zc = (bid_zc > 0.0 && ask_zc > 0.0) ? (bid_zc + ask_zc) / 2.0 : bid_zc;

         if(mid_zc > 0.0)
         {
            // V31.6z42 UPGRADE: same fix as Grid - uses TF-weighted search across the full far
            // range instead of pure-nearest, so a moderately-strong HTF zone between the near
            // and far tiers isn't invisible to both checks.
            double opposing_zone = (entry_dir_i > 0) ?
                                   ZoneMapBestWeightedResistance(mid_zc, EntryFarZoneCautionPoints) :
                                   ZoneMapBestWeightedSupport(mid_zc, EntryFarZoneCautionPoints);
            if(opposing_zone > 0.0)
            {
               double dist_pts = MathAbs(mid_zc - opposing_zone) / _Point;
               double zone_str = ZoneMapStrength(opposing_zone);

               bool near_zc = (dist_pts <= TrendContinuationZoneCautionPoints && zone_str >= TrendContinuationZoneCautionMinStrength);
               bool far_zc = (EnableEntryFarZoneAwareness && !near_zc &&
                              dist_pts <= EntryFarZoneCautionPoints && zone_str >= EntryFarZoneMinStrength);

               if(near_zc || far_zc)
               {
                  int zc_penalty = near_zc ? TrendContinuationZoneCautionPenalty : MathMax(1, TrendContinuationZoneCautionPenalty - 1);
                  G_SCORE_PENALTY += zc_penalty;
                  v31_brain_penalty += zc_penalty;
                  detail += StringFormat(" -%d %s-vs-strong-zone (%.2f,str=%.1f,%.0fpts away);",
                                         zc_penalty, near_zc ? "NEAR" : "FAR", opposing_zone, zone_str, dist_pts);
               }
            }
         }
      }

      // V31.6z8 NEW: Impulse Confirmation - none of the trend-continuation tools sensed a
      // genuine, sharp impulse candle at all. Applies universally (not just continuation
      // types): a fresh, decisive burst AGREEING with the proposed direction is real
      // conviction evidence; a strong impulse the OTHER way is a real caution sign even for
      // a reversal-type entry (e.g. buying right as a sharp bearish impulse just fired).
      if(EnableImpulseConfirmation)
      {
         string imp_detail_e = "";
         double imp_score_e = ImpulseConfirmation(entry_dir_i, imp_detail_e);
         if(imp_score_e >= 0.6)
         {
            cat_impulse = true;
            G_SCORE_BONUS += ImpulseScoreBonus;
            detail += StringFormat(" +%d %s;", ImpulseScoreBonus, imp_detail_e);

            if((ImpulsePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z8 IMPULSE] entry dir=%d agrees - %s", entry_dir_i, imp_detail_e);
         }
         else if(imp_score_e <= 0.3)
         {
            cat_impulse_against = true;
            G_SCORE_PENALTY += ImpulseScoreBonus;
            v31_brain_penalty += ImpulseScoreBonus;
            detail += StringFormat(" -%d %s;", ImpulseScoreBonus, imp_detail_e);

            if((ImpulsePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z8 IMPULSE AGAINST] entry dir=%d - %s", entry_dir_i, imp_detail_e);
         }
      }

      // V31.6z54 NEW: STANDALONE Move Extension check. Direct user scenario: "the trend keeps
      // going - sell, sell, sell - but it has reached the turning point, and a SELL opens right
      // there". Real gap found: Move Extension (z53) only ran INSIDE ImpulseConfirmation, which
      // bails out early with a neutral 0.5 whenever no big impulse candle qualifies. But a long,
      // grinding trend needs no dramatic candle at all - detectors like Trend Ride, Swing
      // Continuation, MA Bounce or Donchian can fire a SELL at the exhausted bottom of a
      // multi-day move with nothing flagging how far it had already run. This asks the question
      // for EVERY entry, impulse candle or not: how much of this move is already behind us?
      if(EnableMoveExtension && EnableStandaloneMoveExtension && entry_dir_i != 0)
      {
         double ext_e = MoveExtensionATR(entry_dir_i);

         if(ext_e >= MoveExtensionMatureATR)
         {
            double span_e = MathMax(0.1, MoveExtensionClimaxATR - MoveExtensionMatureATR);
            double maturity_e = MathMax(0.0, MathMin(1.5, (ext_e - MoveExtensionMatureATR) / span_e));
            int ext_penalty = (int)MathRound(maturity_e * StandaloneMoveExtensionMaxPenalty);

            // V195: past the climax threshold this stops being a discount and becomes a timing
            // objection. A move that has run 3+ ATR is not a worse version of the same trade - it
            // is the same trade offered at the worst possible price, and the pullback that follows
            // is where it should have been taken. Arm and wait for that pullback; entering after it
            // is the identical setup with the risk halved.
            if(EnableSetupArming && ext_e >= MoveExtensionClimaxATR && entry_dir_i != 0)
            {
               double lae_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(lae_px > 0.0 &&
                  SetupArm(entry_dir_i, ARM_REASON_EXTENDED, lae_px,
                           StringFormat("move already %.1f ATR extended - waiting for the pullback", ext_e), false))
               {
                  G_SCORE_DECISION = SCORE_DECISION_WAIT;
                  detail += StringFormat(" [armed: %.1f ATR extended, waiting for pullback];", ext_e);
                  return;
               }
            }

            if(ext_penalty > 0)
            {
               G_SCORE_PENALTY += WeightedPenalty(WARN_LATE_ENTRY, ext_penalty);
               v31_brain_penalty += ext_penalty;
               detail += StringFormat(" -%d LATE-ENTRY(move already %.1f ATR extended);", ext_penalty, ext_e);

               if((ImpulsePrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v31.6z54 MOVE EXTENSION] entry dir=%d into a move already %.1f ATR extended -> -%d",
                              entry_dir_i, ext_e, ext_penalty);
            }
         }
      }

      // V31.6z22 NEW: Exhaustion Consensus - unified, non-linear combination of ADX slope,
      // RSI cooling, candle exhaustion, DXY deceleration, and basket DD acceleration. Entering
      // FRESH into a direction where multiple independent signals already show deceleration is
      // a real caution sign, distinct from (and not double-counted with) the individual
      // category flags above since this only fires when several agree AT ONCE.
      if(EnableExhaustionConsensus)
      {
         string ec_detail_e = "";
         double ec_score_e = ExhaustionConsensusScore(entry_dir_i, ec_detail_e);
         if(ec_score_e < 0.5)
         {
            int ec_penalty = (ec_score_e <= 0.20) ? (ImpulseExhaustionPenalty * 2) : ImpulseExhaustionPenalty;
            G_SCORE_PENALTY += ec_penalty;
            v31_brain_penalty += ec_penalty;
            detail += StringFormat(" -%d %s;", ec_penalty, ec_detail_e);

            if((ImpulseExhaustionPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z22 EXHAUSTION CONSENSUS ENTRY] entry dir=%d - %s", entry_dir_i, ec_detail_e);
         }
      }

      // V31.6z9 NEW: Competing Reversal Signal Caution. Trend Reversal (swing/RSI-based)
      // already applies universally, but our 5 dedicated reversal-PATTERN detectors (Sweep,
      // FBR, Near-Zone, Exhaustion, Range Edge) only ever get checked as scanner CANDIDATES -
      // if a continuation-type entry wins the "best score" race instead, any of these firing
      // in the OPPOSITE direction is silently discarded information. Re-checks them
      // specifically when taking a continuation-type entry, since a genuine, independently-
      // scored reversal pattern forming at the same moment is real caution evidence even if
      // it didn't numerically win the scanner.
      if(EnableCompetingReversalCaution && !IsReversalOpportunityType(G_OPP_TYPE) && entry_dir_i != 0)
      {
         string comp_reason = "";
         int comp_score = 0;
         bool competing_found = false;
         string competing_name = "";

         if(entry_dir_i > 0)
         {
            if(DetectSweepSell(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "Sweep"; }
            else if(DetectFakeBreakoutReturnSell(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "FakeBreakoutReturn"; }
            else if(DetectNearZoneReactionSell(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "NearZoneReaction"; }
            else if(DetectExhaustionSell(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "Exhaustion"; }
            else if(DetectRangeEdgeSell(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "RangeEdge"; }
         }
         else
         {
            if(DetectSweepBuy(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "Sweep"; }
            else if(DetectFakeBreakoutReturnBuy(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "FakeBreakoutReturn"; }
            else if(DetectNearZoneReactionBuy(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "NearZoneReaction"; }
            else if(DetectExhaustionBuy(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "Exhaustion"; }
            else if(DetectRangeEdgeBuy(comp_reason, comp_score) && comp_score >= CompetingReversalMinScore)
               { competing_found = true; competing_name = "RangeEdge"; }
         }

         if(competing_found)
         {
            G_SCORE_PENALTY += CompetingReversalPenalty;
            G_PENALTY_QUALITY += CompetingReversalPenalty;
            v31_brain_penalty += CompetingReversalPenalty;
            detail += StringFormat(" -%d competing reversal (%s: %s);", CompetingReversalPenalty, competing_name, comp_reason);

            if((TrendReversalPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z9 COMPETING REVERSAL] %s fires opposite entry dir=%d - %s",
                           competing_name, entry_dir_i, comp_reason);
         }
      }

      // FEATURE(market-structure): the swing-chain reading. Unlike the fragments around it, this
      // asks one question - is the market building higher highs and higher lows, or lower highs and
      // lower lows? Entering against a confirmed chain is trading against the structure itself, so
      // it carries a real penalty (or a hard block if configured). A mixed/ranging chain declares no
      // direction and costs nothing, which is the honest answer when structure is unclear.
      if(EnableMarketStructure)
      {
         MarketStructureRead();
         if(G_STRUCTURE_DIR != 0)
         {
            bool choch = (G_STRUCTURE_EVENT == -1);   // the chain just broke
            bool bos   = (G_STRUCTURE_EVENT == 1);    // the chain just extended

            if(entry_dir_i == -G_STRUCTURE_DIR)
            {
               // Entering AGAINST the trading-TF structure. Two legitimate exceptions:
               //  1. A CHoCH just fired - the chain has failed, so this is the reversal, not a fight.
               //  2. The chain is only a PULLBACK inside a higher structure this entry agrees with.
               //     Buying a dip inside a bullish H1 opposes the M15 chain by definition; that is
               //     the setup, not an error. Penalising it would ban every pullback entry.
               bool pullback_with_htf = (EnableStructureHTF && G_STRUCTURE_HTF_DIR != 0 &&
                                         entry_dir_i == G_STRUCTURE_HTF_DIR);

               if(choch && MarketStructureCHoCHReleases)
                  detail += StringFormat(" (structure broke - %s, no penalty);", G_STRUCTURE_EVENT_TXT);
               else if(pullback_with_htf)
                  detail += StringFormat(" (with %s - pullback entry, no penalty);", G_STRUCTURE_CONTEXT_TXT);
               else
               {
                  G_SCORE_PENALTY += WeightedPenalty(WARN_STRUCTURE, MarketStructureAgainstPenalty);
                  G_PENALTY_TREND_AGAINST += MarketStructureAgainstPenalty;   // V136: same underlying fact as the other trend-conflict penalties
                  v31_brain_penalty += MarketStructureAgainstPenalty;
                  detail += StringFormat(" -%d against %s;", MarketStructureAgainstPenalty, G_STRUCTURE_DETAIL);
                  if((MarketStructurePrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v112 STRUCTURE] entry dir=%d fights %s", entry_dir_i, G_STRUCTURE_DETAIL);
               }
            }
            else if(entry_dir_i == G_STRUCTURE_DIR)
            {
               // Entering WITH the structure.
               if(bos)
               {
                  // The chain just confirmed itself - the strongest version of this setup.
                  G_SCORE_BONUS += MarketStructureBOSBonus;
         G_BONUS_TREND_ALIGN += MarketStructureBOSBonus;   // V134: same underlying fact as the other trend-agreement bonuses
                  detail += StringFormat(" +%d %s;", MarketStructureBOSBonus, G_STRUCTURE_EVENT_TXT);
               }
               else if(choch)
               {
                  // Continuing a chain that has just BROKEN. This looks like a trend entry but the
                  // structure behind it has failed, so it is exactly the late entry that loses.
                  G_SCORE_PENALTY += MarketStructureCHoCHPenalty;
                  G_PENALTY_TREND_AGAINST += MarketStructureCHoCHPenalty;
                  v31_brain_penalty += MarketStructureCHoCHPenalty;
                  detail += StringFormat(" -%d continuing a broken structure (%s);", MarketStructureCHoCHPenalty, G_STRUCTURE_EVENT_TXT);
               }
            }
         }

         // V112: the two-frame context. Going with the lower-TF chain is NOT automatically right -
         // if that chain is a counter-move inside a bigger opposite structure, the entry is fading
         // the larger trend. Conversely, when both frames agree the setup deserves extra weight.
         if(EnableStructureHTF)
         {
            bool fading_htf = ((G_STRUCTURE_CONTEXT == STRUCT_CTX_PULLBACK_IN_UP   && entry_dir_i < 0) ||
                               (G_STRUCTURE_CONTEXT == STRUCT_CTX_PULLBACK_IN_DOWN && entry_dir_i > 0));
            bool with_aligned = ((G_STRUCTURE_CONTEXT == STRUCT_CTX_ALIGNED_UP   && entry_dir_i > 0) ||
                                 (G_STRUCTURE_CONTEXT == STRUCT_CTX_ALIGNED_DOWN && entry_dir_i < 0));

            if(fading_htf)
            {
               G_SCORE_PENALTY += StructurePullbackFadePenalty;
               G_PENALTY_TREND_AGAINST += StructurePullbackFadePenalty;   // V136: same underlying fact as the other trend-conflict penalties
               v31_brain_penalty += StructurePullbackFadePenalty;
               detail += StringFormat(" -%d trading a %s;", StructurePullbackFadePenalty, G_STRUCTURE_CONTEXT_TXT);
            }
            else if(with_aligned)
            {
               G_SCORE_BONUS += StructureAlignedBonus;
               G_BONUS_TREND_ALIGN += StructureAlignedBonus;   // V134: same underlying fact as the other trend-agreement bonuses
               detail += StringFormat(" +%d %s;", StructureAlignedBonus, G_STRUCTURE_CONTEXT_TXT);
            }
         }
      }

      // V119: penalty path (when ZoneRoleHardBlock is off). Entering while price sits inside a zone
      // band means the buy/sell decision was effectively arbitrary.
      if(EnableZoneRoleCheck && !ZoneRoleHardBlock)
      {
         string zr_pen_detail = "";
         if(ZoneRoleAmbiguous(zr_pen_detail))
         {
            G_SCORE_PENALTY += WeightedPenalty(WARN_ZONE_ROLE, ZoneRoleAmbiguityPenalty);
            G_PENALTY_QUALITY += ZoneRoleAmbiguityPenalty;
            v31_brain_penalty += ZoneRoleAmbiguityPenalty;
            detail += StringFormat(" -%d %s;", ZoneRoleAmbiguityPenalty, zr_pen_detail);
         }
      }

      // V144: are the readings actually agreeing, or merely leaning? A narrow lead means the market
      // has not picked a side yet - and entering an undecided market is how baskets end up caught
      // mid-turn. This is separate from direction: it prices the AGREEMENT, not the answer.
      if(EnableScenarios)
      {
         double sc_up = 0.0, sc_down = 0.0, sc_none = 0.0;
         string sc_detail = "";
         ScenarioProbabilities(sc_up, sc_down, sc_none, sc_detail);

         double sc_lead = MathMax(sc_up, MathMax(sc_down, sc_none));
         double sc_second = 0.0;
         if(sc_lead == sc_up)        sc_second = MathMax(sc_down, sc_none);
         else if(sc_lead == sc_down) sc_second = MathMax(sc_up, sc_none);
         else                        sc_second = MathMax(sc_up, sc_down);

         if(sc_lead > 0.0 && (sc_lead - sc_second) < ScenarioMinMargin)
         {
            G_SCORE_PENALTY += WeightedPenalty(WARN_UNDECIDED, ScenarioUndecidedPenalty);
            G_PENALTY_CONDITIONS += ScenarioUndecidedPenalty;
            v31_brain_penalty += ScenarioUndecidedPenalty;
            detail += StringFormat(" -%d undecided (%s);", ScenarioUndecidedPenalty, sc_detail);
            if((ScenarioPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v144 SCENARIOS] %s", sc_detail);
         }
      }

      // V143: what does the SEQUENCE of recent events say comes next? This is the one check that
      // reads the market as a story rather than a snapshot - the same sweep means reversal or
      // continuation depending only on what followed it, and no single-moment indicator can tell
      // those apart.
      if(EnableChainExpectation)
      {
         double ce_conf = 0.0;
         string ce_detail = "";
         int ce_pat = CHAIN_PAT_NONE;
         int ce_dir = ChainExpectation(ce_conf, ce_detail, ce_pat);

         if(ce_dir != 0 && ce_conf >= ChainExpectMinConfidence)
         {
            if(entry_dir_i == ce_dir)
            {
               G_SCORE_BONUS += ChainExpectWithBonus;
               detail += StringFormat(" +%d chain %s;", ChainExpectWithBonus, ce_detail);
            }
            else
            {
               G_SCORE_PENALTY += WeightedPenalty(WARN_CHAIN, ChainExpectAgainstPenalty);
               G_PENALTY_CONDITIONS += ChainExpectAgainstPenalty;
               v31_brain_penalty += ChainExpectAgainstPenalty;
               detail += StringFormat(" -%d against chain %s;", ChainExpectAgainstPenalty, ce_detail);
            }
            if((ChainExpectPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v143 CHAIN] %s | entry dir=%d", ce_detail, entry_dir_i);
         }
      }

      // V169: what kind of day has this already been? A good day is worth protecting more than
      // extending, and a bad one is not worth trading back - that is how a bad day becomes a bad
      // week.
      if(EnableDailyState)
      {
         string ds_detail = "";
         int ds_offset = DailyStateScoreOffset(ds_detail);
         if(ds_offset > 0)
         {
            G_SCORE_MIN_REQUIRED += ds_offset;
            detail += StringFormat(" [+%d score bar: %s];", ds_offset, ds_detail);
         }
      }

      // V167: is this entry leaning on the price the zone actually reacts from, or on the extreme it
      // merely reaches? Entering at the reach edge fills early and then watches price continue to
      // the reaction edge before turning - drawdown that was avoidable.
      if(EnableZoneEdges)
      {
         double ze_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ze_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double ze_mid = (ze_bid > 0.0 && ze_ask > 0.0) ? (ze_bid + ze_ask) / 2.0 : ze_bid;

         if(ze_mid > 0.0)
         {
            bool   ze_is_support = (entry_dir_i > 0);
            double ze_level = ze_is_support ? ZoneMapNearestSupport(ze_mid)
                                            : ZoneMapNearestResistance(ze_mid);

            if(ze_level > 0.0)
            {
               double ze_outer = 0.0, ze_inner = 0.0;
               string ze_detail = "";
               if(ZoneEdgePrices(ze_level, ze_is_support, ze_outer, ze_inner, ze_detail))
               {
                  // Has price reached the edge that actually reacts, or only the one it reaches?
                  bool reaction_reached = ze_is_support ? (ze_mid <= ze_inner)
                                                        : (ze_mid >= ze_inner);
                  if(!reaction_reached)
                  {
                     // V195: the zone's reaction edge is a PRICE, and price is something the EA can
                     // wait for rather than pay a penalty over. Entering here means filling early
                     // and then watching the market travel to where the turn actually happens -
                     // avoidable drawdown that a few bars of patience removes entirely.
                     if(EnableSetupArming && EnableZoneEdgeArming &&
                        SetupArm(entry_dir_i, ARM_REASON_ZONE, ze_inner,
                                 StringFormat("reaction edge is %.2f, price is %.2f - waiting for it",
                                              ze_inner, ze_mid), false))
                     {
                        G_SCORE_DECISION = SCORE_DECISION_WAIT;
                        detail += StringFormat(" [armed: waiting for reaction edge %.2f];", ze_inner);
                        return;
                     }
                     G_SCORE_PENALTY += ZoneEdgeEarlyEntryPenalty;
                     G_PENALTY_QUALITY += ZoneEdgeEarlyEntryPenalty;
                     v31_brain_penalty += ZoneEdgeEarlyEntryPenalty;
                     detail += StringFormat(" -%d early: %s;", ZoneEdgeEarlyEntryPenalty, ze_detail);
                     if((ZoneEdgePrintOnUse && VerboseLogs))
                        PrintFormat("[SIRUS v167 ZONE EDGE] entry is early - %s", ze_detail);
                  }
               }
            }
         }
      }

      // V205: what is behind the level in front? The zone map reports the nearest level, which is
      // the right answer for where price will go first and the wrong one for whether the trade has
      // room. Price that fell to a deep support, bounced, and now sits above a shallower one shows
      // plenty of space beneath that shallow level - while the level that actually turned price
      // sits just under it, invisible.
      //
      // The distance that matters is to the level that will HOLD, not the first one price meets.
      if(EnableSecondLevelCheck && entry_dir_i != 0)
      {
         double sl_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl_mid = (sl_bid > 0.0 && sl_ask > 0.0) ? (sl_bid + sl_ask) / 2.0 : sl_bid;

         if(sl_mid > 0.0 && _Point > 0.0)
         {
            double first_lvl = (entry_dir_i > 0) ? ZoneMapNearestResistance(sl_mid)
                                                 : ZoneMapNearestSupport(sl_mid);
            if(first_lvl > 0.0)
            {
               double second_lvl = (entry_dir_i > 0)
                                   ? ZoneMapNextResistanceAbove(sl_mid, first_lvl)
                                   : ZoneMapNextSupportBelow(sl_mid, first_lvl);

               if(second_lvl > 0.0)
               {
                  double s_first  = ZoneMapStrengthByTouches(first_lvl);
                  double s_second = ZoneMapStrengthByTouches(second_lvl);
                  double gap_pts  = MathAbs(second_lvl - first_lvl) / _Point;
                  double dist_pts = MathAbs(second_lvl - sl_mid) / _Point;

                  // The one behind only matters when it is genuinely stronger, close enough behind
                  // to be reached in the same move, and within the range this trade would travel.
                  bool stronger = (s_second >= s_first + SecondLevelStrengthEdge);
                  bool close_behind = (gap_pts <= (double)SecondLevelMaxGapPoints);
                  bool in_range = (dist_pts <= (double)SecondLevelReachPoints);

                  if(stronger && close_behind && in_range)
                  {
                     G_SCORE_PENALTY += SecondLevelPenalty;
                     G_PENALTY_QUALITY += SecondLevelPenalty;
                     detail += StringFormat(" -%d stronger %s at %.2f behind %.2f;",
                                            SecondLevelPenalty,
                                            (entry_dir_i > 0 ? "resistance" : "support"),
                                            second_lvl, first_lvl);
                     if((SecondLevelPrintOnUse && VerboseLogs))
                        PrintFormat("[SIRUS v205 SECOND LEVEL] %s at %.2f (strength %.2f) sits behind %.2f (%.2f) - the trade is really facing the stronger one",
                                    (entry_dir_i > 0 ? "resistance" : "support"),
                                    second_lvl, s_second, first_lvl, s_first);
                  }
               }
            }
         }
      }

      // V219: before scoring the layers separately - do they describe one situation? Falling swing
      // highs, price at a support, and a rejection printing there is not three facts worth a few
      // points each; it is a downtrend testing a level that is holding, and it means more than the
      // sum. Change one part - the rejection fails instead of holding - and the conclusion inverts
      // completely, which adding scores cannot express.
      if(EnableSituationRead && entry_dir_i != 0)
      {
         int    sit_dir = 0;
         double sit_w = 0.0;
         string sit_detail = "";
         int    sit = ReadSituation(sit_dir, sit_w, sit_detail);

         if(sit != SIT_NONE && sit_dir != 0 && sit_w >= SituationMinWeight)
         {
            G_SITUATION = sit;
            G_SITUATION_DIR = sit_dir;

            int sit_adj = (int)MathRound(sit_w * (double)SituationScore);
            sit_adj = MathMax(1, sit_adj);

            if(sit_dir == entry_dir_i)
            {
               G_SCORE_BONUS += sit_adj;
               detail += StringFormat(" +%d %s: %s;", sit_adj, SituationName(sit), sit_detail);
            }
            else
            {
               G_SCORE_PENALTY += sit_adj;
               G_PENALTY_QUALITY += sit_adj;
               detail += StringFormat(" -%d against %s: %s;", sit_adj, SituationName(sit), sit_detail);
            }

            if((SituationPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v219 SITUATION] %s - %s | dir=%d weight %.2f",
                           SituationName(sit), sit_detail, sit_dir, sit_w);
         }
      }

      // V207: what are the candles themselves saying, read as a sequence rather than one at a time?
      // The same bar means different things in different places - an expanding range is a breakout
      // after quiet bars and exhaustion after loud ones - so the state is interpreted against where
      // price actually is, not scored on its own.
      if(EnableCandleSequence && entry_dir_i != 0)
      {
         int    cs_dir = 0;
         double cs_conf = 0.0;
         string cs_detail = "";
         int    cs_state = CandleSequenceRead(cs_dir, cs_conf, cs_detail);

         int cs_adj = 0;
         string cs_why = "";

         switch(cs_state)
         {
            case CANDLE_STATE_REJECTION:
               // A level is being defended. Trading with the rejection is trading with whoever
               // defended it; trading against it means being on the side that just lost.
               if(cs_dir == entry_dir_i)      { cs_adj = +CandleRejectionBonus; cs_why = "rejection with us"; }
               else if(cs_dir == -entry_dir_i){ cs_adj = -CandleRejectionPenalty; cs_why = "rejection against us"; }
               break;

            case CANDLE_STATE_ABSORPTION:
               // Effort without result - a wide range that closed nowhere. Somebody large is on the
               // other side of the move, and it is usually not the side that looks obvious.
               if(cs_dir == -entry_dir_i)     { cs_adj = -CandleAbsorptionPenalty; cs_why = "absorption against us"; }
               break;

            case CANDLE_STATE_EXPANDING:
               // Ranges growing means the move is being driven. With us that is participation;
               // against us it is what the counter-impulse checks exist for, so this only adds a
               // small amount rather than duplicating them.
               if(cs_dir == entry_dir_i)      { cs_adj = +CandleExpansionBonus; cs_why = "expansion with us"; }
               else if(cs_dir == -entry_dir_i){ cs_adj = -CandleExpansionBonus; cs_why = "expansion against us"; }
               break;

            case CANDLE_STATE_CONTRACTING:
               // The move is losing participants. Entering WITH a fading move is the late-entry
               // problem in another form; entering against a fading move is early but reasonable.
               if(cs_dir == entry_dir_i)      { cs_adj = -CandleContractionPenalty; cs_why = "entering with a fading move"; }
               break;

            case CANDLE_STATE_INSIDE:
               // A pause. Not a signal either way - but it means the last bar resolved nothing,
               // so any reading taken from it is weaker than it looks.
               cs_adj = -CandleInsidePenalty;
               cs_why = "inside bar - last candle resolved nothing";
               break;
         }

         // V216: weighted by how often this reading has actually been right here.
         if(cs_adj != 0 && cs_dir != 0)
            cs_adj = (cs_adj > 0) ? CandleWeighted(CSRC_SEQUENCE, cs_dir, cs_adj)
                                  : -CandleWeighted(CSRC_SEQUENCE, cs_dir, -cs_adj);

         if(cs_adj > 0)
         {
            G_SCORE_BONUS += cs_adj;
            detail += StringFormat(" +%d %s;", cs_adj, cs_why);
            G_CANDLE_BONUS += cs_adj;
         }
         else if(cs_adj < 0)
         {
            G_SCORE_PENALTY += -cs_adj;
            G_PENALTY_QUALITY += -cs_adj;
            G_CANDLE_PENALTY += -cs_adj;
            detail += StringFormat(" %d %s;", cs_adj, cs_why);
         }

         if((CandleSequencePrintOnUse && VerboseLogs) && cs_adj != 0)
            PrintFormat("[SIRUS v207 CANDLES] %s | %s", cs_detail, cs_why);
      }

      // V208: the same candle, refined by two questions the sequence reader cannot answer -
      // WHERE it happened and WHOSE wick it is. These adjust the reading rather than replace it:
      // the sequence says what the candles are doing, these say how much to believe it.
      if(entry_dir_i != 0)
      {
         // Authorship first - it decides which wick is worth locating.
         double au_conv = 0.0;
         string au_detail = "";
         int au_side = CandleWickAuthorship(au_conv, au_detail);

         if(au_side != 0 && au_conv >= CandleAuthorshipMinToAct)
         {
            // Now: did that wick reach anything? A rejection at a level that has held before is
            // the strongest single-bar signal available; the identical candle in open space is
            // price dipping and someone buying, which means nothing.
            double loc_level = 0.0;
            string loc_detail = "";
            double loc_w = CandleLocationWeight(au_side, loc_level, loc_detail);

            // The signal is the wick's conviction scaled by where it happened. With no level
            // under it, the location weight is zero and the whole thing correctly contributes
            // nothing - which is the point.
            double signal = au_conv * loc_w;

            if(signal >= CandleLocationMinSignal)
            {
               int adj = (int)MathRound(signal * (double)CandleLocationMaxScore);
               adj = MathMax(1, MathMin(CandleLocationMaxScore, adj));
               adj = CandleWeighted(CSRC_AUTHORSHIP, au_side, adj);
               if(adj <= 0) adj = 0;

               if(au_side == entry_dir_i)
               {
                  G_SCORE_BONUS += adj;
                  detail += StringFormat(" +%d %s | %s;", adj, au_detail, loc_detail);
                  G_CANDLE_BONUS += adj;
               }
               else
               {
                  G_SCORE_PENALTY += adj;
                  G_PENALTY_QUALITY += adj;
                  detail += StringFormat(" -%d against: %s | %s;", adj, au_detail, loc_detail);
                  G_CANDLE_PENALTY += adj;
               }

               if((CandleLocationPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v208 CANDLE] %s | %s | signal %.2f", au_detail, loc_detail, signal);
            }
         }
      }

      // V210: was anybody there? A candle's shape says what happened; its volume says whether the
      // market participated. On XAUUSD a wide bar on thin volume is a few orders moving an empty
      // book - it retraces as easily as it came - while the same bar on heavy volume is a market
      // that showed up.
      if(EnableCandleParticipation && entry_dir_i != 0)
      {
         double part = CandleParticipation(1);
         int    p_dir = 0;
         {
            double po = CandleOpen(CandleSequenceTF, 1), pc = CandleClose(CandleSequenceTF, 1);
            if(po > 0.0 && pc > 0.0) p_dir = (pc > po) ? 1 : ((pc < po) ? -1 : 0);
         }

         if(p_dir != 0)
         {
            if(part >= CandleParticipationStrong)
            {
               // Heavy participation makes the candle mean more, in whichever direction it points.
               if(p_dir == entry_dir_i)
               {
                  G_SCORE_BONUS += CandleParticipationScore;
                  G_CANDLE_BONUS += CandleParticipationScore;
                  detail += StringFormat(" +%d candle backed by %.1fx volume;", CandleParticipationScore, part);
               }
               else
               {
                  G_SCORE_PENALTY += CandleParticipationScore;
                  G_PENALTY_QUALITY += CandleParticipationScore;
                  G_CANDLE_PENALTY += CandleParticipationScore;
                  detail += StringFormat(" -%d opposing candle backed by %.1fx volume;", CandleParticipationScore, part);
               }
            }
            else if(part <= CandleParticipationThin && p_dir == entry_dir_i)
            {
               // Our own candle happened on nothing - a weaker reason to act than it appears.
               G_SCORE_PENALTY += CandleParticipationScore;
               G_PENALTY_CONDITIONS += CandleParticipationScore;
               G_CANDLE_PENALTY += CandleParticipationScore;
               detail += StringFormat(" -%d candle on thin %.1fx volume;", CandleParticipationScore, part);
            }
         }
      }

      // V210: what the open says. A bar that gapped up and closed below its open was sold into -
      // information the body cannot carry, because the body starts at the open.
      if(EnableCandleOpeningBias && entry_dir_i != 0)
      {
         string ob_detail = "";
         double ob = CandleOpeningBias(ob_detail);
         if(MathAbs(ob) >= 0.15 && StringLen(ob_detail) > 0)
         {
            int ob_dir = (ob > 0.0) ? 1 : -1;
            int ob_adj = (int)MathRound(MathAbs(ob) * (double)CandleOpeningScore);
            if(ob_adj > 0)
            {
               if(ob_dir == entry_dir_i)
               {
                  G_SCORE_BONUS += ob_adj;
                  G_CANDLE_BONUS += ob_adj;
                  detail += StringFormat(" +%d %s;", ob_adj, ob_detail);
               }
               else
               {
                  G_SCORE_PENALTY += ob_adj;
                  G_PENALTY_QUALITY += ob_adj;
                  G_CANDLE_PENALTY += ob_adj;
                  detail += StringFormat(" -%d %s;", ob_adj, ob_detail);
               }
            }
         }
      }

      // V210: a recognised shape. These need two or three bars in a specific arrangement, which is
      // why they mark turns rather than continuations - and a turn is precisely what a setup
      // waiting at a level is waiting for.
      if(EnableCandlePatterns && entry_dir_i != 0)
      {
         int    cp_dir = 0;
         double cp_conf = 0.0;
         string cp_detail = "";
         int    cp_pat = CandlePatternRead(cp_dir, cp_conf, cp_detail);

         if(cp_pat != CPAT_NONE && cp_dir != 0 && cp_conf > 0.0)
         {
            double weight = cp_conf;
            string extra = "";

            // V211: where did it form? A morning star at a support that has held is a turn
            // beginning at the level that produces turns; the same three candles in open space
            // are three candles.
            double pl_level = 0.0;
            string pl_detail = "";
            double pl_w = CandlePatternLocation(cp_dir, pl_level, pl_detail);
            if(EnablePatternLocation)
            {
               weight *= (PatternLocationFloor + (1.0 - PatternLocationFloor) * pl_w);
               if(pl_w > 0.0) extra += " " + pl_detail;
            }

            // V211: and has this shape been working here? Reputation is not a record.
            double pwr = PatternWinRate(cp_pat);
            if(pwr >= 0.0)
            {
               if(pwr <= PatternGradePoorRate)
               {
                  weight *= PatternGradePoorFactor;
                  extra += StringFormat(" [only %.0f%% here]", pwr * 100.0);
               }
               else if(pwr >= (1.0 - PatternGradePoorRate))
               {
                  weight *= PatternGradeGoodFactor;
                  extra += StringFormat(" [%.0f%% here]", pwr * 100.0);
               }
            }

            int cp_adj = (int)MathRound(weight * (double)CandlePatternScore);
            cp_adj = CandleWeighted(CSRC_PATTERN, cp_dir, cp_adj);

            if(cp_adj > 0)
            {
               if(cp_dir == entry_dir_i)
               {
                  G_SCORE_BONUS += cp_adj;
                  G_CANDLE_BONUS += cp_adj;
                  detail += StringFormat(" +%d %s%s;", cp_adj, cp_detail, extra);
               }
               else
               {
                  G_SCORE_PENALTY += cp_adj;
                  G_PENALTY_QUALITY += cp_adj;
                  G_CANDLE_PENALTY += cp_adj;
                  detail += StringFormat(" -%d %s against%s;", cp_adj, cp_detail, extra);
               }
            }

            // Record it so the next occurrence is judged on evidence rather than reputation.
            {
               double pj_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double pj_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double pj_mid = (pj_bid > 0.0 && pj_ask > 0.0) ? (pj_bid + pj_ask) / 2.0 : pj_bid;
               if(pj_mid > 0.0)
                  PatternJudgeArm(cp_pat, cp_dir, pj_mid);
            }

            if((CandlePatternPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v211 PATTERN] %s%s | weight %.2f | entry dir=%d",
                           cp_detail, extra, weight, entry_dir_i);
         }
      }

      // V212: the bar that is still forming. This is the only reading here that does not wait for a
      // close, and it is deliberately limited: it can strengthen or weaken a decision the closed
      // bars already point toward, and it cannot create one. A live wick at forty seconds is a
      // rejection in progress; it is also a shape that can be gone by fifty-five, so it earns
      // influence in proportion to how much of the bar has actually happened.
      if(EnableLiveBarRead && entry_dir_i != 0)
      {
         int    lb_dir = 0;
         double lb_weight = 0.0;
         string lb_detail = "";
         int    lb_state = LiveBarRead(lb_dir, lb_weight, lb_detail);

         if(lb_state != CANDLE_STATE_NEUTRAL && lb_weight >= LiveBarMinWeight)
         {
            int lb_adj = 0;
            string lb_why = "";

            switch(lb_state)
            {
               case CANDLE_STATE_REJECTION:
                  // A level is being defended right now. With us this is the earliest confirmation
                  // available; against us it is the earliest warning.
                  if(lb_dir == entry_dir_i)      { lb_adj = +LiveBarScore; lb_why = "live rejection with us"; }
                  else if(lb_dir == -entry_dir_i){ lb_adj = -LiveBarScore; lb_why = "live rejection against us"; }
                  break;

               case CANDLE_STATE_EXPANDING:
                  // A body being driven through as we watch. Against us this is the counter-impulse
                  // case arriving a minute early.
                  if(lb_dir == -entry_dir_i)     { lb_adj = -LiveBarScore; lb_why = "live bar driving against us"; }
                  else if(lb_dir == entry_dir_i) { lb_adj = +LiveBarScore / 2; lb_why = "live bar driving with us"; }
                  break;

               case CANDLE_STATE_ABSORPTION:
                  // Both sides active and neither winning - whatever the closed bars concluded is
                  // being contested right now.
                  lb_adj = -LiveBarScore / 2;
                  lb_why = "live bar contested";
                  break;
            }

            // Scaled by how much of the bar has formed. Early in the bar this reduces almost
            // everything to nothing, which is the correct treatment of a shape that can still
            // reverse entirely.
            lb_adj = (int)MathRound((double)lb_adj * lb_weight);
            if(lb_adj != 0 && lb_dir != 0)
               lb_adj = (lb_adj > 0) ? CandleWeighted(CSRC_LIVEBAR, lb_dir, lb_adj)
                                     : -CandleWeighted(CSRC_LIVEBAR, lb_dir, -lb_adj);

            if(lb_adj > 0)
            {
               G_SCORE_BONUS += lb_adj;
               G_CANDLE_BONUS += lb_adj;
               detail += StringFormat(" +%d %s;", lb_adj, lb_why);
            }
            else if(lb_adj < 0)
            {
               G_SCORE_PENALTY += -lb_adj;
               G_PENALTY_QUALITY += -lb_adj;
               G_CANDLE_PENALTY += -lb_adj;
               detail += StringFormat(" %d %s;", lb_adj, lb_why);
            }

            if((LiveBarPrintOnUse && VerboseLogs) && lb_adj != 0)
               PrintFormat("[SIRUS v212 LIVE BAR] %s | %s", lb_detail, lb_why);
         }
      }

      // V218: where in the current bar is this fill landing? From a live loss - a buy at 4394.43 on
      // a bar that had spiked to 4397 and come back. Everything else here reads bar 1 and later, so
      // the bar the entry actually opens on was never examined, and a fill into the wick of a sweep
      // looked identical to a fill at the low of a strong bar.
      if(EnableEntryBarCheck && entry_dir_i != 0)
      {
         string eb_detail = "";
         double eb_sev = EntryBarPlacement(entry_dir_i, eb_detail);

         if(eb_sev >= EntryBarMinSeverity)
         {
            int eb_pen = (int)MathRound(eb_sev * (double)EntryBarPenalty);
            eb_pen = MathMax(1, eb_pen);
            G_SCORE_PENALTY += eb_pen;
            G_PENALTY_QUALITY += eb_pen;
            detail += StringFormat(" -%d %s;", eb_pen, eb_detail);

            if((EntryBarPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v218 ENTRY BAR] %s | dir=%d | severity %.2f",
                           eb_detail, entry_dir_i, eb_sev);
         }
      }

      // V218: the plain shape of the recent swings. On M5 the losing move was 4402, then 4398, then
      // 4394 - three lower highs, and the entry was at the third. The EA reads trend direction and
      // structure breaks, but not the arithmetic a trader sees instantly: each swing high is below
      // the last, so this is a downtrend whatever the indicators say.
      // V225: what do the timeframes say TOGETHER? The measured structure reads M5 and treats what
      // it finds as the answer. Three lower highs on M5 inside a rising M15 is a pullback - selling
      // it means selling the dip of an uptrend - and it is indistinguishable from the real thing
      // without looking up.
      if(EnableStructureMTF && entry_dir_i != 0)
      {
         int    al_dir = 0;
         double al_w = 0.0;
         string al_detail = "";
         int    al = StructureAlignment(al_dir, al_w, al_detail);

         switch(al)
         {
            case TFALIGN_FULL:
            {
               // Everything agreeing is the rarest condition on the chart, and trading against it
               // is the most expensive thing available.
               int adj = (int)MathRound(al_w * (double)StructureAlignScore);
               adj = MathMax(1, adj);
               if(al_dir == entry_dir_i)
               {
                  G_SCORE_BONUS += adj;
                  detail += StringFormat(" +%d %s;", adj, al_detail);
                  G_STRUCT_BONUS += adj;
               }
               else
               {
                  G_SCORE_PENALTY += adj;
                  G_PENALTY_TREND_AGAINST += adj;
                  detail += StringFormat(" -%d against %s;", adj, al_detail);
                  G_STRUCT_PENALTY += adj;
               }
               break;
            }

            case TFALIGN_PULLBACK:
            {
               // The lower timeframe is giving back inside a larger move. The trade runs with the
               // higher timeframes; taking the lower one's direction is buying the correction.
               int adj = (int)MathRound(al_w * (double)StructurePullbackScore);
               adj = MathMax(1, adj);
               if(al_dir == entry_dir_i)
               {
                  G_SCORE_BONUS += adj;
                  detail += StringFormat(" +%d entering with the %s;", adj, al_detail);
                  G_STRUCT_BONUS += adj;
               }
               else
               {
                  G_SCORE_PENALTY += adj;
                  G_PENALTY_TREND_AGAINST += adj;
                  detail += StringFormat(" -%d trading the %s as if it were the trend;", adj, al_detail);
                  G_STRUCT_PENALTY += adj;
               }
               break;
            }

            case TFALIGN_TRANSITION:
            {
               // Middle and higher disagree. Something is changing and nothing is decided - the
               // worst moment to commit to either side, whichever side that is.
               int adj = (int)MathRound(al_w * (double)StructureTransitionPenalty);
               adj = MathMax(1, adj);
               G_SCORE_PENALTY += adj;
               G_PENALTY_CONDITIONS += adj;
               detail += StringFormat(" -%d %s;", adj, al_detail);
               break;
            }
         }

         if((StructureMTFPrintOnUse && VerboseLogs) && al != TFALIGN_NONE && StringLen(al_detail) > 0)
            PrintFormat("[SIRUS v225 MTF] %s | entry dir=%d", al_detail, entry_dir_i);
      }

      // V225: and how much of the move is already behind us? Three steps covering eight dollars and
      // three steps covering eighty cents read identically to a step count, and they are not the
      // same trade - the first is nearly finished.
      if(EnableStructureMaturity && entry_dir_i != 0)
      {
         string mt_detail = "";
         double maturity = StructureMaturity(mt_detail);

         if(maturity >= StructureMatureFrom && G_LS_DIR != 0)
         {
            double over = (maturity - StructureMatureFrom) / MathMax(0.01, 1.0 - StructureMatureFrom);
            int mt_adj = (int)MathRound(over * (double)StructureMaturityScore);

            if(mt_adj > 0)
            {
               if(G_LS_DIR == entry_dir_i)
               {
                  // Joining a structure that has already run most of its distance.
                  G_SCORE_PENALTY += mt_adj;
                  G_PENALTY_IMPULSE += mt_adj;
                  detail += StringFormat(" -%d joining late: %s;", mt_adj, mt_detail);
               }
               else
               {
                  // Fading one that has run its distance is the better side of the same fact.
                  G_SCORE_BONUS += mt_adj;
                  detail += StringFormat(" +%d fading a mature structure: %s;", mt_adj, mt_detail);
               }
            }
         }
      }

      // V223: the measured structure - shape, step size and where it ends. This runs alongside the
      // simpler swing count rather than replacing it: the count says which way, the measurements say
      // how much to believe it and what would end it.
      if(EnableLocalStructure && entry_dir_i != 0)
      {
         LocalStructureUpdate();

         if(G_LS_DIR != 0 && G_LS_STATE != LSTRUCT_CHOPPY && G_LS_CONVICTION > 0.0)
         {
            double ls_weight = G_LS_CONVICTION;
            string ls_extra = "";

            // A fading structure is losing participants - the last swing before a turn is almost
            // always the smallest, so trading WITH a fading move is late and against it is early
            // but reasonable.
            if(G_LS_STATE == LSTRUCT_FADING)
            {
               if(G_LS_DIR == entry_dir_i)
               {
                  ls_weight *= LocalStructureFadeWithFactor;
                  ls_extra = " (fading - late)";
               }
               else
               {
                  ls_weight *= LocalStructureFadeAgainstFactor;
                  ls_extra = " (fading - turn possible)";
               }
            }
            else if(G_LS_STATE == LSTRUCT_EXPANDING)
            {
               // Accelerating. With us that is participation; against us it is the worst time to
               // take the other side.
               ls_weight *= LocalStructureExpandFactor;
               ls_extra = " (expanding)";
            }

            int ls_adj = (int)MathRound(ls_weight * (double)LocalStructureScore);

            if(ls_adj > 0)
            {
               if(G_LS_DIR == entry_dir_i)
               {
                  G_SCORE_BONUS += ls_adj;
                  G_STRUCT_BONUS += ls_adj;
                  detail += StringFormat(" +%d %s%s;", ls_adj, G_LS_DETAIL, ls_extra);
               }
               else
               {
                  G_SCORE_PENALTY += ls_adj;
                  G_PENALTY_TREND_AGAINST += ls_adj;
                  G_STRUCT_PENALTY += ls_adj;
                  detail += StringFormat(" -%d against %s%s;", ls_adj, G_LS_DETAIL, ls_extra);
               }
            }

            // How far is the invalidation? A counter-trend entry with the structure's end price
            // close by has a defined, cheap risk; one with it far away does not.
            if(G_LS_INVALIDATE > 0.0 && G_LS_DIR == -entry_dir_i && _Point > 0.0)
            {
               double inv_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double inv_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double inv_mid = (inv_bid > 0.0 && inv_ask > 0.0) ? (inv_bid + inv_ask) / 2.0 : inv_bid;
               if(inv_mid > 0.0)
               {
                  double inv_dist = MathAbs(G_LS_INVALIDATE - inv_mid) / _Point;
                  if(inv_dist <= (double)LocalStructureNearInvalidation)
                  {
                     G_SCORE_BONUS += LocalStructureInvalidationBonus;
                     G_STRUCT_BONUS += LocalStructureInvalidationBonus;
                     detail += StringFormat(" +%d structure ends %.0f pts away at %.2f;",
                                            LocalStructureInvalidationBonus, inv_dist, G_LS_INVALIDATE);
                  }
               }
            }

            if((LocalStructurePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v223 STRUCTURE] %s | entry dir=%d", G_LS_DETAIL, entry_dir_i);
         }
      }

      // V224: has a structure just ENDED? This is the highest-information moment available - not an
      // indicator crossing a threshold, but the thing being measured changing state. A falling
      // sequence that closes above its last lower high is no longer a falling sequence, by
      // definition rather than by opinion.
      if(EnableStructureBreak && entry_dir_i != 0)
      {
         double br_fresh = 0.0, br_price = 0.0;
         int    br_dir = RecentStructureBreak(br_fresh, br_price);

         if(br_dir != 0 && br_fresh > 0.0)
         {
            int br_adj = (int)MathRound(br_fresh * (double)StructureBreakScore);
            br_adj = MathMax(1, br_adj);

            if(br_dir == entry_dir_i)
            {
               G_SCORE_BONUS += br_adj;
               G_STRUCT_BONUS += br_adj;
               detail += StringFormat(" +%d structure broke %.2f in our favour;", br_adj, br_price);
            }
            else
            {
               G_SCORE_PENALTY += br_adj;
               G_PENALTY_TREND_AGAINST += br_adj;
               G_STRUCT_PENALTY += br_adj;
               detail += StringFormat(" -%d structure broke %.2f against us;", br_adj, br_price);
            }
         }
      }

      // V224: does the structure's end coincide with a zone? Two independent readings landing on the
      // same price is stronger than either alone - and when they disagree, the picture is less clear
      // than either suggests.
      if(EnableStructureConfluence && entry_dir_i != 0)
      {
         double cf_level = 0.0;
         string cf_detail = "";
         double cf_w = StructureLevelConfluence(cf_level, cf_detail);

         if(cf_w >= StructureConfluenceMinWeight && G_LS_DIR != 0)
         {
            // The confluence price is what a counter-trend entry is heading toward and what a
            // with-trend entry is running away from.
            int cf_adj = (int)MathRound(cf_w * (double)StructureConfluenceScore);
            cf_adj = MathMax(1, cf_adj);

            if(G_LS_DIR == -entry_dir_i)
            {
               // Trading against the structure, toward a price two readings agree on.
               G_SCORE_BONUS += cf_adj;
               G_STRUCT_BONUS += cf_adj;
               detail += StringFormat(" +%d %s;", cf_adj, cf_detail);
            }
         }
      }

      if(EnableLocalSwingShape && entry_dir_i != 0)
      {
         int    sw_steps = 0;
         double sw_conv = 0.0;
         string sw_detail = "";
         int    sw_dir = LocalSwingShape(sw_steps, sw_conv, sw_detail);

         if(sw_dir != 0 && sw_conv > 0.0)
         {
            int sw_adj = (int)MathRound(sw_conv * (double)LocalSwingScore);
            sw_adj = MathMax(1, sw_adj);

            if(sw_dir == entry_dir_i)
            {
               G_SCORE_BONUS += sw_adj;
               G_STRUCT_BONUS += sw_adj;
               detail += StringFormat(" +%d %s;", sw_adj, sw_detail);
            }
            else
            {
               // Buying into a sequence of lower highs. This is the case the loss came from, and
               // it belongs with the trend-conflict group rather than quality - it is about
               // direction, not placement.
               G_SCORE_PENALTY += sw_adj;
               G_PENALTY_TREND_AGAINST += sw_adj;
               G_STRUCT_PENALTY += sw_adj;
               detail += StringFormat(" -%d entering against %s;", sw_adj, sw_detail);

               if((LocalSwingPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v218 SWINGS] %s | entry dir=%d", sw_detail, entry_dir_i);
            }
         }
      }

      // V215: do the candle readings disagree, and does that disagreement have a name? A rejection
      // that was then traded through is not a weaker rejection - it is a defence breaking, which is
      // a different and more useful thing than either reading. Summing them cancels it.
      if(EnableCandleConflict && entry_dir_i != 0)
      {
         int    cf_dir = 0;
         double cf_w = 0.0;
         string cf_detail = "";
         int    cf = CandleConflictRead(cf_dir, cf_w, cf_detail);

         if((cf == CCONF_DEFENCE_BROKE || cf == CCONF_PUSH_STALLED) && cf_dir != 0 && cf_w > 0.0)
         {
            int cf_adj = (int)MathRound(cf_w * (double)CandleConflictScore);
            cf_adj = MathMax(1, cf_adj);
            cf_adj = CandleWeighted(CSRC_CONFLICT, cf_dir, cf_adj);
            if(cf_adj <= 0) cf_adj = 0;

            if(cf_dir == entry_dir_i)
            {
               G_SCORE_BONUS += cf_adj;
               G_CANDLE_BONUS += cf_adj;
               detail += StringFormat(" +%d %s;", cf_adj, cf_detail);
            }
            else
            {
               G_SCORE_PENALTY += cf_adj;
               G_PENALTY_QUALITY += cf_adj;
               G_CANDLE_PENALTY += cf_adj;
               detail += StringFormat(" -%d %s against;", cf_adj, cf_detail);
            }

            if((CandleConflictPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v215 CONFLICT] %s | dir=%d | weight %.2f",
                           cf_detail, cf_dir, cf_w);
         }
      }

      // V213: what changed inside the bar. This is the reading that arrives earliest of all, because
      // it does not need the bar to finish - only to have moved. A wick that existed and has been
      // traded through says buyers defended that low and were beaten, and it says so while the
      // beating is still happening.
      if(EnableLiveBarEvolution && entry_dir_i != 0)
      {
         int    ev_dir = 0;
         double ev_w = 0.0;
         string ev_detail = "";
         int    ev = LiveBarEvolution(ev_dir, ev_w, ev_detail);

         if(ev != LIVE_EVO_NONE && ev_dir != 0 && ev_w >= LiveBarMinWeight)
         {
            int ev_adj = (int)MathRound(ev_w * (double)LiveEvolutionScore);
            ev_adj = MathMax(1, ev_adj);
            ev_adj = CandleWeighted(CSRC_EVOLUTION, ev_dir, ev_adj);
            if(ev_adj <= 0) ev_adj = 0;

            if(ev_dir == entry_dir_i)
            {
               G_SCORE_BONUS += ev_adj;
               G_CANDLE_BONUS += ev_adj;
               detail += StringFormat(" +%d %s;", ev_adj, ev_detail);
            }
            else
            {
               G_SCORE_PENALTY += ev_adj;
               G_PENALTY_QUALITY += ev_adj;
               G_CANDLE_PENALTY += ev_adj;
               detail += StringFormat(" -%d %s against;", ev_adj, ev_detail);
            }

            if((LiveEvolutionPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v213 EVOLUTION] %s | entry dir=%d | weight %.2f",
                           ev_detail, entry_dir_i, ev_w);
         }
      }

      // V213: is price running into a level right now? Not a level the trade might reach later -
      // one it is closing on within this bar, untested. Entering here means buying the last of the
      // move into the thing that stops it.
      if(EnableLiveApproach && entry_dir_i != 0)
      {
         double ap_dist = 0.0;
         string ap_detail = "";
         double ap_level = LiveApproachingLevel(entry_dir_i, ap_dist, ap_detail);

         if(ap_level > 0.0)
         {
            // Closer means worse - there is less room left before the level is reached.
            double reach = ScaleAdjustedPoints(MathMax(1, LiveApproachPoints));
            double closeness = 1.0 - (ap_dist / MathMax(1.0, reach));
            int ap_pen = (int)MathRound(closeness * (double)LiveApproachPenalty);
            if(ap_pen > 0)
            {
               G_SCORE_PENALTY += ap_pen;
               G_PENALTY_QUALITY += ap_pen;
               detail += StringFormat(" -%d %s;", ap_pen, ap_detail);
            }
         }
      }

      // V211: which timeframe is speaking? The candle reader runs on M1, and an M1 signal inside a
      // strong M5 candle pointing the other way is a pullback being read as a reversal - which is
      // exactly the "strong buy candles then sell" mistake. The higher timeframe does not veto the
      // lower one; it decides how much the lower one is allowed to mean.
      if(EnableCandleHTF && entry_dir_i != 0)
      {
         double htf_body = 0.0;
         string htf_detail = "";
         int htf_agree = CandleHTFAgreement(entry_dir_i, htf_body, htf_detail);

         if(htf_agree < 0)
         {
            // Scaled by how decisive the higher candle is - a marginal one says little, a
            // full-bodied one says the lower reading is noise inside a larger move.
            int htf_pen = (int)MathRound(htf_body * (double)CandleHTFDisagreeScore);
            htf_pen = MathMax(1, MathMin(CandleHTFDisagreeScore, htf_pen));
            htf_pen = CandleWeighted(CSRC_HTF, -entry_dir_i, htf_pen);
            if(htf_pen <= 0) htf_pen = 1;
            G_SCORE_PENALTY += htf_pen;
            G_PENALTY_TREND_AGAINST += htf_pen;
            G_CANDLE_PENALTY += htf_pen;
            detail += StringFormat(" -%d %s;", htf_pen, htf_detail);
            if((CandleHTFPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v211 HTF] %s | entry dir=%d", htf_detail, entry_dir_i);
         }
         else if(htf_agree > 0 && htf_body >= CandleHTFStrongBody)
         {
            G_SCORE_BONUS += CandleHTFAgreeScore;
            G_CANDLE_BONUS += CandleHTFAgreeScore;
            detail += StringFormat(" +%d %s;", CandleHTFAgreeScore, htf_detail);
         }
      }

      // V209: record this candle so its outcome can be graded, and weigh the reading by how such
      // candles have actually been resolving lately. A market where rejections keep failing is one
      // where a rejection means less - which is something only the record can say.
      if(EnableCandleFollowThrough && entry_dir_i != 0)
      {
         double ft_conv = 0.0;
         string ft_detail = "";
         int ft_side = CandleWickAuthorship(ft_conv, ft_detail);

         if(ft_side != 0 && ft_conv >= CandleAuthorshipMinToAct)
         {
            double tip = (ft_side > 0) ? CandleLow(CandleSequenceTF, 1)
                                       : CandleHigh(CandleSequenceTF, 1);
            if(tip > 0.0)
               CandleEventRecord(1, ft_side, tip);
         }

         double rel = CandleRejectionReliability();
         if(rel >= 0.0 && ft_side != 0)
         {
            // A good record makes a rejection worth more; a poor one makes it worth less, and
            // that applies whichever side the rejection favours.
            if(rel <= CandleFollowThroughPoorRate)
            {
               G_SCORE_PENALTY += CandleFollowThroughAdjust;
               G_PENALTY_CONDITIONS += CandleFollowThroughAdjust;
               detail += StringFormat(" -%d rejections only holding %.0f%% here;",
                                      CandleFollowThroughAdjust, rel * 100.0);
            }
            else if(rel >= (1.0 - CandleFollowThroughPoorRate) && ft_side == entry_dir_i)
            {
               G_SCORE_BONUS += CandleFollowThroughAdjust;
               detail += StringFormat(" +%d rejections holding %.0f%% here;",
                                      CandleFollowThroughAdjust, rel * 100.0);
            }
         }
      }

      // V209: how did the candle cross the level it was aimed at? This is the "support broke, so
      // sell again" case: a close beyond a level with a long wick back is not a break, it is an
      // attempt the level was already pushing back inside the same bar - and selling under it is
      // selling into the level rather than through it.
      if(EnableCandleBreakQuality && entry_dir_i != 0)
      {
         double bq_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double bq_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bq_mid = (bq_bid > 0.0 && bq_ask > 0.0) ? (bq_bid + bq_ask) / 2.0 : bq_bid;

         if(bq_mid > 0.0)
         {
            // The level this entry is trading through is the one just behind price in the entry
            // direction - a sell trades down through support, a buy up through resistance.
            double bq_level = (entry_dir_i > 0) ? ZoneMapNearestResistance(bq_mid)
                                                : ZoneMapNearestSupport(bq_mid);
            if(bq_level > 0.0)
            {
               double bq_q = 0.0;
               string bq_detail = "";
               int bq_res = CandleBreakQuality(bq_level, entry_dir_i, bq_q, bq_detail);

               if(bq_res > 0)
               {
                  CandleEventRecord(2, entry_dir_i, bq_level);
                  int add = (int)MathRound(bq_q * (double)CandleBreakQualityScore);
                  if(add > 0)
                  {
                     G_SCORE_BONUS += add;
                     detail += StringFormat(" +%d %s;", add, bq_detail);
                  }
               }
               else if(bq_res < 0)
               {
                  int pen = (int)MathRound(MathMax(0.4, bq_q) * (double)CandleBreakQualityScore);
                  G_SCORE_PENALTY += pen;
                  G_PENALTY_QUALITY += pen;
                  detail += StringFormat(" -%d %s;", pen, bq_detail);
               }

               // And whether breaks have been holding at all lately.
               double brel = CandleBreakReliability();
               if(brel >= 0.0 && brel <= CandleFollowThroughPoorRate && bq_res > 0)
               {
                  G_SCORE_PENALTY += CandleFollowThroughAdjust;
                  G_PENALTY_CONDITIONS += CandleFollowThroughAdjust;
                  detail += StringFormat(" -%d breaks only holding %.0f%% here;",
                                         CandleFollowThroughAdjust, brel * 100.0);
               }
            }
         }
      }



      // V239: did the candle get through the one before it? From the losing buy, annotated as "the
      // candle did not break the previous body" - the plainest statement of a push failing, and the
      // EA had no way to express it. Body size, wick share and direction all read fine; what none of
      // them asks is whether the bar achieved anything.
      if(EnableCandleProgress && entry_dir_i != 0)
      {
         string cp_detail = "";
         double cp_sev = CandleFailedProgress(entry_dir_i, cp_detail);

         if(cp_sev >= CandleProgressMinSeverity)
         {
            int cp_pen = (int)MathRound(cp_sev * (double)CandleProgressPenalty);
            cp_pen = MathMax(1, cp_pen);
            G_SCORE_PENALTY += cp_pen;
            G_PENALTY_QUALITY += cp_pen;
            G_CANDLE_PENALTY += cp_pen;
            detail += StringFormat(" -%d %s;", cp_pen, cp_detail);

            if((CandleProgressPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v239 PROGRESS] %s | dir=%d", cp_detail, entry_dir_i);
         }
      }

      // V248: is there anything happening at all? A dead market is specifically dangerous for a
      // ladder - the range is too tight for the target, so the rungs fill quickly, and then the move
      // that eventually arrives finds a full basket waiting for it.
      if(EnableDeadMarketCheck && entry_dir_i != 0)
      {
         string dm_detail = "";
         double dead = MarketIsDead(dm_detail);
         if(dead >= DeadMarketMinSeverity)
         {
            int dm_pen = (int)MathRound(dead * (double)DeadMarketPenalty);
            dm_pen = MathMax(1, dm_pen);
            G_SCORE_PENALTY += dm_pen;
            G_PENALTY_CONDITIONS += dm_pen;
            detail += StringFormat(" -%d dead market: %s;", dm_pen, dm_detail);
         }
      }

      // V248: is a release happening right now? The calendar knows when they are scheduled; this
      // notices one arriving, which is what matters and which happens whether or not it was listed.
      if(EnableLiveNewsRead && entry_dir_i != 0)
      {
         string nw_detail = "";
         double news = NewsInProgress(nw_detail);
         if(news >= LiveNewsMinSeverity)
         {
            int nw_pen = (int)MathRound(news * (double)LiveNewsPenalty);
            nw_pen = MathMax(1, nw_pen);
            G_SCORE_PENALTY += nw_pen;
            G_PENALTY_CONDITIONS += nw_pen;
            detail += StringFormat(" -%d %s;", nw_pen, nw_detail);

            if((LiveNewsPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v248 NEWS] %s", nw_detail);
         }
      }

      // V245: does the target land inside a band? RoomToTargetPoints already asks whether a wall
      // sits beyond the target, and it reads a single price - so against a band it returns whichever
      // edge happened to be cached. From a live entry: a buy at 4491.35 targeting 4493.85, with a
      // band running 4492.00-4494.15 that had turned price away three times. It saw 4494.15,
      // measured $2.80 of room, and reported plenty for a $2.50 target. The real figure was $0.65 -
      // the distance to where the band STARTS. Everything past that is inside the thing rejecting
      // price.
      if(EnableTargetBandCheck && entry_dir_i != 0)
      {
         double tb_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double tb_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double tb_mid = (tb_bid > 0.0 && tb_ask > 0.0) ? (tb_bid + tb_ask) / 2.0 : tb_bid;

         if(tb_mid > 0.0 && _Point > 0.0)
         {
            double tb_tp = BaseBasketTPPoints();
            if(tb_tp > 0.0)
            {
               double tb_target = tb_mid + (double)entry_dir_i * tb_tp * _Point;
               double tb_lo = 0.0, tb_hi = 0.0;
               string tb_detail = "";
               double tb_sev = TargetInsideBand(entry_dir_i, tb_target, tb_lo, tb_hi, tb_detail);

               if(tb_sev >= TargetBandMinSeverity)
               {
                  int tb_pen = (int)MathRound(tb_sev * (double)TargetBandPenalty);
                  tb_pen = MathMax(1, tb_pen);
                  G_SCORE_PENALTY += tb_pen;
                  G_PENALTY_QUALITY += tb_pen;
                  detail += StringFormat(" -%d %s;", tb_pen, tb_detail);

                  if((TargetBandPrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v245 TARGET BAND] %s | dir=%d", tb_detail, entry_dir_i);
               }
            }
         }
      }

      // V254: has the market moved away from the volatility the settings assume? Every distance
      // here - grid spacing, target, stop - was sized for a particular range. When ATR doubles they
      // are all simultaneously too small and none of them knows it.
      if(EnableVolatilityShift && entry_dir_i != 0)
      {
         string vs_detail = "";
         double vs = VolatilityShift(vs_detail);

         if(vs >= VolatilityShiftHigh)
         {
            // Wider than the settings expect. The target is closer than it looks in ATR terms, but
            // so is the stop, and the grid spacing no longer matches the moves it has to absorb.
            double over = (vs - VolatilityShiftHigh) / MathMax(0.1, VolatilityShiftFull - VolatilityShiftHigh);
            int vs_pen = (int)MathRound(MathMin(1.0, over) * (double)VolatilityShiftPenalty);
            vs_pen = MathMax(1, vs_pen);
            G_SCORE_PENALTY += vs_pen;
            G_PENALTY_CONDITIONS += vs_pen;
            detail += StringFormat(" -%d %s;", vs_pen, vs_detail);

            if((VolatilityShiftPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v254 VOLATILITY] %s", vs_detail);
         }
      }

      // V264: is there a level in the way that the ordinary scan would have skipped? A shelf at
      // 4305-4315 held twice in early September; price returned nine days later and the EA did not
      // see it. The level was never lost - the H1 lookback covers ten days - but the scan returns
      // the NEAREST support, and nine days of trading had put dozens of newer swings between price
      // and that shelf. A level with three touches and a week of history loses to a swing that
      // formed forty minutes ago and has never been tested, because nearest is the only comparison
      // the scan makes.
      if(EnableProtectedZones && entry_dir_i != 0)
      {
         double pz_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pz_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double pz_mid = (pz_bid > 0.0 && pz_ask > 0.0) ? (pz_bid + pz_ask) / 2.0 : pz_bid;

         if(pz_mid > 0.0 && _Point > 0.0)
         {
            double pz_str = 0.0;
            string pz_detail = "";
            double pz_level = ProtectedZoneNear(pz_mid, entry_dir_i, pz_str, pz_detail);

            if(pz_level > 0.0 && pz_str >= ProtectedZoneMinStrength)
            {
               double pz_gap = MathAbs(pz_level - pz_mid) / _Point;
               double pz_tp = BaseBasketTPPoints();

               // Only a problem when it sits between the entry and where the trade is going.
               if(pz_tp > 0.0 && pz_gap < pz_tp)
               {
                  double pz_short = 1.0 - (pz_gap / pz_tp);
                  double pz_weight = MathMin(1.0, pz_str / MathMax(0.1, ProtectedZoneFullStrength));
                  int pz_pen = (int)MathRound(pz_short * pz_weight * (double)ProtectedZonePenalty);
                  pz_pen = MathMax(1, pz_pen);

                  G_SCORE_PENALTY += pz_pen;
                  G_PENALTY_QUALITY += pz_pen;
                  detail += StringFormat(" -%d %s in the way;", pz_pen, pz_detail);

                  if((ProtectedZonePrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v264 PROTECTED] %s | %.0f pts ahead of a %.0f pt target",
                                 pz_detail, pz_gap, pz_tp);
               }
            }
         }
      }

      // V262: which end of the candle came first? A bar with wicks on both sides says price visited
      // two extremes and not in what order - and the order is most of the meaning. Down first then
      // up means the lows were swept and the selling is already spent; up first then down is the
      // opposite. From OHLC alone these are identical, and the close position hints badly: a bar
      // that swept its lows, rallied, and faded slightly at the end closes mid-range and looks
      // balanced when it was nothing of the kind. The sequence is recoverable from the timeframe
      // below, where the order is not in doubt.
      if(EnableWickOrder && entry_dir_i != 0)
      {
         double wo_conv = 0.0;
         string wo_detail = "";
         int    wo_dir = WickOrderBias(wo_conv, wo_detail);

         if(wo_dir != 0 && wo_conv >= WickOrderMinConviction)
         {
            int wo_adj = (int)MathRound(wo_conv * (double)WickOrderScore);
            wo_adj = MathMax(1, wo_adj);

            if(wo_dir == entry_dir_i)
            {
               G_SCORE_BONUS += wo_adj;
               G_CANDLE_BONUS += wo_adj;
               detail += StringFormat(" +%d %s;", wo_adj, wo_detail);
            }
            else
            {
               G_SCORE_PENALTY += wo_adj;
               G_PENALTY_TREND_AGAINST += wo_adj;
               G_CANDLE_PENALTY += wo_adj;
               detail += StringFormat(" -%d against the order: %s;", wo_adj, wo_detail);
            }

            if((WickOrderPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v262 ORDER] %s | implied dir=%d | entry dir=%d",
                           wo_detail, wo_dir, entry_dir_i);
         }
      }

      // V260: how did price get here? CandleLocationWeight asks where a wick landed and
      // CandleRelevance asks how close a level is - both are questions about position, which is half
      // of context. The other half is arrival. A rejection at support after a fast one-way drop is
      // exhaustion testing the level, and those hold. The same candle after forty minutes of
      // grinding into it is absorption wearing the level down, and those break. Every candle reading
      // here treats them identically because none looks at the bars before the one it is reading.
      if(EnableArrivalRead && entry_dir_i != 0)
      {
         int    ar_dir = 0;
         string ar_detail = "";
         double ar_q = ArrivalQuality(ar_dir, ar_detail);

         if(ar_dir != 0)
         {
            // Only meaningful near a level - in open space how price arrived says nothing about
            // what happens next, because there is nothing there for it to happen at.
            double ar_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ar_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double ar_mid = (ar_bid > 0.0 && ar_ask > 0.0) ? (ar_bid + ar_ask) / 2.0 : ar_bid;

            if(ar_mid > 0.0 && _Point > 0.0)
            {
               // The level price arrived AT - ahead of the direction it was travelling.
               double ar_level = (ar_dir > 0) ? ZoneMapNearestResistance(ar_mid)
                                              : ZoneMapNearestSupport(ar_mid);

               if(ar_level > 0.0)
               {
                  double ar_gap = MathAbs(ar_level - ar_mid) / _Point;
                  double ar_reach = ScaleAdjustedPoints(MathMax(1, ArrivalLevelReach));

                  if(ar_gap <= ar_reach)
                  {
                     double ar_strength = ZoneMapStrengthByTouches(ar_level);

                     if(ar_strength >= ArrivalMinLevelStrength)
                     {
                        // A trade AGAINST the arrival direction is fading the approach - betting
                        // the level holds. Fast arrivals support that bet; grinds argue against it.
                        bool fading = (entry_dir_i == -ar_dir);

                        int ar_adj = 0;
                        if(fading)
                        {
                           // Fast in, exhausted, level likely holds - good. Slow grind, level being
                           // worn down - bad.
                           double lean = (ar_q * 2.0) - 1.0;      // -1 grind, +1 fast
                           ar_adj = (int)MathRound(lean * (double)ArrivalScore);
                        }
                        else
                        {
                           // Trading WITH the approach - continuing through the level. The grind
                           // case favours that, the exhaustion case argues against it.
                           double lean = 1.0 - (ar_q * 2.0);
                           ar_adj = (int)MathRound(lean * (double)ArrivalScore);
                        }

                        if(ar_adj > 0)
                        {
                           G_SCORE_BONUS += ar_adj;
                           G_CANDLE_BONUS += ar_adj;
                           detail += StringFormat(" +%d %s;", ar_adj, ar_detail);
                        }
                        else if(ar_adj < 0)
                        {
                           G_SCORE_PENALTY += -ar_adj;
                           G_PENALTY_QUALITY += -ar_adj;
                           G_CANDLE_PENALTY += -ar_adj;
                           detail += StringFormat(" -%d %s;", -ar_adj, ar_detail);
                        }

                        if(ar_adj != 0 && (ArrivalPrintOnUse && VerboseLogs))
                           PrintFormat("[SIRUS v260 ARRIVAL] %s | level %.2f | %s | adj=%d",
                                       ar_detail, ar_level,
                                       (fading ? "fading the approach" : "continuing through"),
                                       ar_adj);
                     }
                  }
               }
            }
         }
      }

      // V258: are the candle sizes going somewhere? CandleSequenceRead compares the newest bar to the
      // average of five and calls it expanding or contracting - a snapshot. That cannot separate one
      // small candle after four large ones, which is a pause, from four candles each smaller than
      // the last, which is a move running out of people willing to pay. Both read as "contracting"
      // to a comparison against a mean, because a mean does not know what order things arrived in.
      if(EnableCandleProgression && entry_dir_i != 0)
      {
         int    cp_prog = CSEQ_NONE;
         int    cp_lean = 0;
         string cp_detail = "";
         double cp_conv = CandleProgression(cp_prog, cp_lean, cp_detail);

         if(cp_conv >= CandleProgressionMinConviction && cp_prog != CSEQ_NONE && cp_lean != 0)
         {
            int cp_adj = (int)MathRound(cp_conv * (double)CandleProgressionScore);
            cp_adj = MathMax(1, cp_adj);

            if(cp_prog == CSEQ_FADING)
            {
               // The bodies are shrinking in the direction they point. Whoever was driving it is
               // running out - which is bad for joining and good for fading.
               if(cp_lean == entry_dir_i)
               {
                  G_SCORE_PENALTY += cp_adj;
                  G_PENALTY_IMPULSE += cp_adj;
                  G_CANDLE_PENALTY += cp_adj;
                  detail += StringFormat(" -%d joining a move that is fading: %s;", cp_adj, cp_detail);
               }
               else
               {
                  G_SCORE_BONUS += cp_adj;
                  G_CANDLE_BONUS += cp_adj;
                  detail += StringFormat(" +%d fading side is running out: %s;", cp_adj, cp_detail);
               }
            }
            else
            {
               // Building. Pressure is accumulating in the direction the bodies point.
               if(cp_lean == entry_dir_i)
               {
                  G_SCORE_BONUS += cp_adj;
                  G_CANDLE_BONUS += cp_adj;
                  detail += StringFormat(" +%d %s;", cp_adj, cp_detail);
               }
               else
               {
                  G_SCORE_PENALTY += cp_adj;
                  G_PENALTY_TREND_AGAINST += cp_adj;
                  G_CANDLE_PENALTY += cp_adj;
                  detail += StringFormat(" -%d against %s;", cp_adj, cp_detail);
               }
            }

            if((CandleProgressionPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v258 PROGRESSION] %s | lean=%d | entry dir=%d",
                           cp_detail, cp_lean, entry_dir_i);
         }
      }

      // V257: did a recent wick go and fetch something? Authorship already reads wicks and asks
      // which side of the bar got rejected, measured against its own body. This asks where the wick
      // ENDED - a tip landing on a prior high has collected the stops sitting above it, which is the
      // only reason price goes there and does not stay. The same 60% wick means nothing in open
      // space and a great deal on last week's low.
      if(EnableLiquidityWick && entry_dir_i != 0)
      {
         int    lw_dir = 0;
         double lw_level = 0.0;
         string lw_detail = "";
         double lw_conv = LiquidityWickSweep(lw_dir, lw_level, lw_detail);

         if(lw_conv >= LiquidityWickMinConviction && lw_dir != 0)
         {
            // Highs taken points down, lows taken points up - the liquidity that would have fuelled
            // the other direction has already been spent.
            int implied = -lw_dir;

            int lw_adj = (int)MathRound(lw_conv * (double)LiquidityWickScore);
            lw_adj = MathMax(1, lw_adj);

            if(implied == entry_dir_i)
            {
               G_SCORE_BONUS += lw_adj;
               G_CANDLE_BONUS += lw_adj;
               detail += StringFormat(" +%d %s;", lw_adj, lw_detail);
            }
            else
            {
               G_SCORE_PENALTY += lw_adj;
               G_PENALTY_TREND_AGAINST += lw_adj;
               G_CANDLE_PENALTY += lw_adj;
               detail += StringFormat(" -%d entering toward liquidity already taken: %s;",
                                      lw_adj, lw_detail);
            }

            if((LiquidityWickPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v257 LIQUIDITY] %s | implied dir=%d | entry dir=%d",
                           lw_detail, implied, entry_dir_i);
         }
      }

      // V253: did a candle recently take out both sides? A bar with long wicks above and below a
      // small body reads to the EA as a doji - indecision, no information. That is wrong in the most
      // expensive way: price went up far enough to clear the shorts, came back down far enough to
      // clear the longs, and closed where it started. Nobody is undecided. Both sides are out, and
      // whoever did the clearing has the market to themselves.
      if(EnableManipulationRead && entry_dir_i != 0)
      {
         int    mp_dir = 0;
         string mp_detail = "";
         double mp_conv = RecentManipulation(mp_dir, mp_detail);

         if(mp_conv >= ManipulationMinConviction)
         {
            if(mp_dir == 0)
            {
               // Both sides cleared and the close gave nothing away. The sweep is real; the
               // direction is not settled, and entering before it is entering blind.
               int mp_pen = (int)MathRound(mp_conv * (double)ManipulationUnclearPenalty);
               mp_pen = MathMax(1, mp_pen);
               G_SCORE_PENALTY += mp_pen;
               G_PENALTY_CONDITIONS += mp_pen;
               G_CANDLE_PENALTY += mp_pen;
               detail += StringFormat(" -%d %s, direction not settled;", mp_pen, mp_detail);
            }
            else if(mp_dir == entry_dir_i)
            {
               int mp_bonus = (int)MathRound(mp_conv * (double)ManipulationScore);
               mp_bonus = MathMax(1, mp_bonus);
               G_SCORE_BONUS += mp_bonus;
               G_CANDLE_BONUS += mp_bonus;
               detail += StringFormat(" +%d entering after %s;", mp_bonus, mp_detail);
            }
            else
            {
               // Against the side the sweep favoured. The liquidity that would have carried this
               // direction was taken during the sweep itself.
               int mp_pen = (int)MathRound(mp_conv * (double)ManipulationScore);
               mp_pen = MathMax(1, mp_pen);
               G_SCORE_PENALTY += mp_pen;
               G_PENALTY_TREND_AGAINST += mp_pen;
               G_CANDLE_PENALTY += mp_pen;
               detail += StringFormat(" -%d against the sweep: %s;", mp_pen, mp_detail);
            }

            if((ManipulationPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v253 SWEEP BAR] %s | likely dir=%d | entry dir=%d",
                           mp_detail, mp_dir, entry_dir_i);
         }
      }

      // V252: is there a level in front of this trade that does not come from the swing cache? A
      // support at 4305-4315 held on the 2nd and 3rd of September; on the 11th price came back to it
      // and the EA did not see it - nine days is a long time in a cache, and hundreds of newer
      // swings had pushed it out.
      //
      // Round numbers, the monthly range and the weekly open do not need remembering. They are
      // prices rather than history, and they matter precisely when the cache is least useful: after
      // a large move into territory with no recent swings in it at all.
      if(EnableGlobalLevels && entry_dir_i != 0)
      {
         double gl_level = 0.0;
         string gl_detail = "";
         double gl_str = GlobalLevelAhead(entry_dir_i, gl_level, gl_detail);

         if(gl_str >= GlobalLevelMinStrength && gl_level > 0.0)
         {
            // A global level ahead is a wall the trade has to get through before its target - the
            // same objection as any other level, from a source the cache cannot lose.
            double gl_gap = MathAbs(gl_level - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
            double gl_tp = BaseBasketTPPoints();

            if(gl_tp > 0.0 && gl_gap < gl_tp)
            {
               double short_by = 1.0 - (gl_gap / gl_tp);
               int gl_pen = (int)MathRound(short_by * gl_str * (double)GlobalLevelPenalty);
               gl_pen = MathMax(1, gl_pen);
               G_SCORE_PENALTY += gl_pen;
               G_PENALTY_QUALITY += gl_pen;
               detail += StringFormat(" -%d %s, short of the %.0f pt target;",
                                      gl_pen, gl_detail, gl_tp);

               if((GlobalLevelPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v252 GLOBAL] %s | dir=%d", gl_detail, entry_dir_i);
            }
         }
      }

      // V250: is the bigger picture pointing the other way? Three live buys made the same mistake -
      // 4670.41, 4672.48, 4670.48 - each time a double top had formed above, price had broken down
      // through it, and then come back to the neckline. The EA saw a support and bought it.
      //
      // A support inside a completed bearish reversal is not a support. It is the neckline of the
      // pattern that just broke, and price returning to it is the retest before the next leg down.
      //
      // This adds weight rather than vetoing. A local setup inside a hostile larger context can
      // still be right - it just has to be much better than the same setup with the bigger picture
      // behind it.
      if(EnableReversalContext && entry_dir_i != 0)
      {
         double rv_sev = 0.0;
         string rv_detail = "";
         if(IsNecklineRetest(entry_dir_i, rv_sev, rv_detail) && rv_sev >= ReversalMinSeverity)
         {
            int rv_pen = (int)MathRound(rv_sev * (double)ReversalContextPenalty);
            rv_pen = MathMax(1, rv_pen);
            G_SCORE_PENALTY += rv_pen;
            G_PENALTY_TREND_AGAINST += rv_pen;
            G_STRUCT_PENALTY += rv_pen;
            detail += StringFormat(" -%d %s;", rv_pen, rv_detail);

            if((ReversalContextPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v250 CONTEXT] %s | dir=%d", rv_detail, entry_dir_i);
         }
      }

      // V238: is this entry going INTO a band that has been rejecting price? The counter-zone check
      // measures distance to the nearest level, which is the right question when price is outside a
      // band and the wrong one when it is between the edges - the nearest edge is then a dollar
      // away and the check reads plenty of room. That is how a buy went in at 4435, in the middle
      // of a shelf that had capped price on four separate days.
      if(EnableBandEntryGuard && entry_dir_i != 0)
      {
         double bg_lo = 0.0, bg_hi = 0.0;
         string bg_detail = "";
         double bg_sev = InsideRejectingBand(entry_dir_i, bg_lo, bg_hi, bg_detail);

         if(bg_sev >= BandGuardMinSeverity)
         {
            int bg_pen = (int)MathRound(bg_sev * (double)BandGuardPenalty);
            bg_pen = MathMax(1, bg_pen);
            G_SCORE_PENALTY += bg_pen;
            G_PENALTY_QUALITY += bg_pen;
            detail += StringFormat(" -%d %s;", bg_pen, bg_detail);

            if((BandGuardPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v238 BAND] %s | dir=%d", bg_detail, entry_dir_i);
         }
      }

      // V238: has a sweep already happened and turned the structure? Price took out 4325, failed to
      // continue, recovered to a higher high at 4358, and never went back. Liquidity taken,
      // structure turned, level holding - three reasons to buy, and the EA sold into it. The sweep
      // DETECTORS exist; what was missing is the reading that the sweep is finished and its
      // consequence is now in force.
      if(EnableSweepReversal && entry_dir_i != 0)
      {
         double sr_strength = 0.0;
         string sr_detail = "";
         int    sr_dir = SweepReversalDir(sr_strength, sr_detail);

         if(sr_dir != 0 && sr_strength >= SweepReversalMinStrength)
         {
            int sr_adj = (int)MathRound(sr_strength * (double)SweepReversalScore);
            sr_adj = MathMax(1, sr_adj);

            if(sr_dir == entry_dir_i)
            {
               G_SCORE_BONUS += sr_adj;
               detail += StringFormat(" +%d %s;", sr_adj, sr_detail);
            }
            else
            {
               // Trading against a completed sweep reversal. The liquidity that would have carried
               // this direction has already been taken, which is what makes it the wrong side.
               G_SCORE_PENALTY += sr_adj;
               G_PENALTY_TREND_AGAINST += sr_adj;
               G_STRUCT_PENALTY += sr_adj;
               detail += StringFormat(" -%d against: %s;", sr_adj, sr_detail);

               if((SweepReversalPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v238 SWEEP] %s | entry dir=%d", sr_detail, entry_dir_i);
            }
         }
      }

      // V229: one bar. Every other impulse check needs a sequence - three candles, three dollars,
      // eight dollars, a stretched ATR reading - and the case that keeps costing money is a single
      // strong close followed immediately by a counter-setup. A bar three times the size of its
      // neighbours with a decisive body is not a trend by any of those measures, and does not need
      // to be: whoever produced it is still in the market for the next bar or two.
      if(EnableSingleCandleGuard && entry_dir_i != 0)
      {
         int    sc_dir = 0;
         string sc_detail = "";
         double sc_strength = SingleCandleDominance(sc_dir, sc_detail);

         if(sc_dir != 0 && sc_strength >= SingleCandleMinStrength && sc_dir == -entry_dir_i)
         {
            // Timing, not direction. The objection ends when the next bar fails to continue -
            // a specific, observable event rather than a fixed delay.
            if(EnableSetupArming && SingleCandleArms && !SingleCandleFaded(sc_dir))
            {
               double sc_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(sc_px > 0.0 &&
                  SetupArm(entry_dir_i, ARM_REASON_EXTENDED, sc_px,
                           StringFormat("%s - waiting for it to stop", sc_detail), false))
               {
                  G_SCORE_DECISION = SCORE_DECISION_WAIT;
                  detail += StringFormat(" [armed: %s];", sc_detail);
                  return;
               }
            }

            int sc_pen = (int)MathRound(sc_strength * (double)SingleCandlePenalty);
            sc_pen = MathMax(1, sc_pen);
            G_SCORE_PENALTY += sc_pen;
            G_PENALTY_IMPULSE += sc_pen;
            G_CANDLE_PENALTY += sc_pen;
            detail += StringFormat(" -%d entering against a %s;", sc_pen, sc_detail);

            if((SingleCandlePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v229 SINGLE CANDLE] %s | entry dir=%d | strength %.2f",
                           sc_detail, entry_dir_i, sc_strength);
         }
         else if(sc_dir != 0 && sc_strength >= SingleCandleMinStrength && sc_dir == entry_dir_i)
         {
            // V230: a dominant bar in OUR direction is not straightforwardly good. The bar has
            // already travelled - entering now means entering a dollar worse than whoever produced
            // it, at the point where the move is most likely to pause. Whether that is participation
            // or chasing depends on where in the bar the entry lands.
            double sc_h = CandleHigh(SingleCandleTF, 1);
            double sc_l = CandleLow(SingleCandleTF, 1);
            double sc_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sc_rng = sc_h - sc_l;

            bool chasing = false;
            if(sc_rng > 0.0 && sc_px > 0.0)
            {
               // How far up the bar's own range is this fill? Near the extreme it produced, the
               // entry is buying the end of the move rather than joining it.
               double pos = (entry_dir_i > 0) ? (sc_px - sc_l) / sc_rng : (sc_h - sc_px) / sc_rng;
               chasing = (pos >= SingleCandleChaseFrom);
            }

            if(chasing)
            {
               int sc_chase = (int)MathRound(sc_strength * (double)SingleCandleChasePenalty);
               sc_chase = MathMax(1, sc_chase);
               G_SCORE_PENALTY += sc_chase;
               G_PENALTY_QUALITY += sc_chase;
               G_CANDLE_PENALTY += sc_chase;
               detail += StringFormat(" -%d chasing a %s;", sc_chase, sc_detail);

               if((SingleCandlePrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v230 CHASE] entry at the far end of %s", sc_detail);
            }
            else
            {
               int sc_bonus = (int)MathRound(sc_strength * (double)SingleCandleBonus);
               if(sc_bonus > 0)
               {
                  G_SCORE_BONUS += sc_bonus;
                  G_CANDLE_BONUS += sc_bonus;
                  detail += StringFormat(" +%d %s with us;", sc_bonus, sc_detail);
               }
            }
         }
      }

      // V204: is a run of candles pushing against this entry right now? Distance-based impulse
      // checks miss this - three or four strong closes covering a dollar is not a "thrust" by any
      // points threshold, but it is very clearly a market being pushed, and taking the other side
      // of it mid-push is the pattern that has been producing quick losses.
      //
      // Treated as timing, not direction: the entry is held until the run stops, which is a bar
      // closing against it or a doji. That is a specific, observable end - not an arbitrary wait.
      if(EnableConsecutivePressure && entry_dir_i != 0)
      {
         int    cp_run = 0;
         double cp_body = 0.0;
         string cp_detail = "";
         int    cp_dir = ConsecutivePressureDir(cp_run, cp_body, cp_detail);

         if(cp_dir != 0 && cp_dir == -entry_dir_i)
         {
            if(EnableSetupArming && ConsecutivePressureArms)
            {
               double cp_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(cp_px > 0.0 &&
                  SetupArm(entry_dir_i, ARM_REASON_EXTENDED, cp_px,
                           StringFormat("%s - waiting for the run to break", cp_detail), false))
               {
                  G_SCORE_DECISION = SCORE_DECISION_WAIT;
                  detail += StringFormat(" [armed: %s];", cp_detail);
                  return;
               }
            }

            int cp_pen = MathMin(ConsecutivePressureMaxPenalty,
                                 ConsecutivePressurePenalty * MathMax(1, cp_run - ConsecutivePressureMinRun + 1));
            G_SCORE_PENALTY += cp_pen;
            G_PENALTY_IMPULSE += cp_pen;
            detail += StringFormat(" -%d %s;", cp_pen, cp_detail);
            if((ConsecutivePressurePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v204 PRESSURE] entry against %s", cp_detail);
         }
      }

      // V166: what has already happened. A run of losses says conditions changed; losing repeatedly
      // at one price says the EA keeps making the same mistake there.
      if(EnableStreakAwareness)
      {
         int st_pen = StreakPenalty();
         if(st_pen > 0)
         {
            G_SCORE_PENALTY += st_pen;
            v31_brain_penalty += st_pen;
            detail += StringFormat(" -%d %d losses in a row;", st_pen, G_LOSS_STREAK);
         }
      }

      if(EnableRepeatMistakeGuard)
      {
         double rm_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double rm_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double rm_mid = (rm_bid > 0.0 && rm_ask > 0.0) ? (rm_bid + rm_ask) / 2.0 : rm_bid;
         string rm_detail = "";
         if(rm_mid > 0.0 && RepeatedLossesNear(rm_mid, rm_detail) >= RepeatMistakeMinHits)
         {
            G_SCORE_PENALTY += RepeatMistakePenalty;
            G_PENALTY_QUALITY += RepeatMistakePenalty;
            v31_brain_penalty += RepeatMistakePenalty;
            detail += StringFormat(" -%d %s;", RepeatMistakePenalty, rm_detail);
         }
      }

      // V165: can this trade pay for itself? Every other check here weighs whether the setup is
      // good; this one weighs whether it is worth taking at the current cost - and a scalp whose
      // spread eats a third of its target is not, regardless of how good the setup is.
      if(EnableSpreadEconomics)
      {
         string sp_detail = "";
         double sp_ratio = SpreadCostRatio(sp_detail);

         if(sp_ratio > 0.0)
         {
            if(SpreadCostHardBlock && sp_ratio >= SpreadCostRefuse)
            {
               G_SCORE_DECISION = SCORE_DECISION_HARD_BLOCK;
               G_BLOCK_REASON = StringFormat("spread makes this trade unprofitable - %s", sp_detail);
               // V170c: set the same status fields the older hard blocks set. Without these the
               // dashboard keeps showing the previous decision and the signature is not refreshed,
               // so a blocked bar looks identical to one that was never evaluated.
               G_SCORE_HARD_BLOCK = G_BLOCK_REASON;
               G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + G_SCORE_HARD_BLOCK;
               G_SCORE_LAST_SIGNATURE = G_SCORE_STATUS + "|" + IntegerToString(G_BARS_SEEN);
               detail += StringFormat(" [BLOCKED: %s];", sp_detail);
               if((SpreadPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v165 SPREAD] BLOCKED - %s", sp_detail);
               {
                  double sp_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double sp_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double sp_mid = (sp_bid > 0.0 && sp_ask > 0.0) ? (sp_bid + sp_ask) / 2.0 : sp_bid;
                  if(sp_mid > 0.0)
                     BlockAuditRecord(entry_dir_i, sp_mid);
               }
               return;
            }
            // V196: a wide spread is the one objection with a guaranteed resolution - spreads
            // narrow. Paying a penalty for it means taking the trade at the worst cost of the hour
            // when a few bars of patience gets the same setup at the normal one.
            else if(sp_ratio >= SpreadCostCaution && EnableSpreadArming && EnableSetupArming)
            {
               double sp_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(sp_px > 0.0 &&
                  SetupArm(entry_dir_i, ARM_REASON_STRUCTURE, sp_px,
                           StringFormat("spread costs %.0f%% of target - waiting for it to narrow",
                                        sp_ratio * 100.0), false))
               {
                  G_SCORE_DECISION = SCORE_DECISION_WAIT;
                  detail += " [armed: waiting for spread to narrow];";
                  return;
               }
            }
            else if(sp_ratio >= SpreadCostCaution)
            {
               G_SCORE_PENALTY += SpreadCostPenalty;
               G_PENALTY_CONDITIONS += SpreadCostPenalty;
               v31_brain_penalty += SpreadCostPenalty;
               detail += StringFormat(" -%d %s;", SpreadCostPenalty, sp_detail);
            }
         }

         // And whether the exit will be priced under worse conditions than the entry.
         string sp_why = "";
         if(SpreadWideningExpected(sp_why))
         {
            G_SCORE_PENALTY += SpreadForecastPenalty;
            G_PENALTY_CONDITIONS += SpreadForecastPenalty;
            v31_brain_penalty += SpreadForecastPenalty;
            detail += StringFormat(" -%d %s;", SpreadForecastPenalty, sp_why);
            if((SpreadPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v165 SPREAD] widening expected: %s", sp_why);
         }
      }

      // V164: what is the market about to do that has nothing to do with this setup? Minutes before
      // a session change, the participants who will decide the next move are not in the market yet -
      // any reading taken now describes a market that is about to be replaced.
      if(EnableSessionContext)
      {
         int    sc_mins = 999;
         string sc_detail = "";
         int    sc_sess = SessionContext(sc_mins, sc_detail);

         if(sc_sess == SESSION_DEAD)
         {
            G_SCORE_PENALTY += SessionDeadPenalty;
            G_PENALTY_CONDITIONS += SessionDeadPenalty;
            v31_brain_penalty += SessionDeadPenalty;
            detail += StringFormat(" -%d rollover;", SessionDeadPenalty);
         }
         else if(sc_mins <= SessionChangeWarnMinutes)
         {
            G_SCORE_PENALTY += SessionChangePenalty;
            G_PENALTY_CONDITIONS += SessionChangePenalty;
            v31_brain_penalty += SessionChangePenalty;
            detail += StringFormat(" -%d %s;", SessionChangePenalty, sc_detail);
         }

         if((SessionPrintOnUse && VerboseLogs) && (sc_sess == SESSION_DEAD || sc_mins <= SessionChangeWarnMinutes))
            PrintFormat("[SIRUS v164 SESSION] %s", sc_detail);
      }

      // V163: who actually holds control right now - and does that agree with where price has been
      // going? When it does not, control is the earlier reading of the two.
      if(EnablePressureReading)
      {
         double pr_trend = 0.0;
         bool   pr_div = false;
         string pr_detail = "";
         double pr = DominantSidePressure(pr_trend, pr_div, pr_detail);

         if(MathAbs(pr) >= PressureMinToAct)
         {
            int pr_dir = (pr > 0.0) ? 1 : -1;

            if(entry_dir_i == pr_dir)
            {
               // Entering with control while price still disagrees is the most valuable version
               // of this: the setup is early rather than late.
               int bonus = pr_div ? PressureDivergenceBonus : PressureWithBonus;
               G_SCORE_BONUS += bonus;
               detail += StringFormat(" +%d %s;", bonus, pr_detail);
            }
            else
            {
               G_SCORE_PENALTY += PressureAgainstPenalty;
               G_PENALTY_CONDITIONS += PressureAgainstPenalty;
               v31_brain_penalty += PressureAgainstPenalty;
               detail += StringFormat(" -%d against %s;", PressureAgainstPenalty, pr_detail);
            }

            if((PressurePrintOnUse && VerboseLogs) && pr_div)
               PrintFormat("[SIRUS v163 PRESSURE] %s | entry dir=%d", pr_detail, entry_dir_i);
         }
      }

      // V162: is the market actually going anywhere? In churn every signal is describing noise, and
      // no score is meaningful - the target cannot be reached regardless of how good the setup looks.
      if(EnableNoiseFilter)
      {
         double nz_reach = 1.0;
         string nz_detail = "";
         double nz = MarketNoiseLevel(nz_reach, nz_detail);

         bool nz_unreachable = (nz_reach < NoiseMinReachability);

         // V162b: refusing to trade is the wrong answer here. The problem is not that the setup is
         // bad - it is that the TARGET is wrong for these conditions. A market covering 40% of the
         // usual ground has not stopped being tradeable; it has stopped supporting a $2.50 target.
         // Shrinking the target to what the market can actually deliver keeps the EA working
         // instead of standing aside, and a smaller target in churn is exactly what a scalper
         // should be taking anyway.
         if(nz_unreachable)
         {
            G_NOISE_TP_FACTOR = MathMax(NoiseMinTPFactor, MathMin(1.0, nz_reach / MathMax(0.01, NoiseMinReachability)));
            detail += StringFormat(" [target scaled to %.0f%% - %s];", G_NOISE_TP_FACTOR * 100.0, nz_detail);
            if((NoisePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v162b NOISE] target scaled to %.0f%% - %s",
                           G_NOISE_TP_FACTOR * 100.0, nz_detail);
         }
         else
            G_NOISE_TP_FACTOR = 1.0;

         // Only extreme churn still carries a penalty, and even then it is a penalty rather than a
         // refusal - the score engine can still decide the setup is worth it.
         if(nz >= NoiseCautionLevel)
         {
            G_SCORE_PENALTY += NoiseCautionPenalty;
            G_PENALTY_CONDITIONS += NoiseCautionPenalty;
            v31_brain_penalty += NoiseCautionPenalty;
            detail += StringFormat(" -%d churning;", NoiseCautionPenalty);
         }
      }

      // V159: before anything about direction - can this entry's ladder actually survive being
      // completed? Every other check here is a judgement call; this one is arithmetic.
      if(EnableBasketProjection && G_BASKET_ORDERS <= 0)
      {
         double pj_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pj_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double pj_entry = (entry_dir_i > 0) ? pj_ask : pj_bid;

         if(pj_entry > 0.0)
         {
            int    pj_orders = 0;
            double pj_lots = 0.0, pj_dd = 0.0, pj_margin = 0.0;
            string pj_detail = "";
            double pj_sev = ProjectBasketRisk(entry_dir_i, pj_entry, pj_orders, pj_lots,
                                              pj_dd, pj_margin, pj_detail);

            // V159b: refusing the trade is the crudest possible response to this. The ladder is too
            // big for the account - so make the ladder smaller. Scaling the entry lot scales every
            // rung below it, which brings the projected drawdown and margin back inside the limits
            // while still taking the setup. A trade at 60% size is a trade; a refused trade is not.
            if(pj_sev >= ProjectionCautionSeverity)
            {
               double needed = ProjectionCautionSeverity / MathMax(0.01, pj_sev);
               G_PROJECTION_LOT_FACTOR = MathMax(ProjectionMinLotFactor, MathMin(1.0, needed));

               detail += StringFormat(" [size scaled to %.0f%% - %s];",
                                      G_PROJECTION_LOT_FACTOR * 100.0, pj_detail);
               if((ProjectionPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v159b PROJECTION] size scaled to %.0f%% - %s",
                              G_PROJECTION_LOT_FACTOR * 100.0, pj_detail);

               // Only when even the smallest permitted size cannot survive is the trade genuinely
               // impossible rather than merely oversized.
               if(ProjectionHardBlock && (pj_sev * G_PROJECTION_LOT_FACTOR) >= ProjectionBlockSeverity)
               {
                  G_SCORE_DECISION = SCORE_DECISION_HARD_BLOCK;
                  G_BLOCK_REASON = StringFormat("ladder cannot survive even at minimum size - %s", pj_detail);
               // V170c: set the same status fields the older hard blocks set. Without these the
               // dashboard keeps showing the previous decision and the signature is not refreshed,
               // so a blocked bar looks identical to one that was never evaluated.
               G_SCORE_HARD_BLOCK = G_BLOCK_REASON;
               G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + G_SCORE_HARD_BLOCK;
               G_SCORE_LAST_SIGNATURE = G_SCORE_STATUS + "|" + IntegerToString(G_BARS_SEEN);
                  detail += " [BLOCKED: unsurvivable at any size];";
                  if((ProjectionPrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v159b PROJECTION] BLOCKED - unsurvivable even at %.0f%% size",
                                 ProjectionMinLotFactor * 100.0);
                  BlockAuditRecord(entry_dir_i, pj_entry);
                  return;
               }
            }
            else
               G_PROJECTION_LOT_FACTOR = 1.0;
         }
      }

      // V154: what has this market done the last times it looked like this? No theory involved -
      // just the record. It is worth weighing precisely because it can disagree with every
      // theory-based module at once, and sometimes the record is right and the theory is not.
      if(EnablePatternMemory)
      {
         int    pm_samples = 0;
         double pm_fit = 0.0;
         string pm_detail = "";
         double pm_bias = PatternMemoryBias(pm_samples, pm_fit, pm_detail);

         if(MathAbs(pm_bias) >= PatternMemoryMinBias && pm_fit >= PatternMemoryMinFit)
         {
            int pm_dir = (pm_bias > 0) ? 1 : -1;
            if(entry_dir_i == pm_dir)
            {
               G_SCORE_BONUS += PatternMemoryWithBonus;
               detail += StringFormat(" +%d %s;", PatternMemoryWithBonus, pm_detail);
            }
            else
            {
               G_SCORE_PENALTY += WeightedPenalty(WARN_HISTORY, PatternMemoryAgainstPenalty);
               G_PENALTY_CONDITIONS += PatternMemoryAgainstPenalty;
               v31_brain_penalty += PatternMemoryAgainstPenalty;
               detail += StringFormat(" -%d against %s;", PatternMemoryAgainstPenalty, pm_detail);
            }
            if((PatternMemoryPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v154 PATTERN MEMORY] %s | entry dir=%d", pm_detail, entry_dir_i);
         }
      }

      // V151: is this a decision or a liquidation? Entering into live forced flow means standing in
      // front of orders that must be filled at any price. But once that flow stalls, fading it is
      // unusually clean - the forced seller is gone and there is no willing seller behind them.
      if(EnableForcedFlow)
      {
         double ff_intensity = 0.0;
         string ff_detail = "";
         int ff_dir = ForcedFlowDirection(ff_intensity, ff_detail);

         if(ff_dir != 0 && ff_intensity >= ForcedFlowMinIntensity)
         {
            // Has the forced flow stalled? Reuse the sustained-exhaustion read: a rejection
            // against the flow means the forced supply has been exhausted.
            int ff_exh = SustainedImpulseExhaustedDir();
            bool ff_spent = (ff_exh == ff_dir);

            if(entry_dir_i == ff_dir && !ff_spent)
            {
               // Joining a liquidation late - the snap-back lands on us.
               G_SCORE_PENALTY += WeightedPenalty(WARN_FORCED_FLOW, ForcedFlowAgainstPenalty);
               G_PENALTY_IMPULSE += ForcedFlowAgainstPenalty;
               v31_brain_penalty += ForcedFlowAgainstPenalty;
               detail += StringFormat(" -%d joining %s;", ForcedFlowAgainstPenalty, ff_detail);
            }
            else if(entry_dir_i == -ff_dir && ff_spent)
            {
               // Fading it after it is spent - the highest-quality version of this setup.
               G_SCORE_BONUS += ForcedFlowFadeBonus;
               detail += StringFormat(" +%d fading spent %s;", ForcedFlowFadeBonus, ff_detail);
            }
            else if(entry_dir_i == -ff_dir && !ff_spent)
            {
               // Fading it while it is still running - standing in front of forced orders.
               G_SCORE_PENALTY += WeightedPenalty(WARN_FORCED_FLOW, ForcedFlowAgainstPenalty);
               v31_brain_penalty += ForcedFlowAgainstPenalty;
               detail += StringFormat(" -%d fading live %s;", ForcedFlowAgainstPenalty, ff_detail);
            }

            if((ForcedFlowPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v151 FORCED FLOW] %s | spent=%s | entry dir=%d",
                           ff_detail, (ff_spent ? "yes" : "no"), entry_dir_i);
         }
      }

      // V149: what does the whole path ahead look like? A crowded path stalls a scalp repeatedly
      // even when the first wall is far enough away; an open stretch lets the same target run.
      if(EnablePathDensity)
      {
         double pd_gap = 0.0;
         int    pd_walls = 0;
         string pd_detail = "";
         double pd_density = PathDensityAhead(entry_dir_i, pd_gap, pd_walls, pd_detail);
         double pd_target = BaseBasketTPPoints();

         if(pd_density >= PathDensityCrowdedPerDollar)
         {
            G_SCORE_PENALTY += WeightedPenalty(WARN_PATH_CROWDED, PathDensityCrowdedPenalty);
            G_PENALTY_CONDITIONS += PathDensityCrowdedPenalty;
            v31_brain_penalty += PathDensityCrowdedPenalty;
            detail += StringFormat(" -%d crowded %s;", PathDensityCrowdedPenalty, pd_detail);
            if((PathDensityPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v149 PATH] crowded - %s", pd_detail);
         }
         else if(pd_gap >= pd_target * MathMax(1.0, PathDensityClearGapFactor))
         {
            G_SCORE_BONUS += PathDensityClearBonus;
            detail += StringFormat(" +%d open road (%s);", PathDensityClearBonus, pd_detail);
         }
      }

      // V148: the level this entry is leaning on - is it one that holds, or one that attracts?
      // Fading a retail level before its stops are taken means standing in front of the run that
      // takes them; leaning on an institutional level is what a bounce trade is supposed to be.
      if(EnableParticipantModel)
      {
         double pm_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pm_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double pm_mid = (pm_bid > 0.0 && pm_ask > 0.0) ? (pm_bid + pm_ask) / 2.0 : pm_bid;

         if(pm_mid > 0.0)
         {
            // The level this entry expects to bounce FROM: support under a buy, resistance above a sell.
            double pm_level = (entry_dir_i > 0) ? ZoneMapNearestSupport(pm_mid)
                                                : ZoneMapNearestResistance(pm_mid);
            if(pm_level > 0.0)
            {
               double pm_conf = 0.0;
               string pm_detail = "";
               int pm_profile = LevelParticipantProfile(pm_level, pm_conf, pm_detail);

               if(pm_profile != 0 && pm_conf >= ParticipantMinConfidence)
               {
                  if(pm_profile < 0)
                  {
                     G_SCORE_PENALTY += WeightedPenalty(WARN_RETAIL_LEVEL, ParticipantRetailFadePenalty);
                     G_PENALTY_CONDITIONS += ParticipantRetailFadePenalty;
                     v31_brain_penalty += ParticipantRetailFadePenalty;
                     detail += StringFormat(" -%d leaning on a %s;", ParticipantRetailFadePenalty, pm_detail);
                  }
                  else
                  {
                     G_SCORE_BONUS += ParticipantInstBonus;
                     detail += StringFormat(" +%d leaning on an %s;", ParticipantInstBonus, pm_detail);
                  }
                  if((ParticipantPrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS v148 PARTICIPANTS] %.2f is an %s", pm_level, pm_detail);
               }
            }
         }
      }

      // V140: is price likely to run to a stop pool BEFORE going our way? Buying into a shelf of
      // buy-stops above means paying for the run that fills them - the same entry is usually
      // available afterwards at a better price, from the far side of the sweep.
      if(EnableLiquidityMap)
      {
         int    lq_dir = 0;
         double lq_price = 0.0, lq_dist = 0.0;
         string lq_detail = "";
         double lq_weight = LiquidityPoolAhead(entry_dir_i, lq_dir, lq_price, lq_dist, lq_detail);

         if(lq_weight >= LiquidityMinWeight && lq_dist <= ScaleAdjustedPoints(LiquidityNearPoints))
         {
            // V195: a stop pool ahead is not a reason to trade smaller - it is a reason to let it be
            // taken first. Price runs to those stops, and the move that follows the sweep is
            // cleaner than the one that walks into it. Waiting turns the obstacle into the entry.
            if(EnableSetupArming && EnableLiquidityArming && lq_price > 0.0 &&
               SetupArm(entry_dir_i, ARM_REASON_ZONE, lq_price,
                        StringFormat("stop pool at %.2f - waiting for it to be taken", lq_price), false))
            {
               G_SCORE_DECISION = SCORE_DECISION_WAIT;
               detail += StringFormat(" [armed: waiting for the pool at %.2f];", lq_price);
               return;
            }
            G_SCORE_PENALTY += WeightedPenalty(WARN_LIQUIDITY, LiquidityAheadPenalty);
            G_PENALTY_QUALITY += LiquidityAheadPenalty;
            v31_brain_penalty += LiquidityAheadPenalty;
            detail += StringFormat(" -%d %s;", LiquidityAheadPenalty, lq_detail);
            if((LiquidityPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v140 LIQUIDITY] %s - entry into it penalised", lq_detail);
         }
      }

      // V118: is there space for this trade to work? Direction alone is not enough - a scalp target
      // opened into a wall closer than the target itself is structurally unlikely to finish, and the
      // usual outcome is a stall followed by a reversal into the basket.
      if(EnableRoomCheck)
      {
         string room_detail = "";
         double room_pts = RoomToTargetPoints(entry_dir_i, room_detail);
         double needed = BaseBasketTPPoints() * MathMax(0.1, RoomMinFactor);

         if(room_pts < needed)
         {
            G_SCORE_PENALTY += WeightedPenalty(WARN_NO_ROOM, RoomTooTightPenalty);
            G_PENALTY_QUALITY += RoomTooTightPenalty;
            v31_brain_penalty += RoomTooTightPenalty;
            detail += StringFormat(" -%d %s (target needs %.0f);", RoomTooTightPenalty, room_detail, needed);
            if((RoomPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v118 ROOM] tight: %s | target needs %.0f pts", room_detail, needed);
         }
      }

      // V117: consensus across the independent readings. This does not re-judge direction (the
      // modules above already did that); it prices AGREEMENT. Unanimity means the market has a clear
      // owner; a split means it does not, and entering a market that hasn't decided is how baskets
      // end up caught mid-turn.
      if(EnableMarketVerdict)
      {
         MarketVerdictRead();
         bool strong = (G_VERDICT_AGREE >= VerdictStrongAgreeCount);

         if(G_VERDICT_DIR != 0 && strong)
         {
            if(entry_dir_i == G_VERDICT_DIR)
            {
               G_SCORE_BONUS += VerdictStrongBonus;
         G_BONUS_TREND_ALIGN += VerdictStrongBonus;   // V134: same underlying fact as the other trend-agreement bonuses
               detail += StringFormat(" +%d %s;", VerdictStrongBonus, G_VERDICT_TXT);
            }
            else
            {
               G_SCORE_PENALTY += VerdictAgainstPenalty;
               G_PENALTY_TREND_AGAINST += VerdictAgainstPenalty;   // V136: same underlying fact as the other trend-conflict penalties
               v31_brain_penalty += VerdictAgainstPenalty;
               detail += StringFormat(" -%d against %s;", VerdictAgainstPenalty, G_VERDICT_TXT);
            }
         }
         else if(G_VERDICT_DIR == 0 && G_VERDICT_ACTIVE >= MathMax(2, VerdictMinActiveSources))
         {
            // Genuine split - the readings disagree with each other, not merely weakly.
            G_SCORE_PENALTY += VerdictSplitPenalty;
            G_PENALTY_TREND_AGAINST += VerdictSplitPenalty;
            v31_brain_penalty += VerdictSplitPenalty;
            detail += StringFormat(" -%d %s;", VerdictSplitPenalty, G_VERDICT_TXT);
         }
      }

      // V113: the break staircase. Independent of the swing chain but usually agreeing with it -
      // when both say the same thing the read is as strong as this EA can make it, and when the
      // entry fights a staircase it is fading a market that has been stepping through level after
      // level, which is the pattern behind the live losses.
      if(EnableBreakSequence)
      {
         BreakSequenceRead();
         if(G_BREAK_SEQ_DIR != 0)
         {
            if(entry_dir_i == G_BREAK_SEQ_DIR)
            {
               G_SCORE_BONUS += BreakSequenceWithBonus;
         G_BONUS_TREND_ALIGN += BreakSequenceWithBonus;   // V134: same underlying fact as the other trend-agreement bonuses
               detail += StringFormat(" +%d %s;", BreakSequenceWithBonus, G_BREAK_SEQ_TXT);
            }
            else
            {
               G_SCORE_PENALTY += BreakSequenceAgainstPenalty;
               G_PENALTY_TREND_AGAINST += BreakSequenceAgainstPenalty;   // V136: same underlying fact as the other trend-conflict penalties
               v31_brain_penalty += BreakSequenceAgainstPenalty;
               detail += StringFormat(" -%d against %s;", BreakSequenceAgainstPenalty, G_BREAK_SEQ_TXT);
            }
         }
      }

      // V31.6z10 NEW: Recent Zone Break ("premium" weight) - a fresh, confirmed break of a
      // strong zone deserves its own prominent bonus/penalty, not just a quiet nudge buried
      // inside ZoneMapStrength. Applies universally.
      if(EnableRecentZoneBreak)
      {
         string zb_detail_e = "";
         int zb_dir_e = RecentZoneBreakDirection(zb_detail_e);
         if(zb_dir_e != 0)
         {
            if(zb_dir_e == entry_dir_i)
            {
               cat_zonebreak = true;
               G_SCORE_BONUS += ZoneBreakScoreBonus;
               detail += StringFormat(" +%d %s;", ZoneBreakScoreBonus, zb_detail_e);
            }
            else
            {
               cat_zonebreak_against = true;
               G_SCORE_PENALTY += ZoneBreakAgainstPenalty;
               G_PENALTY_TREND_AGAINST += ZoneBreakAgainstPenalty;   // V136: same underlying fact as the other trend-conflict penalties
               v31_brain_penalty += ZoneBreakAgainstPenalty;
               detail += StringFormat(" -%d zone break AGAINST (%s);", ZoneBreakAgainstPenalty, zb_detail_e);
            }

            if((ZoneBreakPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z10 ZONE BREAK] entry dir=%d - %s", entry_dir_i, zb_detail_e);
         }
      }

      // V31.6z24 NEW: Session Transition Guard - the first few minutes after London/NY opens
      // are classically the most volatile, spread-prone window of the day. Applies a modest
      // universal caution rather than an outright block, since genuine opportunities do occur
      // right at session open too - just with more risk attached.
      if(EnableSessionTransitionGuard)
      {
         string st_detail = "";
         if(IsInSessionTransitionWindow(st_detail))
         {
            G_SCORE_PENALTY += SessionTransitionScorePenalty;
            G_PENALTY_CONDITIONS += SessionTransitionScorePenalty;
            v31_brain_penalty += SessionTransitionScorePenalty;
            detail += StringFormat(" -%d %s;", SessionTransitionScorePenalty, st_detail);
         }
      }

      // V31.6z25 NEW: Weekend Gap Guard - discourages fresh entries in the hours before
      // Friday's close, since an open basket has zero chance to react to weekend gap risk.
      if(EnableWeekendGapGuard)
      {
         string wg_detail = "";
         if(IsApproachingWeeklyClose(wg_detail))
         {
            G_SCORE_PENALTY += WeekendGapScorePenalty;
            G_PENALTY_QUALITY += WeekendGapScorePenalty;
            v31_brain_penalty += WeekendGapScorePenalty;
            detail += StringFormat(" -%d %s;", WeekendGapScorePenalty, wg_detail);
         }
      }

      // V31.6z25 NEW: Gap Detection - recognizes when the market just reopened after a
      // significant time gap (weekend/holiday) with a meaningful price jump. The first few
      // bars after a gap can behave unusually (settling, filling, or extending) - extra
      // caution rather than treating it like any other fresh signal. Persists for
      // GapCautionBarsAfter bars, not just the single bar the gap occurred on.
      if(EnableGapDetection)
      {
         double gap_pts = RecentGapPointsCached(SignalTF);
         if(gap_pts >= GapDetectionMinPoints)
            G_LAST_GAP_BAR = G_BARS_SEEN;

         if(G_LAST_GAP_BAR >= 0 && (G_BARS_SEEN - G_LAST_GAP_BAR) <= MathMax(0, GapCautionBarsAfter))
         {
            G_SCORE_PENALTY += GapCautionScorePenalty;
            G_PENALTY_QUALITY += GapCautionScorePenalty;
            v31_brain_penalty += GapCautionScorePenalty;
            detail += StringFormat(" -%d recent gap (%d bars ago);", GapCautionScorePenalty, G_BARS_SEEN - G_LAST_GAP_BAR);
         }
      }

      // FEATURE(gap-fill-magnet): keep the magnet state current, then penalise an entry that fights
      // the pull toward an unfilled gap. The hard-block variant lives in CounterContextBlockNow;
      // this branch adds a score penalty (used when hard-block is off, and as extra weight anyway).
      UpdateGapFillMagnet();
      UpdateGhostZones();
      if(EnableGapFillMagnet && !GapFillMagnetHardBlock &&
         G_GAP_FILL_DIR != 0 && entry_dir_i == -G_GAP_FILL_DIR)
      {
         G_SCORE_PENALTY += GapFillMagnetScorePenalty;
         G_PENALTY_QUALITY += GapFillMagnetScorePenalty;
         v31_brain_penalty += GapFillMagnetScorePenalty;
         detail += StringFormat(" -%d against gap-fill pull (%s);",
                                GapFillMagnetScorePenalty,
                                (G_GAP_FILL_DIR < 0 ? "down" : "up"));
      }

      // FEATURE(collapse-bottom-guard): penalty path (used when hard-block is off). Penalise an
      // entry that continues a fast recent collapse/spike right at its extreme.
      if(EnableCollapseBottomGuard && !CollapseGuardHardBlock)
      {
         int cbg_dir = CollapseBottomMoveDir();
         if(cbg_dir != 0 && entry_dir_i == cbg_dir)
         {
            G_SCORE_PENALTY += CollapseGuardScorePenalty;
            G_PENALTY_CONDITIONS += CollapseGuardScorePenalty;
            v31_brain_penalty += CollapseGuardScorePenalty;
            detail += StringFormat(" -%d continues fast %s;",
                                   CollapseGuardScorePenalty,
                                   (cbg_dir > 0 ? "spike" : "collapse"));
         }
      }

      // FEATURE(local-trend-turning): when the local trend is mid-flip (fast window disagrees with
      // the main window), a fresh first entry is riskier - the direction is unsettled. Apply a small
      // caution penalty so borderline entries wait for the turn to resolve. The dampened local
      // confidence already feeds alignment; this is an explicit, modest nudge on top.
      if(EnableLocalTrendTurning && G_LOCAL_TREND_TURNING)
      {
         G_SCORE_PENALTY += LocalTrendTurningPenalty;
         G_PENALTY_TREND_AGAINST += LocalTrendTurningPenalty;
         v31_brain_penalty += LocalTrendTurningPenalty;
         detail += StringFormat(" -%d local trend turning;", LocalTrendTurningPenalty);
      }

      // FEATURE(local-trend-momentum): a fading local trend (ADX rolling over) is where late trend-
      // following entries get caught by the reversal. Small caution penalty so borderline entries in
      // a tiring trend wait. The trimmed local confidence already feeds alignment; this is on top.
      if(EnableLocalTrendMomentum && G_LOCAL_TREND_FADING)
      {
         G_SCORE_PENALTY += LocalTrendFadePenalty;
         G_PENALTY_TREND_AGAINST += LocalTrendFadePenalty;
         v31_brain_penalty += LocalTrendFadePenalty;
         detail += StringFormat(" -%d local trend fading;", LocalTrendFadePenalty);
      }

      // FEATURE(global-trend-momentum): the big-picture equivalents. A fading or just-turned GLOBAL
      // trend is a stronger caution than the local ones - macro reversals are the deep-DD events - so
      // these carry a slightly higher penalty.
      if(EnableGlobalTrendMomentum && G_GLOBAL_TREND_FADING)
      {
         G_SCORE_PENALTY += GlobalTrendFadePenalty;
         G_PENALTY_TREND_AGAINST += GlobalTrendFadePenalty;
         v31_brain_penalty += GlobalTrendFadePenalty;
         detail += StringFormat(" -%d global trend fading;", GlobalTrendFadePenalty);
      }
      if(EnableGlobalTrendTurning && G_GLOBAL_TREND_TURNING)
      {
         G_SCORE_PENALTY += GlobalTrendTurningPenalty;
         G_PENALTY_TREND_AGAINST += GlobalTrendTurningPenalty;
         v31_brain_penalty += GlobalTrendTurningPenalty;
         detail += StringFormat(" -%d global trend turning;", GlobalTrendTurningPenalty);
      }

      // FEATURE(recent-extreme): penalty path (when RecentExtremeHardBlock is off). Penalise entering
      // with a sizeable recent move at its exhausted extreme (rejection wick).
      if(EnableRecentExtremeBlock && !RecentExtremeHardBlock && _Point > 0.0)
      {
         int rx_win = MathMax(3, RecentExtremeWindowBars);
         double rx_now = CandleClose(SignalTF, 1);
         double rx_start = CandleClose(SignalTF, rx_win);
         double rx_hi = HighestHigh(SignalTF, rx_win, 1);
         double rx_lo = LowestLow(SignalTF, rx_win, 1);
         double rx_rng = rx_hi - rx_lo;
         if(rx_now > 0.0 && rx_start > 0.0 && rx_rng > 0.0)
         {
            double rx_net = MathAbs(rx_now - rx_start) / _Point;
            int rx_move = (rx_now > rx_start) ? 1 : -1;
            if(entry_dir_i == rx_move && rx_net >= RecentExtremeMinMovePoints)
            {
               double rx_near = (rx_move > 0) ? (rx_hi - rx_now) / rx_rng : (rx_now - rx_lo) / rx_rng;
               double rx_limit = MathMax(0.0, MathMin(1.0, RecentExtremeNearPercent / 100.0));
               double rx_range = CandleRangePoints(SignalTF, 1);
               double rx_wick = (rx_move > 0) ? UpperWickPoints(SignalTF, 1) : LowerWickPoints(SignalTF, 1);
               if(rx_near <= rx_limit && rx_range > 0.0 && (rx_wick / rx_range) >= RecentExtremeWickRatio)
               {
                  G_SCORE_PENALTY += RecentExtremePenalty;
                  G_PENALTY_IMPULSE += RecentExtremePenalty;
                  v31_brain_penalty += RecentExtremePenalty;
                  detail += StringFormat(" -%d recent extreme (%s move net %.0f);", RecentExtremePenalty, (rx_move > 0 ? "up" : "down"), rx_net);
               }
            }
         }
      }

      // FEATURE(correction-exhaustion): penalty path (when CorrectionExhaustionHardBlock is off).
      // Penalise fading the main trend at a tiring correction top/bottom.
      if(EnableCorrectionExhaustion && !CorrectionExhaustionHardBlock &&
         G_LAST_IMPULSE_DIRECTION != 0 && entry_dir_i == -G_LAST_IMPULSE_DIRECTION && _Point > 0.0)
      {
         int ce_age = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
         if(ce_age >= 0 && ce_age <= MathMax(1, CorrectionExhaustionWindowBars))
         {
            double ce_retrace = ImpulseCorrectionRetracePercent();
            double ce_range = CandleRangePoints(SignalTF, 1);
            if(ce_retrace >= CorrectionExhaustionMinRetrace && ce_range > 0.0)
            {
               double ce_wick = (entry_dir_i > 0) ? UpperWickPoints(SignalTF, 1) : LowerWickPoints(SignalTF, 1);
               if((ce_wick / ce_range) >= CorrectionExhaustionWickRatio)
               {
                  G_SCORE_PENALTY += CorrectionExhaustionPenalty;
                  G_PENALTY_IMPULSE += CorrectionExhaustionPenalty;
                  v31_brain_penalty += CorrectionExhaustionPenalty;
                  detail += StringFormat(" -%d correction exhausted (retrace %.0f%%);", CorrectionExhaustionPenalty, ce_retrace);
               }
            }
         }
      }

      // FEATURE(zone-thrust-penalty): price arriving at the level WITH a thrust means the small
      // bounce bar that created this zone-retest signal is probably just a pause before the break.
      // Penalise fading it. Applies whenever the entry direction opposes the arriving thrust.
      if(EnableZoneThrustPenalty)
      {
         int thrust_dir = RecentThrustDir();
         // A thrust that is already stalling (rejection wick) is no longer a reason to avoid fading
         // the level - that's exactly when the reversal is reasonable. Only penalise a LIVE thrust.
         bool thrust_stalling = (RecentThrustExhaustedDir() == thrust_dir && thrust_dir != 0);
         if(thrust_dir != 0 && !thrust_stalling && entry_dir_i == -thrust_dir)
         {
            G_SCORE_PENALTY += ZoneThrustPenaltyPoints;
            G_PENALTY_QUALITY += ZoneThrustPenaltyPoints;
            v31_brain_penalty += ZoneThrustPenaltyPoints;
            detail += StringFormat(" -%d fading an arriving %s thrust;", ZoneThrustPenaltyPoints, (thrust_dir > 0 ? "up" : "down"));
         }
      }

      // FEATURE(counter-impulse-block): penalty path (used when CounterImpulseHardBlock is off).
      // Penalise a first entry that opposes an active, non-exhausted spike/sustained impulse.
      if(EnableCounterImpulseBlock && !CounterImpulseHardBlock)
      {
         int ci_dir = SpikeImpulseDir();
         if(ci_dir == 0)
            ci_dir = SustainedImpulseDir();
         if(ci_dir != 0 && entry_dir_i == -ci_dir)
         {
            int exh = SustainedImpulseExhaustedDir();
            if(exh != ci_dir)   // not exhausted -> impulse still running
            {
               G_SCORE_PENALTY += CounterImpulseScorePenalty;
               G_PENALTY_IMPULSE += CounterImpulseScorePenalty;
               v31_brain_penalty += CounterImpulseScorePenalty;
               detail += StringFormat(" -%d opposes active %s impulse;",
                                      CounterImpulseScorePenalty, (ci_dir > 0 ? "up" : "down"));
            }
         }
      }

      // FEATURE(ghost-zones): penalty path (used when ghost hard-block is off, the default). Penalise
      // a signal running into a recently-broken level that price may react at.
      if(EnableGhostZones && !GhostZoneHardBlock)
      {
         int ghost_dir = GhostZoneReactionDir();
         if(ghost_dir != 0 && entry_dir_i == ghost_dir)
         {
            G_SCORE_PENALTY += GhostZoneScorePenalty;
            G_PENALTY_QUALITY += GhostZoneScorePenalty;
            v31_brain_penalty += GhostZoneScorePenalty;
            detail += StringFormat(" -%d into ghost zone;", GhostZoneScorePenalty);
         }
      }

      // FEATURE(sustained-impulse-exhaustion): penalise adding in the impulse direction once a
      // sustained impulse shows exhaustion (rejection wick + efficiency drop). This is the WITH-
      // impulse counterpart to the correction penalty above: entering the tail end of a stalling
      // one-way move is a classic deep-DD entry.
      if(EnableSustainedExhaustion)
      {
         int exh_dir = SustainedImpulseExhaustedDir();
         if(exh_dir != 0 && entry_dir_i == exh_dir)
         {
            G_SCORE_PENALTY += SustainedExhaustionPenalty;
            G_PENALTY_IMPULSE += SustainedExhaustionPenalty;
            v31_brain_penalty += SustainedExhaustionPenalty;
            detail += StringFormat(" -%d impulse exhausted (%s tail);",
                                   SustainedExhaustionPenalty, (exh_dir > 0 ? "up" : "down"));
         }
      }

      if(EnableImpulseCorrectionPenalty && G_LAST_IMPULSE_DIRECTION != 0 &&
         entry_dir_i == -G_LAST_IMPULSE_DIRECTION)
      {
         int imp_age = G_BARS_SEEN - G_LAST_IMPULSE_BAR;
         if(imp_age >= 0 && imp_age <= MathMax(1, ImpulseCorrectionPenaltyWindowBars))
         {
            double retrace = ImpulseCorrectionRetracePercent();
            if(retrace > 0.0 && retrace < ImpulseCorrectionDonePercent)
            {
               G_SCORE_PENALTY += ImpulseCorrectionPenaltyPoints;
               G_PENALTY_IMPULSE += ImpulseCorrectionPenaltyPoints;
               v31_brain_penalty += ImpulseCorrectionPenaltyPoints;
               detail += StringFormat(" -%d counter-impulse (retrace %.0f%%<%.0f%%);",
                                      ImpulseCorrectionPenaltyPoints, retrace, ImpulseCorrectionDonePercent);
            }
         }
      }

      // Gather remaining independent-category flags for the consensus check below.
      //
      // V31.6z66 fix: structural bias found via audit. These three categories were only ever
      // computed in the AGREE direction - there was no cat_orderflow_against, cat_dxy_against
      // or cat_bigtrend_against anywhere. So Order Flow, DXY and the Kalman big-trend could
      // vote FOR an entry but were structurally incapable of voting AGAINST one, no matter how
      // firmly they opposed it. That left 11 ways to agree versus only 8 ways to disagree,
      // against the same threshold - agreement was simply easier to reach than disagreement.
      // FIX(orderflow-magnitude): OrderFlowConvictionSign() classifies VOLUME MAGNITUDE
      // (+1 = heavy/confirmed, -1 = thin/weak, 0 = ordinary) from iVolume alone - it carries NO
      // bullish/bearish direction. Tying it to the entry direction made the test ASYMMETRIC:
      // it demanded heavy volume to confirm a BUY but thin volume to confirm a SELL.
      cat_orderflow = (EnableOrderFlow && OrderFlowConvictionSign(SignalTF, 1) > 0);
      cat_orderflow_against = (EnableOrderFlow && OrderFlowConvictionSign(SignalTF, 1) < 0);

      if(EnableDXYProxy)
      {
         string dxy_reason = "";
         int dxy_dir = DXYProxyDirection(dxy_reason);
         int price_effect = DXYProxyInverseRelationship ? -dxy_dir : dxy_dir;
         cat_dxy = (price_effect != 0 && price_effect == entry_dir_i);
         cat_dxy_against = (price_effect != 0 && price_effect == -entry_dir_i);
      }

      if(KalmanTrendReady())
      {
         double slope = G_KALMAN_TREND / _Point;
         int kalman_dir = (slope > KalmanTrendMinPoints) ? 1 : (slope < -KalmanTrendMinPoints ? -1 : 0);
         cat_bigtrend = (kalman_dir != 0 && kalman_dir == entry_dir_i);
         cat_bigtrend_against = (kalman_dir != 0 && kalman_dir == -entry_dir_i);
      }

      // V31.6x UPGRADE: Brain Consensus - was tracking only the original 5 categories, missing
      // the 4 newer senses (Trend Strength/ADX, Major Sweep, EQ Zone, Engulfing) entirely, and
      // only ever rewarded agreement - never recognized genuine multi-sense DISAGREEMENT as its
      // own danger signal. Now symmetric across all 9 categories, matching the more complete
      // design Grid Intelligence already has.
      if(EnableBrainConsensus)
      {
         int categories_agree = (cat_reversal ? 1 : 0) + (cat_orderflow ? 1 : 0) +
                                 (cat_dxy ? 1 : 0) + (cat_bigtrend ? 1 : 0) + (cat_mtf ? 1 : 0) +
                                 (cat_majorsweep ? 1 : 0) + (cat_eqzone ? 1 : 0) + (cat_engulfing ? 1 : 0) +
                                 (cat_trendquality ? 1 : 0) + (cat_impulse ? 1 : 0) + (cat_zonebreak ? 1 : 0);

         int categories_against = (cat_reversal_against ? 1 : 0) + (cat_mtf_against ? 1 : 0) +
                                   (cat_trendstrength_against ? 1 : 0) + (cat_majorsweep_against ? 1 : 0) +
                                   (cat_eqzone_against ? 1 : 0) + (cat_engulfing_against ? 1 : 0) +
                                   (cat_impulse_against ? 1 : 0) + (cat_zonebreak_against ? 1 : 0) +
                                   (cat_orderflow_against ? 1 : 0) + (cat_dxy_against ? 1 : 0) +
                                   (cat_bigtrend_against ? 1 : 0);

         int min_cats = MathMax(2, BrainConsensusMinCategories);

         // V31.6z66 fix: the branches below used to be `if(agree) ... else if(against)`. That
         // `else` meant the moment enough categories agreed, the against-count was never even
         // looked at - so a genuinely CONFLICTED market (say 5 categories for AND 5 against)
         // collected the full agreement bonus while five independent senses shouting the
         // opposite were silently discarded. Grid Intelligence has always handled this case
         // properly with its own conflicted-signals branch; First Entry simply never did.
         // Conflict is its own distinct state - not a weaker form of agreement.
         bool strong_agree   = (categories_agree >= min_cats);
         bool strong_against = (categories_against >= min_cats);

         if(strong_agree && strong_against)
         {
            int conflict_pen = BrainConsensusConflictPenalty;
            G_SCORE_PENALTY += conflict_pen;
            v31_brain_penalty += conflict_pen;
            detail += StringFormat(" -%d brain CONFLICTED (%d for vs %d against);",
                                   conflict_pen, categories_agree, categories_against);

            if((BrainConsensusPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6z66 BRAIN CONFLICTED] %d categories agree BUT %d disagree on dir=%d - ambiguous, not confirmation",
                           categories_agree, categories_against, entry_dir_i);
         }
         else if(strong_agree)
         {
            G_SCORE_BONUS += BrainConsensusBonus;
         G_BONUS_TREND_ALIGN += BrainConsensusBonus;   // V134: same underlying fact as the other trend-agreement bonuses
            detail += StringFormat(" +%d brain consensus (%d independent categories agree);",
                                   BrainConsensusBonus, categories_agree);

            if((BrainConsensusPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6i BRAIN CONSENSUS] %d independent categories agree on dir=%d - synergy bonus",
                           categories_agree, entry_dir_i);
         }
         else if(strong_against)
         {
            int conflict_penalty = BrainConsensusBonus + (categories_against - min_cats);
            G_SCORE_PENALTY += conflict_penalty;
            v31_brain_penalty += conflict_penalty;
            detail += StringFormat(" -%d brain consensus AGAINST (%d independent categories disagree);",
                                   conflict_penalty, categories_against);

            if((BrainConsensusPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v31.6x BRAIN CONSENSUS AGAINST] %d independent categories disagree with dir=%d - synergy penalty",
                           categories_against, entry_dir_i);
         }
      }
   }

   // V31.6y fix: Brain Penalty Cap MOVED here - was previously checked BEFORE 6 new penalty
   // sources (Trend Reversal against, MTF against, ADX against, Major Sweep against, EQ Zone
   // against, Engulfing against, Brain Consensus against) were even added to v31_brain_penalty,
   // making the cap completely ineffective against all of them - exactly the uncontrolled
   // stacking this cap exists to prevent. Now captures the true total.
   //
   // V31.6z61 fix: the cap became a blunt instrument once this session roughly doubled the
   // penalty sources (26 now, with a theoretical total well past 50). A HARD clip at 12 meant
   // 12 points of penalty and 55 points of penalty produced the IDENTICAL result - flattening
   // every nuanced, magnitude-aware penalty built today back into a single indistinguishable
   // value. "Mildly unfavourable" and "catastrophically unfavourable" scored the same.
   // A soft cap keeps the cap's real purpose (one setup shouldn't be killed by many small,
   // partly-correlated penalties) while preserving the ordering information beyond it: excess
   // still counts, just at heavily reduced weight. Same philosophy as the Bayesian shrinkage -
   // control the extreme without discarding what the data actually says.
   // V31.6z65 fix: a structural asymmetry found via audit, directly tied to the user's report
   // of BUYs at the top of extended rallies. Penalties are capped (below); bonuses were NOT.
   // But roughly 8 of the 22 bonus sources are measuring essentially ONE fact - "the trend
   // agrees with this direction": MTF, MTF Confidence, Global/Local, Trend Quality, Impulse,
   // DXY, ADX strength, Brain consensus. In a strong trend they ALL fire, stacking to ~+16 from
   // what is really a single piece of information, while every caution signal (zone ahead,
   // exhaustion, late entry, ambiguity) got compressed by the cap. The scoring therefore leaned
   // structurally toward chasing whatever was already running - precisely the failure mode
   // reported. Capping bonuses on the same terms as penalties restores the balance without
   // silencing either side.
   // V134: this must run BEFORE any total-bonus cap. It removes DOUBLE COUNTING, which is a
   // different job from limiting the total: if a total cap shrinks the bonus first, subtracting the
   // duplicate portion afterwards charges for the same excess twice and collapses a legitimately
   // strong setup to almost nothing (19 -> 14 -> 2 in the original ordering).
   //
   // Eight separate bonuses all reward the SAME underlying fact - "the trend agrees with this
   // entry". Global/local alignment, both structure frames, the verdict, the staircase, trend
   // quality and brain consensus are different measurements of one thing, and in a clean trend they
   // ALL fire: +19 from a single observation. That is what pushed the live bonus to 16 and made
   // every protection penalty irrelevant. Cap the group so trend agreement is worth a strong,
   // bounded amount - setup-quality bonuses (engulfing, sweep, EQ zone, zone break) are measuring
   // genuinely different things and stay outside this cap.
   if(MaxTrendAlignBonus > 0 && G_BONUS_TREND_ALIGN > MaxTrendAlignBonus)
   {
      int trend_excess = G_BONUS_TREND_ALIGN - MaxTrendAlignBonus;
      G_SCORE_BONUS -= trend_excess;
      if(G_SCORE_BONUS < 0) G_SCORE_BONUS = 0;
      detail += StringFormat(" [trend-agreement bonus %d->%d];", G_BONUS_TREND_ALIGN, MaxTrendAlignBonus);
   }

   if(EnableBonusCap && BonusCap > 0 && G_SCORE_BONUS > BonusCap)
   {
      int effective_bonus = BonusCap;

      if(EnableSoftBrainPenaltyCap)
      {
         double excess_b = (double)(G_SCORE_BONUS - BonusCap);
         effective_bonus = BonusCap + (int)MathRound(excess_b * MathMax(0.0, MathMin(1.0, BrainPenaltySoftFactor)));
      }

      if(effective_bonus < G_SCORE_BONUS)
      {
         detail += StringFormat(" bonus-cap (raw=%d -> %d);", G_SCORE_BONUS, effective_bonus);
         G_SCORE_BONUS = effective_bonus;
      }
   }

   if(BrainPenaltyCap > 0 && v31_brain_penalty > BrainPenaltyCap)
   {
      int effective_penalty = BrainPenaltyCap;

      if(EnableSoftBrainPenaltyCap)
      {
         double excess = (double)(v31_brain_penalty - BrainPenaltyCap);
         effective_penalty = BrainPenaltyCap + (int)MathRound(excess * MathMax(0.0, MathMin(1.0, BrainPenaltySoftFactor)));
      }

      int brain_refund = v31_brain_penalty - effective_penalty;
      if(brain_refund > 0)
      {
         G_SCORE_PENALTY -= brain_refund;
         detail += StringFormat(" +%d brain-cap refund (raw=%d -> %d);", brain_refund, v31_brain_penalty, effective_penalty);
      }
   }

   // FIX(penalty-stacking): many independent modules each subtract points for what is essentially
   // the SAME observation - "this entry is against the prevailing direction". Trend-against, MTF
   // confirm, MTF confidence, MTF vote, DLP HTF, daily bias, reversal consensus and global/local
   // alignment all read overlapping inputs, and their penalties simply added up: a counter-trend
   // reversal setup could accumulate ~19 points of penalty on top of a 7-point minimum, i.e. an
   // effective bar of ~26 when the scanner only ever produces single digits. The result was that
   // entire families of setup became mathematically unreachable rather than merely discouraged.
   // The lot path already solved exactly this with MinFirstEntryLotFactor (a floor under stacked
   // multiplicative cuts); the score path had no equivalent. Every guard still votes and still
   // logs, but their COMBINED subtraction is capped here, so overlapping opinions can discourage
   // an entry without silently making it impossible. Set 0 to restore uncapped stacking.
   // V173: trade-quality penalties get their own, higher ceiling. These describe something wrong
   // with THIS trade - no room to the target, a level that cannot be read, entering into a stop
   // pool, repeating a loss at the same price - and unlike conditions they SHOULD be able to refuse
   // on their own. V172 lowered every penalty together to stop conditions overwhelming the score,
   // which also blunted these, and a bot indifferent to real danger is worse than one that trades
   // too little.
   // V182: keep the FULL weight of what the modules found, before any cap trims it for the entry
   // decision. The entry decision needs a small number - the modules should shade it, not run it.
   // But sizing needs the whole picture: twelve points of accumulated warning is a different trade
   // from four, even when both are allowed through.
   // V184: every penalty now belongs to exactly one group. Twenty-seven of them were previously
   // ungrouped, which meant they bypassed the group caps entirely and went straight to the total -
   // so the careful ordering of quality / trend / conditions applied to barely half the system.
   //
   // The assignment follows one question: is this about the TRADE or about the MARKET? Entering
   // where a move has already exhausted is a placement problem (quality); a churning session or a
   // split verdict describes conditions the trade has to live with (conditions).
   G_PENALTY_RAW = G_PENALTY_QUALITY + G_PENALTY_CONDITIONS + G_PENALTY_TREND_AGAINST;

   // V214: the candle budget. Ten modules read candles and several of them read the SAME event -
   // a live rejection, its authorship and the sequence state are three views of one wick, and each
   // was charging for it separately. Together they could swing the score by more than thirty points
   // against caps of twelve, which would have let the candle layer outvote everything else by sheer
   // count rather than by being right.
   //
   // They keep their reasoning; what they lose is the ability to dominate. Whatever the candles
   // conclude arrives as one contribution, sized like any other group.
   // V249: how much of the EA is behind this, and do its layers agree? Both are read here, after
   // every module has spoken and before the caps compress the result - the caps would hide exactly
   // the shape being measured.
   if(EnableScoreConsensus || EnableLayerConflict)
   {
      // A 13 built from eleven small contributions is broad agreement. A 13 from two loud modules
      // with the rest silent is a narrow opinion that happened to shout. They reach the score
      // identically and are acted on identically.
      if(EnableScoreConsensus)
      {
         int con_n = 0;
         string con_detail = "";
         double breadth = ScoreConsensus(detail, con_n, con_detail);

         if(con_n > 0 && breadth < ConsensusThinBelow)
         {
            // Narrow support does not make the reading wrong - it makes it less certain, and the
            // honest expression of that is a smaller score rather than a refusal.
            int thin_pen = (int)MathRound((ConsensusThinBelow - breadth) /
                                          MathMax(0.01, ConsensusThinBelow) * (double)ConsensusThinPenalty);
            if(thin_pen > 0)
            {
               G_SCORE_PENALTY += thin_pen;
               G_PENALTY_CONDITIONS += thin_pen;
               detail += StringFormat(" -%d thin support: %s;", thin_pen, con_detail);
            }
         }
      }

      // And whether the layers are looking at the same chart and reaching opposite conclusions.
      // Three against three is not a weak signal; it is no signal, and the sum quietly turns it
      // into a small one.
      if(EnableLayerConflict && entry_dir_i != 0)
      {
         string cf_detail = "";
         double conflict = LayerContradiction(entry_dir_i, cf_detail);

         if(conflict >= ConflictMinSeverity)
         {
            int cf_pen = (int)MathRound(conflict * (double)ConflictPenalty);
            cf_pen = MathMax(1, cf_pen);
            G_SCORE_PENALTY += cf_pen;
            G_PENALTY_CONDITIONS += cf_pen;
            detail += StringFormat(" -%d %s;", cf_pen, cf_detail);

            if((ConflictPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v249 CONFLICT] %s | dir=%d", cf_detail, entry_dir_i);
         }
      }
   }

   // V274: the hierarchy has to act like one. V266 and V273 were built on the principle that the
   // larger scale decides what the smaller one MEANS rather than voting alongside it - and then both
   // were wired into the same structure budget as the local readings. Local sources cap at seven,
   // global conflict caps at seven, and the two cancel to nothing. A market where M5 says buy and
   // the monthly trend says the opposite comes out neutral, which is precisely the reading that
   // produced three losing baskets.
   //
   // Overruling means the larger scale reduces what the smaller one can claim, not that it files an
   // equal and opposite claim. So global conflict scales the local structure bonus down before the
   // budgets are applied. A strong monthly trend against the trade does not merely offset the local
   // case; it takes most of it away, which is what "the larger picture decides" actually means.
   if(EnableScaleHierarchy && entry_dir_i != 0 && G_STRUCT_BONUS > 0)
   {
      string hd_detail = "";
      double hier = HigherScaleConflict(entry_dir_i, hd_detail);

      double ctd = 0.0;
      if(EnableGlobalTrend)
      {
         string cd = "";
         ctd = CounterTrendAtLevel(entry_dir_i, cd);
      }

      double override_strength = MathMax(hier, ctd);

      if(override_strength >= HierarchyOverrideFrom)
      {
         double over = (override_strength - HierarchyOverrideFrom) /
                       MathMax(0.01, 1.0 - HierarchyOverrideFrom);
         double keep = 1.0 - MathMin(1.0, over) * HierarchyOverrideMaxCut;

         int before = G_STRUCT_BONUS;
         int after = (int)MathRound((double)G_STRUCT_BONUS * keep);
         int removed = before - after;

         if(removed > 0)
         {
            G_STRUCT_BONUS = after;
            G_SCORE_BONUS -= removed;
            if(G_SCORE_BONUS < 0) G_SCORE_BONUS = 0;
            detail += StringFormat(" [local case cut %d->%d by the larger scale];", before, after);
         }
      }
   }

   // V227: the structure budget. Five modules report on structure direction and all of them route
   // into the trend group, whose cap is 4 - so 27 points of independent reading arrived with the
   // force of one, and the cap decided which survived rather than the market. They also overlap: a
   // falling structure, three falling swings and lower highs across three timeframes are one
   // observation described three ways.
   //
   // One budget for the set, sized like any other group. The excess is removed from the trend group
   // too, or the group cap below would still be working from the uncapped figure.
   if(MaxStructurePenalty > 0 && G_STRUCT_PENALTY > MaxStructurePenalty)
   {
      int sp_excess = G_STRUCT_PENALTY - MaxStructurePenalty;
      G_SCORE_PENALTY -= sp_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      G_PENALTY_TREND_AGAINST -= sp_excess;
      if(G_PENALTY_TREND_AGAINST < 0) G_PENALTY_TREND_AGAINST = 0;
      detail += StringFormat(" [structure penalty %d->%d];", G_STRUCT_PENALTY, MaxStructurePenalty);
      G_STRUCT_PENALTY = MaxStructurePenalty;
   }
   if(MaxStructureBonus > 0 && G_STRUCT_BONUS > MaxStructureBonus)
   {
      int sb_excess = G_STRUCT_BONUS - MaxStructureBonus;
      G_SCORE_BONUS -= sb_excess;
      if(G_SCORE_BONUS < 0) G_SCORE_BONUS = 0;
      detail += StringFormat(" [structure bonus %d->%d];", G_STRUCT_BONUS, MaxStructureBonus);
      G_STRUCT_BONUS = MaxStructureBonus;
   }

   // V219: when the layers were read as one situation, their individual contributions are the same
   // evidence a second time. The situation already priced the rejection, the level and the swing
   // shape together - letting each of them score again counts one observation three times, which is
   // exactly the double-counting the situation reader exists to remove.
   if(EnableSituationRead && G_SITUATION != SIT_NONE)
   {
      int sup_bonus = (int)MathRound((double)G_CANDLE_BONUS * (1.0 - SituationSuppressFactor));
      int sup_pen   = (int)MathRound((double)G_CANDLE_PENALTY * (1.0 - SituationSuppressFactor));

      if(sup_bonus > 0)
      {
         G_SCORE_BONUS -= sup_bonus;
         if(G_SCORE_BONUS < 0) G_SCORE_BONUS = 0;
         G_CANDLE_BONUS -= sup_bonus;
      }
      if(sup_pen > 0)
      {
         G_SCORE_PENALTY -= sup_pen;
         if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
         G_PENALTY_QUALITY -= sup_pen;
         if(G_PENALTY_QUALITY < 0) G_PENALTY_QUALITY = 0;
         G_CANDLE_PENALTY -= sup_pen;
      }
      if(sup_bonus > 0 || sup_pen > 0)
         detail += StringFormat(" [situation named - candle parts reduced %d%%];",
                                (int)((1.0 - SituationSuppressFactor) * 100.0));
   }

   // V215: the budget scales with where price is. Candles at a strong level are answering the
   // question that decides the trade; the same candles in open space are describing where a bar
   // happened to turn. A fixed budget spends the same weight on both.
   int eff_candle_bonus = MaxCandleBonus;
   int eff_candle_penalty = MaxCandlePenalty;
   if(EnableCandleRelevance)
   {
      string rel_detail = "";
      double rel = CandleRelevance(entry_dir_i, rel_detail);

      // And when the readings simply disagree, the layer is undecided - it should say less
      // regardless of where price is.
      if(EnableCandleConflict)
      {
         int    cf_dir = 0;
         double cf_w = 0.0;
         string cf_detail = "";
         if(CandleConflictRead(cf_dir, cf_w, cf_detail) == CCONF_SPLIT)
            rel *= CandleSplitDampen;
      }

      eff_candle_bonus   = (int)MathRound((double)MaxCandleBonus * rel);
      eff_candle_penalty = (int)MathRound((double)MaxCandlePenalty * rel);
      if(StringLen(rel_detail) > 0 && MathAbs(rel - 1.0) > 0.1)
         detail += StringFormat(" [%s];", rel_detail);
   }

   if(eff_candle_bonus > 0 && G_CANDLE_BONUS > eff_candle_bonus)
   {
      int cb_excess = G_CANDLE_BONUS - eff_candle_bonus;
      G_SCORE_BONUS -= cb_excess;
      if(G_SCORE_BONUS < 0) G_SCORE_BONUS = 0;
      detail += StringFormat(" [candle bonus %d->%d];", G_CANDLE_BONUS, eff_candle_bonus);
      G_CANDLE_BONUS = eff_candle_bonus;
   }
   if(eff_candle_penalty > 0 && G_CANDLE_PENALTY > eff_candle_penalty)
   {
      int cp_excess = G_CANDLE_PENALTY - eff_candle_penalty;
      G_SCORE_PENALTY -= cp_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      // The excess also has to come out of the quality group it was added to, or the group caps
      // below would still see the uncapped figure.
      G_PENALTY_QUALITY -= cp_excess;
      if(G_PENALTY_QUALITY < 0) G_PENALTY_QUALITY = 0;
      detail += StringFormat(" [candle penalty %d->%d];", G_CANDLE_PENALTY, eff_candle_penalty);
      G_CANDLE_PENALTY = eff_candle_penalty;
   }

   // V185: the impulse family capped separately, then folded into quality. Six penalties describe
   // the same observation - the move is stretched, exhausted, or being faded - and in a strong
   // impulse three or four fire together for 15-19 points. That is one reason spending the entire
   // quality budget, leaving nothing to express a room or level problem alongside it.
   if(MaxImpulsePenalty > 0 && G_PENALTY_IMPULSE > MaxImpulsePenalty)
   {
      int imp_excess = G_PENALTY_IMPULSE - MaxImpulsePenalty;
      G_SCORE_PENALTY -= imp_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      detail += StringFormat(" [impulse penalty %d->%d];", G_PENALTY_IMPULSE, MaxImpulsePenalty);
      G_PENALTY_IMPULSE = MaxImpulsePenalty;
   }
   G_PENALTY_QUALITY += G_PENALTY_IMPULSE;

   if(MaxQualityPenalty > 0 && G_PENALTY_QUALITY > MaxQualityPenalty)
   {
      int q_excess = G_PENALTY_QUALITY - MaxQualityPenalty;
      G_SCORE_PENALTY -= q_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      detail += StringFormat(" [quality penalty %d->%d];", G_PENALTY_QUALITY, MaxQualityPenalty);
   }

   // V170: noise, session and spread are three readings of ONE question - is the market currently
   // worth trading at all? They fire together in exactly the conditions where each is individually
   // right (a churning Asian session with a wide spread), and stacking them meant conditions alone
   // could exhaust the entire penalty budget, leaving nothing to express an actual setup problem.
   if(MaxConditionPenalty > 0 && G_PENALTY_CONDITIONS > MaxConditionPenalty)
   {
      int cond_excess = G_PENALTY_CONDITIONS - MaxConditionPenalty;
      G_SCORE_PENALTY -= cond_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      detail += StringFormat(" [conditions penalty %d->%d];", G_PENALTY_CONDITIONS, MaxConditionPenalty);
   }

   // V136: six penalties all charge for the SAME fact - "this entry fights the trend/structure".
   // Structure-against, verdict-against, staircase-against, zone-break-against, pullback-fade and
   // brain-conflict are different measurements of one conflict, together worth 25. Against a total
   // cap of 6 that meant one warning and six warnings scored almost identically (4 vs 6), so the
   // system could not tell "slightly questionable" from "everything disagrees".
   //
   // Capping the group removes the duplication; raising the total cap then lets DIFFERENT kinds of
   // danger accumulate again - trend conflict AND no room AND an undefined zone role is genuinely
   // worse than any one of them alone. Runs before the total cap, for the same reason the bonus
   // group cap does: de-duplicating and limiting are separate jobs, in that order.
   if(MaxTrendAgainstPenalty > 0 && G_PENALTY_TREND_AGAINST > MaxTrendAgainstPenalty)
   {
      int tp_excess = G_PENALTY_TREND_AGAINST - MaxTrendAgainstPenalty;
      G_SCORE_PENALTY -= tp_excess;
      if(G_SCORE_PENALTY < 0) G_SCORE_PENALTY = 0;
      detail += StringFormat(" [trend-conflict penalty %d->%d];", G_PENALTY_TREND_AGAINST, MaxTrendAgainstPenalty);
   }

   // V129: make HIGH HUNTER as careful as BALANCED about danger, while keeping it quicker on clean
   // setups. Hunter is structurally ~3 points lighter than Balanced (min score 6 -> 4, plus a +1
   // signal bonus), which meant a good-but-warned setup - base 7-9 with one protection penalty -
   // passed in Hunter while Balanced correctly waited. Every protection added in this session
   // (structure, room, verdict, late-entry, zone role...) was quietly weaker there.
   //
   // Scaling the accumulated penalty by the same factor restores the balance: with no warnings
   // Hunter still enters where Balanced would not (that is its purpose), but the moment a real
   // danger signal appears it now refuses exactly like Balanced does.

   // V130: the bonus side was never capped while the penalty side was capped at 6. Live screenshot:
   // base=8, bonus=16, penalty=6 -> final 18 against a Hunter bar of 4. With bonuses free to reach
   // 16 from 29 separate sources, NO protection penalty could ever change the outcome - every guard
   // added in this session was arguing against a number it could not reach. Capping the bonus
   // restores the balance: strong setups still score well, but agreement between many bonus sources
   // stops being an automatic override of every danger signal.
   // V270: which side of the day's open is price on? It is the reference every participant measures
   // the day against - above it the day is up and buyers are in profit, below it the day is down -
   // and it is the single most widely watched price on the chart. V252 added the weekly open and
   // stopped there.
   if(EnableDailyOpen && entry_dir_i != 0)
   {
      int    do_side = 0;
      double do_dist = 0.0;
      double do_price = DailyOpenPrice(do_side, do_dist);

      if(do_price > 0.0 && do_side != 0 && do_dist >= (double)DailyOpenMinDistance)
      {
         // Trading with the day rather than against it. The further price has travelled from the
         // open, the more the day has committed to a direction.
         double commitment = MathMin(1.0, do_dist / MathMax(1.0, (double)DailyOpenFullDistance));
         int do_adj = (int)MathRound(commitment * (double)DailyOpenScore);

         if(do_adj > 0)
         {
            if(do_side == entry_dir_i)
            {
               G_SCORE_BONUS += do_adj;
               detail += StringFormat(" +%d with the day (%.0f pts %s its open);",
                                      do_adj, do_dist, (do_side > 0 ? "above" : "below"));
            }
            else
            {
               G_SCORE_PENALTY += do_adj;
               G_PENALTY_TREND_AGAINST += do_adj;
               detail += StringFormat(" -%d against the day (%.0f pts %s its open);",
                                      do_adj, do_dist, (do_side > 0 ? "above" : "below"));
            }
         }
      }
   }

   // V270: is price making progress on less participation than it used to need?
   // CandleParticipation reads volume on one bar - whether the market showed up for it. What it
   // cannot see is effort against result across bars: a new high reached on less volume than the
   // previous high took means fewer participants are needed to move price, which is what a move
   // running out looks like before it turns.
   if(EnableVolumeDivergence && entry_dir_i != 0)
   {
      int    vd_dir = 0;
      string vd_detail = "";
      double vd_conv = VolumeDivergence(vd_dir, vd_detail);

      if(vd_conv >= VolumeDivergenceMinConviction && vd_dir != 0)
      {
         int vd_adj = (int)MathRound(vd_conv * (double)VolumeDivergenceScore);
         vd_adj = MathMax(1, vd_adj);

         if(vd_dir == entry_dir_i)
         {
            // Joining the move that is running out of participation.
            G_SCORE_PENALTY += vd_adj;
            G_PENALTY_IMPULSE += vd_adj;
            G_CANDLE_PENALTY += vd_adj;
            detail += StringFormat(" -%d joining a fading move: %s;", vd_adj, vd_detail);
         }
         else
         {
            G_SCORE_BONUS += vd_adj;
            G_CANDLE_BONUS += vd_adj;
            detail += StringFormat(" +%d %s;", vd_adj, vd_detail);
         }

         if((VolumeDivergencePrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v270 DIVERGENCE] %s | fading dir=%d | entry dir=%d",
                        vd_detail, vd_dir, entry_dir_i);
      }
   }

   // V269: how has this setup type actually performed here?   // V269: how has this setup type actually performed here? The EA recognises sixteen types and
   // treats them as equally likely to work, having never counted which ones do. That cannot be
   // reasoned out from first principles - the answer depends on the spread, the sessions this
   // account trades and how this symbol behaves - so it has to be measured. The candle layer already
   // learns this way; it was never extended to the setups, which is where the difference matters
   // most.
   if(EnableSetupLearning && G_OPP_TYPE != OPP_TYPE_NONE)
   {
      string sl_detail = "";
      int sl_adj = SetupTypeAdjustment((int)G_OPP_TYPE, sl_detail);

      if(sl_adj > 0)
      {
         G_SCORE_BONUS += sl_adj;
         detail += StringFormat(" +%d %s;", sl_adj, sl_detail);
      }
      else if(sl_adj < 0)
      {
         G_SCORE_PENALTY += -sl_adj;
         G_PENALTY_QUALITY += -sl_adj;
         detail += StringFormat(" -%d %s;", -sl_adj, sl_detail);
      }
   }

   // V268: is today one of the days nobody is there?   // V268: is today one of the days nobody is there? The holiday guard exists and only works if
   // someone types the dates in every year, and a list nobody updated is a guard that quietly
   // stopped guarding. Most thin days need no list - the fixed holidays never move, late December
   // empties out regardless of where the weekend falls, August is structurally quiet, and month-end
   // brings flow the EA cannot anticipate. A ladder built in a thin market assumes someone will be
   // there to take the other side of the recovery, and on these days there is a fair chance nobody
   // is.
   if(EnableCalendarThinness && entry_dir_i != 0)
   {
      string ct_detail = "";
      double thin = CalendarThinness(ct_detail);

      if(thin >= ThinMinSeverity)
      {
         int ct_pen = (int)MathRound(thin * (double)ThinDayPenalty);
         ct_pen = MathMax(1, ct_pen);
         G_SCORE_PENALTY += ct_pen;
         G_PENALTY_CONDITIONS += ct_pen;
         detail += StringFormat(" -%d %s;", ct_pen, ct_detail);

         if((ThinDayPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v268 THIN] %s", ct_detail);
      }
   }

   // V291: was this level already decided about? Everything slow was computed while price was still
   // on its way here - the trend, the scales, the range, the day. Reading it back means the entry
   // does not spend three bars re-deriving what was already true, and those three bars are the
   // difference between the reaction and the tail of it.
   if(EnablePreparedLevels && entry_dir_i != 0)
   {
      string pr_detail = "";
      double pr_score = PreparedLevelHit(entry_dir_i, pr_detail);

      G_PREP_HIT_THIS_BAR = (pr_score >= PrepMinScore);
      if(G_PREP_HIT_THIS_BAR)
      {
         int pr_bonus = (int)MathRound(MathMin(1.0, pr_score / MathMax(0.1, PrepFullScore)) *
                                       (double)PreparedLevelBonus);
         if(pr_bonus > 0)
         {
            G_SCORE_BONUS += pr_bonus;
            detail += StringFormat(" +%d %s;", pr_bonus, pr_detail);
         }
      }
   }

   // V288: is this entry at the far end of the move it wants to join? A live SELL was taken at the
   // low of a four-dollar decline and price turned two bars later. Four modules had objected and
   // each answered by subtracting points - the wrong answer, because nothing was wrong with the
   // setup. The direction was right and the structure was right; the moment was not.
   //
   // Selling the bottom of a decline and selling a pullback inside it are the same trade at
   // different prices, and only one works. A poor setup should be refused; a good setup at a poor
   // moment should be held.
   if(EnableLateEntryHold && entry_dir_i != 0 && EnableSetupArming)
   {
      double le_travelled = 0.0;
      string le_detail = "";
      double le_pos = EntryPositionInMove(entry_dir_i, le_travelled, le_detail);

      // V289: only a CONTINUATION setup is late at the extreme. A reversal setup is late everywhere
      // else - fading a move is a trade that only exists at its end, and holding one for a pullback
      // is waiting for the exact thing it was placed to catch. The previous version held both, which
      // delayed the setups that were already in the right place and slowed the EA for no gain.
      //
      // The distinction already exists: IsReversalOpportunityType knows which is which.
      bool le_is_reversal = IsReversalOpportunityType(G_OPP_TYPE);

      if(le_pos >= LateEntryHoldFrom && !le_is_reversal)
      {
         double le_target = LateEntryBetterPrice(entry_dir_i);
         if(le_target > 0.0 && SetupArm(entry_dir_i, ARM_REASON_LATE, le_target, le_detail, false))
         {
            G_SCORE_DECISION = SCORE_DECISION_WAIT;
            detail += StringFormat(" [holding for a pullback: %s];", le_detail);
            if((LateEntryPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v288 LATE] %s - waiting for %.2f", le_detail, le_target);
            return;
         }
      }
      else if(le_pos >= LateEntryHoldFrom && le_is_reversal && EnableReversalAtExtreme)
      {
         // V289: and a reversal setup at the extreme is where it belongs. The same reading that
         // makes a continuation trade late makes this one timely - it is fading a move that has
         // run, which is the only place fading works. Being at the end is the setup, not a flaw
         // in it.
         int re_bonus = (int)MathRound(((le_pos - LateEntryHoldFrom) /
                                        MathMax(0.01, 1.0 - LateEntryHoldFrom)) *
                                       (double)ReversalAtExtremeBonus);
         if(re_bonus > 0)
         {
            G_SCORE_BONUS += re_bonus;
            detail += StringFormat(" +%d fading a move that has run: %s;", re_bonus, le_detail);
         }
      }
   }

   // V275: the score has cleared, and the price it cleared at is arbitrary. A setup confirming at the
   // top of a bar and the same setup confirming at its low are one trade taken a dollar apart, with
   // a target of two-fifty - nearly half the trade decided by which tick the score happened to cross
   // on. EntryBarPlacement measures this and charges for it, which is the wrong answer to a timing
   // problem: a poor fill is not a reason to refuse a good setup, it is a reason to wait a few
   // minutes for a better one. The setup does not expire in three bars.
   if(EnableFillTiming && entry_dir_i != 0 && EnableSetupArming)
   {
      double fq_better = 0.0;
      string fq_detail = "";
      double fq_sev = FillQualityPenalty(entry_dir_i, fq_better, fq_detail);

      if(fq_sev >= FillTimingMinSeverity)
      {
         double fq_px = (entry_dir_i > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(fq_px > 0.0 && SetupArm(entry_dir_i, ARM_REASON_FILL, fq_px, fq_detail, false))
         {
            G_SCORE_DECISION = SCORE_DECISION_WAIT;
            detail += StringFormat(" [holding for a better fill: %s];", fq_detail);

            if((FillTimingPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v275 FILL] %s | dir=%d", fq_detail, entry_dir_i);
            return;
         }
      }
   }

   // V273: what has the market been doing for months?   // V273: what has the market been doing for months? HigherScaleConflict reads H4 over eighty bars
   // - thirteen days, which is a swing inside a trend rather than the trend itself. This matters most
   // at the distant levels V272 extended the EA's memory to reach: a daily level from four months ago
   // is the strongest thing on the chart, and price arriving at it in a falling market is not the
   // same event as price arriving at it in a rising one. In the first the level is something the
   // trend has to get past and usually does; in the second it is where the trend stops.
   if(EnableGlobalTrend && entry_dir_i != 0)
   {
      string gt_detail = "";
      double ct = CounterTrendAtLevel(entry_dir_i, gt_detail);

      if(ct >= CounterTrendMinSeverity)
      {
         int ct_pen = (int)MathRound(ct * (double)CounterTrendPenalty);
         ct_pen = MathMax(1, ct_pen);
         G_SCORE_PENALTY += ct_pen;
         G_PENALTY_TREND_AGAINST += ct_pen;
         G_STRUCT_PENALTY += ct_pen;
         detail += StringFormat(" -%d %s;", ct_pen, gt_detail);

         if((GlobalTrendPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v273 GLOBAL] %s | dir=%d", gt_detail, entry_dir_i);
      }
      else
      {
         // Trading WITH an established monthly trend. The bonus is smaller than the penalty
         // because being right about direction is the easy half - the hard half is entry, and
         // that is what the rest of the scoring is for.
         double gs = 0.0;
         string gd = "";
         int gdir = GlobalTrendDirection(gs, gd);
         if(gdir == entry_dir_i && gs >= GlobalTrendMinStrength)
         {
            int gt_bonus = (int)MathRound(gs * (double)GlobalTrendBonus);
            if(gt_bonus > 0)
            {
               G_SCORE_BONUS += gt_bonus;
               detail += StringFormat(" +%d with the %s;", gt_bonus, gd);
            }
         }
      }
   }

   // V273: and the streak. PostWinFastEntry already removes the WAIT after a winning basket in the
   // same direction; what it does not do is raise the score. A direction that has just paid, twice,
   // in this market, has earned more than the removal of a delay - and the reverse matters more:
   // three losses in a row is the market saying the read is wrong, which deserves more than a note
   // on the dashboard.
   if(EnableStreakScoring)
   {
      if(G_WIN_STREAK >= StreakScoreFromWins && G_LAST_WIN_DIR == entry_dir_i)
      {
         double over = (double)(G_WIN_STREAK - StreakScoreFromWins + 1) /
                       MathMax(1.0, (double)StreakScoreFullWins);
         int ws = (int)MathRound(MathMin(1.0, over) * (double)StreakWinBonus);
         if(ws > 0)
         {
            G_SCORE_BONUS += ws;
            detail += StringFormat(" +%d %d wins in a row this way;", ws, G_WIN_STREAK);
         }
      }
      else if(G_LOSS_STREAK >= StreakScoreFromLosses)
      {
         // Applies whichever way the next trade points. After three losses the problem is the
         // reading, not the direction, and switching sides does not fix a bad reading.
         double over = (double)(G_LOSS_STREAK - StreakScoreFromLosses + 1) /
                       MathMax(1.0, (double)StreakScoreFullLosses);
         int ls = (int)MathRound(MathMin(1.0, over) * (double)StreakLossPenalty);
         if(ls > 0)
         {
            G_SCORE_PENALTY += ls;
            G_PENALTY_CONDITIONS += ls;
            detail += StringFormat(" -%d %d losses in a row;", ls, G_LOSS_STREAK);
         }
      }
   }

   // V266: does the larger scale disagree?   // V266: does the larger scale disagree?   // V266: does the larger scale disagree? Every reading here contributes points to one total, so an
   // M5 support and an H1 downtrend arrive as two numbers that get added - and the sum can come out
   // positive, which is how the EA bought a support inside a downtrend three times. The larger scale
   // does not vote alongside the smaller one; it decides what the smaller one MEANS. A support in an
   // uptrend is a place to buy; the identical support in a downtrend is a step on the way down.
   // Addition cannot express that, because it treats both inputs as the same kind of thing.
   if(EnableScaleHierarchy && entry_dir_i != 0)
   {
      string hs_detail = "";
      double conflict = HigherScaleConflict(entry_dir_i, hs_detail);

      if(conflict >= HierarchyMinConflict)
      {
         int hs_pen = (int)MathRound(conflict * (double)HierarchyPenalty);
         hs_pen = MathMax(1, hs_pen);
         G_SCORE_PENALTY += hs_pen;
         G_PENALTY_TREND_AGAINST += hs_pen;
         G_STRUCT_PENALTY += hs_pen;
         detail += StringFormat(" -%d %s;", hs_pen, hs_detail);

         if((HierarchyPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v266 HIERARCHY] %s | dir=%d", hs_detail, entry_dir_i);
      }
   }

   // V266: and what would the other direction have scored? The scanner finds the best setup one way
   // and scores it, and never asks. When both sides look good that is not two opportunities - it is
   // a market that has not decided, and a score of 11 for a buy means something different when the
   // sell also scores 9.
   if(EnableAmbiguityCheck && entry_dir_i != 0)
   {
      string amb_detail = "";
      double opp_strength = OppositeSideStrength(entry_dir_i, amb_detail);

      if(opp_strength >= AmbiguityMinOpposite)
      {
         double ratio = opp_strength / MathMax(1.0, (double)(G_SCORE_BASE + G_SCORE_BONUS));
         if(ratio >= AmbiguityMinRatio)
         {
            int amb_pen = (int)MathRound(MathMin(1.0, ratio) * (double)AmbiguityPenalty);
            amb_pen = MathMax(1, amb_pen);
            G_SCORE_PENALTY += amb_pen;
            G_PENALTY_CONDITIONS += amb_pen;
            detail += StringFormat(" -%d %s;", amb_pen, amb_detail);

            if((AmbiguityPrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v266 AMBIGUITY] %s | opposite %.1f against own %d",
                           amb_detail, opp_strength, G_SCORE_BASE + G_SCORE_BONUS);
         }
      }
   }

   // V263: broad agreement earns headroom. The ceiling exists to stop two loud modules from
   // dominating, and it does that job - but it applies the same limit when eleven modules each
   // contribute a point or two, which is the opposite situation and the one worth acting on.
   //
   // V249 already measures how many modules spoke, and it uses that only to penalise thin support.
   // The other half of the same reading was never used: when support IS broad, the cap that exists
   // to contain a narrow opinion is holding back a wide one.
   //
   // So the ceiling lifts with breadth rather than being fixed. A setup that eleven modules agree on
   // can express more than a setup two modules shouted about, which is what the scoring was supposed
   // to distinguish in the first place. Nothing about the penalty side changes.
   int eff_bonus_cap = MaxTotalScoreBonus;

   if(EnableConsensusHeadroom && MaxTotalScoreBonus > 0)
   {
      int con_n = 0;
      string con_d = "";
      double breadth = ScoreConsensus(detail, con_n, con_d);

      if(breadth >= ConsensusHeadroomFrom)
      {
         double over = (breadth - ConsensusHeadroomFrom) /
                       MathMax(0.01, 1.0 - ConsensusHeadroomFrom);
         eff_bonus_cap = MaxTotalScoreBonus +
                         (int)MathRound(MathMin(1.0, over) * (double)ConsensusHeadroomExtra);
      }
   }

   if(eff_bonus_cap > 0 && G_SCORE_BONUS > eff_bonus_cap)
   {
      detail += StringFormat(" [bonus capped %d->%d];", G_SCORE_BONUS, eff_bonus_cap);
      G_SCORE_BONUS = eff_bonus_cap;
   }

   // V249fix(auto-mode): the penalty cap is now RELATIVE TO THE BAR IN FORCE. It was a shared 12
   // while MinScoreForContext() moves between 2 (Hunter) and 4 (Balanced), so the number of penalty
   // points that could actually refuse an entry differed by the size of that gap: at base 5 / bonus 6,
   // Balanced could refuse with 8 points but Hunter needed 11. The aggressive mode was structurally
   // harder to stop - the same asymmetry the mode bonus created, arriving by a second route. Adding
   // back the bar difference restores symmetry, and is what HunterProtectionPenaltyScale was reaching
   // for before it was disabled as too blunt.
   int eff_penalty_cap = MaxTotalScorePenalty +
                         MathMax(0, (G_SCORE_IS_MICRO ? MinScoreMicroBalanced : MinScoreBalanced)
                                    - MinScoreForContext(G_SCORE_IS_MICRO));
   if(G_ACTIVE_MODE == SIRUS_MODE_HIGH_HUNTER && HunterProtectionPenaltyScale > 1.0)
   {
      int raw_pen = G_SCORE_PENALTY;
      G_SCORE_PENALTY = (int)MathRound(G_SCORE_PENALTY * HunterProtectionPenaltyScale);
      eff_penalty_cap = (int)MathRound(eff_penalty_cap * HunterProtectionPenaltyScale);
      if(G_SCORE_PENALTY != raw_pen)
         detail += StringFormat(" [hunter protection x%.2f: %d->%d];",
                                HunterProtectionPenaltyScale, raw_pen, G_SCORE_PENALTY);
   }

   if(eff_penalty_cap > 0 && G_SCORE_PENALTY > eff_penalty_cap)
   {
      detail += StringFormat(" [penalty capped %d->%d];", G_SCORE_PENALTY, eff_penalty_cap);
      G_SCORE_PENALTY = eff_penalty_cap;
   }

   // V278: a hard ceiling immediately before the sum. The cap above is applied and then further
   // penalty can arrive from the context pass and the legacy layer, each with its own limit computed
   // from a value that has since moved - so the total ends higher than the ceiling that was supposed
   // to bound it. On live screens the raw figure reached forty-seven against a ceiling of ten.
   //
   // Whatever path the penalty took to get here, this is the number that decides the trade, and it
   // is the right place to enforce the limit.
   if(MaxTotalScorePenalty > 0 && G_SCORE_PENALTY > MaxTotalScorePenalty)
   {
      detail += StringFormat(" [final penalty cap %d->%d];", G_SCORE_PENALTY, MaxTotalScorePenalty);
      G_SCORE_PENALTY = MaxTotalScorePenalty;
   }

   G_SCORE_FINAL = G_SCORE_BASE + G_SCORE_BONUS - G_SCORE_PENALTY;

   // FEATURE(impulse-end-hardblock): the exact scenario the user described - "impulse SELL,
   // then another SELL opens at the very bottom" (and the BUY-at-the-top mirror). Two distinct
   // dangers, both hard-blocked here regardless of how high the raw score is:
   //   (1) SAME-DIRECTION-INTO-CLIMAX: we want to enter in the same direction a move has ALREADY
   //       run to a climax extension (>= ImpulseEndHardBlockATR). That is entering at the
   //       exhausted end of the move - "selling the bottom / buying the top".
   //   (2) FRESH-IMPULSE-AGAINST: a sharp impulse candle just fired the OPPOSITE way. Entering
   //       straight into a fresh opposing burst is the classic trap.
   // Reuses MoveExtensionATR and ImpulseConfirmation, the same measurements the penalty system
   // above already trusts - this just makes the extreme cases a veto instead of a deduction.
   if((EnableImpulseEndHardBlock || EnableImpulseAgainstHardBlock) &&
      (G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL))
   {
      int imp_dir_i = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      string imp_hb_reason = "";
      bool   imp_hb = false;

      // (1) Same-direction entry into an already-climax-extended move.
      if(!imp_hb && EnableImpulseEndHardBlock && EnableMoveExtension)
      {
         double ext_hb = MoveExtensionATR(imp_dir_i);
         if(ext_hb >= ImpulseEndHardBlockATR)
         {
            // V31.67b: an extended move is only EXHAUSTION if the trend no longer backs it.
            // If the global trend still strongly agrees with our direction, this is trend
            // CONTINUATION - the exact "ride the trend, re-enter along it" case the user relies
            // on - so let it through. Only block an extended move that has lost its trend support.
            bool trend_still_backs = false;
            if(ImpulseEndHardBlockRespectTrend)
            {
               string gt_detail_hb = "";
               double gt_conf_hb = GlobalTrendConfidence(imp_dir_i, gt_detail_hb);
               trend_still_backs = (gt_conf_hb >= ImpulseEndHardBlockTrendConf);
            }

            if(!trend_still_backs)
            {
               imp_hb = true;
               imp_hb_reason = StringFormat("%s at the END of an extended move (%.1f ATR run, >= %.1f climax, trend no longer backing)",
                                            (imp_dir_i > 0 ? "BUY" : "SELL"), ext_hb, ImpulseEndHardBlockATR);
            }
         }
      }

      // (2) Entry straight into a fresh, strong OPPOSING impulse candle.
      if(!imp_hb && EnableImpulseAgainstHardBlock && EnableImpulseConfirmation)
      {
         string imp_conf_detail = "";
         double imp_conf = ImpulseConfirmation(imp_dir_i, imp_conf_detail);
         // ImpulseConfirmationRaw returns 0.15 when a qualifying impulse fired the OTHER way.
         if(imp_conf <= 0.15)
         {
            imp_hb = true;
            imp_hb_reason = StringFormat("%s straight into a fresh opposing impulse (%s)",
                                         (imp_dir_i > 0 ? "BUY" : "SELL"), imp_conf_detail);
         }
      }

      // (3) FEATURE(blowoff-hardblock): entry in the SAME direction as a giant climax candle that
      // just printed - buying the top / selling the bottom of a violent spike. This catches the
      // single-bar blow-off that the multi-bar MoveExtension measure can miss. Only same-direction
      // continuation into the spike is blocked; reversal/bounce entries against it are left alone.
      if(!imp_hb && EnableBlowOffHardBlock)
      {
         double bo_atr = ATRPointsManual(SignalTF, ImpulsePeriod, 1);
         if(bo_atr > 0.0 && BlowOffCandleATRMult > 0.0)
         {
            int bo_look = MathMax(1, BlowOffLookbackBars);
            for(int b = 1; b <= bo_look && !imp_hb; b++)
            {
               double bo_range = CandleRangePoints(SignalTF, b);
               if(bo_range < bo_atr * BlowOffCandleATRMult)
                  continue;   // not a blow-off-sized bar

               // Direction of this giant bar: bullish body = up spike, bearish = down spike.
               double bo_open  = CandleOpen(SignalTF, b);
               double bo_close = CandleClose(SignalTF, b);
               int bo_dir = (bo_close > bo_open) ? 1 : ((bo_close < bo_open) ? -1 : 0);

               // Block only if the spike is in OUR entry direction (jumping in at its extreme).
               if(bo_dir != 0 && bo_dir == imp_dir_i)
               {
                  imp_hb = true;
                  imp_hb_reason = StringFormat("%s right after a blow-off climax candle (bar%d range %.0fpts = %.1fx ATR)",
                                               (imp_dir_i > 0 ? "BUY" : "SELL"), b, bo_range, bo_range / bo_atr);
                  if((BlowOffHardBlockPrintOnUse && VerboseLogs))
                     PrintFormat("[SIRUS BLOW-OFF HARD BLOCK] %s", imp_hb_reason);
               }
            }
         }
      }

      if(imp_hb)
      {
         G_SCORE_DECISION   = SCORE_DECISION_HARD_BLOCK;
         G_SCORE_HARD_BLOCK = imp_hb_reason;
         G_SCORE_HB_DIR_WHY = imp_hb_reason;   // directional: refuses only the spike's side
         G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + imp_hb_reason;
         G_SCORE_DETAIL = StringFormat("SCORE DETAIL: impulse-end hard block | final=%d/%d | %s",
                                       G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, detail);

         if((ImpulseEndHardBlockPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS IMPULSE-END HARD BLOCK] %s | final score was %d/%d (blocked regardless)",
                        imp_hb_reason, G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);

         string sig_imp = G_SCORE_STATUS + "|" + IntegerToString(G_BARS_SEEN);
         G_SCORE_LAST_SIGNATURE = sig_imp;
         return;
      }
   }

   // FIX(zone-wall-hardblock): final, decisive guard for the exact failure in the user's
   // screenshot - a SELL fired directly on a strong support wall (or a BUY into strong
   // resistance) and price immediately ran the other way. The existing zone caution only
   // subtracts a few points, which a strong signal can out-score. This is a genuine HARD BLOCK,
   // reached ONLY when the opposing wall is BOTH very close AND very strong (thresholds are
   // deliberately stricter than the caution's). It runs after the score is known but before the
   // PASS decision, so it can veto an otherwise-passing signal. Reuses the same TF-weighted zone
   // search already used by the caution above.
   if(EnableZoneWallHardBlock && (G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL))
   {
      int wall_dir_i = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      double bid_hb = 0.0, ask_hb = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_hb);
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_hb);
      double mid_hb = (bid_hb > 0.0 && ask_hb > 0.0) ? (bid_hb + ask_hb) / 2.0 : bid_hb;

      if(mid_hb > 0.0 && _Point > 0.0)
      {
         // BUY is threatened by resistance overhead; SELL is threatened by support below.
         double wall = (wall_dir_i > 0) ?
                       ZoneMapNearestResistance(mid_hb) :
                       ZoneMapNearestSupport(mid_hb);

         if(wall > 0.0)
         {
            double wall_dist_pts = MathAbs(mid_hb - wall) / _Point;
            double wall_strength = ZoneMapStrength(wall);

            if(wall_dist_pts <= ZoneWallHardBlockPoints && wall_strength >= ZoneWallHardBlockMinStrength)
            {
               G_SCORE_DECISION   = SCORE_DECISION_HARD_BLOCK;
               G_SCORE_HARD_BLOCK = StringFormat("%s into strong %s wall (%.2f, str=%.1f, %.0fpts away)",
                                                 (wall_dir_i > 0 ? "BUY" : "SELL"),
                                                 (wall_dir_i > 0 ? "resistance" : "support"),
                                                 wall, wall_strength, wall_dist_pts);
               G_SCORE_HB_DIR_WHY = G_SCORE_HARD_BLOCK;   // directional: refuses only the side facing the wall
               G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + G_SCORE_HARD_BLOCK;
               G_SCORE_DETAIL = StringFormat("SCORE DETAIL: zone-wall hard block | final=%d/%d | %s",
                                             G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, detail);

               if((ZoneWallHardBlockPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS ZONE-WALL HARD BLOCK] %s | final score was %d/%d (blocked regardless)",
                              G_SCORE_HARD_BLOCK, G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);

               string sig_hb = G_SCORE_STATUS + "|" + IntegerToString(G_BARS_SEEN);
               G_SCORE_LAST_SIGNATURE = sig_hb;
               // V170c: record this refusal too. The block audit was only seeing the three newest blocks,
               // so its verdict described a fraction of the refusals and made the older ones look free.
               {
                  double ba2_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double ba2_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double ba2_mid = (ba2_bid > 0.0 && ba2_ask > 0.0) ? (ba2_bid + ba2_ask) / 2.0 : ba2_bid;
                  int    ba2_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
                  if(ba2_mid > 0.0 && ba2_dir != 0)
                     BlockAuditRecord(ba2_dir, ba2_mid);
               }
               return;
            }
         }
      }
   }

   // FEATURE(counter-context-guard): the three "entry fights current context" hard blocks
   // (counter-zone / HTF-against / range-breakout counter-fade) are evaluated by ONE shared
   // function, which the queue-replay guard also calls. That single source of truth is what stops
   // a stale queued signal from firing under conditions that would block a fresh entry.
   // First-entry only - grid recovery has its own zone/HTF logic and is not affected here.
   if(G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL)
   {
      int ctx_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      string ctx_why = "";
      // FIX(arm-confirm-deadlock): THE 18-HOUR NO-TRADE BUG.
      // CounterContextBlockNow() does not merely test - when EnableSetupArming is on it ARMS the
      // setup and returns true (see its zone/impulse blocks). SetupArmConfirmed() above, which is
      // the only place an arm is ever released, runs EARLIER in this same function. So both ways
      // out of a wait looped straight back into a new wait:
      //   - EXPIRY: after SetupArmZoneWaitBars the arm is dropped, execution falls through to here,
      //     the zone is still within CounterZoneBlockPoints, so SetupArm() arms it fresh (its
      //     "don't re-arm the same thing" guards do not fire because G_ARM_DIR was just cleared to
      //     0) and returns true. The clock restarts. Forever.
      //   - CONFIRMATION (worse): the arm confirms, gets its +SetupArmScoreBonus... and is then
      //     re-armed and hard-blocked here before the entry can ever be sent. And confirmation for
      //     ARM_REASON_ZONE IS a rejection AT the zone, so price is by construction still inside
      //     the block window at that moment - the confirmed trade could never be taken.
      // On top of that this `return` sits BEFORE G_FUNNEL_SETUPS++ below, so the dashboard funnel
      // read "0 setups -> 0, 0 blocked, 0 gated -> 0 entries" and gave no hint anything was wrong.
      // A setup whose objection the market has just answered is exactly the trade this engine was
      // built to take, so it is no longer re-tested against the objection it already survived.
      int ctx_pen_before = G_SCORE_PENALTY;
      if(CounterContextBlockNow(ctx_dir, ctx_why, (ctx_dir == arm_confirmed_dir)))
      {
         G_SCORE_DECISION   = SCORE_DECISION_HARD_BLOCK;
         G_SCORE_HARD_BLOCK = ctx_why;
         G_SCORE_HB_DIR_WHY = ctx_why;   // CHAIN FIX: a directional refusal - the brain may still look at the other side
         G_SCORE_STATUS = "SCORE: HARD_BLOCK | reason=" + G_SCORE_HARD_BLOCK;
         G_SCORE_DETAIL = StringFormat("SCORE DETAIL: counter-context block | final=%d/%d | %s",
                                       G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, detail);
         if((CounterZoneBlockPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS COUNTER-CONTEXT BLOCK] %s | score was %d/%d (first-entry blocked)",
                        G_SCORE_HARD_BLOCK, G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
         G_SCORE_LAST_SIGNATURE = G_SCORE_STATUS + "|" + IntegerToString(G_BARS_SEEN);
         // V170c: record this refusal too. The block audit was only seeing the three newest blocks,
         // so its verdict described a fraction of the refusals and made the older ones look free.
         {
            double ba2_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ba2_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double ba2_mid = (ba2_bid > 0.0 && ba2_ask > 0.0) ? (ba2_bid + ba2_ask) / 2.0 : ba2_bid;
            int    ba2_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
            if(ba2_mid > 0.0 && ba2_dir != 0)
               BlockAuditRecord(ba2_dir, ba2_mid);
         }
         return;
      }

      // FIX(context-penalties-inert): CounterContextBlockNow() does not only block - three of its
      // sections are configured as "penalty instead of hard block" and add to G_SCORE_PENALTY
      // rather than returning true: HTF-against, range-breakout fade, and fresh-impulse wait.
      // (The counter-impulse / correction-exhaustion / recent-extreme penalties inside it are
      // unreachable - their own hard-block flag gates the whole section - but those three families
      // already reach the score from their own earlier call sites, so nothing is double-counted.)
      // G_SCORE_FINAL was computed further ABOVE, so those three penalties landed in a variable
      // nothing read again: they changed no score, no decision, no lot and no TP.
      // Fold them in properly - same total cap as above, so this cannot run away - and recompute.
      if(G_SCORE_PENALTY != ctx_pen_before)
      {
         int ctx_added = G_SCORE_PENALTY - ctx_pen_before;

         // Must be the SAME ceiling the main clamp used, or adding a context penalty could re-clamp
         // the total DOWNWARD and paradoxically RAISE G_SCORE_FINAL. Mirrors the bar-relative term.
         int ctx_cap = MaxTotalScorePenalty +
                       MathMax(0, (G_SCORE_IS_MICRO ? MinScoreMicroBalanced : MinScoreBalanced)
                                  - MinScoreForContext(G_SCORE_IS_MICRO));

         if(G_SCORE_PENALTY < 0)
            G_SCORE_PENALTY = 0;
         if(ctx_cap > 0 && G_SCORE_PENALTY > ctx_cap)
            G_SCORE_PENALTY = ctx_cap;

         // The per-group caps (impulse, quality, trend) ran ABOVE this point, so the context
         // additions have not been through them. Re-clamp the two groups they can touch, or the
         // WAIT diagnostic prints out-of-cap group figures and the documented 9/4/2 ordering reads
         // wrong. The totals are already bounded by ctx_cap; this only keeps the breakdown honest.
         if(MaxImpulsePenalty > 0 && G_PENALTY_IMPULSE > MaxImpulsePenalty)
            G_PENALTY_IMPULSE = MaxImpulsePenalty;
         if(MaxQualityPenalty > 0 && G_PENALTY_QUALITY > MaxQualityPenalty)
            G_PENALTY_QUALITY = MaxQualityPenalty;

         // G_PENALTY_RAW drives EnableWarningLotScaling and EnableWarningTPScaling, and it is
         // computed BEFORE this point. Without this the fix would be half-applied in the LOOSE
         // direction: the entry decision would tighten while the position sizing kept using the
         // old, smaller warning count. Raw is uncapped by design, so add the pre-cap delta.
         G_PENALTY_RAW += ctx_added;

         // V278: a hard ceiling immediately before the sum. The cap above is applied and then further
   // penalty can arrive from the context pass and the legacy layer, each with its own limit computed
   // from a value that has since moved - so the total ends higher than the ceiling that was supposed
   // to bound it. On live screens the raw figure reached forty-seven against a ceiling of ten.
   //
   // Whatever path the penalty took to get here, this is the number that decides the trade, and it
   // is the right place to enforce the limit.
   if(MaxTotalScorePenalty > 0 && G_SCORE_PENALTY > MaxTotalScorePenalty)
   {
      detail += StringFormat(" [final penalty cap %d->%d];", G_SCORE_PENALTY, MaxTotalScorePenalty);
      G_SCORE_PENALTY = MaxTotalScorePenalty;
   }

   G_SCORE_FINAL = G_SCORE_BASE + G_SCORE_BONUS - G_SCORE_PENALTY;
         detail += StringFormat(" [context -%d -> penalty=%d final=%d];",
                                ctx_added, G_SCORE_PENALTY, G_SCORE_FINAL);
      }
   }

   if(G_OPP_DIR != OPP_DIR_NONE)
      G_FUNNEL_SETUPS++;

   // V280: one clamp immediately before the decision, whatever path the score took to get here.
   // The two earlier ceilings sit inside conditional blocks - the first runs before the context pass
   // adds its own penalty, the second only runs when that pass changed something - so a score can
   // reach this line having passed neither. Live screens showed penalty 43 against a ceiling of 10
   // and the EA refusing setups that had cleared everything else.
   //
   // This is the number that decides the trade. Bounding it anywhere earlier is bounding a value
   // that can still move; bounding it here is bounding the one that counts.
   // V287: the ceiling has to move with the breadth of objection, exactly as V263 moves the bonus
   // ceiling with the breadth of agreement. Leaving one side fixed made the scoring one-directional
   // in the other direction: bonus reaching twenty-six against a penalty frozen at ten meant six
   // modules could object to a setup and never stop it. A live SELL was taken at the bottom of a
   // long decline with the move-extension, maturity, progression and discount readings all against
   // it - and it passed, because their combined objection was cut to ten while the agreement that
   // carried it was not cut at all.
   //
   // Same mechanism, same reading, applied to the side that was left out.
   int eff_final_pen_cap = MaxTotalScorePenalty;

   if(EnableObjectionHeadroom && MaxTotalScorePenalty > 0 && G_PENALTY_RAW > 0)
   {
      // How far the raw objection ran past the ceiling. A setup drawing forty raw penalty has more
      // against it than one drawing twelve, and until now they were charged the same.
      double over = (double)(G_PENALTY_RAW - MaxTotalScorePenalty) /
                    MathMax(1.0, (double)MaxTotalScorePenalty * ObjectionHeadroomSpan);
      if(over > 0.0)
         eff_final_pen_cap = MaxTotalScorePenalty +
                             (int)MathRound(MathMin(1.0, over) * (double)ObjectionHeadroomExtra);
   }

   if(eff_final_pen_cap > 0 && G_SCORE_PENALTY > eff_final_pen_cap)
   {
      G_SCORE_DETAIL += StringFormat(" [decision penalty cap %d->%d];",
                                     G_SCORE_PENALTY, eff_final_pen_cap);
      G_SCORE_PENALTY = eff_final_pen_cap;
   }
   G_SCORE_FINAL = G_SCORE_BASE + G_SCORE_BONUS - G_SCORE_PENALTY;

   if(G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED)
   {
      G_LAST_ENTRY_ALLOWED_BAR = G_BARS_SEEN;   // V180: the valve measures silence from here
      if(G_SCORE_IS_MICRO)
         G_SCORE_DECISION = SCORE_DECISION_MICRO_PASS;
      else
         G_SCORE_DECISION = SCORE_DECISION_PASS;
   }
   else
   {
      G_SCORE_DECISION = SCORE_DECISION_WAIT;
      if(G_OPP_DIR != OPP_DIR_NONE)
         G_FUNNEL_SCORE_WAIT++;
   }

   // V172: when the decision is a block, the numbers alone do not say WHICH check refused it -
   // and with twenty penalty sources now live, "penalty=25" could be almost anything. The reason
   // string is what makes a refusal diagnosable instead of merely visible.
   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK && StringLen(G_SCORE_HARD_BLOCK) > 0)
   {
      G_SCORE_STATUS = StringFormat("SCORE: HARD_BLOCK | %s | base=%d bonus=%d penalty=%d",
                                    G_SCORE_HARD_BLOCK,
                                    G_SCORE_BASE, G_SCORE_BONUS, G_SCORE_PENALTY);
   }
   else
   G_SCORE_STATUS = StringFormat("SCORE: %s | final=%d/%d | base=%d bonus=%d penalty=%d | %s %s",
                                 ScoreDecisionToString(G_SCORE_DECISION),
                                 G_SCORE_FINAL,
                                 G_SCORE_MIN_REQUIRED,
                                 G_SCORE_BASE,
                                 G_SCORE_BONUS,
                                 G_SCORE_PENALTY,
                                 OpportunityGradeToString(G_OPP_GRADE),
                                 OpportunityDirToString(G_OPP_DIR));

   // V172: and when it is a WAIT, show what the penalty was actually made of. A wait with
   // penalty=25 is not one problem, it is several - and only the breakdown says which.
   if(G_SCORE_DECISION == SCORE_DECISION_WAIT && G_SCORE_PENALTY > 0)
      G_SCORE_STATUS += StringFormat(" | trend=%d conditions=%d", 
                                     G_PENALTY_TREND_AGAINST, G_PENALTY_CONDITIONS);

   G_SCORE_DETAIL = StringFormat("SCORE DETAIL: TPtarget=%.0f room=%.0f | %s",
                                 G_SCORE_TP_TARGET,
                                 G_SCORE_ROOM_POINTS,
                                 detail);

   string signature = G_SCORE_STATUS + "|" + G_SCORE_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintMarketOnChange && signature != G_SCORE_LAST_SIGNATURE)
   {
      if(G_SCORE_DECISION != SCORE_DECISION_NONE || G_SCORE_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 SCORE] %s | %s | opp=%s %s %s | source=%s",
                     G_SCORE_STATUS,
                     G_SCORE_DETAIL,
                     OpportunityGradeToString(G_OPP_GRADE),
                     OpportunityDirToString(G_OPP_DIR),
                     OpportunityTypeToString(G_OPP_TYPE),
                     source);
      }
      G_SCORE_LAST_SIGNATURE = signature;
   }

   if(G_ENV_READY)
      SetStatus("CORE + ENV + MODE + MARKET + SCANNER + SCORE READY: first entry only in Phase 21.3", "SignalScoreEngine");
}
