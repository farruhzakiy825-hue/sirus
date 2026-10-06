# CHANGELOG — Sirus Brain V8

## 12-bosqich: o'lchov (profiler + soya buxgalteriyasi)

- **Profiler** (`EnableProfiler`):
  - har tik 9 bo'lak bo'yicha o'lchanadi: tayyorlov, miya, skaner, himoyalar, grid, kirish, post, soya, panel;
  - panel pastida o'rtacha va eng katta vaqt hamda eng og'ir bo'lak chiqadi;
  - jurnalga soatiga bir qator `[SIRUS PROF]` yoziladi.
- **Soya buxgalteriyasi** (`EnableShadowLedger`):
  - har rad etilgan setup yashirin kuzatiladi: TP ga yetadimi (TP), birinchi grid qadamigacha qaytadimi (GRID) yoki 30 daqiqada hech biri bo'lmaydimi (TIMEOUT);
  - natija rad etgan filtr nomi bilan yoziladi;
  - haqiqatan olingan kirishlar ham shu tarzda kuzatiladi va solishtirish uchun TAKEN deb yoziladi;
  - panelda `Soya: to'silgan … → TP …% · olingan … → TP …%` qatori chiqadi;
  - filtr yaxshi savdolarni to'sayotgan bo'lsa, ⚠ belgisi bilan ogohlantiradi;
  - har natija CSV ga yoziladi: `Sirus_Shadow_<symbol>_<magic>.csv`;
  - kun oxirida `[SIRUS SHADOW DAY]` xulosasi chiqadi: `BLOCKS-GOOD` / `EARNS-ITS-PLACE`.
- Savdo mantig'iga ta'siri yo'q.

## Savdo soni va yo'nalish: ikki qatlam, FVG, sham aniqligi, tezlik

- **Ikki qatlam muammosi hal qilindi** (`MBOwnsDuplicateGates`). Market Brain savdo tomonida bo'lsa, xuddi shu savolni beradigan eski filtrlar chetga turadi: joy himoyasi, Location Brain, impuls quvish, HTF bias, eski daraja, singan daraja va yo'nalish aniqligi. Javobni miya veto'si va hakami beradi.
  - Miya neytral bo'lsa, faqat ball solig'i filtrlari chetga turadi. Joy va HTF filtrlari qoladi.
  - Miya qarshi bo'lsa, ikkala qatlam ham ishlaydi.
  - Tezkor kirishlarda eski filtrlar har doim chetga turadi.
- **FVG xatosi tuzatildi.** Gap o'zining o'rta shami bilan "to'lgan" deb hisoblanardi, shuning uchun FVG zonalari umuman yo'q edi. Gaplar ro'yxati endi har M15 barda bir marta tuziladi.
- **Sham dvigateli tuzatildi:**
  - impuls tezligi so'nggi 30% pullbackdan o'lchanadi, endi trendda yolg'on "EXPIRED" chiqmaydi;
  - "EARLY" holati endi haqiqatan chiqadi;
  - to'lqinlar to'g'ri sanaladi;
  - muvaffaqiyatsiz jonli sham faqat M1 triggerini bekor qiladi;
  - BREAKOUT va CONTINUATION uchun sham tanasi kamida 0.3 ATR bo'lishi kerak;
  - narx 0.5 ATR qaytsa, M5 trigger bekor bo'ladi.
- **Tezlik:**
  - eng yaqin support/resistance qidiruvi bir tik ichida bir marta hisoblanadi;
  - panel chart rangini 3 soniyada bir marta o'qiydi;
  - vizual bo'lmagan testerda panel chizilmaydi.
- **Panel:** "Jimlik N daq" qatori bugun eng ko'p to'sgan filtrlar bilan chiqadi. Gate registry endi "signal yo'q", "miya taqiqi" va "hakam kutdi" holatlarini ham sanaydi.

## Cashback tempi va aylanma paneli

- **Cashback tempi** (`EnableCashbackTempo`, faqat `EnableRebateMode` yoqilganda ishlaydi). Veto'lar o'zgarmaydi. O'zgarishlar:
  - Neytral bozorda kirish uchun joy YOKI trigger yetarli (oddiy rejimda ikkalasi ham kerak).
  - EHTIYOT va OCHISH sifat chegaralari `CashbackTempoQualityCut` (10) ga pasaytirildi.
  - Yutuqdan keyingi re-entry oynasi `CashbackReentryBars` (40 M1 bar) ga uzaytirildi.
  - Tezkor tezis kirishi endi FAOLLASHGAN tezisni ham qabul qiladi, 1 ta qarama-qarshilikka chidaydi.
- **Panelda "CASHBACK AYLANMASI" bo'limi**, faqat cashback rejimida ko'rinadi:
  - bugun, hafta, oy va jami lot aylanmasi hamda savdolar soni;
  - `CashbackPerLot` > 0 bo'lsa, taxminiy cashback $;
  - TP point, trailing holati va tempo.

## v31.68

- **Yangiliklar kalendari:** voqealar keshlanadi va oyna har tikda jonli vaqt bilan baholanadi. "Surprise" kengaytmasi endi ishlaydi. Auto-flat voqea ID'si bo'yicha ishlaydi. Rejalashtirilgan yangilik grid'ni har doim to'xtatadi.
- **Cashback trailing:** TP trailing'ni ishga tushiradi. Har qanday trailing qulfi brokerga real SL sifatida yoziladi.
- **Server litsenziyasi**, WebRequest va masofaviy buyruqlar olib tashlandi.
- **Hisob turi** avtomatik aniqlanadi. Hedging bo'lmasa, yangi savdo ochilmaydi.
- **Savatni yopish:** retcode bo'yicha qayta urinish, urinishlar orasida pauza. Qisman yopish chiqish deviatsiyasi bilan bajariladi va natijasi tekshiriladi.
- **Taymer** faqat soatga bog'liq himoyani ishga tushiradi.
- **Grid lot:** qattiq cheklovlar poldan keyin qo'llanadi. Ehtiyot modullari rad etgan pog'ona vaqtincha ushlab turiladi.
- **Mayda tuzatishlar:** komissiya DD'ga qo'shildi, slippage yuborishdan oldin o'lchanadi, retcode tekshiriladi. Qayta init'da bar hisoblagichi nolga qaytmaydi. `VerboseLogs` kaliti qo'shildi. 104 ta ishlatilmaydigan input olib tashlandi.
- **Kod tuzilishi:** kod `Sirus/` papkasidagi 17 ta qismga bo'lindi. Kompilyatsiya qilinadigan dastur avvalgisi bilan aynan bir xil.

## Kod ichidagi tuzatishlar ko'rsatkichi

Har bir tuzatish yoki imkoniyatning batafsil sababi kodning o'zida, shu tegning yonidagi kommentda yozilgan. Quyida har bir teg birinchi uchragan joyi bilan berilgan.

| Teg | Fayl:qator | Qisqacha |
|---|---|---|
| `FIX(arm-wall-geometry)` | `Sirus/00_Defines.mqh:167` | true when G_ARM_TRIGGER is a wall the trade must get PAST, false when it is a level the trade wants price to dip into. The two need opposite confirmat |
| `FIX(counter-trend-needs-a-reason)` | `Sirus/00_Defines.mqh:168` | this entry is fighting a confirmed global trend - ChooseLadderShape() caps its ladder |
| `FIX(counter-zone-rearm-loop)` | `Sirus/00_Defines.mqh:169` | bar a counter-zone wait ended UNANSWERED, per direction ([0]=buy, [1]=sell). One shared slot let a SELL failure cancel a BUY cooldown. |
| `FIX(affordability-basis)` | `Sirus/00_Defines.mqh:462` | declared here because LadderIsAffordable() calls it ~1700 lines before its definition |
| `FIX(scalein-orphan)` | `Sirus/00_Defines.mqh:465` | ScaleInDueLot() needs a LIVE basket read, and it sits ~13k lines above the definition |
| `FIX(affordability-geometric-step)` | `Sirus/00_Defines.mqh:466` | same reason - the ladder projection needs the real widening factor and its clamps |
| `FIX(log-noise)` | `Sirus/01_Inputs.mqh:8` | master switch for the ~170 "...PrintOnUse" diagnostic logs. false = quiet journal (trades, closes, errors and warnings still print). Each individual P |
| `FEATURE(close-markers)` | `Sirus/01_Inputs.mqh:93` | when a basket closes, record WHY it closed and whether it won or lost, |
| `FEATURE(grid-reaction)` | `Sirus/01_Inputs.mqh:755` | "reaction preference" for grid additions (user request, variant A). |
| `FEATURE(grid-reaction-consensus)` | `Sirus/01_Inputs.mqh:770` | a single M15 rejection candle can be a fakeout. Instead of |
| `FIX(exit-slippage-cap)` | `Sirus/01_Inputs.mqh:1724` | max slippage on EXITS ($3.00). Closes used to inherit OrderSendDeviationPoints (50 = $0.05) from the shared CTrade object, so a basket stop during a n |
| `FIX(close-no-retry)` | `Sirus/01_Inputs.mqh:1725` | how many times the basket close loop re-tries the positions that failed to close. 1 = old single-attempt behaviour. |
| `FIX(close-retry-same-quote)` | `Sirus/01_Inputs.mqh:1726` | pause between basket-close passes (live only), so a requote is retried at a fresh price instead of the same one |
| `FEATURE(daily-bias)` | `Sirus/01_Inputs.mqh:1751` | previous-day analysis. Adds three things the bot was missing |
| `FIX(hard-spread-preempts-unified)` | `Sirus/01_Inputs.mqh:1785` | was 300, the ONLY spread gate in the EA not routed through EffSpread(). Every other one (env 6140, queue, micro, risk) resolves to UnifiedMaxSpreadPoi |
| `FEATURE(range-breakout)` | `Sirus/01_Inputs.mqh:1806` | detect when price ESCAPES the range (variant B). While ranging, the bot |
| `FEATURE(sustained-impulse)` | `Sirus/01_Inputs.mqh:1823` | the single-bar impulse test only catches a sharp one-candle burst. A |
| `FEATURE(sustained-impulse-exhaustion)` | `Sirus/01_Inputs.mqh:1835` | the ATR-based ImpulseEndHardBlock only fires on huge (7x |
| `FEATURE(counter-impulse-block)` | `Sirus/01_Inputs.mqh:1845` | entering AGAINST a strong impulse while it is still running (not |
| `FEATURE(correction-exhaustion)` | `Sirus/01_Inputs.mqh:1866` | the screenshot's right-hand loss - after a DOWN move, price |
| `FEATURE(recent-extreme)` | `Sirus/01_Inputs.mqh:1881` | the screenshot's left-hand loss - price fell into a bottom, the bot sold |
| `FEATURE(spike-impulse)` | `Sirus/01_Inputs.mqh:1897` | the OTHER kind of fast move - a single bar that blows out several times |
| `FEATURE(recent-thrust)` | `Sirus/01_Inputs.mqh:1906` | live-trading gap found by the user - price arrived at a resistance WITH a |
| `FEATURE(zone-thrust-penalty)` | `Sirus/01_Inputs.mqh:2624` | second layer for the same live-trading gap. A zone-retest signal is |
| `FEATURE(strong-zone-override)` | `Sirus/01_Inputs.mqh:2868` | the plain nearest-zone scan returns the CLOSEST support/resistance |
| `FEATURE(ghost-zones)` | `Sirus/01_Inputs.mqh:2878` | a support/resistance that gets broken doesn't vanish from a trader's mind |
| `FEATURE(impulse-correction-penalty)` | `Sirus/01_Inputs.mqh:2901` | buying into a shallow bounce while a DOWN impulse is still |
| `FIX(counter-zone-single-level)` | `Sirus/01_Inputs.mqh:3351` | treat a SHELF of several ordinary opposing levels as a wall, not only a single strong one. This is the guard against "sell at support / buy at resista |
| `FEATURE(gap-fill-magnet)` | `Sirus/01_Inputs.mqh:3610` | after a large gap, price tends to drift back to fill it. Discourage |
| `FIX(dow-bayes-penalty)` | `Sirus/01_Inputs.mqh:3755` | the "bad day of week" penalty used to reuse DayOfWeekBayesBonus (copy-pasted from the HourBayes pair above without its own Penalty input), so it could |
| `FEATURE(candlestick-models)` | `Sirus/01_Inputs.mqh:3905` | Pin Bar (Hammer / Shooting Star) and Morning/Evening Star, added |
| `FEATURE(consensus-quality)` | `Sirus/01_Inputs.mqh:3929` | 2nd-stage quality layer (B + C). A reversal is stronger when it |
| `FEATURE(firstentry-reversal-consensus)` | `Sirus/01_Inputs.mqh:3948` | a reversal-type first entry (sweep / near-zone / fake |
| `FIX(zone-wall-hardblock)` | `Sirus/01_Inputs.mqh:4088` | the caution above only ever applied a -penalty. With MinScore as |
| `FEATURE(counter-zone-firstentry)` | `Sirus/01_Inputs.mqh:4101` | variant B - a dedicated hard block for the exact failure the |
| `FEATURE(htf-against-firstentry)` | `Sirus/01_Inputs.mqh:4128` | variant B for "the bot opens SELL against a BUY market and sits |
| `FIX(global-notrend-floor)` | `Sirus/01_Inputs.mqh:4155` | GlobalTFConfidence() used to borrow LocalTrendNoTrendADX (14.0) as its |
| `FEATURE(local-trend-range-floor)` | `Sirus/01_Inputs.mqh:4165` | below MinADX the code falls back to a simple direction read and |
| `FEATURE(local-trend-momentum)` | `Sirus/01_Inputs.mqh:4172` | direction+strength alone can't tell a trend that is BUILDING (ADX |
| `FEATURE(global-htf-bind)` | `Sirus/01_Inputs.mqh:4184` | DeepHTFTrendDirection() - the trend direction the dashboard shows and the |
| `FEATURE(global-trend-momentum)` | `Sirus/01_Inputs.mqh:4193` | the mirror of the local momentum/turning work, for the big picture. |
| `FEATURE(simple-trend-structure)` | `Sirus/01_Inputs.mqh:4219` | the fallback trend read (used when ADX doesn't qualify) compared |
| `FEATURE(local-trend-turning)` | `Sirus/01_Inputs.mqh:4228` | the local trend read uses an 8-bar window, so when the trend has |
| `FEATURE(adaptive-alignment-weight)` | `Sirus/01_Inputs.mqh:4240` | a 1-order scalp is a pure M1/M5 event, so local should lead. |
| `FEATURE(impulse-end-hardblock)` | `Sirus/01_Inputs.mqh:4302` | direct user request - "if the impulse is SELL, do NOT open |
| `FEATURE(collapse-bottom-guard)` | `Sirus/01_Inputs.mqh:4316` | the mirror of the resistance-BUY problem. When price has fallen |
| `FEATURE(blowoff-hardblock)` | `Sirus/01_Inputs.mqh:4335` | the single most dangerous entry in a fast market - jumping in the |
| `FEATURE(market-structure)` | `Sirus/02_Globals.mqh:53` | the swing-chain reading. Refreshed once per bar by MarketStructureRead(). |
| `FIX(see-persist-counts-ticks)` | `Sirus/02_Globals.mqh:409` | the bar the counter last advanced on |
| `FIX(close-remnant-becomes-new-basket)` | `Sirus/02_Globals.mqh:410` | a basket close left positions behind - no grid additions until it is flat |
| `FIX(calendar-window)` | `Sirus/02_Globals.mqh:480` | calendar value id of the active event (unique per release) |
| `FIX(autoflat-by-id)` | `Sirus/02_Globals.mqh:494` | calendar value id, not the name - a weekly release (Jobless Claims) has the same name every week, so the name-based latch silently disabled auto-flat  |
| `FIX(ghost-zone-capacity)` | `Sirus/02_Globals.mqh:546` | was [8] while GhostZoneMaxCount (input, V206) is 10 - the populating |
| `FEATURE(wick-sweep)` | `Sirus/03_Core_Utils.mqh:787` | user request - a real liquidity sweep takes out the prior high/low with |
| `FIX(extension-unit)` | `Sirus/04_Trend_Structure.mqh:550` | the swing scan spans MoveExtensionLookbackBars on MoveExtensionTF |
| `FIX(hunter-spread-order)` | `Sirus/04_Trend_Structure.mqh:1276` | this reject-gate gates on AutoBalancedSpreadLimit alone, then the |
| `FIX(hunter-spread-discriminator-dead)` | `Sirus/04_Trend_Structure.mqh:1307` | this test used EffSpread(AutoHighHunterMaxSpread), and |
| `FIX(stale-range)` | `Sirus/04_Trend_Structure.mqh:1604` | G_RANGE_HIGH/LOW are only rewritten while a range is actually confirmed, so |
| `FIX(breakout-tf)` | `Sirus/04_Trend_Structure.mqh:1616` | confirm on the SAME timeframe the range was measured on. Reading a single |
| `FIX(tp-anchor-vs-current-price)` | `Sirus/05_Situation_Candles.mqh:482` | the value this returns is consumed as a distance from the |
| `FIX(impulse-direction)` | `Sirus/05_Situation_Candles.mqh:3263` | the direction used to come from just c1 vs c2 - a single-bar look |
| `FIX(entry-history-wipe)` | `Sirus/05_Situation_Candles.mqh:3426` | the entry HISTORY is deliberately NOT cleared here. ResetOpportunity() |
| `FIX(queue-reset-wipe)` | `Sirus/05_Situation_Candles.mqh:3457` | G_QUEUE_ACTIVE NOT reset here - per-scan reset was killing the signal queue before it could replay (queue is managed by SaveCurrentSignalToQueue / Cle |
| `FIX(block-state-wipe)` | `Sirus/05_Situation_Candles.mqh:3481` | temp-block LIFECYCLE state is not cleared by a routine reset. These |
| `FIX(grid-cooldown-wipe)` | `Sirus/05_Situation_Candles.mqh:3492` | grid timing history is NOT cleared by a routine reset. Wiping |
| `FIX(post-loss-cooldown-wipe)` | `Sirus/05_Situation_Candles.mqh:3522` | NOT cleared here - per-scan reset must not erase the post-loss cooldown (see ResetScoreEngine note). |
| `FIX(vps-timer-wipe)` | `Sirus/05_Situation_Candles.mqh:3554` | G_VPS_LAST_CHECK/LAST_AUDIT/LAST_BROKER_PRINT/TICK_WINDOW_START/TICK_WINDOW_COUNT/TICKS_PER_MINUTE deliberately NOT cleared here - this reset runs on  |
| `FIX(basket-state-wipe)` | `Sirus/05_Situation_Candles.mqh:3586` | basket TRAILING / break-even state is NOT cleared by a routine |
| `FIX(aftershock-wipe)` | `Sirus/05_Situation_Candles.mqh:3596` | the aftershock timer is NOT cleared by a routine reset - clearing it |
| `FIX(pack3-timer-wipe)` | `Sirus/05_Situation_Candles.mqh:3613` | G_PACK3_LAST_DEAL_SCAN/LAST_AUDIT_PRINT deliberately NOT cleared here - Pack3ClosedDealAnalytics() uses them to throttle its own deal-history rescan t |
| `FEATURE(bayes-auto-disable)` | `Sirus/05_Situation_Candles.mqh:3659` | forward declarations: defined later, used by the scanner above. |
| `FIX(dead-ceiling-guard)` | `Sirus/05_Situation_Candles.mqh:3688` | the old `if(ceiling <= 0.0 // ceiling >= price) ceiling = ...` branch |
| `FEATURE(order-block)` | `Sirus/05_Situation_Candles.mqh:4253` | institutional order block reaction (highest-grade of the candle group). |
| `FEATURE(tweezer)` | `Sirus/05_Situation_Candles.mqh:4260` | tweezer top/bottom double-rejection. |
| `FIX(orderflow-magnitude)` | `Sirus/05_Situation_Candles.mqh:4315` | OrderFlowConvictionSign() classifies VOLUME MAGNITUDE |
| `FREE(sweep)` | `Sirus/05_Situation_Candles.mqh:4688` | wick sweep is a strong CONFIRMATION (bonus points above) but not a gate. The |
| `FIX(orderflow-sign)` | `Sirus/05_Situation_Candles.mqh:4731` | a bearish sweep-sell should be confirmed by BEARISH order flow |
| `FIX(buy-first-bias)` | `Sirus/07_Detectors.mqh:2445` | the scanner evaluates every pair BUY-first, and on an EXACT tie (same |
| `FEATURE(counter-context-guard)` | `Sirus/08_Scanner_Score.mqh:733` | ONE shared evaluator for the three "entry fights the current |
| `FIX(ghost-zone-side)` | `Sirus/08_Scanner_Score.mqh:1091` | the outer `MathAbs(bid - lvl) <= reach` guard above already forces |
| `FIX(lean-killed-by-blocking-flag)` | `Sirus/08_Scanner_Score.mqh:1133` | EnableCounterZoneCluster is a BLOCKING input. The lean |
| `FIX(cluster-memo-key)` | `Sirus/08_Scanner_Score.mqh:1149` | the two callers use DIFFERENT windows and would otherwise share a slot |
| `FIX(lean-displaced-by-strong-override)` | `Sirus/08_Scanner_Score.mqh:1249` | EnableStrongZoneOverride searches out to |
| `FIX(lean-wrong-side)` | `Sirus/08_Scanner_Score.mqh:1261` | both scans accept a level up to ZoneNearAboveTolerance on the FAR |
| `FIX(arm-confirm-scope)` | `Sirus/08_Scanner_Score.mqh:1298` | skip_counter_zone suppresses ONLY this section. An armed setup that |
| `FIX(counter-zone-permanent-block)` | `Sirus/08_Scanner_Score.mqh:1394` | during the cooldown this must NOT hard-block. |
| `FIX(counter-trend-score-source)` | `Sirus/08_Scanner_Score.mqh:1470` | use the score of the signal being TESTED. The |
| `FIX(counter-trend-no-valve)` | `Sirus/08_Scanner_Score.mqh:1486` | this refusal sits AFTER BlockSafetyValve and |
| `FIX(counter-trend-print-per-tick)` | `Sirus/08_Scanner_Score.mqh:1508` | CoreUpdate runs on every tick, so an |
| `FIX(counter-trend-flag-stale)` | `Sirus/08_Scanner_Score.mqh:1878` | ResetScoreEngine() clears this, but it is only reached on the |
| `FIX(arm-confirm-deadlock)` | `Sirus/08_Scanner_Score.mqh:1979` | remembers that THIS pass just confirmed an armed setup, so the |
| `FIX(dead-variable)` | `Sirus/08_Scanner_Score.mqh:2384` | cat_trendstrength (the FOR-agreeing variant) removed - TrendStrengthAgainst() |
| `FIX(penalty-stacking)` | `Sirus/08_Scanner_Score.mqh:5803` | many independent modules each subtract points for what is essentially |
| `FIX(context-penalties-inert)` | `Sirus/08_Scanner_Score.mqh:6759` | CounterContextBlockNow() does not only block - three of its |
| `FIX(queue-dir-enum)` | `Sirus/09_Redirect_Queue_Pack2.mqh:1148` | ENUM_OPPORTUNITY_DIR is NONE=0 / BUY=1 / SELL=2, but the scoring |
| `FIX(queue-hardblock-bypass)` | `Sirus/09_Redirect_Queue_Pack2.mqh:1172` | ReplayQueuedSignal restores the stored decision and sets |
| `FIX(queue-soft-guard-bypass)` | `Sirus/09_Redirect_Queue_Pack2.mqh:1191` | the guards that are configured as PENALTIES (not hard blocks) |
| `FIX(breakeven-counted-as-win)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2267` | an exact break-even close (profit == 0.0, e.g. from |
| `FIX(tp-dir-no-basket)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2488` | G_BASKET_DIRECTION is -1 with no basket and -2 when mixed, and |
| `FIX(tp-situation-dir-mismatch)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2543` | G_SITUATION_DIR is set by the ENTRY scanner and describes the |
| `FIX(szr-unreachable)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2722` | this counter-trend check DUPLICATES the "HTF/structure against" reason |
| `FIX(trail-lock-moves-backwards)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2934` | smart_step is recomputed every tick and widens again as |
| `FIX(dynamic-tp-two-writers)` | `Sirus/09_Redirect_Queue_Pack2.mqh:2992` | this used to call Pack2BasketTPForOrders(orders, BaseBasketTPPoints()) |
| `FIX(dd-commission)` | `Sirus/10_Basket_Stats_Context.mqh:152` | basket profit and DD read POSITION_PROFIT + POSITION_SWAP only. On a commission |
| `FIX(dd-equity-zero-reads-as-100pct)` | `Sirus/10_Basket_Stats_Context.mqh:283` | equity was unguarded. A transient equity==0 read while |
| `FIX(affordability-stale-shape)` | `Sirus/10_Basket_Stats_Context.mqh:4522` | this used LadderOrders()/LadderMultiplier(), which read |
| `FIX(affordability-math)` | `Sirus/10_Basket_Stats_Context.mqh:4588` | the old estimate was `total_lots * (span * 0.5)` - the WHOLE ladder's |
| `FIX(thesis-wrong-side)` | `Sirus/10_Basket_Stats_Context.mqh:4891` | the invalidation must sit on the side this trade would be WRONG |
| `FIX(failed-break-i1)` | `Sirus/10_Basket_Stats_Context.mqh:5043` | for i==1 (the most recently closed bar) reclaim_from (i-1=0) is |
| `FEATURE(smart-time-filter)` | `Sirus/11_Expectancy_MTF_News.mqh:1720` | sample-count helpers, so the filter never acts on a thin sample. |
| `FIX(silent-guard-off)` | `Sirus/11_Expectancy_MTF_News.mqh:1881` | the ring buffer only holds 16 one-second samples. If the user set |
| `FIX(v243-support-only-asymmetry)` | `Sirus/11_Expectancy_MTF_News.mqh:3224` | V243 added ZoneNearAboveTolerance to the SUPPORT scan - "a |
| `FIX(support-collapse-to-price)` | `Sirus/11_Expectancy_MTF_News.mqh:3273` | was `best = MathMin(l, price)`. For the V243 case this |
| `FIX(regime-0-hidden)` | `Sirus/12_Exits_Trailing.mqh:470` | was `r = 1`, skipping regime 0 (REGIME_UNKNOWN). RegimeRecordOutcome() |
| `FIX(dd-warning-not-reset)` | `Sirus/12_Exits_Trailing.mqh:850` | G_LAST_DD_WARNING_LEVEL used to only reset on a full basket-state |
| `FIX(partial-close-deviation)` | `Sirus/12_Exits_Trailing.mqh:965` | partial closes inherited the 50-point ENTRY deviation from the shared |
| `FIX(bayes-double-count)` | `Sirus/12_Exits_Trailing.mqh:1038` | capture the detector type BUT do NOT record the outcome or clear |
| `FIX(close-retcode)` | `Sirus/12_Exits_Trailing.mqh:1087` | "sent" alone is not "closed". A partial fill leaves volume behind, and a |
| `FIX(recovery-path-sell)` | `Sirus/13_Grid_Engine.mqh:385` | the path home always runs FROM current price TOWARD break-even |
| `FIX(recovery-path-cascade)` | `Sirus/13_Grid_Engine.mqh:422` | the step below advances search_from by only |
| `FIX(direction-guard)` | `Sirus/13_Grid_Engine.mqh:483` | grid_direction MUST be a real BUY/SELL. The old code did |
| `FIX(martingale-floor-override)` | `Sirus/13_Grid_Engine.mqh:1378` | the lot adjustments are two different kinds of thing, and the |
| `FIX(sent-is-not-filled)` | `Sirus/13_Grid_Engine.mqh:1630` | OrderSend()/CTrade return true when the request passed the basic checks and the |
| `FIX(grid-distance-escapes-clamp)` | `Sirus/13_Grid_Engine.mqh:2032` | GridDistanceForNextOrder() ends by clamping the gap to |
| `FIX(dead-assignment)` | `Sirus/13_Grid_Engine.mqh:2188` | the plain `G_NEXT_GRID_PRICE = next_price;` that used to sit here was |
| `FIX(szr-lot-floor)` | `Sirus/13_Grid_Engine.mqh:2242` | SZRLotFactor (0.5) was applied AFTER NextGridLot's floors, so it |
| `FIX(scalein-no-margin-check)` | `Sirus/13_Grid_Engine.mqh:2563` | this was the ONLY order-sending path in the EA with no |
| `FIX(close-remnant-never-retried)` | `Sirus/13_Grid_Engine.mqh:2610` | the G_BASKET_CLOSE_PENDING latch stops the grid ADDING to a |
| `FIX(daily-attempts-reset)` | `Sirus/14_Risk_Gates_Entry.mqh:35` | MaxDailyEntryAttempts is a DAILY limit, but nothing ever reset |
| `FIX(loss-tiers-masked-by-spread)` | `Sirus/14_Risk_Gates_Entry.mqh:431` | the ENV-not-ready and wide-spread gates used to sit ABOVE |
| `FIX(momentum-wall-negative-dist)` | `Sirus/14_Risk_Gates_Entry.mqh:790` | , BUY side: the resistance scan is now lenient the same |
| `FIX(rc-check-side-effects)` | `Sirus/14_Risk_Gates_Entry.mqh:857` | apply_side_effects=false is for callers that only want the |
| `FIX(micro-floor)` | `Sirus/14_Risk_Gates_Entry.mqh:941` | a MICRO entry is deliberately smaller (StartLot x MicroLotFactor), but the |
| `FIX(scale-in-autolot-remainder)` | `Sirus/14_Risk_Gates_Entry.mqh:1067` | captured BEFORE the split overwrites `lot`, so the floor |
| `FIX(projection-clears-pending-lot)` | `Sirus/14_Risk_Gates_Entry.mqh:1119` | ...and not during a risk PROJECTION either. The |
| `FIX(tick-size)` | `Sirus/14_Risk_Gates_Entry.mqh:1222` | round to the broker's actual TRADE_TICK_SIZE, not just to digits. On most |
| `FIX(auto-widen-tp)` | `Sirus/14_Risk_Gates_Entry.mqh:1383` | a TP/SL closer than the broker's stop/freeze level used to CANCEL the |
| `FIX(rental-delay-after-send)` | `Sirus/14_Risk_Gates_Entry.mqh:4746` | this block used to sit BELOW the Buy/Sell call. The delay it is |
| `FIX(slippage-after-send)` | `Sirus/14_Risk_Gates_Entry.mqh:4845` | this was read AFTER Buy()/Sell() returned, i.e. the quote after the fill, |
| `FIX(partial-fill-ignored)` | `Sirus/14_Risk_Gates_Entry.mqh:4861` | CTrade::Buy/Sell return true for TRADE_RETCODE_DONE_PARTIAL as well |
| `FIX(first-entry-direction-stale)` | `Sirus/14_Risk_Gates_Entry.mqh:4889` | these two read G_BASKET_DIRECTION, but at this instant it |
| `FIX(cap-bypass)` | `Sirus/15_Legacy_Packs.mqh:693` | this runs AFTER UpdateSignalScoreEngine has already applied |
| `FIX(top-zone-priority)` | `Sirus/15_Legacy_Packs.mqh:3017` | unlike its sibling DeepZonePressureDirection (which picks whichever |
| `FIX(init-bypasses-anti-churn)` | `Sirus/16_Dashboard_Core.mqh:856` | OnInit zeroes G_BARS_SEEN / G_TICK_COUNT / G_LAST_ENTRY_TIME and |
| `FIX(structure-dash-brace)` | `Sirus/16_Dashboard_Core.mqh:1689` | this block used to stay open across all three sections below |
| `FIX(input-validation)` | `Sirus_Brain_V8.mq5:47` | the EA used to start with INIT_SUCCEEDED no matter what the user |
| `FIX(deviation-validation)` | `Sirus_Brain_V8.mq5:70` | OrderSendDeviationPoints is a plain (signed) int but is handed |
| `FIX(reinit-bar-rewind)` | `Sirus_Brain_V8.mq5:95` | G_BARS_SEEN is NOT zeroed here any more. An input change or timeframe switch |
| `FIX(timer-result-check)` | `Sirus_Brain_V8.mq5:674` | EventSetTimer()'s return value used to be discarded. If it fails |
| `FIX(account-mode)` | `Sirus_Brain_V8.mq5:697` | detected automatically - no input to set. |
| `FIX(handle-leak)` | `Sirus_Brain_V8.mq5:764` | SMA cache was never released |
| `FEATURE(tp-sl-lines)` | `Sirus_Brain_V8.mq5:772` | remove the basket TP / trailing-SL lines when the EA stops. Unlike the |
| `FIX(modhealth-per-tick)` | `Sirus_Brain_V8.mq5:1390` | this used to call ModuleHealthUpdate() here unconditionally, on |
| `PERF(tester-speed)` | `Sirus_Brain_V8.mq5:1396` | comment below already fixed for the rest of the dashboard. G_MH_* is only |
| `FIX(timer-trades)` | `Sirus_Brain_V8.mq5:1430` | in CoreUpdate |
