# Auditor T - Strategy Tester compatibility (read-only)

Scope: why Sirus_Brain_V8 "does not work in the Strategy Tester": (A) fails to initialise, (B) initialises but
never trades, (C) runs extremely slowly. Static reading only: no compiler, no tester, no tester log here.
Nothing under /home/user/sirus was edited.

Line numbers are per-file (`Sirus/NN_*.mqh`, `Sirus_Brain_V8.mq5`) from the working tree on 2026-10-10.
NOTE: while this audit ran, another process was modifying 06, 09, 14, 15, 20, 23 and 25 (uncommitted diff of
about 100 lines). None of those edits touch the items below, but some line numbers in 14/15/20 may move by a
few lines, so every item also gives the function name.

Status words (from the brief): STATICALLY PRESENT / RUNTIME VERIFIED / FAILED / NOT YET VERIFIED. Nothing here
is RUNTIME VERIFIED: there is no tester evidence. "UNVERIFIED (platform)" means the result depends on an MT5
tester behaviour I could not confirm from the code. The Journal line that settles it is given each time.

Tester facts this report relies on (standard MT5 behaviour):
- `TimeLocal()`, `TimeGMT()` and `TimeTradeServer()` all return the SIMULATED time in the tester. `GetTickCount()`,
  `GetTickCount64()` and `GetMicrosecondCount()` return REAL wall-clock time.
- The Calendar* functions return nothing in the tester. `Sleep()` does not wait in the tester.
- `EventSetTimer` works in the tester, and OnTimer fires once per SIMULATED timer interval.
- In a non-visual test, chart objects are still created on a virtual chart (they cost time, nobody sees them).
- Every Print/PrintFormat line is written to the agent log (`Tester\Agent-...\logs`). This is synchronous disk I/O.
- When an EA reads another symbol, the tester must load and model that symbol as well (a multi-currency test).

---------------------------------------------------------------------------------------------------
## 0. Executive summary (most likely first)

1. **C1 - Journal flood (most likely cause of the extreme slowness).** About 35 "print when the signature
   changes" loggers, plus NEW BAR, VPS, NO-TRADE AUDIT, BROKER, ENTRY WAIT, CHAIN, LOG and PROF lines, all
   print in the tester. `VerboseLogs=true` by default and no logger checks MQL_TESTER. The ENV and MODE
   signatures include the live spread, so they print on every spread change, which with real ticks is nearly
   every tick.
2. **C2 - The whole CoreUpdate pipeline runs on every tick.** That is about 60 Update* calls, about 100
   status/detail strings, and RefreshGridDashboardStats from 21 call sites. The scanner "throttle" re-runs
   whenever price moves 0.10 x ATR(M1), which on gold is almost every tick. OnTimer adds one more pass per
   simulated second.
3. **C3 - Chart objects in a non-visual test.** `DrawBasketTPSLLines` is guarded only for optimization, the
   premium visual engine has no tester guard, and close markers are never deleted. The clutter control scans
   all chart objects at least 3 times every 30 simulated seconds. This is an O(N) cost where N grows all test
   long, so the test gets slower day by day.
4. **B1 - The Setup Doctor needs `TERMINAL_CONNECTED`** (14:297). If the tester reports "not connected",
   every first entry is refused for the whole test. UNVERIFIED (platform). Look for
   `[SIRUS v29 SETUP DOCTOR] terminal=no`.
5. **B2 - Netting account or spread at or above 500.** Either one refuses every entry for the whole test,
   with a clear Journal line.
6. **B3 - Test window too short or no prior history.** Warm-ups (brain priming, Kalman 30 H1 bars, velocity
   baseline 300 ticks) plus a strict gate chain mean a "1-hour" test can legitimately show 0 trades.
7. **C4/C5 - Multi-symbol DXY proxy and a full ATR handle cache.** The DXY proxy makes the tester model
   EURUSD, GBPUSD and USDJPY as well. The ATR cache holds exactly 12 of 12 combinations with default inputs,
   so changing one TF or period input causes indicator re-creation on every call.
8. **B4 - The tick-velocity guard uses `GetTickCount64` (wall clock).** Its "tick-rate spike" test measures
   how fast the PC processes ticks, not the market. Tester entry pauses therefore happen at random times,
   and live velocity blocks (233 shadow rows) cannot be reproduced in the tester.

(A) OnInit itself is very unlikely to be the problem. The only non-success return is INIT_PARAMETERS_INCORRECT
for obviously invalid inputs. The init log line `[SIRUS v31.6 PHASE 22.9] INIT OK` proves it started.

---------------------------------------------------------------------------------------------------
## A. Initialisation in the tester

### A-1 Only one failure path: input validation -> INIT_PARAMETERS_INCORRECT (STATICALLY PRESENT, low likelihood)
`Sirus_Brain_V8.mq5:61-102`, `OnInit`:
```
if(StartLot <= 0.0) ... else if(MaxLot > 0.0 && MaxLot < StartLot) ... else if(UseGridRecovery && LotMultiplier <= 0.0)
... MaxOrders < 1 ... GridDistancePoints <= 0 ... MagicNumber <= 0 ... CoreTimerSeconds < 0 ... OrderSendDeviationPoints < 0
   return INIT_PARAMETERS_INCORRECT;
```
- When: once per run or optimization pass. In optimization, any pass whose ranges produce e.g. MaxLot < StartLot is
  rejected silently (the tester counts it as a skipped pass).
- Journal: `[SIRUS INIT ABORT] invalid input configuration: ...`.
- There is **no** `INIT_FAILED` return anywhere. A failed `EventSetTimer` (mq5:699) only prints a warning.
- Fix: none needed. Tell the owner to search the Journal for `INIT ABORT`.

### A-2 Account and symbol checks at init only warn (STATICALLY PRESENT)
`Sirus_Brain_V8.mq5:716-723` prints `[SIRUS ACCOUNT] mode=%s ... NEW TRADES DISABLED - needs a hedging account`
when the account is not hedging, but init still returns INIT_SUCCEEDED. The EA "runs" and never trades
(see B-2). The tester takes the margin mode from the account the terminal is logged into.

### A-3 Restores in OnInit read GlobalVariables (STATICALLY PRESENT; behaviour in the tester UNVERIFIED (platform))
`Sirus_Brain_V8.mq5:728-750`: `BayesLoadState, ChainPatternRestore, ScoreBandRestore, WarningStatsRestore,
BlockAuditRestore, BasketAgeRestore, EVRestore, OppTypeStatsRestore, CandleLearningRestore, PatternRecordRestore,
FollowRecordRestore, PostLossCooldownLoad, SelfDefenseLoad, HourBayesLoad, DayOfWeekBayesLoad`, plus
`ScenarioRestore` (mq5:63) and the trail peak GV (mq5:745-750). None of these skip the tester. Only some other
modules do: `MBCeLoad` (20e:63 `if(MQLInfoInteger(MQL_TESTER)) continue;`), MBFastCount (23:787/803) and the
evidence gates (26c:119/155).
- Normally the tester agent has its own GlobalVariable space that starts empty, so these restore nothing. They
  cannot make init fail. If the agent's GVs were shared or kept between runs, see B-6.
- Files: all FileOpen calls (22:215, 24:591, 26:221/390, 26b:166, 90:123) are append-only CSV writers into the
  agent sandbox. Nothing is read back, nothing uses FILE_COMMON, and nothing can fail init.

### A-4 Things that look like init failures but are not
- A compile error leaves the old .ex5 in place: the tester runs the last successfully compiled build. The owner
  must confirm "0 errors" in MetaEditor before testing (this project is 74k lines in 39 includes).
- A huge agent log (see C1) can fill the disk or make the tester appear frozen during the first simulated days.
  To the owner that also looks like "does not work".

---------------------------------------------------------------------------------------------------
## B. Initialises but never (or rarely) trades in the tester

Order of the first-entry chain (`FirstEntryCanRun`, 14:4188): basket-closed-this-tick -> AllowLiveTrading -> ENV
-> RiskAllowsNewEntry -> packs (Pack3, P4M, P4L, ...) -> score -> location -> micro -> positions -> cooldowns ->
Operator -> DailyProfitGovernor -> SettingsSanity -> License -> **SetupDoctor (4639)** -> Retry -> Calendar ->
Holiday -> **Weekend** -> SmartTime -> FreshBar -> **AccountMode (4690)** -> **Velocity (4697)** -> Drift -> ...
-> brain veto -> entry judge. Each refusal prints `[SIRUS v31.6 PHASE 21.3 ENTRY] ENTRY: WAIT | reason=<text>`
(14:4983-4995) when the reason text changes. **That line names the gate**, so it is the first thing to ask for.

### B-1 Setup Doctor requires TERMINAL_CONNECTED (WRONGLY BLOCKS if the tester reports false; UNVERIFIED (platform)) - P2, high impact
`14_Risk_Gates_Entry.mqh:289-330`, `SetupDoctorAllowsEntry`:
```
bool terminal_ok  = TerminalInfoInteger(TERMINAL_CONNECTED) != 0;
bool algo_ok      = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0;
...
bool all_ok = terminal_ok && account_ok && mql_ok && symbol_ok;
...
if(!all_ok && SetupDoctorBlockLiveInvalid) { reason = "setup doctor: " + state; return false; }
```
Defaults: `EnableSetupDoctor=true` (01_Inputs:3949), `SetupDoctorBlockLiveInvalid=true` (3951).
- How often: every tick that reaches this gate.
- Effect: if the tester agent reports no trade-server connection (a tester agent is not a connected terminal),
  every first entry is refused for the whole run. Grid adds are unaffected, but no basket ever starts.
- Journal: `[SIRUS v29 SETUP DOCTOR] terminal=no algo=... account=... mql=... symbol=...` (printed on change), and
  `ENTRY: WAIT | reason=setup doctor: terminal=no ...`.
- Minimal fix: `bool terminal_ok = MQLInfoInteger(MQL_TESTER) ? true : (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);`
  The same idea applies to `CheckTradePermissions` (03:462) and `VPSCheckBroker` (15:100-122). They read
  TERMINAL_TRADE_ALLOWED and ACCOUNT_TRADE_ALLOWED, which normally read true in the tester.

### B-2 Account margin mode not HEDGING -> all new entries and grid adds off (STATICALLY PRESENT) - P2
`13_Grid_Engine.mqh:1653-1670`, `AccountModeAllowsTrading`:
```
if(mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) { reason = "account hedging"; return true; }
reason = StringFormat("account is %s - the grid basket needs a HEDGING account; new entries and grid additions are off", ...);
return false;
```
It is called in FirstEntryCanRun (14:4690) and in the grid path. The tester takes the margin mode from the
account the terminal is logged into (Exness MT5 accounts are usually hedging, but check).
- Journal at init: `[SIRUS ACCOUNT] mode=NETTING ... NEW TRADES DISABLED` and `[SIRUS ACCOUNT MODE] account is NETTING ...`.
- Fix: none in code. Test with the terminal logged into a hedging account.

### B-3 Spread caps: unified cap 500 points blocks everything, P4M/risk caps also resolve to 500 (STATICALLY PRESENT) - P2
- `UseUnifiedMaxSpread=true`, `UnifiedMaxSpreadPoints=500` (01_Inputs:178/90). `EffSpread()` (03:274) returns 500 for
  every module, so `RiskMaxSpreadPoints=300` and `P4MiniMaxSpread=300` become 500 too.
- ENV: `CheckSpreadEnvironment` (03:503-531): `spread > EffSpread(MaxSpreadPoints)` gives "spread high". Risk:
  `RiskHardBlockCheck` (14:463-467) `G_LAST_SPREAD_POINTS >= EffSpread(RiskMaxSpreadPoints)` gives RISK BLOCK.
- Tester specifics: with "Every tick" or "1 minute OHLC" the spread comes from the M1 bar spread field or the
  fixed value chosen in the tester's Spread box. If the owner left Spread = "Current" while the market was closed
  or at rollover, a single large value (e.g. 600-1000 points on XAUUSDm) is used for the ENTIRE test, and nothing
  ever trades. With real ticks, real spread is used (normally around 160-300 points on XAUUSDm - estimate).
- Journal: `[... ENV] ENV BLOCK: spread high NNN/500 ...` or `RISK BLOCK: risk spread high NNN/500`.
- Fix: none in code. Ask for the tester's Spread setting.

### B-4 Tick-velocity guard measures PC speed, not market speed, in the tester (CONDITION WRONG in tester) - P2/P3
`11_Expectancy_MTF_News.mqh:1876-1999`, `TickVelocityUpdate` (called from OnTick, mq5:1410):
```
ulong ms = GetTickCount64();
double dt = (double)(ms - G_VEL_LAST_MS); if(dt < 1.0) dt = 1.0;
double rate = 1000.0 / dt; // tick/sekund
G_VEL_RATE_FAST = ... *0.70 + rate*0.30;  G_VEL_RATE_SLOW = ... *0.995 + rate*0.005;
...
double ratio = G_VEL_RATE_FAST / G_VEL_RATE_SLOW;
if(ratio < VelocitySpikeRatio || move_points < (double)VelocityMovePoints) return;
```
- How often: every tick.
- In the tester, `dt` is the real time the PC took between two OnTick calls, i.e. how heavy the EA's last tick
  was, clamped at 1 ms, so `rate` is at most 1000. Cheap ticks look "fast" and per-bar or scanner ticks look
  "slow". The ratio of 4 (01_Inputs:381) is therefore met whenever a run of cheap ticks follows a run of heavy
  ones. Heavy ticks happen exactly when price moves, because the scanner re-runs on price moves (C2). So the
  guard tends to stay silent during real spikes and fire at random during cheap stretches.
- The price-move condition (>= max(400 points, 1.5 x ATR(M1)) in 5 s) still limits it, and the first-entry
  pause is capped at 60 s per 5 min (`VelocityMaxHoldPer5Min=60`). The grid pause `G_VEL_GRID_UNTIL` (11:1939)
  is set before that budget check and has no cap.
- Effect: velocity blocks in the tester differ from live (live CSV: 233 velocity rows), so the tester cannot
  reproduce or validate this gate. It is not a total block.
- Fix: use market time: `MqlTick t; SymbolInfoTick(_Symbol,t); ulong ms = t.time_msc;` instead of `GetTickCount64()`.
  `time_msc` is the same live and in the tester (real or generated ticks). The comment at 17:681-683 shows the
  authors already fixed the identical problem in MBTickFlowUpdate.

### B-5 History readiness and warm-ups: a short test can legitimately produce 0 trades (STATICALLY PRESENT) - P3
- ENV history (03:533-570, `CheckHistoryEnvironment`, every tick): `MinBarsM1/M5/M15/H1 = 100` (01_Inputs:3841-3844),
  `t0 > 0`, and `SERIES_SYNCHRONIZED` (03:294). Normally satisfied in the tester (the tester supplies history before
  the start date). It fails only if the terminal has no history before the start date. Journal:
  `ENV BLOCK: M1 history not ready` / `H1 history not ready`.
- Brain priming (20_Market_Brain.mqh:1126, `G_MB_BRAIN_PRIMED = (G_MB_ATR[0..2] > 0 && G_MB_EV_FILLED[1] && G_MB_EV_FILLED[2])`):
  this needs `CopyRates` of at least 30 bars (17:714) and at least 40 bars (18:686) on M1/M5/M15. Until then the
  judge returns `entry judge: market data not ready (brain warming up)` (23:258) for every entry.
- Kalman (04_Trend_Structure.mqh:1435-1473): steps once per new H1 bar, ready after `KalmanWarmupBars=30` H1 bars,
  about 30 simulated hours. It is not seeded from history. Consumers fall back to SMA logic, so it does not block,
  but the first 1-2 days of every test run on different logic than a long-running live EA.
- Velocity baseline: `G_TICK_COUNT < 300` (11:1912). Scenario, Bayes, hour and day statistics start empty in a
  tester run.
- Effect: for "a 1-hour test" (the comment in mq5:1438) zero trades is quite possibly correct behaviour.
  This is especially true with the strict gate chain (live CSV: score 817, brainVeto 526 refusals). Test at
  least 1-2 weeks.

### B-6 Live state leaking into the tester via GlobalVariables (NOT YET VERIFIED; only if the agent shares or keeps GVs) - P2 if it happens
`12_Exits_Trailing.mqh:713-726`, `PostLossCooldownLoad`:
```
datetime until = (datetime)GlobalVariableGet(key);
if(until > TimeCurrent()) { G_POST_LOSS_COOLDOWN_UNTIL = until; PrintFormat("[SIRUS v30.2 PERSIST] Post-loss cooldown restored until %s", ...); }
```
- If the tester saw a GV written by the live EA (same Magic and symbol), `until` is a 2026 timestamp, which is
  greater than any historical TimeCurrent. The post-loss cooldown would then block every entry for the whole
  backtest (`RISK BLOCK: post-loss cooldown until ...`).
- Similar restores: SelfDefense (11:1512, raises the minimum score), HourBayes and DayOfWeekBayes (bad-hour/day
  filter), Bayes, candle learning (05:1312), Scenario (14:2993).
- Normally the agent's GV space is separate and empty, so this should not happen. The Journal settles it in
  one look: any `[SIRUS v30.2 PERSIST] ... restored`, `[SIRUS v31 SELF-DEFENSE] restored ACTIVE`,
  `[SIRUS v31.1 HOUR-BAYES] restored N values` or `[SIRUS SCENARIO] N reactions recovered` line at the start
  of a test.
- Fix (also for determinism between runs): skip every restore and save when `MQLInfoInteger(MQL_TESTER)`, as
  20e:63 and 26c:119 already do.

### B-7 Tester model choice changes what the EA can see (STATICALLY PRESENT) - P2 for validity
- "Open prices only": OnTick fires only at each chart-timeframe bar open. A TP of about 224 points, M1 bars,
  the live-sweep reclaim timer, the 10 s entry cooldown and the tick flow are all meaningless. Do not use it.
- "1 minute OHLC": 4 ticks per M1 bar. `MBTickFlowUpdate` (17:677, CopyTicks over 30 s), live sweep (18:1004),
  velocity (B-4), `MinSecondsBetweenEntries=10` and TP fills at 224 points against a spread of about 240 are
  all distorted. Use it only as a quick "does it trade at all" smoke test.
- "Every tick" (generated): synthetic ticks and bar spreads. "Every tick based on real ticks" is the only
  model where this scalper's results mean anything. It is also the slowest (C1/C2 cost scales with tick count;
  XAUUSD real ticks are of the order of 10^5 per day - estimate).
- If the broker has no real-tick history for the range, the tester silently generates ticks. Its Journal then
  says so ("real ticks absent ... generated").

### B-8 Behaviour that differs from live by design (STATICALLY PRESENT, not blockers) - P3
- Economic calendar off in the tester: `UpdateEconomicCalendarGuard` (11:4938) `if(MQL_TESTER) { CalendarClearState(); return; }`.
  The tester trades through NFP and CPI releases, which live refuses (31 calendar rows plus 38 news rows in the
  live CSV). Expect more trades and worse fills in the tester.
- DXY proxy (11:2633-2690): if EURUSD, GBPUSD and USDJPY (Exness: EURUSDm etc.) cannot be resolved in the tester,
  it behaves as disabled. Journal: `[SIRUS v31.6j DXY TESTER] ... AVAILABLE / NOT AVAILABLE`. See C4 for the cost
  when it IS available.
- Weekend guard (11:1333-1345, TimeCurrent): blocks Saturday and Sunday bars and Friday from
  `WeekendBlockEntryFriHour`. A test window that is only a Friday evening shows 0 trades.
- Spread memory (20e) starts empty in the tester (intended), so V10/V11 "x normal spread" vetoes are inactive
  for the first 20 M1 samples of each hour.
- `StartLot=0.25` fixed (`UseAutoLot=false`). With a small tester deposit and default tester leverage of 1:100
  (live Exness is often 1:2000 or unlimited), the ladder is trimmed (14:4934-4955) or orders fail with "not
  enough money". This changes the result; it is not a code bug. Ask for deposit and leverage.

### Checked and fine in the tester
- `Sleep` only in close retries and skipped in the tester (12:1125). `TimeLocal` is used only for throttles and
  tick-age (03:285, 15:50/142, 16:669/1000/1088). In the tester it equals simulated time, so tick age reads 0 in
  OnTick and `MaxTickAgeSeconds=180` never trips. No TimeGMT.
- `HistorySelect` is throttled or cached everywhere (09:2237 every 300 s; 22:167 per basket close; 25:* panel only,
  cached; 10:169 commission cached per position; 26:346 once a day).
- Symbol keyword "XAUUSD" and P4M "XAU" both match "XAUUSDm". SYMBOL_TRADE_MODE is FULL in the tester. The license
  guard is off by default (01_Inputs:3938).
- `G_GRID_ATTEMPTS` (MaxDailyGridAttempts=200) is reset by ResetOpportunity each scan, so it does not accumulate
  across a long test.

---------------------------------------------------------------------------------------------------
## C. Runs extremely slowly

Context: the PERF(tester-speed) fix already skips the dashboard and heartbeat in OnTick when in the tester
(mq5:1436-1450, 16:1085). The comment there blames them for "a 1-hour test taking 200 hours". What remains is
below. The EA has a built-in profiler (`EnableProfiler=true`, 26_Measure.mqh:33). It prints an hourly
`[SIRUS PROF] avg/peak per segment` line (26:113-128) and a daily `[SIRUS DAY REPORT] ... tick X ms` line
(26:390), **including in the tester**. These two lines would turn every estimate below into a measurement.
Rule of thumb: wall time is roughly ticks x avg tick ms. For example 150k ticks/day x 2 ms is 5 min per
simulated day, and x 20 ms is 50 min per day.

### C-1 Journal flood - no tester suppression, spread inside two signatures (P2, most likely main cost)
Default `VerboseLogs=true` (01_Inputs:99). About 35 loggers of the form
`string signature = <STATUS> + "|" + <DETAIL> + "|" + IntegerToString(G_BARS_SEEN); if(Print... && signature != LAST) PrintFormat(...)`.
Because `G_BARS_SEEN` is in almost every signature, every module that passes its own filter prints at least
once per M1 bar. The worst ones:
| file:line | function | prints when | default flag |
|---|---|---|---|
| 03_Core_Utils.mqh:659-670 | UpdateEnvironmentEngine (every tick) | **any spread change** - `G_ENV_SPREAD_STATUS` = `"SPREAD: %d | ..."` (03:507) is in the signature, no other filter | PrintEnvOnChange=true (3870) |
| 04_Trend_Structure.mqh:1410-1422 | UpdateModeManager | signature has `G_LAST_SPREAD_POINTS`; prints only when "important" (mode switch) so mostly string cost | PrintModeOnChange=true |
| 03_Core_Utils.mqh:390-397 | UpdateBarTracker | every new M1 bar (1440/day) | PrintNewBarLog=true (3869) |
| 14_Risk_Gates_Entry.mqh:4983-4995 | UpdateFirstEntryEngine | every change of the WAIT reason. Reasons with counters change every tick or second: `"entry cooldown seconds %d/%d"` (14:4606), `"velocity spike hold %ds left"` (11:1996), `"spread high %d/%d"` | PrintEntryDecision=true |
| 13_Grid_Engine.mqh:2858-2868 | grid engine | any change while a basket is open (detail has live values) - per tick with a basket | PrintGridDecisions=true |
| 09_Redirect_Queue_Pack2.mqh:3024-3034 | UpdateLegacyPack2 | `G_BASKET_ORDERS > 0` and the detail has `DD=%.2f` - **per tick while any basket is open** (250-450 baskets/day) | PrintLegacyPack2Events=true |
| 14_Risk_Gates_Entry.mqh:561-571 | UpdateRiskEngine | while RISK BLOCK, the detail has `profit=%.2f` - per tick during a risk block | (no flag) |
| 15_Legacy_Packs.mqh:195-231 | UpdateVPSLiveValidation | VPS line every 30 s when changed; NO-TRADE AUDIT every 120 s; BROKER every 300 s | UseVPSLiveValidation / VPSPrint* = true (3875-3884) |
| 14_Risk_Gates_Entry.mqh:3869-3900 | DecisionChainLog | once per bar per direction or verdict (a long `[SIRUS CHAIN]` line) | LogDecisionChain=true (1086) |
| 14_Risk_Gates_Entry.mqh:3578-3598 | DecisionLog | every new line text (has score and leg position), at most once a minute only if identical | EnableDecisionLog=true (958) |
| 08:222, 08:6927, 09:513/934/1386/1840/1978/2388, 10:82, 15:824/1001/1919/2103/2176/2546/2871/3194/3462/3718/3966/4246/4477/4765, 16:171/381/673 | module loggers | on change, filtered (grade != NONE, APPLIED, basket open ...) | all true |
- How often: from about 10^4 lines per simulated day with no basket open to about 10^5 or more with baskets
  open and real ticks (estimate). Each line is a formatted string plus synchronous agent-log I/O. A month of
  real-tick testing can write millions of lines (GB-size logs).
- Minimal fix:
  1. Add one global: `bool G_TESTER_QUIET = (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE) && !TesterVerboseLogs);`
     (new input `TesterVerboseLogs=false`). Prepend `!G_TESTER_QUIET &&` to every print-on-change condition, the
     NEW BAR, VPS, AUDIT and BROKER prints and DecisionChainLog. Keep only ENTRY SENT/FAILED, basket close,
     DAY REPORT and PROF.
  2. Remove `G_ENV_SPREAD_STATUS` from the ENV signature (03:659) and `G_LAST_SPREAD_POINTS` from the MODE
     signature (04:1410). Neither needs to log every spread tick, even live.
  - Zero-code workaround for the owner today: VerboseLogs=false, PrintEnvOnChange=false, PrintNewBarLog=false,
    PrintEntryDecision=false, PrintGridDecisions=false, PrintLegacyPack2Events=false, PrintMarketOnChange=false,
    PrintModeOnChange=false, UseVPSLiveValidation=false, LogDecisionChain=false, EnableDecisionLog=false, all
    other Print*Events=false. These are print and status only. I checked that G_VPS_OK is read only by text
    builders (16:441), so they do not change trading.

### C-2 Full pipeline every tick, plus a 1 s timer pass (P2)
`16_Dashboard_Core.mqh:841-1000`, `CoreUpdate("TICK")`. The only throttle is `ScanDue` (16:801-814), and it
re-runs the scanner when
```
if(atr1 > 0.0 && MathAbs(bid - G_SCAN_BID) >= ScanMovePointsATR * atr1) return true;   // ScanMovePointsATR = 0.10 (16:778)
if((TimeCurrent() - G_SCAN_TIME) >= MathMax(1, ScanMaxSeconds)) return true;          // 3 s
```
0.10 x ATR(M1) on XAUUSD is a few tens of points, about one or two typical tick moves, so in an active market
the full scanner and score (08, about 7k lines) plus 13 more engines run on most ticks. Everything after the
scanner runs on every tick unconditionally:
- about 25 guard and pack updates, several twice per tick (Pack3, P4M, P4L, RCB, WCP, SmartClientSafety run
  before and "POST_ENTRY");
- the grid engine and the first-entry engine (the full gate chain, veto and judge probes);
- `UpdatePremiumVisualEngine` and `UpdatePremiumLogEngine` (`BuildNextAction` / `BuildPremiumSummary` strings);
- about 100 `StringFormat` status and detail strings that only the dashboard reads, e.g. `UpdateClockState`
  (03:316, 3 x TimeToString), `UpdateTickState`, `UpdateBarTracker` "BAR OK" (03:402) and the ENV strings
  (03:640-675, plus 4 x `Bars` / `SeriesInfoInteger` in CheckHistoryEnvironment);
- `RefreshGridDashboardStats` (13:2538) has 21 call sites. Each loops positions and calls
  `DrawBasketTPSLLines` (C-3).
- OnTimer: `CoreTimerSeconds=1` (01_Inputs:3833) means 86,400 simulated timer events per day. Each one runs
  `EmergencyBasketForceCloseCheck` + `UpdateClockState` + `UpdateTickState` + calendar (returns at once) +
  `CheckNewsAutoFlat` (16:857-863). That is modest, but pure overhead in the tester.
- Minimal fix:
  1. In the tester, raise `ScanMovePointsATR` to 0.3-0.5, or gate the scanner to at most once per simulated
     second unless the basket count changed.
  2. Build the G_*_STATUS / G_*_DETAIL / G_CLOCK / G_BAR strings only when they will be shown or printed, e.g.
     `if(!G_TESTER_QUIET)` around the StringFormat blocks.
  3. In OnTimer, `if(MQL_TESTER && !MQL_VISUAL_MODE) return;` before CoreUpdate. OnTick already runs
     EmergencyBasketForceCloseCheck on every tick, and calendar and news auto-flat are off in the tester.

### C-3 Chart objects in non-visual tests; close markers grow without bound (P2, progressive slowdown)
- `13_Grid_Engine.mqh:2444-2450`, `DrawBasketTPSLLines`:
  ```
  // PERF: chart objects are for live monitoring only - never draw them in the tester/optimizer, ...
  if((bool)MQLInfoInteger(MQL_OPTIMIZATION)) return;
  ```
  The comment says "tester/optimizer" but the code checks optimization only. In a single non-visual test it runs
  from every RefreshGridDashboardStats call: several times per tick, 4 ObjectFind plus ObjectSet* with a basket
  open, 4 ObjectDelete when flat.
- `15_Legacy_Packs.mqh:1878-1905`, `UpdatePremiumVisualEngine` (`UsePremiumVisualEngine=true`, refresh every 3
  simulated seconds): about 10 draw routines (zones, basket lines, markers, header, watermark) with no tester
  guard.
- `12_Exits_Trailing.mqh:925-960`, `DrawBasketCloseMarker` (`EnableCloseMarkers=true`): 2 objects per basket
  close, never deleted during the run. The comment at 12:924 says "permanent visual trail". At 250-450 baskets
  a day, a 1-month test leaves about 10^4 objects.
- `15_Legacy_Packs.mqh:1833-1875`, `UpdatePremiumVisualClutterControl`, every 30 simulated seconds: two
  `PremiumVisualCountObjects` passes (1727) + `PremiumVisualCleanupSignalHistory` (1793) + `DeleteByPrefix("SESSION_")`
  (session zones are off). Each is a full `for(i=ObjectsTotal(0)-1..)` with `ObjectName` + `StringFind`. With N
  growing from the markers, that is 2,880 cleanups a day x 4 scans x N, so later days of a long test run slower
  than early ones.
- Fix: one guard `if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;` at the top of
  DrawBasketTPSLLines (replacing the optimization-only test), UpdatePremiumVisualEngine and DrawBasketCloseMarker.

### C-4 DXY proxy makes the test multi-symbol (P3, cost scales with the tick model)
`11_Expectancy_MTF_News.mqh:2633-2690` (`ResolveBrokerSymbol`, `DXYProxyEnsureSymbols`): `SymbolSelect` of
EURUSD/GBPUSD/USDJPY (or the first symbol starting with that name, e.g. EURUSDm) and `iClose(other, H1, ...)`
(2689-2693). Defaults: `EnableDXYProxy=true` (5102), `EnableDXYConfirmedTrend` (5859), `EnableDXYDeceleration` (6685).
- In the tester, touching another symbol makes the tester download and model it, with real ticks if that model
  is chosen. That adds three FX majors' tick streams to every run and a long first-run download. Behaviour also
  depends on whether that data exists (B-8).
- Fix: in the tester default the proxy off (`if(MQL_TESTER && !TesterUseDXY) return false;` in DXYProxyEnsureSymbols),
  or document that DXY needs those symbols' history. Note: turning it off changes scoring (bonus/penalty 1).

### C-5 ATR handle cache is exactly full with default inputs (P3 risk, catastrophic if exceeded)
`04_Trend_Structure.mqh:1041` `#define SIRUS_ATR_CACHE_SIZE 12`, round-robin eviction with `IndicatorRelease`
(1066-1078). I resolved every `ATRPointsManual` call to its defaults and count exactly 12 distinct (TF, period)
pairs: (M1,14), (M5,14), (M15,14), (M30,14), (H1,14), (H4,14), (D1,14), (M15,20) and (M15,5) ExpandingVol,
(M1,100) ATRRegimeBasePeriod, (M5,100) VolatilityBaseline, (M15,56) RegimeCandidate.
- If any TF or period input is changed (e.g. RegimeTF=H1, ATRPeriod=20, a different HierarchyTF/LBTimeframe), a
  13th pair appears. From then on, round-robin eviction destroys and re-creates iATR handles continuously,
  potentially several times per tick. Each re-creation recalculates ATR over the whole history, and the first
  `CopyBuffer` can return -1, which reads as ATR=0. That alone can make a test hundreds of times slower and change
  decisions. It is the most plausible mechanism for a literal "200x" slowdown if the owner tested with a modified
  .set. UNVERIFIED (which .set was used).
- Fix: `#define SIRUS_ATR_CACHE_SIZE 32`. The same applies to the SMA cache (12) and RSI/ADX caches (8)
  (03:862/936/1011), though their combinations looked within limits.

### C-6 Visual mode: UI throttles run on simulated time (P3, visual tests only)
In visual mode OnTimer draws every simulated second (mq5:1462-1467). `DrawDashboard`'s throttle is
`TimeLocal()` + `DashboardRefreshSeconds=1` (16:1088). In the tester that is simulated time, so at a high
speed slider the panel (about 200 color helper calls, many objects, `ChartRedraw` 25:968) is rebuilt many
times per REAL second. `MBVisChartBg` (25:70) correctly uses `GetTickCount`; the redraw throttle should do the
same.
- Fix: throttle UI redraws on `GetTickCount()` (wall clock), e.g. at most every 250-500 ms, in visual mode.
  This is the opposite of trade logic, which must use simulated time.

### C-7 Smaller items (P4)
- `MBShadowFlush` (26:217-232): FileOpen/Close once per M1 bar when there are rows (`ShadowToFile=true`, skipped only
  in optimization). `RCWriteCsv` (90:116): one FileOpen per order (about 500-2000 a day with grid). Autopsy,
  DNA and Recovery CSVs: per basket. Acceptable. Turn them off for speed runs.
- `MBTickFlowUpdate` (17:677-698): `CopyTicks(... from now-30 s, up to 3000)` once per simulated second. Fine.
- `MBRangeLayersUpdate` (20:488): `CopyRates(M5, 1460)` plus a loop once per M15 bar. Fine.
- `DuplicateInstanceCheck` (13:1132): one GlobalVariableSet per second. Fine.
- Market Brain (17/18/20/20a-g), ZoneMap (11:3114), LocationBrain (14:3340) and ZoneEngineBuild (14:3600) are
  per-bar cached. They are not per-tick hot spots.

---------------------------------------------------------------------------------------------------
## D. What the owner should check and send

**Tester settings (screenshot of the Settings tab):**
1. Model: "Every tick based on real ticks" (required for meaningful results) vs "1 minute OHLC" (smoke test
   only) vs "Open prices only" (invalid for this EA).
2. Symbol exactly (XAUUSDm?), chart timeframe (use M1), date range (at least 1-2 weeks, not 1 hour), visual
   mode on or off, optimization on or off.
3. Deposit, currency, **leverage** (the tester default is 1:100, not the live Exness leverage), **Spread**
   ("Current" vs fixed - see B-3), Delays.
4. Was a .set file loaded? Send it, because changed TF or period inputs trigger C-5.
5. Terminal account: hedging or netting (B-2); demo or real; which Exness server.

**Journal / Tester log lines (search the tester's "Journal" tab or `Tester\Agent-*\logs\*.log`):**
- Start: `[SIRUS v31.6 PHASE 22.9] INIT OK ...`, `[SIRUS ACCOUNT] mode=...`, any `[SIRUS INIT ABORT]`,
  `[SIRUS v254 SETTINGS]`, `[SIRUS v31.6j DXY TESTER] ...`, any `PERSIST ... restored` / `SELF-DEFENSE restored`
  / `HOUR-BAYES restored` / `SCENARIO ... recovered` (B-6).
- Blockers: the first 20 `[SIRUS v31.6 PHASE 21.3 ENTRY] ENTRY: WAIT | reason=...` lines, any
  `[SIRUS v29 SETUP DOCTOR] terminal=...` (B-1), `[... ENV] ENV BLOCK: ...`, `RISK BLOCK`,
  `[SIRUS v31.6 PHASE 21.3 NO-TRADE AUDIT]` (every 120 s, a compact "why no trade"), and `[SIRUS QUIET]`.
- Daily: `[SIRUS DAY SUMMARY]`, `[SIRUS DAY REPORT] ... tick X ms`.
- Speed: every `[SIRUS PROF] avg/peak per segment: ...` line (hourly). This shows where the milliseconds go
  (tick / pre / brain / scan / guards / grid / entry / post).
- Tester's own lines: "real ticks absent / generated", "history ... synchronized", "not enough money",
  "invalid volume", "unsupported filling mode", "market closed", "log file size".
- Size of the agent log file for the run (GB-size confirms C-1).

**Quick A/B to separate B from C (no code change):**
1. Run 1 week, "1 minute OHLC", non-visual, deposit 10,000, leverage 1:500+, fixed spread 200, all Print flags off
   (list in C-1), UsePremiumVisualEngine=false, EnableCloseMarkers=false, EnableTPSLLines=false,
   EnableDXYProxy=false. If it trades, the code can trade in the tester. If it still does not, the ENTRY WAIT
   reason names the gate.
2. Same week with "Every tick based on real ticks". Compare the `[SIRUS PROF]` tick ms and the wall time.

---------------------------------------------------------------------------------------------------
## E. Proposed minimal code changes (NOT applied), in priority order
1. Tester log silencer (`G_TESTER_QUIET`) on all print-on-change, NEW BAR, VPS, AUDIT, BROKER, CHAIN and LOG prints.
   Drop spread from the ENV and MODE signatures (03:659, 04:1410).
2. SetupDoctor: skip `TERMINAL_CONNECTED` in the tester (14:297).
3. `MQL_TESTER && !MQL_VISUAL_MODE` guard for DrawBasketTPSLLines (13:2448), UpdatePremiumVisualEngine (15:1878)
   and DrawBasketCloseMarker (12:925).
4. `SIRUS_ATR_CACHE_SIZE` 12 -> 32 (04:1041).
5. TickVelocityUpdate: `MqlTick.time_msc` instead of `GetTickCount64()` (11:1881).
6. OnTimer: return early in a non-visual tester (mq5:1455); in the tester, ScanMovePointsATR 0.3+ or a 1 s scan floor (16:801).
7. Skip all GV restores and saves under MQL_TESTER (mq5:728-750 and the *Load/*Restore functions) for deterministic runs.
8. DXY proxy off by default in the tester (11:2653).
9. Status/detail StringFormat blocks only when they will be displayed or printed.
10. Visual-mode UI throttle on wall clock (16:1088).
