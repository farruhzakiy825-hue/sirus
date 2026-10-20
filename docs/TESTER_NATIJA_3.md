# Tester natijasi №3 — real ticks, XAUUSDm, 2026-03-18 … 2026-10-16

- Model: **Every tick based on real ticks**, V9.05.
- 8 oy: 995 ta M5 oyog'i, ~3 200 soya T savdo, 116 ming O'lchov natijasi.

## Soya T: mezondan o'tgan juft yo'q

- Barcha 10 juft: savdo boshiga −0.10R … +0.03R.
- Topish davrida hech biri t ≥ 2.6 ga yetmadi.
- Tasdiqlash davrida A_S, A_X, E_S, E_X t ≈ −2 (minus).

## Real ticks va 1 minute OHLC (bir xil davr, bir xil signallar)

| Juft | Real: n / R | OHLC: n / R |
|---|---|---|
| A_S | 523 / −0.015 | 523 / −0.051 |
| A_X | 575 / −0.018 | 575 / −0.039 |
| B_S | 318 / −0.103 | 318 / −0.157 |
| B_X | 373 / −0.012 | 373 / −0.050 |
| C_S | 216 / −0.002 | 217 / −0.068 |
| C_X | 258 / −0.017 | 259 / −0.070 |
| D_S | 129 / +0.025 | 129 / −0.017 |
| D_X | 129 / −0.052 | 129 / −0.098 |
| E_S | 356 / −0.015 | 356 / −0.046 |
| E_X | 378 / −0.020 | 378 / −0.044 |

- Signallar bir xil. OHLC trailing natijasini ~0.04R yomonroq ko'rsatadi (stop to'ldirish modeli tufayli).
- Real ticksda ham natija 0 dan oshmaydi.

**O'lchov:**
- Real ticks bilan OHLC deyarli bir xil: kichik TP 93.0% va 93.5%.
- "Oyoq bilan" savdo kutilgandan +0.34 pp (ikkala modelda).
- Kataklar taqsimoti tasodifiy.

## Xulosa

1 minute OHLC sinovlarining xulosasi real ticksda tasdiqlandi: M1 / M5 tuzilmasidan kirishda ustunlik yo'q. Keyingi raund faqat **yangi turdagi ma'lumot** bilan bo'ladi: tick faolligi, dollar (EURUSD), volatillik portlashi va xarajat rejimi.
