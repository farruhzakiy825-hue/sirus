//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 15_Legacy_Packs                                 |
//| VPS validation, legacy/deep/RC packs, client safety              |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  PHASE 21.3 VPS LIVE VALIDATION
//==================================================================//
string BuildFinalNoTradeReason()
{
   if(!G_ENV_READY)
      return "NO TRADE: ENV not ready | " + G_ENV_BLOCK_REASON;

   if(G_LEGACY_HARD_BLOCK)
      return "NO TRADE: legacy hard block | " + G_LEGACY_REASON;

   if(G_RISK_HARD_BLOCK)
      return "NO TRADE: " + G_RISK_STATUS;

   if(G_BASKET_ORDERS > 0)
      return "NO TRADE: basket already active | grid/recovery managing";

   if(G_ENTRY_READY)
      return "TRADE READY: entry engine allowed";

   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
      return "NO TRADE: score hard block | " + G_SCORE_HARD_BLOCK;

   if(G_SCORE_DECISION == SCORE_DECISION_WAIT)
      return StringFormat("NO TRADE: score wait final=%d/%d | opp=%s %s %s",
                          G_SCORE_FINAL,
                          G_SCORE_MIN_REQUIRED,
                          OpportunityGradeToString(G_OPP_GRADE),
                          OpportunityDirToString(G_OPP_DIR),
                          OpportunityTypeToString(G_OPP_TYPE));

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS && !G_MICRO_READY)
      return "NO TRADE: micro guard wait | " + G_MICRO_REASON;

   if(G_OPP_GRADE == OPP_GRADE_NONE)
      return "NO TRADE: no opportunity | market=" + MarketStateToString(G_MARKET_STATE);

   return "NO TRADE: scanning | no final entry permission yet";
}

void UpdateVPSTickWindow()
{
   datetime now = TimeLocal();

   if(G_VPS_TICK_WINDOW_START <= 0)
   {
      G_VPS_TICK_WINDOW_START = now;
      G_VPS_TICK_WINDOW_COUNT = 0;
   }

   G_VPS_TICK_WINDOW_COUNT++;

   int elapsed = (int)(now - G_VPS_TICK_WINDOW_START);
   if(elapsed >= 60)
   {
      G_VPS_TICKS_PER_MINUTE = (int)G_VPS_TICK_WINDOW_COUNT;
      G_VPS_TICK_WINDOW_START = now;
      G_VPS_TICK_WINDOW_COUNT = 0;
   }
}

bool VPSCheckBroker(string &reason)
{
   string parts = "";
   bool ok = true;

   if(G_LAST_SPREAD_POINTS < 0)
   {
      ok = false;
      parts += "spread unreadable; ";
   }
   else
      parts += StringFormat("spread=%d; ", G_LAST_SPREAD_POINTS);

   long trade_mode = 0;
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode))
      parts += StringFormat("tradeMode=%d; ", (int)trade_mode);
   else
   {
      ok = false;
      parts += "tradeMode unreadable; ";
   }

   long stop_level = 0;
   long freeze_level = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stop_level);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);
   parts += StringFormat("stop=%d freeze=%d; ", (int)stop_level, (int)freeze_level);

   double vmin=0.0, vmax=0.0, vstep=0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, vmin);
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, vmax);
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, vstep);
   parts += StringFormat("lot %.2f-%.2f step %.2f; ", vmin, vmax, vstep);

   if(RequireTradePermission)
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      {
         ok = false;
         parts += "terminal trade disabled; ";
      }

      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         ok = false;
         parts += "MQL trade disabled; ";
      }

      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      {
         ok = false;
         parts += "account trade disabled; ";
      }
   }

   reason = parts;
   return ok;
}

void UpdateVPSLiveValidation(const string source)
{
   if(!UseVPSLiveValidation)
   {
      G_VPS_OK = true;
      G_VPS_STATUS = "VPS: OFF";
      G_VPS_REASON = "UseVPSLiveValidation=false";
      G_VPS_DETAIL = "VPS DETAIL: disabled";
      G_VPS_NO_TRADE_REASON = BuildFinalNoTradeReason();
      return;
   }

   UpdateVPSTickWindow();

   datetime now = TimeLocal();
   if(G_VPS_LAST_CHECK > 0 && (now - G_VPS_LAST_CHECK) < VPSValidationSeconds)
   {
      G_VPS_NO_TRADE_REASON = BuildFinalNoTradeReason();
      return;
   }

   G_VPS_LAST_CHECK = now;
   G_VPS_WARNINGS = 0;

   int tick_age = TickAgeSeconds();
   int bar_age_sec = 999999;
   if(G_LAST_BAR_TIME > 0)
      bar_age_sec = (int)(TimeCurrent() - G_LAST_BAR_TIME);

   bool tick_ok = (tick_age >= 0 && tick_age <= VPSMaxTickSilentSeconds);
   bool bar_ok = (bar_age_sec <= VPSMaxM1BarSilentMinutes * 60);
   bool timer_ok = (G_TIMER_COUNT > 0);

   string broker_reason = "";
   bool broker_ok = VPSCheckBroker(broker_reason);
   G_VPS_BROKER_DETAIL = "BROKER: " + broker_reason;

   if(!tick_ok) G_VPS_WARNINGS++;
   if(!bar_ok) G_VPS_WARNINGS++;
   if(!timer_ok) G_VPS_WARNINGS++;
   if(!broker_ok) G_VPS_WARNINGS++;
   if(VPSWarnIfNotM1Chart && (ENUM_TIMEFRAMES)_Period != PERIOD_M1) G_VPS_WARNINGS++;
   if(G_VPS_TICKS_PER_MINUTE > 0 && G_VPS_TICKS_PER_MINUTE < VPSMinTicksPerMinute) G_VPS_WARNINGS++;

   G_VPS_OK = (G_VPS_WARNINGS == 0);

   G_VPS_REASON = StringFormat("tickAge=%ds/%d | barAge=%ds/%d | tpm=%d | timer=%s | broker=%s",
                               tick_age,
                               VPSMaxTickSilentSeconds,
                               bar_age_sec,
                               VPSMaxM1BarSilentMinutes * 60,
                               G_VPS_TICKS_PER_MINUTE,
                               BoolText(timer_ok),
                               BoolText(broker_ok));

   G_VPS_STATUS = (G_VPS_OK ? "VPS OK" : "VPS WARN: " + G_VPS_REASON);
   G_VPS_DETAIL = StringFormat("VPS DETAIL: local=%s server=%s | chartTF=%s coreTF=%s | warnings=%d",
                               SafeTime(TimeLocal()),
                               SafeTime(TimeCurrent()),
                               TFToString((ENUM_TIMEFRAMES)_Period),
                               TFToString(CoreBarTF),
                               G_VPS_WARNINGS);

   G_VPS_NO_TRADE_REASON = BuildFinalNoTradeReason();

   string signature = G_VPS_STATUS + "|" + G_VPS_NO_TRADE_REASON + "|" + IntegerToString(G_BARS_SEEN);

   if(signature != G_VPS_LAST_SIGNATURE)
   {
      PrintFormat("[SIRUS v31.6 PHASE 21.3 VPS] %s | %s | %s | source=%s",
                  G_VPS_STATUS,
                  G_VPS_DETAIL,
                  G_VPS_NO_TRADE_REASON,
                  source);
      G_VPS_LAST_SIGNATURE = signature;
   }

   if(VPSPrintNoTradeAudit && VPSNoTradeAuditSeconds > 0 && (G_VPS_LAST_AUDIT <= 0 || (now - G_VPS_LAST_AUDIT) >= VPSNoTradeAuditSeconds))
   {
      G_VPS_LAST_AUDIT = now;
      PrintFormat("[SIRUS v31.6 PHASE 21.3 NO-TRADE AUDIT] %s | env=%s | risk=%s | market=%s | opp=%s %s %s score=%s %d/%d | entry=%s",
                  G_VPS_NO_TRADE_REASON,
                  G_ENV_STATUS,
                  G_RISK_STATUS,
                  MarketStateToString(G_MARKET_STATE),
                  OpportunityGradeToString(G_OPP_GRADE),
                  OpportunityDirToString(G_OPP_DIR),
                  OpportunityTypeToString(G_OPP_TYPE),
                  ScoreDecisionToString(G_SCORE_DECISION),
                  G_SCORE_FINAL,
                  G_SCORE_MIN_REQUIRED,
                  G_ENTRY_STATUS);
   }

   if(VPSPrintBrokerSnapshot && VPSBrokerSnapshotSeconds > 0 && (G_VPS_LAST_BROKER_PRINT <= 0 || (now - G_VPS_LAST_BROKER_PRINT) >= VPSBrokerSnapshotSeconds))
   {
      G_VPS_LAST_BROKER_PRINT = now;
      PrintFormat("[SIRUS v31.6 PHASE 21.3 BROKER] %s | symbol=%s | digits=%d point=%.5f | account=%I64d leverage=1:%d",
                  G_VPS_BROKER_DETAIL,
                  _Symbol,
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
                  _Point,
                  (long)AccountInfoInteger(ACCOUNT_LOGIN),
                  (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
   }
}

//==================================================================//
//  PHASE 21.3 LEGACY SIRUS UPGRADE PACK
//==================================================================//
int LegacyDirectionSign()
{
   if(G_OPP_DIR == OPP_DIR_BUY) return 1;
   if(G_OPP_DIR == OPP_DIR_SELL) return -1;
   return 0;
}

string LegacyDirText(const int dir)
{
   if(dir > 0) return "BUY";
   if(dir < 0) return "SELL";
   return "NONE";
}

double LegacyATR(const ENUM_TIMEFRAMES tf)
{
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      atr = ATRPointsManual(SignalTF, ATRPeriod, 1);
   return atr;
}

int LegacyBarsSinceTime(datetime t, ENUM_TIMEFRAMES tf)
{
   if(t <= 0)
      return 999999;

   for(int i=0; i<500; i++)
   {
      datetime bt = iTime(_Symbol, tf, i);
      if(bt <= 0)
         break;
      if(bt <= t)
         return i;
   }
   return 999999;
}

void LegacyAddNearestLevel(const double price, const double current, bool support)
{
   if(price <= 0.0 || current <= 0.0) return;

   double dist = MathAbs(current - price) / _Point;

   if(support && price < current)
   {
      if(G_LEGACY_NEAREST_SUPPORT <= 0.0 || dist < G_LEGACY_SUPPORT_DIST)
      {
         G_LEGACY_NEAREST_SUPPORT = price;
         G_LEGACY_SUPPORT_DIST = dist;
      }
   }

   if(!support && price > current)
   {
      if(G_LEGACY_NEAREST_RESIST <= 0.0 || dist < G_LEGACY_RESIST_DIST)
      {
         G_LEGACY_NEAREST_RESIST = price;
         G_LEGACY_RESIST_DIST = dist;
      }
   }
}

void LegacyBuildSmartSRZones()
{
   G_LEGACY_NEAREST_SUPPORT = 0.0;
   G_LEGACY_NEAREST_RESIST = 0.0;
   G_LEGACY_SUPPORT_DIST = 999999.0;
   G_LEGACY_RESIST_DIST = 999999.0;

   if(!LegacyUseSmartSRZones)
   {
      G_LEGACY_ZONE_STATUS = "ZONE: disabled";
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current = (bid > 0.0 && ask > 0.0 ? (bid + ask) * 0.5 : CandleClose(SignalTF, 1));

   if(current <= 0.0)
   {
      G_LEGACY_ZONE_STATUS = "ZONE: price not ready";
      return;
   }

   int depth = MathMax(1, LegacySRSwingDepth);
   int m15_limit = MathMin(LegacySRLookbackBarsM15, Bars(_Symbol, PERIOD_M15) - depth - 2);
   int h1_limit  = MathMin(LegacySRLookbackBarsH1,  Bars(_Symbol, PERIOD_H1)  - depth - 2);

   for(int i=depth+1; i<m15_limit; i++)
   {
      if(LegacyIsSwingLow(PERIOD_M15, i, depth))
         LegacyAddNearestLevel(CandleLow(PERIOD_M15, i), current, true);
      if(LegacyIsSwingHigh(PERIOD_M15, i, depth))
         LegacyAddNearestLevel(CandleHigh(PERIOD_M15, i), current, false);
   }

   for(int j=depth+1; j<h1_limit; j++)
   {
      if(LegacyIsSwingLow(PERIOD_H1, j, depth))
         LegacyAddNearestLevel(CandleLow(PERIOD_H1, j), current, true);
      if(LegacyIsSwingHigh(PERIOD_H1, j, depth))
         LegacyAddNearestLevel(CandleHigh(PERIOD_H1, j), current, false);
   }

   if(G_LEGACY_NEAREST_SUPPORT <= 0.0 && G_LEGACY_NEAREST_RESIST <= 0.0)
      G_LEGACY_ZONE_STATUS = "ZONE: no swing zones";
   else
      G_LEGACY_ZONE_STATUS = StringFormat("ZONE: S=%.2f %.0fpt | R=%.2f %.0fpt",
                                          G_LEGACY_NEAREST_SUPPORT,
                                          G_LEGACY_SUPPORT_DIST,
                                          G_LEGACY_NEAREST_RESIST,
                                          G_LEGACY_RESIST_DIST);
}

void LegacyDeleteZoneObjects()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, G_PREFIX + "LEGACY_ZONE_") == 0)
         ObjectDelete(0, name);
   }
}

void LegacyDrawZoneLine(const string key, const double price, const color clr)
{
   if(price <= 0.0) return;

   string name = G_PREFIX + "LEGACY_ZONE_" + key;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, name, OBJPROP_TEXT, key);
}

void LegacyDrawSRZoneObjects()
{
   if(!LegacyShowSRZoneLines || !LegacyUseSmartSRZones) return;
   LegacyDrawZoneLine("SUPPORT", G_LEGACY_NEAREST_SUPPORT, clrLime);
   LegacyDrawZoneLine("RESIST",  G_LEGACY_NEAREST_RESIST,  clrTomato);
}

bool LegacyManualNewsBlocked()
{
   if(!LegacyUseManualNewsGuard) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   if(LegacyNewsStartHour == LegacyNewsEndHour) return false;
   if(LegacyNewsStartHour < LegacyNewsEndHour)
      return (h >= LegacyNewsStartHour && h < LegacyNewsEndHour);

   return (h >= LegacyNewsStartHour || h < LegacyNewsEndHour);
}

int LegacySessionScore()
{
   if(!LegacyUseSessionDNA)
   {
      G_LEGACY_SESSION_STATUS = "SESSION: disabled";
      return 0;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   int score = 0;
   string name = "OFF";

   if(h >= LegacyAsiaStartHour && h < LegacyLondonStartHour)
   {
      name = "ASIA";
      score = (G_MARKET_STATE == MARKET_RANGE ? 1 : 0);
   }
   else if(h >= LegacyLondonStartHour && h < LegacyNYStartHour)
   {
      name = "LONDON";
      score = (G_MARKET_STATE == MARKET_TREND_UP || G_MARKET_STATE == MARKET_TREND_DOWN || G_MARKET_STATE == MARKET_PULLBACK ? 1 : 0);
   }
   else
   {
      name = "NEW_YORK";
      score = (G_MARKET_STATE == MARKET_IMPULSE ? -1 : 1);
   }

   G_LEGACY_SESSION_STATUS = StringFormat("SESSION: %s | score=%d | serverHour=%d", name, score, h);
   return score;
}

bool LegacyLiquiditySweepForDir(const int dir, string &reason)
{
   if(!LegacyUseLiquiditySweep || dir == 0)
   {
      reason = "sweep disabled/no dir";
      return false;
   }

   int lookback = MathMax(3, LegacySweepLookbackBars);
   double prior_high = HighestHigh(SignalTF, lookback, 2);
   double prior_low  = LowestLow(SignalTF, lookback, 2);
   double h1 = CandleHigh(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double c1 = CandleClose(SignalTF, 1);
   double range = CandleRangePoints(SignalTF, 1);

   if(prior_high <= 0.0 || prior_low <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || range <= 0.0)
   {
      reason = "sweep data not ready";
      return false;
   }

   if(dir > 0)
   {
      double lower = LowerWickPoints(SignalTF, 1);
      bool ok = (l1 < prior_low && c1 > prior_low && lower / range >= 0.30);
      reason = StringFormat("BUY sweep=%s | low=%.2f priorLow=%.2f wick=%.2f", BoolText(ok), l1, prior_low, lower / range);
      return ok;
   }

   double upper = UpperWickPoints(SignalTF, 1);
   bool ok = (h1 > prior_high && c1 < prior_high && upper / range >= 0.30);
   reason = StringFormat("SELL sweep=%s | high=%.2f priorHigh=%.2f wick=%.2f", BoolText(ok), h1, prior_high, upper / range);
   return ok;
}

bool LegacyFakeBreakoutForDir(const int dir, string &reason)
{
   if(!LegacyUseFakeBreakout || dir == 0)
   {
      reason = "fake breakout disabled/no dir";
      return false;
   }

   int lookback = MathMax(6, LegacyBOSLookbackBars);
   double prior_high = HighestHigh(FastContextTF, lookback, 2);
   double prior_low  = LowestLow(FastContextTF, lookback, 2);
   double h1 = CandleHigh(FastContextTF, 1);
   double l1 = CandleLow(FastContextTF, 1);
   double c1 = CandleClose(FastContextTF, 1);

   if(prior_high <= 0.0 || prior_low <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
   {
      reason = "fake breakout data not ready";
      return false;
   }

   if(dir > 0)
   {
      bool ok = (l1 < prior_low && c1 > prior_low);
      reason = StringFormat("BUY fakeBreak=%s | low=%.2f priorLow=%.2f close=%.2f", BoolText(ok), l1, prior_low, c1);
      return ok;
   }

   bool ok = (h1 > prior_high && c1 < prior_high);
   reason = StringFormat("SELL fakeBreak=%s | high=%.2f priorHigh=%.2f close=%.2f", BoolText(ok), h1, prior_high, c1);
   return ok;
}

void LegacyUpdateBOSRetest()
{
   G_LEGACY_BOS_STATUS = "BOS: disabled";
   if(!LegacyUseBOSRetest) return;

   int lookback = MathMax(8, LegacyBOSLookbackBars);
   double high = HighestHigh(StructureTF, lookback, 2);
   double low  = LowestLow(StructureTF, lookback, 2);
   double c1 = CandleClose(StructureTF, 1);

   if(high <= 0.0 || low <= 0.0 || c1 <= 0.0)
   {
      G_LEGACY_BOS_STATUS = "BOS: data not ready";
      return;
   }

   if(c1 > high)
   {
      G_LEGACY_BOS_DIR = 1;
      G_LEGACY_BOS_LEVEL = high;
      G_LEGACY_BOS_TIME = TimeCurrent();
      G_LEGACY_BOS_STATUS = StringFormat("BOS: UP level=%.2f", high);
      return;
   }

   if(c1 < low)
   {
      G_LEGACY_BOS_DIR = -1;
      G_LEGACY_BOS_LEVEL = low;
      G_LEGACY_BOS_TIME = TimeCurrent();
      G_LEGACY_BOS_STATUS = StringFormat("BOS: DOWN level=%.2f", low);
      return;
   }

   if(G_LEGACY_BOS_DIR != 0 && G_LEGACY_BOS_TIME > 0)
   {
      int bars_since = LegacyBarsSinceTime(G_LEGACY_BOS_TIME, SignalTF);
      if(bars_since > LegacyBOSRetestBars)
      {
         G_LEGACY_BOS_DIR = 0;
         G_LEGACY_BOS_LEVEL = 0.0;
         G_LEGACY_BOS_STATUS = "BOS: expired";
      }
      else
      {
         G_LEGACY_BOS_STATUS = StringFormat("BOS: wait retest %s level=%.2f age=%d/%d",
                                            LegacyDirText(G_LEGACY_BOS_DIR),
                                            G_LEGACY_BOS_LEVEL,
                                            bars_since,
                                            LegacyBOSRetestBars);
      }
   }
   else
      G_LEGACY_BOS_STATUS = "BOS: none";
}

bool LegacyBOSRetestForDir(const int dir, string &reason)
{
   if(!LegacyUseBOSRetest || dir == 0 || G_LEGACY_BOS_DIR == 0 || G_LEGACY_BOS_LEVEL <= 0.0)
   {
      reason = "no active BOS";
      return false;
   }

   if(dir != G_LEGACY_BOS_DIR)
   {
      reason = "BOS opposite direction";
      return false;
   }

   double c1 = CandleClose(SignalTF, 1);
   double l1 = CandleLow(SignalTF, 1);
   double h1 = CandleHigh(SignalTF, 1);
   double buffer = MathMax((double)LegacyNearZonePoints, LegacyATR(SignalTF) * 0.35);

   bool touched = false;
   if(dir > 0)
      touched = (l1 <= G_LEGACY_BOS_LEVEL + buffer * _Point && c1 > G_LEGACY_BOS_LEVEL);
   else
      touched = (h1 >= G_LEGACY_BOS_LEVEL - buffer * _Point && c1 < G_LEGACY_BOS_LEVEL);

   reason = StringFormat("BOS retest=%s | dir=%s level=%.2f buffer=%.0f", BoolText(touched), LegacyDirText(dir), G_LEGACY_BOS_LEVEL, buffer);
   return touched;
}

bool LegacyZoneReactionForDir(const int dir, string &reason)
{
   if(!LegacyUseSmartSRZones || dir == 0)
   {
      reason = "zone disabled/no dir";
      return false;
   }

   double range = CandleRangePoints(SignalTF, 1);
   if(range <= 0.0)
   {
      reason = "zone candle not ready";
      return false;
   }

   if(dir > 0)
   {
      bool near_support = (G_LEGACY_NEAREST_SUPPORT > 0.0 && G_LEGACY_SUPPORT_DIST <= LegacyNearZonePoints);
      double lower = LowerWickPoints(SignalTF, 1);
      bool rejection = (lower / range >= 0.28);
      reason = StringFormat("BUY zoneReaction=%s | supportDist=%.0f/%d | wick=%.2f", BoolText(near_support && rejection), G_LEGACY_SUPPORT_DIST, LegacyNearZonePoints, lower / range);
      return (near_support && rejection);
   }

   bool near_resist = (G_LEGACY_NEAREST_RESIST > 0.0 && G_LEGACY_RESIST_DIST <= LegacyNearZonePoints);
   double upper = UpperWickPoints(SignalTF, 1);
   bool rejection = (upper / range >= 0.28);
   reason = StringFormat("SELL zoneReaction=%s | resistDist=%.0f/%d | wick=%.2f", BoolText(near_resist && rejection), G_LEGACY_RESIST_DIST, LegacyNearZonePoints, upper / range);
   return (near_resist && rejection);
}

bool LegacyRoadblockForDir(const int dir, string &reason)
{
   if(!LegacyUseRoadblockGuard || dir == 0)
   {
      reason = "roadblock disabled/no dir";
      return false;
   }

   double tp = (G_SCORE_TP_TARGET > 0.0 ? G_SCORE_TP_TARGET : MainTPPoints());
   double min_room = MathMax((double)LegacyRoadblockMinRoomPts, tp * 0.45);

   if(dir > 0 && G_LEGACY_NEAREST_RESIST > 0.0 && G_LEGACY_RESIST_DIST < min_room)
   {
      reason = StringFormat("BUY roadblock: resistance %.0f < room %.0f", G_LEGACY_RESIST_DIST, min_room);
      return true;
   }

   if(dir < 0 && G_LEGACY_NEAREST_SUPPORT > 0.0 && G_LEGACY_SUPPORT_DIST < min_room)
   {
      reason = StringFormat("SELL roadblock: support %.0f < room %.0f", G_LEGACY_SUPPORT_DIST, min_room);
      return true;
   }

   reason = "no roadblock";
   return false;
}

bool LegacyTrendExhaustionForDir(const int dir, string &reason)
{
   if(!LegacyUseTrendExhaustion || dir == 0)
   {
      reason = "exhaustion disabled/no dir";
      return false;
   }

   double atr = LegacyATR(SignalTF);
   double range = CandleRangePoints(SignalTF, 1);
   double body = CandleBodyPoints(SignalTF, 1);

   if(atr <= 0.0 || range <= 0.0)
   {
      reason = "exhaustion data not ready";
      return false;
   }

   bool big = (range >= atr * 1.8);
   bool weak_body = (body <= range * 0.35);

   if(dir > 0)
   {
      double upper = UpperWickPoints(SignalTF, 1);
      bool risk = (big && weak_body && upper / range >= 0.45);
      reason = StringFormat("BUY exhaustionRisk=%s | range=%.0f atr=%.0f upper=%.2f", BoolText(risk), range, atr, upper/range);
      return risk;
   }

   double lower = LowerWickPoints(SignalTF, 1);
   bool risk = (big && weak_body && lower / range >= 0.45);
   reason = StringFormat("SELL exhaustionRisk=%s | range=%.0f atr=%.0f lower=%.2f", BoolText(risk), range, atr, lower/range);
   return risk;
}

void LegacyApplyScoreChange(const int bonus, const int penalty, const string why)
{
   if(bonus > 0)
   {
      G_SCORE_BONUS += bonus;
      G_SCORE_FINAL += bonus;
      G_LEGACY_BONUS += bonus;
   }

   if(penalty > 0)
   {
      // FIX(cap-bypass): this runs AFTER UpdateSignalScoreEngine has already applied
      // MaxTotalScorePenalty, and it adjusts G_SCORE_FINAL directly - so without honouring the cap
      // here, the legacy packs (deep parity HTF, zone danger, upgrade pack) could push the total
      // penalty straight back past the ceiling and re-create the stacking the cap exists to stop.
      // Only the portion that still fits under the cap is charged; the rest is dropped and logged.
      int allowed = penalty;
      if(MaxTotalScorePenalty > 0)
      {
         int room = MaxTotalScorePenalty - G_SCORE_PENALTY;
         if(room < 0)
            room = 0;
         allowed = (int)MathMin((double)penalty, (double)room);
      }

      if(allowed > 0)
      {
         G_SCORE_PENALTY += allowed;
         G_SCORE_FINAL -= allowed;
         G_LEGACY_PENALTY += allowed;
      }

      if(allowed < penalty)
         G_SCORE_DETAIL = G_SCORE_DETAIL + StringFormat(" [legacy penalty %d capped to %d];", penalty, allowed);
   }

   G_SCORE_DETAIL = G_SCORE_DETAIL + " LEGACY[" + why + "];";
}

void LegacyRecalculateDecision()
{
   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK) return;
   if(G_SCORE_MIN_REQUIRED <= 0) return;

   if(G_SCORE_FINAL >= G_SCORE_MIN_REQUIRED)
   {
      if(IsMicroOpportunity()) G_SCORE_DECISION = SCORE_DECISION_MICRO_PASS;
      else G_SCORE_DECISION = SCORE_DECISION_PASS;
   }
   else
      G_SCORE_DECISION = SCORE_DECISION_WAIT;

   G_SCORE_STATUS = StringFormat("SCORE: %s | final=%d/%d | legacy bonus=%d penalty=%d",
                                 ScoreDecisionToString(G_SCORE_DECISION),
                                 G_SCORE_FINAL,
                                 G_SCORE_MIN_REQUIRED,
                                 G_LEGACY_BONUS,
                                 G_LEGACY_PENALTY);
}

void UpdateLegacyUpgradePack(const string source)
{
   G_LEGACY_APPLIED = false;
   G_LEGACY_HARD_BLOCK = false;
   G_LEGACY_BONUS = 0;
   G_LEGACY_PENALTY = 0;

   if(!UseLegacyUpgradePack)
   {
      G_LEGACY_STATUS = "LEGACY: OFF";
      G_LEGACY_DETAIL = "LEGACY DETAIL: disabled";
      return;
   }

   LegacyBuildSmartSRZones();
   LegacyUpdateBOSRetest();
   LegacyDrawSRZoneObjects();

   int dir = LegacyDirectionSign();
   int session_score = LegacySessionScore();

   string sweep_reason = "", fake_reason = "", zone_reason = "", bos_reason = "", road_reason = "", exh_reason = "";

   bool news_block = LegacyManualNewsBlocked();
   bool sweep_ok = LegacyLiquiditySweepForDir(dir, sweep_reason);
   bool fake_ok = LegacyFakeBreakoutForDir(dir, fake_reason);
   bool zone_ok = LegacyZoneReactionForDir(dir, zone_reason);
   bool bos_ok = LegacyBOSRetestForDir(dir, bos_reason);
   bool roadblock = LegacyRoadblockForDir(dir, road_reason);
   bool exhaustion = LegacyTrendExhaustionForDir(dir, exh_reason);

   G_LEGACY_SWEEP_STATUS = "SWEEP: " + sweep_reason;
   G_LEGACY_FAKE_STATUS = "FAKE: " + fake_reason;
   G_LEGACY_EXH_STATUS = "EXH: " + exh_reason;

   if(news_block && LegacyHardBlockNews)
   {
      G_LEGACY_HARD_BLOCK = true;
      G_SCORE_DECISION = SCORE_DECISION_HARD_BLOCK;
      G_SCORE_HARD_BLOCK = "legacy manual news guard";
      G_SCORE_STATUS = "SCORE: HARD_BLOCK | legacy manual news guard";
      G_SCORE_DETAIL = G_SCORE_DETAIL + " LEGACY[manual news hard block];";
   }

   if(roadblock && LegacyHardBlockRoadblock)
   {
      G_LEGACY_HARD_BLOCK = true;
      G_SCORE_DECISION = SCORE_DECISION_HARD_BLOCK;
      G_SCORE_HARD_BLOCK = "legacy roadblock";
      G_SCORE_STATUS = "SCORE: HARD_BLOCK | legacy roadblock";
      G_SCORE_DETAIL = G_SCORE_DETAIL + " LEGACY[roadblock hard block];";
   }

   if(G_OPP_DIR == OPP_DIR_BUY || G_OPP_DIR == OPP_DIR_SELL)
   {
      if(sweep_ok) LegacyApplyScoreChange(LegacyBoostSweep, 0, "sweep " + sweep_reason);
      if(fake_ok) LegacyApplyScoreChange(LegacyBoostFakeBreakout, 0, "fake " + fake_reason);
      if(zone_ok) LegacyApplyScoreChange(LegacyBoostZoneReaction, 0, "zone " + zone_reason);
      if(bos_ok) LegacyApplyScoreChange(LegacyBoostBOSRetest, 0, "BOS " + bos_reason);

      if(session_score > 0) LegacyApplyScoreChange(session_score, 0, "session " + G_LEGACY_SESSION_STATUS);
      else if(session_score < 0) LegacyApplyScoreChange(0, MathAbs(session_score), "session risk " + G_LEGACY_SESSION_STATUS);

      if(roadblock && !LegacyHardBlockRoadblock) LegacyApplyScoreChange(0, LegacyPenaltyRoadblock, "roadblock " + road_reason);
      if(exhaustion) LegacyApplyScoreChange(0, LegacyPenaltyExhaustion, "exhaustion " + exh_reason);

      LegacyRecalculateDecision();
   }

   G_LEGACY_APPLIED = (G_LEGACY_BONUS > 0 || G_LEGACY_PENALTY > 0 || G_LEGACY_HARD_BLOCK);
   G_LEGACY_REASON = StringFormat("bonus=%d penalty=%d hard=%s", G_LEGACY_BONUS, G_LEGACY_PENALTY, BoolText(G_LEGACY_HARD_BLOCK));
   G_LEGACY_STATUS = "LEGACY: " + G_LEGACY_REASON;
   G_LEGACY_DETAIL = StringFormat("LEGACY DETAIL: %s | %s | %s | %s | %s | %s",
                                  G_LEGACY_ZONE_STATUS,
                                  G_LEGACY_BOS_STATUS,
                                  G_LEGACY_SWEEP_STATUS,
                                  G_LEGACY_FAKE_STATUS,
                                  G_LEGACY_EXH_STATUS,
                                  G_LEGACY_SESSION_STATUS);

   string signature = G_LEGACY_STATUS + "|" + G_LEGACY_DETAIL + "|" + IntegerToString(G_BARS_SEEN) + "|" + ScoreDecisionToString(G_SCORE_DECISION);

   if(PrintLegacyUpgradeEvents && signature != G_LEGACY_LAST_SIGNATURE)
   {
      if(G_LEGACY_APPLIED || G_LEGACY_LAST_SIGNATURE == "")
      {
         G_LEGACY_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 21.3 LEGACY] %s | %s | score=%s %d/%d | source=%s",
                     G_LEGACY_STATUS,
                     G_LEGACY_DETAIL,
                     ScoreDecisionToString(G_SCORE_DECISION),
                     G_SCORE_FINAL,
                     G_SCORE_MIN_REQUIRED,
                     source);
      }
      G_LEGACY_LAST_SIGNATURE = signature;
   }
}

bool LegacyAllowsGrid(string &reason)
{
   if(!UseLegacyUpgradePack)
   {
      reason = "legacy grid pass";
      return true;
   }

   if(G_LEGACY_HARD_BLOCK)
   {
      reason = "legacy hard block: " + G_LEGACY_REASON;
      return false;
   }

   if(G_MARKET_STATE == MARKET_IMPULSE && GridBlockFreshImpulse)
   {
      reason = "legacy grid impulse guard";
      return false;
   }

   reason = "legacy grid pass";
   return true;
}


//==================================================================//
//  PHASE 21.3 STABLE RC BASELINE
//==================================================================//

//==================================================================//
//  PHASE 22.1 PACK4 MINI LICENSE - COMPILE FIX
//==================================================================//
void UpdatePack4MiniLicense(const string source)
{
   G_P4M_VALID = true;
   G_P4M_HARD_BLOCK = false;
   G_P4M_ENTRY_BLOCK = false;
   G_P4M_GRID_BLOCK = false;
   G_P4M_LICENSE_OK = true;
   G_P4M_SYMBOL_OK = true;
   G_P4M_SPREAD_OK = true;

   if(!UsePack4MiniLicense)
   {
      G_P4M_STATUS = "P4M: OFF";
      G_P4M_REASON = "disabled";
      G_P4M_DETAIL = "P4M DETAIL: disabled";
      return;
   }

   string detail = "";

   if(P4MiniUseLicenseControl)
   {
      long login = AccountInfoInteger(ACCOUNT_LOGIN);
      string login_text = SafeLongText(login);
      bool account_ok = true;

      if(StringLen(P4MiniAccountWhitelist) > 0)
      {
         account_ok = false;
         string parts[];
         int count = StringSplit(P4MiniAccountWhitelist, ',', parts);

         for(int i=0; i<count; i++)
         {
            string p = parts[i];
            StringTrimLeft(p);
            StringTrimRight(p);

            if(p == login_text)
            {
               account_ok = true;
               break;
            }
         }
      }

      datetime expire_time = StringToTime(P4MiniExpireDate + " 23:59") + P4MiniGraceDays * 86400;
      if(expire_time <= 0)
         expire_time = D'2099.12.31 23:59';

      G_P4M_EXPIRE_TIME = expire_time;

      bool date_ok = (TimeCurrent() <= expire_time);

      long mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
      bool type_ok = true;

      if(mode == ACCOUNT_TRADE_MODE_DEMO && !P4MiniAllowDemo)
         type_ok = false;
      if(mode == ACCOUNT_TRADE_MODE_REAL && !P4MiniAllowReal)
         type_ok = false;

      G_P4M_LICENSE_OK = (account_ok && date_ok && type_ok);

      detail = detail + StringFormat("license account=%s date=%s type=%s; ",
                                     BoolText(account_ok),
                                     BoolText(date_ok),
                                     BoolText(type_ok));
   }
   else
   {
      detail = detail + "license disabled; ";
   }

   if(P4MiniUseSymbolGuard && P4MiniRequireXAU)
      G_P4M_SYMBOL_OK = (StringFind(_Symbol, P4MiniSymbolKeyword) >= 0);
   else
      G_P4M_SYMBOL_OK = true;

   if(EffSpread(P4MiniMaxSpread) > 0)
      G_P4M_SPREAD_OK = (G_LAST_SPREAD_POINTS <= EffSpread(P4MiniMaxSpread));
   else
      G_P4M_SPREAD_OK = true;

   if(!G_P4M_LICENSE_OK)
   {
      G_P4M_HARD_BLOCK = true;
      G_P4M_ENTRY_BLOCK = true;
      G_P4M_GRID_BLOCK = true;
      G_P4M_REASON = "license invalid";
   }
   else if(!G_P4M_SYMBOL_OK)
   {
      G_P4M_HARD_BLOCK = true;
      G_P4M_ENTRY_BLOCK = true;
      G_P4M_GRID_BLOCK = true;
      G_P4M_REASON = "symbol invalid";
   }
   else if(!G_P4M_SPREAD_OK)
   {
      G_P4M_ENTRY_BLOCK = true;
      G_P4M_GRID_BLOCK = true;
      G_P4M_REASON = "spread guard";
   }
   else
   {
      G_P4M_REASON = "valid";
   }

   G_P4M_VALID = (!G_P4M_HARD_BLOCK && !G_P4M_ENTRY_BLOCK && !G_P4M_GRID_BLOCK);

   if(G_P4M_HARD_BLOCK && P4MiniCloseBasketInvalid && G_BASKET_ORDERS > 0)
      CloseSirusBasket("P4M invalid: " + G_P4M_REASON);

   G_P4M_STATUS = StringFormat("P4M: valid=%s license=%s symbol=%s spread=%s",
                               BoolText(G_P4M_VALID),
                               BoolText(G_P4M_LICENSE_OK),
                               BoolText(G_P4M_SYMBOL_OK),
                               BoolText(G_P4M_SPREAD_OK));

   G_P4M_DETAIL = StringFormat("P4M DETAIL: %s symbol=%s spread=%d/%d",
                               detail,
                               _Symbol,
                               G_LAST_SPREAD_POINTS,
                               EffSpread(P4MiniMaxSpread));

   string signature = G_P4M_STATUS + "|" + G_P4M_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintPack4MiniEvents && signature != G_P4M_LAST_SIGNATURE)
   {
      if(!G_P4M_VALID || G_P4M_LAST_SIGNATURE == "")
      {
         G_P4M_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 22.1 P4M] %s | %s | source=%s",
                     G_P4M_STATUS,
                     G_P4M_DETAIL,
                     source);
      }

      G_P4M_LAST_SIGNATURE = signature;
   }
}

bool Pack4MiniAllowsEntry(string &reason)
{
   if(!UsePack4MiniLicense)
   {
      reason = "P4M entry pass";
      return true;
   }

   if(G_P4M_HARD_BLOCK)
   {
      reason = "P4M hard block: " + G_P4M_REASON;
      return false;
   }

   if(G_P4M_ENTRY_BLOCK)
   {
      reason = "P4M entry block: " + G_P4M_REASON;
      return false;
   }

   reason = "P4M entry pass";
   return true;
}

bool Pack4MiniAllowsGrid(string &reason)
{
   if(!UsePack4MiniLicense)
   {
      reason = "P4M grid pass";
      return true;
   }

   if(G_P4M_HARD_BLOCK)
   {
      reason = "P4M hard block: " + G_P4M_REASON;
      return false;
   }

   if(G_P4M_GRID_BLOCK)
   {
      reason = "P4M grid block: " + G_P4M_REASON;
      return false;
   }

   reason = "P4M grid pass";
   return true;
}


//==================================================================//
//  PHASE 22.3 PREMIUM VISUAL WATERMARK / ZONES
//==================================================================//
string PremiumVisualName(const string suffix)
{
   return G_PREFIX + "PV_" + suffix;
}

void PremiumVisualDeleteObjects()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, G_PREFIX + "PV_") == 0)
         ObjectDelete(0, name);
   }
}

void PremiumVisualDrawLabel(const string suffix,
                            const string text,
                            const int corner,
                            const int x,
                            const int y,
                            const color clr,
                            const int font_size,
                            const string font_name = "Arial")
{
   string name = PremiumVisualName(suffix);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, font_name);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}


void PremiumVisualDrawHLine(const string suffix,
                            const double price,
                            const color clr,
                            const ENUM_LINE_STYLE style,
                            const int width)
{
   if(price <= 0.0)
      return;

   string name = PremiumVisualName(suffix);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

double PremiumVisualValuePerPointPerLot()
{
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_value <= 0.0 || tick_size <= 0.0 || _Point <= 0.0)
      return 0.0;

   return tick_value * (_Point / tick_size);
}

double PremiumVisualBasketSLPrice()
{
   if(!PremiumShowBasketSLLine || !UseBasketSL)
      return 0.0;

   if(G_BASKET_ORDERS <= 0 || G_BASKET_AVG_PRICE <= 0.0 || G_BASKET_VOLUME <= 0.0)
      return 0.0;

   if(BasketSLPercent <= 0.0)
      return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return 0.0;

   double loss_money = balance * BasketSLPercent / 100.0;
   double value_per_point_lot = PremiumVisualValuePerPointPerLot();

   if(value_per_point_lot <= 0.0)
      return 0.0;

   double points = loss_money / (value_per_point_lot * G_BASKET_VOLUME);

   if(points <= 0.0)
      return 0.0;

   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
      return G_BASKET_AVG_PRICE - points * _Point;

   if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
      return G_BASKET_AVG_PRICE + points * _Point;

   return 0.0;
}

void PremiumVisualDrawBasketSLLine()
{
   if(!PremiumShowBasketSLLine)
      return;

   double sl_price = PremiumVisualBasketSLPrice();

   if(sl_price > 0.0)
      PremiumVisualDrawHLine("BASKET_SL",
                             sl_price,
                             PremiumBasketSLColor,
                             STYLE_DASHDOT,
                             1);
}

void PremiumVisualDrawTrailLockLine()
{
   if(!PremiumShowTrailLockLine)
      return;

   if(!G_BASKET_TRAIL_ACTIVE || G_BASKET_ORDERS <= 0 || G_BASKET_AVG_PRICE <= 0.0 || G_BASKET_TRAIL_LOCK <= 0.0)
      return;

   double lock_price = 0.0;

   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
      lock_price = G_BASKET_AVG_PRICE + G_BASKET_TRAIL_LOCK * _Point;
   else if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
      lock_price = G_BASKET_AVG_PRICE - G_BASKET_TRAIL_LOCK * _Point;

   if(lock_price > 0.0)
      PremiumVisualDrawHLine("TRAIL_LOCK",
                             lock_price,
                             PremiumTrailLockColor,
                             STYLE_DASHDOTDOT,
                             1);
}

void PremiumVisualDrawSessionRectangle(const string suffix,
                                       const datetime t1,
                                       const datetime t2,
                                       const color clr,
                                       const string label_text)
{
   if(t1 <= 0 || t2 <= 0 || t2 <= t1)
      return;

   double hi = HighestHigh(PERIOD_CURRENT, PremiumSessionLookbackBars, 0);
   double lo = LowestLow(PERIOD_CURRENT, PremiumSessionLookbackBars, 0);

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return;

   string name = PremiumVisualName("SESSION_" + suffix);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);

   ObjectMove(0, name, 0, t1, hi);
   ObjectMove(0, name, 1, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   string label_name = PremiumVisualName("SESSION_" + suffix + "_LBL");

   if(ObjectFind(0, label_name) < 0)
      ObjectCreate(0, label_name, OBJ_TEXT, 0, t1, hi);

   ObjectMove(0, label_name, 0, t1, hi);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, PremiumSessionLabelColor);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, PremiumZoneLabelFontSize);
   ObjectSetString(0, label_name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, label_name, OBJPROP_TEXT, label_text);
   ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
}

datetime PremiumVisualTodayAtHour(const int hour_value)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = hour_value;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

void PremiumVisualDrawSessionZones()
{
   if(!PremiumShowSessionZones)
      return;

   int asia_h = SafeHourClamp(LegacyAsiaStartHour);
   int london_h = SafeHourClamp(LegacyLondonStartHour);
   int ny_h = SafeHourClamp(LegacyNYStartHour);

   datetime asia_start = PremiumVisualTodayAtHour(asia_h);
   datetime london_start = PremiumVisualTodayAtHour(london_h);
   datetime ny_start = PremiumVisualTodayAtHour(ny_h);
   datetime day_end = PremiumVisualTodayAtHour(23) + 3600;

   if(london_start > asia_start)
      PremiumVisualDrawSessionRectangle("ASIA", asia_start, london_start, PremiumAsiaSessionColor, "ASIA");

   if(ny_start > london_start)
      PremiumVisualDrawSessionRectangle("LONDON", london_start, ny_start, PremiumLondonSessionColor, "LONDON");

   if(day_end > ny_start)
      PremiumVisualDrawSessionRectangle("NY", ny_start, day_end, PremiumNYSessionColor, "NEW YORK");
}

void PremiumVisualDrawSignalHistoryMarker()
{
   if(!PremiumShowSignalHistory)
      return;

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
      return;

   datetime sig_time = iTime(_Symbol, SignalTF, 1);
   if(sig_time <= 0)
      return;

   double sig_price = 0.0;
   int arrow_code = 0;
   color arrow_color = clrWhite;

   if(G_OPP_DIR == OPP_DIR_BUY)
   {
      sig_price = CandleLow(SignalTF, 1) - PremiumSignalArrowOffsetPoints * _Point;
      arrow_code = 241;
      arrow_color = PremiumSignalBuyColor;
   }
   else
   {
      sig_price = CandleHigh(SignalTF, 1) + PremiumSignalArrowOffsetPoints * _Point;
      arrow_code = 242;
      arrow_color = PremiumSignalSellColor;
   }

   if(sig_price <= 0.0)
      return;

   string dir = (G_OPP_DIR == OPP_DIR_BUY ? "BUY" : "SELL");
   string name = PremiumVisualName("SIGNAL_HIST_" + dir + "_" + SafeDateTimeKey(sig_time));

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, sig_time, sig_price);

   ObjectMove(0, name, 0, sig_time, sig_price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrow_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}


void PremiumVisualDrawHeaderFrame()
{
   if(!PremiumShowHeaderFrame)
      return;

   string name = PremiumVisualName("HEADER_FRAME");

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PremiumHeaderFrameX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PremiumHeaderFrameY);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, PremiumHeaderFrameW);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, PremiumHeaderFrameH);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PremiumHeaderBorderColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PremiumHeaderBgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   PremiumVisualDrawLabel("HEADER_STATUS",
                          G_RC_STATUS + " | " + ModeToString(G_ACTIVE_MODE),
                          CORNER_RIGHT_UPPER,
                          PremiumHeaderFrameX + 12,
                          PremiumHeaderFrameY + PremiumHeaderFrameH - 20,
                          PremiumAccentColor,
                          MathMax(PremiumZoneLabelFontSize, 8),
                          "Arial");
}

void PremiumVisualDrawBasketLines()
{
   if(!PremiumShowBasketLines)
      return;

   if(G_BASKET_ORDERS <= 0 || G_BASKET_AVG_PRICE <= 0.0)
      return;

   PremiumVisualDrawHLine("BASKET_AVG",
                          G_BASKET_AVG_PRICE,
                          PremiumBasketAvgColor,
                          STYLE_DASH,
                          1);

   double tp_points = BasketTPForOrderCount(G_BASKET_ORDERS);
   double tp_price = 0.0;

   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
      tp_price = G_BASKET_AVG_PRICE + tp_points * _Point;
   else if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
      tp_price = G_BASKET_AVG_PRICE - tp_points * _Point;

   if(tp_price > 0.0)
      PremiumVisualDrawHLine("BASKET_TP",
                             tp_price,
                             PremiumBasketTPColor,
                             STYLE_SOLID,
                             1);
}

void PremiumVisualDrawNextGridLine()
{
   if(!PremiumShowNextGridLine)
      return;

   if(G_BASKET_ORDERS <= 0 || G_BASKET_AVG_PRICE <= 0.0 || G_NEXT_GRID_DISTANCE <= 0.0)
      return;

   double grid_price = 0.0;

   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
      grid_price = G_BASKET_AVG_PRICE - G_NEXT_GRID_DISTANCE * _Point;
   else if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
      grid_price = G_BASKET_AVG_PRICE + G_NEXT_GRID_DISTANCE * _Point;

   if(grid_price > 0.0)
      PremiumVisualDrawHLine("NEXT_GRID",
                             grid_price,
                             PremiumNextGridColor,
                             STYLE_DOT,
                             1);
}

void PremiumVisualDrawSignalMarker()
{
   if(!PremiumShowSignalMarker)
      return;

   if(G_OPP_DIR != OPP_DIR_BUY && G_OPP_DIR != OPP_DIR_SELL)
      return;

   datetime sig_time = iTime(_Symbol, SignalTF, 1);
   if(sig_time <= 0)
      return;

   double sig_price = 0.0;
   int arrow_code = 0;
   color arrow_color = clrWhite;

   if(G_OPP_DIR == OPP_DIR_BUY)
   {
      sig_price = CandleLow(SignalTF, 1) - PremiumSignalArrowOffsetPoints * _Point;
      arrow_code = 241;
      arrow_color = PremiumSignalBuyColor;
   }
   else if(G_OPP_DIR == OPP_DIR_SELL)
   {
      sig_price = CandleHigh(SignalTF, 1) + PremiumSignalArrowOffsetPoints * _Point;
      arrow_code = 242;
      arrow_color = PremiumSignalSellColor;
   }

   if(sig_price <= 0.0)
      return;

   string name = PremiumVisualName("SIGNAL_ARROW");

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, sig_time, sig_price);

   ObjectMove(0, name, 0, sig_time, sig_price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrow_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PremiumVisualDrawZoneRectangle(const string suffix,
                                    const double center_price,
                                    const int half_width_points,
                                    const color zone_color,
                                    const bool back,
                                    const string label_text)
{
   if(center_price <= 0.0 || half_width_points <= 0)
      return;

   int bars_back = MathMax(PremiumZoneLookbackBars, 20);
   int bars_fwd  = MathMax(PremiumZoneForwardBars, 5);

   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, bars_back);
   datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(t1 <= 0)
      t1 = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * bars_back;
   if(t2 <= 0)
      t2 = TimeCurrent();

   t2 += PeriodSeconds(PERIOD_CURRENT) * bars_fwd;

   double upper = center_price + half_width_points * _Point;
   double lower = center_price - half_width_points * _Point;

   string name = PremiumVisualName(suffix);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, upper, t2, lower);

   ObjectMove(0, name, 0, t1, upper);
   ObjectMove(0, name, 1, t2, lower);
   ObjectSetInteger(0, name, OBJPROP_COLOR, zone_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   if(PremiumShowZoneLabels)
   {
      string lname = PremiumVisualName(suffix + "_LBL");

      if(ObjectFind(0, lname) < 0)
         ObjectCreate(0, lname, OBJ_TEXT, 0, t2, center_price);

      ObjectMove(0, lname, 0, t2, center_price);
      ObjectSetInteger(0, lname, OBJPROP_COLOR, PremiumAccentColor);
      ObjectSetInteger(0, lname, OBJPROP_FONTSIZE, PremiumZoneLabelFontSize);
      ObjectSetString(0, lname, OBJPROP_FONT, "Arial");
      ObjectSetString(0, lname, OBJPROP_TEXT, label_text);
      ObjectSetInteger(0, lname, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lname, OBJPROP_HIDDEN, true);
   }
}

void PremiumVisualDrawZoneMidline(const string suffix,
                                  const double price,
                                  const color line_color)
{
   if(price <= 0.0)
      return;

   string name = PremiumVisualName(suffix);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PremiumVisualDrawWatermark()
{
   if(!PremiumShowWatermark)
   {
      MBDeleteWatermark();
      return;
   }

   // Phase 10: the designed watermark replaces the plain label.
   if(EnableNewWatermark)
   {
      PremiumVisualDeleteExact("WM_1");
      MBDrawWatermark();
      return;
   }
   MBDeleteWatermark();

   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   int wm_x = MathMax(80, chart_w / 2 - PremiumWatermarkFontSize * 4);
   int wm_y = MathMax(90, chart_h / 2 - PremiumWatermarkFontSize / 2);

   PremiumVisualDrawLabel("WM_1",
                          "SIRUS BY ZAKIY",
                          CORNER_LEFT_UPPER,
                          wm_x,
                          wm_y,
                          PremiumWatermarkColor,
                          PremiumWatermarkFontSize,
                          "Arial Black");

   PremiumVisualDeleteExact("WM_2");
   PremiumVisualDeleteExact("WM_3");
}

double PremiumVisualRecentLow(const int bars_count)
{
   int total_bars = Bars(_Symbol, PERIOD_CURRENT);
   int limit = MathMin(MathMax(bars_count, 20), MathMax(total_bars - 2, 1));
   double lowest = 0.0;

   for(int i=1; i<=limit; i++)
   {
      double v = iLow(_Symbol, PERIOD_CURRENT, i);
      if(v <= 0.0)
         continue;

      if(lowest <= 0.0 || v < lowest)
         lowest = v;
   }

   return lowest;
}

double PremiumVisualRecentHigh(const int bars_count)
{
   int total_bars = Bars(_Symbol, PERIOD_CURRENT);
   int limit = MathMin(MathMax(bars_count, 20), MathMax(total_bars - 2, 1));
   double highest = 0.0;

   for(int i=1; i<=limit; i++)
   {
      double v = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(v <= 0.0)
         continue;

      if(highest <= 0.0 || v > highest)
         highest = v;
   }

   return highest;
}

void PremiumVisualDrawZones()
{
   if(!PremiumShowZones)
      return;

   // V29 fix (A2): draw the SAME zones the bot actually uses for TP/grid decisions
   // (unified swing-confirmed, 6-TF Zone Map), instead of a disconnected older system.
   double cur_bid = 0.0, cur_ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, cur_bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, cur_ask);
   double cur_mid = (cur_bid > 0.0 && cur_ask > 0.0) ? (cur_bid + cur_ask) / 2.0 : cur_bid;

   double support_price = ZoneMapNearestSupport(cur_mid);
   double resist_price  = ZoneMapNearestResistance(cur_mid);

   bool support_fallback = false;
   bool resist_fallback  = false;

   if(PremiumUseFallbackZones)
   {
      if(support_price <= 0.0)
      {
         support_price = PremiumVisualRecentLow(PremiumFallbackZoneLookbackBars);
         support_fallback = true;
      }

      if(resist_price <= 0.0)
      {
         resist_price = PremiumVisualRecentHigh(PremiumFallbackZoneLookbackBars);
         resist_fallback = true;
      }
   }

   // V31.6 visual fix: fallback half-width applies ONLY to a zone that actually came from
   // the fallback path. Real swing/FVG zones use the normal (narrow) width - previously the
   // wide fallback width was applied to ALL zones whenever fallback was merely enabled.
   int support_half_width = (support_fallback ? PremiumFallbackZoneHalfWidthPoints : PremiumZoneHalfWidthPoints);
   int resist_half_width  = (resist_fallback  ? PremiumFallbackZoneHalfWidthPoints : PremiumZoneHalfWidthPoints);

   if(support_price > 0.0)
   {
      PremiumVisualDrawZoneRectangle("SUPPORT_ZONE",
                                     support_price,
                                     support_half_width,
                                     PremiumSupportZoneColor,
                                     true,
                                     (support_fallback ? "SIRUS DEMAND" : "SIRUS SUPPORT"));

      if(PremiumShowZoneMidlines)
         PremiumVisualDrawZoneMidline("SUPPORT_LINE",
                                      support_price,
                                      PremiumSupportLineColor);
   }

   if(resist_price > 0.0)
   {
      PremiumVisualDrawZoneRectangle("RESIST_ZONE",
                                     resist_price,
                                     resist_half_width,
                                     PremiumResistanceZoneColor,
                                     true,
                                     (resist_fallback ? "SIRUS SUPPLY" : "SIRUS RESIST"));

      if(PremiumShowZoneMidlines)
         PremiumVisualDrawZoneMidline("RESIST_LINE",
                                      resist_price,
                                      PremiumResistanceLineColor);
   }
}


//==================================================================//
//  PHASE 22.6 VISUAL CLEANUP / PERFORMANCE
//==================================================================//
void PremiumVisualDeleteExact(const string suffix)
{
   string name = PremiumVisualName(suffix);
   if(ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
      G_PV_CLEANED_OBJECTS++;
   }
}

void PremiumVisualDeleteByPrefix(const string suffix_prefix)
{
   string prefix = PremiumVisualName(suffix_prefix);

   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);

      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
         G_PV_CLEANED_OBJECTS++;
      }
   }
}

int PremiumVisualCountObjects()
{
   int count = 0;
   string prefix = G_PREFIX + "PV_";

   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         count++;
   }

   return count;
}

void PremiumVisualCleanupBasketObjects()
{
   if(!PremiumHideBasketLinesWhenFlat)
      return;

   if(G_BASKET_ORDERS > 0)
      return;

   PremiumVisualDeleteExact("BASKET_AVG");
   PremiumVisualDeleteExact("BASKET_TP");
   PremiumVisualDeleteExact("BASKET_SL");
   PremiumVisualDeleteExact("TRAIL_LOCK");
   PremiumVisualDeleteExact("NEXT_GRID");
}

void PremiumVisualCleanupDisabledObjects()
{
   if(!PremiumCleanIfDisabled)
      return;

   if(PremiumCleanZonesIfOff && !PremiumShowZones)
   {
      PremiumVisualDeleteByPrefix("SUPPORT_ZONE");
      PremiumVisualDeleteByPrefix("SUPPORT_LINE");
      PremiumVisualDeleteByPrefix("RESIST_ZONE");
      PremiumVisualDeleteByPrefix("RESIST_LINE");
   }

   if(PremiumCleanSignalIfOff && !PremiumShowSignalMarker)
      PremiumVisualDeleteExact("SIGNAL_ARROW");

   if(PremiumCleanSignalIfOff && !PremiumShowSignalHistory)
      PremiumVisualDeleteByPrefix("SIGNAL_HIST_");

   if(PremiumCleanSessionsIfOff && !PremiumShowSessionZones)
      PremiumVisualDeleteByPrefix("SESSION_");

   if(!PremiumShowHeaderFrame)
   {
      PremiumVisualDeleteExact("HEADER_FRAME");
      PremiumVisualDeleteExact("HEADER_STATUS");
   }

   if(!PremiumShowWatermark)
   {
      PremiumVisualDeleteExact("WM_1");
      PremiumVisualDeleteExact("WM_2");
      PremiumVisualDeleteExact("WM_3");
   }
}

void PremiumVisualCleanupSignalHistory()
{
   if(!PremiumCleanOldSignalHistory)
      return;

   if(!PremiumShowSignalHistory)
      return;

   string prefix = PremiumVisualName("SIGNAL_HIST_");
   int count = 0;
   int max_age_sec = PeriodSeconds(SignalTF) * MathMax(PremiumSignalHistoryBars, 1);
   datetime cutoff = TimeCurrent() - max_age_sec;

   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);

      if(StringFind(name, prefix) != 0)
         continue;

      count++;

      datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);

      if(obj_time > 0 && obj_time < cutoff)
      {
         ObjectDelete(0, name);
         G_PV_CLEANED_OBJECTS++;
         count--;
      }
   }

   // Emergency unclutter: if too many history arrows remain, clear history arrows.
   if(PremiumMaxSignalHistoryObjects > 0 && count > PremiumMaxSignalHistoryObjects)
   {
      PremiumVisualDeleteByPrefix("SIGNAL_HIST_");
      G_PV_CLEAN_STATUS = "PV CLEAN: signal history reset";
   }
}

void UpdatePremiumVisualClutterControl(const string source)
{
   if(!PremiumUseClutterControl)
   {
      G_PV_CLEAN_STATUS = "PV CLEAN: OFF";
      G_PV_CLEAN_DETAIL = "PV CLEAN DETAIL: disabled";
      return;
   }

   datetime now = TimeLocal();

   if(G_PV_LAST_CLEANUP > 0 && (now - G_PV_LAST_CLEANUP) < PremiumVisualCleanupSeconds)
      return;

   G_PV_LAST_CLEANUP = now;
   int before = PremiumVisualCountObjects();
   G_PV_CLEANED_OBJECTS = 0;

   PremiumVisualCleanupBasketObjects();
   PremiumVisualCleanupDisabledObjects();
   PremiumVisualCleanupSignalHistory();

   int after = PremiumVisualCountObjects();
   G_PV_OBJECT_COUNT = after;

   if(G_PV_CLEAN_STATUS != "PV CLEAN: signal history reset")
      G_PV_CLEAN_STATUS = "PV CLEAN: OK";

   G_PV_CLEAN_DETAIL = StringFormat("PV CLEAN DETAIL: objects %d->%d cleaned=%d maxHist=%d flatHide=%s",
                                    before,
                                    after,
                                    G_PV_CLEANED_OBJECTS,
                                    PremiumMaxSignalHistoryObjects,
                                    BoolText(PremiumHideBasketLinesWhenFlat));

   if(PremiumPrintCleanupEvents && G_PV_CLEANED_OBJECTS > 0)
   {
      G_PV_CLEAN_EVENT_COUNT++;
      PrintFormat("[SIRUS v31.6 PHASE 22.6 PV CLEAN] %s | %s | source=%s",
                  G_PV_CLEAN_STATUS,
                  G_PV_CLEAN_DETAIL,
                  source);
   }
}

void UpdatePremiumVisualEngine(const string source)
{
   if(!UsePremiumVisualEngine)
   {
      G_PV_STATUS = "PV: OFF";
      G_PV_DETAIL = "PV DETAIL: disabled";
      PremiumVisualDeleteObjects();
      return;
   }

   datetime now = TimeLocal();

   if(G_PV_LAST_REFRESH > 0 && (now - G_PV_LAST_REFRESH) < PremiumVisualRefreshSeconds)
      return;

   G_PV_LAST_REFRESH = now;

   PremiumVisualDrawSessionZones();
   PremiumVisualDrawHeaderFrame();
   PremiumVisualDrawWatermark();
   PremiumVisualDrawZones();
   PremiumVisualDrawBasketLines();
   PremiumVisualDrawBasketSLLine();
   PremiumVisualDrawTrailLockLine();
   PremiumVisualDrawNextGridLine();
   PremiumVisualDrawSignalMarker();
   PremiumVisualDrawSignalHistoryMarker();
   UpdatePremiumVisualClutterControl(source);

   G_PV_STATUS = "PV: ACTIVE";
   G_PV_DETAIL = StringFormat("PV DETAIL: wm=%s zones=%s basket=%s SL=%s trail=%s grid=%s signal=%s session=%s objects=%d cleaned=%d",
                              BoolText(PremiumShowWatermark),
                              BoolText(PremiumShowZones),
                              BoolText(PremiumShowBasketLines),
                              BoolText(PremiumShowBasketSLLine),
                              BoolText(PremiumShowTrailLockLine),
                              BoolText(PremiumShowNextGridLine),
                              BoolText(PremiumShowSignalMarker),
                              BoolText(PremiumShowSessionZones),
                              G_PV_OBJECT_COUNT,
                              G_PV_CLEANED_OBJECTS);

   string signature = G_PV_STATUS + "|" + G_PV_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintPremiumVisualEvents && signature != G_PV_LAST_SIGNATURE)
   {
      if(G_PV_LAST_SIGNATURE == "")
         G_PV_EVENT_COUNT++;

      PrintFormat("[SIRUS v31.6 PHASE 22.3 PV] %s | %s | source=%s",
                  G_PV_STATUS,
                  G_PV_DETAIL,
                  source);

      G_PV_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 22.7 RC SETTINGS BALANCE / SAFE DEFAULTS
//==================================================================//
string RCBPreset()
{
   // V249fix(auto-mode): under SirusMode = AUTO the live mode is decided per scan, but this preset
   // is a STRING INPUT that never moves - so the HIGH_HUNTER limits were unreachable: the EA could
   // run in HIGH_HUNTER all session while this governor kept applying BALANCED caps (7 orders vs 9,
   // 0.25 first lot vs 0.50). That is a brake nobody asked for, and it hides itself - the two
   // branches currently return the same spread number, so you cannot see the mode being ignored.
   // In AUTO the governor now follows the mode actually in force (frozen per basket once one is
   // open, live otherwise). An EXPLICIT SirusMode still uses the string, so nothing changes for a
   // user who set the mode by hand.
   if(SirusMode == SIRUS_MODE_AUTO)
   {
      // An explicitly chosen SAFE preset is a deliberate instruction and outranks the live mode -
      // otherwise following the mode would silently delete the tightest caps the user asked for.
      string sp = RCSettingsPreset;
      StringTrimLeft(sp);
      StringTrimRight(sp);
      if(sp == "SAFE" || sp == "safe" || sp == "Safe")
         return "SAFE";

      ENUM_SIRUS_MODE eff = (G_BASKET_MODE_FROZEN ? G_BASKET_FROZEN_MODE : G_ACTIVE_MODE);
      if(eff == SIRUS_MODE_HIGH_HUNTER)
         return "HIGH_HUNTER";
      return "BALANCED";
   }

   string p = RCSettingsPreset;
   StringTrimLeft(p);
   StringTrimRight(p);

   if(p == "SAFE" || p == "safe" || p == "Safe")
      return "SAFE";

   if(p == "HIGH_HUNTER" || p == "high_hunter" || p == "High_Hunter" || p == "HIGH" || p == "high")
      return "HIGH_HUNTER";

   return "BALANCED";
}

void RCBPresetLimits(string &preset, double &first_lot, int &max_orders, double &basket_sl, int &spread_cap)
{
   preset = RCBPreset();

   if(preset == "SAFE")
   {
      first_lot = RCSafeMaxFirstLot;
      max_orders = RCSafeMaxOrders;
      basket_sl = RCSafeMaxBasketSL;
      spread_cap = EffSpread(RCSafeMaxSpread);
      return;
   }

   if(preset == "HIGH_HUNTER")
   {
      first_lot = RCHighHunterMaxFirstLot;
      max_orders = RCHighHunterMaxOrders;
      basket_sl = RCHighHunterMaxBasketSL;
      spread_cap = EffSpread(RCHighHunterMaxSpread);
      return;
   }

   first_lot = RCBalancedMaxFirstLot;
   max_orders = RCBalancedMaxOrders;
   basket_sl = RCBalancedMaxBasketSL;
   spread_cap = EffSpread(RCBalancedMaxSpread);
}

void UpdateRCSettingsBalance(const string source)
{
   G_RCB_VALID = true;
   G_RCB_ENTRY_BLOCK = false;
   G_RCB_GRID_BLOCK = false;
   G_RCB_WARNINGS = 0;

   if(!UseRCSettingsBalance)
   {
      G_RCB_STATUS = "RCB: OFF";
      G_RCB_REASON = "disabled";
      G_RCB_DETAIL = "RCB DETAIL: disabled";
      return;
   }

   string preset = "";
   double max_first = 0.0;
   int max_orders = 0;
   double max_sl = 0.0;
   int max_spread = 0;

   RCBPresetLimits(preset, max_first, max_orders, max_sl, max_spread);

   G_RCB_MAX_FIRST_LOT = max_first;
   G_RCB_MAX_ORDERS = max_orders;
   G_RCB_MAX_BASKET_SL = max_sl;
   G_RCB_MAX_SPREAD = max_spread;

   string warnings = "";

   // FIX(rc-check-side-effects): this call is only checking the number against RC's caps, not
   // opening anything - apply_side_effects=false stops it from polluting G_LOT_TRACE / the
   // AutoLotPrintOnUse dedup, and (more importantly) from overwriting G_SCALEIN_PENDING_LOT.
   double current_first_lot = LotForCurrentEntry(false);

   if(RCWarnIfLotTooHigh && max_first > 0.0 && current_first_lot > max_first + 0.0000001)
   {
      G_RCB_WARNINGS++;
      warnings = warnings + StringFormat("first lot %.2f>%.2f; ", current_first_lot, max_first);
      if(RCSettingsStrictEnforce)
         G_RCB_ENTRY_BLOCK = true;
   }

   if(RCWarnIfMaxOrdersHigh && max_orders > 0 && MaxOrders > max_orders)
   {
      G_RCB_WARNINGS++;
      warnings = warnings + StringFormat("MaxOrders %d>%d; ", MaxOrders, max_orders);
      if(RCSettingsStrictEnforce)
         G_RCB_GRID_BLOCK = true;
   }

   if(RCWarnIfBasketSLHigh && max_sl > 0.0 && BasketSLPercent > max_sl)
   {
      G_RCB_WARNINGS++;
      warnings = warnings + StringFormat("BasketSL %.2f>%.2f; ", BasketSLPercent, max_sl);
      if(RCSettingsStrictEnforce)
      {
         G_RCB_ENTRY_BLOCK = true;
         G_RCB_GRID_BLOCK = true;
      }
   }

   if(RCWarnIfSpreadCapHigh && max_spread > 0 && EffSpread(P4MiniMaxSpread) > max_spread)
   {
      G_RCB_WARNINGS++;
      warnings = warnings + StringFormat("P4Spread %d>%d; ", EffSpread(P4MiniMaxSpread), max_spread);
   }

   if(RCWarnIfLicenseOff && P4MiniUseLicenseControl == false)
   {
      G_RCB_WARNINGS++;
      warnings = warnings + "license off; ";
   }

   if(warnings == "")
      warnings = "settings healthy";

   G_RCB_REASON = warnings;
   G_RCB_VALID = (G_RCB_WARNINGS == 0 || !RCSettingsStrictEnforce);

   if(G_RCB_ENTRY_BLOCK || G_RCB_GRID_BLOCK)
      G_RCB_STATUS = "RCB: STRICT BLOCK";
   else if(G_RCB_WARNINGS > 0)
      G_RCB_STATUS = "RCB: WARN";
   else
      G_RCB_STATUS = "RCB: READY";

   G_RCB_DETAIL = StringFormat("RCB DETAIL: preset=%s warnings=%d strict=%s firstCap=%.2f maxOrders=%d maxSL=%.2f maxSpread=%d | %s",
                               preset,
                               G_RCB_WARNINGS,
                               BoolText(RCSettingsStrictEnforce),
                               max_first,
                               max_orders,
                               max_sl,
                               max_spread,
                               warnings);

   string signature = G_RCB_STATUS + "|" + G_RCB_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintRCSettingsEvents && signature != G_RCB_LAST_SIGNATURE)
   {
      if(G_RCB_WARNINGS > 0 || G_RCB_LAST_SIGNATURE == "")
      {
         G_RCB_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 22.7 RCB] %s | %s | source=%s",
                     G_RCB_STATUS,
                     G_RCB_DETAIL,
                     source);
      }

      G_RCB_LAST_SIGNATURE = signature;
   }
}

bool RCSettingsAllowsEntry(string &reason)
{
   if(!UseRCSettingsBalance)
   {
      reason = "RCB entry pass";
      return true;
   }

   if(G_RCB_ENTRY_BLOCK)
   {
      reason = "RCB entry block: " + G_RCB_REASON;
      return false;
   }

   reason = "RCB entry pass";
   return true;
}

bool RCSettingsAllowsGrid(string &reason)
{
   if(!UseRCSettingsBalance)
   {
      reason = "RCB grid pass";
      return true;
   }

   if(G_RCB_GRID_BLOCK)
   {
      reason = "RCB grid block: " + G_RCB_REASON;
      return false;
   }

   reason = "RCB grid pass";
   return true;
}


//==================================================================//
//  PHASE 22.8 WARNING CLEANUP / ZERO-WARNING POLISH
//==================================================================//
void UpdateWarningCleanupPolish(const string source)
{
   if(!UseWarningCleanupPolish)
   {
      G_WCP_STATUS = "WCP: OFF";
      G_WCP_DETAIL = "WCP DETAIL: disabled";
      return;
   }

   G_WCP_STATUS = "WCP: ACTIVE";
   G_WCP_DETAIL = StringFormat("WCP DETAIL: type-safe strings active | login=%s | bars=%s | spread=%s | source=%s",
                               SafeLongText(AccountInfoInteger(ACCOUNT_LOGIN)),
                               SafeIntText(G_BARS_SEEN),
                               SafeIntText(G_LAST_SPREAD_POINTS),
                               source);

   string signature = G_WCP_STATUS + "|" + G_WCP_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintWarningCleanupEvents && signature != G_WCP_LAST_SIGNATURE)
   {
      if(G_WCP_LAST_SIGNATURE == "")
      {
         G_WCP_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 22.8 WCP] %s | %s",
                     G_WCP_STATUS,
                     G_WCP_DETAIL);
      }

      G_WCP_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 22.9 FINAL SELF-AUDIT / v23.76 CHECKLIST
//==================================================================//
void FinalAuditAdd(const bool ok,
                   const string name,
                   int &passed,
                   int &total,
                   string &missing)
{
   total++;

   if(ok)
   {
      passed++;
      return;
   }

   if(StringLen(missing) < 420)
      missing = missing + name + "; ";
}


//==================================================================//
//  FINAL RELEASE BUILD / CLIENT PRESET EXPORT
//==================================================================//
string ReleaseProfile()
{
   string p = ReleaseBuildProfile;
   StringTrimLeft(p);
   StringTrimRight(p);

   if(p == "INTERNAL_TEST" || p == "internal_test" || p == "INTERNAL")
      return "INTERNAL_TEST";

   if(p == "CLIENT_SAFE" || p == "client_safe" || p == "SAFE")
      return "CLIENT_SAFE";

   if(p == "HIGH_HUNTER" || p == "high_hunter" || p == "HIGH")
      return "HIGH_HUNTER";

   if(p == "RENTAL_DEMO" || p == "rental_demo" || p == "DEMO")
      return "RENTAL_DEMO";

   return "CLIENT_BALANCED";
}

string ReleasePresetHint()
{
   string p = ReleaseProfile();

   if(p == "CLIENT_SAFE")
      return "RCSettingsPreset=SAFE | P4MiniClientRiskProfile=CONSERVATIVE | Strict optional";

   if(p == "HIGH_HUNTER")
      return "RCSettingsPreset=HIGH_HUNTER | P4MiniClientRiskProfile=AGGRESSIVE | More activity/risk";

   if(p == "RENTAL_DEMO")
      return "License ON recommended | Demo allowed | Low lot cap | Visual ON";

   if(p == "INTERNAL_TEST")
      return "License OFF allowed | Strict OFF | Full logs ON | Visual ON";

   return "RCSettingsPreset=BALANCED | P4MiniClientRiskProfile=BALANCED | Client default";
}

void ReleaseAddCheck(const bool ok,
                     const string name,
                     int &warnings,
                     string &reason)
{
   if(ok)
      return;

   warnings++;

   if(StringLen(reason) < 480)
      reason = reason + name + "; ";
}


//==================================================================//
//  PHASE 23.1 LEGACY DEEP PARITY / HTF COMMANDER
//==================================================================//
string DeepDirText(const int dir)
{
   if(dir > 0)
      return "BUY";
   if(dir < 0)
      return "SELL";
   return "NEUTRAL";
}

int DeepOpportunitySign()
{
   if(G_OPP_DIR == OPP_DIR_BUY)
      return 1;
   if(G_OPP_DIR == OPP_DIR_SELL)
      return -1;
   return 0;
}

int DeepHTFTrendDirection()
{
   if(!UseDeepHTFCommander)
      return 0;

   int htf_dir = 0;

   // V31.6d: unified trend source (see HTFStructureBias for the full rationale). Reads the
   // same Kalman signal MARKET_STATE and HTF Structure Commander now use, instead of an
   // independent dual-SMA cross+slope opinion. Falls back to the original method only while
   // Kalman is still warming up.
   if(KalmanTrendReady())
   {
      double kalman_slope = G_KALMAN_TREND / _Point;
      if(kalman_slope > KalmanTrendMinPoints)  htf_dir = 1;
      else if(kalman_slope < -KalmanTrendMinPoints) htf_dir = -1;
   }
   else
   {
      int slope_bars = MathMax(1, DeepHTFSlopeBars);

      double fast_now = SMA(HTFTrendTF, DeepHTFFastMAPeriod, 1);
      double fast_old = SMA(HTFTrendTF, DeepHTFFastMAPeriod, 1 + slope_bars);
      double slow_now = SMA(HTFTrendTF, DeepHTFSlowMAPeriod, 1);
      double close_now = CandleClose(HTFTrendTF, 1);

      if(fast_now <= 0.0 || fast_old <= 0.0 || slow_now <= 0.0 || close_now <= 0.0)
         htf_dir = 0;
      else
      {
         double slope_points = (fast_now - fast_old) / _Point;

         if(close_now > fast_now && fast_now > slow_now && slope_points > 0.0)
            htf_dir = 1;
         else if(close_now < fast_now && fast_now < slow_now && slope_points < 0.0)
            htf_dir = -1;
         // Softer fallback: old Sirus commander idea reads large-flow direction even when MA stack is not perfect.
         else if(close_now > fast_now && fast_now >= slow_now)
            htf_dir = 1;
         else if(close_now < fast_now && fast_now <= slow_now)
            htf_dir = -1;
      }
   }

   // FEATURE(global-htf-bind): the read above is a single-TF (H1) opinion. Bind it to the weighted
   // D1/H4/H1 global trend so a brief H1 pullback inside a bigger trend can't masquerade as the HTF
   // direction. If the weighted global is confident and disagrees with the H1 read, global wins.
   if(EnableGlobalHTFBind)
   {
      string gdetail = "";
      double gconf_buy = GlobalTrendConfidence(1, gdetail);   // >0 => weighted global leans UP
      int global_dir = 0;
      if(gconf_buy >= GlobalHTFBindMinConfidence)  global_dir = 1;
      else if(gconf_buy <= -GlobalHTFBindMinConfidence) global_dir = -1;

      if(global_dir != 0 && global_dir != htf_dir)
         htf_dir = global_dir;   // trust the bigger, weighted picture over a lone H1 read
   }

   return htf_dir;
}

int DeepM15StructureDirection()
{
   if(!UseDeepHTFCommander)
      return 0;

   int lookback = MathMax(10, DeepStructureLookbackBars);

   double close_now = CandleClose(StructureTF, 1);
   double prev_high = HighestHigh(StructureTF, lookback, 2);
   double prev_low  = LowestLow(StructureTF, lookback, 2);

   if(close_now <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low)
      return 0;

   if(close_now > prev_high)
      return 1;

   if(close_now < prev_low)
      return -1;

   double pos = (close_now - prev_low) / (prev_high - prev_low);

   if(pos <= 0.25)
      return 1;

   if(pos >= 0.75)
      return -1;

   return 0;
}

int DeepZonePressureDirection(string &reason)
{
   reason = "no strong zone pressure";

   if(!UseDeepHTFCommander)
      return 0;

   double price = CandleClose(SignalTF, 1);
   if(price <= 0.0)
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(price <= 0.0)
      return 0;

   int near_pts = MathMax(1, DeepZoneNearPoints);

   double support_dist = 999999999.0;
   double resist_dist  = 999999999.0;

   if(G_LEGACY_NEAREST_SUPPORT > 0.0)
      support_dist = PointsBetween(price, G_LEGACY_NEAREST_SUPPORT);

   if(G_LEGACY_NEAREST_RESIST > 0.0)
      resist_dist = PointsBetween(price, G_LEGACY_NEAREST_RESIST);

   if(support_dist <= near_pts && support_dist <= resist_dist)
   {
      reason = StringFormat("near support %.0f/%d", support_dist, near_pts);
      return 1;
   }

   if(resist_dist <= near_pts && resist_dist < support_dist)
   {
      reason = StringFormat("near resistance %.0f/%d", resist_dist, near_pts);
      return -1;
   }

   reason = StringFormat("zone clear support=%.0f resist=%.0f near=%d", support_dist, resist_dist, near_pts);
   return 0;
}

void UpdateLegacyDeepParityPack(const string source)
{
   G_DLP_APPLIED = false;
   G_DLP_ENTRY_BLOCK = false;
   G_DLP_GRID_BLOCK = false;
   G_DLP_BONUS = 0;
   G_DLP_PENALTY = 0;
   G_DLP_ALIGNMENT_SCORE = 0;

   if(!UseLegacyDeepParityPack || !UseDeepHTFCommander)
   {
      G_DLP_STATUS = "DLP: OFF";
      G_DLP_REASON = "deep parity disabled";
      G_DLP_DETAIL = "DLP DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();
   string zone_reason = "";

   G_DLP_HTF_DIR = DeepHTFTrendDirection();
   G_DLP_STRUCT_DIR = DeepM15StructureDirection();
   G_DLP_ZONE_DIR = DeepZonePressureDirection(zone_reason);

   if(opp == 0)
   {
      G_DLP_STATUS = "DLP: WAIT";
      G_DLP_REASON = "no opportunity direction";
      G_DLP_DETAIL = StringFormat("DLP DETAIL: htf=%s m15=%s zone=%s | %s",
                                  DeepDirText(G_DLP_HTF_DIR),
                                  DeepDirText(G_DLP_STRUCT_DIR),
                                  DeepDirText(G_DLP_ZONE_DIR),
                                  zone_reason);
      return;
   }

   string reason = "";

   if(G_DLP_HTF_DIR == opp)
   {
      G_DLP_ALIGNMENT_SCORE++;
      G_DLP_BONUS += DeepHTFAlignBonus;
      reason = reason + "HTF aligned; ";
   }
   else if(G_DLP_HTF_DIR == -opp)
   {
      G_DLP_ALIGNMENT_SCORE--;
      G_DLP_PENALTY += DeepHTFCounterPenalty;
      reason = reason + "HTF countertrend; ";

      if(DeepHTFStrictCounterTrendBlock)
         G_DLP_ENTRY_BLOCK = true;

      if(DeepHTFBlockGridCounterTrend)
         G_DLP_GRID_BLOCK = true;
   }

   if(G_DLP_STRUCT_DIR == opp)
   {
      G_DLP_ALIGNMENT_SCORE++;
      G_DLP_BONUS += DeepM15ConfirmBonus;
      reason = reason + "M15 confirms; ";
   }
   else if(G_DLP_STRUCT_DIR == -opp)
   {
      G_DLP_ALIGNMENT_SCORE--;
      G_DLP_PENALTY += 1;
      reason = reason + "M15 against; ";
   }

   if(G_DLP_ZONE_DIR == opp)
   {
      G_DLP_ALIGNMENT_SCORE++;
      G_DLP_BONUS += DeepZoneReactionBonus;
      reason = reason + "zone supports entry; ";
   }
   else if(G_DLP_ZONE_DIR == -opp)
   {
      G_DLP_ALIGNMENT_SCORE--;
      G_DLP_PENALTY += DeepZoneDangerPenalty;
      reason = reason + "opposite zone danger; ";
   }

   if(reason == "")
      reason = "neutral HTF context";

   if(DeepHTFUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DLP_BONUS > 0 || G_DLP_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DLP_BONUS, G_DLP_PENALTY, "deep parity htf " + reason);
         LegacyRecalculateDecision();
         G_DLP_APPLIED = true;
      }
   }

   G_DLP_REASON = reason;

   if(G_DLP_ENTRY_BLOCK || G_DLP_GRID_BLOCK)
      G_DLP_STATUS = "DLP: STRICT BLOCK";
   else if(G_DLP_PENALTY > G_DLP_BONUS)
      G_DLP_STATUS = "DLP: CAUTION";
   else if(G_DLP_BONUS > 0)
      G_DLP_STATUS = "DLP: BOOST";
   else
      G_DLP_STATUS = "DLP: NEUTRAL";

   G_DLP_DETAIL = StringFormat("DLP DETAIL: opp=%s htf=%s m15=%s zone=%s align=%d bonus=%d penalty=%d | %s | %s",
                               DeepDirText(opp),
                               DeepDirText(G_DLP_HTF_DIR),
                               DeepDirText(G_DLP_STRUCT_DIR),
                               DeepDirText(G_DLP_ZONE_DIR),
                               G_DLP_ALIGNMENT_SCORE,
                               G_DLP_BONUS,
                               G_DLP_PENALTY,
                               zone_reason,
                               reason);

   string signature = G_DLP_STATUS + "|" + G_DLP_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepParityEvents && signature != G_DLP_LAST_SIGNATURE)
   {
      if(G_DLP_LAST_SIGNATURE == "" || G_DLP_APPLIED || G_DLP_ENTRY_BLOCK || G_DLP_GRID_BLOCK)
      {
         G_DLP_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.1 DLP] %s | %s | source=%s",
                     G_DLP_STATUS,
                     G_DLP_DETAIL,
                     source);
      }

      G_DLP_LAST_SIGNATURE = signature;
   }
}

bool LegacyDeepParityAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepHTFCommander)
   {
      reason = "DLP entry pass";
      return true;
   }

   if(G_DLP_ENTRY_BLOCK)
   {
      reason = "DLP entry block: " + G_DLP_REASON;
      return false;
   }

   reason = "DLP entry pass";
   return true;
}

bool LegacyDeepParityAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepHTFCommander)
   {
      reason = "DLP grid pass";
      return true;
   }

   if(G_DLP_GRID_BLOCK)
   {
      reason = "DLP grid block: " + G_DLP_REASON;
      return false;
   }

   reason = "DLP grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.2 DEEP BOS / CHOCH / RETEST UPGRADE
//==================================================================//
int DeepDetectBOSDirection(double &level, string &reason)
{
   level = 0.0;
   reason = "no BOS";

   if(!UseDeepBOSChochRetest)
      return 0;

   int lookback = MathMax(10, DeepBOSLookbackBars);
   int buffer = MathMax(0, DeepBOSBreakBufferPoints);

   double close_now = CandleClose(StructureTF, 1);
   double prev_high = HighestHigh(StructureTF, lookback, 2);
   double prev_low  = LowestLow(StructureTF, lookback, 2);

   if(close_now <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low)
   {
      reason = "BOS data not ready";
      return 0;
   }

   if(close_now > prev_high + buffer * _Point)
   {
      level = prev_high;
      reason = StringFormat("bull BOS close %.2f > high %.2f buffer=%d", close_now, prev_high, buffer);
      return 1;
   }

   if(close_now < prev_low - buffer * _Point)
   {
      level = prev_low;
      reason = StringFormat("bear BOS close %.2f < low %.2f buffer=%d", close_now, prev_low, buffer);
      return -1;
   }

   reason = StringFormat("inside structure high=%.2f low=%.2f close=%.2f", prev_high, prev_low, close_now);
   return 0;
}

bool DeepDetectRetest(const int bos_dir, const double level, string &reason)
{
   reason = "no retest";

   if(!UseDeepBOSChochRetest)
      return false;

   if(bos_dir == 0 || level <= 0.0)
   {
      reason = "no valid BOS level";
      return false;
   }

   int bars_since = G_BARS_SEEN - G_DBOS_LAST_BOS_BAR;

   if(bars_since < 0 || bars_since > DeepRetestMaxBars)
   {
      reason = StringFormat("retest expired bars=%d max=%d", bars_since, DeepRetestMaxBars);
      return false;
   }

   int zone = MathMax(1, DeepRetestZonePoints);

   double close_now = CandleClose(SignalTF, 1);
   double low_now   = CandleLow(SignalTF, 1);
   double high_now  = CandleHigh(SignalTF, 1);

   if(close_now <= 0.0 || low_now <= 0.0 || high_now <= 0.0)
   {
      reason = "retest data not ready";
      return false;
   }

   if(bos_dir > 0)
   {
      bool touched = (low_now <= level + zone * _Point);
      bool reclaimed = (close_now >= level);

      if(touched && reclaimed)
      {
         reason = StringFormat("bull retest ready level=%.2f close=%.2f bars=%d", level, close_now, bars_since);
         return true;
      }
   }

   if(bos_dir < 0)
   {
      bool touched = (high_now >= level - zone * _Point);
      bool rejected = (close_now <= level);

      if(touched && rejected)
      {
         reason = StringFormat("bear retest ready level=%.2f close=%.2f bars=%d", level, close_now, bars_since);
         return true;
      }
   }

   reason = StringFormat("waiting retest level=%.2f close=%.2f bars=%d zone=%d", level, close_now, bars_since, zone);
   return false;
}

void UpdateDeepBOSChochRetest(const string source)
{
   G_DBOS_APPLIED = false;
   G_DBOS_ENTRY_BLOCK = false;
   G_DBOS_GRID_BLOCK = false;
   G_DBOS_RETEST_READY = false;
   G_DBOS_CHOCH_ACTIVE = false;
   G_DBOS_BONUS = 0;
   G_DBOS_PENALTY = 0;

   if(!UseLegacyDeepParityPack || !UseDeepBOSChochRetest)
   {
      G_DBOS_STATUS = "DBOS: OFF";
      G_DBOS_REASON = "deep BOS disabled";
      G_DBOS_DETAIL = "DBOS DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();
   string bos_reason = "";
   double bos_level = 0.0;
   int bos_dir = DeepDetectBOSDirection(bos_level, bos_reason);

   if(bos_dir != 0)
   {
      bool new_break = (G_DBOS_LAST_BOS_LEVEL <= 0.0 ||
                        MathAbs(bos_level - G_DBOS_LAST_BOS_LEVEL) > MathMax(1, DeepBOSBreakBufferPoints) * _Point ||
                        bos_dir != G_DBOS_DIR);

      if(new_break)
      {
         if(G_DBOS_LAST_MAJOR_DIR != 0 && bos_dir == -G_DBOS_LAST_MAJOR_DIR)
            G_DBOS_CHOCH_ACTIVE = true;

         G_DBOS_LAST_MAJOR_DIR = bos_dir;
         G_DBOS_LAST_BOS_LEVEL = bos_level;
         G_DBOS_LAST_BOS_BAR = G_BARS_SEEN;
         G_DBOS_EVER_RETESTED = false;
         G_DBOS_BREAK_VOLUME_SIGN = OrderFlowConvictionSign(StructureTF, 1);
      }

      G_DBOS_DIR = bos_dir;
   }

   string retest_reason = "";
   G_DBOS_RETEST_READY = DeepDetectRetest(G_DBOS_DIR, G_DBOS_LAST_BOS_LEVEL, retest_reason);
   if(G_DBOS_RETEST_READY)
      G_DBOS_EVER_RETESTED = true;

   string reason = "";

   if(opp != 0 && G_DBOS_DIR != 0)
   {
      if(G_DBOS_DIR == opp)
      {
         // V29 fake-breakout guard: a fresh, not-yet-retested break gets a smaller bonus.
         // Full bonus only once the break has proven itself via a real retest.
         if(G_DBOS_EVER_RETESTED)
         {
            G_DBOS_BONUS += DeepBOSAlignBonus;
            reason = reason + "BOS aligned (confirmed); ";
         }
         else
         {
            G_DBOS_BONUS += DeepBOSFreshBreakBonus;
            reason = reason + "BOS aligned (fresh, unconfirmed); ";

            // V29 new: volume confirms or casts doubt on a fresh, unretested break.
            if(EnableOrderFlow)
            {
               if(G_DBOS_BREAK_VOLUME_SIGN > 0)
               {
                  G_DBOS_BONUS += OrderFlowStrongBOSBonus;
                  reason = reason + "break volume strong; ";
               }
               else if(G_DBOS_BREAK_VOLUME_SIGN < 0)
               {
                  G_DBOS_PENALTY += OrderFlowWeakBOSPenalty;
                  reason = reason + "break volume weak; ";
               }
            }
         }
      }
      else if(G_DBOS_DIR == -opp)
      {
         G_DBOS_PENALTY += DeepBOSAgainstPenalty;
         reason = reason + "BOS against; ";

         if(DeepBOSStrictAgainstBlock)
            G_DBOS_ENTRY_BLOCK = true;

         if(DeepBOSBlockGridAgainst)
            G_DBOS_GRID_BLOCK = true;
      }
   }

   if(opp != 0 && G_DBOS_CHOCH_ACTIVE)
   {
      if(G_DBOS_DIR == opp)
      {
         G_DBOS_BONUS += DeepCHoCHBonus;
         reason = reason + "CHoCH confirms reversal; ";
      }
      else
      {
         G_DBOS_PENALTY += 1;
         reason = reason + "CHoCH against signal; ";
      }
   }

   if(opp != 0 && G_DBOS_RETEST_READY)
   {
      if(G_DBOS_DIR == opp)
      {
         G_DBOS_BONUS += DeepRetestBonus;
         reason = reason + "retest confirmed; ";
      }
      else
      {
         G_DBOS_PENALTY += DeepFailedRetestPenalty;
         reason = reason + "opposite retest risk; ";
      }
   }
   else if(opp != 0 && G_DBOS_DIR == opp && G_DBOS_LAST_BOS_LEVEL > 0.0)
   {
      G_DBOS_PENALTY += DeepFailedRetestPenalty;
      reason = reason + "BOS waiting retest; ";
   }

   if(reason == "")
      reason = "neutral BOS context";

   if(DeepBOSUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DBOS_BONUS > 0 || G_DBOS_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DBOS_BONUS, G_DBOS_PENALTY, "deep BOS " + reason);
         LegacyRecalculateDecision();
         G_DBOS_APPLIED = true;
      }
   }

   G_DBOS_REASON = reason;

   if(G_DBOS_ENTRY_BLOCK || G_DBOS_GRID_BLOCK)
      G_DBOS_STATUS = "DBOS: STRICT BLOCK";
   else if(G_DBOS_RETEST_READY)
      G_DBOS_STATUS = "DBOS: RETEST READY";
   else if(G_DBOS_CHOCH_ACTIVE)
      G_DBOS_STATUS = "DBOS: CHOCH";
   else if(G_DBOS_BONUS > G_DBOS_PENALTY)
      G_DBOS_STATUS = "DBOS: BOOST";
   else if(G_DBOS_PENALTY > G_DBOS_BONUS)
      G_DBOS_STATUS = "DBOS: CAUTION";
   else
      G_DBOS_STATUS = "DBOS: NEUTRAL";

   G_DBOS_DETAIL = StringFormat("DBOS DETAIL: opp=%s bos=%s level=%.2f choch=%s retest=%s bonus=%d penalty=%d | %s | %s",
                                DeepDirText(opp),
                                DeepDirText(G_DBOS_DIR),
                                G_DBOS_LAST_BOS_LEVEL,
                                BoolText(G_DBOS_CHOCH_ACTIVE),
                                BoolText(G_DBOS_RETEST_READY),
                                G_DBOS_BONUS,
                                G_DBOS_PENALTY,
                                bos_reason,
                                retest_reason);

   string signature = G_DBOS_STATUS + "|" + G_DBOS_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepBOSEvents && signature != G_DBOS_LAST_SIGNATURE)
   {
      if(G_DBOS_LAST_SIGNATURE == "" || G_DBOS_APPLIED || G_DBOS_ENTRY_BLOCK || G_DBOS_GRID_BLOCK || G_DBOS_RETEST_READY)
      {
         G_DBOS_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.2 DBOS] %s | %s | source=%s",
                     G_DBOS_STATUS,
                     G_DBOS_DETAIL,
                     source);
      }

      G_DBOS_LAST_SIGNATURE = signature;
   }
}

bool DeepBOSAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepBOSChochRetest)
   {
      reason = "DBOS entry pass";
      return true;
   }

   if(G_DBOS_ENTRY_BLOCK)
   {
      reason = "DBOS entry block: " + G_DBOS_REASON;
      return false;
   }

   reason = "DBOS entry pass";
   return true;
}

bool DeepBOSAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepBOSChochRetest)
   {
      reason = "DBOS grid pass";
      return true;
   }

   if(G_DBOS_GRID_BLOCK)
   {
      reason = "DBOS grid block: " + G_DBOS_REASON;
      return false;
   }

   reason = "DBOS grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.3 DEEP TOP ZONE / COUNTERTREND TRAP GUARD
//==================================================================//
double DeepCandleUpperWickRatio(const ENUM_TIMEFRAMES tf, const int shift)
{
   double high = CandleHigh(tf, shift);
   double low = CandleLow(tf, shift);
   double open = CandleOpen(tf, shift);
   double close = CandleClose(tf, shift);

   double range = high - low;
   if(range <= 0.0)
      return 0.0;

   double body_top = MathMax(open, close);
   double upper = high - body_top;

   if(upper < 0.0)
      upper = 0.0;

   return upper / range;
}

double DeepCandleLowerWickRatio(const ENUM_TIMEFRAMES tf, const int shift)
{
   double high = CandleHigh(tf, shift);
   double low = CandleLow(tf, shift);
   double open = CandleOpen(tf, shift);
   double close = CandleClose(tf, shift);

   double range = high - low;
   if(range <= 0.0)
      return 0.0;

   double body_bottom = MathMin(open, close);
   double lower = body_bottom - low;

   if(lower < 0.0)
      lower = 0.0;

   return lower / range;
}

int DeepZoneBreakoutDirection(string &reason)
{
   reason = "no breakout";

   double close_now = CandleClose(SignalTF, 1);
   if(close_now <= 0.0)
      close_now = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(close_now <= 0.0)
      return 0;

   int buffer = MathMax(1, DeepZoneBreakoutBufferPoints);

   if(G_LEGACY_NEAREST_RESIST > 0.0 && close_now > G_LEGACY_NEAREST_RESIST + buffer * _Point)
   {
      reason = StringFormat("resistance breakout close=%.2f res=%.2f buffer=%d",
                            close_now,
                            G_LEGACY_NEAREST_RESIST,
                            buffer);
      return 1;
   }

   if(G_LEGACY_NEAREST_SUPPORT > 0.0 && close_now < G_LEGACY_NEAREST_SUPPORT - buffer * _Point)
   {
      reason = StringFormat("support breakdown close=%.2f sup=%.2f buffer=%d",
                            close_now,
                            G_LEGACY_NEAREST_SUPPORT,
                            buffer);
      return -1;
   }

   reason = "price inside zone boundary";
   return 0;
}

int DeepTopZoneTrapDirection(string &reason)
{
   reason = "no trap";

   if(!UseDeepTopZoneTrapGuard)
      return 0;

   double price = CandleClose(SignalTF, 1);
   if(price <= 0.0)
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(price <= 0.0)
      return 0;

   int near_pts = MathMax(1, DeepTopZoneNearPoints);

   double support_dist = 999999999.0;
   double resist_dist  = 999999999.0;

   if(G_LEGACY_NEAREST_SUPPORT > 0.0)
      support_dist = PointsBetween(price, G_LEGACY_NEAREST_SUPPORT);

   if(G_LEGACY_NEAREST_RESIST > 0.0)
      resist_dist = PointsBetween(price, G_LEGACY_NEAREST_RESIST);

   double upper_wick = DeepCandleUpperWickRatio(SignalTF, 1);
   double lower_wick = DeepCandleLowerWickRatio(SignalTF, 1);

   // FIX(top-zone-priority): unlike its sibling DeepZonePressureDirection (which picks whichever
   // zone price is actually CLOSER before deciding a direction), this function used to check the
   // resistance branch unconditionally first, with no comparison against support_dist. In a tight
   // range where both zones sit within near_pts, price could be genuinely closer to support (a
   // bullish case) and this would still report "top trap" (bearish) every time, because the
   // resistance check never looked at where support was. Added the same tie-break the sibling uses.
   if(resist_dist <= near_pts && resist_dist <= support_dist)
   {
      G_DTZ_TOP_DANGER = true;

      if(upper_wick >= DeepTrapWickRatio || price <= G_LEGACY_NEAREST_RESIST)
      {
         reason = StringFormat("top trap near resistance dist=%.0f/%d upperWick=%.2f",
                               resist_dist,
                               near_pts,
                               upper_wick);
         return -1;
      }

      reason = StringFormat("near resistance danger dist=%.0f/%d upperWick=%.2f",
                            resist_dist,
                            near_pts,
                            upper_wick);
      return 0;
   }

   if(support_dist <= near_pts && support_dist < resist_dist)
   {
      G_DTZ_BOTTOM_DANGER = true;

      if(lower_wick >= DeepTrapWickRatio || price >= G_LEGACY_NEAREST_SUPPORT)
      {
         reason = StringFormat("bottom trap near support dist=%.0f/%d lowerWick=%.2f",
                               support_dist,
                               near_pts,
                               lower_wick);
         return 1;
      }

      reason = StringFormat("near support danger dist=%.0f/%d lowerWick=%.2f",
                            support_dist,
                            near_pts,
                            lower_wick);
      return 0;
   }

   reason = StringFormat("no near zone support=%.0f resist=%.0f near=%d",
                         support_dist,
                         resist_dist,
                         near_pts);
   return 0;
}

void UpdateDeepTopZoneTrapGuard(const string source)
{
   G_DTZ_APPLIED = false;
   G_DTZ_ENTRY_BLOCK = false;
   G_DTZ_GRID_BLOCK = false;
   G_DTZ_TOP_DANGER = false;
   G_DTZ_BOTTOM_DANGER = false;
   G_DTZ_BREAKOUT_OK = false;
   G_DTZ_BONUS = 0;
   G_DTZ_PENALTY = 0;
   G_DTZ_TRAP_DIR = 0;

   if(!UseLegacyDeepParityPack || !UseDeepTopZoneTrapGuard)
   {
      G_DTZ_STATUS = "DTZ: OFF";
      G_DTZ_REASON = "deep top zone disabled";
      G_DTZ_DETAIL = "DTZ DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();

   string trap_reason = "";
   string breakout_reason = "";

   G_DTZ_TRAP_DIR = DeepTopZoneTrapDirection(trap_reason);
   int breakout_dir = DeepZoneBreakoutDirection(breakout_reason);

   string reason = "";

   if(opp != 0 && breakout_dir == opp)
   {
      G_DTZ_BREAKOUT_OK = true;
      G_DTZ_BONUS += DeepZoneBreakoutBonus;
      reason = reason + "zone breakout confirms; ";
   }

   if(opp != 0 && G_DTZ_TRAP_DIR == opp)
   {
      G_DTZ_BONUS += DeepTrapWithSignalBonus;
      reason = reason + "trap supports signal; ";
   }
   else if(opp != 0 && G_DTZ_TRAP_DIR == -opp)
   {
      G_DTZ_PENALTY += DeepOppositeZonePenalty;
      reason = reason + "opposite trap danger; ";

      if(DeepTopZoneStrictBlock)
         G_DTZ_ENTRY_BLOCK = true;

      if(DeepTopZoneBlockGrid)
         G_DTZ_GRID_BLOCK = true;
   }

   // Direct zone danger when signal tries to buy into resistance or sell into support.
   if(opp > 0 && G_DTZ_TOP_DANGER && !G_DTZ_BREAKOUT_OK)
   {
      G_DTZ_PENALTY += DeepCounterTrendTrapPenalty;
      reason = reason + "BUY into top zone; ";

      if(DeepTopZoneStrictBlock)
         G_DTZ_ENTRY_BLOCK = true;
   }

   if(opp < 0 && G_DTZ_BOTTOM_DANGER && !G_DTZ_BREAKOUT_OK)
   {
      G_DTZ_PENALTY += DeepCounterTrendTrapPenalty;
      reason = reason + "SELL into bottom zone; ";

      if(DeepTopZoneStrictBlock)
         G_DTZ_ENTRY_BLOCK = true;
   }

   if(reason == "")
      reason = "neutral zone trap context";

   if(DeepTopZoneUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DTZ_BONUS > 0 || G_DTZ_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DTZ_BONUS, G_DTZ_PENALTY, "deep top zone " + reason);
         LegacyRecalculateDecision();
         G_DTZ_APPLIED = true;
      }
   }

   G_DTZ_REASON = reason;

   if(G_DTZ_ENTRY_BLOCK || G_DTZ_GRID_BLOCK)
      G_DTZ_STATUS = "DTZ: STRICT BLOCK";
   else if(G_DTZ_BREAKOUT_OK)
      G_DTZ_STATUS = "DTZ: BREAKOUT OK";
   else if(G_DTZ_PENALTY > G_DTZ_BONUS)
      G_DTZ_STATUS = "DTZ: TRAP DANGER";
   else if(G_DTZ_BONUS > 0)
      G_DTZ_STATUS = "DTZ: BOOST";
   else
      G_DTZ_STATUS = "DTZ: NEUTRAL";

   G_DTZ_DETAIL = StringFormat("DTZ DETAIL: opp=%s trap=%s breakout=%s top=%s bottom=%s bonus=%d penalty=%d | %s | %s",
                               DeepDirText(opp),
                               DeepDirText(G_DTZ_TRAP_DIR),
                               DeepDirText(breakout_dir),
                               BoolText(G_DTZ_TOP_DANGER),
                               BoolText(G_DTZ_BOTTOM_DANGER),
                               G_DTZ_BONUS,
                               G_DTZ_PENALTY,
                               trap_reason,
                               breakout_reason);

   string signature = G_DTZ_STATUS + "|" + G_DTZ_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepTopZoneEvents && signature != G_DTZ_LAST_SIGNATURE)
   {
      if(G_DTZ_LAST_SIGNATURE == "" || G_DTZ_APPLIED || G_DTZ_ENTRY_BLOCK || G_DTZ_GRID_BLOCK || G_DTZ_BREAKOUT_OK)
      {
         G_DTZ_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.3 DTZ] %s | %s | source=%s",
                     G_DTZ_STATUS,
                     G_DTZ_DETAIL,
                     source);
      }

      G_DTZ_LAST_SIGNATURE = signature;
   }
}

bool DeepTopZoneAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepTopZoneTrapGuard)
   {
      reason = "DTZ entry pass";
      return true;
   }

   if(G_DTZ_ENTRY_BLOCK)
   {
      reason = "DTZ entry block: " + G_DTZ_REASON;
      return false;
   }

   reason = "DTZ entry pass";
   return true;
}

bool DeepTopZoneAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepTopZoneTrapGuard)
   {
      reason = "DTZ grid pass";
      return true;
   }

   if(G_DTZ_GRID_BLOCK)
   {
      reason = "DTZ grid block: " + G_DTZ_REASON;
      return false;
   }

   reason = "DTZ grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.4 DEEP NEWS / VOLATILITY SHOCK BRAIN
//==================================================================//
int DeepShockImpulseDirection(double &range_pts,
                              double &body_pts,
                              double &atr_pts,
                              string &reason)
{
   range_pts = 0.0;
   body_pts = 0.0;
   atr_pts = 0.0;
   reason = "no impulse";

   if(!UseDeepNewsVolatilityBrain || !DeepShockUseATRImpulse)
      return 0;

   range_pts = CandleRangePoints(SignalTF, 1);
   body_pts = CandleBodyPoints(SignalTF, 1);
   atr_pts = ATRPointsManual(SignalTF, DeepShockATRPeriod, 2);

   if(range_pts <= 0.0 || body_pts <= 0.0 || atr_pts <= 0.0)
   {
      reason = "shock data not ready";
      return 0;
   }

   bool range_shock = (range_pts >= atr_pts * DeepShockRangeATRMult);
   bool body_shock  = (body_pts >= atr_pts * DeepShockBodyATRMult);

   if(!range_shock && !body_shock)
   {
      reason = StringFormat("normal candle range=%.0f body=%.0f atr=%.0f", range_pts, body_pts, atr_pts);
      return 0;
   }

   double open = CandleOpen(SignalTF, 1);
   double close = CandleClose(SignalTF, 1);

   if(open <= 0.0 || close <= 0.0)
   {
      reason = "open/close not ready";
      return 0;
   }

   if(close > open)
   {
      reason = StringFormat("bull shock range=%.0f body=%.0f atr=%.0f", range_pts, body_pts, atr_pts);
      return 1;
   }

   if(close < open)
   {
      reason = StringFormat("bear shock range=%.0f body=%.0f atr=%.0f", range_pts, body_pts, atr_pts);
      return -1;
   }

   reason = "shock candle neutral close";
   return 0;
}

bool DeepShockExhaustionRisk(const int shock_dir, string &reason)
{
   reason = "no exhaustion risk";

   if(shock_dir == 0)
      return false;

   double upper = DeepCandleUpperWickRatio(SignalTF, 1);
   double lower = DeepCandleLowerWickRatio(SignalTF, 1);

   if(shock_dir > 0 && upper >= DeepTrapWickRatio)
   {
      reason = StringFormat("bull shock upper wick risk %.2f", upper);
      return true;
   }

   if(shock_dir < 0 && lower >= DeepTrapWickRatio)
   {
      reason = StringFormat("bear shock lower wick risk %.2f", lower);
      return true;
   }

   reason = StringFormat("wick ok upper=%.2f lower=%.2f", upper, lower);
   return false;
}

void UpdateDeepNewsVolatilityBrain(const string source)
{
   G_DNV_APPLIED = false;
   G_DNV_ENTRY_BLOCK = false;
   G_DNV_GRID_BLOCK = false;
   G_DNV_NEWS_ACTIVE = false;
   G_DNV_SHOCK_ACTIVE = false;
   G_DNV_SPREAD_SHOCK = false;
   G_DNV_EXHAUST_RISK = false;
   G_DNV_BONUS = 0;
   G_DNV_PENALTY = 0;
   G_DNV_SHOCK_DIR = 0;

   if(!UseLegacyDeepParityPack || !UseDeepNewsVolatilityBrain)
   {
      G_DNV_STATUS = "DNV: OFF";
      G_DNV_REASON = "deep news/volatility disabled";
      G_DNV_DETAIL = "DNV DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();
   string reason = "";

   if(DeepShockUseNewsState && G_PACK3_NEWS_ACTIVE)
   {
      G_DNV_NEWS_ACTIVE = true;
      G_DNV_PENALTY += DeepNewsPenalty;
      reason = reason + "news active; ";

      if(DeepNewsStrictEntryBlock)
         G_DNV_ENTRY_BLOCK = true;

      if(DeepNewsStrictGridBlock)
         G_DNV_GRID_BLOCK = true;
   }

   if(DeepShockUseSpreadSpike && DeepShockSpreadPoints > 0 && G_LAST_SPREAD_POINTS >= DeepShockSpreadPoints)
   {
      G_DNV_SPREAD_SHOCK = true;
      G_DNV_PENALTY += 1;
      reason = reason + StringFormat("spread shock %d/%d; ", G_LAST_SPREAD_POINTS, DeepShockSpreadPoints);
   }

   double range_pts = 0.0;
   double body_pts = 0.0;
   double atr_pts = 0.0;
   string shock_reason = "";
   G_DNV_SHOCK_DIR = DeepShockImpulseDirection(range_pts, body_pts, atr_pts, shock_reason);

   if(G_DNV_SHOCK_DIR != 0)
   {
      G_DNV_SHOCK_ACTIVE = true;
      G_DNV_LAST_SHOCK_BAR = G_BARS_SEEN;

      string exhaust_reason = "";
      G_DNV_EXHAUST_RISK = DeepShockExhaustionRisk(G_DNV_SHOCK_DIR, exhaust_reason);

      if(opp != 0)
      {
         if(G_DNV_SHOCK_DIR == opp && !G_DNV_EXHAUST_RISK)
         {
            G_DNV_BONUS += DeepShockMomentumBonus;
            reason = reason + "shock momentum supports signal; ";
         }
         else if(G_DNV_SHOCK_DIR == -opp)
         {
            G_DNV_PENALTY += DeepShockAgainstPenalty;
            reason = reason + "shock against signal; ";
         }
      }

      if(G_DNV_EXHAUST_RISK)
      {
         G_DNV_PENALTY += DeepShockExhaustPenalty;
         reason = reason + "shock exhaustion risk; ";
      }
   }
   else
   {
      int bars_since = G_BARS_SEEN - G_DNV_LAST_SHOCK_BAR;

      if(bars_since >= 0 && bars_since <= DeepShockCooldownBars)
      {
         G_DNV_SHOCK_ACTIVE = true;
         G_DNV_PENALTY += 1;
         reason = reason + StringFormat("post-shock cooldown bars=%d/%d; ", bars_since, DeepShockCooldownBars);
      }
   }

   if(reason == "")
      reason = "calm volatility context";

   if(DeepNewsUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DNV_BONUS > 0 || G_DNV_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DNV_BONUS, G_DNV_PENALTY, "deep news volatility " + reason);
         LegacyRecalculateDecision();
         G_DNV_APPLIED = true;
      }
   }

   G_DNV_REASON = reason;

   if(G_DNV_ENTRY_BLOCK || G_DNV_GRID_BLOCK)
      G_DNV_STATUS = "DNV: STRICT BLOCK";
   else if(G_DNV_NEWS_ACTIVE)
      G_DNV_STATUS = "DNV: NEWS";
   else if(G_DNV_SHOCK_ACTIVE && G_DNV_EXHAUST_RISK)
      G_DNV_STATUS = "DNV: EXHAUST SHOCK";
   else if(G_DNV_SHOCK_ACTIVE)
      G_DNV_STATUS = "DNV: SHOCK";
   else if(G_DNV_SPREAD_SHOCK)
      G_DNV_STATUS = "DNV: SPREAD SHOCK";
   else
      G_DNV_STATUS = "DNV: CALM";

   G_DNV_DETAIL = StringFormat("DNV DETAIL: opp=%s shock=%s news=%s spread=%s exhaust=%s bonus=%d penalty=%d | %s",
                               DeepDirText(opp),
                               DeepDirText(G_DNV_SHOCK_DIR),
                               BoolText(G_DNV_NEWS_ACTIVE),
                               BoolText(G_DNV_SPREAD_SHOCK),
                               BoolText(G_DNV_EXHAUST_RISK),
                               G_DNV_BONUS,
                               G_DNV_PENALTY,
                               shock_reason);

   string signature = G_DNV_STATUS + "|" + G_DNV_DETAIL + "|" + G_DNV_REASON + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepShockEvents && signature != G_DNV_LAST_SIGNATURE)
   {
      if(G_DNV_LAST_SIGNATURE == "" || G_DNV_APPLIED || G_DNV_ENTRY_BLOCK || G_DNV_GRID_BLOCK || G_DNV_SHOCK_ACTIVE || G_DNV_NEWS_ACTIVE)
      {
         G_DNV_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.4 DNV] %s | %s | reason=%s | source=%s",
                     G_DNV_STATUS,
                     G_DNV_DETAIL,
                     G_DNV_REASON,
                     source);
      }

      G_DNV_LAST_SIGNATURE = signature;
   }
}

bool DeepNewsVolatilityAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepNewsVolatilityBrain)
   {
      reason = "DNV entry pass";
      return true;
   }

   if(G_DNV_ENTRY_BLOCK)
   {
      reason = "DNV entry block: " + G_DNV_REASON;
      return false;
   }

   reason = "DNV entry pass";
   return true;
}

bool DeepNewsVolatilityAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseDeepNewsVolatilityBrain)
   {
      reason = "DNV grid pass";
      return true;
   }

   if(G_DNV_GRID_BLOCK)
   {
      reason = "DNV grid block: " + G_DNV_REASON;
      return false;
   }

   reason = "DNV grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.5 ADAPTIVE ENTRY TIMING BRAIN
//==================================================================//
int DeepCurrentSignalBarAgeSeconds()
{
   datetime bar_time = iTime(_Symbol, SignalTF, 0);

   if(bar_time <= 0)
      return 0;

   int age = (int)(TimeCurrent() - bar_time);

   if(age < 0)
      age = 0;

   return age;
}

bool DeepTimingCandleConfirms(const int opp, string &reason)
{
   reason = "no candle confirm";

   if(opp == 0)
      return false;

   double open = CandleOpen(SignalTF, 1);
   double close = CandleClose(SignalTF, 1);

   if(open <= 0.0 || close <= 0.0)
   {
      reason = "candle data not ready";
      return false;
   }

   if(opp > 0 && close > open)
   {
      reason = "bull close confirms BUY";
      return true;
   }

   if(opp < 0 && close < open)
   {
      reason = "bear close confirms SELL";
      return true;
   }

   reason = StringFormat("candle against opp=%s open=%.2f close=%.2f",
                         DeepDirText(opp),
                         open,
                         close);
   return false;
}

bool DeepTimingRejectionConfirms(const int opp, string &reason)
{
   reason = "no rejection confirm";

   if(opp == 0)
      return false;

   double upper = DeepCandleUpperWickRatio(SignalTF, 1);
   double lower = DeepCandleLowerWickRatio(SignalTF, 1);

   if(opp > 0 && lower >= DeepTrapWickRatio)
   {
      reason = StringFormat("lower wick confirms BUY %.2f", lower);
      return true;
   }

   if(opp < 0 && upper >= DeepTrapWickRatio)
   {
      reason = StringFormat("upper wick confirms SELL %.2f", upper);
      return true;
   }

   reason = StringFormat("wick not enough upper=%.2f lower=%.2f", upper, lower);
   return false;
}

void UpdateAdaptiveEntryTimingBrain(const string source)
{
   G_DET_APPLIED = false;
   G_DET_ENTRY_BLOCK = false;
   G_DET_GRID_BLOCK = false;
   G_DET_EARLY_BAR = false;
   G_DET_LATE_ENTRY = false;
   G_DET_CANDLE_CONFIRM = false;
   G_DET_REJECTION_CONFIRM = false;
   G_DET_POST_SHOCK = false;
   G_DET_BONUS = 0;
   G_DET_PENALTY = 0;

   if(!UseLegacyDeepParityPack || !UseAdaptiveEntryTimingBrain)
   {
      G_DET_STATUS = "DET: OFF";
      G_DET_REASON = "adaptive timing disabled";
      G_DET_DETAIL = "DET DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();
   G_DET_BAR_AGE_SECONDS = DeepCurrentSignalBarAgeSeconds();

   string reason = "";

   if(G_DET_BAR_AGE_SECONDS < MathMax(0, DeepTimingMinSecondsAfterBarOpen))
   {
      G_DET_EARLY_BAR = true;
      G_DET_PENALTY += DeepTimingEarlyPenalty;
      reason = reason + StringFormat("early bar age=%ds; ", G_DET_BAR_AGE_SECONDS);

      if(DeepTimingStrictEarlyBlock)
         G_DET_ENTRY_BLOCK = true;
   }

   if(DeepTimingLateEntrySeconds > 0 && G_DET_BAR_AGE_SECONDS > DeepTimingLateEntrySeconds)
   {
      G_DET_LATE_ENTRY = true;
      G_DET_PENALTY += DeepTimingLatePenalty;
      reason = reason + StringFormat("late entry age=%ds; ", G_DET_BAR_AGE_SECONDS);
   }

   int shock_bars = G_BARS_SEEN - G_DNV_LAST_SHOCK_BAR;

   if(G_DNV_LAST_SHOCK_BAR > -99999 && shock_bars >= 0 && shock_bars <= DeepTimingPostShockWaitBars)
   {
      G_DET_POST_SHOCK = true;
      G_DET_PENALTY += DeepTimingPostShockPenalty;
      reason = reason + StringFormat("post shock timing bars=%d/%d; ", shock_bars, DeepTimingPostShockWaitBars);

      if(DeepTimingBlockGridAfterShock)
         G_DET_GRID_BLOCK = true;
   }

   string candle_reason = "";
   G_DET_CANDLE_CONFIRM = DeepTimingCandleConfirms(opp, candle_reason);

   if(opp != 0)
   {
      if(G_DET_CANDLE_CONFIRM)
      {
         G_DET_BONUS += DeepTimingCandleConfirmBonus;
         reason = reason + "candle confirms; ";
      }
      else
      {
         G_DET_PENALTY += DeepTimingOppCandlePenalty;
         reason = reason + "candle not confirm; ";
      }
   }

   string wick_reason = "";
   G_DET_REJECTION_CONFIRM = DeepTimingRejectionConfirms(opp, wick_reason);

   if(opp != 0 && G_DET_REJECTION_CONFIRM)
   {
      G_DET_BONUS += DeepTimingRejectionBonus;
      reason = reason + "rejection confirms; ";
   }

   if(reason == "")
      reason = "timing healthy";

   if(DeepTimingUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DET_BONUS > 0 || G_DET_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DET_BONUS, G_DET_PENALTY, "deep timing " + reason);
         LegacyRecalculateDecision();
         G_DET_APPLIED = true;
      }
   }

   G_DET_REASON = reason;

   if(G_DET_ENTRY_BLOCK || G_DET_GRID_BLOCK)
      G_DET_STATUS = "DET: STRICT BLOCK";
   else if(G_DET_EARLY_BAR)
      G_DET_STATUS = "DET: EARLY WAIT";
   else if(G_DET_POST_SHOCK)
      G_DET_STATUS = "DET: POST SHOCK";
   else if(G_DET_CANDLE_CONFIRM || G_DET_REJECTION_CONFIRM)
      G_DET_STATUS = "DET: CONFIRMED";
   else if(G_DET_LATE_ENTRY)
      G_DET_STATUS = "DET: LATE";
   else
      G_DET_STATUS = "DET: HEALTHY";

   G_DET_DETAIL = StringFormat("DET DETAIL: opp=%s age=%ds early=%s late=%s candle=%s wick=%s postShock=%s bonus=%d penalty=%d | %s | %s",
                               DeepDirText(opp),
                               G_DET_BAR_AGE_SECONDS,
                               BoolText(G_DET_EARLY_BAR),
                               BoolText(G_DET_LATE_ENTRY),
                               candle_reason,
                               wick_reason,
                               BoolText(G_DET_POST_SHOCK),
                               G_DET_BONUS,
                               G_DET_PENALTY,
                               G_DET_REASON,
                               source);

   string signature = G_DET_STATUS + "|" + G_DET_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepTimingEvents && signature != G_DET_LAST_SIGNATURE)
   {
      if(G_DET_LAST_SIGNATURE == "" || G_DET_APPLIED || G_DET_ENTRY_BLOCK || G_DET_GRID_BLOCK || G_DET_CANDLE_CONFIRM)
      {
         G_DET_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.5 DET] %s | %s",
                     G_DET_STATUS,
                     G_DET_DETAIL);
      }

      G_DET_LAST_SIGNATURE = signature;
   }
}

bool AdaptiveEntryTimingAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseAdaptiveEntryTimingBrain)
   {
      reason = "DET entry pass";
      return true;
   }

   if(G_DET_ENTRY_BLOCK)
   {
      reason = "DET entry block: " + G_DET_REASON;
      return false;
   }

   reason = "DET entry pass";
   return true;
}

bool AdaptiveEntryTimingAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseAdaptiveEntryTimingBrain)
   {
      reason = "DET grid pass";
      return true;
   }

   if(G_DET_GRID_BLOCK)
   {
      reason = "DET grid block: " + G_DET_REASON;
      return false;
   }

   reason = "DET grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.6 ADAPTIVE RECOVERY INTELLIGENCE
//==================================================================//
double DeepRecoveryClampDouble(const double value, const double min_value, const double max_value)
{
   double v = value;

   if(v < min_value)
      v = min_value;

   if(v > max_value)
      v = max_value;

   return v;
}

bool DeepRecoveryTrendAgainstBasket()
{
   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
   {
      if(G_MARKET_STATE == MARKET_TREND_DOWN || G_DLP_HTF_DIR < 0 || G_DBOS_DIR < 0)
         return true;
   }

   if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
   {
      if(G_MARKET_STATE == MARKET_TREND_UP || G_DLP_HTF_DIR > 0 || G_DBOS_DIR > 0)
         return true;
   }

   return false;
}

bool DeepRecoveryZoneDangerAgainstBasket()
{
   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
   {
      if(G_DTZ_TOP_DANGER && !G_DTZ_BREAKOUT_OK)
         return true;
   }

   if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
   {
      if(G_DTZ_BOTTOM_DANGER && !G_DTZ_BREAKOUT_OK)
         return true;
   }

   return false;
}

void UpdateAdaptiveRecoveryIntelligence(const string source)
{
   G_DRI_APPLIED = false;
   G_DRI_GRID_BLOCK = false;
   G_DRI_TREND_AGAINST = false;
   G_DRI_ZONE_DANGER = false;
   G_DRI_NEWS_SHOCK = false;
   G_DRI_ORDER_PRESSURE = false;
   G_DRI_HEALTH_SCORE = 100;
   G_DRI_DISTANCE_FACTOR = 1.0;
   G_DRI_LOT_FACTOR = 1.0;

   if(!UseLegacyDeepParityPack || !UseAdaptiveRecoveryIntelligence)
   {
      G_DRI_STATUS = "DRI: OFF";
      G_DRI_REASON = "adaptive recovery disabled";
      G_DRI_DETAIL = "DRI DETAIL: disabled";
      return;
   }

   RefreshGridDashboardStats();

   if(G_BASKET_ORDERS <= 0)
   {
      G_DRI_STATUS = "DRI: FLAT";
      G_DRI_REASON = "no basket";
      G_DRI_DETAIL = "DRI DETAIL: no open basket";
      return;
   }

   int penalty = 0;
   string reason = "";

   double dd = G_BASKET_DD_PERCENT;
   double hard_dd = MathMax(DeepRecoveryDDHardCaution, DeepRecoveryDDStretchStart + 0.1);

   if(dd >= DeepRecoveryDDStretchStart)
   {
      double dd_ratio = DeepRecoveryClampDouble(dd / hard_dd, 0.0, 1.5);
      int dd_penalty = (int)MathRound(35.0 * DeepRecoveryClampDouble(dd_ratio, 0.0, 1.0));
      penalty += dd_penalty;
      reason = reason + StringFormat("DD stretch %.2f%% penalty=%d; ", dd, dd_penalty);

      if(DeepRecoveryUseGridDistance)
         G_DRI_DISTANCE_FACTOR = MathMax(G_DRI_DISTANCE_FACTOR, DeepRecoveryDistanceBoost + dd_ratio * 0.55);

      if(DeepRecoveryUseLotThrottle)
         G_DRI_LOT_FACTOR = MathMin(G_DRI_LOT_FACTOR, DeepRecoveryLotReduceFactor);
   }

   if(MaxOrders > 0 && G_BASKET_ORDERS >= MathMax(1, MaxOrders - 1))
   {
      G_DRI_ORDER_PRESSURE = true;
      penalty += DeepRecoveryOrderPressurePenalty;
      reason = reason + StringFormat("order pressure %d/%d; ", G_BASKET_ORDERS, MaxOrders);

      if(DeepRecoveryUseGridDistance)
         G_DRI_DISTANCE_FACTOR = MathMax(G_DRI_DISTANCE_FACTOR, 1.35);

      if(DeepRecoveryUseLotThrottle)
         G_DRI_LOT_FACTOR = MathMin(G_DRI_LOT_FACTOR, 0.70);
   }

   G_DRI_TREND_AGAINST = DeepRecoveryTrendAgainstBasket();

   if(G_DRI_TREND_AGAINST)
   {
      penalty += DeepRecoveryTrendAgainstPenalty;
      reason = reason + "HTF/structure against basket; ";

      if(DeepRecoveryUseGridDistance)
         G_DRI_DISTANCE_FACTOR = MathMax(G_DRI_DISTANCE_FACTOR, 1.45);

      if(DeepRecoveryUseLotThrottle)
         G_DRI_LOT_FACTOR = MathMin(G_DRI_LOT_FACTOR, 0.65);
   }

   G_DRI_ZONE_DANGER = DeepRecoveryZoneDangerAgainstBasket();

   if(G_DRI_ZONE_DANGER)
   {
      penalty += DeepRecoveryZoneDangerPenalty;
      reason = reason + "opposite zone/trap danger; ";

      if(DeepRecoveryUseGridDistance)
         G_DRI_DISTANCE_FACTOR = MathMax(G_DRI_DISTANCE_FACTOR, 1.35);

      if(DeepRecoveryUseLotThrottle)
         G_DRI_LOT_FACTOR = MathMin(G_DRI_LOT_FACTOR, 0.70);
   }

   G_DRI_NEWS_SHOCK = (G_DNV_NEWS_ACTIVE || G_DNV_SHOCK_ACTIVE || G_DNV_SPREAD_SHOCK || G_DET_POST_SHOCK);

   if(G_DRI_NEWS_SHOCK)
   {
      penalty += DeepRecoveryNewsShockPenalty;
      reason = reason + "news/shock recovery risk; ";

      if(DeepRecoveryUseGridDistance)
         G_DRI_DISTANCE_FACTOR = MathMax(G_DRI_DISTANCE_FACTOR, 1.50);

      if(DeepRecoveryUseLotThrottle)
         G_DRI_LOT_FACTOR = MathMin(G_DRI_LOT_FACTOR, 0.65);
   }

   G_DRI_DISTANCE_FACTOR = DeepRecoveryClampDouble(G_DRI_DISTANCE_FACTOR, 1.0, MathMax(1.0, DeepRecoveryMaxDistanceBoost));
   G_DRI_LOT_FACTOR = DeepRecoveryClampDouble(G_DRI_LOT_FACTOR, MathMax(0.01, DeepRecoveryMinLotFactor), 1.0);

   G_DRI_HEALTH_SCORE = 100 - penalty;

   if(G_DRI_HEALTH_SCORE < 0)
      G_DRI_HEALTH_SCORE = 0;

   if(reason == "")
      reason = "recovery health normal";

   if(DeepRecoveryBlockBadGrid && G_DRI_HEALTH_SCORE < DeepRecoveryMinHealthScore)
      G_DRI_GRID_BLOCK = true;

   G_DRI_APPLIED = (G_DRI_DISTANCE_FACTOR > 1.0 || G_DRI_LOT_FACTOR < 1.0 || G_DRI_GRID_BLOCK);

   G_DRI_REASON = reason;

   if(G_DRI_GRID_BLOCK)
      G_DRI_STATUS = "DRI: GRID BLOCK";
   else if(G_DRI_HEALTH_SCORE < DeepRecoveryMinHealthScore)
      G_DRI_STATUS = "DRI: DEFENSE";
   else if(G_DRI_DISTANCE_FACTOR > 1.0 || G_DRI_LOT_FACTOR < 1.0)
      G_DRI_STATUS = "DRI: ADAPTIVE";
   else
      G_DRI_STATUS = "DRI: HEALTHY";

   G_DRI_DETAIL = StringFormat("DRI DETAIL: health=%d min=%d orders=%d DD=%.2f points=%.0f distX=%.2f lotX=%.2f trendAgainst=%s zoneDanger=%s newsShock=%s | %s",
                               G_DRI_HEALTH_SCORE,
                               DeepRecoveryMinHealthScore,
                               G_BASKET_ORDERS,
                               G_BASKET_DD_PERCENT,
                               G_BASKET_POINTS,
                               G_DRI_DISTANCE_FACTOR,
                               G_DRI_LOT_FACTOR,
                               BoolText(G_DRI_TREND_AGAINST),
                               BoolText(G_DRI_ZONE_DANGER),
                               BoolText(G_DRI_NEWS_SHOCK),
                               G_DRI_REASON);

   string signature = G_DRI_STATUS + "|" + G_DRI_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepRecoveryEvents && signature != G_DRI_LAST_SIGNATURE)
   {
      if(G_DRI_LAST_SIGNATURE == "" || G_DRI_APPLIED || G_DRI_GRID_BLOCK || G_BASKET_ORDERS > 1)
      {
         G_DRI_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.6 DRI] %s | %s | source=%s",
                     G_DRI_STATUS,
                     G_DRI_DETAIL,
                     source);
      }

      G_DRI_LAST_SIGNATURE = signature;
   }
}

double DeepRecoveryAdjustGridDistance(const double base_distance)
{
   double dist = base_distance;

   if(!UseLegacyDeepParityPack || !UseAdaptiveRecoveryIntelligence || !DeepRecoveryUseGridDistance)
      return dist;

   if(G_DRI_DISTANCE_FACTOR > 1.0)
      dist *= G_DRI_DISTANCE_FACTOR;

   return dist;
}

double DeepRecoveryAdjustGridLot(const double base_lot)
{
   double lot = base_lot;

   if(!UseLegacyDeepParityPack || !UseAdaptiveRecoveryIntelligence || !DeepRecoveryUseLotThrottle)
      return lot;

   if(G_DRI_LOT_FACTOR < 1.0)
      lot *= G_DRI_LOT_FACTOR;

   return lot;
}

bool AdaptiveRecoveryAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseAdaptiveRecoveryIntelligence)
   {
      reason = "DRI grid pass";
      return true;
   }

   if(G_DRI_GRID_BLOCK)
   {
      reason = "DRI grid block: " + G_DRI_REASON;
      return false;
   }

   reason = "DRI grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.7 PROFIT EXTRACTION / SMART EXIT BRAIN
//==================================================================//
bool DeepExitHasMinimumMoneyProfit()
{
   if(DeepExitMinProfitMoney <= 0.0)
      return true;

   return (G_BASKET_PROFIT >= DeepExitMinProfitMoney);
}

bool DeepExitOppositeRiskAgainstBasket()
{
   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
   {
      if(G_DTZ_TOP_DANGER && !G_DTZ_BREAKOUT_OK)
         return true;

      if(G_DLP_HTF_DIR < 0 && G_DBOS_DIR < 0)
         return true;
   }

   if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
   {
      if(G_DTZ_BOTTOM_DANGER && !G_DTZ_BREAKOUT_OK)
         return true;

      if(G_DLP_HTF_DIR > 0 && G_DBOS_DIR > 0)
         return true;
   }

   return false;
}

bool DeepExitShockRisk()
{
   if(G_DNV_NEWS_ACTIVE || G_DNV_SPREAD_SHOCK)
      return true;

   if(G_DNV_SHOCK_ACTIVE && G_DNV_EXHAUST_RISK)
      return true;

   if(G_DET_POST_SHOCK)
      return true;

   return false;
}

void DeepExitResetTracking()
{
   G_DXB_PEAK_POINTS = 0.0;
   G_DXB_PEAK_PROFIT = 0.0;
   G_DXB_TRACK_DIR = -1;
   G_DXB_TRACK_ORDERS = 0;
}

void UpdateProfitExtractionSmartExit(const string source)
{
   G_DXB_APPLIED = false;
   G_DXB_CLOSE_SENT = false;
   G_DXB_OPPOSITE_RISK = false;
   G_DXB_SHOCK_RISK = false;
   G_DXB_PEAK_GIVEBACK = false;
   G_DXB_QUICK_PROFIT = false;

   if(!UseLegacyDeepParityPack || !UseProfitExtractionSmartExit)
   {
      G_DXB_STATUS = "DXB: OFF";
      G_DXB_REASON = "smart exit disabled";
      G_DXB_DETAIL = "DXB DETAIL: disabled";
      return;
   }

   RefreshGridDashboardStats();

   if(G_BASKET_ORDERS <= 0)
   {
      DeepExitResetTracking();
      G_DXB_STATUS = "DXB: FLAT";
      G_DXB_REASON = "no basket";
      G_DXB_DETAIL = "DXB DETAIL: no open basket";
      return;
   }

   if(G_DXB_TRACK_DIR != G_BASKET_DIRECTION)
      DeepExitResetTracking();

   G_DXB_TRACK_DIR = G_BASKET_DIRECTION;
   G_DXB_TRACK_ORDERS = G_BASKET_ORDERS;

   if(G_BASKET_POINTS > G_DXB_PEAK_POINTS)
      G_DXB_PEAK_POINTS = G_BASKET_POINTS;

   if(G_BASKET_PROFIT > G_DXB_PEAK_PROFIT)
      G_DXB_PEAK_PROFIT = G_BASKET_PROFIT;

   int protect_points = MathMax(1, DeepExitProtectStartPoints);
   int giveback_points = MathMax(1, DeepExitPeakGivebackPoints);

   double peak_drop_points = G_DXB_PEAK_POINTS - G_BASKET_POINTS;
   double peak_drop_percent = 0.0;

   if(G_DXB_PEAK_POINTS > 0.0)
      peak_drop_percent = peak_drop_points / G_DXB_PEAK_POINTS * 100.0;

   G_DXB_OPPOSITE_RISK = DeepExitOppositeRiskAgainstBasket();
   G_DXB_SHOCK_RISK = DeepExitShockRisk();

   if(G_DXB_PEAK_POINTS >= protect_points &&
      peak_drop_points >= giveback_points &&
      peak_drop_percent >= DeepExitPeakGivebackPercent)
   {
      G_DXB_PEAK_GIVEBACK = true;
   }

   if(G_BASKET_ORDERS >= MathMax(1, DeepExitMultiOrderMinOrders) &&
      G_BASKET_POINTS >= MathMax(1, DeepExitMultiOrderProfitPoints) &&
      DeepExitHasMinimumMoneyProfit())
   {
      G_DXB_QUICK_PROFIT = true;
   }

   string reason = "";
   bool close_now = false;

   if(DeepExitEnableAutoClose)
   {
      if(DeepExitQuickMultiOrderProfit && G_DXB_QUICK_PROFIT)
      {
         close_now = true;
         reason = "quick multi-order profit extraction";
      }
      else if(DeepExitCloseOnPeakGiveback && G_DXB_PEAK_GIVEBACK && DeepExitHasMinimumMoneyProfit())
      {
         close_now = true;
         reason = StringFormat("peak giveback %.0f/%.0f %.1f%%",
                               peak_drop_points,
                               G_DXB_PEAK_POINTS,
                               peak_drop_percent);
      }
      else if(DeepExitCloseOnOppositeRisk &&
              G_DXB_OPPOSITE_RISK &&
              G_BASKET_POINTS >= MathMax(1, DeepExitOppositeRiskMinPoints) &&
              DeepExitHasMinimumMoneyProfit())
      {
         close_now = true;
         reason = "profit protected from opposite zone/HTF risk";
      }
      else if(DeepExitCloseOnShockRisk &&
              G_DXB_SHOCK_RISK &&
              G_BASKET_POINTS >= MathMax(1, DeepExitShockRiskMinPoints) &&
              DeepExitHasMinimumMoneyProfit())
      {
         close_now = true;
         reason = "profit protected from news/shock risk";
      }
   }

   if(reason == "")
      reason = "smart exit monitoring";

   if(close_now)
   {
      G_DXB_CLOSE_SENT = true;
      G_DXB_APPLIED = true;

      bool closed = CloseSirusBasket("Deep Smart Exit: " + reason);
      RefreshGridDashboardStats();

      if(closed)
         G_DXB_STATUS = "DXB: CLOSED";
      else
         G_DXB_STATUS = "DXB: CLOSE FAILED";

      G_DXB_REASON = reason;
      DeepExitResetTracking();
   }
   else if(G_DXB_QUICK_PROFIT)
   {
      G_DXB_STATUS = "DXB: QUICK PROFIT READY";
      G_DXB_REASON = "quick profit condition ready";
   }
   else if(G_DXB_PEAK_GIVEBACK)
   {
      G_DXB_STATUS = "DXB: GIVEBACK";
      G_DXB_REASON = "peak giveback detected";
   }
   else if(G_DXB_OPPOSITE_RISK || G_DXB_SHOCK_RISK)
   {
      G_DXB_STATUS = "DXB: PROTECT WATCH";
      G_DXB_REASON = "risk detected while basket active";
   }
   else if(G_DXB_PEAK_POINTS >= protect_points)
   {
      G_DXB_STATUS = "DXB: PROTECTING";
      G_DXB_REASON = "profit protection armed";
   }
   else
   {
      G_DXB_STATUS = "DXB: MONITOR";
      G_DXB_REASON = reason;
   }

   G_DXB_DETAIL = StringFormat("DXB DETAIL: orders=%d points=%.0f peakPts=%.0f drop=%.0f dropPct=%.1f profit=%.2f peakProfit=%.2f quick=%s giveback=%s oppRisk=%s shockRisk=%s autoClose=%s | %s",
                               G_BASKET_ORDERS,
                               G_BASKET_POINTS,
                               G_DXB_PEAK_POINTS,
                               peak_drop_points,
                               peak_drop_percent,
                               G_BASKET_PROFIT,
                               G_DXB_PEAK_PROFIT,
                               BoolText(G_DXB_QUICK_PROFIT),
                               BoolText(G_DXB_PEAK_GIVEBACK),
                               BoolText(G_DXB_OPPOSITE_RISK),
                               BoolText(G_DXB_SHOCK_RISK),
                               BoolText(DeepExitEnableAutoClose),
                               G_DXB_REASON);

   string signature = G_DXB_STATUS + "|" + G_DXB_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintDeepExitEvents && signature != G_DXB_LAST_SIGNATURE)
   {
      if(G_DXB_LAST_SIGNATURE == "" || G_DXB_APPLIED || G_DXB_QUICK_PROFIT || G_DXB_PEAK_GIVEBACK || G_DXB_OPPOSITE_RISK || G_DXB_SHOCK_RISK)
      {
         G_DXB_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.7 DXB] %s | %s | source=%s",
                     G_DXB_STATUS,
                     G_DXB_DETAIL,
                     source);
      }

      G_DXB_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 23.8 MARKET REGIME AUTO-TUNING BRAIN
//==================================================================//
int RegimeDominantDirection()
{
   if(G_DLP_HTF_DIR != 0)
      return G_DLP_HTF_DIR;

   if(G_MARKET_STATE == MARKET_TREND_UP)
      return 1;

   if(G_MARKET_STATE == MARKET_TREND_DOWN)
      return -1;

   if(G_DBOS_DIR != 0)
      return G_DBOS_DIR;

   return 0;
}

bool RegimeRangeEdgeSupportsSignal(const int opp)
{
   if(opp == 0)
      return false;

   if(G_DTZ_TRAP_DIR == opp)
      return true;

   if(G_DLP_ZONE_DIR == opp)
      return true;

   if(G_DBOS_RETEST_READY && G_DBOS_DIR == opp)
      return true;

   return false;
}

void UpdateMarketRegimeAutoTuningBrain(const string source)
{
   G_DRT_APPLIED = false;
   G_DRT_ENTRY_BLOCK = false;
   G_DRT_GRID_BLOCK = false;
   G_DRT_TREND_MODE = false;
   G_DRT_RANGE_MODE = false;
   G_DRT_SHOCK_MODE = false;
   G_DRT_CHAOS_MODE = false;
   G_DRT_REGIME_DIR = 0;
   G_DRT_BONUS = 0;
   G_DRT_PENALTY = 0;
   G_DRT_GRID_FACTOR = 1.0;
   G_DRT_LOT_FACTOR = 1.0;

   if(!UseLegacyDeepParityPack || !UseMarketRegimeAutoTuningBrain)
   {
      G_DRT_STATUS = "DRT: OFF";
      G_DRT_REASON = "regime auto-tuning disabled";
      G_DRT_DETAIL = "DRT DETAIL: disabled";
      return;
   }

   int opp = DeepOpportunitySign();
   string reason = "";

   G_DRT_REGIME_DIR = RegimeDominantDirection();

   if(G_MARKET_STATE == MARKET_TREND_UP || G_MARKET_STATE == MARKET_TREND_DOWN || G_MARKET_STATE == MARKET_PULLBACK)
   {
      G_DRT_TREND_MODE = true;

      if(opp != 0 && G_DRT_REGIME_DIR == opp)
      {
         G_DRT_BONUS += RegimeTrendAlignBonus;
         reason = reason + "trend aligned; ";
      }
      else if(opp != 0 && G_DRT_REGIME_DIR == -opp)
      {
         G_DRT_PENALTY += RegimeAgainstTrendPenalty;
         reason = reason + "against dominant trend; ";

         if(RegimeTuneUseGridDistance)
            G_DRT_GRID_FACTOR = MathMax(G_DRT_GRID_FACTOR, RegimeGridTrendAgainstDistanceFactor);
      }
      else
      {
         reason = reason + "trend neutral; ";
      }
   }

   if(G_MARKET_STATE == MARKET_RANGE)
   {
      G_DRT_RANGE_MODE = true;

      if(RegimeRangeEdgeSupportsSignal(opp))
      {
         G_DRT_BONUS += RegimeRangeEdgeBonus;
         reason = reason + "range edge supports signal; ";
      }
      else if(opp != 0 && G_DNV_SHOCK_DIR == opp)
      {
         G_DRT_PENALTY += RegimeRangeChasePenalty;
         reason = reason + "range momentum chase risk; ";
      }
      else
      {
         reason = reason + "range neutral; ";
      }
   }

   if(G_MARKET_STATE == MARKET_IMPULSE || G_DNV_SHOCK_ACTIVE || G_DNV_NEWS_ACTIVE || G_DNV_SPREAD_SHOCK)
   {
      G_DRT_SHOCK_MODE = true;
      G_DRT_PENALTY += RegimeShockPenalty;
      reason = reason + "shock/impulse regime; ";

      if(opp != 0 && G_DNV_SHOCK_DIR == opp && !G_DNV_EXHAUST_RISK)
      {
         G_DRT_BONUS += RegimeMomentumContinuationBonus;
         reason = reason + "momentum continuation allowed; ";
      }

      if(RegimeTuneUseGridDistance)
         G_DRT_GRID_FACTOR = MathMax(G_DRT_GRID_FACTOR, RegimeGridShockDistanceFactor);

      if(RegimeTuneUseLotThrottle)
         G_DRT_LOT_FACTOR = MathMin(G_DRT_LOT_FACTOR, RegimeLotShockFactor);

      if(RegimeTuneBlockGridInShock)
         G_DRT_GRID_BLOCK = true;
   }

   if(G_MARKET_STATE == MARKET_EXHAUSTION)
   {
      if(opp != 0 && (G_DTZ_TRAP_DIR == opp || G_DLP_ZONE_DIR == opp || G_DBOS_CHOCH_ACTIVE))
      {
         G_DRT_BONUS += RegimeExhaustionReversalBonus;
         reason = reason + "exhaustion reversal supports signal; ";
      }
      else
      {
         G_DRT_PENALTY += 1;
         reason = reason + "exhaustion caution; ";
      }
   }

   if(G_MARKET_STATE == MARKET_DEAD || G_MARKET_STATE == MARKET_CHAOS)
   {
      G_DRT_CHAOS_MODE = true;
      G_DRT_PENALTY += RegimeDeadChaosPenalty;
      reason = reason + "dead/chaos market; ";

      if(RegimeTuneUseGridDistance)
         G_DRT_GRID_FACTOR = MathMax(G_DRT_GRID_FACTOR, RegimeGridChaosDistanceFactor);

      if(RegimeTuneUseLotThrottle)
         G_DRT_LOT_FACTOR = MathMin(G_DRT_LOT_FACTOR, RegimeLotChaosFactor);

      if(RegimeTuneStrictDeadChaosBlock)
      {
         G_DRT_ENTRY_BLOCK = true;
         G_DRT_GRID_BLOCK = true;
      }
   }

   if(reason == "")
      reason = "regime normal";

   if(G_DRT_GRID_FACTOR < 1.0)
      G_DRT_GRID_FACTOR = 1.0;

   if(G_DRT_LOT_FACTOR <= 0.0 || G_DRT_LOT_FACTOR > 1.0)
      G_DRT_LOT_FACTOR = 1.0;

   if(RegimeTuneUseScoreIntegration && (G_SCORE_DECISION != SCORE_DECISION_HARD_BLOCK))
   {
      if(G_DRT_BONUS > 0 || G_DRT_PENALTY > 0)
      {
         LegacyApplyScoreChange(G_DRT_BONUS, G_DRT_PENALTY, "regime auto-tune " + reason);
         LegacyRecalculateDecision();
         G_DRT_APPLIED = true;
      }
   }

   G_DRT_REASON = reason;

   if(G_DRT_ENTRY_BLOCK || G_DRT_GRID_BLOCK)
      G_DRT_STATUS = "DRT: STRICT BLOCK";
   else if(G_DRT_CHAOS_MODE)
      G_DRT_STATUS = "DRT: CHAOS DEFENSE";
   else if(G_DRT_SHOCK_MODE)
      G_DRT_STATUS = "DRT: SHOCK DEFENSE";
   else if(G_DRT_RANGE_MODE)
      G_DRT_STATUS = "DRT: RANGE TUNE";
   else if(G_DRT_TREND_MODE)
      G_DRT_STATUS = "DRT: TREND TUNE";
   else if(G_DRT_APPLIED)
      G_DRT_STATUS = "DRT: TUNED";
   else
      G_DRT_STATUS = "DRT: NORMAL";

   G_DRT_DETAIL = StringFormat("DRT DETAIL: market=%s opp=%s regimeDir=%s bonus=%d penalty=%d gridX=%.2f lotX=%.2f trend=%s range=%s shock=%s chaos=%s | %s",
                               MarketStateToString(G_MARKET_STATE),
                               DeepDirText(opp),
                               DeepDirText(G_DRT_REGIME_DIR),
                               G_DRT_BONUS,
                               G_DRT_PENALTY,
                               G_DRT_GRID_FACTOR,
                               G_DRT_LOT_FACTOR,
                               BoolText(G_DRT_TREND_MODE),
                               BoolText(G_DRT_RANGE_MODE),
                               BoolText(G_DRT_SHOCK_MODE),
                               BoolText(G_DRT_CHAOS_MODE),
                               G_DRT_REASON);

   string signature = G_DRT_STATUS + "|" + G_DRT_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintRegimeTuneEvents && signature != G_DRT_LAST_SIGNATURE)
   {
      if(G_DRT_LAST_SIGNATURE == "" || G_DRT_APPLIED || G_DRT_ENTRY_BLOCK || G_DRT_GRID_BLOCK || G_DRT_SHOCK_MODE || G_DRT_CHAOS_MODE)
      {
         G_DRT_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.8 DRT] %s | %s | source=%s",
                     G_DRT_STATUS,
                     G_DRT_DETAIL,
                     source);
      }

      G_DRT_LAST_SIGNATURE = signature;
   }
}

double RegimeTuneAdjustGridDistance(const double base_distance)
{
   double dist = base_distance;

   if(!UseLegacyDeepParityPack || !UseMarketRegimeAutoTuningBrain || !RegimeTuneUseGridDistance)
      return dist;

   if(G_DRT_GRID_FACTOR > 1.0)
      dist *= G_DRT_GRID_FACTOR;

   return dist;
}

double RegimeTuneAdjustGridLot(const double base_lot)
{
   double lot = base_lot;

   if(!UseLegacyDeepParityPack || !UseMarketRegimeAutoTuningBrain || !RegimeTuneUseLotThrottle)
      return lot;

   if(G_DRT_LOT_FACTOR > 0.0 && G_DRT_LOT_FACTOR < 1.0)
      lot *= G_DRT_LOT_FACTOR;

   return lot;
}

bool MarketRegimeAutoTuneAllowsEntry(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseMarketRegimeAutoTuningBrain)
   {
      reason = "DRT entry pass";
      return true;
   }

   if(G_DRT_ENTRY_BLOCK)
   {
      reason = "DRT entry block: " + G_DRT_REASON;
      return false;
   }

   reason = "DRT entry pass";
   return true;
}

bool MarketRegimeAutoTuneAllowsGrid(string &reason)
{
   if(!UseLegacyDeepParityPack || !UseMarketRegimeAutoTuningBrain)
   {
      reason = "DRT grid pass";
      return true;
   }

   if(G_DRT_GRID_BLOCK)
   {
      reason = "DRT grid block: " + G_DRT_REASON;
      return false;
   }

   reason = "DRT grid pass";
   return true;
}


//==================================================================//
//  PHASE 23.9 SMART CLIENT SAFETY / RENTAL PROTECTION BRAIN
//==================================================================//
string ClientSafetyProfile()
{
   // V249fix(auto-mode): under SirusMode = AUTO the live mode is decided per scan, but this preset
   // is a STRING INPUT that never moves - so the HIGH_HUNTER limits were unreachable: the EA could
   // run in HIGH_HUNTER all session while this governor kept applying BALANCED caps (7 orders vs 9,
   // 0.25 first lot vs 0.50). That is a brake nobody asked for, and it hides itself - the two
   // branches currently return the same spread number, so you cannot see the mode being ignored.
   // In AUTO the governor now follows the mode actually in force (frozen per basket once one is
   // open, live otherwise). An EXPLICIT SirusMode still uses the string, so nothing changes for a
   // user who set the mode by hand.
   if(SirusMode == SIRUS_MODE_AUTO)
   {
      // Same rule: an explicit CONSERVATIVE choice outranks the live mode.
      string cp = P4MiniClientRiskProfile;
      StringTrimLeft(cp);
      StringTrimRight(cp);
      if(cp == "CONSERVATIVE" || cp == "SAFE" || cp == "safe" || cp == "conservative")
         return "SAFE";

      ENUM_SIRUS_MODE eff = (G_BASKET_MODE_FROZEN ? G_BASKET_FROZEN_MODE : G_ACTIVE_MODE);
      if(eff == SIRUS_MODE_HIGH_HUNTER)
         return "HIGH_HUNTER";
      return "BALANCED";
   }

   string p = P4MiniClientRiskProfile;
   StringTrimLeft(p);
   StringTrimRight(p);

   if(p == "CONSERVATIVE" || p == "SAFE" || p == "safe" || p == "conservative")
      return "SAFE";

   if(p == "AGGRESSIVE" || p == "HIGH" || p == "HIGH_HUNTER" || p == "aggressive")
      return "HIGH_HUNTER";

   return "BALANCED";
}

int ClientSafetySpreadLimit()
{
   string p = ClientSafetyProfile();

   if(p == "SAFE")
      return EffSpread(ClientSafetyMaxSpreadSafe);

   if(p == "HIGH_HUNTER")
      return EffSpread(ClientSafetyMaxSpreadHighHunter);

   return EffSpread(ClientSafetyMaxSpreadBalanced);
}

void ClientSafetyAddWarning(const string text, string &reason)
{
   G_DCS_WARNINGS++;

   if(StringLen(reason) < 520)
      reason = reason + text + "; ";
}

void UpdateSmartClientSafetyBrain(const string source)
{
   G_DCS_APPLIED = false;
   G_DCS_ENTRY_BLOCK = false;
   G_DCS_GRID_BLOCK = false;
   G_DCS_LICENSE_RISK = false;
   G_DCS_SPREAD_RISK = false;
   G_DCS_DD_RISK = false;
   G_DCS_ORDER_RISK = false;
   G_DCS_RENTAL_PROFILE = false;
   G_DCS_GRID_FACTOR = 1.0;
   G_DCS_LOT_FACTOR = 1.0;
   G_DCS_WARNINGS = 0;

   if(!UseSmartClientSafetyBrain)
   {
      G_DCS_STATUS = "DCS: OFF";
      G_DCS_REASON = "client safety disabled";
      G_DCS_DETAIL = "DCS DETAIL: disabled";
      return;
   }

   RefreshGridDashboardStats();

   string reason = "";
   string profile = ClientSafetyProfile();

   if(ReleaseProfile() == "RENTAL_DEMO" || ReleaseRequireLicenseForClient || P4MiniUseLicenseControl)
      G_DCS_RENTAL_PROFILE = true;

   if(G_DCS_RENTAL_PROFILE && ClientSafetyRequireLicenseWhenRental && !P4MiniUseLicenseControl)
   {
      G_DCS_LICENSE_RISK = true;
      ClientSafetyAddWarning("rental profile but license OFF", reason);

      if(ClientSafetyStrictEnforce)
      {
         G_DCS_ENTRY_BLOCK = true;
         G_DCS_GRID_BLOCK = true;
      }
   }

   if(G_DCS_RENTAL_PROFILE && ClientSafetyWarnEmptyWhitelist && P4MiniUseLicenseControl && StringLen(P4MiniAccountWhitelist) <= 0)
   {
      G_DCS_LICENSE_RISK = true;
      ClientSafetyAddWarning("license ON but whitelist empty", reason);

      if(ClientSafetyStrictEnforce)
         G_DCS_ENTRY_BLOCK = true;
   }

   int spread_limit = ClientSafetySpreadLimit();

   if(spread_limit > 0 && G_LAST_SPREAD_POINTS > spread_limit)
   {
      G_DCS_SPREAD_RISK = true;
      ClientSafetyAddWarning(StringFormat("spread high %d/%d", G_LAST_SPREAD_POINTS, spread_limit), reason);

      if(ClientSafetyBlockHighSpread || ClientSafetyStrictEnforce)
         G_DCS_ENTRY_BLOCK = true;

      if(ClientSafetyUseGridDistance)
         G_DCS_GRID_FACTOR = MathMax(G_DCS_GRID_FACTOR, ClientSafetyGridDistanceFactor);
   }

   double dd = MathMax(G_BASKET_DD_PERCENT, G_RISK_EQUITY_DD_PCT);

   if(dd >= ClientSafetyDDWarnPercent)
   {
      G_DCS_DD_RISK = true;
      ClientSafetyAddWarning(StringFormat("DD warning %.2f%%", dd), reason);

      if(ClientSafetyUseGridDistance)
         G_DCS_GRID_FACTOR = MathMax(G_DCS_GRID_FACTOR, ClientSafetyGridDistanceFactor);

      if(ClientSafetyUseLotThrottle)
         G_DCS_LOT_FACTOR = MathMin(G_DCS_LOT_FACTOR, ClientSafetyLotThrottleFactor);
   }

   if(dd >= ClientSafetyDDDangerPercent)
   {
      G_DCS_DD_RISK = true;
      ClientSafetyAddWarning(StringFormat("DD danger %.2f%%", dd), reason);

      if(ClientSafetyUseGridDistance)
         G_DCS_GRID_FACTOR = MathMax(G_DCS_GRID_FACTOR, ClientSafetyDangerDistanceFactor);

      if(ClientSafetyUseLotThrottle)
         G_DCS_LOT_FACTOR = MathMin(G_DCS_LOT_FACTOR, ClientSafetyDangerLotFactor);

      if(ClientSafetyStrictEnforce)
         G_DCS_GRID_BLOCK = true;
   }

   if(G_BASKET_ORDERS >= MathMax(1, ClientSafetyMaxOrdersWarn))
   {
      G_DCS_ORDER_RISK = true;
      ClientSafetyAddWarning(StringFormat("order pressure %d/%d", G_BASKET_ORDERS, ClientSafetyMaxOrdersWarn), reason);

      if(ClientSafetyUseGridDistance)
         G_DCS_GRID_FACTOR = MathMax(G_DCS_GRID_FACTOR, ClientSafetyGridDistanceFactor);

      if(ClientSafetyUseLotThrottle)
         G_DCS_LOT_FACTOR = MathMin(G_DCS_LOT_FACTOR, ClientSafetyLotThrottleFactor);
   }

   if(G_DCS_LOT_FACTOR <= 0.0 || G_DCS_LOT_FACTOR > 1.0)
      G_DCS_LOT_FACTOR = 1.0;

   if(G_DCS_GRID_FACTOR < 1.0)
      G_DCS_GRID_FACTOR = 1.0;

   if(reason == "")
      reason = "client safety normal";

   G_DCS_APPLIED = (G_DCS_WARNINGS > 0 || G_DCS_GRID_FACTOR > 1.0 || G_DCS_LOT_FACTOR < 1.0 || G_DCS_ENTRY_BLOCK || G_DCS_GRID_BLOCK);
   G_DCS_REASON = reason;

   if(G_DCS_ENTRY_BLOCK || G_DCS_GRID_BLOCK)
      G_DCS_STATUS = "DCS: STRICT BLOCK";
   else if(G_DCS_DD_RISK)
      G_DCS_STATUS = "DCS: DD DEFENSE";
   else if(G_DCS_LICENSE_RISK)
      G_DCS_STATUS = "DCS: LICENSE WARN";
   else if(G_DCS_SPREAD_RISK)
      G_DCS_STATUS = "DCS: SPREAD WARN";
   else if(G_DCS_ORDER_RISK)
      G_DCS_STATUS = "DCS: ORDER WARN";
   else if(G_DCS_RENTAL_PROFILE)
      G_DCS_STATUS = "DCS: RENTAL READY";
   else
      G_DCS_STATUS = "DCS: SAFE";

   G_DCS_DETAIL = StringFormat("DCS DETAIL: profile=%s rental=%s warnings=%d spread=%d/%d DD=%.2f orders=%d gridX=%.2f lotX=%.2f strict=%s | %s",
                               profile,
                               BoolText(G_DCS_RENTAL_PROFILE),
                               G_DCS_WARNINGS,
                               G_LAST_SPREAD_POINTS,
                               spread_limit,
                               dd,
                               G_BASKET_ORDERS,
                               G_DCS_GRID_FACTOR,
                               G_DCS_LOT_FACTOR,
                               BoolText(ClientSafetyStrictEnforce),
                               G_DCS_REASON);

   string signature = G_DCS_STATUS + "|" + G_DCS_DETAIL + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintClientSafetyEvents && signature != G_DCS_LAST_SIGNATURE)
   {
      if(G_DCS_LAST_SIGNATURE == "" || G_DCS_APPLIED || G_DCS_ENTRY_BLOCK || G_DCS_GRID_BLOCK)
      {
         G_DCS_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 23.9 DCS] %s | %s | source=%s",
                     G_DCS_STATUS,
                     G_DCS_DETAIL,
                     source);
      }

      G_DCS_LAST_SIGNATURE = signature;
   }
}

double ClientSafetyAdjustGridDistance(const double base_distance)
{
   double dist = base_distance;

   if(!UseSmartClientSafetyBrain || !ClientSafetyUseGridDistance)
      return dist;

   if(G_DCS_GRID_FACTOR > 1.0)
      dist *= G_DCS_GRID_FACTOR;

   return dist;
}

double ClientSafetyAdjustGridLot(const double base_lot)
{
   double lot = base_lot;

   if(!UseSmartClientSafetyBrain || !ClientSafetyUseLotThrottle)
      return lot;

   if(G_DCS_LOT_FACTOR > 0.0 && G_DCS_LOT_FACTOR < 1.0)
      lot *= G_DCS_LOT_FACTOR;

   return lot;
}

// V31.6z6 fix: these two were accidentally deleted along with the unrelated
// FinalPresetHardening QA-audit cluster - same "PresetHardening" name prefix, but this pair
// is part of the legitimate post-floor grid distance/lot chain (compile error found via live
// testing). G_DPH_GRID_FACTOR/G_DPH_LOT_FACTOR are permanently 1.0 now (their updater is the
// FinalPresetHardening brain we intentionally removed), so these are safely inert no-ops -
// fixes the compile error while keeping FinalPresetHardening's influence fully neutralized.
double PresetHardeningAdjustGridDistance(const double base_distance)
{
   double dist = base_distance;

   if(!PresetHardeningUseGridDistance)
      return dist;

   if(G_DPH_GRID_FACTOR > 1.0)
      dist *= G_DPH_GRID_FACTOR;

   return dist;
}

double PresetHardeningAdjustGridLot(const double base_lot)
{
   double lot = base_lot;

   if(!PresetHardeningUseLotThrottle)
      return lot;

   if(G_DPH_LOT_FACTOR > 0.0 && G_DPH_LOT_FACTOR < 1.0)
      lot *= G_DPH_LOT_FACTOR;

   return lot;
}

bool SmartClientSafetyAllowsEntry(string &reason)
{
   if(!UseSmartClientSafetyBrain)
   {
      reason = "DCS entry pass";
      return true;
   }

   if(G_DCS_ENTRY_BLOCK)
   {
      reason = "DCS entry block: " + G_DCS_REASON;
      return false;
   }

   reason = "DCS entry pass";
   return true;
}

bool SmartClientSafetyAllowsGrid(string &reason)
{
   if(!UseSmartClientSafetyBrain)
   {
      reason = "DCS grid pass";
      return true;
   }

   if(G_DCS_GRID_BLOCK)
   {
      reason = "DCS grid block: " + G_DCS_REASON;
      return false;
   }

   reason = "DCS grid pass";
   return true;
}


//==================================================================//
//  PHASE 24.0 FINAL INTELLIGENCE MERGE / v24 PRO BRAIN
//==================================================================//
void FinalMergeAddPenalty(const bool condition,
                          const int value,
                          const string text,
                          int &penalty,
                          string &reason)
{
   if(!condition)
      return;

   int v = MathMax(0, value);
   penalty += v;

   if(StringLen(reason) < 620)
      reason = reason + text + " -" + IntegerToString(v) + "; ";
}

void FinalMergeAddBonus(const bool condition,
                        const int value,
                        const string text,
                        int &bonus,
                        string &reason)
{
   if(!condition)
      return;

   int v = MathMax(0, value);
   bonus += v;

   if(StringLen(reason) < 620)
      reason = reason + text + " +" + IntegerToString(v) + "; ";
}
