//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 27_Core_Entry                                   |
//| YADRO: the first-entry decision rebuilt on five questions        |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// PACKAGE 29: YADRO (core entry)
//---------------------------------------------------------------------
// WHY (live 2026-10-19): the first entry had to pass 150+ places that could refuse it - score, judge,
// council, location, zone, drift, V0-V11, arbiter ... - and EVERY one had to say yes. Each was added
// after a bad trade and each is reasonable alone; together they almost always found a "no". In 383
// minutes of decisions seven produced a trade, and the shadow ledger showed the refusals did not
// separate risk: refused setups needed the grid 3-7% of the time, the entries taken 17%.
//
// YADRO asks five questions per side and decides:
//   1. DIRECTION  with H1 + H4, or neutral -> open. Against both (one established) or a bias of -3
//                 -> only at the side's own location (a fresh sweep of the other side's liquidity,
//                 or a level the role engine says still holds), with M5 / the local leg turned, a
//                 closed turn trigger, and H1 + M15 not both still pushing against it. A confirmed
//                 reversal the other way (V1) and the re-entry memory after a loss still refuse.
//   2. PLACE      not into a spent move: exhaustion and taken liquidity refuse; "late in the leg"
//                 refuses only against the H1 + H4 trend (trends run).
//   3. TRIGGER    a trigger toward the side now (a closed turn when counter-trend), and the
//                 forming candle not displacing the other way (V4).
//   4. ROOM       no holding level of the other side inside the TP (V3), the cost not abnormal.
//   5. SAFETY     risk engine, safety layer, news, spread, weekend / holiday, anomaly, duplicate,
//                 cooldown, one basket at a time, broker retry backoff, operator / sanity checks.
// Both sides are asked every tick; the better-placed one is taken (with the HTF trend first).
//
// The old chain is NOT deleted. It still runs as an advisor: its verdict is written next to every
// YADRO decision in the Trace CSV ("eski: ..."), so each old filter can be measured on the trades
// YADRO took against its advice - and put back, one by one, where the numbers say it earns its place.
// EntryCoreMode = false restores the old chain as the decision maker.
//=====================================================================

input group "YADRO ▸ Core entry (5 questions)"
// EntryCoreMode: 29-PAKET: birinchi kirishni YADRO hal qiladi (5 savol). false = eski zanjir hal qiladi
input bool   EntryCoreMode            = true;   // YADRO: core entry decides the first entry
// CoreLegacyAdvisor: Eski zanjir maslahatchi bo'lib ishlaydi - uning fikri Trace'ga yoziladi (taqqoslash uchun)
input bool   CoreLegacyAdvisor        = true;   // YADRO: run the old chain as an advisor (Trace)

// CoreTipLegATR: 30-PAKET: oxirgi M5 barlarda shu ATR(M5) dan ko'p yugurgan harakatning cho'qqisida (yuqori chorakda) o'sha tomonga kirilmaydi
input double CoreTipLegATR            = 1.8;   // YADRO: no chasing - stretched run, ATR(M5)
// CoreTipLegATRTrend: H1 + H4 bilan bir tomonda bo'lsa - shu ATR(M5) dan keyin (trend yugurishiga ko'proq joy)
input double CoreTipLegATRTrend       = 3.0;   // YADRO: no chasing with the HTF trend, ATR(M5)
// CoreTipBars: Yugurish shuncha M5 bar ichida o'lchanadi
input int    CoreTipBars              = 8;   // YADRO: stretched run lookback, M5 bars
// CoreReversalEntry: Cho'zilgan yugurishdan keyin teskari tomonga kirish: yopilgan burilish shami yoki sweep bilan
input bool   CoreReversalEntry        = true;   // YADRO: reversal entry after a stretched run
// CoreMinControl: 31-PAKET: mikro nazorat (BUY% / SELL%) shu foizdan past bo'lsa - qarshi tomon boshqaryapti, oddiy kirish yo'q (burilish kirishiga yopilgan burilish shami yetadi)
input int    CoreMinControl           = 35;   // YADRO: min micro control share for the side, %

string G_CORE_WHY[2];      // 0 = SELL, 1 = BUY: why that side was refused / taken this tick

// PACKAGE 30 (live 2026-10-19 11:16): YADRO bought 4177.4, the top of a $9 rally inside an H4 down-turn,
// and price fell back to 4169. A trader does not buy the last tick of a run - and at the top of a run
// that has stalled he looks for the turn. A run in dir is "stretched" when price has travelled at least
// min_atr x ATR(M5) from the extreme of the last CoreTipBars M5 bars and still stands in the top quarter
// of that range. ext = the run in ATR(M5).
bool CoreStretched(const int dir, const double min_atr, double &ext)
{
   ext = 0.0;
   double atr5 = G_MB_ATR[1] * _Point;
   int n = MathMax(3, CoreTipBars);
   if(dir == 0 || atr5 <= 0.0)
      return false;
   int ilo = iLowest(_Symbol, PERIOD_M5, MODE_LOW, n, 0), ihi = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, n, 0);
   if(ilo < 0 || ihi < 0)
      return false;
   double lo = iLow(_Symbol, PERIOD_M5, ilo), hi = iHigh(_Symbol, PERIOD_M5, ihi);
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(lo <= 0.0 || hi <= lo || px <= 0.0)
      return false;
   // The run must go the right way: the up-run's low came before its high (and the reverse).
   if(dir > 0 && ilo < ihi) return false;
   if(dir < 0 && ihi < ilo) return false;
   ext = (dir > 0 ? (px - lo) : (hi - px)) / atr5;
   double pos = (dir > 0) ? (px - lo) / (hi - lo) : (hi - px) / (hi - lo);
   return (ext >= min_atr && pos >= 0.75);
}
string G_CORE_LEGACY = ""; // the old chain's verdict this tick

bool CoreEntryOn()
{
   return (EntryCoreMode && EnableMarketBrain && EnableMarketBrainEngines && G_MB_BRAIN_PRIMED);
}

// 5. SAFETY - the refusals that are about money, the broker or the calendar, never about the setup.
bool CoreSafetyAllows(string &reason)
{
   if(!UseFirstEntryEngine)                 { reason = "UseFirstEntryEngine=false"; return false; }
   if(G_BASKET_CLOSED_TICK == G_TICK_COUNT) { reason = "position: basket closed this tick - next tick decides"; return false; }
   if(!AllowLiveTrading)                    { reason = "AllowLiveTrading=false"; return false; }
   if(!G_ENV_READY)                         { reason = "ENV not ready"; return false; }
   if(!RiskAllowsNewEntry(reason))               return false;
   if(!Pack3AllowsEntry(reason))                 return false;
   if(!DuplicateInstanceAllowsTrading(reason))   return false;
   if(!SafetyAllowsEntry(reason))                return false;
   if(OneBasketAtATime && HasOpenSirusPosition())
   {
      reason = StringFormat("existing SIRUS position count=%d", CountSirusPositions());
      return false;
   }
   int since = (G_LAST_ENTRY_TIME <= 0) ? 999999 : (int)(TimeCurrent() - G_LAST_ENTRY_TIME);
   if(MinSecondsBetweenEntries > 0 && since < MinSecondsBetweenEntries)
   {
      reason = StringFormat("entry cooldown seconds %d/%d", since, MinSecondsBetweenEntries);
      return false;
   }
   if(!OperatorControlAllowsEntry(reason))       return false;
   if(!DailyProfitGovernorAllowsEntry(reason))   return false;
   if(!SettingsSanityAllowsEntry(reason))        return false;
   if(!SetupDoctorAllowsEntry(reason))           return false;
   if(!RetryEngineAllowsFirstEntry(reason))      return false;
   if(!EconomicCalendarAllowsEntry(reason))      return false;
   if(!BrokerHolidayAllowsEntry(reason))         return false;
   if(!WeekendGuardAllowsEntry(reason))          return false;
   if(!AccountModeAllowsTrading(reason))         return false;
   if(!VelocityAllowsNewRisk(reason))            return false;
   int spr = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spr > MaxSpreadAllowed())
   {
      reason = StringFormat("spread %d > %d", spr, MaxSpreadAllowed());
      return false;
   }
   string an = "";
   if(MBAnomalyBlocks(an))
   {
      reason = "anomaly: " + an;
      return false;
   }
   reason = "";
   return true;
}

// Questions 1-4 for one side. rank: how well placed the side is (only compared when both pass).
bool CoreSideOk(const int d, string &why, int &rank)
{
   why = "";
   rank = 0;
   string side = (d > 0) ? "BUY" : "SELL";
   double px = SymbolInfoDouble(_Symbol, (d > 0 ? SYMBOL_ASK : SYMBOL_BID));
   if(px <= 0.0)
   {
      why = "core none: no price";
      return false;
   }
   int h1 = G_MB_TF_STATE[3], h4 = G_MB_TF_STATE[4];
   bool with_htf = (MBSign(h1) == d && MBSign(h4) == d);
   bool htf_against = (MBSign(h1) == -d && MBSign(h4) == -d && (MathAbs(h1) >= 2 || MathAbs(h4) >= 2));
   bool counter = htf_against || (d * G_MB_BIAS <= -3);
   string w = "", u = "";
   // The other way's run is stretched - this side is the turn (package 30). Worked out first: it is the
   // proof the direction question accepts in place of a turned local leg; the trigger question below
   // still demands a closed turn candle or a sweep for it.
   double rev_ext = 0.0;
   bool reversal = CoreReversalEntry && CoreStretched(-d, CoreTipLegATR, rev_ext);
   string rsw = "";
   bool swept = reversal && MBLiveSweepFresh(d, rsw);

   // 1. DIRECTION
   string loc = "";
   if(counter)
   {
      bool push = (MBPressureSide(3) == -d && MBPressureSide(2) == -d);
      if(push)
      {
         why = StringFormat("core direction: %s against H4 %s / H1 %s and H1 + M15 still push against it", side,
                            MBArbStateTxt(h4), MBArbStateTxt(h1));
         return false;
      }
      if(!MBArbiterAtOwnLocation(d, px, loc))
      {
         why = StringFormat("core direction: %s against H4 %s / H1 %s - only at its own location (sweep / holding level)", side,
                            MBArbStateTxt(h4), MBArbStateTxt(h1));
         return false;
      }
      if(MBM5StructDir() != d && MBLayerLocal() != d)
      {
         why = StringFormat("core direction: counter-trend %s at %s - M5 / local leg not turned yet", side, loc);
         return false;
      }
   }
   // PACKAGE 32 (global vs local): against the global bias the entry needs the market to have turned its
   // way underneath - M5 structure or the local leg - the V0 local-trading rule; inside an H1 + H4 trend
   // too (an M15 pullback is bought once M5 / local turns back, not while it still falls). A turn after a
   // stretched run carries its own proof (checked at the trigger).
   if(MBBiasAlign(d) < 0 && !reversal && MBM5StructDir() != d && MBLayerLocal() != d)
   {
      why = StringFormat("core direction: %s against the global bias (%s) - M5 structure / local leg not turned its way", side,
                         MBBiasName(G_MB_BIAS));
      return false;
   }
   if(MBVetoReversal && MBVetoReversalCheck(d, w))
   {
      why = "core direction: " + w;
      return false;
   }
   if(MBReentryBlocks(d, w, u))
   {
      why = "core direction: " + w;
      return false;
   }

   // 2. PLACE
   if(MBLateBlocks(d, w, u))
   {
      bool late_only = (StringFind(w, "late entry") == 0);
      if(!(late_only && with_htf))
      {
         why = "core place: " + w;
         return false;
      }
   }

   // PACKAGE 30: no chasing - not into the tip of a stretched run (more room with the H1 + H4 trend).
   double ext = 0.0;
   if(CoreStretched(d, (with_htf ? MathMax(CoreTipLegATR, CoreTipLegATRTrend) : CoreTipLegATR), ext))
   {
      why = StringFormat("core place: %s at the tip of a %.1f ATR(M5) run - no chasing, waiting for a pullback or the turn", side, ext);
      return false;
   }
   // 3. TRIGGER (a turn is taken only on proof: a closed turn candle or a sweep, never the forming candle)
   bool strong = MBHasStrongTriggerNow(d);
   bool trig = (counter || reversal) ? (strong || swept) : (strong || MBHasTriggerNow(d));
   if(!trig)
   {
      why = StringFormat("core trigger: no %s trigger now%s", side,
                         (counter ? " (counter-trend needs a closed turn)" :
                          (reversal ? StringFormat(" (turn after a %.1f ATR run needs a closed turn candle or a sweep)", rev_ext) : "")));
      return false;
   }
   if(MBVetoAcceleration && MBVetoAccelerationCheck(d, w))
   {
      why = "core trigger: " + w;
      return false;
   }
   // PACKAGE 31: who controls the micro flow now (20d: candles, displacement, M1 / M5 structure, pressure,
   // tick flow). A plain entry does not go in while the other side clearly holds it; a turn entry carries
   // its own proof (a closed turn candle or a sweep), the control share lags a turn by design.
   int ctrl = MBControlOf(d);
   if(EnableMicroControl && CoreMinControl > 0 && ctrl < CoreMinControl && !((counter || reversal) && (strong || swept)))
   {
      why = StringFormat("core trigger: micro control %s %d%% - the other side controls the flow now", side, ctrl);
      return false;
   }

   // 4. ROOM
   double room = 0.0, need = 0.0;
   string zt = "";
   if(MBV3Blocked(d, px, room, need, zt))
   {
      why = StringFormat("core room: %s holds %.0f pts away (TP needs %.0f)", zt, MathMax(0.0, room), need);
      return false;
   }
   if(MBCostBlocks(d, w, u))
   {
      why = "core room: " + w;
      return false;
   }
   // PACKAGE 32 (zones): not into the other side's fresh higher-timeframe zone - inside it or right at it -
   // until an M15 close takes it out (20g) ...
   if(EnableHTFZones && MBHTFZoneBlocks(d, w))
   {
      why = "core room: " + w;
      return false;
   }
   // ... and not into a strong fresh supply / demand zone (20i) right in front when this side's own zone
   // here is weaker - the judge's BLOCK verdict - unless the live candle is breaking it now.
   double atr5 = G_MB_ATR[1] * _Point;
   if(EnableZoneConflictBlock && atr5 > 0.0 && G_MB_LIVE_DIR != d)
   {
      int zo = ZIOpposingAhead(d, px, ZoneConflictBlockATR * atr5, ZoneConflictBlockScore);
      if(zo >= 0)
      {
         int zw = ZIOwnZoneAt(d, px, 0.3 * atr5, ZIMinScore);
         if(!(zw >= 0 && G_ZI_SCORE[zw] >= G_ZI_SCORE[zo]))
         {
            why = "core room: strong fresh zone right in front - " + ZIDescribe(zo);
            return false;
         }
      }
   }

   rank = (with_htf ? 4 : 0) + (MBBiasAlign(d) > 0 ? 2 : 0) + (strong ? 1 : 0) + (G_MB_LIVE_DIR == d ? 1 : 0) - (counter ? 3 : 0)
          + (reversal ? 3 : 0)
          + ((EnableMicroControl && G_MC_TURN == MC_TURN_REVERSAL && d == -G_MC_PRIMARY) ? 2 : 0)    // the micro turn is this side's
          - ((EnableMicroControl && (G_MC_TURN == MC_TURN_REVERSAL || G_MC_TURN == MC_TURN_EXHAUST) && d == G_MC_PRIMARY) ? 2 : 0);
   why = StringFormat("%s%s%s%s · control %d%%", (with_htf ? "with H1+H4" : (counter ? "counter at " + loc : "HTF neutral")),
                      (reversal ? StringFormat(" · turn after a %.1f ATR run%s", rev_ext, (swept ? " (" + rsw + ")" : "")) : ""),
                      (strong ? " · closed trigger" : " · trigger"), (G_MB_LIVE_DIR == d ? " · live candle" : ""), ctrl);
   return true;
}

// The decision. Sets the scanner state the send path reads (direction, type, score, context).
bool CoreEntryCanRun(string &reason)
{
   int det_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
   ENUM_OPPORTUNITY_TYPE det_type = G_OPP_TYPE;

   // The old chain as advisor: run it first, keep its verdict, then decide here.
   G_CORE_LEGACY = "";
   if(CoreLegacyAdvisor)
   {
      string lr = "";
      bool lok = FirstEntryCanRun(lr);
      G_CORE_LEGACY = lok ? "ready" : lr;
      if(StringLen(G_CORE_LEGACY) > 90)
         G_CORE_LEGACY = StringSubstr(G_CORE_LEGACY, 0, 90);
      // FirstEntryCanRun may have redirected or replaced the setup - the core reads the scanner's own.
      G_OPP_DIR = (det_dir > 0) ? OPP_DIR_BUY : ((det_dir < 0) ? OPP_DIR_SELL : OPP_DIR_NONE);
      G_OPP_TYPE = det_type;
   }
   G_MB_FAST_ACTIVE = false;
   G_EG_SKIP_MASK = 0;

   string safety = "";
   if(!CoreSafetyAllows(safety))
   {
      reason = safety;
      return false;
   }

   int rk[2] = {0, 0};
   bool ok[2];
   for(int k = 0; k <= 1; k++)
      ok[k] = CoreSideOk((k == 1) ? 1 : -1, G_CORE_WHY[k], rk[k]);

   int d = 0;
   if(ok[1] && ok[0])
   {
      // Equal footing (a range, a neutral HTF): the side the market is moving now decides - the live
      // candle, then M5 structure, then the local leg, then the scanner's setup.
      if(rk[1] != rk[0])            d = (rk[1] > rk[0]) ? 1 : -1;
      else if(G_MB_LIVE_DIR != 0)   d = G_MB_LIVE_DIR;
      else if(MBM5StructDir() != 0) d = MBM5StructDir();
      else if(MBLayerLocal() != 0)  d = MBLayerLocal();
      else if(det_dir != 0)         d = det_dir;
   }
   else if(ok[1]) d = 1;
   else if(ok[0]) d = -1;

   if(d == 0)
   {
      if(ok[1] && ok[0])
         reason = "core none: both sides equal - waiting for the market to pick one";
      else
      {
         // Name the refusal of the scanner's side if it has one, else of the side that came closer.
         int show = (det_dir != 0) ? ((det_dir > 0) ? 1 : 0) : 1;
         reason = G_CORE_WHY[show];
         if(det_dir == 0)
            reason = "core none: BUY - " + G_CORE_WHY[1] + " | SELL - " + G_CORE_WHY[0];
      }
      if(CoreLegacyAdvisor)
         reason += " | eski: " + G_CORE_LEGACY;
      return false;
   }

   int k = (d > 0) ? 1 : 0;
   ENUM_OPPORTUNITY_DIR opp = (d > 0) ? OPP_DIR_BUY : OPP_DIR_SELL;
   bool same = (det_dir == d && det_type != OPP_TYPE_NONE);
   bool counter = (MBSign(G_MB_TF_STATE[3]) == -d && MBSign(G_MB_TF_STATE[4]) == -d);
   string sw = "";
   if(!same)
   {
      G_PENALTY_RAW = 0;
      if(counter)
         G_OPP_TYPE = MBLiveSweepFresh(d, sw) ? OPP_TYPE_SWEEP_REJECTION : OPP_TYPE_NEAR_ZONE_REACTION;
      else if(MBSign(G_MB_TF_STATE[3]) == d && MBSign(G_MB_TF_STATE[4]) == d)
         G_OPP_TYPE = OPP_TYPE_PULLBACK_CONTINUATION;
      else
         G_OPP_TYPE = OPP_TYPE_MOMENTUM_SCALP;
   }
   G_OPP_DIR = opp;
   G_SCORE_IS_MICRO = false;
   if(G_SCORE_MIN_REQUIRED <= 0)
      G_SCORE_MIN_REQUIRED = MinScoreForContext(false);
   G_SCORE_FINAL = MathMax(G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
   G_SCORE_DECISION = SCORE_DECISION_PASS;
   G_ENTRY_AGAINST_GLOBAL = (MBBiasAlign(d) < 0);
   G_OPP_REASON = StringFormat("YADRO %s: %s", (d > 0 ? "BUY" : "SELL"), G_CORE_WHY[k]);
   reason = G_OPP_REASON;
   if(CoreLegacyAdvisor)
      reason += " | eski: " + G_CORE_LEGACY;
   return true;
}

// Panel: one line - what YADRO says about each side.
string CorePanelText()
{
   if(!CoreEntryOn())
      return "";
   string b = (StringLen(G_CORE_WHY[1]) > 0) ? G_CORE_WHY[1] : "-";
   string s = (StringLen(G_CORE_WHY[0]) > 0) ? G_CORE_WHY[0] : "-";
   StringReplace(b, "core ", "");
   StringReplace(s, "core ", "");
   return StringFormat("YADRO  BUY: %s  ·  SELL: %s", b, s);
}

// The decision text without the old chain's advice (the panel and the status show YADRO's own reason;
// the Trace CSV keeps both).
string CoreStripAdvice(const string why)
{
   int p = StringFind(why, " | eski: ");
   return (p >= 0) ? StringSubstr(why, 0, p) : why;
}

// Panel "Sabab" for a YADRO refusal.
string CoreReasonUz(const string why)
{
   string t = CoreStripAdvice(why);
   if(StringFind(t, "core direction: ") == 0) return "yo'nalish - " + StringSubstr(t, 16);
   if(StringFind(t, "core place: ") == 0)     return "joy - " + StringSubstr(t, 12);
   if(StringFind(t, "core trigger: ") == 0)   return "trigger - " + StringSubstr(t, 14);
   if(StringFind(t, "core room: ") == 0)      return "TP uchun joy - " + StringSubstr(t, 11);
   if(StringFind(t, "core none: ") == 0)      return StringSubstr(t, 11);
   return t;
}
