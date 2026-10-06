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
input int    MBPermExceptionMargin    = 2;      // V0: zaif qarama-qarshi bias'da faqat reversal setup va ball >= minimum + shu
input bool   MBOwnsDuplicateGates     = true;   // Miya savdo tomonida bo'lsa, xuddi shu savolni beradigan ESKI filtrlar (joy, impuls quvish, HTF, eski daraja, singan daraja, aniqlik) chetga turadi - javobni miya veto'si va hakami beradi. Miya qarshi bo'lsa ikkala qatlam ham ishlaydi

int      G_MB_VETO_COUNT = 0;
string   G_MB_VETO_LAST = "";
datetime G_MB_VETO_LAST_PRINT = 0;

// V1 for one opposite liquidity event (index sw): true when it stands, confirmed and unanswered.
bool MBVetoReversalFrom(const int dir, const int sw, string &why)
{
   datetime t0 = G_MB_EV[sw].time;
   bool htf = (MBEventRank(G_MB_EV[sw].tfi) >= 3);

   // The market answering back in our direction after it lifts the veto.
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= t0 || G_MB_EV[idx].dir != dir) continue;
      if(MBEventRank(G_MB_EV[idx].tfi) < 2) continue;
      int ty = G_MB_EV[idx].type;
      if(ty == MB_EV_ACCEPTANCE || ty == MB_EV_MSS || ty == MB_EV_LIQ_SWEEP || ty == MB_EV_FAKE_BREAK)
         return false;
   }

   // Confirmations of the turn, after the sweep.
   bool disp = false, mss = false, reclaim = false;
   string conf = "";
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time < t0 || G_MB_EV[idx].dir != -dir) continue;
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
         if(!MBEventRelevant(idx)) continue;
         if(G_MB_EV[idx].dir != -dir) continue;
         if(G_MB_EV[idx].type != MB_EV_LIQ_SWEEP && G_MB_EV[idx].type != MB_EV_FAKE_BREAK) continue;
         if(MBEventRank(G_MB_EV[idx].tfi) != rank) continue;
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
                         (int)((TimeCurrent() - (G_MB_DEAD_UNTIL - MathMax(1, MBInvalidationMemoryM5) * PeriodSeconds(PERIOD_M5))) / 60), side);
      return true;
   }
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
   if(a == 1 && !reversal_type)
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

   if(MBPermissionCheck(dir, why))
      blocked = true;
   else if(MBVetoReversal && MBVetoReversalCheck(dir, why))
      blocked = true;
   else if(MBVetoZoneCheck(dir, price, why))
      blocked = true;
   else if(MBVetoAcceleration && MBVetoAccelerationCheck(dir, why))
      blocked = true;

   if(!blocked)
      return true;

   G_MB_VETO_COUNT++;
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
