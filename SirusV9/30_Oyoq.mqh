//+------------------------------------------------------------------+
//| SirusV9 - 30_Oyoq                                                |
//| Savol: qaysi oyoq yuryapti, qayerdan qayergacha, qayerda o'ladi? |
//| Oyoq holati 10_Hodisalar da yuritiladi; bu fayl uning pasportini |
//| (maqsad, foizlar, bosqich, qaytish zonasi, reversal bosqichi)    |
//| jonli narx bilan hisoblaydi. POYDEVOR.md 3-bo'lim.               |
//+------------------------------------------------------------------+

#define STG_NONE     0
#define STG_TUGILDI  1   // tug'ildi, 2 yopilish tasdig'i kutilmoqda
#define STG_YANGI    2
#define STG_RIVOJ    3
#define STG_KECH     4
#define STG_TUGADI   5

#define PBZ_YURISH   0
#define PBZ_SAYOZ    1
#define PBZ_OLTIN    2
#define PBZ_CHUQUR   3
#define PBZ_OLDI     4   // himoya oldi
#define PBZ_SINOV    5   // narx HIMOYA narisida, yopilish kutilmoqda

struct SLegView
{
   bool     ok;
   int      tfi;
   int      dir;
   double   origin;
   double   himoya;
   double   ext;        // jonli EKSTREMUM (yopilgan + shakllanayotgan bar)
   datetime bornT;
   datetime originT;
   datetime himoyaT;
   datetime extT;
   int      birthType;
   int      birthQ;
   double   birthLevel;
   bool     confirmed;
   int      waves;
   int      targetIdx;  // g_pool indeksi, -1 yo'q
   double   target;
   double   progress;   // 0..1+; -1 = maqsad yo'q
   double   lenAtr;     // uzunlik bir pog'ona katta TF ning ATR ida (M5 oyog'i -> ATR(M15))
   double   pullback;   // HIMOYA dan o'lchanadi: 0 = ekstremumda, 1 = himoyada
   int      stage;
   int      zone;
   int      revStage;   // shu oyoq MSS bilan tug'ilgan bo'lsa: 3..6
   int      counter;    // teskari tomonga burilish: 0..3 (1 sweep, 2 +displacement, 3 +ichki break)
   bool     tugadiByPool;
   string   tugadiWhat;
   int      mapRel;     // 40_Xarita: +1 IMPULS, -1 KORREKSIYA, -2 QARSHI, 0 neytral
};

SLegView g_lv[V9_TF_N];

//--- Maqsad uchun minimal hovuz sinfi: oyoq TF iga mos.
int V9LegTargetClass(const int tfi)
{
   if(tfi <= V9_M1)  return 1;
   if(tfi == V9_M5)  return 2;
   if(tfi == V9_M15) return 2;
   if(tfi == V9_H1)  return 3;
   return 4;
}

string V9StageName(const int st)
{
   switch(st)
   {
      case STG_TUGILDI: return "TUG'ILDI";
      case STG_YANGI:   return "YANGI";
      case STG_RIVOJ:   return "RIVOJ";
      case STG_KECH:    return "KECH";
      case STG_TUGADI:  return "TUGADI";
   }
   return "-";
}

string V9ZoneName(const int z)
{
   switch(z)
   {
      case PBZ_YURISH: return "yurishda";
      case PBZ_SAYOZ:  return "sayoz";
      case PBZ_OLTIN:  return "oltin zona";
      case PBZ_CHUQUR: return "chuqur";
      case PBZ_OLDI:   return "himoya oldi";
      case PBZ_SINOV:  return "HIMOYA sinovda";
   }
   return "-";
}

//--- Reversal bosqichi (V8 20b:408 dan soddalashtirilgan): MSS bilan tug'ilgan oyoq uchun.
//--- 3 = MSS; 4 = buzilgan darajaga retest va ushlab turdi; 5 = higher low / lower high; 6 = yangi BOS.
int V9RevStage(const int tfi)
{
   if(g_leg[tfi].dir == 0 || g_leg[tfi].birthType != EV_MSS)
      return 0;
   int d = g_leg[tfi].dir;
   int st = 3;
   double atr = V9Atr(tfi);
   int n = g_nbar[tfi];
   int b = g_leg[tfi].bornBi;
   if(atr <= 0.0 || b < 0)
      return st;
   double lvl = g_leg[tfi].birthLevel;
   for(int j = b + 1; j < n; j++)
   {
      double e = (d > 0) ? g_bar[tfi][j].l : g_bar[tfi][j].h;
      if(-d * (e - lvl) >= -V9_REV_RETEST_ATR * atr)
      {
         st = 4;
         break;
      }
   }
   for(int s = 0; s < g_nsw[tfi]; s++)
   {
      if(g_sw[tfi][s].bi <= b || g_sw[tfi][s].side != -d)
         continue;
      if(d * (g_sw[tfi][s].price - g_leg[tfi].origin) >= V9_REV_HL_ATR * atr)
      {
         st = MathMax(st, 5);
         break;
      }
   }
   if(g_leg[tfi].waves >= 2)
      st = 6;
   return st;
}

//--- Teskari tomonga burilish belgilari, oxirgi BOS (yoki tug'ilish) dan keyin.
int V9CounterStage(const int tfi)
{
   int d = g_leg[tfi].dir;
   if(d == 0)
      return 0;
   int from = g_leg[tfi].bornBi;
   for(int s = 0; s < V9EvCount(tfi); s++)
   {
      int i = V9EvNewest(tfi, s);
      if(g_ev[tfi][i].bi <= from)
         break;
      if(g_ev[tfi][i].type == EV_BOS && g_ev[tfi][i].dir == d && !g_ev[tfi][i].failed)
      {
         from = g_ev[tfi][i].bi;
         break;
      }
   }
   int sw = -1;
   for(int s = V9EvCount(tfi) - 1; s >= 0; s--)   // eskidan yangiga
   {
      int i = V9EvNewest(tfi, s);
      if(g_ev[tfi][i].bi <= from || g_ev[tfi][i].dir != -d || g_ev[tfi][i].failed)
         continue;
      if(g_ev[tfi][i].type == EV_SWEEP || g_ev[tfi][i].type == EV_FAKE || g_ev[tfi][i].type == EV_FAILED)
      {
         sw = g_ev[tfi][i].bi;
         break;
      }
   }
   if(sw < 0)
      return 0;
   int st = 1;
   if(V9EvFindNewest(tfi, EV_DISP, -d, sw) >= 0)
      st = 2;
   if(st == 2 && V9EvFindNewest(tfi, EV_INNER, -d, sw) >= 0)
      st = 3;
   return st;
}

//--- TUGADI: oyoq tug'ilgandan keyin o'z yo'nalishidagi katta hovuzni oldi / sweep qildi
//--- va shundan beri yangi BOS bo'lmadi.
bool V9LegTookPool(const int tfi, string &what)
{
   what = "";
   int d = g_leg[tfi].dir;
   int minCls = V9LegTargetClass(tfi) + 1;
   if(minCls > 5) minCls = 5;
   for(int i = 0; i < g_npool; i++)
   {
      if(g_pool[i].side != d || g_pool[i].status == PST_FRESH || g_pool[i].cls < minCls)
         continue;
      if(g_pool[i].statusT <= g_leg[tfi].bornT)
         continue;
      if(d * (g_pool[i].price - g_leg[tfi].origin) <= 0.0)
         continue;
      if(g_leg[tfi].lastBosT > g_pool[i].statusT)
         continue;
      what = V9PoolName(i) + " " + V9Px(g_pool[i].price);
      return true;
   }
   return false;
}

//--- Bitta TF oyog'ining ko'rinishi.
void V9LegCompute(const int tfi)
{
   g_lv[tfi].ok = false;
   g_lv[tfi].tfi = tfi;
   g_lv[tfi].dir = 0;
   g_lv[tfi].stage = STG_NONE;
   g_lv[tfi].mapRel = 0;
   int d = g_leg[tfi].dir;
   if(!g_ready[tfi] || d == 0 || g_leg[tfi].extBi < 0)
      return;
   int refTf = MathMin(tfi + 1, V9_H4);
   double atrRef = V9Atr(refTf) * ((tfi == V9_H4) ? 2.0 : 1.0);
   double bid = V9Bid();
   if(bid <= 0.0)
      return;

   g_lv[tfi].dir = d;
   g_lv[tfi].origin = g_leg[tfi].origin;
   g_lv[tfi].himoya = g_leg[tfi].himoya;
   g_lv[tfi].bornT = g_leg[tfi].bornT;
   g_lv[tfi].originT = g_bar[tfi][g_leg[tfi].originBi].t;
   g_lv[tfi].himoyaT = g_bar[tfi][g_leg[tfi].himoyaBi].t;
   g_lv[tfi].birthType = g_leg[tfi].birthType;
   g_lv[tfi].birthQ = g_leg[tfi].birthQ;
   g_lv[tfi].birthLevel = g_leg[tfi].birthLevel;
   g_lv[tfi].confirmed = g_leg[tfi].confirmed;
   g_lv[tfi].waves = g_leg[tfi].waves;

   // Jonli ekstremum: yopilgan ekstremum yoki shakllanayotgan bar (struktura undan olinmaydi).
   double ext = g_leg[tfi].ext;
   datetime extT = g_bar[tfi][g_leg[tfi].extBi].t;
   double live = (d > 0) ? V9LiveHigh(tfi) : V9LiveLow(tfi);
   if(live > 0.0 && d * (live - ext) > 0.0)
   {
      ext = live;
      extT = iTime(_Symbol, V9TF(tfi), 0);
   }
   g_lv[tfi].ext = ext;
   g_lv[tfi].extT = extT;

   // Maqsad: EKSTREMUM dan narida, oyoq yo'nalishidagi eng yaqin YANGI hovuz.
   double atr = V9Atr(tfi);
   g_lv[tfi].targetIdx = V9PoolAhead(d, ext, V9_TARGET_GAP_ATR * atr, V9LegTargetClass(tfi));
   g_lv[tfi].target = (g_lv[tfi].targetIdx >= 0) ? g_pool[g_lv[tfi].targetIdx].price : 0.0;

   double span = d * (ext - g_lv[tfi].origin);
   g_lv[tfi].lenAtr = (atrRef > 0.0) ? span / atrRef : 0.0;
   g_lv[tfi].progress = -1.0;
   if(g_lv[tfi].targetIdx >= 0)
   {
      double full = d * (g_lv[tfi].target - g_lv[tfi].origin);
      if(full > 0.0)
         g_lv[tfi].progress = span / full;
   }

   // Qaytish HIMOYA dan o'lchanadi (POYDEVOR 3.2).
   double leg = d * (ext - g_lv[tfi].himoya);
   g_lv[tfi].pullback = (leg > 0.0) ? d * (ext - bid) / leg : 0.0;
   double pb = g_lv[tfi].pullback;
   if(d * (bid - g_lv[tfi].himoya) < 0.0) g_lv[tfi].zone = PBZ_SINOV;
   else if(pb < V9_PB_SHALLOW)            g_lv[tfi].zone = PBZ_YURISH;
   else if(pb < V9_PB_GOLD_LO)            g_lv[tfi].zone = PBZ_SAYOZ;
   else if(pb < V9_PB_GOLD_HI)            g_lv[tfi].zone = PBZ_OLTIN;
   else if(pb < V9_PB_DEEP_HI)            g_lv[tfi].zone = PBZ_CHUQUR;
   else                                   g_lv[tfi].zone = PBZ_OLDI;

   // Bosqich
   string tw = "";
   g_lv[tfi].tugadiByPool = V9LegTookPool(tfi, tw);
   g_lv[tfi].tugadiWhat = tw;
   int st = STG_YANGI;
   if(!g_leg[tfi].confirmed)
      st = STG_TUGILDI;
   else if(g_lv[tfi].tugadiByPool)
      st = STG_TUGADI;
   else
   {
      if(g_lv[tfi].progress >= 0.0)
         st = (g_lv[tfi].progress < V9_STAGE_NEW) ? STG_YANGI : ((g_lv[tfi].progress < V9_STAGE_LATE) ? STG_RIVOJ : STG_KECH);
      else
         st = (g_lv[tfi].lenAtr < V9_LEN_NEW_ATR15) ? STG_YANGI : ((g_lv[tfi].lenAtr < V9_LEN_LATE_ATR15) ? STG_RIVOJ : STG_KECH);
      if(g_leg[tfi].waves >= V9_STAGE_WAVES_LATE && st < STG_KECH)
         st = STG_KECH;
   }
   g_lv[tfi].stage = st;
   g_lv[tfi].revStage = V9RevStage(tfi);
   g_lv[tfi].counter = V9CounterStage(tfi);
   g_lv[tfi].ok = true;
}

//--- Oyoq qisqa matni: "↑ RIVOJ 57% · qaytish 51% (oltin zona) · 2-turtki"
string V9LegShort(const int tfi)
{
   if(!g_lv[tfi].ok)
      return "oyoq yo'q (struktura aniqlanmadi)";
   string s = V9Arrow(g_lv[tfi].dir) + " " + V9StageName(g_lv[tfi].stage);
   if(g_lv[tfi].progress >= 0.0)
      s = s + " " + V9Pct(g_lv[tfi].progress);
   else
      s = s + StringFormat(" %.1f ATR(%s)", g_lv[tfi].lenAtr, V9TFName(MathMin(tfi + 1, V9_H4)));
   s = s + " · qaytish " + V9Pct(MathMax(0.0, g_lv[tfi].pullback)) + " (" + V9ZoneName(g_lv[tfi].zone) + ")";
   s = s + StringFormat(" · %d-turtki", g_lv[tfi].waves);
   return s;
}
