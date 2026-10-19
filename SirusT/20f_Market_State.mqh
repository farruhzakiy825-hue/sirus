//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20f_Market_State                                |
//| Plan stage 8: market sensitivity, anomaly detector, one market   |
//| state with its transitions, adaptive weighting, scenarios and    |
//| the market narrative.                                            |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// Nothing here reads the market again - it reads the layers that already did (regime, bias, lock,
// reversal maturity, liquidity map, exhaustion, control) and says what they add up to.
//
//  SENSITIVITY  how alive the tape is: the last five M1 ranges against ATR(M1) and the five-bar
//               velocity -> SOKIN / ODDIY / FAOLLASHMOQDA / KENGAYMOQDA / TEZ / CHARCHADI.
//  ANOMALY      a spread 2.5x its hour's normal, an M1 bar of 4 ATR(M1), a jump of one ATR(M5)
//               between two ticks -> ABNORMAL for AnomalyCooldownMin: no new entries.
//  STATE        one of: NEWS/ABNORMAL, REVERSAL CONFIRMED, REVERSAL DEVELOPING, LIQUIDITY HUNT,
//               EXHAUSTION, BREAKOUT, EXPANSION, FAKE BREAKOUT, STRONG TREND, TREND, PULLBACK,
//               ACCUMULATION, DISTRIBUTION, CHOP, UNKNOWN - with the time it changed and the
//               state before (a transition is often worth more than the state).
//  WEIGHTING    the judge's quality moves with the state: trend states favour the primary side,
//               reversal states the reversal side, exhaustion taxes the primary side, chop and
//               unknown tax everything a little.
//  SCENARIOS    bull / bear / chop shares, each with its target (the champion liquidity) and its
//               invalidation (the protected level).
//  NARRATIVE    one line: what happened, where we are, what is awaited.
//  FEEDBACK     package 16b (plan item 10): the dominant scenario (share >= ScenarioFeedbackMinShare, with a
//               target and an invalidation) is followed bar by bar until price reaches the target, crosses
//               the invalidation or ScenarioFeedbackHours pass - one CSV row each and a hit rate per share
//               band on the panel. Recorded only: no rule reads it yet.
//
// Speed: once per M1 bar; the tick part is one price comparison.

// [tester build] input group "BRAIN ▸ Market state & scenarios"
// EnableMarketState: Bozor holati (15 holat), sezgirlik, ssenariylar va hikoya - panel + hakam vaznlari
const bool   EnableMarketState        = true;   // Enable market state
// EnableAnomalyGuard: G'AYRITABIIY BOZOR: spread 2.5x, M1 bar 4 ATR, tiklar orasida 1 ATR(M5) sakrash - AnomalyCooldownMin davomida yangi kirish yo'q
const bool   EnableAnomalyGuard       = true;   // Enable anomaly guard
// AnomalyCooldownMin: G'ayritabiiy hodisadan keyin shuncha daqiqa kutiladi
const int    AnomalyCooldownMin       = 5;   // Anomaly cooldown min
// StatePrintOnUse: Holat almashuvini jurnalga yozish ([SIRUS STATE])
#define StatePrintOnUse                      LogBrainEvents   // Package 14 log group (was input, default true)
// EnableScenarioFeedback: Ustun ssenariy maqsadga yetdimi yoki bekor bo'ldimi - CSV (Sirus_Scenario_*.csv) va panel. Faqat o'lchaydi
const bool   EnableScenarioFeedback   = true;   // Scenario feedback: record target / invalidation outcomes
// ScenarioFeedbackMinShare: Ssenariy shu ulushdan (%) boshlab kuzatiladi
const int    ScenarioFeedbackMinShare = 55;   // Scenario feedback: follow from this share %
// ScenarioFeedbackHours: Shuncha soatda hal bo'lmasa - TIMEOUT
const int    ScenarioFeedbackHours    = 4;   // Scenario feedback: timeout hours

#define MST_UNKNOWN        0
#define MST_NEWS           1
#define MST_REV_CONFIRMED  2
#define MST_REV_DEVELOP    3
#define MST_LIQ_HUNT       4
#define MST_EXHAUSTION     5
#define MST_BREAKOUT       6
#define MST_EXPANSION      7
#define MST_FAKE_BREAKOUT  8
#define MST_STRONG_TREND   9
#define MST_TREND          10
#define MST_PULLBACK       11
#define MST_ACCUMULATION   12
#define MST_DISTRIBUTION   13
#define MST_CHOP           14

#define SN_QUIET     0
#define SN_NORMAL    1
#define SN_ACTIVE    2
#define SN_EXPAND    3
#define SN_FAST      4
#define SN_EXHAUST   5

int      G_MST_STATE      = MST_UNKNOWN;
int      G_MST_DIR        = 0;          // the side the state belongs to (0 = none)
int      G_MST_PREV       = MST_UNKNOWN;
int      G_MST_PREV_DIR   = 0;
datetime G_MST_SINCE      = 0;
int      G_MST_SENS       = SN_NORMAL;
datetime G_MST_SENS_HOT   = 0;          // last time the tape was EXPANDING / FAST
datetime G_MST_ANOM_UNTIL = 0;
string   G_MST_ANOM_WHY   = "";
double   G_MST_LAST_BID   = 0.0;
datetime G_MST_BAR        = 0;
int      G_SC_BULL = 33, G_SC_BEAR = 33, G_SC_CHOP = 34;
double   G_SC_BULL_TGT = 0.0, G_SC_BEAR_TGT = 0.0, G_SC_BULL_INV = 0.0, G_SC_BEAR_INV = 0.0;
// Package 16b: the scenario being followed, and today's hit rate per share band (0: <65, 1: 65-74, 2: 75+).
int      G_SCF_DIR = 0, G_SCF_SHARE = 0, G_SCF_STATE = 0;
double   G_SCF_PX = 0.0, G_SCF_TGT = 0.0, G_SCF_INV = 0.0, G_SCF_MFE = 0.0, G_SCF_MAE = 0.0;
datetime G_SCF_OPEN = 0;
int      G_SCF_HIT[3], G_SCF_N[3];
int      G_SCF_DAY = -1;
string   G_MST_STORY = "";

string MBStateName(const int s)
{
   switch(s)
   {
      case MST_NEWS:          return "YANGILIK/G'AYRITABIIY";
      case MST_REV_CONFIRMED: return "BURILISH TASDIQLANDI";
      case MST_REV_DEVELOP:   return "BURILISH RIVOJLANMOQDA";
      case MST_LIQ_HUNT:      return "LIKVIDLIK OVI";
      case MST_EXHAUSTION:    return "CHARCHASH";
      case MST_BREAKOUT:      return "BREAKOUT";
      case MST_EXPANSION:     return "KENGAYISH";
      case MST_FAKE_BREAKOUT: return "SOXTA BREAKOUT";
      case MST_STRONG_TREND:  return "KUCHLI TREND";
      case MST_TREND:         return "TREND";
      case MST_PULLBACK:      return "PULLBACK";
      case MST_ACCUMULATION:  return "TO'PLASH";
      case MST_DISTRIBUTION:  return "TARQATISH";
      case MST_CHOP:          return "CHOP";
   }
   return "NOMA'LUM";
}

string MBSensName(const int s)
{
   switch(s)
   {
      case SN_QUIET:   return "sokin";
      case SN_NORMAL:  return "oddiy";
      case SN_ACTIVE:  return "faollashmoqda";
      case SN_EXPAND:  return "kengaymoqda";
      case SN_FAST:    return "tez";
      case SN_EXHAUST: return "charchadi";
   }
   return "-";
}

string MBDirArrow(const int d) { return (d > 0) ? "▲" : ((d < 0) ? "▼" : ""); }

// Every tick: a jump of one ATR(M5) between two ticks is not a market, it is a gap.
void MBMarketStateTick()
{
   if(!EnableMarketState || !EnableAnomalyGuard)
      return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr5 = G_MB_ATR[1] * _Point;
   if(bid > 0.0 && G_MST_LAST_BID > 0.0 && atr5 > 0.0 && MathAbs(bid - G_MST_LAST_BID) >= atr5)
   {
      G_MST_ANOM_UNTIL = TimeCurrent() + MathMax(1, AnomalyCooldownMin) * 60;
      G_MST_ANOM_WHY = StringFormat("price jumped %.1f ATR(M5) in one tick", MathAbs(bid - G_MST_LAST_BID) / atr5);
      if(StatePrintOnUse && G_VERBOSE)
         PrintFormat("[SIRUS STATE] ABNORMAL - %s", G_MST_ANOM_WHY);
   }
   G_MST_LAST_BID = bid;
}

int MBSensitivity()
{
   double base = G_MB_ATR[0] * _Point;
   if(base <= 0.0)
      return SN_NORMAL;
   double rs = 0.0;
   for(int s = 1; s <= 5; s++)
      rs += iHigh(_Symbol, PERIOD_M1, s) - iLow(_Symbol, PERIOD_M1, s);
   double rr = (rs / 5.0) / base;
   double c1 = iClose(_Symbol, PERIOD_M1, 1), c6 = iClose(_Symbol, PERIOD_M1, 6);
   double vel = (c1 > 0.0 && c6 > 0.0) ? MathAbs(c1 - c6) / base : 0.0;
   int s = SN_NORMAL;
   if(rr >= 2.5 || G_MB_VOL_PCT >= 92.0)  s = SN_FAST;
   else if(rr >= 1.8 && vel >= 3.0)       s = SN_EXPAND;
   else if(rr >= 1.2 || vel >= 2.0)       s = SN_ACTIVE;
   else if(rr < 0.6)                      s = SN_QUIET;
   if(s == SN_EXPAND || s == SN_FAST)
      G_MST_SENS_HOT = TimeCurrent();
   else if(G_MST_SENS_HOT > 0 && TimeCurrent() - G_MST_SENS_HOT <= 900 && rr < 1.0)
   {
      int md = (c1 > c6) ? 1 : -1;
      if(MBExhaustPressure(md) >= ExhaustCautionScore || MBExhaustPressure(-md) >= ExhaustCautionScore)
         s = SN_EXHAUST;
   }
   return s;
}

void MBMarketStateUpdate()
{
   if(!EnableMarketState || !EnableMarketBrainEngines)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 <= 0 || m1 == G_MST_BAR)
      return;
   G_MST_BAR = m1;
   double atr1 = G_MB_ATR[0] * _Point;

   // Anomaly from the closed bar and the spread.
   if(EnableAnomalyGuard)
   {
      double r1 = iHigh(_Symbol, PERIOD_M1, 1) - iLow(_Symbol, PERIOD_M1, 1);
      double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double norm = MBNormalSpread();
      string w = "";
      if(atr1 > 0.0 && r1 >= 4.0 * atr1) w = StringFormat("M1 bar of %.1f ATR", r1 / atr1);
      else if(norm > 0.0 && spr >= 2.5 * norm) w = StringFormat("spread %.0f = %.1fx normal", spr, spr / norm);
      if(StringLen(w) > 0)
      {
         if(TimeCurrent() >= G_MST_ANOM_UNTIL && StatePrintOnUse && G_VERBOSE)
            PrintFormat("[SIRUS STATE] ABNORMAL - %s", w);
         G_MST_ANOM_UNTIL = TimeCurrent() + MathMax(1, AnomalyCooldownMin) * 60;
         G_MST_ANOM_WHY = w;
      }
   }
   G_MST_SENS = MBSensitivity();

   int P = (G_ST_LOCK_DIR != 0) ? G_ST_LOCK_DIR : ((MBSign(G_MB_BIAS) != 0) ? MBSign(G_MB_BIAS) : G_MB_TREND[2]);
   int st = MST_UNKNOWN, sd = 0;
   datetime lt = 0;
   int lc = 0, lq = 0;
   double le = 0.0;
   int ksw = (G_LQ_SW_TIME[1] > G_LQ_SW_TIME[0]) ? 1 : 0;   // the latest map sweep: 1 = highs taken
   bool recent_sweep = (G_LQ_SW_TIME[ksw] > 0 && TimeCurrent() - G_LQ_SW_TIME[ksw] <= 900 && G_LQ_SW_CLASS[ksw] >= 2 && !G_LQ_SW_TRAP[ksw]);
   bool recent_trap = (G_LQ_SW_TIME[ksw] > 0 && TimeCurrent() - G_LQ_SW_TIME[ksw] <= 1800 && G_LQ_SW_TRAP[ksw]);
   double cl = 0.0;
   bool comp_release = (MBStFind(3, 1, 0, 1, TimeCurrent() - 600, false, cl) > 0 || MBStFind(3, -1, 0, 1, TimeCurrent() - 600, false, cl) > 0) &&
                       (MBEventExists(MB_EV_COMP_RELEASE, 1, 0, 0.0, TimeCurrent() - 600, DBL_MAX) ||
                        MBEventExists(MB_EV_COMP_RELEASE, -1, 0, 0.0, TimeCurrent() - 600, DBL_MAX) ||
                        MBEventExists(MB_EV_COMP_RELEASE, 1, 1, 0.0, TimeCurrent() - 900, DBL_MAX) ||
                        MBEventExists(MB_EV_COMP_RELEASE, -1, 1, 0.0, TimeCurrent() - 900, DBL_MAX));

   if(TimeCurrent() < G_MST_ANOM_UNTIL || G_CAL_ACTIVE)                 { st = MST_NEWS; }
   else if(G_ST_REV_DIR != 0 && G_ST_REV_STAGE >= 5)                     { st = MST_REV_CONFIRMED; sd = G_ST_REV_DIR; }
   else if(G_ST_REV_DIR != 0 && G_ST_REV_STAGE >= 3)                     { st = MST_REV_DEVELOP; sd = G_ST_REV_DIR; }
   else if(recent_sweep)                                                 { st = MST_LIQ_HUNT; sd = (ksw == 1) ? -1 : 1; }
   else if(P != 0 && (MBExhaustPressure(P) >= 60 || G_MST_SENS == SN_EXHAUST)) { st = MST_EXHAUSTION; sd = P; }
   else if(recent_trap)                                                  { st = MST_FAKE_BREAKOUT; sd = (ksw == 1) ? 1 : -1; }
   else if(comp_release && (G_MST_SENS >= SN_ACTIVE))                     { st = MST_BREAKOUT; sd = (iClose(_Symbol, PERIOD_M1, 1) > iClose(_Symbol, PERIOD_M1, 6)) ? 1 : -1; }
   // PACKAGE 5 (B-F5): an expansion is on the side the market is MOVING (the forming M1 displacement,
   // else the M5 pressure, else the last six M1 closes) - it used to take P, the old side, so the judge
   // gave +4 to the stale side and -8 to the side the market was expanding toward. A strong trend needs
   // the bias to point the same way as the regime.
   else if((G_MB_RG == MB_RG_EXPANSION) || G_MST_SENS == SN_EXPAND || G_MST_SENS == SN_FAST)
   {
      int mv = (G_MB_LIVE_DIR != 0) ? G_MB_LIVE_DIR : MBPressureSide(1);
      if(mv == 0)
         mv = (iClose(_Symbol, PERIOD_M1, 1) > iClose(_Symbol, PERIOD_M1, 6)) ? 1 : -1;
      st = MST_EXPANSION;
      sd = (G_MB_RG == MB_RG_EXPANSION && G_MB_RG_DIR != 0) ? G_MB_RG_DIR : mv;
   }
   else if(G_MB_RG == MB_RG_TREND && MathAbs(G_MB_BIAS) >= 3 && MBSign(G_MB_BIAS) == G_MB_RG_DIR &&
           (G_ST_LOCK_DIR == 0 || G_ST_LOCK_DIR == G_MB_RG_DIR))
                                                                         { st = MST_STRONG_TREND; sd = G_MB_RG_DIR; }
   else if(EnableMicroControl && G_MC_TURN == MC_TURN_PULLBACK && P != 0) { st = MST_PULLBACK; sd = P; }
   else if(G_MB_RG == MB_RG_TREND || MathAbs(G_MB_BIAS) >= 2)            { st = MST_TREND; sd = (MathAbs(G_MB_BIAS) >= 2) ? MBSign(G_MB_BIAS) : G_MB_RG_DIR; }
   else if(G_MB_RG == MB_RG_RANGE || G_MB_RG == MB_RG_COMPRESSION)
   {
      // Inside a box: the side whose liquidity was taken last tells accumulation from distribution.
      if(G_LQ_SW_TIME[0] > 0 && TimeCurrent() - G_LQ_SW_TIME[0] <= 7200 && G_LQ_SW_TIME[0] >= G_LQ_SW_TIME[1] && G_MB_DR_POS <= 0.5)
         { st = MST_ACCUMULATION; sd = 1; }
      else if(G_LQ_SW_TIME[1] > 0 && TimeCurrent() - G_LQ_SW_TIME[1] <= 7200 && G_LQ_SW_TIME[1] > G_LQ_SW_TIME[0] && G_MB_DR_POS >= 0.5)
         { st = MST_DISTRIBUTION; sd = -1; }
      else
         st = MST_CHOP;
   }
   else if(EnableMicroControl && MathAbs(G_MC_BUY - 50) < 10)
      st = MST_CHOP;

   if(st != G_MST_STATE || sd != G_MST_DIR)
   {
      if(StatePrintOnUse && G_VERBOSE && G_MST_SINCE > 0)
         PrintFormat("[SIRUS STATE] %s %s -> %s %s (after %d min)", MBStateName(G_MST_STATE), MBDirArrow(G_MST_DIR),
                     MBStateName(st), MBDirArrow(sd), (int)((TimeCurrent() - G_MST_SINCE) / 60));
      G_MST_PREV = G_MST_STATE;
      G_MST_PREV_DIR = G_MST_DIR;
      G_MST_STATE = st;
      G_MST_DIR = sd;
      G_MST_SINCE = TimeCurrent();
   }

   // Scenarios.
   double bull = 0.4 * G_MC_BUY, bear = 0.4 * G_MC_SELL, chop = 0.0;
   if(G_MB_BIAS > 0) bull += 12.0 * G_MB_BIAS; else if(G_MB_BIAS < 0) bear += 12.0 * (-G_MB_BIAS);
   if(G_ST_LOCK_DIR > 0) bull += 15.0; else if(G_ST_LOCK_DIR < 0) bear += 15.0;
   if(G_ST_REV_DIR > 0) bull += 4.0 * G_ST_REV_STAGE; else if(G_ST_REV_DIR < 0) bear += 4.0 * G_ST_REV_STAGE;
   if(G_MB_RG == MB_RG_TREND) { if(G_MB_RG_DIR > 0) bull += 10.0; else bear += 10.0; }
   if(G_MB_RG == MB_RG_RANGE || G_MB_RG == MB_RG_COMPRESSION) chop += 25.0;
   if(MathAbs(G_MC_BUY - 50) < 10) chop += 15.0;
   if(G_MST_SENS == SN_QUIET) chop += 10.0;
   double tot = MathMax(1.0, bull + bear + chop);
   G_SC_BULL = (int)MathRound(100.0 * bull / tot);
   G_SC_BEAR = (int)MathRound(100.0 * bear / tot);
   G_SC_CHOP = MathMax(0, 100 - G_SC_BULL - G_SC_BEAR);
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string wtmp = "";
   G_SC_BULL_TGT = MBLqChampion(1, px, wtmp);
   G_SC_BEAR_TGT = MBLqChampion(-1, px, wtmp);
   G_SC_BULL_INV = (G_ST_PROT_LO[2] > 0.0 && G_ST_PROT_LO[2] < px) ? G_ST_PROT_LO[2] : G_LX_ORIGIN[1];
   G_SC_BEAR_INV = (G_ST_PROT_HI[2] > 0.0 && G_ST_PROT_HI[2] > px) ? G_ST_PROT_HI[2] : G_LX_ORIGIN[0];
   MBScenarioFeedbackBar();

   // Narrative: what happened, where we are, what is awaited.
   string s = "";
   if(G_LQ_SW_TIME[ksw] > 0 && TimeCurrent() - G_LQ_SW_TIME[ksw] <= 14400)
      s += StringFormat("%s likvidlik olindi (%s%s) → ", (ksw == 1 ? "yuqori" : "pastki"), MBLqClassName(G_LQ_SW_CLASS[ksw]),
                        (G_LQ_SW_TRAP[ksw] ? ", tuzoq" : ""));
   if(MathAbs(G_ST_SEQ[2]) >= 2) s += StringFormat("M15 %s×%d buzilish → ", MBDirArrow(G_ST_SEQ[2]), MathAbs(G_ST_SEQ[2]));
   if(G_ST_LOCK_DIR != 0) s += StringFormat("LOCK %s → ", MBDirArrow(G_ST_LOCK_DIR));
   s += StringFormat("%s %s", MBStateName(G_MST_STATE), MBDirArrow(G_MST_DIR));
   string next = "";
   switch(G_MST_STATE)
   {
      case MST_NEWS:          next = "kutish"; break;
      case MST_REV_CONFIRMED: next = "yangi tomonga pullback'dan kirish"; break;
      case MST_REV_DEVELOP:   next = "MSS retesti / higher low kutilmoqda"; break;
      case MST_LIQ_HUNT:      next = "sweep tasdig'i (displacement / MSS) kutilmoqda"; break;
      case MST_EXHAUSTION:    next = "eski tomonga yangi kirish yo'q, burilish dalili kutilmoqda"; break;
      case MST_BREAKOUT:      next = "breakout tomonga erta, retestda"; break;
      case MST_EXPANSION:     next = "faqat kengayish tomonga, erta"; break;
      case MST_FAKE_BREAKOUT: next = "sweep muvaffaqiyatsiz - harakat davom etadi"; break;
      case MST_STRONG_TREND:  next = "trend tomonga, sayoz pullback'da"; break;
      case MST_TREND:         next = "trend tomonga, pullback'da"; break;
      case MST_PULLBACK:      next = "pullback tugashi (M1 burilishi) kutilmoqda"; break;
      case MST_ACCUMULATION:  next = "pastki chekkada BUY, tasdiq bilan"; break;
      case MST_DISTRIBUTION:  next = "yuqori chekkada SELL, tasdiq bilan"; break;
      case MST_CHOP:          next = "faqat chekkalarda, kichik"; break;
      default:               next = "aniq dalil kutilmoqda"; break;
   }
   G_MST_STORY = s + " → " + next;
}

// True = no new entry (abnormal market).
bool MBAnomalyBlocks(string &why)
{
   why = "";
   if(!EnableMarketState || !EnableAnomalyGuard || TimeCurrent() >= G_MST_ANOM_UNTIL)
      return false;
   why = StringFormat("abnormal market: %s - %d s more", G_MST_ANOM_WHY, (int)(G_MST_ANOM_UNTIL - TimeCurrent()));
   return true;
}

// The judge's quality moves with the state.
int MBStateQualityAdj(const int dir)
{
   if(!EnableMarketState || dir == 0)
      return 0;
   int sd = G_MST_DIR;
   switch(G_MST_STATE)
   {
      case MST_STRONG_TREND:
      case MST_TREND:         return (sd == 0) ? 0 : ((dir == sd) ? 4 : -6);
      case MST_PULLBACK:      return (sd == 0) ? 0 : ((dir == sd) ? 4 : -4);
      case MST_REV_CONFIRMED:
      case MST_REV_DEVELOP:   return (dir == sd) ? 6 : -6;
      case MST_EXHAUSTION:    return (dir == sd) ? -6 : 0;
      case MST_LIQ_HUNT:      return (dir == sd) ? 4 : -4;
      case MST_FAKE_BREAKOUT: return (dir == sd) ? 4 : -6;
      case MST_EXPANSION:
      case MST_BREAKOUT:      return (sd == 0) ? 0 : ((dir == sd) ? 4 : -8);
      case MST_ACCUMULATION:
      case MST_DISTRIBUTION:  return (dir == sd) ? 3 : -3;
      case MST_CHOP:          return -4;
      case MST_UNKNOWN:       return -3;
   }
   return 0;
}

string MBStatePanelText()
{
   if(!EnableMarketState || G_MST_BAR <= 0)
      return "";
   string t = StringFormat("Holat: %s %s (%d daq", MBStateName(G_MST_STATE), MBDirArrow(G_MST_DIR), (int)((TimeCurrent() - G_MST_SINCE) / 60));
   if(G_MST_PREV != G_MST_STATE || G_MST_PREV_DIR != G_MST_DIR)
      t += StringFormat(", oldin %s %s", MBStateName(G_MST_PREV), MBDirArrow(G_MST_PREV_DIR));
   t += StringFormat(") · tasma %s", MBSensName(G_MST_SENS));
   return t;
}

// Package 16b: close the followed scenario - one CSV row, the band tally, a journal line.
void MBScenarioFeedbackClose(const string result)
{
   if(G_SCF_DIR == 0)
      return;
   int band = (G_SCF_SHARE >= 75) ? 2 : ((G_SCF_SHARE >= 65) ? 1 : 0);
   if(result == "TARGET" || result == "INVALID")
   {
      G_SCF_N[band]++;
      if(result == "TARGET") G_SCF_HIT[band]++;
   }
   int mins = (int)((TimeCurrent() - G_SCF_OPEN) / 60);
   if(StatePrintOnUse && G_VERBOSE)
      PrintFormat("[SIRUS SCENARIO] %s %d%% %s after %d min | from %s target %s invalid %s | MFE %.0f MAE %.0f pts",
                  (G_SCF_DIR > 0 ? "BULL" : "BEAR"), G_SCF_SHARE, result, mins, DoubleToString(G_SCF_PX, _Digits),
                  DoubleToString(G_SCF_TGT, _Digits), DoubleToString(G_SCF_INV, _Digits), G_SCF_MFE, G_SCF_MAE);
   if(!MQLInfoInteger(MQL_OPTIMIZATION))
   {
      string name = StringFormat("Sirus_Scenario_%s_%I64d.csv", _Symbol, MagicNumber);
      int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(h != INVALID_HANDLE)
      {
         if(FileSize(h) == 0)
            FileWriteString(h, "open;close;side;share;state;start;target;invalid;result;minutes;mfe_pts;mae_pts;target_pts;invalid_pts\r\n");
         FileSeek(h, 0, SEEK_END);
         FileWriteString(h, StringFormat("%s;%s;%s;%d;%s;%s;%s;%s;%s;%d;%.0f;%.0f;%.0f;%.0f\r\n",
                                         TimeToString(G_SCF_OPEN, TIME_DATE | TIME_MINUTES), TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                                         (G_SCF_DIR > 0 ? "BULL" : "BEAR"), G_SCF_SHARE, MBStateName(G_SCF_STATE),
                                         DoubleToString(G_SCF_PX, _Digits), DoubleToString(G_SCF_TGT, _Digits), DoubleToString(G_SCF_INV, _Digits),
                                         result, mins, G_SCF_MFE, G_SCF_MAE,
                                         MathAbs(G_SCF_TGT - G_SCF_PX) / _Point, MathAbs(G_SCF_PX - G_SCF_INV) / _Point));
         FileClose(h);
      }
   }
   G_SCF_DIR = 0;
}

// Package 16b: once per M1 bar - resolve the followed scenario on the closed bar's range, then follow the
// dominant one if nothing is followed (or the dominant side flipped).
void MBScenarioFeedbackBar()
{
   if(!EnableScenarioFeedback)
      return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != G_SCF_DAY)
   {
      G_SCF_DAY = dt.day_of_year;
      ArrayInitialize(G_SCF_HIT, 0);
      ArrayInitialize(G_SCF_N, 0);
   }
   if(G_SCF_DIR != 0)
   {
      double hi = iHigh(_Symbol, PERIOD_M1, 1), lo = iLow(_Symbol, PERIOD_M1, 1);
      if(hi > 0.0 && lo > 0.0)
      {
         double fav = (G_SCF_DIR > 0) ? (hi - G_SCF_PX) : (G_SCF_PX - lo);
         double adv = (G_SCF_DIR > 0) ? (lo - G_SCF_PX) : (G_SCF_PX - hi);
         G_SCF_MFE = MathMax(G_SCF_MFE, fav / _Point);
         G_SCF_MAE = MathMin(G_SCF_MAE, adv / _Point);
         bool to_tgt = (G_SCF_DIR > 0) ? (hi >= G_SCF_TGT) : (lo <= G_SCF_TGT);
         bool to_inv = (G_SCF_DIR > 0) ? (lo <= G_SCF_INV) : (hi >= G_SCF_INV);
         if(to_tgt && to_inv)
            MBScenarioFeedbackClose("BOTH");   // one bar took both - the order inside it is unknown, not counted
         else if(to_tgt)
            MBScenarioFeedbackClose("TARGET");
         else if(to_inv)
            MBScenarioFeedbackClose("INVALID");
         else if(TimeCurrent() - G_SCF_OPEN >= MathMax(1, ScenarioFeedbackHours) * 3600)
            MBScenarioFeedbackClose("TIMEOUT");
      }
   }
   int side = (G_SC_BULL >= ScenarioFeedbackMinShare && G_SC_BULL > G_SC_BEAR) ? 1 :
              ((G_SC_BEAR >= ScenarioFeedbackMinShare && G_SC_BEAR > G_SC_BULL) ? -1 : 0);
   if(side != 0 && G_SCF_DIR == -side)
      MBScenarioFeedbackClose("FLIP");
   if(side == 0 || G_SCF_DIR != 0)
      return;
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tgt = (side > 0) ? G_SC_BULL_TGT : G_SC_BEAR_TGT;
   double inv = (side > 0) ? G_SC_BULL_INV : G_SC_BEAR_INV;
   if(px <= 0.0 || tgt <= 0.0 || inv <= 0.0 || side * (tgt - px) <= 0.0 || side * (px - inv) <= 0.0)
      return;   // a scenario without a target ahead and an invalidation behind cannot be scored
   G_SCF_DIR = side;
   G_SCF_SHARE = (side > 0) ? G_SC_BULL : G_SC_BEAR;
   G_SCF_STATE = G_MST_STATE;
   G_SCF_PX = px;
   G_SCF_TGT = tgt;
   G_SCF_INV = inv;
   G_SCF_MFE = 0.0;
   G_SCF_MAE = 0.0;
   G_SCF_OPEN = TimeCurrent();
}

string MBScenarioFeedbackText()
{
   if(!EnableScenarioFeedback)
      return "";
   string t = "Ssenariy aniqligi (bugun):";
   string band[3] = {"<65%", "65-74%", "75%+"};
   for(int b = 0; b < 3; b++)
      t += StringFormat(" %s %d/%d", band[b], G_SCF_HIT[b], G_SCF_N[b]);
   if(G_SCF_DIR != 0)
      t += StringFormat(" · kuzatilmoqda %s %d%% -> %s", MBDirArrow(G_SCF_DIR), G_SCF_SHARE, DoubleToString(G_SCF_TGT, _Digits));
   return t;
}

string MBScenarioPanelText()
{
   if(!EnableMarketState || G_MST_BAR <= 0)
      return "";
   return StringFormat("Ssenariy: ▲ %d%% (maqsad %s, bekor %s) · ▼ %d%% (maqsad %s, bekor %s) · chop %d%%",
                       G_SC_BULL, (G_SC_BULL_TGT > 0.0 ? DoubleToString(G_SC_BULL_TGT, _Digits) : "-"),
                       (G_SC_BULL_INV > 0.0 ? DoubleToString(G_SC_BULL_INV, _Digits) : "-"),
                       G_SC_BEAR, (G_SC_BEAR_TGT > 0.0 ? DoubleToString(G_SC_BEAR_TGT, _Digits) : "-"),
                       (G_SC_BEAR_INV > 0.0 ? DoubleToString(G_SC_BEAR_INV, _Digits) : "-"), G_SC_CHOP);
}
