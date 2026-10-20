//+------------------------------------------------------------------+
//| SirusV9 - 70_Soya                                                |
//| SOYA T: trailing savdo KUZATUVda. Robot "shu yerda kirardim"     |
//| deydi, chartga chizadi va jurnalga yozadi - ORDER YUBORILMAYDI.  |
//|                                                                  |
//| Maqsad: qaysi kirishda haqiqiy ustunlik borligini TOPISH.        |
//| Kirish gipotezalari va chiqish qoidalari docs/GIPOTEZALAR.md da  |
//| OLDINDAN yozilgan; natijaga qarab o'zgartirilmaydi.              |
//|                                                                  |
//| Kirishlar (har biri alohida hisob):                              |
//|   A asos    - M5 oyog'i tug'ildi (nazorat guruhi)                |
//|   B erta    - M5 qaytishi oltin zonadan chuqur + M1 MSS M5 tomon |
//|   C sweep   - sinf >= 3 hovuz sweep bo'ldi + M1 MSS teskari      |
//|   D sessiya - London / NY ochilishidagi birinchi M5 tug'ilish    |
//|   E kuchli  - M5 oyog'i kuchli sham bilan tug'ildi               |
//| Chiqishlar (har kirish ikkalasi bilan alohida o'lchanadi):       |
//|   S tuzilma - stop M5 HIMOYA bilan suriladi (oyoq SINDI = chiqish)|
//|   X ATR     - stop eng yaxshi narxdan ATR(M5) x 3 (chandelier)   |
//| Natija R da: R = kirishdan boshlang'ich stopgacha (spread bilan).|
//| MFE / MAE ham yoziladi: boshqa chiqishlarni keyin tekshirsa      |
//| bo'ladi. TP yo'q - harakat qancha cho'zilsa, shuncha oladi.      |
//+------------------------------------------------------------------+

// 95_Panel dagi chizish yordamchilari (u bu fayldan keyin ulanadi).
string V9ObjName(const string id);
void   V9ChartText(const string id, const datetime t, const double price, const string text, const color clr);
void   V9ChartDel(const string id);
color  V9Green();
color  V9Red();
color  V9Muted();

struct STrade
{
   bool     on;
   int      dir;
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
int      g_tSessDay[2];            // D: shu sessiyada bugun signal bo'ldimi (yil kuni)

string V9THypId(const int h)
{
   if(h == 0) return "A";
   if(h == 1) return "B";
   if(h == 2) return "C";
   if(h == 3) return "D";
   return "E";
}

string V9THypName(const int h)
{
   if(h == 0) return "asos";
   if(h == 1) return "erta";
   if(h == 2) return "sweep";
   if(h == 3) return "sessiya";
   return "kuchli";
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

//--- D: hozir qaysi sessiya ochilishi. 0 London, 1 Nyu-York, -1 hech biri.
int V9TSession()
{
   datetime utc = TimeCurrent() - V9ServerOffsetSec();
   MqlDateTime u;
   TimeToStruct(utc, u);
   int mins = u.hour * 60 + u.min;
   if(mins >= T_LON_FROM_MIN && mins < T_LON_TO_MIN)
      return 0;
   if(mins >= T_NY_FROM_MIN && mins < T_NY_TO_MIN)
      return 1;
   return -1;
}

//--- C: `dir` savdosi uchun yaqinda sweep bo'lgan katta hovuz (narigi tomonda). -1 yo'q.
int V9TSweptPool(const int dir, const double m1Origin)
{
   int side = -dir;
   datetime now = TimeCurrent();
   int best = -1;
   for(int i = 0; i < g_npool; i++)
   {
      if(g_pool[i].side != side || g_pool[i].cls < T_C_MIN_CLS || g_pool[i].status != PST_SWEPT)
         continue;
      if(now - g_pool[i].statusT > T_C_SWEEP_S)
         continue;
      if(side * (m1Origin - g_pool[i].price) <= 0.0)   // M1 oyog'i sweep nuqtasidan boshlangan bo'lishi kerak
         continue;
      if(best < 0 || g_pool[i].cls > g_pool[best].cls)
         best = i;
   }
   return best;
}

//--- Gipoteza h ning bo'sh joylarida savdo ochadi. stopPx: BUY uchun bid, SELL uchun ask darajasi.
void V9TOpen(const int h, const int dir, const double stopPx, const string why)
{
   double bid = V9Bid(), ask = V9Ask();
   double s = ask - bid;
   double entry = (dir > 0) ? ask : bid;
   double r0 = dir * (entry - stopPx);
   g_tSig[h]++;
   string tm = V9TimeStr(TimeCurrent());
   if(r0 <= 0.0 || r0 < T_MIN_R_SPREAD * s)
   {
      g_tWait[h] = StringSubstr(tm, 11, 5) + " signal o'tkazildi: xavf " + V9Px(r0) + " < 3 spread";
      return;
   }
   int opened = 0;
   for(int x = 0; x < T_EXIT; x++)
   {
      if(g_t[h][x].on)
         continue;
      g_t[h][x].on = true;
      g_t[h][x].dir = dir;
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
   g_tWait[h] = (opened > 0) ? "" : StringSubstr(tm, 11, 5) + " signal o'tkazildi: ikkala chiqish ham band";
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

//--- Yangi bar yopilganda: kirish signallari. Oyoq ko'rinishi (g_lv) hisoblangandan keyin chaqiriladi.
void V9TSignals(const bool m1New, const bool m5New)
{
   bool b5 = m5New && V9TFreshBirth(V9_M5);
   bool b1 = m1New && V9TFreshBirth(V9_M1);
   double atr5 = V9Atr(V9_M5);
   if(atr5 <= 0.0 || V9Bid() <= 0.0)
      return;
   double s = V9Spread();
   double buf = T_STOP_BUF_ATR5 * atr5;

   if(b5)
   {
      int d = g_leg[V9_M5].dir;
      double stop = g_leg[V9_M5].origin - d * buf + ((d < 0) ? s : 0.0);
      string bt = (g_leg[V9_M5].birthType == EV_MSS) ? "MSS" : "birinchi BOS";
      // A: har M5 tug'ilish (nazorat guruhi).
      V9TOpen(0, d, stop, "M5 " + bt);
      // D: London / NY ochilishidagi birinchi M5 tug'ilish.
      int sess = V9TSession();
      if(sess >= 0)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         if(g_tSessDay[sess] != dt.day_of_year)
         {
            g_tSessDay[sess] = dt.day_of_year;
            string sn = (sess == 0) ? "London" : "Nyu-York";
            V9TOpen(3, d, stop, sn + " ochilishi + M5 " + bt);
         }
      }
      // E: kuchli sham bilan tug'ilish (tana >= ATR x 0.8).
      if(g_leg[V9_M5].birthQ == Q_STRONG)
         V9TOpen(4, d, stop, "kuchli M5 " + bt);
   }

   if(b1 && g_leg[V9_M1].birthType == EV_MSS)
   {
      int d1 = g_leg[V9_M1].dir;
      double o1 = g_leg[V9_M1].origin;
      double stop1 = o1 - d1 * buf + ((d1 < 0) ? s : 0.0);
      // B: M5 oyog'i ichida chuqur qaytish tugadi - M1 M5 tomonga burildi.
      if(g_lv[V9_M5].ok && g_lv[V9_M5].confirmed && g_lv[V9_M5].dir == d1)
      {
         int st = g_lv[V9_M5].stage;
         double span = d1 * (g_lv[V9_M5].ext - g_lv[V9_M5].himoya);
         if((st == STG_YANGI || st == STG_RIVOJ || st == STG_KECH) && span > 0.0)
         {
            double depth = d1 * (g_lv[V9_M5].ext - o1) / span;
            if(depth >= T_B_PB_MIN && depth <= 1.0)
               V9TOpen(1, d1, stop1, StringFormat("M5 qaytishi %.0f%% + M1 MSS", depth * 100.0));
         }
      }
      // C: katta hovuz sweepidan keyin M1 teskari burildi.
      int pi = V9TSweptPool(d1, o1);
      if(pi >= 0)
         V9TOpen(2, d1, stop1, "sweep " + V9PoolName(pi) + " + M1 MSS");
   }
}

//--- Har tickda: ochiq savdolarni yuritadi (MFE / MAE, trailing, stop).
void V9TManage()
{
   double bid = V9Bid(), ask = V9Ask();
   double atr5 = V9Atr(V9_M5);
   if(bid <= 0.0 || atr5 <= 0.0)
      return;
   for(int h = 0; h < T_HYP; h++)
   {
      for(int x = 0; x < T_EXIT; x++)
      {
         if(!g_t[h][x].on)
            continue;
         int d = g_t[h][x].dir;
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
         double ns = g_t[h][x].stop;
         if(x == 1)
         {
            g_t[h][x].best = (d > 0) ? MathMax(g_t[h][x].best, bid) : MathMin(g_t[h][x].best, ask);
            ns = g_t[h][x].best - d * T_CHAND_ATR5 * atr5;
         }
         else if(g_leg[V9_M5].dir == d && g_leg[V9_M5].confirmed)
            ns = g_leg[V9_M5].himoya - d * T_STOP_BUF_ATR5 * atr5 + ((d < 0) ? g_t[h][x].sEntry : 0.0);
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
   g_tSessDay[0] = -1;
   g_tSessDay[1] = -1;
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
