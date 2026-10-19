//+------------------------------------------------------------------+
//| SirusV9 - 20_Likvidlik                                           |
//| Savol: pul qayerda yotibdi?                                      |
//| Bitta xarita: M5/M15/H1/H4 swinglari + PDH/PDL + o'tgan hafta +  |
//| Osiyo sessiyasi. Yaqin darajalar birlashadi, sinf TF dan olinadi.|
//| Holat M5 yopilishlari bilan: YANGI / SWEEP / OLINDI.             |
//+------------------------------------------------------------------+

#define PST_FRESH  0
#define PST_SWEPT  1
#define PST_TAKEN  2

// Manba bitlari
#define PSRC_M5    1
#define PSRC_M15   2
#define PSRC_H1    4
#define PSRC_H4    8
#define PSRC_PD    16
#define PSRC_ASIA  32
#define PSRC_PW    64

struct SPool
{
   double   price;
   int      side;      // +1 buy-side (yuqorida, highlar), -1 sell-side (pastda, lowlar)
   int      cls;       // 1 LOCAL .. 5 EXTREME
   int      mask;      // manbalar
   int      sameTf;    // bir TF dan nechta swing qo'shildi (teng highlar)
   datetime t;         // daraja paydo bo'lgan vaqt
   int      status;
   datetime statusT;
};

SPool g_pool[V9_POOL_MAX];
int   g_npool;

int V9PoolClassOfTf(const int tfi)
{
   if(tfi == V9_M5)  return 1;
   if(tfi == V9_M15) return 2;
   if(tfi == V9_H1)  return 3;
   return 4;
}

int V9PoolSrcOfTf(const int tfi)
{
   if(tfi == V9_M5)  return PSRC_M5;
   if(tfi == V9_M15) return PSRC_M15;
   if(tfi == V9_H1)  return PSRC_H1;
   return PSRC_H4;
}

//--- Nomzodni xaritaga qo'shadi yoki yaqin darajaga birlashtiradi.
void V9PoolPut(const double price, const int side, const int cls, const int src, const datetime t, const double mergeTol)
{
   if(price <= 0.0)
      return;
   for(int i = 0; i < g_npool; i++)
   {
      if(g_pool[i].side != side || MathAbs(g_pool[i].price - price) > mergeTol)
         continue;
      // Birlashadi: chekkaroq narx vakil bo'ladi.
      if(side > 0) g_pool[i].price = MathMax(g_pool[i].price, price);
      else         g_pool[i].price = MathMin(g_pool[i].price, price);
      if((g_pool[i].mask & src) != 0 && (src & (PSRC_M5 | PSRC_M15 | PSRC_H1 | PSRC_H4)) != 0)
         g_pool[i].sameTf++;
      g_pool[i].mask |= src;
      g_pool[i].cls = MathMax(g_pool[i].cls, cls);
      if(t < g_pool[i].t)
         g_pool[i].t = t;
      return;
   }
   if(g_npool >= V9_POOL_MAX)
      return;
   g_pool[g_npool].price = price;
   g_pool[g_npool].side = side;
   g_pool[g_npool].cls = cls;
   g_pool[g_npool].mask = src;
   g_pool[g_npool].sameTf = 0;
   g_pool[g_npool].t = t;
   g_pool[g_npool].status = PST_FRESH;
   g_pool[g_npool].statusT = 0;
   g_npool++;
}

//--- Daraja paydo bo'lgandan keyingi M5 yopilishlari bilan holatini aniqlaydi.
void V9PoolStatus(const int i)
{
   int n = g_nbar[V9_M5];
   if(n <= 0)
      return;
   double lvl = g_pool[i].price;
   int side = g_pool[i].side;
   int run = 0;
   g_pool[i].status = PST_FRESH;
   g_pool[i].statusT = 0;
   for(int k = 0; k < n; k++)
   {
      if(g_bar[V9_M5][k].t <= g_pool[i].t)
         continue;
      double atr5 = g_bar[V9_M5][k].atr;
      double ext = (side > 0) ? g_bar[V9_M5][k].h : g_bar[V9_M5][k].l;
      double c = g_bar[V9_M5][k].c;
      if(side * (c - lvl) > 0.0)
      {
         run++;
         if(run >= V9_POOL_TAKEN_CLOSES)
         {
            g_pool[i].status = PST_TAKEN;
            g_pool[i].statusT = g_bar[V9_M5][k].tc;
            return;
         }
         continue;
      }
      run = 0;
      if(side * (ext - lvl) > V9_POOL_SWEEP_ATR5 * atr5)
      {
         g_pool[i].status = PST_SWEPT;
         g_pool[i].statusT = g_bar[V9_M5][k].tc;
      }
   }
}

//--- Bugungi Osiyo sessiyasi (tugagan bo'lsa) high / low.
bool V9AsiaRange(double &hi, double &lo, datetime &tEnd)
{
   hi = 0.0;
   lo = 0.0;
   tEnd = 0;
   datetime now = TimeCurrent();
   int off = V9ServerOffsetSec();
   datetime utcNow = now - off;
   MqlDateTime u;
   TimeToStruct(utcNow, u);
   datetime utcDay = utcNow - (u.hour * 3600 + u.min * 60 + u.sec);
   datetime from = utcDay + V9_ASIA_FROM_UTC * 3600 + off;   // server vaqtida
   datetime to = utcDay + V9_ASIA_TO_UTC * 3600 + off;
   if(now < to)
      return false;   // sessiya hali tugamagan
   MqlRates a[];
   ArraySetAsSeries(a, false);
   int na = CopyRates(_Symbol, PERIOD_M5, from, to - 1, a);
   if(na < 6)
      return false;
   hi = a[0].high;
   lo = a[0].low;
   for(int i = 1; i < na; i++)
   {
      hi = MathMax(hi, a[i].high);
      lo = MathMin(lo, a[i].low);
   }
   tEnd = to;
   return true;
}

//--- Xaritani qayta quradi. M5 va undan katta TF lar tayyor bo'lishi kerak.
void V9PoolsRebuild()
{
   g_npool = 0;
   double atr15 = V9Atr(V9_M15);
   double atrH1 = V9Atr(V9_H1);
   double bid = V9Bid();
   if(atr15 <= 0.0 || bid <= 0.0)
      return;
   double win = MathMax(V9_POOL_WIN_ATR15 * atr15, V9_POOL_WIN_ATRH1 * atrH1);
   double tol = V9_POOL_MERGE_ATR15 * atr15;

   // Eng katta manbadan boshlab - birlashganda katta sinf saqlanadi.
   datetime w0 = iTime(_Symbol, PERIOD_W1, 0);
   double pwh = iHigh(_Symbol, PERIOD_W1, 1), pwl = iLow(_Symbol, PERIOD_W1, 1);
   if(w0 > 0 && MathAbs(pwh - bid) <= win) V9PoolPut(pwh, 1, 4, PSRC_PW, w0, tol);
   if(w0 > 0 && MathAbs(pwl - bid) <= win) V9PoolPut(pwl, -1, 4, PSRC_PW, w0, tol);

   for(int tfi = V9_H4; tfi >= V9_M5; tfi--)
   {
      if(!g_ready[tfi])
         continue;
      for(int s = 0; s < g_nsw[tfi]; s++)
      {
         if(g_sw[tfi][s].liq == LIQ_TAKEN)
            continue;
         double p = g_sw[tfi][s].price;
         if(MathAbs(p - bid) > win)
            continue;
         V9PoolPut(p, g_sw[tfi][s].side, V9PoolClassOfTf(tfi), V9PoolSrcOfTf(tfi), g_sw[tfi][s].t, tol);
      }
   }

   datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   double pdh = iHigh(_Symbol, PERIOD_D1, 1), pdl = iLow(_Symbol, PERIOD_D1, 1);
   if(d0 > 0 && MathAbs(pdh - bid) <= win) V9PoolPut(pdh, 1, 3, PSRC_PD, d0, tol);
   if(d0 > 0 && MathAbs(pdl - bid) <= win) V9PoolPut(pdl, -1, 3, PSRC_PD, d0, tol);

   double ah = 0.0, al = 0.0;
   datetime ae = 0;
   if(V9AsiaRange(ah, al, ae))
   {
      if(MathAbs(ah - bid) <= win) V9PoolPut(ah, 1, 3, PSRC_ASIA, ae, tol);
      if(MathAbs(al - bid) <= win) V9PoolPut(al, -1, 3, PSRC_ASIA, ae, tol);
   }

   // Teng highlar / lowlar bir sinf yuqori (ko'pi bilan 5).
   for(int i = 0; i < g_npool; i++)
      if(g_pool[i].sameTf > 0)
         g_pool[i].cls = MathMin(5, g_pool[i].cls + 1);

   // Holat; uzoq vaqt oldin olingan darajalar tashlanadi.
   datetime now = TimeCurrent();
   int w = 0;
   for(int i = 0; i < g_npool; i++)
   {
      V9PoolStatus(i);
      if(g_pool[i].status == PST_TAKEN && now - g_pool[i].statusT > V9_POOL_KEEP_TAKEN_S)
         continue;
      if(w != i)
         g_pool[w] = g_pool[i];
      w++;
   }
   g_npool = w;
}

string V9PoolName(const int i)
{
   int m = g_pool[i].mask;
   string s = "";
   if((m & PSRC_PW) != 0)        s = (g_pool[i].side > 0) ? "PWH" : "PWL";
   else if((m & PSRC_PD) != 0)   s = (g_pool[i].side > 0) ? "PDH" : "PDL";
   else if((m & PSRC_ASIA) != 0) s = (g_pool[i].side > 0) ? "Osiyo high" : "Osiyo low";
   else if((m & PSRC_H4) != 0)   s = (g_pool[i].side > 0) ? "H4 high" : "H4 low";
   else if((m & PSRC_H1) != 0)   s = (g_pool[i].side > 0) ? "H1 high" : "H1 low";
   else if((m & PSRC_M15) != 0)  s = (g_pool[i].side > 0) ? "M15 high" : "M15 low";
   else                          s = (g_pool[i].side > 0) ? "M5 high" : "M5 low";
   if(g_pool[i].sameTf > 0)
      s = s + ((g_pool[i].side > 0) ? " (teng highlar)" : " (teng lowlar)");
   return s;
}

//--- dir tomonda, `from` dan narida (gap bilan), sinfi >= minCls bo'lgan eng yaqin YANGI hovuz. -1 yo'q.
int V9PoolAhead(const int dir, const double from, const double gap, const int minCls)
{
   int best = -1;
   for(int i = 0; i < g_npool; i++)
   {
      if(g_pool[i].side != dir || g_pool[i].status != PST_FRESH || g_pool[i].cls < minCls)
         continue;
      if(dir * (g_pool[i].price - from) <= gap)
         continue;
      if(best < 0 || dir * (g_pool[i].price - g_pool[best].price) < 0.0)
         best = i;
   }
   return best;
}
