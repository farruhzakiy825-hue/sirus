//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 25_Visual_Design                                |
//| Watermark and the Sirus panel (card dashboard)                   |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// VISUAL DESIGN (engine plan, phase 10)
//---------------------------------------------------------------------
// WATERMARK: a large "SIRUS" in a heavy modern face, a letter-spaced "B Y   Z A K I Y" under a
// thin gold rule, centred on the chart and drawn BEHIND the candles. Its colour is blended from
// the chart background, so it stays quiet on dark and on light charts alike.
//
// SIRUS PANEL: one card instead of forty lines of text - header with a live status pill, then
// ACCOUNT, MARKET BRAIN (bias pill, confidence bar, narrative, location, target / invalidation),
// ENTRY (decision pill, quality bar, reason), BASKET (orders, average, points, DD, thesis, next
// rung) and the latest EVENTS. Text in a UI face, numbers in a monospace face, one colour system
// that follows the chart's own background. The old detailed dashboard is still available
// (EnableNewDashboard = false).
//=====================================================================

input group "48 — VISUAL DESIGN: WATERMARK + DASHBOARD"
input bool   EnableNewWatermark       = true;               // Yangi chiroyli watermark (eski oddiy yozuv o'rniga)
input string WatermarkTitle           = "SIRUS";
input string WatermarkSubtitle        = "BY ZAKIY";
input string WatermarkFont            = "Segoe UI Black";   // Sarlavha shrifti (Windows standarti; masalan "Bahnschrift SemiBold" ham chiroyli)
input string WatermarkSubFont         = "Segoe UI Semibold";
input int    WatermarkTitleSize       = 66;                 // Sarlavha o'lchami (pt)
input int    WatermarkOpacity         = 14;                 // Ko'rinish kuchi: fon rangiga qancha aralashadi (%, 5-40)
input bool   EnableNewDashboard       = true;               // Yangi "karta" dashboard (false = eski batafsil matnli dashboard)
input int    PanelWidth               = 390;                // Panel kengligi (px)
input string PanelFont                = "Segoe UI";
input string PanelFontBold            = "Segoe UI Semibold";
input string PanelFontMono            = "Consolas";
input int    PanelFontSize            = 9;

#define MB_VIS_PREFIX   "SIRUS_UI_"

// --- colour system ---------------------------------------------------------------------------
color MBVisBlend(const color a, const color b, const double t)
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

color MBVisChartBg()
{
   return (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
}

bool MBVisDark()
{
   uint c = (uint)MBVisChartBg();
   double lum = 0.299 * (c & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * ((c >> 16) & 0xFF);
   return (lum < 128.0);
}

color MBVisInk()      { return MBVisDark() ? C'232,236,243' : C'24,29,38'; }
color MBVisMuted()    { return MBVisDark() ? C'138,148,166' : C'98,108,124'; }
color MBVisCard()     { return MBVisBlend(MBVisChartBg(), (MBVisDark() ? C'255,255,255' : C'0,0,0'), MBVisDark() ? 0.07 : 0.035); }
color MBVisBorder()   { return MBVisBlend(MBVisChartBg(), C'212,175,55', MBVisDark() ? 0.45 : 0.55); }
color MBVisTrack()    { return MBVisBlend(MBVisCard(), MBVisInk(), 0.12); }
color MBVisGold()     { return C'212,175,55'; }
color MBVisGreen()    { return MBVisDark() ? C'46,204,128' : C'22,150,88'; }
color MBVisRed()      { return MBVisDark() ? C'239,90,90' : C'200,48,48'; }
color MBVisAmber()    { return MBVisDark() ? C'245,176,65' : C'196,124,16'; }
color MBVisBlue()     { return MBVisDark() ? C'74,163,255' : C'30,110,210'; }

// --- primitives -------------------------------------------------------------------------------
void MBVisRect(const string id, const int x, const int y, const int w, const int h,
               const color fill, const color border, const bool back)
{
   string name = MB_VIS_PREFIX + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, w));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, h));
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void MBVisText(const string id, const string text, const int x, const int y, const color clr,
               const int size, const string font, const ENUM_ANCHOR_POINT anchor, const bool back)
{
   string name = MB_VIS_PREFIX + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, (StringLen(text) > 0 ? text : " "));
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void MBVisDeleteGroup(const string id_prefix)
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX + id_prefix);
}

string MBVisFit(const string text, const int max_chars)
{
   if(StringLen(text) <= max_chars)
      return text;
   return StringSubstr(text, 0, MathMax(1, max_chars - 1)) + "…";
}

string MBVisSpaced(const string text)
{
   string out = "";
   int n = StringLen(text);
   for(int i = 0; i < n; i++)
   {
      string ch = StringSubstr(text, i, 1);
      out += (ch == " ") ? "   " : ch;
      if(i < n - 1 && ch != " ")
         out += " ";
   }
   return out;
}

// --- watermark --------------------------------------------------------------------------------
void MBDrawWatermark()
{
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(w <= 0 || h <= 0)
      return;

   color bg = MBVisChartBg();
   color ink = MBVisDark() ? C'255,255,255' : C'0,0,0';
   double t = MathMax(3, MathMin(60, WatermarkOpacity)) / 100.0;
   int size = MathMax(16, WatermarkTitleSize);
   int px = (int)(size * 1.33);   // point size to pixels (96 dpi)
   int cx = w / 2;
   int cy = h / 2;

   MBVisText("WM_TITLE", WatermarkTitle, cx, cy - px / 4, MBVisBlend(bg, ink, t), size, WatermarkFont, ANCHOR_CENTER, true);

   int line_w = (int)(StringLen(WatermarkTitle) * px * 0.62);
   int line_y = cy + (int)(px * 0.32);
   MBVisRect("WM_RULE", cx - line_w / 2, line_y, line_w, 2, MBVisBlend(bg, MBVisGold(), MathMin(0.75, t * 3.2)),
             MBVisBlend(bg, MBVisGold(), MathMin(0.75, t * 3.2)), true);

   int sub_size = MathMax(9, size / 5);
   MBVisText("WM_SUB", MBVisSpaced(WatermarkSubtitle), cx, line_y + (int)(sub_size * 1.6), MBVisBlend(bg, ink, t * 1.1),
             sub_size, WatermarkSubFont, ANCHOR_CENTER, true);
}

void MBDeleteWatermark()
{
   MBVisDeleteGroup("WM_");
}

// --- panel ------------------------------------------------------------------------------------
int G_MB_PANEL_Y = 0;   // drawing cursor

void MBPanelPill(const string id, const string text, const int x, const int y, const int h, const color tone)
{
   int w = StringLen(text) * (PanelFontSize - 1) + 18;
   MBVisRect(id + "_BG", x, y, w, h, MBVisBlend(MBVisCard(), tone, 0.22), tone, false);
   MBVisText(id + "_TX", text, x + w / 2, y + h / 2, tone, PanelFontSize - 1, PanelFontBold, ANCHOR_CENTER, false);
}

void MBPanelBar(const string id, const int x, const int y, const int w, const double value, const color tone)
{
   double v = MathMax(0.0, MathMin(100.0, value));
   MBVisRect(id + "_TR", x, y, w, 6, MBVisTrack(), MBVisTrack(), false);
   MBVisRect(id + "_FL", x, y, MathMax(1, (int)(w * v / 100.0)), 6, tone, tone, false);
}

void MBPanelSection(const string id, const string title, const int x0, const int w, const int lh)
{
   G_MB_PANEL_Y += lh / 3;
   MBVisRect(id + "_RULE", x0 + 12, G_MB_PANEL_Y + lh / 2, w - 24, 1, MBVisBlend(MBVisCard(), MBVisInk(), 0.10),
             MBVisBlend(MBVisCard(), MBVisInk(), 0.10), false);
   MBVisRect(id + "_MASK", x0 + 12, G_MB_PANEL_Y, StringLen(title) * (PanelFontSize - 1) + 12, lh, MBVisCard(), MBVisCard(), false);
   MBVisText(id + "_T", title, x0 + 12, G_MB_PANEL_Y + 2, MBVisGold(), PanelFontSize - 1, PanelFontBold, ANCHOR_LEFT_UPPER, false);
   G_MB_PANEL_Y += lh;
}

void MBPanelLine(const string id, const string text, const color clr, const bool mono, const int x0, const int w, const int lh)
{
   int max_chars = (int)((w - 24) / (PanelFontSize * (mono ? 0.80 : 0.72)));
   MBVisText(id, MBVisFit(text, max_chars), x0 + 12, G_MB_PANEL_Y, clr, PanelFontSize, (mono ? PanelFontMono : PanelFont), ANCHOR_LEFT_UPPER, false);
   G_MB_PANEL_Y += lh;
}

color MBBiasTone(const int b)
{
   if(b >= 2) return MBVisGreen();
   if(b == 1) return MBVisBlue();
   if(b <= -2) return MBVisRed();
   if(b == -1) return MBVisAmber();
   return MBVisMuted();
}

void MBDrawPanel()
{
   int x0 = MathMax(0, DashboardX);
   int y0 = MathMax(0, DashboardY);
   int w = MathMax(300, PanelWidth);
   int lh = (int)MathRound(PanelFontSize * 1.95);
   color ink = MBVisInk(), muted = MBVisMuted();

   // Card first, so everything else is drawn above it.
   MBVisRect("P_CARD", x0, y0, w, 10, MBVisCard(), MBVisBorder(), false);
   MBVisRect("P_ACCENT", x0, y0, w, 3, MBVisGold(), MBVisGold(), false);
   G_MB_PANEL_Y = y0 + 12;

   // --- header ---
   MBVisText("P_BRAND", "SIRUS", x0 + 12, G_MB_PANEL_Y, MBVisGold(), PanelFontSize + 5, WatermarkFont, ANCHOR_LEFT_UPPER, false);
   MBVisText("P_BRAND2", "BRAIN  " + G_VERSION, x0 + 12 + (PanelFontSize + 5) * 5, G_MB_PANEL_Y + 6, muted, PanelFontSize - 1, PanelFontBold, ANCHOR_LEFT_UPPER, false);

   string status = "SCANNING";
   color status_tone = muted;
   if(G_BASKET_ORDERS > 0)                              { status = "IN TRADE"; status_tone = MBVisBlue(); }
   else if(StringFind(G_ENTRY_REASON, "veto") >= 0)     { status = "VETO";     status_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)    { status = "WAIT";     status_tone = MBVisAmber(); }
   else if(G_ENTRY_READY)                               { status = "READY";    status_tone = MBVisGreen(); }
   if(G_RISK_HARD_BLOCK)                                { status = "RISK STOP"; status_tone = MBVisRed(); }
   int pill_w = StringLen(status) * (PanelFontSize - 1) + 18;
   MBPanelPill("P_STATUS", status, x0 + w - 12 - pill_w, G_MB_PANEL_Y + 2, lh - 2, status_tone);
   G_MB_PANEL_Y += lh + 6;

   // --- account ---
   MBPanelSection("S_ACC", "ACCOUNT", x0, w, lh);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double today = (G_RISK_DAY_START_EQUITY > 0.0) ? eq - G_RISK_DAY_START_EQUITY : 0.0;
   MBPanelLine("A1", StringFormat("Balance %11.2f   Equity %11.2f", bal, eq), ink, true, x0, w, lh);
   MBPanelLine("A2", StringFormat("Today   %+11.2f   DD %5.2f%% / worst %5.2f%%", today, G_RISK_EQUITY_DD_PCT, G_ALL_TIME_MAX_DD_PCT),
               (today < 0.0 ? MBVisRed() : (today > 0.0 ? MBVisGreen() : ink)), true, x0, w, lh);

   // --- market brain ---
   MBPanelSection("S_BRAIN", "MARKET BRAIN", x0, w, lh);
   if(EnableMarketBrain && EnableMarketBrainEngines)
   {
      color tone = MBBiasTone(G_MB_BIAS);
      string bias = MBBiasName(G_MB_BIAS);
      MBPanelPill("B_BIAS", bias, x0 + 12, G_MB_PANEL_Y, lh - 2, tone);
      int bar_x = x0 + 12 + StringLen(bias) * (PanelFontSize - 1) + 30;
      int bar_w = MathMax(40, w - (bar_x - x0) - 60);
      MBPanelBar("B_CONF", bar_x, G_MB_PANEL_Y + lh / 2 - 3, bar_w, G_MB_BIAS_CONF, tone);
      MBVisText("B_CONF_TX", StringFormat("%d%%", G_MB_BIAS_CONF), x0 + w - 12, G_MB_PANEL_Y + 1, muted, PanelFontSize, PanelFontMono, ANCHOR_RIGHT_UPPER, false);
      G_MB_PANEL_Y += lh + 2;
      MBPanelLine("B_WHY", G_MB_BIAS_WHY, ink, false, x0, w, lh);
      MBPanelLine("B_TF", StringFormat("M5 %s · M15 %s · H1 %s · H4 %s", MBBiasName(G_MB_TF_STATE[1]), MBBiasName(G_MB_TF_STATE[2]),
                                       MBBiasName(G_MB_TF_STATE[3]), MBBiasName(G_MB_TF_STATE[4])), muted, false, x0, w, lh);
      string loc = "No H1 range";
      if(G_MB_DR_HI > G_MB_DR_LO)
         loc = StringFormat("%s %.2f  ·  range %s – %s",
                            (G_MB_DR_POS >= 0.55 ? "PREMIUM" : (G_MB_DR_POS <= 0.45 ? "DISCOUNT" : "EQUILIBRIUM")), G_MB_DR_POS,
                            DoubleToString(G_MB_DR_LO, _Digits), DoubleToString(G_MB_DR_HI, _Digits));
      MBPanelLine("B_LOC", loc, ink, false, x0, w, lh);
      MBPanelLine("B_TGT", StringFormat("Target %s %s  ·  Invalid %s  ·  %s",
                                        (G_MB_TH_TARGET > 0.0 ? DoubleToString(G_MB_TH_TARGET, _Digits) : "-"), G_MB_DOL_WHAT,
                                        (G_MB_TH_INVALID > 0.0 ? DoubleToString(G_MB_TH_INVALID, _Digits) : "-"),
                                        MBThesisStateName(G_MB_TH_STATE)), muted, false, x0, w, lh);
   }
   else
      MBPanelLine("B_OFF", "Market Brain is off", muted, false, x0, w, lh);

   // --- entry ---
   MBPanelSection("S_ENTRY", "ENTRY", x0, w, lh);
   string dec = "IDLE";
   color dec_tone = muted;
   if(StringFind(G_ENTRY_REASON, "veto") >= 0)           { dec = "VETO";    dec_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)     { dec = "WAIT";    dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY && G_MB_ENTRY_DECISION == MB_ED_CAUTION) { dec = "CAUTION"; dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY)                                { dec = "EXECUTE"; dec_tone = MBVisGreen(); }
   MBPanelPill("E_DEC", dec, x0 + 12, G_MB_PANEL_Y, lh - 2, dec_tone);
   int qx = x0 + 12 + StringLen(dec) * (PanelFontSize - 1) + 30;
   int qw = MathMax(40, w - (qx - x0) - 60);
   MBPanelBar("E_Q", qx, G_MB_PANEL_Y + lh / 2 - 3, qw, G_MB_ENTRY_QUALITY, dec_tone);
   MBVisText("E_Q_TX", StringFormat("q%d", G_MB_ENTRY_QUALITY), x0 + w - 12, G_MB_PANEL_Y + 1, muted, PanelFontSize, PanelFontMono, ANCHOR_RIGHT_UPPER, false);
   G_MB_PANEL_Y += lh + 2;
   MBPanelLine("E_WHY", (StringLen(G_ENTRY_REASON) > 0 ? G_ENTRY_REASON : "-"), ink, false, x0, w, lh);

   // --- basket ---
   MBPanelSection("S_BASKET", "BASKET", x0, w, lh);
   if(G_BASKET_ORDERS > 0)
   {
      bool buy = (G_BASKET_DIRECTION == POSITION_TYPE_BUY);
      MBPanelLine("K1", StringFormat("%s x%d  avg %s  %+6.0f pts  DD %5.2f%%", (buy ? "BUY " : "SELL"), G_BASKET_ORDERS,
                                     DoubleToString(G_BASKET_AVG_PRICE, _Digits), G_BASKET_POINTS, G_BASKET_DD_PERCENT),
                  (G_BASKET_POINTS >= 0.0 ? MBVisGreen() : MBVisRed()), true, x0, w, lh);
      MBPanelLine("K2", StringFormat("%s  ·  next rung %.0f pts, lot %.2f", MBPositionText(), G_NEXT_GRID_DISTANCE, G_NEXT_GRID_LOT),
                  (G_MB_PB_DEAD ? MBVisAmber() : muted), false, x0, w, lh);
   }
   else
   {
      MBPanelLine("K1", "Flat - waiting for the next setup", muted, false, x0, w, lh);
      MBPanelLine("K2", " ", muted, false, x0, w, lh);
   }

   // --- events ---
   MBPanelSection("S_EV", "EVENTS", x0, w, lh);
   string ev = MBEventText(3);
   string parts[];
   int np = StringSplit(ev, '|', parts);
   for(int i = 0; i < 3; i++)
   {
      string t = (i < np) ? parts[i] : " ";
      StringTrimLeft(t);
      StringTrimRight(t);
      color c = muted;
      if(StringFind(t, " bull ") >= 0) c = MBVisGreen();
      if(StringFind(t, " bear ") >= 0) c = MBVisRed();
      MBPanelLine("V" + IntegerToString(i), t, c, false, x0, w, lh);
   }

   // --- footer ---
   G_MB_PANEL_Y += 2;
   string news = (EnableEconomicCalendarGuard && G_CAL_ACTIVE) ? StringFormat("NEWS %s (%d min)", G_CAL_EVENT_NAME, G_CAL_MINUTES_FROM_EVENT) : "News clear";
   MBPanelLine("F1", StringFormat("%s  ·  spread %d  ·  %s", news, G_LAST_SPREAD_POINTS, TimeToString(TimeCurrent(), TIME_MINUTES)),
               (G_CAL_ACTIVE ? MBVisAmber() : muted), false, x0, w, lh);

   // Size the card to what was drawn.
   ObjectSetInteger(0, MB_VIS_PREFIX + "P_CARD", OBJPROP_YSIZE, G_MB_PANEL_Y - y0 + 8);
}

void MBDeletePanel()
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "P_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "S_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "A");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "B_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "E_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "K");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "V");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "F");
}

void MBDeleteAllVisuals()
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX);
}
