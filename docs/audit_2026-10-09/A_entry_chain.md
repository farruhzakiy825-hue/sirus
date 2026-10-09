# Auditor A: first-entry decision trace, from OnTick to the order send

Scope: the real execution order from `OnTick` to `G_TRADE.Buy/Sell` for a FIRST entry, every writer of the
decision state, and every path that opens a first-entry position. This was a READ-ONLY review. No repo file
was changed.
Citations point to the per-file sources in /home/user/sirus (branch claude/sharp-tesla-dgetgj, HEAD a0e0ea8).

Status vocabulary follows the brief. RUNTIME evidence comes from the two shadow CSVs (older code, 06-09 Oct).
Gate families seen there: score 820, brainVeto 528, velocity 235, TAKEN 134, cooldown 65, risk 60,
zone 46, other 40, news 39, drift 35, calendar 31, location 18, brainWait 12, env 2. Of the 134 TAKEN rows,
60 have `brain_bias` against the entry direction. No TAKEN row has an opposite-direction TAKEN in the same
minute.

---------------------------------------------------------------------------------------------------
## 1. Stage table (execution order of one live tick)

| # | Stage (file:line) | Reads | Checks | Writes | Hands to next stage / why it continues or blocks | Status |
|---|---|---|---|---|---|---|
| 0 | `OnTick` Sirus_Brain_V8.mq5:1398 | - | `SafetyValveCheck()` (1403, may stand down HTF / location gate, see A5), velocity/live sample/structure updates | G_TICK_COUNT, valve state | always calls `CoreUpdate("TICK")` (1429) | STATICALLY PRESENT |
| 1 | `CoreUpdate` 16_Dashboard_Core.mqh:841 | source | EmergencyBasketForceCloseCheck first; `source=="TIMER"` -> clock-only work then **return** (857-863), so the timer never trades; `source!="INIT"` gates grid and entry (969) | - | the Market Brain updates (869-883) run before the scanner. MB* state is fresh for this tick | STATICALLY PRESENT |
| 2 | `ScanDue` 16:801 | bar, bid, ATR, G_BASKET_ORDERS | new M1 bar / basket count changed / >=ScanMaxSeconds(3s) / move >=0.10 ATR | G_SCAN_ORDERS_SEEN | true -> full scan (919-939); false -> `ScanSnapshotRestore` (942). The snapshot covers only OPP_* and SCORE_* fields (816-838), see A3 | STATICALLY PRESENT |
| 3 | `UpdateOpportunityScanner` 08_Scanner_Score.mqh:8 | detectors 07 | `ResetOpportunity("no candidate yet")` (51) zeroes OPP/SCORE (and also G_BASKET_ORDERS, G_RISK_HARD_BLOCK...: 05:3505,3527). Detectors run, then the consensus may flip the side (08:160-180) | G_OPP_DIR/TYPE/SCORE/GRADE, G_OPP_VOICES_*, G_OPP_DIR_CLARITY | best side by score, or by crowd (consensus) | RUNTIME VERIFIED (score gate fires) |
| 4 | `UpdateSignalScoreEngine` 08:1884 | G_OPP_* | resets G_ENTRY_AGAINST_GLOBAL (1892); ScoreHardBlockCheck (chaos/spread/stale), which the block safety valve can release (1918-1935); sets MIN (1967); arm confirmation (1991); **early `return` with WAIT when SetupArm holds (2873, 3172, 4736, 4823, 4911, 5254, 6299, 6341). This happens BEFORE G_SCORE_FINAL is computed at 6553, so FINAL stays 0 (see A1)**; directional hard blocks blow-off 6649, wall 6696, counter-context 6757; final decision 6877-6889 | G_SCORE_DECISION/FINAL/MIN/BONUS/PENALTY, G_PENALTY_RAW (5851), G_ENTRY_AGAINST_GLOBAL (1473), G_SCORE_HB_DIR_WHY, G_ARM_* | PASS / MICRO_PASS / WAIT / HARD_BLOCK / NONE | RUNTIME VERIFIED (family "score") |
| 5 | `UpdateDirectionRedirectEngine` 09_Redirect_Queue_Pack2.mqh:422 | G_SCORE_DECISION, G_OPP_SCORE | runs only on WAIT (RedirectOnlyOnScoreWait); the opposite candidate must score >= original+1 | `ApplyRedirectOpportunity` (391) overwrites G_OPP_DIR/TYPE/SCORE/GRADE/REASON; then `UpdateSignalScoreEngine("REDIRECT_RESCORE")` (16:925) | the redirected side stays even if its rescore is WAIT (A15) | NOT YET VERIFIED |
| 6 | Legacy packs 16:926-932 (DLP 15:2426, DBOS, DTZ 15:3083, DNV, DET, DRT) | DeepOpportunitySign() = G_OPP_DIR at scan time | each adds bonus/penalty via `LegacyApplyScoreChange` (15:682) and **re-derives the decision from score alone** in `LegacyRecalculateDecision` (15:721-730); strict entry-block flags are directional (default off) | G_SCORE_FINAL/DECISION, G_DLP/DBOS/DTZ_ENTRY_BLOCK | A WAIT can become PASS (A1) | NOT YET VERIFIED |
| 7 | `UpdateSignalQueueEngine` 09:1320 | decision, dir | saves any PASS (1043); replays when the current decision is not PASS (`!IsScorePassedDecision`, so HARD_BLOCK and arm-WAIT included) after `QueueCanReplay` (1080-1210) | `ReplayQueuedSignal` (1215) overwrites G_OPP_DIR/TYPE/SCORE, G_SCORE_DECISION/FINAL/MIN, sets `G_SCORE_HARD_BLOCK="none"` | queued direction becomes the decision (A2) | NOT YET VERIFIED ("drift" family is the queued-signal drift gate, RUNTIME VERIFIED) |
| 8 | `UpdateMissedTradeMemory` / `UpdateMicroScalpLayer` / `UpdateBlockExpiryEngine` 16:934-938 | WAIT, block age | missed-memory boost (09:1688), expired-block soft pass +1 (09:841-863) | G_SCORE_FINAL/DECISION, G_MICRO_READY | more WAIT -> PASS conversions | NOT YET VERIFIED |
| 9 | `ScanSnapshotSave` 16:816 | OPP_*/SCORE_* | - | SN_* | state is frozen here. Everything mutated later in the tick is NOT in the snapshot | STATICALLY PRESENT |
| 10 | GUARDS 16:945-966 | - | UpdateRiskEngine, Pack3, P4M, RCB, DCS... | G_RISK_HARD_BLOCK, G_PACK3_*, G_DCS_* | non-directional flags for stage 13 | RUNTIME VERIFIED (family "risk") |
| 11 | `UpdateGridRecoveryEngine` 13_Grid_Engine.mqh:2582 | G_SCALEIN_* | **scale-in completion sends an order** (2589-2640, see A10); `RefreshGridDashboardStats` restores G_BASKET_ORDERS | basket stats | - | NOT YET VERIFIED |
| 12 | `UpdateFirstEntryEngine` 14_Risk_Gates_Entry.mqh:4871 -> `FirstEntryCanRun` 14:4172 | everything above | see rows 13-21 | G_ENTRY_READY | false -> GateRecord / MBMissedNote / shadow, then **return** (4942-4979) | RUNTIME VERIFIED (gate families) |
| 13 | FECR early gates 14:4195-4300 | G_BASKET_CLOSED_TICK, AllowLiveTrading, G_ENV_READY, risk, Pack3, P4M, P4L, RCB, DCS, **DLP/DBOS/DTZ/DNV/DET/DRT flags (directional, computed for the SCAN direction)** | each returns false with a reason | reason | run BEFORE the fast path or redirect can change direction (A9) | RUNTIME VERIFIED (risk/env) |
| 14 | Score relaxations 14:4303-4419 | WAIT, G_ARM_DIR != dir | 5A/5B relief (4310), brain relief `MBBrainScoreRelief` (4375), judge bypass with a judge PROBE (4392-4404), evidence-gate EG_SCORE (4409-4419) | **G_SCORE_DECISION -> PASS** (4358/4383/4401/4415) | all for the detector direction; the arm guard `G_ARM_DIR != dir` is present here and missing at stages 6 and 7 | NOT YET VERIFIED |
| 15 | Market Brain fast path 14:4430-4489 | decision, det_dir | probe veto on the detector PASS (`det_vetoed`, 4433-4442, probe made BEFORE scenario adj / redirect, A7); hb_directional (4444); `MBFastEntryCandidate` 23_Entry_Engine.mqh:852 -> `MBCandOk` 23:755 (MBDirOk 23:713 + MBPermissionCheck + MBVetoAllowsEntry as probe) | **G_OPP_DIR, G_OPP_TYPE, G_OPP_REASON, G_SCORE_FINAL=max(old, min+2), G_SCORE_DECISION=PASS, G_ENTRY_AGAINST_GLOBAL, G_PENALTY_RAW=0, G_SCORE_IS_MICRO=false, G_SCORE_MIN_REQUIRED (if 0), G_MB_FAST_ACTIVE** (4466-4487) | the direction can change here. The final veto and judge (row 20) see the new one | STATICALLY PRESENT |
| 16 | Score check 14:4491 | decision | not PASS -> near-miss log, return false | - | - | RUNTIME VERIFIED ("score") |
| 17 | Location guard 14:4521-4552 (skipped when `MBOwnsGate(true)`) | G_OPP_DIR | LocationZoneRefuses / LGFreshImpulse / LGChasingImpulse / LGMicroTip; a level block -> `TryLocationRedirect` 14:4016 (once per bar per from_dir via static at 4020-4025; LocationBrain + HTF + voices + LG checks for to_dir; `ApplyRedirectOpportunity` + `UpdateSignalScoreEngine("LOCATION_REDIRECT")` 4103-4104; restores everything on failure, 4115-4126) | on success **G_OPP_DIR/TYPE/score flipped**, G_MB_FAST_ACTIVE=false (4128) | the later gates and the veto/judge see the flipped side | RUNTIME VERIFIED ("location"); redirect NOT YET VERIFIED |
| 18 | Misc gates 14:4555-4695 | - | micro ready, direction != NONE, OneBasketAtATime (live positions), cooldown bars/seconds (MinSecondsBetweenEntries=10), operator, DPG, sanity, license, setup doctor, retry engine, calendar, holiday, weekend, time filter, fresh bar, account mode, velocity, drift, M1 close | - | - | RUNTIME VERIFIED (cooldown, velocity, drift, calendar) |
| 19 | Score-cost gates 14:4697-4842 | G_SCORE_FINAL vs MIN+cost | Clarity (4697), Scenario **writes G_SCORE_FINAL += adj** (4731), FailedBreak, OldLevel, HTF bias (4782), NewsOwner (4804), LocationBrain (4819). Gates with `MBOwnsGate(false)` always stand aside for a fast entry; HTF/LocationBrain can be stood down by `ValveIsOff` (A5) | G_SCORE_FINAL | - | RUNTIME VERIFIED ("news"/"zone"); others NOT YET VERIFIED |
| 20 | Final veto + judge 14:4847-4865 | mb_dir = final G_OPP_DIR | `MBVetoAllowsEntry` 21_Direction_Veto.mqh:700 (anomaly, V0 `MBPermissionCheck` 21:621, reversal, zone V2/V3, accel, V5 exhausted, lock, late, reentry, cost, council `MBCouncilBlocks` 21:541 memo keyed by tick msc+dir); `MBEntryJudgeAllows` 23:244 (location/trigger/timing/quality -> EXECUTE/CAUTION/WAIT) | G_MB_ENTRY_DECISION/QUALITY (lot), G_MB_SIG_* anchor | this is the only `return true` (4866-4868). **Every first-entry order is judged on the direction it is sent in** | RUNTIME VERIFIED (brainVeto, brainWait) |
| 21 | Ladder affordability 14:4906-4940 | G_OPP_DIR | trim -> G_AFFORD_RUNG_CAP or refuse | G_AFFORD_RUNG_CAP | - | NOT YET VERIFIED |
| 22 | Prices/TP 14:4981-5002, `BuildEntryPrices` 14:1280, `EntryTPPoints` 14:1201 | order_type = G_OPP_DIR (4981) | rebate TP (cashback), spread-aware, zone cap, stop/freeze widen | price, sl, tp | the TP is absolute, taken from the pre-send quote | STATICALLY PRESENT |
| 23 | Lot `LotForCurrentEntry` 14:828 | G_OPP_DIR, G_SCORE_FINAL/MIN (confidence lot), **G_PENALTY_RAW**, G_PROJECTION_LOT_FACTOR, G_SITUATION(_DIR), G_MB_ENTRY_DECISION | caps/floors, scale-in split **writes G_SCALEIN_PENDING_LOT before the send** (1092) | lot | margin check 5009 | STATICALLY PRESENT |
| 24 | Rental stagger 14:5036-5061, SmartFill 14:5066-5125 | ticks, bid, spread | stagger returns; SmartFill **arms and returns on the first ready tick** (5086-5096) unless `MBMomentumNow`; fires on pullback 120 pts / spread dip 80 / timeout 8 s on a LATER tick where the whole chain re-ran | G_SF_* | see A4 | NOT YET VERIFIED |
| 25 | Send 14:5128-5151 | lot, sl, tp, comment | `G_TRADE.Buy/Sell(lot,_Symbol,0.0,sl,tp,comment)`; `TradeRetcodeFilled` = DONE/DONE_PARTIAL/PLACED (13:1632); partial fill folded into the scale-in amount (5159-5171) | - | - | RUNTIME VERIFIED (TAKEN) |
| 26 | Success 14:5173-5329 | order_type | G_LAST_ENTRY_TIME/BAR, SetBasketThesis/ChooseLadderShape(entry_dir_now) (reads **G_ENTRY_AGAINST_GLOBAL**, 11:494), MBFastEntryFilled, ScaleInArm(G_OPP_DIR) 5271, ClearSignalQueue | basket context | - | RUNTIME VERIFIED (TAKEN) |
| 27 | Failure 14:5330-5366 | retcode | IsTransientTradeRetcode (11:4574) -> RetryEngineAllowsFirstEntry (11:4584) on later ticks; the whole chain re-decides each retry | G_FIRST_LAST_FAIL_* | - | NOT YET VERIFIED |

Paths that SEND an order:
1. First entry at 14:5143-5146 (the only first-entry send).
2. Scale-in completion at 13:2624-2626 (adds the held-back part of the first entry).
3. Grid add at 13:2767-2769 (out of scope).

No other `OrderSend`, `PositionOpen` or pending-order call exists (grep over Sirus/*.mqh and Sirus_Brain_V8.mq5).
OnTimer and INIT cannot reach any of them (16:857-863, 16:969).

**Direction integrity (question 1 / 3).** Nothing between the final veto+judge (14:4850/4858) and
`order_type` (14:4981) writes G_OPP_DIR. The callees in between are GateRecord, MBShadowOnDecision,
QuietTick, DecisionChainLog and LadderIsAffordable. The writers of G_OPP_DIR are listed in Section 3.
Every first-entry order is therefore sent in the direction that the final `MBVetoAllowsEntry` and
`MBEntryJudgeAllows` evaluated. I found **no path that sends a first entry in a direction no
direction-check has seen**. The weaknesses are in what reaches that final check, and with what stale
context (A1-A6).

---------------------------------------------------------------------------------------------------
## 2. Findings

### A1 - Legacy score integration turns a setup-arm WAIT into PASS (the arm is bypassed)
- Category: CONFLICT / CONDITION WRONG. Severity: **P1 (conditional)**, otherwise P2. Status: STATICALLY PRESENT, NOT YET VERIFIED.
- Where:
  - 08_Scanner_Score.mqh:2873 / 3172 / 4736 / 4823 / 4911 / 5254 / 6299 / 6341 (`UpdateSignalScoreEngine`)
  - 15_Legacy_Packs.mqh:721-730 (`LegacyRecalculateDecision`), 682-688, 2512-2519 (DLP), 2833-2840 (DBOS), 3158 (DTZ)
- Code:
  ```
  // 08:2869-2874 (same shape at the other seven sites)
  SetupArm(entry_dir_i, ARM_REASON_EXTENDED, lae_px, "move already %.1f ATR extended - waiting for the pullback", false))
  { G_SCORE_DECISION = SCORE_DECISION_WAIT; ... return; }
  // 08:6553  G_SCORE_FINAL = G_SCORE_BASE + G_SCORE_BONUS - G_SCORE_PENALTY;   <- never reached on those returns
  // 15:721
  void LegacyRecalculateDecision()
  { if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK) return; if(G_SCORE_MIN_REQUIRED <= 0) return;
    if(G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED) { ... G_SCORE_DECISION = SCORE_DECISION_PASS; } else G_SCORE_DECISION = SCORE_DECISION_WAIT; }
  ```
- Cause:
  1. On a full scan `ResetOpportunity` sets G_SCORE_FINAL=0 (05:3423). The score engine sets MIN (08:1967) and then returns early on an arm, so FINAL stays **0**.
  2. The legacy deep-parity packs run next (16:927-932). They are ON by default (01_Inputs:1484-1486, 1505, 1524). They add their bonuses to that 0 and call `LegacyRecalculateDecision`, which decides on score alone.
  3. The bonuses add up: HTF aligned +2 (1495), M15 +1 (1496), zone +1 (1497), BOS aligned +2 (1512), trap / breakout +2/+2 (1530-1531). That reaches MinScoreBalanced=4 (1778) easily for a with-trend setup, so the arm-WAIT becomes PASS.
  4. `SetupArm` returns true on every scan while the objection holds (06:1509 `if(G_ARM_DIR == dir && G_ARM_REASON == reason_code) return true;`), so this can happen on every scan of the wait.
  5. FirstEntryCanRun never checks G_ARM_DIR for a PASS. The arm guard exists only on the relief and fast paths (14:4310/4375/4392/4413/4463).
  6. The fabricated PASS is also queued (stage 7) and so lives on for 3 more bars.
- Effect: the entries the score engine deliberately held go straight through:
  - "move already X ATR extended - waiting for the pullback"
  - "late entry - holding for a pullback"
  - "waiting for reaction edge"
  - "stop pool ahead"
  - "spread costs X% of target"
  - "better fill"
  - and, worst, **"%s - waiting for it to stop" (single opposite candle, 4736) and "waiting for the run to break" (opposite consecutive pressure, 4823)**

  In those last two the market is pushing against the entry right now. A first entry there builds a grid against the live move, which is P1 if nothing later stops it. Only the location guard, the veto (V5/V8) and the judge (`candles_against`, `leg_against`) stand in the way. Whether they reliably catch it is NOT YET VERIFIED.
  Side effect: `G_ARM_SETUP_SCORE`/`G_ARM_START_SCORE` record 0 (06:1529-1531).
- Reproduce: the journal shows `[SIRUS v194 ARMED] BUY held - ...` and, on the same or next M1 bar, `ENTRY SENT` with `score=PASS final≈4-8` and a SCORE DETAIL containing `deep parity htf` / `deep BOS` but no `confirmed:`.

### A2 - Queue replay overrides the current scan's HARD_BLOCK, arm-WAIT or fresh score WAIT for the same side
- Category: CONDITION WRONG. Severity: P2 (P1-candidate for the wall case). Status: NOT YET VERIFIED.
- Where: 09_Redirect_Queue_Pack2.mqh:1349-1352 (`UpdateSignalQueueEngine`), 1219-1300 (`ReplayQueuedSignal`), 1062-1210 (`QueueCanReplay`).
- Code:
  ```
  if(G_QUEUE_ACTIVE && !IsScorePassedDecision(G_SCORE_DECISION) && QueueCanReplay(replay_reason))
     ReplayQueuedSignal();
  ...  G_SCORE_DECISION = G_QUEUE_DECISION; ... G_SCORE_HARD_BLOCK = "none";
  ```
- Cause:
  1. HARD_BLOCK and WAIT both count as "not passed".
  2. `QueueCanReplay` re-checks only ENV, spread<=300, chaos, an opposite PASS, exhaustion consensus, global/local alignment, `CounterContextBlockNow`, ghost zone and collapse guard.
  3. It does **not** re-check:
     - the zone-wall hard block (08:6680-6701 "BUY into strong resistance wall")
     - the blow-off climax block (08:6630-6651)
     - the spread-economics block (08:4870-4879)
     - the projection block "ladder cannot survive even at minimum size" (08:5065-5073)
     - the tick-stale block
     - an armed wait (A1)
     - any penalty the fresh score just applied
  4. A PASS of the same side from up to 3 bars / 300 s earlier (01_Inputs:2343/2348) replaces the fresh refusal. `SaveCurrentSignalToQueue` re-saves every PASS on every scan (09:1034-1060). A PASS that was vetoed tick after tick therefore stays queued and comes back as soon as the score engine downgrades it.
- Effect: a fresh "do not BUY into this wall / after this blow-off" refusal is replaced by an older BUY PASS. Only the location guard, veto and judge remain. The ladder-survivability hard block can also be bypassed.
- Reproduce: `[SIRUS v31.6 PHASE 21.3 QUEUE] QUEUE: REPLAYED BUY ...` in the same scan as `[SIRUS BLOW-OFF HARD BLOCK]`, `into strong resistance wall` or `ladder cannot survive`, followed by `ENTRY SENT BUY`.

### A3 - Snapshot omits context that FirstEntryCanRun mutates; later throttled ticks carry it into a different entry
- Category: SIGNAL/DATA LOST (stale state). Severity: P2. Status: NOT YET VERIFIED.
- Where:
  - 16_Dashboard_Core.mqh:816-838 (the snapshot holds only OPP_*/SCORE_* fields)
  - 14:4473-4478 (fast path writes G_ENTRY_AGAINST_GLOBAL and G_PENALTY_RAW)
  - 14:4103-4104 + success path (location-redirect rescore writes G_ENTRY_AGAINST_GLOBAL, G_PENALTY_RAW, G_SITUATION(_DIR), G_OPP_IS_MICRO, G_SCORE_TP_TARGET)
- Code:
  ```
  G_ENTRY_AGAINST_GLOBAL = (fe_same_side && G_ENTRY_AGAINST_GLOBAL) || (MBBiasAlign(fe_dir) < 0);
  if(!fe_same_side) { G_PENALTY_RAW = 0; G_SCORE_IS_MICRO = false; }
  ```
- Cause:
  1. The scanner throttle is on by default (16:776). A tick without a scan restores G_OPP_DIR / score from the snapshot, but leaves G_ENTRY_AGAINST_GLOBAL, G_PENALTY_RAW, G_SITUATION(_DIR), G_OPP_IS_MICRO and G_SCORE_TP_TARGET as the previous tick's FirstEntryCanRun left them.
  2. Example: tick N has a detector BUY that is counter-trend (`G_ENTRY_AGAINST_GLOBAL=true`, warnings in G_PENALTY_RAW). The fast path finds a with-bias SELL, sets against=false and penalty=0, and is then refused by the judge.
  3. Tick N+1 has no scan. BUY is restored with against=false and penalty_raw=0. If BUY now passes (relief, judge bypass or the evidence gate, all re-evaluated live), `ChooseLadderShape` (11:494) does **not** cap the counter-trend ladder to CounterTrendMaxLadderOrders=3 (01_Inputs:4895). The lot and TP warning scaling (14:1025, 09:2605) see 0.
  4. Queue replay has the same problem: it inherits the current scan's against/penalty/projection flags, not the queued signal's own (09:1235-1295 never sets them).
- Effect: a counter-trend first entry gets the full ladder and the full lot. Conversely, a with-trend entry can be capped by mistake.
- Reproduce: `DecisionLog FAST ...` refused on one tick, then `ENTRY SENT` for the other side within ≤3 s on the same M1 bar, with `[SIRUS COUNTER-TREND] ladder capped` absent while the HTF trend is against the entry.

### A4 - A location redirect is armed by SmartFill and then refused on every later tick of the bar (signal lost)
- Category: SIGNAL/DATA LOST. Severity: P2. Status: NOT YET VERIFIED.
- Where: 14:4020-4025 (static once per bar per from_dir), 14:5086-5096 (SmartFill arm-and-return), 14:5074-5076.
- Code:
  ```
  if(lr_bar == G_BARS_SEEN && lr_dir == from_dir) return false;     // TryLocationRedirect
  else if(!G_SF_ACTIVE) { G_SF_ACTIVE = true; ... return; }          // SmartFill: nothing sent on the ready tick
  if(G_SF_ACTIVE && (sf_dir_now != G_SF_DIR || (sf_now - G_SF_ARM_TIME) > SmartFillTimeoutSec * 3)) G_SF_ACTIVE = false;
  ```
- Cause:
  1. On tick N, X is refused at a level, the redirect to -X succeeds and every gate passes. SmartFill (on by default, 01_Inputs:365) arms and returns without sending.
  2. On tick N+1 the scan or snapshot gives X again. The location guard refuses X, and `TryLocationRedirect` returns false because it already ran this bar. Nothing is logged about the lost redirect beyond `location: ...`.
  3. The armed SmartFill can fire only if the redirect succeeds again within 24 s, on the next bar. Otherwise it re-arms and the loop repeats. The only escape is `MBMomentumNow` (14:5078).
- Effect: the redirect, which is designed to take a BUY from support when a SELL at support is refused, almost never sends. The owner sees "location" refusals and no trade.
- Reproduce: `[SIRUS LOCATION REDIRECT] SELL blocked at a level -> BUY ...` followed by `ENTRY: SMARTFILL armed`, then `location: ...` refusals for the rest of the bar, with no `ENTRY SENT`.

### A5 - Direction gates auto-relax (owner rule "direction gates never auto-relax")
- Category: CONFLICT. Severity: P2. Status: NOT YET VERIFIED.
- Where:
  - 14_Risk_Gates_Entry.mqh:2470-2477 (`ValveForGate`), 2499-2541 (`SafetyValveCheck`), checked at 14:4782 (HTF bias) and 14:4819 (Location Brain)
  - 08_Scanner_Score.mqh:1503-1505 (naked counter-trend refusal released by the block safety valve)
  - 08:1918-1935 (ScoreHardBlockCheck chaos / extreme spread / stale tick released)
- Code:
  ```
  case GATE_LOCATION: return VALVE_LOCATION;  case GATE_REGIME: return VALVE_HTF;
  if(EnableHTFBias && !MBOwnsGate(true) && !ValveIsOff(VALVE_HTF))
  bool ct_valve_open = (EnableBlockSafetyValve && ... (G_BARS_SEEN - G_LAST_ENTRY_ALLOWED_BAR) >= BlockSafetyValveBars);
  ```
- Cause:
  - After 60 quiet bars, with ≥65% of refusals coming from the location or regime family, the HTF-bias gate or the Location Brain is switched off for 30 bars, up to 4 times a day (01_Inputs:983-991). The code itself calls the HTF bias "A direction question" (14:4781).
  - After 180 silent bars the counter-trend "nothing behind it" refusal (tier C) and the chaos / extreme-spread / stale-tick hard block are released for one entry.
- Effect: during a long one-way move (the quiet case these valves exist for) the gates that stop counter-trend first entries are switched off.
- Reproduce: `[SIRUS VALVE] ... standing it down` or `tier C released by the safety valve` / `[SIRUS v180 SAFETY VALVE]`, followed by an entry against the H1/H4 trend.

### A6 - A brain fast entry for the opposite side inherits the detector's score and MIN
- Category: CONFLICT. Severity: P2/P3. Status: NOT YET VERIFIED.
- Where: 14:4482-4484, used at 14:4782-4797 (HTF cost gate), 14:1044-1067 (confidence lot) and 14:5257-5261 (opening score/margin).
- Code:
  ```
  if(G_SCORE_MIN_REQUIRED <= 0) G_SCORE_MIN_REQUIRED = MinScoreForContext(false);
  G_SCORE_FINAL = MathMax(G_SCORE_FINAL, MBFastEntryScore(G_SCORE_MIN_REQUIRED));
  ```
- Cause: when `det_vetoed` or `hb_directional` makes the fast path take the OTHER side, G_SCORE_FINAL / G_SCORE_MIN_REQUIRED still hold the detector side's numbers. Example: BUY PASS score 12 vetoed, SELL fast entry stamped 12.
  - The HTF-bias cost gate still runs for a fast entry without "its own place" (bias neutral or against, e.g. SECOND-CHANCE / PULLBACK types; see `MBOwnsGate` 14:4147-4168). It compares that inherited score against `MIN + htf_cost`, so a counter-HTF SELL passes because the BUY scored high.
  - The confidence lot and the outcome attribution use the same number.
- Effect: the HTF tax is paid with the other direction's score. Lot conviction is wrong.
- Reproduce: `DecisionLog VETO` for BUY and `FAST BRAIN SECOND-CHANCE SELL` in the same tick. ENTRY DETAIL shows `score=` equal to the BUY's score.

### A7 - The veto is asked twice with different inputs (the probe disagrees with the final call)
- Category: CONFLICT. Severity: P3. Status: NOT YET VERIFIED.
- Where: 14:4433-4442 (probe on the detector PASS) versus 14:4850 (final); the score feeds V0 at 21:659.
- Cause:
  1. The probe runs before the scenario adjustment (14:4731 `G_SCORE_FINAL += adj`, ±3), before TryLocationRedirect and before the score-cost gates.
  2. The V0 a==-2 exception depends on `G_SCORE_FINAL >= MIN+2`.
  3. A probe "allowed" and a final "blocked" (after a negative scenario adj) means neither the detector nor the brain's other side trades.
  4. A probe "blocked" (score just short) hands the slot to the opposite-side fast entry. The final call, after +adj, would have allowed the detector's side.
- Effect: a silent tick, or a side switch decided on a pre-adjustment score.

### A8 - The V0 "exceptional reversal" score test is always met by a fast entry; the +2 is a hard-coded duplicate
- Category: CONDITION WRONG. Severity: P3. Status: STATICALLY PRESENT.
- Where: 23_Entry_Engine.mqh:762 (`G_SCORE_MIN_REQUIRED + 2`), 23:1117-1120 (`MBFastEntryScoreMargin`=2, 23:60), 21:659 (`MBPermExceptionMargin`=2, 21:70).
- Cause: the fast path stamps exactly MIN+2, which is exactly the V0 bar. Only `reversal_type && a7_rev` remains as the test. If anyone changes MBFastEntryScoreMargin, the probe (hard-coded +2) and the final veto disagree.

### A9 - Directional legacy entry blocks are computed for the scan direction but checked against the final direction (latent)
- Category: CONDITION WRONG. Severity: P3 (latent: strict inputs default false, 01_Inputs:1487/1506/1525/1559). Status: STATICALLY PRESENT.
- Where: 15:2477 (DLP), 15:2790 (DBOS), 15:3130-3152 (DTZ), checked at 14:4256-4282, which is BEFORE the fast path (4455), the location redirect (4535) and after the queue replay.
- Effect if enabled:
  - A "BUY into top zone" strict block computed for a SELL scan never sees a later fast BUY.
  - A block on the scanner's side kills the tick before the brain can take the other side.
  - Their bonuses and penalties (A1) are also written for the scan side only.

### A10 - Scale-in completion sends a first-entry order with no TP/SL and none of the entry-time gates
- Category: EXECUTION FAILS / RESULT IGNORED. Severity: P3. Status: NOT YET VERIFIED.
- Where: 13_Grid_Engine.mqh:2589-2640; armed at 14:5265-5272; due logic 06_Basket_Session.mqh:527-640.
- Code: `si_sent = G_TRADE.Buy(NormalizeVolumeSafe(si_lot), _Symbol, 0.0, 0.0, 0.0, si_comment);`
- Cause:
  - Its gates are only `AllowLiveTrading && G_ENV_READY && !G_RISK_HARD_BLOCK && !G_RISK_CLOSE_REQUEST`, a margin check, and thrust/wall quality.
  - It skips news-owner, calendar, velocity, spread and the veto/judge.
  - The direction is safe: it is matched to the live basket (06:540-569).
- Effect: the held-back part of the first entry can open inside a news window or on a spread spike, with no broker TP. Whether the basket TP manager re-attaches a TP is outside this audit.

### A11 - Smaller execution-stage issues
- Category: EXECUTION FAILS. Severity: P3.
- (a) The TP is an absolute price built from the pre-send quote (14:1290-1297). The send uses deviation 50 pts (01_Inputs:2394), and the cashback TP is about 224 pts, so slippage can eat up to about 22% of the target.
- (b) After a failed send, `G_SF_ACTIVE` was already cleared on fire (14:5116). The retry tick re-arms SmartFill and waits up to 8 s more on every retry.
- (c) Rental stagger: the static `rental_armed_tick` (14:5040) is not cleared when the setup disappears. A later, unrelated setup inherits the elapsed count and gets no stagger.

### A12 - A failed location redirect leaves redirect statistics behind
- Category: RESULT IGNORED. Severity: P4.
- Where: 09:397-402 (`G_REDIRECT_APPLIED = true; ... G_REDIRECT_SUCCESSES++`), called from 14:4103. The restore at 14:4115-4126 does not undo these.

### A13 - The scan-phase redirect keeps the flipped side even when its rescore fails; the original side loses relief
- Category: SIGNAL/DATA LOST. Severity: P3. Status: NOT YET VERIFIED.
- Where: 16:923-925, 09:495-512.
- Cause: on WAIT, a better-scoring opposite candidate replaces G_OPP_DIR, and `REDIRECT_RESCORE` may still be WAIT. FirstEntryCanRun's relief, judge bypass and evidence passes (14:4303-4419) then evaluate only the redirected side. The original side, which might have qualified for relief, is gone for this scan, and nothing logs it beyond the `REDIRECT` line.

### A14 - Reset helpers zero unrelated state
- Category: INSUFFICIENT EVIDENCE. Severity: P3.
- Where: `ResetOpportunity` 05:3505/3511/3527 (G_BASKET_ORDERS=0, G_BASKET_DIRECTION=-1, G_RISK_HARD_BLOCK=false), `ResetScoreEngine` 08:344/366, `ResetRedirect` 09:66/88.
- Effect:
  - Every scan does this. Between the scan and the next `UpdateRiskEngine` / `RefreshGridDashboardStats`, any reader sees a flat account with no risk block. For the first-entry decision itself the values are recomputed before 14:4220, so I found no entry impact.
  - If the location-redirect rescore ever hits `ResetScoreEngine` (opportunity grade NONE), the zeroing happens inside FirstEntryCanRun after the risk check. That tick then returns false, so no entry results. Whether the grade can be NONE there is NOT YET VERIFIED.

### A15 - Duplicate checks that can disagree (informational)
- Category: CONFLICT. Severity: P3.
- Location is checked five times:
  - location guard LG* (14:4521)
  - Location Brain (14:4819, and inside the redirect / queue replay)
  - veto V2/V3 zone (21:716)
  - council zone in front (21:528)
  - judge `zone_only` (23:518)

  Each has its own band and ATR.
- Lateness / chase is checked four times:
  - LGChasingImpulse
  - score late-entry arm (08:6294)
  - MBLateBlocks V8
  - judge `chase`
- Spread has several thresholds:
  - Pack3 300 (01_Inputs:1286)
  - queue replay 300 (2349)
  - temp-block soft 500 (3837)
  - score hard block 800 (3839)
  - DCS limit
  - MBCostBlocks
- MBCandOk runs MBDirOk, which calls MBCouncilOk / MBLockBlocks / MBLateBlocks / MBReentryBlocks / MBCostBlocks. It then calls MBVetoAllowsEntry, which runs the same checks again. The thresholds are the same, so this is cost only.

---------------------------------------------------------------------------------------------------
## 3. Every writer of the decision state between the score and the send (question 1)

| Global | Writers after the first score (in order) |
|---|---|
| G_OPP_DIR | consensus flip 08:168 (pre-score); `ApplyRedirectOpportunity` 09:406 (scan redirect, and again from TryLocationRedirect 14:4103); `ReplayQueuedSignal` 09:1235; `ScanSnapshotRestore` 16:833; fast path 14:4482; TryLocationRedirect restore 14:4117 |
| G_OPP_TYPE / G_OPP_REASON | same as above, plus fast path 14:4480-4483 (MBCandOk sets G_OPP_TYPE temporarily and restores it, 23:759-775) |
| G_SCORE_DECISION | score 08:6877-6889 + arm returns; legacy recalc 15:728-732 / 15:780-789; queue replay 09:1250/1279/1286; missed memory 09:1704-1706; block expiry 09:862; snapshot 16:835; relief 14:4358; brain relief 14:4383; judge bypass 14:4401; evidence 14:4415; fast path 14:4485; location-redirect rescore 14:4104/4112/4120 |
| G_SCORE_FINAL | score 08:6553/6832/6877; legacy 15:687/710; block expiry 09:861; queue 09:1254; missed memory 09:1696; snapshot 16:835; fast path 14:4484; MBCandOk temporary 23:762/775; scenario 14:4731; redirect restore 14:4119 |
| G_ENTRY_AGAINST_GLOBAL | 08:1892 (reset per score pass), 08:1473; fast path 14:4473; redirect restore 14:4121. **Not in the snapshot, not in the queue** |
| Lot / TP plan | G_PENALTY_RAW 08:5851/6817, fast path 14:4476; G_PROJECTION_LOT_FACTOR (score); G_MB_ENTRY_DECISION (judge probe 14:4397 and final 14:4858; the final one wins); G_SCALEIN_PENDING_LOT 14:1092/1096/1133 (before the send), 14:5168 |

## 4. Answers to the six questions (short)
1. Overwrites: Section 3. No writer runs after the final veto/judge. Direction changes (consensus, scan redirect, queue replay, fast path, location redirect) all happen before it. **A first entry is never sent in a direction no direction-check has seen.** Context flags, however, are stale or inherited (A3, A6).
2. Gate evaluated for one direction, order sent the other way:
   - A9 (legacy directional blocks, latent)
   - A6 (HTF cost on the other side's score)
   - A7 (probe vs final)
   - A3 (against-global / penalty flags)
3. Early returns that skip protection:
   - Every early return in FirstEntryCanRun refuses the entry. The only `return true` is after the veto and judge (14:4866-4868).
   - The bypasses come earlier, at the score level: A1 (arm bypass), A2 (hard-block bypass), A5 (valves).
   - The scale-in completion (A10) is the only order path outside the veto/judge, and its direction is safe.
4. Stale state:
   - A3 (snapshot omissions)
   - A4 (static once per bar plus SmartFill)
   - A11c (rental static)
   - G_ARM_START_SCORE=0 (A1)
   - The council memo keyed by tick msc+dir is correct (21:547-568): MBCouncilEval reads no decision state.
5. Duplicates that disagree: A7, A8, A15.
6. Correct signals lost:
   - A4 (location redirect)
   - A13 (scan-redirect side kept)
   - `TryLocationRedirect` once per bar
   - A11b (the retry delay)
