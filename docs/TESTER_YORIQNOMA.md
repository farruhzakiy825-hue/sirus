# SirusV9 — Strategy Testerda ma'lumot yig'ish

V9 hali savdo qilmaydi. Testerda u bir necha oylik tarixni "ko'rib chiqadi" va uch xil fayl to'ldiradi. Shu fayllar bilan 3-bosqich (Shartnoma) qarorlarini raqamga tayanib qabul qilamiz.

## Sozlash

1. MetaTrader 5 → **View → Strategy Tester** (Ctrl+R).
2. **Expert:** `SirusV9`.
3. **Symbol:** `XAUUSDm`.
4. **Timeframe:** istalgan, masalan M1. Robot M1, M5, M15, H1, H4 ni o'zi o'qiydi.
5. **Date:** oxirgi **2 yil**, "Custom period". Birinchi 2/3 qismida topiladi, oxirgi 1/3 qismida tasdiqlanadi (`docs/GIPOTEZALAR_2.md`).
6. **Modelling:** faqat **Every tick based on real ticks**. F/G/H scalp gipotezalari OHLC'da noto'g'ri baholanadi. EURUSDm tarixi ham avtomatik yuklanadi, birinchi marta biroz vaqt oladi.
7. **Deposit:** 3000 USD (ahamiyati yo'q, savdo bo'lmaydi). **Leverage:** istalgan.
8. **Visual mode:** O'CHIQ. Vizual rejim juda sekin; panel va chizmalar faqat ko'rish uchun.
9. **Optimization:** O'CHIQ.
10. **Start**.

Sinov tugaganda **Journal** oynasida 8 qator chiqadi. Har gipoteza (A, F, G, H) va har chiqish (tuzilma / ATR) uchun bittadan. `EURUSDm topilmadi` degan qator chiqsa, menga ayting:

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

- Kozlar fayli 2 yilda katta bo'ladi (~60 MB). ZIP qilib yuboring.
- Tester O'lchov fayli jonli robotning O'lchov faylini buzmaydi. Jonli robot tester bazasini faqat o'qiydi va "ma'lumot bor" holatga tezroq yetadi.
- Hech qanday order ochilmaydi. Testerda "no trades" ko'rinishi normal.
