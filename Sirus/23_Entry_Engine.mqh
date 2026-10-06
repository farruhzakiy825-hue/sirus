//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 23_Entry_Engine                                 |
//| Market Brain E+F: entry location, timing, quality and the judge  |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// ENTRY ENGINE + ENTRY JUDGE (engine plan, phases 5 and 6)
//---------------------------------------------------------------------
// The veto removes the entries the market has argued against. This stage asks of the ones that
// are left: is THIS the right place and the right moment?
//
// Three independent kinds of evidence (never three indicators):
//   DIRECTION  the Market Brain bias for this side
//   LOCATION   discount for a BUY / premium for a SELL in the H1 dealing range, a zone that holds
//              that role right under / over price, or the first healthy pullback of a young impulse
//   TRIGGER    something happened NOW in this direction: an M1/M5 candle with intent
//              (displacement, rejection, liquidity grab, fake breakout, breakout, continuation),
//              the forming M1 candle displacing, or a fresh liquidity / structure event
//
// Minimum necessary evidence depends on the situation, so a clear trend is not made to wait for
// fifteen confirmations and a counter-move is not taken on one:
//   trend aligned        DIRECTION + LOCATION or TRIGGER
//   neutral              LOCATION + TRIGGER
//   transition toward    TRIGGER + a confirmed liquidity reversal
//   weak opposite        LOCATION + TRIGGER + a confirmed liquidity reversal (V0 already asked
//                        for an exceptional reversal setup)
//
// Timing: a continuation entry after the impulse has run without a healthy pullback is LATE or
// EXPIRED (chasing). And a good signal can become a bad entry without becoming a bad signal: the
// quality decays as price runs away from where the signal first appeared.
//
// The judge turns this into a quality 0..100 and a decision:
//   EXECUTE  open normally
//   CAUTION  open with the lot cut by MBCautionLotFactor
//   WAIT     not now - the setup stays alive and is re-judged on the next tick
//=====================================================================

input group "45 — MARKET BRAIN: ENTRY ENGINE + JUDGE"
input bool   EnableMBEntryJudge       = true;   // Kirish joyi, vaqti va sifati bo'yicha yakuniy qaror: EXECUTE / CAUTION / WAIT
input int    MBEntryExecuteQuality    = 65;     // Sifat >= shu: EXECUTE
input int    MBEntryCautionQuality    = 45;     // Sifat >= shu: CAUTION (kichik lot), undan past: WAIT
input double MBCautionLotFactor       = 0.75;   // CAUTION bo'lganda lot x shu
input double MBEntryDecayPerATR       = 20.0;   // Signal paydo bo'lgandan beri narx har 1 ATR(M1) qochganda sifat shuncha pasayadi
input double MBMaxInvalidationATR5    = 3.0;    // Invalidation darajasi ATR(M5) x shudan uzoq bo'lsa: sifat pasayadi
input bool   MBEntryPrintOnUse        = true;   // Qarorlarni jurnalga yozish ([SIRUS JUDGE])
input bool   EnableMBFastEntry        = true;   // TEZKOR KIRISH: detektor signali kutilmaydi - Market Brain thesis + hozirgi trigger yetarli (veto va judge baribir tekshiradi)
input int    MBReentryWindowBars      = 20;     // Yutgan savat yopilgandan keyin shuncha M1 bar ichida o'sha yo'nalishda tezkor re-entry
input int    MBFastEntryScoreMargin   = 2;      // Tezkor kirishga beriladigan ball: minimum + shu (keyingi ball filtrlaridan o'tishi uchun)
input bool   EnableCashbackTempo      = true;   // CASHBACK TEMPI: faqat cashback rejimida - kirish talablari biroz yumshoq (veto'lar o'zgarmaydi), chunki daromad aylanmadan
input int    CashbackTempoQualityCut  = 10;     // Cashback tempida EHTIYOT / OCHISH sifat chegaralari shuncha pastroq
input int    CashbackReentryBars      = 40;     // Cashback tempida tezkor re-entry oynasi (M1 bar)

#define MB_ED_EXECUTE   0
#define MB_ED_CAUTION   1
#define MB_ED_WAIT      2

int      G_MB_ENTRY_DECISION   = MB_ED_EXECUTE;
int      G_MB_ENTRY_QUALITY    = 0;
string   G_MB_ENTRY_TEXT       = "";
string   G_MB_ENTRY_LAST_PRINT = "";
datetime G_MB_ENTRY_PRINT_TIME = 0;

// Where and when the current signal first appeared (for the entry-quality decay).
int      G_MB_SIG_DIR   = 0;
int      G_MB_SIG_TYPE  = -1;
double   G_MB_SIG_PRICE = 0.0;
datetime G_MB_SIG_TIME  = 0;

string MBEntryDecisionName(const int d)
{
   switch(d)
   {
      case MB_ED_EXECUTE: return "EXECUTE";
      case MB_ED_CAUTION: return "CAUTION";
      case MB_ED_WAIT:    return "WAIT";
   }
   return "?";
}

string MBEntryTypeName(const int dir, const int a)
{
   if(IsReversalOpportunityType(G_OPP_TYPE))
   {
      if(a >= 2)
         return "PULLBACK";
      SMBEvent ev;
      if(MBEventFind(MB_EV_RECLAIM, dir, 0, ev) || MBEventFind(MB_EV_FAKE_BREAK, dir, 0, ev))
         return "LIQUIDITY-RECLAIM";
      return "REVERSAL";
   }
   if(G_OPP_TYPE == OPP_TYPE_BREAKOUT_CONTINUATION || G_OPP_TYPE == OPP_TYPE_DONCHIAN_BREAKOUT ||
      G_OPP_TYPE == OPP_TYPE_EXPANDING_VOLATILITY)
      return "BREAKOUT";
   return "CONTINUATION";
}

bool MBTriggerCandle(const SMBCandle &c, const int dir)
{
   if(c.dir != dir)
      return false;
   return (c.intent == MB_CI_DISPLACEMENT || c.intent == MB_CI_REJECTION || c.intent == MB_CI_LIQ_GRAB ||
           c.intent == MB_CI_FAKE_BREAKOUT || c.intent == MB_CI_BREAKOUT || c.intent == MB_CI_CONTINUATION ||
           c.intent == MB_CI_EXHAUSTION);
}

// A fresh M1 / M5 event in direction dir that can serve as the trigger.
bool MBFreshTriggerEvent(const int dir, string &what)
{
   for(int tfi = 0; tfi <= 1; tfi++)
   {
      int base = tfi * MB_EV_PER_TF;
      for(int i = 0; i < MB_EV_PER_TF; i++)
      {
         int idx = base + i;
         if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dir) continue;
         int ty = G_MB_EV[idx].type;
         if(ty != MB_EV_LIQ_SWEEP && ty != MB_EV_FAKE_BREAK && ty != MB_EV_MSS && ty != MB_EV_RECLAIM &&
            ty != MB_EV_REJECTION && ty != MB_EV_COMP_RELEASE)
            continue;
         if(MBEventAgeBars(G_MB_EV[idx]) > MBFreshLimit(tfi)) continue;
         what = StringFormat("%s %s", MBTFName(tfi), MBEventName(ty));
         return true;
      }
   }
   return false;
}

// The judge. true = the entry may go now (EXECUTE or CAUTION); false = WAIT.
bool MBEntryJudgeAllows(const int dir, string &why)
{
   why = "";
   G_MB_ENTRY_DECISION = MB_ED_EXECUTE;
   if(!EnableMBEntryJudge || !EnableMarketBrain || !EnableMarketBrainEngines || dir == 0)
      return true;

   double price = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   double atr1 = G_MB_ATR[0] * _Point;
   double atr5 = G_MB_ATR[1] * _Point;
   if(price <= 0.0 || atr1 <= 0.0 || atr5 <= 0.0)
      return true;

   int a = dir * G_MB_BIAS;
   string etype = MBEntryTypeName(dir, a);

   // --- DIRECTION ---
   bool dir_ok = (a >= 1) || (a == 0 && dir * G_MB_TF_STATE[1] > 0);

   // --- LOCATION ---
   string loc = "";
   bool range_ok = (G_MB_DR_HI > G_MB_DR_LO);
   bool disc_ok = range_ok && ((dir > 0 && G_MB_DR_POS <= 0.5) || (dir < 0 && G_MB_DR_POS >= 0.5));
   if(disc_ok) loc += StringFormat("%s %.2f", (dir > 0 ? "discount" : "premium"), G_MB_DR_POS);

   bool zone_ok = false;
   if(EnableZoneRoleEngine)
   {
      double lvl = (dir > 0) ? ZoneMapNearestSupport(price) : ZoneMapNearestResistance(price);
      if(lvl > 0.0 && MathAbs(price - lvl) <= atr5)
      {
         SMBZone z;
         if(MBZoneRead(lvl, z) && z.role == dir && !z.pending_break)
         {
            zone_ok = true;
            loc += StringFormat("%s%s %s holds (%s)", (StringLen(loc) > 0 ? ", " : ""),
                                MBZoneRoleName(z.role), DoubleToString(lvl, _Digits), MBZoneStateName(z.state));
         }
      }
   }

   bool pullback_ok = false;
   if(G_MB_IMP_DIR[1] == dir && G_MB_SPEED[1] <= MB_SPEED_NORMAL && G_MB_IMP_WAVES[1] <= 2 &&
      G_MB_IMP_DIR[0] != -dir)
   {
      pullback_ok = true;   // young M5 impulse, entering on its first legs
      loc += StringFormat("%syoung M5 impulse (%s, %d waves)", (StringLen(loc) > 0 ? ", " : ""), MBSpeedName(G_MB_SPEED[1]), G_MB_IMP_WAVES[1]);
   }
   int loc_n = (disc_ok ? 1 : 0) + (zone_ok ? 1 : 0) + (pullback_ok ? 1 : 0);
   bool loc_ok = (loc_n > 0);
   if(!loc_ok) loc = "none";

   // --- TRIGGER ---
   string trig = "";
   bool trig_m1 = MBTriggerCandle(G_MB_LAST[0], dir);
   bool trig_m5 = MBTriggerCandle(G_MB_LAST[1], dir);
   // An M5 trigger is good for its whole bar only while price has not turned half an ATR against it.
   if(trig_m5 && dir * (price - G_MB_LAST[1].close) < -0.5 * atr5)
      trig_m5 = false;
   bool trig_live = (G_MB_LIVE_DIR == dir);
   string ev_what = "";
   bool trig_event = MBFreshTriggerEvent(dir, ev_what);
   if(trig_m1) trig += StringFormat("M1 %s", MBIntentName(G_MB_LAST[0].intent));
   if(trig_m5) trig += StringFormat("%sM5 %s", (StringLen(trig) > 0 ? ", " : ""), MBIntentName(G_MB_LAST[1].intent));
   if(trig_live) trig += StringFormat("%slive early displacement", (StringLen(trig) > 0 ? ", " : ""));
   if(trig_event) trig += StringFormat("%s%s", (StringLen(trig) > 0 ? ", " : ""), ev_what);
   bool trig_ok = trig_m1 || trig_m5 || trig_live || trig_event;
   // A live displacement this way that just gave its strength back cancels the M1 reading (the same
   // minute said the opposite); a closed M5 candle or a fresh event still stands.
   if(G_MB_LIVE_FAILED == dir)
   {
      trig_m1 = false;
      trig_ok = trig_m5 || trig_live || trig_event;
      if(!trig_ok) trig = "live displacement failed";
   }
   if(StringLen(trig) == 0) trig = "none";

   // --- REVERSAL EVIDENCE (needed when not with the trend) ---
   string rev_what = "";
   datetime rev_t = 0;
   bool rev_ok = MBReversalAfter(dir, 1, 4, true, 0, rev_what, rev_t) ||
                 MBReversalAfter(dir, 0, 0, false, 0, rev_what, rev_t);

   // --- TIMING ---
   int chase = 0;
   if(G_MB_IMP_DIR[0] == dir)
   {
      if(G_MB_SPEED[0] == MB_SPEED_EXPIRED) chase = 2;
      else if(G_MB_SPEED[0] == MB_SPEED_LATE) chase = 1;
   }

   // Signal decay: the same signal, price running away from where it first appeared.
   int sig_type = (int)G_OPP_TYPE;
   if(G_MB_SIG_DIR != dir || G_MB_SIG_TYPE != sig_type || (TimeCurrent() - G_MB_SIG_TIME) > 900)
   {
      G_MB_SIG_DIR = dir;
      G_MB_SIG_TYPE = sig_type;
      G_MB_SIG_PRICE = price;
      G_MB_SIG_TIME = TimeCurrent();
   }
   double moved = dir * (price - G_MB_SIG_PRICE) / atr1;
   double decay = (moved > 0.3) ? MBEntryDecayPerATR * (moved - 0.3) : 0.0;

   // Distance to invalidation.
   double inv = (G_MB_TH_DIR == dir && G_MB_TH_INVALID > 0.0) ? G_MB_TH_INVALID : 0.0;
   double inv_atr = (inv > 0.0) ? MathAbs(price - inv) / atr5 : 0.0;
   bool far = (inv > 0.0 && inv_atr > MBMaxInvalidationATR5);

   // --- QUALITY --- (evidence weights learn within ±MBLearnMaxShift once Memory has enough results)
   int align_key = (a >= 3) ? MB_DNA_ALIGN_STRONG : ((a == 2) ? MB_DNA_ALIGN_WEAK : ((a == 1) ? MB_DNA_TRANS_TOWARD : ((a == 0) ? MB_DNA_NEUTRAL : MB_DNA_COUNTER)));
   bool trig_candle = (trig_m1 || trig_m5);
   double f_dir = MBLearnFactor(align_key);
   double f_loc = MBLearnFactorOf(MB_DNA_LOC_DISCOUNT, disc_ok, MB_DNA_LOC_ZONE, zone_ok, MB_DNA_LOC_PULLBACK, pullback_ok);
   double f_trig = MBLearnFactorOf(MB_DNA_TRIG_CANDLE, trig_candle, MB_DNA_TRIG_LIVE, trig_live, MB_DNA_TRIG_EVENT, trig_event);
   double f_rev = MBLearnFactor(MB_DNA_REVERSAL);
   double q = 40.0;
   q += f_dir * ((a >= 3) ? 25.0 : ((a == 2) ? 18.0 : ((a == 1) ? 12.0 : ((a == 0) ? 5.0 : 0.0))));
   if(loc_ok) q += f_loc * (15.0 + ((loc_n >= 2) ? 5.0 : 0.0));
   if(trig_ok) q += f_trig * (15.0 + (trig_event ? 5.0 : 0.0));
   if(rev_ok && a <= 1) q += f_rev * 10.0;
   q -= (chase == 2) ? 30.0 : ((chase == 1) ? 12.0 : 0.0);
   if(far) q -= 10.0;
   if(G_MB_TH_DIR == dir) q -= 8.0 * G_MB_TH_CONTRA;
   q -= decay;
   double press = (dir > 0) ? (G_MB_BULL[0] - G_MB_BEAR[0]) : (G_MB_BEAR[0] - G_MB_BULL[0]);
   q += MathMax(-5.0, MathMin(5.0, press / 10.0));
   q = MathMax(0.0, MathMin(100.0, q));
   G_MB_ENTRY_QUALITY = (int)MathRound(q);

   // --- MINIMUM NECESSARY EVIDENCE ---
   string missing = "";
   if(chase == 2 && !rev_ok)
      missing = StringFormat("chasing: M1 impulse EXPIRED (%.1f ATR without a pullback)", G_MB_IMP_TRAVEL[0]);
   else if(a >= 2)
   {
      if(!(dir_ok && (loc_ok || trig_ok)))
         missing = "trend entry needs a location or a trigger";
   }
   else if(a == 0)
   {
      // Cashback tempo: the target is a few points of spread, so a neutral market needs only a
      // location OR a trigger - the turnover is the income.
      bool neutral_ok = MBCashbackTempo() ? (loc_ok || trig_ok) : (loc_ok && trig_ok);
      if(!neutral_ok)
         missing = StringFormat("neutral market needs location AND trigger (location %s, trigger %s)",
                                (loc_ok ? "ok" : "none"), (trig_ok ? "ok" : "none"));
   }
   else if(a == 1)
   {
      if(!(trig_ok && rev_ok))
         missing = StringFormat("transition entry needs a trigger AND a confirmed liquidity reversal (trigger %s, reversal %s)",
                                (trig_ok ? "ok" : "none"), (rev_ok ? "ok" : "none"));
   }
   else
   {
      if(!(loc_ok && trig_ok && rev_ok))
         missing = "counter-bias entry needs location, trigger and a confirmed liquidity reversal";
   }

   int exec_q = MBEntryExecuteQuality - (MBCashbackTempo() ? MathMax(0, CashbackTempoQualityCut) : 0);
   int caution_q = MBEntryCautionQuality - (MBCashbackTempo() ? MathMax(0, CashbackTempoQualityCut) : 0);
   int decision;
   if(StringLen(missing) > 0)
      decision = MB_ED_WAIT;
   else if(a >= 2 && loc_ok && trig_ok)
      decision = (G_MB_ENTRY_QUALITY >= caution_q) ? MB_ED_EXECUTE : MB_ED_CAUTION;
   else if(G_MB_ENTRY_QUALITY >= exec_q)
      decision = MB_ED_EXECUTE;
   else if(G_MB_ENTRY_QUALITY >= caution_q)
      decision = MB_ED_CAUTION;
   else
   {
      decision = MB_ED_WAIT;
      missing = StringFormat("quality %d below %d", G_MB_ENTRY_QUALITY, caution_q);
   }
   G_MB_ENTRY_DECISION = decision;

   // Entry DNA of this judgement - kept by Memory if the entry fills.
   for(int k = 0; k < MB_DNA_COUNT; k++)
      G_MB_DNA_PENDING[k] = false;
   G_MB_DNA_PENDING[align_key] = true;
   G_MB_DNA_PENDING[MB_DNA_LOC_DISCOUNT] = disc_ok;
   G_MB_DNA_PENDING[MB_DNA_LOC_ZONE] = zone_ok;
   G_MB_DNA_PENDING[MB_DNA_LOC_PULLBACK] = pullback_ok;
   G_MB_DNA_PENDING[MB_DNA_TRIG_CANDLE] = trig_candle && trig_ok;
   G_MB_DNA_PENDING[MB_DNA_TRIG_LIVE] = trig_live && trig_ok;
   G_MB_DNA_PENDING[MB_DNA_TRIG_EVENT] = trig_event;
   G_MB_DNA_PENDING[MB_DNA_REVERSAL] = rev_ok;
   G_MB_DNA_PENDING[MB_DNA_LATE] = (chase >= 1);
   G_MB_DNA_PENDING[MB_DNA_CAUTION] = (decision == MB_ED_CAUTION);
   string htf_what = "";
   datetime htf_t = 0;
   G_MB_DNA_PENDING[MB_DNA_HTF_SWEEP] = MBReversalAfter(dir, 3, 4, true, 0, htf_what, htf_t);
   G_MB_DNA_PENDING[MB_DNA_TYPE_REVERSAL] = IsReversalOpportunityType(G_OPP_TYPE);
   G_MB_DNA_PENDING_QUALITY = G_MB_ENTRY_QUALITY;

   G_MB_ENTRY_TEXT = StringFormat("%s q%d | %s %s | bias %s | location: %s | trigger: %s%s | speed %s%s%s",
                                  MBEntryDecisionName(decision), G_MB_ENTRY_QUALITY, etype, (dir > 0 ? "BUY" : "SELL"),
                                  MBBiasName(G_MB_BIAS), loc, trig,
                                  (rev_ok ? " | reversal: " + rev_what : ""),
                                  (G_MB_IMP_DIR[0] == dir ? MBSpeedName(G_MB_SPEED[0]) : "-"),
                                  (inv > 0.0 ? StringFormat(" | invalid %.1f ATR5", inv_atr) : ""),
                                  (decay > 0.0 ? StringFormat(" | late -%.0f", decay) : ""));

   G_MB_DNA_PENDING_TEXT = G_MB_ENTRY_TEXT;

   if((MBEntryPrintOnUse && VerboseLogs))
   {
      string key = MBEntryDecisionName(decision) + "|" + missing + "|" + etype;
      if(key != G_MB_ENTRY_LAST_PRINT || (TimeCurrent() - G_MB_ENTRY_PRINT_TIME) >= 60)
      {
         PrintFormat("[SIRUS JUDGE] %s%s", G_MB_ENTRY_TEXT, (StringLen(missing) > 0 ? " | WAIT: " + missing : ""));
         G_MB_ENTRY_LAST_PRINT = key;
         G_MB_ENTRY_PRINT_TIME = TimeCurrent();
      }
   }

   if(decision == MB_ED_WAIT)
   {
      why = missing;
      return false;
   }
   return true;
}

//---------------------------------------------------------------------
// FAST ENTRY - the Market Brain as an entry source (speed).
// The old pipeline waits for a detector to fire and for its score to pass, so after a basket
// closes in profit the next one waits for a brand-new signal even though nothing about the market
// has changed. Two fast paths, both still judged by every gate after the score, the veto and the
// Entry Judge:
//   RE-ENTRY  a basket closed in profit within MBReentryWindowBars, its thesis is still open and
//             not contradicted, and there is a trigger now -> same direction again.
//   THESIS    a CONFIRMED thesis with a trend-strength bias, no contradiction, not late, and a
//             trigger now.
//---------------------------------------------------------------------
int      G_MB_LAST_CLOSE_DIR  = 0;     // set by the Position Brain when a basket ends
bool     G_MB_LAST_CLOSE_WIN  = false;
datetime G_MB_LAST_CLOSE_TIME = 0;
int      G_MB_FAST_TODAY      = 0;
int      G_MB_FAST_DAY        = -1;

bool MBHasTriggerNow(const int dir)
{
   string w = "";
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr5 = G_MB_ATR[1] * _Point;
   bool m5 = MBTriggerCandle(G_MB_LAST[1], dir) && !(atr5 > 0.0 && dir * (px - G_MB_LAST[1].close) < -0.5 * atr5);
   bool m1 = MBTriggerCandle(G_MB_LAST[0], dir) && G_MB_LIVE_FAILED != dir;
   return m1 || m5 || (G_MB_LIVE_DIR == dir) || MBFreshTriggerEvent(dir, w);
}

bool MBFastEntryCandidate(int &dir, string &why)
{
   dir = 0;
   why = "";
   if(!EnableMBFastEntry || !EnableMarketBrain || !EnableMarketBrainEngines || G_BASKET_ORDERS > 0)
      return false;

   bool thesis_open = (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED);

   // Re-entry after a win.
   int rd = G_MB_LAST_CLOSE_DIR;
   int reentry_bars = MBCashbackTempo() ? MathMax(MBReentryWindowBars, CashbackReentryBars) : MBReentryWindowBars;
   if(G_MB_LAST_CLOSE_WIN && rd != 0 && (TimeCurrent() - G_MB_LAST_CLOSE_TIME) <= (long)MathMax(1, reentry_bars) * 60)
   {
      bool not_expired = !(G_MB_IMP_DIR[0] == rd && G_MB_SPEED[0] == MB_SPEED_EXPIRED);
      if(rd * G_MB_BIAS >= 1 && thesis_open && G_MB_TH_DIR == rd && G_MB_TH_CONTRA < 2 && not_expired && MBHasTriggerNow(rd))
      {
         dir = rd;
         why = StringFormat("FAST RE-ENTRY %s: last basket won %d min ago, thesis still %s (%s)",
                            (rd > 0 ? "BUY" : "SELL"), (int)((TimeCurrent() - G_MB_LAST_CLOSE_TIME) / 60),
                            MBThesisStateName(G_MB_TH_STATE), MBBiasName(G_MB_BIAS));
      }
   }

   // Thesis entry.
   if(dir == 0)
   {
      int d = MBSign(G_MB_BIAS);
      bool not_late = !(G_MB_IMP_DIR[0] == d && G_MB_SPEED[0] >= MB_SPEED_LATE);
      // Cashback tempo also takes a freshly ACTIVATED thesis and tolerates a medium contradiction.
      bool th_ok = (G_MB_TH_STATE == MB_TH_CONFIRMED) || (MBCashbackTempo() && G_MB_TH_STATE == MB_TH_ACTIVATED);
      int contra_max = MBCashbackTempo() ? 1 : 0;
      if(d != 0 && d * G_MB_BIAS >= 2 && G_MB_TH_DIR == d && th_ok &&
         G_MB_TH_CONTRA <= contra_max && not_late && MBHasTriggerNow(d))
      {
         dir = d;
         why = StringFormat("FAST THESIS %s: %s thesis confirmed (%s %d%%), trigger now",
                            (d > 0 ? "BUY" : "SELL"), (d > 0 ? "bullish" : "bearish"), MBBiasName(G_MB_BIAS), G_MB_BIAS_CONF);
      }
   }

   if(dir == 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != G_MB_FAST_DAY)
   {
      G_MB_FAST_DAY = dt.day_of_year;
      G_MB_FAST_TODAY = 0;
   }
   return true;
}

// Score given to a fast entry so the score-cost gates after the score check judge it fairly.
int MBFastEntryScore(const int min_required)
{
   return min_required + MathMax(0, MBFastEntryScoreMargin);
}

// Called by the first-entry engine after a fill: counts fast entries for the panel.
void MBFastEntryFilled()
{
   if(StringFind(G_OPP_REASON, "FAST ") == 0)
      G_MB_FAST_TODAY++;
}

// Cashback tempo is on: rebate mode with the tempo switch.
bool MBCashbackTempo()
{
   return (EnableRebateMode && EnableCashbackTempo);
}

// Lot step for the first entry: CAUTION trims it.
double MBEntryLotAdjust(const double lot)
{
   if(EnableMBEntryJudge && G_MB_ENTRY_DECISION == MB_ED_CAUTION)
      return lot * MathMax(0.1, MathMin(1.0, MBCautionLotFactor));
   return lot;
}
