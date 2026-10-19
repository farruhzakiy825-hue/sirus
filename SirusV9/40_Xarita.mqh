//+------------------------------------------------------------------+
//| SirusV9 - 40_Xarita                                              |
//| Savol: katta rasm qanday, devorlar qayerda?                      |
//| H1/H4 holati (7 holat), devorlar (H1/H4 supply/demand zonalari), |
//| dealing range (premium/discount), ish oyog'iga ruxsat.           |
//| Xarita o'zi savdo ochmaydi - faqat ruxsat va to'siqlarni beradi. |
//+------------------------------------------------------------------+

// 7 holat: +3 BULLISH, +2 BULLISH (zaif), +1 O'TISH yuqoriga, 0 NEYTRAL, -1, -2, -3 (oyna)
#define MAP_REL_NEUTRAL   0
#define MAP_REL_IMPULS    1
#define MAP_REL_KORREK   -1
#define MAP_REL_QARSHI   -2

struct SZone
{
   int      tfi;
   int      side;     // +1 supply (narx ustida, sotuv devori), -1 demand (narx ostida, xarid devori)
   double   lo;
   double   hi;
   datetime t;
   int      visits;
};

SZone g_zone[V9_ZONE_MAX];
int   g_nzone;
int   g_mapState[V9_TF_N];
double g_drPos;      // H1 dealing range ichidagi joy 0..1 (0 = H1 HIMOYA, 1 = H1 EKSTREMUM)
bool   g_drOk;
bool   g_bigLate;    // H1 oyog'i KECH / TUGADI va ish oyog'i shu tomonga

int V9Sign(const int x)
{
   if(x > 0) return 1;
   if(x < 0) return -1;
   return 0;
}

//--- TF holati oyoq ko'rinishidan.
int V9MapState(const int tfi)
{
   if(!g_lv[tfi].ok)
      return 0;
   int d = g_lv[tfi].dir;
   if(g_lv[tfi].birthType == EV_MSS && g_lv[tfi].revStage < 6)
      return d;                         // O'TISH: MSS bo'ldi, hali yangi BOS yo'q
   if(g_lv[tfi].stage >= STG_KECH || g_lv[tfi].counter >= 2 || g_lv[tfi].pullback >= V9_PB_GOLD_HI)
      return 2 * d;                     // zaif
   return 3 * d;
}

string V9MapStateName(const int st)
{
   switch(st)
   {
      case  3: return "BULLISH";
      case  2: return "BULLISH (zaif)";
      case  1: return "O'TISH";
      case -1: return "O'TISH";
      case -2: return "BEARISH (zaif)";
      case -3: return "BEARISH";
   }
   return "NEYTRAL";
}

//--- Devorlar: baza shami, keyin 3 bar ichida ATR x 1.5 uzoqlashish, baza chekkasidan o'tmasdan (V8 20g:80).
void V9ZonesScanTf(const int tfi)
{
   int n = g_nbar[tfi];
   double bid = V9Bid();
   double atrH1 = V9Atr(V9_H1);
   if(n < 10 || bid <= 0.0 || atrH1 <= 0.0)
      return;
   for(int i = 1; i + V9_Z_LEAVE_BARS < n; i++)
   {
      double atr = g_bar[tfi][i].atr;
      double o = g_bar[tfi][i].o, h = g_bar[tfi][i].h, l = g_bar[tfi][i].l, c = g_bar[tfi][i].c;
      double range = h - l;
      if(atr <= 0.0 || range <= 0.0 || range > V9_Z_BASE_RANGE * atr || MathAbs(c - o) > V9_Z_BASE_BODY * range)
         continue;
      for(int side = -1; side <= 1; side += 2)
      {
         // demand (side -1): keyingi barlar baza low idan pastga tushmaydi, yuqoriga ATR x 1.5 ketadi
         bool ok = true;
         double farPx = (side < 0) ? h : l;
         for(int j = i + 1; j <= i + V9_Z_LEAVE_BARS; j++)
         {
            if(side < 0 && g_bar[tfi][j].l < l) ok = false;
            if(side > 0 && g_bar[tfi][j].h > h) ok = false;
            farPx = (side < 0) ? MathMax(farPx, g_bar[tfi][j].h) : MathMin(farPx, g_bar[tfi][j].l);
         }
         if(!ok)
            continue;
         double leave = (side < 0) ? farPx - h : l - farPx;
         if(leave < V9_Z_LEAVE_ATR * atr)
            continue;
         double zlo = l, zhi = h;
         double minW = V9_Z_MIN_W_ATR * atr;
         if(zhi - zlo < minW)
         {
            double mid = (zhi + zlo) / 2.0;
            zlo = mid - minW / 2.0;
            zhi = mid + minW / 2.0;
         }
         // Keyingi tarix: buzildimi (uzoq chekkadan yopilish), necha marta tashrif buyurildi.
         bool broken = false;
         int visits = 0;
         bool outside = true;
         for(int j = i + V9_Z_LEAVE_BARS + 1; j < n && !broken; j++)
         {
            double bc = g_bar[tfi][j].c;
            if(side < 0 && bc < zlo) broken = true;
            if(side > 0 && bc > zhi) broken = true;
            bool touch = (side < 0) ? (g_bar[tfi][j].l <= zhi) : (g_bar[tfi][j].h >= zlo);
            if(touch && outside) visits++;
            outside = !touch;
         }
         if(broken || visits >= V9_Z_MAX_VISITS)
            continue;
         // Narx tomoni: supply narx ustida, demand ostida (yoki narx zona ichida).
         if(side > 0 && zhi < bid) continue;
         if(side < 0 && zlo > bid) continue;
         if(MathMin(MathAbs(zlo - bid), MathAbs(zhi - bid)) > V9_Z_WIN_ATRH1 * atrH1)
            continue;
         // Ustma-ust tushgan bir tomonli zona - eskisi qoladi.
         bool dup = false;
         for(int z = 0; z < g_nzone; z++)
            if(g_zone[z].side == side && g_zone[z].lo <= zhi && zlo <= g_zone[z].hi)
               dup = true;
         if(dup || g_nzone >= V9_ZONE_MAX)
            continue;
         g_zone[g_nzone].tfi = tfi;
         g_zone[g_nzone].side = side;
         g_zone[g_nzone].lo = zlo;
         g_zone[g_nzone].hi = zhi;
         g_zone[g_nzone].t = g_bar[tfi][i].t;
         g_zone[g_nzone].visits = visits;
         g_nzone++;
      }
   }
}

void V9ZonesRebuild()
{
   g_nzone = 0;
   if(g_ready[V9_H4]) V9ZonesScanTf(V9_H4);   // katta TF birinchi: ustma-ust bo'lsa u qoladi
   if(g_ready[V9_H1]) V9ZonesScanTf(V9_H1);
}

//--- Narx ustidagi eng yaqin supply (side +1) yoki ostidagi demand (side -1). -1 yo'q.
int V9ZoneNearest(const int side)
{
   double bid = V9Bid();
   int best = -1;
   double bestD = 0.0;
   for(int z = 0; z < g_nzone; z++)
   {
      if(g_zone[z].side != side)
         continue;
      double dist = (side > 0) ? g_zone[z].lo - bid : bid - g_zone[z].hi;
      if(dist < 0.0) dist = 0.0;   // narx zona ichida
      if(best < 0 || dist < bestD)
      {
         best = z;
         bestD = dist;
      }
   }
   return best;
}

string V9ZoneText(const int z)
{
   if(z < 0)
      return "yo'q";
   double bid = V9Bid();
   string nm = V9TFName(g_zone[z].tfi) + ((g_zone[z].side > 0) ? " supply " : " demand ");
   string rng = V9Px(g_zone[z].lo) + "-" + V9Px(g_zone[z].hi);
   bool inside = (bid >= g_zone[z].lo && bid <= g_zone[z].hi);
   if(inside)
      return nm + rng + " (NARX ICHIDA)";
   double dist = (g_zone[z].side > 0) ? g_zone[z].lo - bid : bid - g_zone[z].hi;
   return nm + rng + " (" + V9Dist(dist) + ")";
}

//--- Xarita: holatlar, dealing range, ish oyog'iga ruxsat.
void V9MapCompute()
{
   for(int tfi = 0; tfi < V9_TF_N; tfi++)
      g_mapState[tfi] = V9MapState(tfi);

   g_drOk = false;
   g_drPos = 0.0;
   if(g_lv[V9_H1].ok)
   {
      int d = g_lv[V9_H1].dir;
      double lo = (d > 0) ? g_lv[V9_H1].himoya : g_lv[V9_H1].ext;
      double hi = (d > 0) ? g_lv[V9_H1].ext : g_lv[V9_H1].himoya;
      if(hi > lo)
      {
         g_drPos = (V9Bid() - lo) / (hi - lo);
         g_drOk = true;
      }
   }

   g_bigLate = false;
   for(int tfi = V9_M1; tfi <= V9_M15; tfi++)
   {
      if(!g_lv[tfi].ok)
         continue;
      int d = g_lv[tfi].dir;
      int h1 = V9Sign(g_mapState[V9_H1]);
      int h4 = V9Sign(g_mapState[V9_H4]);
      int rel = MAP_REL_NEUTRAL;
      if(h1 == d)
         rel = MAP_REL_IMPULS;
      else if(h1 == -d)
         rel = (h4 == -d && MathAbs(g_mapState[V9_H1]) == 3) ? MAP_REL_QARSHI : MAP_REL_KORREK;
      g_lv[tfi].mapRel = rel;
   }
   if(g_lv[V9_M5].ok && g_lv[V9_H1].ok && g_lv[V9_M5].dir == g_lv[V9_H1].dir &&
      g_lv[V9_H1].stage >= STG_KECH)
      g_bigLate = true;
}

string V9MapRelName(const int rel)
{
   switch(rel)
   {
      case MAP_REL_IMPULS: return "IMPULS (H1 bilan)";
      case MAP_REL_KORREK: return "KORREKSIYA (H1 ga qarshi)";
      case MAP_REL_QARSHI: return "QARSHI (H1 va H4 ga qarshi)";
   }
   return "NEYTRAL (H1 aniq emas)";
}

string V9DrText()
{
   if(!g_drOk)
      return "H1 range aniqlanmadi";
   string where = "muvozanat";
   if(g_drPos > V9_DR_EQ_HI) where = "premium";
   if(g_drPos < V9_DR_EQ_LO) where = "discount";
   return StringFormat("%s %.0f%%", where, MathMax(0.0, MathMin(1.0, g_drPos)) * 100.0);
}
