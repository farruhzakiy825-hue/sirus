//+------------------------------------------------------------------+
//| SirusV9 - 70_Soya                                                |
//| SOYA SAVDO: Shartnomaning kirish qoidasi (POYDEVOR 4, birinchi   |
//| variant) KUZATUV rejimida. Robot "shu yerda kirardim" deydi,     |
//| chartga chizadi va jurnalga yozadi - ORDER YUBORILMAYDI.         |
//|                                                                  |
//| Ikkala rejim bir vaqtda, alohida kuzatiladi:                     |
//|   CB (cashback): kichik TP, sayoz / oltin zona, IMPULS yoki      |
//|                  KORREKSIYA (QARSHI emas)                        |
//|   N  (oddiy):    TP = ATR(M15), MAQSADgacha joy bilan, faqat     |
//|                  oltin zona va IMPULS                            |
//| Kirish = YO'NALISH + JOY + TRIGGER, va O'lchov katagi "salbiy"   |
//| bo'lmasligi kerak. Chiqish: TP, yoki oyoq SINDI (teskari oyoq    |
//| tug'ildi). TP dan keyin shartlar hali bajarilsa - darhol qayta.  |
//| Grid va lot bu yerda yo'q (3-bosqich qarorlari).                 |
//+------------------------------------------------------------------+

#define SY_CB   0
#define SY_N    1

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
   double   tpPts;
   datetime t;
   datetime legBornT;   // qaysi oyoq ichida ochildi (shu oyoq SINDI bo'lsa - chiqish)
   double   himoya;
   string   why;
   int      id;
};

SShadow g_sy[2];
string  g_syWait[2];           // hozir nega kirmayapti (birinchi bajarilmagan shart)
int     g_syDay = -1;
int     g_syIn[2];             // bugun: kirishlar
int     g_syTp[2];
int     g_sySd[2];             // SINDI bilan chiqishlar
double  g_syPts[2];            // bugungi jami natija (punkt)
int     g_syLastRes[2];        // oxirgi natija: 1 TP, -1 SINDI, 0 yo'q
double  g_syLastPts[2];
int     g_sySeq = 0;

string V9SyModeName(const int m)
{
   return (m == SY_CB) ? "CB" : "N";
}

string V9SyFile()
{
   return V9DailyFile("Soya");
}

string V9SyHeader()
{
   return "vaqt;rejim;hodisa;tomon;narx;tp;himoya;natija_punkt;daqiqa;sabab";
}

void V9SyDayCheck()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(t.day_of_year == g_syDay)
      return;
   g_syDay = t.day_of_year;
   for(int m = 0; m < 2; m++)
   {
      g_syIn[m] = 0;
      g_syTp[m] = 0;
      g_sySd[m] = 0;
      g_syPts[m] = 0.0;
   }
}

//--- Kirish qoidasi. true = kirardi; aks holda why = birinchi bajarilmagan shart.
bool V9SyCanEnter(const int m, int &dir, double &tpPts, string &why)
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
   // Oldinda devor: TP gacha qarama-qarshi devor bo'lmasin (narx uning ichida ham bo'lmasin).
   int wz = V9ZoneNearest(d);
   if(wz >= 0)
   {
      double edge = (d > 0) ? g_zone[wz].lo : g_zone[wz].hi;
      double room = d * (edge - bid);
      if(room <= tp + s)                     { why = "oldinda devor: " + V9TFName(g_zone[wz].tfi) + ((d > 0) ? " supply" : " demand"); return false; }
   }
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
   V9ChartText(StringFormat("SY_%d_l", id), t, price, (m == SY_CB) ? " CB" : " N", V9Muted());
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

void V9SyClose(const int m, const bool tp)
{
   int d = g_sy[m].dir;
   double bid = V9Bid(), ask = V9Ask();
   // TP broker TP si kabi o'z darajasida yopiladi; SINDI esa bozor narxida.
   double exitPx = (d > 0) ? bid : ask;
   if(tp)
      exitPx = (d > 0) ? g_sy[m].tpLvl : g_sy[m].tpLvl + (ask - bid);
   double pts = d * (exitPx - g_sy[m].entry) / _Point;
   int mins = (int)((TimeCurrent() - g_sy[m].t) / 60);
   if(tp) g_syTp[m]++;
   else   g_sySd[m]++;
   g_syPts[m] += pts;
   g_syLastRes[m] = tp ? 1 : -1;
   g_syLastPts[m] = pts;
   V9SyDrawExit(g_sy[m].id, g_sy[m].t, g_sy[m].entry, TimeCurrent(), exitPx, tp);
   V9FileAppend(V9SyFile(), V9SyHeader(),
                StringFormat("%s;%s;%s;%s;%s;%s;%s;%.0f;%d;%s", V9TimeStr(TimeCurrent()), V9SyModeName(m),
                             (tp ? "TP" : "SINDI"), (d > 0 ? "BUY" : "SELL"), V9Px(exitPx), V9Px(g_sy[m].tpLvl),
                             V9Px(g_sy[m].himoya), pts, mins, g_sy[m].why));
   g_sy[m].on = false;
}

//--- Har tickda: ochiq soya savdolarni yuritadi, keyin yangi kirishni tekshiradi.
void V9SoyaTick()
{
   V9SyDayCheck();
   double bid = V9Bid(), ask = V9Ask();
   if(bid <= 0.0)
      return;
   for(int m = 0; m < 2; m++)
   {
      if(g_sy[m].on)
      {
         int d = g_sy[m].dir;
         bool tpHit = (d > 0) ? (bid >= g_sy[m].tpLvl) : (bid <= g_sy[m].tpLvl);
         // SINDI: shu savdo ochilgan oyoq tugadi (teskari oyoq tug'ildi yoki boshqa oyoq boshlandi).
         bool legEnd = (!g_lv[V9_M5].ok || g_lv[V9_M5].dir != d || g_lv[V9_M5].bornT != g_sy[m].legBornT);
         if(tpHit)
            V9SyClose(m, true);
         else if(legEnd)
            V9SyClose(m, false);
         else
            continue;
      }
      int dir = 0;
      double tpPts = 0.0;
      string why = "";
      if(!V9SyCanEnter(m, dir, tpPts, why))
      {
         g_syWait[m] = why;
         continue;
      }
      g_syWait[m] = "";
      double entry = (dir > 0) ? ask : bid;
      g_sy[m].on = true;
      g_sy[m].dir = dir;
      g_sy[m].entry = entry;
      g_sy[m].tpPts = tpPts;
      g_sy[m].tpLvl = (dir > 0) ? entry + tpPts * _Point : entry - tpPts * _Point - (ask - bid);
      g_sy[m].t = TimeCurrent();
      g_sy[m].legBornT = g_lv[V9_M5].bornT;
      g_sy[m].himoya = g_lv[V9_M5].himoya;
      g_sy[m].why = why;
      g_sy[m].id = g_sySeq;
      g_sySeq++;
      g_syIn[m]++;
      V9SyDrawEntry(m, g_sy[m].id, dir, g_sy[m].t, entry);
      V9FileAppend(V9SyFile(), V9SyHeader(),
                   StringFormat("%s;%s;KIRISH;%s;%s;%s;%s;;;%s", V9TimeStr(g_sy[m].t), V9SyModeName(m), (dir > 0 ? "BUY" : "SELL"),
                                V9Px(entry), V9Px(g_sy[m].tpLvl), V9Px(g_sy[m].himoya), why));
   }
}

void V9SoyaInit()
{
   for(int m = 0; m < 2; m++)
   {
      g_sy[m].on = false;
      g_syWait[m] = "";
      g_syIn[m] = 0;
      g_syTp[m] = 0;
      g_sySd[m] = 0;
      g_syPts[m] = 0.0;
      g_syLastRes[m] = 0;
      g_syLastPts[m] = 0.0;
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
   return StringFormat("bugun %d kirish · %d TP · %d SINDI", g_syIn[m], g_syTp[m], g_sySd[m]);
}
