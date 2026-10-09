# Auditor B - Direction sources and multi-timeframe integration

Scope: every module that produces a direction or a structure read, how M1..D1 cooperate, BOS / MSS /
sweep consistency, stale state, timeframe / indexing errors. READ-ONLY audit of /home/user/sirus at
branch claude/sharp-tesla-dgetgj. Citations are file:line in /home/user/sirus/Sirus unless noted.
Status vocabulary and finding categories as in BRIEF.md. "GUESS" marks anything not proven from code.

Runtime evidence used: the two shadow CSVs (older code, 06-09 Oct). Column `brain_bias` is
`G_MB_BIAS` at the decision (26_Measure.mqh:327 `G_SH[k].bias = G_MB_BIAS;`).
Summary of 2,065 rows (script: scratchpad/audit/b_csv.py, b_csv2.py):

| d*G_MB_BIAS | rows TP | rows GRID | GRID share |
|---|---|---|---|
| -3 | 41 | 9 | 18.0 % |
| -2 | 90 | 6 | 6.3 % |
| -1 | 570 | 52 | 8.4 % |
| +1 | 684 | 45 | 6.2 % |
| +2 | 197 | 17 | 7.9 % |
| +3 | 294 | 25 | 7.8 % |

* `brain_bias` is **never 0** in 2,065 rows; |bias| = 1 (TRANSITION) in 1,227 rows (59 %).
* TAKEN trades: 72 with the bias, 60 against it (TP 55 / GRID 5 against vs TP 63 / GRID 9 with).
  Only "strongly against" (-3) is measurably worse. This is RUNTIME evidence that G_MB_BIAS was
  produced and consumed; it is not evidence about any sub-rule below.

---------------------------------------------------------------------------------------------------

## 1. Module inventory (producer table)

Call order per real tick (16_Dashboard_Core.mqh:841-915): OnTick -> TickVelocity, LiveSample,
`LocalStructureUpdate`, `LocalStructureBreakUpdate` (BEFORE `UpdateBarTracker` increments
`G_BARS_SEEN`) -> CoreUpdate: UpdateBarTracker -> MBCandleEngineUpdate -> MBEventEngineUpdate ->
MBBrainUpdate -> MBLiquidityMapUpdate -> MBStructUpdate -> MBLocationUpdate -> MBMicroUpdate ->
MBCost -> MBMarketStateTick/Update -> MBHTFZonesUpdate -> MBLowerHighUpdate -> MBPositionBrain ->
UpdateKalmanTrendFilter -> UpdateDailyBias -> ... UpdateMarketStateRouter -> (if ScanDue) scanner,
score, redirect, legacy packs (DeepHTF / DeepBOS) -> gates -> grid -> first entry.
Timer passes do NOT run any of these (FIX(timer-trades), 16:856-863).

| Module / function | Purpose | TF(s) and bar index actually used | Cadence | Outputs | Consumers | Status |
|---|---|---|---|---|---|---|
| 17 MBCandleEngineUpdate (17:700) | candle intent, 3-bar pressure, accel, impulse, ATR | M1,M5,M15,H1,H4 via MBTF(); `CopyRates(...,0,90)`, reads r[1..6] (closed); ATRPointsManual(tf,14,1) | once per new bar of each TF | G_MB_ATR[], G_MB_LAST[], G_MB_BULL/BEAR, G_MB_ACCEL(_DIR), G_MB_SEQ*, G_MB_IMP_*[0..1], G_MB_SPEED | 18,19,20*,21,23,24 (everything brain) | STATICALLY PRESENT |
| 17 MBLiveCandleUpdate (17:531) | forming M1 displacement | M1 bar 0 (o/h/l) + bid, bar 1 hi/lo | every tick | G_MB_LIVE_DIR, G_MB_LIVE_FAILED | 20 MBLayerMicro, 21 V4, 23 triggers, 24, 90 | STATICALLY PRESENT |
| 17 MBPressureSide (17:588) | side of 3-candle pressure, fallback c1 vs c6 >= 1 ATR | closed bars of tfi | on demand (globals per bar, iClose live read) | int | 20,20c,20g,21,23,24 | STATICALLY PRESENT |
| 18 MBEventEngineUpdate (18:672) | SWEEP, FAKE_BREAK, RECLAIM, ACCEPTANCE, DISPLACEMENT, BOS/MSS, REJECTION, COMP_RELEASE | M1..H4 + KEY(on M5); `CopyRates(tf,0,N)`, evaluates closed bars s>=1; replay 100 bars on first run | once per new bar per TF; catch-up up to 30 bars | G_MB_EV[240] ring (40 per TF), G_MB_TREND[], G_MB_LAST_BROKEN_*; calls MBStructBreakRecord | 20,20b,20c,20f,21,23,24,25,90 | STATICALLY PRESENT |
| 18 MBLiveSweepUpdate (18:1003) | tick-level sweep of M5/M15/H1 swings, PDH/PDL, Asia, round numbers | pools rebuilt per M1 bar from closed bars; pierce on bid per tick | every tick | G_MB_LSW_* | 20 (dead-lock lift, MBReactionCandle), 20b, 20c, 20d, 21 V4, 23 SWEEP | STATICALLY PRESENT |
| 19 MBZoneRead / MBZoneEntryVerdict (19:357,442) | zone role history (support/resistance, flips, sweeps) | M5 closed bars 1..N | memo per M5 bar per level | SMBZone | 21 V2/V3/council, 23 judge | STATICALLY PRESENT |
| 20 MBBrainUpdate (20:962) | global bias (7 states), thesis, DOL, dealing range, local thesis | per-TF states from events (M5..H4); M15 state drives direction; H1/H4 only change confidence or via HTF liquidity reversal | once per M1 bar (first tick) | G_MB_BIAS, G_MB_BIAS_CONF, G_MB_TF_STATE[], G_MB_TH_*, G_MB_DEAD_*, G_MB_DR_*, G_MB_DOL, G_LOC_TH_* | 20d,20f,21,23,24,25,26,26b,26c | **RUNTIME VERIFIED** (brain_bias column) |
| 20 MBRegimeUpdate (20:362) | TREND / RANGE / EXPANSION / COMPRESSION + box | M15 closed 1..50; H4 box CopyRates(H4,1,20); M5 vol pct CopyRates(M5,1,1460) | once per M15 bar | G_MB_RG, G_MB_RG_DIR, G_MB_RG_HI/LO, G_MB_H4_HI/LO, G_MB_VOL_PCT | 20c,20f,23,24,25 | STATICALLY PRESENT |
| 20 MBLayerLocal (20:664) | local (M5) direction | impulse M5, MBM5StructDir, net c1-c7 M5, local thesis, P5 | on demand | int | 20 (local level, handoff), 20g, 21 council, 23, 25 | STATICALLY PRESENT |
| 20 MBLayerMicro (20:714) | micro (M1) direction | live M1, P1, G_MB_TREND[0] | on demand | int | **panel only** (25:681) | STATICALLY PRESENT (no trading consumer) |
| 20a MBLiquidityMapUpdate (20a:324) | multi-TF liquidity levels, sweeps, traps | swings M5/M15 (len 3), H1/H4 (len 2), D1 PDH/PDL; status judged on the **closed M5 bar only** for every TF | once per M5 bar | G_LQ[], G_LQ_SW_*[2] | 20b lock/reversal, 20c, 20f | STATICALLY PRESENT |
| 20b MBStructBreakRecord / FollowThrough (20b:128,186) | run of breaks, protected level, break quality | per break TF (M5..H4); follow-through = next bar only | per event / per M1 bar | G_ST_SEQ[], G_ST_PROT_HI/LO[], G_ST_LB_* | 20b lock, 20b MBM5StructDir, 20f, 21 council | STATICALLY PRESENT |
| 20b MBLockEvaluate (20b:325) | direction lock | M15 runs (or M5 + G_MB_TREND[2]), M15 close iClose(M15,1) | once per M5 bar | G_ST_LOCK_* | 20d,20f,21 V7,23 MBDirOk,25,26b | STATICALLY PRESENT |
| 20b MBReversalCompute (20b:379) | reversal stage 0..6 against P = lock or **G_MB_TREND[2]** | events + M5 closes + M1 CopyRates from MSS close | once per M1 bar, stage>=4 re-checked live | G_ST_REV_DIR/STAGE/EXT/MSS | 14 (MBReversalUnlocked), 20c,20f,21 V0/council,23 | STATICALLY PRESENT |
| 20b MBM5StructDir (20b:98) | intact M5 structure dir | G_MB_TF_STATE[1] + G_ST_PROT_*[1] + iClose(M5,1) | on demand | int | 20 MBLayerLocal, 21 council 1e, 21 V0 W5, 20b MBLockBlocks | STATICALLY PRESENT |
| 20c MBLocationUpdate (20c:290) | leg origin/target, exhaustion pressure, taken liquidity | origin iHighest/iLowest(M15,24,0) incl. live; M5 closed 1..6 | once per M1 bar | G_LX_ORIGIN/TARGET/PRESS/TAKEN, G_LX_PRESS_HIST | 20c MBLateBlocks (21 V8, 23), 20d, 20f, 24, 26b | STATICALLY PRESENT |
| 20f MBMarketStateUpdate (20f:160) | 14 named states + scenario %, narrative | M1 closed 1..6 + other brain globals | once per M1 bar | G_MST_STATE/DIR, G_SC_* | G_MST_*: only MBStateQualityAdj (23:497) + panel; G_SC_*: **panel only** | STATICALLY PRESENT |
| 20g MBHTFZonesUpdate (20g:104) | fresh H1/H4 supply/demand | CopyRates(tf,1,N) closed; release by iClose(M15,1) | once per H1 bar | G_HZ_* | 21 council 1h | NOT YET VERIFIED (added 09 Oct) |
| 20g MBLowerHighUpdate (20g:177) | M15 lower high / higher low | CopyRates(M15,1,24) closed; release iClose(M5,1) | once per M5 bar | G_LH_LEVEL/TOP | 21 council 1g | NOT YET VERIFIED |
| 04 UpdateKalmanTrendFilter (04:1435) | alpha-beta filter of HTFTrendTF=H1 closes | CandleClose(H1,1) | once per H1 bar, **live steps only, not seeded from history** | G_KALMAN_TREND/LEVEL/BAR_COUNT | DeepHTFTrendDirection, HTFStructureBias, DetectTrendState, MTFAlignmentCount, 05:4528, 08:2521, 08:5666 | STATICALLY PRESENT |
| 04 GlobalTrendConfidence (04:125) | signed D1/H4/H1 ADX blend | ADX shift 1 (closed) | 1-slot cache per M1 bar & dir | double, G_GLOBAL_TREND_FADING/TURNING | DeepHTF bind (15:2339), score | STATICALLY PRESENT |
| 04 LocalStructureUpdate / BreakUpdate (04:2540, 2373) | M5 swing staircase, invalidation, break event | LocalStructureTF=M5 closed bars; break confirm CandleClose(M15,1) | once per M1 bar (keyed on G_BARS_SEEN); break check every tick | G_LS_DIR/STATE/INVALIDATE, G_LSB_BREAK_* | 05,08 score (8 sites), 09, 10, 11 | STATICALLY PRESENT |
| 05 UpdateMarketStateRouter (05:3183) | legacy MARKET_STATE (trend/range/impulse/chaos...) | DetectTrendState: Kalman H1 + SMA(M15,50) closed | once per M1 bar | G_MARKET_STATE | 05,07,08,09,11,12,13,14,15 (≈60 refs) | STATICALLY PRESENT |
| 05 CandleHTFAgreement (05:2031) | M15 candle agrees with entry | M15 bar 1 **and live bar 0** | on demand | int | 05:199 grid doubt, 08:4033 score, 16 panel | STATICALLY PRESENT |
| 15 DeepHTFTrendDirection (15:2292) | HTF direction | Kalman H1 if ready, else SMA50/200 H1 (closed), then overridden by GlobalTrendConfidence(D1/H4/H1 ADX) when |conf|>=0.35 | on demand (uncached) | int | 07:2471 tie-break, 08:1432 score, 15 DLP (G_DLP_HTF_DIR), 21:685 V0 (only when bias==0) | STATICALLY PRESENT |
| 15 DeepM15StructureDirection (15:2353) | "M15 structure" | M15 closed close vs 36-bar range: breakout = with, **bottom 25% = +1, top 25% = -1** (fade) | per scan | G_DLP_STRUCT_DIR | 15 DLP score only | STATICALLY PRESENT |
| 15 DeepDetectBOSDirection / UpdateDeepBOSChochRetest (15:2601,2701) | legacy BOS / CHoCH | M15 close(1) beyond HighestHigh(M15,34,2)+180 pts | per scan | **G_DBOS_DIR latched** | 11:4558 lot guard, 13:836 grid sense 14, 15 score/blocks | STATICALLY PRESENT |
| 11 HTFStructureBias (11:4499) | H1 bias | Kalman, else close(H1,1) vs close(H1,20) | on demand | int | HTFStructureLotAdjust (14:915) | STATICALLY PRESENT |
| 11 MTFAlignmentCount (11:2603) | # TFs agreeing | SimpleTFDirection M15/H4 (closed), Kalman H1, D1OverallDirection | on demand | int | score | STATICALLY PRESENT |
| 11 UpdateDailyBias (11:3966) | prior-day colour + today's gap | D1 bar 1 + today's open | once per D1 | G_DAILY_BIAS, G_PDH/PDL | 07:2469 tie-break, 08:2227 score | STATICALLY PRESENT |
| 11 ZoneMapNearestSupport/Resistance (11:3694) | nearest swing level | M5,M15,M30,H1,H4,D1,M1 swings, closed shifts | swing cache per M1 bar; memo per tick | double | 20 (local thesis, handoff), 21 V2/V3/council, 23 judge, many legacy | STATICALLY PRESENT |

Outputs nobody uses for trading (only panel / text):
* `MBStructDamage()` (20b:581) - **no caller at all** (NEVER CALLED).
* `MBLayerMicro()` (20:714) - only 25_Visual_Design.mqh:681.
* `G_SC_BULL/BEAR/CHOP`, `G_SC_*_TGT`, `G_SC_*_INV` (20f:245-260) - only MBScenarioPanelText.
* `MBLxRising()` (20c:327) - only MBLocationPanelText (20c:403).
* `G_MST_STATE/G_MST_DIR` - only `MBStateQualityAdj` (23:497, a judge-quality +/-) and the panel.
No reader of a never-written global was found among the direction globals checked
(G_LX_TARGET, G_LEGACY_NEAREST_*, G_LS_DIR, G_DLP_*, G_ST_*, G_MB_DR_* all have writers).

---------------------------------------------------------------------------------------------------

## 2. Multi-timeframe map: who decides what

| TF | Brain (20*) | Legacy (04/05/08/11/15) |
|---|---|---|
| tick / M1 live | G_MB_LIVE_DIR, live sweeps, V4 acceleration (also forming M5 candle), MBCandleConfirms live-invalidation | LiveBarRead/LiveSampleUpdate (05), CandleHTFAgreement live M15 bar |
| M1 closed | M1 pressure, M1 impulse speed, MST sensitivity, local-thesis origin, micro control | SignalTF=M1 detectors, CoreBarTF=M1 cadence (G_BARS_SEEN) |
| M5 | **local layer** (MBLayerLocal), MBM5StructDir, liquidity-map status, lock cadence, zone roles, council 1b/1e, exhaustion pressure | LocalStructureTF=M5 (G_LS_DIR), break events (G_LSB_*) |
| M15 | **global direction**: `bias = s15` (20:981-1010), regime / range box, lock runs and lock release, lower-high rule, HTF-zone release close, fresh-break council | StructureTF=M15 (DeepBOS, DeepM15Structure, DetectTrendState SMA), LocalTrendTF=M15, CandleHTFTimeframe=M15 |
| H1 | dealing range, H1 state = confidence only (+8/-10), HTF liquidity reversal -> TRANSITION, HTF zones | **HTFTrendTF=H1**: Kalman, DeepHTF SMA fallback, HTFStructureBias, MTFConfirmTF |
| H4 | H4 state = confidence only (+6/-6), HTF reversal, H4 box, HTF zones, map pools | GlobalTrendConfidence H4 ADX, MTF H4 |
| D1 | PDH/PDL pools (event KEY, map, DOL) | GlobalTrendConfidence D1 ADX (primary, binds DeepHTF), G_DAILY_BIAS, D1OverallDirection |

Final arbiter of a FIRST ENTRY's direction: every first entry goes through `MBVetoAllowsEntry`
(14_Risk_Gates_Entry.mqh:4850) and `MBEntryJudgeAllows` (14:4858). Inside, V0 (`MBPermissionCheck`,
21:629) decides on `a = dir * G_MB_BIAS`. So G_MB_BIAS (M15 structure) is the direction rule; H1/H4/D1
only reach the gate when `G_MB_BIAS == 0` (21:685) - and runtime shows the bias was never 0.
`MBStandsInFor` (21:560) makes legacy HTF score gates stand aside whenever `dir*G_MB_BIAS >= 1`.

### Pairs that can disagree with no rule for who wins (or a rule only in some consumers)

| # | Source A | Source B | Where they collide | Rule? |
|---|---|---|---|---|
| C1 | G_MB_BIAS (M15 structure) | DeepHTFTrendDirection / Kalman H1 / D1-H4-H1 ADX | V0 vs lot trims `HTFStructureLotAdjust` (14:915), `FirstEntryTrendGuardLotAdjust` (14:916), grid sense 14 (13:842), DLP score | Gate: bias wins (HTF used only if bias==0). Lot & grid: legacy HTF applied regardless - a brain-approved entry is trimmed to 0.4x and its grid scored "HTF-against". No rule. |
| C2 | G_MB_BIAS | G_MB_RG_DIR (M15 efficiency-ratio regime) | 20f:214 `MST_STRONG_TREND; sd = G_MB_RG_DIR` with only `MathAbs(G_MB_BIAS) >= 3`; 20f:215 MST_TREND | none - see F5 |
| C3 | G_MB_BIAS | G_MB_TREND[2] (raw last M15 break, failed breaks included) | reversal stage base P (20b:381) vs MST/micro primary (20f:189, 20d:147) | partial: lock first, then each module picks a different fallback |
| C4 | G_MB_TF_STATE[1] / MBM5StructDir (event swings, failed-break filtered) | G_LS_DIR (04 swing staircase, no break feedback) | both called "M5 structure"; brain council vs legacy score (08:3763-3800) | none - see F7 |
| C5 | event-engine SWEEP (per-TF ATR, max 1 ATR, judged on the level's own TF) | liquidity-map sweep (M5 ATR for every TF, no max pierce, judged on M5 closes) | lock arming (20b:333-341 takes the newer), reversal stage 1 (20b:404), 20c pressure, MST LIQ_HUNT | "newer wins" in lock/reversal; others OR them - see F4 |
| C6 | G_DAILY_BIAS (yesterday colour / gap) | G_MB_BIAS | detector tie-break 07:2468, score 08:2227 | none (brain veto later) |
| C7 | G_DBOS_DIR (M15 34-bar range break, latched) | G_MB_TF_STATE[2] | lot guard, grid sense 14, DBOS score | none - see F8 |
| C8 | DeepM15StructureDirection (range-position fade) | M15 structure (brain) | DLP score | none |
| C9 | G_MARKET_STATE (legacy router: Kalman H1 + SMA M15) | G_MST_STATE (brain) | legacy detectors / grid / lot vs judge quality | none (two state machines) |
| C10 | MBLayerLocal / MBM5StructDir / local thesis | G_MB_BIAS | V0, council, MBDirOk | **explicit rules exist** (MBLocalOkFor, council 1e/4, MBRangeRules) |
| C11 | HTF zones 20g, lower-high 20g, zone role 19, ZoneMap | each other | council 1g/1h/3, V2/V3, judge zone_ok | OR-ed blocks: any block wins (a rule, but a block from one can contradict a "holds" from another) |

---------------------------------------------------------------------------------------------------

## 3. BOS / MSS / sweep definitions across modules

| Concept | Module | Definition | Buffer / ATR base | Bar |
|---|---|---|---|---|
| BOS/MSS | 18 MBDetectStructure (18:539) | first close beyond most recent swing (len 2 HTF / 3 M1); type from **G_MB_TREND** | 0.05 x ATR(tf) | closed |
| Failed break (state) | 20 MBBreakFailed (20:148) | either of next **2** closes back through by 0.1 ATR(tf) | 0.1 ATR(tf) | closed |
| Failed break (run/quality) | 20b MBStructBreakRecord / FollowThrough (20b:163-176, 196-212) | **next 1** close back through | 0.1 ATR(tf) | closed |
| Failed break (G_MB_TREND) | 18:572/591 | **never** - G_MB_TREND flips on every break, failed or not | - | - |
| "Holding" HTF break | 21 MBFreshBreakAgainst (21:316) | M5 close not back through by 0.3 ATR(M5); MBBreakFailed | 0.3 ATR(M5) on an M15/H1 level | closed M5 |
| BOS (legacy) | 15 DeepDetectBOSDirection (15:2601) | M15 close beyond 34-bar Highest/Lowest (range break, not swing) | fixed 180 points ($0.18) | closed; **latched forever** |
| structure break (legacy) | 04 LocalStructureBreakUpdate (04:2373) | M5 close beyond last swing (depth 2) AND M15 close beyond | none | closed, checked every tick |
| SWEEP | 18 MBDetectLiquidity (18:396) | wick >= max(0.1 ATR(tf), spread), <= 1 ATR(tf), close back within 3 bars of pool TF | ATR of the pool TF | closed bars of the pool TF |
| FAKE_BREAK | 18 | closed beyond by 0.25 ATR, back within 5 bars | ATR(tf) | closed |
| Map sweep | 20a MBLqStatusUpdate (20a:240) | M5 bar pierces any-TF level by max(0.1 ATR(M5), spread), M5 close back; **no max pierce** | **ATR(M5) for H4/H1 levels too** | closed M5 |
| Map "taken" | 20a harvest (20a:196) / status | close beyond by 0.05 ATR(tf) / 2 M5 closes beyond | mixed | closed |
| Pool "taken" (event engine) | 18 MBPoolIntactBefore (18:381) | **wick** beyond by min_pierce | ATR(tf) | closed |
| Live sweep | 18 MBLiveSweepUpdate | bid beyond by max(0.15 ATR(M1), spread), back within 45 s, max MBSweepMaxATR x ATR(pool TF) | ATR(M1) entry, ATR(tf) max | tick |
| Confirmation of a reversal | 20 MBReversalAfterCalc (20:238), 21 V1 (21:122), V1 "answer" (21:96-101), dead-lock lift (20:1168), MBContradiction (20:626), 24:221, 90:89 | BOS/MSS counted **without** MBBreakFailed | - | - |
| Same, filtered | 20b MBStFind/MBStCount (20b:241,279), 20 MBLastStructureEvent, 21 MBFreshBreakAgainst | BOS/MSS **with** MBBreakFailed | - | - |

---------------------------------------------------------------------------------------------------

## 4. Findings

### B-F1 - A failed break still flips G_MB_TREND, so the next real break is typed MSS: trends read as TRANSITION
* Category: CONDITION WRONG. Severity: **P2** (V0 then admits only reversal types in the trend's
  own direction; continuation entries blocked / late). Status: STATICALLY PRESENT; runtime
  CONSISTENT (59 % of shadow rows have |bias| = 1) but causation is a GUESS.
* Where: 18_Event_Engine.mqh:564, 572, 584, 591 (`MBDetectStructure`).
```
int type = (G_MB_TREND[tfi] < 0) ? MB_EV_MSS : MB_EV_BOS;      // 18:564
...
G_MB_TREND[tfi] = 1;                                          // 18:572 (every break, failed or not)
```
* Cause: the brain's state skips a failed break (`MBLastStructureEvent` -> `MBBreakFailed`,
  20:170-195), but `G_MB_TREND` - which decides BOS vs MSS for the NEXT break - is set by the failed
  break too. Uptrend; an M5/M15 low is grabbed (close below the swing low, then two closes back) ->
  G_MB_TREND = -1. Price resumes and closes above the next swing high -> recorded as **MSS**, so
  `MBTimeframeState` (20:306) returns TRANSITION_UP (+1) instead of BULLISH (+3).
* Effect: on M15 this makes `G_MB_BIAS = +/-1`; V0 (21:675-680) then refuses BUY continuation types
  in an uptrend ("only reversal / reclaim entries") unless MBTransitionConfirmed; the judge asks for
  a reversal proof (23:571-578). `G_MB_TREND[2]` is also P for the reversal stages (20b:381) and the
  M5 lock-run condition (20b:354), so a grab also re-bases the "reversal" against the wrong side.
* Reproduce: journal `[SIRUS STRUCTURE] M15 ... FAILED` (or a SWEEP/FAKE-BREAK that MBBreakFailed
  skips) followed by `[SIRUS EVENT] M15 MSS BULLISH` while the previous valid M15 event was a bullish
  BOS; dashboard bias TRANSITION_UP in a rally; `[SIRUS VETO] BUY ... V0 permission: TRANSITION_UP -
  only reversal / reclaim`.

### B-F2 - Failed-break handling is applied in some readers and not in others
* Category: CONFLICT. Severity: P2. Status: STATICALLY PRESENT.
* Unfiltered (count a liquidity grab as structure): `MBReversalAfterCalc` confirmations
  (20:238 `ty == MB_EV_MSS || ty == MB_EV_BOS`), V1 confirmations and "answer back"
  (21:96-101, 21:122), dead-thesis lock lift (20:1168), `MBContradiction` (20:626), 23:232,
  24:221, 90:89. Filtered: MBLastStructureEvent, MBStFind/MBStCount (20b:241,279),
  MBFreshBreakAgainst (21:345).
* Two different failure tests: `MBBreakFailed` = either of the next 2 closes back by 0.1 ATR;
  `G_ST_LB_Q` / `G_ST_SEQ` = next 1 close only (20b:163-176, 196-212). A break whose 1st follow
  bar holds and 2nd closes back is FAILED for the bias but CONFIRMED and counted in `G_ST_SEQ` for
  the lock run (20b:353-354), the lock refresh (20b:311 `G_ST_LB_Q[2] >= ST_Q_VALID`) and the council
  release (21:343 `G_ST_LB_Q[1] >= ST_Q_VALID`).
* Effect: the same grab can (a) confirm a reversal for G_MB_BIAS transitions (20:998-1000) and V1
  (blocking the trend side) while (b) being ignored by the M5/M15 state. Owner case of 08-Oct 19:40
  (comment at 20:142-147) is fixed only for the state, not for V1 / bias transitions.
* Reproduce: a sweep -> displacement -> BOS whose 2nd bar closes back: look for `[SIRUS VETO] ... V1
  reversal: ... + M5 BOS` (or a bias TRANSITION with "M5 reversal: ... BOS") right after the BOS is
  dropped from the M5 state.

### B-F3 - `MBM5StructDir` mixes a failed-filtered state with a protected level taken from the latest break (failed or WEAK included)
* Category: CONFLICT. Severity: P3. Status: STATICALLY PRESENT.
* 20b:98-110 reads `G_MB_TF_STATE[1]` (failed breaks skipped) but `G_ST_PROT_LO/HI[1]`, which
  `MBStructBreakRecord` (20b:137-143) overwrites on **every** recorded break of that direction,
  including WEAK and later-FAILED ones. The same pattern is in `MBFreshBreakAgainst`'s live branch
  (21:357 `G_ST_PROT_*[2]`) and lock protected level (20b:357-359).
* Effect: after a failed bullish stop-run the protected low moves up to the grab leg's low; the next
  ordinary pullback closes below it and the "intact M5 structure" reads 0 (council 1e and the local
  layer lose the structure) while the state still says up. GUESS on frequency.

### B-F4 - Three different sweep definitions; the liquidity map judges H1/H4 levels on M5 with M5 ATR and no maximum pierce
* Category: CONFLICT. Severity: P2 (lock arming / reversal stage 1 / MST LIQ_HUNT can fire on what the
  event engine calls a break). Status: STATICALLY PRESENT.
* 20a:247 `double pierce = MathMax(MBSweepMinATR * atr5, spread);` and 20a:265-268
  `if(s * (ext - L) >= pierce) { if(s * (c - L) < 0.0) { ... sweep` - any size wick, judged on one
  M5 close, for every level class including H4 and PDH/PDL. Event engine: pierce <= 1 ATR **of the
  pool's TF**, judged on that TF's closes (18:449-466). Pool "taken": map = close beyond, event engine
  = wick beyond (18:381-393).
* Consumers that take whichever is newer or OR them: `MBLockEvaluate` (20b:333-341), `MBReversalCompute`
  stage 1 (20b:398-407), `MBLxPressure` (20c:180-186), `MBLxTakenAhead` (20c:250-259), MST LIQ_HUNT /
  FAKE_BREAKOUT (20f:194-196, 207-208).
* Effect: an H4 high run through by 2 ATR(M5) with one M5 close back below = a MAJOR buy-side map
  sweep (can arm a BEARISH lock with displacement + 2 breaks, and stage-1 a bearish reversal) while the
  H4 bar closes far above (event engine: ACCEPTANCE / BOS up).
* Reproduce: `[SIRUS LIQUIDITY] BUY-SIDE liquidity swept @ <H4 level> | MAJOR` while the same H4 bar
  later prints `[SIRUS EVENT] H4 ACCEPTANCE BULLISH` or `H4 BOS BULLISH`.

### B-F5 - Market state STRONG_TREND / TREND / EXPANSION take a direction from a different source than the bias, with no sign check
* Category: CONDITION WRONG. Severity: P3 (judge quality +/-4..8, scenario panel). Status: STATICALLY
  PRESENT.
```
else if(G_MB_RG == MB_RG_TREND && MathAbs(G_MB_BIAS) >= 3 && (G_ST_LOCK_DIR == 0 || G_ST_LOCK_DIR == G_MB_RG_DIR))
     { st = MST_STRONG_TREND; sd = G_MB_RG_DIR; }                                   // 20f:213-214
... { st = MST_EXPANSION; sd = (G_MB_RG == MB_RG_EXPANSION) ? G_MB_RG_DIR : P; }   // 20f:211-212
```
* Cause: |bias| >= 3 is checked, not its sign vs `G_MB_RG_DIR` (net M15 close over 20 bars). In a
  fast move (SN_FAST / SN_EXPAND, incl. any day with `G_MB_VOL_PCT >= 92`) the state's side is P
  (lock / bias / G_MB_TREND[2]) - the old side - not the move's side.
* Effect: `MBStateQualityAdj` (20f:303-325, used at 23:497) gives +4 to the stale side and -8 to the
  side the market is actually expanding toward.
* Reproduce: panel "Holat: KENGAYISH ▲" during a fast drop; `[SIRUS STATE] ... -> KENGAYISH ▲` while
  G_MB_LIVE_DIR = -1.

### B-F6 - RANGE EDGE treats price outside the box as "at the edge" - a breakout up is sold, a breakdown bought
* Category: CONDITION WRONG. Severity: **P1 candidate** (wrong-direction first entry), guarded only by
  other vetoes. Status: STATICALLY PRESENT, NOT YET VERIFIED at runtime.
```
double pos = (bid - G_MB_RG_LO) / (G_MB_RG_HI - G_MB_RG_LO);          // 23:1016
int rd2 = (pos <= 0.20) ? 1 : ((pos >= 0.80) ? -1 : 0);                // 23:1017
bool range_edge = (rg == MB_RG_RANGE) && (... || (dir < 0 && rg_pos >= 1.0 - RegimeRangeEdge)); // 23:333
```
* Cause: no upper/lower bound (pos > 1 or < 0 = price already beyond the box). The box / regime are
  refreshed once per M15 bar (20:362-366), so for up to 15 min after a breakout `G_MB_RG == RANGE`.
* Effect: BRAIN RANGE SELL above a broken range top (pos 1.1) if a trigger candle prints; the judge
  also scores it as "range_edge". MBRangeRules also lets it through a weak opposite bias (21:642).
  It is stopped only if council / V4 / fresh-break / MBM5StructDir happen to fire.
* Reproduce: `BRAIN RANGE SELL: 1xx% of the M15 range` (percentage > 100) or `BRAIN RANGE BUY: -x%`.

### B-F7 - Legacy M5 structure (G_LS_DIR) keeps the old direction through a break; score rewards the wrong side
* Category: SIGNAL/DATA LOST. Severity: P2 (wrong-side score after a breakdown; P1 only if the brain veto
  misses). Status: STATICALLY PRESENT.
* `LocalStructureUpdate` (04:2540) builds G_LS_DIR from confirmed swings only; a breakdown makes no new
  confirmed swing low, so G_LS_DIR stays "rising" with the same invalidation for the whole fall. The
  break is noticed in `LocalStructureBreakUpdate` but never fed back into G_LS_DIR. The scorer
  (08:3763-3800) gives `+LocalStructureScore` to BUY / penalty to SELL with no check that price is
  already beyond `G_LS_INVALIDATE`; 08:3813-3826 even pays a "structure ends N pts away" bonus using
  `MathAbs` (beyond counts as near).
* Also: after a break, 04:2435-2438 re-arms `G_LSB_LAST_DIR = G_LS_DIR` with the same price in the same
  call, so the next tick "breaks" again and `G_LSB_BREAK_BAR = G_BARS_SEEN` (04:2420) is refreshed every
  tick - `RecentStructureBreak` freshness stays 1.0 for as long as the swings do not change (stale
  "fresh break"; journal spam `[SIRUS v224 BREAK]` every tick when verbose).
* Conflicts with the brain: `MBM5StructDir` turns 0 at the first M5 close below its protected low.
* Reproduce: in an M5 breakdown, `G_SCORE_DETAIL` contains `-N against rising ...` for SELLs and
  `[SIRUS v224 BREAK] rising structure ended` repeats on consecutive ticks.

### B-F8 - G_DBOS_DIR (legacy BOS) is latched forever and feeds lot and grid
* Category: SIGNAL/DATA LOST (stale). Severity: P3. Status: STATICALLY PRESENT.
* 15:2724-2743: `if(bos_dir != 0) { ... G_DBOS_DIR = bos_dir; }` - never aged, never cleared by a
  failed break, not reset on reinit; the only write in the code base (grep `G_DBOS_DIR *=`).
* Consumers: `FirstEntryTrendGuardLotAdjust` (11:4558-4560, lot x0.4 when "against"), grid sense 14
  (13:836), DBOS score/blocks. A range break from yesterday still trims today's lot and marks grid
  adds "BOS/CHoCH-against".

### B-F9 - Kalman threshold is 5 points ($0.005 per H1 bar) on a 3-digit symbol: the "unified" H1 direction is never neutral
* Category: CONDITION WRONG. Severity: P3. Status: STATICALLY PRESENT.
* 01_Inputs.mqh:4197 `KalmanTrendMinPoints = 5.0`; used raw as points (`G_KALMAN_TREND / _Point >
  KalmanTrendMinPoints`) in 04:1500, 11:2325, 11:2612, 11:4510, 15:2306, 08:2522, 08:5669 - no
  ScaleAdjustedPoints. With _Point = 0.001 any slope above half a cent per hour is a trend.
* Effect: DeepHTFTrendDirection, HTFStructureBias, MTF H1 vote and DetectTrendState's slope test reduce
  to sign(slope); `HTFStructureLotAdjust` (11:4528) trims every entry on the other side of that sign.
* Related: the filter is not seeded from history (04:1448-1452) and `KalmanWarmupBars = 30` H1 bars,
  so for 30 hours after every terminal/VPS restart four "unified" consumers each fall back to a
  different method (SMA50/200 stack 15:2311-2332, close vs 20 bars 11:4515-4525, SimpleTFDirection
  11:2615, SMA slope 04:1513-1527) that can disagree - the comment "brief warmup window" (11:4506) is
  wrong. `G_KALMAN_*` is also not reset on a symbol change (no reset in OnInit).

### B-F10 - Higher timeframes cannot veto: H1/H4 state only changes confidence; DeepHTF only consulted when bias is 0 (never at runtime)
* Category: CONFLICT (C1). Severity: P2 (design gap; first entries against H1/H4/D1 structure are
  limited only by lot trims). Status: STATICALLY PRESENT; RUNTIME: bias never 0 in 2,065 shadow rows,
  so the W5 branch (21:685) effectively never ran in the measured version.
* 20:981 `int bias = s15;` - s1h/s4h only add +8/-10 and +6/-6 to G_MB_BIAS_CONF (20:1096-1097).
  The only HTF direction input is an H1/H4/KEY liquidity reversal (20:1013-1027).
* At the same time the legacy layer applies the HTF view to the same trade without knowing the brain's
  decision: lot x HTFStructureCounterLotFactor (14:915), x0.4 (14:916), grid sense 14 (13:842).
  So the same direction is approved by one layer and penalised by the other; nothing reconciles them.
* Runtime note: d*bias = -3 had 18 % GRID vs 6-8 % elsewhere (n = 50) - the only alignment bucket that
  mattered; this does not test H1/H4 directly (INSUFFICIENT EVIDENCE for HTF value).

### B-F11 - Event ring holds 40 events per TF; the structure owner can be evicted, and ages are wall-clock
* Category: SIGNAL/DATA LOST. Severity: P3. Status: STATICALLY PRESENT; frequency is a GUESS.
* 18:98 `#define MB_EV_PER_TF 40`; displacements, sweeps, reclaims, rejections, comp-releases share the
  ring with BOS/MSS. `MBLastStructureEvent` (20:170) has no fallback once the last BOS/MSS is overwritten
  -> state NEUTRAL (or the failed-skip walks to an evicted slot and returns -1).
* 18:195 `long age = (long)(TimeCurrent() - ev.time) / sec;` - ages count weekend / daily-break hours, so
  on Monday every M5..H4 event of Friday is past `MBEventRelevant` (12 bars) even if only a few bars
  printed (H4: 12 bars = 48 h of wall time = one weekend). V1, reversal confirmations, contradiction,
  MBThesisInvalidation all start Monday blind.

### B-F12 - No reset of brain state on symbol change / reinit
* Category: SIGNAL/DATA LOST (stale). Severity: P3 (P1 only if the EA is moved to another symbol on the
  same chart). Status: STATICALLY PRESENT.
* OnInit (Sirus_Brain_V8.mq5:61-770) resets legacy G_* but not G_MB_EV[], G_MB_EV_FILLED[] /
  G_MB_EV_BAR[], G_MB_TREND[], G_ST_* (lock, runs, protected levels), G_LQ[] map, G_HZ_*, G_MB_BIAS,
  G_KALMAN_*, G_DBOS_DIR. The authors' own FIX(reinit-bar-rewind) comment (mq5:115-121) states globals
  survive a reinit. After a symbol switch the replay is skipped (`G_MB_EV_FILLED` already true,
  18:695) and the old symbol's levels/events/lock steer the new one until they age out.

### B-F13 - CandleHTFAgreement lets the first ticks of a new M15 bar overrule the closed M15 candle
* Category: CONDITION WRONG. Severity: P3. Status: STATICALLY PRESENT.
* 05:2060-2070: live body ratio `MathAbs(c0 - o0) / (h0 - l0) >= CandleHTFMinBody (0.40)` with no
  minimum range; a bar 2 ticks old has ratio ~1.0, and `effective = live_dir` overrides the closed
  candle. Consumers: score (08:4033), grid doubt (05:199).

### B-F14 - Late-leg guard goes silent once price is beyond its target
* Category: CONDITION WRONG. Severity: P3 (late / chasing entry, not direction). Status: STATICALLY
  PRESENT.
* 20c:133 `if(T <= 0.0 || dir * (T - px) <= 0.0) return 0.0;` - G_LX_TARGET is chosen once per M1 bar
  "ahead of price"; when price runs through it intrabar, MBLegPct = 0 -> `MBLateBlocks` late branch
  (20c:375-384) cannot fire exactly when the leg has overshot.

### B-F15 - Several direction globals are once-per-bar and read intrabar
* Category: CONFLICT / stale. Severity: P3 (P2 for the first minutes after a flip). Status: STATICALLY
  PRESENT.
* G_MB_BIAS, G_MB_TF_STATE, G_LX_*, G_MST_*, G_MC_* refresh once per M1 bar on its first tick; lock
  once per M5; HTF zones once per H1; regime / range box once per M15; Kalman once per H1; daily bias
  once per D1. Bias hysteresis can hold an old view up to 4 M1 bars (20:1050-1081: `need = 4` at 20:1071 when M1
  and M5 candles still push the old way). Live protection exists only for the opposite side (V4
  21:211-250, MBCandleConfirms live check 17:621-631, MBStructStageFor live 20b:566-577,
  MBFreshBreakAgainst). Effect: after an M15 flip, the new side is V0-blocked (a = -3/-2) for 2-4 min
  while the old side is council-blocked -> silence / late first entry (by design, but no rule).
* `LocalStructureUpdate` runs in OnTick before `UpdateBarTracker` (Sirus_Brain_V8.mq5:1412 vs 16:868),
  so its per-bar recompute happens one tick late on every new M1 bar (P4).

### B-F16 - Smaller items
* 1-slot cache thrash: `GlobalTrendConfidence` (04:125-150) caches one (bar, direction); callers
  alternate +1 / -1 (DeepHTF always asks +1, scorer asks per entry_dir) -> recomputes D1/H4/H1 ADX
  repeatedly per tick. Category RESULT IGNORED / cost, P3.
* G_DAILY_BIAS (11:4013) uses a fixed 100-point ($0.10) neutral band, less than half the 240-point
  spread: "today's gap" sign is mostly noise, and it wins the detector tie-break before DeepHTF and
  without G_MB_BIAS (07:2466-2471). CONFLICT C6, P3.
* DeepM15StructureDirection (15:2376-2380) calls the bottom quarter of a 36-bar M15 range "+1" and the
  top quarter "-1" (a fade), named and scored as "M15 confirms" structure - opposite meaning to the
  brain's M15 structure in a trend. P3/P4.
* ZoneMap support scan prefers a swing up to `ZoneNearAboveTolerance` (900 pts) ABOVE price
  (11:3399) while the resistance scan prefers levels genuinely ahead (11:3360-3374). V3 for a SELL
  uses that "support" with `room_pts = (price - z.hi)/_Point` (21:195) - negative when the level is above
  price -> "V3 no room". GUESS: depends on MBZoneRead role/pending_break for a just-broken level.
* `MBEventFind` uses `MBRelevantLimit(1)` for KEY events (18:1102) while `MBEventRelevant` uses 2x for
  KEY (18:228) - two relevance windows for the same event. P4.
* NEVER CALLED: `MBStructDamage()` (20b:581). Panel-only: MBLayerMicro, G_SC_*, MBLxRising.
* ATR = 0 divisions: none found unguarded in 17/18/19/20*/21/23 (each division sits behind an
  `atr > 0` early return or ternary).
* Series indexing: all CopyRates in 17/18/20*/20g set `ArraySetAsSeries(..., true)`; the two
  non-series copies (18:364 Asia range, 18:847 KEY intact check) only take min/max - correct.

---------------------------------------------------------------------------------------------------

## 5. Producer -> consumer map for the main direction outputs

| Output | Written by | Read by (trading) | Read by (panel/log only) |
|---|---|---|---|
| G_MB_BIAS | 20:1105 | 20 (local, handoff, regime rules), 20d:147, 20f:189/213-216/245, 21 V0/council/MBStandsInFor/MBGlobalWeak, 23 judge/candidates/MBDirOk/MBTieFirst, 24, 26c, 26b | 25, 26 (shadow CSV) |
| G_MB_TF_STATE[] | 20:975-976 | 20b MBM5StructDir, 21:355 fresh break, 23:267 dir_ok, 24 | 25 |
| G_MB_TREND[] | 18:572/591 | 18 BOS/MSS typing, 20 MBLayerMicro, 20b:356/381 lock/reversal, 20c:225, 20d:147/165, 20f:189 | - |
| MBLayerLocal() | 20:664 | 20 (local level, handoff), 20g:236, 21 council (1,4,1b,1d), 21:600 transition, 23 (judge, candidates) | 25 |
| MBM5StructDir() | 20b:98 | 20:689, 20b:599, 21:457 council 1e, 21:688 V0 W5 | - |
| G_ST_LOCK_DIR | 20b:362 | 20b MBLockBlocks (21 V7, 23 MBDirOk), 20d, 20f | 25, 26b |
| G_ST_REV_DIR/STAGE | 20b:379-489 | 14:4162, 20c:220, 20f:197-198, 21 V0/council, 23 BRAIN REVERSAL | 25 |
| G_LQ_SW_* | 20a:206-238 | 20b lock/reversal, 20c, 20f | 20a panel |
| G_HZ_*, G_LH_* | 20g | 21 council 1g/1h | 25 |
| G_MST_STATE/DIR | 20f:230-238 | 23:497 (quality only) | 25 |
| DeepHTFTrendDirection() | 15:2292 | 07:2471, 08:1432, 15 DLP, 21:685 | 16 |
| G_KALMAN_TREND | 04:1459 | 04 DetectTrendState, 05:4530, 08:2521/5668, 11:2325/2612/4509, 15:2305 | - |
| G_DBOS_DIR | 15:2742 | 11:4558 lot, 13:837 grid, 15 DBOS | 16 |
| G_DAILY_BIAS | 11:4018-4023 | 07:2469 tie-break, 08:2227 score | 16 |
| G_LS_DIR | 04:2662 | 05:330/358, 08 (6 sites), 09:2497, 10 (3 sites), 11:582 | 16 |
| G_MARKET_STATE | 05 router | ~60 legacy refs (07,08,09,11,12,13,14,15) | 16, 90 |
