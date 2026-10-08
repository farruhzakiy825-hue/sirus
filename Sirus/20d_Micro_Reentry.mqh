//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20d_Micro_Reentry                               |
//| Plan stage 4: who controls now (BUY% / SELL%), the micro turn    |
//| type against the primary direction, and re-entry intelligence.   |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// WHO CONTROLS NOW   from price behaviour, not indicators: liquidity taken for a side, the other side
//                    failing (its exhaustion pressure), displacement, M1 / M5 structure, M1 / M5
//                    pressure and tick flow, a higher low / lower high. Shown as BUY% / SELL%, with
//                    its change over the last three M5 bars (a falling share is the early warning).
// MICRO TURN         when the micro side opposes the primary one (the lock, else the bias, else M15),
//                    what kind of turn it is: NOISE (< 20% of the 6-hour range retraced), PULLBACK
//                    (20-45%), EXHAUSTION (the primary side's exhaustion pressure, or 45%+ with a
//                    displacement against it), REVERSAL (a mature reversal, or 60%+ with M5 structure
//                    turned). A buy candle is not a BUY; the judge weighs the turn type.
// RE-ENTRY           a closed basket is not a dead idea - and a dead idea is not a reason to re-enter:
//                    the exit kind is remembered (PROFIT / BE / INVALID / LOSS / LOCAL). After an
//                    INVALID or LOSS exit the same side waits for something new (a new M5+ break that
//                    way, a new thesis, or a mature reversal), at most ReentryCooldownMaxMin. Failed
//                    attempts per thesis are counted; ReentryMaxAttempts of them close that side until
//                    a new thesis (or two hours). The fast re-entry after a win goes at once (no bar wait),
//                    must not chase (within 1 ATR(M5) of the exit price) and must not have the control
//                    turned against it. A setup refused only for its place (late / chasing / a zone in
//                    front) gets a SECOND CHANCE when price comes back 0.5 ATR(M5) better.
//
// Speed: control and turn once per M1 bar; the rest is a few comparisons when an entry is asked for.

input group "BRAIN ▸ Market control & re-entry"
// EnableMicroControl: "Kim boshqaryapti": BUY% / SELL% va burilish turi (shovqin / pullback / charchash / reversal) - hakam sifatiga ta'sir qiladi
input bool   EnableMicroControl       = true;   // Enable micro control
// EnableSmartReentry: Qayta kirish aqli: chiqish sababi, urinishlar soni, "nima o'zgardi", quvmaslik
input bool   EnableSmartReentry       = true;   // Enable smart reentry
// ReentryMaxAttempts: Bitta g'oya bo'yicha shuncha muvaffaqiyatsiz savatdan keyin shu tomon yangi g'oyagacha (yoki 2 soat) yopiq
input int    ReentryMaxAttempts       = 3;   // Reentry max attempts
// ReentryCooldownMaxMin: G'oya o'lib / zararda yopilgandan keyin shu tomonga yangi dalil kutish (ko'pi bilan shuncha daqiqa)
input int    ReentryCooldownMaxMin    = 60;   // Reentry cooldown max min
// EnableSecondChance: Faqat joyi yomonligi uchun o'tkazilgan setup: narx 0.5 ATR(M5) yaxshiroq joyga qaytsa - BRAIN SECOND CHANCE
input bool   EnableSecondChance       = true;   // Enable second chance

#define MC_TURN_NONE      0
#define MC_TURN_NOISE     1
#define MC_TURN_PULLBACK  2
#define MC_TURN_EXHAUST   3
#define MC_TURN_REVERSAL  4

int      G_MC_BUY      = 50;     // control share, %
int      G_MC_SELL     = 50;
int      G_MC_HIST[4];           // BUY% at the last four M5 bars
int      G_MC_PRIMARY  = 0;
int      G_MC_MICRO    = 0;
int      G_MC_TURN     = MC_TURN_NONE;
double   G_MC_TURN_R   = 0.0;    // share of the 6-hour range retraced against the primary side
datetime G_MC_BAR      = 0;
datetime G_MC_BAR_M5   = 0;

#define RE_PROFIT   1
#define RE_BE       2
#define RE_INVALID  3
#define RE_LOSS     4
#define RE_LOCAL    5

int      G_RE_KIND   = 0;        // how the last basket ended
int      G_RE_DIR    = 0;
datetime G_RE_TIME   = 0;
double   G_RE_PX     = 0.0;
string   G_RE_REASON = "";
int      G_RE_ATT[2];            // failed attempts per side (0 SELL, 1 BUY) ...
datetime G_RE_ATT_TH[2];         // ... on this thesis (its start time, 0 = none)
datetime G_RE_ATT_T[2];          // last failure

string   G_LAST_CLOSE_WHY  = ""; // set by CloseSirusBasket via MBNoteCloseReason
datetime G_LAST_CLOSE_WHEN = 0;

int      G_SC_DIR  = 0;          // second chance: a setup refused only for its place
double   G_SC_PX   = 0.0;
datetime G_SC_TIME = 0;
string   G_SC_WHY  = "";

string MBTurnName(const int t)
{
   switch(t)
   {
      case MC_TURN_NOISE:    return "SHOVQIN";
      case MC_TURN_PULLBACK: return "PULLBACK";
      case MC_TURN_EXHAUST:  return "CHARCHASH";
      case MC_TURN_REVERSAL: return "REVERSAL";
   }
   return "-";
}

string MBReKindName(const int k)
{
   switch(k)
   {
      case RE_PROFIT:  return "foyda";
      case RE_BE:      return "BE";
      case RE_INVALID: return "g'oya o'ldi";
      case RE_LOSS:    return "zarar";
      case RE_LOCAL:   return "lokal";
   }
   return "-";
}

// Evidence that side d controls the tape right now (points, unbounded above ~100).
int MBMcSide(const int d)
{
   int p = 0;
   datetime lt = 0;
   int lc = 0, lq = 0;
   double le = 0.0;
   if(MBLqSweepFor(d, 1, 3600, lt, lc, le, lq)) p += (lc >= 3) ? 20 : 12;
   else if(G_MB_LSW_DIR == d && TimeCurrent() - G_MB_LSW_TIME <= 600) p += 12;
   p += MathMin(20, G_LX_PRESS[MBLxK(-d)] / 4);                       // the other side failing
   if(G_MB_LIVE_DIR == d) p += 8;
   if(G_MB_LAST[1].intent == MB_CI_DISPLACEMENT && G_MB_LAST[1].dir == d) p += 15;
   else if(G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == d) p += 8;
   if(G_MB_TREND[0] == d) p += 10;
   if(G_MB_TREND[1] == d) p += 10;
   if(MBPressureSide(0) == d) p += 5;
   if(MBPressureSide(1) == d) p += 8;
   if(EnableTickFlow && G_MB_FLOW_N >= 20 && d * G_MB_FLOW_IMB >= 0.2) p += 5;
   if(MBStructStageFor(d) >= 5) p += 10;                              // higher low / lower high made
   return p;
}

void MBMicroUpdate()
{
   if(!EnableMicroControl || !EnableMarketBrainEngines)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 <= 0 || m1 == G_MC_BAR)
      return;
   G_MC_BAR = m1;
   int b = MBMcSide(1), s = MBMcSide(-1);
   G_MC_BUY = (b + s > 0) ? (int)MathRound(100.0 * b / (b + s)) : 50;
   G_MC_SELL = 100 - G_MC_BUY;
   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 > 0 && m5 != G_MC_BAR_M5)
   {
      G_MC_BAR_M5 = m5;
      for(int h = 3; h > 0; h--) G_MC_HIST[h] = G_MC_HIST[h - 1];
      G_MC_HIST[0] = G_MC_BUY;
   }

   G_MC_PRIMARY = (G_ST_LOCK_DIR != 0) ? G_ST_LOCK_DIR : ((MBSign(G_MB_BIAS) != 0) ? MBSign(G_MB_BIAS) : G_MB_TREND[2]);
   G_MC_MICRO = (G_MC_BUY >= 60) ? 1 : ((G_MC_BUY <= 40) ? -1 : 0);
   G_MC_TURN = MC_TURN_NONE;
   G_MC_TURN_R = 0.0;
   int P = G_MC_PRIMARY;
   if(P == 0 || G_MC_MICRO != -P)
      return;
   int m = -P;
   double hi6 = G_LX_ORIGIN[0], lo6 = G_LX_ORIGIN[1];   // the six-hour high and low
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(hi6 <= lo6 || px <= 0.0)
      return;
   G_MC_TURN_R = (P < 0) ? (px - lo6) / (hi6 - lo6) : (hi6 - px) / (hi6 - lo6);
   double dl = 0.0;
   bool disp_m = (MBStFind(3, m, 1, 1, TimeCurrent() - 900, false, dl) > 0);
   int st_m = MBStructStageFor(m);
   if(st_m >= MathMax(1, LockUnlockStage) || (G_MC_TURN_R >= 0.60 && (G_MB_TREND[1] == m || st_m >= 3)))
      G_MC_TURN = MC_TURN_REVERSAL;
   else if(G_LX_PRESS[MBLxK(P)] >= ExhaustCautionScore || (G_MC_TURN_R >= 0.45 && disp_m))
      G_MC_TURN = MC_TURN_EXHAUST;
   else if(G_MC_TURN_R >= 0.20)
      G_MC_TURN = MC_TURN_PULLBACK;
   else
      G_MC_TURN = MC_TURN_NOISE;
}

// The control share of dir, %.
int MBControlOf(const int dir) { return (dir > 0) ? G_MC_BUY : G_MC_SELL; }

// Judge quality from the control and the turn type.
int MBMicroQualityAdj(const int dir)
{
   if(!EnableMicroControl || dir == 0 || G_MC_BAR <= 0)
      return 0;
   int adj = 0;
   int own = MBControlOf(dir);
   if(own <= 30)      adj -= 10;
   else if(own >= 65) adj += 5;
   int P = G_MC_PRIMARY;
   if(P != 0 && G_MC_TURN != MC_TURN_NONE)
   {
      if(dir == P)
         adj += (G_MC_TURN == MC_TURN_PULLBACK) ? 6 : ((G_MC_TURN == MC_TURN_EXHAUST) ? -8 : ((G_MC_TURN == MC_TURN_REVERSAL) ? -15 : 0));
      else
         adj += (G_MC_TURN == MC_TURN_NOISE) ? -10 : ((G_MC_TURN == MC_TURN_PULLBACK) ? -5 : ((G_MC_TURN == MC_TURN_REVERSAL) ? 8 : 0));
   }
   return adj;
}

//---------------------------------------------------------------------
// RE-ENTRY
//---------------------------------------------------------------------
// CloseSirusBasket (12) leaves its reason here; a basket closed by the broker (TP / SL) leaves none.
void MBNoteCloseReason(const string why)
{
   G_LAST_CLOSE_WHY = why;
   G_LAST_CLOSE_WHEN = TimeCurrent();
}

// Called by the Position Brain when a basket ends.
void MBReExitRecord(const int dir, const double res)
{
   if(dir == 0)
      return;
   string r = (TimeCurrent() - G_LAST_CLOSE_WHEN <= 120) ? G_LAST_CLOSE_WHY : (res > 0.0 ? "broker TP" : "broker SL");
   G_LAST_CLOSE_WHEN = 0;   // AUDIT FIX: used once - a later broker close must not inherit this reason
   int kind = RE_PROFIT;
   if(StringFind(r, "thesis dead") >= 0)                         kind = RE_INVALID;
   else if(StringFind(r, "SMART EXIT") >= 0 || res < 0.0)        kind = RE_LOSS;
   else if(StringFind(r, "local") >= 0)                          kind = RE_LOCAL;
   else if(StringFind(r, "break-even") >= 0)                     kind = RE_BE;
   G_RE_KIND = kind;
   G_RE_DIR = dir;
   G_RE_TIME = TimeCurrent();
   G_RE_PX = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   G_RE_REASON = r;
   int k = (dir > 0) ? 1 : 0;
   datetime th = (G_MB_TH_DIR == dir) ? G_MB_TH_SINCE : 0;
   if(kind == RE_PROFIT)
      G_RE_ATT[k] = 0;
   else
   {
      if(G_RE_ATT_TH[k] != th) { G_RE_ATT[k] = 0; G_RE_ATT_TH[k] = th; }
      G_RE_ATT[k]++;
      G_RE_ATT_T[k] = TimeCurrent();
   }
   if(VerboseLogs && StructurePrintOnUse)
      PrintFormat("[SIRUS REENTRY] %s basket ended: %s (%s) | failed attempts on this thesis: %d",
                  (dir > 0 ? "BUY" : "SELL"), MBReKindName(kind), r, G_RE_ATT[k]);
}

// True = no new entry toward dir yet (after a dead idea, or too many failed attempts on one thesis).
bool MBReentryBlocks(const int dir, string &why, string &uz)
{
   why = "";
   uz = "";
   if(!EnableSmartReentry || dir == 0)
      return false;
   if(G_RE_DIR == dir && (G_RE_KIND == RE_INVALID || G_RE_KIND == RE_LOSS) &&
      TimeCurrent() - G_RE_TIME < (long)MathMax(1, ReentryCooldownMaxMin) * 60)
   {
      double lv = 0.0;
      bool new_break = (MBStFind(1, dir, 1, 4, G_RE_TIME + 1, false, lv, true) > 0);   // by bar close (AUDIT FIX B6)
      bool new_thesis = (G_MB_TH_DIR == dir && G_MB_TH_SINCE > G_RE_TIME);
      bool reversal = (MBStructStageFor(dir) >= MathMax(1, LockUnlockStage));
      if(!(new_break || new_thesis || reversal))
      {
         why = StringFormat("re-entry: the last %s basket ended '%s' %d min ago - waiting for something new (a new break, thesis or reversal)",
                            (dir > 0 ? "BUY" : "SELL"), MBReKindName(G_RE_KIND), (int)((TimeCurrent() - G_RE_TIME) / 60));
         uz = StringFormat("%s - yangi dalil kutilmoqda", MBReKindName(G_RE_KIND));
         return true;
      }
   }
   int k = (dir > 0) ? 1 : 0;
   datetime th = (G_MB_TH_DIR == dir) ? G_MB_TH_SINCE : 0;
   if(ReentryMaxAttempts > 0 && G_RE_ATT[k] >= ReentryMaxAttempts && G_RE_ATT_TH[k] == th && TimeCurrent() - G_RE_ATT_T[k] < 7200)
   {
      why = StringFormat("re-entry: %d failed %s baskets on this thesis - waiting for a new one", G_RE_ATT[k], (dir > 0 ? "BUY" : "SELL"));
      uz = StringFormat("%d urinish - yangi g'oya kerak", G_RE_ATT[k]);
      return true;
   }
   return false;
}

// The fast re-entry after a win: something new (a bar closed since), not chasing, control not turned.
bool MBReentryFastOk(const int dir)
{
   if(!EnableSmartReentry)
      return true;
   // OWNER RULE (speed): after a TP the next entry goes at once when the signal is there - no waiting
   // for a new bar. Only after a non-profit exit must something new (a closed bar) come first.
   if(G_RE_KIND != RE_PROFIT && G_RE_TIME > 0 && iTime(_Symbol, PERIOD_M1, 1) < G_RE_TIME)
      return false;
   double atr5 = G_MB_ATR[1] * _Point;
   double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   if(atr5 > 0.0 && G_RE_PX > 0.0 && dir * (px - G_RE_PX) > 1.0 * atr5)
      return false;
   if(EnableMicroControl && MBControlOf(dir) < 40)
      return false;
   return true;
}

// A refused setup - remembered for a second chance only when its PLACE was the reason.
void MBMissedNote(const int dir, const string reason)
{
   if(!EnableSecondChance || dir == 0)
      return;
   bool place = (StringFind(reason, "late entry") >= 0 || StringFind(reason, "chasing") >= 0 ||
                 StringFind(reason, "right in front") >= 0 || StringFind(reason, "entry quality") >= 0);
   if(!place)
      return;
   if(G_SC_DIR == dir && TimeCurrent() - G_SC_TIME <= 300)
      return;   // keep the first refusal of the run as the reference price
   G_SC_DIR = dir;
   G_SC_PX = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   G_SC_TIME = TimeCurrent();
   G_SC_WHY = reason;
}

// Price came back to a better place for the refused setup: true with a short reason.
bool MBSecondChanceNow(int &dir, string &why)
{
   dir = 0;
   why = "";
   if(!EnableSecondChance || G_SC_DIR == 0)
      return false;
   double atr5 = G_MB_ATR[1] * _Point;
   double px = SymbolInfoDouble(_Symbol, (G_SC_DIR > 0 ? SYMBOL_ASK : SYMBOL_BID));
   if(TimeCurrent() - G_SC_TIME > 1800 || atr5 <= 0.0 || px <= 0.0 || MathAbs(px - G_SC_PX) > 3.0 * atr5)
   {
      G_SC_DIR = 0;
      return false;
   }
   double better = G_SC_DIR * (G_SC_PX - px);   // a BUY lower, a SELL higher
   if(better < 0.5 * atr5)
      return false;
   dir = G_SC_DIR;
   why = StringFormat("refused %d min ago for its place, now %.1f ATR(M5) better", (int)((TimeCurrent() - G_SC_TIME) / 60), better / atr5);
   return true;
}

void MBSecondChanceTaken() { G_SC_DIR = 0; }

string MBMicroPanelText()
{
   string t = "";
   if(EnableMicroControl && G_MC_BAR > 0)
   {
      int d3 = G_MC_BUY - G_MC_HIST[3];
      string tr = (G_MC_HIST[3] > 0 && d3 >= 15) ? " ↑" : ((G_MC_HIST[3] > 0 && d3 <= -15) ? " ↓" : "");
      t = StringFormat("Nazorat: BUY %d%% / SELL %d%%%s", G_MC_BUY, G_MC_SELL, tr);
      if(G_MC_TURN != MC_TURN_NONE)
         t += StringFormat(" · burilish: %s (%.0f%%)", MBTurnName(G_MC_TURN), G_MC_TURN_R * 100.0);
   }
   if(EnableSmartReentry && G_RE_KIND != 0 && TimeCurrent() - G_RE_TIME <= 7200)
      t += StringFormat("%soxirgi savat %s: %s", (StringLen(t) > 0 ? " · " : ""), (G_RE_DIR > 0 ? "BUY" : "SELL"), MBReKindName(G_RE_KIND));
   return t;
}
