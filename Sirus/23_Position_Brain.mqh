//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 23_Position_Brain                               |
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

input group "46 — MARKET BRAIN: POSITION BRAIN (SMART GRID)"
input bool   EnableMBPositionBrain    = true;   // Ochiq savat thesis'ini kuzatish: o'lsa grid to'xtaydi va savat break-even'da yopiladi
input bool   MBGridNeedsResponse      = true;   // Grid faqat zonada sham reaksiyasi bo'lsa qo'shiladi (qarshi displacement / break'da qo'shilmaydi)
input int    MBGridResponseMaxBars    = 15;     // Reaksiya bo'lmasa ko'pi bilan shuncha M1 bar kutadi, keyin qo'shadi
input int    MBBreakEvenCoverPoints   = 30;     // Thesis o'lganda savat shu punkt foyda bilan yopiladi (break-even + qoplama)
input bool   MBPositionPrintOnUse     = true;   // Thesis o'limi / qutqaruv / grid kutishini jurnalga yozish ([SIRUS POSITION])

datetime G_MB_PB_BASKET    = 0;     // open time of the first position of the watched basket
int      G_MB_PB_DIR       = 0;
bool     G_MB_PB_DEAD      = false;
datetime G_MB_PB_DEAD_TIME = 0;
string   G_MB_PB_DEAD_WHY  = "";
bool     G_MB_PB_RESCUED   = false;
int      G_MB_PB_WAIT_ORDERS = -1;  // grid response wait: rung being held
datetime G_MB_PB_WAIT_SINCE  = 0;

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

// Why the basket's thesis is dead, or "" when it is not.
string MBBasketDeathReason(const int dir, const datetime since)
{
   string what = "";
   datetime swt = 0;
   if(MBReversalAfter(-dir, 1, 4, true, since, what, swt))
      return "confirmed liquidity reversal against it: " + what;

   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= since || G_MB_EV[idx].dir != -dir) continue;
      if(MBEventRank(G_MB_EV[idx].tfi) < 2) continue;
      int ty = G_MB_EV[idx].type;
      if(ty == MB_EV_MSS || ty == MB_EV_ACCEPTANCE)
         return StringFormat("%s %s against it @ %s", MBTFName(G_MB_EV[idx].tfi), MBEventName(ty),
                             DoubleToString(G_MB_EV[idx].level, _Digits));
   }

   datetime th_died = G_MB_DEAD_UNTIL - MathMax(1, MBInvalidationMemoryM5) * PeriodSeconds(PERIOD_M5);
   if(EnableMarketBrain && G_MB_TH_DIR == dir && G_MB_TH_STATE == MB_TH_INVALIDATED && G_MB_DEAD_DIR == dir && th_died > since)
      return StringFormat("Market Brain %s thesis invalidated (beyond %s)", (dir > 0 ? "bullish" : "bearish"),
                          DoubleToString(G_MB_TH_INVALID, _Digits));
   return "";
}

// Called every tick from CoreUpdate.
void MBPositionBrainUpdate()
{
   if(!EnableMBPositionBrain || !EnableMarketBrainEngines)
      return;

   datetime opened = (G_BASKET_ORDERS > 0) ? MBBasketOpenTime() : 0;
   if(opened == 0)
   {
      G_MB_PB_BASKET = 0;
      G_MB_PB_DIR = 0;
      G_MB_PB_DEAD = false;
      G_MB_PB_DEAD_TIME = 0;
      G_MB_PB_DEAD_WHY = "";
      G_MB_PB_RESCUED = false;
      G_MB_PB_WAIT_ORDERS = -1;
      return;
   }

   int dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : ((G_BASKET_DIRECTION == POSITION_TYPE_SELL) ? -1 : 0);
   if(dir == 0)
      return;

   if(opened != G_MB_PB_BASKET || dir != G_MB_PB_DIR)
   {
      G_MB_PB_BASKET = opened;
      G_MB_PB_DIR = dir;
      G_MB_PB_DEAD = false;
      G_MB_PB_DEAD_TIME = 0;
      G_MB_PB_DEAD_WHY = "";
      G_MB_PB_RESCUED = false;
      G_MB_PB_WAIT_ORDERS = -1;
   }

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
         if((MBPositionPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS POSITION] %s basket RESCUE allowed: %s - additions and the normal target are back",
                        (dir > 0 ? "BUY" : "SELL"), what);
      }
   }
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

   if(!MBGridNeedsResponse)
      return true;

   // Against: a fresh displacement or a genuine break the other way on M1 / M5.
   bool against = (G_MB_LAST[0].intent == MB_CI_DISPLACEMENT && G_MB_LAST[0].dir == -dir) ||
                  (G_MB_LAST[1].intent == MB_CI_DISPLACEMENT && G_MB_LAST[1].dir == -dir) ||
                  (G_MB_LIVE_DIR == -dir);
   string against_what = against ? "displacement against the basket" : "";
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
   if(against)
   {
      reason = "holding - " + against_what + " (no averaging into a breakdown)";
      return false;
   }

   // Response: the market defending the basket's side at this price.
   bool response = (MBTriggerCandle(G_MB_LAST[0], dir) && G_MB_LAST[0].intent != MB_CI_CONTINUATION) ||
                   (MBTriggerCandle(G_MB_LAST[1], dir) && G_MB_LAST[1].intent != MB_CI_CONTINUATION) ||
                   (G_MB_LIVE_DIR == dir);
   string ev_what = "";
   if(!response)
      response = MBFreshTriggerEvent(dir, ev_what);
   if(response)
   {
      G_MB_PB_WAIT_ORDERS = -1;
      return true;
   }

   // No response yet: wait a while for one, then add anyway.
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
   if((MBPositionPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS POSITION] no response after %d M1 bars - grid addition goes in", waited);
   G_MB_PB_WAIT_ORDERS = -1;
   return true;
}

// Exit hook: a dead thesis closes the basket at break-even plus the cover.
bool MBBasketBreakEvenExit(const double basket_points, string &why)
{
   if(!EnableMBPositionBrain || !G_MB_PB_DEAD)
      return false;
   if(basket_points >= (double)MathMax(0, MBBreakEvenCoverPoints))
   {
      why = StringFormat("thesis dead - break-even exit at +%.0f pts (%s)", basket_points, G_MB_PB_DEAD_WHY);
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
