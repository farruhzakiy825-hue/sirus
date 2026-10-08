//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 24_Position_Brain                               |
//| Market Brain G: smart grid, thesis monitor, break-even exit      |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// POSITION BRAIN (engine plan, phase 7)
//---------------------------------------------------------------------
// "I opened a BUY, so BUY must be right" is how a recoverable basket becomes one that is not.
// After a basket opens, its thesis is watched:
//
//   DEAD when, after the basket opened, the market confirms the other side:
//     - a confirmed liquidity reversal against it (sweep / fake break on M5+ plus displacement,
//       MSS/BOS or reclaim), or
//     - an MSS or a genuine break (acceptance) against it on M15 and above, or
//     - the Market Brain thesis in the basket's direction was invalidated.
//   Then:  no more averaging into the dead direction, and the basket target drops to break-even
//          (plus a small cover) - the first time price comes back, it is closed without loss.
//          No hedge, no partial closing of a losing basket; the Basket SL stays the last line.
//
//   RESCUE when, after it died, a NEW thesis in the basket's direction appears (a confirmed
//   liquidity reversal back toward it, or a new Market Brain thesis that way): additions are
//   allowed again and the basket's normal target returns.
//
//   SMART GRID while the thesis lives: reaching the grid distance is not enough. The addition
//   needs the market to respond at that price - a rejection, liquidity grab, displacement or
//   fresh sweep/reclaim in the basket's direction. A displacement or a genuine break AGAINST the
//   basket holds the addition even at full distance. With no response either way the addition
//   waits up to MBGridResponseMaxBars, then goes in (the recovery is delayed, never abandoned).
//=====================================================================

input group "BRAIN ▸ Position brain (smart grid & exits)"
// EnableMBPositionBrain: Ochiq savat thesis'ini kuzatish: o'lsa grid to'xtaydi va savat break-even'da yopiladi
input bool   EnableMBPositionBrain    = true;   // Enable mb position brain
// MBGridNeedsResponse: Grid faqat zonada sham reaksiyasi bo'lsa qo'shiladi (qarshi displacement / break'da qo'shilmaydi)
input bool   MBGridNeedsResponse      = true;   // Brain grid needs response (on/off)
// MBGridResponseMaxBars: Reaksiya bo'lmasa ko'pi bilan shuncha M1 bar kutadi, keyin qo'shadi
input int    MBGridResponseMaxBars    = 15;   // Brain grid response max bars
// MBBreakEvenCoverPoints: Thesis o'lganda savat shu punkt foyda bilan yopiladi (break-even + qoplama)
input int    MBBreakEvenCoverPoints   = 30;   // Brain break even cover points
// MBPositionPrintOnUse: Thesis o'limi / qutqaruv / grid kutishini jurnalga yozish ([SIRUS POSITION])
input bool   MBPositionPrintOnUse     = true;   // Brain position print on use (on/off)
// EnableRecoveryJudge: 16-BOSQICH: AQLLI CHIQISH. DD shu % dan oshganda "savat qutqarilishi mumkinmi?" baholanadi: IMKON BOR - 50% gacha ushlanadi, SHUBHALI - grid yo'q + BE da chiqish, IMKONSIZ - savat yopiladi
input bool   EnableRecoveryJudge      = true;   // Enable recovery judge
// RecoveryStartDD: Baholash shu DD % (balansdan) dan boshlanadi
input double RecoveryStartDD          = 25.0;   // Recovery start DD
// RecoveryPersistBars: IMKONSIZ holati shuncha M1 bar saqlansa - chiqish qurollanadi
input int    RecoveryPersistBars      = 3;   // Recovery persist bars
// RecoveryBounceATR: Qurollangandan keyin narx savat foydasiga ATR(M1) x shu qaytsa - o'sha qaytishda yopiladi
input double RecoveryBounceATR        = 0.3;   // Recovery bounce ATR
// RecoveryWorsenDD: Qurollangandan keyin DD yana shuncha % oshsa - darhol yopiladi
input double RecoveryWorsenDD         = 3.0;   // Recovery worsen DD
// RecoveryZoneATR15: Qutqaruv joyi (zona / FVG) savat foydasiga shuncha ATR(M15) ichida bo'lsa - "imkon bor" belgisi
input double RecoveryZoneATR15        = 1.5;   // Recovery zone ATR 15
// EnableGridAtStructure: Grid pog'onasi narx tuzilmaga (zona / FVG / likvidlik) yetganda qo'yiladi; havoda - javob kutish vaqti ichida kutadi
input bool   EnableGridAtStructure    = true;   // Enable grid at structure
// GridStructureATR5: Tuzilma narxdan ATR(M5) x shu ichida bo'lsa - "tuzilmada"
input double GridStructureATR5        = 0.5;   // Grid structure ATR 5
// GridReserveRungs: Oxirgi shuncha pog'ona ZAXIRA: faqat tuzilma + qarshi harakat charchagan + sham javobi bo'lsa (vaqt bilan ochilmaydi)
input int    GridReserveRungs         = 2;   // Grid reserve rungs
// RecoveryLogToFile: Chuqur savatlar natijasini CSV ga yozish (Sirus_Recovery_<symbol>_<magic>.csv)
input bool   RecoveryLogToFile        = true;   // Recovery log to file (on/off)
// RunnerMinStepPoints: Kuzatish masofasi kamida shuncha (amalda max(shu, ATR(M5) x 0.5))
input int    RunnerMinStepPoints      = 300;   // Runner min step points
// RunnerFarTPMult: Uzoq maqsad: TP x shu yoki likvidlik maqsadi (DOL), qaysi yaqin bo'lsa
input double RunnerFarTPMult          = 2.5;   // Runner far TP multiplier
// RunnerMaxOrders: Shundan ko'p orderli savat yugurmaydi
input int    RunnerMaxOrders          = 2;   // Runner max orders
// RunnerStallMinutes: Yangi cho'qqi shuncha daqiqa bo'lmasa - yopiladi
input int    RunnerStallMinutes       = 10;   // Runner stall minutes
// EnableExpectationCheck: 5-BOSQICH: KUTILGAN vs HAQIQIY - savat ExpectMinutes ichida TP ning ExpectTPShare qismiga yetmasa VA bozor unga qarshi o'girilsa (nazorat / charchash) - BE + qoplamada yopiladi (zararga emas)
input bool   EnableExpectationCheck   = true;   // Enable expectation check
// ExpectMinutes: Shu daqiqada savat o'zini ko'rsatishi kerak
input int    ExpectMinutes            = 20;   // Expect minutes
// ExpectTPShare: ... TP ning shuncha qismi (eng yaxshi nuqtasi)
input double ExpectTPShare            = 0.35;   // Expect TP share
// EnableGridLiability: 5-BOSQICH: GRID JAVOBGARLIGI - yangi pog'onadan keyingi BE kuchli likvidlik (H4 / PD) ortida qolsa pog'ona qo'yilmaydi (qarshi harakat charchamaguncha); H1 darajasi ortida - zaxira pog'onadek (tuzilma + javob + charchash)
input bool   EnableGridLiability      = true;   // Enable grid liability
// GridHoldOnCandlesAgainst: M5 va M15 shamlari savatga qarshi bosayotgan bo'lsa (harakat charchamagan) - grid qo'shilmaydi
input bool   GridHoldOnCandlesAgainst = true;   // Grid hold on candles against (on/off)
// EnableStaleBasketBE: Uzoq DD dan qaytgan savat: shamlar uning tomonida bo'lmasa break-even + qoplamada yopiladi (zararga yopmaydi)
input bool   EnableStaleBasketBE      = true;   // Enable stale basket BE
// StaleBasketMinutes: Savat shuncha daqiqadan beri ochiq bo'lsa ...
input int    StaleBasketMinutes       = 90;   // Stale basket minutes
// StaleBasketMinDD: ... va DD kamida shuncha % bo'lgan bo'lsa
input double StaleBasketMinDD         = 8.0;   // Stale basket min DD

datetime G_MB_PB_BASKET    = 0;     // open time of the first position of the watched basket
int      G_MB_PB_DIR       = 0;
bool     G_MB_PB_DEAD      = false;
datetime G_MB_PB_DEAD_TIME = 0;
string   G_MB_PB_DEAD_WHY  = "";
bool     G_MB_PB_RESCUED   = false;
int      G_MB_PB_WAIT_ORDERS = -1;  // grid response wait: rung being held
datetime G_MB_PB_CHECK_BAR   = 0;   // M1 bar of the last death / rescue check
datetime G_MB_PB_WAIT_LAST   = 0;   // last time the grid asked for this rung
bool     G_MB_PB_LOCAL       = false; // opened against the global bias (a local leg)
double   G_PB_MFE            = 0.0;   // plan stage 5: best basket points so far
double   G_PB_MAE            = 0.0;   // plan stage 7: worst basket points so far
datetime G_PB_T_SHOW         = 0;     // plan stage 7: when the basket first showed ExpectTPShare of its TP
int      G_PB_MAX_HOLD_MIN   = 0;     // grid rescue: the longest the grid held this basket (minutes)
bool     G_PB_EXP_FAIL       = false; // the basket did not do what it was opened for, and the tape turned
string   G_PB_EXP_WHY        = "";
datetime G_MB_PB_WAIT_SINCE  = 0;

// Stage 16: Recovery Judge state for the open basket.
#define MB_RC_NONE        0
#define MB_RC_POSSIBLE    1
#define MB_RC_DOUBTFUL    2
#define MB_RC_IMPOSSIBLE  3
int      G_MB_RC_STATE    = MB_RC_NONE;
int      G_MB_RC_NEG      = 0;
int      G_MB_RC_POS      = 0;
string   G_MB_RC_WHY      = "";
int      G_MB_RC_PERSIST  = 0;
datetime G_MB_RC_BAR      = 0;
bool     G_MB_RC_ARMED    = false;   // IMPOSSIBLE held long enough - waiting for the exit moment
double   G_MB_RC_ARM_DD   = 0.0;
double   G_MB_RC_WORST    = 0.0;     // worst price since armed
double   G_MB_RC_PEAK_DD  = 0.0;     // deepest DD of this basket
int      G_MB_RC_WORST_STATE = MB_RC_NONE;

// AUDIT FIX: the basket's judgement survives a terminal restart or an input change. Saved in terminal
// global variables keyed by the basket's open time; restored only for that same basket.
string MBPBKey(const string f)
{
   return StringFormat("SIRUS_PB_%s_%I64d_%s", _Symbol, MagicNumber, f);
}

void MBRecoverySave()
{
   if(G_MB_PB_BASKET == 0 || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   GlobalVariableSet(MBPBKey("BASKET"), (double)G_MB_PB_BASKET);
   GlobalVariableSet(MBPBKey("DEAD"), G_MB_PB_DEAD ? 1.0 : 0.0);
   GlobalVariableSet(MBPBKey("DEADT"), (double)G_MB_PB_DEAD_TIME);
   GlobalVariableSet(MBPBKey("PEAK"), G_MB_RC_PEAK_DD);
   GlobalVariableSet(MBPBKey("ARMED"), G_MB_RC_ARMED ? 1.0 : 0.0);
   GlobalVariableSet(MBPBKey("ARMDD"), G_MB_RC_ARM_DD);
   GlobalVariableSet(MBPBKey("WORSTST"), (double)G_MB_RC_WORST_STATE);
}

void MBRecoveryRestore(const datetime opened)
{
   if(!GlobalVariableCheck(MBPBKey("BASKET")) || (datetime)GlobalVariableGet(MBPBKey("BASKET")) != opened)
      return;
   G_MB_PB_DEAD = (GlobalVariableGet(MBPBKey("DEAD")) > 0.5);
   G_MB_PB_DEAD_TIME = (datetime)GlobalVariableGet(MBPBKey("DEADT"));
   if(G_MB_PB_DEAD) G_MB_PB_DEAD_WHY = "restored after restart";
   G_MB_RC_PEAK_DD = GlobalVariableGet(MBPBKey("PEAK"));
   G_MB_RC_ARMED = (GlobalVariableGet(MBPBKey("ARMED")) > 0.5);
   G_MB_RC_ARM_DD = GlobalVariableGet(MBPBKey("ARMDD"));
   G_MB_RC_WORST_STATE = (int)GlobalVariableGet(MBPBKey("WORSTST"));
   G_MB_RC_WORST = (G_MB_PB_DIR > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if((MBPositionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS POSITION] basket state restored: dead %s, peak DD %.1f%%, exit armed %s",
                  (G_MB_PB_DEAD ? "yes" : "no"), G_MB_RC_PEAK_DD, (G_MB_RC_ARMED ? "yes" : "no"));
}

void MBRecoveryForget()
{
   GlobalVariableDel(MBPBKey("BASKET"));
   GlobalVariableDel(MBPBKey("DEAD"));
   GlobalVariableDel(MBPBKey("DEADT"));
   GlobalVariableDel(MBPBKey("PEAK"));
   GlobalVariableDel(MBPBKey("ARMED"));
   GlobalVariableDel(MBPBKey("ARMDD"));
   GlobalVariableDel(MBPBKey("WORSTST"));
}

// Open time of the oldest position of this EA's basket, 0 when flat.
datetime MBBasketOpenTime()
{
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldest)
         oldest = t;
   }
   return oldest;
}

// Direction of this EA's open basket from the positions themselves (+1 / -1, 0 when flat or mixed).
int MBBasketDirReal()
{
   int d = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      int pd = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(d == 0) d = pd;
      else if(d != pd) return 0;
   }
   return d;
}

// Why the basket's thesis is dead, or "" when it is not.
string MBBasketDeathReason(const int dir, const datetime since)
{
   string what = "";
   datetime swt = 0;
   if(MBReversalAfter(-dir, 1, 4, true, since, what, swt))
      return "confirmed liquidity reversal against it: " + what;

   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != -dir) continue;
      if(G_MB_EV[idx].time + PeriodSeconds(MBEventTF(G_MB_EV[idx].tfi)) <= since) continue;   // AUDIT FIX: bar close vs basket open
      if(MBEventRank(G_MB_EV[idx].tfi) < 2) continue;
      int ty = G_MB_EV[idx].type;
      if(ty == MB_EV_MSS || ty == MB_EV_ACCEPTANCE)
         return StringFormat("%s %s against it @ %s", MBTFName(G_MB_EV[idx].tfi), MBEventName(ty),
                             DoubleToString(G_MB_EV[idx].level, _Digits));
   }

   datetime th_died = G_MB_DEAD_TIME;
   if(EnableMarketBrain && G_MB_TH_DIR == dir && G_MB_TH_STATE == MB_TH_INVALIDATED && th_died > since)
      return StringFormat("Market Brain %s thesis invalidated (beyond %s)", (dir > 0 ? "bullish" : "bearish"),
                          DoubleToString(G_MB_TH_INVALID, _Digits));
   return "";
}

//---------------------------------------------------------------------
// STAGE 16 (E1): RECOVERY JUDGE - "can this basket still be saved?"
//---------------------------------------------------------------------
// From RecoveryStartDD the question changes from "how much is it losing" to "can it still come
// back". Nine readings, each for or against. The number against that is enough to give up falls as
// the drawdown deepens; below 35% it must include the thesis being dead or threatened, or a
// confirmed liquidity reversal against the basket. A full five-rung ladder reaches 33-41% by design,
// so a basket is only given up when the evidence that it cannot come back is broad.
string MBRecoveryStateName(const int st)
{
   switch(st)
   {
      case MB_RC_POSSIBLE:   return "POSSIBLE";
      case MB_RC_DOUBTFUL:   return "DOUBTFUL";
      case MB_RC_IMPOSSIBLE: return "IMPOSSIBLE";
   }
   return "-";
}

// Structure on the basket's side close to price: a zone or an unfilled FVG within `reach`.
bool MBStructureNear(const int dir, const double price, const double reach, string &what)
{
   what = "";
   double z = (dir > 0) ? ZoneMapNearestSupport(price) : ZoneMapNearestResistance(price);
   if(z > 0.0 && MathAbs(price - z) <= reach)
   {
      what = StringFormat("zone %s", DoubleToString(z, _Digits));
      return true;
   }
   double g = (dir > 0) ? FVGNearestSupport(price) : FVGNearestResistance(price);
   if(g > 0.0 && MathAbs(price - g) <= reach)
   {
      what = StringFormat("FVG %s", DoubleToString(g, _Digits));
      return true;
   }
   return false;
}

// The move against the basket is spent (late, expired or showing exhaustion).
bool MBAdverseSpent(const int dir)
{
   string w = "";
   if(MBExhausted(-dir, w))
      return true;
   return (G_MB_IMP_DIR[1] == -dir && G_MB_SPEED[1] >= MB_SPEED_LATE) ||
          (G_MB_IMP_DIR[0] == -dir && G_MB_SPEED[0] >= MB_SPEED_EXPIRED);
}

void MBRecoveryEvaluate(const int dir, const datetime opened)
{
   double dd = G_BASKET_DD_PERCENT;
   G_MB_RC_PEAK_DD = MathMax(G_MB_RC_PEAK_DD, dd);
   // AUDIT FIX: a thesis back on the basket's side cancels a pending exit - checked before the DD
   // early return, so a basket that recovered above RecoveryStartDD is released too.
   if(G_MB_RC_ARMED && G_MB_TH_DIR == dir && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED) &&
      !G_MB_TH_THREAT && dir * G_MB_BIAS >= 1)
   {
      G_MB_RC_ARMED = false;
      G_MB_RC_PERSIST = 0;
      MBRecoverySave();
      if((MBPositionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS RECOVERY] exit cancelled - a %s thesis is back on the basket's side", (dir > 0 ? "bullish" : "bearish"));
   }
   if(!EnableRecoveryJudge || dd < RecoveryStartDD)
   {
      if(G_MB_RC_STATE != MB_RC_NONE && !G_MB_RC_ARMED)
      {
         G_MB_RC_STATE = MB_RC_NONE;
         G_MB_RC_PERSIST = 0;
         G_MB_RC_WHY = "";
      }
      return;
   }
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 == G_MB_RC_BAR)
      return;
   G_MB_RC_BAR = m1;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px = (dir > 0) ? bid : ask;
   double atr15 = ((G_MB_ATR[2] > 0.0) ? G_MB_ATR[2] : G_MB_ATR[1] * 2.0) * _Point;
   if(px <= 0.0 || atr15 <= 0.0)
      return;

   int neg = 0, pos = 0;
   bool key = false;
   string wn = "", wp = "";

   // 1. Thesis.
   bool th_alive = (G_MB_TH_DIR == dir && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED) && !G_MB_TH_THREAT);
   if(G_MB_PB_DEAD)
   { neg++; key = true; wn += "thesis dead; "; }
   else if(G_MB_TH_DIR == dir && G_MB_TH_THREAT)
   { neg++; wn += "thesis threatened; "; }   // a warning, not proof - it does not count as the key reading
   else if(th_alive) { pos++; wp += "thesis alive; "; }
   // 2. Brain bias.
   int a = dir * G_MB_BIAS;
   if(a <= -2) { neg++; wn += "brain strongly against; "; }
   else if(a >= 1) { pos++; wp += "brain with it; "; }
   // 3. Confirmed liquidity reversal against it on M15+ since it opened.
   string rv = "";
   datetime rvt = 0;
   if(MBReversalAfter(-dir, 2, 4, true, opened, rv, rvt)) { neg++; key = true; wn += "reversal against: " + rv + "; "; }
   // 4. The move against it: still running, or spent.
   if(MBAdverseSpent(dir)) { pos++; wp += "adverse move spent; "; }
   else if((G_MB_IMP_DIR[1] == -dir && G_MB_SPEED[1] <= MB_SPEED_NORMAL) || (G_MB_ACCEL[1] > 0 && G_MB_ACCEL_DIR[1] == -dir))
   { neg++; wn += "adverse move still fresh; "; }
   // 5. A place to be rescued from.
   string sw = "";
   double px_in = (dir > 0) ? ask : bid;   // same side as the grid's check - one zone lookup, not two
   if(MBStructureNear(dir, px_in, RecoveryZoneATR15 * atr15, sw)) { pos++; wp += "rescue " + sw + "; "; }
   else { neg++; wn += "no structure near (in the air); "; }
   // 6. Ladder left.
   // 6 + 7. Depth: ladder used up and break-even far away are what a deep basket looks like by
   // definition (a full ladder sits at 33-41% DD) - together they count as ONE reading, never as proof.
   string gr = "";
   int maxo = GridEffectiveMaxOrders(gr);
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double be = (G_BASKET_AVG_PRICE > 0.0) ? dir * (G_BASKET_AVG_PRICE - px) / atr15 : 0.0;
   bool ladder_out = (G_BASKET_ORDERS >= maxo || (ml > 0.0 && ml < 300.0));
   if(ladder_out || be >= 4.0)
   { neg++; wn += StringFormat("depth: %s, BE %.1f ATR15 away; ", (ladder_out ? "ladder used / margin thin" : "rungs left"), be); }
   else if(be <= 2.0 || maxo - G_BASKET_ORDERS >= 2)
   { pos++; wp += StringFormat("%d rungs left, BE %.1f ATR15; ", maxo - G_BASKET_ORDERS, be); }
   // 8. H1 and H4 both against.
   if(MBSign(G_MB_TF_STATE[3]) == -dir && MBSign(G_MB_TF_STATE[4]) == -dir) { neg++; wn += "H1 and H4 against; "; }
   // 9. A release that already came out and surprised (AUDIT FIX: the window before the release can be
   // the very move that rescues the basket - it is not evidence against it).
   if(G_CAL_ACTIVE && G_CAL_MINUTES_FROM_EVENT < 0 && G_CAL_BIG_SURPRISE) { neg++; wn += "news surprise; "; }

   int need = (dd >= 45.0) ? 2 : ((dd >= 35.0) ? 3 : 4);
   bool need_key = true;   // AUDIT FIX: always - a dead thesis or a confirmed reversal, at every depth
   int st = MB_RC_POSSIBLE;
   if(neg >= need && (!need_key || key) && neg > pos)
      st = MB_RC_IMPOSSIBLE;
   else if(neg >= 2 && neg >= pos)
      st = MB_RC_DOUBTFUL;


   G_MB_RC_PERSIST = (st == MB_RC_IMPOSSIBLE) ? G_MB_RC_PERSIST + 1 : 0;
   if(st != G_MB_RC_STATE && (MBPositionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS RECOVERY] %s basket DD %.1f%% -> %s (against %d / for %d, need %d incl. dead thesis or reversal: %s) | against: %s| for: %s",
                  (dir > 0 ? "BUY" : "SELL"), dd, MBRecoveryStateName(st), neg, pos, need, (key ? "yes" : "no"), wn, wp);
   G_MB_RC_STATE = st;
   G_MB_RC_NEG = neg;
   G_MB_RC_POS = pos;
   G_MB_RC_WHY = (st == MB_RC_POSSIBLE) ? wp : wn;
   if(st > G_MB_RC_WORST_STATE) G_MB_RC_WORST_STATE = st;

   if(st == MB_RC_IMPOSSIBLE && !G_MB_RC_ARMED && G_MB_RC_PERSIST >= MathMax(1, RecoveryPersistBars))
   {
      G_MB_RC_ARMED = true;
      G_MB_RC_ARM_DD = dd;
      G_MB_RC_WORST = px;
      MBRecoverySave();
      if((MBPositionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS RECOVERY] EXIT ARMED at DD %.1f%% - closing on the first %.1f ATR bounce, or at once if DD reaches %.1f%%",
                     dd, RecoveryBounceATR, dd + RecoveryWorsenDD);
   }
}

// STAGE 16 (E6): the exit moment for a basket judged IMPOSSIBLE - not on the worst tick. The first
// bounce in the basket's favour closes it; a further RecoveryWorsenDD of drawdown closes it at once.
bool MBRecoveryExit(string &why)
{
   if(!EnableRecoveryJudge || !EnableMBPositionBrain || !EnableMarketBrainEngines ||
      !G_MB_RC_ARMED || G_BASKET_ORDERS <= 0 || G_MB_PB_DIR == 0)
      return false;
   if(G_MB_PB_BASKET != MBBasketOpenTime())   // AUDIT FIX: only the basket that was judged
      return false;
   int dir = G_MB_PB_DIR;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(px <= 0.0)
      return false;
   G_MB_RC_WORST = (dir > 0) ? MathMin(G_MB_RC_WORST, px) : MathMax(G_MB_RC_WORST, px);
   double atr1 = G_MB_ATR[0] * _Point;
   double bounce = dir * (px - G_MB_RC_WORST);
   double dd = G_BASKET_DD_PERCENT;
   if(atr1 > 0.0 && bounce >= RecoveryBounceATR * atr1)
   {
      why = StringFormat("SMART EXIT: recovery impossible (%s) - closed on a %.2f bounce at DD %.1f%%", G_MB_RC_WHY, bounce, dd);
      return true;
   }
   if(dd >= G_MB_RC_ARM_DD + RecoveryWorsenDD)
   {
      why = StringFormat("SMART EXIT: recovery impossible (%s) - DD worsened %.1f%% -> %.1f%%", G_MB_RC_WHY, G_MB_RC_ARM_DD, dd);
      return true;
   }
   return false;
}

// LOCAL BASKET EXIT (5): a basket opened against the global bias is a short visit, not a position to
// nurse. At break-even or better it closes when: it has been open LocalBasketMaxMinutes; the global
// side displaces back (live or a fresh M1 / M5 displacement); the handoff moment arrives (the bounce
// ran into the global side's place and turned); or its local thesis has ended (target or invalid).
bool MBLocalBasketExit(const double profit, string &why)
{
   if(!EnableLocalTrading || !EnableMBPositionBrain || !EnableMarketBrainEngines || !G_MB_PB_LOCAL)
      return false;
   if(G_MB_PB_BASKET == 0 || G_MB_PB_BASKET != MBBasketOpenTime() || G_MB_PB_DIR == 0)
      return false;
   if(profit < 0.0)
      return false;
   int ld = G_MB_PB_DIR, gd = -ld;
   string hw = "";
   if((TimeCurrent() - G_MB_PB_BASKET) >= (long)MathMax(1, LocalBasketMaxMinutes) * 60)
      why = StringFormat("local basket open %d min - closed at +%.2f", (int)((TimeCurrent() - G_MB_PB_BASKET) / 60), profit);
   else if(G_MB_LIVE_DIR == gd || (G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == gd &&
                                   G_MB_LAST[0].time >= G_MB_PB_BASKET) ||
           (G_MB_LAST[1].intent == MB_CI_DISPLACEMENT && G_MB_LAST[1].dir == gd && G_MB_LAST[1].time >= G_MB_PB_BASKET))
      why = StringFormat("global side displaced back - local basket closed at +%.2f", profit);
   else if(MBHandoffNow(gd, hw))
      why = StringFormat("handoff: %s - local basket closed at +%.2f", hw, profit);
   else if(G_LOC_TH_DIR != ld && G_LOC_TH_END >= G_MB_PB_BASKET &&
           (G_LOC_TH_STATE == "maqsadga yetdi" || G_LOC_TH_STATE == "yiqildi"))
      why = StringFormat("local thesis %s - local basket closed at +%.2f", G_LOC_TH_STATE, profit);
   return (StringLen(why) > 0);
}

//---------------------------------------------------------------------
// SMART RUNNER (normal mode): let the right baskets run past the TP
//---------------------------------------------------------------------
// The fixed TP (2500 x 0.85 = ~2125) closed every basket before the 2300 trail could ever arm. A
// basket now RUNS - no close at the TP, a trail and a far target instead - only when the market
// supports it: a trend or expansion its way, or the brain with it and its thesis alive; one or two
// orders; never a local / dead / once-deep basket; no news; and room to the next opposing zone of
// at least 1.5 x TP. Everything else keeps the fixed TP.
bool     G_RUN_ACTIVE = false;
datetime G_RUN_BASKET = 0;
datetime G_RUN_PEAK_T = 0;
double   G_RUN_TARGET = 0.0;   // points over the average

bool MBRunnerActive()
{
   return (G_RUN_ACTIVE && G_RUN_BASKET != 0 && G_RUN_BASKET == G_MB_PB_BASKET);
}

void MBRunnerReset()
{
   G_RUN_ACTIVE = false;
   G_RUN_BASKET = 0;
   G_RUN_PEAK_T = 0;
   G_RUN_TARGET = 0.0;
}

bool MBRunnerEligible(const int dir, const double tp_points, string &why)
{
   why = "";
   if(!EnableSmartRunner || EnableRebateMode || dir == 0 || tp_points <= 0.0)
      return false;
   if(G_BASKET_ORDERS > MathMax(1, RunnerMaxOrders) || G_MB_PB_LOCAL || G_MB_PB_DEAD)
      return false;
   if(EnableRecoveryJudge && (G_MB_RC_PEAK_DD >= RecoveryStartDD || G_MB_RC_STATE >= MB_RC_DOUBTFUL))
      return false;
   if(G_CAL_ACTIVE)
      return false;
   bool trend = EnableRegimePlaybook && (G_MB_RG == MB_RG_TREND || G_MB_RG == MB_RG_EXPANSION) && G_MB_RG_DIR == dir;
   bool brain = (dir * G_MB_BIAS >= 2 && G_MB_TH_DIR == dir && !G_MB_TH_THREAT &&
                 (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED));
   if(!trend && !brain)
      return false;
   if(EnableRegimePlaybook && (G_MB_RG == MB_RG_RANGE || G_MB_RG == MB_RG_COMPRESSION) && !brain)
      return false;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double z = (dir > 0) ? ZoneMapNearestResistance(px) : ZoneMapNearestSupport(px);
   if(z > 0.0 && G_BASKET_AVG_PRICE > 0.0 && dir * (z - G_BASKET_AVG_PRICE) / _Point < 1.5 * tp_points)
      return false;   // an opposing zone sits too close - take the TP
   why = trend ? StringFormat("%s regime", MBRegimeName(G_MB_RG)) : StringFormat("%s, thesis alive", MBBiasName(G_MB_BIAS));
   return true;
}

// Take the broker TP off the basket's positions (the runner manages the exit; a broker TP would close
// it at the old target). The lock goes on the broker as a stop through BrokerTrailSync.
void MBRunnerClearBrokerTP()
{
   G_TRADE.SetExpertMagicNumber(MagicNumber);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      double tp = PositionGetDouble(POSITION_TP);
      if(tp > 0.0)
         G_TRADE.PositionModify(ticket, PositionGetDouble(POSITION_SL), 0.0);
   }
}

// Called from the basket exit check before the fixed TP. True = close now (why says how).
bool MBRunnerManage(const double basket_points, const double tp_points, string &why)
{
   why = "";
   if(!EnableSmartRunner || EnableRebateMode || G_MB_PB_DIR == 0 || G_MB_PB_BASKET == 0)
      return false;
   if(G_MB_PB_BASKET != MBBasketOpenTime())
      return false;
   int dir = G_MB_PB_DIR;
   double atr5_pts = G_MB_ATR[1];
   double step = MathMax((double)MathMax(1, RunnerMinStepPoints), 0.5 * atr5_pts);
   double arm = MathMin((double)MathMax(1, RunnerArmPoints), 0.88 * tp_points);

   if(!MBRunnerActive())
   {
      string ew = "";
      if(basket_points < arm || !MBRunnerEligible(dir, tp_points, ew))
         return false;
      G_RUN_ACTIVE = true;
      G_RUN_BASKET = G_MB_PB_BASKET;
      G_RUN_PEAK_T = TimeCurrent();
      double far = RunnerFarTPMult * tp_points;
      if(G_MB_DOL > 0.0 && G_BASKET_AVG_PRICE > 0.0)
      {
         double dol_pts = dir * (G_MB_DOL - G_BASKET_AVG_PRICE) / _Point;
         if(dol_pts >= 1.5 * tp_points)
            far = MathMin(far, dol_pts);
      }
      G_RUN_TARGET = far;
      G_BASKET_TRAIL_ACTIVE = true;
      G_BASKET_TRAIL_PEAK = basket_points;
      // The first lock keeps most of what the fixed TP would have paid: the configured lock, or 90% of
      // the arm point when the TP (x TPScale) sits below the configured arm.
      G_BASKET_TRAIL_LOCK = MathMax(0.0, MathMin((double)RunnerLockPoints, MathMax(arm - step, 0.9 * arm)));
      if(G_BASKET_TRAIL_LOCK >= basket_points)
         G_BASKET_TRAIL_LOCK = MathMax(0.0, basket_points - 0.5 * step);
      MBRunnerClearBrokerTP();
      if((MBPositionPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS RUNNER] %s basket runs (%s): armed at +%.0f, lock +%.0f, trail %.0f, far target +%.0f",
                     (dir > 0 ? "BUY" : "SELL"), ew, basket_points, G_BASKET_TRAIL_LOCK, step, G_RUN_TARGET);
   }

   // Trail: the lock only moves up.
   if(basket_points > G_BASKET_TRAIL_PEAK)
   {
      G_BASKET_TRAIL_PEAK = basket_points;
      G_RUN_PEAK_T = TimeCurrent();
   }
   double want = G_BASKET_TRAIL_PEAK - step;
   if(want > G_BASKET_TRAIL_LOCK && want < basket_points)
      G_BASKET_TRAIL_LOCK = want;
   G_BASKET_TRAIL_ACTIVE = true;

   if(basket_points <= G_BASKET_TRAIL_LOCK)
      why = StringFormat("RUNNER lock +%.0f (peak +%.0f)", G_BASKET_TRAIL_LOCK, G_BASKET_TRAIL_PEAK);
   else if(G_RUN_TARGET > 0.0 && basket_points >= G_RUN_TARGET)
      why = StringFormat("RUNNER far target +%.0f reached", G_RUN_TARGET);
   else if(basket_points >= tp_points && MBReactionCandle(-dir))
      why = StringFormat("RUNNER: reaction candle against at +%.0f - out before it bites", basket_points);
   else if((TimeCurrent() - G_RUN_PEAK_T) >= (long)MathMax(1, RunnerStallMinutes) * 60)
      why = StringFormat("RUNNER: no new high for %d min - closed at +%.0f", RunnerStallMinutes, basket_points);
   return (StringLen(why) > 0);
}

// E8: one line per deep basket, for tuning the thresholds on evidence.
void MBRecoveryLog(const datetime opened, const int dir, const double result)
{
   if(!RecoveryLogToFile || G_MB_RC_PEAK_DD < RecoveryStartDD)
      return;
   string name = StringFormat("Sirus_Recovery_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) == 0)
      FileWriteString(h, "opened;closed;dir;peak_dd;worst_state;armed;result;last_reason\r\n");
   FileSeek(h, 0, SEEK_END);
   string why_csv = G_MB_RC_WHY;
   StringReplace(why_csv, ";", ",");   // AUDIT FIX: the reasons use "; " - keep them in one CSV column
   FileWriteString(h, StringFormat("%s;%s;%s;%.1f;%s;%s;%.2f;%s\r\n", TimeToString(opened, TIME_DATE | TIME_SECONDS),
                                   TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), (dir > 0 ? "BUY" : "SELL"),
                                   G_MB_RC_PEAK_DD, MBRecoveryStateName(G_MB_RC_WORST_STATE), (G_MB_RC_ARMED ? "yes" : "no"),
                                   result, why_csv));
   FileClose(h);
}

void MBRecoveryReset()
{
   G_MB_RC_STATE = MB_RC_NONE;
   G_MB_RC_NEG = 0;
   G_MB_RC_POS = 0;
   G_MB_RC_WHY = "";
   G_MB_RC_PERSIST = 0;
   G_MB_RC_BAR = 0;
   G_MB_RC_ARMED = false;
   G_MB_RC_ARM_DD = 0.0;
   G_MB_RC_WORST = 0.0;
   G_MB_RC_PEAK_DD = 0.0;
   G_MB_RC_WORST_STATE = MB_RC_NONE;
}

// Panel text for the basket section.
string MBRecoveryText()
{
   if(!EnableRecoveryJudge || G_BASKET_ORDERS <= 0)
      return "";
   if(G_MB_RC_STATE == MB_RC_NONE)
      return StringFormat("Qutqarish: baholash %.0f%% DD dan boshlanadi (hozir %.1f%%, SL %.0f%%)", RecoveryStartDD, G_BASKET_DD_PERCENT, BasketSLPercent);
   string st = (G_MB_RC_STATE == MB_RC_POSSIBLE) ? "IMKON BOR" : ((G_MB_RC_STATE == MB_RC_DOUBTFUL) ? "SHUBHALI" : "IMKONSIZ");
   if(G_MB_RC_ARMED) st = "IMKONSIZ - chiqish qurollangan";
   return StringFormat("Qutqarish: %s (qarshi %d / yonida %d) · %s", st, G_MB_RC_NEG, G_MB_RC_POS, G_MB_RC_WHY);
}

// How the watched basket ended: the fast re-entry path, Memory and the recovery log read it.
void MBPBCloseBookkeeping()
{
   int outs = 0;
   double res = MBBasketResult(G_MB_PB_BASKET, outs);
   G_MB_LAST_CLOSE_DIR = G_MB_PB_DIR;
   G_MB_LAST_CLOSE_WIN = (res > 0.0);
   G_MB_LAST_CLOSE_TIME = TimeCurrent();
   MBReExitRecord(G_MB_PB_DIR, res);         // plan stage 4: exit kind + failed attempts per thesis
   MBAutopsyOnClose(G_MB_PB_DIR, res, G_PB_MFE, G_PB_MAE, G_MB_PB_BASKET, G_PB_T_SHOW);   // plan stage 7
   MBMemoryOnBasketClosed(G_MB_PB_BASKET);   // Memory (phase 8): write the result next to the Entry DNA
   if(G_MB_PB_LOCAL)
      MBLocalRecord(res > 0.0);              // local record: auto-tune + loss pause
   MBRecoveryLog(G_MB_PB_BASKET, G_MB_PB_DIR, res);   // stage 16 (E8)
   MBRecoveryForget();
}

// Called every tick from CoreUpdate.
void MBPositionBrainUpdate()
{
   if(!EnableMBPositionBrain || !EnableMarketBrainEngines)
   {
      // AUDIT FIX: switched off - no judgement of an old basket may survive to close a new one.
      G_MB_PB_BASKET = 0;
      G_MB_PB_DIR = 0;
      G_MB_PB_DEAD = false;
      MBRecoveryReset();
      return;
   }

   // AUDIT FIX: decided on the real positions - at OnInit G_BASKET_ORDERS is still 0 while a basket is
   // open, and treating that as "closed" wrote a fake result and dropped the basket's state.
   datetime opened = MBBasketOpenTime();
   if(opened == 0)
   {
      if(G_MB_PB_BASKET != 0)
         MBPBCloseBookkeeping();
      MBRecoveryReset();
      MBRunnerReset();
      G_PB_MFE = 0.0;
      G_PB_MAE = 0.0;
      G_PB_T_SHOW = 0;
      G_PB_MAX_HOLD_MIN = 0;
      G_PB_EXP_FAIL = false;
      G_PB_EXP_WHY = "";
      G_MB_PB_BASKET = 0;
      G_MB_PB_DIR = 0;
      G_MB_PB_DEAD = false;
      G_MB_PB_DEAD_TIME = 0;
      G_MB_PB_DEAD_WHY = "";
      G_MB_PB_RESCUED = false;
      G_MB_PB_WAIT_ORDERS = -1;
      return;
   }

   int dir = MBBasketDirReal();
   if(dir == 0)
      return;

   if(opened != G_MB_PB_BASKET || dir != G_MB_PB_DIR)
   {
      // AUDIT FIX: the old basket closed and a new one opened on the same tick - the old one still
      // gets its bookkeeping (result, last close, recovery log) before the state moves on.
      if(G_MB_PB_BASKET != 0 && opened != G_MB_PB_BASKET)
         MBPBCloseBookkeeping();
      G_MB_PB_LOCAL = (dir * G_MB_BIAS < 0);
      MBRunnerReset();
      G_PB_MFE = 0.0;
      G_PB_MAE = 0.0;
      G_PB_T_SHOW = 0;
      G_PB_MAX_HOLD_MIN = 0;
      G_PB_EXP_FAIL = false;
      G_PB_EXP_WHY = "";
      G_MB_PB_BASKET = opened;
      G_MB_PB_DIR = dir;
      G_MB_PB_DEAD = false;
      G_MB_PB_DEAD_TIME = 0;
      G_MB_PB_DEAD_WHY = "";
      G_MB_PB_RESCUED = false;
      G_MB_PB_WAIT_ORDERS = -1;
      MBRecoveryReset();
      G_MB_PB_CHECK_BAR = 0;
      MBRecoveryRestore(opened);   // same basket after a restart / input change: its judgement comes back
   }

   G_PB_MFE = MathMax(G_PB_MFE, G_BASKET_POINTS);   // plan stage 5: the basket's best moment
   G_PB_MAE = MathMin(G_PB_MAE, G_BASKET_POINTS);   // plan stage 7: and its worst
   if(G_GRID_HOLD_SINCE > 0)
      G_PB_MAX_HOLD_MIN = MathMax(G_PB_MAX_HOLD_MIN, (int)((TimeCurrent() - G_GRID_HOLD_SINCE) / 60));

   // SPEED: death and rescue read events and the thesis, which change once per M1 bar.
   datetime pb_bar = iTime(_Symbol, PERIOD_M1, 0);
   bool pb_check = (pb_bar != G_MB_PB_CHECK_BAR);
   G_MB_PB_CHECK_BAR = pb_bar;
   if(!pb_check)
   {
      MBRecoveryEvaluate(dir, opened);
      return;
   }
   MBExpectationEvaluate(dir, opened);

   if(!G_MB_PB_DEAD)
   {
      // A rescued basket is only judged on what happened after the rescue.
      datetime since = G_MB_PB_RESCUED ? G_MB_PB_DEAD_TIME : opened;
      string why = MBBasketDeathReason(dir, since);
      if(StringLen(why) > 0)
      {
         G_MB_PB_DEAD = true;
         G_MB_PB_DEAD_TIME = TimeCurrent();
         G_MB_PB_DEAD_WHY = why;
         G_MB_PB_RESCUED = false;
         MBRecoverySave();
         if((MBPositionPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS POSITION] %s basket thesis DEAD (%d orders, %.0f pts) | %s | grid stopped, exit at break-even",
                        (dir > 0 ? "BUY" : "SELL"), G_BASKET_ORDERS, G_BASKET_POINTS, why);
      }
   }
   else
   {
      // Rescue: a new thesis back in the basket's direction, after it died.
      string what = "";
      datetime swt = 0;
      bool rescue = MBReversalAfter(dir, 0, 4, true, G_MB_PB_DEAD_TIME, what, swt);
      if(!rescue && EnableMarketBrain && G_MB_TH_DIR == dir && G_MB_TH_SINCE > G_MB_PB_DEAD_TIME &&
         (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED))
      {
         rescue = true;
         what = StringFormat("new %s thesis (%s)", (dir > 0 ? "bullish" : "bearish"), MBBiasName(G_MB_BIAS));
      }
      if(rescue)
      {
         G_MB_PB_DEAD = false;
         G_MB_PB_RESCUED = true;
         G_MB_PB_DEAD_TIME = TimeCurrent();
         MBRecoverySave();
         if((MBPositionPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS POSITION] %s basket RESCUE allowed: %s - additions and the normal target are back",
                        (dir > 0 ? "BUY" : "SELL"), what);
      }
   }

   MBRecoveryEvaluate(dir, opened);   // stage 16 (E1): from RecoveryStartDD, once per M1 bar
   MBRecoverySave();                  // once per M1 bar (this path runs on the bar's first tick)
}

// Plan stage 5: EXPECTATION vs REALITY, once per M1 bar. A basket opened for a move has to show it:
// after ExpectMinutes its best moment must have reached ExpectTPShare of the TP. Slow alone is not
// enough (a recovering grid is slow by design) - the tape must also have turned against it: its
// side's control share at 35% or less, its side exhausted, or the micro turn against it EXHAUSTION+.
// Then the basket takes break-even + cover instead of waiting for the full target. Never a loss.
void MBExpectationEvaluate(const int dir, const datetime opened)
{
   if(!EnableExpectationCheck || dir == 0 || opened <= 0)
   {
      G_PB_EXP_FAIL = false;
      return;
   }
   int mins = (int)((TimeCurrent() - opened) / 60);
   double tp = BasketTPForOrderCount(MathMax(1, G_BASKET_ORDERS));
   if(G_PB_T_SHOW == 0 && tp > 0.0 && G_PB_MFE >= ExpectTPShare * tp)
      G_PB_T_SHOW = TimeCurrent();   // plan stage 7: time to show
   bool slow = (mins >= MathMax(1, ExpectMinutes) && tp > 0.0 && G_PB_MFE < ExpectTPShare * tp);
   string against = "";
   if(EnableMicroControl && MBControlOf(dir) <= 35)
      against = StringFormat("control %d%%", MBControlOf(dir));
   else if(MBExhaustPressure(dir) >= ExhaustCautionScore)
      against = StringFormat("exhaustion %d", MBExhaustPressure(dir));
   else if(EnableMicroControl && G_MC_PRIMARY == dir && G_MC_TURN >= MC_TURN_EXHAUST)
      against = StringFormat("micro turn %s", MBTurnName(G_MC_TURN));
   bool fail = slow && StringLen(against) > 0;
   if(fail && !G_PB_EXP_FAIL && (MBPositionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS POSITION] %s basket EXPECTATION FAILED: %d min, best +%.0f of TP %.0f, %s - break-even exit armed",
                  (dir > 0 ? "BUY" : "SELL"), mins, G_PB_MFE, tp, against);
   G_PB_EXP_FAIL = fail;
   G_PB_EXP_WHY = fail ? StringFormat("%d min, best +%.0f/%.0f, %s", mins, G_PB_MFE, tp, against) : "";
}

// The minimum confirmation for a rung: the move against the basket has at least PAUSED - no live
// displacement against, the last closed M1 bar is not a displacement / continuation / breakout against,
// and it made no new extreme beyond the bar before it. Normally comes within minutes.
bool MBGridPauseConfirm(const int dir, string &why)
{
   why = "";
   if(dir == 0)
      return false;
   if(G_MB_LIVE_DIR == -dir)
      return false;
   int it = G_MB_LAST[0].intent;
   if(G_MB_LAST[0].dir == -dir && (it == MB_CI_DISPLACEMENT || it == MB_CI_CONTINUATION || it == MB_CI_BREAKOUT))
      return false;
   double e1 = (dir > 0) ? iLow(_Symbol, PERIOD_M1, 1) : iHigh(_Symbol, PERIOD_M1, 1);
   double e2 = (dir > 0) ? iLow(_Symbol, PERIOD_M1, 2) : iHigh(_Symbol, PERIOD_M1, 2);
   if(e1 <= 0.0 || e2 <= 0.0 || dir * (e1 - e2) < 0.0)
      return false;   // the last bar still made a new extreme against the basket
   why = "qarshi harakat to'xtadi (oxirgi M1 yangi ekstremum qilmadi)";
   return true;
}

// Rescue guarantee: is the move against a basket in dir slowing? (any one sign is enough)
bool MBAdverseSlowing(const int dir, string &why)
{
   why = "";
   if(!EnableMarketBrainEngines)
   {
      why = "miya o'chiq";
      return true;
   }
   int xp = MBExhaustPressure(-dir);
   if(xp >= 30)
   {
      why = StringFormat("qarshi harakat charchash %d", xp);
      return true;
   }
   int it = G_MB_LAST[0].intent;
   if(G_MB_LIVE_DIR == dir ||
      (G_MB_LAST[0].dir == dir && (it == MB_CI_REJECTION || it == MB_CI_DISPLACEMENT || it == MB_CI_LIQ_GRAB || it == MB_CI_ABSORPTION)))
   {
      why = "savat tomoniga sham";
      return true;
   }
   if(MBPressureSide(0) != -dir && MBPressureSide(1) != -dir)
   {
      why = "M1/M5 bosimi endi qarshi emas";
      return true;
   }
   if(MBAdverseSpent(dir))
   {
      why = "qarshi impuls kech";
      return true;
   }
   return false;
}

// Grid gate. true = the addition may go now.
bool MBGridAllows(const int dir, const int orders, string &reason)
{
   if(!EnableMBPositionBrain || !EnableMarketBrainEngines || dir == 0)
      return true;

   if(G_MB_PB_DEAD)
   {
      reason = "holding - basket thesis dead (" + G_MB_PB_DEAD_WHY + "); waiting for break-even or a new thesis";
      return false;
   }
   if(EnableRecoveryJudge && G_MB_RC_ARMED)
   {
      reason = "holding - smart exit armed, waiting for the exit bounce";
      return false;
   }
   // RESCUE GUARANTEE (13_Grid_Engine): price has run far enough from the last order (and, below the
   // forced distance, the move against the basket is slowing) - every soft hold below is stepped over.
   // The two above are the owner's hard rules and stay.
   if(G_GRID_RESCUE_ON)
   {
      G_GRID_OVERRIDDEN += (StringLen(G_GRID_OVERRIDDEN) > 0 ? " | " : "") + "market brain holds";
      G_MB_PB_WAIT_ORDERS = -1;
      return true;
   }
   // Stage 16 (A7): the thesis is threatened - no averaging until the candles side with it again.
   if(G_MB_TH_THREAT && G_MB_TH_DIR == dir)
   {
      reason = "holding - basket thesis threatened (" + G_MB_TH_THREAT_WHY + ")";
      return false;
   }
   // Local basket (opened against the global bias): a shallow ladder only.
   if(G_MB_PB_LOCAL && orders >= MathMax(1, LocalGridMaxRungs))
   {
      reason = StringFormat("holding - local basket keeps at most %d orders", LocalGridMaxRungs);
      return false;
   }
   // Stage 16 (E1/E4): a doubtful or impossible basket - or one whose exit is armed - gets no more rungs.
   if(EnableRecoveryJudge && G_MB_RC_ARMED)
   {
      reason = "holding - smart exit armed, waiting for the exit bounce";
      return false;
   }
   if(EnableRecoveryJudge && G_MB_RC_STATE >= MB_RC_DOUBTFUL)
   {
      reason = StringFormat("holding - recovery %s (%s)", MBRecoveryStateName(G_MB_RC_STATE), G_MB_RC_WHY);
      return false;
   }

   if(!MBGridNeedsResponse)
      return true;

   // Against: a fresh displacement or a genuine break the other way on M1 / M5.
   bool against = (G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == -dir) ||
                  (G_MB_LAST[1].intent == MB_CI_DISPLACEMENT && G_MB_LAST[1].dir == -dir) ||
                  (G_MB_LIVE_DIR == -dir);
   string against_what = against ? "displacement against the basket" : "";
   // Stage 15 (A3): an M5 reversal forming against the basket - do not average into it yet.
   if(!against && EnableCandleDirectionLink && G_MB_SEQ_STORY[1] == 2 && G_MB_SEQ_DIR[1] == -dir)
   {
      against = true;
      against_what = "M5 reversal sequence forming against the basket";
   }
   if(!against)
   {
      for(int tfi = 0; tfi <= 1 && !against; tfi++)
      {
         int base = tfi * MB_EV_PER_TF;
         for(int i = 0; i < MB_EV_PER_TF; i++)
         {
            int idx = base + i;
            if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != -dir) continue;
            if(G_MB_EV[idx].type != MB_EV_ACCEPTANCE) continue;
            if(MBEventAgeBars(G_MB_EV[idx]) > MBFreshLimit(tfi)) continue;
            against = true;
            against_what = StringFormat("%s genuine break against @ %s", MBTFName(tfi), DoubleToString(G_MB_EV[idx].level, _Digits));
            break;
         }
      }
   }
   // FIX(long-DD): M5 and M15 pressure both against the basket and the move not spent - averaging here
   // adds bigger lots into a running move and is what turns a pullback into a long drawdown.
   if(!against && GridHoldOnCandlesAgainst && EnableCandleDirectionLink &&
      MBPressureSide(1) == -dir && MBPressureSide(2) == -dir && !MBAdverseSpent(dir))
   {
      against = true;
      against_what = "M5 and M15 candles still push against the basket";
   }
   if(against)
   {
      reason = "holding - " + against_what + " (no averaging into a breakdown)";
      return false;
   }

   // Response: the market defending the basket's side at this price.
   double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   bool response = (MBCandleTriggerNow(0, dir, px) && G_MB_LAST[0].intent != MB_CI_CONTINUATION) ||
                   (MBCandleTriggerNow(1, dir, px) && G_MB_LAST[1].intent != MB_CI_CONTINUATION) ||
                   (G_MB_LIVE_DIR == dir);
   string ev_what = "";
   if(!response)
      response = MBFreshTriggerEvent(dir, ev_what);

   // Stage 16 (E2/E3): the response must come AT a structure - a zone or FVG on the basket's side.
   double atr5 = G_MB_ATR[1] * _Point;
   string st_what = "";
   bool at_structure = !EnableGridAtStructure ||
                       (response && atr5 > 0.0 && MBStructureNear(dir, px, GridStructureATR5 * atr5, st_what));
   // Stage 16 (E5): the last rungs are a reserve - structure, a spent adverse move and a response,
   // all three, and no timeout opens them.
   string gm_why = "";
   int maxo = GridEffectiveMaxOrders(gm_why);
   // Plan stage 5 (GRID LIABILITY): where does this rung put the basket's break-even? Behind an HTF
   // MAJOR+ untaken level (H4 / previous day) the rung only deepens the hole - no rung until the
   // move against is spent. Behind an H1 MAJOR level it is a reserve-grade rung.
   bool liability_soft = false;
   if(EnableGridLiability && G_BASKET_VOLUME > 0.0 && G_BASKET_AVG_PRICE > 0.0)
   {
      double lot = (G_NEXT_GRID_LOT > 0.0) ? G_NEXT_GRID_LOT : G_BASKET_VOLUME / MathMax(1, orders);
      double new_avg = (G_BASKET_AVG_PRICE * G_BASKET_VOLUME + px * lot) / (G_BASKET_VOLUME + lot);
      double need = dir * (new_avg - px);   // how far price must come back for break-even
      double hard = MBLqNearestAhead(dir, px, 4);
      double soft = MBLqNearestAhead(dir, px, 3);
      if(need > 0.0 && hard > 0.0 && dir * (hard - px) < need && !MBAdverseSpent(dir))
      {
         reason = StringFormat("holding - grid liability: break-even after this rung (%s) sits beyond HTF liquidity %s",
                               DoubleToString(new_avg, _Digits), DoubleToString(hard, _Digits));
         return false;
      }
      liability_soft = (need > 0.0 && soft > 0.0 && dir * (soft - px) < need);
   }
   // A basket opened on a local leg against the global bias averages only like the reserve rungs:
   // structure, a spent move against it and a response - never on time alone.
   bool reserve = (GridReserveRungs > 0 && maxo - orders <= GridReserveRungs) || G_MB_PB_LOCAL || liability_soft;
   if(reserve)
   {
      if(response && at_structure && MBAdverseSpent(dir))
      {
         G_MB_PB_WAIT_ORDERS = -1;
         return true;
      }
      reason = StringFormat("holding - reserve rung %d/%d needs structure (%s) + spent adverse move (%s) + response (%s)",
                            orders + 1, maxo, (at_structure ? "ok" : "no"), (MBAdverseSpent(dir) ? "ok" : "no"), (response ? "ok" : "no"));
      return false;
   }
   if(response && at_structure)
   {
      G_MB_PB_WAIT_ORDERS = -1;
      return true;
   }

   // No response yet: wait a while for one, then add anyway. AUDIT FIX: the wait restarts when price
   // left the rung and came back (no call for over a minute) - time spent away is not waiting.
   if(G_MB_PB_WAIT_ORDERS == orders && G_MB_PB_WAIT_LAST > 0 && (TimeCurrent() - G_MB_PB_WAIT_LAST) > 60)
      G_MB_PB_WAIT_ORDERS = -1;
   G_MB_PB_WAIT_LAST = TimeCurrent();
   if(G_MB_PB_WAIT_ORDERS != orders)
   {
      G_MB_PB_WAIT_ORDERS = orders;
      G_MB_PB_WAIT_SINCE = TimeCurrent();
   }
   int waited = (int)((TimeCurrent() - G_MB_PB_WAIT_SINCE) / 60);
   if(waited < MathMax(0, MBGridResponseMaxBars))
   {
      reason = StringFormat("holding - waiting for a candle response at this price (%d/%d M1 bars)", waited, MBGridResponseMaxBars);
      return false;
   }
   // OWNER RULE (fix): no response after the wait used to add the rung anyway - unconfirmed. Now the
   // wait only lowers what counts as confirmation: the move against has at least paused.
   string pw = "";
   if(!MBGridPauseConfirm(dir, pw))
   {
      reason = StringFormat("holding - no response after %d M1 bars; waiting for the move against to pause", waited);
      return false;
   }
   if((MBPositionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS POSITION] no response after %d M1 bars - grid addition on a pause (%s)", waited, pw);
   G_MB_PB_WAIT_ORDERS = -1;
   return true;
}

// Exit hook: a dead thesis closes the basket at break-even plus the cover.
bool MBBasketBreakEvenExit(const double basket_points, const double profit, string &why)
{
   if(!EnableMBPositionBrain || !EnableMarketBrainEngines || G_MB_PB_DIR == 0)
      return false;
   if(G_MB_PB_BASKET != MBBasketOpenTime())   // AUDIT FIX: only the basket that was judged
      return false;
   // Stage 16 (E7): break-even is also the exit for a doubtful basket, and for one that came back
   // from deep drawdown without a live thesis on its side - waiting for the full target there asks
   // the market for a second favour.
   bool th_with = (G_MB_TH_DIR == G_MB_PB_DIR && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED) &&
                   !G_MB_TH_THREAT && G_MB_PB_DIR * G_MB_BIAS >= 1);
   bool doubtful = EnableRecoveryJudge && G_MB_RC_STATE >= MB_RC_DOUBTFUL;
   // AUDIT FIX: a deep basket alone is normal for a full ladder - only one that was also judged doubtful.
   bool deep_back = EnableRecoveryJudge && G_MB_RC_PEAK_DD >= RecoveryStartDD && G_MB_RC_WORST_STATE >= MB_RC_DOUBTFUL && !th_with;
   // FIX(long-DD): a basket that sat in drawdown for a long time and came back without the candles on
   // its side (M5 and M15 not both with it) takes break-even rather than waiting for the full target.
   bool stale = EnableStaleBasketBE && G_MB_RC_PEAK_DD >= StaleBasketMinDD &&
                (TimeCurrent() - G_MB_PB_BASKET) >= (long)MathMax(1, StaleBasketMinutes) * 60 &&
                !(MBPressureSide(1) == G_MB_PB_DIR && MBPressureSide(2) == G_MB_PB_DIR) && !th_with;
   bool expect_fail = EnableExpectationCheck && G_PB_EXP_FAIL;   // plan stage 5
   if(!G_MB_PB_DEAD && !doubtful && !deep_back && !stale && !expect_fail)
      return false;
   // AUDIT FIX: break-even in money too - points ignore swap and commission.
   if(basket_points >= (double)MathMax(0, MBBreakEvenCoverPoints) && profit >= 0.0)
   {
      if(G_MB_PB_DEAD)
         why = StringFormat("thesis dead - break-even exit at +%.0f pts (%s)", basket_points, G_MB_PB_DEAD_WHY);
      else if(doubtful)
         why = StringFormat("recovery %s - break-even exit at +%.0f pts", MBRecoveryStateName(G_MB_RC_STATE), basket_points);
      else if(deep_back)
         why = StringFormat("back from %.1f%% DD without a thesis on its side - break-even exit at +%.0f pts", G_MB_RC_PEAK_DD, basket_points);
      else if(expect_fail && !stale)
         why = StringFormat("expectation failed (%s) - break-even exit at +%.0f pts", G_PB_EXP_WHY, basket_points);
      else
         why = StringFormat("open %d min, back from %.1f%% DD, candles not with it - break-even exit at +%.0f pts",
                            (int)((TimeCurrent() - G_MB_PB_BASKET) / 60), G_MB_RC_PEAK_DD, basket_points);
      return true;
   }
   return false;
}

string MBPositionText()
{
   if(!EnableMBPositionBrain || G_MB_PB_BASKET == 0)
      return "no basket";
   if(G_MB_PB_DEAD)
      return "thesis DEAD - " + G_MB_PB_DEAD_WHY + " - exit at break-even";
   return G_MB_PB_RESCUED ? "thesis RESCUED - normal management" : "thesis alive";
}
