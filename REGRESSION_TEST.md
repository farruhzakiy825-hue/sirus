# Regression test holatlari

Har bir yangi bosqichdan keyin shu holatlar tester'da qayta o'ynatiladi. Natija oldingi bilan
solishtiriladi.

## Holat №1: 4126 SELL (2026-10-06, broker vaqti 06:15)

**Bozor:** XAUUSD H4 dealing range ≈ 4110–4192. Narx 4110.5 dagi pastki likvidlikni yechib oldi
(wick ≈ 4105), 4125 ustiga qaytdi, keyin kuchli bullish H4 shamlar bilan 4160–4175 ga chiqdi.

**Xato:** robot 06:15 da 4126 da SELL ochgan.

**Kutilgan natija (yangi engine'dan keyin):** 4126 SELL **bloklanadi** (HTF sell-side sweep +
reclaim, discount). Jurnalda veto sababi yoziladi.

### Qanday o'ynatiladi
1. MetaTrader → **Strategy Tester** (Ctrl+R).
2. Expert: `Sirus_Brain_V8`. Symbol: `XAUUSD`. Timeframe: `M1`.
3. Modelling: **Every tick based on real ticks**.
4. Sana: `2026.10.05` – `2026.10.07`. Indikator va struktura tarixini to'plashi uchun bir kun oldindan boshlanadi.
5. **Visual mode** yoqilgan bo'lsin.
6. Inputs: hozirgi live `.set` faylingizni yuklang. `EnableReasonCode = true`, `ReasonCodeToFile = true`.
7. Start. 06:15 atrofida sekinlashtirib kuzating.

### 1-bosqichdan keyin tekshiriladi (Event + Candle Engine)
Jurnalda `[SIRUS EVENT]` qatorlari paydo bo'ladi. 2026-10-06 tongida kutilayotganlar:
- H4 yoki H1 **SWEEP BULLISH** ≈ 4110.5 atrofida (sell-side likvidlik olindi, narx qaytib yopildi);
- keyin RECLAIM, M5 / M15 da MSS yoki BOS BULLISH, bullish DISPLACEMENT.

Agar 06:15 da yana SELL ochilsa, uning Reason Code'ida `EVENTS` va `CONFLICTS` qatorlarida shu
bullish hodisalar ko'rinishi kerak. Bu hali bloklamaydi: veto 4-bosqichda qo'shiladi. Hozir
tekshiramiz: **robot bu hodisalarni ko'ryaptimi?**

### Natijani yuborish
- Tester'ning **Journal** (Журнал) oynasidan `[SIRUS REASON` bilan boshlanadigan qatorlar,
  ayniqsa 06:00–06:30 oralig'idagilar.
- Yoki CSV fayl: tester agent papkasi →
  `Tester\Agent-127.0.0.1-3000\MQL5\Files\Sirus_ReasonCode_XAUUSD_240007.csv`
  (papkani MetaTrader → File → Open Data Folder → yuqoriga `Tester` orqali topasiz).

Har bir SELL yoki BUY uchun quyidagilar ko'rinadi:
`SIGNAL` (qaysi detektor), `WHY`, `SCORE`, `MARKET`, `STRUCTURE`, `TF STATE`, `ZONES`, `LOCATION`,
`NEWS`, `CONFLICTS` (savdoga qarshi bo'lgan dalillar) va `LOT`.
