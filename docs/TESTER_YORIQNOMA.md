# SirusV9 — Strategy Testerda ma'lumot yig'ish

V9 hali savdo qilmaydi. Testerda u bir necha oylik tarixni "ko'rib chiqadi" va uch xil fayl to'ldiradi. Shu fayllar bilan 3-bosqich (Shartnoma) qarorlarini raqamga tayanib qabul qilamiz.

## Sozlash

1. MetaTrader 5 → **View → Strategy Tester** (Ctrl+R).
2. **Expert:** `SirusV9`.
3. **Symbol:** `XAUUSDm`.
4. **Timeframe:** istalgan, masalan M1. Robot M1, M5, M15, H1, H4 ni o'zi o'qiydi.
5. **Date:** oxirgi **12 oy**, "Custom period". Gipotezalar shunday davr talab qiladi: 8 oyda topiladi, 4 oyda tasdiqlanadi (`docs/GIPOTEZALAR.md`).
6. **Modelling:** iloji bo'lsa **Every tick based on real ticks**. Juda sekin bo'lsa — **1 minute OHLC**.
7. **Deposit:** 3000 USD (ahamiyati yo'q, savdo bo'lmaydi). **Leverage:** istalgan.
8. **Visual mode:** O'CHIQ. Vizual rejim juda sekin; panel va chizmalar faqat ko'rish uchun.
9. **Optimization:** O'CHIQ.
10. **Start**.

Sinov tugaganda **Journal** oynasida 10 qator chiqadi. Har gipoteza (A–E) va har chiqish (tuzilma / ATR) uchun bittadan:

```
[SIRUS V9 SOYA T] A asos / tuzilma: signal ..., savdo ..., yutgan ..., jami ...R, savdo boshiga ...R
...
```

## Qaysi fayllarni yuborasiz

Papka: MetaTrader → **File → Open Data Folder**, keyin bir pog'ona yuqoriga → `Common\Files`.

Odatdagi to'liq yo'l: `C:\Users\<siz>\AppData\Roaming\MetaQuotes\Terminal\Common\Files`

| Fayl | Nima bor |
|---|---|
| `SirusV9_TESTER_Soya_XAUUSDm.csv` | har soya T savdo: kirish, chiqish, natija R da, MFE / MAE |
| `SirusV9_TESTER_Kozlar_XAUUSDm.csv` | har M5 bar: robot nimani ko'rdi |
| `SirusV9_Olchov_TESTER_XAUUSDm.csv` | O'lchov: 720 holat bo'yicha xayoliy savdolar statistikasi |
| `SirusV9_Olchov_TESTER_XAUUSDm.bin` | O'lchov bazasi (jonli robot uni o'qiydi) |

Har yangi sinov eski tester fayllarini o'zi o'chiradi, shuning uchun bir vaqtda bitta sinov natijasi turadi.

## Muhim

- Kozlar fayli 12 oyda katta bo'ladi (~70 ming qator, ~30 MB). ZIP qilib yuboring.
- Tester O'lchov fayli jonli robotning O'lchov faylini buzmaydi. Jonli robot tester bazasini faqat o'qiydi va "ma'lumot bor" holatga tezroq yetadi.
- Hech qanday order ochilmaydi. Testerda "no trades" ko'rinishi normal.
