# Sirus Brain V8: tahlil va tuzatish rejasi

## Bajarilganlar (v31.68)

| # | Muammo | Holat |
|---|---|---|
| 1 | Broker tomonida himoya yo'q | ✅ Cashback trailing qo'shildi: savat TP'ga yetganda yopilmaydi, trailing'ga o'tadi. Trailing qulfi brokerga **real SL** sifatida yoziladi (faqat foydadagi savatga). Zarardagi grid'ga SL qo'yilmaydi |
| 2 | Risk limitlari 50% | ➖ Egasining qarori: 50% qoladi |
| 3 | Martingeyl pollari | ⏳ Keyingi bosqich |
| 5 | Hisob turi | ✅ Avtomatik aniqlanadi. Hedging bo'lmasa, yangi kirish va grid o'chadi |
| 6, 10, 11 | Server litsenziyasi / WebRequest | ✅ Modul butunlay olib tashlandi |
| 7, 8 | Yopishda qayta urinish, qisman yopish | ✅ Retcode bo'yicha tarmoqlash, urinishlar orasida pauza, qisman yopishda chiqish deviatsiyasi va natija tekshiruvi |
| 9 | Taymer | ✅ Taymer faqat himoyani ishga tushiradi (emergency, yangilik oynasi, auto-flat). Kirish va grid faqat tikda ishlaydi |
| 12 | Kalendar | ✅ Kesh + har tikda jonli baholash, kengaytirilgan oyna ishlaydi, auto-flat voqea ID'si bo'yicha, `HardBlockFirst=false` bo'lsa ham grid yangilikda to'xtaydi |
| 13 | O'lik inputlar | ✅ 104 ta hech qayerda ishlatilmaydigan input o'chirildi |
| 14 | Takroriy chaqiruvlar | ✅ Faqat dashboard uchun ishlaydigan 2 ta updater har tikda 3 marta emas, 1 marta chaqiriladi |
| 15 | DD'da komissiya | ✅ Kirish komissiyasi keshlanib, DD va savat foydasiga qo'shiladi |
| 16 | Slippage o'lchovi | ✅ Narx yuborishdan oldin olinadi |
| 17 | `sent` ≠ to'ldirildi | ✅ Kirish, grid va scale-in'da retcode tekshiriladi |
| 18 | Qayta init'da holat | ✅ `G_BARS_SEEN` endi nolga qaytarilmaydi, 55 ta `static` kesh himoyalandi |
| 19 | Jurnal shovqini | ✅ `VerboseLogs` umumiy kaliti (165 ta `PrintOnUse` uning ostida) |
| 20, 21 | Sarlavha, `#property strict`, takroriy e'lonlar | ✅ |
| 22, 23 | Kommentlar tarixi, modullarga bo'lish | ⏳ Kompilyatsiya tasdiqlangandan keyin alohida bosqich |

> Raqamlar quyidagi 2-bo'limdagi ro'yxat bo'yicha.


Fayl: `Sirus_Brain_V8.mq5` (versiya 31.67, XAUUSD uchun grid/martingeyl savat EA)

## 1. Umumiy holat (raqamlarda)

| Ko'rsatkich | Qiymat |
|---|---|
| Qatorlar | 58 286 (2,6 MB, bitta fayl) |
| `input` parametrlar | ~3 075 (shundan 376 ta `Enable*`, 170 ta `*PrintOnUse`) |
| Funksiyalar | ~1 180 |
| Global o'zgaruvchilar | ~1 060 |
| `*AllowsEntry` / `*AllowsGrid` filtrlar | 33 / 32 |
| Kommentga olingan kod qatorlari | ~440 |
| Versiya teglari (V12, V222, FIX(...)) | 223 + 100 |

Asosiy oqim: `OnTick` / `OnTimer` → `CoreUpdate()` (`:55701`) → ~60 ta `Update*` modul → `UpdateGridRecoveryEngine` (grid) + `UpdateFirstEntryEngine` (birinchi kirish).

**Asosiy xulosa:** robot ko'p qatlamli "patch ustiga patch" ko'rinishida o'sgan. Savdo mantig'i
kuchli, lekin uni nazorat qilib, test qilib, ishonch bilan o'zgartirib bo'lmaydi. Eng katta xavf
koddagi xatolardan ko'ra **risk modeli** (martingeyl + broker tomonida SL yo'qligi + 50% DD limitlari).

## 2. Topilgan muammolar

### 🔴 Kritik (pul yo'qotishga olib kelishi mumkin)

1. **Broker tomonida himoya yo'q.** Pozitsiyalar `sl=0, tp=0` bilan ochiladi (`UseFirstEntrySL=false`).
   Barcha SL/TP/DD yopishlar faqat EA ishlab turganda bajariladi. VPS uzilsa, terminal qotib qolsa yoki
   `WebRequest` bloklasa, savat himoyasiz qoladi.
2. **Risk standartlari haddan tashqari yuqori.** `BasketSLPercent=50`, `DailyLossPercent=50`,
   `EquityStopPercent=50`, `EmergencyDDPercent=50`, `EmergencyForceCloseDDPercent=52` (`:906-930`).
   Bitta yomon savat hisobning yarmini yo'qotadi.
3. **Martingeyl "pol"lari ehtiyot modullarini bekor qiladi.** `NextGridLot()` (`:43644`) avval 8 ta
   ehtiyot koeffitsiyenti bilan lotni kamaytiradi, keyin `MinGridLotFactor` va
   `EnableAbsoluteGridLotFloor` uni yana yuqoriga ko'taradi. Natijada xavfli vaziyatda ham lot
   deyarli to'liq martingeyl bo'yicha o'sadi.
4. **`StartLot=0.25` balansga bog'lanmagan** (`UseAutoLot` o'chiq). Kichik hisobda 5 ta grid ×1.30
   tez marjin chaqiruviga olib keladi.
5. **Hisob turi tekshirilmaydi.** `ACCOUNT_MARGIN_MODE` hech qayerda o'qilmaydi. Netting hisobida grid
   alohida pozitsiyalar o'rniga bitta pozitsiyani o'zgartiradi, savat mantig'i butunlay buziladi.
6. **Sinxron `WebRequest` savdo oqimida** (`:36765`, timeout 7 s). `CoreUpdate` ichida chaqiriladi,
   server sekin bo'lsa 7 soniyagacha tiklar (yopish buyruqlari ham) ishlanmay qoladi.

### 🟠 Yuqori

7. **Yopishdagi qayta urinish (`CloseNaviusBasket`, `:41109`)** narx yangilanmasdan, pauzasiz ketma-ket
   bajariladi. Requote/off-quotes holatida 3 urinish ham bir xil sabab bilan yiqiladi.
8. **Qisman yopish** (`:41401`, `:41438`) kirish uchun mo'ljallangan 50 punktlik deviatsiya bilan
   ishlaydi va natija (`ResultRetcode`) tekshirilmaydi.
9. **`OnTimer` har 1 soniyada butun `CoreUpdate`ni ishga tushiradi** (kirish va grid ham). Natijalari:
   bozor yopiq yoki tik yo'q paytda eski narx bilan qaror qabul qilinishi, tester'da keskin sekinlashuv,
   va `G_IS_NEW_BAR` taymer tomonidan "yutib yuborilishi".
10. **Litsenziya grace muddatini chetlab o'tish mumkin.** `G_SRV_LAST_OK` saqlanmaydi (`:5633`). Har
    restartda yana to'liq 720 daqiqa beriladi.
11. **Masofaviy buyruqlar (`flat`, `pause`, `lot50`)** oddiy matn javobidan o'qiladi, imzo/autentifikatsiya
    yo'q. URL HTTP bo'lsa yoki server buzilsa, savatni tashqaridan yopish mumkin.
12. **Kalendar "news surprise" kengaytmasi ishlamaydi** (`:39873`). `from_time` faqat
    `EconomicCalendarPostMinutes` orqaga qaraydi, shuning uchun kengaytirilgan oynadagi eski yangiliklar
    umuman yuklanmaydi.

### 🟡 O'rta

13. **3 075 input.** Sozlash oynasidan foydalanib bo'lmaydi, optimizatsiya amalda imkonsiz, ko'plari
    "o'lik" (kommentga olingan modullarga tegishli). Kompilyator/terminal cheklovlari bilan muammo bo'lishi
    ehtimoli bor, MetaEditor'da tekshirish kerak.
14. **Takrorlanuvchi qatlamlar:** `Legacy*`, `Pack2/3/4*`, `Deep*`, `RCSettings*`, `ClientSafety*`,
    `PresetHardening*` bir xil ishni (lot/masofa/ruxsat) qayta-qayta qiladi. `UpdateClientDashboardPolish`
    va `UpdateLiveValidationProbe` bitta tikda 3 martadan chaqiriladi.
15. **Floating DD komissiyani hisobga olmaydi** (`EmergencyBasketForceCloseCheck`, `:40910`: faqat
    `PROFIT + SWAP`).
16. **Slippage noto'g'ri o'lchanadi.** `slip_requested` buyruq bajarilgandan *keyin* o'qiladi (`:49841`).
17. **`sent==true` ≠ to'ldirildi.** `ResultRetcode()` `DONE`/`DONE_PARTIAL` ekanligi aniq tekshirilmaydi.
18. **Qayta init paytida global holat.** ~1 060 globaldan faqat bir qismi `OnInit`da tiklanadi. Funksiya
    ichidagi `static`lar (masalan `last_save_bar`) TF/parametr o'zgarganda eski qiymatda qoladi.
19. **Log shovqini:** 334 ta `Print` + 170 ta `PrintOnUse` (ko'pi `true`). Jurnal o'qib bo'lmas holatga
    keladi, diskni to'ldiradi.

### ⚪ Past / texnik qarz

20. `#property strict` MQL4 uchun, MQL5'da ma'nosiz. Fayl sarlavhasi `Navius_v24...` deb yozilgan, `#property version` esa `31.67`.
21. Takroriy forward e'lonlar (`AutoLotBase` `:471` va `:567`, `AutoGridMultiplier`).
22. Kommentlar uch xil "til"da (o'zbek/ingliz/versiya tarixi), funksiya ichida o'nlab qatorli tarix.
23. Bitta 58k qatorli fayl: modullarga (`.mqh`) bo'linmagan.

## 3. Tuzatish rejasi (bosqichlar)

> Har bir bosqich alohida commit bo'ladi. Savdo xatti-harakatini o'zgartiradigan har bir qadamdan keyin
> MetaEditor'da kompilyatsiya va Strategy Tester'da (oldingi natija bilan solishtirib) tekshirish kerak.

### 0-bosqich: Asos (xavfsiz, xatti-harakat o'zgarmaydi)
- [ ] MetaEditor'da hozirgi holatni kompilyatsiya qilish, xato/ogohlantirishlar ro'yxatini olish *(sizdan)*
- [ ] Bazaviy backtest: XAUUSD, M1, oxirgi 6-12 oy, "Every tick based on real ticks". Hisobot saqlanadi *(sizdan)*
- [ ] Haqiqiy ishlatiladigan `.set` faylni olish (qaysi modullar yoqilganini bilish uchun)

### 1-bosqich: Kritik xavfsizlik
- [ ] `OnInit`: hedging bo'lmagan hisobda yuklanmaslik (#5)
- [ ] Broker tomonida "falokat SL"i: har bir pozitsiyaga savat SL'idan uzoqroq qattiq SL qo'yish (#1)
- [ ] Risk standartlarini xavfsiz qiymatlarga tushirish va `OnInit`da mantiqiy tartibni tekshirish
      (`DailyLoss ≤ BasketSL < EmergencyForceClose`) (#2)
- [ ] Martingeyl pollarini qayta ko'rish: ehtiyot modullari "grid qo'shma" deganda pol lotni oshirmasin (#3)
- [ ] `ProjectBasketRisk`/`LadderIsAffordable` asosida: to'liq zinapoya hisobni ko'tara olmasa, birinchi kirishni ochmaslik (#4)

### 2-bosqich: Ijro ishonchliligi
- [ ] Yopish qayta urinishi: har urinishdan oldin `SymbolInfoTick` bilan yangi narx, retcode bo'yicha tarmoqlash (#7)
- [ ] Qisman yopishda yopish deviatsiyasi va natijani tekshirish (#8)
- [ ] `ResultRetcode` bo'yicha to'liq tekshiruv, slippage o'lchovini tuzatish (#16, #17)
- [ ] Floating DD'ga komissiyani qo'shish (#15)

### 3-bosqich: Arxitektura oqimi
- [ ] `OnTimer` faqat himoya (emergency/DD/yopish) va dashboard; kirish/grid faqat yangi tikda (#9)
- [ ] `WebRequest`ni savdo yo'lidan chiqarish: kam timeout, faqat `OnTimer`da, tik yo'lini bloklamasin (#6)
- [ ] `G_SRV_LAST_OK`ni GlobalVariable'da saqlash, javobga HMAC imzo qo'shish (#10, #11)
- [ ] Kalendar so'rov oynasini kengaytirilgan muddatga moslash (#12)

### 4-bosqich: Soddalashtirish
- [ ] Ishlatilmaydigan (kommentga olingan) modullar va ularning inputlarini olib tashlash (#13, #14)
- [ ] Takroriy `Update*` chaqiruvlarini bittaga tushirish
- [ ] Inputlarni ~100-150 ta asosiy sozlamaga qisqartirish, qolganlarini konstantaga aylantirish
- [ ] `PrintOnUse` → bitta `LogLevel` input (#19)

### 5-bosqich: Modullarga bo'lish
- [ ] `Sirus_Brain_V8.mq5` + `Include/Sirus/*.mqh` (Risk, Grid, Entry, Execution, News, License, Dashboard, Analysis)
- [ ] Sarlavha/versiyani bir xillashtirish, eski versiya tarixini `CHANGELOG.md`ga ko'chirish (#20-23)

### 6-bosqich: Tasdiqlash
- [ ] Har bosqichdan keyin backtest natijasini 0-bosqich bilan solishtirish (Profit, Max DD, Recovery Factor, savdolar soni)
- [ ] Demo hisobda 1-2 hafta forward test

## 4. Sizdan kerak bo'ladigan ma'lumotlar

1. Broker va hisob turi: hedging yoki netting, kotirovka xonasi (3 yoki 2 xonali XAUUSD), komissiya.
2. Hozir ishlatayotgan `.set` fayl va hisob balansi.
3. MetaEditor kompilyatsiya natijasi (xatolar/ogohlantirishlar).
4. Risk bo'yicha qaroringiz: savat SL'i balansning necha foizi bo'lishi kerak (hozir 50%).
5. Server litsenziyasi (`EnableServerLicense`) ishlatiladimi?

> Eslatma: bu muhitda MetaEditor yo'q, shuning uchun men kodni kompilyatsiya qila olmayman va backtest
> o'tkaza olmayman. Har bir o'zgarishni siz MetaEditor/Tester'da tekshirib, natijani yuborasiz.
