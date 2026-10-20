# Ustunlik qidiruvi — 2-raund: scalp, yangi turdagi ma'lumot (V9.06)

Bu hujjat tester natijasini ko'rishdan **oldin** yozildi (2026-10-20). Qoidalar `docs/GIPOTEZALAR.md` dagidek: natijani ko'rgandan keyin gipoteza, son yoki mezon o'zgartirilmaydi.

**Nega 2-raund:**
- 1-raund (A–E, M1/M5 narx tuzilmasi) uch sinovda o'tmadi: 2.5 oy, 13.5 oy va 8 oy real ticks (`TESTER_NATIJA_1..3.md`).
- 2-raund robot hozirgacha **umuman ishlatmagan** ma'lumotni sinaydi:
  - tick faolligi;
  - dollar (EURUSD);
  - volatillik portlashi.
- B–E olib tashlandi. A nazorat guruhi bo'lib qoladi.

## Umumiy qoidalar

- TP yo'q. Ikki trailing chiqish (M1 shkalasida):
  - **S:** stop M1 oyog'ining HIMOYAsidan ATR(M1) × 0.25 narida. Faqat M1 oyog'i savdo tomonida va tasdiqlangan bo'lsa suriladi.
  - **X:** stop eng yaxshi narxdan ATR(M1) × 3 orqada.
- **Xarajat filtri:** boshlang'ich xavf kamida **10 spread**. Ya'ni spread xavfning 10% idan oshmaydi, aks holda signal o'tkaziladi.
- **Sirpanish:** stopda zararga ATR(M5) × 0.05. Gapda haqiqiy narx.
- Natija R da. MFE / MAE yoziladi.
- Har gipoteza va chiqish juftida bir vaqtda bitta savdo.

## Gipotezalar

| | Nomi | Kirish (M1 bar yopilganda) | Boshlang'ich stop |
|---|---|---|---|
| **F** | faollik | Bar tick hajmi oldingi 30 bar medianasidan ≥ 3 barobar. Tana ≥ ATR(M1). Yopilish o'sha tomondagi 25% da. Shu tomonga kiriladi | Bar narigi uchidan ATR(M1) × 0.25 narida |
| **G** | dollar | EURUSD'ning shu daqiqadagi M1 bari: tana ≥ o'z ATR(M1), yopilish chekka 25% da. Oltin shu daqiqada o'sha tomonga ATR(M1) × 0.3 dan ko'p yurmagan. Oltinda **EURUSD tomoniga** (dollarga teskari) kiriladi | Kirishdan ATR(M1) × 2 |
| **H** | portlash | M1 shami diapazoni ≥ oldingi ATR(M1) × 4, tana ≥ diapazonning yarmi. Keyingi 10 bar ichida birinchi teskari yopilgan bar — qaytish. Narx qaytish barining portlash tomondagi uchini buzganda (tickda) portlash tomoniga kiriladi | Qaytish barining narigi uchidan ATR(M1) × 0.25 narida |

Asoslar:
- **F:** katta o'yinchi kirganda tick tezlashadi. Bu harakat davom etadimi?
- **G:** oltin dollarga teskari yuradi. EURUSD birinchi harakat qilsa, oltin kechikib ergashadimi?
- **H:** katta yangilik harakati bir zumda tugamaydi degan taxmin.

## Sinov

- **Tester:** XAUUSDm, **2 yil**, faqat **Every tick based on real ticks**. OHLC'da break va tor stoplar noto'g'ri baholanadi, simulyatsiyada tasdiqlangan.
- EURUSDm tarixini tester o'zi yuklaydi.
- **Topish davri:** birinchi 2/3 (~16 oy). **Tasdiqlash davri:** oxirgi 1/3 (~8 oy).

## O'tish mezoni (F, G, H uchun 6 juft)

1. **Topish davrida:** kamida 60 savdo, o'rtacha R > 0 va **t ≥ 2.4**. 6 ta qator sinalgani uchun oshirilgan chegara.
2. **Tasdiqlash davrida:** kamida 25 savdo, o'rtacha R > 0 va t ≥ 1.65.
3. O'tganlar Shartnomaga kiradi: sent hisob, lot, 50% stop budjeti.
4. Hech biri o'tmasa, XAUUSD scalp yopiladi. Keyingi yo'nalish — katta TF trend (D1), ko'p yillik tarixda.

A (nazorat) eski mezonda (t ≥ 2.6) baholanadi.
