//+------------------------------------------------------------------+
//| SirusV9 - 70_Soya                                                |
//| SOYA T: trailing savdo KUZATUVda. Robot "shu yerda kirardim"     |
//| deydi, chartga chizadi va jurnalga yozadi - ORDER YUBORILMAYDI.  |
//|                                                                  |
//| Maqsad: qaysi kirishda haqiqiy ustunlik borligini TOPISH.        |
//| Gipotezalar va sonlar natijadan OLDIN yozilgan:                  |
//|   A - docs/GIPOTEZALAR.md (3 sinovda o'tmadi; nazorat guruhi)    |
//|   F, G, H - docs/GIPOTEZALAR_2.md (scalp, YANGI turdagi ma'lumot)|
//|                                                                  |
//| Kirishlar:                                                       |
//|   A asos     - M5 oyog'i tug'ildi                                |
//|   F faollik  - M1 bar: tick hajmi 3x + kuchli tana -> shu tomon  |
//|   G dollar   - EURUSD M1 da kuchli sham, oltin hali qimirlamagan |
//|                -> oltin EURUSD tomoniga (dollarga teskari)       |
//|   H portlash - M1 portlash shami (>= 4 ATR), birinchi qaytishdan |
//|                keyin portlash tomoniga break                     |
//| Chiqishlar (har kirish ikkalasi bilan alohida o'lchanadi):       |
//|   S tuzilma - stop HIMOYA bilan suriladi (A: M5, F/G/H: M1)      |
//|   X ATR     - stop eng yaxshi narxdan ATR x 3 (A: M5, F/G/H: M1) |
//| Natija R da: R = kirishdan boshlang'ich stopgacha (spread bilan).|
//| MFE / MAE ham yoziladi. TP yo'q.                                 |
//+------------------------------------------------------------------+

// 95_Panel dagi chizish yordamchilari (u bu fayldan keyin ulanadi).
string V9ObjName(const string id);
void   V9ChartText(const string id, const datetime t, const double price, const string text, const color clr);
void   V9ChartDel(const string id);
color  V9Green();
color  V9Red();
color  V9Muted();

#define TH_A   0
#define TH_F   1
#define TH_G   2
#define TH_H   3

struct STrade
{
   bool     on;
   int      dir;
   int      tfx;        // chiqish shkalasi: V9_M5 (A) yoki V9_M1 (F, G, H)
   double   entry;      // BUY: ask, SELL: bid
   double   stop;       // chiqish narxi tomonida: BUY - bid darajasi, SELL - ask darajasi
   double   stop0;
   double   r0;         // boshlang'ich xavf (narx), spread bilan
   double   sEntry;     // kirishdagi spread
   double   best;       // eng yaxshi chiqish narxi (BUY max bid, SELL min ask)
   double   mfe;        // R da
   double   mae;        // R da
   datetime t;
   int      id;
   string   why;
};

STrade   g_t[T_HYP][T_EXIT];
string   g_tWait[T_HYP];           // oxirgi signal nima bo'ldi
int      g_tSig[T_HYP];            // signallar (o'tkazilganlari bilan)
int      g_tIn[T_HYP][T_EXIT];     // kirishlar
int      g_tN[T_HYP][T_EXIT];      // yopilgan
int      g_tWin[T_HYP][T_EXIT];
double   g_tR[T_HYP][T_EXIT];      // jami R
int      g_tSeq = 0;
datetime g_tBornSeen[V9_TF_N];
int      g_tDirSeen[V9_TF_N];
bool     g_tInit[V9_TF_N];

// G: dollar (EURUSD)
string   g_eurSym = "";
bool     g_eurOk = false;

// H: portlash holati
int      g_hDir = 0;               // kutilayotgan portlash tomoni, 0 = yo'q
int      g_hLeft = 0;              // necha M1 bar kutish qoldi
bool     g_hPull = false;          // birinchi qaytish bari bo'ldimi
double   g_hTrig = 0.0;            // qaytish barining portlash tomondagi uchi (break darajasi)
double   g_hStop = 0.0;            // qaytish barining narigi uchi (bid darajasi)

string V9THypId(const int h)
{
   if(h == TH_A) return "A";
   if(h == TH_F) return "F";
   if(h == TH_G) return "G";
   return "H";
}

string V9THypName(const int h)
{
   if(h == TH_A) return "asos";
   if(h == TH_F) return "faollik";
   if(h == TH_G) return "dollar";
   return "portlash";
}

string V9TExitId(const int x)
{
   return (x == 0) ? "S" : "X";
}

string V9TFile()
{
   return V9DailyFile("Soya");
}

string V9THeader()
{
   return "vaqt;gipoteza;chiqish;hodisa;tomon;narx;stop;xavf_narx;natija_R;mfe_R;mae_R;daqiqa;sabab";
}

void V9TDrawEntry(const int h, const int id, const int dir, const datetime t, const double price)
{
   string name = V9ObjName(StringFormat("TY_%d_e", id));
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (dir > 0) ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (dir > 0) ? V9Green() : V9Red());
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, (dir > 0) ? ANCHOR_TOP : ANCHOR_BOTTOM);
   V9ChartText(StringFormat("TY_%d_l", id), t, price, " " + V9THypId(h), V9Muted());
}

void V9TDrawExit(const int id, const datetime t0, const double p0, const datetime t1, const double p1, const bool win)
{
   string ln = V9ObjName(StringFormat("TY_%d_x", id));
   if(ObjectFind(0, ln) < 0)
   {
      ObjectCreate(0, ln, OBJ_TREND, 0, t0, p0, t1, p1);
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_DOT);
   }
   ObjectSetInteger(0, ln, OBJPROP_COLOR, win ? V9Green() : V9Red());
   string mk = V9ObjName(StringFormat("TY_%d_r", id));
   if(ObjectFind(0, mk) < 0)
   {
      ObjectCreate(0, mk, OBJ_ARROW, 0, t1, p1);
      ObjectSetInteger(0, mk, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, mk, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, mk, OBJPROP_ARROWCODE, win ? 252 : 251);   // Wingdings: ✓ / ✗
   ObjectSetInteger(0, mk, OBJPROP_COLOR, win ? V9Green() : V9Red());
   // Chart tozaligi: oxirgi 40 ta soya savdo qoladi.
   int old = id - 40;
   if(old >= 0)
   {
      V9ChartDel(StringFormat("TY_%d_e", old));
      V9ChartDel(StringFormat("TY_%d_l", old));
      V9ChartDel(StringFormat("TY_%d_x", old));
      V9ChartDel(StringFormat("TY_%d_r", old));
   }
}

//--- Shu yopilgan barda yangi oyoq tug'ildimi (SOXTA tiklanishi emas). Har yangi barda BIR marta chaqiriladi.
//--- Birinchi chaqiruv faqat eslab qoladi: ishga tushganda eski oyoq "yangi" deb olinmaydi.
bool V9TFreshBirth(const int tfi)
{
   int n = g_nbar[tfi];
   if(n <= 0)
      return false;
   bool changed = (g_leg[tfi].bornT != g_tBornSeen[tfi] || g_leg[tfi].dir != g_tDirSeen[tfi]);
   bool first = !g_tInit[tfi];
   g_tInit[tfi] = true;
   g_tBornSeen[tfi] = g_leg[tfi].bornT;
   g_tDirSeen[tfi] = g_leg[tfi].dir;
   if(first || !changed || g_leg[tfi].dir == 0)
      return false;
   return (g_leg[tfi].bornT == g_bar[tfi][n - 1].tc);
}

//--- Gipoteza h ning bo'sh joylarida savdo ochadi. stopPx: BUY uchun bid, SELL uchun ask darajasi.
void V9TOpen(const int h, const int dir, const double stopPx, const string why)
{
   double bid = V9Bid(), ask = V9Ask();
   double s = ask - bid;
   double entry = (dir > 0) ? ask : bid;
   double r0 = dir * (entry - stopPx);
   double minK = (h == TH_A) ? T_MIN_R_SPREAD : T_SCALP_R_SPREAD;
   g_tSig[h]++;
   string tm = V9TimeStr(TimeCurrent());
   if(r0 <= 0.0 || r0 < minK * s)
   {
      g_tWait[h] = StringSubstr(tm, 11, 5) + StringFormat(" o'tkazildi: xavf %s < %.0f spread", V9Px(r0), minK);
      return;
   }
   int opened = 0;
   for(int x = 0; x < T_EXIT; x++)
   {
      if(g_t[h][x].on)
         continue;
      g_t[h][x].on = true;
      g_t[h][x].dir = dir;
      g_t[h][x].tfx = (h == TH_A) ? V9_M5 : V9_M1;
      g_t[h][x].entry = entry;
      g_t[h][x].stop = stopPx;
      g_t[h][x].stop0 = stopPx;
      g_t[h][x].r0 = r0;
      g_t[h][x].sEntry = s;
      g_t[h][x].best = (dir > 0) ? bid : ask;
      g_t[h][x].mfe = 0.0;
      g_t[h][x].mae = 0.0;
      g_t[h][x].t = TimeCurrent();
      g_t[h][x].id = g_tSeq;
      g_t[h][x].why = why;
      g_tSeq++;
      g_tIn[h][x]++;
      opened++;
      V9TDrawEntry(h, g_t[h][x].id, dir, g_t[h][x].t, entry);
      V9FileAppend(V9TFile(), V9THeader(),
                   StringFormat("%s;%s;%s;KIRISH;%s;%s;%s;%s;;;;;%s", tm, V9THypId(h), V9TExitId(x), (dir > 0 ? "BUY" : "SELL"),
                                V9Px(entry), V9Px(stopPx), V9Px(r0), why));
   }
   g_tWait[h] = (opened > 0) ? "" : StringSubstr(tm, 11, 5) + " o'tkazildi: ikkala chiqish ham band";
}

void V9TClose(const int h, const int x, const double fill, const string kind)
{
   int d = g_t[h][x].dir;
   double r = d * (fill - g_t[h][x].entry) / g_t[h][x].r0;
   int mins = (int)((TimeCurrent() - g_t[h][x].t) / 60);
   g_tN[h][x]++;
   if(r > 0.0)
      g_tWin[h][x]++;
   g_tR[h][x] += r;
   V9TDrawExit(g_t[h][x].id, g_t[h][x].t, g_t[h][x].entry, TimeCurrent(), fill, r > 0.0);
   V9FileAppend(V9TFile(), V9THeader(),
                StringFormat("%s;%s;%s;%s;%s;%s;%s;%s;%.3f;%.3f;%.3f;%d;%s", V9TimeStr(TimeCurrent()), V9THypId(h), V9TExitId(x), kind,
                             (d > 0 ? "BUY" : "SELL"), V9Px(fill), V9Px(g_t[h][x].stop), V9Px(g_t[h][x].r0), r,
                             g_t[h][x].mfe, g_t[h][x].mae, mins, g_t[h][x].why));
   g_t[h][x].on = false;
}

//--- Bar yopilish joyi 0..1 (0 = low, 1 = high). Diapazon 0 bo'lsa 0.5.
double V9TClosePos(const double h, const double l, const double c)
{
   double rg = h - l;
   return (rg > 0.0) ? (c - l) / rg : 0.5;
}

//--- F: oxirgi yopilgan M1 bar - tick hajmi portlashi + kuchli tana. Yo'nalish yoki 0.
int V9TFaollik(double &volK)
{
   volK = 0.0;
   int n = g_nbar[V9_M1];
   if(n < T_F_VOL_N + 2)
      return 0;
   int k = n - 1;
   double v[];
   ArrayResize(v, T_F_VOL_N);
   for(int i = 0; i < T_F_VOL_N; i++)
      v[i] = g_bar[V9_M1][k - 1 - i].vol;
   ArraySort(v);
   double med = 0.5 * (v[T_F_VOL_N / 2 - 1] + v[T_F_VOL_N / 2]);
   if(med <= 0.0)
      return 0;
   volK = g_bar[V9_M1][k].vol / med;
   if(volK < T_F_VOL_K)
      return 0;
   double o = g_bar[V9_M1][k].o, c = g_bar[V9_M1][k].c;
   double atr1 = g_bar[V9_M1][k - 1].atr;   // shu bargacha bo'lgan ATR (bar o'zini o'lchamaydi)
   if(atr1 <= 0.0 || MathAbs(c - o) < T_F_BODY_ATR1 * atr1)
      return 0;
   double pos = V9TClosePos(g_bar[V9_M1][k].h, g_bar[V9_M1][k].l, c);
   if(c > o && pos >= T_CLOSE_POS)
      return 1;
   if(c < o && pos <= 1.0 - T_CLOSE_POS)
      return -1;
   return 0;
}

//--- G: oltinning oxirgi yopilgan M1 bari bilan bir vaqtdagi EURUSD bari kuchli bo'lsa - uning yo'nalishi.
int V9TDollar(string &why)
{
   why = "";
   if(!g_eurOk)
      return 0;
   int n = g_nbar[V9_M1];
   if(n < 2)
      return 0;
   datetime T = g_bar[V9_M1][n - 1].t;
   if(TimeCurrent() < T + 60)
      return 0;
   MqlRates e[];
   ArraySetAsSeries(e, false);
   int got = CopyRates(g_eurSym, PERIOD_M1, 0, 24, e);
   if(got < 17)
      return 0;
   int j = -1;
   for(int i = got - 1; i >= 0; i--)
      if(e[i].time == T)
      {
         j = i;
         break;
      }
   if(j < 15)
      return 0;
   // EURUSD ATR(M1): oldingi 14 bar (shu barsiz).
   double sum = 0.0;
   for(int i = j - 14; i < j; i++)
   {
      double x = e[i].high - e[i].low;
      x = MathMax(x, MathAbs(e[i].high - e[i - 1].close));
      x = MathMax(x, MathAbs(e[i].low - e[i - 1].close));
      sum += x;
   }
   double atrE = sum / 14.0;
   double body = e[j].close - e[j].open;
   if(atrE <= 0.0 || MathAbs(body) < T_G_BODY_ATR * atrE)
      return 0;
   double pos = V9TClosePos(e[j].high, e[j].low, e[j].close);
   int d = 0;
   if(body > 0.0 && pos >= T_CLOSE_POS) d = 1;
   if(body < 0.0 && pos <= 1.0 - T_CLOSE_POS) d = -1;
   if(d == 0)
      return 0;
   // Oltin shu daqiqada hali o'sha tomonga yurmagan bo'lishi kerak.
   double atr1 = g_bar[V9_M1][n - 2].atr;
   double xm = d * (g_bar[V9_M1][n - 1].c - g_bar[V9_M1][n - 1].o);
   if(atr1 <= 0.0 || xm > T_G_XAU_MAX_ATR1 * atr1)
      return 0;
   why = StringFormat("%s M1 %.1f ATR, oltin %.1f ATR", g_eurSym, MathAbs(body) / atrE, xm / atr1);
   return d;
}

//--- H: M1 yopilganda portlash holatini yuritadi (break tickda tekshiriladi).
void V9TPortlashBar()
{
   int n = g_nbar[V9_M1];
   if(n < 3)
      return;
   int k = n - 1;
   double o = g_bar[V9_M1][k].o, c = g_bar[V9_M1][k].c, hi = g_bar[V9_M1][k].h, lo = g_bar[V9_M1][k].l;
   double atrPrev = g_bar[V9_M1][k - 1].atr;
   // Kutilayotgan portlash: birinchi teskari yopilgan bar - qaytish.
   if(g_hDir != 0)
   {
      g_hLeft--;
      if(!g_hPull && g_hDir * (c - o) < 0.0)
      {
         g_hPull = true;
         g_hTrig = (g_hDir > 0) ? hi : lo;
         g_hStop = (g_hDir > 0) ? lo - T_STOP_BUF_ATR1 * atrPrev : hi + T_STOP_BUF_ATR1 * atrPrev;
      }
      if(g_hLeft <= 0)
         g_hDir = 0;
   }
   // Yangi portlash (eskisining o'rnini egallaydi).
   double rg = hi - lo;
   if(atrPrev > 0.0 && rg >= T_H_RANGE_ATR1 * atrPrev && MathAbs(c - o) >= T_H_BODY * rg)
   {
      g_hDir = (c > o) ? 1 : -1;
      g_hLeft = T_H_WAIT_BARS;
      g_hPull = false;
   }
}

//--- Yangi bar yopilganda: kirish signallari. Oyoq ko'rinishi (g_lv) hisoblangandan keyin chaqiriladi.
void V9TSignals(const bool m1New, const bool m5New)
{
   bool b5 = m5New && V9TFreshBirth(V9_M5);
   double atr5 = V9Atr(V9_M5);
   double atr1 = V9Atr(V9_M1);
   if(atr5 <= 0.0 || atr1 <= 0.0 || V9Bid() <= 0.0)
      return;
   double s = V9Spread();

   if(b5)
   {
      // A: har M5 tug'ilish (nazorat guruhi).
      int d = g_leg[V9_M5].dir;
      double stop = g_leg[V9_M5].origin - d * T_STOP_BUF_ATR5 * atr5 + ((d < 0) ? s : 0.0);
      string bt = (g_leg[V9_M5].birthType == EV_MSS) ? "MSS" : "birinchi BOS";
      V9TOpen(TH_A, d, stop, "M5 " + bt);
   }

   if(!m1New)
      return;
   int n = g_nbar[V9_M1];
   if(n < 2)
      return;
   int k = n - 1;

   // F: tick hajmi portlashi + kuchli tana -> shu tomonga. Stop bar narigi uchidan narida.
   double volK = 0.0;
   int df = V9TFaollik(volK);
   if(df != 0)
   {
      double stopF = (df > 0) ? g_bar[V9_M1][k].l - T_STOP_BUF_ATR1 * atr1 : g_bar[V9_M1][k].h + T_STOP_BUF_ATR1 * atr1 + s;
      V9TOpen(TH_F, df, stopF, StringFormat("tick hajmi x%.1f + kuchli M1", volK));
   }

   // G: EURUSD harakati, oltin hali ergashmagan -> oltin EURUSD tomoniga. Stop ATR(M1) x 2.
   string gw = "";
   int dg = V9TDollar(gw);
   if(dg != 0)
   {
      double stopG = (dg > 0) ? V9Bid() - T_G_STOP_ATR1 * atr1 : V9Ask() + T_G_STOP_ATR1 * atr1;
      V9TOpen(TH_G, dg, stopG, gw);
   }

   // H: holat M1 yopilishida yangilanadi; kirish V9TManage dagi break tekshiruvida.
   V9TPortlashBar();
}

//--- H: qaytish barining uchi tickda buzildimi.
void V9TPortlashTick()
{
   if(g_hDir == 0 || !g_hPull)
      return;
   int d = g_hDir;
   double px = (d > 0) ? V9Ask() : V9Bid();
   if(d * (px - g_hTrig) <= 0.0)
      return;
   double stop = g_hStop + ((d < 0) ? V9Spread() : 0.0);
   g_hDir = 0;
   V9TOpen(TH_H, d, stop, "M1 portlash + qaytish + break");
}

//--- Har tickda: H break, keyin ochiq savdolarni yuritadi (MFE / MAE, trailing, stop).
void V9TManage()
{
   double bid = V9Bid(), ask = V9Ask();
   double atr5 = V9Atr(V9_M5);
   if(bid <= 0.0 || atr5 <= 0.0)
      return;
   V9TPortlashTick();
   for(int h = 0; h < T_HYP; h++)
   {
      for(int x = 0; x < T_EXIT; x++)
      {
         if(!g_t[h][x].on)
            continue;
         int d = g_t[h][x].dir;
         int tf = g_t[h][x].tfx;
         double atrX = V9Atr(tf);
         double px = (d > 0) ? bid : ask;   // shu tickda yopilsa qaysi narx
         // Stop avval tekshiriladi: o'tgan tickda qo'yilgan stopga shu tick yetdimi.
         if(d * (px - g_t[h][x].stop) <= 0.0)
         {
            // Stop narxi va zararga kichik sirpanish; gap bo'lsa - bozor narxida.
            double fill = g_t[h][x].stop - d * T_SLIP_ATR5 * atr5;
            if(d * (g_t[h][x].stop - px) > T_GAP_ATR5 * atr5)
               fill = px;
            V9TClose(h, x, fill, (d * (g_t[h][x].stop - g_t[h][x].stop0) > 0.0) ? "TRAIL" : "STOP");
            continue;
         }
         double fav = d * (px - g_t[h][x].entry) / g_t[h][x].r0;
         g_t[h][x].mfe = MathMax(g_t[h][x].mfe, fav);
         g_t[h][x].mae = MathMax(g_t[h][x].mae, -fav);
         if(atrX <= 0.0)
            continue;
         double ns = g_t[h][x].stop;
         if(x == 1)
         {
            g_t[h][x].best = (d > 0) ? MathMax(g_t[h][x].best, bid) : MathMin(g_t[h][x].best, ask);
            ns = g_t[h][x].best - d * T_CHAND_ATR * atrX;
         }
         else if(g_leg[tf].dir == d && g_leg[tf].confirmed)
         {
            double buf = (tf == V9_M5) ? T_STOP_BUF_ATR5 * atr5 : T_STOP_BUF_ATR1 * atrX;
            ns = g_leg[tf].himoya - d * buf + ((d < 0) ? g_t[h][x].sEntry : 0.0);
         }
         // Stop faqat oldinga suriladi va hozirgi narxdan o'tib ketmaydi.
         if(d * (ns - g_t[h][x].stop) > 0.0 && d * (px - ns) > 0.0)
            g_t[h][x].stop = ns;
      }
   }
}

void V9SoyaInit()
{
   for(int h = 0; h < T_HYP; h++)
   {
      g_tWait[h] = "";
      g_tSig[h] = 0;
      for(int x = 0; x < T_EXIT; x++)
      {
         g_t[h][x].on = false;
         g_tIn[h][x] = 0;
         g_tN[h][x] = 0;
         g_tWin[h][x] = 0;
         g_tR[h][x] = 0.0;
      }
   }
   for(int tfi = 0; tfi < V9_TF_N; tfi++)
   {
      g_tBornSeen[tfi] = 0;
      g_tDirSeen[tfi] = 0;
      g_tInit[tfi] = false;
   }
   g_hDir = 0;
   g_hPull = false;
   // G: dollar o'lchovi uchun EURUSD (shu brokerdagi qo'shimcha bilan: XAUUSDm -> EURUSDm).
   string suffix = (StringFind(_Symbol, "XAUUSD") == 0) ? StringSubstr(_Symbol, 6) : "";
   g_eurSym = "EURUSD" + suffix;
   g_eurOk = SymbolSelect(g_eurSym, true);
   if(!g_eurOk)
   {
      g_tWait[TH_G] = g_eurSym + " topilmadi - G ishlamaydi";
      PrintFormat("[SIRUS V9 SOYA T] %s topilmadi: G (dollar) gipotezasi ishlamaydi", g_eurSym);
   }
}

//--- Panel: ochiq savdo(lar) yoki oxirgi signal holati.
string V9TNowText(const int h)
{
   string s = "";
   for(int x = 0; x < T_EXIT; x++)
   {
      if(!g_t[h][x].on)
         continue;
      int d = g_t[h][x].dir;
      double px = (d > 0) ? V9Bid() : V9Ask();
      double r = d * (px - g_t[h][x].entry) / g_t[h][x].r0;
      if(s != "")
         s = s + " · ";
      s = s + V9TExitId(x) + StringFormat(" %+.1fR", r);
   }
   if(s != "")
   {
      int dd = g_t[h][0].on ? g_t[h][0].dir : g_t[h][1].dir;
      return V9Arrow(dd) + " " + s;
   }
   if(h == TH_H && g_hDir != 0)
      return V9Arrow(g_hDir) + (g_hPull ? " portlash: break kutilmoqda" : " portlash: qaytish kutilmoqda");
   if(g_tWait[h] != "")
      return g_tWait[h];
   return "kutmoqda";
}

//--- Ko'z jurnali uchun: ochiq savdolar qisqacha.
string V9TOpenText()
{
   string s = "";
   for(int h = 0; h < T_HYP; h++)
      for(int x = 0; x < T_EXIT; x++)
      {
         if(!g_t[h][x].on)
            continue;
         int d = g_t[h][x].dir;
         double px = (d > 0) ? V9Bid() : V9Ask();
         if(s != "")
            s = s + " ";
         s = s + V9THypId(h) + "_" + V9TExitId(x) + StringFormat("%+.1fR", d * (px - g_t[h][x].entry) / g_t[h][x].r0);
      }
   return (s == "") ? "-" : s;
}

//--- Ishga tushgandan beri (tester oxirida Journal ga).
void V9SyPrintSummary()
{
   for(int h = 0; h < T_HYP; h++)
      for(int x = 0; x < T_EXIT; x++)
      {
         int n = g_tN[h][x];
         PrintFormat("[SIRUS V9 SOYA T] %s %s / %s: signal %d, savdo %d, yutgan %d, jami %+.1fR, savdo boshiga %+.2fR",
                     V9THypId(h), V9THypName(h), (x == 0) ? "tuzilma" : "ATR", g_tSig[h], n, g_tWin[h][x], g_tR[h][x],
                     (n > 0) ? g_tR[h][x] / n : 0.0);
      }
}
