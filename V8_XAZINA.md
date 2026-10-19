# V8 XAZINASI — V9 ga nima olinadi, nima qoladi, nima takrorlanmaydi

To'rt manbadan saralandi:
1. bozorni o'qish kodi (17, 18, 19, 20, 20a, 20b, 20c, 20d, 20g, 20i, 04/05/10/11 zona bo'limlari);
2. ijro, xavfsizlik va jurnal kodi (03, 06, 09, 10, 11, 12, 13, 14, 20e, 26, 26b, 26d, 28, .mq5);
3. kod izohlari (FIX / AUDIT FIX / live loss / OWNER RULE) va CHANGELOG, AUDIT, TUZATISH_REJASI;
4. egasining dizayn hujjatlari (6 ta .txt) va YANGI_ENGINE_REJASI.

V8 kodiga tegilmadi. Fayl manzillari `fayl:qator` ko'rinishida, `Sirus/` ichidan.

**Natija:**
- olinadigan algoritm va qismlar — 60+;
- universal saboqlar — 54;
- egasining qat'iy qoidalari — 25;
- takrorlanmaydigan tuzoqlar — 30;
- poydevordagi ziddiyatlar — 10 ta (bo'lim 6 da hal qilingan);
- ochiq qarorlar — 7 ta (3-bosqichda).

---

## 1. Egasining qat'iy qoidalari (V9 da so'zma-so'z)

| # | Qoida | Manba |
|---|---|---|
| Q1 | Hedge yo'q: bir vaqtda bitta basket, faqat hedging hisob. REVERSE va REDUCE (qisman yopish) yo'q | YER §7, 27:128, 13:1704 |
| Q2 | Grid pog'onasi oldingisidan **hech qachon kichik emas**. Margin sig'masa pog'ona rad etiladi, kichraytirilmaydi | 13:1511, 14:604, pkg 8/26 |
| Q3 | Tasdiqsiz pog'ona yo'q. Kutish faqat tasdiq darajasini pasaytiradi: kamida qarshi harakat to'xtagan bo'lishi kerak | 13:1792, 24:1188 |
| Q4 | Grid qutqaruvchi, **muzlab qolmaydi**. "Muzlash" deganda chiqish yo'li yo'q to'xtash tushuniladi | 13:1740 |
| Q5 | TP dan keyin darhol re-entry (OnTradeTransaction), lekin bozor har safar qayta baholanadi | mq5:1428, 20d:280 |
| Q6 | Cashback: TP qat'iy, trailing yo'q. Trailing va runner faqat normal rejimda | 26d:177 |
| Q7 | Basket SL 50% — oxirgi to'r | TUZATISH #2 |
| Q8 | Yo'nalish darvozalari jimlik sababli o'z-o'zidan bo'shamaydi | 08:1523, pkg 1/2/26 |
| Q9 | "Qayerda" filtrlari (joy, oldidagi zona, olingan likvidlik, kech, charchash) dalil darvozasi yoki tempo bilan yumshatilmaydi | 26c:79 |
| Q10 | BUY joyida BUY, SELL joyida SELL: ikki tomon ham savdo qilinadi | pkg 28 |
| Q11 | Avval shamlar: zonaga yetish kirish sababi emas | 23:858 |
| Q12 | Uch qavat: H1/H4 = risk, lokal (M5) = yo'nalish, M1 = vaqt. Mikro tomonni yolg'iz tanlamaydi | pkg 38 |
| Q13 | Filtrlar savdo ko'payishi uchun o'chirilmaydi. Ular dalil bilan muvofiqlashtiriladi | pkg 40/41 |
| Q14 | Butun miya ikkala rejimda ham ishlaydi | pkg 8 |
| Q15 | Basket o'zi ochilgan rejimda yopiladi | pkg 25, 03:289 |
| Q16 | Bitta spread chegarasi, bitta yangilik egasi, bitta xavfsizlik qatlami | pkg 14 |
| Q17 | Impuls oxirida shu tomonga yangi savdo yo'q (SELL impulsining tubida SELL ochilmaydi). Katta shamdan keyin darhol kirilmaydi | 01:5988, 04:518 |
| Q18 | Global trend bilan savdo DD vaqtini qisqartiradi | 01:5755 |
| Q19 | TEMPO hech qachon doim yoqiq emas. Yumshatish faqat shartli, faqat xavfsiz tomonda va o'chirgich bilan | AQLLI TEMPO |
| Q20 | Kichik dollar hisob ($100) — faqat cashback; cent hisob $50 dan. "Kattaroq lot + qisqaroq zina" | pkg 8/9/10/13 |
| Q21 | Kuniga 250–450 savdo, lekin noto'g'ri yo'nalishga kirmasdan. Veto tor bo'ladi va faqat kuchli qarshi dalilda ishlaydi | YER §7 |
| Q22 | FXStreet / WebRequest yo'q, MT5 kalendari yetadi | YER |
| Q23 | Og'ir hisob faqat yangi barda yoki hodisada | YER |
| Q24 | Kodni tushunmasdan modul qo'shilmaydi, ko'r yamoq yo'q, har xato regressiya testiga aylanadi, kelajakka qarash (look-ahead) yo'q | CBA XXII |
| Q25 | Panel: bitta ustun; watermark shamlar orqasida, vertikal markazda, Bahnschrift; HOLAT NAZORATI bloki doim ko'rinadi | pkg 22–24 |

---

## 2. Qatlam bo'yicha olinadiganlar

### 10 HODISALAR

| Qism | V8 manba | Nega olinadi (saboq) | Konstantalar |
|---|---|---|---|
| Bitta swing qoidasi | 18:343 | Kelajakka qaramaydi, ko'pchilik modul shuni ishlatadi. Yangi tomonda qat'iy, eski tomonda ≥ | len 3 (M1), 2 (M5–H4); teng cho'qqilar 0.15 ATR ichida birlashadi |
| BOS / MSS | 18:587 | MSS oxirgi **haqiqiy** struktura bilan solishtiriladi, soxta break aylantirgan bayroq bilan emas. Aks holda qatorlarning 59% i "TRANSITION" bo'lib qolgan | 0.05 ATR; sweep dan keyin MSS ×1.5 |
| Soxta break | 20:148, 20b:186–235 | 08-Okt 19:40 da zarar: 4128 dagi grab BOS deb o'qilib, rally o'rtasida SELL ochilgan | 2 yopilish ichida 0.1 ATR qaytsa — SOXTA; KUTILMOQDA holati bor |
| Break sifati | 20b:148 | HIMOYAni faqat VALID va undan yuqori break siljitadi | tana < 0.3 ATR WEAK, ≥ 0.8 STRONG |
| Sweep / fake / reclaim / acceptance | 18:444 | Sweep va break farqi | teshish ≥ max(0.1 ATR, spread), ≤ 1.0 ATR; acceptance = 3 yopilish ≥ 0.25 ATR |
| Displacement | 17:301 | Displacement fake'dan **oldin** tekshiriladi. Aks holda eng kuchli burilish shami yo'qolardi | tana ≥ 1.2 ATR, ≥ 0.6 diapazon, yopilish chekka 25% da |
| Hodisa ombori | 18 | Yosh savdo vaqtida o'lchanadi (dam olish kuni hisoblanmaydi). Vaqt **bar yopilishidan** olinadi. Startda tarix qayta o'ynaladi | TF ga 40 ta; 3 ta eng yangi BOS himoyalangan |
| Jonli (tick) sweep | 18:1060 | Tezlik: yopilishni kutmasdan | teshish ≥ 0.15 ATR(M1); reclaim 45 s; amal qilish 120 s |
| Sifat shkalasi | T4157 | Faqat wick bo'lsa MSS emas; kichik tana — kuchsiz; yopilish — haqiqiy; displacement bilan — kuchli; davomi bo'lsa — tasdiqlangan | — |

### 20 LIKVIDLIK

| Qism | V8 manba | Nega | Konstantalar |
|---|---|---|---|
| Likvidlik xaritasi | 20a | Bitta xarita. TF niqobi sinfni beradi: LOCAL → EXTREME | 0.2 ATR(M15) ichida birlashadi; oyna max(8 ATR M15, 4 ATR H1) |
| Holatlar | 20a:355 | FRESH → PARTIAL → SWEPT → RESWEPT → TAKEN | TAKEN = 2 ta M5 yopilish |
| TRAP | 20a:412 | Sweep dan keyin 1 soat ichida acceptance bo'lsa — bu davom etish, burilish emas | 3600 s |
| Sessiya darajalari | 20a:225, 10:3027 | Asia / Frankfurt / London / NY midnight, DST bilan | — |
| Maqsad tanlash | 20a:550 | Oldinda, buzilmagan, sinf ≥ 2 | — |
| Champion (DOL zaxirasi) | 20a:524 | sinf × yosh / masofa | yosh: 1.0 / 0.8 / 0.6 |
| Muvaffaqiyatsiz hujumlar = kuch | 10:5109 (V246) | 4492–4494 bandi ikki marta buzilib, ikki marta qaytarib olindi | ATR ga o'tkaziladi |
| Bandning yaqin chekkasi | 11:37 (V245) | BUY ning $2.50 maqsadi bandga $0.65 qolganida tiqilib qolgan | — |
| Yumaloq sonlar xx00 / xx50, EQH / EQL | CBA VI.3 | Hovuz manbai | — |

### 30 OYOQ

| Qism | V8 manba | Nega | Konstantalar |
|---|---|---|---|
| HIMOYA | 20b:150 | Buzilgan swing va buzgan bar orasidagi chekka nuqta. Soxta breakda oldingi HIMOYA tiklanadi | — |
| SINDI testi | 20b:100, 20:1157 | Struktura buzilmaguncha qarshi sham — bu pullback | 0.15 ATR(M5) chiqish |
| Breaklar seriyasi | 20b:55 | To'lqin va IMPULS turi | — |
| Impuls dvigateli | 17:407 | To'lqinlar va tezlik. 62% qaytarilgan yoki origindan o'tgan impuls tugagan hisoblanadi (6-Okt 19:18 dagi 18 daqiqalik jimlik shundan) | EARLY < 1.5 < NORMAL < 2.5 < LATE < 4 ATR |
| Reversal bosqichlari 1–6 | 20b:408 | 4157.88 dagi BUY juda erta olingan, 4070 dagi haqiqiy burilish o'tkazib yuborilgan. Sweep ekstremumidan orqaga yopilish = TRAP (0-bosqich) | retest 0.35 ATR; higher low ≥ 0.2 ATR |
| Charchash bosimi | 20c:144 | V9 origin bilan qayta hisoblanadi. Data: ≥ 60 da 25% grid | og'irliklar 20 / 20 / 20 / 15 / 15 / 10 |
| Olingan likvidlik = TUGADI | 20c:242 | Maqsad bajarilgan | xotira: diapazonda 15 daqiqa, trendda 60 |
| Qaytish sinflari | T4157 | Shovqin < 20%, pullback 20–45%, zaiflash 45–60%, > 60% + mikro break = burilish ehtimoli | — |
| Cho'zilgan oxirida kirmaslik | 27:89 | BUY 4177.4 | 8 ta M5 da ≥ 1.8 ATR (HTF bilan 3.0) |
| Kech + bias'ga qarshi | pkg 50 | Tester: oyoqning 80% idan keyin grid 11–15%, oldin 5% | — |
| Hujumdagi trend | 21 | 08-Okt 16:00 BUY: 2 ta qarshi M5 break bo'lsa, trend tomonga kirish yo'q | — |
| Yangi M15/H1 BOS ushlab turibdi | 21 | 08-Okt 22:20 SELL breakout retestini sotgan: 60 daqiqa teskari tomonga kirilmaydi | — |

### 40 XARITA

| Qism | V8 manba | Nega | Konstantalar |
|---|---|---|---|
| 7 holatli TF holati | 20:324 | BULLISH … TRANSITION … BEARISH; WEAK holati | bosim farqi ≥ 20 |
| Tasdiqlangan burilish | 20:224 | M5+ sweep M5+ tasdiq talab qiladi | — |
| HTF devorlari (zonalar) | 20g:80 + 20i:106 → bitta detektor | 09-Okt 08:33 BUY 4196.8 egasi chizgan H4 supply ichida ochilgan | baza + 3 bar ichida ≥ 1.5 ATR; kenglik 0.2–1.5 ATR; 3 tashrifdan keyin eskiradi |
| Zona roli tarixdan | 19:127 | 4125 support sweep qilingan, "resistance" deb o'qilgan, 4126 dan SELL ochilgan | ±0.30 ATR(M5); 3 yopilish = yangi rol |
| Zona chegarasi | pkg 28 | Zanjirlangan darajalar bitta $70 "support" ga aylanib, 4130 dan yuqorida hamma SELL ni bloklagan | ≤ 2.5 ATR(M5) |
| Ikki pog'ona yuqoriga qarash | V232/V250 | "H1 aldandi, H4 buzilmadi"; H4 double top ichidagi support — bu neckline retest | — |
| HTF sweep vetosi | YER §12.4 (4126 holati) | Yangi H1/H4 SSL sweep + reclaim bo'lsa, DOL gacha discount da SELL yo'q | — |
| Premium / discount | YER §12.2 | Premium da BUY faqat yangi qarama-qarshi likvidlik + MSS bilan | — |

### 50 QADAM

| Qism | V8 manba | Nega | Konstantalar |
|---|---|---|---|
| Sham niyati klassifikatori | 17:241 | Tekshirish tartibi muhim: grab → displacement → fake → absorption → rejection → … | wick ≥ 0.5; real tana ≥ 0.3 ATR |
| Bosim | 17:367 | Bar o'lchami bilan tortiladi: tushayotgan lentada kichik bar "BUY bosimi" emas (E-7) | 30 / 20 / 20 / 15 / 10 / 5 |
| Burilish shami tasdig'i | 17:648 | Jonli narx dalilni bekor qiladi: ekstremumi olinsa yoki 0.5 ATR qaytarilsa (A1) | diapazon ≥ 0.5 ATR |
| Shakllanayotgan M1 displacement | 17:542 | Tezlik, yopilishni kutmaslik | tana ≥ 0.8 ATR |
| Mikro nazorat | 20d:107 | **Bitta** chegara to'plami (V8 da 5 xil edi) | — |
| Qarshi va burilish kirishlari | pkg 43 | 13:34 BUY 4163.0 pichoq ushlash: oxirgi yopilgan M1 kirish tomonida bo'lishi va shakllanayotgan bar qarshi yurmasligi shart | — |
| Signal tez eskiradi | pkg 44 | Tez zarba 3 s, M1 momentum 0.25 ATR qaytarilsa tugaydi | — |
| Bitta yopilmagan sham uch rolni o'ynay olmaydi | E-3 / E-5 | Joy + trigger + dalil: kamida bittasi yopilgan bo'lishi kerak | — |
| Muvaffaqiyatsiz davom | 10:1359 (V239) | 4435 dagi BUY zarari | — |

### 60 O'LCHOV

| Qism | V8 manba | Nega |
|---|---|---|
| Ehtimol jadvali infratuzilmasi | 28:138 | FILE_COMMON; TESTER_ fayli live da faqat o'qiladi; rejimlar alohida |
| To'g'ri o'lchov | pkg 37/41 | TP ≪ grid qadami bo'lsa, TP% hech narsa demaydi (tasodifiy kirish ~96% TP). O'lchov: "grid kerak bo'ldimi" + chuqur MAE |
| Broker TP g'alabalari ham hisobga | pkg 2, 24:728 | Aks holda statistika zararga og'adi |
| O'tkazib yuborilgan g'alabalar | T4157 §19 | Filtr savdoni o'ldiryaptimi — o'lchanadi |
| **O'lchov faqat blok QO'SHADI** | Q8 / Q9 | Yo'nalish va "qayerda" vetolarini hech qachon yumshatmaydi |

### 70 SHARTNOMA (saboqlar; qoidalar 3-bosqichda)

- Kirish uchun uchta mustaqil toifa kerak: **YO'NALISH + JOY + TRIGGER**. Bitta sabab bilan kirilmaydi (NEW §12).
- **Yo'nalish ≠ kirish.** 4081 SELL misoli: yo'nalish 85, joy 32 → BLOK.
- Score hech qachon qat'iy vetoni bekor qilmaydi. Ustuvorlik: fakt > kontekst > imkoniyat.
- Qarshi va reversal kirishlar ko'proq dalil talab qiladi (counter-trend solig'i).
- Re-entry: savdo yopildi ≠ tezis o'ldi. Chiqish sababi yo'lni belgilaydi. Zarar yoki o'lik tezisdan keyin yangi M5+ dalil kerak. Bitta g'oyada 3 marta muvaffaqiyatsiz bo'lsa, o'sha tomon yopiladi. Cooldown **hodisaga** bog'langan, vaqtga emas.
- Pog'onadan oldin yo'nalish qayta tekshiriladi. Ketayotgan harakat ichiga qo'shilmaydi (pkg 45: qutqaruv pichoq ushlayotgan edi).
- Qutqara olmaydigan pog'ona qo'yilmaydi: BE toza HTF MAJOR ortida qolsa yoki SL gacha oz qolgan bo'lsa.
- Basketning tezisi va bekor bo'lish narxi ochilishda yoziladi (live: 4470 / 4484 SELL lar).
- Basket harakatini ko'rsatishi kerak: 20 daqiqada TP ning 35% i. BE pul hisobida (swap + komissiya).
- Net edge = kutilgan harakat − spread − komissiya. **Cashback savdo sababi emas** ($5.5/lot faqat ma'lumot uchun).
- Bitta qarorda bitta eng yaxshi nomzod. Bozor NOMA'LUM bo'lsa — savdo yo'q.

### 80 XAVFSIZLIK

| Qism | V8 manba | Nega | Konstantalar |
|---|---|---|---|
| Bitta favqulodda stop | 12:800 | Mustaqil to'r: real > 50% basket yopilmay qolgandan keyin yozilgan | 52%, swap + komissiya bilan |
| Kapital pog'onalari spreaddan oldin | 14:372 | Keng spread stoplarni jim qilib qo'ygan | — |
| Equity = 0 himoyasi | 10:298 | Reconnect paytidagi 0 qiymati 100% DD emas | — |
| Komissiya DD ichida | 10:162 | — | — |
| Margin oldindan tekshiruvi | 14:635, 13:1224 | Bitta qabul / rad hukmiga birlashtiriladi | ≥ 200%, basket ≤ 60% |
| Spread xotirasi | 20e:35 | Soat bo'yicha, login bilan. 3× sakrash o'rganilmaydi; ketma-ket 30 ta bo'lsa — yangi normal | anomal = 2× |
| Anomaliya | 20f:133 | Spread 2.5×, 4 ATR lik M1 bar yoki tick sakrashi → 5 daqiqa kirish yo'q | — |
| Kalendar | 11:4924 | `ArraySize` bilan o'qiladi (bool emas — pkg 26 gacha deyarli ishlamagan). Ko'r qolganda fail-safe 08:30 / 10:00 NY, chorshanba 14:00. Auto-flat event ID bo'yicha va faqat foydada | 15 / 15 daqiqa, HIGH |
| Sessiya / DST soati | 10:3010 | Dam olish kuni qo'riqchisi shunga asoslanadi (qat'iy server soatiga emas) | — |
| Dublikat nusxa | 13:1142 | chart ID + heartbeat | 5 s / 30 s |
| Velocity qo'riqchisi | 11:2007 | 16:41 dagi 23 daqiqalik jimlik: endi adaptiv | 400 p VA 1.5 ATR(M1) |
| Miya tayyor emas → KUT | 27:112 | Start paytida ATR va tarix yo'q | — |

### 90 IJRO

| Qism | V8 manba | Nega |
|---|---|---|
| Yuborildi ≠ bajarildi | 13:1699, 14:4839 | Retcode tekshiriladi; qisman to'ldirilganda real hajm olinadi. **Bitta** yuborish funksiyasi kirish va pog'ona uchun |
| Yo'qolgan javob | 11:4676 | TIMEOUT dan keyin qayta yuborishdan oldin pozitsiyalar tekshiriladi (aks holda pozitsiya ikki baravar bo'lardi) |
| Basketni yopish + qayta urinish | 12:1020 | 3 o'tish, keng deviation ($3), yangi kotirovka |
| Qoldiq qulfi | 12:1148 | Yopilmay qolgan qoldiq ustiga yangi zina qurilmaydi. Restart dan keyin ham saqlanadi |
| Broker tomoni himoyasi | 12:1369, 12:1457 | EA offline bo'lsa ham: har orderda TP, disaster SL, trailing qulfi real SL sifatida, faqat qattiqlashadi |
| Narxni tick o'lchamiga moslash, TP ni stop / freeze darajasigacha kengaytirish | 14:1206, 14:1360 | Savdo bekor qilinmaydi |
| Hajm normalizatsiyasi | 14:698 | Riskni kamaytirishda pastga, pog'ona qoidasida (Q2) yuqoriga yaxlitlanadi |
| Hisob turini aniqlash | 13:1704 | Netting hisobda yangi risk ochilmaydi |
| OnTradeTransaction | mq5:1428 | Broker TP → darhol yangi qaror (Q5) |
| Har basket tugashini deal tarixidan yozish | 24:728 | — |
| Restartdan keyin tiklash | 24:131 | Kalit = birinchi pozitsiyaning **POSITION_IDENTIFIER** (ochilish vaqti emas) |
| Rejim basketga qotiriladi | 03:289 | Q15 |
| Handlerlar | mq5 | INIT da savdo yo'q; OnTimer faqat soat ishi; OnDeinit tartibi; tester: Sleep, kalendar va dublikat qo'riqchisi yo'q |

### 95 PANEL va 99 JURNAL

- **Panel:** faqat tekshirilgan qiymatlar ko'rsatiladi: balans/equity, bugungi net, DD, ekspozitsiya, holat, yo'nalish sabablari, risk holati, rejim, oxirgi signal va rad sababi, qutqaruv holati (CBA XVII).
- **Har savdoga sabab kodi.** Har WAIT yoki BLOCK o'z sababini aytadi.
- **Trace CSV** (26d), **Autopsy CSV** (26b, IJRO XATOSI qoidasi bilan), **profiler** (26).

---

## 3. Tashlanadiganlar

| Nima | Nega |
|---|---|
| G_MB_BIAS kompoziti, MBLayerLocal, lokal tezis, handoff | Bir-biriga zid yamoqlar to'plami; o'rniga oyoq + xarita |
| Market Brain tezis obyekti | Oyoq hayot sikli bilan almashadi (faqat 0.15 ATR bufer qoladi) |
| Alohida yo'nalish qulfi (20b:332) | Oyoq + xarita ichida "tasdiqlangan IMPULS" bo'ladi |
| G_LX_ORIGIN (6 soat), MBLxTargetAhead | Origin va maqsad takrorlari |
| 20f bozor holati, ssenariylar, narrativ | Faqat boshqa qatlamlarni qayta o'qiydi (anomaliya qismi 80 ga ko'chadi) |
| 11 zona xaritasi (7 TF), ZoneMapStrength, polarity flip, zona charchashi | 20a / 19 takrori. Bir-biriga zid (V141 ↔ V200 ↔ V265). Stack overflow (V203) |
| FVG, sham patternlari (05), tick flow / tick volume | Isbotlanmagan. Dalil chiqsa O'lchov orqali qaytadi |
| MarketStructureRead, LocalStructureUpdate, MoveExtensionATR | Takror. LocalStructureUpdate swinglarni tartibsiz juftlaydi (04:2651) |
| Skaner, redirect, navbat, legacy / deep / Pack paketlari | Faqat durangda tomon tanlash uchun ishlatilgan |
| 15 lot sozlagichi, margin rescue lot | Oxirida hammasi bekor qilinardi |
| SmartFill, rental stagger, scale-in, qisman yopish bosqichlari | Vaqt Qadam ishi; scale-in xatolar manbai; qisman yopish zararni realizatsiya qiladi |
| Rebate trailing, Pack2 trailing, runner trailing alohida | Q6. Normal rejimda **bitta** qulf egasi bo'ladi (Shartnoma) |
| Server disaster SL, Smart Early Exit, Deep Exit va boshqa ~50% stoplar | 7 ta ustma-ust stop o'rniga bitta |
| Qo'lda bayram ro'yxati, manual news CSV, ModuleHealth, Bayes / score restore | Eskiradi yoki foydasiz |

V8 git'da to'liq qoladi. Biror qism kerakligiga dalil chiqsa, qaytariladi.

---

## 4. Takrorlanmaydigan tuzoqlar

**Bozorni o'qishda:**

1. Trend bayrog'i soxta breaklar bilan almashardi. V9 da break CONFIRMED bo'lgunicha faqat hodisa.
2. Maqsad yo'q bo'lsa oyoq % = 0 qaytardi. Hovuzlar 3 ATR(M5) bilan kesilgan edi.
3. Shakllanayotgan bar ekstremumlarga qo'shilardi. Struktura faqat yopilgan barlardan olinadi; jonli EKSTREMUM alohida yuritiladi.
4. Swing qoidalari 3 xil edi (>=, >, ikkala tomon qat'iy). Chuqurlik ham har xil. V9 da **bitta** qoida.
5. "Teshish" va "olindi" tushunchalari 4–5 xil ta'riflangan edi. V9 da **bitta** ta'rif.
6. Hodisa vaqti bar ochilishi deb olinardi. V9 da yopilish vaqti bir marta saqlanadi.
7. Faqat oxirgi breakning davomi tekshirilardi. V9 da har break uchun alohida kutilayotgan yozuv.
8. O'lim chizig'i yoki maqsad noto'g'ri tomonda chiqardi. Maqsad qat'iy oldinda, o'lim chizig'i qat'iy orqada, minimal masofa bilan.
9. O'qiydigan funksiyalar holatni o'zgartirardi (20g:177). V9 o'quvchilari toza.
10. Bar yopilishi va tick aralashardi. Har chiqishda qaysi biri ekani yoziladi.
11. Spread o'lchamidagi barlar signal deb olinardi. Minimal o'lcham ATR da.
12. Birliklar aralashgan edi (qat'iy punktlar, bid/ask asimmetriyasi). Hammasi ATR ga o'tkaziladi.
13. Mikro nazoratda 5 xil chegara bor edi. V9 da bitta.
14. Xotiralar chegarasiz edi. Har xotiraga muddat va aniq ochilish sharti beriladi.
15. Zona kuchi qo'shimcha ballar to'plami bo'lib, o'ziga zid edi. O'lchovsiz ball qo'shilmaydi.
16. Kalit darajadagi breaklar soxtalikka tekshirilmasdi. V9 da hammasi tekshiriladi.

**Ijroda:**

17. 7 ta ustma-ust ~50% stop bor edi; hisob darajasidagi stop basket SL dan oldin ishlab qolardi.
18. Margin trimini pog'ona qoidasi qayta ko'tarib, bekor qilib qo'yardi. V9: lot bir marta hisoblanadi, keyin bitta "sig'adi / sig'maydi" hukmi.
19. Pack2 va Pack3 har tickda ikki marta ishlardi.
20. Faqat qattiqlashadigan broker SL runnerni erta yopardi. V9 da bitta qulf egasi.
21. Timer eskirgan kotirovkada yopish yuborardi.
22. Qutqaruv qat'iy bloklar ustidan sakrab o'tardi.
23. Gridda qisman to'ldirish yozilmasdi.
24. Bitta CTrade obyektida deviation 50 ↔ 3000 almashtirilardi. V9 da kirish va chiqish uchun alohida obyektlar.
25. Basket yo'nalishi eskirgan o'zgaruvchidan olinardi. V9 da orderning o'zidan olinadi.
26. Tiklash tester uchun himoyalanmagan edi; kalit prefikslari aralash edi.
27. Ikki xil xayoliy hisob bor edi. V9 da bitta.
28. Dam olish kuni qat'iy server soatiga bog'langan edi. V9 da sessiya soati.
29. Kalendar bool natijasi son deb o'qilardi.
30. Yuborish va hisob yozish orasida `return` bor edi.

---

## 5. Hisoblash

| | Soni |
|---|---|
| Olinadigan algoritm va qismlar | 60+ |
| Universal saboqlar | 54 |
| Egasining qoidalari | 25 |
| Tuzoqlar | 30 |
| Tashlanadigan guruhlar | 14 |

---

## 6. Poydevordagi tuzatishlar (egasining hujjatlari bilan ziddiyatlar hal qilindi)

| # | Ziddiyat | V9 dagi yechim |
|---|---|---|
| Z1 | POYDEVOR: "SINDI = teskari oyoq tug'ildi". Egasi: bitta MSS bu reversalning 3-bosqichi; "M5 MSS H1 ni bekor qila olmaydi" | **SINDI eski oyoq shartnomasini tugatadi**: o'sha tomonga yangi kirish yo'q, grid to'xtaydi. Teskari oyoq TUG'ILADI, lekin unga shartnoma faqat reversal ≥ 4-bosqichda **va** Xarita ruxsat bersa beriladi |
| Z2 | Teskari oyoq va hedge | Q1: yangi shartnoma faqat eski basket yopilgandan keyin |
| Z3 | Yo'nalish manbai | Yo'nalishni M5 oyog'i beradi, lekin Xarita 7 holatli TF holati va **ruxsat matritsasi** bilan cheklaydi (IMPULS / KORREKSIYA / taqiq) |
| Z4 | Tezlik (250–450 savdo/kun) | Qadam **jonli** hodisalarni ishlatadi: tick sweep, shakllanayotgan displacement. Oyoq bar yopilishida yangilanadi, lekin bekor bo'lish har tickda tekshiriladi. Kunlik savdo soni va o'tkazib yuborilganlar O'lchovda kuzatiladi |
| Z5 | Zona roli faqat "sezgi a'zosi" edi | Devorlar va zona roli **Xarita** qatlamiga kiradi. Oldindagi qarama-qarshi devor = joy yo'q = kirish yo'q (qat'iy) |
| Z6 | "Har modulda o'chirgich bo'lsin" va "kam sozlama" | Egasining oxirgi qarori ustun: ~50 sozlama. Konstantalar bitta faylda (`01_Konstantalar.mqh`) nomi va izohi bilan turadi; testerda o'zgartirish oson |
| Z7 | Re-entry vaqtga bog'langan edi | Vaqt sozlamasi o'rniga **hodisaga bog'langan** re-entry |
| Z8 | Cashback TP = spread × k; spread kengaysa TP ham o'sadi | Anomal spread → kirish yo'q (80); kirishdan oldin net edge tekshiruvi |
| Z9 | "Grid muzlamaydi" va "tahdid bo'lsa grid to'xtaydi" | Muzlash = chiqish yo'lisiz to'xtash, bu taqiqlanadi. To'xtash har doim chiqish rejasi bilan birga keladi |
| Z10 | Zarar qoidasi: Q7 + "IMPOSSIBLE yoki SL" va POYDEVOR "shartnoma tugadi" | **Ochiq qaror** (bo'lim 7). Egasi printsipda "tezis o'lsa kichik zarar" ga rozi bo'lgan, raqamlar 3-bosqichda |

---

## 7. Ochiq qarorlar (3-bosqichda egasi bilan)

1. **Shartnoma tugaganda zarar qoidasi.** Byudjet, yopish usuli va chiqish vaqti; qutqaruv hakami saqlanadimi.
2. **Lot.** Kichik hisoblar uchun "kattaroq lot + qisqaroq zina" tamoyilining raqamlari.
3. **Cashback TP hajmi** va o'rim chegaralari: qaysi bosqichlarda ruxsat.
4. **Normal rejim.** TP oyoqdan qanday olinadi; qulf / trailing qachon ishga tushadi.
5. **Grid.** Pog'onalar soni va qaytish zonalariga moslash.
6. **Regime.** Diapazon yoki siqilish oyoqlar tilida qanday o'qiladi (masalan, ikki tomonga ketma-ket SOXTA = diapazon).
7. **Panel.** Qaysi qatorlar.
