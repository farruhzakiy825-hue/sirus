//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 21_Direction_Veto                               |
//| Market Brain D: hard vetoes built on events and zone roles       |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// DIRECTION VETO (engine plan, phase 4)
//---------------------------------------------------------------------
// A score of 92 is not a reason to sell into a market that has just shown it is going up. These
// vetoes sit after every other gate and refuse an entry only on STRONG contrary evidence - the
// rest of the evidence keeps working through the score, so the trade count stays high.
//
//   V1 REVERSAL   the opposite side's liquidity was just taken (sweep or fake break, M5 and up)
//                 and the market confirmed it (displacement, MSS/BOS, reclaim). On H1/H4/daily
//                 levels the sweep plus one confirmation is enough. Lifted when the market
//                 answers back in our direction (acceptance, MSS or a sweep of the other side, on
//                 M15 and up) or when the events are no longer relevant.
//   V2 ZONE ROLE  the zone the entry leans on does not have that role in its history: a SELL at
//                 a support that was never genuinely broken (or was swept and reclaimed), or at a
//                 broken support that has not been retested and rejected. BUY mirrors it.
//   V3 NO ROOM    a level that still holds sits between the entry and its target.
//   V4 AGAINST    the move is accelerating the other way right now (live M1 displacement
//                 against, or an accelerating displacement candle against).
//   V0 PERMISSION the Market Brain bias decides which entries a direction may take:
//                 aligned trend -> all; transition toward it -> reversal / reclaim types only;
//                 neutral -> all; transition away -> wait; weak opposite -> only an exceptional
//                 reversal setup; strong opposite -> none. A thesis that was just invalidated is
//                 not re-entered in the same direction without a strong bias (invalidation memory).
//
// Case 1 (4142 SELL): sell-side sweep -> bullish displacement -> MSS        -> V1.
// Case 2 (4126 SELL): 4125 support swept and reclaimed, H4 sell-side sweep -> V1, V2, V3.
//=====================================================================

input group "43 — MARKET BRAIN: DIRECTION VETO"
input bool   EnableMBVeto             = true;   // Kuchli qarama-qarshi dalil bo'lsa birinchi kirishni bloklash (4142 / 4126 xatolari)
input bool   MBVetoReversal           = true;   // V1: qarama-qarshi likvidlik olindi + tasdiq (displacement / MSS / reclaim)
input int    MBVetoReversalConfirms   = 2;      // V1: M5 / M15 sweep uchun kerakli tasdiqlar soni (H1 / H4 / kunlik uchun 1)
input bool   MBVetoZoneRole           = true;   // V2: zona tarixi bu yo'nalishga ruxsat bermasa
input double MBVetoZoneNearATR        = 1.5;    // V2: zona narxdan ATR(M5) x shu ichida bo'lsa tekshiriladi
input bool   MBVetoNoRoom             = true;   // V3: maqsadgacha ushlab turgan qarama-qarshi zona bo'lsa
input double MBVetoRoomTPMult         = 1.0;    // V3: zonagacha masofa < savat TP x shu bo'lsa - joy yo'q
input bool   MBVetoAcceleration       = true;   // V4: harakat hozir qarama-qarshi tomonga tezlashmoqda
input bool   MBVetoPrintOnUse         = true;   // Veto'ni jurnalga yozish ([SIRUS VETO])
input bool   EnableMBPermission       = true;   // V0: Market Brain yo'nalish ruxsati (BEARISH da BUY yo'q, TRANSITION da faqat reversal turi ...)
input bool   EnableEntryCouncil       = true;   // KENGASH: lokal + M5/M15 shamlari + zona birga hal qiladi. Uchalasi qarshi bo'lsa sweep ham kirgizmaydi; zaif global lokalni bosmaydi; qarshi zonaga kirmaydi. Bir tomon yopilsa - boshqa tomon (LOCAL / MOMENTUM) kirishi mumkin
input int    CouncilWeakGlobalConf    = 50;     // Global ishonchi shundan past yoki o'tish holatida bo'lsa - yo'nalishni lokal hal qiladi
input double CouncilZoneATR5          = 0.35;   // SELL ostida ushlab turgan support / BUY ustida resistance shu ATR(M5) ichida bo'lsa - kirmaydi (M5 yopilib buzilmaguncha)
input int    MBPermExceptionMargin    = 2;      // V0: zaif qarama-qarshi bias'da faqat reversal setup va ball >= minimum + shu
input bool   MBOwnsDuplicateGates     = true;   // Miya savdo tomonida bo'lsa, xuddi shu savolni beradigan ESKI filtrlar (joy, impuls quvish, HTF, eski daraja, singan daraja, aniqlik) chetga turadi - javobni miya veto'si va hakami beradi. Miya qarshi bo'lsa ikkala qatlam ham ishlaydi

int      G_MB_VETO_COUNT = 0;
string   G_MB_VETO_LAST = "";
datetime G_MB_VETO_LAST_PRINT = 0;

// V1 for one opposite liquidity event (index sw): true when it stands, confirmed and unanswered.
bool MBVetoReversalFrom(const int dir, const int sw, string &why)
{
   datetime t0 = G_MB_EV[sw].time;
   datetime t0_close = t0 + PeriodSeconds(MBEventTF(G_MB_EV[sw].tfi));   // AUDIT FIX: after the sweep bar closed
   bool htf = (MBEventRank(G_MB_EV[sw].tfi) >= 3);

   // The market answering back in our direction after it lifts the veto. AUDIT FIX: a newer liquidity
   // sweep / failed break our way counts from M5 up, so two opposite sweeps cannot veto both sides.
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= t0 || G_MB_EV[idx].dir != dir) continue;
      int ty = G_MB_EV[idx].type;
      int rk = MBEventRank(G_MB_EV[idx].tfi);
      if((ty == MB_EV_ACCEPTANCE || ty == MB_EV_MSS) && rk >= 2)
         return false;
      if((ty == MB_EV_LIQ_SWEEP || ty == MB_EV_FAKE_BREAK) && rk >= 1)
         return false;
      // LOCK FIX: the trend simply resuming - an M15+ BOS or displacement our way - answers it too.
      if((ty == MB_EV_BOS || ty == MB_EV_DISPLACEMENT) && rk >= 2)
         return false;
   }
   // LOCK FIX: and so does an M5 close beyond the sweep's own extreme - the swept side won after all.
   double c5 = iClose(_Symbol, PERIOD_M5, 1);
   double ext = G_MB_EV[sw].extreme;
   if(c5 > 0.0 && ext > 0.0 && iTime(_Symbol, PERIOD_M5, 1) >= t0_close &&
      ((dir > 0 && c5 > ext) || (dir < 0 && c5 < ext)))
      return false;

   // Confirmations of the turn, after the sweep.
   bool disp = false, mss = false, reclaim = false;
   string conf = "";
   int min_rank = (MBEventRank(G_MB_EV[sw].tfi) >= 1) ? 1 : 0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time < t0_close || G_MB_EV[idx].dir != -dir) continue;
      if(MBEventRank(G_MB_EV[idx].tfi) < min_rank) continue;
      if(!MBEventRelevant(idx)) continue;
      int ty = G_MB_EV[idx].type;
      if(ty == MB_EV_DISPLACEMENT && !disp) { disp = true; conf += StringFormat(" + %s displacement", MBTFName(G_MB_EV[idx].tfi)); }
      if((ty == MB_EV_MSS || ty == MB_EV_BOS) && !mss) { mss = true; conf += StringFormat(" + %s %s", MBTFName(G_MB_EV[idx].tfi), MBEventName(ty)); }
      if(ty == MB_EV_RECLAIM && !reclaim) { reclaim = true; conf += StringFormat(" + %s reclaim", MBTFName(G_MB_EV[idx].tfi)); }
   }
   int confirms = (disp ? 1 : 0) + (mss ? 1 : 0) + (reclaim ? 1 : 0);
   int need = htf ? 1 : MathMax(1, MBVetoReversalConfirms);
   if(confirms < need)
      return false;

   why = StringFormat("V1 reversal: %s %s %s @ %s (%d bars)%s - no %s until the market answers back",
                      MBTFName(G_MB_EV[sw].tfi),
                      (dir < 0 ? "sell-side" : "buy-side"),
                      MBEventName(G_MB_EV[sw].type),
                      DoubleToString(G_MB_EV[sw].level, _Digits),
                      MBEventAgeBars(G_MB_EV[sw]), conf,
                      (dir < 0 ? "SELL" : "BUY"));
   return true;
}

// V1. True when the market has just turned against `dir`: ANY relevant opposite sweep / fake break
// (M5 and up) that is confirmed and not yet answered - a newer, smaller, unconfirmed sweep does not
// hide an older H4 one. Higher timeframes are checked first.
bool MBVetoReversalCheck(const int dir, string &why)
{
   for(int rank = 4; rank >= 1; rank--)
   {
      for(int idx = 0; idx < MB_EV_MAX; idx++)
      {
         if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != -dir) continue;   // cheap filters first
         if(G_MB_EV[idx].type != MB_EV_LIQ_SWEEP && G_MB_EV[idx].type != MB_EV_FAKE_BREAK) continue;
         if(MBEventRank(G_MB_EV[idx].tfi) != rank) continue;
         if(!MBEventRelevant(idx)) continue;
         if(MBVetoReversalFrom(dir, idx, why))
            return true;
      }
   }
   return false;
}

// V2 + V3. The zone the entry leans on, and the one it is walking into.
bool MBVetoZoneCheck(const int dir, const double price, string &why)
{
   if(!EnableZoneRoleEngine)
      return false;
   double atr5 = ((G_MB_ATR[1] > 0.0) ? G_MB_ATR[1] : ATRPointsManual(PERIOD_M5, 14, 1)) * _Point;
   if(atr5 <= 0.0)
      return false;

   double res = ZoneMapNearestResistance(price);
   double sup = ZoneMapNearestSupport(price);

   if(MBVetoZoneRole)
   {
      double lean = (dir < 0) ? res : sup;
      if(lean > 0.0 && MathAbs(lean - price) <= MBVetoZoneNearATR * atr5)
      {
         string zwhy = "";
         int v = MBZoneEntryVerdict(dir, lean, zwhy);
         if(v <= 0)
         {
            why = StringFormat("V2 zone role: %s", zwhy);
            return true;
         }
      }
   }

   if(MBVetoNoRoom)
   {
      double other = (dir < 0) ? sup : res;
      if(other > 0.0)
      {
         SMBZone z;
         if(MBZoneRead(other, z) && !z.pending_break && ((dir < 0 && z.role > 0) || (dir > 0 && z.role < 0)))
         {
            double room_pts = (dir < 0) ? (price - z.hi) / _Point : (z.lo - price) / _Point;
            double need_pts = MathMax(1.0, BaseBasketTPPoints()) * MathMax(0.1, MBVetoRoomTPMult);
            if(room_pts < need_pts)
            {
               why = StringFormat("V3 no room: %s %s holds %.0f pts away (target needs %.0f) - %s",
                                  MBZoneRoleName(z.role), DoubleToString(other, _Digits), MathMax(0.0, room_pts), need_pts,
                                  MBZoneStateName(z.state));
               return true;
            }
         }
      }
   }
   return false;
}

// V4. Moving hard the other way right now.
bool MBVetoAccelerationCheck(const int dir, string &why)
{
   if(G_MB_LIVE_DIR == -dir)
   {
      why = "V4 against: the forming M1 candle is displacing the other way";
      return true;
   }
   // FIX(sell-into-bull): the forming M5 candle running the other way - body >= 0.8 ATR(M5), closing in
   // its far quarter. The M1 reading misses it when the M1 candles pause inside the M5 push.
   if(EnableCandleReadingGate && G_MB_ATR[1] > 0.0)
   {
      double o5 = iOpen(_Symbol, PERIOD_M5, 0), h5 = iHigh(_Symbol, PERIOD_M5, 0), l5 = iLow(_Symbol, PERIOD_M5, 0);
      double c5 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double atr5 = G_MB_ATR[1] * _Point;
      if(o5 > 0.0 && c5 > 0.0 && h5 > l5 && MathAbs(c5 - o5) >= 0.8 * atr5)
      {
         double pos5 = (c5 - l5) / (h5 - l5);
         int d5 = (c5 > o5 && pos5 >= 0.75) ? 1 : ((c5 < o5 && pos5 <= 0.25) ? -1 : 0);
         if(d5 == -dir)
         {
            why = StringFormat("V4 against: the forming M5 candle is running the other way (body %.1f ATR)", MathAbs(c5 - o5) / atr5);
            return true;
         }
      }
   }
   // Stage 14 (C1): liquidity was just swept and reclaimed the other way on M5 or higher - the bar-close
   // engine will call it a reversal in a moment; do not enter into it in the meantime.
   string lsw = "";
   if(G_MB_LSW_TFI >= 1 && (TimeCurrent() - G_MB_LSW_TIME) <= 60 && MBLiveSweepFresh(-dir, lsw))
   {
      why = "V4 against: " + lsw + " the other way";
      return true;
   }
   if(G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == -dir &&
      G_MB_ACCEL[0] > 0 && G_MB_ACCEL_DIR[0] == -dir)
   {
      why = StringFormat("V4 against: accelerating M1 displacement the other way (body %.1f ATR)", G_MB_LAST[0].body_atr);
      return true;
   }
   return false;
}

// Does the Market Brain stand in for an older gate that asks the same question?
//   with the trade (bias toward dir)  -> yes, for the score-cost gates and the location gates:
//                                        the veto (V1-V4) and the judge (location, trigger,
//                                        impulse speed) answer them with fresher evidence;
//   neutral                           -> only the score-cost gates (clarity, old level, failed
//                                        break); the old location guards and the HTF bias stay,
//                                        because with no direction of its own the brain must not
//                                        wave a trade past the larger timeframes or a bad place;
//   against the trade                 -> never: both layers judge it.
// Not before the brain has seen enough bars to have an opinion.
int MBBiasAlign(const int dir)
{
   return dir * G_MB_BIAS;
}

// ENTRY COUNCIL (owner rule: read the local leg, the candles and the zone together). True = this
// direction may not be entered now; the other direction is still free to qualify.
//  1. local layer, M5 pressure and M15 pressure all the other way - no entry, a sweep included,
//     unless a closed M5 candle turned this way after a confirmed M15+ liquidity reversal;
//  2. (sweeps) a sweep is not its own proof - see the judge and the SWEEP entry;
//  3. a holding zone of the other side right in front (support under a SELL, resistance over a
//     BUY) - wait until an M5 candle closes through it;
//  4. a weak global bias (transition, or confidence below CouncilWeakGlobalConf) does not override
//     the local leg the other way - unless an M5 candle turned, or an M1 one did at a spent leg.
string G_MB_COUNCIL_UZ[2];   // short panel text of the last council refusal per side (0 = SELL, 1 = BUY)

bool MBGlobalWeak()
{
   return (MathAbs(G_MB_BIAS) <= 1 || G_MB_BIAS_CONF < CouncilWeakGlobalConf);
}

bool MBCouncilEval(const int dir, string &why, string &uz)
{
   why = "";
   uz = "";
   int loc = MBLayerLocal();
   int p5 = MBPressureSide(1), p15 = MBPressureSide(2);
   bool m5_turn = MBCandleConfirms(1, dir);
   // 1. The triple rule.
   if(loc == -dir && p5 == -dir && p15 == -dir)
   {
      string w = "";
      datetime t = 0;
      if(!(m5_turn && MBReversalAfter(dir, 2, 4, true, TimeCurrent() - 3600, w, t)))
      {
         why = "council: local leg, M5 and M15 candles all the other way";
         uz = "lokal + M5 + M15 qarshi";
         return true;
      }
   }
   // 4. A weak global bias does not override the local leg.
   if(loc == -dir && dir * G_MB_BIAS >= 0 && MBGlobalWeak() &&
      !(m5_turn || (MBCandleConfirms(0, dir) && MBLocalLegSpent(-dir))))
   {
      why = StringFormat("council: weak global (%s, %d%%) does not override the local leg the other way",
                         MBBiasName(G_MB_BIAS), G_MB_BIAS_CONF);
      uz = "zaif global, lokal qarshi";
      return true;
   }
   // 3. A holding zone of the other side right in front.
   double atr5 = G_MB_ATR[1] * _Point;
   if(EnableZoneRoleEngine && atr5 > 0.0 && CouncilZoneATR5 > 0.0)
   {
      double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
      double lvl = (dir > 0) ? ZoneMapNearestResistance(px) : ZoneMapNearestSupport(px);
      if(px > 0.0 && lvl > 0.0 && dir * (lvl - px) <= CouncilZoneATR5 * atr5 && dir * (lvl - px) >= -0.1 * atr5)
      {
         SMBZone z;
         double c5 = iClose(_Symbol, PERIOD_M5, 1);
         bool broken = (c5 > 0.0 && dir * (c5 - lvl) > 0.1 * atr5);
         // Plan stage 3 (level fatigue): a zone tested four times or more is wearing out - breakout
         // risk, not a wall; it does not hold the entry back.
         if(!broken && MBZoneRead(lvl, z) && z.role == -dir && !z.pending_break && z.touches < 4)
         {
            why = StringFormat("council: %s %s holds right in front (%.2f ATR) - waiting for an M5 close through it",
                               (dir > 0 ? "resistance" : "support"), DoubleToString(lvl, _Digits), MathAbs(lvl - px) / atr5);
            uz = StringFormat("oldida %s %s", (dir > 0 ? "resistance" : "support"), DoubleToString(lvl, _Digits));
            return true;
         }
      }
   }
   return false;
}

// Memoised per tick and direction - the brain entries ask several times a tick.
bool MBCouncilBlocks(const int dir, string &why)
{
   why = "";
   if(!EnableEntryCouncil || !EnableMarketBrain || !EnableMarketBrainEngines || dir == 0 || !G_MB_BRAIN_PRIMED)
      return false;
   static long   cb_msc[2] = {0, 0};
   static bool   cb_res[2] = {false, false};
   static string cb_why[2];
   int k = (dir > 0) ? 1 : 0;
   long msc = SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC);
   if(msc != cb_msc[k] || msc == 0)
   {
      cb_res[k] = MBCouncilEval(dir, cb_why[k], G_MB_COUNCIL_UZ[k]);
      cb_msc[k] = msc;
   }
   why = cb_why[k];
   return cb_res[k];
}

bool MBCouncilOk(const int dir)
{
   string w = "";
   return !MBCouncilBlocks(dir, w);
}

bool MBStandsInFor(const int dir, const bool location_gate)
{
   if(!MBOwnsDuplicateGates || !EnableMarketBrain || !EnableMarketBrainEngines || !EnableMBVeto || dir == 0)
      return false;
   if(!G_MB_BRAIN_PRIMED)
      return false;
   int a = dir * G_MB_BIAS;
   if(a >= 1)
      return true;
   if(a == 0)
      return !location_gate;
   // A local leg against the global bias: the old score taxes (HTF against, old level...) are exactly
   // what the local case overrides; the old location guards stay.
   if(MBLocalOkFor(dir) || (a >= -2 && MBRangeRules()))
      return !location_gate;
   return false;
}

// V0. Direction permission from the Market Brain bias.
bool MBPermissionCheck(const int dir, string &why)
{
   if(!EnableMBPermission || !EnableMarketBrain)
      return false;

   int a = dir * G_MB_BIAS;   // +3 strongly aligned ... -3 strongly against
   string side = (dir > 0) ? "BUY" : "SELL";
   bool reversal_type = IsReversalOpportunityType(G_OPP_TYPE);

   if(G_MB_DEAD_DIR == dir && TimeCurrent() < G_MB_DEAD_UNTIL && a < 3)
   {
      why = StringFormat("V0 invalidation memory: the %s thesis died %d min ago - no %s without a strong bias",
                         (dir > 0 ? "bullish" : "bearish"),
                         (int)((TimeCurrent() - G_MB_DEAD_TIME) / 60), side);
      return true;
   }
   // PLAN STAGE 1: a reversal that reached the unlock stage (sweep, displacement, MSS, held retest)
   // is the proof a counter-bias entry needs - the bias catches up later.
   if(a < 0 && MBStructStageFor(dir) >= MathMax(1, LockUnlockStage))
      return false;
   // REGIME DOMINANCE: in a range / compression a weak or turning bias does not veto.
   if(a < 0 && a >= -2 && MBRangeRules())
      return false;
   // LOCAL TRADING: against the global bias, a local leg that way may still be traded - a strong one
   // against the strongest bias, an ordinary one against a weak or turning bias.
   if(a < 0 && MBLocalOkFor(dir))
      return false;   // a local leg strong enough for this bias (guards: freshness, expansion, waves, pause, record)
   if(a == -3)
   {
      why = StringFormat("V0 permission: bias %s - %s blocked", MBBiasName(G_MB_BIAS), side);
      return true;
   }
   if(a == -2 && !(reversal_type && G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED + MathMax(0, MBPermExceptionMargin)))
   {
      why = StringFormat("V0 permission: bias %s - %s only on an exceptional reversal setup (score %d, needs %d)",
                         MBBiasName(G_MB_BIAS), side, G_SCORE_FINAL, G_SCORE_MIN_REQUIRED + MathMax(0, MBPermExceptionMargin));
      return true;
   }
   if(a == -1)
   {
      why = StringFormat("V0 permission: market is %s - no %s while it turns away", MBBiasName(G_MB_BIAS), side);
      return true;
   }
   // A displacement the new way IS the transition confirming itself - a momentum entry with it is
   // allowed alongside reversal / reclaim types.
   bool momentum_confirms = (G_OPP_TYPE == OPP_TYPE_MOMENTUM_SCALP) &&
                            (G_MB_LIVE_DIR == dir || MBCandleConfirms(0, dir) || MBCandleConfirms(1, dir));
   if(a == 1 && !reversal_type && !momentum_confirms)
   {
      why = StringFormat("V0 permission: %s - only reversal / reclaim %s entries (this is %s)",
                         MBBiasName(G_MB_BIAS), side, OpportunityTypeToString(G_OPP_TYPE));
      return true;
   }
   return false;
}

// The gate. true = allowed.
bool MBVetoAllowsEntry(const int dir, string &why)
{
   why = "";
   if(!EnableMBVeto || !EnableMarketBrainEngines || dir == 0)
      return true;

   double price = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
   bool blocked = false;
   string late_uz = "";

   if(MBPermissionCheck(dir, why))
      blocked = true;
   else if(MBVetoReversal && MBVetoReversalCheck(dir, why))
      blocked = true;
   else if(MBVetoZoneCheck(dir, price, why))
      blocked = true;
   else if(MBVetoAcceleration && MBVetoAccelerationCheck(dir, why))
      blocked = true;
   else if(MBExhausted(dir, why))
   {
      why = "V5 exhausted: " + why;   // stage 13 (A4): no new entry into a spent impulse
      blocked = true;
   }
   else if(MBLockBlocks(dir, why))
      blocked = true;                  // V7: direction lock (plan stage 1)
   else if(MBLateBlocks(dir, why, late_uz))
      blocked = true;                  // V8: late in the leg / exhausted / target already taken (plan stage 2)
   else if(MBReentryBlocks(dir, why, late_uz))
      blocked = true;                  // V9: re-entry after a dead idea / too many failed attempts (plan stage 4)
   else if(MBCouncilBlocks(dir, why))
      blocked = true;                  // V6: the entry council (local + candles + zone)

   if(!blocked)
      return true;

   // Counted per decision, not per tick: once per M1 bar for the same reason.
   {
      static datetime vc_bar = 0;
      static string vc_why = "";
      datetime vb = iTime(_Symbol, PERIOD_M1, 0);
      if(vb != vc_bar || why != vc_why)
      {
         G_MB_VETO_COUNT++;
         vc_bar = vb;
         vc_why = why;
      }
   }
   if((MBVetoPrintOnUse && VerboseLogs) && (why != G_MB_VETO_LAST || (TimeCurrent() - G_MB_VETO_LAST_PRINT) >= 60))
   {
      PrintFormat("[SIRUS VETO] %s %s @ %s blocked | %s",
                  (dir > 0 ? "BUY" : "SELL"), OpportunityTypeToString(G_OPP_TYPE),
                  DoubleToString(price, _Digits), why);
      G_MB_VETO_LAST = why;
      G_MB_VETO_LAST_PRINT = TimeCurrent();
   }
   return false;
}
