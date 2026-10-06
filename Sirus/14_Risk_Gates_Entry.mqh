//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 14_Risk_Gates_Entry                             |
//| Risk governor, gates, first entry engine                         |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  PHASE 21.3 RISK ENGINE
//==================================================================//
datetime RiskDateStamp(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

void ResetDailyRiskIfNeeded()
{
   datetime now_stamp = RiskDateStamp(TimeCurrent());
   if(now_stamp <= 0)
      now_stamp = RiskDateStamp(TimeLocal());

   if(G_RISK_DAY_STAMP <= 0 || now_stamp != G_RISK_DAY_STAMP)
   {
      G_RISK_DAY_STAMP = now_stamp;
      G_RISK_DAY_START_BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
      G_RISK_DAY_START_EQUITY  = AccountInfoDouble(ACCOUNT_EQUITY);
      G_RISK_DAILY_LOSS_MONEY = 0.0;
      G_RISK_DAILY_LOSS_PCT = 0.0;

      // FIX(daily-attempts-reset): MaxDailyEntryAttempts is a DAILY limit, but nothing ever reset
      // its counter on a day boundary - the only thing that cleared it was ResetOpportunity(), and
      // that was a bug in the opposite direction (it cleared on every quiet tick, so the limit
      // could never be reached). With that wipe correctly removed, the counter would otherwise
      // accumulate across days and eventually block trading until the EA was restarted. Reset it
      // with the rest of the daily risk state, which is where a daily counter belongs.
      G_ENTRY_ATTEMPTS = 0;
      G_ENTRY_SUCCESSES = 0;
      G_ENTRY_FAILS = 0;

      PrintFormat("[SIRUS v31.6 PHASE 21.3 RISK] New risk day | stamp=%s | startBalance=%.2f | startEquity=%.2f",
                  SafeTime(G_RISK_DAY_STAMP),
                  G_RISK_DAY_START_BALANCE,
                  G_RISK_DAY_START_EQUITY);
   }
}

// --- V29 ported: Daily Profit Governor (target lock + trail lock) ---
// Reuses G_RISK_DAY_START_EQUITY / ResetDailyRiskIfNeeded() from v24 risk engine.
void UpdateDailyProfitGovernor()
{
   if(!EnableDailyProfitGovernor)
   {
      G_DPG_TARGET_LOCKED = false;
      G_DPG_TRAIL_LOCKED  = false;
      return;
   }

   // Reset peak/lock state on new risk day (G_RISK_DAY_STAMP already rolls daily).
   if(G_DPG_DAY_STAMP != G_RISK_DAY_STAMP)
   {
      G_DPG_DAY_STAMP      = G_RISK_DAY_STAMP;
      G_DPG_PEAK_EQUITY    = 0.0;
      G_DPG_TARGET_LOCKED  = false;
      G_DPG_TRAIL_LOCKED   = false;
      G_DPG_TARGET_PRINTED = false;
      G_DPG_TRAIL_PRINTED  = false;
   }

   double base = G_RISK_DAY_START_EQUITY;
   if(base <= 0.0)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit_pct = (equity - base) / base * 100.0;

   if(equity > G_DPG_PEAK_EQUITY)
      G_DPG_PEAK_EQUITY = equity;

   if(DailyProfitTargetPercent > 0.0 && profit_pct >= DailyProfitTargetPercent && !G_DPG_TARGET_LOCKED)
   {
      G_DPG_TARGET_LOCKED = true;
      if(DailyProfitPrintOnLock && !G_DPG_TARGET_PRINTED)
      {
         PrintFormat("[SIRUS v29 DAILY PROFIT] Target reached %.2f/%.2f%% - new entries locked for today",
                     profit_pct, DailyProfitTargetPercent);
         G_DPG_TARGET_PRINTED = true;
      }
   }

   if(EnableDailyProfitTrailLock && DailyProfitTrailStartPercent > 0.0 && G_DPG_PEAK_EQUITY > base)
   {
      double peak_pct = (G_DPG_PEAK_EQUITY - base) / base * 100.0;
      if(peak_pct >= DailyProfitTrailStartPercent)
      {
         double giveback_pct = (G_DPG_PEAK_EQUITY - equity) / (G_DPG_PEAK_EQUITY - base) * 100.0;
         if(giveback_pct >= DailyProfitTrailGivebackPercent && !G_DPG_TRAIL_LOCKED)
         {
            G_DPG_TRAIL_LOCKED = true;
            if(DailyProfitPrintOnLock && !G_DPG_TRAIL_PRINTED)
            {
               PrintFormat("[SIRUS v29 DAILY PROFIT] Trail giveback %.2f%% from peak %.2f%% - new entries locked for today",
                           giveback_pct, peak_pct);
               G_DPG_TRAIL_PRINTED = true;
            }
         }
      }
   }
}

bool DailyProfitGovernorAllowsEntry(string &reason)
{
   if(!EnableDailyProfitGovernor)
   {
      reason = "daily profit governor disabled";
      return true;
   }
   if(G_DPG_TARGET_LOCKED && DailyProfitBlockNewEntriesAtTarget)
   {
      reason = "daily profit target reached, new entries locked";
      return false;
   }
   if(G_DPG_TRAIL_LOCKED && DailyProfitBlockNewEntriesOnTrail)
   {
      reason = "daily profit trail giveback lock, new entries locked";
      return false;
   }
   reason = "daily profit governor pass";
   return true;
}

bool DailyProfitGovernorAllowsRecovery(string &reason)
{
   if(!EnableDailyProfitGovernor)
   {
      reason = "daily profit governor disabled";
      return true;
   }
   if(G_DPG_TARGET_LOCKED && DailyProfitBlockRecoveryAtTarget)
   {
      reason = "daily profit target reached, recovery locked";
      return false;
   }
   if(G_DPG_TRAIL_LOCKED && DailyProfitBlockRecoveryOnTrail)
   {
      reason = "daily profit trail giveback lock, recovery locked";
      return false;
   }
   reason = "daily profit governor pass";
   return true;
}

// --- V29 ported: Operator Control (manual pause) ---
bool OperatorControlAllowsEntry(string &reason)
{
   if(OperatorPauseAllNewOrders)
   {
      reason = "operator paused all new orders";
      return false;
   }
   if(OperatorPauseFirstEntries)
   {
      reason = "operator paused first entries";
      return false;
   }
   reason = "operator control pass";
   return true;
}

bool OperatorControlAllowsRecovery(string &reason)
{
   if(OperatorPauseAllNewOrders)
   {
      reason = "operator paused all new orders";
      return false;
   }
   if(OperatorPauseRecoveryGrid)
   {
      reason = "operator paused recovery/grid";
      return false;
   }
   reason = "operator control pass";
   return true;
}

// --- V29 ported: Settings Sanity Governor ---
bool SettingsSanityAllowsEntry(string &reason)
{
   if(!EnableSettingsSanityGovernor)
   {
      reason = "settings sanity disabled";
      return true;
   }

   string issue = "";
   bool critical = false;

   if(GridDistancePoints < SettingsSanityMinGridPoints)
   {
      issue = StringFormat("GridDistancePoints %d below safe minimum %d", GridDistancePoints, SettingsSanityMinGridPoints);
      critical = true;
   }
   else if(UseIndividualTPForFirstEntry && FirstEntryTPMinPoints < SettingsSanityMinTPPoints)
   {
      issue = StringFormat("FirstEntryTPMinPoints %d below safe minimum %d", FirstEntryTPMinPoints, SettingsSanityMinTPPoints);
      critical = true;
   }

   string state = (critical ? "CRITICAL:" + issue : "OK");
   if(SettingsSanityPrintOnChange && state != G_SANITY_LAST_STATE)
   {
      PrintFormat("[SIRUS v29 SETTINGS SANITY] %s", state);
      G_SANITY_LAST_STATE = state;
   }

   if(critical && SettingsSanityBlockLiveOnCritical)
   {
      reason = "settings sanity: " + issue;
      return false;
   }

   reason = "settings sanity pass";
   return true;
}

// --- V29 ported: License / Account Guard ---
bool LicenseAccountInList(const long login, const string allowed)
{
   if(StringLen(allowed) == 0)
      return true;

   string parts[];
   int n = StringSplit(allowed, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string trimmed = parts[i];
      StringTrimLeft(trimmed);
      StringTrimRight(trimmed);
      if(trimmed == IntegerToString(login))
         return true;
   }
   return false;
}

bool LicenseGuardAllowsEntry(string &reason)
{
   if(!EnableLicenseAccountGuard)
   {
      reason = "license guard disabled";
      return true;
   }

   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   bool account_ok = LicenseAccountInList(login, LicenseAllowedAccounts);

   bool expiry_ok = true;
   if(StringLen(LicenseExpiryDate) > 0)
   {
      datetime expiry = StringToTime(LicenseExpiryDate);
      if(expiry > 0 && TimeCurrent() > expiry)
         expiry_ok = false;
   }

   bool valid = (account_ok && expiry_ok);
   string state = StringFormat("client=%s account=%s expiry=%s valid=%s",
                                LicenseClientName, YesNoV29(account_ok), YesNoV29(expiry_ok), YesNoV29(valid));

   if(state != G_LICENSE_LAST_STATE)
   {
      PrintFormat("[SIRUS v29 LICENSE] %s", state);
      G_LICENSE_LAST_STATE = state;
   }

   if(!valid && LicenseGuardBlockLiveInvalid)
   {
      reason = StringFormat("license guard invalid | account_ok=%s expiry_ok=%s", YesNoV29(account_ok), YesNoV29(expiry_ok));
      return false;
   }

   reason = "license guard pass";
   return true;
}

// --- V29 ported: Setup Doctor ---
bool SetupDoctorAllowsEntry(string &reason)
{
   if(!EnableSetupDoctor)
   {
      reason = "setup doctor disabled";
      return true;
   }

   bool terminal_ok  = TerminalInfoInteger(TERMINAL_CONNECTED) != 0;
   bool algo_ok      = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0;
   bool account_ok   = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0;
   bool mql_ok       = MQLInfoInteger(MQL_TRADE_ALLOWED) != 0;
   long trade_mode   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   bool symbol_ok    = (trade_mode == SYMBOL_TRADE_MODE_FULL);

   bool all_ok = terminal_ok && account_ok && mql_ok && symbol_ok;
   if(SetupDoctorRequireTradeAllowed)
      all_ok = all_ok && algo_ok;

   string state = StringFormat("terminal=%s algo=%s account=%s mql=%s symbol=%s",
                                YesNoV29(terminal_ok), YesNoV29(algo_ok), YesNoV29(account_ok),
                                YesNoV29(mql_ok), YesNoV29(symbol_ok));

   if(SetupDoctorPrintOnChange && state != G_SETUPDOC_LAST_STATE)
   {
      PrintFormat("[SIRUS v29 SETUP DOCTOR] %s", state);
      G_SETUPDOC_LAST_STATE = state;
   }

   if(!all_ok && SetupDoctorBlockLiveInvalid)
   {
      reason = "setup doctor: " + state;
      return false;
   }

   reason = "setup doctor pass";
   return true;
}

void UpdateDailyLossStats()
{
   ResetDailyRiskIfNeeded();
   UpdateDailyProfitGovernor();

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double base = G_RISK_DAY_START_EQUITY;

   if(base <= 0.0)
      base = AccountInfoDouble(ACCOUNT_BALANCE);

   G_RISK_DAILY_LOSS_MONEY = MathMax(0.0, base - equity);

   if(base > 0.0)
      G_RISK_DAILY_LOSS_PCT = G_RISK_DAILY_LOSS_MONEY / base * 100.0;
   else
      G_RISK_DAILY_LOSS_PCT = 0.0;

   G_RISK_EQUITY_DD_PCT = AccountDDPercentApprox();

   // V29 fix: track the real worst DD ever seen (was previously mislabeled on the dashboard).
   // V31.6b: persist on each new record - a restart can no longer wipe the statistic.
   if(G_RISK_EQUITY_DD_PCT > G_ALL_TIME_MAX_DD_PCT)
   {
      G_ALL_TIME_MAX_DD_PCT = G_RISK_EQUITY_DD_PCT;
      if(EnablePersistentState)
         GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_MAXDD", MagicNumber, _Symbol), G_ALL_TIME_MAX_DD_PCT);
   }
   if(G_RISK_DAILY_LOSS_PCT > G_ALL_TIME_MAX_DAILY_DD_PCT)
   {
      G_ALL_TIME_MAX_DAILY_DD_PCT = G_RISK_DAILY_LOSS_PCT;
      if(EnablePersistentState)
         GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_MAXDDD", MagicNumber, _Symbol), G_ALL_TIME_MAX_DAILY_DD_PCT);
   }
}

// BOSQICH 1: bitta qoida - haqiqiy zarar nima. Foyda va 0.0 - zarar emas. Balansning
// TrivialLossPctOfBalance %idan kichik minus (tez bozordagi slippage, break-even chiqish) ham zarar emas.
bool IsMeaningfulLoss(const double profit)
{
   if(profit >= 0.0)
      return false;
   if(TrivialLossPctOfBalance <= 0.0)
      return true;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0)
      return true;
   return ((-profit / bal) * 100.0 > TrivialLossPctOfBalance);
}

bool IsPostLossCooldownActive()
{
   if(!UsePostLossCooldown)
      return false;

   return (G_POST_LOSS_COOLDOWN_UNTIL > TimeCurrent());
}

void UpdatePostLossCooldown()
{
   if(!UsePostLossCooldown)
      return;

   // Detect basket disappearing after being in floating loss.
   if(G_PREV_BASKET_ORDERS > 0 && G_BASKET_ORDERS == 0)
   {
      if(IsMeaningfulLoss(G_PREV_BASKET_PROFIT))   // BOSQICH 1
      {
         G_POST_LOSS_COOLDOWN_UNTIL = TimeCurrent() + PostLossCooldownMinutes * 60;
         PostLossCooldownSave(); // V30.2: survive restart
         PrintFormat("[SIRUS v31.6 PHASE 21.3 RISK] Post-loss cooldown started until %s | lastBasketProfit=%.2f",
                     SafeTime(G_POST_LOSS_COOLDOWN_UNTIL),
                     G_PREV_BASKET_PROFIT);
      }
   }

   G_PREV_BASKET_ORDERS = G_BASKET_ORDERS;
   G_PREV_BASKET_PROFIT = G_BASKET_PROFIT;
}

bool RiskCloseBasketIfNeeded(const string reason)
{
   if(G_BASKET_ORDERS <= 0)
      return false;

   bool ok = CloseNaviusBasket("RISK: " + reason);
   if(ok)
      G_RISK_CLOSE_COUNT++;

   return ok;
}

bool RiskHardBlockCheck(string &reason, bool &close_request)
{
   close_request = false;
   reason = "none";

   if(!UseRiskEngine)
   {
      reason = "Risk engine disabled";
      return false;
   }

   // FIX(loss-tiers-masked-by-spread): the ENV-not-ready and wide-spread gates used to sit ABOVE
   // the loss tiers. Both `return true` with close_request left FALSE, and UpdateRiskEngine() only
   // acts on that flag - so on every tick where the spread was wide, the emergency / equity-stop /
   // daily-loss closes were silently skipped. EffSpread() resolves to UnifiedMaxSpreadPoints (500 =
   // $0.50), which XAUUSD exceeds routinely on news and at session open: i.e. the account-level
   // stops went dead in exactly the conditions they exist for. They are also the ONLY tiers that
   // can see loss on other symbols - the basket SL and the emergency force-close both sum this
   // symbol+magic only. The loss tiers are decisions about capital and must be evaluated first;
   // the tradability gates below only decide whether to keep TRADING.
   if(UseEmergencyClose && EmergencyDDPercent > 0.0 && G_RISK_EQUITY_DD_PCT >= EmergencyDDPercent)
   {
      reason = StringFormat("EMERGENCY DD %.2f/%.2f%%", G_RISK_EQUITY_DD_PCT, EmergencyDDPercent);
      close_request = true;
      return true;
   }

   // NOTE: with the shipped defaults EquityStopPercent and EmergencyDDPercent are both 50.0, so the
   // emergency tier above wins and this one never fires. That is the safe way round (emergency
   // always closes, this one only closes if CloseBasketOnEquityStop is true), but it does mean
   // EquityStopPercent has no effect unless you set it BELOW EmergencyDDPercent.
   if(UseEquityStop && EquityStopPercent > 0.0 && G_RISK_EQUITY_DD_PCT >= EquityStopPercent)
   {
      reason = StringFormat("Equity stop DD %.2f/%.2f%%", G_RISK_EQUITY_DD_PCT, EquityStopPercent);
      close_request = CloseBasketOnEquityStop;
      return true;
   }

   if(UseDailyLossLimit)
   {
      if(DailyLossPercent > 0.0 && G_RISK_DAILY_LOSS_PCT >= DailyLossPercent)
      {
         reason = StringFormat("Daily loss %.2f/%.2f%%", G_RISK_DAILY_LOSS_PCT, DailyLossPercent);
         close_request = CloseBasketOnDailyLoss;
         return true;
      }

      if(DailyLossMoney > 0.0 && G_RISK_DAILY_LOSS_MONEY >= DailyLossMoney)
      {
         reason = StringFormat("Daily loss money %.2f/%.2f", G_RISK_DAILY_LOSS_MONEY, DailyLossMoney);
         close_request = CloseBasketOnDailyLoss;
         return true;
      }
   }

   // --- tradability gates: these stop new trading, they never decide about capital -------------
   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return true;
   }

   if(G_LAST_SPREAD_POINTS >= EffSpread(RiskMaxSpreadPoints))
   {
      reason = StringFormat("risk spread high %d/%d", G_LAST_SPREAD_POINTS, EffSpread(RiskMaxSpreadPoints));
      return true;
   }

   if(IsPostLossCooldownActive())
   {
      reason = "post-loss cooldown until " + SafeTime(G_POST_LOSS_COOLDOWN_UNTIL);
      return true;
   }

   if(MaxDailyEntryAttempts > 0 && G_ENTRY_ATTEMPTS >= MaxDailyEntryAttempts)
   {
      reason = StringFormat("max daily entry attempts %d/%d", G_ENTRY_ATTEMPTS, MaxDailyEntryAttempts);
      return true;
   }

   if(MaxDailyGridAttempts > 0 && G_GRID_ATTEMPTS >= MaxDailyGridAttempts)
   {
      reason = StringFormat("max daily grid attempts %d/%d", G_GRID_ATTEMPTS, MaxDailyGridAttempts);
      return true;
   }

   return false;
}

void UpdateRiskEngine(const string source)
{
   if(!UseRiskEngine)
   {
      G_RISK_READY = true;
      G_RISK_HARD_BLOCK = false;
      G_RISK_CLOSE_REQUEST = false;
      G_RISK_STATUS = "RISK: OFF";
      G_RISK_REASON = "UseRiskEngine=false";
      G_RISK_DETAIL = "RISK DETAIL: disabled";
      return;
   }

   UpdateDailyLossStats();
   RefreshGridDashboardStats();

   bool close_req = false;
   string reason = "";
   bool hard_block = RiskHardBlockCheck(reason, close_req);

   G_RISK_HARD_BLOCK = hard_block;
   G_RISK_CLOSE_REQUEST = close_req;
   G_RISK_READY = !hard_block;
   G_RISK_REASON = reason;

   if(close_req)
      RiskCloseBasketIfNeeded(reason);

   RefreshGridDashboardStats();
   UpdatePostLossCooldown();
   UpdateSelfDefense();     // V31: cooldown o'chiq bo'lsa ham mustaqil ishlaydi

   if(G_RISK_HARD_BLOCK)
   {
      G_RISK_STATUS = "RISK BLOCK: " + G_RISK_REASON;
      G_RISK_BLOCK_COUNT++;
   }
   else
   {
      G_RISK_STATUS = "RISK READY";
   }

   G_RISK_DETAIL = StringFormat("RISK DETAIL: dailyLoss=%.2f/%.2f%% | equityDD=%.2f%% | basketOrders=%d profit=%.2f | closeReq=%s | blocks=%d closes=%d",
                                G_RISK_DAILY_LOSS_MONEY,
                                G_RISK_DAILY_LOSS_PCT,
                                G_RISK_EQUITY_DD_PCT,
                                G_BASKET_ORDERS,
                                G_BASKET_PROFIT,
                                BoolText(G_RISK_CLOSE_REQUEST),
                                G_RISK_BLOCK_COUNT,
                                G_RISK_CLOSE_COUNT);

   string signature = G_RISK_STATUS + "|" + G_RISK_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(signature != G_RISK_LAST_SIGNATURE)
   {
      if(G_RISK_HARD_BLOCK || G_RISK_LAST_SIGNATURE == "")
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 RISK] %s | %s | source=%s",
                     G_RISK_STATUS,
                     G_RISK_DETAIL,
                     source);
      }
      G_RISK_LAST_SIGNATURE = signature;
   }
}

bool RiskAllowsNewEntry(string &reason)
{
   if(!UseRiskEngine || !RiskBlockNewEntry)
   {
      reason = "risk entry pass";
      return true;
   }

   if(G_RISK_HARD_BLOCK)
   {
      reason = G_RISK_STATUS;
      return false;
   }

   reason = "risk entry pass";
   return true;
}

bool RiskAllowsGrid(string &reason)
{
   if(!UseRiskEngine || !RiskBlockGrid)
   {
      reason = "risk grid pass";
      return true;
   }

   if(G_RISK_HARD_BLOCK)
   {
      reason = G_RISK_STATUS;
      return false;
   }

   reason = "risk grid pass";
   return true;
}

//==================================================================//
//  PHASE 21.3 FIRST ENTRY ENGINE
//==================================================================//
// --- V30 new: MARGIN GUARD ---
// Checks BEFORE sending an order that the account can actually afford it.
// Old behaviour: order was sent blindly and the broker rejected it with
// TRADE_RETCODE_NO_MONEY. Now we block early with a clear reason (no silent block).
// ============================================================================
// V114: MARGIN RESCUE LOT - don't just freeze when the full grid lot won't fit.
// ----------------------------------------------------------------------------
// Live case from the user: on a $50 account with StartLot 0.2 the basket went
// into a $6 drawdown and the grid simply stopped - the next order's margin would
// have pushed the basket past MaxBasketMarginPercent, so it was refused. On a
// $100 account with StartLot 0.3 (a SMALLER lot-to-balance ratio) the same setup
// added its grid order, averaged down and closed in profit.
//
// The dangerous part is the feedback loop: drawdown lowers equity, which raises
// the basket's margin percentage, which blocks the grid - exactly when the grid
// is most needed. The basket then sits frozen until the SL takes it.
//
// So instead of refusing outright, find the LARGEST lot that does fit. A smaller
// addition still pulls the average toward price and still lets the basket close
// on a bounce. But it is only worth doing if the lot is still meaningful: a token
// 0.01 addition takes fresh risk while barely moving the break-even, so anything
// below GridMarginRescueMinFactor of the intended lot is refused and the block
// stands - with a clear reason in the log either way.
// Returns the usable lot, or 0.0 if nothing meaningful fits.
// ============================================================================
double MarginRescueGridLot(const ENUM_ORDER_TYPE order_type, const double intended_lot, string &detail)
{
   detail = "";
   if(!EnableGridMarginRescue || intended_lot <= 0.0)
      return 0.0;

   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double floor_lot = intended_lot * MathMax(0.05, MathMin(1.0, GridMarginRescueMinFactor));

   // Step down in 10% increments and take the first size that clears BOTH margin checks.
   for(int step = 9; step >= 1; step--)
   {
      double test_lot = NormalizeVolumeSafe(intended_lot * (double)step / 10.0);

      if(test_lot < vmin || test_lot < floor_lot || test_lot >= intended_lot)
         continue;

      string m_reason = "", e_reason = "";
      if(MarginAllowsOrder(order_type, test_lot, m_reason) &&
         BasketExposureAllowsGrid(test_lot, order_type, e_reason))
      {
         detail = StringFormat("margin rescue: %.2f -> %.2f lot (%.0f%% of intended)",
                               intended_lot, test_lot, (test_lot / intended_lot) * 100.0);
         return test_lot;
      }
   }

   detail = StringFormat("margin rescue: nothing >= %.2f lot fits (intended %.2f)", floor_lot, intended_lot);
   return 0.0;
}

bool MarginAllowsOrder(const ENUM_ORDER_TYPE order_type, const double lot, string &reason)
{
   if(!EnableMarginGuard)
   {
      reason = "margin guard disabled";
      return true;
   }

   if(lot <= 0.0)
   {
      reason = "margin guard: lot<=0";
      return false;
   }

   double price = 0.0;
   if(order_type == ORDER_TYPE_BUY)
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, price);
   else
      SymbolInfoDouble(_Symbol, SYMBOL_BID, price);

   if(price <= 0.0)
   {
      reason = "margin guard: price unreadable";
      return false;
   }

   double need_margin = 0.0;
   if(!OrderCalcMargin(order_type, _Symbol, lot, price, need_margin))
   {
      reason = StringFormat("margin guard: OrderCalcMargin failed err=%d", GetLastError());
      return false;
   }

   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double used_margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(need_margin > free_margin)
   {
      reason = StringFormat("margin guard: need=%.2f > free=%.2f", need_margin, free_margin);
      if((MarginGuardPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v30 MARGIN GUARD] BLOCK | %s | lot=%.2f", reason, lot);
      return false;
   }

   double projected_used = used_margin + need_margin;
   if(MarginGuardMinLevelPct > 0.0 && projected_used > 0.0)
   {
      double projected_level = equity / projected_used * 100.0;
      if(projected_level < MarginGuardMinLevelPct)
      {
         reason = StringFormat("margin guard: projected level %.0f%% < min %.0f%%",
                               projected_level, MarginGuardMinLevelPct);
         if((MarginGuardPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v30 MARGIN GUARD] BLOCK | %s | lot=%.2f need=%.2f", reason, lot, need_margin);
         return false;
      }
   }

   reason = "margin ok";
   return true;
}

double NormalizeVolumeSafe(double volume)
{
   double vmin = 0.0, vmax = 0.0, vstep = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, vmin);
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, vmax);
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, vstep);

   if(vmin <= 0.0 || vmax <= 0.0 || vstep <= 0.0)
      return volume;

   if(volume < vmin)
      volume = vmin;

   if(volume > vmax)
      volume = vmax;

   double steps = MathFloor((volume - vmin) / vstep + 0.5);
   double normalized = vmin + steps * vstep;

   if(normalized < vmin)
      normalized = vmin;
   if(normalized > vmax)
      normalized = vmax;

   int digits = 2;
   if(vstep >= 1.0)  digits = 0; // V30 fix: some brokers use whole-lot steps
   if(vstep < 0.1)   digits = 2;
   if(vstep < 0.01)  digits = 3;
   if(vstep < 0.001) digits = 4;

   return NormalizeDouble(normalized, digits);
}

// --- V29 ported: Zone Map (nearest H1/M15 wall) functions moved earlier (before GridDistanceForNextOrder) to avoid forward-reference ---

// --- V29 ported: Zone Map caution for momentum entries - never blocks, only trims lot near a wall ---
double ZoneMapMomentumLotAdjust(const double lot)
{
   // V31.6c fix: this used to apply ONLY to OPP_TYPE_MOMENTUM_SCALP entries, so a Sweep,
   // Range-Edge, or Pullback entry could open directly INTO a strong opposing wall (e.g. a
   // SELL right at strong M15 support) with zero caution. Opening near a strong wall is risky
   // regardless of which detector produced the signal - so this now applies to every entry type.
   if(!EnableZoneMapMomentumCaution)
      return lot;

   double ask = 0.0, bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return lot;

   double dist = -1.0;
   double level = 0.0;
   if(G_OPP_DIR == OPP_DIR_BUY)
   {
      level = ZoneMapNearestResistance(ask);
      // FIX(momentum-wall-negative-dist), BUY side: the resistance scan is now lenient the same
      // way the support scan has been since V243, so this can come back slightly BELOW ask. A
      // signed distance then goes negative, the `dist >= 0.0` guard below fails, and the whole
      // "opening into a wall -> trim the lot" caution is skipped at exactly the moment the wall is
      // closest. Same bug that was already fixed on the SELL branch.
      if(level > 0.0)
         dist = MathAbs(level - ask) / _Point;
   }
   else if(G_OPP_DIR == OPP_DIR_SELL)
   {
      level = ZoneMapNearestSupport(bid);
      // FIX(momentum-wall-negative-dist): MathAbs, because ZoneMapNearestSupport() can legitimately
      // return a level slightly ABOVE bid (the V243 ZoneNearAboveTolerance case - price standing
      // INSIDE the shelf). A signed (bid - level) then goes negative, the `dist >= 0.0` guard below
      // fails, and this entire "opening into a wall -> trim the lot" caution is skipped - so the EA
      // would open a FULL-size sell at exactly the moment the wall is closest. (The BUY branch above
      // now needs the same treatment, for the same reason - see its own note.)
      if(level > 0.0)
         dist = MathAbs(bid - level) / _Point;
   }

   if(dist >= 0.0 && dist <= ZoneMapMomentumCautionPoints)
   {
      double strength = ZoneMapStrength(level);
      double factor = ZoneMapMomentumLotFactor / (1.0 + (strength - 1.0) * ZoneStrengthLotTrimScale);
      factor = MathMax(0.05, factor);

      if((ZoneMapPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.6c ZONE WALL] entry %.0f pts from wall (strength=%.2f) - lot trimmed x%.2f (not blocked)",
                     dist, strength, factor);
      return lot * factor;
   }

   return lot;
}

// NOTE: the default value for apply_side_effects lives on the forward declaration near the top of
// the file ONLY - repeating it here as well is a "default parameter already defined" compile error.
double LotForCurrentEntry(const bool apply_side_effects)
{
   double lot = StartLot;

   // V285: size the base lot to the balance before anything else touches it. StartLot is a fixed
   // number and a balance is not - the same 0.25 that is conservative on a large account is the
   // whole of a small one, and until now the affordability check compared the fixed lot against the
   // moving budget and refused the entry whenever they did not line up.
   //
   // Solving for the lot instead keeps the ladder intact. All its rungs, its spacing, its
   // multiplier - a $100 account trades the same structure as a $10,000 one, in the size that
   // structure costs at $100. It only ever sizes DOWN; a large account still trades what it was
   // told to.
   if(EnableEntryAffordability && EnableBalanceSizedLot)
   {
      int bs_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(bs_dir == 0) bs_dir = 1;          // sizing is direction-independent; any non-zero will do

      double fitted = AffordableStartLot(bs_dir);
      if(fitted > 0.0 && fitted < lot)
      {
         if(apply_side_effects && (BalanceSizedLotPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v285 SIZE] balance %.2f carries %.2f lots for a %d-rung ladder (StartLot %.2f)",
                        AccountInfoDouble(ACCOUNT_BALANCE), fitted, MaxOrders, StartLot);
         lot = fitted;
      }
   }


   // FIX(rc-check-side-effects): apply_side_effects=false is for callers that only want the
   // NUMBER (e.g. UpdateRCSettingsBalance comparing it against a cap) without mutating diagnostic
   // globals (G_LOT_TRACE, the AutoLotPrintOnUse dedup) or - more importantly - G_SCALEIN_PENDING_LOT,
   // which used to get overwritten by every "just checking" call made while G_BASKET_ORDERS <= 0,
   // corrupting the real scale-in completion armed by an actual entry moments earlier in the same tick.
   bool eff_trace           = EnableLotTrace && apply_side_effects;
   bool eff_autolot_print   = (AutoLotPrintOnUse && VerboseLogs) && apply_side_effects;
   bool eff_confidence_print = (ConfidenceLotPrintOnUse && VerboseLogs) && apply_side_effects;

   // V31 AUTOLOT: yoqilganda StartLot va mode-lotlar o'rniga balans/equity'dan hisoblanadi.
   if(UseAutoLot)
   {
      double auto_lot = AutoLotBase();
      if(auto_lot > 0.0)
      {
         lot = auto_lot;
         if(eff_autolot_print)
         {
            static double last_printed_autolot = 0.0;
            if(MathAbs(auto_lot - last_printed_autolot) > 0.0005)
            {
               PrintFormat("[SIRUS v31 AUTOLOT] base lot=%.2f (%s=%.2f, mode=%s)",
                           auto_lot,
                           (AutoLotUseEquity ? "equity" : "balance"),
                           (AutoLotUseEquity ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE)),
                           (AutoLotRiskMode ? "risk%" : "per-1000"));
               last_printed_autolot = auto_lot;
            }
         }
      }
   }
   else
   {
      if(G_ACTIVE_MODE == NAVIUS_MODE_BALANCED && LotForBalancedMode > 0.0)
         lot = LotForBalancedMode;

      if(G_ACTIVE_MODE == NAVIUS_MODE_HIGH_HUNTER && LotForHighHunterMode > 0.0)
         lot = LotForHighHunterMode;
   }

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS)
      lot *= MicroLotFactor();

   if(MaxLot > 0.0 && lot > MaxLot)
      lot = MaxLot;

   // V31.5 LOT TRACE: har bosqich lotni o'zgartirsa izga yoziladi.
   double lt_prev = lot;
   if(eff_trace) G_LOT_TRACE = StringFormat("base=%.2f", lot);
#define LT_STEP(name) if(eff_trace && MathAbs(lot - lt_prev) > 0.0001) { G_LOT_TRACE += StringFormat(" -> %s=%.2f", name, lot); lt_prev = lot; }

   lot = Pack4MiniAdjustLot(lot, false);              LT_STEP("p4mini")
   lot = ZoneMapMomentumLotAdjust(lot);               LT_STEP("zoneMom")


   ENUM_ORDER_TYPE current_order_type = (G_OPP_DIR == OPP_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   lot = CorrelationGuardLotAdjust(lot, current_order_type);  LT_STEP("corr")
   lot = EconomicCalendarLotAdjust(lot);  LT_STEP("calendar")
   lot = HTFStructureLotAdjust(lot, current_order_type);  LT_STEP("htf")
   lot = FirstEntryTrendGuardLotAdjust(lot, current_order_type);  LT_STEP("trendG")
   lot = DXYProxyLotAdjust(lot, current_order_type);  LT_STEP("dxy")
   lot = BrokerHolidayLotAdjust(lot);  LT_STEP("holiday")
   lot = NYKillzoneLotAdjust(lot);     LT_STEP("nykillzone")
   lot = MarginLevelLotAdjust(lot);    LT_STEP("marginLevel")
   lot = SpreadATRQualityLotAdjust(lot);                       LT_STEP("spreadATR")
   lot = PostSLDirectionLotAdjust(lot, current_order_type);   LT_STEP("postSL")
   lot = ImpulseCorrectionLotAdjust(lot, current_order_type);  LT_STEP("impulseCorr")
   lot = SwingImpulseCorrectionLotAdjust(lot, current_order_type);  LT_STEP("swingImpulse")
   lot = MarketConfidenceLotAdjust(lot, G_OPP_TYPE);  LT_STEP("bayesConf")
   lot = SelfDefenseLotAdjust(lot);                  // V31: himoya rejimida kamaytirish  LT_STEP("defense")
   lot = MBEntryLotAdjust(lot);                      LT_STEP("judgeCaution")   // Market Brain: CAUTION entries are smaller

   // V31.6 new: global floor. Multiple trim guards measure overlapping conditions
   // (trend-against + HTF-counter + DXY-against are near-triplicates), so stacked
   // multiplication could crush the lot to a meaningless size (e.g. 0.25 -> 0.04).
   // All guards keep working, but the combined cut can never go below this fraction
   // of the base lot.
   if(MinFirstEntryLotFactor > 0.0)
   {
      double lot_floor = StartLot * MinFirstEntryLotFactor;
      if(G_ACTIVE_MODE == NAVIUS_MODE_BALANCED && LotForBalancedMode > 0.0)
         lot_floor = LotForBalancedMode * MinFirstEntryLotFactor;
      if(G_ACTIVE_MODE == NAVIUS_MODE_HIGH_HUNTER && LotForHighHunterMode > 0.0)
         lot_floor = LotForHighHunterMode * MinFirstEntryLotFactor;

      // FIX(micro-floor): a MICRO entry is deliberately smaller (StartLot x MicroLotFactor), but the
      // floor above is computed from the FULL StartLot. With MinFirstEntryLotFactor at 1.0 that floor
      // equals a full first entry, so it silently pushed every micro back up to the full lot and the
      // whole "smaller micro" idea did nothing in Balanced mode. When this is a micro entry, scale the
      // floor by the same MicroLotFactor so the intended micro size (e.g. 0.25 x 0.80 = 0.20) survives
      // while still protecting it from being cut below that by the other adjusters.
      if(G_SCORE_IS_MICRO)
         lot_floor *= MicroLotFactor();

      if(lot < lot_floor)
         lot = lot_floor;
   }
   LT_STEP("floor")

   // FIX(MaxLot-ceiling): the MaxLot check near the top of this function runs BEFORE all the
   // *LotAdjust() steps. Any adjuster that can multiply the lot UP (e.g. MarketConfidenceLotAdjust
   // when ConfidenceMaxLotMultiplier > 1.0) could therefore push the final lot past MaxLot with no
   // final guard. NextGridLot() already re-clamps at the end; the first-entry path did not. This
   // makes MaxLot the genuine hard ceiling its own comment promises.
   if(MaxLot > 0.0 && lot > MaxLot)
   {
      lot = MaxLot;
      LT_STEP("maxCap")
   }

      if(eff_trace)
   {
      double lt_final = NormalizeVolumeSafe(lot);
      if(MathAbs(lt_final - lt_prev) > 0.0001)
         G_LOT_TRACE += StringFormat(" -> norm=%.2f", lt_final);
      G_LOT_TRACE += StringFormat(" | FINAL=%.2f", lt_final);
   }

   // V170: the three entry-size adjustments are COMBINED before any limit is applied, for the same
   // reason the target factors are. Applied one after another they multiplied: conviction 0.80,
   // projection 0.45 and scale-in 0.80 compound to 0.29, turning a 0.25 first entry into 0.072 -
   // and since every grid lot multiplies from the first, the whole ladder came out at 1.27 lots
   // instead of 4.48. The recovery engine would have been three times weaker than the settings say,
   // silently, with each individual adjustment looking perfectly reasonable on its own.
   double lot_factor = 1.0;
   string lot_why = "";

   // 1. Conviction - how far above the bar did this setup score, and does the record support it?
   if(EnableConfidenceLot && lot > 0.0)
   {
      int conf_min = (G_SCORE_MIN_REQUIRED > 0) ? G_SCORE_MIN_REQUIRED
                                                : MinScoreForContext(G_SCORE_IS_MICRO);
      conf_min = MathMax(1, conf_min);
      int conf_full = MathMax(conf_min + 1, ConfidenceLotFullScore);
      int conf_now  = G_SCORE_FINAL;

      if(conf_now > 0)
      {
         double t = (double)(conf_now - conf_min) / (double)(conf_full - conf_min);
         t = MathMax(0.0, MathMin(1.0, t));

         double floor_factor = MathMax(0.1, MathMin(1.0, ConfidenceLotMinFactor));
         double f_conf = floor_factor + (1.0 - floor_factor) * t;

         // The score claims conviction; the record says whether that claim is earned.
         if(EnableCalibratedLotSizing)
         {
            int cal_samples = 0;
            double cal_wr = ScoreBandWinRate(conf_now - conf_min, cal_samples);   // V249fix(auto-mode): margin (conf_min already has the >0 fallback applied)
            if(cal_wr >= 0.0)
            {
               if(cal_wr <= CalibrationPoorWinRate)
                  f_conf = floor_factor;
               else if(cal_wr < CalibrationGoodWinRate)
                  f_conf = floor_factor + (f_conf - floor_factor) * 0.5;
            }
         }

         lot_factor *= f_conf;
         if(f_conf < 0.999) lot_why += StringFormat("conviction x%.2f ", f_conf);
      }
   }

   // 2. Accumulated warnings. This is where the modules earn their place: rather than refusing a
   // setup that has three or four cautions against it, the EA takes it at a size that matches how
   // much is actually in doubt. A clean setup gets the full lot; one carrying twelve points of
   // warning gets the floor. Both trade - which is the point, since blocking them is what turned a
   // high-frequency scalper into something that traded twice a day.
   if(EnableWarningLotScaling && G_PENALTY_RAW > 0)
   {
      double w_span = MathMax(1.0, (double)WarningLotFullPenalty);
      double w_t = MathMax(0.0, MathMin(1.0, (double)G_PENALTY_RAW / w_span));
      double f_warn = 1.0 - (1.0 - WarningLotMinFactor) * w_t;
      lot_factor *= f_warn;
      if(f_warn < 0.999) lot_why += StringFormat("warnings(%d) x%.2f ", G_PENALTY_RAW, f_warn);
   }

   // 3. Projection - does the ladder this entry commits to fit inside the account?
   if(EnableBasketProjection && !G_PROJECTION_MEASURING &&
      G_PROJECTION_LOT_FACTOR > 0.0 && G_PROJECTION_LOT_FACTOR < 0.999)
   {
      lot_factor *= G_PROJECTION_LOT_FACTOR;
      lot_why += StringFormat("ladder x%.2f ", G_PROJECTION_LOT_FACTOR);
   }

   // Bounded once, together. Below this floor the ladder stops being the ladder the settings
   // describe, and the recovery maths behind it no longer holds.
   lot_factor = MathMax(EntryLotFactorMin, MathMin(1.0, lot_factor));

   if(lot_factor < 0.999)
   {
      double scaled = lot * lot_factor;
      if(eff_confidence_print)
         PrintFormat("[SIRUS v170 ENTRY LOT] %.2f -> %.2f (x%.2f: %s)",
                     lot, NormalizeVolumeSafe(scaled), lot_factor, lot_why);
      lot = scaled;
   }

   // V220: size follows the situation's reliability. A reversal is the least repeatable of the four
   // - when it fails the prior trend resumes immediately - so it gets the smallest commitment, while
   // a level holding inside a range is the most repeatable and gets the full size.
   if(EnableSituationPlan && G_SITUATION != SIT_NONE && G_BASKET_ORDERS <= 0)
   {
      double sl_f = SituationLotFactor(G_SITUATION);
      if(sl_f > 0.0 && MathAbs(sl_f - 1.0) > 0.01)
         lot *= sl_f;
   }

   // V161: take only part of the intended size now; the rest is added once price confirms.
   // The full figure is remembered so the grid ladder still multiplies from it - a completion is
   // part of this entry, not a rung of the ladder.
   // FIX(scale-in-autolot-remainder): captured BEFORE the split overwrites `lot`, so the floor
   // block below can recompute the held-back remainder against the actual pipeline result
   // (AutoLot base + every *LotAdjust() step + conviction/warning/projection/situation factors)
   // instead of the raw StartLot input, which silently diverges from it whenever UseAutoLot is on.
   double full_intended_lot = lot;
   if(EnableScaleIn && !G_PROJECTION_MEASURING && lot > 0.0 && G_BASKET_ORDERS <= 0)
   {
      // V170: scale-in splits what is left AFTER the adjustments above, and its own floor is
      // applied to that - so the first part can never fall below what the combined limit allows.
      double frac = ScaleInAdaptiveFraction();
      double first_part = NormalizeVolumeSafe(lot * frac);
      double remainder  = NormalizeVolumeSafe(lot - first_part);

      // Only worth splitting if both halves are tradeable sizes.
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(first_part >= min_lot && remainder >= min_lot)
      {
         // FIX(rc-check-side-effects): only arm the real scale-in state for a call that is
         // actually about to open the entry - a "just checking the number" call must not
         // overwrite what a real entry may have just armed this same tick.
         if(apply_side_effects)
            G_SCALEIN_PENDING_LOT = remainder;   // armed properly once the entry actually opens
         lot = first_part;
      }
      else if(apply_side_effects)
         G_SCALEIN_PENDING_LOT = 0.0;
   }

   // V175: the floor applies to the ORDER THAT ACTUALLY OPENS, which is what the user sees on the
   // chart and what the account is committed to. Placing it before the scale-in split would have
   // guaranteed the intended lot rather than the executed one - and after conviction scaling, ladder
   // scaling and an 85% split, an 0.25 intent was opening at 0.17.
   //
   // Expressed as a fraction of StartLot rather than a fixed volume, so it follows automatically
   // when StartLot is changed for a different account size.
   if(EntryLotAbsoluteFloor > 0.0 && lot > 0.0 && G_BASKET_ORDERS <= 0)
   {
      double floor_lot = NormalizeVolumeSafe(StartLot * MathMax(0.1, MathMin(1.0, EntryLotAbsoluteFloor)));
      if(lot < floor_lot)
      {
         if(eff_confidence_print)
            PrintFormat("[SIRUS v175 LOT FLOOR] opening lot %.2f -> %.2f (never below %.0f%% of StartLot %.2f)",
                        lot, floor_lot, EntryLotAbsoluteFloor * 100.0, StartLot);
         lot = floor_lot;

         // The held-back portion is recomputed against the raised lot, so the two still add up to
         // a coherent position rather than the remainder of a smaller one.
         // FIX(scale-in-autolot-remainder): was `StartLot` unconditionally - wrong whenever
         // UseAutoLot (or mode-lot selection) makes the pipeline's actual base differ from the raw
         // StartLot input, since then this "remainder" no longer added up to what the rest of the
         // pipeline actually intended to commit. Use the captured pre-split pipeline result instead.
         // FIX(rc-check-side-effects): G_SCALEIN_PENDING_LOT only armed for a real entry call.
         // FIX(projection-clears-pending-lot): ...and not during a risk PROJECTION either. The
         // scale-in SPLIT above is skipped while G_PROJECTION_MEASURING, so full_intended_lot
         // equals lot, so `rest` is 0 and this line would zero a pending lot a real entry had
         // armed moments earlier. ProjectBasketRisk() calls LotForCurrentEntry() with side effects
         // on, so the guard has to name the projection explicitly.
         if(apply_side_effects && !G_PROJECTION_MEASURING)
         {
            double intended = MathMax(full_intended_lot, floor_lot);
            double rest = NormalizeVolumeSafe(intended - lot);
            double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            G_SCALEIN_PENDING_LOT = (rest >= min_lot) ? rest : 0.0;
         }
      }
   }


#undef LT_STEP
   return NormalizeVolumeSafe(lot);
}

string BuildOrderComment()
{
   // MT5 truncates order comments near 31 chars, so keep the brand (F.Zakiy) plus the two useful
   // fields (mode + entry type) and drop the version string, which was what pushed the old comment
   // past the limit and got the mode/type cut off. "Navius by Zakiy BAL FIRST" = 25 chars.
   string entry_type = (G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS ? "MICRO" : "FIRST");
   return StringFormat("Navius by Zakiy %s %s", ModeToShortString(G_ACTIVE_MODE), entry_type);
}

int CountNaviusPositions()
{
   int count = 0;
   int total = PositionsTotal();

   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);

      if(sym == _Symbol && magic == MagicNumber)
         count++;
   }

   return count;
}

bool HasOpenNaviusPosition()
{
   return (CountNaviusPositions() > 0);
}

double EntryTPPoints()
{
   // V283: rebate mode reaches here too. The switch was put in BaseBasketTPPoints on the assumption
   // that every target reads from it - the basket targets do, and the FIRST entry does not. It has
   // its own chain: MainTPPoints, then the ATR adaptation, then a floor of FirstEntryTPMinPoints.
   // So rebate mode was correctly wired for the basket and silently absent from the one order that
   // actually opens, which is why the target came out at its usual size.
   if(EnableRebateMode)
   {
      double rebate_tp = RebateTargetPoints();
      if(rebate_tp > 0.0)
         return rebate_tp;
   }

   bool is_micro = (G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS);
   double tp = (is_micro ? MicroTPPoints() : MainTPPoints());

   // V31.1 ATR-ADAPTIV TP: fiks TP o'rniga volatillikka mos TP.
   // Volatil kunda TP kengayadi (erta yopilmaydi), tinch kunda torayadi (yetib boradi).
   // Micro-scalp entrylarga tegilmaydi - ularning o'z qisqa TP mantig'i bor.
   if(EnableATRAdaptiveTP && !is_micro)
   {
      double atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
      if(atr > 0.0 && ATRTPFactor > 0.0)
      {
         double atr_tp = atr * ATRTPFactor;
         if(atr_tp < (double)MathMax(1, ATRTPMinPoints)) atr_tp = (double)ATRTPMinPoints;
         if(ATRTPMaxPoints > ATRTPMinPoints && atr_tp > (double)ATRTPMaxPoints) atr_tp = (double)ATRTPMaxPoints;

         if((ATRTPPrintOnUse && VerboseLogs) && MathAbs(atr_tp - tp) > 1.0)
            PrintFormat("[SIRUS v31.1 ATR-TP] fixed %.0f -> adaptive %.0f (ATR=%.0f x %.2f)", tp, atr_tp, atr, ATRTPFactor);
         tp = atr_tp;
      }
   }

   if(tp < FirstEntryTPMinPoints)
      tp = FirstEntryTPMinPoints;

   return ApplyTPScale(tp);   // v291a: TP biroz kichikroq (TPScale)
}

double NormalizePriceSafe(const double price)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // FIX(tick-size): round to the broker's actual TRADE_TICK_SIZE, not just to digits. On most
   // symbols (incl. XAUUSD) tick size == point, so this matches the old behaviour. But some
   // brokers use a tick size larger than a point (e.g. 0.05 on certain metals/indices); an
   // off-tick price there gets the order rejected with "invalid price". Snapping to the tick
   // grid first makes the price always broker-valid. Falls back to plain digit rounding if the
   // tick size is unavailable.
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size > 0.0)
   {
      double snapped = MathRound(price / tick_size) * tick_size;
      return NormalizeDouble(snapped, digits);
   }

   return NormalizeDouble(price, digits);
}

// --- V29 ported: Zone Map functions moved earlier (before LotForCurrentEntry) to avoid forward-reference ---

// --- V29 ported: HTF Structure Commander (H1 trend bias) - warning only, never blocks entry ---
void HTFStructureWarnIfCounterTrend(const ENUM_ORDER_TYPE order_type)
{
   if(!EnableHTFStructureWarn)
      return;

   int bias = HTFStructureBias();
   bool counter = (order_type == ORDER_TYPE_BUY && bias < 0) || (order_type == ORDER_TYPE_SELL && bias > 0);

   if(counter && (HTFStructurePrintOnUse && VerboseLogs))
   {
      PrintFormat("[SIRUS v29 HTF STRUCTURE] warning: entering %s against H1 bias=%d (info only, not blocked)",
                  (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), bias);
   }
}

bool BuildEntryPrices(ENUM_ORDER_TYPE order_type, double &price, double &sl, double &tp)
{
   double ask = 0.0, bid = 0.0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) || !SymbolInfoDouble(_Symbol, SYMBOL_BID, bid))
      return false;

   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return false;

   double tp_points = EntryTPPoints();
   double sl_points = (UseFirstEntrySL ? (double)FirstEntrySLPoints : 0.0);

   if(order_type == ORDER_TYPE_BUY)
   {
      price = ask;
      tp = (UseIndividualTPForFirstEntry && tp_points > 0.0) ? price + tp_points * _Point : 0.0;
      sl = (UseFirstEntrySL && sl_points > 0.0) ? price - sl_points * _Point : 0.0;

      // V283: spread-aware widening is exactly what rebate mode already does, by design and with its
      // own multiple - applying both widens the target twice.
      if(EnableSpreadAwareTP && !EnableRebateMode && tp > 0.0)
      {
         double spread_points = (ask - bid) / _Point;
         double min_required = spread_points * SpreadAwareMinRatio + SpreadAwareCommissionPoints;
         double current_tp_points = PointsBetween(price, tp);
         if(current_tp_points < min_required)
         {
            double widened = price + min_required * _Point;
            if((SpreadAwarePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v29 SPREAD-AWARE TP] widened %.5f -> %.5f (spread=%.0fpts ratio=%.1f)",
                           tp, widened, spread_points, SpreadAwareMinRatio);
            tp = widened;
         }
      }

      if(EnableZoneMapTPGuard && tp > 0.0)
      {
         double res = ZoneMapNearestResistance(price);
         if(res > 0.0 && res < tp)
         {
            double strength = ZoneMapStrength(res);
            double buffer_points = ZoneMapBufferPoints * (1.0 + (strength - 1.0) * ZoneStrengthTPBufferScale);
            double capped = res - buffer_points * _Point;
            // V283: and the floor does not apply in rebate mode - a floor of 2000 points is twenty
         // times the target the mode is built around, so it would quietly restore the ordinary
         // target under a different name.
         double min_floor = price + (EnableRebateMode ? RebateTargetPoints() : (double)FirstEntryTPMinPoints) * _Point;
            if(capped > min_floor)
            {
               if((ZoneMapPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v29 ZONE MAP] TP capped before resistance %.5f -> %.5f (strength=%.2f buffer=%.0f)",
                              tp, capped, strength, buffer_points);
               tp = capped;
            }
         }
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      price = bid;
      tp = (UseIndividualTPForFirstEntry && tp_points > 0.0) ? price - tp_points * _Point : 0.0;
      sl = (UseFirstEntrySL && sl_points > 0.0) ? price + sl_points * _Point : 0.0;

      // V283: spread-aware widening is exactly what rebate mode already does, by design and with its
      // own multiple - applying both widens the target twice.
      if(EnableSpreadAwareTP && !EnableRebateMode && tp > 0.0)
      {
         double spread_points = (ask - bid) / _Point;
         double min_required = spread_points * SpreadAwareMinRatio + SpreadAwareCommissionPoints;
         double current_tp_points = PointsBetween(price, tp);
         if(current_tp_points < min_required)
         {
            double widened = price - min_required * _Point;
            if((SpreadAwarePrintOnUse && VerboseLogs))
               PrintFormat("[SIRUS v29 SPREAD-AWARE TP] widened %.5f -> %.5f (spread=%.0fpts ratio=%.1f)",
                           tp, widened, spread_points, SpreadAwareMinRatio);
            tp = widened;
         }
      }

      if(EnableZoneMapTPGuard && tp > 0.0)
      {
         double sup = ZoneMapNearestSupport(price);
         if(sup > 0.0 && sup > tp)
         {
            double strength = ZoneMapStrength(sup);
            double buffer_points = ZoneMapBufferPoints * (1.0 + (strength - 1.0) * ZoneStrengthTPBufferScale);
            double capped = sup + buffer_points * _Point;
            double min_floor = price - (EnableRebateMode ? RebateTargetPoints() : (double)FirstEntryTPMinPoints) * _Point;
            if(capped < min_floor)
            {
               if((ZoneMapPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v29 ZONE MAP] TP capped before support %.5f -> %.5f (strength=%.2f buffer=%.0f)",
                              tp, capped, strength, buffer_points);
               tp = capped;
            }
         }
      }
   }
   else
      return false;

   HTFStructureWarnIfCounterTrend(order_type);

   // Rebate trailing: a broker TP at the small cashback target would close the first order before the
   // trail could ever arm. The basket exit and the broker-side trailing stop own the exit instead.
   if(RebateTrailingOn())
      tp = 0.0;

   price = NormalizePriceSafe(price);
   if(tp > 0.0) tp = NormalizePriceSafe(tp);
   if(sl > 0.0) sl = NormalizePriceSafe(sl);

   return true;
}

bool CheckStopFreezeDistance(const ENUM_ORDER_TYPE order_type, const double price, double &sl, double &tp, string &reason)
{
   long stop_level = 0;
   long freeze_level = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stop_level);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);

   double min_points = (double)MathMax(stop_level, freeze_level);
   if(min_points < 0.0)
      min_points = 0.0;

   // FIX(auto-widen-tp): a TP/SL closer than the broker's stop/freeze level used to CANCEL the
   // whole trade. Since this bot uses a single TP (no individual SL by default), losing an
   // otherwise-valid entry over a too-tight TP is wasteful. Instead, push the level out to the
   // broker minimum (plus a small pad) IN THE CORRECT DIRECTION and let the trade proceed. A tiny
   // pad above the exact minimum avoids a borderline rejection from rounding/spread jitter.
   if(min_points > 0.0 && (tp > 0.0 || sl > 0.0))
   {
      double pad_points = min_points + 5.0;   // 5-point safety pad over the hard minimum

      if(tp > 0.0 && PointsBetween(price, tp) < min_points)
      {
         double old_tp = tp;
         tp = (order_type == ORDER_TYPE_BUY) ? price + pad_points * _Point
                                             : price - pad_points * _Point;
         tp = NormalizePriceSafe(tp);
         PrintFormat("[SIRUS TP AUTO-WIDEN] TP %.2f too close (<%dpts) -> widened to %.2f",
                     old_tp, (int)min_points, tp);
      }

      if(sl > 0.0 && PointsBetween(price, sl) < min_points)
      {
         double old_sl = sl;
         sl = (order_type == ORDER_TYPE_BUY) ? price - pad_points * _Point
                                             : price + pad_points * _Point;
         sl = NormalizePriceSafe(sl);
         PrintFormat("[SIRUS SL AUTO-WIDEN] SL %.2f too close (<%dpts) -> widened to %.2f",
                     old_sl, (int)min_points, sl);
      }
   }

   reason = "levels ok";
   return true;
}

// V31.6e new: M1 entry-close confirmation. A signal must survive until the M1 bar it appeared
// on actually CLOSES before we act on it - filters out a signal that flickers into existence
// on a tick spike and vanishes before the bar finishes. Applies identically to a fresh first
// entry and a reentry right after a quick close: the direction is tracked, not "is this the
// first ever entry", so neither gets a free pass.
bool M1EntryCloseAllows(string &reason)
{
   if(!UseM1EntryClose)
   {
      reason = "M1 close confirm off";
      return true;
   }

   datetime cur_m1_bar = iTime(_Symbol, PERIOD_M1, 0);
   int cur_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));

   if(cur_dir == 0)
   {
      reason = "no opportunity direction";
      return false;
   }

   if(cur_dir != G_M1_GATE_LAST_DIR)
   {
      G_M1_GATE_LAST_DIR = cur_dir;
      G_M1_GATE_BAR = cur_m1_bar;
      reason = "new signal - waiting M1 bar close";
      return false;
   }

   if(cur_m1_bar == G_M1_GATE_BAR)
   {
      reason = "waiting current M1 bar to close";
      return false;
   }

   reason = "M1 bar closed - signal confirmed";
   return true;
}


// ---------------------------------------------------------------------------- v291b
// BOSQICH 5b: daraja qachon SINGAN hisoblanadi. Ilgari faqat M5 yopilishi bilan - $20 lik impulsda bu
// juda sekin edi: narx darajadan ancha o'tib ketgan, lekin M5 hali yopilmagan -> daraja "tirik" ->
// davom etish savdosi to'silardi. Endi: M5 yopilishi YOKI ketma-ket 2 ta M1 yopilishi daraja ortida.
// Supurish (soya, bitta M1 yopilishi va darhol qaytish) sinish hisoblanmaydi - himoya saqlanadi.
// dir > 0: resistance (yuqoriga sinish), dir < 0: support (pastga sinish).
bool LGBrokenBeyond(const int dir, const double lvl, const double tol)
{
   double c5 = CandleClose(PERIOD_M5, 1);
   if(dir > 0 ? (c5 > lvl + tol) : (c5 < lvl - tol))
      return true;
   double c1a = CandleClose(PERIOD_M1, 1), c1b = CandleClose(PERIOD_M1, 2);
   if(dir > 0 ? (c1a > lvl + tol && c1b > lvl + tol) : (c1a < lvl - tol && c1b < lvl - tol))
      return true;

   // BOSQICH 9: SEKIN SINISH. Narx darajaning ortida ketma-ket LGHoldBeyondBarsM1 ta M1 shamida
   // yopilgan bo'lsa (kichik farq bilan ham) - bu supurish emas, narx u yerda USHLANIB turibdi.
   // Supurish - bu tez teshish va 1-2 sham ichida qaytish; bir necha daqiqa ortida turish - sinish.
   // Rasm: narx 4323 resistance ustida 30-60 sent yuqorida bir necha M1 yopilgan, lekin $1 lik
   // tolerans tufayli "tirik" hisoblanib, break-retest BUY to'silgan edi.
   int hb = MathMax(2, LGHoldBeyondBarsM1);
   for(int k = 1; k <= hb; k++)
   {
      double ck = CandleClose(PERIOD_M1, k);
      if(ck <= 0.0) return false;
      if(dir > 0 ? (ck <= lvl) : (ck >= lvl)) return false;
   }
   return true;
}

// Og'ir qism (har daraja uchun qaytishlarni sanash) M1 bariga bir marta; har tikda faqat masofa.
void LGScan(const int tfs, const int dir, const double px, const double near_px,
            double &best_lvl, int &best_ep, double &best_ws, bool &best_pierced)
{
   best_lvl = 0.0; best_ep = 0; best_ws = 0.0; best_pierced = false;
   static int    cb_bar[2][2];
   static bool   cb_init = false;
   static int    cb_n[2][2];
   static double cb_lvl[2][2][200], cb_ws[2][2][200];
   static int    cb_ep[2][2][200];
   if(!cb_init)
   {
      for(int a = 0; a < 2; a++) for(int b = 0; b < 2; b++) { cb_bar[a][b] = -100000; cb_n[a][b] = 0; }
      cb_init = true;
   }
   ENUM_TIMEFRAMES tf = (tfs == 0) ? PERIOD_M5 : PERIOD_M15;
   int look = (tfs == 0) ? LGLookbackM5 : LGLookbackM15;
   int ds = (dir > 0) ? 0 : 1;

   if(cb_bar[tfs][ds] != G_BARS_SEEN)
   {
      cb_bar[tfs][ds] = G_BARS_SEEN;
      cb_n[tfs][ds] = 0;
      double h_[200], l_[200], c_[200];
      int n = MathMax(6, MathMin(200, look));
      for(int i = 1; i <= n; i++)
      {
         h_[n - i] = CandleHigh(tf, i);
         l_[n - i] = CandleLow(tf, i);
         c_[n - i] = CandleClose(tf, i);
      }
      double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
      if(atr > 0.0)
      {
         double tol = atr * LGTouchATR, sep = atr * LGSeparationATR, mw = atr * LGMinWickATR;
         for(int a = 0; a < n; a++)
         {
            double rng = h_[a] - l_[a];
            if(rng <= 0.0) continue;
            double lvl  = (dir < 0) ? l_[a] : h_[a];
            double wick = (dir < 0) ? (c_[a] - l_[a]) : (h_[a] - c_[a]);
            if(wick < mw || wick < rng * LGWickShare) continue;

            int ep = 0; bool away = true; double cur = 0.0, ws = 0.0;
            for(int k = 0; k < n; k++)
            {
               double rk = h_[k] - l_[k];
               if(rk <= 0.0) continue;
               bool rej, left; double exc;
               if(dir < 0)
               {
                  double wk = c_[k] - l_[k];
                  rej  = (MathAbs(l_[k] - lvl) <= tol && wk >= rk * LGWickShare && wk >= mw);
                  left = (h_[k] >= lvl + sep || l_[k] < lvl - sep);
                  exc  = h_[k] - lvl;
               }
               else
               {
                  double wk = h_[k] - c_[k];
                  rej  = (MathAbs(h_[k] - lvl) <= tol && wk >= rk * LGWickShare && wk >= mw);
                  left = (l_[k] <= lvl - sep || h_[k] > lvl + sep);
                  exc  = lvl - l_[k];
               }
               if(rej && away)
               {
                  if(ep > 0) ws += (cur >= atr * LGStrongBounceATR) ? 2.0 : 1.0;
                  ep++; away = false; cur = 0.0;
               }
               if(ep > 0 && exc > cur) cur = exc;
               if(left) away = true;
            }
            if(ep <= 0) continue;
            ws += (cur >= atr * LGStrongBounceATR) ? 2.0 : 1.0;

            // BOSQICH 5c: keyinchalik SINGANMI? Daraja paydo bo'lgandan keyin biror sham uning
            // ortida yopilgan bo'lsa - u endi bu tomon uchun devor emas (support singan bo'lsa,
            // u endi resistance). Ilgari bu tekshirilmasdi: $25 lik tushishda singan eski support
            // narx pastdan qaytib kelganda "support" bo'lib qolib, pullback SELL ni to'sardi.
            bool broken_later = false;
            for(int k = a + 1; k < n && !broken_later; k++)
               if(dir < 0 ? (c_[k] < lvl - tol) : (c_[k] > lvl + tol))
                  broken_later = true;
            if(broken_later) continue;

            int m = cb_n[tfs][ds];
            if(m < 200)
            {
               cb_lvl[tfs][ds][m] = lvl; cb_ep[tfs][ds][m] = ep; cb_ws[tfs][ds][m] = ws;
               cb_n[tfs][ds] = m + 1;
            }
         }
      }
   }

   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   if(px <= 0.0 || atr5 <= 0.0) return;
   double pierce = atr5 * LGPierceATR, brk = atr5 * LGTouchATR;
   for(int j = 0; j < cb_n[tfs][ds]; j++)
   {
      double lvl = cb_lvl[tfs][ds][j];
      double dist = (dir < 0) ? (px - lvl) : (lvl - px);
      bool pierced = false;
      if(dist < 0.0)
      {
         if(dist < -pierce) continue;
         if(LGBrokenBeyond(dir, lvl, brk)) continue;   // BOSQICH 5b: M5 yoki 2 x M1 yopilishi bilan sinish
         pierced = true;                       // faqat soya - daraja tirik
      }
      else if(dist > near_px)
         continue;
      double ws = cb_ws[tfs][ds][j];
      if(ws > best_ws || (ws == best_ws && cb_ep[tfs][ds][j] > best_ep))
      { best_ws = ws; best_ep = cb_ep[tfs][ds][j]; best_lvl = lvl; best_pierced = pierced; }
   }
}

// SELL -> ostidagi support, BUY -> ustidagi resistance
bool LGLiveLevel(const int dir, string &why)
{
   why = "";
   double px = (dir < 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   if(px <= 0.0 || atr5 <= 0.0) return false;

   // "Shundoq yonida": TP yo'lida VA ~1 ATR ichida (yoki darajaning ustida)
   double tp_px = BaseBasketTPPoints() * _Point;
   double near_px = MathMax(atr5 * LGOnLevelATR,
                            MathMin(tp_px > 0.0 ? tp_px * 0.9 : atr5 * LGMaxDistATR, atr5 * LGMaxDistATR));

   double l5, l15, w5, w15; int e5, e15; bool p5, p15;
   LGScan(0, dir, px, near_px, l5, e5, w5, p5);
   LGScan(1, dir, px, near_px, l15, e15, w15, p15);
   bool u15 = (w15 > w5);
   double lvl = u15 ? l15 : l5, ws = u15 ? w15 : w5;
   int ep = u15 ? e15 : e5; bool pc = u15 ? p15 : p5;
   if(ep <= 0) return false;

   double need = (double)MathMax(1, LGMinRejections);
   bool confl = false;
   if(ws < need && ws >= (double)LGConfluenceRejections && ZoneMapStrength(lvl) >= CounterZoneBlockMinStrength)
   { need = (double)LGConfluenceRejections; confl = true; }
   if(ws < need) return false;

   why = StringFormat("%s into %s %.2f (%s, %d rejections%s, %s)",
                      (dir > 0 ? "BUY" : "SELL"), (dir < 0 ? "support" : "resistance"), lvl,
                      (pc ? "wick-pierced" : StringFormat("%.2f away", (dir < 0) ? (px - lvl) : (lvl - px))),
                      ep, (confl ? ", zone map confirms" : ""), (u15 ? "M15" : "M5"));
   return true;
}

// Swing zonasi: BUY - eng yaqin sinmagan swing high ostida, zona ichida; SELL - swing low ustida.
// Swing M5 yopilishi bilan sindirilgan bo'lsa (keyingi shamlardan biri uning narigi tomonida yopilgan) -
// u endi to'siq emas. Og'ir qism (swinglarni topish) M1 bariga bir marta.
bool LGSwingLevel(const int dir, string &why)
{
   why = "";
   if(!LGSwingGuard) return false;
   // BOSQICH 6: uch TF (M15, M5, M1). Har swing uchun REAKSIYA o'lchanadi: narx undan keyin qancha
   // uzoqlashgan. Reaksiya < LGSwingMinReactATR x (shu TF ATR) bo'lsa - bu to'lqin, zona emas.
   // Zona kengligi: M15/M5 - M5 ATR bo'yicha, M1 - M1 ATR bo'yicha (M1 zonasi tor, faqat shundoq yonida).
   static int    sw_bar[2] = {-100000, -100000};
   static int    sw_n[2]   = {0, 0};
   static double sw_lvl[2][200];
   static int    sw_tf[2][200];
   static bool   sw_flip[2][200];
   int ds = (dir > 0) ? 0 : 1;
   int dep = MathMax(1, LGSwingDepth);

   if(sw_bar[ds] != G_BARS_SEEN)
   {
      sw_bar[ds] = G_BARS_SEEN;
      sw_n[ds] = 0;
      int tfs_count = LGSwingUseM1 ? 3 : 2;
      for(int t = 0; t < tfs_count; t++)
      {
         ENUM_TIMEFRAMES tf = (t == 0) ? PERIOD_M15 : ((t == 1) ? PERIOD_M5 : PERIOD_M1);
         int look = MathMin(200, (t == 0) ? LGSwingLookM15 : ((t == 1) ? LGSwingLookM5 : LGSwingLookM1));
         double atr_tf = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
         if(atr_tf <= 0.0) continue;
         double tol = atr_tf * LGTouchATR;
         double min_react = atr_tf * LGSwingMinReactATR;
         for(int i = dep + 1; i <= look; i++)
         {
            double v = (dir > 0) ? CandleHigh(tf, i) : CandleLow(tf, i);
            if(v <= 0.0) continue;
            bool swing = true;
            for(int k = 1; k <= dep && swing; k++)
            {
               double a = (dir > 0) ? CandleHigh(tf, i - k) : CandleLow(tf, i - k);
               double b = (dir > 0) ? CandleHigh(tf, i + k) : CandleLow(tf, i + k);
               if(dir > 0 && (a >= v || b >= v)) swing = false;
               if(dir < 0 && (a <= v || b <= v)) swing = false;
            }
            if(!swing) continue;

            // Reaksiya va keyingi sinish - swingdan keyingi shamlar bo'yicha
            double react = 0.0;
            bool broken = false;
            for(int k = i - 1; k >= 1 && !broken; k--)
            {
               double ck = CandleClose(tf, k);
               if((dir > 0 && ck > v + tol) || (dir < 0 && ck < v - tol)) { broken = true; break; }
               double away = (dir > 0) ? (v - CandleLow(tf, k)) : (CandleHigh(tf, k) - v);
               if(away > react) react = away;
            }
            if(broken || react < min_react) continue;

            int m = sw_n[ds];
            if(m < 200) { sw_lvl[ds][m] = v; sw_tf[ds][m] = t; sw_flip[ds][m] = false; sw_n[ds] = m + 1; }
         }

         // BOSQICH 8: ROL ALMASHGAN DARAJALAR. BUY uchun - yopilish bilan PASTGA singan swing LOW
         // (endi resistance), SELL uchun - YUQORIGA singan swing HIGH (endi support). Shartlar:
         // asl swing haqiqiy bo'lgan (reaksiya >= min_react), sinish YOPILISH bilan, va sinishdan
         // keyin daraja qaytarib olinmagan (qaytib yopilish yo'q).
         if(LGSwingFlip)
         {
            for(int i = dep + 1; i <= look; i++)
            {
               double u = (dir > 0) ? CandleLow(tf, i) : CandleHigh(tf, i);
               if(u <= 0.0) continue;
               bool fsw = true;
               for(int k = 1; k <= dep && fsw; k++)
               {
                  double a = (dir > 0) ? CandleLow(tf, i - k) : CandleHigh(tf, i - k);
                  double b = (dir > 0) ? CandleLow(tf, i + k) : CandleHigh(tf, i + k);
                  if(dir > 0 && (a <= u || b <= u)) fsw = false;   // swing low
                  if(dir < 0 && (a >= u || b >= u)) fsw = false;   // swing high
               }
               if(!fsw) continue;

               int brk_k = -1;
               double react2 = 0.0;
               for(int k = i - 1; k >= 1; k--)
               {
                  double ck = CandleClose(tf, k);
                  if((dir > 0 && ck < u - tol) || (dir < 0 && ck > u + tol)) { brk_k = k; break; }
                  double away = (dir > 0) ? (CandleHigh(tf, k) - u) : (u - CandleLow(tf, k));
                  if(away > react2) react2 = away;
               }
               if(brk_k < 1 || react2 < min_react) continue;

               bool lost = false;
               for(int k = brk_k - 1; k >= 1 && !lost; k--)
               {
                  double ck = CandleClose(tf, k);
                  if((dir > 0 && ck > u + tol) || (dir < 0 && ck < u - tol)) lost = true;
               }
               if(lost) continue;

               int m = sw_n[ds];
               if(m < 200) { sw_lvl[ds][m] = u; sw_tf[ds][m] = t; sw_flip[ds][m] = true; sw_n[ds] = m + 1; }
            }
         }
      }
   }

   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   double atr1 = ATRPointsManual(PERIOD_M1, ATRPeriod, 1) * _Point;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr5 <= 0.0 || px <= 0.0 || sw_n[ds] <= 0) return false;
   if(atr1 <= 0.0) atr1 = atr5 / 2.2;
   double pierce = atr5 * LGPierceATR, brk = atr5 * LGTouchATR;

   double best = 0.0, best_d = 1e9; int best_tf = 0; bool best_flip = false;
   for(int j = 0; j < sw_n[ds]; j++)
   {
      double lvl = sw_lvl[ds][j];
      int    t   = sw_tf[ds][j];
      double band = (t == 2) ? atr1 * LGSwingBandATR : atr5 * LGSwingBandATR;
      double d = (dir > 0) ? (lvl - px) : (px - lvl);   // musbat = zona oldinda
      if(d < 0.0)
      {
         if(d < -((t == 2) ? atr1 * LGPierceATR : pierce)) continue;
         if(LGBrokenBeyond(dir, lvl, brk)) continue;
      }
      else if(d > band)
         continue;
      if(MathAbs(d) < best_d) { best_d = MathAbs(d); best = lvl; best_tf = t; best_flip = sw_flip[ds][j]; }
   }
   if(best <= 0.0) return false;

   why = StringFormat("%s into %s %s %s %.2f (%.2f away)%s",
                      (dir > 0 ? "BUY" : "SELL"), (best_tf == 0 ? "M15" : (best_tf == 1 ? "M5" : "M1")),
                      (best_flip ? "flipped" : "swing"),
                      (dir > 0 ? "resistance" : "support"), best, best_d,
                      (best_flip ? (dir > 0 ? " - retest of a broken support" : " - retest of a broken resistance") : ""));
   return true;
}

// Mayda harakatning uchi: oxirgi LGTipBarsM1 ta M1 shamidagi oyoqning eng chekkasida kirish.
// BUY: narx oyoq tepasining yuqori LGTipShare qismida; SELL: tubida. Narx ozgina qaytsa - o'zi ochiladi.
bool LGMicroTip(const int dir, string &why)
{
   why = "";
   if(!LGBlockMicroTip) return false;
   int n = MathMax(3, MathMin(60, LGTipBarsM1));
   double atr1 = ATRPointsManual(PERIOD_M1, ATRPeriod, 1) * _Point;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr1 <= 0.0 || px <= 0.0) return false;
   double hi = 0.0, lo = 0.0; int hi_i = -1, lo_i = -1;
   for(int i = 0; i <= n; i++)
   {
      double h = CandleHigh(PERIOD_M1, i), l = CandleLow(PERIOD_M1, i);
      if(i == 0) { h = MathMax(h, px); l = MathMin(l, px); }
      if(h <= 0.0 || l <= 0.0) continue;
      if(hi_i < 0 || h > hi) { hi = h; hi_i = i; }
      if(lo_i < 0 || l < lo) { lo = l; lo_i = i; }
   }
   if(hi_i < 0 || lo_i < 0) return false;
   double leg = hi - lo;
   if(leg < atr1 * LGTipLegATR) return false;
   if(LGTipMaxLegATR > 0.0 && leg > atr1 * LGTipMaxLegATR) return false;   // BOSQICH 5b: impuls - mayda uch emas
   // BUY: oyoq pastdan yuqoriga (pastlik tepadan oldin, ya'ni kattaroq indeksda)
   if(dir > 0 && lo_i > hi_i && px >= hi - leg * LGTipShare)
   {
      why = StringFormat("BUY at the tip of a %.2f up-leg (%.2f-%.2f) - waiting for a small pullback", leg, lo, hi);
      return true;
   }
   if(dir < 0 && hi_i > lo_i && px <= lo + leg * LGTipShare)
   {
      why = StringFormat("SELL at the tip of a %.2f down-leg (%.2f-%.2f) - waiting for a small bounce", leg, lo, hi);
      return true;
   }
   return false;
}

// Katta shamni quvish: BUY uning tepasida, SELL uning tubida. Hozir shakllanayotgan M5 shami (0) va
// oldingisi (1) tekshiriladi - skrinshotdagi BUY aynan shakllanayotgan $7 lik shamning tepasida
// ochilgan edi, yopilgan shamlarga qaraydigan tekshiruv uni ko'rmasdi. Narx sham ichiga qaytsa
// yoki 10 daqiqa o'tsa - o'zi ochiladi.
bool LGChasingImpulse(const int dir, string &why)
{
   why = "";
   if(!LGBlockChase) return false;
   double atr = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   if(atr <= 0.0) return false;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(px <= 0.0) return false;
   for(int i = 0; i <= 1; i++)
   {
      double o = CandleOpen(PERIOD_M5, i), c = (i == 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : CandleClose(PERIOD_M5, i);
      double h = CandleHigh(PERIOD_M5, i), l = CandleLow(PERIOD_M5, i);
      if(i == 0) { h = MathMax(h, c); l = MathMin(l, c); }
      double rng = h - l;
      if(rng <= 0.0 || rng < atr * LGChaseRangeATR) continue;
      if(dir > 0 && c > o && px >= h - rng * LGChaseTopShare)
      {
         why = StringFormat("BUY chasing the top of a %.2f bullish candle (%.2f-%.2f)", rng, l, h);
         return true;
      }
      if(dir < 0 && c < o && px <= l + rng * LGChaseTopShare)
      {
         why = StringFormat("SELL chasing the bottom of a %.2f bearish candle (%.2f-%.2f)", rng, l, h);
         return true;
      }
   }
   return false;
}

// Yangi katta impuls shamining tanasi ichida unga qarshi kirish
bool LGFreshImpulse(const int dir, string &why)
{
   why = "";
   if(!LGUseFreshImpulse) return false;
   static int    fb_bar[2] = {-100000, -100000};
   static double fb_o[2] = {0.0, 0.0}, fb_c[2] = {0.0, 0.0};
   static int    fb_age[2] = {0, 0};
   int sl = (dir > 0) ? 0 : 1;
   if(fb_bar[sl] != G_BARS_SEEN)
   {
      fb_bar[sl] = G_BARS_SEEN; fb_o[sl] = 0.0; fb_c[sl] = 0.0; fb_age[sl] = 0;
      double atr = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
      int n = MathMax(2, LGImpulseLookbackM5);
      if(atr > 0.0)
         for(int i = 1; i <= n; i++)
         {
            double o = CandleOpen(PERIOD_M5, i), c = CandleClose(PERIOD_M5, i);
            double rng = CandleHigh(PERIOD_M5, i) - CandleLow(PERIOD_M5, i);
            if(rng <= 0.0 || rng < atr * LGImpulseRangeATR || MathAbs(c - o) < rng * LGImpulseBodyShare) continue;
            if(dir > 0 && c >= o) continue;   // BUY uchun ayiq impulsi
            if(dir < 0 && c <= o) continue;   // SELL uchun buqa impulsi
            bool reclaimed = false;
            for(int k = i - 1; k >= 1; k--)
            {
               double ck = CandleClose(PERIOD_M5, k);
               if((dir > 0 && ck > o) || (dir < 0 && ck < o)) { reclaimed = true; break; }
            }
            if(!reclaimed) { fb_o[sl] = o; fb_c[sl] = c; fb_age[sl] = i; }
            break;
         }
   }
   if(fb_o[sl] <= 0.0) return false;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lo = MathMin(fb_o[sl], fb_c[sl]), hi = MathMax(fb_o[sl], fb_c[sl]);
   if(px < lo || px > hi) return false;
   why = StringFormat("%s inside the body of a %d-bar-old %s impulse (%.2f-%.2f)",
                      (dir > 0 ? "BUY" : "SELL"), fb_age[sl], (dir > 0 ? "bearish" : "bullish"), lo, hi);
   return true;
}

// ============================================================================
// BOSQICH 11: ZONA DVIGATELI
// ----------------------------------------------------------------------------
// Ilgari har daraja alohida to'siq edi: S1, S2, R1, R2 - to'rtta blocker. Endi:
//   1) YIG'ISH   - M15/M5/M1 dan swing high va low; faqat narx reaksiya bergan joylar
//   2) KLASTER   - bir-biriga yaqin darajalar bitta HUDUD (lo..hi), vaznlari qo'shiladi
//   3) ROL       - hudud narxdan yuqorida bo'lsa RESISTANCE, pastda bo'lsa SUPPORT.
//                  Rol tarixdan emas, narxning hozirgi joyidan kelib chiqadi - shuning uchun
//                  singan resistance o'z-o'zidan support bo'ladi (flip alohida qoida talab qilmaydi)
//   4) SINISH    - savdo yo'nalishida yopilish bilan o'tilgan hudud to'siq emas (M5 / 2xM1 / ushlanib turish)
//   5) DOMINANT  - har tomonda eng yaqin va vazni yetarli hudud
// Vazn: har daraja 1 ball, reaksiya >= 2 ATR bo'lsa 2 ball, M15 darajasi x1.5, M5 x1.2, M1 x1.0
//=====================================================================
// NEWS — one owner
//---------------------------------------------------------------------
// Three systems answer the same question and none of them is in charge:
//
//   EnableEconomicCalendarGuard  reads the calendar - scheduled, factual
//   EnableLiveNewsRead           reads price behaviour - inferred, guesses
//   Pack3UpdateNewsGuard         a third, from an older pack
//
// They disagree, and when they do the outcome depends on which one a particular call
// site happened to ask. The log showed it at NFP: one said news at 17:29, another said
// no at 17:30.
//
// A scheduled release is a fact. Price moving like a release is an opinion about a
// fact. So the calendar is the owner, and the live read only speaks when the calendar
// has nothing to say - which is exactly where an unscheduled move needs catching.
//=====================================================================

int      G_NEWS_STATE = 0;      // 0 none, 1 live-read only, 2 scheduled
string   G_NEWS_WHY   = "";
int      G_NEWS_BAR   = -100000;

// 0 = clear, 1 = behaving like news, 2 = a scheduled release is in its window
// The live price read is the expensive part, so it alone is cached per bar.
int NewsLiveReadState(string &why)
{
   why = "";
   if(!EnableLiveNewsRead)
      return 0;

   if(G_NEWS_BAR > G_BARS_SEEN)
      G_NEWS_BAR = -100000;   // FIX(reinit-bar-rewind)
   if(G_NEWS_BAR == G_BARS_SEEN)
   {
      why = G_NEWS_WHY;
      return G_NEWS_STATE;
   }
   G_NEWS_BAR = G_BARS_SEEN;
   G_NEWS_STATE = 0;
   G_NEWS_WHY = "";

   string d = "";
   if(NewsInProgress(d))
   {
      G_NEWS_STATE = 1;
      G_NEWS_WHY = "behaving like news: " + d;
   }
   why = G_NEWS_WHY;
   return G_NEWS_STATE;
}

// 0 = clear, 1 = behaving like news, 2 = a scheduled release is in its window
int NewsOwnerState(string &why)
{
   why = "";

   if(!EnableNewsOwner)
   {
      // Owner off: fall back to whatever the old call sites did, so turning this off
      // restores the previous behaviour exactly.
      if(EnableLiveNewsRead)
      {
         string d = "";
         if(NewsInProgress(d)) { why = d; return 1; }
      }
      return 0;
   }

   // The calendar first. A release that is on the schedule is not a matter of opinion.
   // FIX(calendar-window): read G_CAL_ACTIVE directly and on every call. Before, this went through
   // EconomicCalendarAllowsEntry(), which answers "allowed" in lot-trim mode
   // (EconomicCalendarHardBlockFirst=false) - so with hard-block off a scheduled release did not stop
   // GRID additions at all. The window itself was also frozen for a whole bar by the cache below.
   // Whether a scheduled window stops a first ENTRY is still decided by the hard-block setting, in
   // NewsOwnerBlocksEntry().
   if(EnableEconomicCalendarGuard && G_CAL_ACTIVE)
   {
      why = StringFormat("scheduled: %s (%d min)%s", G_CAL_EVENT_NAME, G_CAL_MINUTES_FROM_EVENT,
                         (G_CAL_BIG_SURPRISE ? " surprise" : ""));
      return 2;
   }

   // Nothing scheduled - now the live read matters, because an unscheduled move is
   // precisely what the calendar cannot see.
   return NewsLiveReadState(why);
}

bool NewsOwnerBlocksEntry(string &why)
{
   int st = NewsOwnerState(why);

   if(st == 2)
   {
      if(EconomicCalendarHardBlockFirst)
         return true;                             // scheduled - blocked
      // Lot-trim mode: the scheduled window alone does not stop an entry (the lot is cut by
      // EconomicCalendarLotAdjust), but price actually behaving like a release still can.
      string live_why = "";
      if(NewsLiveReadState(live_why) == 1 && NewsLiveReadBlocksEntry)
      {
         why = why + " | " + live_why;
         return true;
      }
      return false;
   }
   if(st == 1) return NewsLiveReadBlocksEntry;    // inferred - the operator decides

   return false;
}

bool NewsOwnerBlocksGrid(string &why)
{
   int st = NewsOwnerState(why);

   // Adding to a basket during a release is how a recoverable position becomes one that
   // is not, so this is stricter than the entry side.
   return (st >= 1);
}


//=====================================================================
//---------------------------------------------------------------------
// GATE REGISTRY — every refusal names itself
//---------------------------------------------------------------------
// Seventy-one places can refuse an entry. Thirty-nine sit in FirstEntryCanRun and the
// other thirty-two live inside twenty-four functions called RiskAllowsNewEntry,
// Pack3AllowsEntry, DeepTopZoneAllowsEntry and so on - each writing a reason string
// with no indication of which module produced it.
//
// So the dashboard can say an entry was refused and cannot say by what. Finding out
// meant reading the source, which is how a day went to guessing which gate was closed,
// six times, wrong each time.
//
// A gate that cannot name itself cannot be tuned, and a gate nobody can tune is one
// nobody trusts. This costs one assignment per refusal.
//=====================================================================

#define GATE_COUNT               29

#define GATE_NONE                0
#define GATE_ENGINE              1
#define GATE_ENV                 2
#define GATE_RISK                3
#define GATE_PACK3               4
#define GATE_PACK4               5
#define GATE_LICENSE             6
#define GATE_OPERATOR            7
#define GATE_SESSION             8
#define GATE_WEEKEND             9
#define GATE_HOLIDAY             10
#define GATE_NEWS                11
#define GATE_CALENDAR            12
#define GATE_SPREAD              13
#define GATE_VELOCITY            14
#define GATE_SCORE               15
#define GATE_DIRECTION           16
#define GATE_POSITIONS           17
#define GATE_COOLDOWN            18
#define GATE_RETRY               19
#define GATE_AFFORD              20
#define GATE_MARGIN              21
#define GATE_ZONE                22
#define GATE_LOCATION            23
#define GATE_REGIME              24
#define GATE_DRIFT               25
#define GATE_NOSETUP             26   // no detector opportunity and no brain fast entry
#define GATE_MBVETO              27   // Market Brain direction veto
#define GATE_MBJUDGE             28   // Market Brain entry judge said WAIT

int      G_GATE[GATE_COUNT];
int      G_GATE_LAST = GATE_NONE;
int      G_GATE_DAY  = -1;

string GateName(const int id)
{
   switch(id)
   {
      case GATE_ENGINE:    return "engineOff";
      case GATE_ENV:       return "env";
      case GATE_RISK:      return "risk";
      case GATE_PACK3:     return "pack3";
      case GATE_PACK4:     return "pack4";
      case GATE_LICENSE:   return "license";
      case GATE_OPERATOR:  return "operator";
      case GATE_SESSION:   return "session";
      case GATE_WEEKEND:   return "weekend";
      case GATE_HOLIDAY:   return "holiday";
      case GATE_NEWS:      return "news";
      case GATE_CALENDAR:  return "calendar";
      case GATE_SPREAD:    return "spread";
      case GATE_VELOCITY:  return "velocity";
      case GATE_SCORE:     return "score";
      case GATE_DIRECTION: return "noDirection";
      case GATE_POSITIONS: return "positions";
      case GATE_COOLDOWN:  return "cooldown";
      case GATE_RETRY:     return "retry";
      case GATE_AFFORD:    return "afford";
      case GATE_MARGIN:    return "margin";
      case GATE_ZONE:      return "zone";
      case GATE_LOCATION:  return "location";
      case GATE_REGIME:    return "regime";
      case GATE_DRIFT:     return "drift";
      case GATE_NOSETUP:   return "noSetup";
      case GATE_MBVETO:    return "brainVeto";
      case GATE_MBJUDGE:   return "brainWait";
   }
   return "other";
}

// Classify a refusal from the text it wrote. Crude, and the alternative - threading an
// id through seventy-one call sites - would touch every one of them to answer a question
// this answers well enough.
int GateClassify(const string why)
{
   if(StringLen(why) == 0)                         return GATE_NONE;

   if(StringFind(why, "no setup") == 0)            return GATE_NOSETUP;
   if(StringFind(why, "market brain veto") == 0)   return GATE_MBVETO;
   if(StringFind(why, "entry judge") == 0)         return GATE_MBJUDGE;

   if(StringFind(why, "better place") >= 0)        return GATE_LOCATION;
   if(StringFind(why, "score") >= 0)               return GATE_SCORE;
   if(StringFind(why, "zone") >= 0 ||
      StringFind(why, "supply") >= 0 ||
      StringFind(why, "demand") >= 0)              return GATE_ZONE;
   if(StringFind(why, "news") >= 0 ||
      StringFind(why, "release") >= 0 ||
      StringFind(why, "scheduled") >= 0)           return GATE_NEWS;
   if(StringFind(why, "calendar") >= 0)            return GATE_CALENDAR;
   if(StringFind(why, "spread") >= 0)              return GATE_SPREAD;
   if(StringFind(why, "velocity") >= 0 ||
      StringFind(why, "spike") >= 0)               return GATE_VELOCITY;
   if(StringFind(why, "cooldown") >= 0)            return GATE_COOLDOWN;
   if(StringFind(why, "position") >= 0)            return GATE_POSITIONS;
   if(StringFind(why, "retry") >= 0)               return GATE_RETRY;
   if(StringFind(why, "margin") >= 0)              return GATE_MARGIN;
   if(StringFind(why, "ladder") >= 0 ||
      StringFind(why, "afford") >= 0 ||
      StringFind(why, "budget") >= 0)              return GATE_AFFORD;
   if(StringFind(why, "session") >= 0 ||
      StringFind(why, "hour") >= 0)                return GATE_SESSION;
   if(StringFind(why, "weekend") >= 0)             return GATE_WEEKEND;
   if(StringFind(why, "holiday") >= 0)             return GATE_HOLIDAY;
   if(StringFind(why, "risk") >= 0 ||
      StringFind(why, "DD") >= 0 ||
      StringFind(why, "loss") >= 0)                return GATE_RISK;
   if(StringFind(why, "regime") >= 0)              return GATE_REGIME;
   if(StringFind(why, "drift") >= 0)               return GATE_DRIFT;
   if(StringFind(why, "direction") >= 0)           return GATE_DIRECTION;
   if(StringFind(why, "ENV") >= 0)                 return GATE_ENV;
   if(StringFind(why, "license") >= 0)             return GATE_LICENSE;
   if(StringFind(why, "Pack3") >= 0 ||
      StringFind(why, "pack3") >= 0)               return GATE_PACK3;
   if(StringFind(why, "Pack4") >= 0 ||
      StringFind(why, "pack4") >= 0)               return GATE_PACK4;
   if(StringFind(why, "false") >= 0 ||
      StringFind(why, "engine") >= 0)              return GATE_ENGINE;

   return GATE_NONE;
}

void GateRecord(const string why)
{
   if(!EnableGateRegistry) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(G_GATE_DAY != dt.day_of_year)
   {
      G_GATE_DAY = dt.day_of_year;
      for(int i = 0; i < GATE_COUNT; i++) G_GATE[i] = 0;
   }

   int id = GateClassify(why);
   if(id <= GATE_NONE || id >= GATE_COUNT) return;

   G_GATE_LAST = id;
   G_GATE[id]++;
}

// The day's refusals, busiest first. Only what actually fired.
string GateTallyText()
{
   if(!EnableGateRegistry) return "";

   int best[5];
   int bn = 0;

   for(int i = 1; i < GATE_COUNT; i++)
   {
      if(G_GATE[i] <= 0) continue;
      int pos = bn;
      while(pos > 0 && G_GATE[best[pos - 1]] < G_GATE[i])
      {
         if(pos < 5) best[pos] = best[pos - 1];
         pos--;
      }
      if(pos < 5) { best[pos] = i; if(bn < 5) bn++; }
   }

   if(bn <= 0) return "gates: nothing refused today";

   string t = "gates: ";
   for(int k = 0; k < bn; k++)
      t += StringFormat("%s %d | ", GateName(best[k]), G_GATE[best[k]]);

   return StringSubstr(t, 0, StringLen(t) - 3);
}

//---------------------------------------------------------------------
// THE QUIET ALARM — eleven gates, and none of them knows about the others
//---------------------------------------------------------------------
// Every guard added here is reasonable on its own. The location brain, the higher
// timeframes, the old level, the failed break, the news owner, the zone engine - each
// asks a fair question and each costs a little.
//
// None of them knows the others exist. Six reasonable costs in a row is a robot that
// does not trade, and it arrives without anything being wrong: no single gate is at
// fault, and the log shows six different reasons on six different bars.
//
// So this counts. Not a limit, not an automatic loosening - a robot that relaxes its own
// standards when it is bored is a robot that takes the trade it was right to refuse. It
// says how long it has been quiet and which gate has been doing it, and the decision
// about whether that is correct stays with the operator.
//---------------------------------------------------------------------

int      G_QUIET_BARS  = 0;        // bars since anything was allowed through
int      G_QUIET_LAST  = -100000;
int      G_QUIET_PEAK  = 0;        // longest quiet run today
int      G_QUIET_DAY   = -1;

void QuietTick(const bool entry_allowed)
{
   if(!EnableQuietAlarm) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(G_QUIET_DAY != dt.day_of_year)
   {
      G_QUIET_DAY = dt.day_of_year;
      G_QUIET_PEAK = 0;
   }

   if(entry_allowed || G_BASKET_ORDERS > 0)   // a basket at work is not silence
   {
      G_QUIET_BARS = 0;
      G_QUIET_LAST = G_BARS_SEEN;
      return;
   }

   // Count bars, not ticks - a thousand refused ticks on one bar is one bar of quiet.
   if(G_QUIET_LAST != G_BARS_SEEN)
   {
      G_QUIET_LAST = G_BARS_SEEN;
      G_QUIET_BARS++;
      if(G_QUIET_BARS > G_QUIET_PEAK) G_QUIET_PEAK = G_QUIET_BARS;

      if((QuietAlarmPrintOnUse && VerboseLogs) && G_QUIET_BARS == QuietAlarmBars)
         PrintFormat("[SIRUS QUIET] nothing opened for %d bars - %s has been the usual reason",
                     G_QUIET_BARS, GateName(G_GATE_LAST));
   }
}

//---------------------------------------------------------------------
// 1. TIGHTENING ON EVIDENCE
//
// The temptation is to loosen when the robot is quiet, and it is the wrong direction:
// quiet has two causes and the robot cannot tell them apart. The thresholds may be too
// strict - or the market may be in the middle of the grind that these guards exist to
// survive. Both look identical from inside, and loosening the second one is how the
// hundred-dollar fall catches the deepest basket of the move.
//
// Losing is different. A run of losses is not an opinion about what the market might be
// doing; it is what already happened. So the adjustment only goes one way: the robot can
// become more careful on evidence, and it cannot become less careful because it is bored.
//---------------------------------------------------------------------

double   G_ADAPT_EXTRA  = 0.0;     // added to the location demand
int      G_ADAPT_WINS   = 0;
int      G_ADAPT_LOSSES = 0;
string   G_ADAPT_TEXT   = "";

void AdaptRecord(const bool won)
{
   if(!EnableEvidenceTighten) return;

   if(won) G_ADAPT_WINS++;
   else    G_ADAPT_LOSSES++;

   int total = G_ADAPT_WINS + G_ADAPT_LOSSES;
   if(total < EvidenceMinTrades) return;

   double rate = (double)G_ADAPT_WINS / (double)total;

   if(rate < EvidenceBadWinRate)
   {
      // Worse than the bar - tighten a step. Capped, because a bad run is not proof that
      // every future entry is bad, and a guard that walks itself up forever ends as a
      // robot that does not trade.
      if(G_ADAPT_EXTRA < EvidenceMaxExtra)
      {
         G_ADAPT_EXTRA = MathMin(EvidenceMaxExtra, G_ADAPT_EXTRA + EvidenceStep);

         if((EvidenceTightenPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS ADAPT] %d of %d won - entries now need %.2f more of the leg",
                        G_ADAPT_WINS, total, G_ADAPT_EXTRA);
      }
   }
   else if(rate >= EvidenceGoodWinRate && G_ADAPT_EXTRA > 0.0)
   {
      // Winning again. The extra demand is released - not loosened past normal, only back
      // to where it started, because the baseline was never the thing that was wrong.
      G_ADAPT_EXTRA = MathMax(0.0, G_ADAPT_EXTRA - EvidenceStep);

      if((EvidenceTightenPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS ADAPT] %d of %d won - extra demand down to %.2f",
                     G_ADAPT_WINS, total, G_ADAPT_EXTRA);
   }

   // Roll the window so the measurement follows recent trading rather than all of it.
   if(total >= EvidenceWindow)
   {
      G_ADAPT_WINS   = (int)MathRound(G_ADAPT_WINS * 0.5);
      G_ADAPT_LOSSES = (int)MathRound(G_ADAPT_LOSSES * 0.5);
   }

   G_ADAPT_TEXT = StringFormat("%d/%d won, +%.2f demand",
                               G_ADAPT_WINS, total, G_ADAPT_EXTRA);
}

string AdaptText()
{
   if(!EnableEvidenceTighten || StringLen(G_ADAPT_TEXT) == 0) return "";
   return "adapt: " + G_ADAPT_TEXT;
}

//---------------------------------------------------------------------
// 2. WHAT THE SILENCE IS MADE OF
//
// Forty bars of quiet from the news guard is a closed market and nothing to fix. Forty
// bars from the location brain is a threshold worth looking at. The bar count alone
// cannot tell them apart, and that is the number everyone reads.
//---------------------------------------------------------------------
string QuietCause()
{
   if(G_QUIET_BARS < QuietAlarmBars) return "";

   int total = 0, top = 0, top_id = 0;
   for(int i = 1; i < GATE_COUNT; i++)
   {
      total += G_GATE[i];
      if(G_GATE[i] > top) { top = G_GATE[i]; top_id = i; }
   }
   if(total <= 0 || top_id == 0) return "";

   double share = (double)top / (double)total;

   // One gate doing nearly all of it is a threshold. Several sharing it is the market.
   if(share >= QuietSingleCauseShare)
      return StringFormat("%s alone, %.0f%% of refusals", GateName(top_id), share * 100.0);

   return StringFormat("spread across gates, %s leads at %.0f%%",
                       GateName(top_id), share * 100.0);
}

string QuietText()
{
   if(!EnableQuietAlarm) return "";

   if(G_QUIET_BARS < QuietAlarmBars)
      return StringFormat("quiet: %d bars (worst today %d)", G_QUIET_BARS, G_QUIET_PEAK);

   string cause = QuietCause();
   return StringFormat("QUIET %d BARS - %s  (worst today %d)",
                       G_QUIET_BARS,
                       (StringLen(cause) > 0 ? cause : GateName(G_GATE_LAST)),
                       G_QUIET_PEAK);
}

//=====================================================================
// THE SAFETY VALVE — the robot can always get back to what worked
//---------------------------------------------------------------------
// Fourteen guards were added to a robot that traded three hundred times a day. Each is
// reasonable, each costs a little, and none of them knows the others exist. Six
// reasonable costs in a row is a robot that does not trade, and it arrives with nothing
// visibly wrong - six different reasons on six different bars.
//
// Loosening on boredom is the wrong answer: quiet has two causes and the robot cannot
// tell a bad threshold from a market it should be sitting out.
//
// But there is a third thing it CAN tell, and it is the one that matters here. The
// baseline worked. If silence is coming from a guard that did not exist last week, that
// is not the market - that is the addition, and the robot can simply stop using it for a
// while.
//
// So this never makes the robot looser than it was before any of this was added. It only
// ever returns it to that, one guard at a time, and only the guard the counters say is
// responsible.
//=====================================================================

#define VALVE_NONE               0
#define VALVE_LOCATION           1
#define VALVE_HTF                2
#define VALVE_OLDLEVEL           3
#define VALVE_FAILEDBREAK        4
#define VALVE_SCENARIO           5
#define VALVE_CLARITY            6
#define VALVE_COUNT              7

int      G_VALVE_OFF   = VALVE_NONE;   // which addition is currently stood down
int      G_VALVE_UNTIL = 0;            // bar it comes back
int      G_VALVE_USES  = 0;            // times today
int      G_VALVE_DAY   = -1;

string ValveName(const int v)
{
   switch(v)
   {
      case VALVE_LOCATION:    return "location brain";
      case VALVE_HTF:         return "htf bias";
      case VALVE_OLDLEVEL:    return "old level";
      case VALVE_FAILEDBREAK: return "failed break";
      case VALVE_SCENARIO:    return "scenario";
      case VALVE_CLARITY:     return "direction clarity";
   }
   return "none";
}

// Which addition does a gate id belong to? Only the ones added here can be stood down -
// risk, news, session, spread and the rest were working before and are not in question.
int ValveForGate(const int gate_id)
{
   switch(gate_id)
   {
      case GATE_LOCATION: return VALVE_LOCATION;
      case GATE_REGIME:   return VALVE_HTF;
      case GATE_ZONE:     return VALVE_OLDLEVEL;
   }
   return VALVE_NONE;
}

// Is this addition currently stood down?
bool ValveIsOff(const int v)
{
   if(!EnableSafetyValve) return false;
   if(G_VALVE_OFF != v) return false;

   if(G_BARS_SEEN >= G_VALVE_UNTIL)
   {
      // Its turn is over. Back on, and if the silence continues the next check will pick
      // whichever guard is responsible now.
      if((SafetyValvePrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS VALVE] %s back on", ValveName(G_VALVE_OFF));
      G_VALVE_OFF = VALVE_NONE;
      return false;
    }

   return true;
}

// Called once a bar. Decides whether an addition should stand down.
void SafetyValveCheck()
{
   if(!EnableSafetyValve) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(G_VALVE_DAY != dt.day_of_year)
   {
      G_VALVE_DAY = dt.day_of_year;
      G_VALVE_USES = 0;
   }

   // Already standing one down - let it run its course.
   if(G_VALVE_OFF != VALVE_NONE) return;

   if(G_QUIET_BARS < SafetyValveBars) return;
   if(SafetyValveMaxPerDay > 0 && G_VALVE_USES >= SafetyValveMaxPerDay) return;

   // Which gate has been doing it, and does it belong to something added here? If the
   // silence is coming from risk, news or the session, there is nothing to stand down -
   // those were right before and they are right now.
   int top = 0, top_id = 0, total = 0;
   for(int i = 1; i < GATE_COUNT; i++)
   {
      total += G_GATE[i];
      if(G_GATE[i] > top) { top = G_GATE[i]; top_id = i; }
   }
   if(total <= 0 || top_id == 0) return;

   double share = (double)top / (double)total;
   if(share < SafetyValveMinShare) return;     // spread across gates - that is the market

   int v = ValveForGate(top_id);
   if(v == VALVE_NONE) return;                 // not one of ours

   G_VALVE_OFF   = v;
   G_VALVE_UNTIL = G_BARS_SEEN + MathMax(5, SafetyValveOffBars);
   G_VALVE_USES++;

   PrintFormat("[SIRUS VALVE] %d bars quiet and %.0f%% of refusals were %s - "
               "standing it down for %d bars (%d of %d today)",
               G_QUIET_BARS, share * 100.0, ValveName(v),
               SafetyValveOffBars, G_VALVE_USES, SafetyValveMaxPerDay);
}

string ValveText()
{
   if(!EnableSafetyValve || G_VALVE_OFF == VALVE_NONE)
   {
      if(G_VALVE_USES > 0)
         return StringFormat("valve: idle (%d uses today)", G_VALVE_USES);
      return "";
   }

   return StringFormat("VALVE: %s off for %d more bars",
                       ValveName(G_VALVE_OFF), G_VALVE_UNTIL - G_BARS_SEEN);
}




//=====================================================================
// THROUGH IT, BUT NOT PAST IT
//---------------------------------------------------------------------
// An impulse drives down through support and the bar closes back above it. The low went
// through; the close did not.
//
// Every reading that works on closes sees a level that held. Every reading that works on
// extremes sees one that broke. Both are looking at the same bar, and the one that is
// right is the close - the break was the market reaching under the level for the stops
// sitting there and then declining to stay.
//
// The EA sells into that, because something registered a break and the continuation
// detectors fired on it. And it is the opposite: support that has just been tested and
// held is the strongest it will ever be, because everyone who sold the break is now
// trapped underneath it.
//=====================================================================

int      G_SWEEP_DIR  = 0;        // which way the sweep went: -1 under support, +1 over resistance
double   G_SWEEP_LVL  = 0.0;
double   G_SWEEP_DEPTH = 0.0;     // how far past, in ATR
int      G_SWEEP_BAR  = -100000;
string   G_SWEEP_TEXT = "";

//---------------------------------------------------------------------
// Did the last few bars reach through a level and close back? Returns the direction of
// the sweep, or zero.
//---------------------------------------------------------------------
int FailedBreakRead(string &detail)
{
   detail = "";
   if(!EnableFailedBreakGuard || _Point <= 0.0) return 0;

   if(G_SWEEP_BAR == G_BARS_SEEN)
   {
      detail = G_SWEEP_TEXT;
      return G_SWEEP_DIR;
   }
   G_SWEEP_BAR = G_BARS_SEEN;
   G_SWEEP_DIR = 0;
   G_SWEEP_LVL = 0.0;
   G_SWEEP_DEPTH = 0.0;
   G_SWEEP_TEXT = "";

   ENUM_TIMEFRAMES tf = SweepReadTF;
   double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
   if(atr <= 0.0) return 0;

   int look = MathMax(2, FailedBreakBars);

   for(int k = 1; k <= look; k++)
   {
      double o = CandleOpen(tf, k), c = CandleClose(tf, k);
      double h = CandleHigh(tf, k), l = CandleLow(tf, k);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0) continue;

      // The level it reached through: the swing extreme just before this bar.
      double sup = 0.0, res = 0.0;
      for(int j = k + 1; j <= k + FailedBreakLevelLook; j++)
      {
         double jh = CandleHigh(tf, j), jl = CandleLow(tf, j);
         if(jh <= 0.0 || jl <= 0.0) continue;
         if(sup <= 0.0 || jl < sup) sup = jl;
         if(res <= 0.0 || jh > res) res = jh;
      }
      if(sup <= 0.0 || res <= 0.0) continue;

      // Under support and back above it.
      if(l < sup && c > sup)
      {
         double depth = (sup - l) / atr;
         if(depth >= FailedBreakMinDepthATR)
         {
            G_SWEEP_DIR = -1;
            G_SWEEP_LVL = sup;
            G_SWEEP_DEPTH = depth;
            G_SWEEP_TEXT = StringFormat("support %.2f reached through by %.1f ATR and held",
                                        sup, depth);
            detail = G_SWEEP_TEXT;
            return -1;
         }
      }

      // Over resistance and back below it.
      if(h > res && c < res)
      {
         double depth = (h - res) / atr;
         if(depth >= FailedBreakMinDepthATR)
         {
            G_SWEEP_DIR = 1;
            G_SWEEP_LVL = res;
            G_SWEEP_DEPTH = depth;
            G_SWEEP_TEXT = StringFormat("resistance %.2f reached through by %.1f ATR and held",
                                        res, depth);
            detail = G_SWEEP_TEXT;
            return 1;
         }
      }
   }

   return 0;
}

//---------------------------------------------------------------------
// What it costs to trade in the direction of a sweep that failed. Selling under support
// that just held is the trade everyone trapped under it already made.
//---------------------------------------------------------------------
int FailedBreakCost(const int dir, string &detail)
{
   detail = "";
   if(!EnableFailedBreakGuard || dir == 0) return 0;

   string d = "";
   int sweep = FailedBreakRead(d);
   if(sweep == 0 || sweep != dir) return 0;

   // Deeper sweeps cost more - a bar that went well past and still closed back has shown
   // more about who is defending the level than one that barely poked through.
   double t = MathMin(1.0, G_SWEEP_DEPTH / MathMax(0.1, FailedBreakFullDepthATR));
   int cost = (int)MathRound(t * (double)FailedBreakScoreCost);
   if(cost <= 0) return 0;

   detail = d;
   return cost;
}

string FailedBreakText()
{
   if(!EnableFailedBreakGuard || G_SWEEP_DIR == 0) return "";
   return "failed break: " + G_SWEEP_TEXT;
}


//=====================================================================
// THE LEVEL FROM TWO MONTHS AGO
//---------------------------------------------------------------------
// Price pushes through the high next to it, the breakout detector fires, and then it
// runs into a level from six weeks back and collapses. The move was never a breakout -
// it was the market collecting the stops sitting above that recent high on its way to
// something it actually cared about.
//
// The zone engine could not see it. It builds from forty-eight bars of M30 and H1 -
// about two days - which is the right window for the zones price is reacting to now,
// and blind to the one that ends the move.
//
// ZoneMap already holds four months of levels and is read in a hundred places, none of
// them the location check. So nothing had to be built: the long history was there and
// the entry gate was not asking it.
//
// What is asked is narrow, because a four-month level near every price would refuse
// everything: only levels that are OLD, have been TOUCHED more than once, and sit
// directly in the path of a breakout. That is the shape of the thing that stops moves.
//=====================================================================

double   G_OLDLVL_PRICE = 0.0;
double   G_SCEN_LAST_APPROACH = 0.0;   // ATR price travelled to reach the level - the other half of what decides a bounce
double   G_APPR_FAR  = 0.0;            // the extreme price came from - closed candles, cached per bar
int      G_APPR_DIR  = 0;
int      G_APPR_BAR  = -100000;
double   G_OLDLVL_AGE   = 0.0;     // days
int      G_OLDLVL_TOUCH = 0;
string   G_OLDLVL_TEXT  = "";
int      G_OLDLVL_BAR   = -100000;

//---------------------------------------------------------------------
// Is there an old, proven level in front of this direction? Returns its price, or zero.
//---------------------------------------------------------------------
double OldLevelAhead(const int dir, double &age_days, int &touches, string &detail)
{
   age_days = 0.0;
   touches  = 0;
   detail   = "";

   if(!EnableOldLevelGuard || dir == 0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0) return 0.0;

   double reach = ScaleAdjustedPoints(MathMax(1, OldLevelReachPoints)) * _Point;

   // Walk the slow timeframes for extremes that price has respected and left behind.
   // Four scales, not two. A level that stopped price six weeks ago may have been drawn
   // on H1 or M30 - the daily chart only shows the ones big enough to leave a daily
   // extreme, and the ones that end intraday moves are often smaller than that.
   //
   // Looking further back on the faster timeframes is the point: three hundred H1 bars is
   // nearly two months, and that is where the level sits that a two-day zone engine
   // cannot see.
   ENUM_TIMEFRAMES tfs[4];
   int looks[4];
   tfs[0] = PERIOD_D1;  looks[0] = MathMax(20, OldLevelLookD1);
   tfs[1] = PERIOD_H4;  looks[1] = MathMax(30, OldLevelLookH4);
   tfs[2] = PERIOD_H1;  looks[2] = MathMax(60, OldLevelLookH1);
   tfs[3] = PERIOD_M30; looks[3] = MathMax(60, OldLevelLookM30);

   double best = 0.0;
   int    best_touch = 0;
   double best_age = 0.0;

   for(int t = 0; t < 4; t++)
   {
      double tf_mins = (tfs[t] == PERIOD_D1) ? 1440.0
                     : ((tfs[t] == PERIOD_H4) ? 240.0
                     : ((tfs[t] == PERIOD_H1) ? 60.0 : 30.0));

      for(int k = MathMax(2, OldLevelMinAgeBars); k <= looks[t]; k++)
      {
         double h = CandleHigh(tfs[t], k), l = CandleLow(tfs[t], k);
         if(h <= 0.0 || l <= 0.0) continue;

         // A BUY runs into highs above; a SELL into lows below.
         double lvl = (dir > 0) ? h : l;
         if(dir > 0 && lvl <= mid) continue;
         if(dir < 0 && lvl >= mid) continue;
         if(MathAbs(lvl - mid) > reach) continue;

         // It has to be a swing, not just a bar that happened to reach furthest.
         bool swing = true;
         for(int dd = 1; dd <= 2 && swing; dd++)
         {
            if(dir > 0)
            {
               if(CandleHigh(tfs[t], k - dd) > h || CandleHigh(tfs[t], k + dd) > h) swing = false;
            }
            else
            {
               if(CandleLow(tfs[t], k - dd) < l || CandleLow(tfs[t], k + dd) < l) swing = false;
            }
         }
         if(!swing) continue;

         // How many times price has come back to it since. Once is a high; three times is
         // a level the market recognises, and that is what ends a run.
         int tcount = 0;
         double tol = ScaleAdjustedPoints(MathMax(1, OldLevelTouchTolerance)) * _Point;
         for(int j = 1; j < k; j++)
         {
            double jh = CandleHigh(tfs[t], j), jl = CandleLow(tfs[t], j);
            if(jh <= 0.0 || jl <= 0.0) continue;
            if(jh >= lvl - tol && jl <= lvl + tol) tcount++;
         }

         if(tcount < OldLevelMinTouches) continue;

         // The nearest one wins - it is the one price meets first.
         if(best <= 0.0 || MathAbs(lvl - mid) < MathAbs(best - mid))
         {
            best = lvl;
            best_touch = tcount;
            best_age = (double)k * tf_mins / 1440.0;
         }
      }
   }

   if(best <= 0.0) return 0.0;

   age_days = best_age;
   touches  = best_touch;
   detail   = StringFormat("%.2f - %.0f days old, touched %d", best, best_age, best_touch);

   return best;
}

//---------------------------------------------------------------------
// Cached per bar. The levels come from closed daily and H4 candles; only the distance
// to them moves within a bar, and that is recomputed where it is used.
//---------------------------------------------------------------------
void OldLevelScan(const int dir)
{
   if(!EnableOldLevelGuard) return;
   if(G_OLDLVL_BAR == G_BARS_SEEN) return;
   G_OLDLVL_BAR = G_BARS_SEEN;

   string d = "";
   double age = 0.0;
   int tc = 0;
   G_OLDLVL_PRICE = OldLevelAhead(dir, age, tc, d);
   G_OLDLVL_AGE   = age;
   G_OLDLVL_TOUCH = tc;
   G_OLDLVL_TEXT  = d;
}

//---------------------------------------------------------------------
// What a breakout into an old level costs. A pullback or a reversal setup pays nothing -
// those are not trying to go through it. A continuation setup is.
//---------------------------------------------------------------------
int OldLevelCost(const int dir, string &detail)
{
   detail = "";
   if(!EnableOldLevelGuard || dir == 0) return 0;

   OldLevelScan(dir);
   if(G_OLDLVL_PRICE <= 0.0) return 0;

   // Only continuation. A reversal setup heading into an old level is trading TOWARD the
   // thing that will stop price - which is the trade, not a problem with it.
   if(OldLevelOnlyBreakouts && IsReversalOpportunityType(G_OPP_TYPE))
      return 0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0) return 0;

   double gap_pts = MathAbs(G_OLDLVL_PRICE - mid) / _Point;
   double reach   = ScaleAdjustedPoints(MathMax(1, OldLevelReachPoints));

   // Closer costs more, and so does a level with more history behind it.
   double near_t  = 1.0 - MathMin(1.0, gap_pts / MathMax(1.0, reach));
   double touch_t = MathMin(1.0, (double)G_OLDLVL_TOUCH / MathMax(1.0, (double)OldLevelFullTouches));

   // And how far price has already come to arrive here. A grind of a hundred dollars that
   // ends at a level is a different thing from a ten-dollar move that reaches one: the
   // first has spent its sellers getting there, and when it turns it turns hard - which is
   // the move that catches a robot still selling every pullback on the way down.
   //
   // The grind is what makes this dangerous, and it is invisible to anything reading a
   // single leg, because the grind is made of many legs each of which looked ordinary.
   double travel_t = 0.0;
   if(EnableApproachTravel)
   {
      double atr_d = ATRPointsManual(ApproachTravelTF, ATRPeriod, 1) * _Point;
      if(atr_d > 0.0)
      {
         // Cached per bar and direction. The far extreme comes from closed candles and cannot move
         // within a bar - only the distance from it to current price can, and that is arithmetic.
         // Without this, every scored entry walks ninety-six bars, which on a robot taking three
         // hundred trades a day is the difference between fast and not.
         if(G_APPR_BAR != G_BARS_SEEN || G_APPR_DIR != dir)
         {
            G_APPR_BAR = G_BARS_SEEN;
            G_APPR_DIR = dir;

            int look = MathMax(10, ApproachTravelBars);
            double far_c = (dir > 0) ? CandleLow(ApproachTravelTF, 1)
                                     : CandleHigh(ApproachTravelTF, 1);

            for(int k = 2; k <= look; k++)
            {
               double h = CandleHigh(ApproachTravelTF, k), l = CandleLow(ApproachTravelTF, k);
               if(h <= 0.0 || l <= 0.0) continue;
               if(dir > 0) { if(l < far_c) far_c = l; }    // a BUY came up from somewhere
               else        { if(h > far_c) far_c = h; }    // a SELL came down from somewhere
            }
            G_APPR_FAR = far_c;
         }

         double far = G_APPR_FAR;

         if(far > 0.0)
         {
            double came = MathAbs(mid - far) / atr_d;
            travel_t = MathMin(1.0, MathMax(0.0,
                       (came - ApproachTravelFromATR) /
                       MathMax(0.1, ApproachTravelFullATR - ApproachTravelFromATR)));

            G_SCEN_LAST_APPROACH = came;

            if(travel_t > 0.0)
               G_OLDLVL_TEXT += StringFormat(", after %.0f ATR of approach", came);
         }
      }
   }

   // Travel raises the cost rather than setting it: a long approach to nothing is just a
   // trend, and a level with no approach behind it is still a level.
   double weight = touch_t * (1.0 + travel_t * ApproachTravelWeight);

   int cost = (int)MathRound(near_t * weight * (double)OldLevelScoreCost);
   if(cost <= 0) return 0;

   detail = StringFormat("%s %s ahead at %.0f pts",
                         (dir > 0 ? "resistance" : "support"), G_OLDLVL_TEXT, gap_pts);
   return cost;
}

string OldLevelText()
{
   if(!EnableOldLevelGuard || G_OLDLVL_PRICE <= 0.0) return "";
   return "old level: " + G_OLDLVL_TEXT;
}

//=====================================================================
// HOW FAR DOES A BOUNCE LIKE THIS ONE USUALLY GO
//---------------------------------------------------------------------
// The target here is small - $2.50, or a quarter of that on rebate - and smaller than
// any reaction worth the name. So the question is not whether a bounce can reach the
// target. It almost always can.
//
// The question is whether it reaches it BEFORE the basket needs rescuing. A reaction of
// half an ATR touches the target and leaves nothing behind it; the next rung opens into
// a move that has already finished, and the hundred-dollar grind is a hundred of those
// in a row.
//
// So this measures what reactions at a given kind of level have actually done. Not a
// forecast - a record. Levels are filed by what distinguishes them: how many touches,
// how old, how far price travelled to reach them. When one reacts, the file says what
// the last ones did.
//
// It says nothing for the first few weeks, and that is correct. Ten samples is noise.
//=====================================================================

#define SCEN_BUCKETS             9      // 3 touch-classes x 3 approach-classes

double   G_SCEN_SUM[SCEN_BUCKETS];      // total travel recorded, in ATR
int      G_SCEN_N[SCEN_BUCKETS];        // samples
double   G_SCEN_PENDING_LVL   = 0.0;    // a reaction being measured right now
int      G_SCEN_PENDING_DIR   = 0;
int      G_SCEN_PENDING_BUCKET = -1;
double   G_SCEN_PENDING_FROM  = 0.0;
int      G_SCEN_PENDING_BAR   = 0;
double   G_SCEN_PROJ          = 0.0;    // what the file says for the level in front of us
int      G_SCEN_PROJ_N        = 0;
string   G_SCEN_TEXT          = "";

string ScenKey(const int bucket)
{
   return StringFormat("NAVIUS_SCEN_%s_%d_%d", _Symbol, MagicNumber, bucket);
}

// Which file a level belongs in. Touches say how well known it is; approach says how
// much of the move has already been spent getting here, and those two decide most of
// what a bounce does.
int ScenBucket(const int touches, const double approach_atr)
{
   int t = (touches >= 4) ? 2 : ((touches >= 2) ? 1 : 0);
   int a = (approach_atr >= ScenApproachHigh) ? 2
         : ((approach_atr >= ScenApproachLow) ? 1 : 0);
   return t * 3 + a;
}

void ScenarioRestore()
{
   if(!EnableScenario || !PersistScenario) return;

   for(int b = 0; b < SCEN_BUCKETS; b++)
   {
      string k = ScenKey(b);
      if(!GlobalVariableCheck(k)) continue;

      // Stored as sum and count packed into two variables.
      G_SCEN_SUM[b] = GlobalVariableGet(k);
      string kn = k + "_N";
      G_SCEN_N[b] = GlobalVariableCheck(kn) ? (int)GlobalVariableGet(kn) : 0;
   }

   int total = 0;
   for(int b = 0; b < SCEN_BUCKETS; b++) total += G_SCEN_N[b];

   if(total > 0 && (ScenRecordPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS SCENARIO] %d reactions recovered", total);
}

void ScenarioStore(const int bucket)
{
   if(!EnableScenario || !PersistScenario) return;
   if(bucket < 0 || bucket >= SCEN_BUCKETS) return;

   GlobalVariableSet(ScenKey(bucket), G_SCEN_SUM[bucket]);
   GlobalVariableSet(ScenKey(bucket) + "_N", (double)G_SCEN_N[bucket]);
}

//---------------------------------------------------------------------
// Watch a reaction from start to finish and file what it did. Called once a bar.
//---------------------------------------------------------------------
void ScenarioTrack()
{
   if(!EnableScenario) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) return;

   // --- finish one that is running ------------------------------------
   if(G_SCEN_PENDING_BUCKET >= 0)
   {
      double atr = ATRPointsManual(ScenarioTF, ATRPeriod, 1) * _Point;
      if(atr <= 0.0) return;

      double moved = (G_SCEN_PENDING_DIR > 0) ? (bid - G_SCEN_PENDING_FROM)
                                              : (G_SCEN_PENDING_FROM - bid);
      double travel = moved / atr;

      bool done = false;

      // It came back through the level: the reaction is over and that is what it managed.
      if(travel < 0.0) done = true;

      // Or it has run long enough that the number has stopped being about the bounce.
      if((G_BARS_SEEN - G_SCEN_PENDING_BAR) >= ScenarioMaxBars) done = true;

      if(done)
      {
         double recorded = MathMax(0.0, travel);
         int b = G_SCEN_PENDING_BUCKET;

         G_SCEN_SUM[b] += recorded;
         G_SCEN_N[b]++;

         // Halve the file when it gets long, so it follows recent behaviour rather than
         // averaging a market that has since changed.
         if(G_SCEN_N[b] >= ScenarioWindow)
         {
            G_SCEN_SUM[b] *= 0.5;
            G_SCEN_N[b] = (int)MathRound(G_SCEN_N[b] * 0.5);
         }

         ScenarioStore(b);

         if((ScenRecordPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS SCENARIO] reaction at %.2f went %.1f ATR - bucket %d now averages %.1f over %d",
                        G_SCEN_PENDING_LVL, recorded, b,
                        G_SCEN_SUM[b] / MathMax(1, G_SCEN_N[b]), G_SCEN_N[b]);

         G_SCEN_PENDING_BUCKET = -1;
      }
      return;      // only one at a time - overlapping reactions measure each other
   }

   // --- start one -----------------------------------------------------
   // A level is reacting when price has just been at it and has turned away.
   if(G_OLDLVL_PRICE <= 0.0) return;

   double tol = ScaleAdjustedPoints(MathMax(1, ScenarioTouchTolerance)) * _Point;
   if(MathAbs(bid - G_OLDLVL_PRICE) > tol) return;

   int dir = (bid > G_OLDLVL_PRICE) ? 1 : -1;

   G_SCEN_PENDING_LVL    = G_OLDLVL_PRICE;
   G_SCEN_PENDING_DIR    = dir;
   G_SCEN_PENDING_FROM   = bid;
   G_SCEN_PENDING_BAR    = G_BARS_SEEN;
   G_SCEN_PENDING_BUCKET = ScenBucket(G_OLDLVL_TOUCH, G_SCEN_LAST_APPROACH);
}

//---------------------------------------------------------------------
// What the file says about the level in front of this direction. Returns ATR, and the
// sample count through its out parameter - a projection from four samples is not a
// projection.
//---------------------------------------------------------------------
double ScenarioProjection(const int dir, int &samples)
{
   samples = 0;
   G_SCEN_PROJ = 0.0;
   G_SCEN_PROJ_N = 0;
   G_SCEN_TEXT = "";

   if(!EnableScenario || dir == 0) return 0.0;
   if(G_OLDLVL_PRICE <= 0.0) return 0.0;

   int b = ScenBucket(G_OLDLVL_TOUCH, G_SCEN_LAST_APPROACH);
   if(b < 0 || b >= SCEN_BUCKETS) return 0.0;
   if(G_SCEN_N[b] < ScenarioMinSamples) return 0.0;

   G_SCEN_PROJ   = G_SCEN_SUM[b] / (double)G_SCEN_N[b];
   G_SCEN_PROJ_N = G_SCEN_N[b];
   samples       = G_SCEN_N[b];

   G_SCEN_TEXT = StringFormat("%.1f ATR expected (%d samples)", G_SCEN_PROJ, G_SCEN_PROJ_N);
   return G_SCEN_PROJ;
}

string ScenarioText()
{
   if(!EnableScenario || StringLen(G_SCEN_TEXT) == 0) return "";
   return "scenario: " + G_SCEN_TEXT;
}




//=====================================================================
// HIGHER TIMEFRAME — a vote, not a veto
//---------------------------------------------------------------------
// Fifty-six of the setup detectors read M15 or M5. Fourteen read H1 or above. That is
// the right balance for a robot taking three hundred trades a day - the daily chart does
// not produce three hundred opportunities - and it is also why a BUY can be taken on an
// M15 pullback while the daily has been falling for a week.
//
// The usual fix is to refuse those trades, and it is the wrong fix: it would cut the
// trade count to a fraction and the robot would stop being what it is.
//
// So the higher timeframes do not get a veto. They raise the price of admission. A setup
// going against a strong daily trend has to be better than one going with it - better
// score, better position in its leg - and most marginal ones will not clear the bar while
// the good ones still do.
//
// Deliberately only the extremes. A daily drifting sideways says nothing and changes
// nothing; a daily that has run hard says plenty.
//=====================================================================

int      G_HTF_DIR     = 0;        // what the larger timeframes are doing
double   G_HTF_FORCE   = 0.0;      // how convincingly, 0..1
string   G_HTF_TEXT    = "";
int      G_HTF_BAR     = -100000;

//---------------------------------------------------------------------
// Direction and conviction from D1 and H4 together. Both are read the same way: net
// travel over a window, measured against how far price walked to get there. A market
// that covered six dollars in a straight line is trending; one that covered six dollars
// wandering is not, and their closes look identical.
//---------------------------------------------------------------------
void HTFBiasScan()
{
   if(!EnableHTFBias) return;
   if(G_HTF_BAR == G_BARS_SEEN) return;
   G_HTF_BAR = G_BARS_SEEN;

   G_HTF_DIR = 0;
   G_HTF_FORCE = 0.0;
   G_HTF_TEXT = "";

   double score = 0.0;
   int    dir_sum = 0;
   string parts = "";

   ENUM_TIMEFRAMES tfs[2];
   int looks[2];
   double weights[2];
   tfs[0] = PERIOD_D1; looks[0] = HTFLookD1; weights[0] = HTFWeightD1;
   tfs[1] = PERIOD_H4; looks[1] = HTFLookH4; weights[1] = HTFWeightH4;

   for(int t = 0; t < 2; t++)
   {
      int look = MathMax(5, looks[t]);

      double c_now  = CandleClose(tfs[t], 1);
      double c_then = CandleClose(tfs[t], look);
      if(c_now <= 0.0 || c_then <= 0.0) continue;

      double net = MathAbs(c_now - c_then);
      double walked = 0.0;
      for(int k = look; k >= 1; k--)
      {
         double h = CandleHigh(tfs[t], k), l = CandleLow(tfs[t], k);
         if(h > 0.0 && l > 0.0) walked += (h - l);
      }
      if(walked <= 0.0) continue;

      double atr = ATRPointsManual(tfs[t], ATRPeriod, 1) * _Point;
      if(atr <= 0.0) continue;

      double size = net / atr;                 // how far, in its own terms
      double eff  = net / walked;              // how directly it got there

      if(size < HTFMinTravelATR || eff < HTFMinEfficiency) continue;

      int d = (c_now > c_then) ? 1 : -1;
      dir_sum += d;

      // Conviction grows with both, and neither alone is enough.
      double conv = MathMin(1.0, (size / MathMax(0.1, HTFFullTravelATR))) * eff;
      score += conv * weights[t] * d;

      parts += StringFormat("%s %.1fATR %.0f%%; ",
                            (tfs[t] == PERIOD_D1 ? "D1" : "H4"), size, eff * 100.0);
   }

   if(MathAbs(score) < 0.0001) return;

   // Both scales must at least agree on sign - one of them running while the other goes
   // the other way is not a trend, it is a disagreement.
   if(HTFRequireAgreement && dir_sum == 0) return;

   G_HTF_DIR   = (score > 0.0) ? 1 : -1;
   G_HTF_FORCE = MathMin(1.0, MathAbs(score));
   G_HTF_TEXT  = StringFormat("%s %.0f%%  %s",
                              (G_HTF_DIR > 0 ? "up" : "down"), G_HTF_FORCE * 100.0, parts);
}

//---------------------------------------------------------------------
// What this direction has to pay. Returns extra score required, and raises the location
// demand through its out parameter. Zero when the higher timeframes have nothing to say
// or are already on this side.
//---------------------------------------------------------------------
int HTFAgainstCost(const int dir, double &extra_location, string &detail)
{
   extra_location = 0.0;
   detail = "";

   if(!EnableHTFBias || dir == 0) return 0;

   HTFBiasScan();

   if(G_HTF_DIR == 0) return 0;
   if(G_HTF_FORCE < HTFMinForceToCount) return 0;

   if(G_HTF_DIR == dir)
   {
      // With the larger trend. Nothing is demanded - and nothing is given either, because
      // the score already rewards alignment in a dozen places and paying twice for one
      // fact is how a hundred and thirty objections became a robot that would not trade.
      detail = "with " + G_HTF_TEXT;
      return 0;
   }

   // Against it. The cost scales with conviction, so a marginal daily costs almost
   // nothing and a hard one costs real score.
   double t = MathMin(1.0, (G_HTF_FORCE - HTFMinForceToCount) /
                           MathMax(0.01, 1.0 - HTFMinForceToCount));

   extra_location = t * HTFAgainstLocationExtra;
   int extra_score = (int)MathRound(t * (double)HTFAgainstScoreExtra);

   detail = StringFormat("against %s - wants +%d score, +%.2f location",
                         G_HTF_TEXT, extra_score, extra_location);
   return extra_score;
}

string HTFBiasText()
{
   if(!EnableHTFBias || G_HTF_DIR == 0) return "";
   return "htf: " + G_HTF_TEXT;
}


//=====================================================================
// LOCATION BRAIN — the last word before an entry opens
//---------------------------------------------------------------------
// The zone engine answers "is there a level in the way". That is a question about
// price, and it is not the question that cost the account two stops.
//
// A SELL at the bottom of a four-dollar fall is wrong even where there is no level
// anywhere near it. Price turns there because the move is stretched, not because it
// met something. The engine had nothing to say about that, because nothing was asking
// WHEN - only WHERE.
//
// So: one question, asked last, after every other gate has already passed.
//
//      "is this a good place for this direction, right now?"
//
// Three readings answer it. All three are cheap - two array reads and a comparison -
// and none of them scans anything the EA was not already reading.
//
//   1. Position in the leg. Selling needs to be near the top of the swing it is
//      joining, buying near the bottom. That is the same requirement for a
//      continuation trade and a reversal trade, which is why one rule covers both.
//
//   2. Stretch. A leg that has run six ATR without a pause is where pullbacks start,
//      not where moves continue. The deeper the stretch, the better the entry price
//      has to be.
//
//   3. The last stop. Taking the same direction again after a stop, at a worse price
//      than the one that just failed, is the mistake repeating itself. The second
//      entry has to be better than the first.
//
// Nothing here refuses a setup. It holds it, and the arming engine releases it when
// price comes to a price worth paying. The trade is not lost - it is bought cheaper.
//=====================================================================


double   G_LB_POS      = 0.5;     // 0 at the leg low, 1 at the leg high
double   G_LB_HI       = 0.0;
double   G_LB_LO       = 0.0;
int      G_LB_DIR      = 0;       // which way the leg is running
double   G_LB_STRETCH  = 0.0;     // leg length in ATR
int      G_LB_BARS     = 0;       // bars the leg has been running
int      G_LB_BAR      = -100000;
string   G_LB_TEXT     = "";

int      G_LB_LAST_STOP_DIR   = 0;
double   G_LB_LAST_STOP_PRICE = 0.0;
int      G_LB_VERDICT  = LB_OK;
string   G_LB_WHY      = "";
int      G_LB_HELD     = 0;       // bars since anything was allowed through

//---------------------------------------------------------------------
// Where the current leg starts. Not a fixed lookback - a fixed window makes a falling
// market read as permanently at the bottom, and the robot stops trading for hours.
//
// The leg restarts when price makes a new extreme against its direction, which is what
// a trader means by "a new swing". So after a fall and a bounce, the leg is measured
// from the bounce, and a sell becomes available again as soon as the pullback is real.
//---------------------------------------------------------------------
void LocationBrainScan()
{
   if(!EnableLocationBrain) return;
   if(G_LB_BAR == G_BARS_SEEN) return;
   G_LB_BAR = G_BARS_SEEN;

   ENUM_TIMEFRAMES tf = LBTimeframe;
   int cap = MathMax(6, LBMaxLegBars);

   double hi = CandleHigh(tf, 1), lo = CandleLow(tf, 1);
   if(hi <= 0.0 || lo <= 0.0) return;

   int hi_at = 1, lo_at = 1;

   // Walk back until the swing stops extending - that is where this leg began.
   int k = 2;
   for(; k <= cap; k++)
   {
      double h = CandleHigh(tf, k), l = CandleLow(tf, k);
      if(h <= 0.0 || l <= 0.0) break;

      if(h > hi) { hi = h; hi_at = k; }
      if(l < lo) { lo = l; lo_at = k; }

      // Both extremes are now far behind and the range has stopped growing: the leg
      // before this one has been reached.
      if(k - MathMax(hi_at, lo_at) >= MathMax(3, LBLegSettleBars))
         break;
   }

   G_LB_HI   = hi;
   G_LB_LO   = lo;
   G_LB_BARS = k;
   G_LB_DIR  = (lo_at < hi_at) ? 1 : -1;    // the later extreme is the direction of travel

   double span = hi - lo;

   // Position is NOT computed here. The leg is made of closed candles and cannot change within a
   // bar, so it is cached - but where price sits inside that leg changes on every tick, and that is
   // the whole question. Computing it here would mean a pullback is seen a full bar late, which on
   // a robot taking three hundred trades a day is most of the entries.
   double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
   G_LB_STRETCH = (atr > 0.0) ? (span / atr) : 0.0;

   G_LB_TEXT = StringFormat("%s  %.1f ATR  %d bars",
                            (G_LB_DIR > 0 ? "up" : "down"), G_LB_STRETCH, G_LB_BARS);
}

//---------------------------------------------------------------------
// The verdict. LB_OK means open it; anything else means hold and wait for a price
// worth paying.
//---------------------------------------------------------------------
int LocationBrainVerdict(const int dir, string &why)
{
   why = "";
   G_LB_VERDICT = LB_OK;
   G_LB_WHY = "";

   if(!EnableLocationBrain || dir == 0)
      return LB_OK;

   LocationBrainScan();          // the leg - cached, closed candles only

   double lb_span = G_LB_HI - G_LB_LO;
   if(G_LB_HI <= 0.0 || G_LB_LO <= 0.0 || lb_span <= 0.0)
      return LB_OK;

   // Position, live. Two subtractions and a divide - the cost of a comparison, and it has to be
   // live: a pullback arriving mid-bar is exactly the price this is waiting for, and seeing it a
   // bar late would miss most of them.
   double lb_px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(lb_px <= 0.0)
      return LB_OK;

   G_LB_POS = MathMax(0.0, MathMin(1.0, (lb_px - G_LB_LO) / lb_span));

   // The leg has to be worth measuring position within. A fifty-cent range says nothing
   // about where the good price is.
   if(G_LB_STRETCH < LBMinLegATR)
      return LB_OK;

   // --- 1. position ---------------------------------------------------
   // Selling wants height, buying wants depth.
   double need = (dir > 0) ? LBBuyMaxPosition : LBSellMinPosition;

   // --- 2a. the larger timeframes -------------------------------------
   // Not a veto - a price. Going against a daily that has run hard means the entry has to
   // be better placed than one going with it.
   if(EnableHTFBias)
   {
      double htf_extra = 0.0;
      string htf_d = "";
      HTFAgainstCost(dir, htf_extra, htf_d);

      if(htf_extra > 0.0)
      {
         if(dir > 0) need -= htf_extra;    // a buy against a falling daily must be deeper
         else        need += htf_extra;    // a sell against a rising one must be higher
      }
   }

   // --- 2. stretch ----------------------------------------------------
   // A stretched leg demands a deeper pullback, because that is where the pullback is
   // coming from.
   if(G_LB_STRETCH >= LBStretchFromATR)
   {
      double over = (G_LB_STRETCH - LBStretchFromATR) /
                    MathMax(0.1, LBStretchFullATR - LBStretchFromATR);
      over = MathMax(0.0, MathMin(1.0, over));

      if(dir > 0) need -= over * LBStretchExtra;   // a buy must be deeper still
      else        need += over * LBStretchExtra;   // a sell must be higher still
   }

   // What the record has added. Only ever a demand, never a discount.
   if(EnableEvidenceTighten && G_ADAPT_EXTRA > 0.0)
   {
      if(dir > 0) need -= G_ADAPT_EXTRA;
      else        need += G_ADAPT_EXTRA;
   }

   bool position_ok = (dir > 0) ? (G_LB_POS <= need) : (G_LB_POS >= need);

   if(!position_ok)
   {
      G_LB_VERDICT = (G_LB_STRETCH >= LBStretchFromATR) ? LB_WAIT_STRETCH : LB_WAIT_POSITION;
      G_LB_WHY = StringFormat("%s at %.2f of the leg, wants %s%.2f",
                              (dir > 0 ? "BUY" : "SELL"), G_LB_POS,
                              (dir > 0 ? "<=" : ">="), need);
      why = G_LB_WHY;
      return G_LB_VERDICT;
   }

   // --- 3. worse than the stop ----------------------------------------
   // The same direction again after a stop, at a price no better than the one that
   // failed, is the first mistake with a bigger lot behind it.
   if(LBBlockWorseThanStop && G_LB_LAST_STOP_DIR == dir && G_LB_LAST_STOP_PRICE > 0.0)
   {
      double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double edge = ScaleAdjustedPoints(MathMax(1, LBBetterThanStopPoints)) * _Point;

      bool better = (dir > 0) ? (px <= G_LB_LAST_STOP_PRICE - edge)
                              : (px >= G_LB_LAST_STOP_PRICE + edge);

      if(!better)
      {
         G_LB_VERDICT = LB_WAIT_WORSE_THAN_STOP;
         G_LB_WHY = StringFormat("last %s stopped at %.2f - wants a better price",
                                 (dir > 0 ? "BUY" : "SELL"), G_LB_LAST_STOP_PRICE);
         why = G_LB_WHY;
         return G_LB_VERDICT;
      }
   }

   return LB_OK;
}

//---------------------------------------------------------------------
// Remember where a losing basket closed, so the next trade that way has to beat it.
//---------------------------------------------------------------------
void LocationBrainRecordStop(const int dir, const double price)
{
   if(!EnableLocationBrain || dir == 0 || price <= 0.0) return;

   G_LB_LAST_STOP_DIR   = dir;
   G_LB_LAST_STOP_PRICE = price;

   if((LocationBrainPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS BRAIN] %s stopped at %.2f - the next one that way has to be better",
                  (dir > 0 ? "BUY" : "SELL"), price);
}

void LocationBrainClearStop(const int dir)
{
   // A win that way clears the debt - the price that failed is no longer the reference.
   if(G_LB_LAST_STOP_DIR == dir)
   {
      G_LB_LAST_STOP_DIR = 0;
      G_LB_LAST_STOP_PRICE = 0.0;
   }
}

string LocationBrainText()
{
   if(!EnableLocationBrain) return "";

   string t = StringFormat("location: at %.2f of the leg  %s", G_LB_POS, G_LB_TEXT);

   if(G_LB_VERDICT != LB_OK && StringLen(G_LB_WHY) > 0)
      t += "  |  waiting " + IntegerToString(G_LB_HELD) + " bars - " + G_LB_WHY;

   return t;
}

//=====================================================================
// DECISION LOG — one line per decision
//---------------------------------------------------------------------
// A day went to guessing which of twenty-two gates was closed, six times, wrong each
// time. The EA knew the answer every time it refused and never wrote it down in a form
// anyone could read back.
//
// One line, one decision, enough fields to reconstruct it afterwards without a
// screenshot. Written only when something changes, so the log stays readable.
//=====================================================================

string   G_DLOG_LAST = "";
datetime G_DLOG_WHEN = 0;

void DecisionLog(const string verdict, const string why)
{
   if(!EnableDecisionLog) return;

   string line = StringFormat(
      "%s | %s %s s%d | leg %.2f %s %.1fATR | %s",
      verdict,
      (G_OPP_DIR == OPP_DIR_BUY ? "BUY" : (G_OPP_DIR == OPP_DIR_SELL ? "SELL" : "---")),
      OpportunityTypeToString(G_OPP_TYPE),
      G_SCORE_FINAL,
      G_LB_POS, (G_LB_DIR > 0 ? "up" : "dn"), G_LB_STRETCH,
      why);

   // Only when it changes, and never more than once a minute for the same thing.
   if(line == G_DLOG_LAST && (TimeCurrent() - G_DLOG_WHEN) < DecisionLogRepeatSeconds)
      return;

   G_DLOG_LAST = line;
   G_DLOG_WHEN = TimeCurrent();

   Print("[SIRUS LOG] ", line);
}



// ============================================================================
int      G_ZN_BAR = -100000;
int      G_ZN_N   = 0;
double   G_ZN_LO[64], G_ZN_HI[64], G_ZN_W[64];
int      G_ZN_TF[64], G_ZN_CNT[64];

void ZoneEngineBuild()
{
   if(G_ZN_BAR == G_BARS_SEEN) return;
   G_ZN_BAR = G_BARS_SEEN;
   G_ZN_N = 0;

   // BOSQICH 18: darajalar endi HUDUD sifatida yig'iladi (lo..hi). Kichik TF da lo = hi (nuqta),
   // katta TF da esa shamning soya maydoni - treyder chizadigan hudud.
   double la[400], lb[400], lw[400];
   int    lt[400], nl = 0;
   int dep = MathMax(1, LGSwingDepth);
   int tf_count = ZoneUseHTF ? 5 : 3;

   for(int t = 0; t < tf_count; t++)
   {
      ENUM_TIMEFRAMES tf = (t == 0) ? PERIOD_M15 : ((t == 1) ? PERIOD_M5 : ((t == 2) ? PERIOD_M1 : ((t == 3) ? PERIOD_M30 : PERIOD_H1)));
      int look = MathMin(200, (t == 0) ? LGSwingLookM15 : ((t == 1) ? LGSwingLookM5 : ((t == 2) ? LGSwingLookM1 : ((t == 3) ? ZoneLookM30 : ZoneLookH1))));
      double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
      if(atr <= 0.0) continue;
      double min_react = atr * LGSwingMinReactATR;
      double tfw = (t == 0) ? 1.5 : ((t == 1) ? 1.2 : ((t == 2) ? 1.0 : ((t == 3) ? ZoneHTFWeightM30 : ZoneHTFWeightH1)));

      for(int side = 0; side < 2; side++)          // 0 = high, 1 = low
      {
         for(int i = dep + 1; i <= look && nl < 400; i++)
         {
            double v = (side == 0) ? CandleHigh(tf, i) : CandleLow(tf, i);
            if(v <= 0.0) continue;
            bool sw = true;
            for(int k = 1; k <= dep && sw; k++)
            {
               double a = (side == 0) ? CandleHigh(tf, i - k) : CandleLow(tf, i - k);
               double b = (side == 0) ? CandleHigh(tf, i + k) : CandleLow(tf, i + k);
               if(side == 0 && (a >= v || b >= v)) sw = false;
               if(side == 1 && (a <= v || b <= v)) sw = false;
            }
            if(!sw) continue;

            double react = 0.0;
            for(int k = i - 1; k >= 1; k--)
            {
               double away = (side == 0) ? (v - CandleLow(tf, k)) : (CandleHigh(tf, k) - v);
               if(away > react) react = away;
            }
            if(react < min_react) continue;

            // Hudud: katta TF da soya maydoni, kichik TF da nuqta
            double za = v, zb = v;
            if(ZoneWickArea && t >= 3)
            {
               double o = CandleOpen(tf, i), c = CandleClose(tf, i);
               double body_lo = MathMin(o, c), body_hi = MathMax(o, c);
               if(side == 1) { za = v; zb = body_lo; }      // swing low: low..tana pastki
               else          { za = body_hi; zb = v; }      // swing high: tana yuqori..high
               if(zb < za) { double tmp = za; za = zb; zb = tmp; }
            }
            la[nl] = za;
            lb[nl] = zb;
            lw[nl] = ((react >= atr * 2.0) ? 2.0 : 1.0) * tfw;
            lt[nl] = t;
            nl++;
         }
      }
   }
   if(nl <= 0) return;

   // hudud boshlanishi bo'yicha saralash
   for(int i = 1; i < nl; i++)
   {
      double ka = la[i], kb = lb[i], kw = lw[i]; int kt = lt[i], j = i - 1;
      while(j >= 0 && la[j] > ka) { la[j+1] = la[j]; lb[j+1] = lb[j]; lw[j+1] = lw[j]; lt[j+1] = lt[j]; j--; }
      la[j+1] = ka; lb[j+1] = kb; lw[j+1] = kw; lt[j+1] = kt;
   }

   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   if(atr5 <= 0.0) return;
   double merge = atr5 * ZoneClusterATR;

   // Klaster: hududlar kesishsa yoki orasi merge dan kichik bo'lsa - birlashadi
   int i0 = 0;
   while(i0 < nl && G_ZN_N < 64)
   {
      int i1 = i0;
      double cur_hi = lb[i0];
      while(i1 + 1 < nl && (la[i1+1] - cur_hi) <= merge)
      {
         i1++;
         if(lb[i1] > cur_hi) cur_hi = lb[i1];
      }
      double w = 0.0; int best_tf = 2;
      for(int k = i0; k <= i1; k++) { w += lw[k]; if(lt[k] > 2) best_tf = lt[k]; else if(lt[k] < best_tf && best_tf <= 2) best_tf = lt[k]; }
      G_ZN_LO[G_ZN_N] = la[i0];
      G_ZN_HI[G_ZN_N] = cur_hi;
      G_ZN_W[G_ZN_N]  = w;
      G_ZN_TF[G_ZN_N] = best_tf;
      G_ZN_CNT[G_ZN_N] = i1 - i0 + 1;
      G_ZN_N++;
      i0 = i1 + 1;
   }

   if(ZoneLogOnUse && G_ZN_N > 0)
   {
      string txt = "";
      for(int z = 0; z < G_ZN_N; z++)
         txt += StringFormat("%.2f-%.2f w%.1f n%d %s | ", G_ZN_LO[z], G_ZN_HI[z], G_ZN_W[z], G_ZN_CNT[z],
                             (G_ZN_TF[z] == 0 ? "M15" : (G_ZN_TF[z] == 1 ? "M5" : (G_ZN_TF[z] == 2 ? "M1" : (G_ZN_TF[z] == 3 ? "M30" : "H1")))));
      PrintFormat("[SIRUS ZONES] %d zones | %s", G_ZN_N, txt);
   }
}

// Savdo yo'nalishidagi dominant hudud to'siq bo'lsa - true.
bool ZoneBlocks(const int dir, string &why)
{
   why = "";
   if(!ZoneEngineOn || (dir != 1 && dir != -1)) return false;
   ZoneEngineBuild();
   if(G_ZN_N <= 0) return false;

   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr5 <= 0.0 || px <= 0.0) return false;
   double band = atr5 * ZoneBandATR, tol = atr5 * LGTouchATR;

   int best = -1; double best_d = 1e9;
   for(int z = 0; z < G_ZN_N; z++)
   {
      if(G_ZN_W[z] < ZoneMinWeight) continue;
      double lo = G_ZN_LO[z], hi = G_ZN_HI[z];
      // ROL: narxdan yuqorida - resistance (BUY uchun to'siq), pastda - support (SELL uchun to'siq)
      double edge;
      if(dir > 0) { if(hi <= px) continue; edge = lo; }   // yuqoridagi hudud, yaqin cheti - lo
      else        { if(lo >= px) continue; edge = hi; }   // pastdagi hudud, yaqin cheti - hi
      double d = (dir > 0) ? (edge - px) : (px - edge);
      if(d < 0.0)
      {
         // BOSQICH 19: narx hudud ICHIDA. Faqat kirish tomonidagi qism to'sadi.
         double width = hi - lo;
         if(width > 0.0 && ZoneInsideBlockShare < 1.0)
         {
            // SELL support hududiga yuqoridan keladi: xavfli qism - yuqori ZoneInsideBlockShare
            double depth = (dir > 0) ? (px - lo) : (hi - px);   // kirish tomonidan qancha ichkari
            if(depth > width * ZoneInsideBlockShare) continue;  // hududni yeb bo'lgan - davom etish ochiq
         }
         d = 0.0;
      }
      else if(d > band) continue;
      // SINISH: savdo yo'nalishida yopilish bilan o'tilganmi
      if(LGBrokenBeyond(dir, (dir > 0) ? hi : lo, tol)) continue;
      if(d < best_d) { best_d = d; best = z; }
   }
   if(best < 0) return false;

   why = StringFormat("%s into %s zone %.2f-%.2f (w%.1f, %d levels, %s) %.2f away",
                      (dir > 0 ? "BUY" : "SELL"), (dir > 0 ? "resistance" : "support"),
                      G_ZN_LO[best], G_ZN_HI[best], G_ZN_W[best], G_ZN_CNT[best],
                      (G_ZN_TF[best] == 0 ? "M15" : (G_ZN_TF[best] == 1 ? "M5" : (G_ZN_TF[best] == 2 ? "M1" : (G_ZN_TF[best] == 3 ? "M30" : "H1")))), best_d);
   return true;
}

// ============================================================================
// BOSQICH 12: S/R DVIGATELI - hudud to'sig'i ustidagi uchta qoida
//   1) SIQILISH: S va R orasi SRCompressionATR dan tor bo'lsa, bu sun'iy tor oraliq.
//      Bunday joyda hudud to'sig'i ishlamaydi - qaror ballga qoladi (band 8, 10).
//   2) IKKALASI BIRDAN YO'Q: narx ikki hudud orasida qolsa, faqat YAQINROG'I to'sadi.
//      Robot hech qachon ikkala yo'nalishni birdan yopmaydi.
//   3) MICRO SINISH: oxirgi M1 shami hudud chetidan TANA bilan o'tib yopilgan bo'lsa
//      (displacement), hudud endi to'siq emas - breakout/retest savdosi o'tadi.
// ============================================================================
double ZoneNearEdge(const int dir, double &lo, double &hi, double &w)
{
   lo = 0.0; hi = 0.0; w = 0.0;
   ZoneEngineBuild();
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(px <= 0.0 || G_ZN_N <= 0) return 0.0;
   int best = -1; double best_d = 1e9, edge = 0.0;
   for(int z = 0; z < G_ZN_N; z++)
   {
      if(G_ZN_W[z] < ZoneMinWeight) continue;
      double e;
      if(dir > 0) { if(G_ZN_HI[z] <= px) continue; e = G_ZN_LO[z]; }
      else        { if(G_ZN_LO[z] >= px) continue; e = G_ZN_HI[z]; }
      double d = MathAbs(e - px);
      if(d < best_d) { best_d = d; best = z; edge = e; }
   }
   if(best < 0) return 0.0;
   lo = G_ZN_LO[best]; hi = G_ZN_HI[best]; w = G_ZN_W[best];
   return edge;
}

bool SRMicroBreak(const int dir, const double edge)
{
   if(!SRMicroBreakAllow || edge <= 0.0) return false;
   double atr1 = ATRPointsManual(PERIOD_M1, ATRPeriod, 1) * _Point;
   if(atr1 <= 0.0) return false;
   double o = CandleOpen(PERIOD_M1, 1), c = CandleClose(PERIOD_M1, 1);
   double h = CandleHigh(PERIOD_M1, 1), l = CandleLow(PERIOD_M1, 1);
   double rng = h - l;
   if(rng < atr1 * SRMicroBreakBodyATR || MathAbs(c - o) < rng * 0.6) return false;
   return (dir > 0) ? (c > edge && o <= edge) : (c < edge && o >= edge);
}

// BOSQICH 15: micro struktura hududni sindirganmi - BOS darajasi hudud chetidan o'tgan bo'lsa,
// bu strukturaviy sinish: hudud endi to'siq emas.
bool MicroBrokeZone(const int dir, const double edge)
{
   if(!MicroZoneOverride || !MicroStructOn || edge <= 0.0) return false;
   MicroStructUpdate();
   for(int t = 0; t < 3; t++)
   {
      if(G_MS_DIR[t] != dir) continue;
      if(G_MS_STATE[t] != MS_IMPULSE && G_MS_STATE[t] != MS_CONTINUATION && G_MS_STATE[t] != MS_REVERSAL) continue;
      double bos = G_MS_BOS[t];
      if(bos <= 0.0) continue;
      double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // BOS darajasi hudud chetida yoki undan narida bo'lsa va narx BOS tomonida bo'lsa
      if(dir > 0 && bos >= edge - (edge * 0.0) && px > bos) return true;
      if(dir < 0 && bos <= edge && px < bos) return true;
   }
   return false;
}

// Yakuniy joy qarori: zona dvigateli + S/R qoidalari
bool LocationZoneRefuses(const int dir, string &why)
{
   why = "";
   if(!ZoneBlocks(dir, why)) return false;

   double lo_f = 0.0, hi_f = 0.0, w_f = 0.0;
   double edge_f = ZoneNearEdge(dir, lo_f, hi_f, w_f);

   // 3) micro sinish - hudud chetidan tana bilan o'tilgan yoki micro BOS uni sindirgan
   if(SRMicroBreak(dir, edge_f) || MicroBrokeZone(dir, edge_f)) { why = ""; return false; }

   double atr5 = ATRPointsManual(PERIOD_M5, ATRPeriod, 1) * _Point;
   double lo_b = 0.0, hi_b = 0.0, w_b = 0.0;
   double edge_b = ZoneNearEdge(-dir, lo_b, hi_b, w_b);   // teskari tomondagi hudud

   if(atr5 > 0.0 && edge_f > 0.0 && edge_b > 0.0)
   {
      // 1) siqilish - ikki hudud orasi juda tor
      double range = MathAbs(edge_f - edge_b);
      if(range < atr5 * SRCompressionATR) { why = ""; return false; }

      // 2) ikkalasi birdan yopilmasin - faqat yaqinrog'i to'sadi
      if(SRNeverBlockBoth)
      {
         double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         string chk = "";
         if(ZoneBlocks(-dir, chk) && MathAbs(edge_f - px) > MathAbs(edge_b - px))
         { why = ""; return false; }
      }
   }
   return true;
}

// ============================================================================
// BOSQICH 13: QAROR ZANJIRI. Har potentsial kirish uchun bitta qator - signal, struktura
// konteksti, zona va uning roli, S/R masofasi, joy, ball, cooldown, sabab va yakuniy qaror.
// "Robot nega savdo qilmadi" savoliga taxminsiz javob beradi.
// ============================================================================
void DecisionChainLog(const bool ready, const string reason)
{
   if(!LogDecisionChain || G_OPP_DIR == OPP_DIR_NONE) return;
   if(!LogDecisionChainAll && ready) return;

   int d = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
   static int ch_bar = -100000;
   static int ch_dir = 0;
   static bool ch_ready = false;
   if(ch_bar > G_BARS_SEEN) ch_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(ch_bar == G_BARS_SEEN && ch_dir == d && ch_ready == ready) return;
   ch_bar = G_BARS_SEEN; ch_dir = d; ch_ready = ready;

   MicroStructUpdate();   // BOSQICH 14
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double r_lo = 0.0, r_hi = 0.0, r_w = 0.0, s_lo = 0.0, s_hi = 0.0, s_w = 0.0;
   double r_edge = ZoneNearEdge(1, r_lo, r_hi, r_w);     // yuqoridagi hudud = resistance
   double s_edge = ZoneNearEdge(-1, s_lo, s_hi, s_w);    // pastdagi hudud = support
   string loc_why = "";
   bool loc_block = LocationZoneRefuses(d, loc_why);
   if(!loc_block)
   {
      string t = "";
      if(LGFreshImpulse(d, t) || LGChasingImpulse(d, t) || LGMicroTip(d, t)) { loc_block = true; loc_why = t; }
   }

   PrintFormat("[SIRUS CHAIN] %s %s | micro=%s | minor=%s | local=%s | market=%s | zones=%d | R=%s | S=%s | range=%s | loc=%s | score=%d/%d (%s) | arm=%s | cooldown=%s | reentry=%s | reason=%s | %s",
               (d > 0 ? "BUY" : "SELL"),
               OpportunityTypeToString(G_OPP_TYPE),
               MicroStructText(0), MicroStructText(1), MicroStructText(2),
               MarketStateToString(G_MARKET_STATE),
               G_ZN_N,
               (r_edge > 0.0 ? StringFormat("%.2f-%.2f w%.1f (%.2f up)", r_lo, r_hi, r_w, r_edge - px) : "-"),
               (s_edge > 0.0 ? StringFormat("%.2f-%.2f w%.1f (%.2f dn)", s_lo, s_hi, s_w, px - s_edge) : "-"),
               ((r_edge > 0.0 && s_edge > 0.0) ? StringFormat("%.2f", r_edge - s_edge) : "-"),
               (loc_block ? loc_why : "ok"),
               G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, ScoreDecisionToString(G_SCORE_DECISION),
               (G_ARM_DIR == 0 ? "no" : (G_ARM_DIR > 0 ? "BUY" : "SELL")),
               (IsPostLossCooldownActive() ? "yes" : "no"),
               ((G_LAST_WIN_DIR == d && (G_BARS_SEEN - G_LAST_WIN_BAR) <= WinReEntryBars) ? "relief" : "no"),
               reason,
               (ready ? "DECISION=ENTER" : "DECISION=NO"));
}

// ============================================================================
// BOSQICH 14: MICRO / MINOR STRUKTURA
// ----------------------------------------------------------------------------
// M1 = micro, M5 = minor. Har TF uchun oxirgi swing high/low topiladi va quyidagilar aniqlanadi:
//   BOS   - yopilish oxirgi swing high dan yuqorida (bullish) yoki swing low dan pastda (bearish)
//   MSS/CHOCH - BOS oldingi BOS ga TESKARI tomonda - struktura o'zgarishi
//   DISPLACEMENT - katta tanali sham (>= MicroDisplaceATR)
//   HOLAT - IMPULSE / CONTINUATION / REVERSAL / PULLBACK / RANGE
// Bu bosqich faqat O'QIYDI va logga beradi; qarorga ta'sir bosqich 15 da ulanadi.
// ============================================================================
// (MS_* konstantalari fayl boshiga ko'chirildi - ular bu satrdan oldin ishlatiladi)

// (G_MS_* globallari fayl boshiga ko'chirildi - ular bu satrdan oldin ishlatiladi)

string MicroStateName(const int st)
{
   switch(st)
   {
      case MS_IMPULSE:      return "IMPULSE";
      case MS_CONTINUATION: return "CONTINUATION";
      case MS_REVERSAL:     return "REVERSAL/MSS";
      case MS_PULLBACK:     return "PULLBACK";
   }
   return "RANGE";
}

void MicroStructUpdate()
{
   if(!MicroStructOn || G_MS_BAR == G_BARS_SEEN) return;
   G_MS_BAR = G_BARS_SEEN;

   for(int t = 0; t < 3; t++)
   {
      ENUM_TIMEFRAMES tf = (t == 0) ? PERIOD_M1 : ((t == 1) ? PERIOD_M5 : PERIOD_M15);
      int look = MathMin(200, (t == 0) ? MicroLookM1 : ((t == 1) ? MicroLookM5 : MicroLookM15));
      int dep  = MathMax(1, MicroSwingDepth);
      double atr = ATRPointsManual(tf, ATRPeriod, 1) * _Point;
      if(atr <= 0.0) continue;

      // oxirgi ikkita swing high va low
      double sh[2] = {0.0, 0.0}, sl[2] = {0.0, 0.0};
      int nh = 0, nl2 = 0;
      for(int i = dep + 1; i <= look && (nh < 2 || nl2 < 2); i++)
      {
         bool hi = true, lo = true;
         double vh = CandleHigh(tf, i), vl = CandleLow(tf, i);
         for(int k = 1; k <= dep; k++)
         {
            if(CandleHigh(tf, i - k) >= vh || CandleHigh(tf, i + k) >= vh) hi = false;
            if(CandleLow(tf, i - k)  <= vl || CandleLow(tf, i + k)  <= vl) lo = false;
         }
         if(hi && nh < 2) sh[nh++] = vh;
         if(lo && nl2 < 2) sl[nl2++] = vl;
      }
      if(nh < 1 || nl2 < 1) { G_MS_DIR[t] = 0; G_MS_STATE[t] = MS_RANGE; continue; }

      // BOS: oxirgi yopilishlar swing dan o'tganmi
      int bos_dir = 0;
      double bos_lvl = 0.0;
      for(int k = 1; k <= 6 && bos_dir == 0; k++)
      {
         double c = CandleClose(tf, k);
         if(c > sh[0]) { bos_dir = 1;  bos_lvl = sh[0]; }
         else if(c < sl[0]) { bos_dir = -1; bos_lvl = sl[0]; }
      }

      // oldingi BOS yo'nalishi: swing ketma-ketligi bo'yicha (HH/HL yoki LH/LL)
      int prev_dir = 0;
      if(nh >= 2 && nl2 >= 2)
      {
         if(sh[0] > sh[1] && sl[0] > sl[1]) prev_dir = 1;
         else if(sh[0] < sh[1] && sl[0] < sl[1]) prev_dir = -1;
      }

      // displacement
      double o = CandleOpen(tf, 1), c1 = CandleClose(tf, 1);
      double rng = CandleHigh(tf, 1) - CandleLow(tf, 1);
      bool disp = (rng >= atr * MicroDisplaceATR && MathAbs(c1 - o) >= rng * 0.6);

      int st = MS_RANGE, dir = prev_dir;
      if(bos_dir != 0)
      {
         dir = bos_dir;
         if(prev_dir != 0 && bos_dir != prev_dir) st = MS_REVERSAL;        // MSS / CHOCH
         else if(disp)                            st = MS_IMPULSE;
         else                                     st = MS_CONTINUATION;
      }
      else if(prev_dir != 0)
      {
         // BOS yo'q: narx struktura yo'nalishiga qarshi harakatlanyaptimi - bu korreksiya
         double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool against = (prev_dir > 0) ? (px < sh[0]) : (px > sl[0]);
         st = against ? MS_PULLBACK : MS_CONTINUATION;
      }

      G_MS_DIR[t]   = dir;
      G_MS_STATE[t] = st;
      G_MS_BOS[t]   = bos_lvl;
   }
}

string MicroStructText(const int t)
{
   if(!MicroStructOn) return "off";
   return StringFormat("%s %s", (G_MS_DIR[t] > 0 ? "up" : (G_MS_DIR[t] < 0 ? "down" : "flat")),
                       MicroStateName(G_MS_STATE[t]));
}

// BOSQICH 7: JOY REDIRECTI. v291 da redirect faqat ball yetmaganda ishlaydi va joy himoyasidan OLDIN
// turadi - shuning uchun himoya support'da SELL ni to'sganda robot support'dan BUY ni umuman
// tekshirmasdi. Bu yerda: faqat DARAJA sababli to'silganda, motorning o'zining redirect qidiruvi
// (FindOppositeRedirectCandidate) va o'zining ball dvigateli ishlatiladi. Yangi strategiya yo'q.
// Ahmoqona bo'lmasligi uchun:
//   - impuls/xaos bozorda ishlamaydi (tushayotgan pichoqni tutmaslik) - v291 redirect qoidasi
//   - jonli kutish (arming) bo'lsa ishlamaydi
//   - teskari yo'nalish ham TOZA joyda bo'lishi shart: boshqa devorga qarab emas, yangi impulsga
//     qarshi emas, shamni quvib emas, harakat uchida emas
//   - ball o'tishi shart (yoki talabdan <= ReliefMaxShortfall kam + yaxshi joy bonusi)
//   - bir barda bir marta
bool TryLocationRedirect(const int from_dir, string &why)
{
   why = "";
   if(!LGLocationRedirect || from_dir == 0) return false;
   static int lr_bar = -100000;
   static int lr_dir = 0;
   if(lr_bar > G_BARS_SEEN) lr_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(lr_bar == G_BARS_SEEN && lr_dir == from_dir) return false;
   lr_bar = G_BARS_SEEN;
   lr_dir = from_dir;

   if(RedirectAvoidChaosImpulse && (G_MARKET_STATE == MARKET_CHAOS || G_MARKET_STATE == MARKET_IMPULSE))
      return false;
   if(G_ARM_DIR != 0)
      return false;

   int to_dir = -from_dir;
   string chk = "";

   // The redirect flips the direction when the zone refuses one way, and it has never asked
   // whether the OTHER way is any good. A flip into a direction the detectors did not vote for,
   // or that the daily is running against, is a trade nobody proposed - the zone engine said "not
   // this way" and something read it as "so the other way then".
   if(EnableRedirectChecks)
   {
      // The crowd. If the side being flipped to had barely any voices, there was no setup there.
      if(EnableDirectionConsensus)
      {
         int to_voices = (to_dir > 0) ? G_OPP_VOICES_BUY : G_OPP_VOICES_SELL;
         if(to_voices < RedirectMinVoices)
         {
            why = StringFormat("redirect refused - only %d detector(s) saw %s",
                               to_voices, (to_dir > 0 ? "BUY" : "SELL"));
            return false;
         }
      }

      // The place. A flip into the bottom of a fall is the same mistake wearing the other sign.
      if(EnableLocationBrain)
      {
         string lb_why = "";
         if(LocationBrainVerdict(to_dir, lb_why) != LB_OK)
         {
            why = "redirect refused - " + lb_why;
            return false;
         }
      }

      // The larger timeframes. Flipping into them is the one direction that needed no help.
      if(EnableHTFBias)
      {
         double htf_extra = 0.0;
         string htf_d = "";
         if(HTFAgainstCost(to_dir, htf_extra, htf_d) > RedirectMaxHTFCost)
         {
            why = "redirect refused - " + htf_d;
            return false;
         }
      }
   }
   if(LocationZoneRefuses(to_dir, chk) || LGFreshImpulse(to_dir, chk) ||
      LGChasingImpulse(to_dir, chk) || LGMicroTip(to_dir, chk))
      return false;

   ENUM_OPPORTUNITY_DIR tdir = (to_dir > 0) ? OPP_DIR_BUY : OPP_DIR_SELL;
   ENUM_OPPORTUNITY_TYPE bt = OPP_TYPE_NONE;
   int bs = 0;
   string br = "";
   bool bm = false;
   if(!FindOppositeRedirectCandidate(tdir, bt, bs, br, bm))
      return false;

   ApplyRedirectOpportunity(tdir, bt, bs, br, bm);
   UpdateSignalScoreEngine("LOCATION_REDIRECT");

   bool passed = (G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS);
   // qaytish darajadan - bu yaxshi joy, 5B bonusi shu yerda ham amal qiladi
   if(!passed && EnableGoodLocationBonus && G_SCORE_DECISION == SCORE_DECISION_WAIT && G_ARM_DIR == 0 &&
      G_SCORE_MIN_REQUIRED > 0 && G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED - MathMax(0, ReliefMaxShortfall) &&
      G_SCORE_FINAL + MathMax(0, GoodLocationBonus) >= G_SCORE_MIN_REQUIRED)
   {
      G_SCORE_DECISION = G_SCORE_IS_MICRO ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS;
      passed = true;
   }
   if(!passed)
      return false;

   why = StringFormat("%s blocked at a level -> %s %s %d/%d",
                      (from_dir > 0 ? "BUY" : "SELL"), (to_dir > 0 ? "BUY" : "SELL"),
                      OpportunityTypeToString(bt), G_SCORE_FINAL, G_SCORE_MIN_REQUIRED);
   if((LGPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS LOCATION REDIRECT] %s", why);
   return true;
}

int G_NEAR_MISS_TODAY = 0;        // BOSQICH 4: bugun nechta setup 1-2 ballga yetmadi (M1 bar bo'yicha)
int G_LOCATION_BLOCKS_TODAY = 0;  // BOSQICH 4: bugun joy himoyasi necha M1 bar davomida kirishni to'sdi

// True while the entry being judged came from the Market Brain fast path. The brain's veto and
// judge already ask the location, impulse, failed-break and HTF questions with fresher evidence, so
// the older score-cost and location gates that ask the same questions stand aside for it - the
// detector score they tax was never part of this entry. Risk, news, spread and cooldowns still apply.
bool G_MB_FAST_ACTIVE = false;

// An older gate stands aside when the Market Brain answers its question (see MBStandsInFor).
bool MBOwnsGate(const bool location_gate)
{
   if(G_MB_FAST_ACTIVE)
      return true;
   int d = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
   return MBStandsInFor(d, location_gate);
}

bool FirstEntryCanRun(string &reason)
{
   G_MB_FAST_ACTIVE = false;
   // BOSQICH 4: kun almashganda kechagi hisob logga yoziladi va nolga qaytadi
   {
      static int fe_day = -1;
      MqlDateTime fe_dt;
      TimeToStruct(TimeCurrent(), fe_dt);
      if(fe_day != fe_dt.day_of_year)
      {
         if(fe_day >= 0)
            PrintFormat("[SIRUS DAY SUMMARY] near-miss setups: %d | location blocks: %d",
                        G_NEAR_MISS_TODAY, G_LOCATION_BLOCKS_TODAY);
         fe_day = fe_dt.day_of_year;
         G_NEAR_MISS_TODAY = 0;
         G_LOCATION_BLOCKS_TODAY = 0;
      }
   }

   if(!UseFirstEntryEngine)
   {
      reason = "UseFirstEntryEngine=false";
      return false;
   }

   if(!AllowLiveTrading)
   {
      reason = "AllowLiveTrading=false";
      return false;
   }

   if(!G_ENV_READY)
   {
      reason = "ENV not ready";
      return false;
   }

   string risk_reason = "";
   if(!RiskAllowsNewEntry(risk_reason))
   {
      reason = risk_reason;
      return false;
   }

   string pack3_entry_reason = "";
   if(!Pack3AllowsEntry(pack3_entry_reason))
   {
      reason = pack3_entry_reason;
      return false;
   }

   string p4m_entry_reason = "";
   if(!Pack4MiniAllowsEntry(p4m_entry_reason))
   {
      reason = p4m_entry_reason;
      return false;
   }

   string p4l_entry_reason = "";
   if(!Pack4MiniLotAllowsEntry(p4l_entry_reason))
   {
      reason = p4l_entry_reason;
      return false;
   }

   string rcb_entry_reason = "";
   if(!RCSettingsAllowsEntry(rcb_entry_reason))
   {
      reason = rcb_entry_reason;
      return false;
   }

   string dcs_entry_reason = "";
   if(!SmartClientSafetyAllowsEntry(dcs_entry_reason))
   {
      reason = dcs_entry_reason;
      return false;
   }

   string dlp_entry_reason = "";
   if(!LegacyDeepParityAllowsEntry(dlp_entry_reason))
   {
      reason = dlp_entry_reason;
      return false;
   }

   string dbos_entry_reason = "";
   if(!DeepBOSAllowsEntry(dbos_entry_reason))
   {
      reason = dbos_entry_reason;
      return false;
   }

   string dtz_entry_reason = "";
   if(!DeepTopZoneAllowsEntry(dtz_entry_reason))
   {
      reason = dtz_entry_reason;
      return false;
   }

   string dnv_entry_reason = "";
   if(!DeepNewsVolatilityAllowsEntry(dnv_entry_reason))
   {
      reason = dnv_entry_reason;
      return false;
   }

   string det_entry_reason = "";
   if(!AdaptiveEntryTimingAllowsEntry(det_entry_reason))
   {
      reason = det_entry_reason;
      return false;
   }

   string drt_entry_reason = "";
   if(!MarketRegimeAutoTuneAllowsEntry(drt_entry_reason))
   {
      reason = drt_entry_reason;
      return false;
   }

   // BOSQICH 5A/5B: YENGILLIK. Ball talabdan ReliefMaxShortfall yoki kamroq kam bo'lgan setup:
   //   5A - yutuqdan keyin o'sha yo'nalish (WinReEntryBars ichida): +WinReEntryRelief
   //   5B - BUY kuchli support ustida / SELL kuchli resistance ostida: +GoodLocationBonus
   // Faqat ball sababli WAIT bo'lsa - jonli kutish (arming) turgan bo'lsa emas: robot "kut" degan
   // joyda yengillik uni majburan ochmaydi. Pastdagi joy himoyasi baribir ishlaydi.
   if(G_SCORE_DECISION == SCORE_DECISION_WAIT && G_ARM_DIR == 0 && G_OPP_DIR != OPP_DIR_NONE &&
      G_SCORE_MIN_REQUIRED > 0 && G_SCORE_FINAL < G_SCORE_MIN_REQUIRED &&
      G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED - MathMax(0, ReliefMaxShortfall))
   {
      int rl_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      int relief = 0;
      string rl_why = "";
      if(EnableWinReEntry && G_LAST_WIN_DIR == rl_dir && (G_BARS_SEEN - G_LAST_WIN_BAR) <= MathMax(1, WinReEntryBars))
      {
         relief += MathMax(0, WinReEntryRelief);
         rl_why += StringFormat("re-entry after win +%d", WinReEntryRelief);
      }
      // BOSQICH 15: struktura kirish tomonida bo'lsa - yengillik. Global trend qarshi bo'lsa ham,
      // "global bullish + local pullback + micro reversal" holati to'siq emas, bu HOLAT.
      if(MicroStructDecides && MicroStructOn)
      {
         MicroStructUpdate();
         int aligned = 0;
         for(int mt = 0; mt < 3; mt++)
            if(G_MS_DIR[mt] == rl_dir &&
               (G_MS_STATE[mt] == MS_IMPULSE || G_MS_STATE[mt] == MS_CONTINUATION || G_MS_STATE[mt] == MS_REVERSAL))
               aligned++;
         // BOSQICH 15b: uchta daraja (micro M1 / minor M5 / local M15). Ikki yoki uchtasi kirish
         // tomonida bo'lsa - to'liq yengillik, bittasi bo'lsa - kichik yengillik.
         int mrel = 0;
         if(aligned >= 2)      mrel = MathMax(0, MicroStructRelief);
         else if(aligned == 1) mrel = MathMax(0, MicroOnlyRelief);
         if(mrel > 0)
         {
            relief += mrel;
            rl_why += (StringLen(rl_why) > 0 ? " | " : "") +
                      StringFormat("structure +%d (micro %s / minor %s / local %s)", mrel,
                                   MicroStructText(0), MicroStructText(1), MicroStructText(2));
         }
      }

      if(EnableGoodLocationBonus)
      {
         string gl = "";
         // BUY uchun: ostida kuchli support bormi? (SELL tomonidan qaraganda "support'ga SELL" holati)
         if(ZoneBlocks(-rl_dir, gl))
         {
            relief += MathMax(0, GoodLocationBonus);
            rl_why += (StringLen(rl_why) > 0 ? " | " : "") + StringFormat("good location +%d", GoodLocationBonus);
         }
      }
      if(relief > 0 && G_SCORE_FINAL + relief >= G_SCORE_MIN_REQUIRED)
      {
         G_SCORE_DECISION = G_SCORE_IS_MICRO ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS;
         if((LGPrintOnUse && VerboseLogs))
         {
            static int rl_bar = -100000;
            if(rl_bar > G_BARS_SEEN) rl_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
            if(rl_bar != G_BARS_SEEN)
            {
               rl_bar = G_BARS_SEEN;
               PrintFormat("[SIRUS RELIEF] %s %d/%d passed with %s",
                           (rl_dir > 0 ? "BUY" : "SELL"), G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, rl_why);
            }
         }
      }
   }

   // MARKET BRAIN SCORE RELIEF: the detectors found a direction but fell short, and the brain reads
   // the same way. Only toward the brain's side; the veto and the judge still decide below.
   if(G_SCORE_DECISION == SCORE_DECISION_WAIT && G_ARM_DIR == 0 && G_OPP_DIR != OPP_DIR_NONE &&
      G_SCORE_MIN_REQUIRED > 0 && G_SCORE_FINAL < G_SCORE_MIN_REQUIRED)
   {
      int br_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
      string br_why = "";
      int br = MBBrainScoreRelief(br_dir, br_why);
      if(br > 0 && G_SCORE_FINAL + br >= G_SCORE_MIN_REQUIRED)
      {
         G_SCORE_DECISION = G_SCORE_IS_MICRO ? SCORE_DECISION_MICRO_PASS : SCORE_DECISION_PASS;
         DecisionLog("BRAIN", StringFormat("score %d/%d passed with %s", G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, br_why));
      }
   }

   // MARKET BRAIN FAST ENTRY (speed): no detector score yet, but a winning basket's thesis is still
   // open (re-entry) or a confirmed thesis has a trigger right now. Everything below - the remaining
   // gates, the veto and the Entry Judge - still decides.
   if(G_SCORE_DECISION != SCORE_DECISION_PASS && G_SCORE_DECISION != SCORE_DECISION_MICRO_PASS)
   {
      int fe_dir = 0;
      string fe_why = "";
      if(MBFastEntryCandidate(fe_dir, fe_why))
      {
         ENUM_OPPORTUNITY_DIR fe_opp = (fe_dir > 0) ? OPP_DIR_BUY : OPP_DIR_SELL;
         if(G_OPP_DIR != fe_opp || G_OPP_TYPE == OPP_TYPE_NONE)
            G_OPP_TYPE = OPP_TYPE_TREND_RIDE;
         G_OPP_DIR = fe_opp;
         G_OPP_REASON = fe_why;
         G_SCORE_FINAL = MathMax(G_SCORE_FINAL, MBFastEntryScore(G_SCORE_MIN_REQUIRED));
         G_SCORE_DECISION = SCORE_DECISION_PASS;
         G_MB_FAST_ACTIVE = true;
         DecisionLog("FAST", fe_why);
      }
   }

   if(G_SCORE_DECISION != SCORE_DECISION_PASS && G_SCORE_DECISION != SCORE_DECISION_MICRO_PASS)
   {
      reason = "score not passed";

      // BOSQICH 4 (kuzatuv): ball talabdan 1-2 ga yetmay qolgan setup - yo'qotilgan savdoning eng
      // aniq nomzodi. Uning har bir bonus va jazosi G_SCORE_DETAIL da bor - endi logga yoziladi.
      // Savdoga ta'siri yo'q. Bir barda bir marta, yo'nalish bo'yicha.
      if(LogNearMiss && G_OPP_DIR != OPP_DIR_NONE && G_SCORE_MIN_REQUIRED > 0 &&
         G_SCORE_DECISION == SCORE_DECISION_WAIT &&
         G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED - MathMax(1, NearMissPoints))
      {
         static int nm_bar = -100000;
         static int nm_dir = 0;
         if(nm_bar > G_BARS_SEEN) nm_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
         int d_now = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : -1;
         if(nm_bar != G_BARS_SEEN || nm_dir != d_now)
         {
            nm_bar = G_BARS_SEEN;
            nm_dir = d_now;
            G_NEAR_MISS_TODAY++;
            PrintFormat("[SIRUS NEAR-MISS] %s %s %d/%d (base %d bonus %d penalty %d) | %s",
                        (d_now > 0 ? "BUY" : "SELL"), OpportunityTypeToString(G_OPP_TYPE),
                        G_SCORE_FINAL, G_SCORE_MIN_REQUIRED,
                        G_SCORE_BASE, G_SCORE_BONUS, G_SCORE_PENALTY, G_SCORE_DETAIL);
         }
      }
      return false;
   }

   // v291b: JOY HIMOYASI - ball o'tgandan keyin, savdo yuborilishidan oldin, oxirgi savol.
   if(EnableLocationGuard && !MBOwnsGate(true))
   {
      int lg_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      string lg_why = "";
      bool lg_level_block = false;
      bool lg_refused = false;
      if(lg_dir != 0)
      {
         if(LocationZoneRefuses(lg_dir, lg_why)) { lg_refused = true; lg_level_block = true; }
         else if(LGFreshImpulse(lg_dir, lg_why) || LGChasingImpulse(lg_dir, lg_why) || LGMicroTip(lg_dir, lg_why))
            lg_refused = true;
      }
      // BOSQICH 7: daraja sababli to'silgan bo'lsa - teskari yo'nalish (darajadan qaytish) tekshiriladi
      string lg_redir = "";
      if(lg_refused && lg_level_block && TryLocationRedirect(lg_dir, lg_redir))
         lg_refused = false;   // teskari yo'nalish toza joyda va ball o'tdi - davom etamiz
      if(lg_refused)
      {
         reason = "location: " + lg_why;
         {
            static int lg_cnt_bar = -100000;
            if(lg_cnt_bar > G_BARS_SEEN) lg_cnt_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
            if(lg_cnt_bar != G_BARS_SEEN) { lg_cnt_bar = G_BARS_SEEN; G_LOCATION_BLOCKS_TODAY++; }
         }
         if((LGPrintOnUse && VerboseLogs))
         {
            static int lg_print_bar = -100000;
            if(lg_print_bar > G_BARS_SEEN) lg_print_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
            if(lg_print_bar != G_BARS_SEEN) { lg_print_bar = G_BARS_SEEN; PrintFormat("[SIRUS LOCATION] %s", lg_why); }
         }
         return false;
      }
   }

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS && !G_MICRO_READY)
   {
      reason = "micro guard not ready: " + G_MICRO_REASON;
      return false;
   }

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
   {
      reason = "no direction";
      return false;
   }

   if(OneBasketAtATime && HasOpenNaviusPosition())
   {
      reason = StringFormat("existing Navius position count=%d", CountNaviusPositions());
      return false;
   }

   int bars_since_entry = G_BARS_SEEN - G_LAST_ENTRY_BAR;
   if(G_LAST_ENTRY_BAR > -9999 && FirstEntryCooldownBars > 0 && bars_since_entry < FirstEntryCooldownBars)
   {
      reason = StringFormat("entry cooldown bars %d/%d", bars_since_entry, FirstEntryCooldownBars);
      return false;
   }

   int seconds_since_entry = (G_LAST_ENTRY_TIME <= 0 ? 999999 : (int)(TimeCurrent() - G_LAST_ENTRY_TIME));
   if(MinSecondsBetweenEntries > 0 && seconds_since_entry < MinSecondsBetweenEntries)
   {
      reason = StringFormat("entry cooldown seconds %d/%d", seconds_since_entry, MinSecondsBetweenEntries);
      return false;
   }

   string op_entry_reason = "";
   if(!OperatorControlAllowsEntry(op_entry_reason))
   {
      reason = op_entry_reason;
      return false;
   }

   string dpg_entry_reason = "";
   if(!DailyProfitGovernorAllowsEntry(dpg_entry_reason))
   {
      reason = dpg_entry_reason;
      return false;
   }

   string sanity_entry_reason = "";
   if(!SettingsSanityAllowsEntry(sanity_entry_reason))
   {
      reason = sanity_entry_reason;
      return false;
   }

   string license_entry_reason = "";
   if(!LicenseGuardAllowsEntry(license_entry_reason))
   {
      reason = license_entry_reason;
      return false;
   }

   string setupdoc_entry_reason = "";
   if(!SetupDoctorAllowsEntry(setupdoc_entry_reason))
   {
      reason = setupdoc_entry_reason;
      return false;
   }

   string retry_entry_reason = "";
   if(!RetryEngineAllowsFirstEntry(retry_entry_reason))
   {
      reason = retry_entry_reason;
      return false;
   }

   string cal_entry_reason = "";
   if(!EconomicCalendarAllowsEntry(cal_entry_reason))
   {
      reason = cal_entry_reason;
      return false;
   }

   string holiday_entry_reason = "";
   if(!BrokerHolidayAllowsEntry(holiday_entry_reason))
   {
      reason = holiday_entry_reason;
      return false;
   }

   string weekend_entry_reason = "";
   if(!WeekendGuardAllowsEntry(weekend_entry_reason))  // V30.4
   {
      reason = weekend_entry_reason;
      return false;
   }

   // FEATURE(smart-time-filter): block fresh entries in proven-bad hours / weekdays.
   string timefilter_reason = "";
   if(!SmartTimeFilterAllowsEntry(timefilter_reason))
   {
      reason = timefilter_reason;
      return false;
   }

   string freshbar_reason = "";
   if(!FreshBarAllowsEntry(freshbar_reason))  // V30.5
   {
      G_FRESHBAR_DEFER_COUNT++;  // V30.6: measurable, shown in entry detail
      reason = freshbar_reason;
      return false;
   }

   string acct_reason = "";
   if(!AccountModeAllowsTrading(acct_reason))
   {
      reason = acct_reason;
      return false;
   }

   string vel_reason = "";
   if(!VelocityAllowsNewRisk(vel_reason))  // V31.1
   {
      reason = vel_reason;
      return false;
   }

   string drift_reason = "";
   if(!EntryDriftAllows(drift_reason))  // V31.3
   {
      reason = drift_reason;
      return false;
   }

   string m1_reason = "";
   if(!M1EntryCloseAllows(m1_reason))
   {
      reason = m1_reason;
      return false;
   }

   // DIRECTION CLARITY: how close the other side came. The engine knew both best scores all along
   // and never used the gap - a BUY at eight against a SELL at seven is a coin on its edge, and a
   // coin on its edge should cost something rather than nothing.
   if(EnableDirectionClarity && !MBOwnsGate(false) && !ValveIsOff(VALVE_CLARITY) && G_OPP_DIR_CLARITY > 0.0 &&
      G_OPP_DIR_CLARITY < ClarityLowBelow && ClarityScoreCost > 0)
   {
      if(G_SCORE_FINAL < G_SCORE_MIN_REQUIRED + ClarityScoreCost)
      {
         reason = StringFormat("score %d, direction contested (%.0f%% clear)",
                               G_SCORE_FINAL, G_OPP_DIR_CLARITY * 100.0);
         DecisionLog("HOLD", reason);
         return false;
      }
   }

   // SCENARIO: what reactions at this level usually give. A pull on the score, not a gate - there
   // are eleven gates already and a twelfth would be the one that stops the robot trading. A strong
   // record adds; a shallow one takes away, and either way the trade can still clear on its own
   // merits.
   if(EnableScenario && ScenEntryScoreWeight > 0 && !ValveIsOff(VALVE_SCENARIO))
   {
      int se_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(se_dir != 0)
      {
         int se_n = 0;
         double se_proj = ScenarioProjection(se_dir, se_n);

         if(se_n >= ScenarioMinSamples && se_proj > 0.0)
         {
            // Measured against the midpoint of what counts as shallow and what counts as room.
            double mid_atr = (ScenGridMinATR + ScenarioShallowATR) * 0.5;
            double t = (se_proj - mid_atr) / MathMax(0.1, ScenGridMinATR);
            t = MathMax(-1.0, MathMin(1.0, t));

            int adj = (int)MathRound(t * (double)ScenEntryScoreWeight);
            if(adj != 0)
            {
               G_SCORE_FINAL += adj;
               if((ScenRecordPrintOnUse && VerboseLogs) && adj < 0)
                  PrintFormat("[SIRUS SCENARIO] %.1f ATR expected here - score %+d", se_proj, adj);
            }
         }
      }
   }

   // FAILED BREAK: the impulse went through and the close came back. Selling under support that
   // just held is the trade everyone trapped under it already made.
   if(EnableFailedBreakGuard && !MBOwnsGate(false) && !ValveIsOff(VALVE_FAILEDBREAK))
   {
      int fb_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(fb_dir != 0)
      {
         string fb_why = "";
         int fb_cost = FailedBreakCost(fb_dir, fb_why);

         if(fb_cost > 0 && G_SCORE_FINAL < G_SCORE_MIN_REQUIRED + fb_cost)
         {
            reason = StringFormat("score %d, %s", G_SCORE_FINAL, fb_why);
            DecisionLog("HOLD", reason);
            return false;
         }
      }
   }

   // OLD LEVEL: a breakout heading into something from weeks ago. The recent high it just cleared
   // was never the destination - the stops above it were, and the level beyond is where the move
   // was always going to end.
   if(EnableOldLevelGuard && !MBOwnsGate(false) && !ValveIsOff(VALVE_OLDLEVEL))
   {
      int ol_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(ol_dir != 0)
      {
         string ol_why = "";
         int ol_cost = OldLevelCost(ol_dir, ol_why);

         if(ol_cost > 0 && G_SCORE_FINAL < G_SCORE_MIN_REQUIRED + ol_cost)
         {
            reason = StringFormat("score %d, %s", G_SCORE_FINAL, ol_why);
            DecisionLog("HOLD", reason);
            return false;
         }
      }
   }

   // HTF BIAS: the score a counter-trend setup has to find. Not a refusal - a price, and one that
   // scales with how convincingly the larger timeframes have moved. A marginal daily costs almost
   // nothing; a daily that has run hard costs real score.
   // A direction question: kept unless the Market Brain is with the trade (MBOwnsGate(true)).
   if(EnableHTFBias && !MBOwnsGate(true) && !ValveIsOff(VALVE_HTF))
   {
      int htf_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(htf_dir != 0)
      {
         double htf_loc = 0.0;
         string htf_why = "";
         int htf_cost = HTFAgainstCost(htf_dir, htf_loc, htf_why);

         if(htf_cost > 0 && G_SCORE_FINAL < G_SCORE_MIN_REQUIRED + htf_cost)
         {
            reason = StringFormat("score %d, %s", G_SCORE_FINAL, htf_why);
            DecisionLog("HOLD", reason);
            return false;
         }
      }
   }

   // S-FIX: news through the owner, so entry and grid read the same answer.
   if(EnableNewsOwner)
   {
      string no_why = "";
      if(NewsOwnerBlocksEntry(no_why))
      {
         reason = no_why;
         DecisionLog("BLOCK", no_why);
         return false;
      }
   }

   // LOCATION BRAIN — the last word. Every other gate has passed: the score, the risk, the zone,
   // the velocity. What none of them asked is whether this is a good PLACE for this direction
   // right now, and that is what a SELL at the bottom of a four-dollar fall gets wrong - there was
   // no level there, nothing to refuse, and price turned anyway because the move was stretched.
   //
   // Held, not refused. The arming engine releases it when price comes back to somewhere worth
   // paying, so the setup is bought cheaper rather than lost.
   if(EnableLocationBrain && !MBOwnsGate(true) && !ValveIsOff(VALVE_LOCATION))
   {
      int lb_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(lb_dir != 0)
      {
         string lb_why = "";
         int lb_v = LocationBrainVerdict(lb_dir, lb_why);

         if(lb_v != LB_OK)
         {
            G_LB_HELD++;

            if((LocationBrainPrintOnUse && VerboseLogs) && (G_LB_HELD % 20) == 1)
               PrintFormat("[SIRUS BRAIN] holding %s - %s", (lb_dir > 0 ? "BUY" : "SELL"), lb_why);

            reason = "waiting for a better place: " + lb_why;
            DecisionLog("HOLD", lb_why);
            return false;
         }

         G_LB_HELD = 0;
      }
   }

   // MARKET BRAIN VETO (engine plan, phase 4) - after everything else, so it judges the final
   // direction. Refuses only on strong contrary evidence: a confirmed liquidity reversal, a zone
   // whose history does not give it the role this entry needs, no room before a level that holds,
   // or a move accelerating the other way.
   {
      int mb_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      string mb_why = "";
      if(!MBVetoAllowsEntry(mb_dir, mb_why))
      {
         reason = "market brain veto: " + mb_why;
         DecisionLog("VETO", mb_why);
         return false;
      }
      // ENTRY JUDGE (phases 5-6): right place and right moment - EXECUTE, CAUTION (smaller lot) or WAIT.
      string mb_jwhy = "";
      if(!MBEntryJudgeAllows(mb_dir, mb_jwhy))
      {
         reason = "entry judge: wait - " + mb_jwhy;
         DecisionLog("WAIT", mb_jwhy);
         return false;
      }
   }

   reason = "entry allowed";
   DecisionLog("OPEN", "all gates passed");
   return true;
}

void UpdateFirstEntryEngine(const string source)
{
   string reason = "";
   G_ENTRY_READY = FirstEntryCanRun(reason);

   // GATE REGISTRY: every refusal passes through here, which is what makes one line worth more
   // than seventy-one scattered ones. The reason text is already written; this turns it into a
   // name and a counter.
   if(!G_ENTRY_READY)
      GateRecord(G_OPP_DIR != OPP_DIR_NONE ? reason : "no setup: " + reason);
   MBShadowOnDecision(G_ENTRY_READY, reason);   // stage 12: follow the refused setup in the shadows

   // And how long it has been since anything got through. Eleven guards that do not know about
   // each other can add up to silence without any one of them being wrong.
   QuietTick(G_ENTRY_READY);

   DecisionChainLog(G_ENTRY_READY, reason);   // BOSQICH 13

   // V248: can the account pay for the whole ladder? GridEffectiveMaxOrders asks this, and it runs
   // from inside GridCanOpen - which means rung two. By then the basket exists, and if the ladder was
   // never affordable the EA finds out halfway up: too deep to close cheaply, too shallow to recover.
   // The question belongs here, where the answer can still be "do not open this".
   // V282: an unaffordable ladder is a reason to trade a SHORTER one, not a reason to skip the trade.
   //
   // The check was built to stop the EA discovering at rung four that the account cannot pay for rung
   // five. It does that - and then refuses the entry entirely, which throws away a setup that every
   // other layer approved because of an arithmetic problem with the last two rungs. The first rung
   // was always affordable; it is the tail that was not.
   //
   // So before refusing, find the deepest ladder the budget does cover and cap the basket there. A
   // three-rung ladder that fits is a trade; a five-rung ladder that does not is nothing.
   if(G_ENTRY_READY && EnableEntryAffordability && EnableAffordableLadderTrim &&
      G_BASKET_ORDERS <= 0)
   {
      int trim_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      if(trim_dir != 0)
      {
         string trim_reason = "";
         if(!LadderIsAffordable(trim_dir, trim_reason))
         {
            int fits = AffordableRungCount(trim_dir);
            if(fits >= MathMax(1, MinAffordableRungs))
            {
               G_AFFORD_RUNG_CAP = fits;
               if((EntryAffordabilityPrintOnUse && VerboseLogs))
                  PrintFormat("[SIRUS v282 TRIM] full ladder does not fit - capping the basket at %d rungs", fits);
            }
         }
         else
            G_AFFORD_RUNG_CAP = 0;      // the full ladder fits; no cap
      }
   }

   if(G_ENTRY_READY && EnableEntryAffordability && !EnableAffordableLadderTrim &&
      G_BASKET_ORDERS <= 0)
   {
      int aff_dir = (G_OPP_DIR == OPP_DIR_BUY) ? 1 : ((G_OPP_DIR == OPP_DIR_SELL) ? -1 : 0);
      string aff_reason = "";
      if(aff_dir != 0 && !LadderIsAffordable(aff_dir, aff_reason))
      {
         G_ENTRY_READY = false;
         reason = aff_reason;
         if((EntryAffordabilityPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v248 AFFORD] %s", aff_reason);
      }
   }


   if(!G_ENTRY_READY)
   {
      // V192: count only refusals that mattered - a gate blocking while there was no setup to take
      // says nothing about why the EA is not trading.
      if(G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS)
      {
         G_FUNNEL_GATE_BLOCK++;
         G_FUNNEL_LAST_GATE = reason;
      }
      G_ENTRY_STATUS = "ENTRY: WAIT | reason=" + reason;
      G_ENTRY_REASON = reason;
      G_ENTRY_DETAIL = StringFormat("ENTRY DETAIL: attempts=%d success=%d fails=%d deferred=%d | positions=%d",
                                    G_ENTRY_ATTEMPTS,
                                    G_ENTRY_SUCCESSES,
                                    G_ENTRY_FAILS,
                                    G_FRESHBAR_DEFER_COUNT,
                                    CountNaviusPositions());

      string signature_wait = G_ENTRY_STATUS + "|" + IntegerToString(G_BARS_SEEN);
      if(PrintEntryDecision && signature_wait != G_ENTRY_LAST_SIGNATURE)
      {
         PrintFormat("[SIRUS v31.6 PHASE 21.3 ENTRY] %s | score=%s final=%d/%d | opp=%s %s %s | source=%s",
                     G_ENTRY_STATUS,
                     ScoreDecisionToString(G_SCORE_DECISION),
                     G_SCORE_FINAL,
                     G_SCORE_MIN_REQUIRED,
                     OpportunityGradeToString(G_OPP_GRADE),
                     OpportunityDirToString(G_OPP_DIR),
                     OpportunityTypeToString(G_OPP_TYPE),
                     source);
         G_ENTRY_LAST_SIGNATURE = signature_wait;
      }

      if(G_ENV_READY)
         SetStatus("CORE + ENV + MODE + MARKET + SCANNER + SCORE + ENTRY WAIT", "FirstEntryEngine");

      return;
   }

   ENUM_ORDER_TYPE order_type = (G_OPP_DIR == OPP_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double price = 0.0, sl = 0.0, tp = 0.0;

   if(!BuildEntryPrices(order_type, price, sl, tp))
   {
      G_ENTRY_FAILS++;
      G_ENTRY_STATUS = "ENTRY: BLOCK | reason=failed to build prices";
      G_ENTRY_REASON = "failed to build prices";
      G_ENTRY_DETAIL = "ENTRY DETAIL: bid/ask unreadable";
      SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
      return;
   }

   string level_reason = "";
   if(!CheckStopFreezeDistance(order_type, price, sl, tp, level_reason))
   {
      G_ENTRY_STATUS = "ENTRY: BLOCK | reason=" + level_reason;
      G_ENTRY_REASON = level_reason;
      G_ENTRY_DETAIL = StringFormat("ENTRY DETAIL: price=%.2f sl=%.2f tp=%.2f", price, sl, tp);
      SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
      return;
   }

   double lot = LotForCurrentEntry();
   string comment = BuildOrderComment();

   // V30 new: margin pre-check (no silent block - full reason shown on dashboard/log).
   string margin_reason = "";
   if(!MarginAllowsOrder(order_type, lot, margin_reason))
   {
      G_ENTRY_STATUS = "ENTRY: BLOCK | reason=" + margin_reason;
      G_ENTRY_REASON = margin_reason;
      G_ENTRY_DETAIL = StringFormat("ENTRY DETAIL: lot=%.2f | free=%.2f | equity=%.2f",
                                    lot,
                                    AccountInfoDouble(ACCOUNT_MARGIN_FREE),
                                    AccountInfoDouble(ACCOUNT_EQUITY));
      SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
      return;
   }

   // V169: stagger entries across rented copies. Fifty accounts firing on the same signal in the
   // same second compete for the same liquidity and every one of them gets a worse fill. The offset
   // is derived from the account number, so each copy waits a different, consistent number of ticks
   // rather than all of them re-rolling the same dice and colliding anyway.
   //
   // FIX(rental-delay-after-send): this block used to sit BELOW the Buy/Sell call. The delay it is
   // supposed to apply therefore never applied to anything - the order had already gone - and its
   // `return` fired with a live position on the account, skipping the ENTIRE `if(sent)` block:
   // G_LAST_ENTRY_TIME / G_LAST_ENTRY_BAR (so MinSecondsBetweenEntries and FirstEntryCooldownBars
   // were defeated for the next basket), SetBasketThesis, ChooseLadderShape, the
   // G_BASKET_MODE_FROZEN grid-profile freeze, G_SCALEIN_EXTRA_ORDERS, ScaleInArm (leaving an
   // armed pending lot with no direction - see the scale-in fixes), G_LAST_ENTRY_TICKET, slippage
   // recording and ClearSignalQueue("entry sent"). RentalEntryDelayTicks() is
   // `ACCOUNT_LOGIN % (RentalSpreadMaxTicks + 1)`, non-zero for two account numbers in three, so
   // most installs hit this on every other basket. Moved above the send, where it belongs.
   if(EnableRentalSpread)
   {
      // G_TICK_COUNT is ulong, so the counter and the comparison stay ulong - narrowing it to int
      // would overflow on a long-running terminal and silently break the stagger.
      static ulong rental_armed_tick = 0;
      int rental_delay = RentalEntryDelayTicks();
      if(rental_delay > 0)
      {
         if(rental_armed_tick == 0)
            rental_armed_tick = G_TICK_COUNT;
         if(rental_armed_tick > G_TICK_COUNT)   // OnInit zeroed G_TICK_COUNT while the static survived
            rental_armed_tick = G_TICK_COUNT;
         if((G_TICK_COUNT - rental_armed_tick) < (ulong)rental_delay)
         {
            // Say what is actually happening. G_ENTRY_STATUS is not written on the ready path, so
            // publishing it unchanged here would repeat the PREVIOUS basket's "SENT BUY ..." line
            // while this tick is deliberately sending nothing.
            G_ENTRY_STATUS = StringFormat("ENTRY: RENTAL STAGGER | waiting %I64u/%d ticks",
                                          G_TICK_COUNT - rental_armed_tick, rental_delay);
            G_ENTRY_REASON = "rental stagger delay";
            SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
            return;                       // still waiting out this copy's offset - NOTHING sent yet
         }
         rental_armed_tick = 0;
      }
   }

   // ================== V31.3 SMART FILL ==================
   // Barcha gate'lar va margin o'tdi - endi kirish LAHZASINI optimallash.
   // Timeout mavjudligi tufayli savdo hech qachon yo'qolmaydi, faqat kechikadi (max 12s).
   if(EnableSmartFill)
   {
      double sf_bid = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_BID, sf_bid);
      int sf_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      int sf_dir_now = (order_type == ORDER_TYPE_BUY ? 1 : -1);
      datetime sf_now = TimeCurrent();

      if(G_SF_ACTIVE && (sf_dir_now != G_SF_DIR || (sf_now - G_SF_ARM_TIME) > SmartFillTimeoutSec * 3))
         G_SF_ACTIVE = false; // yo'nalish o'zgardi yoki eskirib qoldi - qayta qurollanadi

      if(!G_SF_ACTIVE)
      {
         G_SF_ACTIVE     = true;
         G_SF_DIR        = sf_dir_now;
         G_SF_ARM_TIME   = sf_now;
         G_SF_ARM_BID    = sf_bid;
         G_SF_ARM_SPREAD = sf_spread;
         G_ENTRY_STATUS  = StringFormat("ENTRY: SMARTFILL armed | waiting pullback %dpts / spread-dip %dpts / timeout %ds",
                                        SmartFillPullbackPoints, SmartFillSpreadDipPoints, SmartFillTimeoutSec);
         SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
         return;
      }

      bool sf_timeout  = ((sf_now - G_SF_ARM_TIME) >= MathMax(2, SmartFillTimeoutSec));
      double sf_pull   = (G_SF_DIR > 0 ? (G_SF_ARM_BID - sf_bid) : (sf_bid - G_SF_ARM_BID)) / _Point;
      bool sf_pullback = (SmartFillPullbackPoints > 0 && sf_pull >= (double)SmartFillPullbackPoints);
      bool sf_spreddip = (SmartFillSpreadDipPoints > 0 && (G_SF_ARM_SPREAD - sf_spread) >= SmartFillSpreadDipPoints);

      if(!sf_timeout && !sf_pullback && !sf_spreddip)
      {
         G_ENTRY_STATUS = StringFormat("ENTRY: SMARTFILL waiting | pull=%.0f/%d | spread %d->%d | %ds left",
                                       sf_pull, SmartFillPullbackPoints,
                                       G_SF_ARM_SPREAD, sf_spread,
                                       (int)(SmartFillTimeoutSec - (sf_now - G_SF_ARM_TIME)));
         SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
         return;
      }

      // Kirish sharti bajarildi
      G_SF_ACTIVE = false;
      G_SF_FILL_COUNT++;
      if(sf_pullback && sf_pull > 0.0)
         G_SF_SAVED_POINTS += sf_pull;
      if((SmartFillPrintOnUse && VerboseLogs))
         PrintFormat("[SIRUS v31.3 SMARTFILL] fire: %s | pull=%.0f pts | spread %d->%d | fills=%d savedTotal=%.0f pts",
                     (sf_pullback ? "PULLBACK" : (sf_spreddip ? "SPREAD-DIP" : "TIMEOUT")),
                     sf_pull, G_SF_ARM_SPREAD, sf_spread, G_SF_FILL_COUNT, G_SF_SAVED_POINTS);
   }


   G_TRADE.SetExpertMagicNumber(MagicNumber);
   G_TRADE.SetDeviationInPoints(OrderSendDeviationPoints);
   G_TRADE.SetTypeFillingBySymbol(_Symbol);

   G_ENTRY_ATTEMPTS++;

   // V169: the price we would have got had the fill been instant - the gap between this and the actual
   // fill is what slippage costs, and it is invisible unless someone writes it down.
   // FIX(slippage-after-send): this was read AFTER Buy()/Sell() returned, i.e. the quote after the fill,
   // which measured the market's move during the round trip rather than the slippage on this order.
   double slip_requested = (order_type == ORDER_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool sent = false;
   if(order_type == ORDER_TYPE_BUY)
      sent = G_TRADE.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   else
      sent = G_TRADE.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   int retcode = (int)G_TRADE.ResultRetcode();
   string ret_desc = G_TRADE.ResultRetcodeDescription();
   sent = sent && TradeRetcodeFilled((uint)retcode);   // FIX(sent-is-not-filled)

   // FIX(partial-fill-ignored): CTrade::Buy/Sell return true for TRADE_RETCODE_DONE_PARTIAL as well
   // as DONE, and SetTypeFillingBySymbol() selects IOC on symbols that only allow it - IOC being
   // precisely the mode that produces partial fills. ResultVolume() was never read anywhere in this
   // file, so a partial fill was logged and recorded as a full one, and ScaleInArm() below would arm
   // the held-back remainder against a first part that never fully opened. Fold the shortfall back
   // into what scale-in still owes, so the two halves still add up to the intended commitment, and
   // record what ACTUALLY opened rather than what was asked for.
   if(sent)
   {
      double filled_volume = G_TRADE.ResultVolume();
      if(filled_volume > 0.0 && filled_volume < lot - 0.0000001)
      {
         double short_by = lot - filled_volume;
         PrintFormat("[SIRUS PARTIAL FILL] requested %.2f, filled %.2f (short %.2f) | ret=%d %s",
                     lot, filled_volume, short_by, retcode, ret_desc);
         if(EnableScaleIn && G_SCALEIN_PENDING_LOT > 0.0)
            G_SCALEIN_PENDING_LOT = NormalizeVolumeSafe(G_SCALEIN_PENDING_LOT + short_by);
         lot = filled_volume;
      }
   }

   if(sent)
   {
      G_ENTRY_SUCCESSES++;
      G_FUNNEL_ENTRIES++;
      G_LAST_ENTRY_TIME = TimeCurrent();
      G_LAST_ENTRY_BAR = G_BARS_SEEN;

      // FIX(first-entry-direction-stale): these two read G_BASKET_DIRECTION, but at this instant it
      // is still the value RefreshGridDashboardStats() wrote for an EMPTY account earlier in the
      // same tick: -1. POSITION_TYPE_BUY is 0, so the two-way test classified -1 as "not BUY" and
      // BOTH lines produced -1 on EVERY first entry. SELL happened to be right; BUY was inverted.
      //
      // What that cost a BUY basket:
      //   SetBasketThesis(-1) placed the invalidation on a SHORT's wrong side - ABOVE entry. The
      //   thesis-wrong-side guard inside it does not catch that, because for dir=-1 a level above
      //   price is exactly what it expects. BasketPremiseDead() then reads the by-then-correct
      //   direction (+1) and finds price already below the invalidation, so it latches
      //   G_BASKET_PREMISE_DEAD on the FIRST bar close - and GridCanOpen() refuses every rung for
      //   the rest of that basket's life. A BUY entered with any qualifying level 700-4000 points
      //   overhead lost its entire recovery ladder, silently, while the position stayed open.
      //   ChooseLadderShape(-1) anchored on resistance ABOVE price for a ladder that adds downward,
      //   and measured RegimeContradiction the wrong way - so the survival shape and the lean-on-a-
      //   level shape were handed out backwards for BUY.
      // order_type is the authoritative direction here; ScaleInArm below already uses G_OPP_DIR for
      // the same reason.
      int entry_dir_now = (order_type == ORDER_TYPE_BUY) ? 1 : -1;

      // V269: remember which setup opened this basket, so the outcome can be attributed to it.
      if(G_BASKET_ORDERS <= 1)
         G_BASKET_OPP_TYPE = G_OPP_TYPE;

      // V247: and record what this basket is betting on, with the price that would disprove it.
      if(G_BASKET_ORDERS <= 1)
         SetBasketThesis(entry_dir_now);

      // V241: choose the ladder's shape now, while there is still a choice. After the first rung
      // every later one is constrained by the ones before it.
      if(G_BASKET_ORDERS <= 1)
         ChooseLadderShape(entry_dir_now);

      // V228: remember the conditions this basket was built for, so it can be recognised later when
      // they no longer hold.
      if(G_BASKET_ORDERS <= 1)
      {
         int bo_mins = 0;
         string bo_sd = "";
         G_BASKET_OPEN_SESSION = EnableSessionContext ? SessionContext(bo_mins, bo_sd) : -1;
         G_BASKET_TARGET_LEVEL = (G_LS_INVALIDATE > 0.0) ? G_LS_INVALIDATE : 0.0;
         G_BASKET_STALENESS = 0.0;
      }
      G_LAST_ENTRY_TICKET = G_TRADE.ResultOrder();
      ReasonCodeEntry("FIRST", order_type, lot, G_TRADE.ResultPrice(), G_LAST_ENTRY_TICKET);
      MBMemoryOnEntry((order_type == ORDER_TYPE_BUY ? 1 : -1), G_TRADE.ResultPrice());
      MBFastEntryFilled();
      MBShadowOnEntry((order_type == ORDER_TYPE_BUY ? 1 : -1), G_TRADE.ResultPrice());
      if(EnableSlippageTracking)
      {
         double slip_filled = G_TRADE.ResultPrice();
         int    slip_dir = (order_type == ORDER_TYPE_BUY) ? 1 : -1;
         if(slip_filled > 0.0 && slip_requested > 0.0)
            SlippageRecord(slip_requested, slip_filled, slip_dir);
      }
      G_FIRST_LAST_FAIL_TIME = 0;
      G_FIRST_TRANSIENT_RETRY_COUNT = 0;

      // V29 fix: lock the grid profile mode for this basket's whole lifetime.
      G_BASKET_FROZEN_MODE = G_ACTIVE_MODE;
      G_BASKET_MODE_FROZEN = true;

      // V29 new (D-block): remember which detector opened this basket, for Bayes tracking.
      G_BASKET_OPENING_TYPE = G_OPP_TYPE;

      // V153/V155/V157: and the rest of the context this basket was opened in, so its outcome can
      // be credited back to the score band, the warnings that were live, and the regime in force.
      G_BASKET_OPENING_SCORE = G_SCORE_FINAL;
      // Clamped at 0: a basket opened BELOW its bar (safety valve, counter-trend valve, legacy
      // recalculation) would otherwise carry a negative margin, and ScoreBandIndex drops those -
      // silently discarding the outcomes of the most informative trades in the set.
      G_BASKET_OPENING_MARGIN = MathMax(0, G_SCORE_FINAL - G_SCORE_MIN_REQUIRED);   // V249fix(auto-mode): mode-invariant
      G_BASKET_WARNINGS      = G_ENTRY_WARNINGS;
      G_BASKET_REGIME        = G_REGIME;
      G_BASKET_OPEN_BAR      = G_BARS_SEEN;
      G_SCALEIN_EXTRA_ORDERS = 0;
      if(EnableScaleIn && G_SCALEIN_PENDING_LOT > 0.0)
      {
         double si_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double si_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         int    si_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : -1);
         double si_px  = (si_dir > 0) ? si_ask : si_bid;
         ScaleInArm(si_dir, si_px, G_SCALEIN_PENDING_LOT);
      }

      // V31.6j new: remember the nearest zone level at open, for Per-Zone Reliability tracking.
      if(EnableZoneReliability)
      {
         double zbid = 0.0, zask = 0.0;
         SymbolInfoDouble(_Symbol, SYMBOL_BID, zbid);
         SymbolInfoDouble(_Symbol, SYMBOL_ASK, zask);
         double zmid = (zbid > 0.0 && zask > 0.0) ? (zbid + zask) / 2.0 : zbid;
         if(zmid > 0.0)
         {
            double zsup = ZoneMapNearestSupport(zmid);
            double zres = ZoneMapNearestResistance(zmid);
            double dist_sup = (zsup > 0.0) ? (zmid - zsup) : 999999999.0;
            double dist_res = (zres > 0.0) ? (zres - zmid) : 999999999.0;
            G_BASKET_OPENING_ZONE_LEVEL = (dist_sup <= dist_res) ? zsup : zres;
         }
      }

      if(G_QUEUE_ACTIVE)
         ClearSignalQueue("entry sent");

      G_ENTRY_STATUS = StringFormat("ENTRY: SENT %s | lot=%.2f | tp=%.2f | sl=%.2f | ticket=%I64u",
                                    OpportunityDirToString(G_OPP_DIR),
                                    lot,
                                    tp,
                                    sl,
                                    G_LAST_ENTRY_TICKET);

      G_ENTRY_REASON = "order sent";
      G_ENTRY_DETAIL = StringFormat("ENTRY DETAIL: %s | score=%d/%d | opp=%s | ret=%d %s",
                                    comment,
                                    G_SCORE_FINAL,
                                    G_SCORE_MIN_REQUIRED,
                                    OpportunityTypeToString(G_OPP_TYPE),
                                    retcode,
                                    ret_desc);

      PrintFormat("[SIRUS v31.6 PHASE 21.3 ENTRY SENT] %s | %s",
                  G_ENTRY_STATUS,
                  G_ENTRY_DETAIL);

      if(EnableLotTrace && StringLen(G_LOT_TRACE) > 0)
         PrintFormat("[SIRUS v31.5 LOT TRACE] %s", G_LOT_TRACE); // V31.5

      G_HB_OPEN_HOUR = -1; // V31.1: entry soatini yozib olish
      {
         MqlDateTime hb_now;
         TimeToStruct(TimeCurrent(), hb_now);
         G_HB_OPEN_HOUR = hb_now.hour;
         G_BASKET_OPENING_DOW = hb_now.day_of_week;   // V31.6j: entry kunini yozib olish
      }

      if(PushOnEntry)
         NaviusNotify(G_ENTRY_STATUS); // V30.4

      SetStatus("ENTRY SENT: first entry only, grid not active yet", "FirstEntryEngine");
   }
   else
   {
      G_ENTRY_FAILS++;
      G_ENTRY_STATUS = StringFormat("ENTRY: SEND FAILED %s | lot=%.2f | ret=%d %s",
                                    OpportunityDirToString(G_OPP_DIR),
                                    lot,
                                    retcode,
                                    ret_desc);

      G_ENTRY_REASON = "send failed";
      G_ENTRY_DETAIL = StringFormat("ENTRY DETAIL: price=%.2f sl=%.2f tp=%.2f | comment=%s",
                                    price,
                                    sl,
                                    tp,
                                    comment);

      if(EnableRealRetryEngine)
      {
         bool transient = IsTransientTradeRetcode(retcode);
         G_FIRST_LAST_FAIL_TIME = TimeCurrent();
         G_FIRST_LAST_FAIL_TRANSIENT = transient;
         if(transient)
            G_FIRST_TRANSIENT_RETRY_COUNT++;
         else
            G_FIRST_TRANSIENT_RETRY_COUNT = 0;

         if((RetryPrintOnUse && VerboseLogs))
            PrintFormat("[SIRUS v29 RETRY] first-entry fail ret=%d transient=%s attempt=%d/%d",
                        retcode, YesNoV29(transient), G_FIRST_TRANSIENT_RETRY_COUNT, RetryMaxAttempts);
      }

      PrintFormat("[SIRUS v31.6 PHASE 21.3 ENTRY FAILED] %s | %s",
                  G_ENTRY_STATUS,
                  G_ENTRY_DETAIL);

      SetStatus(G_ENTRY_STATUS, "FirstEntryEngine");
   }
}
