# H - Money layer audit (round 2): lot, TP, grid lot, exit judgements

Auditor H. Code: branch claude/sharp-tesla-dgetgj, HEAD 5c348e9 (packages 1-5). READ-ONLY; nothing in the repo changed.
Status words and categories follow BRIEF.md. No runtime evidence exists for lot sizes or exits: the shadow CSVs have no lot,
DD or exit columns, and no `Sirus_Recovery_*.csv` or trace file was uploaded. Everything below is STATICALLY PRESENT or
NOT YET VERIFIED unless a finding says FAILED and shows the arithmetic.

Line numbers are for HEAD 5c348e9. During this audit someone else left uncommitted edits in the working tree
(00_Defines, 02_Globals, 11_Expectancy_MTF_News: package-6 retry code, +67 lines after 11:4618). Not made by this auditor.
In the working tree 11:4741 (CorrelationGuardLotAdjust) is 11:4808 and 11:5071 (EconomicCalendarLotAdjust) is 11:5138.

Assumptions used in the arithmetic (they are marked wherever they matter):
- XAUUSDm, point 0.001, 1.00 lot = $0.10 per point (100 oz contract). Guess: the contract size was not read from a log.
- Cashback mode on (TP ~224 pts). `AutoGridBaseDistance()` = 3 x 224 = 672 pts, raised to the hunter min clamp of 5500 pts
  (shadow CSV: grid_step 5500 in 127/132 TAKEN rows).
- Defaults from 01_Inputs.mqh unless noted. StartLot 0.25, MaxOrders 5, LotMultiplier 1.30, BasketSLPercent 50.

Severity note: the brief's scale has no "money" tier. Account-risk items (a basket ladder bigger than the account can carry,
a recoverable basket closed in loss) are rated P2 here, the highest tier that is not about direction.

---------------------------------------------------------------------------------------------------
## 1. First-entry lot pipeline (`LotForCurrentEntry`, 14_Risk_Gates_Entry.mqh:842-1155)

Order of execution. "Effective" = does the step change the order that is actually sent, with defaults.

| # | Step | file:line | Default factor | Data / TF / freshness | Overlaps with | Effective with defaults? |
|---|------|-----------|----------------|-----------------------|---------------|--------------------------|
| 0 | Balance-sized base (V285) `AffordableStartLot` | 14:851-866, 10:4351 | lot = budget / ladder cost, never above StartLot | balance, live | LadderIsAffordable, projection | **No - undone by step 21** (H-01) |
| 1 | AutoLot / mode lot | 14:880-913 | UseAutoLot=false, mode lots 0 | - | - | no-op |
| 2 | Micro factor | 14:915-916 | x0.80 on MICRO_PASS | G_SCORE_DECISION | floor scales with G_SCORE_IS_MICRO (other flag) | partly |
| 3 | MaxLot pre-cap | 14:918 | 10.0 | - | - | no-op |
| 4 | Pack4Mini first cap | 14:922, 10:97 | BALANCED cap 0.25 = StartLot (CONSERVATIVE 0.10) | input profile | - | no-op at BALANCED; **CONSERVATIVE cap undone by step 21** |
| 5 | ZoneMapMomentum | 14:923, 14:784 | 0.5/(1+(s-1)x0.5), min 0.05, within 400 pts of a wall | Zone map, live | zone vetoes V2/V3, council 3 | removed by floor |
| 6 | Correlation | 14:927, 11:4741 | x0.5 (x0.7 more if unstable) | other symbols' positions | - | removed by floor |
| 7 | Economic calendar | 14:928, 11:5071 | x0.4 (x0.6 surprise) | G_CAL_ACTIVE | hard block first | no-op: `EconomicCalendarHardBlockFirst=true` returns lot unchanged |
| 8 | HTFStructure | 14:929, 11:4553 | x0.6 when H1 AND H4 against (arbiter on) | arbiter H1/H4 | arbiter VH veto already judged the same fact | removed by floor |
| 9 | FirstEntryTrendGuard | 14:930, 11:4584 | x0.4 | legacy state/DLP/DBOS | - | no-op while arbiter on (package 1) |
| 10 | DXY proxy | 14:931, 11:2798 | x0.6 | 3 extra symbols (off in tester) | Grid Intelligence sense 5 | removed by floor |
| 11 | Broker holiday | 14:932, 11:2065 | x0.5 near listed dates | input dates | - | removed by floor |
| 12 | NY killzone | 14:933, 11:2080 | x0.7, server 15-17 | clock | - | removed by floor |
| 13 | Margin level | 14:934, 12:2113 | x0.5 below 150% | account | MarginAllowsOrder needs projected >= 200% | unreachable in practice (H-10) |
| 14 | Spread/ATR quality | 14:935, 11:2148 | x0.7 when spread/ATR(M1,14) >= 0.15 | live spread vs closed M1 ATR | V10 net edge (cost) | removed by floor; guess: fires on most gold M1 bars (spread 240 vs M1 ATR ~800-1600) |
| 15 | Post-SL same direction | 14:936, 11:2166 | x0.6 for 15 bars | last SL | post-loss cooldown | removed by floor |
| 16 | Impulse correction (single candle) | 14:937, 11:2186 | x0.5 | G_LAST_IMPULSE_* | **same fact as 17** | disabled (`EnableImpulseCorrectionGuard=false`) |
| 17 | Swing impulse correction | 14:938, 11:2277 | 0.5/0.7 x Kalman 0.85 x vol 0.8, clamp 0.2..1 | M15 swings, **Kalman H1 slope** (legacy reader the arbiter replaced elsewhere) | 16, 8 | removed by floor (still effective in the GRID lot, see H-05) |
| 18 | Market confidence (vol/Bayes/Hurst) | 14:939, 12:778 | 0.6..1.0, **neutral score = x0.8** | per-type Bayes record | confidence lot (step 23) reads the score record too | removed by floor |
| 19 | Self defense | 14:940, 11:1630 | x0.5 in protection mode | loss streak | - | **protection trim removed by floor**; its LT_STEP sits inside the comment (not traced) |
| 20 | Judge CAUTION | 14:941, 23:1210 | x0.75 (`MBCautionLotFactor`) | G_MB_ENTRY_DECISION | - | removed by floor - owner rule "CAUTION lot ineffective" holds, but only through step 21 |
| 21 | **Min first-entry floor** | 14:944-967 | `lot_floor = StartLot * MinFirstEntryLotFactor` = 0.25 x **1.0** | StartLot input | - | **resets everything above to StartLot** |
| 22 | MaxLot ceiling | 14:974-978 | 10.0 | - | - | no-op |
| 23 | Conviction (score margin, calibrated) | 14:996-1029 | 0.80..1.0 | G_SCORE_FINAL/MIN, ScoreBandWinRate | 18 | yes, bounded |
| 24 | Warnings | 14:1035-1042 | 0.55..1.0 | G_PENALTY_RAW (round-1 A: can be stale) | TP warning scaling | yes, bounded |
| 25 | Projection | 14:1045-1050, 08:5052 | 0.45..1.0 | ProjectBasketRisk per bar, **never reset outside the scan block** | 0, 26 | yes, bounded |
| 26 | Combined bound | 14:1058 | `lot_factor = max(EntryLotFactorMin 0.80, ...)` | - | - | caps 23-25 together at x0.80 |
| 27 | Situation lot | 14:1072-1078 | held/retest 1.0, broke 0.90, reversal 0.75 | G_SITUATION (scanner) | - | yes, but lifted by 29 |
| 28 | Scale-in split | 14:1086-1107, 06:432 | first part 0.80..0.95 (x0.92 volatile) | score margin, calibration, regime | - | yes |
| 29 | Absolute entry floor | 14:1118-1150 | `NormalizeVolumeSafe(StartLot * 0.80)` = 0.20 | StartLot input | - | yes - final lower bound |
| 30 | NormalizeVolumeSafe | 14:748 | round to NEAREST step, raise to vmin | broker | - | can round up |

### Worst-case product with defaults
- Steps 5-20, every trim at its worst (zone 0.05, corr 0.35, HTF 0.6, DXY 0.6, holiday 0.5, NY 0.7, margin 0.5, spread 0.7,
  postSL 0.6, swing 0.34, confidence 0.6, defense 0.5, CAUTION 0.75): product 3.5e-5, i.e. 0.25 -> 0.000009 lot.
  This would be the broker minimum - but step 21 sets the lot back to **0.25** every time.
- Steps 23-25 at their worst (0.80 x 0.55 x 0.45 = 0.198) are bounded to **x0.80** (step 26) -> 0.20.
- Step 27 reversal x0.75 -> 0.15; step 28 x0.80 -> 0.12; step 29 lifts it to **0.20**.
- **Result: the opening order is always in [0.20, 0.25] (80-100% of StartLot)** whatever the market says. The intended total
  (opening part + scale-in remainder) is max(full_intended_lot, 0.20).
- Nothing makes the lot LARGER than StartLot except when the floors override a smaller sizing that was meant (H-01) or a
  hard cap (H-02). `MaxLot` is re-applied after the floor (14:974), so a multiplier above 1 cannot breach MaxLot.

---------------------------------------------------------------------------------------------------
## 2. TP table

| Order / exit | Where computed | Cashback mode (live) | Normal mode | Consistent with EA basket TP? |
|---|---|---|---|---|
| First order broker TP | `EntryTPPoints` 14:1215, `BuildEntryPrices` 14:1296-1395 | `RebateTargetPoints()` = 0.6 x spread + 80 (spread capped at 350, >= 1.2 x stops), **entry-time spread**, measured from ask (BUY) / bid (SELL) -> net +224 pts at spread 240 | max(ATR(M1) x 3 clamped 2500..6000, FirstEntryTPMinPoints 2000) x TPScale 0.85 -> >= 2125; spread-aware widening; zone cap (>= 2000) | Cashback: EA target uses the LIVE spread (round-1 F-C12, still open for 1-order baskets). Normal: different chain (H-08) |
| Zone TP cap | 14:1330-1350 / 1372-1392 | **dead**: `min_floor = price + RebateTargetPoints()` equals tp, cap must be > it but < tp | active, floor 2000 | - |
| Micro TP | 08:490-526 | ignored (rebate returns first) | clamped to MicroTPMin 2000..3000, then FirstEntryTPMinPoints 2000 -> about the main TP | P4 |
| Situation TP plan | 09:2546-2580 (inside `Pack2BasketTPForOrders`) | **not reached**: `BasketTPForOrderCount` returns at 11:1164-1165 | basket target only; first-order broker TP never uses it | - |
| EA basket TP | `BasketTPForOrderCount` 11:1118, check 12:1594/1656 | live rebate target; dead-premise cut `max(1.5 x spread, 400)` never below 224 so never applies; **no swap/carry floor** (H-07) | base 2500 -> contextual (x<=2) -> x0.85 -> chain/situation/regime/noise/health (x0.6..1.35) -> floor 1200 -> carry floor -> TP intelligence | - |
| Grid rung broker TP | grid send `tp=0` (13), `BrokerBackupSync` 12:1468-1550 | orders >= 2: every rung (and the first order) gets avg + live target + 50, re-modified when > 60 pts off, throttle 5 s | none | yes (+50 so the EA closes first) |
| Scale-in completion TP | 13:2646-2694 | first part's broker TP (package 2); replaced by the basket backup TP at orders >= 2 | same | yes |
| Disaster SL | 12:1487-1500 | loss = max(60, max(50, 52)+5)% of balance at the volume-weighted avg | same | 10 pts beyond EA stops |
| Thesis-dead / doubtful / stale / expectation BE | `MBBasketBreakEvenExit` 24:1069 | basket_points >= 30 AND net profit >= 0 | same | money-checked |
| Local basket exit | 24:428 | net profit >= 0.00 (no point cover) | same | money-checked, slippage can turn it negative (round-1 F-C13) |
| SZR escape | 12:1600 | +SZREscapePlusPoints and profit > 0 | same | money-checked |

TP below cost: in cashback the target is measured from the entry price, so the spread is already paid and +224 pts is net of
spread. Commission is not in the formula; on Exness Standard (XAUUSDm) there is none, on Raw/Zero ~70 pts per lot (guess) still
below 224. Swap is the uncovered cost (H-07).

---------------------------------------------------------------------------------------------------
## 3. Grid lot (`NextGridLot` 13:1366-1501)

Order: last lot -> x `LadderMultiplier()` (1.30, or 1.20 long / 1.22 cautious shape) -> MaxLot -> SOFT: SwingImpulse,
SpreadATR, GridIntelligence (neutral x0.85, min 0.15 scaled by depth), GridAdditionQuality (0.70..1.15) -> FLOOR =
max(pure target x MinGridLotFactor 0.5, [previous lot - OFF], StartLot x **LotMultiplier**^orders x 0.80) -> HARD: Pack4Mini
grid cap (1.00), client safety, preset hardening, margin level x0.5 -> MaxLot -> NormalizeVolumeSafe (nearest step).
Caller: 13:2245 with `EffectiveLastLot` / `EffectiveGridOrders` (scale-in completion counted as part of the first entry).

Default ladder from 0.25: 0.25 / 0.325 / 0.4225 / 0.549 / 0.714 = 2.26 lots. With gaps of 5500 pts the projected loss at the
fifth rung is 74,124 pt-lots = **$7,412 per 1.00 starting lot**, $1,853 at 0.25 (= the `AffordableStartLot` formula; matches
`ProjectBasketRisk`'s walk). The 50% basket SL leaves room for the full ladder only above about **$3,706 balance** at StartLot 0.25.

- Can a rung be smaller than the previous one? Yes, in four ways: (a) hard limits after the floor (P4M grid cap, margin-level
  x0.5 - intended "account protection", 13:1492-1496); (b) margin / exposure rescue down to 50% of the intended lot
  (14:653-685, 13:2396-2420, by design); (c) `EnableGridNeverBelowPrevious=false` plus a previous rung boosted by
  GridAdditionQuality up to x1.15 (H-06); (d) SZR is now floored (13:2302-2327) - only if the factor were < 1.
- Can the ladder exceed the affordability projection? Yes: H-01 (first lot not balance-sized), H-03 (depth cap blind in
  cashback), H-05 (absolute floor overrides a gentler shape upward at rungs 4-5).
- Soft cautions do act in the grid: when they cut below the floor the rung is flagged `G_GRID_LOT_CAUTION_FLOORED` and held up
  to 10 M1 bars / +50% distance (13:2256-2283), unless rescue. See H-05 for why this flag is set far more often than intended.

---------------------------------------------------------------------------------------------------
## 4. Exit judgements (24_Position_Brain.mqh)

Recovery Judge (`MBRecoveryEvaluate` 24:281-388), once per M1 bar from DD >= 25% of balance:
| # | Reading | neg / pos | Key? | TF / units |
|---|---|---|---|---|
| 1 | thesis DEAD (G_MB_PB_DEAD) / threatened / alive | neg / neg / pos | DEAD = key | death = M5..H4+KEY reversal, M15+ MSS/acceptance, MB thesis invalidated (24:208-239) |
| 2 | M15 brain bias <= -2 / >= +1 | neg / pos | no | G_MB_BIAS |
| 3 | confirmed liquidity reversal against, M15..H4+KEY, since `opened` | neg | key | **same events as #1** (H-04) |
| 4 | adverse move spent / fresh | pos / neg | no | M5 impulse speed, accel |
| 5 | zone/FVG within 1.5 x ATR(M15) | pos / neg | no | ATR15 points, ok |
| 6+7 | ladder used (orders >= `GridEffectiveMaxOrders`) or margin level < 300% or BE >= 4 ATR15 | neg / pos | no | maxo is miscomputed in cashback (H-03) |
| 8 | H1 and H4 states both against | neg | no | G_MB_TF_STATE[3],[4] |
| 9 | news surprise already out | neg | no | calendar |
IMPOSSIBLE = neg >= need (4 below 35%, 3 at 35-45%, 2 at >= 45%) AND a key reading AND neg > pos; armed after 3 consecutive M1
bars; exit on a bounce of 0.3 x ATR(M1) from the worst price or at once if DD rises 3% more (24:396-421). Grid frozen while
DEAD / armed / DOUBTFUL (DOUBTFUL is stepped over by the rescue guarantee; DEAD and armed are not, 24:893-925).

Soundness:
- Units and TFs are consistent (DD in % of balance, ATR in points x _Point, M1 ATR for the exit bounce, M15 ATR for zone reach).
- It can fire: a grind against the basket produces M15+ ACCEPTANCE events (18:470-484) which kill the thesis (the key).
- It fires too easily because one fact is counted twice and a rescued basket keeps its old key (H-04).
- After a rung closes alone the judgement is lost (round-1 F-C7, still open: identity = oldest open time, 24:723-746). In
  cashback mode package 4's common broker TP makes a lone rung close rare; in normal mode the first order still carries its
  own broker TP from entry (guess: rare, needs an EA target > 2125 + the averaging distance).
- `MBPositionBrainUpdate` runs before the grid engine refreshes G_BASKET_DD_PERCENT / G_BASKET_POINTS (16:893 vs 13:2584):
  the judge and MFE/MAE read the previous tick's values (P4, one tick).

`MBBasketBreakEvenExit` (24:1069-1108): closes at +30 pts and net >= 0 when DEAD, DOUBTFUL, deep-and-back, stale (90 min,
peak DD >= 8%), or expectation failed (20 min, MFE < 35% of TP and the tape turned). Never a loss on the check tick. OK.
`MBLocalBasketExit` (24:428-458): net >= 0.00, no point cover. OK (slippage = round-1 F-C13).
Runner (24:478-584, normal mode only): see H-08.

---------------------------------------------------------------------------------------------------
## 5. Findings

### H-01 - CONFLICT - P2 (money) - the floors undo the balance-sized lot, so small accounts trade a ladder the affordability check never approved
- File: 14_Risk_Gates_Entry.mqh:857-866 (`LotForCurrentEntry`), 14:944-967, 14:1118-1124; 10_Basket_Stats_Context.mqh:4575-4580 (`LadderIsAffordable`); 14:4664-4684 (trim)
- Code:
  - 14:860 `double fitted = AffordableStartLot(bs_dir); if(fitted > 0.0 && fitted < lot) { ... lot = fitted; }`
  - 14:950 `double lot_floor = StartLot * MinFirstEntryLotFactor;` (default 1.0) ... 14:965 `if(lot < lot_floor) lot = lot_floor;`
  - 14:1122 `double floor_lot = NormalizeVolumeSafe(StartLot * MathMax(0.1, MathMin(1.0, EntryLotAbsoluteFloor)));`
  - 10:4577 `double fitted = AffordableStartLot(dir); if(fitted > 0.0 && fitted < base_lot) base_lot = fitted;`
- Cause: V285 sizes the first lot down to what the balance can carry, and `LadderIsAffordable` projects the ladder from that
  fitted lot. Both floors are anchored on the raw StartLot input, so the fitted lot is lifted back to 0.25 (then at most x0.80).
  The same happens to `UseAutoLot=true` when the auto lot is below StartLot.
- Effect: below about $3,706 balance (StartLot 0.25, 5 rungs, 5500-pt gaps, $0.10/pt/lot - assumptions) the check says "the
  full ladder fits" (`G_AFFORD_RUNG_CAP = 0`, 14:4683) while the basket actually opens at 0.20-0.25. Computed SL depth with the
  0.25 ladder: $1,000 balance -> 50% SL at 11,470 pts adverse after 3 rungs; $2,000 -> 16,480 pts after 3 rungs; $3,000 ->
  19,720 pts after 4 rungs. Rungs 4-5 that the recovery maths counts on are never reached. FAILED (arithmetic above), owner
  account size unknown - if it is above ~$3.7k this is dormant.
- Reproduce: balance < $3.7k, `EnableLotTrace`: trace shows `base=0.13 ... -> floor=0.25`; no "[SIRUS v282 TRIM]" line; basket
  closes on "Basket SL percent DD" with orders=3 or 4.

### H-02 - RESULT IGNORED - P3 - seventeen *LotAdjust steps (including the protection trims) are erased by the 1.0 floor
- File: 14:922-941 then 14:944-967; 23_Entry_Engine.mqh:1210-1215; 10:97-110
- Code: `lot = SelfDefenseLotAdjust(lot); ... lot = MBEntryLotAdjust(lot); ... if(lot < lot_floor) lot = lot_floor;`
- Cause: `MinFirstEntryLotFactor=1.0` (01_Inputs:32, "Keep at 1.0") turns every trim before it into a no-op, including the
  account-protection ones (self-defense x0.5, Pack4Mini CONSERVATIVE first cap 0.10, correlation x0.35) - unlike the grid
  lot, where hard limits run after the floor (13:1488-1496).
- Effect: the opening lot is 80-100% of StartLot in all conditions (section 1). The owner rule "CAUTION lot ineffective" is
  met, but only as a side effect: the code still multiplies x0.75 (23:1213), and lowering `MinFirstEntryLotFactor` would
  silently turn CAUTION (and 16 other trims, worst case 3.5e-5) back on. Cost: SwingImpulse's swing scan, DXY's three-symbol
  read and the correlation loop run on every lot call; logs print "lot trimmed x0.50 (not blocked)" for trims that never
  happen. Two trims are near-permanent (guess): Spread/ATR on M1 gold, and MarketConfidence's neutral x0.8.
  Same-fact pairs: HTFStructure vs arbiter VH veto (already decided), ImpulseCorrection vs SwingImpulse (one disabled),
  SwingImpulse's Kalman H1 slope = the legacy HTF reader package 1 retired elsewhere. The SelfDefense `LT_STEP("defense")`
  is inside the comment (14:940), so its cut is shown under "judgeCaution". P4 part.
- Reproduce: any entry with `EnableLotTrace`: `G_LOT_TRACE` ends `-> judgeCaution=0.xx -> floor=0.25`.

### H-03 - CONDITION WRONG - P2 (money) - grid depth limit uses the unclamped cashback spacing (672 pts) and never caps
- File: 04_Trend_Structure.mqh:1959-2030 (`GridEffectiveMaxOrders`), 12_Exits_Trailing.mqh:1790-1795
- Code: `double span_pts = (double)(base - done) * MathMax(1.0, AutoGridBaseDistance()) * 0.5;` with
  `return MathMax(1.0, rebate_tp * RebateGridSpacingMultiple);` (224 x 3 = 672)
- Cause: the real step is clamped to >= 5500 (13:1293-1300; `AffordableStartLot`/`LadderIsAffordable` apply the same clamp),
  this function does not. It also uses a flat half-span, StartLot x 1.30^n instead of the real rungs, and ignores the loss the
  basket already carries.
- Effect: for the remaining 4 rungs of a 0.25 basket it projects 2.01 lots x 1,344 pts x $0.10 = **$270**, while the real
  cost is about **$1,853** - a 7x under-estimate, so the cap never binds in cashback mode. The Recovery Judge's "ladder used"
  reading (24:349-352) and the reserve-rung rule (24:998-1048) read the same uncapped `maxo`. FAILED in cashback mode
  (arithmetic); normal mode (base 6500/7000) is close to correct.
- Reproduce: cashback basket with orders >= 2 and DD rising; `GridEffectiveMaxOrders` reason string stays empty
  ("depth capped at ..." never printed) while the projected full-ladder loss exceeds 0.75 x 50% of balance.

### H-04 - CONDITION WRONG - P2 (money) - Recovery Judge counts one reversal twice and keeps it after a rescue
- File: 24_Position_Brain.mqh:212 (death reason), 24:323-324 (reading 1), 24:335 (reading 3), 24:363-367, 24:760-782 (rescue)
- Code: 24:212 `if(MBReversalAfter(-dir, 1, 4, true, since, what, swt)) return "confirmed liquidity reversal against it: "...`;
  24:324 `{ neg++; key = true; wn += "thesis dead; "; }`; 24:335 `if(MBReversalAfter(-dir, 2, 4, true, opened, rv, rvt)) { neg++; key = true; ...}`
- Cause: an M15/H1/H4/KEY confirmed reversal against the basket kills the thesis (tf range 1..4 covers 2..4) and is then
  counted again as reading 3. Reading 3 is anchored on `opened`, not on the rescue time, so after `RESCUE` (24:776-781, dead
  flag cleared) the old reversal is still a key reading.
- Effect: one market fact = 2 "against" + key. At DD >= 45% that alone is IMPOSSIBLE when at most one reading is "for"; at
  35-45% it needs only the routine depth reading (a full ladder is "ladder used" by definition). The code comment (24:236-240, "only given up when the evidence ... is broad")
  says a basket is given up "only when the evidence ... is broad". A rescued basket can be armed and closed in loss on a
  reversal the rescue had already answered. FAILED (logic, statically).
- Reproduce: log `[SIRUS RECOVERY] ... -> IMPOSSIBLE (against 3 / for 1 ...) | against: thesis dead; reversal against: ...`
  with the same sweep named in the preceding `[SIRUS POSITION] ... thesis DEAD (confirmed liquidity reversal against it: ...)`;
  or the same after `RESCUE allowed`.

### H-05 - CONFLICT - P3 - grid absolute floor uses LotMultiplier, not the shape's multiplier, and anchors on floored rungs
- File: 13_Grid_Engine.mqh:1381-1387, 1470-1482; 11_Expectancy_MTF_News.mqh:464, 483, 524-529; hold 13:2256-2283
- Code: `double eff_mult = LadderMultiplier();` ... `double intended_progression = StartLot * MathPow(LotMultiplier, ...);`
  `G_GRID_LOT_CAUTION_FLOORED = (lot < floor_lot * 0.99);`
- Cause / effect:
  1. Long (1.20) and cautious (1.22) shapes: floor/pure = 0.8 x (1.30/1.20)^(n) reaches 1.017 at rung 4 and 1.10 at rung 5
     (cautious: 1.03 at rung 5). With ZERO cautions the rung is lifted above what the shape asked for (rung 5: 0.571 instead
     of 0.518 lots at StartLot 0.25) AND flagged "caution floored", so it is held up to 10 M1 bars.
  2. Once a rung goes in at the floor, the next pure target (floor x mult) equals the next absolute floor, so any soft factor
     below 0.99 - e.g. Grid Intelligence's neutral x0.85 - flags and holds every later rung. With the 1.30 shape a single soft
     factor below 0.80 (Spread/ATR x0.7 is enough) floors rung 2: 0.25 -> 0.26 (+4%), the "undersized addition" the code
     comments call the worst case.
- Reproduce: `[SIRUS GRID CAUTION HOLD] released after 10 bars` on consecutive rungs; `GRID: WAIT | holding rung - cautions
  cut lot to x0.85` on a long/cautious ladder.

### H-06 - CONDITION WRONG - P3 - a rung can be smaller than the one before it
- File: 13:1433 (`lot *= gq_f`, up to 1.15), 13:1467-1468 (`EnableGridNeverBelowPrevious` default false), 13:1470-1477
- Cause: the absolute floor only guarantees 1.04 x previous when the previous rung sat on its own progression. A previous rung
  boosted by GridAdditionQuality (x1.15) followed by heavy soft cuts: rung 2 = 0.25 x 1.3 x 1.15 = 0.374, rung 3 floored at
  0.8 x 0.25 x 1.69 = 0.338 < 0.374. Hard limits and margin rescue can shrink a rung by design (section 3).
- Effect: inverted martingale step (full new exposure, little average improvement). Rare; NOT YET VERIFIED.
- Reproduce: deal list with GRID n volume < GRID n-1 volume and no "MARGIN RESCUE" line.

### H-07 - SIGNAL/DATA LOST - P3 - cashback basket target ignores swap
- File: 11_Expectancy_MTF_News.mqh:1164-1165 (`if(EnableRebateMode) return tp;`), carry floor only at 09:2562-2570 / 2642-2650;
  check 12:1656 (points only)
- Cause: the swap/carry floor lives in `Pack2BasketTPForOrders`, which rebate mode never reaches; "Basket TP points" compares
  price points only (CurrentBasketPoints 10:338).
- Effect: a grid basket held overnight closes at "+224 pts" with a net money result that can be negative if swap per lot
  exceeds about $22.4 (224 pts x $0.10). This is a loss close outside IMPOSSIBLE. Guess: depends on the account's swap
  status (Exness swap-free status is common for XAU); NOT YET VERIFIED.
- Reproduce: deal history - basket closed with comment "Basket TP points" whose summed profit + swap < 0.

### H-08 - CONFLICT - P3 (normal mode) - first-order broker TP sits below the runner arm point
- File: 14:1215-1253 (`EntryTPPoints`, floor 2000 x 0.85), 24:532-537 (`arm = MathMin(2200, 0.88 * tp_points)`), 12:1594
- Cause: the broker TP (>= 2125) and the EA target (`BasketTPForOrderCount`: x0.6..1.35 factors, situation plan 1200-6000,
  contextual up to x2, TP intelligence) are separate chains. When the EA target is >= ~2415, arm = 2200 > broker TP 2125,
  so the broker closes the 1-order basket before the runner can arm and clear the TP (`MBRunnerClearBrokerTP` runs only on
  arm). This is the same failure the runner header (24:455-459) says it fixed.
- Effect: in normal mode the "smart runner" cannot run exactly when the EA thinks the move has more room. Cashback mode is
  unaffected (runner disabled there by design).
- Reproduce: normal mode, `[SIRUS v170 TP] 2125 -> 2700` or a `[SIRUS v220 PLAN]` target > 2415, then a broker TP deal at
  ~+2125 with no `[SIRUS RUNNER] ... basket runs` line.

### H-09 - CONDITION WRONG - P4 - projection sizing is bounded away and uses a stale shape
- File: 08_Scanner_Score.mqh:5050-5081; 14:1058; 06_Basket_Session.mqh:791-821
- Cause: `G_PROJECTION_LOT_FACTOR` can be 0.45, but `EntryLotFactorMin=0.80` and the 0.80 absolute floor keep the real lot >=
  80%, so "[SIRUS v159b PROJECTION] size scaled to 45%" is not what is traded (with `ProjectionHardBlock=false` nothing else
  acts). `ProjectBasketRisk` walks `NextGridLot` with the PREVIOUS basket's `G_LADDER_MULT` (shape chosen only at entry,
  11:423) - the same stale-shape defect already fixed in `LadderIsAffordable` (10:4522-4530). The factor is written only
  inside the scan block, so a fast/queue entry reuses an older bar's value.
- Effect: log/trace mislead; mild under/over-sizing within the 80-100% band.

### H-10 - NEVER CALLED (effectively) - P4 - three branches that cannot change an order
- Margin-level lot trim (12:2113-2126, used at 14:934 and 13:1496): it trims below 150% margin level, but `MarginAllowsOrder`
  (14:722-743) refuses any order whose projected level is < 200%, and the margin rescue (14:653-685) uses the same check -
  so a trimmed order is never sent.
- Zone TP cap in cashback mode (14:1340, 14:1382): `min_floor` equals the TP, the cap can never pass `capped > min_floor`.
- Micro TP (08:524): clamped to >= 2000, then floored again to FirstEntryTPMinPoints 2000 (14:1250) - about equal to the main TP.

### Round-1 items touched and still open (not re-reported)
- F-C12 (cashback EA target floats with the live spread vs the first order's entry-time broker TP): still true for 1-order
  baskets; package 4 fixed it only for 2+ orders (backup TP re-synced within 60 pts).
- F-C7 (judgement lost when the oldest rung closes alone): code unchanged (24:723-746); in cashback the common broker TP of
  package 4 makes the trigger rare.

### Checked and OK (STATICALLY PRESENT, NOT YET VERIFIED)
- MaxLot is a true ceiling on both paths (14:974-978, 13:1498).
- `LotForCurrentEntry(false)` and the projection call do not overwrite the armed scale-in remainder (14:1099-1106, 1137-1148).
- Scale-in completion carries the first part's TP and is skipped if that TP is already within reach (13:2646-2690).
- BrokerBackupSync never loosens a profit-lock SL and keeps the basket TP 50 pts beyond the EA's own target (12:1520-1545).
- Recovery exit, dead-thesis BE, local and stale exits are money-checked (profit >= 0) except the IMPOSSIBLE exit, which is
  the owner's only allowed loss close.
- Cashback rebate TP is net of spread (measured from the entry price) and stays above the broker stop level.
- Runner, trailing and rebate-trailing are off in cashback mode (`EnableRebateTrailingMode=false`, 24:480, 24:525).
