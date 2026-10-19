# SIRUS POYDEVORI — "Sirus oyoqlarni savdo qiladi"

Bu hujjat kod emas, **mantiq**. Yillar davomida qo'shilgan yamoqlar o'rniga bitta tushunarli tuzilma.
Byudjet, zarar qoidasi, lot va cashback TP hajmi **oxirida** hal qilinadi (egasining qarori).

---

## 0. Nega poydevor kerak (koddan topilgan faktlar)

Kod uch yo'nalishda to'liq ko'rib chiqildi: struktura/oyoq hisoblari, kirish yo'li, grid va chiqishlar.

| Tushuncha | Kodda necha xil hisoblanadi |
|---|---|
| Oyoq boshlanishi (origin) | **8 xil**: 6 soatlik M15 ekstremum, M5 himoya swingi, birinchi displacement ochilishi, 30 ta M1 bar ekstremumi, 60 ta M15 bar ekstremumi, eng eski swing, 8 ta M5 bar, M1 N-bar |
| "Oyoq necha % yurdi" | 3 ta funksiya, har biri boshqa origin bilan. Maqsad topilmasa `MBLegPct` **0%** deydi (kech oyoq "yangi" ko'rinadi) |
| Charchash | 9 xil o'lchov |
| Maqsad | 8 xil |
| Bekor bo'lish (invalidation) | 8 xil |
| Trend yo'nalishi | **15+** xil (ba'zilari soxta breaklar bilan ham trendni almashtiradi) |
| Swing topish | 9 ta alohida sikl, har xil chuqurlik va qoidalar bilan |
| BOS | 5 ta alohida implementatsiya |
| Spread tekshiruvi | 7 joyda, 4 xil chegara |
| Yangilik tekshiruvi | 3 marta ketma-ket |
| Mikro nazorat chegarasi | 5 xil (35 / 40 / 45 / 60 / 65) |
| Kirishdagi lot sozlagichlari | 15 ta, oxirida `MinFirstEntryLotFactor = 1.0` hammasini bekor qiladi |
| Basketni yopish yo'llari | 29 ta chaqiruv, ~20 mexanizm |
| "Tezis o'ldi" ta'rifi | **3 xil**, natijasi har xil (BE + 30, TP 400, TP × 0.6). Ikkitasi bir vaqtda rost bo'lishi mumkin |
| ~50% stoplar | 7 ta ustma-ust |

**Eng og'ir topilma:** o'lik basketda 0–25% DD oralig'ida **hech qanday chiqish yo'q**. Grid qattiq to'xtaydi, basket faqat BE ni kutadi. Zarar bilan chiqish 25% dan (hakam) yoki 50% dan (SL) boshlanadi. −937$ lik basket aynan shu tuynukda 5 kun yashadi.

**Sozlamaning ta'sirsizligi:** cashback grid qadami (TP × 3 ≈ 700 punkt) baribir minimal 6000 ga qisiladi, ya'ni bu sozlama hech narsa qilmaydi.

**Xulosa:** Sirusda "aqlli" bo'laklar yetarli. Kasallik ularning hammasi bitta narsani — **oyoqni** — har biri o'zicha, har xil masshtabda hisoblashi va qarorning yagona egasi yo'qligida.

---

## 1. Poydevor qoidasi

> **Bitta savdo = bitta da'vo = bitta masshtab.**
> Da'vo: "narx shu oyoq bo'ylab MAQSADgacha boradi, HIMOYA buzilmaguncha".
> Kirish, TP, re-entry, grid, chiqish va ushlab turish vaqti shu da'vodan kelib chiqadi.

---

## 2. Uch qavat

| Qavat | TF | Yagona savol | Beradi | Savdo ochadimi? |
|---|---|---|---|---|
| **XARITA** | H4 / H1 | Pul qayerda, devorlar qayerda, katta oyoq qaysi tomonga? | Katta yo'nalish, devorlar, likvidlik hovuzlari | Yo'q |
| **OYOQ** | M15 / M5 | Hozir qaysi oyoq yuryapti, qayerdan qayergacha, qayerda o'ladi? | **Shartnoma** | Shartnoma beradi |
| **QADAM** | M1 | Oyoqqa hozir qo'shilish payti keldimi? | Faqat vaqt | Hech qachon yo'nalish tanlamaydi |

---

## 3. OYOQ — aniq ta'rif

Bitta kanonik obyekt. Hamma modul shu obyektdan o'qiydi, hech kim oyoqni o'zicha qayta hisoblamaydi.

### 3.1 Pasport

| Maydon | Ta'rif | Koddagi eng mustahkam asos |
|---|---|---|
| `YO'NALISH` | +1 / −1 | M5 BOS/MSS (`MBDetectStructure`, 18) |
| `TUG'ILGAN VAQT` | Tug'ilish hodisasi yopilgan bar | `MBStructBreakRecord` (20b:142) |
| `ORIGIN` (qotib qoladi) | Oyoq boshlangan ekstremum: buzilgan swing bilan buzgan bar orasidagi eng chekka nuqta. Reversal oyoqda sweep ekstremumi | `G_ST_PROT_*[M5]` tug'ilgan paytdagi qiymati; reversalda `G_ST_REV_EXT` |
| `HIMOYA` (oyoq bilan birga suriladi) | Oxirgi himoyalangan swing. Har yangi shu-tomon BOS uni oldinga suradi (trendda higher low / lower high) | `G_ST_PROT_*[M5]` (faqat VALID+ break suradi, soxta break orqaga qaytaradi) |
| `EKSTREMUM` | Tug'ilgandan beri eng uzoq nuqta | narx |
| `MAQSAD` | Oyoq oldidagi eng yaqin **buzilmagan** likvidlik hovuzi, klassi M15 yoki undan yuqori | `MBLqNearestAhead` + sinf filtri (20a:550). Zaxira: `G_MB_DOL`, keyin xarita devori |
| `TURI` | IMPULS (displacement bilan tug'ilgan) / KORREKSIYA (xaritaga qarshi) | `MBImpulseUpdate` (17), `G_MB_TF_STATE[3..4]` |
| `TO'LQINLAR` | Shu oyoq ichidagi turtki soni | `G_MB_IMP_WAVES` (17) |
| `XARITAGA MUNOSABATI` | BILAN / QARSHI / NEYTRAL | H1 + H4 holati |

### 3.2 Uchta o'lchov

- **Yurgani %** = (EKSTREMUM − ORIGIN) / (MAQSAD − ORIGIN).
  - Maqsad yo'q bo'lsa, % hisoblanmaydi va oyoq ATR(M15) bilan o'lchanadi. Endi hech qachon "0%" bo'lmaydi.
- **Qaytish %** = (EKSTREMUM − narx) / (EKSTREMUM − ORIGIN). Hozir oyoq qancha orqaga qaytgan.
- **Uzunlik** = (EKSTREMUM − ORIGIN) / ATR(M15).

### 3.3 Hayot sikli

| Bosqich | Shart | Ma'nosi |
|---|---|---|
| **TUG'ILDI** | M5 da VALID+ BOS/MSS yoki reversal 3-bosqich (sweep → displacement → MSS) | Yangi da'vo paydo bo'ldi |
| **TASDIQLANDI** | Keyingi 2 yopilish orqaga qaytmadi (`MBBreakFailed` yo'q) | Soxta emas |
| **SOXTA** | 2 yopilish ichida break qaytarib olindi | Oyoq yo'q, tuzoq. Teskari tomon uchun dalil |
| **YANGI** | Yurgani < 33%, to'lqin ≤ 1 | Eng yaxshi davr |
| **RIVOJ** | 33–66% | Normal davr |
| **KECH** | ≥ 66%, yoki to'lqin ≥ 3, yoki charchash bosimi ≥ 60 | Yangi da'vo yo'q. Data: charchash ≥ 60 da grid 25%, oyoq ≥ 100% da 17.9% (o'rtacha ~7%) |
| **TUGADI** | Maqsadga tegdi | Oyoq o'z vazifasini bajardi. Yangi BOS + yangi maqsad bo'lmaguncha shu tomonga yangi da'vo yo'q |
| **SINDI** | M5 yopilishi HIMOYAdan + 0.15 ATR(M5) dan o'tdi | **Teskari oyoqning tug'ilishi bilan bir hodisa.** Bitta voqea, ikkita ziddiyatli ta'rif emas |

### 3.4 Qaytish zonalari

| Qaytish | Nomi | Ma'nosi |
|---|---|---|
| 0–23% | yurishda | Quvish xavfi: kirish faqat yangi oyoqda |
| 23–38% | sayoz | Kuchli oyoqda kirish joyi |
| 38–62% | **oltin zona** | Asosiy kirish joyi |
| 62–79% | chuqur | Grid pog'onasi joyi |
| 79–100% | himoya oldi | Faqat himoya ushlab tursa |
| HIMOYAdan o'tdi | — | Oyoq SINDI, shartnoma tugadi |

### 3.5 Katta oyoq (XARITA)

Xuddi shu ta'rif H1 da: `G_ST_PROT_*[H1]` + H1 BOS. Dealing range qayta quriladi: H1 himoyasidan qarama-qarshi H1 ekstremumigacha. Hozirgi "eng yaqin H1 swinglar" ko'pincha juda tor.

- Katta oyoq bilan bir tomondagi ish oyog'i = **IMPULS**, to'liq savdo.
- Unga qarshisi = **KORREKSIYA**. Maqsadi katta oyoqning 38–62% qaytishi yoki xarita devori bilan cheklanadi.

---

## 4. Shartnoma: savdo oyoqdan qanday kelib chiqadi (mantiq, raqamlar oxirida)

| Qism | Hozir | Poydevorda |
|---|---|---|
| Kirish | Signal bo'lsa, istalgan joyda | Faqat TASDIQLANGAN, YANGI/RIVOJ oyoqda, uning yo'nalishida, qaytish zonasida, QADAM payti bilan |
| TP (normal) | 3 × ATR(M1), 2125–5100 | Oyoqning qolgan yo'lidan (maqsadgacha yoki uning qismi) |
| TP (cashback) | spread × 0.6 + 80, oyoqqa bog'liq emas | **"O'rim"**: kichik TP lar, lekin faqat tirik oyoq ichida va faqat uning yo'nalishida |
| Re-entry | Har doim tez | Oyoq tirik va KECH emas ekan: darhol (egasining qoidasi saqlanadi). KECH, TUGADI yoki SINDI bo'lsa: to'xtaydi |
| Grid pog'onasi | 6000–12000 punkt, ~15 ta gate | Oyoqning chuqur qaytish zonasida (62 / 79%), HIMOYAdan oldin. Tasdiq QADAMdan |
| Grid to'xtashi | Qattiq muzlash, chiqish yo'q | Muzlash yo'q: pog'ona yo HIMOYA ichida turadi, yo shartnoma tugaydi |
| Chiqish (foyda) | TP / trailing / runner, 6 mexanizm | Maqsad yoki TP; oyoq KECH bo'lsa ehtiyotkor |
| Chiqish (shartnoma tugadi) | 25% / 50% DD | Oyoq SINDI → shartnoma tugadi. **Qanday yopish va byudjet oxirida** |
| Ushlab turish | Cheksiz | Oyoq umri |

---

## 5. Modullar xaritasi

### XARITA (H4 / H1)

- **Qoladi:**
  - `G_MB_TF_STATE[3..4]`
  - Likvidlik xaritasi (20a): H1/H4, sessiya, PDH/PDL
  - HTF zonalari (20g)
  - ZI H1/H4 (20i)
  - DOL
- **Qayta quriladi:** dealing range (3.5 ga qarang).
- **Birlashtiriladi yoki olib tashlanadi:**
  - H4 20-bar qutisi
  - `HTFStructureBias` (Kalman)
  - `DeepHTFTrendDirection`
  - `MarketTrendSideNow`
  - `GlobalTrendDirection` (D1)
  - `MTFTrendDirection`
  - `MarketStructureRead` (11)

### OYOQ (M15 / M5) — bitta dvigatel

- **Asos:**
  - Hodisa dvigateli 18: swing, BOS/MSS, sweep (kanonik)
  - 20b: himoya swinglari, reversal bosqichi, lock
  - 17: impuls, to'lqin, tezlik
  - 20c: bosim / charchash (yangi origin bilan qayta hisoblanadi)
  - 20a: maqsad hovuzlari
- **Shu dvigatelga singib ketadi:**
  - `G_LX_ORIGIN` (6 soatlik)
  - `LocalStructureUpdate` / `G_LS_*` (04)
  - `StructureDirOnTF`
  - `MoveExtensionATR`
  - `LGMicroTip` / `LGChasingImpulse` / `LGFreshImpulse`
  - `MicroStructUpdate` (14)
  - `DeepDetectBOSDirection` (15)
  - Lokal tezis (M1 origin)
  - Market Brain tezis invalidatsiyasi
  - V247 basket tezisi
  - `CoreStretched`
  - `MBLateBlocks`
  - `CoreLateAgainstBiasPct`
- **Qoida:** `G_MB_TREND` soxta breklar bilan almashmasligi kerak, faqat filtrlangan holat ishlatiladi.

### QADAM (M1)

- Sham dvigateli M1: tasdiq yoki qarshilik.
- Mikro nazorat (20d): **bitta** chegara to'plami.
- Jonli sweep.
- YADRO trigger qismi.
- QADAM faqat "hozirmi?" degan savolga javob beradi.

### SEZGI A'ZOLARI (ma'lumot beradi, o'zi to'xtatmaydi)

- Zona roli (19)
- Zona intellekti (20i)
- Xarajat (20e)
- Bozor holati nomi (20f)
- Charchash (20c)

### XAVFSIZLIK (bozorga emas, hisobga tegishli; alohida qatlam)

- Risk / margin
- **Bitta** spread chegarasi
- **Bitta** yangilik tekshiruvi
- Dam olish kunlari
- Dublikat nusxa
- Oxirgi to'r: basket SL va favqulodda yopish (7 ta ~50% stop o'rniga bittasi)

### SHARTNOMA MENEJERI (yagona hokim) — quyidagilar o'rniga keladi

- YADRO tomon mantig'i va eski zanjir maslahatchisi
- Pozitsiya miyasi: o'lim va qutqaruv
- 3 ta "premise dead" ta'rifi
- Expectation / stale BE
- Qutqaruv hakami
- `MBGridAllows` va liability score
- Staleness
- ~10 ta chiqish yo'li

### KEYINROQ KO'RIB CHIQILADI (oxirida egasi bilan)

- Skaner / redirect / queue / legacy paketlari (hozir faqat durang holatda tomon tanlashda ishlatiladi)
- 15 ta o'lik lot sozlagichi
- Ikkita alohida trailing tizimi

---

## 6. Ko'r bo'lmaslik: Sirus o'zini o'lchaydi

Ehtimol jadvalining kataklari oyoq holati bo'yicha bo'ladi:

> bosqich (YANGI / RIVOJ / KECH) × xaritaga munosabat (BILAN / QARSHI) × qaytish zonasi × QADAM (sham bilan / qarshi)

Har katak uchun savol: **"TP HIMOYAdan oldin keladimi?"**

- Bozor buni har kuni ~2800 xayoliy savdo bilan o'zi to'ldiradi, oylab test kerak emas.
- Panel har katakni "ustunlik bor / yo'q / hali noma'lum" deb ko'rsatadi.

---

## 7. Qurish tartibi (buzmasdan)

1. **Oyoq dvigateli — faqat kuzatuvchi.**
   - Savdoga ta'sir qilmaydi.
   - Chartda chiziladi: ORIGIN, HIMOYA, MAQSAD, bosqich, qaytish %.
   - Panelda bitta qator.
   - Egasi live chartda 1–2 kun ko'radi: "oyoqni men ko'rgandek ko'ryaptimi?". Bu oylab testsiz eng tez tekshiruv.
2. Ehtimol jadvali oyoq kataklariga o'tadi. Bu ham faqat kuzatuv.
3. Shartnoma qoidalari (bo'lim 4) raqamlari bilan yoziladi. Shu yerda egasi bilan byudjet, zarar qoidasi, lot va cashback TP hal qilinadi.
4. Shartnoma menejeri YADRO o'rniga ulanadi. Eski yo'llar bittadan o'chiriladi, har birining o'rni ko'rsatiladi.
5. Ortiqcha kod (bo'lim 5) olib tashlanadi.
