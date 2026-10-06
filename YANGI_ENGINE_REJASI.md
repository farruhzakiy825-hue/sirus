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
| Candle Intent (displacement / rejection / absorption …) | 🟡 Qisman | `CandleSequence`, `Authorship`, `LiveBar`, `Evolution` bor, lekin tarqoq |
| Candle Pressure / Acceleration | 🟡 Qisman | `ConsecutivePressure`, `TickVelocity` |
| Live candle (yopilishni kutmaslik) | 🟡 Qisman | `LiveSample` bor |
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

### 0-bosqich: Regression holatlari va Reason Code (asos)
- 4142 va 4126 holatlarining aniq sana va vaqtini olish. Ular "har o'zgarishdan keyin
  tekshiriladigan" test holatlari bo'ladi.
- Har bir ochilgan savdo uchun tuzilgan **Reason Code** jurnalga yoziladi: thesis, WHY ro'yxati,
  invalidation, confidence, qaysi veto'lar tekshirilgan.
- *Natija:* keyingi bosqichlar ta'sirini aniq o'lchash mumkin bo'ladi.

### 1-bosqich: Event Engine (A: faktlar)
- Hodisalar halqa buferi (oxirgi ~50 hodisa), har biri: turi, yo'nalishi, darajasi, TF, kuchi,
  yaratilgan bar, yoshi.
- Hodisa turlari: `LIQ_SWEEP` (buy-side / sell-side), `DISPLACEMENT`, `BOS`, `MSS/CHoCH`,
  `RECLAIM`, `ACCEPTANCE`, `REJECTION`, `COMPRESSION_RELEASE`.
- Mavjud `DetectSweep*`, `MarketStructureRead`, `EventChain` dan foydalaniladi, lekin natija
  signal emas, **hodisa** bo'lib yoziladi.
- *Natija:* "pastda likvidlik olindi → bullish displacement → MSS" ketma-ketligini robot
  ko'ra oladi.

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
- Candle Intent (displacement / rejection / absorption / exhaustion / liquidity-grab /
  fake-breakout …) × Location; Candle Pressure (bull / bear 0-100); acceleration / deceleration.
- Live trigger: sham yopilishini kutmasdan, sham kuchini yo'qotsa signal bekor qilinadi.
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

**0 → 1 → 2 → 4 → 3 → 5 → 6 → 7 → 8 → 9**

4-bosqichni (veto) 3-bosqichdan oldin, faqat Event Engine va Zone Role ustida qilsak, DD'ga
olib kelgan 4142 / 4126 turidagi xatolar eng tez yopiladi. To'liq Market Brain esa undan keyin
quriladi.
