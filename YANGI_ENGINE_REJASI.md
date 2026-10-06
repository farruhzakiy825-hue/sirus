# Sirus: yangi Market Brain engine rejasi

> Manba: egasining 4 ta kuzatuv hujjati (umumiy arxitektura, Direction + First Entry,
> Liquidity → Structure → Direction, Zone + Liquidity + Candle rework).
> Bu hujjat **faqat reja**. Kod yozish har bir bosqich kelishilgandan keyin boshlanadi.

---

## 1. Hozirgi robot qanday qaror qiladi (muammoning ildizi)

```
24 juft detektor ──► eng yuqori ball ──► ~70 ta filtr (+/− ball) ──► ochish
   (zone, sweep,        (bitta g'olib)       (har biri alohida,
    momentum, ...)                            bir-birini bilmaydi)
```

- **Yo'nalishni detektor tanlaydi.** Qaysi detektor eng baland ball bersa, o'sha tomon olinadi.
  Bozor haqida yagona "fikr" (thesis) yo'q. Har bir modul o'zicha ovoz beradi.
- **Zona roli faqat narxning hozirgi joyidan aniqlanadi.** `ZoneMapNearestResistance()` narxdan
  YUQORIDAGI eng yaqin darajani "resistance" deb hisoblaydi. Zonada oldin nima bo'lgani
  (sweep, reclaim, haqiqiy break yoki soxta break) eslab qolinmaydi.

### Xato №1 (4142 SELL), kodda topilgan sabab
`DetectNearZoneReactionSell()` (`Sirus/07_Detectors.mqh:714`) faqat 3 narsani tekshiradi:
1. yaqinda resistance bor;
2. oxirgi shamda yuqori wick ≥ 20%;
3. sham bearish yopilgan.

Undan oldin pastda likvidlik olingani, bullish displacement va MSS bo'lgani **umuman
tekshirilmaydi**. Natijada "zona + bitta qizil sham = SELL" bo'ladi.

### Xato №2 (4126 SELL), kodda topilgan sabab
4125 support atrofida narx bir lahza zonadan pastga tushsa, zona darhol "resistance" bo'lib
qoladi, chunki rol narx joyidan olinadi. `ZoneMapIsPolarityFlip()` esa bir necha yopilishning
pastda bo'lishini "flip" deb qabul qiladi. U displacement, acceptance yoki darhol reclaim
bo'lganini farqlamaydi. Shuning uchun soxta break → 4126 da SELL chiqadi.

---

## 2. Hujjatlardagi g'oyalar va koddagi holati

| G'oya (hujjatlardan) | Kodda bormi | Izoh |
|---|---|---|
| Market Brain / Market Thesis (yagona fikr) | ❌ Yo'q | Eng katta bo'shliq |
| Dynamic Bias (BULLISH … TRANSITION … BEARISH) | ❌ Yo'q | Hozir faqat BUY/SELL ball |
| Thesis lifecycle (Activation / Confirmation / Invalidation) | 🟡 Qisman | `SetBasketThesis` / `BasketPremiseDead` faqat ochiq savat uchun |
| Invalidation memory (eski fikr o'ldi) | ❌ Yo'q | |
| Liquidity event → reaction → displacement → MSS → reclaim | 🟡 Qisman | Sweep faqat **kirish signali** sifatida, bias'ni o'zgartirmaydi |
| Event freshness / age | 🟡 Qisman | `EventChain` bor, yoshi qarorga ta'sir qilmaydi |
| Dynamic Zone Role (UNTOUCHED … RECLAIMED … FAILED) | ❌ Yo'q | Rol = narx joyi |
| Zone interaction memory | ❌ Yo'q | |
| Zone conflict (H1 supply vs M5 demand) | 🟡 Qisman | Kuch bor, TF'lar urushmaydi |
| Hard veto (score'dan alohida) | 🟡 Qisman | `BlowOff`, `ImpulseEnd`, `ZoneWall` bloklari bor, sweep + MSS veto'si yo'q |
| Direction Permission matritsasi | ❌ Yo'q | |
| Entry type (continuation / pullback / reversal / reclaim) | 🟡 Qisman | Detektor turi bor, direction bilan bog'lanmagan |
| Location (premium / discount, room, invalidation masofasi) | 🟡 Qisman | `RoomToTargetPoints`, `LocationBrain`, `EntryPositionInMove` |
| Chase detector / Speed budget / Entry quality decay | 🟡 Qisman | `LateEntry`, arming bor; vaqt bilan ball pasayishi yo'q |
| Impulse origin / Impulse age | ❌ Yo'q | |
| Compression → Expansion | 🟡 Juda kam | |
| Candle Intent (9 xil niyat) | 🟡 Qisman | Sham holatlari bor (expanding / contracting / inside / rejection / absorption), lekin "displacement, liquidity-grab, fake-breakout, exhaustion" kabi yagona tasnif yo'q |
| Candle Anatomy (body %, wick %, close position) | ✅ Bor | `CandleBodyPoints`, `CandleWickAuthorship`, `CandleParticipation` |
| Candle × Location | 🟡 Qisman | `CandleLocationWeight`, `CandlePatternLocation` bor, zona roli bilan bog'lanmagan |
| Candle Sequence (order-flow story) | 🟡 Qisman | `CandleSequenceRead`, `CandleProgression`, `WickOrderBias` bor |
| Candle Pressure Score (bull / bear 0-100) | ❌ Yo'q | `ConsecutivePressure` faqat yo'nalish beradi |
| Candle Acceleration / Deceleration | 🟡 Qisman | `RecentThrustExhausted`, expanding / contracting holati |
| Live candle (yopilishni kutmaslik) | 🟡 Qisman | `LiveBarRead`, `LiveBarEvolution` bor (wick failed / sustained / absorbed) |
| Wick rejection quality (joy + likvidlik + keyingi sham) | 🟡 Qisman | `CandleRejectionReliability`, `CandleBreakQuality` |
| M1 → M5 → M15 sham bosimi solishtirish | 🟡 Qisman | `CandleHTFAgreement` |
| Har sham manbasining aniqligini o'rganish | ✅ Bor | 10 ta manba uchun `CandleSource*` (Bayes) |
| Minimum Necessary Evidence (holatga qarab) | ❌ Yo'q | Hozir bir xil talab |
| Contradiction engine | 🟡 Qisman | `CandleConflict`, `RegimeContradiction` |
| Grid faqat thesis + sham tasdig'i bilan | 🟡 Qisman | `PremiseDead`, `StructureAgainstBasket`, `GridDirectionDoubt` |
| Trade monitor: HOLD / REDUCE / EXIT / REVERSE | 🟡 Qisman | `SmartEarlyExit` bor, REVERSE yo'q |
| Reason code (har savdo sababi) | 🟡 Qisman | `DecisionLog` bor, tuzilgan emas |
| Entry DNA (statistik xotira) | 🟡 Qisman | Detektor bo'yicha Bayes, to'liq "barmoq izi" yo'q |
| Market phase (accumulation / expansion / distribution / contraction) | 🟡 Qisman | Regime (trend / range / volatile / quiet) bor |

**Xulosa:** bo'laklarning ko'pi bor, lekin ular bitta "miya"ga bog'lanmagan.
Yangi engine noldan yozilmaydi. Mavjud o'lchovlar (structure, sweep, candle, location)
**faktlar manbai** sifatida qayta ishlatiladi, ustiga yagona qaror qatlami quriladi.

---

## 3. Maqsadli arxitektura

```
MARKET DATA (har tik / har bar)
   │
   ▼
A0. CANDLE ENGINE      – har sham: intent, anatomy, pressure (bull / bear), acceleration, jonli holat
   │
   ▼
A. EVENT ENGINE        – faktlar: sweep, displacement, BOS/MSS, reclaim, acceptance, rejection
   │                     (har biri: yo'nalish, daraja, TF, kuch, yosh)
   ▼
B. ZONE ROLE ENGINE    – har zona: holat mashinasi + interaction memory
   │
   ▼
C. MARKET BRAIN        – TF bo'yicha bias (7 holat), thesis (activation / confirm / invalidation),
   │                     contradiction, decay, invalidation memory
   ▼
D. DIRECTION PERMISSION + HARD VETO
   │
   ▼
E. ENTRY ENGINE        – entry type, location, room, invalidation masofasi, chase, impulse age,
   │                     candle intent / pressure, live trigger, speed budget
   ▼
F. ENTRY JUDGE         – Direction ↔ Entry matritsasi → EXECUTE / CAUTION / WAIT / BLOCK
   │                     + Reason Code
   ▼
G. POSITION BRAIN      – grid: ADD / WAIT / STOP (thesis + candle response)
   │                     ochiq savat: HOLD / REDUCE / EXIT (/ REVERSE)
   ▼
H. MEMORY              – Entry DNA + natija → keyingi qarorlarga
```

Asosiy qoidalar (hujjatlardan):
- `ZONE ≠ ENTRY`, `LIQUIDITY ≠ ENTRY`, `CANDLE ≠ ENTRY`, `SIGNAL ≠ ENTRY`.
- A (faktlar) > B (kontekst) > C (imkoniyat). Imkoniyat hech qachon faktni bekor qilmaydi.
- Kirish uchun kamida 3 ta mustaqil kategoriya kerak: **DIRECTION + LOCATION + TRIGGER**.
- 20 ta tasdiq kutilmaydi. Kuchli qarama-qarshi dalil bo'lsa, blok. Qolgan hammasi
  ball va reytingga ta'sir qiladi.
- Brain har tikda noldan hisoblamaydi, "nima o'zgardi?" deb faqat yangilanadi (tezlik).

---

## 4. Bosqichma-bosqich reja

Har bir bosqich alohida kalit (`Enable…`) bilan qo'shiladi. Shunda eski va yangi xatti-harakatni
tester'da yonma-yon solishtirish mumkin. Har bosqichdan keyin: kompilyatsiya → backtest
→ demo.

### 0-bosqich: Regression holatlari va Reason Code (asos) — ✅ kod yozildi (`Sirus/17_Reason_Code.mqh`), test: `REGRESSION_TEST.md`
- 4142 va 4126 holatlarining aniq sana va vaqtini olish. Ular "har o'zgarishdan keyin
  tekshiriladigan" test holatlari bo'ladi.
- Har bir ochilgan savdo uchun tuzilgan **Reason Code** jurnalga yoziladi: thesis, WHY ro'yxati,
  invalidation, confidence, qaysi veto'lar tekshirilgan.
- *Natija:* keyingi bosqichlar ta'sirini aniq o'lchash mumkin bo'ladi.

### 1-bosqich: Event Engine (A: faktlar)
- Hodisalar halqa buferi (oxirgi ~50 hodisa), har biri: turi, yo'nalishi, darajasi, TF, kuchi,
  yaratilgan bar, yoshi.
- Hodisa turlari: `LIQ_SWEEP` (buy-side / sell-side, **har TF: M1…H4**), `DISPLACEMENT`, `BOS`, `MSS/CHoCH`,
  `RECLAIM`, `ACCEPTANCE`, `REJECTION`, `COMPRESSION_RELEASE`.
- Mavjud `DetectSweep*`, `MarketStructureRead`, `EventChain` dan foydalaniladi, lekin natija
  signal emas, **hodisa** bo'lib yoziladi.
- *Natija:* "pastda likvidlik olindi → bullish displacement → MSS" ketma-ketligini robot
  ko'ra oladi.

### 1b-bosqich: Candle Intelligence Engine (A0)
Sham hech qachon yolg'iz signal bermaydi, lekin **kirish vaqtini** beradi:
Market Brain "QAYERDA va NIMA UCHUN?" degan savolga, Candle Engine "HOZIRMI?" degan savolga javob beradi.
Mavjud tarqoq sham modullari bitta engine'ga yig'iladi.

1. **Candle Intent.** Har sham quyidagilardan biri sifatida tasniflanadi: `DISPLACEMENT`,
   `REJECTION`, `ABSORPTION`, `CONTINUATION`, `EXHAUSTION`, `INDECISION`, `LIQUIDITY_GRAB`,
   `BREAKOUT`, `FAKE_BREAKOUT`. Bu "qizil sham = SELL" emas, "sham qayerdan boshlandi va nimani
   buzdi?" degan savolga javob.
2. **Candle Anatomy.** Body %, yuqori va pastki wick %, diapazon, yopilish joyi, oldingi sham
   bilan solishtirish. Misol: katta bullish tana + ulkan yuqori wick + resistance ostida yopilish
   = bullish ko'rinishli **rejection**.
3. **Candle × Location.** Bir xil sham ikki joyda ikki xil ma'no beradi. Support + sweep +
   bullish sham = kuchli BUY dalili. Oldingi high + buy-side likvidlik + bullish sham + uzun
   yuqori wick = exhaustion yoki trap.
4. **Candle Sequence.** Ketma-ketlik voqea sifatida o'qiladi: `🔴🔴🔴🔴🟢🔴` = bosim davom etmoqda
   (rejection zonasi). `🔴🔴🔴🟢🟢🟢` = bearish bosim so'nib, reversal boshlanmoqda.
5. **Candle Pressure Score.** Bull va bear bosimi alohida 0-100: tana (30) + yopilish joyi (20)
   + displacement (20) + struktura buzish (15) + likvidlik reaksiyasi (10) + follow-through (5).
   M1, M5, M15 bo'yicha solishtiriladi.
6. **Candle Acceleration.** Oxirgi 5 sham harakati: `3 → 4 → 7 → 12 → 22` = tezlashish;
   `22 → 15 → 8 → 4` = so'nish. "Tezlashayotgan harakatga qarshi kirma" qoidasi va reversalni
   erta sezish shundan olinadi.
7. **Live Candle State.** Sham yopilishini kutmaydi. Jonli shamda kuchli tana, high yaqinida
   turish, oldingi high buzilishi, likvidlik olinishi bo'lsa → "early displacement", kirish
   tayyorlanadi. Sham kuchini yo'qotsa, signal bekor qilinadi.
8. **Wick Rejection Quality.** Wick bor bo'lishi yetarli emas: qayerda, likvidlik oldimi,
   yopilish qayerda, keyingi sham nima qildi, wick'dan keyin displacement bormi.
9. **Impulse Origin / Compression → Expansion.** Birinchi displacement shamini topish
   (impulse yoshi shundan hisoblanadi) va siqilishdan chiqishni alohida hodisa sifatida belgilash.
10. **Grid uchun Candle Response.** Savat zararda bo'lganda zonada bullish rejection + mikro
    displacement bo'lsa (BUY savat uchun), "aqlli qo'shish". Support buzilib, bearish displacement
    bo'lsa, masofa yetgan bo'lsa ham qo'shilmaydi.

*Natija:* Event Engine (displacement, sweep sham, rejection), Zone Role, Entry trigger va aqlli
grid bitta sham tahliliga tayanadi. Mavjud `CandleSource*` o'rganish tizimi saqlanadi.

### 2-bosqich: Zone Role Engine (B)
- Har zona uchun holat: `UNTOUCHED → APPROACHING → TOUCHED → SWEPT / REJECTED / BROKEN →
  RECLAIMED / RETESTED / FAILED → EXPIRED`.
- Rol **tarix bo'yicha** aniqlanadi:
  - *haqiqiy break* = displacement bilan yopilish + N bar acceptance;
  - *soxta break* = break + darhol reclaim → qarama-qarshi tomon uchun signal;
  - *sweep + reclaim* = zona eski rolini kuchaytiradi.
- Zone interaction memory: zonada oxirgi marta nima bo'lgani saqlanadi.
- *Natija:* 4126 xatosi yo'qoladi, chunki support haqiqiy buzilmaguncha SELL zone bo'lmaydi.

### 3-bosqich: Market Brain + Thesis (C)
- TF bo'yicha bias holati: `BULLISH, BULLISH_WEAK, TRANSITION_UP, NEUTRAL, TRANSITION_DOWN,
  BEARISH_WEAK, BEARISH`.
- **Draw on Liquidity + keyingi qadam:** bozor qaysi likvidlikni oldi va endi qaysisiga boryapti
  (12-bo'lim).
- Thesis obyekti: yo'nalish, confidence, phase, liquidity target, **invalidation level**,
  afzal entry turi, holati (`ACTIVATED / CONFIRMED / ACTIVE / FAILED / INVALIDATED`).
- Evidence ladder: observation < reaction < event < structure < confirmation.
- Contradiction: thesis'ga qarshi dalillar alohida hisoblanadi.
- Decay: confidence vaqt bilan emas, qarama-qarshi dalil kelishi bilan pasayadi.
- Invalidation memory: o'lgan thesis qaytmaydi, eski zona signali "o'lik kontekst" deb belgilanadi.
- *Natija:* narrative ("bullish pullback after sell-side sweep") dashboard va jurnalda ko'rinadi.

### 4-bosqich: Direction Permission + Hard Veto (D), DD uchun eng tez foyda
- Ruxsat matritsasi (BUY uchun; SELL teskarisi):
  - `BULLISH` → to'liq ruxsat;
  - `BULLISH_WEAK` → selektiv;
  - `TRANSITION_UP` → faqat reversal / reclaim BUY;
  - `NEUTRAL` → agressiv emas;
  - `BEARISH_WEAK` → faqat istisno setup;
  - `BEARISH` → blok.
- Hard veto (score 92 bo'lsa ham ochilmaydi):
  - yaqinda qarama-qarshi tomonda sweep + kuchli displacement + MSS + reclaim;
  - kuchli S/R ga to'g'ridan-to'g'ri kirish, haqiqiy break bo'lmagan holda;
  - qarama-qarshi displacement hali tezlashmoqda.
- `FirstEntryCanRun` ga ball hisoblanishidan **oldin** ulanadi.
- *Natija:* 4142 va 4126 holatlari bloklanadi. Detektorlar o'zgarmaydi.

### 5-bosqich: Entry Engine + Candle Intelligence (E)
- Entry type: continuation / pullback / reversal / breakout / liquidity-reclaim.
- Location: premium / discount (dealing range ichida), structural room,
  distance-to-invalidation.
- Chase detector + impulse origin / age + entry quality decay ("signal yaxshi, entry yomon").
- Trigger 1b-bosqichdagi Candle Engine'dan olinadi (intent × location, pressure, live state).
- First pullback preference: yangi impulsdan keyingi birinchi sog'lom pullback ustun
  (kuchli boshlang'ich displacement bo'lsa early entry ham mumkin).
- Reclaim quality: break'ning o'zi emas, break'dan keyin daraja qanday ushlanganini o'qish.
- Minimum Necessary Evidence: trend uchun 3 dalil, reversal uchun 4-5 dalil.
- Speed budget: `EARLY / NORMAL / LATE / EXPIRED`.

### 6-bosqich: Entry Judge (F)
- Direction ↔ Entry matritsasi → `EXECUTE / CAUTION / WAIT / BLOCK`.
- Bir vaqtda bir nechta nomzod bo'lsa, real vaqtda pasayadigan ball bilan reyting tuziladi.
- Counterfactual: BUY NOW / WAIT / SELL savollari bo'yicha Reason Code'ga yoziladi.

### 7-bosqich: Position Brain (G)
- Grid: masofa yetishi yetarli emas. Thesis hali tirik + zonada candle response (rejection /
  micro displacement) bo'lsa ADD, aks holda WAIT yoki STOP.
- Ochiq savat monitori: thesis invalid bo'lsa → HOLD / REDUCE / EXIT (REVERSE keyinroq,
  alohida qaror bilan).

### 8-bosqich: Memory (H)
- Entry DNA: regime, direction, event, zone type, candle, impulse age, location, room, vaqt,
  spread, natija → faylga yoziladi.
- Keyinchalik o'xshash setup'lar statistikasi qarorga qo'shiladi.

### 9-bosqich: Tozalash
- Yangi engine bilan takrorlanib qolgan eski filtrlar va detektorlarni bosqichma-bosqich o'chirish,
  inputlarni qisqartirish.

---

## 5. Hujjatlardagi bo'sh joylar: kelishib olish kerak

1. **Aniq ta'riflar (raqamlar).** XAUUSD M1 uchun "displacement" nima (sham tanasi ≥ k × ATR?),
   "sweep" (swing'dan necha punkt o'tib, necha barda qaytsa?), "acceptance" (necha yopilish,
   necha punkt?), "fresh" (necha bar?). Taklif: hammasi ATR'ga nisbatan, boshlang'ich
   qiymatlarni men taklif qilaman, siz tasdiqlaysiz.
2. **Qaysi TF'lar.** HTF = H1 yoki H4? MSS qaysi TF'da hisoblanadi (M1 / M5 / M15)?
   HTF bearish, M5 transition_up bo'lsa, qaysi biri ustun?
3. **Cashback va savdolar soni.** Qattiqroq kirish = kamroq savdo = kamroq cashback.
   Kunlik maqsad qancha (hujjatda 330 trades/day)? DD va aylanma o'rtasidagi muvozanat qayerda?
4. **REVERSE.** Hedging hisobda teskari savat ochish (ikki savat bir vaqtda) xavfli.
   Kerakmi yoki faqat EXIT yetarlimi?
5. **REDUCE.** Zarardagi savatning bir qismini yopish zararni realizatsiya qiladi.
   Qachon ruxsat beriladi?
6. **Thesis o'lgandan keyin ochiq savat.** Grid to'xtaydi, lekin savat o'zi nima bo'ladi:
   SL'gacha ushlab turiladimi, break-even'da chiqiladimi?
7. **Eski detektorlar.** Ular kirish nomzodi bo'lib qoladimi yoki yangi Entry Engine ularni
   to'liq almashtiradimi? Taklif: avval qoladi, yangi engine ruxsat va veto beradi,
   keyin natijaga qarab kamaytiriladi.
8. **Ball og'irliklari** (+25 sweep, +20 rejection …) taxminiy. Boshida qat'iy qoldiramizmi
   yoki mavjud Bayes o'rganish tizimi bilan sozlaymizmi?
9. **Tester cheklovi.** Kalendar tester'da ishlamaydi. Yangi engine'ni baholash uchun real tick
   data bilan backtest + demo kerak. Baseline (hozirgi v31.68) natijasini saqlab qo'yamiz.
10. **Bir vaqtda bir nechta signal.** Robot bitta savat bilan ishlaydi. "Entry competition"
    bir nechta pozitsiya emas, bitta eng yaxshi nomzodni tanlash degani. Shunday tushunildimi?

---

## 6. Taklif etilgan tartib

**0 → 1 + 1b → 2 → 4 → 3 → 5 → 6 → 7 → 8 → 9**

Event Engine va Candle Engine birga quriladi, chunki displacement, sweep sham va rejection
aynan sham tahlilidan chiqadi. 4-bosqichni (veto) 3-bosqichdan oldin, Event, Candle va Zone Role ustida qilsak, DD'ga
olib kelgan 4142 / 4126 turidagi xatolar eng tez yopiladi. To'liq Market Brain esa undan keyin
quriladi.

---

## 7. Kelishilgan qarorlar (egasi bilan)

| # | Savol | Qaror |
|---|---|---|
| 1 | Aniq raqamlar | Claude XAUUSD scalping uchun taklif qiladi. Hammasi ATR'ga nisbatan (8-bo'lim) |
| 2 | Timeframe'lar | Scalping asosida, lekin bozorni keng qamrab oladi (9-bo'lim) |
| 3 | Savdolar soni | **Kuniga 250–450 ta**. Veto tor bo'ladi, faqat kuchli qarama-qarshi dalil bloklaydi |
| 4 | REVERSE / hedge | **Yo'q.** Qutqarish aqlli grid orqali bo'ladi |
| 5 | REDUCE | **Yo'q.** Zarardagi savat qisman yopilmaydi |
| 6 | Thesis o'lsa | Grid to'xtaydi, savat **break-even'da chiqadi** (10-bo'lim) |
| 7 | Eski detektorlar | Nomzod sifatida qoladi. Yangi engine ruxsat va veto beradi, keyin natijaga qarab kamaytiriladi |
| 8 | Ball og'irliklari | Boshida qat'iy. O'rganish 8-bosqichda, chegaralangan holda (11-bo'lim) |
| 9 | Test holati | **4126 SELL: 2026-10-06, broker vaqti 06:15** (Exness). Shu kun tester'da real tick'lar bilan qayta o'ynatiladi |
| 10 | Entry competition | Bitta eng yaxshi nomzod tanlanadi |

---

## 8. Ta'riflar (XAUUSD, scalping)

Hammasi ATR(14) ga nisbatan. Shunda Osiyo sessiyasining sokin bozori ham, NY'ning tez bozori
ham avtomatik hisobga olinadi. `ATR1` = M1 ATR, `ATR5` = M5 ATR.

| Tushuncha | Ta'rif (boshlang'ich qiymat) |
|---|---|
| **Swing (fractal)** | M1: har tomonda 3 bar; M5 / M15 / H1: har tomonda 2 bar |
| **Likvidlik havzasi** | Buzilmagan swing high / low; teng high / low (farq ≤ 0.15 × ATR o'sha TF); PDH / PDL; Osiyo sessiyasi high / low; yumaloq darajalar (xx00, xx50) |
| **Sweep (har TF)** | Narx o'sha TF havzasidan ≥ max(0.10 × ATR(TF), 1 × spread) o'tadi va ≤ 3 bar (o'sha TF) ichida orqaga yopiladi. O'tish > 1 × ATR(TF) bo'lsa, bu sweep emas, break. M1, M5, M15, H1, **H4** bo'yicha alohida kuzatiladi |
| **HTF sweep og'irligi** | H4 sweep > H1 > M15 > M5 > M1. H4 / H1 sweep + reclaim faktlar qatlamida eng kuchli dalillardan biri |
| **Displacement** | Bitta sham: tanasi ≥ 1.2 × ATR1, tana / diapazon ≥ 0.6, yopilish diapazonning chetki 25% ida. Yoki 2–3 shamlik bir tomonli harakat ≥ 2 × ATR1. **Kuchli**: tana ≥ 1.8 × ATR1 yoki FVG qoldiradi |
| **BOS** | Trend yo'nalishidagi oxirgi swing'dan ≥ 0.05 × ATR o'tib yopilish |
| **MSS / CHoCH** | Oxirgi harakatni boshlagan qarama-qarshi swing'dan o'tib yopilish. M1 = mikro (trigger), M5 = lokal (bias o'tishi), M15 = struktura |
| **Rejection** | Daraja tomonidagi wick ≥ 50% diapazon, yopilish qarama-qarshi 40% ichida |
| **Reclaim** | Darajadan o'tgandan keyin ≤ 5 M1 bar ichida qaytib yopilish va ≥ 2 yopilish ushlab turish |
| **Acceptance (haqiqiy break)** | Break displacement bilan bo'lgan + ≥ 3 ketma-ket M1 yopilish (yoki 1 M5 yopilish) darajadan ≥ 0.25 × ATR1 narida + 5 bar ichida reclaim yo'q |
| **Soxta break** | Break bor, lekin 5 bar ichida reclaim. Qarama-qarshi tomon uchun dalil |
| **Freshness** | O'sha TF barlarida: yangi ≤ 3 bar, dolzarb ≤ 12 bar, keyin faqat kontekst (og'irlik 1.0 → 0.3). M1 uchun: yangi ≤ 10, dolzarb ≤ 45. HTF hodisasi narx "draw on liquidity" maqsadiga yetguncha yoki invalidation bo'lguncha dolzarb qoladi |
| **Impulse age** | Impulse boshlanishidan beri o'tgan bar va bir tomonli to'lqinlar soni. 1-to'lqin "yosh", 3-dan keyin "qari" |
| **Chase / Speed budget** | Impulse boshidan ≥ 30% pullback'siz yurilgan masofa: < 1.5 × ATR1 = `EARLY`; < 2.5 × ATR1 = `NORMAL`; < 4 × ATR1 = `LATE`; undan ko'p = `EXPIRED` (continuation kirish uchun) |
| **Compression** | Oxirgi 10 M1 bar diapazoni ≤ 1.5 × ATR1. Undan displacement bilan chiqish = "compression release" |
| **Structural room** | Qarama-qarshi kuchli zonagacha ≥ max(1.5 × savat TP, 1 × ATR5) |
| **Kuchli tana** | tana / diapazon ≥ 0.60 |
| **Indecision** | tana / diapazon ≤ 0.25 va diapazon ≤ 0.7 × ATR1 |
| **Rejection wick** | daraja tomonidagi wick ≥ 0.50 × diapazon |
| **Absorption** | diapazon ≥ 1.3 × ATR1, lekin tana ≤ 0.35 × diapazon (katta harakat, natija yo'q) |
| **Exhaustion** | impulse ≥ 3-to'lqinda + so'nish (har sham diapazoni oldingisidan kichik) + qarama-qarshi wick |
| **Acceleration** | oxirgi 5 sham diapazoni ketma-ket o'smoqda va oxirgisi ≥ 1.5 × o'rtacha |
| **Early (live) displacement** | jonli sham tanasi ≥ 0.8 × ATR1, narx diapazonning chetki 25% ida, oldingi sham high / low buzilgan |

Bu qiymatlar input sifatida chiqariladi va tester'da sozlanadi.

---

## 9. Timeframe sxemasi (scalping, keng qamrov)

| Qatlam | TF | Vazifasi |
|---|---|---|
| **Trigger** | M1 + jonli sham | Kirish vaqti: mikro MSS, rejection, displacement |
| **Lokal struktura** | M5 | Bias o'tishi (`TRANSITION_UP / DOWN`), pullback va reclaim |
| **Yo'nalish** | M15 | Asosiy bias holati (7 holat) |
| **Joylashuv va maqsadlar** | H1, H4, PDH / PDL, Osiyo high / low | Likvidlik xaritasi, dealing range, premium / discount, draw on liquidity. Oddiy HTF zona hard veto emas, faqat location sifatiga ta'sir qiladi. **Istisno:** yangi H1 / H4 likvidlik sweep + reclaim, bu fakt (12-bo'lim) |

Kelishmovchilik qoidasi:
- M15 yo'nalishni beradi.
- M5 qarama-qarshi tomonga sweep + displacement + MSS qilsa → `TRANSITION`. Shunda
  faqat reversal yoki reclaim turidagi kirish mumkin.
- M1 faqat vaqtni beradi, yo'nalishni o'zgartirmaydi.
- H1 / H4 zonasiga to'g'ridan-to'g'ri kirish → location "yomon", ball pasayadi.

Kuniga 250–450 savdo uchun: trend tomonidagi kirishga minimal dalil yetarli
(direction + location + trigger). Qattiq talab faqat trendga qarshi va reversal kirishlarga
qo'yiladi.

---

## 10. Aqlli grid va break-even chiqish

```
Savat ochiq
   │
   ├─ Thesis tirik ─► masofa yetdi + zonada candle response bor ─► ADD
   │                  masofa yetdi, lekin response yo'q          ─► WAIT
   │
   └─ Thesis O'LDI (invalidation)
         │
         ├─ Grid to'xtaydi (o'lik yo'nalishga qo'shilmaydi)
         ├─ Savat TP → break-even (+ spread qoplami). Narx qaytsa, BE'da chiqiladi
         │
         └─ QUTQARISH: savat yo'nalishida YANGI thesis paydo bo'lsa
            (masalan sweep + reclaim + mikro MSS), "rescue add" ruxsat etiladi.
            Ko'r-ko'rona o'rtachalash emas, faqat dalil bilan.
```

- REVERSE (hedge) va REDUCE (qisman yopish) ishlatilmaydi.
- Basket SL (balansning 50%) oxirgi himoya bo'lib qoladi.

---

## 11. Bayes o'rganish qanday ishlaydi (8-bosqich)

Robotda bu tizim allaqachon bor: har detektor va har soat bo'yicha yutgan va yutqazgan
savatlar sanaladi.

Yangi engine'da:
1. Har dalilning boshlang'ich og'irligi bor. Masalan "sweep + displacement" = 25.
2. Har savat yopilganda robot qaysi dalillar bo'lganini va natijani yozadi.
3. Kamida 30 ta misol yig'ilgach, og'irlik moslanadi. Yutganlarda tez-tez uchragan dalil
   biroz kuchayadi, yutqazganlarda uchragani susayadi.
4. O'zgarish chegaralangan: boshlang'ich qiymatdan ±30% dan ko'p emas.
5. **Hard veto'lar hech qachon o'rganish orqali o'chirilmaydi.**

Misol: "sweep + displacement" 40 marta uchragan, 32 tasi yutgan (80%) → 25 dan 29 ga ko'tariladi.
"Faqat rejection" 40 marta uchragan, 18 tasi yutgan (45%) → 10 dan 8 ga tushadi.

---

## 12. HTF likvidlik va "keyingi qadam" (Draw on Liquidity)

> Egasining kuzatuvi (XAUUSD H4, 2026-10-06): narx H4 dealing range'ning past likvidligini
> (≈ 4110.5 dagi past, undan ostiga ≈ 4105 gacha wick) yechib oldi, 4125 ustiga qaytdi va kuchli
> bullish H4 shamlar bilan 4160–4175 supply zonasigacha ko'tarildi. Robot esa 06:15 da **4126
> da SELL** ochdi, ya'ni H4 sell-side sweep + reclaim'dan keyin, dealing range'ning eng pastki
> (discount) qismida, bozor yuqoriga borishga tayyorlanayotgan joyda.

**Qoida:** zonaga kelish = entry emas. Robot avval bozor **oldin nima qilganini** va **keyin
nima qilishi ehtimolini** hisoblaydi.

### 12.1. Ko'p TF'li likvidlik xaritasi
- H4 / H1 / M15 swing high / low, teng high / low, dealing range chetlari, PDH / PDL, haftalik
  high / low, Osiyo sessiyasi high / low, yumaloq darajalar.
- Har havza holati: `INTACT` (hali olinmagan) / `SWEPT` (olindi va qaytdi) / `BROKEN`
  (olindi va qabul qilindi).

### 12.2. Dealing range va joylashuv
- Joriy H4 (yoki H1) dealing range: oxirgi muhim swing high va swing low orasi (misolda ≈ 4110–4192).
- 50% chizig'i: yuqorisi **premium**, pasti **discount**.
- Discount'da SELL va premium'da BUY: faqat yangi qarama-qarshi likvidlik olinib, MSS bo'lgan
  bo'lsa ruxsat. Aks holda location "yomon".

### 12.3. Draw on Liquidity (DOL) va keyingi qadam
Har likvidlik hodisasidan keyin Market Brain kutilgan yo'lni tuzadi:

```
Sell-side H4 havzasi olindi (sweep)
   ↓ reclaim (havza ustiga qaytish)
   ↓ bullish displacement / MSS
KUTILGAN YO'L:  pullback / retest (reclaim darajasi) → yuqoriga
DOL (maqsad):   eng yaqin INTACT buy-side havza yoki to'ldirilmagan supply (misolda 4160–4192)
INVALIDATION:   sweep shamining past nuqtasi ostida acceptance (≈ 4105 ostida)
```

- Kutilgan yo'l tasdiqlansa, thesis kuchayadi. Pullback BUY imkoniyatlari ustun bo'ladi.
- Narx DOL'ga yetsa, thesis "bajarildi". O'sha joyda qarama-qarshi likvidlik va reaksiya
  qidiriladi. Misolda 4160–4175 supply'da SELL faqat buy-side olinib, bearish MSS bo'lsa.
- Invalidation bo'lsa, thesis o'ladi va invalidation memory'ga yoziladi.

### 12.4. Veto (4126 holati uchun)
**HTF sweep veto:** yangi (dolzarb) H1 / H4 sell-side sweep + reclaim bo'lgan bo'lsa va narx hali
DOL'ga yetmagan yoki invalidation bo'lmagan bo'lsa, **discount'da SELL bloklanadi**.
Buy-side uchun teskarisi.
Faqat quyidagi holatda istisno: bearish displacement + reclaim darajasi ostida acceptance.
Bu esa invalidation degani.

### 12.5. Qaysi bosqichlarga kiradi
- 1-bosqich: HTF sweep hodisalari.
- 2-bosqich: zona holatiga HTF likvidlik bog'lanadi.
- 3-bosqich: dealing range, DOL, kutilgan yo'l.
- 4-bosqich: HTF sweep veto.
- 0-bosqich: 4126 holati regression test sifatida (2026-10-06 06:15, tester'da real tick'lar bilan).
