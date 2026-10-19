# CHANGELOG — Sirus Brain V8

## 47-paket: Strategy Tester uchun alohida versiya ("too many inputs" xatosi) (2026-10-19)

- **Muammo:** jonli botda ~2800 ta sozlama bor. Jonli grafik buni ko'taradi, Strategy Tester esa "too many inputs"
  deb ishga tushmaydi.
- **Yechim:** `Sirus_Brain_V8_Tester.mq5` va `SirusT/` papkasi.
  - Bu to'liq bir xil bot.
  - Asosiy sozlamalar sozlama bo'lib qoladi: "SIRUS ▸ 1–7" guruhlari, YADRO va EHTIMOL JADVALI, jami 76 ta.
  - Qolgan 2727 tasi jonli botdagi standart qiymat bilan o'zgarmas (const) bo'ladi.
- **Jonli bot fayllariga tegilmaydi.** Tester versiyasi skript bilan yaratiladi: `python3 tools/make_tester_build.py`.
  Har o'zgarishdan keyin skript qayta ishga tushiriladi.
- **Ehtimol jadvali** Common papkada saqlanadi. Testerda to'ldirilgan jadvalni jonli bot (bir xil simvol va magic
  bilan) o'zi o'qiydi.

## 46-paket: EHTIMOL JADVALI — 1-qadam: faqat kuzatish (savdoga ta'sir qilmaydi) (2026-10-19)

**G'oya:** qoidalarni qo'lda yozish o'rniga bozorning o'z statistikasi. Asosiy savol: "shu kabi lahzadan keyin narx
spread + TP ni grid qadamidan oldin bosib o'tadimi?"

**Qanday ishlaydi (`28_Probability_Table.mqh`):**
- **Xayoliy savdolar.** Har yopilgan M1 shamida bot 2 ta xayoliy savdo ochadi: BUY (ask'da) va SELL (bid'da).
  - Haqiqiy TP va haqiqiy birinchi grid qadami ishlatiladi.
  - Order yuborilmaydi.
- **Natija turlari:**
  - **TP:** TP ga yetdi. "Toza TP": yo'lda eng yomon qarshi yurish TP x 3 ichida qolgan.
  - **ADVERSE:** avval bir grid qadami qarshi yurdi (savatga grid kerak bo'lardi).
  - **TIMEOUT:** 30 daqiqada hech biri bo'lmadi.
- **Holat "barmoq izi".** Har tomon uchun alohida, 243 katak:
  - H1+H4: bilan / aralash / qarshi;
  - lokal (M5 + oyoq): bilan / aralash / qarshi;
  - oxirgi M1 sham: bilan / kichik / qarshi;
  - so'nggi soat M5 diapazonidagi joy: arzon / o'rta / qimmat;
  - volatillik (ATR(M1) TP ga nisbatan): sokin / oddiy / tez.
- **Saqlash.** Jadval umumiy (Common) papkada saqlanadi: `Sirus_PTable_<symbol>_<magic>.bin`.
  - Strategy Tester'da bir-ikki oy o'tkazilsa, jadval bir necha daqiqada to'ladi va jonli grafik uni tayyor holda
    o'qiydi.
  - Odam o'qiydigan nusxasi: `.csv`.
- **Panel qatori:** `EHTIMOL BUY: toza TP 46/50 (92%) · grid 4% · SELL: ...`. Bu jadvalning aynan hozirgi lahza
  haqidagi fikri. Natija kam bo'lsa, "o'rganilmoqda (n/30)" yoziladi.

**Muhim:** bu qadam hech qanday savdo qilmaydi. Qarorni YADRO qabul qiladi. 2-qadam: testerda to'ldirish va natijani
ko'rish. 3-qadam: raqamlar yaxshi bo'lsa, savdoga ulash.

Kalitlar: `EnableProbTable = true`, `PTMaxMinutes = 30`, `PTCleanMAETP = 3.0`, `PTMinSamples = 30`.

## 45-paket: keng tekshiruv — grid va kirishdagi "pichoq tutish" yo'llari yopildi (2026-10-19)

Uch mustaqil tekshiruv (kirish, grid/savat, dalil funksiyalari) bir xil turdagi kamchiliklarni topdi. Yangi to'siq
qo'shilmadi: mavjud qoidalar yangi dalilga va bir-biriga moslashtirildi.

**Grid (eng katta pul ta'siri):**
- **Qutqarish kafolati pichoq tutardi.** U "harakat sekinlashdi" degan xulosani yopilgan M5 tanalari va bir soat oldingi
  sweep'dan chiqarardi. Natijada yangi M1 bar qarshi tomonga sinayotgan paytda ham katta pog'ona qo'shilardi. Endi
  shakllanayotgan M1 qarshi displacement bersa yoki oxirgi M1 qarshi push shami bo'lsa, qutqarish yoqilmaydi. Bu ko'pi
  bilan bitta M1 bar davom etadi, grid muzlab qolmaydi.
- **Grid "javobi"** sifatida savatning oxirgi orderidan oldingi hodisa endi hisoblanmaydi. Hodisalar narx bilan bekor
  bo'ladi (44-paket).
- **"Qarshi" tekshiruvi** endi M1 dagi har qanday qarshi push shamini (continuation, breakout) hisoblaydi. Avval
  faqat displacement hisoblanardi, shuning uchun sekin tushayotgan narxga pog'ona qo'shilardi.
- **Pauza tasdig'i** endi shakllanayotgan barni ham tekshiradi.
- **Qutqarishdagi qadam hisobi** eskirgan (kichikroq) masofaga bo'linib, qutqarishni erta yoqardi. Tuzatildi.
- **M1 push shami trigger sifatida:** narx yarim ATR(M1) orqaga qaytsa, endi trigger hisoblanmaydi.

**Kirish (YADRO):**
- **Oddiy kirishda vaqt qoidasi** (kelishilgan 2-holat): oxirgi yopilgan M1 qarshi push shami bo'lsa, faqat undan
  yangi trigger hisoblanadi (jonli sham yoki jonli sweep). Eski hodisa yoki oldingi M5 shami hisobga olinmaydi.
- **Cashback'da lokal oyoq yolg'iz o'zi ham "qarshi"** hisoblanadi, agar M5 shu tomonda bo'lmasa.
- **HTF burilishi** M5 undan keyin qarshi tomonga sinsa, endi lokal qatlam va bosim qoidalarini bekor qilmaydi (avval
  soatlab bekor qilib turardi).
- **Burilish dalili** endi trigger sham bo'lishi kerak, shunchaki shu rangdagi sham (doji) yetmaydi.
- **Ikkala tomon o'tsa**, lokal qatlam (yo'nalish qatlami) HTF'dan og'irroq tortadi.
- **Order turi** o'tgan yo'liga qarab yoziladi (trendga qarshi / burilish). Grid, lot va o'rganish to'g'ri turni
  ko'radi.
- **SmartFill:** rad etilgan tikdan keyin eski "qurollanish" bekor qilinadi.

**Mikro nazorat:** M5 displacement va sweep ulushi endi faqat hali haqiqiy bo'lsa qo'shiladi.

## 44-paket: dalillar jonli narx bilan yangilanadi (eskirgan dalil bilan qaror yo'q) (2026-10-19)

Keng tekshiruvda 13:34 dagi xatoning ildizi topildi: dalil funksiyalari narx teskari ketgandan keyin ham "haqiqiy"
qolardi.
- **M5 shami dalili** (trigger, tasdiq, "bosim qaytdi" ketma-ketligi) endi quyidagi hollarda tugaydi:
  - shakllanayotgan M1 shami unga qarshi displacement bersa;
  - M5 bar yopilgandan keyin qarshi M1 push shami yopilsa;
  - push shamida narx tananing o'rtasidan orqaga qaytsa.

  Avval bu dalil butun keyingi M5 bar davomida amal qilardi.
- **Yangi hodisalar** (sweep, soxta yorib o'tish, MSS, reclaim va boshqalar) avval faqat yoshiga qarab "yangi"
  hisoblanardi. Endi:
  - sweep / soxta yorib o'tishning chekkasi olinsa, hodisa bekor bo'ladi;
  - boshqa hodisalarda narx darajadan 0.25 ATR orqaga qaytsa, bekor bo'ladi;
  - muvaffaqiyatsiz MSS / reclaim hisoblanmaydi.
- **TEZKOR ZARBA** 3 soniyadan eski bo'lsa (yoki momentum yo'q bo'lsa), SmartFill uni hisobga olmaydi. Avval bir
  necha daqiqa oldingi hukm bilan kutishni o'tkazib yuborardi.
- **M1 momentum**: narx displacement shamining yopilishidan 0.25 ATR qaytgan bo'lsa, momentum hisoblanmaydi.

Bular kirish, grid va hakamning hammasida ishlatiladigan umumiy funksiyalar. Hech qanday yangi to'siq qo'shilmadi:
dalil faqat yangi va haqiqiy bo'lganda hisoblanadi.

## 43-paket: burilish kirishlari pichoq tutmaydi — oxirgi M1 sham o'z tomonida bo'lishi shart (2026-10-19)

**Jonli holat (13:34):** 13:30 dagi yuqoriga otilishdan keyin barcha M1 shamlar pastga ketdi. Lokal ▼, mikro ▼,
lokal oqim kuchli ▼ edi. Shunda ham BUY 4163.0 da ochildi va narx 4152 gacha tushdi. Sabab: burilish istisnolari
(cho'zilgan yugurishdan keyingi burilish va miya burilishi) otilishning hali "amal qilayotgan" M5 tasdig'ini dalil deb
qabul qildi.

**Tuzatish (3 qatlam qoidasi: vaqtni mikro belgilaydi).** H1/H4 ga qarshi yoki burilish sifatida o'tkaziladigan
tomon uchun:
- **oxirgi yopilgan M1 shami shu tomonda** bo'lishi kerak;
- **shakllanayotgan sham qarshi yurmasligi** kerak;
- **mikro nazorat aniq qarshi tomonda bo'lmasligi** kerak (kamida 45%).

Yangi sweep reclaim'da sweep shamining o'zi dalil bo'ladi, shuning uchun u yerda faqat shakllanayotgan sham tekshiriladi.

Oddiy trend bo'yicha yoki neytral kirishlar o'zgarmadi.

## 42-paket: Autopsy'dagi soxta "GRID MUZLADI" belgisi tuzatildi (2026-10-19)

- 19-oktabr Autopsy faylida 12 savatdan 10 tasi "GRID MUZLADI" deb belgilangan edi. Ular orasida 0 daqiqa yashagan
  savatlar ham bor edi.
- Sabab: grid "ushlab turish" vaqti oldingi savatdan qolib ketardi. Grid engine uni faqat grid qo'sha olganda
  tozalardi.
- Endi har yangi savat va savat yopilishida bu vaqt nolga qaytadi. Autopsy tahlili endi to'g'ri ma'lumot beradi.

## 41-paket: filtrlar yana yoqildi; "ikki tomon yopiq" nazorati qo'shildi (2026-10-19)

- **Egasining qarori:** filtrni savdo ko'payishi uchun shunchaki o'chirish yechim emas. Ularni bir-biriga moslashtirish
  kerak. 40-paketdagi o'chiq holat bekor qilindi: hammasi yoqiq. Xatti-harakat 39-paket bilan bir xil, unda savdo
  boshlangan edi. Kalitlar faqat sozlash uchun qoladi.
- **Yangi nazorat (faqat tashxis, hech narsani yumshatmaydi):**
  - YADRO'ning setup qoidalari ikkala tomonni ham 5 daqiqadan ko'proq yopib tursa, HOLAT NAZORATI'da sariq qator
    chiqadi: `Ikki tomon N daq yopiq: BUY <sabab> | SELL <sabab>`.
  - Jurnalga ham yoziladi (15 daqiqada bir marta): `[SIRUS YADRO DEADLOCK]`.
  - Xavfsizlik to'xtatgan (yangilik, pauza) yoki savat ochiq paytlar bu hisobga kirmaydi.
  - Shu bilan qaysi ikki qoida bir-biriga zid ekanini aniq ko'ramiz va o'sha juftni moslashtiramiz. 37-paketda
    global bias va H1 bosimi juftligi shunday hal qilingan edi.

## 40-paket: YADRO birinchi tez holatiga qaytarildi — keyin qo'shilgan to'siqlar o'chiq kalitlarga o'tdi (2026-10-19)

**Xato nima edi:** birinchi YADRO (29-paket) savdoni tez boshladi. Keyin har skrinshotdan keyin yangi to'siq
qo'shildi (31–38 paketlar). Har biri alohida mantiqli edi, birgalikda esa botni yana bo'g'ib qo'ydi. Bu aynan YADRO
tugatishi kerak bo'lgan "to'siqlar yig'indisi" xatosi edi. Kelishilgan qoida buzilgan edi: filtr faqat dalil bilan,
birma-bir qaytariladi.

**Endi har bir qo'shimcha to'siq alohida kalit:**

| Kalit | To'siq | Holat |
|---|---|---|
| `CoreNoChasing` | cho'zilgan yugurish cho'qqisida kirmaslik (4177 dagi BUY xatosidan) | **yoqiq** |
| `CoreUseMicroControl` | mikro nazorat minimum | o'chiq |
| `CoreUseGlobalLocal` | global bias'ga qarshi M5 / lokal burilishi talabi | o'chiq |
| `CoreUseZoneChecks` | H1/H4 zona va RBR/DBR zona bloki | o'chiq |
| `CoreUseH1PushRule` | "H1 + M15 itaryapti" (bitta HTF qarshi bo'lganda) | o'chiq |
| `CoreUseLocalLayer` | lokal qatlam qarshi bo'lsa to'xtash; oddiy rejimda qattiq lokal | o'chiq |

**Saqlab qolinganlar:**
- **Savdo qo'shadigan qoidalar:** burilishga kirish, HTF burilishi, miya burilishi, lokal burilish, tor diapazon
  istisnosi.
- **Xavfsizlik:** yangilik egasi, tartibsiz bozor / spread / eskirgan tik.
- **Tezlik:** maslahatchi, TP/SL chiziqlari.
- **Tuzatishlar:** lot / hakam holati, panel, TP dan keyin darhol qayta kirish.

Yopilgan burilish shami faqat to'liq trendga qarshi tomon va burilish uchun talab qilinadi. 29-paketdagidek, qolgan
kirishlarga istalgan trigger yetadi.

## 39-paket: TP dan keyingi qayta kirish SmartFill'da kutmaydi (2026-10-19)

- Avval SmartFill har bir kirishni (TP dan keyingi qayta kirishni ham) 8 soniyagacha ushlab turardi. U 120 punktlik
  pullback kutardi. Pul to'layotgan harakatda bunday pullback kam bo'ladi, kutish esa keyingi shamni yo'qotardi.
- Endi qayta kirish darhol yuboriladi, agar uch shart bajarilsa:
  - foydali chiqishdan keyin 2 daqiqa ichida, o'sha tomonga;
  - quvish emas (chiqish narxidan 1 ATR(M5) ichida);
  - mikro nazorat qarshi tomonga o'tmagan.
- Boshqa kirishlarda SmartFill avvalgidek ishlaydi. Momentum yoki tezkor zarba bo'lsa, u kutmaydi.

## 38-paket: YADRO — uch qatlam uyg'unligi: katta TF xavf, lokal yo'nalish, mikro vaqt (2026-10-19)

Egasi bilan kelishilgan tartib:

| Qatlam | Vazifa |
|---|---|
| H1 / H4 | **Xavf**: qaysi tomon grid bilan qimmatga tushishi mumkin |
| Lokal (M5 struktura + lokal oyoq) | **Yo'nalish** |
| Mikro (M1 shamlar, mikro nazorat) | **Vaqt**: mikro burilishlar shu yerda ushlanadi |

1. **Hammasi bir tomonda:** shu tomonga yurgan har yopilgan M1 shamida kirish, TP dan keyin darhol qayta kirish.
2. **Mikro lokalga qarshi qaytdi:** qarshi kirilmaydi. Mikro lokal tomonga qaytgan shamda kiriladi.
3. **Lokal katta TF'ga qarshi burildi** ("lokal burilish" savdosi). Lokal tomonga kirish mumkin, agar:
   - mikro nazorat 60%+ bo'lsa;
   - H1 + M15 sham bosimi hozir qarshi itarmayotgan bo'lsa (itarsa — tasdiqlangan HTF burilish yoki miya burilishi
     kerak);
   - TP uchun joy va zonalar tekshiruvdan o'tsa.

   Cashback rejimida yopilgan M1 trigger shami yetadi. Oddiy rejimda kuchli yopilgan burilish shami kerak.
4. **Mikro hamma narsaga qarshi:** kirilmaydi. Istisno — cho'zilgan yugurishdan keyin sweep yoki yopilgan burilish
   shami bilan burilish.

**Lokal qatlam rejimga qarab:**
- **Cashback (TP kichik):** M5 struktura YOKI lokal oyoq yetarli.
- **Oddiy rejim (TP kattaroq):** ikkalasi ham kerak, yoki biri shu tomonda va ikkinchisi neytral bo'lsin. Ikkisi bir
  biriga zid bo'lsa, oddiy rejim aniqlik kutadi.

**Lokal qatlam qarshi bo'lsa:** o'sha tomonga kirilmaydi, lokal burilguncha kutiladi. Istisno — tasdiqlangan burilish.

Kalit: `CoreLocalTurnControl = 60`.

## 37-paket: YADRO — "boshi berk ko'cha" (ikki tomon birdan to'silishi) yechildi (2026-10-19)

**Jonli holat (13:05):** H1 pastki likvidligi sweep qilindi (4165.5), global bias TRANSITION_UP ga o'tdi, M5 va lokal
oyoq yuqoriga burildi. Lekin ikkala tomon ham to'silgan edi:
- **BUY:** H1 DN va H1 + M15 shamlari hali pastga itaryapti.
- **SELL:** global bias'ga qarshi, M5 / lokal pastga burilmagan.

Har bir qoida alohida to'g'ri, birgalikda esa burilish davom etguncha bot jim qoldi.

**Yechim:** global bias (miyaning burilishni o'qiydigan qatlami: struktura xotirasi, qulf, burilish yetukligi) shu
tomonga og'ib bo'lgan bo'lsa va M5 yoki lokal oyoq ham u bilan bir xil bo'lsa, burilish allaqachon boshlangan
hisoblanadi. H1 / M15 sham bosimi orqada qolgan qism, shuning uchun:
- "hali itaryapti" degan rad etish olib tashlanadi;
- bu holat o'sha tomon uchun "joy" hisoblanadi;
- lekin yopilgan burilish shami baribir shart.

Oddiy trend bo'yicha yoki neytral kirishlarda o'zgarish yo'q: istalgan trigger yetadi.

## 36-paket: panel — YADRO sababi har tomon uchun alohida qatorda (2026-10-19)

- Avval "YADRO BUY: … · SELL: …" bitta qatorga sig'madi va SELL qismi qirqilib qolardi. Endi ikki qator bor:
  `YADRO BUY : …` va `YADRO SELL: …`. Har birida o'zbekcha sabab (yo'nalish / joy / trigger / TP uchun joy) yoki
  "tayyor: …" yoziladi.
- Xavfsizlik to'xtatgan bo'lsa (pauza, yangilik, spread, ochiq savat), ikkala qatorda "xavfsizlik - …" ko'rinadi.
  Avval bu holatda eski sabab qolib ketardi.

## 35-paket: YADRO — tasdiqlangan katta TF burilishi trendga qarshi kirishga ruxsat beradi (2026-10-19)

**Jonli holat (12:39):** katta TF likvidligi ovlandi (KEY pastki SWEEP @ 4163.7), M1 darajadan qaytdi, M5 yuqoriga
burildi. YADRO esa har BUY'ni rad etdi: H1 DN va H1 + M15 shamlari hali pastga itarayotgan edi. Bu holatda bot 9
daqiqa jim turdi, rad etishlarning 96% i yo'nalish sababli bo'ldi.

Avvalgi hakamda bunga javob bor edi, YADRO'ga ham qo'shildi. Shart: H1 / H4 / KEY likvidligining **tasdiqlangan**
burilishi (sweep + displacement / MSS / reclaim) kirish tomoniga, eng yangi qarshi H1 / H4 yorib o'tishdan keyin
bo'lishi kerak. Bunda:
- "H1 + M15 hali itaryapti" degan rad etish qo'llanmaydi;
- burilishning o'zi joy hisoblanadi.

Lekin baribir talab qilinadi:
- yopilgan burilish shami yoki sweep;
- M5 yoki lokal oyoq shu tomonga burilgan bo'lishi;
- V1, zonalar, TP uchun joy va mikro nazorat.

Tasdiqlanmagan sweep bilan avvalgidek kirilmaydi.

## 34-paket: tezlik — YADRO maslahatchisi, savat chiziqlari, himoyalar o'lchagichi (2026-10-19)

- **Eski zanjir maslahatchisi har tikda to'liq ishlardi**, savat ochiq bo'lsa ham, va YADRO'ning ustiga qo'shimcha
  yuk bo'lardi. Endi u faqat kerakli paytda ishlaydi:
  - YADRO kirish olgan tikda (har savdo eski zanjir fikri bilan yoziladi; SmartFill kutganda ham bir marta);
  - savat yo'q paytda daqiqasiga bir marta (rad etishlar uchun);
  - savat ochiq yoki xavfsizlik to'xtatgan paytda umuman ishlamaydi.
- **TP/SL chiziqlari har tikda 10–15 marta qayta chizilardi.** Savat statistikasi bir tikda shuncha marta
  yangilanadi, har safar grafik bilan sinxron so'rov ketardi (`ObjectFind`). Savat yo'q paytda esa har tikda o'nlab
  o'chirish buyrug'i yuborilardi. Endi chiziqlar faqat ko'rsatadigan narsa o'zgarganda yoki daqiqada bir marta
  chiziladi.
- **Himoyalar qismi ichki o'lchanadi:** risk, VPS, pack3, safety, warn, pack2, recovery, smartexit. "Tezlik sekin"
  qatorida endi aniq aybdor ko'rinadi, masalan `og'iri himoyalar 36 ms (recovery 30.2)`.

## 33-paket: YADRO — mustaqil tekshiruvda topilgan kamchiliklar tuzatildi (2026-10-19)

**Xavfsizlik (jiddiy):**
- **Jonli yangilik bloki tushib qolgan edi.** Kutilmagan yangilik spike'ida grid to'xtardi, birinchi kirish esa
  ochilaverardi. Endi YADRO ham yangilik egasini (`NewsOwnerBlocksEntry`) so'raydi.
- **Bozor tartibsizligi (chaos), o'qib bo'lmaydigan yoki o'ta katta spread, eskirgan tik** endi YADRO'da ham kirishni
  to'xtatadi (`ScoreHardBlockCheck`).

**To'g'rilik:**
- **Lot va SmartFill boshqa tomon hukmini o'qirdi.** Maslahatchi (eski zanjir) qoldirgan hakam holati tasodifan lotni
  x0.75 qilardi yoki SmartFill'ni o'tkazib yuborardi. Endi tanlangan tomon uchun hakam holati yangilanadi. CAUTION
  YADRO kirishining lotini kichraytirmaydi. Memory to'g'ri kirish DNK'sini o'rganadi.
- **Maslahatchi ball holatini buzib qoldirardi.** Uning yengilliklari, tezkor kirish va redirect qiymatlari lot,
  ogohlantirish og'irligi va ball oralig'iga o'tib ketardi. Endi skaner holati to'liq qaytariladi. YADRO skanerga
  teskari tomonga kirsa, ball minimum bo'ladi (boshqa tomonning bali o'tmaydi).
- **Tor diapazonda ikki tomon birdan to'silardi (V3).** Endi faqat TP uchun joyi kamroq tomon to'siladi.
  `MBVetoNoRoom` kaliti ham hisobga olinadi.
- Dalil darvozalari faqat olingan tomon uchun yoziladi. Trace qatori maslahatchisiz ham toza boshlanadi.

**Treyder mantig'i:**
- H1 yoki H4 dan biri qarshi bo'lsa va H1 + M15 shamlari hali qarshi itarayotgan bo'lsa, kirish yo'q. Bu hakamning
  avvalgi TAQIQ'i: jonli H1 pullback'ga qarshi sotib olmaslik. Isbotlangan burilish bundan mustasno.
- "Oyoqning oxiri" endi faqat H1 yoki H4 qarshi bo'lganda to'sadi (sarlavhadagi qoida bilan bir xil). Cho'qqida
  quvmaslik qoidasi alohida ishlaydi.

## 32-paket: YADRO — global/lokal va zonalar qayta tekshirildi (2026-10-19)

- **Global va lokal:** global bias'ga qarshi kirish endi faqat M5 struktura yoki lokal oyoq shu tomonga burilgan bo'lsa
  ochiladi. Bu eski V0 "lokal savdo" qoidasi. H1 + H4 trendi ichidagi M15 pullback ham shunga kiradi: M15 hali tushib
  turganda BUY yo'q, M5 yoki lokal oyoq qaytgach ochiladi. Cho'zilgan yugurishdan keyingi burilish bundan mustasno:
  uning dalili yopilgan burilish shami yoki sweep.
- **Katta TF zonalari (20g):** qarama-qarshi tomonning yangi H1/H4 zonasi ichida yoki uning qoq oldida kirish yo'q.
  M15 sham uni yopilish bilan olib tashlagunicha kutiladi.
- **Zona intellekti (20i):** kuchli (85+) yangi qarama-qarshi RBR/DBR/RBD/DBD zona 0.35 ATR(M5) ichida bo'lsa va bu
  tomonning shu yerdagi zonasi kuchsizroq bo'lsa, kirish yo'q. Bu hakamning BLOCK hukmi. Faqat jonli sham uni hozir
  yorib o'tayotgan bo'lsa, istisno.

## 31-paket: YADRO mikro nazoratni ham o'qiydi (2026-10-19)

YADRO shamlarni avvaldan o'qiydi: trigger shamlar (hajm tekshiruvi, rejection'ning davomi bilan), jonli sham, M1/M5
hodisalari (sweep, soxta yorib o'tish, MSS, reclaim, rejection, siqilishdan chiqish), M5 struktura, lokal oyoq,
charchash bosimi, qarshi displacement (V4), H1/M15 sham bosimi. Endi unga mikro nazorat qatlami (20d) ham ulandi:
- **Kim boshqaryapti (BUY% / SELL%).** Oddiy kirish o'z tomonining nazorati 35% dan past bo'lsa ochilmaydi, ya'ni
  qarshi tomon oqimni 65%+ ushlab turgan payt. Burilish kirishiga bu talab qo'yilmaydi: nazorat burilishdan kech
  qoladi, uning dalili yopilgan burilish shami yoki sweep.
- **Mikro burilish turi.** Asosiy yo'nalishga qarshi REVERSAL bo'lsa, burilish tomoni ustunlik oladi. Asosiy tomon
  EXHAUST yoki REVERSAL holatida bo'lsa, o'sha tomon ustunlikni yo'qotadi.
- Panel / Trace: har kirish sababida `control NN%` ko'rinadi.
- Kalit: `CoreMinControl = 35` (0 = o'chiq).

## 30-paket: YADRO — cho'qqida quvmaslik va tasdiq bilan burilishga kirish (2026-10-19)

**Jonli holat (11:16):** narx 4168 dan 4177.6 gacha ~9$ ko'tarildi (H4 pastga burilayotgan edi). YADRO aynan cho'qqida
BUY ochdi (4177.4), keyin narx 4169 gacha qaytdi. Treyder yugurishning oxirgi tikida sotib olmaydi. Cho'qqida harakat
to'xtasa, u burilishni qidiradi.

- **Quvmaslik (2-savol, Joy):** oxirgi 8 ta M5 barda harakat ATR(M5) x 1.8 dan ko'p yurgan bo'lsa va narx shu
  diapazonning yuqori choragida tursa, o'sha tomonga kirilmaydi. Panel yozuvi: "joy - BUY at the tip of a 3.8 ATR(M5)
  run". H1 + H4 bilan bir tomonda bo'lsa, chegara ATR x 3.0 (trend yugurishiga ko'proq joy).
- **Burilishga kirish:** qarshi tomonning yugurishi cho'zilgan bo'lsa, bu tomon "burilish" hisoblanadi va ustunlik
  oladi. Kirish faqat dalil bilan:
  - yopilgan burilish shami yoki yugurish uchining sweep'i;
  - shakllanayotgan sham hali qarshi tomonga kuchli yurayotgan bo'lsa (V4), kutadi;
  - H1 + H4 kuchli trendga qarshi bo'lsa, avvalgidek o'z joyi ham kerak (sweep yoki ushlab turgan daraja).
- Hedge yo'q qoidasi o'zgarmadi: ochiq savat bor paytda qarama-qarshi kirish ochilmaydi.
- Kalitlar: `CoreTipLegATR = 1.8`, `CoreTipLegATRTrend = 3.0`, `CoreTipBars = 8`, `CoreReversalEntry = true`.

## 29-paket: YADRO — birinchi kirish 5 savol bilan hal qilinadi (2026-10-19)

**Nega:** tuzatishlardan keyin ham bot jim turdi. Birinchi kirishni 150+ joy rad etishi mumkin edi va hammasi bir
vaqtda "ha" deyishi kerak edi. 383 daqiqalik qarordan faqat 7 tasida savdo ochilgan. Soya daftari esa filtrlar xavfni
ajratmasligini ko'rsatdi: rad etilganlarning 3–7% i grid talab qilardi, ochilganlarning 17%.

**YADRO (`27_Core_Entry.mqh`), har tikda ikkala tomon uchun:**
1. **Yo'nalish.** H1 + H4 bilan yoki neytral bo'lsa — ochiq. Ikkalasi qarshi bo'lsa yoki bias −3 bo'lsa, faqat o'z
   joyida mumkin (sweep yoki ushlab turgan daraja). Bunda M5 / lokal oyoq burilgan va yopilgan trigger bo'lishi kerak,
   H1 + M15 qarshi itarayotgan bo'lmasligi kerak. V1 (tasdiqlangan burilish) va zarardan keyingi qayta kirish xotirasi
   saqlandi.
2. **Joy.** Charchagan impuls va olingan likvidlik to'sadi. "Oyoqning oxiri" faqat H1 + H4 ga qarshi bo'lsa to'sadi.
3. **Trigger.** Hozir shu tomonga trigger bo'lishi kerak (trendga qarshi bo'lsa — yopilgan burilish). Shakllanayotgan
   sham qarshi tomonga displacement bermasligi kerak (V4).
4. **TP uchun joy.** TP ichida ushlab turgan qarama-qarshi daraja yo'q (V3), xarajat odatiy.
5. **Xavfsizlik.** Risk, safety, yangilik, spread, dam olish / bayram, anomaliya, dublikat, pauza, bitta savat,
   broker xatosidan keyin kutish, operator va sozlamalar tekshiruvi.

- Ikkala tomon o'tsa, yaxshiroq joylashgani olinadi. Teng bo'lsa, shu tomonga hal qiladi: jonli sham, keyin M5,
  keyin lokal oyoq.
- **Eski zanjir o'chirilmadi.** U maslahatchi bo'lib ishlaydi: har qaror yonida Trace'ga `eski: ...` yoziladi.
  Shu orqali har bir eski filtrni YADRO uning maslahatiga qarshi ochgan savdolarda o'lchab, foydasi isbotlanganini
  birma-bir qaytaramiz.
- Panel: "Sabab" va "YADRO BUY: … · SELL: …" qatori har tomonning holatini ko'rsatadi.
- Grid, chiqish, basket SL, cashback TP, lot qoidalari o'zgarmadi.
- Kalitlar: `EntryCoreMode = true`, `CoreLegacyAdvisor = true`.

## 28-paket: jonli savdo tahlili - trend ichidagi SELL'lar 2 soat to'silgani tuzatildi (2026-10-19)

19-oktabr fayllari (Trace, Shadow, Autopsy) tahlil qilindi. 07:40 dan 09:17 gacha (server vaqti) birorta ham kirish
bo'lmagan. Narx shu vaqtda 4184 dan 4170 gacha tushgan, H4 va H1 pastga qaragan edi.
- **Sabab:** V2 veto ("zona hali SUPPORT, sweep qilinib qaytarilgan - sotish zonasi emas") 151 marta SELL'ni to'sgan.
  Pastga tushayotgan zinapoyada har bir kichik M5 past nuqta avval sweep qilinadi va bir oz qaytadi. V2 har birini
  "qaytarilgan support" deb o'qib, trend bo'yicha sotishni to'sib qo'ygan.
- **Dalil (soya daftari, 15-oktabrdan beri):** V2 to'sgan trend bo'yicha SELL'lar 120 ta, ulardan faqat 4 tasi (3%)
  grid talab qilardi. Haqiqatda ochilgan kirishlarda bu ko'rsatkich 17%. Ya'ni V2 eng xavfsiz kirishlarni to'sgan.
- **Tuzatish:** H4 va H1 ikkalasi kirish tomonida bo'lsa, faqat "sweep qilinib qaytarilgan" kichik zona endi to'smaydi.
  Bu trend ichidagi pullback. Haqiqiy burilishni V1 (sweep + displacement / MSS) ushlaydi va u o'zgarmadi. Hech qachon
  buzilmagan support va retest kutayotgan buzilgan zona avvalgidek to'sadi. Trendga qarshi BUY'lar (VH) ham avvalgidek
  to'siladi.
- Yangi kalit: `MBVetoZoneRoleTrendPass = true`. O'chirilsa, eski xatti-harakat qaytadi.

**Ikki tomonga savdo (egasining talabi: "BUY joyida BUY, SELL joyida SELL"):**
- Trend pastga bo'lsa, hakam (VH) har qanday BUY'ni TAQIQ qilardi, hatto ushlab turgan support ustidagi BUY'ni ham.
  Soya daftari (15-oktabrdan beri): shunday to'silgan BUY'larning faqat 5% i grid talab qilardi, ochilganlarda 17%.
- Endi H1/H4 qarshi bo'lsa ham, narx **o'z joyida** tursa, TAQIQ o'rniga EHTIYOT beriladi. O'z joyi:
  - qarama-qarshi tomon likvidligi hozirgina sweep qilingan (LIVE sweep);
  - yoki zona roli dvigateli "hali ushlab turibdi" degan support / resistance ATR(M5) x 0.35 ichida.
- EHTIYOT avvalgidek M5 struktura yoki lokal oyoq burilganini va yopilgan burilish triggerini talab qiladi.
- V0 (bias ruxsati) ham shu joyni tan oladi. Faqat zaif yoki burilayotgan bias'da (-1 / -2) ishlaydi.
- O'zgarmagan: kuchli qarama-qarshi bias (-3) va "H1 + M15 hali qarshi itaryapti" holati avvalgidek to'siladi.
- Yangi kalitlar: `ArbiterCounterAtLocation = true`, `ArbiterLocationATR = 0.35`.

**Zona xatosi:** zonalar zanjir bo'lib birlashib ketardi: har bir daraja faqat oldingisiga tegsa yetardi. Natijada
110 ta M30/H1 daraja bitta "4130-4200 support zonasi"ga aylangan (70$ keng), 4130 dan yuqoridagi har SELL
"supportga sotish" deb to'silgan. Endi bitta zona ATR(M5) x 2.5 dan keng bo'lmaydi (`ZoneClusterMaxATR`).

**Panel:** "Balans: noto'g'ri ochilgan / o'tkazilgan yaxshi" qatori tushunarliroq yozildi: "Bugun: xato kirish X/Y
savat · rad etilgandan TP ga yetardi A/B".

**Drift himoyasi:** bu himoya eskirgan signalni QUVISHga qarshi. Endi:
- narx signalga qarshi tomonga ketgan bo'lsa (yaxshiroq narx), to'smaydi;
- H1 + H4 trendi bo'yicha kech kirish ham to'silmaydi. Soya daftarida drift to'sgan SELL'lar: 9 TP / 0 GRID.

## 27-paket: tezlik o'lchagichi to'g'rilandi (2026-10-18)

Paneldagi "Tezlik sekin: tik 44.55 ms (eng ko'p 1323.4) · og'iri: skaner 3" ogohlantirishi tekshirildi. Har bir bo'lim
3 ms dan kam edi, jami esa 44 ms ko'rinardi. Sabab: EA ishga tushgandagi birinchi tiklardan biri (tarix, indikatorlar,
kalendar yuklanadi) 1.3 soniya oldi va bozor jim paytida u bir necha haqiqiy tik bilan o'rtachaga qo'shilib ketdi
(1323 / 30 ≈ 44). Bu savdo sekinligi emas edi.
- Birinchi 20 tik o'rtacha va eng ko'p qiymatga qo'shilmaydi, ularning cho'qqisi jurnalga bir marta yoziladi.
- "Sekin" ogohlantirishi kamida 100 ta o'lchangan tikdan keyingina chiqadi.
- Yangi "boshqa" bo'limi: tikning hech bir bo'limga kirmagan qismi. Endi "og'iri" har doim haqiqiy aybdorni ko'rsatadi.
- Broker yopgan savatdan keyingi qarorlar ham tik sifatida o'lchanadi.
- HOLAT NAZORATI qatori qisqartirildi, endi bir qatorga to'liq sig'adi.

## 26-paket: treyder sifatida xolis tekshiruv - topilgan xatolar tuzatildi (2026-10-18)

To'rt yo'nalishda mustaqil tekshiruv (pul va risk; yo'nalish va kirish; 14-paket birlashtirishlari va kompilyatsiya;
yangi himoyalar). Har topilma kod bilan tasdiqlangandan keyin tuzatildi. Statik tekshiruvlar toza.

**Muhim (P1):**
- **Yangiliklar kalendari amalda deyarli ishlamagan.** `CalendarValueHistory` true/false qaytaradi, kod esa uni hodisalar
  soni deb o'qirdi: muvaffaqiyatli o'qishda faqat BIRINCHI qator ko'rilardi (ko'pincha past ahamiyatli) - yangilik
  oynasi, auto-flat va "surprise" deyarli hech qachon ishlamagan; xato esa hech qachon xato deb ko'rilmagan, fail-safe
  yoqilmasdi. Endi qatorlar soni `ArraySize`, xato `GetLastError` bilan; panel radari ham. 7 kun bo'yi bitta ham USD
  qatori bo'lmasa - kalendar yuklanmagan deb hisoblanadi (fail-safe).
- **Margin rescue pog'onani oldingisidan kichik qilardi** (qoidangiz buzilardi). Endi eng kami - oldingi pog'ona;
  sig'masa, pog'ona qo'yilmaydi. Margin darajasi kesishi ham bu qoidani buzolmaydi.

**O'rta (P2):**
- Grid chuqurligi savatdagi mavjud zararni hisobga oladi: basket SL'gacha bir necha yuz punkt qolganda yangi pog'ona
  ochilmaydi (u qutqara olmaydi).
- "G'oya o'ldi" chiqishi to'langan swapni qo'shadi - sof zararda yopilmaydi.
- Hakam: "yaxshiroq joy" rejasi order to'lganda o'chadi (avval hukm chiqqanda o'chib, SmartFill kutayotganda yo'qolardi);
  reja darajasidan 0.5 ATR(M5) dan ko'p o'tib ketgan yoki rolini yo'qotgan daraja endi "joy" emas (pichoq tutmaslik);
  cashback'da neytral / range kirishga bitta shakllanayotgan M1 sham yetarli emas - kamida bitta yopilgan dalil kerak;
  qarshi kuchli tomonga kirishda soya klapani talabni o'zi yumshatmaydi (qoidangiz: yo'nalish darvozalari o'z-o'zidan
  yumshamaydi); grid zinapoyasi haqiqiy masofa bilan (ATR tagligi va min/max) hisoblanadi.
- Nusxa himoyasi yurak urishi taymerda ham - bozor tanaffusidan keyin ikki grafik bir vaqtda savdo qilmaydi.
- Savatning cashback / oddiy rejimi terminal qayta ishga tushganda yo'qolmaydi.

**Kichik (P3):** fail-safe jadvali grid qutqaruvini to'xtatmaydi (faqat yangi kirish); cashback TP spread 0 o'qilsa
ham to'g'ri; Hunter spread koeffitsienti chegaralangan; autopsy "chiqish xatosi" foydada yopilganlarga qo'yilmaydi va
yarim tunda grid xatolari to'g'ri sanaladi; panel: tanaffusda eskirgan risk sababi o'rniga "bozor tanaffusda",
rad etishlar real vaqt bo'yicha, bo'sh joy faqat haqiqatda yashirilgan qatorlar bilan to'ladi; xavfsizlik jurnali
har tikda yozilmaydi.
- `SafetyMaxFirstLot` sukuti 0 (o'chiq): birinchi kirish tagligi bazaviy lotni baribir qaytarardi - 0.25 chegara hech
  qachon ishlamagan. Lot `EntryBaseLot` va `MaxLot` dan.

**Egasining qarori kerak (o'zgartirilmadi):** `EntryAffordabilityShare` = 1.0 - 3 pog'onali cashback zinapoyasi
3-pog'onani SL ga juda yaqin ochadigan qilib hisoblanadi (endi bunday pog'ona ochilmaydi, demak amalda 2 qutqaruv
pog'onasi). 0.8 qilinsa lot ~20% kichrayadi (kichik hisobda 0.02 -> 0.01, aylanma ikki baravar kam).
`CashbackSizingRungs` savatni 3 orderga cheklamaydi (katta hisobda 5 gacha boradi, budjet ichida).

## 25-paket: qolgan kamchiliklar - grid xavfi, zona to'qnashuvi hakami, rejim almashtirish (2026-10-18)

Bozor ochilishidan oldin, sinov ma'lumotisiz qilinadigan hamma band. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

- **Cashback / oddiy rejimni savdo o'rtasida almashtirish (reja 15.2).** Avval: `EnableRebateMode` o'zgartirilsa EA
  qayta ishga tushib, ochiq savat chiqishni yarim yo'lda almashtirardi (orderlarda cashback'ning kichik broker TP'si
  qolar, EA esa oddiy rejim maqsadini kutardi yoki teskarisi). Endi savat qaysi rejimda ochilgan bo'lsa, o'sha
  rejimda yopiladi (terminal o'zgaruvchisida saqlanadi, qayta ishga tushishda tiklanadi); yangi rejim keyingi
  savatdan. Panelning HOLAT NAZORATI'da sariq qator bilan ko'rinadi.
- **Bekor darajasi va grid (reja 15.5-2).** G'oyaning bekor darajasi birinchi grid pog'onasidan uzoq bo'lsa - hakam
  matnida "grid risk" belgisi; butun zinapoyadan (MaxOrders pog'ona) ham uzoq bo'lsa - basket SL g'oya xato
  ekani isbotlanishidan oldin keladi: sifat -8 (`InvalidationBeyondLadderPenalty`).
- **Zona to'qnashuvi hakami - ALLOW / CAUTION / BLOCK (reja VIII, 15.4).** Kuchli yangi qarshi zona 1 ATR(M5) ichida
  bo'lsa CAUTION (sifat -10, avvalgidek); u narxning qoq oldida (0.35 ATR ichida) yoki narx uning ichida, bahosi
  >= 85, bu tomon zonasi undan kuchsiz va jonli yorib o'tish yo'q bo'lsa - BLOCK: kutish, "yaxshiroq joy" rejasi bilan
  (qayta ochiladi: qarshi zona yorib o'tilsa yoki shu tomon zonasiga qaytilsa). Hakam matnida `zone CAUTION/BLOCK`.
- **Qaror ustuvorligi (reja VIII)** kodda yozildi: risk va xavfsizlik -> yo'nalish veto -> shamlar -> zonadagi reaksiya
  -> zona to'qnashuvi -> tick oqimi -> playbook -> quvish -> dalil -> sifat -> ijro (SmartFill, spread).
- Yangi inputlar: `EnableInvalidationGridRisk`, `InvalidationBeyondLadderPenalty` 8, `EnableZoneConflictBlock`,
  `ZoneConflictBlockATR` 0.35, `ZoneConflictBlockScore` 85.

## 24-paket: panelda HOLAT NAZORATI va bo'sh joyni to'ldirish (2026-10-18)

Egasi maketni tasdiqladi. Savdo mantiqi o'zgarmadi - faqat ko'rsatish.

- **HOLAT NAZORATI** bloki sarlavha ostida, ixcham rejimda ham doim ko'rinadi. Qizil - hozir savdo yo'q, sariq - savdo
  bor, lekin muammo bor, yashil - "Hammasi ishlayapti". Eng og'iri birinchi, ko'pi bilan 4 qator ("yana N ta").
  Tekshiradi: broker ulanishi; MT5 AutoTrading tugmasi va EA ruxsati; ikkinchi EA nusxasi; HIMOYA sababi o'zbekcha
  (bozor yopiq - so'nggi tik vaqti bilan, favqulodda / equity DD, kunlik zarar, spread, zarardan keyingi tanaffus,
  kunlik urinishlar, tarix yuklanmoqda); margin darajasi (<150% qizil, <300% sariq); oxirgi 30 daqiqada rad etilgan
  orderlar (retcode va tavsif bilan); savat DD basket SL ga yaqin (80%); xavfsizlik qatlami kutmoqda; kalendar
  ko'r yoki yangilik oynasi; tik kelmayapti; sozlama auditi ogohlantirishlari; tezlik sekin.
- **"Sabab: initial entry"** endi chiqmaydi: himoya paytida "himoya - <sabab>, yangi kirish yo'q", birinchi tikdan
  oldin "tekshiruv hali boshlanmadi".
- **Bo'sh joy:** ixcham panelda pastda joy qolsa, yashirilgan qatorlar foydalisidan boshlab qaytadi: to'siqlar bugun,
  tuzilma, LOCK, zona, joy, sessiya, filtr dalili, soya va h.k. - ekran qancha sig'dirsa, shuncha.
- Rad etilgan orderlar endi Trace o'chiq bo'lsa ham eslab qolinadi (oxirgi 8 tasi).

## 23-paket: panel yana bitta ustunli, watermark shamlar ortida va markazda (2026-10-18)

Egasining qarori: ikki ustun to'g'ri kelmadi - bitta ustunli holat yaxshi; watermark shrifti qolsin.

- **Panel:** `PanelLayout` = 0 endi bitta ustun (sig'sa to'liq, sig'masa ixcham). Ikki ustun faqat `PanelLayout` = 3
  bo'lganda. Bitta ustunda shrift avvalgidek 9.
- **Watermark doim shamlar ortida:** ob'ektning "orqa fon" belgisi endi har chizishda qo'yiladi (avval faqat yaratilganda -
  oldin oldinda yaratilgan ob'ekt oldinda qolib ketishi mumkin edi). Shamlar va zonalar watermark ustidan ko'rinadi.
- **Watermark panel ostida qolmaydi:** u panel chizilishidan oldin chizilib, grafik o'rtasida - panel ostida - qolib
  ketardi. Endi panel chegarasi aniqlangan (yoki o'zgargan) zahoti watermark qayta chiziladi: gorizontal - panel
  yonidagi bo'sh joy o'rtasida, vertikal - grafik markazida (siljimaydi). Shrift o'zgarmadi (Bahnschrift).

## 22-paket: panel - egasining ekranida tuzatish (2026-10-18)

Egasining skrinshoti (1566 px grafik, Windows 125%) va tasdiqlangan maketi bo'yicha. Savdo mantiqi o'zgarmadi.

- **Kenglik:** ikki ustunli panel grafik kengligining ko'pi bilan `PanelMaxWidthPct` (50%) qismini egallaydi. Avval
  Windows 125% masshtabida kenglik ham 1.25 baravar oshib, ekranning 70% ini olardi.
- **Shrift:** ikki ustunda `PanelFontSize` - 1 (sukut 9 -> 8) - tor ustunga ko'proq matn sig'adi.
- **"Ixcham"da qolib ketish xatosi:** to'liq balandlik faqat to'liq chizilganda o'lchanardi; ixcham holatda hech qachon
  o'lchanmagani uchun panel ixchamdan chiqmasdi. Endi har chizishda yashirilgan qatorlar sanaladi va to'liq balandlik
  hisoblanadi: sig'sa - to'liq, sig'masa - ixcham (chegarada "sakrash" bo'lmasligi uchun kichik zaxira).
- **Watermark:** ko'rinish kuchi 14% -> 20%, eng kichik o'lcham 24 -> 36 pt; panelning o'ng tomonidagi (endi kengroq)
  bo'sh joy o'rtasida.

## 21-paket: premium ikki ustunli panel va yangi watermark (2026-10-18)

Egasi maketni tanladi (ikki ustun). Savdo mantiqi o'zgarmadi. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

- **Ikki ustun.** `PanelLayout`: 0 avtomatik (grafik kengligi yetsa ikki ustun - sukut), 1 bitta ustun to'liq,
  2 bitta ustun ixcham, 3 har doim ikki ustun. Chap ustun: cashback, bozor nafasi. O'ng ustun: HAKAM · ZONALAR · JOY,
  zarba lahzasi, savat, bozor izlari, xabarlar. Balandlik sig'masa ikki ustunda ham ixcham qatorlar.
- **Premium ko'rinish:** oltin chiziqli sarlavha tasmasi, oraliqli "S I R U S" brendi va "BY ZAKIY · oltin ovchisi";
  4 ta katta kartochka - BALANS (equity), BUGUN (zarbalar), DD HOZIR (savatdagi eng chuqur), MAX DD (balans tarixi),
  har birining tepasida rangli chiziq; bo'lim sarlavhalari oltin ◆ belgi va oltin chiziq bilan; ustunlar orasida
  ingichka oltin ajratgich; pastda bitta tasma - spread, server vaqti va tezlik.
- **Watermark:** zamonaviy "Bahnschrift" shrifti (Windows 10/11 da bor), harflar oralatilgan "S I R U S", oltin tus,
  oltin chiziq va ikki ◆, ostida "B Y   Z A K I Y". **Panel egallamagan bo'sh qismning o'rtasiga** joylashadi va u
  yerga sig'masa o'zi kichrayadi - SIRUS yozuvi panel ostida qolmaydi.
- Yangi input: `PanelBrandFont` ("Bahnschrift SemiBold"). `WatermarkFont` / `WatermarkSubFont` sukuti Bahnschrift.

## 20-paket: kontekst eskirishi va nishongacha yo'l (2026-10-18)

Manba: reja 15.5-5 (kontekst eskirishi va ishonch) va master reja VI.2 (Target Engine: nishongacha to'siqlar).
Kompilyatsiya qilinmagan - statik tekshiruvlar toza. Yo'nalish qoidalari o'zgarmadi - faqat hakam SIFATI.

- **Kontekst eskirishi.** Dalil hali "dolzarb" oynada bo'lsa ham, yoshi bilan kuchsizlanadi: tasdiqlangan likvidlik
  burilishi bonusi (10) va yangi hodisa bonusi (5) har `ContextHalfLifeMin` (45) daqiqada yarmiga tushadi, eng kami
  35% qoladi. 5 daqiqalik sweep deyarli to'liq, 2 soatlik sweep ~35% kuch bilan hisoblanadi. Asosiy trigger krediti
  o'zgarmadi. Hakam matnida: `evidence 62% fresh`.
- **Nishongacha yo'l.** Nishon - shu tomonga g'oya nishoni, bo'lmasa champion likvidlik. Narxdan 1 ATR(M5) narida va
  nishondan oldin turgan to'siqlar sanaladi: kuchli (>= `ZIOpposeScore`) yangi qarshi zona yoki rolini ushlab turgan
  qarshi daraja. Har to'siq sifatni `TargetPathObstaclePenalty` (4) ga kamaytiradi, eng ko'pi 2 ta. 1 ATR ichidagi
  to'siqni avvalgidek "ahead" qoidasi (-10) va veto (joy yo'q) ko'radi - ikki marta sanalmaydi. Hakam matnida:
  `path to 4172.58 clear` yoki `path to ...: 1 obstacle(s), first 4168.20`.
- Yangi inputlar: `EnableContextDecay`, `ContextHalfLifeMin` 45, `EnableTargetPath`, `TargetPathObstaclePenalty` 4.

## 19-paket: panel - ekranga sig'adi, matn chegaradan chiqmaydi (2026-10-18)

Egasining skrinshoti bo'yicha. Kompilyatsiya (18-paket) egasida toza edi. Savdo mantiqi o'zgarmadi.

- **Matn panel chegarasidan chiqmaydi.** Satr kengligi endi harf soni bo'yicha taxmin qilinmaydi - MT5'ning o'zi
  (`TextGetSize`) piksel bilan o'lchaydi va panelga sig'magan qism "…" bilan qisqartiriladi. Pill (holat belgisi),
  ishonch va sifat chiziqlari ham o'lchov bilan joylashadi.
- **Windows masshtabi (125% / 150%)** hisobga olinadi: shrift kattalashsa, panel kengligi va qator balandligi ham shu
  nisbatda kattalashadi.
- **Ekranga sig'maslik:** yangi `PanelLayout` - 0 avtomatik (sukut), 1 to'liq, 2 ixcham. Avtomatik rejimda to'liq panel
  grafik balandligiga sig'masa, **ixcham ko'rinish** chiqadi: kapital, cashback, bozor nafasining asosiy qatorlari
  (sabab, qatlamlar, maydon, rejim, holat, ssenariy, hakam, likvidlik, nishon), zarba lahzasi, savat, eng so'nggi iz va
  yaqin xabar. Batafsil qatorlar (dalillar, TF, hikoya, tuzilma, zonalar, xarajat, joy va h.k.) jurnal va CSV'da qoladi.
  Grafik kattalashsa - o'zi to'liq ko'rinishga qaytadi.
- **Bo'sh qator** tuzatildi: sessiya darajalari va "Sessiya:" qatori bir xil nomli ob'ekt edi - biri ikkinchisini
  o'chirib, joy bo'sh qolardi.
- **O'ng yuqoridagi "SAF…" yozuvi va sariq chiziq** - eski sarlavha ramkasi o'ng burchakka noto'g'ri bog'langan edi va
  ekrandan chiqib kesilardi. Yangi panel yoqiq bo'lsa u chizilmaydi (bir xil ma'lumot); eski panelda to'g'ri joylashadi.
- **Max DD** 50% dan oshgan bo'lsa qator qizil rangda (avval faqat joriy DD rangni belgilardi).

## 18-paket: news fail-safe va bir nechta EA nusxasi (2026-10-18)

Manba: reja 15.6, 11-band (master reja XV va XVI.3). Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

**1. Kalendar ishlamasa - xavfsiz holat.**
- Avval: MT5 kalendari o'qilmasa, EA jurnalga "ko'r bo'lishi mumkin" deb yozardi va savdo davom etardi - yangilik
  oynasi umuman ishlamasdi.
- Endi: `CalendarBlindMinutes` (30 daqiqa) davomida kalendar bir marta ham o'qilmasa (ishga tushgandan beri yoki har
  yangilash xato bersa), **zaxira jadval** ishga tushadi: Nyu-York vaqti bilan ish kunlari 08:30 va 10:00, chorshanba
  kunlari 14:00 (FOMC). Shu vaqtlar atrofida (`EconomicCalendarPreMinutes` oldin, `EconomicCalendarPostMinutes` keyin)
  yangi kirish yo'q. Yozgi vaqt sessiya dvigatelidan olinadi.
- Ochiq savat bu taxminiy jadval bo'yicha **yopilmaydi** (news auto-flat faqat haqiqiy kalendar hodisasini ko'radi).
- Xato bo'lsa kalendar har 30 soniyada qayta o'qiladi. Jurnalda `[SIRUS CALENDAR] BLIND ...` va tiklanganda xabar.
- Inputlar: `EnableCalendarFailSafe` (yoqiq), `CalendarBlindMinutes` 30. Testerda kalendar ishlamaydi - u yerda
  o'zgarish yo'q.

**2. Bir nechta EA nusxasi (bir xil Magic + simvol, ikki grafik).**
- Avval: tekshiruv har tikda o'zining yurak urishini "boshqa nusxa" deb ko'rib, yolg'on ogohlantirardi; haqiqiy ikkinchi
  nusxa esa to'xtatilmasdi - ikkalasi bitta savatni boshqarib, qarama-qarshi order yuborishi mumkin edi.
- Endi yurak urishi egasining grafik ID'si bilan yoziladi. O'sha grafikda qayta ishga tushirish - o'sha ega (yolg'on
  signal yo'q). Boshqa grafik tirik egani topsa - **ikkinchi nusxa yangi kirish va grid ochmaydi**
  (`DuplicateInstanceBlockTrading`), chiqishlar ishlayveradi. Ega to'xtasa (OnDeinit kalitlarni bo'shatadi yoki yurak
  urishi 30 soniya eskiradi) - ikkinchi grafik egalikni oladi.

## 17-paket: ssenariylar natijasini o'lchash (2026-10-18)

Manba: reja 15.6, 10-band (Brain Architecture §5). Kompilyatsiya qilinmagan - statik tekshiruvlar toza.
**Faqat o'lchaydi** - hech bir qoida bu raqamlarni o'qimaydi (keyin, ma'lumot yig'ilgach qaror qilinadi).

- 20f har M1 barda ▲ / ▼ / chop ulushini, har birining maqsadini (champion likvidlik) va bekor bo'lish darajasini
  (himoyalangan daraja) hisoblaydi. Endi ustun ssenariy (ulush >= `ScenarioFeedbackMinShare` 55%, oldinda maqsad,
  ortda bekor darajasi bor) kuzatiladi.
- Har barda yopilgan M1 barning high/low'i bilan tekshiriladi: TARGET (maqsadga yetdi), INVALID (bekor darajasi
  o'tildi), TIMEOUT (`ScenarioFeedbackHours` 4 soat), FLIP (ustun tomon almashdi), BOTH (bitta bar ikkalasini oldi -
  tartib noma'lum, hisobga olinmaydi).
- Yangi CSV: `Sirus_Scenario_<symbol>_<magic>.csv` - ochilish/yopilish vaqti, tomon, ulush, bozor holati, boshlang'ich
  narx, maqsad, bekor darajasi, natija, daqiqalar, MFE / MAE, maqsadgacha va bekorgacha masofa.
- Panelda: "Ssenariy aniqligi (bugun): <65% x/y 65-74% x/y 75%+ x/y" - ulush yuqori bo'lsa ssenariy rostdan ham
  ko'proq to'g'ri chiqyaptimi, shu ko'rinadi. Jurnalda `[SIRUS SCENARIO] ...`.
- Yangi inputlar: `EnableScenarioFeedback` (yoqiq), `ScenarioFeedbackMinShare` 55, `ScenarioFeedbackHours` 4.

## 16-paket: Autopsy'ning 4 yangi toifasi + 3 ta kompilyator ogohlantirishi (2026-10-18)

Manba: master reja XVII.2. Kompilyatsiya: egasida 0 xato, 3 ogohlantirish edi - tuzatildi. Savdo mantiqi o'zgarmadi -
faqat yomon tugagan savatning sababi aniqroq yoziladi.

- **Ogohlantirishlar:** `G_TICK_COUNT` (ulong) uchta memo'da `int` ga saqlanardi (11 zona xaritasi, 20h hakam, 23
  raqobat). Endi `long`, aniq cast bilan.
- **NOTO'G'RI BOZOR HOLATI** - kirishda shu tomonga o'qilgan bozor holati (20f) savat davomida ag'darildi: holat
  qarama-qarshi tomonga o'tdi yoki SOXTA BREAKOUT bo'ldi.
- **IJRO XATOSI** - kirishdagi slippage bizga qarshi TP'ning 1/3 qismi yoki 2 normal spreaddan katta, to'ldirishdan
  oldin vaqtinchalik qayta urinish bo'lgan, yoki savat davomida grid orderi yuborilmagan.
- **CHIQISH XATOSI** - savat to'liq TP masofasida foydada bo'lgan, lekin baribir foydasiz tugagan.
- **RISK QOIDASI** - savatni risk qoidasi yopgan: basket SL, emergency, disaster SL, RISK, yangilik / dam olish
  oldidan yopish, broker stop-out.
- Yangi CSV: `Sirus_Autopsy3_<symbol>_<magic>.csv` - qo'shimcha ustunlar `state_entry`, `state_close`, `slip_pts`,
  `retries`, `grid_fails`, `exit_why`. Jurnal qatorida yopilish sababi, holat o'zgarishi va slippage.

## 15-paket: hakamning EXECUTE FAST va WAIT-FOR-LOCATION natijalari (2026-10-18)

Manba: master reja IX.4 (Entry Priority Judge) va IX.2 (har WAIT uchun qayta baholash sharti). Kompilyatsiya
qilinmagan - statik tekshiruvlar toza. Yo'nalish qoidalari o'zgarmadi: yangi natijalar faqat hakam allaqachon
yo'nalish va trigger topgan holatda ishlaydi.

- **EXECUTE FAST** (`MB_EO_EXECUTE_FAST`): hakam EXECUTE deydi va harakat HOZIR ketyapti (jonli displacement, LIVE
  sweep, hozirgina yopilgan M1 displacement), quvish yo'q, M5/M15 bosimi charchamagan. Order shu tikda ketadi:
  SmartFill pullback kutmaydi (`MBEntryFastFor`). Panelda "TEZKOR ZARBA".
- **WAIT-FOR-BETTER-LOCATION** (`MB_EO_WAIT_LOCATION`): yo'nalish va trigger bor, lekin JOY yo'q yoki narx qochgan
  (quvish, signal qochishi, range o'rtasi, hamma range'ning tepasi, oldinda qarshi zona). Yaxshiroq narx
  rejalashtiriladi - eng yaqini: signal paydo bo'lgan joy, narx ortidagi eng yaqin support / resistance, dealing range
  o'rtasi, aks holda yarim ATR(M5) pullback (0.25-2 ATR(M5) oralig'ida). Reja `MBWaitLocationMinutes` (15) daqiqa
  yashaydi.
  - Narx rejadagi DARAJAGA (support / resistance / range o'rtasi) yetsa - bu joy hisoblanadi.
  - Signal joyiga qaytish yoki oddiy pullback faqat quvish va qochish jarimasini olib tashlaydi (joy emas).
  - "Joy yo'q" holatida reja faqat haqiqiy daraja bo'lsa tuziladi - ko'r-ko'rona pullback joy hisoblanmaydi.
  - Panelda "JOY POYLANMOQDA" va narx-nishon.
- **Har WAIT qayta baholash sharti** (`G_MB_ENTRY_RECHECK`): "yopilgan M1/M5 sham shu tomonga", "zonada reaksiya
  shami", "tick oqimi qaytadi", "tasdiqlangan likvidlik burilishi", "pullback", "sifat N dan yuqori", "narx <= X
  (support) hh:mm gacha". Jurnalda `| recheck: ...`, panelda "qayta ochiladi: ...", rad etish sababida ham.
- Yangi inputlar: `EnableMBWaitForLocation` (yoqiq), `MBWaitLocationMinutes` 15, `MBWaitLocationMaxATR5` 2.0.
- Trace CSV ustunlari o'zgarmadi: `rule` ustunida endi `judge:better location: ...` ko'rinadi.

## 14-paket: sozlamalarni birlashtirish - egasining 5 qarori (2026-10-18)

Kompilyatsiya qilinmagan - statik tekshiruvlar toza (qavslar, ta'riflar, dublikatlar, o'zgaruvchilar, format).
Inputlar: 3066 -> ~2760. Kodda o'qilmaydigan input yo'q.

1. **Bitta xavfsizlik qatlami** (`SafetyLayerUpdate`, 10-fayl). P4Mini litsenziya/simvol/spread, P4Mini lot
   chegaralari, RC settings balance va Smart Client Safety o'rniga bitta qatlam:
   - simvol: faqat `SafetySymbolKeyword` ("XAU") bor simvolda savdo;
   - spread `MaxSpreadAllowed()` dan yuqori - yangi kirish ham, yangi pog'ona ham kutadi;
   - lot chegarasi: `SafetyMaxFirstLot` 0.25, `SafetyMaxGridLot` 1.00 (eski BALANCED profil qiymatlari, 0 = o'chiq);
   - DD >= 10%, pog'ona >= 4 yoki yuqori spread - grid masofasi x1.25, DD >= 16% - x1.65.
   - **O'zgarish:** eski ClientSafety DD'da pog'ona lotini x0.75 / x0.55 ga kesar edi (floor'dan KEYIN). Bu "pog'ona
     oldingisidan kichik bo'lmaydi" qoidasiga zid edi - olib tashlandi. Grid xavfini GLS (9-paket) hal qiladi.
   - RC faqat ogohlantirardi (strict o'chiq) va har skanda lotni qayta hisoblardi - olib tashlandi.
   - PresetHardening (koeffitsientlari doim 1.0) va hech qachon yangilanmaydigan "Stable RC" globallari olib tashlandi.
   - Panelda bitta `SAFE :` qatori.
2. **Bitta sessiya dvigateli (UTC + DST)** (`SessionUTCMinute` / `SessionServerMinute`, 10-fayl). Har sessiya
   chegarasi o'z shahri soatida bir marta yozilgan va avtomatik UTC'ga (Yevropa / Amerika yozgi vaqti), keyin broker
   vaqtiga o'tkaziladi. Asia (Tokio 09:00 -> Frankfurt ochilishi), Frankfurt, London 08-16, New York 08-16, NY killzone
   10-12 (NY), rollover 17:00 NY, NY midnight. 18 ta qat'iy soat inputi olib tashlandi (`Session*Hour`,
   `Legacy*StartHour`, `AsiaSession*`, `LondonNYSession*`, `NYKillzone*Hour`, `MBAsia*`, `NYOpenHour`).
   - Qishki qiymatlar UTC+0 serverdagi eski sukut qiymatlariga teng - qishda hech narsa siljimaydi.
   - Yozda: London, NY, killzone, rollover bir soat oldin (avval ba'zilari siljimasdi). Server UTC+0 bo'lmasa ham to'g'ri.
   - Transition guard va brain "ochilish oynasi" endi haqiqiy London ochilishini (08:00 London) oladi.
   - 12-paket Asia darajasi endi Frankfurt ochilishigacha (qishda 00-07 UTC, avval 00-06).
   - `SessionServerUTCOffset` 01-faylga ko'chdi (99 = avtomatik). Input auditi endi faqat noto'g'ri qo'lda offsetni aytadi.
3. **Bitta spread chegarasi.** 14 ta chegara o'rniga `MaxSpreadAllowed()` = `UnifiedMaxSpreadPoints` (Hunter rejimida
   x `HunterSpreadFactor`). `CleanSpreadPoints` - "toza spread" darajasi, `CriticalSpreadPoints` - score qattiq bloki.
   Sukut qiymatlarida xulq o'zgarmaydi (unified chegara oldin ham modul chegaralarini bosib o'tardi).
4. **Litsenziya qoldiqlari olib tashlandi:** V29 license guard, P4Mini litsenziya, `ReleaseBuildProfile`,
   `ReleaseRequireLicenseForClient`, rental ogohlantirishlari va bo'sh "(inactive)" guruhlar.
5. **Log kalitlari guruhlandi.** 217 ta `...PrintOnUse` / `Print...Events` endi 7 ta guruh inputining `#define`'i:
   `LogEntryEvents`, `LogGridEvents`, `LogExitEvents`, `LogRiskEvents`, `LogBrainEvents`, `LogSystemEvents` (yoqiq) va
   `LogDiagnostics` (o'chiq - sukut bo'yicha o'chiq bo'lgan 30 kalit shu yerda). Har kalitning sukut qiymati saqlandi.
   `VerboseLogs` / `TesterQuietLogs` asosiy kalit bo'lib qoladi; Trace / CSV yozuvchilar o'zgarmadi.

Eslatma: eski `.set` fayllaridagi olib tashlangan input nomlari terminal tomonidan e'tiborsiz qoldiriladi.

## 13-paket: input auditi (2026-10-18)

Hisobot: `docs/INPUT_AUDIT.md`. Master reja XVIII - inputlarning ma'nosi o'zgartirilmadi.
- 3066 input; kodda umuman o'qilmaydigani 0; 133 kalit sukut bo'yicha o'chiq; 66 input faqat o'chiq kalit ortida.
  Ko'plikning sababi - parallel oilalar (sessiya soatlari 5 to'plam, maksimal spread 14, birinchi lot 8, pog'ona 9).
- Rejimlar: Balanced / Hunter faqat eski skaner/score/grid masofasini o'zgartiradi; miya (17-26) rejimni o'qimaydi.
- Birlashtirildi: `RebateUSDPerLot` va `CashbackPerLot` (bir son, ikki input) - `CashbackUSDPerLot()`.
- Yangi: ishga tushishda `InputAuditReport()` - zid sozlamalar va egasining qoidalariga zidlar haqida ogohlantirish
  (cashback'da trailing, basket SL != 50%, NeverBelowPrevious o'chiq, kichik dollar hisob oddiy rejimda, server
  UTC+0 emas va qat'iy sessiya soatlari va h.k.). Faqat ogohlantiradi.
- Egasining qarori: cashback limit-order dvigatelidan voz kechildi (rejadan chiqarildi).

## 12-paket: sessiya darajalari likvidlik xaritasida (2026-10-18)

Manba: master reja VI.3 (Session Engine) va egasining "Asia, Frankfurt, London, NY, Midnight, broker vaqti, yozgi/qishki
vaqt" talabi. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

- Oxirgi YAKUNLANGAN Asia (00-06 UTC), Frankfurt (Frankfurt ochilishidan London ochilishigacha: 07-08 UTC, Yevropa yozida
  06-07) va London (08-16 UTC, yozda 07-15) sessiyalarining high/low'i likvidlik xaritasiga qo'shiladi (`LQ_SES`, sinfi
  H1 swing bilan teng). Sessiya tugagandan keyingi tarixi bilan: yopilish ortida = olingan (xaritaga kirmaydi), teshib
  qaytgan = sweep. Shunday qilib "Asia low sweep" - xaritaning oddiy sweep hodisasi: reversal, sweep kirishi, champion
  nishon, grid likvidlik tekshiruvi - hammasi uni ko'radi.
- New York midnight open (00:00 New York = 05:00 UTC, Amerika yozida 04:00) - panelda, narx ustida/ostida.
- Vaqt: UTC + Yevropa/Amerika yozgi vaqti (`IsEuropeanDST` / `IsAmericanDST`), keyin broker serveriga o'tkaziladi.
  `SessionServerUTCOffset` = 99: jonli hisobda server offseti avtomatik (TimeTradeServer - TimeGMT), testerda 0
  (Exness serveri UTC+0). Dam olish kunlari o'tkazib yuboriladi.
- Panel: "Sessiya: Asia 4120.50(toza)-4131.20(sweep) FRA ... LDN ... · midnight 4125.00 (ustida)".

## 11-paket: kirish nomzodlari raqobati (2026-10-17)

Manba: egasining umumiy arxitekturasi ("Entry Priority": BUY #1 = 91, SELL #1 = 38 ... eng yaxshisi) va reja 15.5 #1.
Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

- Miyaning tez kirish nomzodlari (re-entry, reversal, second chance, trend, handoff, pullback, sweep, range, momentum,
  local, aligned) KASKAD edi: birinchi o'tgani yutardi, qolganlari ko'rilmasdi - zaif BUY momentum yangi supply'dagi
  toza SELL sweep o'rnini egallashi mumkin edi.
- Endi har tikda O'TGAN barcha nomzodlar yig'iladi (har tomon va tur bir marta). Bittadan ko'p bo'lsa, har biri
  hakam tomonidan o'z tomoni va turi uchun baholanadi (sinov rejimi: hech narsa langarlanmaydi, o'rganilmaydi, print
  qilinmaydi) - eng yuqori sifat yutadi; EXECUTE bir xil sifatda CAUTION dan ustun; WAIT oladigan nomzod yutqazadi.
  Teng holatda eski tartib hal qiladi.
- G'olib sababi oxirida raqobat jadvali: "[won 3 candidates: SELL SWEEP_REJECTION q74 EXECUTE / BUY MOMENTUM_SCALP q52
  CAUTION / ...]" - DecisionLog orqali Trace CSV ga tushadi.
- Barcha darvozalar, veto va yakuniy hakam keyin baribir hal qiladi. `MBCandOk` javobi tik davomida saqlanadi (CPU).

## 10-paket: Zone Intelligence - RBR / DBR / RBD / DBD (2026-10-17)

Manba: egasining "Zone Intelligence & Supply/Demand Engine" rejasi. Yangi modul `Sirus/20i_Zone_Intelligence.mqh`.
Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

**Aniqlash** (M5, M15, H1, H4; faqat yopilgan barlar, har TF o'z yangi barida qayta quriladi - kelajak ma'lumoti yo'q):
- baza: 1-3 kichik sham (diapazon <= 0.8 ATR, tana <= diapazonning yarmi);
- chiqish: 3 sham ichida bazadan >= 1.5 ATR, birinchi sham haqiqiy tana bilan -> zona tomoni;
- kirish: bazadan oldingi 3 sham >= 0.5 ATR - rally yoki drop -> model RBR / DBR (demand), RBD / DBD (supply);
- chegaralar: proximal (narx birinchi tegadigan) va distal (yopilish shu ortida = buzildi), <= 1.5 ATR.

**Hayot bosqichi**: FRESH / TESTED / WEAKENED; BROKEN (distal ortida yopilish) va EXPIRED (M5 1 kun, M15 2 kun,
H1 10 kun, H4 30 kun) chiqarib tashlanadi. ID = TF + baza vaqti.

**100 ballik baho** (egasining vaznlari): kelib chiqish/impuls 20, likvidlik 20 (bazada sweep + chiqishda BOS),
struktura 20 (BOS + miyaning TF tuzilmasi), yangilik 15, shamlar 15 (chiqish tanasi + baza zichligi), joylashuv/ijro 10
(kenglik, spread). Boshlang'ich sozlama - trace va autopsy bilan tekshiriladi.

**Ishlatilishi** (o'zi hech qachon bloklamaydi):
- hakam: o'z tomonidagi zona (>= 60) - kirish joyi (zona-only bo'lsa reaksiya shami baribir kerak); >= 80 +5 sifat;
  oldinda YANGI qarshi zona (>= 80) - -10 sifat (CAUTION). HTF qattiq qoidasi 20g da qoladi.
- grid: "pog'ona strukturada" - avval o'z tomonidagi zona (>= 50), keyin swing daraja (faqat rol engine uni qarshi
  tomonniki demasa - buzilgan support BUY savat uchun joy emas), keyin FVG.
- panel: "Zona: DBR demand M15 ... 82/100 fresh | RBD supply ...".
- autopsy: yangi `zone` ustuni - yangi fayl nomi `Sirus_Autopsy2_<symbol>_<magic>.csv`.

**Egasining qarori**: `CashbackSizingRungs = 3` (cashback'da lot 3 pog'onali zinapoya uchun o'lchanadi).

## 9-paket: Grid Liability Score + cashback lot aylanmasi (2026-10-17)

**Grid Liability Score (reja XII.3, 15.6 #3)** - `MBGridLiabilityScore()`, 0-100, entry signalidan mustaqil:
chuqurlik 25 (ishlatilgan pog'onalar), DD 25 (basket SL ga nisbatan), margin 15 (300% -> 0, 150% -> to'liq),
BE masofasi 15 (H1 ATR'da, 2 ATR -> to'liq), bozor 20 (H1/H4 qarshi 7+7, M5 da qarshi yangi impuls 6).
- `GridLiabilityReserveScore` (60) dan: pog'ona zaxira darajasida tasdiqlanadi (struktura + charchagan qarshi harakat + javob).
- `GridLiabilityStrongScore` (80) dan: javob kuchli YOPILGAN burilish yoki yangi hodisa bo'lishi shart.
- Gridni muzlatmaydi: qutqarish kafolati (narx yetarli uzoqlashsa) bahodan ustun. Panelda "grid xavfi NN/100",
  savat yopilganda jurnalda eng yuqori qiymat.

**Cashback lot aylanmasi (egasi: kichik dollar hisob faqat cashback uchun)**
- `CashbackSizingRungs` (sukut 0 = to'liq zinapoya): N bo'lsa, lot N pog'onali zinapoya sig'adigan qilib o'lchanadi
  va savat N pog'onada to'xtaydi - kattaroq lot, ko'proq aylanma, kamroq qutqarish. Faqat cashback rejimida, lot
  StartLot / MaxLot dan oshmaydi. Egasining qaroriga qoldirildi.
- Asosiy rejaga egasining qoidalari yozildi (15.1).

## 8-paket: kichik hisoblar ($100 / 5000 USC), grid pog'onasi, ikkala rejimda to'liq miya (2026-10-17)

Egasining qarorlari: eng kichik hisob $100 (dollar) va 5000 USC (cent); pog'ona oldingisidan kichik bo'lsa - ko'r-ko'rona
qo'shish, kerak emas; oddiy rejim ham kerak va qaysi rejimda bo'lmasin miya to'liq ishlasin. Score qayta qurish - 1 kunlik
sinovdan keyin. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

**Kichik hisoblar (H-01)**
- Yagona `EntryBaseLot()`: rejim loti / AutoLot / StartLot -> MaxLot -> balans to'liq zinapoyani ko'taradigan lot -> agar
  minimal lot (0.01) ham to'liq zinapoyani ko'tarmasa: minimal lot, zinapoya esa qisqaradi (`AffordableRungCount`).
  Lot hech qachon kattalashmaydi.
- Ilgari: balansga moslangan lot Balanced/Hunter rejim loti bilan almashtirilardi, keyin ikki pastki chegara
  (StartLot x 1.0, StartLot x 0.80) har kirishni 0.20-0.25 ga qaytarardi. $100 da 50% SL 3-4-pog'onada urardi.
- Pastki chegaralar endi bazaviy lotdan. Grid progressiyasi (absolute floor, SZR, chuqurlik limiti, reach, projection,
  sozlama tekshiruvi) `BasketBaseLot()` dan - 0.01 lik savat pog'onalari 0.25 zinapoyaga ko'tarilmaydi.
- Misol ($100, XAUUSD, qadam 5500, x1.3): 0.01 lot, 4 pog'ona sig'adi ($40 < $50 byudjet), 5-pog'ona yo'q.
  Cent hisob: barcha hisoblar hisob valyutasida (USC) - chegaralar foiz/punktda, dollar-inputlar sukut bo'yicha 0.

**Grid pog'onasi (H-06)**
- `EnableGridNeverBelowPrevious = true`: pog'ona oldingisidan kichik bo'lmaydi. Ehtiyot signallari kichikroq lot so'rasa,
  pog'ona ushlab turiladi (yaxshiroq narx yoki signallar tozalanishi, 10 M1 bargacha) - mayda bo'lak qo'shilmaydi.
  Hisob himoyasi (margin rescue, qattiq cheklovlar) baribir keyin ishlaydi.

**Ikkala rejimda to'liq miya**
- Net edge (TP gacha to'siq) faqat cashback'da ishlardi - endi oddiy rejimda ham, o'sha rejimning birinchi TP'si bilan.
- Uzoq invalidatsiya (-10 sifat) cashback'da o'chiq edi - endi ikkala rejimda (grid xavfi aynan shu).
- H-08: oddiy rejimda runner broker TP'dan oldin ishga tushadi (broker TP'si yaqinroq bo'lsa arm nuqtasi uning 90% iga).

## 7-paket: auditdan qolgan topilmalar - score manbalari, zonalar, pul (2026-10-17)

Manba: `docs/audit_2026-10-17/`. Har topilma kodda qayta tekshirildi. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

**Score: eskirgan va takroriy manbalar**
- F7: legacy paketlar barcha bonus shiftlaridan KEYIN cheklovsiz bonus qo'shardi (Kalman H1, kunlar oldingi BOS,
  M1 sham rangi - ~9 ballgacha) va WAIT'ni PASS qilardi. Endi faqat dvigatel shifti ostidagi joyga va jami 3 balldan
  oshmaydi; jarima ham yagona shift bilan. Hakam yoqiq bo'lsa deep-parity HTF fikri = miyaning H1+H4 tuzilmasi;
  4 soatdan eski legacy BOS bonus bermaydi.
- F11 (1-raund S5): Kalman trend chegarasi 5 pt (oltinda $0.005/soat) - hech qachon "flat" emas edi. Endi kamida
  HTF ATR'ning 5% i (`KalmanTrendMinPts()`), bozor holati, MTF moslik va boshqa 7 o'quvchi uchun.
- F11/F14: ReversalConsensus eskirgan G_DBOS_DIR o'rniga miyaning M15 tuzilmasini o'qiydi (u HTF-qarshi tekshiruvni
  bekor qila olardi). Ambiguity jarimasi `LSDirEff()` ni o'qiydi.
- F9: bitta M15 shamni o'qiydigan bog'liq detektorlar "olomoni" endi daraja-setupni (range edge, sweep, zona
  reaksiyasi, soxta breakout, zona retest) bosib keta olmaydi va skanerni H1/H4 ko'proq qarshi tomonga burmaydi.

**Zonalar**
- G3: xona tekshiruvlari (V3, council 3, net edge) endi HAQIQIY eng yaqin darajani o'qiydi
  (`ZoneMapNearest*Plain`) - kuchli-zona almashtirish $20 gacha uzoqdagi darajani berib, TP'ni to'sadigan yaqin
  devorni yashirardi. Grid, TP, SZR o'zgarishsiz.
- G5: counter-zone - hech qachon ikkala tomon emas (narx qutida bo'lsa break hal qiladi). Input izohi tuzatildi.
- G6: H4/H1 zona M15 yopilishi bilan doimiy bo'shatiladi - break-and-retest BUY endi retestda rad etilmaydi.
- G8: counter-zone devori narx OLDIDA bo'lishi shart - orqadagi daraja keyingi yopilishda "o'tildi" deb tasdiqlanib,
  counter-zone'ni o'chirardi.
- G9: joylashuv qo'riqchisi rol engine "support (swept)" degan darajani BUY uchun "resistance" demaydi (redirect SELL
  ga aylantirishi mumkin edi).
- F19: zona-chegara armi faqat narx zona yonida bo'lsa (minglab pt uzoqdagi momentum BUY "reaksiya chegarasini" kutmaydi).

**Shamlar**
- E-7: sham bosimi sham hajmini hisobga oladi (mayda shamlar yopilish joyi bilan "bosim" yaratmaydi).
- E-8: "absorbed" holati faqat TREND itarishi yutilganda qarshi tomonni chaqiradi.
- E-12: qutqarish "sekinlashish" tekshiruvi endi `MBCandleConfirms` (hajm chegarasi + jonli bekor qilish).
- E-13: kirish shamidagi joy BID bilan o'lchanadi (BUY spread qadar jazolanardi).
- E-17: H1/H4 grid-xavfi ehtiyoti va V0 HTF pullback ochilishi uchun kuchli (yopilgan) trigger
  (`MBHasStrongTriggerNow`) - oddiy M1 davom shami yoki yopilmagan sham yetmaydi.

**Pul**
- H-07: cashback savat TP'si allaqachon to'langan swap'ni qo'shadi (`BasketCarryCostPoints`) - kechasi qolgan savat
  "+224 pt" da sof zararda yopilmaydi. Swap-free hisobda o'zgarish yo'q. Broker zaxira TP ham shu sondan.
- H-05: grid lot pastki chegarasi zinapoya shaklining multiplikatorini ishlatadi (1.30 o'rniga 1.20/1.22).

**Qoldi (egasining qarori kerak):** H-01 (balansga qarab lot, hisob hajmi), H-06 (`EnableGridNeverBelowPrevious`
o'chiq), H-08 (oddiy rejimda runner), F12 (mean-reversion bonuslari - dizayn), F13/F15/F16 (takroriy hisob -
katta qayta qurish), E-9/E-11/E-16/E-18, G7/G10-G13 (P3/P4).

## 6-paket: 2-raund audit topilmalari (shamlar, score, zonalar, pul) + order xatolari (2026-10-17)

Manba: `docs/audit_2026-10-17/` (E shamlar, F detektor/score, G zonalar, H pul). Har topilma kodda qayta
tekshirildi, faqat tasdiqlanganlari tuzatildi. Kompilyatsiya qilinmagan - statik tekshiruvlar toza.

**Noto'g'ri yo'nalish manbalari**
- F1: MARKET_PULLBACK yo'nalishsiz edi - "pullback continuation" detektori faqat trendga QARSHI tomonda
  ishlardi va ikkala tomon ham "+2 trend bilan" olardi. Endi PULLBACK o'z trendiga tegishli
  (`G_PULLBACK_TREND_DIR`, `MarketTrendSideNow()`): detektor, anti-overfilter bonusi va redirect shu tomonni o'qiydi.
- E-1: jonli sham "wick failed" ulush bilan o'lchanardi - pastga tushib keyin o'sgan shamda diapazon
  kattalashgani uchun "lower wick failed" (SELL sababi) chiqardi. Endi wick va tana NARXDA o'lchanadi.
- E-3: katta tuzoq shami FAKE_BREAKOUT bo'lib qolardi va V4, tezis tahdidi, grid to'xtashlari uni
  "qarshi displacement" deb ko'rmasdi. Displacement endi oldin tekshiriladi.
- E-4: `MBCandleConfirms` - wick shami uchun eng kichik diapazon (`MBTurnMinRangeATR` = 0.5 ATR); katta
  hammer / shooting star (ABSORPTION) endi burilish hisoblanadi.
- E-5: bitta yopilmagan M1 sham "joy", "trigger" va "reversal isboti" bo'lib uch marta sanalardi. Ikki
  qism talab qilinadigan qoidalarda endi bittasi yopilgan bo'lishi shart.
- E-6: "range edge rejected" yo'nalishni faqat wickdan olardi (tepada BUY). Endi chegara tomoni bilan bog'langan.
- G1: V2 "SELL hali support bo'lgan zona ostida" holatini ko'rmasdi (resistance ro'yxatida faqat swing
  high bor). Endi narx endigina teshgan o'z tomonidagi swing ham tekshiriladi (`MBPiercedOwnLevel`).
- F10: ruxsat berilgan trendga qarshi kirish `CounterContextBlockNow` dan erta chiqib, range-breakout
  fade va fresh-impulse tekshiruvlarini o'tkazib yuborardi. Endi trend bo'yicha kirish bilan bir xil.
- F6: jarima ikki joyda 10 ga qirqilardi - "objection headroom" (V287) va Hunter termini hech qachon
  ishlamasdi, ~9 bonusli har qanday setup o'tardi. Endi bitta shift: `ScorePenaltyCeiling()`.

**Sukunat (savdo soni) manbalari**
- F3: cashback rejimida spread/TP nisbati har doim ~1.6 (TP spreaddan quriladi) - skaner tomoni doim
  "spread torayishini kutish" armida turardi. Cashback'da spread endi soatning normal spreadi bilan solishtiriladi.
- F2: tasdiqlangan arm shu o'tishning o'zida qayta arm qilinardi - tasdiqlangan setup hech qachon chiqmasdi.
  Endi tasdiqlangan tomon shu barda qayta ushlanmaydi.
- F4: eskirgan arm (skaner jim bo'lganda) miyaning tez kirishini o'sha tomonda to'sardi. `ArmHoldsSide`
  endi arm oynasini tekshiradi (`SetupArmWindowBars`).
- F5: arm-WAIT redirectni ishga tushirib, qarama-qarshi tomonni simmetrik e'tirozlardan qochirardi. Arm
  ushlagan tomonda redirect yo'q.
- E-2: "qarshi itarish" armlari (impuls, bitta qarshi sham, qarshi bosim) EXTENDED tasdig'idan
  foydalanardi - itarish yana 600 pt ketgandan keyin tasdiqlanardi. Endi: itarish TO'XTADI va burildi.
- G2: V3 "joy yo'q" ikkala tomonni bir vaqtda to'sishi mumkin edi; 4+ marta tegilgan zona hali devor edi.
  Endi: hech qachon ikkala tomon emas (kam joyli tomon to'siladi), eskirgan zona devor emas.
- G4: narx orqasidagi swing FVG / PDH / PDL / raw zaxira darajalarini yashirardi va yangi cho'qqida V3
  breakout BUY'ni to'sardi. Tuzatildi.

**Pul va chiqish**
- H-04: Recovery Judge bitta reversal'ni ikki marta sanardi (tezis o'limi + 3-o'qish) - DD >= 45% da
  bitta fakt IMPOSSIBLE (zararda yopish) berardi. Endi 3-o'qish o'limdan yoki rescue'dan keyingi YANGI reversal'ni sanaydi.
- H-03: grid chuqurlik limiti cashback'da 672 pt qadam bilan hisoblanardi (haqiqiysi ~5500) - limit
  hech qachon ishlamasdi. Endi grid dvigateli bilan bir xil min/max qadam.

**Order xatolari (reja X.4)**
- Rad etilgan entry / grid order Trace CSV'ga `FAILED` qatori bo'lib yoziladi (retcode, tavsif, lot, narx).
- TIMEOUT / CONNECTION javobidan keyin order to'lgan bo'lishi mumkin: qayta yuborishdan oldin pozitsiyalar
  va deal tarixi tekshiriladi (`AmbiguousSendFilled`), to'lgan bo'lsa ikkinchi order yuborilmaydi.

**Keyingi paketga qoldirildi (egasining qarori yoki katta o'zgarish kerak):** F7 legacy paketlar
(cheksiz bonuslar), F9/F11 score'dagi ~25 yo'nalish termini hakamni o'qimaydi, G3 kuchli-zona almashtirish,
G5 counter-zone 3500 pt, G6 HTF zona buzilishi, H-01 balansga qarab lot (hisob hajmi kerak), H-07 swap
(hisob swap-free'mi?), E-7..E-18 va F13..F21 (P3/P4).

## 5-paket: struktura, zonalar, sham-yo'nalish izchilligi (2026-10-10)

**Struktura (BOS / MSS)**
- B-F1 (ildizidan): hodisa dvigateli MSS belgisini endi oxirgi HAQIQIY break'ga qarab qo'yadi (failed
  break'lar o'tkazib yuboriladi). Avval G_MB_TREND bo'yicha qo'yardi - likvidlik olish (failed break)
  uni ham almashtirgani uchun keyingi haqiqiy break "MSS" bo'lib qolardi va lock, reversal bosqichlari,
  TF holati yo'q trend o'zgarishini o'qirdi.
- B-F2: struktura xotirasi (run / quality) endi MBBreakFailed bilan bir xil 2 barlik testni ishlatadi -
  keyingi ikki yopilishdan biri qaytsa - failed; ikkinchi bar ham ushlasa - tasdiqlangan.
- B-F3: himoya darajasi (protected high/low) faqat VALID+ break'dan olinadi; break failed bo'lsa oldingi
  daraja qaytariladi. Avval stop-run'dan keyin oddiy pullback "M5 struktura buzildi" deb o'qilardi
  (council 1e va lokal qatlam strukturani yo'qotardi).
- B-F11: hodisa halqasida har TF ning eng yangi 3 ta BOS/MSS hodisasi saqlanadi - shovqin (sweep,
  displacement, rejection...) struktura egasini siqib chiqarmaydi.

**Zonalar**
- ZoneMap support qidiruvi resistance qidiruvi kabi tartiblandi: narx OSTIDAGI daraja ustun; narxdan
  yuqoridagi swing faqat ostida hech narsa bo'lmaganda. Avval yuqoridagi swing haqiqiy supportni bosib
  ketardi - SELL uchun V3 "joy yo'q" va grid reach bozor ustiga qarab nishonga olardi.

**Holat va tomon**
- B-F5: market state EXPANSION tomoni endi bozor HARAKAT qilayotgan tomon (jonli M1 displacement, M5
  bosimi); STRONG_TREND faqat bias rejim bilan bir tomonda; TREND tomoni avval bias. Judge sifati endi
  eskirgan tomonga +4, harakat tomoniga -8 bermaydi.
- Detektorlar teng kelganda tomon: avval Brain bias (hakam ko'rgan), keyin kunlik bias, keyin eski HTF.
- Kunlik bias "gap" chegarasi: kamida 2 spread va kunlik ATR ning 5% i (100 punkt spreadning yarmidan kam edi).
- Deep HTF paketidagi "M15 tasdiqlaydi" endi Brain'ning M15 STRUKTURASI (avval diapazon chetida teskari
  o'ynash - trendda teskari ma'no).

## 4-paket: darhol reaksiya va broker tomonidagi zaxira himoya (2026-10-10)

**Darhol reaksiya (OnTradeTransaction)**
- Basket broker tomonidan yopilsa (TP, zaxira SL, stop-out), EA keyingi tickni kutmaydi: shu zahoti
  bitta to'liq qaror o'tkazadi - Position Brain yopilishni yozadi va signal bo'lsa yangi basket darhol
  ochiladi (TP'dan keyin darhol qayta kirish qoidasi). Ko'p orderli basketda - oxirgi order yopilgach.
- Broker SL / stop-out bo'lsa jurnalga "[SIRUS BROKER CLOSE]" yoziladi. Input: EnableTradeEventReaction=true.

**Broker tomonidagi zaxira himoya (EA yoki VPS o'chiq bo'lsa ham ishlaydi)**
- Disaster SL: har bir pozitsiyaga butun basket zarari balansning BrokerDisasterSLPercent (60%) iga
  yetadigan narx yoziladi. EA ning o'z stoplaridan (50% / 52%) kamida 5% uzoqda - EA ishlayotganda hech
  qachon tegmaydi. Foydadagi trailing SL doim undan qattiqroq va uni almashtiradi; disaster SL trailing
  SL ni hech qachon bo'shatmaydi.
- Basket TP (faqat cashback rejimi, 2+ order): har bir orderga basket TP narxi (+50 punkt) yoziladi -
  EA ishlayotganda u o'z maqsadida birinchi yopadi, o'chiq bo'lsa broker yopadi. Avval grid orderlarida
  TP yo'q edi va EA o'chiq bo'lsa ko'p orderli basket hech qachon foydada yopilmasdi.
- Throttle 5 s; SL 20 punkt, TP 60 punkt farq bo'lsagina o'zgartiriladi.
- Inputlar: EnableBrokerDisasterSL=true, BrokerDisasterSLPercent=60, EnableBrokerBasketTP=true.

## 3-paket: tozalash va kichik holat xatolari (2026-10-10)

**O'lik kod olib tashlandi (hech qachon chaqirilmagan - asl faylda ham)**
- Location Guard'ning "rad etishlar soni / swing darajasi" qismi (LGScan, LGLiveLevel, LGSwingLevel) va
  faqat ular o'qigan 15 ta input (LGLookbackM5/M15, LGMinRejections, LGSwingGuard ...). Ularning vazifasini
  hozir council 3, V2/V3, net edge, HTF zona (1h), lower high (1g) bajaradi.
- Grid level snap (GridPreferredAddPrice + 4 input): xuddi shu ishni V137 "grid reach"
  (GridZoneAwareDistance) allaqachon qiladi - yoqilsa ikki marta surilardi.
- Yana 13 ta chaqirilmaydigan funksiya (DeepRecovery/RegimeTune grid sozlashlari, eski hisobot
  yordamchilari, MBStructDamage, ...), RegimePerfMinSamples va HTFZonePrintOnUse inputlari.
- Doim false qaytaradigan shoxlar: valve (clarity / scenario / failed break), evidence-gate ilgaklari
  yo'nalish qoidalarida (taken / exhaustion / late / zone front / V2-V3 / V5), MBOwnsGate shadow valve.
- Natija: kodda birorta ham chaqirilmaydigan funksiya qolmadi (skript bilan tekshirildi).

**Holat xatolari**
- Hodisa yoshi endi savdo vaqtida: dam olish kunlari (shanba+yakshanba) hodisani "qaritmaydi" - dushanba
  ertalab juma strukturasi, sweep va zonalari eskirgan hisoblanmaydi.
- Chart symboli almashtirilsa EA eski symbol xotirasi bilan savdo qilmaydi: jurnalga sabab yozib to'xtaydi
  ("EA ni yangi symbolga qayta qo'ying").
- CandleHTFAgreement: shakllanayotgan M15 sham faqat yopilgan shamning kamida yarmicha kattalikka yetganda
  hisobga olinadi (birinchi ticklardagi 2 punktlik "kuchli sham" endi yo'q).
- Late guard: narx bar ichida maqsaddan o'tib ketsa - oyoq "yetib kelgan" (100%), "kech emas" (0%) emas.

## 2-paket: zanjir tartibi, holat, grid, struktura ta'riflari (2026-10-10)

**Yo'nalish filtrlari o'zi bo'shashmaydi (egasi qoidasi)**
- Counter-trend rad etishning 180 bar jimlikdan keyingi "valve"i olib tashlandi (08).
- Safety valve endi HTF bias darvozasini o'chira olmaydi (14). 1-paketdagi CSV tasnifi tuzatilgach bu
  valve haqiqatan ishlay boshlagan bo'lardi - yopildi.
- v180 valve endi xavfsizlik bloklarini (chaos, juda katta spread, eskirgan tick, ENV) ochmaydi - faqat jurnalga yozadi.

**Holat (state)**
- Har skanerda (~3 s) basket holatini nollaydigan blok 4 ta reset funksiyasidan olib tashlandi
  (05/08/09). Natija: adverse-streak, DD tezlanishi va MaxDailyGridAttempts endi haqiqatan ishlaydi
  (grid intellekti chuqur DD da ehtiyotkorroq). Grid hisoblagichlari endi risk kuni bilan nollanadi.
- Skaner snapshoti endi kirish kontekstini ham saqlaydi (counter-trend bayrog'i, ogohlantirish og'irligi,
  situation) - keyingi tickda eskirgan kontekst bilan kirish yo'q.

**Statistika**
- Broker TP bilan yopilgan basketlar ham o'rganish statistikasiga yoziladi (Bayes, score band, regime,
  streak, EV, setup turi, evidence tighten). Avval faqat EA yopganlari (asosan zararlar) yozilardi -
  statistika zararga og'ib, kirishlar va lot keraksiz qisqarardi.

**Grid**
- Rescue kafolati endi news, shock, chaos va katta spread paytida grid qo'shmaydi (bu holatlar daqiqalarda
  o'tadi, keyin rescue davom etadi). "Sekinlashdi" uchun jonli M1 sham qarshi displacement qilmasligi ham shart.
- Post-loss cooldown va kunlik kirish urinishlari limiti endi faqat YANGI kirishni to'xtatadi - ochiq
  basketning gridi muzlamaydi. Kunlik grid limiti faqat gridga ta'sir qiladi.
- Scale-in tugallovchi order birinchi qismning broker TP'si bilan yuboriladi; birinchi qism yopilgan
  bo'lsa yoki TP yetib qolgan bo'lsa - yuborilmaydi ("yetim basket" yo'q).

**Struktura ta'riflari birlashtirildi**
- Failed break (likvidlik olish) endi hech qayerda tasdiq emas: reversal tasdig'i, V1 javobi va
  tasdig'i, o'lik tezis "lift"i, qarama-qarshilik og'irligi.
- Likvidlik xaritasi sweep'i hodisa dvigateli bilan bir xil: daraja TF ATR'ining MBSweepMaxATR dan
  chuqur teshish - sweep emas, qaytgan break.
- Eski M5 "staircase" (G_LS_DIR) Brain M5 strukturasiga zid bo'lsa score'ga ovoz bermaydi (sinishdan
  keyin eski tomonni rag'batlantirish yo'q).

**Boshqa**
- Location redirect SmartFill kutganda keyingi tickda rad etilmaydi (bir barda bir marta faqat muvaffaqiyatsiz urinish uchun).
- AdaptDecay soati oxirgi o'zgarishdan hisoblanadi (birinchi qattiqlashuv darhol qaytmaydi).

## Strategy Tester moslashuvi (2026-10-10)

Faqat testerga ta'sir qiladi (jonli savdo o'zgarmaydi). Batafsil: docs/audit_2026-10-09/T_tester.md.
- Jurnal toshqini: vizual bo'lmagan testda batafsil loglar o'chadi (yangi input TesterQuietLogs=true).
  ENV va MODE loglari endi spread har o'zgarganda emas, holat o'zgarganda yoziladi (jonli rejimda ham shovqin kamaydi).
- Setup Doctor testerda "terminal ulanmagan" deb hamma kirishni to'smaydi.
- Testerda (vizual bo'lmagan) chart obyektlari chizilmaydi: TP/SL chiziqlari, premium visual, yopilish markerlari.
- ATR handle keshi 12 -> 32 (12 ta to'la edi - bitta TF o'zgarsa indikator har safar qayta yaratilardi).
- Tick-velocity guard testerda kompyuter soatini emas, tickning o'z vaqtini (time_msc) o'lchaydi.
- Testerda OnTimer o'tkazib yuboriladi (har tick allaqachon himoyani bajaradi; kuniga 86 400 ortiqcha o'tish edi).
- DXY proxy testerda o'chiq (yangi input TesterUseDXYProxy=false) - test 3 ta qo'shimcha symbolni modellamaydi.

## 1-paket: yo'nalish hakami, xavfli 4 xato, qaror izi (2026-10-10)

Audit (AUDIT_2026-10-09.md) asosida. Yo'nalish filtrlari o'zi bo'shashmaydi.

**Yo'nalish hakami (yangi fayl 20h_Direction_Arbiter.mqh, to'liq yoqilgan)**
- Avval yo'nalishni faqat M15 hal qilardi (H1/H4 faqat ishonchga ±6..10). TP (~224 pt) M1 ATR'dan kichik,
  grid qadami (~5500 pt) ≈ 1 H1 ATR - shuning uchun: H1/H4 = grid xavfi, M15 = tomon, M5/M1 = vaqt.
- TAQIQ: H1 va H4 ikkalasi qarshi (biri barqaror) va H1/H4/KEY likvidlik reversali yo'q; yoki biri qarshi va
  H1 + M15 bosimi hali qarshi itaryapti.
- EHTIYOT: biri qarshi (yoki ikkalasi, lekin reversal / o'z HTF zonasi + M15 burilgan) - M5 struktura yoki
  lokal oyoq + trigger kerak.
- M15 o'rta qatlam: H1+H4 trendida M15 ning kuchsiz qarshi harakati (-1/-2) pullback - M5/lokal qaytib,
  trigger bo'lsa trend tomoni ruxsat (V0 va MBDirOk). M15 kuchli qarshi (-3) bo'lsa - yo'q.
- Veto zanjirida "VH" (V11 dan keyin, V0 dan oldin). Panelda yangi qator: "Hakam: H4 · H1 · M15 · M5 | BUY · SELL".
- Eski HTF o'quvchilari (Kalman H1 lot x0.6, trend guard x0.4, grid "HTF-against") hakamga ulandi:
  lot faqat H1+H4 ikkalasi qarshi bo'lganda kesiladi; x0.4 takrori o'chdi; grid bahosi H1/H4 dan.

**Xavfli xatolar**
- B-F6: BRAIN RANGE kirishi va judge "range edge" faqat quti ICHIDA (tashqarida = breakout, unga qarshi kirish yo'q).
- A1: ARM (tasdiq kutayotgan setup) WAIT'ini legacy paketlar, missed-memory va expired-block endi PASS'ga aylantira olmaydi.
- A2: navbat (queue) replay hard block ustidan, shu tomonning yangi WAIT'i yoki ARM'i ustidan ishlamaydi.
- D-01: evidence gate score'ni faqat kamomad <= 2 ball bo'lsa chetlab o'tadi.
- B-F1: failed break trendni almashtirgani uchun haqiqiy break MSS deb belgilanib, trend TRANSITION'da
  qotib qolardi - endi MSS faqat oldingi haqiqiy struktura teskari bo'lsa.

**O'lchov**
- Yangi fayl 26d_Trace.mqh: MQL5\Files\Sirus_Trace_<symbol>_<magic>.csv - har qaror: aniq qoida (VH, V0, V8,
  council...), H4/H1/M15/M5 holati, hakam hukmi, ARM, skanerdan keyin qaysi qadam qarorni o'zgartirgani
  (legacy/queue/memory/expiry/redirect...), tickdagi relief/evidence/fast qadamlari. Savdoga ta'siri yo'q.
- Shadow CSV "extra" ustuni: rule=... h4= h1= m15=.
- GateClassify: hard block, clarity, failed break, old level va HTF bias endi "score" deb yozilmaydi
  (evidence gates toza ma'lumotdan o'rganadi).

## Yaxlit zanjir tuzatishlari (2026-10-09)

Butun qaror zanjiri (scanner → fast path → kandidatlar → veto → judge) bir paketda tekshirildi va
bir-biriga zid joylar tuzatildi. Hech qaysi yo'nalish filtri o'zi bo'shashmaydi.

**Noto'g'ri yo'nalishga qarshi (teshiklar yopildi)**
- R1 (20): "yangi impuls" lokal yo'nalishni faqat M5 bosimi va lokal tezis unga qarshi bo'lmaganda belgilaydi.
- R2 (20b): MBM5StructDir eski 1-barlik test bilan "neytral" qaytarmaydi - singan breaklar 2-barlik test bilan.
- R10 (20b): singan break (likvidlik olish) struktura emas - reversal MSS, lock va stage hisobidan chiqarildi.
- R3/R8 (21): yangi HTF break "ushlab turibdi" chegarasi 0.3 ATR; shu tomonga yangi M5 break bo'lsa 1f to'smaydi.
- R4 (21): 1g (lower high) qoidasida stage<3 istisnosi olib tashlandi.
- R5/F4 (20g): HTF zonalar 3 yopiq bardan topiladi; ikki tomonda zona bo'lsa katta TF hal qiladi, teng TF - bir-birini bekor qiladi.
- R9 (20g): lower high faqat lenta undan qaytganda - lokal oyoq va M5 bosimi shu tomonga bo'lsa to'smaydi.
- R6 (20): RANGE qutisida spike bar (TR > 2x ATR) bo'lsa chegaralar oxirgi 8 M15 bardan olinadi.
- R7 (20c): "kech" maqsadi allaqachon olingan (sweep qilingan) quti chetini o'tkazib yuboradi.
- F10 (21, V0): miya neytral, lekin HTF trend qarshi bo'lsa - M5 struktura, lokal oyoq, unlock-stage reversal yoki range cheti talab qilinadi.

**Jimlik / qulf (deadlock) tuzatishlari**
- F1 (20b): stage 3 deadlock - MSS qilingan, M5 struktura burilgan va narx MSS ortida bo'lsa lock to'smaydi.
- F2 (21): council 3-qoida (zona oldida) ikki tomonni birdan to'smaydi.
- F3 (14): unlock-stage'ga yetgan REVERSAL o'z joyiga ega - eski location/HTF guardlar uni "trendga qarshi" deb o'qimaydi.
- F5 (14): veto rad etadigan detector PASS endi slotni band qilmaydi - miya QARAMA-QARSHI tomonni ko'ra oladi.
- F6 (23): kandidat tekshiruvi to'liq veto (V1-V5 ham) bilan, probe sifatida (hisob va log yo'q) - birinchi kandidat qolganlarini yashirmaydi.
- F7 (08/14): yo'nalishli HARD_BLOCK (counter-context, blow-off, devor) faqat o'sha tomonni to'sadi - miya boshqa tomonni olishi mumkin. Xavfsizlik hard blocklari (chaos, spread, eski tick) o'zgarmadi.
- F8 (14): shu tomonda qurollangan (armed) setup tasdiq kutayotgan bo'lsa, fast path navbatdan oldin kirmaydi.

## HTF supply/demand zonalari + M15 past tepa / baland tub qoidasi; "joy" filtrlari endi hech qachon bo'shamaydi (09-Oct 08:33 BUY 4196.811)

- **Holat.**
  - 06:00 da 4207.98 dagi tepa olindi (supply), 08:18 da undan past tepa 4201.6 chiqdi.
  - 08:33 da BUY ochildi. Narx H1 dealing range ning 77% ida edi, ya'ni egasi chizgan H4 supply (4180–4228) ichida.
  - Keyin narx 4183 gacha tushdi va savat gridga bordi.
- **Sabablar.**
  - **Dalil darvozalari "joy" filtrlarini ham bo'shatib qo'ygan.** Panelda "bias tomoni bo'sh: ball, o…" ko'rindi. Bu xato edi. Joy, oldidagi zona, olingan likvidlik, kech va charchash sifat bali emas, ular yo'nalish xavfi.
  - **Robotda kengligi bor supply/demand zonalari yo'q edi**, faqat alohida swing darajalari bor edi.
  - **M15 da "past tepa" (tuzilma burilishi) o'qilmasdi.**
- **1. Dalil darvozalari toraytirildi.** Endi faqat ball, hakam sifati, drift va TP joyi bo'shashi mumkin. Joy oilasi, oldidagi zona, olingan likvidlik, kech va charchash o'lchanadi, lekin doim ishlaydi.
- **2. Yangi modul `20g_HTF_Zones.mqh`.**
  - **HTF zonalar.** Zona — H1 yoki H4 da kuchli harakat boshlangan asos sham.
    - Shart: keyingi 3 bar ichida narx 1.5 ATR uzoqlashgan va shamning ekstremumini buzgan.
    - Zona narx uning narigi chetidan tashqarida yopilmaguncha yangi hisoblanadi. 3 marta tegilgandan keyin eskiradi.
    - Hisoblash har H1 barda bir marta.
  - **Kengash 1h.**
    - Yangi supply ichida yoki undan 1 ATR(M15) gacha pastda BUY yo'q. M15 zonadan yuqorida yopilmaguncha shunday.
    - Demand uchun ham xuddi shunday, SELL ga nisbatan.
  - **Kengash 1g: past tepa.**
    - Oxirgi 6 soatdagi M15 tepasidan keyin haqiqiy pullback (≥ 0.8 ATR15) va past tepa (≥ 0.3 ATR15 past) bo'lsa, premium tomonda BUY yo'q. Oxirgi M5 past tepadan yuqorida yopilmaguncha shunday.
    - Baland tub uchun ham xuddi shunday: discount tomonda SELL yo'q.
    - Hisoblash har M5 barda bir marta.
  - Ikkalasi ham yo'nalish qoidasi, dalil darvozalari ularni hech qachon bo'shatmaydi.
  - 08:33 dagi BUY ikkala qoida bilan ham to'silardi:
    - past tepa 4201.6 tepa 4207.98 ostida edi;
    - narx 4207 dagi H1 supply asosi ostida edi.
- **Panel.** `HTF zona: supply H1 x-y · demand H4 x-y · past tepa z`
- **Sozlamalar** ("BRAIN ▸ HTF zones & structure"):
  - `EnableHTFZones`;
  - `HTFZoneDispATR` = 1.5;
  - `HTFZoneApproachATR15` = 1.0;
  - `HTFZoneMaxTouches` = 3;
  - `EnableLowerHighRule`.

## DALIL DARVOZALARI: har bir sifat filtri o'z o'rnini robotning o'z raqamlari bilan isbotlaydi (TEMPO va TP ga asoslangan soya klapani o'rniga)

- **Asl sabab** (egasining soya fayllari, 06–09-Oct, 2065 setup).
  - TP ~224 punkt, grid qadami ~5500 punkt. Shuning uchun deyarli har qanday kirish TP ga yetadi: olinganlar 90%, to'silganlar 91%.
  - Kirishlarni bir-biridan ajratadigan yagona narsa: savat **gridga borganmi**.
  - Gridga borganlar ulushi:
    - olingan savdolar: 10.4%;
    - ball to'sganlar: 7.1%;
    - miya veto'si to'sganlar, bias tomonida: 7.1%;
    - miya veto'si to'sganlar, biasga qarshi: 16.1%.
  - Xulosa: ko'p sifat filtrlari savdo sonini o'n barobar kamaytiradi, lekin sifatni oshirmaydi. Biasga qarshi yo'nalish veto'si esa haqiqatan yomon kirishlarni to'xtatadi.
- **Yangi modul `26c_Evidence_Gates.mqh`.**
  - Har bir sifat filtri bo'yicha to'siqlarning qancha qismi gridga borgani yuritiladi. Bias tomoni va biasga qarshi tomon alohida hisoblanadi, natija olingan savdolar bilan solishtiriladi.
  - Filtrlar: ball, hakam, joy oilasi, drift, kech, olingan likvidlik, charchash, oldidagi zona, TP joyi (net edge).
  - Qaror:
    - to'silganlar olinganlardan ko'p gridga bormasa, filtr o'sha tomonda bo'shaydi;
    - +3 foiz punkt ko'p borsa, filtr qaytadi;
    - har tomonda kamida 30 natija bo'lmaguncha filtr ishlaydi.
  - Bo'shatilgan filtr ham o'lchanishda davom etadi: u o'tkazib yuborgan har bir kirishning natijasi uning namunasiga qo'shiladi.
  - Charchash filtri hech qachon to'liq o'chmaydi: faqat +15 bal joy beriladi. Olingan likvidlik filtri daraja ostidagi/ustidagi 0.5 ATR(M5) burilish zonasini doim to'sadi.
- **Hech qachon bo'shamaydi:**
  - V0, LOCK, kengashning tuzilma qoidalari, V1, V4;
  - yangilik, spread, risk, anomaliya;
  - o'lgan g'oyadan keyin qayta kirish.
- **Xavfsizlik.**
  - Bozor noodatiy bo'lsa, hech narsa bo'shamaydi: yangilik oynasi, tezlik pauzasi, anomaliya yoki spread odatiydan 1.5 barobar katta.
  - Circuit breaker: bo'sh filtr bilan ochilgan oxirgi 4 savatdan 2 tasi gridga borsa, barcha yumshatish 60 daqiqaga to'xtaydi.
  - Hisoblar terminal o'zgaruvchilarida saqlanadi, shuning uchun qayta ishga tushganda yo'qolmaydi. 300 natijadan keyin ikkiga bo'linadi, ya'ni eski dalil asta-sekin so'nadi.
- **Boshlang'ich dalil.** Birinchi ishga tushishda egasining fayllaridan olinadi, har hisob 60 natijagacha kichraytiriladi. Faqat bias tomonidagi ball filtri bo'shab boshlaydi (7.7% / 12.2%). Qolganlari yo yomonroq, yo hali isbotlanmagan.
- **Hook'lar:**
  - ball WAIT → PASS, lekin veto va hakam baribir hal qiladi; shu tomonda qurollangan setup bo'lsa, o'zi kutadi;
  - hakam chegaralari −10;
  - eski joy oilasi;
  - drift;
  - V8: kech, olingan likvidlik, charchash;
  - V5;
  - V2/V3 va kengashning 3-qoidasi;
  - V10 net edge.
  - Tick ichida eslab qolingan kengash va xarajat natijalari ham bo'sh filtr belgisini to'g'ri uzatadi.
- **Olib tashlangan, chunki noto'g'ri edi:**
  - TP % ga asoslangan soya klapani (`EnableShadowValve`, `ShadowValveMinutes`, `ShadowValveMinSamples`). TP % kirishlarni ajratmaydi.
  - TEMPO (`EnableTempoValve` va `Tempo*`) — dalil darvozalari uni almashtiradi.
- **Tuzatilgan.** Soya CSV faylidagi `brain_bias` endi yozilgan paytdagi bias, natija aniqlangan paytdagisi emas.
- **Panel.**
  - "Soya" qatori endi gridga borish ulushini ko'rsatadi.
  - Yangi qator: `Filtr dalili (olingan gridga X%): bias tomoni bo'sh: … · qarshi bo'sh: …`. Breaker ishlaganda `yumshatish to'xtatildi`, bozor noodatiy bo'lsa `bozor noodatiy` yoziladi.
- **Jurnal.**
  - `[SIRUS EVIDENCE] <filtr> (<tomon>): STANDS ASIDE / WORKS AGAIN …`
  - `[SIRUS EVIDENCE] BREAKER …`
- **Sozlamalar** ("BRAIN ▸ Evidence gates"):
  - `EnableEvidenceGates`;
  - `EGMinSamples` = 30;
  - `EGBaseBadRate` = 0.10;
  - `EGKeepMargin` = 0.03;
  - `EGBreakerGridBaskets` = 2;
  - `EGBreakerMinutes` = 60;
  - `EGSeedFromOwnerFiles`.

## AQLLI TEMPO: faqat kerak bo'lganda va bozor ruxsat berganda yoqiladi, o'z savatlari yomonlashsa o'zi o'chadi

Bu bo'lim avvalgi "TEMPO doimiy" o'zgarishini almashtiradi. Egasi: doim yoqiq bo'lishi katta zararga olib kirishi mumkin.

- **Yoqilish sharti.** To'rttasi birga bajarilishi kerak:
  1. **Bozor.**
     - Yangilik oynasi, tezlik pauzasi va anomaliya yo'q.
     - Spread shu soatning odatiy darajasi × 1.5 dan oshmaydi.
     - Bozor yomonlashsa, TEMPO "yoqiq" turgan bo'lsa ham hech narsani yumshatmaydi.
  2. **Ehtiyoj.** `TempoQuietMinutes` (10) daqiqa savat va kirish bo'lmagan.
  3. **Dalil.**
     - Faqat yo'nalish jihatidan xavfsiz tomondagi to'silgan setuplar hisobga olinadi: global biasga va buzilmagan M5 tuzilmasiga qarshi bo'lmaganlar.
     - Ular oxirgi kamida 10 ta natijada **toza** bo'lgan bo'lishi kerak: TP ga 1500 punktdan chuqur qarshi harakatsiz yetgan.
     - Toza ulushi kamida 72% bo'lishi va olingan savdolarnikidan kamida 3 foiz punkt yuqori bo'lishi kerak.
     - Egasining fayllarida: olingan savdolar 69% toza, to'silgan xavfsiz setuplar 76%.
  4. **Circuit breaker o'chiq.**
- **Nima yumshaydi.**
  - Faqat xavfsiz tomon uchun: ball, hakam, joy, "kech", olingan likvidlik, drift.
  - Soya klapani orqali yumshatish ham faqat xavfsiz tomonga beriladi.
  - Muddat: 20 daqiqa.
- **Circuit breaker.**
  - TEMPO bilan ochilgan savatlar alohida kuzatiladi.
  - Oxirgi 4 tadan 2 tasi grid talab qilsa, TEMPO 60 daqiqaga o'chadi.
  - Panelda `TEMPO to'xtatildi N daq (sabab)` ko'rinadi, jurnalga `[SIRUS TEMPO] BREAKER` yoziladi.
- **Hech qachon yumshamaydi:** yo'nalish ruxsati, LOCK, kengash (uchlik, 1e, 1f), V1, yangilik, spread, risk.
- **Sozlamalar:**
  - `TempoQuietMinutes` = 10;
  - `TempoMinRefusals` = 10;
  - `TempoCleanMAEPts` = 1500;
  - `TempoMinCleanRate` = 0.72;
  - `TempoCleanEdge` = 0.03;
  - `TempoMinutes` = 20;
  - `TempoBreakerGridBaskets` = 2;
  - `TempoBreakerMinutes` = 60.
- **Tezlik.** Har tickda bir necha taqqoslash. Dalil soya natijasi aniqlanganda yangilanadi.

## TEMPO doimiy (egasining soya fayllari asosida: 06–09-Oct, 2065 setup)

- **Soyani to'g'ri o'qish.** TP taxminan 224 punkt, grid qadami taxminan 5500 punkt. Bunday nisbatda tasodifiy kirish ham taxminan 96% hollarda TP ga yetadi. Shuning uchun "TP %" sifat ko'rsatkichi emas. Haqiqiy farqni ikki narsa ko'rsatadi: GRID (grid kerak bo'lgan hollar) ulushi va 2000 punktdan chuqur qarshi harakat ulushi.
- **Natijalar (GRID ulushi / chuqur MAE ulushi):**
  - olingan savdolar: 10.4% / 21.6%;
  - to'silgan, bias tomonida: 6.5% / 18.0%;
  - to'silgan, biasga qarshi: 8.5% / 21.5%;
  - miya veto'si, biasga qarshi: 16.1% / 26.9%. Bu yo'nalish veto'sining haqiqatan yomon kirishlarni to'xtatayotganini ko'rsatadi, u o'z joyida qoladi.
  - ball, bias tomonida: 6.4% / 16.8%;
  - miya veto'si, bias tomonida: 7.1% / 19.1%.
  - drift, biasga qarshi: TP 66.7%, timeout 22.2%. Yomon kirishlarni to'xtatadi, qoladi.
- **Xulosa.** Yo'nalish jihatidan xavfsiz tomonda vaqt va sifat filtrlari olingan savdolardan yaxshiroq setuplarni to'symoqda. Ular savdo sonini kamaytiryapti, sifatni esa oshirmayapti.
- **O'zgarish.** `TempoQuietMinutes` = 0, ya'ni TEMPO doim yoqiq. Panelda `⚡ TEMPO doim` ko'rinadi.
  - Yo'nalish himoyalari o'zgarmaydi: V0, LOCK, kengash (uchlik, 1e, 1f), V1, yangilik, spread, risk, anomaliya.
  - Biasga qarshi tomonda drift va boshqa filtrlar avvalgidek ishlaydi.
  - Eski shartli rejimga qaytish uchun `TempoQuietMinutes` = 15 qo'ying.

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
