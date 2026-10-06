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
input int    PanelWidth               = 430;                // Panel kengligi (px)
input string PanelFont                = "Segoe UI";
input string PanelFontBold            = "Segoe UI Semibold";
input string PanelFontMono            = "Consolas";
input int    PanelFontSize            = 9;
input double CashbackPerLot           = 0.0;                // CASHBACK bo'limi: 1 lot uchun qaytadigan $ (0 = taxminiy cashback ko'rsatilmaydi). Bo'lim faqat cashback rejimida chiqadi

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
   if(CashbackPerLot > 0.0)
      s += StringFormat("  ≈ %.2f $", G_MB_TURN_LOTS[k] * CashbackPerLot);
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
   if(StringFind(t, "market brain veto: ") == 0) t = "Taqiq: " + StringSubstr(t, 19);
   if(StringFind(t, "entry judge: wait - ") == 0) t = "Poylamoqda: " + StringSubstr(t, 20);
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
   int total = CalendarValueHistory(values, now, now + 24 * 3600, "", EconomicCalendarCurrency);
   G_MB_NEWS_N = 0;
   G_MB_NEWS_EMPTY = (total < 0) ? "Kalendar yuklanmadi" : "Yaqin 24 soatda muhim xabar yo'q";
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
   int w = MathMax(320, PanelWidth);
   int lh = (int)MathRound(PanelFontSize * 1.95);
   color ink = MBVisInk(), muted = MBVisMuted();

   // Card first, so everything else is drawn above it.
   MBVisRect("P_CARD", x0, y0, w, 10, MBVisCard(), MBVisBorder(), false);
   MBVisRect("P_ACCENT", x0, y0, w, 3, MBVisGold(), MBVisGold(), false);
   G_MB_PANEL_Y = y0 + 12;

   // --- header ---
   MBVisText("P_BRAND", "SIRUS", x0 + 12, G_MB_PANEL_Y, MBVisGold(), PanelFontSize + 6, WatermarkFont, ANCHOR_LEFT_UPPER, false);
   MBVisText("P_BRAND2", "oltin ovchisi", x0 + 12 + (int)((PanelFontSize + 6) * 4.9), G_MB_PANEL_Y + 9, muted, PanelFontSize - 1, PanelFont, ANCHOR_LEFT_UPPER, false);

   string status = "OVDA";
   color status_tone = muted;
   if(G_BASKET_ORDERS > 0)                              { status = "SAVDODA";    status_tone = MBVisBlue(); }
   else if(StringFind(G_ENTRY_REASON, "veto") >= 0)     { status = "TAQIQ";      status_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)    { status = "POYLAMOQDA"; status_tone = MBVisAmber(); }
   else if(G_ENTRY_READY)                               { status = "NISHONDA";   status_tone = MBVisGreen(); }
   if(G_RISK_HARD_BLOCK)                                { status = "HIMOYA";     status_tone = MBVisRed(); }
   int pill_w = StringLen(status) * (PanelFontSize - 1) + 18;
   MBPanelPill("P_STATUS", status, x0 + w - 12 - pill_w, G_MB_PANEL_Y + 3, lh - 2, status_tone);
   G_MB_PANEL_Y += lh + 8;

   // --- account ---
   MBPanelSection("S_ACC", "KAPITAL", x0, w, lh);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double today = (G_RISK_DAY_START_EQUITY > 0.0) ? eq - G_RISK_DAY_START_EQUITY : 0.0;
   double hist_dd = MBHistoryMaxDDPercent();
   double max_dd = MathMax(hist_dd, G_ALL_TIME_MAX_DD_PCT);
   MBPanelLine("A1", StringFormat("Balans %10.2f    Equity %10.2f", bal, eq), ink, true, x0, w, lh);
   MBPanelLine("A2", StringFormat("Bugun  %+10.2f    Zarba  %4d (tezkor %d)", today, MBTodayEntries(), G_MB_FAST_TODAY),
               (today < 0.0 ? MBVisRed() : (today > 0.0 ? MBVisGreen() : ink)), true, x0, w, lh);
   MBPanelLine("A3", StringFormat("DD hozir %5.2f%%     Max DD %5.2f%%", G_RISK_EQUITY_DD_PCT, max_dd),
               DDSeverityColor(G_RISK_EQUITY_DD_PCT, EmergencyDDPercent * 0.3, EmergencyDDPercent * 0.6), true, x0, w, lh);
   MBPanelLine("A4", StringFormat("Eng chuqur DD: balans tarixida %.2f%%, ochiq savatda %.2f%%", hist_dd, G_ALL_TIME_MAX_DD_PCT),
               muted, false, x0, w, lh);

   // --- cashback (only in rebate mode) ---
   if(EnableRebateMode)
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
      int bar_x = x0 + 12 + StringLen(bias) * (PanelFontSize - 1) + 30;
      int bar_w = MathMax(40, w - (bar_x - x0) - 64);
      MBPanelBar("B_CONF", bar_x, G_MB_PANEL_Y + lh / 2 - 3, bar_w, G_MB_BIAS_CONF, tone);
      MBVisText("B_CONF_TX", StringFormat("ishonch %d%%", G_MB_BIAS_CONF), x0 + w - 12, G_MB_PANEL_Y + 1, muted, PanelFontSize - 1, PanelFont, ANCHOR_RIGHT_UPPER, false);
      G_MB_PANEL_Y += lh + 2;
      MBPanelLine("B_WHY", "Sabab: " + MBWhyUz(G_MB_BIAS_WHY), ink, false, x0, w, lh);
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
      MBPanelLine("B_TGT", StringFormat("Nishon %s  ·  G'oya chegarasi %s",
                                        (G_MB_TH_TARGET > 0.0 ? DoubleToString(G_MB_TH_TARGET, _Digits) : "-"),
                                        (G_MB_TH_INVALID > 0.0 ? DoubleToString(G_MB_TH_INVALID, _Digits) : "-")), muted, false, x0, w, lh);
   }
   else
      MBPanelLine("B_OFF", "Bozor miyasi o'chirilgan", muted, false, x0, w, lh);

   // --- entry ---
   MBPanelSection("S_ENTRY", "ZARBA LAHZASI", x0, w, lh);
   string dec = "NISHON YO'Q";
   color dec_tone = muted;
   if(StringFind(G_ENTRY_REASON, "veto") >= 0)           { dec = "TAQIQ";            dec_tone = MBVisRed(); }
   else if(StringFind(G_ENTRY_REASON, "judge") >= 0)     { dec = "POYLAMOQDA";       dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY && G_MB_ENTRY_DECISION == MB_ED_CAUTION) { dec = "EHTIYOTKOR ZARBA"; dec_tone = MBVisAmber(); }
   else if(G_ENTRY_READY)                                { dec = "ZARBA";            dec_tone = MBVisGreen(); }
   MBPanelPill("E_DEC", dec, x0 + 12, G_MB_PANEL_Y, lh - 2, dec_tone);
   int qx = x0 + 12 + StringLen(dec) * (PanelFontSize - 1) + 30;
   int qw = MathMax(40, w - (qx - x0) - 64);
   MBPanelBar("E_Q", qx, G_MB_PANEL_Y + lh / 2 - 3, qw, G_MB_ENTRY_QUALITY, dec_tone);
   MBVisText("E_Q_TX", StringFormat("sifat %d", G_MB_ENTRY_QUALITY), x0 + w - 12, G_MB_PANEL_Y + 1, muted, PanelFontSize - 1, PanelFont, ANCHOR_RIGHT_UPPER, false);
   G_MB_PANEL_Y += lh + 2;
   string why_txt = MBReasonUz(G_ENTRY_REASON);
   if(G_ENTRY_REASON == "score not passed" && G_OPP_DIR != OPP_DIR_NONE && G_SCORE_MIN_REQUIRED > 0)
      why_txt = StringFormat("%s signal kuchsiz: ball %d / kerak %d", (G_OPP_DIR == OPP_DIR_BUY ? "BUY" : "SELL"),
                             G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
   MBPanelLine("E_WHY", "Sabab: " + why_txt, ink, false, x0, w, lh);
   if(G_BASKET_ORDERS <= 0 && G_QUIET_BARS >= 5)
      MBPanelLine("E_QUIET", StringFormat("Jimlik %d daq  ·  %s", G_QUIET_BARS, MBGateTopUz(3)),
                  (G_QUIET_BARS >= 30 ? MBVisAmber() : muted), false, x0, w, lh);
   else
      MBPanelLine("E_QUIET", "To'siqlar bugun: " + MBGateTopUz(3), muted, false, x0, w, lh);
   string sh = MBShadowPanelText();
   if(StringLen(sh) > 0)
      MBPanelLine("E_SHADOW", sh, (StringFind(sh, "⚠") >= 0 ? MBVisAmber() : muted), false, x0, w, lh);

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
      if(G_MB_PB_DEAD) state = "G'oya yiqildi - grid to'xtadi, BE'da chiqamiz";
      else if(G_MB_PB_RESCUED) state = "Qutqaruv rejimi - yangi g'oya savat tomonida";
      MBPanelLine("K3", state, (G_MB_PB_DEAD ? MBVisAmber() : muted), false, x0, w, lh);
      MBPanelLine("K4", StringFormat("Keyingi grid: %.0f pt narida, lot %.2f", G_NEXT_GRID_DISTANCE, G_NEXT_GRID_LOT),
                  muted, false, x0, w, lh);
   }
   else
   {
      MBPanelLine("K1", "Savat bo'sh - keyingi o'lja poylanmoqda", muted, false, x0, w, lh);
      ObjectDelete(0, MB_VIS_PREFIX + "K2");
      ObjectDelete(0, MB_VIS_PREFIX + "K3");
      ObjectDelete(0, MB_VIS_PREFIX + "K4");
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

   // --- footer ---
   G_MB_PANEL_Y += 2;
   MBPanelLine("F1", StringFormat("spread %d  ·  server %s", G_LAST_SPREAD_POINTS, TimeToString(TimeTradeServer(), TIME_MINUTES)),
               muted, false, x0, w, lh);
   string prof = MBProfText();
   if(StringLen(prof) > 0)
      MBPanelLine("F2", prof, muted, false, x0, w, lh);

   // Size the card to what was drawn.
   ObjectSetInteger(0, MB_VIS_PREFIX + "P_CARD", OBJPROP_YSIZE, G_MB_PANEL_Y - y0 + 8);
   ChartRedraw(0);   // timer redraws otherwise wait for the next tick to show
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
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "N");
   ObjectsDeleteAll(0, MB_VIS_PREFIX + "C");
}

void MBDeleteAllVisuals()
{
   ObjectsDeleteAll(0, MB_VIS_PREFIX);
}
