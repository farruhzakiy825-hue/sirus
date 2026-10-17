# E (round 2) - Candle reading layer, end to end

Auditor E, round 2. READ-ONLY. Code state: branch `claude/sharp-tesla-dgetgj`, HEAD 5c348e9 (packages 1-5).
Status words and categories follow BRIEF.md. Nothing below is RUNTIME VERIFIED: the shadow CSVs come from
older code and have an empty `extra` column, so they cannot name a candle sub-rule. Everything is
STATICALLY PRESENT / FAILED (proved from code) / NOT YET VERIFIED.

Gold scale used in the severity notes (a guess, not measured here): M1 ATR is about $1-2 (1000-2000 pts),
M5 ATR about $3-5, and the spread is about 240 pts ($0.24). A bar of 0.1 ATR(M1) is smaller than one spread.

Round-1 items that I did NOT re-report: A1 (legacy packs turning an arm WAIT into a PASS - fixed in
package 1), B-F13 (first ticks of a live M15 bar - fixed in package 3, residual noted in E-14), F-C3
(neutral pressure counted as slowing - fixed in package 2; E-12 covers a different hole in the same
function), and D B1 (the late/leg deadlock).

---------------------------------------------------------------------------------------------------
## 1. Inventory - candle readers

| # | Reader (file:line) | What it reads | Bar | Cadence | Output | Size floor? |
|---|---|---|---|---|---|---|
| R1 | 17 `MBReadCandle` 17:239-393 | intent (LIQ_GRAB > FAKE_BREAKOUT > DISPLACEMENT > ABSORPTION > REJECTION > EXHAUSTION > BREAKOUT > INDECISION > CONTINUATION), anatomy, bull/bear 0..100 | closed s>=1 of M1..H4 | once per new bar of each TF (17:709) | `G_MB_LAST[tfi]` | Only DISPLACEMENT (1.2 ATR), BREAKOUT/CONTINUATION (0.3 ATR). LIQ_GRAB, FAKE_BREAKOUT, REJECTION and EXHAUSTION have no floor. |
| R2 | 17 `MBCandleEngineUpdate` 17:700-791 | 3-candle weighted pressure, accel (5 ranges), 6-colour sequence story | closed 1..6 | per new bar | `G_MB_BULL/BEAR`, `G_MB_ACCEL(_DIR)`, `G_MB_SEQ_STORY/DIR`, `G_MB_ATR` | pressure is size-blind (E-7) |
| R3 | 17 `MBImpulseUpdate` 17:396-528 | last displacement (60 bars), waves, travel since a 30% pullback, give-back, compression | closed | per new M1 / M5 bar | `G_MB_IMP_*[0..1]`, `G_MB_SPEED`, `G_MB_COMPRESSED` | ATR |
| R4 | 17 `MBLiveCandleUpdate` 17:531-582 | forming M1: body >= 0.8 ATR(M1), close in its far quarter, beyond the prior bar's extreme; hysteresis exit at 0.4 ATR / mid | **bar 0 M1 + bid** | every price tick | `G_MB_LIVE_DIR`, `G_MB_LIVE_FAILED` | ATR |
| R5 | 17 `MBPressureSide` 17:588-609 | bull-bear >= 15, fallback c1-c6 >= 1 ATR (tfi<=2) | closed | on demand | -1/0/+1 | size-blind (E-7) |
| R6 | 17 `MBCandleConfirms` 17:612-634 | last closed tfi candle is DISP / REJECTION / LIQ_GRAB / FAKE_BREAKOUT toward dir; live invalidation (extreme taken out or 0.5 ATR given back) | closed + live bid | on demand | bool | inherits R1 (no floor for wick types) |
| R7 | 17 `MBCandleOpposes` 17:637-643 | last closed candle is DISP / CONTINUATION / BREAKOUT against | closed, no live check | on demand | bool | misses FAKE_BREAKOUT displacement (E-3) |
| R8 | 17 `MBExhausted` 17:648-669 | M1/M5 impulse LATE+ with 3 waves or EXPIRED, plus an exhaustion / absorption / rejection candle against | closed | on demand | bool | - |
| R9 | 17 `MBTickFlowUpdate` 17:677-698 | bid up/down tick imbalance over 30 s | ticks | 1 per second | `G_MB_FLOW_IMB/N` | - |
| R10 | 23 `MBCandleTriggerNow` 23:186-217, `MBTriggerCandle` 23:132-139, `MBHasTriggerNow` 23:706-712 | trigger = DISP / REJ / LIQ / FAKE / BREAKOUT / **CONTINUATION** / EXHAUSTION on closed M1 or M5, or live M1, or a fresh event | closed + live | on demand | bool | inherits R1 |
| R11 | 21 `MBVetoAccelerationCheck` 21:214-254 | live M1 (R4), **forming M5** body >= 0.8 ATR5 in its far quarter (no hysteresis), live sweep, accelerating closed M1 displacement | bar 0 M1/M5 | per call | V4 block | ATR |
| L1 | 05 `CandleSequenceRead` 05:2607-2738 | M5 (`CandleSequenceTF`) 5 closed bars: INSIDE / ABSORPTION / REJECTION (wick 0.45, body <= 0.5) / EXPANDING / CONTRACTING plus a close-location lean | closed | cached per M1 bar (`G_BARS_SEEN`) | state, dir, conf | none (ratio only) |
| L2 | 05 `LiveBarRead` 05:1778-1857 | forming M5: rejection / expanding / absorption, weighted by progress^2 after 35 % | **bar 0 M5** | per scan (<=3 s) | state, dir, weight | 0.35 ATR range |
| L3 | 05 `LiveSampleUpdate` 05:1544 (called from OnTick mq5:1428) and `LiveBarEvolution` 05:1624-1705 | samples of the forming M5 shape: wick failed / sustained / absorbed | **bar 0 M5** | sampled per tick, read per scan | evo, dir, weight | none - **sign bug E-1** |
| L4 | 05 `CandleConflictRead` 05:1444-1503 | L1 vs L3: DEFENCE_BROKE / PUSH_STALLED / SPLIT | mixed | per scan | conflict, dir | inherits E-1 |
| L5 | 05 `CandleHTFAgreement` 05:1982-2034 | M15 bar 1 body >= 0.40; the forming M15 overrides once its range >= 0.5 x the closed range | closed + **bar 0 M15** | on demand | -1/0/+1 | relative only |
| L6 | 05 `CandlePatternRead` 05:2166-2261 | M5 star / three soldiers / harami / tweezer | closed 1..3 | on demand | pattern, dir | ratios; reclaim formula wrong (E-11) |
| L7 | 05 `CandleWickAuthorship` 05:2527-2588, `CandleLocationWeight` 05:2485 | M5 bar-1 dominant wick vs body, near a zone | closed | on demand | side, conviction | none |
| L8 | 05 `CandleBreakQuality` 05:2408-2459 | M5 bar 1 vs the nearest level ahead | closed | on demand | -1/0/+1 | - |
| L9 | 05 `ConsecutivePressureDir` 05:2740-2805 | M5 run of >= 3 same-colour bodies (>= 55 %) covering >= 900 pts | closed | on demand | dir | **fixed points** (900) |
| L10 | 05 `RecentThrustDir` / `...ExhaustedDir` / `SustainedImpulseExhaustedDir` 05:2813-2930 | M5 15-bar net >= 3000 pts plus efficiency; M15 16 bars; wick against | closed | on demand | dir | fixed points |
| L11 | 05 `ReadSituation` 05:614-880 | swing shape + zone + L1 + L3 -> SIT_* | mixed | per scan | `G_SITUATION(_DIR)` | E-1, E-8, E-9 |
| L12 | 05 `EntryBarPlacement` 05:899-948 | forming M1: where the fill sits in the bar | **bar 0 M1** | per scan | severity | 0.30 ATR; ask-vs-bid bias (E-13) |
| L13 | 04 `SingleCandleDominance` 04:1770, `SingleCandleFaded` 04:1909 | M5 bar 1 vs the average range of bars 2..6 | closed | on demand | dir, strength | 500 pts body |
| L14 | 07 detectors (NZR 07:687-711 / 751-776, range edge 07:788-856, exhaustion 07:1037-1088, MultiCandleShrinking 07:996) | M1 (`SignalTF`) bar 1 wick ratios | closed | per scan | detector PASS | none |

## 2. Inventory - consumers

| Consumer (file:line) | Reads | Effect |
|---|---|---|
| 23 judge `MBEntryJudgeAllows` 23:300-307 (press aligned / pullback / tired), 348 (early_loc), 357-375 (triggers), 516-526 (rev_candle, leg_against, candles_against, tired_block, pb_running), 569 (mom_conf) | R1, R4, R5, R6, R7, R10 | hard WAIT / quality |
| 23 fast-path candidates 852-1090, `MBMomentumNow` 1191, `MBPullbackResume` 144 | R4, R10, R3 | brain entries |
| 21 council `MBCouncilEval` 21:405-481 (m5_turn = R6 on M5; rules 1, 1e, 4, 1b), `MBTrendUnderAttack` 21:307, `MBTransitionConfirmed` 21:609, V0 21:650 / 688, V4 21:214-254, V5 21:736 | R5, R6, R8, R10, R11 | veto |
| 20h `MBArbiterBlocks` 20h:150-165 (CAUTION release = M5 / local + `MBHasTriggerNow`), push 20h:109 (H1 + M15 pressure) | R5, R10 | VH veto |
| 20 brain: bias weak 20:349-350, bias candle wait 20:1104-1111, layer local / micro 20:721-756, local level 20:801-806, leg spent 20:932-939, reaction 20:944-950, thesis threat 20:1257-1265 | R2, R3, R4, R5, R6, R7 | direction state |
| 20c exhaustion pressure 20c:166-167, 221-223; 20d micro 20d:116-122; 20f state 20f:217; 20g lower-high release 20g:235 | R1, R2, R3, R4, R5 | location / state |
| 24 position brain: `MBGridPauseConfirm` 24:832-848, `MBAdverseSlowing` 24:851-883 (rescue guarantee), `MBGridAllows` against 24:940-972, response 24:983-985, 24:275-278, 338, 440-442, 1087 | R1, R3, R4, R5, R6, R10 | grid holds / rescue |
| 08 score: situation 08:3238-3268, sequence 3274-3343, authorship / location 3350-3390, participation 3398-3436, opening 3440-3466, pattern 3470-3540, live bar 3550-3610, entry bar 3616-3632, swing shape 3883, conflict 3919-3949, evolution 3957-3987, HTF candle 4019-4047, follow-through 4052-4083, break quality 4088-4130, single candle 4709-4790, consecutive pressure 4797-4828, candle budget 6005-6044 | L1-L13 | score bonus / penalty / ARM WAIT |
| 05 `GridDirectionDoubt` 05:161-395 | L5, L9, L2, L13, L11 | grid add quality |
| 06 `SetupArmConfirmed` 06:1560-1885 (pattern confirms a wait 1678-1700; EXTENDED geometry 1850-1864) | L6, M1 bar 1 | releases an ARM WAIT with a bonus |

---------------------------------------------------------------------------------------------------
## 3. Findings (ranked)

### E-1 - Live-bar "wick failed" fires on every trend bar that dipped first: the reading has the wrong sign
- Category: CONDITION WRONG. Severity: **P2, P1 candidate** (it scores the wrong side at the bottom of a
  bullish reversal bar, and the mirror case at the top of a bearish one). Status: FAILED (proved from the
  arithmetic). Its effect on trades is NOT YET VERIFIED.
- Where: 05_Situation_Candles.mqh:1544-1606 (`LiveSampleUpdate`) and 1650-1669 (`LiveBarEvolution`).
  ```
  double lower = (MathMin(o, c) - l) / range;            // 1574: wick as a SHARE of the live range
  if(lower > G_LIVE_PEAK_LOWER) G_LIVE_PEAK_LOWER = lower;
  ...
  double lost_lower = G_LIVE_PEAK_LOWER - lo_now;        // 1650
  if(lost_lower >= LiveWickFailedDrop && G_LIVE_PEAK_LOWER >= LiveWickFailedMinPeak)
  {  dir = -1; ... "lower wick failed" ... return LIVE_EVO_WICK_FAILED; }
  ```
- Cause: the wick is stored as a fraction of the bar's range at that moment. When a bar dips first and
  then trends up, the low stays where it was and the wick in points does not change. But the range grows,
  so the ratio falls. Example on the M5 bar: o=100, early sample h=100.2, l=98, c=99.5 gives a lower wick
  of 0.68. Later c=h=103 gives a wick of (100-98)/5 = 0.40. The drop is 0.28, above the 0.18 threshold,
  and the peak of 0.68 is above 0.30. The result is `WICK_FAILED dir=-1`, "buyers lost that low". The low
  was never traded through. The wick check also runs before the "sustained push" check (05:1690), so a
  sustained bullish push is reported as bearish. The upper wick is mirrored.
- Consumers:
  - 08:3957-3987: `LiveEvolutionScore` = 5 x weight, a bonus to SELL and a penalty to BUY.
  - `CandleConflictRead` 05:1474-1481: DEFENCE_BROKE when the closed M5 was a bullish rejection, so up
    to 6 more points go to SELL (08:3919-3949).
  - `ReadSituation` 05:817-824 (`SIT_TREND_TEST_BROKE`): in an M5 downtrend at support, a strong bullish
    bounce bar reads as "support gave way". `G_SITUATION_DIR=-1` is worth up to +8 for SELL
    (`SituationScore` = 8, MinScoreBalanced = 4). It also feeds `GridDirectionDoubt` 05:383 (doubt on a
    BUY basket) and the situation target / lot / grid factors.
- Effect: the weight grows with bar progress (progress^2) and peaks near the bar close. So late in a
  strong M5 bar the legacy score tilts toward the side against that bar. The brain's V4 (forming M5 >= 0.8
  ATR5) and `G_MB_LIVE_DIR` catch only the largest bars. A moderate trend bar (0.4-0.7 ATR5) passes V4.
- Reproduce: verbose journal lines `[SIRUS v213 EVOLUTION] lower wick failed (xx% -> yy%)` while the M5
  bar is green and making new highs, or `[SIRUS v219 SITUATION] ... support at X gave way` on a bullish
  bar. Fix idea (not applied): compare wick lengths in price, or require the bar's low/high to be broken.

### E-2 - Arms against an opposite push confirm when the push goes FURTHER against the entry
- Category: CONDITION WRONG. Severity: P2 (late or wrong-geometry confirmation with a +3 bonus, and
  re-arm churn). Status: STATICALLY PRESENT, NOT YET VERIFIED.
- Where: the arm sites are 08:4721-4731 (single opposite candle), 08:4808-4818 (opposite consecutive
  pressure) and 08:1683-1689 (counter-impulse). All use `ARM_REASON_EXTENDED`, whose answer is
  06:1850-1864:
  ```
  double pulled = (G_ARM_DIR > 0) ? (G_ARM_TRIGGER - l) / _Point : (h - G_ARM_TRIGGER) / _Point;
  if(pulled < (double)SetupArmPullbackPoints) return false;   // 600 pts
  bool resumed = (G_ARM_DIR > 0) ? (c > o) : (c < o);          // one M1 (SignalTF) bar our way
  ```
- Cause: EXTENDED was written for "our move is overextended - wait for a pullback against us". That is
  the correct geometry for the 08:2861 move-extension arm. The three sites above arm the entry because
  the move is running AGAINST it. For them, `pulled >= 600` means the adverse push extended another
  $0.60. One green M1 candle after that is not the push "stopping". This is the same class of defect as
  the already-fixed `FIX(arm-wall-geometry)` for ZONE arms (06:1784-1830).
- Effect: at 08:1981-2004 the confirmation gives `+SetupArmScoreBonus` (3; MinScoreBalanced is 4)
  labelled "pulled back N pts and resumed".
  - If the objection still holds on that scan (same dominant M5 bar, run not broken), the same pass
    re-arms with a new trigger price.
  - If it has lapsed, the entry goes with the bonus from $0.60 or more deeper into the adverse move.
  - `SingleCandleFaded` at the arm site is dead (E-15), so "the next bar fails to continue" is never
    really the release.
  - Side effect: on M5 gold, a run of 3 same-colour bodies covering 900 pts (L9, a fixed-point
    threshold) is ordinary. Every with-trend pullback entry is armed against its own pullback and then
    needs this wrong confirmation.
- Reproduce: `[SIRUS v194 ARMED] BUY held - ... waiting for it to stop` or `... waiting for the run to
  break`, then `CONFIRMED - ... | pulled back 6xx pts and resumed` with a lower ask than at the arm.

### E-3 - Intent precedence hides a displacement inside a FAKE_BREAKOUT; the "against" checks miss bull/bear-trap bars
- Category: SIGNAL/DATA LOST. Severity: P2, P1 candidate for a grid add or first entry right after a trap
  bar. Status: STATICALLY PRESENT, NOT YET VERIFIED.
- Where: 17:295-303 is evaluated before 17:306-312.
  ```
  if(intent == MB_CI_NONE && have_prev && cdir != 0 && out.body_ratio >= 0.5) { ... FAKE_BREAKOUT ... }
  if(intent == MB_CI_NONE && cdir != 0 && body >= MBDispBodyATR * atr ...)   { ... DISPLACEMENT ... }
  ```
- Cause: a bar that closes back inside after a breakout bar is labelled FAKE_BREAKOUT, with
  `strong=false`, whatever its size. A 2-ATR bearish candle after a bull breakout is never DISPLACEMENT.
- Consumers that look only for DISPLACEMENT (or DISP/CONT/BREAKOUT) against:
  - `MBCandleOpposes` 17:642: the judge's `candles_against` 23:519, the bias candle wait 20:1108-1110,
    and the thesis threat `both_against` 20:1258.
  - `m5_disp_against` 20:1257 (the thesis-threat grid hold).
  - V4 "accelerating M1 displacement" 21:247.
  - `MBGridAllows` against 24:940-942 and `MBGridPauseConfirm` 24:840.
- Effect: the strongest reversal bar (a trap plus a displacement) does not count as "pushing against" a
  BUY entry or a BUY basket. Only `MBCandleConfirms` on the SELL side sees it. A BUY grid rung is not
  held by the thesis-threat rule on the M5 trap bar.
- Reproduce: an M5 bar closing above the 10-bar high, then a large red bar closing back below it.
  `MBCandleText()` shows `M5 FAKE-BREAKOUT bear` and the panel shows no "displacement against the basket".

### E-4 - "Strong reaction / turn" (`MBCandleConfirms`) has no size floor for wick types, and excludes the big ones
- Category: CONDITION WRONG. Severity: P2 (it both releases and blocks direction gates). Status:
  STATICALLY PRESENT, NOT YET VERIFIED.
- Where: 17:612-618 (the intent set), the classification 17:288-291, 295-303 and 320-323 (no ATR floor),
  and 17:316-317 (ABSORPTION is evaluated before REJECTION).
- Too loose: a REJECTION, LIQ_GRAB or FAKE_BREAKOUT of any size passes, e.g. a 0.1-ATR M1 bar (smaller
  than one spread) with a 50% lower wick closing in its top 40%. The live invalidation (17:623-631) only
  needs price to stay above that tiny bar's low.
  - The comment at 20:942-943 ("One small candle is not one") is therefore not what the code does.
  - The reading releases: the judge's `rev_candle` (cancels leg_against, pb_running), `zone_only &&
    !reaction` (`MBReactionCandle` 20:946), council 1e / 1 / 1b / 4 (`m5_turn` 21:406), tired_block
    23:529, V0 momentum_confirms 21:687-688, bias confirmation in 1 bar (20:1106) and the thesis-threat
    lift 20:1265.
- Too strict (blocks correct entries):
  - A big hammer (range >= 1.3 ATR, body <= 0.35) is ABSORPTION, not REJECTION, unless it took the
    10-bar extreme.
  - ABSORPTION is in neither `MBCandleConfirms` nor `MBTriggerCandle` (23:136-138).
  - A BREAKOUT candle the new way (close beyond the 10-bar extreme, body 0.3-1.2 ATR) is not a "turn"
    either.
  - So after an M5 pullback in an uptrend, the BUY waits (tired_block / council 1e) for a wick candle or
    a >= 1.2-ATR M5 displacement. Meanwhile a tiny M1 rejection would have satisfied the M1-based
    releases.
- Reproduce: `MBCandleText()` shows `M5 REJECTION bull b../s..` with `body 0.0 ATR` on the
  `[SIRUS CANDLE]` line (MBCandlePrintOnUse) at the moment a council 1e refusal disappears.

### E-5 - One forming M1 candle is counted as location, trigger and reversal proof at once
- Category: CONFLICT (double-count). Severity: P2, P1 candidate on a transition (a == 1) entry. Status:
  STATICALLY PRESENT, NOT YET VERIFIED.
- Where:
  - 23:348 `early_loc = (G_MB_LIVE_DIR == dir && ...)` is a location.
  - 23:360 `trig_live = (G_MB_LIVE_DIR == dir)` is a trigger.
  - 23:516 `rev_candle = (G_MB_LIVE_DIR == dir || ...)` cancels leg_against and pb_running.
  - 23:519-520: candles_against is waived by it.
  - 23:569 `mom_conf = (G_MB_LIVE_DIR == dir || ...)` is the reversal proof for a == 1.
  - It also feeds V0 momentum_confirms 21:687-688 and `MBHasTriggerNow` 23:710, which releases the
    arbiter CAUTION 20h:163 and V0 HTF pullback 21:650.
- Cause: `G_MB_LIVE_DIR` (R4) is a per-tick reading of an unfinished bar. With hysteresis it can still
  flip within the minute and set `G_MB_LIVE_FAILED`.
  - For a == 0 (non-cashback) the judge needs "location AND trigger", and the live bar alone satisfies
    both.
  - For a == 1 it needs "trigger AND (reversal OR momentum)", and the live bar alone satisfies both.
  - It adds quality +15 (loc) +15 (trig).
- Effect: an entry fires on a forming M1 spike (body >= 0.8 ATR(M1), i.e. already $1+ into the move) with
  no closed-bar evidence. The spike can give its strength back seconds later. The basket's direction is
  then decided by a candle that never closed.
- Reproduce: the judge `why` text with `loc=early live impulse` and `trig=live early displacement` as the
  only items, then a closed M1 that is not a displacement.

### E-6 - Situation "range edge rejected" does not check which edge it is
- Category: CONDITION WRONG. Severity: P2, P1 candidate (it scores a BUY at a range top). Status:
  STATICALLY PRESENT, NOT YET VERIFIED.
- Where: 05:647-652 picks the nearer of support and resistance. 05:863-869:
  ```
  if(sw_dir == 0 && rejected_here && cs_dir != 0) { dir = cs_dir; ... return SIT_RANGE_EDGE_FADE; }
  ```
- Cause: `cs_dir` is the wick side of the M5 rejection (05:2701-2705). At a resistance, a bar with a long
  lower wick gives dir = +1, a "range edge rejected" BUY into the ceiling. The same holds for a SELL at
  support. Nothing ties dir to the level's side (at support it should be +1, at resistance -1).
- Effect: about +5 to +8 score to the wrong side (weight about 0.6-1.0 x 8) and `G_SITUATION_DIR` set to
  it. That value feeds grid doubt and the situation TP / grid / lot factors.
- Reproduce: `[SIRUS v219 SITUATION] range edge rejected - no trend, X rejected price | dir=1` while X is
  above price.

### E-7 - Candle pressure is size-blind: tiny bars set M1/M5 pressure by close location alone
- Category: CONDITION WRONG. Severity: P3 (P2 where it releases or blocks gates). Status: STATICALLY
  PRESENT, NOT YET VERIFIED.
- Where: 17:362-367.
  ```
  double bodyf = MathMin(1.0, out.body_atr) * out.body_ratio;
  if(cdir > 0) bull += 30.0 * bodyf; ...
  bull += 20.0 * out.close_pos;  bear += 20.0 * (1.0 - out.close_pos);
  ```
  The threshold is `MBPressureSideMin = 15` (17:593).
- Cause: the close-location term is worth up to ±20 per candle at any range. Two or three tiny M1 bars
  closing near their highs reach 0.5·16 + 0.3·16 + 0.2·16 = 16 >= 15, which is "bull pressure", inside a
  falling tape. The ATR fallback (17:597-606) only runs when the weighted reading is undecided.
- Effect: `MBPressureSide(0)` and, in quiet sessions, `(1)` flip on noise. The gates affected are:
  pb_running / leg_against / press_tired (23:300-305, 517, 530), the local level (20:801-806), local leg
  spent (20:939), council 1b (21:470-475), `MBAdverseSlowing` (24:874, so the rescue guarantee steps
  over soft holds) and the arbiter push (20h:109).

### E-8 - Situation "absorbed" always calls the counter-trend side, whoever was absorbed
- Category: CONDITION WRONG. Severity: P3. Status: STATICALLY PRESENT.
- Where: 05:678 `absorbed = (cs_state == ABSORPTION || evo == LIVE_EVO_ABSORBED)` and 05:854-859
  `if(sw_dir != 0 && absorbed) { dir = -sw_dir; ... SIT_TREND_TEST_HELD }`.
- Cause: `LIVE_EVO_ABSORBED` carries a direction (`-G_LIVE_PEAK_BODY_DIR`) that is ignored. Example: in an
  uptrend at resistance, a bearish push that was absorbed means buyers won. It still produces a SELL
  situation, with no "stretched" requirement (unlike 05:837-850).
- Effect: about +2 to +4 to a counter-trend side, plus `G_SITUATION_DIR` (feeds grid doubt).

### E-9 - Candle follow-through record: the same wick is recorded every scan, the 6-slot ring evicts before grading
- Category: SIGNAL/DATA LOST / duplication. Severity: P3. Status: STATICALLY PRESENT.
- Where: 08:4063 `CandleEventRecord(1, ft_side, tip)` and 08:4111 `CandleEventRecord(2, ...)` run on every
  score pass (every <=3 s, 16:806-819). 05:2289-2312 has no de-duplication. `CANDLE_EVENT_SLOTS = 6`
  (00:87). Grading waits `CandleFollowThroughBars = 6` M1 bars (05:2331).
- Effect:
  - While a wick qualifies, about 20 records per minute push older ones out before they reach age 6.
  - Only the last up-to-6 duplicates of whichever wick was recorded before a pause are graded, each
    counted separately.
  - `CandleRejectionReliability` / `CandleBreakReliability` (score ±`CandleFollowThroughAdjust`) are
    therefore built from a few wicks multiplied by up to 6.

### E-10 - Legacy and brain candle readers disagree on the same M5 bar; legacy only nudges, brain decides
- Category: CONFLICT. Severity: P3 (silence, not direction). Status: STATICALLY PRESENT.
- Thresholds that differ for the "same" concept:
  - Rejection: L1 uses wick >= 0.45 and body <= 0.5, direction from the larger wick (05:2683-2705). R1
    uses wick >= 0.50 and close_pos >= 0.60 (17:320-323).
  - Absorption: L1 is relative to the older bars' average (05:2681). R1 uses 1.3 ATR (17:316).
  - Live bar: L2 / L3 read the forming M5. R4 reads the forming M1; V4 reads the forming M5 at 0.8 ATR.
- Example: an M5 bar with upper wick 0.47, green body 0.45 and lower 0.08.
  - L1 says REJECTION bearish, worth +3 SELL / -4 BUY (08:3293-3296).
  - R1 says "plain" and its pressure leans slightly bull.
- Who wins:
  - The brain veto and judge are hard gates. The legacy reading only moves the detector score (capped
    by `MaxCandleBonus/Penalty` = 8 x relevance, 08:6005-6044).
  - Brain fast-path entries ignore the legacy reading.
  - Detector entries need both, so disagreement turns into WAIT, except where the legacy reading itself
    has the wrong sign (E-1, E-6).
- Double counting inside the legacy score, for the same M5 bar 1:
  - It can earn the sequence REJECTION, authorship/location, pattern (tweezer), conflict, situation and
    follow-through adjust.
  - The situation (08:3253), follow-through (08:4069-4081), break quality (08:4113-4124), entry bar
    (08:3626) and consecutive pressure (08:4823) are outside the `G_CANDLE_*` budget, so they bypass the
    candle cap.
  - `SituationSuppressFactor` (08:5981-5982) trims only part of this.

### E-11 - Morning / evening star needs ~150% reclaim (formula measures from the wrong price); tweezer favours SELL on a doji
- Category: CONDITION WRONG. Severity: P4 (pattern bonus and the pattern-confirms-wait path 06:1678-1700).
  Status: FAILED.
- Where: 05:2201 `reclaim = (d1 > 0) ? (c1 - o3) : (o3 - c1);` with share >= 0.50. The reclaim is
  measured above the first candle's OPEN, not from its close. Intended: `(c1 - c3)/(o3 - c3)`.
- Tweezer, 05:2247-2251: `top` is tested first and accepts `d1 <= 0`, `bottom` accepts `d1 >= 0`. A doji
  matching both is always "tweezer top" (SELL). There is no level or prior-move requirement, and the
  tolerance is $0.25 (about 1 spread).

### E-12 - Rescue "slowing" accepts a tiny M1 rejection in the basket's favour
- Category: CONDITION WRONG. Severity: P3 (grid rescue). Status: STATICALLY PRESENT.
- Where: 24:865-871.
  ```
  if(G_MB_LIVE_DIR == dir || (G_MB_LAST[0].dir == dir && (it == MB_CI_REJECTION || it == MB_CI_DISPLACEMENT ||
     it == MB_CI_LIQ_GRAB || it == MB_CI_ABSORPTION)))  { why = "savat tomoniga sham"; return true; }
  ```
- Cause: no size floor and no live invalidation (unlike `MBCandleConfirms`). In a falling market many M1
  bars have a lower wick and close in their top 40%. Package 2 fixed the neutral-pressure branch (F-C3);
  this branch is untouched.
- Effect: at >= 1.5 adverse steps the rescue guarantee steps over the soft grid holds on one ordinary M1
  bar (13 `GridRescueState`). Pairs with E-7.

### E-13 - Ask vs bid in candle-position tests penalises BUY by spread/range
- Category: CONDITION WRONG (side asymmetry). Severity: P3 (blocks or delays BUY more than SELL).
  Status: STATICALLY PRESENT.
- Where:
  - 05:909 / 924 `px = (dir > 0) ? ask : bid; pos = (dir > 0) ? (px - l)/range : (h - px)/range;` on a
    bid-built M1 bar. A spread of $0.24 on a $0.5 bar adds +0.48 to the BUY position, giving a -1..-6
    `EntryBarPenalty`.
  - The same pattern appears in the single-candle chase test 08:4752-4761 and in the arm trigger prices
    06:1854 (a BUY "pullback" contains the spread).
  - 23:189-191 already fixed this class for the judge ("candles are built from the bid - compare them
    with the bid").

### E-14 - Residual of the package-3 fix in `CandleHTFAgreement`
- Category: CONDITION WRONG. Severity: P4. Status: STATICALLY PRESENT (round-1 B-F13 fix is incomplete).
- Where: 05:2000-2017.
  - The live M15 is honoured once `(h0 - l0) >= 0.5 * range` of the closed M15. After a small closed
    M15 bar (Asia) the guard is still a few points.
  - If the closed M15 is a doji or under 40% body, the function returns 0 before looking at a strongly
    directional live M15.
  - The detail text prints the closed body even when the live bar decided.

### E-15 - `SingleCandleFaded` is always false where it is used (dead check)
- Category: NEVER CALLED (effectively). Severity: P4. Status: FAILED.
- Where: 08:4721 `!SingleCandleFaded(sc_dir)`, together with 04:1909-1930. Both functions read the same M5
  bar 1. Dominance already required `bar_dir == push && body_share >= SingleCandleMinBody`, which is
  exactly Faded's "still going" condition. The comment "ends when the next bar fails to continue" is not
  what the code does (see E-2).

### E-16 - Candle-source learning records the wrong call for penalty states
- Category: CONDITION WRONG. Severity: P4. Status: STATICALLY PRESENT.
- Where: 08:3311 and 3317. CONTRACTING (`cs_dir == entry`, penalty) and INSIDE are passed to
  `CandleWeighted(CSRC_SEQUENCE, cs_dir, ...)` at 08:3324-3325. This records the sequence source as
  calling `cs_dir` when the reading says "against cs_dir" or "nothing". When the fade is right, the
  source is graded wrong. That lowers the weight of all sequence readings, including its correct
  rejection bonuses.

### E-17 - Weak "trigger" set used to lift H1/H4 CAUTION and V0
- Category: CONDITION WRONG (design weakness). Severity: P3 (P2 candidate). Status: NOT YET VERIFIED.
- Where: 20h:162-165 and 21:650 use `MBHasTriggerNow` (23:706-712), which accepts M1 CONTINUATION (17:354:
  body >= 0.3 ATR(M1), body ratio >= 0.5, same colour as the bar before) and BREAKOUT.
- Effect: "M5 structure / local leg + trigger" is effectively "M5 structure / local leg + any ordinary
  M1 body bar". The H1/H4 grid-risk CAUTION and the M15-counter V0 release are then mostly decided by the
  M5 / local reading.
- In cashback tempo the judge's range-trade rule `(loc_ok || trig_ok) && trig_ok` (23:577) reduces to
  `trig_ok`.

### E-18 - Candle-engine state is not reset on re-init (guess about MQL5 semantics)
- Category: CONDITION WRONG. Severity: P4. Status: NOT YET VERIFIED.
- Where: 17:124-150 globals and 17:709 `if(t0 == G_MB_CE_BAR[tfi]) continue;`. No OnInit reset exists
  (grep finds `G_MB_CE_BAR` only in 17).
- Assumption: the code's own `FIX(reinit-bar-rewind)` comments assume statics/globals survive an input
  change. If so, after an input change (MBDispBodyATR, MBRejectWickRatio ...) H1/H4 keep the old
  classification for up to one H1/H4 bar, and `G_MB_IMP_*` keep theirs until the next M1/M5 bar.

---------------------------------------------------------------------------------------------------
## 4. Checklist answers

1. **Classification for gold M1-H4 (3-digit prices):**
   - All brain sizes are ATR-relative; there is no division by zero (every ratio is guarded: 17:267,
     405, 544, 747; 05:1810, 2187, 2671).
   - Weak points:
     - No size floor for the wick intents (E-4).
     - Precedence hides displacement (E-3).
     - Pressure is size-blind (E-7).
     - Legacy fixed-point thresholds (L9 900 pts, L10 3000 / 15000 pts, arm pullback 600 pts, opening gap
       150 pts) behave differently in Asia and NY.
   - Doji handling: the brain gives cdir = 0, so a doji is never DISP/CONT/BREAKOUT/FAKE; a dragonfly can
     be REJECTION. Legacy L9 ends a run on a doji. The tweezer accepts a doji as a "top" (E-11).
2. **Closed vs forming bar:**
   - Bar 0 readers: R4 (M1, hysteresis), V4 forming M5 (no hysteresis, can flip per tick), L2 / L3
     (forming M5, progress-weighted), L5 (forming M15), L12 (forming M1), and the live invalidation in R6.
   - The forming M1 alone can carry a first entry (E-5).
   - L2 / L3 / L12 sit inside the score snapshot and can be up to 3 s stale against the per-tick brain
     (16:806-847) - P4.
3. **Two readers:** see E-10. Brain wins hard decisions; legacy only shifts the detector score and
   becomes harmful only where its sign is wrong (E-1, E-6, E-8).
4. **Wrong TF or sign:**
   - Sign: E-1 (wick dilution), E-6 (edge side), E-8, E-13 (ask vs bid), E-16 (learning sign).
   - TF: no wrong-TF index was found. `MBCandleConfirms` / `TriggerNow` use the matching `G_MB_ATR[tfi]`.
     The M1 impulse uses M5 ATR on purpose (17:456). The arm confirmation mixes an M5 objection with an
     M1 answer (E-2).
5. **Stale state:**
   - `CandleSequenceRead` cache fixed for reinit (05:2622).
   - Candle-engine globals are not reset (E-18).
   - `G_MB_LAST` has no age check in `MBCandleConfirms`, but it is refreshed every bar and retried while
     CopyRates fails (17:714-720).
6. **Duplicates / deadlock:**
   - The brain has overlapping pressure gates (council 1, 1b, 4; judge leg_against, pb_running,
     tired_block; trend-under-attack; grid M5+M15 hold). Their release keys differ (M5 turn vs M1 turn
     vs live).
   - No side-symmetric candle deadlock was found: each gate is direction-exclusive. The worst case is the
     pullback state where BUY waits for an M5 turn (E-4 makes that turn hard to get) and SELL waits for
     M5 structure.
   - The legacy score double-counts one M5 bar several times, partly outside the candle cap (E-10).
7. **Wrong first entry or blocked correct entry:**
   - Wrong side: E-1, E-6, E-3, E-5, E-2 (bonus on a deeper adverse entry).
   - Blocked: E-4 (no turn from a big hammer or a breakout candle), E-13 (BUY), E-2 (with-trend pullback
     entries armed against their own pullback).

## 5. Runtime context (shadow CSV, old code - INSUFFICIENT EVIDENCE for any sub-rule)
- In `396b75bb-...240007.csv`, 378 of 1231 consecutive records less than 60 s apart flip side
  (BUY <-> SELL). That includes TAKEN entries with an opposite-side record seconds before or after, e.g.:
  - 08-Oct 19:53:30 BUY score, then SELL TAKEN -> GRID.
  - 08-Oct 16:00:00 SELL other, then BUY TAKEN -> GRID.
- This fits intrabar (forming-bar) readings that flip the candidate side, but the `extra` column is empty
  in this version, so it cannot be attributed to any candle rule above.
