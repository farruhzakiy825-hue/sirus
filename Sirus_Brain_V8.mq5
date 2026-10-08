//+------------------------------------------------------------------+
//|                                            Sirus_Brain_V8.mq5    |
//|                     SIRUS BY ZAKIY - XAUUSD grid basket EA       |
//|                                              v31.68              |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#property copyright "SIRUS BY ZAKIY | CEO Farruh Zakiy"
#property link      "Telegram: @farruh_zakiy"
#property version   "31.68"
#property description "SIRUS BY ZAKIY"
#property description "CEO Farruh Zakiy"
#property description "Telegram @farruh_zakiy"
#property description "Premium XAUUSD Live EA"

// The EA is split into parts under the Sirus/ folder (next to this file). The compiler pastes each
// #include in place, in this order, so the result is the same single program as before - the order
// is what keeps every name declared before it is used. Keep the Sirus/ folder beside this file.

#include "Sirus/00_Defines.mqh"   // Constants (#define), enums and forward declarations
#include "Sirus/01_Inputs.mqh"   // Input parameters (settings window)
#include "Sirus/02_Globals.mqh"   // Global state variables
#include "Sirus/03_Core_Utils.mqh"   // Text helpers, environment checks, indicator handles
#include "Sirus/04_Trend_Structure.mqh"   // Trend confidence, VWAP, momentum, local structure
#include "Sirus/05_Situation_Candles.mqh"   // Grid addition quality, situations, candle reading, sweeps
#include "Sirus/06_Basket_Session.mqh"   // Pattern memory, basket age, scale-in, basket health, sessions
#include "Sirus/07_Detectors.mqh"   // Noise/path density, opportunity detectors
#include "Sirus/08_Scanner_Score.mqh"   // Opportunity scanner and signal score engine
#include "Sirus/09_Redirect_Queue_Pack2.mqh"   // Direction redirect, temp blocks, signal queue, Pack2/Pack3
#include "Sirus/10_Basket_Stats_Context.mqh"   // Lot caps, basket stats, market context readers
#include "Sirus/11_Expectancy_MTF_News.mqh"   // Expectancy, ladder shape, MTF/DXY/order flow, calendar
#include "Sirus/12_Exits_Trailing.mqh"   // Warnings, audits, basket close, exits, cashback trailing
#include "Sirus/13_Grid_Engine.mqh"   // Grid intelligence, grid lot, GridCanOpen, grid engine
#include "Sirus/14_Risk_Gates_Entry.mqh"   // Risk governor, gates, first entry engine
#include "Sirus/15_Legacy_Packs.mqh"   // VPS validation, legacy/deep/RC packs, client safety
#include "Sirus/16_Dashboard_Core.mqh"   // Client dashboard, CoreUpdate pipeline, dashboard drawing
#include "Sirus/17_Candle_Engine.mqh"    // Market Brain A0: candle intent, pressure, acceleration, impulse
#include "Sirus/18_Event_Engine.mqh"     // Market Brain A: liquidity pools and market events, every TF
#include "Sirus/19_Zone_Role_Engine.mqh" // Market Brain B: a zone's role from its history, not from price
#include "Sirus/20_Market_Brain.mqh"     // Market Brain C: bias states, dealing range, draw on liquidity, thesis
#include "Sirus/20a_Liquidity_Map.mqh"   // Plan stage 3: one liquidity map M5..H4 + PDH/PDL, status, multi-TF sweep, champion
#include "Sirus/20b_Structure_Lock.mqh"  // Plan stage 1: structure memory, MSS quality, direction lock, reversal maturity
#include "Sirus/20c_Location_Exhaustion.mqh" // Plan stage 2: entry location, late-entry guard, exhaustion pressure, counter-trend tax
#include "Sirus/20d_Micro_Reentry.mqh"   // Plan stage 4: who controls now, micro turn type, re-entry intelligence, second chance
#include "Sirus/20e_Cost_Edge.mqh"       // Plan stage 6: spread memory per hour, net edge (cashback), broker reality
#include "Sirus/21_Direction_Veto.mqh"   // Market Brain D: hard vetoes built on events and zone roles
#include "Sirus/22_Memory.mqh"           // Market Brain H: Entry DNA and bounded evidence learning
#include "Sirus/23_Entry_Engine.mqh"     // Market Brain E+F: entry location, timing, quality and the judge
#include "Sirus/24_Position_Brain.mqh"   // Market Brain G: smart grid, thesis monitor, break-even exit
#include "Sirus/25_Visual_Design.mqh"    // Watermark and the Sirus panel (card dashboard)
#include "Sirus/26_Measure.mqh"          // Stage 12: profiler + shadow ledger
#include "Sirus/90_Reason_Code.mqh"      // Reason Code (always last): why every order was opened (journal + CSV)

//==================================================================//
//  MT5 EVENTS
//==================================================================//
int OnInit()
{
   ScenarioRestore();

   Print("[SIRUS BY ZAKIY | CEO Farruh Zakiy | Telegram @farruh_zakiy]");

   // FIX(input-validation): the EA used to start with INIT_SUCCEEDED no matter what the user
   // typed into the inputs. A zero/negative StartLot, a LotMultiplier <= 0, MaxOrders < 1, a
   // bad MagicNumber, etc. would silently corrupt the lot/grid math downstream. This is the
   // cheapest, safest place to catch it: refuse to load with a clear, single reason so the
   // problem is obvious on the chart instead of surfacing later as strange trades. These are
   // pure config sanity checks - they never touch the market.
   {
      string cfg_err = "";

      if(StartLot <= 0.0)
         cfg_err = StringFormat("StartLot must be > 0 (got %.4f)", StartLot);
      else if(MaxLot > 0.0 && MaxLot < StartLot)
         cfg_err = StringFormat("MaxLot (%.4f) is smaller than StartLot (%.4f)", MaxLot, StartLot);
      else if(UseGridRecovery && LotMultiplier <= 0.0)
         cfg_err = StringFormat("LotMultiplier must be > 0 when grid recovery is on (got %.4f)", LotMultiplier);
      else if(UseGridRecovery && MaxOrders < 1)
         cfg_err = StringFormat("MaxOrders must be >= 1 (got %d)", MaxOrders);
      else if(UseGridRecovery && GridDistancePoints <= 0)
         cfg_err = StringFormat("GridDistancePoints must be > 0 (got %d)", GridDistancePoints);
      else if(MagicNumber <= 0)
         cfg_err = StringFormat("MagicNumber must be a positive number (got %I64d)", MagicNumber);
      else if(CoreTimerSeconds < 0)
         cfg_err = StringFormat("CoreTimerSeconds cannot be negative (got %d)", CoreTimerSeconds);
      // FIX(deviation-validation): OrderSendDeviationPoints is a plain (signed) int but is handed
      // straight to CTrade::SetDeviationInPoints(), which takes an unsigned ulong. A negative value
      // here was never caught, and would silently wrap to a huge unsigned deviation - effectively
      // disabling slippage protection on every order this EA sends, with no warning at init time.
      else if(OrderSendDeviationPoints < 0)
         cfg_err = StringFormat("OrderSendDeviationPoints cannot be negative (got %d)", OrderSendDeviationPoints);

      if(StringLen(cfg_err) > 0)
      {
         PrintFormat("[SIRUS INIT ABORT] invalid input configuration: %s. EA will not load - fix the input and re-attach.", cfg_err);
         Comment("SIRUS: INIT ABORTED\n" + cfg_err + "\nFix this input and re-attach the EA.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   G_INIT_LOCAL       = TimeLocal();
   G_INIT_SERVER      = TimeCurrent();
   G_LAST_TICK_LOCAL  = 0;
   G_LAST_TIMER_LOCAL = TimeLocal();
   G_LAST_HEARTBEAT   = 0;
   G_LAST_DASHBOARD   = 0;
   G_LAST_BAR_TIME    = 0;
   G_TICK_COUNT       = 0;
   G_TIMER_COUNT      = 0;
   G_UPDATE_COUNT     = 0;
   // FIX(reinit-bar-rewind): G_BARS_SEEN is NOT zeroed here any more. An input change or timeframe switch
   // re-runs OnInit without unloading the EA, so globals and function statics keep their values - and
   // dozens of per-bar caches and "every N bars" timers (e.g. the learning-record save) are keyed to this
   // counter. Rewinding it to 0 left those keys in the future: caches could return the previous session's
   // reading, and the periodic save stalled until the counter climbed past its old value. On a fresh
   // load it is 0 from its declaration anyway.
   G_LAST_WARNING     = "none";
   G_ENV_LAST_SIGNATURE = "";
   G_MODE_LAST_SIGNATURE = "";
   G_ACTIVE_MODE = ResolveDefaultAutoMode();
   G_PREVIOUS_MODE = G_ACTIVE_MODE;
   G_MODE_CANDIDATE = G_ACTIVE_MODE;
   G_MODE_LAST_SWITCH_BAR = 0;
   G_MODE_LAST_SWITCH_TIME = 0;
   G_MODE_EVAL_BAR = -1;
   G_MODE_STATUS = "MODE: initializing";
   G_MODE_REASON = "initial mode";
   G_MARKET_STATE = MARKET_UNKNOWN;
   G_PREVIOUS_MARKET_STATE = MARKET_UNKNOWN;
   G_MARKET_STATUS = "MARKET: initializing";
   G_MARKET_REASON = "initial market state";
   G_MARKET_LAST_SIGNATURE = "";
   G_MARKET_EVAL_BAR = -1;
   G_TREND_DETAIL = "TREND: initializing";
   G_RANGE_DETAIL = "RANGE: initializing";
   G_IMPULSE_DETAIL = "IMPULSE: initializing";
   G_EXHAUSTION_DETAIL = "EXHAUSTION: initializing";
   G_OPP_DIR = OPP_DIR_NONE;
   G_OPP_GRADE = OPP_GRADE_NONE;
   G_OPP_TYPE = OPP_TYPE_NONE;
   G_OPP_STATUS = "OPPORTUNITY: initializing";
   G_OPP_REASON = "initial opportunity";
   G_OPP_DETAIL = "OPPORTUNITY DETAIL: initializing";
   G_OPP_LAST_SIGNATURE = "";
   G_OPP_SCORE = 0;
   G_OPP_EVAL_BAR = -1;
   G_OPP_IS_MICRO = false;
   G_SCORE_DECISION = SCORE_DECISION_NONE;
   G_SCORE_STATUS = "SCORE: initializing";
   G_SCORE_DETAIL = "SCORE DETAIL: initializing";
   G_SCORE_LAST_SIGNATURE = "";
   G_SCORE_BASE = 0;
   G_SCORE_BONUS = 0;
   G_SCORE_PENALTY = 0;
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
   G_LAST_ENTRY_TIME = 0;
   G_LAST_ENTRY_BAR = -100000;
   G_LAST_ENTRY_TICKET = 0;
   G_ENTRY_ATTEMPTS = 0;
   G_ENTRY_SUCCESSES = 0;
   G_ENTRY_FAILS = 0;
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
   G_QUEUE_ACTIVE = false;
   G_QUEUE_REPLAYED = false;
   G_QUEUE_SAVED_BAR = -100000;
   G_QUEUE_SAVED_TIME = 0;
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
   G_QUEUE_SAVED_COUNT = 0;
   G_QUEUE_REPLAY_COUNT = 0;
   G_QUEUE_EXPIRED_COUNT = 0;
   G_BLOCK_STATUS = "BLOCK: initializing";
   G_BLOCK_REASON = "initial block";
   G_BLOCK_DETAIL = "BLOCK DETAIL: initializing";
   G_BLOCK_LAST_SIGNATURE = "";
   G_BLOCK_TYPE = TEMP_BLOCK_NONE;
   G_BLOCK_ACTIVE = false;
   G_BLOCK_EXPIRED = false;
   G_BLOCK_JUST_EXPIRED = false;
   G_BLOCK_START_BAR = -100000;
   G_BLOCK_START_TIME = 0;
   G_BLOCK_MAX_BARS = 0;
   G_BLOCK_EXPIRED_COUNT = 0;
   G_BLOCK_CLEARED_COUNT = 0;
   G_BLOCK_SOURCE = "";
   G_GRID_STATUS = "GRID: initializing";
   G_GRID_REASON = "initial grid";
   G_GRID_DETAIL = "GRID DETAIL: initializing";
   G_GRID_LAST_SIGNATURE = "";
   G_LAST_GRID_TIME = 0;
   G_LAST_GRID_BAR = -100000;
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
   G_POST_LOSS_COOLDOWN_UNTIL = 0;
   G_RISK_BLOCK_COUNT = 0;
   G_RISK_CLOSE_COUNT = 0;
   G_PREV_BASKET_ORDERS = 0;
   G_PREV_BASKET_PROFIT = 0.0;
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
   G_VPS_STATUS = "VPS: initializing";
   G_VPS_REASON = "initial VPS validation";
   G_VPS_DETAIL = "VPS DETAIL: initializing";
   G_VPS_NO_TRADE_REASON = "NO TRADE: initializing";
   G_VPS_BROKER_DETAIL = "BROKER: initializing";
   G_VPS_LAST_SIGNATURE = "";
   G_VPS_LAST_CHECK = 0;
   G_VPS_LAST_AUDIT = 0;
   G_VPS_LAST_BROKER_PRINT = 0;
   G_VPS_TICK_WINDOW_START = 0;
   G_VPS_TICK_WINDOW_COUNT = 0;
   G_VPS_TICKS_PER_MINUTE = 0;
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
   G_BASKET_TRAIL_ACTIVE = false;
   G_BASKET_TRAIL_PEAK = 0.0;
   G_BASKET_TRAIL_LOCK = 0.0;
   G_BASKET_BE_ACTIVE = false;
   G_PACK2_DYNAMIC_TP = 0.0;
   G_PACK2_DYNAMIC_GRID = 0.0;
   G_PACK2_TRAIL_CLOSES = 0;
   G_PACK2_EVENT_COUNT = 0;
   G_AFTERSHOCK_UNTIL = 0;

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
   G_PACK3_LAST_DEAL_SCAN = 0;
   G_PACK3_LAST_AUDIT_PRINT = 0;
   G_PACK3_EVENT_COUNT = 0;
   G_DEALS_TOTAL = 0;
   G_DEALS_WINS = 0;
   G_DEALS_LOSSES = 0;
   G_DEALS_NET_PROFIT = 0.0;
   G_DEALS_GROSS_PROFIT = 0.0;
   G_DEALS_GROSS_LOSS = 0.0;
   G_DEALS_WINRATE = 0.0;
   G_BROKER_EFFECTIVE_STOP = 0.0;
   G_RC_STATUS = "RC: initializing";
   G_RC_REASON = "initial RC";
   G_RC_DETAIL = "RC DETAIL: initializing";
   G_RC_LAST_SIGNATURE = "";
   G_RC_READY = false;
   G_RC_CRITICAL_BLOCK = false;
   G_RC_ENTRY_BLOCK = false;
   G_RC_GRID_BLOCK = false;
   G_RC_EVENT_COUNT = 0;

   G_P4M_STATUS = "P4M: initializing";
   G_P4M_REASON = "initial P4M";
   G_P4M_DETAIL = "P4M DETAIL: initializing";
   G_P4M_LAST_SIGNATURE = "";
   G_P4M_VALID = true;
   G_P4M_HARD_BLOCK = false;
   G_P4M_ENTRY_BLOCK = false;
   G_P4M_GRID_BLOCK = false;
   G_P4M_LICENSE_OK = true;
   G_P4M_SYMBOL_OK = true;
   G_P4M_SPREAD_OK = true;
   G_P4M_EXPIRE_TIME = 0;
   G_P4M_EVENT_COUNT = 0;
   G_P4L_STATUS = "P4L: initializing";
   G_P4L_REASON = "initial P4L";
   G_P4L_DETAIL = "P4L DETAIL: initializing";
   G_P4L_LAST_SIGNATURE = "";
   G_P4L_VALID = true;
   G_P4L_ENTRY_BLOCK = false;
   G_P4L_GRID_BLOCK = false;
   G_P4L_FIRST_CAP = 0.0;
   G_P4L_GRID_CAP = 0.0;
   G_P4L_MAX_ORDERS = 0;
   G_P4L_MAX_DD = 0.0;
   G_P4L_LAST_ADJUSTED_LOT = 0.0;
   G_P4L_EVENT_COUNT = 0;
   G_PV_STATUS = "PV: initializing";
   G_PV_DETAIL = "PV DETAIL: initializing";
   G_PV_LAST_SIGNATURE = "";
   G_PV_LAST_REFRESH = 0;
   G_PV_EVENT_COUNT = 0;
   G_PV_CLEAN_STATUS = "PV CLEAN: initializing";
   G_PV_CLEAN_DETAIL = "PV CLEAN DETAIL: initializing";
   G_PV_LAST_CLEANUP = 0;
   G_PV_OBJECT_COUNT = 0;
   G_PV_CLEANED_OBJECTS = 0;
   G_PV_CLEAN_EVENT_COUNT = 0;
   G_RCB_STATUS = "RCB: initializing";
   G_RCB_REASON = "initial RCB";
   G_RCB_DETAIL = "RCB DETAIL: initializing";
   G_RCB_LAST_SIGNATURE = "";
   G_RCB_VALID = true;
   G_RCB_ENTRY_BLOCK = false;
   G_RCB_GRID_BLOCK = false;
   G_RCB_MAX_FIRST_LOT = 0.0;
   G_RCB_MAX_ORDERS = 0;
   G_RCB_MAX_BASKET_SL = 0.0;
   G_RCB_MAX_SPREAD = 0;
   G_RCB_WARNINGS = 0;
   G_RCB_EVENT_COUNT = 0;
   G_WCP_STATUS = "WCP: initializing";
   G_WCP_DETAIL = "WCP DETAIL: initializing";
   G_WCP_LAST_SIGNATURE = "";
   G_WCP_EVENT_COUNT = 0;
   G_FSA_STATUS = "FSA: initializing";
   G_FSA_REASON = "initial FSA";
   G_FSA_DETAIL = "FSA DETAIL: initializing";
   G_FSA_LEGACY_DETAIL = "FSA LEGACY: initializing";
   G_FSA_LAST_SIGNATURE = "";
   G_FSA_READY = false;
   G_FSA_ENTRY_BLOCK = false;
   G_FSA_GRID_BLOCK = false;
   G_FSA_SCORE = 0;
   G_FSA_PASSED = 0;
   G_FSA_TOTAL = 0;
   G_FSA_WARNINGS = 0;
   G_FSA_EVENT_COUNT = 0;
   G_RLS_STATUS = "RLS: initializing";
   G_RLS_REASON = "initial RLS";
   G_RLS_DETAIL = "RLS DETAIL: initializing";
   G_RLS_PRESET_DETAIL = "RLS PRESET: initializing";
   G_RLS_LAST_SIGNATURE = "";
   G_RLS_READY = false;
   G_RLS_ENTRY_BLOCK = false;
   G_RLS_GRID_BLOCK = false;
   G_RLS_WARNINGS = 0;
   G_RLS_EVENT_COUNT = 0;
   G_DLP_STATUS = "DLP: initializing";
   G_DLP_REASON = "initial DLP";
   G_DLP_DETAIL = "DLP DETAIL: initializing";
   G_DLP_LAST_SIGNATURE = "";
   G_DLP_APPLIED = false;
   G_DLP_ENTRY_BLOCK = false;
   G_DLP_GRID_BLOCK = false;
   G_DLP_HTF_DIR = 0;
   G_DLP_STRUCT_DIR = 0;
   G_DLP_ZONE_DIR = 0;
   G_DLP_ALIGNMENT_SCORE = 0;
   G_DLP_BONUS = 0;
   G_DLP_PENALTY = 0;
   G_DLP_EVENT_COUNT = 0;
   G_DBOS_STATUS = "DBOS: initializing";
   G_DBOS_REASON = "initial DBOS";
   G_DBOS_DETAIL = "DBOS DETAIL: initializing";
   G_DBOS_LAST_SIGNATURE = "";
   G_DBOS_APPLIED = false;
   G_DBOS_ENTRY_BLOCK = false;
   G_DBOS_GRID_BLOCK = false;
   G_DBOS_RETEST_READY = false;
   G_DBOS_CHOCH_ACTIVE = false;
   G_DBOS_DIR = 0;
   G_DBOS_LAST_MAJOR_DIR = 0;
   G_DBOS_BONUS = 0;
   G_DBOS_PENALTY = 0;
   G_DBOS_LAST_BOS_BAR = -100000;
   G_DBOS_LAST_BOS_LEVEL = 0.0;
   G_DBOS_EVENT_COUNT = 0;
   G_DTZ_STATUS = "DTZ: initializing";
   G_DTZ_REASON = "initial DTZ";
   G_DTZ_DETAIL = "DTZ DETAIL: initializing";
   G_DTZ_LAST_SIGNATURE = "";
   G_DTZ_APPLIED = false;
   G_DTZ_ENTRY_BLOCK = false;
   G_DTZ_GRID_BLOCK = false;
   G_DTZ_TOP_DANGER = false;
   G_DTZ_BOTTOM_DANGER = false;
   G_DTZ_BREAKOUT_OK = false;
   G_DTZ_TRAP_DIR = 0;
   G_DTZ_BONUS = 0;
   G_DTZ_PENALTY = 0;
   G_DTZ_EVENT_COUNT = 0;
   G_DNV_STATUS = "DNV: initializing";
   G_DNV_REASON = "initial DNV";
   G_DNV_DETAIL = "DNV DETAIL: initializing";
   G_DNV_LAST_SIGNATURE = "";
   G_DNV_APPLIED = false;
   G_DNV_ENTRY_BLOCK = false;
   G_DNV_GRID_BLOCK = false;
   G_DNV_NEWS_ACTIVE = false;
   G_DNV_SHOCK_ACTIVE = false;
   G_DNV_SPREAD_SHOCK = false;
   G_DNV_EXHAUST_RISK = false;
   G_DNV_SHOCK_DIR = 0;
   G_DNV_LAST_SHOCK_BAR = -100000;
   G_DNV_BONUS = 0;
   G_DNV_PENALTY = 0;
   G_DNV_EVENT_COUNT = 0;
   G_DET_STATUS = "DET: initializing";
   G_DET_REASON = "initial DET";
   G_DET_DETAIL = "DET DETAIL: initializing";
   G_DET_LAST_SIGNATURE = "";
   G_DET_APPLIED = false;
   G_DET_ENTRY_BLOCK = false;
   G_DET_GRID_BLOCK = false;
   G_DET_EARLY_BAR = false;
   G_DET_LATE_ENTRY = false;
   G_DET_CANDLE_CONFIRM = false;
   G_DET_REJECTION_CONFIRM = false;
   G_DET_POST_SHOCK = false;
   G_DET_BAR_AGE_SECONDS = 0;
   G_DET_BONUS = 0;
   G_DET_PENALTY = 0;
   G_DET_EVENT_COUNT = 0;
   G_DRI_STATUS = "DRI: initializing";
   G_DRI_REASON = "initial DRI";
   G_DRI_DETAIL = "DRI DETAIL: initializing";
   G_DRI_LAST_SIGNATURE = "";
   G_DRI_APPLIED = false;
   G_DRI_GRID_BLOCK = false;
   G_DRI_TREND_AGAINST = false;
   G_DRI_ZONE_DANGER = false;
   G_DRI_NEWS_SHOCK = false;
   G_DRI_ORDER_PRESSURE = false;
   G_DRI_HEALTH_SCORE = 100;
   G_DRI_DISTANCE_FACTOR = 1.0;
   G_DRI_LOT_FACTOR = 1.0;
   G_DRI_EVENT_COUNT = 0;
   G_DXB_STATUS = "DXB: initializing";
   G_DXB_REASON = "initial DXB";
   G_DXB_DETAIL = "DXB DETAIL: initializing";
   G_DXB_LAST_SIGNATURE = "";
   G_DXB_APPLIED = false;
   G_DXB_CLOSE_SENT = false;
   G_DXB_OPPOSITE_RISK = false;
   G_DXB_SHOCK_RISK = false;
   G_DXB_PEAK_GIVEBACK = false;
   G_DXB_QUICK_PROFIT = false;
   G_DXB_PEAK_POINTS = 0.0;
   G_DXB_PEAK_PROFIT = 0.0;
   G_DXB_TRACK_DIR = -1;
   G_DXB_TRACK_ORDERS = 0;
   G_DXB_EVENT_COUNT = 0;
   G_DRT_STATUS = "DRT: initializing";
   G_DRT_REASON = "initial DRT";
   G_DRT_DETAIL = "DRT DETAIL: initializing";
   G_DRT_LAST_SIGNATURE = "";
   G_DRT_APPLIED = false;
   G_DRT_ENTRY_BLOCK = false;
   G_DRT_GRID_BLOCK = false;
   G_DRT_TREND_MODE = false;
   G_DRT_RANGE_MODE = false;
   G_DRT_SHOCK_MODE = false;
   G_DRT_CHAOS_MODE = false;
   G_DRT_REGIME_DIR = 0;
   G_DRT_BONUS = 0;
   G_DRT_PENALTY = 0;
   G_DRT_GRID_FACTOR = 1.0;
   G_DRT_LOT_FACTOR = 1.0;
   G_DRT_EVENT_COUNT = 0;
   G_DCS_STATUS = "DCS: initializing";
   G_DCS_REASON = "initial DCS";
   G_DCS_DETAIL = "DCS DETAIL: initializing";
   G_DCS_LAST_SIGNATURE = "";
   G_DCS_APPLIED = false;
   G_DCS_ENTRY_BLOCK = false;
   G_DCS_GRID_BLOCK = false;
   G_DCS_LICENSE_RISK = false;
   G_DCS_SPREAD_RISK = false;
   G_DCS_DD_RISK = false;
   G_DCS_ORDER_RISK = false;
   G_DCS_RENTAL_PROFILE = false;
   G_DCS_GRID_FACTOR = 1.0;
   G_DCS_LOT_FACTOR = 1.0;
   G_DCS_WARNINGS = 0;
   G_DCS_EVENT_COUNT = 0;
   G_NIM_STATUS = "NIM: initializing";
   G_NIM_REASON = "initial NIM";
   G_NIM_DETAIL = "NIM DETAIL: initializing";
   G_NIM_DEEP_SUMMARY = "NIM DEEP: initializing";
   G_NIM_RECOMMENDATION = "NIM REC: initializing";
   G_NIM_LAST_SIGNATURE = "";
   G_NIM_READY = false;
   G_NIM_PRO_READY = false;
   G_NIM_ENTRY_BLOCK = false;
   G_NIM_GRID_BLOCK = false;
   G_NIM_CRITICAL = false;
   G_NIM_SCORE = 0;
   G_NIM_PENALTY = 0;
   G_NIM_BONUS = 0;
   G_NIM_EVENT_COUNT = 0;
   G_FPR_STATUS = "FPR: initializing";
   G_FPR_REASON = "initial FPR";
   G_FPR_DETAIL = "FPR DETAIL: initializing";
   G_FPR_PRESET = "FPR PRESET: initializing";
   G_FPR_LAST_SIGNATURE = "";
   G_FPR_READY = false;
   G_FPR_PRO_READY = false;
   G_FPR_ENTRY_BLOCK = false;
   G_FPR_GRID_BLOCK = false;
   G_FPR_WARNINGS = 0;
   G_FPR_EVENT_COUNT = 0;
   G_SGV_STATUS = "SGV: initializing";
   G_SGV_REASON = "initial SGV";
   G_SGV_DETAIL = "SGV DETAIL: initializing";
   G_SGV_PROFILE_DETAIL = "SGV PROFILE: initializing";
   G_SGV_LAST_SIGNATURE = "";
   G_SGV_READY = false;
   G_SGV_ENTRY_BLOCK = false;
   G_SGV_GRID_BLOCK = false;
   G_SGV_CLIENT_PROFILE = false;
   G_SGV_RENTAL_PROFILE = false;
   G_SGV_HIGH_HUNTER_PROFILE = false;
   G_SGV_WARNINGS = 0;
   G_SGV_CRITICAL_WARNINGS = 0;
   G_SGV_EVENT_COUNT = 0;
   G_CDP_STATUS = "CDP: initializing";
   G_CDP_BADGE = "SIRUS v31.6 PRO";
   G_CDP_HEALTH_LINE = "HEALTH: initializing";
   G_CDP_RISK_BANNER = "RISK: initializing";
   G_CDP_MODE_ADVICE = "MODE: initializing";
   G_CDP_CONTACT_LINE = "CONTACT: initializing";
   G_CDP_DETAIL = "CDP DETAIL: initializing";
   G_CDP_LAST_SIGNATURE = "";
   G_CDP_READY = false;
   G_CDP_CLIENT_VIEW = true;
   G_CDP_EVENT_COUNT = 0;
   G_DPH_STATUS = "DPH: initializing";
   G_DPH_REASON = "initial DPH";
   G_DPH_DETAIL = "DPH DETAIL: initializing";
   G_DPH_PRESET_MAP = "DPH PRESET: initializing";
   G_DPH_LAST_SIGNATURE = "";
   G_DPH_READY = false;
   G_DPH_ENTRY_BLOCK = false;
   G_DPH_GRID_BLOCK = false;
   G_DPH_CRITICAL = false;
   G_DPH_APPLIED = false;
   G_DPH_WARNINGS = 0;
   G_DPH_CRITICAL_WARNINGS = 0;
   G_DPH_GRID_FACTOR = 1.0;
   G_DPH_LOT_FACTOR = 1.0;
   G_DPH_EVENT_COUNT = 0;
   G_FBL_STATUS = "FBL: initializing";
   G_FBL_REASON = "initial FBL";
   G_FBL_DETAIL = "FBL DETAIL: initializing";
   G_FBL_ROADMAP = "FBL ROADMAP: initializing";
   G_FBL_PACKAGE = "FBL PACKAGE: initializing";
   G_FBL_LAST_SIGNATURE = "";
   G_FBL_READY = false;
   G_FBL_LOCKED = false;
   G_FBL_ENTRY_BLOCK = false;
   G_FBL_GRID_BLOCK = false;
   G_FBL_CRITICAL = false;
   G_FBL_WARNINGS = 0;
   G_FBL_CRITICAL_WARNINGS = 0;
   G_FBL_EVENT_COUNT = 0;
   G_LVP_STATUS = "LVP: initializing";
   G_LVP_REASON = "initial LVP";
   G_LVP_ENTRY_DOCTOR = "ENTRY DOCTOR: initializing";
   G_LVP_GRID_DOCTOR = "GRID DOCTOR: initializing";
   G_LVP_GATE_STACK = "GATE STACK: initializing";
   G_LVP_DETAIL = "LVP DETAIL: initializing";
   G_LVP_LAST_SIGNATURE = "";
   G_LVP_READY = false;
   G_LVP_ENTRY_READY = false;
   G_LVP_GRID_READY = false;
   G_LVP_NO_TRADE = false;
   G_LVP_READY_SCORE = 0;
   G_LVP_BLOCKERS = 0;
   G_LVP_EVENT_COUNT = 0;

   int timer_seconds = CoreTimerSeconds;
   if(timer_seconds < 1)
      timer_seconds = 1;

   // FIX(timer-result-check): EventSetTimer()'s return value used to be discarded. If it fails
   // (e.g. resource exhaustion or a leftover timer from a prior instance), OnTimer() silently never
   // fires - losing the only heartbeat this EA has while the market is closed / between ticks -
   // and the init log right below still printed "timer=%ds" as if it were running, with nothing to
   // suggest why.
   if(!EventSetTimer(timer_seconds))
      PrintFormat("[SIRUS INIT WARNING] EventSetTimer(%d) failed (error %d) - OnTimer() will not fire; the dashboard/heartbeat will only refresh on real ticks.", timer_seconds, GetLastError());

   G_TRADE.SetExpertMagicNumber(MagicNumber);
   G_TRADE.SetDeviationInPoints(OrderSendDeviationPoints);
   G_TRADE.SetTypeFillingBySymbol(_Symbol);

   PrintFormat("[SIRUS v31.6 PHASE 22.9] INIT OK | build=%s | version=%s | mode=%s | symbol=%s | chartTF=%s | coreTF=%s | timer=%ds | local=%s | current=%s",
               SirusBuildName,
               G_VERSION,
               ModeToString(SirusMode),
               _Symbol,
               TFToString((ENUM_TIMEFRAMES)_Period),
               TFToString(CoreBarTF),
               timer_seconds,
               SafeTime(G_INIT_LOCAL),
               SafeTime(G_INIT_SERVER));

   // FIX(account-mode): detected automatically - no input to set.
   {
      string acct_reason = "";
      bool acct_ok = AccountModeAllowsTrading(acct_reason);
      PrintFormat("[SIRUS ACCOUNT] mode=%s | digits=%d | point=%s | %s",
                  AccountMarginModeName(), _Digits, DoubleToString(_Point, _Digits),
                  (acct_ok ? "grid basket enabled" : "NEW TRADES DISABLED - needs a hedging account"));
   }

   Print("[SIRUS v31.6 PRO LIVE FINAL CLEAN SCREEN] IMPORTANT: Live/VPS clean screen build active: compact dashboard, XAUUSD live spread calibration, session zones off, watermark off, live validation probe enabled.");

   SetStatus("CORE INIT OK: waiting first tick/timer", "OnInit");
   BayesLoadState();
   ChainPatternRestore();   // V145: restore the chain patterns' recorded outcomes
   ScoreBandRestore();      // V153: restore per-score-band outcome history
   WarningStatsRestore();   // V155: restore how reliable each warning has been
   BlockAuditRestore();     // V157: restore blocked-trade verdicts and per-regime performance
   BasketAgeRestore();      // V160b: restore the learned typical basket lifetime
   EVRestore();             // V242: restore what the system has been earning
   OppTypeStatsRestore();   // V269: and which setups have been working
   CandleLearningRestore(); // V217: restore what each candle source learned
   PatternRecordRestore();  // V217: and how the patterns have been resolving
   FollowRecordRestore();   // V217: and whether rejections and breaks have been holding
   G_LAST_ENTRY_ALLOWED_BAR = 0;   // V180: set on the first permitted entry, so the valve does not fire before the EA has traded at all        // V30.2: restore learned detector stats
   PostLossCooldownLoad();  // V30.2: restore active cooldown if any
   SelfDefenseLoad();       // V31: restore defense mode state
   HourBayesLoad();         // V31.1: restore hour statistics
   DayOfWeekBayesLoad();    // V31.6j: restore day-of-week statistics
   if(EnablePersistentState) // V30.4: restore trailing peak (reset naturally when basket is gone)
   {
      string tp_key = StringFormat("NAVIUS_%I64d_%s_TRAILPEAK", MagicNumber, _Symbol);
      if(GlobalVariableCheck(tp_key))
         G_TRAIL_PEAK_POINTS = GlobalVariableGet(tp_key);
   }
   Print("[SIRUS V31.5 PATCH] active: V31.4 + LOT TRACE (first-entry lot pipeline transparency)");
   CoreUpdate("INIT");
   DrawDashboard();
   PrintHeartbeat();

   // V254: and do the settings work TOGETHER? The checks above validate values one at a time -
   // StartLot above zero, MaxOrders at least one - and every one of them can pass while the
   // combination is unworkable. A seven-rung ladder at 1.30x on a small account is made of valid
   // numbers and cannot be paid for; the EA would find that out at rung four.
   //
   // This warns rather than refusing to start. The account may be about to be topped up, or the
   // spread may be wide because the market just opened.
   {
      string combo_err = ValidateSettingsCombination();
      if(StringLen(combo_err) > 0)
      {
         PrintFormat("[SIRUS v254 SETTINGS] %s", combo_err);
         G_LAST_WARNING = combo_err;
      }
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // V217: last chance to keep what was learned this session.
   CandleLearningSave();
   PatternRecordSave();
   FollowRecordSave();

   EventKillTimer();
   SirusReleaseATRHandles(); // V30: free cached indicator handles
   SirusReleaseSMAHandles(); // FIX(handle-leak): SMA cache was never released
   SirusReleaseRSIHandles(); // FIX(handle-leak): RSI cache was never released
   SirusReleaseADXHandles(); // FIX(handle-leak): ADX cache was never released
   Comment("");               // FIX(input-validation): clear any INIT-abort message from the chart
   DeleteDashboard();
   MBDeleteAllVisuals();   // watermark + Sirus panel
   MBShadowFlush();        // stage 12: write the buffered shadow rows
   LegacyDeleteZoneObjects();
   PremiumVisualDeleteObjects();

   // FEATURE(tp-sl-lines): remove the basket TP / trailing-SL lines when the EA stops. Unlike the
   // close markers (a permanent history trail), these show CURRENT basket state and should go.
   ObjectDelete(0, G_PREFIX + "LINE_TP");
   ObjectDelete(0, G_PREFIX + "LINE_TP_LBL");
   ObjectDelete(0, G_PREFIX + "LINE_SL");
   ObjectDelete(0, G_PREFIX + "LINE_SL_LBL");

   PrintFormat("[SIRUS v31.6 PHASE 22.9] DEINIT | reason=%d | summary=%s | next=%s | memoryMissed=%d boosts=%d repeat=%d | ticks=%I64u | timers=%I64u | bars_seen=%d | env=%s | risk=%s | dailyLoss=%.2f/%.2f%% | equityDD=%.2f%% | grid_attempts=%d success=%d fails=%d | basketOrders=%d profit=%.2f | riskBlocks=%d riskCloses=%d | entry_attempts=%d success=%d fails=%d | logSnapshots=%d events=%d | legacyEvents=%d pack2Events=%d pack3Events=%d rcEvents=%d pvEvents=%d pvClean=%d rcbEvents=%d wcpEvents=%d fsaEvents=%d rlsEvents=%d dlpEvents=%d dbosEvents=%d dtzEvents=%d dnvEvents=%d detEvents=%d driEvents=%d dxbEvents=%d drtEvents=%d dcsEvents=%d nimEvents=%d fprEvents=%d sgvEvents=%d cdpEvents=%d dphEvents=%d fblEvents=%d lvpEvents=%d | last_status=%s",
               reason,
               G_PREMIUM_SUMMARY,
               G_NEXT_ACTION,
               G_MEMORY_TOTAL_MISSED,
               G_MEMORY_BOOST_COUNT,
               G_MEMORY_REPEAT_COUNT,
               G_TICK_COUNT,
               G_TIMER_COUNT,
               G_BARS_SEEN,
               G_ENV_STATUS,
               G_RISK_STATUS,
               G_RISK_DAILY_LOSS_MONEY,
               G_RISK_DAILY_LOSS_PCT,
               G_RISK_EQUITY_DD_PCT,
               G_GRID_ATTEMPTS,
               G_GRID_SUCCESSES,
               G_GRID_FAILS,
               G_BASKET_ORDERS,
               G_BASKET_PROFIT,
               G_RISK_BLOCK_COUNT,
               G_RISK_CLOSE_COUNT,
               G_ENTRY_ATTEMPTS,
               G_ENTRY_SUCCESSES,
               G_ENTRY_FAILS,
               G_LOG_SNAPSHOT_COUNT,
               G_LOG_EVENT_COUNT,
               G_LEGACY_EVENT_COUNT,
               G_PACK2_EVENT_COUNT,
               G_PACK3_EVENT_COUNT,
               G_RC_EVENT_COUNT,
               G_PV_EVENT_COUNT,
               G_PV_CLEAN_EVENT_COUNT,
               G_RCB_EVENT_COUNT,
               G_WCP_EVENT_COUNT,
               G_FSA_EVENT_COUNT,
               G_RLS_EVENT_COUNT,
               G_DLP_EVENT_COUNT,
               G_DBOS_EVENT_COUNT,
               G_DTZ_EVENT_COUNT,
               G_DNV_EVENT_COUNT,
               G_DET_EVENT_COUNT,
               G_DRI_EVENT_COUNT,
               G_DXB_EVENT_COUNT,
               G_DRT_EVENT_COUNT,
               G_DCS_EVENT_COUNT,
               G_NIM_EVENT_COUNT,
               G_FPR_EVENT_COUNT,
               G_SGV_EVENT_COUNT,
               G_CDP_EVENT_COUNT,
               G_DPH_EVENT_COUNT,
               G_FBL_EVENT_COUNT,
               G_LVP_EVENT_COUNT,
               G_LAST_STATUS);
}

// ----------------------------------------------------------------------------
// V228b: the health check lives here, below every module it inspects. It calls into
// roughly thirty of them, and placing it earlier meant thirty forward declarations to
// maintain - each one a place for a signature to drift out of step with its
// definition. Nothing calls this except OnTick and the dashboard, both of which are
// below it.
// ----------------------------------------------------------------------------
void MHAdd(const string name, const int state, const string note)
{
   if(G_MH_COUNT >= MODHEALTH_MAX)
      return;
   G_MH_NAME[G_MH_COUNT]  = name;
   G_MH_STATE[G_MH_COUNT] = state;
   G_MH_NOTE[G_MH_COUNT]  = note;
   G_MH_COUNT++;
}

// Runs every module and records whether it answered. Once per bar - this calls into
// most of the analysis layer and there is no reason to do it per tick.
void ModuleHealthUpdate()
{
   if(!EnableModuleHealth)
      return;

   // V228d: the once-per-bar guard was skipping the refresh the dashboard asks for. OnTick runs
   // this first and sets the bar marker; the dashboard then calls it again a moment later and the
   // guard sent it straight back, so on the very first draw of a new bar the count could still be
   // reading as zero. Cheap enough to run twice - it is a few reads of already-cached values - and
   // a health line that intermittently vanishes is worse than useless, because an absent number
   // looks the same as a healthy one that nobody drew.
   G_MH_BAR = G_BARS_SEEN;
   G_MH_COUNT = 0;

   int dir_probe = 1;   // direction-taking modules are asked about a buy, arbitrarily

   // --- candle layer ---------------------------------------------------------
   if(EnableCandleSequence)
   {
      int d = 0; double c = 0.0; string t = "";
      int st = CandleSequenceRead(d, c, t);
      MHAdd("candles", (StringLen(t) > 0) ? 1 : 0, CandleStateName(st));
   }

   if(EnableCandleAuthorship)
   {
      double conv = 0.0; string t = "";
      int side = CandleWickAuthorship(conv, t);
      // Silent is legitimate here - most bars have no dominant wick.
      MHAdd("wick", (side != 0 || StringLen(t) > 0) ? 1 : 0,
            (side != 0) ? StringFormat("%.0f%%", conv * 100.0) : "no wick");
   }

   if(EnableCandlePatterns)
   {
      int d = 0; double c = 0.0; string t = "";
      int pat = CandlePatternRead(d, c, t);
      // Finding no pattern is normal; being unable to read the three candles it needs is not, and
      // the two look identical from the return value alone. The candles are checked directly.
      bool pat_ok = (CandleOpen(CandleSequenceTF, 3) > 0.0 && CandleClose(CandleSequenceTF, 1) > 0.0);
      MHAdd("pattern", pat_ok ? 1 : -1, pat_ok ? CandlePatternName(pat) : "cannot read candles");
   }

   if(EnableCandleParticipation)
   {
      double part = CandleParticipation(1);
      // Exactly 1.0 means the volume read failed and it fell back to neutral.
      MHAdd("volume", (part > 0.0 && MathAbs(part - 1.0) > 0.0001) ? 1 : 0,
            StringFormat("%.1fx", part));
   }

   if(EnableCandleHTF)
   {
      double body = 0.0; string t = "";
      int ag = CandleHTFAgreement(dir_probe, body, t);
      MHAdd("htf", (StringLen(t) > 0) ? 1 : 0,
            (ag > 0 ? "agrees" : (ag < 0 ? "against" : "undecided")));
   }

   if(EnableLiveBarRead)
   {
      int d = 0; double w = 0.0; string t = "";
      int st = LiveBarRead(d, w, t);
      double prog = LiveBarProgress(CandleSequenceTF);
      // Early in a bar this correctly says nothing, so progress is what proves it ran.
      MHAdd("livebar", (prog > 0.0) ? 1 : 0,
            (st != CANDLE_STATE_NEUTRAL) ? CandleStateName(st)
                                         : StringFormat("%.0f%% formed", prog * 100.0));
   }

   if(EnableLiveBarEvolution)
   {
      int d = 0; double w = 0.0; string t = "";
      int ev = LiveBarEvolution(d, w, t);
      MHAdd("evolution", (G_LIVE_S_COUNT > 0) ? 1 : 0,
            (ev != LIVE_EVO_NONE) ? LiveEvolutionName(ev)
                                  : StringFormat("%d samples", G_LIVE_S_COUNT));
   }

   if(EnableConsecutivePressure)
   {
      int run = 0; double body = 0.0; string t = "";
      int d = ConsecutivePressureDir(run, body, t);
      bool pr_ok = (CandleHigh(ConsecutivePressureTF, 1) > 0.0);
      MHAdd("pressure", pr_ok ? 1 : -1,
            pr_ok ? ((d != 0) ? StringFormat("%d bars", run) : "no run") : "no bar data");
   }

   if(EnableSingleCandleGuard)
   {
      int scd = 0; string sct = "";
      double scs = SingleCandleDominance(scd, sct);
      bool sc_ok = (CandleHigh(SingleCandleTF, 1) > 0.0);
      MHAdd("bigbar", sc_ok ? 1 : -1,
            sc_ok ? ((scd != 0) ? StringFormat("%.0f%%", scs * 100.0) : "normal") : "no bar data");
   }

   // --- zones ----------------------------------------------------------------
   // The zone map underpins most of the rest - situations, grid placement, targets, candle location
   // - so its failure modes matter more than any single module's. Finding one side and not the other
   // is worth flagging separately: it usually means the swing cache filled from one direction only,
   // which is a real fault that "found something" would hide.
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sup = (bid > 0.0) ? ZoneMapNearestSupport(bid) : 0.0;
      double res = (bid > 0.0) ? ZoneMapNearestResistance(bid) : 0.0;

      if(sup > 0.0 && res > 0.0)
         MHAdd("zones", 1, StringFormat("%.2f-%.2f", sup, res));
      else if(sup > 0.0 || res > 0.0)
         MHAdd("zones", 0, (sup > 0.0) ? StringFormat("support only %.2f", sup)
                                       : StringFormat("resistance only %.2f", res));
      else
         MHAdd("zones", -1, "none found");
   }

   // --- structure ------------------------------------------------------------
   if(EnableLocalStructure)
   {
      LocalStructureUpdate();
      MHAdd("structure", (G_LS_STATE != LSTRUCT_NONE) ? 1 : 0,
            (G_LS_STATE != LSTRUCT_NONE) ? LocalStructureName(G_LS_STATE) : "too few swings");
   }

   if(EnableStructureMTF)
   {
      int d = 0; double w = 0.0; string t = "";
      int al = StructureAlignment(d, w, t);
      MHAdd("mtf", (al != TFALIGN_NONE) ? 1 : 0, TFAlignName(al));
   }

   if(EnableStructureBreak)
   {
      double f = 0.0, px = 0.0;
      int d = RecentStructureBreak(f, px);
      // The tracker is healthy if it is watching something, whether or not it broke.
      MHAdd("break", (G_LSB_LAST_PRICE > 0.0 || d != 0) ? 1 : 0,
            (d != 0) ? StringFormat("broke %.2f", px)
                     : (G_LSB_LAST_PRICE > 0.0 ? StringFormat("watching %.2f", G_LSB_LAST_PRICE)
                                               : "nothing to watch"));
   }

   if(EnableStructureMaturity)
   {
      string t = "";
      double m = StructureMaturity(t);
      MHAdd("maturity", (StringLen(t) > 0) ? 1 : 0,
            (StringLen(t) > 0) ? StringFormat("%.0f%%", m * 100.0) : "no structure");
   }

   if(EnableLocalSwingShape)
   {
      int steps = 0; double c = 0.0; string t = "";
      int d = LocalSwingShape(steps, c, t);
      MHAdd("swings", (d != 0) ? 1 : 0, (d != 0) ? StringFormat("%d steps", steps) : "mixed");
   }

   // --- situation and plan ---------------------------------------------------
   if(EnableSituationRead)
   {
      int d = 0; double w = 0.0; string t = "";
      int sit = ReadSituation(d, w, t);
      // A situation needs a price and a zone to exist at all. Without either, "none" means the
      // reader could not run rather than that nothing is happening.
      double sit_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      MHAdd("situation", (sit_bid > 0.0) ? 1 : -1,
            (sit_bid > 0.0) ? SituationName(sit) : "no price");
   }

   if(EnableSituationPlan && G_SITUATION != SIT_NONE)
   {
      string t = "";
      double pts = SituationTargetPoints(G_SITUATION, G_SITUATION_DIR, t);
      MHAdd("plan", (pts > 0.0) ? 1 : 0,
            (pts > 0.0) ? StringFormat("%.0f pts", pts) : "no target");
   }

   // --- entry quality --------------------------------------------------------
   if(EnableEntryBarCheck)
   {
      string t = "";
      double sev = EntryBarPlacement(dir_probe, t);
      double eb_h = CandleHigh(EntryBarTF, 0), eb_l = CandleLow(EntryBarTF, 0);
      bool eb_ok = (eb_h > 0.0 && eb_l > 0.0 && eb_h > eb_l);
      MHAdd("entrybar", eb_ok ? 1 : -1,
            eb_ok ? ((sev > 0.0) ? StringFormat("%.0f%% bad", sev * 100.0) : "clean")
                  : "cannot read the forming bar");
   }

   if(EnableSecondLevelCheck)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double first = (bid > 0.0) ? ZoneMapNearestSupport(bid) : 0.0;
      double second = (first > 0.0) ? ZoneMapNextSupportBelow(bid, first) : 0.0;
      MHAdd("2ndlevel", (first > 0.0) ? 1 : 0,
            (second > 0.0) ? StringFormat("%.2f", second) : "none behind");
   }

   // --- waiting and learning -------------------------------------------------
   if(EnableSetupArming)
   {
      // Idle is the normal state. A window of zero would mean nothing can ever be held, which is
      // the same as the engine being off while appearing to be on.
      bool arm_ok = (SetupArmZoneWaitBars > 0 && SetupArmPullbackWaitBars > 0);
      MHAdd("arming", arm_ok ? 1 : -1,
            arm_ok ? ((G_ARM_DIR != 0) ? "holding" : "idle") : "wait windows are zero");
   }

   if(EnableCandleLearning)
   {
      int with_record = 0;
      for(int src = 0; src < CSRC_COUNT; src++)
         if(CandleSourceAccuracy(src) >= 0.0) with_record++;
      // The record surviving a restart is the whole point of the learning layer, so the check is
      // whether persistence is on rather than how many sources have data yet.
      MHAdd("learning", PersistCandleLearning ? 1 : 0,
            PersistCandleLearning ? StringFormat("%d/%d rated", with_record, CSRC_COUNT)
                                  : "not persisted - resets on restart");
   }

   // V250c: the modules added since V238. Each was built from a live loss and none of them was in
   // the health count - so a session where one silently stopped working would have looked identical
   // to one where they all ran.
   if(EnableVolatilityShift)
   {
      string vsd = "";
      double vs = VolatilityShift(vsd);
      MHAdd("volshift", (vs > 0.0) ? 1 : -1, StringFormat("%.2fx baseline", vs));
   }

   if(EnableGlobalLevels)
   {
      double gl = 0.0;
      string gd = "";
      double gs = GlobalLevelAhead(dir_probe, gl, gd);
      MHAdd("global", 1, (gl > 0.0) ? StringFormat("%.2f (%.1f)", gl, gs) : "none within reach");
   }

   // V281: which lot the ladder is actually being sized from. When UseAutoLot is on, StartLot is not
   // read at all, and an affordability refusal looks the same either way.
   {
      double shown_lot = StartLot;
      if(UseAutoLot)
      {
         double al = AutoLotBase();
         if(al > 0.0) shown_lot = al;
      }
      MHAdd("lotsource", 1, StringFormat("%.2f (%s)%s", shown_lot,
            (UseAutoLot ? "auto from balance" : "StartLot"),
            (G_AFFORD_RUNG_CAP > 0 ? StringFormat(", capped at %d rungs", G_AFFORD_RUNG_CAP) : "")));
   }

   if(EnableRebateMode)
   {
      double rt = RebateTargetPoints();
      MHAdd("rebate", (rt > 0.0) ? 1 : -1,
            (rt > 0.0) ? StringFormat("target %.0f pts", rt) : "no spread reading");
   }

   if(EnableGlobalTrend)
   {
      double gts = 0.0;
      string gtd = "";
      int gtdir = GlobalTrendDirection(gts, gtd);
      MHAdd("globalTrend", 1, (gtdir != 0)
            ? StringFormat("%s %.0f%%", (gtdir > 0 ? "up" : "down"), gts * 100.0)
            : "no monthly trend");
   }

   if(EnableStreakScoring)
      MHAdd("streak", 1, (G_WIN_STREAK > 0) ? StringFormat("%d wins", G_WIN_STREAK)
            : ((G_LOSS_STREAK > 0) ? StringFormat("%d losses", G_LOSS_STREAK) : "even"));

   if(EnableDailyOpen)
   {
      int dos = 0;
      double dod = 0.0;
      double dop = DailyOpenPrice(dos, dod);
      MHAdd("dayopen", (dop > 0.0) ? 1 : -1,
            (dop > 0.0) ? StringFormat("%.2f, %.0f pts %s", dop, dod,
                          (dos > 0 ? "above" : "below")) : "not available");
   }

   if(EnableVolumeDivergence)
   {
      int vdd = 0;
      string vdt = "";
      double vdc = VolumeDivergence(vdd, vdt);
      MHAdd("volDiv", 1, (vdd != 0) ? StringFormat("%.0f%%", vdc * 100.0) : "none");
   }

   if(EnableCalendarThinness)
   {
      string ctd = "";
      double ct = CalendarThinness(ctd);
      MHAdd("thinday", 1, (ct > 0.0) ? StringFormat("%.0f%% thin", ct * 100.0) : "normal");
   }

   if(EnableScaleHierarchy)
   {
      string hsd = "";
      double hs = HigherScaleConflict(dir_probe, hsd);
      MHAdd("hierarchy", 1, (hs > 0.0) ? StringFormat("%.0f%% conflict", hs * 100.0) : "aligned");
   }

   if(EnablePreparedLevels)
      MHAdd("prepared", 1, (G_PREP_COUNT > 0)
            ? StringFormat("%d levels ready", G_PREP_COUNT) : "nothing in range");

   if(EnableProtectedZones)
   {
      ProtectedZonesRefresh();
      MHAdd("protected", (G_PZ_COUNT > 0) ? 1 : 0,
            StringFormat("%d levels held", G_PZ_COUNT));
   }

   if(EnableWickOrder)
   {
      double woc = 0.0;
      string wot = "";
      int wod = WickOrderBias(woc, wot);
      MHAdd("wickorder", 1, (wod != 0) ? StringFormat("%s first",
            (wod > 0 ? "low" : "high")) : "no clear order");
   }

   if(EnableArrivalRead)
   {
      int ard = 0;
      string art = "";
      double arq = ArrivalQuality(ard, art);
      MHAdd("arrival", 1, (ard != 0) ? StringFormat("%.0f%% efficient", arq * 100.0) : "no approach");
   }

   if(EnableCandleProgression)
   {
      int cpp = CSEQ_NONE, cpl = 0;
      string cpt = "";
      double cpc = CandleProgression(cpp, cpl, cpt);
      MHAdd("progression", 1, (cpp != CSEQ_NONE)
            ? StringFormat("%s %.0f%%", CandleProgressionName(cpp), cpc * 100.0)
            : "flat");
   }

   if(EnableLiquidityWick)
   {
      int lwd = 0;
      double lwl = 0.0;
      string lwt = "";
      double lwc = LiquidityWickSweep(lwd, lwl, lwt);
      MHAdd("liqwick", 1, (lwd != 0) ? StringFormat("%s taken %.2f",
            (lwd > 0 ? "highs" : "lows"), lwl) : "none recent");
   }

   if(EnableManipulationRead)
   {
      int md = 0;
      string mdt = "";
      double mc = RecentManipulation(md, mdt);
      MHAdd("sweepbar", 1, (mc > 0.0) ? StringFormat("%.0f%%", mc * 100.0) : "none recent");
   }

   if(EnableEQZone)
   {
      double rp = 50.0;
      int eqd = EQZoneBias(rp);
      MHAdd("eqzone", (rp != 50.0 || eqd != 0) ? 1 : 0, StringFormat("%.0f%% of range", rp));
   }

   if(EnableBandEntryGuard)
   {
      double bl = 0.0, bh = 0.0;
      string bd = "";
      MHAdd("band", ZonePriceInsideBand(bl, bh, bd) ? 1 : 0,
            (bh > bl) ? StringFormat("%.2f-%.2f", bl, bh) : "not in a band");
   }

   if(EnableSweepReversal)
   {
      double sw = 0.0;
      string sd = "";
      int sdir = SweepReversalDir(sw, sd);
      MHAdd("sweep", 1, (sdir != 0) ? StringFormat("%s %.0f%%",
            (sdir > 0 ? "up" : "down"), sw * 100.0) : "none");
   }

   if(EnableCandleProgress)
   {
      string cpd = "";
      double cps = CandleFailedProgress(dir_probe, cpd);
      bool cp_ok = (CandleClose(CandleSequenceTF, 2) > 0.0);
      MHAdd("progress", cp_ok ? 1 : -1,
            cp_ok ? ((cps > 0.0) ? StringFormat("%.0f%% stalled", cps * 100.0) : "clear")
                  : "cannot read candles");
   }

   if(EnableFailedBreakRead)
   {
      double fb_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double fb_lvl = (fb_bid > 0.0) ? ZoneMapNearestResistance(fb_bid) : 0.0;
      if(fb_lvl > 0.0)
      {
         int fb_bars = 0;
         string fbd = "";
         int fb = FailedBreakCount(fb_lvl, true, fb_bars, fbd);
         MHAdd("failbreak", 1, (fb > 0) ? fbd : "none at the level above");
      }
      else
         MHAdd("failbreak", 0, "no level to check");
   }

   if(EnableReversalContext)
   {
      double rn = 0.0, rc = 0.0;
      string rd = "";
      int rctx = MajorReversalContext(rn, rc, rd);
      MHAdd("reversal", 1,
            (rctx != REVCTX_NONE) ? StringFormat("%s %.0f%%",
               (rctx == REVCTX_BEARISH ? "bearish" : "bullish"), rc * 100.0)
            : "no pattern");
   }

   if(EnableBasketThesis && G_BASKET_ORDERS > 0)
   {
      string td = "";
      bool dead = BasketPremiseDead(td);
      MHAdd("thesis", (G_BASKET_INVALIDATION > 0.0) ? 1 : 0,
            (G_BASKET_INVALIDATION > 0.0)
               ? (dead ? "premise gone" : StringFormat("wrong past %.2f", G_BASKET_INVALIDATION))
               : "no invalidation found");
   }

   if(EnableBasketReach && G_BASKET_ORDERS > 0)
   {
      double ratr = 0.0;
      string rrd = "";
      double rr = BasketReachability(ratr, rrd);
      MHAdd("reach", 1, StringFormat("%.1f ATR", ratr));
   }

   if(EnableExpectancy)
   {
      double total = G_EV_WINS + G_EV_LOSSES;
      MHAdd("expectancy", 1, StringFormat("%.0f/%d baskets", total, ExpectancyMinSamples));
   }

   if(EnableLadderShaping && G_BASKET_ORDERS > 0)
      MHAdd("ladder", 1, StringFormat("%s, %d rungs", LadderShapeName(G_LADDER_SHAPE), LadderOrders()));

   if(EnableDeadMarketCheck)
   {
      string dmd = "";
      double dm = MarketIsDead(dmd);
      MHAdd("deadmkt", 1, (dm > 0.0) ? StringFormat("%.0f%% dead", dm * 100.0) : "active");
   }

   if(EnableLiveNewsRead)
   {
      string nwd = "";
      double nw = NewsInProgress(nwd);
      MHAdd("news", 1, (nw > 0.0) ? StringFormat("%.0f%%", nw * 100.0) : "quiet");
   }

   if(EnableLayerConflict)
   {
      string lcd = "";
      double lc = LayerContradiction(dir_probe, lcd);
      MHAdd("conflict", 1, (lc > 0.0) ? StringFormat("%.0f%% split", lc * 100.0) : "aligned");
   }

   if(EnableGridDepthLimit && G_BASKET_ORDERS > 0)
   {
      string gdr = "";
      int eff = GridEffectiveMaxOrders(gdr);
      MHAdd("griddepth", (eff > 0) ? 1 : -1,
            (eff < MaxOrders) ? StringFormat("%d of %d affordable", eff, MaxOrders)
                              : StringFormat("%d rungs", eff));
   }

   if(EnableBasketStaleness && G_BASKET_ORDERS > 0)
   {
      string std = "";
      double st = BasketStaleness(std);
      MHAdd("stale", 1, StringFormat("%.0f%%", st * 100.0));
   }

   if(EnableGridDirectionCheck && G_BASKET_ORDERS > 0)
   {
      string t = "";
      int bd = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
      double doubt = GridDirectionDoubt(bd, t);
      bool gd_ok = (G_BASKET_AVG_PRICE > 0.0);
      MHAdd("griddir", gd_ok ? 1 : -1,
            gd_ok ? StringFormat("%.0f%% doubt", doubt * 100.0) : "no basket price");
   }
}

// "18/20" plus the names of anything silent.
string ModuleHealthLine(string &silent_out)
{
   silent_out = "";
   if(!EnableModuleHealth)
      return "";

   // V226d: nothing checked yet. This happens when no tick has arrived - the health scan runs on
   // tick, and over a weekend or a broker outage there are none. Saying so is more useful than an
   // empty line, because "no modules line" and "modules not checked" look identical otherwise.
   if(G_MH_COUNT == 0)
      return "modules: waiting for a tick";

   int answering = 0;
   string silent = "";
   for(int i = 0; i < G_MH_COUNT; i++)
   {
      if(G_MH_STATE[i] == 1)
         answering++;
      else
         silent += G_MH_NAME[i] + (G_MH_STATE[i] < 0 ? "(!) " : " ");
   }
   silent_out = silent;
   return StringFormat("modules: %d/%d", answering, G_MH_COUNT);
}

void OnTick()
{
   MBProfBegin(MB_PROF_TICK);
   MBProfBegin(MB_PROF_PRE);
   // SAFETY VALVE: has an added guard been doing all the refusing? Once a bar.
   if(EnableSafetyValve) SafetyValveCheck();

   // SCENARIO: watch a reaction from start to finish and file what it did.
   if(EnableScenario) ScenarioTrack();

   G_TICK_COUNT++;
   G_LAST_TICK_LOCAL = TimeLocal();
   TickVelocityUpdate();
   LiveSampleUpdate();   // V213: record the forming bar's shape so its evolution can be read
   LocalStructureUpdate();// V223: measure the swing structure once per bar
   LocalStructureBreakUpdate();// V224: and notice the moment it is broken
   // FIX(modhealth-per-tick): this used to call ModuleHealthUpdate() here unconditionally, on
   // EVERY tick. ModuleHealthUpdate()'s own doc-comment says "once per bar... no reason to do it
   // per tick", but the V228d change removed its internal per-bar guard (to stop the dashboard
   // showing a stale zero right after a new bar) and nothing replaced the guard at the call site -
   // so it went back to running its ~20 analysis probes (including uncached multi-timeframe
   // ZoneMapNearestSupport/Resistance scans) on every single tick, exactly the per-tick cost the
   // PERF(tester-speed) comment below already fixed for the rest of the dashboard. G_MH_* is only
   // ever read by ModuleHealthLine() for the dashboard's "modules: x/y" line, and DrawDashboard()
   // already calls ModuleHealthUpdate() itself right before drawing that line (see V226d) - so
   // removing this direct call loses nothing: the health data is refreshed exactly when it's about
   // to be shown, whether that's from OnTick's own throttled DrawDashboard() call below or from
   // OnTimer's unconditional one (which is what keeps it live while the market is closed).
   DuplicateInstanceCheck(); // V31.6k: same-terminal duplicate EA detection (warning-only)
   MBProfEnd(MB_PROF_PRE);

   CoreUpdate("TICK");

   MBProfBegin(MB_PROF_SHADOW);
   MBShadowUpdate();
   MBProfEnd(MB_PROF_SHADOW);
   MBProfEnd(MB_PROF_TICK);

   // PERF(tester-speed): the dashboard and heartbeat are purely visual/logging - they do NOT
   // affect trade decisions, but drawing 40+ objects and printing on EVERY tick is the single
   // biggest reason Strategy Tester crawls (a 1-hour test taking "200 hours"). During a tester or
   // optimization run there is no chart to look at, so skip them entirely. In live trading, redraw
   // only when a new bar opens (and on the very first ticks) instead of every tick - the human eye
   // never needs a 20-times-a-second refresh. Trade logic in CoreUpdate above still runs every tick.
   bool in_tester = (bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(!in_tester)
   {
      if(G_IS_NEW_BAR || G_TICK_COUNT < 5)
      {
         DrawDashboard();
         PrintHeartbeat();
      }
   }

   // PHASE 21.3: STABLE RC BASELINE
}

void OnTimer()
{
   G_TIMER_COUNT++;
   G_LAST_TIMER_LOCAL = TimeLocal();

   CoreUpdate("TIMER");   // clock-driven protection only - see FIX(timer-trades) in CoreUpdate

   // Same rule as OnTick: no chart to draw on in a non-visual test or optimization run.
   bool in_tester = (bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(in_tester && !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   DrawDashboard();
   PrintHeartbeat();

   // PHASE 21.3: STABLE RC BASELINE
}
//+------------------------------------------------------------------+
