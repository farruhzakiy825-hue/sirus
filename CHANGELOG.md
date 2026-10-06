# CHANGELOG — Sirus Brain V8

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
