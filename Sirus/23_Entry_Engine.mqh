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

input group "BRAIN ▸ Entry engine & judge"
// EnableMBEntryJudge: Kirish joyi, vaqti va sifati bo'yicha yakuniy qaror: EXECUTE / CAUTION / WAIT
input bool   EnableMBEntryJudge       = true;   // Enable mb entry judge
// MBEntryExecuteQuality: Sifat >= shu: EXECUTE
input int    MBEntryExecuteQuality    = 65;   // Brain entry execute quality
// MBEntryCautionQuality: Sifat >= shu: CAUTION (kichik lot), undan past: WAIT
input int    MBEntryCautionQuality    = 45;   // Brain entry caution quality
// MBCautionLotFactor: CAUTION bo'lganda lot x shu
input double MBCautionLotFactor       = 0.75;   // Brain caution lot factor
// MBEntryDecayPerATR: Signal paydo bo'lgandan beri narx har 1 ATR(M1) qochganda sifat shuncha pasayadi
input double MBEntryDecayPerATR       = 20.0;   // Brain entry decay per ATR
// MBMaxInvalidationATR5: Invalidation darajasi ATR(M5) x shudan uzoq bo'lsa: sifat pasayadi
input double MBMaxInvalidationATR5    = 3.0;   // Brain max invalidation ATR 5
// MBEntryPrintOnUse: Qarorlarni jurnalga yozish ([SIRUS JUDGE])
input bool   MBEntryPrintOnUse        = true;   // Brain entry print on use (on/off)
// EnableMBFastEntry: TEZKOR KIRISH: detektor signali kutilmaydi - Market Brain thesis + hozirgi trigger yetarli (veto va judge baribir tekshiradi)
input bool   EnableMBFastEntry        = true;   // Enable mb fast entry
// MBReentryWindowBars: Yutgan savat yopilgandan keyin shuncha M1 bar ichida o'sha yo'nalishda tezkor re-entry
input int    MBReentryWindowBars      = 20;   // Brain reentry window bars
// MBFastEntryScoreMargin: Tezkor kirishga beriladigan ball: minimum + shu (keyingi ball filtrlaridan o'tishi uchun)
input int    MBFastEntryScoreMargin   = 2;   // Brain fast entry score margin
// CashbackTempoQualityCut: Cashback tempida EHTIYOT / OCHISH sifat chegaralari shuncha pastroq
input int    CashbackTempoQualityCut  = 10;   // Cashback tempo quality cut
// CashbackReentryBars: Cashback tempida tezkor re-entry oynasi (M1 bar)
input int    CashbackReentryBars      = 40;   // Cashback reentry bars
// EnableMBScoreRelief: MIYA YENGILLIGI: eski detektor balli yetmasa, lekin Market Brain shu yo'nalishni tasdiqlasa - yetishmagan ball to'ldiriladi. Keyin veto va hakam (joy + trigger) baribir tekshiradi. Miya qarshi yoki neytral bo'lsa yengillik yo'q
input bool   EnableMBScoreRelief      = true;   // Enable mb score relief
// MBReliefStrong: Miya kuchli tomonda (ustun/hukmron) va g'oya ochiq: shuncha ball
input int    MBReliefStrong           = 4;   // Brain relief strong
// MBReliefWeak: Miya uyg'onmoqda (transition) yoki g'oya yo'q: shuncha ball
input int    MBReliefWeak             = 2;   // Brain relief weak
// EnableBrainEntries: MIYA KIRISHLARI: eski detektor balliga bog'liq bo'lmagan oddiy mantiq - trend g'oyasi, likvidlik ovi (sweep), diapazon chekkasi, momentum. Veto, hakam va risk filtrlari baribir tekshiradi
input bool   EnableBrainEntries       = true;   // Enable brain entries
// BrainEntryTrend: Trend: miya tomonda (ustun/hukmron), g'oya ochiq, trigger bor, impuls kech emas
input bool   BrainEntryTrend          = true;   // Brain entry trend (on/off)
// BrainEntrySweep: Likvidlik ovi: LIVE SWEEP yoki yangi M5+ sweep / fake break qaytishi - qaytish tomonga
input bool   BrainEntrySweep          = true;   // Brain entry sweep (on/off)
// BrainEntryRange: Diapazon (M15 rejimi): chekkada qaytish shami
input bool   BrainEntryRange          = true;   // Brain entry range (on/off)
// BrainEntryMomentum: Momentum: jonli yoki hozirgina yopilgan displacement + M5 bosimi shu tomonda, impuls erta
input bool   BrainEntryMomentum       = true;   // Brain entry momentum (on/off)
// EnableJudgeScoreBypass: HAKAM BALL O'RNIDA: eski detektor balli yetmasa, lekin Market Brain hakami shu setupga yuqori sifat bersa - kirish ochiladi
input bool   EnableJudgeScoreBypass   = true;   // Enable judge score bypass
// MBJudgeBypassQuality: Hakam sifati kamida shuncha bo'lsa
input int    MBJudgeBypassQuality     = 65;   // Brain judge bypass quality
// SmartFillMomentumSkip: 14-BOSQICH (C4): momentum lahzasida (jonli displacement, LIVE SWEEP, hozirgina yopilgan M1 displacement) SmartFill pullback kutmaydi - darhol kiradi
input bool   SmartFillMomentumSkip    = true;   // Smart fill momentum skip (on/off)

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

// TREND PULLBACK RESUME: the last closed M1 candle went against dir (the pullback) and price is now
// breaking that candle's far end the trend's way. In a running trend the impulse reads LATE, but the
// entry is taken off the pullback, not at the top of the run.
bool MBPullbackResume(const int dir)
{
   if(dir == 0 || G_MB_LAST[0].candle_color != -dir || G_MB_LAST[0].high <= G_MB_LAST[0].low)
      return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(dir > 0 ? (bid <= G_MB_LAST[0].high) : (bid >= G_MB_LAST[0].low))
      return false;
   // Not on a spent move: M5 impulse not expired, M5 pressure not against.
   if(G_MB_IMP_DIR[1] == dir && G_MB_SPEED[1] >= MB_SPEED_EXPIRED)
      return false;
   return (MBPressureSide(1) != -dir);
}

// Quality of the last judgement (read by the entry gates before this file).
int MBEntryQualityNow()
{
   return G_MB_ENTRY_QUALITY;
}

// A closed M1 (tfi 0) or M5 (tfi 1) candle that is a usable trigger for dir RIGHT NOW:
//   - its intent is a trigger the right way;
//   - M1: no failed live spike the same way this minute;
//   - M5: price has not turned half an ATR against its close;
//   - STAGE 13 (A5): a rejection / liquidity grab / exhaustion candle counts only once price has
//     followed through past the middle of its body, and never after its wick extreme was taken out.
bool MBCandleTriggerNow(const int tfi, const int dir, const double price_in)
{
   // AUDIT FIX: candles are built from the bid - compare them with the bid, not the ask a BUY pays.
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) price = price_in;
   if(!MBTriggerCandle(G_MB_LAST[tfi], dir))
      return false;
   if(tfi == 0 && G_MB_LIVE_FAILED == dir)
      return false;
   if(tfi == 1)
   {
      double atr5 = G_MB_ATR[1] * _Point;
      if(atr5 > 0.0 && dir * (price - G_MB_LAST[1].close) < -0.5 * atr5)
         return false;
   }
   int it = G_MB_LAST[tfi].intent;
   // Stage 17 (B1): a push candle on thin volume is not a trigger.
   if(EnableTickVolume && (it == MB_CI_DISPLACEMENT || it == MB_CI_BREAKOUT || it == MB_CI_CONTINUATION) &&
      G_MB_LAST[tfi].vol_ratio > 0.0 && G_MB_LAST[tfi].vol_ratio < VolumeWeakRatio)
      return false;
   if(EnableRejectionConfirm && (it == MB_CI_REJECTION || it == MB_CI_LIQ_GRAB || it == MB_CI_EXHAUSTION) &&
      G_MB_LAST[tfi].high > G_MB_LAST[tfi].low)
   {
      double mid = 0.5 * (G_MB_LAST[tfi].open + G_MB_LAST[tfi].close);
      double ext = (dir > 0) ? G_MB_LAST[tfi].low : G_MB_LAST[tfi].high;
      if(dir * (price - ext) < 0.0)
         return false;   // the wick it rejected from has been taken out - the rejection failed
      if(dir * (price - mid) <= 0.0)
         return false;   // no follow-through yet
   }
   return true;
}

// A fresh M1 / M5 event in direction dir that can serve as the trigger.
bool MBFreshTriggerEvent(const int dir, string &what)
{
   if(MBLiveSweepFresh(dir, what))   // stage 14 (C1): the sweep seen on the tick, before any bar closes
      return true;
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
   // AUDIT FIX: no market data yet (start-up, a CopyRates sync miss) is not "execute" - the brain is blind.
   if(price <= 0.0 || atr1 <= 0.0 || atr5 <= 0.0 || !G_MB_BRAIN_PRIMED)
   {
      G_MB_ENTRY_DECISION = MB_ED_WAIT;
      why = "entry judge: market data not ready (brain warming up)";
      return false;
   }

   int a = dir * G_MB_BIAS;
   string etype = MBEntryTypeName(dir, a);
   int loc_lv = (a < 0 && MBLocalOkFor(dir)) ? MBLocalLevel(dir) : 0;   // a tradable local leg against the global bias

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
   // STAGE 13 (A2): the three pressure readings. All three this way = the move is with us; M15 this
   // way with M1 / M5 against = a pullback inside it (a location); M15 and M5 both against = tired.
   int p1 = MBPressureSide(0), p5 = MBPressureSide(1), p15 = MBPressureSide(2);
   bool press_aligned = EnableCandleDirectionLink && p1 == dir && p5 == dir && p15 == dir;
   bool press_pullback = EnableCandleDirectionLink && p15 == dir && (p1 == -dir || p5 == -dir);
   bool press_tired = EnableCandleDirectionLink && p15 == -dir && p5 == -dir;
   if(press_pullback && !pullback_ok)
   {
      pullback_ok = true;
      loc += StringFormat("%spullback inside M15 pressure", (StringLen(loc) > 0 ? ", " : ""));
   }
   // STAGE 15 (A6): first return into an unfilled FVG left by the move this way - where the
   // displacement's unfilled orders sit. Only the first touch counts (a touched gap is filled).
   bool fvg_ok = false;
   if(EnableFVGZones)
   {
      FVGCacheRefresh();
      int fn = (dir > 0) ? G_FVG_BU_N : G_FVG_BE_N;
      for(int k = 0; k < fn && !fvg_ok; k++)
      {
         double glo = (dir > 0) ? G_FVG_BU_LO[k] : G_FVG_BE_LO[k];
         double ghi = (dir > 0) ? G_FVG_BU_HI[k] : G_FVG_BE_HI[k];
         bool in_gap = (dir > 0) ? (price >= glo - 0.1 * atr5 && price <= ghi + 0.2 * atr5)
                                 : (price <= ghi + 0.1 * atr5 && price >= glo - 0.2 * atr5);
         if(in_gap)
         {
            fvg_ok = true;
            loc += StringFormat("%sFVG retest %s-%s", (StringLen(loc) > 0 ? ", " : ""),
                                DoubleToString(glo, _Digits), DoubleToString(ghi, _Digits));
         }
      }
   }
   // STAGE 15 (D1): where in the regime box. RANGE edges are the place; the middle is not.
   int rg = EnableRegimePlaybook ? G_MB_RG : MB_RG_NONE;
   double rg_pos = (G_MB_RG_HI > G_MB_RG_LO) ? (price - G_MB_RG_LO) / (G_MB_RG_HI - G_MB_RG_LO) : 0.5;
   bool range_edge = (rg == MB_RG_RANGE) && ((dir > 0 && rg_pos <= RegimeRangeEdge) || (dir < 0 && rg_pos >= 1.0 - RegimeRangeEdge));
   bool range_mid = (rg == MB_RG_RANGE) && !range_edge && rg_pos > RegimeRangeEdge && rg_pos < 1.0 - RegimeRangeEdge;
   if(range_edge)
      loc += StringFormat("%srange edge %.2f", (StringLen(loc) > 0 ? ", " : ""), rg_pos);
   // The level that was just swept and reclaimed is a location by definition; so is the start of a
   // live impulse (EARLY speed).
   string lsw_loc = "";
   bool swept_loc = MBLiveSweepFresh(dir, lsw_loc);
   // Plan stage 1: the held retest of a reversal's MSS level is a location by definition.
   int st_stage = MBStructStageFor(dir);
   bool retest_loc = (st_stage >= MathMax(1, LockUnlockStage));
   if(retest_loc) loc += StringFormat("%sreversal retest (stage %d)", (StringLen(loc) > 0 ? ", " : ""), st_stage);
   bool early_loc = (G_MB_LIVE_DIR == dir && !(G_MB_IMP_DIR[0] == dir && G_MB_SPEED[0] >= MB_SPEED_NORMAL));
   if(swept_loc) loc += StringFormat("%sswept pool", (StringLen(loc) > 0 ? ", " : ""));
   if(early_loc) loc += StringFormat("%searly live impulse", (StringLen(loc) > 0 ? ", " : ""));
   int loc_n = (disc_ok ? 1 : 0) + (zone_ok ? 1 : 0) + (pullback_ok ? 1 : 0) + (fvg_ok ? 1 : 0) + (range_edge ? 1 : 0) +
               (swept_loc ? 1 : 0) + (early_loc ? 1 : 0) + (retest_loc ? 1 : 0);
   bool loc_ok = (loc_n > 0);
   if(!loc_ok) loc = "none";

   // --- TRIGGER ---
   string trig = "";
   bool trig_m1 = MBCandleTriggerNow(0, dir, price);
   bool trig_m5 = MBCandleTriggerNow(1, dir, price);
   bool trig_live = (G_MB_LIVE_DIR == dir);
   string ev_what = "";
   bool trig_event = MBFreshTriggerEvent(dir, ev_what);
   if(trig_m1) trig += StringFormat("M1 %s", MBIntentName(G_MB_LAST[0].intent));
   if(trig_m5) trig += StringFormat("%sM5 %s", (StringLen(trig) > 0 ? ", " : ""), MBIntentName(G_MB_LAST[1].intent));
   if(trig_live) trig += StringFormat("%slive early displacement", (StringLen(trig) > 0 ? ", " : ""));
   if(trig_event) trig += StringFormat("%s%s", (StringLen(trig) > 0 ? ", " : ""), ev_what);
   // STAGE 15 (A3): M5 sequence "pressure resumes after a one-candle pause" is a trigger this way.
   bool trig_seq = EnableCandleDirectionLink && G_MB_SEQ_STORY[1] == 1 && G_MB_SEQ_DIR[1] == dir;
   if(trig_seq) trig += StringFormat("%sM5 pressure resumes", (StringLen(trig) > 0 ? ", " : ""));
   bool seq_against = EnableCandleDirectionLink && G_MB_SEQ_STORY[1] == 2 && G_MB_SEQ_DIR[1] == -dir;
   bool trig_ok = trig_m1 || trig_m5 || trig_live || trig_event || trig_seq;
   // (A failed live spike this way already cancelled the M1 reading in MBCandleTriggerNow.)
   if(!trig_ok && G_MB_LIVE_FAILED == dir)
      trig = "live displacement failed";
   if(StringLen(trig) == 0) trig = "none";

   // --- REVERSAL EVIDENCE (needed when not with the trend) ---
   string rev_what = "";
   datetime rev_t = 0;
   bool rev_ok = MBReversalAfter(dir, 1, 4, true, 0, rev_what, rev_t) ||
                 MBReversalAfter(dir, 0, 0, false, 0, rev_what, rev_t) ||
                 st_stage >= MathMax(1, LockUnlockStage);

   // --- TIMING ---
   int chase = 0;
   if(G_MB_IMP_DIR[0] == dir)
   {
      if(G_MB_SPEED[0] == MB_SPEED_EXPIRED) chase = 2;
      else if(G_MB_SPEED[0] == MB_SPEED_LATE) chase = 1;
   }
   // LOCK FIX: an M1 leg reads EXPIRED inside a young M5 impulse - the M5 leg says it is still early.
   if(chase > 0 && G_MB_IMP_DIR[1] == dir && G_MB_SPEED[1] == MB_SPEED_EARLY)
      chase--;
   // Off a pullback the trend is resuming from a better price - one step less of a chase.
   bool pb_resume = (a >= 2 && MBPullbackResume(dir));
   if(pb_resume && chase > 0)
   {
      chase--;
      trig_ok = true;
      if(trig == "none" || StringLen(trig) == 0) trig = "pullback resume";
      else trig += ", pullback resume";
   }

   // Signal decay: the same signal, price running away from where it first appeared.
   int sig_type = (int)G_OPP_TYPE;
   // LOCK FIX: the anchor used to live 15 minutes, so a running trend decayed every entry into WAIT
   // and then re-anchored at the extended price. Now: 3 minutes, and a live trigger (live
   // displacement / live sweep / pullback resume) is a new signal from here.
   bool fresh_sig = trig_live || (trig_event && StringFind(ev_what, "LIVE") == 0) || (a >= 2 && MBPullbackResume(dir));
   // AUDIT FIX: the judge-bypass probe (the scanner's side) and the final call (a fast entry's side /
   // type) re-anchored each other every tick, so the decay never built up - only the final call anchors.
   if(!G_MB_JUDGE_PROBE &&
      (G_MB_SIG_DIR != dir || G_MB_SIG_TYPE != sig_type || (TimeCurrent() - G_MB_SIG_TIME) > 180 || fresh_sig))
   {
      G_MB_SIG_DIR = dir;
      G_MB_SIG_TYPE = sig_type;
      G_MB_SIG_PRICE = price;
      G_MB_SIG_TIME = TimeCurrent();
   }
   double moved = (G_MB_SIG_DIR == dir && G_MB_SIG_PRICE > 0.0) ? dir * (price - G_MB_SIG_PRICE) / atr1 : 0.0;
   double decay = (moved > 0.3) ? MBEntryDecayPerATR * (moved - 0.3) : 0.0;
   if(a >= 2 && loc_ok && trig_ok)
      decay = 0.0;   // trend + place + trigger now: the impulse speed judges lateness, not the anchor

   // Distance to invalidation.
   double inv = (G_MB_TH_DIR == dir && G_MB_TH_INVALID > 0.0) ? G_MB_TH_INVALID : 0.0;
   double inv_atr = (inv > 0.0) ? MathAbs(price - inv) / atr5 : 0.0;
   // A cashback basket targets a few points and the basket stop is the account's, not the thesis
   // line - a far invalidation is not this trade's risk. Lateness is still caught by the impulse speed.
   bool far = (inv > 0.0 && inv_atr > MBMaxInvalidationATR5) && !MBCashbackTempo();

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
   // STAGE 15: playbook, candles and FVG.
   if(fvg_ok) q += 5.0;
   if(st_stage >= MathMax(1, LockUnlockStage)) q += 8.0;   // a mature reversal (retest held) this way
   if(loc_lv >= 2) q += 15.0; else if(loc_lv == 1) q += 10.0;   // local leg against the global bias
   if(seq_against) q -= 6.0;   // an M5 reversal is forming against this entry
   bool rg_live_break = (trig_live || (trig_event && StringFind(ev_what, "LIVE") == 0) ||
                         (trig_event && StringFind(ev_what, "COMP-RELEASE") >= 0));
   if(rg == MB_RG_TREND)            q += (dir == G_MB_RG_DIR) ? 4.0 : -4.0;
   else if(rg == MB_RG_RANGE)       q += range_edge ? 5.0 : (range_mid ? -8.0 : 0.0);
   else if(rg == MB_RG_EXPANSION)   q += (dir == G_MB_RG_DIR) ? 4.0 : 0.0;
   else if(rg == MB_RG_COMPRESSION) q += rg_live_break ? 4.0 : -6.0;

   // STAGE 17: volume, tick flow, session sweeps, sweep statistics, three-layer location, volatility.
   bool vol_strong = EnableTickVolume && ((trig_m1 && G_MB_LAST[0].vol_ratio >= VolumeStrongRatio) ||
                                          (trig_m5 && G_MB_LAST[1].vol_ratio >= VolumeStrongRatio));
   if(vol_strong) q += 3.0;
   double flow = dir * G_MB_FLOW_IMB;
   bool flow_against = EnableTickFlow && G_MB_FLOW_N >= 20 && flow <= -TickFlowBlock;
   if(EnableTickFlow && G_MB_FLOW_N >= 20 && flow >= 0.30) q += 3.0;
   string lsw_w = "";
   bool lsw_trig = MBLiveSweepFresh(dir, lsw_w);
   if(lsw_trig && G_MB_LSW_KIND == 1 && MBSessionOpenWindow()) q += 6.0;   // B2: Asia / PDH / PDL taken at a session open
   int ss_n = 0;
   double ss_edge = lsw_trig ? MBSweepEdge(G_MB_LSW_KIND, MBSessionNow(), ss_n) : -1.0;
   if(ss_edge >= 0.60) q += 4.0;
   else if(ss_edge >= 0.0 && ss_edge < 0.40) q -= 6.0;                     // D3: this kind of sweep here usually fails
   int cheap = 0, layers = 0;
   if(G_MB_DR_HI > G_MB_DR_LO) { layers++; if((dir > 0 && G_MB_DR_POS <= 0.5) || (dir < 0 && G_MB_DR_POS >= 0.5)) cheap++; }
   if(G_MB_RG_HI > G_MB_RG_LO) { layers++; if((dir > 0 && rg_pos <= 0.5) || (dir < 0 && rg_pos >= 0.5)) cheap++; }
   if(G_MB_H4_HI > G_MB_H4_LO)
   {
      double p4 = (price - G_MB_H4_LO) / (G_MB_H4_HI - G_MB_H4_LO);
      layers++;
      if((dir > 0 && p4 <= 0.5) || (dir < 0 && p4 >= 0.5)) cheap++;
   }
   bool all_cheap = (layers >= 3 && cheap == layers);
   bool all_dear = (layers >= 3 && cheap == 0);
   if(all_cheap) q += 5.0;
   if(G_MB_VOL_PCT >= 0.0 && G_MB_VOL_PCT < 10.0) q -= 4.0;                // a dead market: the spread is the move
   if(EnableCandleDirectionLink)
   {
      if(press_aligned) q += 6.0;
      if(press_tired)   q -= 8.0;
   }
   else
   {
      double press = (dir > 0) ? (G_MB_BULL[0] - G_MB_BEAR[0]) : (G_MB_BEAR[0] - G_MB_BULL[0]);
      q += MathMax(-5.0, MathMin(5.0, press / 10.0));
   }
   // Plan stage 2: pressure against continuing this way costs quality from ExhaustCautionScore up
   // (from ExhaustBlockScore the veto refuses it outright).
   q += MBMicroQualityAdj(dir);   // plan stage 4: who controls now + the micro turn type
   q += MBStateQualityAdj(dir);   // plan stage 8: adaptive weighting by market state
   int xp = MBExhaustPressure(dir);
   if(ExhaustCautionScore > 0 && xp >= ExhaustCautionScore)
      q -= 0.5 * (xp - ExhaustCautionScore + 10);
   q = MathMax(0.0, MathMin(100.0, q));
   G_MB_ENTRY_QUALITY = (int)MathRound(q);

   // --- MINIMUM NECESSARY EVIDENCE ---
   string missing = "";
   // STAGE 15 (D1): the playbook's hard lines - never against an expansion, and never against a
   // trend regime the brain does not side with, without a confirmed liquidity reversal.
   // READ THE CANDLES FIRST (owner rule): reaching a zone is not a reason to enter.
   //  - a local leg running against this entry (local layer, M1 and M5 pressure all the other way,
   //    the leg not spent) - do not stand in front of it unless a strong reversal candle is here;
   //  - the last closed candles still pushing the other way - wait;
   //  - an entry whose only reason is a zone / range edge / FVG needs a reaction candle there.
   bool rev_candle = (G_MB_LIVE_DIR == dir || MBCandleConfirms(0, dir) || MBCandleConfirms(1, dir));
   bool leg_against = (MBLayerLocal() == -dir && MBPressureSide(0) == -dir && MBPressureSide(1) == -dir &&
                       !MBLocalLegSpent(-dir) && !rev_candle);
   bool candles_against = (MBCandleOpposes(0, dir) && (MBCandleOpposes(1, dir) || MBPressureSide(0) == -dir) &&
                           G_MB_LIVE_DIR != dir);
   bool zone_only = (zone_ok || range_edge || fvg_ok) && !(pullback_ok || early_loc || swept_loc || disc_ok || retest_loc);
   bool reaction = MBReactionCandle(dir) ||
                   (trig_event && (StringFind(ev_what, "REJECTION") >= 0 || StringFind(ev_what, "SWEEP") >= 0 ||
                                   StringFind(ev_what, "FAKE") >= 0 || StringFind(ev_what, "RECLAIM") >= 0));
   // FIX(sell-into-bull): a tired move (M5 AND M15 pressure the other way) only downgraded the entry
   // to CAUTION, and CAUTION trades full size (MinFirstEntryLotFactor = 1.0) - so a SELL went in while
   // the M5 and M15 candles were bullish. Now it waits for a closed M5 candle that turns (a fresh
   // sweep alone no longer counts). And a pullback still running on M1 AND M5 waits for M1 to turn.
   bool turn5 = MBCandleConfirms(1, dir);   // COUNCIL (2): a closed M5 candle - a sweep is not its own proof
   bool tired_block = EnableCandleReadingGate && press_tired && !turn5;
   bool pb_running = EnableCandleReadingGate && p5 == -dir && p1 == -dir && !rev_candle;
   if(leg_against)
      missing = "a local leg is running against this entry (local layer and M1/M5 pressure the other way, not spent)";
   else if(candles_against)
      missing = "the last candles still push the other way - waiting for them to turn";
   else if(tired_block)
      missing = "M5 and M15 candles both push the other way - waiting for an M5 candle that turns";
   else if(pb_running)
      missing = "the move against is still running on M1 and M5 - waiting for the M1 candle to turn";
   else if(zone_only && !reaction)
      missing = "at the zone - waiting for a reaction candle (rejection / grab / displacement)";
   else if(flow_against)
      missing = StringFormat("tick flow against: imbalance %.0f%% the other way over %d ticks", -flow * 100.0, G_MB_FLOW_N);
   else if(rg == MB_RG_EXPANSION && dir == -G_MB_RG_DIR && !rev_ok)
      missing = "playbook: against an M15 expansion without a confirmed reversal";
   else if(rg == MB_RG_TREND && dir == -G_MB_RG_DIR && a <= 0 && !rev_ok && loc_lv == 0)
      missing = "playbook: against the M15 trend regime without a confirmed reversal";
   else if(chase == 2 && !rev_ok)
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
      // LOCK FIX: a breakdown without a sweep never has a "confirmed liquidity reversal"; a strong
      // candle the new way (displacement / rejection / grab) on M1 or M5, or a live one, is the proof.
      // A confirmed turn (local, M5 and control all this way) is the proof too - V0 takes it as well.
      bool mom_conf = (G_MB_LIVE_DIR == dir || MBCandleConfirms(0, dir) || MBCandleConfirms(1, dir) || MBTransitionConfirmed(dir));
      if(!(trig_ok && (rev_ok || mom_conf)))
         missing = StringFormat("transition entry needs a trigger AND a confirmed liquidity reversal (trigger %s, reversal %s)",
                                (trig_ok ? "ok" : "none"), (rev_ok ? "ok" : "none"));
   }
   else if(a >= -2 && MBRangeRules())
   {
      // A range trade against a weak global bias: what a range trade needs - a place and a trigger.
      bool range_ok = MBCashbackTempo() ? (loc_ok || trig_ok) && trig_ok : (loc_ok && trig_ok);
      if(!range_ok)
         missing = StringFormat("range trade needs location AND trigger (location %s, trigger %s)",
                                (loc_ok ? "ok" : "none"), (trig_ok ? "ok" : "none"));
   }
   else if(loc_lv >= 1)
   {
      // A local leg against the global bias: the local structure stands in for the reversal proof,
      // but it still needs a trigger, and a place unless the local case is strong.
      if(!(trig_ok && (loc_ok || loc_lv >= 2)))
         missing = StringFormat("local entry needs a trigger and a location (trigger %s, location %s)",
                                (trig_ok ? "ok" : "none"), (loc_ok ? "ok" : "none"));
   }
   else
   {
      if(!(loc_ok && trig_ok && rev_ok))
         missing = "counter-bias entry needs location, trigger and a confirmed liquidity reversal";
   }

   int exec_q = MBEntryExecuteQuality - (MBCashbackTempo() ? MathMax(0, CashbackTempoQualityCut) : 0);
   int caution_q = MBEntryCautionQuality - (MBCashbackTempo() ? MathMax(0, CashbackTempoQualityCut) : 0);
   if(MBShadowValveOn(GATE_MBJUDGE)) { exec_q -= 10; caution_q -= 10; }   // shadow valve on the judge
   // Plan stage 2: COUNTER-TREND TAX - against a strong bias without a mature reversal, more quality.
   if(a <= -2 && st_stage < MathMax(1, LockUnlockStage) && CounterTrendTax > 0)
   {
      exec_q += CounterTrendTax;
      caution_q += CounterTrendTax;
   }
   int decision;
   if(StringLen(missing) > 0)
      decision = MB_ED_WAIT;
   else if(a >= 2 && loc_ok && trig_ok)
   {
      // AUDIT FIX: favoured, but not immune - heavy decay / chase / contradiction still means WAIT.
      if(G_MB_ENTRY_QUALITY >= caution_q)           decision = MB_ED_EXECUTE;
      else if(G_MB_ENTRY_QUALITY >= caution_q - 10) decision = MB_ED_CAUTION;
      else
      {
         decision = MB_ED_WAIT;
         missing = StringFormat("trend entry quality %d far below %d", G_MB_ENTRY_QUALITY, caution_q);
      }
   }
   else if(G_MB_ENTRY_QUALITY >= exec_q)
      decision = MB_ED_EXECUTE;
   else if(G_MB_ENTRY_QUALITY >= caution_q)
      decision = MB_ED_CAUTION;
   else
   {
      decision = MB_ED_WAIT;
      missing = StringFormat("quality %d below %d", G_MB_ENTRY_QUALITY, caution_q);
   }
   // A tired move (M15 and M5 pressure both against) is never a full-size entry.
   if(decision == MB_ED_EXECUTE && press_tired)
      decision = MB_ED_CAUTION;
   // Middle of a range, or inside a compression without a break: a coin flip is never full size.
   if(decision == MB_ED_EXECUTE && (range_mid || (rg == MB_RG_COMPRESSION && !rg_live_break)))
      decision = MB_ED_CAUTION;
   // Stage 17: buying the top of every range (H1, M15, H4) or trading a wild market is never full size.
   if(decision == MB_ED_EXECUTE && (all_dear || (G_MB_VOL_PCT >= 92.0)))
      decision = MB_ED_CAUTION;
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
int      G_MB_FAST_TYPE       = 0;     // ENUM_OPPORTUNITY_TYPE the brain entry carries (V0 reads the type)
string   G_MB_ENTRY_KIND      = "";    // what opened the current basket (panel)
int      G_MB_FAST_DAY        = -1;

bool MBHasTriggerNow(const int dir)
{
   string w = "";
   double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   return MBCandleTriggerNow(0, dir, px) || MBCandleTriggerNow(1, dir, px) ||
          (G_MB_LIVE_DIR == dir) || MBFreshTriggerEvent(dir, w);
}

// May a brain entry go this way? With the global bias, or neutral - or against it on a local leg
// (a strong one against the strongest bias).
bool MBDirOk(const int d)
{
   string lw = "", lu = "";
   if(MBLockBlocks(d, lw))
      return false;   // direction lock (plan stage 1)
   if(MBLateBlocks(d, lw, lu))
      return false;   // late / exhausted / target taken (plan stage 2)
   if(MBReentryBlocks(d, lw, lu))
      return false;   // re-entry after a dead idea / failed attempts (plan stage 4)
   if(MBCostBlocks(d, lw, lu))
      return false;   // abnormal spread / no room for the cost (plan stage 6)
   if(MBAnomalyBlocks(lw))
      return false;   // abnormal market (plan stage 8)
   if(!MBCouncilOk(d))
      return false;   // the council (local + candles + zone) refuses this side - leave room for the other
   int a = d * G_MB_BIAS;
   if(a >= 0)
      return true;
   if(a >= -2 && MBRangeRules())
      return true;   // range / compression: both edges
   return MBLocalOkFor(d);
}

// AUDIT FIX (tie): the two-sided candidate loops (SWEEP, MOMENTUM, ALIGNED) always tried SELL first, so
// when both sides qualified on the same tick SELL won every time. The side tried first is now the one
// the market prefers: the global bias, else the local leg, else the control share; a true tie alternates.
int MBTieFirst()
{
   if(G_MB_BIAS != 0)
      return MBSign(G_MB_BIAS);
   int loc = MBLayerLocal();
   if(loc != 0)
      return loc;
   if(G_MC_BUY != G_MC_SELL)
      return (G_MC_BUY > G_MC_SELL) ? 1 : -1;
   return (G_TICK_COUNT % 2 == 0) ? 1 : -1;
}

// AUDIT FIX (B2): a candidate is taken only if the veto would let it through - MBDirOk (lock, late,
// re-entry, cost, anomaly, council, local) AND the V0 permission for the type it will carry. Before,
// FAST RE-ENTRY / TREND / HANDOFF / PULLBACK / LOCAL skipped part of that, were found, then vetoed on
// every tick - and since only the first candidate counts, they hid every other setup for up to 40 min.
bool MBCandOk(const int d, const int type)
{
   if(d == 0 || !MBDirOk(d))
      return false;
   ENUM_OPPORTUNITY_TYPE keep_type = G_OPP_TYPE;
   int keep_score = G_SCORE_FINAL;
   G_OPP_TYPE = (ENUM_OPPORTUNITY_TYPE)type;
   G_SCORE_FINAL = MathMax(G_SCORE_FINAL, G_SCORE_MIN_REQUIRED + 2);   // what the fast path will stamp
   string w = "";
   bool blocked = MBPermissionCheck(d, w);
   G_OPP_TYPE = keep_type;
   G_SCORE_FINAL = keep_score;
   return !blocked;
}

// The fast-entry count survives a recompile / restart (it read "tezkor 0" after every reload while the
// day's entry total, read from history, did not). Stored with its day in a terminal variable.
string G_MB_FAST_WHYNOT[2];   // why no brain entry fired this side (0 = SELL, 1 = BUY) - panel

string MBFastCountKey() { return StringFormat("SIRUS_FAST_%s_%I64d", _Symbol, MagicNumber); }

void MBFastCountSave()
{
   if(MQLInfoInteger(MQL_TESTER))
      return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   GlobalVariableSet(MBFastCountKey(), (double)(dt.year * 1000 + dt.day_of_year) * 10000.0 + G_MB_FAST_TODAY);
}

int MBFastToday()
{
   static bool loaded = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(!loaded)
   {
      loaded = true;
      G_MB_FAST_DAY = dt.day_of_year;
      if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(MBFastCountKey()))
      {
         double v = GlobalVariableGet(MBFastCountKey());
         int day = (int)MathFloor(v / 10000.0);
         if(day == dt.year * 1000 + dt.day_of_year)
            G_MB_FAST_TODAY = (int)MathRound(v - day * 10000.0);
      }
   }
   if(dt.day_of_year != G_MB_FAST_DAY)
   {
      G_MB_FAST_DAY = dt.day_of_year;
      G_MB_FAST_TODAY = 0;
   }
   return G_MB_FAST_TODAY;
}

// Why the brain is not entering, per side, in a few words - read once a second, only while flat and
// no candidate fired. Order: the council, the global permission, the trigger, then "no setup".
void MBFastWhyNotUpdate()
{
   static datetime last = 0;
   if(TimeCurrent() == last)
      return;
   last = TimeCurrent();
   for(int k = 0; k <= 1; k++)
   {
      int d = (k == 1) ? 1 : -1;
      string w = "", wu = "";
      if(MBAnomalyBlocks(w))
         G_MB_FAST_WHYNOT[k] = "g'ayritabiiy bozor";
      else if(MBLockBlocks(d, w))
         G_MB_FAST_WHYNOT[k] = StringFormat("LOCK %s, burilish %d/%d", (G_ST_LOCK_DIR > 0 ? "▲" : "▼"), MBStructStageFor(d), LockUnlockStage);
      else if(MBLateBlocks(d, w, wu))
         G_MB_FAST_WHYNOT[k] = wu;
      else if(MBReentryBlocks(d, w, wu))
         G_MB_FAST_WHYNOT[k] = wu;
      else if(MBCostBlocks(d, w, wu))
         G_MB_FAST_WHYNOT[k] = wu;
      else if(MBCouncilBlocks(d, w))
         G_MB_FAST_WHYNOT[k] = "kengash: " + G_MB_COUNCIL_UZ[k];
      else if(!MBDirOk(d))
         G_MB_FAST_WHYNOT[k] = StringFormat("global qarshi (%s)", MBBiasName(G_MB_BIAS));
      else if(!MBHasTriggerNow(d))
         G_MB_FAST_WHYNOT[k] = "trigger yo'q (sham / hodisa)";
      else
         G_MB_FAST_WHYNOT[k] = "trigger bor, setup sharti yo'q";
   }
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
      string aw_re = "";
      // Cashback tempo: the basket just paid this way and the thesis is still open - a neutral
      // bias (hysteresis catching up) does not stop the next one. Against-bias still does.
      int bias_min = MBCashbackTempo() ? 0 : 1;
      // AUDIT FIX: at a transition (a == 1) V0 takes only reversal-type entries - a fast re-entry
      // stamped TREND_RIDE there would always be vetoed.
      int ra = rd * G_MB_BIAS;
      bool ra_ok = (ra >= 2) || (ra == 0 && bias_min == 0) ||
                   (ra == 1 && IsReversalOpportunityType(G_OPP_TYPE) && G_OPP_DIR == (rd > 0 ? OPP_DIR_BUY : OPP_DIR_SELL)) ||
                   (ra == 1 && MBTransitionConfirmed(rd));   // a confirmed turn admits continuation (V0)
      int re_type = (IsReversalOpportunityType(G_OPP_TYPE) && G_OPP_DIR == (rd > 0 ? OPP_DIR_BUY : OPP_DIR_SELL)) ? (int)G_OPP_TYPE : (int)OPP_TYPE_TREND_RIDE;
      if(ra >= bias_min && ra_ok && thesis_open && G_MB_TH_DIR == rd && G_MB_TH_CONTRA < 2 && not_expired && MBCandOk(rd, re_type) && MBReentryFastOk(rd) && !MBTrendUnderAttack(rd, aw_re) && MBHasTriggerNow(rd))
      {
         dir = rd;
         why = StringFormat("FAST RE-ENTRY %s: last basket won %d min ago, thesis still %s (%s)",
                            (rd > 0 ? "BUY" : "SELL"), (int)((TimeCurrent() - G_MB_LAST_CLOSE_TIME) / 60),
                            MBThesisStateName(G_MB_TH_STATE), MBBiasName(G_MB_BIAS));
      }
   }

   G_MB_FAST_TYPE = (int)OPP_TYPE_TREND_RIDE;
   if(dir != 0 && IsReversalOpportunityType(G_OPP_TYPE) && G_OPP_DIR == (dir > 0 ? OPP_DIR_BUY : OPP_DIR_SELL))
      G_MB_FAST_TYPE = (int)G_OPP_TYPE;

   // BRAIN ENTRIES - simple market logic that does not wait for the old detectors' score. Each one
   // carries an opportunity type the V0 permission understands; the veto, the Entry Judge and every
   // risk gate still decide after it.
   // 0. REVERSAL (plan stage 1): the structure was swept, displaced, broken (MSS) and the retest of
   //    the break held - the new direction's first good entry (the 4070 kind), taken before the bias
   //    has caught up. Not once the move is late.
   if(dir == 0 && EnableBrainEntries && EnableReversalEntry && G_ST_REV_DIR != 0 &&
      MBStructStageFor(G_ST_REV_DIR) >= MathMax(1, LockUnlockStage))   // live (AUDIT FIX A5)
   {
      int vd = G_ST_REV_DIR;
      bool late = (G_MB_IMP_DIR[0] == vd && G_MB_SPEED[0] >= MB_SPEED_LATE) ||
                  (G_MB_IMP_DIR[1] == vd && G_MB_SPEED[1] >= MB_SPEED_EXPIRED);
      if(!late && MBCandOk(vd, (int)OPP_TYPE_EXHAUSTION_REVERSAL) && MBHasTriggerNow(vd))
      {
         dir = vd;
         G_MB_FAST_TYPE = (int)OPP_TYPE_EXHAUSTION_REVERSAL;
         why = StringFormat("BRAIN REVERSAL %s: stage %d/6 - sweep %s, MSS %s, retest held", (vd > 0 ? "BUY" : "SELL"),
                            G_ST_REV_STAGE, DoubleToString(G_ST_REV_EXT, _Digits), DoubleToString(G_ST_REV_MSS, _Digits));
      }
   }

   // 0b. SECOND CHANCE (plan stage 4): a setup refused only for its place (late, chasing, a zone in
   //     front) - price came back to a better place and something triggers now.
   if(dir == 0 && EnableBrainEntries)
   {
      int cd = 0;
      string cw = "";
      if(MBSecondChanceNow(cd, cw) && MBCandOk(cd, (int)OPP_TYPE_PULLBACK_CONTINUATION) && MBHasTriggerNow(cd))
      {
         dir = cd;
         G_MB_FAST_TYPE = (int)OPP_TYPE_PULLBACK_CONTINUATION;
         why = StringFormat("BRAIN SECOND-CHANCE %s: %s", (cd > 0 ? "BUY" : "SELL"), cw);
      }
   }

   if(dir == 0 && EnableBrainEntries)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // 1. TREND: the brain holds a direction (weak or strong), a thesis is open that way, the
      //    impulse is not late, and something triggers now.
      int d = MBSign(G_MB_BIAS);
      string aw_tr = "";
      bool fresh_trend = !(G_MB_IMP_DIR[0] == d && G_MB_SPEED[0] >= MB_SPEED_LATE) && MBHasTriggerNow(d);
      bool pullback_trend = MBPullbackResume(d);   // a late trend, entered off its pullback
      int tr_type = (pullback_trend && !fresh_trend) ? (int)OPP_TYPE_PULLBACK_CONTINUATION :
                    ((MBPressureSide(2) == d && MBPressureSide(0) == -d) ? (int)OPP_TYPE_PULLBACK_CONTINUATION : (int)OPP_TYPE_TREND_RIDE);
      if(BrainEntryTrend && d != 0 && d * G_MB_BIAS >= 2 && G_MB_TH_DIR == d && thesis_open && G_MB_TH_CONTRA <= 1 &&
         (fresh_trend || pullback_trend) && MBCandOk(d, tr_type) && !MBTrendUnderAttack(d, aw_tr))
      {
         dir = d;
         G_MB_FAST_TYPE = tr_type;
         why = StringFormat("BRAIN TREND %s: %s, thesis %s, %s", (d > 0 ? "BUY" : "SELL"),
                            MBBiasName(G_MB_BIAS), MBThesisStateName(G_MB_TH_STATE),
                            (fresh_trend ? "trigger now" : "pullback resuming"));
      }

      // 1b. HANDOFF (local -> global): the bounce against the trend ran into the global side's place
      //     and the micro layer turned back - sell the top of the bounce (buy the bottom of the dip).
      if(dir == 0 && G_MB_BIAS != 0)
      {
         int gd = MBSign(G_MB_BIAS);
         string hw = "";
         if(MBHandoffNow(gd, hw) && MBCandOk(gd, (int)OPP_TYPE_EXHAUSTION_REVERSAL) && MBHasTriggerNow(gd))
         {
            dir = gd;
            G_MB_FAST_TYPE = (int)OPP_TYPE_EXHAUSTION_REVERSAL;
            why = StringFormat("BRAIN HANDOFF %s: %s - back with %s", (gd > 0 ? "BUY" : "SELL"), hw, MBBiasName(G_MB_BIAS));
         }
      }

      // 1c. LAYER PULLBACK: global and local agree, the micro layer pulled back and is now resuming.
      if(dir == 0 && MathAbs(G_MB_BIAS) >= 2)
      {
         int gd = MBSign(G_MB_BIAS);
         string aw_pb = "";
         if(MBLayerLocal() == gd && MBPullbackResume(gd) && MBCandOk(gd, (int)OPP_TYPE_PULLBACK_CONTINUATION) && !MBTrendUnderAttack(gd, aw_pb))
         {
            dir = gd;
            G_MB_FAST_TYPE = (int)OPP_TYPE_PULLBACK_CONTINUATION;
            why = StringFormat("BRAIN PULLBACK %s: global and local %s, micro pullback resuming", (gd > 0 ? "BUY" : "SELL"),
                               (gd > 0 ? "up" : "down"));
         }
      }

      // 2. LIQUIDITY HUNT: liquidity was just taken and reclaimed - trade the return. Not against a
      //    strong brain (V0 would refuse it anyway).
      if(dir == 0 && BrainEntrySweep)
      {
         int sw_first = MBTieFirst();
         for(int sw_i = 0; sw_i < 2 && dir == 0; sw_i++)
         {
            int sd = (sw_i == 0) ? sw_first : -sw_first;
            if(!MBCandOk(sd, (int)OPP_TYPE_SWEEP_REJECTION))
               continue;   // V0 would refuse it - leave room for the other candidates
            string w = "";
            bool live = MBLiveSweepFresh(sd, w) && (TimeCurrent() - G_MB_LSW_TIME) <= 60;
            // COUNCIL (2): an M1 pool sweep is a small thing - only with the local leg on its side.
            if(live && G_MB_LSW_TFI == 0 && MBLayerLocal() != sd)
               live = false;
            if(!live)
            {
               // A fresh confirmed M5+ sweep / fake break with a reclaim: at most 10 minutes old, and
               // price not already 1 ATR(M5) away from where it happened (no late entry into the next level).
               datetime swt = 0;
               if(MBReversalAfter(sd, 1, 2, true, TimeCurrent() - 600, w, swt))
               {
                  int sh = iBarShift(_Symbol, PERIOD_M1, swt);
                  double ref = (sh >= 0) ? iClose(_Symbol, PERIOD_M1, sh) : 0.0;
                  double atr5s = G_MB_ATR[1] * _Point;
                  live = (ref > 0.0 && atr5s > 0.0 && sd * (bid - ref) <= atr5s);
               }
            }
            if(live)
            {
               dir = sd;
               G_MB_FAST_TYPE = (int)OPP_TYPE_SWEEP_REJECTION;
               why = StringFormat("BRAIN SWEEP %s: %s", (sd > 0 ? "BUY" : "SELL"), w);
            }
         }
      }

      // 3. RANGE EDGE: the M15 regime is a range and price is at its edge with a turning candle.
      if(dir == 0 && BrainEntryRange && EnableRegimePlaybook && G_MB_RG == MB_RG_RANGE && G_MB_RG_HI > G_MB_RG_LO)
      {
         double pos = (bid - G_MB_RG_LO) / (G_MB_RG_HI - G_MB_RG_LO);
         int rd2 = (pos <= 0.20) ? 1 : ((pos >= 0.80) ? -1 : 0);
         if(rd2 != 0 && MBCandOk(rd2, (int)OPP_TYPE_RANGE_EDGE) && MBHasTriggerNow(rd2))
         {
            dir = rd2;
            G_MB_FAST_TYPE = (int)OPP_TYPE_RANGE_EDGE;
            why = StringFormat("BRAIN RANGE %s: %.0f%% of the M15 range %s-%s, turning candle", (rd2 > 0 ? "BUY" : "SELL"),
                               pos * 100.0, DoubleToString(G_MB_RG_LO, _Digits), DoubleToString(G_MB_RG_HI, _Digits));
         }
      }

      // 4. MOMENTUM: a displacement is happening (live) or just closed, M5 pressure agrees, the
      //    impulse is early, and the brain is not against it. The scalper's bread and butter.
      if(dir == 0 && BrainEntryMomentum)
      {
         int mo_first = MBTieFirst();
         for(int mo_i = 0; mo_i < 2 && dir == 0; mo_i++)
         {
            int md = (mo_i == 0) ? mo_first : -mo_first;
            bool disp = (G_MB_LIVE_DIR == md) ||
                        (G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == md &&
                         G_MB_LAST[0].time == iTime(_Symbol, PERIOD_M1, 1));
            bool early = !(G_MB_IMP_DIR[0] == md && G_MB_SPEED[0] >= MB_SPEED_LATE) &&
                         !(G_MB_IMP_DIR[1] == md && G_MB_SPEED[1] >= MB_SPEED_EXPIRED);
            bool in_box = (EnableRegimePlaybook && G_MB_RG == MB_RG_COMPRESSION && G_MB_LIVE_DIR != md);
            if(disp && early && !in_box && MBPressureSide(1) == md && MBCandOk(md, (int)OPP_TYPE_MOMENTUM_SCALP))
            {
               dir = md;
               G_MB_FAST_TYPE = (int)OPP_TYPE_MOMENTUM_SCALP;
               why = StringFormat("BRAIN MOMENTUM %s: %s displacement, M5 pressure with it (%s)", (md > 0 ? "BUY" : "SELL"),
                                  (G_MB_LIVE_DIR == md ? "live" : "fresh M1"), MBBiasName(G_MB_BIAS));
            }
         }
      }
   }

   // 5. LOCAL LEG: against the global bias, the M1 / M5 structure and pressure have turned this way
   //    and something triggers now - the bounce inside a falling day, the dip inside a rising one.
   if(dir == 0 && EnableBrainEntries && EnableLocalTrading && G_MB_BIAS != 0)
   {
      int ld = -MBSign(G_MB_BIAS);
      int lv = MBLocalLevel(ld);
      bool late = (G_MB_IMP_DIR[0] == ld && G_MB_SPEED[0] >= MB_SPEED_LATE);
      if(MBLocalOkFor(ld) && !late && MBCandOk(ld, (int)OPP_TYPE_MOMENTUM_SCALP) && MBHasTriggerNow(ld))
      {
         dir = ld;
         G_MB_FAST_TYPE = (int)OPP_TYPE_MOMENTUM_SCALP;
         why = StringFormat("BRAIN LOCAL %s: local leg %s against %s (M1/M5 structure + pressure), trigger now",
                            (ld > 0 ? "BUY" : "SELL"), (lv >= 2 ? "strong" : "clear"), MBBiasName(G_MB_BIAS));
      }
   }

   // 6. ALIGNED (owner: "where a SELL may not open, a BUY may"): the local leg and the M5 candles
   //    point the same way, M1 is not against it, the leg is not late and something triggers now. This
   //    is the side the council keeps open when it refuses the other - turnover without fighting the tape.
   if(dir == 0 && EnableBrainEntries && EnableEntryCouncil)
   {
      int al_first = MBTieFirst();
      for(int al_i = 0; al_i < 2 && dir == 0; al_i++)
      {
         int cd = (al_i == 0) ? al_first : -al_first;
         if(MBLayerLocal() != cd || MBPressureSide(1) != cd || MBPressureSide(0) == -cd)
            continue;
         bool late = (G_MB_IMP_DIR[0] == cd && G_MB_SPEED[0] >= MB_SPEED_LATE) ||
                     (G_MB_IMP_DIR[1] == cd && G_MB_SPEED[1] >= MB_SPEED_EXPIRED);
         if(!late && MBCandOk(cd, (int)OPP_TYPE_MOMENTUM_SCALP) && MBHasTriggerNow(cd))
         {
            dir = cd;
            G_MB_FAST_TYPE = (int)OPP_TYPE_MOMENTUM_SCALP;
            why = StringFormat("BRAIN ALIGNED %s: local leg and M5 candles %s, trigger now (%s)", (cd > 0 ? "BUY" : "SELL"),
                               (cd > 0 ? "up" : "down"), MBBiasName(G_MB_BIAS));
         }
      }
   }

   if(dir == 0)
   {
      MBFastWhyNotUpdate();
      return false;
   }
   G_MB_FAST_WHYNOT[0] = "";
   G_MB_FAST_WHYNOT[1] = "";
   MBFastToday();   // rolls the counter over at a new day
   return true;
}

bool MBJudgeBypassOn()  { return EnableJudgeScoreBypass && EnableMBEntryJudge && EnableMarketBrain && EnableMarketBrainEngines; }
int  MBJudgeBypassMin()
{
   // Shadow valve on the score gate: the judge's caution grade is enough to stand in for the score.
   if(MBShadowValveOn(GATE_SCORE))
      return MathMax(1, MathMin(MBJudgeBypassQuality, MBEntryCautionQuality));
   return MathMax(1, MBJudgeBypassQuality);
}

int MBFastEntryType()
{
   return G_MB_FAST_TYPE;
}

// Score given to a fast entry so the score-cost gates after the score check judge it fairly.
int MBFastEntryScore(const int min_required)
{
   return min_required + MathMax(0, MBFastEntryScoreMargin);
}

// Called by the first-entry engine after a fill: counts fast entries for the panel.
void MBFastEntryFilled()
{
   // AUDIT FIX: any first-entry fill ends the second-chance memory - its reference price belongs to
   // the market before this basket.
   if(G_BASKET_ORDERS <= 1)
      MBSecondChanceTaken();
   if(StringFind(G_OPP_REASON, "FAST ") == 0 || StringFind(G_OPP_REASON, "BRAIN ") == 0)
   {
      MBFastToday();
      G_MB_FAST_TODAY++;
      MBFastCountSave();
   }
   if(G_BASKET_ORDERS <= 1)
   {
      int colon = StringFind(G_OPP_REASON, ":");
      G_MB_ENTRY_KIND = (StringFind(G_OPP_REASON, "BRAIN ") == 0 || StringFind(G_OPP_REASON, "FAST ") == 0)
                        ? ((colon > 0) ? StringSubstr(G_OPP_REASON, 0, colon) : G_OPP_REASON)
                        : "detektor " + OpportunityTypeToString(G_OPP_TYPE);
      G_MB_ENTRY_KIND += StringFormat(" · sifat %d", G_MB_ENTRY_QUALITY);
   }
   // The signal was taken. Decay measures a signal price ran away from WITHOUT us; after a fill the
   // next entry is a fresh decision from here. FIX(reentry-decay): the anchor used to stay at the
   // first signal for 15 minutes, so every winning re-entry in the same direction lost quality
   // (five quick cashback wins = about 20 points) until the judge said WAIT in a move that was
   // paying.
   G_MB_SIG_PRICE = SymbolInfoDouble(_Symbol, (G_OPP_DIR == OPP_DIR_BUY ? SYMBOL_ASK : SYMBOL_BID));
   G_MB_SIG_TIME = TimeCurrent();
}

// MARKET BRAIN SCORE RELIEF. The old detectors found a direction but their score fell short. When
// the brain reads the same direction, it lends score: a strong aligned bias with an open thesis that
// way lends MBReliefStrong, a weaker alignment MBReliefWeak. Neutral or against lends nothing - the
// relief can only add trades in the direction the brain already holds, and the veto and the judge
// (location + trigger + impulse speed) still decide after it. In cashback tempo a neutral brain lends
// one point when a thesis is open that way.
int MBBrainScoreRelief(const int dir, string &why)
{
   why = "";
   if(!EnableMBScoreRelief || !EnableMarketBrain || !EnableMarketBrainEngines || !G_MB_BRAIN_PRIMED || dir == 0)
      return 0;
   if(G_MB_DEAD_DIR == dir && TimeCurrent() < G_MB_DEAD_UNTIL)
      return 0;   // that thesis just died - no loans on it
   int a = dir * G_MB_BIAS;
   bool th_with = (G_MB_TH_DIR == dir && (G_MB_TH_STATE == MB_TH_ACTIVATED || G_MB_TH_STATE == MB_TH_CONFIRMED) &&
                   G_MB_TH_CONTRA < 2);
   int r = 0;
   if(a >= 2 && th_with)      r = MathMax(0, MBReliefStrong);
   else if(a >= 2 || (a == 1 && (IsReversalOpportunityType(G_OPP_TYPE) || MBTransitionConfirmed(dir))))
      r = MathMax(0, MBReliefWeak);   // a == 1: V0 admits reversal types, or anything once the turn is confirmed
   else if(a == 0 && th_with && MBCashbackTempo()) r = 1;
   else if(a < 0 && (MBLocalOkFor(dir) || (a >= -2 && MBRangeRules()))) r = MathMax(0, MBReliefWeak);   // local leg / range
   if(r > 0)
      why = StringFormat("brain %s%s +%d", MBBiasName(G_MB_BIAS), (th_with ? ", thesis open" : ""), r);
   return r;
}

// STAGE 14 (C4): is this a momentum moment for dir? Waiting for a pullback here gives the move away -
// the fill SmartFill is waiting for is the one the momentum will not offer.
bool MBMomentumNow(const int dir)
{
   if(!SmartFillMomentumSkip || dir == 0)
      return false;
   if(G_MB_LIVE_DIR == dir)
      return true;
   string w = "";
   if(MBLiveSweepFresh(dir, w) && (TimeCurrent() - G_MB_LSW_TIME) <= 30)
      return true;
   return (G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == dir &&
           G_MB_LAST[0].time == iTime(_Symbol, PERIOD_M1, 1) && (TimeCurrent() - iTime(_Symbol, PERIOD_M1, 0)) <= 20);
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
