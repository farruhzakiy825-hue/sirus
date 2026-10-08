//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 00_Defines                                      |
//| Constants (#define), enums and forward declarations              |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

// BOSQICH 14: micro/minor/local struktura holatlari. #define ishlatilishidan OLDIN turishi shart.
#define MS_RANGE        0
#define MS_IMPULSE      1
#define MS_CONTINUATION 2
#define MS_REVERSAL     3
#define MS_PULLBACK     4

// [0] = M1 micro, [1] = M5 minor, [2] = M15 local (BOSQICH 15b)
int    G_MS_DIR[3]   = {0, 0, 0};
int    G_MS_STATE[3] = {MS_RANGE, MS_RANGE, MS_RANGE};
double G_MS_BOS[3]   = {0.0, 0.0, 0.0};
int    G_MS_BAR      = -100000;


// Chain pattern identifiers. Preprocessor defines are NOT hoisted, so they must appear before the
// first line that mentions them - and the score engine references CHAIN_PAT_NONE long before the
// chain module itself is defined further down.
#define CHAIN_PAT_NONE        0
#define CHAIN_PAT_SWEEP_REV   1
#define CHAIN_PAT_SWEEP_CONT  2
#define CHAIN_PAT_IMP_EXH     3
#define CHAIN_PAT_EXPANSION   4
#define CHAIN_PAT_BREAK_CONF  5

#define LB_OK                    0
#define LB_WAIT_POSITION         1
#define LB_WAIT_STRETCH          2
#define LB_WAIT_WORSE_THAN_STOP  3
#define CHAIN_PAT_NEW_TREND   6
#define CHAIN_PAT_COUNT       7

// Zone-map swing cache dimensions. Same rule as above: these are consumed by modules that appear
// far earlier in the file than the cache itself, so they belong here rather than beside it.
#define SIRUS_ZM_CACHE_TF_COUNT 7
#define SIRUS_ZM_CACHE_MAX 220   // V206: 80 -> 220. The cache fills from the most recent swing backwards and stops when full, so on H1 with a 240-bar lookback it held only the closest 80 - the levels from two days ago were in the data and never reached the cache. A support that broke this morning is visible; the one that has held for two days is the one price is actually heading for.

// Score bands for confidence calibration.
#define SCORE_BAND_COUNT 5

// Warning identifiers for the reliability tracker.
#define WARN_LATE_ENTRY     0
#define WARN_NO_ROOM        1
#define WARN_ZONE_ROLE      2
#define WARN_STRUCTURE      3
#define WARN_LIQUIDITY      4
#define WARN_PATH_CROWDED   5
#define WARN_RETAIL_LEVEL   6
#define WARN_FORCED_FLOW    7
#define WARN_CHAIN          8
#define WARN_UNDECIDED      9
#define WARN_HISTORY        10
#define WARN_COUNT          11

// Market regime identifiers.
#define REGIME_UNKNOWN   0
#define REGIME_TRENDING  1
#define REGIME_RANGING   2
#define REGIME_VOLATILE  3
#define REGIME_QUIET     4

// Pending blocked-entry audit slots.
#define BLOCK_AUDIT_SLOTS 8

// Setup arming - why a setup is being held rather than taken.
#define ARM_REASON_NONE       0
#define ARM_REASON_ZONE       1   // strong opposing zone - wait for the reaction
#define ARM_REASON_EXTENDED   2   // move overextended - wait for the pullback
#define ARM_REASON_STRUCTURE  3   // structure against - wait for a reclaim
#define ARM_REASON_FILL          4
#define ARM_REASON_LATE          5   // V288: right trade, wrong moment - hold for the retrace   // V275: the setup is sound, the price is not - hold a few bars for a better one
#define ARM_OUTCOME_SLOTS     4   // audit slots, one per ARM_REASON_* (index 0 unused)

// Candle sequence states.
#define CANDLE_STATE_NEUTRAL     0
#define CANDLE_STATE_EXPANDING   1   // ranges growing - the move is being driven
#define CANDLE_STATE_CONTRACTING 2   // ranges shrinking - the move is running out
#define CANDLE_STATE_INSIDE      3   // coiling inside the previous bar - a pause
#define CANDLE_STATE_REJECTION   4   // long wick against - a level is being defended
#define CANDLE_STATE_ABSORPTION  5   // large range, small body - effort without result
#define CANDLE_EVENT_SLOTS       6   // candles being watched for what happens after them

// Intra-bar sampling and what changed within the forming bar.
#define LIVE_SAMPLE_SLOTS        8   // shape snapshots kept per forming bar
#define LIVE_EVO_NONE            0
#define LIVE_EVO_WICK_FAILED     1   // a wick existed and was then traded through
#define LIVE_EVO_SUSTAINED       2   // body extending steadily one way
#define LIVE_EVO_ABSORBED        3   // body extended, then gave it back

// What a disagreement between candle readings means.
#define CCONF_NONE               0
#define CCONF_DEFENCE_BROKE      1   // a rejection was read, and then it failed
#define CCONF_PUSH_STALLED       2   // expansion read, then absorbed
#define CCONF_SPLIT              3   // readings disagree with no story behind it

// Candle reading sources, each of which learns its own accuracy.
#define CSRC_SEQUENCE            0
#define CSRC_AUTHORSHIP          1
#define CSRC_PARTICIPATION       2
#define CSRC_OPENING             3
#define CSRC_PATTERN             4
#define CSRC_HTF                 5
#define CSRC_LIVEBAR             6
#define CSRC_EVOLUTION           7
#define CSRC_CONFLICT            8
#define CSRC_BREAK               9
#define CSRC_COUNT               10

// Named situations - zone, candle and structure read as one observation.
#define SIT_NONE                 0
#define SIT_TREND_TEST_HELD      1   // trend reaches a level and the level holds
#define SIT_TREND_TEST_BROKE     2   // trend reaches a level and takes it
#define SIT_EXHAUSTION_AT_EDGE   3   // stretched trend refused at a level - a turn
#define SIT_RANGE_EDGE_FADE      4   // no trend, price at an edge, rejection there
#define SIT_BROKEN_LEVEL_RETEST  5   // a level was taken, price returned to it, and it held from the other side

// Local structure shapes - what the swings look like, not just which way they point.
#define LSTRUCT_NONE             0
#define LSTRUCT_STEPPING         1   // measured swings, consistent size - a trend with participants
#define LSTRUCT_EXPANDING        2   // swings growing - the move is being fed
#define LSTRUCT_FADING           3   // swings shrinking - running out
#define LSTRUCT_CHOPPY           4   // no consistent shape

// How the structure reads across timeframes - the relationship, not just each one.
#define TFALIGN_NONE             0
#define TFALIGN_FULL             1   // all three point the same way
#define TFALIGN_PULLBACK         2   // lower disagrees, the two above agree
#define TFALIGN_TRANSITION       3   // middle disagrees - nothing settled
#define TFALIGN_SPLIT            4   // no coherent picture

// The larger picture, which decides what a local reading means.
#define REVCTX_NONE              0
#define REVCTX_BEARISH           1   // a top formed and broke - rallies into it are retests
#define REVCTX_BULLISH           2   // a bottom formed and broke - dips into it are retests

// How candle sizes are progressing - the order they arrived in, not their average.
#define CSEQ_NONE                0
#define CSEQ_FADING              1   // each body smaller than the last - the move is running out of buyers
#define CSEQ_BUILDING            2   // each body larger - pressure accumulating

// Levels kept where the nearest-swing scan cannot push them off.
#define PROTECTED_ZONE_MAX      24

// Ladder shapes - the grid's character, chosen once when the basket opens.
#define LADDER_DEFAULT           0
#define LADDER_SHORT             1   // few rungs, close, full size - a level is expected to hold
#define LADDER_LONG              2   // many rungs, wide, small - survival against a trend
#define LADDER_CAUTIOUS          3   // conditions unreadable - reduced commitment throughout

#define MODHEALTH_MAX           64   // V271: 48 -> 64. Fifty-two modules now report and the cap was forty-eight, so four would have been dropped in silence - and a silently dropped module is precisely what this check exists to catch. Raised twice now for the same reason; sixty-four leaves room for the next dozen without a third correction.   // V250c: 32 -> 48. Twelve modules were added after the health check was built and the cap was not raised with them, so MHAdd would have silently dropped the last three - and a silently dropped module is exactly what this check exists to catch. Headroom for the next dozen.

// ----------------------------------------------------------------------------
// State read by the module health check below. Declared here because MQL5 resolves
// functions ahead of their definition but not variables, and the health check calls
// into every one of these.
// ----------------------------------------------------------------------------
int      G_ARM_DIR        = 0;      // direction of the armed setup
int      G_ARM_REASON     = ARM_REASON_NONE;
int      G_ARM_BAR        = 0;      // bar it was armed on
double   G_ARM_TRIGGER    = 0.0;    // price the confirmation is measured against
bool     G_ARM_IS_WALL    = false;   // FIX(arm-wall-geometry): true when G_ARM_TRIGGER is a wall the trade must get PAST, false when it is a level the trade wants price to dip into. The two need opposite confirmations.
bool     G_ENTRY_AGAINST_GLOBAL = false;   // FIX(counter-trend-needs-a-reason): this entry is fighting a confirmed global trend - ChooseLadderShape() caps its ladder
int      G_ARM_ZONE_FAIL_BAR[2] = {-1, -1};   // FIX(counter-zone-rearm-loop): bar a counter-zone wait ended UNANSWERED, per direction ([0]=buy, [1]=sell). One shared slot let a SELL failure cancel a BUY cooldown.
double   G_ARM_SETUP_SCORE = 0.0;   // score the setup had when armed
string   G_ARM_TEXT       = "";
int      G_ARM_SESSION    = -1;     // V197: session the setup was armed in - a handover invalidates the reasoning
int      G_ARM_START_SCORE = 0;     // V197: score at the moment of arming, to detect the setup decaying

// Measured local structure (V223). Declared here rather than beside its own module because the
// break tracker below reads these, and MQL5 resolves functions ahead of use but not variables.
int      G_LS_BAR        = -100000;
int      G_LS_STATE      = LSTRUCT_NONE;
int      G_LS_DIR        = 0;
double   G_LS_STEP_AVG   = 0.0;    // average swing size in points
double   G_LS_STEP_TREND = 0.0;    // >0 growing, <0 shrinking
double   G_LS_INVALIDATE = 0.0;    // the price that ends this structure
double   G_LS_CONVICTION = 0.0;
string   G_LS_DETAIL     = "";

// Break tracking - the structure that was in force, and what happened to it.
int      G_LSB_LAST_DIR   = 0;        // direction of the structure being watched
double   G_LSB_LAST_PRICE = 0.0;      // its invalidation price
int      G_LSB_BREAK_BAR  = -100000;  // when it was broken
int      G_LSB_BREAK_DIR  = 0;        // direction the break points
double   G_LSB_BREAK_PRICE = 0.0;

datetime G_LIVE_BAR_TIME   = 0;                    // which bar these samples belong to
double   G_LIVE_S_UPPER[LIVE_SAMPLE_SLOTS];
double   G_LIVE_S_LOWER[LIVE_SAMPLE_SLOTS];
double   G_LIVE_S_BODY[LIVE_SAMPLE_SLOTS];
double   G_LIVE_S_CLOSE[LIVE_SAMPLE_SLOTS];
double   G_LIVE_S_PROG[LIVE_SAMPLE_SLOTS];
int      G_LIVE_S_DIR[LIVE_SAMPLE_SLOTS];
int      G_LIVE_S_COUNT = 0;
double   G_LIVE_S_LAST_PROG = 0.0;

// Peak wick sizes seen at any point during this bar - the wick that existed and was
// then filled is the one that matters, and it is gone from the current shape.
double   G_LIVE_PEAK_UPPER = 0.0;
double   G_LIVE_PEAK_LOWER = 0.0;
double   G_LIVE_PEAK_BODY  = 0.0;
int      G_LIVE_PEAK_BODY_DIR = 0;


// Multi-candle pattern identifiers.
#define CPAT_NONE            0
#define CPAT_MORNING_STAR    1   // down, pause, up - a turn upward
#define CPAT_EVENING_STAR    2   // up, pause, down - a turn downward
#define CPAT_THREE_SOLDIERS  3   // three rising closes with real bodies
#define CPAT_THREE_CROWS     4   // three falling closes with real bodies
#define CPAT_HARAMI          5   // large bar then a small one inside it - momentum ending
#define CPAT_TWEEZER         6   // two bars refused at the same extreme




// Trading session identifiers.
#define SESSION_DEAD     0   // rollover - widened spreads, no participation
#define SESSION_ASIA     1   // thin ranges
#define SESSION_LONDON   2   // expansion
#define SESSION_OVERLAP  3   // London + New York, the day's real volume
#define SESSION_NY       4   // continuation, then fading into the close




//==================================================================//
//  >>>>>>>>>>  HOW TO SET YOUR STOP LOSS (SL)  <<<<<<<<<<           //
//==================================================================//
//                                                                  //
//  To make the SL a given % of balance (example: 70%), set the     //
//  values below to that number. They are kept SEPARATE on purpose  //
//  (each layer checks independently, so if one ever fails another  //
//  still catches it). It's a one-time setup - you rarely touch it. //
//                                                                  //
//  ---- STEP 1: THE MAIN SL (this is the important one) ----       //
//    BasketSLPercent            = 70    <-- your SL %              //
//                                                                  //
//  ---- STEP 2: KEEP THE BACKUP LAYERS IN LINE (= same %) ----     //
//    (if you leave these at 50 while BasketSLPercent = 70, they    //
//     would close the basket at 50% BEFORE your real SL is hit)    //
//    DailyLossPercent           = 70                               //
//    EquityStopPercent          = 70                               //
//    EmergencyDDPercent         = 70                               //
//    RecoveryMaxDDForNewGrid    = 70                               //
//                                                                  //
//  ---- STEP 3: THE VERY LAST BACKSTOP (a bit ABOVE the SL) ----   //
//    EmergencyForceCloseDDPercent = 72   (main SL + 2)             //
//                                                                  //
//  ---- OPTIONAL: early-warning / early-exit (leave or scale) ---- //
//    SmartEarlyExitMinDDPercent = 45   (must stay BELOW the SL)    //
//    DDWarningThreshold1/2/3    = 35 / 50 / 63  (phone alerts)     //
//                                                                  //
//  RULE: Main SL and the STEP-2 backups share the same number.     //
//        STEP-3 sits just above it. Early-exit/alerts sit below.   //
//        All of these live in section "03 - SL / LOSS PROTECTION". //
//==================================================================//



//==================================================================//
//  PHASE 21.3 RULES
//  - FIRST ENTRY ONLY
//  - NO SIGNAL ENGINE
//  - NO GRID
//  - NO RECOVERY
//  - ENVIRONMENT MUST EXPLAIN READY / BLOCK
//  - MODE MANAGER MUST EXPLAIN ACTIVE MODE / REASON / COOLDOWN
//  - MARKET STATE ROUTER MUST EXPLAIN RANGE/TREND/IMPULSE/PULLBACK/EXHAUSTION/DEAD/CHAOS
//  - OPPORTUNITY SCANNER MUST EXPLAIN A+/B/C MICRO CANDIDATES
//  - SCORE ENGINE MUST EXPLAIN FINAL SCORE / MIN SCORE / PASS OR WAIT
//  - FIRST ENTRY ENGINE MAY OPEN ONLY ONE FIRST ENTRY WHEN SCORE PASSES
//  - MICRO SCALP LAYER MUST USE SIRUS TP LOGIC, LOT FACTOR AND MICRO GUARDS
//  - DIRECTION REDIRECT MUST CHECK OPPOSITE SIDE WHEN ORIGINAL SIGNAL FAILS SOFT SCORE
//  - SIGNAL QUEUE MUST SAVE PASSED SIGNALS AND REPLAY THEM BEFORE EXPIRY
//  - BLOCK EXPIRY MUST TRACK TEMPORARY SOFT BLOCKS AND EXPIRE THEM BY BARS/SECONDS
//  - GRID / RECOVERY MUST MANAGE EXISTING SIRUS BASKET ONLY
//  - RISK ENGINE MUST CENTRALIZE HARD BLOCKS AND EMERGENCY CLOSES
//  - PREMIUM DASHBOARD MUST SHOW NEXT ACTION, RISK, BASKET, SIGNAL AND LAST REASON CLEARLY
//  - MISSED TRADE MEMORY MUST RECORD REPEATED SOFT MISSES WITHOUT BYPASSING HARD RISK
//  - VPS VALIDATION MUST EXPLAIN PC/VPS, TICK/BAR/TIMER, BROKER AND FINAL NO-TRADE REASON
//  - LEGACY UPGRADE PACK MUST REBUILD OLD SIRUS MODULES WITHOUT SILENT BLOCKS
//  - LEGACY PACK 2 MUST MANAGE TP CHAIN, ADVANCED RECOVERY AND BASKET TRAILING
//  - LEGACY PACK 3 MUST AUDIT NEWS, BROKER, CLOSED DEALS, CLIENT SAFETY AND DISASTER SL
//  - FIRST ENTRY AND GRID MUST NOT FIGHT EACH OTHER
//  - ANTI-OVERFILTER: most filters are score penalties, not silent blocks
//  - No silent block
//==================================================================//

enum ENUM_SIRUS_MODE
{
   SIRUS_MODE_AUTO        = 0,   // SIRUS AUTO (aqlli: bozorga qarab o'zi tanlaydi)
   SIRUS_MODE_BALANCED    = 1,   // SIRUS BALANCED (muvozanatli)
   SIRUS_MODE_HIGH_HUNTER = 2    // SIRUS HIGH HUNTER (agressiv)
};

// V112: how the trading-timeframe structure sits inside the higher-timeframe structure. This is the
// single reading that tells the EA whether a lower-TF move is the trend itself or a counter-move
// inside a bigger one - the distinction that decides whether fading it is smart or suicidal.
enum ENUM_STRUCT_CONTEXT
{
   STRUCT_CTX_UNCLEAR          = 0,   // neither frame shows a clean chain
   STRUCT_CTX_PARTIAL          = 1,   // only one of the two frames is clear
   STRUCT_CTX_ALIGNED_UP       = 2,   // both frames bullish - trend continuation upward
   STRUCT_CTX_ALIGNED_DOWN     = 3,   // both frames bearish - trend continuation downward
   STRUCT_CTX_PULLBACK_IN_UP   = 4,   // HTF bullish, trading TF bearish = pullback inside an uptrend
   STRUCT_CTX_PULLBACK_IN_DOWN = 5    // HTF bearish, trading TF bullish = bounce inside a downtrend
};

enum ENUM_MARKET_STATE
{
   MARKET_UNKNOWN    = 0,
   MARKET_TREND_UP   = 1,
   MARKET_TREND_DOWN = 2,
   MARKET_RANGE      = 3,
   MARKET_IMPULSE    = 4,
   MARKET_PULLBACK   = 5,
   MARKET_EXHAUSTION = 6,
   MARKET_DEAD       = 7,
   MARKET_CHAOS      = 8
};

enum ENUM_OPPORTUNITY_DIR
{
   OPP_DIR_NONE = 0,
   OPP_DIR_BUY  = 1,
   OPP_DIR_SELL = 2
};

enum ENUM_OPPORTUNITY_GRADE
{
   OPP_GRADE_NONE     = 0,
   OPP_GRADE_C_MICRO  = 1,
   OPP_GRADE_B        = 2,
   OPP_GRADE_A_PLUS   = 3
};

enum ENUM_OPPORTUNITY_TYPE
{
   OPP_TYPE_NONE                  = 0,
   OPP_TYPE_RANGE_EDGE            = 1,
   OPP_TYPE_SWEEP_REJECTION       = 2,
   OPP_TYPE_NEAR_ZONE_REACTION    = 3,
   OPP_TYPE_FAKE_BREAKOUT_RETURN  = 4,
   OPP_TYPE_PULLBACK_CONTINUATION = 5,
   OPP_TYPE_EXHAUSTION_REVERSAL   = 6,
   OPP_TYPE_MOMENTUM_SCALP        = 7,
   OPP_TYPE_SESSION_SCALP         = 8,
   OPP_TYPE_BREAKOUT_CONTINUATION = 9,
   OPP_TYPE_TREND_RIDE            = 10,
   OPP_TYPE_SWING_CONTINUATION    = 11,
   OPP_TYPE_MA_BOUNCE             = 12,
   OPP_TYPE_DONCHIAN_BREAKOUT      = 13,
   OPP_TYPE_CONSECUTIVE_CANDLES    = 14,
   OPP_TYPE_DXY_CONFIRMED_TREND    = 15,
   OPP_TYPE_EXPANDING_VOLATILITY   = 16,
   OPP_TYPE_MTF_UNANIMOUS          = 17,
   OPP_TYPE_EQ_ZONE_TREND          = 18,
   OPP_TYPE_VOLUME_PUSH            = 19,
   OPP_TYPE_VWAP_BOUNCE            = 20,
   OPP_TYPE_ZONE_RETEST             = 21
};

// ----------------------------------------------------------------------------
// V228b: forward declarations, generated from the call graph. MQL5 resolves a call to
// a function defined later only when it has seen a declaration first. Rather than
// reordering forty thousand lines, every function that is called before its own
// definition is declared here, ahead of the first one in the file.
// ----------------------------------------------------------------------------
double NewsInProgress(string &detail);
bool BreakConfirmedTwoLevels(const double level, const int dir, string &detail);
double CurrentBasketPoints(const long direction, const double avg_price);
double Pack2BasketTPForOrders(const int orders, const double base_tp);
double FailedBreakStrengthBoost(const double level, const bool as_resistance, string &detail);
int FailedBreakCount(const double level, const bool as_resistance, int &bars_since_last, string &detail);
double ReachAfterNextRung(string &detail);
double BasketReachability(double &distance_atr, string &detail);
int LadderOrders();
double LadderMultiplier();
double RegimeContradiction(const int basket_dir, string &detail);
int ConsecutivePressureDir(int &run_len, double &avg_body, string &detail);
int LiveBarRead(int &dir, double &weight, string &detail);
double SingleCandleDominance(int &dir, string &detail);
double CandleParticipation(const int shift);
double AutoGridBaseDistance();
double LiveBarProgress(const ENUM_TIMEFRAMES tf);
double ComputeRoomToTP();
void UpdateBlockExpiryEngine(const string source);
double BasketTPForOrderCount(const int orders);
double ZoneMapNearestResistance(const double price);
double ZoneMapNearestSupport(const double price);
double ZoneMapStrength(const double level);
bool CloseSirusBasket(const string reason);
// Stage 12 profiler segments (26_Measure.mqh)
#define MB_PROF_TICK     0
#define MB_PROF_PRE      1
#define MB_PROF_BRAIN    2
#define MB_PROF_SCAN     3
#define MB_PROF_GUARDS   4
#define MB_PROF_GRID     5
#define MB_PROF_ENTRY    6
#define MB_PROF_POST     7
#define MB_PROF_PANEL    8
#define MB_PROF_SHADOW   9
#define MB_PROF_SEGS     10
void MBLiveSweepUpdate();   // stage 14 live sweep - called by the event engine above its definition
bool MBLiveSweepFresh(const int dir, string &what);
bool MBMomentumNow(const int dir);
void MBProfBegin(const int seg);
void MBProfEnd(const int seg);
string MBProfText();
void MBShadowOnDecision(const bool ready, const string reason);
void MBShadowOnEntry(const int dir, const double price);
void MBShadowUpdate();
void MBDailyReportCheck();
void MBShadowFlush();
bool MBShadowValveOn(const int g);   // a quality gate relaxed by the shadow ledger
string MBShadowPanelText();
int MBBiasAlign(const int dir);
int MBFastEntryType();
int MBEntryQualityNow();
bool MBJudgeBypassOn();
int MBJudgeBypassMin();   // opportunity type of the brain / fast entry just found   // dir x Market Brain bias (+3 with ... -3 against)
bool MBStandsInFor(const int dir, const bool location_gate);   // Market Brain owns the duplicate old gates - read by the entry gates before its definition
int MBBrainScoreRelief(const int dir, string &why);   // score the Market Brain adds to a detector setup it agrees with
bool MBCashbackTempo();   // cashback tempo switch - read by the entry judge before its definition
bool RebateTrailingOn();   // cashback trailing switch - read by the basket trailing long before its definition
double GridDistanceForNextOrder(const int current_orders);
void PremiumVisualDeleteExact(const string suffix);
double ATRPointsManual(const ENUM_TIMEFRAMES tf, const int period, const int start_shift);
void LocalStructureUpdate();
double GridDirectionDoubt(const int basket_dir, string &detail);
string SituationName(const int sit);
int LocalSwingShape(int &steps, double &conviction, string &detail);
string CandleLearningText();
int LiveBarEvolution(int &dir, double &weight, string &detail);
int CandleHTFAgreement(const int lower_dir, double &htf_body, string &detail);
string CandlePatternName(const int p);
string CandleStateName(const int st);
int CandleSequenceRead(int &dir, double &conf, string &detail);
double ZoneMapNextSupportBelow(const double price, const double above_level);
double ZoneMapNextResistanceAbove(const double price, const double below_level);
double ZoneMapStrengthByTouches(const double level);
double RegimeGridFactor();
void ArmRecordOutcome(const int reason_code, const int outcome, const int bars_waited);
int SetupArmConsensus(string &detail);
double DominantSidePressure(double &trend, bool &divergence, string &detail);
double ScaleAdjustedPoints(const double configured_points);
void ResetScoreEngine(const string reason);
int MinScoreForContext(const bool is_micro);
void ClearTempBlock(const string reason);
void ApplyExpiredBlockSoftPass();
void ChainPatternPredict(const int pattern, const int dir, const double price);
void ChainPatternSettle();
int ChainExpectation(double &confidence, string &detail, int &pattern);
double LiquidityPoolAhead(const int entry_dir, int &pool_dir, double &pool_price,
                          double &pool_distance_pts, string &detail);
bool ZonePriceInsideBand(double &band_lo, double &band_hi, string &detail);
bool ZoneRoleAmbiguous(string &detail);
double RoomToTargetPoints(const int entry_dir, string &detail);
bool StructureAgainstBasket(string &detail);
double BaseBasketTPPoints();
void RebateTimeFlatManage();
void WeekendGuardManage();
void HourBayesRecord(const int h, const bool won);
void DayOfWeekBayesRecord(const int dow, const bool won);
double ImpulseCorrectionRetracePercent();
int TrendReversalDirection(string &reason, bool &divergence_confirmed);
int MTFAlignmentCount(const int direction);
int ZMTFIndex(const ENUM_TIMEFRAMES tf);
void ZoneMapRefreshSwingCache();
void MarketStructureRead();
double ZoneMapConfluenceCount(const double level);
void ZoneReliabilityRecord(const double level, const bool held);
double ScoreBandWinRate(const int score, int &samples);
void BayesSaveState();
bool GridSafetyDangerNow(string &reason);
void BreakSequenceRead();
double NextGridLot(const double last_lot, const int current_orders);
bool GridCanOpen(string &reason);
void RefreshGridDashboardStats();
bool DailyProfitGovernorAllowsRecovery(string &reason);
bool OperatorControlAllowsRecovery(string &reason);
bool LicenseGuardAllowsEntry(string &reason);
bool SetupDoctorAllowsEntry(string &reason);
double MarginRescueGridLot(const ENUM_ORDER_TYPE order_type, const double intended_lot, string &detail);
bool MarginAllowsOrder(const ENUM_ORDER_TYPE order_type, const double lot, string &reason);
double NormalizeVolumeSafe(double volume);
double AutoLotBase();   // FIX(affordability-basis): declared here because LadderIsAffordable() calls it ~1700 lines before its definition
bool GetSirusBasketStats(int &orders, double &total_volume, double &avg_price, double &profit,
                          long &direction, double &last_price, double &last_lot, datetime &last_time);
// FIX(scalein-orphan): ScaleInDueLot() needs a LIVE basket read, and it sits ~13k lines above the definition
double AutoGridMultiplier();    // FIX(affordability-geometric-step): same reason - the ladder projection needs the real widening factor and its clamps
double AutoGridMinDistance();
double AutoGridMaxDistance();
double LotForCurrentEntry(const bool apply_side_effects = true);
bool LegacyManualNewsBlocked();
bool LegacyAllowsGrid(string &reason);
bool Pack4MiniAllowsEntry(string &reason);
bool Pack4MiniAllowsGrid(string &reason);
bool RCSettingsAllowsEntry(string &reason);
bool RCSettingsAllowsGrid(string &reason);
bool LegacyDeepParityAllowsEntry(string &reason);
bool LegacyDeepParityAllowsGrid(string &reason);
bool DeepBOSAllowsEntry(string &reason);
bool DeepBOSAllowsGrid(string &reason);
bool DeepTopZoneAllowsEntry(string &reason);
bool DeepTopZoneAllowsGrid(string &reason);
bool DeepNewsVolatilityAllowsEntry(string &reason);
bool DeepNewsVolatilityAllowsGrid(string &reason);
bool AdaptiveEntryTimingAllowsEntry(string &reason);
bool AdaptiveEntryTimingAllowsGrid(string &reason);
double DeepRecoveryAdjustGridDistance(const double base_distance);
double DeepRecoveryAdjustGridLot(const double base_lot);
bool AdaptiveRecoveryAllowsGrid(string &reason);
double RegimeTuneAdjustGridDistance(const double base_distance);
double RegimeTuneAdjustGridLot(const double base_lot);
bool MarketRegimeAutoTuneAllowsEntry(string &reason);
bool MarketRegimeAutoTuneAllowsGrid(string &reason);
double ClientSafetyAdjustGridDistance(const double base_distance);
double ClientSafetyAdjustGridLot(const double base_lot);
double PresetHardeningAdjustGridDistance(const double base_distance);
double PresetHardeningAdjustGridLot(const double base_lot);
bool SmartClientSafetyAllowsEntry(string &reason);
bool SmartClientSafetyAllowsGrid(string &reason);
string ShortText(const string text, const int max_len);
void ModuleHealthUpdate();
string ModuleHealthLine(string &silent_out);

// ----------------------------------------------------------------------------
// V250b: forward declarations, generated from the call graph. MQL5 resolves a call to
// a function defined later only when it has seen a declaration first.
// ----------------------------------------------------------------------------
void DecisionLog(const string verdict, const string why);
void MBCandleEngineUpdate();   // 17_Candle_Engine
void MBEventEngineUpdate();    // 18_Event_Engine
void MBBrainUpdate();           // 20_Market_Brain
bool MBVetoAllowsEntry(const int dir, string &why);   // 21_Direction_Veto
bool MBEntryJudgeAllows(const int dir, string &why);   // 23_Entry_Engine
double MBEntryLotAdjust(const double lot);
void MBPositionBrainUpdate();   // 24_Position_Brain
bool MBGridAllows(const int dir, const int orders, string &reason);
bool MBRecoveryExit(string &why);
bool MBRunnerManage(const double basket_points, const double tp_points, string &why);
bool MBRunnerActive();
string SirusOrderComment(const string kind);   // brand comment - used by the grid before its definition
bool MBProfSlow();   // 26_Measure - read by the panel (25)
void MBStructBreakRecord(const int tfi, const int dir, const int type, const double lvl,
                         const MqlRates &r[], const int n, const int s, const int sw, const double atr);   // 20b - called by 18
void MBLiquidityMapUpdate();   // 20a - called by CoreUpdate (16)
void MBStructUpdate();   // 20b - called by CoreUpdate (16)
void MBLocationUpdate();   // 20c - called by CoreUpdate (16)
bool MBLocalBasketExit(const double profit, string &why);   // stage 16 smart exit - read by the basket exit check above its definition
bool MBBasketBreakEvenExit(const double basket_points, const double profit, string &why);
string MBPositionText();
void MBMemoryOnEntry(const int dir, const double price);   // 22_Memory
void MBDrawWatermark();          // 25_Visual_Design
void MBDeleteWatermark();
void MBDrawPanel();
void MBDeletePanel();
void MBDeleteAllVisuals();
bool MBFastEntryCandidate(int &dir, string &why);
void MBFastEntryFilled();
int MBFastEntryScore(const int min_required);   // 23_Entry_Engine
void ReasonCodeEntry(const string kind, const ENUM_ORDER_TYPE type, const double lot, const double fill_price, const ulong ticket);   // 90_Reason_Code
void ReasonCodeGrid(const ENUM_ORDER_TYPE type, const double lot, const double fill_price, const ulong ticket, const int orders_before);
int NewsOwnerState(string &why);
bool NewsOwnerBlocksEntry(string &why);
bool NewsOwnerBlocksGrid(string &why);
void ScenarioRestore();
void ScenarioStore(const int bucket);
void ScenarioTrack();
double ScenarioProjection(const int dir, int &samples);
string ScenarioText();
int FailedBreakRead(string &detail);
int FailedBreakCost(const int dir, string &detail);
string FailedBreakText();
double OldLevelAhead(const int dir, double &age_days, int &touches, string &detail);
void OldLevelScan(const int dir);
int OldLevelCost(const int dir, string &detail);
string OldLevelText();
void HTFBiasScan();
int HTFAgainstCost(const int dir, double &extra_location, string &detail);
string HTFBiasText();
void AdaptRecord(const bool won);
string AdaptText();
string QuietCause();
void QuietTick(const bool entry_allowed);
string QuietText();
string ValveName(const int v);
int ValveForGate(const int gate_id);
bool ValveIsOff(const int v);
void SafetyValveCheck();
string GateName(const int id);
int GateClassify(const string why);
void GateRecord(const string why);
string GateTallyText();
void LocationBrainScan();
int LocationBrainVerdict(const int dir, string &why);
void LocationBrainRecordStop(const int dir, const double price);
void LocationBrainClearStop(const int dir);
string LocationBrainText();
int GlobalTrendDirection(double &strength, string &detail);
double HigherScaleConflict(const int entry_dir, string &detail);
void PreparedLevelsRefresh();
double PreparedLevelHit(const int dir, string &detail);
double PreparedContextScore(const int dir, const double level, string &note);
double EntryPositionInMove(const int entry_dir, double &travelled_pts, string &detail);
double LateEntryBetterPrice(const int entry_dir);
double CalendarThinness(string &detail);
double FillQualityPenalty(const int dir, double &better_price, string &detail);
double ProtectedZoneNear(const double price, const int dir, double &strength, string &detail);
void ReplayQueuedSignal();
void Pack3ClosedDealAnalytics();
bool BasketPremiseDead(string &detail);
void ChooseLadderShape(const int dir);
void UpdateVPSLiveValidation(const string source);
void OnTimer();

// V31.6z NEW: from the "outside auditor" strategy-foundation review - 5 of 7 real detector
// types bet on price REVERSING (Range Edge, Sweep, Near-Zone, Fake Breakout Return,
// Exhaustion), only 2 bet on CONTINUATION (Pullback, Momentum). This matters because if a
// reversal bet is WRONG, grid recovery must then fight a REAL, ongoing trend - the single
// most dangerous scenario for a martingale-style system. Continuation bets, if wrong, fail in
// a more random way. This classification lets both first-entry scoring and grid caution treat
// the two risk profiles differently instead of identically.
bool IsReversalOpportunityType(const ENUM_OPPORTUNITY_TYPE type)
{
   // V31.6z43 fix: Zone Retest was missing from this list - conceptually it's a bounce bet at
   // a specific level (the newly-flipped zone), the same risk character as Near-Zone-Reaction,
   // so it should get the same extra scrutiny (higher score bar, faster-rising grid depth
   // threshold) as the other 5 reversal-type detectors.
   return (type == OPP_TYPE_RANGE_EDGE || type == OPP_TYPE_SWEEP_REJECTION ||
           type == OPP_TYPE_NEAR_ZONE_REACTION || type == OPP_TYPE_FAKE_BREAKOUT_RETURN ||
           type == OPP_TYPE_EXHAUSTION_REVERSAL || type == OPP_TYPE_ZONE_RETEST);
}

enum ENUM_SCORE_DECISION
{
   SCORE_DECISION_NONE       = 0,
   SCORE_DECISION_WAIT       = 1,
   SCORE_DECISION_PASS       = 2,
   SCORE_DECISION_MICRO_PASS = 3,
   SCORE_DECISION_HARD_BLOCK = 4
};

enum ENUM_MICRO_TP_MODE
{
   MICRO_TP_AUTO           = 0,
   MICRO_TP_FIXED          = 1,
   MICRO_TP_MAIN_PERCENT   = 2,
   MICRO_TP_DYNAMIC_MARKET = 3
};

enum ENUM_TEMP_BLOCK_TYPE
{
   TEMP_BLOCK_NONE        = 0,
   TEMP_BLOCK_SCORE_WEAK  = 1,
   TEMP_BLOCK_IMPULSE     = 2,
   TEMP_BLOCK_SOFT_SPREAD = 3,
   TEMP_BLOCK_ROOM_TO_TP  = 4,
   TEMP_BLOCK_MICRO_GUARD = 5,
   TEMP_BLOCK_QUEUE_WAIT  = 6,
   TEMP_BLOCK_REDIRECT    = 7,
   TEMP_BLOCK_BOS_RETEST  = 8,
   TEMP_BLOCK_ZONE_DANGER = 9
};
