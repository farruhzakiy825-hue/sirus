//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 01_Inputs                                       |
//| Input parameters (settings window)                               |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

input bool              EnableReasonCode         = true;      // Har ochilgan order (birinchi kirish, grid, scale-in) uchun "nega ochildi" yozuvi: signal, ball, struktura, zonalar, joylashuv, yangilik, qarshi dalillar (CONFLICTS)
input bool              ReasonCodeToFile         = true;      // Shu yozuvni MQL5/Files/Sirus_ReasonCode_<symbol>_<magic>.csv fayliga ham yozadi (tester'da: agent papkasidagi MQL5/Files)
input bool              VerboseLogs              = true;      // FIX(log-noise): master switch for the ~170 "...PrintOnUse" diagnostic logs. false = quiet journal (trades, closes, errors and warnings still print). Each individual PrintOnUse switch still works when this is true.
input group "01 — SIRUS CORE / MODE"
input string            NaviusBuildName          = "SIRUS v31.6 PRO AUTO GRID SAFETY READY";
input string            OrderBrand               = "SIRUS by Zakiy";   // BREND: har order izohining boshi ("SIRUS by Zakiy | TREND", "... | GRID 3")
input ENUM_NAVIUS_MODE  NaviusMode               = NAVIUS_MODE_AUTO;
input long              MagicNumber              = 240007;
input ENUM_NAVIUS_MODE  DefaultAutoMode          = NAVIUS_MODE_BALANCED;
input bool              AllowAutoHighHunter      = true;
input int               ModeSwitchCooldownBars   = 10;
input bool              ModeEvaluateOnNewBarOnly = false;
input int               AutoHighHunterMaxSpread  = 300;
input int               AutoHighHunterMaxTickAge = 60;
input int               AutoBalancedSpreadLimit  = 300;
input bool              EnableAutoHunterMarketFilter = true;   // V31.6z13: AUTO's switch to HIGH_HUNTER previously checked ONLY spread/tick-age - zero market-risk awareness
input double            AutoHunterMinVolatilityRegime = -0.5;  // Blocks the switch to Hunter during extreme volatility storms (VolatilityRegimeScore -1.0=storm, +1.0=normal)
input bool              EnableAutoHunterNewsFilter   = true;   // V31.6z14: was never checked before - being aggressive right as high-impact news hits is a real, independent risk
input bool              EnableAutoHunterHourFilter   = true;   // V31.6z14: consults this hour's own historical Hour-Bayes win rate (already tracked elsewhere, just never used here)
input double            AutoHunterMinHourWinRate     = 0.35;   // Below this historical win rate for the current hour, count it as a concern
input bool              EnableAutoHunterTrendClarityFilter = true; // V31.6z14: uses Trend Quality Score in BOTH directions - a murky, directionless market is less suitable for aggressive mode
input double            AutoHunterMinTrendClarity    = 0.55;   // At least one direction must show this much Trend Quality to count as "clear"
input double            AutoHunterMinSuitabilityScore = 0.6;   // Overall weighted score (6 factors + non-linear consensus) required to allow HIGH_HUNTER
input bool              EnableAutoHunterBasketHealthFilter = true; // V31.6z15: NEW - if an existing basket is already in meaningful drawdown, switching to the MORE aggressive mode is backwards
input double            AutoHunterMaxBasketDDForHunter = 15.0;  // Basket drawdown % above which Hunter mode is discouraged
input double            AutoHunterConsensusPenaltyStep = 0.15;  // V31.6z15: NEW - non-linear extra penalty per concern once 3+ independent concerns fire simultaneously (same philosophy as Grid Intelligence)

input group "02 — LOT / START SETTINGS"
// ============================ QUICK GUIDE (read this first) ============================
// This section sets the FIRST-ENTRY lot (the size of the very first order in a basket).
// The grid/martingale sizes for orders 2,3,4... are set later in the GRID section.
//
//   >>> StartLot  <-- THIS is your first-entry size. Set it and you're done. <<<
//        Every basket's first order opens at exactly this many lots (default 0.25).
//
//   You normally only touch StartLot. The rest here are optional:
//     - UseAutoLot = false  -> always use StartLot (simple, predictable). RECOMMENDED.
//     - UseAutoLot = true   -> ignore StartLot and size the first order from RiskPercent
//                              of balance instead (see the AUTOLOT DETAILS group below).
//     - MaxLot              -> a hard ceiling so the first-entry lot can never exceed it.
//     - MinFirstEntryLotFactor -> keep at 1.0 so a first entry always opens at full
//                              StartLot size or not at all (never a shrunken partial).
//
//   To trade bigger, just raise StartLot (e.g. 0.25 -> 0.50). To trade smaller, lower it.
// ======================================================================================
input double            StartLot                 = 0.25;      // >>> YOUR FIRST-ENTRY LOT (this is the one you set) <<< Every basket's first order opens at this size. Raise to trade bigger, lower to trade smaller. Only used when UseAutoLot = false.
input double            MinFirstEntryLotFactor   = 1.0;       // Keep at 1.0: guarantees a first entry opens at FULL StartLot size or not at all (never a shrunken partial). At 0.6 the stacked lot guards could trim a 0.25 StartLot down to ~0.15 (which showed on the chart). Safe at 1.0 because poor-condition entries are now REJECTED outright by the hard blocks rather than taken at reduced size. Set to 0.6 only if you'd rather have small entries in marginal conditions than no entry.
input bool              UseAutoLot               = false;     // false = always use StartLot (simple, recommended). true = size the first entry from RiskPercent of balance instead (see AUTOLOT DETAILS below).
input double            RiskPercent              = 1.0;       // Only used when UseAutoLot = true: risk this % of balance per first entry to compute the lot.
input double            MaxLot                   = 10.0;      // Hard ceiling: the first-entry lot never exceeds this, no matter what StartLot/AutoLot produce.

// V139: confidence-scaled first entry. Until now every first entry used the same lot regardless of
// how strongly it qualified - a setup scraping past the score bar risked as much as one clearing it
// by a wide margin, and on a martingale it is the marginal entries that turn into deep baskets.
// The floor is high on purpose: this trims a weak entry, it does not halve it. The grid progression
// downstream assumes a first lot near StartLot, so cutting deeper would leave the whole recovery
// ladder underweight.
input bool              EnableConfidenceLot      = true;   // Scale the FIRST ENTRY lot with the entry's score
input int               ConfidenceLotFullScore   = 12;     // Score at which the full lot is used. Below it the lot tapers toward the floor; at or above it, StartLot is used in full.
input double            ConfidenceLotMinFactor   = 0.80;   // Floor as a fraction of the normal lot (0.80 = StartLot 0.25 never goes below 0.20). Raise toward 1.0 to disable the effect gradually.
input bool              ConfidenceLotPrintOnUse  = true;   // Log every trimmed entry so the sizing can be checked

input group "02a — MARGIN GUARD"
input bool              EnableMarginGuard        = true;      // pre-check free margin before any order
input double            MarginGuardMinLevelPct   = 200.0;     // block if projected margin level % would fall below this
input bool              MarginGuardPrintOnUse    = true;

input group "02b — SPREAD LIMIT"
// One master spread cap used by every module (or each module's own individual limit if off).
input bool              UseUnifiedMaxSpread      = true;
input int               UnifiedMaxSpreadPoints   = 500;    // V90b: 300 -> 500 ($0.50). The user's Exness Cent XAUUSD spread runs $0.25-0.40 normally, so 300 ($0.30) was rejecting ordinary fills. $0.50 lets normal spreads through while still blocking the widened spreads around news/session-open. Paired with CriticalSpreadPoints ($0.80) as a two-stage guard.

input group "02c — WEEKEND GUARD"
input bool              EnableWeekendGuard       = true;
input int               WeekendBlockEntryFriHour = 20;    // Friday (server time): block NEW first entries from this hour
input bool              WeekendBlockGridFri      = true;  // also block NEW grid orders in that window (basket manager keeps working)
input bool              WeekendCloseBasketFri    = false; // optionally flat the whole basket before weekend
input int               WeekendCloseFriHour      = 22;    // Friday hour for the optional flat
input bool              WeekendBlockSunEntries   = true;   // Block entries on Sat/Sun (set false to allow weekend-open trading)
input bool              WeekendGuardPrintOnUse   = true;

input group "02d — PUSH NOTIFICATIONS"
// Requires MetaQuotes ID set up in MT5 mobile.
input bool              EnablePushNotifications  = false;
input bool              PushOnEntry              = true;
input bool              PushOnBasketClose        = true;

input group "02d2 — CHART MARKERS / TP-SL LINES (visual only)"
// FEATURE(close-markers): when a basket closes, record WHY it closed and whether it won or lost,
// so it's visible both in the account History (written into each deal's comment) and on the chart
// (a green check for a profitable close, a red cross for a losing one, with a short tag like TRAIL
// / BE / TP / SL / SZR next to it). Purely visual/record - no effect on trading decisions.
input bool              EnableCloseMarkers       = true;    // Draw a chart marker + tag each time a basket closes
input color             CloseMarkerProfitColor   = clrLime; // Colour of a winning close (check mark)
input color             CloseMarkerLossColor     = clrRed;  // Colour of a losing close (cross)
input int               CloseMarkerFontSize      = 10;      // Font size of the tag text next to the marker

// FEATURE(tp-sl-lines): draw the live basket TARGET (TP) and, once trailing is armed, the trailing
// STOP line on the chart. The TP line is derived from the basket AVERAGE price, so it automatically
// moves whenever a new grid order shifts the average - which is exactly the behaviour the static
// per-order TP never showed. The trailing line only appears once trailing is active and then rides
// 300pts (BasketTrailStepPoints) behind the locked profit. Purely visual - no effect on trading.
input bool              EnableTPSLLines          = true;    // Draw basket TP and trailing-SL lines on the chart
input color             TPLineColor              = clrDodgerBlue; // Colour of the basket TP line
input color             TrailSLLineColor         = clrOrange;     // Colour of the trailing-SL line
input int               TPSLLineWidth            = 1;        // Line thickness
input ENUM_LINE_STYLE   TPSLLineStyle            = STYLE_DASH;    // Line style

input group "02e — FRESH-BAR ENTRY CONFIRMATION"
// Only enters near the start of the signal bar, cutting off stale end-of-bar entries.
input bool              EnableFreshBarEntry      = true;
input double            FreshBarMaxPercentOfBar  = 0.0;   // V34b: set to 0 (OFF) on user request - entry allowed at ANY point in the signal bar, not just the first 75%. Removes the "entry deferred to next bar" delay. (Set to e.g. 75 to re-enable the first-N%-of-bar restriction.)
input bool              FreshBarPrintOnUse       = false;

input group "02f — BAYES SCORE LEARNING"
// Learns from its own trade history and nudges the score accordingly.
input bool              EnableBayesScoreAdjust   = true;
input double            BayesScoreGoodWinrate    = 0.60;  // detector winrate >= this -> bonus
input double            BayesScoreBadWinrate     = 0.40;  // detector winrate <= this -> penalty
input int               BayesScoreBonus          = 1;
input int               BayesScorePenalty        = 1;     // symmetric with bonus: frequency-neutral by design

input group "02g — AUTOLOT DETAILS"
// Only used when UseAutoLot=true above.
input bool              AutoLotUseEquity         = false;    // false=balance, true=equity asosida
input double            AutoLotPer1000           = 0.01;     // Lot per $1000 of balance (e.g. $5000 balance -> 0.05 lot)
input bool              AutoLotRiskMode          = false;    // true: RiskPercent + FirstEntrySLPoints dan hisoblash (SL yoqilgan bo'lishi shart)
input bool              AutoLotPrintOnUse        = true;

input group "02h — SELF-DEFENSE THROTTLE"
// After a losing streak, trims lot and raises the score bar. Never increases lot; recovers gradually on wins.
input bool              EnableSelfDefense        = true;
input int               SelfDefenseLossStreak    = 3;        // shuncha ketma-ket zarar basket -> himoya rejimi ON
input double            SelfDefenseLotFactor     = 0.50;     // himoya rejimida first-entry lot x shu faktor
input int               SelfDefenseMinScoreAdd   = 1;        // himoya rejimida min score +shu (sifat talabi oshadi)
input int               SelfDefenseRecoverWins   = 2;        // shuncha foydali basket -> normal rejim
input bool              SelfDefensePrintOnUse    = true;

input group "02j — ATR ADAPTIVE TP"
input bool              EnableATRAdaptiveTP      = true;
input double            ATRTPFactor              = 3.00;   // TP = ATR x this factor
input int               ATRTPMinPoints           = 2500;   // TP floor - trailing manages the exit, TP is a far ceiling
input int               ATRTPMaxPoints           = 6000;   // TP ceiling
input bool              ATRTPPrintOnUse          = false;

input group "02k — ADR (AVERAGE DAILY RANGE) FILTER"
// Penalizes continuation entries once today's range is mostly used up.
input bool              EnableADRFilter          = true;
input int               ADRPeriodDays            = 14;       // o'rtacha kunlik diapazon shu kunlardan
input double            ADRExhaustPercent        = 78.0;    // V121: 92 -> 78. Today's range having eaten this % of the 14-day average daily range means most of the day's move is already behind us. At 92% the filter almost never fired (a day rarely completes 92% of its own average before the EA is done trading), so it contributed nothing to the trend-chasing problem it exists to prevent.     // bugungi diapazon ADR ning shu %iga yetsa
input int               ADRPenalty               = 4;      // V121: 2 -> 4. Entering after most of the day's expected range is spent is a late entry by definition; the remaining room usually cannot cover the target plus a retrace.        // bugungi harakat YO'NALISHIDAGI entrylarga penalti

input group "02l — HOUR-OF-DAY LEARNING"
// Learns which hours tend to win/lose and nudges the score accordingly.
input bool              EnableHourBayes          = true;
input int               HourBayesMinSamples      = 8;        // soat bo'yicha kamida shuncha basket bo'lmaguncha neutral
input double            HourBayesGoodWinrate     = 0.60;
input double            HourBayesBadWinrate      = 0.40;
input int               HourBayesBonus           = 1;
input int               HourBayesPenalty         = 1;

input group "02m — DXY SCORE ADJUST"
// The DXY proxy also nudges the score, on top of its lot effect.
input bool              DXYProxyScoreAdjust      = true;
input int               DXYProxyScoreBonus       = 1;
input int               DXYProxyScorePenalty     = 1;

// ===================================================================================
// FEATURE: SMART SELF-TUNING (added on user request) - three linked systems that use the
// bot's OWN accumulated win/loss history to (1) stop trading detectors that keep losing,
// (2) avoid times of day / days of week that keep losing, and (3) do this WITHOUT blindly
// increasing trade count, which on a martingale system is what blows accounts. Everything
// below is data-driven, needs a real sample size before it acts, and can be fully disabled.
// ===================================================================================
input group "02f2 — SMART: BAYES DETECTOR AUTO-DISABLE"
// If a specific signal type (detector) has a proven-bad win rate over enough closed trades,
// stop taking its signals entirely. This RAISES quality, does not chase more trades. Needs a
// real sample first (BayesMinSamples) so a couple of unlucky losses can't disable a detector.
input bool   EnableBayesAutoDisable       = false;  // V193: OFF. Yigirma namunadan keyin 38% dan past yutuqli detektorni butunlay o'chiradi. Yuqori chastotali scalperда yigirma namuna bir necha soatda to'planadi, va vaqtincha yomon ketgan detektor abadiy o'chib qolishi mumkin - hech qanday tiklanish yo'li yo'q. O'rganish qolsin, avtomatik o'chirish yo'q.
input double BayesAutoDisableWinrate      = 0.38;   // Disable a detector whose shrunk win rate falls to/below this (0.38 = loses ~62% of the time). Keep well below 0.5 so only genuinely bad detectors are cut.
input int    BayesAutoDisableMinSamples   = 20;     // ...but only after at least this many closed trades of that type. Higher than BayesMinSamples: disabling is a stronger action than a lot trim, so it demands more evidence.
input bool   BayesAutoDisablePrintOnUse   = true;

input group "02f3 — SMART: TIME-OF-DAY / DAY-OF-WEEK FILTER"
// Blocks NEW first entries during hours or weekdays this account has a proven-bad record in.
// Manages existing baskets normally - this only gates opening fresh risk at bad times.
input bool   EnableSmartTimeFilter        = true;   // Master switch for the time filter
input bool   TimeFilterUseHour            = true;   // Block entries in proven-bad HOURS
input double TimeFilterHourBadWinrate     = 0.38;   // An hour at/below this shrunk win rate is blocked...
input int    TimeFilterHourMinSamples     = 20;     // ...once it has at least this many closed trades
input bool   TimeFilterUseDayOfWeek       = true;   // Block entries on proven-bad WEEKDAYS
input double TimeFilterDowBadWinrate      = 0.40;   // A weekday at/below this shrunk win rate is blocked...
input int    TimeFilterDowMinSamples      = 15;     // ...once it has at least this many closed trades
input bool   SmartTimeFilterPrintOnUse    = true;

input group "02n — BRAIN PENALTY CAP"
// Caps how much the learning modules together can penalize a signal, so they can't stack up and choke trade frequency.
input int               BrainPenaltyCap          = 12;   // V31.6y: raised from 2 - now correctly captures 7 new penalty sources (was previously bypassed for all of them due to a positioning bug, now fixed)
input bool              EnableSoftBrainPenaltyCap = true; // V31.6z61: this session roughly doubled the penalty sources (26 now). A HARD clip made 12 points and 55 points of penalty score IDENTICALLY, flattening every nuanced penalty built today. Soft cap keeps excess counting at reduced weight instead of discarding it.
input double            BrainPenaltySoftFactor   = 0.35;  // Weight applied to penalty beyond the cap - low enough that the cap still does its job, high enough that "very bad" still outranks "somewhat bad"
input bool              EnableBonusCap           = true;  // V31.6z65: penalties were capped but bonuses were not - and ~8 of the 22 bonus sources all measure the same single fact ("trend agrees"), stacking to ~+16 in any strong trend while every caution signal got compressed. That asymmetry biased the whole system toward chasing extended moves.
input int               BonusCap                 = 12;    // Symmetric with BrainPenaltyCap - beyond this, extra bonus counts at BrainPenaltySoftFactor weight

input group "02o — ENTRY DRIFT GUARD"
// Skips an entry if price has already moved too far from the signal point (Fresh-Bar covers timing, this covers price).
input bool              EnableEntryDriftGuard    = true;
input double            DriftMaxATRFraction      = 0.60;   // ruxsat etilgan uzoqlik = SignalTF ATR x shu
input int               DriftMinPointsFloor      = 300;    // Minimum allowed drift even when ATR is very small
input bool              DriftPrintOnUse          = false;

input group "02p — SMART FILL"
// Briefly waits for a small pullback or tighter spread before sending; always fires by the timeout either way.
input bool              EnableSmartFill          = true;
input int               SmartFillTimeoutSec      = 8;      // V187: 20 -> 8 soniya. V168 da men buni 6 dan 20 ga oshirgandim, chunki "sifatli setup 20 soniyada yo\'qolmaydi" deb hisoblagandim. Bu past chastotali savdo uchun to\'g\'ri, lekin bu bot daqiqalar ichida ishlaydi - har entryga 20 soniya kechikish M1 barning uchdan birini yeydi va narx allaqachon ketgan bo\'ladi. 8 soniya tik portlashi tinchishiga yetadi, ortiqchasi esa fill yaxshilanishidan ko\'ra ko\'proq yo\'qotadi.
input int               SmartFillPullbackPoints  = 120;    // V187: 200 -> 120 ($0.12). Yaxshiroq fill uchun kutishga arziydigan pullback. 200 pts M1 da kamdan-kam bo\'ladi, ya\'ni SmartFill deyarli har doim timeout bilan tugardi - foydasiz kutish.
input int               SmartFillSpreadDipPoints = 80;    // V168: 20 -> 80 ($0.08). Kutishni oqlaydigan spread torayishi. Signal ko\'pincha spread vaqtincha kengaygan paytda keladi, va o\'shanda kirish kengayishni savdoning IKKALA tomonida to\'laydi.
input bool              SmartFillPrintOnUse      = true;

input group "02q — LOT TRACE (DIAGNOSTIC LOG)"
input bool              EnableLotTrace           = true;

input group "02r — TICK-VELOCITY GUARD"
// Detects a sudden price spike from tick speed, even for news not in the calendar.
input bool              EnableTickVelocityGuard  = true;
input double            VelocitySpikeRatio       = 4.0;      // tick tezligi odatdagidan shu barobar oshsa
input int               VelocityMovePoints       = 400;      // VA narx shu oynada shuncha punkt yursa -> spike
input int               VelocityWindowSec        = 5;
input int               VelocityHoldSec          = 30;       // Seconds to pause new entries after a tick-velocity spike
input bool              VelocityPrintOnUse       = true;

input group "02s — ATR REGIME GRID DISTANCE"
// Scales grid distance by current-vs-baseline volatility - both wider and tighter.
input bool              EnableATRRegimeGrid      = true;      // scale grid distance by current-vs-baseline ATR ratio
input int               ATRRegimeBasePeriod      = 100;       // baseline (slow) ATR period on SignalTF
input double            ATRRegimeMinScale        = 0.70;      // quiet market: distance can shrink to 70%
input double            ATRRegimeMaxScale        = 2.00;      // wild market: distance can grow to 200%
input bool              ATRRegimePrintOnUse      = false;

input group "02t — MULTI-TIMEFRAME CONFIRM"
// Bonus when aligned with the higher-TF trend, penalty when against it - never a hard block.
input bool              EnableMTFConfirm         = false;                                       // V55b: OFF. This penalised/bonused on a single H1 read, but H1 is ALREADY one of the four timeframes the EnableMTFAlignment vote counts (2/4=-2, 3/4=-4, 4/4=-6). Keeping both meant the same H1 opinion was charged twice. The vote is the better voice: it is proportional and covers more timeframes.
input ENUM_TIMEFRAMES   MTFConfirmTF             = PERIOD_H1; // higher timeframe for trend check
input int               MTFConfirmMAPeriod       = 50;        // SMA period on the HTF
input int               MTFConfirmBonus          = 2;         // score bonus when entry direction matches HTF trend
input int               MTFConfirmPenalty        = 2;         // score penalty when entry fights HTF trend
input double            MTFNeutralBandATR        = 0.40;      // price within +-(this x HTF ATR) of SMA = neutral, no adjust
input bool              MTFConfirmPrintOnUse     = false;

input group "02u — PERSISTENT STATE / MODE-SPECIFIC LOT"
input bool              EnablePersistentState    = true;      // save Bayes learning + post-loss cooldown in terminal GlobalVariables
input double            LotForBalancedMode       = 0.0;       // 0 = use StartLot
input double            LotForHighHunterMode     = 0.0;       // 0 = use StartLot

input group "03 — SL / LOSS PROTECTION (ALL LIMITS, ONE PLACE)"
// ============================ QUICK GUIDE (read this first) ============================
// There are several loss limits here, but only ONE is your main SL. The rest are backups.
//
//   >>> BasketSLPercent  <-- THIS is your main SL. Set it and you're done. <<<
//        Closes the whole basket when its floating loss = this % of BALANCE.
//        Want to allow a 70% loss before closing? Set BasketSLPercent = 70. That's it.
//
//   Everything else below is an OPTIONAL backup layer, in order of when it acts:
//     1. SmartEarlyExit   - may exit a bit EARLIER than the main SL, but only when many
//                           signals agree the basket won't recover. Main SL still applies.
//     2. DailyLossLimit   - stops trading for the day after the day's total loss cap.
//     3. EquityStop       - whole-ACCOUNT safety (not just this basket).
//     4. EmergencyClose   - last-resort account-equity close.
//     5. EmergencyForceClose - the very last backstop; set just ABOVE your main SL.
//
//   Rule of thumb: set BasketSLPercent to the % loss you can accept, and keep the daily /
//   equity / emergency values equal to or just above it so they only fire if the main SL
//   somehow didn't. You normally never touch anything except BasketSLPercent.
// ======================================================================================
// Every SL / max-DD / loss-limit setting in the whole EA lives here, right after Lot/Start,
// so nothing can silently conflict (we once found 3 forgotten legacy DD blockers scattered
// across other sections, contradicting the limits below).

input bool              UseRiskEngine            = true;     // Master switch for ALL loss protection below. OFF = no SL / no limits at all (dangerous). Keep this ON.
input bool              UseBasketSL              = true;     // The MAIN stop loss. Closes the WHOLE basket when its loss reaches BasketSLPercent of balance. This is your primary SL.
input double            BasketSLPercent          = 50.0;     // [SL CHECKLIST STEP 1] >>> THE MAIN SL (this is the one you set) <<< Closes the basket when floating loss = this % of BALANCE. Example: balance $1000, value 50 => closes at -$500. To allow a 70% loss before closing, set this to 70 (then match the STEP-2 backups below).
input bool              EnableSmartEarlyExit     = false;   // Optional EARLY exit BEFORE the main SL, only when many signals strongly agree the basket won't recover. Cuts some losses short. The main SL above still applies as the final backstop.
input bool              EnableDDWarningPush      = true;    // Send phone/push alerts as the loss grows (does NOT close anything - just warns you). Uses the three thresholds below.
input double            DDWarningThreshold1      = 25.0;    // Send 1st alert when basket loss reaches this % of balance (early heads-up).
input double            DDWarningThreshold2      = 35.0;    // Send 2nd alert at this % (loss is growing).
input double            DDWarningThreshold3      = 45.0;    // Send 3rd/final alert at this % (loss is close to the main SL).
input double            SmartEarlyExitMinDDPercent = 42.0;  // V249fix: 32 -> 42. At 32% this armed BEFORE the last grid rung could be placed (a completed 5-rung ladder peaks at ~33% DD in hunter geometry and ~35% in balanced (and ~41% in the worst case where ATR/session widening drives every gap to the 12000 clamp)), so it could cancel the final rung and realise a ~$3,200 loss on a basket the affordability gate had already budgeted to full depth. It has to sit ABOVE the completed-ladder drawdown and BELOW BasketSLPercent to be an early exit rather than a competing stop. Re-tune if you change MaxOrders, StartLot or LotMultiplier.   // Smart Early Exit won't consider exiting until loss reaches this % (so normal wiggles don't trigger it). Must be below BasketSLPercent.
input int               SmartEarlyExitMinConfirmations = 3; // Smart Early Exit needs at least this many of 4 independent signals to agree before exiting early. Higher = more cautious (exits less often).
input double            SmartEarlyExitGlobalTrendMinAgainst = 0.5; // For Smart Early Exit: the big-picture (D1/H4/H1) trend must be at least this firmly AGAINST the basket (0 = any, 1 = strongest).
input double            SmartEarlyExitReversalConsensusMin = 0.75; // For Smart Early Exit: the reversal signal against the basket must be at least this strong (0-1).
input int               SmartEarlyExitPersistBars = 30;     // V249fix: 3 -> 30. These are CoreBarTF bars, and CoreBarTF is M1 - so "3 bars" was three MINUTES, not the ~45 the design intended. Three minutes of three indicators agreeing was enough to authorise realising the whole basket loss. 30 M1 bars restores a half-hour confirmation window. If you move CoreBarTF to M15, set this back to ~3.   // For Smart Early Exit: condition must hold this many bars in a row (not one noisy tick) before it acts.

input bool              UseDailyLossLimit        = true;     // Stop trading for the rest of the day once the day's total loss hits the cap below.
input double            DailyLossPercent         = 50.0;    // [SL CHECKLIST STEP 2] Daily loss cap as % of balance. Set = BasketSLPercent (e.g. both 70), or a smaller value would close the basket before the main SL.
input double            DailyLossMoney           = 0.0;      // Daily loss cap as a FIXED MONEY amount instead of %. 0 = off (use DailyLossPercent above). Set e.g. 200 to stop the day at -$200 regardless of balance.
input bool              CloseBasketOnDailyLoss   = false;    // When the daily loss cap is hit: also close the open basket (true) or just stop opening new ones (false).

input bool              UseEquityStop            = true;     // Extra safety based on ACCOUNT EQUITY (whole account), not just the one basket.
input double            EquityStopPercent        = 50.0;    // [SL CHECKLIST STEP 2] Trigger when account EQUITY has dropped this % from balance. Set = BasketSLPercent (e.g. 70). A whole-account safety net.
input bool              CloseBasketOnEquityStop  = true;     // When the equity stop fires: close the open basket too (true) or just block new trades (false).

input bool              UseEmergencyClose        = true;     // Last-resort account-equity emergency close, separate from the layers above.
input double            EmergencyDDPercent       = 50.0;    // [SL CHECKLIST STEP 2] Emergency close when account equity DD reaches this %. Set = BasketSLPercent (e.g. 70). A backup for the equity stop.
input bool              EnableEmergencyForceClose = true;   // A second, independent emergency close with minimal dependencies - fires even if the normal close chain somehow fails.
input double            EmergencyForceCloseDDPercent = 52.0; // [SL CHECKLIST STEP 3] The absolute LAST line of defence. Set just ABOVE your main SL (BasketSLPercent 70 => this 72) so it only fires if everything else failed.

input double            MaxBasketMarginPercent   = 60.0;    // Never let the basket's used margin exceed this % of equity (prevents a margin call). Blocks new grid orders once reached.

// V114: margin rescue. When the next grid order's margin doesn't fit, the EA used to refuse and the
// basket froze in drawdown until the SL. Worse, the loop is self-reinforcing: drawdown lowers equity,
// which raises the basket's margin %, which blocks the grid exactly when it is needed. Live example:
// a $50 account with StartLot 0.2 froze at $6 drawdown, while a $100 account with StartLot 0.3 (a
// SMALLER lot-to-balance ratio) added its order and closed in profit. Rescue looks for the largest
// lot that does fit instead of freezing - but only accepts it if it is still big enough to matter.
input bool              EnableGridMarginRescue   = true;    // When the full grid lot won't fit on margin, add the largest lot that does instead of freezing the basket
input double            GridMarginRescueMinFactor = 0.5;    // The rescue lot must be at least this fraction of the intended lot (0.5 = half). Below this an addition takes fresh risk without meaningfully improving break-even, so the block stands.

// V131: a grid addition placed directly on the wall that will push price back is the worst fill in
// the whole basket. The grid already sees opposing zones, but only as a score component - a strong
// enough score still pushes the order through, which is how a SELL got added right on a support the
// chart had respected before. This makes it a timed WAIT instead: recovery is never frozen (the
// wait expires), but the addition happens after the level gives way rather than into it.
input bool              EnableGridZoneWait       = true;   // Delay a grid addition while price sits on the zone that opposes the basket
input int               GridZoneWaitMaxBars      = 20;     // Hard limit on the wait. Once passed, the grid adds anyway - a basket must never be stranded by a zone price is sitting inside.
input double            GridZoneWaitMaxBasketDD  = 12.0;   // Above this basket drawdown %% the wait is skipped entirely and the grid adds immediately. Waiting for a better fill is worthwhile early; once a basket is deep, delaying its averaging is the freeze that margin rescue exists to prevent.
input bool              GridZoneWaitPrintOnUse   = true;   // Log the wait and its expiry

// V137: structure-based grid placement. A grid order stepped a fixed distance lands wherever the
// arithmetic points - possibly into empty space, possibly onto the very level that will push price
// back against the basket. An addition should sit AT a level that works FOR the basket (resistance
// above a SELL, support below a BUY), because the bounce from there is what carries the basket back
// toward break-even. These settings let the computed distance be pulled to such a level.
input bool              EnableGridZoneReach      = true;   // Let a grid add reach slightly FURTHER to land on a strong level, instead of firing short of it into empty space. (Pulling the add IN toward a nearer zone was already handled by EnableZoneMapGridAwareness.)
input double            GridZoneSnapMaxFactor    = 1.5;    // Ceiling on that reach, as a multiple of the computed distance. 1.5 = may wait up to 50% longer to land on the level; recovery is never pushed further than that.
input double            GridZoneStrongLevel      = 2.5;    // V137b: strength at which a level counts as STRONG enough to be worth waiting longer for. Zone strength now includes rejection quality, so one violent bounce can reach this on its own.
input double            GridZoneStrongSnapFactor = 2.0;    // Reach allowance for those strong levels (2.0 = may wait up to twice the computed distance to land on it). Ordinary levels keep GridZoneSnapMaxFactor.
input bool              GridZoneReachPrintOnUse  = true;   // Log every reach so the placement can be checked against the chart
input bool              GridMarginRescuePrintOnUse = true;  // Log rescues AND frozen-grid blocks - this is the diagnostic that shows an account/lot-size mismatch

input bool              UsePostLossCooldown      = true;     // After a LOSING basket closes, wait before opening a new one (stops revenge-trading straight back in).
input double            TrivialLossPctOfBalance  = 0.50;   // BOSQICH 10: 0.10 -> 0.50. Savat zarari balansning shu %idan KICHIK bo'lsa - "nolga yaqin" yopilish, zarar emas (pauza, +3 ball, zarar seriyasi, zarar joyi xotirasi, o'rganish - hech biri ishlamaydi). Balans 317 da: 0.10% = 0.32 (faqat slippage), 0.50% = 1.59 (break-even atrofidagi yopilishlar). Haqiqiy zararlar (grid chuqurlashib, SL ga yaqin yopilish) bundan ancha katta. 0 = eski xulq
input int               PostLossCooldownMinutes  = 5;      // V187: 30 -> 5 daqiqa. Zarardan keyingi pauza bitta zarar keyingisiga sabab bo'lishini oldini olish uchun - narx hali harakatda, sharoit hali o'sha, va darrov qayta kirish ko'pincha bir xil xatoni takrorlaydi. Besh daqiqa buni ushlaydi. O'ttiz daqiqa esa boshqa narsa: kuniga besh zarar bilan bu ikki yarim soat to'xtash, ya'ni yuqori chastotali scalperning yarim sessiyasi. Zararlar bu strategiyada normal - ular statistikaning bir qismi, jazo emas.
input int               MaxDailyEntryAttempts    = 600;      // Safety cap: max new-basket attempts per day (stops runaway looping). 200 is generous for normal use.
input int               MaxDailyGridAttempts     = 200;      // Safety cap: max grid-add attempts per day.
input int               RiskMaxSpreadPoints      = 300;      // Risk-engine spread ceiling (points). Note: with UseUnifiedMaxSpread ON, the unified spread value overrides this everywhere.
input bool              RiskBlockNewEntry        = true;     // When any risk limit is hit, block NEW first entries.
input bool              RiskBlockGrid            = true;     // When any risk limit is hit, block GRID additions too.
input bool              UseFirstEntrySL          = false;    // Put an individual SL on the FIRST entry only. Rarely used with a basket system - the Basket SL above is the real protection.
input int               FirstEntrySLPoints       = 0;        // Size of that first-entry SL in points. On this 3-digit broker 1000 points = $1. 0 = no individual SL.

// --- Secondary DD thresholds - each INACTIVE by default. Shown together here so a value
// is easy to find if you ever want to re-arm one, and won't silently fight the limits above. ---
input bool              GridSafetyBlockDDRisk    = false;   // OFF = grid spacing is distance-only (recommended). ON = also block grid by DD risk (can leave a basket stuck).
input double            GridSafetyMaxDDForNewGrid = 14.0;    // If GridSafetyBlockDDRisk is ON: stop adding EARLY grid orders once DD passes this %.
input double            RecoveryMaxDDForNewGrid  = 50.0;    // [SL CHECKLIST STEP 2] Stop adding grid orders (3+ orders in) once basket DD passes this %. Set = BasketSLPercent (e.g. 70) so grid stops right at the SL.
input bool              UseServerDisasterSL      = false;   // OFF - redundant with EmergencyDDPercent above. A backup broker-side disaster stop.
input double            ServerDisasterDDPercent  = 35.0;    // If UseServerDisasterSL is ON: its trigger DD %.
input bool              P4MiniBlockGridAboveProfileDD = false; // OFF = grid stays distance-only. (P4-mini profile-specific DD grid block.)
input double            P4MiniConservativeMaxDD  = 10.0;    // Only used if P4MiniBlockGridAboveProfileDD is ON (it's OFF by default): grid-stop DD % for the Conservative profile.
input double            P4MiniBalancedMaxDD      = 18.0;    // Only used if P4MiniBlockGridAboveProfileDD is ON: grid-stop DD % for the Balanced profile.
input double            P4MiniAggressiveMaxDD    = 25.0;    // Only used if P4MiniBlockGridAboveProfileDD is ON: grid-stop DD % for the Aggressive profile.

// --- Soft caution only (lot/distance trim, never blocks or closes) ---
input double            ClientSafetyDDWarnPercent = 10.0;
input double            ClientSafetyDDDangerPercent = 16.0;

input group "04 — TP / PROFIT SETTINGS"
input bool              UseFixedTP               = true;      // Use FixedTPPoints as the base TP instead of UseBasketTP below
input int               FixedTPPoints            = 2500;      // Base TP (points) when UseFixedTP=true
input bool              UseBasketTP              = true;      // Use BasketTPPoints as the base TP when UseFixedTP=false
// ---------------------------------------------------------------------------
// V277: REBATE MODE. The broker pays per lot traded, which changes what a trade is for. Normally a
// basket has to reach a target worth taking; in rebate mode the target IS the cost of entering - the
// basket opens down by the spread, waits for price to give that back, and closes at zero. The trade
// earns nothing; the rebate earns everything.
//
// Everything else is unchanged - the same filters, the same grid rules, the same protections. A
// basket that goes wrong here goes wrong by exactly the same amount, and the rebate does not cover
// losses. It covers the spread on the trades that work.
//
// Run both from one file: two charts, two magic numbers, this switch set differently. A separate
// copy would need every fix applied twice and would drift apart within a month.
// ---------------------------------------------------------------------------
input bool   EnableRebateMode            = false;  // Close at break-even and collect the rebate instead of chasing a target
input double RebateSpreadMultiple        = 0.60;   // BOSQICH 3: 1.15 -> 0.60. Cashback TP = spread x shu + margin. TP kirish narxidan o'lchanadi, ya'ni TP ga yetganda butun TP - foyda; spread foydadan ayirilmaydi, faqat narx yurishi kerak bo'lgan masofani oshiradi. Grid qadamiga ta'sir yo'q - u baribir AutoGridMinDistance ($5.50/$6.00) bilan cheklanadi
input int    RebateTPMarginPoints        = 80;     // BOSQICH 3: 300 -> 80 ($0.08). Exness Cent da komissiya yo'q - bu qism sof foyda edi, xarajat emas. Spread 260 da TP: 599 -> 236 point
input int    RebateTPMaxSpreadPoints     = 350;    // S-FIX: spread above which the target stops growing. A target built from the spread moves furthest away exactly when it is hardest to reach - during a release the spread can run six times normal and the basket is asked for a move it was never sized for. The spread is an entry cost, not a measure of how far price will travel.
input bool   RebateTPCapPrintOnUse       = true;   // Log when the target is held
input double RebateGridSpacingMultiple   = 3.0;
// ---- BOSQICH 17: CASHBACK REJIMINI KUCHAYTIRISH ----
input bool   RebateDisableTrailing    = true;   // Cashback rejimida savat trailingi o'chadi. Sabab: trailing qadami (300 pt) va qulfi (2000 pt) cashback TP sidan (~236 pt) KATTA - u TP ga xalaqit beradi va savatni keraksiz ushlab turadi
input bool   EnableRebateTrailing     = true;   // Cashback: savat TP ga yetganda darhol yopilmaydi - trailing'ga o'tadi. Narx qaytsa kamida qulf (TP x LockFraction) bilan yopiladi, davom etsa foyda o'sadi. Shu rejimda birinchi kirishga broker TP qo'yilmaydi (u trailing'dan oldin yopib qo'yardi)
input double RebateTrailLockFraction  = 0.75;   // Qulf = TP x shu. TP ga yetgandan keyin savat kamida shuncha foyda bilan yopiladi (0.10-0.95)
input double RebateTrailStepFraction  = 0.50;   // Kuzatish masofasi = TP x shu: cho'qqidan shuncha qaytsa savat yopiladi
input int    RebateTrailMinStepPoints = 120;    // Kuzatish masofasi bundan kichik bo'lmaydi (3 xonali: 120 = $0.12)
input bool   EnableBrokerTrailSL      = true;   // Trailing qulfi brokerga REAL stop-loss sifatida yoziladi (faqat savat foydada bo'lganda). VPS/terminal uzilsa ham foyda saqlanadi. Zarardagi grid'ga SL qo'yilmaydi
input int    BrokerTrailMinMovePoints = 20;     // Broker SL kamida shuncha punkt yaxshilansa yangilanadi
input int    BrokerTrailMinIntervalSec = 2;     // Broker SL yangilanishlari orasidagi minimal soniya
input bool   BrokerTrailPrintOnUse    = true;
input bool   RebateTimeFlat           = true;   // Savat juda uzoq ochiq qolsa va MINUSDA bo'lmasa - yopiladi. Maqsad: joyni bo'shatish, keyingi savat -> ko'proq aylanma -> ko'proq cashback
input int    RebateMaxBasketBars      = 25;     // Shuncha M1 bar (daqiqa) dan keyin
input double RebateTimeFlatMinProfit  = 0.0;    // Faqat foyda shundan katta yoki teng bo'lsa yopiladi (0 = nolga teng ham bo'ladi). MINUSDA HECH QACHON yopmaydi    // V286: grid spacing as a multiple of the rebate target. The ordinary spacing is sized for a $2.50 target; against a break-even target it would ask price to give back several times what the basket is trying to recover. Three keeps the ladder proportionate to its own target.

input int               BasketTPPoints           = 2500;      // Base TP (points) when UseFixedTP=false
// V31.6e cleanup: removed UseAdaptiveTP - was dead, and redundant with EnableATRAdaptiveTP anyway.
input bool              UseIndividualTPForFirstEntry = true;
input double            TPScale                  = 0.85;   // v291a: barcha TP larni shu nisbatda kichraytirish (0.85 = 15% kichik, 1.0 = o'zgarishsiz). Savat va birinchi kirish TP si, pol ham. Cashback rejimiga ta'sir qilmaydi
input int               FirstEntryTPMinPoints    = 2000;
// ============================================================================
// v291b: JOY HIMOYASI - alohida blok. Motorga (signal, ball, kutish, grid, risk) TEGMAYDI.
// Faqat birinchi kirishning oxirgi darvozasida (FirstEntryCanRun) bitta savol: joy ahmoqonami?
//   - SELL ko'p marta qaytargan support'ning shundoq ustida / BUY resistance'ning ostida
//   - yangi katta impuls shamining tanasi ichida, unga qarshi kirish
// Teskari yo'nalish har doim ochiq. Grid qo'shishlariga ta'sir qilmaydi.
// ============================================================================
input bool   EnableLocationGuard     = true;   // Joy himoyasi: supportda SELL, resistance da BUY, yangi impuls ichida qarshi kirish yo'q
input int    LGLookbackM5            = 96;     // M5 shamlar (8 soat)
input int    LGLookbackM15           = 96;     // M15 shamlar (24 soat)
input int    LGMinRejections         = 3;      // Shuncha ALOHIDA qaytish - kuchli daraja (katta qaytish 2 ga teng)
input int    LGConfluenceRejections  = 2;      // Zona xaritasi ham tasdiqlasa shuncha yetarli
input double LGStrongBounceATR       = 1.5;    // Shuncha ATR qaytish - "katta" (ikki hisoblanadi)
input double LGTouchATR              = 0.35;   // Tegish toleransi (ATR)
input double LGSeparationATR         = 0.8;    // Ikki qaytish orasida narx shuncha uzoqlashishi kerak
input double LGMinWickATR            = 0.25;   // Rad etish soyasi kamida shuncha ATR
input double LGWickShare             = 0.40;   // Soya shamning kamida shuncha qismi
input double LGMaxDistATR            = 1.0;    // "Shundoq yonida": daraja narxdan shuncha M5 ATR ichida VA TP yo'lida
input double LGOnLevelATR            = 0.30;   // Darajaning ustida - TP dan qat'i nazar
input double LGPierceATR             = 0.5;    // Soya bilan teshish (yopilishsiz) shu chuqurlikkacha - daraja hali tirik
input bool   LGUseFreshImpulse       = true;   // Yangi impuls tanasi ichida qarshi kirish yo'q
input int    LGImpulseLookbackM5     = 6;      // Impuls "yangi" hisoblanadigan vaqt (M5, 30 daqiqa)
input double LGImpulseRangeATR       = 2.0;    // Impuls sham diapazoni kamida shuncha ATR
input double LGImpulseBodyShare      = 0.60;   // Impuls sham tanasi kamida shuncha qism
input bool   LGSwingGuard            = true;   // M5 va M15 dagi SWING HIGH = resistance, SWING LOW = support. Uning ostida (zona ichida) BUY, ustida SELL yo'q - tegishlar soni va TP dan qat'i nazar
input int    LGSwingDepth            = 3;      // Swing: har ikki tomonda shuncha sham undan past (high) / baland (low)
input int    LGSwingLookM15          = 200;    // S-FIX: 48 -> 200. Forty-eight M15 bars is twelve hours - the zones price reacted to this morning and nothing from yesterday. M15 is where the clean zones are drawn, and two days of them is what makes them worth reading. The build is cached per bar and the array already holds four hundred, so this costs one scan a bar and no memory.     // M15 shamlar (12 soat)
input int    LGSwingLookM5           = 120;    // S-FIX: 48 -> 120. Ten hours of M5 rather than four - enough to hold the session's own structure.     // M5 shamlar (4 soat)
input double LGSwingBandATR          = 0.8;
input bool   LGSwingUseM1            = true;   // BOSQICH 6: M1 swinglar ham zona - narx M1 zonalardan ham reaksiya oladi
input int    LGSwingLookM1           = 60;     // M1 shamlar (1 soat)
input double LGSwingMinReactATR      = 1.0;
input int    LGHoldBeyondBarsM1      = 2;      // BOSQICH 11: 3 -> 2 (siz sinab ko'rgan qiymat)
// ---- BOSQICH 11: ZONA DVIGATELI ----
input bool   ZoneEngineOn            = true;   // Darajalar klasterlanib HUDUD bo'ladi; rol (support/resistance) narxning qaysi tomonida ekaniga qarab aniqlanadi
input double ZoneClusterATR          = 0.50;   // Bir-biridan shu M5 ATR ichidagi darajalar bitta hudud
input double ZoneBandATR             = 0.80;   // Hudud chetidan shu masofada - "hudud yonida"
input double ZoneMinWeight           = 2.0;    // Hudud vazni shundan kam bo'lsa - to'siq emas (vazn: reaksiya kuchi + daraja soni + TF)
input bool   ZoneLogOnUse            = false;  // Hududlarni logga yozish (diagnostika)
// ---- BOSQICH 18: KATTA TF HUDUDLARI ----
input bool   ZoneUseHTF               = true;   // M30 va H1 swinglari ham hudud beradi. Ilgari dvigatel M15 gacha qarardi - shuning uchun H1 dagi 4291-4300 kabi hudud ko'rinmasdi
input int    ZoneLookM30              = 96;    // S-FIX: 48 -> 96. Two days of M30.     // M30 shamlar (24 soat)
input int    ZoneLookH1               = 120;    // S-FIX: 48 -> 120. Five days of H1 - the level that ends an intraday move is usually drawn here.     // H1 shamlar (48 soat)
input bool   ZoneWickArea             = true;   // Katta TF da daraja NUQTA emas, HUDUD: shamning soya maydoni (low..tana pastki qismi / tana yuqori qismi..high) - treyder chizganidek
input double ZoneHTFWeightH1          = 2.0;    // H1 darajasi vazni
input double ZoneHTFWeightM30         = 1.7;
input double ZoneInsideBlockShare     = 0.60;   // BOSQICH 19: hududning FAQAT kirish tomonidagi shu qismi to'sadi. Support hududiga yuqoridan kelgan SELL uchun eng xavfli joy - hududning yuqori qismi (xaridorlar shu yerda). Narx hududning pastki qismiga yetgan bo'lsa, u xaridorlarni allaqachon singdirgan - davom etish ochiq. 1.0 = butun hudud to'sadi (eski xulq)    // M30 darajasi vazni  // Hududlarni logga yozish (diagnostika)

//--- LOCATION BRAIN -------------------------------------------------------------------
// The zone engine answers "is there a level in the way" - a question about price. The two stops
// that cost the account were not about price: a SELL at the bottom of a four-dollar fall is wrong
// even with no level anywhere near it, because price turns there from being stretched, not from
// meeting something. Nothing was asking WHEN - only WHERE.
//
// Asked last, after every other gate. Nothing is refused; it is held, and the arming engine
// releases it when price comes to somewhere worth paying.
input bool   EnableLocationBrain         = true;   // The last word before an entry opens
input ENUM_TIMEFRAMES LBTimeframe        = PERIOD_M5;   // Where the leg is measured
input int    LBMaxLegBars                = 40;     // Furthest back a leg can start
input int    LBLegSettleBars             = 4;      // Bars without a new extreme that end the leg. Not a fixed window - a fixed one makes a falling market read as permanently at the bottom and the robot stops trading for hours.
input double LBMinLegATR                 = 1.2;    // Leg size below which position means nothing
input double LBSellMinPosition           = 0.35;   // A SELL wants to be at least this far up the leg
input double LBBuyMaxPosition            = 0.65;   // A BUY wants to be at most this far up it
input double LBStretchFromATR            = 3.0;    // Leg length where the demand starts rising
input double LBStretchFullATR            = 6.0;    // And where the extra demand is complete
input double LBStretchExtra              = 0.20;   // How much further into the leg a stretched move must pull back before it is worth joining
input bool   LBBlockWorseThanStop        = true;   // After a stop, the next trade that way must beat the price that failed
input int    LBBetterThanStopPoints      = 800;    // By at least this much ($0.80)
input bool   LocationBrainPrintOnUse     = true;   // Log holds and stops
input bool   ShowLocationBrainOnDash     = true;   // Show the leg line

//--- HIGHER TIMEFRAME BIAS ------------------------------------------------------------
// Fifty-six setup detectors read M15 or M5; fourteen read H1 or above. That is the right balance
// for three hundred trades a day - the daily chart does not produce three hundred opportunities -
// and it is also why a BUY gets taken on an M15 pullback while the daily has fallen for a week.
//
// Refusing those trades is the wrong fix; it would cut the count to a fraction. So the higher
// timeframes do not veto. They raise the price of admission: a setup against a strong daily needs
// a better score and a better place in its leg, and the marginal ones stop clearing the bar while
// the good ones still do.
input bool   EnableHTFBias               = true;   // Let D1 and H4 raise the price of trading against them
input int    HTFLookD1                   = 10;     // Daily bars read
input int    HTFLookH4                   = 18;     // H4 bars read
input double HTFWeightD1                 = 0.65;   // How much the daily counts
input double HTFWeightH4                 = 0.35;   // And H4
input double HTFMinTravelATR             = 2.0;    // Travel below which a timeframe says nothing. A daily drifting sideways changes nothing; one that has run says plenty.
input double HTFFullTravelATR            = 6.0;    // Travel at which it counts fully
input double HTFMinEfficiency            = 0.45    ;// Net over walked distance. Six dollars in a straight line is a trend; six dollars wandering is not, and their closes look identical.
input bool   HTFRequireAgreement         = true;   // D1 and H4 must at least agree on direction - one running while the other goes the other way is a disagreement, not a trend
input double HTFMinForceToCount          = 0.30;   // Conviction below which nothing is charged
input int    HTFAgainstScoreExtra        = 4;      // Extra score a counter-trend setup must find
input double HTFAgainstLocationExtra     = 0.12;   // And how much further into its leg it must have pulled back
input bool   ShowHTFOnDash               = true;   // Show the bias line

//--- OLD LEVEL GUARD ------------------------------------------------------------------
// Price pushes through the high next to it, the breakout fires, and it runs into a level from six
// weeks back and collapses. The move was never a breakout - the market was collecting the stops
// above that recent high on its way to something it actually cared about.
//
// The zone engine builds from about two days, which is right for the zones price is reacting to
// now and blind to the one that ends the move. ZoneMap already holds four months and is read in a
// hundred places, none of them the location check - so nothing had to be built; the long history
// was there and the entry gate was not asking it.
input bool   EnableOldLevelGuard         = true;   // Charge a breakout running into an old, proven level
input bool   OldLevelOnlyBreakouts       = true;   // Reversal setups pay nothing - heading into the level that stops price IS the trade, not a problem with it
input int    OldLevelLookD1              = 60;     // Daily bars searched (about three months)
input int    OldLevelLookH4              = 120;    // H4 bars (about three weeks)
input int    OldLevelLookH1              = 300;    // H1 bars - nearly two months. The level that ends an intraday move is often drawn on H1, too small to leave a daily extreme and far too old for a two-day zone engine.
input int    OldLevelLookM30             = 400;    // M30 bars - about three weeks
input int    OldLevelMinAgeBars          = 5;      // How far back a level must be to count as old
input int    OldLevelReachPoints         = 6000;   // How far ahead ($6.00) one still matters
input int    OldLevelTouchTolerance      = 800;    // How close ($0.80) counts as touching it again
input int    OldLevelMinTouches          = 2;      // Touches below which it is just a high, not a level
input int    OldLevelFullTouches         = 4;      // Touches at which it counts fully
input int    OldLevelScoreCost           = 5;      // Most score a breakout into one has to find
input bool   ShowOldLevelOnDash          = true;   // Show the old level line

//--- APPROACH TRAVEL ------------------------------------------------------------------
// The market grinds down a hundred dollars - 4450 to 4350 - and then turns hard off some zone. On
// the way down every pullback looked like a sell and the robot took them, and the turn caught it
// with the deepest basket of the move.
//
// The grind is the danger and it is invisible to anything reading one leg, because it is made of
// many legs each of which looked ordinary. So the distance price has COME to reach a level is
// weighed alongside the level itself: a hundred dollars spent getting here means the sellers are
// spent too, and when it turns it turns hard.
input bool   EnableApproachTravel        = true;   // Weigh how far price travelled to reach the level
input ENUM_TIMEFRAMES ApproachTravelTF   = PERIOD_M30;  // Where the approach is measured
input int    ApproachTravelBars          = 96;     // Bars searched - two days on M30
input double ApproachTravelFromATR       = 6.0;    // Travel below which the approach says nothing
input double ApproachTravelFullATR       = 18.0;   // And where it counts fully - a hundred dollars of grind
input double ApproachTravelWeight        = 1.20;   // How much a long approach multiplies the level's cost

//--- SCENARIO -------------------------------------------------------------------------
// The target is small - $2.50, a quarter of that on rebate - and smaller than any reaction worth
// the name, so whether a bounce can REACH the target is not the question. It almost always can.
//
// The question is whether it reaches it before the basket needs rescuing. Half an ATR of reaction
// touches the target and leaves nothing behind it; the next rung opens into a move that has already
// finished, and the hundred-dollar grind is a hundred of those in a row.
//
// Not a forecast - a record. Levels are filed by what distinguishes them, and when one reacts the
// file says what the last ones did. It says nothing for the first few weeks, which is correct: ten
// samples is noise.
input bool   EnableScenario              = true;   // Record what reactions at each kind of level actually do

//--- DIRECTION CONSENSUS --------------------------------------------------------------
// Twenty detectors each propose a direction and the engine takes the single highest score. It has
// never counted how many agreed - so seven detectors at five lose to one outlier at eight, and the
// outlier is the entry that gets taken.
//
// Seven modules seeing the same thing is better evidence than one module seeing it strongly. Not
// always better - a genuinely strong setup keeps its place - but a lone voice should not beat a
// crowd by three points.
input bool   EnableDirectionConsensus    = true;   // Let a clear majority of detectors override a lone high score
input int    ConsensusVoiceEdge          = 3;      // How many more voices the other side needs. Three, not one - a one-voice majority is noise.
input int    ConsensusMaxScoreGap        = 4;      // Score gap above which the lone voice keeps its place anyway. A genuinely strong setup is not outvoted.
input bool   ConsensusPrintOnUse         = true;   // Log overrides

//--- REDIRECT AND QUEUE CHECKS --------------------------------------------------------
// Two places change the direction after the detectors have voted, and neither has ever looked at
// anything the detectors or the guards said.
//
// The redirect flips when the zone refuses one way - and never asks whether the other way is any
// good. The zone engine said "not this way" and something read it as "so the other way then".
//
// The queue replays a signal with the direction and score it had three bars ago. Three bars is
// long enough for price to have left the place that made the setup worth taking, which is the
// whole reason it was queued rather than taken.
input bool   EnableRedirectChecks        = true;   // Make a flipped direction pass the same guards as an original one
input int    RedirectMinVoices           = 2;      // Detectors that must have seen the direction being flipped to. One is not a setup.
input int    RedirectMaxHTFCost          = 2;      // HTF cost above which a flip is refused
input bool   EnableQueueLocationRecheck  = true;   // Re-ask the location brain before replaying a queued signal
input bool   QueueRecheckPrintOnUse      = true;   // Log held replays

input bool   EnableDirectionClarity      = true;   // Charge a direction that barely won. A BUY at eight beating a SELL at seven is not a direction, it is a coin landing on its edge - and the engine already knew both numbers and never used the difference.
input double ClarityLowBelow             = 0.25;   // Clarity below which the direction is called contested
input int    ClarityScoreCost            = 3;      // Score a contested direction has to find
input bool   PersistScenario             = true;   // Keep the record across restarts
input ENUM_TIMEFRAMES ScenarioTF         = PERIOD_M15;  // Where travel is measured
input int    ScenarioTouchTolerance      = 500;    // How close ($0.50) counts as being at the level
input int    ScenarioMaxBars             = 24;     // Bars after which a reaction has stopped being one
input int    ScenarioMinSamples          = 8;      // Samples below which the file says nothing
input int    ScenarioWindow              = 40;     // Samples after which the file is halved, so it follows recent behaviour
input double ScenApproachLow             = 6.0;    // Approach ATR dividing a short run from a medium one
input double ScenApproachHigh            = 14.0;   // And medium from a grind
input double ScenGridMinATR              = 2.0;    // S-GRID: projection a reaction must promise before a rung is added. A rung opened into a bounce that has already finished is how the grind collects baskets.
input double ScenarioShallowATR          = 0.8;    // Projection below which a reaction is shallow - touches the target and leaves nothing behind it
input int    ScenEntryScoreWeight        = 3;      // S-ENTRY: score a strong projection adds, or a shallow one takes. A pull, not a gate - there are eleven gates already and a twelfth would be the one that stops the robot trading.
input bool   ScenRecordPrintOnUse        = true;   // Log each recorded reaction

//--- FAILED BREAK ---------------------------------------------------------------------
// An impulse drives down through support and the bar closes back above it. The low went through;
// the close did not. Readings that work on closes see a level that held; readings that work on
// extremes see one that broke - same bar, and the close is the one that is right.
//
// The EA sells into that, because something registered a break. It is the opposite: support just
// tested and held is the strongest it will ever be, because everyone who sold the break is now
// trapped underneath it.
input bool   EnableFailedBreakGuard      = true;   // Charge trades that follow a break the close took back
input ENUM_TIMEFRAMES SweepReadTF        = PERIOD_M5;   // Where the sweep is read
input int    FailedBreakBars             = 3;      // Bars back a sweep still counts
input int    FailedBreakLevelLook        = 20;     // Bars before it that define the level
input double FailedBreakMinDepthATR      = 0.35;   // How far past the level the extreme must have gone
input double FailedBreakFullDepthATR     = 1.20;   // Depth at which the reading counts fully
input int    FailedBreakScoreCost        = 6;      // Most score a trade following the failed break must find
input bool   ShowFailedBreakOnDash       = true;   // Show the line

//--- DECISION LOG ---------------------------------------------------------------------
input bool   EnableDecisionLog           = true;   // S-FIX: one line per decision. A day went to guessing which of twenty-two gates was closed, six times, wrong each time - the EA knew the answer every time it refused and never wrote it down where anyone could read it back.
input bool   EnableGateRegistry          = true;   // S-FIX: name every refusal. Seventy-one places can refuse an entry and none of them says which module it was - the dashboard could say "refused" and not by what, which is how a day went to guessing, six times, wrong each time.
input bool   ShowGateTallyOnDash         = true;   // Show the day's refusals, busiest first
input bool   EnableQuietAlarm            = true;   // S-FIX: count the bars since anything opened. Every guard here is reasonable alone and none knows the others exist - six reasonable costs in a row is a robot that does not trade, arriving without anything being wrong. This reports it; it does not loosen anything, because a robot that relaxes its own standards when bored takes the trade it was right to refuse.
input int    QuietAlarmBars              = 40;     // Bars of silence after which the dashboard says so
input bool   QuietAlarmPrintOnUse        = true;   // Log it once when it starts

//--- SAFETY VALVE ---------------------------------------------------------------------
// Fourteen guards were added to a robot that traded three hundred times a day. Each is reasonable,
// each costs a little, and none knows the others exist - six reasonable costs in a row is a robot
// that does not trade, arriving with nothing visibly wrong.
//
// Loosening on boredom is the wrong answer: quiet has two causes and the robot cannot tell a bad
// threshold from a market it should sit out. But it CAN tell a third thing, and that is the one
// that matters: the baseline worked. If silence is coming from a guard that did not exist last
// week, that is the addition, not the market.
//
// This never makes the robot looser than it was before any of this was added. It returns it to
// that, one guard at a time, and only the guard the counters name.
input bool   EnableSafetyValve           = true;   // Stand down an added guard when it alone is causing the silence
input int    SafetyValveBars             = 60;     // Bars of quiet before the valve considers acting
input int    SafetyValveOffBars          = 30;     // How long the guard stands down
input double SafetyValveMinShare         = 0.65;   // Share of refusals one guard must own. Below this the silence is spread across gates, which is the market rather than a threshold.
input int    SafetyValveMaxPerDay        = 4;      // Most times a day the valve may act. A guard that needs standing down five times is a guard to retune, not to keep bypassing.
input bool   SafetyValvePrintOnUse       = true;   // Log when a guard comes back
input double QuietSingleCauseShare       = 0.70;   // Share of refusals from one gate that makes it the cause rather than one of several. Forty bars of quiet from the news guard is a closed market; forty from the location brain is a threshold worth looking at, and the bar count alone cannot tell them apart.

//--- TIGHTENING ON EVIDENCE -----------------------------------------------------------
// Loosening when quiet is the wrong direction: quiet has two causes and the robot cannot tell them
// apart. The thresholds may be too strict - or the market may be in the grind these guards exist to
// survive, and loosening there is how the hundred-dollar fall catches the deepest basket.
//
// Losing is different. A run of losses is not an opinion about what the market might do; it is what
// already happened. So this only goes one way: more careful on evidence, never less careful from
// boredom.
input bool   EnableEvidenceTighten       = true;   // Let losses raise the location demand
input int    EvidenceMinTrades           = 10;     // Trades before the record means anything
input int    EvidenceWindow              = 30;     // Trades after which the record is halved, so it follows recent trading
input double EvidenceBadWinRate          = 0.40;   // Win rate below which it tightens
input double EvidenceGoodWinRate         = 0.55;   // And above which the extra demand is released
input double EvidenceStep                = 0.04;   // How much the demand moves each step
input double EvidenceMaxExtra            = 0.15;   // Most it can add. A bad run is not proof every future entry is bad, and a guard that walks itself up forever ends as a robot that does not trade.
input bool   EvidenceTightenPrintOnUse   = true;   // Log each adjustment
input int    DecisionLogRepeatSeconds    = 60;     // Don't repeat the same line more often than this
// ---- BOSQICH 12: S/R DVIGATELI ----
input double SRCompressionATR        = 1.5;    // Support va resistance orasi shu M5 ATR dan tor bo'lsa - bu alohida S va R emas, SIQILISH hududi: hudud to'sig'i o'chadi, qaror ballga qoladi
input bool   SRNeverBlockBoth        = true;   // Narx ikki hudud orasida siqilib qolsa - faqat YAQINROG'I to'sadi, ikkala yo'nalish birdan yopilmaydi
input bool   SRMicroBreakAllow       = true;   // Oxirgi M1 shami hudud chetidan tana bilan o'tib yopilgan bo'lsa (displacement) - hudud to'siq emas
input double SRMicroBreakBodyATR     = 1.0;    // Displacement shami diapazoni kamida shuncha M1 ATR  // Hududlarni logga yozish (diagnostika)      // BOSQICH 9: narx darajaning ortida shuncha ketma-ket M1 shamida yopilsa (kichik farq bilan ham) - daraja singan
input bool   LGSwingFlip             = true;   // BOSQICH 8: ROL ALMASHISHI. Yopilish bilan singan swing high - endi SUPPORT, singan swing low - endi RESISTANCE (M1/M5/M15). Break-retest'da teskari kirish yo'q: bullish sinishdan keyin retestda SELL, bearish sinishdan keyin retestda BUY    // BOSQICH 6: swing faqat narx undan shu TF ning kamida shuncha ATR qaytgan bo'lsa zona. Mayda to'lqin zona emas, reaksiya bergan joy - zona    // Zona kengligi: swing'dan shuncha M5 ATR ichida - "zona ichida"
input bool   LGBlockChase            = true;   // Katta shamning TEPASIDA (BUY) / TUBIDA (SELL) uni quvib kirish yo'q - hozir shakllanayotgan sham ham hisobga olinadi
input double LGChaseTopShare         = 0.30;   // Sham diapazonining eng chekka shu qismi - "tepa"
input double LGChaseRangeATR         = 1.8;    // Sham diapazoni kamida shuncha M5 ATR bo'lsa - katta sham
input bool   LGPrintOnUse            = true;
input bool   EnableWinReEntry        = true;   // BOSQICH 5A: yutuqdan keyin O'SHA yo'nalishda talab qilinadigan ball kamayadi (zarardan keyin - o'zgarishsiz)
input int    WinReEntryBars          = 15;     // Yutuqdan keyin shuncha M1 bar
input int    WinReEntryRelief        = 2;      // Shuncha ball yengillik
input bool   EnableGoodLocationBonus = true;   // BOSQICH 5B: BUY kuchli support ustida / SELL kuchli resistance ostida - ball yengilligi (yaxshi joy tezroq o'tadi)
input int    GoodLocationBonus       = 2;      // Shuncha ball
input int    ReliefMaxShortfall      = 2;      // Yengilliklar faqat talabdan shuncha yoki kamroq kam bo'lgan setupga qo'llanadi
input bool   LGBlockMicroTip         = true;   // Mayda harakatning UCHIDA kirmaslik: BUY oxirgi M1 oyog'ining tepasida, SELL tubida - kichik qaytishni kutadi
input int    LGTipBarsM1             = 10;     // Oyoq shuncha M1 sham ichida o'lchanadi
input double LGTipLegATR             = 1.5;    // Oyoq kamida shuncha M1 ATR bo'lsa - "harakat"
input double LGTipShare              = 0.20;
input double LGTipMaxLegATR          = 4.0;    // BOSQICH 5b: oyoq shundan katta bo'lsa - bu mayda burilish emas, IMPULS. Uch qoidasi qo'llanmaydi (aks holda kuchli harakatda davom etish savdosi doim "uchida" bo'lib to'silardi)   // Oyoqning eng chekka shu qismi - "uch"
input bool   LGLocationRedirect      = true;   // BOSQICH 7: himoya bir yo'nalishni DARAJA sababli to'sganda (support'da SELL / resistance'da BUY) - o'sha zahoti teskari yo'nalishdagi setup tekshiriladi (support'dan BUY / resistance'dan SELL)
// ---- BOSQICH 14: MICRO / MINOR STRUKTURA ----
input bool   MicroStructOn           = true;   // M1 (micro) va M5 (minor) da: swing, BOS, MSS/CHOCH, displacement, impuls va korreksiya farqi
input int    MicroSwingDepth         = 2;      // Swing uchun har ikki tomonda shuncha sham
input int    MicroLookM1             = 60;     // M1 shamlar (1 soat)
input int    MicroLookM5             = 48;     // M5 shamlar (4 soat)
input int    MicroLookM15            = 48;     // BOSQICH 15b: M15 shamlar (12 soat) - LOCAL struktura va yo'nalish
input double MicroDisplaceATR        = 1.5;
// ---- BOSQICH 15: STRUKTURANI QARORGA ULASH (faqat o'tishga yordam beradi, yangi to'siq emas) ----
input bool   MicroStructDecides      = true;   // Micro/minor struktura kirish qaroriga ulansin
input int    MicroStructRelief       = 2;      // Micro VA minor struktura kirish tomonida bo'lsa - talab qilinadigan ball shuncha kamayadi
input int    MicroOnlyRelief         = 1;      // Faqat micro (M1) kirish tomonida bo'lsa - shuncha
input bool   MicroZoneOverride       = true;   // Micro BOS hududni yopilish bilan sindirgan bo'lsa - hudud to'siq emas (breakout/retest savdosi o'tadi)    // Sham diapazoni shuncha ATR dan katta va tanasi >=60% bo'lsa - displacement
input bool   LogDecisionChain        = true;   // BOSQICH 13: har potentsial kirish uchun TO'LIQ qaror zanjiri bitta qatorda ([SIRUS CHAIN]). Bir barda bir marta, yo'nalish bo'yicha
input bool   LogDecisionChainAll      = false;  // true = o'tgan kirishlar ham yoziladi, false = faqat rad etilganlar
input bool   LogNearMiss             = true;   // BOSQICH 4: ball talabdan 1-2 ga yetmagan setupning to'liq bonus/jazo ro'yxati logga ([SIRUS NEAR-MISS])
input int    NearMissPoints          = 2;      // Talabdan shuncha yoki kamroq kam bo'lsa - "yaqin o'tkazib yuborish"
   // Final TP floor for ALL entries incl. micro

input group "05 — TRAILING / PROFIT LOCK"
// V31.6e cleanup: removed UseTrailingStop/TrailingStartPoints/TrailingStepPoints/UseBasketTrailing.
// These belonged only to the old, dormant duplicate trailing block removed this session.
// The real trailing system lives in section 07 (UseAdvancedBasketTrailing/BasketTrailStartPoints/etc).

input group "06 — GRID / RECOVERY SETTINGS"
// ============================ QUICK GUIDE (read this first) ============================
// This sets the martingale grid: when the first entry goes into loss, the EA adds more
// orders at intervals, each bigger than the last, to lower the average price so a small
// bounce closes the whole basket in profit. The FIRST order's size is StartLot (LOT
// section); this section controls orders 2,3,4...
//
//   The three levers you actually tune:
//     - MaxOrders           -> how many orders max in one basket (incl. the first).
//     - GridDistancePoints  -> how far price must move against you before the next add
//                              (3-digit broker: 7000 points = $7.00).
//     - LotMultiplier       -> each add = previous target x this (1.30 = each 30% bigger).
//
//   With StartLot 0.25, LotMultiplier 1.30, MaxOrders 7 the sizes step up like:
//     0.25 -> 0.33 -> 0.42 -> 0.55 -> 0.71 -> 0.93 -> 1.21   (total ~4.40 lots)
//   Bigger MaxOrders / LotMultiplier = faster recovery but much larger risk build-up.
//   The Basket SL (SL section) is what caps the total loss of all these orders together.


// ======================================================================================
input bool              UseGridRecovery          = true;      // Master switch for the whole martingale grid. OFF = only ever the single first entry, no averaging down.
input bool              AllowGridAfterMicro      = false;     // Allow grid adds even after a very small ("micro") first entry. Keep false normally.
input int               MaxOrders                = 5;         // V249fix: 7 -> 5. At 7 rungs from StartLot 0.25 with LotMultiplier 1.30 the full ladder projects ~$6.8k of adverse excursion against a ~$4.2k stop budget on a ~$10k account, so LadderIsAffordable() refused EVERY first entry - the EA scored setups and then never opened them. 5 rungs projects ~$2.6k and fits with room to spare. Raise it only alongside a bigger balance, a smaller StartLot, or a lower LotMultiplier.   // Max orders in ONE basket, including the first entry. Higher = deeper averaging (more recovery power) but bigger total risk.
input int               GridStartOrder           = 2;         // Which order number the grid logic starts at (2 = the first ADD after the first entry). Leave at 2.
input int               GridDistancePoints       = 7000;      // Base distance price must move AGAINST the basket before the next grid order (3-digit broker: 7000 = $7.00). Smaller = adds sooner/closer; larger = adds later/farther.
input double            GridDistanceMultiplier   = 1.25;      // Each successive grid gap = previous gap x this (1.25 = each gap 25% wider), so later adds are spaced farther apart.
input double            LotMultiplier            = 1.30;      // Each grid add's size = previous target x this (1.30 = each add 30% bigger). This is the martingale step. Higher = faster recovery, faster risk build-up.
input double            MinGridLotFactor         = 0.5;    // Safety: the stacked caution modules may trim a grid add down to this fraction of its LotMultiplier target, but never below it (protects the averaging-down math). Leave at 0.5.
input bool              EnableAbsoluteGridLotFloor = true;  // Keep ON. A firm floor on grid-add size anchored to StartLot x LotMultiplier^orders (which can't drift), fixing an old bug where adds silently shrank down the chain.
input double            AbsoluteGridLotFloorFactor = 0.80;  // V222: 1.0 -> 0.80. At 1.0 this floor equalled the full intended progression, which meant every lot adjustment above it - grid intelligence, spread quality, margin level, swing correction, client safety, preset hardening - was computed and then discarded. Eight modules doing nothing. At 0.80 caution can trim up to a fifth of an addition, which is enough to matter and not enough to break the recovery arithmetic the ladder depends on.   // Fraction of the intended martingale step (StartLot x LotMultiplier^orders) below which a grid add can never fall. 1.0 = honour the full progression (0.25 -> 0.33 -> 0.42 -> 0.55 -> 0.71 -> 0.93): fastest recovery, largest risk build-up. Lower this (e.g. 0.7) to make the grid add more cautiously.
input bool              EnableGridNeverBelowPrevious = false; // V222: true -> false. This forced each addition to be at least as large as the one before it, which sounds like protecting the progression and in practice overrode every quality reading - an addition into a worse location was guaranteed to be bigger than one into a better one. The absolute floor above still holds the progression at 80%; what is removed is the rule that made caution impossible. // Keep ON. Never let a grid add be SMALLER than the order it's averaging down (an undersized add takes full new risk while barely improving the escape price). If only a tiny step fits, the EA adds nothing instead.
input bool              EnableGridCautionHold    = true;   // 3-muammo: ehtiyot modullari grid lotini poldan pastga tushirmoqchi bo'lsa, lot majburan ko'tarilmaydi - bu pog'ona vaqtincha ushlab turiladi
input int               GridCautionMaxHoldBars   = 10;     // Ko'pi bilan shuncha bar (M1) kutadi, keyin pol lot bilan qo'shadi
input double            GridCautionExtraDistFraction = 0.5; // Yoki narx grid masofasidan yana shuncha ulush uzoqlashsa (yaxshiroq o'rtacha narx) - darhol qo'shadi
input bool              AdaptiveGridDistance     = true;      // ON = grid spacing adjusts to volatility (ATR) instead of a fixed GridDistancePoints, so adds are wider in fast markets and tighter in calm ones. Recommended ON.
input double            AdaptiveGridATRMult      = 1.10;      // When AdaptiveGridDistance is ON: grid gap = ATR x this. Higher = wider spacing (adds farther apart).
input int               GridMinDistancePoints    = 6000;      // Floor for the adaptive gap (3-digit: 6000 = $6.00). The gap never goes tighter than this even in very calm markets.
input int               GridMaxDistancePoints    = 14000;     // Ceiling for the adaptive gap (14000 = $14.00). The gap never goes wider than this even in very volatile markets.
input int               GridCooldownBars         = 2;         // Minimum bars to wait between two grid adds (stops several adds stacking on one fast candle).
input int               GridMinSecondsBetweenOrders = 120;    // Minimum seconds between two grid adds (a time-based version of the cooldown above).
input bool              GridRequireAdverseMove   = true;      // ON = only add a grid order after price has actually moved AGAINST the basket by the grid distance (true averaging-down). Keep ON.
input bool              GridSameDirectionOnly    = true;      // ON = every order in a basket is the same direction (all BUY or all SELL). Keep ON for this grid design.
input bool              GridBlockFreshImpulse    = true;
input bool              GridUseRecoveryDDTrigger = false;  // OFF - grid is distance-only; Basket SL handles losses

// FEATURE(grid-reaction): "reaction preference" for grid additions (user request, variant A).
// Normally a grid order needs price to travel the FULL grid distance against the basket. But if
// price reaches a strong opposing wall (resistance for a SELL basket / support for a BUY basket)
// and PRINTS A REJECTION - an M15 candle that poked the wall with a real wick and closed back on
// our side - that's a high-quality spot to add, better than a blind distance step. So we let the
// grid fire EARLY (at a reduced fraction of the full distance) when that reaction is present.
// Crucially this is a PREFERENCE, not a requirement: if no reaction appears, the grid still fires
// at the normal full distance, so the basket is never left unprotected waiting for a reaction.
input bool   EnableGridReactionPreference = true;   // Allow an early grid add when price rejects at a strong opposing wall
input double GridReactionDistanceFraction = 0.6;    // With a valid reaction, price only needs to travel this fraction of the full grid distance (0.6 = 60%)
input double GridReactionMinWallStrength  = 1.8;    // The opposing wall must be at least this strong (ZoneMapStrength) to count
input double GridReactionWickRatioMin     = 0.35;   // The M15 rejection candle's wick must be at least this fraction of its range (matches the sweep standard)
input int    GridReactionWallProximityPts = 400;    // Price must be within this many points of the wall for the reaction to count
input bool   GridReactionPrintOnUse       = true;

// FEATURE(grid-reaction-consensus): a single M15 rejection candle can be a fakeout. Instead of
// trusting one candle, require a genuine REVERSAL CONSENSUS in the direction that helps the
// basket - the same multi-signal engine used elsewhere (Swing+RSIdiv / BOS-CHoCH / Sweep /
// Engulfing). "At least 2 independent signals agree" is the bar, so no single pattern can trigger
// an early grid add on its own. The wall+rejection check above still runs first (price must be AT
// a real wall); this adds the "and the reversal is actually confirmed by 2+ signals" requirement.
input bool   GridReactionRequireConsensus = true;   // Require a 2+ signal reversal consensus, not just one M15 candle
input double GridReactionMinConsensusScore = 0.80;  // ReversalConsensusScore threshold: 0.82 = 2 signals, 0.92 = 3+. 0.80 means "at least 2 independent reversal signals agree".
input double            RecoveryStartDDPercent   = 5.0;
input bool              UseAutoGridByMode        = true;
input int               BalancedGridDistancePoints = 7000;
input int               BalancedGridMinDistancePoints = 6000;
input int               BalancedGridMaxDistancePoints = 12000;  // V249fix: 14000 -> 12000. See the multiplier note below - the tail gap is what pushed Balanced's completed-ladder drawdown to 39.1%, against a 42% Smart-Early-Exit arm. Capping the tail at the same 12000 Hunter uses leaves the profile distinct through its wider BASE (7000 vs 6500) without the runaway last rung.
input double            BalancedGridDistanceMultiplier = 1.20;  // V249fix: 1.25 -> 1.20. At 1.25 the 5-rung Balanced ladder ran 40,359 points ($40.36) deep and peaked at 39.1% drawdown - only 2.9 points below where Smart Early Exit arms and 8% under the affordability budget, i.e. the last rung was placed with almost no margin and could be cancelled by SEE before it landed. 1.20 brings it to 37,480 points / 35.4% peak: 17% budget headroom and a 6.6-point gap to SEE, so the ladder the entry gate approved can actually be completed. Balanced remains the WIDER-SPACED profile via its base distance (7000 vs 6500) and floor (6000 vs 5500) - it survives more travel before the ladder completes. Note it is NOT the cheaper one: because its gaps are bigger, its completed-ladder drawdown is HIGHER than Hunter's (35.4% vs 33.0%). Wider spacing buys time, not dollars.
input double            BalancedAdaptiveGridATRMult = 1.10;
input double            BalancedRecoveryStartDDPercent = 5.0;
input int               HunterGridDistancePoints = 6500;   // Hunter base grid step (points)
input int               HunterGridMinDistancePoints = 5500; // Hunter grid floor (points)
input int               HunterGridMaxDistancePoints = 12000;
input double            HunterGridDistanceMultiplier = 1.20;
input double            HunterAdaptiveGridATRMult = 1.00;
input double            HunterRecoveryStartDDPercent = 4.0;
input bool              UseGridSafetyGuard       = true;
input bool              GridSafetyBlockOnNews    = true;
input bool              GridSafetyBlockOnShock   = true;
input bool              GridSafetyBlockOnChaos   = true;
input bool              GridSafetyBlockTrendAgainst = true;
input bool              GridSafetyBlockZoneDanger = true;
input bool              GridSafetyBlockSpreadRisk = true;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) GridSafetyBlockDDRisk
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) GridSafetyMaxDDForNewGrid
input int               GridSafetyMinHealthScore = 65;
input bool              UseBasketTPMoney         = false;
input double            BasketTPMoney            = 0.0;
input bool              UseBasketSLMoney         = false;
input double            BasketSLMoney            = 0.0;
input bool              UseBasketTPPoints        = true;
input int               BasketTPMinPoints        = 1200;   // V170: 2000 -> 1200 ($1.20). This floor exists so the spread cannot eat the trade, and at $0.35 spread a $1.20 target still keeps ~70% of itself. At 2000 it sat ABOVE what the downward adjustments produce, so it silenced them - an Asian, ranging, churning market computed a $1.50 target and got $2.00 anyway. A floor should catch the unreasonable, not overrule the deliberate.

// V138: contextual target. A fixed target ignores what stands in front of the basket. If the nearest
// opposing level is closer than the target, the basket must break it just to finish - and usually
// stalls under it instead. If the way is clear far beyond the target, the move is left unharvested.
input bool   EnableContextualTP           = true;   // Size the basket target by distance to the next opposing level instead of a fixed number
input double ContextTPMinWallStrength     = 1.8;    // Only levels at least this strong reshape the target - a single stray wick should not
input int    ContextTPBufferPoints        = 400;    // Exit this far IN FRONT of the level ($0.40), because price rarely reaches the exact edge
input double ContextTPMaxFactor           = 2.0;    // Ceiling as a multiple of the configured target (2.0 = a clear road may double it, no more - a scalp must stay a scalp)
input bool   ContextTPPrintOnUse          = true;   // Log every target adjustment so it can be checked against the chart
input bool              PrintGridDecisions       = true;

input group "07 — TP CHAIN / ADVANCED RECOVERY"
input bool              UseLegacyPack2           = true;
input bool              UseTPChainLegacy         = true;
input int               TPChainOrder2Percent     = 80;
input int               TPChainOrder3Percent     = 65;
input int               TPChainOrder5Percent     = 50;
input int               TPChainMinPoints         = 2000;   // TP Chain floor (points)
input bool              UseAdvancedBasketTrailing = true;
input int               BasketTrailStartPoints   = 2300;   // Trailing arms at this profit (points)
input int               BasketTrailStepPoints    = 300;    // Trailing follow distance (points)
input int               BasketTrailLockPoints    = 2000;   // Minimum locked profit once armed (points)
input bool              EnableAdaptiveTrailArm   = true;   // V31.6z64: trailing armed at a FIXED 2300 while TP shrinks with basket depth (2000 at 3+ orders) - so for every basket that actually needed grid rescue, TP fired below the arm point and trailing NEVER engaged. Arms relative to each basket's own TP instead.
input double            AdaptiveTrailArmTPFraction = 0.8;  // Arm trailing at this fraction of the basket's own current TP (0.8 x 2000 = 1600 for a deep basket, giving it real trailing protection)
input bool              UseBasketBreakEvenLock   = false;  // OFF - trailing alone manages the exit
input int               BasketBEStartPoints      = 1500;  // BE lock arms at this profit (points)
input int               BasketBEPlusPoints       = 1000;  // BE lock target profit (points)
input bool              UseRecoverySafeModeV2    = true;
input int               RecoverySafeStartOrder   = 3;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) RecoveryMaxDDForNewGrid
input bool              RecoveryStretchGridOnDD  = true;
input double            RecoveryDDStretchStart   = 8.0;
input double            RecoveryDDStretchMult    = 1.35;
input bool              RecoveryBlockAgainstHTF  = true;
input bool              UseAftershockGuard       = true;
input int               AftershockMinutes        = 20;
input int               AftershockMaxSpread      = 300;
input bool              PrintLegacyPack2Events   = true;

input group "08 — NEWS / BROKER / ANALYTICS"
input bool              UseLegacyPack3           = true;
input bool              UseNewsCalendarGuardV2   = true;
input bool              NewsGuardManualSchedule  = true;
input int               NewsGuardMinutesBefore   = 20;
input int               NewsGuardMinutesAfter    = 20;
input string            NewsGuardTimesCSV        = "";        // example: 13:30,15:00 server time
input bool              NewsGuardCloseBasket     = false;
input bool              NewsGuardBlockGrid       = true;
input bool              NewsGuardBlockEntry      = true;
input bool              UseBrokerSyncV2          = true;
input int               BrokerSyncMaxSpread      = 300;
input int               BrokerSyncMinStopLevel   = 0;
input bool              BrokerSyncAdaptTPToStop  = true;
input bool              BrokerSyncAdaptGridToStop= true;
input bool              BrokerSyncBlockBadFilling= false;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) UseServerDisasterSL
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ServerDisasterDDPercent
input bool              ServerDisasterCloseBasket= true;
input bool              UseClosedDealAnalytics   = true;
input int               ClosedDealLookbackDays   = 7;
input int               ClosedDealRefreshSeconds = 300;
input bool              UseClientAuditSummary    = true;
input int               ClientAuditPrintSeconds  = 600;
input bool              PrintLegacyPack3Events   = true;

input group "[NOT WIRED] 09 — STABLE BASELINE"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------

input group "10 — MINI LICENSE"
input bool              UsePack4MiniLicense      = true;
input bool              P4MiniUseLicenseControl  = false;     // keep false while internal testing
input string            P4MiniAccountWhitelist   = "";        // example: 253530129,123456789
input string            P4MiniExpireDate         = "2099.12.31";
input int               P4MiniGraceDays          = 0;
input bool              P4MiniAllowDemo          = true;
input bool              P4MiniAllowReal          = true;
input bool              P4MiniCloseBasketInvalid = false;
input bool              P4MiniUseSymbolGuard     = true;
input bool              P4MiniRequireXAU         = true;
input string            P4MiniSymbolKeyword      = "XAU";
input int               P4MiniMaxSpread          = 300;
input bool              PrintPack4MiniEvents     = true;

input group "11 — CLIENT RISK PROFILE / LOT CAP"
input bool              UsePack4MiniLotCaps      = true;
input string            P4MiniClientRiskProfile  = "BALANCED"; // CONSERVATIVE / BALANCED / AGGRESSIVE
input bool              P4MiniUseProfileCaps     = true;
input double            P4MiniConservativeFirstLot = 0.10;
input double            P4MiniConservativeGridLot  = 0.50;
input int               P4MiniConservativeMaxOrders = 5;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniConservativeMaxDD
input double            P4MiniBalancedFirstLot   = 0.25;
input double            P4MiniBalancedGridLot    = 1.00;
input int               P4MiniBalancedMaxOrders  = 7;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniBalancedMaxDD
input double            P4MiniAggressiveFirstLot = 0.50;
input double            P4MiniAggressiveGridLot  = 2.00;
input int               P4MiniAggressiveMaxOrders = 9;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniAggressiveMaxDD
input double            P4MiniHardCapFirstLot    = 1.00;
input double            P4MiniHardCapGridLot     = 3.00;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniBlockGridAboveProfileDD
input bool              P4MiniBlockGridAboveMaxOrders = true;
input bool              PrintPack4MiniLotEvents  = true;

input group "12 — PREMIUM VISUAL WATERMARK / ZONES"
input bool              UsePremiumVisualEngine   = true;
input bool              PremiumShowWatermark     = true;
input bool              PremiumShowZones         = true;
input bool              PremiumShowZoneMidlines  = true;
input bool              PremiumShowZoneLabels    = true;
input int               PremiumVisualRefreshSeconds = 3;
input int               PremiumZoneHalfWidthPoints = 350;
input int               PremiumZoneLookbackBars  = 180;
input int               PremiumZoneForwardBars   = 20;
input int               PremiumWatermarkFontSize = 42;
input int               PremiumZoneLabelFontSize = 9;
input bool              PremiumUseFallbackZones  = true;
input int               PremiumFallbackZoneLookbackBars = 180;
input int               PremiumFallbackZoneHalfWidthPoints = 900;
input color             PremiumWatermarkColor    = clrDarkSlateGray;
input color             PremiumSupportZoneColor  = clrGreen;
input color             PremiumResistanceZoneColor = clrRed;
input color             PremiumSupportLineColor  = clrAqua;
input color             PremiumResistanceLineColor = clrOrangeRed;
input color             PremiumAccentColor       = clrGold;
input bool              PrintPremiumVisualEvents = true;

input group "13 — PREMIUM VISUAL PACK 2"
input bool              PremiumShowBasketLines   = true;
input bool              PremiumShowNextGridLine  = false;
input bool              PremiumShowSignalMarker  = true;
input bool              PremiumShowHeaderFrame   = true;
input int               PremiumSignalArrowOffsetPoints = 220;
input int               PremiumHeaderFrameX      = 14;
input int               PremiumHeaderFrameY      = 12;
input int               PremiumHeaderFrameW      = 250;
input int               PremiumHeaderFrameH      = 74;
input color             PremiumHeaderBgColor     = clrBlack;
input color             PremiumHeaderBorderColor = clrGold;
input color             PremiumBasketAvgColor    = clrAqua;
input color             PremiumBasketTPColor     = clrGold;
input color             PremiumNextGridColor     = clrOrange;
input color             PremiumSignalBuyColor    = clrLime;
input color             PremiumSignalSellColor   = clrTomato;

input group "14 — PREMIUM VISUAL PACK 3"
input bool              PremiumShowBasketSLLine  = true;
input bool              PremiumShowTrailLockLine = true;
input bool              PremiumShowSignalHistory = false;
input bool              PremiumShowSessionZones  = false;
input int               PremiumSignalHistoryBars = 80;
input int               PremiumSessionLookbackBars = 240;
input color             PremiumBasketSLColor     = clrRed;
input color             PremiumTrailLockColor    = clrYellow;
input color             PremiumAsiaSessionColor  = clrDarkSlateGray;
input color             PremiumLondonSessionColor = clrMidnightBlue;
input color             PremiumNYSessionColor    = clrMaroon;
input color             PremiumSessionLabelColor = clrSilver;

input group "15 — VISUAL CLEANUP / PERFORMANCE"
input bool              PremiumUseClutterControl = true;
input bool              PremiumCleanIfDisabled   = true;
input bool              PremiumHideBasketLinesWhenFlat = true;
input bool              PremiumCleanOldSignalHistory = true;
input int               PremiumMaxSignalHistoryObjects = 10;
input int               PremiumVisualCleanupSeconds = 30;
input bool              PremiumCleanSessionsIfOff = true;
input bool              PremiumCleanZonesIfOff    = true;
input bool              PremiumCleanSignalIfOff   = true;
input bool              PremiumPrintCleanupEvents = true;

input group "16 — SETTINGS BALANCE / SAFE DEFAULTS"
input bool              UseRCSettingsBalance     = true;
input string            RCSettingsPreset         = "BALANCED"; // SAFE / BALANCED / HIGH_HUNTER
input bool              RCSettingsStrictEnforce  = false;      // false = audit only, true = block risky entry/grid
input bool              RCWarnIfLicenseOff       = true;
input bool              RCWarnIfBasketSLHigh     = true;
input bool              RCWarnIfMaxOrdersHigh    = true;
input bool              RCWarnIfLotTooHigh       = true;
input bool              RCWarnIfSpreadCapHigh    = true;
input double            RCSafeMaxFirstLot        = 0.10;
input double            RCBalancedMaxFirstLot    = 0.25;
input double            RCHighHunterMaxFirstLot  = 0.50;
input int               RCSafeMaxOrders          = 5;
input int               RCBalancedMaxOrders      = 7;
input int               RCHighHunterMaxOrders    = 9;
input double            RCSafeMaxBasketSL        = 10.0;
input double            RCBalancedMaxBasketSL    = 50.0;   // V249fix(auto-mode): 18 -> 50, tracking BasketSLPercent. At 18 against a configured BasketSLPercent of 50 this governor raised a warning on EVERY scan, forever - noise that hides a real one, and a live landmine: the moment RCSettingsStrictEnforce is set true it becomes a permanent entry AND grid block. A governor must cap overreach, not disagree with the configuration it is governing. Keep this equal to BasketSLPercent.
input double            RCHighHunterMaxBasketSL  = 50.0;   // V249fix(auto-mode): 25 -> 50, same reason - keep equal to BasketSLPercent.
input int               RCSafeMaxSpread          = 300;
input int               RCBalancedMaxSpread      = 300;
input int               RCHighHunterMaxSpread    = 300;
input bool              PrintRCSettingsEvents    = true;

input group "17 — WARNING CLEANUP / ZERO-WARNING POLISH"
input bool              UseWarningCleanupPolish  = true;
input bool              PrintWarningCleanupEvents = true;

input group "[NOT WIRED] 18 — FINAL SELF-AUDIT CHECKLIST"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------
// V31.6e cleanup: removed FinalAuditWarnIfSessionFilterOff - the check it gated is gone too.

input group "[NOT WIRED] 19 — RELEASE BUILD / CLIENT PRESET EXPORT"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------
input string            ReleaseBuildProfile      = "CLIENT_BALANCED"; // INTERNAL_TEST / CLIENT_SAFE / CLIENT_BALANCED / HIGH_HUNTER / RENTAL_DEMO
input bool              ReleaseRequireLicenseForClient = false;       // set true before real client rental

input group "20 — LEGACY DEEP PARITY / HTF COMMANDER"
input bool              UseLegacyDeepParityPack  = true;
input bool              UseDeepHTFCommander      = true;
input bool              DeepHTFUseScoreIntegration = true;
input bool              DeepHTFStrictCounterTrendBlock = false;
input bool              DeepHTFBlockGridCounterTrend = false; // V52b: REVERTED to false after review. Three reasons: (1) redundant - Pack2RecoveryAllowsGrid() already blocks counter-HTF grid adds and RecoveryBlockAgainstHTF is already true; (2) WRONG DIRECTION - this flag keys off DeepOpportunitySign() (the scanner's current opportunity), not the BASKET direction the grid actually adds in, so it fires on the wrong signal and can block an add that is WITH the trend; (3) it evaluates before szr_active is determined, so it would have killed the Smart Zone Recovery rescue path entirely.
input int               DeepHTFFastMAPeriod      = 50;
input int               DeepHTFSlowMAPeriod      = 200;
input int               DeepHTFSlopeBars         = 8;
input int               DeepStructureLookbackBars = 36;
input int               DeepZoneNearPoints       = 900;
input int               DeepHTFAlignBonus        = 2;
input int               DeepM15ConfirmBonus      = 1;
input int               DeepZoneReactionBonus    = 1;
input int               DeepHTFCounterPenalty    = 0;   // BOSQICH 16: 2 -> 0. TAKROR: HTF qarshiligi ball dvigatelida allaqachon hisoblanadi (HTFAgainstScorePenalty=4, MaxTrendAgainstPenalty=6 - beshta modul shu yerga boradi). Legacy jazo esa CONDITIONS guruhiga, shift hisobidan TASHQARIDA ikkinchi marta yozilardi. Bonusi saqlandi
input int               DeepZoneDangerPenalty    = 2;
input bool              PrintDeepParityEvents    = true;

input group "21 — DEEP BOS / CHoCH / RETEST UPGRADE"
input bool              UseDeepBOSChochRetest    = true;
input bool              DeepBOSUseScoreIntegration = true;
input bool              DeepBOSStrictAgainstBlock = false;
input bool              DeepBOSBlockGridAgainst  = false;
input int               DeepBOSLookbackBars      = 34;
input int               DeepBOSBreakBufferPoints = 180;
input int               DeepRetestZonePoints     = 420;
input int               DeepRetestMaxBars        = 18;
input int               DeepBOSAlignBonus        = 2;
input int               DeepBOSFreshBreakBonus   = 0;    // V29: reduced bonus for a break NOT yet retest-confirmed (fake-breakout guard)
input int               DeepCHoCHBonus           = 2;
input int               DeepRetestBonus          = 2;
input int               DeepBOSAgainstPenalty    = 0;   // BOSQICH 16: 2 -> 0. TAKROR: qarshi struktura ball dvigatelining struktura modullarida hisoblanadi. Bonusi saqlandi
input int               DeepFailedRetestPenalty  = 1;
input bool              PrintDeepBOSEvents       = true;

input group "22 — DEEP TOP ZONE / COUNTERTREND TRAP GUARD"
input bool              UseDeepTopZoneTrapGuard  = true;
input bool              DeepTopZoneUseScoreIntegration = true;
input bool              DeepTopZoneStrictBlock   = false;
input bool              DeepTopZoneBlockGrid     = false;
input int               DeepTopZoneNearPoints    = 850;
input int               DeepZoneBreakoutBufferPoints = 260;
input double            DeepTrapWickRatio        = 0.42;
input int               DeepTrapWithSignalBonus  = 2;
input int               DeepZoneBreakoutBonus    = 2;
input int               DeepOppositeZonePenalty  = 0;   // BOSQICH 16: 3 -> 0. TAKROR: qarshi zona uchun counter-zone, zona veto va BOSQICH 11-12 zona dvigateli bor. Bu to'rtinchi ovoz edi. Bonusi saqlandi
input int               DeepCounterTrendTrapPenalty = 2;
input bool              PrintDeepTopZoneEvents   = true;

input group "23 — DEEP NEWS / VOLATILITY SHOCK BRAIN"
input bool              UseDeepNewsVolatilityBrain = true;
input bool              DeepNewsUseScoreIntegration = true;
input bool              DeepNewsStrictEntryBlock = false;
input bool              DeepNewsStrictGridBlock  = false;
input bool              DeepShockUseNewsState    = true;
input bool              DeepShockUseATRImpulse   = true;
input bool              DeepShockUseSpreadSpike  = true;
input int               DeepShockATRPeriod       = 14;
input double            DeepShockRangeATRMult    = 2.20;
input double            DeepShockBodyATRMult     = 1.25;
input int               DeepShockSpreadPoints    = 300;
input int               DeepShockCooldownBars    = 6;
input int               DeepNewsPenalty          = 3;
input int               DeepShockAgainstPenalty  = 3;
input int               DeepShockExhaustPenalty  = 2;
input int               DeepShockMomentumBonus   = 1;
input bool              PrintDeepShockEvents     = true;

input group "24 — ADAPTIVE ENTRY TIMING BRAIN"
input bool              UseAdaptiveEntryTimingBrain = true;
input bool              DeepTimingUseScoreIntegration = true;
input bool              DeepTimingStrictEarlyBlock = false;
input bool              DeepTimingBlockGridAfterShock = false;
input int               DeepTimingMinSecondsAfterBarOpen = 3;
input int               DeepTimingLateEntrySeconds = 48;
input int               DeepTimingPostShockWaitBars = 2;
input int               DeepTimingCandleConfirmBonus = 2;
input int               DeepTimingRejectionBonus  = 1;
input int               DeepTimingEarlyPenalty    = 0;   // BOSQICH 16: 2 -> 0. Signallar YOPILGAN shamdan quriladi, ya'ni ular tabiiy ravishda yangi barning birinchi soniyalarida paydo bo'ladi. Bu jazo aynan eng yangi signalni kechiktirardi
input int               DeepTimingLatePenalty     = 1;
input int               DeepTimingPostShockPenalty = 2;
input int               DeepTimingOppCandlePenalty = 2;
input bool              PrintDeepTimingEvents     = true;

input group "25 — ADAPTIVE RECOVERY INTELLIGENCE"
input bool              UseAdaptiveRecoveryIntelligence = true;
input bool              DeepRecoveryUseGridDistance = true;
input bool              DeepRecoveryUseLotThrottle = true;
input bool              DeepRecoveryBlockBadGrid  = false;
input int               DeepRecoveryMinHealthScore = 38;
input double            DeepRecoveryDDStretchStart = 6.0;
input double            DeepRecoveryDDHardCaution = 14.0;
input double            DeepRecoveryDistanceBoost = 1.25;
input double            DeepRecoveryMaxDistanceBoost = 2.20;
input double            DeepRecoveryLotReduceFactor = 0.75;
input double            DeepRecoveryMinLotFactor  = 0.50;
input int               DeepRecoveryTrendAgainstPenalty = 22;
input int               DeepRecoveryZoneDangerPenalty = 20;
input int               DeepRecoveryNewsShockPenalty = 18;
input int               DeepRecoveryOrderPressurePenalty = 18;
input bool              PrintDeepRecoveryEvents   = true;

input group "26 — PROFIT EXTRACTION / SMART EXIT BRAIN"
input bool              UseProfitExtractionSmartExit = true;
input bool              DeepExitEnableAutoClose  = false;  // OFF - was closing at 330-700pts via 4 separate sub-mechanisms, undercutting the tuned trailing system (BasketTrailStartPoints etc) in group 03/07
input bool              DeepExitCloseOnPeakGiveback = true;
input bool              DeepExitCloseOnOppositeRisk = true;
input bool              DeepExitCloseOnShockRisk = true;
input bool              DeepExitQuickMultiOrderProfit = true;
input int               DeepExitProtectStartPoints = 700;
input int               DeepExitPeakGivebackPoints = 360;
input double            DeepExitPeakGivebackPercent = 45.0;
input int               DeepExitOppositeRiskMinPoints = 520;
input int               DeepExitShockRiskMinPoints = 650;
input int               DeepExitMultiOrderMinOrders = 3;
input int               DeepExitMultiOrderProfitPoints = 330;
input double            DeepExitMinProfitMoney   = 0.0;
input bool              PrintDeepExitEvents      = true;

input group "27 — MARKET REGIME AUTO-TUNING BRAIN"
input bool              UseMarketRegimeAutoTuningBrain = true;
input bool              RegimeTuneUseScoreIntegration = true;
input bool              RegimeTuneStrictDeadChaosBlock = false;
input bool              RegimeTuneBlockGridInShock = false;
input bool              RegimeTuneUseGridDistance = true;
input bool              RegimeTuneUseLotThrottle = true;
input int               RegimeTrendAlignBonus    = 2;
input int               RegimeRangeEdgeBonus     = 2;
input int               RegimeExhaustionReversalBonus = 2;
input int               RegimeMomentumContinuationBonus = 1;
input int               RegimeAgainstTrendPenalty = 2;
input int               RegimeRangeChasePenalty  = 2;
input int               RegimeShockPenalty       = 2;
input int               RegimeDeadChaosPenalty   = 4;
input double            RegimeGridShockDistanceFactor = 1.45;
input double            RegimeGridChaosDistanceFactor = 1.80;
input double            RegimeGridTrendAgainstDistanceFactor = 1.25;
input double            RegimeLotShockFactor     = 0.75;
input double            RegimeLotChaosFactor     = 0.60;
input bool              PrintRegimeTuneEvents    = true;

input group "28 — SMART CLIENT SAFETY / RENTAL PROTECTION"
input bool              UseSmartClientSafetyBrain = true;
input bool              ClientSafetyStrictEnforce = false;      // false = warn/tune, true = block entry/grid
input bool              ClientSafetyRequireLicenseWhenRental = true;
input bool              ClientSafetyWarnEmptyWhitelist = true;
input bool              ClientSafetyBlockHighSpread = false;
input bool              ClientSafetyUseLotThrottle = true;
input bool              ClientSafetyUseGridDistance = true;
input int               ClientSafetyMaxSpreadBalanced = 300;
input int               ClientSafetyMaxSpreadSafe = 300;
input int               ClientSafetyMaxSpreadHighHunter = 300;
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ClientSafetyDDWarnPercent
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ClientSafetyDDDangerPercent
input int               ClientSafetyMaxOrdersWarn = 4;   // V249fix: 6 -> 4. With MaxOrders 5 a basket can never hold 6 orders, so this "order pressure" warning was dead code. 4 makes it fire on the second-to-last rung, which is where the warning is actually useful.
input double            ClientSafetyGridDistanceFactor = 1.25;
input double            ClientSafetyDangerDistanceFactor = 1.65;
input double            ClientSafetyLotThrottleFactor = 0.75;
input double            ClientSafetyDangerLotFactor = 0.55;
input bool              PrintClientSafetyEvents  = true;

input group "[NOT WIRED] 29 — FINAL INTELLIGENCE MERGE"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------
input int               FinalMergeWarnScore     = 72;

input group "[NOT WIRED] 30 — PRO RELEASE FINAL / PRESET PACKAGER"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------

input group "[NOT WIRED] 31 — SETTINGS GOVERNANCE / CLIENT INPUT GUARD"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------

input group "32 — CLIENT DASHBOARD / LOG POLISH"
input bool              UseClientDashboardPolish = true;
input string            ClientDashboardViewMode  = "COMPACT";      // PRO / COMPACT / RENTAL / INTERNAL
input bool              ClientDashShowHealthLine = true;
input bool              ClientDashShowRiskBanner = true;
input bool              ClientDashShowReleaseBadge = true;
input bool              ClientDashShowModeAdvice = true;
input bool              ClientDashShowContactLine = true;
input bool              ClientDashCompactDeepReasons = true;
input int               ClientDashReasonMaxChars = 70;
input int               ClientDashDefenseScore   = 58;
input int               ClientDashWarnScore      = 72;
input int               ClientDashProScore       = 86;
input bool              PrintClientDashboardPolishEvents = true;

input group "[NOT WIRED] 33 — FINAL PRESET HARDENING / SAFE CLIENT DEFAULTS"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------
input bool              PresetHardeningUseGridDistance = true;
input bool              PresetHardeningUseLotThrottle = true;

input group "[NOT WIRED] 34 — FINAL AUDIT REPORT / BUILD LOCK"

// ---------------------------------------------------------------------------------------------
// [NOT WIRED] The settings in this group are declared but nothing in the EA reads them, so
// changing any of them has NO effect on trading. They belong to the release / client-preset
// control layer (preset locking, input-range guards, licence and build checks) that was written
// out as settings but never connected to the runtime.
//
// They are kept rather than deleted for two reasons: this EA is rented out, so this layer is
// likely to be wanted eventually, and removing ~90 declarations from a live file is a risk with
// no trading benefit. They cost nothing at runtime - they simply do nothing.
// ---------------------------------------------------------------------------------------------

input group "35 — LIVE VALIDATION PROBE / NO-TRADE DOCTOR"
input bool              UseLiveValidationProbe   = true;
input bool              LiveProbeShowEntryDoctor = true;
input bool              LiveProbeShowGridDoctor  = true;
input bool              LiveProbeShowGateStack   = true;
input bool              LiveProbePrintOnChange   = true;
input bool              LiveProbePrintEveryNewBar = false;
input int               LiveProbeMinBarsForReady = 8;
input int               LiveProbeMaxReasonChars  = 130;
input bool              LiveProbeNoTradeDoctorOnly = true; // true = diagnostic only, no blocking
input bool              PrintLiveProbeEvents     = true;

input group "36 — MICRO SCALP SETTINGS"
input bool              UseMicroScalpLayer       = true;
input ENUM_MICRO_TP_MODE MicroTPMode             = MICRO_TP_AUTO;
input int               FixedMicroTPPoints       = 800;
input int               MicroTPPercentOfMainTP   = 40;
input int               MicroTPMinPoints         = 2000;   // Micro entry TP floor (points)
input int               MicroTPMaxPoints         = 3000;   // Micro entry TP ceiling (points)
input double            MicroDynamicATRMult      = 1.20;
input double            MicroDynamicRoomFactor   = 0.70;
input double            MicroLotFactorBalanced   = 0.80;    // V68b: 0.50 -> 0.80 on user request. Micro entry lot = StartLot x this, so 0.25 x 0.80 = 0.20 - smaller than a full first entry, but not tiny. The first-entry floor below is made micro-aware so this reduction actually survives (at 1.0 the floor previously pushed micro back up to the full 0.25).
input double            MicroLotFactorHighHunter = 0.80;   // V249fix(auto-mode): 1.00 -> 0.80. The micro layer exists to take marginal setups at REDUCED size; at 1.00 the reduction was zero, so the aggressive mode sized a marginal entry exactly like a full-conviction one - and larger than Balanced's 0.80 micro. Matched to Balanced; lower it further if you want Hunter's micro to be the smaller of the two.
input bool              MicroOnlyCGrade          = true;
input bool              MicroAllowBGradeIfPreferred = false;
input bool              MicroRequireSweepOrRejection = true;
input bool              MicroAllowNearZoneEntry  = true;
input int               MicroMaxSpreadPoints     = 300;
input int               MicroMinRoomPercentOfTP  = 70;
input bool              MicroBlockFreshImpulse   = true;
input bool              PrintMicroDecisions      = true;

input group "37 — ENTRY / SIGNAL SETTINGS"
input bool              UseM1EntryClose          = false;     // Wait for M1 bar close before entry (currently off)
input int               MinScoreBalanced         = 4;      // V185b: 6 -> 4. Live readings show base 5-7 and bonus capped at 12, so a qualifying setup arrives at roughly 13 - and with the penalty ceiling at 12, a bar of 6 meant anything past seven points of warning was refused. That is far tighter than intended: a single strong impulse against the entry reaches nine on its own. The bar exists to reject setups that never formed properly, not to arbitrate between the score and the warnings - that is what the caps are for.
input int               MinScoreHighHunter       = 2;      // V185b: 4 -> 2, keeping the same two-point gap below Balanced.

// V129: HIGH HUNTER is deliberately lighter than BALANCED - a lower score bar plus a +1 signal
// bonus, roughly 3 points of slack. That slack was also weakening every protection: a setup with a
// real danger penalty (late entry, undefined zone role, structure against, no room...) could pass
// in Hunter while Balanced refused it. Scaling the accumulated penalty in Hunter by this factor
// keeps Hunter fast on CLEAN setups but as strict as Balanced the moment a warning appears - which
// is what makes AUTO mode safe to leave on.
input double            HunterProtectionPenaltyScale = 1.00;   // V176: 1.75 -> 1.00, disabled. This existed because Hunter used to be structurally lighter than Balanced (lower score bar plus a +1 per-detector bonus), so protections needed scaling up to match. The penalty system has since been rebuilt around three separate group caps and a total cap balanced against the bonus cap - that balance is what now keeps Hunter honest. Multiplying on top of it pushed the penalty to 21 against a bonus ceiling of 12, which no setup could answer: live reading showed base=5 bonus=12 penalty=21, a permanent block.
input int               MaxTotalScorePenalty     = 10;     // V272: 12 -> 10. The group ceilings were raised so ten candle modules would not be compressed into the weight of one, and that worked - but it also means the total now reaches twelve on setups where V249 would have stopped at eight or nine, purely because more groups can contribute. A setup with modest agreement and ordinary objections used to pass and now does not, and nothing about it got worse; only the accounting changed. Ten restores that balance while leaving the total a genuine ceiling.     // V249fix(auto-mode): briefly raised to 16 so a saturated bonus pool could still be out-argued. Reverted: the whole score system - and CounterTrendExceptionalMinScore in particular - is calibrated against a typical final of ~9 that assumes THIS cap. At 16 that same reading fell to 5 (Balanced) / 3 (Hunter) against a release bar of 8, which turned the counter-trend guard back into a hard block with only the 3-hour safety valve behind it. The mode-relative term below is the part that was actually needed. The 'penalties cannot refuse once bonuses saturate' problem is real but belongs to a deliberate re-tune of the whole bonus/penalty balance, not to a single input.
input int               MaxTrendAgainstPenalty   = 6;      // V259: 4 -> 6. Five modules route here - timeframe alignment, the sweep reversal, the liquidity wick, the size progression and the reversal context - and their raw total reaches twenty-eight against a ceiling of four. Seven to one is not a cap, it is a filter deciding which reading survives, and the market was never consulted about which that should be.      // V183: trend conflict sits between the two - it is about the trade, but it is also the most duplicated signal in the system.
input int               MaxConditionPenalty      = 4;      // V259: 3 -> 4. Six modules now route here and reach twenty-five raw. Three was chosen in V255 to undo an overcorrection, which it did; four restores a little of what those readings can express without returning to the six that stopped the EA trading.      // V255: 6 -> 3. Raised from 2 to 6 in V250b so the newer readings (a release arriving, a dead market, the layers splitting) would not be compressed into almost nothing. Six turned out to be too much: with every group at once the total penalty now reaches its ceiling on setups that used to pass, and the EA stopped trading on a live account. Three still lets those readings register without letting this group alone consume a quarter of the total budget.      // V250b: 2 -> 6. This cap was set when the group held only spread and noise readings - things that shape size rather than decide direction. It now also holds a release arriving, a market with no range, and the analysis layers contradicting each other, which together produce seventeen points and were being compressed into two. A release mid-entry and a three-against-three split are reasons not to trade at all, and a cap of two made them nearly invisible.      // V183: conditions stay small on the ENTRY decision. A churning session or a wide spread describes the market, not the trade - and blocking on market description is what cut a high-frequency scalper down to a couple of trades a day. Their full weight still reaches the sizing, which is where it belongs.
input int               MaxQualityPenalty        = 9;      // V183: 4 -> 9. These describe something wrong with the TRADE - no room to the target, a level that cannot be read, entering where the last two baskets lost. They should be able to stop an entry on their own, and at 4 they could not: a setup with every quality warning live still scored well enough to trade.
input int               MaxImpulsePenalty        = 5;      // V185: cap on the impulse family before it enters the quality budget. Counter-impulse, correction exhaustion, recent extreme, sustained exhaustion, impulse correction and forced flow are six readings of one thing - how stretched the move is - and they fire together by design. Five points says it clearly without crowding out everything else.
input int               MaxCandlePenalty         = 8;      // V259: 6 -> 8. Ten candle modules now route here and their combined raw output reaches forty, so the group was compressing ten independent readings into the weight of one - and adding an eleventh would have changed nothing except which of the ten survived the cut. Eight is still a ceiling rather than a licence; the total cap of twelve continues to bound everything.      // V214: ceiling on everything the candle layer can charge. Ten modules read candles and several read the same event - a live rejection, its authorship and the sequence state are three views of one wick. Uncapped they swing the score by thirty-plus points against caps of twelve, which is a layer outvoting the rest by count rather than by being right.
input int               MaxCandleBonus           = 8;      // V259: 6 -> 8, moved with the penalty ceiling. Raising one without the other is what made the scoring one-sided in V255 and stopped the EA trading on a live account.      // V214: and the same ceiling on what they can argue FOR, so the cap does not quietly become a one-sided filter.
input int               MaxStructurePenalty      = 7;      // V227: ceiling on everything the structure layer can charge. Five modules read structure direction - measured shape, swing count, timeframe alignment, pullback detection, break event - and all route into a trend group capped at 4, so 27 points of reading arrived with the force of one. Slightly above the candle budget because structure is the slower and more reliable signal of the two.
input int               MaxStructureBonus        = 7;      // V227: and the same ceiling on what they argue FOR.

// V228: when the ladder should stop. MaxOrders is 7 in every circumstance - the ladder does not know
// that order five in a quiet range and order five into a news spike are different commitments, or
// that a basket six hours old is fighting a market that has moved on from the one it opened in.
input bool   EnableGridDepthLimit        = true;   // Stop at the rung the account can pay for rather than the rung the setting names
input double GridDepthBudgetShare        = 0.75;   // Share of the stop-loss budget the remaining rungs may project into. Below 1.0 so the ladder finishes before the stop rather than at it.
input bool   GridDepthPrintOnUse         = true;   // Log depth caps
input bool   EnableBasketStaleness       = true;   // Notice when the basket is fighting a different market from the one it opened in
input int    BasketStaleAfterBars        = 120;    // Bars before age starts counting - two hours on M1, by which point the setup that opened it is history
input int    BasketStaleFullBars         = 400;    // Bars at which age contributes fully
input double BasketStaleAgeWeight        = 0.40;   // Weight of age alone
input double BasketStaleSessionWeight    = 0.35;   // Weight of the session having handed over - different participants, different range
input double BasketStaleTargetWeight     = 0.30;   // Weight of price having passed the level the basket was aimed at without closing
input double BasketStaleBlockLevel       = 0.70;   // V249fix: 0.65 -> 0.70. The session component is a BINARY 0.35 that fires the instant the session hands over and never decays, so at 0.65 a basket needed only 0.30 more from age - 75% of the ramp, i.e. 330 M1 bars = 5h30m - and additions stopped. A completed 5-rung ladder needs ~37,000 points ($37) of adverse travel, which on XAUUSD routinely takes longer and ALWAYS crosses a session, so most real ladders froze at 2-3 rungs: a directional bet with no recovery mechanism left, holding the account hostage under OneBasketAtATime, on a ladder the affordability gate had already budgeted to full depth. At 0.70: age alone (0.40 max) still cannot freeze it; session+age blocks at 365 bars (6h05m); age+target (0.70) blocks WITHOUT needing a session change - which 0.72 would have made structurally impossible, since the non-session maximum is exactly 0.70. That reachability is why this is 0.70 and not higher: at 0.72 a maximally-old basket that had blown through its target could only be frozen while the clock happened to sit in a different session, and would RESUME adding when it returned to the opening session. Note the target component alone, or with only one partner, still does not block - it needs the combination. The real "this premise is dead" gate is BasketPremiseDead(), which runs before staleness and is untouched by this.
input bool   BasketStalePrintOnUse       = true;   // Log stale baskets
input bool   SituationPlanAppliesToGrid  = true;   // V228: keep using the situation and structure targets once the ladder is running. Without this a basket got its measured target on the first entry and then reverted to the estimate chain for every addition - so the target drifted further away with each rung, in a direction nothing had measured. The destination does not change because the ladder grew; only the average entry does.

// V215: candles matter most at a level and least in open space, so their budget scales with where
// price actually is. And when the readings CONFLICT, the conflict is often the information - a
// rejection that was then traded through is not a weaker rejection, it is a defence breaking, and
// summing the two readings cancels the most useful thing either found.
input bool   EnableCandleRelevance       = true;   // Scale the candle budget by proximity to a level
input int    CandleRelevanceReachPoints  = 2500;   // Distance ($2.50) within which candles are reading a level rather than open space
input double CandleRelevanceFloor        = 0.45;   // Budget multiplier in open space - reduced, since a wick there is where the bar turned rather than where a level held
input double CandleRelevanceCeiling      = 1.50;   // And at a strong level, where the question the candle answers is the question that matters
input bool   EnableCandleConflict        = true;   // Read disagreement between candle modules as an event rather than adding them up
input int    CandleConflictScore         = 6;      // Weight of a named conflict - a defence breaking is among the clearest reads available
input double CandleSplitDampen           = 0.50;   // Budget multiplier when readings simply disagree with no story - the layer is undecided and should say less
input bool   CandleConflictPrintOnUse    = true;   // Log named conflicts

// V216: each candle source learns its own accuracy. Ten modules, all trusted equally on the strength
// of their reasoning - reasoning that is sound in general and may be wrong here. Wick authorship
// might read this broker's spread badly; higher-timeframe agreement might be the only thing that
// matters on gold; live-bar evolution might be noise at this tick rate. The code cannot say. So each
// reading is recorded and graded by what price did afterwards, and a source that keeps being right
// earns a louder voice while one that keeps being wrong fades toward silence without ever being
// switched off. Graded per READING, not per trade - a module can be right about direction while the
// trade loses for unrelated reasons, and grading it on the trade would teach the wrong lesson.
input bool   EnableCandleLearning        = true;   // Let each candle source earn or lose weight from its own record
input int    CandleLearningHorizonBars   = 8;      // Bars after a reading before it is graded
input int    CandleLearningDecisivePoints = 600;   // Move ($0.60) that counts as the reading being right or wrong - anything smaller was neither
input int    CandleLearningMinSamples    = 8;      // Graded calls before a source's record is used
input int    CandleLearningMaxSamples    = 50;     // Sample ceiling - conditions change
input double CandleLearningSensitivity   = 0.60;   // How hard accuracy moves the weight. At 0.60 a source right 80% of the time carries 1.36x, one right 20% carries 0.64x.
input double CandleLearningMinWeight     = 0.35;   // Floor - a bad patch quietens a source without silencing one that is fundamentally sound
input double CandleLearningMaxWeight     = 1.60;   // Ceiling - a run of luck cannot let one module dominate
input bool   ShowCandleLearningOnDash    = true;   // Show what each source has learned
input bool   PersistCandleLearning       = true;   // V217: keep the candle records across restarts. Without this the learning resets every recompile and settings change - and since a source needs eight graded calls before its record counts, and eight calls take hours, a record that restarts from zero each session never arrives at anything.
input int    CandleLearningSaveEveryBars = 30;     // How often the records are written back. Every tick is wasteful; only on deinit loses everything when the terminal closes unexpectedly, which it does.
input bool   CandleLearningPrintOnRestore = true;  // Log what was restored at startup

// V218: two gaps a live loss exposed - a buy filled at 4394.43 on a bar that had spiked to 4397 and
// come back, with M5 showing three lower highs behind it.
// THE ENTRY BAR: every other check reads bar 1 and later, so the bar an entry actually opens on was
// never examined. A fill in the upper third of a bar already rejected from its high looked the same
// as a fill at the low of a strong one.
input bool   EnableEntryBarCheck         = true;   // Examine the bar the entry would actually fill on
input ENUM_TIMEFRAMES EntryBarTF         = PERIOD_M1;  // Timeframe of the bar being filled on
input double EntryBarMinSizeATR          = 0.30;   // Bar size against ATR below which the entry bar is too small for its shape to mean anything - a fill anywhere in a tick-sized bar is the same fill.
input double EntryBarBadPlacement        = 0.40;   // V218b: 0.60 -> 0.40. Tested against the actual loss: the fill sat at 49% of the bar\'s range on a bar with a 50% upper wick, and at 0.60 it passed without comment. The wick is what makes the placement bad, so the position threshold has to be low enough for the wick test to be reached at all.
input double EntryBarRejectedWick        = 0.35;   // Wick share that marks the bar as having been pushed back from the extreme being bought toward
input double EntryBarPlacementWeight     = 0.30;   // V218b: 0.45 -> 0.30. More of the severity now comes from the REJECTION rather than the position. A fill halfway up a bar is unremarkable; a fill halfway up a bar that has given back half its range is buying into a sweep.
input double EntryBarMinSeverity         = 0.25;   // V218b: 0.35 -> 0.25, so the case that produced the loss registers rather than falling just under.
input int    EntryBarPenalty             = 6;      // Cost of filling into the wick of a sweep - high, because this is what the loss was
input bool   EntryBarPrintOnUse          = true;   // Log poor entry-bar placement
// THE LOCAL SHAPE: whether each swing high sits below the last. Structure breaks and trend readings
// both lag this, and it is the first thing a trader sees.
input bool   EnableLocalSwingShape       = true;   // Read whether the recent swings are stepping up or down
input ENUM_TIMEFRAMES LocalSwingTF       = PERIOD_M5;  // Timeframe the swings are read on - the scale the setups are built at
input int    LocalSwingLookbackBars      = 60;     // Bars searched for swings
input int    LocalSwingDepth             = 2;      // Bars either side that must be lower/higher for a swing to be confirmed
input int    LocalSwingMinSwings         = 3;      // Swings needed before the shape is read
input int    LocalSwingFullSteps         = 3;      // Consecutive steps at which the shape carries full weight
input int    LocalSwingScore             = 5;      // Weight of entering with or against the swing sequence
input bool   LocalSwingPrintOnUse        = true;   // Log entries taken against the swing shape

// V223: local structure read as SHAPE rather than as an indicator. Local trend is currently ADX,
// which answers "is there a trend" and says nothing about what it looks like - price stepping down
// in measured swings and price collapsing in one leg read the same, and they are different trades.
// The swing count added in V218 is closer, but it only counts; the measurements are where the
// information is. How far each step travels separates a trend with participants from a drift. Whether
// the steps grow or shrink says whether the move is being fed or running out - the last swing before
// a turn is almost always the smallest. And a sequence of lower highs has a specific price above
// which it stops being one, which defines both the invalidation and the target of any counter-trade.
input bool   EnableLocalStructure        = true;   // Measure the swing structure, not just its direction
input ENUM_TIMEFRAMES LocalStructureTF   = PERIOD_M5;  // Timeframe the structure is measured on
input int    LocalStructureLookbackBars  = 80;     // Bars searched for swings
input int    LocalStructureDepth         = 2;      // Bars either side that confirm a swing
input int    LocalStructureMinSwings     = 3;      // Swings needed before the structure is read
input int    LocalStructureFullSteps     = 3;      // Consecutive steps at which conviction is full
input double LocalStructureMinLegATR     = 0.60;   // Swing size against ATR below which the legs are drift rather than structure
input double LocalStructureExpandThreshold = 0.25; // Growth in leg size that marks an accelerating move
input double LocalStructureFadeThreshold = 0.25;   // And shrinkage that marks one running out
input double LocalStructureExpandFactor  = 1.25;   // Weight multiplier when the structure is accelerating
input double LocalStructureFadeWithFactor = 0.55;  // Trading WITH a fading structure is late
input double LocalStructureFadeAgainstFactor = 0.70; // And against it is early, but a turn is genuinely possible
input int    LocalStructureScore         = 5;      // Weight of trading with or against the measured structure
input int    LocalStructureNearInvalidation = 1200; // Distance ($1.20) at which the structure's end price is close enough to make a counter-trade's risk defined and cheap
input int    LocalStructureInvalidationBonus = 2;  // Credit for that
input bool   LocalStructurePrintOnUse    = true;   // Log structure readings
input bool   ShowLocalStructureOnDash    = true;   // Show the measured structure

// V224: the invalidation price put to work. V223 computes the price at which the local structure
// stops existing and then uses it for a two-point bonus, which is the least valuable thing that
// number can do. It is the only price on the chart with a precise meaning - above it a downtrend is
// not a downtrend, by definition rather than by threshold.
input bool   EnableStructureBreak        = true;   // Treat a structure ending as an event, not something noticed a bar later
input int    StructureBreakFreshBars     = 10;     // How long a break stays relevant - by twenty bars whatever it started has already happened
input int    StructureBreakScore         = 6;      // Weight of a fresh break. High: this is the measured thing changing state, not an indicator crossing a line.
input bool   StructureBreakPrintOnUse    = true;   // Log structure breaks
input bool   EnableStructureTarget       = true;   // Use the invalidation price as the target for a counter-structure trade
input double StructureTargetReachFactor  = 0.85;   // Stop short of it, as with any level-based target
input bool   StructureTargetPrintOnUse   = true;   // Log structure-based targets
input bool   EnableStructureConfluence   = true;   // Notice when the structure ends where a zone sits
input int    StructureConfluenceTolerance = 700;   // How close ($0.70) the two must be to count as the same price
input double StructureConfluenceMinWeight = 0.35;  // Agreement below which it is coincidence rather than confluence
input int    StructureConfluenceScore    = 3;      // Credit for two independent readings landing on one price

// V225: structure across timeframes, and how far it has already run. The measured structure reads
// one scale and treats what it finds as the answer; it is one answer at one scale, and the scale
// above usually decides what it means. Three lower highs on M5 inside a rising M15 is a pullback,
// and trading it as a downtrend means selling the dip of an uptrend - indistinguishable from the
// real thing without looking up. Reading three also produces something none has alone: their
// RELATIONSHIP - full agreement, a pullback, or a transition where nothing is settled.
input bool   EnableStructureMTF          = true;   // Read the structure on three timeframes and use their relationship
input ENUM_TIMEFRAMES StructureMTFMiddle = PERIOD_M15;  // The scale above the one structure is measured on
input ENUM_TIMEFRAMES StructureMTFHigher = PERIOD_H1;   // And above that
input double StructureAlignFullBoost     = 1.20;   // Extra weight when all three agree - the rarest condition on the chart
input int    StructureAlignScore         = 6;      // Weight of trading with or against full agreement
input int    StructurePullbackScore      = 5;      // Weight of reading a pullback correctly - or of trading it as if it were the trend
input int    StructureTransitionPenalty  = 3;      // Cost of committing while the timeframes are still deciding
input bool   StructureMTFPrintOnUse      = true;   // Log the timeframe picture
input bool   EnableStructureMaturity     = true;   // Measure how far the structure has already travelled
input double StructureMatureATR          = 6.0;    // Distance in ATR at which a structure has gone as far as these usually go
input double StructureMatureFrom         = 0.55;   // Share of that distance before joining late starts costing
input int    StructureMaturityScore      = 4;      // Weight of joining a finished move, or of fading one

// V226: one line saying whether any of this is working. Twenty modules were added in a single
// session and not one was ever observed running - balanced braces prove the file compiles and prove
// nothing about whether a detector finds what it was written to find. That is how a session ends
// with an EA taking two trades in twelve hours: each module looked reasonable, none was verified,
// and the failure only surfaced when the account stopped trading. "Answering" means the module ran
// and returned something coherent, not that it found a signal - a pattern detector correctly finding
// no pattern is healthy, one that cannot read its candles is not, and until you ask directly the two
// look identical.
input bool   EnableModuleHealth          = true;   // Check each module is answering and show the count
input bool   ShowModuleHealthOnDash      = true;   // Show it on the dashboard
input bool   ShowSilentModuleNames       = true;   // And name anything that is not answering
input bool   ShowDetailedDiagnostics     = false;  // V226: the per-module detail lines. Off by default now that the health count says whether they are working - twenty diagnostic lines nobody reads are worse than one number that gets checked. Turn on when investigating something specific.
input bool   ShowLegacyModuleLines       = false;  // V226b: the per-pack status lines (GRID, DRI, DXB, PACK2, PACK3, RC, P4M, P4L, RCB, FSA, RLS, DCS, NIM, FPR, SGV, CDP, DPH, FBL, LVP, WCP, PV). Twenty-one lines that were useful while each pack was being built and are now noise - the summary and health count cover what they were watched for. Turn on to inspect a specific pack.
input bool   DashboardFullDetail         = false;  // V226b: the master switch for everything beyond the essentials. The dashboard had grown to a hundred and forty lines, which is past the point where anyone reads it - and an unread dashboard is the same as no dashboard, which is how a stalled EA went unnoticed for hours. What stays on: the version and status line, the account and risk figures, the current mode, ENV, the basket, the market and score block, the module health count, and whatever is currently blocking a trade. Everything else is one setting away when it is needed.
input bool   ShowDashboardLineCount      = true;   // V227b: print the line count at the bottom. Static analysis of which lines are visible kept disagreeing with what actually appeared on screen - the guards nest three deep in places - so the EA counts them itself.
input bool   EnableGridStructureCheck    = true;   // V225: let the grid see the structure's invalidation price. Additions belong inside the structure the basket is fighting, not beyond it - past that point the structure has to be wrong for the basket to be right.
input double GridDoubtStructureAgainst   = 0.30;   // Weight added to grid doubt when price has left the structure the basket was opened inside

// V233: the grid reads structure and timeframes and never looks at the bar in front of it. So an
// addition goes in during the exact candle driving price away from the basket - the worst moment
// available, because the size is committed at the fastest part of the adverse move and the next
// addition then has to be larger still. These are the same readings the entry engine uses, applied
// to the decision they never covered.
input bool   EnableGridCandleRead        = true;   // Let the grid see the candles before adding
input double GridDoubtBigBarWeight       = 0.30;   // Weight of a single dominant bar running against the basket
input double GridDoubtPressureWeight     = 0.25;   // Weight of a run of closes going the wrong way
input double GridDoubtLiveBarWeight      = 0.20;   // Weight of the bar currently forming, scaled by how much of it has happened

// V236: from two live stop-outs - a buy at the top of a $24 run that then fell $48, and a sell at
// the bottom of a $99 decline that then rose $32. Both baskets opened at the end of a move, and in
// both the grid kept adding into the reversal. The entry engine reads move maturity and refuses
// these; the grid never did, so once a basket exists the ladder walks into the same extended move
// the entry side would have rejected - each rung larger than the last. An adverse move that has
// already run its usual distance is what the ladder is worst suited to, because it does not retrace
// on the schedule the arithmetic assumes.
input bool   EnableGridMaturityCheck     = true;   // Let the grid see how far the move against it has already gone
input double GridMaturityFrom            = 0.60;   // Share of a structure's usual distance before adding into it starts counting against the basket
input double GridDoubtMaturityWeight     = 0.35;   // Weight of a mature adverse structure
input double GridDoubtExtensionWeight    = 0.25;   // Weight of the adverse move being past its climax point - the same threshold the entry engine waits at

// V240: the assumption under the whole ladder. Every grid rests on price coming back - the
// multiplier, the spacing and the recovery arithmetic only work if that holds. It holds in a range
// and fails in a trend, where the ladder adds size in the direction price is leaving until the
// account settles the matter. The EA classifies the market and the grid never read it: GridCanOpen
// checks MARKET_IMPULSE and nothing else. Both live stop-outs were ladders built against a trend.
input bool   EnableGridRegimeCheck       = true;   // Let the grid see whether the regime supports its premise
input double RegimeAgainstBase           = 0.45;   // Baseline weight when the ladder runs against a classified trend
input double RegimeAlignedBonus          = 0.25;   // Added when all timeframes confirm that trend - three scales agreeing is a trend, one is a reading
input double RegimeExpandingBonus        = 0.20;   // Added when the trend is still making new extremes against the basket
input double RegimeFadingRelief          = 0.20;   // Subtracted when it is fading - a trend running out is when the ladder's premise starts working again
input double GridDoubtRegimeWeight       = 0.40;   // How much regime contradiction counts toward holding additions. The heaviest single input, because it questions the premise rather than the timing.
input double GridQualityRegimeWeight     = 0.30;   // And how much it reduces the size of an addition that still goes ahead

// V241: the shape of the ladder. The grid is always the same - seven rungs, 1.30x, even spacing.
// Distance adapts through half a dozen modules; the shape never does. But a strong level just
// behind the entry calls for two or three close rungs at full size, and a trend running against the
// basket calls for more rungs, each smaller, spaced wide - survival rather than recovery speed.
// Chosen at the START, because every rung after the first is constrained by the ones before it.
input bool   EnableLadderShaping         = true;   // Choose the ladder's shape when the basket opens
input int    LadderAnchorMaxDistance     = 2500;   // How far behind ($2.50) a level can be and still anchor a short ladder
input double LadderAnchorMinStrength     = 1.8;    // Level strength worth building a short ladder against
input int    LadderShortOrders           = 3;      // Rungs when leaning on a level - if it holds this is enough, if it fails more would not have helped
input double LadderShortSpacing          = 0.75;   // Spacing factor, tighter - the level is close and the recovery should be too
input double LadderLongFromContradiction = 0.50;   // Regime contradiction above which the ladder is built for survival
input int    LadderLongExtraOrders       = 0;      // V249fix: 2 -> 0. The "long" shape ALSO widens spacing (LadderLongSpacing 1.30), so +2 rungs on top made it by far the most expensive shape - ~$7.4k projected vs the ~$4.2k budget, i.e. the affordability gate (which must assume the worst shape, since the shape is chosen after the entry) would have gone on refusing every entry even at MaxOrders 5. At 0 - and with LadderLongSpacing also back to 1.00 - the long shape now differs from default ONLY by its gentler multiplier: same rung count, same spacing, so it is strictly SMALLER than the default ladder rather than longer. That is the safe direction and it is what keeps the worst-case shape inside the budget, but be aware the "built to survive a long trend" character is largely neutralised. Restore depth here only together with a bigger balance or a lower StartLot/MaxOrders.   // Extra rungs when against a trend
input int    LadderMaxOrdersCap          = 9;      // Absolute ceiling regardless of shape
input double LadderLongMultReduction     = 0.10;   // How much the multiplier drops - smaller rungs, since there may be many of them
input double LadderLongSpacing           = 1.00;   // V249fix: 1.30 -> 1.00. Wider spacing multiplies on top of the grid's own geometric widening, which made "long" by far the most expensive shape (~$4.6k projected vs a ~$4.2k budget on a ~$10k account) - and since LadderIsAffordable() must assume the worst shape the engine could pick, that one shape alone kept refusing EVERY first entry even at MaxOrders 5. The long ladder still differs from default through its gentler multiplier (LotMultiplier - LadderLongMultReduction). Raise again only with a bigger balance or a lower MaxOrders/StartLot.   // And wider spacing, since the move may run
input int    LadderCautiousFewerOrders   = 2;      // Rungs removed when nothing is readable
input double LadderCautiousMultReduction = 0.08;   // And the multiplier reduction that goes with it
input bool   LadderShapePrintOnUse       = true;   // Log the chosen shape

// V242: what the system is actually earning. A grid produces a very high win rate and that number
// says almost nothing - most baskets close at target for a small amount and the occasional one stops
// out for ten times that. Eighty-five percent wins can be a losing system, and it looks like a
// winning one on every screen the EA draws. This computes the only figure that settles it: what an
// average basket is worth. Not a filter - a reading, like looking at the account curve instead of
// the last trade.
input bool   EnableExpectancy            = true;   // Track what an average basket earns
input int    ExpectancyMinSamples        = 15;     // Baskets before the figure means anything
input int    ExpectancyMaxSamples        = 100;    // Window - a figure covering three months of a different market describes that market, not this one
input bool   PersistExpectancy           = true;   // Keep the record across restarts. Fifteen baskets take days to accumulate; starting from zero each session means never arriving at an answer.
input bool   ShowExpectancyOnDash        = true;   // Show it on the dashboard

// V244: can the basket actually get home? BasketHealthIndex measures what has been SPENT - drawdown
// against the stop, rungs against the maximum, margin against the ceiling. Every component answers
// "how much is used up" and none answers the question that decides the outcome: is the target still
// reachable? Five rungs deep with the target four dollars away and five rungs deep with it forty
// cents away look identical on every reading the EA takes.
input bool   EnableBasketReach           = true;   // Measure how far the basket still has to travel
input double BasketReachComfortATR       = 3.0;    // Distance in ATR the basket can cover in an ordinary session
input double BasketReachFarATR           = 10.0;   // Beyond this it is asking for a move the timeframe does not usually produce
input double BasketReachDoubtBelow       = 0.50;   // Reachability below which the next rung starts counting against the basket
input double GridDoubtReachWeight        = 0.30;   // How much an unreachable target counts toward holding additions
input bool   ShowBasketReachOnDash       = true;   // Show the distance and what the next rung would do to it

// V219: zones, candles and structure read as ONE observation rather than three. Falling swing highs,
// price arriving at a support, and a rejection printing there is a downtrend testing a level that is
// holding - one situation, worth more than the sum of its parts because the parts corroborate each
// other. Change one part and the meaning inverts: the same three inputs with the rejection FAILING
// mean the level gave way. Adding scores produces something in the middle, which is wrong in both
// cases.
input bool   EnableSituationRead         = true;   // Read zone, candle and structure together and name what they describe
input int    SituationLevelReachPoints   = 1200;   // Distance ($1.20) within which price counts as being AT the level
input double SituationMinLevelStrength   = 1.4;    // Level strength below which there is nothing to corroborate
input double SituationFullStrength       = 2.5;    // Strength at which the level contributes fully
input double SituationExhaustionBoost    = 1.35;   // Extra weight when the trend arriving at the level is already stretched - the strongest of the four cases, since it is a turn rather than a pause
input double SituationMinWeight          = 0.30;   // Corroboration below which the situation is not named
input int    SituationScore              = 8;      // Weight of a named situation - higher than any single layer, because three layers agreeing is a different thing from one layer speaking
input double SituationSuppressFactor     = 0.40;   // Share of the individual candle contributions kept once a situation is named. The rest is the same evidence a second time.
input bool   SituationPrintOnUse         = true;   // Log named situations

// V220: the situation sets the trade, not just the score. Each of the four calls for a materially
// different trade and the EA was giving all of them the same target and the same grid. A level that
// held is a bounce - the target is the way back across the range and the grid can be tight. A level
// that broke is a continuation - the target is the next level and the grid must be wide, or the
// ladder fills in one leg. A stretched trend refused is a reversal - the largest target, since the
// whole prior move is now the room, and the smallest size, since reversals fail more than they work.
input bool   EnableSituationPlan         = true;   // Let the named situation set target, grid spacing and size
input double SituationTargetReachFactor  = 0.85;   // Stop short of the level rather than at it - the last stretch is where price stalls, and a target sitting exactly on a level often misses by a tick
input int    SituationTargetMinPoints    = 1200;   // Below this the trade does not clear its own costs
input int    SituationTargetMaxPoints    = 6000;   // Above this it is no longer the strategy that was tested
input double SituationGridHeld           = 0.80;   // Grid spacing when a level is holding - a bounce is the premise, so additions can sit closer
input double SituationGridBroke          = 1.35;   // And when it broke - price is travelling, not oscillating
input double SituationGridReversal       = 1.50;   // A failed reversal fails hard; wide spacing buys room to be wrong
input double SituationLotHeld            = 1.00;   // A level holding within a range is the most repeatable of the four
input double SituationLotBroke           = 0.90;   // Continuations run, but the entry is chasing
input double SituationLotReversal        = 0.75;   // Reversals fail more often than they work

// V231: the broken level that held from the other side. The EA could see both halves of this and
// never joined them - StructureBreak records the level being taken, ZoneRetest finds price returning
// to it, and separately they are a break and a retest. Together they are the highest-quality
// continuation available: what was resistance is now support, everyone who sold it is wrong, and the
// move that broke it has already demonstrated it can.
input bool   EnableBrokenRetest          = true;   // Recognise a broken level being retested from its new side as one situation
input int    BrokenRetestTolerance       = 900;    // How close ($0.90) price must return to count as retesting rather than merely being nearby
input double BrokenRetestMinStrength     = 1.5;    // Level strength worth retesting. A minor swing breaking and being retested is price moving; a level with history changing sides is structural.
input double BrokenRetestWeightBoost     = 1.25;   // Extra weight over the other four situations - this one has the clearest invalidation and the most participants already positioned against it
input double SituationGridRetest         = 0.85;   // Grid spacing here. Tight, because the invalidation sits just the other side of the level - if price goes back through, spacing will not save the basket.
input double SituationLotRetest          = 1.00;   // Full size - the most repeatable of the five

// V232: from a live loss - M1 broke a resistance and the retest read clean, while on M5 and M15 the
// level had never gone anywhere and a long wick was sitting right on it. The EA bought a break that
// only existed at the resolution it happened to be watching, into the place stops had collected.
input bool   EnableBrokenRetestMTF       = true;   // Require the break to survive being looked at from further away. A level the higher timeframe still shows intact is not a broken level - it is a level being tested, with price on the wrong side of it.
input ENUM_TIMEFRAMES BrokenRetestConfirmTF = PERIOD_M15;  // The scale the break must also have cleared
input bool   EnableBrokenRetestWickCheck = true;   // Reject a retest sitting under a long higher-timeframe wick. Stops collect there, price is drawn to them, and what looks like support holding is often price being pulled through it.
input int    BrokenRetestWickBars        = 6;      // Higher-timeframe bars searched for such a wick
input double BrokenRetestWickMinRatio    = 0.40;   // Wick share of its bar's range before it counts as liquidity rather than noise
input int    BrokenRetestWickTolerance   = 1000;   // How close ($1.00) the wick's tip must come to the level
input bool   BrokenRetestPrintOnUse      = true;   // Log rejected retests
input bool   SituationPlanPrintOnUse     = true;   // Log the plan a situation produces

// V221: the grid decides WHERE to add, not only when. Distance says an addition is due; it says
// nothing about whether the addition is a good idea, and the grid has never separated those.
// DIRECTION: the first entry passes forty modules deciding the direction is right. Additions inherit
// that and are never re-tested, so a basket opened into what looked like a pullback keeps adding
// while the pullback becomes a trend change - each addition larger than the last. When the premise
// is gone the grid HOLDS: it does not close, because closing into a move that has just gone against
// the basket realises the loss at its worst point. What stops is the compounding.
input bool   EnableGridDirectionCheck    = true;   // Re-examine the basket's direction before each addition
input double GridDoubtSwingWeight        = 0.35;   // Weight of the swing sequence turning against the basket
input double GridDoubtStructureWeight    = 0.25;   // Weight of a structure break against it
input double GridDoubtHTFWeight          = 0.20;   // Weight of the higher-timeframe candle disagreeing
input double GridDoubtSituationWeight    = 0.40;   // Weight of a named situation pointing the other way - three layers agreeing, so the heaviest single input
input double GridDoubtBlockLevel         = 0.60;   // Accumulated doubt at which additions are held. Deliberately high: the grid exists to recover from being wrong, so it must not stop at the first sign of it.
// LOCATION: the arithmetic puts the addition wherever the multiplier lands. A strong level just
// beyond that is where the addition belongs - adding above it buys the last of the move rather than
// the thing that stops it.
input bool   EnableGridLevelSnap         = true;   // Wait for a nearby level rather than adding at the arithmetic price
input double GridSnapMinStrength         = 1.6;    // Level strength below which it is not worth waiting for
input int    GridSnapMaxShiftPoints      = 1500;   // How much further ($1.50) the addition may be moved - beyond this it is a different trade, not a better fill
input double GridSnapMinSpacingFactor    = 0.85;   // Minimum spacing retained relative to the account rules

// V222: the size of an addition should match its quality. The ladder multiplies by 1.30 regardless
// of where the addition lands, so the largest commitment of the basket - order seven, four times the
// starting size - goes in at the deepest point of the drawdown, at whatever price the arithmetic
// produced, with no reading of whether that price is worth defending. Size still has to grow or the
// recovery does not work; what changes is that it grows MORE where there is something to add against
// and LESS where there is not.
input bool   EnableGridQualityLot        = true;   // Size each addition by how good its location is
input int    GridQualityLevelTolerance   = 800;    // How close ($0.80) a level must be for the addition to count as landing on it
input double GridQualityFullStrength     = 2.2;    // Level strength at which the location credit is full
input double GridQualityLevelWeight      = 0.35;   // Credit for adding against a real level rather than into open space
input double GridQualityDoubtWeight      = 0.30;   // Cost of the basket's direction having deteriorated since it opened
input double GridQualityDeepFrom         = 0.50;   // Share of the stop-loss budget used before depth starts reducing size - the deepest additions decide whether a basket survives and are the least reversible
input double GridQualityDeepWeight       = 0.25;   // How much depth reduces the addition
input double GridQualityBigBarWeight     = 0.25;   // V233: how much a dominant bar shifts the addition's size. Against the basket it is filling at the worst price of an adverse push; with the basket it means the recovery has begun, which the ladder's arithmetic cannot see.
input double GridQualityMinFactor        = 0.70;   // Smallest an addition can be trimmed to - below this the ladder stops recovering at the rate it was designed for
input double GridQualityMaxFactor        = 1.15;   // And the most it can be increased at an excellent location
input bool   GridQualityPrintOnUse       = true;   // Log addition quality readings
input int               MaxTotalScoreBonus       = 26;     // V278: 16 -> 26. Live screens show raw penalty running at thirty to forty-seven against a raw bonus of ten to twenty-eight, and the EA not trading at all. There are a hundred and thirty places that can add penalty and roughly a quarter of them were added today; the bonus side never grew with them. Twenty-six lets a setup that eleven modules agree on express that agreement against objections that now come from a much larger pool.     // V255: 12 -> 16. Penalties grew all day - band entries, sweep bars, reversal context, volatility shift, premium depth - and the bonus ceiling did not move with them. A setup can now accumulate twenty points of genuine agreement and have eight of them discarded while every point of objection survives, which makes a strong setup and a marginal one score the same. The two ceilings have to move together or the scoring quietly becomes one-sided.     // V171: 8 -> 12. When V170 raised the penalty cap to 14 it left the bonus cap at 8, so any three moderate penalties outweighed every bonus the EA could produce and the score could not recover no matter how good the setup was. A ceiling on what can argue FOR a trade must not sit below the ceiling on what can argue against it.
input int               MaxTrendAlignBonus       = 8;      // V259: 7 -> 8, moved with the trend-against ceiling so agreement and objection stay symmetric.      // V171: 5 -> 7, in proportion with the total bonus cap above. The trend-agreement group still cannot dominate, but it can now contribute meaningfully within a 12-point budget.
input bool              UseDirectionRedirect     = true;      // If the preferred direction has no signal, look for one in the opposite direction
input bool              RedirectOnlyOnScoreWait  = true;
input bool              RedirectAllowMicro        = true;
input int               RedirectMinScore          = 4;
input int               RedirectMinImprovement    = 1;
input bool              RedirectRespectMarketTrend = true;
input bool              RedirectAvoidChaosImpulse = true;
input bool              PrintRedirectDecisions    = true;
input bool              UseSignalQueue           = true;      // Remember a valid signal for a few bars if it can't fire immediately
input int               SignalQueueBars          = 3;         // How many bars a queued signal stays valid
input bool              EnableQueueReplayRevalidation = true;  // V31.6z33 NEW: real gap found - a replayed queued signal used to fire with its ORIGINAL, now-stale score, bypassing every fresh check built this session
input double            QueueReplayExhaustionBlockThreshold = 0.30;
input double            QueueReplayGlobalLocalBlockThreshold = 0.30;
input int               SignalQueueMaxAgeSeconds = 300;
input int               SignalQueueMaxSpreadPoints = 300;
input bool              SignalQueueRefreshBetter = true;
input bool              SignalQueueExpireOnOppositePass = true;
input bool              SignalQueueReplayWhenCurrentWait = true;
input bool              PrintQueueDecisions      = true;

input bool              UseMissedTradeMemory     = true;
input int               MissedMemoryRepeatThreshold = 2;
input int               MissedMemoryLookbackBars = 8;
input int               MissedMemoryNearPassGap  = 2;
input int               MissedMemoryScoreBoost   = 1;
input bool              MissedMemoryRespectFreshChecks = true;  // V31.6z34 NEW: real conflict found - "kept almost passing" used to justify a forced boost even when today's Exhaustion Consensus / Global-Local Trend correctly, repeatedly say no
input double            MissedMemoryExhaustionBlockThreshold = 0.30;
input double            MissedMemoryGlobalLocalBlockThreshold = 0.30;
input int               MissedMemoryMaxBoost     = 2;
input bool              MissedMemoryBoostOnlyNearPass = true;
input bool              MissedMemoryAllowMicroBoost = true;
input bool              MissedMemoryIgnoreHardBlocks = true;
input bool              MissedMemoryResetOnEntry = true;
input bool              PrintMissedMemoryEvents  = true;

input bool              UseBlockExpiryEngine     = true;
input int               BlockExpiryScoreWeakBars = 3;
input int               BlockExpiryImpulseBars   = 3;
input int               BlockExpiryRoomBars      = 2;
input int               BlockExpiryMicroBars     = 2;
input int               BlockExpiryRedirectBars  = 2;
input int               BlockExpiryBOSBars       = 5;
input int               BlockExpiryZoneBars      = 2;
input int               BlockExpiryMaxSeconds    = 600;
input bool              BlockExpiryAllowExpiredSoftPass = true;
input int               ExpiredBlockScoreBoost   = 1;
input bool              PrintBlockExpiryEvents   = true;
input bool              UseFirstEntryEngine      = true;
input bool              AllowLiveTrading         = true;
input bool              OneBasketAtATime         = true;
input int               FirstEntryCooldownBars   = 0;   // BOSQICH 5A: 1 -> 0. TP dan keyin keyingi savat o'sha M1 barida ham ochilishi mumkin
input int               CloseDeviationPoints     = 3000;  // FIX(exit-slippage-cap): max slippage on EXITS ($3.00). Closes used to inherit OrderSendDeviationPoints (50 = $0.05) from the shared CTrade object, so a basket stop during a news spike was rejected as a requote and simply did not execute - the worst possible moment to fail. A stop that does not fill is far more expensive than one that slips, so keep this well above the entry cap.
input int               CloseRetryPasses         = 3;     // FIX(close-no-retry): how many times the basket close loop re-tries the positions that failed to close. 1 = old single-attempt behaviour.
input int               CloseRetryDelayMs        = 300;   // FIX(close-retry-same-quote): pause between basket-close passes (live only), so a requote is retried at a fresh price instead of the same one
input int               OrderSendDeviationPoints = 50;    // V90b: 30 -> 50 ($0.05). At $0.03 fast XAUUSD moves (impulse/news tick slippage of $0.05-0.20) were getting orders rejected/requoted, which delays a grid add and distorts the spacing. $0.05 lets orders fill on time while still capping how bad a fill can be.
input int               MinSecondsBetweenEntries = 10;   // BOSQICH 5A: 30 -> 10. Ikki marta yuborishdan himoya uchun yetarli
input bool              PrintEntryDecision       = true;
input bool              UseOpportunityScanner    = true;
input bool              ScannerEvaluateOnNewBarOnly = false;
input int               ScannerLookbackBars      = 20;
input int               SweepLookbackBars        = 10;
input int               RangeEdgePercent         = 22;
input int               MinOpportunityScoreC     = 3;
input int               MinOpportunityScoreB     = 5;
input int               MinOpportunityScoreA     = 7;
input bool              ScannerAllowMicroC       = true;
input bool              ScannerAllowRangeEdge    = true;
input bool              ScannerAllowSweep        = true;
input bool              ScannerAllowPullback     = true;
input bool              ScannerAllowExhaustion   = true;
// SAFE-RELAX(unknown-zone-only): when the market state is UNKNOWN, instead of trading nothing,
// allow ONLY the zone-anchored setups (sweep / fake-breakout-return / near-zone reaction). These
// lean on a real S/R level and don't need a defined trend, so they're safe in a directionless
// market. Trend/momentum/breakout detectors stay off in UNKNOWN. Set false for the old behaviour
// (scanner fully idle when UNKNOWN).
input bool              EnableUnknownZoneOnlyScan = true;

// ===================================================================================
// FEATURE(daily-bias): previous-day analysis. Adds three things the bot was missing:
//   1. PDH / PDL (previous day High/Low) treated as first-class strong zones. The D1 zone scan
//      started at shift 2, so it literally skipped YESTERDAY - the single most-watched intraday
//      level set. These are now fed in as real levels with a strength bonus.
//   2. Prior-day close direction (bullish/bearish day) -> a daily bias.
//   3. Today's open vs prior close -> confirms or tempers that bias.
// The bias adds a small score bonus/penalty to entries that agree/disagree with it. It NEVER
// hard-blocks - it's context, not a gate - so it can't make the bot timid.
// ===================================================================================
input group "93 — DAILY BIAS (PDH/PDL + prior-day close)"
input bool   EnableDailyBias              = true;    // Master switch for previous-day analysis
input bool   EnableDailyLevelsAsZones     = true;    // Feed PDH/PDL (and prior close) into the zone system as strong levels
input double DailyLevelStrengthBonus      = 0.5;     // V33b: reduced 1.0 -> 0.5. At 1.0 a PDH/PDL zone reached ~2.2 strength easily (1.0 base + 1.0 daily + touches), which tripped the zone-wall HARD BLOCK (MinStrength 2.2) almost every time price neared yesterday's high/low - and on XAUUSD price is near PDH/PDL constantly. That made the bot sluggish. 0.5 still ranks these levels above ordinary zones (so sweeps/bounces prefer them) without auto-triggering the hard block.
input int    DailyLevelTolerancePoints    = 150;     // A zone within this many points of PDH/PDL counts as "on" that daily level
input bool   EnableDailyBiasScore         = true;    // Apply a score bonus/penalty for agreeing/disagreeing with the daily bias
input int    DailyBiasScoreBonus          = 2;       // Score points ADDED when entry direction agrees with the daily bias
input int    DailyBiasScorePenalty        = 1;       // V33b: separate, SMALLER penalty when entry opposes the bias. Was reusing the full +2 bonus as a -2 penalty, which (with MinScore as low as 6) suppressed too many valid counter-bias entries and made the bot sluggish. Reward agreement, only mildly discourage disagreement.
input double DailyBiasNeutralOpenPoints   = 100;     // Today's open within this many points of prior close = neutral gap (no open-based bias tilt)
input bool   DailyBiasPrintOnUse          = true;
input bool              ScannerAllowMomentum     = true;

input bool              UseSignalScoreEngine     = true;
input bool              UseAntiOverfilterSystem  = true;
input bool              UseDynamicScoreThreshold = true;
input int               MinScoreMicroBalanced    = 4;      // V177b: reverted from 6.
input int               MinScoreMicroHighHunter  = 3;      // V177b: reverted from 5.
input int               ScoreBonusTrendAligned   = 2;
input int               ScorePenaltyTrendAgainst = 2;
input int               ScoreBonusRangeReaction  = 1;
input int               ScoreBonusCleanSpread    = 1;
input int               ScorePenaltySoftSpread   = 1;
input int               ScorePenaltyNoRoomToTP   = 2;
input int               ScoreBonusRoomToTP       = 1;
input int               ScorePenaltyImpulseRisk  = 1;
input int               ScoreHardBlockExtremeSpread = 800;   // FIX(hard-spread-preempts-unified): was 300, the ONLY spread gate in the EA not routed through EffSpread(). Every other one (env 6140, queue, micro, risk) resolves to UnifiedMaxSpreadPoints = 500, so a 300 hard block fired FIRST and made the 500 setting unreachable - the softer stage was dead, exactly the mistake V90b fixed for MaxSpread/CriticalSpread. This is the ABSOLUTE stop tier, so it now matches CriticalSpreadPoints ($0.80). Set to 0 to follow CriticalSpreadPoints automatically.
input int               ScoreMinRoomPercentOfTP  = 55;

input group "38 — MARKET BRAIN SETTINGS"
input bool              UseMarketStateRouter     = true;
input bool              UseTrendDetection        = true;
input bool              UseRangeDetection        = true;
input bool              UseImpulseDetection      = true;
input bool              UseExhaustionDetection   = true;
input bool              UsePullbackLogic         = true;
input ENUM_TIMEFRAMES   SignalTF                 = PERIOD_M1;
input ENUM_TIMEFRAMES   FastContextTF            = PERIOD_M5;
input ENUM_TIMEFRAMES   StructureTF              = PERIOD_M15;
input ENUM_TIMEFRAMES   HTFTrendTF               = PERIOD_H1;
input int               TrendMAPeriod            = 50;
input int               TrendSlopeLookback       = 5;
input int               ATRPeriod                = 14;
input int               RangeLookbackBars        = 24;
input int               RangeMaxPointsBalanced   = 20000;                                       // V55b: 3500 -> 20000. CRITICAL unit fix - this broker quotes XAUUSD with 3 decimals, so 1000 points = $1, NOT 100. The old 3500 meant $3.50 (not the $35 assumed) and briefly 2000 = $2.00, tighter than the basket take-profit itself, so a range was essentially never detected and the bot sat in MARKET_UNKNOWN. 20000 = $20, the value actually intended.
input int               RangeMaxPointsHunter     = 20000;                                       // V55b: 5000 -> 20000, same 3-digit unit fix as the Balanced value above.

// FEATURE(range-breakout): detect when price ESCAPES the range (variant B). While ranging, the bot
// fades the edges (buy low / sell high). But once price breaks out of the range with conviction,
// that edge-fade is exactly the wrong trade - the user saw SELL at the top just as price broke up
// and ran. This detects a genuine breakout (a strong-bodied close beyond the boundary, not a wick
// poke), so we can (1) block the counter-breakout edge fade and (2) allow an entry WITH the break.
input ENUM_TIMEFRAMES RangeBreakoutConfirmTF = PERIOD_M5;  // V56b NEW: timeframe the breakout candle is confirmed on. MUST match the timeframe the range itself is measured on (FastContextTF), otherwise a noisy single M1 candle can declare a "breakout" of an M5-derived range - which would block the very range-edge fades that range detection exists to enable.
input bool   EnableRangeBreakout          = true;   // Detect and act on price breaking out of the range
input int    RangeBreakoutBufferPoints    = 120;    // Close must clear the range edge by this many points to count as a breakout (filters noise at the edge)
input double RangeBreakoutMinBodyFraction = 0.55;   // The breakout candle must be at least this fraction body (not a wick) - a conviction move, not a fakeout poke
input bool   RangeBreakoutBlockCounterFade = true;  // Block the range edge-fade that fights a confirmed breakout (the SELL-at-top-of-upbreak case)
input bool   RangeBreakoutAllowWithEntry  = true;   // Allow a first entry in the breakout direction (trade WITH the break)
input int    RangeBreakoutMaxAgeBars      = 12;     // V56b NEW: how many bars the stored range boundaries stay valid after the last confirmed range. Without this the boundaries never expire, so once a range ended the detector would keep reporting a breakout of it forever and permanently veto one direction.
input int               DeadATRThresholdPoints   = 350;
input double            ImpulseATRMultiplier     = 2.20;
input int               ImpulseMinPoints         = 1600;
input int               ImpulseDirectionLookbackBars = 3;   // Bars used to decide the impulse's DIRECTION from its net move (was effectively 1 - a single spike candle could flip it). 3 reads the thrust across the impulse, not the last candle's noise.

// FEATURE(sustained-impulse): the single-bar impulse test only catches a sharp one-candle burst. A
// slow, grinding, pullback-free decline (or rally) - price bleeding one direction for hours with no
// retrace - is ALSO an impulse but every individual bar is small, so it was read as a range/ordinary
// trend. Measure "directional efficiency" over a window: net move / total path travelled. A high
// ratio means price went almost straight (few pullbacks) = a real sustained impulse, however slow.
// Live example it must catch: an $56 M15 slide over ~8h with tiny bars but ~0.78 efficiency.
input bool              EnableSustainedImpulse       = true;   // Also flag a slow but pullback-free move as an impulse
input ENUM_TIMEFRAMES   SustainedImpulseTF           = PERIOD_M15; // Timeframe the window is measured on
input int               SustainedImpulseLookbackBars = 16;     // Window length (16 x M15 = 4 hours)
input int               SustainedImpulseMinNetPoints = 15000;  // Minimum NET move over the window (15000 = $15); smaller moves are just noise
input double            SustainedImpulseMinEfficiency = 0.65;  // Net/path ratio required (0.65 = fairly one-directional). Choppy back-and-forth sits ~0.2-0.4 and is correctly ignored.

// FEATURE(sustained-impulse-exhaustion): the ATR-based ImpulseEndHardBlock only fires on huge (7x
// D1 ATR ~ $175) moves, so a normal M15/M5 sustained impulse could run to its end and the bot would
// still add entries in its direction right as it reversed - a classic deep-DD cause. Detect the END
// of a sustained impulse on ITS OWN timeframe: a rejection wick against the impulse direction on the
// latest bar PLUS the directional efficiency dropping below its threshold (the clean one-way move
// has started to stall). Both together = exhaustion; either alone is too easy to trip on noise.
input bool              EnableSustainedExhaustion    = true;   // Penalise adding in the impulse direction once a sustained impulse shows exhaustion
input double            SustainedExhaustionWickRatio = 0.45;   // Rejection wick (against impulse dir) must be at least this fraction of the bar's range
input int               SustainedExhaustionPenalty   = 4;      // Score penalty for entering the impulse direction at its exhausted end

// FEATURE(counter-impulse-block): entering AGAINST a strong impulse while it is still running (not
// yet exhausted) is a classic loss - the screenshot showed SELLs placed into a live $60 up-thrust
// that kept going. The impulse-correction penalty only fires once a pullback has started (retrace>0);
// this covers the earlier, more dangerous case where the impulse is still pushing and there is no
// pullback yet. If a spike or sustained impulse is active and the entry opposes it, block - UNLESS
// the impulse is already showing exhaustion (then a reversal entry is reasonable, so we let it pass).
input bool              EnableCounterImpulseBlock     = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              CounterImpulseHardBlock       = false;  // V186: hard blok -> jazo. impulsga qarshi kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // true = hard block; false = score penalty only
input int               CounterImpulseScorePenalty    = 5;      // Penalty when not hard-blocking
input int               CounterImpulseMaxAgeBars      = 20;     // V177c: 45 -> 20 bars. This is how long the block may hold before releasing regardless of exhaustion. The exhaustion test needs a 45% rejection wick, which a move that simply fades never prints - so this is the only release most blocks will ever get. Twenty M1 bars is long enough that a live impulse still gets respected, short enough that a stalled one stops costing entries.

// V180: safety valve over the whole block set. Each hard block releases on its own condition and
// each is reasonable alone, but none of them can see the others - one condition hands over to the
// next and the EA can sit out for hours without any single check being wrong. Live evidence for
// this: half an hour of silence traced to two separate blocks overlapping. Past this limit, one
// entry is allowed through; the blocks are unchanged, they simply stop compounding into a halt.
input bool   EnableBlockSafetyValve      = true;   // Allow one entry through after a prolonged run of blocked bars
input int    BlockSafetyValveBars        = 180;    // Bars (core TF) of continuous blocking before the valve opens - 180 M1 bars is three hours. Long enough that genuine protection is respected, short enough that a stuck block set does not cost a session.
input bool   BlockSafetyValvePrintOnUse  = true;   // Log every time the valve opens, and which block was holding
input bool              CounterImpulsePrintOnUse      = true;   // Log when the impulse block engages and releases

// FEATURE(correction-exhaustion): the screenshot's right-hand loss - after a DOWN move, price
// corrected UP a long way, the bot bought at the TOP of that correction, then the down-move resumed
// and left the basket in DD. The counter-impulse block (v94) doesn't catch this because the buy is
// WITH the up-correction, not against a live impulse; and the impulse-correction penalty stops firing
// once the retrace is deep. This block targets the correction's EXHAUSTION: main trend down, a
// sizeable counter-trend correction up, and that correction now stalling (rejection wick + slowing).
// Entering in the correction's direction there is fading the main trend right as it's about to
// resume - block it. Symmetric for an up main trend with a down correction.
input bool              EnableCorrectionExhaustion    = true;   // Block a counter-trend entry at the top/bottom of a tiring correction
input bool              CorrectionExhaustionHardBlock = false;  // V181: hard blok -> jazo. korreksiya charchashi - v24 da bunday blok yo'q edi va bot ishlardi; hard blok o'rniga jazo yetarli. Blok savdoni butunlay to'sadi; jazo esa kuchli setupга o'z fikrini bildirish imkonini beradi - bu yuqori chastotali scalperда muhim farq.   // true = hard block; false = score penalty
input double            CorrectionExhaustionMinRetrace = 38.0;  // Correction must have retraced at least this % of the impulse to count as a "sizeable" correction worth fading
input double            CorrectionExhaustionWickRatio = 0.40;   // Rejection wick against the correction must be >= this fraction of the bar range
input int               CorrectionExhaustionPenalty   = 5;      // Score penalty when not hard-blocking
input int               CorrectionExhaustionWindowBars = 25;    // Only within this many bars of the impulse

// FEATURE(recent-extreme): the screenshot's left-hand loss - price fell into a bottom, the bot sold
// AT that bottom (in the move's own direction), then price turned up and left the SELL in long DD.
// This isn't a sustained impulse (so v90 exhaustion misses it) and it's not counter-trend (so the
// counter-impulse block misses it) - it's entering in the direction of a move that has just reached
// its extreme and is showing a rejection wick. General guard: over a recent window price made a net
// move, the current price sits near that window's extreme in the move direction, and the latest bar
// prints a rejection wick against the move. Entering WITH the move there is buying the high / selling
// the low. Block it.
input bool              EnableRecentExtremeBlock     = true;    // Block entering in a move's direction at its exhausted recent extreme
input bool              RecentExtremeHardBlock       = false;  // V181: hard blok -> jazo. yaqin ekstremum - xuddi shu sabab. Blok savdoni butunlay to'sadi; jazo esa kuchli setupга o'z fikrini bildirish imkonini beradi - bu yuqori chastotali scalperда muhim farq.    // true = hard block; false = score penalty
input int               RecentExtremeWindowBars      = 10;      // Window (SignalTF bars) to measure the recent move and its extreme
input double            RecentExtremeMinMovePoints   = 2500.0;  // Net move over the window must be at least this (3-digit points; 2500 = $2.5) to be a "move" worth fading
input double            RecentExtremeNearPercent     = 33.0;    // Current price must be within this % of the window range to the extreme (33% = top/bottom third). The screenshot SELL sat ~30% off the low, so a tight 25% quarter would miss it; a third fits "near the extreme" better.
input double            RecentExtremeWickRatio       = 0.40;    // Rejection wick against the move on the latest bar must be >= this fraction of the bar range
input int               RecentExtremePenalty         = 5;       // Score penalty when not hard-blocking

// FEATURE(spike-impulse): the OTHER kind of fast move - a single bar that blows out several times
// its own ATR (an M5 candle throwing $20, or M1 suddenly flying). The sustained detector above is
// for slow grinds; this is for the violent one-candle burst. Flagging it as an impulse lets the
// downstream guards (collapse-bottom, impulse-end, exhaustion) treat the aftermath cautiously
// instead of chasing the spike. Checks both M1 and M5 so a burst on either shows up.
input bool              EnableSpikeImpulse           = true;   // Flag a single candle that is several x ATR as a sharp impulse
input double            SpikeImpulseATRMultiple      = 4.0;    // A bar counts as a spike when its range >= this many x its own ATR (4.0 = a violent, well-above-normal candle)
input int               SpikeImpulseMinPoints        = 8000;   // AND the bar must be at least this big in absolute terms (8000 = $8), so a spike during a dead low-ATR patch still has to be a real move

// FEATURE(recent-thrust): live-trading gap found by the user - price arrived at a resistance WITH a
// strong impulse and the bot still sold the level, then the thrust broke through and the trade lost.
// The two existing impulse detectors both miss this shape: SpikeImpulse needs $8 in a SINGLE bar
// (far too big), and SustainedImpulse measures M15 x 16 bars = 4 HOURS (far too slow for a scalp).
// Neither sees the common case: "$3-6 of one-directional move over the last 10-20 minutes". This
// detector fills that middle band on the signal timeframe, so the counter-impulse guard and the zone
// filter below can finally see a thrust arriving into a level.
input bool              EnableRecentThrust           = true;   // Detect a recent short-horizon thrust (fills the gap between single-bar spikes and 4-hour sustained moves)
input ENUM_TIMEFRAMES   RecentThrustTF               = PERIOD_M5;   // V267: M1 -> M5, same reason. A thrust measured over M1 bars is a thrust inside one M5 candle.
input int               RecentThrustLookbackBars     = 15;     // Window length in bars (15 x M1 = last 15 minutes)
input int               RecentThrustMinNetPoints     = 3000;   // Minimum NET move over the window (3-digit: 3000 = $3.00) to count as a thrust

// V204: consecutive closing pressure. The distance-based thrust check asks whether price covered
// $3 in fifteen bars - which catches a fast run but misses three or four strong candles closing the
// same way over a dollar or two. The distance is unremarkable; the sequence is not, and taking the
// other side mid-push has been producing quick losses. Read as timing rather than direction: the
// entry waits for the run to break, which is a bar closing against it or a doji - a specific,
// observable end rather than an arbitrary delay.
input bool   EnableConsecutivePressure   = true;   // Read runs of same-direction closes, not just distance covered
input ENUM_TIMEFRAMES ConsecutivePressureTF = PERIOD_M5;   // V267: M1 -> M5. This module produces a DIRECTION - three closes in a row one way - and on M1 three closes is three minutes, which is inside a single M5 candle. A run that short describes the inside of one bar rather than pressure in the market, and it was voting on direction with the same weight as readings drawn from real structure. Small timeframes are for timing; direction has to come from a scale where a run of bars means something.
input int    ConsecutivePressureLookback = 6;      // How far back to follow the run
input int    ConsecutivePressureMinRun   = 3;      // Candles closing the same way before it counts as a push
input double ConsecutivePressureMinBody  = 0.55;   // Body as a share of the bar's range - below this the candle was attempted rather than achieved, and the run ends
input int    ConsecutivePressureMinPoints = 900;   // Ground the run must have covered ($0.90) - consistent small bodies in a tight range are not force
input bool   ConsecutivePressureArms     = true;   // Hold the entry until the run breaks, rather than only penalising it
input int    ConsecutivePressurePenalty  = 3;      // Penalty per candle beyond the minimum run, when not arming
input int    ConsecutivePressureMaxPenalty = 9;    // Ceiling on that penalty
input bool   ConsecutivePressurePrintOnUse = true; // Log entries taken against a live run

// V229: the single strong candle. Eight modules guard against entering into an impulse and none
// fires on one bar - consecutive pressure needs three candles, recent thrust needs $3 over fifteen
// bars, spike detection needs $8. Every threshold assumes a SEQUENCE, because that is what an
// impulse usually looks like. But the expensive case is one bar: a strong close, a counter-setup
// immediately after, and the EA taking the other side while whoever produced that bar is still
// there. Measured against the recent average rather than a fixed distance, since what counts as a
// large bar at 03:00 and at 14:30 are different numbers.
input bool   EnableSingleCandleGuard     = true;   // Respect a single dominant candle, not only sequences
input ENUM_TIMEFRAMES SingleCandleTF     = PERIOD_M5;   // V267: M1 -> M5. This compares a bar to its recent neighbours, which works on either scale - but the conclusion it feeds is directional, and an M1 bar three times the size of its neighbours is routinely just the open of an M5 candle. On M5 a dominant bar is an event.
input int    SingleCandleLookback        = 12;     // Bars defining what a normal candle is here
input double SingleCandleMinRatio        = 2.2;    // Size against that average before the bar counts as dominant
input double SingleCandleFullRatio       = 3.2;    // V229b: 4.0 -> 3.2. Tested against the case this was built for - a $1.20 bar against a $0.45 average is 2.7x, which is plainly a dominant candle, and at a 4.0 full-weight point it scored 0.22 and fell under the acting threshold. Bars four times normal are rare enough that anchoring to them made everything below invisible.
input double SingleCandleMinBody         = 0.55;   // Body share - a wide bar that closed mid-range is a fight, not a push
input int    SingleCandleMinBodyPoints   = 500;    // Absolute floor ($0.50) - three times the size of four tiny bars is still a tiny bar
input double SingleCandleMinStrength     = 0.20;   // V229b: 0.30 -> 0.20, so a 2.7x bar registers rather than falling just short.
input bool   SingleCandleArms            = true;   // Wait for the push to stop rather than penalising the entry. The objection ends when the next bar fails to continue - observable, not a fixed delay.
input int    SingleCandlePenalty         = 5;      // Cost of entering against a dominant bar when not arming
input int    SingleCandleBonus           = 2;      // Credit for entering with one. Deliberately smaller: joining a push is easier to get wrong than avoiding one.
input bool   SingleCandlePrintOnUse      = true;   // Log dominant candles

// V238: two live losses, one blind spot behind each.
// A BUY AT 4435 into a band that had capped price on four separate days. The counter-zone check
// measures distance to the nearest LEVEL, which is right when price is outside a band and wrong when
// it is between the edges - the nearest edge is then a dollar away and the check reads open road
// while price sits in the middle of the thing that has been stopping it all week.
input bool   EnableBandEntryGuard        = true;   // Notice when the entry is inside a band rather than approaching a level
input double BandGuardMinStrength        = 1.5;    // Band strength worth respecting
input double BandGuardFullStrength       = 2.8;    // Strength at which the guard is at full weight
input double BandGuardInsideBase         = 0.45;   // V243: weight carried by being inside a held band at all, before position is considered. The original version scored position only and let the middle through - a sell at 4485.10 inside a 4484.20-4486.00 band scored 0.50 against a 0.55 threshold and passed. A trade anywhere inside a shelf that has held three times has no room in front of it.
input int    BandGuardMinRoomPoints      = 800;    // V243: room ($0.80) to the band's far edge below which the trade cannot work even if the direction is right
input double BandGuardNoRoomFactor       = 1.40;   // V243: multiplier when there is no room - this is the case that produced the loss

// V245: does the target land inside a band? RoomToTargetPoints asks whether a wall sits beyond the
// target and reads a single price, so against a band it returns whichever edge happened to be
// cached. From a live entry: a buy at 4491.35 targeting 4493.85 with a band running 4492.00-4494.15
// that had turned price away three times. It saw the far edge, measured $2.80 of room, and reported
// plenty for a $2.50 target. The real figure was $0.65 - the distance to where the band STARTS.
input bool   EnableTargetBandCheck       = true;   // Check whether the target falls inside a band rather than short of a level
input double TargetBandMinStrength       = 1.5;    // Band strength worth measuring against
input double TargetBandMinSeverity       = 0.30;   // Share of the intended move that must fall inside the band before it counts
input int    TargetBandPenalty           = 6;      // Cost of aiming into a band. High: the target is not merely optimistic, it is inside the thing that stops price.
input bool   TargetBandPrintOnUse        = true;   // Log targets landing inside bands

// V246: the level that was broken and took itself back. ZoneMapIsPolarityFlip looks for one
// crossing - price on one side, then the other - which describes a level changing role and is the
// wrong shape for what usually happens at a strong one. From the live chart: a band at 4492-4494
// that price broke through twice and came straight back under both times. To the flip test that
// reads as a level whose role keeps changing, ambiguous and unreliable. In practice it is the
// opposite - a level that has defeated two attempts is stronger than one never tested, because the
// attempts are the evidence and whoever took them is trapped on the wrong side.
input bool   EnableFailedBreakRead       = true;   // Count breaks that were reclaimed, and treat them as strength
input ENUM_TIMEFRAMES FailedBreakTF      = PERIOD_M5;   // Timeframe attempts are read on
input int    FailedBreakLookback         = 80;     // Bars searched for attempts
input int    FailedBreakTolerance        = 300;    // How far ($0.30) past the level a close must be to count as an attempt rather than noise
input int    FailedBreakReclaimBars      = 4;      // Bars within which price must come back for the break to count as failed. Longer than this and the level genuinely gave way for a while.
input double FailedBreakBoostPer         = 0.20;   // Strength added per defeated attempt
input double FailedBreakMaxBoost         = 0.50;   // Ceiling - two is confirmation, six means price is grinding against it and it will probably go
input int    FailedBreakFreshBars        = 30;     // Bars within which a defence still counts fully - the traders caught by it are still positioned
input int    RetestMinFailedBreaks       = 2;      // Failed breaks that qualify a level for the retest setup without a polarity flip

// V247: the price at which the basket is simply wrong. The EA has three ways to close a losing
// basket - the stop at 50%, an emergency drawdown trigger, an equity stop - and all three answer the
// same question: has the money run out. None answers the one a trader asks first: is the reason I
// took this trade still true? From a live loss: two sells at 4470 and 4484 while price climbed to
// 4523, the second placed ABOVE the first, into the rise, and then the basket sat accumulating
// drawdown toward a percentage. Somewhere in that climb the case for being short stopped existing,
// and nothing was watching - because nothing had recorded what the case was.
input bool   EnableBasketThesis          = true;   // Record what the basket is betting on and the price that would disprove it
input int    ThesisMinDistance           = 700;    // Closest ($0.70) an invalidation can sit - nearer than this and it fires on noise
input int    ThesisMaxDistance           = 4000;   // Furthest ($4.00) - beyond this it is not an invalidation, it is a stop-loss
input int    ThesisTolerance             = 200;    // Slack ($0.20) before a close counts as through it
input bool   ThesisPrintOnUse            = true;   // Log the thesis and its failure

// V290: when the premise is dead, stop asking for the full target. V247 detects that the reason for
// the basket has gone and answers by stopping the grid - which keeps the position from growing and
// does nothing about the position itself, left waiting for a target that assumed the original read
// was right. A basket whose premise is gone is not a trade any more; it is a position to be managed
// out of, and the first retrace toward break-even is the exit.
input bool   EnableDeadPremiseExit       = true;   // Cut the target to break-even once the basket's reason has gone
input bool   RequireDrawdownForBE        = true;   // S-BASKET: wait until the basket is actually deep before cutting to break-even. A premise dying says the reason has gone, not that the trade is lost - a basket three dollars down with its target still close can still reach it, and cutting there gives away every recovery the position had.
input double DeadPremiseBEFromDD         = 12.0;   // S-BASKET: drawdown percent at which a dead premise turns into a break-even exit. Set against a basket stop of fifty, this is the point where the question stops being profit and becomes getting out whole.
input int    DeadPremiseExitPoints       = 400;    // Floor for that target ($0.40) - enough to clear the spread and the tick of slippage that decides whether a break-even close breaks even
input bool   DeadPremiseExitPrintOnUse   = true;   // Log premise exits

// V248: three things checked too late, or not at all.
// AFFORDABILITY: GridEffectiveMaxOrders works out whether the account can pay for the remaining
// rungs, and it runs from inside GridCanOpen - so it first executes at rung two, when the basket
// already exists. If the full ladder was never affordable the EA finds out halfway up, and stops in
// the worst place: too deep to close cheaply, too shallow to recover.
input bool   EnableEntryAffordability    = true;   // Check the whole ladder is affordable before opening anything
input double EntryAffordabilityShare     = 1.00;   // V279: 0.85 -> 1.00. Live case: an $822 account with a $411 stop budget, and a five-rung ladder projecting $393 - inside what the stop is sized to absorb, and refused because of an extra fifteen percent margin this check was adding on top. The stop already bounds the loss; this check exists to catch a ladder the account cannot pay for at all, which is a different question from one that fits with less room to spare. At 1.00 it still refuses anything projecting beyond the stop, and stops duplicating a limit that already exists.   // Share of the stop budget the projected ladder may reach. Below 1.0 so it finishes before the stop rather than at it.
input double EntryAffordabilityMaxMargin = 70.0;   // V279b: 45 -> 70. On an $822 account a five-rung ladder needs roughly $430 of margin, which is 52 percent of equity - refused at 45, and not remotely dangerous: that leaves a margin level near 190 percent against a stop-out around 50. The number this check should protect is the margin LEVEL, and 70 percent of equity still leaves it above 140. Forty-five was refusing ladders the account could carry comfortably.   // Percent of equity the full ladder may need as margin. Running out of margin mid-ladder is worse than running out of budget, because the broker decides what closes.
input bool   EnableAffordableLadderTrim  = true;   // V282: when the full ladder costs more than the stop allows, cap the basket at the depth that fits instead of refusing the entry. The check exists to stop the EA discovering at rung four that it cannot pay for rung five - it does that, and then throws away a setup every other layer approved because of an arithmetic problem with the last two rungs. The first rung was always affordable; the tail was not.
input int    MinAffordableRungs          = 1;      // V284: 2 -> 1. On a small account two rungs can exceed the stop budget while one is plainly affordable, and refusing the entry over that leaves the EA unable to trade at all. A single-rung basket has no recovery ladder, which is a real limitation and a better one than no trade.      // V282: fewest rungs worth trading. Below this the basket has no recovery room at all and the entry is refused as before.
input bool   EnableBalanceSizedLot       = true;   // V285: derive the base lot from the balance so the full ladder fits, instead of refusing entries when a fixed StartLot does not. Sizes down only - a large account still trades the size it was configured for.
input bool   BalanceSizedLotPrintOnUse   = true;   // V285: log when the lot is sized down
input bool   EntryAffordabilityPrintOnUse = true;  // Log refused entries
// A DEAD MARKET is specifically dangerous for a ladder - the range is too tight for the target, so
// the rungs fill quickly and the move that eventually comes finds a full basket waiting.
input bool   EnableDeadMarketCheck       = true;   // Notice when there is nothing happening
input int    DeadMarketLookback          = 20;     // Bars measured
input double DeadMarketExpectedATRPerBar = 0.35;   // Ground a normal bar covers, as a share of ATR - the window is expected to cover this times its length
input double DeadMarketRatio             = 0.60;   // Share of that expectation below which the market counts as dead
input double DeadMarketMinSeverity       = 0.30;   // Below this it is quiet rather than dead
input int    DeadMarketPenalty           = 4;      // Cost of opening a ladder into a market with no range
// NEWS READ FROM THE MARKET rather than the calendar. The EA knows when releases are scheduled; it
// does not notice one HAPPENING - volume several times normal, spread widening, range expanding -
// which is what matters and which arrives whether or not the event was listed anywhere.
input bool   EnableLiveNewsRead          = true;   // Detect a release from the market's own behaviour
input bool   EnableNewsOwner             = true;   // S-FIX: one owner for the news question. Three systems answered it - the calendar, the live price read, and an older pack - and when they disagreed the outcome depended on which one a call site happened to ask. The log caught it at NFP: news at 17:29, no news at 17:30. A scheduled release is a fact; price moving like one is an opinion about a fact, so the calendar leads and the live read speaks only where the calendar is silent.
input bool   NewsLiveReadBlocksEntry     = true;   // S-FIX: whether an inferred release (nothing scheduled, price behaving like it) stops an entry. Grid additions are stopped either way - adding during a release is how a recoverable basket becomes one that is not.
input double LiveNewsVolumeMultiple      = 2.5;    // Volume against normal that signals participants arriving at once
input double LiveNewsVolumeWeight        = 0.40;   // Weight of that
input double LiveNewsSpreadMultiple      = 2.0;    // Spread against its usual level - the broker's own reading of the same thing
input double LiveNewsSpreadWeight        = 0.35;   // Weight of that
input double LiveNewsRangeMultiple       = 2.5;    // Bar range in ATR that marks an expansion
input double LiveNewsRangeWeight         = 0.30;   // Weight of that
input double LiveNewsMinSeverity         = 0.35;   // Below this it is ordinary volatility
input int    LiveNewsPenalty             = 5;      // Cost of opening into a release
input double LiveNewsGridBlock           = 0.55;   // Severity at which the grid stops adding - a rung placed into a release fills at the worst price of it
input bool   LiveNewsPrintOnUse          = true;   // Log detected releases

// V249: two readings a total cannot express, both about the same weakness - a sum hides the shape
// of what produced it.
// CONSENSUS: a score of 13 built from eleven modules each adding a point or two is broad agreement;
// a 13 built by two modules shouting while the rest say nothing is a narrow opinion that happened to
// be loud. They arrive as the same number.
input bool   EnableScoreConsensus        = true;   // Measure how many modules actually contributed
input int    ConsensusFullContributors   = 8;      // Contributions at which support counts as broad
input double ConsensusThinBelow          = 0.40;   // Breadth below which the reading is narrow
input int    ConsensusThinPenalty        = 3;      // Cost of narrow support. Modest - thin agreement is less certain, not wrong.
input bool   EnableConsensusHeadroom     = true;   // V263: let broad agreement raise the bonus ceiling. The cap exists to stop two loud modules dominating and it does that - but it applies the same limit when eleven modules each add a point or two, which is the opposite case. V249 already counts how many spoke and uses it only to penalise thin support; this uses the other half of the same reading.
input double ConsensusHeadroomFrom       = 0.60;   // V263: breadth above which the ceiling starts to lift
input int    ConsensusHeadroomExtra      = 5;      // V263: how much headroom full agreement earns. The penalty side is untouched - this widens what a strong setup can say, not what a weak one gets away with.
input bool   EnableObjectionHeadroom     = true;   // V287: let broad objection raise the penalty ceiling, as V263 lets broad agreement raise the bonus one. Leaving one side fixed made the scoring one-directional: bonus reaching twenty-six against a penalty frozen at ten meant six modules could object and never stop the trade.
input double ObjectionHeadroomSpan       = 2.5;    // V287: how far past the ceiling raw objection must run for the lift to be complete. At 2.5 a raw penalty of twenty-five against a ceiling of ten earns the full extra.
input int    ObjectionHeadroomExtra      = 14;     // V287b: 8 -> 14. With a base of seven and a typical bonus of seventeen, a setup needs twenty or more against it before it stops - and eight of headroom capped the objection at eighteen, so nothing ever did. Fourteen makes a heavily-objected setup stoppable while leaving an ordinary one untouched: the lift only reaches its maximum when raw objection runs two and a half times past the base ceiling, which is the shape of a setup with most of the EA against it.      // V287: how much a setup with everything against it can be charged beyond the base ceiling. Set against a bonus headroom of five plus a base of twenty-six, this keeps a heavily-objected setup stoppable without returning to the state where nothing traded.
// CONTRADICTION: V215 reads disagreement among the candle modules. Nothing does that one level up,
// where structure, situation, timeframes and candles can point opposite ways. Structure +6 up,
// situation -8 down, total -2, and the EA takes a weak short - but -2 out of fourteen points of
// conflicting evidence does not mean "slightly bearish", it means the layers are reaching opposite
// conclusions from the same chart.
input bool   EnableLayerConflict         = true;   // Read disagreement between the analysis layers
input int    ConflictMinLayers           = 3;      // Layers that must have an opinion before a split means anything
input double ConflictMinSplit            = 0.50;   // How evenly divided they must be - three against three is no signal, one dissenter among four is ordinary
input double ConflictMinSeverity         = 0.50;   // Below this the disagreement is normal variation
input int    ConflictPenalty             = 5;      // Cost of acting while the layers contradict each other
input bool   ConflictPrintOnUse          = true;   // Log layer conflicts

// V250: the bigger picture overrules the local one. Three live buys made the same mistake -
// 4670.41, 4672.48, 4670.48 - each time a double top had formed above, price broke down through it,
// then came back to retest the neckline, and the EA saw a support and bought it. A support inside a
// completed bearish reversal is not a support; it is the neckline of the pattern that just broke.
// The EA lacks hierarchy: structure, situation, timeframes and zones all contribute points to one
// total, so an M5 support and an H1 reversal simply add up. They should not - the larger picture
// decides what the smaller one means.
input bool   EnableReversalContext       = true;   // Read completed reversal patterns on the higher timeframes
input ENUM_TIMEFRAMES ReversalContextTF  = PERIOD_M15;  // Timeframe the pattern is read on
input int    ReversalContextLookback     = 80;     // Bars searched for the shape
input double ReversalPeakTolerance       = 0.60;   // How close in ATR the two peaks must be to count as one pattern rather than two unrelated highs
input double ReversalMinHeightATR        = 2.0;    // Pattern height before it means anything - without this any two highs with a dip between them qualify
input double ReversalFullHeightATR       = 5.0;    // Height at which it carries full weight
input int    NecklineRetestReach         = 1200;   // How close ($1.20) to the broken neckline counts as retesting it
input double ReversalContextBaseWeight   = 0.45;   // Weight of being inside a hostile context at all, before proximity to the neckline
input double ReversalMinSeverity         = 0.30;   // Below this the context is too weak to matter
input int    ReversalContextPenalty      = 7;      // Cost of trading against a completed reversal. The heaviest single penalty here, because this specific mistake has now cost three baskets.
input bool   ReversalContextPrintOnUse   = true;   // Log the context and retests

// V252: the levels that do not come from swings. A support at 4305-4315 held on the 2nd and 3rd of
// September; on the 11th price returned to it and the EA did not see it - nine days is a long time
// in a swing cache and hundreds of newer swings had pushed it out. But round numbers, the monthly
// range and the weekly open do not need remembering: they are prices rather than history, and they
// matter most exactly when the cache is least useful - after a large move into territory with no
// recent swings in it at all.
input bool   EnableGlobalLevels          = true;   // Read levels that can be calculated rather than remembered
input double GlobalRoundMajor            = 100.0;  // Hundreds - the strongest round level
input double GlobalRoundMajorStrength    = 2.2;
input double GlobalRoundMid              = 50.0;   // Fifties
input double GlobalRoundMidStrength      = 1.7;
input double GlobalRoundMinor            = 25.0;   // Quarters
input double GlobalRoundMinorStrength    = 1.3;
input double GlobalMonthStrength         = 2.5;    // The monthly high and low - a month of trading decided those
input double GlobalWeekStrength          = 1.9;    // The weekly range
input double GlobalWeekOpenStrength      = 1.6;    // Where the week opened - the reference everyone measures the week against
input int    GlobalLevelReach            = 4000;   // How far ahead ($4.00) to look for one
input double GlobalLevelMinStrength      = 1.5;    // Below this it is not worth the penalty
input int    GlobalLevelPenalty          = 5;      // Cost of a global level sitting between the entry and its target
input bool   GlobalLevelPrintOnUse       = true;   // Log global levels in the way

// V253: the candle that took both sides. A bar with long wicks above and below a small body reads as
// a doji - indecision, no information, ignore it. That is the wrong reading in the most expensive
// way. Price went up far enough to take out everyone short, came back down far enough to take out
// everyone long, and closed near where it started. Nobody is undecided; both sides have been cleared
// and whoever did the clearing has the market to themselves, which is why the move after one of
// these tends to be the real one.
input bool   EnableManipulationRead      = true;   // Read both-sided sweeps rather than calling them dojis
input ENUM_TIMEFRAMES ManipulationTF     = PERIOD_M1;   // V256: M5 -> M1. Stop-clearing is a one-to-two-minute event and M1 is where it is visible as a single bar. M5 still works and is accepted; anything above M15 is refused outright inside the function, because there the same shape is several hours of ordinary trade compressed into one candle rather than a sweep.   // Timeframe the bar is read on
input int    ManipulationLookback        = 6;      // V256: 5 -> 6. On M1 that is six minutes, which is about how long a stop-clearing keeps mattering before the book refills. The effect of a sweep is short-lived; a window measured in hours describes something else.      // Bars back a sweep still counts - the traders it cleared are being replaced
input double ManipulationMaxBody         = 0.35;   // Body share below which price finished roughly where it started
input double ManipulationMinWick         = 0.25;   // Each wick's share. BOTH must clear it - one long wick is a rejection, two is a sweep of both sides.
input double ManipulationFullWickTotal   = 0.80;   // Combined wick share at which the reading is at full weight
input double ManipulationMinRangeATR     = 1.4;    // Bar size in ATR. A small doji in a quiet hour is genuine indecision; one spanning two ATR is a range traded through in both directions inside a single bar, and that takes size to produce.
input double ManipulationFullRangeATR    = 2.5;    // Size at which it carries full weight
input double ManipulationBiasMargin      = 0.12;   // How far off centre the close must be before it suggests a direction
input double ManipulationMinConviction   = 0.30;   // Below this the bar is an ordinary doji
input int    ManipulationScore           = 5;      // Weight of trading with or against the side the sweep favoured
input int    ManipulationUnclearPenalty  = 4;      // Cost of entering while both sides are cleared and the close gave nothing away
input bool   ManipulationPrintOnUse      = true;   // Log sweep bars

// V257: the wick that went and fetched something. CandleWickAuthorship already reads wicks and asks
// which side of the bar was rejected, measured against its own body - a reading about the candle.
// This is a reading about the CHART: a wick whose tip reaches a prior swing extreme and comes
// straight back has collected the stops sitting just beyond it, which is the only reason price goes
// there and does not stay. Authorship cannot tell the two apart because it never looks at where the
// wick ended, only at how big it was.
input bool   EnableLiquidityWick         = true;   // Read wicks that reach a prior extreme and return
input ENUM_TIMEFRAMES LiquidityWickTF    = PERIOD_M5;   // M1, M5 or M15 only - above that a long wick is hours of two-way trade and reaching a prior extreme is unremarkable
input int    LiquidityWickLookback       = 8;      // Bars searched for the sweep
input int    LiquidityWickSearchExtra    = 20;     // Extra bars searched behind it for the extreme the wick reached
input double LiquidityWickMinRatio       = 0.45;   // Wick share of its bar before it counts as deliberate rather than noise
input double LiquidityWickMinRangeATR    = 0.80;   // Bar size in ATR - a long wick on a tiny bar reached nothing worth reaching
input double LiquidityWickFullRangeATR   = 2.00;   // Size at which the reading is at full weight
input int    LiquidityWickTolerance      = 250;    // How close ($0.25) the tip must come to the prior extreme
input double LiquidityWickMinConviction  = 0.30;   // Below this the wick is ordinary
input int    LiquidityWickScore          = 5;      // Weight of trading with or against the side that was collected
input bool   LiquidityWickPrintOnUse     = true;   // Log liquidity sweeps

// V258: sizes that are going somewhere. CandleSequenceRead compares the newest bar to the average of
// the last five - a snapshot, which cannot tell one small candle after four large ones (a pause)
// from four candles each smaller than the one before it (a move running out of people willing to
// pay). Both read as "contracting" to a mean, because a mean does not know what order things
// arrived in. This measures the progression instead: whether each body is smaller than its
// predecessor, or larger, and how consistently.
input bool   EnableCandleProgression     = true;   // Read the order the candle sizes arrived in
input ENUM_TIMEFRAMES CandleProgressionTF = PERIOD_M5;  // M1, M5 or M15 only - on H1 four shrinking bars span most of a session and describe the session
input int    CandleProgressionBars       = 5;      // Bars examined (3 to 6)
input double CandleProgressionStepDown   = 0.80;   // Ratio below which a body counts as smaller than the one before it
input double CandleProgressionStepUp     = 1.25;   // And above which it counts as larger
input int    CandleProgressionMinSteps   = 2;      // Consecutive steps before the progression means anything. A run broken in the middle is not a progression - that is the point of measuring order.
input int    CandleProgressionFullSteps  = 4;      // Steps at which it carries full weight
input double CandleProgressionMixedFactor = 0.55;  // Weight when the bodies point different ways - the sizes are changing but the market has not settled on a direction to change them in
input double CandleProgressionMinConviction = 0.35; // Below this the sequence is unremarkable
input int    CandleProgressionScore      = 2;      // V288b: 4 -> 2. This reading is about WHEN, not whether - and V288 now answers it by holding the setup for a retrace rather than charging it points. Leaving the full penalty in place would charge twice for the same observation: once by waiting, once by subtracting.      // Weight of joining or fading a progression
input bool   CandleProgressionPrintOnUse = true;   // Log progressions

// V260: how price arrived. CandleLocationWeight asks where a wick's tip landed and CandleRelevance
// asks how close a level is - both are about POSITION, which is half of context. The other half is
// arrival: a rejection at support after a fast one-way drop is exhaustion testing the level and
// those hold; the same candle after forty minutes of grinding into it is absorption wearing the
// level down and those break. The shape is identical, what produced it is not, and nothing here
// looked at the bars before the one being read.
input bool   EnableArrivalRead           = true;   // Read how price got to where it is, not just where it is
input ENUM_TIMEFRAMES ArrivalTF          = PERIOD_M5;   // M1, M5 or M15 only
input int    ArrivalBars                 = 12;     // Bars defining the approach - long enough to hold a real move, short enough to still be about this one
input double ArrivalMinNetATR            = 1.2;    // Net distance in ATR before the move counts as an approach at all. Efficient drift over ten points is not an arrival.
input double ArrivalGrindBelow           = 0.30;   // Efficiency (net distance over ground walked) below which the approach is a grind
input double ArrivalFastAbove            = 0.70;   // And above which it is a straight run
input int    ArrivalLevelReach           = 1500;   // How close ($1.50) the level must be. In open space how price arrived says nothing, because there is nothing there for it to matter at.
input double ArrivalMinLevelStrength     = 1.5;    // Level strength worth reading the approach against
input int    ArrivalScore                = 4;      // Weight either way
input bool   ArrivalPrintOnUse           = true;   // Log arrivals

// V261: the hour numbers are wrong for half the year. Every session boundary here is a fixed broker
// hour and all of them assume the relationship between broker time and market time never changes.
// It changes twice a year: London moves to UTC+1 in late March, New York to UTC-4 in early March,
// and the broker's clock stays where it is - so from spring to autumn every boundary is an hour late
// and the killzone covers the wrong sixty minutes. The two regions also switch on different dates,
// and for the fortnight between them the sessions overlap differently than they do all year.
input bool   EnableDSTAdjust             = true;   // Shift session boundaries with the seasons
input int    LocalUTCOffsetHours         = 5;      // The operator's offset from broker time, for the dashboard only. A five-hour gap already produced one wrong conclusion about why the EA stopped on a Friday.
input bool   ShowBothTimesOnDash         = true;   // Show broker and local time together

// V262: which end of the candle came first. A bar with wicks on both sides tells you price visited
// two extremes and not in what order, and the order is most of the meaning - down first then up
// means the lows were swept and the selling is already spent; up first then down is the opposite.
// The four OHLC numbers are identical either way, and the close position hints badly: a bar that
// swept its lows, rallied hard and faded slightly at the end closes mid-range and looks balanced.
// The sequence is recoverable from the timeframe below, where the order is not in doubt.
input bool   EnableWickOrder             = true;   // Read which extreme a bar reached first
input ENUM_TIMEFRAMES WickOrderTF        = PERIOD_M5;   // The bar being read
input ENUM_TIMEFRAMES WickOrderSubTF     = PERIOD_M1;   // The timeframe its order is recovered from. Only M5/M1, M15/M1 and M15/M5 are accepted - the sub-timeframe has to divide the main one evenly, and above M15 this is about a session rather than an event.
input double WickOrderMinWick            = 0.20;   // Each wick's share of the range. Both must clear it, or there is no order to read.
input double WickOrderFullWickTotal      = 0.60;   // Combined wick share at which the reading is at full weight
input int    WickOrderTolerance          = 150;    // How close ($0.15) a sub-bar must come to count as having touched the extreme
input double WickOrderMinSeparation      = 0.25;   // Extremes touched in adjacent sub-bars are almost simultaneous and their order means little
input double WickOrderFullSeparation     = 0.60;   // Share of the bar's sub-bars at which separation is complete
input double WickOrderMinConviction      = 0.30;   // Below this the reading is not clear enough to act on
input int    WickOrderScore              = 4;      // Weight of trading with or against the implied direction
input bool   WickOrderPrintOnUse         = true;   // Log the order

// V264: levels that have earned the right to be remembered. A shelf at 4305-4315 held on the 2nd and
// 3rd of September; price returned on the 11th and the EA did not see it. It was never lost from the
// cache - the H1 lookback covers ten days - but ZoneMapScanTFSupport returns the NEAREST support,
// and nine days of trading had put dozens of newer swings in between. Every one outranked it,
// because nearest is the only comparison that scan makes. StrongZoneOverride corrects this and only
// fires when the two are already close; across nine days they are not.
input bool   EnableProtectedZones        = true;   // Keep qualifying levels where the nearest-swing scan cannot push them off
input int    ProtectedZoneMinTouches     = 3;      // Touches that qualify a level on their own
input double ProtectedZoneMinStrength    = 2.0;    // Or strength alone. Any single condition is enough - they are all evidence the market recognises this price, arrived at different ways.
input double ProtectedZoneFullStrength   = 3.5;    // Strength at which the reading is at full weight
input int    ProtectedZoneMergeTolerance = 400;    // How close ($0.40) two entries must be to count as the same level. They repeat across timeframes, which is itself a sign of quality, but one entry each is enough.
input int    ProtectedZoneRefreshBars    = 20;     // Bars between rebuilds. These levels change over days, not bars, and the scan is the expensive part.
input int    ProtectedZonePenalty        = 6;      // Cost of a protected level sitting between the entry and its target
input bool   ProtectedZonePrintOnUse     = true;   // Log protected levels

// V291: deciding before price arrives. Every reading here starts when price is already somewhere -
// a level is reached, and only then does the work begin, and by the time thirty modules agree the
// reaction that made the level worth trading is several bars old. But the level was there the whole
// time, and the slow half of the answer was knowable before price got there.
input bool   EnablePreparedLevels        = true;   // Decide about levels ahead of price, so arrival costs no time
input int    PrepLookAheadPoints         = 5000;   // How far ahead ($5.00) to prepare
input int    PrepRefreshBars             = 3;      // Bars between rebuilds
input int    PrepHitTolerance            = 400;    // How close ($0.40) counts as arriving
input int    PrepMergePoints             = 600;    // Distance below which two candidates are the same level
input double PrepMinLevelStrength        = 1.8;    // Level strength worth preparing for
input double PrepFullLevelStrength       = 3.5;    // Strength at which the level contributes fully
input double PrepLevelWeight             = 4.0;    // Weight of the level itself
input double PrepTrendWeight             = 3.0;    // Weight of the monthly trend
input double PrepHierarchyWeight         = 4.0;    // Weight of the larger scales objecting
input double PrepRangeWeight             = 2.0;    // Weight of range position
input double PrepThinWeight              = 3.0;    // Weight of a thin day
input double PrepMinScore                = 3.0;    // Context score below which the level is not marked
input double PrepFullScore               = 9.0;    // Score at which the bonus is full
input int    PreparedLevelBonus          = 4;      // Credit for arriving at a level already decided about
input bool   PreparedLevelsPrintOnUse    = true;   // Log prepared levels

// V266: when the larger scale disagrees. Every reading contributes points to one total, so an M5
// support and an H1 downtrend arrive as two numbers that get added together and the sum can come out
// positive - which is how the EA bought a support inside a downtrend three separate times. The
// larger scale does not vote alongside the smaller; it decides what the smaller one means.
input bool   EnableScaleHierarchy        = true;   // Let the larger scales override rather than merely vote
input ENUM_TIMEFRAMES HierarchyTF1       = PERIOD_H4;   // The scale with most authority
input double HierarchyWeight1            = 0.45;
input ENUM_TIMEFRAMES HierarchyTF2       = PERIOD_H1;
input double HierarchyWeight2            = 0.35;
input ENUM_TIMEFRAMES HierarchyTF3       = PERIOD_M30;
input double HierarchyWeight3            = 0.25;
input double HierarchyMinConflict        = 0.35;   // Below this the disagreement is minor
input int    HierarchyPenalty            = 7;      // Cost of trading against the larger scales. Heavy, because this specific mistake has now cost three baskets.
input bool   HierarchyPrintOnUse         = true;   // Log hierarchy conflicts
// And the other half: the scanner finds the best setup one way and never asks what the opposite
// direction would have scored. Both sides looking good is not two opportunities - it is a market
// that has not decided.
input bool   EnableAmbiguityCheck        = true;   // Check what the opposite direction had going for it
input double AmbiguityStructureWeight    = 3.0;    // Points the opposite side gets for structure
input double AmbiguitySituationWeight    = 4.0;    // For a named situation
input double AmbiguityAlignWeight        = 3.0;    // For full timeframe alignment
input double AmbiguityLevelWeight        = 2.5;    // For a level it would be trading away from
input int    AmbiguityLevelReach         = 1200;   // How close ($1.20) that level must be
input double AmbiguityLevelMinStrength   = 1.5;    // And how strong
input double AmbiguityMinOpposite        = 5.0;    // Opposite-side points below which there is no real second case
input double AmbiguityMinRatio           = 0.45;   // Share of our own score the other side must reach before it counts as indecision rather than a weaker alternative
input int    AmbiguityPenalty            = 5;      // Cost of entering while both sides have a case
input bool   AmbiguityPrintOnUse         = true;   // Log ambiguous markets

// V268: the days when nobody is there. The holiday guard exists and works only if someone types the
// dates in - BrokerHolidayDates is a manual list that has to be refreshed every year, and a list
// nobody updated is a guard that quietly stopped guarding. Most thin days need no list: the fixed
// holidays never move, late December empties out regardless of where the weekend falls, August is
// the European holiday month and structurally quiet all month, and month-end brings rebalancing
// flow that moves price for reasons the EA cannot read. The moving holidays still need the manual
// list; this covers the ones that do not.
input bool   EnableCalendarThinness      = true;   // Read the thin days that can be calculated
input double ThinFixedHolidayWeight      = 0.70;   // January 1st, December 25th and 26th
input int    ThinYearEndFromDay          = 20;     // December day from which the market empties out
input int    ThinYearStartToDay          = 3;      // And January days that are still quiet
input double ThinYearEndWeight           = 0.45;   // Weight of the year-end period
input double ThinAugustWeight            = 0.25;   // August. Modest - it is a month of lower volume, not a closed market.
input int    ThinMonthEndDays            = 1;      // Days before month end that count
input double ThinMonthEndWeight          = 0.30;   // Rebalancing flow - not thin exactly, but flow the EA cannot anticipate
input double ThinQuarterEndWeight        = 0.45;   // Quarter end, where the same flow is larger
input double ThinMinSeverity             = 0.25;   // Below this the day is ordinary
input int    ThinDayPenalty              = 5;      // Cost of opening a ladder on a thin day
input double ThinGridDoubtFrom           = 0.35;   // Thinness at which the grid starts holding back too
input double GridDoubtThinWeight         = 0.30;   // How much it counts toward holding additions
input bool   ThinDayPrintOnUse           = true;   // Log thin days

// V269: which setups actually work here. The EA recognises sixteen setup types and treats them all
// as equally likely to work, having never counted which ones do. NEAR_ZONE_REACTION and
// MOMENTUM_SCALP are different trades with different failure modes, and on a given account, symbol
// and broker one may be reliable while the other is not - that cannot be reasoned out, it depends on
// the spread, the sessions traded and how this symbol behaves. The candle layer already learns this
// way and it was never extended to the setups, which is the level where it matters most.
input bool   EnableSetupLearning         = true;   // Keep a record per setup type and weight by it
input int    SetupLearningMinSamples     = 8;      // Baskets before a type's record means anything. Four samples mean nothing and should earn nothing either way.
input int    SetupLearningMaxSamples     = 60;     // Window per type - a record covering a different market describes that market
input double SetupLearningGoodRate       = 0.65;   // Win rate above which a type earns a little
input double SetupLearningPoorRate       = 0.45;   // And below which it loses a little
input int    SetupLearningMaxBonus       = 2;      // Most a good record can add. Deliberately small - this is a nudge built on the account's own history, not a filter, and a run of bad luck should not disable a sound setup.
input int    SetupLearningMaxPenalty     = 3;      // And most a poor one can take away
input bool   PersistSetupLearning        = true;   // Keep the record across restarts. Eight baskets per type takes weeks; starting over each session means never arriving at an answer.
input bool   ShowSetupLearningOnDash     = true;   // Show the best and worst performers

// V270: the day's reference price. Above the daily open the day is up and buyers are in profit;
// below it the day is down. It is the single most widely watched price on the chart and the EA did
// not know where it was - V252 added the weekly open and stopped there.
input bool   EnableDailyOpen             = true;   // Read which side of the day's open price is on
input int    DailyOpenMinDistance        = 300;    // Distance ($0.30) before the day has committed to a side
input int    DailyOpenFullDistance       = 2500;   // Distance ($2.50) at which it has committed fully
input int    DailyOpenScore              = 3      ;// Weight of trading with or against the day
// And effort against result. CandleParticipation reads volume on a single bar - whether the market
// showed up for it. What it cannot see is a new high reached on less volume than the previous high
// took, which means fewer participants are needed to move price: what a move running out looks like
// before it turns. Tick volume is not real volume, and comparing two readings of the same flawed
// measure is where a flawed measure is most usable.
input bool   EnableVolumeDivergence      = true;   // Compare volume at successive swings
input ENUM_TIMEFRAMES VolumeDivergenceTF = PERIOD_M15;  // M5, M15 or M30 only
input int    VolumeDivergenceLookback    = 40;     // Bars searched for the two swings
input double VolumeDivergenceRatio       = 0.70;   // V276: 0.80 -> 0.70. Tick volume is noisy and two swings twenty percent apart is ordinary variation rather than a signal. Thirty percent is a difference worth reading.   // Volume ratio below which the divergence counts
input double VolumeDivergenceFull        = 0.45;   // Ratio at which it is at full weight
input double VolumeDivergenceMinConviction = 0.30; // Below this the difference is noise
input int    VolumeDivergenceScore       = 4;      // Weight either way
input bool   VolumeDivergencePrintOnUse  = true;   // Log divergences

// V273: the trend above everything. HigherScaleConflict reads H4 over eighty bars - thirteen days,
// which is a swing inside a trend rather than the trend. This matters most at the distant levels
// V272 extended the EA's memory to reach: a daily level from four months ago is the strongest thing
// on the chart, and price arriving at it in a falling market is not the same event as arriving at it
// in a rising one. In the first the level is something the trend has to get past and usually does;
// in the second it is where the trend stops.
input bool   EnableGlobalTrend           = true;   // Read the monthly trend, not just the weekly one
input ENUM_TIMEFRAMES GlobalTrendTF      = PERIOD_D1;   // Daily - a monthly trend cannot change within a session
input int    GlobalTrendLookback         = 60;     // Bars defining it - sixty daily bars is about three months
input double GlobalTrendMinATR           = 5.0;    // V276: 3.0 -> 5.0. Three daily ATR on gold is about $135, which over three months is a three percent move - that is drift, not a trend, and at this setting the EA would report a monthly trend almost every day and charge the counter-trend penalty almost every time. Five ATR is roughly five percent over the same window, which is a move the market has actually committed to.    // Net travel in ATR before it is a trend rather than a long range
input double GlobalTrendFullATR          = 10.0;   // Travel at which it is fully established
input double GlobalTrendFullEfficiency   = 0.35;   // Efficiency at which the trend counts as clean - a move that walked straight there differs from one that fought for months, even where the endpoints match
input double GlobalTrendMinStrength      = 0.30;   // Below this the trend is too weak to weigh
input double CounterTrendBaseWeight      = 0.55;   // Weight of running against it at all
input int    CounterTrendLevelReach      = 2000;   // How close ($2.00) the level being faded must be
input double CounterTrendLevelMinStrength = 1.8;   // Level strength worth noting
input double CounterTrendLevelFullStrength = 3.5;  // Strength at which the reading is full
input double CounterTrendMinSeverity     = 0.35;   // Below this the conflict is minor
input int    CounterTrendPenalty         = 6;      // Cost of fading a monthly trend into a level. A level standing against an established trend is not a wall - it is the next thing the trend has to get through, and most of the time it does.
input int    GlobalTrendBonus            = 3;      // Credit for trading with it. Smaller than the penalty: being right about direction is the easy half, and entry is what the rest of the scoring is for.
input bool   GlobalTrendPrintOnUse       = true;   // Log global trend readings

// V288: where in the move, not how many points off. A live SELL was taken at the low of a four-dollar
// decline and turned two bars later; four modules had objected and each answered by subtracting
// points. That treats a timing problem as a quality problem, and the two need opposite responses - a
// poor setup should be refused, a good setup at a poor moment should be held.
input bool   EnableLateEntryHold         = true;   // Hold a good setup that arrived at the wrong price, instead of penalising it
input ENUM_TIMEFRAMES LateEntryTF        = PERIOD_M5;   // M1, M5 or M15
input int    LateEntryLookback           = 30;     // Bars defining the move being joined
input double LateEntryMinSpanATR         = 1.5;    // Move size before position within it means anything
input double LateEntryHoldFrom           = 0.72;   // Position through the move above which the entry is late enough to wait
input double LateEntryRetraceShare       = 0.25;   // How much of the move a retrace must give back - just enough that the entry stops paying for what already happened
input bool   LateEntryPrintOnUse         = true;   // Log pullback holds
input bool   EnableReversalAtExtreme     = true;   // V289: credit a reversal setup for being at the extreme. The reading that makes a continuation trade late makes this one timely - fading a move that has run is the only place fading works, so being at the end is the setup rather than a flaw in it.
input int    ReversalAtExtremeBonus      = 4;      // V289: weight at the far end of the move
input double HierarchyOverrideFrom       = 0.40;   // V274: conflict above which the larger scale starts taking the local case away rather than merely offsetting it. Both were wired into the same structure budget, so local capped at seven, global capped at seven, and a market where M5 said buy while the monthly trend said otherwise came out neutral - which is exactly the reading that produced three losing baskets. Overruling means reducing what the smaller scale can claim.
input double HierarchyOverrideMaxCut     = 0.70;   // V274: most of the local bonus a full conflict removes. Not all of it - a local reading inside a hostile trend is worth less, not worth nothing, and the trade can still be right if everything else about it is strong.

// V275: the price the EA happens to be looking at. Everything built today answers where NOT to
// trade; what decides WHEN is still one question - has the score cleared. The moment it does the
// order goes in at whatever price is on the screen, and that price is arbitrary. A setup confirming
// at the top of an M5 bar and the same setup at its low are one trade taken a dollar apart against a
// target of two-fifty. EntryBarPlacement already measures this and charges for it, which is the
// wrong response: a poor fill is not a reason to refuse a good setup, it is a reason to wait a few
// minutes. The arming engine already knows how to hold a setup and re-check it.
input bool   EnableFillTiming            = true;   // Wait a few bars for a better price rather than penalising a poor one
input ENUM_TIMEFRAMES FillTimingTF       = PERIOD_M5;   // M1 or M5 - the bar the fill is measured within
input double FillTimingMinRangeATR       = 0.70;   // Bar size before position within it matters. In a bar worth twenty points, waiting gains twenty points at most.
input double FillTimingBadFrom           = 0.78;   // V279b: 0.65 -> 0.78. At 0.65 roughly a third of entries were being held for three bars, which is a lot of delay for a fill that was only slightly above the middle of its bar. At 0.78 it holds for the fills that are genuinely near the extreme, where the improvement is worth the wait.   // Position up the bar above which the fill counts as poor
input double FillTimingMinGainShare      = 0.12;   // Improvement, as a share of the target, below which waiting is not worth it
input double FillTimingMinSeverity       = 0.35;   // Below this the fill is ordinary
input bool   FillTimingPrintOnUse        = true;   // Log fill holds
// And the streak, which until now only appeared on the dashboard.
input bool   EnableStreakScoring         = true;   // Let win and loss streaks reach the score
input int    StreakScoreFromWins         = 2;      // Wins in a row before the direction earns anything
input int    StreakScoreFullWins         = 4;      // Wins at which the bonus is full
input int    StreakWinBonus              = 3;      // Most a run of wins can add
input int    StreakScoreFromLosses       = 2;      // Losses before the reading itself is in question
input int    StreakScoreFullLosses       = 4;      // Losses at which the penalty is full
input int    StreakLossPenalty           = 5;      // Most a run of losses can take away. Larger than the win bonus - a losing run says something is wrong with the read, and switching direction does not fix a bad read.

// V254: settings that are each valid and wrong together. The existing input validation checks values
// one at a time and every one can pass while the combination is unworkable - a seven-rung ladder at
// 1.30x on a small account is made of valid numbers and cannot be paid for, and a 250 point target
// against a 260 point spread is a trade that closes at a loss the moment it opens.
input bool   EnableSettingsValidation    = true;   // Check the settings work together, not just individually
input double SettingsLadderMaxShare      = 1.00;   // Share of the stop budget the full ladder may project to before it is flagged
input double SettingsMinTPSpreadRatio    = 3.0;    // How many times the spread the target must be. Below this the trade starts behind and has to make the difference up before it makes anything.
// And the market rather than the settings: every distance here was sized for a particular range, and
// when ATR doubles they are all simultaneously too small while none of them knows it.
input bool   EnableVolatilityShift       = true;   // Notice when volatility has moved away from what the settings assume
input int    VolatilityBaselinePeriod    = 100;    // Bars defining the baseline the current reading is compared against
input double VolatilityShiftHigh         = 1.60;   // Ratio above which the market is wider than the settings expect
input double VolatilityShiftFull         = 2.50;   // Ratio at which the penalty is at full weight
input double VolatilityShiftLow          = 0.60;   // Ratio below which it is narrower - noted but not penalised, since a quiet market is already covered by the dead-market check
input int    VolatilityShiftPenalty      = 4;      // Cost of entering while the range no longer matches the settings
input bool   VolatilityShiftPrintOnUse   = true;   // Log volatility shifts
// And from the third loss: "H2 and H4 never broke - H1 was fooled". The break confirmation added in
// V232 looks one step up. A break can be real on H1 and invisible on H4, and the H4 reading is the
// one that decides whether the move continues.
input bool   EnableDeepBreakConfirm      = true;   // Require a break to survive two steps up, not one
input ENUM_TIMEFRAMES DeepConfirmTF1     = PERIOD_M30;  // First step
input ENUM_TIMEFRAMES DeepConfirmTF2     = PERIOD_H1;   // Second - the one that decides
input double BandGuardMinSeverity        = 0.30;   // Below this the position is unremarkable
input int    BandGuardPenalty            = 6;      // Cost of buying the top of a capping band, or selling the bottom of a holding one
input bool   BandGuardPrintOnUse         = true;   // Log band entries
// A SELL AT 4345 after 4325 was swept, price recovered to a higher high, and never returned.
// Liquidity taken, structure turned, level holding three times - and the EA sold. The sweep
// detectors exist; what was missing is the reading that a sweep has COMPLETED and its consequence
// is now in force.
input bool   EnableSweepReversal         = true;   // Read a completed sweep and the structure turn that followed it
input ENUM_TIMEFRAMES SweepReversalTF    = PERIOD_M5;   // Timeframe the sequence is read on
input int    SweepReversalLookback       = 60;     // Bars searched for the sweep and what followed
input double SweepReversalMinHold        = 0.55;   // Share of the recovery leg price must hold to count as having left the swept level behind rather than hovering above it
input double SweepReversalMinStrength    = 0.40;   // Below this the recovery is not yet convincing
input int    SweepReversalScore          = 6;      // Weight of trading with or against a completed sweep reversal
input bool   SweepReversalPrintOnUse     = true;   // Log sweep reversals

// V239: did the candle get through the one before it? Annotated on the losing buy as "the candle did
// not break the previous body" - the plainest statement of a push failing, and nothing in the EA
// could express it. It measures body size, wick share, direction and range expansion; none of those
// asks whether the bar closed beyond where the last one closed. A bullish candle that cannot clear
// the previous bullish high is buyers arriving and getting nowhere - and to the sequence reader it
// looks like two candles agreeing.
input bool   EnableCandleProgress        = true;   // Check whether the candle progressed past the one before it
input double CandleProgressPartialWeight = 0.55;   // Weight when it cleared the previous body but not the previous extreme - partial failure, not total
input double CandleProgressMinSeverity   = 0.35;   // Below this the stall is unremarkable
input int    CandleProgressPenalty       = 5;      // Cost of entering behind a candle that achieved nothing
input bool   CandleProgressPrintOnUse    = true;   // Log stalled candles

// V230: the same bar, read in context. Size alone says a push happened; it does not say whether the
// push has anywhere left to go, whether anyone was behind it, or whether entering now means joining
// it or arriving after it.
input bool   EnableSingleCandleContext   = true;   // Weigh a dominant bar by what it came off and what it is heading into
input int    SingleCandleLevelReach      = 1200;   // Distance ($1.20) at which a level ahead or behind is close enough to matter
input double SingleCandleLevelMinStrength = 1.5;   // Level strength below which it does not change the reading
input double SingleCandleIntoLevelDamp   = 0.45;   // How much a level directly ahead reduces the push. The move is real and it has somewhere to stop, which makes continuation far less likely than the size suggests.
input double SingleCandleFromLevelBoost  = 1.25;   // And how much starting FROM a level increases it - a bar off a level it respected is the level working
input double SingleCandleVolumeBoost     = 1.20;   // Weight when the market participated
input double SingleCandleThinVolumeDamp  = 0.55;   // And when it did not. A wide bar nobody traded is stops being taken, not demand arriving - it gives the move back as easily as it made it.
input double SingleCandleChaseFrom       = 0.70;   // Position within the bar's range above which entering WITH it is chasing rather than joining. The bar has already travelled; a fill near the extreme it produced buys the end of the move.
input int    SingleCandleChasePenalty    = 4;      // Cost of that

// V207: candle reading in one place, and read as a SEQUENCE. The EA measures candles in twelve
// separate modules - wick ratios for pin bars, body ratios for impulses, close positions for
// pressure - each correct on its own and none aware of the others, so one bar can be a rejection to
// one check and a continuation to another. And all of them read a single bar, while a bar means
// different things depending on what preceded it: an expanding range after quiet bars is a
// breakout, the same range after loud ones is exhaustion.
input bool   EnableCandleSequence        = true;   // Read the last few candles as a sequence and produce one verdict
input ENUM_TIMEFRAMES CandleSequenceTF   = PERIOD_M5;   // V215: M1 -> M5. The setups this informs are built on M5/M15 zones, so reading candles at M1 was analysing a finer resolution than the decisions being made - plenty of M1 shapes that mean nothing at the level the trade actually cares about. M5 matches the structure the EA trades.  // Timeframe the sequence is read on
input int    CandleSequenceBars          = 5;      // Candles in the sequence
input double CandleSequenceMinLean       = 0.25;   // How decisively the sequence must lean before it counts as directional
input double CandleExpansionRatio        = 1.45;   // Newest range against the recent average, above which the move is being driven
input double CandleContractionRatio      = 0.78;   // V239: 0.65 -> 0.78. Fading shows up gradually - candles shrink over several bars rather than one dropping 35% below the average - so a threshold that strict only fires after the move has already stopped. At 0.78 the reading arrives while it is still happening, which is when it is useful.   // Below which it is running out of participants
input double CandleRejectionWickRatio    = 0.45;   // Wick share that marks a level being defended
input double CandleAbsorptionSizeRatio   = 1.60;   // Range size against average for absorption - effort
input double CandleAbsorptionMaxBody     = 0.30;   // Body share below which that effort produced no result
input int    CandleRejectionBonus        = 3;      // Trading with a defended level
input int    CandleRejectionPenalty      = 4;      // Trading against one - being on the side that just lost
input int    CandleAbsorptionPenalty     = 4;      // Trading into someone large on the other side
input int    CandleExpansionBonus        = 2;      // Small on purpose - the impulse checks already cover most of this
input int    CandleContractionPenalty    = 3;      // Entering with a move that is fading
input int    CandleInsidePenalty         = 2;      // The last candle resolved nothing, so readings from it are weaker than they look
input bool   CandleSequencePrintOnUse    = true;   // Log candle verdicts that change the score
input bool   ShowCandleStateOnDash       = true;   // Show the candle sequence reading

// V208: two questions the sequence reader cannot answer. WHERE the candle happened - a long lower
// wick at a support that has held before is sellers being refused at a level that refuses them,
// while the identical candle in open space is price dipping and someone buying. WHOSE wick it is -
// an upper wick on a bullish candle means buyers were turned back, the same wick on a bearish candle
// means sellers drove down from a high. Reading "upper wick" without the body treats opposites as
// one thing. Both refine the sequence reading rather than compete with it.
input bool   EnableCandleAuthorship      = true;   // Read the wick against the candle's own direction, not in isolation
input double CandleAuthorshipMinWick     = 0.40;   // Wick share before it says anything at all
input double CandleAuthorshipMinDominance = 0.15;  // How much one wick must exceed the other to be the one that counts
input double CandleAuthorshipAlignedFactor = 0.45; // Weight when the wick runs WITH the body - the extreme was simply where the bar started, which is weaker than a move taken back
input double CandleAuthorshipIndecisionBody = 0.30; // Body below which two comparable wicks mean both sides tried and neither finished in control
input double CandleAuthorshipMinToAct    = 0.35;   // Conviction needed before the wick is worth locating
input bool   EnableCandleLocation        = true;   // Weigh the rejection by what it happened at
input int    CandleLocationTolerancePoints = 700;  // How close ($0.70) the wick's tip must come to a level to have tested it
input double CandleLocationFullStrength  = 2.0;    // Zone strength at which location weight is full
input double CandleLocationMinSignal     = 0.30;   // Combined conviction x location below which this stays silent
input int    CandleLocationMaxScore      = 5;      // Ceiling on the adjustment - a rejection at a proven level is worth as much as most quality checks
input bool   CandleLocationPrintOnUse    = true;   // Log located rejections

// V209: candles judged by outcome rather than shape. Every reading so far is taken the moment a bar
// closes and then forgotten - which is the one moment it is least reliable, because a candle only
// means what the following bars let it mean. A long lower wick is a rejection until price trades
// back through it. A close beyond a level is a break until price comes straight back, at which
// point the level trapped it. So candles are recorded when they form and graded a few bars later,
// and what the EA gets is not "this looks like a rejection" but "rejections here have been holding".
input bool   EnableCandleFollowThrough   = true;   // Record candles and grade them once their outcome is known
input int    CandleFollowThroughBars     = 6;      // Bars before a candle is judged
input int    CandleFollowThroughTolerance = 200;   // Slack ($0.20) before a level is counted as violated
input int    CandleFollowThroughMinSamples = 6;    // Graded candles needed before the record is used
input int    CandleFollowThroughMaxSamples = 40;   // Sample ceiling - conditions change, and an old record describes a market that no longer exists
input double CandleFollowThroughPoorRate = 0.40;   // Hold rate below which this kind of candle has stopped being reliable here
input int    CandleFollowThroughAdjust   = 3;      // Score adjustment when the record is clearly good or clearly bad
input bool   CandleFollowThroughPrintOnUse = true; // Log each verdict
input bool   EnableCandleBreakQuality    = true;   // Distinguish a clean break from an attempt that was already being pushed back
input double CandleBreakWickPenaltyWeight = 0.8;   // How heavily a wick back past the close counts against a break
input double CandleBreakCleanMin         = 0.35;   // Quality above which the break is treated as real
input int    CandleBreakQualityScore     = 4;      // Score weight of break quality - directly relevant to the "support broke, sell again" case
input bool   ShowCandleFollowOnDash      = true;   // Show how rejections and breaks have been resolving

// V210: three readings the candle engine could not make.
// PARTICIPATION - a large candle on heavy tick volume is a market that showed up; the same candle
// on thin volume is a few orders moving an empty book, and it retraces as easily as it came.
// OPENING GAP - where a candle opens against the previous close says what happened between them; a
// bar that gaps up and closes below its open was sold into, which the body alone cannot show since
// it starts at the open. PATTERNS - shapes needing two or three bars in a specific arrangement are
// the ones that mark TURNS rather than continuations, and they are the natural confirmation for a
// setup that is waiting.
input bool   EnableCandleParticipation   = true;   // Weigh candles by the tick volume behind them
input int    CandleParticipationLookback = 20;     // Bars defining what volume is normal here
input double CandleParticipationStrong   = 1.60;   // Volume multiple that marks a candle the market showed up for
input double CandleParticipationThin     = 0.55;   // Below which the move happened on almost no participation
input int    CandleParticipationScore    = 3;      // Score weight of participation agreeing or disagreeing with the candle
input bool   EnableCandleOpeningBias     = true;   // Read where the candle opened against the previous close
input int    CandleOpeningMinGapPoints   = 150;    // Gap ($0.15) below which the open says nothing
input double CandleOpeningContinuationFactor = 0.5; // Weight when the gap continued rather than reversed - less informative than a rejected gap
input int    CandleOpeningScore          = 2;      // Score weight of the opening reading
input bool   EnableCandlePatterns        = true;   // Read two- and three-candle reversal shapes
input double CandlePatternMinBody        = 0.45;   // Body share for a candle to count as decisive within a pattern
input double CandlePatternStarMaxBody    = 0.35;   // Body share of the middle candle in a star - it has to be a pause
input double CandlePatternMinReclaim     = 0.50;   // How much of the first candle the reversal must take back
input double CandlePatternHaramiOuterBody = 0.55;  // Body of the large candle in a harami
input double CandlePatternHaramiInnerBody = 0.40;  // Body of the small one inside it
input int    CandlePatternTweezerTolerance = 250;  // How close two extremes must be ($0.25) to count as the same level refused twice
input int    CandlePatternScore          = 4;      // Score weight of a recognised pattern
input bool   CandlePatternConfirmsWait   = true;   // Let a reversal pattern complete an armed wait - the turn it marks is exactly what the wait was for
input double CandlePatternWaitMinConf    = 0.45;   // How cleanly a reversal pattern must have formed before it ends a wait on its own

// V211: patterns judged in context, by record, and against the higher timeframe.
input bool   EnablePatternLocation       = true;   // Weigh a pattern by the level it formed at - three candles in open space are three candles
input int    PatternLocationTolerancePoints = 900; // How close ($0.90) the pattern's extreme must sit to a level
input double PatternLocationFloor        = 0.45;   // Weight retained when a pattern formed nowhere in particular - reduced, not ignored
input bool   EnablePatternGrading        = true;   // Track whether each pattern actually works here
input int    PatternGradeHorizonBars     = 12;     // Bars before a pattern is graded
input int    PatternGradeWinPoints       = 700;    // Move ($0.70) that counts the pattern as having worked
input int    PatternGradeMinSamples      = 5;      // Graded occurrences before the record is used
input int    PatternGradeMaxSamples      = 30;     // Sample ceiling
input double PatternGradePoorRate        = 0.35;   // Win rate below which this shape has stopped working here
input double PatternGradePoorFactor      = 0.40;   // Weight multiplier for a shape with a poor record
input double PatternGradeGoodFactor      = 1.35;   // And for one that keeps working
input bool   PatternGradePrintOnUse      = true;   // Log pattern outcomes
input bool   EnableCandleHTF             = true;   // Read the higher timeframe candle alongside the lower one
input ENUM_TIMEFRAMES CandleHTFTimeframe = PERIOD_M15;  // V215: M5 -> M15, keeping one step above the sequence timeframe now that it reads M5.  // The timeframe that outranks the sequence reader
input double CandleHTFMinBody            = 0.40;   // Body share below which the higher candle is undecided and says nothing
input double CandleHTFStrongBody         = 0.65;   // Body share at which agreement is worth a bonus
input int    CandleHTFDisagreeScore      = 5;      // Maximum cost of trading against a decisive higher-timeframe candle
input int    CandleHTFAgreeScore         = 2;      // Bonus when both timeframes point the same way
input bool   CandleHTFPrintOnUse         = true;   // Log timeframe disagreements

// V212: the bar still forming. Every other reading waits for a close, which is correct and safe and
// costs a full minute - by the time an M1 rejection is confirmed, the move it signalled has been
// running for sixty seconds. The forming bar carries the same information earlier; the difficulty is
// that it is not yet a fact, since a wick at thirty seconds can be gone at fifty-five. So it is read
// and then weighted by how much of the bar has elapsed, and it never acts alone - it adjusts a
// decision the closed bars already support.
input bool   EnableLiveBarRead           = true;   // Read the bar currently forming, weighted by how far through it is
input double LiveBarMinProgress          = 0.35;   // Share of the bar that must have elapsed before its shape means anything - a bar 20% formed has had time for one push, which is not a shape
input double LiveBarMinSizeATR           = 0.35;   // Range against ATR below which the live bar is quiet rather than significant
input double LiveBarStrongBody           = 0.60;   // Body share at which the live bar counts as being driven
input double LiveBarMinWeight            = 0.20;   // Weight below which the reading is discarded entirely
input int    LiveBarScore                = 4;      // Full-weight score effect - reached only near the close, since the weight scales with the square of elapsed progress
input bool   LiveBarPrintOnUse           = true;   // Log live-bar adjustments
input bool   ShowLiveBarOnDash           = true;   // Show what the forming bar is doing

// V213: how the bar is CHANGING. V212 reads the forming bar as it is now, which misses the more
// informative thing - how it got there. A bar showing a long lower wick at forty seconds and none at
// fifty-five did not change shape; the buyers who defended that low were overrun inside the same
// minute, and that is stronger information than either snapshot because it says something was tried
// and beaten. The bar is sampled as it forms and what the EA reads is the DIFFERENCE between
// samples.
input bool   EnableLiveBarEvolution      = true;   // Track how the forming bar's shape changes, not just its current state
input double LiveSampleInterval          = 0.08;   // Bar progress between samples - a hundred samples of the same shape is not more information than eight
input double LiveWickFailedDrop          = 0.18;   // Wick share lost before it counts as having been traded through
input double LiveWickFailedMinPeak       = 0.30;   // Wick must have been at least this big to have meant anything when it existed
input double LiveBodyAbsorbedDrop        = 0.20;   // Body share given back before the push counts as absorbed
input double LiveBodyMinPeak             = 0.35;   // Body must have reached this before its loss says anything
input double LiveBodyGrowthMin           = 0.15;   // Body growth across samples that marks a push being sustained
input int    LiveEvolutionScore          = 5;      // Full-weight effect of an intra-bar change - the failed-wick case is among the clearest signals available
input bool   LiveEvolutionPrintOnUse     = true;   // Log intra-bar changes
input bool   EnableLiveApproach          = true;   // Notice price closing on a level right now
input int    LiveApproachPoints          = 800;    // Distance ($0.80) within which a level counts as being approached
input double LiveApproachMinStrength     = 1.4;    // Level strength below which the approach does not matter
input int    LiveApproachPenalty         = 3;      // Cost of entering while price runs into a level it has not tested yet
input bool   ShowLiveEvolutionOnDash     = true;   // Show what changed within the bar
input bool   CandlePatternPrintOnUse     = true;   // Log recognised patterns
input bool   ShowCandlePatternOnDash     = true;   // Show the current pattern reading
input double            RecentThrustMinEfficiency    = 0.55;   // Net/path ratio: how one-directional the move must be. Chop sits ~0.2-0.4 and is ignored; 0.55 = clearly directional.
input double            RecentThrustExhaustWickRatio = 0.45;   // A rejection wick against the thrust >= this fraction of the bar's range marks the thrust as stalling, which releases its block (so genuine reversals aren't locked out).

// FEATURE(zone-thrust-penalty): second layer for the same live-trading gap. A zone-retest signal is
// born purely from "price touched the level and printed a small bounce bar" - it never checks HOW
// price arrived. When price arrives WITH a thrust, that small bounce is usually just a pause before
// the level breaks, so fading it is what lost money. Rather than hard-blocking (zone retests are the
// bot's main signal source and most of them are fine), apply a score penalty: strong setups still
// pass, thin ones no longer do.
input bool              EnableZoneThrustPenalty      = true;   // Penalise fading a level that price is arriving at with a thrust
input int               ZoneThrustPenaltyPoints      = 4;      // Score penalty when the entry fades an arriving thrust
input double            ExhaustionWickRatio      = 0.55;
input bool              MarketEvaluateOnNewBarOnly = false;

input group "39 — LEGACY SIRUS UPGRADE PACK"
input bool              UseLegacyUpgradePack     = false;  // OFF - duplicated/score-stacked with the main scanner (Sweep/FBR/Near-Zone) using older, unconfirmed zone detection
input bool              LegacyUseSmartSRZones    = true;
input bool              LegacyShowSRZoneLines    = true;
input int               LegacySRLookbackBarsM15  = 96;
input int               LegacySRLookbackBarsH1   = 120;
input int               LegacySRSwingDepth       = 3;
input int               LegacyNearZonePoints     = 900;
input bool              LegacyUseBOSRetest       = true;
input int               LegacyBOSLookbackBars    = 24;
input int               LegacyBOSRetestBars      = 8;
input bool              LegacyUseLiquiditySweep  = true;
input int               LegacySweepLookbackBars  = 12;
input bool              LegacyUseFakeBreakout    = true;
input bool              LegacyUseTrendExhaustion = true;
input bool              LegacyUseRoadblockGuard  = true;
input int               LegacyRoadblockMinRoomPts= 900;
input bool              LegacyUseSessionDNA      = true;
input int               LegacyAsiaStartHour      = 0;
input int               LegacyLondonStartHour    = 7;
input int               LegacyNYStartHour        = 13;
input bool              LegacyUseManualNewsGuard = false;
input int               LegacyNewsStartHour      = 0;
input int               LegacyNewsEndHour        = 0;
input int               LegacyBoostSweep         = 2;
input int               LegacyBoostZoneReaction  = 2;
input int               LegacyBoostBOSRetest     = 1;
input int               LegacyBoostFakeBreakout  = 2;
input int               LegacyPenaltyRoadblock   = 2;
input int               LegacyPenaltyExhaustion  = 2;
input bool              LegacyHardBlockNews      = true;
input bool              LegacyHardBlockRoadblock = false;
input bool              PrintLegacyUpgradeEvents = true;

input group "40 — FILTERS / ENVIRONMENT"
input ENUM_TIMEFRAMES   CoreBarTF                = PERIOD_M1;
input int               CoreTimerSeconds         = 1;
input bool              StrictGoldSymbolCheck    = true;
input string            RequiredSymbolKeyword    = "XAUUSD";
input int               MaxSpreadPoints          = 500;    // V90b: 300 -> 500 ($0.50) to match UnifiedMaxSpreadPoints; normal-spread gate.
input int               CriticalSpreadPoints     = 800;    // V90b: 300 -> 800 ($0.80). This is the ABSOLUTE hard stop; it must sit ABOVE MaxSpread so the two form a real two-stage guard (was equal to it, making the softer stage dead). $0.80 only trips on genuine spread blowouts (news, thin liquidity).
input int               MaxTickAgeSeconds        = 180;
input int               MinBarsM1                = 100;
input int               MinBarsM5                = 100;
input int               MinBarsM15               = 100;
input int               MinBarsH1                = 100;
input bool              RequireTradePermission   = true;
input bool              RequireFullTradeMode     = true;

input group "41 — NEWS / SESSION SETTINGS"
// V31.6e cleanup: removed UseNewsFilter/NewsMinutesBefore/NewsMinutesAfter - dead, redundant
// with EnableEconomicCalendarGuard (the real, MT5-native calendar system). Also removed
// UseSessionFilter/AllowAsia/AllowLondon/AllowNewYork - dead, no session-gating logic ever
// existed anywhere. NY killzone caution is now handled by section 75 instead.

input group "42 — DASHBOARD / BRANDING"
input int               DashboardRefreshSeconds  = 1;
input int               ExpertsHeartbeatSeconds  = 30;
input bool              ShowDashboard            = true;
input bool              UsePremiumDashboard      = true;
input bool              DashboardCompactMode     = true;
input bool              ShowDashboardSignalBlock = true;
input bool              ShowDashboardMarketBlock = false;
input bool              ShowDashboardEnvBlock    = false;
input bool              ShowDashboardCounters    = false;
input int               DashboardMaxRows         = 34;
input int               DashboardLineSpacing     = 14;
input bool              UsePremiumLogEngine      = true;
input int               PremiumLogSnapshotSeconds = 60;
input bool              PrintPremiumNextAction   = true;
input bool              PrintExpertsHeartbeat    = true;
input bool              PrintNewBarLog           = true;
input bool              PrintEnvOnChange         = true;
input bool              PrintModeOnChange        = true;
input bool              PrintMarketOnChange      = true;
input bool              PrintTickStaleWarning    = true;
input string            TelegramContact          = "@farruh_zakiy";
input bool              UseVPSLiveValidation     = true;
input int               VPSValidationSeconds     = 30;
input int               VPSMaxTickSilentSeconds  = 120;
input int               VPSMaxM1BarSilentMinutes = 5;
input int               VPSMinTicksPerMinute     = 1;
input bool              VPSWarnIfNotM1Chart      = false;
input bool              VPSPrintNoTradeAudit     = true;
input int               VPSNoTradeAuditSeconds   = 120;
input bool              VPSPrintBrokerSnapshot   = true;
input int               VPSBrokerSnapshotSeconds = 300;
input int               DashboardCorner          = 0;
input int               DashboardX               = 10;
input int               DashboardY               = 24;
input int               DashboardFontSize        = 10;

//====================================================================
//  V29 NEW MODULES — added on top of v24 (see V29-01..V29-13 groups below)
//  Ported from v28 where noted, plus new engineering not present in either.
//====================================================================
input group "43 — OPERATOR CONTROL / MANUAL PAUSE"
input bool   OperatorPauseAllNewOrders   = false;   // Blocks all new entry/recovery requests, basket management stays active
input bool   OperatorPauseFirstEntries   = false;   // Blocks first entries only, recovery/grid still runs
input bool   OperatorPauseRecoveryGrid   = false;   // Blocks recovery/grid requests only, first entries still run

input group "44 — DAILY PROFIT GOVERNOR"
input bool   EnableDailyProfitGovernor          = true;   // Daily profit monitor/lock; 0 target = monitor only
input double DailyProfitTargetPercent           = 0.0;    // 0=disabled; e.g. 10 = lock new entries after +10% day equity
input bool   DailyProfitBlockNewEntriesAtTarget = true;   // After target reached, block fresh first entries
input bool   DailyProfitBlockRecoveryAtTarget   = false;  // After target reached, optionally block recovery/grid too
input bool   EnableDailyProfitTrailLock         = false;  // Protect gained daily profit from giveback
input double DailyProfitTrailStartPercent       = 5.0;    // Trail arms once daily profit reaches this percent
input double DailyProfitTrailGivebackPercent    = 35.0;   // % giveback from daily peak equity that triggers trail lock
input bool   DailyProfitBlockNewEntriesOnTrail  = true;   // Trail lock blocks fresh first entries
input bool   DailyProfitBlockRecoveryOnTrail    = true;   // Trail lock blocks recovery/grid too
input bool   DailyProfitPrintOnLock             = true;   // Print once when target/trail lock fires

input group "45 — SETTINGS SANITY"
input bool   EnableSettingsSanityGovernor      = true;   // Catches dangerous/conflicting settings before live trading
input bool   SettingsSanityBlockLiveOnCritical = true;   // Critical config mismatch blocks live order requests
input int    SettingsSanityMinGridPoints       = 1500;   // GridDistancePoints below this is treated as dangerous
input int    SettingsSanityMinTPPoints         = 300;    // FirstEntryTPMinPoints below this is treated as dangerous
input bool   SettingsSanityPrintOnChange       = true;    // Print only when sanity state changes

input group "46 — LICENSE / ACCOUNT GUARD"
input bool   EnableLicenseAccountGuard   = false;    // Optional client/account access guard; default OFF for owner tests
input bool   LicenseGuardBlockLiveInvalid = true;    // If guard enabled and invalid, block live orders
input string LicenseAllowedAccounts      = "";       // Comma list: 12345,67890. Empty = any account allowed
input string LicenseExpiryDate           = "";       // Format YYYY.MM.DD. Empty = no expiry
input string LicenseClientName           = "SIRUS CLIENT";

input group "47 — SETUP DOCTOR"
input bool   EnableSetupDoctor              = true;   // Diagnose common client/VPS setup mistakes
input bool   SetupDoctorBlockLiveInvalid    = true;   // Block live orders if terminal/account/symbol setup is invalid
input bool   SetupDoctorRequireTradeAllowed = true;   // Terminal/account/MQL trade permission must be allowed
input bool   SetupDoctorPrintOnChange       = true;   // Print setup state only when changed

input group "48 — ZONE MAP / TP GUARD"
input bool   EnableZoneMapTPGuard    = true;    // Cap TP before a nearby H1/M15 wall instead of ignoring it
input int    ZoneMapLookbackH1       = 240;     // V110: 80 -> 240. H1 candles scanned for nearest wall. At 80 this only reached back 3.3 DAYS, so levels built 4-7 days ago were invisible to the whole zone system (live chart: the 4020 and 4070 zones were never seen while 4000 and 4165 were). 240 = 10 days, which covers the swing structure price actually respects. The swing cache is per-bar and capped at 80 zones per TF, so this costs almost nothing.
input int    ZoneMapLookbackM15      = 200;     // V110: 120 -> 200. M15 candles scanned (200 = ~2 days), so intraday levels from the previous session stay in view.
input int    ZoneMapBufferPoints     = 150;     // Keep TP this many points before the wall
input bool   ZoneMapPrintOnUse       = false;   // Print only when TP actually gets capped
input bool   EnableZoneMapMomentumCaution = true;  // Momentum/trend entries ignore zones by default - this adds soft caution
input int    ZoneMapMomentumCautionPoints = 400;   // If a wall is this close ahead, trim lot instead of blocking
input double ZoneMapMomentumLotFactor     = 0.5;   // Lot multiplier applied when momentum entry is near a wall
input bool   EnableZoneMapGridAwareness   = true;  // Let grid distance shorten toward a real H1/M15 zone; never lengthens it
input int    ZoneMapGridBufferPoints      = 100;   // Small buffer added beyond the zone for the grid target
input double ZoneGridMinStrength          = 1.5;   // Zone must be at least this strong to shrink grid distance
input bool   EnableZoneMapSwingConfirm    = true;   // V29: require a genuine confirmed swing point, not any candle wick
input int    ZoneMapSwingDepth            = 3;      // Bars required on each side to confirm a swing high/low

input group "49 — HTF STRUCTURE COMMANDER"
input bool   EnableHTFStructureWarn  = true;    // Warn + trim lot when entry is counter to H1 structure
input int    HTFStructureLookbackBars = 20;     // H1 bars back to compare for trend bias
input bool   HTFStructurePrintOnUse  = false;   // Print only when a counter-trend entry is detected
input double HTFStructureCounterLotFactor = 0.6; // Lot multiplier when entry is counter to H1 bias (never blocks)

input group "50 — REAL RETRY ENGINE"
input bool   EnableRealRetryEngine        = true;   // Real backoff on transient broker errors, no Sleep()
input int    RetryDelaySeconds            = 3;      // Wait between transient-error retries (requote/timeout/connection)
input int    RetryMaxAttempts             = 3;      // Max consecutive transient retries before a longer cooldown
input int    RetryGiveUpCooldownSeconds   = 60;      // Cooldown once max attempts exhausted
input int    RetryNonTransientCooldownSeconds = 20;  // Wait after a non-transient failure (no money, invalid stops, etc.)
input bool   RetryPrintOnUse              = true;

input group "51 — CORRELATION GUARD"
input bool   EnableCorrelationGuard       = true;    // Trim lot when other open positions compound this symbol's risk
input ENUM_TIMEFRAMES CorrelationTF       = PERIOD_H1;
input int    CorrelationLookbackBars      = 100;     // Bars used to compute price correlation
input double CorrelationHighThreshold     = 0.75;    // |correlation| above this is considered compounding
input double CorrelationLotFactor         = 0.5;     // Lot multiplier applied when compounding exposure detected
input bool   CorrelationPrintOnUse        = false;

input group "52 — SPREAD-AWARE MINIMUM TP"
input bool   EnableSpreadAwareTP          = true;
input double SpreadAwareMinRatio          = 3.0;     // TP must be at least this many times the current spread
input int    SpreadAwareCommissionPoints  = 0;       // Optional extra buffer for commission-equivalent points
input bool   SpreadAwarePrintOnUse        = false;

input group "53 — REAL ECONOMIC CALENDAR"
input bool   EnableEconomicCalendarGuard    = true;
input string EconomicCalendarCurrency       = "USD"; // Currency to scan; leave blank to scan all
input int    EconomicCalendarMinImportance  = 2;     // 1=Moderate+High, 2=High only
input int    EconomicCalendarPreMinutes     = 15;    // Caution window before a high-impact event
input int    EconomicCalendarPostMinutes    = 15;    // Caution window after a high-impact event
input int    EconomicCalendarRefreshSeconds = 300;   // Do not query the calendar every tick
input bool   EconomicCalendarHardBlockFirst = true;  // Block new entries in the news window
input double EconomicCalendarLotFactor      = 0.4;   // Lot multiplier during caution window when not hard-blocking
input bool   EconomicCalendarPrintOnUse     = true;

input group "54 — SMART PARTIAL CLOSE"
input bool   EnableSmartPartialClose      = false;  // V62b: OFF on user report. Partial close trims part of the basket, but basket_points is measured from the AVERAGE entry price, and closing individual positions SHIFTS that average - typically the wrong way, so the remaining lot needs price to travel FURTHER to reach TP. Observed live: 0.20 opened, 0.07 trimmed at +2200pts, 0.13 left, and the TP kept moving away. This fundamentally fights the martingale-grid logic (grid ADDS to improve the average; a partial trim WORSENS it), so the two should not run together. The basket now rides intact to its normal TP / trailing / SL.
input int    PartialCloseMinOrders        = 2;       // Only when basket has at least this many orders
input int    PartialCloseAtProfitPoints   = 1500;  // Basket profit points required to trigger partial close
input double PartialClosePercent          = 35.0;     // Percent of each position's volume to close
input bool   PartialClosePrintOnUse       = true;

input group "55 — FIRST ENTRY TREND-AGAINST GUARD"
input bool   EnableFirstEntryTrendGuard         = true;   // Trim lot when opening straight against a strong HTF/BOS trend
input double FirstEntryTrendAgainstLotFactor    = 0.4;    // Lot multiplier applied when trend/BOS strongly oppose the entry
input bool   FirstEntryTrendGuardPrintOnUse     = true;

input group "56 — IMPULSE / CORRECTION COOLDOWN"
input bool   EnableImpulseCooldown              = true;   // Keep grid cautious for a few bars after an impulse, not just the spike bar
input int    ImpulseCooldownBarsCorrection      = 2;      // Shorter cooldown: impulse was against the established trend (likely a pullback)
input int    ImpulseCooldownBarsTrend           = 5;      // Longer cooldown: impulse aligned with the established trend (possible acceleration)
input bool   ImpulseCooldownPrintOnUse          = false;

// V115: the impulse cooldown above was only ever consulted by GridCanOpen, so after a big candle the
// grid waited but a brand-new basket could still be opened on the very next tick. The user noticed
// this from live behaviour ("it used to wait when a big candle appeared"). Opening a fresh basket
// into a just-printed impulse is worse than adding to one: the entry price is the worst of the move,
// spread is widest, and the snap-back is most likely. Apply the same wait to first entries.
input bool   EntryBlockFreshImpulse             = true;   // Also make FIRST ENTRIES wait out the impulse cooldown (not just grid additions)
input int    EntryImpulseCooldownBars           = 0;      // 0 = use the same ImpulseCooldownBarsCorrection/Trend values as the grid. Set a number to give first entries their own (usually longer) wait.

input group "57 — MULTI-BAR VELOCITY CHECK"
input bool   EnableMultiBarVelocityCheck        = true;   // Catch sustained multi-candle moves a single-candle impulse check would miss
input int    VelocityLookbackBars               = 4;      // Net move measured over this many closed bars
input double VelocityATRMultiplier              = 3.0;    // Net move vs ATR(SignalTF) multiplier to count as dangerous velocity

input group "58 — MULTI-TIMEFRAME ZONE MAP"
input bool   EnableZoneMapM5                    = true;
input int    ZoneMapLookbackM5                  = 150;
input bool   EnableZoneMapM30                   = true;
input int    ZoneMapLookbackM30                 = 200;    // V110: 100 -> 200 (~4 days), closing the gap between the M15 and H1 windows.
input bool   EnableZoneMapH4                    = true;
input int    ZoneMapLookbackH4                  = 180;    // V272: 90 -> 180, fifteen days to thirty. H4 and H1 currently cover the same fortnight and largely duplicate each other; extending H4 gives the pair distinct jobs - H1 for the recent context, H4 for the structure behind it.     // V110: 60 -> 90 (~15 days), so the swing structure above H1 is properly covered.
input bool   EnableZoneMapD1                    = true;
input int    ZoneMapLookbackD1                  = 120;    // V272: 45 -> 120, roughly six months of trading. These are the levels that matter when price leaves the range it has been working in - after a large move there are no recent swings in the new territory by definition, and what remains is the round numbers and the turns from months ago. Daily bars are few, so the cache absorbs this without strain.     // V110: 30 -> 45 (~1.5 months), for the major levels price returns to weeks later.
input bool   EnableZoneMapM1                     = true;    // V31.6z16 NEW: real gap found via live testing - a level bouncing repeatedly on M1 was completely invisible to the whole zone system before (it only ever scanned M5 and up)
input int    ZoneMapLookbackM1                   = 200;
input double ZoneMapM1TouchWeight                 = 0.4;    // M1 touches are far more frequent/noisy than H1/D1 ones - down-weighted so they add real signal without dominating the confluence count
input bool   EnableZoneMapBestPick                = true;    // V31.6z42 NEW: real gap found - the core zone finder always picked the NEAREST swing point regardless of significance, so a moderately-strong HTF level slightly further away could be invisible while an insignificant, barely-closer M1 swing won by default
input double ZoneMapBestPickDistancePenalty       = 0.0006;  // per-point distance penalty when weighing a zone's TF significance against how far it is (used by the weighted best-zone pick)

// FEATURE(strong-zone-override): the plain nearest-zone scan returns the CLOSEST support/resistance
// and ignores strength, so a small local level right in front of price hides a much stronger, older
// level a little further away (the "koradi vs kormedi" case: price blew through the near level and
// sat in drawdown until it reached the real zone further off). After finding the nearest zone, also
// find the strongest zone within a search window; if that stronger zone is meaningfully stronger and
// not too much further, prefer it. Applies to both support and resistance. 3-digit: 1000pt = $1.
input bool   EnableStrongZoneOverride  = true;   // V201: ON. This was already written and already correct - it prefers a clearly stronger level a little further away over the merely-closest one, which is exactly the failure behind the losing entries. It has been switched off, so the EA has been reading a minor swing as "the level" while the real one sat unseen just beyond it. Turning it on costs nothing; it only changes which level is reported when a much stronger one is within reach.   // OFF by default: this REPLACES the nearest zone with a stronger further one, which is not the same as remembering broken levels (see ghost-zone feature below). Left in code but disabled unless explicitly wanted.
input int    StrongZoneSearchPoints    = 20000;   // How far past the nearest zone to look for a stronger one (20000 = $20)
input double StrongZoneMinScoreRatio   = 1.25;  // V201: 1.5 -> 1.25. The further level had to score 50% higher before it displaced the nearest - and since strength is 1.0 + touches x 0.25, that meant a four-touch level could not outrank a one-touch swing. At 1.25 a three-touch level (1.75) displaces an untested one (1.25), which is the case that was costing money.     // The stronger zone's weighted score must beat the nearest zone's by at least this ratio to take over

// FEATURE(ghost-zones): a support/resistance that gets broken doesn't vanish from a trader's mind -
// price often returns to RETEST it and reacts there. The scanner only tracks currently-intact
// levels, so once price closes through a level it disappears and the bot is blind to it. This keeps
// a broken H1/H4/D1 level as a "ghost" reaction zone for a few days: if price comes back to it, it
// is treated as a possible reversal point (the bot won't enter continuing INTO it). Only H1+ levels
// qualify - lower TFs break constantly and would just fill the chart with noise. 3-digit: 1000pt=$1.
input bool   EnableGhostZones          = true;    // Remember broken H1/H4/D1 levels as reaction zones
input int    GhostZoneBreakPoints      = 2500;    // A level counts as BROKEN once price closes this far past it (2500 = $2.5), filtering wick pokes / fakeouts
input int    GhostZoneMaxCount         = 10;     // V206: 4 -> 10. Ghost zones are levels that have BROKEN - price went through them - and they matter because price returns to retest them. Four slots covered a few hours; a support broken this morning was already forgotten by afternoon, so a second sell into the same level looked like fresh ground.       // Keep at most this many ghost zones (nearest to price); oldest/furthest are dropped
input double GhostZoneStrengthFactor   = 0.65;    // A ghost's strength = its original strength x this (a broken level still matters, but less than an intact one)
input int    GhostZoneReactionPoints   = 1500;    // How close price must come back to a ghost to treat it as an active reaction zone (1500 = $1.5)
input int    GhostZoneTTLDaysH1        = 3;       // Days an H1-origin ghost stays alive
input int    GhostZoneTTLDaysD1        = 7;       // Days a D1-origin ghost stays alive
// M5/M15 also form ghosts on user report (their broken levels react often), but only STRONG ones -
// a strength filter keeps the chart from filling with the many trivial levels those TFs break daily.
input bool   EnableGhostZonesLowTF     = true;    // Also remember broken M5/M15 levels (strong ones only)
input double GhostZoneLowTFMinStrength  = 1.5;    // V87b: 1.8 -> 1.5. The user observes broken-level reactions mostly on M5/M15, so the filter was letting real zones through only when very strong. 1.5 still needs a genuine multi-touch level (not every minor break) but catches the mid-strength zones price actually reacts at.
input int    GhostZoneLowTFBreakPoints  = 1500;   // Break distance for M5/M15 ghosts (1500 = $1.5; smaller than the HTF $2.5 since these TFs move less per bar)
input int    GhostZoneTTLDaysM15        = 2;      // Days an M15-origin ghost stays alive
input int    GhostZoneCrossLookbackBars  = 6;     // Bars back to sample price when deciding a level was actually CROSSED (was on the other side then, this side now), not merely nearby
input bool   GhostZoneHardBlock       = false;   // false = ghost applies a SCORE PENALTY (a ghost is a probability, not a certainty, so by default it discourages rather than forbids - a strong enough signal still passes). true = hard-block like the other context guards.
input int    GhostZoneScorePenalty    = 4;       // Penalty applied to a signal running into a ghost when not hard-blocking

// FEATURE(impulse-correction-penalty): buying into a shallow bounce while a DOWN impulse is still
// alive (or selling into a shallow dip during an UP impulse) is exactly the "caught against the
// move" loss the user showed - price corrects a little, the bot enters with the correction, then the
// impulse resumes. Penalise a counter-impulse entry while the retracement is still SHALLOW (impulse
// likely not done). Once price has retraced past the threshold the impulse may be over, so we stop
// penalising and let normal signals through. Soft (score penalty), consistent with the other guards.
input bool   EnableImpulseCorrectionPenalty = true;   // Penalise entering WITH a shallow correction against a live impulse
input double ImpulseCorrectionDonePercent    = 50.0;  // Retracement % at/above which the impulse is treated as possibly finished (no penalty). Below this, a counter-impulse entry is penalised.
input int    ImpulseCorrectionPenaltyPoints  = 4;     // Score penalty for a counter-impulse entry during a shallow correction
input int    ImpulseCorrectionPenaltyWindowBars = 20; // Only apply within this many bars of the impulse (after that the impulse is stale)// How much score is lost per point of extra distance - tuned so a full timeframe-weight advantage (e.g. D1 vs M15, 3.0 vs 1.0 = 2.0) offsets roughly 3300 points of extra distance

input group "59 — KALMAN FILTER TREND"
input bool   EnableKalmanTrend        = true;    // Upgrades HTF trend slope from SMA to a Kalman (alpha-beta) filter
input double KalmanAlpha              = 0.35;    // Level gain: higher = reacts faster to new price, less smooth
input double KalmanBeta               = 0.05;    // Trend gain: higher = trend estimate reacts faster, less stable
input int    KalmanWarmupBars         = 30;      // Bars needed before the filter is trusted (falls back to SMA until then)
input double KalmanTrendMinPoints     = 5.0;     // Minimum trend slope (points/bar) to call it up/down, not flat
input bool   KalmanPrintOnUse         = false;

input group "60 — ZONE STRENGTH / CONFLUENCE"
input bool   EnableZoneStrength             = true;   // Score a zone by how many TFs/touches confirm it, not just distance
input int    ZoneStrengthTolerancePoints    = 80;      // Two swing points within this many points count as the same zone
input double ZoneStrengthPerTouch           = 0.25;    // Strength added per confirming swing point found nearby

// V234: which timeframe drew the level. Touch count alone cannot say - four touches on M1 and four
// on H1 produce the same number and they are not the same level. An M1 swing is where price paused
// for a few minutes; an H1 swing is where it turned for hours, and the people who defended it are
// still watching. This is the reading behind the loss where an M1 break looked clean while M5 and
// M15 had never moved at all.
input bool   EnableZoneTFWeight          = true;   // Weigh a level by the largest timeframe that recognises it
input int    ZoneTFMatchTolerance        = 250;    // How close ($0.25) a cached swing must be to count as the same level
input double ZoneTFWeightLowest          = 0.70;   // M1 - where price paused, not where it turned
input double ZoneTFWeightLow             = 1.00;   // M5 - the scale the setups are built on, so the baseline
input double ZoneTFWeightMid             = 1.20;   // M15 and M30
input double ZoneTFWeightHigh            = 1.40;   // H1
input double ZoneTFWeightHigher          = 1.65;   // H4 and D1 - levels with a day or more of history behind them

// V235: two things a touch count cannot see. RETESTS - price visiting a level four times in one
// approach is a pause; visiting, leaving, and returning is the market recognising it. LIQUIDITY -
// a long wick through a level means stops were taken there or are waiting, and price is drawn back
// to that. A level that attracts price is the opposite of one that turns it away.
input bool   EnableZoneRetestCount       = true;   // Count returns to a level, not just touches
input ENUM_TIMEFRAMES ZoneRetestTF       = PERIOD_M5;   // Timeframe returns are counted on
input int    ZoneRetestLookback          = 100;    // Bars searched
input int    ZoneRetestTolerance         = 400;    // How close ($0.40) counts as being at the level
input int    ZoneRetestAwayPoints        = 1200;   // How far ($1.20) price must travel before coming back counts as a return rather than hovering
input double ZoneRetestBonusPer          = 0.15;   // Strength added per return
input double ZoneRetestMaxBonus          = 0.45;   // Ceiling - three returns is confirmation; ten means a range boundary, which touches already count
input bool   EnableZoneWickCheck         = true;   // Reduce a level with a long wick through it
input ENUM_TIMEFRAMES ZoneWickTF         = PERIOD_M15;  // Timeframe the wick is read on - lower ones show noise
input int    ZoneWickLookback            = 8;      // Bars searched
input double ZoneWickMinRatio            = 0.40;   // Wick share of its bar before it counts as liquidity
input int    ZoneWickTolerance           = 600;    // How close ($0.60) the wick tip must reach
input double ZoneWickPenalty             = 0.35;   // How much a full wick reduces the level

// V132: zone strength used to be a pure touch COUNT (1.0 + touches x 0.25), so a level needed four
// tests before it could reach the 1.8 the counter-zone block requires. A level that had thrown price
// back once, hard, scored only 1.25 - and the EA sold straight into one, which went into drawdown.
// These add the missing dimension: how far price travelled AWAY from the level after touching it.
input bool   EnableZoneReactionStrength   = true;   // Add rejection strength (how hard price was thrown back) to a zone's strength, not just how often it was touched
input ENUM_TIMEFRAMES ZoneReactionTF      = PERIOD_M15;  // Timeframe the rejections are measured on
input int    ZoneReactionLookbackBars     = 200;    // How far back to look for touches of the level
input int    ZoneReactionHorizonBars      = 12;     // Bars after a touch in which the move away is measured
input double ZoneReactionMinATR           = 1.0;    // A rejection must travel at least this many ATR to count at all (filters ordinary drift)
input double ZoneReactionWeight           = 0.45;   // Strength added per ATR of rejection beyond the minimum
input double ZoneReactionMaxBonus         = 1.20;   // Ceiling on the rejection bonus so one huge move cannot make every level unbreakable

// V141: zone decay. Strength counted touches and ADDED for each one, so the levels the market had
// eaten most were the ones the EA trusted most - the exact opposite of how a level behaves. The
// orders resting there are finite: each test spends some, which is why a fourth touch so often
// breaks. Decay is read from the reactions themselves (recent bounces weaker than early ones) plus
// a floor-level allowance for sheer number of tests.
input bool   EnableZoneDecay              = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int    ZoneDecayMinTouches          = 3;      // Touches needed before early-vs-recent reactions can be compared
input int    ZoneDecayFreeTouches         = 3;      // Touches allowed before the count itself starts implying decay
input double ZoneDecayPerExtraTouch       = 0.12;   // Decay added per touch beyond that allowance
input double ZoneDecayWeight              = 0.55;   // How much of the measured decay is applied to strength (1.0 = full effect)
input double ZoneDecayMinRetain           = 0.70;  // V200: 0.45 -> 0.70. The floor on how far a level can be discounted. At 0.45 a three-touch zone scoring 1.75 fell to 0.79 - below an untested single swing - purely for having been tested.   // A worn level never falls below this fraction of its strength - even a spent level still holds something
input double ZoneDecayApplyBelow         = 0.85;   // V200: decay only engages below this retention figure - that is, only where reactions have measurably weakened. Above it the level is being tested and holding, which is evidence for it rather than against.
input bool   EnableZoneRoundNumberBonus     = true;    // Small extra weight for round-number price levels (e.g. x50, x100)
input double ZoneRoundNumberStep            = 50.0;    // Round-number spacing to check against (price units, not points)
input double ZoneRoundNumberTolerancePoints = 60.0;    // How close to the round number counts as "on it"
input double ZoneRoundNumberBonusWeight     = 0.5;     // Strength bonus if the zone sits on a round number

// V148: who is the level for? A round number or a clean obvious swing is where retail stops sit -
// price is DRAWN to it, takes them, and often turns straight after. It is a magnet, not a wall. A
// band price spent real time inside and tested without breaking is where size rests; that one
// holds. The EA treats a round number as extra strength, which reads the retail case backwards.
// The deciding factor is HISTORY, not price: an untested round number is a magnet, but one that has
// held repeatedly has become a real level.
input bool   EnableParticipantModel         = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input double ParticipantRoundNumberWeight   = 1.0;    // Evidence toward RETAIL when the level sits on a round number
input double ParticipantUntestedRoundWeight = 1.2;    // Extra retail evidence when that round number has not been tested - obvious to everyone, defended by no one
input int    ParticipantBandWidthPoints     = 2000;   // Band width ($2.00) that counts as a real area rather than a line
input double ParticipantBandWeight          = 1.0;    // Evidence toward INSTITUTIONAL for occupying an area
input int    ParticipantHoldTouches         = 3;      // Touches after which "has it held?" becomes the decisive question
input double ParticipantMaxDecayToHold      = 0.40;   // Decay below which a repeatedly-tested level counts as still holding
input double ParticipantHeldWeight          = 1.5;    // Evidence weight of that hold test - the strongest single signal
input int    ParticipantRetailFadePenalty   = 2;      // Penalty for trading a bounce off a RETAIL level before its stops are taken
input int    ParticipantInstBonus           = 2;      // Bonus for trading a bounce off an INSTITUTIONAL level
input double ParticipantMinConfidence       = 0.35;   // Confidence needed before the profile affects the decision
input bool   ParticipantPrintOnUse          = true;   // Log profiles that change a decision

// V149: path density. The room check knows where the FIRST wall is, which answers "can the target
// be reached" but nothing about what lies beyond it. One wall with open road behind it and five
// walls stacked every dollar both report the same first distance, yet the first is a scalp and the
// second is a grind where a $2.50 target must survive five separate stalls. Density measures how
// hard the path is; the largest gap says whether there is open road worth aiming at.
input bool   EnablePathDensity          = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES PathDensityTF     = PERIOD_M15;  // Timeframe whose levels form the path
input int    PathDensityRangePoints     = 10000;  // How far ahead to survey ($10)
input int    PathDensityMergePoints     = 700;    // Levels within this distance are one wall, not several ($0.70)
input double PathDensityCrowdedPerDollar = 0.60;  // Walls per $1 above which the path counts as crowded
input int    PathDensityCrowdedPenalty  = 2;      // Penalty for entering into a crowded path
input double PathDensityClearGapFactor  = 1.5;    // A gap this many times the basket target counts as genuinely open road
input int    PathDensityClearBonus      = 2;      // Bonus when open road lies ahead
input bool   PathDensityPrintOnUse      = false;  // Log path readings that change a decision

// V150: market scale. Every structural threshold here is a fixed number tuned against a particular
// market - cluster within $2.50, merge walls within $0.70. When the market changes character those
// numbers stop meaning what they meant: in a quiet session $2.50 swallows half the chart into one
// band, in a volatile one it splits a single zone into five. ATR is the usual fix but measures BAR
// size, not structure size - a market can print small bars while swinging widely. The typical
// distance between consecutive swings is the unit the thresholds actually want.
input bool   EnableMarketScale          = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES MarketScaleTF     = PERIOD_M15;  // Timeframe the scale is measured on
input int    MarketScaleMaxSwings       = 20;     // V150b: 12 -> 20. Swing pairs sampled - a wider sample changes less abruptly as individual swings enter and leave it.
input double MarketScaleSmoothAlpha     = 0.12;   // EMA weight for new readings (0.12 = slow drift, not steps)
input double MarketScaleDeadBandPct     = 8.0;    // Changes smaller than this % are ignored entirely - the market has not really changed scale
input double MarketScaleMaxStepPct      = 6.0;    // Maximum the scale may move in one bar (%), so even a real regime change is walked into gradually
input int    MarketScaleMinSwings       = 4;      // Minimum samples before the scale is trusted at all
input int    MarketScaleReferencePoints = 3000;   // The scale the fixed thresholds were tuned against ($3.00). Above it thresholds widen, below it they tighten.
input double MarketScaleMinFactor       = 0.60;   // Floor on the adjustment - a misread scale cannot shrink a threshold past this
input double MarketScaleMaxFactor       = 1.80;   // Ceiling on the adjustment
input bool   ShowMarketScaleOnDash      = false;  // V170d: default OFF. o'lchov birligi - sozlashda kerak, kunlik kuzatuvda emas. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V151: forced flow. Most moves are decisions - someone chose, and the move can pause or reverse at
// any point. A minority are liquidations: margin calls, stop-outs, hedges unwinding. Those orders
// must be filled regardless of price, which is why they run straight, refuse to retrace, and snap
// back hard once the forced supply is exhausted. The EA sees both as "a strong move", yet they need
// opposite handling: fading a decision is dangerous, while fading a spent liquidation is one of the
// best reversals available - the seller was never willing and there is nothing behind them.
input bool   EnableForcedFlow           = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES ForcedFlowTF      = PERIOD_M5;   // Timeframe the flow is measured on
input int    ForcedFlowLookbackBars     = 8;      // Bars covering the move
input double ForcedFlowMinSizeATR       = 2.5;    // Move must be at least this many ATR to qualify at all
input double ForcedFlowFullSizeATR      = 5.0;    // Size at which the "unusually large" signature is fully present
input double ForcedFlowMaxPullback      = 0.25;   // Deepest allowed retracement (25% of the move). A decision breathes; forced flow does not.
input double ForcedFlowMinBodyRatio     = 0.65;   // Candle bodies must be at least this fraction of range - forced fills leave little wick
input int    ForcedFlowAgainstPenalty   = 5;  // V173: 3 -> 5. majburiy buyurtmalar oldida turish - ular narxni so\'ramaydi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering INTO live forced flow - it does not stop for anyone
input int    ForcedFlowFadeBonus        = 2;      // Bonus for fading forced flow once it has stalled (see exhaustion below)
input double ForcedFlowMinIntensity     = 0.40;   // Intensity needed before the reading affects the decision
input bool   ForcedFlowPrintOnUse       = true;   // Log forced flow that changes a decision

// V153: confidence calibration. The score engine states a conviction on every entry and the lot
// sizing now acts on it - but nothing has ever checked whether the number means what it claims. If
// setups scoring 12 win no more often than setups scoring 8, then "12" is decoration and sizing up
// on it is sizing up on noise. Grouping closed baskets by their opening score answers that.
input bool   EnableScoreCalibration     = true;   // Track outcomes per score band to find out whether higher scores really are better trades
input int    ScoreCalibrationMinSamples = 12;     // Closed baskets in a band before its win rate is trusted
input int    ScoreCalibrationMaxSamples = 80;     // Sample ceiling per band; beyond it older evidence decays so the record reflects current behaviour
input bool   EnableCalibratedLotSizing  = true;   // Let a band's measured win rate adjust the lot, not just the raw score
input double CalibrationGoodWinRate     = 0.55;   // Win rate at or above which a band's conviction is considered earned
input double CalibrationPoorWinRate     = 0.42;   // Win rate at or below which the band's conviction is not supported by the record
input bool   ScoreCalibrationPrintOnUse = true;   // Log each recorded outcome
input bool   ShowCalibrationOnDash      = false;  // V170d: default OFF. ball kalibrlash statistikasi - haftada bir marta qarash yetarli. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V154: pattern memory. Every other module reasons from theory - this is a zone, so price should
// react. Sound, but still assumption. This asks what the market has ACTUALLY done the last times
// the chart looked like this: it takes the recent bars as a shape, normalises away price and
// volatility so only the form remains, finds the closest historical matches, and looks at what
// followed each one. The evidence carries no theory at all, which is exactly why it is worth having
// alongside modules that are made of theory.
input bool   EnablePatternMemory        = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES PatternMemoryTF   = PERIOD_M15;  // Timeframe the shapes are read on
input int    PatternMemoryShapeBars     = 20;     // Bars forming the shape
input int    PatternMemoryHorizonBars   = 10;     // Bars after a match used to judge what followed
input int    PatternMemoryHistoryBars   = 3000;   // How far back to search
input int    PatternMemoryKeepMatches   = 20;     // Closest matches kept as the sample
input int    PatternMemoryMinSamples    = 8;      // Matches needed before the reading is used
input double PatternMemoryMaxDistance   = 0.14;   // Maximum average per-point deviation to count as a match. Tighter = fewer but truer matches.
input double PatternMemoryMinOutcome    = 0.25;   // Move (in units of the match window's own range) needed to call an outcome directional
input double PatternMemoryMinBias       = 0.35;   // Bias strength needed before it affects the decision
input double PatternMemoryMinFit        = 0.45;   // Match quality needed before the reading is trusted
input int    PatternMemoryWithBonus     = 2;      // Bonus for entering with what history did
input int    PatternMemoryAgainstPenalty = 2;     // Penalty for entering against it
input bool   PatternMemoryPrintOnUse    = true;   // Log readings that change a decision
input bool   ShowPatternMemoryOnDash    = false;  // V170d: default OFF. tarixiy naqsh - qiziq, lekin qaror bergani jurnalда ko'rinadi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V155: warning reliability. The EA now issues a dozen cautions, each with a penalty chosen by hand,
// and nobody has checked which of them are right. If baskets opened despite "crowded path" lose 70%
// of the time, that warning is under-weighted; if "retail level" baskets win as often as any other,
// that penalty is costing trades for nothing. Recording which warnings were live at entry and
// crediting them when the basket closes lets the penalties re-weight themselves toward the cautions
// this market actually respects. This is the mechanism behind knowing WHY losses happen, remembering
// a pattern that has hurt before, and reviewing each basket afterwards - one question asked once.
input bool   EnableWarningLearning      = true;   // Let each warning's track record adjust its penalty
input int    WarningLearningMinSamples  = 10;     // Baskets carrying a warning before its record is trusted
input int    WarningLearningMaxSamples  = 60;     // Sample ceiling; beyond it older evidence decays
input double WarningNeutralAccuracy     = 0.50;   // Accuracy at which a warning keeps its configured penalty exactly
input double WarningWeightRange         = 0.60;   // How far a fully-right or fully-wrong record may move the penalty
input double WarningWeightMin           = 0.50;   // Floor - a warning that has been wrong still keeps half its weight
input double WarningWeightMax           = 1.80;   // Ceiling - a warning that has been right cannot dominate everything
input bool   WarningLearningPrintOnUse  = true;   // Log which warnings each closed basket credited
input bool   ShowWarningStatsOnDash     = false;  // V170d: default OFF. ogohlantirish ishonchliligi - uzoq muddatli statistika. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V156: regime. The EA runs identical settings whether price is trending, ranging or thrashing -
// the same $2.50 target and $7 grid spacing apply to a market moving $80 a day and one moving $15.
// MARKET_STATE exists but only ever blocks; it never changes HOW the EA trades. These four regimes
// are genuinely different problems: trends persist so targets can be wider, ranges stall at the
// edges so targets must be tighter, volatility needs room, and a quiet market may not reach a normal
// target at all. Switching is deliberately slow - flipping settings mid-basket would be worse than
// using the wrong ones consistently.
input bool   EnableRegimeSwitching      = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES RegimeTF          = PERIOD_M15;  // Timeframe the regime is read on
input int    RegimeLookbackBars         = 30;     // Bars used to judge how much ground price actually covered
input int    RegimeADXPeriod            = 14;     // ADX period for the trend test
input double RegimeTrendADX             = 24.0;   // ADX at or above which a trend is present
input double RegimeTrendEfficiency      = 0.45;   // Net move as a share of the range - a trend covers ground rather than revisiting it
input double RegimeRangeEfficiency      = 0.25;   // Below this, price is revisiting the same prices - a range
input double RegimeVolatileRatio        = 1.60;   // ATR this many times its own longer-term norm = volatile
input double RegimeQuietRatio           = 0.65;   // ATR this far below its norm = quiet
input int    RegimeConfirmBars          = 4;      // Bars a new regime must hold before the switch is made
input double RegimeTrendTPFactor        = 1.25;   // Target multiplier while trending - moves persist
input double RegimeRangeTPFactor        = 0.80;   // While ranging - take less, the edges stall
input double RegimeVolatileTPFactor     = 1.15;   // Wider swings, wider target
input double RegimeQuietTPFactor        = 0.75;   // A normal target may simply not be reached
input double RegimeTrendGridFactor      = 1.20;   // Grid spacing while trending - adverse runs go further
input double RegimeRangeGridFactor      = 0.90;   // Reversion comes sooner in a range
input double RegimeVolatileGridFactor   = 1.35;   // Volatility needs real room between additions
input double RegimeQuietGridFactor      = 0.85;
input int    RegimeVolatileScoreOffset  = 2;      // Extra score demanded before committing in volatility
input int    RegimeQuietScoreOffset     = 1;      // And in a market that may not travel far enough
input bool   RegimePrintOnUse           = true;   // Log regime switches
input bool   ShowRegimeOnDash           = true;   // Show the current regime on the dashboard

// V157: two blind spots. Every hard block is an untested hypothesis - a refusal that would have lost
// saved money, one that would have won cost money, and both look identical from inside the EA
// because the trade never existed. And now that the regime has a name, a question becomes askable
// that was not before: is there a market state where this system simply does not work? Neither
// changes behaviour by itself; they produce the evidence a later decision can rest on.
input bool   EnableBlockAudit           = true;   // Record refused entries and check where price went, to find out whether the blocks are right
input int    BlockAuditHorizonBars      = 15;     // Bars after a refusal before it is judged
input int    BlockAuditDecisivePoints   = 1500;   // Move needed to call the refusal right or wrong ($1.50). Smaller moves are inconclusive and discarded.
input int    BlockAuditDedupeBars       = 5;      // The same direction refused again within this many bars is one decision, not several
input int    BlockAuditMaxSamples       = 100;    // Sample ceiling; beyond it older verdicts decay
input bool   BlockAuditPrintOnUse       = true;   // Log each verdict
input bool   EnableRegimePerformance    = true;   // Track closed-basket outcomes per regime
input int    RegimePerfMinSamples       = 10;     // Baskets in a regime before its win rate is meaningful
input int    RegimePerfMaxSamples       = 60;     // Sample ceiling per regime
input bool   ShowBlockAuditOnDash       = false;  // V170d: default OFF. blok auditi - uzoq muddatli statistika. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V159: basket projection. Every risk check in this EA looks at the position as it exists NOW -
// current drawdown, current margin, current exposure. But a martingale entry is not a 0.25 lot
// position, it is a commitment to a whole ladder, and the only moment that commitment can be
// declined is before the first order exists. Walking the ladder forward answers what the entry
// actually commits to: how many orders, what total volume, what drawdown, and whether the margin
// survives it. A basket that runs out of margin at order five was never survivable - and that was
// knowable in advance.
input bool   EnableBasketProjection     = true;   // Walk the full grid ladder forward before entering
input bool   ProjectionCheckLevels      = true;   // Also check whether a level sits inside the span the ladder would need
input double ProjectionCautionSeverity  = 0.75;   // Severity (worst of projected DD vs SL, and projected margin vs limit) at which the entry is penalised
input double ProjectionBlockSeverity    = 1.00;   // Severity at which the entry is refused outright - the ladder would not survive its own completion
input double ProjectionMinLotFactor     = 0.45;   // V159b: smallest size the entry may be scaled to in order to fit the ladder inside the account. Below this the trade is too small to be worth its costs.
input bool   ProjectionHardBlock        = false;  // V171: true -> false while the size scaling proves itself. The projection already shrinks the entry to fit the account, which handles the problem it was written for; the refusal on top of that was a second answer to a question already answered, and it fires on the same ladder maths that has never run live. The scaling stays active - only the outright refusal is off.
input bool   ProjectionPrintOnUse       = true;   // Log projections that change a decision
input bool   ShowProjectionOnDash       = false;  // V170d: default OFF. narvon proyeksiyasi - entry paytida jurnalда yoziladi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V160: basket health. Drawdown, order count, margin, age and structure are each tracked with their
// own threshold, which works while only one is deteriorating. It fails when several are mildly bad
// at once - four orders used, 30% drawdown, eight hours old, structure turned - none tripping its
// own limit while the basket is clearly in trouble. One figure makes that visible and actionable:
// a healthy basket holds out for its full target, a deteriorating one takes the first reasonable
// exit. The most expensive mistake in recovery trading is waiting for the original target long
// after the position stopped being able to reach it.
input bool   EnableBasketHealth         = true;   // Combine drawdown, orders, margin, age and structure into one health figure
input double BasketHealthWeightDD       = 2.0;    // Weight of drawdown - the most direct measure
input double BasketHealthWeightOrders   = 1.5;    // Weight of how much of the grid ladder is already spent
input double BasketHealthWeightMargin   = 1.5;    // Weight of margin consumption
input double BasketHealthWeightAge      = 1.2;    // Weight of age - a basket that cannot close is a basket the market left behind
input double BasketHealthWeightStructure = 1.0;   // Weight of the structure that justified the basket having broken
input int    BasketHealthAgeBars        = 480;    // Bars (core TF) at which age counts as fully spent - 480 M1 bars = 8 hours
input double BasketHealthGood           = 0.65;   // At or above this the basket is healthy and keeps its full target
input double BasketHealthPoor           = 0.25;   // At or below this it takes the minimum target it can
input double BasketHealthMinTPFactor    = 0.55;   // Smallest target multiplier a struggling basket will accept
input bool   ShowBasketHealthOnDash     = true;   // Show the health figure while a basket is open
input bool   EnableAdaptiveBasketAge    = true;   // V160b: learn what a normal basket lifetime is here instead of using a fixed figure. A scalper closing in twenty minutes and a slower setup need completely different answers, and only the record knows which this is.
input double AdaptiveBasketAgeAlpha     = 0.15;   // How quickly the learned lifetime adapts (slow, so one unusual basket does not move it far)
input double AdaptiveBasketAgeMultiple  = 3.0;    // A basket counts as fully stale at this multiple of the typical winning lifetime
input int    AdaptiveBasketAgeMinBars   = 60;     // Floor on the learned figure (1 hour) - below this normal variation would look like staleness
input int    AdaptiveBasketAgeMaxBars   = 2880;   // Ceiling (2 days) - beyond this age has clearly stopped being informative
input bool   AdaptiveBasketAgePrintOnUse = true;  // Log the learned lifetime as it updates

// V161: scale-in. The grid answers a wrong entry by adding size to it - which works when price comes
// back and is ruinous when it does not, and the EA cannot tell which case it is in at the moment it
// decides. Scale-in inverts that: enter at part size, and complete only after price has moved in
// favour, which is the market agreeing rather than the EA insisting. The trade-off is honest - a
// setup that was immediately right earns less, because part of it was added at a worse price. What
// it buys is that every setup which was simply wrong costs a fraction of what it used to.
input bool   EnableScaleIn              = true;   // Take the first entry at part size and complete it only on confirmation
input double ScaleInFirstFraction       = 0.85;   // V175: 0.80 -> 0.85. The floor above now guarantees the lot itself, so this split applies to a full-size entry: 0.25 enters at 0.21 with 0.04 held for confirmation. Raised slightly because a 15% holdback is enough to matter on a wrong entry without meaningfully reducing a right one.
input int    ScaleInConfirmPoints       = 800;    // Move in favour that counts as the market agreeing ($0.80)
input int    ScaleInAbandonPoints       = 1200;   // Move against at which the remainder is dropped and the grid takes over ($1.20)
input int    ScaleInMaxWaitBars         = 30;     // Bars to wait for confirmation before dropping the remainder - a setup going nowhere is not worth completing
input bool   ScaleInPrintOnUse          = true;   // Log scale-in entries, completions and abandonments

// V161b: a fixed 60% / $0.80 / $1.20 throws away information the EA already has. How much to commit
// immediately is a statement about how much this particular setup is trusted, and what counts as
// "price agreed" depends on what the market is currently doing - $0.80 is a real move in a quiet
// session and noise in a fast one. Most importantly, reaching a distance is not the same as being
// confirmed: price can drift there on thin overlapping bars, which is the market wandering rather
// than agreeing.
input bool   EnableAdaptiveScaleIn      = true;   // Size the first part by conviction and scale the distances to current volatility
input double ScaleInMinFraction         = 0.80;   // V161c: 0.40 -> 0.80. Even the weakest qualifying setup enters at 80%. A setup that passed thirteen hard blocks and thirty penalties is a real opportunity - halving it distrusts the EA's own filters. The held-back portion is a hedge against being wrong, not a statement that the setup is doubtful.
input double ScaleInMaxFraction         = 0.95;   // V161c: 0.80 -> 0.95. A setup clearing every bar comfortably takes almost all of its size straight away - at that point waiting for confirmation costs more in worse fills than it saves.
input double ScaleInVolatileFactor      = 0.92;   // V161c: 0.75 -> 0.92. Volatility still justifies holding a little more back, but the reduction is now gentle - at the old value it would have pulled an 80% entry down to 60%, undoing the floor above.
input double ScaleInConfirmATR          = 0.80;   // Confirmation distance in ATR - replaces the fixed points figure when adaptive
input double ScaleInAbandonATR          = 1.20;   // Abandonment distance in ATR
input bool   EnableScaleInQuality       = true;   // Require the confirming move to have conviction, and refuse to complete into a wall
input bool   ScaleInRequireConviction   = true;   // Drifting to the confirmation distance does not count as confirmation
input double ScaleInMinRoomFactor       = 1.00;   // Room beyond the confirmation point needed before completing, as a multiple of the confirmation distance
input double ScaleInWallMinStrength     = 1.8;    // Only a genuine level blocks a completion

// V162: noise. There are stretches where the market is busy and pointless - bars print, indicators
// produce readings, and forty bars later price is where it started. The signals are not wrong during
// those stretches, they are describing noise, and a signal describing noise is not weak but
// meaningless. A setup can clear every filter and score 12 in conditions where a $2.50 target was
// never reachable. The measure is displacement against distance travelled: price moving $8 to end up
// $6 away is trending, price moving $8 to end up $0.50 away is churning. Deliberately separate from
// volatility - the regime detector reads SIZE, this reads PURPOSE.
input bool   EnableNoiseFilter          = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES NoiseTF           = PERIOD_M5;   // Timeframe the noise is measured on
input int    NoiseLookbackBars          = 40;     // Bars covering the measurement
input int    NoiseReachHorizonBars      = 40;     // Bars a basket normally has to reach its target - used to judge reachability
input double NoiseCautionLevel          = 0.82;   // Noise above which the entry is penalised
input double NoiseBlockLevel            = 0.90;   // Noise above which entries are refused - at this level price is not travelling anywhere
input double NoiseMinReachability       = 0.55;   // Expected travel as a fraction of the target; below this the target is not realistically reachable
input int    NoiseCautionPenalty        = 2;      // Penalty for entering into churn
input double NoiseMinTPFactor           = 0.50;   // V162b: floor on how far the target may be scaled down in churn. Below this the trade is not worth its spread.
input bool   NoisePrintOnUse            = true;   // Log noise readings that change a decision
input bool   ShowNoiseOnDash            = true;   // Show the noise reading on the dashboard

// V163: pressure. Every directional reading here is derived from RESULT - price closed higher,
// structure made a higher high. All true, all backward-looking. But each bar is a contest and the
// bar itself records who won it: a bar opening at its low and closing at its high was taken by
// buyers outright; one that spiked down and closed near its high was attempted by sellers and taken
// back. The useful case is when control and price DISAGREE - price still falling while each bar is
// defended harder is sellers running out of conviction while still nominally in charge, and that
// shows up before any close-based indicator can see it.
input bool   EnablePressureReading      = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES PressureTF        = PERIOD_M5;   // Timeframe the bar contest is read on
input int    PressureLookbackBars       = 12;     // Bars examined
input int    PressureMinBars            = 6;      // Minimum readable bars before the reading is used
input double PressureBodyWeight         = 0.55;   // How much a bar counts regardless of body size (the rest scales with body share - a close at the high on a tiny body was not really won)
input double PressureRecencyWeight      = 0.15;   // Extra weight per bar toward the present - control changes hands
input double PressureMinTrend           = 0.20;   // Shift in control needed before it is treated as meaningful
input double PressureMinPriceMove       = 1500.0; // V170f: 800 -> 1500 ($1.50). Over twelve M5 bars price routinely travels $0.80 without meaning anything, so divergence was being declared on ordinary drift. Divergence is only interesting when price has genuinely gone one way while control went the other.
input int    PressureWithBonus          = 2;      // Bonus for entering with the side that holds control
input int    PressureAgainstPenalty     = 2;      // Penalty for entering against it
input int    PressureDivergenceBonus    = 3;      // Bonus for entering with control while price still disagrees - the early reading
input double PressureMinToAct           = 0.25;   // Pressure strength needed before it affects the decision
input bool   PressurePrintOnUse         = true;   // Log pressure readings that change a decision
input bool   ShowPressureOnDash         = true;   // Show the pressure reading on the dashboard

// V164: session context. The EA measures time in bars and treats them as equivalent, but the market
// runs on a schedule: Asia drifts in thin ranges, London expands them, the New York overlap carries
// the real volume, and rollover is a dead zone of widened spreads. Two things follow that bars
// cannot express - WHICH session it is changes what a setup means (a breakout at 03:00 has nobody
// behind it), and PROXIMITY to a session change matters more than anything happening now, because
// fifteen minutes before London the current move is about to be overwritten by participants who are
// not in the market yet.
// NOTE: all hours are BROKER server time. Defaults below are set for a UTC+0 server, which is what
// this account uses. On a UTC+2/+3 server every hour would need shifting by that offset - the values
// are not universal. Daylight saving moves London and New York by an hour twice a year; the defaults
// follow winter time, which is close enough that only the session edges are affected.
input bool   EnableSessionContext       = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int    SessionAsiaStartHour       = 0;      // 00:00 UTC - Tokyo session opens
input int    SessionLondonStartHour     = 8;      // 08:00 UTC - London opens (07:00 UTC during British Summer Time; set to 7 from late March to late October if you want it exact)
input int    SessionNYStartHour         = 13;     // 13:00 UTC - New York opens, and the London/NY overlap begins. This is the highest-volume window of the day for XAUUSD.
input int    SessionLondonEndHour       = 16;     // 16:00 UTC - London closes, ending the overlap
input int    SessionNYEndHour           = 21;     // 21:00 UTC - New York winds down
input int    SessionRolloverHour        = 22;     // 22:00 UTC - the standard forex rollover (17:00 New York). Spreads widen sharply here and liquidity thins to almost nothing.
input int    SessionRolloverMinutes     = 40;     // Width of the rollover window, centred on the hour above
input double SessionAsiaTPFactor        = 0.75;   // Asia delivers less ground - a full-size target often is not reached
input double SessionLondonTPFactor      = 1.10;   // London expands ranges
input double SessionOverlapTPFactor     = 1.20;   // The overlap carries the day's real movement
input double SessionNYTPFactor          = 1.00;   // New York after London closes
input double SessionDeadTPFactor        = 0.65;   // Rollover moves on no participation - take what is there
input int    SessionChangeWarnMinutes   = 20;     // Minutes before a session change at which current readings stop being reliable
input int    SessionChangePenalty       = 2;      // Penalty for entering right before the market changes hands
input int    SessionDeadPenalty         = 3;      // Penalty for entering during rollover
input bool   SessionPrintOnUse          = false;  // Log session effects on decisions
input bool   ShowSessionOnDash          = true;   // Show the session and what is coming on the dashboard

// V165: spread economics. The EA checks spread against a maximum and moves on - which answers "is
// the spread acceptable" but never "is this trade worth its cost". A $2.50 target at $0.35 spread
// gives away 14% before price does anything; at $1.00, which happens at rollover, the trade must
// travel 40% further than its target implies just to break even. The setup has not changed - the
// arithmetic has. And since widening is scheduled rather than random, it can be anticipated.
input bool   EnableSpreadEconomics      = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   SpreadCountRoundTrip       = true;   // Count the exit's share of the spread too - most fills give up half of it again
input double SpreadCostCaution          = 0.26;   // V170e: 0.18 -> 0.26. Calibrated against this account\'s actual spread. At $0.35 spread and a $2.50 target the round-trip cost is 21%, so at 0.18 EVERY normal trade was collecting this penalty - a penalty that fires on all conditions is not a filter, it is a constant. 0.26 leaves normal conditions alone and catches the genuinely expensive ones.
input double SpreadCostRefuse           = 0.45;   // V170e: 0.32 -> 0.45. At 0.32 the refusal fired whenever the target was reduced - an Asian, churning session computes a $1.50 target, and $0.35 spread against it is 35%, blocking trades that were merely unremarkable rather than unprofitable. 0.45 refuses only when the spread genuinely eats the trade, which in practice means rollover and news.
input int    SpreadCostPenalty          = 4;      // Penalty at the caution level
input bool   SpreadCostHardBlock        = false;  // V186: hard blok -> jazo. spread qimmat - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // Refuse trades above the refusal ratio. Unlike most blocks here this is not a judgement - the trade cannot pay for itself.
input bool   EnableSpreadForecast       = true;   // Anticipate widening instead of only reacting to it
input int    SpreadForecastWarnMinutes  = 25;     // Minutes before rollover at which a new scalp is priced under conditions its exit will not enjoy
input int    SpreadForecastThinSessionPoints = 450; // Spread in a thin session above which further widening is likely
input int    SpreadForecastPenalty      = 2;      // Penalty for entering into expected widening
input bool   SpreadPrintOnUse           = true;   // Log spread economics that change a decision
input bool   ShowSpreadCostOnDash       = true;   // Show the cost ratio on the dashboard

// V166: three gaps sharing one source - the EA looks at each basket in isolation, never at what came
// before it or what it has already paid.
// CARRY: a basket that stays open pays swap daily. The profit figure includes it, the TARGET does
// not - so a $2.50 target on a basket that has paid $3 in swap closes for a loss while reporting a
// win. STREAKS: one loss is variance, three consecutive is information. REPETITION: if the last two
// baskets both lost at the same level, the third one there is the same mistake with a new timestamp.
input bool   EnableCarryCostAdjust      = true;   // Raise the target by what the basket has already paid in swap
input double CarryCostMinProfitPoints   = 300;    // Profit that must remain after covering carry ($0.30) - a break-even exit is not a take-profit
input bool   EnableStreakAwareness      = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int    StreakCautionLosses        = 3;      // Consecutive losses before caution begins
input int    StreakPenaltyPerLoss       = 2;      // Penalty added per loss beyond that
input int    StreakMaxPenalty           = 6;      // Ceiling - a streak is a hint that conditions changed, not a verdict
input bool   StreakPrintOnUse           = true;   // Log streak warnings
input bool   EnableRepeatMistakeGuard   = true;   // Notice when recent baskets already lost around this price
input int    RepeatMistakePoints        = 2500;   // How close counts as "the same place" ($2.50)
input int    RepeatMistakeMinHits       = 2;      // Recent losing baskets near this price before it counts as repetition
input int    RepeatMistakePenalty       = 5;  // V173: 3 -> 5. shu darajada allaqachon ikki marta yutqazilgan. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for opening where the last attempts already failed
input bool   ShowStreakOnDash           = true;   // Show streak and repetition state on the dashboard
input bool   ShowEntryFunnelOnDash       = true;   // V192: show how many setups were found and where they were lost. Two trades in twelve hours on a scalper is a measurable problem, and this line says which layer is responsible instead of leaving it to be guessed.

// V194: setup arming. The EA had two answers to a warning - refuse, or take it smaller. A setup
// arriving into a strong opposing zone is neither bad nor small: it is EARLY. Arming holds the
// direction and waits for the market to answer that specific objection - price reaching the zone
// and being rejected there, a pullback completing, a level being reclaimed. Confirmed, the trade is
// taken at FULL size, because the objection was answered rather than tolerated. Unconfirmed within
// the window, it is dropped - a setup that never got its confirmation was never the trade it looked
// like. This is the difference between refusing and waiting.
input bool   EnableSetupArming           = true;   // Hold early setups and wait for confirmation instead of refusing or shrinking them
input int    SetupArmMinWaitBars         = 1;      // Bars before a confirmation counts - confirming on the same bar the objection appeared is noise
input int    SetupArmMaxWaitBars         = 10;     // V198: 25 -> 10. Fallback window for anything not covered above.
input double SetupArmRejectionWickRatio  = 0.35;   // Wick against the zone, as a share of the bar's range, that counts as the level rejecting price
input bool   EnableCounterTrendNeedsReason = true;   // FIX(counter-trend-needs-a-reason): refuse a first entry that fights a CONFIRMED global trend with no reversal consensus AND no level behind it to lean on. Everything else about the counter-trend path is unchanged - this only removes the naked case.
input int    CounterTrendSupportMaxDistance = 3500;   // How far behind ($3.50) a level can sit and still count as something this trade leans on. Mirrors CounterZoneBlockPoints, which asks the same question about what is in FRONT.
input double CounterTrendSupportMinStrength = 1.4;    // Strength a single level behind must carry to justify a counter-trend entry on its own. Same bar as CounterZoneBlockMinStrength - a shelf can qualify instead, via the cluster test.
input int    CounterTrendExceptionalMinScore = 8;      // V249fix(auto-mode): the ABSOLUTE quality floor for the tier-C release, applied alongside the relative margin below. Needed because AUTO switches the bar itself: MinScoreHighHunter is 2 and MinScoreBalanced is 4, and Hunter additionally collects a +1 mode bonus - so a purely relative margin released the counter-trend guard at a MUCH lower absolute score in Hunter, i.e. the MORE aggressive mode got the WEAKER protection. With a floor of 8 both modes demand the same real quality; the relative term still applies if you raise a MinScore well above it.
input int    CounterTrendExceptionalMargin  = 3;      // V249fix: 6 -> 3. At 6 this release was DEAD: G_SCORE_MIN_REQUIRED is typically 5 (MinScoreBalanced 4 + the reversal-type extra), so it demanded a final of 11 - and in exactly the conditions this tier fires, the trend-conflict penalties have already driven the total to the 12 cap, so final tracks base and a typical live reading is 9. At 3 the bar is 8 and a genuinely strong setup gets through, which is the whole point. Release valve: a counter-trend setup with nothing behind it is STILL allowed if its final score clears the required bar by this much AFTER the HTF penalty. V189 refused a live A+ setup scoring 11 against a bar of 4 and that was wrong - this is what stops that happening again. Lower = stricter.
input int    CounterTrendMaxLadderOrders    = 3;      // Ladder depth cap for an entry against a confirmed global trend. Being wrong on this bet means the grid is averaging INTO a running trend - the single most dangerous state for a martingale, per the EA's own note. Refuses no trades; it only limits how much a wrong one can cost. 0 = no cap.
input bool   CounterTrendPrintOnUse        = true;    // Log every counter-trend decision (tier B allowed / tier C refused) - this is the data you need to tune the two thresholds above from a real session rather than a guess.
input bool   EnableCounterZoneCluster   = true;   // FIX(counter-zone-single-level): treat a SHELF of several ordinary opposing levels as a wall, not only a single strong one. This is the guard against "sell at support / buy at resistance" when the nearest level alone looks weak.
input int    CounterZoneClusterMinLevels = 3;      // How many DISTINCT opposing levels inside CounterZoneBlockPoints make a shelf. Levels closer together than ZoneNextLevelGapPoints count once.
input double CounterZoneClusterMinLevelStrength = 1.25;  // Minimum strength for a level to COUNT as a shelf member. Below the single-wall floor (CounterZoneBlockMinStrength 1.4) - the point of the shelf test is that no single member has to clear that - but above the 1.0 untested baseline, so a row of raw wicks is not a wall. Without this floor the test degenerates into "are there 3 swing points within $3.50", which is true almost always, in both directions at once.
input double CounterZoneClusterMinSum   = 0.9;     // Total confirmation the shelf must carry, summed as (strength - 1.0) per level - so a row of untested single wicks sums to zero and cannot block. 0.9 ~= three levels each with roughly one confirming retouch.
input int    CounterZoneReArmCooldownBars = 20;    // FIX(counter-zone-rearm-loop): after a counter-zone wait expires unanswered, do not start another one for this many bars. Stops the arm engine holding a setup forever against a wall price never clears; during the cooldown the block falls through to CounterZoneHardBlock / the score penalty, which is the documented design.
input int    SetupArmWallClearPoints    = 200;    // FIX(arm-wall-geometry): how far past the opposing wall ($0.20) price must CLOSE before a counter-zone objection counts as answered. A wall is cleared, not bounced off - see the ARM_REASON_ZONE confirm branch.
input int    SetupArmPullbackPoints      = 600;    // Pullback depth ($0.60) that answers an overextended move
input int    SetupArmScoreBonus          = 3;      // Bonus when a confirmation arrives - the objection was answered, which is worth more than it never having been raised
input bool   SetupArmPrintOnUse          = true;   // Log arming, confirmation and expiry
input bool   ShowSetupArmOnDash          = true;   // Show the armed setup and what it is waiting for
input bool   EnableZoneEdgeArming        = true;   // V195: wait for the zone's reaction edge instead of penalising an early fill. The edge is a price - patience reaches it, a penalty only records that it was missed.
input bool   EnableLiquidityArming       = true;   // V195: wait for a stop pool to be taken rather than entering into it. The move after a sweep is cleaner than the one that walks into it.

// V196: independent confirmation for the wait. Waiting on price alone is one opinion and a late
// one - price reaching a level says the market got there, not that it turned. Pressure, chain and
// pattern memory read intent directly and see a turn beginning before it prints. Two agreeing ends
// the wait on its own; all three disagreeing ends it the other way, since a setup the market has
// moved away from will not be rescued by waiting out the window.
input bool   EnableArmConsensus          = true;   // Let pressure, chain and history confirm or cancel a wait, alongside the price test
input bool   EnableSpreadArming          = true;   // V196: wait for a wide spread to narrow rather than paying a penalty for it. Spreads always narrow - this is the objection most certain to resolve itself.

// V197: waits are now checked while they run and measured after they finish.
// Each objection resolves on its own timescale, so one window for all of them was either too short
// for pullbacks or too generous for spreads.
input int    SetupArmZoneWaitBars        = 8;      // V198: 20 -> 8. On M1 that was twenty minutes of holding, on an EA whose trades resolve in ten to twenty. A wait that outlasts the trade it is waiting for is not patience - it is the EA sitting out the session. If the zone has not rejected price within eight bars, it is not defending that level today.
input int    SetupArmPullbackWaitBars    = 15;     // V198: 35 -> 15. Still the longest of the three, because a pullback genuinely takes longer to form - but thirty-five minutes on a scalper meant one held setup could cost an entire session of other opportunities.
input int    SetupArmStructureWaitBars   = 5;      // V198: 12 -> 5. Spreads narrow within a few bars or they are not narrowing; a reclaim either happens on the next candles or the level held. Neither needs twelve minutes to answer.
input int    SetupArmFillWaitBars        = 3;      // V275: bars held for a better price. Short by design - the objection is a few points, not a condition that has to resolve, and a setup held too long for a better entry becomes a setup missed for one.
input int    SetupArmLateWaitBars        = 10;     // V288: bars held for a pullback. Longer than a fill hold - a retrace takes time to arrive, and the setup behind it is structural rather than momentary.
input bool   EnableArmValidityCheck      = true;   // Check the setup is still there while waiting. Waiting was never the goal - it was a way to get the same trade at a better moment, and that trade can disappear mid-wait.
input int    ArmAbandonDistancePoints    = 4000;   // Distance from the level ($4.00) at which the wait is abandoned - price has left the area, so the reaction cannot happen there
input bool   ArmAbandonOnSessionChange   = true;   // Abandon when the session hands over. The participants who would have produced the expected reaction are no longer the ones trading.
input bool   EnableArmAudit              = true;   // Measure whether waiting works. Without this the next round of tuning is guesswork - which is what produced a day of blind adjustments.
input int    ArmAuditHorizonBars         = 20;     // Bars after a confirmed entry before judging what the wait produced
input int    ArmAuditWinPoints           = 800;    // Move in favour ($0.80) that counts the wait as having paid off
input bool   ArmAuditPrintOnUse          = true;   // Log each verdict
input bool   ShowArmAuditOnDash          = true;   // Show the wait statistics on the dashboard

// V199: after a winning basket the same direction enters without waiting. Taking profit IS the
// confirmation - the EA read the direction correctly and the market paid for it - and demanding a
// fresh one minutes later turns the EA's own success into a reason for hesitation. Worse, the move
// that produced the profit is usually still running, which trips the overextension check and holds
// the EA out of the very continuation it just proved.
input bool   EnablePostWinFastEntry      = true;   // Skip the wait for the direction of a recently profitable basket
input int    PostWinFastEntryBars        = 20;     // Bars after a winning close during which that direction still counts as confirmed
input int    ArmConsensusMinAgree        = 2;      // Sources that must agree for the wait to complete on their own
input int    ArmConsensusMinAgainst      = 3;      // Sources pointing the other way before the setup is dropped early - unanimous, because cancelling a valid wait is the more expensive mistake

// V167: zone edges. Everything here treats a zone as one price; on a chart it is a region, and where
// inside it price reacts is not arbitrary. The OUTER edge is the extreme - where stops sit and where
// a sweep wicks to. The INNER edge is where the orders rest - the price the zone has actually been
// defended from. Price routinely trades through the outer edge and turns at the inner one, and on
// XAUUSD that gap is often a dollar: on a $2.50 target, the difference between a scalp that works
// and one that opens straight into drawdown. The two answer different questions - risk measures to
// the outer edge because price can reach it, entries aim at the inner edge because that is where the
// turn happens.
input bool   EnableZoneEdges            = true;   // Resolve a zone into its reaction edge and its reach edge instead of one price
input ENUM_TIMEFRAMES ZoneEdgeTF        = PERIOD_M15;  // Timeframe the zone's member swings are read on
input int    ZoneEdgeGatherPoints       = 1800;   // How far around the level to gather swings belonging to the same zone ($1.80, adjusted by market scale)
input int    ZoneEdgeMinSwings          = 3;      // Swings needed before a zone has a meaningful shape rather than a single point
input int    ZoneEdgeMinGapPoints       = 400;    // Gap between the edges below which the distinction does not matter ($0.40)
input int    ZoneEdgeEarlyEntryPenalty  = 4;  // V173: 2 -> 4. reaksiya nuqtasiga yetmagan - darrov DD. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering at the reach edge when the reaction edge is still ahead - the fill is early and drawdown is immediate
input bool   ZoneEdgePrintOnUse         = true;   // Log edge resolution that changes a decision
input bool   ShowZoneEdgesOnDash        = false;  // V170d: default OFF. zona chekkalari - jurnalда batafsilroq. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V169: four small gaps. None changes how a trade is chosen; all answer questions the EA currently
// cannot. EXIT QUALITY - it knows whether it hit its target, not what happened next; if price keeps
// running after almost every exit the target is too small. SLIPPAGE - a persistent $0.10 on a $2.50
// target is 4% of every trade, paid twice, and unmeasured it just looks like underperformance.
// DAILY STATE - most systems give back the day's gains in the last hour. RENTAL SPREAD - fifty
// copies firing on the same signal in the same second compete for the same liquidity.
input bool   EnableExitQuality          = true;   // Watch where price goes after a basket closes, to find out whether the target is the right size
input int    ExitQualityHorizonBars     = 20;     // Bars watched after the close
input int    ExitQualityRunOnPoints     = 800;    // Move after the exit that counts as decisive either way ($0.80)
input double ExitQualityTargetTooSmall  = 0.65;   // Share of exits followed by more movement above which the target is probably too small
input int    ExitQualityMaxSamples      = 60;     // Sample ceiling
input bool   ExitQualityPrintOnUse      = true;   // Log each post-exit verdict
input bool   EnableSlippageTracking     = true;   // Measure the gap between the price asked for and the price received
input int    SlippageMaxSamples         = 100;    // Sample ceiling
input bool   EnableDailyState           = true;   // Be harder to convince once the day is already good, and after a bad one
input double DailyGoodDayPercent        = 2.0;    // Daily gain above which protecting the day matters more than adding to it
input int    DailyGoodDayScoreOffset    = 2;      // Extra score demanded on a good day
input double DailyBadDayPercent         = 2.5;    // Daily loss below which the EA stops trying to trade its way back
input int    DailyBadDayScoreOffset     = 3;      // Extra score demanded after a bad day
input bool   EnableRentalSpread         = true;   // Stagger entries across rented copies so they do not compete for the same fill
input int    RentalSpreadMaxTicks       = 2;      // V187: 4 -> 2. Ijara nusxalarini ajratish uchun yetarli, lekin har entryga qo\'shiladigan kechikishni yarmiga qisqartiradi.
input bool   ShowDiagnosticsOnDash      = false;  // V170d: default OFF. chiqish sifati va slippage - haftalik ko'rib chiqish uchun. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V170: the conditional target adjustments (session, regime, noise, health) are combined into one
// factor before any limit is applied. Applied one at a time they were wrong in both directions:
// downward each step clamped at the minimum, so the first factor to reach the floor silenced every
// one after it; upward there was no clamp at all, so an overlap trending market produced a $3.75
// target on a scalper configured for $2.50. These bounds keep the combined result inside what this
// strategy can actually work with.
input double TPFactorMin                = 0.60;   // Smallest the combined target adjustment may be. Below this the trade stops clearing its own spread.
input double TPFactorMax                = 1.35;   // Largest. A scalper that starts holding for $4 is no longer the strategy that was tested.
input bool   TPAdjustPrintOnUse         = true;   // Log meaningful target adjustments
input double EntryLotFactorMin          = 0.80;   // V175: 0.65 -> 0.80 on request. The floor under the COMBINED entry adjustment. Below 80% the grid progression behind it stops matching the settings - every rung multiplies from the first, so a 65% first entry makes the whole recovery ladder 35% weaker than the numbers say.
input double EntryLotAbsoluteFloor      = 0.80;   // V175: the entry lot never falls below this fraction of StartLot, whatever the adjustments decide. Applied LAST, after conviction scaling, ladder-fit scaling and the scale-in split - each is bounded on its own, but they multiply, and 0.80 x 0.80 is 0.64. This is the figure that holds.

// V182: the modules shape the SIZE of a trade rather than veto it. Twenty analytical modules were
// each given the power to refuse an entry, and together they cut a high-frequency scalper down to a
// couple of trades a day - the reasoning was sound but the mechanism was wrong. A warning is not a
// reason to stand aside; it is a reason to commit less and ask for less. The setup still trades.
input bool   EnableWarningLotScaling    = true;   // Let accumulated warnings reduce the entry size instead of refusing the entry
input int    WarningLotFullPenalty      = 14;     // Warning weight at which sizing reaches its floor. Below this it scales proportionally - four points of caution trims a little, twelve trims to the floor.
input double WarningLotMinFactor        = 0.55;   // Smallest size a heavily-warned setup will take, as a fraction of the intended lot
input bool   EnableWarningTPScaling     = true;   // Let the same weight shorten the target
input double WarningTPMinFactor         = 0.70;   // Smallest target multiplier from warnings - a doubtful trade should be asked for less, not sent out for the same move with less behind it
input double ZoneStrengthTPBufferScale      = 0.6;     // How much zone strength widens the TP-cap buffer (0=no effect)
input double ZoneStrengthLotTrimScale       = 0.5;     // How much zone strength deepens the momentum-caution lot cut

input group "61 — LIQUIDITY VACUUM (FAIR VALUE GAP)"
input bool             EnableFVGZones        = true;    // Unfilled 3-candle price gaps act as extra magnet zones
input ENUM_TIMEFRAMES  FVGTimeframe          = PERIOD_M15;
input int              FVGLookbackBars       = 100;
input int              FVGMinGapPoints       = 150;     // Ignore gaps smaller than this - not significant
input bool             FVGPrintOnUse         = false;

input group "62 — ORDER FLOW (TICK VOLUME)"
input bool   EnableOrderFlow           = true;    // MT5 has no real order flow, this is a tick-volume-based proxy
input int    OrderFlowLookbackBars     = 20;      // Bars used to compute the average volume baseline
input double OrderFlowHighMultiplier   = 1.3;     // Volume >= avg*this counts as a confirmed/strong move
input double OrderFlowLowMultiplier    = 0.7;     // Volume <= avg*this counts as a weak/suspicious move
input int    OrderFlowWeakBOSPenalty   = 1;       // Extra penalty on a fresh BOS break with weak (low-volume) conviction
input int    OrderFlowStrongBOSBonus   = 1;       // Extra bonus on a fresh BOS break with strong (high-volume) conviction

input group "63 — DXY PROXY (SYNTHETIC DOLLAR INDEX)"
input bool             EnableDXYProxy            = true;   // No real DXY on most Cent accounts - built from 3 major pairs instead
input string           DXYProxyPair1             = "EURUSD";
input string           DXYProxyPair2             = "GBPUSD";
input string           DXYProxyPair3             = "USDJPY";
input ENUM_TIMEFRAMES  DXYProxyTF                = PERIOD_H1;
input int              DXYProxyLookbackBars      = 20;     // Bars back used to measure the proxy's slope
input double           DXYProxyMinSlopePercent   = 0.15;   // Minimum % change over the lookback to call it a clear direction
input bool             DXYProxyInverseRelationship = true; // true = USD-quote symbols like XAUUSD/EURUSD (higher DXY -> lower price)
input double           DXYProxyLotFactor         = 0.6;    // Lot multiplier when the entry goes against the dollar proxy trend
input bool             DXYProxyPrintOnUse        = true;

input group "64 — BROKER HOLIDAY CALENDAR"
input bool   EnableBrokerHolidayCalendar     = true;
input string BrokerHolidayDates              = "2026.12.25,2026.12.31,2027.01.01"; // comma-separated YYYY.MM.DD
input int    BrokerHolidayCautionDaysBefore  = 1;
input int    BrokerHolidayCautionDaysAfter   = 1;
input bool   BrokerHolidayHardBlockOnDay     = false;   // default OFF - caution (lot cut) instead of a hard block
input double BrokerHolidayLotFactor          = 0.5;
input bool   BrokerHolidayPrintOnUse         = true;

input group "65 — LADDERED PARTIAL CLOSE (2-STAGE)"
input bool   EnableLadderedPartialClose = false;   // V62b: OFF for the same reason as EnableSmartPartialClose - a second trim stage only compounds the average-price distortion described there. (No effect anyway while Smart Partial Close is off, but set false so re-enabling one does not silently pull in the other.)
input int    LadderStage2ProfitPoints   = 3000;    // 2nd trim trigger, further out than stage 1 (PartialCloseAtProfitPoints)
input double LadderStage2Percent        = 30.0;    // % of each position's REMAINING volume closed at stage 2

input group "66 — AUTO-FLAT BEFORE MAJOR NEWS"
input bool   EnableNewsAutoFlat         = true;    // Fully close the basket ahead of a high-impact calendar event
input int    NewsAutoFlatMinutesBefore  = 15;      // How many minutes before the event to close
input bool   NewsAutoFlatOnlyIfProfit   = true;    // Only close if the basket is currently in profit
input bool   NewsAutoFlatPrintOnUse     = true;

input group "67 — CORRELATION INSTABILITY"
input bool   EnableCorrelationInstability     = true;   // Extra caution when a pair's correlation itself is unreliable
input int    CorrelationShortWindowBars       = 50;
input int    CorrelationLongWindowBars        = 200;
input double CorrelationInstabilityThreshold  = 0.35;   // |short-term corr - long-term corr| beyond this = unstable
input double CorrelationInstabilityLotFactor  = 0.7;    // Extra lot cut applied on top of the normal correlation cut
input bool   CorrelationInstabilityPrintOnUse = false;

input group "68 — MARKET CONFIDENCE SCORE (VOLATILITY + BAYES + HURST)"
input bool   EnableConfidenceScore        = true;   // Combines 3 independent signals into ONE final lot multiplier
input ENUM_TIMEFRAMES ConfidenceATRTF     = PERIOD_H1;
input int    VolRegimeATRPeriod           = 14;
input int    VolRegimeLookbackBars        = 100;    // Bars of ATR history used to rank the current ATR's percentile
input double VolRegimeHighPercentile      = 85.0;   // Above this percentile = storm (caution)
input double VolRegimeLowPercentile       = 15.0;   // Below this percentile = too thin/dead (mild caution)
input bool   EnableVolRegimeContinuous    = true;   // V31.6z58: this function computed a real continuous percentile then collapsed it into 3 fixed values - the 85th and 99th percentile both scored identically, so "edge of a storm" and "deep inside one" were indistinguishable
input int    BayesMinSamples              = 8;      // Minimum closed trades for a detector before trusting its win-rate
input bool   EnableBayesShrinkage         = true;   // V31.6z48: real statistical weakness fixed - sample count used to be a pure on/off gate (10 samples at 70% trusted exactly as much as 200 at 70%). Shrinkage pulls the observed rate toward the 0.5 prior in proportion to how little evidence backs it.
input double BayesShrinkageStrength       = 10.0;   // Equivalent "virtual samples" of the 0.5 prior - higher = more conservative, needs more real evidence to move away from neutral
input int    BayesMaxSampleWindow         = 30;      // Rolling window size (older outcomes decay out)
input int    HurstLookbackBars            = 100;
input int    HurstMinChunkSize            = 8;
input double ConfidenceMinLotMultiplier   = 0.6;
input double ConfidenceMaxLotMultiplier   = 1.0;    // Capped at 1.0 - never exceeds StartLot
input bool   ConfidencePrintOnUse         = false;

input group "69 — SMART ZONE RECOVERY (TREND-BLOCK EXCEPTION)"
input bool   EnableSmartZoneRecovery      = true;   // Allow ONE reduced-lot recovery add at a strong wall while trend-block is active
input double SZRMinZoneStrength           = 1.3;   // Wall must be at least this strong (ZoneMapStrength)
input int    SZRZoneProximityPoints       = 500;    // Price must be within this many points of the wall (near side)
input int    SZRMaxBeyondZonePoints       = 250;    // If price has broken past the wall by more than this, the wall failed - no add
input int    SZRMaxUsesPerEpisode         = 3;      // V54b: replaces the old hard one-shot. How many smart rescue adds may fire during ONE continuous trend-block episode. The one-shot existed so SZR could not override the counter-trend block on every single grid step; a small cap keeps that protection while allowing more than a single rescue, as requested. Set 0 for uncapped (SZR then overrides the trend block on every step its zone/rejection/order-flow conditions pass - the riskiest setting).
input bool   SZRRequireRejectionCandle    = true;   // Last closed M15 candle must have poked the wall and closed back on our side
input bool   SZRUseOrderFlowVeto          = true;   // Strong tick-volume conviction INTO the wall (likely breakout) vetoes the add
input double SZRLotFactor                 = 1.0;    // V54b: raised 0.5 -> 1.0 on user request. A rescue add now uses the FULL normal next grid lot (which already carries the 1.30 martingale multiplier) instead of half of it. Rationale from the user: a half-size add takes new risk while barely improving the basket average, so it should either be a proper-sized add or no add at all. Set below 1.0 again if you want smaller, more cautious rescue adds.
input bool   EnableSZREscapeMode         = false;  // OFF - SZR adds exit via normal trailing/TP, not a fast release
input int    SZREscapePlusPoints         = 300;    // Escape target: basket profit points that triggers the fast release
input bool   SZRPrintOnUse                = true;

input group "70 — HUNTER INTELLIGENCE UPGRADE"
input bool   EnableHunterD1Filter        = true;   // Hunter's lower score threshold only applies WITH the D1 trend
input int    HunterD1LookbackDays        = 10;     // D1 bars back to compare for overall direction
input bool   HunterD1PrintOnUse          = true;
input bool   EnableHunterVelocitySense   = true;   // Give a small score bonus when a live tick-velocity spike agrees with the signal direction (pre-candle-close impulse sensing)
input int    HunterVelocitySenseBonus    = 1;

input group "71 — ROBOT EYES SHARPENING (SWEEP + FAKE BREAKOUT RETURN)"
input bool   EnableZoneAwareSweep        = true;   // Sweep level prefers a real, swing-confirmed Zone Map wall over a raw recent low/high
input bool   EnableSweepVolumeCheck      = true;   // Strong tick-volume on the sweep+rejection candle adds confidence (bonus, never a block)
input bool   EnableFakeBreakoutReturn    = true;   // NEW detector: price broke a real wall, failed to hold, closed back on the original side

// V147: trap quality. A failed breakout is the best setup on the chart - but only when it actually
// trapped someone. The detector above fires on any wick that pokes through a level and returns,
// which is most wicks: nobody was positioned there, so nobody has to get out, and the "reversal"
// has no fuel. A real trap broke deep enough to look genuine, HELD on the far side long enough for
// traders to enter, and then snapped back - that snap is those traders being forced out.
input bool   EnableTrapQuality           = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int    TrapQualityLookbackBars     = 10;     // Bars examined for the break and its failure
input double TrapQualityFullDepthATR     = 1.2;    // Penetration (in ATR) that counts as a fully convincing break
input int    TrapQualityFullHoldBars     = 3;      // Bars CLOSING beyond the level that count as fully convincing persistence
input double TrapWeightDepth             = 1.0;    // Weight of break depth
input double TrapWeightHold              = 1.6;    // Weight of persistence - highest, because without it there was no trap, only a wick
input double TrapWeightSnap              = 1.2;    // Weight of the snap-back speed
input double TrapQualityMinToTrade       = 0.35;   // Below this the "failed breakout" is noise and the setup is rejected outright
input int    TrapQualityWeakPenalty      = 3;      // V188: score cost of a failed-breakout that shows little evidence it trapped anyone. Previously this rejected the setup before scoring - which contradicted the design: every other warning in this EA shapes the trade instead of vetoing it, and this one should too.
input double TrapQualityStrong           = 0.65;   // At or above this the trap is convincing enough to earn extra score
input int    TrapQualityBonus            = 2;      // Score added for a convincing trap
input int    FBRLookbackBars             = 6;      // Bars back to search for the breach
input int    FBRBreachPoints             = 50;     // Minimum points beyond the wall to count as a genuine breach (not noise)
input double FBRMinZoneStrength          = 1.2;   // Wall must be at least this strong to qualify
input bool   FBRPrintOnUse               = false;

input group "72 — MAX BASKET EXPOSURE (SCALES WITH ANY ACCOUNT SIZE)"
input bool   EnableMaxBasketExposure     = true;   // Hard block: total basket margin can never exceed this % of equity, whatever the account size
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) MaxBasketMarginPercent
input bool   MaxBasketExposurePrintOnUse = true;

input group "73 — SESSION-ADAPTIVE GRID DISTANCE"
input bool   EnableSessionGridDistance   = true;   // Grid steps tighter in quiet Asia hours, wider in London/NY
input int    AsiaSessionStartHour        = 0;      // Server time hours
input int    AsiaSessionEndHour          = 7;
input double AsiaGridDistanceFactor      = 1.0;    // Asia session grid distance multiplier (1.0 = normal)
input int    LondonNYSessionStartHour    = 7;
input int    LondonNYSessionEndHour      = 21;
input double LondonNYGridDistanceFactor  = 1.15;
input bool   SessionGridPrintOnUse       = false;
input bool   EnableSessionTransitionGuard = true;   // V31.6z24 NEW: caution during the volatile first minutes after a major session opens
input int    SessionTransitionWindowMinutes = 15;   // Minutes before/after session open to treat as a transition window
input bool   EnableAsiaTransitionGuard   = false;    // Asia open is typically much calmer than London/NY - off by default
input int    SessionTransitionScorePenalty = 2;
input bool   EnableWeekendGapGuard       = true;    // V31.6z25 NEW: discourages fresh entries in the hours before Friday's close - weekend gap risk with no offsetting benefit
input int    WeeklyCloseHour             = 23;      // Server time hour the market effectively stops trading Friday
input int    WeekendGapGuardWindowMinutes = 120;    // How many minutes before close to start discouraging fresh entries
input int    WeekendGapScorePenalty      = 3;
input bool   EnableGapDetection          = true;    // V31.6z25 NEW: recognizes when the last two bars are separated by an abnormally large time gap (weekend/holiday close)
input double GapDetectionTimeMultiplier  = 2.5;     // Bar time-gap must exceed the timeframe's normal spacing by this multiple to count as a genuine gap
input double GapDetectionMinPoints       = 300;     // Minimum price gap size to matter for caution purposes
input int    GapCautionBarsAfter         = 3;        // How many bars after a detected gap to keep applying extra caution
input int    GapCautionScorePenalty      = 2;

// FEATURE(gap-fill-magnet): after a large gap, price tends to drift back to fill it. Discourage
// entries that fight that drift until the gap is filled. This addresses the live case where the
// market gapped up, left a gap below, and slowly sold back down to fill it while BUY zones kept
// firing straight into the decline. 3-digit broker: 1000 points = $1.
input bool   EnableGapFillMagnet          = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int    GapFillMagnetMinPoints       = 2000;    // Minimum gap size to treat as a magnet (2000 = $2). Weekend XAUUSD gaps are often $2-10; small gaps are ignored.
input bool   GapFillMagnetHardBlock       = false;  // V186: hard blok -> jazo. gap magnitiga qarshi - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.    // true = hard-block a first entry against the pull; false = penalty only
input int    GapFillMagnetMaxAgeBars     = 240;    // V178: bars (core TF) after which an unfilled gap stops blocking - 240 M1 bars is four hours. The magnet's logic is that price is drawn back to fill the gap; when it has trended away for hours instead, that is no longer what is happening and the block is just cost.
input int    GapFillMagnetMinBarGap      = 3;      // V178b: a real gap leaves a TIME hole - the bars either side sit further apart than this multiple of the timeframe. Without the test, any two adjacent minutes that jumped $2 armed the magnet, which on gold is a fast tick rather than a gap.
input bool   GapFillMagnetPrintOnUse     = true;   // Log when the magnet arms and expires
input int    GapFillMagnetScorePenalty    = 4;       // Score penalty when not hard-blocking (or for grid context)
input double GapFillMagnetFilledFraction  = 0.90;    // Gap counts as "filled" once price retraces this fraction of it back toward the fill level (0.90 = 90%)
input bool   EnableTPIntelligence        = true;    // V31.6z26 NEW: dynamic TP based on Trend Quality/Exhaustion Consensus - the natural complement to Smart Trail, previously purely mechanical
input double TPIntelligenceStrongTrendThreshold = 0.7; // Trend Quality Score above this extends TP
input double TPIntelligenceExtendMultiplier = 1.2;   // How much to extend TP when trend is genuinely strong
input double TPIntelligenceExhaustionThreshold = 0.3; // Exhaustion Consensus at/below this tightens TP
input double TPIntelligenceTightenMultiplier = 0.8;  // How much to tighten TP when exhaustion signs are firing

input group "122 — GRID INTELLIGENCE UNIFICATION (SENSES 14-15)"
// V31.6z27: found that Adaptive Recovery Intelligence (DRI) and Market Regime Auto-Tuning
// (DRT) were separately, redundantly multiplying grid distance/lot based on similar criteria
// as Grid Intelligence - three parallel, mutually-unaware systems compounding blindly. Their
// genuinely NON-redundant signals (BOS/CHoCH, HTF direction, Top Zone Trap, DD stretch) are
// now folded into Grid Intelligence's proven 13-sense consensus as Senses 14-15, and DRI/DRT
// are disconnected from directly multiplying distance/lot (see group 123).
// (EnableStructureConfluence declared above with the other structure settings)
input bool   EnableBasketDDStretch       = true;
input int    GridOpposingZoneCautionPoints = 600;   // V31.6z28 NEW: real bug found via live testing - Grid's Zone sense never checked the OPPOSING zone (resistance for BUY, support for SELL) at all
input double GridOpposingZoneMinStrength = 1.5;
input bool   EnableGridFarZoneAwareness  = true;    // V31.6z29 NEW: the 600pt check alone covers <10% of an actual grid step (6500pts+) - blind to a major zone further out but still in the grid's path
input int    GridFarZoneCautionPoints    = 6000;    // Roughly one grid step - covers the range the NEXT addition (or this one settling in) is likely to reach
input double GridFarZoneMinStrength      = 2.5;     // Notably higher than the near-range bar - only genuinely MAJOR levels should matter at this distance

input group "74 — ZONE / FVG QUALITY UPGRADE"
input int    ZoneTouchMinSeparationBars  = 5;      // Two swing points closer than this count as ONE touch, not two independent confirmations
input double ZoneAgeMinWeight            = 0.3;    // Oldest touch in the lookback window counts this fraction of a fresh one (recency-weighted)
input bool   EnableZoneAgeByProof        = true;   // V265: let the touch count raise the age floor. Age discounted every touch equally, so the oldest in the window kept thirty percent of its weight regardless of quality - a shelf touched three times nine days ago counted as roughly one touch, which is how the 4305-4315 level read as a minor swing. Age is a fair proxy for relevance when nothing better exists; here something better does - a price the market returned to three separate times has been confirmed by the market, and that confirmation does not expire on the same schedule as one untested touch.
input int    ZoneAgeProofFullTouches     = 4;      // V265: touches at which the floor reaches its maximum
input double ZoneAgeProofMaxFloor        = 0.75;   // V265: the floor a well-tested level keeps. One touch still fades to thirty percent; several holds most of its weight for as long as it stays in the window.
input bool   EnableFVGClusterBonus       = true;   // Overlapping/nearby unfilled gaps make a level stronger, not just one gap in isolation
input int    FVGClusterTolerancePoints   = 150;
input double FVGClusterStrengthWeight    = 0.3;
input bool   EnableZoneCascade           = true;   // If the nearest wall already failed, fall back to the NEXT wall further out instead of giving up

input group "75 — NEAR-ZONE REACTION + NY KILLZONE CAUTION"
input bool   EnableNearZoneReaction      = true;    // NEW detector: price approaching a real zone with an early rejection sign, before it's tested/broken
input int    NearZoneReactionRangePoints = 1500;    // V75b: 300 -> 1500 ($1.5). This is how close price must be to a support/resistance for a bounce entry to register. On a 3-digit broker 300 = $0.30, far tighter than where XAUUSD actually reacts to a level ($1-2 out), so most genuine bounces were missed and price had to be almost touching the zone. $1.5 catches a real reaction while still requiring price to be at the level, not drifting near it. (Distinct from the $3.5 counter-zone BLOCK, which is about entering INTO a wall the wrong way.)// Must be within this many points of the wall, not yet at/through it
input double NearZoneReactionMinStrength = 1.2;   // Zone strength required for a near-zone reaction signal
input bool   EnableNYKillzoneCaution     = true;    // Soft lot caution during typical NY-open volatility window - never blocks, any signal type
input int    NYKillzoneStartHour         = 15;      // Server time hours - adjust to match your broker's NY-open offset
input int    NYKillzoneEndHour           = 17;
input double NYKillzoneLotFactor         = 0.7;
input bool   NYKillzonePrintOnUse        = false;

input group "76 — IMPULSE CORRECTION GUARD (FIRST ENTRY) [SUPERSEDED]"
input bool   EnableImpulseCorrectionGuard      = false;  // OFF - superseded by group 77 (swing-based)
input int    ImpulseCorrectionWindowBars       = 8;
input double ImpulseCorrectionMinRetracePercent = 25.0;
input double ImpulseCorrectionLotFactor        = 0.5;
input bool   ImpulseCorrectionPrintOnUse       = true;

input group "77 — SWING IMPULSE CORRECTION (UPGRADED, MULTI-LAYER)"
input bool             EnableSwingImpulseCorrection = true;
input ENUM_TIMEFRAMES  SwingImpulseTF               = PERIOD_M15;
input int               SwingImpulseLookbackBars    = 50;      // How far back to search for the last significant swing high/low
input int               SwingImpulseDepth           = 3;       // Swing confirmation depth (same convention as Zone Map)
input double            SwingImpulseMinATRMultiple  = 3.0;     // The swing range must be at least this many ATRs to count as a genuine big impulse (adapts to any market condition)
input double            SwingImpulseMinRetracePercent = 25.0;  // Price must have retraced at least this % of the impulse range to call it an active correction
input bool              SwingImpulseRequireMTFConfirm = true;  // Reference point must also be a real, multi-TF confirmed Zone Map level (not just local M15 noise)
input double            SwingImpulseMTFMinStrength  = 1.5;
input bool              SwingImpulseUseVolumeCheck  = true;    // Heavy volume during what looks like a correction is suspicious - extra caution
input bool              SwingImpulseUseZoneMatch    = true;    // Price sitting at a real zone, proportional to the impulse size, strengthens the correction read
input double            SwingImpulseZoneSearchFactor = 0.6;    // Search zones within this fraction of the impulse's own range - big impulses look farther out
input double            SwingImpulseBigDirLotFactor = 0.5;     // Lot factor when a real zone match is found
input double            SwingImpulseSmallDirLotFactor = 0.7;   // Lot factor when no zone match, but retrace/ATR conditions still qualify
input bool              SwingImpulsePrintOnUse      = true;

input group "78 — TREND REVERSAL (SWING SEQUENCE + RSI DIVERGENCE)"
input bool              EnableTrendReversal          = true;
input ENUM_TIMEFRAMES   TrendReversalTF              = PERIOD_M15;
input int               TrendReversalLookbackBars    = 80;
input int               TrendReversalSwingDepth      = 3;
input int               TrendReversalRSIPeriod       = 14;
input bool              TrendReversalRequireDivergence = false;  // If true, RSI must also confirm (not just price structure) - stricter
input int               TrendReversalBonus           = 2;        // Score bonus when an entry aligns with a confirmed reversal
input int               TrendReversalDivergenceBonus = 1;        // Extra bonus when RSI divergence also confirms
input int               TrendReversalAgainstPenalty  = 2;        // V31.6s: PENALTY when a confirmed reversal points AGAINST the proposed entry - was previously only ever rewarded when it agreed, never penalized when it disagreed
input int               TrendReversalAgainstDivergencePenalty = 2; // Extra penalty on top when RSI divergence also confirms the against-reversal
input int               MTFAgainstPenaltyUnanimous   = 6;        // V31.6s: penalty when all 4 TF agree AGAINST entry direction
input int               MTFAgainstPenalty3           = 4;        // Penalty when 3/4 TF agree against
input int               MTFAgainstPenalty2           = 2;        // Penalty when 2/4 TF agree against
input bool              EnableTrendStrengthEntry     = true;     // V31.6s: was ONLY wired into Grid Intelligence - a strong, sustained ADX-confirmed trend against a first entry had zero effect on its score until now
input int               TrendStrengthEntryPenaltyMax = 4;        // Penalty at maximum adverse trend strength (ADX >= TrendStrengthStrongADX)
input bool              TrendReversalPrintOnUse      = true;
// V31.6m cleanup: removed EnableGridReversalBlock - superseded by the continuous Grid
// Intelligence Score system (group 92), which replaced this binary block entirely.

input group "79 — MULTI-TIMEFRAME STRUCTURE ALIGNMENT"
input bool              EnableMTFAlignment           = true;
input int               MTFAlignmentM15LookbackBars  = 20;
input int               MTFAlignmentH1LookbackBars   = 20;
input int               MTFAlignmentH4LookbackBars   = 20;
input int               MTFAlignmentBonusPerTF       = 1;   // Score bonus per additional timeframe that agrees with the entry direction
input bool              MTFAlignmentPrintOnUse       = false;

input group "80 — BRAIN CONSENSUS (INDEPENDENT-EVIDENCE SYNERGY)"
input bool              EnableBrainConsensus         = true;   // Rewards genuine agreement across INDEPENDENT evidence categories, beyond their individual score contributions
input int               BrainConsensusMinCategories  = 3;      // Minimum independent categories agreeing before the synergy bonus applies
input int               BrainConsensusBonus          = 2;
input int               BrainConsensusConflictPenalty = 3;   // V31.6z66: NEW state - enough categories agree AND enough disagree at the same time. Previously the `else if` meant agreement won and every opposing category was silently discarded. Conflict is ambiguity, not confirmation.
input bool              BrainConsensusPrintOnUse     = true;

input group "81 — ZONE POLARITY FLIP"
input bool              EnableZonePolarityFlip       = true;
input int               PolarityFlipLookbackBars     = 120;    // V31.6z51: raised from 60 - on the new H1 default this reaches ~5 days, enough to actually see a major zone's break-and-flip. (Was 60 bars on M15 = only 15 hours.)
input int               PolarityFlipMinHoldBars      = 2;      // Price must have held on the new side for at least this many bars
input double            PolarityFlipStrengthBonus    = 0.6;    // Added to ZoneMapStrength when a level shows a genuine polarity flip
input ENUM_TIMEFRAMES   PolarityFlipTF               = PERIOD_H1;  // V31.6z51: was hardcoded to M15 - with the 60-bar lookback that meant it could only see 15 HOURS, so any major H4/D1 flip older than that was invisible. H1 x 120 bars now reaches ~5 days.
input bool              EnablePolarityFlipTrendWeighting = true;  // V31.6z51: a flip that agrees with the H4/D1 picture is the classic reliable structure; one against it usually fails - they were weighted identically before
input double            PolarityFlipTrendAlignedLevel = 0.35;     // |Global Trend Confidence| needed to count as clearly aligned/opposed
input double            PolarityFlipTrendAlignedMultiplier = 1.4; // Flip bonus multiplier when the flip direction agrees with the global trend
input double            PolarityFlipTrendAgainstMultiplier = 0.5; // Flip bonus multiplier when the flip fights the global trend

input group "82 — MULTI-CANDLE PATTERN (EXHAUSTION UPGRADE)"
input bool              EnableMultiCandlePattern     = true;
input int               MultiCandleBonus             = 1;

input group "83 — SPREAD/ATR LIQUIDITY QUALITY"
input bool              EnableSpreadATRQuality       = true;
input double            SpreadATRWarnRatio           = 0.15;   // Spread above this fraction of ATR = caution
input double            SpreadATRLotFactor            = 0.7;
input bool              SpreadATRPrintOnUse          = false;

input group "84 — NEWS SURPRISE MAGNITUDE"
input bool              EnableNewsSurprise           = true;
input double             NewsSurpriseMinPercent       = 20.0;   // % deviation from forecast to count as a genuine surprise
input int               NewsSurpriseExtraCautionMinutes = 30;   // Extra caution window after a big surprise, beyond the normal pre/post window
input double            NewsSurpriseLotFactor        = 0.6;
input bool              NewsSurprisePrintOnUse       = true;

input group "85 — DAY-OF-WEEK LEARNING"
input bool              EnableDayOfWeekBayes         = true;
input int               DayOfWeekBayesMinSamples     = 6;
input int               DayOfWeekBayesMaxWindow      = 20;
input int               DayOfWeekBayesBonus          = 1;
input int               DayOfWeekBayesPenalty        = 1;   // FIX(dow-bayes-penalty): the "bad day of week" penalty used to reuse DayOfWeekBayesBonus (copy-pasted from the HourBayes pair above without its own Penalty input), so it could not be tuned independently of the bonus

input group "86 — POST-SL SAME-DIRECTION COOLDOWN"
input bool              EnablePostSLDirectionGuard   = true;
input int               PostSLDirectionWindowBars    = 15;
input int               PostSLDirectionExtraScoreReq = 3;       // Extra score points required for a same-direction entry in the window
input double            PostSLDirectionLotFactor     = 0.6;
input bool              PostSLDirectionPrintOnUse    = true;

input group "87 — ZONE FATIGUE (RAPID REPEAT TESTING)"
input bool              EnableZoneFatigue            = true;
input int               ZoneFatigueWindowBars        = 15;      // Touches within this many bars of each other count as "rapid"
input int               ZoneFatigueMinRapidTouches   = 2;       // This many rapid touches triggers the fatigue penalty
input double            ZoneFatigueStrengthPenalty   = 0.5;
input bool              EnableZoneLongTermExhaustion = false;  // V31.6z18 fix: defaulted OFF after user feedback - a zone proven strong across many weeks and timeframes should be respected MORE, not penalized. Available for those who want it, but off by default.
input int               ZoneLongTermExhaustionMinTouches = 4;  // Total well-separated touches (over the FULL lookback) before exhaustion caution starts
input double            ZoneLongTermExhaustionPenaltyPerTouch = 0.15;
input double            ZoneLongTermExhaustionMaxPenalty = 0.8; // Capped - a heavily-tested zone still has some validity, just tempered rather than treated as ever-strengthening

input group "88 — PER-ZONE HISTORICAL RELIABILITY"
input bool              EnableZoneReliability        = true;
input double            ZoneReliabilityBucketPoints  = 500;     // Price bucket size for tracking outcomes
input int               ZoneReliabilityMinSamples    = 3;
input int               ZoneReliabilityMaxWindow     = 30;     // V31.67c: raised 12 -> 30 on user request for LONGER zone memory. The bot now remembers a level's hold/break record over ~30 outcomes instead of ~12, so a zone proven strong over a long history keeps that memory instead of it decaying away after a dozen touches.

input group "89 — DXY TESTER CONSISTENCY"
// No new inputs - DXYProxyEnsureSymbols now checks MQL_TESTER explicitly for consistent
// backtest-vs-live behavior instead of silently depending on symbol availability.

input group "90 — BROKER MARGIN LEVEL AWARENESS"
// Independent from our own equity-DD based stops (group 00) - this tracks the BROKER'S own
// Margin Level% (Equity/Used Margin), the number that actually triggers a forced stop-out on
// their side, completely outside our control once it's reached.
input bool              EnableMarginLevelGuard       = true;
input double            MarginLevelWarnPercent       = 150.0;   // Below this - soft caution, lot trimmed
input double            MarginLevelDangerPercent     = 100.0;   // Below this - new grid additions blocked
input double            MarginLevelLotFactor         = 0.5;
input bool              MarginLevelPrintOnUse        = true;

input group "91 — DUPLICATE INSTANCE PROTECTION"
// A completely different risk dimension: not market risk, but DEPLOYMENT risk. If the same
// EA (same Magic+Symbol) is accidentally attached twice on the same terminal - two chart
// windows, or forgetting one is already running - both instances would think they own the
// same basket and could send conflicting orders. Detected via a heartbeat GlobalVariable,
// shared across all EA instances on the same terminal.
input bool              EnableDuplicateInstanceGuard = true;
input int               DuplicateInstanceHeartbeatSeconds = 5;
input int               DuplicateInstanceStaleSeconds = 30;
input bool              DuplicateInstancePrintOnUse  = true;

input group "92 — GRID INTELLIGENCE (SIXTEEN-SENSE, CONTINUOUS)"
// Grid is the primary rescue mechanism when a basket is losing - it now gets the fullest
// awareness we have: reversal confidence, zone quality + historical reliability, multi-TF
// alignment, order flow, DXY macro, volatility regime, trend strength (ADX), a forward-
// looking recovery-path zone search, major-sweep awareness, Equilibrium/Premium-Discount
// range position, engulfing pattern confirmation, recent zone break, AND impulse exhaustion
// warning (group 118) - catches deceleration in the SAME direction grid is riding, right now.
// Combined into ONE weighted 0-1 score with non-linear consensus/conflict adjustment.
input bool              EnableGridIntelligence       = true;
input double            GridIntelligenceMinLotFactor = 0.15;   // Lot floor at the worst (but not hard-blocked) score
input double            GridIntelligenceNeutralLotFactor = 0.85; // V31.6z35 NEW: lot factor at a completely NEUTRAL score (0.5) - was collapsing to ~0.57 under the old linear formula, crushing lot sizing's informative value once combined with the rest of the chain
input bool              EnableGridIntelligenceDistance = true;   // V31.6z59: fixes a regression from the z27 unification - disconnecting DRI/DRT removed ALL condition-awareness from grid DISTANCE (lot got a replacement, distance did not), leaving it purely mechanical regardless of what the 16 senses saw
input double            GridIntelligenceMaxDistanceWiden = 1.5;  // Distance multiplier at the worst (but not hard-blocked) score - poor conditions mean "wait for a better price", not just "add less"

input group "125 — MTF ALIGNMENT CONFIDENCE (MAGNITUDE-AWARE)"
// Same upgrade already applied to Global/Local Trend, found still missing here: the existing
// MTFAlignmentCount() treats a barely-positive close comparison the same as a strongly ADX-
// confirmed trend. This adds a continuous, magnitude-aware confidence used at the two most
// decision-critical points, without touching the 15+ places that use the simple count.
input bool              EnableMTFConfidence          = true;
input int               MTFConfidenceADXPeriod       = 14;
input double            MTFConfidenceMinADX          = 18.0;
input double            MTFConfidenceADXFullStrength = 32.0;
input double            MTFConfidenceWeakValue       = 0.30;   // Capped confidence when ADX doesn't qualify and simple close-comparison is used instead
input double            MTFConfidenceD1Value         = 0.40;   // D1 has no dedicated ADX check here - fixed weak-to-moderate confirmation value
input double            MTFConfidenceStrongLevel     = 0.45;   // V31.6z47: |confidence| at/above this counts as strongly aligned/opposed for First Entry scoring
input int               MTFConfidenceScoreAdjust     = 2;      // V31.6z47: First Entry bonus/penalty magnitude - modest, since the direction-only MTF check above already contributes

input group "126 — DIRECTIONAL CLARITY (BOTH-SIDES-SCORED CHECK)"
// V31.6z49: direct response to the user's observation that first-entry errors are a main cause
// of long drawdowns. The scanner picks the single highest scorer across all 47 detectors -
// winner takes all - so nothing downstream ever knew whether the OPPOSING direction also had a
// strong candidate at that same moment. "BUY 7 with nothing on sell" (one-sided conviction) and
// "BUY 7 but SELL 6 too" (the market telling both stories at once) were indistinguishable.
input bool              EnableDirectionalClarity     = true;
input int               DirectionalClarityMinOpposingScore = 4;  // Opposing side must reach at least this to count as genuine competition (below this it's just noise)
input int               DirectionalClarityMaxMargin  = 3;        // Margin (own - opposing) at/below which the ambiguity penalty applies at all
input int               DirectionalClarityMaxPenalty = 4;        // Penalty at a dead tie (margin=0), scaling down linearly as the margin widens
input bool              DirectionalClarityPrintOnUse = true;
input double            GridIntelligenceHardBlockBelow = 0.12; // Below this score, block entirely (overwhelming multi-sense agreement against)
input bool              GridIntelligencePrintOnUse   = true;
input double            GridIntelligenceConsensusWeight = 0.08;   // Per-extra-sense adjustment when 3+ senses strongly agree (either direction)
input double            GridIntelligenceConflictPenalty = 0.10;   // Penalty when senses are genuinely split (ambiguous, dangerous ground)
input int               GridIntelligenceConsensusMaxOpposed = 2;  // V31.6z67: the consensus BONUS now also requires few senses opposing. Previously it only checked "enough agree" - so 10 for / 6 against still collected a full synergy bonus while the conflicted branch never ran.
input double            GridIntelligenceDepthThresholdBoost = 0.35; // How much the hard-block bar rises from order 1 to order 6+ (deeper = stricter)
input double            GridIntelligenceMaxThreshold = 0.85;  // V31.6z68: the depth boosts are multiplicative (reversal x1.5, adverse-streak x1.5, DD-accel x1.6 = x3.6) and could push the bar to ~1.38 - above the score's own 0-1 range, so NOTHING could ever pass and the 16-sense system silently became a plain hard block. Conditions may demand a near-perfect read; never an impossible one.

input group "93 — TREND STRENGTH (ADX)"
input bool              EnableTrendStrength          = true;   // V31.6q: catches a strong, SUSTAINED, ongoing move against grid direction - Trend Reversal alone only fires on a CHANGE of character, missing plain continuation
input ENUM_TIMEFRAMES   TrendStrengthTF              = PERIOD_M15;
input int               TrendStrengthPeriod          = 14;
input double            TrendStrengthMinADX          = 20.0;   // Below this ADX, no meaningful trend - component stays neutral
input double            TrendStrengthStrongADX       = 40.0;   // At/above this ADX, treated as maximum strength

input group "94 — RECOVERY PATH ZONE SEARCH"
// The first FORWARD-LOOKING sense: searches the actual price path between now and the
// basket's break-even average for a real, strong waypoint the market is likely to respect.
input bool              EnableRecoveryPathSearch     = true;
input int               RecoveryPathMaxWaypoints     = 3;      // How many candidate zones to scan along the path (cascading, like SZR)
input int               RecoveryPathZoneToleranceP   = 50;     // Points to step past a found zone before searching for the next
input double            RecoveryPathMinZoneStrength  = 1.5;    // V31.6z60: minimum strength for a zone on the path home to count as a genuine BARRIER (was mislabelled "waypoint" - the old code treated these obstacles as a reason to add MORE, exactly inverted)
input double            RecoveryPathSeveritySpan     = 2.0;    // V31.6z60: strength range above MinZoneStrength across which barrier severity scales from mild to full

input group "95 — MAJOR SWEEP AWARENESS"
// Scans recent bars for a strong, zone-confirmed sweep-rejection - a general sense that feeds
// grid/entry decisions, complementing the existing Sweep detector (which only fires as its
// own standalone entry type on the current bar).
input bool              EnableMajorSweepAwareness    = true;
input int               MajorSweepLookbackBars       = 6;
input int               MajorSweepZoneSearchPoints   = 300;
input double            MajorSweepMinZoneStrength    = 1.5;
input int               MajorSweepScoreBonus         = 2;      // Bonus/penalty magnitude when a recent sweep agrees/disagrees with the proposed direction
input bool              MajorSweepPrintOnUse         = true;

input group "96 — EQUILIBRIUM / PREMIUM-DISCOUNT ZONE"
// Classic SMC concept: the 50% midpoint of the current significant range splits it into
// Premium (upper half, favors SELL) and Discount (lower half, favors BUY). Captures WHERE
// within the broader range price sits - a dimension no other sense measures.
input bool              EnableEQZone                 = true;
input ENUM_TIMEFRAMES   EQZoneTF                     = PERIOD_H1;
input int               EQZoneLookbackBars           = 40;
input double            EQZonePremiumThreshold       = 65.0;   // Range-position % at/above which price is "deep Premium"
input double            EQZoneDiscountThreshold      = 35.0;   // Range-position % at/below which price is "deep Discount"
input int               EQZoneScoreBonus             = 2;      // Bonus/penalty magnitude when EQ zone agrees/disagrees with the proposed direction
input bool              EnableEQZoneScaling          = true;   // V251: weigh premium/discount by how deep into the extreme price is, rather than a flat point either side of the threshold
input int               EQZoneDeepBonus              = 4;      // V251: extra weight at the far edge of the range, on top of the base. At the threshold itself the reading is marginal; at the extreme it is the whole trade.
input bool              EQZonePrintOnUse             = false;

input group "97 — ENGULFING PATTERN AWARENESS"
// Classic two-candle reversal/continuation confirmation: current candle's body completely
// engulfs the prior candle's body in the opposite direction. Zone-quality-gated by default,
// same upgrade philosophy as Sweep: prefer engulfing AT a real level over open-space noise.
input bool              EnableEngulfingAwareness     = true;
input int               EngulfingLookbackBars        = 6;
input bool              EngulfingRequireZoneConfirm  = true;
input int               EngulfingZoneSearchPoints    = 300;
input double            EngulfingMinZoneStrength     = 1.5;
input int               EngulfingScoreBonus          = 2;
input bool              EngulfingPrintOnUse          = true;

// FEATURE(candlestick-models): Pin Bar (Hammer / Shooting Star) and Morning/Evening Star, added
// to the reversal consensus so a turn is confirmed by classic candlestick reversals, not just
// engulfing. These feed the SAME consensus that both grid reactions and reversal first-entries
// use, so improving them here strengthens both at once.
input group "97b — CANDLESTICK REVERSAL PATTERNS (Pin Bar + Star)"
input bool   EnablePinBarAwareness      = true;   // Include Pin Bar (Hammer/Shooting Star) in the reversal consensus
input double PinBarMaxBodyFraction      = 0.35;   // Body must be <= this fraction of the candle range (a pin bar is mostly wick)
input double PinBarMinWickFraction      = 0.50;   // The rejection wick must be >= this fraction of the range (long tail)
input double PinBarOppositeWickMax      = 0.5;    // The opposite (small) wick must be <= this fraction of the rejection wick
input bool   EnableStarAwareness        = true;   // Include Morning/Evening Star (3-candle) in the reversal consensus
input double StarMiddleMaxBodyFraction  = 0.5;    // The middle "star" candle's body must be <= this fraction of the first candle's body
input int    CandlePatternLookbackBars  = 4;      // How many recent bars to scan for a pin bar / star

// FEATURE(order-block + tweezer): 1st-stage advanced models. Order Block = institutional zone
// (last opposite candle before a strong impulse) that price returns to and reacts from - a
// higher-grade signal than a plain candle. Tweezer = two candles rejecting the same level twice.
// Both feed the SAME reversal consensus, so grid reactions and reversal first-entries both gain.
input bool   EnableOrderBlockAwareness  = true;   // Include institutional Order Block reactions in the consensus
input double OrderBlockImpulseATRMult   = 1.5;    // The impulse leg after the order block must be at least this * ATR (a real institutional move)
input int    OrderBlockLookbackBars     = 8;      // How many bars back to search for the order block + impulse
input int    OrderBlockZonePadPoints    = 100;    // Price counts as "in the zone" within this many points of the order block candle
input bool   EnableTweezerAwareness     = true;   // Include Tweezer top/bottom in the consensus
input int    TweezerTolerancePoints     = 80;     // Two highs/lows within this many points count as a matching tweezer level

// FEATURE(consensus-quality): 2nd-stage quality layer (B + C). A reversal is stronger when it
// happens (C) at a strong S/R zone, and (B) shows up on more than one timeframe. Rather than
// GATE signals on these (which would starve the consensus), we ADD a bonus confirmation when they
// hold - so a reversal at a real wall, confirmed on two TFs, counts for more, while a lone signal
// still counts. Bonus, not a filter - keeps the consensus alive while rewarding quality.
input bool   EnableConsensusZoneQuality  = true;   // (C) +1 consensus when the reversal sits at a strong S/R zone
input double ConsensusZoneMinStrength    = 2.0;    // Zone must be at least this strong (ZoneMapStrength) to grant the bonus
input int    ConsensusZoneProximityPts   = 350;    // Reversal must be within this many points of that zone
input bool   EnableConsensusMultiTF      = true;   // (B) +1 consensus when a candle reversal also shows on the higher TF
input bool   EnableConsensusOrderFlow    = true;   // (A) +1 consensus when order-flow pressure agrees with the reversal. NOTE: MT5 has only tick volume, so this is a rough proxy - kept as a bonus (never a gate) precisely because it's the least reliable of the three quality layers.

input group "98 — REVERSAL VS CONTINUATION RISK DIFFERENTIATION"
// From the professional audit (Phase 1/2 findings): reversal-type signals carry more
// downstream risk than continuation-type signals in a grid/martingale system, but were
// previously held to the identical score bar. This treats them differently at both entry
// (higher bar to start) and grid (faster-rising caution as a reversal-opened basket deepens).
input bool              EnableReversalRiskDifferentiation = true;
input int               ReversalTypeExtraScoreReq    = 1;      // Extra minimum score required for a reversal-type first entry

// FEATURE(firstentry-reversal-consensus): a reversal-type first entry (sweep / near-zone / fake-
// breakout / range-edge / exhaustion / zone-retest) is a bet that price TURNS. A single candle or
// a single detector can be fooled. So for reversal-type entries ONLY, cross-check the multi-signal
// ReversalConsensusScore in the entry's own direction: if 2+ independent reversal signals agree,
// award a score BONUS (this is a genuine turn); if they don't, apply a PENALTY (the turn isn't
// confirmed). This is deliberately a score nudge, NOT a hard block - a strong reversal setup can
// still pass without full consensus, and it NEVER touches trend / breakout / momentum entries
// (those aren't reversals, so demanding reversal consensus of them would wrongly suppress them).
input bool   EnableFirstEntryReversalConsensus = false;                                         // V55b: OFF. Redundant - the reversal consensus is ALREADY scored by the GlobalLocalScoreBonus block, which handles it with a proper three-way branch (supports / opposes / conflicting, +/-3). This layer added a fourth opinion on the same evidence: consensus in favour scored +3 there and +2 here, absent consensus was penalised twice. One voice per observation.
input double FirstEntryConsensusMinScore    = 0.80;      // 0.82 = 2 signals agree, 0.92 = 3+. 0.80 = "at least 2 independent reversal signals".
input int    FirstEntryConsensusBonus       = 2;         // Score added when consensus confirms the reversal
input int    FirstEntryConsensusPenalty     = 1;         // V50b: cut 2 -> 1. This penalty stacked on top of ReversalTypeExtraScoreReq (+1 to the minimum) and the daily-bias penalty, pushing a Balanced-mode reversal entry's effective bar to ~10 points - a good setup scoring 8 was failing. The +2 bonus for confirmed consensus is kept, so consensus is still rewarded; it's just no longer double-punished when absent.
input bool   FirstEntryConsensusPrintOnUse  = true;
input double            ReversalTypeDepthBoostMultiplier = 1.5; // Grid's depth-aware threshold rises this much faster for a reversal-opened basket

input group "99 — TREND QUALITY SCORE (CONTINUATION SYNTHESIS)"
// The market moves WITH a trend more often than it reverses - this is the unifying "eye" for
// trend-continuation confidence, combining ADX strength, MTF alignment, moving-average order,
// and Higher-High/Higher-Low structure into one 0-1 score. Boosts every continuation-type
// detector (and can stand alone as its own confirmation) rather than being one more isolated signal.
input bool              EnableTrendQualityScore      = true;
input ENUM_TIMEFRAMES   TrendQualityTF               = PERIOD_M15;
input int               TrendQualityFastMA           = 8;
input int               TrendQualityMediumMA         = 21;
input int               TrendQualitySlowMA           = 50;
input int               TrendQualitySwingDepth       = 3;
input int               TrendQualitySwingLookback     = 40;
input int               TrendQualityBonus            = 2;      // Score bonus when trend quality strongly agrees with entry direction
input double            TrendQualityMinScoreForBonus = 0.65;
input bool              TrendQualityPrintOnUse       = true;

input group "100 — BREAKOUT CONTINUATION"
// Opposite of Fake Breakout Return: price breaks a real zone with a strong, non-rejecting
// close - bet the break is genuine and continues, not a trap.
input bool              EnableBreakoutContinuation   = true;
input int               BreakoutSearchPoints         = 300;
input int               BreakoutConfirmPoints        = 100;   // How far beyond the zone the close must be to count as a genuine break
input double            BreakoutMaxWickRatio         = 0.25;  // Rejection wick must be below this fraction of the candle range
input double            BreakoutStrengthConfirmScale = 0.5;    // V31.6z18 fix: replaces the old "strength=bonus" logic - stronger zones now require proportionally MORE confirm-distance beyond BreakoutConfirmPoints before a break is accepted (a real bug found via live testing: a proven multi-week support broke through a single confirming candle, backwards logic)

input group "101 — TREND RIDE (ADX-CONFIRMED PULLBACK ENTRY)"
// Classic "buy the dip in an uptrend": strong ADX-confirmed trend + a shallow pullback that's
// now resuming - enter WITH the trend rather than waiting for a reversal that may not come.
input bool              EnableTrendRide              = true;
input ENUM_TIMEFRAMES   TrendRideTF                  = PERIOD_M15;
input double            TrendRideMinADX              = 25.0;
input int               TrendRidePullbackLookback    = 5;
input double            TrendRideMaxPullbackATRMult  = 1.5;   // Pullback depth must stay within this multiple of ATR (shallow, not a reversal)

input group "102 — SWING CONTINUATION"
// The mirror of Trend Reversal: after a pullback WITHIN an established trend, a fresh swing
// point that CONTINUES the existing HH/HL (or LH/LL) sequence confirms the trend is intact,
// not reversing.
input bool              EnableSwingContinuation      = true;
input ENUM_TIMEFRAMES   SwingContinuationTF          = PERIOD_M15;
input int               SwingContinuationDepth       = 3;
input int               SwingContinuationLookback     = 40;

input group "103 — MOVING AVERAGE BOUNCE"
// Price pulls back to a rising (or falling) moving average within a confirmed trend and
// bounces - a very well-known, simple trend-continuation entry.
input bool              EnableMABounce               = true;
input ENUM_TIMEFRAMES   MABounceTF                   = PERIOD_M15;
input int               MABouncePeriod               = 21;
input int               MABounceTolerancePoints      = 150;
input int               MABounceSlopeLookback        = 5;    // Bars back to compare MA slope for rising/falling confirmation

input group "104 — DONCHIAN BREAKOUT"
// The simplest, most classic trend-following entry: price makes a new N-bar high/low.
input bool              EnableDonchianBreakout       = true;
input ENUM_TIMEFRAMES   DonchianTF                   = PERIOD_M15;
input int               DonchianPeriod               = 20;

input group "105 — CONSECUTIVE SAME-DIRECTION CANDLES"
// Several candles in a row closing the same direction is a simple, reliable momentum
// confirmation - an uninterrupted push, not a chop.
input bool              EnableConsecutiveCandles     = true;
input ENUM_TIMEFRAMES   ConsecutiveCandlesTF         = PERIOD_M15;
input int               ConsecutiveCandleCount       = 3;

input group "106 — DXY-CONFIRMED TREND (GOLD-SPECIFIC MACRO)"
// If the dollar is trending strongly and gold's local price agrees, that's macro-level
// confirmation, not just local price action.
input bool              EnableDXYConfirmedTrend      = true;
input int               DXYConfirmedTrendPriceLookback = 10;

input group "107 — EXPANDING VOLATILITY"
// ATR expanding (not contracting) in the trend direction means there's still room left -
// the trend isn't running out of steam.
input bool              EnableExpandingVolatility    = true;
input ENUM_TIMEFRAMES   ExpandingVolTF               = PERIOD_M15;
input int               ExpandingVolFastPeriod       = 5;
input int               ExpandingVolSlowPeriod       = 20;
input double            ExpandingVolMinRatio         = 1.15;  // Fast ATR must exceed slow ATR by at least this ratio to count as "expanding"

input group "108 — MTF UNANIMOUS TRIGGER"
// Rare, but when all 4 timeframes (M15/H1/H4/D1) agree on direction, that's a genuinely
// strong standalone signal, not just a supporting bonus.
input bool              EnableMTFUnanimousTrigger    = true;
input int               MTFUnanimousBaseScore        = 5;

input group "109 — EQ ZONE TREND (BUY THE DIP IN AN UPTREND)"
// The Equilibrium/Premium-Discount concept read the other way: within a CONFIRMED trend,
// price pulling back to the Discount half (for an uptrend) or Premium half (for a downtrend)
// is the classic "buy the dip / sell the rip within a trend" entry.
input bool              EnableEQZoneTrend            = true;
input double            EQZoneTrendMinADX            = 22.0;

input group "110 — VOLUME PUSH CONTINUATION"
// Sustained, one-directional tick-volume conviction across several bars - no sweep, no
// reversal pattern needed, just sustained real pressure in one direction.
input bool              EnableVolumePush             = true;
input ENUM_TIMEFRAMES   VolumePushTF                 = PERIOD_M15;
input int               VolumePushLookbackBars       = 3;

input group "111 — VWAP BOUNCE (VOLUME-WEIGHTED AVERAGE PRICE)"
// Unlike a plain moving average, VWAP weighs price by VOLUME - one of the most-watched
// levels for institutional participants. Price holding above/below VWAP, or bouncing off
// it, is a genuinely different dimension than a simple MA (which ignores volume entirely).
input bool              EnableVWAPBounce             = true;
input ENUM_TIMEFRAMES   VWAPTF                       = PERIOD_M15;
input int               VWAPLookbackBars             = 48;    // ~ one session on M15; resets the VWAP window
input int               VWAPTolerancePoints          = 150;

input group "112 — TREND CONTINUATION ZONE CAUTION"
// Real gap found via live testing: 11 of 12 trend-continuation detectors (Trend Ride, MA
// Bounce, Donchian, Consecutive Candles, DXY, Expanding Vol, MTF Unanimous, EQ Zone,
// Volume Push, VWAP, Swing Continuation) never check Zone Map - a SELL could fire right
// INTO a strong historical support level purely because the local trend looks strong. This
// applies a universal penalty to ANY continuation-type entry that's heading straight into a
// strong opposing zone, regardless of which specific detector fired.
input bool              EnableTrendContinuationZoneCaution = true;
input int               TrendContinuationZoneCautionPoints = 600;   // How close the opposing zone must be to trigger caution (widened from 250 - that was only $2.50, smaller than a typical single candle move)
input double            TrendContinuationZoneCautionMinStrength = 1.5;
input int               TrendContinuationZoneCautionPenalty = 3;
input bool              EnableReversalTypeZoneCaution = true;  // V31.6z50: confirmed root cause of "BUY at resistance / SELL at support" - reversal types were EXEMPT from this check on the assumption they police their own zones, but an audit found Sweep and Range-Edge check NO zone at all, and none of the others check the OPPOSING one. A bounce bet with a wall right in front is just as bad as a breakout into one.
input bool              EnableEntryFarZoneAwareness  = true;   // V31.6z29 NEW: catches "broke a LOCAL high but still under a major ceiling" - the 600pt check alone missed levels further out
input int               EntryFarZoneCautionPoints    = 3000;   // Narrower than Grid's far check (6000) - a fresh entry commits less than an averaging-down grid addition, so a moderate look-ahead is enough
input double            EntryFarZoneMinStrength      = 2.5;    // Only genuinely major levels matter at this distance

// FIX(zone-wall-hardblock): the caution above only ever applied a -penalty. With MinScore as
// low as 4-6, a strong signal could absorb the penalty and STILL fire - which is exactly the
// screenshot case: a SELL opened right on a strong support wall and price rocketed up. A penalty
// is right for a "moderate wall / decent distance" situation, but a VERY strong wall sitting
// VERY close in front of the trade is not a "score it lower" case - it's a "do not take this
// trade" case. This adds a true HARD BLOCK for that extreme, unambiguous situation only. It sits
// ON TOP of the penalty system (does not replace it) and is deliberately stricter than the
// caution thresholds so it fires only on the genuinely dangerous setups.
input bool              EnableZoneWallHardBlock      = false;                                   // V55b: OFF. Its rule now lives in CounterContextBlockNow() with identical thresholds (250pt / strength 2.5), where BOTH the score engine and the queue-replay guard evaluate it. Leaving this one on as well would apply the same veto twice, and only the score-engine path - a queued signal would still have skipped it.
input int               ZoneWallHardBlockPoints      = 250;    // Opposing wall must be at least this CLOSE (points) to hard-block. Tighter than the 600pt caution - only an imminent wall blocks
input double            ZoneWallHardBlockMinStrength = 2.5;    // V33b: raised 2.2 -> 2.5. With PDH/PDL now added as strong levels, 2.2 was reached too often and blocked too much. 2.5 reserves the hard block for genuinely major, multi-touch walls, keeping the bot active near ordinary daily levels.
input bool              ZoneWallHardBlockPrintOnUse  = true;

// FEATURE(counter-zone-firstentry): variant B - a dedicated hard block for the exact failure the
// user hit: a first entry opened straight INTO a strong zone it should bounce off (a SELL sitting
// on support, or a BUY under resistance). The existing zone-wall block was tuned conservative
// (str 2.5 / 250pt) to avoid making the bot sluggish, so it let this through. This block is
// FIRST-ENTRY ONLY (grid is unaffected) and specifically targets counter-zone entries: SELL when
// strong SUPPORT is close below (price is likely to bounce UP), BUY when strong RESISTANCE is
// close above (price is likely to drop). It is intentionally wider/looser than the zone-wall
// block because opening a fresh basket against a defended level is the single worst entry type.
input bool   EnableCounterZoneFirstEntryBlock = true;   // Hard-block a FIRST entry opened into a strong zone it should bounce off
input int    CounterZoneBlockPoints        = 3500;      // V70b: 250 -> 3500 ($3.5) after a live loss. At 250 ($0.25) a first entry was blocked only if price was almost ON the level, so a BUY ~$1 under a strong 4104 resistance sailed through and price rejected straight down for a ~50% basket loss. XAUUSD moves $70-80/day and rejects from resistance $1-4 out, so the block must trigger while there is still room. Paired with the strength floor so only genuine levels veto.
input double CounterZoneBlockMinStrength   = 1.4;   // V200: 1.8 -> 1.4. Zone strength is 1.0 + touches x 0.25, so 1.8 needed four touches before the protection engaged - and a level tested three times is exactly the kind that turns price back. Your losing entries were into two- and three-touch zones scoring 1.50-1.75, sitting just under the threshold. At 1.4 a three-touch level is protected; a single untested swing at 1.25 still is not.      // V70b: 2.5 -> 1.8. Strength = 1.0 + touches*weight + confirmations, so 2.5 needed a heavily re-tested level and let fresh-but-real resistance through. 1.8 catches a level with a couple of touches/confirmations - the wall price rejects from - without blocking trivial zones.
input int    ZoneNearAboveTolerance      = 900;    // V243: how far ($0.90) past the current price a swing can sit and still count as the level in front of it. A support price has just risen through is still that support - discarding it made a shelf read as a single point further down, which is how a sell went in at 4485.10 with the band running to 4486.

// V205: the level behind the level. The zone map reports the nearest one - correct for where price
// goes first, wrong for whether the trade has room. Price that fell to a deep support, bounced, and
// now sits above a shallower one shows plenty of space beneath that shallow level, while the level
// that actually turned price sits just under it, unseen. The distance that matters is to the level
// that will HOLD, not the first one price meets.
input bool   EnableSecondLevelCheck      = true;   // Look past the nearest level to what is behind it
input int    ZoneNextLevelGapPoints      = 300;    // Separation ($0.30) before a level counts as a distinct one rather than part of the same zone
input double SecondLevelStrengthEdge     = 0.4;    // How much stronger the level behind must be before it changes the picture
input int    SecondLevelMaxGapPoints     = 4000;   // Gap ($4.00) within which the level behind is reachable in the same move
input int    SecondLevelReachPoints      = 8000;   // Distance ($8.00) within which it is close enough to matter to this trade at all
input int    SecondLevelPenalty          = 4;      // Score cost of trading toward a level whose real barrier sits just behind the visible one
input bool   SecondLevelPrintOnUse       = true;   // Log when a hidden stronger level is found
input bool   CounterZoneBlockPrintOnUse    = true;

// FEATURE(htf-against-firstentry): variant B for "the bot opens SELL against a BUY market and sits
// in DD". Until now a first entry fighting the higher-timeframe trend only lost a couple of score
// points and some lot size - never blocked - so a strong counter-trend signal still fired. This
// HARD-BLOCKS a first entry taken against a STRONG global trend... UNLESS it is a genuinely strong
// reversal (a full multi-signal consensus). That exception is the whole point: we still want to
// catch real turns, we just refuse weak/ordinary entries that fight a firm trend. First-entry only.
input bool   EnableHTFAgainstFirstEntryBlock = true;   // Hard-block a first entry fighting a strong global trend
input double HTFAgainstBlockMinConfidence   = 0.60;    // V100b: 0.40 -> 0.60 for scalping. With a ~$2-3 TP, a normal D1/H4 trend shouldn't veto a counter-direction scalp - inside an uptrend there are still plenty of small down-scalps. At 0.60 (needs ADX ~32 across D1/H4/H1) only a GENUINELY strong global counter-trend blocks the entry; ordinary trends leave scalps free. The counter-impulse and ghost blocks (which scalping genuinely needs) are separate and unaffected.
input double HTFAgainstReversalOverride     = 0.82;    // V50b: lowered 0.90 -> 0.82. Demanding 3+ reversal signals to trade against a trend was so rare it never fired; 0.82 (2 independent signals) still means a confirmed turn, not a guess.
input int    HTFAgainstScorePenalty      = 4;      // V189: score cost of a first entry against a confident higher-timeframe trend. This was a hard block until a live A+ setup scoring 11 against a bar of 4 was refused by it - the observation was right, the mechanism was not.

input group "123 — GLOBAL VS LOCAL TREND ALIGNMENT"
// Direct user request: distinguish "what is the BIG PICTURE doing" (H4/D1) from "what is
// happening RIGHT NOW" (M15/local) - trading as much as possible WITH the global trend is
// exactly what shortens DD duration, since an aligned basket has real structural odds of
// being pulled back to break-even even after an adverse local move, while one fighting the
// bigger picture has no underlying current working in its favor.
input bool              EnableGlobalLocalTrendSplit  = true;
input int               GlobalTrendADXPeriod         = 14;
input double            GlobalTrendMinADX            = 20.0;
input double            GlobalTrendADXFullStrength   = 20.0;  // V96b: 35 -> 20. mag=1 now needs ADX ~40 (MinADX 20 + 20). The slower D1/H4/H1 rarely push ADX to the old ~55 that FullStrength 35 implied, so strong global trends were badly under-rated (ADX 30 gave only ~0.29). 20 keeps it reachable while still separating weak from strong.// V31.6z31 NEW: ADX at/above this counts as FULL magnitude (1.0) for the global confidence blend - between MinADX and here scales linearly
input int               GlobalTrendH4LookbackBars    = 12;    // ~2 days of H4 bars
input int               GlobalTrendH1LookbackBars    = 24;    // V31.6z56 NEW: H1 was completely absent from the global read - this is the bridge between the big picture and the local M15 view
input double            GlobalTrendWeightD1          = 3.0;   // V31.6z56: D1 is the biggest, most persistent picture - previously it carried only 1 of 3 votes while H4 carried 2
input double            GlobalTrendWeightH4          = 2.0;   // Main swing structure
input double            GlobalTrendWeightH1          = 1.0;   // Bridge to the local read - lightest of the three "global" timeframes
input double            GlobalTrendWeakConfirmValue  = 0.30;  // Capped confidence when a timeframe's ADX doesn't qualify and the close-comparison fallback is used instead
// FIX(global-notrend-floor): GlobalTFConfidence() used to borrow LocalTrendNoTrendADX (14.0) as its
// own "genuine range, suppress the fallback" floor. That value was tuned for M15-scale ADX; D1/H4/H1
// ADX moves much slower and sits above 14 far more easily even in a real range, so the global range
// floor was effectively toothless - a daily/4h/1h range could still leak a spurious directional bias
// through the close-comparison fallback. Global timeframes now get their own floor, tuned separately.
input double            GlobalTrendNoTrendADX        = 16.0;   // Below this ADX on a global (D1/H4/H1) TF = no trend at all (range); return 0 rather than a weak direction
input ENUM_TIMEFRAMES   LocalTrendTF                 = PERIOD_M15;
input int               LocalTrendADXPeriod          = 14;
input double            LocalTrendMinADX             = 18.0;   // ADX at/above which the local read is treated as a real (ADX-graded) trend

// FEATURE(local-trend-range-floor): below MinADX the code falls back to a simple direction read and
// reports a weak trend - but a genuine RANGE (very low ADX, price chopping sideways) would still be
// labelled a weak up/down trend, inviting trend-following entries into a range. Add a hard floor:
// when ADX is below this, there is effectively NO trend, so local confidence is 0 regardless of which
// way the last few closes happened to lean. Between the floor and MinADX it stays a weak read.
input double            LocalTrendNoTrendADX         = 14.0;   // Below this ADX = no local trend at all (range); return 0 rather than a weak direction

// FEATURE(local-trend-momentum): direction+strength alone can't tell a trend that is BUILDING (ADX
// rising) from one that is FADING (ADX falling) - both read as e.g. "ADX 30, strong". A fading trend
// is where reversals happen, so trading it like a healthy trend is a classic late entry. Compare ADX
// now vs a few bars back: if it has dropped meaningfully, the trend is losing steam - trim the local
// confidence and raise a "fading" flag for caution. We do NOT reward a building trend (asymmetric):
// caution on the way down is protective, extra conviction on the way up is not needed.
input bool              EnableLocalTrendMomentum      = true;  // Detect a fading local trend via ADX slope and treat it with caution
input int               LocalTrendADXSlopeBars        = 3;     // How many bars back to compare ADX against for the slope
input double            LocalTrendADXFadeDelta        = 2.0;   // ADX must have dropped at least this much to count as "fading" (filters noise)
input double            LocalTrendFadeDampen          = 0.65;  // When fading, multiply local confidence by this (0.65 = trim ~a third)
input int               LocalTrendFadePenalty         = 2;     // Small score penalty on a first entry while the local trend is fading (caution, not a block)

// FEATURE(global-htf-bind): DeepHTFTrendDirection() - the trend direction the dashboard shows and the
// HTF-against block relies on - historically read a SINGLE timeframe (H1 MA / Kalman). So a brief H1
// pullback inside a larger D1/H4 downtrend could report "up", and the HTF guard would then protect
// the WRONG side. Bind the final HTF direction to the full weighted global read (D1/H4/H1): H1 gives
// the responsive read, but if the weighted global trend is confident and DISAGREES with H1, global
// wins (H1 is treated as a pullback, not the trend). If global is only mild, the H1 read stands.
input bool              EnableGlobalHTFBind          = true;   // Bind HTF direction to the weighted D1/H4/H1 global read, not H1 alone
input double            GlobalHTFBindMinConfidence   = 0.35;   // Weighted global confidence needed for global to overrule the single-TF H1 direction

// FEATURE(global-trend-momentum): the mirror of the local momentum/turning work, for the big picture.
// A fading GLOBAL trend (D1 ADX rolling over) precedes the large reversals that hurt a martingale
// most, and a just-turned D1/H4 is where the bot can get stuck trading the old macro direction. Give
// global its own fade + turning reads, measured on the primary global TF (D1) with slower settings
// than local, since D1 bars are days. Same asymmetric treatment: caution when weakening, no bonus.
input bool              EnableGlobalTrendMomentum    = true;   // Detect a fading global trend via D1 ADX slope
input ENUM_TIMEFRAMES   GlobalTrendPrimaryTF         = PERIOD_D1;  // The TF the global fade/turning reads are measured on
input int               GlobalTrendADXSlopeBars      = 2;      // Bars back to compare global ADX against (D1 bars = days, so keep small)
input double            GlobalTrendADXFadeDelta      = 2.0;    // Global ADX must have dropped at least this much to count as fading
input double            GlobalTrendFadeDampen        = 0.70;   // When global fading, multiply global confidence by this
input bool              EnableGlobalTrendTurning     = true;   // Detect a just-started global flip via a fast/slow window split on the primary global TF
input int               GlobalTrendFastLookbackBars  = 3;      // Fast window (bars) for the recent global direction
input double            GlobalTrendTurningDampen     = 0.60;   // When global turning, multiply global confidence by this
input int               GlobalTrendFadePenalty       = 3;      // Score penalty on a first entry while the global trend is fading (bigger than local: macro reversal risk)
input int               GlobalTrendTurningPenalty    = 3;      // Score penalty on a first entry while the global trend is turning
input double            LocalTrendADXFullStrength    = 17.0;  // V96b: 30 -> 17. mag=1 now needs ADX ~35 (MinADX 18 + 17), a level a real strong XAUUSD M15 trend actually reaches. At 30 it needed ADX ~48 which M15 rarely hits, so genuine strong trends were rated only ~0.55 mag and under-drove the trend guards.// V31.6z31 NEW: same magnitude-scaling concept, for the local read
input int               LocalTrendLookbackBars       = 8;
input bool              EnableLocalTrendM5           = true;  // V31.6z57: M5 sits between the M1 signal TF and the M15 local read but was in NO trend check - a structural blind spot right next to where signals fire
input int               LocalTrendM5LookbackBars     = 12;
input double            LocalTrendWeightM5           = 1.0;   // Lightest - M5 is the noisiest of the three and shouldn't dominate
input double            LocalTrendWeightMain         = 2.0;   // LocalTrendTF (M15) stays the primary local read
input bool              EnableLocalTrendM30          = true;  // V31.6z57: M30 appeared NOWHERE outside the Zone Map - the natural bridge from M15 up to the H1 global read was entirely missing
input int               LocalTrendM30LookbackBars    = 8;
input double            LocalTrendWeightM30          = 1.5;   // Between M5 and M15 in weight - slower, so less noisy than M5
input double            LocalTrendWeakConfirmValue   = 0.30;    // V31.6z31 NEW: capped confidence when local ADX doesn't qualify and we fall back to a simple close-comparison - deliberately weak, not treated the same as an ADX-confirmed local move

// FEATURE(simple-trend-structure): the fallback trend read (used when ADX doesn't qualify) compared
// only close[1] vs close[lookback] - two points, blind to the shape between them. One big candle
// could flip it, and a choppy range that happens to end higher reads as "uptrend". Upgrade it to
// agree across three cheap checks: the net close move, the slope of the window, and market structure
// (higher-highs/higher-lows vs lower-highs/lower-lows). All three must agree for a direction; if they
// disagree the tape is unclear and it returns 0 (no false trend). Keeps the +1/-1/0 interface.
input bool              EnableStructureTrend         = true;   // Use net+slope+structure agreement instead of a bare 2-point close compare
input int               StructureTrendMinAgree       = 2;      // How many of the 3 checks (net, slope, structure) must agree (2 = majority, 3 = unanimous/strict)

// FEATURE(local-trend-turning): the local trend read uses an 8-bar window, so when the trend has
// only just flipped (e.g. M15 turned up->down 3 bars ago) the older bars still dominate and the read
// lags - the bot keeps trading the OLD direction into the new move. Add a fast window (default 4
// bars) alongside the main one: when fast and main DISAGREE, the local trend is turning, so we raise
// a "turning" flag (caution) and soften the confidence rather than reporting a confident stale trend.
input bool              EnableLocalTrendTurning      = true;   // Detect a just-started local trend flip via a fast/slow window split
input int               LocalTrendFastLookbackBars   = 4;      // Fast window (bars) for the recent local direction; compared against the main window
input double            LocalTrendTurningDampen      = 0.50;   // When turning, multiply local confidence by this (0.50 = halve it) so a stale trend can't drive full-size decisions
input int               LocalTrendTurningPenalty     = 2;      // Small score penalty on a first entry while the local trend is mid-flip (caution, not a block)
input double            GlobalLocalWeightGlobal      = 0.35;  // V100b: 0.65 -> 0.35. This EA scalps XAUUSD with a ~$2-3 TP, an M1/M5 event; the D1/H4/H1 global trend barely moves at that scale, so LOCAL should dominate the alignment. Global stays at 0.35 as a context/safety layer - still matters when a basket deepens or a big global reversal is underway, but no longer overrides the local read that governs a 2-3 dollar scalp.
input double            GlobalLocalWeightLocal       = 0.65;  // V100b: 0.35 -> 0.65. Local (M5/M15/M30) now leads, matching the scalping timeframe.

// FEATURE(adaptive-alignment-weight): a 1-order scalp is a pure M1/M5 event, so local should lead.
// But as the grid deepens (5-7 orders) the position is no longer a small scalp - it is a large,
// losing basket where a big GLOBAL reversal is the real threat, exactly the -1458 screenshot. So
// shift the alignment weighting from local-led toward global-led as the order count rises. At 1 order
// it uses the scalping weights above; by MaxOrders it reaches the deep-basket weights below. This
// keeps scalps free while restoring global protection precisely when the basket becomes dangerous.
input bool              EnableAdaptiveAlignWeight    = true;   // Shift alignment toward global as the basket deepens
input double            DeepBasketWeightGlobal       = 0.65;   // Global weight when the basket is at/near MaxOrders (mirrors the scalp weights, flipped)
input int               AdaptiveAlignFullShiftOrders = 5;      // V249fix: 6 -> 5, to track MaxOrders. At 6 with MaxOrders 5 the basket could never reach the "full shift" point, so the deep-basket global-trend weighting topped out at 80% of its configured value exactly when the basket was at its most dangerous - the opposite of what this feature is for. Keep this equal to MaxOrders.   // Order count at which the deep-basket weighting is fully reached
input double            GlobalLocalPullbackGlobalMin = 0.40;  // V31.6z31 NEW: global confidence must be at least this to even consider the "pullback vs reversal" adjustment
input double            GlobalLocalPullbackLocalMin  = 0.40;  // Local opposition must exceed this before the non-linear taper starts
input double            GlobalLocalPullbackTaperRate = 0.55;  // How aggressively the score tapers down as local opposition strengthens beyond the minimum
input int               GlobalLocalScoreBonus        = 3;     // First Entry bonus/penalty magnitude when alignment is strongly favorable/unfavorable
input bool              GlobalLocalPrintOnUse        = true;

input group "124 — REVERSAL CONSENSUS (UNIFIED)"
// Direct user feedback: Sense 1 (heaviest-weighted throughout) only ever used swing+RSI to
// detect a reversal, never combined with BOS/CHoCH, Major Sweep, or Engulfing - three more
// genuinely independent reversal confirmations built later the same session.
input bool              EnableReversalConsensus      = true;
input double            ReversalConsensus1Score      = 0.68;  // Score when exactly 1 independent signal confirms
input double            ReversalConsensus2Score      = 0.82;  // 2 signals - disproportionately higher, not just additive
input double            ReversalConsensus3Score      = 0.92;  // 3+ signals - very high confidence
input double            ReversalConsensusExtraStep   = 0.03;  // Additional increment per confirmation beyond 3

input group "112b — ZONE RETEST (WAS ORPHANED - NEVER WIRED IN)"
// V31.6z43 fix: OPP_TYPE_ZONE_RETEST, its string mapping, and both detector functions were
// fully built and well-designed (confirms a genuine polarity flip via ZoneMapIsPolarityFlip,
// then requires an actual touch-and-bounce, not just proximity) - but never wired into either
// scanner, AND these 4 required inputs were never declared at all (would have failed to
// compile the moment anyone tried to actually enable it). Both gaps fixed together.
input bool   EnableZoneRetestTrigger      = true;
input double ZoneRetestMaxDistancePoints  = 1500;   // V76b: 400 -> 1500 ($1.5). How close CURRENT price must be to the flipped level to count as still retesting it. At 400 ($0.40) a genuine retest bounce was only valid while price sat almost exactly on the level; once it recovered even $0.50 (normal for a support-flip bounce) the entry was missed. The actual touch is still confirmed separately by ZoneRetestTouchTolerancePoints ($0.15) over the recent window, so widening this only lets the bounce register after price lifts off - it does not loosen what counts as a touch. Matches NearZoneReactionRangePoints for consistency.
input double ZoneRetestTouchTolerancePoints = 150;  // How close the low/high must come to the exact level to count as a genuine touch
input double ZoneRetestMinStrength        = 1.5;    // Zone strength bonus threshold (score +2 above this)
input int    ZoneRetestConfirmWindowBars  = 3;       // V31.6z44 NEW: real gap found - only checked the single most recent bar for a touch, missing a retest that happened a bar or two ago with recovery since
input double ZoneRetestMinWickRatio       = 0.35;    // Rejection wick (vs candle range) needed to count as a "quality" bounce rather than just a plain green/red close

input group "113 — IMPULSE CONFIRMATION"
// None of the 13 trend-continuation tools sense a genuine, sharp impulse candle at all - a
// real gap since a single decisive burst (unusually large range/body vs recent ATR) is
// strong, direct evidence of conviction, distinct from slower measures like ADX or MA order.
input bool              EnableImpulseConfirmation    = true;
input ENUM_TIMEFRAMES   ImpulseTF                    = PERIOD_M15;
input int               ImpulsePeriod                = 14;
input int               ImpulseLookbackBars          = 4;
input double            ImpulseMinBodyRatio          = 0.6;   // Candle body must be at least this fraction of its range to count as a real impulse, not just a long-wicked chop bar
input double            ImpulseMinATRMultiple        = 1.5;   // Candle range must be at least this multiple of ATR to qualify as an impulse
input bool              EnableMoveExtension          = true;  // V31.6z53: fixes a real, user-reported danger - Impulse Confirmation rewarded candle SIZE with no regard for WHERE in the move it happened, so a blow-off climax at the top of an extended rally earned the HIGHEST buy confidence (the classic false-breakout trap)
input ENUM_TIMEFRAMES   MoveExtensionTF              = PERIOD_M15;  // V237: H1 -> M15. From two live stop-outs: a buy at the top of a $24 run and a sell at the bottom of a $99 decline, both taken because this check read 0.53 ATR where the move was plainly finished. The comment below records the original problem correctly - H1 legs against an H1 ATR over a five-day window pinned the block on permanently - but the fix chosen was to widen the ATR rather than narrow the window, which silenced the check for the scale actually being traded. Setups here are built on M5 zones with $2.50 targets; a $24 move is the whole trade, and on H1 it is one candle.
input ENUM_TIMEFRAMES   MoveExtensionATRTF           = PERIOD_M15;  // V237: D1 -> M15. The move and the ATR it is measured against must be on the same scale or the ratio is meaningless - $24 against a $45 daily ATR reads as 0.53, against the $1.80 M15 ATR it reads as 13. What made the old H1/H1 pairing misfire was the LOOKBACK spanning five days, not the ATR timeframe; that is corrected below.
input int               MoveExtensionATRPeriod       = 14;    // ATR period on MoveExtensionTF - must be the same TF as the origin search so the ATR-multiple units stay coherent
input int               MoveExtensionLookbackBars    = 60;   // V237: 120 -> 60. This is the other half of the same fix. The window has to span a period the ATR can describe: 120 H1 bars is five days, and a five-day move against an hourly ATR is enormous by construction, which is what pinned the old block on. Sixty M15 bars is fifteen hours - long enough to hold a full session's move, short enough that the M15 ATR is the right unit for it.   // V122: 100 -> 120. On H1 that is 5 DAYS, so a trend that has been running most of a week is still measured from its real start rather than from wherever the window happened to begin.
input double            MoveExtensionResetPercent    = 50.0;   // V122: a correction retracing this much of the leg means the old move ended and a new one started - the extension is then measured from the correction's turning point, not the original extreme. Without this, a fresh rally after a real pullback still reads as an exhausted multi-day trend and gets blocked. Lower = resets more easily, higher = keeps counting the older move.   // V31.6z55: raised from 40. On the H1 default this reaches ~4 days, enough to actually locate a long trend's origin
input double            MoveExtensionMatureATR       = 1.2;    // V121: 3.0 -> 1.2. Measured in D1 ATR units (~$25 on XAUUSD), so the old 3.0 meant a move had to run $75 - an ENTIRE day's range - before the late-entry penalty even began, and the climax/hard-block levels above it were effectively unreachable. The trend-chasing protection was dead. At 1.2 (~$30) caution starts where a move is genuinely extended for a scalper whose target is $2.50.   // Extension (in ATR) beyond which the impulse bonus starts tapering toward neutral
input double            MoveExtensionClimaxATR       = 2.4;    // V121: 6.0 -> 2.4 (~$60). Full late-entry penalty by here - a move this far into its run is far more likely to retrace into the basket than to extend again.   // Extension beyond which a large impulse candle is treated as a CLIMAX warning, not confirmation
input double            MoveExtensionClimaxScore     = 0.25;  // Score returned in the climax case - deliberately below neutral: at this point the impulse argues AGAINST joining, not for it
input bool              EnableStandaloneMoveExtension = true; // V31.6z54: the extension check above only ran when a big impulse candle qualified - but a long, grinding trend needs no dramatic candle, so an entry at the exhausted extreme of a multi-day move went completely unflagged
input int               StandaloneMoveExtensionMaxPenalty = 5;  // V121: 3 -> 5. Entering at the end of an extended trend is one of the most expensive mistakes this EA makes (it opens at the worst price and the retrace becomes deep DD), so it deserves more than a nudge. // Penalty at full climax extension, scaling up from zero at MoveExtensionMatureATR
input int               ImpulseScoreBonus            = 2;
input bool              ImpulsePrintOnUse            = true;

// FEATURE(impulse-end-hardblock): direct user request - "if the impulse is SELL, do NOT open
// another SELL at the very bottom; if BUY, do NOT open another BUY at the very top". The
// existing MoveExtension / ImpulseConfirmation logic above only ever applied a -penalty, which
// a strong signal can out-score at the low MinScore thresholds, so a late continuation entry
// into an exhausted move could STILL fire. This is a true HARD BLOCK for that exact case:
// entering in the SAME direction as a move that has already run to a climax extension. It sits
// on top of the penalty system (does not replace it) and reuses the same MoveExtensionATR
// measurement already trusted above, so there's one coherent definition of "the move's end".
input bool              EnableImpulseEndHardBlock    = false;  // V186: hard blok -> jazo. impuls oxirida kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input double            ImpulseEndHardBlockATR       = 3.2;    // V121: 7.0 -> 3.2 (~$80). Hard refusal once a move has run more than a full day's range in one direction - chasing it there is not a scalp, it is buying the top.    // V36b: lowered 9.0 -> 7.0. Climax is defined at 6 ATR (MoveExtensionClimaxATR) but the hard block only fired at 9, leaving a 6-9 ATR gap where entries into an already-exhausted move slipped through. 7 closes most of that gap while still allowing a genuinely strong trend a little room past climax.
input bool              ImpulseEndHardBlockRespectTrend = true; // If the move is extended BUT the global trend still strongly agrees with our direction, this is trend continuation, NOT exhaustion - so do not hard-block. Only blocks an extended move that has LOST its trend backing.
input double            ImpulseEndHardBlockTrendConf = 0.40;                                    // V55b: 0.65 -> 0.40. GlobalTrendConfidence is (ADX-20)/35 averaged over D1/H4/H1, so it realistically tops out near 0.6; 0.65 needed ADX ~43 on all three at once and therefore almost never fired. The whole point of this input is to let a strong trend continue past an extended move - at 0.65 that exception was dead and the block vetoed trend continuation too.
input bool              EnableImpulseAgainstHardBlock = false; // impulse-AGAINST fires on ANY strong opposite candle, which precedes good support-bounce / resistance-bounce entries - vetoing those made the bot timid. Off by default; still costs score points via the penalty.

// FEATURE(collapse-bottom-guard): the mirror of the resistance-BUY problem. When price has fallen
// hard and fast over the last few bars, opening a SELL at the BOTTOM of that drop (continuing the
// move) is entering right where a snap-back is most likely - which is exactly how a SELL got caught
// on the $61 M15 drop that then reversed. This is SPEED-based, not the 7-ATR climax test: a $61
// (2.4 ATR) drop never reached the climax threshold, so nothing blocked it. Measures the recent
// swing over a short window; if the drop/rise exceeds the threshold, entries CONTINUING the move
// are blocked (SELL at the bottom of a fast drop, BUY at the top of a fast rise). 3-digit: 1000pt=$1.
input bool              EnableCollapseBottomGuard    = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES   CollapseGuardTF              = PERIOD_M15; // Timeframe the recent swing is measured on
input int               CollapseGuardLookbackBars    = 8;      // How many bars back to measure the move (8 x M15 = 2 hours)
input int               CollapseGuardMinPoints       = 25000;  // V73b: 15000 -> 25000 ($25) on user request. XAUUSD moves $70-80/day, so $15 over 2 hours was only ~20% of a normal day and fired too readily. $25 in 2 hours is a genuinely sharp move (a third of a day's range).
input bool              CollapseGuardHardBlock       = false;  // V186: hard blok -> jazo. kollaps ostida kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // true = hard-block the continuation entry; false = penalty only
input int               CollapseGuardScorePenalty    = 4;      // Score penalty when not hard-blocking
// Second, LONGER window so a slow but sustained collapse (e.g. price sliding down all day from the
// 09:30 high) is caught too - the short window above only sees a fast drop and would miss a gentle
// multi-hour decline. Either window triggering is enough. 3-digit: 1000pt = $1.
input int               CollapseGuardLongLookbackBars = 32;     // Longer window (32 x M15 = 8 hours) for a sustained, day-long move
input int               CollapseGuardLongMinPoints    = 45000;  // V73b: 30000 -> 45000 ($45) on user request. Over the 8-hour window this is a strong sustained trend (~60% of a day) - it comfortably catches the live "$61 slide from the 09:30 high" case while letting ordinary intraday swings through.

// FEATURE(blowoff-hardblock): the single most dangerous entry in a fast market - jumping in the
// SAME direction as a huge climactic "blow-off" candle that just printed. MoveExtensionATR
// measures how far the whole move has run, but it can miss a violent single-bar spike that
// hasn't yet accumulated many ATRs of total travel. This checks the raw candle: if the signal
// bar (or the one before it) is a giant bar in our intended direction - range >= X * ATR - we
// are trying to buy the very top / sell the very bottom of a spike, so hard-block it. Opposite
// (reversal / bounce) entries are never touched; only same-direction continuation into the spike.
input bool              EnableBlowOffHardBlock       = false;  // V186: hard blok -> jazo. blow-off shamdan keyin - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input double            BlowOffCandleATRMult         = 2.5;    // A bar whose range >= this * ATR counts as a blow-off climax candle
input int               BlowOffLookbackBars          = 2;      // Check the last N closed bars for a blow-off in our direction (1 = only the most recent)
input bool              BlowOffHardBlockPrintOnUse   = true;
input bool              ImpulseEndHardBlockPrintOnUse = true;

input group "114 — COMPETING REVERSAL SIGNAL CAUTION"
// Trend Reversal (swing/RSI-based) already applies universally, but our 5 dedicated
// reversal-PATTERN detectors (Sweep, FBR, Near-Zone, Exhaustion, Range Edge) only ever get
// checked as candidates for winning the scanner - if a continuation entry wins instead, any
// of these 5 firing in the OPPOSITE direction is silently discarded. This re-checks them
// specifically as a caution signal when taking a continuation-type entry.
input bool              EnableCompetingReversalCaution = true;
input int               CompetingReversalMinScore    = 3;      // Minimum score the competing reversal detector must show to count
input int               CompetingReversalPenalty     = 2;

input group "115 — RECENT ZONE BREAK (PREMIUM)"
// Zone Polarity Flip already exists but lives quietly INSIDE ZoneMapStrength as a background
// nudge - never its own visible signal. This gives a FRESH, confirmed zone break (price
// closing decisively through a strong level) its own prominent, standalone weight - same
// "recent event" pattern as Major Sweep and Engulfing, applied universally to entries.
input bool              EnableRecentZoneBreak        = true;
input ENUM_TIMEFRAMES   ZoneBreakTF                  = PERIOD_M15;  // V110: the break scan used to run on SignalTF (M1), so even 30 bars only remembered a break for 30 MINUTES. Live chart: price broke upward and ran ~$160 over TWO DAYS, and the bot was still selling into it because the break had long since dropped out of view. Measuring on M15 puts the scan on a structural scale while staying precise enough to catch the breaking candle.
input int               ZoneBreakLookbackBars        = 96;    // V110: 30 -> 96, now measured on ZoneBreakTF. 96 x M15 = 24 HOURS of break memory, so a breakout still counts during the retest that follows it a day later. Raise toward 192 (2 days) if the bot still fades day-old breaks; lower toward 48 (12h) if too many ordinary setups get penalised.
input int               ZoneBreakSearchPoints        = 300;
input double            ZoneBreakMinStrength         = 1.5;
input int               ZoneBreakScoreBonus          = 3;      // Higher than Major Sweep/Engulfing (2) - deliberately "premium" weight
input int               ZoneBreakAgainstPenalty      = 5;      // V108b: separate, LARGER penalty for entering AGAINST a recent break (was reusing the +3 bonus as a -3 penalty). Fading a level that just broke is the live-trading loss this fixes: after an upward break the level is support and buyers are in control, so a SELL there needs to clear a much higher bar than a normal setup.

// ============================================================================
// V110 NEW: MARKET STRUCTURE READER
// ----------------------------------------------------------------------------
// User feedback after live testing: "the robot just follows orders - it should
// watch and analyse the market on its own." The EA already MEASURES a great deal
// (zones, impulses, trend confidence, market state), but every one of those is
// consumed as an isolated bonus/penalty at the moment of entry. Nothing reads the
// market as a SEQUENCE. A trader looking at the chart sees "each level is being
// broken and turning into support, so this leg is still building" - the EA saw
// only "there is a zone here, a break happened here".
//
// This module reads the swing chain itself. Using the swing cache the zone map
// already builds each bar, it takes the last three swing highs and last three
// swing lows and asks four questions:
//     is the newest high above the previous high?      (HH)
//     was that previous high above the one before it?   (HH)
//     is the newest low above the previous low?         (HL)
//     was that previous low above the one before it?    (HL)
// Four "yes" answers = a clean higher-high / higher-low chain = bullish structure.
// Four "no" = lower-high / lower-low = bearish structure. A mix means the market
// is ranging or in transition, and the EA should not pretend to know a direction.
//
// The output is ONE clear reading (direction + how many of the four steps agree),
// not another score fragment - so it can be used as a decisive check rather than
// yet another +/- nudge.
// ============================================================================
input bool              EnableMarketStructure        = true;   // Read the swing chain (HH/HL vs LH/LL) as a single structural reading
input ENUM_TIMEFRAMES   MarketStructureTF            = PERIOD_M15;  // Timeframe the swing chain is read on. M15 is the scalper's structural frame; H1 for a slower, broader read.
input int               MarketStructureMinSteps      = 3;      // How many of the four chain checks must agree before a direction is declared (3 = allow one imperfect step; 4 = only perfect chains)
input int               MarketStructureAgainstPenalty = 4;     // Score penalty for a first entry that fights a confirmed structure
input bool              MarketStructureHardBlock     = false;  // false = penalty only (recommended to start). true = hard-block entries against a confirmed structure.
input bool              MarketStructurePrintOnUse    = false;  // Log the structural reading when it affects a decision
input int               MarketStructureBOSBonus      = 2;      // Bonus for entering in the direction of a structure that just EXTENDED (Break of Structure) - the chain confirmed itself
input bool              MarketStructureCHoCHReleases = true;   // When a CHoCH fires (the chain just broke), stop penalising entries against the old structure. Without this the EA would keep defending a structure that has already failed and would miss every reversal. Highly recommended ON.
input int               MarketStructureCHoCHPenalty  = 3;      // Penalty for entering WITH the old structure right after it broke (CHoCH) - continuing a chain that just failed

// V112: the higher-timeframe frame the trading structure sits inside. Reading only one timeframe was
// the remaining simplification: a bearish M15 chain means "sell" under a bearish H1, but under a
// BULLISH H1 the same chain is just a pullback - and selling into it is exactly the losing entry
// seen in live testing. Reading both and naming the relationship is what a trader does out loud.
input bool              EnableStructureHTF           = true;   // Also read the structure on a higher timeframe and combine the two into one context
input ENUM_TIMEFRAMES   StructureHTF                 = PERIOD_H1;   // The higher frame (H1 for an M15 trading structure; H4 for a slower read)
input int               StructurePullbackFadePenalty = 4;      // Penalty for trading WITH a lower-TF counter-move against the higher frame (i.e. selling a pullback inside an uptrend)
input int               StructureAlignedBonus        = 2;      // Bonus when both frames agree and the entry goes with them

// V116: use the structure reading on the OPEN basket, not just on new entries. Until now every
// structural insight was spent deciding whether to open a trade, while baskets already in drawdown
// rode out the very turn the reader could see. When the structure that supported a basket breaks
// (CHoCH), or the opposing structure extends (BOS against us), the basket is swimming upstream:
// take the smaller bounce that is still on offer instead of waiting for the original target.
input bool              EnableStructureBasketExit    = true;   // Let the structure reading manage OPEN baskets, not just entries
input double            StructureBreakTPFactor       = 0.6;    // When structure turns against the basket, shrink the take-profit to this fraction (0.6 = exit on 60% of the original target). Never goes below BasketTPMinPoints.
input bool              StructureBreakCountsAsExitConfirm = true;  // Count a structural turn against the basket as one SmartEarlyExit confirmation
input bool              StructureBasketExitPrintOnUse = true;  // Log when the structure shortens a basket's target

// V117: consensus. Each reading already speaks for itself; this asks whether they agree. Unanimity
// across independent mechanisms (swings, zone behaviour, indicators) is the strongest signal this EA
// can produce, while a genuine split means the market has no owner yet - the honest response there
// is to wait, not to average the disagreement into a middling score.
input bool              EnableMarketVerdict          = true;   // Measure agreement across the independent direction readings
input int               VerdictMinActiveSources      = 3;      // At least this many readings must have an opinion before a verdict is declared
input double            VerdictTrendMinConfidence    = 0.30;   // Trend confidence needed before global/local trend counts as a vote (below this it abstains)
input int               VerdictStrongAgreeCount      = 4;      // Votes needed to call the consensus STRONG
input int               VerdictStrongBonus           = 3;      // Bonus for entering with a strong consensus
input int               VerdictAgainstPenalty        = 4;      // Penalty for entering against a strong consensus
input int               VerdictSplitPenalty          = 2;      // Penalty for entering while the readings are genuinely split (market without an owner)
input bool              MarketVerdictPrintOnUse      = false;  // Log the verdict each bar

// V118: room to target. Direction is only half the question - the other half is whether there is
// space in front of the entry for the target to be reached. On a ~$2.50 scalp target, opening into
// a wall $1.00 away is opening a trade that structurally cannot finish. The check measures the
// distance to the nearest thing in the way (opposing zone, or the structure's continuation level)
// and compares it against the basket target.
input bool              EnableRoomCheck              = true;   // Require space between entry and the nearest opposing level before taking a trade
input bool              RoomUseStructureLevel        = true;   // Also treat the structure's continuation level as a wall, not just zones
input double            RoomMinFactor                = 1.0;    // Room must be at least this multiple of the basket target (1.0 = at least as much space as the target needs)
input int               RoomTooTightPenalty          = 4;      // Penalty when there is less room than the target requires
input bool              RoomHardBlock                = false;  // V171: true -> false. Room is real, but the contextual TP now shrinks the target toward whatever room exists, so refusing as well means refusing trades the EA had already adapted to. Re-enable if the log shows entries still being taken into walls.
input bool              RoomPrintOnUse               = false;  // Log the room measurement when it affects a decision

// V119: zone role. A level's role is decided purely by whether it sits above or below price, which
// breaks inside a thick band: there the EA sees resistance just above AND support just below, births
// both a buy and a sell signal, and whichever scores higher wins. That is the reported "sell in a buy
// zone, buy in a sell zone" behaviour. Inside a band the role is genuinely undefined - wait for price
// to leave it and show which edge it respects.
input bool              EnableZoneRoleCheck          = true;   // Detect when price is INSIDE a zone band, where support/resistance roles are undefined
input bool              ZoneBandUseM5                = true;   // Cluster M5 swings into bands (small intraday zones)
input bool              ZoneBandUseM15               = true;   // Cluster M15 swings into bands (the scalper's main structural zones)
input bool              ZoneBandUseH1                = true;   // Cluster H1 swings into bands (the big levels drawn on a chart)
input double            ZoneBandATRMult              = 0.60;   // Band thickness is derived from each timeframe's OWN ATR x this, not a fixed dollar amount - small zones and large zones both exist, so the market sizes them. Raise for looser grouping (thicker bands), lower for tighter.
input int               ZoneBandMinTolerancePoints   = 600;    // Floor for the ATR-derived tolerance ($0.60) so a dead session can't collapse every band to a point
input int               ZoneBandMaxTolerancePoints   = 9000;   // Ceiling for it ($9.00) so a volatility spike can't merge the whole chart into one band
input int               ZoneBandSearchPoints         = 20000;  // Only consider swings within this distance of price ($20) when looking for a band
input int               ZoneBandMinTouches           = 3;      // A band must contain at least this many swings - two stray points are not a zone
input int               ZoneRoleAmbiguityPenalty     = 5;      // Penalty for entering while the role is undefined
input bool              ZoneRoleHardBlock            = false;  // V193: oxirgi blok ham jazoga. Har skrinshotda BOSHQA sabab chiqdi - ya'ni to'siqlar ketma-ket joylashgan va bittasini tuzatgach keyingisi ushlaydi. Bu bloklarni bittalab ochish bilan hal bo'lmaydi: hammasi bir vaqtda jazoga o'tishi kerak, keyin jonli natija qaysi biri haqiqatan kerakligini ko'rsatadi. CounterZone yagona istisno - u o'lchangan zararni to'sadi.

input bool   CounterZoneHardBlock            = true;   // V191: qayta BLOK. Bu yagona filtr bo'lib, u JONLI o'lchangan zararni to'sadi - sizning -819.90 zararingiz aynan shu naqsh edi (SELL support ustida). Boshqa bloklar nazariy asosga ega, bu esa haqiqiy hisobdagi pulga. Chegaralari qattiq ($3.50 masofa, kuchlilik >=1.8), ya'ni u kamdan-kam ishlaydi va savdo chastotasiga sezilarli ta'sir qilmaydi.
input int    CounterZoneScorePenalty         = 5;   // V190: kuchli zonaga qarshi kirish jazosi - sifat guruhiga boradi
input bool   RangeBreakoutHardBlock          = false;   // V190: tasdiqlangan breakoutni so'ndirish - jazo rejimi
input int    RangeBreakoutFadePenalty        = 4;   // V190: breakoutga qarshi kirish jazosi - trend guruhiga
input bool   FreshImpulseWaitHardBlock       = false;   // V190: yangi impuls kutish - jazo rejimi. Kutish o'zi bloklash, va u impuls yoshiga qarab avtomatik tugaydi.
input int    FreshImpulseWaitPenalty         = 3;   // V190: yangi impulsdan keyin darrov kirish jazosi
input bool              ZoneRolePrintOnUse           = true;   // Log when an entry is refused or penalised for an undefined zone role

// V140: liquidity map. The EA recognises a sweep only after it has happened, which is too late to
// act on. Stops cluster just beyond swing extremes, and most heavily where several swings line up at
// the same level - equal highs are a shelf of buy-stops, equal lows a shelf of sell-stops. Price is
// drawn to those shelves, which is why markets so often run to an obvious high, take it, and turn.
// Knowing the pool is there BEFORE the run means the entry can wait and be taken from the far side
// of it instead of being run over on the way.
input bool              EnableLiquidityMap       = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input ENUM_TIMEFRAMES   LiquidityMapTF           = PERIOD_M15;  // Timeframe whose swing extremes form the pools
input int               LiquidityClusterPoints   = 700;    // V170f: 1500 -> 700 ($0.70). Equal highs that the market actually reacts to sit 200-600 points apart; at $1.50 tolerance three unrelated swings merged into one "pool", inflating its weight and hiding how tight the real cluster was. Now consistent with PathDensityMergePoints, which answers the same question - when are two levels one level.
input int               LiquidityMapSearchPoints = 12000;  // Only consider pools within this distance of price ($12)
input int               LiquidityMinSwings       = 2;      // Aligned swings needed to call it a pool (2 = a clean double top/bottom)

// V172: every penalty added this session was sized as though it were the only new one. Twenty of
// them are now live, and a live reading showed penalty=25 against a bonus ceiling of 12 - the score
// could not recover from conditions that were merely unremarkable. These are halved roughly across
// the board: each still says what it said, but the sum now leaves room for the setup to argue back.
input int               LiquidityAheadPenalty    = 4;  // V173: 2 -> 4. narx avval hovuzga chopadi - entry o\'sha yugurishni sotib oladi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering INTO a pool that price will likely run to first
input double            LiquidityMinWeight       = 2.5;    // Pool weight needed before it affects the decision at all
input int               LiquidityNearPoints      = 5000;   // A pool further away than this ($5) is too distant to matter for a scalp
input bool              LiquidityPrintOnUse      = true;   // Log pools that change a decision

// V142: event chain. Every event the EA detects - a level breaking, a thrust, a structure flip, a
// sweep - is scored the instant it appears and then forgotten. Nothing asks what came BEFORE it,
// yet that is exactly what gives an event its meaning: a CHoCH after a sweep is a reversal, the
// same CHoCH without one is often just noise. Recording events in order is the groundwork for
// reading the market as a sequence rather than a series of snapshots.
input bool              EnableEventChain         = true;   // Record market events in order so the sequence can be read, not just the latest event
input int               EventChainDedupeBars     = 3;      // The same event kind and direction within this many bars is treated as one event still developing
input bool              EventChainPrintOnUse     = false;  // Log every event appended to the chain (verbose - for tuning)
input bool              ShowEventChainOnDash     = false;  // V170d: default OFF. hodisalar zanjiri - bashorat qatori uni allaqachon xulosalaydi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.

// V143: reading the chain. Certain sequences carry a well-known meaning, and the meaning is in the
// ORDER: a sweep followed by a CHoCH against it is a reversal, while the same sweep followed by a
// BOS the same way is continuation. One event, opposite conclusions, decided entirely by what came
// next. These confidences say how much each recognised sequence is worth; an unrecognised chain
// returns nothing rather than guessing.
input bool              EnableChainExpectation   = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input int               ChainExpectationMaxAgeBars = 12;   // A chain older than this describes a market that has moved on
input int               ChainExpectationTightBars  = 8;    // Links formed further apart than this are only loosely related - confidence fades
input double            ChainConfSweepReversal     = 0.80; // sweep -> CHoCH against it: the run was for stops and is finished
input double            ChainConfSweepContinuation = 0.70; // sweep -> BOS same way: liquidity became fuel, not a turn
input double            ChainConfImpulseExhaustion = 0.65; // impulse -> CHoCH: the thrust is spent
input double            ChainConfExpansion         = 0.60; // range break -> impulse: expansion usually continues
input double            ChainConfBreakConfirmed    = 0.65; // zone break -> BOS: continuation
input double            ChainConfNewTrend          = 0.75; // CHoCH -> BOS the same way: a new direction confirmed itself
input int               ChainExpectWithBonus       = 3;    // Bonus for entering WITH what the chain expects
input int               ChainExpectAgainstPenalty  = 4;  // V173: 3 -> 4. hodisalar ketma-ketligi teskari aytadi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.    // Penalty for entering AGAINST it
input double            ChainExpectMinConfidence   = 0.60; // Confidence needed before the expectation affects the decision at all
input bool              ChainExpectPrintOnUse      = true; // Log expectations that change a decision

// V144: scenarios. Every module produces a direction and the EA reduces them to one answer, which
// throws away the most useful part of the reading: "45/30/25" and "80/10/10" both name the same
// winner but describe opposite markets - one with no owner, one with a clear one. Weighing the
// sources into three buckets keeps that distinction. A narrow margin is not a weak signal to trade
// smaller; it is a market that has not decided, and standing aside is the honest response.
input bool              EnableScenarios          = true;   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input double            ScenarioWeightChain      = 2.0;    // Weight of the event chain - the only source reading SEQUENCE rather than state
input double            ScenarioWeightStructure  = 1.5;    // Weight of each swing-structure frame
input double            ScenarioWeightStaircase  = 1.5;    // Weight of the broken-level staircase
input double            ScenarioWeightTrend      = 1.0;    // Weight of each indicator trend scale
input double            ScenarioWeightLiquidity  = 1.2;    // Weight of a stop pool pulling price toward it
input double            ScenarioMinMargin        = 0.20;   // Lead over the runner-up needed to call the market decided (0.20 = 20 points). Below this the readings are split.
input int               ScenarioUndecidedPenalty = 2;      // Penalty for entering while the scenarios are this close - the market has not chosen a side
input bool              ScenarioPrintOnUse       = false;  // Log the scenario split each time it affects a decision
input bool              ShowScenariosOnDash      = true;   // Show the split on the dashboard

// V145: the chain grades its own predictions. The confidences above were set by hand - reasonable,
// but unverified on this symbol. Every prediction is now recorded and scored a fixed number of bars
// later, and the tally feeds back into the confidence. Evidence is blended in gradually so a thin
// sample cannot overwrite a considered prior, and the tallies decay so a pattern that has stopped
// working loses its reputation instead of trading on an old reputation forever.
input bool              EnableChainLearning      = true;   // Let recorded outcomes adjust each chain pattern's confidence
input int               ChainLearningHorizonBars = 15;     // Bars after a prediction before it is graded
input int               ChainLearningWinPoints   = 1500;   // Move needed to call the prediction right or wrong (3-digit: 1500 = $1.50). Anything smaller is noise and is discarded.
input double            ChainLearningShrinkage   = 12.0;   // How much evidence is needed before the measured rate outweighs the configured one. Higher = slower to trust new data.
input int               ChainLearningMaxSamples  = 60;     // Tally ceiling per pattern; beyond it older evidence decays so behaviour can change
input bool              ChainLearningPrintOnUse  = true;   // Log every graded prediction

// V113: the break SEQUENCE - the staircase. On the live chart the user marked four levels broken in
// turn (4020 -> 4050 -> 4070 -> 4165), each becoming support: that progression is the plainest
// statement that buyers are in control, and the EA could not see it because its break detector
// stopped at the first break it found. Counting the whole window turns "a break happened" into
// "price has been climbing a staircase of broken levels".
input bool              EnableBreakSequence          = true;   // Count all zone breaks in the window instead of only the most recent one
input int               BreakSequenceLookbackBars    = 192;    // Window on ZoneBreakTF (192 x M15 = 2 days) - a staircase takes time to build
input int               BreakSequenceMinCount        = 2;      // How many one-sided breaks make a staircase (2 = a level broken, then the next one)
input int               BreakSequenceDedupePoints    = 800;    // Levels within this distance count as the SAME zone (3-digit: 800 = $0.80), so one zone broken over several bars isn't counted twice
input int               BreakSequenceWithBonus       = 3;      // Bonus for entering in the direction of a confirmed staircase
input int               BreakSequenceAgainstPenalty  = 5;      // Penalty for entering against a confirmed staircase - fading a market that is stepping through level after level
input bool              ZoneBreakPrintOnUse          = true;

input group "116 — SMART TRAIL ACCELERATION"
// The one part of the trade lifecycle none of today's new senses ever reached: exit/trailing
// was purely mechanical (fixed 300-point follow distance regardless of what's happening).
// This does NOT change WHEN trailing arms (BasketTrailStartPoints stays as-is) - it only
// tightens the follow distance once armed, when Trend Reversal, Recent Zone Break, Impulse,
// or Trend Quality show warning signs against the basket's direction, locking profit in
// faster instead of blindly giving back the full step regardless of deteriorating conditions.
input bool              EnableSmartTrailTightening   = true;
input int               SmartTrailMinStepPoints      = 100;    // Tightest the follow distance can go with maximum warnings
input int               SmartTrailWarningsForMaxTighten = 3;   // Warnings needed (out of 4 checks) to reach the minimum step
input bool              SmartTrailPrintOnUse         = true;

input group "117 — GRID-VS-TRAILING SAFETY CHECK"
// Grid Intelligence and the trailing/profit-lock system had zero awareness of each other -
// found during today's professional audit. If the basket is already in profit-trailing mode,
// adding more exposure via grid is philosophically backwards.
input bool              EnableGridTrailSafetyCheck   = true;

input group "118 — IMPULSE EXHAUSTION WARNING"
// Real gap found via live testing: grid kept adding BUY right as a sharp rally was visibly
// topping out (shrinking bullish bodies + growing upper-wick rejection) - the SAME-direction
// momentum a basket rides was never checked for deceleration, only whether a candle recently
// agreed with direction (Impulse Confirmation). This is the missing complement.
input bool              EnableImpulseExhaustionWarning = true;
input double            ImpulseExhaustionWickRatio   = 0.4;    // Rejection wick must be at least this fraction of the candle range
input double            ImpulseExhaustionShrinkFactor = 0.6;   // Current body must shrink to at most this fraction of the prior body
input int               ImpulseExhaustionPenalty     = 3;
input bool              ImpulseExhaustionPrintOnUse  = true;

input group "119 — DECELERATION AWARENESS (SYSTEMATIC AUDIT FOLLOW-UP)"
// Four more instances of the SAME pattern found via deeper audit: checking if something IS
// strong right now, but never whether it's GETTING WEAKER. ADX slope, MA convergence, waning
// volume, and the basket's own track record of prior grid additions.
input bool              EnableADXDeceleration        = true;
input double            ADXDecelerationMinDrop       = 5.0;    // Minimum ADX drop vs N bars ago to count as decelerating
input int               ADXDecelerationLookbackBars  = 5;
input bool              EnableMAConvergenceCheck     = true;
input int               MAConvergenceLookbackBars    = 8;
input double            MAConvergenceThreshold       = 0.7;    // Current fast-slow MA spread must be below this fraction of the prior spread to count as "converging"
input bool              EnableVolumePushWaningCheck  = true;
input double            VolumePushWaningThreshold    = 0.6;    // Most recent bar's conviction ratio must be below this fraction of the oldest bar's to count as "waning"
input int               VolumePushWaningPenalty      = 2;
input bool              EnableBasketAdverseStreakCheck = true;
input int               BasketAdverseStreakMinCount  = 2;      // Consecutive grid additions with no intervening recovery before extra caution kicks in
input double            BasketAdverseStreakBoostMultiplier = 1.5; // How much faster the depth threshold rises once the streak triggers

input group "120 — DECELERATION AWARENESS ROUND 2"
// Four MORE instances of the same pattern, found via a second, deeper audit pass: basket DD
// rate-of-change, candle-size progression, RSI extreme-cooling, and DXY's own deceleration.
input bool              EnableBasketDDAcceleration   = true;
input int               BasketDDAccelWindowBars      = 4;      // Bars per comparison window (recent vs older)
input double            BasketDDAccelRatioThreshold  = 1.4;     // Recent worsening rate must exceed the older rate by this multiple to count as "accelerating"
input double            BasketDDAccelMinFreshRate    = 1.0;     // Minimum %/bar worsening rate to flag a fresh acceleration starting from a calm baseline
input double            BasketDDAccelBoostMultiplier = 1.6;     // How much faster the grid depth threshold rises when DD is accelerating
input bool              EnableCandleSizeProgression  = true;
input double            CandleSizeProgressionThreshold = 1.3;   // Ratio needed to count as accelerating (or its inverse for decelerating)
input int               CandleSizeDecelPenalty       = 2;
input bool              EnableRSICooling             = true;
input double            RSICoolingOverboughtLevel    = 65.0;
input double            RSICoolingOversoldLevel      = 35.0;
input double            RSICoolingMinDrop            = 5.0;     // Minimum RSI point change vs N bars ago to count as cooling/warming
input bool              EnableDXYDeceleration        = true;
input double            DXYDecelerationThreshold     = 0.6;     // Recent-window slope must be below this fraction of the older-window slope to count as decelerating

input group "121 — EXHAUSTION CONSENSUS (UNIFIED, NON-LINEAR)"
// Ties together ADX slope, RSI cooling, candle-level Impulse Exhaustion, DXY deceleration,
// and basket DD acceleration into ONE non-linear score - genuine multi-signal agreement
// compounds rather than just adding, the same philosophy already proven for Grid Intelligence
// and AUTO Hunter Suitability. Replaces treating these as small, scattered, isolated checks.
input bool              EnableExhaustionConsensus    = true;
input double            ExhaustionConsensusMinFactor = 0.3;     // Minimum individual factor value to count as "triggered" for consensus purposes
input double            ExhaustionConsensusExtraPenaltyStep = 0.04; // Additional compounding penalty per extra warning beyond 2
input bool              EnableDeepShockExhaustionInConsensus = true; // V31.6z34 NEW: folds Deep News Volatility Brain's own shock-wick exhaustion check in as Factor 6, instead of leaving it as an isolated, uncoordinated signal
