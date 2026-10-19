//+------------------------------------------------------------------+
//| SirusV9 - 10_Hodisalar                                           |
//| Savol: bozorda nima bo'ldi?                                      |
//| BITTA swing qoidasi, BOS / SINDI (MSS) / ichki break, sweep,     |
//| soxta break, displacement - har TF uchun.                        |
//|                                                                  |
//| Har TF har yangi barda TARIXDAN QAYTA QURILADI (eskidan yangiga).|
//| Shuning uchun: restartdan keyin holat yo'qolmaydi, kelajakka     |
//| qarash yo'q (swing faqat o'ng tomonidagi barlar yopilgandan      |
//| keyin ma'lum bo'ladi), va har hodisa o'z vaqtidagi ATR bilan     |
//| o'lchanadi.                                                      |
//|                                                                  |
//| Oyoq holati (yo'nalish, ORIGIN, HIMOYA, EKSTREMUM) ham shu yerda |
//| yuritiladi: oyoq struktura hodisalarining natijasi.              |
//+------------------------------------------------------------------+

//--- Hodisa turlari
#define EV_BOS     1    // oyoq yo'nalishida swing buzildi (yoki birinchi oyoq tug'ildi)
#define EV_MSS     2    // HIMOYA buzildi: eski oyoq SINDI, teskari oyoq TUG'ILDI
#define EV_INNER   3    // oyoqqa qarshi ichki (kichik) swing buzildi - bu pullback, oyoq tirik
#define EV_SWEEP   4    // swing teshildi va ichkarida yopildi (likvidlik olindi)
#define EV_FAKE    5    // juda chuqur teshib qaytdi (ATR x 1 dan ko'p)
#define EV_DISP    6    // displacement shami
#define EV_FAILED  7    // break 2 yopilish ichida qaytarib olindi (SOXTA) - teskari tomon uchun dalil

//--- Break sifati
#define Q_WEAK     1
#define Q_VALID    2
#define Q_STRONG   3

//--- Swing likvidligi
#define LIQ_INTACT 0
#define LIQ_SWEPT  1
#define LIQ_TAKEN  2

struct SEvent
{
   int      type;
   int      dir;      // hodisaning MA'NOSI: +1 bullish, -1 bearish
   int      tfi;
   double   level;
   datetime tc;       // hodisa bari yopilgan vaqt
   int      bi;       // bar indeksi (shu qayta qurishda)
   int      q;
   bool     failed;
   bool     confirmed;
   bool     strong;
};

struct SSwing
{
   int      bi;       // swing bari indeksi
   datetime t;        // swing bari ochilish vaqti
   double   price;
   int      side;     // +1 high (buy-side likvidlik), -1 low (sell-side)
   bool     broken;   // struktura ma'nosida buzilgan (BOS / ichki break uchun ishlatib bo'lingan)
   int      liq;      // LIQ_INTACT / LIQ_SWEPT / LIQ_TAKEN
   int      sweeps;
   double   sweepExt; // eng chuqur teshish narxi
   datetime liqT;     // likvidlik holati o'zgargan bar yopilishi
};

//--- Oyoq holati (struktura mashinasi). Ko'rinish (foiz, bosqich, maqsad) 30_Oyoq da hisoblanadi.
struct SLegState
{
   int      dir;        // +1 / -1, 0 = hali oyoq yo'q
   double   origin;     // oyoq tug'ilgan ekstremum (qotib qoladi)
   int      originBi;
   double   himoya;     // o'lim chizig'i (har VALID+ BOS bilan suriladi)
   int      himoyaBi;
   double   ext;        // tug'ilgandan beri eng uzoq nuqta (faqat yopilgan barlar)
   int      extBi;
   int      bornBi;
   datetime bornT;      // tug'ilgan bar yopilishi
   int      birthType;  // EV_BOS (birinchi oyoq) yoki EV_MSS
   int      birthQ;
   double   birthLevel; // tug'dirgan buzilgan daraja
   bool     confirmed;  // 2 yopilish qaytmadi
   int      waves;      // turtkilar: tug'ilish + har VALID+ BOS
   datetime lastBosT;
};

struct SPending
{
   bool      on;
   int       kind;      // 1 = tug'ilish, 2 = BOS
   int       bi;
   int       dir;
   double    level;
   int       swingIdx;  // BOS bo'lsa - buzilgan swing
   int       evAbs;     // hodisa halqasidagi mutlaq raqami
   SLegState snap;      // break oldidagi oyoq holati (SOXTA bo'lsa tiklanadi)
};

SSwing    g_sw[V9_TF_N][V9_SW_MAX];
int       g_nsw[V9_TF_N];
SEvent    g_ev[V9_TF_N][V9_EV_MAX];
int       g_evTotal[V9_TF_N];          // mutlaq hisoblagich; indeks = total % V9_EV_MAX
SLegState g_leg[V9_TF_N];
SPending  g_pend[V9_TF_N][V9_PEND_MAX];
int       g_refHi[V9_TF_N];            // eng yangi tasdiqlangan swing high (g_sw indeksi), -1 yo'q
int       g_refLo[V9_TF_N];
int       g_lastFailBi[V9_TF_N];
int       g_lastFailDir[V9_TF_N];
double    g_lastFailLvl[V9_TF_N];

//--- Hodisa halqasi
int V9EvAdd(const int tfi, const int type, const int dir, const double level, const int bi, const int q, const bool strong)
{
   int a = g_evTotal[tfi];
   int i = a % V9_EV_MAX;
   g_ev[tfi][i].type      = type;
   g_ev[tfi][i].dir       = dir;
   g_ev[tfi][i].tfi       = tfi;
   g_ev[tfi][i].level     = level;
   g_ev[tfi][i].tc        = g_bar[tfi][bi].tc;
   g_ev[tfi][i].bi        = bi;
   g_ev[tfi][i].q         = q;
   g_ev[tfi][i].failed    = false;
   g_ev[tfi][i].confirmed = false;
   g_ev[tfi][i].strong    = strong;
   g_evTotal[tfi] = a + 1;
   return a;
}

bool V9EvAlive(const int tfi, const int abs_idx)
{
   return (abs_idx >= 0 && abs_idx < g_evTotal[tfi] && g_evTotal[tfi] - abs_idx <= V9_EV_MAX);
}

int V9EvCount(const int tfi)
{
   return MathMin(g_evTotal[tfi], V9_EV_MAX);
}

//--- Eng yangidan k-chi hodisa (k = 0 eng yangi). Halqa indeksini qaytaradi, -1 yo'q.
int V9EvNewest(const int tfi, const int k)
{
   if(k < 0 || k >= V9EvCount(tfi))
      return -1;
   return (g_evTotal[tfi] - 1 - k) % V9_EV_MAX;
}

int V9BreakQuality(const int tfi, const int k, const double atr)
{
   double body = MathAbs(g_bar[tfi][k].c - g_bar[tfi][k].o);
   if(body < V9_Q_WEAK_BODY * atr)
      return Q_WEAK;
   if(body >= V9_Q_STRONG_BODY * atr)
      return Q_STRONG;
   return Q_VALID;
}

//--- [from..to] oralig'idagi eng past low / eng baland high indeksi
int V9LowestBi(const int tfi, const int from, const int to)
{
   int best = from;
   for(int j = from; j <= to; j++)
      if(g_bar[tfi][j].l < g_bar[tfi][best].l)
         best = j;
   return best;
}

int V9HighestBi(const int tfi, const int from, const int to)
{
   int best = from;
   for(int j = from; j <= to; j++)
      if(g_bar[tfi][j].h > g_bar[tfi][best].h)
         best = j;
   return best;
}

void V9LegClear(SLegState &L)
{
   L.dir = 0;
   L.origin = 0.0;
   L.originBi = -1;
   L.himoya = 0.0;
   L.himoyaBi = -1;
   L.ext = 0.0;
   L.extBi = -1;
   L.bornBi = -1;
   L.bornT = 0;
   L.birthType = 0;
   L.birthQ = 0;
   L.birthLevel = 0.0;
   L.confirmed = false;
   L.waves = 0;
   L.lastBosT = 0;
}

//--- Oyoq yo'nalishida eng uzoq yopilgan nuqtani [from..to] oralig'idan yangilaydi.
void V9LegExtFrom(const int tfi, SLegState &L, const int from, const int to)
{
   if(L.dir == 0 || from > to)
      return;
   for(int j = from; j <= to; j++)
   {
      if(L.dir > 0 && (L.extBi < 0 || g_bar[tfi][j].h > L.ext))
      {
         L.ext = g_bar[tfi][j].h;
         L.extBi = j;
      }
      if(L.dir < 0 && (L.extBi < 0 || g_bar[tfi][j].l < L.ext))
      {
         L.ext = g_bar[tfi][j].l;
         L.extBi = j;
      }
   }
}

//--- Yangi oyoq tug'iladi. origin = himoya = protBi dagi ekstremum.
void V9LegBirth(const int tfi, SLegState &L, const int dir, const int protBi, const int k,
                const int birthType, const int q, const double level)
{
   L.dir = dir;
   L.originBi = protBi;
   L.origin = (dir > 0) ? g_bar[tfi][protBi].l : g_bar[tfi][protBi].h;
   L.himoyaBi = protBi;
   L.himoya = L.origin;
   L.ext = 0.0;
   L.extBi = -1;
   V9LegExtFrom(tfi, L, protBi, k);
   L.bornBi = k;
   L.bornT = g_bar[tfi][k].tc;
   L.birthType = birthType;
   L.birthQ = q;
   L.birthLevel = level;
   L.confirmed = false;
   L.waves = 1;
   L.lastBosT = 0;
}

void V9PendAdd(const int tfi, const int kind, const int k, const int dir, const double level,
               const int swingIdx, const int evAbs, const SLegState &snap)
{
   for(int p = 0; p < V9_PEND_MAX; p++)
   {
      if(g_pend[tfi][p].on)
         continue;
      g_pend[tfi][p].on = true;
      g_pend[tfi][p].kind = kind;
      g_pend[tfi][p].bi = k;
      g_pend[tfi][p].dir = dir;
      g_pend[tfi][p].level = level;
      g_pend[tfi][p].swingIdx = swingIdx;
      g_pend[tfi][p].evAbs = evAbs;
      g_pend[tfi][p].snap = snap;
      return;
   }
   // To'la bo'lsa: eng eskisini tasdiqlangan deb hisoblab, joyini beradi.
   int oldest = 0;
   for(int p = 1; p < V9_PEND_MAX; p++)
      if(g_pend[tfi][p].bi < g_pend[tfi][oldest].bi)
         oldest = p;
   g_pend[tfi][oldest].on = false;
   V9PendAdd(tfi, kind, k, dir, level, swingIdx, evAbs, snap);
}

//--- Bar k yopildi: kutayotgan breaklarni tekshiradi (SOXTA yoki TASDIQLANDI).
//--- Eskidan yangiga: biri SOXTA bo'lsa, holat uning oldiga qaytadi va undan keyingilar ham bekor bo'ladi.
void V9PendingStep(const int tfi, const int k, const double atr)
{
   int order[V9_PEND_MAX];
   int cnt = 0;
   for(int q = 0; q < V9_PEND_MAX; q++)
   {
      if(!g_pend[tfi][q].on)
         continue;
      int pos = cnt;
      while(pos > 0 && g_pend[tfi][order[pos - 1]].bi > g_pend[tfi][q].bi)
      {
         order[pos] = order[pos - 1];
         pos--;
      }
      order[pos] = q;
      cnt++;
   }
   for(int x = 0; x < cnt; x++)
   {
      int p = order[x];
      if(!g_pend[tfi][p].on)
         continue;
      int age = k - g_pend[tfi][p].bi;
      if(age < 1)
         continue;
      int d = g_pend[tfi][p].dir;
      bool back = (d * (g_bar[tfi][k].c - g_pend[tfi][p].level) < -V9_FAIL_BACK_ATR * atr);
      if(back)
      {
         int pbi = g_pend[tfi][p].bi;
         double plvl = g_pend[tfi][p].level;
         g_leg[tfi] = g_pend[tfi][p].snap;
         V9LegExtFrom(tfi, g_leg[tfi], pbi, k);
         for(int q = 0; q < V9_PEND_MAX; q++)
         {
            if(!g_pend[tfi][q].on || g_pend[tfi][q].bi < pbi)
               continue;
            if(V9EvAlive(tfi, g_pend[tfi][q].evAbs))
               g_ev[tfi][g_pend[tfi][q].evAbs % V9_EV_MAX].failed = true;
            int si = g_pend[tfi][q].swingIdx;
            if(si >= 0 && si < g_nsw[tfi])
               g_sw[tfi][si].broken = false;   // swing qaytadan ishlaydi: u faqat teshilgan edi
            g_pend[tfi][q].on = false;
         }
         V9EvAdd(tfi, EV_FAILED, -d, plvl, k, 0, false);
         g_lastFailBi[tfi] = k;
         g_lastFailDir[tfi] = d;
         g_lastFailLvl[tfi] = plvl;
         return;
      }
      if(age >= V9_FAIL_BARS)
      {
         if(V9EvAlive(tfi, g_pend[tfi][p].evAbs))
            g_ev[tfi][g_pend[tfi][p].evAbs % V9_EV_MAX].confirmed = true;
         if(g_pend[tfi][p].kind == 1 && g_leg[tfi].bornBi == g_pend[tfi][p].bi)
            g_leg[tfi].confirmed = true;
         g_pend[tfi][p].on = false;
      }
   }
}

//--- Bitta swing qoidasi (V8 18:353): yangi tomonda qat'iy (>), eski tomonda >= .
//--- Bar k yopilganda i = k - len dagi bar swing ekani ma'lum bo'ladi.
void V9SwingStep(const int tfi, const int k, const int len)
{
   int i = k - len;
   if(i - len < 0)
      return;
   bool isHi = true, isLo = true;
   for(int j = 1; j <= len; j++)
   {
      if(!(g_bar[tfi][i].h > g_bar[tfi][i + j].h) || !(g_bar[tfi][i].h >= g_bar[tfi][i - j].h)) isHi = false;
      if(!(g_bar[tfi][i].l < g_bar[tfi][i + j].l) || !(g_bar[tfi][i].l <= g_bar[tfi][i - j].l)) isLo = false;
   }
   for(int side = 1; side >= -1; side -= 2)
   {
      if((side > 0 && !isHi) || (side < 0 && !isLo))
         continue;
      int n = g_nsw[tfi];
      if(n >= V9_SW_MAX)
         return;
      g_sw[tfi][n].bi = i;
      g_sw[tfi][n].t = g_bar[tfi][i].t;
      g_sw[tfi][n].price = (side > 0) ? g_bar[tfi][i].h : g_bar[tfi][i].l;
      g_sw[tfi][n].side = side;
      g_sw[tfi][n].broken = false;
      g_sw[tfi][n].liq = LIQ_INTACT;
      g_sw[tfi][n].sweeps = 0;
      g_sw[tfi][n].sweepExt = g_sw[tfi][n].price;
      g_sw[tfi][n].liqT = 0;
      g_nsw[tfi] = n + 1;
      if(side > 0) g_refHi[tfi] = n;
      else         g_refLo[tfi] = n;
   }
}

//--- Likvidlik: bar k swinglarni teshdimi, ichkarida yopildimi, yoki narida yopildimi.
void V9LiquidityStep(const int tfi, const int k, const double atr)
{
   double minP = V9_SWEEP_MIN_ATR * atr;
   double maxP = V9_SWEEP_MAX_ATR * atr;
   double take = V9_TAKEN_CLOSE_ATR * atr;
   for(int s = 0; s < g_nsw[tfi]; s++)
   {
      if(g_sw[tfi][s].liq == LIQ_TAKEN || g_sw[tfi][s].bi >= k)
         continue;
      int side = g_sw[tfi][s].side;
      double P = g_sw[tfi][s].price;
      double ext = (side > 0) ? g_bar[tfi][k].h : g_bar[tfi][k].l;
      double c = g_bar[tfi][k].c;
      if(side * (c - P) > take)
      {
         g_sw[tfi][s].liq = LIQ_TAKEN;
         g_sw[tfi][s].liqT = g_bar[tfi][k].tc;
         continue;
      }
      if(side * (ext - P) <= minP)
         continue;
      // Teshdi va ichkarida (yoki daraja ustida) yopildi. Qayta sweep faqat yangi chuqurlikda.
      if(g_sw[tfi][s].liq == LIQ_SWEPT && side * (ext - g_sw[tfi][s].sweepExt) <= 0.0)
         continue;
      double depth = side * (ext - P);
      int type = (depth <= maxP) ? EV_SWEEP : EV_FAKE;
      V9EvAdd(tfi, type, -side, P, k, 0, depth > maxP);
      g_sw[tfi][s].liq = LIQ_SWEPT;
      g_sw[tfi][s].sweeps++;
      g_sw[tfi][s].sweepExt = ext;
      g_sw[tfi][s].liqT = g_bar[tfi][k].tc;
   }
}

//--- Bar k close narisida qolgan bir tomonli swinglar struktura ma'nosida buzilgan.
void V9MarkBrokenBeyond(const int tfi, const int side, const double close)
{
   for(int s = 0; s < g_nsw[tfi]; s++)
   {
      if(g_sw[tfi][s].broken || g_sw[tfi][s].side != side)
         continue;
      if(side * (close - g_sw[tfi][s].price) > 0.0)
         g_sw[tfi][s].broken = true;
   }
}

//--- Struktura: BOS (oyoq yo'nalishida), SINDI -> teskari oyoq (MSS), ichki break.
void V9StructureStep(const int tfi, const int k, const double atr)
{
   double c = g_bar[tfi][k].c;
   double buf = V9_BREAK_BUF_ATR * atr;
   int d = g_leg[tfi].dir;

   if(d == 0)
   {
      // Hali oyoq yo'q: birinchi VALID+ break oyoqni tug'diradi.
      for(int side = 1; side >= -1; side -= 2)
      {
         int si = (side > 0) ? g_refHi[tfi] : g_refLo[tfi];
         if(si < 0 || g_sw[tfi][si].broken)
            continue;
         double P = g_sw[tfi][si].price;
         if(side * (c - P) <= buf)
            continue;
         int q = V9BreakQuality(tfi, k, atr);
         g_sw[tfi][si].broken = true;
         int ev = V9EvAdd(tfi, EV_BOS, side, P, k, q, q == Q_STRONG);
         if(q < Q_VALID)
            continue;
         SLegState snap = g_leg[tfi];
         int protBi = (side > 0) ? V9LowestBi(tfi, g_sw[tfi][si].bi, k) : V9HighestBi(tfi, g_sw[tfi][si].bi, k);
         V9LegBirth(tfi, g_leg[tfi], side, protBi, k, EV_BOS, q, P);
         V9MarkBrokenBeyond(tfi, side, c);
         V9PendAdd(tfi, 1, k, side, P, si, ev, snap);
         return;
      }
      return;
   }

   // 1. SINDI: HIMOYA narisida yopilish -> eski oyoq tugadi, teskari oyoq tug'iladi.
   if(d * (c - g_leg[tfi].himoya) < -V9_SINDI_BUF_ATR * atr)
   {
      int q = V9BreakQuality(tfi, k, atr);
      double lvl = g_leg[tfi].himoya;
      // Yangi oyoq eski oyoqning EKSTREMUMidan boshlanadi (eng uzoq nuqtadan pastga / yuqoriga ketdi).
      int from = (g_leg[tfi].extBi >= 0) ? g_leg[tfi].extBi : MathMax(0, g_leg[tfi].himoyaBi);
      int protBi = (d > 0) ? V9HighestBi(tfi, from, k) : V9LowestBi(tfi, from, k);
      SLegState snap = g_leg[tfi];
      int ev = V9EvAdd(tfi, EV_MSS, -d, lvl, k, q, q == Q_STRONG);
      V9LegBirth(tfi, g_leg[tfi], -d, protBi, k, EV_MSS, q, lvl);
      V9MarkBrokenBeyond(tfi, -d, c);
      V9PendAdd(tfi, 1, k, -d, lvl, -1, ev, snap);
      return;
   }

   // 2. BOS oyoq yo'nalishida.
   int si = (d > 0) ? g_refHi[tfi] : g_refLo[tfi];
   if(si >= 0 && !g_sw[tfi][si].broken)
   {
      double P = g_sw[tfi][si].price;
      if(d * (c - P) > buf)
      {
         int q = V9BreakQuality(tfi, k, atr);
         g_sw[tfi][si].broken = true;
         int ev = V9EvAdd(tfi, EV_BOS, d, P, k, q, q == Q_STRONG);
         if(q >= Q_VALID)
         {
            SLegState snap = g_leg[tfi];
            int protBi = (d > 0) ? V9LowestBi(tfi, g_sw[tfi][si].bi, k) : V9HighestBi(tfi, g_sw[tfi][si].bi, k);
            g_leg[tfi].himoyaBi = protBi;
            g_leg[tfi].himoya = (d > 0) ? g_bar[tfi][protBi].l : g_bar[tfi][protBi].h;
            g_leg[tfi].waves++;
            g_leg[tfi].lastBosT = g_bar[tfi][k].tc;
            V9PendAdd(tfi, 2, k, d, P, si, ev, snap);
         }
         V9MarkBrokenBeyond(tfi, d, c);
      }
   }

   // 3. Ichki break: oyoqqa qarshi kichik swing buzildi, lekin HIMOYA ushlab turibdi - pullback.
   int sj = (d > 0) ? g_refLo[tfi] : g_refHi[tfi];
   if(sj >= 0 && !g_sw[tfi][sj].broken)
   {
      double P = g_sw[tfi][sj].price;
      if(-d * (c - P) > buf)
      {
         g_sw[tfi][sj].broken = true;
         V9EvAdd(tfi, EV_INNER, -d, P, k, V9BreakQuality(tfi, k, atr), false);
      }
   }
}

//--- Displacement shami
void V9DispStep(const int tfi, const int k, const double atr)
{
   double o = g_bar[tfi][k].o, h = g_bar[tfi][k].h, l = g_bar[tfi][k].l, c = g_bar[tfi][k].c;
   double range = h - l;
   double body = MathAbs(c - o);
   if(range <= 0.0 || body < V9_DISP_BODY_ATR * atr || body < V9_DISP_RATIO * range)
      return;
   double pos = (c - l) / range;
   int dir = 0;
   if(c > o && pos >= V9_DISP_CLOSE_POS) dir = 1;
   if(c < o && pos <= 1.0 - V9_DISP_CLOSE_POS) dir = -1;
   if(dir == 0)
      return;
   V9EvAdd(tfi, EV_DISP, dir, c, k, 0, body >= V9_DISP_STRONG_ATR * atr);
}

//--- Bitta TF ni tarixdan qayta quradi.
void V9EventsRebuild(const int tfi)
{
   int n = g_nbar[tfi];
   g_nsw[tfi] = 0;
   g_evTotal[tfi] = 0;
   g_refHi[tfi] = -1;
   g_refLo[tfi] = -1;
   g_lastFailBi[tfi] = -1;
   g_lastFailDir[tfi] = 0;
   g_lastFailLvl[tfi] = 0.0;
   V9LegClear(g_leg[tfi]);
   for(int p = 0; p < V9_PEND_MAX; p++)
      g_pend[tfi][p].on = false;
   int len = (tfi == V9_M1) ? V9_SWING_LEN_M1 : V9_SWING_LEN_HTF;
   for(int k = 0; k < n; k++)
   {
      double atr = g_bar[tfi][k].atr;
      if(atr <= 0.0)
         continue;
      V9PendingStep(tfi, k, atr);
      V9SwingStep(tfi, k, len);
      V9LiquidityStep(tfi, k, atr);
      V9StructureStep(tfi, k, atr);
      V9LegExtFrom(tfi, g_leg[tfi], k, k);
      V9DispStep(tfi, k, atr);
   }
}

//--- Oxirgi bar ostidagi eng yangi hodisa (turi, yo'nalishi, minimal bar indeksi bo'yicha). Halqa indeksi, -1 yo'q.
int V9EvFindNewest(const int tfi, const int type, const int dir, const int minBi)
{
   int cnt = V9EvCount(tfi);
   for(int k = 0; k < cnt; k++)
   {
      int i = V9EvNewest(tfi, k);
      if(g_ev[tfi][i].bi < minBi)
         return -1;
      if(g_ev[tfi][i].type != type || g_ev[tfi][i].failed)
         continue;
      if(dir != 0 && g_ev[tfi][i].dir != dir)
         continue;
      return i;
   }
   return -1;
}

string V9EvName(const int type)
{
   switch(type)
   {
      case EV_BOS:    return "BOS";
      case EV_MSS:    return "MSS";
      case EV_INNER:  return "ichki break";
      case EV_SWEEP:  return "sweep";
      case EV_FAKE:   return "soxta break";
      case EV_DISP:   return "displacement";
      case EV_FAILED: return "SOXTA";
   }
   return "?";
}
