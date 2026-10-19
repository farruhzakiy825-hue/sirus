//+------------------------------------------------------------------+
//| SirusV9 - 95_Panel                                               |
//| Faqat O'QIYDI va chizadi. Hech qanday qaror yo'q.                |
//| Chart: M5 oyog'i (ORIGIN, HIMOYA, MAQSAD, oltin va chuqur zona), |
//| H1 oyog'i, likvidlik hovuzlari, devorlar. Panel: bitta ustun.    |
//+------------------------------------------------------------------+

// Ranglar (sozlama emas: egasi 2 rang bilan cheklashni aytgan; kerak bo'lsa keyin)
#define InpClrTitle   clrGold
#define InpClrText    clrWhiteSmoke
#define InpClrMuted   clrDarkGray
#define InpClrUp      clrMediumSeaGreen
#define InpClrDn      clrTomato
#define InpClrOrigin  clrGray
#define InpClrHimoya  clrCrimson
#define InpClrTarget  clrDodgerBlue
#define InpClrGold    C'60,52,25'
#define InpClrDeep    C'45,35,70'
#define InpClrPool    clrSteelBlue
#define InpClrSupply  C'110,40,40'
#define InpClrDemand  C'35,90,60'

int g_panelLines = 0;

//--- Obyekt nomi: prefiks + id (literal + literal qo'shilmasin).
string V9Obj(const string id)
{
   string p = V9_OBJ;
   return p + id;
}

void V9ObjCommon(const string name)
{
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//--- Gorizontal segment (t1 dan t2 gacha).
void V9DrawLine(const string id, const datetime t1, const datetime t2, const double price,
                const color clr, const int style, const int width)
{
   string name = V9Obj(id);
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price))
         return;
      V9ObjCommon(name);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
   ObjectMove(0, name, 0, t1, price);
   ObjectMove(0, name, 1, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void V9DrawRect(const string id, const datetime t1, const datetime t2, const double p1, const double p2, const color clr)
{
   string name = V9Obj(id);
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
         return;
      V9ObjCommon(name);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   ObjectMove(0, name, 0, t1, p1);
   ObjectMove(0, name, 1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void V9DrawText(const string id, const datetime t, const double price, const string text, const color clr, const int size)
{
   string name = V9Obj(id);
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
         return;
      V9ObjCommon(name);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   ObjectMove(0, name, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, InpFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void V9Del(const string id)
{
   string name = V9Obj(id);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

//--- Yozuvlar ustma-ust tushmasin: har yozuv narxi eslab qolinadi.
double g_lblP[64];
int    g_lblN = 0;

double V9LabelTol()
{
   double pmax = ChartGetDouble(0, CHART_PRICE_MAX);
   double pmin = ChartGetDouble(0, CHART_PRICE_MIN);
   long hpx = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(pmax > pmin && hpx > 0)
      return (pmax - pmin) / (double)hpx * (double)(InpFontSize + 6);
   return 0.1 * V9Atr(V9_M15);
}

//--- Narx bo'sh bo'lsa band qiladi va true qaytaradi.
bool V9LabelFree(const double p, const double tol)
{
   for(int i = 0; i < g_lblN; i++)
      if(MathAbs(g_lblP[i] - p) < tol)
         return false;
   if(g_lblN < 64)
   {
      g_lblP[g_lblN] = p;
      g_lblN++;
   }
   return true;
}

//--- Oyoq yozuvi: joy bo'sh bo'lsa asosiy ustunda, band bo'lsa o'ngroqda (o'chirilmaydi).
void V9LegLabel(const string id, const double price, const string text, const color clr, const double tol)
{
   int P = PeriodSeconds();
   datetime x = TimeCurrent() + 9 * P;
   if(!V9LabelFree(price, tol))
      x = TimeCurrent() + 30 * P;
   V9DrawText(id, x, price, text, clr, InpFontSize - 1);
}

//--- Bitta oyoqni chizadi. pre = "M5_" / "H1_".
void V9DrawLeg(const int tfi, const string pre, const bool zones, const int width)
{
   string ids[9] = {"org", "him", "tgt", "gold", "deep", "lorg", "lhim", "ltgt", "lbos"};
   if(!g_lv[tfi].ok)
   {
      for(int i = 0; i < 9; i++)
         V9Del(pre + ids[i]);
      return;
   }
   int d = g_lv[tfi].dir;
   datetime now = TimeCurrent();
   datetime right = now + 8 * PeriodSeconds();
   double tol = V9LabelTol();
   string tf = V9TFName(tfi) + " ";

   V9DrawLine(pre + "org", g_lv[tfi].originT, right, g_lv[tfi].origin, InpClrOrigin, STYLE_DOT, 1);
   V9LegLabel(pre + "lorg", g_lv[tfi].origin, tf + "ORIGIN " + V9Px(g_lv[tfi].origin), InpClrOrigin, tol);

   V9DrawLine(pre + "him", g_lv[tfi].himoyaT, right, g_lv[tfi].himoya, InpClrHimoya, STYLE_SOLID, width);
   V9LegLabel(pre + "lhim", g_lv[tfi].himoya, tf + "HIMOYA " + V9Px(g_lv[tfi].himoya), InpClrHimoya, tol);

   if(g_lv[tfi].targetIdx >= 0)
   {
      V9DrawLine(pre + "tgt", g_lv[tfi].originT, right, g_lv[tfi].target, InpClrTarget, STYLE_DASH, width);
      V9LegLabel(pre + "ltgt", g_lv[tfi].target,
                 tf + "MAQSAD " + V9PoolName(g_lv[tfi].targetIdx) + " " + V9Px(g_lv[tfi].target), InpClrTarget, tol);
   }
   else
   {
      V9Del(pre + "tgt");
      V9Del(pre + "ltgt");
   }

   string birth = (g_lv[tfi].birthType == EV_MSS) ? "MSS" : "BOS";
   string conf = g_lv[tfi].confirmed ? "" : " (tasdiq kutilmoqda)";
   double bl = g_lv[tfi].birthLevel;
   V9DrawText(pre + "lbos", g_lv[tfi].bornT, bl, tf + birth + " · TUG'ILDI" + conf, InpClrMuted, InpFontSize - 2);

   if(zones)
   {
      double leg = d * (g_lv[tfi].ext - g_lv[tfi].himoya);
      if(leg > 0.0)
      {
         double g1 = g_lv[tfi].ext - d * leg * V9_PB_GOLD_LO;
         double g2 = g_lv[tfi].ext - d * leg * V9_PB_GOLD_HI;
         double d2 = g_lv[tfi].ext - d * leg * V9_PB_DEEP_HI;
         V9DrawRect(pre + "gold", g_lv[tfi].extT, right, g1, g2, InpClrGold);
         V9DrawRect(pre + "deep", g_lv[tfi].extT, right, g2, d2, InpClrDeep);
      }
   }
   else
   {
      V9Del(pre + "gold");
      V9Del(pre + "deep");
   }
}

//--- Hovuzlar: sinfi >= 2 bo'lgan YANGI va SWEEP darajalar, qisqa segment.
void V9DrawPools()
{
   ObjectsDeleteAll(0, V9Obj("pl_"));
   if(!InpShowPools)
      return;
   datetime now = TimeCurrent();
   datetime right = now + 6 * PeriodSeconds();
   double tol = V9LabelTol();
   int drawn = 0;
   for(int i = 0; i < g_npool && drawn < 24; i++)
   {
      if(g_pool[i].cls < 2 || g_pool[i].status == PST_TAKEN)
         continue;
      string id = "pl_" + IntegerToString(i);
      int style = (g_pool[i].status == PST_SWEPT) ? STYLE_DOT : STYLE_DASHDOT;
      datetime left = g_pool[i].t;
      if(left < now - 6 * 3600)
         left = now - 6 * 3600;
      V9DrawLine(id, left, right, g_pool[i].price, InpClrPool, style, 1);
      string txt = V9PoolName(i) + StringFormat(" · sinf %d", g_pool[i].cls) + ((g_pool[i].status == PST_SWEPT) ? " · sweep" : "");
      if(V9LabelFree(g_pool[i].price, tol))
         V9DrawText(id + "t", right, g_pool[i].price, txt, InpClrPool, InpFontSize - 2);
      drawn++;
   }
}

//--- Devorlar
void V9DrawZones()
{
   ObjectsDeleteAll(0, V9Obj("zn_"));
   if(!InpShowZones)
      return;
   datetime right = TimeCurrent() + 6 * PeriodSeconds();
   double tol = V9LabelTol();
   for(int z = 0; z < g_nzone; z++)
   {
      string id = "zn_" + IntegerToString(z);
      color c = (g_zone[z].side > 0) ? InpClrSupply : InpClrDemand;
      V9DrawRect(id, g_zone[z].t, right, g_zone[z].lo, g_zone[z].hi, c);
      if(V9LabelFree(g_zone[z].hi, tol))
         V9DrawText(id + "t", right, g_zone[z].hi, V9TFName(g_zone[z].tfi) + ((g_zone[z].side > 0) ? " supply" : " demand"),
                    c, InpFontSize - 2);
   }
}

//--- Panel qatori
void V9PanelLine(const int row, const string text, const color clr)
{
   string name = V9Obj("pn_") + IntegerToString(row);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      V9ObjCommon(name);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + row * (InpFontSize + 8));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, (row == 0) ? "Bahnschrift SemiBold" : InpFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (row == 0) ? InpFontSize + 1 : InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

string V9LegDetail(const int tfi)
{
   if(!g_lv[tfi].ok)
      return "";
   double bid = V9Bid();
   string s = "HIMOYA " + V9Px(g_lv[tfi].himoya) + " (" + V9Dist(bid - g_lv[tfi].himoya) + ")";
   if(g_lv[tfi].targetIdx >= 0)
      s = s + " · MAQSAD " + V9PoolName(g_lv[tfi].targetIdx) + " " + V9Px(g_lv[tfi].target) + " (" + V9Dist(g_lv[tfi].target - bid) + ")";
   else
      s = s + " · MAQSAD topilmadi";
   s = s + " · ORIGIN " + V9Px(g_lv[tfi].origin);
   return s;
}

string V9LegBirthText(const int tfi)
{
   if(!g_lv[tfi].ok)
      return "";
   MqlDateTime t;
   TimeToStruct(g_lv[tfi].bornT, t);
   string q = (g_lv[tfi].birthQ == Q_STRONG) ? "kuchli" : ((g_lv[tfi].birthQ == Q_WEAK) ? "kuchsiz" : "oddiy");
   string s = StringFormat("tug'ildi %02d:%02d ", t.hour, t.min) + ((g_lv[tfi].birthType == EV_MSS) ? "MSS" : "BOS") + " (" + q + ")";
   s = s + (g_lv[tfi].confirmed ? " · tasdiqlandi" : " · tasdiq kutilmoqda");
   if(g_lv[tfi].revStage > 0)
      s = s + StringFormat(" · burilish %d-bosqich", g_lv[tfi].revStage);
   if(g_lv[tfi].counter > 0)
      s = s + StringFormat(" · teskari belgi %d/3", g_lv[tfi].counter);
   if(g_lv[tfi].stage == STG_TUGADI)
      s = s + " · olindi: " + g_lv[tfi].tugadiWhat;
   return s;
}

//--- Eng yangi muhim hodisa (M5 / M15 / H1): "M5 sweep ↓ 4194.00 (3 daq)"
string V9LastEventText()
{
   int bestTf = -1, bestI = -1;
   datetime bestT = 0;
   for(int tfi = V9_M5; tfi <= V9_H1; tfi++)
   {
      if(!g_ready[tfi])
         continue;
      for(int k = 0; k < V9EvCount(tfi); k++)
      {
         int i = V9EvNewest(tfi, k);
         int ty = g_ev[tfi][i].type;
         if(ty == EV_DISP || ty == EV_INNER)
            continue;
         if(g_ev[tfi][i].tc > bestT)
         {
            bestT = g_ev[tfi][i].tc;
            bestTf = tfi;
            bestI = i;
         }
         break;
      }
   }
   if(bestI < 0)
      return "hodisa yo'q";
   int mins = (int)((TimeCurrent() - bestT) / 60);
   string f = g_ev[bestTf][bestI].failed ? " (SOXTA chiqdi)" : "";
   return V9TFName(bestTf) + " " + V9EvName(g_ev[bestTf][bestI].type) + " " + V9Arrow(g_ev[bestTf][bestI].dir) + " " +
          V9Px(g_ev[bestTf][bestI].level) + f + StringFormat(" (%d daq oldin)", mins);
}

string V9PoolSideText(const int side)
{
   double bid = V9Bid();
   int best = -1;
   for(int i = 0; i < g_npool; i++)
   {
      if(g_pool[i].side != side || g_pool[i].status != PST_FRESH || g_pool[i].cls < 2)
         continue;
      if(side * (g_pool[i].price - bid) <= 0.0)
         continue;
      if(best < 0 || side * (g_pool[i].price - g_pool[best].price) < 0.0)
         best = i;
   }
   if(best < 0)
      return "yo'q";
   return V9PoolName(best) + " " + V9Px(g_pool[best].price) + StringFormat(" (sinf %d, ", g_pool[best].cls) +
          V9Dist(g_pool[best].price - bid) + ")";
}

void V9PanelDraw(const double ms)
{
   if(!InpShowPanel)
   {
      ObjectsDeleteAll(0, V9Obj("pn_"));
      return;
   }
   int r = 0;
   V9PanelLine(r++, "SIRUS V9 · KO'ZLAR (1-bosqich: faqat kuzatuv, savdo yo'q)", InpClrTitle);
   if(!g_ready[V9_M5] || !g_ready[V9_H1])
   {
      V9PanelLine(r++, "Tarix yuklanmoqda... (M5 / H1 barlari yetarli emas)", InpClrMuted);
      for(int k = r; k < g_panelLines; k++)
         ObjectDelete(0, V9Obj("pn_") + IntegerToString(k));
      g_panelLines = r;
      return;
   }
   color cM5 = (g_lv[V9_M5].dir > 0) ? InpClrUp : ((g_lv[V9_M5].dir < 0) ? InpClrDn : InpClrText);
   V9PanelLine(r++, "OYOQ M5: " + V9LegShort(V9_M5) + (g_lv[V9_M5].ok ? " · " + V9MapRelName(g_lv[V9_M5].mapRel) : ""), cM5);
   if(g_lv[V9_M5].ok)
   {
      V9PanelLine(r++, "   " + V9LegDetail(V9_M5), InpClrText);
      V9PanelLine(r++, "   " + V9LegBirthText(V9_M5), InpClrMuted);
   }
   color cH1 = (g_lv[V9_H1].dir > 0) ? InpClrUp : ((g_lv[V9_H1].dir < 0) ? InpClrDn : InpClrText);
   V9PanelLine(r++, "OYOQ H1: " + V9LegShort(V9_H1), cH1);
   if(g_lv[V9_H1].ok)
      V9PanelLine(r++, "   " + V9LegDetail(V9_H1), InpClrText);
   V9PanelLine(r++, "OYOQ H4: " + V9LegShort(V9_H4), InpClrText);
   V9PanelLine(r++, "XARITA: H1 " + V9MapStateName(g_mapState[V9_H1]) + " · H4 " + V9MapStateName(g_mapState[V9_H4]) +
                    " · " + V9DrText() + (g_bigLate ? " · DIQQAT: katta oyoq kech" : ""), InpClrText);
   V9PanelLine(r++, "DEVOR: tepada " + V9ZoneText(V9ZoneNearest(1)), InpClrSupply);
   V9PanelLine(r++, "DEVOR: pastda " + V9ZoneText(V9ZoneNearest(-1)), InpClrDemand);
   V9PanelLine(r++, "LIKVIDLIK: tepada " + V9PoolSideText(1), InpClrPool);
   V9PanelLine(r++, "LIKVIDLIK: pastda " + V9PoolSideText(-1), InpClrPool);
   color cQ = (g_qd.dir > 0) ? InpClrUp : ((g_qd.dir < 0) ? InpClrDn : InpClrText);
   V9PanelLine(r++, "QADAM M1: " + V9QadamText(), cQ);
   V9PanelLine(r++, "OXIRGI HODISA: " + V9LastEventText(), InpClrMuted);
   V9PanelLine(r++, StringFormat("tezlik %.2f ms · hovuz %d · devor %d", ms, g_npool, g_nzone), InpClrMuted);
   for(int k = r; k < g_panelLines; k++)
      ObjectDelete(0, V9Obj("pn_") + IntegerToString(k));
   g_panelLines = r;
}

void V9DrawAll(const bool full, const double ms)
{
   g_lblN = 0;
   if(InpShowM5Leg) V9DrawLeg(V9_M5, "M5_", true, 2);
   else             ObjectsDeleteAll(0, V9Obj("M5_"));
   if(InpShowH1Leg) V9DrawLeg(V9_H1, "H1_", false, 3);
   else             ObjectsDeleteAll(0, V9Obj("H1_"));
   if(full)
   {
      V9DrawPools();
      V9DrawZones();
   }
   V9PanelDraw(ms);
   ChartRedraw(0);
}

void V9PanelClear()
{
   ObjectsDeleteAll(0, V9_OBJ);
   g_panelLines = 0;
}
