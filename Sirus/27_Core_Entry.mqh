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
// CoreLocalTurnControl: 38-PAKET: lokal oyoq katta TF ga qarshi burilganda (lokal burilish savdosi) mikro nazorat kamida shu foiz bo'lsin
input int    CoreLocalTurnControl     = 60;   // YADRO: micro control for a local turn against H1/H4, %

// PACKAGE 40 (owner, live 2026-10-19): the first YADRO (package 29) traded fast; every refusal added after
// it (packages 31-38) was reasonable alone and together they choked the entries again - the very stacking
// YADRO was built to end. Each of them is now a switch, OFF by default, to be turned on one by one only
// when the Trace / Autopsy numbers show it lowers the grid rate. The rules that ADD entries (the turn
// after a stretched run, the HTF reversal, the brain's turn, the local turn, the boxed-range escape) and
// the safety / speed / lot fixes stay on.
input group "YADRO ▸ Extra filters (OFF until the data earns them)"
// CoreNoChasing: 30-PAKET: cho'zilgan yugurish cho'qqisida o'sha tomonga kirmaslik (4177 dagi BUY xatosidan)
input bool   CoreNoChasing            = true;   // YADRO filter: no chasing at the tip of a stretched run
// CoreUseMicroControl: 31-PAKET: mikro nazorat CoreMinControl % dan past bo'lsa oddiy kirish yo'q
input bool   CoreUseMicroControl      = false;   // YADRO filter: micro control minimum
// CoreUseGlobalLocal: 32-PAKET: global bias'ga qarshi kirish uchun M5 / lokal oyoq burilgan bo'lishi kerak
input bool   CoreUseGlobalLocal       = false;   // YADRO filter: global bias needs M5 / local turned
// CoreUseZoneChecks: 32-PAKET: yangi H1/H4 zona va kuchli RBR/DBR zona qoq oldida kirmaslik
input bool   CoreUseZoneChecks        = false;   // YADRO filter: HTF zone / zone-intelligence block
// CoreUseH1PushRule: 33-PAKET: H1 yoki H4 qarshi va H1 + M15 bosimi qarshi bo'lsa kirmaslik
input bool   CoreUseH1PushRule        = false;   // YADRO filter: one of H1/H4 against with H1+M15 pushing
// CoreUseLocalLayer: 38-PAKET: lokal qatlam qarshi bo'lsa kirmaslik; oddiy rejimda M5 va lokal ikkalasi kerak
input bool   CoreUseLocalLayer        = false;   // YADRO filter: local layer against / strict in normal mode

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
   if(EnableNewsOwner && NewsOwnerBlocksEntry(reason))   return false;   // package 33: the live news read too (the grid reads it)
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
   // PACKAGE 33: the scanner's SAFETY hard block - market chaos, unreadable / extreme spread, no or stale
   // tick. Asked directly: its other hard blocks (walls, counter-context, blow-off, legacy roadblock) are
   // setup opinions the core's own questions answer.
   string hb = "";
   if(ScoreHardBlockCheck(hb))
   {
      reason = "hard block: " + hb;
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

   // PACKAGE 35 (live 12:39): a KEY sell-side sweep at 4163.7 was answered (M1 rejection, M5 turned up),
   // and YADRO refused every BUY because H1 was DN with H1 + M15 pressure still down. The arbiter it
   // replaced had the answer to that: a CONFIRMED H1 / H4 / KEY liquidity reversal toward the side after
   // the newest H1 / H4 break against it (sweep + displacement / MSS / reclaim) - the market has already
   // turned where the big money was. With it, the "still pushing" refusal stands aside and the reversal
   // is the side's location; the closed turn trigger and M5 / local turn are still required.
   datetime rv_since = 0;
   for(int tfi = 3; tfi <= 4; tfi++)
   {
      int le = MBLastStructureEvent(tfi);
      if(le >= 0 && G_MB_EV[le].dir == -d)
         rv_since = MathMax(rv_since, G_MB_EV[le].time + PeriodSeconds(MBEventTF(tfi)));
   }
   string rv_what = "";
   datetime rv_t = 0;
   bool htf_rev = MBReversalAfter(d, 3, 4, true, rv_since, rv_what, rv_t);
   // PACKAGE 37 (live 13:05 - deadlock): after an H1 sell-side sweep the brain's global bias turned to
   // TRANSITION_UP, M5 turned up, the local leg went up - and both sides stood refused: BUY because H1
   // was still DN with H1 + M15 candle pressure down, SELL because it was against the global bias with
   // M5 / local not turned. Each rule right alone, together silence for as long as a turn takes. The
   // brain's bias is the layer built to read the turn (structure memory, lock, reversal maturity): when
   // it already leans this side and M5 or the local leg agrees, the turn is underway - the H1 / M15
   // pressure is the lagging part. It then answers the "still pushing" refusal and stands as the side's
   // location; a closed turn trigger is still required.
   bool brain_turn = (MBBiasAlign(d) >= 1 && (MBM5StructDir() == d || MBLayerLocal() == d));

   // PACKAGE 38 (owner): three layers, three jobs. H1 / H4 decide the RISK (which side can cost a grid),
   // the LOCAL layer (M5 structure + the local leg) decides the DIRECTION, the MICRO layer (M1 candles,
   // micro control) decides the MOMENT. The TP is small, so the local turns are traded too - but the
   // micro layer never picks a side on its own: a micro move against the local leg is waited out and the
   // entry goes on the M1 candle that turns back. Cashback (small TP): the local layer is M5 OR the local
   // leg. Normal mode (larger TP): both, or one with the other neutral.
   bool cashback = RebateModeOn();
   int  m5 = MBM5StructDir(), lc = MBLayerLocal();
   bool strict_local  = (CoreUseLocalLayer && !cashback);
   bool local_with    = !strict_local ? (m5 == d || lc == d) : ((m5 == d && lc != -d) || (lc == d && m5 != -d));
   bool local_against = cashback ? (m5 == -d && lc == -d) : (m5 == -d || lc == -d);
   bool local_turn    = local_with && (!EnableMicroControl || CoreLocalTurnControl <= 0 || MBControlOf(d) >= CoreLocalTurnControl);
   bool via_local = false;

   // 1. DIRECTION
   string loc = "";
   if(CoreUseLocalLayer && local_against && !reversal && !htf_rev)
   {
      why = StringFormat("core direction: the local layer is against %s (M5 %s, local leg %s) - waiting for it to turn", side,
                         (m5 > 0 ? "up" : (m5 < 0 ? "down" : "flat")), (lc > 0 ? "up" : (lc < 0 ? "down" : "flat")));
      return false;
   }
   if(counter)
   {
      bool push = (MBPressureSide(3) == -d && MBPressureSide(2) == -d) && !htf_rev && !brain_turn;
      if(push)
      {
         why = StringFormat("core direction: %s against H4 %s / H1 %s and H1 + M15 still push against it", side,
                            MBArbStateTxt(h4), MBArbStateTxt(h1));
         return false;
      }
      if(htf_rev)
         loc = "HTF reversal " + rv_what;
      else if(brain_turn)
         loc = "brain turning " + MBBiasName(G_MB_BIAS);
      else if(local_turn)
      {
         loc = StringFormat("local turn (M5 %s, local %s, control %d%%)", (m5 == d ? "with" : "flat"), (lc == d ? "with" : "flat"),
                            MBControlOf(d));
         via_local = true;
      }
      else if(!MBArbiterAtOwnLocation(d, px, loc))
      {
         why = StringFormat("core direction: %s against H4 %s / H1 %s - needs its own location or a local turn with micro control %d%%+", side,
                            MBArbStateTxt(h4), MBArbStateTxt(h1), CoreLocalTurnControl);
         return false;
      }
      if(!local_with)
      {
         why = StringFormat("core direction: counter-trend %s at %s - the local layer (M5 / local leg) not turned yet", side, loc);
         return false;
      }
   }
   // PACKAGE 33: one of H1 / H4 against while H1 AND M15 candle pressure still push against it - the
   // arbiter's DENY: buying into a live H1 pullback. A turn with its proof is checked at the trigger.
   if(CoreUseH1PushRule && !counter && !reversal && !htf_rev && !brain_turn && (MBSign(h1) == -d || MBSign(h4) == -d) && MBPressureSide(3) == -d && MBPressureSide(2) == -d)
   {
      why = StringFormat("core direction: %s with %s against and H1 + M15 still pushing against it", side,
                         (MBSign(h1) == -d ? "H1" : "H4"));
      return false;
   }
   // PACKAGE 32 (global vs local): against the global bias the entry needs the market to have turned its
   // way underneath - M5 structure or the local leg - the V0 local-trading rule; inside an H1 + H4 trend
   // too (an M15 pullback is bought once M5 / local turns back, not while it still falls). A turn after a
   // stretched run carries its own proof (checked at the trigger).
   if(CoreUseGlobalLocal && MBBiasAlign(d) < 0 && !reversal && MBM5StructDir() != d && MBLayerLocal() != d)
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
      bool htf_any_against = (MBSign(h1) == -d || MBSign(h4) == -d);
      if(!(late_only && !htf_any_against))
      {
         why = "core place: " + w;
         return false;
      }
   }

   // PACKAGE 30: no chasing - not into the tip of a stretched run (more room with the H1 + H4 trend).
   double ext = 0.0;
   if(CoreNoChasing && CoreStretched(d, (with_htf ? MathMax(CoreTipLegATR, CoreTipLegATRTrend) : CoreTipLegATR), ext))
   {
      why = StringFormat("core place: %s at the tip of a %.1f ATR(M5) run - no chasing, waiting for a pullback or the turn", side, ext);
      return false;
   }
   // 3. TRIGGER (a turn is taken only on proof: a closed turn candle or a sweep, never the forming candle)
   bool strong = MBHasStrongTriggerNow(d);
   // The full counter-trend side and the turn need a closed turn; every other entry any trigger.
   bool trig;
   if(reversal)
      trig = (strong || swept);                                   // a turn after a stretched run: real proof only
   else if(counter)   // package 40: as in package 29 - only the full counter-trend side needs the closed turn
      // Package 38: a cashback local turn takes its M1 candle - a CLOSED trigger candle, never the forming one.
      trig = (strong || swept || (via_local && cashback && MBCandleTriggerNow(0, d, px)));
   else
      trig = (strong || MBHasTriggerNow(d));
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
   if(CoreUseMicroControl && EnableMicroControl && CoreMinControl > 0 && ctrl < CoreMinControl && !((counter || reversal) && (strong || swept)))
   {
      why = StringFormat("core trigger: micro control %s %d%% - the other side controls the flow now", side, ctrl);
      return false;
   }

   // 4. ROOM
   double room = 0.0, need = 0.0;
   string zt = "";
   if(MBVetoNoRoom && MBV3Blocked(d, px, room, need, zt))
   {
      // Package 33: price boxed between a holding support and resistance - only the side with LESS room is
      // refused (the veto's own escape, 21); refusing both was silence in every tight range.
      double px_o = SymbolInfoDouble(_Symbol, (d > 0 ? SYMBOL_BID : SYMBOL_ASK));
      double room_o = 0.0, need_o = 0.0;
      string zt_o = "";
      bool boxed = MBV3Blocked(-d, px_o, room_o, need_o, zt_o);
      if(!boxed || room < room_o)
      {
         why = StringFormat("core room: %s holds %.0f pts away (TP needs %.0f)%s", zt, MathMax(0.0, room), need,
                            (boxed ? StringFormat(" - boxed, the other side has %.0f", MathMax(0.0, room_o)) : ""));
         return false;
      }
   }
   if(MBCostBlocks(d, w, u))
   {
      why = "core room: " + w;
      return false;
   }
   // PACKAGE 32 (zones): not into the other side's fresh higher-timeframe zone - inside it or right at it -
   // until an M15 close takes it out (20g) ...
   if(CoreUseZoneChecks && EnableHTFZones && MBHTFZoneBlocks(d, w))
   {
      why = "core room: " + w;
      return false;
   }
   // ... and not into a strong fresh supply / demand zone (20i) right in front when this side's own zone
   // here is weaker - the judge's BLOCK verdict - unless the live candle is breaking it now.
   double atr5 = G_MB_ATR[1] * _Point;
   if(CoreUseZoneChecks && EnableZoneConflictBlock && atr5 > 0.0 && G_MB_LIVE_DIR != d)
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
// PACKAGE 34 (speed): the old chain as advisor ran the whole legacy decision on EVERY tick - with a basket
// open too - on top of the core. It now runs only when its verdict is worth writing down: on the tick the
// core takes an entry (every trade carries the old chain's opinion), and while flat once per M1 bar for the
// refusals. Everything it touches is put back afterwards (package 33): the scanner / score state, the
// evidence-gate bookkeeping, the brain fast-entry flag.
datetime G_CORE_ADV_BAR = 0;
int      G_CORE_ADV_DIR = 0;
string   G_CORE_ADV_LAST = "";

string CoreRunAdvisor()
{
   ENUM_OPPORTUNITY_DIR   s_dir = G_OPP_DIR;
   ENUM_OPPORTUNITY_TYPE  s_type = G_OPP_TYPE;
   ENUM_OPPORTUNITY_GRADE s_grade = G_OPP_GRADE;
   string s_oreason = G_OPP_REASON, s_odetail = G_OPP_DETAIL, s_sdetail = G_SCORE_DETAIL, s_shard = G_SCORE_HARD_BLOCK;
   int    s_oscore = G_OPP_SCORE, s_final = G_SCORE_FINAL, s_min = G_SCORE_MIN_REQUIRED, s_base = G_SCORE_BASE;
   int    s_bonus = G_SCORE_BONUS, s_pen = G_SCORE_PENALTY, s_raw = G_PENALTY_RAW, s_sit = G_SITUATION, s_sitd = G_SITUATION_DIR;
   double s_clar = G_OPP_DIR_CLARITY;
   ENUM_SCORE_DECISION s_dec = G_SCORE_DECISION;
   bool   s_micro = G_SCORE_IS_MICRO, s_against = G_ENTRY_AGAINST_GLOBAL, s_fast = G_MB_FAST_ACTIVE, s_rec = G_EG_RECORD;
   int    s_mask = G_EG_SKIP_MASK;

   string lr = "";
   bool lok = FirstEntryCanRun(lr);
   string v = lok ? "ready" : lr;
   if(StringLen(v) > 90)
      v = StringSubstr(v, 0, 90);

   G_OPP_DIR = s_dir; G_OPP_TYPE = s_type; G_OPP_GRADE = s_grade;
   G_OPP_REASON = s_oreason; G_OPP_DETAIL = s_odetail; G_OPP_SCORE = s_oscore; G_OPP_DIR_CLARITY = s_clar;
   G_SCORE_FINAL = s_final; G_SCORE_MIN_REQUIRED = s_min; G_SCORE_BASE = s_base; G_SCORE_BONUS = s_bonus;
   G_SCORE_PENALTY = s_pen; G_PENALTY_RAW = s_raw; G_SCORE_DETAIL = s_sdetail; G_SCORE_HARD_BLOCK = s_shard;
   G_SCORE_DECISION = s_dec; G_SCORE_IS_MICRO = s_micro; G_ENTRY_AGAINST_GLOBAL = s_against;
   G_SITUATION = s_sit; G_SITUATION_DIR = s_sitd;
   G_MB_FAST_ACTIVE = s_fast; G_EG_RECORD = s_rec; G_EG_SKIP_MASK = s_mask;
   return v;
}

bool CoreEntryCanRun(string &reason)
{
   int det_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
   ENUM_OPPORTUNITY_TYPE det_type = G_OPP_TYPE;
   G_TR_TICK = "";   // package 33: the decision trace starts clean
   G_CORE_LEGACY = "";
   G_MB_FAST_ACTIVE = false;
   G_EG_SKIP_MASK = 0;

   string safety = "";
   if(!CoreSafetyAllows(safety))
   {
      reason = safety;   // a basket open, news, cooldown ... - nothing for the advisor to compare
      G_CORE_WHY[0] = "core safety: " + safety;   // package 36: the panel shows it instead of an old reason
      G_CORE_WHY[1] = G_CORE_WHY[0];
      return false;
   }

   int rk[2] = {0, 0};
   bool ok[2];
   G_EG_RECORD = false;   // package 33: the evidence-gate relaxations are recorded for the side taken only
   for(int k = 0; k <= 1; k++)
      ok[k] = CoreSideOk((k == 1) ? 1 : -1, G_CORE_WHY[k], rk[k]);
   G_EG_SKIP_MASK = 0;

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
         // Name the refusal of the scanner's side if it has one, else both.
         int show = (det_dir != 0) ? ((det_dir > 0) ? 1 : 0) : 1;
         reason = G_CORE_WHY[show];
         if(det_dir == 0)
            reason = "core none: BUY - " + G_CORE_WHY[1] + " | SELL - " + G_CORE_WHY[0];
      }
      datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
      if(CoreLegacyAdvisor && (m1 != G_CORE_ADV_BAR || G_CORE_ADV_DIR != 0))
      {
         G_CORE_ADV_BAR = m1;
         G_CORE_ADV_DIR = 0;
         G_CORE_LEGACY = CoreRunAdvisor();
         reason += " | eski: " + G_CORE_LEGACY;
      }
      return false;
   }

   int k = (d > 0) ? 1 : 0;
   {
      string cw = "", cu = "";
      G_EG_RECORD = true;
      MBCostBlocks(d, cw, cu);   // cached this tick - records the relaxations that stood aside for this side
   }
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
   // Package 33: the scanner's score belongs to its own side - a core entry the other way carries the minimum.
   G_SCORE_FINAL = same ? MathMax(G_SCORE_FINAL, G_SCORE_MIN_REQUIRED) : G_SCORE_MIN_REQUIRED;
   G_SCORE_DECISION = SCORE_DECISION_PASS;
   G_ENTRY_AGAINST_GLOBAL = (MBBiasAlign(d) < 0);
   G_OPP_REASON = StringFormat("YADRO %s: %s", (d > 0 ? "BUY" : "SELL"), G_CORE_WHY[k]);

   // The old chain's opinion on the trade being taken (its state changes are undone inside). Once per
   // side per M1 bar - SmartFill can hold a ready entry for several ticks.
   if(CoreLegacyAdvisor)
   {
      datetime m1r = iTime(_Symbol, PERIOD_M1, 0);
      if(m1r != G_CORE_ADV_BAR || d != G_CORE_ADV_DIR)
      {
         G_CORE_ADV_BAR = m1r;
         G_CORE_ADV_DIR = d;
         G_CORE_ADV_LAST = CoreRunAdvisor();
      }
      G_CORE_LEGACY = G_CORE_ADV_LAST;
   }

   // Package 33: the send path reads the Entry Judge's state (lot caution, SmartFill fast flag, entry DNA
   // for Memory). Refresh it for THIS side - after the advisor, whose probes leave it for another side -
   // and keep the core's verdict: the judge's CAUTION does not shrink a core entry, its EXECUTE FAST still
   // lets SmartFill fire at once.
   {
      string jw = "";
      bool jp = G_MB_JUDGE_PROBE;
      G_MB_JUDGE_PROBE = false;
      MBEntryJudgeAllows(d, jw);
      G_MB_JUDGE_PROBE = jp;
      G_MB_ENTRY_DECISION = MB_ED_EXECUTE;
      if(!(G_MB_ENTRY_OUTCOME == MB_EO_EXECUTE_FAST && G_MB_ENTRY_OUTCOME_DIR == d))
         G_MB_ENTRY_OUTCOME = MB_EO_EXECUTE;
      G_MB_ENTRY_OUTCOME_DIR = d;
      G_MB_ENTRY_RECHECK = "";
   }
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

// PACKAGE 39 (owner rule: immediate re-entry after a TP): SmartFill held every entry up to 8 s for a
// 120-point pullback - also the re-entry right after a TP in a move that is still paying, where the
// pullback rarely comes and the wait costs the next candle. A re-entry the same way within two minutes of a
// profitable exit, not chasing (within 1 ATR(M5) of the exit) and with the control not turned against it,
// goes at once.
bool CoreFastReentry(const int dir)
{
   if(!CoreEntryOn() || dir == 0 || G_RE_KIND != RE_PROFIT || G_RE_DIR != dir || G_RE_TIME <= 0)
      return false;
   if(TimeCurrent() - G_RE_TIME > 120)
      return false;
   return MBReentryFastOk(dir);
}

// Package 36: one panel line per side - the two reasons no longer share one line (it was cut off and the
// SELL half never showed). Ready sides read "tayyor: ...".
string CorePanelSide(const int k)
{
   string t = (StringLen(G_CORE_WHY[k]) > 0) ? G_CORE_WHY[k] : "-";
   if(StringFind(t, "core ") == 0)
      t = CoreReasonUz(t);
   else if(t != "-")
      t = "tayyor: " + t;
   return StringFormat("YADRO %s: %s", (k == 1 ? "BUY " : "SELL"), t);
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
   if(StringFind(t, "core safety: ") == 0)    return "xavfsizlik - " + StringSubstr(t, 13);
   return t;
}
