//+------------------------------------------------------------------+
//| SirusV9 - 70_Soya                                                |
//| SOYA SAVDO: Shartnomaning kirish qoidasi (POYDEVOR 4, birinchi   |
//| variant) KUZATUV rejimida. Robot "shu yerda kirardim" deydi,     |
//| chartga chizadi va jurnalga yozadi - ORDER YUBORILMAYDI.         |
//|                                                                  |
//| Uch xil kirish alohida kuzatiladi:                               |
//|   CB (cashback): oyoq yo'nalishida, kichik TP, sayoz / oltin     |
//|                  zona, IMPULS yoki KORREKSIYA (QARSHI emas).     |
//|                  Chiqish: TP yoki oyoq SINDI.                    |
//|   N  (oddiy):    oyoq yo'nalishida, TP = ATR(M15) (MAQSADgacha   |
//|                  yo'lning 80% idan oshmaydi), faqat oltin zona   |
//|                  va IMPULS. Chiqish: TP yoki oyoq SINDI.         |
//|   Q  (cashback qaytish o'rimi): oyoq TUGADI yoki maqsadga 80%+   |
//|                  yetgan, ekstremumda teskari belgi bor (sweep /  |
//|                  soxta break / SOXTA) va qadam teskari tomonga - |
//|                  oyoqqa QARSHI kichik TP. Stop ekstremumdan sal  |
//|                  narida (yaqin). Chiqish: TP, STOP yoki 120 daq. |
//| Kirish shartlariga O'lchov katagi "salbiy" bo'lmasligi ham       |
//| kiradi. TP dan keyin shartlar hali bajarilsa - darhol qayta.     |
//| Grid va lot bu yerda yo'q (3-bosqich qarorlari).                 |
//+------------------------------------------------------------------+

#define SY_CB   0
#define SY_N    1
#define SY_Q    2
#define SY_M    3

#define SY_Q_PROGRESS     0.80    // Q: KECH oyoq maqsadning kamida shuncha qismini yurgan bo'lsin
#define SY_Q_MAX_PB       0.38    // Q: narx hali ekstremum yonida (qaytish <= 38%)
#define SY_Q_MAX_RISK     1.00    // Q: kirishdan stopgacha ATR(M5) x shundan oshmasin (zarar kichik bo'lsin)
#define SY_Q_TIMEOUT_MIN  120     // Q: shuncha daqiqada TP ham, stop ham bo'lmasa - bozor narxida yopiladi

// 95_Panel dagi chizish yordamchilari (u bu fayldan keyin ulanadi va soya bo'limini o'qiydi).
string V9ObjName(const string id);
void   V9ChartText(const string id, const datetime t, const double price, const string text, const color clr);
void   V9ChartDel(const string id);
color  V9Green();
color  V9Red();
color  V9Muted();

struct SShadow
{
   bool     on;
   int      dir;
   double   entry;      // BUY: ask, SELL: bid
   double   tpLvl;      // bid darajasi
   double   stLvl;      // bid darajasi (faqat Q; CB / N oyoq SINDI bilan chiqadi)
   double   tpPts;
   datetime t;
   datetime legBornT;   // qaysi oyoq ichida ochildi
   double   himoya;
   string   why;
   int      id;
};

SShadow g_sy[SY_M];
string  g_syWait[SY_M];        // hozir nega kirmayapti (birinchi bajarilmagan shart)
int     g_syDay = -1;
int     g_syIn[SY_M];          // bugun
int     g_syTp[SY_M];
int     g_sySd[SY_M];          // TP siz chiqishlar (SINDI / STOP / VAQT)
double  g_syPts[SY_M];
int     g_syAllIn[SY_M];       // ishga tushgandan beri (tester xulosasi uchun)
int     g_syAllTp[SY_M];
int     g_syAllSd[SY_M];
double  g_syAllPts[SY_M];
int     g_sySeq = 0;

string V9SyModeName(const int m)
{
   if(m == SY_CB) return "CB";
   if(m == SY_N)  return "N";
   return "Q";
}

string V9SyFile()
{
   return V9DailyFile("Soya");
}

string V9SyHeader()
{
   return "vaqt;rejim;hodisa;tomon;narx;tp;himoya_yoki_stop;natija_punkt;daqiqa;sabab";
}

void V9SyDayCheck()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(t.day_of_year == g_syDay)
      return;
   g_syDay = t.day_of_year;
   for(int m = 0; m < SY_M; m++)
   {
      g_syIn[m] = 0;
      g_syTp[m] = 0;
      g_sySd[m] = 0;
      g_syPts[m] = 0.0;
   }
}

//--- Oldinda TP gacha qarama-qarshi devor bormi (narx uning ichida bo'lsa ham). true = joy bor.
bool V9SyRoom(const int dir, const double tp, string &why)
{
   int wz = V9ZoneNearest(dir);
   if(wz < 0)
      return true;
   double bid = V9Bid();
   double edge = (dir > 0) ? g_zone[wz].lo : g_zone[wz].hi;
   double room = dir * (edge - bid);
   if(room > tp + V9Spread())
      return true;
   why = "oldinda devor: " + V9TFName(g_zone[wz].tfi) + ((dir > 0) ? " supply" : " demand");
   return false;
}

//--- CB va N: oyoq yo'nalishida. true = kirardi; aks holda why = birinchi bajarilmagan shart.
bool V9SyCanEnterWith(const int m, int &dir, double &tpPts, string &why)
{
   dir = 0;
   tpPts = 0.0;
   why = "";
   if(!g_lv[V9_M5].ok)                       { why = "M5 oyog'i yo'q"; return false; }
   int d = g_lv[V9_M5].dir;
   if(!g_lv[V9_M5].confirmed)                { why = "oyoq tasdiqlanmagan (2 sham kutilmoqda)"; return false; }
   int st = g_lv[V9_M5].stage;
   if(st != STG_YANGI && st != STG_RIVOJ)    { why = "oyoq " + V9StageName(st) + " - yangi da'vo yo'q"; return false; }
   int rel = g_lv[V9_M5].mapRel;
   if(rel == MAP_REL_QARSHI)                 { why = "xarita QARSHI (H1 va H4)"; return false; }
   if(m == SY_N && rel != MAP_REL_IMPULS)    { why = "oddiy rejim faqat IMPULS da"; return false; }
   if(g_bigLate)                             { why = "katta oyoq (H1) kech"; return false; }
   int z = g_lv[V9_M5].zone;
   if(m == SY_CB && z != PBZ_SAYOZ && z != PBZ_OLTIN) { why = "joy emas: " + V9ZoneName(z); return false; }
   if(m == SY_N && z != PBZ_OLTIN)           { why = "joy emas: " + V9ZoneName(z) + " (oltin zona kerak)"; return false; }

   double bid = V9Bid(), s = V9Spread();
   double atr15 = V9Atr(V9_M15);
   if(bid <= 0.0 || atr15 <= 0.0)            { why = "narx / ATR yo'q"; return false; }
   double tp = 0.0;
   if(m == SY_CB)
      tp = V9OlTp(0, s);
   else
   {
      if(g_lv[V9_M5].targetIdx < 0)          { why = "MAQSAD yo'q"; return false; }
      double toT = d * (g_lv[V9_M5].target - bid);
      tp = MathMin(atr15, 0.8 * toT);
      if(tp < 3.0 * s)                       { why = "MAQSADgacha joy kam"; return false; }
   }
   if(!V9SyRoom(d, tp, why))
      return false;
   if(g_qd.dir != d)                         { why = "qadam: payt emas (" + g_qd.why + ")"; return false; }
   int cell = g_olCellNow[(d > 0) ? 1 : 0];
   if(V9OlVerdict((m == SY_CB) ? 0 : 1, cell) == -1) { why = "O'lchov: shu holat salbiy"; return false; }

   dir = d;
   tpPts = tp / _Point;
   string zt = (z == PBZ_OLTIN) ? "oltin zona" : "sayoz qaytish";
   string rt = (rel == MAP_REL_IMPULS) ? "IMPULS" : ((rel == MAP_REL_KORREK) ? "KORREKSIYA" : "H1 neytral");
   why = zt + " + " + g_qd.why + " + " + rt;
   return true;
}

//--- Q: oyoq tugagan / maqsadga yetgan joyda, oyoqqa QARSHI kichik o'rim. Stop ekstremumdan sal narida.
bool V9SyCanEnterQ(int &dir, double &tpPts, double &stLvl, string &why)
{
   dir = 0;
   tpPts = 0.0;
   stLvl = 0.0;
   why = "";
   if(!g_lv[V9_M5].ok)                       { why = "M5 oyog'i yo'q"; return false; }
   int d = g_lv[V9_M5].dir;
   int st = g_lv[V9_M5].stage;
   bool spent = (st == STG_TUGADI) || (st == STG_KECH && g_lv[V9_M5].progress >= SY_Q_PROGRESS);
   if(!spent)                                { why = "oyoq hali tugamagan (" + V9StageName(st) + ")"; return false; }
   if(g_lv[V9_M5].counter < 1)               { why = "ekstremumda teskari belgi yo'q (sweep / soxta break)"; return false; }
   if(g_lv[V9_M5].pullback > SY_Q_MAX_PB)    { why = "narx ekstremumdan uzoqlashgan"; return false; }
   // Kuchli H1 oyoq bilan bir tomonda bo'lsa, unga qarshi o'rim qilinmaydi (H1 hali bosmoqda).
   if(g_lv[V9_M5].mapRel == MAP_REL_IMPULS && MathAbs(g_mapState[V9_H1]) == 3)
                                             { why = "H1 kuchli, oyoq bilan bir tomonda"; return false; }
   int q = -d;
   double bid = V9Bid(), ask = V9Ask(), s = V9Spread();
   double atr5 = V9Atr(V9_M5);
   if(bid <= 0.0 || atr5 <= 0.0)             { why = "narx / ATR yo'q"; return false; }
   double tp = V9OlTp(0, s);
   if(!V9SyRoom(q, tp, why))
      return false;
   if(g_qd.dir != q)                         { why = "qadam: teskari payt emas (" + g_qd.why + ")"; return false; }
   int cell = g_olCellNow[(q > 0) ? 1 : 0];
   if(V9OlVerdict(0, cell) == -1)            { why = "O'lchov: shu holat salbiy"; return false; }
   // Stop: ekstremumdan ATR(M5) x 0.15 narida. BUY stopi bid da, SELL stopi ask da (bid = ask - spread).
   double ext = g_lv[V9_M5].ext;
   double stop = ext - q * V9_SINDI_BUF_ATR * atr5;
   stLvl = (q > 0) ? stop : stop - (ask - bid);
   if(q * (bid - stLvl) <= 0.0)              { why = "narx stop chizig'ida"; return false; }
   if(q * (bid - stLvl) > SY_Q_MAX_RISK * atr5) { why = "stop uzoq (ekstremumdan ATR(M5) dan ko'p)"; return false; }
   dir = q;
   tpPts = tp / _Point;
   why = "oyoq " + V9StageName(st) + " + teskari belgi " + IntegerToString(g_lv[V9_M5].counter) + "/3 + " + g_qd.why;
   return true;
}

void V9SyDrawEntry(const int m, const int id, const int dir, const datetime t, const double price)
{
   string name = V9ObjName(StringFormat("SY_%d_e", id));
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (dir > 0) ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (dir > 0) ? V9Green() : V9Red());
   ObjectSetInteger(0, name, OBJPROP_WIDTH, (m == SY_N) ? 2 : 1);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, (dir > 0) ? ANCHOR_TOP : ANCHOR_BOTTOM);
   V9ChartText(StringFormat("SY_%d_l", id), t, price, " " + V9SyModeName(m), V9Muted());
}

void V9SyDrawExit(const int id, const datetime t0, const double p0, const datetime t1, const double p1, const bool tp)
{
   string ln = V9ObjName(StringFormat("SY_%d_x", id));
   if(ObjectFind(0, ln) < 0)
   {
      ObjectCreate(0, ln, OBJ_TREND, 0, t0, p0, t1, p1);
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_DOT);
   }
   ObjectSetInteger(0, ln, OBJPROP_COLOR, tp ? V9Green() : V9Red());
   string mk = V9ObjName(StringFormat("SY_%d_r", id));
   if(ObjectFind(0, mk) < 0)
   {
      ObjectCreate(0, mk, OBJ_ARROW, 0, t1, p1);
      ObjectSetInteger(0, mk, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, mk, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, mk, OBJPROP_ARROWCODE, tp ? 252 : 251);   // Wingdings: ✓ / ✗
   ObjectSetInteger(0, mk, OBJPROP_COLOR, tp ? V9Green() : V9Red());
   // Chart tozaligi: eng eski belgilar o'chadi (oxirgi 40 ta soya savdo qoladi).
   int old = id - 40;
   if(old >= 0)
   {
      V9ChartDel(StringFormat("SY_%d_e", old));
      V9ChartDel(StringFormat("SY_%d_l", old));
      V9ChartDel(StringFormat("SY_%d_x", old));
      V9ChartDel(StringFormat("SY_%d_r", old));
   }
}

//--- Yopish. kind: "TP", "SINDI" (oyoq tugadi), "STOP" (Q stopi), "VAQT" (Q vaqti tugadi).
void V9SyClose(const int m, const string kind)
{
   int d = g_sy[m].dir;
   double bid = V9Bid(), ask = V9Ask();
   bool tp = (kind == "TP");
   // TP va STOP broker orderi kabi o'z darajasida yopiladi; SINDI va VAQT bozor narxida.
   double exitPx = (d > 0) ? bid : ask;
   if(tp)
      exitPx = (d > 0) ? g_sy[m].tpLvl : g_sy[m].tpLvl + (ask - bid);
   else if(kind == "STOP")
      exitPx = (d > 0) ? g_sy[m].stLvl : g_sy[m].stLvl + (ask - bid);
   double pts = d * (exitPx - g_sy[m].entry) / _Point;
   int mins = (int)((TimeCurrent() - g_sy[m].t) / 60);
   if(tp) { g_syTp[m]++; g_syAllTp[m]++; }
   else   { g_sySd[m]++; g_syAllSd[m]++; }
   g_syPts[m] += pts;
   g_syAllPts[m] += pts;
   V9SyDrawExit(g_sy[m].id, g_sy[m].t, g_sy[m].entry, TimeCurrent(), exitPx, tp);
   double ref = (m == SY_Q) ? g_sy[m].stLvl : g_sy[m].himoya;
   V9FileAppend(V9SyFile(), V9SyHeader(),
                StringFormat("%s;%s;%s;%s;%s;%s;%s;%.0f;%d;%s", V9TimeStr(TimeCurrent()), V9SyModeName(m), kind,
                             (d > 0 ? "BUY" : "SELL"), V9Px(exitPx), V9Px(g_sy[m].tpLvl), V9Px(ref), pts, mins, g_sy[m].why));
   g_sy[m].on = false;
}

void V9SyOpen(const int m, const int dir, const double tpPts, const double stLvl, const string why)
{
   double bid = V9Bid(), ask = V9Ask();
   double entry = (dir > 0) ? ask : bid;
   g_sy[m].on = true;
   g_sy[m].dir = dir;
   g_sy[m].entry = entry;
   g_sy[m].tpPts = tpPts;
   g_sy[m].tpLvl = (dir > 0) ? entry + tpPts * _Point : entry - tpPts * _Point - (ask - bid);
   g_sy[m].stLvl = stLvl;
   g_sy[m].t = TimeCurrent();
   g_sy[m].legBornT = g_lv[V9_M5].bornT;
   g_sy[m].himoya = g_lv[V9_M5].himoya;
   g_sy[m].why = why;
   g_sy[m].id = g_sySeq;
   g_sySeq++;
   g_syIn[m]++;
   g_syAllIn[m]++;
   V9SyDrawEntry(m, g_sy[m].id, dir, g_sy[m].t, entry);
   double ref = (m == SY_Q) ? stLvl : g_sy[m].himoya;
   V9FileAppend(V9SyFile(), V9SyHeader(),
                StringFormat("%s;%s;KIRISH;%s;%s;%s;%s;;;%s", V9TimeStr(g_sy[m].t), V9SyModeName(m), (dir > 0 ? "BUY" : "SELL"),
                             V9Px(entry), V9Px(g_sy[m].tpLvl), V9Px(ref), why));
}

//--- Har tickda: ochiq soya savdolarni yuritadi, keyin yangi kirishni tekshiradi.
void V9SoyaTick()
{
   V9SyDayCheck();
   double bid = V9Bid();
   if(bid <= 0.0)
      return;
   for(int m = 0; m < SY_M; m++)
   {
      if(g_sy[m].on)
      {
         int d = g_sy[m].dir;
         bool tpHit = (d > 0) ? (bid >= g_sy[m].tpLvl) : (bid <= g_sy[m].tpLvl);
         if(m == SY_Q)
         {
            bool stHit = (d > 0) ? (bid <= g_sy[m].stLvl) : (bid >= g_sy[m].stLvl);
            if(stHit)
               V9SyClose(m, "STOP");
            else if(tpHit)
               V9SyClose(m, "TP");
            else if(TimeCurrent() - g_sy[m].t >= SY_Q_TIMEOUT_MIN * 60)
               V9SyClose(m, "VAQT");
            else
               continue;
         }
         else
         {
            // SINDI: shu savdo ochilgan oyoq tugadi (teskari oyoq tug'ildi yoki boshqa oyoq boshlandi).
            bool legEnd = (!g_lv[V9_M5].ok || g_lv[V9_M5].dir != d || g_lv[V9_M5].bornT != g_sy[m].legBornT);
            if(tpHit)
               V9SyClose(m, "TP");
            else if(legEnd)
               V9SyClose(m, "SINDI");
            else
               continue;
         }
      }
      int dir = 0;
      double tpPts = 0.0, stLvl = 0.0;
      string why = "";
      bool ok = (m == SY_Q) ? V9SyCanEnterQ(dir, tpPts, stLvl, why) : V9SyCanEnterWith(m, dir, tpPts, why);
      if(!ok)
      {
         g_syWait[m] = why;
         continue;
      }
      g_syWait[m] = "";
      V9SyOpen(m, dir, tpPts, stLvl, why);
   }
}

void V9SoyaInit()
{
   for(int m = 0; m < SY_M; m++)
   {
      g_sy[m].on = false;
      g_syWait[m] = "";
      g_syIn[m] = 0;
      g_syTp[m] = 0;
      g_sySd[m] = 0;
      g_syPts[m] = 0.0;
      g_syAllIn[m] = 0;
      g_syAllTp[m] = 0;
      g_syAllSd[m] = 0;
      g_syAllPts[m] = 0.0;
   }
   g_syDay = -1;
}

//--- Panel uchun: ochiq soya savdo yoki nega kutmoqda.
string V9SyNowText(const int m)
{
   if(g_sy[m].on)
   {
      int d = g_sy[m].dir;
      double px = (d > 0) ? V9Bid() : V9Ask();
      double pts = d * (px - g_sy[m].entry) / _Point;
      return StringFormat("%s %s · TP %.0f p · hozir %+.0f p", (d > 0 ? "BUY" : "SELL"), V9Px(g_sy[m].entry), g_sy[m].tpPts, pts);
   }
   return "kutmoqda: " + g_syWait[m];
}

string V9SyStatText(const int m)
{
   return StringFormat("bugun %d kirish · %d TP · %d boshqa", g_syIn[m], g_syTp[m], g_sySd[m]);
}

//--- Ishga tushgandan beri (tester oxirida jurnalga).
void V9SyPrintSummary()
{
   for(int m = 0; m < SY_M; m++)
      PrintFormat("[SIRUS V9 SOYA] %s: %d kirish, %d TP, %d TP siz (SINDI/STOP/VAQT), jami %+.0f punkt",
                  V9SyModeName(m), g_syAllIn[m], g_syAllTp[m], g_syAllSd[m], g_syAllPts[m]);
}
