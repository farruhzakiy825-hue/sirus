# Tester natijasi №2 — Soya T (trailing), XAUUSDm, 2025-09-01 … 2026-10-16

- Model: 1 minute OHLC, V9.05.
- 13.5 oy, ~6 200 soya savdo, 1 922 ta M5 oyog'i.
- Oltin narxi davr ichida 3448 → 4164 (+21%).
- Mezon va gipotezalar: `docs/GIPOTEZALAR.md`, natijadan oldin yozilgan.

## Natija: mezondan hech qaysi juft o'tmadi

| Juft | Savdo | Yutgan | Savdo boshiga | t | Topish / Tasdiqlash |
|---|---|---|---|---|---|
| A_S asos / tuzilma | 984 | 40% | −0.050R | −1.5 | −0.028 / −0.087 |
| A_X asos / ATR | 1088 | 36% | −0.029R | −1.6 | −0.008 / −0.066 |
| B_S erta / tuzilma | 593 | 33% | −0.035R | −0.5 | +0.045 / −0.187 |
| B_X erta / ATR | 708 | 34% | +0.007R | +0.1 | +0.032 / −0.043 |
| C_S sweep / tuzilma | 410 | 34% | −0.061R | −0.8 | −0.187 / +0.204 |
| C_X sweep / ATR | 484 | 37% | −0.020R | −0.4 | −0.024 / −0.011 |
| D_S sessiya / tuzilma | 263 | 39% | −0.049R | −0.7 | −0.034 / −0.076 |
| D_X sessiya / ATR | 266 | 37% | −0.069R | −2.0 | −0.075 / −0.057 |
| E_S kuchli / tuzilma | 680 | 40% | −0.067R | −1.8 | −0.061 / −0.077 |
| E_X kuchli / ATR | 732 | 36% | −0.051R | −2.5 | −0.036 / −0.078 |

## Qo'shimcha tekshiruvlar (oldindan yozilmagan, faqat ma'lumot uchun)

- **BUY / SELL:** +21% o'sgan yilda ham BUY tomoni ishonchli plyus bermadi (eng yaxshisi B_X BUY: +0.098R, t = +1.2).
- **Trailing o'rniga qat'iy TP** (MFE orqali; 0.5R, 1R, 2R, 3R, 5R): hammasi −0.07R … +0.01R oralig'ida. Chiqish usuli natijani o'zgartirmaydi, muammo kirishda.
- **Oyoqlar:** keyingi 30 / 60 / 240 daqiqada yo'nalish 46–53%, hamma joyda |t| < 2.
  - Oyoq tug'ilganda median uzunligi 3.9 ATR(M15).
  - Vaqtning 80% ida oyoq KECH yoki TUGADI.
- **Soat bo'yicha M5 qaytimi** (24 soat): hech biri |t| ≥ 2 emas.
- **D1 trend (narx MA50 ustida — BUY, ostida — SELL):** +$1487 1 unsiyaga, t = +1.1. Bir yillik ma'lumot isbot uchun yetmaydi.

## Xulosa

1 va 2-sinov bir xil narsani ko'rsatdi. M1 / M5 tuzilmasidan (BOS, MSS, sweep, sessiya, displacement) kirishning XAUUSD'da xarajatdan ustun ustunligi yo'q: natijalar −xarajat atrofida. Bu oiladagi kirishlarni yana surish data-mining bo'ladi (V8 tuzog'i). Shuning uchun to'xtatiladi.

**Keyingi nomzod — katta TF trend (time-series momentum, D1 / H4):**
- tashqi, ko'p yillik ilmiy dalilga ega;
- savdo kam, xarajat ulushi kichik, trailing tabiiy mos keladi;
- ko'p yillik (10+) tarixda, oldindan yozilgan qoidalar bilan sinalishi kerak.
