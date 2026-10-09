# CHANGELOG — Sirus Brain V8

## TEMPO klapani: filtrlar ortiqcha to'sganda savdo oqimini tiklash (09-Oct: 7 soatda 3 ta savdo)

- **Holat.**
  - 09-Oct Osiyo sessiyasida 7 soatda faqat 3 ta savdo bo'ldi.
  - Soya: 354 ta to'silgan setupdan 91% i TP ga yetardi. O'tkazilgan yaxshi setuplar: 322.
  - To'siqlar: "ball yetmadi" 45%, "miya taqiqi" 28%, "drift" 8%.
  - Har bir filtr alohida to'g'ri, lekin hammasi birga deyarli hech narsani o'tkazmadi.
- **TEMPO qachon yoqiladi.** Ikki shart birga bajarilishi kerak:
  - `TempoQuietMinutes` (15) daqiqa kirish bo'lmagan;
  - oxirgi kamida `TempoMinRefusals` (10) ta to'silgan setupning kamida `TempoMinTPRate` (80%) i TP ga yetgan.
  - Shunda `TempoMinutes` (20) daqiqaga vaqt va sifat filtrlari yumshaydi.
- **Nima yumshaydi:**
  - detektor balli, hakam, joy/zona/HTF-rejim oilasi (soya klapani hammasini birga yoqadi);
  - "kech kirish" to'siq emas;
  - charchash chegarasi +15;
  - olingan likvidlik: faqat daraja ostidagi/ustidagi burilish zonasi (0.5 ATR(M5)) to'sadi;
  - drift chegarasi 2 barobar.
- **Kimga tegishli.** Faqat yo'nalish jihatidan xavfsiz tomonga: global biasga qarshi emas va buzilmagan M5 tuzilmasiga qarshi emas.
- **Hech qachon yumshamaydi:**
  - V0 yo'nalish ruxsati;
  - LOCK;
  - kengash (uchlik, 1e M5 tuzilma, 1f yangi M15/H1 buzilishi);
  - yangilik, spread, risk, anomaliya.
- **Drift himoyasi** navbatdagi signalni qayta o'ynatish uchun yozilgan. Endi u miya tez kirishiga umuman qo'llanmaydi, chunki tez kirish jonli narxda baholanadi.
- **Panel.** Soya qatorida `⚡ TEMPO N daq` ko'rinadi. Jurnalga `[SIRUS TEMPO] on ...` yoziladi.

## Yangi M15/H1 buzilishiga qarshi kirish yo'q (08-Oct 22:20 BRAIN HANDOFF SELL 4135.106)

- **Holat.**
  - 22:05–22:13 da narx M15 dagi past cho'qqini (4134.85) yuqoriga buzdi. M15 bari 22:15 da yopilgach MSS yuqoriga yozildi.
  - Bias, global tezis va LOCK bir necha daqiqa kechikdi: bias 2 bar tasdiq kutadi, lock M5 bar yopilishida yoqiladi.
  - Shu oraliqda BRAIN HANDOFF "trendga qarshi qaytishning tepasi" deb 4135.1 da SELL ochdi. Bu breakout retestini sotish edi.
- **Kengash qoidasi 1f.**
  - M15 yoki H1 da oxirgi 60 daqiqada yopilgan, muvaffaqiyatsiz bo'lmagan va hali ushlab turgan BOS/MSS bo'lsa, teskari kirish to'siladi. "Ushlab turgan" degani: oxirgi yopilgan M5 hali buzilish tomonida.
  - Qoida uch holatda yechiladi:
    - M5 daraja orqasiga qaytib yopilsa;
    - buzilish muvaffaqiyatsiz chiqsa;
    - burilish MSS bosqichiga (3/6) yetsa.
  - **Jonli qism:** M15 bari hali yopilmagan bo'lsa ham, M15 tuzilmasi bir tomonga qarab turgan, lekin M5 uning himoyalangan swingi orqasida yopilgan bo'lsa, tuzilma buzilgan hisoblanadi.
  - Barcha kirishlarga tegishli, chunki ular kengashdan o'tadi: HANDOFF, TREND, PULLBACK, FAST RE-ENTRY, SECOND-CHANCE va detektorlar. Ularning hammasi kechikadigan bias yoki tezisga tayanadi.
  - Sozlamalar: `EnableCouncilFreshBreak`, `CouncilFreshBreakMinutes` = 60.

## Tuzilma birinchi: M5 tuzilmasi buzilmaguncha unga qarshi sham "pullback" (08-Oct 18:56 va 19:53 dagi SELL'lar)

- **Holat.**
  - 18:30 dan keyin M5 da aniq ko'tarilish bo'ldi: tublar 4121 → 4124 → 4127 → 4128 → 4128.1.
  - Robot ikki marta ko'tarilishning o'rtasida SELL ochdi: 18:56 da 4127.075 va 19:53 da 4130.126.
- **Sabablar.**
  - 19:40 dagi qizil M5 shami 4128 dagi tekis tublarni bir oz kesib o'tdi. Bu "M5 bearish BOS" deb yozildi, garchi keyingi barlar yana tepada yopilgan bo'lsa ham, ya'ni bu likvidlik ovi edi. Natijada M5 holati 20:12 gacha "▼" bo'lib turdi.
  - Yangi M5 impulsi har doim lokal qatlamni belgilardi. Bitta qizil sham lokalni pastga burdi.
  - Pullback tugashi deb bitta M1 shamining tubi kesilgani o'qildi.
- **1. Muvaffaqiyatsiz buzilish tuzilma emas.**
  - Keyingi 1–2 yopilgan bar daraja orqasiga 0.1 ATR qaytsa, BOS yoki MSS likvidlik ovi hisoblanadi va tashlab yuboriladi. Undan oldingi tuzilma amalda qoladi.
  - Bu barcha TF holatiga va biasga ta'sir qiladi.
- **2. Lokal qatlam: tuzilma birinchi.**
  - Buzilmagan M5 tuzilmasi lokal yo'nalish hisoblanadi.
  - Unga qarshi impuls, sof harakat yoki bosim, himoyalangan swing orqasida M5 yopilishi bo'lmaguncha, pullback hisoblanadi.
- **3. Kengash qoidasi 1e.**
  - Buzilmagan M5 tuzilmasiga qarshi kirish uchun ikkalasi birga kerak:
    - yopilgan, hali buzilmagan M5 burilish shami;
    - narx M5 oyog'ining uzoq yarmida bo'lishi (up-oyoqning tepasida SELL, down-oyoqning tubida BUY).
  - Yoki burilish MSS bosqichiga (3/6) yetgan bo'lishi kerak.
  - M1 shamlari yetmaydi.
  - Barcha kirishlarga tegishli: detektor, miya nomzodlari, veto.
  - Sozlamalar: `EnableCouncilM5Structure`, `CouncilM5StructLegPos` = 0.5.
- **4. Pullback tugashi uchun M1 tuzilmasi buzilishi kerak.** Narx oxirgi 3 ta yopilgan M1 shamining ekstremumidan o'tishi kerak.
- **5. O'tish holatida maqsadi bajarilgan tomonga davom kirishi yo'q.** Masalan, tekis tublar olinib, narx qaytgan bo'lsa.
- **6. Panel.** Savat ochiq paytda "Sabab" qatori savat holatini ko'rsatadi.
- **Qolgan sham o'qishlari tekshirildi.**
  - Trigger (M1/M5), MOMENTUM, SWEEP, LOCAL, ALIGNED, V0 momentum tasdig'i va kengash 4-qoidasi endi tuzilmaga asoslangan lokal qatlam va 1e qoidasi orqali o'tadi. Ular tuzilma bilan birga kirish vaqtini aniqlaydi, tuzilmaga qarshi kirishni yolg'iz o'zi ochmaydi.
  - Grid uchun "M5 displacement qarshi bo'lsa grid to'xtaydi" himoyasi o'zgarmadi.

## Audit qoldiqlari: SELL og'ishi, tezlik, ishga tushish

- **SELL og'ishi.**
  - SWEEP, MOMENTUM va ALIGNED nomzodlari har doim avval SELL'ni tekshirardi, shuning uchun ikkala tomon bir tickda teng bo'lsa SELL yutardi.
  - Endi birinchi tekshiriladigan tomon bozorga qarab tanlanadi:
    1. global bias;
    2. bias bo'lmasa, lokal oyoq;
    3. u ham bo'lmasa, nazorat ulushi;
    4. to'liq teng bo'lsa, navbatma-navbat.
- **Tezlik.**
  - Skaner har bir skanda savat sonini 0 ga tushirardi, grid esa uni keyinroq tiklardi. Shuning uchun savat ochiq paytda "savat soni o'zgardi" deb to'liq skan har tickda qayta ishlardi.
  - Endi skan qaror qilingan paytdagi son saqlanadi.
- **Ishga tushish.**
  - Miya "tayyor" belgisini faqat quyidagilar tayyor bo'lgandan keyin qo'yadi:
    - M1, M5 va M15 ATR;
    - M5 va M15 voqealar tarixi.
  - Ilgari birinchi M1 barda, ma'lumot bo'sh bo'lsa ham, qo'yilardi.

## Tanqidiy audit: first entry (3 bosqich)

Kod to'rt qismga bo'lib tekshirildi:
- oxirgi o'zgarishlar;
- first entry zanjiri;
- miya veto'si, kengash va hakam;
- 20a–20f modullari.

Har bir topilma kodda qayta tasdiqlandi. Asosiy natija: buyruq har doim veto va hakam tekshirgan yo'nalishda yuboriladi. Muammolar undan oldinroq edi: noto'g'ri dalil, eskirgan holat va bir-birini qulflaydigan qoidalar.

### 1-bosqich: noto'g'ri yo'nalish xavfi
- **A1 — M5/M1 burilish shami jonli tekshiriladi.** Narx shamning dumini buzsa yoki yopilishidan 0.5 ATR qaytsa, sham endi tasdiq emas. Ilgari 5 daqiqa tasdiq bo'lib turar edi va BUY sinish ichiga kirishi mumkin edi.
- **A2 — Konsensus yo'nalishni almashtirganda setup to'liq yangi tomondan olinadi.** Turi, darajasi, micro bayrog'i va sababi yangi tomonniki bo'ladi. Ilgari SELL BUY'ning "sweep rejection" turi bilan qolib, V0 dan "burilish" deb o'tardi.
- **A3 — Lokal qatlam: impulsning kuchi ekstremumining yoshiga qarab.**
  - Ekstremum oxirgi 6 ta M5 bar ichida yangilangan bo'lsa, impuls yo'nalishni belgilaydi. Yangi displacement'ni eski 30 daqiqalik harakat bosa olmaydi.
  - Eski bo'lsa, impuls faqat quyidagilarning hech biri teskari bo'lmagandagina gapiradi: sof harakat, M5 bosimi, M5 tuzilmasi, lokal oyoq.
- **A4 — Lokal oyoq eskirmaydi.**
  - M1 va M5 bosimi ikkalasi qarshi bo'lsa yoki 90 daqiqa o'tsa, lokal oyoq tugaydi.
  - M5 bosimi qarshi bo'lsa, u lokal qatlamni belgilamaydi.
  - Maqsadi narxning orqasida qolgan oyoq yaratilmaydi.
- **A5 — Burilish bosqichi jonli o'qiladi.** Narx MSS darajasidan qaytib o'tsa, bosqich 3 ga tushadi. Shunda lock va REVERSAL kirishi minut tugashini kutmaydi.
- **A6 — Savat yopilgan tickning o'zida yangi savat ochilmaydi.** Zarardan keyingi pauza va qayta kirish xotirasi keyingi tickda yoziladi, shuning uchun bu tick o'tkazib yuboriladi.
- **A7 — Kuchli biasga qarshi "istisno burilish" kuchaytirildi.** Endi oxirgi bir soat ichida M5 yoki undan yuqori (yoki KEY) likvidlik burilishi kerak. Bitta M1 sweep yetmaydi.
- **A8 — Xavfsizlik klapani har qanday haqiqiy kirishni hisoblaydi.** Ilgari faqat detektor kirishlarini sanardi va savdo bo'layotgan paytda ball to'siqlarini ochib yuborardi.
- **A9 — Tasdiqlangan setup bonusi faqat qurollangan tomonga beriladi.** Arm ham faqat o'z tomonidagi yengilliklarni ushlab turadi.
- **C1 — Grid spike'da qo'shilmaydi.** Grid tezlik pauzasining asl qoidasida qoldi: qat'iy chegara, byudjet yo'q. Moslashuvchan chegara va byudjet faqat first entry uchun. Pauza bilan qoplanmagan spike'da "jonli tezlik" bonusi berilmaydi.

### 2-bosqich: jimlik va savdo soni
- **B1 — Kengash 1d qoidasi.**
  - Strukturaga mos tomon endi o'z dalili bilan ochiladi: yopilgan M5 burilish shami yoki bir soat ichidagi M5+/KEY likvidlik burilishi.
  - Qarshi tomonning "olingan likvidlik" sababi endi "kech" deb hisoblanmaydi.
- **B2 — Tez kirish nomzodlari to'liq veto bilan tekshiriladi.**
  - Tekshiruv: MBDirOk (lock, kech, qayta kirish, xarajat, anomaliya, kengash) va V0 ruxsati, o'zi oladigan tur bilan.
  - Qamrab olinganlar: FAST RE-ENTRY, REVERSAL, SECOND-CHANCE, TREND, HANDOFF, PULLBACK, SWEEP, RANGE, MOMENTUM, LOCAL, ALIGNED.
  - Natija: veto'ga uriladigan nomzod boshqa setuplarni 20–40 daqiqa yashirmaydi.
- **B3 — Broker TP bilan yopilgan yutuq ham "yutuq".** Shu bilan TP dan keyingi tez qayta kirish yengilligi ishlaydi.
- **B4 — "Kutish" faqat setup haqiqatan qurollanganda.** `SetupArm` endi natija qaytaradi. Qurollanmagan setup kutishda qotib qolmaydi.
- **B5 — BUY va SELL joyi bir xil o'lchanadi (bid'dan).** Xarajat, olingan likvidlik va oyoq foizida BUY'dan spread ikki marta olinmaydi.
- **B6 — Voqealar yoshi barning yopilishidan hisoblanadi.** H1/H4 voqealari, diapazondagi M15, qayta kirishdagi "yangi break" va lock yangilanishi kelishi bilan eskirmaydi.
- **B7 — O'tish holatida davom kirishi "micro control" o'chiq bo'lsa ham ishlaydi.**
- **B8 — Spread xotirasi har hisob uchun alohida.** Spread 30 namuna ketma-ket 3 barobar katta bo'lsa, u yangi odatiy deb qabul qilinadi.

### 3-bosqich
- **C2 — Miya kirishi skaner kontekstini meros qilib olmaydi.**
  - Trendga qarshi kirishning zinapoya cheklovi to'g'ri qo'llanadi.
  - Boshqa tomonning ogohlantirish og'irligi va micro bayrog'i olib tashlanadi.
  - Minimal ball 0 bo'lib qolmaydi.
  - Vaziyat bo'yicha lot va TP faqat o'z yo'nalishiga.
- **C3 — Mayda tuzatishlar.**
  - Yangilik "tinchlandi" ro'yxati to'liq kesh hajmida.
  - Natija kutilganidan keskin farq qilgan yangilikda kamida odatiy post-oyna saqlanadi.
  - Hakamning sinov chaqiruvi kechikish langarini siljitmaydi.
  - Miya ma'lumoti tayyor bo'lmasa, hakam KUTADI.
  - Muvaffaqiyatsiz redirect holatni to'liq tiklaydi.
  - Muddati o'tgan blokning yengilligi faqat o'sha blok kutgan tomonga beriladi.
  - Olingan likvidlik himoyasi haqiqiy TP bilan o'lchaydi.
- **C4 — MSS'dan keyingi retest.** M15/H1 MSS endi o'z barining yopilishidan hisoblanadi. Ilgari "retest" oynasi break'dan oldingi barlarni ham olardi va burilish 3/6 da qotib qolardi. Sweep ekstremumi voqeaning o'zidan olinadi.

## Lokal qatlam eski impulsga yopishmasin + o'tish holatida tasdiqlangan burilish bo'yicha davom kirishi

- **Holat 1 (18:56 SELL 4127.075).**
  - Yangilikdan keyingi tushish (4145 → 4121.4) M5 da bitta uzun "impuls" deb o'qilgan. Impuls oxirgi bir xil yo'nalishdagi displacement'lar zanjirining boshigacha cho'ziladi, shuning uchun oyoq taxminan $20 va 2 soatlik bo'lib chiqqan.
  - 4121.4 → 4129.5 ko'tarilishi uning 40% i edi, impuls tugashi uchun 62% kerak. Shu sababli lokal qatlam ko'tarilish davomida "▼" deb turdi.
  - Holbuki o'sha paytda lokal oyoq ▲ (maqsad 4133.45), M5 bosimi ▲ va M1 ▲ edi.
  - Kengashning 1b qoidasi ("lokal + M5 qarshi → yopilgan M5 burilishi kerak") ishga tushmadi va SELL ko'tarilishning o'rtasida ochildi.
- **Tuzatish 1.** M5 impulsi lokal qatlamni faqat yaqin harakat unga zid bo'lmasa belgilaydi. Zid holatlar:
  - oxirgi 6 ta M5 yopilishidagi sof harakat ≥ 1 ATR teskari tomonga;
  - yoki faol lokal oyoq va M5 bosimi ikkalasi teskari tomonga.
  - Zid bo'lsa, lokal = sof harakat yoki lokal oyoq. Endi bunday SELL kengashda to'xtaydi.
- **Holat 2 (17:56–18:30).**
  - Toza pasayish bo'ldi ($11): lokal ▼, mikro ▼, M5 ▼, nazorat SELL 88%.
  - Lekin bias "TRANSITION_DOWN" bo'lgani uchun V0 qoidasi faqat burilish setupini o'tkazdi. Bir soat SELL bo'lmadi.
- **Tuzatish 2.** O'tish holatida burilish tasdiqlangan bo'lsa, davom kirishlariga ham ruxsat. Uchala shart birga bajarilishi kerak:
  - lokal qatlam shu tomonga;
  - M5 bosimi yoki M5 tuzilmasi shu tomonga;
  - nazorat ≥ 65%.
  - Kengash, kech, charchash, zona, olingan likvidlik veto'lari o'z joyida.
  - Hakam, tezkor qayta kirish va ball yordami ham shu qoidaga moslandi.
  - Sozlamalar: `EnableTransitionContinuation` = true, `TransitionControlPct` = 65.

## Diapazonda tubdagi BUY "olingan likvidlik" bilan to'silmasin (17:25–18:10, 4127–4134 diapazoni)

- **Holat.**
  - Yangilikdan keyin narx 4127–4134 diapazonida yurdi. SELL tepada 2 marta ochildi, ikkalasi TP ga yetdi.
  - Tubdagi BUY esa "oldindagi likvidlik olingan" deb 1 soat davomida to'sildi. Sabab: diapazon tepasi 4134 olinib qaytgan edi.
  - Himoya BUY'ni olingan tepadan 1 ATR(M5) gacha pastda to'sardi. Volatillik yuqori bo'lganda bu deyarli butun diapazon edi.
- **1. Joy bor bo'lsa — to'siq yo'q.** Himoya endi faqat ikki holatda to'sadi:
  - olingan darajagacha joy (spread + TP) × 1.2 dan kam bo'lsa;
  - narx o'sha daraja ostida/ustida 0.5 ATR(M5) ichida, ya'ni burilish zonasida bo'lsa.
  - Diapazon tubidagi BUY'ning TP si uchun joy yetarli, shuning uchun to'silmaydi. 4142 holati (olingan tepaning ostida BUY) avvalgidek to'siladi.
  - Joy kirish paytidagi jonli narxdan o'lchanadi.
- **2. Diapazonda xotira qisqa.** RANGE yoki SIQILISH rejimida olingan likvidlik 15 daqiqa eslab qolinadi. Trendda avvalgidek 60 daqiqa.
- **Sozlamalar** ("BRAIN ▸ Entry location & exhaustion"):
  - `TakenLiqRoomMult` = 1.2;
  - `TakenLiqBlockATR5` = 0.5;
  - `TakenLiqRangeMinutes` = 15.

## Yangilikdan keyingi pauza bozor tinchlanganda tugaydi (17:25: 31 daqiqa jimlik, "kalendar 46%")

- **Holat.**
  - Yuqori ta'sirli USD yangiligi (17:13 dagi 4134 → 4145 spike) atrofida kalendar himoyasi 15 daqiqa oldin va 15 daqiqa keyin kirishni to'xtatdi.
  - Natija prognozdan 20% dan ko'p farq qilsa, pauza 45 daqiqagacha uzayadi.
  - Bitta yangilik 30–60 daqiqa jimlik berardi, bozor tinchlangandan keyin ham.
- **Yangi qoida.** Yangilikdan keyingi pauza quyidagi shartlar birga bajarilganda tugaydi:
  - yangilikdan kamida 5 daqiqa o'tgan;
  - oxirgi 2 ta yopilgan M1 sham ham tinch, ya'ni har birining kattaligi yangilikdan oldingi ATR(M1) × 1.5 dan kichik;
  - spread shu soatning odatiy darajasi × 1.5 dan oshmaydi;
  - g'ayritabiiy holat himoyasi jim.
- **Qaror qulflanadi.** Har bir yangilik uchun bir marta qaror qilinadi. Pauza tugagach, yo'nalishni miya (kengash, kech, lock) tanlaydi.
- **O'zgarmadi.** Yangilikdan oldingi pauza, yangilikdan oldin foydada yopish (auto-flat) va eng uzoq chegara (15/45 daqiqa) avvalgidek.
- **Log.** `[SIRUS CALENDAR] <nom>: market settled N min after the release ... post-news pause ended`
- **Sozlamalar** ("ADVANCED ▸ Real economic calendar"):
  - `EnableNewsSettleRelease` = true;
  - `NewsSettleMinMinutes` = 5;
  - `NewsSettleBars` = 2;
  - `NewsSettleRangeATR` = 1.5;
  - `NewsSettleSpreadMult` = 1.5.
- **Tezlik.** Tekshiruv faqat yangilikdan keyingi oynada va har M1 barda bir marta ishlaydi.

## Tezlik himoyasi faol bozorni bo'g'masin (16:41: 23 daqiqa jimlik, "tezlik 62%")

- **Holat.**
  - 16:16 dagi katta sakrashdan (4111 → 4132) keyin bozor faol qoldi, volatillik 83-foizda edi.
  - Tick tezligi himoyasining qat'iy chegarasi bor edi: 5 soniyada 400 punkt va tick tezligi 4 barobar. Bunday bozorda bu oddiy harakat, shuning uchun himoya har 30 soniyada qayta yoqilib turdi.
  - Natija: 23 daqiqa kirish bo'lmadi. Soya hisobiga ko'ra, to'silgan 24 setupdan 23 tasi TP ga yetgan bo'lardi.
- **1. Moslashuvchan chegara.** Sakrash deb hisoblanishi uchun harakat 400 punkt VA ATR(M1) × 1.5 dan katta bo'lishi kerak. Faol bozorda oddiy harakat sakrash emas.
  - Sozlama: `VelocityMoveATRMult` = 1.5 (0 = faqat qat'iy punkt).
- **2. Taqiq byudjeti.** Tezlik pauzasi har 5 daqiqada jami ko'pi bilan 60 soniya.
  - Haqiqiy portlash ushlanadi, keyingi faol bozorda kirish ochiq qoladi.
  - Byudjet tugaganda logda yoziladi: `pause budget ... used, entries stay open`.
  - Sozlama: `VelocityMaxHoldPer5Min` = 60 (0 = cheklovsiz).
- **O'zgarmadi.**
  - Rejalashtirilgan yangilik himoyasi (kalendar oynasi) avvalgidek ishlaydi.
  - Ochiq savat boshqaruviga tegilmadi.
  - Jonli tezlik yo'nalishi (`LiveVelocityDirection`) yangi chegarani ishlatadi, pauza byudjetiga bog'liq emas.
- **Tezlik.** ATR(M1) faqat tick tezligi va punkt shartlari bajarilgandagina o'qiladi, oddiy tick'da qo'shimcha hisob yo'q.

## Pullback yoki reversal? (16:00 BRAIN TREND BUY 4111.87 holati) + TP'dan keyin darhol qayta kirish

- **Holat.**
  - Bias hali eski ko'tarilishdan qolgan TREND ▲ holatida edi, holvaki M5 ikki marta pastga buzilgan edi (▼×2).
  - Lokal, mikro va M1/M5/M15 bosimi ham ▼ edi.
  - Robot buni pullback deb o'qib BUY ochdi, narx esa tushishda davom etdi.
- **1c. Trend hujumda.** Bias tomoniga kirish to'xtaydi, agar quyidagilardan biri bo'lsa:
  - M5 trendga qarshi ketma-ket 2 marta buzilgan;
  - qarshi burilish MSS bosqichiga (3/6) yetgan;
  - M5 bir marta qarshi buzilgan va M5 hamda M15 bosimi qarshi.
  - M5 trend tomoniga qayta buzilmaguncha bias tomonga kirilmaydi. Bu TREND, PULLBACK, RE-ENTRY va boshqa barcha kirishlarga (veto orqali) tegishli.
- **1b. M5 burilishi.** Lokal oyoq va M5 bosimi qarshi bo'lsa, faqat yopilgan M5 burilish shami hisoblanadi. Bitta M1 shami burilish emas. Sozlama: `EnableCouncilM5Turn`.
- **1d. Charchash teskari signal emas.** Qarshi tomon "kech / charchagan / maqsadi olingan" deb yopilgan bo'lsa-yu, harakat hali o'sha tomonga davom etayotgan bo'lsa (lokal yoki M5), bu tomonga kirish uchun o'z dalili kerak: kamida 2-bosqichli burilish (likvidlik olindi + displacement).
- **Tezlik: TP'dan keyin qayta kirish.**
  - Foyda bilan yopilgandan keyin signal bo'lsa, darhol kiriladi. Yangi bar kutish olib tashlandi, u 60 soniyagacha kechiktirardi.
  - Quvmaslik (1 ATR(M5)) va nazorat tekshiruvlari qoldi.
  - Zarar yoki g'oya o'lib yopilgandan keyin esa avvalgidek yangi dalil kutiladi.

## Sozlamalar oynasi: brend darajasida, tushunarli

- **Muammo.** MT5 sozlamalar oynasida har sozlama nomi o'rniga uning izohi ko'rsatiladi. Izohlar esa dasturchi eslatmalari edi ("V249fix: 7 -> 5 ...", "Close at break-even and collect the rebate..."). Jami 3206 ta sozlama va 169 ta bo'lim bor edi, raqamlar aralash, bir qismi ulanmagan.
- **Tepada SIRUS ▸ Quick Setup.** 7 bo'lim, 43 asosiy sozlama:
  - General;
  - Lot size;
  - Grid recovery;
  - Take profit & exit;
  - Cashback mode;
  - Protection;
  - Display & alerts.
- **Har sozlamaga qisqa, aniq inglizcha nom berildi.** Masalan, `Start lot (first order)`, `Cashback mode`, `Basket stop loss (% of balance)`. Eski texnik izoh kodda, sozlamaning ustidagi qatorda saqlandi.
- **Bo'limlar bir xil uslubda:**
  - `ADVANCED ▸ ...`;
  - `BRAIN ▸ ...`;
  - `DISPLAY ▸ ...`;
  - `DIAGNOSTICS ▸ ...`.
  - Hech qayerga ulanmagan bo'limlar `(inactive)` deb belgilandi.
- **Ro'yxat qiymatlari:**
  - Trading mode: AUTO (adaptive) / BALANCED / HIGH HUNTER (aggressive);
  - Micro TP mode: AUTO / FIXED / % OF MAIN TP / DYNAMIC.
- **Presetlar buzilmaydi.** O'zgaruvchi nomlari va qiymatlari o'zgarmadi, faqat ko'rinadigan nomlar va tartib o'zgardi.
- **Qo'llanma:** `SETTINGS_GUIDE.md`.

## Grid: tasdiqsiz pog'ona yo'q (egasi qoidasi)

- **Tuzatildi.** Tasdiqsiz grid qo'shadigan ikki joy bor edi:
  1. qutqaruv kafolatida 2.5 qadamdan keyin pog'ona majburan qo'shilardi;
  2. eski koddagi qoida: oddiy dolivkada sham javobi 15 daqiqa kelmasa, pog'ona baribir qo'shilardi.
- **Endi:** grid hech qachon tasdiqsiz qo'shmaydi. Kutish faqat tasdiq talabini pasaytiradi, bekor qilmaydi:

| Holat | Tasdiq |
|---|---|
| Oddiy dolivka | Zonada sham javobi |
| 15 daqiqa javob kelmasa | Qarshi harakat **to'xtagan** bo'lishi kerak |
| Qutqaruv, 1.5 qadam | Qarshi harakat **sekinlashgan** |
| Qutqaruv, 2.5 qadam | Sekinlashgan **yoki** to'xtagan |

- "To'xtagan" deganda uch shart birga tushuniladi:
  - hozir qarshi tomonga displacement yo'q;
  - oxirgi M1 shami qarshi displacement, davom etish yoki breakout emas;
  - oxirgi M1 yangi ekstremum qilmadi.
- Odatda bu bir necha daqiqada keladi, shuning uchun grid muzlamaydi va impuls ichiga ham kirmaydi.

## Grid: qutqaruv kafolati — grid muzlab qolmaydi

- **Muammo.**
  - Grid qo'shishni 60 dan ortiq joy to'xtatishi mumkin edi:
    - `GridCanOpen` ichida 52 ta;
    - miya grid darvozasida 12 ga yaqin.
  - Ularning ko'pi "hozircha kut" shartlari edi va chiqish yo'li yo'q edi. Masalan: eski pack filtrlari, cooldown'lar, "shamlar qarshi", "BE katta daraja ortida", "tiklanish shubhali", javobsiz zaxira pog'ona.
  - Narx savatdan uzoqlashib ketaverar, grid qo'shilmas, savat katta DD da qolib ketardi.
- **Tuzatish (`EnableGridRescueGuarantee`).** Har bir yumshoq to'siq endi "yaxshiroq narxni kut" degani. "Hech qachon" degani emas:
  - narx oxirgi orderdan **1.5** rejalashtirilgan qadam uzoqlashsa va qarshi harakat sekinlashsa, yumshoq to'siqlar chetlab o'tiladi. Sekinlashish belgilari:
    - qarshi harakatning charchashi 30+;
    - savat tomoniga sham chiqdi;
    - M1/M5 bosimi endi qarshi emas;
    - qarshi impuls kech.
  - **2.5** qadam uzoqlashsa, yumshoq to'siqlar har holda chetlab o'tiladi.
  - Kiradigan pog'ona oddiy pog'ona bo'ladi: masofa, lot va barcha qattiq tekshiruvlar o'z joyida.
  - Pog'ona qo'yilgach, hisob yangi orderdan qayta boshlanadi. Bir harakatda faqat bitta qutqaruv pog'onasi qo'yiladi, ketma-ket qo'shilib ketmaydi.
- **Qattiq to'siqlar o'zgarmadi:**
  - savdo yoki muhit o'chiq;
  - savat foyda trailing'ida;
  - hisob, marja va ekspozitsiya chegaralari;
  - grid chuqurligi byudjeti;
  - maksimal order soni;
  - hafta oxiri;
  - tezlik sakrashi;
  - rejalashtirilgan yangilik;
  - miya g'oyasi o'lgan (BE da chiqish);
  - IMKONSIZ chiqishi qurollangan.
- **Panel (SAVAT bo'limi):** `Grid kutmoqda 14 daq · narx 1.2 qadam · <sabab> · qutqaruv 1.5 qadamda`. Kafolat ishga tushsa: `QUTQARUV: grid to'siqlari chetlab o'tiladi - 1.6 qadam + qarshi harakat charchash 42`.
- **Jurnal:** `[SIRUS GRID RESCUE] ... - stepped over: <qaysi to'siqlar>`.
- **Autopsiya:** yangi belgi **GRID MUZLADI** — grid savatni 30 daqiqa va undan ko'p ushlab turgan bo'lsa.

## Audit: 1–8 bosqich modullari

Kompilyatsiya xatosi topilmadi: prototiplar, chaqiruv imzolari, havolalar, format qatorlari va massivlar tekshirildi. Yo'nalish belgilari ham to'g'ri. Tuzatilgan 7 ta kamchilik:

1. **LOCK qayta yoqilib qolardi.** Lock tugagach, u o'sha dalil bilan keyingi M5 barda yana yoqilardi va yo'nalish yopiq qolaverardi. Endi lock'ni yoqqan sweep ishlatilgan deb belgilanadi va qayta yoqish uchun yangi sweep kerak bo'ladi.
2. **Zaif soxta buzilish ketma-ketlikni qisqartirardi.** ZAIF buzilish ketma-ketlikka qo'shilmagani holda, soxta chiqqanda undan ayirilardi. Endi faqat ketma-ketlikka qo'shilgan buzilish ayiriladi.
3. **Yangi sweep eski "tuzoq" belgisini meros olardi.** Tuzoq bo'lgan sweep yonidagi yangi sweep u bilan birlashib, "tuzoq" belgisini olib qolardi. Endi yangi sweep tuzoq bilan birlashmaydi.
4. **Yopilish sababi eskirib qolardi.** Sabab o'qilgandan keyin tozalanmasdi. Broker TP/SL bilan yopilgan keyingi savat eski sababni ("g'oya o'ldi") meros olardi. Endi sabab bir marta o'qiladi va tozalanadi.
5. **Modul o'chirilsa eski holat qolardi.** Endi o'chirilganda LOCK va burilish nolga tushadi, likvidlik xaritasi tozalanadi.
6. **Ikkinchi imkoniyat xotirasi eskirib qolardi.** Endi har qanday birinchi kirishdan keyin u tozalanadi.
7. **Panelda ogohlantirish.** O'zgaruvchi nomi takrorlanib, kompilyator ogohlantirish berardi. Nom o'zgartirildi.

## Katta reja — 8-bosqich: bozor holati, sezgirlik, g'ayritabiiy bozor, ssenariylar, hikoya

Yangi modul: `Sirus/20f_Market_State.mqh`. Bu modul bozorni qaytadan o'qimaydi. U boshqa qatlamlar allaqachon o'qigan narsalarni (rejim, bias, lock, burilish, likvidlik xaritasi, charchash, nazorat) bitta xulosaga yig'adi.

- **Sezgirlik.** So'nggi 5 ta M1 diapazoni ATR(M1) bilan solishtiriladi va 5 bar tezligi ham hisobga olinadi. Natija:
  - sokin;
  - oddiy;
  - faollashmoqda;
  - kengaymoqda;
  - tez;
  - charchadi (kengayishdan keyin so'nish).
- **G'ayritabiiy bozor (`EnableAnomalyGuard`).** 5 daqiqa davomida yangi kirish bo'lmaydi, agar:
  - spread shu soat uchun odatiydan 2.5 barobar katta bo'lsa;
  - M1 bari 4 ATR bo'lsa;
  - ikki tick orasida narx 1 ATR(M5) sakrasa.
- **Bozor holati.** 15 ta holat va holatlar orasidagi o'tish jurnalga yoziladi (`[SIRUS STATE]`):
  - YANGILIK/G'AYRITABIIY;
  - BURILISH TASDIQLANDI / RIVOJLANMOQDA;
  - LIKVIDLIK OVI;
  - CHARCHASH;
  - BREAKOUT;
  - KENGAYISH;
  - SOXTA BREAKOUT;
  - KUCHLI TREND / TREND;
  - PULLBACK;
  - TO'PLASH / TARQATISH;
  - CHOP;
  - NOMA'LUM.
- **Holatga qarab vaznlar.** Hakam sifati holatga qarab o'zgaradi:
  - trend holatlarida asosiy tomon +4, qarshi tomon −6;
  - burilish holatlarida burilish tomoni +6, eski tomon −6;
  - charchashda eski tomon −6;
  - kengayishda qarshi tomon −8;
  - CHOP −4, NOMA'LUM −3.
- **Ssenariylar.** Bull, bear va chop foizlari. Har biri uchun maqsad (eng muhim likvidlik) va bekor bo'lish darajasi (himoyalangan daraja) ko'rsatiladi.
- **Hikoya.** Bitta qator: nima bo'ldi → qayerdamiz → nima kutilmoqda. Masalan: `yuqori likvidlik olindi (MAJOR) → M15 ▼×2 buzilish → LOCK ▼ → PULLBACK ▼ → pullback tugashi (M1 burilishi) kutilmoqda`.
- **Panel:** Holat, Ssenariy va Hikoya qatorlari. "Miya" qatorida `g'ayritabiiy bozor` sababi.
- **Tuzatish:** takroriy nomlar tekshiruvi eski kodda ham bor bo'lgan `G_MS_*` va `MS_PULLBACK` nomlarini topdi. Yangi nomlar `G_MST_*` va `MST_*` ga o'zgartirildi.
- **Tezlik:** hammasi har M1 barda bir marta hisoblanadi. Har tickda faqat bitta narx solishtirish (sakrashni aniqlash uchun).

## Katta reja — 7-bosqich: diagnostika — savdo xotirasi, autopsiya, balans

Yangi modul: `Sirus/26b_Autopsy.mqh`.

- **Kirishdagi suratga olish.** Har birinchi kirishda barcha qatlamlarning o'sha paytdagi holati eslab qolinadi:
  - kirish turi;
  - oyoqning o'tilgan foizi;
  - charchash;
  - olingan likvidlik;
  - LOCK;
  - burilish bosqichi;
  - bias;
  - nazorat;
  - oldindagi joy va kerakli harakat;
  - spread va odatiy spread;
  - yangilik.
- **Savdo xotirasi.** Har savat uchun yoziladi:
  - eng yaxshi nuqta (MFE);
  - eng yomon nuqta (MAE);
  - TP ning 35% iga yetish vaqti.
- **Autopsiya.** Foydada tugamagan yoki yo'lda TP hajmida minusga kirgan savat ochib ko'riladi. Xato turi eng muhimidan boshlab belgilanadi:
  1. QARSHI LOCK
  2. KECH KIRISH
  3. OLINGAN LIKVIDLIK
  4. CHARCHASH E'TIBORSIZ
  5. QARSHI ZONA
  6. TRENDGA QARSHI
  7. NAZORAT QARSHI
  8. SPREAD/YANGILIK
  9. SOXTA SWEEP
  10. VAQT (to'g'ri edi)
  11. NOTO'G'RI YO'NALISH
  12. ANIQLANMADI
- **Natijalar qayerga yoziladi:**
  - jurnal: `[SIRUS AUTOPSY]`;
  - har savat uchun bitta CSV qator: `Sirus_Autopsy_<symbol>_<magic>.csv`;
  - kun yakunida bitta qator: `[SIRUS AUTOPSY DAY]`.
- **Balans (panel).** `Balans: noto'g'ri ochilgan 3/12 (25%) · o'tkazilgan yaxshi 18/29 · eng ko'p xato: KECH KIRISH ×2`. Noto'g'ri ochilganlarni kamaytirib, yaxshilarini o'tkazib yubormaslik uchun ikkalasi yonma-yon ko'rinadi.

## Katta reja — 6-bosqich: cashback iqtisodi

Yangi modul: `Sirus/20e_Cost_Edge.mqh`.

- **Spread xotirasi (`EnableSpreadMemory`).**
  - Har server soati uchun odatiy spread o'rganiladi: har M1 barda bitta namuna olinadi.
  - O'rganilgan qiymatlar terminal global o'zgaruvchilarida saqlanadi, restartdan keyin yo'qolmaydi.
  - Hozirgi spread shu soat uchun odatiydan 2 barobar katta bo'lsa, kirish bo'lmaydi. Cashback ikki barobar spreadni qoplamaydi.
  - Juda katta sakrashlar (odatiydan 3 barobar ortiq) o'rganishga kirmaydi, aks holda xotira sakrashni "odatiy" deb o'rganib qoladi.
- **Broker xotirasi.** Har to'ldirilgan orderdagi slippage ham soat bo'yicha o'rtacha qilib saqlanadi va xarajatga qo'shiladi.
- **Sof foyda (`EnableNetEdge`, faqat cashback rejimi).**
  - Kirishdan oldin oldindagi eng yaqin to'siqqacha joy o'lchanadi. To'siq — ushlab turgan zona yoki likvidlik darajasi.
  - Bu joy kerakli harakatga solishtiriladi: kerakli harakat = spread + slippage + TP.
  - Joy kerakli harakatning 1.2 barobaridan kam bo'lsa, kirish bo'lmaydi: savdo o'zini oqlay olmaydi.
- **Qayerda ishlaydi:** V10 veto, barcha miya nomzodlari va "Miya" qatorida sabab (`spread 520 (odatiy 240)`, `joy 310 < kerak 650`).
- **Panel:** `Xarajat: spread 240 (bu soat odatiy 230) · slippage ~12 · kerakli harakat 476`. Spread g'ayritabiiy bo'lsa qator sariq bo'ladi.
- **Ixtiyoriy sozlama `RebateUSDPerLot`:** brokerning 1 lot uchun cashback summasini kiritsangiz, panelda ko'rsatiladi.
- **Tuzatish:** butun kod bo'yicha takroriy nomlar tekshiruvi `G_CE_BAR` nomini eski kodda ham borligini topdi, yangi nomlar `G_CX_` ga o'zgartirildi.

## Katta reja — 5-bosqich: savat ichida — kutilgan va haqiqiy harakat, grid javobgarligi

Kompilyatsiya xatosi ham tuzatildi: `EnableLiquidityMap` va `LiquidityPrintOnUse` nomlari eski sozlamalarda ham bor edi. Yangilari endi `EnableMBLiquidityMap` va `MBLiquidityPrintOnUse`. Shu bilan birga butun kod bo'yicha takroriy nomlar tekshiruvi qo'shildi.

- **Kutilgan va haqiqiy harakat (`EnableExpectationCheck`).** Savat ochilgan harakatini ko'rsatishi kerak: 20 daqiqa ichida eng yaxshi nuqtasi TP ning 35% iga yetishi kerak.
  - Faqat sekinlik yetarli emas, chunki grid tabiatan sekin tiklanadi. Bozor ham savatga qarshi o'girilgan bo'lishi kerak:
    - savat tomonining nazorati 35% yoki kamroq;
    - yoki savat tomoni charchagan;
    - yoki mikro burilish savatga qarshi (CHARCHASH yoki REVERSAL).
  - Ikkala shart bajarilsa, savat to'liq TP ni kutmasdan **BE + qoplamada** yopiladi. Zararga hech qachon yopilmaydi.
- **Grid javobgarligi (`EnableGridLiability`).** Har yangi pog'onadan oldin tekshiriladi: pog'onadan keyin BE (o'rtacha narx) qayerga tushadi?
  - BE HTF MAJOR+ toza likvidlik (H4 yoki kechagi kun darajasi) ortida qolsa, qarshi harakat charchamaguncha pog'ona qo'yilmaydi. Narx u darajani buzmasdan BE ga yetolmaydi, pog'ona faqat chuqurni chuqurlashtiradi.
  - BE H1 MAJOR darajasi ortida qolsa, pog'ona zaxira pog'ona kabi qo'yiladi: tuzilma + javob + charchash kerak.
- **Panel (SAVAT bo'limi):** `Kutilgan: 14 daq · eng yaxshi +120 / TP 224 · ko'rsatdi` yoki `Kutilgan: BAJARILMADI - BE'da chiqamiz (...)`.
- **Tezlik:** eng yaxshi nuqta har tickda bitta taqqoslash bilan yangilanadi. Kutilgan harakat har M1 barda, grid javobgarligi faqat pog'ona vaqtida tekshiriladi.

## Katta reja — 4-bosqich: mikro nazorat va qayta kirish aqli

Yangi modul: `Sirus/20d_Micro_Reentry.mqh`.

- **"Kim boshqaryapti" (BUY% / SELL%).** Indikator emas, narx xulqi asosida hisoblanadi:
  - shu tomon uchun likvidlik olingani (xarita sweep'i);
  - qarshi tomonning charchashi;
  - displacement;
  - M1/M5 tuzilmasi;
  - M1/M5 bosimi va tick oqimi;
  - higher low / lower high.
  - So'nggi 3 ta M5 barda nazorat 15+ foiz o'zgarsa, panelda ↑/↓ chiqadi. Bu erta ogohlantirish.
- **Burilish turi.** Mikro nazorat asosiy yo'nalishga qarshi bo'lganda aniqlanadi. Asosiy yo'nalish: lock, bo'lmasa bias, bo'lmasa M15.
  - SHOVQIN: 6 soatlik diapazonning 20% idan kam qaytgan;
  - PULLBACK: 20–45%;
  - CHARCHASH: asosiy tomonning charchash bosimi yuqori, yoki 45%+ qaytish va qarshi displacement;
  - REVERSAL: yetilgan burilish, yoki 60%+ qaytish va M5 tuzilmasi burilgan.
  - **Hakamga ta'siri:** asosiy tomonga kirish PULLBACK'da +6, CHARCHASH'da −8, REVERSAL'da −15. Qarshi tomonga kirish SHOVQIN'da −10, PULLBACK'da −5, REVERSAL'da +8.
  - O'z nazorati 30% dan past bo'lsa −10, 65% dan yuqori bo'lsa +5.
- **Qayta kirish aqli (`EnableSmartReentry`).**
  - **Chiqish turi eslab qolinadi:** FOYDA / BE / G'OYA O'LDI / ZARAR / LOKAL. Broker TP yoki SL bilan yopilsa, natijaga qarab aniqlanadi.
  - **G'oya o'lgan yoki zarar bilan yopilgan bo'lsa,** shu tomon yangi dalilni kutadi: shu tomonga yangi M5+ buzilish, yangi g'oya yoki yetilgan burilish. Ko'pi bilan 60 daqiqa.
  - **Urinishlar:** bitta g'oya bo'yicha 3 ta muvaffaqiyatsiz savatdan keyin shu tomon yangi g'oyagacha yopiq (ko'pi bilan 2 soat). BUY-loss-BUY-loss aylanishi to'xtaydi.
  - **Yutgandan keyin tez qayta kirish (FAST RE-ENTRY)** uchun endi yana uch shart bor: chiqishdan keyin yangi bar yopilgan bo'lishi, chiqish narxidan 1 ATR(M5) dan uzoqlashmagan bo'lishi va nazorat qarshi tomonga o'tmagan bo'lishi.
- **Ikkinchi imkoniyat (`EnableSecondChance`).** Faqat joyi yomonligi uchun o'tkazilgan setup (kech, quvish, oldida zona, sifat past) 30 daqiqa eslab qolinadi. Narx 0.5 ATR(M5) yaxshiroq joyga qaytsa va trigger bo'lsa, robot kiradi: **BRAIN SECOND-CHANCE**.
- **Qayerda ishlaydi:** V9 veto, barcha miya nomzodlari, "Miya" qatorida sabab.
- **Panel:** `Nazorat: BUY 62% / SELL 38% ↑ · burilish: PULLBACK (31%) · oxirgi savat SELL: foyda`.
- **Tezlik:** nazorat va burilish har M1 barda bir marta hisoblanadi.

## Katta reja — 3-bosqich: likvidlik xaritasi

Yangi modul: `Sirus/20a_Liquidity_Map.mqh`.

- **Bitta xarita.**
  - Nimalar kiradi: M5, M15, H1 va H4 swing high/low'lari, kechagi kun high/low'i (PDH/PDL).
  - Bir-biriga yaqin darajalar (0.2 ATR(M15) ichida) bitta darajaga birlashadi va qaysi TF'lar yaratganini eslab qoladi. Masalan, "H1+H4+PD" — bu bitta H1 swing emas, katta likvidlik.
  - Bir TF'ning ikki swing'i bir joyda bo'lsa, bu **teng high/low** hisoblanadi.
- **Holat:**
  - toza;
  - tegilgan;
  - sweep — o'tib, qaytib yopildi;
  - qayta sweep;
  - olingan — ortida 2 ta M5 yopilish (acceptance).
  - Sweep'dan keyin bir soat ichida olingan bo'lsa — **TUZOQ**: sweep muvaffaqiyatsiz, harakat davom etadi.
- **Kuch (multi-TF sweep):**
  - LOCAL — faqat M5;
  - KUCHLI LOKAL — M15;
  - MAJOR — H1;
  - HTF MAJOR — H4 yoki PD;
  - EXTREME — H1 + H4/PD + M15/M5.
  - Teng darajalar kuchni bir pog'ona oshiradi.
  - Bir tomonda 30 daqiqa va yarim ATR(M15) ichida bo'lgan sweep'lar bitta hodisaga birlashadi.
- **Soya (wick) sifati:** soya barning yarmidan ko'p va yopilish uzoq yarmida bo'lsa — kuchli. Keyingi bar uzoqlashib yopilsa — tasdiqlangan.
- **Eng muhim daraja (Champion):** har tomonda bitta. Hisoblash: kuch × yosh (12 soat / 48 soat) ÷ masofa.
- **Daraja charchashi:** 4+ marta test qilingan zona endi devor emas, breakout xavfi. Kengash bunday zona oldida kirishni to'xtatmaydi.
- **Ulangan joylar:**
  - LOCK: MAJOR+ xarita sweep'i lock uchun sweep sifatida hisoblanadi.
  - Burilish 1-bosqichi: xarita sweep'i hisoblanadi.
  - Kech kirish maqsadi: oldindagi MAJOR+ toza daraja.
  - Charchash: qarshi tomondagi xarita sweep'i.
  - Olingan likvidlik himoyasi: xarita sweep'i, tuzoq bo'lmasa.
- **Panel:** `Likvidlik: ▲ 4184.20 (H1+H4, toza) · ▼ 4070.10 (H1+PD teng, toza) · sweep ▼ MAJOR 12 daq`.
- **Tezlik:** har M5 barda bir marta (4 ta CopyRates). Har tickda hech narsa qo'shilmadi.

## Katta reja — 2-bosqich: kirish joyi, charchash va kech kirish himoyasi

Yangi modul: `Sirus/20c_Location_Exhaustion.mqh`. Shu bosqich ikki holatni yopadi: katta tushishning tubida ochilgan 4081.173 SELL va pastdagi likvidlik olingandan keyin ochilgan 4142 SELL.

- **Oyoq va joy.**
  - Har yo'nalish oyog'ining boshlanish nuqtasi: 6 soatlik ekstremum.
  - Maqsad: oldindagi eng yaqin **katta** daraja (dealing range, H4 qutisi, rejim qutisi, M15+ swing, PDH/PDL/Osiyo likvidligi). Mayda zonalar bunga kirmaydi, ular uchun kengash bor.
  - **Kech kirish himoyasi (`EnableLateEntryGuard`):** oyoq maqsadgacha 85% yurgan va kamida 2.5 ATR(M15) bo'lsa, shu tomonga yangi kirish yo'q. Pullback bo'lsa, o'tilgan foiz o'zi kamayadi.
- **Charchash bosimi (0–100):** davom etayotgan yo'nalishga qarshi bosim. Tarkibi:
  - momentum so'nishi (20);
  - qarshi likvidlik olindi (20);
  - davom eta olmaslik: ekstremum eskirgan yoki yangi low'lar soya bilan yopilmoqda (20);
  - rad etish shami (15);
  - tuzilma qarshi tomonga burilmoqda (15);
  - oyoqning chuqur qismi (10).
  - **70+** bo'lsa, shu tomonga yangi kirish yo'q. Bu teskari savdo signali emas: teskari tomonga kirish uchun alohida dalil kerak.
  - **50+** bo'lsa, hakam sifatiga jarima.
  - So'nggi 3 ta M5 barda bosim 20+ ga oshsa, panelda ↑ belgisi chiqadi (erta ogohlantirish).
- **Olingan likvidlik himoyasi (`EnableTakenLiquidityGuard`):** oldindagi M5+ likvidlik so'nggi bir soat ichida olingan va qaytarilgan bo'lsa (sweep muvaffaqiyatsiz bo'lmagan), shu tomonga kirish yo'q. Maqsad allaqachon bajarilgan.
- **Trendga qarshi soliq (`CounterTrendTax = 10`):** kuchli biasga qarshi kirishda, burilish yetilmagan bo'lsa, hakam 10 ball ko'proq sifat talab qiladi.
- **Qayerda ishlaydi:** V8 veto, barcha miya nomzodlari (MBDirOk), "Miya" qatorida sabab.
- **Panel:** `Joy: SELL juda kech · charchash 74↑ | BUY yaxshi · charchash 12`.
- **Tezlik:** boshlanish nuqtasi, maqsad va bosim har M1 barda bir marta hisoblanadi. Har tickda faqat o'tilgan foiz qayta hisoblanadi.

## Katta reja — 1-bosqich: tuzilma xotirasi, yo'nalish LOCK va burilish yetilishi

Yangi modul: `Sirus/20b_Structure_Lock.mqh`. Shu bosqich ikki holatni yopadi: erta reversal deb ochilgan 4157.88 BUY va o'tkazib yuborilgan haqiqiy 4070 reversal.

- **Tuzilma xotirasi (M5 / M15 / H1).** Har buzilish (BOS/MSS) uchun saqlanadi:
  - **ketma-ketlik:** bir tomonga nechta buzilish ketma-ket bo'lgani;
  - **himoyalangan daraja:** bearish buzilish kelib chiqqan lower high, bullish buzilish kelib chiqqan higher low;
  - **sifat:**
    - ZAIF — mayda tana;
    - YOPILISH — daraja ortida yopildi;
    - KUCHLI — displacement tanasi;
    - TASDIQ — keyingi bar ushlab qoldi;
    - SOXTA — keyingi bar qaytib yopildi, ya'ni tuzoq.
  - Faqat soya bilan bo'lgan buzilish umuman hisoblanmaydi. Zaif buzilish ketma-ketlikka qo'shilmaydi.
- **Yo'nalish LOCK (`EnableStructureLock`).**
  - **Yoqilish sharti:** M15+ sweep (12 soat ichida) + displacement + ketma-ket 2 buzilish (M15 da, yoki M5 da, agar M15 ham o'sha tomonda bo'lsa).
  - **Qarshi tomonga kirishlar** burilish `LockUnlockStage` (4) bosqichga yetguncha yopiq: V7 veto, miya nomzodlari va panel.
  - **Lock tugaydi:** M15 himoyalangan darajadan o'tib yopilsa, burilish 6-bosqichga yetsa yoki 8 soat davomida lock tomoniga yangi buzilish bo'lmasa.
- **Burilish yetilishi (0–6 bosqich).** Lock'ka yoki M15 trendiga qarshi o'lchanadi:
  1. likvidlik olindi;
  2. displacement;
  3. M5+ MSS;
  4. MSS darajasi retesti ushlandi;
  5. higher low;
  6. yangi buzilish.
  - Displacement'dan keyin M5 sweep ekstremumidan o'tib yopilsa — TUZOQ, bosqich 0 ga qaytadi.
  - Bosqich har M1 barda voqealardan qayta hisoblanadi, shuning uchun restartdan keyin ham to'g'ri bo'ladi.
- **Yangi kirish turi: BRAIN REVERSAL (`EnableReversalEntry`).** Burilish 4+ bosqichga yetgan, harakat kech emas, kengash ruxsat bergan va trigger bor bo'lsa, robot yangi tomonga kiradi. Bu 4070 tipidagi kirish.
  - V0 ruxsati: 4+ bosqichdagi burilish global bias'ga qarshi kirish uchun dalil hisoblanadi.
  - Hakam: 4+ bosqichdagi retest joy sifatida va tasdiqlangan reversal sifatida hisoblanadi, sifat balliga +8.
- **Panel:**
  - `Tuzilma: M5 ▼×2 · M15 ▼ · H1 • (oxirgi M15: tasdiq)`;
  - `LOCK ▼ · himoya 4171.40 · burilish ▲ 3/6 (MSS 4092.10)`;
  - "Miya" qatorida `LOCK ▼, burilish 2/4`.
- **Tezlik:**
  - buzilishlar faqat o'z TF barida yoziladi;
  - lock har M5 barda bir marta tekshiriladi;
  - burilish har M1 barda bir marta hisoblanadi;
  - har tickda hech narsa qo'shilmadi.

## Katta reja — 0-bosqich: tezkor tuzatishlar va ko'rinish

- **Lokal qatlam ziddiyati:**
  - panelda bir vaqtda "lokal ▲" va "lokal oyoq ▼" turardi. Sababi: kechikkan M5 tuzilmasi lokal tezisdan oldin o'qilardi;
  - yangi tartib: M5 impulsi → M5 dagi sof harakat → **faol lokal tezis → M5 bosimi** → eng oxirida M5 tuzilmasi.
- **"Tezkor 0" restartdan keyin:**
  - miya kirishlari hisoblagichi har qayta kompilyatsiyada nolga tushardi, kunlik jami esa tarixdan o'qilardi;
  - endi hisoblagich kuni bilan terminal o'zgaruvchisida saqlanadi.
- **Paneldagi yangi qator "Miya BUY: … · SELL: …":**
  - savat yo'q paytda miya nega kirmayotganini har tomon uchun ko'rsatadi: kengash sababi, global qarshi, trigger yo'q yoki setup sharti yo'q;
  - jimlik sababini endi panelning o'zidan ko'rish mumkin.
- **Soya klapani:**
  - `ShadowValveMinSamples` 20 dan 10 ga tushirildi;
  - to'silgan setuplar turli filtrlarga bo'linib ketgani uchun 20 namunaga hech qachon yetmasdi ("to'silgan 18 → TP 100%" bo'lsa ham klapan ochilmasdi).
- **Performance shartnomasi:** tick o'rtacha vaqti 30 ms dan oshsa, panelning tezlik qatori sariq rangga o'tadi.

## Yashirin xato: qaytarib berilgan impuls "yosh" deb qolardi (BE dan keyingi jimlik)

- **Holat (6-oktabr, 19:18–19:36):**
  - savat BE da yopildi, keyin narx M5 da ~$8 pastga sirpandi va 18 daqiqa birorta ham kirish bo'lmadi;
  - panelda lokal ▲ edi, M1/M5 bosimi esa ▼.
- **Sabab:**
  - impuls oxirgi 60 bar ichidagi so'nggi displacement'dan olinardi;
  - tezlik soati har pullback'da qaytadan boshlanardi;
  - shuning uchun 19:00 dagi M5 ko'tarilishi to'liq qaytarib berilganda ham (pastga displacement bo'lmagan, mayda shamlar) u "YOSH impuls ▲" deb qolaverdi.
- **Natija:**
  - lokal qatlam ▲ ni ko'rsatdi;
  - lokal SELL "global oyoq yangi" deb yopildi;
  - BUY'ni esa shamlar to'g'ri yopdi;
  - hech qaysi tomon ochilmadi.
- **Tuzatish (`MBImpulseGiveBack = 0.62`):** impuls boshlanish nuqtasidan o'tib yopilsa yoki butun harakatining 62% ini qaytarib bersa, tugagan hisoblanadi. M1 va M5 impulsiga birdek tegishli. Lokal qatlam endi M5 dagi sof harakatni o'qiydi (bu holatda ▼). Lokal SELL va BRAIN ALIGNED o'z vaqtida ochiladi.

## Kirish kengashi: lokal + shamlar + zona birga hal qiladi

- **Holat (6-oktabr, 18:42):** BRAIN SWEEP SELL 4168.905 da ochildi. O'sha paytda:
  - lokal ▲, M5/M15 bosimi ▲/▲, H1/H4 ↗;
  - narx yashil support ustida turgan edi;
  - global zaif edi: "ayiqlar uyg'onmoqda", 37%.
  Kichik M1 sweep o'zini "burilish shami" deb oqlab, sham qoidasini chetlab o'tdi.
- **Kengash (`EnableEntryCouncil`, V6 veto va har bir miya kirishi):**
  1. **Uchlik qoida:** lokal, M5 va M15 uchalasi qarshi bo'lsa, kirish yo'q, sweep bo'lsa ham. Istisno: M15+ likvidlik reversali va undan keyin yopilgan M5 burilish shami.
  2. **Sweep o'zini oqlamaydi:**
     - burilish dalili faqat yopilgan M5 shami;
     - M1 pool sweepi faqat lokal o'sha tomonda bo'lsa olinadi;
     - tasdiqlangan sweep 10 daqiqadan eski emas (avval 30 daqiqa edi) va narx undan 1 ATR(M5) dan uzoqlashmagan bo'lishi kerak.
  3. **Qarshi zona:** SELL ostida ushlab turgan support yoki BUY ustida resistance 0.35 ATR(M5) ichida bo'lsa, robot kutadi. Zonani M5 yopilib buzsa, kiradi.
  4. **Zaif global lokalni bosmaydi:** global o'tish holatida yoki ishonchi 50% dan past bo'lsa, lokalga qarshi kirilmaydi. Istisno: M5 burilish shami, yoki lokal oyoq charchagan joyda M1 burilish shami.
- **Savdo soni kamaymasligi uchun:**
  - kengash bir tomonni yopsa, nomzodlar qolgan tomonda qidiriladi;
  - yangi **BRAIN ALIGNED** kirishi: lokal oyoq va M5 shamlari bir tomonda, M1 qarshi emas, harakat kech emas va trigger bor bo'lsa, o'sha tomonga kiradi. Masalan, SELL ochib bo'lmaydigan joyda BUY.
- **Tezlik:** kengash natijasi har tick va har yo'nalish uchun bir marta hisoblanadi.

## Cashback rejimida trailing o'chirildi

- **Muammo:** cashback rejimida alohida "rebate trailing" yoqilgan edi (TP ga yetganda yopmasdan, TP × 0.75 qulf bilan kuzatardi). Broker stopi sirpanish va spred bilan ishlagani uchun savatlar mayda zararda yopilib qolardi.
- **Endi:**
  - cashback rejimida savat eski qat'iy TP da yopiladi;
  - birinchi orderga broker TP yana qo'yiladi.
- **Trailing faqat oddiy rejimda ishlaydi:**
  - aqlli yuguruvchi;
  - Pack2 savat trailingi endi cashback rejimida hech qachon ishlamaydi.
- **Sozlamalar:**
  - `EnableRebateTrailing` o'rniga `EnableRebateTrailingMode = false`. Nomi o'zgargani uchun eski presetdagi `true` qiymati o'qilmaydi;
  - `RebateDisableTrailing` olib tashlandi, endi u har doim amalda.

## Shamga qarshi kirmaslik, uzoq DD ga qarshi choralar, SIRUS rejim nomlari

- **Topilgan teshik:** M5 va M15 shamlari kirishga qarshi bo'lsa ("charchagan harakat"), hakam faqat CAUTION berardi. CAUTION lot esa kichraymaydi (`MinFirstEntryLotFactor = 1.0`), shuning uchun bullish M5/M15 da SELL to'liq lot bilan ochilardi.
- **Hakam (`EnableCandleReadingGate`):**
  - M5 va M15 bosimi qarshi bo'lsa: M5 burilish shami (yoki tasdiqlangan reversal + reaksiya shami) chiqmaguncha kutadi;
  - qarshi harakat M1 va M5 da hali davom etsa: M1 burilish shamini kutadi.
- **V4 veto:** shakllanayotgan M5 shami qarshi tomonga kuchli yursa (tanasi ≥ 0.8 ATR(M5), yopilish chekkada), kirish yo'q. Avval faqat M1 sham ko'rilardi.
- **Grid (`GridHoldOnCandlesAgainst`):** M5 va M15 shamlari savatga qarshi bosayotgan va harakat charchamagan bo'lsa, grid qo'shilmaydi. Katta lotlar yugurayotgan harakatga qo'shilmaydi.
- **Uzoq DD (`EnableStaleBasketBE`):** savat 90 daqiqadan beri ochiq bo'lsa, DD kamida 8% bo'lgan bo'lsa va M5+M15 shamlari uning tomonida bo'lmasa, break-even + qoplamada yopiladi. Zararga yopmaydi.
- **SIRUS nomlari:**
  - sozlamalardagi rejim endi "SIRUS AUTO / SIRUS BALANCED / SIRUS HIGH HUNTER";
  - `NaviusMode` o'rniga `SirusMode`, `NaviusBuildName` o'rniga `SirusBuildName`;
  - koddagi barcha Navius nomlari SIRUS ga almashtirildi.
  - Terminal global o'zgaruvchilari kalitlari o'zgarmadi, yig'ilgan statistika saqlanadi.

## Aqlli TP (yuguruvchi) va SIRUS brendi

- **Topilgan ziddiyat:** TP 2500 × TPScale 0.85 ≈ 2125 pt, trailing esa 2300 da boshlanardi. Savat TP da yopilib ketar, trailing hech qachon ishlamasdi.
- **Aqlli yuguruvchi** (`EnableSmartRunner`, faqat oddiy rejimda): savat TP da yopilmaydi, trailing va uzoq maqsad bilan yuradi. Shartlar:
  - TREND yoki PORTLASH rejimi savat tomonida, yoki miya ustun tomonda va g'oya tirik (xavf ostida emas);
  - savatda ko'pi bilan 2 order;
  - savat lokal emas, g'oyasi o'lmagan va hech qachon chuqur DD bo'lmagan;
  - yangilik oynasi yo'q;
  - eng yaqin qarshi zonagacha kamida 1.5 × TP.
- **Raqamlar:**
  - trailing boshlanishi 2200 pt (TP undan kichik bo'lsa, TP × 0.88);
  - qulf 2000 pt (TP past bo'lsa, boshlanish nuqtasining 90% i);
  - kuzatish masofasi max(300 pt, 0.5 × ATR(M5));
  - uzoq maqsad: 2.5 × TP yoki likvidlik maqsadi (DOL), qaysi biri yaqin bo'lsa.
- **Yuguruvchidan chiqish:**
  - narx qulfga qaytsa;
  - uzoq maqsadga yetsa;
  - TP dan yuqorida teskari reaksiya shami chiqsa;
  - 10 daqiqa yangi cho'qqi bo'lmasa.
- **Himoya:** yuguruvchi yoqilganda brokerdagi TP olib tashlanadi, qulf esa brokerga real SL sifatida yoziladi. Eski Pack2 trailing yuguruvchi ishlayotganda chetga turadi.
- **Panel:** savat yuguruvchi rejimida bo'lsa, "YUGURUVCHI: qulf · cho'qqi · maqsad" qatori chiqadi.
- **Brend:**
  - order izohlari endi "Navius by Zakiy ..." emas, `SIRUS by Zakiy | TREND`, `| SWEEP`, `| GRID 3`, `| SCALE-IN` shaklida;
  - brend nomi `OrderBrand` sozlamasida;
  - terminal global o'zgaruvchilaridagi eski kalitlar o'zgartirilmadi, robot yig'gan statistika saqlanadi.

## Shamlarni o'qish: zonaga yetdi degani uchungina kirmaydi

Jonli kuzatuv: robot 4164.04 da SELL ochdi. Bu kuchli ko'tarilayotgan lokal oyoqning o'rtasi edi: uchala bosim ▲ edi, qarshilik zonasi esa $2 yuqorida (4166.26).

- **HANDOFF qattiqlashtirildi:**
  - Faqat haqiqiy joyda ishlaydi: lokal maqsad (±0.3 ATR) yoki qarshi zona (0.5 ATR(M5) ichida). "H1 premium" ($14 lik oraliq) endi joy hisoblanmaydi.
  - Lokal oyoq charchagan bo'lishi shart (`MBLocalLegSpent`): impuls kech, charchoq shami bor yoki M5 bosimi aylangan.
  - Reaksiya shami kerak (`MBReactionCandle`): M1/M5 da displacement, rejection, grab yoki fake breakout, yoki yangi LIVE SWEEP. Bitta mayda sham yetmaydi.
- **Hakamda "avval shamni o'qi" qoidasi** (barcha kirish turlari uchun):
  - qarshi tomonga lokal oyoq yuguryapti (lokal qatlam, M1 va M5 bosimi qarshi, oyoq charchamagan) → kutadi. Faqat kuchli qaytish shami bo'lsa kiradi;
  - oxirgi yopilgan shamlar hali qarshi itaryapti → kutadi;
  - kirishning yagona sababi zona, diapazon chekkasi yoki FVG bo'lsa → reaksiya shamini kutadi.
- **Panel:** SAVAT bo'limida ochiq savat qaysi kirish turi bilan ochilgani ko'rinadi: "Kirish: BRAIN HANDOFF SELL · sifat 72 · LOKAL savat".

## Diapazon hukmronligi, tez lokal qatlam, barqaror bosim, soya klapani

Jonli kuzatuv: narx $13 ko'tarildi, robot esa "global SELL" bo'yicha jim turdi. Soyada to'silgan setuplarning 94% i TP ga yetardi.

- **A. Rejim hukmronligi** (`MBRangeRules`): DIAPAZON va SIQILISH rejimida zaif yoki uyg'onayotgan global bias (|bias| ≤ 2) veto bo'lmaydi.
  - ikkala chekkada ham savdo qilinadi;
  - hakam diapazon savdosidan joy va trigger talab qiladi;
  - ball solig'i filtrlari chetga turadi;
  - miya yengilligi beriladi.
- **B. Lokal qatlam tezlashdi.** Lokal yo'nalish shu tartibda aniqlanadi:
  1. jonli M5 impulsi (hali kech emas);
  2. oxirgi 6 ta M5 yopilishning sof harakati (≥ 1 ATR);
  3. M5 struktura;
  4. bosim.
- **C. Bosim barqaror bo'ldi:** 3 shamlik bosim noaniq bo'lsa, oxirgi 5 shamning sof harakati (≥ 1 ATR) qaror qiladi.
- **D. Lokal g'oya va kirish kelishdi:** lokal g'oya faol bo'lsa, o'sha tomonda lokal oyoq bor deb hisoblanadi.
- **E. Soya klapani** (`EnableShadowValve`, 30 daqiqa, 20 namuna):
  - sifat filtri (ball, joy / zona / HTF, hakam) to'sgan setuplar olinganlardan 15% ko'proq va kamida 70% TP ga yetsa, o'sha filtr 30 daqiqa yumshaydi. Keyin qayta yumshashi uchun yangi dalil kerak.
  - Yumshash qanday ishlaydi: ball filtrida hakamning EHTIYOT bahosi yetarli bo'ladi; joy oilasi filtrlari chetga turadi; hakam chegaralari 10 ballga pasayadi.
  - Risk, yangilik, spread, marja va yo'nalish veto'si hech qachon yumshamaydi.
  - Panelda "⚙ yumshatildi: ..." deb ko'rsatiladi.

## Lokal savdo mukammallashtirildi (uch qatlam, qo'l almashuvi, lokal g'oya)

1. **Uch qatlam:** global (M15+), lokal (M5) va mikro (M1). Panelda "Qatlamlar: global · lokal · mikro" qatori chiqadi.
2. **Lokal g'oya:** globalga qarshi lokal oyoqning o'z maqsadi va chegarasi bor.
   - maqsad: global oyoqning 50% i yoki undan yaqin bo'lsa, qarshi zona;
   - chegara: oyoq boshlangan nuqta.
   - Chartda chiziq bilan ko'rsatiladi (`ShowLocalOnChart`).
3. **Lokal → global qo'l almashuvi (BRAIN HANDOFF):** lokal oyoq global tomonning joyiga yetib (lokal maqsad, H1 premium/discount yoki qarshi zona) mikro qatlam qaytsa, global tomonga kiriladi. Bu ko'tarilish cho'qqisida SELL, tushish tubida BUY degani. Ochiq lokal savat esa shu lahzada BE yoki foydada yopiladi.
4. **Qatlamli pullback (BRAIN PULLBACK):** global va lokal bir tomonda bo'lsa, mikro qaytishdan keyin davom etilganda kiriladi.
5. **Lokal savat qoidalari:**
   - ko'pi bilan 3 order (`LocalGridMaxRungs`);
   - 20 daqiqadan keyin BE yoki foydada yopiladi (`LocalBasketMaxMinutes`);
   - global tomon qayta displacement qilsa, qo'l almashuv bo'lsa yoki lokal g'oya tugasa, BE/foydada yopiladi.
6. **Global oyoq holati va lokal to'lqinlar:** lokal savdo uch holatda yo'q:
   - global M5 impulsi yosh bo'lsa;
   - global portlash (expansion) bo'lsa;
   - lokal oyoq 3-to'lqinida bo'lsa.
7. **O'rganish va himoya:**
   - oxirgi 30 ta lokal natija yoziladi; yutuq 40% dan past bo'lsa, faqat "kuchli" lokal qabul qilinadi;
   - ketma-ket 2 ta lokal zarar bo'lsa, lokal savdo 30 daqiqaga to'xtaydi. Global savdo davom etadi. Pauza vaqt bilan cheklangan, muzlatib qo'ymaydi.
8. **Sessiya:** London yoki NY ochilishida, TREND rejimida trendga qarshi lokal uchun "kuchli" daraja talab qilinadi.
9. **Vizual:** panelda lokal oyoq maqsadi, chegarasi, holati va lokal natija. Chartda maqsad va chegara chiziqlari.

## Muzlashga qarshi: 11 ta yashirin qulf tuzatildi

Robotni harakatlanayotgan bozorda 10–60 daqiqa jim qoldiradigan qulflar:

1. **Signal eskirishi:** anchor endi 15 daqiqa emas, 3 daqiqa yashaydi. Har jonli trigger (displacement, LIVE SWEEP, pullback qaytishi) yangi signal hisoblanadi. Trend + joy + trigger bo'lsa, eskirish jazosi yo'q.
2. **V1 veto davom etuvchi trendda ochilmasdi:** endi M15+ BOS yoki displacement bizning tomonga bo'lsa, yoki M5 sweep ekstremumidan narida yopilsa, veto yechiladi.
3. **Uyg'onish bosqichi:**
   - reversal tasdig'i faqat hali dolzarb hodisalardan olinadi;
   - a = 1 holatida kuchli sham (M1/M5 displacement, rejection, grab) "reversal isboti" o'rnida qabul qilinadi.
4. **M1 impulsi EXPIRED da qotib qolardi:**
   - M1 da 0.3 ATR(M5) qaytish ham soatni qaytadan boshlaydi;
   - yosh M5 impulsi bo'lsa, M1 quvish jazosi bir pog'ona yumshaydi.
5. **To'xtagan narx xotirasi abadiy edi:** endi 1 soatda yoki narx 3 ATR(M5) uzoqlashganda tozalanadi. Faqat sezilarli zarar yoziladi.
6. **Tezlik guardi o'zini uzaytirardi:** endi blok bir marta qo'yiladi va o'z vaqtida tugaydi.
7. **Flip zona (V2):** uchta M5 yopilish darajadan narida bo'lsa, retestsiz ham yangi rol qabul qilinadi.
8. **Vaqt filtri o'zini abadiy qulflardi:** soat va hafta kuni statistikasi har kuni 10% ga eskiradi.
9. **Tezis qarama-qarshiligi kunlab to'planardi:** endi faqat dolzarb hodisalar sanaladi.
10. **Bir tomonlama qulflar:** dalil kuchaytirish har soat bir qadam kamayadi. "O'z-o'zini himoya" rejimi 4 soatdan keyin o'chadi.
11. **Kunlik kirish limiti:** 200 → 600.

Qo'shimcha tuzatilgan mayda xatolar:
- vaqtinchalik blok tozalanganda ochiq savat statistikasi nolga tushirilmaydi;
- zarar bilan yopilgan BUY ham post-SL hisobiga yoziladi.

## Lokal savdo: global yo'nalishga qarshi lokal oyoqlar

- **Muammo:** robot faqat global yo'nalishda (M15 va undan yuqori) savdo qilardi. Global SELL bo'lsa, BUY ni bir necha joy birdaniga to'sardi: V0, hakam (tasdiqlangan reversal talabi), rejim qoidasi va miya kirishlari. Shuning uchun lokal ko'tarilishlar o'tkazib yuborilardi.
- **Lokal daraja** (`EnableLocalTrading`, `MBLocalLevel`):
  - **1:** M5 strukturasi shu tomonda va bosim bor, yoki M1 strukturasi shu tomonda va M1 bilan M5 bosimi ham shu tomonda.
  - **2 (kuchli):** M5 va M1 strukturasi ham, ikkala bosim ham shu tomonda, ustiga so'nggi 30 daqiqada M1/M5 likvidlik reversali bor.
- **Qayerga ta'sir qiladi:**
  - **V0:** zaif yoki uyg'onayotgan qarshi biasda lokal 1 yetarli. Eng kuchli qarshi biasda lokal 2 kerak.
  - **Hakam:** lokal setupda reversal isboti o'rnida lokal struktura ishlatiladi. Baribir trigger kerak, joy ham kerak (lokal 2 bo'lsa joy shart emas). Sifatga +10 / +15.
  - **Miya kirishlari:** yangi **BRAIN LOCAL** turi qo'shildi. Sweep, diapazon va momentum kirishlari ham lokal ruxsat bilan qarshi tomonga ochila oladi.
  - **Miya yengilligi:** lokal setupga +2.
  - **Eski filtrlar:** ball solig'i filtrlari (HTF qarshi, eski daraja va boshqalar) lokal setupda chetga turadi. Eski joy himoyasi qoladi.
- **Grid himoyasi:** globalga qarshi ochilgan savat faqat zaxira pog'onalar qoidasi bilan o'rtachalanadi: tuzilma, charchagan qarshi harakat va sham javobi. Vaqt o'tishi bilan pog'ona qo'shilmaydi.
- **Panel:** "Lokal oqim: ▲ bor / kuchli (global: ▼)" qatori chiqadi.

## Yashirin xato: yo'nalish qulfi

- **Xato:**
  - G'oyaning bekor qilish chegarasi eng yaqin kichik M15 swing'ga qo'yilardi.
  - Shu sabab oddiy pullbackdagi bitta M5 yopilish g'oyani "o'ldirardi".
  - Keyin o'sha yo'nalish **2 soat** qulflanardi va faqat eng kuchli bias (±3) bilan ochilardi.
  - Bozor shu yo'nalishda davom etsa ham, har bir kirish "V0 invalidation memory" bilan to'silardi. O'sha tomonda yangi g'oya ham ochilmasdi, shuning uchun miya kirishlari va yengillik ham ishlamasdi.
- **Tuzatildi:**
  - bekor qilish chegarasi narxdan kamida 0.8 ATR(M15) uzoqda bo'ladi;
  - g'oya o'lishi uchun M5 yopilish chegaradan 0.15 ATR(M5) narida bo'lishi kerak;
  - qulf ko'pi bilan 1 soat;
  - bozor yo'nalishni qayta tasdiqlasa, qulf **darhol ochiladi**: bias kamida "ustun" bo'lsa va o'limdan keyin M5+ BOS / MSS / displacement / acceptance yoki LIVE SWEEP bo'lsa.
  - panelda qulf "Qulf: SELL N daq" deb ko'rinadi.

## Tezlik va trend savdosi: skaner jilovi, "uyg'onish + harakat = trend", pullback, hakam

- **D. Tezlik** (`EnableScannerThrottle`):
  - Profiler ko'rsatdi: eski skaner ~49 ms (tik ~55 ms, eng sekini 1.2 s).
  - Endi skaner faqat shu holatlarda ishlaydi: yangi M1 bar, narx 0.1 ATR(M1) siljiganda, savat o'zgarganda yoki 3 soniyada bir marta.
  - Oradagi tiklarda skaner natijasi snapshot'dan tiklanadi. Kirish filtrlari tik ichida o'zgartirgan qiymatlar keyingi tiklarga o'tib to'planmaydi.
  - Panelda "skaner N% tikda" ko'rinadi.
- **A. Uyg'onish + harakat = trend:** miya "uyg'onmoqda" holatida bo'lsa ham, uchta shart bajarilsa trend (±2) deb hisoblanadi:
  - M5 strukturasi shu tomonda;
  - M1/M5/M15 bosimidan kamida 2 tasi shu tomonda;
  - teskari reversal yo'q.
  - Natijada $5 lik tushishda SELL endi taqiqlanmaydi.
- **B. Trend pullbackdan davom etishi:** oxirgi M1 sham trendga qarshi yopilgan bo'lsa (pullback) va narx uning chekkasini trend tomonga buzsa:
  - TREND miya kirishi ochiladi (impuls kech bo'lsa ham);
  - hakamdagi "quvish" jazosi bir pog'ona yumshaydi.
- **C. Hakam ball o'rnida** (`EnableJudgeScoreBypass`, `MBJudgeBypassQuality=65`): eski ball yetmasa ham, hakam shu setupga 65+ sifat bersa, kirish ochiladi.

## Miya kirishlari: jimlikka qarshi oddiy mantiq

- **Muammo:** kirish faqat eski detektorlar balli o'tganda boshlanardi (to'xtashlarning 86% i "ball yetmadi"). Miyaning tezkor kirishi esa juda tor edi: tasdiqlangan g'oya, kuchli bias, qarama-qarshilik yo'q. Natijada bozor harakatlansa ham robot jim turardi.
- **Yechim** (`EnableBrainEntries`): miya o'zi 4 xil oddiy kirishni topadi. Har biri V0 tushunadigan kirish turi bilan beriladi.
  1. **TREND** (`TREND_RIDE` / `PULLBACK_CONTINUATION`): miya kuchli tomonda, g'oya ochiq, impuls kech emas, trigger bor.
  2. **LIKVIDLIK OVI** (`SWEEP_REJECTION`): yangi LIVE SWEEP yoki so'nggi 30 daqiqadagi M5/M15/KEY sweep + tasdiq. Qaytish tomonga kiriladi, miya qarshi bo'lmasa.
  3. **DIAPAZON CHEKKASI** (`RANGE_EDGE`): M15 diapazonining 20% chekkasida qaytish shami.
  4. **MOMENTUM** (`MOMENTUM_SCALP`): jonli yoki hozirgina yopilgan displacement, M5 bosimi shu tomonda, impuls erta, miya qarshi emas.
- Keyin baribir tekshiriladi: V0–V5 veto, hakam (joy + trigger + tezlik + rejim + oqim), risk / yangilik / spread / marja / pauza.
- **V0:** transition holatida o'sha tomonga displacement bilan kelgan momentum ham qabul qilinadi.
- **Hakam:** yechilgan likvidlik darajasi va jonli impulsning boshlanishi joy hisoblanadi.
- **Eski joy filtrlari:** miya neytral bo'lsa ham, o'z joyini olib kelgan kirishni (sweep, diapazon chekkasi, momentum) to'xtatmaydi.
- **O'chirildi:** `EnableSmartEarlyExit` va `CloseBasketOnDailyLoss`. Savatni endi faqat aqlli chiqish yoki 50% SL yopadi.

## Chuqur audit (savdodan oldin)

To'rt yo'nalishda audit o'tkazildi: kompilyatsiya, mantiq, tezlik va pul xavfsizligi. Kompilyator xatosi topilmadi. Tuzatilganlar:

- **Mantiq:**
  - Likvidlik burilishining tasdig'i endi sweep bari yopilgandan keyin kelishi shart. M5 va undan katta sweep uchun tasdiq ham M5+ bo'lishi kerak. Avval deyarli har HTF sweep "tasdiqlangan" bo'lib, V1 veto va savat o'limi juda ko'p ishlardi.
  - V1 endi BUY va SELL ni bir vaqtda to'smaydi.
  - Ikkala tomonda ham HTF reversal bo'lsa, yangisi olinadi.
  - Hodisa vaqti endi bar yopilishi bo'yicha solishtiriladi.
  - Tezkor kirish HARD_BLOCK va bozor xaosi ustidan o'tmaydi.
  - Tezkor kirish joy va HTF filtrlarini faqat miya tomonda bo'lsa chetlab o'tadi.
  - Transition (a = 1) holatida tezkor kirish va miya yengilligi faqat reversal turiga beriladi.
  - Trend kirishida ham sifat juda past bo'lsa, WAIT qaytariladi.
  - Shamlar bid narxi bilan solishtiriladi.
  - Grid javob kutishi narx qaytib kelganda qaytadan boshlanadi.
  - Bir tikda yopilib, yangisi ochilgan savat ham hisobotga yoziladi.
  - LIVE SWEEP daqiqa almashganda ham ko'rinadi.
  - Kunlik hisobot soya natijalari nolga tushmasidan oldin yoziladi.
- **Pul xavfsizligi:**
  - "IMKONSIZ" holati har doim o'lgan g'oya yoki tasdiqlangan reversal talab qiladi. Chuqurlik belgilari (grid tugagan, BE uzoq) bitta belgi hisoblanadi.
  - Yangilik faqat chiqqandan keyin va kutilmagan natija bo'lsa hisobga olinadi.
  - Chiqish qurollangan bo'lsa, grid qo'shilmaydi.
  - BE chiqishi pulda ham ≥ 0 bo'lishi kerak.
  - `deep_back` faqat SHUBHALI deb topilgan savatga ishlaydi.
  - Chiqishlar faqat baholangan savatga tegadi.
  - Savat holati qayta ishga tushganda tiklanadi.
  - Miya o'chirilsa, holat tozalanadi.
- **Tezlik:**
  - hodisa natijalari keshlanadi;
  - savat o'limi M1 barda bir marta tekshiriladi;
  - zona keshiga salbiy natijalar ham yoziladi;
  - soya CSV buferlanadi;
  - panelning doimiy xossalari faqat yaratilganda o'rnatiladi;
  - profiler OnInit'ni hisobga olmaydi;
  - veto qarorlari tik bo'yicha emas, qaror bo'yicha sanaladi.

## 18-bosqich: dalillar tablosi va kunlik hisobot

- **B5. Dalillar tablosi:** panelda "Dalillar" qatori chiqadi: eng katta likvidlik hodisasi (H1/H4/KEY) va eng yangi M15+ struktura (MSS/BOS).
- **B6. Kunlik hisobot** (`EnableDailyReport`): har kun yakunida `Sirus_DailyReport_<symbol>_<magic>.csv` fayliga va jurnalga `[SIRUS DAY REPORT]` qatori yoziladi. Unda: kirishlar soni, lot, natija, yutgan/yutqazgan yopilishlar, soya statistikasi (to'silgan va olingan setuplar, ularning TP %), LIVE SWEEP soni, veto soni va o'rtacha tik vaqti.
- **Keyinga qoldirildi:**
  - C3 limit orderlar;
  - eski filtrlarni tozalash (soya buxgalteriyasi va backtest raqamlari kelgach).

## 17-bosqich: nozik aniqlik

- **B1. Tick hajmi:** o'rtacha hajmdan ×0.7 dan past bo'lgan displacement, breakout yoki continuation shami trigger hisoblanmaydi. ×1.5 dan baland hajmda sifat +3.
- **B2. Sessiya:** Osiyo, London, Nyu-York. London yoki NY ochilishining birinchi 2 soatida Osiyo / PDH / PDL darajasining LIVE SWEEP'i +6 sifat oladi.
- **B3. Yumaloq narxlar:** XX00 va XX50 darajalari LIVE SWEEP hovuzi sifatida ishlatiladi. Faqat oxirgi bir soatda tegilmagan bo'lsa.
- **D2. Tik oqimi:** oxirgi 30 soniyada tiklarning ≥40% kirishga qarshi bo'lsa (kamida 20 tik), kirish kutiladi. ≥30% tomonda bo'lsa, sifat +3.
- **D3. Sweep statistikasi:** har LIVE SWEEP natijasi (hovuz turi × sessiya) terminal global o'zgaruvchilarida saqlanadi. 30 namunadan keyin ishlatiladi: yutuq ≥60% bo'lsa sifat +4, <40% bo'lsa −6.
- **D5. Uch qatlamli diapazon:** H1, M15 va H4 diapazonlarining uchalasida ham arzon bo'lsa, sifat +5. Uchalasida ham qimmat bo'lsa, faqat EHTIYOT lot.
- **D7. Volatillik foizi:** joriy M5 ATR oxirgi 5 kunga nisbatan baholanadi. <10-foiz (o'lik bozor) bo'lsa sifat −4. ≥92-foiz (vahshiy bozor) bo'lsa, faqat EHTIYOT lot.
- **Panel:** "Sessiya · Volatillik · Oqim" qatori qo'shildi.
- **B4:** TP va grid o'zgartirilmadi. Sessiya farqini D7 volatillik foizi qoplaydi.

## 16-bosqich: aqlli grid va aqlli chiqish (25% → 50%)

- **A7. G'oya xavf ostida:** g'oyaga qarshi kuchli M5 displacement bo'lsa yoki M1 va M5 shamlari bilan M5 bosimi qarshi bo'lsa, `THREATENED` holati yoqiladi. Grid to'xtaydi. G'oyani tasdiqlovchi sham kelganda holat yechiladi.
- **E1. Qutqarish bahosi** (`EnableRecoveryJudge`, `RecoveryStartDD=25`):
  - 25% DD dan boshlab har M1 barda 9 belgi tekshiriladi: g'oya, miya, M15+ reversal, qarshi harakat holati, yaqin zona yoki FVG, grid zaxirasi va marja, BE masofasi, H1 va H4, yangilik.
  - **IMKON BOR:** savat 50% gacha ushlanadi.
  - **SHUBHALI:** grid qo'shilmaydi, savat BE'da yopiladi.
  - **IMKONSIZ:** kerakli qarshi belgilar soni 25–35% DD da 4 ta (g'oya o'limi yoki reversal shart), 35–45% da 3 ta, 45% dan yuqorida 2 ta. Holat 3 bar saqlansa, chiqish qurollanadi.
- **E6. Chiqish lahzasi:** savat birinchi 0.3 ATR(M1) qaytishda yopiladi. DD yana +3% oshsa, darhol yopiladi. G'oya qaytsa, chiqish bekor qilinadi.
- **E2/E3. Grid tuzilmada:** sham javobi zona yoki FVG yonida bo'lishi kerak. Havoda bo'lsa, javob kutish vaqti ichida kutadi.
- **E5. Zaxira pog'onalar:** oxirgi 2 pog'ona faqat tuzilma, charchagan qarshi harakat va sham javobi uchalasi bo'lganda ochiladi. Vaqt o'tishi bilan ochilmaydi.
- **E7. Chiqish maqsadi:** chuqur DD dan qaytgan savat o'z tomonida tirik g'oya bo'lmasa, BE + qoplama bilan yopiladi.
- **E8. Hisobot:** chuqur savatlar `Sirus_Recovery_<symbol>_<magic>.csv` fayliga yoziladi.
- **E9. Panel:** SAVAT bo'limida "Qutqarish: …" qatori chiqadi.
- O'zgarmaganlar: Basket SL 50%, favqulodda yopish 50% / 52%, eski Smart Early Exit (42%).

## 15-bosqich: bozor rejimi, FVG retest, sham ketma-ketligi

- **D1. M15 rejimi** (`EnableRegimePlaybook`): TREND, DIAPAZON, PORTLASH yoki SIQILISH. Har M15 barda bir marta o'qiladi. Hakamdagi o'yin kitobi:
  - **TREND:** trend tomoniga sifat +4, teskari tomoniga −4. Miya ham tomonda bo'lmasa, tasdiqlangan reversal kerak.
  - **DIAPAZON:** chekkasi yaxshi joy (+5). O'rtasida sifat −8 va faqat EHTIYOT lot.
  - **PORTLASH:** portlash tomoniga +4. Teskari tomonga reversalsiz kirish yo'q.
  - **SIQILISH:** ichida sifat −6 va EHTIYOT lot. Siqilishdan chiqish shamida (jonli displacement / LIVE SWEEP / COMP-RELEASE) +4.
  - Panelda "Rejim (M15)" qatori chiqadi.
- **A6. FVG retest:** narx shu yo'nalishdagi to'lmagan FVG'ga birinchi marta qaytsa, bu joy hisoblanadi va sifat +5.
- **A3. M5 ketma-ketlik:**
  - "bosim pauzadan keyin davom etyapti" trigger bo'ladi;
  - "burilish shakllanyapti" kirishga qarshi bo'lsa, sifat −6;
  - savatga qarshi bo'lsa, grid qo'shmaydi.

## 14-bosqich: haqiqiy tezlik

- **C1. LIVE SWEEP** (`EnableLiveSweep`): likvidlik yechilishi tikda ko'rinadi.
  - Har M1 barda narx yaqinidagi olinmagan hovuzlar yig'iladi: M5/M15/H1 swing va teng high/low, PDH/PDL, Osiyo.
  - Narx hovuzdan biroz o'tib, 45 soniya ichida qaytsa, darhol trigger beriladi. Avval bu bar yopilishini kutardi: M1 da 60 soniyagacha, M5 da 5 daqiqagacha.
  - Savdoga qarshi tomonga M5+ LIVE SWEEP bo'lsa, V4 veto ishlaydi.
- **C4. SmartFill momentumda kutmaydi** (`SmartFillMomentumSkip`): jonli displacement, yangi LIVE SWEEP yoki hozirgina yopilgan M1 displacement bo'lsa, darhol kiradi. Qolgan holatlarda avvalgidek yaxshi narxni kutadi.
- **C2** alohida kod talab qilmadi: kirish quvuri har tikda ishlaydi, endi triggerlar ham tikda keladi.
- **C5** (eski skanerni jilovlash) profiler raqamlari kelgandan keyin qilinadi.

## 13-bosqich: yo'nalish × sham

- **A1. Yo'nalish almashuvi:** yangi yo'nalish tomonida M1 yoki M5 da kuchli sham bo'lsa (displacement, rejection, liq-grab, fake breakout), miya darhol almashadi. Eski yo'nalishni itarayotgan shamlar bo'lsa, 3–4 bar kutadi. Sham yo'q bo'lsa, avvalgidek 2 bar.
- **A2. Uch TF bosimi (M1 / M5 / M15):**
  - uchalasi ham tomonda bo'lsa, sifat +6;
  - M15 tomonda, M1/M5 qarshi bo'lsa — pullback, joy hisoblanadi;
  - M15 va M5 qarshi bo'lsa — charchoq: sifat −8 va faqat EHTIYOT lot;
  - bosim miya ishonchiga ham qo'shiladi va panelda "Bosim" qatori chiqadi.
- **A4. V5 veto:** charchagan impulsga yangi kirish yo'q. Charchagan deganda 3-to'lqin yoki EXPIRED tezlik, ustiga charchoq / absorbsiya / rejection shami tushuniladi.
- **A5. Rejection tasdig'i:** rejection, liq-grab yoki exhaustion shami trigger bo'lishi uchun narx uning tanasi o'rtasidan o'tgan bo'lishi kerak. Soyasi buzilsa, trigger bekor. Grid javobi ham shu qoida bilan tekshiriladi.
- Kalitlar: `EnableCandleDirectionLink`, `EnableExhaustionVeto`, `EnableRejectionConfirm`.

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
