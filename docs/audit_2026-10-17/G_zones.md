# G - Zones and levels: sources, consumers, conflicts (round 2)

Auditor G. Code: branch claude/sharp-tesla-dgetgj HEAD 5c348e9 (packages 1-5). I only read the repo; I did not edit it.
Citations are file:line in /home/user/sirus/Sirus. Status words and finding categories come from BRIEF.md.
Typical gold magnitudes used for the examples (GUESS, not measured): ATR(M5) about 1500-2500 pts, ATR(M15) about 3000-4000 pts,
spread about 240 pts, cashback TP about 224 pts.

Runtime evidence: the shadow CSVs (old code, 06-09 Oct) show gate families `zone` 46 rows, `location` 18 rows and
`brainVeto` 528 rows. Their `extra` column is empty, so no zone sub-rule (V2, V3, council 3, counter-zone, 1h, 1g) can be told
apart. Every zone sub-rule below is therefore STATICALLY PRESENT or NOT YET VERIFIED. Only the `zone`/`location` families are
RUNTIME VERIFIED as having fired.

---------------------------------------------------------------------------------------------------------------------------

## 1. Source table - the same price level, eight definitions

| # | Source | Level built from | Width | Role rule | Touch / strength | "Broken" rule | Refresh | Status |
|---|---|---|---|---|---|---|---|---|
| S1 | ZoneMap nearest S/R, 11:3348-3737 | Confirmed swing points (depth 3) on M1 M5 M15 M30 H1 H4 D1. Highs and lows go into SEPARATE lists. Plus raw candle fallback, FVG (M15), PDH/PDL, strong-zone override | Point (no width) | **Fixed by list:** swing HIGH = resistance, swing LOW = support. Position decides only which side counts as "ahead". A level up to ZoneNearAboveTolerance x scale (900 x 0.6-1.8 = 540-1620 pts) behind price is returned when nothing is ahead | ZoneMapStrength 11:4132: 1 + 0.25 x merged high+low swing touches (80 pt tol, all TFs, age-weighted) + reaction + round + FVG + polarity flip + reliability + PDH/PDL. **No upper cap** (long-term exhaustion OFF, 01:5492) | None. Broken swings stay in the list. Price position alone decides | Swing cache per M1 bar (11:3127); answer memo per tick (11:3715) | STATICALLY PRESENT |
| S2 | Zone role engine, 19:127-348 | Any level a consumer passes in (in practice ZoneMap levels) replayed on 576 closed M5 bars | level +/- 0.30 ATR(M5) (19:147) | Origin = which side of the band price was on 2 days ago. Flips only on a genuine break | Band entries (touches), sweeps, rejections | 2 M5 closes beyond the far edge + 0.25 ATR, with the first body >= 0.8 ATR; or 4 grind closes (19:183-212, 229-239) | Per M5 bar (19:362) | STATICALLY PRESENT |
| S3 | Location-guard zone engine, 14:3342-3595 | Swings (depth LGSwingDepth) on M15 M5 M1 (+M30 H1), react >= 1 ATR(tf). Highs and lows **merged** into clusters | Point on LTF, wick area on M30/H1, clusters merged within 0.5 ATR(M5) | **Positional:** above price = resistance, below = support (14:3470-3473) | Cluster weight (TF weight x react) >= 2.0 | LGBrokenBeyond 14:1502: 1 M5 close beyond edge+0.35 ATR(M5), or 2 M1 closes, or N M1 closes beyond | Per M1 bar | STATICALLY PRESENT, location family RUNTIME VERIFIED |
| S4 | HTF supply/demand, 20g:54-173 | H1/H4 base candle before a displacement of 1.5 ATR(tf) within 3 bars | Base candle body to wick; 0.2-1.5 ATR(tf), so up to about $20-30 on H4 (GUESS on ATR) | supply = against BUY, demand = against SELL | Visits; worn after more than 3 | A close beyond the far side **on the zone's own TF** (20g:91). The block also lifts when the **last** M15 close or live bid is beyond (20g:135-136, 141-142) | Per H1 bar | NOT YET VERIFIED (added 09 Oct) |
| S5 | Lower high / higher low, 20g:176-241 | 24 closed M15 bars: top, pullback >= 0.8 ATR15, then the running max/min after it | Point | blocks BUY under it in the premium half | - | An M5 close or the live bid beyond it | Per M5 bar | NOT YET VERIFIED |
| S6 | Liquidity map, 20a:132-446 | Swings M5/M15/H1/H4 + PDH/PDL, merged within 0.2 ATR15 | Point | side +1 = highs (buy-side), -1 = lows | Touches within 0.1 ATR5, 10 min apart | TAKEN after 2 M5 closes beyond level+pierce (20a:290-293) | Per M5 bar | STATICALLY PRESENT |
| S7 | Live pools (18:815-1128) | M1/M5/M15 swings within 3 ATR5 + key levels | Point | side | - | DONE when the bid pierces and comes back (sweep), or stays through for LiveSweepReclaimSec **seconds** (18:1127) | Tick | STATICALLY PRESENT |
| S8 | Ghost zones, 08:1000-1100 | ZoneMap NearestResistance/Support (swing highs/lows) crossed by 2500 pts each side within 6 M1 bars | Point | broken support = resistance (positional) | ZoneMapStrength | the cross itself | Per bar | STATICALLY PRESENT |
| S9 | Legacy smart S/R, 15:276-344 | M15/H1 swings | Point | by position vs mid | - | - | **Never built at default inputs** (only called from UpdateLegacyUpgradePack, 15:759, and UseLegacyUpgradePack=false, 01:3761) | FAILED (inert) |
| S10 | ZonePriceInsideBand / ZoneBandOnTF, 10:1265 | Swing cache M5/M15/H1 | Band | - | count | - | per call | STATICALLY PRESENT |

**Check (2), the ZoneMapScanTFSupport re-rank (Package 5).** The support scan (11:3386-3422) now mirrors the resistance scan
(11:3348-3384) exactly. Both use the same tolerance from ScaleAdjustedPoints. Equality is handled the same way: `h >= price`
counts as ahead, and `l <= price` counts as below. A level genuinely ahead outranks one behind. When both levels are behind,
the nearer one wins. **It is symmetric and correct within the scan.** The only difference is cosmetic: the support scan computes
`l_tol` inside the loop (11:3403), and the resistance scan computes it once (11:3367). That costs one extra call per level, but
the value is cached per bar (07:83-94). The round-1 B guess ("V3 for a SELL sees its support overhead -> no room") is fixed for
the ordinary case. It remains only in the "nothing on the far side" case, see G4.
I found no other BUY/SELL asymmetry in S2, S3, S4, S5, the SZR walls, GridZoneAwareDistance, the counter-zone cluster, the FVG
helpers or the strong-zone override. Each was checked branch by branch.

## 2. Consumer map

| Consumer | file:line | Source read | Price | Distance / test | Role-aware? | Touch cap |
|---|---|---|---|---|---|---|
| V2 zone role | 21:175-188 | S1 lean (SELL: res = swing high, BUY: sup = swing low) -> S2 verdict | ask/bid | within 1.5 ATR5 | yes, but only on the type-fixed S1 level | no |
| V3 no room | 21:190-209 | S1 other side -> S2 role, room measured from **band edge** | ask/bid | room < 1.0 x BaseBasketTPPoints | yes | **no** |
| V10 net edge | 20e:157-205 | S1 strictly ahead (role -dir, <4 touches, unknown = obstacle) or S6 pool | **bid** both | room < 1.2 x (spread+slip+TP) to **level** | yes | <4 |
| Council 3 | 21:379-398, 527-540 | S1 -> S2 | ask/bid | level within 0.35 ATR5; released 0.1 ATR beyond; skipped when both sides | yes | <4 |
| Council 1h | 21:430-440, 20g:154 | S4 | bid | inside or within 1 ATR15 | own | own (3) |
| Council 1g | 21:419-429, 20g:217 | S5 | bid | - | - | - |
| Judge zone_ok | 23:275-289 | S1 -> S2 role == dir | ask/bid | within 1 ATR5 | yes | no |
| Judge fvg_ok | 23:311-329 | FVG cache | ask/bid | in gap | - | - |
| Late-leg target 20c | 20c:71-115 | DR/H4/regime box, S7 (not done), S6 class>=3 | bid | - | - | - |
| Counter-zone (score HB/arm) | 08:1287-1416 | S1 (MathAbs) + cluster | mid | **3500 pts**, strength >= 1.4 | no | no |
| Score zone caution | 08:2765-2800 | S1 weighted | mid | near/far | no | no |
| Zone-edge arm, second level, etc. | 08:3130-3230 | S1 | mid | - | no | no |
| Wall hard block | 08:6660-6716 | S1 | mid | 250 pts / 2.5 | no | OFF (EnableZoneWallHardBlock=false, 01:5893) |
| Location guard + redirect | 14:4280-4311, 3564, 3765 | S3 | ask/bid | 0.8 ATR5 band | positional | - |
| DTZ / DLP zone dir | 15:2955-3110, 2339 | S9 | close[1] | 850 pts | positional | inert (S9 never built) |
| Entry TP zone cap | 14:1329-1346, 1374-1390 | S1 | entry price | res < tp | no | **inert in cashback** (see G13) |
| Grid reach | 11:4236-4330, called at 13:2072 | S1 from **last order price** | last price | +/- buffer 100 | no | no |
| SZR | 11:4388-4500 | S1 + cascade | bid both | 500 / 250 pts fixed | no | no |
| Grid intelligence / reaction | 13:551, 593, 1550 | S1 | mid/bid | 300 pts etc. | no | no |
| Handoff place / local target | 20:911, 971 | S1 | bid | 0.5 ATR5 | no | - |

---------------------------------------------------------------------------------------------------------------------------

## 3. Findings (ranked)

### G1 - The role engine's flip / sweep rules never see the level that flipped (CONFLICT, P2, can feed P1)
- Where: 11:3348-3384 (`ZoneMapScanTFResistance` reads only `G_ZMC_HIGH_PRICE`), 11:3386-3422 (support reads only
  `G_ZMC_LOW_PRICE`); 21:177 `double lean = (dir < 0) ? res : sup;`; 21:192 `double other = (dir < 0) ? sup : res;`;
  21:386 `double l = (dir > 0) ? ZoneMapNearestResistance(px) : ZoneMapNearestSupport(px);`; 23:278 the same.
- The 19 header (19:11-32) states the engine's purpose: "price dipped a few points under the 4125 support ... SELL taken at
  4126 ... SELL at a zone whose role is still SUPPORT -> not a sell zone; SELL at a broken support -> only after the retest."
  Every consumer gets its level from ZoneMap, and ZoneMap's resistance list holds swing HIGHS only. A swept or broken swing LOW
  that now sits above price is therefore never the "lean" of a SELL. V2, the judge and council 3 ask about the nearest swing
  high instead. The mirror case holds for BUY: a broken swing high now below price is never `sup`.
- Effect:
  - SELL under a swept-but-unbroken support. V2 checks some swing high above, not the support. Council 3 for SELL looks at
    `NearestSupport(bid)`, which is now the next lower low. It also releases once `bid < l - 0.1 ATR5` (21:387). V3 measures
    room to that lower low. So **no zone rule refuses the SELL** while price is below the support intrabar. V1 needs the
    closed-bar sweep event.
  - SELL retesting a broken support from below. The "not yet retested" wait (19:461) never fires, and the judge gives no
    zone credit.
  - BUY: mirrored in both cases.
- Status: STATICALLY PRESENT. Reproduce: a SELL `ENTRY SENT` while the bid sits 0.1-0.5 ATR5 under an M5/M15 swing low that
  the next M5 close reclaims; the reason-code dump (90:208-225) prints "ZONE ABOVE" as a swing high, not the swept low.

### G2 - V3 "no room" is the strictest room rule, measured from the band edge, with no fatigue cap and no both-sides escape (WRONGLY BLOCKS, P2)
- Where: 21:196-200
  ```
  if(MBZoneRead(other, z) && !z.pending_break && ((dir < 0 && z.role > 0) || (dir > 0 && z.role < 0)))
     double room_pts = (dir < 0) ? (price - z.hi) / _Point : (z.lo - price) / _Point;
     double need_pts = MathMax(1.0, BaseBasketTPPoints()) * MathMax(0.1, MBVetoRoomTPMult);
  ```
  The band is level +/- 0.30 ATR5 (19:147). Compare council 3 (21:394, `z.touches >= 4` excluded, both sides cancel at
  21:531) and net edge (20e:164, `zz.touches < 4`, measured to the level).
- Cause: three rules ask "is there room before the level" with different geometry:
  - V3: band edge + 1 TP, so it blocks when the level is about 0.3 x 2000 + 224 = about 824 pts away (GUESS on ATR).
  - Net edge: 1.2 x (240 + 224) = about 557 pts from the bid to the level.
  - Council 3: 0.35 ATR5, about 700 pts.

  V3 runs first in the chain (21:732), before council 3 (21:749). So:
  - (a) A level 3-4 TPs away blocks a 224-pt scalp.
  - (b) A level tested four or more times still blocks through V3, although council 3 and net edge treat it as "wearing
    out - breakout risk, not a wall" (21:393).
  - (c) In a box with a holding support and a holding resistance each within about $0.8, V3 blocks BUY **and** SELL. This is
    the deadlock that council 3 (CHAIN FIX compression, 21:527-531), the LG (14:3586 SRNeverBlockBoth) and 1h (20g:163) were
    each changed to avoid.
- Effect: silence in Asia chop. The compression escape exists in council 3, which V3 sits ahead of, so that escape is dead.
- Reproduce: `V3 no room: SUPPORT x holds N pts away` for SELLs and `V3 no room: RESISTANCE y` for BUYs inside the same M1
  bar range.

### G3 - "Nearest" support/resistance is not the nearest: the strong-zone override swaps it for a level up to $20 away in every brain room check (CONFLICT, P2/P3)
- Where: 11:3471-3481 and 11:3686-3697. With `EnableStrongZoneOverride=true` (01:4092), `StrongZoneSearchPoints=20000`
  and `StrongZoneMinScoreRatio=1.25`:
  `if(strong_price > 0.0 && strong_price > best) { ... if(near_score > 0.0 && strong_str >= near_score * StrongZoneMinScoreRatio) best = strong_price; }`
  It is applied whenever `G_ZONE_LOOKUP_BUSY` is false, which covers V2, V3, council 3, net edge, the judge, the counter-zone,
  the TP cap, grid reach and SZR. Only HasSupportingLevelBehind switches it off (08:1249-1254, "FIX(lean-displaced-by-strong-override)").
- Cause: a one-touch M5 swing 200 pts ahead (strength about 1.25) is replaced by an H1 level 1500 pts ahead with strength
  >= 1.56. V3 then measures 1500 pts of "room", council 3 sees no zone in front, and net edge measures to the far level
  (unless a liquidity pool is nearer). The obstacle that actually decides a 224-pt TP disappears. The override was written for
  "where price will react" (grid, SZR). The room checks ask a different question, and the file already fixed the same inversion
  for one consumer only.
- Effect: entries into a minor wall pass every room rule; the near level is invisible. Severity depends on how often a 1.25x
  stronger level sits within $20, which is very often with seven TFs. That part is a GUESS.
- Reproduce: council `holds right in front` never printed while an M5 swing 0.2 ATR5 ahead is visible on the chart; the
  dump's "ZONE ABOVE" is a far H1/H4 level.

### G4 - When nothing is on the far side, both scans return a level behind price and mask the PDH/PDL/FVG/raw fallbacks; V3 then blocks breakout BUYs at new highs (SELLs at new lows) (WRONGLY BLOCKS + SIGNAL LOST, P2)
- Where: 11:3368-3383 accept `h >= price - h_tol` and keep a behind level when nothing is ahead. Then the fallbacks all compare
  against that `best`:
  - raw: 11:3446 `if(best == 0.0) best = ZoneMapRawNearestResistance(price);`
  - FVG: 11:3453 `fvg < best`
  - PDH: 11:3465 `G_PDH < best`

  A real level ahead never beats a behind `best`, so the PDH or bearish FVG overhead is dropped. The mirror is in
  11:3663/3669/3679 for support. The override only rescues it when the level ahead is >= 1.25x stronger (11:3476).
- Effect: at a breakout to a new high in all seven lookbacks (D1 = 120 days; gold ATH runs):
  - The resistance just broken comes back as `res`. MBZoneRead keeps it RESISTANCE until 2 displacement closes beyond
    level + 0.55 ATR5. V3 computes `room_pts = (z.lo - price)` < 0, so **with-trend BUY is blocked** ("V3 no room ... 0 pts")
    for the first M5 bars after the break.
  - Council 3 has already released (21:387).
  - The counter-zone uses `MathAbs(mid_cc - zone_cc)` (08:1327), so it reads the same behind level as "BUY into strong
    resistance".

  Mirror: SELL at 6-month lows. Severity P2, but limited to range extremes on all TFs.
- Reproduce: a new ATH, then `V3 no room: RESISTANCE <the just-broken high> holds 0 pts away` printed while the ask is above
  that high.

### G5 - Counter-zone hard block: 3500-point window, strength >= 1.4, no "never both" escape; its input note claims thresholds it does not use (WRONGLY BLOCKS / late entry, P2)
- Where:
  - 08:1311-1330: `zone_cc` (S1), `dist_cc = MathAbs(mid_cc - zone_cc)`, `single_wall = dist_cc <= CounterZoneBlockPoints && str_cc >= CounterZoneBlockMinStrength`.
  - Inputs 01:5911-5913: `CounterZoneBlockPoints = 3500`, `CounterZoneBlockMinStrength = 1.4`. CounterZoneHardBlock=true (01:6417).
  - The wall arm waits up to SetupArmZoneWaitBars=8 M1 bars for an M1 close **beyond** the wall (06:1805-1812). If the wait
    expires, the rule gives a -5 penalty for 20 bars (08:1400-1415, 01:4868, 6419) and then arms again.
  - 01:5892 says the old wall hard block's rule "now lives in CounterContextBlockNow() with identical thresholds (250pt /
    strength 2.5)". The thresholds actually used are 3500 / 1.4, so the window is 14x wider and the strength bar is a
    two-touch level.
- Effect:
  - Any first entry with a two-touch opposing swing within $3.5 must see price clear that swing within 8 minutes. For a
    224-pt scalp that means waiting for a $1-3 move in its own direction first, so the entry is late (P2).
  - Otherwise it pays -5 against a MinScore of about 4.
  - BUY and SELL can both be affected at once. Only one arm exists at a time, so this is a rotating hold, not a true deadlock.
  - It is the widest of the 7+ rules that refuse the same level (see G10).
- Status: STATICALLY PRESENT. It may be part of the RUNTIME VERIFIED `score`/`zone` families; the CSV cannot tell.
- Reproduce: `[SIRUS v194 ARMED] ... strong resistance at X - waiting for price to clear it` with X 1000-3500 pts away,
  followed by `dropped after 8/8 bars`.

### G6 - HTF zone release is not sticky: break-and-retest BUY above an H4 supply is refused on the retest (WRONGLY BLOCKS, P2)
- Where: 20g:89-97 marks a zone broken only by a close beyond on the zone's **own** TF (an H4 close for H4 zones), and the list
  is rebuilt once per H1 bar (20g:110-116). Between rebuilds, 20g:135-136:
  ```
  if(c15 > G_HZ_HI[k]) continue;   // already closed above it - taken out
  if(px > G_HZ_HI[k]) continue;
  ```
  Only the LAST closed M15 bar and the live bid release it.
- Effect: price closes an M15 bar above an H4 supply (the 20g header and CHANGELOG call this the release), then dips back into
  the top of the zone on the next M15 close. That is the textbook retest BUY. The zone is "fresh" again and council 1h refuses
  the BUY until an H4 bar closes above. The mirror applies to SELL below an H4 demand. The S2 role engine would call the same
  level BROKEN after 2 M5 closes, so the two sources disagree.
- Status: NOT YET VERIFIED (no runtime data for 20g).
- Reproduce: `council: inside the H4 supply zone ... no BUY until an M15 close above it` printed after an M15 close above that
  zone's high in the same H4 bar.

### G7 - Four or more incompatible "broken" and "touch" definitions for one level (CONFLICT, P3)
- Broken:
  - S2: 2 M5 closes beyond edge + 0.25 ATR5 with a 0.8 ATR body, or 4 grind closes.
  - Council 3: one M5 close 0.1 ATR5 beyond the level (21:390).
  - S3: 1 M5 close beyond edge + 0.35 ATR5, or 2 M1 closes (14:1504-1509).
  - S4: an own-TF close, or the last M15 close (G6).
  - S6: 2 M5 closes beyond level + pierce (20a:290).
  - S7: seconds beyond (18:1127).
  - S8: 2500 pts each side.
- Touches:
  - Council 3 / net edge: S2 band entries >= 4 = "wearing out" (21:393, 20e:164).
  - ZoneMapStrength: more touches always means stronger, with no cap because long-term exhaustion is OFF (01:5492). The
    counter-zone, score caution and grid reach therefore treat the same 5-touch level as the strongest wall.
  - S4: worn after more than 3 own-TF visits.
- Concrete conflict: one M5 close 0.2 ATR5 above resistance R. Council 3 and the LG release R. S6 marks it PARTIAL, then
  TAKEN on the 2nd close, which drops it from net edge and makes it a 20c "spent" target. S2 still says RESISTANCE (not even
  pending), so V2 treats it as holding and V3 does too if R is still `res` (G4). Meanwhile the counter-zone keeps arming
  against it by strength.

### G8 - Wall-arm confirmation contradicts its own comment: a trigger already behind price CONFIRMS instead of being dropped (CONDITION WRONG, P3)
- Where: 06:1801-1808
  ```
  // ... If the trigger is already behind us the "cleared" test is satisfied on the very next close ...
  // Treat that as a bad arm and drop it.
  bool still_ahead = (G_ARM_DIR > 0) ? (G_ARM_TRIGGER > c) : (G_ARM_TRIGGER < c);
  bool cleared = still_ahead ? false : ((G_ARM_DIR > 0) ? (c > G_ARM_TRIGGER + wall_buf) : (c < G_ARM_TRIGGER - wall_buf));
  if(cleared) { ...; return true; }
  ```
  When the trigger is behind, `still_ahead` is false and the normal "cleared" test runs and succeeds. Nothing is dropped. This
  is exactly the G4 case: the counter-zone arms on a behind level via MathAbs (08:1327, 1377), and the arm then confirms with
  its score bonus and `skip_counter_zone`.

### G9 - Location-guard positional roles plus redirect can flip a swept-support BUY into a SELL (CONFLICT, P2; P1 path is a GUESS)
- Where: 14:3470-3473 (`if(dir > 0) { if(hi <= px) continue; edge = lo; }`: anything above price is "resistance") and
  14:4288-4295 (a level block runs `TryLocationRedirect`).
- During a sweep below support S (bid under S.lo intrabar), the S3 engine reads S as resistance. LGBrokenBeyond for BUY checks
  closes above S.hi, which are false, so the BUY is refused "BUY into resistance zone". TryLocationRedirect then evaluates a
  SELL (14:3765-3896). S2 calls S SUPPORT (swept), but per G1 V2 never asks S2 about S. The SELL is checked only by voices,
  LocationBrain, HTF cost, score and the remaining veto layers. The LG runs only when `!MBOwnsGate(true)` (14:4280), i.e.
  detector entries.
- Status: STATICALLY PRESENT; the redirect is NOT YET VERIFIED.
- Reproduce: `[SIRUS LOCATION REDIRECT] BUY blocked at a level -> SELL` with the bid below a swing low that the next M5 close
  reclaims.

### G10 - One level, seven or more refusals (duplication, P3)
A BUY with a two-touch swing high about 600 pts ahead is refused or taxed by all of the following:
1. V3 (21:190)
2. V10 net edge (20e:191)
3. Council 3 (21:531)
4. Counter-zone arm/HB (08:1311)
5. Score near-zone caution (08:2780)
6. Second-level penalty (08:3194)
7. LG zone (14:3453, detector entries)
8. Plus the grid opposing-zone caution (13:593) and DTZ when legacy is enabled

Each uses its own price reference: ask, bid or mid. Spread (about 240) is roughly one TP (about 224), so the same level is a
full TP nearer or farther depending on the rule. Logs blame whichever rule runs first, so tuning one rule changes nothing.

### G11 - Legacy S/R zones are never built at default inputs, so DTZ / DLP zone direction / zone breakout are inert; the DTZ wick test is also bypassed (SIGNAL/DATA LOST, P3)
- Where: `LegacyBuildSmartSRZones()` is called only from `UpdateLegacyUpgradePack` (15:759), which returns early when
  `UseLegacyUpgradePack=false` (01:3761, 15:751-757). As a result, G_LEGACY_NEAREST_SUPPORT/RESIST stay 0, and
  DeepTopZoneTrapDirection (15:2955), DeepZonePressureDirection (15:2339) and DeepZoneBreakoutDirection (15:2920) always return
  0 or "no near zone".
- Latent bug if it is re-enabled: 15:2993 `if(upper_wick >= DeepTrapWickRatio || price <= G_LEGACY_NEAREST_RESIST)`. The
  legacy resistance is by construction above the build-time mid (15:291), so the second clause is nearly always true.
  "Top trap" then becomes "within 850 pts of any resistance": SELL +2 (DeepTrapWithSignalBonus) and BUY -2, a fade bias.
  Mirror at 15:3013.
- The round-1 FIX(top-zone-priority) therefore fixed a function that does not run.

### G12 - Ghost zones read the type-fixed lists and need a $5 move in 6 minutes (CONDITION WRONG, P3)
- Where: 08:1029-1047. "Broken support ... now sits ABOVE price -> nearest resistance". But `ZoneMapNearestResistance` returns
  swing HIGHS only (G1), so the level recorded as an "ex-support" is a swing high price fell through, not the support that
  broke. Each side also needs `GhostZoneBreakPoints = 2500` pts within `GhostZoneCrossLookbackBars = 6` (01:4107, 4129)
  SignalTF=M1 bars. The rule rarely fires, and when it does it often records the wrong level.

### G13 - Smaller items (P3/P4)
- **Entry TP zone cap is inert in cashback mode** (14:1331-1346). The TP equals RebateTargetPoints (14:1222-1226) and
  `min_floor = price + RebateTargetPoints`. Since `capped = res - buffer < res < tp = min_floor`, the condition
  `capped > min_floor` can never hold. This is harmless but dead code. P4.
- **Grid reach / zone-aware distance** (11:4236-4330) uses the support relative to the LAST ORDER price, with no S2 role and
  no "still holds" test. After the current leg has already broken that support, the add is still placed "at" it, so the grid
  adds at a broken level. The clamp at 13:2100-2106 limits the distance but not the logic. The effect is a GUESS: other grid
  confirmations exist. P3.
- **HTF "never both sides"** (20g:165-167) compares the NEAREST zone per side, not the highest-TF zone. With an H1 supply at
  distance 0, an H4 supply 0.5 ATR15 away and an H1 demand, both directions cancel and the H4 supply is ignored. P3.
- **Lower-high rule** (20g:207-212): `lh` is the running max of ALL M15 highs after the pullback, including the latest closed
  bar. It is not a confirmed swing that turned down. In a recovery rally each new M15 high becomes the "lower high", and BUY
  dips stay blocked until within 0.3 ATR15 of the top, unless local leg and M5 pressure are both up (20g:235). This may block
  continuation BUYs in premium; the effect is a GUESS. P3.
- **MBZoneRead cache** (19:369) returns the cached replay of any level within 0.05 ATR5 (about 100 pts), using the cached
  band. P4.
- **Unknown role, three meanings**: net edge treats an unreadable zone as an obstacle (20e:164 `!MBZoneRead(...) ||`), V3 and
  council 3 treat it as no obstacle, and V2 treats it as allow (19:446-450). P4.
- **Stale caches (check 6).** No harmful staleness found:
  - Every consumer pairs the closed-bar S2 role with a live price test (21:387-391).
  - The FVG list is per M15 bar, so a gap filled intrabar still reads "unfilled" for up to 15 min. That is harmless because
    the judge's `in_gap` is a live range test.
  - The S4 rebuild per H1 bar is the G6 issue.

## 4. Answers to the brief's checks
1. Same level, different definitions: yes. See the source table, G1, G7, G9, and S4 vs S2 in G6.
2. BUY/SELL asymmetry: none in the logic. The Package-5 support re-rank is symmetric and correct. The residual "nothing on
   the far side" problem (G4) is symmetric.
3. Role flips after a break: **not applied by any consumer to the flipped level itself** (G1). The ZoneMap lists are
   role-fixed and S3 is purely positional. S8 ghosts try to cover this but read the wrong list (G12).
4. Units and signs:
   - All distances are in points with the correct sign, except MathAbs on levels that can be behind price: counter-zone
     08:1327, wall HB 08:6682 (OFF), grid intel 13:554 (G4/G8).
   - ATR is ATR(14) everywhere: G_MB_ATR comes from ATRPointsManual(tf,14) (17:717), and ATRPeriod=14.
   - Price references are mixed (G10).
   - V3 measures from the band edge while net edge measures from the level (G2).
5. Deadlocks and duplication: V3 blocks both sides in a box (G2). The counter-zone rotates holds (G5). There is 7x
   duplication (G10). The LG, council 3 and 1h each have a "never both" escape; V3 and the counter-zone do not.
6. Stale caches: nothing harmful beyond G6 (S4 per-H1 rebuild with a single-M15-close release).
7. Wrong-direction or blocked correct entries:
   - Wrong-direction risk: G1 (SELL under a swept support not refused by zone rules), and G9 (LG plus redirect, GUESS for the
     full path).
   - Correct entries blocked: G2, G4, G5, G6.
