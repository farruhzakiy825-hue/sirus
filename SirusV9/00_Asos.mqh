//+------------------------------------------------------------------+
//| SirusV9 - 00_Asos                                                |
//| Turlar, timeframe'lar, barlar va ATR, umumiy yordamchilar.       |
//| Hech qanday qaror yo'q.                                          |
//+------------------------------------------------------------------+

#define V9_TF_N   5
#define V9_M1     0
#define V9_M5     1
#define V9_M15    2
#define V9_H1     3
#define V9_H4     4

ENUM_TIMEFRAMES V9TF(const int tfi)
{
   if(tfi == V9_M1)  return PERIOD_M1;
   if(tfi == V9_M5)  return PERIOD_M5;
   if(tfi == V9_M15) return PERIOD_M15;
   if(tfi == V9_H1)  return PERIOD_H1;
   return PERIOD_H4;
}

string V9TFName(const int tfi)
{
   if(tfi == V9_M1)  return "M1";
   if(tfi == V9_M5)  return "M5";
   if(tfi == V9_M15) return "M15";
   if(tfi == V9_H1)  return "H1";
   return "H4";
}

int V9BarsWanted(const int tfi)
{
   return (tfi == V9_H4) ? V9_BARS_H4 : V9_BARS_MAX;
}

//--- Bitta yopilgan bar. t = ochilish, tc = yopilish vaqti (hodisalar shu bilan vaqtlanadi).
struct SBar
{
   datetime t;
   datetime tc;
   double   o;
   double   h;
   double   l;
   double   c;
   double   atr;   // shu bargacha (shu bar bilan) ATR - hodisa o'z vaqtidagi ATR bilan o'lchanadi
};

SBar     g_bar[V9_TF_N][V9_BARS_MAX];
int      g_nbar[V9_TF_N];
datetime g_barT[V9_TF_N];     // oxirgi yuklangan forming barning ochilish vaqti (yangi bar detektori)
bool     g_ready[V9_TF_N];

//--- TF ning yopilgan barlarini yuklaydi (eskidan yangiga) va har bar uchun ATR hisoblaydi.
bool V9LoadBars(const int tfi)
{
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int want = V9BarsWanted(tfi);
   int got = CopyRates(_Symbol, V9TF(tfi), 1, want, r);
   if(got < V9_BARS_MIN)
      return false;
   if(got > V9_BARS_MAX)
      got = V9_BARS_MAX;
   int ps = PeriodSeconds(V9TF(tfi));
   double tr[];
   ArrayResize(tr, got);
   double sum = 0.0;
   for(int i = 0; i < got; i++)
   {
      double x = r[i].high - r[i].low;
      if(i > 0)
      {
         x = MathMax(x, MathAbs(r[i].high - r[i - 1].close));
         x = MathMax(x, MathAbs(r[i].low - r[i - 1].close));
      }
      tr[i] = x;
      sum += x;
      if(i >= V9_ATR_N)
         sum -= tr[i - V9_ATR_N];
      int cnt = MathMin(i + 1, V9_ATR_N);
      g_bar[tfi][i].t   = r[i].time;
      g_bar[tfi][i].tc  = r[i].time + ps;
      g_bar[tfi][i].o   = r[i].open;
      g_bar[tfi][i].h   = r[i].high;
      g_bar[tfi][i].l   = r[i].low;
      g_bar[tfi][i].c   = r[i].close;
      g_bar[tfi][i].atr = sum / (double)cnt;
   }
   g_nbar[tfi] = got;
   return true;
}

//--- Yangi (forming) bar ochildimi?
bool V9NewBar(const int tfi)
{
   datetime t0 = iTime(_Symbol, V9TF(tfi), 0);
   if(t0 <= 0)
      return false;
   if(t0 == g_barT[tfi])
      return false;
   g_barT[tfi] = t0;
   return true;
}

//--- Oxirgi yopilgan barning ATR i (narx birligida). 0 = tayyor emas.
double V9Atr(const int tfi)
{
   int n = g_nbar[tfi];
   if(!g_ready[tfi] || n <= 0)
      return 0.0;
   return g_bar[tfi][n - 1].atr;
}

double V9Bid()    { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double V9Ask()    { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double V9Spread() { return V9Ask() - V9Bid(); }

//--- Shakllanayotgan barning high / low (jonli EKSTREMUM uchun; struktura hech qachon undan olinmaydi).
double V9LiveHigh(const int tfi) { return iHigh(_Symbol, V9TF(tfi), 0); }
double V9LiveLow(const int tfi)  { return iLow(_Symbol, V9TF(tfi), 0); }

//--- Matn yordamchilari
string V9Px(const double p)
{
   return DoubleToString(p, _Digits);
}

string V9Dist(const double d)
{
   return StringFormat("%.1f$", MathAbs(d));
}

string V9Arrow(const int dir)
{
   if(dir > 0) return "▲";
   if(dir < 0) return "▼";
   return "—";
}

string V9Pct(const double x)
{
   return StringFormat("%.0f%%", x * 100.0);
}

//--- Server soati UTC dan qancha farq qiladi (30 daqiqaga yaxlitlangan). Testerda 0.
int V9ServerOffsetSec()
{
   long d = (long)(TimeTradeServer() - TimeGMT());
   long half = 1800;
   long r = (d >= 0) ? ((d + half / 2) / half) * half : -(((-d) + half / 2) / half) * half;
   return (int)r;
}
