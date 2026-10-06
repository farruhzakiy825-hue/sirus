//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 90_Reason_Code                                  |
//| Reason Code: why every order was opened (journal + CSV)          |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// REASON CODE (engine plan, phase 0)
//---------------------------------------------------------------------
// Every order the EA opens - first entry, grid addition, scale-in - writes down what the
// robot believed at that moment: the signal and its score, the market state, the structure on
// every timeframe it reads, the nearest zones, where price sat in its leg, the news state and how
// the lot was built. A line of CONFLICTS lists anything in that picture that argued against the
// trade, so a bad entry can be traced to the reasoning that let it through.
//
// Nothing here changes a decision. It only records them. The same record goes to the Experts
// journal and, when ReasonCodeToFile is on, to MQL5/Files/Sirus_ReasonCode_<symbol>_<magic>.csv
// (in the Strategy Tester: the agent's MQL5/Files folder) so a whole test day can be read at once.
//=====================================================================

int G_RC_SEQ = 0;

string RCDirText(const int dir)
{
   if(dir > 0) return "UP";
   if(dir < 0) return "DOWN";
   return "flat";
}

string RCMSStateName(const int st)
{
   switch(st)
   {
      case MS_RANGE:        return "range";
      case MS_IMPULSE:      return "impulse";
      case MS_CONTINUATION: return "continuation";
      case MS_REVERSAL:     return "reversal";
      case MS_PULLBACK:     return "pullback";
   }
   return "?";
}

string RCCsvSafe(const string text)
{
   string out = text;
   StringReplace(out, ";", ",");
   StringReplace(out, "\r", " ");
   StringReplace(out, "\n", " ");
   return out;
}

string RCShort(const string text, const int max_len)
{
   if(StringLen(text) <= max_len)
      return text;
   return StringSubstr(text, 0, max_len - 3) + "...";
}

// Everything in the picture that argued against an entry in this direction.
string RCConflicts(const int dir)
{
   string c = "";
   if(G_STRUCTURE_DIR != 0 && G_STRUCTURE_DIR == -dir)
      c += StringFormat(" swing-chain %s;", RCDirText(G_STRUCTURE_DIR));
   if(G_STRUCTURE_HTF_DIR != 0 && G_STRUCTURE_HTF_DIR == -dir)
      c += StringFormat(" HTF chain %s;", RCDirText(G_STRUCTURE_HTF_DIR));
   if(G_STRUCTURE_EVENT == -1 && G_STRUCTURE_DIR == dir)
      c += " own structure just CHoCH'd;";
   if(G_VERDICT_DIR != 0 && G_VERDICT_DIR == -dir)
      c += StringFormat(" verdict %s (%d/%d);", RCDirText(G_VERDICT_DIR), G_VERDICT_AGREE, G_VERDICT_ACTIVE);
   string tf_name[3] = {"M1", "M5", "M15"};
   for(int i = 0; i < 3; i++)
      if(G_MS_DIR[i] != 0 && G_MS_DIR[i] == -dir &&
         (G_MS_STATE[i] == MS_IMPULSE || G_MS_STATE[i] == MS_CONTINUATION || G_MS_STATE[i] == MS_REVERSAL))
         c += StringFormat(" %s %s %s;", tf_name[i], RCDirText(G_MS_DIR[i]), RCMSStateName(G_MS_STATE[i]));
   // Location in the current leg: selling the bottom fifth / buying the top fifth.
   if(dir < 0 && G_LB_POS <= 0.20)
      c += StringFormat(" SELL at leg bottom (pos %.2f);", G_LB_POS);
   if(dir > 0 && G_LB_POS >= 0.80)
      c += StringFormat(" BUY at leg top (pos %.2f);", G_LB_POS);
   if(G_SITUATION != SIT_NONE && G_SITUATION_DIR != 0 && G_SITUATION_DIR == -dir)
      c += StringFormat(" situation %s favours %s;", SituationName(G_SITUATION), RCDirText(G_SITUATION_DIR));
   if(EnableEconomicCalendarGuard && G_CAL_ACTIVE)
      c += StringFormat(" news window %s;", G_CAL_EVENT_NAME);
   // Market Brain facts that point the other way (M5 and above, still relevant).
   if(EnableMarketBrainEngines)
   {
      int against[5] = {MB_EV_LIQ_SWEEP, MB_EV_FAKE_BREAK, MB_EV_MSS, MB_EV_ACCEPTANCE, MB_EV_RECLAIM};
      for(int i = 0; i < 5; i++)
      {
         SMBEvent ev;
         if(MBEventFind(against[i], -dir, 1, ev))
            c += StringFormat(" %s %s %s @ %s (%d bars);", MBTFName(ev.tfi), MBEventName(ev.type),
                              (ev.dir > 0 ? "bull" : "bear"), DoubleToString(ev.level, _Digits), MBEventAgeBars(ev));
      }
      int m1_imp = G_MB_IMP_DIR[0];
      if(m1_imp == dir && G_MB_SPEED[0] >= MB_SPEED_LATE)
         c += StringFormat(" chasing: M1 impulse %s %.1f ATR;", MBSpeedName(G_MB_SPEED[0]), G_MB_IMP_TRAVEL[0]);
      if(G_MB_LIVE_DIR == -dir)
         c += " live M1 candle displacing against;";
   }
   if(StringLen(c) == 0)
      return "none";
   return StringSubstr(c, 1);
}

void RCZones(const double price, double &sup, double &sup_str, double &res, double &res_str)
{
   sup = ZoneMapNearestSupport(price);
   res = ZoneMapNearestResistance(price);
   sup_str = (sup > 0.0) ? ZoneMapStrength(sup) : 0.0;
   res_str = (res > 0.0) ? ZoneMapStrength(res) : 0.0;
}

void RCWriteCsv(const string kind, const int dir, const double lot, const double price, const ulong ticket,
                const double sup, const double res, const string conflicts, const string extra)
{
   if(!ReasonCodeToFile)
      return;

   string name = StringFormat("Sirus_ReasonCode_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[SIRUS REASON] cannot open %s (error %d)", name, GetLastError());
      return;
   }
   if(FileSize(h) == 0)
      FileWriteString(h, "seq;time;kind;dir;lot;price;ticket;signal;score;min_score;decision;market;regime;"
                         "chain;htf_chain;event;verdict;ms_m1;ms_m5;ms_m15;leg_pos;leg_stretch;"
                         "support;resistance;news;conflicts;signal_reason;extra;candle;events;brain\r\n");
   FileSeek(h, 0, SEEK_END);

   string row = StringFormat("%d;%s;%s;%s;%.2f;%s;%I64u;%s;%d;%d;%s;%s;%s;%d;%d;%s;%d;%d/%s;%d/%s;%d/%s;%.2f;%.1f;%s;%s;%s;%s;%s;%s;%s;%s;%s\r\n",
                             G_RC_SEQ,
                             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                             kind,
                             (dir > 0 ? "BUY" : "SELL"),
                             lot,
                             DoubleToString(price, _Digits),
                             ticket,
                             OpportunityTypeToString(G_OPP_TYPE),
                             G_SCORE_FINAL,
                             G_SCORE_MIN_REQUIRED,
                             ScoreDecisionToString(G_SCORE_DECISION),
                             MarketStateToString(G_MARKET_STATE),
                             RegimeName(G_REGIME),
                             G_STRUCTURE_DIR,
                             G_STRUCTURE_HTF_DIR,
                             RCCsvSafe(G_STRUCTURE_EVENT_TXT),
                             G_VERDICT_DIR,
                             G_MS_DIR[0], RCMSStateName(G_MS_STATE[0]),
                             G_MS_DIR[1], RCMSStateName(G_MS_STATE[1]),
                             G_MS_DIR[2], RCMSStateName(G_MS_STATE[2]),
                             G_LB_POS,
                             G_LB_STRETCH,
                             (sup > 0.0 ? DoubleToString(sup, _Digits) : ""),
                             (res > 0.0 ? DoubleToString(res, _Digits) : ""),
                             (G_CAL_ACTIVE ? RCCsvSafe(G_CAL_EVENT_NAME) : ""),
                             RCCsvSafe(conflicts),
                             RCCsvSafe(G_OPP_REASON),
                             RCCsvSafe(extra),
                             RCCsvSafe(MBCandleText()),
                             RCCsvSafe(MBEventText(8)),
                             RCCsvSafe(MBBrainText()));
   FileWriteString(h, row);
   FileClose(h);
}

// The lines every kind of entry shares: market, structure, zones, location, news.
void RCPrintContext(const int dir, const double price, double &sup, double &res, string &conflicts)
{
   double sup_str = 0.0, res_str = 0.0;
   RCZones(price, sup, sup_str, res, res_str);

   PrintFormat("   MARKET   : state=%s | regime=%s | mode=%s | situation=%s",
               MarketStateToString(G_MARKET_STATE), RegimeName(G_REGIME),
               ModeToShortString(G_ACTIVE_MODE), SituationName(G_SITUATION));
   PrintFormat("   STRUCTURE: chain %s (%d/4) %s | HTF %s (%d) | %s | verdict %s (%d/%d)",
               RCDirText(G_STRUCTURE_DIR), G_STRUCTURE_STEPS,
               (StringLen(G_STRUCTURE_EVENT_TXT) > 0 ? "[" + G_STRUCTURE_EVENT_TXT + "]" : ""),
               RCDirText(G_STRUCTURE_HTF_DIR), G_STRUCTURE_HTF_STEPS,
               G_STRUCTURE_CONTEXT_TXT,
               RCDirText(G_VERDICT_DIR), G_VERDICT_AGREE, G_VERDICT_ACTIVE);
   PrintFormat("   TF STATE : M1 %s/%s | M5 %s/%s | M15 %s/%s | local %s | reversal-ctx %s",
               RCDirText(G_MS_DIR[0]), RCMSStateName(G_MS_STATE[0]),
               RCDirText(G_MS_DIR[1]), RCMSStateName(G_MS_STATE[1]),
               RCDirText(G_MS_DIR[2]), RCMSStateName(G_MS_STATE[2]),
               LocalStructureName(G_LS_STATE),
               (StringLen(G_REVCTX_TEXT) > 0 ? G_REVCTX_TEXT : "none"));
   PrintFormat("   ZONES    : support %s (str %.1f, %.0f pts below) | resistance %s (str %.1f, %.0f pts above)",
               (sup > 0.0 ? DoubleToString(sup, _Digits) : "-"), sup_str,
               (sup > 0.0 ? (price - sup) / _Point : 0.0),
               (res > 0.0 ? DoubleToString(res, _Digits) : "-"), res_str,
               (res > 0.0 ? (res - price) / _Point : 0.0));
   PrintFormat("   LOCATION : leg %s pos %.2f (0=low 1=high) | stretch %.1f ATR | %d bars | %s",
               RCDirText(G_LB_DIR), G_LB_POS, G_LB_STRETCH, G_LB_BARS, RCShort(G_LB_TEXT, 160));
   PrintFormat("   NEWS     : %s",
               (EnableEconomicCalendarGuard && G_CAL_ACTIVE)
                  ? StringFormat("%s (%d min)%s", G_CAL_EVENT_NAME, G_CAL_MINUTES_FROM_EVENT, (G_CAL_BIG_SURPRISE ? " surprise" : ""))
                  : "clear");

   if(EnableZoneRoleEngine)
   {
      SMBZone zs, zr;
      string vs = "", vr = "";
      bool hs = (sup > 0.0 && MBZoneRead(sup, zs));
      bool hr = (res > 0.0 && MBZoneRead(res, zr));
      PrintFormat("   ZONE BELOW: %s", (hs ? MBZoneText(zs) : "-"));
      PrintFormat("   ZONE ABOVE: %s", (hr ? MBZoneText(zr) : "-"));
      // The zone this entry leans on: a SELL leans on the zone above (or the one it sits in),
      // a BUY on the zone below. Preview of the phase 4 veto.
      double lean = (dir < 0) ? res : sup;
      if(lean > 0.0)
      {
         int verdict = MBZoneEntryVerdict(dir, lean, vs);
         PrintFormat("   ZONE ROLE: %s -> %s", vs, (verdict > 0 ? "OK" : (verdict == 0 ? "WAIT" : "AGAINST")));
      }
      // And the zone on the other side: selling right on top of a support that still holds.
      double other = (dir < 0) ? sup : res;
      if(other > 0.0 && MathAbs(price - other) <= 1.0 * G_MB_ATR[1] * _Point)
      {
         SMBZone zo;
         if(MBZoneRead(other, zo) && ((dir < 0 && zo.role > 0) || (dir > 0 && zo.role < 0)))
            PrintFormat("   ZONE ROLE: entering right on a %s that holds (%s)", MBZoneRoleName(zo.role), MBZoneStateName(zo.state));
      }
   }
   PrintFormat("   BRAIN    : %s", MBBrainText());
   PrintFormat("   CANDLE   : %s", MBCandleText());
   PrintFormat("   EVENTS   : %s", MBEventText(8));

   conflicts = RCConflicts(dir);
   PrintFormat("   CONFLICTS: %s", conflicts);
}

// First entry and scale-in.
void ReasonCodeEntry(const string kind, const ENUM_ORDER_TYPE type, const double lot, const double fill_price, const ulong ticket)
{
   if(!EnableReasonCode)
      return;

   G_RC_SEQ++;
   int dir = (type == ORDER_TYPE_BUY) ? 1 : -1;
   double price = (fill_price > 0.0) ? fill_price
                                     : SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));

   PrintFormat("[SIRUS REASON #%d] %s %s %.2f @ %s | %s | ticket %I64u | spread %d | ATR M1 %.0f / M5 %.0f pts",
               G_RC_SEQ, kind, (dir > 0 ? "BUY" : "SELL"), lot, DoubleToString(price, _Digits),
               TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), ticket, GetSpreadPoints(),
               ATRPointsManual(PERIOD_M1, 14, 1), ATRPointsManual(PERIOD_M5, 14, 1));
   PrintFormat("   SIGNAL   : %s | score %d (min %d) %s%s | voices BUY %d / SELL %d, clarity %.2f",
               OpportunityTypeToString(G_OPP_TYPE), G_SCORE_FINAL, G_SCORE_MIN_REQUIRED,
               ScoreDecisionToString(G_SCORE_DECISION), (G_SCORE_IS_MICRO ? " micro" : ""),
               G_OPP_VOICES_BUY, G_OPP_VOICES_SELL, G_OPP_DIR_CLARITY);
   PrintFormat("   WHY      : %s", RCShort(G_OPP_REASON, 400));
   PrintFormat("   SCORE    : base %d +bonus %d -penalty %d | candle +%d/-%d | hard-block %s | %s",
               G_SCORE_BASE, G_SCORE_BONUS, G_SCORE_PENALTY, G_CANDLE_BONUS, G_CANDLE_PENALTY,
               G_SCORE_HARD_BLOCK, RCShort(G_SCORE_DETAIL, 300));

   double sup = 0.0, res = 0.0;
   string conflicts = "";
   RCPrintContext(dir, price, sup, res, conflicts);
   PrintFormat("   LOT      : %s", (StringLen(G_LOT_TRACE) > 0 ? RCShort(G_LOT_TRACE, 300) : "-"));

   RCWriteCsv(kind, dir, lot, price, ticket, sup, res, conflicts, G_LOT_TRACE);
}

// Grid addition.
void ReasonCodeGrid(const ENUM_ORDER_TYPE type, const double lot, const double fill_price, const ulong ticket, const int orders_before)
{
   if(!EnableReasonCode)
      return;

   G_RC_SEQ++;
   int dir = (type == ORDER_TYPE_BUY) ? 1 : -1;
   double price = (fill_price > 0.0) ? fill_price
                                     : SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID));

   PrintFormat("[SIRUS REASON #%d] GRID %s %.2f @ %s | %s | ticket %I64u | rung %d -> %d",
               G_RC_SEQ, (dir > 0 ? "BUY" : "SELL"), lot, DoubleToString(price, _Digits),
               TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), ticket, orders_before, orders_before + 1);
   string extra = StringFormat("avg %s DD %.2f%% distance %.0f soft-lot x%.2f%s",
                               DoubleToString(G_BASKET_AVG_PRICE, _Digits), G_BASKET_DD_PERCENT,
                               G_NEXT_GRID_DISTANCE, G_GRID_LOT_SOFT_FACTOR,
                               (G_GRID_LOT_CAUTION_FLOORED ? " (floored)" : ""));
   PrintFormat("   BASKET   : %s | profit %.2f | %s", extra, G_BASKET_PROFIT, RCShort(G_GRID_DETAIL, 200));

   double sup = 0.0, res = 0.0;
   string conflicts = "";
   RCPrintContext(dir, price, sup, res, conflicts);

   RCWriteCsv("GRID", dir, lot, price, ticket, sup, res, conflicts, extra);
}
