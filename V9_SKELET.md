# SIRUS V9 — SKELET (0-bosqich)

Bu hujjat kod emas, **qurilish chizmasi**. Egasi "ha" demaguncha bitta qator kod yozilmaydi.
Mantiq asosi: `POYDEVOR.md`.

V8 muzlatiladi: unga boshqa yamoq qo'shilmaydi. V8 git'da to'liq saqlanadi, undan istalgan bo'lakni **dalil bilan** qayta olish mumkin.

---

## 1. Uch temir qoida

1. **Har qatlam bitta savolga javob beradi.** Boshqa qatlamning ishini qilmaydi.
2. **Ma'lumot faqat pastdan yuqoriga oqadi.** Qatlam faqat o'zidan pastdagilarni o'qiydi.
3. **Qarorni faqat Shartnoma qabul qiladi, orderga faqat Ijro tegadi.** Boshqa hech kim savdo ochmaydi, yopmaydi, to'xtatmaydi.

---

## 2. Fayllar

```
SirusV9/
  SirusV9.mq5        dirijyor: OnInit / OnTick / OnTimer / OnTradeTransaction — faqat qatlamlarni tartib bilan chaqiradi
  00_Asos.mqh        turlar (Oyoq, Hovuz, Hodisa, Shartnoma), ATR kesh, yangi bar, umumiy yordamchilar
  10_Hodisalar.mqh   BITTA swing topuvchi; BOS / MSS / sweep / displacement / soxta break — M1, M5, M15, H1, H4
  20_Likvidlik.mqh   likvidlik hovuzlari: swing, PDH/PDL, sessiya, Osiyo; holati (yangi / sweep / olingan)
  30_Oyoq.mqh        OYOQ dvigateli: pasport, hayot sikli, o'lchovlar, qaytish zonalari (M5 ish oyog'i + H1 katta oyoq)
  40_Xarita.mqh      H1/H4: katta oyoq, devorlar (HTF zonalar), dealing range, maqsad (DOL)
  50_Qadam.mqh       M1: "hozirmi?" — burilish shami, rad etish, mikro nazorat (bitta chegara to'plami)
  60_Olchov.mqh      xayoliy savdolar oyoq kataklari bo'yicha: ustunlik bor / yo'q / noma'lum
  70_Shartnoma.mqh   YAGONA HOKIM: kirish, re-entry, grid pog'onasi, chiqish
  80_Xavfsizlik.mqh  spread, yangilik, dam olish, margin, bitta favqulodda stop, dublikat nusxa
  90_Ijro.mqh        order yuborish / yopish, qayta urinish, broker SL/TP zaxirasi, restartdan keyin tiklash
  95_Panel.mqh       panel + chart chizmalari (oyoq, hovuzlar, zonalar)
  99_Jurnal.mqh      bitta formatdagi jurnal: trace + autopsy CSV
```

13 ta fayl. V8 da 43 fayl va 75 000 qator bor.

---

## 3. Har tickda oqim

```
 bozor ──► 10 HODISALAR ──► 20 LIKVIDLIK ──► 30 OYOQ (M5 + H1) ──► 40 XARITA
                                                     │                  │
                                                     ▼                  ▼
                                               50 QADAM (M1)      60 O'LCHOV
                                                     │                  │
                                                     └──► 70 SHARTNOMA ◄┘
                                                              │
                                                     80 XAVFSIZLIK (ruxsat bormi?)
                                                              │
                                                          90 IJRO ──► broker
 95 PANEL va 99 JURNAL hammasini faqat o'qiydi.
```

Har ko'z faqat **yangi bar yopilganda** qayta hisoblanadi: M1 qatlami har M1 da, M5 qatlami har M5 da va hokazo. Tickda faqat Shartnoma narxni kuzatadi va Ijro ishlaydi. Shu sababli V9 tez bo'ladi.

---

## 4. Har qatlam: savol, chiqish, V8 dan nima olinadi

| Qatlam | Yagona savol | Chiqaradi | V8 dagi asos (ko'chirib, tozalab olinadi) |
|---|---|---|---|
| 10 Hodisalar | Bozorda nima bo'ldi? | Swinglar, BOS/MSS, sweep, displacement, soxta break | 18_Event_Engine, 20 `MBBreakFailed`, 17 displacement |
| 20 Likvidlik | Pul qayerda yotibdi? | Hovuzlar ro'yxati, sinfi, holati | 20a_Liquidity_Map |
| 30 Oyoq | Qaysi oyoq yuryapti, qayerdan qayergacha, qayerda o'ladi? | Oyoq pasporti (M5 va H1) | 20b himoya swinglari + reversal, 17 to'lqin/tezlik, 20c bosim |
| 40 Xarita | Katta rasm qanday, devorlar qayerda? | Katta oyoq, devorlar, maqsad | 20g HTF zonalar, 20i H1/H4 zonalar |
| 50 Qadam | Hozirmi? | Burilish / rad etish / nazorat | 17 M1 sham, 20d mikro nazorat |
| 60 O'lchov | Shu holatda Sirus ko'radimi? | Katak bahosi | 28 ehtimol jadvali |
| 70 Shartnoma | Nima qilamiz? | Ochish / qo'shish / yopish / kutish + sababi | **yangi** (POYDEVOR §4) |
| 80 Xavfsizlik | Hisob va sharoit ruxsat beradimi? | ha / yo'q + sababi | V8 risk, kalendar, margin |
| 90 Ijro | Buyruqni brokerga qanday yetkazamiz? | Order natijasi | V8 12/13/14 sinalgan qismi |

Olinmaydi: skaner, redirect, navbat, legacy/deep paketlar, 15 lot sozlagich, ikkinchi trailing, 9 xil charchash, 8 xil origin va hokazo.

---

## 5. Sozlamalar: 2979 → ~55

### 5.1 Printsip: sozlama va konstanta ikki xil narsa

- **Sozlama** = egasining tanlovi: risk, rejim, lot, jadval, ko'rinish. Hisobdan hisobga o'zgaradi. Panelda ko'rinadi.
- **Ichki konstanta** = bozorni qanday o'qish: "BOS = swingdan yopilish", "oltin zona 38–62%". Hamma uchun bir xil. Kodda nomi va izohi bilan turadi. Bozor nisbiy o'lchovlarda (ATR, oyoq o'lchami) olinadi, shuning uchun qayta sozlash kerak emas. Uning ta'sirini O'lchov qatlami ko'rsatadi; dalil chiqsa sozlamaga ko'tariladi.

### 5.2 Qolgan 2900+ qayerga ketadi

| V8 dagi tur | Taxminan | V9 da |
|---|---|---|
| Raqamli chegaralar (ATR karra, bar soni, %) | 1849 | Asosiy qismi bitta tushunchaning takrori. Kerakli ~40–60 tasi **ichki konstanta**ga aylanadi |
| Yoq/o'chir kalitlari (Enable / Use) | 517 | Yo'q. V9 da "ixtiyoriy bo'lak" yo'q: qism dizaynda bor yoki yo'q |
| Legacy / Pack / Deep / V-raqamli | 120 | Ko'chirilmaydi |
| Butun guruhlar: DXY proksi, Bayes/Hurst, RSI divergensiya, pin bar, premium vizual paketlar, regime auto-tuning, profit governor... | ~300 | Ko'chirilmaydi |
| Vizual / log / push | ~160 | 14 taga qisqaradi |
| Hunter / Balanced rejim nusxalari | 16 | Bitta rejim to'plami: Cashback / Normal |

### 5.3 V9 sozlamalari (taxminiy ro'yxat, raqamlari 3-bosqichda birga hal qilinadi)

**1. Rejim (3)**
- Savdo rejimi: Cashback / Normal
- Magic raqam
- Savdo yoqilgan / faqat kuzatish

**2. Lot (4)**
- Boshlang'ich lot
- Avto lot (ha / yo'q)
- Avto lot: shartnoma riski %
- Maksimal lot

**3. Shartnoma va byudjet (6)**
- Bitta shartnoma maksimal zarari (balans %)
- Maksimal grid pog'onalari
- Pog'ona lot ko'paytmasi (≥ 1.0, pog'ona hech qachon kichraymaydi)
- Basket SL % — oxirgi to'r
- Kunlik zarar limiti %
- Shartnoma tugaganda yopish usuli (3-bosqichda hal qilinadi)

**4. TP va re-entry (5)**
- Cashback TP = spread × k
- Normal TP = qolgan yo'lning ulushi
- Minimal TP (punkt)
- TP dan keyin darhol re-entry (ha / yo'q)
- Re-entry oralig'i (sekund)

**5. Oyoq (4)**
- Ish TF (M5)
- Xarita TF (H1)
- "Kech" chegarasi %
- Korreksiya oyoqlarida savdo (ha / yo'q)

**6. Xavfsizlik (10)**
- Maksimal spread
- Yangilikdan oldin / keyin (daqiqa)
- Yangilik darajasi
- Savdo soatlari (boshlanish / tugash)
- Juma to'xtash soati
- Jumada yopish (ha / yo'q)
- Minimal margin %
- Maksimal slippage
- Favqulodda DD %

**7. O'lchov (4)**
- Xayoliy savdo (ha / yo'q)
- Katak uchun minimal namuna
- Salbiy katakda kirmaslik (ha / yo'q)
- Tester jadvalini o'qish (ha / yo'q)

**8. Panel va chart (8)**
- Panel
- Oyoq chiziqlari
- Hovuzlar
- Zonalar
- Shrift o'lchami
- 2 ta rang
- Burchak

**9. Jurnal va xabar (6)**
- Log darajasi
- Trace CSV
- Autopsy CSV
- Yopilganda push
- DD ogohlantirish push
- DD ogohlantirish %

**Jami ≈ 50.** Tester uchun alohida "kichraytirilgan" build kerak bo'lmaydi.

---

## 6. Keyingi bosqichlar

| Bosqich | Nima | Savdo? |
|---|---|---|
| 0 | Shu skelet (egasi tasdiqlaydi) | — |
| 1 | 00–50 + 95: ko'zlar va chart. Egasi live chartda tekshiradi | yo'q |
| 2 | 60: o'lchov | yo'q |
| 3 | 70 qoidalari raqamlari bilan + byudjet / zarar / lot / cashback TP qarorlari | yo'q |
| 4 | 80 + 90: xavfsizlik va ijro | demo |
| 5 | Demo → live | ha |

---

## 7. Xazinadan keyin aniqlashtirishlar (`V8_XAZINA.md` §6)

- **SINDI** eski oyoq shartnomasini tugatadi. Teskari oyoqqa shartnoma faqat reversal ≥ 4-bosqichda va Xarita ruxsat bersa beriladi. "M5 MSS H1 ni bekor qila olmaydi."
- **Hedge yo'q.** Yangi shartnoma faqat eski basket yopilgandan keyin.
- **40 Xarita** ichiga qo'shiladi:
  - 7 holatli TF holati va ruxsat matritsasi (IMPULS / KORREKSIYA / taqiq);
  - devorlar va zona roli (qat'iy: oldinda devor bo'lsa, joy yo'q);
  - HTF sweep vetosi;
  - premium / discount;
  - katta oyoq KECH yoki TUGADI bo'lsa, shu tomonga yangi shartnoma yo'q (4081 SELL saboqi).
- **50 Qadam** jonli hodisalarni ishlatadi: tick sweep, shakllanayotgan displacement. Bekor bo'lish har tickda tekshiriladi. Tezlik maqsadi: 250–450 savdo/kun, O'lchovda kuzatiladi.
- **60 O'lchov** faqat blok qo'shadi. Yo'nalish va "qayerda" vetolarini hech qachon yumshatmaydi.
- **Konstantalar** bitta faylda: `01_Konstantalar.mqh`, nomi va izohi bilan.
- **Re-entry** hodisaga bog'langan: "Re-entry oralig'i (sekund)" sozlamasi olib tashlanadi. Kirish va chiqish uchun alohida CTrade obyektlari. Restart kaliti POSITION_IDENTIFIER.
- **Normal rejimda bitta qulf / trailing egasi** — Shartnoma.
- **Ochiq qarorlar** (3-bosqich): `V8_XAZINA.md` §7.

---

## 8. Egasining qarorlari (qat'iy)

- **Stop doim 50%.** Basket SL = balansning 50% i. Bu oxirgi to'r va o'zgarmaydi.
- **Minimal balansga moslashish majburiy.**
  - $100 lik hisob — faqat cashback rejimi.
  - Cent hisob — $50 dan.
  - Live hisob hozir ~$300.
  - Lot, zina uzunligi va shartnoma byudjeti 3-bosqichda shu balanslarga moslab hisoblanadi: "kattaroq lot + qisqaroq zina", pog'ona hech qachon kichraymaydi.
  - Tester minimal $3000 — natijalar balans foizida o'lchanadi, $ da emas.

