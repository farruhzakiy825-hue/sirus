//+------------------------------------------------------------------+
//| SirusV9 - 50_Qadam                                               |
//| Savol: hozirmi?                                                  |
//| M1 da: oxirgi yopilgan sham niyati, 3 sham bosimi, shakllanayot- |
//| gan shamning erta displacement i, jonli (tick) sweep.            |
//| QADAM hech qachon yo'nalish TANLAMAYDI - faqat vaqtni aytadi.    |
//+------------------------------------------------------------------+

#define QI_NONE     0
#define QI_DISP     1   // displacement
#define QI_REJECT   2   // rad etish (dum)
#define QI_INDEC    3   // noaniq
#define QI_CONT     4   // oddiy davom shami
#define QI_SMALL    5   // kichik sham (signal emas)

struct SQadam
{
   int      intent;      // oxirgi yopilgan M1
   int      intentDir;
   int      pressure;    // oxirgi 3 yopilgan M1 bosimi: +1 / -1 / 0
   int      liveDisp;    // shakllanayotgan M1 erta displacement: +1 / -1 / 0
   int      lswDir;      // jonli sweep ma'nosi: +1 (lowlar olinib qaytdi) / -1 / 0
   double   lswLevel;
   datetime lswTime;
   int      dir;         // jami vaqt signali: +1 / -1 / 0
   string   why;
};

SQadam   g_qd;
datetime g_tkT[V9_TICK_RING];
double   g_tkBid[V9_TICK_RING];
int      g_tkN;
int      g_tkHead;

void V9TickPush(const datetime t, const double bid)
{
   g_tkT[g_tkHead] = t;
   g_tkBid[g_tkHead] = bid;
   g_tkHead = (g_tkHead + 1) % V9_TICK_RING;
   if(g_tkN < V9_TICK_RING)
      g_tkN++;
}

//--- Oxirgi `sec` soniyadagi eng baland / eng past bid.
void V9TickRange(const int sec, double &hi, double &lo)
{
   hi = 0.0;
   lo = 0.0;
   datetime now = TimeCurrent();
   for(int k = 0; k < g_tkN; k++)
   {
      int i = (g_tkHead - 1 - k + V9_TICK_RING) % V9_TICK_RING;
      if(now - g_tkT[i] > sec)
         break;
      if(hi == 0.0 || g_tkBid[i] > hi) hi = g_tkBid[i];
      if(lo == 0.0 || g_tkBid[i] < lo) lo = g_tkBid[i];
   }
}

//--- Yopilgan M1 sham niyati (V8 17:241 tartibi soddalashtirilgan: displacement birinchi).
void V9QadamClosed()
{
   g_qd.intent = QI_NONE;
   g_qd.intentDir = 0;
   g_qd.pressure = 0;
   int n = g_nbar[V9_M1];
   if(!g_ready[V9_M1] || n < 4)
      return;
   int k = n - 1;
   double atr = g_bar[V9_M1][k].atr;
   double o = g_bar[V9_M1][k].o, h = g_bar[V9_M1][k].h, l = g_bar[V9_M1][k].l, c = g_bar[V9_M1][k].c;
   double range = h - l;
   double body = MathAbs(c - o);
   if(atr <= 0.0 || range <= 0.0)
      return;
   double pos = (c - l) / range;
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;
   int cdir = (c > o) ? 1 : ((c < o) ? -1 : 0);
   if(cdir != 0 && body >= V9_DISP_BODY_ATR * atr && body >= V9_DISP_RATIO * range &&
      ((cdir > 0 && pos >= V9_DISP_CLOSE_POS) || (cdir < 0 && pos <= 1.0 - V9_DISP_CLOSE_POS)))
   { g_qd.intent = QI_DISP; g_qd.intentDir = cdir; }
   else if(range >= 0.5 * atr && lower >= V9_Q_REJ_WICK * range && pos >= V9_Q_REJ_CLOSE)
   { g_qd.intent = QI_REJECT; g_qd.intentDir = 1; }
   else if(range >= 0.5 * atr && upper >= V9_Q_REJ_WICK * range && pos <= 1.0 - V9_Q_REJ_CLOSE)
   { g_qd.intent = QI_REJECT; g_qd.intentDir = -1; }
   else if(body <= V9_Q_INDEC_BODY * range && range <= V9_Q_INDEC_RANGE * atr)
   { g_qd.intent = QI_INDEC; g_qd.intentDir = 0; }
   else if(body >= V9_Q_REAL_BODY * atr)
   { g_qd.intent = QI_CONT; g_qd.intentDir = cdir; }
   else
   { g_qd.intent = QI_SMALL; g_qd.intentDir = 0; }

   // Bosim: oxirgi 3 sham, bar o'lchami bilan tortilgan (E-7: kichik barlar bosim emas).
   double w[3] = {0.5, 0.3, 0.2};
   double p = 0.0;
   for(int j = 0; j < 3; j++)
   {
      int b = k - j;
      double a = g_bar[V9_M1][b].atr;
      if(a <= 0.0)
         continue;
      double bd = g_bar[V9_M1][b].c - g_bar[V9_M1][b].o;
      p += w[j] * MathMax(-1.0, MathMin(1.0, bd / a));
   }
   if(p > V9_PRESS_THR) g_qd.pressure = 1;
   else if(p < -V9_PRESS_THR) g_qd.pressure = -1;
}

//--- Jonli qism: har tickda.
void V9QadamLive()
{
   double bid = V9Bid();
   g_qd.liveDisp = 0;
   double atr1 = V9Atr(V9_M1);
   if(bid <= 0.0 || atr1 <= 0.0)
      return;
   double o0 = iOpen(_Symbol, PERIOD_M1, 0);
   double h0 = iHigh(_Symbol, PERIOD_M1, 0);
   double l0 = iLow(_Symbol, PERIOD_M1, 0);
   int n = g_nbar[V9_M1];
   double cPrev = (n > 0) ? g_bar[V9_M1][n - 1].c : 0.0;
   double rng = h0 - l0;
   if(o0 > 0.0 && rng > 0.0 && cPrev > 0.0)
   {
      double body = bid - o0;
      double pos = (bid - l0) / rng;
      if(body >= V9_Q_LIVE_DISP_ATR * atr1 && pos >= V9_DISP_CLOSE_POS && bid > cPrev) g_qd.liveDisp = 1;
      if(-body >= V9_Q_LIVE_DISP_ATR * atr1 && pos <= 1.0 - V9_DISP_CLOSE_POS && bid < cPrev) g_qd.liveDisp = -1;
   }

   // Jonli sweep: M1 / M5 swingi 45 s ichida teshildi va narx qaytib kirdi (V8 18:1060).
   double tHi = 0.0, tLo = 0.0;
   V9TickRange(V9_LSW_WINDOW_S, tHi, tLo);
   double minP = MathMax(V9_LSW_MIN_ATR1 * atr1, V9Spread());
   double nearDist = V9_LSW_NEAR_ATR5 * V9Atr(V9_M5);
   for(int tfi = V9_M1; tfi <= V9_M5; tfi++)
   {
      for(int s = 0; s < g_nsw[tfi]; s++)
      {
         if(g_sw[tfi][s].liq == LIQ_TAKEN || g_sw[tfi][s].broken)
            continue;
         double P = g_sw[tfi][s].price;
         if(MathAbs(P - bid) > nearDist)
            continue;
         if(g_sw[tfi][s].side > 0 && tHi > P + minP && bid < P)
         {
            g_qd.lswDir = -1;
            g_qd.lswLevel = P;
            g_qd.lswTime = TimeCurrent();
         }
         if(g_sw[tfi][s].side < 0 && tLo > 0.0 && tLo < P - minP && bid > P)
         {
            g_qd.lswDir = 1;
            g_qd.lswLevel = P;
            g_qd.lswTime = TimeCurrent();
         }
      }
   }
   if(g_qd.lswDir != 0 && TimeCurrent() - g_qd.lswTime > V9_LSW_VALID_S)
      g_qd.lswDir = 0;

   // Jami vaqt signali: eng yangi dalil ustun. Yo'nalishni tanlamaydi - faqat "hozir qaysi tomonga turtki bor".
   g_qd.dir = 0;
   g_qd.why = "aniq turtki yo'q";
   if(g_qd.lswDir != 0)
   {
      g_qd.dir = g_qd.lswDir;
      g_qd.why = "jonli sweep " + V9Px(g_qd.lswLevel);
   }
   else if(g_qd.liveDisp != 0)
   {
      g_qd.dir = g_qd.liveDisp;
      g_qd.why = "shakllanayotgan M1 displacement";
   }
   else if(g_qd.intent == QI_DISP || g_qd.intent == QI_REJECT)
   {
      g_qd.dir = g_qd.intentDir;
      g_qd.why = (g_qd.intent == QI_DISP) ? "M1 displacement yopildi" : "M1 rad etish shami";
   }
   else if(g_qd.pressure != 0)
   {
      g_qd.dir = g_qd.pressure;
      g_qd.why = "M1 bosimi";
   }
}

string V9QadamText()
{
   string s = V9Arrow(g_qd.dir) + " " + g_qd.why;
   if(g_qd.pressure != 0 && g_qd.pressure != g_qd.dir)
      s = s + " · bosim " + V9Arrow(g_qd.pressure);
   return s;
}
