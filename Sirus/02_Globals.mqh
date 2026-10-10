//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 02_Globals                                      |
//| Global state variables                                           |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  GLOBAL CORE STATE
//==================================================================//
string   G_PREFIX              = "NAVIUS_V24_AUTO_GRID_SAFETY_READY_";
string   G_VERSION             = "31.68";
string   G_PHASE               = "READY";
string   G_LAST_STATUS         = "BOOTING";
string   G_LAST_EVENT          = "none";
string   G_LAST_WARNING        = "none";
string   G_CLOCK_STATUS        = "CLOCK: waiting";
string   G_BAR_STATUS          = "BAR: waiting";
string   G_TICK_STATUS         = "TICK: waiting";

datetime G_INIT_LOCAL          = 0;
datetime G_INIT_SERVER         = 0;
datetime G_LAST_TICK_LOCAL     = 0;
// V203: guard against the zone lookup calling itself. ZoneMapNearest*() consults the weighted
// "strongest nearby" search, and that search falls back to ZoneMapNearest*() when it finds nothing -
// which is a loop with no exit. It only became reachable when EnableStrongZoneOverride was turned
// on, and the result was a stack overflow before the EA saw a single tick.
bool G_ZONE_LOOKUP_BUSY = false;
datetime G_LAST_TIMER_LOCAL    = 0;
datetime G_LAST_HEARTBEAT      = 0;
datetime G_LAST_DASHBOARD      = 0;
datetime G_LAST_BAR_TIME       = 0;
bool     G_IS_NEW_BAR          = false;   // PERF: true only on the tick a new CoreBarTF bar opens

ulong    G_TICK_COUNT          = 0;
ulong    G_BASKET_CLOSED_TICK  = ULONG_MAX;   // AUDIT FIX (A6): the tick in which the EA closed a basket
bool     G_MB_JUDGE_PROBE      = false;
bool     G_MB_FAST_ACTIVE      = false;       // the entry being judged came from the Market Brain fast path
bool     G_MB_VETO_PROBE       = false;       // the veto is asked as a probe (candidate / detector check): no count, no print
string   G_INIT_SYMBOL_PREV    = "";          // the symbol of the last OnInit (globals survive a chart symbol change)
bool     G_BASKET_OUTCOME_DONE = false;       // the finished basket's learning records were written (12 / 24)
bool     G_VERBOSE             = true;        // VerboseLogs, switched off in a non-visual tester run (TesterQuietLogs) - set in OnInit
string   G_TR_SCAN             = "";          // decision trace: what the scan phase did to the decision (26d)
string   G_TR_TICK             = "";          // decision trace: what FirstEntryCanRun did to it this tick (26d)
int      G_TR_S_DEC            = 0;           // decision trace: snapshot before a step
int      G_TR_S_DIR            = 0;
int      G_TR_S_FIN            = 0;
string   G_SCORE_HB_DIR_WHY    = "";          // the last DIRECTIONAL score hard block (counter-context, blow-off, wall) - see ScoreHBDirectional
int      G_EG_SKIP_MASK        = 0;           // evidence keys that stood aside in the current entry decision (26c)
bool     G_EG_RECORD           = false;       // record skips (on inside the first-entry decision, off during candidate probes)
bool     G_EG_MKT_OK           = false;       // the market lets filters relax (no news / spike / anomaly / wide spread)
datetime G_EG_BREAK_UNTIL      = 0;           // circuit breaker: relaxed baskets went to the grid - off until
string   G_EG_BREAK_WHY        = "";
bool     G_EG_BASKET           = false;       // the open basket was entered with a filter standing aside
int      G_EG_BASKET_MAXORD    = 0;           // its largest order count so far
int      G_EG_HIST[4];                        // last such baskets: 1 = needed the grid, 0 = clean, -1 = none
int      G_EG_HIST_POS         = 0;       // AUDIT FIX: the judge-bypass probe must not move the signal-decay anchor
ulong    G_TIMER_COUNT         = 0;
ulong    G_UPDATE_COUNT        = 0;
int      G_BARS_SEEN           = 0;
int      G_LAST_SPREAD_POINTS  = -1;
bool     G_CORE_READY          = false;

CTrade   G_TRADE;

//==================================================================//
//  GLOBAL ENVIRONMENT STATE
//==================================================================//
bool     G_ENV_READY           = false;
bool     G_LOCAL_TREND_TURNING  = false;   // FEATURE(local-trend-turning): true when the fast local window disagrees with the main window (trend just flipping - treat local trend with caution)
bool     G_LOCAL_TREND_FADING   = false;   // FEATURE(local-trend-momentum): true when local ADX is dropping (trend losing steam - reversal risk, treat with caution)
bool     G_GLOBAL_TREND_FADING  = false;   // FEATURE(global-trend-momentum): true when global (D1) ADX is dropping - big-picture trend weakening
bool     G_GLOBAL_TREND_TURNING = false;   // FEATURE(global-trend-momentum): true when the fast global window disagrees with the main global read - macro trend flipping

// FEATURE(market-structure): the swing-chain reading. Refreshed once per bar by MarketStructureRead().
int      G_STRUCTURE_DIR      = 0;         // +1 = higher-high/higher-low chain, -1 = lower-high/lower-low, 0 = no clean structure (range/transition)
int      G_STRUCTURE_STEPS    = 0;         // How many of the four chain checks agreed (0-4) - the confidence behind G_STRUCTURE_DIR
string   G_STRUCTURE_DETAIL   = "";        // Human-readable summary for the dashboard/logs

// V111: the levels that define the structure, and what price has just done to them.
// A structure isn't only a direction - it has a price at which it stops being true. Knowing that
// level is what lets the EA say "buyers are in control UNTIL 4150" instead of just "bullish".
double   G_STRUCTURE_INVALIDATION = 0.0;   // Bullish: the last higher-low. Bearish: the last lower-high. Close beyond it and the structure is broken.
double   G_STRUCTURE_CONTINUATION = 0.0;   // Bullish: the last swing high. Bearish: the last swing low. Close beyond it and the structure has extended.
int      G_STRUCTURE_EVENT        = 0;     // +1 = BOS (structure just extended in its own direction), -1 = CHoCH (structure just broke - character changing), 0 = neither
string   G_STRUCTURE_EVENT_TXT    = "";    // Description of the latest event

// V112: the higher-timeframe structure and the combined context reading.
int                 G_STRUCTURE_HTF_DIR     = 0;    // Structure direction on StructureHTF
int                 G_STRUCTURE_HTF_STEPS   = 0;    // How many chain checks agreed on the HTF
ENUM_STRUCT_CONTEXT G_STRUCTURE_CONTEXT     = STRUCT_CTX_UNCLEAR;
string              G_STRUCTURE_CONTEXT_TXT = "";

// V113: the break staircase reading.
double   G_GAP_FILL_ORIGIN = 0.0;   // V125: price level the market gapped TO - lets the magnet measure partial fill progress
int      G_PENALTY_TREND_AGAINST = 0;   // V136: how much of the penalty came from "the entry fights the trend/structure" sources, so one fact is not charged six times
int      G_BONUS_TREND_ALIGN = 0;   // V134: how much of the bonus came from "trend agrees with the entry" sources, so that one fact cannot be rewarded eight times
int      G_GRID_ZONE_WAIT_BAR = -100000;   // V131: bar the grid started waiting out an opposing zone (-100000 = not waiting)
int      G_BREAK_SEQ_DIR   = 0;    // +1 = climbing through resistances, -1 = falling through supports, 0 = none/churn
int      G_BREAK_SEQ_COUNT = 0;    // How many distinct levels were broken that way
string   G_BREAK_SEQ_TXT   = "";   // Description for the dashboard/logs

// V117: the consensus verdict across all independent readings.
int      G_VERDICT_DIR    = 0;    // +1 / -1 / 0 (0 = split or not enough sources)
int      G_VERDICT_AGREE  = 0;    // How many sources agreed with G_VERDICT_DIR
int      G_VERDICT_ACTIVE = 0;    // How many sources had an opinion at all
string   G_VERDICT_TXT    = "";
string   G_ENV_STATUS          = "ENV: waiting";
string   G_ENV_BLOCK_REASON    = "none";
string   G_ENV_LAST_SIGNATURE  = "";
string   G_ENV_SYMBOL_STATUS   = "SYMBOL: waiting";
string   G_ENV_TRADE_STATUS    = "TRADE: waiting";
string   G_ENV_SPREAD_STATUS   = "SPREAD: waiting";
string   G_ENV_HISTORY_STATUS  = "HISTORY: waiting";
string   G_ENV_LOT_STATUS      = "LOT: waiting";
string   G_ENV_LEVEL_STATUS    = "LEVELS: waiting";

//==================================================================//
//  GLOBAL MODE MANAGER STATE
//==================================================================//
ENUM_SIRUS_MODE G_ACTIVE_MODE          = SIRUS_MODE_BALANCED;
ENUM_SIRUS_MODE G_PREVIOUS_MODE        = SIRUS_MODE_BALANCED;
ENUM_SIRUS_MODE G_MODE_CANDIDATE       = SIRUS_MODE_BALANCED;
string           G_MODE_STATUS          = "MODE: waiting";
string           G_MODE_REASON          = "initializing";
string           G_MODE_LAST_SIGNATURE  = "";
int              G_MODE_LAST_SWITCH_BAR = 0;
datetime         G_MODE_LAST_SWITCH_TIME= 0;
int              G_MODE_EVAL_BAR        = -1;

//==================================================================//
//  GLOBAL MARKET STATE ROUTER
//==================================================================//
ENUM_MARKET_STATE G_MARKET_STATE          = MARKET_UNKNOWN;
ENUM_MARKET_STATE G_PREVIOUS_MARKET_STATE = MARKET_UNKNOWN;
string            G_MARKET_STATUS         = "MARKET: waiting";
string            G_MARKET_REASON         = "initializing";
string            G_MARKET_LAST_SIGNATURE = "";
int               G_MARKET_EVAL_BAR       = -1;
double            G_MARKET_ATR_M1         = 0.0;
double            G_MARKET_ATR_M5         = 0.0;
double            G_MARKET_RANGE_POINTS   = 0.0;
double            G_RANGE_HIGH            = 0.0;   // FEATURE(range-breakout): last confirmed range top
double            G_RANGE_LOW             = 0.0;   // last confirmed range bottom
int               G_RANGE_VALID_BAR       = -1;    // bar index the range boundaries were last confirmed
double            G_MARKET_SIGNAL_RANGE   = 0.0;
double            G_MARKET_SIGNAL_BODY    = 0.0;
double            G_MARKET_UPPER_WICK     = 0.0;
double            G_MARKET_LOWER_WICK     = 0.0;
string            G_TREND_DETAIL          = "TREND: waiting";
string            G_RANGE_DETAIL          = "RANGE: waiting";
string            G_IMPULSE_DETAIL        = "IMPULSE: waiting";
string            G_EXHAUSTION_DETAIL     = "EXHAUSTION: waiting";

//==================================================================//
//  GLOBAL OPPORTUNITY SCANNER
//==================================================================//
ENUM_OPPORTUNITY_DIR    G_OPP_DIR             = OPP_DIR_NONE;
ENUM_OPPORTUNITY_GRADE  G_OPP_GRADE           = OPP_GRADE_NONE;
ENUM_OPPORTUNITY_TYPE   G_OPP_TYPE            = OPP_TYPE_NONE;
string                  G_OPP_STATUS          = "OPPORTUNITY: waiting";
string                  G_OPP_REASON          = "initializing";
string                  G_OPP_DETAIL          = "OPPORTUNITY DETAIL: waiting";
string                  G_OPP_LAST_SIGNATURE  = "";
int                     G_OPP_SCORE           = 0;
// V31.6z49 NEW: track the best score achieved on EACH side independently. The scanner picks
// the single highest-scoring candidate across all 47 detectors, but never recorded whether the
// LOSING side also had a strong candidate - so "BUY 7, nothing else" and "BUY 7 but SELL 6 too"
// were indistinguishable downstream, despite being completely different situations.
int                     G_OPP_BEST_BUY_SCORE  = 0;
// AUDIT FIX (A2): the best setup of each side in full - a consensus flip takes the other side's own
// type, grade and reason instead of keeping the loser's (a SELL stamped SWEEP_REJECTION passed V0
// as a "reversal" it never was). Index 0 = SELL, 1 = BUY.
ENUM_OPPORTUNITY_TYPE   G_OPP_SIDE_TYPE[2];
ENUM_OPPORTUNITY_GRADE  G_OPP_SIDE_GRADE[2];
bool                    G_OPP_SIDE_MICRO[2];
string                  G_OPP_SIDE_REASON[2];
// CONSENSUS: how many detectors spoke for each side this scan. The engine keeps the best score per
// direction and has never kept the count - so seven detectors agreeing at five lose to one outlier
// at eight, and the outlier is the entry that gets taken.
int                     G_OPP_VOICES_BUY  = 0;
int                     G_OPP_VOICES_SELL = 0;
int                     G_OPP_SUM_BUY     = 0;
int                     G_OPP_SUM_SELL    = 0;
double                  G_OPP_DIR_CLARITY = 0.0;   // how far apart the two sides were, 0..1
int                     G_OPP_BEST_SELL_SCORE = 0;
int                     G_OPP_EVAL_BAR        = -1;
double                  G_OPP_ROOM_POINTS     = 0.0;
double                  G_OPP_NEAR_LOW_DIST   = 0.0;
double                  G_OPP_NEAR_HIGH_DIST  = 0.0;
bool                    G_OPP_IS_MICRO        = false;

//==================================================================//
//  GLOBAL SIGNAL SCORE ENGINE
//==================================================================//
ENUM_SCORE_DECISION     G_SCORE_DECISION       = SCORE_DECISION_NONE;
string                  G_SCORE_STATUS         = "SCORE: waiting";
string                  G_SCORE_DETAIL         = "SCORE DETAIL: waiting";
string                  G_SCORE_LAST_SIGNATURE = "";
int                     G_SCORE_BASE           = 0;
int                     G_SCORE_BONUS          = 0;
int                     G_SCORE_PENALTY        = 0;
int                     G_ENTRY_WARNINGS       = 0;      // V155: bit flags of the cautions raised while scoring the entry being judged
int                     G_PENALTY_CONDITIONS   = 0;      // V170: penalties describing CONDITIONS rather than the setup - noise, session, spread. Three readings of one thing: whether the market is currently worth trading.
int                     G_PENALTY_QUALITY      = 0;      // V173: penalties describing what is wrong with THIS TRADE - no room, undefined level, entry into a stop pool, repeating a loss. Kept separate from conditions because a market being unremarkable and a trade being badly placed are not the same objection, and only one of them should be able to refuse on its own.
int                     G_PENALTY_RAW          = 0;      // V182: total uncapped warning weight - the entry decision uses the capped figure, position sizing uses this one
int                     G_PENALTY_IMPULSE      = 0;      // V185: the impulse family - six penalties that all say "the move is stretched or finished". Capped together so one observation cannot spend the entire quality budget.
// V214: candle readings are capped together. Eight modules now read candles - sequence shape, wick
// authorship, location, follow-through, break quality, participation, patterns, higher timeframe,
// the live bar and its evolution - and each was scoring independently, for a combined swing of
// roughly 34 points against caps of 12. Worse, several of them look at the SAME wick: a live
// rejection, its authorship and the sequence state are three readings of one event, and each was
// charging for it.
//
// One budget for all of them. The candles keep every bit of their reasoning; what they lose is the
// ability to outvote the rest of the system by sheer count.
int                     G_CANDLE_BONUS         = 0;      // candle-derived bonus, before the group cap
int                     G_CANDLE_PENALTY       = 0;      // candle-derived penalty, before the group cap
// V227: the structure readings are capped together, for the same reason the candle ones are. Five
// modules now report on structure direction - the measured shape, the swing count, timeframe
// alignment, pullback detection and the break event - and every one of them routes into the trend
// group, whose cap is 4. Together they can produce 27, which means five independent readings arrive
// with the force of one and the cap decides which of them survives rather than the market.
//
// They are also reading the same thing. A falling structure, three falling swings and lower highs on
// three timeframes are one observation described three ways, and each was charging separately.
int                     G_STRUCT_BONUS         = 0;      // structure-derived bonus, before the group cap
int                     G_STRUCT_PENALTY       = 0;      // structure-derived penalty, before the group cap
int                     G_BASKET_OPEN_SESSION  = -1;    // V228: session the basket was opened in - a handover means different participants
double                  G_BASKET_TARGET_LEVEL  = 0.0;   // V228: the price the basket was aimed at, so it can be noticed when price passes it
double                  G_BASKET_STALENESS     = 0.0;   // V228: how far the market has moved from the one this basket was built for
int                     G_BASKET_OPP_TYPE      = 0;     // V269: the setup type that opened this basket
int                     G_AFFORD_RUNG_CAP      = 0;     // V282: rungs the budget covers, 0 = full ladder fits
bool                    G_PREP_HIT_THIS_BAR    = false;  // V291: price is at a level already decided about
int                     G_GRID_MAX_EFFECTIVE   = 0;     // V228: rungs the account can actually pay for
int                     G_SITUATION            = SIT_NONE;   // V219: when the layers describe one situation, it is scored as one thing and the parts are suppressed
int                     G_SITUATION_DIR        = 0;
double                  G_GRID_DIRECTION_DOUBT = 0.0;   // V221: how far the basket's direction has drifted from what opened it
double                  G_GRID_SNAP_PRICE      = 0.0;   // V221: the level an addition is waiting for, when one was found
// V192: entry funnel counters. Two trades in twelve hours on a scalper means something is refusing
// setups, but "something" covers thirty gates across four layers - and guessing which has cost a
// day already. These count what actually happens, so the answer comes from the EA rather than from
// reading code.
int                     G_FUNNEL_SETUPS        = 0;      // opportunities the scanner found
int                     G_FUNNEL_SCORE_WAIT    = 0;      // rejected on score
int                     G_FUNNEL_HARD_BLOCK    = 0;      // refused by a hard block
int                     G_FUNNEL_GATE_BLOCK    = 0;      // refused by an entry gate (FirstEntryCanRun)
int                     G_FUNNEL_ENTRIES       = 0;      // actually opened
string                  G_FUNNEL_LAST_GATE     = "";     // which gate refused most recently
double                  G_NOISE_TP_FACTOR      = 1.0;    // V162b: target multiplier from current noise - the market sets what is reachable, not the settings
double                  G_PROJECTION_LOT_FACTOR = 1.0;   // V159b: entry-size multiplier that brings the projected ladder back inside the account's limits
bool                    G_PROJECTION_MEASURING  = false; // V170b: set while the projection asks for the lot, so the lot does not answer with the projection's own previous adjustment already applied
int                     G_LAST_ENTRY_ALLOWED_BAR = 0;    // V180: last bar on which any entry was permitted - the safety valve counts silence from here

// Zone-map swing cache. Declared here rather than beside the zone map itself because the modules
// that read it - liquidity pools, path density, market scale, zone edges - are defined earlier in
// the file, and MQL5 does not hoist variable declarations the way it hoists function ones.
double G_ZMC_HIGH_PRICE[SIRUS_ZM_CACHE_TF_COUNT][SIRUS_ZM_CACHE_MAX];
double G_ZMC_LOW_PRICE[SIRUS_ZM_CACHE_TF_COUNT][SIRUS_ZM_CACHE_MAX];
int    G_ZMC_HIGH_SHIFT[SIRUS_ZM_CACHE_TF_COUNT][SIRUS_ZM_CACHE_MAX];
int    G_ZMC_LOW_SHIFT[SIRUS_ZM_CACHE_TF_COUNT][SIRUS_ZM_CACHE_MAX];
int    G_ZMC_HIGH_COUNT[SIRUS_ZM_CACHE_TF_COUNT];
int    G_ZMC_LOW_COUNT[SIRUS_ZM_CACHE_TF_COUNT];
int    G_ZMC_CACHE_BAR = -100000;


// V174: state belonging to modules defined further down the file. MQL5 resolves FUNCTIONS ahead of
// use but not VARIABLES, and these are read by the score engine and lot engine long before the
// modules that own them appear - so their declarations belong here, beside the other engine state.
double G_SCALEIN_PENDING_LOT = 0.0;   // remaining lot still to be added, 0 = nothing pending
double G_SCALEIN_ENTRY_PRICE = 0.0;   // price the first part went in at
int    G_SCALEIN_DIR         = 0;     // direction of the pending completion
int    G_SCALEIN_BAR         = 0;     // bar the first part opened on
int    G_SCALEIN_EXTRA_ORDERS = 0;    // completions opened - these are NOT grid orders and must not advance the ladder
double G_BASKET_AGE_TYPICAL  = 0.0;  // V160b: learned typical lifetime of a WINNING basket, in core bars
int    G_BASKET_OPEN_BAR     = 0;    // V160: bar the current basket opened on - its age is the clearest sign a recovery has stalled
int      G_REGIME          = REGIME_UNKNOWN;
int      G_REGIME_CANDIDATE = REGIME_UNKNOWN;
int      G_REGIME_SINCE_BAR = 0;
int      G_REGIME_AGREE     = 0;    // consecutive bars the candidate has held
string   G_REGIME_TEXT      = "";
int                     G_SCORE_FINAL          = 0;
int                     G_SCORE_MIN_REQUIRED   = 0;
double                  G_SCORE_TP_TARGET      = 0.0;
double                  G_SCORE_ROOM_POINTS    = 0.0;
bool                    G_SCORE_IS_MICRO       = false;
string                  G_SCORE_HARD_BLOCK     = "none";

//==================================================================//
//  GLOBAL FIRST ENTRY ENGINE
//==================================================================//
string                  G_ENTRY_STATUS         = "ENTRY: waiting";
string                  G_ENTRY_REASON         = "initializing";
string                  G_ENTRY_DETAIL         = "ENTRY DETAIL: waiting";
string                  G_ENTRY_LAST_SIGNATURE = "";
datetime                G_LAST_ENTRY_TIME      = 0;
int                     G_LAST_ENTRY_BAR       = -100000;
ulong                   G_LAST_ENTRY_TICKET    = 0;
int                     G_ENTRY_ATTEMPTS       = 0;
int                     G_ENTRY_SUCCESSES      = 0;
int                     G_FRESHBAR_DEFER_COUNT  = 0;     // V30.6: how many entries were deferred by the fresh-bar gate

// --- V31 Self-Defense state ---
int                     G_SD_LOSS_STREAK        = 0;
int                     G_SD_RECOVER_WINS       = 0;
bool                    G_SD_ACTIVE             = false;
int                     G_SD_PREV_ORDERS        = 0;
double                  G_SD_PREV_PROFIT        = 0.0;
long                    G_SD_PREV_DIRECTION     = -1;     // V31.6j: basket direction, tracked for Post-SL cooldown

// --- V31.1 Hour-Bayes state ---
double                  G_HB_WINS[24];
double                  G_HB_LOSSES[24];
int                     G_HB_OPEN_HOUR          = -1;

// --- V31.1 Tick-velocity state ---
double                  G_VEL_RATE_FAST         = 0.0;
double                  G_VEL_RATE_SLOW         = 0.0;
ulong                   G_VEL_LAST_MS           = 0;
double                  G_VEL_RING_PRICE[16];
datetime                G_VEL_RING_TIME[16];
int                     G_VEL_RING_POS          = 0;
datetime                G_VEL_RING_LAST_SEC     = 0;
datetime                G_VEL_SPIKE_UNTIL       = 0;
datetime                G_VEL_GRID_UNTIL        = 0;   // grid pause: the original fixed-threshold spike rule, no budget
datetime                G_VEL_BLOCK_UNTIL       = 0;   // entry pause (capped by VelocityMaxHoldPer5Min)
datetime                G_VEL_BUDGET_START      = 0;   // start of the current 5-minute pause budget
int                     G_VEL_BUDGET_USED       = 0;   // pause seconds spent in it

// --- V31.3 Smart Fill state ---
bool                    G_SF_ACTIVE             = false;
int                     G_SF_DIR                = 0;     // +1 BUY, -1 SELL
datetime                G_SF_ARM_TIME           = 0;
double                  G_SF_ARM_BID            = 0.0;
int                     G_SF_ARM_SPREAD         = 0;
int                     G_SF_FILL_COUNT         = 0;
double                  G_SF_SAVED_POINTS       = 0.0;   // pullback tufayli tejalgan punktlar yig'indisi
string                  G_LOT_TRACE             = "";    // V31.5: oxirgi lot hisobining bosqichma-bosqich izi
int                     G_ENTRY_FAILS          = 0;
bool                    G_ENTRY_READY          = false;

//==================================================================//
//  GLOBAL MICRO SCALP LAYER
//==================================================================//
string                  G_MICRO_STATUS         = "MICRO: waiting";
string                  G_MICRO_REASON         = "initializing";
string                  G_MICRO_DETAIL         = "MICRO DETAIL: waiting";
string                  G_MICRO_LAST_SIGNATURE = "";
bool                    G_MICRO_READY          = false;
double                  G_MICRO_TP_POINTS      = 0.0;
double                  G_MICRO_LOT_FACTOR     = 0.0;

//==================================================================//
//  GLOBAL DIRECTION REDIRECT ENGINE
//==================================================================//
string                  G_REDIRECT_STATUS       = "REDIRECT: waiting";
string                  G_REDIRECT_REASON       = "initializing";
string                  G_REDIRECT_DETAIL       = "REDIRECT DETAIL: waiting";
string                  G_REDIRECT_LAST_SIGNATURE = "";
bool                    G_REDIRECT_APPLIED      = false;
int                     G_REDIRECT_ATTEMPTS     = 0;
int                     G_REDIRECT_SUCCESSES    = 0;
ENUM_OPPORTUNITY_DIR    G_REDIRECT_FROM_DIR     = OPP_DIR_NONE;
ENUM_OPPORTUNITY_DIR    G_REDIRECT_TO_DIR       = OPP_DIR_NONE;
ENUM_OPPORTUNITY_TYPE   G_REDIRECT_TYPE         = OPP_TYPE_NONE;
int                     G_REDIRECT_SCORE        = 0;

//==================================================================//
//  GLOBAL SIGNAL QUEUE ENGINE
//==================================================================//
string                  G_QUEUE_STATUS          = "QUEUE: waiting";
string                  G_QUEUE_REASON          = "initializing";
string                  G_QUEUE_DETAIL          = "QUEUE DETAIL: waiting";
string                  G_QUEUE_LAST_SIGNATURE  = "";
bool                    G_QUEUE_ACTIVE          = false;
bool                    G_QUEUE_REPLAYED        = false;
int                     G_QUEUE_SAVED_BAR       = -100000;
datetime                G_QUEUE_SAVED_TIME      = 0;
ENUM_OPPORTUNITY_DIR    G_QUEUE_DIR             = OPP_DIR_NONE;
ENUM_OPPORTUNITY_GRADE  G_QUEUE_GRADE           = OPP_GRADE_NONE;
ENUM_OPPORTUNITY_TYPE   G_QUEUE_TYPE            = OPP_TYPE_NONE;
ENUM_SCORE_DECISION     G_QUEUE_DECISION        = SCORE_DECISION_NONE;
ENUM_MARKET_STATE       G_QUEUE_MARKET_STATE    = MARKET_UNKNOWN;
int                     G_QUEUE_OPP_SCORE       = 0;
int                     G_QUEUE_SCORE_FINAL     = 0;
int                     G_QUEUE_SCORE_MIN       = 0;
ENUM_SIRUS_MODE        G_QUEUE_MODE            = SIRUS_MODE_BALANCED;   // V249fix(auto-mode): the mode the queued signal was authorised under
bool                    G_QUEUE_IS_MICRO        = false;
double                  G_QUEUE_TP_TARGET       = 0.0;
double                  G_QUEUE_ROOM_POINTS     = 0.0;
string                  G_QUEUE_OPP_REASON      = "";
string                  G_QUEUE_SCORE_DETAIL    = "";
int                     G_QUEUE_SAVED_COUNT     = 0;
int                     G_QUEUE_REPLAY_COUNT    = 0;
int                     G_QUEUE_EXPIRED_COUNT   = 0;

//==================================================================//
//  GLOBAL BLOCK EXPIRY ENGINE
//==================================================================//
string                  G_BLOCK_STATUS          = "BLOCK: waiting";
string                  G_BLOCK_REASON          = "initializing";
string                  G_BLOCK_DETAIL          = "BLOCK DETAIL: waiting";
string                  G_BLOCK_LAST_SIGNATURE  = "";
ENUM_TEMP_BLOCK_TYPE    G_BLOCK_TYPE            = TEMP_BLOCK_NONE;
bool                    G_BLOCK_ACTIVE          = false;
bool                    G_BLOCK_EXPIRED         = false;
bool                    G_BLOCK_JUST_EXPIRED    = false;
int                     G_BLOCK_START_BAR       = -100000;
ENUM_OPPORTUNITY_DIR    G_BLOCK_DIR             = OPP_DIR_NONE;   // AUDIT FIX: the side the temp block was waiting on
datetime                G_BLOCK_START_TIME      = 0;
int                     G_BLOCK_MAX_BARS        = 0;
int                     G_BLOCK_EXPIRED_COUNT   = 0;
int                     G_BLOCK_CLEARED_COUNT   = 0;
string                  G_BLOCK_SOURCE          = "";

//==================================================================//
//  GLOBAL GRID / RECOVERY ENGINE
//==================================================================//
string                  G_GRID_STATUS           = "GRID: waiting";
string                  G_GRID_REASON           = "initializing";
string                  G_GRID_DETAIL           = "GRID DETAIL: waiting";
string                  G_GRID_LAST_SIGNATURE   = "";
datetime                G_LAST_GRID_TIME        = 0;
int                     G_LAST_GRID_BAR         = -100000;
int                     G_GRID_ATTEMPTS         = 0;
#define SIRUS_DD_HISTORY_SIZE 16
double                  G_BASKET_DD_HISTORY[SIRUS_DD_HISTORY_SIZE];
int                     G_BASKET_DD_HISTORY_COUNT = 0;
int                     G_BASKET_DD_HISTORY_BAR   = -1;
double                  G_BASKET_LAST_GRID_PRICE = 0.0;   // V31.6z20 NEW: price of the most recent grid addition, for adverse-streak tracking
int                     G_BASKET_ADVERSE_STREAK  = 0;     // consecutive grid additions with NO intervening recovery - the basket's own track record
int                     G_LAST_GAP_BAR           = -1;    // V31.6z25 NEW: bar index when a significant gap was last detected, for extended post-gap caution
// FEATURE(gap-fill-magnet): remember a large unfilled gap so we can discourage entries that fight
// the pull back toward it. G_GAP_FILL_LEVEL is the price the gap opened AWAY from (the level the
// market tends to return to); G_GAP_FILL_DIR is the direction price is pulled to fill it
// (+1 = pulled UP toward a gap above, -1 = pulled DOWN toward a gap below); 0 = no active gap.
double                  G_GAP_FILL_LEVEL         = 0.0;
int                     G_GAP_FILL_DIR           = 0;
int                     G_GAP_FILL_BAR           = 0;      // V178: bar the gap opened on - a gap that never fills must not block one direction indefinitely
datetime                G_GAP_FILL_TIME          = 0;
int                     G_SEE_PERSIST_BARS       = 0;     // V31.6z41 NEW: Smart Early Exit persistence counter
int                     G_SEE_PERSIST_DIR        = 0;
int                     G_SEE_PERSIST_LAST_BAR   = -1;    // FIX(see-persist-counts-ticks): the bar the counter last advanced on
bool                    G_BASKET_CLOSE_PENDING   = false; // FIX(close-remnant-becomes-new-basket): a basket close left positions behind - no grid additions until it is flat
double                  G_LAST_DD_WARNING_LEVEL  = 0.0;   // V31.6z45 NEW: tracks highest DD warning threshold already notified, avoids repeat spam
int                     G_GRID_SUCCESSES        = 0;
int                     G_GRID_FAILS            = 0;
int                     G_BASKET_ORDERS         = 0;
double                  G_BASKET_VOLUME         = 0.0;
double                  G_BASKET_AVG_PRICE      = 0.0;
double                  G_BASKET_PROFIT         = 0.0;
double                  G_BASKET_POINTS         = 0.0;
double                  G_BASKET_DD_PERCENT     = 0.0;
long                    G_BASKET_DIRECTION      = -1;
double                  G_NEXT_GRID_PRICE       = 0.0;
double                  G_NEXT_GRID_DISTANCE    = 0.0;
double                  G_NEXT_GRID_LOT         = 0.0;

//==================================================================//
//  GLOBAL RISK ENGINE
//==================================================================//
string                  G_RISK_STATUS           = "RISK: waiting";
string                  G_RISK_REASON           = "initializing";
string                  G_RISK_DETAIL           = "RISK DETAIL: waiting";
string                  G_RISK_LAST_SIGNATURE   = "";
bool                    G_RISK_READY            = false;
bool                    G_RISK_HARD_BLOCK       = false;
bool                    G_RISK_CLOSE_REQUEST    = false;
datetime                G_RISK_DAY_STAMP        = 0;
double                  G_RISK_DAY_START_BALANCE= 0.0;
double                  G_RISK_DAY_START_EQUITY = 0.0;

// --- V29 ported: Trailing Profit Lock (activates existing v24 TrailingStartPoints/TrailingStepPoints inputs) ---
double                  G_TRAIL_PEAK_POINTS      = 0.0;

// --- V29 Stage 5: Impulse cooldown / trend-vs-correction state ---
int                     G_LAST_IMPULSE_BAR          = -100000;

// --- V29 fix: real, tracked worst-DD statistics (dashboard previously showed a settings value mislabeled as "MaxDD") ---
double                  G_ALL_TIME_MAX_DD_PCT       = 0.0;   // worst live account DD seen since this EA session started
double                  G_ALL_TIME_MAX_DAILY_DD_PCT = 0.0;   // worst single-day DD % seen since this EA session started

// --- V29 new: Kalman (alpha-beta) trend filter state ---
double                  G_KALMAN_LEVEL           = 0.0;
double                  G_KALMAN_TREND           = 0.0;
int                     G_KALMAN_BAR_COUNT       = 0;
datetime                G_KALMAN_LAST_BAR_TIME   = 0;

// --- V29 fix: freeze the grid profile mode for the lifetime of an open basket, so AUTO mode
// switching mid-basket can't mix Hunter-distance and Balanced-distance grid orders together. ---
ENUM_SIRUS_MODE        G_BASKET_FROZEN_MODE        = SIRUS_MODE_BALANCED;
bool                    G_BASKET_MODE_FROZEN        = false;
bool                    G_LAST_IMPULSE_TREND_ALIGNED = false;
int                     G_LAST_IMPULSE_DIRECTION     = 0;      // V31.6f: +1 up, -1 down
double                  G_LAST_IMPULSE_CLOSE         = 0.0;
double                  G_LAST_IMPULSE_RANGE_POINTS  = 0.0;
ENUM_MARKET_STATE       G_ESTABLISHED_TREND          = MARKET_UNKNOWN;

// --- V29 Stage 4: Real Retry Engine state ---
datetime                G_FIRST_LAST_FAIL_TIME      = 0;
bool                    G_FIRST_LAST_FAIL_TRANSIENT = false;
int                     G_FIRST_TRANSIENT_RETRY_COUNT = 0;
datetime                G_GRID_LAST_FAIL_TIME       = 0;
bool                    G_GRID_LAST_FAIL_TRANSIENT  = false;
int                     G_GRID_TRANSIENT_RETRY_COUNT = 0;

// --- V29 Stage 4: Economic Calendar state ---
datetime                G_CAL_LAST_SCAN          = 0;
bool                    G_CAL_ACTIVE             = false;
bool                    G_CAL_BIG_SURPRISE       = false;   // V31.6j: last release deviated significantly from forecast
double                  G_CAL_SURPRISE_PERCENT   = 0.0;
string                  G_CAL_EVENT_NAME         = "";
int                     G_CAL_MINUTES_FROM_EVENT = 0;
ulong                   G_CAL_EVENT_ID           = 0;       // FIX(calendar-window): calendar value id of the active event (unique per release)
bool                    G_CAL_FETCH_FAILED       = false;
bool                    G_CAL_PENDING_ACTUAL     = false;   // a cached release has happened but its actual figure is not in yet
ulong                   G_CAL_LAST_SURPRISE_ID   = 0;
#define CAL_CACHE_MAX 64
datetime                G_CAL_EV_TIME[CAL_CACHE_MAX];
string                  G_CAL_EV_NAME[CAL_CACHE_MAX];
ulong                   G_CAL_EV_ID[CAL_CACHE_MAX];
bool                    G_CAL_EV_SURPRISE[CAL_CACHE_MAX];
double                  G_CAL_EV_SURPRISE_PCT[CAL_CACHE_MAX];
int                     G_CAL_EV_COUNT           = 0;
ulong                   G_CAL_SETTLED_ID[CAL_CACHE_MAX]; // releases whose post window ended early (market settled)
int                     G_CAL_SETTLED_POS        = 0;
datetime                G_CAL_SETTLE_BAR         = 0;     // M1 bar of the last settle check

// --- V29 Stage 4: Smart Partial Close state ---
int                     G_PARTIAL_CLOSE_STAGE    = 0;      // V29: 0=none, 1=stage1 done, 2=stage1+stage2 done
ulong                   G_NEWS_FLAT_LAST_EVENT   = 0;      // V29: avoids re-triggering auto-flat for the same event. FIX(autoflat-by-id): calendar value id, not the name - a weekly release (Jobless Claims) has the same name every week, so the name-based latch silently disabled auto-flat for it after the first time.

// --- V29 new (D-block): Market Confidence Score state ---
#define SIRUS_OPP_TYPE_COUNT 22
double                  G_BAYES_WINS[SIRUS_OPP_TYPE_COUNT];
double                  G_BAYES_LOSSES[SIRUS_OPP_TYPE_COUNT];
int                     G_BASKET_OPENING_TYPE   = 0;      // OPP_TYPE_NONE; records which detector opened the current basket

// --- V31.6e new: M1 entry-close confirmation gate state ---
datetime                G_M1_GATE_BAR           = 0;
int                     G_M1_GATE_LAST_DIR      = 0;

// --- V31.6k new: Duplicate instance detection (warning-only, avoids false-positives on restart) ---
bool                    G_DUP_INSTANCE_WARNED   = false;

// --- V31.6j new: Day-of-Week Bayes tracking (0=Sunday..6=Saturday) ---
#define SIRUS_DOW_COUNT 7
double                  G_DOW_WINS[SIRUS_DOW_COUNT];
double                  G_DOW_LOSSES[SIRUS_DOW_COUNT];
int                     G_BASKET_OPENING_DOW    = -1;

// --- V31.6j new: Post-SL same-direction cooldown ---
int                     G_LAST_SL_DIRECTION     = 0;      // POSITION_TYPE_BUY/SELL of the last SL-closed basket
int                     G_LAST_SL_BAR           = -100000;

// --- V31.6j new: Per-zone historical reliability (bucketed by price) ---
#define SIRUS_ZONE_RELIABILITY_BUCKETS 40
double                  G_ZONE_RELIABILITY_KEY[SIRUS_ZONE_RELIABILITY_BUCKETS];
double                  G_ZONE_RELIABILITY_HOLDS[SIRUS_ZONE_RELIABILITY_BUCKETS];
double                  G_ZONE_RELIABILITY_BREAKS[SIRUS_ZONE_RELIABILITY_BUCKETS];
int                     G_ZONE_RELIABILITY_COUNT = 0;
double                  G_BASKET_OPENING_ZONE_LEVEL = 0.0;

// ===================================================================================
// FEATURE(daily-bias): D1 / previous-day analysis state. Recomputed once per new D1 bar (cheap),
// cached here for every consumer. Everything is validated (>0 checks) before use so a data gap
// on a fresh symbol/day can never feed a garbage level into the zone system.
//   G_PDH / G_PDL      = previous day's High / Low  (the institutional PDH/PDL levels)
//   G_PDC / G_PDO      = previous day's Close / Open
//   G_TODAY_OPEN       = today's D1 open
//   G_DAILY_BIAS       = +1 bullish / -1 bearish / 0 neutral, from prior-day close direction
//                        AND today's open vs prior close, combined conservatively
//   G_DAILY_BIAS_TXT   = human-readable reason for the dashboard/log
//   G_DAILY_BIAS_BAR   = the D1 bar time this was computed for (staleness guard)
// ===================================================================================
double                  G_PDH = 0.0;
double                  G_PDL = 0.0;

// FEATURE(ghost-zones): parallel arrays holding recently-broken H1/H4/D1 levels kept as reaction
// zones. _WAS_SUPPORT records the level's role BEFORE it broke: a broken support (price fell through
// it) is a level price may bounce-reject from on the way back UP, and vice-versa. _EXPIRY is when
// the ghost should be dropped. Kept small (GhostZoneMaxCount) and pruned every scan.
// FIX(ghost-zone-capacity): was [8] while GhostZoneMaxCount (input, V206) is 10 - the populating
// code below already defensively clamps to MathMin(8, GhostZoneMaxCount) so this was never an
// out-of-bounds crash, but it silently capped every account at 8 ghost zones no matter what the
// input said. Sized to match the input's documented intent (V206: 4 -> 10) instead.
double                  G_GHOST_PRICE[10];
bool                    G_GHOST_WAS_SUPPORT[10];
double                  G_GHOST_STRENGTH[10];
datetime                G_GHOST_EXPIRY[10];
int                     G_GHOST_COUNT = 0;
double                  G_PDC = 0.0;
double                  G_PDO = 0.0;
double                  G_TODAY_OPEN = 0.0;
int                     G_DAILY_BIAS = 0;
string                  G_DAILY_BIAS_TXT = "daily bias: not computed";
datetime                G_DAILY_BIAS_BAR = 0;

// --- V31.6 new: Smart Zone Recovery episode state ---
bool                    G_SZR_BLOCK_PREV        = false;  // trend-block state on previous check (episode edge detection)
int                     G_SZR_USES_THIS_EPISODE = 0;      // V54b: was a one-shot bool. Now counts how many smart adds have fired in the current continuous trend-block episode, capped by SZRMaxUsesPerEpisode (0 = uncapped).
bool                    G_SZR_ESCAPE_MODE       = false;  // V31.6b: armed after a smart add fires - basket exits at BE+X

// --- V29 ported: Settings Sanity / License / Setup Doctor state ---
string                  G_SANITY_LAST_STATE      = "";
string                  G_LICENSE_LAST_STATE     = "";
string                  G_SETUPDOC_LAST_STATE    = "";

// --- V29 ported: Daily Profit Governor state ---
datetime                G_DPG_DAY_STAMP          = 0;
double                  G_DPG_PEAK_EQUITY        = 0.0;
bool                    G_DPG_TARGET_LOCKED      = false;
bool                    G_DPG_TRAIL_LOCKED       = false;
bool                    G_DPG_TARGET_PRINTED     = false;
bool                    G_DPG_TRAIL_PRINTED      = false;
double                  G_RISK_DAILY_LOSS_MONEY = 0.0;
double                  G_RISK_DAILY_LOSS_PCT   = 0.0;
double                  G_RISK_EQUITY_DD_PCT    = 0.0;
datetime                G_POST_LOSS_COOLDOWN_UNTIL = 0;
int                     G_RISK_BLOCK_COUNT      = 0;
int                     G_RISK_CLOSE_COUNT      = 0;
int                     G_PREV_BASKET_ORDERS    = 0;
double                  G_PREV_BASKET_PROFIT    = 0.0;

//==================================================================//
//  GLOBAL PREMIUM DASHBOARD / LOG ENGINE
//==================================================================//
string                  G_PREMIUM_STATUS        = "PREMIUM: waiting";
string                  G_PREMIUM_SUMMARY       = "initializing";
string                  G_NEXT_ACTION           = "initializing";
string                  G_LAST_MAJOR_EVENT      = "none";
string                  G_LOG_LAST_SIGNATURE    = "";
datetime                G_LOG_LAST_SNAPSHOT     = 0;
int                     G_LOG_SNAPSHOT_COUNT    = 0;
int                     G_LOG_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL MISSED TRADE MEMORY
//==================================================================//
string                  G_MEMORY_STATUS         = "MEMORY: waiting";
string                  G_MEMORY_REASON         = "initializing";
string                  G_MEMORY_DETAIL         = "MEMORY DETAIL: waiting";
string                  G_MEMORY_LAST_SIGNATURE = "";
string                  G_MEMORY_SETUP_SIGNATURE= "";
string                  G_MEMORY_LAST_MISS_REASON = "";
bool                    G_MEMORY_APPLIED        = false;
int                     G_MEMORY_REPEAT_COUNT   = 0;
int                     G_MEMORY_TOTAL_MISSED   = 0;
int                     G_MEMORY_BOOST_COUNT    = 0;
int                     G_MEMORY_LAST_BAR       = -100000;
datetime                G_MEMORY_LAST_TIME      = 0;
int                     G_MEMORY_CURRENT_BOOST  = 0;

//==================================================================//
//  GLOBAL VPS LIVE VALIDATION
//==================================================================//
string                  G_VPS_STATUS            = "VPS: waiting";
string                  G_VPS_REASON            = "initializing";
string                  G_VPS_DETAIL            = "VPS DETAIL: waiting";
string                  G_VPS_NO_TRADE_REASON   = "NO TRADE: initializing";
string                  G_VPS_BROKER_DETAIL     = "BROKER: initializing";
string                  G_VPS_LAST_SIGNATURE    = "";
datetime                G_VPS_LAST_CHECK        = 0;
datetime                G_VPS_LAST_AUDIT        = 0;
datetime                G_VPS_LAST_BROKER_PRINT = 0;
datetime                G_VPS_TICK_WINDOW_START = 0;
ulong                   G_VPS_TICK_WINDOW_COUNT = 0;
int                     G_VPS_TICKS_PER_MINUTE  = 0;
bool                    G_VPS_OK                = false;
int                     G_VPS_WARNINGS          = 0;

//==================================================================//
//  GLOBAL LEGACY SIRUS UPGRADE PACK
//==================================================================//
string                  G_LEGACY_STATUS         = "LEGACY: waiting";
string                  G_LEGACY_REASON         = "initializing";
string                  G_LEGACY_DETAIL         = "LEGACY DETAIL: waiting";
string                  G_LEGACY_LAST_SIGNATURE = "";
bool                    G_LEGACY_HARD_BLOCK     = false;
bool                    G_LEGACY_APPLIED        = false;
int                     G_LEGACY_BONUS          = 0;
int                     G_LEGACY_PENALTY        = 0;
double                  G_LEGACY_NEAREST_SUPPORT= 0.0;
double                  G_LEGACY_NEAREST_RESIST = 0.0;
double                  G_LEGACY_SUPPORT_DIST   = 0.0;
double                  G_LEGACY_RESIST_DIST    = 0.0;
string                  G_LEGACY_ZONE_STATUS    = "ZONE: waiting";
string                  G_LEGACY_BOS_STATUS     = "BOS: waiting";
string                  G_LEGACY_SWEEP_STATUS   = "SWEEP: waiting";
string                  G_LEGACY_FAKE_STATUS    = "FAKE: waiting";
string                  G_LEGACY_EXH_STATUS     = "EXH: waiting";
string                  G_LEGACY_SESSION_STATUS = "SESSION: waiting";
int                     G_LEGACY_BOS_DIR        = 0;
datetime                G_LEGACY_BOS_TIME       = 0;
double                  G_LEGACY_BOS_LEVEL      = 0.0;
int                     G_LEGACY_EVENT_COUNT    = 0;

//==================================================================//
//  GLOBAL LEGACY PACK 2 / TP CHAIN / ADVANCED RECOVERY
//==================================================================//
string                  G_PACK2_STATUS          = "PACK2: waiting";
string                  G_PACK2_REASON          = "initializing";
string                  G_PACK2_DETAIL          = "PACK2 DETAIL: waiting";
string                  G_PACK2_LAST_SIGNATURE  = "";
bool                    G_PACK2_APPLIED         = false;
bool                    G_BASKET_TRAIL_ACTIVE   = false;
double                  G_BASKET_TRAIL_PEAK     = 0.0;
double                  G_BASKET_TRAIL_LOCK     = 0.0;
bool                    G_BASKET_BE_ACTIVE      = false;
double                  G_PACK2_DYNAMIC_TP      = 0.0;
double                  G_PACK2_DYNAMIC_GRID    = 0.0;
int                     G_PACK2_TRAIL_CLOSES    = 0;
int                     G_PACK2_EVENT_COUNT     = 0;
datetime                G_AFTERSHOCK_UNTIL      = 0;

//==================================================================//
//  GLOBAL LEGACY PACK 3 / NEWS / BROKER / ANALYTICS
//==================================================================//
string                  G_PACK3_STATUS          = "PACK3: waiting";
string                  G_PACK3_REASON          = "initializing";
string                  G_PACK3_DETAIL          = "PACK3 DETAIL: waiting";
string                  G_PACK3_NEWS_STATUS     = "NEWS: waiting";
string                  G_PACK3_BROKER_STATUS   = "BROKER_SYNC: waiting";
string                  G_PACK3_DEAL_STATUS     = "DEALS: waiting";
string                  G_PACK3_AUDIT_STATUS    = "CLIENT_AUDIT: waiting";
string                  G_PACK3_LAST_SIGNATURE  = "";
bool                    G_PACK3_HARD_BLOCK      = false;
bool                    G_PACK3_ENTRY_BLOCK     = false;
bool                    G_PACK3_GRID_BLOCK      = false;
bool                    G_PACK3_CLOSE_REQUEST   = false;
bool                    G_PACK3_NEWS_ACTIVE     = false;
datetime                G_PACK3_NEWS_UNTIL      = 0;
datetime                G_PACK3_LAST_DEAL_SCAN  = 0;
datetime                G_PACK3_LAST_AUDIT_PRINT= 0;
int                     G_PACK3_EVENT_COUNT     = 0;
int                     G_DEALS_TOTAL           = 0;
int                     G_DEALS_WINS            = 0;
int                     G_DEALS_LOSSES          = 0;
double                  G_DEALS_NET_PROFIT      = 0.0;
double                  G_DEALS_GROSS_PROFIT    = 0.0;
double                  G_DEALS_GROSS_LOSS      = 0.0;
double                  G_DEALS_WINRATE         = 0.0;
double                  G_BROKER_EFFECTIVE_STOP = 0.0;

//==================================================================//
//  GLOBAL PHASE 21.3 / STABLE RC BASELINE
//==================================================================//
string                  G_RC_STATUS             = "RC: waiting";
string                  G_RC_REASON             = "initializing";
string                  G_RC_DETAIL             = "RC DETAIL: waiting";
string                  G_RC_LAST_SIGNATURE     = "";
bool                    G_RC_READY              = false;
bool                    G_RC_CRITICAL_BLOCK     = false;
bool                    G_RC_ENTRY_BLOCK        = false;
bool                    G_RC_GRID_BLOCK         = false;
int                     G_RC_EVENT_COUNT        = 0;

//==================================================================//
//  GLOBAL PHASE 22.1 / PACK4 MINI LICENSE
//==================================================================//
string                  G_P4M_STATUS            = "P4M: waiting";
string                  G_P4M_REASON            = "initializing";
string                  G_P4M_DETAIL            = "P4M DETAIL: waiting";
string                  G_P4M_LAST_SIGNATURE    = "";
bool                    G_P4M_VALID             = true;
bool                    G_P4M_HARD_BLOCK        = false;
bool                    G_P4M_ENTRY_BLOCK       = false;
bool                    G_P4M_GRID_BLOCK        = false;
bool                    G_P4M_LICENSE_OK        = true;
bool                    G_P4M_SYMBOL_OK         = true;
bool                    G_P4M_SPREAD_OK         = true;
datetime                G_P4M_EXPIRE_TIME       = 0;
int                     G_P4M_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 22.2 / CLIENT RISK PROFILE / LOT CAP
//==================================================================//
string                  G_P4L_STATUS            = "P4L: waiting";
string                  G_P4L_REASON            = "initializing";
string                  G_P4L_DETAIL            = "P4L DETAIL: waiting";
string                  G_P4L_LAST_SIGNATURE    = "";
bool                    G_P4L_VALID             = true;
bool                    G_P4L_ENTRY_BLOCK       = false;
bool                    G_P4L_GRID_BLOCK        = false;
double                  G_P4L_FIRST_CAP         = 0.0;
double                  G_P4L_GRID_CAP          = 0.0;
int                     G_P4L_MAX_ORDERS        = 0;
double                  G_P4L_MAX_DD            = 0.0;
double                  G_P4L_LAST_ADJUSTED_LOT = 0.0;
int                     G_P4L_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 22.3 / PREMIUM VISUAL WATERMARK / ZONES
//==================================================================//
string                  G_PV_STATUS             = "PV: waiting";
string                  G_PV_DETAIL             = "PV DETAIL: waiting";
string                  G_PV_LAST_SIGNATURE     = "";
datetime                G_PV_LAST_REFRESH       = 0;
int                     G_PV_EVENT_COUNT        = 0;

string                  G_PV_CLEAN_STATUS       = "PV CLEAN: waiting";
string                  G_PV_CLEAN_DETAIL       = "PV CLEAN DETAIL: waiting";
datetime                G_PV_LAST_CLEANUP       = 0;
int                     G_PV_OBJECT_COUNT       = 0;
int                     G_PV_CLEANED_OBJECTS    = 0;
int                     G_PV_CLEAN_EVENT_COUNT  = 0;

//==================================================================//
//  GLOBAL PHASE 22.7 / RC SETTINGS BALANCE
//==================================================================//
string                  G_RCB_STATUS            = "RCB: waiting";
string                  G_RCB_REASON            = "initializing";
string                  G_RCB_DETAIL            = "RCB DETAIL: waiting";
string                  G_RCB_LAST_SIGNATURE    = "";
bool                    G_RCB_VALID             = true;
bool                    G_RCB_ENTRY_BLOCK       = false;
bool                    G_RCB_GRID_BLOCK        = false;
double                  G_RCB_MAX_FIRST_LOT     = 0.0;
int                     G_RCB_MAX_ORDERS        = 0;
double                  G_RCB_MAX_BASKET_SL     = 0.0;
int                     G_RCB_MAX_SPREAD        = 0;
int                     G_RCB_WARNINGS          = 0;
int                     G_RCB_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 22.8 / WARNING CLEANUP POLISH
//==================================================================//
string                  G_WCP_STATUS            = "WCP: waiting";
string                  G_WCP_DETAIL            = "WCP DETAIL: waiting";
string                  G_WCP_LAST_SIGNATURE    = "";
int                     G_WCP_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 22.9 / FINAL SELF-AUDIT
//==================================================================//
string                  G_FSA_STATUS            = "FSA: waiting";
string                  G_FSA_REASON            = "initializing";
string                  G_FSA_DETAIL            = "FSA DETAIL: waiting";
string                  G_FSA_LEGACY_DETAIL     = "FSA LEGACY: waiting";
string                  G_FSA_LAST_SIGNATURE    = "";
bool                    G_FSA_READY             = false;
bool                    G_FSA_ENTRY_BLOCK       = false;
bool                    G_FSA_GRID_BLOCK        = false;
int                     G_FSA_SCORE             = 0;
int                     G_FSA_PASSED            = 0;
int                     G_FSA_TOTAL             = 0;
int                     G_FSA_WARNINGS          = 0;
int                     G_FSA_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL FINAL / RELEASE BUILD CONTROLLER
//==================================================================//
string                  G_RLS_STATUS            = "RLS: waiting";
string                  G_RLS_REASON            = "initializing";
string                  G_RLS_DETAIL            = "RLS DETAIL: waiting";
string                  G_RLS_PRESET_DETAIL     = "RLS PRESET: waiting";
string                  G_RLS_LAST_SIGNATURE    = "";
bool                    G_RLS_READY             = false;
bool                    G_RLS_ENTRY_BLOCK       = false;
bool                    G_RLS_GRID_BLOCK        = false;
int                     G_RLS_WARNINGS          = 0;
int                     G_RLS_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.1 / LEGACY DEEP PARITY HTF COMMANDER
//==================================================================//
string                  G_DLP_STATUS            = "DLP: waiting";
string                  G_DLP_REASON            = "initializing";
string                  G_DLP_DETAIL            = "DLP DETAIL: waiting";
string                  G_DLP_LAST_SIGNATURE    = "";
bool                    G_DLP_APPLIED           = false;
bool                    G_DLP_ENTRY_BLOCK       = false;
bool                    G_DLP_GRID_BLOCK        = false;
int                     G_DLP_HTF_DIR           = 0;
int                     G_DLP_STRUCT_DIR        = 0;
int                     G_DLP_ZONE_DIR          = 0;
int                     G_DLP_ALIGNMENT_SCORE   = 0;
int                     G_DLP_BONUS             = 0;
int                     G_DLP_PENALTY           = 0;
int                     G_DLP_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.2 / DEEP BOS CHOCH RETEST
//==================================================================//
string                  G_DBOS_STATUS           = "DBOS: waiting";
string                  G_DBOS_REASON           = "initializing";
string                  G_DBOS_DETAIL           = "DBOS DETAIL: waiting";
string                  G_DBOS_LAST_SIGNATURE   = "";
bool                    G_DBOS_APPLIED          = false;
bool                    G_DBOS_ENTRY_BLOCK      = false;
bool                    G_DBOS_GRID_BLOCK       = false;
bool                    G_DBOS_RETEST_READY     = false;
bool                    G_DBOS_EVER_RETESTED    = false;   // V29: stays true once THIS break level has been retest-confirmed
int                     G_DBOS_BREAK_VOLUME_SIGN = 0;      // V29: order-flow conviction sign captured at the moment of the break
bool                    G_DBOS_CHOCH_ACTIVE     = false;
int                     G_DBOS_DIR              = 0;
int                     G_DBOS_LAST_MAJOR_DIR   = 0;
int                     G_DBOS_BONUS            = 0;
int                     G_DBOS_PENALTY          = 0;
int                     G_DBOS_LAST_BOS_BAR     = -100000;
double                  G_DBOS_LAST_BOS_LEVEL   = 0.0;
int                     G_DBOS_EVENT_COUNT      = 0;

//==================================================================//
//  GLOBAL PHASE 23.3 / DEEP TOP ZONE TRAP GUARD
//==================================================================//
string                  G_DTZ_STATUS            = "DTZ: waiting";
string                  G_DTZ_REASON            = "initializing";
string                  G_DTZ_DETAIL            = "DTZ DETAIL: waiting";
string                  G_DTZ_LAST_SIGNATURE    = "";
bool                    G_DTZ_APPLIED           = false;
bool                    G_DTZ_ENTRY_BLOCK       = false;
bool                    G_DTZ_GRID_BLOCK        = false;
bool                    G_DTZ_TOP_DANGER        = false;
bool                    G_DTZ_BOTTOM_DANGER     = false;
bool                    G_DTZ_BREAKOUT_OK       = false;
int                     G_DTZ_TRAP_DIR          = 0;
int                     G_DTZ_BONUS             = 0;
int                     G_DTZ_PENALTY           = 0;
int                     G_DTZ_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.4 / DEEP NEWS VOLATILITY SHOCK BRAIN
//==================================================================//
string                  G_DNV_STATUS            = "DNV: waiting";
string                  G_DNV_REASON            = "initializing";
string                  G_DNV_DETAIL            = "DNV DETAIL: waiting";
string                  G_DNV_LAST_SIGNATURE    = "";
bool                    G_DNV_APPLIED           = false;
bool                    G_DNV_ENTRY_BLOCK       = false;
bool                    G_DNV_GRID_BLOCK        = false;
bool                    G_DNV_NEWS_ACTIVE       = false;
bool                    G_DNV_SHOCK_ACTIVE      = false;
bool                    G_DNV_SPREAD_SHOCK      = false;
bool                    G_DNV_EXHAUST_RISK      = false;
int                     G_DNV_SHOCK_DIR         = 0;
int                     G_DNV_LAST_SHOCK_BAR    = -100000;
int                     G_DNV_BONUS             = 0;
int                     G_DNV_PENALTY           = 0;
int                     G_DNV_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.5 / ADAPTIVE ENTRY TIMING BRAIN
//==================================================================//
string                  G_DET_STATUS            = "DET: waiting";
string                  G_DET_REASON            = "initializing";
string                  G_DET_DETAIL            = "DET DETAIL: waiting";
string                  G_DET_LAST_SIGNATURE    = "";
bool                    G_DET_APPLIED           = false;
bool                    G_DET_ENTRY_BLOCK       = false;
bool                    G_DET_GRID_BLOCK        = false;
bool                    G_DET_EARLY_BAR         = false;
bool                    G_DET_LATE_ENTRY        = false;
bool                    G_DET_CANDLE_CONFIRM    = false;
bool                    G_DET_REJECTION_CONFIRM = false;
bool                    G_DET_POST_SHOCK        = false;
int                     G_DET_BAR_AGE_SECONDS   = 0;
int                     G_DET_BONUS             = 0;
int                     G_DET_PENALTY           = 0;
int                     G_DET_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.6 / ADAPTIVE RECOVERY INTELLIGENCE
//==================================================================//
string                  G_DRI_STATUS            = "DRI: waiting";
string                  G_DRI_REASON            = "initializing";
string                  G_DRI_DETAIL            = "DRI DETAIL: waiting";
string                  G_DRI_LAST_SIGNATURE    = "";
bool                    G_DRI_APPLIED           = false;
bool                    G_DRI_GRID_BLOCK        = false;
bool                    G_DRI_TREND_AGAINST     = false;
bool                    G_DRI_ZONE_DANGER       = false;
bool                    G_DRI_NEWS_SHOCK        = false;
bool                    G_DRI_ORDER_PRESSURE    = false;
int                     G_DRI_HEALTH_SCORE      = 100;
double                  G_DRI_DISTANCE_FACTOR   = 1.0;
double                  G_DRI_LOT_FACTOR        = 1.0;
int                     G_DRI_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.7 / PROFIT EXTRACTION SMART EXIT
//==================================================================//
string                  G_DXB_STATUS            = "DXB: waiting";
string                  G_DXB_REASON            = "initializing";
string                  G_DXB_DETAIL            = "DXB DETAIL: waiting";
string                  G_DXB_LAST_SIGNATURE    = "";
bool                    G_DXB_APPLIED           = false;
bool                    G_DXB_CLOSE_SENT        = false;
bool                    G_DXB_OPPOSITE_RISK     = false;
bool                    G_DXB_SHOCK_RISK        = false;
bool                    G_DXB_PEAK_GIVEBACK     = false;
bool                    G_DXB_QUICK_PROFIT      = false;
double                  G_DXB_PEAK_POINTS       = 0.0;
double                  G_DXB_PEAK_PROFIT       = 0.0;
long                    G_DXB_TRACK_DIR         = -1;
int                     G_DXB_TRACK_ORDERS      = 0;
int                     G_DXB_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.8 / MARKET REGIME AUTO-TUNING
//==================================================================//
string                  G_DRT_STATUS            = "DRT: waiting";
string                  G_DRT_REASON            = "initializing";
string                  G_DRT_DETAIL            = "DRT DETAIL: waiting";
string                  G_DRT_LAST_SIGNATURE    = "";
bool                    G_DRT_APPLIED           = false;
bool                    G_DRT_ENTRY_BLOCK       = false;
bool                    G_DRT_GRID_BLOCK        = false;
bool                    G_DRT_TREND_MODE        = false;
bool                    G_DRT_RANGE_MODE        = false;
bool                    G_DRT_SHOCK_MODE        = false;
bool                    G_DRT_CHAOS_MODE        = false;
int                     G_DRT_REGIME_DIR        = 0;
int                     G_DRT_BONUS             = 0;
int                     G_DRT_PENALTY           = 0;
double                  G_DRT_GRID_FACTOR       = 1.0;
double                  G_DRT_LOT_FACTOR        = 1.0;
int                     G_DRT_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 23.9 / SMART CLIENT SAFETY RENTAL PROTECTION
//==================================================================//
string                  G_DCS_STATUS            = "DCS: waiting";
string                  G_DCS_REASON            = "initializing";
string                  G_DCS_DETAIL            = "DCS DETAIL: waiting";
string                  G_DCS_LAST_SIGNATURE    = "";
bool                    G_DCS_APPLIED           = false;
bool                    G_DCS_ENTRY_BLOCK       = false;
bool                    G_DCS_GRID_BLOCK        = false;
bool                    G_DCS_LICENSE_RISK      = false;
bool                    G_DCS_SPREAD_RISK       = false;
bool                    G_DCS_DD_RISK           = false;
bool                    G_DCS_ORDER_RISK        = false;
bool                    G_DCS_RENTAL_PROFILE    = false;
double                  G_DCS_GRID_FACTOR       = 1.0;
double                  G_DCS_LOT_FACTOR        = 1.0;
int                     G_DCS_WARNINGS          = 0;
int                     G_DCS_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.0 / FINAL INTELLIGENCE MERGE PRO
//==================================================================//
string                  G_NIM_STATUS            = "NIM: waiting";
string                  G_NIM_REASON            = "initializing";
string                  G_NIM_DETAIL            = "NIM DETAIL: waiting";
string                  G_NIM_DEEP_SUMMARY      = "NIM DEEP: waiting";
string                  G_NIM_RECOMMENDATION    = "NIM REC: waiting";
string                  G_NIM_LAST_SIGNATURE    = "";
bool                    G_NIM_READY             = false;
bool                    G_NIM_PRO_READY         = false;
bool                    G_NIM_ENTRY_BLOCK       = false;
bool                    G_NIM_GRID_BLOCK        = false;
bool                    G_NIM_CRITICAL          = false;
int                     G_NIM_SCORE             = 0;
int                     G_NIM_PENALTY           = 0;
int                     G_NIM_BONUS             = 0;
int                     G_NIM_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.1 / PRO RELEASE FINAL
//==================================================================//
string                  G_FPR_STATUS            = "FPR: waiting";
string                  G_FPR_REASON            = "initializing";
string                  G_FPR_DETAIL            = "FPR DETAIL: waiting";
string                  G_FPR_PRESET            = "FPR PRESET: waiting";
string                  G_FPR_LAST_SIGNATURE    = "";
bool                    G_FPR_READY             = false;
bool                    G_FPR_PRO_READY         = false;
bool                    G_FPR_ENTRY_BLOCK       = false;
bool                    G_FPR_GRID_BLOCK        = false;
int                     G_FPR_WARNINGS          = 0;
int                     G_FPR_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.2 / SETTINGS GOVERNANCE CLIENT GUARD
//==================================================================//
string                  G_SGV_STATUS            = "SGV: waiting";
string                  G_SGV_REASON            = "initializing";
string                  G_SGV_DETAIL            = "SGV DETAIL: waiting";
string                  G_SGV_PROFILE_DETAIL    = "SGV PROFILE: waiting";
string                  G_SGV_LAST_SIGNATURE    = "";
bool                    G_SGV_READY             = false;
bool                    G_SGV_ENTRY_BLOCK       = false;
bool                    G_SGV_GRID_BLOCK        = false;
bool                    G_SGV_CLIENT_PROFILE    = false;
bool                    G_SGV_RENTAL_PROFILE    = false;
bool                    G_SGV_HIGH_HUNTER_PROFILE = false;
int                     G_SGV_WARNINGS          = 0;
int                     G_SGV_CRITICAL_WARNINGS = 0;
int                     G_SGV_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.3 / CLIENT DASHBOARD POLISH
//==================================================================//
string                  G_CDP_STATUS            = "CDP: waiting";
string                  G_CDP_BADGE             = "SIRUS BY ZAKIY";
string                  G_CDP_HEALTH_LINE       = "HEALTH: waiting";
string                  G_CDP_RISK_BANNER       = "RISK: waiting";
string                  G_CDP_MODE_ADVICE       = "MODE: waiting";
string                  G_CDP_CONTACT_LINE      = "CONTACT: waiting";
string                  G_CDP_DETAIL            = "CDP DETAIL: waiting";
string                  G_CDP_LAST_SIGNATURE    = "";
bool                    G_CDP_READY             = false;
bool                    G_CDP_CLIENT_VIEW       = true;
int                     G_CDP_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.4 / FINAL PRESET HARDENING
//==================================================================//
string                  G_DPH_STATUS            = "DPH: waiting";
string                  G_DPH_REASON            = "initializing";
string                  G_DPH_DETAIL            = "DPH DETAIL: waiting";
string                  G_DPH_PRESET_MAP        = "DPH PRESET: waiting";
string                  G_DPH_LAST_SIGNATURE    = "";
bool                    G_DPH_READY             = false;
bool                    G_DPH_ENTRY_BLOCK       = false;
bool                    G_DPH_GRID_BLOCK        = false;
bool                    G_DPH_CRITICAL          = false;
bool                    G_DPH_APPLIED           = false;
int                     G_DPH_WARNINGS          = 0;
int                     G_DPH_CRITICAL_WARNINGS = 0;
double                  G_DPH_GRID_FACTOR       = 1.0;
double                  G_DPH_LOT_FACTOR        = 1.0;
int                     G_DPH_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.5 / FINAL BUILD AUDIT LOCK
//==================================================================//
string                  G_FBL_STATUS            = "FBL: waiting";
string                  G_FBL_REASON            = "initializing";
string                  G_FBL_DETAIL            = "FBL DETAIL: waiting";
string                  G_FBL_ROADMAP           = "FBL ROADMAP: waiting";
string                  G_FBL_PACKAGE           = "FBL PACKAGE: waiting";
string                  G_FBL_LAST_SIGNATURE    = "";
bool                    G_FBL_READY             = false;
bool                    G_FBL_LOCKED            = false;
bool                    G_FBL_ENTRY_BLOCK       = false;
bool                    G_FBL_GRID_BLOCK        = false;
bool                    G_FBL_CRITICAL          = false;
int                     G_FBL_WARNINGS          = 0;
int                     G_FBL_CRITICAL_WARNINGS = 0;
int                     G_FBL_EVENT_COUNT       = 0;

//==================================================================//
//  GLOBAL PHASE 24.6 / LIVE VALIDATION PROBE
//==================================================================//
string                  G_LVP_STATUS            = "LVP: waiting";
string                  G_LVP_REASON            = "initializing";
string                  G_LVP_ENTRY_DOCTOR      = "ENTRY DOCTOR: waiting";
string                  G_LVP_GRID_DOCTOR       = "GRID DOCTOR: waiting";
string                  G_LVP_GATE_STACK        = "GATE STACK: waiting";
string                  G_LVP_DETAIL            = "LVP DETAIL: waiting";
string                  G_LVP_LAST_SIGNATURE    = "";
bool                    G_LVP_READY             = false;
bool                    G_LVP_ENTRY_READY       = false;
bool                    G_LVP_GRID_READY        = false;
bool                    G_LVP_NO_TRADE          = false;
int                     G_LVP_READY_SCORE       = 0;
int                     G_LVP_BLOCKERS          = 0;
int                     G_LVP_EVENT_COUNT       = 0;
