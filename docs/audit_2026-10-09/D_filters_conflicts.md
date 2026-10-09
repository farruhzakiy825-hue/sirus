> TEKSHIRUV IZOHI (bosh audit): D-02 qisman noto'g'ri - 08:1918 dagi v180 valve faqat ScoreHardBlockCheck sabablarini (ENV, chaos, spread, tick) ochadi, yo'nalish bloklarini emas. Yo'nalishli counter-trend rad etishning alohida valve'i 08:1495 da (A5). Qarang: AUDIT_2026-10-09.md, 5-bo'lim.

# Auditor D - first-entry filters / gates and the conflicts between them

Scope: 10, 11 (velocity, calendar + settle, drift, time filter, holiday/weekend), 14 (FirstEntryCanRun and
helpers), 20c, 20d, 20e, 20f, 21 (veto V0-V11 + council), 22, 23 (judge, fast entry), 26, 26b, 26c.
Read-only audit. Line numbers are per-file (Sirus/*.mqh). "Guess" marks anything not proven from code.
Status words: STATICALLY PRESENT / RUNTIME VERIFIED / FAILED / NOT YET VERIFIED (as in the brief).
CSV evidence = the owner's shadow files from 06-09 Oct (older build). It proves only that a gate family fired.

---------------------------------------------------------------------------------------------------
## 1. The first-entry filter chain, in the order it really runs

Call chain: `UpdateFirstEntryEngine` (14:4871) -> `FirstEntryCanRun` (14:4172). After the call, the reason
string goes through `GateRecord` (tally per TICK, 14:4881), `MBMissedNote` (second-chance memory),
`MBShadowOnDecision` (one shadow per direction per M1 bar, 26:420), `QuietTick`, `DecisionChainLog`.
The shadow CSV gate name = `GateName(GateClassify(reason))` (14:2137-2183), so it is decided by KEYWORDS in
the reason text, in this order: "no setup" > "market brain veto" > "entry judge" > "better place" > "score" >
"zone/supply/demand" > "news/release/scheduled" > "calendar" > "spread" > "velocity/spike" > "cooldown" >
"position" > "retry" > "margin" > "ladder/afford/budget" > "session/hour" > "weekend" > "holiday" >
"risk/DD/loss" > "regime" > "drift" > "direction" > "ENV" > "license" > "pack3" > "pack4" > "false/engine".
Anything else -> "other". Rows with GATE_POSITIONS and rows with no direction are never shadowed.

Columns: Sides = one (the proposed side only) / both (direction-blind). Log = DecisionLog verdict or Print tag
(besides GateRecord/DecisionChainLog that every refusal gets). Relaxers = anything that can switch it off at
runtime. All are STATICALLY PRESENT unless marked otherwise.

| # | Filter | file:line | Reads | Sides | Log | Shadow gate | Relaxers / release |
|---|---|---|---|---|---|---|---|
| 0 | UseFirstEntryEngine | 14:4193 | input | both | - | other ("false"->engineOff) | input |
| 1 | basket closed this tick | 14:4201 | G_BASKET_CLOSED_TICK | both | - | (positions, not shadowed) | next tick |
| 2 | AllowLiveTrading | 14:4207 | input | both | - | engineOff | input |
| 3 | ENV not ready | 14:4213 | G_ENV_READY | both | - | env (RUNTIME VERIFIED, 2 rows) | env |
| 4 | RiskAllowsNewEntry (DD, equity stop, daily loss, spread>=500, post-loss cooldown, max attempts) | 14:4220 / 14:576, 420-500 | account, G_LAST_SPREAD_POINTS | both | - | risk / spread / cooldown / other | time, day roll |
| 5-15 | Legacy packs: Pack3, P4M, P4L, RCB, DCS, DLP(HTF commander), DBOS, DTZ, DNV, DET, DRT | 14:4227-4302 (09:2403, 15:1016-4838, 10:113) | pack globals G_*_ENTRY_BLOCK | per pack (mostly both) | - | mostly other; DTZ may hit "zone"; DRT "regime" | pack logic (out of scope) |
| 16 | SCORE decision (scanner 08) incl. HARD_BLOCK, LATE-hold arm, fill-timing arm | 08 (UpdateSignalScoreEngine); tested 14:4491 | detectors, penalties (incl. counter-trend 08:6355-6440) | one | NEAR-MISS print | **score** (RUNTIME VERIFIED, 817 rows) | see 16a-16f |
| 16a | Relief 5A/15/5B (win re-entry +2, micro structure +2/+1, good location +2), shortfall <=2 | 14:4310-4370 | G_LAST_WIN_*, MicroStruct, ZoneBlocks(-dir) | one | [SIRUS RELIEF] | - | not over own-side arm |
| 16b | Brain score relief | 14:4375-4387, 23:1158 | G_MB_BIAS, thesis, local/range | one (brain side) | DecisionLog BRAIN | - | not over own-side arm |
| 16c | Judge-instead-of-score bypass (quality >= 65, or 45 when EG_SCORE relaxed) | 14:4392-4404, 23:1102-1109 | full judge probe | one | DecisionLog JUDGE | - | EG_SCORE lowers threshold |
| 16d | **Evidence gate EG_SCORE** - WAIT -> PASS, no shortfall cap | 14:4406-4418 | 26c tallies | one side bucket | DecisionLog EVIDENCE | - | 26c (seeded relaxed on bias/neutral side) |
| 16e | v180 Block Safety Valve - releases ANY score HARD_BLOCK after 180 silent bars | 08:1918-1935 | G_LAST_ENTRY_ALLOWED_BAR | one | [SIRUS v180 SAFETY VALVE] | - | (is itself a relaxer) |
| 16f | Fast entry (brain) replaces WAIT / NONE / vetoed PASS / directional HARD_BLOCK | 14:4429-4489, 23:852 | brain, MBCandOk (=MBDirOk + V0 + full veto probe) | other side allowed | DecisionLog FAST | - | - |
| 17 | **Location guard** (LG): zone refusal -> TryLocationRedirect; LGFreshImpulse, LGChasingImpulse, LGMicroTip | 14:4521-4552; 14:3815, 1873, 1843, 1804; redirect 14:4016 | ZoneEngine (M15/M5/M1 swings, band 0.8 ATR5), M5/M1 candles | one | [SIRUS LOCATION] print | **zone** (zone text) / **other** (chase, tip, impulse - no keyword) | skipped when MBOwnsGate(true); redirect flips side |
| 18 | micro guard not ready | 14:4555 | G_MICRO_READY | one | - | other | - |
| 19 | no direction | 14:4560 | G_OPP_DIR | - | - | (not shadowed) | - |
| 20 | OneBasketAtATime | 14:4567 | positions | both | - | positions (not shadowed) | - |
| 21 | entry cooldown bars (FirstEntryCooldownBars=0 -> off) | 14:4573 | G_BARS_SEEN | both | - | cooldown | - |
| 22 | entry cooldown seconds (10 s) | 14:4580 | TimeCurrent | both | - | **cooldown** (RUNTIME VERIFIED, 64) | time |
| 23-27 | Operator, DailyProfitGovernor, SettingsSanity, License, SetupDoctor | 14:4588-4620 | inputs/account | both | - | other/risk | - |
| 28 | RetryEngine (after a failed send) | 14:4623, 11:4584 | G_FIRST_LAST_FAIL_* | both | - | retry | time |
| 29 | **Economic calendar** (hard block, pre 15 / post 15 min, +30 surprise, settle release) | 14:4630, 11:5018, 11:4927 | G_CAL_ACTIVE (TimeTradeServer) | both | [SIRUS CALENDAR] | **calendar** (RUNTIME VERIFIED, 31) | settle release 11:4884 |
| 30 | Broker holiday (hard block off by default) | 14:4637, 11:1314 | date list | both | - | holiday | - |
| 31 | Weekend guard (Fri late, Sat/Sun) | 14:4644, 11:1389 | server time | both | - | weekend | - |
| 32 | Smart time filter (bad hour / bad weekday Bayes) | 14:4652, 11:1752 | G_HB_*, G_DOW_* | both | [SIRUS SMART TIME FILTER] | session ("hour") / other ("bad-day") | 10%/day fade |
| 33 | Fresh-bar (FreshBarMaxPercentOfBar=0 -> off) | 14:4659, 11:1347 | bar age | both | - | other | smart-fill arm bypass |
| 34 | Account mode (needs hedging) | 14:4667, 13:1653 | account | both | - | other | - |
| 35 | **Tick-velocity guard** (spike: rate x4, move >= max(400, 1.5 ATR1) in 5 s; hold 30 s; budget 60 s / 5 min) | 14:4674, 11:1876-1999 | GetTickCount64 rate, TimeCurrent ring | both | [SIRUS v31.1 VELOCITY] | **velocity** (RUNTIME VERIFIED, 233) | budget/expiry |
| 36 | **Entry drift guard** abs(bid - M1 close[1]) > max(300, 0.6 ATR M1) | 14:4681, 11:2017-2055 | M1 close, bid | one bucket, direction-blind test | [SIRUS v31.3 DRIFT] | **drift** (RUNTIME VERIFIED, 34) | EG_DRIFT; skipped for fast entries |
| 37 | M1 entry close (UseM1EntryClose=false -> off) | 14:4688 | M1 bar | one | - | other | - |
| 38 | Direction clarity (cost 3 when < 25% clear) | 14:4697 | G_OPP_DIR_CLARITY | one | DecisionLog HOLD | **score** (text "score %d, direction contested") | MBOwnsGate(false); VALVE_CLARITY (unreachable) |
| 39 | Scenario (score +/- only, not a gate) | 14:4713 | scenario file | one | print | - | VALVE_SCENARIO (unreachable) |
| 40 | Failed-break cost | 14:4741 | FailedBreakCost | one | DecisionLog HOLD | **score** | MBOwnsGate(false); VALVE_FAILEDBREAK (unreachable) |
| 41 | Old-level cost | 14:4761 | OldLevelCost | one | DecisionLog HOLD | **score** | MBOwnsGate(false); VALVE_OLDLEVEL |
| 42 | **HTF bias cost** (up to +4 score; "a direction question") | 14:4782, 14:3236 | HTFBiasScan G_HTF_DIR/FORCE | one | DecisionLog HOLD | **score** | MBOwnsGate(true); **VALVE_HTF** |
| 43 | News owner (live news read; scheduled branch duplicates #29) | 14:4801, 14:2012 | NewsInProgress / G_CAL_ACTIVE | both | DecisionLog BLOCK | **news** (RUNTIME VERIFIED, 38) | - |
| 44 | **Location Brain** (M5 leg position, stretch, HTF extra, adapt extra, worse-than-stop) | 14:4819, 14:3388 | M5 leg, G_ADAPT_EXTRA, G_LB_LAST_STOP_* | one | DecisionLog HOLD, [SIRUS BRAIN] | **location** ("better place") (RUNTIME VERIFIED, 17) | MBOwnsGate(true); VALVE_LOCATION |
| 45 | **Market Brain veto** (sub-order below) | 14:4848, 21:700 | brain | one | DecisionLog VETO, [SIRUS VETO] | **brainVeto** (RUNTIME VERIFIED, 526) | EG_NETEDGE only |
| 46 | **Entry Judge** (sub-order below) | 14:4856, 23:244 | brain | one | DecisionLog WAIT, [SIRUS JUDGE] | **brainWait** (RUNTIME VERIFIED, 12) | EG_JUDGE (-10 quality) |

Veto sub-order (21:710-734; first true wins, the reason text is that rule's):
V11 anomaly (20f:293; spread >= 2.5x hour normal, M1 bar >= 4 ATR1, 1-ATR5 tick jump; 5 min; BOTH sides) ->
V0 permission (21:621: invalidation memory, a=-3, a=-2 exceptional reversal, a=-1, a=+1 reversal/momentum/
transition only, a=0 vs DeepHTFTrendDirection (W5)) -> V1 reversal (21:143) -> V2 zone role / V3 no room
(21:161; EG_ZONEFRONT - dead) -> V4 acceleration (21:211) -> V5 exhausted (17:648; EG_EXHAUST - dead) ->
V7 lock (20b) -> V8 MBLateBlocks: taken liquidity / exhaustion >= 70 / late leg >= 85% (20c:336; EG keys dead)
-> V9 re-entry after dead idea / 3 failed attempts (20d:239) -> V10 cost: spread > 2.0x hour normal, net edge
(20e:174; EG_NETEDGE relaxable) -> V6 council (21:397: 1 triple, 1g lower-high, 1h HTF zone, 1f fresh HTF break,
1e M5 structure, 4 weak global, 1b local+M5, 1c trend under attack, 1d exhaustion-not-reverse, 3 zone in front).
All veto refusals are filed as "brainVeto" whatever the sub-rule.

Judge sub-order (23:244-680, "missing" first hit wins, else quality): data not ready -> leg_against ->
candles_against -> tired_block -> pb_running -> zone_only without reaction -> tick flow against -> playbook
expansion -> playbook trend regime -> chasing EXPIRED -> per-alignment needs (trend / neutral / transition /
range / local / counter) -> quality < caution_q (45; -10 cashback tempo; -10 EG_JUDGE; +10 counter-trend tax).

Not in my list but on the path: score HARD_BLOCKs in 08:577-1880 (13 types). 26b Autopsy and 22 Memory do not
gate (22 only scales judge quality by +/-30% after 30 samples, no decay).

---------------------------------------------------------------------------------------------------
## 2. Relaxers - who can switch a gate off (item d)

`MBEGRelaxable` (26c:84-87) = SCORE, JUDGE, DRIFT, NETEDGE. `MBEGSkip` returns false first for every other key:
```
if(!EnableEvidenceGates || k < 0 || k >= EG_COUNT || dir == 0 || !MBEGRelaxable(k))
   return false;                                                   // 26c:173-174
```
Every call site checked:

| Call site | Key | Live? |
|---|---|---|
| 14:4413 score WAIT -> PASS | EG_SCORE | LIVE (no shortfall cap, see D-01) |
| 23:1106 MBJudgeBypassMin 65 -> 45 | EG_SCORE via MBShadowValveOn | LIVE |
| 23:595 judge exec/caution -10 | EG_JUDGE via MBShadowValveOn | LIVE (quality only; "missing" lines kept) |
| 11:2047 drift | EG_DRIFT | LIVE |
| 20e:199 net edge | EG_NETEDGE | LIVE |
| 14:4150 MBOwnsGate shadow valve (location/zone/regime) | EG_LOCATION | DEAD (always false) |
| 20c:350 taken liq, 20c:368 exhaustion, 20c:378 late | EG_TAKEN/EXHAUST/LATE | DEAD |
| 21:528 council 3, 21:716 V2/V3, 21:720 V5 | EG_ZONEFRONT/EXHAUST | DEAD |

So no shadow valve still relaxes a location / zone / direction gate through 26c. BUT three OTHER relaxers do
touch direction content and are not covered by MBEGRelaxable:
1. EG_SCORE removes the score WAIT entirely, and the score contains counter-trend / HTF-hierarchy penalties
   (08:6355-6440, G_PENALTY_TREND_AGAINST). With a neutral brain the clarity / failed-break / old-level gates also
   stand aside (21:587-588) -> D-01.
2. The 14 "SAFETY VALVE" (14:2468-2542) stands down VALVE_HTF = the HTF-bias gate, which 14:4780 calls
   "A direction question" -> D-03.
3. The 08 v180 Block Safety Valve releases any score HARD_BLOCK incl. "counter-impulse" (#7) and "market
   structure: don't trade against a confirmed swing chain" (#10) -> D-02.
Relief 5A/15/5B: quality, capped at 2 points; the BOSQICH-15 micro relief is explicitly meant to override
"global trend against" (14:4322-4323) but only within 2 points - P3 note, not a finding.
Arms: relief/brain/judge/EG never relax over an arm of the same side (A9 fix) - OK.
Fast entry / TryLocationRedirect / det_vetoed: they choose a different SIDE (not relaxers); both still go through
V0..V6 and the judge. Redirect does apply the +2 good-location relief to the flipped side (14:4107-4114).

---------------------------------------------------------------------------------------------------
## 3. Duplicates - same market fact, different data / thresholds (item a)

| Fact | Filters (data, threshold) | Stricter |
|---|---|---|
| Late in the leg / chasing | score LATE hold (08:6280, EntryPositionInMove on LateEntryTF) ; Location Brain (14:3388, M5 leg <=40 bars, BUY<=0.65/SELL>=0.35 minus stretch/HTF/adapt) ; V8 late (20c:374, 6h M15 origin -> MAJOR target, >=85% and >=2.5 ATR15) ; LG MicroTip (M1 10 bars, top 20%) ; LG Chasing (M5 bar >=1.8 ATR, top 30%) ; judge chase (M1 impulse EXPIRED) + decay ; council 1e (needs far half of M5 leg for counter-structure) ; drift (|bid-M1 close| > 0.6 ATR1) | LB / LG MicroTip on the detector path; V8 on the brain path (LB/LG skipped when brain owns) |
| Zone / obstacle ahead | LG zone (14:3704, own zone engine, band 0.8 ATR5, weight>=2) ; council 3 (21:376, zone map role engine, 0.35 ATR5, <4 touches) ; V3 no room (21:187, room < 1.0 x BaseBasketTP ~224 pts, from ask/bid) ; V10 net edge (20e:191, room < 1.2 x (spread+slip+TP) ~557 pts, zone OR any liquidity >= LOCAL M5, from bid) ; old-level cost (14:4761) ; score HB #12 room to target (08:~1850) | net edge (2.5x V3's room, and counts pools); LG zone by distance |
| Liquidity pool ahead | 20c:91 MBLxTargetAhead = the leg's TARGET ; 20e:167 MBRoomAhead = an OBSTACLE (class >= 1) ; judge "swept pool" = a location | opposite semantics -> D-07 |
| HTF trend | V0-W5 DeepHTFTrendDirection (21:685) ; HTF bias cost G_HTF_DIR/FORCE (14:3236) ; council 1h HTF zones, 1f fresh M15/H1 break ; DLP HTF commander pack ; score CounterTrendAtLevel / HigherScaleConflict / GlobalTrendDirection (08:6355-6440) ; judge counter-trend tax (G_MB_BIAS) | V0-W5 (block) vs HTF bias (cost) read DIFFERENT HTF readers |
| News / abnormal tape | calendar (11:4927) ; news owner scheduled branch (14:1977, same G_CAL_ACTIVE) ; live news read NewsInProgress ; velocity (11:1876) ; anomaly V11 (20f) ; DNV pack (strict off) ; EG_MKT_OK (26c:262) ; score news penalty (08:4196) | calendar (hard) first in order? No - see E: score/LG run before it |
| Spread | risk spread >= 500 fixed (14:482) ; V10 > 2.0x hour normal ; V11 >= 2.5x ; EG market >1.5x ; settle <= NewsSettleSpreadMult | 2.0x relative ~= 480 pts at normal 240 - about equal to the fixed 500 |
| Exhaustion | V5 MBExhausted (17:648) ; V8 pressure >= 70 (20c:367) ; judge -0.5/pt from 50 ; council 1d (other side) ; MST_EXHAUSTION state weight | V8/V5 both "block" |
| Repeat after loss | LB worse-than-stop (14:3489, 1 h / 3 ATR5) ; V9 re-entry (20d:239, 60 min / new break) ; V0 invalidation memory ; risk post-loss cooldown ; smart time filter | three independent memories of the same losing basket |

---------------------------------------------------------------------------------------------------
## 4. Deadlocks - both sides closed at once (item b)

| # | Pair | Concrete market | Release |
|---|---|---|---|
| B1 | SELL: V8 late / exhaustion (20c:367-385) ; BUY: council 1d (21:505-523) + judge leg_against/candles_against | Down leg has done 85% of its way from the 6h high to the PDL/H4 low, M5 candles still bearish, no closed bullish M5 turn yet | an M5 turn candle (BUY) or a pullback that lowers the leg % (SELL). Silence 5-20 min (guess) |
| B2 | BUY: council 1g lower-high (20g:218) ; SELL: council 1e M5 structure up intact (21:457-471) | M15 printed a lower high under the top; price bounces in premium on M5 higher lows, local leg up but M5 pressure not both up | closed bearish M5 turn in the far half (SELL) or M5 close above the LH (BUY) |
| B3 | BUY: LGChasingImpulse (14:1843) ; SELL: LGFreshImpulse (14:1873) (detector path, brain not owning) | A closed bullish M5 candle of >= 2 ATR5 with body >= 60%, price in its top 30% (inside the body) | 2 M5 bars / price leaves the body. Both refusals -> shadow "other" |
| B4 | LB dead band (14:3424-3468) | Neutral brain, stretched M5 leg >= 6 ATR5, adapt extra 0.15 after a losing run: BUY needs pos <= 0.30, SELL needs >= 0.70 -> 40% of the leg closed both ways | pullback / adapt decay. (Bias was never 0 in the CSVs, so rare - guess) |
| B5 | V10 net edge both sides (20e:191-205) | Cashback mode, M5 pools / holding zones within ~0.56 $ above and below (chop) | price leaves the box |
| B6 | SELL: V8 taken liquidity ; BUY: council 3 / V3 / net edge | Sell-side pool just swept and reclaimed, resistance 0.3 ATR5 above | M5 close through the resistance |

All are "wait for proof" designs; none is permanent. They are silence sources, not bugs (P3 CONFLICT).

---------------------------------------------------------------------------------------------------
## 5. Release conditions that can never be met / values never updated (item c)
- ValveIsOff(VALVE_CLARITY / VALVE_SCENARIO / VALVE_FAILEDBREAK) (14:4697, 4713, 4741): `ValveForGate` maps only
  LOCATION/REGIME/ZONE (14:2468-2478), so these three can never be stood down - dead branches.
- MBShadowValveOn(GATE_LOCATION/ZONE/REGIME) (14:4150) and the six non-relaxable MBEGSkip sites: always false.
- EG relaxed filter: return condition is effectively unreachable (D-06).
- AdaptDecay timer (D-10): the first tighten step is undone immediately.

---------------------------------------------------------------------------------------------------
## 6. CSV statistics (item 3)

Files: 396b75bb (magic 240007, 1903 rows) + 876129b9 (magic 7770101, 146 rows); 2049 resolved rows,
06-Oct 16:13 .. 09-Oct 06:20. Bad = GRID or TIMEOUT. Alignment = sign(dir x brain_bias); brain_bias was never 0
in these files, so "neutral" is empty. TAKEN bad 10.4% (14/134): with-bias 12.2% (9/74), against 8.3% (5/60).

| gate | n | bad | bad% | with-bias n / bad% | against n / bad% | vs TAKEN 10.4% | binomial p (one-sided) |
|---|---|---|---|---|---|---|---|
| score | 817 | 69 | 8.4 | 451 / 7.8 | 366 / 9.3 | blocks good (bias side) | P(<=)=0.03 |
| brainVeto | 526 | 47 | 8.9 | 434 / 7.4 | 92 / **16.3** | blocks good with bias, protects against bias | 0.02 / 0.05 |
| velocity | 233 | 16 | 6.9 | 156 / 7.7 | 77 / 5.2 | blocks good | 0.04 |
| cooldown | 64 | 3 | 4.7 | 38 / 2.6 | 26 / 7.7 | blocks good | 0.09 |
| risk | 59 | 2 | 3.4 | 49 / 2.0 | 10 / 10.0 | blocks good | 0.05 |
| zone | 44 | 5 | 11.4 | 0 | 44 / 11.4 | ~equal | 0.49 |
| other | 38 | 3 | 7.9 | 0 | 38 / 7.9 | ~equal | 0.43 |
| news | 38 | 5 | 13.2 | 24 / 12.5 | 14 / 14.3 | protects (weak) | 0.37 |
| drift | 34 | 6 | **17.6** | 17 / 5.9 | 17 / **29.4** | protects, against-bias side | 0.14 (against 0.03) |
| calendar | 31 | 0 | 0.0 | 17 / 0 | 14 / 0 | blocks good | 0.03 |
| location | 17 | 2 | 11.8 | 0 | 17 / 11.8 | ~equal | 0.54 |
| brainWait | 12 | 1 | 8.3 | 9 / 11.1 | 3 / 0 | n too small | - |
| env | 2 | 0 | 0 | - | - | - | - |

RUNTIME VERIFIED as firing (family only): score, brainVeto, brainWait, velocity, cooldown, risk, zone, other,
news, drift, calendar, location, env, TAKEN. Never seen: spread, session, weekend, holiday, retry, margin, afford,
regime, noDirection, pack3, pack4, license, operator, engineOff (noSetup/positions are never shadowed).
Caveats: (1) 154 GRID rows fall into only 71 same-direction episodes (resolved within 10 min of each other) - the
samples are strongly clustered, effective n is about half; none of the differences survives that except
perhaps calendar 0/31. (2) TAKEN has its own SE of about +/-2.6 pp. (3) zone/other/location rows are 100%
against-bias: in this build the location guard and Location Brain only ran when the brain was not with the trade
(MBOwnsGate) - consistent with the code. (4) Daily coverage: TAKEN 29 / 2 / 98 / 5 on 06/07/08/09-Oct, far below
the 250-450/day target; 07-Oct was dominated by risk (58) + velocity (31) + brainVeto (29). (5) The CSV cannot tell
sub-rules apart: all veto sub-rules are "brainVeto"; HTF/old-level/failed-break/clarity refusals are "score".
Reading: overall blocked 8.3% bad vs TAKEN 10.4% -> by this metric the gates as a whole do not filter out bad
entries; the only family whose refusals look worse than the trades taken is the veto ON THE AGAINST-BIAS SIDE
(16.3% vs 8.3%) and drift against the bias (29%, n=17). Velocity, calendar, risk and cooldown refusals did
better than the taken trades (they cost trades, not quality) - weak evidence.

---------------------------------------------------------------------------------------------------
## 7. Findings (ranked)

### D-01  CONFLICT  P2 (P1 potential)  - EG_SCORE removes the score with no floor; with a neutral brain nothing then checks detector direction confidence
- 14:4406-4418 `FirstEntryCanRun`:
```
if(G_ARM_DIR != eg_dir && MBEGSkip(EG_SCORE, eg_dir))
{  G_SCORE_DECISION = G_SCORE_IS_MICRO ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS;
```
- 26c:140-146 seed: `G_EG_TK_N[0] = 60; G_EG_TK_BAD[0] = 7; ... G_EG_N[EG_SCORE][0] = 60; G_EG_BAD[EG_SCORE][0] = 5;`
  -> 8.3% <= 11.7% -> EG_SCORE side 0 (with bias OR neutral, `a = (dir*G_MB_BIAS<0)?1:0`) is relaxed from the first tick.
- 21:587-588 `MBStandsInFor`: `if(a == 0) return !location_gate;` -> with a neutral brain clarity (14:4697),
  failed-break (14:4741) and old-level (14:4761) all stand aside.
- Cause: unlike relief (shortfall <= 2) the evidence skip has no shortfall cap; the score carries the counter-trend
  and scale-hierarchy penalties (08:6355-6440). With brain bias 0 the remaining direction checks are V0-W5 (only if
  DeepHTFTrend is against) and the judge (cashback tempo: location OR trigger).
- Effect: under a neutral brain, a detector direction with any score (e.g. 20/60) and a contested direction
  (clarity < 25%) can open the first rung -> the grid's direction is set by a weak, coin-flip detector vote.
- Repro: brain bias 0, detector SELL with score far below minimum; look for `[SIRUS LOG] EVIDENCE | SELL ... score
  x/y short` followed by `OPEN`. Status: STATICALLY PRESENT, NOT YET VERIFIED (bias 0 never occurs in the old CSVs).

### D-02  CONFLICT  P2 (P1 potential)  - v180 Block Safety Valve auto-releases direction hard blocks
- 08:1918-1935 `UpdateSignalScoreEngine`:
```
if(silent_bars >= BlockSafetyValveBars)  { ... hard_blocked = false; G_LAST_ENTRY_ALLOWED_BAR = G_BARS_SEEN; }
```
  EnableBlockSafetyValve=true, BlockSafetyValveBars=180 (01_Inputs:2563-2565).
- Cause: releases whichever hard block is live, incl. #7 counter-impulse and #10 "don't trade against a confirmed
  swing chain" (08 ScoreHardBlockCheck) - direction gates. Owner rule: direction gates never auto-relax.
- Effect: after ~3 h without a score PASS, one entry against a running impulse / swing chain is let through to the
  veto/judge. Repro: `[SIRUS v180 SAFETY VALVE] ... releasing one. Last block: ...`. (08 is outside my file list -
  flag for the scanner auditor.) NOT YET VERIFIED.

### D-03  CONFLICT  P2  - 14 SAFETY VALVE stands down the HTF-bias direction gate, keyed on the wrong gate
- 14:2468-2478 `ValveForGate`:
```
case GATE_LOCATION: return VALVE_LOCATION;
case GATE_REGIME:   return VALVE_HTF;
case GATE_ZONE:     return VALVE_OLDLEVEL;
```
  14:4780-4782: "A direction question ... `if(EnableHTFBias && !MBOwnsGate(true) && !ValveIsOff(VALVE_HTF))`".
- Cause: (1) auto-relaxes a direction gate; (2) HTF refusals are written "score %d, against ..." and classify as
  GATE_SCORE (14:2146), never GATE_REGIME - REGIME only comes from texts containing "regime" (e.g. DRT pack
  "shock/impulse regime", 15:4374), which run BEFORE the HTF gate, so standing HTF down cannot end that silence;
  (3) GATE_ZONE refusals are the location guard, but the valve stands down OLD LEVEL; (4) the share is taken from
  the day's PER-TICK tallies (GateRecord every tick, incl. "no setup"), not from the current quiet run.
- Effect: either never fires (noSetup/score dominate) or relaxes the wrong (direction) gate. NOT YET VERIFIED.

### D-04  CONDITION WRONG  P3  - GateClassify/MBEGKeyOf file direction refusals and hard blocks as "score"
- 14:2146 `if(StringFind(why, "score") >= 0) return GATE_SCORE;` ; 14:4493 `reason = "score not passed";` (also for
  SCORE_DECISION_HARD_BLOCK) ; 26c:205-206 `if(g == GATE_SCORE) return EG_SCORE;`
- Cause: clarity / failed-break / old-level / HTF refusals ("score %d, ...") and every HARD_BLOCK (chaos, stale
  tick, extreme spread, counter-impulse, blow-off) are shadowed as "score" and fed to EG_SCORE.
- Effect: the "score" CSV row (817) mixes 6+ gates; the evidence that decides whether the score may stand aside is
  computed on a population the skip never applies to (skip only acts on WAIT). Location-guard chase/tip/impulse
  refusals land in "other" (no keyword). Repro: compare DecisionLog HOLD lines with the shadow gate column.

### D-05  CONFLICT (order)  P3  - market-state gates run after score/location, so refusals are misattributed
- Order 14:4491 score -> 14:4521 LG -> ... 14:4630 calendar -> 14:4674 velocity -> 14:4681 drift.
- Effect: during a news window / spike, a setup that fails score is recorded as "score" (and EG_SCORE gets a
  news-time sample; MBEGFeed 26c:213 has no market filter while MBEGSkip refuses in abnormal market 26c:175) -
  the evidence population differs from the decision population; reason logs hide the calendar block.
  Repro: `[SIRUS v29 CALENDAR] high-impact window active` while shadow rows in the same minutes are "score".

### D-06  CONDITION WRONG  P3  - a relaxed evidence gate cannot come back on its own data
- 26c:220-236 `MBEGFeed`: for a TAKEN row the mask keys are fed the same outcome that feeds the baseline
  (`G_EG_TK_N[a]++ ... G_EG_N[k][a]++`), and a relaxed key no longer refuses on that side, so N[k] becomes the
  taken subset -> r converges to base; return needs `r > base + EGKeepMargin` (26c:100). Also 14:4413 records the
  EG_SCORE bit before the fast-entry block; if the detector PASS is then vetoed and the brain takes the other
  side (14:4429-4486) the mask still carries EG_SCORE, so a brain trade is booked as a score sample.
- Effect: once a filter stands aside it essentially stays aside (only the 60-min breaker interrupts).

### D-07  CONFLICT  P3  - liquidity ahead is a target in 20c and an obstacle in 20e
- 20c:91 `double lq = MBLqNearestAhead(dir, px, 3);` (the leg's target) vs 20e:167
  `double l = MBLqNearestAhead(dir, px, 1);` inside `MBRoomAhead` (obstacle; class 1 = LOCAL M5).
- Effect (cashback mode): an untaken M5 swing high 0.5 $ above a BUY refuses it as "no room" (need ~557 pts) while
  the late-leg logic treats MAJOR pools as where price is going; V3 (224 pts) is redundant under net edge.
  Repro: `market brain veto: net edge: room ... < 1.2 x (spread ...)` with a pool listed on the liquidity panel.

### D-08  WRONGLY BLOCKS  P2  - neutral-brain FAST RE-ENTRY after a TP is re-checked by HTF cost / LB / LG
- 23:872-885 allows `ra == 0` in cashback tempo with type TREND_RIDE; 14:4163 `MBOwnsGate` returns true for a
  location gate only if aligned or own place (TREND_RIDE is not); 14:4484 stamps `min + MBFastEntryScoreMargin(2)`
  while HTFAgainstScoreExtra=4 (14:4791 `G_SCORE_FINAL < G_SCORE_MIN_REQUIRED + htf_cost`).
- Effect: with bias 0 and HTF force >= ~0.74 against, the re-entry is refused "score X, against HTF"; at the tip of
  the leg after a TP the LG MicroTip / Location Brain also refuse it -> conflicts with "immediate re-entry after a TP".
  NOT YET VERIFIED (bias 0 absent in CSV).

### D-09  CONFLICT  P3  - deadlock pairs B1-B6 (section 4) produce silence with no single gate at fault.

### D-10  CONDITION WRONG  P3  - AdaptDecay's clock is only reset when it decays
- 14:2312-2317:
```
if(ad_last == 0) { ad_last = TimeCurrent(); return; }
if(G_ADAPT_EXTRA > 0.0 && (TimeCurrent() - ad_last) >= 3600)
{  G_ADAPT_EXTRA = MathMax(0.0, G_ADAPT_EXTRA - EvidenceStep); ad_last = TimeCurrent(); }
```
- Effect: after >= 1 h with extra = 0, the first `AdaptRecord` tighten step (+0.04) is removed on the next
  `LocationBrainVerdict` call; the evidence-tightening mostly never acts. Repro: `[SIRUS ADAPT] ... need 0.04 more`
  followed by LB HOLD texts with the old `wants <= 0.65`.

### D-11  CONDITION WRONG  P3  - drift guard is direction-blind and not tied to a queued signal
- 11:2041 `double drift_pts = MathAbs(bid - signal_close) / _Point;` (signal_close = M1 close[1], SignalTF=M1)
- Effect: a BUY offered 0.6 ATR1 BELOW the last close (a better price) is refused like a chase; every detector
  setup on a wide M1 bar is refused although it is not a replay. CSV: drift against-bias 29% bad (n=17) - the
  against-side refusals look protective, the with-bias ones (5.9%) do not; EG_DRIFT may relax only the latter.

### D-12  CONFLICT  P3  - fast entries skip score-cost gates even against the bias
- 14:4163 `if(!location_gate || MBBiasAlign(d) >= 1 || ...) return true;` for G_MB_FAST_ACTIVE, contradicting the
  rule in 21:261 "against the trade -> never". Failed-break / old-level / clarity never see a brain LOCAL or
  SWEEP entry against the bias (they could not pass anyway: stamped score min+2 < min+3 clarity cost).

### D-13  INSUFFICIENT EVIDENCE  P3  - gates that cost trades but not quality (CSV)
- velocity 233 refusals at 6.9% bad, calendar 0/31, risk 3.4%, cooldown 4.7% vs TAKEN 10.4%. With clustering this is
  weak, but no CSV evidence shows these both-side gates protect. 08-Oct alone: 188 velocity rows.

### D-14  RESULT IGNORED / dead code  P4
- Six MBEGSkip sites for non-relaxable keys (20c:350/368/378, 21:528/716/720) and MBShadowValveOn location family
  (14:4150) always return false; VALVE_CLARITY/SCENARIO/FAILEDBREAK unreachable. If EG_ZONEFRONT were ever made
  relaxable, 21:716 would leave V2/V3 text in `why` for a later rule. 22_Memory learning counts never decay.

### D-15  P4 naming
- CSV "location" = Location Brain only; location guard = "zone" or "other"; "bad-day filter" = "other";
  "max daily entry attempts" = "other". Panels reading "location" under-count the location guard.

---------------------------------------------------------------------------------------------------
## 8. Timers (item f) - checked, no wrong-base bug found except D-10
Server-time based and consistent: MinSecondsBetweenEntries (TimeCurrent), velocity hold (TimeCurrent; rate uses
GetTickCount64 only for tick rate - fine), calendar (TimeTradeServer for window, settle per M1 bar), EG breaker,
anomaly, re-entry (20d), second chance, LB stop memory (1 h / 3 ATR5), fresh-break window, spread memory per
server hour. Bar-based: ValveIsOff, location counters, TryLocationRedirect once per bar per side (a failed
redirect is not retried in the same bar - P4). SafetyValveCheck says "once a bar" but runs every tick (no harm).
