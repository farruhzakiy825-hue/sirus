//+------------------------------------------------------------------+
//| SirusV9 - 60_Olchov                                              |
//| Savol: shu holatda Sirus ko'radimi, yoki ko'rmi?                 |
//|                                                                  |
//| Har yopilgan M1 shamida xayoliy BUY va SELL ochiladi (savdo yo'q)|
//| ikki xil TP bilan (har tomon va TP turida bir vaqtda bittadan -   |
//| natijalar mustaqil bo'lsin), har tickda hal qilinadi (TP yoki stop -|
//| qaysi biri avval). Har biri oyoq holati katagiga yoziladi:       |
//|   tomon x oyoqqa nisbat (bilan / qarshi) x M5 bosqich x qaytish  |
//|   zonasi x H1 xaritasi (bilan / neytral / qarshi) x M1 qadam     |
//| Stop = oyoqning o'lim chizig'i (oyoq bilan: HIMOYA, oyoqqa       |
//| qarshi: EKSTREMUM), ATR(M5) x 0.15 narida.                       |
//|                                                                  |
//| KUTILGAN NATIJA nazariy formula bilan EMAS, shu bozordagi xuddi  |
//| shunday masofali BARCHA xayoliy savdolarning haqiqiy natijasi    |
//| bilan olinadi. Nazariy b/(a+b) narx uzluksiz deb hisoblaydi;     |
//| real narx ticklar orasida sakraydi va TP yaqin / stop uzoq       |
//| kataklarni tizimli ravishda soxta salbiy qilib qo'yadi (sintetik |
//| tasodifiy bozorda shunday chiqdi). Shuning uchun savol aniq:     |
//| "oyoq holatini bilish faqat masofani bilishdan ko'ra ko'proq     |
//| narsa beradimi?" Sakrash ham, spread ham o'z-o'zidan hisobda.    |
//|                                                                  |
//| Baho: z >= 2 ustunlik bor, z <= -2 salbiy, 30 dan kam noma'lum.  |
//| O'LCHOV faqat ko'rsatadi; Shartnomada (3-bosqich) u faqat blok   |
//| QO'SHISHI mumkin - vetolarni yumshatmaydi.                       |
//|                                                                  |
//| Fayllar (umumiy papka): live va tester jadvallari alohida; live  |
//| tester jadvalini faqat o'qiydi; tester o'zini qayta yuklamaydi.  |
//+------------------------------------------------------------------+

struct SVTrade
{
   bool     on;
   int      side;
   int      mode;
   int      cell;
   int      bin;      // masofa nisbati bo'lagi
   double   tpLvl;    // bid darajasi
   double   stLvl;    // bid darajasi
   double   base;     // nazariy b/(a+b) (faqat CSV uchun)
   datetime t;        // ochilgan vaqt
};

SVTrade g_vt[OL_VMAX];
int     g_olN[OL_MODES][OL_CELLS];               // ochilgan
int     g_olTo[OL_MODES][OL_CELLS];              // vaqti tugadi
int     g_olBn[OL_MODES][OL_CELLS][OL_BINS];     // hal bo'lgan, bo'lak bo'yicha
int     g_olBt[OL_MODES][OL_CELLS][OL_BINS];     // shulardan TP
double  g_olBase[OL_MODES][OL_CELLS];            // nazariy ehtimollar yig'indisi
int     g_oltBn[OL_MODES][OL_CELLS][OL_BINS];    // tester jadvali (faqat o'qish)
int     g_oltBt[OL_MODES][OL_CELLS][OL_BINS];
int     g_poolN[OL_MODES][OL_BINS];              // hamma kataklar yig'indisi (live + tester)
int     g_poolT[OL_MODES][OL_BINS];
long    g_olTotal = 0;
long    g_oltTotal = 0;
datetime g_olSaved = 0;
datetime g_olLastBar = 0;
int     g_olCellNow[2] = {-1, -1};               // shu lahza katagi: [0] SELL, [1] BUY
int     g_olOpen[OL_MODES][2];                   // ochiq xayoliy savdolar: [tp turi][0 SELL / 1 BUY]

bool V9OlTester()
{
   return (MQLInfoInteger(MQL_TESTER) != 0);
}

string V9OlFile(const bool tester)
{
   return tester ? "SirusV9_Olchov_TESTER_" + _Symbol + ".bin" : "SirusV9_Olchov_" + _Symbol + ".bin";
}

//--- Shu lahzaning katagi, `side` (+1 BUY / -1 SELL) nuqtai nazaridan. -1 = M5 oyog'i yo'q.
int V9OlCell(const int side)
{
   if(!g_lv[V9_M5].ok)
      return -1;
   int st = g_lv[V9_M5].stage - STG_TUGILDI;
   if(st < 0 || st > 4)
      return -1;
   int legRel = (g_lv[V9_M5].dir == side) ? 1 : 0;
   int zc = g_lv[V9_M5].zone;
   int z = (zc <= PBZ_SAYOZ) ? 0 : ((zc == PBZ_OLTIN) ? 1 : ((zc == PBZ_CHUQUR) ? 2 : 3));
   int mp = V9Sign(g_mapState[V9_H1]) * side + 1;
   int qd = g_qd.dir * side + 1;
   int si = (side > 0) ? 1 : 0;
   return ((((si * 2 + legRel) * 5 + st) * 4 + z) * 3 + mp) * 3 + qd;
}

string V9OlCellText(const int cell)
{
   if(cell < 0)
      return "oyoq yo'q";
   int c = cell;
   int qd = c % 3; c /= 3;
   int mp = c % 3; c /= 3;
   int z = c % 4;  c /= 4;
   int st = c % 5; c /= 5;
   int legRel = c % 2;
   string zn[4] = {"yurish/sayoz", "oltin", "chuqur", "himoya oldi"};
   string rel[3] = {"qarshi", "neytral", "bilan"};
   string s = (legRel == 1) ? "oyoq bilan" : "oyoqqa qarshi";
   s = s + " · " + V9StageName(st + STG_TUGILDI) + " · " + zn[z] + " · H1 " + rel[mp] + " · qadam " + rel[qd];
   return s;
}

//--- Kichik TP (V8 cashback formulasi) yoki o'rta TP (ATR(M15)), narx birligida.
double V9OlTp(const int mode, const double spread)
{
   if(mode == 0)
   {
      double sp = MathMin(spread / _Point, (double)OL_CB_SPREAD_CAP);
      return (sp * OL_CB_SPREAD_K + OL_CB_ADD_PTS) * _Point;
   }
   return V9Atr(V9_M15);
}

void V9OlOpen(const int side, const int cell, const datetime t)
{
   double bid = V9Bid();
   double s = V9Spread();
   double atr5 = V9Atr(V9_M5);
   double atr15 = V9Atr(V9_M15);
   if(bid <= 0.0 || s < 0.0 || atr5 <= 0.0 || atr15 <= 0.0 || cell < 0)
      return;
   bool withLeg = (g_lv[V9_M5].dir == side);
   double ref = withLeg ? g_lv[V9_M5].himoya : g_lv[V9_M5].ext;
   double stop = ref - side * OL_STOP_BUF_ATR5 * atr5;
   // Bid makonida: BUY ask da kiradi (bid + s); SELL ning stopi ask da, ya'ni bid da s ga yaqinroq.
   double b = (side > 0) ? bid - stop : (stop - s) - bid;
   if(b <= 0.0)
      return;   // narx allaqachon o'lim chizig'ida - savdo bo'lmaydi
   double bMax = OL_STOP_MAX_ATR15 * atr15;
   if(b > bMax)
      b = bMax;
   int si = (side > 0) ? 1 : 0;
   for(int mode = 0; mode < OL_MODES; mode++)
   {
      // MUSTAQILLIK: shu tomon va TP turida oldingi xayoliy savdo hali ochiq bo'lsa - yangisi ochilmaydi.
      // Har daqiqada ustma-ust ochilgan savdolar bitta narx harakati bilan birga hal bo'ladi va z ni yolg'on
      // katta qiladi (tasodifiy bozorda ham "ustunlik" chiqardi). Ketma-ket, ustma-ust tushmaydigan savdolar
      // bir-biridan mustaqil.
      if(g_olOpen[mode][si] > 0)
         continue;
      double tp = V9OlTp(mode, s);
      if(tp <= 0.0)
         continue;
      double a = s + tp;
      int slot = -1;
      for(int i = 0; i < OL_VMAX; i++)
         if(!g_vt[i].on) { slot = i; break; }
      if(slot < 0)
         return;
      double base = b / (a + b);
      g_vt[slot].on = true;
      g_vt[slot].side = side;
      g_vt[slot].mode = mode;
      g_vt[slot].cell = cell;
      g_vt[slot].bin = MathMax(0, MathMin(OL_BINS - 1, (int)(base * OL_BINS)));
      g_vt[slot].tpLvl = (side > 0) ? bid + a : bid - a;
      g_vt[slot].stLvl = (side > 0) ? bid - b : bid + b;
      g_vt[slot].base = base;
      g_vt[slot].t = t;
      g_olN[mode][cell]++;
      g_olOpen[mode][si]++;
   }
}

void V9OlClose(const int i)
{
   int si = (g_vt[i].side > 0) ? 1 : 0;
   if(g_olOpen[g_vt[i].mode][si] > 0)
      g_olOpen[g_vt[i].mode][si]--;
   g_vt[i].on = false;
}

void V9OlBook(const int i, const bool tp)
{
   int m = g_vt[i].mode, c = g_vt[i].cell, k = g_vt[i].bin;
   g_olBn[m][c][k]++;
   g_poolN[m][k]++;
   if(tp)
   {
      g_olBt[m][c][k]++;
      g_poolT[m][k]++;
   }
   g_olBase[m][c] += g_vt[i].base;
   g_olTotal++;
   V9OlClose(i);
}

//--- Har tickda: ochiq xayoliy savdolar shu narxda TP ga yoki stopga tegdimi.
void V9OlTick()
{
   double bid = V9Bid();
   datetime now = TimeCurrent();
   if(bid <= 0.0)
      return;
   for(int i = 0; i < OL_VMAX; i++)
   {
      if(!g_vt[i].on)
         continue;
      int side = g_vt[i].side;
      bool tpHit = (side > 0) ? (bid >= g_vt[i].tpLvl) : (bid <= g_vt[i].tpLvl);
      bool stHit = (side > 0) ? (bid <= g_vt[i].stLvl) : (bid >= g_vt[i].stLvl);
      if(stHit)
         V9OlBook(i, false);
      else if(tpHit)
         V9OlBook(i, true);
      else if(now - g_vt[i].t >= OL_TIMEOUT_MIN * 60)
      {
         g_olTo[g_vt[i].mode][g_vt[i].cell]++;
         V9OlClose(i);
      }
   }
}

//--- Har yangi M1 barda (oyoq / xarita / qadam hisoblangandan keyin) chaqiriladi.
void V9OlStep()
{
   int n = g_nbar[V9_M1];
   if(!g_ready[V9_M1] || !g_ready[V9_M5] || !g_ready[V9_H1] || n < 2)
      return;
   datetime bt = g_bar[V9_M1][n - 1].t;
   if(bt == g_olLastBar)
      return;
   g_olLastBar = bt;
   datetime t = g_bar[V9_M1][n - 1].tc;
   for(int side = -1; side <= 1; side += 2)
      V9OlOpen(side, V9OlCell(side), t);
}

//--- Shu lahza katagi (panel uchun; har tickda arzon).
void V9OlNow()
{
   g_olCellNow[0] = V9OlCell(-1);
   g_olCellNow[1] = V9OlCell(1);
}

//--- Katak bahosi (live + tester). n = hal bo'lganlar, p = TP ulushi, pe = kutilgan ulush, z.
bool V9OlStat(const int mode, const int cell, int &n, double &p, double &pe, double &z)
{
   n = 0;
   p = 0.0;
   pe = 0.0;
   z = 0.0;
   if(cell < 0 || mode < 0 || mode >= OL_MODES)
      return false;
   int tp = 0;
   double e = 0.0, v = 0.0;
   for(int k = 0; k < OL_BINS; k++)
   {
      int nk = g_olBn[mode][cell][k] + g_oltBn[mode][cell][k];
      if(nk <= 0 || g_poolN[mode][k] <= 0)
         continue;
      double r = (double)g_poolT[mode][k] / g_poolN[mode][k];
      n += nk;
      tp += g_olBt[mode][cell][k] + g_oltBt[mode][cell][k];
      e += nk * r;
      v += nk * r * (1.0 - r);
   }
   if(n <= 0)
      return false;
   p = (double)tp / n;
   pe = e / n;
   z = (tp - e) / MathSqrt(MathMax(1e-9, v));
   return true;
}

//--- -1 salbiy, 0 neytral, +1 ustunlik bor, -9 noma'lum (namuna kam)
int V9OlVerdict(const int mode, const int cell)
{
   int n;
   double p, pe, z;
   if(!V9OlStat(mode, cell, n, p, pe, z) || n < OL_MIN_N)
      return -9;
   if(z >= OL_Z_SIG) return 1;
   if(z <= -OL_Z_SIG) return -1;
   return 0;
}

string V9OlVerdictName(const int v)
{
   if(v == 1)  return "ustunlik bor";
   if(v == -1) return "salbiy";
   if(v == 0)  return "neytral";
   return "noma'lum";
}

//--- "n 134 · TP 62% / kutilgan 48% · +14"
string V9OlStatText(const int mode, const int cell)
{
   int n;
   double p, pe, z;
   if(!V9OlStat(mode, cell, n, p, pe, z))
      return "namuna yo'q";
   return StringFormat("n %d · TP %.0f%% / kutilgan %.0f%% · %+.0f", n, p * 100.0, pe * 100.0, (p - pe) * 100.0);
}

void V9OlPoolRebuild()
{
   for(int m = 0; m < OL_MODES; m++)
      for(int k = 0; k < OL_BINS; k++)
      {
         g_poolN[m][k] = 0;
         g_poolT[m][k] = 0;
         for(int c = 0; c < OL_CELLS; c++)
         {
            g_poolN[m][k] += g_olBn[m][c][k] + g_oltBn[m][c][k];
            g_poolT[m][k] += g_olBt[m][c][k] + g_oltBt[m][c][k];
         }
      }
}

//--- Fayl: versiya, o'lchamlar, keyin jadval.
bool V9OlWrite(const string name)
{
   int h = FileOpen(name, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteInteger(h, OL_FILE_VER, INT_VALUE);
   FileWriteInteger(h, OL_MODES, INT_VALUE);
   FileWriteInteger(h, OL_CELLS, INT_VALUE);
   FileWriteInteger(h, OL_BINS, INT_VALUE);
   FileWriteLong(h, g_olTotal);
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         FileWriteInteger(h, g_olN[m][c], INT_VALUE);
         FileWriteInteger(h, g_olTo[m][c], INT_VALUE);
         FileWriteDouble(h, g_olBase[m][c]);
         for(int k = 0; k < OL_BINS; k++)
         {
            FileWriteInteger(h, g_olBn[m][c][k], INT_VALUE);
            FileWriteInteger(h, g_olBt[m][c][k], INT_VALUE);
         }
      }
   FileClose(h);
   return true;
}

//--- Faylni o'qiydi. intoTester = true: tester jadvaliga (faqat o'qish), aks holda live jadvalga.
bool V9OlRead(const string name, const bool intoTester)
{
   if(!FileIsExist(name, FILE_COMMON))
      return false;
   int h = FileOpen(name, FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   int ver = FileReadInteger(h, INT_VALUE);
   int modes = FileReadInteger(h, INT_VALUE);
   int cells = FileReadInteger(h, INT_VALUE);
   int bins = FileReadInteger(h, INT_VALUE);
   if(ver != OL_FILE_VER || modes != OL_MODES || cells != OL_CELLS || bins != OL_BINS)
   {
      FileClose(h);
      PrintFormat("[SIRUS V9 O'LCHOV] %s boshqa formatda (%d) - o'qilmadi", name, ver);
      return false;
   }
   long total = FileReadLong(h);
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         int n = FileReadInteger(h, INT_VALUE);
         int to = FileReadInteger(h, INT_VALUE);
         double base = FileReadDouble(h);
         if(!intoTester)
         {
            g_olN[m][c] = n;
            g_olTo[m][c] = to;
            g_olBase[m][c] = base;
         }
         for(int k = 0; k < OL_BINS; k++)
         {
            int bn = FileReadInteger(h, INT_VALUE);
            int bt = FileReadInteger(h, INT_VALUE);
            if(intoTester)
            {
               g_oltBn[m][c][k] = bn;
               g_oltBt[m][c][k] = bt;
            }
            else
            {
               g_olBn[m][c][k] = bn;
               g_olBt[m][c][k] = bt;
            }
         }
      }
   FileClose(h);
   if(intoTester) g_oltTotal = total;
   else           g_olTotal = total;
   return true;
}

//--- O'qiladigan nusxa (CSV): faqat namunasi bor kataklar.
void V9OlWriteCsv(const bool tester)
{
   string name = tester ? "SirusV9_Olchov_TESTER_" + _Symbol + ".csv" : "SirusV9_Olchov_" + _Symbol + ".csv";
   int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, "tp_turi;tomon;katak;natija;tp;vaqti_tugadi;tp_ulushi;kutilgan;ustunlik;z;baho;nazariy_tasodif\r\n");
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         int n;
         double p, pe, z;
         if(!V9OlStat(m, c, n, p, pe, z))
            continue;
         int tpc = (int)MathRound(p * n);
         string verdict = V9OlVerdictName(V9OlVerdict(m, c));
         string side = (c >= OL_CELLS / 2) ? "BUY" : "SELL";
         int own = 0;
         for(int k = 0; k < OL_BINS; k++)
            own += g_olBn[m][c][k];
         double theo = (own > 0) ? g_olBase[m][c] / own : 0.0;
         FileWriteString(h, StringFormat("%s;%s;%s;%d;%d;%d;%.3f;%.3f;%+.3f;%.2f;%s;%.3f\r\n",
                                         (m == 0 ? "kichik" : "orta"), side, V9OlCellText(c), n, tpc, g_olTo[m][c],
                                         p, pe, p - pe, z, verdict, theo));
      }
   FileClose(h);
}

void V9OlInit()
{
   for(int i = 0; i < OL_VMAX; i++)
      g_vt[i].on = false;
   for(int m = 0; m < OL_MODES; m++)
   {
      g_olOpen[m][0] = 0;
      g_olOpen[m][1] = 0;
   }
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         g_olN[m][c] = 0;
         g_olTo[m][c] = 0;
         g_olBase[m][c] = 0.0;
         for(int k = 0; k < OL_BINS; k++)
         {
            g_olBn[m][c][k] = 0;
            g_olBt[m][c][k] = 0;
            g_oltBn[m][c][k] = 0;
            g_oltBt[m][c][k] = 0;
         }
      }
   g_olTotal = 0;
   g_oltTotal = 0;
   g_olLastBar = 0;
   g_olSaved = TimeCurrent();
   if(!V9OlTester())   // tester har doim toza boshlaydi va oxirida o'z faylini yozadi
   {
      if(V9OlRead(V9OlFile(false), false))
         PrintFormat("[SIRUS V9 O'LCHOV] live jadval yuklandi: %d natija", (int)g_olTotal);
      if(V9OlRead(V9OlFile(true), true))
         PrintFormat("[SIRUS V9 O'LCHOV] tester jadvali qo'shildi (faqat o'qish): %d natija", (int)g_oltTotal);
   }
   V9OlPoolRebuild();
}

void V9OlSave(const bool final)
{
   if(MQLInfoInteger(MQL_OPTIMIZATION) != 0)
      return;
   bool tester = V9OlTester();
   if(tester && !final)
      return;
   if(!final && TimeCurrent() - g_olSaved < OL_SAVE_SEC)
      return;
   g_olSaved = TimeCurrent();
   if(V9OlWrite(V9OlFile(tester)))
      V9OlWriteCsv(tester);
}
