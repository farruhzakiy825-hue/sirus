//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 01_Inputs                                       |
//| Input parameters (settings window)                               |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SIRUS QUICK SETUP - the settings an operator actually changes.   |
//| Everything below "ADVANCED" / "BRAIN" is tuned; leave it alone   |
//| unless you know exactly why.                                     |
//+------------------------------------------------------------------+
input group "SIRUS ▸ 1 · General"
// SirusBuildName: SIRUS versiyasi
input string            SirusBuildName           = "SIRUS v31.6 PRO AUTO GRID SAFETY READY";   // EA version
// OrderBrand: BREND: har order izohining boshi ("SIRUS by Zakiy | TREND", "... | GRID 3")
input string            OrderBrand               = "SIRUS by Zakiy";   // Order comment brand
// SirusMode: SIRUS rejimi (AUTO tavsiya)
input ENUM_SIRUS_MODE   SirusMode                = SIRUS_MODE_AUTO;   // Trading mode
// DefaultAutoMode: AUTO ishonchsiz bo'lsa qaytadigan rejim
input ENUM_SIRUS_MODE   DefaultAutoMode          = SIRUS_MODE_BALANCED;   // AUTO fallback mode
input long              MagicNumber              = 240007;   // Magic number
input bool              AllowLiveTrading         = true;   // Allow live trading
input group "SIRUS ▸ 2 · Lot size"
// StartLot: >>> YOUR FIRST-ENTRY LOT (this is the one you set) <<< Every basket's first order opens at this size. Raise to trade bigger, lower to trade smaller. Only used when UseAutoLot = false.
input double            StartLot                 = 0.25;   // Start lot (first order)
// UseAutoLot: false = always use StartLot (simple, recommended). true = size the first entry from RiskPercent of balance instead (see AUTOLOT DETAILS below).
input bool              UseAutoLot               = false;   // Auto lot from balance
// RiskPercent: Only used when UseAutoLot = true: risk this % of balance per first entry to compute the lot.
input double            RiskPercent              = 1.0;   // Auto lot: risk per entry (%)
// MinFirstEntryLotFactor: Keep at 1.0: guarantees a first entry opens at FULL StartLot size or not at all (never a shrunken partial). At 0.6 the stacked lot guards could trim a 0.25 StartLot down to ~0.15 (which showed on the chart). Safe at 1.0 because poor-condition entries are now REJECTED outright by the hard blocks rather than taken at reduced size. Set to 0.6 only if you'd rather have small entries in marginal conditions than no entry.
input double            MinFirstEntryLotFactor   = 1.0;   // Min first-entry lot factor (1.0 = full)
input group "SIRUS ▸ 3 · Grid recovery"
// UseGridRecovery: Master switch for the whole martingale grid. OFF = only ever the single first entry, no averaging down.
input bool              UseGridRecovery          = true;   // Grid recovery
// MaxOrders: V249fix: 7 -> 5. At 7 rungs from StartLot 0.25 with LotMultiplier 1.30 the full ladder projects ~$6.8k of adverse excursion against a ~$4.2k stop budget on a ~$10k account, so LadderIsAffordable() refused EVERY first entry - the EA scored setups and then never opened them. 5 rungs projects ~$2.6k and fits with room to spare. Raise it only alongside a bigger balance, a smaller StartLot, or a lower LotMultiplier.   // Max orders in ONE basket, including the first entry. Higher = deeper averaging (more recovery power) but bigger total risk.
input int               MaxOrders                = 5;   // Max orders per basket
// GridDistancePoints: Base distance price must move AGAINST the basket before the next grid order (3-digit broker: 7000 = $7.00). Smaller = adds sooner/closer; larger = adds later/farther.
input int               GridDistancePoints       = 7000;   // Grid step (points)
// GridDistanceMultiplier: Each successive grid gap = previous gap x this (1.25 = each gap 25% wider), so later adds are spaced farther apart.
input double            GridDistanceMultiplier   = 1.25;   // Grid step multiplier
// LotMultiplier: Each grid add's size = previous target x this (1.30 = each add 30% bigger). This is the martingale step. Higher = faster recovery, faster risk build-up.
input double            LotMultiplier            = 1.30;   // Grid lot multiplier
// AdaptiveGridDistance: ON = grid spacing adjusts to volatility (ATR) instead of a fixed GridDistancePoints, so adds are wider in fast markets and tighter in calm ones. Recommended ON.
input bool              AdaptiveGridDistance     = true;   // Adaptive grid step (ATR)
// EnableGridRescueGuarantee: QUTQARUV KAFOLATI: yumshoq grid to'siqlari narx uzoqlashsa chetlab o'tiladi - grid muzlamaydi (qattiq xavfsizlik to'siqlari qoladi)
input bool   EnableGridRescueGuarantee = true;   // Grid rescue guarantee
// GridRescueSoftSteps: Narx oxirgi orderdan shuncha rejalashtirilgan qadam uzoqlashsa VA qarshi harakat sekinlashsa - yumshoq to'siqlar chetlab o'tiladi
input double GridRescueSoftSteps      = 1.5;   // Rescue: steps + slowdown
// GridRescueForceSteps: Shuncha qadam uzoqlashsa - harakat to'xtaganini ko'rsatuvchi tasdiq yetadi (qarshi displacement yo'q, oxirgi M1 yangi ekstremum qilmadi). TASDIQSIZ HECH QACHON
input double GridRescueForceSteps     = 2.5;   // Rescue: steps + pause
input group "SIRUS ▸ 4 · Take profit & exit"
// BasketTPPoints: Base TP (points) when UseFixedTP=false
input int               BasketTPPoints           = 2500;   // Basket take profit (points)
// TPScale: v291a: barcha TP larni shu nisbatda kichraytirish (0.85 = 15% kichik, 1.0 = o'zgarishsiz). Savat va birinchi kirish TP si, pol ham. Cashback rejimiga ta'sir qilmaydi
input double            TPScale                  = 0.85;   // Take profit scale
// ATRTPMinPoints: TP floor - trailing manages the exit, TP is a far ceiling
input int               ATRTPMinPoints           = 2500;   // Minimum take profit (points)
// EnableSmartRunner: AQLLI TP (oddiy rejim): trend + tirik g'oya + joy bo'lsa, savat TP da yopilmaydi - trailing va uzoq maqsad bilan yuguradi. Diapazon / lokal / chuqur / ko'p orderli savatda oddiy TP
input bool   EnableSmartRunner        = true;   // Smart runner (trailing, normal mode)
// RunnerArmPoints: Trailing shu foydada yoqiladi (TP dan kichik bo'lsa TP x 0.88)
input int    RunnerArmPoints          = 2200;   // Runner: start trailing at (points)
// RunnerLockPoints: Yoqilgandan keyin kamida shuncha foyda qulflanadi
input int    RunnerLockPoints         = 2000;   // Runner: locked profit (points)
input group "SIRUS ▸ 5 · Cashback mode"
// EnableRebateMode: Close at break-even and collect the rebate instead of chasing a target
input bool   EnableRebateMode            = false;   // Cashback mode
// RebateSpreadMultiple: BOSQICH 3: 1.15 -> 0.60. Cashback TP = spread x shu + margin. TP kirish narxidan o'lchanadi, ya'ni TP ga yetganda butun TP - foyda; spread foydadan ayirilmaydi, faqat narx yurishi kerak bo'lgan masofani oshiradi. Grid qadamiga ta'sir yo'q - u baribir AutoGridMinDistance ($5.50/$6.00) bilan cheklanadi
input double RebateSpreadMultiple        = 0.60;   // Cashback TP = spread ×
// RebateTPMarginPoints: BOSQICH 3: 300 -> 80 ($0.08). Exness Cent da komissiya yo'q - bu qism sof foyda edi, xarajat emas. Spread 260 da TP: 599 -> 236 point
input int    RebateTPMarginPoints        = 80;   // Cashback TP extra (points)
// EnableCashbackTempo: CASHBACK TEMPI: faqat cashback rejimida - kirish talablari biroz yumshoq (veto'lar o'zgarmaydi), chunki daromad aylanmadan
input bool   EnableCashbackTempo      = true;   // Cashback fast tempo
input group "SIRUS ▸ 6 · Protection"
// UseBasketSL: The MAIN stop loss. Closes the WHOLE basket when its loss reaches BasketSLPercent of balance. This is your primary SL.
input bool              UseBasketSL              = true;   // Basket stop loss
// BasketSLPercent: [SL CHECKLIST STEP 1] >>> THE MAIN SL (this is the one you set) <<< Closes the basket when floating loss = this % of BALANCE. Example: balance $1000, value 50 => closes at -$500. To allow a 70% loss before closing, set this to 70 (then match the STEP-2 backups below).
input double            BasketSLPercent          = 50.0;   // Basket stop loss (% of balance)
// DailyLossPercent: [SL CHECKLIST STEP 2] Daily loss cap as % of balance. Set = BasketSLPercent (e.g. both 70), or a smaller value would close the basket before the main SL.
input double            DailyLossPercent         = 50.0;   // Daily loss limit (%)
// CloseBasketOnDailyLoss: When the daily loss cap is hit: also close the open basket (true) or just stop opening new ones (false).
input bool              CloseBasketOnDailyLoss   = false;   // Close basket at daily loss limit
// EquityStopPercent: [SL CHECKLIST STEP 2] Trigger when account EQUITY has dropped this % from balance. Set = BasketSLPercent (e.g. 70). A whole-account safety net.
input double            EquityStopPercent        = 50.0;   // Equity stop (% drawdown)
// EmergencyDDPercent: [SL CHECKLIST STEP 2] Emergency close when account equity DD reaches this %. Set = BasketSLPercent (e.g. 70). A backup for the equity stop.
input double            EmergencyDDPercent       = 50.0;   // Emergency close (% drawdown)
// EnableSmartEarlyExit: Optional EARLY exit BEFORE the main SL, only when many signals strongly agree the basket won't recover. Cuts some losses short. The main SL above still applies as the final backstop.
input bool              EnableSmartEarlyExit     = false;   // Smart early exit
// UnifiedMaxSpreadPoints: V90b: 300 -> 500 ($0.50). The user's Exness Cent XAUUSD spread runs $0.25-0.40 normally, so 300 ($0.30) was rejecting ordinary fills. $0.50 lets normal spreads through while still blocking the widened spreads around news/session-open. Paired with CriticalSpreadPoints ($0.80) as a two-stage guard.
input int               UnifiedMaxSpreadPoints   = 500;   // Max spread (points)
input bool   EnableEconomicCalendarGuard    = true;   // News filter (economic calendar)
input bool              EnableWeekendGuard       = true;   // Weekend protection
// EnableMarginGuard: pre-check free margin before any order
input bool              EnableMarginGuard        = true;   // Free margin check
input group "SIRUS ▸ 7 · Display & alerts"
input bool              ShowDashboard            = true;   // Show dashboard
input bool              EnablePushNotifications  = false;   // Push notifications
// VerboseLogs: FIX(log-noise): master switch for the ~170 "...PrintOnUse" diagnostic logs. false = quiet journal (trades, closes, errors and warnings still print). Each individual PrintOnUse switch still works when this is true.
input bool              VerboseLogs              = true;   // Detailed journal logs
input group "ADVANCED ▸ Diagnostics & reason code"
// EnableReasonCode: Har ochilgan order (birinchi kirish, grid, scale-in) uchun "nega ochildi" yozuvi: signal, ball, struktura, zonalar, joylashuv, yangilik, qarshi dalillar (CONFLICTS)
input bool              EnableReasonCode         = true;   // Enable reason code
// ReasonCodeToFile: Shu yozuvni MQL5/Files/Sirus_ReasonCode_<symbol>_<magic>.csv fayliga ham yozadi (tester'da: agent papkasidagi MQL5/Files)
input bool              ReasonCodeToFile         = true;   // Reason code to file (on/off)
input group "ADVANCED ▸ SIRUS core / mode"
input bool              AllowAutoHighHunter      = true;   // Allow auto high hunter
input int               ModeSwitchCooldownBars   = 10;   // Mode switch cooldown bars
input bool              ModeEvaluateOnNewBarOnly = false;   // Mode evaluate on new bar only (on/off)
input int               AutoHighHunterMaxSpread  = 300;   // Auto high hunter max spread
input int               AutoHighHunterMaxTickAge = 60;   // Auto high hunter max tick age
input int               AutoBalancedSpreadLimit  = 300;   // Auto balanced spread limit
// EnableAutoHunterMarketFilter: V31.6z13: AUTO's switch to HIGH_HUNTER previously checked ONLY spread/tick-age - zero market-risk awareness
input bool              EnableAutoHunterMarketFilter = true;   // Enable auto hunter market filter
// AutoHunterMinVolatilityRegime: Blocks the switch to Hunter during extreme volatility storms (VolatilityRegimeScore -1.0=storm, +1.0=normal)
input double            AutoHunterMinVolatilityRegime = -0.5;   // Auto hunter min volatility regime
// EnableAutoHunterNewsFilter: V31.6z14: was never checked before - being aggressive right as high-impact news hits is a real, independent risk
input bool              EnableAutoHunterNewsFilter   = true;   // Enable auto hunter news filter
// EnableAutoHunterHourFilter: V31.6z14: consults this hour's own historical Hour-Bayes win rate (already tracked elsewhere, just never used here)
input bool              EnableAutoHunterHourFilter   = true;   // Enable auto hunter hour filter
// AutoHunterMinHourWinRate: Below this historical win rate for the current hour, count it as a concern
input double            AutoHunterMinHourWinRate     = 0.35;   // Auto hunter min hour win rate
// EnableAutoHunterTrendClarityFilter: V31.6z14: uses Trend Quality Score in BOTH directions - a murky, directionless market is less suitable for aggressive mode
input bool              EnableAutoHunterTrendClarityFilter = true;   // Enable auto hunter trend clarity filter
// AutoHunterMinTrendClarity: At least one direction must show this much Trend Quality to count as "clear"
input double            AutoHunterMinTrendClarity    = 0.55;   // Auto hunter min trend clarity
// AutoHunterMinSuitabilityScore: Overall weighted score (6 factors + non-linear consensus) required to allow HIGH_HUNTER
input double            AutoHunterMinSuitabilityScore = 0.6;   // Auto hunter min suitability score
// EnableAutoHunterBasketHealthFilter: V31.6z15: NEW - if an existing basket is already in meaningful drawdown, switching to the MORE aggressive mode is backwards
input bool              EnableAutoHunterBasketHealthFilter = true;   // Enable auto hunter basket health filter
// AutoHunterMaxBasketDDForHunter: Basket drawdown % above which Hunter mode is discouraged
input double            AutoHunterMaxBasketDDForHunter = 15.0;   // Auto hunter max basket DD for hunter
// AutoHunterConsensusPenaltyStep: V31.6z15: NEW - non-linear extra penalty per concern once 3+ independent concerns fire simultaneously (same philosophy as Grid Intelligence)
input double            AutoHunterConsensusPenaltyStep = 0.15;   // Auto hunter consensus penalty step

input group "ADVANCED ▸ Lot / start settings"
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
// MaxLot: Hard ceiling: the first-entry lot never exceeds this, no matter what StartLot/AutoLot produce.
input double            MaxLot                   = 10.0;   // Max lot

// V139: confidence-scaled first entry. Until now every first entry used the same lot regardless of
// how strongly it qualified - a setup scraping past the score bar risked as much as one clearing it
// by a wide margin, and on a martingale it is the marginal entries that turn into deep baskets.
// The floor is high on purpose: this trims a weak entry, it does not halve it. The grid progression
// downstream assumes a first lot near StartLot, so cutting deeper would leave the whole recovery
// ladder underweight.
// EnableConfidenceLot: Scale the FIRST ENTRY lot with the entry's score
input bool              EnableConfidenceLot      = true;   // Enable confidence lot
// ConfidenceLotFullScore: Score at which the full lot is used. Below it the lot tapers toward the floor; at or above it, StartLot is used in full.
input int               ConfidenceLotFullScore   = 12;   // Confidence lot full score
// ConfidenceLotMinFactor: Floor as a fraction of the normal lot (0.80 = StartLot 0.25 never goes below 0.20). Raise toward 1.0 to disable the effect gradually.
input double            ConfidenceLotMinFactor   = 0.80;   // Confidence lot min factor
// ConfidenceLotPrintOnUse: Log every trimmed entry so the sizing can be checked
input bool              ConfidenceLotPrintOnUse  = true;   // Confidence lot print on use (on/off)

input group "ADVANCED ▸ Margin guard"
// MarginGuardMinLevelPct: block if projected margin level % would fall below this
input double            MarginGuardMinLevelPct   = 200.0;   // Margin guard min level %
input bool              MarginGuardPrintOnUse    = true;   // Margin guard print on use (on/off)

input group "ADVANCED ▸ Spread limit"
// One master spread cap used by every module (or each module's own individual limit if off).
input bool              UseUnifiedMaxSpread      = true;   // Use unified max spread

input group "ADVANCED ▸ Weekend guard"
// WeekendBlockEntryFriHour: Friday (server time): block NEW first entries from this hour
input int               WeekendBlockEntryFriHour = 20;   // Weekend block entry Friday hour
// WeekendBlockGridFri: also block NEW grid orders in that window (basket manager keeps working)
input bool              WeekendBlockGridFri      = true;   // Weekend block grid Friday (on/off)
// WeekendCloseBasketFri: optionally flat the whole basket before weekend
input bool              WeekendCloseBasketFri    = false;   // Weekend close basket Friday (on/off)
// WeekendCloseFriHour: Friday hour for the optional flat
input int               WeekendCloseFriHour      = 22;   // Weekend close Friday hour
// WeekendBlockSunEntries: Block entries on Sat/Sun (set false to allow weekend-open trading)
input bool              WeekendBlockSunEntries   = true;   // Weekend block sun entries (on/off)
input bool              WeekendGuardPrintOnUse   = true;   // Weekend guard print on use (on/off)

input group "ADVANCED ▸ Push notifications"
// Requires MetaQuotes ID set up in MT5 mobile.
input bool              PushOnEntry              = true;   // Push on entry (on/off)
input bool              PushOnBasketClose        = true;   // Push on basket close (on/off)

input group "ADVANCED ▸ Chart markers / TP-SL lines (visual only)"
// FEATURE(close-markers): when a basket closes, record WHY it closed and whether it won or lost,
// so it's visible both in the account History (written into each deal's comment) and on the chart
// (a green check for a profitable close, a red cross for a losing one, with a short tag like TRAIL
// / BE / TP / SL / SZR next to it). Purely visual/record - no effect on trading decisions.
// EnableCloseMarkers: Draw a chart marker + tag each time a basket closes
input bool              EnableCloseMarkers       = true;   // Enable close markers
// CloseMarkerProfitColor: Colour of a winning close (check mark)
input color             CloseMarkerProfitColor   = clrLime;   // Close marker profit color
// CloseMarkerLossColor: Colour of a losing close (cross)
input color             CloseMarkerLossColor     = clrRed;   // Close marker loss color
// CloseMarkerFontSize: Font size of the tag text next to the marker
input int               CloseMarkerFontSize      = 10;   // Close marker font size

// FEATURE(tp-sl-lines): draw the live basket TARGET (TP) and, once trailing is armed, the trailing
// STOP line on the chart. The TP line is derived from the basket AVERAGE price, so it automatically
// moves whenever a new grid order shifts the average - which is exactly the behaviour the static
// per-order TP never showed. The trailing line only appears once trailing is active and then rides
// 300pts (BasketTrailStepPoints) behind the locked profit. Purely visual - no effect on trading.
// EnableTPSLLines: Draw basket TP and trailing-SL lines on the chart
input bool              EnableTPSLLines          = true;   // Enable tpsl lines
// TPLineColor: Colour of the basket TP line
input color             TPLineColor              = clrDodgerBlue;   // TP line color
// TrailSLLineColor: Colour of the trailing-SL line
input color             TrailSLLineColor         = clrOrange;   // Trail SL line color
// TPSLLineWidth: Line thickness
input int               TPSLLineWidth            = 1;   // Tpsl line width
// TPSLLineStyle: Line style
input ENUM_LINE_STYLE   TPSLLineStyle            = STYLE_DASH;   // Tpsl line style

input group "ADVANCED ▸ Fresh-bar entry confirmation"
// Only enters near the start of the signal bar, cutting off stale end-of-bar entries.
input bool              EnableFreshBarEntry      = true;   // Enable fresh bar entry
// FreshBarMaxPercentOfBar: V34b: set to 0 (OFF) on user request - entry allowed at ANY point in the signal bar, not just the first 75%. Removes the "entry deferred to next bar" delay. (Set to e.g. 75 to re-enable the first-N%-of-bar restriction.)
input double            FreshBarMaxPercentOfBar  = 0.0;   // Fresh bar max % of bar
input bool              FreshBarPrintOnUse       = false;   // Fresh bar print on use (on/off)

input group "ADVANCED ▸ Bayes score learning"
// Learns from its own trade history and nudges the score accordingly.
input bool              EnableBayesScoreAdjust   = true;   // Enable bayes score adjust
// BayesScoreGoodWinrate: detector winrate >= this -> bonus
input double            BayesScoreGoodWinrate    = 0.60;   // Bayes score good winrate
// BayesScoreBadWinrate: detector winrate <= this -> penalty
input double            BayesScoreBadWinrate     = 0.40;   // Bayes score bad winrate
input int               BayesScoreBonus          = 1;   // Bayes score bonus
// BayesScorePenalty: symmetric with bonus: frequency-neutral by design
input int               BayesScorePenalty        = 1;   // Bayes score penalty

input group "ADVANCED ▸ Autolot details"
// Only used when UseAutoLot=true above.
// AutoLotUseEquity: false=balance, true=equity asosida
input bool              AutoLotUseEquity         = false;   // Auto lot use equity
// AutoLotPer1000: Lot per $1000 of balance (e.g. $5000 balance -> 0.05 lot)
input double            AutoLotPer1000           = 0.01;   // Auto lot per 1000
// AutoLotRiskMode: true: RiskPercent + FirstEntrySLPoints dan hisoblash (SL yoqilgan bo'lishi shart)
input bool              AutoLotRiskMode          = false;   // Auto lot risk mode
input bool              AutoLotPrintOnUse        = true;   // Auto lot print on use

input group "ADVANCED ▸ Self-defense throttle"
// After a losing streak, trims lot and raises the score bar. Never increases lot; recovers gradually on wins.
input bool              EnableSelfDefense        = true;   // Enable self defense
// SelfDefenseLossStreak: shuncha ketma-ket zarar basket -> himoya rejimi ON
input int               SelfDefenseLossStreak    = 3;   // Self defense loss streak
// SelfDefenseLotFactor: himoya rejimida first-entry lot x shu faktor
input double            SelfDefenseLotFactor     = 0.50;   // Self defense lot factor
// SelfDefenseMinScoreAdd: himoya rejimida min score +shu (sifat talabi oshadi)
input int               SelfDefenseMinScoreAdd   = 1;   // Self defense min score add
// SelfDefenseRecoverWins: shuncha foydali basket -> normal rejim
input int               SelfDefenseRecoverWins   = 2;   // Self defense recover wins
input bool              SelfDefensePrintOnUse    = true;   // Self defense print on use (on/off)

input group "ADVANCED ▸ ATR adaptive TP"
input bool              EnableATRAdaptiveTP      = true;   // Enable ATR adaptive TP
// ATRTPFactor: TP = ATR x this factor
input double            ATRTPFactor              = 3.00;   // Atrtp factor
// ATRTPMaxPoints: TP ceiling
input int               ATRTPMaxPoints           = 6000;   // Atrtp max points
input bool              ATRTPPrintOnUse          = false;   // Atrtp print on use (on/off)

input group "ADVANCED ▸ ADR (average daily range) filter"
// Penalizes continuation entries once today's range is mostly used up.
input bool              EnableADRFilter          = true;   // Enable ADR filter
// ADRPeriodDays: o'rtacha kunlik diapazon shu kunlardan
input int               ADRPeriodDays            = 14;   // ADR period days
// ADRExhaustPercent: V121: 92 -> 78. Today's range having eaten this % of the 14-day average daily range means most of the day's move is already behind us. At 92% the filter almost never fired (a day rarely completes 92% of its own average before the EA is done trading), so it contributed nothing to the trend-chasing problem it exists to prevent.     // bugungi diapazon ADR ning shu %iga yetsa
input double            ADRExhaustPercent        = 78.0;   // ADR exhaust %
// ADRPenalty: V121: 2 -> 4. Entering after most of the day's expected range is spent is a late entry by definition; the remaining room usually cannot cover the target plus a retrace.        // bugungi harakat YO'NALISHIDAGI entrylarga penalti
input int               ADRPenalty               = 4;   // ADR penalty

input group "ADVANCED ▸ Hour-of-day learning"
// Learns which hours tend to win/lose and nudges the score accordingly.
input bool              EnableHourBayes          = true;   // Enable hour bayes
// HourBayesMinSamples: soat bo'yicha kamida shuncha basket bo'lmaguncha neutral
input int               HourBayesMinSamples      = 8;   // Hour bayes min samples
input double            HourBayesGoodWinrate     = 0.60;   // Hour bayes good winrate
input double            HourBayesBadWinrate      = 0.40;   // Hour bayes bad winrate
input int               HourBayesBonus           = 1;   // Hour bayes bonus
input int               HourBayesPenalty         = 1;   // Hour bayes penalty

input group "ADVANCED ▸ DXY score adjust"
// The DXY proxy also nudges the score, on top of its lot effect.
input bool              DXYProxyScoreAdjust      = true;   // DXY proxy score adjust (on/off)
input int               DXYProxyScoreBonus       = 1;   // DXY proxy score bonus
input int               DXYProxyScorePenalty     = 1;   // DXY proxy score penalty

// ===================================================================================
// FEATURE: SMART SELF-TUNING (added on user request) - three linked systems that use the
// bot's OWN accumulated win/loss history to (1) stop trading detectors that keep losing,
// (2) avoid times of day / days of week that keep losing, and (3) do this WITHOUT blindly
// increasing trade count, which on a martingale system is what blows accounts. Everything
// below is data-driven, needs a real sample size before it acts, and can be fully disabled.
// ===================================================================================
input group "ADVANCED ▸ Smart: bayes detector AUTO-disable"
// If a specific signal type (detector) has a proven-bad win rate over enough closed trades,
// stop taking its signals entirely. This RAISES quality, does not chase more trades. Needs a
// real sample first (BayesMinSamples) so a couple of unlucky losses can't disable a detector.
// EnableBayesAutoDisable: V193: OFF. Yigirma namunadan keyin 38% dan past yutuqli detektorni butunlay o'chiradi. Yuqori chastotali scalperда yigirma namuna bir necha soatda to'planadi, va vaqtincha yomon ketgan detektor abadiy o'chib qolishi mumkin - hech qanday tiklanish yo'li yo'q. O'rganish qolsin, avtomatik o'chirish yo'q.
input bool   EnableBayesAutoDisable       = false;   // Enable bayes auto disable
// BayesAutoDisableWinrate: Disable a detector whose shrunk win rate falls to/below this (0.38 = loses ~62% of the time). Keep well below 0.5 so only genuinely bad detectors are cut.
input double BayesAutoDisableWinrate      = 0.38;   // Bayes auto disable winrate
// BayesAutoDisableMinSamples: ...but only after at least this many closed trades of that type. Higher than BayesMinSamples: disabling is a stronger action than a lot trim, so it demands more evidence.
input int    BayesAutoDisableMinSamples   = 20;   // Bayes auto disable min samples
input bool   BayesAutoDisablePrintOnUse   = true;   // Bayes auto disable print on use (on/off)

input group "ADVANCED ▸ Smart: time-of-day / day-of-week filter"
// Blocks NEW first entries during hours or weekdays this account has a proven-bad record in.
// Manages existing baskets normally - this only gates opening fresh risk at bad times.
// EnableSmartTimeFilter: Master switch for the time filter
input bool   EnableSmartTimeFilter        = true;   // Enable smart time filter
// TimeFilterUseHour: Block entries in proven-bad HOURS
input bool   TimeFilterUseHour            = true;   // Time filter use hour (on/off)
// TimeFilterHourBadWinrate: An hour at/below this shrunk win rate is blocked...
input double TimeFilterHourBadWinrate     = 0.38;   // Time filter hour bad winrate
// TimeFilterHourMinSamples: ...once it has at least this many closed trades
input int    TimeFilterHourMinSamples     = 20;   // Time filter hour min samples
// TimeFilterUseDayOfWeek: Block entries on proven-bad WEEKDAYS
input bool   TimeFilterUseDayOfWeek       = true;   // Time filter use day of week (on/off)
// TimeFilterDowBadWinrate: A weekday at/below this shrunk win rate is blocked...
input double TimeFilterDowBadWinrate      = 0.40;   // Time filter day-of-week bad winrate
// TimeFilterDowMinSamples: ...once it has at least this many closed trades
input int    TimeFilterDowMinSamples      = 15;   // Time filter day-of-week min samples
input bool   SmartTimeFilterPrintOnUse    = true;   // Smart time filter print on use (on/off)

input group "ADVANCED ▸ Brain penalty cap"
// Caps how much the learning modules together can penalize a signal, so they can't stack up and choke trade frequency.
// BrainPenaltyCap: V31.6y: raised from 2 - now correctly captures 7 new penalty sources (was previously bypassed for all of them due to a positioning bug, now fixed)
input int               BrainPenaltyCap          = 12;   // Brain penalty cap
// EnableSoftBrainPenaltyCap: V31.6z61: this session roughly doubled the penalty sources (26 now). A HARD clip made 12 points and 55 points of penalty score IDENTICALLY, flattening every nuanced penalty built today. Soft cap keeps excess counting at reduced weight instead of discarding it.
input bool              EnableSoftBrainPenaltyCap = true;   // Enable soft brain penalty cap
// BrainPenaltySoftFactor: Weight applied to penalty beyond the cap - low enough that the cap still does its job, high enough that "very bad" still outranks "somewhat bad"
input double            BrainPenaltySoftFactor   = 0.35;   // Brain penalty soft factor
// EnableBonusCap: V31.6z65: penalties were capped but bonuses were not - and ~8 of the 22 bonus sources all measure the same single fact ("trend agrees"), stacking to ~+16 in any strong trend while every caution signal got compressed. That asymmetry biased the whole system toward chasing extended moves.
input bool              EnableBonusCap           = true;   // Enable bonus cap
// BonusCap: Symmetric with BrainPenaltyCap - beyond this, extra bonus counts at BrainPenaltySoftFactor weight
input int               BonusCap                 = 12;   // Bonus cap

input group "ADVANCED ▸ Entry drift guard"
// Skips an entry if price has already moved too far from the signal point (Fresh-Bar covers timing, this covers price).
input bool              EnableEntryDriftGuard    = true;   // Enable entry drift guard
// DriftMaxATRFraction: ruxsat etilgan uzoqlik = SignalTF ATR x shu
input double            DriftMaxATRFraction      = 0.60;   // Drift max ATR fraction
// DriftMinPointsFloor: Minimum allowed drift even when ATR is very small
input int               DriftMinPointsFloor      = 300;   // Drift min points floor
input bool              DriftPrintOnUse          = false;   // Drift print on use (on/off)

input group "ADVANCED ▸ Smart fill"
// Briefly waits for a small pullback or tighter spread before sending; always fires by the timeout either way.
input bool              EnableSmartFill          = true;   // Enable smart fill
// SmartFillTimeoutSec: V187: 20 -> 8 soniya. V168 da men buni 6 dan 20 ga oshirgandim, chunki "sifatli setup 20 soniyada yo\'qolmaydi" deb hisoblagandim. Bu past chastotali savdo uchun to\'g\'ri, lekin bu bot daqiqalar ichida ishlaydi - har entryga 20 soniya kechikish M1 barning uchdan birini yeydi va narx allaqachon ketgan bo\'ladi. 8 soniya tik portlashi tinchishiga yetadi, ortiqchasi esa fill yaxshilanishidan ko\'ra ko\'proq yo\'qotadi.
input int               SmartFillTimeoutSec      = 8;   // Smart fill timeout sec
// SmartFillPullbackPoints: V187: 200 -> 120 ($0.12). Yaxshiroq fill uchun kutishga arziydigan pullback. 200 pts M1 da kamdan-kam bo\'ladi, ya\'ni SmartFill deyarli har doim timeout bilan tugardi - foydasiz kutish.
input int               SmartFillPullbackPoints  = 120;   // Smart fill pullback points
// SmartFillSpreadDipPoints: V168: 20 -> 80 ($0.08). Kutishni oqlaydigan spread torayishi. Signal ko\'pincha spread vaqtincha kengaygan paytda keladi, va o\'shanda kirish kengayishni savdoning IKKALA tomonida to\'laydi.
input int               SmartFillSpreadDipPoints = 80;   // Smart fill spread dip points
input bool              SmartFillPrintOnUse      = true;   // Smart fill print on use (on/off)

input group "ADVANCED ▸ Lot trace (diagnostic log)"
input bool              EnableLotTrace           = true;   // Enable lot trace

input group "ADVANCED ▸ Tick-velocity guard"
// Detects a sudden price spike from tick speed, even for news not in the calendar.
input bool              EnableTickVelocityGuard  = true;   // Enable tick velocity guard
// VelocitySpikeRatio: tick tezligi odatdagidan shu barobar oshsa
input double            VelocitySpikeRatio       = 4.0;   // Velocity spike ratio
// VelocityMovePoints: VA narx shu oynada shuncha punkt yursa -> spike
input int               VelocityMovePoints       = 400;   // Velocity move points
input int               VelocityWindowSec        = 5;   // Velocity window sec
// VelocityHoldSec: Seconds to pause new entries after a tick-velocity spike
input int               VelocityHoldSec          = 30;   // Velocity hold sec
// VelocityMoveATRMult: the spike move must also be at least ATR(M1) x this (0 = off) - in a fast, volatile market an ordinary move is not a spike
input double            VelocityMoveATRMult      = 1.5;   // Spike move vs ATR(M1) (x, 0 = fixed points only)
// VelocityMaxHoldPer5Min: the spike pause may hold entries for at most this many seconds in any 5 minutes (0 = no cap) - a real spike is caught, a busy market is not choked
input int               VelocityMaxHoldPer5Min   = 60;   // Max spike pause per 5 min (sec, 0 = no cap)
input bool              VelocityPrintOnUse       = true;   // Velocity print on use (on/off)

input group "ADVANCED ▸ ATR regime grid distance"
// Scales grid distance by current-vs-baseline volatility - both wider and tighter.
// EnableATRRegimeGrid: scale grid distance by current-vs-baseline ATR ratio
input bool              EnableATRRegimeGrid      = true;   // Enable ATR regime grid
// ATRRegimeBasePeriod: baseline (slow) ATR period on SignalTF
input int               ATRRegimeBasePeriod      = 100;   // ATR regime base period
// ATRRegimeMinScale: quiet market: distance can shrink to 70%
input double            ATRRegimeMinScale        = 0.70;   // ATR regime min scale
// ATRRegimeMaxScale: wild market: distance can grow to 200%
input double            ATRRegimeMaxScale        = 2.00;   // ATR regime max scale
input bool              ATRRegimePrintOnUse      = false;   // ATR regime print on use (on/off)

input group "ADVANCED ▸ Multi-timeframe confirm"
// Bonus when aligned with the higher-TF trend, penalty when against it - never a hard block.
// EnableMTFConfirm: V55b: OFF. This penalised/bonused on a single H1 read, but H1 is ALREADY one of the four timeframes the EnableMTFAlignment vote counts (2/4=-2, 3/4=-4, 4/4=-6). Keeping both meant the same H1 opinion was charged twice. The vote is the better voice: it is proportional and covers more timeframes.
input bool              EnableMTFConfirm         = false;   // Enable MTF confirm
// MTFConfirmTF: higher timeframe for trend check
input ENUM_TIMEFRAMES   MTFConfirmTF             = PERIOD_H1;   // MTF confirm TF
// MTFConfirmMAPeriod: SMA period on the HTF
input int               MTFConfirmMAPeriod       = 50;   // MTF confirm MA period
// MTFConfirmBonus: score bonus when entry direction matches HTF trend
input int               MTFConfirmBonus          = 2;   // MTF confirm bonus
// MTFConfirmPenalty: score penalty when entry fights HTF trend
input int               MTFConfirmPenalty        = 2;   // MTF confirm penalty
// MTFNeutralBandATR: price within +-(this x HTF ATR) of SMA = neutral, no adjust
input double            MTFNeutralBandATR        = 0.40;   // MTF neutral band ATR
input bool              MTFConfirmPrintOnUse     = false;   // MTF confirm print on use (on/off)

input group "ADVANCED ▸ Persistent state / mode-specific lot"
// EnablePersistentState: save Bayes learning + post-loss cooldown in terminal GlobalVariables
input bool              EnablePersistentState    = true;   // Enable persistent state
// LotForBalancedMode: 0 = use StartLot
input double            LotForBalancedMode       = 0.0;   // Lot for balanced mode
// LotForHighHunterMode: 0 = use StartLot
input double            LotForHighHunterMode     = 0.0;   // Lot for high hunter mode

input group "ADVANCED ▸ SL / loss protection (all limits, one place)"
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

// UseRiskEngine: Master switch for ALL loss protection below. OFF = no SL / no limits at all (dangerous). Keep this ON.
input bool              UseRiskEngine            = true;   // Use risk engine
// EnableDDWarningPush: Send phone/push alerts as the loss grows (does NOT close anything - just warns you). Uses the three thresholds below.
input bool              EnableDDWarningPush      = true;   // Enable DD warning push
// DDWarningThreshold1: Send 1st alert when basket loss reaches this % of balance (early heads-up).
input double            DDWarningThreshold1      = 25.0;   // DD warning threshold 1
// DDWarningThreshold2: Send 2nd alert at this % (loss is growing).
input double            DDWarningThreshold2      = 35.0;   // DD warning threshold 2
// DDWarningThreshold3: Send 3rd/final alert at this % (loss is close to the main SL).
input double            DDWarningThreshold3      = 45.0;   // DD warning threshold 3
// SmartEarlyExitMinDDPercent: V249fix: 32 -> 42. At 32% this armed BEFORE the last grid rung could be placed (a completed 5-rung ladder peaks at ~33% DD in hunter geometry and ~35% in balanced (and ~41% in the worst case where ATR/session widening drives every gap to the 12000 clamp)), so it could cancel the final rung and realise a ~$3,200 loss on a basket the affordability gate had already budgeted to full depth. It has to sit ABOVE the completed-ladder drawdown and BELOW BasketSLPercent to be an early exit rather than a competing stop. Re-tune if you change MaxOrders, StartLot or LotMultiplier.   // Smart Early Exit won't consider exiting until loss reaches this % (so normal wiggles don't trigger it). Must be below BasketSLPercent.
input double            SmartEarlyExitMinDDPercent = 42.0;   // Smart early exit min DD %
// SmartEarlyExitMinConfirmations: Smart Early Exit needs at least this many of 4 independent signals to agree before exiting early. Higher = more cautious (exits less often).
input int               SmartEarlyExitMinConfirmations = 3;   // Smart early exit min confirmations
// SmartEarlyExitGlobalTrendMinAgainst: For Smart Early Exit: the big-picture (D1/H4/H1) trend must be at least this firmly AGAINST the basket (0 = any, 1 = strongest).
input double            SmartEarlyExitGlobalTrendMinAgainst = 0.5;   // Smart early exit global trend min against
// SmartEarlyExitReversalConsensusMin: For Smart Early Exit: the reversal signal against the basket must be at least this strong (0-1).
input double            SmartEarlyExitReversalConsensusMin = 0.75;   // Smart early exit reversal consensus min
// SmartEarlyExitPersistBars: V249fix: 3 -> 30. These are CoreBarTF bars, and CoreBarTF is M1 - so "3 bars" was three MINUTES, not the ~45 the design intended. Three minutes of three indicators agreeing was enough to authorise realising the whole basket loss. 30 M1 bars restores a half-hour confirmation window. If you move CoreBarTF to M15, set this back to ~3.   // For Smart Early Exit: condition must hold this many bars in a row (not one noisy tick) before it acts.
input int               SmartEarlyExitPersistBars = 30;   // Smart early exit persist bars

// UseDailyLossLimit: Stop trading for the rest of the day once the day's total loss hits the cap below.
input bool              UseDailyLossLimit        = true;   // Use daily loss limit
// DailyLossMoney: Daily loss cap as a FIXED MONEY amount instead of %. 0 = off (use DailyLossPercent above). Set e.g. 200 to stop the day at -$200 regardless of balance.
input double            DailyLossMoney           = 0.0;   // Daily loss money

// UseEquityStop: Extra safety based on ACCOUNT EQUITY (whole account), not just the one basket.
input bool              UseEquityStop            = true;   // Use equity stop
// CloseBasketOnEquityStop: When the equity stop fires: close the open basket too (true) or just block new trades (false).
input bool              CloseBasketOnEquityStop  = true;   // Close basket on equity stop

// UseEmergencyClose: Last-resort account-equity emergency close, separate from the layers above.
input bool              UseEmergencyClose        = true;   // Use emergency close
// EnableEmergencyForceClose: A second, independent emergency close with minimal dependencies - fires even if the normal close chain somehow fails.
input bool              EnableEmergencyForceClose = true;   // Enable emergency force close
// EmergencyForceCloseDDPercent: [SL CHECKLIST STEP 3] The absolute LAST line of defence. Set just ABOVE your main SL (BasketSLPercent 70 => this 72) so it only fires if everything else failed.
input double            EmergencyForceCloseDDPercent = 52.0;   // Emergency force close DD %

// MaxBasketMarginPercent: Never let the basket's used margin exceed this % of equity (prevents a margin call). Blocks new grid orders once reached.
input double            MaxBasketMarginPercent   = 60.0;   // Max basket margin %

// V114: margin rescue. When the next grid order's margin doesn't fit, the EA used to refuse and the
// basket froze in drawdown until the SL. Worse, the loop is self-reinforcing: drawdown lowers equity,
// which raises the basket's margin %, which blocks the grid exactly when it is needed. Live example:
// a $50 account with StartLot 0.2 froze at $6 drawdown, while a $100 account with StartLot 0.3 (a
// SMALLER lot-to-balance ratio) added its order and closed in profit. Rescue looks for the largest
// lot that does fit instead of freezing - but only accepts it if it is still big enough to matter.
// EnableGridMarginRescue: When the full grid lot won't fit on margin, add the largest lot that does instead of freezing the basket
input bool              EnableGridMarginRescue   = true;   // Enable grid margin rescue
// GridMarginRescueMinFactor: The rescue lot must be at least this fraction of the intended lot (0.5 = half). Below this an addition takes fresh risk without meaningfully improving break-even, so the block stands.
input double            GridMarginRescueMinFactor = 0.5;   // Grid margin rescue min factor

// V131: a grid addition placed directly on the wall that will push price back is the worst fill in
// the whole basket. The grid already sees opposing zones, but only as a score component - a strong
// enough score still pushes the order through, which is how a SELL got added right on a support the
// chart had respected before. This makes it a timed WAIT instead: recovery is never frozen (the
// wait expires), but the addition happens after the level gives way rather than into it.
// EnableGridZoneWait: Delay a grid addition while price sits on the zone that opposes the basket
input bool              EnableGridZoneWait       = true;   // Enable grid zone wait
// GridZoneWaitMaxBars: Hard limit on the wait. Once passed, the grid adds anyway - a basket must never be stranded by a zone price is sitting inside.
input int               GridZoneWaitMaxBars      = 20;   // Grid zone wait max bars
// GridZoneWaitMaxBasketDD: Above this basket drawdown %% the wait is skipped entirely and the grid adds immediately. Waiting for a better fill is worthwhile early; once a basket is deep, delaying its averaging is the freeze that margin rescue exists to prevent.
input double            GridZoneWaitMaxBasketDD  = 12.0;   // Grid zone wait max basket DD
// GridZoneWaitPrintOnUse: Log the wait and its expiry
input bool              GridZoneWaitPrintOnUse   = true;   // Grid zone wait print on use (on/off)

// V137: structure-based grid placement. A grid order stepped a fixed distance lands wherever the
// arithmetic points - possibly into empty space, possibly onto the very level that will push price
// back against the basket. An addition should sit AT a level that works FOR the basket (resistance
// above a SELL, support below a BUY), because the bounce from there is what carries the basket back
// toward break-even. These settings let the computed distance be pulled to such a level.
// EnableGridZoneReach: Let a grid add reach slightly FURTHER to land on a strong level, instead of firing short of it into empty space. (Pulling the add IN toward a nearer zone was already handled by EnableZoneMapGridAwareness.)
input bool              EnableGridZoneReach      = true;   // Enable grid zone reach
// GridZoneSnapMaxFactor: Ceiling on that reach, as a multiple of the computed distance. 1.5 = may wait up to 50% longer to land on the level; recovery is never pushed further than that.
input double            GridZoneSnapMaxFactor    = 1.5;   // Grid zone snap max factor
// GridZoneStrongLevel: V137b: strength at which a level counts as STRONG enough to be worth waiting longer for. Zone strength now includes rejection quality, so one violent bounce can reach this on its own.
input double            GridZoneStrongLevel      = 2.5;   // Grid zone strong level
// GridZoneStrongSnapFactor: Reach allowance for those strong levels (2.0 = may wait up to twice the computed distance to land on it). Ordinary levels keep GridZoneSnapMaxFactor.
input double            GridZoneStrongSnapFactor = 2.0;   // Grid zone strong snap factor
// GridZoneReachPrintOnUse: Log every reach so the placement can be checked against the chart
input bool              GridZoneReachPrintOnUse  = true;   // Grid zone reach print on use (on/off)
// GridMarginRescuePrintOnUse: Log rescues AND frozen-grid blocks - this is the diagnostic that shows an account/lot-size mismatch
input bool              GridMarginRescuePrintOnUse = true;   // Grid margin rescue print on use (on/off)

// UsePostLossCooldown: After a LOSING basket closes, wait before opening a new one (stops revenge-trading straight back in).
input bool              UsePostLossCooldown      = true;   // Use post loss cooldown
// TrivialLossPctOfBalance: BOSQICH 10: 0.10 -> 0.50. Savat zarari balansning shu %idan KICHIK bo'lsa - "nolga yaqin" yopilish, zarar emas (pauza, +3 ball, zarar seriyasi, zarar joyi xotirasi, o'rganish - hech biri ishlamaydi). Balans 317 da: 0.10% = 0.32 (faqat slippage), 0.50% = 1.59 (break-even atrofidagi yopilishlar). Haqiqiy zararlar (grid chuqurlashib, SL ga yaqin yopilish) bundan ancha katta. 0 = eski xulq
input double            TrivialLossPctOfBalance  = 0.50;   // Trivial loss % of balance
// PostLossCooldownMinutes: V187: 30 -> 5 daqiqa. Zarardan keyingi pauza bitta zarar keyingisiga sabab bo'lishini oldini olish uchun - narx hali harakatda, sharoit hali o'sha, va darrov qayta kirish ko'pincha bir xil xatoni takrorlaydi. Besh daqiqa buni ushlaydi. O'ttiz daqiqa esa boshqa narsa: kuniga besh zarar bilan bu ikki yarim soat to'xtash, ya'ni yuqori chastotali scalperning yarim sessiyasi. Zararlar bu strategiyada normal - ular statistikaning bir qismi, jazo emas.
input int               PostLossCooldownMinutes  = 5;   // Post loss cooldown minutes
// MaxDailyEntryAttempts: Safety cap: max new-basket attempts per day (stops runaway looping). 200 is generous for normal use.
input int               MaxDailyEntryAttempts    = 600;   // Max daily entry attempts
// MaxDailyGridAttempts: Safety cap: max grid-add attempts per day.
input int               MaxDailyGridAttempts     = 200;   // Max daily grid attempts
// RiskMaxSpreadPoints: Risk-engine spread ceiling (points). Note: with UseUnifiedMaxSpread ON, the unified spread value overrides this everywhere.
input int               RiskMaxSpreadPoints      = 300;   // Risk max spread points
// RiskBlockNewEntry: When any risk limit is hit, block NEW first entries.
input bool              RiskBlockNewEntry        = true;   // Risk block new entry (on/off)
// RiskBlockGrid: When any risk limit is hit, block GRID additions too.
input bool              RiskBlockGrid            = true;   // Risk block grid (on/off)
// UseFirstEntrySL: Put an individual SL on the FIRST entry only. Rarely used with a basket system - the Basket SL above is the real protection.
input bool              UseFirstEntrySL          = false;   // Use first entry SL
// FirstEntrySLPoints: Size of that first-entry SL in points. On this 3-digit broker 1000 points = $1. 0 = no individual SL.
input int               FirstEntrySLPoints       = 0;   // First entry SL points

// --- Secondary DD thresholds - each INACTIVE by default. Shown together here so a value
// is easy to find if you ever want to re-arm one, and won't silently fight the limits above. ---
// GridSafetyBlockDDRisk: OFF = grid spacing is distance-only (recommended). ON = also block grid by DD risk (can leave a basket stuck).
input bool              GridSafetyBlockDDRisk    = false;   // Grid safety block DD risk (on/off)
// GridSafetyMaxDDForNewGrid: If GridSafetyBlockDDRisk is ON: stop adding EARLY grid orders once DD passes this %.
input double            GridSafetyMaxDDForNewGrid = 14.0;   // Grid safety max DD for new grid
// RecoveryMaxDDForNewGrid: [SL CHECKLIST STEP 2] Stop adding grid orders (3+ orders in) once basket DD passes this %. Set = BasketSLPercent (e.g. 70) so grid stops right at the SL.
input double            RecoveryMaxDDForNewGrid  = 50.0;   // Recovery max DD for new grid
// UseServerDisasterSL: OFF - redundant with EmergencyDDPercent above. A backup broker-side disaster stop.
input bool              UseServerDisasterSL      = false;   // Use server disaster SL
// ServerDisasterDDPercent: If UseServerDisasterSL is ON: its trigger DD %.
input double            ServerDisasterDDPercent  = 35.0;   // Server disaster DD %
// P4MiniBlockGridAboveProfileDD: OFF = grid stays distance-only. (P4-mini profile-specific DD grid block.)
input bool              P4MiniBlockGridAboveProfileDD = false;   // P4 mini block grid above profile DD (on/off)
// P4MiniConservativeMaxDD: Only used if P4MiniBlockGridAboveProfileDD is ON (it's OFF by default): grid-stop DD % for the Conservative profile.
input double            P4MiniConservativeMaxDD  = 10.0;   // P4 mini conservative max DD
// P4MiniBalancedMaxDD: Only used if P4MiniBlockGridAboveProfileDD is ON: grid-stop DD % for the Balanced profile.
input double            P4MiniBalancedMaxDD      = 18.0;   // P4 mini balanced max DD
// P4MiniAggressiveMaxDD: Only used if P4MiniBlockGridAboveProfileDD is ON: grid-stop DD % for the Aggressive profile.
input double            P4MiniAggressiveMaxDD    = 25.0;   // P4 mini aggressive max DD

// --- Soft caution only (lot/distance trim, never blocks or closes) ---
input double            ClientSafetyDDWarnPercent = 10.0;   // Client safety DD warn %
input double            ClientSafetyDDDangerPercent = 16.0;   // Client safety DD danger %

input group "ADVANCED ▸ TP / profit settings"
// UseFixedTP: Use FixedTPPoints as the base TP instead of UseBasketTP below
input bool              UseFixedTP               = true;   // Use fixed TP
// FixedTPPoints: Base TP (points) when UseFixedTP=true
input int               FixedTPPoints            = 2500;   // Fixed TP points
// UseBasketTP: Use BasketTPPoints as the base TP when UseFixedTP=false
input bool              UseBasketTP              = true;   // Use basket TP
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
// RebateTPMaxSpreadPoints: S-FIX: spread above which the target stops growing. A target built from the spread moves furthest away exactly when it is hardest to reach - during a release the spread can run six times normal and the basket is asked for a move it was never sized for. The spread is an entry cost, not a measure of how far price will travel.
input int    RebateTPMaxSpreadPoints     = 350;   // Cashback TP max spread points
// RebateTPCapPrintOnUse: Log when the target is held
input bool   RebateTPCapPrintOnUse       = true;   // Cashback TP cap print on use (on/off)
input double RebateGridSpacingMultiple   = 3.0;   // Cashback grid spacing multiple
// ---- BOSQICH 17: CASHBACK REJIMINI KUCHAYTIRISH ----
// EnableRebateTrailingMode: OFF (egasi qarori): cashback rejimida trailing YO'Q - savat eski qat'iy TP da yopiladi. Trailing faqat oddiy rejimda (aqlli yuguruvchi). true = eski cashback trailing (TP x LockFraction qulf)
input bool   EnableRebateTrailingMode = false;   // Enable Cashback trailing mode
// RebateTrailLockFraction: Qulf = TP x shu. TP ga yetgandan keyin savat kamida shuncha foyda bilan yopiladi (0.10-0.95)
input double RebateTrailLockFraction  = 0.75;   // Cashback trail lock fraction
// RebateTrailStepFraction: Kuzatish masofasi = TP x shu: cho'qqidan shuncha qaytsa savat yopiladi
input double RebateTrailStepFraction  = 0.50;   // Cashback trail step fraction
// RebateTrailMinStepPoints: Kuzatish masofasi bundan kichik bo'lmaydi (3 xonali: 120 = $0.12)
input int    RebateTrailMinStepPoints = 120;   // Cashback trail min step points
// EnableBrokerTrailSL: Trailing qulfi brokerga REAL stop-loss sifatida yoziladi (faqat savat foydada bo'lganda). VPS/terminal uzilsa ham foyda saqlanadi. Zarardagi grid'ga SL qo'yilmaydi
input bool   EnableBrokerTrailSL      = true;   // Enable broker trail SL
// BrokerTrailMinMovePoints: Broker SL kamida shuncha punkt yaxshilansa yangilanadi
input int    BrokerTrailMinMovePoints = 20;   // Broker trail min move points
// BrokerTrailMinIntervalSec: Broker SL yangilanishlari orasidagi minimal soniya
input int    BrokerTrailMinIntervalSec = 2;   // Broker trail min interval sec
input bool   BrokerTrailPrintOnUse    = true;   // Broker trail print on use (on/off)
// RebateTimeFlat: Savat juda uzoq ochiq qolsa va MINUSDA bo'lmasa - yopiladi. Maqsad: joyni bo'shatish, keyingi savat -> ko'proq aylanma -> ko'proq cashback
input bool   RebateTimeFlat           = true;   // Cashback time flat (on/off)
// RebateMaxBasketBars: Shuncha M1 bar (daqiqa) dan keyin
input int    RebateMaxBasketBars      = 25;   // Cashback max basket bars
// RebateTimeFlatMinProfit: Faqat foyda shundan katta yoki teng bo'lsa yopiladi (0 = nolga teng ham bo'ladi). MINUSDA HECH QACHON yopmaydi    // V286: grid spacing as a multiple of the rebate target. The ordinary spacing is sized for a $2.50 target; against a break-even target it would ask price to give back several times what the basket is trying to recover. Three keeps the ladder proportionate to its own target.
input double RebateTimeFlatMinProfit  = 0.0;   // Cashback time flat min profit

// V31.6e cleanup: removed UseAdaptiveTP - was dead, and redundant with EnableATRAdaptiveTP anyway.
input bool              UseIndividualTPForFirstEntry = true;   // Use individual TP for first entry
input int               FirstEntryTPMinPoints    = 2000;   // First entry TP min points
// ============================================================================
// v291b: JOY HIMOYASI - alohida blok. Motorga (signal, ball, kutish, grid, risk) TEGMAYDI.
// Faqat birinchi kirishning oxirgi darvozasida (FirstEntryCanRun) bitta savol: joy ahmoqonami?
//   - SELL ko'p marta qaytargan support'ning shundoq ustida / BUY resistance'ning ostida
//   - yangi katta impuls shamining tanasi ichida, unga qarshi kirish
// Teskari yo'nalish har doim ochiq. Grid qo'shishlariga ta'sir qilmaydi.
// ============================================================================
// EnableLocationGuard: Joy himoyasi: supportda SELL, resistance da BUY, yangi impuls ichida qarshi kirish yo'q
input bool   EnableLocationGuard     = true;   // Enable location guard
// LGLookbackM5: M5 shamlar (8 soat)
input int    LGLookbackM5            = 96;   // Lg lookback M5
// LGLookbackM15: M15 shamlar (24 soat)
input int    LGLookbackM15           = 96;   // Lg lookback M15
// LGMinRejections: Shuncha ALOHIDA qaytish - kuchli daraja (katta qaytish 2 ga teng)
input int    LGMinRejections         = 3;   // Lg min rejections
// LGConfluenceRejections: Zona xaritasi ham tasdiqlasa shuncha yetarli
input int    LGConfluenceRejections  = 2;   // Lg confluence rejections
// LGStrongBounceATR: Shuncha ATR qaytish - "katta" (ikki hisoblanadi)
input double LGStrongBounceATR       = 1.5;   // Lg strong bounce ATR
// LGTouchATR: Tegish toleransi (ATR)
input double LGTouchATR              = 0.35;   // Lg touch ATR
// LGSeparationATR: Ikki qaytish orasida narx shuncha uzoqlashishi kerak
input double LGSeparationATR         = 0.8;   // Lg separation ATR
// LGMinWickATR: Rad etish soyasi kamida shuncha ATR
input double LGMinWickATR            = 0.25;   // Lg min wick ATR
// LGWickShare: Soya shamning kamida shuncha qismi
input double LGWickShare             = 0.40;   // Lg wick share
// LGMaxDistATR: "Shundoq yonida": daraja narxdan shuncha M5 ATR ichida VA TP yo'lida
input double LGMaxDistATR            = 1.0;   // Lg max distance ATR
// LGOnLevelATR: Darajaning ustida - TP dan qat'i nazar
input double LGOnLevelATR            = 0.30;   // Lg on level ATR
// LGPierceATR: Soya bilan teshish (yopilishsiz) shu chuqurlikkacha - daraja hali tirik
input double LGPierceATR             = 0.5;   // Lg pierce ATR
// LGUseFreshImpulse: Yangi impuls tanasi ichida qarshi kirish yo'q
input bool   LGUseFreshImpulse       = true;   // Lg use fresh impulse (on/off)
// LGImpulseLookbackM5: Impuls "yangi" hisoblanadigan vaqt (M5, 30 daqiqa)
input int    LGImpulseLookbackM5     = 6;   // Lg impulse lookback M5
// LGImpulseRangeATR: Impuls sham diapazoni kamida shuncha ATR
input double LGImpulseRangeATR       = 2.0;   // Lg impulse range ATR
// LGImpulseBodyShare: Impuls sham tanasi kamida shuncha qism
input double LGImpulseBodyShare      = 0.60;   // Lg impulse body share
// LGSwingGuard: M5 va M15 dagi SWING HIGH = resistance, SWING LOW = support. Uning ostida (zona ichida) BUY, ustida SELL yo'q - tegishlar soni va TP dan qat'i nazar
input bool   LGSwingGuard            = true;   // Lg swing guard (on/off)
// LGSwingDepth: Swing: har ikki tomonda shuncha sham undan past (high) / baland (low)
input int    LGSwingDepth            = 3;   // Lg swing depth
// LGSwingLookM15: S-FIX: 48 -> 200. Forty-eight M15 bars is twelve hours - the zones price reacted to this morning and nothing from yesterday. M15 is where the clean zones are drawn, and two days of them is what makes them worth reading. The build is cached per bar and the array already holds four hundred, so this costs one scan a bar and no memory.     // M15 shamlar (12 soat)
input int    LGSwingLookM15          = 200;   // Lg swing look M15
// LGSwingLookM5: S-FIX: 48 -> 120. Ten hours of M5 rather than four - enough to hold the session's own structure.     // M5 shamlar (4 soat)
input int    LGSwingLookM5           = 120;   // Lg swing look M5
input double LGSwingBandATR          = 0.8;   // Lg swing band ATR
// LGSwingUseM1: BOSQICH 6: M1 swinglar ham zona - narx M1 zonalardan ham reaksiya oladi
input bool   LGSwingUseM1            = true;   // Lg swing use M1 (on/off)
// LGSwingLookM1: M1 shamlar (1 soat)
input int    LGSwingLookM1           = 60;   // Lg swing look M1
input double LGSwingMinReactATR      = 1.0;   // Lg swing min react ATR
// LGHoldBeyondBarsM1: BOSQICH 11: 3 -> 2 (siz sinab ko'rgan qiymat)
input int    LGHoldBeyondBarsM1      = 2;   // Lg hold beyond bars M1
// ---- BOSQICH 11: ZONA DVIGATELI ----
// ZoneEngineOn: Darajalar klasterlanib HUDUD bo'ladi; rol (support/resistance) narxning qaysi tomonida ekaniga qarab aniqlanadi
input bool   ZoneEngineOn            = true;   // Zone engine on (on/off)
// ZoneClusterATR: Bir-biridan shu M5 ATR ichidagi darajalar bitta hudud
input double ZoneClusterATR          = 0.50;   // Zone cluster ATR
// ZoneBandATR: Hudud chetidan shu masofada - "hudud yonida"
input double ZoneBandATR             = 0.80;   // Zone band ATR
// ZoneMinWeight: Hudud vazni shundan kam bo'lsa - to'siq emas (vazn: reaksiya kuchi + daraja soni + TF)
input double ZoneMinWeight           = 2.0;   // Zone min weight
// ZoneLogOnUse: Hududlarni logga yozish (diagnostika)
input bool   ZoneLogOnUse            = false;   // Zone log on use (on/off)
// ---- BOSQICH 18: KATTA TF HUDUDLARI ----
// ZoneUseHTF: M30 va H1 swinglari ham hudud beradi. Ilgari dvigatel M15 gacha qarardi - shuning uchun H1 dagi 4291-4300 kabi hudud ko'rinmasdi
input bool   ZoneUseHTF               = true;   // Zone use HTF (on/off)
// ZoneLookM30: S-FIX: 48 -> 96. Two days of M30.     // M30 shamlar (24 soat)
input int    ZoneLookM30              = 96;   // Zone look M30
// ZoneLookH1: S-FIX: 48 -> 120. Five days of H1 - the level that ends an intraday move is usually drawn here.     // H1 shamlar (48 soat)
input int    ZoneLookH1               = 120;   // Zone look H1
// ZoneWickArea: Katta TF da daraja NUQTA emas, HUDUD: shamning soya maydoni (low..tana pastki qismi / tana yuqori qismi..high) - treyder chizganidek
input bool   ZoneWickArea             = true;   // Zone wick area (on/off)
// ZoneHTFWeightH1: H1 darajasi vazni
input double ZoneHTFWeightH1          = 2.0;   // Zone HTF weight H1
input double ZoneHTFWeightM30         = 1.7;   // Zone HTF weight M30
// ZoneInsideBlockShare: BOSQICH 19: hududning FAQAT kirish tomonidagi shu qismi to'sadi. Support hududiga yuqoridan kelgan SELL uchun eng xavfli joy - hududning yuqori qismi (xaridorlar shu yerda). Narx hududning pastki qismiga yetgan bo'lsa, u xaridorlarni allaqachon singdirgan - davom etish ochiq. 1.0 = butun hudud to'sadi (eski xulq)    // M30 darajasi vazni  // Hududlarni logga yozish (diagnostika)
input double ZoneInsideBlockShare     = 0.60;   // Zone inside block share

//--- LOCATION BRAIN -------------------------------------------------------------------
// The zone engine answers "is there a level in the way" - a question about price. The two stops
// that cost the account were not about price: a SELL at the bottom of a four-dollar fall is wrong
// even with no level anywhere near it, because price turns there from being stretched, not from
// meeting something. Nothing was asking WHEN - only WHERE.
//
// Asked last, after every other gate. Nothing is refused; it is held, and the arming engine
// releases it when price comes to somewhere worth paying.
// EnableLocationBrain: The last word before an entry opens
input bool   EnableLocationBrain         = true;   // Enable location brain
// LBTimeframe: Where the leg is measured
input ENUM_TIMEFRAMES LBTimeframe        = PERIOD_M5;   // Lb timeframe
// LBMaxLegBars: Furthest back a leg can start
input int    LBMaxLegBars                = 40;   // Lb max leg bars
// LBLegSettleBars: Bars without a new extreme that end the leg. Not a fixed window - a fixed one makes a falling market read as permanently at the bottom and the robot stops trading for hours.
input int    LBLegSettleBars             = 4;   // Lb leg settle bars
// LBMinLegATR: Leg size below which position means nothing
input double LBMinLegATR                 = 1.2;   // Lb min leg ATR
// LBSellMinPosition: A SELL wants to be at least this far up the leg
input double LBSellMinPosition           = 0.35;   // Lb sell min position
// LBBuyMaxPosition: A BUY wants to be at most this far up it
input double LBBuyMaxPosition            = 0.65;   // Lb buy max position
// LBStretchFromATR: Leg length where the demand starts rising
input double LBStretchFromATR            = 3.0;   // Lb stretch from ATR
// LBStretchFullATR: And where the extra demand is complete
input double LBStretchFullATR            = 6.0;   // Lb stretch full ATR
// LBStretchExtra: How much further into the leg a stretched move must pull back before it is worth joining
input double LBStretchExtra              = 0.20;   // Lb stretch extra
// LBBlockWorseThanStop: After a stop, the next trade that way must beat the price that failed
input bool   LBBlockWorseThanStop        = true;   // Lb block worse than stop (on/off)
// LBBetterThanStopPoints: By at least this much ($0.80)
input int    LBBetterThanStopPoints      = 800;   // Lb better than stop points
// LocationBrainPrintOnUse: Log holds and stops
input bool   LocationBrainPrintOnUse     = true;   // Location brain print on use (on/off)
// ShowLocationBrainOnDash: Show the leg line
input bool   ShowLocationBrainOnDash     = true;   // Show location brain on dashboard

//--- HIGHER TIMEFRAME BIAS ------------------------------------------------------------
// Fifty-six setup detectors read M15 or M5; fourteen read H1 or above. That is the right balance
// for three hundred trades a day - the daily chart does not produce three hundred opportunities -
// and it is also why a BUY gets taken on an M15 pullback while the daily has fallen for a week.
//
// Refusing those trades is the wrong fix; it would cut the count to a fraction. So the higher
// timeframes do not veto. They raise the price of admission: a setup against a strong daily needs
// a better score and a better place in its leg, and the marginal ones stop clearing the bar while
// the good ones still do.
// EnableHTFBias: Let D1 and H4 raise the price of trading against them
input bool   EnableHTFBias               = true;   // Enable HTF bias
// HTFLookD1: Daily bars read
input int    HTFLookD1                   = 10;   // HTF look D1
// HTFLookH4: H4 bars read
input int    HTFLookH4                   = 18;   // HTF look H4
// HTFWeightD1: How much the daily counts
input double HTFWeightD1                 = 0.65;   // HTF weight D1
// HTFWeightH4: And H4
input double HTFWeightH4                 = 0.35;   // HTF weight H4
// HTFMinTravelATR: Travel below which a timeframe says nothing. A daily drifting sideways changes nothing; one that has run says plenty.
input double HTFMinTravelATR             = 2.0;   // HTF min travel ATR
// HTFFullTravelATR: Travel at which it counts fully
input double HTFFullTravelATR            = 6.0;   // HTF full travel ATR
// HTFMinEfficiency: Net over walked distance. Six dollars in a straight line is a trend; six dollars wandering is not, and their closes look identical.
input double HTFMinEfficiency            = 0.45    ;   // HTF min efficiency
// HTFRequireAgreement: D1 and H4 must at least agree on direction - one running while the other goes the other way is a disagreement, not a trend
input bool   HTFRequireAgreement         = true;   // HTF require agreement (on/off)
// HTFMinForceToCount: Conviction below which nothing is charged
input double HTFMinForceToCount          = 0.30;   // HTF min force to count
// HTFAgainstScoreExtra: Extra score a counter-trend setup must find
input int    HTFAgainstScoreExtra        = 4;   // HTF against score extra
// HTFAgainstLocationExtra: And how much further into its leg it must have pulled back
input double HTFAgainstLocationExtra     = 0.12;   // HTF against location extra
// ShowHTFOnDash: Show the bias line
input bool   ShowHTFOnDash               = true;   // Show HTF on dashboard

//--- OLD LEVEL GUARD ------------------------------------------------------------------
// Price pushes through the high next to it, the breakout fires, and it runs into a level from six
// weeks back and collapses. The move was never a breakout - the market was collecting the stops
// above that recent high on its way to something it actually cared about.
//
// The zone engine builds from about two days, which is right for the zones price is reacting to
// now and blind to the one that ends the move. ZoneMap already holds four months and is read in a
// hundred places, none of them the location check - so nothing had to be built; the long history
// was there and the entry gate was not asking it.
// EnableOldLevelGuard: Charge a breakout running into an old, proven level
input bool   EnableOldLevelGuard         = true;   // Enable old level guard
// OldLevelOnlyBreakouts: Reversal setups pay nothing - heading into the level that stops price IS the trade, not a problem with it
input bool   OldLevelOnlyBreakouts       = true;   // Old level only breakouts (on/off)
// OldLevelLookD1: Daily bars searched (about three months)
input int    OldLevelLookD1              = 60;   // Old level look D1
// OldLevelLookH4: H4 bars (about three weeks)
input int    OldLevelLookH4              = 120;   // Old level look H4
// OldLevelLookH1: H1 bars - nearly two months. The level that ends an intraday move is often drawn on H1, too small to leave a daily extreme and far too old for a two-day zone engine.
input int    OldLevelLookH1              = 300;   // Old level look H1
// OldLevelLookM30: M30 bars - about three weeks
input int    OldLevelLookM30             = 400;   // Old level look M30
// OldLevelMinAgeBars: How far back a level must be to count as old
input int    OldLevelMinAgeBars          = 5;   // Old level min age bars
// OldLevelReachPoints: How far ahead ($6.00) one still matters
input int    OldLevelReachPoints         = 6000;   // Old level reach points
// OldLevelTouchTolerance: How close ($0.80) counts as touching it again
input int    OldLevelTouchTolerance      = 800;   // Old level touch tolerance
// OldLevelMinTouches: Touches below which it is just a high, not a level
input int    OldLevelMinTouches          = 2;   // Old level min touches
// OldLevelFullTouches: Touches at which it counts fully
input int    OldLevelFullTouches         = 4;   // Old level full touches
// OldLevelScoreCost: Most score a breakout into one has to find
input int    OldLevelScoreCost           = 5;   // Old level score cost
// ShowOldLevelOnDash: Show the old level line
input bool   ShowOldLevelOnDash          = true;   // Show old level on dashboard

//--- APPROACH TRAVEL ------------------------------------------------------------------
// The market grinds down a hundred dollars - 4450 to 4350 - and then turns hard off some zone. On
// the way down every pullback looked like a sell and the robot took them, and the turn caught it
// with the deepest basket of the move.
//
// The grind is the danger and it is invisible to anything reading one leg, because it is made of
// many legs each of which looked ordinary. So the distance price has COME to reach a level is
// weighed alongside the level itself: a hundred dollars spent getting here means the sellers are
// spent too, and when it turns it turns hard.
// EnableApproachTravel: Weigh how far price travelled to reach the level
input bool   EnableApproachTravel        = true;   // Enable approach travel
// ApproachTravelTF: Where the approach is measured
input ENUM_TIMEFRAMES ApproachTravelTF   = PERIOD_M30;   // Approach travel TF
// ApproachTravelBars: Bars searched - two days on M30
input int    ApproachTravelBars          = 96;   // Approach travel bars
// ApproachTravelFromATR: Travel below which the approach says nothing
input double ApproachTravelFromATR       = 6.0;   // Approach travel from ATR
// ApproachTravelFullATR: And where it counts fully - a hundred dollars of grind
input double ApproachTravelFullATR       = 18.0;   // Approach travel full ATR
// ApproachTravelWeight: How much a long approach multiplies the level's cost
input double ApproachTravelWeight        = 1.20;   // Approach travel weight

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
// EnableScenario: Record what reactions at each kind of level actually do
input bool   EnableScenario              = true;   // Enable scenario

//--- DIRECTION CONSENSUS --------------------------------------------------------------
// Twenty detectors each propose a direction and the engine takes the single highest score. It has
// never counted how many agreed - so seven detectors at five lose to one outlier at eight, and the
// outlier is the entry that gets taken.
//
// Seven modules seeing the same thing is better evidence than one module seeing it strongly. Not
// always better - a genuinely strong setup keeps its place - but a lone voice should not beat a
// crowd by three points.
// EnableDirectionConsensus: Let a clear majority of detectors override a lone high score
input bool   EnableDirectionConsensus    = true;   // Enable direction consensus
// ConsensusVoiceEdge: How many more voices the other side needs. Three, not one - a one-voice majority is noise.
input int    ConsensusVoiceEdge          = 3;   // Consensus voice edge
// ConsensusMaxScoreGap: Score gap above which the lone voice keeps its place anyway. A genuinely strong setup is not outvoted.
input int    ConsensusMaxScoreGap        = 4;   // Consensus max score gap
// ConsensusPrintOnUse: Log overrides
input bool   ConsensusPrintOnUse         = true;   // Consensus print on use (on/off)

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
// EnableRedirectChecks: Make a flipped direction pass the same guards as an original one
input bool   EnableRedirectChecks        = true;   // Enable redirect checks
// RedirectMinVoices: Detectors that must have seen the direction being flipped to. One is not a setup.
input int    RedirectMinVoices           = 2;   // Redirect min voices
// RedirectMaxHTFCost: HTF cost above which a flip is refused
input int    RedirectMaxHTFCost          = 2;   // Redirect max HTF cost
// EnableQueueLocationRecheck: Re-ask the location brain before replaying a queued signal
input bool   EnableQueueLocationRecheck  = true;   // Enable queue location recheck
// QueueRecheckPrintOnUse: Log held replays
input bool   QueueRecheckPrintOnUse      = true;   // Queue recheck print on use (on/off)

// EnableDirectionClarity: Charge a direction that barely won. A BUY at eight beating a SELL at seven is not a direction, it is a coin landing on its edge - and the engine already knew both numbers and never used the difference.
input bool   EnableDirectionClarity      = true;   // Enable direction clarity
// ClarityLowBelow: Clarity below which the direction is called contested
input double ClarityLowBelow             = 0.25;   // Clarity low below
// ClarityScoreCost: Score a contested direction has to find
input int    ClarityScoreCost            = 3;   // Clarity score cost
// PersistScenario: Keep the record across restarts
input bool   PersistScenario             = true;   // Persist scenario (on/off)
// ScenarioTF: Where travel is measured
input ENUM_TIMEFRAMES ScenarioTF         = PERIOD_M15;   // Scenario TF
// ScenarioTouchTolerance: How close ($0.50) counts as being at the level
input int    ScenarioTouchTolerance      = 500;   // Scenario touch tolerance
// ScenarioMaxBars: Bars after which a reaction has stopped being one
input int    ScenarioMaxBars             = 24;   // Scenario max bars
// ScenarioMinSamples: Samples below which the file says nothing
input int    ScenarioMinSamples          = 8;   // Scenario min samples
// ScenarioWindow: Samples after which the file is halved, so it follows recent behaviour
input int    ScenarioWindow              = 40;   // Scenario window
// ScenApproachLow: Approach ATR dividing a short run from a medium one
input double ScenApproachLow             = 6.0;   // Scen approach low
// ScenApproachHigh: And medium from a grind
input double ScenApproachHigh            = 14.0;   // Scen approach high
// ScenGridMinATR: S-GRID: projection a reaction must promise before a rung is added. A rung opened into a bounce that has already finished is how the grind collects baskets.
input double ScenGridMinATR              = 2.0;   // Scen grid min ATR
// ScenarioShallowATR: Projection below which a reaction is shallow - touches the target and leaves nothing behind it
input double ScenarioShallowATR          = 0.8;   // Scenario shallow ATR
// ScenEntryScoreWeight: S-ENTRY: score a strong projection adds, or a shallow one takes. A pull, not a gate - there are eleven gates already and a twelfth would be the one that stops the robot trading.
input int    ScenEntryScoreWeight        = 3;   // Scen entry score weight
// ScenRecordPrintOnUse: Log each recorded reaction
input bool   ScenRecordPrintOnUse        = true;   // Scen record print on use (on/off)

//--- FAILED BREAK ---------------------------------------------------------------------
// An impulse drives down through support and the bar closes back above it. The low went through;
// the close did not. Readings that work on closes see a level that held; readings that work on
// extremes see one that broke - same bar, and the close is the one that is right.
//
// The EA sells into that, because something registered a break. It is the opposite: support just
// tested and held is the strongest it will ever be, because everyone who sold the break is now
// trapped underneath it.
// EnableFailedBreakGuard: Charge trades that follow a break the close took back
input bool   EnableFailedBreakGuard      = true;   // Enable failed break guard
// SweepReadTF: Where the sweep is read
input ENUM_TIMEFRAMES SweepReadTF        = PERIOD_M5;   // Sweep read TF
// FailedBreakBars: Bars back a sweep still counts
input int    FailedBreakBars             = 3;   // Failed break bars
// FailedBreakLevelLook: Bars before it that define the level
input int    FailedBreakLevelLook        = 20;   // Failed break level look
// FailedBreakMinDepthATR: How far past the level the extreme must have gone
input double FailedBreakMinDepthATR      = 0.35;   // Failed break min depth ATR
// FailedBreakFullDepthATR: Depth at which the reading counts fully
input double FailedBreakFullDepthATR     = 1.20;   // Failed break full depth ATR
// FailedBreakScoreCost: Most score a trade following the failed break must find
input int    FailedBreakScoreCost        = 6;   // Failed break score cost
// ShowFailedBreakOnDash: Show the line
input bool   ShowFailedBreakOnDash       = true;   // Show failed break on dashboard

//--- DECISION LOG ---------------------------------------------------------------------
// EnableDecisionLog: S-FIX: one line per decision. A day went to guessing which of twenty-two gates was closed, six times, wrong each time - the EA knew the answer every time it refused and never wrote it down where anyone could read it back.
input bool   EnableDecisionLog           = true;   // Enable decision log
// EnableGateRegistry: S-FIX: name every refusal. Seventy-one places can refuse an entry and none of them says which module it was - the dashboard could say "refused" and not by what, which is how a day went to guessing, six times, wrong each time.
input bool   EnableGateRegistry          = true;   // Enable gate registry
// ShowGateTallyOnDash: Show the day's refusals, busiest first
input bool   ShowGateTallyOnDash         = true;   // Show gate tally on dashboard
// EnableQuietAlarm: S-FIX: count the bars since anything opened. Every guard here is reasonable alone and none knows the others exist - six reasonable costs in a row is a robot that does not trade, arriving without anything being wrong. This reports it; it does not loosen anything, because a robot that relaxes its own standards when bored takes the trade it was right to refuse.
input bool   EnableQuietAlarm            = true;   // Enable quiet alarm
// QuietAlarmBars: Bars of silence after which the dashboard says so
input int    QuietAlarmBars              = 40;   // Quiet alarm bars
// QuietAlarmPrintOnUse: Log it once when it starts
input bool   QuietAlarmPrintOnUse        = true;   // Quiet alarm print on use (on/off)

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
// EnableSafetyValve: Stand down an added guard when it alone is causing the silence
input bool   EnableSafetyValve           = true;   // Enable safety valve
// SafetyValveBars: Bars of quiet before the valve considers acting
input int    SafetyValveBars             = 60;   // Safety valve bars
// SafetyValveOffBars: How long the guard stands down
input int    SafetyValveOffBars          = 30;   // Safety valve off bars
// SafetyValveMinShare: Share of refusals one guard must own. Below this the silence is spread across gates, which is the market rather than a threshold.
input double SafetyValveMinShare         = 0.65;   // Safety valve min share
// SafetyValveMaxPerDay: Most times a day the valve may act. A guard that needs standing down five times is a guard to retune, not to keep bypassing.
input int    SafetyValveMaxPerDay        = 4;   // Safety valve max per day
// SafetyValvePrintOnUse: Log when a guard comes back
input bool   SafetyValvePrintOnUse       = true;   // Safety valve print on use (on/off)
// QuietSingleCauseShare: Share of refusals from one gate that makes it the cause rather than one of several. Forty bars of quiet from the news guard is a closed market; forty from the location brain is a threshold worth looking at, and the bar count alone cannot tell them apart.
input double QuietSingleCauseShare       = 0.70;   // Quiet single cause share

//--- TIGHTENING ON EVIDENCE -----------------------------------------------------------
// Loosening when quiet is the wrong direction: quiet has two causes and the robot cannot tell them
// apart. The thresholds may be too strict - or the market may be in the grind these guards exist to
// survive, and loosening there is how the hundred-dollar fall catches the deepest basket.
//
// Losing is different. A run of losses is not an opinion about what the market might do; it is what
// already happened. So this only goes one way: more careful on evidence, never less careful from
// boredom.
// EnableEvidenceTighten: Let losses raise the location demand
input bool   EnableEvidenceTighten       = true;   // Enable evidence tighten
// EvidenceMinTrades: Trades before the record means anything
input int    EvidenceMinTrades           = 10;   // Evidence min trades
// EvidenceWindow: Trades after which the record is halved, so it follows recent trading
input int    EvidenceWindow              = 30;   // Evidence window
// EvidenceBadWinRate: Win rate below which it tightens
input double EvidenceBadWinRate          = 0.40;   // Evidence bad win rate
// EvidenceGoodWinRate: And above which the extra demand is released
input double EvidenceGoodWinRate         = 0.55;   // Evidence good win rate
// EvidenceStep: How much the demand moves each step
input double EvidenceStep                = 0.04;   // Evidence step
// EvidenceMaxExtra: Most it can add. A bad run is not proof every future entry is bad, and a guard that walks itself up forever ends as a robot that does not trade.
input double EvidenceMaxExtra            = 0.15;   // Evidence max extra
// EvidenceTightenPrintOnUse: Log each adjustment
input bool   EvidenceTightenPrintOnUse   = true;   // Evidence tighten print on use (on/off)
// DecisionLogRepeatSeconds: Don't repeat the same line more often than this
input int    DecisionLogRepeatSeconds    = 60;   // Decision log repeat seconds
// ---- BOSQICH 12: S/R DVIGATELI ----
// SRCompressionATR: Support va resistance orasi shu M5 ATR dan tor bo'lsa - bu alohida S va R emas, SIQILISH hududi: hudud to'sig'i o'chadi, qaror ballga qoladi
input double SRCompressionATR        = 1.5;   // SR compression ATR
// SRNeverBlockBoth: Narx ikki hudud orasida siqilib qolsa - faqat YAQINROG'I to'sadi, ikkala yo'nalish birdan yopilmaydi
input bool   SRNeverBlockBoth        = true;   // SR never block both (on/off)
// SRMicroBreakAllow: Oxirgi M1 shami hudud chetidan tana bilan o'tib yopilgan bo'lsa (displacement) - hudud to'siq emas
input bool   SRMicroBreakAllow       = true;   // SR micro break allow (on/off)
// SRMicroBreakBodyATR: Displacement shami diapazoni kamida shuncha M1 ATR  // Hududlarni logga yozish (diagnostika)      // BOSQICH 9: narx darajaning ortida shuncha ketma-ket M1 shamida yopilsa (kichik farq bilan ham) - daraja singan
input double SRMicroBreakBodyATR     = 1.0;   // SR micro break body ATR
// LGSwingFlip: BOSQICH 8: ROL ALMASHISHI. Yopilish bilan singan swing high - endi SUPPORT, singan swing low - endi RESISTANCE (M1/M5/M15). Break-retest'da teskari kirish yo'q: bullish sinishdan keyin retestda SELL, bearish sinishdan keyin retestda BUY    // BOSQICH 6: swing faqat narx undan shu TF ning kamida shuncha ATR qaytgan bo'lsa zona. Mayda to'lqin zona emas, reaksiya bergan joy - zona    // Zona kengligi: swing'dan shuncha M5 ATR ichida - "zona ichida"
input bool   LGSwingFlip             = true;   // Lg swing flip (on/off)
// LGBlockChase: Katta shamning TEPASIDA (BUY) / TUBIDA (SELL) uni quvib kirish yo'q - hozir shakllanayotgan sham ham hisobga olinadi
input bool   LGBlockChase            = true;   // Lg block chase (on/off)
// LGChaseTopShare: Sham diapazonining eng chekka shu qismi - "tepa"
input double LGChaseTopShare         = 0.30;   // Lg chase top share
// LGChaseRangeATR: Sham diapazoni kamida shuncha M5 ATR bo'lsa - katta sham
input double LGChaseRangeATR         = 1.8;   // Lg chase range ATR
input bool   LGPrintOnUse            = true;   // Lg print on use (on/off)
// EnableWinReEntry: BOSQICH 5A: yutuqdan keyin O'SHA yo'nalishda talab qilinadigan ball kamayadi (zarardan keyin - o'zgarishsiz)
input bool   EnableWinReEntry        = true;   // Enable win re entry
// WinReEntryBars: Yutuqdan keyin shuncha M1 bar
input int    WinReEntryBars          = 15;   // Win re entry bars
// WinReEntryRelief: Shuncha ball yengillik
input int    WinReEntryRelief        = 2;   // Win re entry relief
// EnableGoodLocationBonus: BOSQICH 5B: BUY kuchli support ustida / SELL kuchli resistance ostida - ball yengilligi (yaxshi joy tezroq o'tadi)
input bool   EnableGoodLocationBonus = true;   // Enable good location bonus
// GoodLocationBonus: Shuncha ball
input int    GoodLocationBonus       = 2;   // Good location bonus
// ReliefMaxShortfall: Yengilliklar faqat talabdan shuncha yoki kamroq kam bo'lgan setupga qo'llanadi
input int    ReliefMaxShortfall      = 2;   // Relief max shortfall
// LGBlockMicroTip: Mayda harakatning UCHIDA kirmaslik: BUY oxirgi M1 oyog'ining tepasida, SELL tubida - kichik qaytishni kutadi
input bool   LGBlockMicroTip         = true;   // Lg block micro tip (on/off)
// LGTipBarsM1: Oyoq shuncha M1 sham ichida o'lchanadi
input int    LGTipBarsM1             = 10;   // Lg tip bars M1
// LGTipLegATR: Oyoq kamida shuncha M1 ATR bo'lsa - "harakat"
input double LGTipLegATR             = 1.5;   // Lg tip leg ATR
input double LGTipShare              = 0.20;   // Lg tip share
// LGTipMaxLegATR: BOSQICH 5b: oyoq shundan katta bo'lsa - bu mayda burilish emas, IMPULS. Uch qoidasi qo'llanmaydi (aks holda kuchli harakatda davom etish savdosi doim "uchida" bo'lib to'silardi)   // Oyoqning eng chekka shu qismi - "uch"
input double LGTipMaxLegATR          = 4.0;   // Lg tip max leg ATR
// LGLocationRedirect: BOSQICH 7: himoya bir yo'nalishni DARAJA sababli to'sganda (support'da SELL / resistance'da BUY) - o'sha zahoti teskari yo'nalishdagi setup tekshiriladi (support'dan BUY / resistance'dan SELL)
input bool   LGLocationRedirect      = true;   // Lg location redirect (on/off)
// ---- BOSQICH 14: MICRO / MINOR STRUKTURA ----
// MicroStructOn: M1 (micro) va M5 (minor) da: swing, BOS, MSS/CHOCH, displacement, impuls va korreksiya farqi
input bool   MicroStructOn           = true;   // Micro struct on (on/off)
// MicroSwingDepth: Swing uchun har ikki tomonda shuncha sham
input int    MicroSwingDepth         = 2;   // Micro swing depth
// MicroLookM1: M1 shamlar (1 soat)
input int    MicroLookM1             = 60;   // Micro look M1
// MicroLookM5: M5 shamlar (4 soat)
input int    MicroLookM5             = 48;   // Micro look M5
// MicroLookM15: BOSQICH 15b: M15 shamlar (12 soat) - LOCAL struktura va yo'nalish
input int    MicroLookM15            = 48;   // Micro look M15
input double MicroDisplaceATR        = 1.5;   // Micro displace ATR
// ---- BOSQICH 15: STRUKTURANI QARORGA ULASH (faqat o'tishga yordam beradi, yangi to'siq emas) ----
// MicroStructDecides: Micro/minor struktura kirish qaroriga ulansin
input bool   MicroStructDecides      = true;   // Micro struct decides (on/off)
// MicroStructRelief: Micro VA minor struktura kirish tomonida bo'lsa - talab qilinadigan ball shuncha kamayadi
input int    MicroStructRelief       = 2;   // Micro struct relief
// MicroOnlyRelief: Faqat micro (M1) kirish tomonida bo'lsa - shuncha
input int    MicroOnlyRelief         = 1;   // Micro only relief
// MicroZoneOverride: Micro BOS hududni yopilish bilan sindirgan bo'lsa - hudud to'siq emas (breakout/retest savdosi o'tadi)    // Sham diapazoni shuncha ATR dan katta va tanasi >=60% bo'lsa - displacement
input bool   MicroZoneOverride       = true;   // Micro zone override (on/off)
// LogDecisionChain: BOSQICH 13: har potentsial kirish uchun TO'LIQ qaror zanjiri bitta qatorda ([SIRUS CHAIN]). Bir barda bir marta, yo'nalish bo'yicha
input bool   LogDecisionChain        = true;   // Log decision chain
// LogDecisionChainAll: true = o'tgan kirishlar ham yoziladi, false = faqat rad etilganlar
input bool   LogDecisionChainAll      = false;   // Log decision chain all
// LogNearMiss: BOSQICH 4: ball talabdan 1-2 ga yetmagan setupning to'liq bonus/jazo ro'yxati logga ([SIRUS NEAR-MISS])
input bool   LogNearMiss             = true;   // Log near miss
// NearMissPoints: Talabdan shuncha yoki kamroq kam bo'lsa - "yaqin o'tkazib yuborish"
input int    NearMissPoints          = 2;   // Near miss points
   // Final TP floor for ALL entries incl. micro

input group "ADVANCED ▸ Trailing / profit lock"
// V31.6e cleanup: removed UseTrailingStop/TrailingStartPoints/TrailingStepPoints/UseBasketTrailing.
// These belonged only to the old, dormant duplicate trailing block removed this session.
// The real trailing system lives in section 07 (UseAdvancedBasketTrailing/BasketTrailStartPoints/etc).

input group "ADVANCED ▸ Grid / recovery settings"
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
// AllowGridAfterMicro: Allow grid adds even after a very small ("micro") first entry. Keep false normally.
input bool              AllowGridAfterMicro      = false;   // Allow grid after micro
// GridStartOrder: Which order number the grid logic starts at (2 = the first ADD after the first entry). Leave at 2.
input int               GridStartOrder           = 2;   // Grid start order
// MinGridLotFactor: Safety: the stacked caution modules may trim a grid add down to this fraction of its LotMultiplier target, but never below it (protects the averaging-down math). Leave at 0.5.
input double            MinGridLotFactor         = 0.5;   // Min grid lot factor
// EnableAbsoluteGridLotFloor: Keep ON. A firm floor on grid-add size anchored to StartLot x LotMultiplier^orders (which can't drift), fixing an old bug where adds silently shrank down the chain.
input bool              EnableAbsoluteGridLotFloor = true;   // Enable absolute grid lot floor
// AbsoluteGridLotFloorFactor: V222: 1.0 -> 0.80. At 1.0 this floor equalled the full intended progression, which meant every lot adjustment above it - grid intelligence, spread quality, margin level, swing correction, client safety, preset hardening - was computed and then discarded. Eight modules doing nothing. At 0.80 caution can trim up to a fifth of an addition, which is enough to matter and not enough to break the recovery arithmetic the ladder depends on.   // Fraction of the intended martingale step (StartLot x LotMultiplier^orders) below which a grid add can never fall. 1.0 = honour the full progression (0.25 -> 0.33 -> 0.42 -> 0.55 -> 0.71 -> 0.93): fastest recovery, largest risk build-up. Lower this (e.g. 0.7) to make the grid add more cautiously.
input double            AbsoluteGridLotFloorFactor = 0.80;   // Absolute grid lot floor factor
// EnableGridNeverBelowPrevious: V222: true -> false. This forced each addition to be at least as large as the one before it, which sounds like protecting the progression and in practice overrode every quality reading - an addition into a worse location was guaranteed to be bigger than one into a better one. The absolute floor above still holds the progression at 80%; what is removed is the rule that made caution impossible. // Keep ON. Never let a grid add be SMALLER than the order it's averaging down (an undersized add takes full new risk while barely improving the escape price). If only a tiny step fits, the EA adds nothing instead.
input bool              EnableGridNeverBelowPrevious = false;   // Enable grid never below previous
// EnableGridCautionHold: 3-muammo: ehtiyot modullari grid lotini poldan pastga tushirmoqchi bo'lsa, lot majburan ko'tarilmaydi - bu pog'ona vaqtincha ushlab turiladi
input bool              EnableGridCautionHold    = true;   // Enable grid caution hold
// GridCautionMaxHoldBars: Ko'pi bilan shuncha bar (M1) kutadi, keyin pol lot bilan qo'shadi
input int               GridCautionMaxHoldBars   = 10;   // Grid caution max hold bars
// GridCautionExtraDistFraction: Yoki narx grid masofasidan yana shuncha ulush uzoqlashsa (yaxshiroq o'rtacha narx) - darhol qo'shadi
input double            GridCautionExtraDistFraction = 0.5;   // Grid caution extra distance fraction
// AdaptiveGridATRMult: When AdaptiveGridDistance is ON: grid gap = ATR x this. Higher = wider spacing (adds farther apart).
input double            AdaptiveGridATRMult      = 1.10;   // Adaptive grid ATR multiplier
// GridMinDistancePoints: Floor for the adaptive gap (3-digit: 6000 = $6.00). The gap never goes tighter than this even in very calm markets.
input int               GridMinDistancePoints    = 6000;   // Grid min distance points
// GridMaxDistancePoints: Ceiling for the adaptive gap (14000 = $14.00). The gap never goes wider than this even in very volatile markets.
input int               GridMaxDistancePoints    = 14000;   // Grid max distance points
// GridCooldownBars: Minimum bars to wait between two grid adds (stops several adds stacking on one fast candle).
input int               GridCooldownBars         = 2;   // Grid cooldown bars
// GridMinSecondsBetweenOrders: Minimum seconds between two grid adds (a time-based version of the cooldown above).
input int               GridMinSecondsBetweenOrders = 120;   // Grid min seconds between orders
// GridRequireAdverseMove: ON = only add a grid order after price has actually moved AGAINST the basket by the grid distance (true averaging-down). Keep ON.
input bool              GridRequireAdverseMove   = true;   // Grid require adverse move (on/off)
// GridSameDirectionOnly: ON = every order in a basket is the same direction (all BUY or all SELL). Keep ON for this grid design.
input bool              GridSameDirectionOnly    = true;   // Grid same direction only (on/off)
input bool              GridBlockFreshImpulse    = true;   // Grid block fresh impulse (on/off)
// GridUseRecoveryDDTrigger: OFF - grid is distance-only; Basket SL handles losses
input bool              GridUseRecoveryDDTrigger = false;   // Grid use recovery DD trigger (on/off)

// FEATURE(grid-reaction): "reaction preference" for grid additions (user request, variant A).
// Normally a grid order needs price to travel the FULL grid distance against the basket. But if
// price reaches a strong opposing wall (resistance for a SELL basket / support for a BUY basket)
// and PRINTS A REJECTION - an M15 candle that poked the wall with a real wick and closed back on
// our side - that's a high-quality spot to add, better than a blind distance step. So we let the
// grid fire EARLY (at a reduced fraction of the full distance) when that reaction is present.
// Crucially this is a PREFERENCE, not a requirement: if no reaction appears, the grid still fires
// at the normal full distance, so the basket is never left unprotected waiting for a reaction.
// EnableGridReactionPreference: Allow an early grid add when price rejects at a strong opposing wall
input bool   EnableGridReactionPreference = true;   // Enable grid reaction preference
// GridReactionDistanceFraction: With a valid reaction, price only needs to travel this fraction of the full grid distance (0.6 = 60%)
input double GridReactionDistanceFraction = 0.6;   // Grid reaction distance fraction
// GridReactionMinWallStrength: The opposing wall must be at least this strong (ZoneMapStrength) to count
input double GridReactionMinWallStrength  = 1.8;   // Grid reaction min wall strength
// GridReactionWickRatioMin: The M15 rejection candle's wick must be at least this fraction of its range (matches the sweep standard)
input double GridReactionWickRatioMin     = 0.35;   // Grid reaction wick ratio min
// GridReactionWallProximityPts: Price must be within this many points of the wall for the reaction to count
input int    GridReactionWallProximityPts = 400;   // Grid reaction wall proximity points
input bool   GridReactionPrintOnUse       = true;   // Grid reaction print on use (on/off)

// FEATURE(grid-reaction-consensus): a single M15 rejection candle can be a fakeout. Instead of
// trusting one candle, require a genuine REVERSAL CONSENSUS in the direction that helps the
// basket - the same multi-signal engine used elsewhere (Swing+RSIdiv / BOS-CHoCH / Sweep /
// Engulfing). "At least 2 independent signals agree" is the bar, so no single pattern can trigger
// an early grid add on its own. The wall+rejection check above still runs first (price must be AT
// a real wall); this adds the "and the reversal is actually confirmed by 2+ signals" requirement.
// GridReactionRequireConsensus: Require a 2+ signal reversal consensus, not just one M15 candle
input bool   GridReactionRequireConsensus = true;   // Grid reaction require consensus (on/off)
// GridReactionMinConsensusScore: ReversalConsensusScore threshold: 0.82 = 2 signals, 0.92 = 3+. 0.80 means "at least 2 independent reversal signals agree".
input double GridReactionMinConsensusScore = 0.80;   // Grid reaction min consensus score
input double            RecoveryStartDDPercent   = 5.0;   // Recovery start DD %
input bool              UseAutoGridByMode        = true;   // Use auto grid by mode
input int               BalancedGridDistancePoints = 7000;   // Balanced grid distance points
input int               BalancedGridMinDistancePoints = 6000;   // Balanced grid min distance points
// BalancedGridMaxDistancePoints: V249fix: 14000 -> 12000. See the multiplier note below - the tail gap is what pushed Balanced's completed-ladder drawdown to 39.1%, against a 42% Smart-Early-Exit arm. Capping the tail at the same 12000 Hunter uses leaves the profile distinct through its wider BASE (7000 vs 6500) without the runaway last rung.
input int               BalancedGridMaxDistancePoints = 12000;   // Balanced grid max distance points
// BalancedGridDistanceMultiplier: V249fix: 1.25 -> 1.20. At 1.25 the 5-rung Balanced ladder ran 40,359 points ($40.36) deep and peaked at 39.1% drawdown - only 2.9 points below where Smart Early Exit arms and 8% under the affordability budget, i.e. the last rung was placed with almost no margin and could be cancelled by SEE before it landed. 1.20 brings it to 37,480 points / 35.4% peak: 17% budget headroom and a 6.6-point gap to SEE, so the ladder the entry gate approved can actually be completed. Balanced remains the WIDER-SPACED profile via its base distance (7000 vs 6500) and floor (6000 vs 5500) - it survives more travel before the ladder completes. Note it is NOT the cheaper one: because its gaps are bigger, its completed-ladder drawdown is HIGHER than Hunter's (35.4% vs 33.0%). Wider spacing buys time, not dollars.
input double            BalancedGridDistanceMultiplier = 1.20;   // Balanced grid distance multiplier
input double            BalancedAdaptiveGridATRMult = 1.10;   // Balanced adaptive grid ATR multiplier
input double            BalancedRecoveryStartDDPercent = 5.0;   // Balanced recovery start DD %
// HunterGridDistancePoints: Hunter base grid step (points)
input int               HunterGridDistancePoints = 6500;   // Hunter grid distance points
// HunterGridMinDistancePoints: Hunter grid floor (points)
input int               HunterGridMinDistancePoints = 5500;   // Hunter grid min distance points
input int               HunterGridMaxDistancePoints = 12000;   // Hunter grid max distance points
input double            HunterGridDistanceMultiplier = 1.20;   // Hunter grid distance multiplier
input double            HunterAdaptiveGridATRMult = 1.00;   // Hunter adaptive grid ATR multiplier
input double            HunterRecoveryStartDDPercent = 4.0;   // Hunter recovery start DD %
input bool              UseGridSafetyGuard       = true;   // Use grid safety guard
input bool              GridSafetyBlockOnNews    = true;   // Grid safety block on news (on/off)
input bool              GridSafetyBlockOnShock   = true;   // Grid safety block on shock (on/off)
input bool              GridSafetyBlockOnChaos   = true;   // Grid safety block on chaos (on/off)
input bool              GridSafetyBlockTrendAgainst = true;   // Grid safety block trend against (on/off)
input bool              GridSafetyBlockZoneDanger = true;   // Grid safety block zone danger (on/off)
input bool              GridSafetyBlockSpreadRisk = true;   // Grid safety block spread risk (on/off)
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) GridSafetyBlockDDRisk
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) GridSafetyMaxDDForNewGrid
input int               GridSafetyMinHealthScore = 65;   // Grid safety min health score
input bool              UseBasketTPMoney         = false;   // Use basket TP money
input double            BasketTPMoney            = 0.0;   // Basket TP money
input bool              UseBasketSLMoney         = false;   // Use basket SL money
input double            BasketSLMoney            = 0.0;   // Basket SL money
input bool              UseBasketTPPoints        = true;   // Use basket TP points
// BasketTPMinPoints: V170: 2000 -> 1200 ($1.20). This floor exists so the spread cannot eat the trade, and at $0.35 spread a $1.20 target still keeps ~70% of itself. At 2000 it sat ABOVE what the downward adjustments produce, so it silenced them - an Asian, ranging, churning market computed a $1.50 target and got $2.00 anyway. A floor should catch the unreasonable, not overrule the deliberate.
input int               BasketTPMinPoints        = 1200;   // Basket TP min points

// V138: contextual target. A fixed target ignores what stands in front of the basket. If the nearest
// opposing level is closer than the target, the basket must break it just to finish - and usually
// stalls under it instead. If the way is clear far beyond the target, the move is left unharvested.
// EnableContextualTP: Size the basket target by distance to the next opposing level instead of a fixed number
input bool   EnableContextualTP           = true;   // Enable contextual TP
// ContextTPMinWallStrength: Only levels at least this strong reshape the target - a single stray wick should not
input double ContextTPMinWallStrength     = 1.8;   // Context TP min wall strength
// ContextTPBufferPoints: Exit this far IN FRONT of the level ($0.40), because price rarely reaches the exact edge
input int    ContextTPBufferPoints        = 400;   // Context TP buffer points
// ContextTPMaxFactor: Ceiling as a multiple of the configured target (2.0 = a clear road may double it, no more - a scalp must stay a scalp)
input double ContextTPMaxFactor           = 2.0;   // Context TP max factor
// ContextTPPrintOnUse: Log every target adjustment so it can be checked against the chart
input bool   ContextTPPrintOnUse          = true;   // Context TP print on use (on/off)
input bool              PrintGridDecisions       = true;   // Print grid decisions

input group "ADVANCED ▸ TP chain / advanced recovery"
input bool              UseLegacyPack2           = true;   // Use legacy pack 2
input bool              UseTPChainLegacy         = true;   // Use TP chain legacy
input int               TPChainOrder2Percent     = 80;   // TP chain order 2 %
input int               TPChainOrder3Percent     = 65;   // TP chain order 3 %
input int               TPChainOrder5Percent     = 50;   // TP chain order 5 %
// TPChainMinPoints: TP Chain floor (points)
input int               TPChainMinPoints         = 2000;   // TP chain min points
input bool              UseAdvancedBasketTrailing = true;   // Use advanced basket trailing
// BasketTrailStartPoints: Trailing arms at this profit (points)
input int               BasketTrailStartPoints   = 2300;   // Basket trail start points
// BasketTrailStepPoints: Trailing follow distance (points)
input int               BasketTrailStepPoints    = 300;   // Basket trail step points
// BasketTrailLockPoints: Minimum locked profit once armed (points)
input int               BasketTrailLockPoints    = 2000;   // Basket trail lock points
// EnableAdaptiveTrailArm: V31.6z64: trailing armed at a FIXED 2300 while TP shrinks with basket depth (2000 at 3+ orders) - so for every basket that actually needed grid rescue, TP fired below the arm point and trailing NEVER engaged. Arms relative to each basket's own TP instead.
input bool              EnableAdaptiveTrailArm   = true;   // Enable adaptive trail arm
// AdaptiveTrailArmTPFraction: Arm trailing at this fraction of the basket's own current TP (0.8 x 2000 = 1600 for a deep basket, giving it real trailing protection)
input double            AdaptiveTrailArmTPFraction = 0.8;   // Adaptive trail arm TP fraction
// UseBasketBreakEvenLock: OFF - trailing alone manages the exit
input bool              UseBasketBreakEvenLock   = false;   // Use basket break even lock
// BasketBEStartPoints: BE lock arms at this profit (points)
input int               BasketBEStartPoints      = 1500;   // Basket BE start points
// BasketBEPlusPoints: BE lock target profit (points)
input int               BasketBEPlusPoints       = 1000;   // Basket BE plus points
input bool              UseRecoverySafeModeV2    = true;   // Use recovery safe mode
input int               RecoverySafeStartOrder   = 3;   // Recovery safe start order
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) RecoveryMaxDDForNewGrid
input bool              RecoveryStretchGridOnDD  = true;   // Recovery stretch grid on DD (on/off)
input double            RecoveryDDStretchStart   = 8.0;   // Recovery DD stretch start
input double            RecoveryDDStretchMult    = 1.35;   // Recovery DD stretch multiplier
input bool              RecoveryBlockAgainstHTF  = true;   // Recovery block against HTF (on/off)
input bool              UseAftershockGuard       = true;   // Use aftershock guard
input int               AftershockMinutes        = 20;   // Aftershock minutes
input int               AftershockMaxSpread      = 300;   // Aftershock max spread
input bool              PrintLegacyPack2Events   = true;   // Print legacy pack 2 events

input group "ADVANCED ▸ News / broker / analytics"
input bool              UseLegacyPack3           = true;   // Use legacy pack 3
input bool              UseNewsCalendarGuardV2   = true;   // Use news calendar guard
input bool              NewsGuardManualSchedule  = true;   // News guard manual schedule (on/off)
input int               NewsGuardMinutesBefore   = 20;   // News guard minutes before
input int               NewsGuardMinutesAfter    = 20;   // News guard minutes after
// NewsGuardTimesCSV: example: 13:30,15:00 server time
input string            NewsGuardTimesCSV        = "";   // News guard times CSV
input bool              NewsGuardCloseBasket     = false;   // News guard close basket (on/off)
input bool              NewsGuardBlockGrid       = true;   // News guard block grid (on/off)
input bool              NewsGuardBlockEntry      = true;   // News guard block entry (on/off)
input bool              UseBrokerSyncV2          = true;   // Use broker sync
input int               BrokerSyncMaxSpread      = 300;   // Broker sync max spread
input int               BrokerSyncMinStopLevel   = 0;   // Broker sync min stop level
input bool              BrokerSyncAdaptTPToStop  = true;   // Broker sync adapt TP to stop (on/off)
input bool              BrokerSyncAdaptGridToStop= true;   // Broker sync adapt grid to stop (on/off)
input bool              BrokerSyncBlockBadFilling= false;   // Broker sync block bad filling (on/off)
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) UseServerDisasterSL
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ServerDisasterDDPercent
input bool              ServerDisasterCloseBasket= true;   // Server disaster close basket (on/off)
input bool              UseClosedDealAnalytics   = true;   // Use closed deal analytics
input int               ClosedDealLookbackDays   = 7;   // Closed deal lookback days
input int               ClosedDealRefreshSeconds = 300;   // Closed deal refresh seconds
input bool              UseClientAuditSummary    = true;   // Use client audit summary
input int               ClientAuditPrintSeconds  = 600;   // Client audit print seconds
input bool              PrintLegacyPack3Events   = true;   // Print legacy pack 3 events

input group "ADVANCED ▸ (inactive) Stable baseline"

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

input group "ADVANCED ▸ Mini license"
input bool              UsePack4MiniLicense      = true;   // Use pack 4 mini license
// P4MiniUseLicenseControl: keep false while internal testing
input bool              P4MiniUseLicenseControl  = false;   // P4 mini use license control (on/off)
// P4MiniAccountWhitelist: example: 253530129,123456789
input string            P4MiniAccountWhitelist   = "";   // P4 mini account whitelist
input string            P4MiniExpireDate         = "2099.12.31";   // P4 mini expire date
input int               P4MiniGraceDays          = 0;   // P4 mini grace days
input bool              P4MiniAllowDemo          = true;   // P4 mini allow demo (on/off)
input bool              P4MiniAllowReal          = true;   // P4 mini allow real (on/off)
input bool              P4MiniCloseBasketInvalid = false;   // P4 mini close basket invalid (on/off)
input bool              P4MiniUseSymbolGuard     = true;   // P4 mini use symbol guard (on/off)
input bool              P4MiniRequireXAU         = true;   // P4 mini require xau (on/off)
input string            P4MiniSymbolKeyword      = "XAU";   // P4 mini symbol keyword
input int               P4MiniMaxSpread          = 300;   // P4 mini max spread
input bool              PrintPack4MiniEvents     = true;   // Print pack 4 mini events

input group "ADVANCED ▸ Client risk profile / lot cap"
input bool              UsePack4MiniLotCaps      = true;   // Use pack 4 mini lot caps
// P4MiniClientRiskProfile: CONSERVATIVE / BALANCED / AGGRESSIVE
input string            P4MiniClientRiskProfile  = "BALANCED";   // P4 mini client risk profile
input bool              P4MiniUseProfileCaps     = true;   // P4 mini use profile caps (on/off)
input double            P4MiniConservativeFirstLot = 0.10;   // P4 mini conservative first lot
input double            P4MiniConservativeGridLot  = 0.50;   // P4 mini conservative grid lot
input int               P4MiniConservativeMaxOrders = 5;   // P4 mini conservative max orders
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniConservativeMaxDD
input double            P4MiniBalancedFirstLot   = 0.25;   // P4 mini balanced first lot
input double            P4MiniBalancedGridLot    = 1.00;   // P4 mini balanced grid lot
input int               P4MiniBalancedMaxOrders  = 7;   // P4 mini balanced max orders
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniBalancedMaxDD
input double            P4MiniAggressiveFirstLot = 0.50;   // P4 mini aggressive first lot
input double            P4MiniAggressiveGridLot  = 2.00;   // P4 mini aggressive grid lot
input int               P4MiniAggressiveMaxOrders = 9;   // P4 mini aggressive max orders
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniAggressiveMaxDD
input double            P4MiniHardCapFirstLot    = 1.00;   // P4 mini hard cap first lot
input double            P4MiniHardCapGridLot     = 3.00;   // P4 mini hard cap grid lot
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) P4MiniBlockGridAboveProfileDD
input bool              P4MiniBlockGridAboveMaxOrders = true;   // P4 mini block grid above max orders (on/off)
input bool              PrintPack4MiniLotEvents  = true;   // Print pack 4 mini lot events

input group "ADVANCED ▸ Premium visual watermark / zones"
input bool              UsePremiumVisualEngine   = true;   // Use premium visual engine
input bool              PremiumShowWatermark     = true;   // Premium show watermark (on/off)
input bool              PremiumShowZones         = true;   // Premium show zones (on/off)
input bool              PremiumShowZoneMidlines  = true;   // Premium show zone midlines (on/off)
input bool              PremiumShowZoneLabels    = true;   // Premium show zone labels (on/off)
input int               PremiumVisualRefreshSeconds = 3;   // Premium visual refresh seconds
input int               PremiumZoneHalfWidthPoints = 350;   // Premium zone half width points
input int               PremiumZoneLookbackBars  = 180;   // Premium zone lookback bars
input int               PremiumZoneForwardBars   = 20;   // Premium zone forward bars
input int               PremiumWatermarkFontSize = 42;   // Premium watermark font size
input int               PremiumZoneLabelFontSize = 9;   // Premium zone label font size
input bool              PremiumUseFallbackZones  = true;   // Premium use fallback zones (on/off)
input int               PremiumFallbackZoneLookbackBars = 180;   // Premium fallback zone lookback bars
input int               PremiumFallbackZoneHalfWidthPoints = 900;   // Premium fallback zone half width points
input color             PremiumWatermarkColor    = clrDarkSlateGray;   // Premium watermark color
input color             PremiumSupportZoneColor  = clrGreen;   // Premium support zone color
input color             PremiumResistanceZoneColor = clrRed;   // Premium resistance zone color
input color             PremiumSupportLineColor  = clrAqua;   // Premium support line color
input color             PremiumResistanceLineColor = clrOrangeRed;   // Premium resistance line color
input color             PremiumAccentColor       = clrGold;   // Premium accent color
input bool              PrintPremiumVisualEvents = true;   // Print premium visual events

input group "ADVANCED ▸ Premium visual pack 2"
input bool              PremiumShowBasketLines   = true;   // Premium show basket lines (on/off)
input bool              PremiumShowNextGridLine  = false;   // Premium show next grid line (on/off)
input bool              PremiumShowSignalMarker  = true;   // Premium show signal marker (on/off)
input bool              PremiumShowHeaderFrame   = true;   // Premium show header frame (on/off)
input int               PremiumSignalArrowOffsetPoints = 220;   // Premium signal arrow offset points
input int               PremiumHeaderFrameX      = 14;   // Premium header frame x
input int               PremiumHeaderFrameY      = 12;   // Premium header frame y
input int               PremiumHeaderFrameW      = 250;   // Premium header frame w
input int               PremiumHeaderFrameH      = 74;   // Premium header frame h
input color             PremiumHeaderBgColor     = clrBlack;   // Premium header bg color
input color             PremiumHeaderBorderColor = clrGold;   // Premium header border color
input color             PremiumBasketAvgColor    = clrAqua;   // Premium basket average color
input color             PremiumBasketTPColor     = clrGold;   // Premium basket TP color
input color             PremiumNextGridColor     = clrOrange;   // Premium next grid color
input color             PremiumSignalBuyColor    = clrLime;   // Premium signal buy color
input color             PremiumSignalSellColor   = clrTomato;   // Premium signal sell color

input group "ADVANCED ▸ Premium visual pack 3"
input bool              PremiumShowBasketSLLine  = true;   // Premium show basket SL line (on/off)
input bool              PremiumShowTrailLockLine = true;   // Premium show trail lock line (on/off)
input bool              PremiumShowSignalHistory = false;   // Premium show signal history (on/off)
input bool              PremiumShowSessionZones  = false;   // Premium show session zones (on/off)
input int               PremiumSignalHistoryBars = 80;   // Premium signal history bars
input int               PremiumSessionLookbackBars = 240;   // Premium session lookback bars
input color             PremiumBasketSLColor     = clrRed;   // Premium basket SL color
input color             PremiumTrailLockColor    = clrYellow;   // Premium trail lock color
input color             PremiumAsiaSessionColor  = clrDarkSlateGray;   // Premium asia session color
input color             PremiumLondonSessionColor = clrMidnightBlue;   // Premium london session color
input color             PremiumNYSessionColor    = clrMaroon;   // Premium NY session color
input color             PremiumSessionLabelColor = clrSilver;   // Premium session label color

input group "ADVANCED ▸ Visual cleanup / performance"
input bool              PremiumUseClutterControl = true;   // Premium use clutter control (on/off)
input bool              PremiumCleanIfDisabled   = true;   // Premium clean if disabled (on/off)
input bool              PremiumHideBasketLinesWhenFlat = true;   // Premium hide basket lines when flat (on/off)
input bool              PremiumCleanOldSignalHistory = true;   // Premium clean old signal history (on/off)
input int               PremiumMaxSignalHistoryObjects = 10;   // Premium max signal history objects
input int               PremiumVisualCleanupSeconds = 30;   // Premium visual cleanup seconds
input bool              PremiumCleanSessionsIfOff = true;   // Premium clean sessions if off (on/off)
input bool              PremiumCleanZonesIfOff    = true;   // Premium clean zones if off (on/off)
input bool              PremiumCleanSignalIfOff   = true;   // Premium clean signal if off (on/off)
input bool              PremiumPrintCleanupEvents = true;   // Premium print cleanup events (on/off)

input group "ADVANCED ▸ Settings balance / safe defaults"
input bool              UseRCSettingsBalance     = true;   // Use RC settings balance
// RCSettingsPreset: SAFE / BALANCED / HIGH_HUNTER
input string            RCSettingsPreset         = "BALANCED";   // RC settings preset
// RCSettingsStrictEnforce: false = audit only, true = block risky entry/grid
input bool              RCSettingsStrictEnforce  = false;   // RC settings strict enforce (on/off)
input bool              RCWarnIfLicenseOff       = true;   // RC warn if license off (on/off)
input bool              RCWarnIfBasketSLHigh     = true;   // RC warn if basket SL high (on/off)
input bool              RCWarnIfMaxOrdersHigh    = true;   // RC warn if max orders high (on/off)
input bool              RCWarnIfLotTooHigh       = true;   // RC warn if lot too high (on/off)
input bool              RCWarnIfSpreadCapHigh    = true;   // RC warn if spread cap high (on/off)
input double            RCSafeMaxFirstLot        = 0.10;   // RC safe max first lot
input double            RCBalancedMaxFirstLot    = 0.25;   // RC balanced max first lot
input double            RCHighHunterMaxFirstLot  = 0.50;   // RC high hunter max first lot
input int               RCSafeMaxOrders          = 5;   // RC safe max orders
input int               RCBalancedMaxOrders      = 7;   // RC balanced max orders
input int               RCHighHunterMaxOrders    = 9;   // RC high hunter max orders
input double            RCSafeMaxBasketSL        = 10.0;   // RC safe max basket SL
// RCBalancedMaxBasketSL: V249fix(auto-mode): 18 -> 50, tracking BasketSLPercent. At 18 against a configured BasketSLPercent of 50 this governor raised a warning on EVERY scan, forever - noise that hides a real one, and a live landmine: the moment RCSettingsStrictEnforce is set true it becomes a permanent entry AND grid block. A governor must cap overreach, not disagree with the configuration it is governing. Keep this equal to BasketSLPercent.
input double            RCBalancedMaxBasketSL    = 50.0;   // RC balanced max basket SL
// RCHighHunterMaxBasketSL: V249fix(auto-mode): 25 -> 50, same reason - keep equal to BasketSLPercent.
input double            RCHighHunterMaxBasketSL  = 50.0;   // RC high hunter max basket SL
input int               RCSafeMaxSpread          = 300;   // RC safe max spread
input int               RCBalancedMaxSpread      = 300;   // RC balanced max spread
input int               RCHighHunterMaxSpread    = 300;   // RC high hunter max spread
input bool              PrintRCSettingsEvents    = true;   // Print RC settings events

input group "ADVANCED ▸ Warning cleanup / zero-warning polish"
input bool              UseWarningCleanupPolish  = true;   // Use warning cleanup polish
input bool              PrintWarningCleanupEvents = true;   // Print warning cleanup events

input group "ADVANCED ▸ (inactive) Final self-audit checklist"

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

input group "ADVANCED ▸ (inactive) Release build / client preset export"

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
// ReleaseBuildProfile: INTERNAL_TEST / CLIENT_SAFE / CLIENT_BALANCED / HIGH_HUNTER / RENTAL_DEMO
input string            ReleaseBuildProfile      = "CLIENT_BALANCED";   // Release build profile
// ReleaseRequireLicenseForClient: set true before real client rental
input bool              ReleaseRequireLicenseForClient = false;   // Release require license for client (on/off)

input group "ADVANCED ▸ Legacy deep parity / HTF commander"
input bool              UseLegacyDeepParityPack  = true;   // Use legacy deep parity pack
input bool              UseDeepHTFCommander      = true;   // Use deep HTF commander
input bool              DeepHTFUseScoreIntegration = true;   // Deep HTF use score integration (on/off)
input bool              DeepHTFStrictCounterTrendBlock = false;   // Deep HTF strict counter trend block (on/off)
// DeepHTFBlockGridCounterTrend: V52b: REVERTED to false after review. Three reasons: (1) redundant - Pack2RecoveryAllowsGrid() already blocks counter-HTF grid adds and RecoveryBlockAgainstHTF is already true; (2) WRONG DIRECTION - this flag keys off DeepOpportunitySign() (the scanner's current opportunity), not the BASKET direction the grid actually adds in, so it fires on the wrong signal and can block an add that is WITH the trend; (3) it evaluates before szr_active is determined, so it would have killed the Smart Zone Recovery rescue path entirely.
input bool              DeepHTFBlockGridCounterTrend = false;   // Deep HTF block grid counter trend (on/off)
input int               DeepHTFFastMAPeriod      = 50;   // Deep HTF fast MA period
input int               DeepHTFSlowMAPeriod      = 200;   // Deep HTF slow MA period
input int               DeepHTFSlopeBars         = 8;   // Deep HTF slope bars
input int               DeepStructureLookbackBars = 36;   // Deep structure lookback bars
input int               DeepZoneNearPoints       = 900;   // Deep zone near points
input int               DeepHTFAlignBonus        = 2;   // Deep HTF align bonus
input int               DeepM15ConfirmBonus      = 1;   // Deep M15 confirm bonus
input int               DeepZoneReactionBonus    = 1;   // Deep zone reaction bonus
// DeepHTFCounterPenalty: BOSQICH 16: 2 -> 0. TAKROR: HTF qarshiligi ball dvigatelida allaqachon hisoblanadi (HTFAgainstScorePenalty=4, MaxTrendAgainstPenalty=6 - beshta modul shu yerga boradi). Legacy jazo esa CONDITIONS guruhiga, shift hisobidan TASHQARIDA ikkinchi marta yozilardi. Bonusi saqlandi
input int               DeepHTFCounterPenalty    = 0;   // Deep HTF counter penalty
input int               DeepZoneDangerPenalty    = 2;   // Deep zone danger penalty
input bool              PrintDeepParityEvents    = true;   // Print deep parity events

input group "ADVANCED ▸ Deep BOS / CHoCH / retest upgrade"
input bool              UseDeepBOSChochRetest    = true;   // Use deep BOS CHOCH retest
input bool              DeepBOSUseScoreIntegration = true;   // Deep BOS use score integration (on/off)
input bool              DeepBOSStrictAgainstBlock = false;   // Deep BOS strict against block (on/off)
input bool              DeepBOSBlockGridAgainst  = false;   // Deep BOS block grid against (on/off)
input int               DeepBOSLookbackBars      = 34;   // Deep BOS lookback bars
input int               DeepBOSBreakBufferPoints = 180;   // Deep BOS break buffer points
input int               DeepRetestZonePoints     = 420;   // Deep retest zone points
input int               DeepRetestMaxBars        = 18;   // Deep retest max bars
input int               DeepBOSAlignBonus        = 2;   // Deep BOS align bonus
// DeepBOSFreshBreakBonus: V29: reduced bonus for a break NOT yet retest-confirmed (fake-breakout guard)
input int               DeepBOSFreshBreakBonus   = 0;   // Deep BOS fresh break bonus
input int               DeepCHoCHBonus           = 2;   // Deep c ho ch bonus
input int               DeepRetestBonus          = 2;   // Deep retest bonus
// DeepBOSAgainstPenalty: BOSQICH 16: 2 -> 0. TAKROR: qarshi struktura ball dvigatelining struktura modullarida hisoblanadi. Bonusi saqlandi
input int               DeepBOSAgainstPenalty    = 0;   // Deep BOS against penalty
input int               DeepFailedRetestPenalty  = 1;   // Deep failed retest penalty
input bool              PrintDeepBOSEvents       = true;   // Print deep BOS events

input group "ADVANCED ▸ Deep top zone / countertrend trap guard"
input bool              UseDeepTopZoneTrapGuard  = true;   // Use deep top zone trap guard
input bool              DeepTopZoneUseScoreIntegration = true;   // Deep top zone use score integration (on/off)
input bool              DeepTopZoneStrictBlock   = false;   // Deep top zone strict block (on/off)
input bool              DeepTopZoneBlockGrid     = false;   // Deep top zone block grid (on/off)
input int               DeepTopZoneNearPoints    = 850;   // Deep top zone near points
input int               DeepZoneBreakoutBufferPoints = 260;   // Deep zone breakout buffer points
input double            DeepTrapWickRatio        = 0.42;   // Deep trap wick ratio
input int               DeepTrapWithSignalBonus  = 2;   // Deep trap with signal bonus
input int               DeepZoneBreakoutBonus    = 2;   // Deep zone breakout bonus
// DeepOppositeZonePenalty: BOSQICH 16: 3 -> 0. TAKROR: qarshi zona uchun counter-zone, zona veto va BOSQICH 11-12 zona dvigateli bor. Bu to'rtinchi ovoz edi. Bonusi saqlandi
input int               DeepOppositeZonePenalty  = 0;   // Deep opposite zone penalty
input int               DeepCounterTrendTrapPenalty = 2;   // Deep counter trend trap penalty
input bool              PrintDeepTopZoneEvents   = true;   // Print deep top zone events

input group "ADVANCED ▸ Deep news / volatility shock brain"
input bool              UseDeepNewsVolatilityBrain = true;   // Use deep news volatility brain
input bool              DeepNewsUseScoreIntegration = true;   // Deep news use score integration (on/off)
input bool              DeepNewsStrictEntryBlock = false;   // Deep news strict entry block (on/off)
input bool              DeepNewsStrictGridBlock  = false;   // Deep news strict grid block (on/off)
input bool              DeepShockUseNewsState    = true;   // Deep shock use news state (on/off)
input bool              DeepShockUseATRImpulse   = true;   // Deep shock use ATR impulse (on/off)
input bool              DeepShockUseSpreadSpike  = true;   // Deep shock use spread spike (on/off)
input int               DeepShockATRPeriod       = 14;   // Deep shock ATR period
input double            DeepShockRangeATRMult    = 2.20;   // Deep shock range ATR multiplier
input double            DeepShockBodyATRMult     = 1.25;   // Deep shock body ATR multiplier
input int               DeepShockSpreadPoints    = 300;   // Deep shock spread points
input int               DeepShockCooldownBars    = 6;   // Deep shock cooldown bars
input int               DeepNewsPenalty          = 3;   // Deep news penalty
input int               DeepShockAgainstPenalty  = 3;   // Deep shock against penalty
input int               DeepShockExhaustPenalty  = 2;   // Deep shock exhaust penalty
input int               DeepShockMomentumBonus   = 1;   // Deep shock momentum bonus
input bool              PrintDeepShockEvents     = true;   // Print deep shock events

input group "ADVANCED ▸ Adaptive entry timing brain"
input bool              UseAdaptiveEntryTimingBrain = true;   // Use adaptive entry timing brain
input bool              DeepTimingUseScoreIntegration = true;   // Deep timing use score integration (on/off)
input bool              DeepTimingStrictEarlyBlock = false;   // Deep timing strict early block (on/off)
input bool              DeepTimingBlockGridAfterShock = false;   // Deep timing block grid after shock (on/off)
input int               DeepTimingMinSecondsAfterBarOpen = 3;   // Deep timing min seconds after bar open
input int               DeepTimingLateEntrySeconds = 48;   // Deep timing late entry seconds
input int               DeepTimingPostShockWaitBars = 2;   // Deep timing post shock wait bars
input int               DeepTimingCandleConfirmBonus = 2;   // Deep timing candle confirm bonus
input int               DeepTimingRejectionBonus  = 1;   // Deep timing rejection bonus
// DeepTimingEarlyPenalty: BOSQICH 16: 2 -> 0. Signallar YOPILGAN shamdan quriladi, ya'ni ular tabiiy ravishda yangi barning birinchi soniyalarida paydo bo'ladi. Bu jazo aynan eng yangi signalni kechiktirardi
input int               DeepTimingEarlyPenalty    = 0;   // Deep timing early penalty
input int               DeepTimingLatePenalty     = 1;   // Deep timing late penalty
input int               DeepTimingPostShockPenalty = 2;   // Deep timing post shock penalty
input int               DeepTimingOppCandlePenalty = 2;   // Deep timing opp candle penalty
input bool              PrintDeepTimingEvents     = true;   // Print deep timing events

input group "ADVANCED ▸ Adaptive recovery intelligence"
input bool              UseAdaptiveRecoveryIntelligence = true;   // Use adaptive recovery intelligence
input bool              DeepRecoveryUseGridDistance = true;   // Deep recovery use grid distance (on/off)
input bool              DeepRecoveryUseLotThrottle = true;   // Deep recovery use lot throttle (on/off)
input bool              DeepRecoveryBlockBadGrid  = false;   // Deep recovery block bad grid (on/off)
input int               DeepRecoveryMinHealthScore = 38;   // Deep recovery min health score
input double            DeepRecoveryDDStretchStart = 6.0;   // Deep recovery DD stretch start
input double            DeepRecoveryDDHardCaution = 14.0;   // Deep recovery DD hard caution
input double            DeepRecoveryDistanceBoost = 1.25;   // Deep recovery distance boost
input double            DeepRecoveryMaxDistanceBoost = 2.20;   // Deep recovery max distance boost
input double            DeepRecoveryLotReduceFactor = 0.75;   // Deep recovery lot reduce factor
input double            DeepRecoveryMinLotFactor  = 0.50;   // Deep recovery min lot factor
input int               DeepRecoveryTrendAgainstPenalty = 22;   // Deep recovery trend against penalty
input int               DeepRecoveryZoneDangerPenalty = 20;   // Deep recovery zone danger penalty
input int               DeepRecoveryNewsShockPenalty = 18;   // Deep recovery news shock penalty
input int               DeepRecoveryOrderPressurePenalty = 18;   // Deep recovery order pressure penalty
input bool              PrintDeepRecoveryEvents   = true;   // Print deep recovery events

input group "ADVANCED ▸ Profit extraction / smart exit brain"
input bool              UseProfitExtractionSmartExit = true;   // Use profit extraction smart exit
// DeepExitEnableAutoClose: OFF - was closing at 330-700pts via 4 separate sub-mechanisms, undercutting the tuned trailing system (BasketTrailStartPoints etc) in group 03/07
input bool              DeepExitEnableAutoClose  = false;   // Deep exit enable auto close (on/off)
input bool              DeepExitCloseOnPeakGiveback = true;   // Deep exit close on peak giveback (on/off)
input bool              DeepExitCloseOnOppositeRisk = true;   // Deep exit close on opposite risk (on/off)
input bool              DeepExitCloseOnShockRisk = true;   // Deep exit close on shock risk (on/off)
input bool              DeepExitQuickMultiOrderProfit = true;   // Deep exit quick multi order profit (on/off)
input int               DeepExitProtectStartPoints = 700;   // Deep exit protect start points
input int               DeepExitPeakGivebackPoints = 360;   // Deep exit peak giveback points
input double            DeepExitPeakGivebackPercent = 45.0;   // Deep exit peak giveback %
input int               DeepExitOppositeRiskMinPoints = 520;   // Deep exit opposite risk min points
input int               DeepExitShockRiskMinPoints = 650;   // Deep exit shock risk min points
input int               DeepExitMultiOrderMinOrders = 3;   // Deep exit multi order min orders
input int               DeepExitMultiOrderProfitPoints = 330;   // Deep exit multi order profit points
input double            DeepExitMinProfitMoney   = 0.0;   // Deep exit min profit money
input bool              PrintDeepExitEvents      = true;   // Print deep exit events

input group "ADVANCED ▸ Market regime AUTO-tuning brain"
input bool              UseMarketRegimeAutoTuningBrain = true;   // Use market regime auto tuning brain
input bool              RegimeTuneUseScoreIntegration = true;   // Regime tune use score integration (on/off)
input bool              RegimeTuneStrictDeadChaosBlock = false;   // Regime tune strict dead chaos block (on/off)
input bool              RegimeTuneBlockGridInShock = false;   // Regime tune block grid in shock (on/off)
input bool              RegimeTuneUseGridDistance = true;   // Regime tune use grid distance (on/off)
input bool              RegimeTuneUseLotThrottle = true;   // Regime tune use lot throttle (on/off)
input int               RegimeTrendAlignBonus    = 2;   // Regime trend align bonus
input int               RegimeRangeEdgeBonus     = 2;   // Regime range edge bonus
input int               RegimeExhaustionReversalBonus = 2;   // Regime exhaustion reversal bonus
input int               RegimeMomentumContinuationBonus = 1;   // Regime momentum continuation bonus
input int               RegimeAgainstTrendPenalty = 2;   // Regime against trend penalty
input int               RegimeRangeChasePenalty  = 2;   // Regime range chase penalty
input int               RegimeShockPenalty       = 2;   // Regime shock penalty
input int               RegimeDeadChaosPenalty   = 4;   // Regime dead chaos penalty
input double            RegimeGridShockDistanceFactor = 1.45;   // Regime grid shock distance factor
input double            RegimeGridChaosDistanceFactor = 1.80;   // Regime grid chaos distance factor
input double            RegimeGridTrendAgainstDistanceFactor = 1.25;   // Regime grid trend against distance factor
input double            RegimeLotShockFactor     = 0.75;   // Regime lot shock factor
input double            RegimeLotChaosFactor     = 0.60;   // Regime lot chaos factor
input bool              PrintRegimeTuneEvents    = true;   // Print regime tune events

input group "ADVANCED ▸ Smart client safety / rental protection"
input bool              UseSmartClientSafetyBrain = true;   // Use smart client safety brain
// ClientSafetyStrictEnforce: false = warn/tune, true = block entry/grid
input bool              ClientSafetyStrictEnforce = false;   // Client safety strict enforce (on/off)
input bool              ClientSafetyRequireLicenseWhenRental = true;   // Client safety require license when rental (on/off)
input bool              ClientSafetyWarnEmptyWhitelist = true;   // Client safety warn empty whitelist (on/off)
input bool              ClientSafetyBlockHighSpread = false;   // Client safety block high spread (on/off)
input bool              ClientSafetyUseLotThrottle = true;   // Client safety use lot throttle (on/off)
input bool              ClientSafetyUseGridDistance = true;   // Client safety use grid distance (on/off)
input int               ClientSafetyMaxSpreadBalanced = 300;   // Client safety max spread balanced
input int               ClientSafetyMaxSpreadSafe = 300;   // Client safety max spread safe
input int               ClientSafetyMaxSpreadHighHunter = 300;   // Client safety max spread high hunter
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ClientSafetyDDWarnPercent
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) ClientSafetyDDDangerPercent
// ClientSafetyMaxOrdersWarn: V249fix: 6 -> 4. With MaxOrders 5 a basket can never hold 6 orders, so this "order pressure" warning was dead code. 4 makes it fire on the second-to-last rung, which is where the warning is actually useful.
input int               ClientSafetyMaxOrdersWarn = 4;   // Client safety max orders warn
input double            ClientSafetyGridDistanceFactor = 1.25;   // Client safety grid distance factor
input double            ClientSafetyDangerDistanceFactor = 1.65;   // Client safety danger distance factor
input double            ClientSafetyLotThrottleFactor = 0.75;   // Client safety lot throttle factor
input double            ClientSafetyDangerLotFactor = 0.55;   // Client safety danger lot factor
input bool              PrintClientSafetyEvents  = true;   // Print client safety events

input group "ADVANCED ▸ (inactive) Final intelligence merge"

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
input int               FinalMergeWarnScore     = 72;   // Final merge warn score

input group "ADVANCED ▸ (inactive) PRO release final / preset packager"

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

input group "ADVANCED ▸ (inactive) Settings governance / client input guard"

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

input group "ADVANCED ▸ Client dashboard / log polish"
input bool              UseClientDashboardPolish = true;   // Use client dashboard polish
// ClientDashboardViewMode: PRO / COMPACT / RENTAL / INTERNAL
input string            ClientDashboardViewMode  = "COMPACT";   // Client dashboard view mode
input bool              ClientDashShowHealthLine = true;   // Client dashboard show health line (on/off)
input bool              ClientDashShowRiskBanner = true;   // Client dashboard show risk banner (on/off)
input bool              ClientDashShowReleaseBadge = true;   // Client dashboard show release badge (on/off)
input bool              ClientDashShowModeAdvice = true;   // Client dashboard show mode advice (on/off)
input bool              ClientDashShowContactLine = true;   // Client dashboard show contact line (on/off)
input bool              ClientDashCompactDeepReasons = true;   // Client dashboard compact deep reasons (on/off)
input int               ClientDashReasonMaxChars = 70;   // Client dashboard reason max chars
input int               ClientDashDefenseScore   = 58;   // Client dashboard defense score
input int               ClientDashWarnScore      = 72;   // Client dashboard warn score
input int               ClientDashProScore       = 86;   // Client dashboard pro score
input bool              PrintClientDashboardPolishEvents = true;   // Print client dashboard polish events

input group "ADVANCED ▸ (inactive) Final preset hardening / safe client defaults"

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
input bool              PresetHardeningUseGridDistance = true;   // Preset hardening use grid distance (on/off)
input bool              PresetHardeningUseLotThrottle = true;   // Preset hardening use lot throttle (on/off)

input group "ADVANCED ▸ (inactive) Final audit report / build lock"

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

input group "ADVANCED ▸ Live validation probe / no-trade doctor"
input bool              UseLiveValidationProbe   = true;   // Use live validation probe
input bool              LiveProbeShowEntryDoctor = true;   // Live probe show entry doctor (on/off)
input bool              LiveProbeShowGridDoctor  = true;   // Live probe show grid doctor (on/off)
input bool              LiveProbeShowGateStack   = true;   // Live probe show gate stack (on/off)
input bool              LiveProbePrintOnChange   = true;   // Live probe print on change (on/off)
input bool              LiveProbePrintEveryNewBar = false;   // Live probe print every new bar (on/off)
input int               LiveProbeMinBarsForReady = 8;   // Live probe min bars for ready
input int               LiveProbeMaxReasonChars  = 130;   // Live probe max reason chars
// LiveProbeNoTradeDoctorOnly: true = diagnostic only, no blocking
input bool              LiveProbeNoTradeDoctorOnly = true;   // Live probe no trade doctor only (on/off)
input bool              PrintLiveProbeEvents     = true;   // Print live probe events

input group "ADVANCED ▸ Micro scalp settings"
input bool              UseMicroScalpLayer       = true;   // Use micro scalp layer
input ENUM_MICRO_TP_MODE MicroTPMode             = MICRO_TP_AUTO;   // Micro TP mode
input int               FixedMicroTPPoints       = 800;   // Fixed micro TP points
input int               MicroTPPercentOfMainTP   = 40;   // Micro TP % of main TP
// MicroTPMinPoints: Micro entry TP floor (points)
input int               MicroTPMinPoints         = 2000;   // Micro TP min points
// MicroTPMaxPoints: Micro entry TP ceiling (points)
input int               MicroTPMaxPoints         = 3000;   // Micro TP max points
input double            MicroDynamicATRMult      = 1.20;   // Micro dynamic ATR multiplier
input double            MicroDynamicRoomFactor   = 0.70;   // Micro dynamic room factor
// MicroLotFactorBalanced: V68b: 0.50 -> 0.80 on user request. Micro entry lot = StartLot x this, so 0.25 x 0.80 = 0.20 - smaller than a full first entry, but not tiny. The first-entry floor below is made micro-aware so this reduction actually survives (at 1.0 the floor previously pushed micro back up to the full 0.25).
input double            MicroLotFactorBalanced   = 0.80;   // Micro lot factor balanced
// MicroLotFactorHighHunter: V249fix(auto-mode): 1.00 -> 0.80. The micro layer exists to take marginal setups at REDUCED size; at 1.00 the reduction was zero, so the aggressive mode sized a marginal entry exactly like a full-conviction one - and larger than Balanced's 0.80 micro. Matched to Balanced; lower it further if you want Hunter's micro to be the smaller of the two.
input double            MicroLotFactorHighHunter = 0.80;   // Micro lot factor high hunter
input bool              MicroOnlyCGrade          = true;   // Micro only c grade (on/off)
input bool              MicroAllowBGradeIfPreferred = false;   // Micro allow b grade if preferred (on/off)
input bool              MicroRequireSweepOrRejection = true;   // Micro require sweep or rejection (on/off)
input bool              MicroAllowNearZoneEntry  = true;   // Micro allow near zone entry (on/off)
input int               MicroMaxSpreadPoints     = 300;   // Micro max spread points
input int               MicroMinRoomPercentOfTP  = 70;   // Micro min room % of TP
input bool              MicroBlockFreshImpulse   = true;   // Micro block fresh impulse (on/off)
input bool              PrintMicroDecisions      = true;   // Print micro decisions

input group "ADVANCED ▸ Entry / signal settings"
// UseM1EntryClose: Wait for M1 bar close before entry (currently off)
input bool              UseM1EntryClose          = false;   // Use M1 entry close
// MinScoreBalanced: V185b: 6 -> 4. Live readings show base 5-7 and bonus capped at 12, so a qualifying setup arrives at roughly 13 - and with the penalty ceiling at 12, a bar of 6 meant anything past seven points of warning was refused. That is far tighter than intended: a single strong impulse against the entry reaches nine on its own. The bar exists to reject setups that never formed properly, not to arbitrate between the score and the warnings - that is what the caps are for.
input int               MinScoreBalanced         = 4;   // Min score balanced
// MinScoreHighHunter: V185b: 4 -> 2, keeping the same two-point gap below Balanced.
input int               MinScoreHighHunter       = 2;   // Min score high hunter

// V129: HIGH HUNTER is deliberately lighter than BALANCED - a lower score bar plus a +1 signal
// bonus, roughly 3 points of slack. That slack was also weakening every protection: a setup with a
// real danger penalty (late entry, undefined zone role, structure against, no room...) could pass
// in Hunter while Balanced refused it. Scaling the accumulated penalty in Hunter by this factor
// keeps Hunter fast on CLEAN setups but as strict as Balanced the moment a warning appears - which
// is what makes AUTO mode safe to leave on.
// HunterProtectionPenaltyScale: V176: 1.75 -> 1.00, disabled. This existed because Hunter used to be structurally lighter than Balanced (lower score bar plus a +1 per-detector bonus), so protections needed scaling up to match. The penalty system has since been rebuilt around three separate group caps and a total cap balanced against the bonus cap - that balance is what now keeps Hunter honest. Multiplying on top of it pushed the penalty to 21 against a bonus ceiling of 12, which no setup could answer: live reading showed base=5 bonus=12 penalty=21, a permanent block.
input double            HunterProtectionPenaltyScale = 1.00;   // Hunter protection penalty scale
// MaxTotalScorePenalty: V272: 12 -> 10. The group ceilings were raised so ten candle modules would not be compressed into the weight of one, and that worked - but it also means the total now reaches twelve on setups where V249 would have stopped at eight or nine, purely because more groups can contribute. A setup with modest agreement and ordinary objections used to pass and now does not, and nothing about it got worse; only the accounting changed. Ten restores that balance while leaving the total a genuine ceiling.     // V249fix(auto-mode): briefly raised to 16 so a saturated bonus pool could still be out-argued. Reverted: the whole score system - and CounterTrendExceptionalMinScore in particular - is calibrated against a typical final of ~9 that assumes THIS cap. At 16 that same reading fell to 5 (Balanced) / 3 (Hunter) against a release bar of 8, which turned the counter-trend guard back into a hard block with only the 3-hour safety valve behind it. The mode-relative term below is the part that was actually needed. The 'penalties cannot refuse once bonuses saturate' problem is real but belongs to a deliberate re-tune of the whole bonus/penalty balance, not to a single input.
input int               MaxTotalScorePenalty     = 10;   // Max total score penalty
// MaxTrendAgainstPenalty: V259: 4 -> 6. Five modules route here - timeframe alignment, the sweep reversal, the liquidity wick, the size progression and the reversal context - and their raw total reaches twenty-eight against a ceiling of four. Seven to one is not a cap, it is a filter deciding which reading survives, and the market was never consulted about which that should be.      // V183: trend conflict sits between the two - it is about the trade, but it is also the most duplicated signal in the system.
input int               MaxTrendAgainstPenalty   = 6;   // Max trend against penalty
// MaxConditionPenalty: V259: 3 -> 4. Six modules now route here and reach twenty-five raw. Three was chosen in V255 to undo an overcorrection, which it did; four restores a little of what those readings can express without returning to the six that stopped the EA trading.      // V255: 6 -> 3. Raised from 2 to 6 in V250b so the newer readings (a release arriving, a dead market, the layers splitting) would not be compressed into almost nothing. Six turned out to be too much: with every group at once the total penalty now reaches its ceiling on setups that used to pass, and the EA stopped trading on a live account. Three still lets those readings register without letting this group alone consume a quarter of the total budget.      // V250b: 2 -> 6. This cap was set when the group held only spread and noise readings - things that shape size rather than decide direction. It now also holds a release arriving, a market with no range, and the analysis layers contradicting each other, which together produce seventeen points and were being compressed into two. A release mid-entry and a three-against-three split are reasons not to trade at all, and a cap of two made them nearly invisible.      // V183: conditions stay small on the ENTRY decision. A churning session or a wide spread describes the market, not the trade - and blocking on market description is what cut a high-frequency scalper down to a couple of trades a day. Their full weight still reaches the sizing, which is where it belongs.
input int               MaxConditionPenalty      = 4;   // Max condition penalty
// MaxQualityPenalty: V183: 4 -> 9. These describe something wrong with the TRADE - no room to the target, a level that cannot be read, entering where the last two baskets lost. They should be able to stop an entry on their own, and at 4 they could not: a setup with every quality warning live still scored well enough to trade.
input int               MaxQualityPenalty        = 9;   // Max quality penalty
// MaxImpulsePenalty: V185: cap on the impulse family before it enters the quality budget. Counter-impulse, correction exhaustion, recent extreme, sustained exhaustion, impulse correction and forced flow are six readings of one thing - how stretched the move is - and they fire together by design. Five points says it clearly without crowding out everything else.
input int               MaxImpulsePenalty        = 5;   // Max impulse penalty
// MaxCandlePenalty: V259: 6 -> 8. Ten candle modules now route here and their combined raw output reaches forty, so the group was compressing ten independent readings into the weight of one - and adding an eleventh would have changed nothing except which of the ten survived the cut. Eight is still a ceiling rather than a licence; the total cap of twelve continues to bound everything.      // V214: ceiling on everything the candle layer can charge. Ten modules read candles and several read the same event - a live rejection, its authorship and the sequence state are three views of one wick. Uncapped they swing the score by thirty-plus points against caps of twelve, which is a layer outvoting the rest by count rather than by being right.
input int               MaxCandlePenalty         = 8;   // Max candle penalty
// MaxCandleBonus: V259: 6 -> 8, moved with the penalty ceiling. Raising one without the other is what made the scoring one-sided in V255 and stopped the EA trading on a live account.      // V214: and the same ceiling on what they can argue FOR, so the cap does not quietly become a one-sided filter.
input int               MaxCandleBonus           = 8;   // Max candle bonus
// MaxStructurePenalty: V227: ceiling on everything the structure layer can charge. Five modules read structure direction - measured shape, swing count, timeframe alignment, pullback detection, break event - and all route into a trend group capped at 4, so 27 points of reading arrived with the force of one. Slightly above the candle budget because structure is the slower and more reliable signal of the two.
input int               MaxStructurePenalty      = 7;   // Max structure penalty
// MaxStructureBonus: V227: and the same ceiling on what they argue FOR.
input int               MaxStructureBonus        = 7;   // Max structure bonus

// V228: when the ladder should stop. MaxOrders is 7 in every circumstance - the ladder does not know
// that order five in a quiet range and order five into a news spike are different commitments, or
// that a basket six hours old is fighting a market that has moved on from the one it opened in.
// EnableGridDepthLimit: Stop at the rung the account can pay for rather than the rung the setting names
input bool   EnableGridDepthLimit        = true;   // Enable grid depth limit
// GridDepthBudgetShare: Share of the stop-loss budget the remaining rungs may project into. Below 1.0 so the ladder finishes before the stop rather than at it.
input double GridDepthBudgetShare        = 0.75;   // Grid depth budget share
// GridDepthPrintOnUse: Log depth caps
input bool   GridDepthPrintOnUse         = true;   // Grid depth print on use (on/off)
// EnableBasketStaleness: Notice when the basket is fighting a different market from the one it opened in
input bool   EnableBasketStaleness       = true;   // Enable basket staleness
// BasketStaleAfterBars: Bars before age starts counting - two hours on M1, by which point the setup that opened it is history
input int    BasketStaleAfterBars        = 120;   // Basket stale after bars
// BasketStaleFullBars: Bars at which age contributes fully
input int    BasketStaleFullBars         = 400;   // Basket stale full bars
// BasketStaleAgeWeight: Weight of age alone
input double BasketStaleAgeWeight        = 0.40;   // Basket stale age weight
// BasketStaleSessionWeight: Weight of the session having handed over - different participants, different range
input double BasketStaleSessionWeight    = 0.35;   // Basket stale session weight
// BasketStaleTargetWeight: Weight of price having passed the level the basket was aimed at without closing
input double BasketStaleTargetWeight     = 0.30;   // Basket stale target weight
// BasketStaleBlockLevel: V249fix: 0.65 -> 0.70. The session component is a BINARY 0.35 that fires the instant the session hands over and never decays, so at 0.65 a basket needed only 0.30 more from age - 75% of the ramp, i.e. 330 M1 bars = 5h30m - and additions stopped. A completed 5-rung ladder needs ~37,000 points ($37) of adverse travel, which on XAUUSD routinely takes longer and ALWAYS crosses a session, so most real ladders froze at 2-3 rungs: a directional bet with no recovery mechanism left, holding the account hostage under OneBasketAtATime, on a ladder the affordability gate had already budgeted to full depth. At 0.70: age alone (0.40 max) still cannot freeze it; session+age blocks at 365 bars (6h05m); age+target (0.70) blocks WITHOUT needing a session change - which 0.72 would have made structurally impossible, since the non-session maximum is exactly 0.70. That reachability is why this is 0.70 and not higher: at 0.72 a maximally-old basket that had blown through its target could only be frozen while the clock happened to sit in a different session, and would RESUME adding when it returned to the opening session. Note the target component alone, or with only one partner, still does not block - it needs the combination. The real "this premise is dead" gate is BasketPremiseDead(), which runs before staleness and is untouched by this.
input double BasketStaleBlockLevel       = 0.70;   // Basket stale block level
// BasketStalePrintOnUse: Log stale baskets
input bool   BasketStalePrintOnUse       = true;   // Basket stale print on use (on/off)
// SituationPlanAppliesToGrid: V228: keep using the situation and structure targets once the ladder is running. Without this a basket got its measured target on the first entry and then reverted to the estimate chain for every addition - so the target drifted further away with each rung, in a direction nothing had measured. The destination does not change because the ladder grew; only the average entry does.
input bool   SituationPlanAppliesToGrid  = true;   // Situation plan applies to grid (on/off)

// V215: candles matter most at a level and least in open space, so their budget scales with where
// price actually is. And when the readings CONFLICT, the conflict is often the information - a
// rejection that was then traded through is not a weaker rejection, it is a defence breaking, and
// summing the two readings cancels the most useful thing either found.
// EnableCandleRelevance: Scale the candle budget by proximity to a level
input bool   EnableCandleRelevance       = true;   // Enable candle relevance
// CandleRelevanceReachPoints: Distance ($2.50) within which candles are reading a level rather than open space
input int    CandleRelevanceReachPoints  = 2500;   // Candle relevance reach points
// CandleRelevanceFloor: Budget multiplier in open space - reduced, since a wick there is where the bar turned rather than where a level held
input double CandleRelevanceFloor        = 0.45;   // Candle relevance floor
// CandleRelevanceCeiling: And at a strong level, where the question the candle answers is the question that matters
input double CandleRelevanceCeiling      = 1.50;   // Candle relevance ceiling
// EnableCandleConflict: Read disagreement between candle modules as an event rather than adding them up
input bool   EnableCandleConflict        = true;   // Enable candle conflict
// CandleConflictScore: Weight of a named conflict - a defence breaking is among the clearest reads available
input int    CandleConflictScore         = 6;   // Candle conflict score
// CandleSplitDampen: Budget multiplier when readings simply disagree with no story - the layer is undecided and should say less
input double CandleSplitDampen           = 0.50;   // Candle split dampen
// CandleConflictPrintOnUse: Log named conflicts
input bool   CandleConflictPrintOnUse    = true;   // Candle conflict print on use (on/off)

// V216: each candle source learns its own accuracy. Ten modules, all trusted equally on the strength
// of their reasoning - reasoning that is sound in general and may be wrong here. Wick authorship
// might read this broker's spread badly; higher-timeframe agreement might be the only thing that
// matters on gold; live-bar evolution might be noise at this tick rate. The code cannot say. So each
// reading is recorded and graded by what price did afterwards, and a source that keeps being right
// earns a louder voice while one that keeps being wrong fades toward silence without ever being
// switched off. Graded per READING, not per trade - a module can be right about direction while the
// trade loses for unrelated reasons, and grading it on the trade would teach the wrong lesson.
// EnableCandleLearning: Let each candle source earn or lose weight from its own record
input bool   EnableCandleLearning        = true;   // Enable candle learning
// CandleLearningHorizonBars: Bars after a reading before it is graded
input int    CandleLearningHorizonBars   = 8;   // Candle learning horizon bars
// CandleLearningDecisivePoints: Move ($0.60) that counts as the reading being right or wrong - anything smaller was neither
input int    CandleLearningDecisivePoints = 600;   // Candle learning decisive points
// CandleLearningMinSamples: Graded calls before a source's record is used
input int    CandleLearningMinSamples    = 8;   // Candle learning min samples
// CandleLearningMaxSamples: Sample ceiling - conditions change
input int    CandleLearningMaxSamples    = 50;   // Candle learning max samples
// CandleLearningSensitivity: How hard accuracy moves the weight. At 0.60 a source right 80% of the time carries 1.36x, one right 20% carries 0.64x.
input double CandleLearningSensitivity   = 0.60;   // Candle learning sensitivity
// CandleLearningMinWeight: Floor - a bad patch quietens a source without silencing one that is fundamentally sound
input double CandleLearningMinWeight     = 0.35;   // Candle learning min weight
// CandleLearningMaxWeight: Ceiling - a run of luck cannot let one module dominate
input double CandleLearningMaxWeight     = 1.60;   // Candle learning max weight
// ShowCandleLearningOnDash: Show what each source has learned
input bool   ShowCandleLearningOnDash    = true;   // Show candle learning on dashboard
// PersistCandleLearning: V217: keep the candle records across restarts. Without this the learning resets every recompile and settings change - and since a source needs eight graded calls before its record counts, and eight calls take hours, a record that restarts from zero each session never arrives at anything.
input bool   PersistCandleLearning       = true;   // Persist candle learning (on/off)
// CandleLearningSaveEveryBars: How often the records are written back. Every tick is wasteful; only on deinit loses everything when the terminal closes unexpectedly, which it does.
input int    CandleLearningSaveEveryBars = 30;   // Candle learning save every bars
// CandleLearningPrintOnRestore: Log what was restored at startup
input bool   CandleLearningPrintOnRestore = true;   // Candle learning print on restore (on/off)

// V218: two gaps a live loss exposed - a buy filled at 4394.43 on a bar that had spiked to 4397 and
// come back, with M5 showing three lower highs behind it.
// THE ENTRY BAR: every other check reads bar 1 and later, so the bar an entry actually opens on was
// never examined. A fill in the upper third of a bar already rejected from its high looked the same
// as a fill at the low of a strong one.
// EnableEntryBarCheck: Examine the bar the entry would actually fill on
input bool   EnableEntryBarCheck         = true;   // Enable entry bar check
// EntryBarTF: Timeframe of the bar being filled on
input ENUM_TIMEFRAMES EntryBarTF         = PERIOD_M1;   // Entry bar TF
// EntryBarMinSizeATR: Bar size against ATR below which the entry bar is too small for its shape to mean anything - a fill anywhere in a tick-sized bar is the same fill.
input double EntryBarMinSizeATR          = 0.30;   // Entry bar min size ATR
// EntryBarBadPlacement: V218b: 0.60 -> 0.40. Tested against the actual loss: the fill sat at 49% of the bar\'s range on a bar with a 50% upper wick, and at 0.60 it passed without comment. The wick is what makes the placement bad, so the position threshold has to be low enough for the wick test to be reached at all.
input double EntryBarBadPlacement        = 0.40;   // Entry bar bad placement
// EntryBarRejectedWick: Wick share that marks the bar as having been pushed back from the extreme being bought toward
input double EntryBarRejectedWick        = 0.35;   // Entry bar rejected wick
// EntryBarPlacementWeight: V218b: 0.45 -> 0.30. More of the severity now comes from the REJECTION rather than the position. A fill halfway up a bar is unremarkable; a fill halfway up a bar that has given back half its range is buying into a sweep.
input double EntryBarPlacementWeight     = 0.30;   // Entry bar placement weight
// EntryBarMinSeverity: V218b: 0.35 -> 0.25, so the case that produced the loss registers rather than falling just under.
input double EntryBarMinSeverity         = 0.25;   // Entry bar min severity
// EntryBarPenalty: Cost of filling into the wick of a sweep - high, because this is what the loss was
input int    EntryBarPenalty             = 6;   // Entry bar penalty
// EntryBarPrintOnUse: Log poor entry-bar placement
input bool   EntryBarPrintOnUse          = true;   // Entry bar print on use (on/off)
// THE LOCAL SHAPE: whether each swing high sits below the last. Structure breaks and trend readings
// both lag this, and it is the first thing a trader sees.
// EnableLocalSwingShape: Read whether the recent swings are stepping up or down
input bool   EnableLocalSwingShape       = true;   // Enable local swing shape
// LocalSwingTF: Timeframe the swings are read on - the scale the setups are built at
input ENUM_TIMEFRAMES LocalSwingTF       = PERIOD_M5;   // Local swing TF
// LocalSwingLookbackBars: Bars searched for swings
input int    LocalSwingLookbackBars      = 60;   // Local swing lookback bars
// LocalSwingDepth: Bars either side that must be lower/higher for a swing to be confirmed
input int    LocalSwingDepth             = 2;   // Local swing depth
// LocalSwingMinSwings: Swings needed before the shape is read
input int    LocalSwingMinSwings         = 3;   // Local swing min swings
// LocalSwingFullSteps: Consecutive steps at which the shape carries full weight
input int    LocalSwingFullSteps         = 3;   // Local swing full steps
// LocalSwingScore: Weight of entering with or against the swing sequence
input int    LocalSwingScore             = 5;   // Local swing score
// LocalSwingPrintOnUse: Log entries taken against the swing shape
input bool   LocalSwingPrintOnUse        = true;   // Local swing print on use (on/off)

// V223: local structure read as SHAPE rather than as an indicator. Local trend is currently ADX,
// which answers "is there a trend" and says nothing about what it looks like - price stepping down
// in measured swings and price collapsing in one leg read the same, and they are different trades.
// The swing count added in V218 is closer, but it only counts; the measurements are where the
// information is. How far each step travels separates a trend with participants from a drift. Whether
// the steps grow or shrink says whether the move is being fed or running out - the last swing before
// a turn is almost always the smallest. And a sequence of lower highs has a specific price above
// which it stops being one, which defines both the invalidation and the target of any counter-trade.
// EnableLocalStructure: Measure the swing structure, not just its direction
input bool   EnableLocalStructure        = true;   // Enable local structure
// LocalStructureTF: Timeframe the structure is measured on
input ENUM_TIMEFRAMES LocalStructureTF   = PERIOD_M5;   // Local structure TF
// LocalStructureLookbackBars: Bars searched for swings
input int    LocalStructureLookbackBars  = 80;   // Local structure lookback bars
// LocalStructureDepth: Bars either side that confirm a swing
input int    LocalStructureDepth         = 2;   // Local structure depth
// LocalStructureMinSwings: Swings needed before the structure is read
input int    LocalStructureMinSwings     = 3;   // Local structure min swings
// LocalStructureFullSteps: Consecutive steps at which conviction is full
input int    LocalStructureFullSteps     = 3;   // Local structure full steps
// LocalStructureMinLegATR: Swing size against ATR below which the legs are drift rather than structure
input double LocalStructureMinLegATR     = 0.60;   // Local structure min leg ATR
// LocalStructureExpandThreshold: Growth in leg size that marks an accelerating move
input double LocalStructureExpandThreshold = 0.25;   // Local structure expand threshold
// LocalStructureFadeThreshold: And shrinkage that marks one running out
input double LocalStructureFadeThreshold = 0.25;   // Local structure fade threshold
// LocalStructureExpandFactor: Weight multiplier when the structure is accelerating
input double LocalStructureExpandFactor  = 1.25;   // Local structure expand factor
// LocalStructureFadeWithFactor: Trading WITH a fading structure is late
input double LocalStructureFadeWithFactor = 0.55;   // Local structure fade with factor
// LocalStructureFadeAgainstFactor: And against it is early, but a turn is genuinely possible
input double LocalStructureFadeAgainstFactor = 0.70;   // Local structure fade against factor
// LocalStructureScore: Weight of trading with or against the measured structure
input int    LocalStructureScore         = 5;   // Local structure score
// LocalStructureNearInvalidation: Distance ($1.20) at which the structure's end price is close enough to make a counter-trade's risk defined and cheap
input int    LocalStructureNearInvalidation = 1200;   // Local structure near invalidation
// LocalStructureInvalidationBonus: Credit for that
input int    LocalStructureInvalidationBonus = 2;   // Local structure invalidation bonus
// LocalStructurePrintOnUse: Log structure readings
input bool   LocalStructurePrintOnUse    = true;   // Local structure print on use (on/off)
// ShowLocalStructureOnDash: Show the measured structure
input bool   ShowLocalStructureOnDash    = true;   // Show local structure on dashboard

// V224: the invalidation price put to work. V223 computes the price at which the local structure
// stops existing and then uses it for a two-point bonus, which is the least valuable thing that
// number can do. It is the only price on the chart with a precise meaning - above it a downtrend is
// not a downtrend, by definition rather than by threshold.
// EnableStructureBreak: Treat a structure ending as an event, not something noticed a bar later
input bool   EnableStructureBreak        = true;   // Enable structure break
// StructureBreakFreshBars: How long a break stays relevant - by twenty bars whatever it started has already happened
input int    StructureBreakFreshBars     = 10;   // Structure break fresh bars
// StructureBreakScore: Weight of a fresh break. High: this is the measured thing changing state, not an indicator crossing a line.
input int    StructureBreakScore         = 6;   // Structure break score
// StructureBreakPrintOnUse: Log structure breaks
input bool   StructureBreakPrintOnUse    = true;   // Structure break print on use (on/off)
// EnableStructureTarget: Use the invalidation price as the target for a counter-structure trade
input bool   EnableStructureTarget       = true;   // Enable structure target
// StructureTargetReachFactor: Stop short of it, as with any level-based target
input double StructureTargetReachFactor  = 0.85;   // Structure target reach factor
// StructureTargetPrintOnUse: Log structure-based targets
input bool   StructureTargetPrintOnUse   = true;   // Structure target print on use (on/off)
// EnableStructureConfluence: Notice when the structure ends where a zone sits
input bool   EnableStructureConfluence   = true;   // Enable structure confluence
// StructureConfluenceTolerance: How close ($0.70) the two must be to count as the same price
input int    StructureConfluenceTolerance = 700;   // Structure confluence tolerance
// StructureConfluenceMinWeight: Agreement below which it is coincidence rather than confluence
input double StructureConfluenceMinWeight = 0.35;   // Structure confluence min weight
// StructureConfluenceScore: Credit for two independent readings landing on one price
input int    StructureConfluenceScore    = 3;   // Structure confluence score

// V225: structure across timeframes, and how far it has already run. The measured structure reads
// one scale and treats what it finds as the answer; it is one answer at one scale, and the scale
// above usually decides what it means. Three lower highs on M5 inside a rising M15 is a pullback,
// and trading it as a downtrend means selling the dip of an uptrend - indistinguishable from the
// real thing without looking up. Reading three also produces something none has alone: their
// RELATIONSHIP - full agreement, a pullback, or a transition where nothing is settled.
// EnableStructureMTF: Read the structure on three timeframes and use their relationship
input bool   EnableStructureMTF          = true;   // Enable structure MTF
// StructureMTFMiddle: The scale above the one structure is measured on
input ENUM_TIMEFRAMES StructureMTFMiddle = PERIOD_M15;   // Structure MTF middle
// StructureMTFHigher: And above that
input ENUM_TIMEFRAMES StructureMTFHigher = PERIOD_H1;   // Structure MTF higher
// StructureAlignFullBoost: Extra weight when all three agree - the rarest condition on the chart
input double StructureAlignFullBoost     = 1.20;   // Structure align full boost
// StructureAlignScore: Weight of trading with or against full agreement
input int    StructureAlignScore         = 6;   // Structure align score
// StructurePullbackScore: Weight of reading a pullback correctly - or of trading it as if it were the trend
input int    StructurePullbackScore      = 5;   // Structure pullback score
// StructureTransitionPenalty: Cost of committing while the timeframes are still deciding
input int    StructureTransitionPenalty  = 3;   // Structure transition penalty
// StructureMTFPrintOnUse: Log the timeframe picture
input bool   StructureMTFPrintOnUse      = true;   // Structure MTF print on use (on/off)
// EnableStructureMaturity: Measure how far the structure has already travelled
input bool   EnableStructureMaturity     = true;   // Enable structure maturity
// StructureMatureATR: Distance in ATR at which a structure has gone as far as these usually go
input double StructureMatureATR          = 6.0;   // Structure mature ATR
// StructureMatureFrom: Share of that distance before joining late starts costing
input double StructureMatureFrom         = 0.55;   // Structure mature from
// StructureMaturityScore: Weight of joining a finished move, or of fading one
input int    StructureMaturityScore      = 4;   // Structure maturity score

// V226: one line saying whether any of this is working. Twenty modules were added in a single
// session and not one was ever observed running - balanced braces prove the file compiles and prove
// nothing about whether a detector finds what it was written to find. That is how a session ends
// with an EA taking two trades in twelve hours: each module looked reasonable, none was verified,
// and the failure only surfaced when the account stopped trading. "Answering" means the module ran
// and returned something coherent, not that it found a signal - a pattern detector correctly finding
// no pattern is healthy, one that cannot read its candles is not, and until you ask directly the two
// look identical.
// EnableModuleHealth: Check each module is answering and show the count
input bool   EnableModuleHealth          = true;   // Enable module health
// ShowModuleHealthOnDash: Show it on the dashboard
input bool   ShowModuleHealthOnDash      = true;   // Show module health on dashboard
// ShowSilentModuleNames: And name anything that is not answering
input bool   ShowSilentModuleNames       = true;   // Show silent module names
// ShowDetailedDiagnostics: V226: the per-module detail lines. Off by default now that the health count says whether they are working - twenty diagnostic lines nobody reads are worse than one number that gets checked. Turn on when investigating something specific.
input bool   ShowDetailedDiagnostics     = false;   // Show detailed diagnostics
// ShowLegacyModuleLines: V226b: the per-pack status lines (GRID, DRI, DXB, PACK2, PACK3, RC, P4M, P4L, RCB, FSA, RLS, DCS, NIM, FPR, SGV, CDP, DPH, FBL, LVP, WCP, PV). Twenty-one lines that were useful while each pack was being built and are now noise - the summary and health count cover what they were watched for. Turn on to inspect a specific pack.
input bool   ShowLegacyModuleLines       = false;   // Show legacy module lines
// DashboardFullDetail: V226b: the master switch for everything beyond the essentials. The dashboard had grown to a hundred and forty lines, which is past the point where anyone reads it - and an unread dashboard is the same as no dashboard, which is how a stalled EA went unnoticed for hours. What stays on: the version and status line, the account and risk figures, the current mode, ENV, the basket, the market and score block, the module health count, and whatever is currently blocking a trade. Everything else is one setting away when it is needed.
input bool   DashboardFullDetail         = false;   // Dashboard full detail (on/off)
// ShowDashboardLineCount: V227b: print the line count at the bottom. Static analysis of which lines are visible kept disagreeing with what actually appeared on screen - the guards nest three deep in places - so the EA counts them itself.
input bool   ShowDashboardLineCount      = true;   // Show dashboard line count
// EnableGridStructureCheck: V225: let the grid see the structure's invalidation price. Additions belong inside the structure the basket is fighting, not beyond it - past that point the structure has to be wrong for the basket to be right.
input bool   EnableGridStructureCheck    = true;   // Enable grid structure check
// GridDoubtStructureAgainst: Weight added to grid doubt when price has left the structure the basket was opened inside
input double GridDoubtStructureAgainst   = 0.30;   // Grid doubt structure against

// V233: the grid reads structure and timeframes and never looks at the bar in front of it. So an
// addition goes in during the exact candle driving price away from the basket - the worst moment
// available, because the size is committed at the fastest part of the adverse move and the next
// addition then has to be larger still. These are the same readings the entry engine uses, applied
// to the decision they never covered.
// EnableGridCandleRead: Let the grid see the candles before adding
input bool   EnableGridCandleRead        = true;   // Enable grid candle read
// GridDoubtBigBarWeight: Weight of a single dominant bar running against the basket
input double GridDoubtBigBarWeight       = 0.30;   // Grid doubt big bar weight
// GridDoubtPressureWeight: Weight of a run of closes going the wrong way
input double GridDoubtPressureWeight     = 0.25;   // Grid doubt pressure weight
// GridDoubtLiveBarWeight: Weight of the bar currently forming, scaled by how much of it has happened
input double GridDoubtLiveBarWeight      = 0.20;   // Grid doubt live bar weight

// V236: from two live stop-outs - a buy at the top of a $24 run that then fell $48, and a sell at
// the bottom of a $99 decline that then rose $32. Both baskets opened at the end of a move, and in
// both the grid kept adding into the reversal. The entry engine reads move maturity and refuses
// these; the grid never did, so once a basket exists the ladder walks into the same extended move
// the entry side would have rejected - each rung larger than the last. An adverse move that has
// already run its usual distance is what the ladder is worst suited to, because it does not retrace
// on the schedule the arithmetic assumes.
// EnableGridMaturityCheck: Let the grid see how far the move against it has already gone
input bool   EnableGridMaturityCheck     = true;   // Enable grid maturity check
// GridMaturityFrom: Share of a structure's usual distance before adding into it starts counting against the basket
input double GridMaturityFrom            = 0.60;   // Grid maturity from
// GridDoubtMaturityWeight: Weight of a mature adverse structure
input double GridDoubtMaturityWeight     = 0.35;   // Grid doubt maturity weight
// GridDoubtExtensionWeight: Weight of the adverse move being past its climax point - the same threshold the entry engine waits at
input double GridDoubtExtensionWeight    = 0.25;   // Grid doubt extension weight

// V240: the assumption under the whole ladder. Every grid rests on price coming back - the
// multiplier, the spacing and the recovery arithmetic only work if that holds. It holds in a range
// and fails in a trend, where the ladder adds size in the direction price is leaving until the
// account settles the matter. The EA classifies the market and the grid never read it: GridCanOpen
// checks MARKET_IMPULSE and nothing else. Both live stop-outs were ladders built against a trend.
// EnableGridRegimeCheck: Let the grid see whether the regime supports its premise
input bool   EnableGridRegimeCheck       = true;   // Enable grid regime check
// RegimeAgainstBase: Baseline weight when the ladder runs against a classified trend
input double RegimeAgainstBase           = 0.45;   // Regime against base
// RegimeAlignedBonus: Added when all timeframes confirm that trend - three scales agreeing is a trend, one is a reading
input double RegimeAlignedBonus          = 0.25;   // Regime aligned bonus
// RegimeExpandingBonus: Added when the trend is still making new extremes against the basket
input double RegimeExpandingBonus        = 0.20;   // Regime expanding bonus
// RegimeFadingRelief: Subtracted when it is fading - a trend running out is when the ladder's premise starts working again
input double RegimeFadingRelief          = 0.20;   // Regime fading relief
// GridDoubtRegimeWeight: How much regime contradiction counts toward holding additions. The heaviest single input, because it questions the premise rather than the timing.
input double GridDoubtRegimeWeight       = 0.40;   // Grid doubt regime weight
// GridQualityRegimeWeight: And how much it reduces the size of an addition that still goes ahead
input double GridQualityRegimeWeight     = 0.30;   // Grid quality regime weight

// V241: the shape of the ladder. The grid is always the same - seven rungs, 1.30x, even spacing.
// Distance adapts through half a dozen modules; the shape never does. But a strong level just
// behind the entry calls for two or three close rungs at full size, and a trend running against the
// basket calls for more rungs, each smaller, spaced wide - survival rather than recovery speed.
// Chosen at the START, because every rung after the first is constrained by the ones before it.
// EnableLadderShaping: Choose the ladder's shape when the basket opens
input bool   EnableLadderShaping         = true;   // Enable ladder shaping
// LadderAnchorMaxDistance: How far behind ($2.50) a level can be and still anchor a short ladder
input int    LadderAnchorMaxDistance     = 2500;   // Ladder anchor max distance
// LadderAnchorMinStrength: Level strength worth building a short ladder against
input double LadderAnchorMinStrength     = 1.8;   // Ladder anchor min strength
// LadderShortOrders: Rungs when leaning on a level - if it holds this is enough, if it fails more would not have helped
input int    LadderShortOrders           = 3;   // Ladder short orders
// LadderShortSpacing: Spacing factor, tighter - the level is close and the recovery should be too
input double LadderShortSpacing          = 0.75;   // Ladder short spacing
// LadderLongFromContradiction: Regime contradiction above which the ladder is built for survival
input double LadderLongFromContradiction = 0.50;   // Ladder long from contradiction
// LadderLongExtraOrders: V249fix: 2 -> 0. The "long" shape ALSO widens spacing (LadderLongSpacing 1.30), so +2 rungs on top made it by far the most expensive shape - ~$7.4k projected vs the ~$4.2k budget, i.e. the affordability gate (which must assume the worst shape, since the shape is chosen after the entry) would have gone on refusing every entry even at MaxOrders 5. At 0 - and with LadderLongSpacing also back to 1.00 - the long shape now differs from default ONLY by its gentler multiplier: same rung count, same spacing, so it is strictly SMALLER than the default ladder rather than longer. That is the safe direction and it is what keeps the worst-case shape inside the budget, but be aware the "built to survive a long trend" character is largely neutralised. Restore depth here only together with a bigger balance or a lower StartLot/MaxOrders.   // Extra rungs when against a trend
input int    LadderLongExtraOrders       = 0;   // Ladder long extra orders
// LadderMaxOrdersCap: Absolute ceiling regardless of shape
input int    LadderMaxOrdersCap          = 9;   // Ladder max orders cap
// LadderLongMultReduction: How much the multiplier drops - smaller rungs, since there may be many of them
input double LadderLongMultReduction     = 0.10;   // Ladder long multiplier reduction
// LadderLongSpacing: V249fix: 1.30 -> 1.00. Wider spacing multiplies on top of the grid's own geometric widening, which made "long" by far the most expensive shape (~$4.6k projected vs a ~$4.2k budget on a ~$10k account) - and since LadderIsAffordable() must assume the worst shape the engine could pick, that one shape alone kept refusing EVERY first entry even at MaxOrders 5. The long ladder still differs from default through its gentler multiplier (LotMultiplier - LadderLongMultReduction). Raise again only with a bigger balance or a lower MaxOrders/StartLot.   // And wider spacing, since the move may run
input double LadderLongSpacing           = 1.00;   // Ladder long spacing
// LadderCautiousFewerOrders: Rungs removed when nothing is readable
input int    LadderCautiousFewerOrders   = 2;   // Ladder cautious fewer orders
// LadderCautiousMultReduction: And the multiplier reduction that goes with it
input double LadderCautiousMultReduction = 0.08;   // Ladder cautious multiplier reduction
// LadderShapePrintOnUse: Log the chosen shape
input bool   LadderShapePrintOnUse       = true;   // Ladder shape print on use (on/off)

// V242: what the system is actually earning. A grid produces a very high win rate and that number
// says almost nothing - most baskets close at target for a small amount and the occasional one stops
// out for ten times that. Eighty-five percent wins can be a losing system, and it looks like a
// winning one on every screen the EA draws. This computes the only figure that settles it: what an
// average basket is worth. Not a filter - a reading, like looking at the account curve instead of
// the last trade.
// EnableExpectancy: Track what an average basket earns
input bool   EnableExpectancy            = true;   // Enable expectancy
// ExpectancyMinSamples: Baskets before the figure means anything
input int    ExpectancyMinSamples        = 15;   // Expectancy min samples
// ExpectancyMaxSamples: Window - a figure covering three months of a different market describes that market, not this one
input int    ExpectancyMaxSamples        = 100;   // Expectancy max samples
// PersistExpectancy: Keep the record across restarts. Fifteen baskets take days to accumulate; starting from zero each session means never arriving at an answer.
input bool   PersistExpectancy           = true;   // Persist expectancy (on/off)
// ShowExpectancyOnDash: Show it on the dashboard
input bool   ShowExpectancyOnDash        = true;   // Show expectancy on dashboard

// V244: can the basket actually get home? BasketHealthIndex measures what has been SPENT - drawdown
// against the stop, rungs against the maximum, margin against the ceiling. Every component answers
// "how much is used up" and none answers the question that decides the outcome: is the target still
// reachable? Five rungs deep with the target four dollars away and five rungs deep with it forty
// cents away look identical on every reading the EA takes.
// EnableBasketReach: Measure how far the basket still has to travel
input bool   EnableBasketReach           = true;   // Enable basket reach
// BasketReachComfortATR: Distance in ATR the basket can cover in an ordinary session
input double BasketReachComfortATR       = 3.0;   // Basket reach comfort ATR
// BasketReachFarATR: Beyond this it is asking for a move the timeframe does not usually produce
input double BasketReachFarATR           = 10.0;   // Basket reach far ATR
// BasketReachDoubtBelow: Reachability below which the next rung starts counting against the basket
input double BasketReachDoubtBelow       = 0.50;   // Basket reach doubt below
// GridDoubtReachWeight: How much an unreachable target counts toward holding additions
input double GridDoubtReachWeight        = 0.30;   // Grid doubt reach weight
// ShowBasketReachOnDash: Show the distance and what the next rung would do to it
input bool   ShowBasketReachOnDash       = true;   // Show basket reach on dashboard

// V219: zones, candles and structure read as ONE observation rather than three. Falling swing highs,
// price arriving at a support, and a rejection printing there is a downtrend testing a level that is
// holding - one situation, worth more than the sum of its parts because the parts corroborate each
// other. Change one part and the meaning inverts: the same three inputs with the rejection FAILING
// mean the level gave way. Adding scores produces something in the middle, which is wrong in both
// cases.
// EnableSituationRead: Read zone, candle and structure together and name what they describe
input bool   EnableSituationRead         = true;   // Enable situation read
// SituationLevelReachPoints: Distance ($1.20) within which price counts as being AT the level
input int    SituationLevelReachPoints   = 1200;   // Situation level reach points
// SituationMinLevelStrength: Level strength below which there is nothing to corroborate
input double SituationMinLevelStrength   = 1.4;   // Situation min level strength
// SituationFullStrength: Strength at which the level contributes fully
input double SituationFullStrength       = 2.5;   // Situation full strength
// SituationExhaustionBoost: Extra weight when the trend arriving at the level is already stretched - the strongest of the four cases, since it is a turn rather than a pause
input double SituationExhaustionBoost    = 1.35;   // Situation exhaustion boost
// SituationMinWeight: Corroboration below which the situation is not named
input double SituationMinWeight          = 0.30;   // Situation min weight
// SituationScore: Weight of a named situation - higher than any single layer, because three layers agreeing is a different thing from one layer speaking
input int    SituationScore              = 8;   // Situation score
// SituationSuppressFactor: Share of the individual candle contributions kept once a situation is named. The rest is the same evidence a second time.
input double SituationSuppressFactor     = 0.40;   // Situation suppress factor
// SituationPrintOnUse: Log named situations
input bool   SituationPrintOnUse         = true;   // Situation print on use (on/off)

// V220: the situation sets the trade, not just the score. Each of the four calls for a materially
// different trade and the EA was giving all of them the same target and the same grid. A level that
// held is a bounce - the target is the way back across the range and the grid can be tight. A level
// that broke is a continuation - the target is the next level and the grid must be wide, or the
// ladder fills in one leg. A stretched trend refused is a reversal - the largest target, since the
// whole prior move is now the room, and the smallest size, since reversals fail more than they work.
// EnableSituationPlan: Let the named situation set target, grid spacing and size
input bool   EnableSituationPlan         = true;   // Enable situation plan
// SituationTargetReachFactor: Stop short of the level rather than at it - the last stretch is where price stalls, and a target sitting exactly on a level often misses by a tick
input double SituationTargetReachFactor  = 0.85;   // Situation target reach factor
// SituationTargetMinPoints: Below this the trade does not clear its own costs
input int    SituationTargetMinPoints    = 1200;   // Situation target min points
// SituationTargetMaxPoints: Above this it is no longer the strategy that was tested
input int    SituationTargetMaxPoints    = 6000;   // Situation target max points
// SituationGridHeld: Grid spacing when a level is holding - a bounce is the premise, so additions can sit closer
input double SituationGridHeld           = 0.80;   // Situation grid held
// SituationGridBroke: And when it broke - price is travelling, not oscillating
input double SituationGridBroke          = 1.35;   // Situation grid broke
// SituationGridReversal: A failed reversal fails hard; wide spacing buys room to be wrong
input double SituationGridReversal       = 1.50;   // Situation grid reversal
// SituationLotHeld: A level holding within a range is the most repeatable of the four
input double SituationLotHeld            = 1.00;   // Situation lot held
// SituationLotBroke: Continuations run, but the entry is chasing
input double SituationLotBroke           = 0.90;   // Situation lot broke
// SituationLotReversal: Reversals fail more often than they work
input double SituationLotReversal        = 0.75;   // Situation lot reversal

// V231: the broken level that held from the other side. The EA could see both halves of this and
// never joined them - StructureBreak records the level being taken, ZoneRetest finds price returning
// to it, and separately they are a break and a retest. Together they are the highest-quality
// continuation available: what was resistance is now support, everyone who sold it is wrong, and the
// move that broke it has already demonstrated it can.
// EnableBrokenRetest: Recognise a broken level being retested from its new side as one situation
input bool   EnableBrokenRetest          = true;   // Enable broken retest
// BrokenRetestTolerance: How close ($0.90) price must return to count as retesting rather than merely being nearby
input int    BrokenRetestTolerance       = 900;   // Broken retest tolerance
// BrokenRetestMinStrength: Level strength worth retesting. A minor swing breaking and being retested is price moving; a level with history changing sides is structural.
input double BrokenRetestMinStrength     = 1.5;   // Broken retest min strength
// BrokenRetestWeightBoost: Extra weight over the other four situations - this one has the clearest invalidation and the most participants already positioned against it
input double BrokenRetestWeightBoost     = 1.25;   // Broken retest weight boost
// SituationGridRetest: Grid spacing here. Tight, because the invalidation sits just the other side of the level - if price goes back through, spacing will not save the basket.
input double SituationGridRetest         = 0.85;   // Situation grid retest
// SituationLotRetest: Full size - the most repeatable of the five
input double SituationLotRetest          = 1.00;   // Situation lot retest

// V232: from a live loss - M1 broke a resistance and the retest read clean, while on M5 and M15 the
// level had never gone anywhere and a long wick was sitting right on it. The EA bought a break that
// only existed at the resolution it happened to be watching, into the place stops had collected.
// EnableBrokenRetestMTF: Require the break to survive being looked at from further away. A level the higher timeframe still shows intact is not a broken level - it is a level being tested, with price on the wrong side of it.
input bool   EnableBrokenRetestMTF       = true;   // Enable broken retest MTF
// BrokenRetestConfirmTF: The scale the break must also have cleared
input ENUM_TIMEFRAMES BrokenRetestConfirmTF = PERIOD_M15;   // Broken retest confirm TF
// EnableBrokenRetestWickCheck: Reject a retest sitting under a long higher-timeframe wick. Stops collect there, price is drawn to them, and what looks like support holding is often price being pulled through it.
input bool   EnableBrokenRetestWickCheck = true;   // Enable broken retest wick check
// BrokenRetestWickBars: Higher-timeframe bars searched for such a wick
input int    BrokenRetestWickBars        = 6;   // Broken retest wick bars
// BrokenRetestWickMinRatio: Wick share of its bar's range before it counts as liquidity rather than noise
input double BrokenRetestWickMinRatio    = 0.40;   // Broken retest wick min ratio
// BrokenRetestWickTolerance: How close ($1.00) the wick's tip must come to the level
input int    BrokenRetestWickTolerance   = 1000;   // Broken retest wick tolerance
// BrokenRetestPrintOnUse: Log rejected retests
input bool   BrokenRetestPrintOnUse      = true;   // Broken retest print on use (on/off)
// SituationPlanPrintOnUse: Log the plan a situation produces
input bool   SituationPlanPrintOnUse     = true;   // Situation plan print on use (on/off)

// V221: the grid decides WHERE to add, not only when. Distance says an addition is due; it says
// nothing about whether the addition is a good idea, and the grid has never separated those.
// DIRECTION: the first entry passes forty modules deciding the direction is right. Additions inherit
// that and are never re-tested, so a basket opened into what looked like a pullback keeps adding
// while the pullback becomes a trend change - each addition larger than the last. When the premise
// is gone the grid HOLDS: it does not close, because closing into a move that has just gone against
// the basket realises the loss at its worst point. What stops is the compounding.
// EnableGridDirectionCheck: Re-examine the basket's direction before each addition
input bool   EnableGridDirectionCheck    = true;   // Enable grid direction check
// GridDoubtSwingWeight: Weight of the swing sequence turning against the basket
input double GridDoubtSwingWeight        = 0.35;   // Grid doubt swing weight
// GridDoubtStructureWeight: Weight of a structure break against it
input double GridDoubtStructureWeight    = 0.25;   // Grid doubt structure weight
// GridDoubtHTFWeight: Weight of the higher-timeframe candle disagreeing
input double GridDoubtHTFWeight          = 0.20;   // Grid doubt HTF weight
// GridDoubtSituationWeight: Weight of a named situation pointing the other way - three layers agreeing, so the heaviest single input
input double GridDoubtSituationWeight    = 0.40;   // Grid doubt situation weight
// GridDoubtBlockLevel: Accumulated doubt at which additions are held. Deliberately high: the grid exists to recover from being wrong, so it must not stop at the first sign of it.
input double GridDoubtBlockLevel         = 0.60;   // Grid doubt block level
// LOCATION: the arithmetic puts the addition wherever the multiplier lands. A strong level just
// beyond that is where the addition belongs - adding above it buys the last of the move rather than
// the thing that stops it.
// EnableGridLevelSnap: Wait for a nearby level rather than adding at the arithmetic price
input bool   EnableGridLevelSnap         = true;   // Enable grid level snap
// GridSnapMinStrength: Level strength below which it is not worth waiting for
input double GridSnapMinStrength         = 1.6;   // Grid snap min strength
// GridSnapMaxShiftPoints: How much further ($1.50) the addition may be moved - beyond this it is a different trade, not a better fill
input int    GridSnapMaxShiftPoints      = 1500;   // Grid snap max shift points
// GridSnapMinSpacingFactor: Minimum spacing retained relative to the account rules
input double GridSnapMinSpacingFactor    = 0.85;   // Grid snap min spacing factor

// V222: the size of an addition should match its quality. The ladder multiplies by 1.30 regardless
// of where the addition lands, so the largest commitment of the basket - order seven, four times the
// starting size - goes in at the deepest point of the drawdown, at whatever price the arithmetic
// produced, with no reading of whether that price is worth defending. Size still has to grow or the
// recovery does not work; what changes is that it grows MORE where there is something to add against
// and LESS where there is not.
// EnableGridQualityLot: Size each addition by how good its location is
input bool   EnableGridQualityLot        = true;   // Enable grid quality lot
// GridQualityLevelTolerance: How close ($0.80) a level must be for the addition to count as landing on it
input int    GridQualityLevelTolerance   = 800;   // Grid quality level tolerance
// GridQualityFullStrength: Level strength at which the location credit is full
input double GridQualityFullStrength     = 2.2;   // Grid quality full strength
// GridQualityLevelWeight: Credit for adding against a real level rather than into open space
input double GridQualityLevelWeight      = 0.35;   // Grid quality level weight
// GridQualityDoubtWeight: Cost of the basket's direction having deteriorated since it opened
input double GridQualityDoubtWeight      = 0.30;   // Grid quality doubt weight
// GridQualityDeepFrom: Share of the stop-loss budget used before depth starts reducing size - the deepest additions decide whether a basket survives and are the least reversible
input double GridQualityDeepFrom         = 0.50;   // Grid quality deep from
// GridQualityDeepWeight: How much depth reduces the addition
input double GridQualityDeepWeight       = 0.25;   // Grid quality deep weight
// GridQualityBigBarWeight: V233: how much a dominant bar shifts the addition's size. Against the basket it is filling at the worst price of an adverse push; with the basket it means the recovery has begun, which the ladder's arithmetic cannot see.
input double GridQualityBigBarWeight     = 0.25;   // Grid quality big bar weight
// GridQualityMinFactor: Smallest an addition can be trimmed to - below this the ladder stops recovering at the rate it was designed for
input double GridQualityMinFactor        = 0.70;   // Grid quality min factor
// GridQualityMaxFactor: And the most it can be increased at an excellent location
input double GridQualityMaxFactor        = 1.15;   // Grid quality max factor
// GridQualityPrintOnUse: Log addition quality readings
input bool   GridQualityPrintOnUse       = true;   // Grid quality print on use (on/off)
// MaxTotalScoreBonus: V278: 16 -> 26. Live screens show raw penalty running at thirty to forty-seven against a raw bonus of ten to twenty-eight, and the EA not trading at all. There are a hundred and thirty places that can add penalty and roughly a quarter of them were added today; the bonus side never grew with them. Twenty-six lets a setup that eleven modules agree on express that agreement against objections that now come from a much larger pool.     // V255: 12 -> 16. Penalties grew all day - band entries, sweep bars, reversal context, volatility shift, premium depth - and the bonus ceiling did not move with them. A setup can now accumulate twenty points of genuine agreement and have eight of them discarded while every point of objection survives, which makes a strong setup and a marginal one score the same. The two ceilings have to move together or the scoring quietly becomes one-sided.     // V171: 8 -> 12. When V170 raised the penalty cap to 14 it left the bonus cap at 8, so any three moderate penalties outweighed every bonus the EA could produce and the score could not recover no matter how good the setup was. A ceiling on what can argue FOR a trade must not sit below the ceiling on what can argue against it.
input int               MaxTotalScoreBonus       = 26;   // Max total score bonus
// MaxTrendAlignBonus: V259: 7 -> 8, moved with the trend-against ceiling so agreement and objection stay symmetric.      // V171: 5 -> 7, in proportion with the total bonus cap above. The trend-agreement group still cannot dominate, but it can now contribute meaningfully within a 12-point budget.
input int               MaxTrendAlignBonus       = 8;   // Max trend align bonus
// UseDirectionRedirect: If the preferred direction has no signal, look for one in the opposite direction
input bool              UseDirectionRedirect     = true;   // Use direction redirect
input bool              RedirectOnlyOnScoreWait  = true;   // Redirect only on score wait (on/off)
input bool              RedirectAllowMicro        = true;   // Redirect allow micro (on/off)
input int               RedirectMinScore          = 4;   // Redirect min score
input int               RedirectMinImprovement    = 1;   // Redirect min improvement
input bool              RedirectRespectMarketTrend = true;   // Redirect respect market trend (on/off)
input bool              RedirectAvoidChaosImpulse = true;   // Redirect avoid chaos impulse (on/off)
input bool              PrintRedirectDecisions    = true;   // Print redirect decisions
// UseSignalQueue: Remember a valid signal for a few bars if it can't fire immediately
input bool              UseSignalQueue           = true;   // Use signal queue
// SignalQueueBars: How many bars a queued signal stays valid
input int               SignalQueueBars          = 3;   // Signal queue bars
// EnableQueueReplayRevalidation: V31.6z33 NEW: real gap found - a replayed queued signal used to fire with its ORIGINAL, now-stale score, bypassing every fresh check built this session
input bool              EnableQueueReplayRevalidation = true;   // Enable queue replay revalidation
input double            QueueReplayExhaustionBlockThreshold = 0.30;   // Queue replay exhaustion block threshold
input double            QueueReplayGlobalLocalBlockThreshold = 0.30;   // Queue replay global local block threshold
input int               SignalQueueMaxAgeSeconds = 300;   // Signal queue max age seconds
input int               SignalQueueMaxSpreadPoints = 300;   // Signal queue max spread points
input bool              SignalQueueRefreshBetter = true;   // Signal queue refresh better (on/off)
input bool              SignalQueueExpireOnOppositePass = true;   // Signal queue expire on opposite pass (on/off)
input bool              SignalQueueReplayWhenCurrentWait = true;   // Signal queue replay when current wait (on/off)
input bool              PrintQueueDecisions      = true;   // Print queue decisions

input bool              UseMissedTradeMemory     = true;   // Use missed trade memory
input int               MissedMemoryRepeatThreshold = 2;   // Missed memory repeat threshold
input int               MissedMemoryLookbackBars = 8;   // Missed memory lookback bars
input int               MissedMemoryNearPassGap  = 2;   // Missed memory near pass gap
input int               MissedMemoryScoreBoost   = 1;   // Missed memory score boost
// MissedMemoryRespectFreshChecks: V31.6z34 NEW: real conflict found - "kept almost passing" used to justify a forced boost even when today's Exhaustion Consensus / Global-Local Trend correctly, repeatedly say no
input bool              MissedMemoryRespectFreshChecks = true;   // Missed memory respect fresh checks (on/off)
input double            MissedMemoryExhaustionBlockThreshold = 0.30;   // Missed memory exhaustion block threshold
input double            MissedMemoryGlobalLocalBlockThreshold = 0.30;   // Missed memory global local block threshold
input int               MissedMemoryMaxBoost     = 2;   // Missed memory max boost
input bool              MissedMemoryBoostOnlyNearPass = true;   // Missed memory boost only near pass (on/off)
input bool              MissedMemoryAllowMicroBoost = true;   // Missed memory allow micro boost (on/off)
input bool              MissedMemoryIgnoreHardBlocks = true;   // Missed memory ignore hard blocks (on/off)
input bool              MissedMemoryResetOnEntry = true;   // Missed memory reset on entry (on/off)
input bool              PrintMissedMemoryEvents  = true;   // Print missed memory events

input bool              UseBlockExpiryEngine     = true;   // Use block expiry engine
input int               BlockExpiryScoreWeakBars = 3;   // Block expiry score weak bars
input int               BlockExpiryImpulseBars   = 3;   // Block expiry impulse bars
input int               BlockExpiryRoomBars      = 2;   // Block expiry room bars
input int               BlockExpiryMicroBars     = 2;   // Block expiry micro bars
input int               BlockExpiryRedirectBars  = 2;   // Block expiry redirect bars
input int               BlockExpiryBOSBars       = 5;   // Block expiry BOS bars
input int               BlockExpiryZoneBars      = 2;   // Block expiry zone bars
input int               BlockExpiryMaxSeconds    = 600;   // Block expiry max seconds
input bool              BlockExpiryAllowExpiredSoftPass = true;   // Block expiry allow expired soft pass
input int               ExpiredBlockScoreBoost   = 1;   // Expired block score boost
input bool              PrintBlockExpiryEvents   = true;   // Print block expiry events
input bool              UseFirstEntryEngine      = true;   // Use first entry engine
input bool              OneBasketAtATime         = true;   // One basket at a time (on/off)
// FirstEntryCooldownBars: BOSQICH 5A: 1 -> 0. TP dan keyin keyingi savat o'sha M1 barida ham ochilishi mumkin
input int               FirstEntryCooldownBars   = 0;   // First entry cooldown bars
// CloseDeviationPoints: FIX(exit-slippage-cap): max slippage on EXITS ($3.00). Closes used to inherit OrderSendDeviationPoints (50 = $0.05) from the shared CTrade object, so a basket stop during a news spike was rejected as a requote and simply did not execute - the worst possible moment to fail. A stop that does not fill is far more expensive than one that slips, so keep this well above the entry cap.
input int               CloseDeviationPoints     = 3000;   // Close deviation points
// CloseRetryPasses: FIX(close-no-retry): how many times the basket close loop re-tries the positions that failed to close. 1 = old single-attempt behaviour.
input int               CloseRetryPasses         = 3;   // Close retry passes
// CloseRetryDelayMs: FIX(close-retry-same-quote): pause between basket-close passes (live only), so a requote is retried at a fresh price instead of the same one
input int               CloseRetryDelayMs        = 300;   // Close retry delay ms
// OrderSendDeviationPoints: V90b: 30 -> 50 ($0.05). At $0.03 fast XAUUSD moves (impulse/news tick slippage of $0.05-0.20) were getting orders rejected/requoted, which delays a grid add and distorts the spacing. $0.05 lets orders fill on time while still capping how bad a fill can be.
input int               OrderSendDeviationPoints = 50;   // Order send deviation points
// MinSecondsBetweenEntries: BOSQICH 5A: 30 -> 10. Ikki marta yuborishdan himoya uchun yetarli
input int               MinSecondsBetweenEntries = 10;   // Min seconds between entries
input bool              PrintEntryDecision       = true;   // Print entry decision
input bool              UseOpportunityScanner    = true;   // Use opportunity scanner
input bool              ScannerEvaluateOnNewBarOnly = false;   // Scanner evaluate on new bar only (on/off)
input int               ScannerLookbackBars      = 20;   // Scanner lookback bars
input int               SweepLookbackBars        = 10;   // Sweep lookback bars
input int               RangeEdgePercent         = 22;   // Range edge %
input int               MinOpportunityScoreC     = 3;   // Min opportunity score c
input int               MinOpportunityScoreB     = 5;   // Min opportunity score b
input int               MinOpportunityScoreA     = 7;   // Min opportunity score a
input bool              ScannerAllowMicroC       = true;   // Scanner allow micro c (on/off)
input bool              ScannerAllowRangeEdge    = true;   // Scanner allow range edge (on/off)
input bool              ScannerAllowSweep        = true;   // Scanner allow sweep (on/off)
input bool              ScannerAllowPullback     = true;   // Scanner allow pullback (on/off)
input bool              ScannerAllowExhaustion   = true;   // Scanner allow exhaustion (on/off)
// SAFE-RELAX(unknown-zone-only): when the market state is UNKNOWN, instead of trading nothing,
// allow ONLY the zone-anchored setups (sweep / fake-breakout-return / near-zone reaction). These
// lean on a real S/R level and don't need a defined trend, so they're safe in a directionless
// market. Trend/momentum/breakout detectors stay off in UNKNOWN. Set false for the old behaviour
// (scanner fully idle when UNKNOWN).
input bool              EnableUnknownZoneOnlyScan = true;   // Enable unknown zone only scan

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
input group "ADVANCED ▸ Daily bias (PDH/PDL + prior-day close)"
// EnableDailyBias: Master switch for previous-day analysis
input bool   EnableDailyBias              = true;   // Enable daily bias
// EnableDailyLevelsAsZones: Feed PDH/PDL (and prior close) into the zone system as strong levels
input bool   EnableDailyLevelsAsZones     = true;   // Enable daily levels as zones
// DailyLevelStrengthBonus: V33b: reduced 1.0 -> 0.5. At 1.0 a PDH/PDL zone reached ~2.2 strength easily (1.0 base + 1.0 daily + touches), which tripped the zone-wall HARD BLOCK (MinStrength 2.2) almost every time price neared yesterday's high/low - and on XAUUSD price is near PDH/PDL constantly. That made the bot sluggish. 0.5 still ranks these levels above ordinary zones (so sweeps/bounces prefer them) without auto-triggering the hard block.
input double DailyLevelStrengthBonus      = 0.5;   // Daily level strength bonus
// DailyLevelTolerancePoints: A zone within this many points of PDH/PDL counts as "on" that daily level
input int    DailyLevelTolerancePoints    = 150;   // Daily level tolerance points
// EnableDailyBiasScore: Apply a score bonus/penalty for agreeing/disagreeing with the daily bias
input bool   EnableDailyBiasScore         = true;   // Enable daily bias score
// DailyBiasScoreBonus: Score points ADDED when entry direction agrees with the daily bias
input int    DailyBiasScoreBonus          = 2;   // Daily bias score bonus
// DailyBiasScorePenalty: V33b: separate, SMALLER penalty when entry opposes the bias. Was reusing the full +2 bonus as a -2 penalty, which (with MinScore as low as 6) suppressed too many valid counter-bias entries and made the bot sluggish. Reward agreement, only mildly discourage disagreement.
input int    DailyBiasScorePenalty        = 1;   // Daily bias score penalty
// DailyBiasNeutralOpenPoints: Today's open within this many points of prior close = neutral gap (no open-based bias tilt)
input double DailyBiasNeutralOpenPoints   = 100;   // Daily bias neutral open points
input bool   DailyBiasPrintOnUse          = true;   // Daily bias print on use (on/off)
input bool              ScannerAllowMomentum     = true;   // Scanner allow momentum (on/off)

input bool              UseSignalScoreEngine     = true;   // Use signal score engine
input bool              UseAntiOverfilterSystem  = true;   // Use anti overfilter system
input bool              UseDynamicScoreThreshold = true;   // Use dynamic score threshold
// MinScoreMicroBalanced: V177b: reverted from 6.
input int               MinScoreMicroBalanced    = 4;   // Min score micro balanced
// MinScoreMicroHighHunter: V177b: reverted from 5.
input int               MinScoreMicroHighHunter  = 3;   // Min score micro high hunter
input int               ScoreBonusTrendAligned   = 2;   // Score bonus trend aligned
input int               ScorePenaltyTrendAgainst = 2;   // Score penalty trend against
input int               ScoreBonusRangeReaction  = 1;   // Score bonus range reaction
input int               ScoreBonusCleanSpread    = 1;   // Score bonus clean spread
input int               ScorePenaltySoftSpread   = 1;   // Score penalty soft spread
input int               ScorePenaltyNoRoomToTP   = 2;   // Score penalty no room to TP
input int               ScoreBonusRoomToTP       = 1;   // Score bonus room to TP
input int               ScorePenaltyImpulseRisk  = 1;   // Score penalty impulse risk
// ScoreHardBlockExtremeSpread: FIX(hard-spread-preempts-unified): was 300, the ONLY spread gate in the EA not routed through EffSpread(). Every other one (env 6140, queue, micro, risk) resolves to UnifiedMaxSpreadPoints = 500, so a 300 hard block fired FIRST and made the 500 setting unreachable - the softer stage was dead, exactly the mistake V90b fixed for MaxSpread/CriticalSpread. This is the ABSOLUTE stop tier, so it now matches CriticalSpreadPoints ($0.80). Set to 0 to follow CriticalSpreadPoints automatically.
input int               ScoreHardBlockExtremeSpread = 800;   // Score hard block extreme spread
input int               ScoreMinRoomPercentOfTP  = 55;   // Score min room % of TP

input group "ADVANCED ▸ Market brain settings"
input bool              UseMarketStateRouter     = true;   // Use market state router
input bool              UseTrendDetection        = true;   // Use trend detection
input bool              UseRangeDetection        = true;   // Use range detection
input bool              UseImpulseDetection      = true;   // Use impulse detection
input bool              UseExhaustionDetection   = true;   // Use exhaustion detection
input bool              UsePullbackLogic         = true;   // Use pullback logic
input ENUM_TIMEFRAMES   SignalTF                 = PERIOD_M1;   // Signal TF
input ENUM_TIMEFRAMES   FastContextTF            = PERIOD_M5;   // Fast context TF
input ENUM_TIMEFRAMES   StructureTF              = PERIOD_M15;   // Structure TF
input ENUM_TIMEFRAMES   HTFTrendTF               = PERIOD_H1;   // HTF trend TF
input int               TrendMAPeriod            = 50;   // Trend MA period
input int               TrendSlopeLookback       = 5;   // Trend slope lookback
input int               ATRPeriod                = 14;   // ATR period
input int               RangeLookbackBars        = 24;   // Range lookback bars
// RangeMaxPointsBalanced: V55b: 3500 -> 20000. CRITICAL unit fix - this broker quotes XAUUSD with 3 decimals, so 1000 points = $1, NOT 100. The old 3500 meant $3.50 (not the $35 assumed) and briefly 2000 = $2.00, tighter than the basket take-profit itself, so a range was essentially never detected and the bot sat in MARKET_UNKNOWN. 20000 = $20, the value actually intended.
input int               RangeMaxPointsBalanced   = 20000;   // Range max points balanced
// RangeMaxPointsHunter: V55b: 5000 -> 20000, same 3-digit unit fix as the Balanced value above.
input int               RangeMaxPointsHunter     = 20000;   // Range max points hunter

// FEATURE(range-breakout): detect when price ESCAPES the range (variant B). While ranging, the bot
// fades the edges (buy low / sell high). But once price breaks out of the range with conviction,
// that edge-fade is exactly the wrong trade - the user saw SELL at the top just as price broke up
// and ran. This detects a genuine breakout (a strong-bodied close beyond the boundary, not a wick
// poke), so we can (1) block the counter-breakout edge fade and (2) allow an entry WITH the break.
// RangeBreakoutConfirmTF: V56b NEW: timeframe the breakout candle is confirmed on. MUST match the timeframe the range itself is measured on (FastContextTF), otherwise a noisy single M1 candle can declare a "breakout" of an M5-derived range - which would block the very range-edge fades that range detection exists to enable.
input ENUM_TIMEFRAMES RangeBreakoutConfirmTF = PERIOD_M5;   // Range breakout confirm TF
// EnableRangeBreakout: Detect and act on price breaking out of the range
input bool   EnableRangeBreakout          = true;   // Enable range breakout
// RangeBreakoutBufferPoints: Close must clear the range edge by this many points to count as a breakout (filters noise at the edge)
input int    RangeBreakoutBufferPoints    = 120;   // Range breakout buffer points
// RangeBreakoutMinBodyFraction: The breakout candle must be at least this fraction body (not a wick) - a conviction move, not a fakeout poke
input double RangeBreakoutMinBodyFraction = 0.55;   // Range breakout min body fraction
// RangeBreakoutBlockCounterFade: Block the range edge-fade that fights a confirmed breakout (the SELL-at-top-of-upbreak case)
input bool   RangeBreakoutBlockCounterFade = true;   // Range breakout block counter fade (on/off)
// RangeBreakoutAllowWithEntry: Allow a first entry in the breakout direction (trade WITH the break)
input bool   RangeBreakoutAllowWithEntry  = true;   // Range breakout allow with entry (on/off)
// RangeBreakoutMaxAgeBars: V56b NEW: how many bars the stored range boundaries stay valid after the last confirmed range. Without this the boundaries never expire, so once a range ended the detector would keep reporting a breakout of it forever and permanently veto one direction.
input int    RangeBreakoutMaxAgeBars      = 12;   // Range breakout max age bars
input int               DeadATRThresholdPoints   = 350;   // Dead ATR threshold points
input double            ImpulseATRMultiplier     = 2.20;   // Impulse ATR multiplier
input int               ImpulseMinPoints         = 1600;   // Impulse min points
// ImpulseDirectionLookbackBars: Bars used to decide the impulse's DIRECTION from its net move (was effectively 1 - a single spike candle could flip it). 3 reads the thrust across the impulse, not the last candle's noise.
input int               ImpulseDirectionLookbackBars = 3;   // Impulse direction lookback bars

// FEATURE(sustained-impulse): the single-bar impulse test only catches a sharp one-candle burst. A
// slow, grinding, pullback-free decline (or rally) - price bleeding one direction for hours with no
// retrace - is ALSO an impulse but every individual bar is small, so it was read as a range/ordinary
// trend. Measure "directional efficiency" over a window: net move / total path travelled. A high
// ratio means price went almost straight (few pullbacks) = a real sustained impulse, however slow.
// Live example it must catch: an $56 M15 slide over ~8h with tiny bars but ~0.78 efficiency.
// EnableSustainedImpulse: Also flag a slow but pullback-free move as an impulse
input bool              EnableSustainedImpulse       = true;   // Enable sustained impulse
// SustainedImpulseTF: Timeframe the window is measured on
input ENUM_TIMEFRAMES   SustainedImpulseTF           = PERIOD_M15;   // Sustained impulse TF
// SustainedImpulseLookbackBars: Window length (16 x M15 = 4 hours)
input int               SustainedImpulseLookbackBars = 16;   // Sustained impulse lookback bars
// SustainedImpulseMinNetPoints: Minimum NET move over the window (15000 = $15); smaller moves are just noise
input int               SustainedImpulseMinNetPoints = 15000;   // Sustained impulse min net points
// SustainedImpulseMinEfficiency: Net/path ratio required (0.65 = fairly one-directional). Choppy back-and-forth sits ~0.2-0.4 and is correctly ignored.
input double            SustainedImpulseMinEfficiency = 0.65;   // Sustained impulse min efficiency

// FEATURE(sustained-impulse-exhaustion): the ATR-based ImpulseEndHardBlock only fires on huge (7x
// D1 ATR ~ $175) moves, so a normal M15/M5 sustained impulse could run to its end and the bot would
// still add entries in its direction right as it reversed - a classic deep-DD cause. Detect the END
// of a sustained impulse on ITS OWN timeframe: a rejection wick against the impulse direction on the
// latest bar PLUS the directional efficiency dropping below its threshold (the clean one-way move
// has started to stall). Both together = exhaustion; either alone is too easy to trip on noise.
// EnableSustainedExhaustion: Penalise adding in the impulse direction once a sustained impulse shows exhaustion
input bool              EnableSustainedExhaustion    = true;   // Enable sustained exhaustion
// SustainedExhaustionWickRatio: Rejection wick (against impulse dir) must be at least this fraction of the bar's range
input double            SustainedExhaustionWickRatio = 0.45;   // Sustained exhaustion wick ratio
// SustainedExhaustionPenalty: Score penalty for entering the impulse direction at its exhausted end
input int               SustainedExhaustionPenalty   = 4;   // Sustained exhaustion penalty

// FEATURE(counter-impulse-block): entering AGAINST a strong impulse while it is still running (not
// yet exhausted) is a classic loss - the screenshot showed SELLs placed into a live $60 up-thrust
// that kept going. The impulse-correction penalty only fires once a pullback has started (retrace>0);
// this covers the earlier, more dangerous case where the impulse is still pushing and there is no
// pullback yet. If a spike or sustained impulse is active and the entry opposes it, block - UNLESS
// the impulse is already showing exhaustion (then a reversal entry is reasonable, so we let it pass).
// EnableCounterImpulseBlock: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableCounterImpulseBlock     = true;   // Enable counter impulse block
// CounterImpulseHardBlock: V186: hard blok -> jazo. impulsga qarshi kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // true = hard block; false = score penalty only
input bool              CounterImpulseHardBlock       = false;   // Counter impulse hard block (on/off)
// CounterImpulseScorePenalty: Penalty when not hard-blocking
input int               CounterImpulseScorePenalty    = 5;   // Counter impulse score penalty
// CounterImpulseMaxAgeBars: V177c: 45 -> 20 bars. This is how long the block may hold before releasing regardless of exhaustion. The exhaustion test needs a 45% rejection wick, which a move that simply fades never prints - so this is the only release most blocks will ever get. Twenty M1 bars is long enough that a live impulse still gets respected, short enough that a stalled one stops costing entries.
input int               CounterImpulseMaxAgeBars      = 20;   // Counter impulse max age bars

// V180: safety valve over the whole block set. Each hard block releases on its own condition and
// each is reasonable alone, but none of them can see the others - one condition hands over to the
// next and the EA can sit out for hours without any single check being wrong. Live evidence for
// this: half an hour of silence traced to two separate blocks overlapping. Past this limit, one
// entry is allowed through; the blocks are unchanged, they simply stop compounding into a halt.
// EnableBlockSafetyValve: Allow one entry through after a prolonged run of blocked bars
input bool   EnableBlockSafetyValve      = true;   // Enable block safety valve
// BlockSafetyValveBars: Bars (core TF) of continuous blocking before the valve opens - 180 M1 bars is three hours. Long enough that genuine protection is respected, short enough that a stuck block set does not cost a session.
input int    BlockSafetyValveBars        = 180;   // Block safety valve bars
// BlockSafetyValvePrintOnUse: Log every time the valve opens, and which block was holding
input bool   BlockSafetyValvePrintOnUse  = true;   // Block safety valve print on use
// CounterImpulsePrintOnUse: Log when the impulse block engages and releases
input bool              CounterImpulsePrintOnUse      = true;   // Counter impulse print on use (on/off)

// FEATURE(correction-exhaustion): the screenshot's right-hand loss - after a DOWN move, price
// corrected UP a long way, the bot bought at the TOP of that correction, then the down-move resumed
// and left the basket in DD. The counter-impulse block (v94) doesn't catch this because the buy is
// WITH the up-correction, not against a live impulse; and the impulse-correction penalty stops firing
// once the retrace is deep. This block targets the correction's EXHAUSTION: main trend down, a
// sizeable counter-trend correction up, and that correction now stalling (rejection wick + slowing).
// Entering in the correction's direction there is fading the main trend right as it's about to
// resume - block it. Symmetric for an up main trend with a down correction.
// EnableCorrectionExhaustion: Block a counter-trend entry at the top/bottom of a tiring correction
input bool              EnableCorrectionExhaustion    = true;   // Enable correction exhaustion
// CorrectionExhaustionHardBlock: V181: hard blok -> jazo. korreksiya charchashi - v24 da bunday blok yo'q edi va bot ishlardi; hard blok o'rniga jazo yetarli. Blok savdoni butunlay to'sadi; jazo esa kuchli setupга o'z fikrini bildirish imkonini beradi - bu yuqori chastotali scalperда muhim farq.   // true = hard block; false = score penalty
input bool              CorrectionExhaustionHardBlock = false;   // Correction exhaustion hard block (on/off)
// CorrectionExhaustionMinRetrace: Correction must have retraced at least this % of the impulse to count as a "sizeable" correction worth fading
input double            CorrectionExhaustionMinRetrace = 38.0;   // Correction exhaustion min retrace
// CorrectionExhaustionWickRatio: Rejection wick against the correction must be >= this fraction of the bar range
input double            CorrectionExhaustionWickRatio = 0.40;   // Correction exhaustion wick ratio
// CorrectionExhaustionPenalty: Score penalty when not hard-blocking
input int               CorrectionExhaustionPenalty   = 5;   // Correction exhaustion penalty
// CorrectionExhaustionWindowBars: Only within this many bars of the impulse
input int               CorrectionExhaustionWindowBars = 25;   // Correction exhaustion window bars

// FEATURE(recent-extreme): the screenshot's left-hand loss - price fell into a bottom, the bot sold
// AT that bottom (in the move's own direction), then price turned up and left the SELL in long DD.
// This isn't a sustained impulse (so v90 exhaustion misses it) and it's not counter-trend (so the
// counter-impulse block misses it) - it's entering in the direction of a move that has just reached
// its extreme and is showing a rejection wick. General guard: over a recent window price made a net
// move, the current price sits near that window's extreme in the move direction, and the latest bar
// prints a rejection wick against the move. Entering WITH the move there is buying the high / selling
// the low. Block it.
// EnableRecentExtremeBlock: Block entering in a move's direction at its exhausted recent extreme
input bool              EnableRecentExtremeBlock     = true;   // Enable recent extreme block
// RecentExtremeHardBlock: V181: hard blok -> jazo. yaqin ekstremum - xuddi shu sabab. Blok savdoni butunlay to'sadi; jazo esa kuchli setupга o'z fikrini bildirish imkonini beradi - bu yuqori chastotali scalperда muhim farq.    // true = hard block; false = score penalty
input bool              RecentExtremeHardBlock       = false;   // Recent extreme hard block (on/off)
// RecentExtremeWindowBars: Window (SignalTF bars) to measure the recent move and its extreme
input int               RecentExtremeWindowBars      = 10;   // Recent extreme window bars
// RecentExtremeMinMovePoints: Net move over the window must be at least this (3-digit points; 2500 = $2.5) to be a "move" worth fading
input double            RecentExtremeMinMovePoints   = 2500.0;   // Recent extreme min move points
// RecentExtremeNearPercent: Current price must be within this % of the window range to the extreme (33% = top/bottom third). The screenshot SELL sat ~30% off the low, so a tight 25% quarter would miss it; a third fits "near the extreme" better.
input double            RecentExtremeNearPercent     = 33.0;   // Recent extreme near %
// RecentExtremeWickRatio: Rejection wick against the move on the latest bar must be >= this fraction of the bar range
input double            RecentExtremeWickRatio       = 0.40;   // Recent extreme wick ratio
// RecentExtremePenalty: Score penalty when not hard-blocking
input int               RecentExtremePenalty         = 5;   // Recent extreme penalty

// FEATURE(spike-impulse): the OTHER kind of fast move - a single bar that blows out several times
// its own ATR (an M5 candle throwing $20, or M1 suddenly flying). The sustained detector above is
// for slow grinds; this is for the violent one-candle burst. Flagging it as an impulse lets the
// downstream guards (collapse-bottom, impulse-end, exhaustion) treat the aftermath cautiously
// instead of chasing the spike. Checks both M1 and M5 so a burst on either shows up.
// EnableSpikeImpulse: Flag a single candle that is several x ATR as a sharp impulse
input bool              EnableSpikeImpulse           = true;   // Enable spike impulse
// SpikeImpulseATRMultiple: A bar counts as a spike when its range >= this many x its own ATR (4.0 = a violent, well-above-normal candle)
input double            SpikeImpulseATRMultiple      = 4.0;   // Spike impulse ATR multiple
// SpikeImpulseMinPoints: AND the bar must be at least this big in absolute terms (8000 = $8), so a spike during a dead low-ATR patch still has to be a real move
input int               SpikeImpulseMinPoints        = 8000;   // Spike impulse min points

// FEATURE(recent-thrust): live-trading gap found by the user - price arrived at a resistance WITH a
// strong impulse and the bot still sold the level, then the thrust broke through and the trade lost.
// The two existing impulse detectors both miss this shape: SpikeImpulse needs $8 in a SINGLE bar
// (far too big), and SustainedImpulse measures M15 x 16 bars = 4 HOURS (far too slow for a scalp).
// Neither sees the common case: "$3-6 of one-directional move over the last 10-20 minutes". This
// detector fills that middle band on the signal timeframe, so the counter-impulse guard and the zone
// filter below can finally see a thrust arriving into a level.
// EnableRecentThrust: Detect a recent short-horizon thrust (fills the gap between single-bar spikes and 4-hour sustained moves)
input bool              EnableRecentThrust           = true;   // Enable recent thrust
// RecentThrustTF: V267: M1 -> M5, same reason. A thrust measured over M1 bars is a thrust inside one M5 candle.
input ENUM_TIMEFRAMES   RecentThrustTF               = PERIOD_M5;   // Recent thrust TF
// RecentThrustLookbackBars: Window length in bars (15 x M1 = last 15 minutes)
input int               RecentThrustLookbackBars     = 15;   // Recent thrust lookback bars
// RecentThrustMinNetPoints: Minimum NET move over the window (3-digit: 3000 = $3.00) to count as a thrust
input int               RecentThrustMinNetPoints     = 3000;   // Recent thrust min net points

// V204: consecutive closing pressure. The distance-based thrust check asks whether price covered
// $3 in fifteen bars - which catches a fast run but misses three or four strong candles closing the
// same way over a dollar or two. The distance is unremarkable; the sequence is not, and taking the
// other side mid-push has been producing quick losses. Read as timing rather than direction: the
// entry waits for the run to break, which is a bar closing against it or a doji - a specific,
// observable end rather than an arbitrary delay.
// EnableConsecutivePressure: Read runs of same-direction closes, not just distance covered
input bool   EnableConsecutivePressure   = true;   // Enable consecutive pressure
// ConsecutivePressureTF: V267: M1 -> M5. This module produces a DIRECTION - three closes in a row one way - and on M1 three closes is three minutes, which is inside a single M5 candle. A run that short describes the inside of one bar rather than pressure in the market, and it was voting on direction with the same weight as readings drawn from real structure. Small timeframes are for timing; direction has to come from a scale where a run of bars means something.
input ENUM_TIMEFRAMES ConsecutivePressureTF = PERIOD_M5;   // Consecutive pressure TF
// ConsecutivePressureLookback: How far back to follow the run
input int    ConsecutivePressureLookback = 6;   // Consecutive pressure lookback
// ConsecutivePressureMinRun: Candles closing the same way before it counts as a push
input int    ConsecutivePressureMinRun   = 3;   // Consecutive pressure min run
// ConsecutivePressureMinBody: Body as a share of the bar's range - below this the candle was attempted rather than achieved, and the run ends
input double ConsecutivePressureMinBody  = 0.55;   // Consecutive pressure min body
// ConsecutivePressureMinPoints: Ground the run must have covered ($0.90) - consistent small bodies in a tight range are not force
input int    ConsecutivePressureMinPoints = 900;   // Consecutive pressure min points
// ConsecutivePressureArms: Hold the entry until the run breaks, rather than only penalising it
input bool   ConsecutivePressureArms     = true;   // Consecutive pressure arms (on/off)
// ConsecutivePressurePenalty: Penalty per candle beyond the minimum run, when not arming
input int    ConsecutivePressurePenalty  = 3;   // Consecutive pressure penalty
// ConsecutivePressureMaxPenalty: Ceiling on that penalty
input int    ConsecutivePressureMaxPenalty = 9;   // Consecutive pressure max penalty
// ConsecutivePressurePrintOnUse: Log entries taken against a live run
input bool   ConsecutivePressurePrintOnUse = true;   // Consecutive pressure print on use (on/off)

// V229: the single strong candle. Eight modules guard against entering into an impulse and none
// fires on one bar - consecutive pressure needs three candles, recent thrust needs $3 over fifteen
// bars, spike detection needs $8. Every threshold assumes a SEQUENCE, because that is what an
// impulse usually looks like. But the expensive case is one bar: a strong close, a counter-setup
// immediately after, and the EA taking the other side while whoever produced that bar is still
// there. Measured against the recent average rather than a fixed distance, since what counts as a
// large bar at 03:00 and at 14:30 are different numbers.
// EnableSingleCandleGuard: Respect a single dominant candle, not only sequences
input bool   EnableSingleCandleGuard     = true;   // Enable single candle guard
// SingleCandleTF: V267: M1 -> M5. This compares a bar to its recent neighbours, which works on either scale - but the conclusion it feeds is directional, and an M1 bar three times the size of its neighbours is routinely just the open of an M5 candle. On M5 a dominant bar is an event.
input ENUM_TIMEFRAMES SingleCandleTF     = PERIOD_M5;   // Single candle TF
// SingleCandleLookback: Bars defining what a normal candle is here
input int    SingleCandleLookback        = 12;   // Single candle lookback
// SingleCandleMinRatio: Size against that average before the bar counts as dominant
input double SingleCandleMinRatio        = 2.2;   // Single candle min ratio
// SingleCandleFullRatio: V229b: 4.0 -> 3.2. Tested against the case this was built for - a $1.20 bar against a $0.45 average is 2.7x, which is plainly a dominant candle, and at a 4.0 full-weight point it scored 0.22 and fell under the acting threshold. Bars four times normal are rare enough that anchoring to them made everything below invisible.
input double SingleCandleFullRatio       = 3.2;   // Single candle full ratio
// SingleCandleMinBody: Body share - a wide bar that closed mid-range is a fight, not a push
input double SingleCandleMinBody         = 0.55;   // Single candle min body
// SingleCandleMinBodyPoints: Absolute floor ($0.50) - three times the size of four tiny bars is still a tiny bar
input int    SingleCandleMinBodyPoints   = 500;   // Single candle min body points
// SingleCandleMinStrength: V229b: 0.30 -> 0.20, so a 2.7x bar registers rather than falling just short.
input double SingleCandleMinStrength     = 0.20;   // Single candle min strength
// SingleCandleArms: Wait for the push to stop rather than penalising the entry. The objection ends when the next bar fails to continue - observable, not a fixed delay.
input bool   SingleCandleArms            = true;   // Single candle arms (on/off)
// SingleCandlePenalty: Cost of entering against a dominant bar when not arming
input int    SingleCandlePenalty         = 5;   // Single candle penalty
// SingleCandleBonus: Credit for entering with one. Deliberately smaller: joining a push is easier to get wrong than avoiding one.
input int    SingleCandleBonus           = 2;   // Single candle bonus
// SingleCandlePrintOnUse: Log dominant candles
input bool   SingleCandlePrintOnUse      = true;   // Single candle print on use (on/off)

// V238: two live losses, one blind spot behind each.
// A BUY AT 4435 into a band that had capped price on four separate days. The counter-zone check
// measures distance to the nearest LEVEL, which is right when price is outside a band and wrong when
// it is between the edges - the nearest edge is then a dollar away and the check reads open road
// while price sits in the middle of the thing that has been stopping it all week.
// EnableBandEntryGuard: Notice when the entry is inside a band rather than approaching a level
input bool   EnableBandEntryGuard        = true;   // Enable band entry guard
// BandGuardMinStrength: Band strength worth respecting
input double BandGuardMinStrength        = 1.5;   // Band guard min strength
// BandGuardFullStrength: Strength at which the guard is at full weight
input double BandGuardFullStrength       = 2.8;   // Band guard full strength
// BandGuardInsideBase: V243: weight carried by being inside a held band at all, before position is considered. The original version scored position only and let the middle through - a sell at 4485.10 inside a 4484.20-4486.00 band scored 0.50 against a 0.55 threshold and passed. A trade anywhere inside a shelf that has held three times has no room in front of it.
input double BandGuardInsideBase         = 0.45;   // Band guard inside base
// BandGuardMinRoomPoints: V243: room ($0.80) to the band's far edge below which the trade cannot work even if the direction is right
input int    BandGuardMinRoomPoints      = 800;   // Band guard min room points
// BandGuardNoRoomFactor: V243: multiplier when there is no room - this is the case that produced the loss
input double BandGuardNoRoomFactor       = 1.40;   // Band guard no room factor

// V245: does the target land inside a band? RoomToTargetPoints asks whether a wall sits beyond the
// target and reads a single price, so against a band it returns whichever edge happened to be
// cached. From a live entry: a buy at 4491.35 targeting 4493.85 with a band running 4492.00-4494.15
// that had turned price away three times. It saw the far edge, measured $2.80 of room, and reported
// plenty for a $2.50 target. The real figure was $0.65 - the distance to where the band STARTS.
// EnableTargetBandCheck: Check whether the target falls inside a band rather than short of a level
input bool   EnableTargetBandCheck       = true;   // Enable target band check
// TargetBandMinStrength: Band strength worth measuring against
input double TargetBandMinStrength       = 1.5;   // Target band min strength
// TargetBandMinSeverity: Share of the intended move that must fall inside the band before it counts
input double TargetBandMinSeverity       = 0.30;   // Target band min severity
// TargetBandPenalty: Cost of aiming into a band. High: the target is not merely optimistic, it is inside the thing that stops price.
input int    TargetBandPenalty           = 6;   // Target band penalty
// TargetBandPrintOnUse: Log targets landing inside bands
input bool   TargetBandPrintOnUse        = true;   // Target band print on use (on/off)

// V246: the level that was broken and took itself back. ZoneMapIsPolarityFlip looks for one
// crossing - price on one side, then the other - which describes a level changing role and is the
// wrong shape for what usually happens at a strong one. From the live chart: a band at 4492-4494
// that price broke through twice and came straight back under both times. To the flip test that
// reads as a level whose role keeps changing, ambiguous and unreliable. In practice it is the
// opposite - a level that has defeated two attempts is stronger than one never tested, because the
// attempts are the evidence and whoever took them is trapped on the wrong side.
// EnableFailedBreakRead: Count breaks that were reclaimed, and treat them as strength
input bool   EnableFailedBreakRead       = true;   // Enable failed break read
// FailedBreakTF: Timeframe attempts are read on
input ENUM_TIMEFRAMES FailedBreakTF      = PERIOD_M5;   // Failed break TF
// FailedBreakLookback: Bars searched for attempts
input int    FailedBreakLookback         = 80;   // Failed break lookback
// FailedBreakTolerance: How far ($0.30) past the level a close must be to count as an attempt rather than noise
input int    FailedBreakTolerance        = 300;   // Failed break tolerance
// FailedBreakReclaimBars: Bars within which price must come back for the break to count as failed. Longer than this and the level genuinely gave way for a while.
input int    FailedBreakReclaimBars      = 4;   // Failed break reclaim bars
// FailedBreakBoostPer: Strength added per defeated attempt
input double FailedBreakBoostPer         = 0.20;   // Failed break boost per
// FailedBreakMaxBoost: Ceiling - two is confirmation, six means price is grinding against it and it will probably go
input double FailedBreakMaxBoost         = 0.50;   // Failed break max boost
// FailedBreakFreshBars: Bars within which a defence still counts fully - the traders caught by it are still positioned
input int    FailedBreakFreshBars        = 30;   // Failed break fresh bars
// RetestMinFailedBreaks: Failed breaks that qualify a level for the retest setup without a polarity flip
input int    RetestMinFailedBreaks       = 2;   // Retest min failed breaks

// V247: the price at which the basket is simply wrong. The EA has three ways to close a losing
// basket - the stop at 50%, an emergency drawdown trigger, an equity stop - and all three answer the
// same question: has the money run out. None answers the one a trader asks first: is the reason I
// took this trade still true? From a live loss: two sells at 4470 and 4484 while price climbed to
// 4523, the second placed ABOVE the first, into the rise, and then the basket sat accumulating
// drawdown toward a percentage. Somewhere in that climb the case for being short stopped existing,
// and nothing was watching - because nothing had recorded what the case was.
// EnableBasketThesis: Record what the basket is betting on and the price that would disprove it
input bool   EnableBasketThesis          = true;   // Enable basket thesis
// ThesisMinDistance: Closest ($0.70) an invalidation can sit - nearer than this and it fires on noise
input int    ThesisMinDistance           = 700;   // Thesis min distance
// ThesisMaxDistance: Furthest ($4.00) - beyond this it is not an invalidation, it is a stop-loss
input int    ThesisMaxDistance           = 4000;   // Thesis max distance
// ThesisTolerance: Slack ($0.20) before a close counts as through it
input int    ThesisTolerance             = 200;   // Thesis tolerance
// ThesisPrintOnUse: Log the thesis and its failure
input bool   ThesisPrintOnUse            = true;   // Thesis print on use (on/off)

// V290: when the premise is dead, stop asking for the full target. V247 detects that the reason for
// the basket has gone and answers by stopping the grid - which keeps the position from growing and
// does nothing about the position itself, left waiting for a target that assumed the original read
// was right. A basket whose premise is gone is not a trade any more; it is a position to be managed
// out of, and the first retrace toward break-even is the exit.
// EnableDeadPremiseExit: Cut the target to break-even once the basket's reason has gone
input bool   EnableDeadPremiseExit       = true;   // Enable dead premise exit
// RequireDrawdownForBE: S-BASKET: wait until the basket is actually deep before cutting to break-even. A premise dying says the reason has gone, not that the trade is lost - a basket three dollars down with its target still close can still reach it, and cutting there gives away every recovery the position had.
input bool   RequireDrawdownForBE        = true;   // Require drawdown for BE
// DeadPremiseBEFromDD: S-BASKET: drawdown percent at which a dead premise turns into a break-even exit. Set against a basket stop of fifty, this is the point where the question stops being profit and becomes getting out whole.
input double DeadPremiseBEFromDD         = 12.0;   // Dead premise BE from DD
// DeadPremiseExitPoints: Floor for that target ($0.40) - enough to clear the spread and the tick of slippage that decides whether a break-even close breaks even
input int    DeadPremiseExitPoints       = 400;   // Dead premise exit points
// DeadPremiseExitPrintOnUse: Log premise exits
input bool   DeadPremiseExitPrintOnUse   = true;   // Dead premise exit print on use (on/off)

// V248: three things checked too late, or not at all.
// AFFORDABILITY: GridEffectiveMaxOrders works out whether the account can pay for the remaining
// rungs, and it runs from inside GridCanOpen - so it first executes at rung two, when the basket
// already exists. If the full ladder was never affordable the EA finds out halfway up, and stops in
// the worst place: too deep to close cheaply, too shallow to recover.
// EnableEntryAffordability: Check the whole ladder is affordable before opening anything
input bool   EnableEntryAffordability    = true;   // Enable entry affordability
// EntryAffordabilityShare: V279: 0.85 -> 1.00. Live case: an $822 account with a $411 stop budget, and a five-rung ladder projecting $393 - inside what the stop is sized to absorb, and refused because of an extra fifteen percent margin this check was adding on top. The stop already bounds the loss; this check exists to catch a ladder the account cannot pay for at all, which is a different question from one that fits with less room to spare. At 1.00 it still refuses anything projecting beyond the stop, and stops duplicating a limit that already exists.   // Share of the stop budget the projected ladder may reach. Below 1.0 so it finishes before the stop rather than at it.
input double EntryAffordabilityShare     = 1.00;   // Entry affordability share
// EntryAffordabilityMaxMargin: V279b: 45 -> 70. On an $822 account a five-rung ladder needs roughly $430 of margin, which is 52 percent of equity - refused at 45, and not remotely dangerous: that leaves a margin level near 190 percent against a stop-out around 50. The number this check should protect is the margin LEVEL, and 70 percent of equity still leaves it above 140. Forty-five was refusing ladders the account could carry comfortably.   // Percent of equity the full ladder may need as margin. Running out of margin mid-ladder is worse than running out of budget, because the broker decides what closes.
input double EntryAffordabilityMaxMargin = 70.0;   // Entry affordability max margin
// EnableAffordableLadderTrim: V282: when the full ladder costs more than the stop allows, cap the basket at the depth that fits instead of refusing the entry. The check exists to stop the EA discovering at rung four that it cannot pay for rung five - it does that, and then throws away a setup every other layer approved because of an arithmetic problem with the last two rungs. The first rung was always affordable; the tail was not.
input bool   EnableAffordableLadderTrim  = true;   // Enable affordable ladder trim
// MinAffordableRungs: V284: 2 -> 1. On a small account two rungs can exceed the stop budget while one is plainly affordable, and refusing the entry over that leaves the EA unable to trade at all. A single-rung basket has no recovery ladder, which is a real limitation and a better one than no trade.      // V282: fewest rungs worth trading. Below this the basket has no recovery room at all and the entry is refused as before.
input int    MinAffordableRungs          = 1;   // Min affordable rungs
// EnableBalanceSizedLot: V285: derive the base lot from the balance so the full ladder fits, instead of refusing entries when a fixed StartLot does not. Sizes down only - a large account still trades the size it was configured for.
input bool   EnableBalanceSizedLot       = true;   // Enable balance sized lot
// BalanceSizedLotPrintOnUse: V285: log when the lot is sized down
input bool   BalanceSizedLotPrintOnUse   = true;   // Balance sized lot print on use (on/off)
// EntryAffordabilityPrintOnUse: Log refused entries
input bool   EntryAffordabilityPrintOnUse = true;   // Entry affordability print on use (on/off)
// A DEAD MARKET is specifically dangerous for a ladder - the range is too tight for the target, so
// the rungs fill quickly and the move that eventually comes finds a full basket waiting.
// EnableDeadMarketCheck: Notice when there is nothing happening
input bool   EnableDeadMarketCheck       = true;   // Enable dead market check
// DeadMarketLookback: Bars measured
input int    DeadMarketLookback          = 20;   // Dead market lookback
// DeadMarketExpectedATRPerBar: Ground a normal bar covers, as a share of ATR - the window is expected to cover this times its length
input double DeadMarketExpectedATRPerBar = 0.35;   // Dead market expected ATR per bar
// DeadMarketRatio: Share of that expectation below which the market counts as dead
input double DeadMarketRatio             = 0.60;   // Dead market ratio
// DeadMarketMinSeverity: Below this it is quiet rather than dead
input double DeadMarketMinSeverity       = 0.30;   // Dead market min severity
// DeadMarketPenalty: Cost of opening a ladder into a market with no range
input int    DeadMarketPenalty           = 4;   // Dead market penalty
// NEWS READ FROM THE MARKET rather than the calendar. The EA knows when releases are scheduled; it
// does not notice one HAPPENING - volume several times normal, spread widening, range expanding -
// which is what matters and which arrives whether or not the event was listed anywhere.
// EnableLiveNewsRead: Detect a release from the market's own behaviour
input bool   EnableLiveNewsRead          = true;   // Enable live news read
// EnableNewsOwner: S-FIX: one owner for the news question. Three systems answered it - the calendar, the live price read, and an older pack - and when they disagreed the outcome depended on which one a call site happened to ask. The log caught it at NFP: news at 17:29, no news at 17:30. A scheduled release is a fact; price moving like one is an opinion about a fact, so the calendar leads and the live read speaks only where the calendar is silent.
input bool   EnableNewsOwner             = true;   // Enable news owner
// NewsLiveReadBlocksEntry: S-FIX: whether an inferred release (nothing scheduled, price behaving like it) stops an entry. Grid additions are stopped either way - adding during a release is how a recoverable basket becomes one that is not.
input bool   NewsLiveReadBlocksEntry     = true;   // News live read blocks entry (on/off)
// LiveNewsVolumeMultiple: Volume against normal that signals participants arriving at once
input double LiveNewsVolumeMultiple      = 2.5;   // Live news volume multiple
// LiveNewsVolumeWeight: Weight of that
input double LiveNewsVolumeWeight        = 0.40;   // Live news volume weight
// LiveNewsSpreadMultiple: Spread against its usual level - the broker's own reading of the same thing
input double LiveNewsSpreadMultiple      = 2.0;   // Live news spread multiple
// LiveNewsSpreadWeight: Weight of that
input double LiveNewsSpreadWeight        = 0.35;   // Live news spread weight
// LiveNewsRangeMultiple: Bar range in ATR that marks an expansion
input double LiveNewsRangeMultiple       = 2.5;   // Live news range multiple
// LiveNewsRangeWeight: Weight of that
input double LiveNewsRangeWeight         = 0.30;   // Live news range weight
// LiveNewsMinSeverity: Below this it is ordinary volatility
input double LiveNewsMinSeverity         = 0.35;   // Live news min severity
// LiveNewsPenalty: Cost of opening into a release
input int    LiveNewsPenalty             = 5;   // Live news penalty
// LiveNewsGridBlock: Severity at which the grid stops adding - a rung placed into a release fills at the worst price of it
input double LiveNewsGridBlock           = 0.55;   // Live news grid block
// LiveNewsPrintOnUse: Log detected releases
input bool   LiveNewsPrintOnUse          = true;   // Live news print on use (on/off)

// V249: two readings a total cannot express, both about the same weakness - a sum hides the shape
// of what produced it.
// CONSENSUS: a score of 13 built from eleven modules each adding a point or two is broad agreement;
// a 13 built by two modules shouting while the rest say nothing is a narrow opinion that happened to
// be loud. They arrive as the same number.
// EnableScoreConsensus: Measure how many modules actually contributed
input bool   EnableScoreConsensus        = true;   // Enable score consensus
// ConsensusFullContributors: Contributions at which support counts as broad
input int    ConsensusFullContributors   = 8;   // Consensus full contributors
// ConsensusThinBelow: Breadth below which the reading is narrow
input double ConsensusThinBelow          = 0.40;   // Consensus thin below
// ConsensusThinPenalty: Cost of narrow support. Modest - thin agreement is less certain, not wrong.
input int    ConsensusThinPenalty        = 3;   // Consensus thin penalty
// EnableConsensusHeadroom: V263: let broad agreement raise the bonus ceiling. The cap exists to stop two loud modules dominating and it does that - but it applies the same limit when eleven modules each add a point or two, which is the opposite case. V249 already counts how many spoke and uses it only to penalise thin support; this uses the other half of the same reading.
input bool   EnableConsensusHeadroom     = true;   // Enable consensus headroom
// ConsensusHeadroomFrom: V263: breadth above which the ceiling starts to lift
input double ConsensusHeadroomFrom       = 0.60;   // Consensus headroom from
// ConsensusHeadroomExtra: V263: how much headroom full agreement earns. The penalty side is untouched - this widens what a strong setup can say, not what a weak one gets away with.
input int    ConsensusHeadroomExtra      = 5;   // Consensus headroom extra
// EnableObjectionHeadroom: V287: let broad objection raise the penalty ceiling, as V263 lets broad agreement raise the bonus one. Leaving one side fixed made the scoring one-directional: bonus reaching twenty-six against a penalty frozen at ten meant six modules could object and never stop the trade.
input bool   EnableObjectionHeadroom     = true;   // Enable objection headroom
// ObjectionHeadroomSpan: V287: how far past the ceiling raw objection must run for the lift to be complete. At 2.5 a raw penalty of twenty-five against a ceiling of ten earns the full extra.
input double ObjectionHeadroomSpan       = 2.5;   // Objection headroom span
// ObjectionHeadroomExtra: V287b: 8 -> 14. With a base of seven and a typical bonus of seventeen, a setup needs twenty or more against it before it stops - and eight of headroom capped the objection at eighteen, so nothing ever did. Fourteen makes a heavily-objected setup stoppable while leaving an ordinary one untouched: the lift only reaches its maximum when raw objection runs two and a half times past the base ceiling, which is the shape of a setup with most of the EA against it.      // V287: how much a setup with everything against it can be charged beyond the base ceiling. Set against a bonus headroom of five plus a base of twenty-six, this keeps a heavily-objected setup stoppable without returning to the state where nothing traded.
input int    ObjectionHeadroomExtra      = 14;   // Objection headroom extra
// CONTRADICTION: V215 reads disagreement among the candle modules. Nothing does that one level up,
// where structure, situation, timeframes and candles can point opposite ways. Structure +6 up,
// situation -8 down, total -2, and the EA takes a weak short - but -2 out of fourteen points of
// conflicting evidence does not mean "slightly bearish", it means the layers are reaching opposite
// conclusions from the same chart.
// EnableLayerConflict: Read disagreement between the analysis layers
input bool   EnableLayerConflict         = true;   // Enable layer conflict
// ConflictMinLayers: Layers that must have an opinion before a split means anything
input int    ConflictMinLayers           = 3;   // Conflict min layers
// ConflictMinSplit: How evenly divided they must be - three against three is no signal, one dissenter among four is ordinary
input double ConflictMinSplit            = 0.50;   // Conflict min split
// ConflictMinSeverity: Below this the disagreement is normal variation
input double ConflictMinSeverity         = 0.50;   // Conflict min severity
// ConflictPenalty: Cost of acting while the layers contradict each other
input int    ConflictPenalty             = 5;   // Conflict penalty
// ConflictPrintOnUse: Log layer conflicts
input bool   ConflictPrintOnUse          = true;   // Conflict print on use (on/off)

// V250: the bigger picture overrules the local one. Three live buys made the same mistake -
// 4670.41, 4672.48, 4670.48 - each time a double top had formed above, price broke down through it,
// then came back to retest the neckline, and the EA saw a support and bought it. A support inside a
// completed bearish reversal is not a support; it is the neckline of the pattern that just broke.
// The EA lacks hierarchy: structure, situation, timeframes and zones all contribute points to one
// total, so an M5 support and an H1 reversal simply add up. They should not - the larger picture
// decides what the smaller one means.
// EnableReversalContext: Read completed reversal patterns on the higher timeframes
input bool   EnableReversalContext       = true;   // Enable reversal context
// ReversalContextTF: Timeframe the pattern is read on
input ENUM_TIMEFRAMES ReversalContextTF  = PERIOD_M15;   // Reversal context TF
// ReversalContextLookback: Bars searched for the shape
input int    ReversalContextLookback     = 80;   // Reversal context lookback
// ReversalPeakTolerance: How close in ATR the two peaks must be to count as one pattern rather than two unrelated highs
input double ReversalPeakTolerance       = 0.60;   // Reversal peak tolerance
// ReversalMinHeightATR: Pattern height before it means anything - without this any two highs with a dip between them qualify
input double ReversalMinHeightATR        = 2.0;   // Reversal min height ATR
// ReversalFullHeightATR: Height at which it carries full weight
input double ReversalFullHeightATR       = 5.0;   // Reversal full height ATR
// NecklineRetestReach: How close ($1.20) to the broken neckline counts as retesting it
input int    NecklineRetestReach         = 1200;   // Neckline retest reach
// ReversalContextBaseWeight: Weight of being inside a hostile context at all, before proximity to the neckline
input double ReversalContextBaseWeight   = 0.45;   // Reversal context base weight
// ReversalMinSeverity: Below this the context is too weak to matter
input double ReversalMinSeverity         = 0.30;   // Reversal min severity
// ReversalContextPenalty: Cost of trading against a completed reversal. The heaviest single penalty here, because this specific mistake has now cost three baskets.
input int    ReversalContextPenalty      = 7;   // Reversal context penalty
// ReversalContextPrintOnUse: Log the context and retests
input bool   ReversalContextPrintOnUse   = true;   // Reversal context print on use (on/off)

// V252: the levels that do not come from swings. A support at 4305-4315 held on the 2nd and 3rd of
// September; on the 11th price returned to it and the EA did not see it - nine days is a long time
// in a swing cache and hundreds of newer swings had pushed it out. But round numbers, the monthly
// range and the weekly open do not need remembering: they are prices rather than history, and they
// matter most exactly when the cache is least useful - after a large move into territory with no
// recent swings in it at all.
// EnableGlobalLevels: Read levels that can be calculated rather than remembered
input bool   EnableGlobalLevels          = true;   // Enable global levels
// GlobalRoundMajor: Hundreds - the strongest round level
input double GlobalRoundMajor            = 100.0;   // Global round major
input double GlobalRoundMajorStrength    = 2.2;   // Global round major strength
// GlobalRoundMid: Fifties
input double GlobalRoundMid              = 50.0;   // Global round mid
input double GlobalRoundMidStrength      = 1.7;   // Global round mid strength
// GlobalRoundMinor: Quarters
input double GlobalRoundMinor            = 25.0;   // Global round minor
input double GlobalRoundMinorStrength    = 1.3;   // Global round minor strength
// GlobalMonthStrength: The monthly high and low - a month of trading decided those
input double GlobalMonthStrength         = 2.5;   // Global month strength
// GlobalWeekStrength: The weekly range
input double GlobalWeekStrength          = 1.9;   // Global week strength
// GlobalWeekOpenStrength: Where the week opened - the reference everyone measures the week against
input double GlobalWeekOpenStrength      = 1.6;   // Global week open strength
// GlobalLevelReach: How far ahead ($4.00) to look for one
input int    GlobalLevelReach            = 4000;   // Global level reach
// GlobalLevelMinStrength: Below this it is not worth the penalty
input double GlobalLevelMinStrength      = 1.5;   // Global level min strength
// GlobalLevelPenalty: Cost of a global level sitting between the entry and its target
input int    GlobalLevelPenalty          = 5;   // Global level penalty
// GlobalLevelPrintOnUse: Log global levels in the way
input bool   GlobalLevelPrintOnUse       = true;   // Global level print on use (on/off)

// V253: the candle that took both sides. A bar with long wicks above and below a small body reads as
// a doji - indecision, no information, ignore it. That is the wrong reading in the most expensive
// way. Price went up far enough to take out everyone short, came back down far enough to take out
// everyone long, and closed near where it started. Nobody is undecided; both sides have been cleared
// and whoever did the clearing has the market to themselves, which is why the move after one of
// these tends to be the real one.
// EnableManipulationRead: Read both-sided sweeps rather than calling them dojis
input bool   EnableManipulationRead      = true;   // Enable manipulation read
// ManipulationTF: V256: M5 -> M1. Stop-clearing is a one-to-two-minute event and M1 is where it is visible as a single bar. M5 still works and is accepted; anything above M15 is refused outright inside the function, because there the same shape is several hours of ordinary trade compressed into one candle rather than a sweep.   // Timeframe the bar is read on
input ENUM_TIMEFRAMES ManipulationTF     = PERIOD_M1;   // Manipulation TF
// ManipulationLookback: V256: 5 -> 6. On M1 that is six minutes, which is about how long a stop-clearing keeps mattering before the book refills. The effect of a sweep is short-lived; a window measured in hours describes something else.      // Bars back a sweep still counts - the traders it cleared are being replaced
input int    ManipulationLookback        = 6;   // Manipulation lookback
// ManipulationMaxBody: Body share below which price finished roughly where it started
input double ManipulationMaxBody         = 0.35;   // Manipulation max body
// ManipulationMinWick: Each wick's share. BOTH must clear it - one long wick is a rejection, two is a sweep of both sides.
input double ManipulationMinWick         = 0.25;   // Manipulation min wick
// ManipulationFullWickTotal: Combined wick share at which the reading is at full weight
input double ManipulationFullWickTotal   = 0.80;   // Manipulation full wick total
// ManipulationMinRangeATR: Bar size in ATR. A small doji in a quiet hour is genuine indecision; one spanning two ATR is a range traded through in both directions inside a single bar, and that takes size to produce.
input double ManipulationMinRangeATR     = 1.4;   // Manipulation min range ATR
// ManipulationFullRangeATR: Size at which it carries full weight
input double ManipulationFullRangeATR    = 2.5;   // Manipulation full range ATR
// ManipulationBiasMargin: How far off centre the close must be before it suggests a direction
input double ManipulationBiasMargin      = 0.12;   // Manipulation bias margin
// ManipulationMinConviction: Below this the bar is an ordinary doji
input double ManipulationMinConviction   = 0.30;   // Manipulation min conviction
// ManipulationScore: Weight of trading with or against the side the sweep favoured
input int    ManipulationScore           = 5;   // Manipulation score
// ManipulationUnclearPenalty: Cost of entering while both sides are cleared and the close gave nothing away
input int    ManipulationUnclearPenalty  = 4;   // Manipulation unclear penalty
// ManipulationPrintOnUse: Log sweep bars
input bool   ManipulationPrintOnUse      = true;   // Manipulation print on use (on/off)

// V257: the wick that went and fetched something. CandleWickAuthorship already reads wicks and asks
// which side of the bar was rejected, measured against its own body - a reading about the candle.
// This is a reading about the CHART: a wick whose tip reaches a prior swing extreme and comes
// straight back has collected the stops sitting just beyond it, which is the only reason price goes
// there and does not stay. Authorship cannot tell the two apart because it never looks at where the
// wick ended, only at how big it was.
// EnableLiquidityWick: Read wicks that reach a prior extreme and return
input bool   EnableLiquidityWick         = true;   // Enable liquidity wick
// LiquidityWickTF: M1, M5 or M15 only - above that a long wick is hours of two-way trade and reaching a prior extreme is unremarkable
input ENUM_TIMEFRAMES LiquidityWickTF    = PERIOD_M5;   // Liquidity wick TF
// LiquidityWickLookback: Bars searched for the sweep
input int    LiquidityWickLookback       = 8;   // Liquidity wick lookback
// LiquidityWickSearchExtra: Extra bars searched behind it for the extreme the wick reached
input int    LiquidityWickSearchExtra    = 20;   // Liquidity wick search extra
// LiquidityWickMinRatio: Wick share of its bar before it counts as deliberate rather than noise
input double LiquidityWickMinRatio       = 0.45;   // Liquidity wick min ratio
// LiquidityWickMinRangeATR: Bar size in ATR - a long wick on a tiny bar reached nothing worth reaching
input double LiquidityWickMinRangeATR    = 0.80;   // Liquidity wick min range ATR
// LiquidityWickFullRangeATR: Size at which the reading is at full weight
input double LiquidityWickFullRangeATR   = 2.00;   // Liquidity wick full range ATR
// LiquidityWickTolerance: How close ($0.25) the tip must come to the prior extreme
input int    LiquidityWickTolerance      = 250;   // Liquidity wick tolerance
// LiquidityWickMinConviction: Below this the wick is ordinary
input double LiquidityWickMinConviction  = 0.30;   // Liquidity wick min conviction
// LiquidityWickScore: Weight of trading with or against the side that was collected
input int    LiquidityWickScore          = 5;   // Liquidity wick score
// LiquidityWickPrintOnUse: Log liquidity sweeps
input bool   LiquidityWickPrintOnUse     = true;   // Liquidity wick print on use (on/off)

// V258: sizes that are going somewhere. CandleSequenceRead compares the newest bar to the average of
// the last five - a snapshot, which cannot tell one small candle after four large ones (a pause)
// from four candles each smaller than the one before it (a move running out of people willing to
// pay). Both read as "contracting" to a mean, because a mean does not know what order things
// arrived in. This measures the progression instead: whether each body is smaller than its
// predecessor, or larger, and how consistently.
// EnableCandleProgression: Read the order the candle sizes arrived in
input bool   EnableCandleProgression     = true;   // Enable candle progression
// CandleProgressionTF: M1, M5 or M15 only - on H1 four shrinking bars span most of a session and describe the session
input ENUM_TIMEFRAMES CandleProgressionTF = PERIOD_M5;   // Candle progression TF
// CandleProgressionBars: Bars examined (3 to 6)
input int    CandleProgressionBars       = 5;   // Candle progression bars
// CandleProgressionStepDown: Ratio below which a body counts as smaller than the one before it
input double CandleProgressionStepDown   = 0.80;   // Candle progression step down
// CandleProgressionStepUp: And above which it counts as larger
input double CandleProgressionStepUp     = 1.25;   // Candle progression step up
// CandleProgressionMinSteps: Consecutive steps before the progression means anything. A run broken in the middle is not a progression - that is the point of measuring order.
input int    CandleProgressionMinSteps   = 2;   // Candle progression min steps
// CandleProgressionFullSteps: Steps at which it carries full weight
input int    CandleProgressionFullSteps  = 4;   // Candle progression full steps
// CandleProgressionMixedFactor: Weight when the bodies point different ways - the sizes are changing but the market has not settled on a direction to change them in
input double CandleProgressionMixedFactor = 0.55;   // Candle progression mixed factor
// CandleProgressionMinConviction: Below this the sequence is unremarkable
input double CandleProgressionMinConviction = 0.35;   // Candle progression min conviction
// CandleProgressionScore: V288b: 4 -> 2. This reading is about WHEN, not whether - and V288 now answers it by holding the setup for a retrace rather than charging it points. Leaving the full penalty in place would charge twice for the same observation: once by waiting, once by subtracting.      // Weight of joining or fading a progression
input int    CandleProgressionScore      = 2;   // Candle progression score
// CandleProgressionPrintOnUse: Log progressions
input bool   CandleProgressionPrintOnUse = true;   // Candle progression print on use (on/off)

// V260: how price arrived. CandleLocationWeight asks where a wick's tip landed and CandleRelevance
// asks how close a level is - both are about POSITION, which is half of context. The other half is
// arrival: a rejection at support after a fast one-way drop is exhaustion testing the level and
// those hold; the same candle after forty minutes of grinding into it is absorption wearing the
// level down and those break. The shape is identical, what produced it is not, and nothing here
// looked at the bars before the one being read.
// EnableArrivalRead: Read how price got to where it is, not just where it is
input bool   EnableArrivalRead           = true;   // Enable arrival read
// ArrivalTF: M1, M5 or M15 only
input ENUM_TIMEFRAMES ArrivalTF          = PERIOD_M5;   // Arrival TF
// ArrivalBars: Bars defining the approach - long enough to hold a real move, short enough to still be about this one
input int    ArrivalBars                 = 12;   // Arrival bars
// ArrivalMinNetATR: Net distance in ATR before the move counts as an approach at all. Efficient drift over ten points is not an arrival.
input double ArrivalMinNetATR            = 1.2;   // Arrival min net ATR
// ArrivalGrindBelow: Efficiency (net distance over ground walked) below which the approach is a grind
input double ArrivalGrindBelow           = 0.30;   // Arrival grind below
// ArrivalFastAbove: And above which it is a straight run
input double ArrivalFastAbove            = 0.70;   // Arrival fast above
// ArrivalLevelReach: How close ($1.50) the level must be. In open space how price arrived says nothing, because there is nothing there for it to matter at.
input int    ArrivalLevelReach           = 1500;   // Arrival level reach
// ArrivalMinLevelStrength: Level strength worth reading the approach against
input double ArrivalMinLevelStrength     = 1.5;   // Arrival min level strength
// ArrivalScore: Weight either way
input int    ArrivalScore                = 4;   // Arrival score
// ArrivalPrintOnUse: Log arrivals
input bool   ArrivalPrintOnUse           = true;   // Arrival print on use (on/off)

// V261: the hour numbers are wrong for half the year. Every session boundary here is a fixed broker
// hour and all of them assume the relationship between broker time and market time never changes.
// It changes twice a year: London moves to UTC+1 in late March, New York to UTC-4 in early March,
// and the broker's clock stays where it is - so from spring to autumn every boundary is an hour late
// and the killzone covers the wrong sixty minutes. The two regions also switch on different dates,
// and for the fortnight between them the sessions overlap differently than they do all year.
// EnableDSTAdjust: Shift session boundaries with the seasons
input bool   EnableDSTAdjust             = true;   // Enable dst adjust
// LocalUTCOffsetHours: The operator's offset from broker time, for the dashboard only. A five-hour gap already produced one wrong conclusion about why the EA stopped on a Friday.
input int    LocalUTCOffsetHours         = 5;   // Local UTC offset hours
// ShowBothTimesOnDash: Show broker and local time together
input bool   ShowBothTimesOnDash         = true;   // Show both times on dashboard

// V262: which end of the candle came first. A bar with wicks on both sides tells you price visited
// two extremes and not in what order, and the order is most of the meaning - down first then up
// means the lows were swept and the selling is already spent; up first then down is the opposite.
// The four OHLC numbers are identical either way, and the close position hints badly: a bar that
// swept its lows, rallied hard and faded slightly at the end closes mid-range and looks balanced.
// The sequence is recoverable from the timeframe below, where the order is not in doubt.
// EnableWickOrder: Read which extreme a bar reached first
input bool   EnableWickOrder             = true;   // Enable wick order
// WickOrderTF: The bar being read
input ENUM_TIMEFRAMES WickOrderTF        = PERIOD_M5;   // Wick order TF
// WickOrderSubTF: The timeframe its order is recovered from. Only M5/M1, M15/M1 and M15/M5 are accepted - the sub-timeframe has to divide the main one evenly, and above M15 this is about a session rather than an event.
input ENUM_TIMEFRAMES WickOrderSubTF     = PERIOD_M1;   // Wick order sub TF
// WickOrderMinWick: Each wick's share of the range. Both must clear it, or there is no order to read.
input double WickOrderMinWick            = 0.20;   // Wick order min wick
// WickOrderFullWickTotal: Combined wick share at which the reading is at full weight
input double WickOrderFullWickTotal      = 0.60;   // Wick order full wick total
// WickOrderTolerance: How close ($0.15) a sub-bar must come to count as having touched the extreme
input int    WickOrderTolerance          = 150;   // Wick order tolerance
// WickOrderMinSeparation: Extremes touched in adjacent sub-bars are almost simultaneous and their order means little
input double WickOrderMinSeparation      = 0.25;   // Wick order min separation
// WickOrderFullSeparation: Share of the bar's sub-bars at which separation is complete
input double WickOrderFullSeparation     = 0.60;   // Wick order full separation
// WickOrderMinConviction: Below this the reading is not clear enough to act on
input double WickOrderMinConviction      = 0.30;   // Wick order min conviction
// WickOrderScore: Weight of trading with or against the implied direction
input int    WickOrderScore              = 4;   // Wick order score
// WickOrderPrintOnUse: Log the order
input bool   WickOrderPrintOnUse         = true;   // Wick order print on use (on/off)

// V264: levels that have earned the right to be remembered. A shelf at 4305-4315 held on the 2nd and
// 3rd of September; price returned on the 11th and the EA did not see it. It was never lost from the
// cache - the H1 lookback covers ten days - but ZoneMapScanTFSupport returns the NEAREST support,
// and nine days of trading had put dozens of newer swings in between. Every one outranked it,
// because nearest is the only comparison that scan makes. StrongZoneOverride corrects this and only
// fires when the two are already close; across nine days they are not.
// EnableProtectedZones: Keep qualifying levels where the nearest-swing scan cannot push them off
input bool   EnableProtectedZones        = true;   // Enable protected zones
// ProtectedZoneMinTouches: Touches that qualify a level on their own
input int    ProtectedZoneMinTouches     = 3;   // Protected zone min touches
// ProtectedZoneMinStrength: Or strength alone. Any single condition is enough - they are all evidence the market recognises this price, arrived at different ways.
input double ProtectedZoneMinStrength    = 2.0;   // Protected zone min strength
// ProtectedZoneFullStrength: Strength at which the reading is at full weight
input double ProtectedZoneFullStrength   = 3.5;   // Protected zone full strength
// ProtectedZoneMergeTolerance: How close ($0.40) two entries must be to count as the same level. They repeat across timeframes, which is itself a sign of quality, but one entry each is enough.
input int    ProtectedZoneMergeTolerance = 400;   // Protected zone merge tolerance
// ProtectedZoneRefreshBars: Bars between rebuilds. These levels change over days, not bars, and the scan is the expensive part.
input int    ProtectedZoneRefreshBars    = 20;   // Protected zone refresh bars
// ProtectedZonePenalty: Cost of a protected level sitting between the entry and its target
input int    ProtectedZonePenalty        = 6;   // Protected zone penalty
// ProtectedZonePrintOnUse: Log protected levels
input bool   ProtectedZonePrintOnUse     = true;   // Protected zone print on use (on/off)

// V291: deciding before price arrives. Every reading here starts when price is already somewhere -
// a level is reached, and only then does the work begin, and by the time thirty modules agree the
// reaction that made the level worth trading is several bars old. But the level was there the whole
// time, and the slow half of the answer was knowable before price got there.
// EnablePreparedLevels: Decide about levels ahead of price, so arrival costs no time
input bool   EnablePreparedLevels        = true;   // Enable prepared levels
// PrepLookAheadPoints: How far ahead ($5.00) to prepare
input int    PrepLookAheadPoints         = 5000;   // Prep look ahead points
// PrepRefreshBars: Bars between rebuilds
input int    PrepRefreshBars             = 3;   // Prep refresh bars
// PrepHitTolerance: How close ($0.40) counts as arriving
input int    PrepHitTolerance            = 400;   // Prep hit tolerance
// PrepMergePoints: Distance below which two candidates are the same level
input int    PrepMergePoints             = 600;   // Prep merge points
// PrepMinLevelStrength: Level strength worth preparing for
input double PrepMinLevelStrength        = 1.8;   // Prep min level strength
// PrepFullLevelStrength: Strength at which the level contributes fully
input double PrepFullLevelStrength       = 3.5;   // Prep full level strength
// PrepLevelWeight: Weight of the level itself
input double PrepLevelWeight             = 4.0;   // Prep level weight
// PrepTrendWeight: Weight of the monthly trend
input double PrepTrendWeight             = 3.0;   // Prep trend weight
// PrepHierarchyWeight: Weight of the larger scales objecting
input double PrepHierarchyWeight         = 4.0;   // Prep hierarchy weight
// PrepRangeWeight: Weight of range position
input double PrepRangeWeight             = 2.0;   // Prep range weight
// PrepThinWeight: Weight of a thin day
input double PrepThinWeight              = 3.0;   // Prep thin weight
// PrepMinScore: Context score below which the level is not marked
input double PrepMinScore                = 3.0;   // Prep min score
// PrepFullScore: Score at which the bonus is full
input double PrepFullScore               = 9.0;   // Prep full score
// PreparedLevelBonus: Credit for arriving at a level already decided about
input int    PreparedLevelBonus          = 4;   // Prepared level bonus
// PreparedLevelsPrintOnUse: Log prepared levels
input bool   PreparedLevelsPrintOnUse    = true;   // Prepared levels print on use (on/off)

// V266: when the larger scale disagrees. Every reading contributes points to one total, so an M5
// support and an H1 downtrend arrive as two numbers that get added together and the sum can come out
// positive - which is how the EA bought a support inside a downtrend three separate times. The
// larger scale does not vote alongside the smaller; it decides what the smaller one means.
// EnableScaleHierarchy: Let the larger scales override rather than merely vote
input bool   EnableScaleHierarchy        = true;   // Enable scale hierarchy
// HierarchyTF1: The scale with most authority
input ENUM_TIMEFRAMES HierarchyTF1       = PERIOD_H4;   // Hierarchy TF 1
input double HierarchyWeight1            = 0.45;   // Hierarchy weight 1
input ENUM_TIMEFRAMES HierarchyTF2       = PERIOD_H1;   // Hierarchy TF 2
input double HierarchyWeight2            = 0.35;   // Hierarchy weight 2
input ENUM_TIMEFRAMES HierarchyTF3       = PERIOD_M30;   // Hierarchy TF 3
input double HierarchyWeight3            = 0.25;   // Hierarchy weight 3
// HierarchyMinConflict: Below this the disagreement is minor
input double HierarchyMinConflict        = 0.35;   // Hierarchy min conflict
// HierarchyPenalty: Cost of trading against the larger scales. Heavy, because this specific mistake has now cost three baskets.
input int    HierarchyPenalty            = 7;   // Hierarchy penalty
// HierarchyPrintOnUse: Log hierarchy conflicts
input bool   HierarchyPrintOnUse         = true;   // Hierarchy print on use (on/off)
// And the other half: the scanner finds the best setup one way and never asks what the opposite
// direction would have scored. Both sides looking good is not two opportunities - it is a market
// that has not decided.
// EnableAmbiguityCheck: Check what the opposite direction had going for it
input bool   EnableAmbiguityCheck        = true;   // Enable ambiguity check
// AmbiguityStructureWeight: Points the opposite side gets for structure
input double AmbiguityStructureWeight    = 3.0;   // Ambiguity structure weight
// AmbiguitySituationWeight: For a named situation
input double AmbiguitySituationWeight    = 4.0;   // Ambiguity situation weight
// AmbiguityAlignWeight: For full timeframe alignment
input double AmbiguityAlignWeight        = 3.0;   // Ambiguity align weight
// AmbiguityLevelWeight: For a level it would be trading away from
input double AmbiguityLevelWeight        = 2.5;   // Ambiguity level weight
// AmbiguityLevelReach: How close ($1.20) that level must be
input int    AmbiguityLevelReach         = 1200;   // Ambiguity level reach
// AmbiguityLevelMinStrength: And how strong
input double AmbiguityLevelMinStrength   = 1.5;   // Ambiguity level min strength
// AmbiguityMinOpposite: Opposite-side points below which there is no real second case
input double AmbiguityMinOpposite        = 5.0;   // Ambiguity min opposite
// AmbiguityMinRatio: Share of our own score the other side must reach before it counts as indecision rather than a weaker alternative
input double AmbiguityMinRatio           = 0.45;   // Ambiguity min ratio
// AmbiguityPenalty: Cost of entering while both sides have a case
input int    AmbiguityPenalty            = 5;   // Ambiguity penalty
// AmbiguityPrintOnUse: Log ambiguous markets
input bool   AmbiguityPrintOnUse         = true;   // Ambiguity print on use (on/off)

// V268: the days when nobody is there. The holiday guard exists and works only if someone types the
// dates in - BrokerHolidayDates is a manual list that has to be refreshed every year, and a list
// nobody updated is a guard that quietly stopped guarding. Most thin days need no list: the fixed
// holidays never move, late December empties out regardless of where the weekend falls, August is
// the European holiday month and structurally quiet all month, and month-end brings rebalancing
// flow that moves price for reasons the EA cannot read. The moving holidays still need the manual
// list; this covers the ones that do not.
// EnableCalendarThinness: Read the thin days that can be calculated
input bool   EnableCalendarThinness      = true;   // Enable calendar thinness
// ThinFixedHolidayWeight: January 1st, December 25th and 26th
input double ThinFixedHolidayWeight      = 0.70;   // Thin fixed holiday weight
// ThinYearEndFromDay: December day from which the market empties out
input int    ThinYearEndFromDay          = 20;   // Thin year end from day
// ThinYearStartToDay: And January days that are still quiet
input int    ThinYearStartToDay          = 3;   // Thin year start to day
// ThinYearEndWeight: Weight of the year-end period
input double ThinYearEndWeight           = 0.45;   // Thin year end weight
// ThinAugustWeight: August. Modest - it is a month of lower volume, not a closed market.
input double ThinAugustWeight            = 0.25;   // Thin august weight
// ThinMonthEndDays: Days before month end that count
input int    ThinMonthEndDays            = 1;   // Thin month end days
// ThinMonthEndWeight: Rebalancing flow - not thin exactly, but flow the EA cannot anticipate
input double ThinMonthEndWeight          = 0.30;   // Thin month end weight
// ThinQuarterEndWeight: Quarter end, where the same flow is larger
input double ThinQuarterEndWeight        = 0.45;   // Thin quarter end weight
// ThinMinSeverity: Below this the day is ordinary
input double ThinMinSeverity             = 0.25;   // Thin min severity
// ThinDayPenalty: Cost of opening a ladder on a thin day
input int    ThinDayPenalty              = 5;   // Thin day penalty
// ThinGridDoubtFrom: Thinness at which the grid starts holding back too
input double ThinGridDoubtFrom           = 0.35;   // Thin grid doubt from
// GridDoubtThinWeight: How much it counts toward holding additions
input double GridDoubtThinWeight         = 0.30;   // Grid doubt thin weight
// ThinDayPrintOnUse: Log thin days
input bool   ThinDayPrintOnUse           = true;   // Thin day print on use (on/off)

// V269: which setups actually work here. The EA recognises sixteen setup types and treats them all
// as equally likely to work, having never counted which ones do. NEAR_ZONE_REACTION and
// MOMENTUM_SCALP are different trades with different failure modes, and on a given account, symbol
// and broker one may be reliable while the other is not - that cannot be reasoned out, it depends on
// the spread, the sessions traded and how this symbol behaves. The candle layer already learns this
// way and it was never extended to the setups, which is the level where it matters most.
// EnableSetupLearning: Keep a record per setup type and weight by it
input bool   EnableSetupLearning         = true;   // Enable setup learning
// SetupLearningMinSamples: Baskets before a type's record means anything. Four samples mean nothing and should earn nothing either way.
input int    SetupLearningMinSamples     = 8;   // Setup learning min samples
// SetupLearningMaxSamples: Window per type - a record covering a different market describes that market
input int    SetupLearningMaxSamples     = 60;   // Setup learning max samples
// SetupLearningGoodRate: Win rate above which a type earns a little
input double SetupLearningGoodRate       = 0.65;   // Setup learning good rate
// SetupLearningPoorRate: And below which it loses a little
input double SetupLearningPoorRate       = 0.45;   // Setup learning poor rate
// SetupLearningMaxBonus: Most a good record can add. Deliberately small - this is a nudge built on the account's own history, not a filter, and a run of bad luck should not disable a sound setup.
input int    SetupLearningMaxBonus       = 2;   // Setup learning max bonus
// SetupLearningMaxPenalty: And most a poor one can take away
input int    SetupLearningMaxPenalty     = 3;   // Setup learning max penalty
// PersistSetupLearning: Keep the record across restarts. Eight baskets per type takes weeks; starting over each session means never arriving at an answer.
input bool   PersistSetupLearning        = true;   // Persist setup learning (on/off)
// ShowSetupLearningOnDash: Show the best and worst performers
input bool   ShowSetupLearningOnDash     = true;   // Show setup learning on dashboard

// V270: the day's reference price. Above the daily open the day is up and buyers are in profit;
// below it the day is down. It is the single most widely watched price on the chart and the EA did
// not know where it was - V252 added the weekly open and stopped there.
// EnableDailyOpen: Read which side of the day's open price is on
input bool   EnableDailyOpen             = true;   // Enable daily open
// DailyOpenMinDistance: Distance ($0.30) before the day has committed to a side
input int    DailyOpenMinDistance        = 300;   // Daily open min distance
// DailyOpenFullDistance: Distance ($2.50) at which it has committed fully
input int    DailyOpenFullDistance       = 2500;   // Daily open full distance
// DailyOpenScore: Weight of trading with or against the day
input int    DailyOpenScore              = 3      ;   // Daily open score
// And effort against result. CandleParticipation reads volume on a single bar - whether the market
// showed up for it. What it cannot see is a new high reached on less volume than the previous high
// took, which means fewer participants are needed to move price: what a move running out looks like
// before it turns. Tick volume is not real volume, and comparing two readings of the same flawed
// measure is where a flawed measure is most usable.
// EnableVolumeDivergence: Compare volume at successive swings
input bool   EnableVolumeDivergence      = true;   // Enable volume divergence
// VolumeDivergenceTF: M5, M15 or M30 only
input ENUM_TIMEFRAMES VolumeDivergenceTF = PERIOD_M15;   // Volume divergence TF
// VolumeDivergenceLookback: Bars searched for the two swings
input int    VolumeDivergenceLookback    = 40;   // Volume divergence lookback
// VolumeDivergenceRatio: V276: 0.80 -> 0.70. Tick volume is noisy and two swings twenty percent apart is ordinary variation rather than a signal. Thirty percent is a difference worth reading.   // Volume ratio below which the divergence counts
input double VolumeDivergenceRatio       = 0.70;   // Volume divergence ratio
// VolumeDivergenceFull: Ratio at which it is at full weight
input double VolumeDivergenceFull        = 0.45;   // Volume divergence full
// VolumeDivergenceMinConviction: Below this the difference is noise
input double VolumeDivergenceMinConviction = 0.30;   // Volume divergence min conviction
// VolumeDivergenceScore: Weight either way
input int    VolumeDivergenceScore       = 4;   // Volume divergence score
// VolumeDivergencePrintOnUse: Log divergences
input bool   VolumeDivergencePrintOnUse  = true;   // Volume divergence print on use (on/off)

// V273: the trend above everything. HigherScaleConflict reads H4 over eighty bars - thirteen days,
// which is a swing inside a trend rather than the trend. This matters most at the distant levels
// V272 extended the EA's memory to reach: a daily level from four months ago is the strongest thing
// on the chart, and price arriving at it in a falling market is not the same event as arriving at it
// in a rising one. In the first the level is something the trend has to get past and usually does;
// in the second it is where the trend stops.
// EnableGlobalTrend: Read the monthly trend, not just the weekly one
input bool   EnableGlobalTrend           = true;   // Enable global trend
// GlobalTrendTF: Daily - a monthly trend cannot change within a session
input ENUM_TIMEFRAMES GlobalTrendTF      = PERIOD_D1;   // Global trend TF
// GlobalTrendLookback: Bars defining it - sixty daily bars is about three months
input int    GlobalTrendLookback         = 60;   // Global trend lookback
// GlobalTrendMinATR: V276: 3.0 -> 5.0. Three daily ATR on gold is about $135, which over three months is a three percent move - that is drift, not a trend, and at this setting the EA would report a monthly trend almost every day and charge the counter-trend penalty almost every time. Five ATR is roughly five percent over the same window, which is a move the market has actually committed to.    // Net travel in ATR before it is a trend rather than a long range
input double GlobalTrendMinATR           = 5.0;   // Global trend min ATR
// GlobalTrendFullATR: Travel at which it is fully established
input double GlobalTrendFullATR          = 10.0;   // Global trend full ATR
// GlobalTrendFullEfficiency: Efficiency at which the trend counts as clean - a move that walked straight there differs from one that fought for months, even where the endpoints match
input double GlobalTrendFullEfficiency   = 0.35;   // Global trend full efficiency
// GlobalTrendMinStrength: Below this the trend is too weak to weigh
input double GlobalTrendMinStrength      = 0.30;   // Global trend min strength
// CounterTrendBaseWeight: Weight of running against it at all
input double CounterTrendBaseWeight      = 0.55;   // Counter trend base weight
// CounterTrendLevelReach: How close ($2.00) the level being faded must be
input int    CounterTrendLevelReach      = 2000;   // Counter trend level reach
// CounterTrendLevelMinStrength: Level strength worth noting
input double CounterTrendLevelMinStrength = 1.8;   // Counter trend level min strength
// CounterTrendLevelFullStrength: Strength at which the reading is full
input double CounterTrendLevelFullStrength = 3.5;   // Counter trend level full strength
// CounterTrendMinSeverity: Below this the conflict is minor
input double CounterTrendMinSeverity     = 0.35;   // Counter trend min severity
// CounterTrendPenalty: Cost of fading a monthly trend into a level. A level standing against an established trend is not a wall - it is the next thing the trend has to get through, and most of the time it does.
input int    CounterTrendPenalty         = 6;   // Counter trend penalty
// GlobalTrendBonus: Credit for trading with it. Smaller than the penalty: being right about direction is the easy half, and entry is what the rest of the scoring is for.
input int    GlobalTrendBonus            = 3;   // Global trend bonus
// GlobalTrendPrintOnUse: Log global trend readings
input bool   GlobalTrendPrintOnUse       = true;   // Global trend print on use (on/off)

// V288: where in the move, not how many points off. A live SELL was taken at the low of a four-dollar
// decline and turned two bars later; four modules had objected and each answered by subtracting
// points. That treats a timing problem as a quality problem, and the two need opposite responses - a
// poor setup should be refused, a good setup at a poor moment should be held.
// EnableLateEntryHold: Hold a good setup that arrived at the wrong price, instead of penalising it
input bool   EnableLateEntryHold         = true;   // Enable late entry hold
// LateEntryTF: M1, M5 or M15
input ENUM_TIMEFRAMES LateEntryTF        = PERIOD_M5;   // Late entry TF
// LateEntryLookback: Bars defining the move being joined
input int    LateEntryLookback           = 30;   // Late entry lookback
// LateEntryMinSpanATR: Move size before position within it means anything
input double LateEntryMinSpanATR         = 1.5;   // Late entry min span ATR
// LateEntryHoldFrom: Position through the move above which the entry is late enough to wait
input double LateEntryHoldFrom           = 0.72;   // Late entry hold from
// LateEntryRetraceShare: How much of the move a retrace must give back - just enough that the entry stops paying for what already happened
input double LateEntryRetraceShare       = 0.25;   // Late entry retrace share
// LateEntryPrintOnUse: Log pullback holds
input bool   LateEntryPrintOnUse         = true;   // Late entry print on use (on/off)
// EnableReversalAtExtreme: V289: credit a reversal setup for being at the extreme. The reading that makes a continuation trade late makes this one timely - fading a move that has run is the only place fading works, so being at the end is the setup rather than a flaw in it.
input bool   EnableReversalAtExtreme     = true;   // Enable reversal at extreme
// ReversalAtExtremeBonus: V289: weight at the far end of the move
input int    ReversalAtExtremeBonus      = 4;   // Reversal at extreme bonus
// HierarchyOverrideFrom: V274: conflict above which the larger scale starts taking the local case away rather than merely offsetting it. Both were wired into the same structure budget, so local capped at seven, global capped at seven, and a market where M5 said buy while the monthly trend said otherwise came out neutral - which is exactly the reading that produced three losing baskets. Overruling means reducing what the smaller scale can claim.
input double HierarchyOverrideFrom       = 0.40;   // Hierarchy override from
// HierarchyOverrideMaxCut: V274: most of the local bonus a full conflict removes. Not all of it - a local reading inside a hostile trend is worth less, not worth nothing, and the trade can still be right if everything else about it is strong.
input double HierarchyOverrideMaxCut     = 0.70;   // Hierarchy override max cut

// V275: the price the EA happens to be looking at. Everything built today answers where NOT to
// trade; what decides WHEN is still one question - has the score cleared. The moment it does the
// order goes in at whatever price is on the screen, and that price is arbitrary. A setup confirming
// at the top of an M5 bar and the same setup at its low are one trade taken a dollar apart against a
// target of two-fifty. EntryBarPlacement already measures this and charges for it, which is the
// wrong response: a poor fill is not a reason to refuse a good setup, it is a reason to wait a few
// minutes. The arming engine already knows how to hold a setup and re-check it.
// EnableFillTiming: Wait a few bars for a better price rather than penalising a poor one
input bool   EnableFillTiming            = true;   // Enable fill timing
// FillTimingTF: M1 or M5 - the bar the fill is measured within
input ENUM_TIMEFRAMES FillTimingTF       = PERIOD_M5;   // Fill timing TF
// FillTimingMinRangeATR: Bar size before position within it matters. In a bar worth twenty points, waiting gains twenty points at most.
input double FillTimingMinRangeATR       = 0.70;   // Fill timing min range ATR
// FillTimingBadFrom: V279b: 0.65 -> 0.78. At 0.65 roughly a third of entries were being held for three bars, which is a lot of delay for a fill that was only slightly above the middle of its bar. At 0.78 it holds for the fills that are genuinely near the extreme, where the improvement is worth the wait.   // Position up the bar above which the fill counts as poor
input double FillTimingBadFrom           = 0.78;   // Fill timing bad from
// FillTimingMinGainShare: Improvement, as a share of the target, below which waiting is not worth it
input double FillTimingMinGainShare      = 0.12;   // Fill timing min gain share
// FillTimingMinSeverity: Below this the fill is ordinary
input double FillTimingMinSeverity       = 0.35;   // Fill timing min severity
// FillTimingPrintOnUse: Log fill holds
input bool   FillTimingPrintOnUse        = true;   // Fill timing print on use (on/off)
// And the streak, which until now only appeared on the dashboard.
// EnableStreakScoring: Let win and loss streaks reach the score
input bool   EnableStreakScoring         = true;   // Enable streak scoring
// StreakScoreFromWins: Wins in a row before the direction earns anything
input int    StreakScoreFromWins         = 2;   // Streak score from wins
// StreakScoreFullWins: Wins at which the bonus is full
input int    StreakScoreFullWins         = 4;   // Streak score full wins
// StreakWinBonus: Most a run of wins can add
input int    StreakWinBonus              = 3;   // Streak win bonus
// StreakScoreFromLosses: Losses before the reading itself is in question
input int    StreakScoreFromLosses       = 2;   // Streak score from losses
// StreakScoreFullLosses: Losses at which the penalty is full
input int    StreakScoreFullLosses       = 4;   // Streak score full losses
// StreakLossPenalty: Most a run of losses can take away. Larger than the win bonus - a losing run says something is wrong with the read, and switching direction does not fix a bad read.
input int    StreakLossPenalty           = 5;   // Streak loss penalty

// V254: settings that are each valid and wrong together. The existing input validation checks values
// one at a time and every one can pass while the combination is unworkable - a seven-rung ladder at
// 1.30x on a small account is made of valid numbers and cannot be paid for, and a 250 point target
// against a 260 point spread is a trade that closes at a loss the moment it opens.
// EnableSettingsValidation: Check the settings work together, not just individually
input bool   EnableSettingsValidation    = true;   // Enable settings validation
// SettingsLadderMaxShare: Share of the stop budget the full ladder may project to before it is flagged
input double SettingsLadderMaxShare      = 1.00;   // Settings ladder max share
// SettingsMinTPSpreadRatio: How many times the spread the target must be. Below this the trade starts behind and has to make the difference up before it makes anything.
input double SettingsMinTPSpreadRatio    = 3.0;   // Settings min TP spread ratio
// And the market rather than the settings: every distance here was sized for a particular range, and
// when ATR doubles they are all simultaneously too small while none of them knows it.
// EnableVolatilityShift: Notice when volatility has moved away from what the settings assume
input bool   EnableVolatilityShift       = true;   // Enable volatility shift
// VolatilityBaselinePeriod: Bars defining the baseline the current reading is compared against
input int    VolatilityBaselinePeriod    = 100;   // Volatility baseline period
// VolatilityShiftHigh: Ratio above which the market is wider than the settings expect
input double VolatilityShiftHigh         = 1.60;   // Volatility shift high
// VolatilityShiftFull: Ratio at which the penalty is at full weight
input double VolatilityShiftFull         = 2.50;   // Volatility shift full
// VolatilityShiftLow: Ratio below which it is narrower - noted but not penalised, since a quiet market is already covered by the dead-market check
input double VolatilityShiftLow          = 0.60;   // Volatility shift low
// VolatilityShiftPenalty: Cost of entering while the range no longer matches the settings
input int    VolatilityShiftPenalty      = 4;   // Volatility shift penalty
// VolatilityShiftPrintOnUse: Log volatility shifts
input bool   VolatilityShiftPrintOnUse   = true;   // Volatility shift print on use (on/off)
// And from the third loss: "H2 and H4 never broke - H1 was fooled". The break confirmation added in
// V232 looks one step up. A break can be real on H1 and invisible on H4, and the H4 reading is the
// one that decides whether the move continues.
// EnableDeepBreakConfirm: Require a break to survive two steps up, not one
input bool   EnableDeepBreakConfirm      = true;   // Enable deep break confirm
// DeepConfirmTF1: First step
input ENUM_TIMEFRAMES DeepConfirmTF1     = PERIOD_M30;   // Deep confirm TF 1
// DeepConfirmTF2: Second - the one that decides
input ENUM_TIMEFRAMES DeepConfirmTF2     = PERIOD_H1;   // Deep confirm TF 2
// BandGuardMinSeverity: Below this the position is unremarkable
input double BandGuardMinSeverity        = 0.30;   // Band guard min severity
// BandGuardPenalty: Cost of buying the top of a capping band, or selling the bottom of a holding one
input int    BandGuardPenalty            = 6;   // Band guard penalty
// BandGuardPrintOnUse: Log band entries
input bool   BandGuardPrintOnUse         = true;   // Band guard print on use (on/off)
// A SELL AT 4345 after 4325 was swept, price recovered to a higher high, and never returned.
// Liquidity taken, structure turned, level holding three times - and the EA sold. The sweep
// detectors exist; what was missing is the reading that a sweep has COMPLETED and its consequence
// is now in force.
// EnableSweepReversal: Read a completed sweep and the structure turn that followed it
input bool   EnableSweepReversal         = true;   // Enable sweep reversal
// SweepReversalTF: Timeframe the sequence is read on
input ENUM_TIMEFRAMES SweepReversalTF    = PERIOD_M5;   // Sweep reversal TF
// SweepReversalLookback: Bars searched for the sweep and what followed
input int    SweepReversalLookback       = 60;   // Sweep reversal lookback
// SweepReversalMinHold: Share of the recovery leg price must hold to count as having left the swept level behind rather than hovering above it
input double SweepReversalMinHold        = 0.55;   // Sweep reversal min hold
// SweepReversalMinStrength: Below this the recovery is not yet convincing
input double SweepReversalMinStrength    = 0.40;   // Sweep reversal min strength
// SweepReversalScore: Weight of trading with or against a completed sweep reversal
input int    SweepReversalScore          = 6;   // Sweep reversal score
// SweepReversalPrintOnUse: Log sweep reversals
input bool   SweepReversalPrintOnUse     = true;   // Sweep reversal print on use (on/off)

// V239: did the candle get through the one before it? Annotated on the losing buy as "the candle did
// not break the previous body" - the plainest statement of a push failing, and nothing in the EA
// could express it. It measures body size, wick share, direction and range expansion; none of those
// asks whether the bar closed beyond where the last one closed. A bullish candle that cannot clear
// the previous bullish high is buyers arriving and getting nowhere - and to the sequence reader it
// looks like two candles agreeing.
// EnableCandleProgress: Check whether the candle progressed past the one before it
input bool   EnableCandleProgress        = true;   // Enable candle progress
// CandleProgressPartialWeight: Weight when it cleared the previous body but not the previous extreme - partial failure, not total
input double CandleProgressPartialWeight = 0.55;   // Candle progress partial weight
// CandleProgressMinSeverity: Below this the stall is unremarkable
input double CandleProgressMinSeverity   = 0.35;   // Candle progress min severity
// CandleProgressPenalty: Cost of entering behind a candle that achieved nothing
input int    CandleProgressPenalty       = 5;   // Candle progress penalty
// CandleProgressPrintOnUse: Log stalled candles
input bool   CandleProgressPrintOnUse    = true;   // Candle progress print on use (on/off)

// V230: the same bar, read in context. Size alone says a push happened; it does not say whether the
// push has anywhere left to go, whether anyone was behind it, or whether entering now means joining
// it or arriving after it.
// EnableSingleCandleContext: Weigh a dominant bar by what it came off and what it is heading into
input bool   EnableSingleCandleContext   = true;   // Enable single candle context
// SingleCandleLevelReach: Distance ($1.20) at which a level ahead or behind is close enough to matter
input int    SingleCandleLevelReach      = 1200;   // Single candle level reach
// SingleCandleLevelMinStrength: Level strength below which it does not change the reading
input double SingleCandleLevelMinStrength = 1.5;   // Single candle level min strength
// SingleCandleIntoLevelDamp: How much a level directly ahead reduces the push. The move is real and it has somewhere to stop, which makes continuation far less likely than the size suggests.
input double SingleCandleIntoLevelDamp   = 0.45;   // Single candle into level damp
// SingleCandleFromLevelBoost: And how much starting FROM a level increases it - a bar off a level it respected is the level working
input double SingleCandleFromLevelBoost  = 1.25;   // Single candle from level boost
// SingleCandleVolumeBoost: Weight when the market participated
input double SingleCandleVolumeBoost     = 1.20;   // Single candle volume boost
// SingleCandleThinVolumeDamp: And when it did not. A wide bar nobody traded is stops being taken, not demand arriving - it gives the move back as easily as it made it.
input double SingleCandleThinVolumeDamp  = 0.55;   // Single candle thin volume damp
// SingleCandleChaseFrom: Position within the bar's range above which entering WITH it is chasing rather than joining. The bar has already travelled; a fill near the extreme it produced buys the end of the move.
input double SingleCandleChaseFrom       = 0.70;   // Single candle chase from
// SingleCandleChasePenalty: Cost of that
input int    SingleCandleChasePenalty    = 4;   // Single candle chase penalty

// V207: candle reading in one place, and read as a SEQUENCE. The EA measures candles in twelve
// separate modules - wick ratios for pin bars, body ratios for impulses, close positions for
// pressure - each correct on its own and none aware of the others, so one bar can be a rejection to
// one check and a continuation to another. And all of them read a single bar, while a bar means
// different things depending on what preceded it: an expanding range after quiet bars is a
// breakout, the same range after loud ones is exhaustion.
// EnableCandleSequence: Read the last few candles as a sequence and produce one verdict
input bool   EnableCandleSequence        = true;   // Enable candle sequence
// CandleSequenceTF: V215: M1 -> M5. The setups this informs are built on M5/M15 zones, so reading candles at M1 was analysing a finer resolution than the decisions being made - plenty of M1 shapes that mean nothing at the level the trade actually cares about. M5 matches the structure the EA trades.  // Timeframe the sequence is read on
input ENUM_TIMEFRAMES CandleSequenceTF   = PERIOD_M5;   // Candle sequence TF
// CandleSequenceBars: Candles in the sequence
input int    CandleSequenceBars          = 5;   // Candle sequence bars
// CandleSequenceMinLean: How decisively the sequence must lean before it counts as directional
input double CandleSequenceMinLean       = 0.25;   // Candle sequence min lean
// CandleExpansionRatio: Newest range against the recent average, above which the move is being driven
input double CandleExpansionRatio        = 1.45;   // Candle expansion ratio
// CandleContractionRatio: V239: 0.65 -> 0.78. Fading shows up gradually - candles shrink over several bars rather than one dropping 35% below the average - so a threshold that strict only fires after the move has already stopped. At 0.78 the reading arrives while it is still happening, which is when it is useful.   // Below which it is running out of participants
input double CandleContractionRatio      = 0.78;   // Candle contraction ratio
// CandleRejectionWickRatio: Wick share that marks a level being defended
input double CandleRejectionWickRatio    = 0.45;   // Candle rejection wick ratio
// CandleAbsorptionSizeRatio: Range size against average for absorption - effort
input double CandleAbsorptionSizeRatio   = 1.60;   // Candle absorption size ratio
// CandleAbsorptionMaxBody: Body share below which that effort produced no result
input double CandleAbsorptionMaxBody     = 0.30;   // Candle absorption max body
// CandleRejectionBonus: Trading with a defended level
input int    CandleRejectionBonus        = 3;   // Candle rejection bonus
// CandleRejectionPenalty: Trading against one - being on the side that just lost
input int    CandleRejectionPenalty      = 4;   // Candle rejection penalty
// CandleAbsorptionPenalty: Trading into someone large on the other side
input int    CandleAbsorptionPenalty     = 4;   // Candle absorption penalty
// CandleExpansionBonus: Small on purpose - the impulse checks already cover most of this
input int    CandleExpansionBonus        = 2;   // Candle expansion bonus
// CandleContractionPenalty: Entering with a move that is fading
input int    CandleContractionPenalty    = 3;   // Candle contraction penalty
// CandleInsidePenalty: The last candle resolved nothing, so readings from it are weaker than they look
input int    CandleInsidePenalty         = 2;   // Candle inside penalty
// CandleSequencePrintOnUse: Log candle verdicts that change the score
input bool   CandleSequencePrintOnUse    = true;   // Candle sequence print on use (on/off)
// ShowCandleStateOnDash: Show the candle sequence reading
input bool   ShowCandleStateOnDash       = true;   // Show candle state on dashboard

// V208: two questions the sequence reader cannot answer. WHERE the candle happened - a long lower
// wick at a support that has held before is sellers being refused at a level that refuses them,
// while the identical candle in open space is price dipping and someone buying. WHOSE wick it is -
// an upper wick on a bullish candle means buyers were turned back, the same wick on a bearish candle
// means sellers drove down from a high. Reading "upper wick" without the body treats opposites as
// one thing. Both refine the sequence reading rather than compete with it.
// EnableCandleAuthorship: Read the wick against the candle's own direction, not in isolation
input bool   EnableCandleAuthorship      = true;   // Enable candle authorship
// CandleAuthorshipMinWick: Wick share before it says anything at all
input double CandleAuthorshipMinWick     = 0.40;   // Candle authorship min wick
// CandleAuthorshipMinDominance: How much one wick must exceed the other to be the one that counts
input double CandleAuthorshipMinDominance = 0.15;   // Candle authorship min dominance
// CandleAuthorshipAlignedFactor: Weight when the wick runs WITH the body - the extreme was simply where the bar started, which is weaker than a move taken back
input double CandleAuthorshipAlignedFactor = 0.45;   // Candle authorship aligned factor
// CandleAuthorshipIndecisionBody: Body below which two comparable wicks mean both sides tried and neither finished in control
input double CandleAuthorshipIndecisionBody = 0.30;   // Candle authorship indecision body
// CandleAuthorshipMinToAct: Conviction needed before the wick is worth locating
input double CandleAuthorshipMinToAct    = 0.35;   // Candle authorship min to act
// EnableCandleLocation: Weigh the rejection by what it happened at
input bool   EnableCandleLocation        = true;   // Enable candle location
// CandleLocationTolerancePoints: How close ($0.70) the wick's tip must come to a level to have tested it
input int    CandleLocationTolerancePoints = 700;   // Candle location tolerance points
// CandleLocationFullStrength: Zone strength at which location weight is full
input double CandleLocationFullStrength  = 2.0;   // Candle location full strength
// CandleLocationMinSignal: Combined conviction x location below which this stays silent
input double CandleLocationMinSignal     = 0.30;   // Candle location min signal
// CandleLocationMaxScore: Ceiling on the adjustment - a rejection at a proven level is worth as much as most quality checks
input int    CandleLocationMaxScore      = 5;   // Candle location max score
// CandleLocationPrintOnUse: Log located rejections
input bool   CandleLocationPrintOnUse    = true;   // Candle location print on use (on/off)

// V209: candles judged by outcome rather than shape. Every reading so far is taken the moment a bar
// closes and then forgotten - which is the one moment it is least reliable, because a candle only
// means what the following bars let it mean. A long lower wick is a rejection until price trades
// back through it. A close beyond a level is a break until price comes straight back, at which
// point the level trapped it. So candles are recorded when they form and graded a few bars later,
// and what the EA gets is not "this looks like a rejection" but "rejections here have been holding".
// EnableCandleFollowThrough: Record candles and grade them once their outcome is known
input bool   EnableCandleFollowThrough   = true;   // Enable candle follow through
// CandleFollowThroughBars: Bars before a candle is judged
input int    CandleFollowThroughBars     = 6;   // Candle follow through bars
// CandleFollowThroughTolerance: Slack ($0.20) before a level is counted as violated
input int    CandleFollowThroughTolerance = 200;   // Candle follow through tolerance
// CandleFollowThroughMinSamples: Graded candles needed before the record is used
input int    CandleFollowThroughMinSamples = 6;   // Candle follow through min samples
// CandleFollowThroughMaxSamples: Sample ceiling - conditions change, and an old record describes a market that no longer exists
input int    CandleFollowThroughMaxSamples = 40;   // Candle follow through max samples
// CandleFollowThroughPoorRate: Hold rate below which this kind of candle has stopped being reliable here
input double CandleFollowThroughPoorRate = 0.40;   // Candle follow through poor rate
// CandleFollowThroughAdjust: Score adjustment when the record is clearly good or clearly bad
input int    CandleFollowThroughAdjust   = 3;   // Candle follow through adjust
// CandleFollowThroughPrintOnUse: Log each verdict
input bool   CandleFollowThroughPrintOnUse = true;   // Candle follow through print on use (on/off)
// EnableCandleBreakQuality: Distinguish a clean break from an attempt that was already being pushed back
input bool   EnableCandleBreakQuality    = true;   // Enable candle break quality
// CandleBreakWickPenaltyWeight: How heavily a wick back past the close counts against a break
input double CandleBreakWickPenaltyWeight = 0.8;   // Candle break wick penalty weight
// CandleBreakCleanMin: Quality above which the break is treated as real
input double CandleBreakCleanMin         = 0.35;   // Candle break clean min
// CandleBreakQualityScore: Score weight of break quality - directly relevant to the "support broke, sell again" case
input int    CandleBreakQualityScore     = 4;   // Candle break quality score
// ShowCandleFollowOnDash: Show how rejections and breaks have been resolving
input bool   ShowCandleFollowOnDash      = true;   // Show candle follow on dashboard

// V210: three readings the candle engine could not make.
// PARTICIPATION - a large candle on heavy tick volume is a market that showed up; the same candle
// on thin volume is a few orders moving an empty book, and it retraces as easily as it came.
// OPENING GAP - where a candle opens against the previous close says what happened between them; a
// bar that gaps up and closes below its open was sold into, which the body alone cannot show since
// it starts at the open. PATTERNS - shapes needing two or three bars in a specific arrangement are
// the ones that mark TURNS rather than continuations, and they are the natural confirmation for a
// setup that is waiting.
// EnableCandleParticipation: Weigh candles by the tick volume behind them
input bool   EnableCandleParticipation   = true;   // Enable candle participation
// CandleParticipationLookback: Bars defining what volume is normal here
input int    CandleParticipationLookback = 20;   // Candle participation lookback
// CandleParticipationStrong: Volume multiple that marks a candle the market showed up for
input double CandleParticipationStrong   = 1.60;   // Candle participation strong
// CandleParticipationThin: Below which the move happened on almost no participation
input double CandleParticipationThin     = 0.55;   // Candle participation thin
// CandleParticipationScore: Score weight of participation agreeing or disagreeing with the candle
input int    CandleParticipationScore    = 3;   // Candle participation score
// EnableCandleOpeningBias: Read where the candle opened against the previous close
input bool   EnableCandleOpeningBias     = true;   // Enable candle opening bias
// CandleOpeningMinGapPoints: Gap ($0.15) below which the open says nothing
input int    CandleOpeningMinGapPoints   = 150;   // Candle opening min gap points
// CandleOpeningContinuationFactor: Weight when the gap continued rather than reversed - less informative than a rejected gap
input double CandleOpeningContinuationFactor = 0.5;   // Candle opening continuation factor
// CandleOpeningScore: Score weight of the opening reading
input int    CandleOpeningScore          = 2;   // Candle opening score
// EnableCandlePatterns: Read two- and three-candle reversal shapes
input bool   EnableCandlePatterns        = true;   // Enable candle patterns
// CandlePatternMinBody: Body share for a candle to count as decisive within a pattern
input double CandlePatternMinBody        = 0.45;   // Candle pattern min body
// CandlePatternStarMaxBody: Body share of the middle candle in a star - it has to be a pause
input double CandlePatternStarMaxBody    = 0.35;   // Candle pattern star max body
// CandlePatternMinReclaim: How much of the first candle the reversal must take back
input double CandlePatternMinReclaim     = 0.50;   // Candle pattern min reclaim
// CandlePatternHaramiOuterBody: Body of the large candle in a harami
input double CandlePatternHaramiOuterBody = 0.55;   // Candle pattern harami outer body
// CandlePatternHaramiInnerBody: Body of the small one inside it
input double CandlePatternHaramiInnerBody = 0.40;   // Candle pattern harami inner body
// CandlePatternTweezerTolerance: How close two extremes must be ($0.25) to count as the same level refused twice
input int    CandlePatternTweezerTolerance = 250;   // Candle pattern tweezer tolerance
// CandlePatternScore: Score weight of a recognised pattern
input int    CandlePatternScore          = 4;   // Candle pattern score
// CandlePatternConfirmsWait: Let a reversal pattern complete an armed wait - the turn it marks is exactly what the wait was for
input bool   CandlePatternConfirmsWait   = true;   // Candle pattern confirms wait (on/off)
// CandlePatternWaitMinConf: How cleanly a reversal pattern must have formed before it ends a wait on its own
input double CandlePatternWaitMinConf    = 0.45;   // Candle pattern wait min confidence

// V211: patterns judged in context, by record, and against the higher timeframe.
// EnablePatternLocation: Weigh a pattern by the level it formed at - three candles in open space are three candles
input bool   EnablePatternLocation       = true;   // Enable pattern location
// PatternLocationTolerancePoints: How close ($0.90) the pattern's extreme must sit to a level
input int    PatternLocationTolerancePoints = 900;   // Pattern location tolerance points
// PatternLocationFloor: Weight retained when a pattern formed nowhere in particular - reduced, not ignored
input double PatternLocationFloor        = 0.45;   // Pattern location floor
// EnablePatternGrading: Track whether each pattern actually works here
input bool   EnablePatternGrading        = true;   // Enable pattern grading
// PatternGradeHorizonBars: Bars before a pattern is graded
input int    PatternGradeHorizonBars     = 12;   // Pattern grade horizon bars
// PatternGradeWinPoints: Move ($0.70) that counts the pattern as having worked
input int    PatternGradeWinPoints       = 700;   // Pattern grade win points
// PatternGradeMinSamples: Graded occurrences before the record is used
input int    PatternGradeMinSamples      = 5;   // Pattern grade min samples
// PatternGradeMaxSamples: Sample ceiling
input int    PatternGradeMaxSamples      = 30;   // Pattern grade max samples
// PatternGradePoorRate: Win rate below which this shape has stopped working here
input double PatternGradePoorRate        = 0.35;   // Pattern grade poor rate
// PatternGradePoorFactor: Weight multiplier for a shape with a poor record
input double PatternGradePoorFactor      = 0.40;   // Pattern grade poor factor
// PatternGradeGoodFactor: And for one that keeps working
input double PatternGradeGoodFactor      = 1.35;   // Pattern grade good factor
// PatternGradePrintOnUse: Log pattern outcomes
input bool   PatternGradePrintOnUse      = true;   // Pattern grade print on use (on/off)
// EnableCandleHTF: Read the higher timeframe candle alongside the lower one
input bool   EnableCandleHTF             = true;   // Enable candle HTF
// CandleHTFTimeframe: V215: M5 -> M15, keeping one step above the sequence timeframe now that it reads M5.  // The timeframe that outranks the sequence reader
input ENUM_TIMEFRAMES CandleHTFTimeframe = PERIOD_M15;   // Candle HTF timeframe
// CandleHTFMinBody: Body share below which the higher candle is undecided and says nothing
input double CandleHTFMinBody            = 0.40;   // Candle HTF min body
// CandleHTFStrongBody: Body share at which agreement is worth a bonus
input double CandleHTFStrongBody         = 0.65;   // Candle HTF strong body
// CandleHTFDisagreeScore: Maximum cost of trading against a decisive higher-timeframe candle
input int    CandleHTFDisagreeScore      = 5;   // Candle HTF disagree score
// CandleHTFAgreeScore: Bonus when both timeframes point the same way
input int    CandleHTFAgreeScore         = 2;   // Candle HTF agree score
// CandleHTFPrintOnUse: Log timeframe disagreements
input bool   CandleHTFPrintOnUse         = true;   // Candle HTF print on use (on/off)

// V212: the bar still forming. Every other reading waits for a close, which is correct and safe and
// costs a full minute - by the time an M1 rejection is confirmed, the move it signalled has been
// running for sixty seconds. The forming bar carries the same information earlier; the difficulty is
// that it is not yet a fact, since a wick at thirty seconds can be gone at fifty-five. So it is read
// and then weighted by how much of the bar has elapsed, and it never acts alone - it adjusts a
// decision the closed bars already support.
// EnableLiveBarRead: Read the bar currently forming, weighted by how far through it is
input bool   EnableLiveBarRead           = true;   // Enable live bar read
// LiveBarMinProgress: Share of the bar that must have elapsed before its shape means anything - a bar 20% formed has had time for one push, which is not a shape
input double LiveBarMinProgress          = 0.35;   // Live bar min progress
// LiveBarMinSizeATR: Range against ATR below which the live bar is quiet rather than significant
input double LiveBarMinSizeATR           = 0.35;   // Live bar min size ATR
// LiveBarStrongBody: Body share at which the live bar counts as being driven
input double LiveBarStrongBody           = 0.60;   // Live bar strong body
// LiveBarMinWeight: Weight below which the reading is discarded entirely
input double LiveBarMinWeight            = 0.20;   // Live bar min weight
// LiveBarScore: Full-weight score effect - reached only near the close, since the weight scales with the square of elapsed progress
input int    LiveBarScore                = 4;   // Live bar score
// LiveBarPrintOnUse: Log live-bar adjustments
input bool   LiveBarPrintOnUse           = true;   // Live bar print on use (on/off)
// ShowLiveBarOnDash: Show what the forming bar is doing
input bool   ShowLiveBarOnDash           = true;   // Show live bar on dashboard

// V213: how the bar is CHANGING. V212 reads the forming bar as it is now, which misses the more
// informative thing - how it got there. A bar showing a long lower wick at forty seconds and none at
// fifty-five did not change shape; the buyers who defended that low were overrun inside the same
// minute, and that is stronger information than either snapshot because it says something was tried
// and beaten. The bar is sampled as it forms and what the EA reads is the DIFFERENCE between
// samples.
// EnableLiveBarEvolution: Track how the forming bar's shape changes, not just its current state
input bool   EnableLiveBarEvolution      = true;   // Enable live bar evolution
// LiveSampleInterval: Bar progress between samples - a hundred samples of the same shape is not more information than eight
input double LiveSampleInterval          = 0.08;   // Live sample interval
// LiveWickFailedDrop: Wick share lost before it counts as having been traded through
input double LiveWickFailedDrop          = 0.18;   // Live wick failed drop
// LiveWickFailedMinPeak: Wick must have been at least this big to have meant anything when it existed
input double LiveWickFailedMinPeak       = 0.30;   // Live wick failed min peak
// LiveBodyAbsorbedDrop: Body share given back before the push counts as absorbed
input double LiveBodyAbsorbedDrop        = 0.20;   // Live body absorbed drop
// LiveBodyMinPeak: Body must have reached this before its loss says anything
input double LiveBodyMinPeak             = 0.35;   // Live body min peak
// LiveBodyGrowthMin: Body growth across samples that marks a push being sustained
input double LiveBodyGrowthMin           = 0.15;   // Live body growth min
// LiveEvolutionScore: Full-weight effect of an intra-bar change - the failed-wick case is among the clearest signals available
input int    LiveEvolutionScore          = 5;   // Live evolution score
// LiveEvolutionPrintOnUse: Log intra-bar changes
input bool   LiveEvolutionPrintOnUse     = true;   // Live evolution print on use (on/off)
// EnableLiveApproach: Notice price closing on a level right now
input bool   EnableLiveApproach          = true;   // Enable live approach
// LiveApproachPoints: Distance ($0.80) within which a level counts as being approached
input int    LiveApproachPoints          = 800;   // Live approach points
// LiveApproachMinStrength: Level strength below which the approach does not matter
input double LiveApproachMinStrength     = 1.4;   // Live approach min strength
// LiveApproachPenalty: Cost of entering while price runs into a level it has not tested yet
input int    LiveApproachPenalty         = 3;   // Live approach penalty
// ShowLiveEvolutionOnDash: Show what changed within the bar
input bool   ShowLiveEvolutionOnDash     = true;   // Show live evolution on dashboard
// CandlePatternPrintOnUse: Log recognised patterns
input bool   CandlePatternPrintOnUse     = true;   // Candle pattern print on use (on/off)
// ShowCandlePatternOnDash: Show the current pattern reading
input bool   ShowCandlePatternOnDash     = true;   // Show candle pattern on dashboard
// RecentThrustMinEfficiency: Net/path ratio: how one-directional the move must be. Chop sits ~0.2-0.4 and is ignored; 0.55 = clearly directional.
input double            RecentThrustMinEfficiency    = 0.55;   // Recent thrust min efficiency
// RecentThrustExhaustWickRatio: A rejection wick against the thrust >= this fraction of the bar's range marks the thrust as stalling, which releases its block (so genuine reversals aren't locked out).
input double            RecentThrustExhaustWickRatio = 0.45;   // Recent thrust exhaust wick ratio

// FEATURE(zone-thrust-penalty): second layer for the same live-trading gap. A zone-retest signal is
// born purely from "price touched the level and printed a small bounce bar" - it never checks HOW
// price arrived. When price arrives WITH a thrust, that small bounce is usually just a pause before
// the level breaks, so fading it is what lost money. Rather than hard-blocking (zone retests are the
// bot's main signal source and most of them are fine), apply a score penalty: strong setups still
// pass, thin ones no longer do.
// EnableZoneThrustPenalty: Penalise fading a level that price is arriving at with a thrust
input bool              EnableZoneThrustPenalty      = true;   // Enable zone thrust penalty
// ZoneThrustPenaltyPoints: Score penalty when the entry fades an arriving thrust
input int               ZoneThrustPenaltyPoints      = 4;   // Zone thrust penalty points
input double            ExhaustionWickRatio      = 0.55;   // Exhaustion wick ratio
input bool              MarketEvaluateOnNewBarOnly = false;   // Market evaluate on new bar only (on/off)

input group "ADVANCED ▸ Legacy SIRUS upgrade pack"
// UseLegacyUpgradePack: OFF - duplicated/score-stacked with the main scanner (Sweep/FBR/Near-Zone) using older, unconfirmed zone detection
input bool              UseLegacyUpgradePack     = false;   // Use legacy upgrade pack
input bool              LegacyUseSmartSRZones    = true;   // Legacy use smart SR zones (on/off)
input bool              LegacyShowSRZoneLines    = true;   // Legacy show SR zone lines (on/off)
input int               LegacySRLookbackBarsM15  = 96;   // Legacy SR lookback bars M15
input int               LegacySRLookbackBarsH1   = 120;   // Legacy SR lookback bars H1
input int               LegacySRSwingDepth       = 3;   // Legacy SR swing depth
input int               LegacyNearZonePoints     = 900;   // Legacy near zone points
input bool              LegacyUseBOSRetest       = true;   // Legacy use BOS retest (on/off)
input int               LegacyBOSLookbackBars    = 24;   // Legacy BOS lookback bars
input int               LegacyBOSRetestBars      = 8;   // Legacy BOS retest bars
input bool              LegacyUseLiquiditySweep  = true;   // Legacy use liquidity sweep (on/off)
input int               LegacySweepLookbackBars  = 12;   // Legacy sweep lookback bars
input bool              LegacyUseFakeBreakout    = true;   // Legacy use fake breakout (on/off)
input bool              LegacyUseTrendExhaustion = true;   // Legacy use trend exhaustion (on/off)
input bool              LegacyUseRoadblockGuard  = true;   // Legacy use roadblock guard (on/off)
input int               LegacyRoadblockMinRoomPts= 900;   // Legacy roadblock min room points
input bool              LegacyUseSessionDNA      = true;   // Legacy use session dna (on/off)
input int               LegacyAsiaStartHour      = 0;   // Legacy asia start hour
input int               LegacyLondonStartHour    = 7;   // Legacy london start hour
input int               LegacyNYStartHour        = 13;   // Legacy NY start hour
input bool              LegacyUseManualNewsGuard = false;   // Legacy use manual news guard (on/off)
input int               LegacyNewsStartHour      = 0;   // Legacy news start hour
input int               LegacyNewsEndHour        = 0;   // Legacy news end hour
input int               LegacyBoostSweep         = 2;   // Legacy boost sweep
input int               LegacyBoostZoneReaction  = 2;   // Legacy boost zone reaction
input int               LegacyBoostBOSRetest     = 1;   // Legacy boost BOS retest
input int               LegacyBoostFakeBreakout  = 2;   // Legacy boost fake breakout
input int               LegacyPenaltyRoadblock   = 2;   // Legacy penalty roadblock
input int               LegacyPenaltyExhaustion  = 2;   // Legacy penalty exhaustion
input bool              LegacyHardBlockNews      = true;   // Legacy hard block news (on/off)
input bool              LegacyHardBlockRoadblock = false;   // Legacy hard block roadblock (on/off)
input bool              PrintLegacyUpgradeEvents = true;   // Print legacy upgrade events

input group "ADVANCED ▸ Filters / environment"
input ENUM_TIMEFRAMES   CoreBarTF                = PERIOD_M1;   // Core bar TF
input int               CoreTimerSeconds         = 1;   // Core timer seconds
input bool              StrictGoldSymbolCheck    = true;   // Strict gold symbol check (on/off)
input string            RequiredSymbolKeyword    = "XAUUSD";   // Required symbol keyword
// MaxSpreadPoints: V90b: 300 -> 500 ($0.50) to match UnifiedMaxSpreadPoints; normal-spread gate.
input int               MaxSpreadPoints          = 500;   // Max spread points
// CriticalSpreadPoints: V90b: 300 -> 800 ($0.80). This is the ABSOLUTE hard stop; it must sit ABOVE MaxSpread so the two form a real two-stage guard (was equal to it, making the softer stage dead). $0.80 only trips on genuine spread blowouts (news, thin liquidity).
input int               CriticalSpreadPoints     = 800;   // Critical spread points
input int               MaxTickAgeSeconds        = 180;   // Max tick age seconds
input int               MinBarsM1                = 100;   // Min bars M1
input int               MinBarsM5                = 100;   // Min bars M5
input int               MinBarsM15               = 100;   // Min bars M15
input int               MinBarsH1                = 100;   // Min bars H1
input bool              RequireTradePermission   = true;   // Require trade permission
input bool              RequireFullTradeMode     = true;   // Require full trade mode

input group "ADVANCED ▸ News / session settings"
// V31.6e cleanup: removed UseNewsFilter/NewsMinutesBefore/NewsMinutesAfter - dead, redundant
// with EnableEconomicCalendarGuard (the real, MT5-native calendar system). Also removed
// UseSessionFilter/AllowAsia/AllowLondon/AllowNewYork - dead, no session-gating logic ever
// existed anywhere. NY killzone caution is now handled by section 75 instead.

input group "ADVANCED ▸ Dashboard / branding"
input int               DashboardRefreshSeconds  = 1;   // Dashboard refresh seconds
input int               ExpertsHeartbeatSeconds  = 30;   // Experts heartbeat seconds
input bool              UsePremiumDashboard      = true;   // Use premium dashboard
input bool              DashboardCompactMode     = true;   // Dashboard compact mode (on/off)
input bool              ShowDashboardSignalBlock = true;   // Show dashboard signal block
input bool              ShowDashboardMarketBlock = false;   // Show dashboard market block
input bool              ShowDashboardEnvBlock    = false;   // Show dashboard env block
input bool              ShowDashboardCounters    = false;   // Show dashboard counters
input int               DashboardMaxRows         = 34;   // Dashboard max rows
input int               DashboardLineSpacing     = 14;   // Dashboard line spacing
input bool              UsePremiumLogEngine      = true;   // Use premium log engine
input int               PremiumLogSnapshotSeconds = 60;   // Premium log snapshot seconds
input bool              PrintPremiumNextAction   = true;   // Print premium next action
input bool              PrintExpertsHeartbeat    = true;   // Print experts heartbeat
input bool              PrintNewBarLog           = true;   // Print new bar log
input bool              PrintEnvOnChange         = true;   // Print env on change
input bool              PrintModeOnChange        = true;   // Print mode on change
input bool              PrintMarketOnChange      = true;   // Print market on change
input bool              PrintTickStaleWarning    = true;   // Print tick stale warning
input string            TelegramContact          = "@farruh_zakiy";   // Telegram contact
input bool              UseVPSLiveValidation     = true;   // Use VPS live validation
input int               VPSValidationSeconds     = 30;   // VPS validation seconds
input int               VPSMaxTickSilentSeconds  = 120;   // VPS max tick silent seconds
input int               VPSMaxM1BarSilentMinutes = 5;   // VPS max M1 bar silent minutes
input int               VPSMinTicksPerMinute     = 1;   // VPS min ticks per minute
input bool              VPSWarnIfNotM1Chart      = false;   // VPS warn if not M1 chart (on/off)
input bool              VPSPrintNoTradeAudit     = true;   // VPS print no trade audit (on/off)
input int               VPSNoTradeAuditSeconds   = 120;   // VPS no trade audit seconds
input bool              VPSPrintBrokerSnapshot   = true;   // VPS print broker snapshot (on/off)
input int               VPSBrokerSnapshotSeconds = 300;   // VPS broker snapshot seconds
input int               DashboardCorner          = 0;   // Dashboard corner
input int               DashboardX               = 10;   // Dashboard x
input int               DashboardY               = 24;   // Dashboard y
input int               DashboardFontSize        = 10;   // Dashboard font size

//====================================================================
//  V29 NEW MODULES — added on top of v24 (see V29-01..V29-13 groups below)
//  Ported from v28 where noted, plus new engineering not present in either.
//====================================================================
input group "ADVANCED ▸ Operator control / manual pause"
// OperatorPauseAllNewOrders: Blocks all new entry/recovery requests, basket management stays active
input bool   OperatorPauseAllNewOrders   = false;   // Operator pause all new orders (on/off)
// OperatorPauseFirstEntries: Blocks first entries only, recovery/grid still runs
input bool   OperatorPauseFirstEntries   = false;   // Operator pause first entries (on/off)
// OperatorPauseRecoveryGrid: Blocks recovery/grid requests only, first entries still run
input bool   OperatorPauseRecoveryGrid   = false;   // Operator pause recovery grid (on/off)

input group "ADVANCED ▸ Daily profit governor"
// EnableDailyProfitGovernor: Daily profit monitor/lock; 0 target = monitor only
input bool   EnableDailyProfitGovernor          = true;   // Enable daily profit governor
// DailyProfitTargetPercent: 0=disabled; e.g. 10 = lock new entries after +10% day equity
input double DailyProfitTargetPercent           = 0.0;   // Daily profit target %
// DailyProfitBlockNewEntriesAtTarget: After target reached, block fresh first entries
input bool   DailyProfitBlockNewEntriesAtTarget = true;   // Daily profit block new entries at target (on/off)
// DailyProfitBlockRecoveryAtTarget: After target reached, optionally block recovery/grid too
input bool   DailyProfitBlockRecoveryAtTarget   = false;   // Daily profit block recovery at target (on/off)
// EnableDailyProfitTrailLock: Protect gained daily profit from giveback
input bool   EnableDailyProfitTrailLock         = false;   // Enable daily profit trail lock
// DailyProfitTrailStartPercent: Trail arms once daily profit reaches this percent
input double DailyProfitTrailStartPercent       = 5.0;   // Daily profit trail start %
// DailyProfitTrailGivebackPercent: % giveback from daily peak equity that triggers trail lock
input double DailyProfitTrailGivebackPercent    = 35.0;   // Daily profit trail giveback %
// DailyProfitBlockNewEntriesOnTrail: Trail lock blocks fresh first entries
input bool   DailyProfitBlockNewEntriesOnTrail  = true;   // Daily profit block new entries on trail (on/off)
// DailyProfitBlockRecoveryOnTrail: Trail lock blocks recovery/grid too
input bool   DailyProfitBlockRecoveryOnTrail    = true;   // Daily profit block recovery on trail (on/off)
// DailyProfitPrintOnLock: Print once when target/trail lock fires
input bool   DailyProfitPrintOnLock             = true;   // Daily profit print on lock (on/off)

input group "ADVANCED ▸ Settings sanity"
// EnableSettingsSanityGovernor: Catches dangerous/conflicting settings before live trading
input bool   EnableSettingsSanityGovernor      = true;   // Enable settings sanity governor
// SettingsSanityBlockLiveOnCritical: Critical config mismatch blocks live order requests
input bool   SettingsSanityBlockLiveOnCritical = true;   // Settings sanity block live on critical (on/off)
// SettingsSanityMinGridPoints: GridDistancePoints below this is treated as dangerous
input int    SettingsSanityMinGridPoints       = 1500;   // Settings sanity min grid points
// SettingsSanityMinTPPoints: FirstEntryTPMinPoints below this is treated as dangerous
input int    SettingsSanityMinTPPoints         = 300;   // Settings sanity min TP points
// SettingsSanityPrintOnChange: Print only when sanity state changes
input bool   SettingsSanityPrintOnChange       = true;   // Settings sanity print on change (on/off)

input group "ADVANCED ▸ License / account guard"
// EnableLicenseAccountGuard: Optional client/account access guard; default OFF for owner tests
input bool   EnableLicenseAccountGuard   = false;   // Enable license account guard
// LicenseGuardBlockLiveInvalid: If guard enabled and invalid, block live orders
input bool   LicenseGuardBlockLiveInvalid = true;   // License guard block live invalid (on/off)
// LicenseAllowedAccounts: Comma list: 12345,67890. Empty = any account allowed
input string LicenseAllowedAccounts      = "";   // License allowed accounts
// LicenseExpiryDate: Format YYYY.MM.DD. Empty = no expiry
input string LicenseExpiryDate           = "";   // License expiry date
input string LicenseClientName           = "SIRUS CLIENT";   // License client name

input group "ADVANCED ▸ Setup doctor"
// EnableSetupDoctor: Diagnose common client/VPS setup mistakes
input bool   EnableSetupDoctor              = true;   // Enable setup doctor
// SetupDoctorBlockLiveInvalid: Block live orders if terminal/account/symbol setup is invalid
input bool   SetupDoctorBlockLiveInvalid    = true;   // Setup doctor block live invalid (on/off)
// SetupDoctorRequireTradeAllowed: Terminal/account/MQL trade permission must be allowed
input bool   SetupDoctorRequireTradeAllowed = true;   // Setup doctor require trade allowed (on/off)
// SetupDoctorPrintOnChange: Print setup state only when changed
input bool   SetupDoctorPrintOnChange       = true;   // Setup doctor print on change (on/off)

input group "ADVANCED ▸ Zone map / TP guard"
// EnableZoneMapTPGuard: Cap TP before a nearby H1/M15 wall instead of ignoring it
input bool   EnableZoneMapTPGuard    = true;   // Enable zone map TP guard
// ZoneMapLookbackH1: V110: 80 -> 240. H1 candles scanned for nearest wall. At 80 this only reached back 3.3 DAYS, so levels built 4-7 days ago were invisible to the whole zone system (live chart: the 4020 and 4070 zones were never seen while 4000 and 4165 were). 240 = 10 days, which covers the swing structure price actually respects. The swing cache is per-bar and capped at 80 zones per TF, so this costs almost nothing.
input int    ZoneMapLookbackH1       = 240;   // Zone map lookback H1
// ZoneMapLookbackM15: V110: 120 -> 200. M15 candles scanned (200 = ~2 days), so intraday levels from the previous session stay in view.
input int    ZoneMapLookbackM15      = 200;   // Zone map lookback M15
// ZoneMapBufferPoints: Keep TP this many points before the wall
input int    ZoneMapBufferPoints     = 150;   // Zone map buffer points
// ZoneMapPrintOnUse: Print only when TP actually gets capped
input bool   ZoneMapPrintOnUse       = false;   // Zone map print on use (on/off)
// EnableZoneMapMomentumCaution: Momentum/trend entries ignore zones by default - this adds soft caution
input bool   EnableZoneMapMomentumCaution = true;   // Enable zone map momentum caution
// ZoneMapMomentumCautionPoints: If a wall is this close ahead, trim lot instead of blocking
input int    ZoneMapMomentumCautionPoints = 400;   // Zone map momentum caution points
// ZoneMapMomentumLotFactor: Lot multiplier applied when momentum entry is near a wall
input double ZoneMapMomentumLotFactor     = 0.5;   // Zone map momentum lot factor
// EnableZoneMapGridAwareness: Let grid distance shorten toward a real H1/M15 zone; never lengthens it
input bool   EnableZoneMapGridAwareness   = true;   // Enable zone map grid awareness
// ZoneMapGridBufferPoints: Small buffer added beyond the zone for the grid target
input int    ZoneMapGridBufferPoints      = 100;   // Zone map grid buffer points
// ZoneGridMinStrength: Zone must be at least this strong to shrink grid distance
input double ZoneGridMinStrength          = 1.5;   // Zone grid min strength
// EnableZoneMapSwingConfirm: V29: require a genuine confirmed swing point, not any candle wick
input bool   EnableZoneMapSwingConfirm    = true;   // Enable zone map swing confirm
// ZoneMapSwingDepth: Bars required on each side to confirm a swing high/low
input int    ZoneMapSwingDepth            = 3;   // Zone map swing depth

input group "ADVANCED ▸ HTF structure commander"
// EnableHTFStructureWarn: Warn + trim lot when entry is counter to H1 structure
input bool   EnableHTFStructureWarn  = true;   // Enable HTF structure warn
// HTFStructureLookbackBars: H1 bars back to compare for trend bias
input int    HTFStructureLookbackBars = 20;   // HTF structure lookback bars
// HTFStructurePrintOnUse: Print only when a counter-trend entry is detected
input bool   HTFStructurePrintOnUse  = false;   // HTF structure print on use (on/off)
// HTFStructureCounterLotFactor: Lot multiplier when entry is counter to H1 bias (never blocks)
input double HTFStructureCounterLotFactor = 0.6;   // HTF structure counter lot factor

input group "ADVANCED ▸ Real retry engine"
// EnableRealRetryEngine: Real backoff on transient broker errors, no Sleep()
input bool   EnableRealRetryEngine        = true;   // Enable real retry engine
// RetryDelaySeconds: Wait between transient-error retries (requote/timeout/connection)
input int    RetryDelaySeconds            = 3;   // Retry delay seconds
// RetryMaxAttempts: Max consecutive transient retries before a longer cooldown
input int    RetryMaxAttempts             = 3;   // Retry max attempts
// RetryGiveUpCooldownSeconds: Cooldown once max attempts exhausted
input int    RetryGiveUpCooldownSeconds   = 60;   // Retry give up cooldown seconds
// RetryNonTransientCooldownSeconds: Wait after a non-transient failure (no money, invalid stops, etc.)
input int    RetryNonTransientCooldownSeconds = 20;   // Retry non transient cooldown seconds
input bool   RetryPrintOnUse              = true;   // Retry print on use (on/off)

input group "ADVANCED ▸ Correlation guard"
// EnableCorrelationGuard: Trim lot when other open positions compound this symbol's risk
input bool   EnableCorrelationGuard       = true;   // Enable correlation guard
input ENUM_TIMEFRAMES CorrelationTF       = PERIOD_H1;   // Correlation TF
// CorrelationLookbackBars: Bars used to compute price correlation
input int    CorrelationLookbackBars      = 100;   // Correlation lookback bars
// CorrelationHighThreshold: |correlation| above this is considered compounding
input double CorrelationHighThreshold     = 0.75;   // Correlation high threshold
// CorrelationLotFactor: Lot multiplier applied when compounding exposure detected
input double CorrelationLotFactor         = 0.5;   // Correlation lot factor
input bool   CorrelationPrintOnUse        = false;   // Correlation print on use (on/off)

input group "ADVANCED ▸ Spread-aware minimum TP"
input bool   EnableSpreadAwareTP          = true;   // Enable spread aware TP
// SpreadAwareMinRatio: TP must be at least this many times the current spread
input double SpreadAwareMinRatio          = 3.0;   // Spread aware min ratio
// SpreadAwareCommissionPoints: Optional extra buffer for commission-equivalent points
input int    SpreadAwareCommissionPoints  = 0;   // Spread aware commission points
input bool   SpreadAwarePrintOnUse        = false;   // Spread aware print on use (on/off)

input group "ADVANCED ▸ Real economic calendar"
// EconomicCalendarCurrency: Currency to scan; leave blank to scan all
input string EconomicCalendarCurrency       = "USD";   // Economic calendar currency
// EconomicCalendarMinImportance: 1=Moderate+High, 2=High only
input int    EconomicCalendarMinImportance  = 2;   // Economic calendar min importance
// EconomicCalendarPreMinutes: Caution window before a high-impact event
input int    EconomicCalendarPreMinutes     = 15;   // Economic calendar pre minutes
// EconomicCalendarPostMinutes: Caution window after a high-impact event
input int    EconomicCalendarPostMinutes    = 15;   // Economic calendar post minutes
// EconomicCalendarRefreshSeconds: Do not query the calendar every tick
input int    EconomicCalendarRefreshSeconds = 300;   // Economic calendar refresh seconds
// EconomicCalendarHardBlockFirst: Block new entries in the news window
input bool   EconomicCalendarHardBlockFirst = true;   // Economic calendar hard block first (on/off)
// EconomicCalendarLotFactor: Lot multiplier during caution window when not hard-blocking
input double EconomicCalendarLotFactor      = 0.4;   // Economic calendar lot factor
input bool   EconomicCalendarPrintOnUse     = true;   // Economic calendar print on use (on/off)

input group "ADVANCED ▸ Smart partial close"
// EnableSmartPartialClose: V62b: OFF on user report. Partial close trims part of the basket, but basket_points is measured from the AVERAGE entry price, and closing individual positions SHIFTS that average - typically the wrong way, so the remaining lot needs price to travel FURTHER to reach TP. Observed live: 0.20 opened, 0.07 trimmed at +2200pts, 0.13 left, and the TP kept moving away. This fundamentally fights the martingale-grid logic (grid ADDS to improve the average; a partial trim WORSENS it), so the two should not run together. The basket now rides intact to its normal TP / trailing / SL.
input bool   EnableSmartPartialClose      = false;   // Enable smart partial close
// PartialCloseMinOrders: Only when basket has at least this many orders
input int    PartialCloseMinOrders        = 2;   // Partial close min orders
// PartialCloseAtProfitPoints: Basket profit points required to trigger partial close
input int    PartialCloseAtProfitPoints   = 1500;   // Partial close at profit points
// PartialClosePercent: Percent of each position's volume to close
input double PartialClosePercent          = 35.0;   // Partial close %
input bool   PartialClosePrintOnUse       = true;   // Partial close print on use (on/off)

input group "ADVANCED ▸ First entry trend-against guard"
// EnableFirstEntryTrendGuard: Trim lot when opening straight against a strong HTF/BOS trend
input bool   EnableFirstEntryTrendGuard         = true;   // Enable first entry trend guard
// FirstEntryTrendAgainstLotFactor: Lot multiplier applied when trend/BOS strongly oppose the entry
input double FirstEntryTrendAgainstLotFactor    = 0.4;   // First entry trend against lot factor
input bool   FirstEntryTrendGuardPrintOnUse     = true;   // First entry trend guard print on use (on/off)

input group "ADVANCED ▸ Impulse / correction cooldown"
// EnableImpulseCooldown: Keep grid cautious for a few bars after an impulse, not just the spike bar
input bool   EnableImpulseCooldown              = true;   // Enable impulse cooldown
// ImpulseCooldownBarsCorrection: Shorter cooldown: impulse was against the established trend (likely a pullback)
input int    ImpulseCooldownBarsCorrection      = 2;   // Impulse cooldown bars correction
// ImpulseCooldownBarsTrend: Longer cooldown: impulse aligned with the established trend (possible acceleration)
input int    ImpulseCooldownBarsTrend           = 5;   // Impulse cooldown bars trend
input bool   ImpulseCooldownPrintOnUse          = false;   // Impulse cooldown print on use (on/off)

// V115: the impulse cooldown above was only ever consulted by GridCanOpen, so after a big candle the
// grid waited but a brand-new basket could still be opened on the very next tick. The user noticed
// this from live behaviour ("it used to wait when a big candle appeared"). Opening a fresh basket
// into a just-printed impulse is worse than adding to one: the entry price is the worst of the move,
// spread is widest, and the snap-back is most likely. Apply the same wait to first entries.
// EntryBlockFreshImpulse: Also make FIRST ENTRIES wait out the impulse cooldown (not just grid additions)
input bool   EntryBlockFreshImpulse             = true;   // Entry block fresh impulse (on/off)
// EntryImpulseCooldownBars: 0 = use the same ImpulseCooldownBarsCorrection/Trend values as the grid. Set a number to give first entries their own (usually longer) wait.
input int    EntryImpulseCooldownBars           = 0;   // Entry impulse cooldown bars

input group "ADVANCED ▸ Multi-bar velocity check"
// EnableMultiBarVelocityCheck: Catch sustained multi-candle moves a single-candle impulse check would miss
input bool   EnableMultiBarVelocityCheck        = true;   // Enable multi bar velocity check
// VelocityLookbackBars: Net move measured over this many closed bars
input int    VelocityLookbackBars               = 4;   // Velocity lookback bars
// VelocityATRMultiplier: Net move vs ATR(SignalTF) multiplier to count as dangerous velocity
input double VelocityATRMultiplier              = 3.0;   // Velocity ATR multiplier

input group "ADVANCED ▸ Multi-timeframe zone map"
input bool   EnableZoneMapM5                    = true;   // Enable zone map M5
input int    ZoneMapLookbackM5                  = 150;   // Zone map lookback M5
input bool   EnableZoneMapM30                   = true;   // Enable zone map M30
// ZoneMapLookbackM30: V110: 100 -> 200 (~4 days), closing the gap between the M15 and H1 windows.
input int    ZoneMapLookbackM30                 = 200;   // Zone map lookback M30
input bool   EnableZoneMapH4                    = true;   // Enable zone map H4
// ZoneMapLookbackH4: V272: 90 -> 180, fifteen days to thirty. H4 and H1 currently cover the same fortnight and largely duplicate each other; extending H4 gives the pair distinct jobs - H1 for the recent context, H4 for the structure behind it.     // V110: 60 -> 90 (~15 days), so the swing structure above H1 is properly covered.
input int    ZoneMapLookbackH4                  = 180;   // Zone map lookback H4
input bool   EnableZoneMapD1                    = true;   // Enable zone map D1
// ZoneMapLookbackD1: V272: 45 -> 120, roughly six months of trading. These are the levels that matter when price leaves the range it has been working in - after a large move there are no recent swings in the new territory by definition, and what remains is the round numbers and the turns from months ago. Daily bars are few, so the cache absorbs this without strain.     // V110: 30 -> 45 (~1.5 months), for the major levels price returns to weeks later.
input int    ZoneMapLookbackD1                  = 120;   // Zone map lookback D1
// EnableZoneMapM1: V31.6z16 NEW: real gap found via live testing - a level bouncing repeatedly on M1 was completely invisible to the whole zone system before (it only ever scanned M5 and up)
input bool   EnableZoneMapM1                     = true;   // Enable zone map M1
input int    ZoneMapLookbackM1                   = 200;   // Zone map lookback M1
// ZoneMapM1TouchWeight: M1 touches are far more frequent/noisy than H1/D1 ones - down-weighted so they add real signal without dominating the confluence count
input double ZoneMapM1TouchWeight                 = 0.4;   // Zone map M1 touch weight
// EnableZoneMapBestPick: V31.6z42 NEW: real gap found - the core zone finder always picked the NEAREST swing point regardless of significance, so a moderately-strong HTF level slightly further away could be invisible while an insignificant, barely-closer M1 swing won by default
input bool   EnableZoneMapBestPick                = true;   // Enable zone map best pick
// ZoneMapBestPickDistancePenalty: per-point distance penalty when weighing a zone's TF significance against how far it is (used by the weighted best-zone pick)
input double ZoneMapBestPickDistancePenalty       = 0.0006;   // Zone map best pick distance penalty

// FEATURE(strong-zone-override): the plain nearest-zone scan returns the CLOSEST support/resistance
// and ignores strength, so a small local level right in front of price hides a much stronger, older
// level a little further away (the "koradi vs kormedi" case: price blew through the near level and
// sat in drawdown until it reached the real zone further off). After finding the nearest zone, also
// find the strongest zone within a search window; if that stronger zone is meaningfully stronger and
// not too much further, prefer it. Applies to both support and resistance. 3-digit: 1000pt = $1.
// EnableStrongZoneOverride: V201: ON. This was already written and already correct - it prefers a clearly stronger level a little further away over the merely-closest one, which is exactly the failure behind the losing entries. It has been switched off, so the EA has been reading a minor swing as "the level" while the real one sat unseen just beyond it. Turning it on costs nothing; it only changes which level is reported when a much stronger one is within reach.   // OFF by default: this REPLACES the nearest zone with a stronger further one, which is not the same as remembering broken levels (see ghost-zone feature below). Left in code but disabled unless explicitly wanted.
input bool   EnableStrongZoneOverride  = true;   // Enable strong zone override
// StrongZoneSearchPoints: How far past the nearest zone to look for a stronger one (20000 = $20)
input int    StrongZoneSearchPoints    = 20000;   // Strong zone search points
// StrongZoneMinScoreRatio: V201: 1.5 -> 1.25. The further level had to score 50% higher before it displaced the nearest - and since strength is 1.0 + touches x 0.25, that meant a four-touch level could not outrank a one-touch swing. At 1.25 a three-touch level (1.75) displaces an untested one (1.25), which is the case that was costing money.     // The stronger zone's weighted score must beat the nearest zone's by at least this ratio to take over
input double StrongZoneMinScoreRatio   = 1.25;   // Strong zone min score ratio

// FEATURE(ghost-zones): a support/resistance that gets broken doesn't vanish from a trader's mind -
// price often returns to RETEST it and reacts there. The scanner only tracks currently-intact
// levels, so once price closes through a level it disappears and the bot is blind to it. This keeps
// a broken H1/H4/D1 level as a "ghost" reaction zone for a few days: if price comes back to it, it
// is treated as a possible reversal point (the bot won't enter continuing INTO it). Only H1+ levels
// qualify - lower TFs break constantly and would just fill the chart with noise. 3-digit: 1000pt=$1.
// EnableGhostZones: Remember broken H1/H4/D1 levels as reaction zones
input bool   EnableGhostZones          = true;   // Enable ghost zones
// GhostZoneBreakPoints: A level counts as BROKEN once price closes this far past it (2500 = $2.5), filtering wick pokes / fakeouts
input int    GhostZoneBreakPoints      = 2500;   // Ghost zone break points
// GhostZoneMaxCount: V206: 4 -> 10. Ghost zones are levels that have BROKEN - price went through them - and they matter because price returns to retest them. Four slots covered a few hours; a support broken this morning was already forgotten by afternoon, so a second sell into the same level looked like fresh ground.       // Keep at most this many ghost zones (nearest to price); oldest/furthest are dropped
input int    GhostZoneMaxCount         = 10;   // Ghost zone max count
// GhostZoneStrengthFactor: A ghost's strength = its original strength x this (a broken level still matters, but less than an intact one)
input double GhostZoneStrengthFactor   = 0.65;   // Ghost zone strength factor
// GhostZoneReactionPoints: How close price must come back to a ghost to treat it as an active reaction zone (1500 = $1.5)
input int    GhostZoneReactionPoints   = 1500;   // Ghost zone reaction points
// GhostZoneTTLDaysH1: Days an H1-origin ghost stays alive
input int    GhostZoneTTLDaysH1        = 3;   // Ghost zone TTL days H1
// GhostZoneTTLDaysD1: Days a D1-origin ghost stays alive
input int    GhostZoneTTLDaysD1        = 7;   // Ghost zone TTL days D1
// M5/M15 also form ghosts on user report (their broken levels react often), but only STRONG ones -
// a strength filter keeps the chart from filling with the many trivial levels those TFs break daily.
// EnableGhostZonesLowTF: Also remember broken M5/M15 levels (strong ones only)
input bool   EnableGhostZonesLowTF     = true;   // Enable ghost zones low TF
// GhostZoneLowTFMinStrength: V87b: 1.8 -> 1.5. The user observes broken-level reactions mostly on M5/M15, so the filter was letting real zones through only when very strong. 1.5 still needs a genuine multi-touch level (not every minor break) but catches the mid-strength zones price actually reacts at.
input double GhostZoneLowTFMinStrength  = 1.5;   // Ghost zone low TF min strength
// GhostZoneLowTFBreakPoints: Break distance for M5/M15 ghosts (1500 = $1.5; smaller than the HTF $2.5 since these TFs move less per bar)
input int    GhostZoneLowTFBreakPoints  = 1500;   // Ghost zone low TF break points
// GhostZoneTTLDaysM15: Days an M15-origin ghost stays alive
input int    GhostZoneTTLDaysM15        = 2;   // Ghost zone TTL days M15
// GhostZoneCrossLookbackBars: Bars back to sample price when deciding a level was actually CROSSED (was on the other side then, this side now), not merely nearby
input int    GhostZoneCrossLookbackBars  = 6;   // Ghost zone cross lookback bars
// GhostZoneHardBlock: false = ghost applies a SCORE PENALTY (a ghost is a probability, not a certainty, so by default it discourages rather than forbids - a strong enough signal still passes). true = hard-block like the other context guards.
input bool   GhostZoneHardBlock       = false;   // Ghost zone hard block (on/off)
// GhostZoneScorePenalty: Penalty applied to a signal running into a ghost when not hard-blocking
input int    GhostZoneScorePenalty    = 4;   // Ghost zone score penalty

// FEATURE(impulse-correction-penalty): buying into a shallow bounce while a DOWN impulse is still
// alive (or selling into a shallow dip during an UP impulse) is exactly the "caught against the
// move" loss the user showed - price corrects a little, the bot enters with the correction, then the
// impulse resumes. Penalise a counter-impulse entry while the retracement is still SHALLOW (impulse
// likely not done). Once price has retraced past the threshold the impulse may be over, so we stop
// penalising and let normal signals through. Soft (score penalty), consistent with the other guards.
// EnableImpulseCorrectionPenalty: Penalise entering WITH a shallow correction against a live impulse
input bool   EnableImpulseCorrectionPenalty = true;   // Enable impulse correction penalty
// ImpulseCorrectionDonePercent: Retracement % at/above which the impulse is treated as possibly finished (no penalty). Below this, a counter-impulse entry is penalised.
input double ImpulseCorrectionDonePercent    = 50.0;   // Impulse correction done %
// ImpulseCorrectionPenaltyPoints: Score penalty for a counter-impulse entry during a shallow correction
input int    ImpulseCorrectionPenaltyPoints  = 4;   // Impulse correction penalty points
// ImpulseCorrectionPenaltyWindowBars: Only apply within this many bars of the impulse (after that the impulse is stale)// How much score is lost per point of extra distance - tuned so a full timeframe-weight advantage (e.g. D1 vs M15, 3.0 vs 1.0 = 2.0) offsets roughly 3300 points of extra distance
input int    ImpulseCorrectionPenaltyWindowBars = 20;   // Impulse correction penalty window bars

input group "ADVANCED ▸ Kalman filter trend"
// EnableKalmanTrend: Upgrades HTF trend slope from SMA to a Kalman (alpha-beta) filter
input bool   EnableKalmanTrend        = true;   // Enable kalman trend
// KalmanAlpha: Level gain: higher = reacts faster to new price, less smooth
input double KalmanAlpha              = 0.35;   // Kalman alpha
// KalmanBeta: Trend gain: higher = trend estimate reacts faster, less stable
input double KalmanBeta               = 0.05;   // Kalman beta
// KalmanWarmupBars: Bars needed before the filter is trusted (falls back to SMA until then)
input int    KalmanWarmupBars         = 30;   // Kalman warmup bars
// KalmanTrendMinPoints: Minimum trend slope (points/bar) to call it up/down, not flat
input double KalmanTrendMinPoints     = 5.0;   // Kalman trend min points
input bool   KalmanPrintOnUse         = false;   // Kalman print on use (on/off)

input group "ADVANCED ▸ Zone strength / confluence"
// EnableZoneStrength: Score a zone by how many TFs/touches confirm it, not just distance
input bool   EnableZoneStrength             = true;   // Enable zone strength
// ZoneStrengthTolerancePoints: Two swing points within this many points count as the same zone
input int    ZoneStrengthTolerancePoints    = 80;   // Zone strength tolerance points
// ZoneStrengthPerTouch: Strength added per confirming swing point found nearby
input double ZoneStrengthPerTouch           = 0.25;   // Zone strength per touch

// V234: which timeframe drew the level. Touch count alone cannot say - four touches on M1 and four
// on H1 produce the same number and they are not the same level. An M1 swing is where price paused
// for a few minutes; an H1 swing is where it turned for hours, and the people who defended it are
// still watching. This is the reading behind the loss where an M1 break looked clean while M5 and
// M15 had never moved at all.
// EnableZoneTFWeight: Weigh a level by the largest timeframe that recognises it
input bool   EnableZoneTFWeight          = true;   // Enable zone TF weight
// ZoneTFMatchTolerance: How close ($0.25) a cached swing must be to count as the same level
input int    ZoneTFMatchTolerance        = 250;   // Zone TF match tolerance
// ZoneTFWeightLowest: M1 - where price paused, not where it turned
input double ZoneTFWeightLowest          = 0.70;   // Zone TF weight lowest
// ZoneTFWeightLow: M5 - the scale the setups are built on, so the baseline
input double ZoneTFWeightLow             = 1.00;   // Zone TF weight low
// ZoneTFWeightMid: M15 and M30
input double ZoneTFWeightMid             = 1.20;   // Zone TF weight mid
// ZoneTFWeightHigh: H1
input double ZoneTFWeightHigh            = 1.40;   // Zone TF weight high
// ZoneTFWeightHigher: H4 and D1 - levels with a day or more of history behind them
input double ZoneTFWeightHigher          = 1.65;   // Zone TF weight higher

// V235: two things a touch count cannot see. RETESTS - price visiting a level four times in one
// approach is a pause; visiting, leaving, and returning is the market recognising it. LIQUIDITY -
// a long wick through a level means stops were taken there or are waiting, and price is drawn back
// to that. A level that attracts price is the opposite of one that turns it away.
// EnableZoneRetestCount: Count returns to a level, not just touches
input bool   EnableZoneRetestCount       = true;   // Enable zone retest count
// ZoneRetestTF: Timeframe returns are counted on
input ENUM_TIMEFRAMES ZoneRetestTF       = PERIOD_M5;   // Zone retest TF
// ZoneRetestLookback: Bars searched
input int    ZoneRetestLookback          = 100;   // Zone retest lookback
// ZoneRetestTolerance: How close ($0.40) counts as being at the level
input int    ZoneRetestTolerance         = 400;   // Zone retest tolerance
// ZoneRetestAwayPoints: How far ($1.20) price must travel before coming back counts as a return rather than hovering
input int    ZoneRetestAwayPoints        = 1200;   // Zone retest away points
// ZoneRetestBonusPer: Strength added per return
input double ZoneRetestBonusPer          = 0.15;   // Zone retest bonus per
// ZoneRetestMaxBonus: Ceiling - three returns is confirmation; ten means a range boundary, which touches already count
input double ZoneRetestMaxBonus          = 0.45;   // Zone retest max bonus
// EnableZoneWickCheck: Reduce a level with a long wick through it
input bool   EnableZoneWickCheck         = true;   // Enable zone wick check
// ZoneWickTF: Timeframe the wick is read on - lower ones show noise
input ENUM_TIMEFRAMES ZoneWickTF         = PERIOD_M15;   // Zone wick TF
// ZoneWickLookback: Bars searched
input int    ZoneWickLookback            = 8;   // Zone wick lookback
// ZoneWickMinRatio: Wick share of its bar before it counts as liquidity
input double ZoneWickMinRatio            = 0.40;   // Zone wick min ratio
// ZoneWickTolerance: How close ($0.60) the wick tip must reach
input int    ZoneWickTolerance           = 600;   // Zone wick tolerance
// ZoneWickPenalty: How much a full wick reduces the level
input double ZoneWickPenalty             = 0.35;   // Zone wick penalty

// V132: zone strength used to be a pure touch COUNT (1.0 + touches x 0.25), so a level needed four
// tests before it could reach the 1.8 the counter-zone block requires. A level that had thrown price
// back once, hard, scored only 1.25 - and the EA sold straight into one, which went into drawdown.
// These add the missing dimension: how far price travelled AWAY from the level after touching it.
// EnableZoneReactionStrength: Add rejection strength (how hard price was thrown back) to a zone's strength, not just how often it was touched
input bool   EnableZoneReactionStrength   = true;   // Enable zone reaction strength
// ZoneReactionTF: Timeframe the rejections are measured on
input ENUM_TIMEFRAMES ZoneReactionTF      = PERIOD_M15;   // Zone reaction TF
// ZoneReactionLookbackBars: How far back to look for touches of the level
input int    ZoneReactionLookbackBars     = 200;   // Zone reaction lookback bars
// ZoneReactionHorizonBars: Bars after a touch in which the move away is measured
input int    ZoneReactionHorizonBars      = 12;   // Zone reaction horizon bars
// ZoneReactionMinATR: A rejection must travel at least this many ATR to count at all (filters ordinary drift)
input double ZoneReactionMinATR           = 1.0;   // Zone reaction min ATR
// ZoneReactionWeight: Strength added per ATR of rejection beyond the minimum
input double ZoneReactionWeight           = 0.45;   // Zone reaction weight
// ZoneReactionMaxBonus: Ceiling on the rejection bonus so one huge move cannot make every level unbreakable
input double ZoneReactionMaxBonus         = 1.20;   // Zone reaction max bonus

// V141: zone decay. Strength counted touches and ADDED for each one, so the levels the market had
// eaten most were the ones the EA trusted most - the exact opposite of how a level behaves. The
// orders resting there are finite: each test spends some, which is why a fourth touch so often
// breaks. Decay is read from the reactions themselves (recent bounces weaker than early ones) plus
// a floor-level allowance for sheer number of tests.
// EnableZoneDecay: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableZoneDecay              = true;   // Enable zone decay
// ZoneDecayMinTouches: Touches needed before early-vs-recent reactions can be compared
input int    ZoneDecayMinTouches          = 3;   // Zone decay min touches
// ZoneDecayFreeTouches: Touches allowed before the count itself starts implying decay
input int    ZoneDecayFreeTouches         = 3;   // Zone decay free touches
// ZoneDecayPerExtraTouch: Decay added per touch beyond that allowance
input double ZoneDecayPerExtraTouch       = 0.12;   // Zone decay per extra touch
// ZoneDecayWeight: How much of the measured decay is applied to strength (1.0 = full effect)
input double ZoneDecayWeight              = 0.55;   // Zone decay weight
// ZoneDecayMinRetain: V200: 0.45 -> 0.70. The floor on how far a level can be discounted. At 0.45 a three-touch zone scoring 1.75 fell to 0.79 - below an untested single swing - purely for having been tested.   // A worn level never falls below this fraction of its strength - even a spent level still holds something
input double ZoneDecayMinRetain           = 0.70;   // Zone decay min retain
// ZoneDecayApplyBelow: V200: decay only engages below this retention figure - that is, only where reactions have measurably weakened. Above it the level is being tested and holding, which is evidence for it rather than against.
input double ZoneDecayApplyBelow         = 0.85;   // Zone decay apply below
// EnableZoneRoundNumberBonus: Small extra weight for round-number price levels (e.g. x50, x100)
input bool   EnableZoneRoundNumberBonus     = true;   // Enable zone round number bonus
// ZoneRoundNumberStep: Round-number spacing to check against (price units, not points)
input double ZoneRoundNumberStep            = 50.0;   // Zone round number step
// ZoneRoundNumberTolerancePoints: How close to the round number counts as "on it"
input double ZoneRoundNumberTolerancePoints = 60.0;   // Zone round number tolerance points
// ZoneRoundNumberBonusWeight: Strength bonus if the zone sits on a round number
input double ZoneRoundNumberBonusWeight     = 0.5;   // Zone round number bonus weight

// V148: who is the level for? A round number or a clean obvious swing is where retail stops sit -
// price is DRAWN to it, takes them, and often turns straight after. It is a magnet, not a wall. A
// band price spent real time inside and tested without breaking is where size rests; that one
// holds. The EA treats a round number as extra strength, which reads the retail case backwards.
// The deciding factor is HISTORY, not price: an untested round number is a magnet, but one that has
// held repeatedly has become a real level.
// EnableParticipantModel: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableParticipantModel         = true;   // Enable participant model
// ParticipantRoundNumberWeight: Evidence toward RETAIL when the level sits on a round number
input double ParticipantRoundNumberWeight   = 1.0;   // Participant round number weight
// ParticipantUntestedRoundWeight: Extra retail evidence when that round number has not been tested - obvious to everyone, defended by no one
input double ParticipantUntestedRoundWeight = 1.2;   // Participant untested round weight
// ParticipantBandWidthPoints: Band width ($2.00) that counts as a real area rather than a line
input int    ParticipantBandWidthPoints     = 2000;   // Participant band width points
// ParticipantBandWeight: Evidence toward INSTITUTIONAL for occupying an area
input double ParticipantBandWeight          = 1.0;   // Participant band weight
// ParticipantHoldTouches: Touches after which "has it held?" becomes the decisive question
input int    ParticipantHoldTouches         = 3;   // Participant hold touches
// ParticipantMaxDecayToHold: Decay below which a repeatedly-tested level counts as still holding
input double ParticipantMaxDecayToHold      = 0.40;   // Participant max decay to hold
// ParticipantHeldWeight: Evidence weight of that hold test - the strongest single signal
input double ParticipantHeldWeight          = 1.5;   // Participant held weight
// ParticipantRetailFadePenalty: Penalty for trading a bounce off a RETAIL level before its stops are taken
input int    ParticipantRetailFadePenalty   = 2;   // Participant retail fade penalty
// ParticipantInstBonus: Bonus for trading a bounce off an INSTITUTIONAL level
input int    ParticipantInstBonus           = 2;   // Participant inst bonus
// ParticipantMinConfidence: Confidence needed before the profile affects the decision
input double ParticipantMinConfidence       = 0.35;   // Participant min confidence
// ParticipantPrintOnUse: Log profiles that change a decision
input bool   ParticipantPrintOnUse          = true;   // Participant print on use (on/off)

// V149: path density. The room check knows where the FIRST wall is, which answers "can the target
// be reached" but nothing about what lies beyond it. One wall with open road behind it and five
// walls stacked every dollar both report the same first distance, yet the first is a scalp and the
// second is a grind where a $2.50 target must survive five separate stalls. Density measures how
// hard the path is; the largest gap says whether there is open road worth aiming at.
// EnablePathDensity: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnablePathDensity          = true;   // Enable path density
// PathDensityTF: Timeframe whose levels form the path
input ENUM_TIMEFRAMES PathDensityTF     = PERIOD_M15;   // Path density TF
// PathDensityRangePoints: How far ahead to survey ($10)
input int    PathDensityRangePoints     = 10000;   // Path density range points
// PathDensityMergePoints: Levels within this distance are one wall, not several ($0.70)
input int    PathDensityMergePoints     = 700;   // Path density merge points
// PathDensityCrowdedPerDollar: Walls per $1 above which the path counts as crowded
input double PathDensityCrowdedPerDollar = 0.60;   // Path density crowded per dollar
// PathDensityCrowdedPenalty: Penalty for entering into a crowded path
input int    PathDensityCrowdedPenalty  = 2;   // Path density crowded penalty
// PathDensityClearGapFactor: A gap this many times the basket target counts as genuinely open road
input double PathDensityClearGapFactor  = 1.5;   // Path density clear gap factor
// PathDensityClearBonus: Bonus when open road lies ahead
input int    PathDensityClearBonus      = 2;   // Path density clear bonus
// PathDensityPrintOnUse: Log path readings that change a decision
input bool   PathDensityPrintOnUse      = false;   // Path density print on use (on/off)

// V150: market scale. Every structural threshold here is a fixed number tuned against a particular
// market - cluster within $2.50, merge walls within $0.70. When the market changes character those
// numbers stop meaning what they meant: in a quiet session $2.50 swallows half the chart into one
// band, in a volatile one it splits a single zone into five. ATR is the usual fix but measures BAR
// size, not structure size - a market can print small bars while swinging widely. The typical
// distance between consecutive swings is the unit the thresholds actually want.
// EnableMarketScale: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableMarketScale          = true;   // Enable market scale
// MarketScaleTF: Timeframe the scale is measured on
input ENUM_TIMEFRAMES MarketScaleTF     = PERIOD_M15;   // Market scale TF
// MarketScaleMaxSwings: V150b: 12 -> 20. Swing pairs sampled - a wider sample changes less abruptly as individual swings enter and leave it.
input int    MarketScaleMaxSwings       = 20;   // Market scale max swings
// MarketScaleSmoothAlpha: EMA weight for new readings (0.12 = slow drift, not steps)
input double MarketScaleSmoothAlpha     = 0.12;   // Market scale smooth alpha
// MarketScaleDeadBandPct: Changes smaller than this % are ignored entirely - the market has not really changed scale
input double MarketScaleDeadBandPct     = 8.0;   // Market scale dead band %
// MarketScaleMaxStepPct: Maximum the scale may move in one bar (%), so even a real regime change is walked into gradually
input double MarketScaleMaxStepPct      = 6.0;   // Market scale max step %
// MarketScaleMinSwings: Minimum samples before the scale is trusted at all
input int    MarketScaleMinSwings       = 4;   // Market scale min swings
// MarketScaleReferencePoints: The scale the fixed thresholds were tuned against ($3.00). Above it thresholds widen, below it they tighten.
input int    MarketScaleReferencePoints = 3000;   // Market scale reference points
// MarketScaleMinFactor: Floor on the adjustment - a misread scale cannot shrink a threshold past this
input double MarketScaleMinFactor       = 0.60;   // Market scale min factor
// MarketScaleMaxFactor: Ceiling on the adjustment
input double MarketScaleMaxFactor       = 1.80;   // Market scale max factor
// ShowMarketScaleOnDash: V170d: default OFF. o'lchov birligi - sozlashda kerak, kunlik kuzatuvda emas. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowMarketScaleOnDash      = false;   // Show market scale on dashboard

// V151: forced flow. Most moves are decisions - someone chose, and the move can pause or reverse at
// any point. A minority are liquidations: margin calls, stop-outs, hedges unwinding. Those orders
// must be filled regardless of price, which is why they run straight, refuse to retrace, and snap
// back hard once the forced supply is exhausted. The EA sees both as "a strong move", yet they need
// opposite handling: fading a decision is dangerous, while fading a spent liquidation is one of the
// best reversals available - the seller was never willing and there is nothing behind them.
// EnableForcedFlow: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableForcedFlow           = true;   // Enable forced flow
// ForcedFlowTF: Timeframe the flow is measured on
input ENUM_TIMEFRAMES ForcedFlowTF      = PERIOD_M5;   // Forced flow TF
// ForcedFlowLookbackBars: Bars covering the move
input int    ForcedFlowLookbackBars     = 8;   // Forced flow lookback bars
// ForcedFlowMinSizeATR: Move must be at least this many ATR to qualify at all
input double ForcedFlowMinSizeATR       = 2.5;   // Forced flow min size ATR
// ForcedFlowFullSizeATR: Size at which the "unusually large" signature is fully present
input double ForcedFlowFullSizeATR      = 5.0;   // Forced flow full size ATR
// ForcedFlowMaxPullback: Deepest allowed retracement (25% of the move). A decision breathes; forced flow does not.
input double ForcedFlowMaxPullback      = 0.25;   // Forced flow max pullback
// ForcedFlowMinBodyRatio: Candle bodies must be at least this fraction of range - forced fills leave little wick
input double ForcedFlowMinBodyRatio     = 0.65;   // Forced flow min body ratio
// ForcedFlowAgainstPenalty: V173: 3 -> 5. majburiy buyurtmalar oldida turish - ular narxni so\'ramaydi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering INTO live forced flow - it does not stop for anyone
input int    ForcedFlowAgainstPenalty   = 5;   // Forced flow against penalty
// ForcedFlowFadeBonus: Bonus for fading forced flow once it has stalled (see exhaustion below)
input int    ForcedFlowFadeBonus        = 2;   // Forced flow fade bonus
// ForcedFlowMinIntensity: Intensity needed before the reading affects the decision
input double ForcedFlowMinIntensity     = 0.40;   // Forced flow min intensity
// ForcedFlowPrintOnUse: Log forced flow that changes a decision
input bool   ForcedFlowPrintOnUse       = true;   // Forced flow print on use (on/off)

// V153: confidence calibration. The score engine states a conviction on every entry and the lot
// sizing now acts on it - but nothing has ever checked whether the number means what it claims. If
// setups scoring 12 win no more often than setups scoring 8, then "12" is decoration and sizing up
// on it is sizing up on noise. Grouping closed baskets by their opening score answers that.
// EnableScoreCalibration: Track outcomes per score band to find out whether higher scores really are better trades
input bool   EnableScoreCalibration     = true;   // Enable score calibration
// ScoreCalibrationMinSamples: Closed baskets in a band before its win rate is trusted
input int    ScoreCalibrationMinSamples = 12;   // Score calibration min samples
// ScoreCalibrationMaxSamples: Sample ceiling per band; beyond it older evidence decays so the record reflects current behaviour
input int    ScoreCalibrationMaxSamples = 80;   // Score calibration max samples
// EnableCalibratedLotSizing: Let a band's measured win rate adjust the lot, not just the raw score
input bool   EnableCalibratedLotSizing  = true;   // Enable calibrated lot sizing
// CalibrationGoodWinRate: Win rate at or above which a band's conviction is considered earned
input double CalibrationGoodWinRate     = 0.55;   // Calibration good win rate
// CalibrationPoorWinRate: Win rate at or below which the band's conviction is not supported by the record
input double CalibrationPoorWinRate     = 0.42;   // Calibration poor win rate
// ScoreCalibrationPrintOnUse: Log each recorded outcome
input bool   ScoreCalibrationPrintOnUse = true;   // Score calibration print on use (on/off)
// ShowCalibrationOnDash: V170d: default OFF. ball kalibrlash statistikasi - haftada bir marta qarash yetarli. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowCalibrationOnDash      = false;   // Show calibration on dashboard

// V154: pattern memory. Every other module reasons from theory - this is a zone, so price should
// react. Sound, but still assumption. This asks what the market has ACTUALLY done the last times
// the chart looked like this: it takes the recent bars as a shape, normalises away price and
// volatility so only the form remains, finds the closest historical matches, and looks at what
// followed each one. The evidence carries no theory at all, which is exactly why it is worth having
// alongside modules that are made of theory.
// EnablePatternMemory: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnablePatternMemory        = true;   // Enable pattern memory
// PatternMemoryTF: Timeframe the shapes are read on
input ENUM_TIMEFRAMES PatternMemoryTF   = PERIOD_M15;   // Pattern memory TF
// PatternMemoryShapeBars: Bars forming the shape
input int    PatternMemoryShapeBars     = 20;   // Pattern memory shape bars
// PatternMemoryHorizonBars: Bars after a match used to judge what followed
input int    PatternMemoryHorizonBars   = 10;   // Pattern memory horizon bars
// PatternMemoryHistoryBars: How far back to search
input int    PatternMemoryHistoryBars   = 3000;   // Pattern memory history bars
// PatternMemoryKeepMatches: Closest matches kept as the sample
input int    PatternMemoryKeepMatches   = 20;   // Pattern memory keep matches
// PatternMemoryMinSamples: Matches needed before the reading is used
input int    PatternMemoryMinSamples    = 8;   // Pattern memory min samples
// PatternMemoryMaxDistance: Maximum average per-point deviation to count as a match. Tighter = fewer but truer matches.
input double PatternMemoryMaxDistance   = 0.14;   // Pattern memory max distance
// PatternMemoryMinOutcome: Move (in units of the match window's own range) needed to call an outcome directional
input double PatternMemoryMinOutcome    = 0.25;   // Pattern memory min outcome
// PatternMemoryMinBias: Bias strength needed before it affects the decision
input double PatternMemoryMinBias       = 0.35;   // Pattern memory min bias
// PatternMemoryMinFit: Match quality needed before the reading is trusted
input double PatternMemoryMinFit        = 0.45;   // Pattern memory min fit
// PatternMemoryWithBonus: Bonus for entering with what history did
input int    PatternMemoryWithBonus     = 2;   // Pattern memory with bonus
// PatternMemoryAgainstPenalty: Penalty for entering against it
input int    PatternMemoryAgainstPenalty = 2;   // Pattern memory against penalty
// PatternMemoryPrintOnUse: Log readings that change a decision
input bool   PatternMemoryPrintOnUse    = true;   // Pattern memory print on use (on/off)
// ShowPatternMemoryOnDash: V170d: default OFF. tarixiy naqsh - qiziq, lekin qaror bergani jurnalда ko'rinadi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowPatternMemoryOnDash    = false;   // Show pattern memory on dashboard

// V155: warning reliability. The EA now issues a dozen cautions, each with a penalty chosen by hand,
// and nobody has checked which of them are right. If baskets opened despite "crowded path" lose 70%
// of the time, that warning is under-weighted; if "retail level" baskets win as often as any other,
// that penalty is costing trades for nothing. Recording which warnings were live at entry and
// crediting them when the basket closes lets the penalties re-weight themselves toward the cautions
// this market actually respects. This is the mechanism behind knowing WHY losses happen, remembering
// a pattern that has hurt before, and reviewing each basket afterwards - one question asked once.
// EnableWarningLearning: Let each warning's track record adjust its penalty
input bool   EnableWarningLearning      = true;   // Enable warning learning
// WarningLearningMinSamples: Baskets carrying a warning before its record is trusted
input int    WarningLearningMinSamples  = 10;   // Warning learning min samples
// WarningLearningMaxSamples: Sample ceiling; beyond it older evidence decays
input int    WarningLearningMaxSamples  = 60;   // Warning learning max samples
// WarningNeutralAccuracy: Accuracy at which a warning keeps its configured penalty exactly
input double WarningNeutralAccuracy     = 0.50;   // Warning neutral accuracy
// WarningWeightRange: How far a fully-right or fully-wrong record may move the penalty
input double WarningWeightRange         = 0.60;   // Warning weight range
// WarningWeightMin: Floor - a warning that has been wrong still keeps half its weight
input double WarningWeightMin           = 0.50;   // Warning weight min
// WarningWeightMax: Ceiling - a warning that has been right cannot dominate everything
input double WarningWeightMax           = 1.80;   // Warning weight max
// WarningLearningPrintOnUse: Log which warnings each closed basket credited
input bool   WarningLearningPrintOnUse  = true;   // Warning learning print on use (on/off)
// ShowWarningStatsOnDash: V170d: default OFF. ogohlantirish ishonchliligi - uzoq muddatli statistika. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowWarningStatsOnDash     = false;   // Show warning stats on dashboard

// V156: regime. The EA runs identical settings whether price is trending, ranging or thrashing -
// the same $2.50 target and $7 grid spacing apply to a market moving $80 a day and one moving $15.
// MARKET_STATE exists but only ever blocks; it never changes HOW the EA trades. These four regimes
// are genuinely different problems: trends persist so targets can be wider, ranges stall at the
// edges so targets must be tighter, volatility needs room, and a quiet market may not reach a normal
// target at all. Switching is deliberately slow - flipping settings mid-basket would be worse than
// using the wrong ones consistently.
// EnableRegimeSwitching: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableRegimeSwitching      = true;   // Enable regime switching
// RegimeTF: Timeframe the regime is read on
input ENUM_TIMEFRAMES RegimeTF          = PERIOD_M15;   // Regime TF
// RegimeLookbackBars: Bars used to judge how much ground price actually covered
input int    RegimeLookbackBars         = 30;   // Regime lookback bars
// RegimeADXPeriod: ADX period for the trend test
input int    RegimeADXPeriod            = 14;   // Regime ADX period
// RegimeTrendADX: ADX at or above which a trend is present
input double RegimeTrendADX             = 24.0;   // Regime trend ADX
// RegimeTrendEfficiency: Net move as a share of the range - a trend covers ground rather than revisiting it
input double RegimeTrendEfficiency      = 0.45;   // Regime trend efficiency
// RegimeRangeEfficiency: Below this, price is revisiting the same prices - a range
input double RegimeRangeEfficiency      = 0.25;   // Regime range efficiency
// RegimeVolatileRatio: ATR this many times its own longer-term norm = volatile
input double RegimeVolatileRatio        = 1.60;   // Regime volatile ratio
// RegimeQuietRatio: ATR this far below its norm = quiet
input double RegimeQuietRatio           = 0.65;   // Regime quiet ratio
// RegimeConfirmBars: Bars a new regime must hold before the switch is made
input int    RegimeConfirmBars          = 4;   // Regime confirm bars
// RegimeTrendTPFactor: Target multiplier while trending - moves persist
input double RegimeTrendTPFactor        = 1.25;   // Regime trend TP factor
// RegimeRangeTPFactor: While ranging - take less, the edges stall
input double RegimeRangeTPFactor        = 0.80;   // Regime range TP factor
// RegimeVolatileTPFactor: Wider swings, wider target
input double RegimeVolatileTPFactor     = 1.15;   // Regime volatile TP factor
// RegimeQuietTPFactor: A normal target may simply not be reached
input double RegimeQuietTPFactor        = 0.75;   // Regime quiet TP factor
// RegimeTrendGridFactor: Grid spacing while trending - adverse runs go further
input double RegimeTrendGridFactor      = 1.20;   // Regime trend grid factor
// RegimeRangeGridFactor: Reversion comes sooner in a range
input double RegimeRangeGridFactor      = 0.90;   // Regime range grid factor
// RegimeVolatileGridFactor: Volatility needs real room between additions
input double RegimeVolatileGridFactor   = 1.35;   // Regime volatile grid factor
input double RegimeQuietGridFactor      = 0.85;   // Regime quiet grid factor
// RegimeVolatileScoreOffset: Extra score demanded before committing in volatility
input int    RegimeVolatileScoreOffset  = 2;   // Regime volatile score offset
// RegimeQuietScoreOffset: And in a market that may not travel far enough
input int    RegimeQuietScoreOffset     = 1;   // Regime quiet score offset
// RegimePrintOnUse: Log regime switches
input bool   RegimePrintOnUse           = true;   // Regime print on use (on/off)
// ShowRegimeOnDash: Show the current regime on the dashboard
input bool   ShowRegimeOnDash           = true;   // Show regime on dashboard

// V157: two blind spots. Every hard block is an untested hypothesis - a refusal that would have lost
// saved money, one that would have won cost money, and both look identical from inside the EA
// because the trade never existed. And now that the regime has a name, a question becomes askable
// that was not before: is there a market state where this system simply does not work? Neither
// changes behaviour by itself; they produce the evidence a later decision can rest on.
// EnableBlockAudit: Record refused entries and check where price went, to find out whether the blocks are right
input bool   EnableBlockAudit           = true;   // Enable block audit
// BlockAuditHorizonBars: Bars after a refusal before it is judged
input int    BlockAuditHorizonBars      = 15;   // Block audit horizon bars
// BlockAuditDecisivePoints: Move needed to call the refusal right or wrong ($1.50). Smaller moves are inconclusive and discarded.
input int    BlockAuditDecisivePoints   = 1500;   // Block audit decisive points
// BlockAuditDedupeBars: The same direction refused again within this many bars is one decision, not several
input int    BlockAuditDedupeBars       = 5;   // Block audit dedupe bars
// BlockAuditMaxSamples: Sample ceiling; beyond it older verdicts decay
input int    BlockAuditMaxSamples       = 100;   // Block audit max samples
// BlockAuditPrintOnUse: Log each verdict
input bool   BlockAuditPrintOnUse       = true;   // Block audit print on use
// EnableRegimePerformance: Track closed-basket outcomes per regime
input bool   EnableRegimePerformance    = true;   // Enable regime performance
// RegimePerfMinSamples: Baskets in a regime before its win rate is meaningful
input int    RegimePerfMinSamples       = 10;   // Regime perf min samples
// RegimePerfMaxSamples: Sample ceiling per regime
input int    RegimePerfMaxSamples       = 60;   // Regime perf max samples
// ShowBlockAuditOnDash: V170d: default OFF. blok auditi - uzoq muddatli statistika. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowBlockAuditOnDash       = false;   // Show block audit on dashboard

// V159: basket projection. Every risk check in this EA looks at the position as it exists NOW -
// current drawdown, current margin, current exposure. But a martingale entry is not a 0.25 lot
// position, it is a commitment to a whole ladder, and the only moment that commitment can be
// declined is before the first order exists. Walking the ladder forward answers what the entry
// actually commits to: how many orders, what total volume, what drawdown, and whether the margin
// survives it. A basket that runs out of margin at order five was never survivable - and that was
// knowable in advance.
// EnableBasketProjection: Walk the full grid ladder forward before entering
input bool   EnableBasketProjection     = true;   // Enable basket projection
// ProjectionCheckLevels: Also check whether a level sits inside the span the ladder would need
input bool   ProjectionCheckLevels      = true;   // Projection check levels (on/off)
// ProjectionCautionSeverity: Severity (worst of projected DD vs SL, and projected margin vs limit) at which the entry is penalised
input double ProjectionCautionSeverity  = 0.75;   // Projection caution severity
// ProjectionBlockSeverity: Severity at which the entry is refused outright - the ladder would not survive its own completion
input double ProjectionBlockSeverity    = 1.00;   // Projection block severity
// ProjectionMinLotFactor: V159b: smallest size the entry may be scaled to in order to fit the ladder inside the account. Below this the trade is too small to be worth its costs.
input double ProjectionMinLotFactor     = 0.45;   // Projection min lot factor
// ProjectionHardBlock: V171: true -> false while the size scaling proves itself. The projection already shrinks the entry to fit the account, which handles the problem it was written for; the refusal on top of that was a second answer to a question already answered, and it fires on the same ladder maths that has never run live. The scaling stays active - only the outright refusal is off.
input bool   ProjectionHardBlock        = false;   // Projection hard block (on/off)
// ProjectionPrintOnUse: Log projections that change a decision
input bool   ProjectionPrintOnUse       = true;   // Projection print on use (on/off)
// ShowProjectionOnDash: V170d: default OFF. narvon proyeksiyasi - entry paytida jurnalда yoziladi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowProjectionOnDash       = false;   // Show projection on dashboard

// V160: basket health. Drawdown, order count, margin, age and structure are each tracked with their
// own threshold, which works while only one is deteriorating. It fails when several are mildly bad
// at once - four orders used, 30% drawdown, eight hours old, structure turned - none tripping its
// own limit while the basket is clearly in trouble. One figure makes that visible and actionable:
// a healthy basket holds out for its full target, a deteriorating one takes the first reasonable
// exit. The most expensive mistake in recovery trading is waiting for the original target long
// after the position stopped being able to reach it.
// EnableBasketHealth: Combine drawdown, orders, margin, age and structure into one health figure
input bool   EnableBasketHealth         = true;   // Enable basket health
// BasketHealthWeightDD: Weight of drawdown - the most direct measure
input double BasketHealthWeightDD       = 2.0;   // Basket health weight DD
// BasketHealthWeightOrders: Weight of how much of the grid ladder is already spent
input double BasketHealthWeightOrders   = 1.5;   // Basket health weight orders
// BasketHealthWeightMargin: Weight of margin consumption
input double BasketHealthWeightMargin   = 1.5;   // Basket health weight margin
// BasketHealthWeightAge: Weight of age - a basket that cannot close is a basket the market left behind
input double BasketHealthWeightAge      = 1.2;   // Basket health weight age
// BasketHealthWeightStructure: Weight of the structure that justified the basket having broken
input double BasketHealthWeightStructure = 1.0;   // Basket health weight structure
// BasketHealthAgeBars: Bars (core TF) at which age counts as fully spent - 480 M1 bars = 8 hours
input int    BasketHealthAgeBars        = 480;   // Basket health age bars
// BasketHealthGood: At or above this the basket is healthy and keeps its full target
input double BasketHealthGood           = 0.65;   // Basket health good
// BasketHealthPoor: At or below this it takes the minimum target it can
input double BasketHealthPoor           = 0.25;   // Basket health poor
// BasketHealthMinTPFactor: Smallest target multiplier a struggling basket will accept
input double BasketHealthMinTPFactor    = 0.55;   // Basket health min TP factor
// ShowBasketHealthOnDash: Show the health figure while a basket is open
input bool   ShowBasketHealthOnDash     = true;   // Show basket health on dashboard
// EnableAdaptiveBasketAge: V160b: learn what a normal basket lifetime is here instead of using a fixed figure. A scalper closing in twenty minutes and a slower setup need completely different answers, and only the record knows which this is.
input bool   EnableAdaptiveBasketAge    = true;   // Enable adaptive basket age
// AdaptiveBasketAgeAlpha: How quickly the learned lifetime adapts (slow, so one unusual basket does not move it far)
input double AdaptiveBasketAgeAlpha     = 0.15;   // Adaptive basket age alpha
// AdaptiveBasketAgeMultiple: A basket counts as fully stale at this multiple of the typical winning lifetime
input double AdaptiveBasketAgeMultiple  = 3.0;   // Adaptive basket age multiple
// AdaptiveBasketAgeMinBars: Floor on the learned figure (1 hour) - below this normal variation would look like staleness
input int    AdaptiveBasketAgeMinBars   = 60;   // Adaptive basket age min bars
// AdaptiveBasketAgeMaxBars: Ceiling (2 days) - beyond this age has clearly stopped being informative
input int    AdaptiveBasketAgeMaxBars   = 2880;   // Adaptive basket age max bars
// AdaptiveBasketAgePrintOnUse: Log the learned lifetime as it updates
input bool   AdaptiveBasketAgePrintOnUse = true;   // Adaptive basket age print on use (on/off)

// V161: scale-in. The grid answers a wrong entry by adding size to it - which works when price comes
// back and is ruinous when it does not, and the EA cannot tell which case it is in at the moment it
// decides. Scale-in inverts that: enter at part size, and complete only after price has moved in
// favour, which is the market agreeing rather than the EA insisting. The trade-off is honest - a
// setup that was immediately right earns less, because part of it was added at a worse price. What
// it buys is that every setup which was simply wrong costs a fraction of what it used to.
// EnableScaleIn: Take the first entry at part size and complete it only on confirmation
input bool   EnableScaleIn              = true;   // Enable scale in
// ScaleInFirstFraction: V175: 0.80 -> 0.85. The floor above now guarantees the lot itself, so this split applies to a full-size entry: 0.25 enters at 0.21 with 0.04 held for confirmation. Raised slightly because a 15% holdback is enough to matter on a wrong entry without meaningfully reducing a right one.
input double ScaleInFirstFraction       = 0.85;   // Scale in first fraction
// ScaleInConfirmPoints: Move in favour that counts as the market agreeing ($0.80)
input int    ScaleInConfirmPoints       = 800;   // Scale in confirm points
// ScaleInAbandonPoints: Move against at which the remainder is dropped and the grid takes over ($1.20)
input int    ScaleInAbandonPoints       = 1200;   // Scale in abandon points
// ScaleInMaxWaitBars: Bars to wait for confirmation before dropping the remainder - a setup going nowhere is not worth completing
input int    ScaleInMaxWaitBars         = 30;   // Scale in max wait bars
// ScaleInPrintOnUse: Log scale-in entries, completions and abandonments
input bool   ScaleInPrintOnUse          = true;   // Scale in print on use (on/off)

// V161b: a fixed 60% / $0.80 / $1.20 throws away information the EA already has. How much to commit
// immediately is a statement about how much this particular setup is trusted, and what counts as
// "price agreed" depends on what the market is currently doing - $0.80 is a real move in a quiet
// session and noise in a fast one. Most importantly, reaching a distance is not the same as being
// confirmed: price can drift there on thin overlapping bars, which is the market wandering rather
// than agreeing.
// EnableAdaptiveScaleIn: Size the first part by conviction and scale the distances to current volatility
input bool   EnableAdaptiveScaleIn      = true;   // Enable adaptive scale in
// ScaleInMinFraction: V161c: 0.40 -> 0.80. Even the weakest qualifying setup enters at 80%. A setup that passed thirteen hard blocks and thirty penalties is a real opportunity - halving it distrusts the EA's own filters. The held-back portion is a hedge against being wrong, not a statement that the setup is doubtful.
input double ScaleInMinFraction         = 0.80;   // Scale in min fraction
// ScaleInMaxFraction: V161c: 0.80 -> 0.95. A setup clearing every bar comfortably takes almost all of its size straight away - at that point waiting for confirmation costs more in worse fills than it saves.
input double ScaleInMaxFraction         = 0.95;   // Scale in max fraction
// ScaleInVolatileFactor: V161c: 0.75 -> 0.92. Volatility still justifies holding a little more back, but the reduction is now gentle - at the old value it would have pulled an 80% entry down to 60%, undoing the floor above.
input double ScaleInVolatileFactor      = 0.92;   // Scale in volatile factor
// ScaleInConfirmATR: Confirmation distance in ATR - replaces the fixed points figure when adaptive
input double ScaleInConfirmATR          = 0.80;   // Scale in confirm ATR
// ScaleInAbandonATR: Abandonment distance in ATR
input double ScaleInAbandonATR          = 1.20;   // Scale in abandon ATR
// EnableScaleInQuality: Require the confirming move to have conviction, and refuse to complete into a wall
input bool   EnableScaleInQuality       = true;   // Enable scale in quality
// ScaleInRequireConviction: Drifting to the confirmation distance does not count as confirmation
input bool   ScaleInRequireConviction   = true;   // Scale in require conviction (on/off)
// ScaleInMinRoomFactor: Room beyond the confirmation point needed before completing, as a multiple of the confirmation distance
input double ScaleInMinRoomFactor       = 1.00;   // Scale in min room factor
// ScaleInWallMinStrength: Only a genuine level blocks a completion
input double ScaleInWallMinStrength     = 1.8;   // Scale in wall min strength

// V162: noise. There are stretches where the market is busy and pointless - bars print, indicators
// produce readings, and forty bars later price is where it started. The signals are not wrong during
// those stretches, they are describing noise, and a signal describing noise is not weak but
// meaningless. A setup can clear every filter and score 12 in conditions where a $2.50 target was
// never reachable. The measure is displacement against distance travelled: price moving $8 to end up
// $6 away is trending, price moving $8 to end up $0.50 away is churning. Deliberately separate from
// volatility - the regime detector reads SIZE, this reads PURPOSE.
// EnableNoiseFilter: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableNoiseFilter          = true;   // Enable noise filter
// NoiseTF: Timeframe the noise is measured on
input ENUM_TIMEFRAMES NoiseTF           = PERIOD_M5;   // Noise TF
// NoiseLookbackBars: Bars covering the measurement
input int    NoiseLookbackBars          = 40;   // Noise lookback bars
// NoiseReachHorizonBars: Bars a basket normally has to reach its target - used to judge reachability
input int    NoiseReachHorizonBars      = 40;   // Noise reach horizon bars
// NoiseCautionLevel: Noise above which the entry is penalised
input double NoiseCautionLevel          = 0.82;   // Noise caution level
// NoiseBlockLevel: Noise above which entries are refused - at this level price is not travelling anywhere
input double NoiseBlockLevel            = 0.90;   // Noise block level
// NoiseMinReachability: Expected travel as a fraction of the target; below this the target is not realistically reachable
input double NoiseMinReachability       = 0.55;   // Noise min reachability
// NoiseCautionPenalty: Penalty for entering into churn
input int    NoiseCautionPenalty        = 2;   // Noise caution penalty
// NoiseMinTPFactor: V162b: floor on how far the target may be scaled down in churn. Below this the trade is not worth its spread.
input double NoiseMinTPFactor           = 0.50;   // Noise min TP factor
// NoisePrintOnUse: Log noise readings that change a decision
input bool   NoisePrintOnUse            = true;   // Noise print on use (on/off)
// ShowNoiseOnDash: Show the noise reading on the dashboard
input bool   ShowNoiseOnDash            = true;   // Show noise on dashboard

// V163: pressure. Every directional reading here is derived from RESULT - price closed higher,
// structure made a higher high. All true, all backward-looking. But each bar is a contest and the
// bar itself records who won it: a bar opening at its low and closing at its high was taken by
// buyers outright; one that spiked down and closed near its high was attempted by sellers and taken
// back. The useful case is when control and price DISAGREE - price still falling while each bar is
// defended harder is sellers running out of conviction while still nominally in charge, and that
// shows up before any close-based indicator can see it.
// EnablePressureReading: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnablePressureReading      = true;   // Enable pressure reading
// PressureTF: Timeframe the bar contest is read on
input ENUM_TIMEFRAMES PressureTF        = PERIOD_M5;   // Pressure TF
// PressureLookbackBars: Bars examined
input int    PressureLookbackBars       = 12;   // Pressure lookback bars
// PressureMinBars: Minimum readable bars before the reading is used
input int    PressureMinBars            = 6;   // Pressure min bars
// PressureBodyWeight: How much a bar counts regardless of body size (the rest scales with body share - a close at the high on a tiny body was not really won)
input double PressureBodyWeight         = 0.55;   // Pressure body weight
// PressureRecencyWeight: Extra weight per bar toward the present - control changes hands
input double PressureRecencyWeight      = 0.15;   // Pressure recency weight
// PressureMinTrend: Shift in control needed before it is treated as meaningful
input double PressureMinTrend           = 0.20;   // Pressure min trend
// PressureMinPriceMove: V170f: 800 -> 1500 ($1.50). Over twelve M5 bars price routinely travels $0.80 without meaning anything, so divergence was being declared on ordinary drift. Divergence is only interesting when price has genuinely gone one way while control went the other.
input double PressureMinPriceMove       = 1500.0;   // Pressure min price move
// PressureWithBonus: Bonus for entering with the side that holds control
input int    PressureWithBonus          = 2;   // Pressure with bonus
// PressureAgainstPenalty: Penalty for entering against it
input int    PressureAgainstPenalty     = 2;   // Pressure against penalty
// PressureDivergenceBonus: Bonus for entering with control while price still disagrees - the early reading
input int    PressureDivergenceBonus    = 3;   // Pressure divergence bonus
// PressureMinToAct: Pressure strength needed before it affects the decision
input double PressureMinToAct           = 0.25;   // Pressure min to act
// PressurePrintOnUse: Log pressure readings that change a decision
input bool   PressurePrintOnUse         = true;   // Pressure print on use (on/off)
// ShowPressureOnDash: Show the pressure reading on the dashboard
input bool   ShowPressureOnDash         = true;   // Show pressure on dashboard

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
// EnableSessionContext: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableSessionContext       = true;   // Enable session context
// SessionAsiaStartHour: 00:00 UTC - Tokyo session opens
input int    SessionAsiaStartHour       = 0;   // Session asia start hour
// SessionLondonStartHour: 08:00 UTC - London opens (07:00 UTC during British Summer Time; set to 7 from late March to late October if you want it exact)
input int    SessionLondonStartHour     = 8;   // Session london start hour
// SessionNYStartHour: 13:00 UTC - New York opens, and the London/NY overlap begins. This is the highest-volume window of the day for XAUUSD.
input int    SessionNYStartHour         = 13;   // Session NY start hour
// SessionLondonEndHour: 16:00 UTC - London closes, ending the overlap
input int    SessionLondonEndHour       = 16;   // Session london end hour
// SessionNYEndHour: 21:00 UTC - New York winds down
input int    SessionNYEndHour           = 21;   // Session NY end hour
// SessionRolloverHour: 22:00 UTC - the standard forex rollover (17:00 New York). Spreads widen sharply here and liquidity thins to almost nothing.
input int    SessionRolloverHour        = 22;   // Session rollover hour
// SessionRolloverMinutes: Width of the rollover window, centred on the hour above
input int    SessionRolloverMinutes     = 40;   // Session rollover minutes
// SessionAsiaTPFactor: Asia delivers less ground - a full-size target often is not reached
input double SessionAsiaTPFactor        = 0.75;   // Session asia TP factor
// SessionLondonTPFactor: London expands ranges
input double SessionLondonTPFactor      = 1.10;   // Session london TP factor
// SessionOverlapTPFactor: The overlap carries the day's real movement
input double SessionOverlapTPFactor     = 1.20;   // Session overlap TP factor
// SessionNYTPFactor: New York after London closes
input double SessionNYTPFactor          = 1.00;   // Session nytp factor
// SessionDeadTPFactor: Rollover moves on no participation - take what is there
input double SessionDeadTPFactor        = 0.65;   // Session dead TP factor
// SessionChangeWarnMinutes: Minutes before a session change at which current readings stop being reliable
input int    SessionChangeWarnMinutes   = 20;   // Session change warn minutes
// SessionChangePenalty: Penalty for entering right before the market changes hands
input int    SessionChangePenalty       = 2;   // Session change penalty
// SessionDeadPenalty: Penalty for entering during rollover
input int    SessionDeadPenalty         = 3;   // Session dead penalty
// SessionPrintOnUse: Log session effects on decisions
input bool   SessionPrintOnUse          = false;   // Session print on use (on/off)
// ShowSessionOnDash: Show the session and what is coming on the dashboard
input bool   ShowSessionOnDash          = true;   // Show session on dashboard

// V165: spread economics. The EA checks spread against a maximum and moves on - which answers "is
// the spread acceptable" but never "is this trade worth its cost". A $2.50 target at $0.35 spread
// gives away 14% before price does anything; at $1.00, which happens at rollover, the trade must
// travel 40% further than its target implies just to break even. The setup has not changed - the
// arithmetic has. And since widening is scheduled rather than random, it can be anticipated.
// EnableSpreadEconomics: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableSpreadEconomics      = true;   // Enable spread economics
// SpreadCountRoundTrip: Count the exit's share of the spread too - most fills give up half of it again
input bool   SpreadCountRoundTrip       = true;   // Spread count round trip (on/off)
// SpreadCostCaution: V170e: 0.18 -> 0.26. Calibrated against this account\'s actual spread. At $0.35 spread and a $2.50 target the round-trip cost is 21%, so at 0.18 EVERY normal trade was collecting this penalty - a penalty that fires on all conditions is not a filter, it is a constant. 0.26 leaves normal conditions alone and catches the genuinely expensive ones.
input double SpreadCostCaution          = 0.26;   // Spread cost caution
// SpreadCostRefuse: V170e: 0.32 -> 0.45. At 0.32 the refusal fired whenever the target was reduced - an Asian, churning session computes a $1.50 target, and $0.35 spread against it is 35%, blocking trades that were merely unremarkable rather than unprofitable. 0.45 refuses only when the spread genuinely eats the trade, which in practice means rollover and news.
input double SpreadCostRefuse           = 0.45;   // Spread cost refuse
// SpreadCostPenalty: Penalty at the caution level
input int    SpreadCostPenalty          = 4;   // Spread cost penalty
// SpreadCostHardBlock: V186: hard blok -> jazo. spread qimmat - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // Refuse trades above the refusal ratio. Unlike most blocks here this is not a judgement - the trade cannot pay for itself.
input bool   SpreadCostHardBlock        = false;   // Spread cost hard block (on/off)
// EnableSpreadForecast: Anticipate widening instead of only reacting to it
input bool   EnableSpreadForecast       = true;   // Enable spread forecast
// SpreadForecastWarnMinutes: Minutes before rollover at which a new scalp is priced under conditions its exit will not enjoy
input int    SpreadForecastWarnMinutes  = 25;   // Spread forecast warn minutes
// SpreadForecastThinSessionPoints: Spread in a thin session above which further widening is likely
input int    SpreadForecastThinSessionPoints = 450;   // Spread forecast thin session points
// SpreadForecastPenalty: Penalty for entering into expected widening
input int    SpreadForecastPenalty      = 2;   // Spread forecast penalty
// SpreadPrintOnUse: Log spread economics that change a decision
input bool   SpreadPrintOnUse           = true;   // Spread print on use (on/off)
// ShowSpreadCostOnDash: Show the cost ratio on the dashboard
input bool   ShowSpreadCostOnDash       = true;   // Show spread cost on dashboard

// V166: three gaps sharing one source - the EA looks at each basket in isolation, never at what came
// before it or what it has already paid.
// CARRY: a basket that stays open pays swap daily. The profit figure includes it, the TARGET does
// not - so a $2.50 target on a basket that has paid $3 in swap closes for a loss while reporting a
// win. STREAKS: one loss is variance, three consecutive is information. REPETITION: if the last two
// baskets both lost at the same level, the third one there is the same mistake with a new timestamp.
// EnableCarryCostAdjust: Raise the target by what the basket has already paid in swap
input bool   EnableCarryCostAdjust      = true;   // Enable carry cost adjust
// CarryCostMinProfitPoints: Profit that must remain after covering carry ($0.30) - a break-even exit is not a take-profit
input double CarryCostMinProfitPoints   = 300;   // Carry cost min profit points
// EnableStreakAwareness: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableStreakAwareness      = true;   // Enable streak awareness
// StreakCautionLosses: Consecutive losses before caution begins
input int    StreakCautionLosses        = 3;   // Streak caution losses
// StreakPenaltyPerLoss: Penalty added per loss beyond that
input int    StreakPenaltyPerLoss       = 2;   // Streak penalty per loss
// StreakMaxPenalty: Ceiling - a streak is a hint that conditions changed, not a verdict
input int    StreakMaxPenalty           = 6;   // Streak max penalty
// StreakPrintOnUse: Log streak warnings
input bool   StreakPrintOnUse           = true;   // Streak print on use (on/off)
// EnableRepeatMistakeGuard: Notice when recent baskets already lost around this price
input bool   EnableRepeatMistakeGuard   = true;   // Enable repeat mistake guard
// RepeatMistakePoints: How close counts as "the same place" ($2.50)
input int    RepeatMistakePoints        = 2500;   // Repeat mistake points
// RepeatMistakeMinHits: Recent losing baskets near this price before it counts as repetition
input int    RepeatMistakeMinHits       = 2;   // Repeat mistake min hits
// RepeatMistakePenalty: V173: 3 -> 5. shu darajada allaqachon ikki marta yutqazilgan. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for opening where the last attempts already failed
input int    RepeatMistakePenalty       = 5;   // Repeat mistake penalty
// ShowStreakOnDash: Show streak and repetition state on the dashboard
input bool   ShowStreakOnDash           = true;   // Show streak on dashboard
// ShowEntryFunnelOnDash: V192: show how many setups were found and where they were lost. Two trades in twelve hours on a scalper is a measurable problem, and this line says which layer is responsible instead of leaving it to be guessed.
input bool   ShowEntryFunnelOnDash       = true;   // Show entry funnel on dashboard

// V194: setup arming. The EA had two answers to a warning - refuse, or take it smaller. A setup
// arriving into a strong opposing zone is neither bad nor small: it is EARLY. Arming holds the
// direction and waits for the market to answer that specific objection - price reaching the zone
// and being rejected there, a pullback completing, a level being reclaimed. Confirmed, the trade is
// taken at FULL size, because the objection was answered rather than tolerated. Unconfirmed within
// the window, it is dropped - a setup that never got its confirmation was never the trade it looked
// like. This is the difference between refusing and waiting.
// EnableSetupArming: Hold early setups and wait for confirmation instead of refusing or shrinking them
input bool   EnableSetupArming           = true;   // Enable setup arming
// SetupArmMinWaitBars: Bars before a confirmation counts - confirming on the same bar the objection appeared is noise
input int    SetupArmMinWaitBars         = 1;   // Setup arm min wait bars
// SetupArmMaxWaitBars: V198: 25 -> 10. Fallback window for anything not covered above.
input int    SetupArmMaxWaitBars         = 10;   // Setup arm max wait bars
// SetupArmRejectionWickRatio: Wick against the zone, as a share of the bar's range, that counts as the level rejecting price
input double SetupArmRejectionWickRatio  = 0.35;   // Setup arm rejection wick ratio
// EnableCounterTrendNeedsReason: FIX(counter-trend-needs-a-reason): refuse a first entry that fights a CONFIRMED global trend with no reversal consensus AND no level behind it to lean on. Everything else about the counter-trend path is unchanged - this only removes the naked case.
input bool   EnableCounterTrendNeedsReason = true;   // Enable counter trend needs reason
// CounterTrendSupportMaxDistance: How far behind ($3.50) a level can sit and still count as something this trade leans on. Mirrors CounterZoneBlockPoints, which asks the same question about what is in FRONT.
input int    CounterTrendSupportMaxDistance = 3500;   // Counter trend support max distance
// CounterTrendSupportMinStrength: Strength a single level behind must carry to justify a counter-trend entry on its own. Same bar as CounterZoneBlockMinStrength - a shelf can qualify instead, via the cluster test.
input double CounterTrendSupportMinStrength = 1.4;   // Counter trend support min strength
// CounterTrendExceptionalMinScore: V249fix(auto-mode): the ABSOLUTE quality floor for the tier-C release, applied alongside the relative margin below. Needed because AUTO switches the bar itself: MinScoreHighHunter is 2 and MinScoreBalanced is 4, and Hunter additionally collects a +1 mode bonus - so a purely relative margin released the counter-trend guard at a MUCH lower absolute score in Hunter, i.e. the MORE aggressive mode got the WEAKER protection. With a floor of 8 both modes demand the same real quality; the relative term still applies if you raise a MinScore well above it.
input int    CounterTrendExceptionalMinScore = 8;   // Counter trend exceptional min score
// CounterTrendExceptionalMargin: V249fix: 6 -> 3. At 6 this release was DEAD: G_SCORE_MIN_REQUIRED is typically 5 (MinScoreBalanced 4 + the reversal-type extra), so it demanded a final of 11 - and in exactly the conditions this tier fires, the trend-conflict penalties have already driven the total to the 12 cap, so final tracks base and a typical live reading is 9. At 3 the bar is 8 and a genuinely strong setup gets through, which is the whole point. Release valve: a counter-trend setup with nothing behind it is STILL allowed if its final score clears the required bar by this much AFTER the HTF penalty. V189 refused a live A+ setup scoring 11 against a bar of 4 and that was wrong - this is what stops that happening again. Lower = stricter.
input int    CounterTrendExceptionalMargin  = 3;   // Counter trend exceptional margin
// CounterTrendMaxLadderOrders: Ladder depth cap for an entry against a confirmed global trend. Being wrong on this bet means the grid is averaging INTO a running trend - the single most dangerous state for a martingale, per the EA's own note. Refuses no trades; it only limits how much a wrong one can cost. 0 = no cap.
input int    CounterTrendMaxLadderOrders    = 3;   // Counter trend max ladder orders
// CounterTrendPrintOnUse: Log every counter-trend decision (tier B allowed / tier C refused) - this is the data you need to tune the two thresholds above from a real session rather than a guess.
input bool   CounterTrendPrintOnUse        = true;   // Counter trend print on use (on/off)
// EnableCounterZoneCluster: FIX(counter-zone-single-level): treat a SHELF of several ordinary opposing levels as a wall, not only a single strong one. This is the guard against "sell at support / buy at resistance" when the nearest level alone looks weak.
input bool   EnableCounterZoneCluster   = true;   // Enable counter zone cluster
// CounterZoneClusterMinLevels: How many DISTINCT opposing levels inside CounterZoneBlockPoints make a shelf. Levels closer together than ZoneNextLevelGapPoints count once.
input int    CounterZoneClusterMinLevels = 3;   // Counter zone cluster min levels
// CounterZoneClusterMinLevelStrength: Minimum strength for a level to COUNT as a shelf member. Below the single-wall floor (CounterZoneBlockMinStrength 1.4) - the point of the shelf test is that no single member has to clear that - but above the 1.0 untested baseline, so a row of raw wicks is not a wall. Without this floor the test degenerates into "are there 3 swing points within $3.50", which is true almost always, in both directions at once.
input double CounterZoneClusterMinLevelStrength = 1.25;   // Counter zone cluster min level strength
// CounterZoneClusterMinSum: Total confirmation the shelf must carry, summed as (strength - 1.0) per level - so a row of untested single wicks sums to zero and cannot block. 0.9 ~= three levels each with roughly one confirming retouch.
input double CounterZoneClusterMinSum   = 0.9;   // Counter zone cluster min sum
// CounterZoneReArmCooldownBars: FIX(counter-zone-rearm-loop): after a counter-zone wait expires unanswered, do not start another one for this many bars. Stops the arm engine holding a setup forever against a wall price never clears; during the cooldown the block falls through to CounterZoneHardBlock / the score penalty, which is the documented design.
input int    CounterZoneReArmCooldownBars = 20;   // Counter zone re arm cooldown bars
// SetupArmWallClearPoints: FIX(arm-wall-geometry): how far past the opposing wall ($0.20) price must CLOSE before a counter-zone objection counts as answered. A wall is cleared, not bounced off - see the ARM_REASON_ZONE confirm branch.
input int    SetupArmWallClearPoints    = 200;   // Setup arm wall clear points
// SetupArmPullbackPoints: Pullback depth ($0.60) that answers an overextended move
input int    SetupArmPullbackPoints      = 600;   // Setup arm pullback points
// SetupArmScoreBonus: Bonus when a confirmation arrives - the objection was answered, which is worth more than it never having been raised
input int    SetupArmScoreBonus          = 3;   // Setup arm score bonus
// SetupArmPrintOnUse: Log arming, confirmation and expiry
input bool   SetupArmPrintOnUse          = true;   // Setup arm print on use (on/off)
// ShowSetupArmOnDash: Show the armed setup and what it is waiting for
input bool   ShowSetupArmOnDash          = true;   // Show setup arm on dashboard
// EnableZoneEdgeArming: V195: wait for the zone's reaction edge instead of penalising an early fill. The edge is a price - patience reaches it, a penalty only records that it was missed.
input bool   EnableZoneEdgeArming        = true;   // Enable zone edge arming
// EnableLiquidityArming: V195: wait for a stop pool to be taken rather than entering into it. The move after a sweep is cleaner than the one that walks into it.
input bool   EnableLiquidityArming       = true;   // Enable liquidity arming

// V196: independent confirmation for the wait. Waiting on price alone is one opinion and a late
// one - price reaching a level says the market got there, not that it turned. Pressure, chain and
// pattern memory read intent directly and see a turn beginning before it prints. Two agreeing ends
// the wait on its own; all three disagreeing ends it the other way, since a setup the market has
// moved away from will not be rescued by waiting out the window.
// EnableArmConsensus: Let pressure, chain and history confirm or cancel a wait, alongside the price test
input bool   EnableArmConsensus          = true;   // Enable arm consensus
// EnableSpreadArming: V196: wait for a wide spread to narrow rather than paying a penalty for it. Spreads always narrow - this is the objection most certain to resolve itself.
input bool   EnableSpreadArming          = true;   // Enable spread arming

// V197: waits are now checked while they run and measured after they finish.
// Each objection resolves on its own timescale, so one window for all of them was either too short
// for pullbacks or too generous for spreads.
// SetupArmZoneWaitBars: V198: 20 -> 8. On M1 that was twenty minutes of holding, on an EA whose trades resolve in ten to twenty. A wait that outlasts the trade it is waiting for is not patience - it is the EA sitting out the session. If the zone has not rejected price within eight bars, it is not defending that level today.
input int    SetupArmZoneWaitBars        = 8;   // Setup arm zone wait bars
// SetupArmPullbackWaitBars: V198: 35 -> 15. Still the longest of the three, because a pullback genuinely takes longer to form - but thirty-five minutes on a scalper meant one held setup could cost an entire session of other opportunities.
input int    SetupArmPullbackWaitBars    = 15;   // Setup arm pullback wait bars
// SetupArmStructureWaitBars: V198: 12 -> 5. Spreads narrow within a few bars or they are not narrowing; a reclaim either happens on the next candles or the level held. Neither needs twelve minutes to answer.
input int    SetupArmStructureWaitBars   = 5;   // Setup arm structure wait bars
// SetupArmFillWaitBars: V275: bars held for a better price. Short by design - the objection is a few points, not a condition that has to resolve, and a setup held too long for a better entry becomes a setup missed for one.
input int    SetupArmFillWaitBars        = 3;   // Setup arm fill wait bars
// SetupArmLateWaitBars: V288: bars held for a pullback. Longer than a fill hold - a retrace takes time to arrive, and the setup behind it is structural rather than momentary.
input int    SetupArmLateWaitBars        = 10;   // Setup arm late wait bars
// EnableArmValidityCheck: Check the setup is still there while waiting. Waiting was never the goal - it was a way to get the same trade at a better moment, and that trade can disappear mid-wait.
input bool   EnableArmValidityCheck      = true;   // Enable arm validity check
// ArmAbandonDistancePoints: Distance from the level ($4.00) at which the wait is abandoned - price has left the area, so the reaction cannot happen there
input int    ArmAbandonDistancePoints    = 4000;   // Arm abandon distance points
// ArmAbandonOnSessionChange: Abandon when the session hands over. The participants who would have produced the expected reaction are no longer the ones trading.
input bool   ArmAbandonOnSessionChange   = true;   // Arm abandon on session change (on/off)
// EnableArmAudit: Measure whether waiting works. Without this the next round of tuning is guesswork - which is what produced a day of blind adjustments.
input bool   EnableArmAudit              = true;   // Enable arm audit
// ArmAuditHorizonBars: Bars after a confirmed entry before judging what the wait produced
input int    ArmAuditHorizonBars         = 20;   // Arm audit horizon bars
// ArmAuditWinPoints: Move in favour ($0.80) that counts the wait as having paid off
input int    ArmAuditWinPoints           = 800;   // Arm audit win points
// ArmAuditPrintOnUse: Log each verdict
input bool   ArmAuditPrintOnUse          = true;   // Arm audit print on use (on/off)
// ShowArmAuditOnDash: Show the wait statistics on the dashboard
input bool   ShowArmAuditOnDash          = true;   // Show arm audit on dashboard

// V199: after a winning basket the same direction enters without waiting. Taking profit IS the
// confirmation - the EA read the direction correctly and the market paid for it - and demanding a
// fresh one minutes later turns the EA's own success into a reason for hesitation. Worse, the move
// that produced the profit is usually still running, which trips the overextension check and holds
// the EA out of the very continuation it just proved.
// EnablePostWinFastEntry: Skip the wait for the direction of a recently profitable basket
input bool   EnablePostWinFastEntry      = true;   // Enable post win fast entry
// PostWinFastEntryBars: Bars after a winning close during which that direction still counts as confirmed
input int    PostWinFastEntryBars        = 20;   // Post win fast entry bars
// ArmConsensusMinAgree: Sources that must agree for the wait to complete on their own
input int    ArmConsensusMinAgree        = 2;   // Arm consensus min agree
// ArmConsensusMinAgainst: Sources pointing the other way before the setup is dropped early - unanimous, because cancelling a valid wait is the more expensive mistake
input int    ArmConsensusMinAgainst      = 3;   // Arm consensus min against

// V167: zone edges. Everything here treats a zone as one price; on a chart it is a region, and where
// inside it price reacts is not arbitrary. The OUTER edge is the extreme - where stops sit and where
// a sweep wicks to. The INNER edge is where the orders rest - the price the zone has actually been
// defended from. Price routinely trades through the outer edge and turns at the inner one, and on
// XAUUSD that gap is often a dollar: on a $2.50 target, the difference between a scalp that works
// and one that opens straight into drawdown. The two answer different questions - risk measures to
// the outer edge because price can reach it, entries aim at the inner edge because that is where the
// turn happens.
// EnableZoneEdges: Resolve a zone into its reaction edge and its reach edge instead of one price
input bool   EnableZoneEdges            = true;   // Enable zone edges
// ZoneEdgeTF: Timeframe the zone's member swings are read on
input ENUM_TIMEFRAMES ZoneEdgeTF        = PERIOD_M15;   // Zone edge TF
// ZoneEdgeGatherPoints: How far around the level to gather swings belonging to the same zone ($1.80, adjusted by market scale)
input int    ZoneEdgeGatherPoints       = 1800;   // Zone edge gather points
// ZoneEdgeMinSwings: Swings needed before a zone has a meaningful shape rather than a single point
input int    ZoneEdgeMinSwings          = 3;   // Zone edge min swings
// ZoneEdgeMinGapPoints: Gap between the edges below which the distinction does not matter ($0.40)
input int    ZoneEdgeMinGapPoints       = 400;   // Zone edge min gap points
// ZoneEdgeEarlyEntryPenalty: V173: 2 -> 4. reaksiya nuqtasiga yetmagan - darrov DD. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering at the reach edge when the reaction edge is still ahead - the fill is early and drawdown is immediate
input int    ZoneEdgeEarlyEntryPenalty  = 4;   // Zone edge early entry penalty
// ZoneEdgePrintOnUse: Log edge resolution that changes a decision
input bool   ZoneEdgePrintOnUse         = true;   // Zone edge print on use (on/off)
// ShowZoneEdgesOnDash: V170d: default OFF. zona chekkalari - jurnalда batafsilroq. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowZoneEdgesOnDash        = false;   // Show zone edges on dashboard

// V169: four small gaps. None changes how a trade is chosen; all answer questions the EA currently
// cannot. EXIT QUALITY - it knows whether it hit its target, not what happened next; if price keeps
// running after almost every exit the target is too small. SLIPPAGE - a persistent $0.10 on a $2.50
// target is 4% of every trade, paid twice, and unmeasured it just looks like underperformance.
// DAILY STATE - most systems give back the day's gains in the last hour. RENTAL SPREAD - fifty
// copies firing on the same signal in the same second compete for the same liquidity.
// EnableExitQuality: Watch where price goes after a basket closes, to find out whether the target is the right size
input bool   EnableExitQuality          = true;   // Enable exit quality
// ExitQualityHorizonBars: Bars watched after the close
input int    ExitQualityHorizonBars     = 20;   // Exit quality horizon bars
// ExitQualityRunOnPoints: Move after the exit that counts as decisive either way ($0.80)
input int    ExitQualityRunOnPoints     = 800;   // Exit quality run on points
// ExitQualityTargetTooSmall: Share of exits followed by more movement above which the target is probably too small
input double ExitQualityTargetTooSmall  = 0.65;   // Exit quality target too small
// ExitQualityMaxSamples: Sample ceiling
input int    ExitQualityMaxSamples      = 60;   // Exit quality max samples
// ExitQualityPrintOnUse: Log each post-exit verdict
input bool   ExitQualityPrintOnUse      = true;   // Exit quality print on use (on/off)
// EnableSlippageTracking: Measure the gap between the price asked for and the price received
input bool   EnableSlippageTracking     = true;   // Enable slippage tracking
// SlippageMaxSamples: Sample ceiling
input int    SlippageMaxSamples         = 100;   // Slippage max samples
// EnableDailyState: Be harder to convince once the day is already good, and after a bad one
input bool   EnableDailyState           = true;   // Enable daily state
// DailyGoodDayPercent: Daily gain above which protecting the day matters more than adding to it
input double DailyGoodDayPercent        = 2.0;   // Daily good day %
// DailyGoodDayScoreOffset: Extra score demanded on a good day
input int    DailyGoodDayScoreOffset    = 2;   // Daily good day score offset
// DailyBadDayPercent: Daily loss below which the EA stops trying to trade its way back
input double DailyBadDayPercent         = 2.5;   // Daily bad day %
// DailyBadDayScoreOffset: Extra score demanded after a bad day
input int    DailyBadDayScoreOffset     = 3;   // Daily bad day score offset
// EnableRentalSpread: Stagger entries across rented copies so they do not compete for the same fill
input bool   EnableRentalSpread         = true;   // Enable rental spread
// RentalSpreadMaxTicks: V187: 4 -> 2. Ijara nusxalarini ajratish uchun yetarli, lekin har entryga qo\'shiladigan kechikishni yarmiga qisqartiradi.
input int    RentalSpreadMaxTicks       = 2;   // Rental spread max ticks
// ShowDiagnosticsOnDash: V170d: default OFF. chiqish sifati va slippage - haftalik ko'rib chiqish uchun. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool   ShowDiagnosticsOnDash      = false;   // Show diagnostics on dashboard

// V170: the conditional target adjustments (session, regime, noise, health) are combined into one
// factor before any limit is applied. Applied one at a time they were wrong in both directions:
// downward each step clamped at the minimum, so the first factor to reach the floor silenced every
// one after it; upward there was no clamp at all, so an overlap trending market produced a $3.75
// target on a scalper configured for $2.50. These bounds keep the combined result inside what this
// strategy can actually work with.
// TPFactorMin: Smallest the combined target adjustment may be. Below this the trade stops clearing its own spread.
input double TPFactorMin                = 0.60;   // TP factor min
// TPFactorMax: Largest. A scalper that starts holding for $4 is no longer the strategy that was tested.
input double TPFactorMax                = 1.35;   // TP factor max
// TPAdjustPrintOnUse: Log meaningful target adjustments
input bool   TPAdjustPrintOnUse         = true;   // TP adjust print on use (on/off)
// EntryLotFactorMin: V175: 0.65 -> 0.80 on request. The floor under the COMBINED entry adjustment. Below 80% the grid progression behind it stops matching the settings - every rung multiplies from the first, so a 65% first entry makes the whole recovery ladder 35% weaker than the numbers say.
input double EntryLotFactorMin          = 0.80;   // Entry lot factor min
// EntryLotAbsoluteFloor: V175: the entry lot never falls below this fraction of StartLot, whatever the adjustments decide. Applied LAST, after conviction scaling, ladder-fit scaling and the scale-in split - each is bounded on its own, but they multiply, and 0.80 x 0.80 is 0.64. This is the figure that holds.
input double EntryLotAbsoluteFloor      = 0.80;   // Entry lot absolute floor

// V182: the modules shape the SIZE of a trade rather than veto it. Twenty analytical modules were
// each given the power to refuse an entry, and together they cut a high-frequency scalper down to a
// couple of trades a day - the reasoning was sound but the mechanism was wrong. A warning is not a
// reason to stand aside; it is a reason to commit less and ask for less. The setup still trades.
// EnableWarningLotScaling: Let accumulated warnings reduce the entry size instead of refusing the entry
input bool   EnableWarningLotScaling    = true;   // Enable warning lot scaling
// WarningLotFullPenalty: Warning weight at which sizing reaches its floor. Below this it scales proportionally - four points of caution trims a little, twelve trims to the floor.
input int    WarningLotFullPenalty      = 14;   // Warning lot full penalty
// WarningLotMinFactor: Smallest size a heavily-warned setup will take, as a fraction of the intended lot
input double WarningLotMinFactor        = 0.55;   // Warning lot min factor
// EnableWarningTPScaling: Let the same weight shorten the target
input bool   EnableWarningTPScaling     = true;   // Enable warning TP scaling
// WarningTPMinFactor: Smallest target multiplier from warnings - a doubtful trade should be asked for less, not sent out for the same move with less behind it
input double WarningTPMinFactor         = 0.70;   // Warning TP min factor
// ZoneStrengthTPBufferScale: How much zone strength widens the TP-cap buffer (0=no effect)
input double ZoneStrengthTPBufferScale      = 0.6;   // Zone strength TP buffer scale
// ZoneStrengthLotTrimScale: How much zone strength deepens the momentum-caution lot cut
input double ZoneStrengthLotTrimScale       = 0.5;   // Zone strength lot trim scale

input group "ADVANCED ▸ Liquidity vacuum (fair value gap)"
// EnableFVGZones: Unfilled 3-candle price gaps act as extra magnet zones
input bool             EnableFVGZones        = true;   // Enable FVG zones
input ENUM_TIMEFRAMES  FVGTimeframe          = PERIOD_M15;   // FVG timeframe
input int              FVGLookbackBars       = 100;   // FVG lookback bars
// FVGMinGapPoints: Ignore gaps smaller than this - not significant
input int              FVGMinGapPoints       = 150;   // FVG min gap points
input bool             FVGPrintOnUse         = false;   // FVG print on use (on/off)

input group "ADVANCED ▸ Order flow (tick volume)"
// EnableOrderFlow: MT5 has no real order flow, this is a tick-volume-based proxy
input bool   EnableOrderFlow           = true;   // Enable order flow
// OrderFlowLookbackBars: Bars used to compute the average volume baseline
input int    OrderFlowLookbackBars     = 20;   // Order flow lookback bars
// OrderFlowHighMultiplier: Volume >= avg*this counts as a confirmed/strong move
input double OrderFlowHighMultiplier   = 1.3;   // Order flow high multiplier
// OrderFlowLowMultiplier: Volume <= avg*this counts as a weak/suspicious move
input double OrderFlowLowMultiplier    = 0.7;   // Order flow low multiplier
// OrderFlowWeakBOSPenalty: Extra penalty on a fresh BOS break with weak (low-volume) conviction
input int    OrderFlowWeakBOSPenalty   = 1;   // Order flow weak BOS penalty
// OrderFlowStrongBOSBonus: Extra bonus on a fresh BOS break with strong (high-volume) conviction
input int    OrderFlowStrongBOSBonus   = 1;   // Order flow strong BOS bonus

input group "ADVANCED ▸ DXY proxy (synthetic dollar index)"
// EnableDXYProxy: No real DXY on most Cent accounts - built from 3 major pairs instead
input bool             EnableDXYProxy            = true;   // Enable DXY proxy
input string           DXYProxyPair1             = "EURUSD";   // DXY proxy pair 1
input string           DXYProxyPair2             = "GBPUSD";   // DXY proxy pair 2
input string           DXYProxyPair3             = "USDJPY";   // DXY proxy pair 3
input ENUM_TIMEFRAMES  DXYProxyTF                = PERIOD_H1;   // DXY proxy TF
// DXYProxyLookbackBars: Bars back used to measure the proxy's slope
input int              DXYProxyLookbackBars      = 20;   // DXY proxy lookback bars
// DXYProxyMinSlopePercent: Minimum % change over the lookback to call it a clear direction
input double           DXYProxyMinSlopePercent   = 0.15;   // DXY proxy min slope %
// DXYProxyInverseRelationship: true = USD-quote symbols like XAUUSD/EURUSD (higher DXY -> lower price)
input bool             DXYProxyInverseRelationship = true;   // DXY proxy inverse relationship (on/off)
// DXYProxyLotFactor: Lot multiplier when the entry goes against the dollar proxy trend
input double           DXYProxyLotFactor         = 0.6;   // DXY proxy lot factor
input bool             DXYProxyPrintOnUse        = true;   // DXY proxy print on use (on/off)

input group "ADVANCED ▸ Broker holiday calendar"
input bool   EnableBrokerHolidayCalendar     = true;   // Enable broker holiday calendar
// BrokerHolidayDates: comma-separated YYYY.MM.DD
input string BrokerHolidayDates              = "2026.12.25,2026.12.31,2027.01.01";   // Broker holiday dates
input int    BrokerHolidayCautionDaysBefore  = 1;   // Broker holiday caution days before
input int    BrokerHolidayCautionDaysAfter   = 1;   // Broker holiday caution days after
// BrokerHolidayHardBlockOnDay: default OFF - caution (lot cut) instead of a hard block
input bool   BrokerHolidayHardBlockOnDay     = false;   // Broker holiday hard block on day (on/off)
input double BrokerHolidayLotFactor          = 0.5;   // Broker holiday lot factor
input bool   BrokerHolidayPrintOnUse         = true;   // Broker holiday print on use (on/off)

input group "ADVANCED ▸ Laddered partial close (2-stage)"
// EnableLadderedPartialClose: V62b: OFF for the same reason as EnableSmartPartialClose - a second trim stage only compounds the average-price distortion described there. (No effect anyway while Smart Partial Close is off, but set false so re-enabling one does not silently pull in the other.)
input bool   EnableLadderedPartialClose = false;   // Enable laddered partial close
// LadderStage2ProfitPoints: 2nd trim trigger, further out than stage 1 (PartialCloseAtProfitPoints)
input int    LadderStage2ProfitPoints   = 3000;   // Ladder stage 2 profit points
// LadderStage2Percent: % of each position's REMAINING volume closed at stage 2
input double LadderStage2Percent        = 30.0;   // Ladder stage 2 %

input group "ADVANCED ▸ AUTO-flat before major news"
// EnableNewsAutoFlat: Fully close the basket ahead of a high-impact calendar event
input bool   EnableNewsAutoFlat         = true;   // Enable news auto flat
// NewsAutoFlatMinutesBefore: How many minutes before the event to close
input int    NewsAutoFlatMinutesBefore  = 15;   // News auto flat minutes before
// NewsAutoFlatOnlyIfProfit: Only close if the basket is currently in profit
input bool   NewsAutoFlatOnlyIfProfit   = true;   // News auto flat only if profit (on/off)
input bool   NewsAutoFlatPrintOnUse     = true;   // News auto flat print on use (on/off)

input group "ADVANCED ▸ Correlation instability"
// EnableCorrelationInstability: Extra caution when a pair's correlation itself is unreliable
input bool   EnableCorrelationInstability     = true;   // Enable correlation instability
input int    CorrelationShortWindowBars       = 50;   // Correlation short window bars
input int    CorrelationLongWindowBars        = 200;   // Correlation long window bars
// CorrelationInstabilityThreshold: |short-term corr - long-term corr| beyond this = unstable
input double CorrelationInstabilityThreshold  = 0.35;   // Correlation instability threshold
// CorrelationInstabilityLotFactor: Extra lot cut applied on top of the normal correlation cut
input double CorrelationInstabilityLotFactor  = 0.7;   // Correlation instability lot factor
input bool   CorrelationInstabilityPrintOnUse = false;   // Correlation instability print on use (on/off)

input group "ADVANCED ▸ Market confidence score (volatility + bayes + hurst)"
// EnableConfidenceScore: Combines 3 independent signals into ONE final lot multiplier
input bool   EnableConfidenceScore        = true;   // Enable confidence score
input ENUM_TIMEFRAMES ConfidenceATRTF     = PERIOD_H1;   // Confidence atrtf
input int    VolRegimeATRPeriod           = 14;   // Volume regime ATR period
// VolRegimeLookbackBars: Bars of ATR history used to rank the current ATR's percentile
input int    VolRegimeLookbackBars        = 100;   // Volume regime lookback bars
// VolRegimeHighPercentile: Above this percentile = storm (caution)
input double VolRegimeHighPercentile      = 85.0;   // Volume regime high percentile
// VolRegimeLowPercentile: Below this percentile = too thin/dead (mild caution)
input double VolRegimeLowPercentile       = 15.0;   // Volume regime low percentile
// EnableVolRegimeContinuous: V31.6z58: this function computed a real continuous percentile then collapsed it into 3 fixed values - the 85th and 99th percentile both scored identically, so "edge of a storm" and "deep inside one" were indistinguishable
input bool   EnableVolRegimeContinuous    = true;   // Enable volume regime continuous
// BayesMinSamples: Minimum closed trades for a detector before trusting its win-rate
input int    BayesMinSamples              = 8;   // Bayes min samples
// EnableBayesShrinkage: V31.6z48: real statistical weakness fixed - sample count used to be a pure on/off gate (10 samples at 70% trusted exactly as much as 200 at 70%). Shrinkage pulls the observed rate toward the 0.5 prior in proportion to how little evidence backs it.
input bool   EnableBayesShrinkage         = true;   // Enable bayes shrinkage
// BayesShrinkageStrength: Equivalent "virtual samples" of the 0.5 prior - higher = more conservative, needs more real evidence to move away from neutral
input double BayesShrinkageStrength       = 10.0;   // Bayes shrinkage strength
// BayesMaxSampleWindow: Rolling window size (older outcomes decay out)
input int    BayesMaxSampleWindow         = 30;   // Bayes max sample window
input int    HurstLookbackBars            = 100;   // Hurst lookback bars
input int    HurstMinChunkSize            = 8;   // Hurst min chunk size
input double ConfidenceMinLotMultiplier   = 0.6;   // Confidence min lot multiplier
// ConfidenceMaxLotMultiplier: Capped at 1.0 - never exceeds StartLot
input double ConfidenceMaxLotMultiplier   = 1.0;   // Confidence max lot multiplier
input bool   ConfidencePrintOnUse         = false;   // Confidence print on use (on/off)

input group "ADVANCED ▸ Smart zone recovery (trend-block exception)"
// EnableSmartZoneRecovery: Allow ONE reduced-lot recovery add at a strong wall while trend-block is active
input bool   EnableSmartZoneRecovery      = true;   // Enable smart zone recovery
// SZRMinZoneStrength: Wall must be at least this strong (ZoneMapStrength)
input double SZRMinZoneStrength           = 1.3;   // SZR min zone strength
// SZRZoneProximityPoints: Price must be within this many points of the wall (near side)
input int    SZRZoneProximityPoints       = 500;   // SZR zone proximity points
// SZRMaxBeyondZonePoints: If price has broken past the wall by more than this, the wall failed - no add
input int    SZRMaxBeyondZonePoints       = 250;   // SZR max beyond zone points
// SZRMaxUsesPerEpisode: V54b: replaces the old hard one-shot. How many smart rescue adds may fire during ONE continuous trend-block episode. The one-shot existed so SZR could not override the counter-trend block on every single grid step; a small cap keeps that protection while allowing more than a single rescue, as requested. Set 0 for uncapped (SZR then overrides the trend block on every step its zone/rejection/order-flow conditions pass - the riskiest setting).
input int    SZRMaxUsesPerEpisode         = 3;   // SZR max uses per episode
// SZRRequireRejectionCandle: Last closed M15 candle must have poked the wall and closed back on our side
input bool   SZRRequireRejectionCandle    = true;   // SZR require rejection candle (on/off)
// SZRUseOrderFlowVeto: Strong tick-volume conviction INTO the wall (likely breakout) vetoes the add
input bool   SZRUseOrderFlowVeto          = true;   // SZR use order flow veto (on/off)
// SZRLotFactor: V54b: raised 0.5 -> 1.0 on user request. A rescue add now uses the FULL normal next grid lot (which already carries the 1.30 martingale multiplier) instead of half of it. Rationale from the user: a half-size add takes new risk while barely improving the basket average, so it should either be a proper-sized add or no add at all. Set below 1.0 again if you want smaller, more cautious rescue adds.
input double SZRLotFactor                 = 1.0;   // SZR lot factor
// EnableSZREscapeMode: OFF - SZR adds exit via normal trailing/TP, not a fast release
input bool   EnableSZREscapeMode         = false;   // Enable SZR escape mode
// SZREscapePlusPoints: Escape target: basket profit points that triggers the fast release
input int    SZREscapePlusPoints         = 300;   // SZR escape plus points
input bool   SZRPrintOnUse                = true;   // SZR print on use (on/off)

input group "ADVANCED ▸ Hunter intelligence upgrade"
// EnableHunterD1Filter: Hunter's lower score threshold only applies WITH the D1 trend
input bool   EnableHunterD1Filter        = true;   // Enable hunter D1 filter
// HunterD1LookbackDays: D1 bars back to compare for overall direction
input int    HunterD1LookbackDays        = 10;   // Hunter D1 lookback days
input bool   HunterD1PrintOnUse          = true;   // Hunter D1 print on use (on/off)
// EnableHunterVelocitySense: Give a small score bonus when a live tick-velocity spike agrees with the signal direction (pre-candle-close impulse sensing)
input bool   EnableHunterVelocitySense   = true;   // Enable hunter velocity sense
input int    HunterVelocitySenseBonus    = 1;   // Hunter velocity sense bonus

input group "ADVANCED ▸ Robot eyes sharpening (sweep + fake breakout return)"
// EnableZoneAwareSweep: Sweep level prefers a real, swing-confirmed Zone Map wall over a raw recent low/high
input bool   EnableZoneAwareSweep        = true;   // Enable zone aware sweep
// EnableSweepVolumeCheck: Strong tick-volume on the sweep+rejection candle adds confidence (bonus, never a block)
input bool   EnableSweepVolumeCheck      = true;   // Enable sweep volume check
// EnableFakeBreakoutReturn: NEW detector: price broke a real wall, failed to hold, closed back on the original side
input bool   EnableFakeBreakoutReturn    = true;   // Enable fake breakout return

// V147: trap quality. A failed breakout is the best setup on the chart - but only when it actually
// trapped someone. The detector above fires on any wick that pokes through a level and returns,
// which is most wicks: nobody was positioned there, so nobody has to get out, and the "reversal"
// has no fuel. A real trap broke deep enough to look genuine, HELD on the far side long enough for
// traders to enter, and then snapped back - that snap is those traders being forced out.
// EnableTrapQuality: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableTrapQuality           = true;   // Enable trap quality
// TrapQualityLookbackBars: Bars examined for the break and its failure
input int    TrapQualityLookbackBars     = 10;   // Trap quality lookback bars
// TrapQualityFullDepthATR: Penetration (in ATR) that counts as a fully convincing break
input double TrapQualityFullDepthATR     = 1.2;   // Trap quality full depth ATR
// TrapQualityFullHoldBars: Bars CLOSING beyond the level that count as fully convincing persistence
input int    TrapQualityFullHoldBars     = 3;   // Trap quality full hold bars
// TrapWeightDepth: Weight of break depth
input double TrapWeightDepth             = 1.0;   // Trap weight depth
// TrapWeightHold: Weight of persistence - highest, because without it there was no trap, only a wick
input double TrapWeightHold              = 1.6;   // Trap weight hold
// TrapWeightSnap: Weight of the snap-back speed
input double TrapWeightSnap              = 1.2;   // Trap weight snap
// TrapQualityMinToTrade: Below this the "failed breakout" is noise and the setup is rejected outright
input double TrapQualityMinToTrade       = 0.35;   // Trap quality min to trade
// TrapQualityWeakPenalty: V188: score cost of a failed-breakout that shows little evidence it trapped anyone. Previously this rejected the setup before scoring - which contradicted the design: every other warning in this EA shapes the trade instead of vetoing it, and this one should too.
input int    TrapQualityWeakPenalty      = 3;   // Trap quality weak penalty
// TrapQualityStrong: At or above this the trap is convincing enough to earn extra score
input double TrapQualityStrong           = 0.65;   // Trap quality strong
// TrapQualityBonus: Score added for a convincing trap
input int    TrapQualityBonus            = 2;   // Trap quality bonus
// FBRLookbackBars: Bars back to search for the breach
input int    FBRLookbackBars             = 6;   // Fbr lookback bars
// FBRBreachPoints: Minimum points beyond the wall to count as a genuine breach (not noise)
input int    FBRBreachPoints             = 50;   // Fbr breach points
// FBRMinZoneStrength: Wall must be at least this strong to qualify
input double FBRMinZoneStrength          = 1.2;   // Fbr min zone strength
input bool   FBRPrintOnUse               = false;   // Fbr print on use (on/off)

input group "ADVANCED ▸ Max basket exposure (scales with any account size)"
// EnableMaxBasketExposure: Hard block: total basket margin can never exceed this % of equity, whatever the account size
input bool   EnableMaxBasketExposure     = true;   // Enable max basket exposure
// (moved to group "00 - MASTER SL / DD LIMITS" at the top) MaxBasketMarginPercent
input bool   MaxBasketExposurePrintOnUse = true;   // Max basket exposure print on use (on/off)

input group "ADVANCED ▸ Session-adaptive grid distance"
// EnableSessionGridDistance: Grid steps tighter in quiet Asia hours, wider in London/NY
input bool   EnableSessionGridDistance   = true;   // Enable session grid distance
// AsiaSessionStartHour: Server time hours
input int    AsiaSessionStartHour        = 0;   // Asia session start hour
input int    AsiaSessionEndHour          = 7;   // Asia session end hour
// AsiaGridDistanceFactor: Asia session grid distance multiplier (1.0 = normal)
input double AsiaGridDistanceFactor      = 1.0;   // Asia grid distance factor
input int    LondonNYSessionStartHour    = 7;   // London NY session start hour
input int    LondonNYSessionEndHour      = 21;   // London NY session end hour
input double LondonNYGridDistanceFactor  = 1.15;   // London NY grid distance factor
input bool   SessionGridPrintOnUse       = false;   // Session grid print on use (on/off)
// EnableSessionTransitionGuard: V31.6z24 NEW: caution during the volatile first minutes after a major session opens
input bool   EnableSessionTransitionGuard = true;   // Enable session transition guard
// SessionTransitionWindowMinutes: Minutes before/after session open to treat as a transition window
input int    SessionTransitionWindowMinutes = 15;   // Session transition window minutes
// EnableAsiaTransitionGuard: Asia open is typically much calmer than London/NY - off by default
input bool   EnableAsiaTransitionGuard   = false;   // Enable asia transition guard
input int    SessionTransitionScorePenalty = 2;   // Session transition score penalty
// EnableWeekendGapGuard: V31.6z25 NEW: discourages fresh entries in the hours before Friday's close - weekend gap risk with no offsetting benefit
input bool   EnableWeekendGapGuard       = true;   // Enable weekend gap guard
// WeeklyCloseHour: Server time hour the market effectively stops trading Friday
input int    WeeklyCloseHour             = 23;   // Weekly close hour
// WeekendGapGuardWindowMinutes: How many minutes before close to start discouraging fresh entries
input int    WeekendGapGuardWindowMinutes = 120;   // Weekend gap guard window minutes
input int    WeekendGapScorePenalty      = 3;   // Weekend gap score penalty
// EnableGapDetection: V31.6z25 NEW: recognizes when the last two bars are separated by an abnormally large time gap (weekend/holiday close)
input bool   EnableGapDetection          = true;   // Enable gap detection
// GapDetectionTimeMultiplier: Bar time-gap must exceed the timeframe's normal spacing by this multiple to count as a genuine gap
input double GapDetectionTimeMultiplier  = 2.5;   // Gap detection time multiplier
// GapDetectionMinPoints: Minimum price gap size to matter for caution purposes
input double GapDetectionMinPoints       = 300;   // Gap detection min points
// GapCautionBarsAfter: How many bars after a detected gap to keep applying extra caution
input int    GapCautionBarsAfter         = 3;   // Gap caution bars after
input int    GapCautionScorePenalty      = 2;   // Gap caution score penalty

// FEATURE(gap-fill-magnet): after a large gap, price tends to drift back to fill it. Discourage
// entries that fight that drift until the gap is filled. This addresses the live case where the
// market gapped up, left a gap below, and slowly sold back down to fill it while BUY zones kept
// firing straight into the decline. 3-digit broker: 1000 points = $1.
// EnableGapFillMagnet: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool   EnableGapFillMagnet          = true;   // Enable gap fill magnet
// GapFillMagnetMinPoints: Minimum gap size to treat as a magnet (2000 = $2). Weekend XAUUSD gaps are often $2-10; small gaps are ignored.
input int    GapFillMagnetMinPoints       = 2000;   // Gap fill magnet min points
// GapFillMagnetHardBlock: V186: hard blok -> jazo. gap magnitiga qarshi - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.    // true = hard-block a first entry against the pull; false = penalty only
input bool   GapFillMagnetHardBlock       = false;   // Gap fill magnet hard block (on/off)
// GapFillMagnetMaxAgeBars: V178: bars (core TF) after which an unfilled gap stops blocking - 240 M1 bars is four hours. The magnet's logic is that price is drawn back to fill the gap; when it has trended away for hours instead, that is no longer what is happening and the block is just cost.
input int    GapFillMagnetMaxAgeBars     = 240;   // Gap fill magnet max age bars
// GapFillMagnetMinBarGap: V178b: a real gap leaves a TIME hole - the bars either side sit further apart than this multiple of the timeframe. Without the test, any two adjacent minutes that jumped $2 armed the magnet, which on gold is a fast tick rather than a gap.
input int    GapFillMagnetMinBarGap      = 3;   // Gap fill magnet min bar gap
// GapFillMagnetPrintOnUse: Log when the magnet arms and expires
input bool   GapFillMagnetPrintOnUse     = true;   // Gap fill magnet print on use (on/off)
// GapFillMagnetScorePenalty: Score penalty when not hard-blocking (or for grid context)
input int    GapFillMagnetScorePenalty    = 4;   // Gap fill magnet score penalty
// GapFillMagnetFilledFraction: Gap counts as "filled" once price retraces this fraction of it back toward the fill level (0.90 = 90%)
input double GapFillMagnetFilledFraction  = 0.90;   // Gap fill magnet filled fraction
// EnableTPIntelligence: V31.6z26 NEW: dynamic TP based on Trend Quality/Exhaustion Consensus - the natural complement to Smart Trail, previously purely mechanical
input bool   EnableTPIntelligence        = true;   // Enable TP intelligence
// TPIntelligenceStrongTrendThreshold: Trend Quality Score above this extends TP
input double TPIntelligenceStrongTrendThreshold = 0.7;   // TP intelligence strong trend threshold
// TPIntelligenceExtendMultiplier: How much to extend TP when trend is genuinely strong
input double TPIntelligenceExtendMultiplier = 1.2;   // TP intelligence extend multiplier
// TPIntelligenceExhaustionThreshold: Exhaustion Consensus at/below this tightens TP
input double TPIntelligenceExhaustionThreshold = 0.3;   // TP intelligence exhaustion threshold
// TPIntelligenceTightenMultiplier: How much to tighten TP when exhaustion signs are firing
input double TPIntelligenceTightenMultiplier = 0.8;   // TP intelligence tighten multiplier

input group "ADVANCED ▸ Grid intelligence unification (senses 14-15)"
// V31.6z27: found that Adaptive Recovery Intelligence (DRI) and Market Regime Auto-Tuning
// (DRT) were separately, redundantly multiplying grid distance/lot based on similar criteria
// as Grid Intelligence - three parallel, mutually-unaware systems compounding blindly. Their
// genuinely NON-redundant signals (BOS/CHoCH, HTF direction, Top Zone Trap, DD stretch) are
// now folded into Grid Intelligence's proven 13-sense consensus as Senses 14-15, and DRI/DRT
// are disconnected from directly multiplying distance/lot (see group 123).
// (EnableStructureConfluence declared above with the other structure settings)
input bool   EnableBasketDDStretch       = true;   // Enable basket DD stretch
// GridOpposingZoneCautionPoints: V31.6z28 NEW: real bug found via live testing - Grid's Zone sense never checked the OPPOSING zone (resistance for BUY, support for SELL) at all
input int    GridOpposingZoneCautionPoints = 600;   // Grid opposing zone caution points
input double GridOpposingZoneMinStrength = 1.5;   // Grid opposing zone min strength
// EnableGridFarZoneAwareness: V31.6z29 NEW: the 600pt check alone covers <10% of an actual grid step (6500pts+) - blind to a major zone further out but still in the grid's path
input bool   EnableGridFarZoneAwareness  = true;   // Enable grid far zone awareness
// GridFarZoneCautionPoints: Roughly one grid step - covers the range the NEXT addition (or this one settling in) is likely to reach
input int    GridFarZoneCautionPoints    = 6000;   // Grid far zone caution points
// GridFarZoneMinStrength: Notably higher than the near-range bar - only genuinely MAJOR levels should matter at this distance
input double GridFarZoneMinStrength      = 2.5;   // Grid far zone min strength

input group "ADVANCED ▸ Zone / FVG quality upgrade"
// ZoneTouchMinSeparationBars: Two swing points closer than this count as ONE touch, not two independent confirmations
input int    ZoneTouchMinSeparationBars  = 5;   // Zone touch min separation bars
// ZoneAgeMinWeight: Oldest touch in the lookback window counts this fraction of a fresh one (recency-weighted)
input double ZoneAgeMinWeight            = 0.3;   // Zone age min weight
// EnableZoneAgeByProof: V265: let the touch count raise the age floor. Age discounted every touch equally, so the oldest in the window kept thirty percent of its weight regardless of quality - a shelf touched three times nine days ago counted as roughly one touch, which is how the 4305-4315 level read as a minor swing. Age is a fair proxy for relevance when nothing better exists; here something better does - a price the market returned to three separate times has been confirmed by the market, and that confirmation does not expire on the same schedule as one untested touch.
input bool   EnableZoneAgeByProof        = true;   // Enable zone age by proof
// ZoneAgeProofFullTouches: V265: touches at which the floor reaches its maximum
input int    ZoneAgeProofFullTouches     = 4;   // Zone age proof full touches
// ZoneAgeProofMaxFloor: V265: the floor a well-tested level keeps. One touch still fades to thirty percent; several holds most of its weight for as long as it stays in the window.
input double ZoneAgeProofMaxFloor        = 0.75;   // Zone age proof max floor
// EnableFVGClusterBonus: Overlapping/nearby unfilled gaps make a level stronger, not just one gap in isolation
input bool   EnableFVGClusterBonus       = true;   // Enable FVG cluster bonus
input int    FVGClusterTolerancePoints   = 150;   // FVG cluster tolerance points
input double FVGClusterStrengthWeight    = 0.3;   // FVG cluster strength weight
// EnableZoneCascade: If the nearest wall already failed, fall back to the NEXT wall further out instead of giving up
input bool   EnableZoneCascade           = true;   // Enable zone cascade

input group "ADVANCED ▸ Near-zone reaction + NY killzone caution"
// EnableNearZoneReaction: NEW detector: price approaching a real zone with an early rejection sign, before it's tested/broken
input bool   EnableNearZoneReaction      = true;   // Enable near zone reaction
// NearZoneReactionRangePoints: V75b: 300 -> 1500 ($1.5). This is how close price must be to a support/resistance for a bounce entry to register. On a 3-digit broker 300 = $0.30, far tighter than where XAUUSD actually reacts to a level ($1-2 out), so most genuine bounces were missed and price had to be almost touching the zone. $1.5 catches a real reaction while still requiring price to be at the level, not drifting near it. (Distinct from the $3.5 counter-zone BLOCK, which is about entering INTO a wall the wrong way.)// Must be within this many points of the wall, not yet at/through it
input int    NearZoneReactionRangePoints = 1500;   // Near zone reaction range points
// NearZoneReactionMinStrength: Zone strength required for a near-zone reaction signal
input double NearZoneReactionMinStrength = 1.2;   // Near zone reaction min strength
// EnableNYKillzoneCaution: Soft lot caution during typical NY-open volatility window - never blocks, any signal type
input bool   EnableNYKillzoneCaution     = true;   // Enable NY killzone caution
// NYKillzoneStartHour: Server time hours - adjust to match your broker's NY-open offset
input int    NYKillzoneStartHour         = 15;   // NY killzone start hour
input int    NYKillzoneEndHour           = 17;   // NY killzone end hour
input double NYKillzoneLotFactor         = 0.7;   // NY killzone lot factor
input bool   NYKillzonePrintOnUse        = false;   // NY killzone print on use (on/off)

input group "ADVANCED ▸ Impulse correction guard (first entry) [superseded]"
// EnableImpulseCorrectionGuard: OFF - superseded by group 77 (swing-based)
input bool   EnableImpulseCorrectionGuard      = false;   // Enable impulse correction guard
input int    ImpulseCorrectionWindowBars       = 8;   // Impulse correction window bars
input double ImpulseCorrectionMinRetracePercent = 25.0;   // Impulse correction min retrace %
input double ImpulseCorrectionLotFactor        = 0.5;   // Impulse correction lot factor
input bool   ImpulseCorrectionPrintOnUse       = true;   // Impulse correction print on use (on/off)

input group "ADVANCED ▸ Swing impulse correction (upgraded, multi-layer)"
input bool             EnableSwingImpulseCorrection = true;   // Enable swing impulse correction
input ENUM_TIMEFRAMES  SwingImpulseTF               = PERIOD_M15;   // Swing impulse TF
// SwingImpulseLookbackBars: How far back to search for the last significant swing high/low
input int               SwingImpulseLookbackBars    = 50;   // Swing impulse lookback bars
// SwingImpulseDepth: Swing confirmation depth (same convention as Zone Map)
input int               SwingImpulseDepth           = 3;   // Swing impulse depth
// SwingImpulseMinATRMultiple: The swing range must be at least this many ATRs to count as a genuine big impulse (adapts to any market condition)
input double            SwingImpulseMinATRMultiple  = 3.0;   // Swing impulse min ATR multiple
// SwingImpulseMinRetracePercent: Price must have retraced at least this % of the impulse range to call it an active correction
input double            SwingImpulseMinRetracePercent = 25.0;   // Swing impulse min retrace %
// SwingImpulseRequireMTFConfirm: Reference point must also be a real, multi-TF confirmed Zone Map level (not just local M15 noise)
input bool              SwingImpulseRequireMTFConfirm = true;   // Swing impulse require MTF confirm (on/off)
input double            SwingImpulseMTFMinStrength  = 1.5;   // Swing impulse MTF min strength
// SwingImpulseUseVolumeCheck: Heavy volume during what looks like a correction is suspicious - extra caution
input bool              SwingImpulseUseVolumeCheck  = true;   // Swing impulse use volume check (on/off)
// SwingImpulseUseZoneMatch: Price sitting at a real zone, proportional to the impulse size, strengthens the correction read
input bool              SwingImpulseUseZoneMatch    = true;   // Swing impulse use zone match (on/off)
// SwingImpulseZoneSearchFactor: Search zones within this fraction of the impulse's own range - big impulses look farther out
input double            SwingImpulseZoneSearchFactor = 0.6;   // Swing impulse zone search factor
// SwingImpulseBigDirLotFactor: Lot factor when a real zone match is found
input double            SwingImpulseBigDirLotFactor = 0.5;   // Swing impulse big dir lot factor
// SwingImpulseSmallDirLotFactor: Lot factor when no zone match, but retrace/ATR conditions still qualify
input double            SwingImpulseSmallDirLotFactor = 0.7;   // Swing impulse small dir lot factor
input bool              SwingImpulsePrintOnUse      = true;   // Swing impulse print on use (on/off)

input group "ADVANCED ▸ Trend reversal (swing sequence + RSI divergence)"
input bool              EnableTrendReversal          = true;   // Enable trend reversal
input ENUM_TIMEFRAMES   TrendReversalTF              = PERIOD_M15;   // Trend reversal TF
input int               TrendReversalLookbackBars    = 80;   // Trend reversal lookback bars
input int               TrendReversalSwingDepth      = 3;   // Trend reversal swing depth
input int               TrendReversalRSIPeriod       = 14;   // Trend reversal RSI period
// TrendReversalRequireDivergence: If true, RSI must also confirm (not just price structure) - stricter
input bool              TrendReversalRequireDivergence = false;   // Trend reversal require divergence (on/off)
// TrendReversalBonus: Score bonus when an entry aligns with a confirmed reversal
input int               TrendReversalBonus           = 2;   // Trend reversal bonus
// TrendReversalDivergenceBonus: Extra bonus when RSI divergence also confirms
input int               TrendReversalDivergenceBonus = 1;   // Trend reversal divergence bonus
// TrendReversalAgainstPenalty: V31.6s: PENALTY when a confirmed reversal points AGAINST the proposed entry - was previously only ever rewarded when it agreed, never penalized when it disagreed
input int               TrendReversalAgainstPenalty  = 2;   // Trend reversal against penalty
// TrendReversalAgainstDivergencePenalty: Extra penalty on top when RSI divergence also confirms the against-reversal
input int               TrendReversalAgainstDivergencePenalty = 2;   // Trend reversal against divergence penalty
// MTFAgainstPenaltyUnanimous: V31.6s: penalty when all 4 TF agree AGAINST entry direction
input int               MTFAgainstPenaltyUnanimous   = 6;   // MTF against penalty unanimous
// MTFAgainstPenalty3: Penalty when 3/4 TF agree against
input int               MTFAgainstPenalty3           = 4;   // MTF against penalty 3
// MTFAgainstPenalty2: Penalty when 2/4 TF agree against
input int               MTFAgainstPenalty2           = 2;   // MTF against penalty 2
// EnableTrendStrengthEntry: V31.6s: was ONLY wired into Grid Intelligence - a strong, sustained ADX-confirmed trend against a first entry had zero effect on its score until now
input bool              EnableTrendStrengthEntry     = true;   // Enable trend strength entry
// TrendStrengthEntryPenaltyMax: Penalty at maximum adverse trend strength (ADX >= TrendStrengthStrongADX)
input int               TrendStrengthEntryPenaltyMax = 4;   // Trend strength entry penalty max
input bool              TrendReversalPrintOnUse      = true;   // Trend reversal print on use (on/off)
// V31.6m cleanup: removed EnableGridReversalBlock - superseded by the continuous Grid
// Intelligence Score system (group 92), which replaced this binary block entirely.

input group "ADVANCED ▸ Multi-timeframe structure alignment"
input bool              EnableMTFAlignment           = true;   // Enable MTF alignment
input int               MTFAlignmentM15LookbackBars  = 20;   // MTF alignment M15 lookback bars
input int               MTFAlignmentH1LookbackBars   = 20;   // MTF alignment H1 lookback bars
input int               MTFAlignmentH4LookbackBars   = 20;   // MTF alignment H4 lookback bars
// MTFAlignmentBonusPerTF: Score bonus per additional timeframe that agrees with the entry direction
input int               MTFAlignmentBonusPerTF       = 1;   // MTF alignment bonus per TF
input bool              MTFAlignmentPrintOnUse       = false;   // MTF alignment print on use (on/off)

input group "ADVANCED ▸ Brain consensus (independent-evidence synergy)"
// EnableBrainConsensus: Rewards genuine agreement across INDEPENDENT evidence categories, beyond their individual score contributions
input bool              EnableBrainConsensus         = true;   // Enable brain consensus
// BrainConsensusMinCategories: Minimum independent categories agreeing before the synergy bonus applies
input int               BrainConsensusMinCategories  = 3;   // Brain consensus min categories
input int               BrainConsensusBonus          = 2;   // Brain consensus bonus
// BrainConsensusConflictPenalty: V31.6z66: NEW state - enough categories agree AND enough disagree at the same time. Previously the `else if` meant agreement won and every opposing category was silently discarded. Conflict is ambiguity, not confirmation.
input int               BrainConsensusConflictPenalty = 3;   // Brain consensus conflict penalty
input bool              BrainConsensusPrintOnUse     = true;   // Brain consensus print on use (on/off)

input group "ADVANCED ▸ Zone polarity flip"
input bool              EnableZonePolarityFlip       = true;   // Enable zone polarity flip
// PolarityFlipLookbackBars: V31.6z51: raised from 60 - on the new H1 default this reaches ~5 days, enough to actually see a major zone's break-and-flip. (Was 60 bars on M15 = only 15 hours.)
input int               PolarityFlipLookbackBars     = 120;   // Polarity flip lookback bars
// PolarityFlipMinHoldBars: Price must have held on the new side for at least this many bars
input int               PolarityFlipMinHoldBars      = 2;   // Polarity flip min hold bars
// PolarityFlipStrengthBonus: Added to ZoneMapStrength when a level shows a genuine polarity flip
input double            PolarityFlipStrengthBonus    = 0.6;   // Polarity flip strength bonus
// PolarityFlipTF: V31.6z51: was hardcoded to M15 - with the 60-bar lookback that meant it could only see 15 HOURS, so any major H4/D1 flip older than that was invisible. H1 x 120 bars now reaches ~5 days.
input ENUM_TIMEFRAMES   PolarityFlipTF               = PERIOD_H1;   // Polarity flip TF
// EnablePolarityFlipTrendWeighting: V31.6z51: a flip that agrees with the H4/D1 picture is the classic reliable structure; one against it usually fails - they were weighted identically before
input bool              EnablePolarityFlipTrendWeighting = true;   // Enable polarity flip trend weighting
// PolarityFlipTrendAlignedLevel: |Global Trend Confidence| needed to count as clearly aligned/opposed
input double            PolarityFlipTrendAlignedLevel = 0.35;   // Polarity flip trend aligned level
// PolarityFlipTrendAlignedMultiplier: Flip bonus multiplier when the flip direction agrees with the global trend
input double            PolarityFlipTrendAlignedMultiplier = 1.4;   // Polarity flip trend aligned multiplier
// PolarityFlipTrendAgainstMultiplier: Flip bonus multiplier when the flip fights the global trend
input double            PolarityFlipTrendAgainstMultiplier = 0.5;   // Polarity flip trend against multiplier

input group "ADVANCED ▸ Multi-candle pattern (exhaustion upgrade)"
input bool              EnableMultiCandlePattern     = true;   // Enable multi candle pattern
input int               MultiCandleBonus             = 1;   // Multi candle bonus

input group "ADVANCED ▸ Spread/ATR liquidity quality"
input bool              EnableSpreadATRQuality       = true;   // Enable spread ATR quality
// SpreadATRWarnRatio: Spread above this fraction of ATR = caution
input double            SpreadATRWarnRatio           = 0.15;   // Spread ATR warn ratio
input double            SpreadATRLotFactor            = 0.7;   // Spread ATR lot factor
input bool              SpreadATRPrintOnUse          = false;   // Spread ATR print on use (on/off)

input group "ADVANCED ▸ News surprise magnitude"
input bool              EnableNewsSurprise           = true;   // Enable news surprise
// NewsSurpriseMinPercent: % deviation from forecast to count as a genuine surprise
input double             NewsSurpriseMinPercent       = 20.0;   // News surprise min %
// NewsSurpriseExtraCautionMinutes: Extra caution window after a big surprise, beyond the normal pre/post window
input int               NewsSurpriseExtraCautionMinutes = 30;   // News surprise extra caution minutes
input double            NewsSurpriseLotFactor        = 0.6;   // News surprise lot factor
input bool              NewsSurprisePrintOnUse       = true;   // News surprise print on use (on/off)

input group "ADVANCED ▸ Day-of-week learning"
input bool              EnableDayOfWeekBayes         = true;   // Enable day of week bayes
input int               DayOfWeekBayesMinSamples     = 6;   // Day of week bayes min samples
input int               DayOfWeekBayesMaxWindow      = 20;   // Day of week bayes max window
input int               DayOfWeekBayesBonus          = 1;   // Day of week bayes bonus
// DayOfWeekBayesPenalty: FIX(dow-bayes-penalty): the "bad day of week" penalty used to reuse DayOfWeekBayesBonus (copy-pasted from the HourBayes pair above without its own Penalty input), so it could not be tuned independently of the bonus
input int               DayOfWeekBayesPenalty        = 1;   // Day of week bayes penalty

input group "ADVANCED ▸ Post-SL same-direction cooldown"
input bool              EnablePostSLDirectionGuard   = true;   // Enable post SL direction guard
input int               PostSLDirectionWindowBars    = 15;   // Post SL direction window bars
// PostSLDirectionExtraScoreReq: Extra score points required for a same-direction entry in the window
input int               PostSLDirectionExtraScoreReq = 3;   // Post SL direction extra score required
input double            PostSLDirectionLotFactor     = 0.6;   // Post SL direction lot factor
input bool              PostSLDirectionPrintOnUse    = true;   // Post SL direction print on use (on/off)

input group "ADVANCED ▸ Zone fatigue (rapid repeat testing)"
input bool              EnableZoneFatigue            = true;   // Enable zone fatigue
// ZoneFatigueWindowBars: Touches within this many bars of each other count as "rapid"
input int               ZoneFatigueWindowBars        = 15;   // Zone fatigue window bars
// ZoneFatigueMinRapidTouches: This many rapid touches triggers the fatigue penalty
input int               ZoneFatigueMinRapidTouches   = 2;   // Zone fatigue min rapid touches
input double            ZoneFatigueStrengthPenalty   = 0.5;   // Zone fatigue strength penalty
// EnableZoneLongTermExhaustion: V31.6z18 fix: defaulted OFF after user feedback - a zone proven strong across many weeks and timeframes should be respected MORE, not penalized. Available for those who want it, but off by default.
input bool              EnableZoneLongTermExhaustion = false;   // Enable zone long term exhaustion
// ZoneLongTermExhaustionMinTouches: Total well-separated touches (over the FULL lookback) before exhaustion caution starts
input int               ZoneLongTermExhaustionMinTouches = 4;   // Zone long term exhaustion min touches
input double            ZoneLongTermExhaustionPenaltyPerTouch = 0.15;   // Zone long term exhaustion penalty per touch
// ZoneLongTermExhaustionMaxPenalty: Capped - a heavily-tested zone still has some validity, just tempered rather than treated as ever-strengthening
input double            ZoneLongTermExhaustionMaxPenalty = 0.8;   // Zone long term exhaustion max penalty

input group "ADVANCED ▸ Per-zone historical reliability"
input bool              EnableZoneReliability        = true;   // Enable zone reliability
// ZoneReliabilityBucketPoints: Price bucket size for tracking outcomes
input double            ZoneReliabilityBucketPoints  = 500;   // Zone reliability bucket points
input int               ZoneReliabilityMinSamples    = 3;   // Zone reliability min samples
// ZoneReliabilityMaxWindow: V31.67c: raised 12 -> 30 on user request for LONGER zone memory. The bot now remembers a level's hold/break record over ~30 outcomes instead of ~12, so a zone proven strong over a long history keeps that memory instead of it decaying away after a dozen touches.
input int               ZoneReliabilityMaxWindow     = 30;   // Zone reliability max window

input group "ADVANCED ▸ DXY tester consistency"
// No new inputs - DXYProxyEnsureSymbols now checks MQL_TESTER explicitly for consistent
// backtest-vs-live behavior instead of silently depending on symbol availability.

input group "ADVANCED ▸ Broker margin level awareness"
// Independent from our own equity-DD based stops (group 00) - this tracks the BROKER'S own
// Margin Level% (Equity/Used Margin), the number that actually triggers a forced stop-out on
// their side, completely outside our control once it's reached.
input bool              EnableMarginLevelGuard       = true;   // Enable margin level guard
// MarginLevelWarnPercent: Below this - soft caution, lot trimmed
input double            MarginLevelWarnPercent       = 150.0;   // Margin level warn %
// MarginLevelDangerPercent: Below this - new grid additions blocked
input double            MarginLevelDangerPercent     = 100.0;   // Margin level danger %
input double            MarginLevelLotFactor         = 0.5;   // Margin level lot factor
input bool              MarginLevelPrintOnUse        = true;   // Margin level print on use (on/off)

input group "ADVANCED ▸ Duplicate instance protection"
// A completely different risk dimension: not market risk, but DEPLOYMENT risk. If the same
// EA (same Magic+Symbol) is accidentally attached twice on the same terminal - two chart
// windows, or forgetting one is already running - both instances would think they own the
// same basket and could send conflicting orders. Detected via a heartbeat GlobalVariable,
// shared across all EA instances on the same terminal.
input bool              EnableDuplicateInstanceGuard = true;   // Enable duplicate instance guard
input int               DuplicateInstanceHeartbeatSeconds = 5;   // Duplicate instance heartbeat seconds
input int               DuplicateInstanceStaleSeconds = 30;   // Duplicate instance stale seconds
input bool              DuplicateInstancePrintOnUse  = true;   // Duplicate instance print on use (on/off)

input group "ADVANCED ▸ Grid intelligence (sixteen-sense, continuous)"
// Grid is the primary rescue mechanism when a basket is losing - it now gets the fullest
// awareness we have: reversal confidence, zone quality + historical reliability, multi-TF
// alignment, order flow, DXY macro, volatility regime, trend strength (ADX), a forward-
// looking recovery-path zone search, major-sweep awareness, Equilibrium/Premium-Discount
// range position, engulfing pattern confirmation, recent zone break, AND impulse exhaustion
// warning (group 118) - catches deceleration in the SAME direction grid is riding, right now.
// Combined into ONE weighted 0-1 score with non-linear consensus/conflict adjustment.
input bool              EnableGridIntelligence       = true;   // Enable grid intelligence
// GridIntelligenceMinLotFactor: Lot floor at the worst (but not hard-blocked) score
input double            GridIntelligenceMinLotFactor = 0.15;   // Grid intelligence min lot factor
// GridIntelligenceNeutralLotFactor: V31.6z35 NEW: lot factor at a completely NEUTRAL score (0.5) - was collapsing to ~0.57 under the old linear formula, crushing lot sizing's informative value once combined with the rest of the chain
input double            GridIntelligenceNeutralLotFactor = 0.85;   // Grid intelligence neutral lot factor
// EnableGridIntelligenceDistance: V31.6z59: fixes a regression from the z27 unification - disconnecting DRI/DRT removed ALL condition-awareness from grid DISTANCE (lot got a replacement, distance did not), leaving it purely mechanical regardless of what the 16 senses saw
input bool              EnableGridIntelligenceDistance = true;   // Enable grid intelligence distance
// GridIntelligenceMaxDistanceWiden: Distance multiplier at the worst (but not hard-blocked) score - poor conditions mean "wait for a better price", not just "add less"
input double            GridIntelligenceMaxDistanceWiden = 1.5;   // Grid intelligence max distance widen

input group "ADVANCED ▸ MTF alignment confidence (magnitude-aware)"
// Same upgrade already applied to Global/Local Trend, found still missing here: the existing
// MTFAlignmentCount() treats a barely-positive close comparison the same as a strongly ADX-
// confirmed trend. This adds a continuous, magnitude-aware confidence used at the two most
// decision-critical points, without touching the 15+ places that use the simple count.
input bool              EnableMTFConfidence          = true;   // Enable MTF confidence
input int               MTFConfidenceADXPeriod       = 14;   // MTF confidence ADX period
input double            MTFConfidenceMinADX          = 18.0;   // MTF confidence min ADX
input double            MTFConfidenceADXFullStrength = 32.0;   // MTF confidence ADX full strength
// MTFConfidenceWeakValue: Capped confidence when ADX doesn't qualify and simple close-comparison is used instead
input double            MTFConfidenceWeakValue       = 0.30;   // MTF confidence weak value
// MTFConfidenceD1Value: D1 has no dedicated ADX check here - fixed weak-to-moderate confirmation value
input double            MTFConfidenceD1Value         = 0.40;   // MTF confidence D1 value
// MTFConfidenceStrongLevel: V31.6z47: |confidence| at/above this counts as strongly aligned/opposed for First Entry scoring
input double            MTFConfidenceStrongLevel     = 0.45;   // MTF confidence strong level
// MTFConfidenceScoreAdjust: V31.6z47: First Entry bonus/penalty magnitude - modest, since the direction-only MTF check above already contributes
input int               MTFConfidenceScoreAdjust     = 2;   // MTF confidence score adjust

input group "ADVANCED ▸ Directional clarity (both-sides-scored check)"
// V31.6z49: direct response to the user's observation that first-entry errors are a main cause
// of long drawdowns. The scanner picks the single highest scorer across all 47 detectors -
// winner takes all - so nothing downstream ever knew whether the OPPOSING direction also had a
// strong candidate at that same moment. "BUY 7 with nothing on sell" (one-sided conviction) and
// "BUY 7 but SELL 6 too" (the market telling both stories at once) were indistinguishable.
input bool              EnableDirectionalClarity     = true;   // Enable directional clarity
// DirectionalClarityMinOpposingScore: Opposing side must reach at least this to count as genuine competition (below this it's just noise)
input int               DirectionalClarityMinOpposingScore = 4;   // Directional clarity min opposing score
// DirectionalClarityMaxMargin: Margin (own - opposing) at/below which the ambiguity penalty applies at all
input int               DirectionalClarityMaxMargin  = 3;   // Directional clarity max margin
// DirectionalClarityMaxPenalty: Penalty at a dead tie (margin=0), scaling down linearly as the margin widens
input int               DirectionalClarityMaxPenalty = 4;   // Directional clarity max penalty
input bool              DirectionalClarityPrintOnUse = true;   // Directional clarity print on use (on/off)
// GridIntelligenceHardBlockBelow: Below this score, block entirely (overwhelming multi-sense agreement against)
input double            GridIntelligenceHardBlockBelow = 0.12;   // Grid intelligence hard block below
input bool              GridIntelligencePrintOnUse   = true;   // Grid intelligence print on use (on/off)
// GridIntelligenceConsensusWeight: Per-extra-sense adjustment when 3+ senses strongly agree (either direction)
input double            GridIntelligenceConsensusWeight = 0.08;   // Grid intelligence consensus weight
// GridIntelligenceConflictPenalty: Penalty when senses are genuinely split (ambiguous, dangerous ground)
input double            GridIntelligenceConflictPenalty = 0.10;   // Grid intelligence conflict penalty
// GridIntelligenceConsensusMaxOpposed: V31.6z67: the consensus BONUS now also requires few senses opposing. Previously it only checked "enough agree" - so 10 for / 6 against still collected a full synergy bonus while the conflicted branch never ran.
input int               GridIntelligenceConsensusMaxOpposed = 2;   // Grid intelligence consensus max opposed
// GridIntelligenceDepthThresholdBoost: How much the hard-block bar rises from order 1 to order 6+ (deeper = stricter)
input double            GridIntelligenceDepthThresholdBoost = 0.35;   // Grid intelligence depth threshold boost
// GridIntelligenceMaxThreshold: V31.6z68: the depth boosts are multiplicative (reversal x1.5, adverse-streak x1.5, DD-accel x1.6 = x3.6) and could push the bar to ~1.38 - above the score's own 0-1 range, so NOTHING could ever pass and the 16-sense system silently became a plain hard block. Conditions may demand a near-perfect read; never an impossible one.
input double            GridIntelligenceMaxThreshold = 0.85;   // Grid intelligence max threshold

input group "ADVANCED ▸ Trend strength (ADX)"
// EnableTrendStrength: V31.6q: catches a strong, SUSTAINED, ongoing move against grid direction - Trend Reversal alone only fires on a CHANGE of character, missing plain continuation
input bool              EnableTrendStrength          = true;   // Enable trend strength
input ENUM_TIMEFRAMES   TrendStrengthTF              = PERIOD_M15;   // Trend strength TF
input int               TrendStrengthPeriod          = 14;   // Trend strength period
// TrendStrengthMinADX: Below this ADX, no meaningful trend - component stays neutral
input double            TrendStrengthMinADX          = 20.0;   // Trend strength min ADX
// TrendStrengthStrongADX: At/above this ADX, treated as maximum strength
input double            TrendStrengthStrongADX       = 40.0;   // Trend strength strong ADX

input group "ADVANCED ▸ Recovery path zone search"
// The first FORWARD-LOOKING sense: searches the actual price path between now and the
// basket's break-even average for a real, strong waypoint the market is likely to respect.
input bool              EnableRecoveryPathSearch     = true;   // Enable recovery path search
// RecoveryPathMaxWaypoints: How many candidate zones to scan along the path (cascading, like SZR)
input int               RecoveryPathMaxWaypoints     = 3;   // Recovery path max waypoints
// RecoveryPathZoneToleranceP: Points to step past a found zone before searching for the next
input int               RecoveryPathZoneToleranceP   = 50;   // Recovery path zone tolerance p
// RecoveryPathMinZoneStrength: V31.6z60: minimum strength for a zone on the path home to count as a genuine BARRIER (was mislabelled "waypoint" - the old code treated these obstacles as a reason to add MORE, exactly inverted)
input double            RecoveryPathMinZoneStrength  = 1.5;   // Recovery path min zone strength
// RecoveryPathSeveritySpan: V31.6z60: strength range above MinZoneStrength across which barrier severity scales from mild to full
input double            RecoveryPathSeveritySpan     = 2.0;   // Recovery path severity span

input group "ADVANCED ▸ Major sweep awareness"
// Scans recent bars for a strong, zone-confirmed sweep-rejection - a general sense that feeds
// grid/entry decisions, complementing the existing Sweep detector (which only fires as its
// own standalone entry type on the current bar).
input bool              EnableMajorSweepAwareness    = true;   // Enable major sweep awareness
input int               MajorSweepLookbackBars       = 6;   // Major sweep lookback bars
input int               MajorSweepZoneSearchPoints   = 300;   // Major sweep zone search points
input double            MajorSweepMinZoneStrength    = 1.5;   // Major sweep min zone strength
// MajorSweepScoreBonus: Bonus/penalty magnitude when a recent sweep agrees/disagrees with the proposed direction
input int               MajorSweepScoreBonus         = 2;   // Major sweep score bonus
input bool              MajorSweepPrintOnUse         = true;   // Major sweep print on use (on/off)

input group "ADVANCED ▸ Equilibrium / premium-discount zone"
// Classic SMC concept: the 50% midpoint of the current significant range splits it into
// Premium (upper half, favors SELL) and Discount (lower half, favors BUY). Captures WHERE
// within the broader range price sits - a dimension no other sense measures.
input bool              EnableEQZone                 = true;   // Enable EQ zone
input ENUM_TIMEFRAMES   EQZoneTF                     = PERIOD_H1;   // EQ zone TF
input int               EQZoneLookbackBars           = 40;   // EQ zone lookback bars
// EQZonePremiumThreshold: Range-position % at/above which price is "deep Premium"
input double            EQZonePremiumThreshold       = 65.0;   // EQ zone premium threshold
// EQZoneDiscountThreshold: Range-position % at/below which price is "deep Discount"
input double            EQZoneDiscountThreshold      = 35.0;   // EQ zone discount threshold
// EQZoneScoreBonus: Bonus/penalty magnitude when EQ zone agrees/disagrees with the proposed direction
input int               EQZoneScoreBonus             = 2;   // EQ zone score bonus
// EnableEQZoneScaling: V251: weigh premium/discount by how deep into the extreme price is, rather than a flat point either side of the threshold
input bool              EnableEQZoneScaling          = true;   // Enable EQ zone scaling
// EQZoneDeepBonus: V251: extra weight at the far edge of the range, on top of the base. At the threshold itself the reading is marginal; at the extreme it is the whole trade.
input int               EQZoneDeepBonus              = 4;   // EQ zone deep bonus
input bool              EQZonePrintOnUse             = false;   // EQ zone print on use (on/off)

input group "ADVANCED ▸ Engulfing pattern awareness"
// Classic two-candle reversal/continuation confirmation: current candle's body completely
// engulfs the prior candle's body in the opposite direction. Zone-quality-gated by default,
// same upgrade philosophy as Sweep: prefer engulfing AT a real level over open-space noise.
input bool              EnableEngulfingAwareness     = true;   // Enable engulfing awareness
input int               EngulfingLookbackBars        = 6;   // Engulfing lookback bars
input bool              EngulfingRequireZoneConfirm  = true;   // Engulfing require zone confirm (on/off)
input int               EngulfingZoneSearchPoints    = 300;   // Engulfing zone search points
input double            EngulfingMinZoneStrength     = 1.5;   // Engulfing min zone strength
input int               EngulfingScoreBonus          = 2;   // Engulfing score bonus
input bool              EngulfingPrintOnUse          = true;   // Engulfing print on use (on/off)

// FEATURE(candlestick-models): Pin Bar (Hammer / Shooting Star) and Morning/Evening Star, added
// to the reversal consensus so a turn is confirmed by classic candlestick reversals, not just
// engulfing. These feed the SAME consensus that both grid reactions and reversal first-entries
// use, so improving them here strengthens both at once.
input group "ADVANCED ▸ Candlestick reversal patterns (pin bar + star)"
// EnablePinBarAwareness: Include Pin Bar (Hammer/Shooting Star) in the reversal consensus
input bool   EnablePinBarAwareness      = true;   // Enable pin bar awareness
// PinBarMaxBodyFraction: Body must be <= this fraction of the candle range (a pin bar is mostly wick)
input double PinBarMaxBodyFraction      = 0.35;   // Pin bar max body fraction
// PinBarMinWickFraction: The rejection wick must be >= this fraction of the range (long tail)
input double PinBarMinWickFraction      = 0.50;   // Pin bar min wick fraction
// PinBarOppositeWickMax: The opposite (small) wick must be <= this fraction of the rejection wick
input double PinBarOppositeWickMax      = 0.5;   // Pin bar opposite wick max
// EnableStarAwareness: Include Morning/Evening Star (3-candle) in the reversal consensus
input bool   EnableStarAwareness        = true;   // Enable star awareness
// StarMiddleMaxBodyFraction: The middle "star" candle's body must be <= this fraction of the first candle's body
input double StarMiddleMaxBodyFraction  = 0.5;   // Star middle max body fraction
// CandlePatternLookbackBars: How many recent bars to scan for a pin bar / star
input int    CandlePatternLookbackBars  = 4;   // Candle pattern lookback bars

// FEATURE(order-block + tweezer): 1st-stage advanced models. Order Block = institutional zone
// (last opposite candle before a strong impulse) that price returns to and reacts from - a
// higher-grade signal than a plain candle. Tweezer = two candles rejecting the same level twice.
// Both feed the SAME reversal consensus, so grid reactions and reversal first-entries both gain.
// EnableOrderBlockAwareness: Include institutional Order Block reactions in the consensus
input bool   EnableOrderBlockAwareness  = true;   // Enable order block awareness
// OrderBlockImpulseATRMult: The impulse leg after the order block must be at least this * ATR (a real institutional move)
input double OrderBlockImpulseATRMult   = 1.5;   // Order block impulse ATR multiplier
// OrderBlockLookbackBars: How many bars back to search for the order block + impulse
input int    OrderBlockLookbackBars     = 8;   // Order block lookback bars
// OrderBlockZonePadPoints: Price counts as "in the zone" within this many points of the order block candle
input int    OrderBlockZonePadPoints    = 100;   // Order block zone pad points
// EnableTweezerAwareness: Include Tweezer top/bottom in the consensus
input bool   EnableTweezerAwareness     = true;   // Enable tweezer awareness
// TweezerTolerancePoints: Two highs/lows within this many points count as a matching tweezer level
input int    TweezerTolerancePoints     = 80;   // Tweezer tolerance points

// FEATURE(consensus-quality): 2nd-stage quality layer (B + C). A reversal is stronger when it
// happens (C) at a strong S/R zone, and (B) shows up on more than one timeframe. Rather than
// GATE signals on these (which would starve the consensus), we ADD a bonus confirmation when they
// hold - so a reversal at a real wall, confirmed on two TFs, counts for more, while a lone signal
// still counts. Bonus, not a filter - keeps the consensus alive while rewarding quality.
// EnableConsensusZoneQuality: (C) +1 consensus when the reversal sits at a strong S/R zone
input bool   EnableConsensusZoneQuality  = true;   // Enable consensus zone quality
// ConsensusZoneMinStrength: Zone must be at least this strong (ZoneMapStrength) to grant the bonus
input double ConsensusZoneMinStrength    = 2.0;   // Consensus zone min strength
// ConsensusZoneProximityPts: Reversal must be within this many points of that zone
input int    ConsensusZoneProximityPts   = 350;   // Consensus zone proximity points
// EnableConsensusMultiTF: (B) +1 consensus when a candle reversal also shows on the higher TF
input bool   EnableConsensusMultiTF      = true;   // Enable consensus multi TF
// EnableConsensusOrderFlow: (A) +1 consensus when order-flow pressure agrees with the reversal. NOTE: MT5 has only tick volume, so this is a rough proxy - kept as a bonus (never a gate) precisely because it's the least reliable of the three quality layers.
input bool   EnableConsensusOrderFlow    = true;   // Enable consensus order flow

input group "ADVANCED ▸ Reversal vs continuation risk differentiation"
// From the professional audit (Phase 1/2 findings): reversal-type signals carry more
// downstream risk than continuation-type signals in a grid/martingale system, but were
// previously held to the identical score bar. This treats them differently at both entry
// (higher bar to start) and grid (faster-rising caution as a reversal-opened basket deepens).
input bool              EnableReversalRiskDifferentiation = true;   // Enable reversal risk differentiation
// ReversalTypeExtraScoreReq: Extra minimum score required for a reversal-type first entry
input int               ReversalTypeExtraScoreReq    = 1;   // Reversal type extra score required

// FEATURE(firstentry-reversal-consensus): a reversal-type first entry (sweep / near-zone / fake-
// breakout / range-edge / exhaustion / zone-retest) is a bet that price TURNS. A single candle or
// a single detector can be fooled. So for reversal-type entries ONLY, cross-check the multi-signal
// ReversalConsensusScore in the entry's own direction: if 2+ independent reversal signals agree,
// award a score BONUS (this is a genuine turn); if they don't, apply a PENALTY (the turn isn't
// confirmed). This is deliberately a score nudge, NOT a hard block - a strong reversal setup can
// still pass without full consensus, and it NEVER touches trend / breakout / momentum entries
// (those aren't reversals, so demanding reversal consensus of them would wrongly suppress them).
// EnableFirstEntryReversalConsensus: V55b: OFF. Redundant - the reversal consensus is ALREADY scored by the GlobalLocalScoreBonus block, which handles it with a proper three-way branch (supports / opposes / conflicting, +/-3). This layer added a fourth opinion on the same evidence: consensus in favour scored +3 there and +2 here, absent consensus was penalised twice. One voice per observation.
input bool   EnableFirstEntryReversalConsensus = false;   // Enable first entry reversal consensus
// FirstEntryConsensusMinScore: 0.82 = 2 signals agree, 0.92 = 3+. 0.80 = "at least 2 independent reversal signals".
input double FirstEntryConsensusMinScore    = 0.80;   // First entry consensus min score
// FirstEntryConsensusBonus: Score added when consensus confirms the reversal
input int    FirstEntryConsensusBonus       = 2;   // First entry consensus bonus
// FirstEntryConsensusPenalty: V50b: cut 2 -> 1. This penalty stacked on top of ReversalTypeExtraScoreReq (+1 to the minimum) and the daily-bias penalty, pushing a Balanced-mode reversal entry's effective bar to ~10 points - a good setup scoring 8 was failing. The +2 bonus for confirmed consensus is kept, so consensus is still rewarded; it's just no longer double-punished when absent.
input int    FirstEntryConsensusPenalty     = 1;   // First entry consensus penalty
input bool   FirstEntryConsensusPrintOnUse  = true;   // First entry consensus print on use (on/off)
// ReversalTypeDepthBoostMultiplier: Grid's depth-aware threshold rises this much faster for a reversal-opened basket
input double            ReversalTypeDepthBoostMultiplier = 1.5;   // Reversal type depth boost multiplier

input group "ADVANCED ▸ Trend quality score (continuation synthesis)"
// The market moves WITH a trend more often than it reverses - this is the unifying "eye" for
// trend-continuation confidence, combining ADX strength, MTF alignment, moving-average order,
// and Higher-High/Higher-Low structure into one 0-1 score. Boosts every continuation-type
// detector (and can stand alone as its own confirmation) rather than being one more isolated signal.
input bool              EnableTrendQualityScore      = true;   // Enable trend quality score
input ENUM_TIMEFRAMES   TrendQualityTF               = PERIOD_M15;   // Trend quality TF
input int               TrendQualityFastMA           = 8;   // Trend quality fast MA
input int               TrendQualityMediumMA         = 21;   // Trend quality medium MA
input int               TrendQualitySlowMA           = 50;   // Trend quality slow MA
input int               TrendQualitySwingDepth       = 3;   // Trend quality swing depth
input int               TrendQualitySwingLookback     = 40;   // Trend quality swing lookback
// TrendQualityBonus: Score bonus when trend quality strongly agrees with entry direction
input int               TrendQualityBonus            = 2;   // Trend quality bonus
input double            TrendQualityMinScoreForBonus = 0.65;   // Trend quality min score for bonus
input bool              TrendQualityPrintOnUse       = true;   // Trend quality print on use (on/off)

input group "ADVANCED ▸ Breakout continuation"
// Opposite of Fake Breakout Return: price breaks a real zone with a strong, non-rejecting
// close - bet the break is genuine and continues, not a trap.
input bool              EnableBreakoutContinuation   = true;   // Enable breakout continuation
input int               BreakoutSearchPoints         = 300;   // Breakout search points
// BreakoutConfirmPoints: How far beyond the zone the close must be to count as a genuine break
input int               BreakoutConfirmPoints        = 100;   // Breakout confirm points
// BreakoutMaxWickRatio: Rejection wick must be below this fraction of the candle range
input double            BreakoutMaxWickRatio         = 0.25;   // Breakout max wick ratio
// BreakoutStrengthConfirmScale: V31.6z18 fix: replaces the old "strength=bonus" logic - stronger zones now require proportionally MORE confirm-distance beyond BreakoutConfirmPoints before a break is accepted (a real bug found via live testing: a proven multi-week support broke through a single confirming candle, backwards logic)
input double            BreakoutStrengthConfirmScale = 0.5;   // Breakout strength confirm scale

input group "ADVANCED ▸ Trend ride (ADX-confirmed pullback entry)"
// Classic "buy the dip in an uptrend": strong ADX-confirmed trend + a shallow pullback that's
// now resuming - enter WITH the trend rather than waiting for a reversal that may not come.
input bool              EnableTrendRide              = true;   // Enable trend ride
input ENUM_TIMEFRAMES   TrendRideTF                  = PERIOD_M15;   // Trend ride TF
input double            TrendRideMinADX              = 25.0;   // Trend ride min ADX
input int               TrendRidePullbackLookback    = 5;   // Trend ride pullback lookback
// TrendRideMaxPullbackATRMult: Pullback depth must stay within this multiple of ATR (shallow, not a reversal)
input double            TrendRideMaxPullbackATRMult  = 1.5;   // Trend ride max pullback ATR multiplier

input group "ADVANCED ▸ Swing continuation"
// The mirror of Trend Reversal: after a pullback WITHIN an established trend, a fresh swing
// point that CONTINUES the existing HH/HL (or LH/LL) sequence confirms the trend is intact,
// not reversing.
input bool              EnableSwingContinuation      = true;   // Enable swing continuation
input ENUM_TIMEFRAMES   SwingContinuationTF          = PERIOD_M15;   // Swing continuation TF
input int               SwingContinuationDepth       = 3;   // Swing continuation depth
input int               SwingContinuationLookback     = 40;   // Swing continuation lookback

input group "ADVANCED ▸ Moving average bounce"
// Price pulls back to a rising (or falling) moving average within a confirmed trend and
// bounces - a very well-known, simple trend-continuation entry.
input bool              EnableMABounce               = true;   // Enable MA bounce
input ENUM_TIMEFRAMES   MABounceTF                   = PERIOD_M15;   // MA bounce TF
input int               MABouncePeriod               = 21;   // MA bounce period
input int               MABounceTolerancePoints      = 150;   // MA bounce tolerance points
// MABounceSlopeLookback: Bars back to compare MA slope for rising/falling confirmation
input int               MABounceSlopeLookback        = 5;   // MA bounce slope lookback

input group "ADVANCED ▸ Donchian breakout"
// The simplest, most classic trend-following entry: price makes a new N-bar high/low.
input bool              EnableDonchianBreakout       = true;   // Enable donchian breakout
input ENUM_TIMEFRAMES   DonchianTF                   = PERIOD_M15;   // Donchian TF
input int               DonchianPeriod               = 20;   // Donchian period

input group "ADVANCED ▸ Consecutive same-direction candles"
// Several candles in a row closing the same direction is a simple, reliable momentum
// confirmation - an uninterrupted push, not a chop.
input bool              EnableConsecutiveCandles     = true;   // Enable consecutive candles
input ENUM_TIMEFRAMES   ConsecutiveCandlesTF         = PERIOD_M15;   // Consecutive candles TF
input int               ConsecutiveCandleCount       = 3;   // Consecutive candle count

input group "ADVANCED ▸ DXY-confirmed trend (gold-specific macro)"
// If the dollar is trending strongly and gold's local price agrees, that's macro-level
// confirmation, not just local price action.
input bool              EnableDXYConfirmedTrend      = true;   // Enable DXY confirmed trend
input int               DXYConfirmedTrendPriceLookback = 10;   // DXY confirmed trend price lookback

input group "ADVANCED ▸ Expanding volatility"
// ATR expanding (not contracting) in the trend direction means there's still room left -
// the trend isn't running out of steam.
input bool              EnableExpandingVolatility    = true;   // Enable expanding volatility
input ENUM_TIMEFRAMES   ExpandingVolTF               = PERIOD_M15;   // Expanding volume TF
input int               ExpandingVolFastPeriod       = 5;   // Expanding volume fast period
input int               ExpandingVolSlowPeriod       = 20;   // Expanding volume slow period
// ExpandingVolMinRatio: Fast ATR must exceed slow ATR by at least this ratio to count as "expanding"
input double            ExpandingVolMinRatio         = 1.15;   // Expanding volume min ratio

input group "ADVANCED ▸ MTF unanimous trigger"
// Rare, but when all 4 timeframes (M15/H1/H4/D1) agree on direction, that's a genuinely
// strong standalone signal, not just a supporting bonus.
input bool              EnableMTFUnanimousTrigger    = true;   // Enable MTF unanimous trigger
input int               MTFUnanimousBaseScore        = 5;   // MTF unanimous base score

input group "ADVANCED ▸ EQ zone trend (BUY the dip in an uptrend)"
// The Equilibrium/Premium-Discount concept read the other way: within a CONFIRMED trend,
// price pulling back to the Discount half (for an uptrend) or Premium half (for a downtrend)
// is the classic "buy the dip / sell the rip within a trend" entry.
input bool              EnableEQZoneTrend            = true;   // Enable EQ zone trend
input double            EQZoneTrendMinADX            = 22.0;   // EQ zone trend min ADX

input group "ADVANCED ▸ Volume push continuation"
// Sustained, one-directional tick-volume conviction across several bars - no sweep, no
// reversal pattern needed, just sustained real pressure in one direction.
input bool              EnableVolumePush             = true;   // Enable volume push
input ENUM_TIMEFRAMES   VolumePushTF                 = PERIOD_M15;   // Volume push TF
input int               VolumePushLookbackBars       = 3;   // Volume push lookback bars

input group "ADVANCED ▸ Vwap bounce (volume-weighted average price)"
// Unlike a plain moving average, VWAP weighs price by VOLUME - one of the most-watched
// levels for institutional participants. Price holding above/below VWAP, or bouncing off
// it, is a genuinely different dimension than a simple MA (which ignores volume entirely).
input bool              EnableVWAPBounce             = true;   // Enable VWAP bounce
input ENUM_TIMEFRAMES   VWAPTF                       = PERIOD_M15;   // Vwaptf
// VWAPLookbackBars: ~ one session on M15; resets the VWAP window
input int               VWAPLookbackBars             = 48;   // VWAP lookback bars
input int               VWAPTolerancePoints          = 150;   // VWAP tolerance points

input group "ADVANCED ▸ Trend continuation zone caution"
// Real gap found via live testing: 11 of 12 trend-continuation detectors (Trend Ride, MA
// Bounce, Donchian, Consecutive Candles, DXY, Expanding Vol, MTF Unanimous, EQ Zone,
// Volume Push, VWAP, Swing Continuation) never check Zone Map - a SELL could fire right
// INTO a strong historical support level purely because the local trend looks strong. This
// applies a universal penalty to ANY continuation-type entry that's heading straight into a
// strong opposing zone, regardless of which specific detector fired.
input bool              EnableTrendContinuationZoneCaution = true;   // Enable trend continuation zone caution
// TrendContinuationZoneCautionPoints: How close the opposing zone must be to trigger caution (widened from 250 - that was only $2.50, smaller than a typical single candle move)
input int               TrendContinuationZoneCautionPoints = 600;   // Trend continuation zone caution points
input double            TrendContinuationZoneCautionMinStrength = 1.5;   // Trend continuation zone caution min strength
input int               TrendContinuationZoneCautionPenalty = 3;   // Trend continuation zone caution penalty
// EnableReversalTypeZoneCaution: V31.6z50: confirmed root cause of "BUY at resistance / SELL at support" - reversal types were EXEMPT from this check on the assumption they police their own zones, but an audit found Sweep and Range-Edge check NO zone at all, and none of the others check the OPPOSING one. A bounce bet with a wall right in front is just as bad as a breakout into one.
input bool              EnableReversalTypeZoneCaution = true;   // Enable reversal type zone caution
// EnableEntryFarZoneAwareness: V31.6z29 NEW: catches "broke a LOCAL high but still under a major ceiling" - the 600pt check alone missed levels further out
input bool              EnableEntryFarZoneAwareness  = true;   // Enable entry far zone awareness
// EntryFarZoneCautionPoints: Narrower than Grid's far check (6000) - a fresh entry commits less than an averaging-down grid addition, so a moderate look-ahead is enough
input int               EntryFarZoneCautionPoints    = 3000;   // Entry far zone caution points
// EntryFarZoneMinStrength: Only genuinely major levels matter at this distance
input double            EntryFarZoneMinStrength      = 2.5;   // Entry far zone min strength

// FIX(zone-wall-hardblock): the caution above only ever applied a -penalty. With MinScore as
// low as 4-6, a strong signal could absorb the penalty and STILL fire - which is exactly the
// screenshot case: a SELL opened right on a strong support wall and price rocketed up. A penalty
// is right for a "moderate wall / decent distance" situation, but a VERY strong wall sitting
// VERY close in front of the trade is not a "score it lower" case - it's a "do not take this
// trade" case. This adds a true HARD BLOCK for that extreme, unambiguous situation only. It sits
// ON TOP of the penalty system (does not replace it) and is deliberately stricter than the
// caution thresholds so it fires only on the genuinely dangerous setups.
// EnableZoneWallHardBlock: V55b: OFF. Its rule now lives in CounterContextBlockNow() with identical thresholds (250pt / strength 2.5), where BOTH the score engine and the queue-replay guard evaluate it. Leaving this one on as well would apply the same veto twice, and only the score-engine path - a queued signal would still have skipped it.
input bool              EnableZoneWallHardBlock      = false;   // Enable zone wall hard block
// ZoneWallHardBlockPoints: Opposing wall must be at least this CLOSE (points) to hard-block. Tighter than the 600pt caution - only an imminent wall blocks
input int               ZoneWallHardBlockPoints      = 250;   // Zone wall hard block points
// ZoneWallHardBlockMinStrength: V33b: raised 2.2 -> 2.5. With PDH/PDL now added as strong levels, 2.2 was reached too often and blocked too much. 2.5 reserves the hard block for genuinely major, multi-touch walls, keeping the bot active near ordinary daily levels.
input double            ZoneWallHardBlockMinStrength = 2.5;   // Zone wall hard block min strength
input bool              ZoneWallHardBlockPrintOnUse  = true;   // Zone wall hard block print on use (on/off)

// FEATURE(counter-zone-firstentry): variant B - a dedicated hard block for the exact failure the
// user hit: a first entry opened straight INTO a strong zone it should bounce off (a SELL sitting
// on support, or a BUY under resistance). The existing zone-wall block was tuned conservative
// (str 2.5 / 250pt) to avoid making the bot sluggish, so it let this through. This block is
// FIRST-ENTRY ONLY (grid is unaffected) and specifically targets counter-zone entries: SELL when
// strong SUPPORT is close below (price is likely to bounce UP), BUY when strong RESISTANCE is
// close above (price is likely to drop). It is intentionally wider/looser than the zone-wall
// block because opening a fresh basket against a defended level is the single worst entry type.
// EnableCounterZoneFirstEntryBlock: Hard-block a FIRST entry opened into a strong zone it should bounce off
input bool   EnableCounterZoneFirstEntryBlock = true;   // Enable counter zone first entry block
// CounterZoneBlockPoints: V70b: 250 -> 3500 ($3.5) after a live loss. At 250 ($0.25) a first entry was blocked only if price was almost ON the level, so a BUY ~$1 under a strong 4104 resistance sailed through and price rejected straight down for a ~50% basket loss. XAUUSD moves $70-80/day and rejects from resistance $1-4 out, so the block must trigger while there is still room. Paired with the strength floor so only genuine levels veto.
input int    CounterZoneBlockPoints        = 3500;   // Counter zone block points
// CounterZoneBlockMinStrength: V200: 1.8 -> 1.4. Zone strength is 1.0 + touches x 0.25, so 1.8 needed four touches before the protection engaged - and a level tested three times is exactly the kind that turns price back. Your losing entries were into two- and three-touch zones scoring 1.50-1.75, sitting just under the threshold. At 1.4 a three-touch level is protected; a single untested swing at 1.25 still is not.      // V70b: 2.5 -> 1.8. Strength = 1.0 + touches*weight + confirmations, so 2.5 needed a heavily re-tested level and let fresh-but-real resistance through. 1.8 catches a level with a couple of touches/confirmations - the wall price rejects from - without blocking trivial zones.
input double CounterZoneBlockMinStrength   = 1.4;   // Counter zone block min strength
// ZoneNearAboveTolerance: V243: how far ($0.90) past the current price a swing can sit and still count as the level in front of it. A support price has just risen through is still that support - discarding it made a shelf read as a single point further down, which is how a sell went in at 4485.10 with the band running to 4486.
input int    ZoneNearAboveTolerance      = 900;   // Zone near above tolerance

// V205: the level behind the level. The zone map reports the nearest one - correct for where price
// goes first, wrong for whether the trade has room. Price that fell to a deep support, bounced, and
// now sits above a shallower one shows plenty of space beneath that shallow level, while the level
// that actually turned price sits just under it, unseen. The distance that matters is to the level
// that will HOLD, not the first one price meets.
// EnableSecondLevelCheck: Look past the nearest level to what is behind it
input bool   EnableSecondLevelCheck      = true;   // Enable second level check
// ZoneNextLevelGapPoints: Separation ($0.30) before a level counts as a distinct one rather than part of the same zone
input int    ZoneNextLevelGapPoints      = 300;   // Zone next level gap points
// SecondLevelStrengthEdge: How much stronger the level behind must be before it changes the picture
input double SecondLevelStrengthEdge     = 0.4;   // Second level strength edge
// SecondLevelMaxGapPoints: Gap ($4.00) within which the level behind is reachable in the same move
input int    SecondLevelMaxGapPoints     = 4000;   // Second level max gap points
// SecondLevelReachPoints: Distance ($8.00) within which it is close enough to matter to this trade at all
input int    SecondLevelReachPoints      = 8000;   // Second level reach points
// SecondLevelPenalty: Score cost of trading toward a level whose real barrier sits just behind the visible one
input int    SecondLevelPenalty          = 4;   // Second level penalty
// SecondLevelPrintOnUse: Log when a hidden stronger level is found
input bool   SecondLevelPrintOnUse       = true;   // Second level print on use (on/off)
input bool   CounterZoneBlockPrintOnUse    = true;   // Counter zone block print on use (on/off)

// FEATURE(htf-against-firstentry): variant B for "the bot opens SELL against a BUY market and sits
// in DD". Until now a first entry fighting the higher-timeframe trend only lost a couple of score
// points and some lot size - never blocked - so a strong counter-trend signal still fired. This
// HARD-BLOCKS a first entry taken against a STRONG global trend... UNLESS it is a genuinely strong
// reversal (a full multi-signal consensus). That exception is the whole point: we still want to
// catch real turns, we just refuse weak/ordinary entries that fight a firm trend. First-entry only.
// EnableHTFAgainstFirstEntryBlock: Hard-block a first entry fighting a strong global trend
input bool   EnableHTFAgainstFirstEntryBlock = true;   // Enable HTF against first entry block
// HTFAgainstBlockMinConfidence: V100b: 0.40 -> 0.60 for scalping. With a ~$2-3 TP, a normal D1/H4 trend shouldn't veto a counter-direction scalp - inside an uptrend there are still plenty of small down-scalps. At 0.60 (needs ADX ~32 across D1/H4/H1) only a GENUINELY strong global counter-trend blocks the entry; ordinary trends leave scalps free. The counter-impulse and ghost blocks (which scalping genuinely needs) are separate and unaffected.
input double HTFAgainstBlockMinConfidence   = 0.60;   // HTF against block min confidence
// HTFAgainstReversalOverride: V50b: lowered 0.90 -> 0.82. Demanding 3+ reversal signals to trade against a trend was so rare it never fired; 0.82 (2 independent signals) still means a confirmed turn, not a guess.
input double HTFAgainstReversalOverride     = 0.82;   // HTF against reversal override
// HTFAgainstScorePenalty: V189: score cost of a first entry against a confident higher-timeframe trend. This was a hard block until a live A+ setup scoring 11 against a bar of 4 was refused by it - the observation was right, the mechanism was not.
input int    HTFAgainstScorePenalty      = 4;   // HTF against score penalty

input group "ADVANCED ▸ Global vs local trend alignment"
// Direct user request: distinguish "what is the BIG PICTURE doing" (H4/D1) from "what is
// happening RIGHT NOW" (M15/local) - trading as much as possible WITH the global trend is
// exactly what shortens DD duration, since an aligned basket has real structural odds of
// being pulled back to break-even even after an adverse local move, while one fighting the
// bigger picture has no underlying current working in its favor.
input bool              EnableGlobalLocalTrendSplit  = true;   // Enable global local trend split
input int               GlobalTrendADXPeriod         = 14;   // Global trend ADX period
input double            GlobalTrendMinADX            = 20.0;   // Global trend min ADX
// GlobalTrendADXFullStrength: V96b: 35 -> 20. mag=1 now needs ADX ~40 (MinADX 20 + 20). The slower D1/H4/H1 rarely push ADX to the old ~55 that FullStrength 35 implied, so strong global trends were badly under-rated (ADX 30 gave only ~0.29). 20 keeps it reachable while still separating weak from strong.// V31.6z31 NEW: ADX at/above this counts as FULL magnitude (1.0) for the global confidence blend - between MinADX and here scales linearly
input double            GlobalTrendADXFullStrength   = 20.0;   // Global trend ADX full strength
// GlobalTrendH4LookbackBars: ~2 days of H4 bars
input int               GlobalTrendH4LookbackBars    = 12;   // Global trend H4 lookback bars
// GlobalTrendH1LookbackBars: V31.6z56 NEW: H1 was completely absent from the global read - this is the bridge between the big picture and the local M15 view
input int               GlobalTrendH1LookbackBars    = 24;   // Global trend H1 lookback bars
// GlobalTrendWeightD1: V31.6z56: D1 is the biggest, most persistent picture - previously it carried only 1 of 3 votes while H4 carried 2
input double            GlobalTrendWeightD1          = 3.0;   // Global trend weight D1
// GlobalTrendWeightH4: Main swing structure
input double            GlobalTrendWeightH4          = 2.0;   // Global trend weight H4
// GlobalTrendWeightH1: Bridge to the local read - lightest of the three "global" timeframes
input double            GlobalTrendWeightH1          = 1.0;   // Global trend weight H1
// GlobalTrendWeakConfirmValue: Capped confidence when a timeframe's ADX doesn't qualify and the close-comparison fallback is used instead
input double            GlobalTrendWeakConfirmValue  = 0.30;   // Global trend weak confirm value
// FIX(global-notrend-floor): GlobalTFConfidence() used to borrow LocalTrendNoTrendADX (14.0) as its
// own "genuine range, suppress the fallback" floor. That value was tuned for M15-scale ADX; D1/H4/H1
// ADX moves much slower and sits above 14 far more easily even in a real range, so the global range
// floor was effectively toothless - a daily/4h/1h range could still leak a spurious directional bias
// through the close-comparison fallback. Global timeframes now get their own floor, tuned separately.
// GlobalTrendNoTrendADX: Below this ADX on a global (D1/H4/H1) TF = no trend at all (range); return 0 rather than a weak direction
input double            GlobalTrendNoTrendADX        = 16.0;   // Global trend no trend ADX
input ENUM_TIMEFRAMES   LocalTrendTF                 = PERIOD_M15;   // Local trend TF
input int               LocalTrendADXPeriod          = 14;   // Local trend ADX period
// LocalTrendMinADX: ADX at/above which the local read is treated as a real (ADX-graded) trend
input double            LocalTrendMinADX             = 18.0;   // Local trend min ADX

// FEATURE(local-trend-range-floor): below MinADX the code falls back to a simple direction read and
// reports a weak trend - but a genuine RANGE (very low ADX, price chopping sideways) would still be
// labelled a weak up/down trend, inviting trend-following entries into a range. Add a hard floor:
// when ADX is below this, there is effectively NO trend, so local confidence is 0 regardless of which
// way the last few closes happened to lean. Between the floor and MinADX it stays a weak read.
// LocalTrendNoTrendADX: Below this ADX = no local trend at all (range); return 0 rather than a weak direction
input double            LocalTrendNoTrendADX         = 14.0;   // Local trend no trend ADX

// FEATURE(local-trend-momentum): direction+strength alone can't tell a trend that is BUILDING (ADX
// rising) from one that is FADING (ADX falling) - both read as e.g. "ADX 30, strong". A fading trend
// is where reversals happen, so trading it like a healthy trend is a classic late entry. Compare ADX
// now vs a few bars back: if it has dropped meaningfully, the trend is losing steam - trim the local
// confidence and raise a "fading" flag for caution. We do NOT reward a building trend (asymmetric):
// caution on the way down is protective, extra conviction on the way up is not needed.
// EnableLocalTrendMomentum: Detect a fading local trend via ADX slope and treat it with caution
input bool              EnableLocalTrendMomentum      = true;   // Enable local trend momentum
// LocalTrendADXSlopeBars: How many bars back to compare ADX against for the slope
input int               LocalTrendADXSlopeBars        = 3;   // Local trend ADX slope bars
// LocalTrendADXFadeDelta: ADX must have dropped at least this much to count as "fading" (filters noise)
input double            LocalTrendADXFadeDelta        = 2.0;   // Local trend ADX fade delta
// LocalTrendFadeDampen: When fading, multiply local confidence by this (0.65 = trim ~a third)
input double            LocalTrendFadeDampen          = 0.65;   // Local trend fade dampen
// LocalTrendFadePenalty: Small score penalty on a first entry while the local trend is fading (caution, not a block)
input int               LocalTrendFadePenalty         = 2;   // Local trend fade penalty

// FEATURE(global-htf-bind): DeepHTFTrendDirection() - the trend direction the dashboard shows and the
// HTF-against block relies on - historically read a SINGLE timeframe (H1 MA / Kalman). So a brief H1
// pullback inside a larger D1/H4 downtrend could report "up", and the HTF guard would then protect
// the WRONG side. Bind the final HTF direction to the full weighted global read (D1/H4/H1): H1 gives
// the responsive read, but if the weighted global trend is confident and DISAGREES with H1, global
// wins (H1 is treated as a pullback, not the trend). If global is only mild, the H1 read stands.
// EnableGlobalHTFBind: Bind HTF direction to the weighted D1/H4/H1 global read, not H1 alone
input bool              EnableGlobalHTFBind          = true;   // Enable global HTF bind
// GlobalHTFBindMinConfidence: Weighted global confidence needed for global to overrule the single-TF H1 direction
input double            GlobalHTFBindMinConfidence   = 0.35;   // Global HTF bind min confidence

// FEATURE(global-trend-momentum): the mirror of the local momentum/turning work, for the big picture.
// A fading GLOBAL trend (D1 ADX rolling over) precedes the large reversals that hurt a martingale
// most, and a just-turned D1/H4 is where the bot can get stuck trading the old macro direction. Give
// global its own fade + turning reads, measured on the primary global TF (D1) with slower settings
// than local, since D1 bars are days. Same asymmetric treatment: caution when weakening, no bonus.
// EnableGlobalTrendMomentum: Detect a fading global trend via D1 ADX slope
input bool              EnableGlobalTrendMomentum    = true;   // Enable global trend momentum
// GlobalTrendPrimaryTF: The TF the global fade/turning reads are measured on
input ENUM_TIMEFRAMES   GlobalTrendPrimaryTF         = PERIOD_D1;   // Global trend primary TF
// GlobalTrendADXSlopeBars: Bars back to compare global ADX against (D1 bars = days, so keep small)
input int               GlobalTrendADXSlopeBars      = 2;   // Global trend ADX slope bars
// GlobalTrendADXFadeDelta: Global ADX must have dropped at least this much to count as fading
input double            GlobalTrendADXFadeDelta      = 2.0;   // Global trend ADX fade delta
// GlobalTrendFadeDampen: When global fading, multiply global confidence by this
input double            GlobalTrendFadeDampen        = 0.70;   // Global trend fade dampen
// EnableGlobalTrendTurning: Detect a just-started global flip via a fast/slow window split on the primary global TF
input bool              EnableGlobalTrendTurning     = true;   // Enable global trend turning
// GlobalTrendFastLookbackBars: Fast window (bars) for the recent global direction
input int               GlobalTrendFastLookbackBars  = 3;   // Global trend fast lookback bars
// GlobalTrendTurningDampen: When global turning, multiply global confidence by this
input double            GlobalTrendTurningDampen     = 0.60;   // Global trend turning dampen
// GlobalTrendFadePenalty: Score penalty on a first entry while the global trend is fading (bigger than local: macro reversal risk)
input int               GlobalTrendFadePenalty       = 3;   // Global trend fade penalty
// GlobalTrendTurningPenalty: Score penalty on a first entry while the global trend is turning
input int               GlobalTrendTurningPenalty    = 3;   // Global trend turning penalty
// LocalTrendADXFullStrength: V96b: 30 -> 17. mag=1 now needs ADX ~35 (MinADX 18 + 17), a level a real strong XAUUSD M15 trend actually reaches. At 30 it needed ADX ~48 which M15 rarely hits, so genuine strong trends were rated only ~0.55 mag and under-drove the trend guards.// V31.6z31 NEW: same magnitude-scaling concept, for the local read
input double            LocalTrendADXFullStrength    = 17.0;   // Local trend ADX full strength
input int               LocalTrendLookbackBars       = 8;   // Local trend lookback bars
// EnableLocalTrendM5: V31.6z57: M5 sits between the M1 signal TF and the M15 local read but was in NO trend check - a structural blind spot right next to where signals fire
input bool              EnableLocalTrendM5           = true;   // Enable local trend M5
input int               LocalTrendM5LookbackBars     = 12;   // Local trend M5 lookback bars
// LocalTrendWeightM5: Lightest - M5 is the noisiest of the three and shouldn't dominate
input double            LocalTrendWeightM5           = 1.0;   // Local trend weight M5
// LocalTrendWeightMain: LocalTrendTF (M15) stays the primary local read
input double            LocalTrendWeightMain         = 2.0;   // Local trend weight main
// EnableLocalTrendM30: V31.6z57: M30 appeared NOWHERE outside the Zone Map - the natural bridge from M15 up to the H1 global read was entirely missing
input bool              EnableLocalTrendM30          = true;   // Enable local trend M30
input int               LocalTrendM30LookbackBars    = 8;   // Local trend M30 lookback bars
// LocalTrendWeightM30: Between M5 and M15 in weight - slower, so less noisy than M5
input double            LocalTrendWeightM30          = 1.5;   // Local trend weight M30
// LocalTrendWeakConfirmValue: V31.6z31 NEW: capped confidence when local ADX doesn't qualify and we fall back to a simple close-comparison - deliberately weak, not treated the same as an ADX-confirmed local move
input double            LocalTrendWeakConfirmValue   = 0.30;   // Local trend weak confirm value

// FEATURE(simple-trend-structure): the fallback trend read (used when ADX doesn't qualify) compared
// only close[1] vs close[lookback] - two points, blind to the shape between them. One big candle
// could flip it, and a choppy range that happens to end higher reads as "uptrend". Upgrade it to
// agree across three cheap checks: the net close move, the slope of the window, and market structure
// (higher-highs/higher-lows vs lower-highs/lower-lows). All three must agree for a direction; if they
// disagree the tape is unclear and it returns 0 (no false trend). Keeps the +1/-1/0 interface.
// EnableStructureTrend: Use net+slope+structure agreement instead of a bare 2-point close compare
input bool              EnableStructureTrend         = true;   // Enable structure trend
// StructureTrendMinAgree: How many of the 3 checks (net, slope, structure) must agree (2 = majority, 3 = unanimous/strict)
input int               StructureTrendMinAgree       = 2;   // Structure trend min agree

// FEATURE(local-trend-turning): the local trend read uses an 8-bar window, so when the trend has
// only just flipped (e.g. M15 turned up->down 3 bars ago) the older bars still dominate and the read
// lags - the bot keeps trading the OLD direction into the new move. Add a fast window (default 4
// bars) alongside the main one: when fast and main DISAGREE, the local trend is turning, so we raise
// a "turning" flag (caution) and soften the confidence rather than reporting a confident stale trend.
// EnableLocalTrendTurning: Detect a just-started local trend flip via a fast/slow window split
input bool              EnableLocalTrendTurning      = true;   // Enable local trend turning
// LocalTrendFastLookbackBars: Fast window (bars) for the recent local direction; compared against the main window
input int               LocalTrendFastLookbackBars   = 4;   // Local trend fast lookback bars
// LocalTrendTurningDampen: When turning, multiply local confidence by this (0.50 = halve it) so a stale trend can't drive full-size decisions
input double            LocalTrendTurningDampen      = 0.50;   // Local trend turning dampen
// LocalTrendTurningPenalty: Small score penalty on a first entry while the local trend is mid-flip (caution, not a block)
input int               LocalTrendTurningPenalty     = 2;   // Local trend turning penalty
// GlobalLocalWeightGlobal: V100b: 0.65 -> 0.35. This EA scalps XAUUSD with a ~$2-3 TP, an M1/M5 event; the D1/H4/H1 global trend barely moves at that scale, so LOCAL should dominate the alignment. Global stays at 0.35 as a context/safety layer - still matters when a basket deepens or a big global reversal is underway, but no longer overrides the local read that governs a 2-3 dollar scalp.
input double            GlobalLocalWeightGlobal      = 0.35;   // Global local weight global
// GlobalLocalWeightLocal: V100b: 0.35 -> 0.65. Local (M5/M15/M30) now leads, matching the scalping timeframe.
input double            GlobalLocalWeightLocal       = 0.65;   // Global local weight local

// FEATURE(adaptive-alignment-weight): a 1-order scalp is a pure M1/M5 event, so local should lead.
// But as the grid deepens (5-7 orders) the position is no longer a small scalp - it is a large,
// losing basket where a big GLOBAL reversal is the real threat, exactly the -1458 screenshot. So
// shift the alignment weighting from local-led toward global-led as the order count rises. At 1 order
// it uses the scalping weights above; by MaxOrders it reaches the deep-basket weights below. This
// keeps scalps free while restoring global protection precisely when the basket becomes dangerous.
// EnableAdaptiveAlignWeight: Shift alignment toward global as the basket deepens
input bool              EnableAdaptiveAlignWeight    = true;   // Enable adaptive align weight
// DeepBasketWeightGlobal: Global weight when the basket is at/near MaxOrders (mirrors the scalp weights, flipped)
input double            DeepBasketWeightGlobal       = 0.65;   // Deep basket weight global
// AdaptiveAlignFullShiftOrders: V249fix: 6 -> 5, to track MaxOrders. At 6 with MaxOrders 5 the basket could never reach the "full shift" point, so the deep-basket global-trend weighting topped out at 80% of its configured value exactly when the basket was at its most dangerous - the opposite of what this feature is for. Keep this equal to MaxOrders.   // Order count at which the deep-basket weighting is fully reached
input int               AdaptiveAlignFullShiftOrders = 5;   // Adaptive align full shift orders
// GlobalLocalPullbackGlobalMin: V31.6z31 NEW: global confidence must be at least this to even consider the "pullback vs reversal" adjustment
input double            GlobalLocalPullbackGlobalMin = 0.40;   // Global local pullback global min
// GlobalLocalPullbackLocalMin: Local opposition must exceed this before the non-linear taper starts
input double            GlobalLocalPullbackLocalMin  = 0.40;   // Global local pullback local min
// GlobalLocalPullbackTaperRate: How aggressively the score tapers down as local opposition strengthens beyond the minimum
input double            GlobalLocalPullbackTaperRate = 0.55;   // Global local pullback taper rate
// GlobalLocalScoreBonus: First Entry bonus/penalty magnitude when alignment is strongly favorable/unfavorable
input int               GlobalLocalScoreBonus        = 3;   // Global local score bonus
input bool              GlobalLocalPrintOnUse        = true;   // Global local print on use (on/off)

input group "ADVANCED ▸ Reversal consensus (unified)"
// Direct user feedback: Sense 1 (heaviest-weighted throughout) only ever used swing+RSI to
// detect a reversal, never combined with BOS/CHoCH, Major Sweep, or Engulfing - three more
// genuinely independent reversal confirmations built later the same session.
input bool              EnableReversalConsensus      = true;   // Enable reversal consensus
// ReversalConsensus1Score: Score when exactly 1 independent signal confirms
input double            ReversalConsensus1Score      = 0.68;   // Reversal consensus 1 score
// ReversalConsensus2Score: 2 signals - disproportionately higher, not just additive
input double            ReversalConsensus2Score      = 0.82;   // Reversal consensus 2 score
// ReversalConsensus3Score: 3+ signals - very high confidence
input double            ReversalConsensus3Score      = 0.92;   // Reversal consensus 3 score
// ReversalConsensusExtraStep: Additional increment per confirmation beyond 3
input double            ReversalConsensusExtraStep   = 0.03;   // Reversal consensus extra step

input group "ADVANCED ▸ Zone retest (was orphaned - never wired in)"
// V31.6z43 fix: OPP_TYPE_ZONE_RETEST, its string mapping, and both detector functions were
// fully built and well-designed (confirms a genuine polarity flip via ZoneMapIsPolarityFlip,
// then requires an actual touch-and-bounce, not just proximity) - but never wired into either
// scanner, AND these 4 required inputs were never declared at all (would have failed to
// compile the moment anyone tried to actually enable it). Both gaps fixed together.
input bool   EnableZoneRetestTrigger      = true;   // Enable zone retest trigger
// ZoneRetestMaxDistancePoints: V76b: 400 -> 1500 ($1.5). How close CURRENT price must be to the flipped level to count as still retesting it. At 400 ($0.40) a genuine retest bounce was only valid while price sat almost exactly on the level; once it recovered even $0.50 (normal for a support-flip bounce) the entry was missed. The actual touch is still confirmed separately by ZoneRetestTouchTolerancePoints ($0.15) over the recent window, so widening this only lets the bounce register after price lifts off - it does not loosen what counts as a touch. Matches NearZoneReactionRangePoints for consistency.
input double ZoneRetestMaxDistancePoints  = 1500;   // Zone retest max distance points
// ZoneRetestTouchTolerancePoints: How close the low/high must come to the exact level to count as a genuine touch
input double ZoneRetestTouchTolerancePoints = 150;   // Zone retest touch tolerance points
// ZoneRetestMinStrength: Zone strength bonus threshold (score +2 above this)
input double ZoneRetestMinStrength        = 1.5;   // Zone retest min strength
// ZoneRetestConfirmWindowBars: V31.6z44 NEW: real gap found - only checked the single most recent bar for a touch, missing a retest that happened a bar or two ago with recovery since
input int    ZoneRetestConfirmWindowBars  = 3;   // Zone retest confirm window bars
// ZoneRetestMinWickRatio: Rejection wick (vs candle range) needed to count as a "quality" bounce rather than just a plain green/red close
input double ZoneRetestMinWickRatio       = 0.35;   // Zone retest min wick ratio

input group "ADVANCED ▸ Impulse confirmation"
// None of the 13 trend-continuation tools sense a genuine, sharp impulse candle at all - a
// real gap since a single decisive burst (unusually large range/body vs recent ATR) is
// strong, direct evidence of conviction, distinct from slower measures like ADX or MA order.
input bool              EnableImpulseConfirmation    = true;   // Enable impulse confirmation
input ENUM_TIMEFRAMES   ImpulseTF                    = PERIOD_M15;   // Impulse TF
input int               ImpulsePeriod                = 14;   // Impulse period
input int               ImpulseLookbackBars          = 4;   // Impulse lookback bars
// ImpulseMinBodyRatio: Candle body must be at least this fraction of its range to count as a real impulse, not just a long-wicked chop bar
input double            ImpulseMinBodyRatio          = 0.6;   // Impulse min body ratio
// ImpulseMinATRMultiple: Candle range must be at least this multiple of ATR to qualify as an impulse
input double            ImpulseMinATRMultiple        = 1.5;   // Impulse min ATR multiple
// EnableMoveExtension: V31.6z53: fixes a real, user-reported danger - Impulse Confirmation rewarded candle SIZE with no regard for WHERE in the move it happened, so a blow-off climax at the top of an extended rally earned the HIGHEST buy confidence (the classic false-breakout trap)
input bool              EnableMoveExtension          = true;   // Enable move extension
// MoveExtensionTF: V237: H1 -> M15. From two live stop-outs: a buy at the top of a $24 run and a sell at the bottom of a $99 decline, both taken because this check read 0.53 ATR where the move was plainly finished. The comment below records the original problem correctly - H1 legs against an H1 ATR over a five-day window pinned the block on permanently - but the fix chosen was to widen the ATR rather than narrow the window, which silenced the check for the scale actually being traded. Setups here are built on M5 zones with $2.50 targets; a $24 move is the whole trade, and on H1 it is one candle.
input ENUM_TIMEFRAMES   MoveExtensionTF              = PERIOD_M15;   // Move extension TF
// MoveExtensionATRTF: V237: D1 -> M15. The move and the ATR it is measured against must be on the same scale or the ratio is meaningless - $24 against a $45 daily ATR reads as 0.53, against the $1.80 M15 ATR it reads as 13. What made the old H1/H1 pairing misfire was the LOOKBACK spanning five days, not the ATR timeframe; that is corrected below.
input ENUM_TIMEFRAMES   MoveExtensionATRTF           = PERIOD_M15;   // Move extension atrtf
// MoveExtensionATRPeriod: ATR period on MoveExtensionTF - must be the same TF as the origin search so the ATR-multiple units stay coherent
input int               MoveExtensionATRPeriod       = 14;   // Move extension ATR period
// MoveExtensionLookbackBars: V237: 120 -> 60. This is the other half of the same fix. The window has to span a period the ATR can describe: 120 H1 bars is five days, and a five-day move against an hourly ATR is enormous by construction, which is what pinned the old block on. Sixty M15 bars is fifteen hours - long enough to hold a full session's move, short enough that the M15 ATR is the right unit for it.   // V122: 100 -> 120. On H1 that is 5 DAYS, so a trend that has been running most of a week is still measured from its real start rather than from wherever the window happened to begin.
input int               MoveExtensionLookbackBars    = 60;   // Move extension lookback bars
// MoveExtensionResetPercent: V122: a correction retracing this much of the leg means the old move ended and a new one started - the extension is then measured from the correction's turning point, not the original extreme. Without this, a fresh rally after a real pullback still reads as an exhausted multi-day trend and gets blocked. Lower = resets more easily, higher = keeps counting the older move.   // V31.6z55: raised from 40. On the H1 default this reaches ~4 days, enough to actually locate a long trend's origin
input double            MoveExtensionResetPercent    = 50.0;   // Move extension reset %
// MoveExtensionMatureATR: V121: 3.0 -> 1.2. Measured in D1 ATR units (~$25 on XAUUSD), so the old 3.0 meant a move had to run $75 - an ENTIRE day's range - before the late-entry penalty even began, and the climax/hard-block levels above it were effectively unreachable. The trend-chasing protection was dead. At 1.2 (~$30) caution starts where a move is genuinely extended for a scalper whose target is $2.50.   // Extension (in ATR) beyond which the impulse bonus starts tapering toward neutral
input double            MoveExtensionMatureATR       = 1.2;   // Move extension mature ATR
// MoveExtensionClimaxATR: V121: 6.0 -> 2.4 (~$60). Full late-entry penalty by here - a move this far into its run is far more likely to retrace into the basket than to extend again.   // Extension beyond which a large impulse candle is treated as a CLIMAX warning, not confirmation
input double            MoveExtensionClimaxATR       = 2.4;   // Move extension climax ATR
// MoveExtensionClimaxScore: Score returned in the climax case - deliberately below neutral: at this point the impulse argues AGAINST joining, not for it
input double            MoveExtensionClimaxScore     = 0.25;   // Move extension climax score
// EnableStandaloneMoveExtension: V31.6z54: the extension check above only ran when a big impulse candle qualified - but a long, grinding trend needs no dramatic candle, so an entry at the exhausted extreme of a multi-day move went completely unflagged
input bool              EnableStandaloneMoveExtension = true;   // Enable standalone move extension
// StandaloneMoveExtensionMaxPenalty: V121: 3 -> 5. Entering at the end of an extended trend is one of the most expensive mistakes this EA makes (it opens at the worst price and the retrace becomes deep DD), so it deserves more than a nudge. // Penalty at full climax extension, scaling up from zero at MoveExtensionMatureATR
input int               StandaloneMoveExtensionMaxPenalty = 5;   // Standalone move extension max penalty
input int               ImpulseScoreBonus            = 2;   // Impulse score bonus
input bool              ImpulsePrintOnUse            = true;   // Impulse print on use (on/off)

// FEATURE(impulse-end-hardblock): direct user request - "if the impulse is SELL, do NOT open
// another SELL at the very bottom; if BUY, do NOT open another BUY at the very top". The
// existing MoveExtension / ImpulseConfirmation logic above only ever applied a -penalty, which
// a strong signal can out-score at the low MinScore thresholds, so a late continuation entry
// into an exhausted move could STILL fire. This is a true HARD BLOCK for that exact case:
// entering in the SAME direction as a move that has already run to a climax extension. It sits
// on top of the penalty system (does not replace it) and reuses the same MoveExtensionATR
// measurement already trusted above, so there's one coherent definition of "the move's end".
// EnableImpulseEndHardBlock: V186: hard blok -> jazo. impuls oxirida kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableImpulseEndHardBlock    = false;   // Enable impulse end hard block
// ImpulseEndHardBlockATR: V121: 7.0 -> 3.2 (~$80). Hard refusal once a move has run more than a full day's range in one direction - chasing it there is not a scalp, it is buying the top.    // V36b: lowered 9.0 -> 7.0. Climax is defined at 6 ATR (MoveExtensionClimaxATR) but the hard block only fired at 9, leaving a 6-9 ATR gap where entries into an already-exhausted move slipped through. 7 closes most of that gap while still allowing a genuinely strong trend a little room past climax.
input double            ImpulseEndHardBlockATR       = 3.2;   // Impulse end hard block ATR
// ImpulseEndHardBlockRespectTrend: If the move is extended BUT the global trend still strongly agrees with our direction, this is trend continuation, NOT exhaustion - so do not hard-block. Only blocks an extended move that has LOST its trend backing.
input bool              ImpulseEndHardBlockRespectTrend = true;   // Impulse end hard block respect trend (on/off)
// ImpulseEndHardBlockTrendConf: V55b: 0.65 -> 0.40. GlobalTrendConfidence is (ADX-20)/35 averaged over D1/H4/H1, so it realistically tops out near 0.6; 0.65 needed ADX ~43 on all three at once and therefore almost never fired. The whole point of this input is to let a strong trend continue past an extended move - at 0.65 that exception was dead and the block vetoed trend continuation too.
input double            ImpulseEndHardBlockTrendConf = 0.40;   // Impulse end hard block trend confidence
// EnableImpulseAgainstHardBlock: impulse-AGAINST fires on ANY strong opposite candle, which precedes good support-bounce / resistance-bounce entries - vetoing those made the bot timid. Off by default; still costs score points via the penalty.
input bool              EnableImpulseAgainstHardBlock = false;   // Enable impulse against hard block

// FEATURE(collapse-bottom-guard): the mirror of the resistance-BUY problem. When price has fallen
// hard and fast over the last few bars, opening a SELL at the BOTTOM of that drop (continuing the
// move) is entering right where a snap-back is most likely - which is exactly how a SELL got caught
// on the $61 M15 drop that then reversed. This is SPEED-based, not the 7-ATR climax test: a $61
// (2.4 ATR) drop never reached the climax threshold, so nothing blocked it. Measures the recent
// swing over a short window; if the drop/rise exceeds the threshold, entries CONTINUING the move
// are blocked (SELL at the bottom of a fast drop, BUY at the top of a fast rise). 3-digit: 1000pt=$1.
// EnableCollapseBottomGuard: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableCollapseBottomGuard    = true;   // Enable collapse bottom guard
// CollapseGuardTF: Timeframe the recent swing is measured on
input ENUM_TIMEFRAMES   CollapseGuardTF              = PERIOD_M15;   // Collapse guard TF
// CollapseGuardLookbackBars: How many bars back to measure the move (8 x M15 = 2 hours)
input int               CollapseGuardLookbackBars    = 8;   // Collapse guard lookback bars
// CollapseGuardMinPoints: V73b: 15000 -> 25000 ($25) on user request. XAUUSD moves $70-80/day, so $15 over 2 hours was only ~20% of a normal day and fired too readily. $25 in 2 hours is a genuinely sharp move (a third of a day's range).
input int               CollapseGuardMinPoints       = 25000;   // Collapse guard min points
// CollapseGuardHardBlock: V186: hard blok -> jazo. kollaps ostida kirish - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // true = hard-block the continuation entry; false = penalty only
input bool              CollapseGuardHardBlock       = false;   // Collapse guard hard block (on/off)
// CollapseGuardScorePenalty: Score penalty when not hard-blocking
input int               CollapseGuardScorePenalty    = 4;   // Collapse guard score penalty
// Second, LONGER window so a slow but sustained collapse (e.g. price sliding down all day from the
// 09:30 high) is caught too - the short window above only sees a fast drop and would miss a gentle
// multi-hour decline. Either window triggering is enough. 3-digit: 1000pt = $1.
// CollapseGuardLongLookbackBars: Longer window (32 x M15 = 8 hours) for a sustained, day-long move
input int               CollapseGuardLongLookbackBars = 32;   // Collapse guard long lookback bars
// CollapseGuardLongMinPoints: V73b: 30000 -> 45000 ($45) on user request. Over the 8-hour window this is a strong sustained trend (~60% of a day) - it comfortably catches the live "$61 slide from the 09:30 high" case while letting ordinary intraday swings through.
input int               CollapseGuardLongMinPoints    = 45000;   // Collapse guard long min points

// FEATURE(blowoff-hardblock): the single most dangerous entry in a fast market - jumping in the
// SAME direction as a huge climactic "blow-off" candle that just printed. MoveExtensionATR
// measures how far the whole move has run, but it can miss a violent single-bar spike that
// hasn't yet accumulated many ATRs of total travel. This checks the raw candle: if the signal
// bar (or the one before it) is a giant bar in our intended direction - range >= X * ATR - we
// are trying to buy the very top / sell the very bottom of a spike, so hard-block it. Opposite
// (reversal / bounce) entries are never touched; only same-direction continuation into the spike.
// EnableBlowOffHardBlock: V186: hard blok -> jazo. blow-off shamdan keyin - bu haqiqiy ogohlantirish, lekin blok ballni BUTUNLAY chetlab o'tadi, ya'ni kuchli setup ham o'z fikrini bildira olmaydi. Modul o'chmaydi: uning jazosi ballga boradi va lot bilan TP ni kichraytiradi. Savdo bo'ladi, lekin ehtiyot bilan.   // V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableBlowOffHardBlock       = false;   // Enable blow off hard block
// BlowOffCandleATRMult: A bar whose range >= this * ATR counts as a blow-off climax candle
input double            BlowOffCandleATRMult         = 2.5;   // Blow off candle ATR multiplier
// BlowOffLookbackBars: Check the last N closed bars for a blow-off in our direction (1 = only the most recent)
input int               BlowOffLookbackBars          = 2;   // Blow off lookback bars
input bool              BlowOffHardBlockPrintOnUse   = true;   // Blow off hard block print on use (on/off)
input bool              ImpulseEndHardBlockPrintOnUse = true;   // Impulse end hard block print on use (on/off)

input group "ADVANCED ▸ Competing reversal signal caution"
// Trend Reversal (swing/RSI-based) already applies universally, but our 5 dedicated
// reversal-PATTERN detectors (Sweep, FBR, Near-Zone, Exhaustion, Range Edge) only ever get
// checked as candidates for winning the scanner - if a continuation entry wins instead, any
// of these 5 firing in the OPPOSITE direction is silently discarded. This re-checks them
// specifically as a caution signal when taking a continuation-type entry.
input bool              EnableCompetingReversalCaution = true;   // Enable competing reversal caution
// CompetingReversalMinScore: Minimum score the competing reversal detector must show to count
input int               CompetingReversalMinScore    = 3;   // Competing reversal min score
input int               CompetingReversalPenalty     = 2;   // Competing reversal penalty

input group "ADVANCED ▸ Recent zone break (premium)"
// Zone Polarity Flip already exists but lives quietly INSIDE ZoneMapStrength as a background
// nudge - never its own visible signal. This gives a FRESH, confirmed zone break (price
// closing decisively through a strong level) its own prominent, standalone weight - same
// "recent event" pattern as Major Sweep and Engulfing, applied universally to entries.
input bool              EnableRecentZoneBreak        = true;   // Enable recent zone break
// ZoneBreakTF: V110: the break scan used to run on SignalTF (M1), so even 30 bars only remembered a break for 30 MINUTES. Live chart: price broke upward and ran ~$160 over TWO DAYS, and the bot was still selling into it because the break had long since dropped out of view. Measuring on M15 puts the scan on a structural scale while staying precise enough to catch the breaking candle.
input ENUM_TIMEFRAMES   ZoneBreakTF                  = PERIOD_M15;   // Zone break TF
// ZoneBreakLookbackBars: V110: 30 -> 96, now measured on ZoneBreakTF. 96 x M15 = 24 HOURS of break memory, so a breakout still counts during the retest that follows it a day later. Raise toward 192 (2 days) if the bot still fades day-old breaks; lower toward 48 (12h) if too many ordinary setups get penalised.
input int               ZoneBreakLookbackBars        = 96;   // Zone break lookback bars
input int               ZoneBreakSearchPoints        = 300;   // Zone break search points
input double            ZoneBreakMinStrength         = 1.5;   // Zone break min strength
// ZoneBreakScoreBonus: Higher than Major Sweep/Engulfing (2) - deliberately "premium" weight
input int               ZoneBreakScoreBonus          = 3;   // Zone break score bonus
// ZoneBreakAgainstPenalty: V108b: separate, LARGER penalty for entering AGAINST a recent break (was reusing the +3 bonus as a -3 penalty). Fading a level that just broke is the live-trading loss this fixes: after an upward break the level is support and buyers are in control, so a SELL there needs to clear a much higher bar than a normal setup.
input int               ZoneBreakAgainstPenalty      = 5;   // Zone break against penalty

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
// EnableMarketStructure: Read the swing chain (HH/HL vs LH/LL) as a single structural reading
input bool              EnableMarketStructure        = true;   // Enable market structure
// MarketStructureTF: Timeframe the swing chain is read on. M15 is the scalper's structural frame; H1 for a slower, broader read.
input ENUM_TIMEFRAMES   MarketStructureTF            = PERIOD_M15;   // Market structure TF
// MarketStructureMinSteps: How many of the four chain checks must agree before a direction is declared (3 = allow one imperfect step; 4 = only perfect chains)
input int               MarketStructureMinSteps      = 3;   // Market structure min steps
// MarketStructureAgainstPenalty: Score penalty for a first entry that fights a confirmed structure
input int               MarketStructureAgainstPenalty = 4;   // Market structure against penalty
// MarketStructureHardBlock: false = penalty only (recommended to start). true = hard-block entries against a confirmed structure.
input bool              MarketStructureHardBlock     = false;   // Market structure hard block (on/off)
// MarketStructurePrintOnUse: Log the structural reading when it affects a decision
input bool              MarketStructurePrintOnUse    = false;   // Market structure print on use (on/off)
// MarketStructureBOSBonus: Bonus for entering in the direction of a structure that just EXTENDED (Break of Structure) - the chain confirmed itself
input int               MarketStructureBOSBonus      = 2;   // Market structure BOS bonus
// MarketStructureCHoCHReleases: When a CHoCH fires (the chain just broke), stop penalising entries against the old structure. Without this the EA would keep defending a structure that has already failed and would miss every reversal. Highly recommended ON.
input bool              MarketStructureCHoCHReleases = true;   // Market structure c ho ch releases (on/off)
// MarketStructureCHoCHPenalty: Penalty for entering WITH the old structure right after it broke (CHoCH) - continuing a chain that just failed
input int               MarketStructureCHoCHPenalty  = 3;   // Market structure c ho ch penalty

// V112: the higher-timeframe frame the trading structure sits inside. Reading only one timeframe was
// the remaining simplification: a bearish M15 chain means "sell" under a bearish H1, but under a
// BULLISH H1 the same chain is just a pullback - and selling into it is exactly the losing entry
// seen in live testing. Reading both and naming the relationship is what a trader does out loud.
// EnableStructureHTF: Also read the structure on a higher timeframe and combine the two into one context
input bool              EnableStructureHTF           = true;   // Enable structure HTF
// StructureHTF: The higher frame (H1 for an M15 trading structure; H4 for a slower read)
input ENUM_TIMEFRAMES   StructureHTF                 = PERIOD_H1;   // Structure HTF
// StructurePullbackFadePenalty: Penalty for trading WITH a lower-TF counter-move against the higher frame (i.e. selling a pullback inside an uptrend)
input int               StructurePullbackFadePenalty = 4;   // Structure pullback fade penalty
// StructureAlignedBonus: Bonus when both frames agree and the entry goes with them
input int               StructureAlignedBonus        = 2;   // Structure aligned bonus

// V116: use the structure reading on the OPEN basket, not just on new entries. Until now every
// structural insight was spent deciding whether to open a trade, while baskets already in drawdown
// rode out the very turn the reader could see. When the structure that supported a basket breaks
// (CHoCH), or the opposing structure extends (BOS against us), the basket is swimming upstream:
// take the smaller bounce that is still on offer instead of waiting for the original target.
// EnableStructureBasketExit: Let the structure reading manage OPEN baskets, not just entries
input bool              EnableStructureBasketExit    = true;   // Enable structure basket exit
// StructureBreakTPFactor: When structure turns against the basket, shrink the take-profit to this fraction (0.6 = exit on 60% of the original target). Never goes below BasketTPMinPoints.
input double            StructureBreakTPFactor       = 0.6;   // Structure break TP factor
// StructureBreakCountsAsExitConfirm: Count a structural turn against the basket as one SmartEarlyExit confirmation
input bool              StructureBreakCountsAsExitConfirm = true;   // Structure break counts as exit confirm (on/off)
// StructureBasketExitPrintOnUse: Log when the structure shortens a basket's target
input bool              StructureBasketExitPrintOnUse = true;   // Structure basket exit print on use (on/off)

// V117: consensus. Each reading already speaks for itself; this asks whether they agree. Unanimity
// across independent mechanisms (swings, zone behaviour, indicators) is the strongest signal this EA
// can produce, while a genuine split means the market has no owner yet - the honest response there
// is to wait, not to average the disagreement into a middling score.
// EnableMarketVerdict: Measure agreement across the independent direction readings
input bool              EnableMarketVerdict          = true;   // Enable market verdict
// VerdictMinActiveSources: At least this many readings must have an opinion before a verdict is declared
input int               VerdictMinActiveSources      = 3;   // Verdict min active sources
// VerdictTrendMinConfidence: Trend confidence needed before global/local trend counts as a vote (below this it abstains)
input double            VerdictTrendMinConfidence    = 0.30;   // Verdict trend min confidence
// VerdictStrongAgreeCount: Votes needed to call the consensus STRONG
input int               VerdictStrongAgreeCount      = 4;   // Verdict strong agree count
// VerdictStrongBonus: Bonus for entering with a strong consensus
input int               VerdictStrongBonus           = 3;   // Verdict strong bonus
// VerdictAgainstPenalty: Penalty for entering against a strong consensus
input int               VerdictAgainstPenalty        = 4;   // Verdict against penalty
// VerdictSplitPenalty: Penalty for entering while the readings are genuinely split (market without an owner)
input int               VerdictSplitPenalty          = 2;   // Verdict split penalty
// MarketVerdictPrintOnUse: Log the verdict each bar
input bool              MarketVerdictPrintOnUse      = false;   // Market verdict print on use (on/off)

// V118: room to target. Direction is only half the question - the other half is whether there is
// space in front of the entry for the target to be reached. On a ~$2.50 scalp target, opening into
// a wall $1.00 away is opening a trade that structurally cannot finish. The check measures the
// distance to the nearest thing in the way (opposing zone, or the structure's continuation level)
// and compares it against the basket target.
// EnableRoomCheck: Require space between entry and the nearest opposing level before taking a trade
input bool              EnableRoomCheck              = true;   // Enable room check
// RoomUseStructureLevel: Also treat the structure's continuation level as a wall, not just zones
input bool              RoomUseStructureLevel        = true;   // Room use structure level (on/off)
// RoomMinFactor: Room must be at least this multiple of the basket target (1.0 = at least as much space as the target needs)
input double            RoomMinFactor                = 1.0;   // Room min factor
// RoomTooTightPenalty: Penalty when there is less room than the target requires
input int               RoomTooTightPenalty          = 4;   // Room too tight penalty
// RoomHardBlock: V171: true -> false. Room is real, but the contextual TP now shrinks the target toward whatever room exists, so refusing as well means refusing trades the EA had already adapted to. Re-enable if the log shows entries still being taken into walls.
input bool              RoomHardBlock                = false;   // Room hard block (on/off)
// RoomPrintOnUse: Log the room measurement when it affects a decision
input bool              RoomPrintOnUse               = false;   // Room print on use (on/off)

// V119: zone role. A level's role is decided purely by whether it sits above or below price, which
// breaks inside a thick band: there the EA sees resistance just above AND support just below, births
// both a buy and a sell signal, and whichever scores higher wins. That is the reported "sell in a buy
// zone, buy in a sell zone" behaviour. Inside a band the role is genuinely undefined - wait for price
// to leave it and show which edge it respects.
// EnableZoneRoleCheck: Detect when price is INSIDE a zone band, where support/resistance roles are undefined
input bool              EnableZoneRoleCheck          = true;   // Enable zone role check
// ZoneBandUseM5: Cluster M5 swings into bands (small intraday zones)
input bool              ZoneBandUseM5                = true;   // Zone band use M5 (on/off)
// ZoneBandUseM15: Cluster M15 swings into bands (the scalper's main structural zones)
input bool              ZoneBandUseM15               = true;   // Zone band use M15 (on/off)
// ZoneBandUseH1: Cluster H1 swings into bands (the big levels drawn on a chart)
input bool              ZoneBandUseH1                = true;   // Zone band use H1 (on/off)
// ZoneBandATRMult: Band thickness is derived from each timeframe's OWN ATR x this, not a fixed dollar amount - small zones and large zones both exist, so the market sizes them. Raise for looser grouping (thicker bands), lower for tighter.
input double            ZoneBandATRMult              = 0.60;   // Zone band ATR multiplier
// ZoneBandMinTolerancePoints: Floor for the ATR-derived tolerance ($0.60) so a dead session can't collapse every band to a point
input int               ZoneBandMinTolerancePoints   = 600;   // Zone band min tolerance points
// ZoneBandMaxTolerancePoints: Ceiling for it ($9.00) so a volatility spike can't merge the whole chart into one band
input int               ZoneBandMaxTolerancePoints   = 9000;   // Zone band max tolerance points
// ZoneBandSearchPoints: Only consider swings within this distance of price ($20) when looking for a band
input int               ZoneBandSearchPoints         = 20000;   // Zone band search points
// ZoneBandMinTouches: A band must contain at least this many swings - two stray points are not a zone
input int               ZoneBandMinTouches           = 3;   // Zone band min touches
// ZoneRoleAmbiguityPenalty: Penalty for entering while the role is undefined
input int               ZoneRoleAmbiguityPenalty     = 5;   // Zone role ambiguity penalty
// ZoneRoleHardBlock: V193: oxirgi blok ham jazoga. Har skrinshotda BOSHQA sabab chiqdi - ya'ni to'siqlar ketma-ket joylashgan va bittasini tuzatgach keyingisi ushlaydi. Bu bloklarni bittalab ochish bilan hal bo'lmaydi: hammasi bir vaqtda jazoga o'tishi kerak, keyin jonli natija qaysi biri haqiqatan kerakligini ko'rsatadi. CounterZone yagona istisno - u o'lchangan zararni to'sadi.
input bool              ZoneRoleHardBlock            = false;   // Zone role hard block (on/off)

// CounterZoneHardBlock: V191: qayta BLOK. Bu yagona filtr bo'lib, u JONLI o'lchangan zararni to'sadi - sizning -819.90 zararingiz aynan shu naqsh edi (SELL support ustida). Boshqa bloklar nazariy asosga ega, bu esa haqiqiy hisobdagi pulga. Chegaralari qattiq ($3.50 masofa, kuchlilik >=1.8), ya'ni u kamdan-kam ishlaydi va savdo chastotasiga sezilarli ta'sir qilmaydi.
input bool   CounterZoneHardBlock            = true;   // Counter zone hard block (on/off)
// CounterZoneScorePenalty: V190: kuchli zonaga qarshi kirish jazosi - sifat guruhiga boradi
input int    CounterZoneScorePenalty         = 5;   // Counter zone score penalty
// RangeBreakoutHardBlock: V190: tasdiqlangan breakoutni so'ndirish - jazo rejimi
input bool   RangeBreakoutHardBlock          = false;   // Range breakout hard block (on/off)
// RangeBreakoutFadePenalty: V190: breakoutga qarshi kirish jazosi - trend guruhiga
input int    RangeBreakoutFadePenalty        = 4;   // Range breakout fade penalty
// FreshImpulseWaitHardBlock: V190: yangi impuls kutish - jazo rejimi. Kutish o'zi bloklash, va u impuls yoshiga qarab avtomatik tugaydi.
input bool   FreshImpulseWaitHardBlock       = false;   // Fresh impulse wait hard block (on/off)
// FreshImpulseWaitPenalty: V190: yangi impulsdan keyin darrov kirish jazosi
input int    FreshImpulseWaitPenalty         = 3;   // Fresh impulse wait penalty
// ZoneRolePrintOnUse: Log when an entry is refused or penalised for an undefined zone role
input bool              ZoneRolePrintOnUse           = true;   // Zone role print on use (on/off)

// V140: liquidity map. The EA recognises a sweep only after it has happened, which is too late to
// act on. Stops cluster just beyond swing extremes, and most heavily where several swings line up at
// the same level - equal highs are a shelf of buy-stops, equal lows a shelf of sell-stops. Price is
// drawn to those shelves, which is why markets so often run to an obvious high, take it, and turn.
// Knowing the pool is there BEFORE the run means the entry can wait and be taken from the far side
// of it instead of being run over on the way.
// EnableLiquidityMap: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableLiquidityMap       = true;   // Enable liquidity map
// LiquidityMapTF: Timeframe whose swing extremes form the pools
input ENUM_TIMEFRAMES   LiquidityMapTF           = PERIOD_M15;   // Liquidity map TF
// LiquidityClusterPoints: V170f: 1500 -> 700 ($0.70). Equal highs that the market actually reacts to sit 200-600 points apart; at $1.50 tolerance three unrelated swings merged into one "pool", inflating its weight and hiding how tight the real cluster was. Now consistent with PathDensityMergePoints, which answers the same question - when are two levels one level.
input int               LiquidityClusterPoints   = 700;   // Liquidity cluster points
// LiquidityMapSearchPoints: Only consider pools within this distance of price ($12)
input int               LiquidityMapSearchPoints = 12000;   // Liquidity map search points
// LiquidityMinSwings: Aligned swings needed to call it a pool (2 = a clean double top/bottom)
input int               LiquidityMinSwings       = 2;   // Liquidity min swings

// V172: every penalty added this session was sized as though it were the only new one. Twenty of
// them are now live, and a live reading showed penalty=25 against a bonus ceiling of 12 - the score
// could not recover from conditions that were merely unremarkable. These are halved roughly across
// the board: each still says what it said, but the sum now leaves room for the setup to argue back.
// LiquidityAheadPenalty: V173: 2 -> 4. narx avval hovuzga chopadi - entry o\'sha yugurishni sotib oladi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.      // Penalty for entering INTO a pool that price will likely run to first
input int               LiquidityAheadPenalty    = 4;   // Liquidity ahead penalty
// LiquidityMinWeight: Pool weight needed before it affects the decision at all
input double            LiquidityMinWeight       = 2.5;   // Liquidity min weight
// LiquidityNearPoints: A pool further away than this ($5) is too distant to matter for a scalp
input int               LiquidityNearPoints      = 5000;   // Liquidity near points
// LiquidityPrintOnUse: Log pools that change a decision
input bool              LiquidityPrintOnUse      = true;   // Liquidity print on use (on/off)

// V142: event chain. Every event the EA detects - a level breaking, a thrust, a structure flip, a
// sweep - is scored the instant it appears and then forgotten. Nothing asks what came BEFORE it,
// yet that is exactly what gives an event its meaning: a CHoCH after a sweep is a reversal, the
// same CHoCH without one is often just noise. Recording events in order is the groundwork for
// reading the market as a sequence rather than a series of snapshots.
// EnableEventChain: Record market events in order so the sequence can be read, not just the latest event
input bool              EnableEventChain         = true;   // Enable event chain
// EventChainDedupeBars: The same event kind and direction within this many bars is treated as one event still developing
input int               EventChainDedupeBars     = 3;   // Event chain dedupe bars
// EventChainPrintOnUse: Log every event appended to the chain (verbose - for tuning)
input bool              EventChainPrintOnUse     = false;   // Event chain print on use (on/off)
// ShowEventChainOnDash: V170d: default OFF. hodisalar zanjiri - bashorat qatori uni allaqachon xulosalaydi. Seventeen new dashboard lines were added today and all defaulted on - together they push the panel past the height of a normal chart window, hiding the lines that matter during trading.
input bool              ShowEventChainOnDash     = false;   // Show event chain on dashboard

// V143: reading the chain. Certain sequences carry a well-known meaning, and the meaning is in the
// ORDER: a sweep followed by a CHoCH against it is a reversal, while the same sweep followed by a
// BOS the same way is continuation. One event, opposite conclusions, decided entirely by what came
// next. These confidences say how much each recognised sequence is worth; an unrecognised chain
// returns nothing rather than guessing.
// EnableChainExpectation: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableChainExpectation   = true;   // Enable chain expectation
// ChainExpectationMaxAgeBars: A chain older than this describes a market that has moved on
input int               ChainExpectationMaxAgeBars = 12;   // Chain expectation max age bars
// ChainExpectationTightBars: Links formed further apart than this are only loosely related - confidence fades
input int               ChainExpectationTightBars  = 8;   // Chain expectation tight bars
// ChainConfSweepReversal: sweep -> CHoCH against it: the run was for stops and is finished
input double            ChainConfSweepReversal     = 0.80;   // Chain confidence sweep reversal
// ChainConfSweepContinuation: sweep -> BOS same way: liquidity became fuel, not a turn
input double            ChainConfSweepContinuation = 0.70;   // Chain confidence sweep continuation
// ChainConfImpulseExhaustion: impulse -> CHoCH: the thrust is spent
input double            ChainConfImpulseExhaustion = 0.65;   // Chain confidence impulse exhaustion
// ChainConfExpansion: range break -> impulse: expansion usually continues
input double            ChainConfExpansion         = 0.60;   // Chain confidence expansion
// ChainConfBreakConfirmed: zone break -> BOS: continuation
input double            ChainConfBreakConfirmed    = 0.65;   // Chain confidence break confirmed
// ChainConfNewTrend: CHoCH -> BOS the same way: a new direction confirmed itself
input double            ChainConfNewTrend          = 0.75;   // Chain confidence new trend
// ChainExpectWithBonus: Bonus for entering WITH what the chain expects
input int               ChainExpectWithBonus       = 3;   // Chain expect with bonus
// ChainExpectAgainstPenalty: V173: 3 -> 4. hodisalar ketma-ketligi teskari aytadi. Bu SIFAT jazosi, sharoit emas - v172 da ikkalasi bir xil pasaytirilgan edi, va bu botni haqiqiy xavflarga ham befarq qildi.    // Penalty for entering AGAINST it
input int               ChainExpectAgainstPenalty  = 4;   // Chain expect against penalty
// ChainExpectMinConfidence: Confidence needed before the expectation affects the decision at all
input double            ChainExpectMinConfidence   = 0.60;   // Chain expect min confidence
// ChainExpectPrintOnUse: Log expectations that change a decision
input bool              ChainExpectPrintOnUse      = true;   // Chain expect print on use (on/off)

// V144: scenarios. Every module produces a direction and the EA reduces them to one answer, which
// throws away the most useful part of the reading: "45/30/25" and "80/10/10" both name the same
// winner but describe opposite markets - one with no owner, one with a clear one. Weighing the
// sources into three buckets keeps that distinction. A narrow margin is not a weak signal to trade
// smaller; it is a market that has not decided, and standing aside is the honest response.
// EnableScenarios: V182: back ON. Turning these off restored the trade frequency but threw away the reasoning with it - which is the whole reason they were built. They stay active; what changed is what they DO, see below.
input bool              EnableScenarios          = true;   // Enable scenarios
// ScenarioWeightChain: Weight of the event chain - the only source reading SEQUENCE rather than state
input double            ScenarioWeightChain      = 2.0;   // Scenario weight chain
// ScenarioWeightStructure: Weight of each swing-structure frame
input double            ScenarioWeightStructure  = 1.5;   // Scenario weight structure
// ScenarioWeightStaircase: Weight of the broken-level staircase
input double            ScenarioWeightStaircase  = 1.5;   // Scenario weight staircase
// ScenarioWeightTrend: Weight of each indicator trend scale
input double            ScenarioWeightTrend      = 1.0;   // Scenario weight trend
// ScenarioWeightLiquidity: Weight of a stop pool pulling price toward it
input double            ScenarioWeightLiquidity  = 1.2;   // Scenario weight liquidity
// ScenarioMinMargin: Lead over the runner-up needed to call the market decided (0.20 = 20 points). Below this the readings are split.
input double            ScenarioMinMargin        = 0.20;   // Scenario min margin
// ScenarioUndecidedPenalty: Penalty for entering while the scenarios are this close - the market has not chosen a side
input int               ScenarioUndecidedPenalty = 2;   // Scenario undecided penalty
// ScenarioPrintOnUse: Log the scenario split each time it affects a decision
input bool              ScenarioPrintOnUse       = false;   // Scenario print on use (on/off)
// ShowScenariosOnDash: Show the split on the dashboard
input bool              ShowScenariosOnDash      = true;   // Show scenarios on dashboard

// V145: the chain grades its own predictions. The confidences above were set by hand - reasonable,
// but unverified on this symbol. Every prediction is now recorded and scored a fixed number of bars
// later, and the tally feeds back into the confidence. Evidence is blended in gradually so a thin
// sample cannot overwrite a considered prior, and the tallies decay so a pattern that has stopped
// working loses its reputation instead of trading on an old reputation forever.
// EnableChainLearning: Let recorded outcomes adjust each chain pattern's confidence
input bool              EnableChainLearning      = true;   // Enable chain learning
// ChainLearningHorizonBars: Bars after a prediction before it is graded
input int               ChainLearningHorizonBars = 15;   // Chain learning horizon bars
// ChainLearningWinPoints: Move needed to call the prediction right or wrong (3-digit: 1500 = $1.50). Anything smaller is noise and is discarded.
input int               ChainLearningWinPoints   = 1500;   // Chain learning win points
// ChainLearningShrinkage: How much evidence is needed before the measured rate outweighs the configured one. Higher = slower to trust new data.
input double            ChainLearningShrinkage   = 12.0;   // Chain learning shrinkage
// ChainLearningMaxSamples: Tally ceiling per pattern; beyond it older evidence decays so behaviour can change
input int               ChainLearningMaxSamples  = 60;   // Chain learning max samples
// ChainLearningPrintOnUse: Log every graded prediction
input bool              ChainLearningPrintOnUse  = true;   // Chain learning print on use (on/off)

// V113: the break SEQUENCE - the staircase. On the live chart the user marked four levels broken in
// turn (4020 -> 4050 -> 4070 -> 4165), each becoming support: that progression is the plainest
// statement that buyers are in control, and the EA could not see it because its break detector
// stopped at the first break it found. Counting the whole window turns "a break happened" into
// "price has been climbing a staircase of broken levels".
// EnableBreakSequence: Count all zone breaks in the window instead of only the most recent one
input bool              EnableBreakSequence          = true;   // Enable break sequence
// BreakSequenceLookbackBars: Window on ZoneBreakTF (192 x M15 = 2 days) - a staircase takes time to build
input int               BreakSequenceLookbackBars    = 192;   // Break sequence lookback bars
// BreakSequenceMinCount: How many one-sided breaks make a staircase (2 = a level broken, then the next one)
input int               BreakSequenceMinCount        = 2;   // Break sequence min count
// BreakSequenceDedupePoints: Levels within this distance count as the SAME zone (3-digit: 800 = $0.80), so one zone broken over several bars isn't counted twice
input int               BreakSequenceDedupePoints    = 800;   // Break sequence dedupe points
// BreakSequenceWithBonus: Bonus for entering in the direction of a confirmed staircase
input int               BreakSequenceWithBonus       = 3;   // Break sequence with bonus
// BreakSequenceAgainstPenalty: Penalty for entering against a confirmed staircase - fading a market that is stepping through level after level
input int               BreakSequenceAgainstPenalty  = 5;   // Break sequence against penalty
input bool              ZoneBreakPrintOnUse          = true;   // Zone break print on use (on/off)

input group "ADVANCED ▸ Smart trail acceleration"
// The one part of the trade lifecycle none of today's new senses ever reached: exit/trailing
// was purely mechanical (fixed 300-point follow distance regardless of what's happening).
// This does NOT change WHEN trailing arms (BasketTrailStartPoints stays as-is) - it only
// tightens the follow distance once armed, when Trend Reversal, Recent Zone Break, Impulse,
// or Trend Quality show warning signs against the basket's direction, locking profit in
// faster instead of blindly giving back the full step regardless of deteriorating conditions.
input bool              EnableSmartTrailTightening   = true;   // Enable smart trail tightening
// SmartTrailMinStepPoints: Tightest the follow distance can go with maximum warnings
input int               SmartTrailMinStepPoints      = 100;   // Smart trail min step points
// SmartTrailWarningsForMaxTighten: Warnings needed (out of 4 checks) to reach the minimum step
input int               SmartTrailWarningsForMaxTighten = 3;   // Smart trail warnings for max tighten
input bool              SmartTrailPrintOnUse         = true;   // Smart trail print on use (on/off)

input group "ADVANCED ▸ Grid-vs-trailing safety check"
// Grid Intelligence and the trailing/profit-lock system had zero awareness of each other -
// found during today's professional audit. If the basket is already in profit-trailing mode,
// adding more exposure via grid is philosophically backwards.
input bool              EnableGridTrailSafetyCheck   = true;   // Enable grid trail safety check

input group "ADVANCED ▸ Impulse exhaustion warning"
// Real gap found via live testing: grid kept adding BUY right as a sharp rally was visibly
// topping out (shrinking bullish bodies + growing upper-wick rejection) - the SAME-direction
// momentum a basket rides was never checked for deceleration, only whether a candle recently
// agreed with direction (Impulse Confirmation). This is the missing complement.
input bool              EnableImpulseExhaustionWarning = true;   // Enable impulse exhaustion warning
// ImpulseExhaustionWickRatio: Rejection wick must be at least this fraction of the candle range
input double            ImpulseExhaustionWickRatio   = 0.4;   // Impulse exhaustion wick ratio
// ImpulseExhaustionShrinkFactor: Current body must shrink to at most this fraction of the prior body
input double            ImpulseExhaustionShrinkFactor = 0.6;   // Impulse exhaustion shrink factor
input int               ImpulseExhaustionPenalty     = 3;   // Impulse exhaustion penalty
input bool              ImpulseExhaustionPrintOnUse  = true;   // Impulse exhaustion print on use (on/off)

input group "ADVANCED ▸ Deceleration awareness (systematic audit follow-up)"
// Four more instances of the SAME pattern found via deeper audit: checking if something IS
// strong right now, but never whether it's GETTING WEAKER. ADX slope, MA convergence, waning
// volume, and the basket's own track record of prior grid additions.
input bool              EnableADXDeceleration        = true;   // Enable ADX deceleration
// ADXDecelerationMinDrop: Minimum ADX drop vs N bars ago to count as decelerating
input double            ADXDecelerationMinDrop       = 5.0;   // ADX deceleration min drop
input int               ADXDecelerationLookbackBars  = 5;   // ADX deceleration lookback bars
input bool              EnableMAConvergenceCheck     = true;   // Enable MA convergence check
input int               MAConvergenceLookbackBars    = 8;   // MA convergence lookback bars
// MAConvergenceThreshold: Current fast-slow MA spread must be below this fraction of the prior spread to count as "converging"
input double            MAConvergenceThreshold       = 0.7;   // MA convergence threshold
input bool              EnableVolumePushWaningCheck  = true;   // Enable volume push waning check
// VolumePushWaningThreshold: Most recent bar's conviction ratio must be below this fraction of the oldest bar's to count as "waning"
input double            VolumePushWaningThreshold    = 0.6;   // Volume push waning threshold
input int               VolumePushWaningPenalty      = 2;   // Volume push waning penalty
input bool              EnableBasketAdverseStreakCheck = true;   // Enable basket adverse streak check
// BasketAdverseStreakMinCount: Consecutive grid additions with no intervening recovery before extra caution kicks in
input int               BasketAdverseStreakMinCount  = 2;   // Basket adverse streak min count
// BasketAdverseStreakBoostMultiplier: How much faster the depth threshold rises once the streak triggers
input double            BasketAdverseStreakBoostMultiplier = 1.5;   // Basket adverse streak boost multiplier

input group "ADVANCED ▸ Deceleration awareness round 2"
// Four MORE instances of the same pattern, found via a second, deeper audit pass: basket DD
// rate-of-change, candle-size progression, RSI extreme-cooling, and DXY's own deceleration.
input bool              EnableBasketDDAcceleration   = true;   // Enable basket DD acceleration
// BasketDDAccelWindowBars: Bars per comparison window (recent vs older)
input int               BasketDDAccelWindowBars      = 4;   // Basket DD accel window bars
// BasketDDAccelRatioThreshold: Recent worsening rate must exceed the older rate by this multiple to count as "accelerating"
input double            BasketDDAccelRatioThreshold  = 1.4;   // Basket DD accel ratio threshold
// BasketDDAccelMinFreshRate: Minimum %/bar worsening rate to flag a fresh acceleration starting from a calm baseline
input double            BasketDDAccelMinFreshRate    = 1.0;   // Basket DD accel min fresh rate
// BasketDDAccelBoostMultiplier: How much faster the grid depth threshold rises when DD is accelerating
input double            BasketDDAccelBoostMultiplier = 1.6;   // Basket DD accel boost multiplier
input bool              EnableCandleSizeProgression  = true;   // Enable candle size progression
// CandleSizeProgressionThreshold: Ratio needed to count as accelerating (or its inverse for decelerating)
input double            CandleSizeProgressionThreshold = 1.3;   // Candle size progression threshold
input int               CandleSizeDecelPenalty       = 2;   // Candle size decel penalty
input bool              EnableRSICooling             = true;   // Enable RSI cooling
input double            RSICoolingOverboughtLevel    = 65.0;   // RSI cooling overbought level
input double            RSICoolingOversoldLevel      = 35.0;   // RSI cooling oversold level
// RSICoolingMinDrop: Minimum RSI point change vs N bars ago to count as cooling/warming
input double            RSICoolingMinDrop            = 5.0;   // RSI cooling min drop
input bool              EnableDXYDeceleration        = true;   // Enable DXY deceleration
// DXYDecelerationThreshold: Recent-window slope must be below this fraction of the older-window slope to count as decelerating
input double            DXYDecelerationThreshold     = 0.6;   // DXY deceleration threshold

input group "ADVANCED ▸ Exhaustion consensus (unified, non-linear)"
// Ties together ADX slope, RSI cooling, candle-level Impulse Exhaustion, DXY deceleration,
// and basket DD acceleration into ONE non-linear score - genuine multi-signal agreement
// compounds rather than just adding, the same philosophy already proven for Grid Intelligence
// and AUTO Hunter Suitability. Replaces treating these as small, scattered, isolated checks.
input bool              EnableExhaustionConsensus    = true;   // Enable exhaustion consensus
// ExhaustionConsensusMinFactor: Minimum individual factor value to count as "triggered" for consensus purposes
input double            ExhaustionConsensusMinFactor = 0.3;   // Exhaustion consensus min factor
// ExhaustionConsensusExtraPenaltyStep: Additional compounding penalty per extra warning beyond 2
input double            ExhaustionConsensusExtraPenaltyStep = 0.04;   // Exhaustion consensus extra penalty step
// EnableDeepShockExhaustionInConsensus: V31.6z34 NEW: folds Deep News Volatility Brain's own shock-wick exhaustion check in as Factor 6, instead of leaving it as an isolated, uncoordinated signal
input bool              EnableDeepShockExhaustionInConsensus = true;   // Enable deep shock exhaustion in consensus
