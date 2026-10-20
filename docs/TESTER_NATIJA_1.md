# Tester natijasi №1 — XAUUSDm, 2026-08-03 … 2026-10-16

- Model: 1 minute OHLC (har daqiqada 4 tick).
- Sinov ~2.5 oy: 15 149 ta M5 qator, 415 ta M5 oyog'i, 38 890 ta O'lchov natijasi.
- Tahlil: `tools/v9check/tahlil.py`.

## 1. Soya savdo (punktda, keshbeksiz)

| Rejim | Savdo | TP ulushi | Zararsizlik uchun kerak | O'rtacha yutuq | O'rtacha zarar | Savdo boshiga |
|---|---|---|---|---|---|---|
| CB | 552 | 93.1% | 98.4% | +231 | −14 036 (SINDI) | **−751** |
| N | 18 | 38.9% | 68.5% | +6 480 | −14 097 | **−6 095** |
| Q | 1 837 | 80.9% | 93.6% | +231 | −3 392 (STOP) | **−461** |

Uchala rejim ham minusda.

## 2. O'lchov — "ko'zlar" yo'nalishni oldindan bilyaptimi?

- Kichik TP: 275 ta katakda kamida 30 tadan natija bor.
  - z o'rtacha +0.11, sd 1.09;
  - |z| ≥ 2 bo'lgan katak 13 ta. Toza tasodifda ham ~13 ta bo'ladi.
- Har o'lchov alohida (oyoq bilan / qarshi, bosqich, zona, H1, qadam): hammasida |z| < 2.
- Ma'nosi: shu davrda katak bo'yicha bo'lish TP ulushini geometriyadan (TP va stopgacha masofa) ortiq bashorat qilmadi.

## 3. Oyoqlar — har oyoq bitta namuna

- Oyoq tug'ilganda allaqachon uzun: median 3.7 ATR(M15), origindan ~$24.
- Vaqtning 73% ida oyoq KECH yoki TUGADI, atigi 3% ida YANGI.
- 415 oyoqning 105 tasi TUG'ILDI bosqichidan nariga o'tmagan.
- Oyoq yo'nalishida keyingi 30 / 60 / 240 daqiqa: hamma bosqichda |t| < 2, yo'nalish to'g'ri chiqishi ~50%.

## Xulosa

Bu davrda M5 tuzilmasi (BOS / MSS oyog'i) keyingi harakat yo'nalishida statistik ustunlik bermadi. Kichik TP va uzoq stop bilan ustunliksiz savdo har safar o'rtacha spread atrofida zarar qiladi. Grid bu zararni yo'q qilmaydi, faqat kamdan-kam, lekin katta zararga yig'adi.

Keyingi qadam: Shartnomani qurishdan oldin ustunlik manbasini oldindan belgilangan gipotezalar bilan topish va tasdiqlash. Davr uzunroq bo'lishi kerak; topish va tasdiqlash davrlari ajratiladi.
