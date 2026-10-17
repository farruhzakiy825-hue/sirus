# F (round 2) - Detectors and score engine internals

Auditor F, round 2. Code: branch `claude/sharp-tesla-dgetgj` HEAD `5c348e9` (packages 1-5 applied).
The audit was READ-ONLY on /home/user/sirus. Line numbers are in the per-file sources (`Sirus/NN_*.mqh`).
Status words and categories follow BRIEF.md. **No compiler and no tester were available, so nothing here is
RUNTIME VERIFIED unless a shadow-CSV number is quoted.** The CSVs prove only the gate *family* "score".

Scope:
- 07_Detectors.mqh (all detectors, ConsiderOpportunity: voices, tie-break)
- 05:4575-4700 sweep detectors
- 08_Scanner_Score.mqh: UpdateOpportunityScanner (consensus, clarity), UpdateSignalScoreEngine, CounterContextBlockNow, ApplyAntiOverfilterScoring, MinScoreForContext
- 06 SetupArm / SetupArmConfirmed, because they decide the score WAIT
- 15 legacy packs and 09 redirect / missed-memory / expiry, as far as they change the score

Round-1 items marked fixed in CHANGELOG (A1 arm guard in legacy/memory/expiry/queue, B-F7 LSDirEff,
package-5 tie-break, DeepM15 to MB M15, v180 valve, ct_valve) are not re-reported. Where a fix is
incomplete, that is reported (F14).

---------------------------------------------------------------------------------------------------

## 0. Top findings (ranked)

| # | ID | Cat | Sev | One line |
|---|----|-----|-----|----------|
| 1 | F1 | CONDITION WRONG | P1 | The "Pullback continuation" detector fires only on the COUNTER-trend side in Balanced mode. MARKET_PULLBACK is direction-less, and both sides also get +2 "aligned with trend/pullback". |
| 2 | F3 | WRONGLY BLOCKS | P2 (P1 risk) | Cashback mode: the spread-economics arm is always true (spread/TP*1.5 = 1.6 against a 0.26 threshold). The scanner's side is held in WAIT on every scan, and the brain fast path is barred on that side too. Only the "last winning direction" (20 bars) escapes. |
| 3 | F2 | CONDITION WRONG | P2 | An arm that confirms is re-armed in the SAME pass by every arm site except counter-zone. A confirmed setup never gets out, and the FILL arm's "take it anyway" cannot happen. |
| 4 | F6 | CONDITION WRONG | P2 | The penalty is clamped to 10 at 08:6538, before the V287 "objection headroom" (08:6849) and the Hunter cap term (08:6512). Both are dead. The penalty ceiling is 10; the bonus ceiling is 26-31, plus legacy bonuses with no cap. Any setup with roughly 9+ bonus PASSes whatever objects. |
| 5 | F7 | CONFLICT | P2 | The legacy packs add bonuses with no cap (bypassing BonusCap, MaxTotalScoreBonus, MaxTrendAlignBonus), while their penalties are 0 or get only the room left under 10. LegacyRecalculateDecision then turns WAIT into PASS. The bonuses come from Kalman H1 (DLP), the latched G_DBOS_DIR (DBOS) and the M1 candle colour (DET). |
| 6 | F4 | SIGNAL/DATA LOST | P2 | An arm is aged and expired only inside the score engine, and only when the scanner has an opportunity. A stale G_ARM_DIR keeps blocking the brain fast path on that side (14:4219) and every relief path. |
| 7 | F5 | CONFLICT | P2 | The scan redirect runs on an arm-WAIT and does not check the arm. The opposite side then escapes the same (symmetric) objection, because SetupArm will not arm a second side. Redirect also undoes consensus flips. |
| 8 | F10 | CONDITION WRONG | P2 | CounterContextBlockNow does `return false` right after allowing a counter-HTF entry (08:1533). Counter-trend entries skip the range-breakout counter-fade penalty (section 3) and the fresh-impulse wait (section 11) that with-trend entries pay. |
| 9 | F9 | CONFLICT | P2 | Consensus counts "voices" from detectors that read the same M15/M1 candle. 3 extra voices can flip a level-based setup up to 4 points stronger. The arbiter is never asked. |
| 10 | F11/F12 | CONFLICT | P2/P3 | About 25 direction terms in the score, none read the arbiter. Several use the Kalman 5-pt H1 slope, D1 closes, G_DAILY_BIAS or latched G_DBOS_DIR. Nine terms reward counter-structure / mean-reversion entries. |

The others are F8 and F13-F22 (P3/P4), in section 6.

---------------------------------------------------------------------------------------------------

## 1. Detector table (07_Detectors.mqh + 05 sweep)

All detectors are enabled by default. The scanner runs about every 3 s (`ScannerEvaluateOnNewBarOnly=false`, 01:2362).
Each detector is called BUY first, then SELL (08:57-147), and `ConsiderOpportunity` keeps the best one.
Grades come from `GradeFromScore` 05:3566:
- A >= 7, B >= 5
- C_MICRO >= 3, only if micro_preferred
- otherwise NONE (dropped)
- Hunter mode adds +1 to the grade only (07:2420)

In MARKET_UNKNOWN only detectors 1-3 run (08:33-74).

| # | Detector (BUY / SELL lines) | TF / data | Gate state | Trigger (BUY; SELL mirrored) | Dir rule | Score -> grade | Issues |
|---|---|---|---|---|---|---|---|
| 1 | Sweep 05:4575 / 4642 | M1 bar1; level = LowestLow(M1,10, from bar 2), snapped to support within 50 pts (05:4563-4569) | ScannerAllowSweep | l1<lvl && c1>lvl && lowerWick/range>=0.35 | wick side | 3+2+1 (+1 RANGE/EXH, +1 volume, +1 wick sweep) = 6-9, A/B, micro | +1 for RANGE/EXHAUSTION state is charged again by the anti-overfilter (+1 range / +1 exhaustion, 08:647-651). In EXHAUSTION the state *is* the same bar-1 wick (05:3017). One wick, counted 3x (F15). |
| 2 | Fake breakout return 07:477 / 561 | M1, ZoneMap level near **bid+50** / **ask-50** | none | low<sup-50 in bars 2..7; c1>sup | return side | 3 + bull 1 + **strength 1 (always true after 07:504 check)** + trap +2/-3 + vol 1 = 1-8 | Constant +1 (F15). SELL search starts from ask: a 240-pt spread asymmetry (F20). |
| 3 | Near-zone reaction 07:650 / 714 | M1 bar1; level within 1500 pts of **bid** (BUY) / **ask** (SELL) | none | lowerWick>=20% && bullish close | wick side | 2+2+1+**1 (always)**+vol = **always 6-7 -> B** | Window shifted 240 pts for SELL (F20). "Near" = 1500 pts = 6.7x TP. |
| 4 | Range edge 07:778 / 818 | M1 c1 vs M5 20-bar hi/lo | G_MARKET_STATE RANGE/DEAD | near edge && wick>=0.28 | edge side | 2+2+1 = 4-5, B / micro | - |
| 5 | **Pullback continuation 07:858 / 890** | M1 c1,c2 | PULLBACK or TREND_UP (BUY) / PULLBACK or TREND_DOWN (SELL) | BUY: c1>c2 && bullish | candle colour | PULLBACK +2, cont +3, body +1 | **F1: in PULLBACK only the counter-trend side can fire, and only it reaches grade B in Balanced.** |
| 6 | Momentum 07:922 / 957 | M1 | IMPULSE or TREND | c1>c2, bullish, body>=0.55 ATR | candle | 3 (+2 in TREND) | In IMPULSE it scores 3 -> NONE (not micro): it fires only in TREND state. |
| 7 | Exhaustion 07:1029 / 1060 | M1 bar1 | EXHAUSTION (bar1 wick>=0.55) | lower>upper && lower/range>=0.55 | wick side | 4+1+multi(1) = 4-6, micro | The state and the detector are the same wick. |
| 8 | Breakout continuation 07:1095 / 1146 | M1 c1 vs ZoneMap level | none | c1>res+100*(strength-scaled), small upper wick, bullish | break side | 3+2+1+vol = 6-7 | Fires for 60 s on the closed bar even if bid fell back (F17). |
| 9 | Trend ride 07:1204 / 1254 | M15 ADX(>=25) and DI | none | strong DI, shallow pullback, bullish M15 c1 | DI side | 3+2+1+MTF 1 = 6-7 | Valid for the whole 15 min after the M15 close (F17). |
| 10 | Swing continuation 07:1309 / 1353 | M15 swings + live mid | none | HL & HH & mid>high1 | swing seq | 4+1+MTF = 5-6 | - |
| 11 | MA bounce 07:1399 / 1442 | M15 SMA | none | rising SMA, touch, bullish close above | slope | 2+2+2+1 = 6-7 | M15 staleness (F17). |
| 12 | Donchian 07:1489 / 1521 | M15, 20 bars | none | c1>HH(2..21) && bullish | break | 4+1+vol+MTF = 5-7 | M15 staleness (F17). |
| 13 | Consecutive candles 07:1557 / 1610 | M15 x3 | none | 3 bullish M15 bars | colour | 4 (+accel, -decel, +vol) | Same M15 bar as 9, 12, 15, 18, 19 (F9). |
| 14 | DXY confirmed 07:1663 / 1694 | DXY proxy + M1 c1 vs c_N | none | DXY inverse confirms && local up | DXY | 3+2+1 | Off in tester. |
| 15 | Expanding volatility 07:1729 / 1761 | M15 ATR fast/slow + M15 colour | none | expanding && bullish M15 c1 | **only the M15 candle colour** | 3+2+1 | Direction is one candle (F9). |
| 16 | MTF unanimous 07:1797 / 1818 | MTFAlignmentCount (M15/H4 SimpleTF, **Kalman H1 5-pt**, D1 closes) | none | 4/4 agree | legacy HTF | fixed 5 -> B | No timing content at all. Purely legacy HTF (F11). |
| 17 | EQ zone trend 07:1843 / 1878 | M15 ADX + H1 40-bar discount <=35% | none | strong trend && discount | trend | fixed 5 | - |
| 18 | Volume push 07:1917 / 1970 | M15 volume magnitude | none | N heavy-volume bars && bullish M15 c1 | **candle colour** (volume carries no sign) | 4+1+1-waning | (F9) |
| 19 | VWAP bounce 07:2026 / 2066 | M15 VWAP | none | above, touch, bounce | side | 1+2+3+MTF = 6-7 | M15 staleness. |
| 20 | Zone retest 07:2115 / 2255 | ZoneMap level at mid; flip or FailedBreakCount | none | dist 0..1500, touch within window, recovered | level side | 4+2+1+1+1 = 4-9 | Correct sides (FailedBreakCount `as_resistance=false` for BUY, 10:4986). |

### Direction correctness

- No sign error was found in detectors 1-4 and 6-20 (BUY uses lows/support/lower wick, SELL the mirror).
- The one real inversion is #5 (F1).
- Bid/ask asymmetries (F20) shift the SELL windows by one spread.
- Every detector reads closed bar 1 while the scanner re-runs every ~3 s, so an M1 signal lives up to 60 s and an M15 signal up to 15 min (F17).

### ConsiderOpportunity / consensus / clarity / tie-break (07:2387-2501, 08:154-205)

- **Voices.** Every graded detector adds a voice and its score to G_OPP_VOICES_* / G_OPP_SUM_* (07:2430-2431). The best setup per side is kept in G_OPP_SIDE_* (07:2434-2449).
- **Tie-break** (exact score AND grade): the brain bias wins (`MBBiasSignNow`, 07:2470), then G_DAILY_BIAS, then DeepHTFTrendDirection. This is the only place in 07/08 that reads the brain or arbiter. STATICALLY PRESENT.
- **Consensus flip** (08:154-189). If the losing side has `>= win_n + 3` voices and `win_best - lose_best <= 4`, the direction flips to the crowd and G_OPP_SCORE becomes lose_best. The arbiter is not consulted. See F9.
- **Clarity.** `G_OPP_DIR_CLARITY = (hi-lo)/hi` (08:198), read by the clarity cost gate at 14:4456. The same fact is also scored by DirectionalClarity, Ambiguity and Brain-conflicted (F16).

---------------------------------------------------------------------------------------------------

## 2. Score engine: MIN, arms, hard blocks

### MIN (G_SCORE_MIN_REQUIRED)

`MinScoreForContext` (08:528):
- Balanced 4 / micro 4
- Hunter 2 / micro 3

AUTO picks HIGH_HUNTER whenever spread <= 300 (04:1320) and the suitability score passes. At the ~240 spread, Hunter is probably the usual mode (guess, NOT YET VERIFIED).

Additions:

| Addition | Size | Line |
|---|---|---|
| RegimeScoreOffset | volatile +2 / quiet +1 | 06:1149 |
| Reversal types | +1 | 08:1970 |
| DEAD non-micro | +1 | 08:2302 |
| RANGE micro | -1 | 08:2306 |
| Hunter IMPULSE (floored at Balanced) | -1 | 08:2316 |
| Self-defense | +1 | 08:2325 |
| Hunter vs D1OverallDirection | raised to the Balanced bar | 08:2336 |
| Post-SL same direction | +3 | 08:2357 |
| DailyState | good day +2 / bad day +3 | 08:3117 |

Range: 2 to about 14.

### Arm sites (each `return`s with WAIT when SetupArm accepts)

| Site | Line | Reason | Trigger / confirmation | Reachability |
|---|---|---|---|---|
| Move extension >= climax ATR | 08:2856 | EXTENDED | 600-pt pullback then resume | STATICALLY PRESENT |
| **Zone edge** | 08:3158 | ZONE | price must reach the zone *median* and reject. **No distance limit** | almost every entry above a >=3-swing M15 support (F19) |
| Single dominant candle against | 08:4719 | EXTENDED | pullback | STATICALLY PRESENT |
| Consecutive pressure against | 08:4806 | EXTENDED | pullback | STATICALLY PRESENT |
| **Spread economics** | 08:4893 | STRUCTURE | close beyond ask/bid at arm time (06:1872) | **always true in cashback (F3)**; never in normal mode (240/2500*1.5 = 0.14) |
| Liquidity pool ahead | 08:5241 | ZONE | dip and reject | STATICALLY PRESENT |
| Late entry hold (continuation types) | 08:6288 | LATE | retrace price | STATICALLY PRESENT |
| Fill timing | 08:6330 | FILL | better price, or "take anyway" on expiry (06:1608) | the take-anyway path is broken by F2 |
| Counter-zone (wall) | 08:1377 (inside CounterContextBlockNow) | ZONE wall | close beyond wall +200 | 3500-pt window (F21). The only site with a confirm-skip (08:6746). |
| Counter-impulse | 08:1686 | EXTENDED | - | **dead**: the section needs `CounterImpulseHardBlock` (false, 01:?). The comment at 08:1680 claims otherwise (F18). |

### Hard blocks in 08

**Live with defaults:**
- ScoreHardBlockCheck safety block (chaos / spread unreadable or >= critical / no tick / stale tick), 08:564
- CounterContextBlockNow section 1, counter-zone (`CounterZoneHardBlock=true`, 01:6417), after the arm cycle
- CounterContextBlockNow section 2 tier C, the "naked" counter-HTF refusal (08:1510)

**Dead with defaults (flag false):**

| Block | Line | Flag |
|---|---|---|
| Spread-cost hard block | 08:4866 | SpreadCostHardBlock=false |
| Projection hard block | 08:5062 | ProjectionHardBlock=false |
| Impulse-end / impulse-against | 08:6556 | EnableImpulseEndHardBlock=false, EnableImpulseAgainstHardBlock=false |
| Blow-off | 08:6608 | EnableBlowOffHardBlock=false |
| Zone wall | 08:6665 | EnableZoneWallHardBlock=false |
| CounterContext sections 4, 5, 6, 7, 8, 9, 10, 12, 13 | - | their `*HardBlock` flags are false |
| Legacy news / roadblock | - | UseLegacyUpgradePack=false |

Round-1 A_entry_chain row 4 listed "blow-off 6649, wall 6696" as live directional HBs. They are not live with default inputs.

---------------------------------------------------------------------------------------------------

## 3. Bonus / penalty table (UpdateSignalScoreEngine, defaults from 01_Inputs)

How to read the table:
- **Group** = the cap bucket the term is charged to. Caps: TA = trend-align bonus (8), BC = brain penalty soft cap (12 + 35%), Q = quality (9), C = conditions (4), T = trend-against (6), I = impulse (5), S = structure (7/7), CND = candle (8/8, relevance-scaled), none = only the total caps.
- **"late"** = added after the group caps ran (08:5771-6095), so it escapes them (F13).
- **Dir** = with / against the entry direction, or "agn" (direction-agnostic).
- **Arb?** = could contradict the arbiter (H1/H4) or brain bias (F11/F12).

| Term (line) | Bonus / penalty | Data source | Dir | Group | Arb? |
|---|---|---|---|---|---|
| Arm confirmed (2003) | +3 | arm confirm (pressure / chain / memory / pattern / price) | with | none | double-counts pressure, chain, memory (F15) |
| FirstEntryReversalConsensus (2020) | +2 / -1 | ReversalConsensusScore | dir | none | OFF by default (`EnableFirstEntryReversalConsensus=false`); would duplicate 2462 |
| withBreakout (2045) | +2 | RangeBreakoutDirection | with | none | - |
| Anti-overfilter trend (634-644) | +2 / -2 | **G_MARKET_STATE** (Kalman H1 5-pt + M15 SMA) | with/against. **PULLBACK gives +2 to BOTH sides** | none | yes (F1, F11) |
| Range / exhaustion reaction (647-651) | +1 / +1 | G_MARKET_STATE + type | - | none | duplicates the sweep detector's +1 |
| Impulse risk (653) | -1 | G_MARKET_STATE IMPULSE | agn | none | - |
| Clean spread (660) | +1 | spread <= 300 | agn | none | **always true at 240**, while cashback arms on spread (F15) |
| Soft spread (662) | -1 | spread > 400 | agn | none | - |
| Room to TP (666-669) | +1 / -2 | M5 20-bar hi/lo vs TP | - | none | mostly constant +1 in cashback (TP 224) |
| Hunter mode (678) | +1 | mode | agn | none | - |
| MTFConfirm (2066) | +2 / -2 | close vs SMA, HTF | dir | BC | OFF (`EnableMTFConfirm=false`) |
| MTFConfidence (2094) | +2 / -2 | M15 ADX, **Kalman H1 (full at 15 pts)**, H1 ADX | dir | TA / BC | yes |
| DirectionalClarity (2126) | -0..4 | best opposing detector score | agn | BC | duplicate of 14:4456 and 6448 (F16) |
| Bayes type / hour / dow (2157-2215) | +/-1 each | own trade stats | agn | BC | - |
| **DailyBias (2218)** | +2 / -1 | **G_DAILY_BIAS** (yesterday colour / gap) | dir | BC | yes (asymmetric) |
| ADR exhausted (2241) | -4 | ADR used + today's dir | with today | BC | - |
| DXY (2265) | +1 / -1 | DXY proxy H1 | dir | BC | yes |
| Live velocity (2380) | +1 | tick spike vs bar1 close | with | none | - |
| Trend reversal (2417-2445) | +2 (+1 div) / -2 (-4) | swing + RSI (TrendReversalDirection) | dir | BC | - |
| Reversal consensus (2462-2496) | +3 / -3 / conflict -3 | swing, RSI, **latched G_DBOS_DIR** (05:4148), major sweep, engulfing | dir | TA / BC / T | stale (F14) |
| **MTF alignment (2501)** | +1 per TF (max 4) / -2, -4, -6 | M15 SimpleTF, **Kalman H1 5-pt**, H4 SimpleTF, **D1 closes** | dir | **not TA** / BC | yes (F11) |
| TrendStrengthAgainst (2560) | -0..4 | ADX | against | BC | yes |
| Major sweep (2586) | +2 / -2 | RecentMajorSweepDirection | dir | BC | sweep counted again (F15) |
| **EQ zone (2615)** | +2..6 / -2..6 | H1 40-bar premium/discount | **mean reversion** | Q / BC | **yes: a with-trend SELL in "discount" is charged up to 6** (F12) |
| Engulfing (2664) | +2 / -2 | M? engulfing | dir | BC (not CND) | candle counted outside the candle cap |
| Trend quality (2693) | +2 | ADX + MTF + ribbon + HH/HL | with | TA | yes |
| Global / local (2715) | +3 / -3 | GlobalTrendConfidence D1/H4/H1 ADX + local | dir | TA / BC | yes |
| Zone caution (2752-2797) | -3 near / -2 far | opposing zone <= far window | against | BC | - |
| Impulse confirmation (2808) | +2 / -2 | impulse candle | dir | BC | - |
| Move extension (2841) | -0..5 | MoveExtensionATR | with | BC | arm at climax |
| Exhaustion consensus (2888) | -3 / -6 | ADX slope, RSI, candles, DXY, DD | with | BC | - |
| Competing reversal (2912) | -2 | re-runs reversal detectors | against | Q / BC | - |
| Market structure (2964-3019) | -4 against, +2 BOS, -3 CHoCH | G_STRUCTURE_DIR swing chain | dir | T / TA | yes |
| Structure HTF (3021) | -4 fade / +2 aligned | G_STRUCTURE_CONTEXT | dir | T / TA | yes |
| Zone role ambiguous (3046) | -5 | ZoneRoleAmbiguous | agn | Q / BC | - |
| Scenario undecided (3061) | -2 | scenario probabilities | agn | C / BC | - |
| Chain expectation (3088) | +3 / -4 | event chain | dir | C / BC | - |
| Zone edge early (3131) | arm, else -4 | ZoneEdgePrices M15 | - | Q / BC | F19 |
| Second level (3186) | -4 | next zone | against | Q | - |
| **Situation (3238)** | +/- up to **8** | ReadSituation | dir | none / Q | largest single term |
| Candle sequence (3275) | +3 / -4 / +/-2 / -3 / -2 | M1 candles | dir | CND | - |
| Wick authorship x location (3354) | +/-1..5 | M1 wick + level | dir | CND | - |
| Participation (3400) | +/-3 | volume | dir | CND / Q / C | - |
| Opening bias (3441) | +/-0..2 | open | dir | CND | - |
| Candle patterns (3471) | +/-0..4 | 2-3 bar patterns | dir | CND | - |
| Live bar (3551) | +/-0..4 | forming bar | dir | CND | - |
| Entry bar placement (3618) | -1..6 | forming bar | - | Q | - |
| Structure MTF (3645) | +/-6, +/-5, -3 transition | StructureAlignment | dir | S / T / C | yes |
| **Structure maturity (3718)** | -4 with / **+4 fading against** | **LSDirEff** + maturity | counter-structure bonus | S | F12 |
| Local structure (3750) | +/-5 | LSDirEff, G_LS_* | dir | S / T | - |
| **Structure invalidation near (3804)** | **+2 for counter-structure** | G_LS_INVALIDATE | against structure | S | F12 |
| Structure break (3831) | +/-6 | G_LSB_* (from raw G_LS_DIR) | dir | S / T | - |
| **Structure confluence (3860)** | **+3 only when against LSDirEff** | structure end + zone | counter | S | F12 |
| Local swing shape (3883) | +/-5 | M5 swings | dir | S / T | - |
| Candle conflict (3920) | +/-6 | candle conflict | dir | CND / Q | - |
| Live evolution (3958) | +/-5 | forming bar | dir | CND / Q | - |
| Live approach (3995) | -0..3 | level ahead | - | Q | - |
| Candle HTF (4020) | -1..5 / +2 | M15 candle | dir | CND / T | - |
| Candle follow-through (4052) | +/-3 | candle record | - | **none / C** (outside CND) | - |
| Candle break quality (4091) | +0..4 / -2..4 | break candle | - | **none / Q** (outside CND) | - |
| Candle progress (4146) | -1..5 | progress | - | CND / Q | - |
| Dead market (4168) | -1..4 | MarketIsDead | agn | C | - |
| Live news (4184) | -1..5 | NewsInProgress | agn | C | - |
| Target band (4208) | -1..6 | TargetInsideBand | - | Q | - |
| Volatility shift (4242) | -1..4 | ATR shift | agn | C | - |
| Protected zone (4270) | -1..6 | old zones | - | Q | - |
| Wick order (4314) | +/-1..4 | M1 order | dir | CND / T | - |
| **Arrival (4351)** | +/-0..4 | arrival speed | fade vs continue | CND / Q | counter-trend fade bonus |
| Candle progression (4433) | +/-1..2 (fade side +) | body trend | dir | CND / I / T | F12 |
| Liquidity wick (4492) | +/-1..5 | wick tips | -lw_dir | CND / T | sweep again (F15) |
| Manipulation (4534) | +/-1..5, -1..4 unclear | two-sided sweep bar | dir | CND / C / T | sweep again |
| Global levels (4587) | -1..5 | round numbers / opens | - | Q | - |
| Reversal context / neckline (4626) | -1..7 | IsNecklineRetest | against | T / S | - |
| Band entry guard (4649) | -1..6 | band | - | Q | - |
| Sweep reversal (4673) | +/-1..6 | SweepReversalDir | dir | none / T / S | sweep again |
| Single candle (4709) | arm / -1..5 / chase -1..4 / +0..2 | dominant M1 bar | dir | I / CND / Q | - |
| Consecutive pressure (4797) | arm / -3..9 | M1 run | against | I | - |
| Streak awareness (4832) | -N | loss streak | agn | BC | duplicate of 6390 |
| Repeat mistake (4843) | -5 | losses near price | agn | Q / BC | - |
| **Spread economics (4861)** | arm, else -4; widening -2 | spread / TP | agn | C / BC | F3 |
| Session (4932) | -3 / -2 | session clock | agn | C / BC | - |
| Pressure (4959) | +2 / +3 / -2 | DominantSidePressure | dir | C / BC | also an arm-confirm source |
| Noise (4993) | -2 (TP scaled) | MarketNoiseLevel | agn | C / BC | - |
| Pattern memory (5088) | +2 / -2 | history | dir | C / BC | also an arm-confirm source |
| Forced flow (5118) | -5 / +2 fade | ForcedFlowDirection | dir | I / BC | - |
| Path density (5161) | -2 / +2 | zones ahead | - | C / BC | - |
| Participant (5188) | -2 / +2 | level profile | - | C / BC | - |
| Liquidity map (5229) | arm / -4 | pool ahead | - | Q / BC | - |
| Room (5261) | -4 | RoomToTargetPoints | - | Q / BC | - |
| Verdict (5282) | +3 / -4 / -2 split | MarketVerdictRead | dir | TA / T | yes |
| Break sequence (5317) | +3 / -5 | BreakSequenceRead | dir | TA / T | yes |
| Zone break (5341) | +3 / -5 | RecentZoneBreakDirection | dir | none / T | - |
| Session transition, weekend, gap (5371-5419) | -2 / -3 / -2 | clock | agn | C / Q | - |
| Gap-fill magnet (5422) | -4 | gap | against pull | Q | - |
| Collapse guard (5435) | -4 | fast move | with move | C | - |
| Local / global trend turning / fading (5453-5487) | -2 / -2 / -3 / -3 | trend flags | **agn (both sides charged)** | T | - |
| Recent extreme (5492) | -5 | M1 window | with move | I | - |
| Correction exhaustion (5523) | -5 | last impulse | against impulse | I | - |
| Zone thrust (5548) | -4 | RecentThrustDir | against thrust | Q | - |
| Counter-impulse (5565) | -5 | Spike / Sustained impulse | against | I | - |
| Ghost zone (5586) | -4 | ghost levels | into ghost | Q | - |
| Sustained exhaustion (5602) | -4 | exhaustion | with | I | - |
| Impulse correction (5615) | -4 | last impulse | against | I | - |
| Brain consensus (5670) | +2 / -(2+n) / -3 conflict | 11 categories incl. **Kalman H1 (cat_bigtrend)**, DXY, order flow | dir | TA / BC | yes |
| Score consensus thin (5860) | -0..3 | breadth | agn | C | - |
| Layer conflict (5884) | -1..5 | LayerContradiction | agn | C | duplicate of 2126 / 6448 |
| **DailyOpen (6123) - late** | +/-0..3 | day open | dir | T (after cap) | yes |
| **Volume divergence (6160) - late** | -1..4 with / +1..4 against | volume | counter bonus | CND / I (after caps) | F12, F13 |
| **Setup learning (6198) - late** | +/-N | per-type stats | - | Q (after cap) | - |
| **Calendar thin (6223) - late** | -1..5 | calendar | agn | C (after cap) | - |
| **Prepared levels (6245) - late** | +0..4 | prepared level | with | none | - |
| Reversal at extreme (6299) - late | +0..4 | EntryPositionInMove | reversal types | none | F12 |
| **GlobalTrend V273 (6348) - late** | -1..6 / +0..3 | CounterTrendAtLevel / GlobalTrendDirection | dir | T / S (after caps) | yes |
| **Streak scoring (6390) - late** | +0..3 / -0..5 | win / loss streak | dir / agn | C (after cap) | +3 for the last-won direction |
| **Scale hierarchy (6425) - late** | -1..7 | HigherScaleConflict (H4 80 bars) | against | T / S (after caps) | yes |
| **Ambiguity (6448) - late** | -1..5 | OppositeSideStrength (**raw G_LS_DIR**) | agn | C (after cap) | F14, F16 |

Then come the caps:
- trend-align 8 (5771)
- BonusCap soft 12 (5779)
- brain penalty soft 12 (5796)
- structure 7/7 (5956)
- situation suppress (5979)
- candle (6030)
- impulse 5, quality 9, conditions 4, trend 6 (6055-6095)
- total bonus 26 (+5 headroom, 6484-6503)
- penalty: eff cap (6525), then the **hard clamp to 10 (6538)**

The final score is 6544. Then:
- CounterContextBlockNow (6746)
- the context penalties are folded in and clamped to 10 again (6817)
- objection headroom (6849-6866), which is **dead** (F6)
- the decision (6870)

---------------------------------------------------------------------------------------------------

## 4. Legacy score packs (15) and 09 converters, as far as they change the score

| Pack (call 16:931-937) | Bonus | Penalty (default) | Data | Notes |
|---|---|---|---|---|
| Legacy upgrade 15:740 | 2/2/1/2 | 2/2 | G_LEGACY_* zones | **OFF** (`UseLegacyUpgradePack=false`, 01:3761) |
| DLP 15:2380 | HTF +2, M15 +1, zone +1 | HTF 0 (01:1474), M15 -1, zone -2 | **DeepHTFTrendDirection = Kalman H1 5-pt, ADX-bound** (15:2241); MB M15 state (15:2304); **G_LEGACY_NEAREST_* never built** (F8) | zone term dead |
| DBOS 15:2655 | aligned +2 (when ever retested), CHoCH +2, retest +2, volume +1 | against 0, CHoCH-against -1, failed retest -1 | **G_DBOS_DIR latched** (15:2696), **G_DBOS_EVER_RETESTED latched** (15:2702) | "BOS waiting retest" -1 applies forever after the 18-bar window (15:2777-2782) |
| DTZ 15:3050 | breakout +2, trap +2 | opposite zone 0, counter trap -2 | **G_LEGACY_NEAREST_* = 0 always** | **entirely dead** (F8) |
| DNV 15:3307 | shock momentum +1 | news -3, spread -1, shock against -3, exhaust -2, cooldown -1 | DeepShock M1 | - |
| DET 15:3554 | candle confirms +2, rejection +1 | late (>48 s) -1, post-shock -2, candle not confirming -2 | **M1 bar-1 colour / wick, again** | duplicates the detector's candle terms and the candle layer, outside the candle cap |
| DRT 15:4296 | momentum continuation, exhaustion reversal | shock, exhaustion, dead / chaos | G_MARKET_STATE, DTZ / DLP zone dirs (dead) | exhaustion-reversal bonus is reachable only through the DBOS CHoCH flag |

How the changes are applied (`LegacyApplyScoreChange`, 15:682-716):
- Bonuses go straight to G_SCORE_FINAL with **no cap**.
- Penalties are clipped to the room left under MaxTotalScorePenalty (10).
- `LegacyRecalculateDecision` (15:721) then re-derives PASS/WAIT from the score alone. It skips HARD_BLOCK and arm-held sides (package-1 A1 fix present at 15:727). See F7.

09 converters:
- Expired-block soft pass +ExpiredBlockScoreBoost (09:841-846) and missed-memory boost (09:1686-1697): both have the arm guard (A1 fix present).
- Scan redirect (09:422-500): no arm guard and no voices check (`RedirectMinVoices` is used only by the location redirect, 14:3798). See F5.

---------------------------------------------------------------------------------------------------

## 5. Score-scale analysis (question 5)

- **Final = base + bonus - penalty.**
  - base: detector score, 3-9; most detectors give 5-7, and NZR is always 6-7.
  - bonus: after the soft BonusCap it is 12 + 0.35 * excess, capped at 26 (+5 with breadth). Legacy bonuses come on top, uncapped.
  - **penalty <= 10 hard** (08:6538, 6817; F6).
- **Weak setup passing on bonuses alone: yes.** A base-5 setup needs only bonus >= MIN - 5 + penalty, i.e. bonus >= 9 in Balanced and >= 7 in Hunter. Once that holds, any number of objections, however large their raw sum (G_PENALTY_RAW is uncapped, "47 raw" per the V278 comment), cannot refuse it.
- **A clean with-trend setup collects about 15-25 raw bonus.** Examples:
  - MTF alignment 4x1 (not in the trend cap)
  - anti-overfilter trend +2, clean spread +1, room +1
  - trend-align group 8
  - daily bias +2, global trend +3, daily open +3
  - situation up to +8, candle group up to 8, structure group up to 7
  - legacy DLP +2, DBOS +2, DET +3

  The score gate is therefore decided by how many agreeing readings exist, not by the objections.
- A counter-trend reversal setup can also collect the counter-structure bonuses of F12 (+4 maturity fade, +3 confluence, +2 invalidation, up to +6 EQ zone, +4 reversal-at-extreme, +4 volume divergence).
- **Good setup never reaching PASS:** only through MIN stacking (volatile +2, reversal +1, post-SL +3, bad day +3: MIN up to about 13-14) or arm loops (F2/F3/F19/F21). These are the real silence sources, not the penalty arithmetic.

---------------------------------------------------------------------------------------------------

## 6. Findings

### F1 - "Pullback continuation" detector is direction-inverted; PULLBACK gives +2 to both sides
- Category: CONDITION WRONG. Severity: **P1** at detector level. Whether the later veto (VH/V0) always removes it is NOT YET VERIFIED.
- Where:
  - 07_Detectors.mqh:866-886 and 898-918 (`DetectPullbackBuy/Sell`)
  - 05_Situation_Candles.mqh:3098-3106 (`DetectPullbackState`)
  - 08_Scanner_Score.mqh:634-644 (`ApplyAntiOverfilterScoring`)
- Code:
  ```
  05:3098  bool pullback_against_up   = (trend_state == MARKET_TREND_UP   && c1 < c2 && c2 < c3);
  07:866   bool market_ok = (G_MARKET_STATE == MARKET_PULLBACK || G_MARKET_STATE == MARKET_TREND_UP);
  07:877   bool continuation = (c1 > c2 && IsBullishCandle(SignalTF, 1));
  07:880   if(G_MARKET_STATE == MARKET_PULLBACK) score += 2;
  07:898   bool market_ok = (G_MARKET_STATE == MARKET_PULLBACK || G_MARKET_STATE == MARKET_TREND_DOWN);
  07:909   bool continuation = (c1 < c2 && IsBearishCandle(SignalTF, 1));
  08:641   if(G_MARKET_STATE == MARKET_TREND_DOWN || G_MARKET_STATE == MARKET_PULLBACK)
             AddScoreBonus(... ScoreBonusTrendAligned, "sell aligned with trend/pullback");
  ```
- Cause:
  - MARKET_PULLBACK carries no direction. In an up-trend it means three falling M1 closes (c1<c2<c3) on the same bars the detector reads.
  - So in PULLBACK-of-uptrend, `DetectPullbackBuy` (needs c1>c2) can never fire. `DetectPullbackSell` fires on the falling closes, scores 2+3(+1) = 5-6 (grade B), and the anti-overfilter adds +2 "aligned with trend".
  - The with-trend version only runs in TREND_UP and scores 3-4, which is grade NONE in Balanced (`MinOpportunityScoreB=5`, not micro).
  - The type is classed as continuation (00:684), so it also escapes the +1 reversal bar.
- Effect: in Balanced mode the "pullback continuation" opportunity is always a sell into an up-trend's pullback (or a buy into a down-trend's bounce), with +2 "trend aligned". A wrong-direction first-entry candidate is created by design.
- Reproduce: H1 Kalman up, M15 close > SMA, three falling M1 closes. The journal shows `[... SCANNER] OPPORTUNITY: B SELL PULLBACK_CONTINUATION | ... down continuation=true` and `+2 sell aligned with trend/pullback` in SCORE DETAIL.

### F2 - A confirmed arm is re-armed in the same pass (all sites except counter-zone)
- Category: CONDITION WRONG. Severity: P2 (silence; the confirmed trade is never taken).
- Where:
  - 08:1982-2013 (confirm and `SetupArmClear()`)
  - arm sites 08:2861, 3159, 4724, 4811, 4898, 5242, 6288, 6330
  - the only exemption, 08:6746 `(ctx_dir == arm_confirmed_dir)`
  - 06:1500-1541 (`SetupArm`)
- Code:
  ```
  08:2012   SetupArmClear();                   // after a confirmation
  ...
  08:4893   else if(sp_ratio >= SpreadCostCaution && EnableSpreadArming && EnableSetupArming)
  08:4898      SetupArm(entry_dir_i, ARM_REASON_STRUCTURE, sp_px, ...)) { G_SCORE_DECISION = SCORE_DECISION_WAIT; ... return; }
  06:1524   if(G_ARM_DIR == dir && G_ARM_REASON == reason_code) return true;   // G_ARM_DIR was just cleared -> arms fresh
  ```
- Cause:
  - `arm_confirmed_dir` is passed only to CounterContextBlockNow (fix "arm-confirm-deadlock").
  - Every other arm site re-tests its own objection after the confirmation cleared the arm. If the objection still holds (spread; zone reaction edge after the bounce; fill quality), it arms again and returns WAIT.
  - The FILL arm's "no better price after N bars - taking the setup anyway" (06:1603-1609) clears the arm and returns true. The fill check at 08:6320 then re-arms in the same pass.
- Effect: an armed setup can leave its wait only if the objection itself disappeared. Confirmation adds +3 (08:2003) and is then thrown away. Permanent WAIT loops. Combined with F3, this is a total stop of the detector path in cashback mode.
- Reproduce: journal `[SIRUS v194 ARMED] CONFIRMED - ...` immediately followed in the same scan by `[SIRUS v194 ARMED] BUY held - spread costs ...` (or `reaction edge is ...`), with no ENTRY.

### F3 - Cashback mode: the spread-economics arm is always true
- Category: WRONGLY BLOCKS. Severity: P2. There is a P1 risk scenario, marked as a guess below.
- Where:
  - 08:4861-4917
  - 06:2312-2340 (`SpreadCostRatio`)
  - 11:941-975 (`RebateTargetPoints`)
  - 14:4219 (fast path barred on an armed side)
  - 06:1512 (post-win skip)
- Code:
  ```
  11:953   double target = spread_pts * RebateSpreadMultiple + (double)RebateTPMarginPoints;   // 240*0.6+80 = 224
  06:2330  double ratio = spread_pts / target;  if(SpreadCountRoundTrip) ratio *= 1.5;             // 1.61
  01:4777  SpreadCostCaution = 0.26
  14:4219  if(fe_found && G_ARM_DIR == fe_dir) fe_found = false;
  ```
- Cause:
  - In cashback mode the TP is built from the spread, so spread/TP*1.5 is about 1.6 for any spread above about 16 pts.
  - The caution threshold (0.26) and the arm (`EnableSpreadArming=true`) therefore fire on every scan whose side is not already armed and not inside the 20-bar post-win window.
  - The confirmation ("reclaimed": M1 close beyond the ask/bid at arm time, 06:1872) needs a move of at least one spread (about 224-240 pts, i.e. the whole TP). Because of F2, it is re-armed in the same pass anyway.
  - There is no `EnableRebateMode` exemption: grep shows the only rebate checks near spread are at 14:1314/1359.
- Effect:
  - In cashback, the scanner's side is permanently WAIT, and the brain fast path cannot take that side either (14:4219).
  - First entries come only from: the side the scanner did NOT pick (fast path, redirect - F5), or the last-won direction during 20 bars after a TP (06:1512).
  - Normal mode is unaffected (240/2500*1.5 = 0.14).
  - *Guess (P1 scenario):* after a run of BUY TPs the market turns. SELL setups on the scanner side are armed. BUY stays free for 20 bars per win, so the detector path keeps offering the old direction. The veto/arbiter is the only remaining stop.
- Runtime: the "score" family is the biggest gate (820/2065 rows, 40%). The CSV period ran in cashback (tp-entry = 0.224 in every row) with this code (spread arming exists since 47f47f9, 2026-10-06). This is consistent but NOT YET VERIFIED, because the CSV does not name the sub-rule.
- Reproduce: cashback mode, any detector setup. SCORE DETAIL ends with `[armed: waiting for spread to narrow]`; `[SIRUS v194 ARMED] ... spread costs 160% of target`.

### F4 - A stale arm blocks the brain fast path while the scanner has no setup
- Category: SIGNAL/DATA LOST (stale state). Severity: P2.
- Where:
  - 08:1889-1892 (early return "no opportunity") before 08:1982 (the only call to `SetupArmConfirmed`)
  - 14:4219
  - 06:1489-1492 (`ArmHoldsSide`, no window check)
- Code:
  ```
  08:1889  if(G_OPP_GRADE == OPP_GRADE_NONE || G_OPP_DIR == OPP_DIR_NONE) { ResetScoreEngine("no opportunity"); return; }
  08:1982  if(EnableSetupArming && G_ARM_DIR != 0) { ... SetupArmConfirmed(arm_detail) ... }
  06:1491  return (EnableSetupArming && dir != 0 && G_ARM_DIR == dir && G_ARM_REASON != ARM_REASON_NONE);
  ```
- Cause: arm expiry (window, abandon distance, session change) is evaluated only in `SetupArmConfirmed`. That runs only when the scanner has an opportunity and no safety hard block. Neither the W2 fast-path check nor `ArmHoldsSide` tests the arm's age.
- Effect: after the scanner goes quiet, an arm from minutes or hours earlier keeps refusing that side's:
  - brain fast entries (14:4219)
  - reliefs (14:4062/4127/4144/4168)
  - queue / legacy / memory / expiry upgrades

  The result is silence on exactly the side the EA had judged right.
- Reproduce: an `[ARMED] BUY held` line, then a quiet tape with no scanner opportunity, and the brain bias is BUY. The panel `armed:` text keeps showing BUY with waited > window, and there is no FAST BUY.

### F5 - The scan redirect ignores the arm, so the opposite side escapes symmetric objections; it also reverses consensus
- Category: CONFLICT. Severity: P2.
- Where: 09:422-500 (`UpdateDirectionRedirectEngine`), 16:928-931, 06:1531-1535.
- Code:
  ```
  09:436  if(RedirectOnlyOnScoreWait && G_SCORE_DECISION != SCORE_DECISION_WAIT) {...return;}   // arm WAIT qualifies
  09:478  else if(best_score < G_OPP_SCORE + RedirectMinImprovement) ...
  06:1534  if(held <= SetupArmMaxWaitBars) return (G_ARM_DIR == dir);   // other side -> false -> no WAIT
  ```
- Cause:
  - An arm-WAIT is a timing hold ("right side, early"), but it triggers the redirect.
  - In the REDIRECT_RESCORE pass, every arm site for the new side gets `false` from SetupArm, because the original side holds the arm. Spread, zone-edge and pressure objections that apply equally to both sides therefore do not hold the new side. The spread site adds no penalty either: its third branch is an `else if` of the same chain, 08:4907.
  - The redirect needs the opposite score >= G_OPP_SCORE+1. That is exactly the case after a consensus flip (08:168-170 sets G_OPP_SCORE = lose_best). So the crowd decision is undone whenever the crowd side WAITs.
  - No voices check here (`RedirectMinVoices` is only read at 14:3798).
- Effect: a side flip produced by the waiting mechanism itself. The new side faces fewer objections than the side the EA preferred.
- Reproduce: `[... REDIRECT] REDIRECT: BUY -> SELL` in the same scan as `[ARMED] BUY held`, then SCORE PASS SELL without `[armed ...]`.

### F6 - The penalty ceiling is a hard 10; "objection headroom" (V287) and the Hunter cap term are dead
- Category: CONDITION WRONG (the code does not do what its comments say). Severity: P2.
- Where: 08:6512-6528 (eff_penalty_cap), 08:6538-6542 (V278 clamp), 08:6817-6821, 08:6849-6866 (V287).
- Code:
  ```
  6512 int eff_penalty_cap = MaxTotalScorePenalty + MathMax(0, (... MinScoreBalanced) - MinScoreForContext(...));  // Hunter 12
  6538 if(MaxTotalScorePenalty > 0 && G_SCORE_PENALTY > MaxTotalScorePenalty) G_SCORE_PENALTY = MaxTotalScorePenalty; // 10
  6849 int eff_final_pen_cap = MaxTotalScorePenalty; ... eff_final_pen_cap = MaxTotalScorePenalty + ... ObjectionHeadroomExtra(14)
  6862 if(eff_final_pen_cap > 0 && G_SCORE_PENALTY > eff_final_pen_cap)   // never true: penalty already <= 10
  ```
- Cause: the V278 hard clamp runs after the bar-relative cap and before the V287 headroom. G_SCORE_PENALTY can never exceed 10 when the headroom code runs.
- Effect:
  - The asymmetry V287 was written to remove is still live: bonus up to 26-31 (plus uncapped legacy bonuses, F7) against a penalty frozen at 10.
  - Any setup with bonus >= MIN - base + 10 passes whatever objects. Example: Balanced base 5 needs bonus 9; Hunter needs 7.
  - The V249 Hunter symmetry term (+2) is also overridden.
- Reproduce: SCORE DETAIL containing `[final penalty cap NN->10]` and never `[decision penalty cap ...]`. A setup with G_PENALTY_RAW of 30+ and PASS.

### F7 - Legacy packs: uncapped bonuses, zeroed or capped penalties, WAIT to PASS from stale sources
- Category: CONFLICT. Severity: P2.
- Where:
  - 15:682-716 (`LegacyApplyScoreChange`), 15:721-736 (`LegacyRecalculateDecision`)
  - DLP 15:2400-2470, DBOS 15:2683-2791, DET 15:3590-3636
  - inputs 01:1474, 1494, 1508, 1535 (penalties set to 0 in "BOSQICH 16", bonuses kept)
- Code:
  ```
  15:686  G_SCORE_BONUS += bonus; G_SCORE_FINAL += bonus;       // no cap of any kind
  15:701  int room = MaxTotalScorePenalty - G_SCORE_PENALTY;    // penalties only into what is left of 10
  15:731  if(G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED) G_SCORE_DECISION = PASS;
  ```
- Cause:
  - The score engine's bonus caps (trend-align 8, BonusCap, MaxTotalScoreBonus) have already run when the packs add DLP HTF +2, DBOS aligned +2 / CHoCH +2 / retest +2, and DET candle +2 / rejection +1.
  - Their penalties are 0 by input, or dropped when the engine penalty is already 10.
  - The sources are stale or legacy:
    - DeepHTFTrendDirection = Kalman H1 5-pt slope (15:2253-2257)
    - G_DBOS_DIR and G_DBOS_EVER_RETESTED are latched (15:2696, 2702): "BOS aligned (confirmed)" +2 for a break days old
    - DET re-reads the M1 bar-1 colour that the detector and the candle layer already scored
- Effect: a one-way upward pressure of up to about 9 points after all caps. It re-derives PASS on score alone (the arm guard is present) and duplicates the trend-agreement and candle facts the caps were built to de-duplicate.
- Reproduce: SCORE STATUS `final=X/Y | legacy bonus=5 penalty=0` on a scan whose engine detail shows `[trend-agreement bonus 11->8]` and `[final penalty cap 14->10]`.

### F8 - DTZ pack and the DLP / DRT zone terms read zones that are never built
- Category: SIGNAL/DATA LOST. Severity: P3 (dead code that looks live in the panel).
- Where:
  - 15:752-759 (`LegacyBuildSmartSRZones` only after `if(!UseLegacyUpgradePack) return;`; default false, 01:3761)
  - 05:3513-3514 (reset to 0 every scan)
  - readers 15:2358-2362, 2933-2946, 2974-3013, 4319
- Effect:
  - DTZ (trap +2, breakout +2, counter trap -2) never fires.
  - The DLP "zone supports / opposite zone danger" term is always 0.
  - The DRT exhaustion-reversal bonus is reachable only through the DBOS CHoCH flag.
- Reproduce: the DTZ panel always reads `no near zone support=999999999 ...`.

### F9 - Consensus voices count correlated detectors and can override a stronger level-based setup
- Category: CONFLICT. Severity: P2.
- Where: 08:154-189, 07:2430-2431. Inputs ConsensusVoiceEdge=3, ConsensusMaxScoreGap=4 (01:850-852).
- Code:
  ```
  08:165  if(lose_n >= win_n + ConsensusVoiceEdge && (win_best - lose_best) <= ConsensusMaxScoreGap)
  08:168     G_OPP_DIR = (win_dir > 0) ? OPP_DIR_SELL : OPP_DIR_BUY;  G_OPP_SCORE = lose_best;
  ```
- Cause:
  - One bullish M15 bar 1 makes ConsecutiveCandles, ExpandingVolatility, VolumePush, VWAP bounce, MA bounce, Donchian and TrendRide speak together (rows 9-19). Each counts as an independent voice.
  - A single level-based reversal (sweep or FBR, score up to 8-9) is outvoted by 4 such voices at a score as low as 4-5.
  - The arbiter and brain bias are not consulted. Only the exact-tie case reads them (07:2470).
- Effect: the scanner direction flips on correlated evidence, not on independent evidence. Runtime hint: **44% of consecutive "score" rows within 120 s flip direction** (286 flips vs 363 same; shadow CSVs). This proves direction instability of the scanner family, not this sub-rule.
- Reproduce: `[SIRUS CONSENSUS] 4 detectors said BUY at best 5 - overriding one-sided SELL at 8`.

### F10 - CounterContextBlockNow returns early after allowing a counter-HTF entry
- Category: CONDITION WRONG. Severity: P2 (counter-trend entries get lighter checks than with-trend ones).
- Where: 08:1428-1535; sections skipped are at 08:1539 (range counter-fade) and 08:1806 (fresh impulse).
- Code:
  ```
  08:1446  G_SCORE_PENALTY += HTFAgainstScorePenalty;
  08:1528  why = StringFormat("-%d %s against HTF trend ...");
  08:1533  return false;          // <- inside if(rc < HTFAgainstReversalOverride)
  08:1539  // --- 3. Range breakout counter-fade ---   (never reached for that entry)
  ```
- Cause: the tier B/C "allowed" branch exits the function. Sections 3-13 run only for entries that are not counter-HTF.
- Effect: a counter-HTF entry that also fades a confirmed range breakout does not pay `RangeBreakoutFadePenalty` (4). It also skips the fresh-impulse wait (3). A with-trend entry in the same spot pays both.
- Reproduce: Kalman H1 down, GlobalTrendConfidence <= -0.6, a BUY with a lean level below, a fresh downside range breakdown. SCORE DETAIL has `against HTF` but no `fades a confirmed downside breakdown`.

### F11 - About 25 HTF / direction terms in the score, none of which read the arbiter
- Category: CONFLICT. Severity: P2 for the stale ones, P3 overall.
- Where: rows marked "Arb? yes" in section 3, plus the legacy packs.
- Cause: the score runs before the veto and the arbiter, and builds its own HTF opinion. It never reads G_MB_BIAS or the 20h verdict; only LSDirEff (04:2543) and DeepM15 (15:2304) were bound. The sources and their problems:
  - **Kalman H1 slope > 5 pts**:
    - MTF alignment, 08:2508-2511
    - MTFConfidence, saturating at 15 pts (05:4471-4473)
    - Brain-consensus cat_bigtrend, 08:5656-5662
    - G_MARKET_STATE trend, which drives anti-overfilter ±2 and detectors 5-6
    - DeepHTFTrendDirection, used in the HTF-against penalty / refusal and in DLP
    - MTFAlignmentCount, used in detectors (+1 each) and MTF Unanimous

    At _Point 0.001, 5 pts = $0.005 per H1 bar, so the slope is essentially never neutral. This is round-1 S5, still unfixed (`KalmanTrendMinPoints=5.0`, 01:4160).
  - **D1OverallDirection** (03:714, two D1 closes; never neutral): MTF alignment, Hunter D1 bar.
  - **G_DAILY_BIAS** (yesterday's colour / gap): DailyBias +2 / -1 (asymmetric), and the detector tie-break fallback.
  - **G_DBOS_DIR latched**: DBOS, and ReversalConsensusScore (05:4148). That score feeds the +3 / -3 reversal consensus and **the tier-A override of the HTF-against check** (08:1434, rc >= 0.82).
- Effect: the score can WAIT a side the arbiter approves, and PASS (then get vetoed) a side the arbiter denies. "Trend agreement" is counted far beyond the 8-point group cap: MTF alignment, anti-overfilter, daily bias, DXY, global trend, daily open and legacy HTF are not in the TA group.

### F12 - Score terms that reward counter-structure / mean-reversion entries
- Category: CONFLICT. Severity: P3. They push toward fades the council (1e, 1g) and the arbiter refuse.
- Terms and where:
  - Structure maturity "fading a mature structure" +4: 08:3740-3745
  - Structure invalidation near, counter-structure only, +2: 08:3804-3820
  - Structure confluence, only when against LSDirEff, +3: 08:3873-3879
  - EQ zone up to ±6, H1 40-bar range position, so a with-trend SELL in a falling market sits in "discount" and pays -2..-6: 08:2615-2660
  - Arrival "fading the approach": 08:4380-4390
  - Forced-flow fade +2: 08:5144
  - Candle progression "fading side is running out" +2: 08:4462
  - Volume divergence +1..4 against the move, added after the caps: 08:6181-6186
  - Reversal-at-extreme +4: 08:6299
- Effect: none is wrong by itself, but in a trend they systematically lift the counter-side score that the arbiter must later veto. This is consistent with brainVeto being the second-largest gate (528 rows) - a guess about cause.

### F13 - Group caps are bypassed by late or ungrouped terms
- Category: CONDITION WRONG. Severity: P3.
- Where: group caps 08:5956-6105. Late additions 08:6123-6470: DailyOpen, VolumeDivergence, SetupLearning, CalendarThinness, PreparedLevels, GlobalTrend V273, StreakScoring, ScaleHierarchy, Ambiguity. Ungrouped trend terms: 08:2501-2556 (MTF alignment), 634-644, 2218, 2265, 2808.
- Effect: the V134/V136/V227/V214 de-duplication works only for part of the system. The candle, impulse and trend groups receive points after they were capped, and only the total caps bound the result.

### F14 - The B-F7 fix (LSDirEff) is incomplete; ReversalConsensus uses latched DBOS
- Category: SIGNAL/DATA LOST. Severity: P3.
- Where:
  - 10:2551 (`OppositeSideStrength`, raw `G_LS_DIR`), feeding the Ambiguity penalty -1..5 at 08:6448
  - 05:4148 (`G_DBOS_DIR == direction` counted as a reversal confirmation)
- Code:
  ```
  10:2551  if(G_LS_DIR == opp && G_LS_STATE != LSTRUCT_CHOPPY) { points += AmbiguityStructureWeight; ...
  ```
- Effect: after an M5 breakdown that the brain recognises, the legacy staircase still reads "rising". The SELL then gets an ambiguity penalty for "structure on the other side".

### F15 - The same fact is scored several times, and constant (always-true) terms
- Category: CONFLICT / P3. Examples (all verified in code):
  - **One sweep wick** is scored by: detector (+3/+2/+1, 05:4600-4627), RANGE/EXHAUSTION +1 in the detector and +1 in the anti-overfilter (08:647-651), Major sweep +2, Liquidity wick +5, Manipulation +5, Sweep reversal +6, Reversal consensus, DET rejection +1.
  - **One M1 bar-1 colour** is scored by: almost every detector, candle sequence, opening bias, DET +2 / -2.
  - **Arm confirmation by pressure / chain / pattern memory** (06:2004-2060) earns +3, while the same three readings already score +2/+3, +3, +2 (08:4959, 3088, 5088).
  - **Always-true terms:**
    - "clean spread" +1 at spread 240 <= 300 (08:660). In cashback this coexists with the spread arm that calls the same spread 160% of target.
    - FBR/NZR `strength >= Min` +1, true by construction (07:534, 699).
    - NZR always scores 6-7.

### F16 - "Both sides look good" is charged four or five times
- Category: CONFLICT. Severity: P3.
- The same fact is charged by:
  - DirectionalClarity -0..4 (08:2126)
  - Ambiguity -1..5 (08:6448)
  - Layer conflict -1..5 (08:5884)
  - Brain conflicted -3 (08:5697)
  - the clarity cost gate +3 (14:4456)

### F17 - Closed-bar detectors stay "fresh" for a whole bar
- Category: SIGNAL/DATA LOST (stale). Severity: P3.
- Where: 07 (all detectors read bar 1); 01:2362 `ScannerEvaluateOnNewBarOnly=false`; M15 TFs at 01:5779-5858.
- Effect: M15 detectors (trend ride, Donchian, consecutive, expanding vol, volume push, VWAP, MA bounce) re-fire every ~3 s for 15 minutes after their trigger close, even after price returns through the level. DET "late entry" (-1) measures only the M1 bar age and is usually lost to the cap.

### F18 - Disabled hard blocks and misleading comments
- Category: NEVER CALLED (with defaults). Severity: P4.
- Dead with default inputs: 08:6556-6660 (impulse-end, impulse-against, blow-off), 08:6665-6720 (zone wall), and CounterContext sections 4-10, 12, 13.
- The section-7 comment says "arming runs regardless of the hard-block flag" (08:1680-1683), but the whole section is inside `if(EnableCounterImpulseBlock && CounterImpulseHardBlock)` (08:1604), so the arm never runs.
- Round-1 A row 4 should be read with this in mind.

### F19 - The zone-edge arm has no distance limit
- Category: WRONGLY BLOCKS. Severity: P3 (P2 if frequent; guess).
- Where: 08:3131-3175, 06:2101-2195 (no distance test), 06:1734-1744 (abandon at 4000 pts).
- Effect: any BUY whose nearest support zone (>= 3 M15 swings within 1800 pts, edge gap >= 400) sits below is armed until price comes back to the zone median and rejects. That includes momentum and breakouts far above the zone.
  - If price is > 4000 pts away, the arm is abandoned on the next bar and re-armed on the same scan (F2 pattern).
  - Otherwise it is held for 8 bars and then re-armed.
- Reproduce: `[armed: waiting for reaction edge X]` with X thousands of points below the bid.

### F20 - Bid/ask asymmetry in detector windows
- Category: CONDITION WRONG. Severity: P3.
- Where: 07:668/732 (NZR: BUY measures from bid, SELL from ask), 07:494/578 (FBR search from bid+50 vs ask-50).
- Effect: SELL windows are shifted one spread (~240 pts, about 16% of the 1500-pt NZR window) relative to BUY.

### F21 - Counter-zone 3500-pt window with a "clear the wall" confirmation
- Category: WRONGLY BLOCKS. Severity: P3 (frequency NOT YET VERIFIED).
- Where: 08:1300-1420, 06:1798-1828; inputs CounterZoneBlockPoints=3500 (01:5911), CounterZoneHardBlock=true, re-arm cooldown 20.
- Effect: a BUY with a level of strength >= 1.4 (or a 3-level shelf) anywhere within 3500 pts (about 15x TP) above is HARD_BLOCKed while armed. It is released only if price CLEARS the wall +200 within 8 bars. Otherwise there is a 20-bar penalty cooldown, then the block again. On XAUUSD both sides usually have such a level within $3.50, so this is a symmetric silence cycle (guess).

### F22 - Runtime evidence (shadow CSVs, older code version)
- Family "score": **RUNTIME VERIFIED** (820 of 2065 rows; 820 including 3 SUMMARY rows).
  - Outcomes: TP 748, GRID 58 (7.1%), TIMEOUT 11.
  - TAKEN: TP 120, GRID 14 (10.4%).
  - Blocked-by-score setups did no worse than the taken ones. The score gate does not discriminate (consistent with round 1).
- Split:
  - BUY 363 / SELL 454
  - with-bias 452 (GRID 6.4%) / against-bias 368 (GRID 7.9%)
- Direction instability: 44% of consecutive score rows within 120 s flip BUY/SELL (286/649). The first two CSV rows are a BUY at 16:15:01 and a SELL at 16:15:07, both TP.
- With TP 224 pts (the median |tp-entry| is 0.224 in every gate), either side often reaches TP within seconds (median minutes = 0, median MFE 267). The score's direction terms cannot be tested against "TP" outcomes; GRID rate is the only meaningful label.
- Sub-rules (spread arm, zone-edge arm, consensus, legacy) are NOT YET VERIFIED: the CSV has no score breakdown, and `extra` was empty in that version.
- Scripts: /tmp/claude-0/-home-user-sirus/31e02e2b-4af5-5ece-83c7-e9cdc4e3f833/scratchpad/audit/F_work/csv_score.py and csv_flip.py.

---------------------------------------------------------------------------------------------------

## 7. Answers to the check list

1. **Wrong-direction detectors:** F1 (pullback, inverted). F20 (bid/ask windows). F17 (closed-bar staleness). No other sign error was found.
2. **Double counting / contradiction:** F7, F9, F13, F15, F16. Also the "clean spread" vs spread-arm contradiction (F15), and anti-overfilter PULLBACK +2 to both sides (F1).
3. **Direction terms vs the arbiter:** F11 (list) and F12. The score never reads the arbiter. The only arbiter-aware spots are LSDirEff, DeepM15 and the tie-break.
4. **Stale / legacy sources:**
   - Kalman 5-pt: 7 consumers (F11)
   - G_DAILY_BIAS: score + tie-break
   - G_DBOS_DIR latched: DBOS +2, ReversalConsensus, which is the HTF-against tier-A override
   - G_LS_DIR raw in Ambiguity (F14)
   - DTZ / DLP zone never built (F8)
   - stale arm (F4)
5. **Scale:** a weak setup passes on bonuses alone (F6, section 5). Good setups fail mostly through arm loops (F2, F3, F19, F21) and MIN stacking, not through penalties.
6. **Unreachable or always-true arms / hard blocks:**
   - always true: spread arm in cashback (F3)
   - near-always: zone-edge arm (F19)
   - dead: objection headroom and the Hunter cap term (F6); the hard blocks of F18; the counter-impulse arm (F18)
7. **Wrong-direction first entry / blocking correct ones:**
   - wrong direction: F1, F5, F9, F10, F7
   - blocking: F2, F3, F4, F19, F21
8. **Runtime:** F22.

## 8. Status summary

| Module | Status |
|---|---|
| Scanner + score family | RUNTIME VERIFIED (family only) |
| Consensus flip, tie-break, redirect, arm sites, legacy packs | STATICALLY PRESENT / NOT YET VERIFIED |
| F3 spread arm (cashback) | STATICALLY PRESENT. Code arithmetic proves it fires; there is no log evidence. |
| F6 objection headroom | **FAILED**: provably never applies (penalty already <= 10 at 08:6538) |
| F8 DTZ pack | **FAILED**: provably reads zeros with default inputs |
| F1 pullback detector | **FAILED** as a with-trend detector: it can fire only counter-trend in PULLBACK |
