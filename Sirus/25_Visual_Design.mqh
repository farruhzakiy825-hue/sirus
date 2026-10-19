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

input group "DISPLAY ▸ Panel & watermark"
// EnableNewWatermark: Yangi chiroyli watermark (eski oddiy yozuv o'rniga)
input bool   EnableNewWatermark       = true;   // Enable new watermark
input string WatermarkTitle           = "SIRUS";   // Watermark title
input string WatermarkSubtitle        = "BY ZAKIY";   // Watermark subtitle
// WatermarkFont: Sarlavha shrifti (Windows 10/11 standarti "Bahnschrift"; yo'q bo'lsa Windows o'xshashini qo'yadi)
input string WatermarkFont            = "Bahnschrift SemiBold";   // Watermark font
input string WatermarkSubFont         = "Bahnschrift Light";   // Watermark sub font
// WatermarkTitleSize: Sarlavha o'lchami (pt). Panel yonidagi bo'sh joyga sig'masa o'zi kichrayadi
input int    WatermarkTitleSize       = 64;   // Watermark title size
// WatermarkOpacity: Ko'rinish kuchi: fon rangiga qancha aralashadi (%, 5-40)
input int    WatermarkOpacity         = 20;   // Watermark opacity
// EnableNewDashboard: Yangi "karta" dashboard (false = eski batafsil matnli dashboard)
input bool   EnableNewDashboard       = true;   // Enable new dashboard
// PanelWidth: Panel kengligi (px)
input int    PanelWidth               = 430;   // Panel width
input string PanelFont                = "Segoe UI";   // Panel font
input string PanelFontBold            = "Segoe UI Semibold";   // Panel font bold
input string PanelFontMono            = "Consolas";   // Panel font mono
input int    PanelFontSize            = 9;   // Panel font size
// PanelLayout: 0 = avtomatik bitta ustun (sig'sa to'liq, sig'masa ixcham), 1 = bitta ustun doim to'liq, 2 = bitta ustun doim ixcham, 3 = ikki ustun
input int    PanelLayout              = 0;   // Panel layout: 0 auto (one column), 1 full, 2 compact, 3 two columns
// PanelBrandFont: Panel sarlavhasi (SIRUS) va katta raqamlar shrifti
input string PanelBrandFont           = "Bahnschrift SemiBold";   // Panel brand / figures font
// PanelMaxWidthPct: Ikki ustunli panel grafik kengligining ko'pi bilan shuncha foizini egallaydi
input int    PanelMaxWidthPct         = 50;   // Two-column panel: at most this % of the chart width
// CashbackPerLot: CASHBACK bo'limi: 1 lot uchun qaytadigan $ (0 = taxminiy cashback ko'rsatilmaydi). Bo'lim faqat cashback rejimida chiqadi
input double CashbackPerLot           = 0.0;   // Cashback per lot

// Package 13 (input audit): CashbackPerLot (panel) and RebateUSDPerLot (20e cost line) were two inputs for one
// number. Either one now feeds both; RebateUSDPerLot wins when both are set (the audit warns about that).
double CashbackUSDPerLot()
{
   return (RebateUSDPerLot > 0.0) ? RebateUSDPerLot : CashbackPerLot;
}

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

// SPEED: ChartGetInteger waits for the chart's command queue, and the colour helpers asked it about
// two hundred times per redraw. The background is read once every few seconds instead.
color G_MB_BG_COLOR = clrBlack;
bool  G_MB_BG_DARK  = true;
uint  G_MB_BG_MS    = 0;
bool  G_MB_BG_READ  = false;

color MBVisChartBg()
{
   uint now = GetTickCount();
   if(!G_MB_BG_READ || (now - G_MB_BG_MS) > 3000)
   {
      G_MB_BG_READ = true;
      G_MB_BG_MS = now;
      G_MB_BG_COLOR = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
      uint c = (uint)G_MB_BG_COLOR;
      G_MB_BG_DARK = ((0.299 * (c & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * ((c >> 16) & 0xFF)) < 128.0);
   }
   return G_MB_BG_COLOR;
}

bool MBVisDark()
{
   MBVisChartBg();
   return G_MB_BG_DARK;
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
   {
      // SPEED: fixed properties only once, at creation.
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);   // package 23: every call - a watermark is always behind the candles
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, w));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, h));
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}

void MBVisText(const string id, const string text, const int x, const int y, const color clr,
               const int size, const string font, const ENUM_ANCHOR_POINT anchor, const bool back)
{
   string name = MB_VIS_PREFIX + id;
   if(ObjectFind(0, name) < 0)
   {
      // SPEED: fixed properties only once, at creation.
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_BACK, back);   // package 23: every call - a watermark is always behind the candles
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, (StringLen(text) > 0 ? text : " "));
}

void MBVisDeleteGroup(const string id_prefix)
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX + id_prefix);
}

// Package 19: the real pixel width of a text as the label draws it (points, so the Windows scale is included).
int MBVisTextW(const string text, const string font, const int size)
{
   uint tw = 0, th = 0;
   TextSetFont(font, -size * 10);
   if(!TextGetSize(text, tw, th))
      return (int)(StringLen(text) * size * 0.85);
   return (int)tw;
}

// The text cut (with "…") to fit max_px - measured, not guessed from a character count.
string MBVisFitPx(const string text, const string font, const int size, const int max_px)
{
   if(MBVisTextW(text, font, size) <= max_px)
      return text;
   int lo = 1, hi = StringLen(text);
   while(lo < hi)
   {
      int mid = (lo + hi + 1) / 2;
      if(MBVisTextW(StringSubstr(text, 0, mid) + "…", font, size) <= max_px) lo = mid;
      else hi = mid - 1;
   }
   return StringSubstr(text, 0, lo) + "…";
}

// The Windows display scale (1.0 at 96 dpi, 1.25 at 120) - fonts grow with it, pixel distances do not.
double MBVisScale()
{
   int dpi = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   return (dpi > 96) ? dpi / 96.0 : 1.0;
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
int G_MB_PANEL_FS = 9;           // package 22: the panel's font size of this draw (two columns: one point smaller)
int G_MB_PANEL_RIGHT_EDGE = 0;   // package 21: where the panel ends - the watermark sits in the free part of the chart

// Package 21: a premium watermark - the title letter-spaced in a modern face, gold-tinted, with a gold rule
// between two diamonds and the spaced subtitle. Centred in the part of the chart the panel leaves free, and
// shrunk if it would not fit there, so the SIRUS word is never hidden behind the panel.
void MBDrawWatermark()
{
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(w <= 0 || h <= 0)
      return;

   color bg = MBVisChartBg();
   color ink = MBVisDark() ? C'255,255,255' : C'0,0,0';
   color tint = MBVisBlend(ink, MBVisGold(), 0.55);
   double t = MathMax(3, MathMin(60, WatermarkOpacity)) / 100.0;
   string title = MBVisSpaced(WatermarkTitle);
   int left = (G_MB_PANEL_RIGHT_EDGE > 0 && G_MB_PANEL_RIGHT_EDGE < w - 200) ? G_MB_PANEL_RIGHT_EDGE : 0;
   int free_w = w - left;
   int size = MathMax(16, WatermarkTitleSize);
   int tw = MBVisTextW(title, WatermarkFont, size);
   if(tw > free_w - 60 && tw > 0)
      size = MathMax(36, (int)(size * (double)(free_w - 60) / tw));
   tw = MBVisTextW(title, WatermarkFont, size);
   int px = (int)(size * 1.33 * MBVisScale());
   int cx = left + free_w / 2;
   int cy = h / 2;   // owner: always the vertical centre of the chart

   MBVisText("WM_TITLE", title, cx, cy - px / 4, MBVisBlend(bg, tint, t), size, WatermarkFont, ANCHOR_CENTER, true);

   int line_w = (int)(tw * 0.72);
   int line_y = cy + (int)(px * 0.36);
   color rule = MBVisBlend(bg, MBVisGold(), MathMin(0.75, t * 3.2));
   MBVisRect("WM_RULE", cx - line_w / 2, line_y, line_w, 2, rule, rule, true);
   int dsz = MathMax(7, size / 9);
   MBVisText("WM_DL", "◆", cx - line_w / 2 - dsz, line_y + 1, rule, dsz, "Segoe UI Symbol", ANCHOR_CENTER, true);
   MBVisText("WM_DR", "◆", cx + line_w / 2 + dsz, line_y + 1, rule, dsz, "Segoe UI Symbol", ANCHOR_CENTER, true);

   int sub_size = MathMax(9, size / 5);
   MBVisText("WM_SUB", MBVisSpaced(WatermarkSubtitle), cx, line_y + (int)(sub_size * 1.9 * MBVisScale()), MBVisBlend(bg, tint, t * 1.2),
             sub_size, WatermarkSubFont, ANCHOR_CENTER, true);
}

void MBDeleteWatermark()
{
   MBVisDeleteGroup("WM_");
}

// --- panel ------------------------------------------------------------------------------------
// Package 19: the new panel is drawn (read by the old premium header in 15, which then stands aside).
bool MBNewPanelOn()
{
   return (EnableNewDashboard && ShowDashboard);
}

int G_MB_PANEL_Y = 0;   // drawing cursor
int  G_MB_PANEL_W = 430;         // package 19: card width of this draw (scaled)
bool G_MB_PANEL_COMPACT = false; // package 19: only the main lines
int  G_MB_PANEL_FULL_H = 0;      // height of the last full one-column draw (for the automatic layout)
bool G_MB_PANEL_TWO = false;     // package 21: two columns
int  G_MB_PANEL_COL = 0;         // package 22: the column being drawn (0 left / single, 1 right)
int  G_MB_PANEL_HID[2];          // package 22: lines a compact draw left out, per column (to know the full height)
int  G_MB_PANEL_TWO_H = 0;       // height of the last full two-column draw

// Package 19: the lines a compact panel leaves out (the detail - still in the journal and the CSVs).
// Package 24: when the compact panel leaves room, detail lines come back in this order (most useful first).
int G_MB_PANEL_EXTRA = 0;
string G_MB_PANEL_PRI = ",E_QUIET,B_ST,B_LK,B_ZI,B_LX,B_SES,E_EG,E_SHADOW,B_MC,B_HZ,B_SESL,B_CE,B_EVB,B_TF,B_LOCTH,B_NAR,B_SCF,A4,C2,C3,V1,V2,N2,K6,K7,";

int MBPanelPriority(const string id)
{
   int p = StringFind(G_MB_PANEL_PRI, "," + id + ",");
   if(p < 0)
      return 999;
   int n = 0;
   for(int i = 0; i < p; i++)
      if(StringGetCharacter(G_MB_PANEL_PRI, i) == ',') n++;
   return n;   // package 26: the comma count before the id is its 0-based index
}

bool MBPanelIsDetail(const string id)
{
   if(StringFind(",A4,C2,C3,B_EVB,B_LOCTH,B_TF,B_SCF,B_NAR,B_ST,B_LK,B_SESL,B_ZI,B_HZ,B_MC,B_CE,B_LX,B_SES,"
                 "E_QUIET,E_SHADOW,E_EG,V1,V2,N2,F2,K6,K7,", "," + id + ",") < 0)
      return false;
   return (MBPanelPriority(id) >= G_MB_PANEL_EXTRA);   // a compact panel with room shows the first few again
}

//---------------------------------------------------------------------
// Package 24: HOLAT NAZORATI - every problem that stops or spoils trading, in words, at the top of the panel
// (compact or not). Red = no trading now, amber = trading with a problem, green = nothing wrong.
//---------------------------------------------------------------------
#define MB_HL_MAX 8
int    G_HL_N = 0;
int    G_HL_SEV[MB_HL_MAX];
string G_HL_TXT[MB_HL_MAX];

void MBHealthAdd(const int sev, const string text)
{
   if(G_HL_N >= MB_HL_MAX)
      return;
   G_HL_SEV[G_HL_N] = sev;
   G_HL_TXT[G_HL_N] = text;
   G_HL_N++;
}

string MBAgoUz(const long sec)
{
   if(sec >= 86400) return StringFormat("%d kun oldin", (int)(sec / 86400));
   if(sec >= 3600)  return StringFormat("%d soat oldin", (int)(sec / 3600));
   return StringFormat("%d daq oldin", (int)MathMax(1, sec / 60));
}

string MBEnvReasonUz(const string r)
{
   if(StringFind(r, "tick stale") == 0 || r == "no tick received yet")
   {
      datetime lt = (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME);
      return (lt > 0) ? StringFormat("bozor yopiq yoki tik yo'q - so'nggi tik %s (%s)", TimeToString(lt, TIME_DATE | TIME_MINUTES),
                                     MBAgoUz((long)(TimeTradeServer() - lt)))
                      : "bozor yopiq yoki tik yo'q";
   }
   if(r == "terminal AutoTrading disabled")      return "MT5 da AutoTrading (Algo Trading) o'chiq";
   if(r == "MQL trading disabled for EA")        return "EA ga savdo ruxsati berilmagan (EA sozlamasi)";
   if(r == "account trading disabled" || r == "expert trading disabled on account") return "hisob EA savdosiga ruxsat bermaydi";
   if(r == "symbol trade mode not FULL")         return "simvolda hozir savdo yopiq (sessiya tashqarisi)";
   if(StringFind(r, "spread high") >= 0)          return "spread juda yuqori " + StringSubstr(r, StringFind(r, "high") + 5);
   if(StringFind(r, "history not ready") >= 0)    return "grafik tarixi yuklanmoqda (" + StringSubstr(r, 0, StringFind(r, " ")) + ")";
   if(StringFind(r, "symbol") == 0)               return "simvol muammosi: " + r;
   return "savdo muhiti tayyor emas: " + r;
}

string MBRiskReasonUz(const string r)
{
   if(StringFind(r, "EMERGENCY DD") == 0)         return "favqulodda DD " + StringSubstr(r, 13);
   if(StringFind(r, "Equity stop DD") == 0)       return "equity to'xtash DD " + StringSubstr(r, 15);
   if(StringFind(r, "Daily loss money") == 0)     return "kunlik zarar chegarasi " + StringSubstr(r, 17);
   if(StringFind(r, "Daily loss") == 0)           return "kunlik zarar chegarasi " + StringSubstr(r, 11);
   if(r == "ENV not ready")                       return MBEnvReasonUz(G_ENV_BLOCK_REASON);
   if(StringFind(r, "risk spread high") == 0)     return "spread juda yuqori " + StringSubstr(r, 17);
   if(StringFind(r, "post-loss cooldown until") == 0) return "zarardan keyingi tanaffus " + StringSubstr(r, 25) + " gacha";
   if(StringFind(r, "max daily entry attempts") == 0) return "kunlik kirish urinishlari tugadi " + StringSubstr(r, 25);
   if(StringFind(r, "max daily grid attempts") == 0)  return "kunlik grid urinishlari tugadi " + StringSubstr(r, 24);
   return r;
}

void MBHealthCollect()
{
   G_HL_N = 0;
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   // red - nothing can trade now
   if(!tester && TerminalInfoInteger(TERMINAL_CONNECTED) == 0)
      MBHealthAdd(2, "Broker bilan ulanish yo'q - internet / server ulanishini tekshiring");
   if(!tester && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
      MBHealthAdd(2, "MT5 da AutoTrading (Algo Trading) tugmasi o'chiq - savdo yo'q");
   else if(!tester && MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
      MBHealthAdd(2, "EA sozlamasida 'Algo Trading ga ruxsat' belgilanmagan");
   if(G_DUP_ACTIVE)
      MBHealthAdd(2, "Boshqa grafikda shu EA (shu Magic) ishlayapti - bu grafik savdo ochmaydi");
   // Package 26: no tick for minutes = the market is paused / closed; the risk state is only re-read on a tick,
   // so a stale reason (e.g. Friday's last wide spread) is not shown as the cause.
   int tick_age = TickAgeSeconds();
   bool no_ticks = (!tester && tick_age > 180);
   datetime last_tick = (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME);
   string paused = (last_tick > 0) ? StringFormat("bozor tanaffusda yoki yopiq - so'nggi tik %s (%s)", TimeToString(last_tick, TIME_DATE | TIME_MINUTES),
                                                 MBAgoUz((long)(TimeTradeServer() - last_tick)))
                                   : "bozor tanaffusda yoki yopiq";
   if(G_RISK_HARD_BLOCK)
      MBHealthAdd(2, "HIMOYA: " + (no_ticks ? paused : MBRiskReasonUz(G_RISK_REASON)));
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(G_BASKET_ORDERS > 0 && ml > 0.0 && ml < 150.0)
      MBHealthAdd(2, StringFormat("Margin darajasi %.0f%% - stop-out xavfi", ml));
   string fl = "";
   int nf = MBSendFailsRecent(1800, fl);
   if(nf > 0)
      MBHealthAdd(nf >= 3 ? 2 : 1, StringFormat("Oxirgi 30 daqiqada %d order rad etildi: %s", nf, fl));
   // amber - trading, but something is off
   if(G_BASKET_ORDERS > 0 && ml > 0.0 && ml >= 150.0 && ml < 300.0)
      MBHealthAdd(1, StringFormat("Margin darajasi %.0f%% - past", ml));
   if(G_BASKET_ORDERS > 0 && BasketSLPercent > 0.0 && G_BASKET_DD_PERCENT >= 0.8 * BasketSLPercent)
      MBHealthAdd(1, StringFormat("Savat DD %.1f%% - basket SL %.0f%% ga yaqin", G_BASKET_DD_PERCENT, BasketSLPercent));
   if(G_SAF_ENTRY_BLOCK && !G_RISK_HARD_BLOCK)
      MBHealthAdd(1, "Xavfsizlik qatlami kutmoqda: " + G_SAF_REASON);
   if(G_RB_FROZEN && G_RB_FROZEN_VAL != EnableRebateMode)
      MBHealthAdd(1, StringFormat("Rejim almashtirildi: ochiq savat %s rejimida yopiladi, keyingisi %s", (G_RB_FROZEN_VAL ? "cashback" : "oddiy"),
                                  (EnableRebateMode ? "cashback" : "oddiy")));
   if(G_CAL_BLIND)
      MBHealthAdd(1, "Kalendar o'qilmayapti - zaxira jadval yoqilgan (08:30 / 10:00 NY)");
   else if(G_CAL_ACTIVE && EconomicCalendarHardBlockFirst)
      MBHealthAdd(1, StringFormat("Yangilik oynasi: %s - yangi kirish yo'q", G_CAL_EVENT_NAME));
   if(!G_RISK_HARD_BLOCK && no_ticks)
      MBHealthAdd(1, "Tik kelmayapti: " + paused);
   string ia = "";
   int nia = MBInputAuditCount(ia);
   if(nia > 0)
      MBHealthAdd(1, "Sozlama: " + ia + (nia > 1 ? StringFormat(" (+%d)", nia - 1) : ""));
   if(MBProfSlow())
      MBHealthAdd(1, "Tezlik sekin: " + MBProfShortText());
}

// Draws the block at the cursor: worst first (reds were added first), at most 4 lines.
void MBPanelHealth(const int x, const int w, const int lh)
{
   double sc = MBVisScale();
   MBHealthCollect();
   int worst = 0;
   for(int i = 0; i < G_HL_N; i++) worst = MathMax(worst, G_HL_SEV[i]);
   color tone = (worst >= 2) ? MBVisRed() : ((worst == 1) ? MBVisAmber() : MBVisGreen());
   int rows = (G_HL_N > 0) ? MathMin(G_HL_N, 4) : 1;
   int bx = x + 12, bw = w - 24, by = G_MB_PANEL_Y + (int)(2 * sc);
   int bh = (int)(lh * 1.05) + rows * lh;
   MBVisRect("P_HB", bx, by, bw, bh, MBVisBlend(MBVisCard(), tone, 0.10), MBVisBlend(MBVisCard(), tone, 0.55), false);
   MBVisRect("P_HA", bx, by, (int)MathMax(2, 3 * sc), bh, tone, tone, false);
   string title = "HOLAT NAZORATI" + (G_HL_N > 4 ? StringFormat("  ·  yana %d ta", G_HL_N - 4) : "");
   MBVisText("P_HT", title, bx + (int)(10 * sc), by + (int)(4 * sc), tone, G_MB_PANEL_FS - 1, PanelFontBold, ANCHOR_LEFT_UPPER, false);
   int ry = by + (int)(lh * 1.05);
   for(int r = 0; r < 4; r++)
   {
      string ico_id = "P_HI" + IntegerToString(r), txt_id = "P_HR" + IntegerToString(r);
      if(r >= rows)
      {
         ObjectDelete(0, MB_VIS_PREFIX + ico_id);
         ObjectDelete(0, MB_VIS_PREFIX + txt_id);
         continue;
      }
      int sev = (G_HL_N > 0) ? G_HL_SEV[r] : 0;
      color c = (sev >= 2) ? MBVisRed() : ((sev == 1) ? MBVisAmber() : MBVisGreen());
      string ico = (sev >= 2) ? "✖" : ((sev == 1) ? "⚠" : "✔");
      string txt = (G_HL_N > 0) ? G_HL_TXT[r]
                   : StringFormat("Hammasi ishlayapti: ulanish, AutoTrading, spread %d/%d, risk, kalendar", G_LAST_SPREAD_POINTS, MaxSpreadAllowed());
      int tx = bx + (int)(30 * sc);
      MBVisText(ico_id, ico, bx + (int)(12 * sc), ry, c, G_MB_PANEL_FS, "Segoe UI Symbol", ANCHOR_LEFT_UPPER, false);
      MBVisText(txt_id, MBVisFitPx(txt, PanelFont, G_MB_PANEL_FS, bw - (tx - bx) - (int)(8 * sc)), tx, ry, c, G_MB_PANEL_FS, PanelFont, ANCHOR_LEFT_UPPER, false);
      ry += lh;
   }
   G_MB_PANEL_Y = by + bh + (int)(4 * sc);
}

int MBPanelPillW(const string text)
{
   return MBVisTextW(text, PanelFontBold, G_MB_PANEL_FS - 1) + (int)(18 * MBVisScale());
}

void MBPanelPill(const string id, const string text, const int x, const int y, const int h, const color tone)
{
   int w = MBPanelPillW(text);
   MBVisRect(id + "_BG", x, y, w, h, MBVisBlend(MBVisCard(), tone, 0.22), tone, false);
   MBVisText(id + "_TX", text, x + w / 2, y + h / 2, tone, G_MB_PANEL_FS - 1, PanelFontBold, ANCHOR_CENTER, false);
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
   // Package 21: a gold diamond, the title, then a gold-tinted rule to the column's edge.
   string t = "◆  " + title;
   color rule = MBVisBlend(MBVisCard(), MBVisGold(), 0.28);
   MBVisRect(id + "_RULE", x0 + 12, G_MB_PANEL_Y + lh / 2, w - 24, 1, rule, rule, false);
   MBVisRect(id + "_MASK", x0 + 12, G_MB_PANEL_Y, MBVisTextW(t, PanelFontBold, G_MB_PANEL_FS - 1) + 10, lh, MBVisCard(), MBVisCard(), false);
   MBVisText(id + "_T", t, x0 + 12, G_MB_PANEL_Y + 2, MBVisGold(), G_MB_PANEL_FS - 1, PanelFontBold, ANCHOR_LEFT_UPPER, false);
   G_MB_PANEL_Y += lh;
}

// Package 21: a figure tile - small caps label, a big value, a muted line under it.
void MBPanelTile(const string id, const int x, const int y, const int w, const int h,
                 const string label, const string value, const color vclr, const string sub)
{
   double sc = MBVisScale();
   MBVisRect(id + "_BG", x, y, w, h, MBVisBlend(MBVisCard(), MBVisInk(), 0.045), MBVisBlend(MBVisCard(), MBVisGold(), 0.30), false);
   MBVisRect(id + "_TOP", x, y, w, 2, MBVisBlend(MBVisCard(), vclr, 0.70), MBVisBlend(MBVisCard(), vclr, 0.70), false);
   MBVisText(id + "_L", label, x + (int)(10 * sc), y + (int)(6 * sc), MBVisMuted(), G_MB_PANEL_FS - 2, PanelFontBold, ANCHOR_LEFT_UPPER, false);
   MBVisText(id + "_V", MBVisFitPx(value, PanelBrandFont, G_MB_PANEL_FS + 4, w - (int)(20 * sc)), x + (int)(10 * sc), y + h / 2 + (int)(2 * sc),
             vclr, G_MB_PANEL_FS + 4, PanelBrandFont, ANCHOR_LEFT, false);
   MBVisText(id + "_S", MBVisFitPx(sub, PanelFont, G_MB_PANEL_FS - 2, w - (int)(20 * sc)), x + (int)(10 * sc), y + h - (int)(5 * sc),
             MBVisMuted(), G_MB_PANEL_FS - 2, PanelFont, ANCHOR_LEFT_LOWER, false);
}

void MBPanelLine(const string id, const string text, const color clr, const bool mono, const int x0, const int w, const int lh)
{
   if(G_MB_PANEL_COMPACT && MBPanelIsDetail(id))
   {
      ObjectDelete(0, MB_VIS_PREFIX + id);
      G_MB_PANEL_HID[G_MB_PANEL_COL]++;
      return;
   }
   string font = (mono ? PanelFontMono : PanelFont);
   MBVisText(id, MBVisFitPx(text, font, G_MB_PANEL_FS, w - 24), x0 + 12, G_MB_PANEL_Y, clr, G_MB_PANEL_FS, font, ANCHOR_LEFT_UPPER, false);
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

// --- panel data helpers -----------------------------------------------------------------------

// Largest drawdown of the account's closed-balance curve over its whole history (deposits and
// withdrawals move the peak with the balance, so they are not counted as drawdown). Cached.
double   G_MB_HIST_DD_PCT  = 0.0;
datetime G_MB_HIST_DD_TIME = 0;

double MBHistoryMaxDDPercent()
{
   if(G_MB_HIST_DD_TIME > 0 && (TimeCurrent() - G_MB_HIST_DD_TIME) < 600)
      return G_MB_HIST_DD_PCT;
   G_MB_HIST_DD_TIME = TimeCurrent();
   if(!HistorySelect(0, TimeCurrent() + 60))
      return G_MB_HIST_DD_PCT;

   double bal = 0.0, peak = 0.0, worst = 0.0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      ENUM_DEAL_TYPE ty = (ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE);
      double amount = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                      HistoryDealGetDouble(d, DEAL_COMMISSION);
      if(ty == DEAL_TYPE_BALANCE || ty == DEAL_TYPE_CREDIT || ty == DEAL_TYPE_BONUS || ty == DEAL_TYPE_CORRECTION)
      {
         bal += amount;
         peak += amount;
         if(peak < bal) peak = bal;
         continue;
      }
      bal += amount;
      if(bal > peak) peak = bal;
      if(peak > 0.0)
         worst = MathMax(worst, (peak - bal) / peak * 100.0);
   }
   G_MB_HIST_DD_PCT = worst;
   return worst;
}

// Entries this EA opened today (first entries and grid additions). Cached for 30 seconds.
int      G_MB_TODAY_ENTRIES = 0;
datetime G_MB_TODAY_TIME    = 0;

int MBTodayEntries()
{
   if(G_MB_TODAY_TIME > 0 && (TimeCurrent() - G_MB_TODAY_TIME) < 30)
      return G_MB_TODAY_ENTRIES;
   G_MB_TODAY_TIME = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day0 = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   int count = 0;
   if(HistorySelect(day0, TimeCurrent() + 60))
   {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(d, DEAL_MAGIC) != MagicNumber) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
            count++;
      }
   }
   G_MB_TODAY_ENTRIES = count;
   return count;
}

// Lot turnover of this EA (symbol + magic, opening volume only) for today / week / month / all
// time. Cached for two minutes - the full-history pass is too heavy for every panel redraw.
double   G_MB_TURN_LOTS[4];
int      G_MB_TURN_DEALS[4];
datetime G_MB_TURN_TIME = 0;

void MBTurnoverUpdate()
{
   if(G_MB_TURN_TIME > 0 && (TimeCurrent() - G_MB_TURN_TIME) < 120)
      return;
   G_MB_TURN_TIME = TimeCurrent();
   ArrayInitialize(G_MB_TURN_LOTS, 0.0);
   ArrayInitialize(G_MB_TURN_DEALS, 0);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day0 = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime week0 = day0 - (datetime)(((dt.day_of_week + 6) % 7) * 86400);   // Monday
   datetime month0 = day0 - (datetime)((dt.day - 1) * 86400);
   if(!HistorySelect(0, TimeCurrent() + 60))
      return;

   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != MagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      double vol = HistoryDealGetDouble(d, DEAL_VOLUME);
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      G_MB_TURN_LOTS[3] += vol;  G_MB_TURN_DEALS[3]++;
      if(t >= month0) { G_MB_TURN_LOTS[2] += vol;  G_MB_TURN_DEALS[2]++; }
      if(t >= week0)  { G_MB_TURN_LOTS[1] += vol;  G_MB_TURN_DEALS[1]++; }
      if(t >= day0)   { G_MB_TURN_LOTS[0] += vol;  G_MB_TURN_DEALS[0]++; }
   }
}

// Turnover with the estimated cashback when a rate per lot is set.
string MBTurnoverText(const string label, const int k)
{
   string s = StringFormat("%-6s %8.2f lot  %5d savdo", label, G_MB_TURN_LOTS[k], G_MB_TURN_DEALS[k]);
   if(CashbackUSDPerLot() > 0.0)
      s += StringFormat("  ≈ %.2f $", G_MB_TURN_LOTS[k] * CashbackUSDPerLot());
   return s;
}

// The day's busiest entry blockers, in plain words, for the silence line.
string MBGateUz(const int id)
{
   switch(id)
   {
      case GATE_NOSETUP:   return "signal yo'q";
      case GATE_SCORE:     return "ball yetmadi";
      case GATE_MBVETO:    return "miya taqiqi";
      case GATE_MBJUDGE:   return "hakam kutdi";
      case GATE_LOCATION:  return "joy yomon";
      case GATE_ZONE:      return "zona to'sdi";
      case GATE_REGIME:    return "HTF qarshi";
      case GATE_NEWS:      return "yangilik";
      case GATE_CALENDAR:  return "kalendar";
      case GATE_SPREAD:    return "spread";
      case GATE_VELOCITY:  return "tezlik";
      case GATE_RISK:      return "risk";
      case GATE_COOLDOWN:  return "pauza";
      case GATE_SESSION:   return "sessiya";
      case GATE_DIRECTION: return "yo'nalish";
   }
   return GateName(id);
}

string MBGateTopUz(const int top)
{
   int used[3] = {0, 0, 0};
   int total = 0;
   for(int i = 1; i < GATE_COUNT; i++) total += G_GATE[i];
   if(total <= 0) return "bugun to'siq yo'q";
   string t = "";
   for(int k = 0; k < MathMin(3, top); k++)
   {
      int best = 0;
      for(int i = 1; i < GATE_COUNT; i++)
      {
         bool taken = false;
         for(int j = 0; j < k; j++) if(used[j] == i) taken = true;
         if(!taken && G_GATE[i] > 0 && (best == 0 || G_GATE[i] > G_GATE[best])) best = i;
      }
      if(best == 0) break;
      used[k] = best;
      t += StringFormat("%s%s %d%%", (k > 0 ? " · " : ""), MBGateUz(best), (int)MathRound(100.0 * G_GATE[best] / total));
   }
   return t;
}

string MBBiasUz(const int b)
{
   switch(b)
   {
      case MB_BIAS_BULLISH:         return "BUQALAR HUKMRON";
      case MB_BIAS_BULLISH_WEAK:    return "BUQALAR USTUN";
      case MB_BIAS_TRANSITION_UP:   return "BUQALAR UYG'ONMOQDA";
      case MB_BIAS_NEUTRAL:         return "MUVOZANAT";
      case MB_BIAS_TRANSITION_DOWN: return "AYIQLAR UYG'ONMOQDA";
      case MB_BIAS_BEARISH_WEAK:    return "AYIQLAR USTUN";
      case MB_BIAS_BEARISH:         return "AYIQLAR HUKMRON";
   }
   return "?";
}

string MBBiasArrow(const int b)
{
   switch(b)
   {
      case MB_BIAS_BULLISH:         return "▲▲";
      case MB_BIAS_BULLISH_WEAK:    return "▲";
      case MB_BIAS_TRANSITION_UP:   return "↗";
      case MB_BIAS_NEUTRAL:         return "●";
      case MB_BIAS_TRANSITION_DOWN: return "↘";
      case MB_BIAS_BEARISH_WEAK:    return "▼";
      case MB_BIAS_BEARISH:         return "▼▼";
   }
   return "?";
}

string MBEventUz(const int type)
{
   switch(type)
   {
      case MB_EV_LIQ_SWEEP:    return "likvidlik ovlandi";
      case MB_EV_FAKE_BREAK:   return "soxta yorib o'tish";
      case MB_EV_RECLAIM:      return "daraja qaytarib olindi";
      case MB_EV_ACCEPTANCE:   return "daraja yorildi";
      case MB_EV_DISPLACEMENT: return "kuchli zarba shami";
      case MB_EV_BOS:          return "trend davom etdi";
      case MB_EV_MSS:          return "trend burildi";
      case MB_EV_REJECTION:    return "darajadan qaytarildi";
      case MB_EV_COMP_RELEASE: return "siqilish portladi";
   }
   return "?";
}

// The n-th newest relevant event (M1 displacement / BOS left out). -1 when none.
int MBEventNth(const int nth)
{
   int used[];
   ArrayResize(used, MB_EV_MAX);
   ArrayInitialize(used, 0);
   int best = -1;
   for(int k = 0; k <= nth; k++)
   {
      best = -1;
      for(int idx = 0; idx < MB_EV_MAX; idx++)
      {
         if(used[idx] != 0 || G_MB_EV[idx].time <= 0) continue;
         if(G_MB_EV[idx].tfi == 0 && (G_MB_EV[idx].type == MB_EV_DISPLACEMENT || G_MB_EV[idx].type == MB_EV_BOS)) continue;
         if(MBEventWeight(G_MB_EV[idx]) <= 0.0) continue;
         if(best < 0 || G_MB_EV[idx].time > G_MB_EV[best].time)
            best = idx;
      }
      if(best < 0)
         return -1;
      used[best] = 1;
   }
   return best;
}

string MBWhyUz(const string why)
{
   string t = why;
   StringReplace(t, "HTF liquidity reversal: ", "Katta TF likvidligi ovlandi: ");
   StringReplace(t, ", but M5 reversal: ", ", M5 burilishi: ");
   StringReplace(t, ", M5 pullback ", ", M5 da pullback ");
   StringReplace(t, "sell-side", "pastki");
   StringReplace(t, "buy-side", "yuqori");
   StringReplace(t, "M15 neutral, M5 ", "M15 neytral, M5 ");
   StringReplace(t, ", but M5 ", ", lekin M5 ");
   return t;
}

string MBReasonUz(const string reason)
{
   if(StringLen(reason) == 0) return "-";
   if(reason == "score not passed") return "Nishon hali aniq emas - signal kuchsiz";
   if(reason == "entry allowed") return "Barcha filtrlar o'tdi - zarba tayyor";
   string t = reason;
   if(StringFind(t, "hard block: ") == 0) t = "Qattiq to'siq: " + StringSubstr(t, 12);
   if(StringFind(t, "market brain veto: ") == 0) t = "Taqiq: " + StringSubstr(t, 19);
   if(StringFind(t, "entry judge: wait - better location: ") == 0) t = "Yaxshiroq joy poylanmoqda: " + StringSubstr(t, 37);
   else if(StringFind(t, "entry judge: wait - ") == 0) t = "Poylamoqda: " + StringSubstr(t, 20);
   StringReplace(t, " | recheck: ", " | qayta ochiladi: ");
   if(StringFind(t, "waiting for a better place: ") == 0) t = "Yaxshiroq joy poylanmoqda: " + StringSubstr(t, 28);
   return t;
}

// Next high-impact releases for the panel (24h ahead). Refreshed every 10 minutes.
datetime G_MB_NEWS_TIME[2];
string   G_MB_NEWS_NAME[2];
string   G_MB_NEWS_CUR[2];
int      G_MB_NEWS_N     = 0;
datetime G_MB_NEWS_SCAN  = 0;
string   G_MB_NEWS_EMPTY = "Yaqin 24 soatda muhim xabar yo'q";

void MBNewsRadarUpdate()
{
   datetime now = TimeTradeServer();
   if(now <= 0) now = TimeCurrent();
   // Drop releases that have passed.
   while(G_MB_NEWS_N > 0 && G_MB_NEWS_TIME[0] <= now)
   {
      G_MB_NEWS_TIME[0] = G_MB_NEWS_TIME[1];
      G_MB_NEWS_NAME[0] = G_MB_NEWS_NAME[1];
      G_MB_NEWS_CUR[0] = G_MB_NEWS_CUR[1];
      G_MB_NEWS_N--;
   }
   if(G_MB_NEWS_SCAN > 0 && (now - G_MB_NEWS_SCAN) < 600 && now >= G_MB_NEWS_SCAN)
      return;
   G_MB_NEWS_SCAN = now;

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      G_MB_NEWS_N = 0;
      G_MB_NEWS_EMPTY = "Tester rejimida kalendar ishlamaydi";
      return;
   }

   MqlCalendarValue values[];
   ResetLastError();
   long rc = (long)CalendarValueHistory(values, now, now + 24 * 3600, "", EconomicCalendarCurrency);   // package 26: true / false
   int read_err = GetLastError();
   int total = ArraySize(values);
   G_MB_NEWS_N = 0;
   G_MB_NEWS_EMPTY = (rc <= 0 && read_err != 0) ? "Kalendar yuklanmadi" : "Yaqin 24 soatda muhim xabar yo'q";
   for(int i = 0; i < total && G_MB_NEWS_N < 2; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      int importance = (int)ev.importance;
      bool important = (EconomicCalendarMinImportance <= 1) ? (importance >= CALENDAR_IMPORTANCE_MODERATE)
                                                            : (importance >= CALENDAR_IMPORTANCE_HIGH);
      if(!important || values[i].time <= now)
         continue;
      MqlCalendarCountry country;
      string cur = "";
      if(CalendarCountryById(ev.country_id, country))
         cur = country.currency;
      // Keep them in time order (the calendar usually returns them sorted, but do not rely on it).
      int pos = G_MB_NEWS_N;
      while(pos > 0 && G_MB_NEWS_TIME[pos - 1] > values[i].time)
      {
         if(pos < 2)
         {
            G_MB_NEWS_TIME[pos] = G_MB_NEWS_TIME[pos - 1];
            G_MB_NEWS_NAME[pos] = G_MB_NEWS_NAME[pos - 1];
            G_MB_NEWS_CUR[pos] = G_MB_NEWS_CUR[pos - 1];
         }
         pos--;
      }
      if(pos < 2)
      {
         G_MB_NEWS_TIME[pos] = values[i].time;
         G_MB_NEWS_NAME[pos] = ev.name;
         G_MB_NEWS_CUR[pos] = cur;
         G_MB_NEWS_N = MathMin(2, G_MB_NEWS_N + 1);
      }
   }
}

// --- panel ------------------------------------------------------------------------------------
void MBDrawPanel()
{
   int x0 = MathMax(0, DashboardX);
   int y0 = MathMax(0, DashboardY);
   double sc = MBVisScale();
   int w = (int)MathRound(MathMax(320, PanelWidth) * sc);   // package 19: the card grows with the Windows scale like the fonts do
   color ink = MBVisInk(), muted = MBVisMuted();
   // Package 21/22: the layout. Two columns when the chart is wide enough (automatic) or always (3), the card
   // at most PanelMaxWidthPct of the chart (package 22: at a 125% Windows scale it took 70%); one column
   // otherwise. In either, the compact line set only when the full one does not fit the chart's height.
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int gap = (int)MathRound(26 * sc);
   int w2 = 2 * w - 24 + gap;   // pad 12 + column + gap + column + pad 12
   if(chart_w > 0)
      w2 = MathMin(w2, (int)(chart_w * MathMax(30, MathMin(90, PanelMaxWidthPct)) / 100.0));
   int wcol = (w2 + 24 - gap) / 2;   // one column's width, its 12 px pads included
   // Package 23: the owner prefers one column - two columns only when asked for (3).
   bool two = (PanelLayout == 3 && chart_w > 0 && wcol - 24 >= (int)(250 * sc));
   G_MB_PANEL_FS = two ? MathMax(7, PanelFontSize - 1) : PanelFontSize;
   int lh = (int)MathRound(G_MB_PANEL_FS * 1.95 * sc);
   int full_h = two ? ((G_MB_PANEL_TWO_H > 0) ? G_MB_PANEL_TWO_H : 0) : ((G_MB_PANEL_FULL_H > 0) ? G_MB_PANEL_FULL_H : 0);
   // Not measured yet: try the full panel first (a compact one now measures the full height too).
   int room = chart_h - 8 - (G_MB_PANEL_COMPACT ? lh / 2 : 0);   // a little hysteresis: no flapping at the edge
   bool compact_now = (PanelLayout == 2) || (PanelLayout != 1 && chart_h > 0 && full_h > 0 && y0 + full_h > room);
   if(two != G_MB_PANEL_TWO || compact_now != G_MB_PANEL_COMPACT)
   {
      MBDeletePanel();   // a different layout - nothing of the old one may stay behind
      G_MB_PANEL_TWO = two;
      G_MB_PANEL_COMPACT = compact_now;
   }
   if(two)
      w = wcol;   // every column call below takes w as its column width
   int card_x = x0, card_w = (two ? w2 : w);
   int col_xr = x0 + w - 24 + gap;   // the right column's x (its text starts 12 px in, like the left one)
   G_MB_PANEL_COL = 0;
   G_MB_PANEL_HID[0] = 0;
   G_MB_PANEL_HID[1] = 0;
   G_MB_PANEL_W = card_w;
   int prev_edge = G_MB_PANEL_RIGHT_EDGE;
   G_MB_PANEL_RIGHT_EDGE = card_x + card_w;
   // Package 23: the watermark is placed beside the panel - redraw it the moment the panel's edge is known or
   // moves (it used to be drawn before the first panel and stayed centred under it).
   if(prev_edge != G_MB_PANEL_RIGHT_EDGE && EnableNewWatermark && PremiumShowWatermark && UsePremiumVisualEngine)
      MBDrawWatermark();

   // --- card and header band ---
   int band_h = (int)MathRound(lh * 2.1);
   MBVisRect("P_CARD", card_x, y0, card_w, 10, MBVisCard(), MBVisBorder(), false);
   color band = MBVisBlend(MBVisCard(), MBVisGold(), 0.07);
   MBVisRect("P_BAND", card_x + 1, y0 + 1, card_w - 2, band_h, band, band, false);
   MBVisRect("P_ACCENT", card_x, y0, card_w, 3, MBVisGold(), MBVisGold(), false);
   color band_rule = MBVisBlend(MBVisCard(), MBVisGold(), 0.45);
   MBVisRect("P_BANDLINE", card_x + 12, y0 + band_h, card_w - 24, 1, band_rule, band_rule, false);
   int band_cy = y0 + 2 + band_h / 2;
   string brand = MBVisSpaced("SIRUS");
   MBVisText("P_BRAND", brand, card_x + 14, band_cy, MBVisGold(), G_MB_PANEL_FS + 7, PanelBrandFont, ANCHOR_LEFT, false);
   MBVisText("P_BRAND2", "BY ZAKIY  ·  oltin ovchisi", card_x + 14 + MBVisTextW(brand, PanelBrandFont, G_MB_PANEL_FS + 7) + (int)(12 * sc),
             band_cy + (int)(2 * sc), muted, G_MB_PANEL_FS - 1, PanelFont, ANCHOR_LEFT, false);

   string status = "OVDA";
   color status_tone = muted;
   if(G_BASKET_ORDERS > 0)                              { status = "SAVDODA";    status_tone = MBVisBlue(); }
   else if(StringFind(G_ENTRY_REASON, "veto") >= 0)     { status = "TAQIQ";      status_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)    { status = "POYLAMOQDA"; status_tone = MBVisAmber(); }
   else if(G_ENTRY_READY)                               { status = "NISHONDA";   status_tone = MBVisGreen(); }
   if(G_RISK_HARD_BLOCK)                                { status = "HIMOYA";     status_tone = MBVisRed(); }
   int pill_w = MBPanelPillW(status);
   MBPanelPill("P_STATUS", status, card_x + card_w - 12 - pill_w, band_cy - (lh - 2) / 2, lh - 2, status_tone);
   G_MB_PANEL_Y = y0 + band_h + (int)(8 * sc);

   // --- health check (package 24): always visible, compact or not ---
   MBPanelHealth(card_x, card_w, lh);

   // --- account ---
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double today = (G_RISK_DAY_START_EQUITY > 0.0) ? eq - G_RISK_DAY_START_EQUITY : 0.0;
   double hist_dd = MBHistoryMaxDDPercent();
   double max_dd = MathMax(hist_dd, G_ALL_TIME_MAX_DD_PCT);
   color dd_now_clr = DDSeverityColor(G_RISK_EQUITY_DD_PCT, EmergencyDDPercent * 0.3, EmergencyDDPercent * 0.6);
   color dd_max_clr = (max_dd >= 50.0) ? MBVisRed() : ((max_dd >= 25.0) ? MBVisAmber() : MBVisGreen());
   if(two)
   {
      // Package 21: four figure tiles across the card instead of the KAPITAL lines.
      int tg = (int)(8 * sc);
      int th = (int)MathRound(lh * 2.8);
      int tw = (card_w - 24 - 3 * tg) / 4;
      int ty = G_MB_PANEL_Y;
      MBPanelTile("P_T1", card_x + 12, ty, tw, th, "BALANS", StringFormat("%.2f", bal), ink, StringFormat("equity %.2f", eq));
      MBPanelTile("P_T2", card_x + 12 + (tw + tg), ty, tw, th, "BUGUN", StringFormat("%+.2f", today),
                  (today < 0.0 ? MBVisRed() : (today > 0.0 ? MBVisGreen() : ink)),
                  StringFormat("%d zarba · tezkor %d", MBTodayEntries(), MBFastToday()));
      MBPanelTile("P_T3", card_x + 12 + 2 * (tw + tg), ty, tw, th, "DD HOZIR", StringFormat("%.2f%%", G_RISK_EQUITY_DD_PCT), dd_now_clr,
                  StringFormat("savatda eng chuqur %.2f%%", G_ALL_TIME_MAX_DD_PCT));
      MBPanelTile("P_T4", card_x + 12 + 3 * (tw + tg), ty, tw, th, "MAX DD", StringFormat("%.2f%%", max_dd), dd_max_clr, "balans tarixida");
      G_MB_PANEL_Y = ty + th + (int)(4 * sc);
   }
   else
   {
      MBPanelSection("S_ACC", "KAPITAL", x0, w, lh);
      MBPanelLine("A1", StringFormat("Balans %10.2f    Equity %10.2f", bal, eq), ink, true, x0, w, lh);
      MBPanelLine("A2", StringFormat("Bugun  %+10.2f    Zarba  %4d (tezkor %d)", today, MBTodayEntries(), MBFastToday()),
                  (today < 0.0 ? MBVisRed() : (today > 0.0 ? MBVisGreen() : ink)), true, x0, w, lh);
      MBPanelLine("A3", StringFormat("DD hozir %5.2f%%     Max DD %5.2f%%", G_RISK_EQUITY_DD_PCT, max_dd),
                  (max_dd >= 50.0 ? MBVisRed() : dd_now_clr), true, x0, w, lh);
      MBPanelLine("A4", StringFormat("Eng chuqur DD: balans tarixida %.2f%%, ochiq savatda %.2f%%", hist_dd, G_ALL_TIME_MAX_DD_PCT),
                  muted, false, x0, w, lh);
   }
   int col_top = G_MB_PANEL_Y;
   int left_end = G_MB_PANEL_Y;

   // --- cashback (only in rebate mode) ---
   if(RebateModeOn())
   {
      MBPanelSection("S_CB", "CASHBACK AYLANMASI", x0, w, lh);
      MBTurnoverUpdate();
      MBPanelLine("C1", MBTurnoverText("Bugun", 0), MBVisGold(), true, x0, w, lh);
      MBPanelLine("C2", MBTurnoverText("Hafta", 1), ink, true, x0, w, lh);
      MBPanelLine("C3", MBTurnoverText("Oy", 2), ink, true, x0, w, lh);
      MBPanelLine("C4", MBTurnoverText("Jami", 3), ink, true, x0, w, lh);
      string trail = "trailing o'chiq";
      if(RebateTrailingOn())
         trail = G_RB_TRAIL_ACTIVE ? StringFormat("trailing FAOL, qulf %.0f pt", G_RB_TRAIL_LOCK) : "trailing TP da yoqiladi";
      MBPanelLine("C5", StringFormat("TP %.0f pt  ·  %s  ·  tempo %s", RebateTargetPoints(), trail,
                                     (MBCashbackTempo() ? "TEZKOR" : "oddiy")), muted, false, x0, w, lh);
   }
   else if(ObjectFind(0, MB_VIS_PREFIX + "C1") >= 0)
   {
      ObjectsDeleteAll(0, MB_VIS_PREFIX + "S_CB");
      ObjectsDeleteAll(0, MB_VIS_PREFIX + "C");
   }

   // --- market brain ---
   MBPanelSection("S_BRAIN", "BOZOR NAFASI", x0, w, lh);
   if(EnableMarketBrain && EnableMarketBrainEngines)
   {
      color tone = MBBiasTone(G_MB_BIAS);
      string bias = MBBiasUz(G_MB_BIAS);
      MBPanelPill("B_BIAS", bias, x0 + 12, G_MB_PANEL_Y, lh - 2, tone);
      int bar_x = x0 + 12 + MBPanelPillW(bias) + (int)(12 * sc);
      int bar_w = MathMax(40, w - (bar_x - x0) - MBVisTextW("ishonch 100%", PanelFont, G_MB_PANEL_FS - 1) - (int)(22 * sc));
      MBPanelBar("B_CONF", bar_x, G_MB_PANEL_Y + lh / 2 - 3, bar_w, G_MB_BIAS_CONF, tone);
      MBVisText("B_CONF_TX", StringFormat("ishonch %d%%", G_MB_BIAS_CONF), x0 + w - 12, G_MB_PANEL_Y + 1, muted, G_MB_PANEL_FS - 1, PanelFont, ANCHOR_RIGHT_UPPER, false);
      G_MB_PANEL_Y += lh + 2;
      MBPanelLine("B_WHY", "Sabab: " + MBWhyUz(G_MB_BIAS_WHY), ink, false, x0, w, lh);
      // Stage 18 (B5): the evidence board - the biggest liquidity event and the latest M15+ structure.
      {
         string ev_txt = "";
         SMBEvent e;
         int best_rank = -1;
         for(int ty = MB_EV_LIQ_SWEEP; ty <= MB_EV_FAKE_BREAK; ty++)
            if(MBEventFind(ty, 0, 3, e) && MBEventRank(e.tfi) > best_rank)
            {
               best_rank = MBEventRank(e.tfi);
               ev_txt = StringFormat("%s %s %s %s", MBTFName(e.tfi), (e.dir > 0 ? "▲" : "▼"), MBEventUz(e.type), DoubleToString(e.level, _Digits));
            }
         SMBEvent st;
         bool have_st = MBEventFind(MB_EV_MSS, 0, 2, st);
         SMBEvent bos;
         if(MBEventFind(MB_EV_BOS, 0, 2, bos) && (!have_st || bos.time > st.time)) { st = bos; have_st = true; }
         string st_txt = have_st ? StringFormat("%s %s %s", MBTFName(st.tfi), (st.dir > 0 ? "▲" : "▼"), MBEventUz(st.type)) : "";
         string board = "Dalillar: ";
         board += (StringLen(ev_txt) > 0 ? ev_txt : "katta likvidlik hodisasi yo'q");
         if(StringLen(st_txt) > 0) board += "  ·  " + st_txt;
         MBPanelLine("B_EVB", board, muted, false, x0, w, lh);
      }
      // Three layers: global (M15+) · local (M5) · micro (M1), and the local leg's own thesis.
      MBPanelLine("B_LOCAL", StringFormat("Qatlamlar: global %s · lokal %s · mikro %s  ·  lokal oqim %s",
                                          MBBiasArrow(G_MB_BIAS), MBBiasArrow(2 * MBLayerLocal()), MBBiasArrow(2 * MBLayerMicro()),
                                          MBLocalText()), ink, false, x0, w, lh);
      int ln = 0;
      double lwr = MBLocalWinRate(ln);
      string lrec = (ln > 0) ? StringFormat(" · lokal natija %d/%d", (int)MathRound(lwr * ln), ln) : "";
      if(G_LOC_TH_DIR != 0)
         MBPanelLine("B_LOCTH", StringFormat("Lokal oyoq %s: maqsad %s · chegara %s%s", (G_LOC_TH_DIR > 0 ? "▲" : "▼"),
                                             DoubleToString(G_LOC_TH_TARGET, _Digits), DoubleToString(G_LOC_TH_INVALID, _Digits), lrec),
                     muted, false, x0, w, lh);
      else
         MBPanelLine("B_LOCTH", StringFormat("Lokal oyoq: yo'q (oxirgisi: %s)%s", G_LOC_TH_STATE, lrec), muted, false, x0, w, lh);
      // Chart lines for the local leg.
      string lt = MB_VIS_PREFIX + "LOC_TGT", li = MB_VIS_PREFIX + "LOC_INV";
      if(ShowLocalOnChart && G_LOC_TH_DIR != 0)
      {
         if(ObjectFind(0, lt) < 0) { ObjectCreate(0, lt, OBJ_HLINE, 0, 0, G_LOC_TH_TARGET); ObjectSetInteger(0, lt, OBJPROP_STYLE, STYLE_DASH);
                                     ObjectSetInteger(0, lt, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, lt, OBJPROP_HIDDEN, true); }
         if(ObjectFind(0, li) < 0) { ObjectCreate(0, li, OBJ_HLINE, 0, 0, G_LOC_TH_INVALID); ObjectSetInteger(0, li, OBJPROP_STYLE, STYLE_DOT);
                                     ObjectSetInteger(0, li, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, li, OBJPROP_HIDDEN, true); }
         ObjectSetDouble(0, lt, OBJPROP_PRICE, G_LOC_TH_TARGET);
         ObjectSetDouble(0, li, OBJPROP_PRICE, G_LOC_TH_INVALID);
         ObjectSetInteger(0, lt, OBJPROP_COLOR, MBVisGreen());
         ObjectSetInteger(0, li, OBJPROP_COLOR, MBVisAmber());
         ObjectSetString(0, lt, OBJPROP_TEXT, "Lokal maqsad");
         ObjectSetString(0, li, OBJPROP_TEXT, "Lokal chegara");
      }
      else
      {
         if(ObjectFind(0, lt) >= 0) ObjectDelete(0, lt);
         if(ObjectFind(0, li) >= 0) ObjectDelete(0, li);
      }
      MBPanelLine("B_TF", StringFormat("TF  M5 %s  M15 %s  H1 %s  H4 %s  ·  Bosim  M1 %s  M5 %s  M15 %s",
                                       MBBiasArrow(G_MB_TF_STATE[1]), MBBiasArrow(G_MB_TF_STATE[2]),
                                       MBBiasArrow(G_MB_TF_STATE[3]), MBBiasArrow(G_MB_TF_STATE[4]),
                                       MBBiasArrow(2 * MBPressureSide(0)), MBBiasArrow(2 * MBPressureSide(1)),
                                       MBBiasArrow(2 * MBPressureSide(2))), muted, false, x0, w, lh);
      string loc = "Maydon: H1 diapazon hali chizilmadi";
      if(G_MB_DR_HI > G_MB_DR_LO)
         loc = StringFormat("Maydon: %s (%.0f%%)  ·  %s – %s",
                            (G_MB_DR_POS >= 0.55 ? "PREMIUM ZONA" : (G_MB_DR_POS <= 0.45 ? "CHEGIRMA ZONASI" : "MUVOZANAT")), G_MB_DR_POS * 100.0,
                            DoubleToString(G_MB_DR_LO, _Digits), DoubleToString(G_MB_DR_HI, _Digits));
      MBPanelLine("B_LOC", loc, ink, false, x0, w, lh);
      if(EnableRegimePlaybook && G_MB_RG != MB_RG_NONE)
      {
         string rg_uz = "DIAPAZON";
         if(G_MB_RG == MB_RG_TREND)            rg_uz = (G_MB_RG_DIR > 0 ? "TREND ▲" : "TREND ▼");
         else if(G_MB_RG == MB_RG_EXPANSION)   rg_uz = (G_MB_RG_DIR > 0 ? "PORTLASH ▲" : "PORTLASH ▼");
         else if(G_MB_RG == MB_RG_COMPRESSION) rg_uz = "SIQILISH";
         string rg_play = "chekkada kirish, o'rtada ehtiyot";
         if(G_MB_RG == MB_RG_TREND)            rg_play = "pullback'da trend tomonga";
         else if(G_MB_RG == MB_RG_EXPANSION)   rg_play = "faqat portlash tomonga, erta";
         else if(G_MB_RG == MB_RG_COMPRESSION) rg_play = "chiqish shamini kutish";
         MBPanelLine("B_RG", StringFormat("Rejim (M15): %s  ·  %s", rg_uz, rg_play), ink, false, x0, w, lh);
      }
      else
         ObjectDelete(0, MB_VIS_PREFIX + "B_RG");
      // Plan stage 8: market state, scenarios and the narrative.
      {
         string ms = MBStatePanelText();
         if(StringLen(ms) > 0)
         {
            MBPanelLine("B_MS", ms, (G_MST_STATE == MST_NEWS ? MBVisAmber() : ink), false, x0, w, lh);
            MBPanelLine("B_SCN", MBScenarioPanelText(), muted, false, x0, w, lh);
            string scf = MBScenarioFeedbackText();   // package 16b: how often the dominant scenario was right
            if(StringLen(scf) > 0)
               MBPanelLine("B_SCF", scf, muted, false, x0, w, lh);
            else
               ObjectDelete(0, MB_VIS_PREFIX + "B_SCF");
            MBPanelLine("B_NAR", "Hikoya: " + G_MST_STORY, muted, false, x0, w, lh);
         }
         else
         {
            ObjectDelete(0, MB_VIS_PREFIX + "B_MS");
            ObjectDelete(0, MB_VIS_PREFIX + "B_SCN");
            ObjectDelete(0, MB_VIS_PREFIX + "B_SCF");
            ObjectDelete(0, MB_VIS_PREFIX + "B_NAR");
         }
      }
      // Plan stage 1: structure memory, direction lock and reversal maturity.
      MBPanelLine("B_ST", MBStructPanelText(), muted, false, x0, w, lh);
      MBPanelLine("B_LK", MBLockPanelText(), (G_ST_LOCK_DIR != 0 ? MBBiasTone(2 * G_ST_LOCK_DIR) : muted), false, x0, w, lh);
      if(EnableMBLiquidityMap)
         MBPanelLine("B_LQ", MBLiquidityPanelText(), muted, false, x0, w, lh);
      else
         ObjectDelete(0, MB_VIS_PREFIX + "B_LQ");
      // Stage 17: session, volatility percentile and tick flow.
      string flow_txt = (EnableTickFlow && G_MB_FLOW_N >= 20)
                        ? StringFormat("Oqim %s %.0f%%", (G_MB_FLOW_IMB >= 0.0 ? "▲" : "▼"), MathAbs(G_MB_FLOW_IMB) * 100.0) : "Oqim -";
      MBPanelLine("B_SES", StringFormat("Sessiya: %s%s  ·  Volatillik %s  ·  %s", MBSessionUz(MBSessionNow()),
                                        (MBSessionOpenWindow() ? " (ochilish)" : ""),
                                        (G_MB_VOL_PCT >= 0.0 ? StringFormat("%.0f-foiz", G_MB_VOL_PCT) : "-"), flow_txt),
                  muted, false, x0, w, lh);
      if(G_MB_DEAD_DIR != 0 && TimeCurrent() < G_MB_DEAD_UNTIL)
         MBPanelLine("B_LOCK", StringFormat("Qulf: %s %d daq (g'oya yiqildi) - yangi struktura bilan ochiladi",
                                            (G_MB_DEAD_DIR > 0 ? "BUY" : "SELL"), (int)((G_MB_DEAD_UNTIL - TimeCurrent()) / 60)),
                     MBVisAmber(), false, x0, w, lh);
      else
         ObjectDelete(0, MB_VIS_PREFIX + "B_LOCK");
      MBPanelLine("B_TGT", StringFormat("Nishon %s  ·  G'oya chegarasi %s",
                                        (G_MB_TH_TARGET > 0.0 ? DoubleToString(G_MB_TH_TARGET, _Digits) : "-"),
                                        (G_MB_TH_INVALID > 0.0 ? DoubleToString(G_MB_TH_INVALID, _Digits) : "-")), muted, false, x0, w, lh);
      // Package 21: in two columns the right column starts here, with the judge / zones / place lines.
      left_end = G_MB_PANEL_Y;
      if(two)
      {
         G_MB_PANEL_Y = col_top;
         x0 = col_xr;
         G_MB_PANEL_COL = 1;
         MBPanelSection("S_DET", "HAKAM · ZONALAR · JOY", x0, w, lh);
      }
      {
         string ses = MBSessionPanelText();   // package 12: Asia / Frankfurt / London high-low and the midnight open
         if(StringLen(ses) > 0) MBPanelLine("B_SESL", ses, muted, false, x0, w, lh);   // package 19: own id (B_SES is the session line below)
         else ObjectDelete(0, MB_VIS_PREFIX + "B_SESL");
      }
      {
         string ab = MBArbiterText();   // direction arbiter: what H4 / H1 / M15 / M5 say and the verdict per side
         if(StringLen(ab) > 0) MBPanelLine("B_ARB", ab, muted, false, x0, w, lh);
         else ObjectDelete(0, MB_VIS_PREFIX + "B_ARB");
      }
      {
         string zi = ZIPanelText();     // package 10: the nearest RBR / DBR / RBD / DBD zones with their score
         if(StringLen(zi) > 0) MBPanelLine("B_ZI", zi, muted, false, x0, w, lh);
         else ObjectDelete(0, MB_VIS_PREFIX + "B_ZI");
      }
      {
         string hz = MBHTFZoneText();   // HTF supply / demand zones and the M15 lower high / higher low
         if(StringLen(hz) > 0) MBPanelLine("B_HZ", hz, muted, false, x0, w, lh);
         else ObjectDelete(0, MB_VIS_PREFIX + "B_HZ");
      }
      {
         string mc = MBMicroPanelText();
         if(StringLen(mc) > 0) MBPanelLine("B_MC", mc, muted, false, x0, w, lh);
         else ObjectDelete(0, MB_VIS_PREFIX + "B_MC");
      }
      {
         string ce = MBCostPanelText();
         if(StringLen(ce) > 0) MBPanelLine("B_CE", ce, (StringFind(ce, "BAND") >= 0 ? MBVisAmber() : muted), false, x0, w, lh);
         else ObjectDelete(0, MB_VIS_PREFIX + "B_CE");
      }
      MBPanelLine("B_LX", MBLocationPanelText(), ((G_LX_PRESS[0] >= ExhaustCautionScore || G_LX_PRESS[1] >= ExhaustCautionScore) ? MBVisAmber() : muted), false, x0, w, lh);
   }
   else
   {
      MBPanelLine("B_OFF", "Bozor miyasi o'chirilgan", muted, false, x0, w, lh);
      left_end = G_MB_PANEL_Y;
      if(two)
      {
         G_MB_PANEL_Y = col_top;
         x0 = col_xr;
         G_MB_PANEL_COL = 1;
      }
   }

   // --- entry ---
   MBPanelSection("S_ENTRY", "ZARBA LAHZASI", x0, w, lh);
   string dec = "NISHON YO'Q";
   color dec_tone = muted;
   if(StringFind(G_ENTRY_REASON, "veto") >= 0)           { dec = "TAQIQ";            dec_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0 && G_MB_ENTRY_OUTCOME == MB_EO_WAIT_LOCATION) { dec = "JOY POYLANMOQDA"; dec_tone = MBVisAmber(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)     { dec = "POYLAMOQDA";       dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY && G_MB_ENTRY_DECISION == MB_ED_CAUTION) { dec = "EHTIYOTKOR ZARBA"; dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY && G_MB_ENTRY_OUTCOME == MB_EO_EXECUTE_FAST) { dec = "TEZKOR ZARBA"; dec_tone = MBVisGreen(); }
   else if(G_ENTRY_READY)                                { dec = "ZARBA";            dec_tone = MBVisGreen(); }
   MBPanelPill("E_DEC", dec, x0 + 12, G_MB_PANEL_Y, lh - 2, dec_tone);
   int qx = x0 + 12 + MBPanelPillW(dec) + (int)(12 * sc);
   int qw = MathMax(40, w - (qx - x0) - MBVisTextW("sifat 100", PanelFont, G_MB_PANEL_FS - 1) - (int)(22 * sc));
   MBPanelBar("E_Q", qx, G_MB_PANEL_Y + lh / 2 - 3, qw, G_MB_ENTRY_QUALITY, dec_tone);
   MBVisText("E_Q_TX", StringFormat("sifat %d", G_MB_ENTRY_QUALITY), x0 + w - 12, G_MB_PANEL_Y + 1, muted, G_MB_PANEL_FS - 1, PanelFont, ANCHOR_RIGHT_UPPER, false);
   G_MB_PANEL_Y += lh + 2;
   string why_txt = MBReasonUz(G_ENTRY_REASON);
   if(G_BASKET_ORDERS > 0)
      why_txt = StringFormat("savat ochiq (%d order) - yangi kirish yo'q, savat boshqarilmoqda", G_BASKET_ORDERS);
   else if(G_RISK_HARD_BLOCK)   // package 24: the entry check does not run under a hard block - say why
      why_txt = "himoya - " + MBRiskReasonUz(G_RISK_REASON) + ", yangi kirish yo'q";
   else if(CoreEntryOn() && StringFind(G_ENTRY_REASON, "core ") == 0)
      why_txt = CoreReasonUz(G_ENTRY_REASON);   // package 29: YADRO's own refusal
   else if(G_ENTRY_REASON == "initial entry")
      why_txt = "tekshiruv hali boshlanmadi (birinchi tik kutilmoqda)";
   else if(G_ENTRY_REASON == "score not passed" && G_OPP_DIR != OPP_DIR_NONE && G_SCORE_MIN_REQUIRED > 0)
      why_txt = StringFormat("%s signal kuchsiz: ball %d / kerak %d", (G_OPP_DIR == OPP_DIR_BUY ? "BUY" : "SELL"),
                             G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
   MBPanelLine("E_WHY", "Sabab: " + why_txt, ink, false, x0, w, lh);
   if(G_BASKET_ORDERS <= 0 && G_QUIET_BARS >= 5)
      MBPanelLine("E_QUIET", StringFormat("Jimlik %d daq  ·  %s", G_QUIET_BARS, MBGateTopUz(3)),
                  (G_QUIET_BARS >= 30 ? MBVisAmber() : muted), false, x0, w, lh);
   else
      MBPanelLine("E_QUIET", "To'siqlar bugun: " + MBGateTopUz(3), muted, false, x0, w, lh);
   if(G_BASKET_ORDERS <= 0 && CoreEntryOn())
      MBPanelLine("E_FAST", CorePanelText(), muted, false, x0, w, lh);   // package 29: YADRO, both sides
   else if(G_BASKET_ORDERS <= 0 && EnableBrainEntries && (StringLen(G_MB_FAST_WHYNOT[0]) > 0 || StringLen(G_MB_FAST_WHYNOT[1]) > 0))
      MBPanelLine("E_FAST", StringFormat("Miya  BUY: %s  ·  SELL: %s", G_MB_FAST_WHYNOT[1], G_MB_FAST_WHYNOT[0]), muted, false, x0, w, lh);
   else
      ObjectDelete(0, MB_VIS_PREFIX + "E_FAST");
   string sh = MBShadowPanelText();
   if(StringLen(sh) > 0)
      MBPanelLine("E_SHADOW", sh, (StringFind(sh, "⚠") >= 0 ? MBVisAmber() : muted), false, x0, w, lh);
   string egt = MBEGPanelText();   // evidence gates: which quality filters stand aside, per side
   if(StringLen(egt) > 0)
      MBPanelLine("E_EG", egt, (StringFind(egt, "to'xtatildi") >= 0 ? MBVisAmber() : muted), false, x0, w, lh);
   else
      ObjectDelete(0, MB_VIS_PREFIX + "E_EG");
   string au_bal = MBAutopsyPanelText();   // plan stage 7: bad entries taken vs good setups missed
   if(StringLen(au_bal) > 0)
      MBPanelLine("E_BAL", au_bal, muted, false, x0, w, lh);
   else
      ObjectDelete(0, MB_VIS_PREFIX + "E_BAL");

   // --- basket ---
   MBPanelSection("S_BASKET", "SAVAT", x0, w, lh);
   if(G_BASKET_ORDERS > 0)
   {
      bool buy = (G_BASKET_DIRECTION == POSITION_TYPE_BUY);
      double tp_pts = BasketTPForOrderCount(G_BASKET_ORDERS);
      double tp_price = buy ? G_BASKET_AVG_PRICE + tp_pts * _Point : G_BASKET_AVG_PRICE - tp_pts * _Point;
      MBPanelLine("K1", StringFormat("%s x%d   foyda %+.2f $   (%+.0f pt)", (buy ? "BUY" : "SELL"), G_BASKET_ORDERS,
                                     G_BASKET_PROFIT, G_BASKET_POINTS),
                  (G_BASKET_PROFIT >= 0.0 ? MBVisGreen() : MBVisRed()), true, x0, w, lh);
      MBPanelLine("K2", StringFormat("BE narx %s   TP narx %s   DD %.2f%%", DoubleToString(G_BASKET_AVG_PRICE, _Digits),
                                     DoubleToString(tp_price, _Digits), G_BASKET_DD_PERCENT), ink, true, x0, w, lh);
      string state = "G'oya tirik - grid aqlli rejimda";
      if(G_MB_TH_THREAT && G_MB_TH_DIR == (buy ? 1 : -1)) state = "G'oya xavf ostida - grid to'xtadi (" + G_MB_TH_THREAT_WHY + ")";
      if(G_MB_PB_DEAD) state = "G'oya yiqildi - grid to'xtadi, BE'da chiqamiz";
      if(MBRunnerActive())
         state = StringFormat("YUGURUVCHI: qulf +%.0f · cho'qqi +%.0f · maqsad +%.0f pt", G_BASKET_TRAIL_LOCK, G_BASKET_TRAIL_PEAK, G_RUN_TARGET);
      else if(G_MB_PB_RESCUED) state = "Qutqaruv rejimi - yangi g'oya savat tomonida";
      MBPanelLine("K3", state, (G_MB_PB_DEAD ? MBVisAmber() : muted), false, x0, w, lh);
      if(StringLen(G_MB_ENTRY_KIND) > 0)
         MBPanelLine("K6", "Kirish: " + G_MB_ENTRY_KIND + (G_MB_PB_LOCAL ? " · LOKAL savat" : ""), muted, false, x0, w, lh);
      else
         ObjectDelete(0, MB_VIS_PREFIX + "K6");
      MBPanelLine("K4", StringFormat("Keyingi grid: %.0f pt narida, lot %.2f", G_NEXT_GRID_DISTANCE, G_NEXT_GRID_LOT),
                  muted, false, x0, w, lh);
      // Rescue guarantee: why the grid is holding, for how long, and how far price has run.
      if(G_GRID_HOLD_SINCE > 0)
      {
         string gr = G_GRID_REASON;
         if(StringFind(gr, "holding - ") == 0) gr = StringSubstr(gr, 10);
         MBPanelLine("K8", StringFormat("Grid kutmoqda %d daq · narx %.1f qadam · %s%s", (int)((TimeCurrent() - G_GRID_HOLD_SINCE) / 60),
                                        G_GRID_ADVERSE_STEPS, gr,
                                        (G_GRID_RESCUE_ON ? "" : StringFormat(" · qutqaruv %.1f qadamda", GridRescueSoftSteps))),
                     (G_GRID_ADVERSE_STEPS >= GridRescueSoftSteps ? MBVisAmber() : muted), false, x0, w, lh);
      }
      else if(G_GRID_RESCUE_ON)
         MBPanelLine("K8", "QUTQARUV: grid to'siqlari chetlab o'tiladi - " + G_GRID_RESCUE_WHY, MBVisAmber(), false, x0, w, lh);
      else
         ObjectDelete(0, MB_VIS_PREFIX + "K8");
      string rc = MBRecoveryText();
      if(StringLen(rc) > 0)
         MBPanelLine("K5", rc, (G_MB_RC_STATE == MB_RC_IMPOSSIBLE ? MBVisRed() : (G_MB_RC_STATE == MB_RC_DOUBTFUL ? MBVisAmber() : muted)),
                     false, x0, w, lh);
      else
         ObjectDelete(0, MB_VIS_PREFIX + "K5");
      // Plan stage 5: expectation vs reality.
      if(EnableExpectationCheck && G_MB_PB_BASKET > 0)
      {
         int pb_min = (int)((TimeCurrent() - G_MB_PB_BASKET) / 60);
         double tp_x = BasketTPForOrderCount(MathMax(1, G_BASKET_ORDERS));
         string ex = G_PB_EXP_FAIL ? "BAJARILMADI - BE'da chiqamiz (" + G_PB_EXP_WHY + ")"
                                   : StringFormat("%d daq · eng yaxshi +%.0f / TP %.0f%s", pb_min, G_PB_MFE, tp_x,
                                                  (G_PB_MFE >= ExpectTPShare * tp_x ? " · ko'rsatdi" : ""));
         MBPanelLine("K7", "Kutilgan: " + ex, (G_PB_EXP_FAIL ? MBVisAmber() : muted), false, x0, w, lh);
      }
      else
         ObjectDelete(0, MB_VIS_PREFIX + "K7");
   }
   else
   {
      ObjectDelete(0, MB_VIS_PREFIX + "K7");
      ObjectDelete(0, MB_VIS_PREFIX + "K8");
      MBPanelLine("K1", "Savat bo'sh - keyingi o'lja poylanmoqda", muted, false, x0, w, lh);
      ObjectDelete(0, MB_VIS_PREFIX + "K2");
      ObjectDelete(0, MB_VIS_PREFIX + "K3");
      ObjectDelete(0, MB_VIS_PREFIX + "K4");
      ObjectDelete(0, MB_VIS_PREFIX + "K5");
      ObjectDelete(0, MB_VIS_PREFIX + "K6");
   }

   // --- events ---
   MBPanelSection("S_EV", "BOZOR IZLARI", x0, w, lh);
   for(int i = 0; i < 3; i++)
   {
      int idx = MBEventNth(i);
      if(idx < 0)
      {
         MBPanelLine("V" + IntegerToString(i), (i == 0 ? "Hozircha muhim iz yo'q" : " "), muted, false, x0, w, lh);
         continue;
      }
      string t = StringFormat("%s  %s %s  %s  ·  %d bar oldin",
                              MBTFName(G_MB_EV[idx].tfi), (G_MB_EV[idx].dir > 0 ? "▲" : "▼"),
                              MBEventUz(G_MB_EV[idx].type), DoubleToString(G_MB_EV[idx].level, _Digits),
                              MBEventAgeBars(G_MB_EV[idx]));
      MBPanelLine("V" + IntegerToString(i), t, (G_MB_EV[idx].dir > 0 ? MBVisGreen() : MBVisRed()), false, x0, w, lh);
   }

   // --- news radar ---
   MBPanelSection("S_NEWS", "XABARLAR RADARI", x0, w, lh);
   if(EnableEconomicCalendarGuard && G_CAL_ACTIVE)
      MBPanelLine("N0", StringFormat("HOZIR: %s  ·  %s", G_CAL_EVENT_NAME,
                                     (G_CAL_MINUTES_FROM_EVENT >= 0 ? StringFormat("%d daq qoldi", G_CAL_MINUTES_FROM_EVENT)
                                                                    : StringFormat("%d daq oldin chiqdi", -G_CAL_MINUTES_FROM_EVENT))),
                  MBVisRed(), false, x0, w, lh);
   else
      ObjectDelete(0, MB_VIS_PREFIX + "N0");
   MBNewsRadarUpdate();
   for(int k = 0; k < 2; k++)
   {
      string nid = "N" + IntegerToString(k + 1);
      if(k >= G_MB_NEWS_N)
      {
         MBPanelLine(nid, (k == 0 ? G_MB_NEWS_EMPTY : " "), muted, false, x0, w, lh);
         continue;
      }
      long left = (long)(G_MB_NEWS_TIME[k] - TimeTradeServer()) / 60;
      string left_txt = (left >= 60) ? StringFormat("%dsoat %02ddaq", (int)(left / 60), (int)(left % 60)) : StringFormat("%d daq", (int)MathMax(0.0, (double)left));
      MBPanelLine(nid, StringFormat("%s  %s  %s  ·  %s qoldi", TimeToString(G_MB_NEWS_TIME[k], TIME_MINUTES),
                                    G_MB_NEWS_CUR[k], G_MB_NEWS_NAME[k], left_txt),
                  (left <= 60 ? MBVisAmber() : ink), false, x0, w, lh);
   }

   // --- column divider (two columns) ---
   int right_end = G_MB_PANEL_Y;
   int cols_end = two ? MathMax(left_end, right_end) : G_MB_PANEL_Y;
   // Package 22: the height the full panel would need - drawn now, or this draw plus the lines it left out.
   int full_cols_end = two ? MathMax(left_end + G_MB_PANEL_HID[0] * lh, right_end + G_MB_PANEL_HID[1] * lh)
                           : cols_end + (G_MB_PANEL_HID[0] + G_MB_PANEL_HID[1]) * lh;
   if(two)
   {
      color div = MBVisBlend(MBVisCard(), MBVisGold(), 0.22);
      MBVisRect("P_DIV", col_xr + 12 - gap / 2, col_top + (int)(6 * sc), 1, MathMax(1, cols_end - col_top - (int)(6 * sc)), div, div, false);
   }
   G_MB_PANEL_Y = cols_end;

   // --- footer: one strip across the card - spread and server time left, the speed right ---
   G_MB_PANEL_Y += (int)(6 * sc);
   color foot = MBVisBlend(MBVisCard(), MBVisInk(), 0.035);
   MBVisRect("P_FOOT", card_x + 1, G_MB_PANEL_Y, card_w - 2, lh + (int)(4 * sc), foot, foot, false);
   string f1 = StringFormat("spread %d  ·  server %s%s", G_LAST_SPREAD_POINTS, TimeToString(TimeTradeServer(), TIME_MINUTES),
                            (G_MB_PANEL_COMPACT ? "  ·  ixcham" : ""));
   MBVisText("F1", f1, card_x + 12, G_MB_PANEL_Y + (int)(3 * sc), muted, G_MB_PANEL_FS - 1, PanelFont, ANCHOR_LEFT_UPPER, false);
   string prof = MBProfText();
   int f2_w = card_w - 24 - MBVisTextW(f1, PanelFont, G_MB_PANEL_FS - 1) - (int)(16 * sc);
   if(StringLen(prof) > 0 && f2_w > 40)   // performance contract: amber above 30 ms
      MBVisText("F2", MBVisFitPx(prof, PanelFont, G_MB_PANEL_FS - 1, f2_w), card_x + card_w - 12, G_MB_PANEL_Y + (int)(3 * sc),
                (MBProfSlow() ? MBVisAmber() : muted), G_MB_PANEL_FS - 1, PanelFont, ANCHOR_RIGHT_UPPER, false);
   else
      ObjectDelete(0, MB_VIS_PREFIX + "F2");
   G_MB_PANEL_Y += lh + (int)(4 * sc);

   // Size the card to what was drawn; every draw remembers the full height for the automatic layout.
   int full_now = (G_MB_PANEL_Y - y0 + 4) + (full_cols_end - cols_end);
   if(two) G_MB_PANEL_TWO_H = full_now;
   else    G_MB_PANEL_FULL_H = full_now;
   ObjectSetInteger(0, MB_VIS_PREFIX + "P_CARD", OBJPROP_YSIZE, G_MB_PANEL_Y - y0 + 4);
   // Package 24: a compact panel with room left brings detail lines back, most useful first (one line of
   // room = one line more; an overflow takes lines away again).
   if(G_MB_PANEL_COMPACT && chart_h > 0 && lh > 0)
   {
      int spare = (chart_h - 8) - (G_MB_PANEL_Y + 4);
      int step = (spare >= 0) ? spare / lh : -((-spare + lh - 1) / lh);
      step = MathMin(step, G_MB_PANEL_HID[0] + G_MB_PANEL_HID[1]);   // package 26: only lines that were really left out
      G_MB_PANEL_EXTRA = MathMax(0, MathMin(30, G_MB_PANEL_EXTRA + step));
   }
   else
      G_MB_PANEL_EXTRA = 0;
   ChartRedraw(0);   // timer redraws otherwise wait for the next tick to show
}

void MBDeletePanel()
{
   G_MB_PANEL_RIGHT_EDGE = 0;
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "P_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "S_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "A");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "B_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "E_");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "K");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "V");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "F");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "N");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "C");
}

void MBDeleteAllVisuals()
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX);
}
