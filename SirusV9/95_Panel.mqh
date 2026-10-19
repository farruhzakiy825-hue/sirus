//+------------------------------------------------------------------+
//| SirusV9 - 95_Panel                                               |
//| Faqat O'QIYDI va chizadi. Hech qanday qaror yo'q.                |
//|                                                                  |
//| WATERMARK: chart o'rtasida (panel bo'sh qoldirgan qismda),       |
//| shamlar ORQASIDA, "S I R U S" + oltin chiziq + "B Y  Z A K I Y". |
//| Rang chart fonidan aralashtiriladi - qorong'i va yorug' fonda    |
//| ham sokin turadi (V8 25_Visual_Design dizayni).                  |
//|                                                                  |
//| PANEL: bitta karta, bitta ustun. Sarlavha + holat "pill", keyin  |
//| OYOQ (progress chiziqlari), KATTA RASM, LIKVIDLIK va DEVOR,      |
//| QADAM, O'LCHOV, oxirgi hodisa. Matn Segoe UI, raqamlar Consolas, |
//| brend va sarlavhalar Bahnschrift.                                |
//|                                                                  |
//| CHART: faqat oyoq chiziqlari (ORIGIN, HIMOYA, MAQSAD) - M5 va H1.|
//| Mayda zonalar va hovuzlar CHIZILMAYDI: robot ularni ko'radi,     |
//| panel aytadi. Chiziqlar har soniyada suzmaydi - o'ng cheti faqat |
//| yangi chart barida siljiydi.                                     |
//+------------------------------------------------------------------+

#define V9_UI       "SV9_UI_"
#define V9F_BRAND   "Bahnschrift SemiBold"
#define V9F_LIGHT   "Bahnschrift Light"
#define V9F_TEXT    "Segoe UI"
#define V9F_BOLD    "Segoe UI Semibold"
#define V9F_MONO    "Consolas"
#define V9_PANEL_W  450
#define V9_PAD      14

//====================================================================
// Rang tizimi (chart fonidan)
//====================================================================
color g_bgClr = clrBlack;
bool  g_bgDark = true;
uint  g_bgMs = 0;
bool  g_bgRead = false;
int   g_panelRight = 0;   // panel o'ng cheti (watermark bo'sh qismga joylashadi)

color V9Blend(const color a, const color b, const double t)
{
   double k = MathMax(0.0, MathMin(1.0, t));
   uint ua = (uint)a, ub = (uint)b;
   int ar = (int)(ua & 0xFF), ag = (int)((ua >> 8) & 0xFF), ab = (int)((ua >> 16) & 0xFF);
   int br = (int)(ub & 0xFF), bg = (int)((ub >> 8) & 0xFF), bb = (int)((ub >> 16) & 0xFF);
   int r = (int)MathRound(ar + (br - ar) * k);
   int g = (int)MathRound(ag + (bg - ag) * k);
   int b2 = (int)MathRound(ab + (bb - ab) * k);
   return (color)((uint)r | ((uint)g << 8) | ((uint)b2 << 16));
}

color V9Bg()
{
   uint now = GetTickCount();
   if(!g_bgRead || now - g_bgMs > 3000)
   {
      g_bgRead = true;
      g_bgMs = now;
      g_bgClr = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
      uint c = (uint)g_bgClr;
      g_bgDark = ((0.299 * (c & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * ((c >> 16) & 0xFF)) < 128.0);
   }
   return g_bgClr;
}

bool  V9Dark()    { V9Bg(); return g_bgDark; }
color V9Ink()     { return V9Dark() ? C'232,236,243' : C'24,29,38'; }
color V9Muted()   { return V9Dark() ? C'138,148,166' : C'98,108,124'; }
color V9Gold()    { return C'212,175,55'; }
color V9Card()    { return V9Blend(V9Bg(), (V9Dark() ? C'255,255,255' : C'0,0,0'), V9Dark() ? 0.07 : 0.035); }
color V9Border()  { return V9Blend(V9Bg(), V9Gold(), V9Dark() ? 0.45 : 0.55); }
color V9Track()   { return V9Blend(V9Card(), V9Ink(), 0.12); }
color V9Green()   { return V9Dark() ? C'46,204,128' : C'22,150,88'; }
color V9Red()     { return V9Dark() ? C'239,90,90' : C'200,48,48'; }
color V9Amber()   { return V9Dark() ? C'245,176,65' : C'196,124,16'; }
color V9Blue()    { return V9Dark() ? C'74,163,255' : C'30,110,210'; }
color V9DirClr(const int d) { return (d > 0) ? V9Green() : ((d < 0) ? V9Red() : V9Muted()); }

//====================================================================
// Primitivlar
//====================================================================
double V9Scale()
{
   int dpi = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   return (dpi > 96) ? dpi / 96.0 : 1.0;
}

int V9Pix(const int pt)
{
   return (int)MathRound(pt * 1.333 * V9Scale());
}

int V9TextW(const string text, const string font, const int size)
{
   uint tw = 0, th = 0;
   TextSetFont(font, -size * 10);
   if(!TextGetSize(text, tw, th))
      return (int)(StringLen(text) * size * 0.85);
   return (int)tw;
}

string V9UIName(const string id)
{
   string p = V9_UI;
   return p + id;
}

void V9UIRect(const string id, const int x, const int y, const int w, const int h, const color fill, const color border, const bool back)
{
   string name = V9UIName(id);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, w));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, h));
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}

void V9UIText(const string id, const string text, const int x, const int y, const color clr, const int size,
              const string font, const ENUM_ANCHOR_POINT anchor, const bool back)
{
   string name = V9UIName(id);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, (StringLen(text) > 0) ? text : " ");
}

void V9UIDel(const string id)
{
   string name = V9UIName(id);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

//--- Matn kenglikka sig'masa "…" bilan qisqaradi.
string V9Fit(const string text, const string font, const int size, const int maxPx)
{
   if(V9TextW(text, font, size) <= maxPx)
      return text;
   int lo = 1, hi = StringLen(text);
   while(lo < hi)
   {
      int mid = (lo + hi + 1) / 2;
      if(V9TextW(StringSubstr(text, 0, mid) + "…", font, size) <= maxPx) lo = mid;
      else hi = mid - 1;
   }
   return StringSubstr(text, 0, lo) + "…";
}

string V9Spaced(const string text)
{
   string out = "";
   int n = StringLen(text);
   for(int i = 0; i < n; i++)
   {
      string ch = StringSubstr(text, i, 1);
      out = out + ((ch == " ") ? "   " : ch);
      if(i < n - 1 && ch != " ")
         out = out + " ";
   }
   return out;
}

//--- Pill: o'ng cheti xr da. Kengligini qaytaradi.
int V9UIPill(const string id, const string text, const int xr, const int y, const color clr)
{
   int fs = InpFontSize - 1;
   int w = V9TextW(text, V9F_BRAND, fs) + 16;
   int h = V9Pix(fs) + 6;
   V9UIRect(id + "_bg", xr - w, y - 2, w, h, V9Blend(V9Card(), clr, 0.22), V9Blend(V9Card(), clr, 0.70), false);
   V9UIText(id + "_tx", text, xr - w / 2, y - 2 + h / 2, clr, fs, V9F_BRAND, ANCHOR_CENTER, false);
   return w;
}

void V9UIPillDel(const string id)
{
   V9UIDel(id + "_bg");
   V9UIDel(id + "_tx");
}

//--- Progress chizig'i: 0..1. ticks: 0..1 oralig'idagi belgilar (masalan oltin zona chegaralari).
void V9UIBar(const string id, const int x, const int y, const int w, const int h, const double frac, const color fill,
             const double t1, const double t2, const double t3)
{
   double f = MathMax(0.0, MathMin(1.0, frac));
   V9UIRect(id + "_tr", x, y, w, h, V9Track(), V9Track(), false);
   V9UIRect(id + "_fl", x, y, MathMax(1, (int)(w * f)), h, fill, fill, false);
   double tk[3];
   tk[0] = t1;
   tk[1] = t2;
   tk[2] = t3;
   for(int i = 0; i < 3; i++)
   {
      string tid = id + "_t" + IntegerToString(i);
      if(tk[i] > 0.0 && tk[i] < 1.0)
         V9UIRect(tid, x + (int)(w * tk[i]), y - 2, 1, h + 4, V9Muted(), V9Muted(), false);
      else
         V9UIDel(tid);
   }
}

//====================================================================
// Watermark
//====================================================================
void V9DrawWatermark()
{
   if(!InpShowWatermark)
   {
      ObjectsDeleteAll(0, V9UIName("WM_"));
      return;
   }
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(w <= 0 || h <= 0)
      return;
   color bg = V9Bg();
   color ink = V9Dark() ? C'255,255,255' : C'0,0,0';
   color tint = V9Blend(ink, V9Gold(), 0.55);
   double t = 0.20;
   string title = V9Spaced("SIRUS");
   int left = (g_panelRight > 0 && g_panelRight < w - 200) ? g_panelRight : 0;
   int freeW = w - left;
   int size = 64;
   int tw = V9TextW(title, V9F_BRAND, size);
   if(tw > freeW - 60 && tw > 0)
      size = MathMax(36, (int)(size * (double)(freeW - 60) / tw));
   tw = V9TextW(title, V9F_BRAND, size);
   int px = V9Pix(size);
   int cx = left + freeW / 2;
   int cy = h / 2;   // egasi: har doim chartning vertikal o'rtasi

   V9UIText("WM_TITLE", title, cx, cy - px / 4, V9Blend(bg, tint, t), size, V9F_BRAND, ANCHOR_CENTER, true);
   int lineW = (int)(tw * 0.72);
   int lineY = cy + (int)(px * 0.36);
   color rule = V9Blend(bg, V9Gold(), MathMin(0.75, t * 3.2));
   V9UIRect("WM_RULE", cx - lineW / 2, lineY, lineW, 2, rule, rule, true);
   int dsz = MathMax(7, size / 9);
   V9UIText("WM_DL", "◆", cx - lineW / 2 - dsz, lineY + 1, rule, dsz, "Segoe UI Symbol", ANCHOR_CENTER, true);
   V9UIText("WM_DR", "◆", cx + lineW / 2 + dsz, lineY + 1, rule, dsz, "Segoe UI Symbol", ANCHOR_CENTER, true);
   int subSize = MathMax(9, size / 5);
   V9UIText("WM_SUB", V9Spaced("BY ZAKIY"), cx, lineY + (int)(V9Pix(subSize) * 1.45), V9Blend(bg, tint, t * 1.2),
            subSize, V9F_LIGHT, ANCHOR_CENTER, true);
}

//====================================================================
// Chart: oyoq chiziqlari
//====================================================================
double g_lblP[16];
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

bool V9LabelFree(const double p, const double tol)
{
   for(int i = 0; i < g_lblN; i++)
      if(MathAbs(g_lblP[i] - p) < tol)
         return false;
   if(g_lblN < 16)
   {
      g_lblP[g_lblN] = p;
      g_lblN++;
   }
   return true;
}

string V9ObjName(const string id)
{
   string p = V9_OBJ;
   return p + id;
}

void V9ChartLine(const string id, const datetime t1, const datetime t2, const double price, const color clr,
                 const int style, const int width)
{
   string name = V9ObjName(id);
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price))
         return;
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   ObjectMove(0, name, 0, t1, price);
   ObjectMove(0, name, 1, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void V9ChartText(const string id, const datetime t, const double price, const string text, const color clr)
{
   string name = V9ObjName(id);
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
         return;
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   ObjectMove(0, name, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, V9F_TEXT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize - 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void V9ChartDel(const string id)
{
   string name = V9ObjName(id);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void V9ChartLeg(const int tfi, const string pre, const int width)
{
   if(!g_lv[tfi].ok)
   {
      ObjectsDeleteAll(0, V9ObjName(pre));
      return;
   }
   int P = PeriodSeconds();
   datetime bar0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime right = bar0 + 6 * P;     // faqat yangi chart barida siljiydi
   double tol = V9LabelTol();
   string tf = V9TFName(tfi) + " ";
   color cOrg = V9Muted();
   color cHim = V9Red();
   color cTgt = V9Blue();

   V9ChartLine(pre + "org", g_lv[tfi].originT, right, g_lv[tfi].origin, cOrg, STYLE_DOT, 1);
   V9ChartText(pre + "lorg", V9LabelFree(g_lv[tfi].origin, tol) ? right + P : right + 14 * P, g_lv[tfi].origin,
               tf + "ORIGIN " + V9Px(g_lv[tfi].origin), cOrg);
   V9ChartLine(pre + "him", g_lv[tfi].himoyaT, right, g_lv[tfi].himoya, cHim, STYLE_SOLID, width);
   V9ChartText(pre + "lhim", V9LabelFree(g_lv[tfi].himoya, tol) ? right + P : right + 14 * P, g_lv[tfi].himoya,
               tf + "HIMOYA " + V9Px(g_lv[tfi].himoya), cHim);
   if(g_lv[tfi].targetIdx >= 0)
   {
      V9ChartLine(pre + "tgt", g_lv[tfi].originT, right, g_lv[tfi].target, cTgt, STYLE_DASH, width);
      V9ChartText(pre + "ltgt", V9LabelFree(g_lv[tfi].target, tol) ? right + P : right + 14 * P, g_lv[tfi].target,
                  tf + "MAQSAD " + V9PoolName(g_lv[tfi].targetIdx) + " " + V9Px(g_lv[tfi].target), cTgt);
   }
   else
   {
      V9ChartDel(pre + "tgt");
      V9ChartDel(pre + "ltgt");
   }
}

//====================================================================
// Panel
//====================================================================
int g_py = 0;   // chizish kursori

int V9Row(const int size)
{
   return V9Pix(size) + 7;
}

//--- Bo'lim sarlavhasi: "O Y O Q  ·  M 5" + ingichka chiziq.
void V9Section(const string id, const string title, const int x, const int w)
{
   int fs = InpFontSize - 1;
   g_py += 6;
   string t = V9Spaced(title);
   V9UIText(id + "_h", t, x, g_py, V9Blend(V9Muted(), V9Gold(), 0.35), fs, V9F_BRAND, ANCHOR_LEFT_UPPER, false);
   int tw = V9TextW(t, V9F_BRAND, fs);
   int ly = g_py + V9Pix(fs) / 2 + 1;
   V9UIRect(id + "_ln", x + tw + 10, ly, MathMax(1, w - tw - 10), 1, V9Blend(V9Card(), V9Gold(), 0.35),
            V9Blend(V9Card(), V9Gold(), 0.35), false);
   g_py += V9Row(fs);
}

//--- Qator: chapda matn, o'ngda qiymat (Consolas).
void V9Line(const string id, const string left, const color lc, const string right, const color rc,
            const int x, const int w, const bool bold)
{
   int fs = InpFontSize;
   int rw = (StringLen(right) > 0) ? V9TextW(right, V9F_MONO, fs) + 12 : 0;
   V9UIText(id + "_l", V9Fit(left, bold ? V9F_BOLD : V9F_TEXT, fs, w - rw), x, g_py, lc, fs,
            bold ? V9F_BOLD : V9F_TEXT, ANCHOR_LEFT_UPPER, false);
   if(rw > 0)
      V9UIText(id + "_r", right, x + w, g_py, rc, fs, V9F_MONO, ANCHOR_RIGHT_UPPER, false);
   else
      V9UIDel(id + "_r");
   g_py += V9Row(fs);
}

void V9LineDel(const string id)
{
   V9UIDel(id + "_l");
   V9UIDel(id + "_r");
}

//--- Progress qatori: chapda nom, o'rtada chiziq, o'ngda qiymat.
void V9BarLine(const string id, const string name, const double frac, const color fill, const string value,
               const color vc, const int x, const int w, const double t1, const double t2, const double t3)
{
   int fs = InpFontSize;
   int labW = 64;
   int valW = 150;
   V9UIText(id + "_n", name, x, g_py, V9Muted(), fs, V9F_TEXT, ANCHOR_LEFT_UPPER, false);
   int bx = x + labW;
   int bw = MathMax(40, w - labW - valW);
   int bh = 6;
   int by = g_py + V9Pix(fs) / 2 - bh / 2 + 1;
   V9UIBar(id + "_b", bx, by, bw, bh, frac, fill, t1, t2, t3);
   V9UIText(id + "_v", value, x + w, g_py, vc, fs, V9F_MONO, ANCHOR_RIGHT_UPPER, false);
   g_py += V9Row(fs);
}

void V9BarLineDel(const string id)
{
   V9UIDel(id + "_n");
   V9UIDel(id + "_v");
   ObjectsDeleteAll(0, V9UIName(id + "_b"));
}

color V9StageClr(const int st)
{
   switch(st)
   {
      case STG_YANGI:  return V9Green();
      case STG_RIVOJ:  return V9Blue();
      case STG_KECH:   return V9Amber();
      case STG_TUGADI: return V9Red();
   }
   return V9Muted();
}

color V9VerdictClr(const int v)
{
   if(v == 1)  return V9Green();
   if(v == -1) return V9Red();
   if(v == 0)  return V9Amber();
   return V9Muted();
}

string V9Ago(const datetime t)
{
   long sec = (long)(TimeCurrent() - t);
   if(sec < 0) sec = 0;
   if(sec >= 86400) return StringFormat("%d kun", (int)(sec / 86400));
   if(sec >= 3600)  return StringFormat("%d soat", (int)(sec / 3600));
   return StringFormat("%d daq", (int)(sec / 60));
}

//--- Eng yangi muhim hodisa (M5 / M15 / H1).
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
   string f = g_ev[bestTf][bestI].failed ? " (SOXTA chiqdi)" : "";
   return V9TFName(bestTf) + " " + V9EvName(g_ev[bestTf][bestI].type) + " " + V9Arrow(g_ev[bestTf][bestI].dir) + " " +
          V9Px(g_ev[bestTf][bestI].level) + f + " · " + V9Ago(bestT) + " oldin";
}

//--- Narxdan `side` tomondagi eng yaqin YANGI hovuz (sinf >= 2). -1 yo'q.
int V9PoolNearestSide(const int side)
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
   return best;
}

void V9PanelDraw(const double ms, const double msBar)
{
   if(!InpShowPanel)
   {
      ObjectsDeleteAll(0, V9UIName("P_"));
      g_panelRight = 0;
      return;
   }
   int X = InpPanelX;
   int W = (int)(V9_PANEL_W * MathMin(1.4, V9Scale()));
   int x = X + V9_PAD;
   int w = W - 2 * V9_PAD;
   double bid = V9Bid();
   g_panelRight = X + W;

   // Karta foni birinchi yaratiladi - qolganlari uning ustida.
   V9UIRect("P_card", X, InpPanelY, W, 40, V9Card(), V9Border(), false);
   V9UIRect("P_top", X, InpPanelY, W, 3, V9Gold(), V9Gold(), false);
   g_py = InpPanelY + 12;

   // Sarlavha
   int bfs = InpFontSize + 7;
   string brand = V9Spaced("SIRUS");
   V9UIText("P_brand", brand, x, g_py, V9Gold(), bfs, V9F_BRAND, ANCHOR_LEFT_UPPER, false);
   int bw = V9TextW(brand, V9F_BRAND, bfs);
   V9UIText("P_ver", "V9", x + bw + 8, g_py + V9Pix(bfs) - V9Pix(InpFontSize) - 2, V9Muted(), InpFontSize, V9F_BRAND,
            ANCHOR_LEFT_UPPER, false);
   V9UIPill("P_mode", "KUZATUV · SAVDO YO'Q", x + w, g_py + 4, V9Amber());
   g_py += V9Pix(bfs) + 8;
   string sub = _Symbol + " · ko'zlar + o'lchov · spread " + V9Px(V9Spread()) + StringFormat(" · tick %.2f ms · bar %.1f ms", ms, msBar);
   V9UIText("P_sub", V9Fit(sub, V9F_TEXT, InpFontSize - 1, w), x, g_py, V9Muted(), InpFontSize - 1, V9F_TEXT, ANCHOR_LEFT_UPPER, false);
   g_py += V9Row(InpFontSize - 1);

   if(!g_ready[V9_M5] || !g_ready[V9_H1])
   {
      V9Section("P_s0", "TAYYORLANMOQDA", x, w);
      V9Line("P_wait", "Tarix yuklanmoqda (M5 / H1 barlari yetarli emas)...", V9Muted(), "", V9Muted(), x, w, false);
   }
   else
   {
      V9UIDel("P_s0_h");
      V9UIDel("P_s0_ln");
      V9LineDel("P_wait");

      // --- OYOQ M5
      V9Section("P_s1", "OYOQ · M5", x, w);
      if(g_lv[V9_M5].ok)
      {
         int d = g_lv[V9_M5].dir;
         string head = V9Arrow(d) + "  " + V9MapRelName(g_lv[V9_M5].mapRel);
         V9UIText("P_l1_l", V9Fit(head, V9F_BOLD, InpFontSize + 1, w - 110), x, g_py, V9DirClr(d), InpFontSize + 1, V9F_BOLD,
                  ANCHOR_LEFT_UPPER, false);
         V9UIPill("P_stg", V9StageName(g_lv[V9_M5].stage), x + w, g_py + 2, V9StageClr(g_lv[V9_M5].stage));
         g_py += V9Row(InpFontSize + 1) + 2;
         if(g_lv[V9_M5].progress >= 0.0)
            V9BarLine("P_b1", "yurgan", g_lv[V9_M5].progress, V9DirClr(d), V9Pct(g_lv[V9_M5].progress) +
                      StringFormat(" · %d turtki", g_lv[V9_M5].waves), V9Ink(), x, w, V9_STAGE_NEW, V9_STAGE_LATE, 0.0);
         else
            V9BarLine("P_b1", "yurgan", g_lv[V9_M5].lenAtr / (V9_LEN_LATE_ATR15 * 1.2), V9DirClr(d),
                      StringFormat("%.1f ATR · %d turtki", g_lv[V9_M5].lenAtr, g_lv[V9_M5].waves), V9Ink(), x, w,
                      V9_LEN_NEW_ATR15 / (V9_LEN_LATE_ATR15 * 1.2), 1.0 / 1.2, 0.0);
         color zc = (g_lv[V9_M5].zone == PBZ_OLTIN) ? V9Gold() : ((g_lv[V9_M5].zone >= PBZ_OLDI) ? V9Red() : V9Muted());
         V9BarLine("P_b2", "qaytish", g_lv[V9_M5].pullback, zc, V9Pct(MathMax(0.0, g_lv[V9_M5].pullback)) + " · " +
                   V9ZoneName(g_lv[V9_M5].zone), zc, x, w, V9_PB_GOLD_LO, V9_PB_GOLD_HI, V9_PB_DEEP_HI);
         V9Line("P_him", "HIMOYA  " + V9Px(g_lv[V9_M5].himoya), V9Red(), V9Dist(bid - g_lv[V9_M5].himoya), V9Ink(), x, w, false);
         if(g_lv[V9_M5].targetIdx >= 0)
            V9Line("P_tgt", "MAQSAD  " + V9PoolName(g_lv[V9_M5].targetIdx) + "  " + V9Px(g_lv[V9_M5].target), V9Blue(),
                   V9Dist(g_lv[V9_M5].target - bid), V9Ink(), x, w, false);
         else
            V9Line("P_tgt", "MAQSAD  topilmadi (oyoq ATR bilan o'lchanmoqda)", V9Muted(), "", V9Muted(), x, w, false);
         MqlDateTime bt;
         TimeToStruct(g_lv[V9_M5].bornT, bt);
         string q = (g_lv[V9_M5].birthQ == Q_STRONG) ? "kuchli" : ((g_lv[V9_M5].birthQ == Q_WEAK) ? "kuchsiz" : "oddiy");
         string born = StringFormat("tug'ildi %02d:%02d · ", bt.hour, bt.min) + ((g_lv[V9_M5].birthType == EV_MSS) ? "MSS " : "BOS ") + q +
                       (g_lv[V9_M5].confirmed ? " · tasdiqlandi" : " · tasdiq kutilmoqda");
         if(g_lv[V9_M5].revStage > 0)
            born = born + StringFormat(" · burilish %d/6", g_lv[V9_M5].revStage);
         if(g_lv[V9_M5].counter > 0)
            born = born + StringFormat(" · teskari belgi %d/3", g_lv[V9_M5].counter);
         V9Line("P_born", born, V9Muted(), "", V9Muted(), x, w, false);
         if(g_lv[V9_M5].stage == STG_TUGADI)
            V9Line("P_tug", "olindi: " + g_lv[V9_M5].tugadiWhat, V9Amber(), "", V9Muted(), x, w, false);
         else
            V9LineDel("P_tug");
         V9LineDel("P_noleg");
      }
      else
      {
         V9Line("P_noleg", "oyoq yo'q - struktura hali aniqlanmadi", V9Muted(), "", V9Muted(), x, w, false);
         V9UIDel("P_l1_l");
         V9UIPillDel("P_stg");
         V9BarLineDel("P_b1");
         V9BarLineDel("P_b2");
         V9LineDel("P_him");
         V9LineDel("P_tgt");
         V9LineDel("P_born");
         V9LineDel("P_tug");
      }

      // --- KATTA RASM
      V9Section("P_s2", "KATTA RASM · H1 / H4", x, w);
      int s1 = g_mapState[V9_H1], s4 = g_mapState[V9_H4];
      V9UIText("P_h1", "H1  " + V9Arrow(V9Sign(s1)) + " " + V9MapStateName(s1), x, g_py, V9DirClr(V9Sign(s1)), InpFontSize,
               V9F_BOLD, ANCHOR_LEFT_UPPER, false);
      V9UIText("P_h4", "H4  " + V9Arrow(V9Sign(s4)) + " " + V9MapStateName(s4), x + w, g_py, V9DirClr(V9Sign(s4)), InpFontSize,
               V9F_BOLD, ANCHOR_RIGHT_UPPER, false);
      g_py += V9Row(InpFontSize);
      if(g_lv[V9_H1].ok)
         V9Line("P_h1d", "H1 HIMOYA " + V9Px(g_lv[V9_H1].himoya) + " · " + V9StageName(g_lv[V9_H1].stage),
                V9Muted(), V9Dist(bid - g_lv[V9_H1].himoya), V9Ink(), x, w, false);
      else
         V9LineDel("P_h1d");
      if(g_drOk)
         V9BarLine("P_b3", "range", g_drPos, V9Blend(V9Muted(), V9Gold(), 0.5), V9DrText(), V9Ink(), x, w, 0.5, 0.0, 0.0);
      else
         V9BarLineDel("P_b3");
      if(g_bigLate)
         V9Line("P_late", "DIQQAT: katta oyoq (H1) kech - shu tomonga yangi da'vo xavfli", V9Amber(), "", V9Muted(), x, w, false);
      else
         V9LineDel("P_late");

      // --- LIKVIDLIK va DEVOR
      V9Section("P_s3", "LIKVIDLIK · DEVOR", x, w);
      int pu = V9PoolNearestSide(1), pd = V9PoolNearestSide(-1);
      if(pu >= 0)
         V9Line("P_pu", "▲ " + V9PoolName(pu) + "  " + V9Px(g_pool[pu].price) + StringFormat(" · sinf %d", g_pool[pu].cls),
                V9Ink(), V9Dist(g_pool[pu].price - bid), V9Ink(), x, w, false);
      else
         V9Line("P_pu", "▲ yuqorida hovuz yo'q", V9Muted(), "", V9Muted(), x, w, false);
      if(pd >= 0)
         V9Line("P_pd", "▼ " + V9PoolName(pd) + "  " + V9Px(g_pool[pd].price) + StringFormat(" · sinf %d", g_pool[pd].cls),
                V9Ink(), V9Dist(bid - g_pool[pd].price), V9Ink(), x, w, false);
      else
         V9Line("P_pd", "▼ pastda hovuz yo'q", V9Muted(), "", V9Muted(), x, w, false);
      int zu = V9ZoneNearest(1), zd = V9ZoneNearest(-1);
      V9Line("P_zu", "devor ▲ " + ((zu >= 0) ? V9TFName(g_zone[zu].tfi) + " supply " + V9Px(g_zone[zu].lo) + "-" + V9Px(g_zone[zu].hi) : "yo'q"),
             V9Red(), (zu >= 0) ? ((bid >= g_zone[zu].lo && bid <= g_zone[zu].hi) ? "ICHIDA" : V9Dist(g_zone[zu].lo - bid)) : "",
             V9Ink(), x, w, false);
      V9Line("P_zd", "devor ▼ " + ((zd >= 0) ? V9TFName(g_zone[zd].tfi) + " demand " + V9Px(g_zone[zd].lo) + "-" + V9Px(g_zone[zd].hi) : "yo'q"),
             V9Green(), (zd >= 0) ? ((bid >= g_zone[zd].lo && bid <= g_zone[zd].hi) ? "ICHIDA" : V9Dist(bid - g_zone[zd].hi)) : "",
             V9Ink(), x, w, false);

      // --- QADAM
      V9Section("P_s4", "QADAM · M1", x, w);
      V9Line("P_qd", V9Arrow(g_qd.dir) + "  " + g_qd.why, V9DirClr(g_qd.dir),
             (g_qd.pressure != 0) ? "bosim " + V9Arrow(g_qd.pressure) : "bosim —", V9DirClr(g_qd.pressure), x, w, false);

      // --- O'LCHOV
      V9Section("P_s5", "O'LCHOV · XAYOLIY SAVDOLAR", x, w);
      for(int k = 1; k >= 0; k--)
      {
         int cell = g_olCellNow[k];
         string sid = (k == 1) ? "P_ob" : "P_os";
         string nm = (k == 1) ? "BUY " : "SELL";
         int v = V9OlVerdict(0, cell);
         V9UIText(sid + "_n", nm, x, g_py, V9DirClr(k == 1 ? 1 : -1), InpFontSize, V9F_BOLD, ANCHOR_LEFT_UPPER, false);
         string st = (cell >= 0) ? V9OlStatText(0, cell) : "oyoq yo'q";
         V9UIText(sid + "_t", st, x + 46, g_py, V9Ink(), InpFontSize, V9F_MONO, ANCHOR_LEFT_UPPER, false);
         V9UIPill(sid + "_p", V9OlVerdictName(v), x + w, g_py + 2, V9VerdictClr(v));
         g_py += V9Row(InpFontSize) + 3;
      }
      int vb1 = V9OlVerdict(1, g_olCellNow[1]), vs1 = V9OlVerdict(1, g_olCellNow[0]);
      V9Line("P_om", "o'rta TP (ATR M15):  BUY " + V9OlVerdictName(vb1) + "  ·  SELL " + V9OlVerdictName(vs1), V9Muted(), "", V9Muted(), x, w, false);
      V9Line("P_ot", "yuqorida: kichik TP (cashback). Natijalar: " + IntegerToString(g_olTotal) + "  (tester " + IntegerToString(g_oltTotal) + ")",
             V9Muted(), "", V9Muted(), x, w, false);

      // --- Oxirgi hodisa
      V9Section("P_s6", "OXIRGI HODISA", x, w);
      V9Line("P_ev", V9LastEventText(), V9Ink(), "", V9Muted(), x, w, false);
   }

   g_py += 6;
   V9UIRect("P_card", X, InpPanelY, W, g_py - InpPanelY, V9Card(), V9Border(), false);
}

void V9DrawAll(const bool full, const double ms, const double msBar)
{
   g_lblN = 0;
   if(InpShowM5Leg) V9ChartLeg(V9_M5, "M5_", 2);
   else             ObjectsDeleteAll(0, V9ObjName("M5_"));
   if(InpShowH1Leg) V9ChartLeg(V9_H1, "H1_", 3);
   else             ObjectsDeleteAll(0, V9ObjName("H1_"));
   V9PanelDraw(ms, msBar);
   if(full)
      V9DrawWatermark();
   ChartRedraw(0);
}

void V9PanelClear()
{
   ObjectsDeleteAll(0, V9_OBJ);
   ObjectsDeleteAll(0, V9_UI);
}
