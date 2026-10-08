//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20e_Cost_Edge                                   |
//| Plan stage 6: cashback economics - the net edge of an entry,     |
//| the spread memory per server hour and the broker reality memory. |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// "Cashback is not a reason to trade - it makes a good trade's economics better." A cashback basket
// targets a few hundred points, and price has to travel the spread, the slippage and the target
// before the basket closes. Two questions before an entry:
//
//  SPREAD MEMORY   what is normal spread at this server hour? (an average per hour, learnt per M1
//                  bar and kept across restarts). Now above SpreadAbnormalMult x normal -> no entry:
//                  cashback does not pay for a spread that is twice what it usually is.
//  NET EDGE        (cashback mode) the room to the nearest obstacle ahead - a holding zone or a
//                  liquidity level - against what the trade needs: spread + average slippage + TP.
//                  Room shorter than NetEdgeRoomMult x that -> no entry: the trade cannot pay.
//  BROKER REALITY  the same per-hour memory for slippage on fills; shown on the panel, added to the cost.
//
// Speed: one spread sample per M1 bar; the checks are a few comparisons when an entry is asked for.

input group "47e — CASHBACK IQTISODI (reja 6-bosqich)"
input bool   EnableSpreadMemory       = true;   // Har server soati uchun odatiy spread o'rganiladi (qayta ishga tushganda saqlanadi); hozirgi spread odatiydan SpreadAbnormalMult marta katta bo'lsa - kirish yo'q
input double SpreadAbnormalMult       = 2.0;    // Odatiy spreaddan shuncha marta katta - g'ayritabiiy
input bool   EnableNetEdge            = true;   // Cashback rejimi: oldindagi to'siqqacha joy (spread + slippage + TP) x NetEdgeRoomMult dan kam bo'lsa - kirish yo'q (savdo o'zini oqlay olmaydi)
input double NetEdgeRoomMult          = 1.2;    // Joy kamida kerakli harakatning shuncha barobari bo'lsin
input double RebateUSDPerLot          = 0.0;    // Ixtiyoriy: brokerning 1 lot uchun cashback summasi ($) - faqat panelda sof foyda ko'rsatish uchun

double   G_CX_SPR[24];          // average spread per server hour (points)
int      G_CX_SPR_N[24];
double   G_CX_SLIP[24];         // average slippage per server hour (points, + = worse)
int      G_CX_SLIP_N[24];
bool     G_CX_LOADED = false;
datetime G_CX_BAR    = 0;
int      G_CX_SAVE_CNT = 0;

string MBCeKey(const string f, const int h) { return StringFormat("SIRUS_CE_%s_%I64d_%s%02d", _Symbol, MagicNumber, f, h); }

int MBCeHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
}

void MBCeLoad()
{
   if(G_CX_LOADED)
      return;
   G_CX_LOADED = true;
   for(int h = 0; h < 24; h++)
   {
      G_CX_SPR[h] = 0.0; G_CX_SPR_N[h] = 0; G_CX_SLIP[h] = 0.0; G_CX_SLIP_N[h] = 0;
      if(MQLInfoInteger(MQL_TESTER))
         continue;
      if(GlobalVariableCheck(MBCeKey("S", h)))  G_CX_SPR[h]    = GlobalVariableGet(MBCeKey("S", h));
      if(GlobalVariableCheck(MBCeKey("SN", h))) G_CX_SPR_N[h]  = (int)GlobalVariableGet(MBCeKey("SN", h));
      if(GlobalVariableCheck(MBCeKey("P", h)))  G_CX_SLIP[h]   = GlobalVariableGet(MBCeKey("P", h));
      if(GlobalVariableCheck(MBCeKey("PN", h))) G_CX_SLIP_N[h] = (int)GlobalVariableGet(MBCeKey("PN", h));
   }
}

void MBCeSave(const int h)
{
   if(MQLInfoInteger(MQL_TESTER))
      return;
   GlobalVariableSet(MBCeKey("S", h), G_CX_SPR[h]);
   GlobalVariableSet(MBCeKey("SN", h), G_CX_SPR_N[h]);
   GlobalVariableSet(MBCeKey("P", h), G_CX_SLIP[h]);
   GlobalVariableSet(MBCeKey("PN", h), G_CX_SLIP_N[h]);
}

// One spread sample per M1 bar into this hour's average (the first 30 samples a plain mean, then a
// slow moving average that follows the broker's changes without jumping on one spike).
void MBCostUpdate()
{
   if(!EnableSpreadMemory)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 <= 0 || m1 == G_CX_BAR)
      return;
   G_CX_BAR = m1;
   MBCeLoad();
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spr <= 0.0)
      return;
   int h = MBCeHour();
   int n = G_CX_SPR_N[h];
   // A spike already twice the learnt normal is not learnt (it would teach the memory that spikes are normal).
   if(n >= 30 && spr > 3.0 * G_CX_SPR[h])
      return;
   double a = (n < 30) ? 1.0 / (n + 1) : 0.03;
   G_CX_SPR[h] = (n == 0) ? spr : G_CX_SPR[h] + a * (spr - G_CX_SPR[h]);
   G_CX_SPR_N[h] = MathMin(100000, n + 1);
   if(++G_CX_SAVE_CNT >= 10)
   {
      G_CX_SAVE_CNT = 0;
      MBCeSave(h);
   }
}

// Called by SlippageRecord (06) on every fill: + = worse than asked for.
void MBCostSlipRecord(const double slip_pts)
{
   MBCeLoad();
   int h = MBCeHour();
   int n = G_CX_SLIP_N[h];
   double a = (n < 20) ? 1.0 / (n + 1) : 0.05;
   G_CX_SLIP[h] = (n == 0) ? slip_pts : G_CX_SLIP[h] + a * (slip_pts - G_CX_SLIP[h]);
   G_CX_SLIP_N[h] = MathMin(100000, n + 1);
   MBCeSave(h);
}

// This hour's normal spread (or the mean of the hours learnt so far while this one is young).
double MBNormalSpread()
{
   MBCeLoad();
   int h = MBCeHour();
   if(G_CX_SPR_N[h] >= 20)
      return G_CX_SPR[h];
   double s = 0.0;
   int k = 0;
   for(int i = 0; i < 24; i++)
      if(G_CX_SPR_N[i] >= 20) { s += G_CX_SPR[i]; k++; }
   return (k > 0) ? s / k : 0.0;
}

double MBExpectedSlip()
{
   MBCeLoad();
   int h = MBCeHour();
   return (G_CX_SLIP_N[h] >= 5) ? MathMax(0.0, G_CX_SLIP[h]) : 0.0;
}

// Room to the nearest obstacle ahead in dir (a holding zone or a liquidity level of any class), points.
double MBRoomAhead(const int dir, const double px)
{
   double best = 0.0;
   double z = (dir > 0) ? ZoneMapNearestResistance(px) : ZoneMapNearestSupport(px);
   if(z > 0.0 && dir * (z - px) > 0.0)
   {
      SMBZone zz;
      if(!MBZoneRead(z, zz) || (zz.role == -dir && !zz.pending_break && zz.touches < 4))
         best = z;
   }
   double l = MBLqNearestAhead(dir, px, 1);
   if(l > 0.0 && (best <= 0.0 || MathAbs(l - px) < MathAbs(best - px)))
      best = l;
   return (best > 0.0) ? MathAbs(best - px) / _Point : 0.0;
}

// True = the entry cannot pay here (abnormal spread, or no room for spread + slippage + target).
bool MBCostBlocks(const int dir, string &why, string &uz)
{
   why = "";
   uz = "";
   if(dir == 0)
      return false;
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(EnableSpreadMemory)
   {
      double norm = MBNormalSpread();
      if(norm > 0.0 && spr > SpreadAbnormalMult * norm)
      {
         why = StringFormat("cost: spread %.0f is %.1fx this hour's normal %.0f", spr, spr / norm, norm);
         uz = StringFormat("spread %.0f (odatiy %.0f)", spr, norm);
         return true;
      }
   }
   if(EnableNetEdge && EnableRebateMode)
   {
      double px = SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));
      double tp = RebateTargetPoints();
      double need = spr + MBExpectedSlip() + tp;
      double room = MBRoomAhead(dir, px);
      if(tp > 0.0 && room > 0.0 && room < NetEdgeRoomMult * need)
      {
         why = StringFormat("net edge: room %.0f pts to the obstacle ahead < %.1f x (spread %.0f + slippage %.0f + TP %.0f)",
                            room, NetEdgeRoomMult, spr, MBExpectedSlip(), tp);
         uz = StringFormat("joy %.0f < kerak %.0f", room, NetEdgeRoomMult * need);
         return true;
      }
   }
   return false;
}

string MBCostPanelText()
{
   if(!EnableSpreadMemory && !EnableNetEdge)
      return "";
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double norm = MBNormalSpread();
   string t = (norm > 0.0) ? StringFormat("Xarajat: spread %.0f (bu soat odatiy %.0f%s)", spr, norm, (spr > SpreadAbnormalMult * norm ? " - BAND" : ""))
                           : StringFormat("Xarajat: spread %.0f (o'rganilmoqda)", spr);
   double slip = MBExpectedSlip();
   if(slip > 0.0) t += StringFormat(" · slippage ~%.0f", slip);
   if(EnableRebateMode)
   {
      double tp = RebateTargetPoints();
      t += StringFormat(" · kerakli harakat %.0f", spr + slip + tp);
      if(RebateUSDPerLot > 0.0)
         t += StringFormat(" · cashback $%.2f/lot", RebateUSDPerLot);
   }
   return t;
}
