//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 26b_Autopsy                                     |
//| Plan stage 7: trade memory (MFE / MAE / time to show), bad-entry |
//| autopsy with a classification, and the balance of bad entries    |
//| taken against good setups missed.                                |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// "What is Sirus wrong about most often?" - answered from the trades, not from a feeling. At every
// first entry the reading of every layer is kept (leg location, exhaustion, taken liquidity, the
// lock, the reversal stage, the bias, control, room ahead, spread, news). When the basket ends, a
// basket that did not end in profit - or that went a full TP against itself on the way - is opened
// up and labelled, most telling reason first:
//   QARSHI LOCK . KECH KIRISH . OLINGAN LIKVIDLIK . CHARCHASH E'TIBORSIZ . QARSHI ZONA .
//   TRENDGA QARSHI . NAZORAT QARSHI . SPREAD/YANGILIK . SOXTA SWEEP . VAQT (to'g'ri edi) .
//   NOTO'G'RI YO'NALISH . ANIQLANMADI
// One CSV row per basket (Sirus_Autopsy_<symbol>_<magic>.csv) with MFE, MAE, minutes to show and
// the snapshot; counters per label for the day; and the balance on the panel: bad entries taken
// (false positives) against refused setups that would have reached TP (false negatives, from the
// shadow ledger). Cutting one without watching the other is how the EA once fell to 3 trades a day.

input group "DIAGNOSTICS ▸ Trade autopsy"
// EnableAutopsy: Har savat yakunida: MFE / MAE / ko'rsatish vaqti va (yomon tugagan bo'lsa) xato turi - jurnal, CSV va panel
input bool   EnableAutopsy            = true;   // Enable autopsy
// AutopsyToFile: Sirus_Autopsy_<symbol>_<magic>.csv
input bool   AutopsyToFile            = true;   // Autopsy to file (on/off)

#define AU_TAGS 13
string   G_AU_TAG_UZ[AU_TAGS] = {"QARSHI LOCK", "KECH KIRISH", "OLINGAN LIKVIDLIK", "CHARCHASH E'TIBORSIZ", "QARSHI ZONA",
                                 "TRENDGA QARSHI", "NAZORAT QARSHI", "SPREAD/YANGILIK", "SOXTA SWEEP", "VAQT (to'g'ri edi)",
                                 "NOTO'G'RI YO'NALISH", "GRID MUZLADI", "ANIQLANMADI"};
int      G_AU_TODAY[AU_TAGS];
int      G_AU_BASKETS = 0;       // baskets ended today
int      G_AU_BAD     = 0;       // of them not in profit (false positives)
int      G_AU_DAY     = -1;
string   G_AU_LAST    = "";

// The snapshot taken at the first entry.
bool     G_AU_HAVE  = false;
datetime G_AU_OPEN  = 0;
int      G_AU_DIR   = 0;
string   G_AU_KIND  = "";
double   G_AU_LEGPCT = 0.0, G_AU_LEG15 = 0.0;
int      G_AU_EXH   = 0;
bool     G_AU_TAKEN = false;
int      G_AU_LOCK  = 0;
int      G_AU_STAGE = 0;
int      G_AU_A     = 0;
int      G_AU_CTRL  = 50;
double   G_AU_ROOM  = 0.0, G_AU_NEED = 0.0;
double   G_AU_SPR   = 0.0, G_AU_NORM = 0.0;
bool     G_AU_NEWS  = false;

void MBAutopsyDayRoll()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year == G_AU_DAY)
      return;
   // The day that ended, in one line: how many baskets went wrong and why.
   if(G_AU_DAY >= 0 && G_AU_BASKETS > 0)
   {
      string tl = "";
      for(int i = 0; i < AU_TAGS; i++)
         if(G_AU_TODAY[i] > 0) tl += StringFormat("%s%s %d", (StringLen(tl) > 0 ? ", " : ""), G_AU_TAG_UZ[i], G_AU_TODAY[i]);
      PrintFormat("[SIRUS AUTOPSY DAY] baskets %d, not in profit %d (%.0f%%) | %s", G_AU_BASKETS, G_AU_BAD,
                  100.0 * G_AU_BAD / G_AU_BASKETS, (StringLen(tl) > 0 ? tl : "-"));
   }
   G_AU_DAY = dt.day_of_year;
   ArrayInitialize(G_AU_TODAY, 0);
   G_AU_BASKETS = 0;
   G_AU_BAD = 0;
}

// Called by the first-entry engine (14) right after a fill.
void MBAutopsyOnEntry(const int dir)
{
   if(!EnableAutopsy || dir == 0)
      return;
   G_AU_HAVE = true;
   G_AU_OPEN = TimeCurrent();
   G_AU_DIR = dir;
   G_AU_KIND = G_MB_ENTRY_KIND;
   G_AU_LEGPCT = MBLegPct(dir, G_AU_LEG15);
   G_AU_EXH = MBExhaustPressure(dir);
   G_AU_TAKEN = G_LX_TAKEN[MBLxK(dir)];
   G_AU_LOCK = G_ST_LOCK_DIR;
   G_AU_STAGE = MBStructStageFor(dir);
   G_AU_A = dir * G_MB_BIAS;
   G_AU_CTRL = MBControlOf(dir);
   double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   G_AU_SPR = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   G_AU_NORM = MBNormalSpread();
   G_AU_ROOM = MBRoomAhead(dir, px);
   G_AU_NEED = G_AU_SPR + MBExpectedSlip() + BasketTPForOrderCount(1);
   G_AU_NEWS = G_CAL_ACTIVE;
}

// The labels of a basket that went wrong, most telling first.
string MBAutopsyTags(const int dir, const double mfe, const double tp, const int exit_kind, int &first)
{
   first = -1;
   string t = "";
   bool hit[AU_TAGS];
   for(int i = 0; i < AU_TAGS; i++) hit[i] = false;
   if(G_AU_HAVE)
   {
      hit[0] = (G_AU_LOCK == -dir);
      hit[1] = (G_AU_LEGPCT >= 70.0 && G_AU_LEG15 >= 1.5);
      hit[2] = G_AU_TAKEN;
      hit[3] = (G_AU_EXH >= ExhaustCautionScore);
      hit[4] = (G_AU_ROOM > 0.0 && G_AU_ROOM < 1.5 * G_AU_NEED);
      hit[5] = (G_AU_A <= -2 && G_AU_STAGE < MathMax(1, LockUnlockStage));
      hit[6] = (G_AU_CTRL <= 35);
      hit[7] = (G_AU_NEWS || (G_AU_NORM > 0.0 && G_AU_SPR >= 1.5 * G_AU_NORM));
      int k = MBLqSideIdx(-dir);
      hit[8] = ((StringFind(G_AU_KIND, "SWEEP") >= 0 || StringFind(G_AU_KIND, "REVERSAL") >= 0) &&
                G_LQ_SW_TRAP[k] && G_LQ_SW_TIME[k] >= G_AU_OPEN - 1800);
   }
   hit[9] = (tp > 0.0 && mfe >= 0.5 * tp);
   hit[10] = !hit[9] && (exit_kind == RE_INVALID || exit_kind == RE_LOSS) && (tp > 0.0 && mfe < 0.2 * tp);
   hit[11] = (G_PB_MAX_HOLD_MIN >= 30);   // the grid held this basket half an hour or more
   for(int i = 0; i < AU_TAGS - 1; i++)
   {
      if(!hit[i]) continue;
      if(first < 0) first = i;
      t += (StringLen(t) > 0 ? ", " : "") + G_AU_TAG_UZ[i];
   }
   if(first < 0)
   {
      first = AU_TAGS - 1;
      t = G_AU_TAG_UZ[first];
   }
   return t;
}

// Called by the Position Brain (24) when a basket ends - after the re-entry record (exit kind).
void MBAutopsyOnClose(const int dir, const double res, const double mfe, const double mae, const datetime opened, const datetime t_show)
{
   if(!EnableAutopsy || dir == 0)
      return;
   MBAutopsyDayRoll();
   double tp = BasketTPForOrderCount(1);
   bool bad = (G_RE_KIND != RE_PROFIT && G_RE_KIND != RE_LOCAL) || res < 0.0;
   bool deep = (tp > 0.0 && mae <= -1.0 * tp);
   G_AU_BASKETS++;
   if(bad) G_AU_BAD++;
   int mins = (int)((TimeCurrent() - opened) / 60);
   int show = (t_show > 0) ? (int)((t_show - opened) / 60) : -1;
   string tags = "";
   if(bad || deep)
   {
      int first = -1;
      tags = MBAutopsyTags(dir, mfe, tp, G_RE_KIND, first);
      if(first >= 0) G_AU_TODAY[first]++;
      G_AU_LAST = StringFormat("%s %s: %s", (dir > 0 ? "BUY" : "SELL"), MBReKindName(G_RE_KIND), tags);
      if(VerboseLogs)
         PrintFormat("[SIRUS AUTOPSY] %s basket %d min, %s %.2f | MFE %+.0f MAE %+.0f (TP %.0f) | %s | entry: %s, leg %.0f%%, exhaustion %d, control %d%%, room %.0f/%.0f",
                     (dir > 0 ? "BUY" : "SELL"), mins, MBReKindName(G_RE_KIND), res, mfe, mae, tp, tags,
                     (G_AU_HAVE ? G_AU_KIND : "-"), G_AU_LEGPCT, G_AU_EXH, G_AU_CTRL, G_AU_ROOM, G_AU_NEED);
   }
   if(AutopsyToFile && !MQLInfoInteger(MQL_OPTIMIZATION))
   {
      string name = StringFormat("Sirus_Autopsy_%s_%I64d.csv", _Symbol, MagicNumber);
      int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(h != INVALID_HANDLE)
      {
         if(FileSize(h) == 0)
            FileWriteString(h, "open;close;dir;entry_kind;exit;result;minutes;mfe_pts;mae_pts;tp_pts;min_to_show;labels;leg_pct;leg_atr15;exhaustion;taken_liq;lock;rev_stage;bias_align;control;room_pts;need_pts;spread;normal_spread;news\r\n");
         FileSeek(h, 0, SEEK_END);
         FileWriteString(h, StringFormat("%s;%s;%s;%s;%s;%.2f;%d;%.0f;%.0f;%.0f;%d;%s;%.0f;%.1f;%d;%d;%d;%d;%d;%d;%.0f;%.0f;%.0f;%.0f;%d\r\n",
                                         TimeToString(opened, TIME_DATE | TIME_MINUTES), TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                                         (dir > 0 ? "BUY" : "SELL"), (G_AU_HAVE ? G_AU_KIND : "-"), MBReKindName(G_RE_KIND), res, mins,
                                         mfe, mae, tp, show, tags, G_AU_LEGPCT, G_AU_LEG15, G_AU_EXH, (G_AU_TAKEN ? 1 : 0), G_AU_LOCK,
                                         G_AU_STAGE, G_AU_A, G_AU_CTRL, G_AU_ROOM, G_AU_NEED, G_AU_SPR, G_AU_NORM, (G_AU_NEWS ? 1 : 0)));
         FileClose(h);
      }
   }
   G_AU_HAVE = false;
}

string MBAutopsyPanelText()
{
   if(!EnableAutopsy)
      return "";
   MBAutopsyDayRoll();
   // False negatives from the shadow ledger: refused setups that would have reached TP.
   int bn = 0, btp = 0;
   for(int g = 0; g < GATE_COUNT; g++)
   {
      bn += G_SH_TALLY[g][MB_SH_TP] + G_SH_TALLY[g][MB_SH_GRID] + G_SH_TALLY[g][MB_SH_TIMEOUT];
      btp += G_SH_TALLY[g][MB_SH_TP];
   }
   int top = -1;
   for(int i = 0; i < AU_TAGS; i++)
      if(G_AU_TODAY[i] > 0 && (top < 0 || G_AU_TODAY[i] > G_AU_TODAY[top])) top = i;
   string t = StringFormat("Balans: noto'g'ri ochilgan %d/%d", G_AU_BAD, G_AU_BASKETS);
   if(G_AU_BASKETS > 0) t += StringFormat(" (%.0f%%)", 100.0 * G_AU_BAD / G_AU_BASKETS);
   t += StringFormat(" · o'tkazilgan yaxshi %d/%d", btp, bn);
   if(top >= 0) t += StringFormat(" · eng ko'p xato: %s ×%d", G_AU_TAG_UZ[top], G_AU_TODAY[top]);
   return t;
}
