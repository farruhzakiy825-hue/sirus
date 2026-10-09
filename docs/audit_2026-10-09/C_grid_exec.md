# Auditor C - Basket / Grid / Recovery / Exits / Risk / Order execution

Scope: 06_Basket_Session, 10_Basket_Stats_Context, 12_Exits_Trailing, 13_Grid_Engine, 24_Position_Brain,
risk parts of 14_Risk_Gates_Entry, every CTrade call in the EA. READ-ONLY audit, no compiler/tester available.
All statuses follow BRIEF.md vocabulary. "Default" = value in the shipped `input` declaration (owner's live .set
file not available - cashback mode assumed ON for the live account because the shadow CSV shows TP = 224 pts =
240*0.60+80, i.e. `RebateTargetPoints()`).

---------------------------------------------------------------------------------------------------
## 0. Event wiring (where everything runs)

| Event | What runs | File:line |
|---|---|---|
| OnTick | `CoreUpdate("TICK")` - full pipeline | Sirus_Brain_V8.mq5:1398, 16_Dashboard_Core.mqh:841 |
| OnTimer (1 s) | `CoreUpdate("TIMER")` = `EmergencyBasketForceCloseCheck()` + clock/calendar + `CheckNewsAutoFlat()` then return | 16_Dashboard_Core.mqh:847-862 |
| OnTradeTransaction / OnTrade | **not implemented** - all fills/closes are detected by polling `PositionsTotal()` | grep: no handler |

CoreUpdate("TICK") order (16_Dashboard_Core.mqh:847-993):
1. `EmergencyBasketForceCloseCheck()` (12:822) - may close
2. Market-brain updates incl. **`MBPositionBrainUpdate()`** (24:654) - basket thesis, Recovery Judge, **MBPBCloseBookkeeping**
3. `CheckNewsAutoFlat()` (12:1236) - may close
4. scan block if `ScanDue()`: `UpdateOpportunityScanner` -> **`ResetOpportunity()` zeroes the basket globals** (see F-C1), score, redirect, legacy/deep packs
5. `UpdateRiskEngine()` (14:509) - refreshes basket stats, may close (`RiskCloseBasketIfNeeded`)
6. `UpdateLegacyPack3()` (09:2348) - news-guard close / disaster SL / weekend flat / **rebate time flat** (may close)
7. `UpdateLegacyPack2()` (09:2974) - Pack2 BE lock / trailing (may close)
8. `UpdateProfitExtractionSmartExit()` (15:4082) - DXB (auto-close off by default)
9. `UpdateGridRecoveryEngine()` (13:2584) - scale-in completion send, remnant-retry close, **`CheckBasketExit()`** (all basket TP/SL/smart exits), **grid add send**
10. `UpdateLegacyPack2("POST_GRID")`, `UpdateFirstEntryEngine()` (14:4871) - **first entry send**
11. post: `UpdateLegacyPack3("POST_ENTRY")` (can close again), dashboards

---------------------------------------------------------------------------------------------------
## 1. Module inventory

| Module | Purpose | Main functions (callers / event) | Inputs | Outputs |
|---|---|---|---|---|
| 06_Basket_Session | Scale-in split/complete, basket age learning, regime/session/streak/loss-level helpers, setup-arm judge | `ScaleInArm` (14 first entry, tick), `ScaleInDueLot` (13 `UpdateGridRecoveryEngine`, tick), `ScaleInReset` (8 sites), `RegimeUpdate` (CoreUpdate), `RegimeGridFactor` (13 GridCanOpen), `StreakRecordOutcome`/`RecordLossLevel` (12 CloseSirusBasket only), `ExitQualityArm/Settle`, `SlippageRecord` (14), `SessionContext`, `ProjectBasketRisk` | positions, ATR, score, regime | G_SCALEIN_*, G_REGIME, G_LOSS_STREAK, loss levels |
| 10_Basket_Stats_Context | **Basket accounting** + lots of context helpers | `GetSirusBasketStats` (7 callers: grid, exits, news flat, scale-in, rescue), `SelectedPositionNetProfit`/`PositionCommissionCached`, `BasketDDPercentApprox` (balance-based), `AccountDDPercentApprox`, `CurrentBasketPoints`, `SafePartialVolume`, `LadderIsAffordable`/`AffordableRungCount` (14 entry), `SetBasketThesis`/`BasketPremiseDead` (14, 13), `Pack4MiniAdjustLot` (13 NextGridLot), `OppTypeRecord` (12 close only), `NewsInProgress`, `ZonePriceInsideBand` (13) | live positions (symbol+magic), deal history (commission) | orders, volume, avg, net profit, direction (-1 none, -2 mixed), last price/lot |
| 12_Exits_Trailing | Every exit + trade close execution + grid distance profile + learning stores | `CloseSirusBasket` (23 call sites, see section 3), `BasketPartialClose`, `CheckBasketExit` (13 UpdateGridRecoveryEngine, tick), `EmergencyBasketForceCloseCheck` (CoreUpdate, tick+timer), `CheckNewsAutoFlat` (tick+timer), `RebateTrailManage`, `BrokerTrailSync` (PositionModify SL), `GridSafetyDangerNow` (13), `AutoGrid*Distance` (13), `MarginLevelAllowsGrid/LotAdjust` (13) | basket stats, inputs, ATR | closes, broker SL, G_BASKET_CLOSE_PENDING, G_BASKET_CLOSED_TICK, learning records |
| 13_Grid_Engine | Grid add decision + send, basket stats refresh, rescue guarantee | `UpdateGridRecoveryEngine` (CoreUpdate tick, not INIT/TIMER), `GridCanOpen` (~45 gates), `GridRescueState`/`GridSoftHold`, `GridDistanceForNextOrder`, `NextGridLot`, `IsGridAdverseMove`, `BasketExposureAllowsGrid`, `GridIntelligence*`, `RefreshGridDashboardStats` (10 callers), `TradeRetcodeFilled`, `AccountModeAllowsTrading` | basket stats, all gate flags | G_NEXT_GRID_*, G_BASKET_* (refresh), grid order |
| 24_Position_Brain | Basket thesis (DEAD/RESCUE), Recovery Judge (POSSIBLE/DOUBTFUL/IMPOSSIBLE), smart exits, smart runner, smart-grid confirmation | `MBPositionBrainUpdate` (CoreUpdate tick), `MBRecoveryEvaluate` (once/M1), `MBRecoveryExit` / `MBBasketBreakEvenExit` / `MBLocalBasketExit` / `MBRunnerManage` (12 CheckBasketExit), `MBGridAllows` (13 GridCanOpen), `MBGridPauseConfirm`/`MBAdverseSlowing` (13 GridRescueState), `MBPBCloseBookkeeping` (only from MBPositionBrainUpdate), `MBRecoverySave/Restore` (GlobalVariables) | market-brain globals, basket stats | G_MB_PB_*, G_MB_RC_*, close reasons |
| 14 (risk part) | Account-level risk, margin guard, first-entry send | `UpdateRiskEngine` (CoreUpdate), `RiskHardBlockCheck` (loss tiers then tradability gates), `RiskAllowsGrid/NewEntry`, `MarginAllowsOrder`, `MarginRescueGridLot`, `BuildEntryPrices`, `CheckStopFreezeDistance`, `UpdateFirstEntryEngine` (send at 14:5144) | equity/balance, spread, cooldown, attempt counters | G_RISK_HARD_BLOCK, G_RISK_CLOSE_REQUEST, first entry |

Functions with zero call sites (script `fn_refs.py`, comments stripped): `ZoneReactionPrice` (06:2190), `ZoneRiskPrice` (06:2200), `RegimeWinRate` (12:441), `LGLiveLevel` (14:1629), `LGSwingLevel` (14:1665). `G_TRAIL_PEAK_POINTS` is restored in OnInit (mq5:749) and reset in 12:1474 but never written or read for any decision (dead state).

### All trade-server calls in the EA
| Call | File:line | Function | Result check |
|---|---|---|---|
| `G_TRADE.Buy/Sell` (first entry, SL/TP attached) | 14:5144/5146 | UpdateFirstEntryEngine | `sent && TradeRetcodeFilled(rc)`; partial fill folded into scale-in |
| `G_TRADE.Buy/Sell` (scale-in completion, sl=0 tp=0) | 13:2624/2626 | UpdateGridRecoveryEngine | `TradeRetcodeFilled` |
| `G_TRADE.Buy/Sell` (grid add, sl=0 tp=0) | 13:2767/2769 | UpdateGridRecoveryEngine | `TradeRetcodeFilled`; failure -> retry engine |
| `PositionClose` (basket close, 3 passes, 300 ms gap, deviation 3000) | 12:1086 | CloseSirusBasket | DONE/PLACED, POSITION_CLOSED, retryable list |
| `PositionClosePartial` | 12:974 | BasketPartialClose | DONE/PLACED |
| `PositionModify` (broker trailing SL) | 12:1438 | BrokerTrailSync | DONE/NO_CHANGES, retried next tick |
| `PositionModify` (clear TP for runner) | 24:517 | MBRunnerClearBrokerTP | **ignored** (F-C14) |

No raw `OrderSend`, `OrderSendAsync`, `MqlTradeRequest` or `OrderCheck` anywhere. Magic+symbol filtering is applied in every position loop (`GetSirusBasketStats`, `CountSirusPositions`, `CloseSirusBasket`, `BrokerTrailSync`, `MBBasketOpenTime/DirReal`, emergency close, exposure cap, partial close) - STATICALLY PRESENT, consistent.

---------------------------------------------------------------------------------------------------
## 2. Grid chain (tick only; `UpdateGridRecoveryEngine` 13:2584)

1. Scale-in completion (13:2589-2645): `ScaleInDueLot()` -> `AllowLiveTrading && G_ENV_READY && !G_RISK_HARD_BLOCK && !G_RISK_CLOSE_REQUEST` -> `MarginAllowsOrder` -> `Buy/Sell(lot, 0 SL, 0 TP)`. No spread/news/velocity gate.
2. `RefreshGridDashboardStats()` - rebuilds G_BASKET_* from live positions.
3. Remnant retry: `G_BASKET_CLOSE_PENDING && orders>0` -> `CloseSirusBasket("remnant retry...")` every >=5 s.
4. `CheckBasketExit()` - if it returns true (any close attempted) the grid is skipped this tick.
5. `GridCanOpen()` (13:1750), in order (H = hard, S = soft = can be stepped over by the rescue guarantee via `GridSoftHold`):
   H `G_BASKET_CLOSE_PENDING`; H `UseGridRecovery`; H `AllowLiveTrading`; H `G_ENV_READY`; H operator control;
   H `EnableGridTrailSafetyCheck && G_BASKET_TRAIL_ACTIVE`; -> `GridRescueState()`;
   H daily-profit governor; H license; H setup doctor; H retry engine; H `RiskAllowsGrid` (= !G_RISK_HARD_BLOCK: emergency/equity/daily-loss tiers **and** ENV, spread>=500, post-loss cooldown, MaxDailyEntryAttempts, MaxDailyGridAttempts);
   S legacy, S Pack2, S Pack3 (manual news windows), S P4M, S P4L, S RCB, S DCS, S DLP, S DBOS, S DTZ; H DNV (`G_DNV_GRID_BLOCK`); S DET; S DRI; H weekend; H account HEDGING; H velocity spike (`G_VEL_GRID_UNTIL`); S DRT;
   basket: H mixed (-2); H `orders >= MaxOrders`; H `orders+1 < GridStartOrder(2)`; H micro guard (`AllowGridAfterMicro`, broken - F-C5);
   S `GridCooldownBars(2)`; H `GridMinSecondsBetweenOrders(120)`; S fresh impulse; S impulse cooldown;
   S **`GridSafetyDangerNow` (DD, health, news, shock, chaos, trend-against, zone, spread)** - trend-against may be overridden once by SZR;
   distance = `GridDistanceForNextOrder` x ladder spacing x situation x regime x zone-aware x (0.6 if `GridReactionAtWall`) then clamped to [AutoGridMin, AutoGridMax]; `IsGridAdverseMove` (bid <= last - dist for BUY / ask >= last + dist for SELL) - **mandatory** when `GridRequireAdverseMove=true`;
   H depth limit (`GridEffectiveMaxOrders`, budget = BasketSLPercent x share); S scenario projection; H news owner (calendar window or live news read); S basket thesis dead; S staleness;
   `G_NEXT_GRID_LOT = NextGridLot(...)` (multiplier 1.30 via `LadderMultiplier`, soft cautions, floors: never below previous lot, absolute floor from StartLot x 1.3^n; hard limits last: P4M cap, client safety, preset, margin level, MaxLot);
   H "waiting distance"; H caution hold (lot floored -> wait up to 10 bars / extra distance, bypassed by rescue);
   **H `MBGridAllows`** (24:869): dead thesis H, IMPOSSIBLE armed H, then if `G_GRID_RESCUE_ON` -> allow; else threatened thesis, local basket rung cap, DOUBTFUL+, against-move checks (displacement / M5 reversal / genuine break / M5+M15 pressure), response (candle trigger / fresh event) **at structure**, reserve rungs need structure+spent move+response, grid liability vs HTF liquidity, otherwise wait up to `MBGridResponseMaxBars(15)` M1 bars then require `MBGridPauseConfirm` (no live displacement against, last M1 bar made no new extreme);
   SZR consumes its one-shot here (F-C8); H zone-band wait (10 bars, bypassed by rescue or deep DD); H exposure cap 60% of equity (margin rescue: largest 10%-step lot >= `GridMarginRescueMinFactor`); S Grid Intelligence; H broker margin level.
6. Rescue guarantee (`GridRescueState` 13:1695): adverse steps = (last_price - px)/step. >= 1.5 steps and `MBAdverseSlowing` (exhaustion>=30, OR a candle the basket's way, OR M1 and M5 pressure **not against** (neutral counts), OR adverse impulse late) -> soft holds skipped; >= 2.5 steps and (slowing OR pause) -> same. Hard holds never skipped (F-C3 shows GridSafetyDangerNow's news/shock/chaos are wrapped as soft).
7. Send (13:2717-2770): `MarginAllowsOrder` (free margin, projected level >= 200%) else margin-rescue lot; `Buy/Sell(G_NEXT_GRID_LOT, 0, sl=0, tp=0, "GRID n")`; success = `TradeRetcodeFilled` (DONE, DONE_PARTIAL, PLACED). On success: adverse streak, `G_LAST_GRID_TIME/BAR`, counters. On failure: `G_GRID_FAILS++`, retry engine (transient: REQUOTE/REJECT/PRICE_CHANGED/TIMEOUT/CONNECTION/PRICE_OFF -> delay, 3 attempts then give-up cooldown; non-transient -> 20 s). No in-tick retry, no partial-fill top-up.

Direction lock: grid side = `G_BASKET_DIRECTION` (live positions), mixed basket refused - STATICALLY PRESENT.
Max orders: `MaxOrders=5` raw position count + `GridEffectiveMaxOrders` (ladder shape, affordability cap, depth budget) - STATICALLY PRESENT.
Lot multiplier: 1.30 with floors - STATICALLY PRESENT.
Runtime: shadow CSV (older code) shows TAKEN baskets with tp distance 224 pts (129/132) and grid step 5500 pts (127/132); 14/132 TAKEN rows hit the grid step (outcome GRID) within 0-21 min - RUNTIME VERIFIED only that the grid step distance is the 5500 clamp, not that adds were sent.

---------------------------------------------------------------------------------------------------
## 3. Owner rules

### 3.1 Basket SL 50% - how it is computed and enforced
* `CheckBasketExit` 12:1570: `if(UseBasketSL && BasketSLPercent > 0.0) { double dd = BasketDDPercentApprox(profit); if(dd >= BasketSLPercent) CloseSirusBasket(...) }`
* `BasketDDPercentApprox` 10:300: `MathAbs(basket_profit) / ACCOUNT_BALANCE * 100` where `profit` = sum of `POSITION_PROFIT + SWAP + cached commission` for symbol+magic (10:191-247). Defaults `UseBasketSL=true`, `BasketSLPercent=50`.
* **EA-side only.** No broker SL is ever put on a losing basket: first entry `UseFirstEntrySL=false`, grid/scale-in orders are sent with `sl=0`, `BrokerTrailSync` only writes an SL when a trailing lock is armed in profit (`if(lock_pts <= 0.0) return; // only a basket in locked profit gets a broker stop`, 12:1383). **If the EA/terminal/VPS is offline nothing enforces 50%** - only the broker's margin stop-out. Same for the duplicates: `EmergencyBasketForceCloseCheck` (52%, balance-based, tick+timer), risk-engine `EmergencyDDPercent=50` / `EquityStopPercent=50` (account equity DD, all symbols).
* Only evaluated on ticks (`CheckBasketExit` is not reached from OnTimer); the 52% emergency net also runs on the timer.
* Status: STATICALLY PRESENT; NOT YET VERIFIED at runtime.

### 3.2 Every path that can close a basket at a loss (all go through `CloseSirusBasket`, 12:1005)
| # | Path | File:line | Default | Can realise a loss? |
|---|---|---|---|---|
| 1 | Basket SL % (50) | 12:1570-1577 | ON | yes (hard stop, owner rule) |
| 2 | Emergency force close (independent, 52%) | 12:885-891 | ON | yes (2nd hard stop, also on OnTimer) |
| 3 | Risk engine emergency DD (equity DD >= 50%, **account-wide**) | 14:430-436 -> 14:530 `RiskCloseBasketIfNeeded` | ON | yes - can fire below this basket's own 50% if other symbols/EAs lose |
| 4 | Risk engine equity stop 50% + `CloseBasketOnEquityStop=true` | 14:443-448 | ON (shadowed by #3) | yes |
| 5 | Risk engine daily loss (`CloseBasketOnDailyLoss=false`) | 14:450-472 | OFF | yes if enabled |
| 6 | **Smart exit IMPOSSIBLE** (`MBRecoveryExit`: bounce of 0.3 ATR(M1) after arm, or DD +3% after arm) | 24:396-421 -> 12:1531-1535 | ON | yes (owner rule) |
| 7 | Remnant retry of an incomplete close | 13:2655-2664 | always | yes - finishes any earlier close at the current price |
| 8 | Basket SL money | 12:1517-1521 | OFF | yes |
| 9 | Smart Early Exit | 12:1583-1591 | OFF | yes |
| 10 | Pack3 news-guard close (`NewsGuardCloseBasket=false`) | 09:2119-2123 | OFF | yes |
| 11 | Pack3 server disaster SL (`UseServerDisasterSL=false`, 35%) | 09:2307-2315 | OFF | yes |
| 12 | Weekend Friday flat (`WeekendCloseBasketFri=false`) | 11:1439-1450 | OFF | yes |
| 13 | P4M license/symbol invalid (`P4MiniCloseBasketInvalid=false`) | 15:984-985 | OFF | yes |
| 14 | Deep Smart Exit (`DeepExitEnableAutoClose=false`) | 15:4189-4192 | OFF | money-profit gated |
| 15 | News auto-flat before calendar event (`NewsAutoFlatOnlyIfProfit=true`) | 12:1270-1276 | ON | no (profit > 0), only if flag kept |
| 16 | Rebate time flat (25 bars, profit >= 0.0) | 11:1428-1435 | ON in cashback | near-zero: closes at net 0.00 at market -> slippage / missing commission (F-C13) can realise small loss |
| 17 | `MBBasketBreakEvenExit` (dead / doubtful / deep-back / stale / expectation fail) | 24:1059-1093 | ON | points >= 30 and money >= 0 - break-even, slippage only |
| 18 | `MBLocalBasketExit` | 24:428-448 | ON | profit >= 0 |
| 19 | Basket TP points / money, SZR escape | 12:1505-1565 | ON / OFF / OFF | points-based, not money-checked |
| 20 | Rebate trailing lock, Pack2 trailing / BE lock, runner lock | 12:1352, 09:2873/2958, 24:574 | rebate trail OFF, Pack2 ON (normal mode), runner ON (normal mode) | points-based lock > 0 |
| 21 | Partial closes stage 1/2 | 12:1595-1659 | OFF | realises losses on losing rungs (basket net > 0) |
| 22 | Broker-side trailing SL (`BrokerTrailSync`) | 12:1372 | ON | only when lock > avg (profit) |
| 23 | Broker margin stop-out | broker | - | yes, the only protection while the EA is offline |

Verdict on "loss close only via smart exit IMPOSSIBLE": with defaults, the hard-stop family (#1-#4, all at 50-52%), the IMPOSSIBLE exit (#6) and the remnant retry (#7) are the only intentional loss paths; #3 is account-wide and can pre-empt the basket's own 50% (CONFLICT, F-C11). Eight more loss paths are present and switched off by inputs only. Status: STATICALLY PRESENT, NOT YET VERIFIED.

### 3.3 Trailing only in normal mode
Pack2 trailing guarded `UseAdvancedBasketTrailing && !EnableRebateMode && !RebateTrailingOn()` (09:2920); runner guarded `EnableRebateMode` (24:481/525); rebate trailing needs `EnableRebateTrailingMode` (default false, 12:1309). STATICALLY PRESENT. Note: one input (`EnableRebateTrailingMode=true`) turns trailing on in cashback mode, and Pack2 trailing is broken when the lock is below the arm point (F-C9).

### 3.4 Cashback fixed TP
First entry broker TP = `RebateTargetPoints()` at entry (14:1208-1213, 1294). Basket exit target `BasketTPForOrderCount()` returns `BaseBasketTPPoints()` (rebate target) without depth cuts (11:1170-1171) - but it is **recomputed every tick from the live `SYMBOL_SPREAD`** (11:953) so the EA-side target floats with spread (cap at spread 350); grid rungs carry no broker TP. Dead-premise path can cut it to max(1.5 x spread, DeadPremiseExitPoints). PARTIALLY as stated - F-C12.

### 3.5 No hedge
`OneBasketAtATime=true` + `HasOpenSirusPosition()` live count (14:4566); grid side = basket side; mixed basket refused (13:1933); scale-in abandoned if live basket side != armed side (06:557-564). No code path opens the opposite side while a basket of this magic+symbol is open, as long as `OneBasketAtATime` stays true. STATICALLY PRESENT. (Grid/deep "grid block" flags DLP/DBOS/DTZ are computed against the scanner's new-opportunity direction, not the basket's - F-C15, off by default.)

---------------------------------------------------------------------------------------------------
## 4. Execution
* Filling: `SetTypeFillingBySymbol(_Symbol)` before every send (OnInit + each call site). Deviation: entries/grid `OrderSendDeviationPoints=50`, closes `max(50, CloseDeviationPoints=3000)` and restored after. (Guess: on Exness market execution the deviation is ignored by the server, so REQUOTE is rare.)
* Retcodes: sends accept DONE / DONE_PARTIAL / PLACED as filled (13:1632). Close treats DONE/PLACED as closed, POSITION_CLOSED as gone, retries REQUOTE, PRICE_CHANGED, PRICE_OFF, REJECT, TIMEOUT, CONNECTION, TOO_MANY_REQUESTS, ERROR, LOCKED, DONE_PARTIAL, INVALID_FILL up to 3 passes 300 ms apart; anything else (MARKET_CLOSED, NO_MONEY, INVALID_STOPS, FROZEN, TRADE_DISABLED) = fatal -> latch `G_BASKET_CLOSE_PENDING` -> remnant retry every 5 s on ticks. STATICALLY PRESENT.
* Invalid stops: `CheckStopFreezeDistance` widens TP/SL to max(stops, freeze)+5 pts on the correct side (14:1396). Broker trail SL keeps max(stops, freeze)+2 pts from bid/ask and never below avg (12:1408-1419). **No code path can put a TP/SL on the wrong side** (checked BuildEntryPrices, ZoneMap cap floor, CheckStopFreezeDistance, BrokerTrailSync, MBRunnerClearBrokerTP).
* Partial fills: first entry - shortfall folded into scale-in (14:5160-5170); grid - not topped up, ladder continues from the real last lot (P4).
* Failure midway through a ladder: grid state (`G_LAST_GRID_*`, streak, counters) written only after `TradeRetcodeFilled`; exceptions: SZR one-shot (F-C8) and the MB response wait reset (F-C10).
* Restart: basket rebuilt from live positions every tick (`GetSirusBasketStats`), Recovery Judge / dead thesis restored from GlobalVariables keyed on the oldest position's open time (24:116-132). Not restored: `G_LAST_GRID_TIME/BAR` (OnInit 0/-100000 -> both grid cooldowns skipped right after a restart), `G_SCALEIN_EXTRA_ORDERS` (scale-in counted as a grid rung -> distance/lot one step deeper), `G_AFFORD_RUNG_CAP` (affordability rung cap lost), `G_BASKET_CLOSE_PENDING` (an unfinished close's remnant is treated as a fresh basket), trailing/runner state (broker SL survives), `G_BASKET_OPEN_BAR` vs reset `G_BARS_SEEN`. All P3, F-C16.

---------------------------------------------------------------------------------------------------
## 5. Findings

### F-C1 - SIGNAL/DATA LOST - P3 - basket state wiped by every scan
* File: 05_Situation_Candles.mqh:3502-3518 (`ResetOpportunity`), same block in 08_Scanner_Score.mqh:341 (`ResetScoreEngine`), 09:63 (`ResetRedirect`)
* Code: `G_GRID_ATTEMPTS = 0; ... G_BASKET_ORDERS = 0; ... G_BASKET_DIRECTION = -1; G_BASKET_LAST_GRID_PRICE = 0.0; G_BASKET_ADVERSE_STREAK = 0; G_BASKET_DD_HISTORY_COUNT = 0; G_BASKET_DD_HISTORY_BAR = -1; G_SEE_PERSIST_BARS = 0; ... G_LAST_DD_WARNING_LEVEL = 0.0; G_NEXT_GRID_LOT = 0.0; ... G_RISK_HARD_BLOCK = false;`
* Cause: `UpdateOpportunityScanner` calls `ResetOpportunity("no candidate yet")` on every scan (08:51); with `ScanMaxSeconds=3` that is at least every 3 s and every new M1 bar. `RefreshGridDashboardStats` restores only orders/volume/avg/profit/direction/points/DD - not the history-type fields.
* Effects (each verified in code):
  - `G_BASKET_LAST_GRID_PRICE` is 0 at the next grid send, so `if(G_BASKET_LAST_GRID_PRICE > 0.0 && streak_price > 0.0)` (13:2786) is false -> `G_BASKET_ADVERSE_STREAK` never increments -> `EnableBasketAdverseStreakCheck` (13:1079) can never fire. FAILED.
  - `RecordBasketDDHistory` (04:365) gets one sample per bar, then the count is zeroed -> `BasketDDAccelerationFactor` needs `count >= 2*w` (04:392) -> always returns 0. FAILED.
  - `G_SEE_PERSIST_BARS` zeroed -> Smart Early Exit persistence cannot build (feature off by default).
  - `G_LAST_DD_WARNING_LEVEL` zeroed -> `EmergencyBasketForceCloseCheck` re-sends the "DD WARNING" push after every scan once DD >= 25% (push off by default: `EnablePushNotifications=false`).
  - `G_GRID_ATTEMPTS` zeroed -> `MaxDailyGridAttempts=200` (14:500) can never trigger.
  - Inside the scan block itself every legacy/deep module sees `G_BASKET_ORDERS=0`, `G_BASKET_DIRECTION=-1`.
* Reproduce: open a basket, let it go into DD > 25% for > 3 bars; `G_BASKET_ADVERSE_STREAK` stays 0, no "DD accelerating" detail ever printed.

### F-C2 - SIGNAL/DATA LOST - P2 - learning records only see EA-closed baskets
* File: 12_Exits_Trailing.mqh:1144-1210 (`CloseSirusBasket`)
* Code: `if(all_ok && closed > 0 && EnableConfidenceScore) { BayesRecordOutcome(...); ScoreBandRecordOutcome(...); WarningRecordOutcome(...); RegimeRecordOutcome(...); ... StreakRecordOutcome(pre_close_profit > 0.0); EVRecord(pre_close_profit); OppTypeRecord(...); ... AdaptRecord(pre_close_profit > 0.0); ... RecordLossLevel(...) }`
* Cause: the universal close hook `MBPBCloseBookkeeping` (24:633) records memory/autopsy/re-entry/evidence gates/win direction for every ending, but Bayes, score bands, warnings, regime, streak, EV, setup-type, evidence-tighten (`AdaptRecord`) are written only when the EA itself closes. In cashback mode the first entry carries a broker TP equal to the basket target (14:1208, 1294), so a winning 1-order basket is normally closed by the broker (the EA's `Basket TP points` check races the server-side TP - guess: broker usually wins). Losing baskets (SL 50%, IMPOSSIBLE) are always EA-closed.
* Effect: win rates/EV/streaks biased toward losses: `G_LOSS_STREAK` is never reset by broker-TP wins (`StreakPenalty` grows), `AdaptRecord` win rate drops -> evidence tightening blocks more entries, Bayes can disable detectors (`BayesDetectorDisabled`), score-band calibration shrinks the first part. Fewer entries / smaller lots without a real reason.
* Reproduce: log `[SIRUS v166 STREAK] N consecutive losses` while the deal history shows TP wins in between; compare `G_EV_WINS` with the number of TP deals.

### F-C3 - CONFLICT - P2 - rescue guarantee steps over shock / chaos / news-active / DD dangers
* File: 13_Grid_Engine.mqh:1990-2017 (`GridCanOpen`), 12:1775-1831 (`GridSafetyDangerNow`)
* Code: comment 13:1993 "Every other danger (DD too high, low health, news, shock, chaos) stays absolute"; actual: `if(is_trend_block && SmartZoneRecoveryAllows(...)) {...} else if(GridSoftHold(reason, auto_grid_safety_reason + ...)) return false;`
* Cause: every `GridSafetyDangerNow` reason, not just trend-against, is routed through `GridSoftHold`, which returns false (not held) when `G_GRID_RESCUE_ON`. The rescue header (13:1686) lists "a velocity spike, scheduled news" as HARD. Shock (`G_DNV_SHOCK_ACTIVE`, `G_DNV_SPREAD_SHOCK`, `G_DET_POST_SHOCK`, `G_DRT_SHOCK_MODE`) and chaos have no other hard gate (`G_DNV_GRID_BLOCK` is set only for news with `DeepNewsStrictGridBlock`, default false, 15:3360-3367; DET/DRT gates are soft).
* Effect: when price is >= 1.5 grid steps away and "slowing" (which includes neutral M1/M5 pressure - 24:864), a rung is added during a detected shock/post-shock or chaos market. Velocity spike (hard, 13:1906) and calendar/live news owner (hard, 13:2152) still apply - guess: they overlap with many shocks but not post-shock cooldown.
* Reproduce: log `[SIRUS GRID RESCUE] ... stepped over: auto grid safety: shock/post-shock risk` (or `chaos market`).

### F-C4 - CONFLICT - P2 - scale-in remainder can become an orphan "basket" in cashback mode
* File: 06_Basket_Session.mqh:527-640 (`ScaleInDueLot`), 13:2589-2645 (send with `0.0, 0.0` SL/TP), 14:1076-1097 (split)
* Code: `si_sent = G_TRADE.Buy(NormalizeVolumeSafe(si_lot), _Symbol, 0.0, 0.0, 0.0, si_comment);`; confirm distance `MathMax(base * 0.4, MathMin(base * 2.5, atr*0.8))` = 320..2000 pts measured on mid vs the entry ask.
* Cause: `EnableScaleIn=true` is not disabled in cashback mode. First part has a broker TP at entry+224; completion has none. With ATR(M1) < ~430 pts the completion confirms at mid >= entry_ask+320 (bid ~= entry+200, 24 pts before the first part's TP). The broker then closes the first part at TP; the completion (opened ~200-300 pts higher, no TP) remains. `MBPositionBrainUpdate` sees a new oldest-position time and books the old basket as closed (24:706); the remnant is now a 1-order basket that passed no entry gate, blocks new entries (`OneBasketAtATime`) and can receive grid rungs (orders+1=2 >= GridStartOrder).
* Effect: chased, ungated position at a worse price; grid ladder can be built on it. When ATR is higher the completion never fires and every basket runs at 80-95% of the intended lot (cashback volume lost).
* Reproduce (quiet Asian session): `[SIRUS v161 SCALE-IN] completed with ...` followed within seconds by a TP deal on the first ticket and a position with comment "SCALE-IN" left open. Guess on frequency; NOT YET VERIFIED.

### F-C5 - CONDITION WRONG - P3 - "no grid after micro" guard never active
* File: 13_Grid_Engine.mqh:1947-1957; resets at 05:3431, 08:270; overwritten at 14:4953
* Code: `if(StringFind(G_ENTRY_DETAIL, "MICRO") >= 0 && orders == 1) { reason = "grid after micro disabled"; return false; }`
* Cause: `G_ENTRY_DETAIL` contains the comment ("...| MICRO") only in the tick of the entry; the next scan sets `"ENTRY DETAIL: initializing"` and the blocked entry engine writes `"ENTRY DETAIL: attempts=..."` every tick. A rung needs >= 5500 pts of adverse move, i.e. many ticks later.
* Effect: with `AllowGridAfterMicro=false` (default) micro-scalp baskets still get the full martingale ladder. FAILED.
* Reproduce: a basket whose first comment is "... | MICRO" receives a "GRID 2" order.

### F-C6 - WRONGLY BLOCKS - P2 - entry/attempt and spread "tradability" blocks also freeze grid recovery
* File: 14_Risk_Gates_Entry.mqh:476-505 (`RiskHardBlockCheck`), 14:594 (`RiskAllowsGrid`), 13:1834
* Code: `if(MaxDailyEntryAttempts > 0 && G_ENTRY_ATTEMPTS >= MaxDailyEntryAttempts) { reason = ...; return true; }` -> `G_RISK_HARD_BLOCK` -> `RiskAllowsGrid` false (hard, not soft).
* Cause: gates meant to stop NEW trading (comment 14:474 "these stop new trading") set the same flag that blocks grid additions (`RiskBlockGrid=true`). `MaxDailyEntryAttempts=600` counts every send attempt incl. failures; owner target 250-450 trades/day.
* Effect: on a busy/requote-heavy day, after 600 attempts every open basket loses its grid until the day rolls over (owner rule "grid must not freeze"); spread >= 500 pts and post-loss cooldown do the same while they last.
* Reproduce: log `RISK BLOCK: max daily entry attempts 600/600` together with `GRID: WAIT | reason=RISK BLOCK...`.

### F-C7 - SIGNAL/DATA LOST - P3 - dead/IMPOSSIBLE judgement lost when the oldest rung closes alone
* File: 24_Position_Brain.mqh:704-726 (`MBPositionBrainUpdate`)
* Code: `if(opened != G_MB_PB_BASKET || dir != G_MB_PB_DIR) { if(G_MB_PB_BASKET != 0 && opened != G_MB_PB_BASKET) MBPBCloseBookkeeping(); ... G_MB_PB_DEAD = false; ... MBRecoveryReset(); ... MBRecoveryRestore(opened); }`
* Cause: the basket identity is the oldest position's open time. If rung 1 closes alone (its own broker TP while the EA was offline, a manual close, partial-close stage) the remaining rungs get a fresh identity: bookkeeping records a "closed" basket (usually a win), recovery GVs are deleted (`MBRecoveryForget`), and dead-thesis / IMPOSSIBLE-armed / peak-DD are reset.
* Effect: a deep remnant that was judged dead or IMPOSSIBLE is treated as a new healthy basket - grid additions re-allowed (the two "owner hard rules" in `MBGridAllows` lifted), smart exit disarmed.
* Reproduce: close the first ticket by hand on a 3-rung basket with `[SIRUS POSITION] ... thesis DEAD`; next tick shows no DEAD and a GRID add is possible.

### F-C8 - RESULT IGNORED - P3 - SZR one-shot consumed before the order is confirmed
* File: 13_Grid_Engine.mqh:2271-2305
* Code: comment "the one-shot is consumed only HERE - when every other condition ... also passed"; then `G_SZR_USES_THIS_EPISODE++; G_SZR_ESCAPE_MODE = true; GlobalVariableSet(...SZRUSED...)` - followed by exposure cap (2371), zone wait (2333), margin level (2419), `MarginAllowsOrder` (2717) and the send itself.
* Effect: if any later gate or the send fails, the trend-block episode's only SZR permission is spent and escape mode is latched without a rung; the next attempt is held by the trend block (soft, rescue may still pass).
* Reproduce: `[SIRUS v31.6 SMART ZONE RECOVERY] trend-block overridden once` followed by `GRID FROZEN at exposure gate` or `GRID FAILED`.

### F-C9 - EXECUTION FAILS - P3 (normal mode) - Pack2 trailing close never checked below the arm point
* File: 09_Redirect_Queue_Pack2.mqh:2920-2968 (`Pack2CheckBasketBreakEvenOrTrail`)
* Code: `if(UseAdvancedBasketTrailing && !EnableRebateMode && ... && G_BASKET_POINTS >= effective_trail_start) { ... if(G_BASKET_POINTS <= G_BASKET_TRAIL_LOCK) closed = CloseSirusBasket(...) }`
* Cause: the lock is set to `points - step` (<= start - step on arming), i.e. below the arm point, but the close check sits inside the `>= effective_trail_start` block. A pull-back from just above the arm point goes below the start and the EA-side lock never fires. `G_BASKET_TRAIL_ACTIVE` stays true until the basket is flat, so `GridCanOpen` keeps refusing rungs (`EnableGridTrailSafetyCheck`, hard, 13:1793).
* Effect: in normal mode the exit relies entirely on the broker SL from `BrokerTrailSync`; if that modify failed (freeze/stops level, throttle) the basket can fall back into loss with its grid frozen.
* Reproduce: normal mode, basket peaks at arm+100 pts and falls back - no "Pack2 Basket trailing lock" close; `GRID: WAIT | reason=basket already in profit-trailing mode` persists.

### F-C10 - SIGNAL/DATA LOST - P3 - MB response wait restarts after a failed grid send
* File: 24_Position_Brain.mqh:1015-1054 (`MBGridAllows`), 13:2717-2770
* Code: `G_MB_PB_WAIT_ORDERS = -1; return true;` (allow) - next tick after a failed send: `if(G_MB_PB_WAIT_ORDERS != orders) { G_MB_PB_WAIT_ORDERS = orders; G_MB_PB_WAIT_SINCE = TimeCurrent(); }`
* Effect: a rung that waited 15 M1 bars and then failed (requote, margin) has to wait up to 15 more bars unless a response/rescue appears.

### F-C11 - CONFLICT - P2 - account-wide DD can close this basket below its 50% SL
* File: 14:430-436 (`RiskHardBlockCheck`), 10:262-280 (`AccountDDPercentApprox`)
* Code: `if(UseEmergencyClose && EmergencyDDPercent > 0.0 && G_RISK_EQUITY_DD_PCT >= EmergencyDDPercent) { ...; close_request = true; ...}` with `dd = (balance - equity) / balance * 100`.
* Effect: if other symbols/EAs share the account, their floating loss counts; this basket is force-closed at a loss through a path other than its own 50% SL or IMPOSSIBLE (the code comment at 14:422 says this is intentional - flag for the owner).

### F-C12 - CONFLICT - P3 - cashback basket target is not fixed
* File: 11_Expectancy_MTF_News.mqh:941-975, 1170-1171; 12:1561
* Code: `double target = spread_pts * RebateSpreadMultiple + (double)RebateTPMarginPoints;` (live `SYMBOL_SPREAD`), used every tick by `BasketTPForOrderCount`.
* Effect: EA-side target moves with spread (e.g. spread 150 -> 170 pts, spread 350 -> 290 pts) while the first order's broker TP stays at the entry value; multi-rung baskets have no broker TP at all, so with the EA offline they never take profit.

### F-C13 - INSUFFICIENT EVIDENCE - P3 - "break-even" closes can realise small losses
* File: 11:1432 (`if(G_BASKET_PROFIT < RebateTimeFlatMinProfit) return;` with default 0.0), 10:150-188 (`PositionCommissionCached` returns 0 when history is not loaded: `return 0.0; // history not available yet`)
* Effect: rebate time-flat / BE exits close at net >= 0.00 measured before a market close with 3000-pt deviation; slippage or an uncounted commission can turn them into small losses (loss closes not via IMPOSSIBLE). Guess; check deal history for time-flat closes with negative profit.

### F-C14 - RESULT IGNORED - P4 - runner TP removal not checked
* File: 24_Position_Brain.mqh:517 - `G_TRADE.PositionModify(ticket, PositionGetDouble(POSITION_SL), 0.0);` result discarded; if it fails the broker TP closes the "runner" at the old target (not a loss).

### F-C15 - CONDITION WRONG - P4 (inputs off) - deep-pack grid blocks keyed to the scanner's opportunity, not the basket
* File: 15_Legacy_Packs.mqh:2443-2480 (DLP), 2780-2793 (DBOS), 3123-3133 (DTZ) - `int opp = DeepOpportunitySign();` (`G_OPP_DIR`) ... `if(DeepHTFBlockGridCounterTrend) G_DLP_GRID_BLOCK = true;`
* Effect if enabled: a BUY basket's grid is blocked because a new SELL setup is counter-HTF, and not blocked when it should be. Defaults all false.

### F-C16 - SIGNAL/DATA LOST - P3 - restart/reinit loses grid timing and basket bookkeeping
* File: Sirus_Brain_V8.mq5:237-238 (`G_LAST_GRID_TIME = 0; G_LAST_GRID_BAR = -100000;`), 13:1960-1970 (cooldowns skipped when `G_LAST_GRID_BAR <= -9999` / time 0), `G_SCALEIN_EXTRA_ORDERS`, `G_AFFORD_RUNG_CAP`, `G_BASKET_CLOSE_PENDING` not persisted.
* Effect: right after a restart a rung can be added immediately (cooldowns skipped), a scale-in completion is counted as a grid rung (next lot/distance one step too deep), the affordability rung cap is gone, and a failed-close remnant becomes a fresh basket.

### F-C17 - CONFLICT - P4 - cashback grid spacing multiple is dead code in practice
* File: 12:1693-1698 then 13:1281-1285 / 2077-2083 clamp
* Code: `return MathMax(1.0, rebate_tp * RebateGridSpacingMultiple);` (224 x 3 = 672 pts) then `dist = MathMax(dist, min_dist)` (5500/6000).
* Effect: spacing is always the min clamp. RUNTIME VERIFIED (shadow CSV, older code): grid_step 5500 in 127/132 TAKEN rows, 6000 in 5.

### F-C18 - NEVER CALLED - P4
`ZoneReactionPrice` (06:2190), `ZoneRiskPrice` (06:2200), `RegimeWinRate` (12:441), `LGLiveLevel` (14:1629), `LGSwingLevel` (14:1665); `G_TRAIL_PEAK_POINTS` restored/reset but never used for a decision.

### Checked and OK (STATICALLY PRESENT, NOT YET VERIFIED)
* Grid add only after the full adverse distance (`GridRequireAdverseMove=true`, DD trigger can only add strictness, 13:2102).
* Grid state updated only after a filled retcode (13:2775-2821); first-entry state likewise (14:5156-5300).
* `G_BASKET_CLOSED_TICK` set on every EA close with `closed > 0` (12:1137) and checked by the first-entry gate (14:4201); broker-side closes do not set it, but `MBPBCloseBookkeeping` and the post-loss cooldown run earlier in the same tick, so the A6 intent holds.
* `MBPBCloseBookkeeping` reached for every ending as long as `EnableMBPositionBrain && EnableMarketBrainEngines` (both default true); if either is switched off it never runs (24:656-664).
* Recovery Judge needs a key reading (dead thesis or confirmed reversal) at every depth (`need_key = true`, 24:364) and `neg > pos`.
* TP/SL never placed on the wrong side (section 4).
