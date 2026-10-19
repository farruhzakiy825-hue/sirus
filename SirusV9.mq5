//+------------------------------------------------------------------+
//| SirusV9.mq5 — SIRUS BY ZAKIY                                     |
//| 2-bosqich: KO'ZLAR + O'LCHOV. Faqat kuzatadi. SAVDO QILMAYDI:     |
//| bu faylda order yuboradigan hech qanday kod yo'q.                |
//|                                                                  |
//| Qatlamlar (V9_SKELET.md): 10 Hodisalar -> 20 Likvidlik ->        |
//| 30 Oyoq -> 40 Xarita -> 50 Qadam -> 60 O'lchov -> 95 Panel.      |
//| Mantiq: POYDEVOR.md, saboqlar: V8_XAZINA.md.                     |
//+------------------------------------------------------------------+
#property copyright   "SIRUS BY ZAKIY"
#property version     "9.02"
#property description "SIRUS V9 - 2-bosqich: ko'zlar + o'lchov (xayoliy savdolar). Savdo qilmaydi."

input group "SIRUS V9 ▸ Ko'rinish"
input bool   InpShowPanel     = true;   // Panel (premium karta)
input bool   InpShowWatermark = true;   // Watermark: chart o'rtasida, shamlar orqasida
input bool   InpShowM5Leg     = true;   // M5 oyog'i chiziqlari: ORIGIN / HIMOYA / MAQSAD
input bool   InpShowH1Leg     = true;   // H1 oyog'i chiziqlari (katta oyoq)
input int    InpFontSize      = 9;      // Shrift o'lchami
input int    InpPanelX        = 12;     // Panel: chapdan (px)
input int    InpPanelY        = 24;     // Panel: tepadan (px)

#include "SirusV9/01_Konstantalar.mqh"
#include "SirusV9/00_Asos.mqh"
#include "SirusV9/10_Hodisalar.mqh"
#include "SirusV9/20_Likvidlik.mqh"
#include "SirusV9/30_Oyoq.mqh"
#include "SirusV9/40_Xarita.mqh"
#include "SirusV9/50_Qadam.mqh"
#include "SirusV9/60_Olchov.mqh"
#include "SirusV9/95_Panel.mqh"

double g_msEma = 0.0;
uint   g_lastDraw = 0;

int OnInit()
{
   for(int tfi = 0; tfi < V9_TF_N; tfi++)
   {
      g_ready[tfi] = false;
      g_barT[tfi] = 0;
      g_nbar[tfi] = 0;
      g_nsw[tfi] = 0;
      g_evTotal[tfi] = 0;
      V9LegClear(g_leg[tfi]);
      g_lv[tfi].ok = false;
      g_mapState[tfi] = 0;
   }
   g_npool = 0;
   g_nzone = 0;
   g_tkN = 0;
   g_tkHead = 0;
   g_qd.dir = 0;
   g_qd.lswDir = 0;
   g_qd.why = "";
   V9OlInit();
   PrintFormat("[SIRUS V9] %s: 2-bosqich (ko'zlar + o'lchov) ishga tushdi - savdo qilmaydi, faqat kuzatadi", _Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   V9OlSave(true);
   V9PanelClear();
   ChartRedraw(0);
}

void OnTick()
{
   ulong t0 = GetMicrosecondCount();
   double bid = V9Bid();
   if(bid <= 0.0)
      return;
   V9TickPush(TimeCurrent(), bid);

   bool full = false;
   bool m1New = false;
   bool poolsDue = false;
   bool zonesDue = false;
   for(int tfi = 0; tfi < V9_TF_N; tfi++)
   {
      bool nb = V9NewBar(tfi);
      if(!nb && g_ready[tfi])
         continue;
      if(V9LoadBars(tfi))
      {
         g_ready[tfi] = true;
         V9EventsRebuild(tfi);
         full = true;
         if(tfi == V9_M1) m1New = true;
         if(tfi >= V9_M5) { poolsDue = true; zonesDue = true; }
      }
      else
      {
         g_ready[tfi] = false;
         g_barT[tfi] = 0;   // tarix hali yuklanmagan - keyingi tickda yana urinadi
      }
   }
   if(poolsDue)
      V9PoolsRebuild();
   if(zonesDue)
      V9ZonesRebuild();
   if(m1New)
      V9QadamClosed();

   for(int tfi = 0; tfi < V9_TF_N; tfi++)
      V9LegCompute(tfi);
   V9MapCompute();
   V9QadamLive();
   V9OlNow();
   if(m1New)
      V9OlStep();
   V9OlTick();
   V9OlSave(false);

   double ms = (double)(GetMicrosecondCount() - t0) / 1000.0;
   g_msEma = (g_msEma <= 0.0) ? ms : g_msEma * 0.95 + ms * 0.05;

   uint now = GetTickCount();
   if(full || now - g_lastDraw >= (uint)V9_DRAW_MS)
   {
      g_lastDraw = now;
      V9DrawAll(full, g_msEma);
   }
}

//--- Chart o'lchami / masshtabi o'zgarsa watermark joyiga qaytadi.
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      V9DrawWatermark();
      ChartRedraw(0);
   }
}
