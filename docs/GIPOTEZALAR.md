# Ustunlik qidiruvi — oldindan yozilgan gipotezalar (V9.05)

Bu hujjat tester natijasini ko'rishdan **oldin** yozildi. Natijani ko'rgandan keyin gipoteza, son yoki mezon o'zgartirilmaydi. O'zgartirilsa, yangi gipoteza bo'ladi va boshqa davrda qayta sinaladi.

Nega bunday qattiq: 10 ta qatorni sinasak, ulardan birontasi tasodifan "zo'r" chiqishi mumkin. V8 yillar davomida aynan shu tuzoqqa tushgan: natijaga qarab sozlama surilgan.

## Savdo shakli (hamma gipotezalar uchun bir xil)

- TP yo'q, faqat trailing stop: harakat qancha cho'zilsa, shuncha olinadi.
- Natija **R** da o'lchanadi.
  - 1R — kirishdan boshlang'ich stopgacha bo'lgan masofa, spread bilan.
  - +2R — xavf qilingan summaning 2 barobari foyda.
- Har kirish ikki chiqish bilan alohida o'lchanadi:
  - **S (tuzilma):** stop M5 oyog'ining HIMOYAsi bilan suriladi, ATR(M5) × 0.15 narida. Oyoq sinsa — chiqiladi.
  - **X (ATR):** stop eng yaxshi narxdan ATR(M5) × 3 orqada (chandelier).
- Stop faqat oldinga suriladi.
- Yopilishda zararga ATR(M5) × 0.05 sirpanish hisoblanadi. Gap bo'lsa, haqiqiy narx olinadi.
- Boshlang'ich xavf 3 spreaddan kichik bo'lsa, signal o'tkaziladi.
- Har gipoteza va chiqish juftida bir vaqtda ko'pi bilan bitta ochiq savdo bo'ladi.

## Kirish gipotezalari

| | Nomi | Kirish | Boshlang'ich stop | Asosi |
|---|---|---|---|---|
| **A** | asos (nazorat) | M5 oyog'i tug'ildi (MSS), shu yopilgan barda | M5 origin ∓ 0.15 ATR(M5) | Taqqoslash uchun. 1-sinovda ustunlik ko'rinmagan |
| **B** | erta | M5 oyog'i tasdiqlangan, bosqichi YANGI / RIVOJ / KECH. Qaytish M5 yo'lining 38–100% iga yetgan. M1 da M5 tomonga MSS bo'ldi | M1 origin (qaytish tubi) ∓ 0.15 ATR(M5) | Oyoqni kech ko'rish muammosi: kirish qaytish tubida, stop yaqin |
| **C** | sweep | Sinfi ≥ 3 hovuz (H1/H4/PDH/PDL/Osiyo/PW) oxirgi 60 daqiqada sweep bo'lgan. M1 da teskari MSS bo'ldi. M1 oyog'i sweep nuqtasidan boshlangan | M1 origin (sweep uchi) ∓ 0.15 ATR(M5) | Katta likvidlik olingandan keyingi burilish: stop yaqin, harakat uzoq bo'lishi mumkin |
| **D** | sessiya | London 07:00–10:00 yoki NY 12:30–15:30 (UTC) oynasidagi birinchi M5 tug'ilish. Har sessiyada kuniga bitta | A bilan bir xil | Ochilishda hajm va yo'nalish kuchli bo'ladi degan taxmin |
| **E** | kuchli | M5 oyog'ini tug'dirgan sham tanasi ≥ 0.8 ATR(M5) | A bilan bir xil | Kuchli displacement davom etadi degan taxmin |

## Sinov

- **Tester:** XAUUSDm, oxirgi **12 oy**, 1 minute OHLC (yoki real ticks).
- **Topish davri:** birinchi 8 oy. **Tasdiqlash davri:** oxirgi 4 oy. Davr savdo kirgan vaqt bo'yicha bo'linadi.
- **Tahlil:** `python3 tools/v9check/tahlil.py <Soya.csv> <Kozlar.csv> <Olchov.csv>`

## O'tish mezoni (har gipoteza va chiqish juftiga alohida)

1. **Topish davrida:** kamida 60 savdo, o'rtacha R > 0 va t ≥ 2.6. 2.6 — 10 ta qator sinalgani uchun oshirilgan chegara.
2. **Tasdiqlash davrida:** kamida 25 savdo, o'rtacha R > 0 va t ≥ 1.65.
3. Ikkalasidan o'tganlargina Shartnomaga kiradi. U yerda lot, stop budjeti (50%) va kichik balansga moslash shu juftning R taqsimotidan hisoblanadi.
4. Hech biri o'tmasa, real pulda bu asosda savdo qilinmaydi. Keyingi gipotezalar yangi hujjat bilan yoziladi.

A (nazorat) o'tsa ham, bu "har oyoqqa kirish ishlaydi" degani. Unda B–E A dan yaxshiroqmi, alohida solishtiriladi.
