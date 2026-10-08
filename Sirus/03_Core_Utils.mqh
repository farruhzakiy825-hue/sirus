//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 03_Core_Utils                                   |
//| Text helpers, environment checks, indicator handles              |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  STRING HELPERS
//==================================================================//
// V29: placed first in the file so every later function can safely use it (MQL5 requires
// a function to be defined before its first use in the same file).
string YesNoV29(const bool v) { return (v ? "YES" : "NO"); }

string ModeToString(ENUM_SIRUS_MODE mode)
{
   switch(mode)
   {
      case SIRUS_MODE_AUTO:        return "AUTO";
      case SIRUS_MODE_BALANCED:    return "BALANCED";
      case SIRUS_MODE_HIGH_HUNTER: return "HIGH_HUNTER";
   }
   return "UNKNOWN";
}

// Compact mode tag for order comments, which MT5 caps near 31 chars.
string ModeToShortString(ENUM_SIRUS_MODE mode)
{
   switch(mode)
   {
      case SIRUS_MODE_AUTO:        return "AUTO";
      case SIRUS_MODE_BALANCED:    return "BAL";
      case SIRUS_MODE_HIGH_HUNTER: return "HUNT";
   }
   return "UNK";
}


bool IsForcedMode()
{
   return (SirusMode == SIRUS_MODE_BALANCED || SirusMode == SIRUS_MODE_HIGH_HUNTER);
}

bool IsValidTradingMode(ENUM_SIRUS_MODE mode)
{
   return (mode == SIRUS_MODE_BALANCED || mode == SIRUS_MODE_HIGH_HUNTER);
}


string MarketStateToString(ENUM_MARKET_STATE state)
{
   switch(state)
   {
      case MARKET_UNKNOWN:    return "UNKNOWN";
      case MARKET_TREND_UP:   return "TREND_UP";
      case MARKET_TREND_DOWN: return "TREND_DOWN";
      case MARKET_RANGE:      return "RANGE";
      case MARKET_IMPULSE:    return "IMPULSE";
      case MARKET_PULLBACK:   return "PULLBACK";
      case MARKET_EXHAUSTION: return "EXHAUSTION";
      case MARKET_DEAD:       return "DEAD";
      case MARKET_CHAOS:      return "CHAOS";
   }
   return "UNKNOWN";
}

string OpportunityDirToString(ENUM_OPPORTUNITY_DIR dir)
{
   switch(dir)
   {
      case OPP_DIR_NONE: return "NONE";
      case OPP_DIR_BUY:  return "BUY";
      case OPP_DIR_SELL: return "SELL";
   }
   return "NONE";
}

string OpportunityGradeToString(ENUM_OPPORTUNITY_GRADE grade)
{
   switch(grade)
   {
      case OPP_GRADE_NONE:    return "NONE";
      case OPP_GRADE_C_MICRO: return "C MICRO";
      case OPP_GRADE_B:       return "B";
      case OPP_GRADE_A_PLUS:  return "A+";
   }
   return "NONE";
}

string OpportunityTypeToString(ENUM_OPPORTUNITY_TYPE type)
{
   switch(type)
   {
      case OPP_TYPE_NONE:                  return "NONE";
      case OPP_TYPE_RANGE_EDGE:            return "RANGE_EDGE";
      case OPP_TYPE_SWEEP_REJECTION:       return "SWEEP_REJECTION";
      case OPP_TYPE_NEAR_ZONE_REACTION:    return "NEAR_ZONE_REACTION";
      case OPP_TYPE_FAKE_BREAKOUT_RETURN:  return "FAKE_BREAKOUT_RETURN";
      case OPP_TYPE_PULLBACK_CONTINUATION: return "PULLBACK_CONTINUATION";
      case OPP_TYPE_EXHAUSTION_REVERSAL:   return "EXHAUSTION_REVERSAL";
      case OPP_TYPE_MOMENTUM_SCALP:        return "MOMENTUM_SCALP";
      case OPP_TYPE_SESSION_SCALP:         return "SESSION_SCALP";
      case OPP_TYPE_BREAKOUT_CONTINUATION: return "BREAKOUT_CONTINUATION";
      case OPP_TYPE_TREND_RIDE:            return "TREND_RIDE";
      case OPP_TYPE_SWING_CONTINUATION:    return "SWING_CONTINUATION";
      case OPP_TYPE_MA_BOUNCE:             return "MA_BOUNCE";
      case OPP_TYPE_DONCHIAN_BREAKOUT:      return "DONCHIAN_BREAKOUT";
      case OPP_TYPE_CONSECUTIVE_CANDLES:    return "CONSECUTIVE_CANDLES";
      case OPP_TYPE_DXY_CONFIRMED_TREND:    return "DXY_CONFIRMED_TREND";
      case OPP_TYPE_EXPANDING_VOLATILITY:   return "EXPANDING_VOLATILITY";
      case OPP_TYPE_MTF_UNANIMOUS:          return "MTF_UNANIMOUS";
      case OPP_TYPE_EQ_ZONE_TREND:          return "EQ_ZONE_TREND";
      case OPP_TYPE_VOLUME_PUSH:            return "VOLUME_PUSH";
      case OPP_TYPE_VWAP_BOUNCE:            return "VWAP_BOUNCE";
      case OPP_TYPE_ZONE_RETEST:            return "ZONE_RETEST";
   }
   return "NONE";
}




string TempBlockToString(ENUM_TEMP_BLOCK_TYPE block_type)
{
   switch(block_type)
   {
      case TEMP_BLOCK_NONE:        return "NONE";
      case TEMP_BLOCK_SCORE_WEAK:  return "SCORE_WEAK";
      case TEMP_BLOCK_IMPULSE:     return "IMPULSE";
      case TEMP_BLOCK_SOFT_SPREAD: return "SOFT_SPREAD";
      case TEMP_BLOCK_ROOM_TO_TP:  return "ROOM_TO_TP";
      case TEMP_BLOCK_MICRO_GUARD: return "MICRO_GUARD";
      case TEMP_BLOCK_QUEUE_WAIT:  return "QUEUE_WAIT";
      case TEMP_BLOCK_REDIRECT:    return "REDIRECT";
      case TEMP_BLOCK_BOS_RETEST:  return "BOS_RETEST";
      case TEMP_BLOCK_ZONE_DANGER: return "ZONE_DANGER";
   }
   return "UNKNOWN";
}

string MicroTPModeToString(ENUM_MICRO_TP_MODE mode)
{
   switch(mode)
   {
      case MICRO_TP_AUTO:           return "AUTO";
      case MICRO_TP_FIXED:          return "FIXED";
      case MICRO_TP_MAIN_PERCENT:   return "MAIN_PERCENT";
      case MICRO_TP_DYNAMIC_MARKET: return "DYNAMIC_MARKET";
   }
   return "AUTO";
}

string ScoreDecisionToString(ENUM_SCORE_DECISION decision)
{
   switch(decision)
   {
      case SCORE_DECISION_NONE:       return "NONE";
      case SCORE_DECISION_WAIT:       return "WAIT";
      case SCORE_DECISION_PASS:       return "PASS";
      case SCORE_DECISION_MICRO_PASS: return "MICRO_PASS";
      case SCORE_DECISION_HARD_BLOCK: return "HARD_BLOCK";
   }
   return "NONE";
}

string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "PERIOD_M1";
      case PERIOD_M2:   return "PERIOD_M2";
      case PERIOD_M3:   return "PERIOD_M3";
      case PERIOD_M4:   return "PERIOD_M4";
      case PERIOD_M5:   return "PERIOD_M5";
      case PERIOD_M6:   return "PERIOD_M6";
      case PERIOD_M10:  return "PERIOD_M10";
      case PERIOD_M12:  return "PERIOD_M12";
      case PERIOD_M15:  return "PERIOD_M15";
      case PERIOD_M20:  return "PERIOD_M20";
      case PERIOD_M30:  return "PERIOD_M30";
      case PERIOD_H1:   return "PERIOD_H1";
      case PERIOD_H2:   return "PERIOD_H2";
      case PERIOD_H3:   return "PERIOD_H3";
      case PERIOD_H4:   return "PERIOD_H4";
      case PERIOD_H6:   return "PERIOD_H6";
      case PERIOD_H8:   return "PERIOD_H8";
      case PERIOD_H12:  return "PERIOD_H12";
      case PERIOD_D1:   return "PERIOD_D1";
      case PERIOD_W1:   return "PERIOD_W1";
      case PERIOD_MN1:  return "PERIOD_MN1";
   }
   return "PERIOD_UNKNOWN";
}

string SafeTime(datetime t)
{
   if(t <= 0)
      return "n/a";
   return TimeToString(t, TIME_DATE|TIME_SECONDS);
}


//==================================================================//
//  PHASE 22.8 TYPE-SAFE STRING HELPERS
//==================================================================//
string SafeLongText(const long value)
{
   return IntegerToString(value);
}

string SafeIntText(const int value)
{
   return IntegerToString(value);
}

string SafeDateTimeKey(const datetime value)
{
   return IntegerToString((long)value);
}

int SafeHourClamp(const int hour_value)
{
   int h = hour_value;

   if(h < 0)
      h = 0;

   if(h > 23)
      h = 23;

   return h;
}

string BoolText(bool value)
{
   return value ? "true" : "false";
}

string TradeModeToString(long mode)
{
   if(mode == SYMBOL_TRADE_MODE_DISABLED)  return "DISABLED";
   if(mode == SYMBOL_TRADE_MODE_LONGONLY)  return "LONGONLY";
   if(mode == SYMBOL_TRADE_MODE_SHORTONLY) return "SHORTONLY";
   if(mode == SYMBOL_TRADE_MODE_CLOSEONLY) return "CLOSEONLY";
   if(mode == SYMBOL_TRADE_MODE_FULL)      return "FULL";
   return "UNKNOWN";
}

//==================================================================//
//  CORE STATUS HELPERS
//==================================================================//
void SetStatus(const string status, const string event_text="")
{
   G_LAST_STATUS = status;
   if(event_text != "")
      G_LAST_EVENT = event_text;
}

int GetSpreadPoints()
{
   long spread = -1;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread))
      return (int)spread;

   double ask = 0.0;
   double bid = 0.0;
   if(SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) && SymbolInfoDouble(_Symbol, SYMBOL_BID, bid) && _Point > 0.0)
      return (int)MathRound((ask - bid) / _Point);

   return -1;
}

// V30.3: effective max-spread resolver (unified master or per-module fallback).
int EffSpread(const int module_value)
{
   if(UseUnifiedMaxSpread && UnifiedMaxSpreadPoints > 0)
      return UnifiedMaxSpreadPoints;
   return module_value;
}

int TickAgeSeconds()
{
   if(G_LAST_TICK_LOCAL <= 0)
      return -1;
   return (int)(TimeLocal() - G_LAST_TICK_LOCAL);
}

bool IsHistoryReadyTF(const ENUM_TIMEFRAMES tf, const int min_bars, string &details)
{
   int bars_count = Bars(_Symbol, tf);
   datetime t0    = iTime(_Symbol, tf, 0);

   long synced = 0;
   bool sync_ok = SeriesInfoInteger(_Symbol, tf, SERIES_SYNCHRONIZED, synced);

   details = StringFormat("%s Bars=%d/%d t0=%s sync=%s/%d",
                          TFToString(tf),
                          bars_count,
                          min_bars,
                          SafeTime(t0),
                          BoolText(sync_ok),
                          (int)synced);

   if(bars_count < min_bars)
      return false;

   if(t0 <= 0)
      return false;

   if(sync_ok && synced == 0)
      return false;

   return true;
}

void UpdateClockState()
{
   datetime local_now  = TimeLocal();
   datetime current    = TimeCurrent();
   datetime trade_srv  = TimeTradeServer();

   G_CLOCK_STATUS = StringFormat("CLOCK: local=%s | current=%s | trade_server=%s",
                                 SafeTime(local_now),
                                 SafeTime(current),
                                 SafeTime(trade_srv));
}

void UpdateTickState()
{
   int age = TickAgeSeconds();
   G_LAST_SPREAD_POINTS = GetSpreadPoints();

   MqlTick tick;
   bool tick_ok = SymbolInfoTick(_Symbol, tick);

   if(age < 0)
      G_TICK_STATUS = StringFormat("TICK: no tick yet | tick_ok=%s | spread=%d", BoolText(tick_ok), G_LAST_SPREAD_POINTS);
   else
      G_TICK_STATUS = StringFormat("TICK: age=%ds | ticks=%I64u | tick_ok=%s | spread=%d",
                                   age,
                                   G_TICK_COUNT,
                                   BoolText(tick_ok),
                                   G_LAST_SPREAD_POINTS);

   if(PrintTickStaleWarning && age >= MaxTickAgeSeconds)
      G_LAST_WARNING = StringFormat("TICK STALE: %ds without tick on %s", age, _Symbol);
}

void UpdateBarTracker(const string source)
{
   G_IS_NEW_BAR = false;   // PERF: reset each call; set true below only when a new bar opens
   datetime bar_time = iTime(_Symbol, CoreBarTF, 0);
   int bars_count    = Bars(_Symbol, CoreBarTF);

   if(bar_time <= 0 || bars_count <= 0)
   {
      G_BAR_STATUS = StringFormat("BAR: not ready | TF=%s | Bars=%d | source=%s",
                                  TFToString(CoreBarTF),
                                  bars_count,
                                  source);
      SetStatus("CORE WAIT: bar history not ready", "UpdateBarTracker");
      return;
   }

   if(G_LAST_BAR_TIME <= 0)
   {
      G_LAST_BAR_TIME = bar_time;
      G_BAR_STATUS = StringFormat("BAR INIT: TF=%s | current=%s | Bars=%d",
                                  TFToString(CoreBarTF),
                                  SafeTime(G_LAST_BAR_TIME),
                                  bars_count);
      SetStatus("CORE READY: bar tracker initialized", "first bar init");
      return;
   }

   if(bar_time != G_LAST_BAR_TIME)
   {
      G_IS_NEW_BAR = true;   // PERF: a fresh bar opened this tick
      datetime old_bar = G_LAST_BAR_TIME;
      G_LAST_BAR_TIME = bar_time;
      G_BARS_SEEN++;

      G_BAR_STATUS = StringFormat("NEW BAR: TF=%s | count=%d | old=%s | new=%s | source=%s",
                                  TFToString(CoreBarTF),
                                  G_BARS_SEEN,
                                  SafeTime(old_bar),
                                  SafeTime(G_LAST_BAR_TIME),
                                  source);

      if(PrintNewBarLog)
      {
         PrintFormat("[SIRUS v31.6 PHASE 22.9] NEW BAR | TF=%s | count=%d | old=%s | new=%s | source=%s",
                     TFToString(CoreBarTF),
                     G_BARS_SEEN,
                     SafeTime(old_bar),
                     SafeTime(G_LAST_BAR_TIME),
                     source);
      }
   }
   else
   {
      G_BAR_STATUS = StringFormat("BAR OK: TF=%s | seen=%d | current=%s | Bars=%d | source=%s",
                                  TFToString(CoreBarTF),
                                  G_BARS_SEEN,
                                  SafeTime(G_LAST_BAR_TIME),
                                  bars_count,
                                  source);
   }
}

//==================================================================//
//  PHASE 21.3 ENVIRONMENT ENGINE
//==================================================================//
bool CheckSymbolEnvironment()
{
   bool ok = true;

   bool selected = SymbolSelect(_Symbol, true);

   bool keyword_ok = true;
   if(StrictGoldSymbolCheck && RequiredSymbolKeyword != "")
      keyword_ok = (StringFind(_Symbol, RequiredSymbolKeyword) >= 0);

   long trade_mode = -1;
   bool trade_mode_ok = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode);

   bool full_mode_ok = true;
   if(RequireFullTradeMode)
      full_mode_ok = (trade_mode == SYMBOL_TRADE_MODE_FULL);

   G_ENV_SYMBOL_STATUS = StringFormat("SYMBOL: %s | selected=%s | keyword=%s/%s | trade_mode=%s",
                                      _Symbol,
                                      BoolText(selected),
                                      RequiredSymbolKeyword,
                                      BoolText(keyword_ok),
                                      TradeModeToString(trade_mode));

   if(!selected)
   {
      G_ENV_BLOCK_REASON = "symbol not selected";
      ok = false;
   }
   else if(!keyword_ok)
   {
      G_ENV_BLOCK_REASON = "symbol keyword mismatch";
      ok = false;
   }
   else if(!trade_mode_ok)
   {
      G_ENV_BLOCK_REASON = "symbol trade mode unreadable";
      ok = false;
   }
   else if(RequireFullTradeMode && !full_mode_ok)
   {
      G_ENV_BLOCK_REASON = "symbol trade mode not FULL";
      ok = false;
   }

   return ok;
}

bool CheckTradePermissions()
{
   bool terminal_allowed = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   bool mql_allowed      = (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
   bool account_trade    = (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
   bool expert_trade     = (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);

   G_ENV_TRADE_STATUS = StringFormat("TRADE: terminal=%s | mql=%s | account=%s | expert=%s",
                                     BoolText(terminal_allowed),
                                     BoolText(mql_allowed),
                                     BoolText(account_trade),
                                     BoolText(expert_trade));

   if(!RequireTradePermission)
      return true;

   if(!terminal_allowed)
   {
      G_ENV_BLOCK_REASON = "terminal AutoTrading disabled";
      return false;
   }
   if(!mql_allowed)
   {
      G_ENV_BLOCK_REASON = "MQL trading disabled for EA";
      return false;
   }
   if(!account_trade)
   {
      G_ENV_BLOCK_REASON = "account trading disabled";
      return false;
   }
   if(!expert_trade)
   {
      G_ENV_BLOCK_REASON = "expert trading disabled on account";
      return false;
   }

   return true;
}

bool CheckSpreadEnvironment()
{
   int spread = GetSpreadPoints();
   G_LAST_SPREAD_POINTS = spread;

   G_ENV_SPREAD_STATUS = StringFormat("SPREAD: %d | max=%d | critical=%d",
                                      spread,
                                      EffSpread(MaxSpreadPoints),
                                      CriticalSpreadPoints);

   if(spread < 0)
   {
      G_ENV_BLOCK_REASON = "spread unreadable";
      return false;
   }

   if(spread >= CriticalSpreadPoints)
   {
      G_ENV_BLOCK_REASON = StringFormat("critical spread high %d/%d", spread, CriticalSpreadPoints);
      return false;
   }

   if(spread > EffSpread(MaxSpreadPoints))
   {
      G_ENV_BLOCK_REASON = StringFormat("spread high %d/%d", spread, EffSpread(MaxSpreadPoints));
      return false;
   }

   return true;
}

bool CheckHistoryEnvironment()
{
   string d1, d5, d15, d60;
   bool ok1  = IsHistoryReadyTF(PERIOD_M1,  MinBarsM1,  d1);
   bool ok5  = IsHistoryReadyTF(PERIOD_M5,  MinBarsM5,  d5);
   bool ok15 = IsHistoryReadyTF(PERIOD_M15, MinBarsM15, d15);
   bool ok60 = IsHistoryReadyTF(PERIOD_H1,  MinBarsH1,  d60);

   G_ENV_HISTORY_STATUS = "HISTORY: " + d1 + " | " + d5 + " | " + d15 + " | " + d60;

   if(!ok1)
   {
      G_ENV_BLOCK_REASON = "M1 history not ready";
      return false;
   }
   if(!ok5)
   {
      G_ENV_BLOCK_REASON = "M5 history not ready";
      return false;
   }
   if(!ok15)
   {
      G_ENV_BLOCK_REASON = "M15 history not ready";
      return false;
   }
   if(!ok60)
   {
      G_ENV_BLOCK_REASON = "H1 history not ready";
      return false;
   }

   return true;
}

bool CheckLotEnvironment()
{
   double vmin  = 0.0;
   double vmax  = 0.0;
   double vstep = 0.0;

   bool ok_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN,  vmin);
   bool ok_max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX,  vmax);
   bool ok_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, vstep);

   G_ENV_LOT_STATUS = StringFormat("LOT: min=%.2f | max=%.2f | step=%.2f",
                                   vmin, vmax, vstep);

   if(!ok_min || !ok_max || !ok_step)
   {
      G_ENV_BLOCK_REASON = "lot info unreadable";
      return false;
   }

   if(vmin <= 0.0 || vmax <= 0.0 || vstep <= 0.0 || vmax < vmin)
   {
      G_ENV_BLOCK_REASON = "lot info invalid";
      return false;
   }

   return true;
}

bool CheckLevelEnvironment()
{
   long stop_level   = 0;
   long freeze_level = 0;

   bool ok_stop   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stop_level);
   bool ok_freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);

   G_ENV_LEVEL_STATUS = StringFormat("LEVELS: stop=%d | freeze=%d",
                                     (int)stop_level,
                                     (int)freeze_level);

   if(!ok_stop || !ok_freeze)
   {
      G_ENV_BLOCK_REASON = "stop/freeze level unreadable";
      return false;
   }

   if(stop_level < 0 || freeze_level < 0)
   {
      G_ENV_BLOCK_REASON = "stop/freeze level invalid";
      return false;
   }

   return true;
}

bool CheckTickFlowEnvironment()
{
   int age = TickAgeSeconds();
   if(age < 0)
   {
      G_ENV_BLOCK_REASON = "no tick received yet";
      return false;
   }

   if(age > MaxTickAgeSeconds)
   {
      G_ENV_BLOCK_REASON = StringFormat("tick stale %ds/%d", age, MaxTickAgeSeconds);
      return false;
   }

   return true;
}

void UpdateEnvironmentEngine()
{
   G_ENV_BLOCK_REASON = "none";

   bool ok_symbol  = CheckSymbolEnvironment();
   bool ok_trade   = CheckTradePermissions();
   bool ok_spread  = CheckSpreadEnvironment();
   bool ok_history = CheckHistoryEnvironment();
   bool ok_lot     = CheckLotEnvironment();
   bool ok_levels  = CheckLevelEnvironment();
   bool ok_tick    = CheckTickFlowEnvironment();

   G_ENV_READY = (ok_symbol && ok_trade && ok_spread && ok_history && ok_lot && ok_levels && ok_tick);

   if(G_ENV_READY)
      G_ENV_STATUS = "ENV READY";
   else
      G_ENV_STATUS = "ENV BLOCK: " + G_ENV_BLOCK_REASON;

   string signature = G_ENV_STATUS + "|" + G_ENV_SYMBOL_STATUS + "|" + G_ENV_TRADE_STATUS + "|" + G_ENV_SPREAD_STATUS;

   if(PrintEnvOnChange && signature != G_ENV_LAST_SIGNATURE)
   {
      G_ENV_LAST_SIGNATURE = signature;
      PrintFormat("[SIRUS v31.6 PHASE 21.3 ENV] %s | %s | %s | %s | %s",
                  G_ENV_STATUS,
                  G_ENV_SYMBOL_STATUS,
                  G_ENV_TRADE_STATUS,
                  G_ENV_SPREAD_STATUS,
                  G_ENV_LEVEL_STATUS);
   }

   if(G_ENV_READY)
      SetStatus("CORE + ENV READY: first entry only in Phase 21.3", "EnvironmentEngine");
   else
      SetStatus(G_ENV_STATUS, "EnvironmentEngine");
}



//==================================================================//
//  MARKET MATH HELPERS
//==================================================================//
double PointsBetween(const double a, const double b)
{
   if(_Point <= 0.0)
      return 0.0;
   return MathAbs(a - b) / _Point;
}

double CandleHigh(const ENUM_TIMEFRAMES tf, const int shift)
{
   return iHigh(_Symbol, tf, shift);
}

double CandleLow(const ENUM_TIMEFRAMES tf, const int shift)
{
   return iLow(_Symbol, tf, shift);
}

double CandleOpen(const ENUM_TIMEFRAMES tf, const int shift)
{
   return iOpen(_Symbol, tf, shift);
}

double CandleClose(const ENUM_TIMEFRAMES tf, const int shift)
{
   return iClose(_Symbol, tf, shift);
}

// V31.6c new: D1 overall direction - the "big picture" Hunter mode was missing entirely.
// Simple close-vs-close-N-bars-back, same method as HTFStructureBias, just on D1 instead of H1.
int D1OverallDirection()
{
   double close_now  = CandleClose(PERIOD_D1, 1);
   double close_then = CandleClose(PERIOD_D1, MathMax(2, HunterD1LookbackDays));
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0;
   if(close_now > close_then)
      return 1;
   if(close_now < close_then)
      return -1;
   return 0;
}

// V31.6c new: live tick-velocity direction - reuses the existing spike detector's own state
// (G_VEL_SPIKE_UNTIL / rate ratio) rather than waiting for a candle to close. This is genuine
// "before the candle closes" impulse sensing: a real acceleration happening in ticks RIGHT NOW,
// not a description of a move that already finished.
int LiveVelocityDirection()
{
   if(TimeCurrent() > G_VEL_SPIKE_UNTIL)
      return 0; // no live spike right now

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;

   double ref = CandleClose(SignalTF, 1);
   if(mid <= 0.0 || ref <= 0.0)
      return 0;

   if(mid > ref) return 1;
   if(mid < ref) return -1;
   return 0;
}

double CandleRangePoints(const ENUM_TIMEFRAMES tf, const int shift)
{
   double h = CandleHigh(tf, shift);
   double l = CandleLow(tf, shift);
   if(h <= 0.0 || l <= 0.0 || h < l)
      return 0.0;
   return PointsBetween(h, l);
}

double CandleBodyPoints(const ENUM_TIMEFRAMES tf, const int shift)
{
   double o = CandleOpen(tf, shift);
   double c = CandleClose(tf, shift);
   if(o <= 0.0 || c <= 0.0)
      return 0.0;
   return PointsBetween(o, c);
}

double UpperWickPoints(const ENUM_TIMEFRAMES tf, const int shift)
{
   double h = CandleHigh(tf, shift);
   double o = CandleOpen(tf, shift);
   double c = CandleClose(tf, shift);
   if(h <= 0.0 || o <= 0.0 || c <= 0.0)
      return 0.0;
   return PointsBetween(h, MathMax(o, c));
}

double LowerWickPoints(const ENUM_TIMEFRAMES tf, const int shift)
{
   double l = CandleLow(tf, shift);
   double o = CandleOpen(tf, shift);
   double c = CandleClose(tf, shift);
   if(l <= 0.0 || o <= 0.0 || c <= 0.0)
      return 0.0;
   return PointsBetween(MathMin(o, c), l);
}

// ============================================================================
// FEATURE(wick-sweep): user request - a real liquidity sweep takes out the prior high/low with
// the WICK (shadow) only, then the BODY closes back inside. If the candle BODY itself trades
// through the level (both open AND close beyond it), that is a genuine break, not a stop-hunt
// wick - price accepted the new level rather than rejecting it. These two helpers encode exactly
// that distinction and are reused by every sweep detector so the whole bot shares one honest
// definition of "swept by wick, not body".
//
//   IsWickSweepLow : the bar's LOW pierced 'level' (l < level) but the body held above it
//                    (min(open,close) >= level, within a tiny tolerance), AND the lower wick is
//                    a meaningful fraction of the range. => bullish stop-hunt below support.
//   IsWickSweepHigh: the bar's HIGH pierced 'level' (h > level) but the body held below it
//                    (max(open,close) <= level), AND the upper wick is meaningful.
//                    => bearish stop-hunt above resistance.
// ============================================================================
input group "ADVANCED ▸ Wick-based liquidity sweep (body must not break the level)"
// EnableWickSweepFilter: Require sweeps to be taken by wick, not by candle body
input bool   EnableWickSweepFilter        = true;   // Enable wick sweep filter
// WickSweepMinWickRatio: Rejection wick must be at least this fraction of the candle's range
input double WickSweepMinWickRatio        = 0.35;   // Wick sweep min wick ratio
// WickSweepBodyTolerancePoints: Small grace (points): body may close a hair past the level and still count as a wick sweep (spread/noise). 0 = strict.
input double WickSweepBodyTolerancePoints = 20;   // Wick sweep body tolerance points

bool IsWickSweepLow(const ENUM_TIMEFRAMES tf, const int shift, const double level)
{
   if(!EnableWickSweepFilter)
      return true;   // filter off -> don't constrain callers

   double l = CandleLow(tf, shift);
   double o = CandleOpen(tf, shift);
   double c = CandleClose(tf, shift);
   double range = CandleRangePoints(tf, shift);
   if(l <= 0.0 || o <= 0.0 || c <= 0.0 || level <= 0.0 || range <= 0.0)
      return false;

   double tol = MathMax(0.0, WickSweepBodyTolerancePoints) * _Point;
   double body_low = MathMin(o, c);

   bool wick_pierced = (l < level);                 // shadow took the liquidity below the level
   bool body_held    = (body_low >= level - tol);   // but the body stayed above it (not a real break)
   double lower_wick = LowerWickPoints(tf, shift);
   bool wick_big     = ((lower_wick / range) >= WickSweepMinWickRatio);

   return (wick_pierced && body_held && wick_big);
}

bool IsWickSweepHigh(const ENUM_TIMEFRAMES tf, const int shift, const double level)
{
   if(!EnableWickSweepFilter)
      return true;

   double h = CandleHigh(tf, shift);
   double o = CandleOpen(tf, shift);
   double c = CandleClose(tf, shift);
   double range = CandleRangePoints(tf, shift);
   if(h <= 0.0 || o <= 0.0 || c <= 0.0 || level <= 0.0 || range <= 0.0)
      return false;

   double tol = MathMax(0.0, WickSweepBodyTolerancePoints) * _Point;
   double body_high = MathMax(o, c);

   bool wick_pierced = (h > level);                  // shadow took the liquidity above the level
   bool body_held    = (body_high <= level + tol);   // body stayed below it (not a real break)
   double upper_wick = UpperWickPoints(tf, shift);
   bool wick_big     = ((upper_wick / range) >= WickSweepMinWickRatio);

   return (wick_pierced && body_held && wick_big);
}

// V31.6d upgrade: was a manual close-sum loop; now uses MT5's native iMA (SMA method) via a
// small handle cache, same pattern as the ATR upgrade earlier. Directly improves accuracy/speed
// for every consumer: DetectTrendState's SMA fallback, and the Deep HTF Commander cross-check.
#define SIRUS_SMA_CACHE_SIZE 12
int G_SMA_CACHE_TF[SIRUS_SMA_CACHE_SIZE];
int G_SMA_CACHE_PERIOD[SIRUS_SMA_CACHE_SIZE];
int G_SMA_CACHE_HANDLE[SIRUS_SMA_CACHE_SIZE];
int G_SMA_CACHE_COUNT = 0;
int G_SMA_CACHE_EVICT_NEXT = 0;   // FIX(handle-leak): cache full -> release evicted slot, reuse it

int SirusGetSMAHandle(const ENUM_TIMEFRAMES tf, const int period)
{
   for(int i = 0; i < G_SMA_CACHE_COUNT; i++)
   {
      if(G_SMA_CACHE_TF[i] == (int)tf && G_SMA_CACHE_PERIOD[i] == period)
         return G_SMA_CACHE_HANDLE[i];
   }

   int h = iMA(_Symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE)
      return INVALID_HANDLE;

   if(G_SMA_CACHE_COUNT < SIRUS_SMA_CACHE_SIZE)
   {
      G_SMA_CACHE_TF[G_SMA_CACHE_COUNT] = (int)tf;
      G_SMA_CACHE_PERIOD[G_SMA_CACHE_COUNT] = period;
      G_SMA_CACHE_HANDLE[G_SMA_CACHE_COUNT] = h;
      G_SMA_CACHE_COUNT++;
   }
   else
   {
      // FIX(handle-leak): cache full - release the evicted slot's handle before reusing it,
      // otherwise a new iMA handle leaks on every uncached (tf,period) request.
      int slot = G_SMA_CACHE_EVICT_NEXT;
      if(G_SMA_CACHE_HANDLE[slot] != INVALID_HANDLE)
         IndicatorRelease(G_SMA_CACHE_HANDLE[slot]);
      G_SMA_CACHE_TF[slot] = (int)tf;
      G_SMA_CACHE_PERIOD[slot] = period;
      G_SMA_CACHE_HANDLE[slot] = h;
      G_SMA_CACHE_EVICT_NEXT = (slot + 1) % SIRUS_SMA_CACHE_SIZE;
   }
   return h;
}

void SirusReleaseSMAHandles()
{
   for(int i = 0; i < G_SMA_CACHE_COUNT; i++)
   {
      if(G_SMA_CACHE_HANDLE[i] != INVALID_HANDLE)
      {
         IndicatorRelease(G_SMA_CACHE_HANDLE[i]);
         G_SMA_CACHE_HANDLE[i] = INVALID_HANDLE;
      }
   }
   G_SMA_CACHE_COUNT = 0;
   G_SMA_CACHE_EVICT_NEXT = 0;
}

double SMA(const ENUM_TIMEFRAMES tf, const int period, const int start_shift)
{
   if(period <= 0)
      return 0.0;

   int handle = SirusGetSMAHandle(tf, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, start_shift, 1, buf) != 1)
      return 0.0;

   return buf[0];
}

// V31.6i new: native RSI, same handle-cache pattern as SMA/ATR. Used by the new Trend Reversal
// / Divergence detector - momentum divergence needs a real oscillator, not a price-only proxy.
#define SIRUS_RSI_CACHE_SIZE 8
int G_RSI_CACHE_TF[SIRUS_RSI_CACHE_SIZE];
int G_RSI_CACHE_PERIOD[SIRUS_RSI_CACHE_SIZE];
int G_RSI_CACHE_HANDLE[SIRUS_RSI_CACHE_SIZE];
int G_RSI_CACHE_COUNT = 0;
int G_RSI_CACHE_EVICT_NEXT = 0;   // FIX(handle-leak)

int SirusGetRSIHandle(const ENUM_TIMEFRAMES tf, const int period)
{
   for(int i = 0; i < G_RSI_CACHE_COUNT; i++)
   {
      if(G_RSI_CACHE_TF[i] == (int)tf && G_RSI_CACHE_PERIOD[i] == period)
         return G_RSI_CACHE_HANDLE[i];
   }

   int h = iRSI(_Symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE)
      return INVALID_HANDLE;

   if(G_RSI_CACHE_COUNT < SIRUS_RSI_CACHE_SIZE)
   {
      G_RSI_CACHE_TF[G_RSI_CACHE_COUNT] = (int)tf;
      G_RSI_CACHE_PERIOD[G_RSI_CACHE_COUNT] = period;
      G_RSI_CACHE_HANDLE[G_RSI_CACHE_COUNT] = h;
      G_RSI_CACHE_COUNT++;
   }
   else
   {
      // FIX(handle-leak): release evicted slot before reusing.
      int slot = G_RSI_CACHE_EVICT_NEXT;
      if(G_RSI_CACHE_HANDLE[slot] != INVALID_HANDLE)
         IndicatorRelease(G_RSI_CACHE_HANDLE[slot]);
      G_RSI_CACHE_TF[slot] = (int)tf;
      G_RSI_CACHE_PERIOD[slot] = period;
      G_RSI_CACHE_HANDLE[slot] = h;
      G_RSI_CACHE_EVICT_NEXT = (slot + 1) % SIRUS_RSI_CACHE_SIZE;
   }
   return h;
}

void SirusReleaseRSIHandles()
{
   for(int i = 0; i < G_RSI_CACHE_COUNT; i++)
   {
      if(G_RSI_CACHE_HANDLE[i] != INVALID_HANDLE)
      {
         IndicatorRelease(G_RSI_CACHE_HANDLE[i]);
         G_RSI_CACHE_HANDLE[i] = INVALID_HANDLE;
      }
   }
   G_RSI_CACHE_COUNT = 0;
   G_RSI_CACHE_EVICT_NEXT = 0;
}

double SirusRSI(const ENUM_TIMEFRAMES tf, const int period, const int shift)
{
   if(period <= 0)
      return 0.0;

   int handle = SirusGetRSIHandle(tf, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
      return 0.0;

   return buf[0];
}

// V31.6q new: native ADX, same handle-cache pattern as RSI/SMA/ATR. Fills a real gap: Trend
// Reversal only fires on a CHANGE of swing character - a strong, sustained, ALREADY-ONGOING
// move (no fresh reversal pattern, just persistent continuation) slipped past it silently.
// ADX measures trend STRENGTH directly, regardless of whether it's changing or continuing.
#define SIRUS_ADX_CACHE_SIZE 8
int G_ADX_CACHE_TF[SIRUS_ADX_CACHE_SIZE];
int G_ADX_CACHE_PERIOD[SIRUS_ADX_CACHE_SIZE];
int G_ADX_CACHE_HANDLE[SIRUS_ADX_CACHE_SIZE];
int G_ADX_CACHE_COUNT = 0;
int G_ADX_CACHE_EVICT_NEXT = 0;   // FIX(handle-leak): ADX is requested with the most distinct
                                  // (tf,period) combos, so it overflowed the cache most often -
                                  // every overflow used to iADX() a fresh handle and drop it on
                                  // the floor. Now the evicted slot is released and reused.

int SirusGetADXHandle(const ENUM_TIMEFRAMES tf, const int period)
{
   for(int i = 0; i < G_ADX_CACHE_COUNT; i++)
   {
      if(G_ADX_CACHE_TF[i] == (int)tf && G_ADX_CACHE_PERIOD[i] == period)
         return G_ADX_CACHE_HANDLE[i];
   }

   int h = iADX(_Symbol, tf, period);
   if(h == INVALID_HANDLE)
      return INVALID_HANDLE;

   if(G_ADX_CACHE_COUNT < SIRUS_ADX_CACHE_SIZE)
   {
      G_ADX_CACHE_TF[G_ADX_CACHE_COUNT] = (int)tf;
      G_ADX_CACHE_PERIOD[G_ADX_CACHE_COUNT] = period;
      G_ADX_CACHE_HANDLE[G_ADX_CACHE_COUNT] = h;
      G_ADX_CACHE_COUNT++;
   }
   else
   {
      int slot = G_ADX_CACHE_EVICT_NEXT;
      if(G_ADX_CACHE_HANDLE[slot] != INVALID_HANDLE)
         IndicatorRelease(G_ADX_CACHE_HANDLE[slot]);
      G_ADX_CACHE_TF[slot] = (int)tf;
      G_ADX_CACHE_PERIOD[slot] = period;
      G_ADX_CACHE_HANDLE[slot] = h;
      G_ADX_CACHE_EVICT_NEXT = (slot + 1) % SIRUS_ADX_CACHE_SIZE;
   }
   return h;
}

void SirusReleaseADXHandles()
{
   for(int i = 0; i < G_ADX_CACHE_COUNT; i++)
   {
      if(G_ADX_CACHE_HANDLE[i] != INVALID_HANDLE)
      {
         IndicatorRelease(G_ADX_CACHE_HANDLE[i]);
         G_ADX_CACHE_HANDLE[i] = INVALID_HANDLE;
      }
   }
   G_ADX_CACHE_COUNT = 0;
   G_ADX_CACHE_EVICT_NEXT = 0;
}

// buffer: 0=main ADX line, 1=+DI, 2=-DI
double SirusADX(const ENUM_TIMEFRAMES tf, const int period, const int buffer, const int shift)
{
   if(period <= 0)
      return 0.0;

   int handle = SirusGetADXHandle(tf, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, buffer, shift, 1, buf) != 1)
      return 0.0;

   return buf[0];
}

// V31.6z4 speed fix: several detectors (Trend Ride, EQ Zone Trend) each called SirusADX
// three times DIRECTLY, uncached - four detectors alone meant 12 CopyBuffer reads per tick
// for the SAME (tf, period) data. Shared multi-slot per-bar cache, same spirit as the
// handle-cache above but for the actual VALUES, not just the indicator handle.
#define SIRUS_ADX_SNAP_CACHE_SIZE 8
int    G_ADX_SNAP_CACHE_BAR[SIRUS_ADX_SNAP_CACHE_SIZE];
int    G_ADX_SNAP_CACHE_TF[SIRUS_ADX_SNAP_CACHE_SIZE];
int    G_ADX_SNAP_CACHE_PERIOD[SIRUS_ADX_SNAP_CACHE_SIZE];
double G_ADX_SNAP_CACHE_ADX[SIRUS_ADX_SNAP_CACHE_SIZE];
double G_ADX_SNAP_CACHE_PLUS[SIRUS_ADX_SNAP_CACHE_SIZE];
double G_ADX_SNAP_CACHE_MINUS[SIRUS_ADX_SNAP_CACHE_SIZE];
int    G_ADX_SNAP_CACHE_COUNT = 0;

void CachedADXSnapshot(const ENUM_TIMEFRAMES tf, const int period, double &adx, double &plus_di, double &minus_di)
{
   for(int i = 0; i < G_ADX_SNAP_CACHE_COUNT; i++)
   {
      if(G_ADX_SNAP_CACHE_TF[i] == (int)tf && G_ADX_SNAP_CACHE_PERIOD[i] == period)
      {
         if(G_ADX_SNAP_CACHE_BAR[i] != G_BARS_SEEN)
         {
            G_ADX_SNAP_CACHE_ADX[i]   = SirusADX(tf, period, 0, 1);
            G_ADX_SNAP_CACHE_PLUS[i]  = SirusADX(tf, period, 1, 1);
            G_ADX_SNAP_CACHE_MINUS[i] = SirusADX(tf, period, 2, 1);
            G_ADX_SNAP_CACHE_BAR[i]   = G_BARS_SEEN;
         }
         adx = G_ADX_SNAP_CACHE_ADX[i];
         plus_di = G_ADX_SNAP_CACHE_PLUS[i];
         minus_di = G_ADX_SNAP_CACHE_MINUS[i];
         return;
      }
   }

   adx      = SirusADX(tf, period, 0, 1);
   plus_di  = SirusADX(tf, period, 1, 1);
   minus_di = SirusADX(tf, period, 2, 1);

   if(G_ADX_SNAP_CACHE_COUNT < SIRUS_ADX_SNAP_CACHE_SIZE)
   {
      int idx = G_ADX_SNAP_CACHE_COUNT;
      G_ADX_SNAP_CACHE_TF[idx]     = (int)tf;
      G_ADX_SNAP_CACHE_PERIOD[idx] = period;
      G_ADX_SNAP_CACHE_BAR[idx]    = G_BARS_SEEN;
      G_ADX_SNAP_CACHE_ADX[idx]    = adx;
      G_ADX_SNAP_CACHE_PLUS[idx]   = plus_di;
      G_ADX_SNAP_CACHE_MINUS[idx]  = minus_di;
      G_ADX_SNAP_CACHE_COUNT++;
   }
}

// V31.6z20 NEW: ADX DECELERATION. Real, systemic gap found via deeper audit after today's
// exhaustion fix: TrendStrengthAgainst, TrendQualityScore, Trend Ride, and EQ Zone Trend all
// read ADX's raw VALUE (is it >= a threshold) but NONE of them ever compare it to a prior bar
// to see if ADX itself is FALLING even while still numerically "strong". A falling ADX after
// a peak is one of the most well-known exhaustion signals in technical analysis - a trend
// that's still technically "strong" by the threshold but actively losing steam right now.
double ADXDecelerationFactor(const ENUM_TIMEFRAMES tf, const int period, const int lookback_bars)
{
   if(!EnableADXDeceleration)
      return 0.0;

   double adx_now = SirusADX(tf, period, 0, 1);
   double adx_prior = SirusADX(tf, period, 0, MathMax(2, lookback_bars + 1));

   if(adx_now <= 0.0 || adx_prior <= 0.0)
      return 0.0;

   double drop = adx_prior - adx_now;
   if(drop < ADXDecelerationMinDrop)
      return 0.0;

   return MathMin(1.0, drop / MathMax(1.0, ADXDecelerationMinDrop * 3.0));
}

int SimpleTFDirection(const ENUM_TIMEFRAMES tf, const int lookback);
