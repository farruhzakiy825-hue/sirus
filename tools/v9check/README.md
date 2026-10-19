# V9 tekshiruv vositasi (MetaEditor siz)

MQL5 kodini C++ ga o'girib kompilyatsiya qiladi va sintetik bozorda ishga tushiradi.

```bash
cd tools/v9check
python3 mql2cpp.py ../.. SirusV9.mq5 v9.cpp            # MQL5 -> C++
g++ -std=c++17 -fsyntax-only -Wall -Wextra -Wshadow v9.cpp
g++ -std=c++17 -O1 -g -fsanitize=address,undefined test.cpp -o t
./t 42 0.002                                            # seed, narx sakrashi ehtimoli
./t 42 0 out.json 20 && python3 render.py out.json out.html   # chizma namunasi
```

`test.cpp` tekshiradi:
- swing kelajakka qaramaydi;
- HIMOYA har doim EKSTREMUM orqasida;
- tirik oyoqda yopilish HIMOYA dan narida emas (SINDI o'tkazib yuborilmagan);
- MAQSAD har doim oldinda;
- bosqichlar, zonalar va hovuzlar to'g'ri oraliqda;
- ssenariylar: ko'tarilish oyog'i, MSS, SOXTA tiklanishi, sweep.
