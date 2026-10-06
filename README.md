# Sirus Brain V8: XAUUSD grid basket EA

## O'rnatish

Kod bir nechta faylga bo'lingan. MetaTrader'da shunday joylashtiring:

```
MQL5/Experts/Sirus/
├── Sirus_Brain_V8.mq5      ← shu faylni kompilyatsiya qilasiz
└── Sirus/                  ← bu papka .mq5 fayl bilan YONMA-YON turishi shart
    ├── 00_Defines.mqh
    ├── 01_Inputs.mqh
    ├── ...
    └── 17_Reason_Code.mqh
```

1. Butun papkani `MQL5/Experts/` ichiga ko'chiring (masalan, `MQL5/Experts/Sirus/`).
2. MetaEditor'da faqat `Sirus_Brain_V8.mq5` ni oching va **Compile** (F7) bosing.
3. Natija bitta `Sirus_Brain_V8.ex5` fayl bo'ladi. Unga hamma qism kiradi, mijozga faqat shu fayl beriladi.

`.mqh` fayllarni alohida kompilyatsiya qilmang. Ular faqat asosiy fayl orqali, ma'lum tartibda ulanadi.

## Qayerda nima bor

| Fayl | Mazmuni |
|---|---|
| `00_Defines.mqh` | Konstantalar, enum'lar, oldindan e'lonlar |
| `01_Inputs.mqh` | Barcha sozlamalar (Inputs oynasi) |
| `02_Globals.mqh` | Global holat o'zgaruvchilari |
| `03_Core_Utils.mqh` | Yordamchi funksiyalar, muhit tekshiruvi, indikatorlar |
| `04_Trend_Structure.mqh` | Trend, VWAP, momentum, lokal struktura |
| `05_Situation_Candles.mqh` | Grid qo'shilish sifati, vaziyatlar, sham tahlili, sweep |
| `06_Basket_Session.mqh` | Pattern xotirasi, savat yoshi, scale-in, sessiyalar |
| `07_Detectors.mqh` | Kirish imkoniyati detektorlari |
| `08_Scanner_Score.mqh` | Skaner va signal ball dvigateli |
| `09_Redirect_Queue_Pack2.mqh` | Yo'nalish almashtirish, vaqtinchalik bloklar, navbat, Pack2/3 |
| `10_Basket_Stats_Context.mqh` | Lot chegaralari, savat statistikasi, bozor konteksti |
| `11_Expectancy_MTF_News.mqh` | Kutilma, zinapoya shakli, MTF/DXY, yangiliklar kalendari |
| `12_Exits_Trailing.mqh` | Ogohlantirishlar, savatni yopish, chiqishlar, cashback trailing |
| `13_Grid_Engine.mqh` | Grid intellekti, grid lot, grid dvigateli |
| `14_Risk_Gates_Entry.mqh` | Risk, kirish filtrlari, birinchi kirish |
| `15_Legacy_Packs.mqh` | VPS tekshiruvi, eski paketlar, mijoz xavfsizligi |
| `16_Dashboard_Core.mqh` | Dashboard, `CoreUpdate` oqimi |
| `17_Reason_Code.mqh` | Har ochilgan order sababi (jurnal + CSV) |
| `Sirus_Brain_V8.mq5` | `#property`, qismlarni ulash, `OnInit` / `OnDeinit` / `OnTick` / `OnTimer` |

Tuzatishlar tarixi `CHANGELOG.md` da, tahlil va reja esa `TUZATISH_REJASI.md` da.
