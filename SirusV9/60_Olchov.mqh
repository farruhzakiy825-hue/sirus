//+------------------------------------------------------------------+
//| SirusV9 - 60_Olchov                                              |
//| Savol: shu holatda Sirus ko'radimi, yoki ko'rmi?                 |
//|                                                                  |
//| Har yopilgan M1 shamida xayoliy BUY va SELL ochiladi (savdo yo'q)|
//| ikki xil TP bilan. Har biri oyoq holati katagiga yoziladi:       |
//|   tomon x oyoqqa nisbat (bilan / qarshi) x M5 bosqich x qaytish  |
//|   zonasi x H1 xaritasi (bilan / neytral / qarshi) x M1 qadam     |
//| Stop = oyoqning o'lim chizig'i (oyoq bilan: HIMOYA, oyoqqa       |
//| qarshi: EKSTREMUM), ATR(M5) x 0.15 narida - savdo shu yerda      |
//| noto'g'ri bo'lardi.                                              |
//|                                                                  |
//| Har natija TASODIF bilan solishtiriladi: TP masofasi a, stop     |
//| masofasi b bo'lsa, tasodifiy narx TP ga avval yetishi = b/(a+b). |
//| Ustunlik = haqiqiy TP ulushi - tasodifiy ulush (z >= 2 = ishonch-|
//| li). Bu O'LCHOV faqat ko'rsatadi; qaror Shartnomada (3-bosqich), |
//| va u faqat blok QO'SHISHI mumkin - vetolarni yumshatmaydi.       |
//|                                                                  |
//| Fayllar (umumiy papka): live jadval va tester jadvali alohida;   |
//| live tester jadvalini faqat o'qiydi; tester o'zini qayta         |
//| yuklamaydi (bir davrni ikki marta sanamaslik uchun).             |
//+------------------------------------------------------------------+

#define OL_RES_TP     1
#define OL_RES_STOP   2

struct SVTrade
{
   bool     on;
   int      side;
   int      mode;
   int      cell;
   double   tpLvl;    // bid darajasi
   double   stLvl;    // bid darajasi
   double   base;     // tasodifiy ehtimol b/(a+b)
   datetime t;        // ochilgan vaqt (M1 bar yopilishi)
};

SVTrade g_vt[OL_VMAX];
int     g_olN[OL_MODES][OL_CELLS];      // ochilgan
int     g_olTp[OL_MODES][OL_CELLS];
int     g_olSt[OL_MODES][OL_CELLS];
int     g_olTo[OL_MODES][OL_CELLS];     // vaqti tugadi
double  g_olBase[OL_MODES][OL_CELLS];   // hal bo'lganlarning tasodifiy ehtimollari yig'indisi
int     g_oltTp[OL_MODES][OL_CELLS];    // tester jadvali (faqat o'qish)
int     g_oltSt[OL_MODES][OL_CELLS];
double  g_oltBase[OL_MODES][OL_CELLS];
long    g_olTotal = 0;
long    g_oltTotal = 0;
datetime g_olSaved = 0;
datetime g_olLastBar = 0;
int     g_olCellNow[2] = {-1, -1};      // shu lahza katagi: [0] SELL, [1] BUY

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
   // Bid makonida: BUY ask da kiradi (bid + s), SELL ask bo'yicha yopiladi (stop bid da s ga yaqinroq).
   double b = (side > 0) ? bid - stop : (stop - s) - bid;
   if(b <= 0.0)
      return;   // narx allaqachon o'lim chizig'ida - savdo bo'lmaydi
   double bMax = OL_STOP_MAX_ATR15 * atr15;
   if(b > bMax)
      b = bMax;
   for(int mode = 0; mode < OL_MODES; mode++)
   {
      double tp = V9OlTp(mode, s);
      if(tp <= 0.0)
         continue;
      double a = s + tp;
      int slot = -1;
      for(int i = 0; i < OL_VMAX; i++)
         if(!g_vt[i].on) { slot = i; break; }
      if(slot < 0)
         return;   // to'la (bo'lmasligi kerak: 4 ta x 120 daqiqa < 640)
      g_vt[slot].on = true;
      g_vt[slot].side = side;
      g_vt[slot].mode = mode;
      g_vt[slot].cell = cell;
      g_vt[slot].tpLvl = (side > 0) ? bid + a : bid - a;
      g_vt[slot].stLvl = (side > 0) ? bid - b : bid + b;
      g_vt[slot].base = b / (a + b);
      g_vt[slot].t = t;
      g_olN[mode][cell]++;
   }
}

//--- Yangi yopilgan M1 bar bilan ochiq xayoliy savdolarni hal qiladi.
void V9OlResolve(const datetime barT, const double h, const double l)
{
   for(int i = 0; i < OL_VMAX; i++)
   {
      if(!g_vt[i].on || g_vt[i].t > barT)
         continue;   // shu bar boshlanganidan keyin ochilgan
      int side = g_vt[i].side;
      bool tpHit = (side > 0) ? (h >= g_vt[i].tpLvl) : (l <= g_vt[i].tpLvl);
      bool stHit = (side > 0) ? (l <= g_vt[i].stLvl) : (h >= g_vt[i].stLvl);
      int m = g_vt[i].mode, c = g_vt[i].cell;
      if(stHit)
      {
         // Bir barda ikkalasi ham tegsa - stop (ehtiyotkor hisob: bar ichida qaysi biri avval ekani noma'lum).
         g_olSt[m][c]++;
         g_olBase[m][c] += g_vt[i].base;
         g_olTotal++;
         g_vt[i].on = false;
      }
      else if(tpHit)
      {
         g_olTp[m][c]++;
         g_olBase[m][c] += g_vt[i].base;
         g_olTotal++;
         g_vt[i].on = false;
      }
      else if(barT + 60 - g_vt[i].t >= OL_TIMEOUT_MIN * 60)
      {
         g_olTo[m][c]++;
         g_vt[i].on = false;
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
   V9OlResolve(bt, g_bar[V9_M1][n - 1].h, g_bar[V9_M1][n - 1].l);
   datetime t = g_bar[V9_M1][n - 1].tc;
   for(int side = -1; side <= 1; side += 2)
   {
      int cell = V9OlCell(side);
      V9OlOpen(side, cell, t);
   }
}

//--- Shu lahza katagi (panel uchun; har tickda arzon).
void V9OlNow()
{
   g_olCellNow[0] = V9OlCell(-1);
   g_olCellNow[1] = V9OlCell(1);
}

//--- Katak bahosi (live + tester). Natija: hal bo'lganlar, TP ulushi, tasodifiy ulush, z.
bool V9OlStat(const int mode, const int cell, int &n, double &p, double &pb, double &z)
{
   n = 0;
   p = 0.0;
   pb = 0.0;
   z = 0.0;
   if(cell < 0 || mode < 0 || mode >= OL_MODES)
      return false;
   int tp = g_olTp[mode][cell] + g_oltTp[mode][cell];
   int st = g_olSt[mode][cell] + g_oltSt[mode][cell];
   double base = g_olBase[mode][cell] + g_oltBase[mode][cell];
   n = tp + st;
   if(n <= 0)
      return false;
   p = (double)tp / n;
   pb = base / n;
   double se = MathSqrt(MathMax(1e-9, pb * (1.0 - pb)) / n);
   z = (p - pb) / se;
   return true;
}

//--- -1 salbiy, 0 neytral, +1 ustunlik bor, -9 noma'lum (namuna kam)
int V9OlVerdict(const int mode, const int cell)
{
   int n;
   double p, pb, z;
   if(!V9OlStat(mode, cell, n, p, pb, z) || n < OL_MIN_N)
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

//--- "n 134 · TP 62% / tasodif 48% · +14"
string V9OlStatText(const int mode, const int cell)
{
   int n;
   double p, pb, z;
   if(!V9OlStat(mode, cell, n, p, pb, z))
      return "namuna yo'q";
   return StringFormat("n %d · TP %.0f%% / tasodif %.0f%% · %+.0f", n, p * 100.0, pb * 100.0, (p - pb) * 100.0);
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
   FileWriteLong(h, g_olTotal);
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         FileWriteInteger(h, g_olN[m][c], INT_VALUE);
         FileWriteInteger(h, g_olTp[m][c], INT_VALUE);
         FileWriteInteger(h, g_olSt[m][c], INT_VALUE);
         FileWriteInteger(h, g_olTo[m][c], INT_VALUE);
         FileWriteDouble(h, g_olBase[m][c]);
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
   if(ver != OL_FILE_VER || modes != OL_MODES || cells != OL_CELLS)
   {
      FileClose(h);
      PrintFormat("[SIRUS V9 O'LCHOV] %s eski formatda (%d) - o'qilmadi", name, ver);
      return false;
   }
   long total = FileReadLong(h);
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         int n = FileReadInteger(h, INT_VALUE);
         int tp = FileReadInteger(h, INT_VALUE);
         int st = FileReadInteger(h, INT_VALUE);
         int to = FileReadInteger(h, INT_VALUE);
         double base = FileReadDouble(h);
         if(intoTester)
         {
            g_oltTp[m][c] = tp;
            g_oltSt[m][c] = st;
            g_oltBase[m][c] = base;
         }
         else
         {
            g_olN[m][c] = n;
            g_olTp[m][c] = tp;
            g_olSt[m][c] = st;
            g_olTo[m][c] = to;
            g_olBase[m][c] = base;
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
   FileWriteString(h, "tp_turi;tomon;katak;n;tp;stop;vaqti_tugadi;tp_ulushi;tasodif;ustunlik;z;baho\r\n");
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         int res = g_olTp[m][c] + g_olSt[m][c];
         if(res <= 0)
            continue;
         double p = (double)g_olTp[m][c] / res;
         double pb = g_olBase[m][c] / res;
         double se = MathSqrt(MathMax(1e-9, pb * (1.0 - pb)) / res);
         double z = (p - pb) / se;
         string verdict = (res < OL_MIN_N) ? "noma'lum" : ((z >= OL_Z_SIG) ? "ustunlik bor" : ((z <= -OL_Z_SIG) ? "salbiy" : "neytral"));
         string side = (c >= OL_CELLS / 2) ? "BUY" : "SELL";
         FileWriteString(h, StringFormat("%s;%s;%s;%d;%d;%d;%d;%.3f;%.3f;%+.3f;%.2f;%s\r\n",
                                         (m == 0 ? "kichik" : "orta"), side, V9OlCellText(c), res,
                                         g_olTp[m][c], g_olSt[m][c], g_olTo[m][c], p, pb, p - pb, z, verdict));
      }
   FileClose(h);
}

void V9OlInit()
{
   for(int i = 0; i < OL_VMAX; i++)
      g_vt[i].on = false;
   for(int m = 0; m < OL_MODES; m++)
      for(int c = 0; c < OL_CELLS; c++)
      {
         g_olN[m][c] = 0;
         g_olTp[m][c] = 0;
         g_olSt[m][c] = 0;
         g_olTo[m][c] = 0;
         g_olBase[m][c] = 0.0;
         g_oltTp[m][c] = 0;
         g_oltSt[m][c] = 0;
         g_oltBase[m][c] = 0.0;
      }
   g_olTotal = 0;
   g_oltTotal = 0;
   g_olLastBar = 0;
   g_olSaved = TimeCurrent();
   if(V9OlTester())
      return;   // tester har doim toza boshlaydi va oxirida o'z faylini yozadi
   if(V9OlRead(V9OlFile(false), false))
      PrintFormat("[SIRUS V9 O'LCHOV] live jadval yuklandi: %d natija", (int)g_olTotal);
   if(V9OlRead(V9OlFile(true), true))
      PrintFormat("[SIRUS V9 O'LCHOV] tester jadvali qo'shildi (faqat o'qish): %d natija", (int)g_oltTotal);
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
