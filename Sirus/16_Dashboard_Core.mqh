//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 16_Dashboard_Core                               |
//| Client dashboard, CoreUpdate pipeline, dashboard drawing         |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//==================================================================//
//  PHASE 24.2 SETTINGS GOVERNANCE / CLIENT INPUT GUARD
//==================================================================//
//==================================================================//
//  PHASE 24.3 CLIENT-FACING DASHBOARD / LOG POLISH
//==================================================================//
string ClientDashMode()
{
   string p = ClientDashboardViewMode;
   StringTrimLeft(p);
   StringTrimRight(p);

   if(p == "COMPACT" || p == "compact")
      return "COMPACT";

   if(p == "RENTAL" || p == "rental")
      return "RENTAL";

   if(p == "INTERNAL" || p == "internal")
      return "INTERNAL";

   return "PRO";
}

string ClientDashSafeReason(const string text)
{
   int max_chars = MathMax(20, ClientDashReasonMaxChars);
   return ShortText(text, max_chars);
}

// BOSQICH 2: G_NIM_SCORE kodda hech qayerda hisoblanmaydi (faqat 0 bilan boshlanadi). Shu sababli
// dashboard DOIM "RISK: DEFENSE — wait / protect capital" va "- defense" ko'rsatardi, savdo ruxsat
// etilgan paytda ham. Hisoblanmagan ball (0) - "noma'lum", xavf emas.
int NIMScoreForDash()
{
   return (G_NIM_SCORE > 0) ? G_NIM_SCORE : 100;
}

string ClientDashRiskBanner()
{
   if(G_NIM_ENTRY_BLOCK || G_NIM_GRID_BLOCK || G_FPR_ENTRY_BLOCK || G_FPR_GRID_BLOCK || G_SGV_ENTRY_BLOCK || G_SGV_GRID_BLOCK)
      return "RISK: BLOCK — safety protection active";

   if(NIMScoreForDash() < ClientDashDefenseScore || G_RISK_HARD_BLOCK)
      return "RISK: DEFENSE — wait / protect capital";

   if(G_DNV_NEWS_ACTIVE || G_DNV_SHOCK_ACTIVE || G_DRT_SHOCK_MODE || G_DCS_DD_RISK)
      return "RISK: CAUTION — volatile / recovery defense";

   if(NIMScoreForDash() < ClientDashWarnScore || G_FPR_WARNINGS > 0 || G_SGV_WARNINGS > 0)
      return "RISK: WATCH — settings/release warnings";

   if(G_NIM_SCORE >= ClientDashProScore && G_NIM_PRO_READY)
      return "RISK: CLEAN — PRO conditions";

   return "RISK: NORMAL — balanced trading";
}

string ClientDashReleaseBadge()
{
   if(G_FPR_PRO_READY && G_NIM_PRO_READY)
      return "SIRUS BY ZAKIY - pro ready";

   if(G_FPR_READY && G_NIM_READY)
      return "SIRUS BY ZAKIY - ready";

   if(G_FPR_WARNINGS > 0 || G_SGV_WARNINGS > 0)
      return "SIRUS BY ZAKIY - review settings";

   if(NIMScoreForDash() < ClientDashDefenseScore)
      return "SIRUS BY ZAKIY - defense";

   return "SIRUS BY ZAKIY - active";
}

string ClientDashModeAdvice()
{
   if(!ClientDashShowModeAdvice)
      return "MODE: hidden";

   string rec = G_NIM_RECOMMENDATION;

   if(rec == "" || rec == "NIM REC: waiting")
      rec = "NIM REC: BALANCED";

   return rec + " | Active " + ModeToString(G_ACTIVE_MODE);
}

void UpdateClientDashboardPolish(const string source)
{
   G_CDP_READY = false;
   G_CDP_CLIENT_VIEW = true;

   if(!UseClientDashboardPolish)
   {
      G_CDP_STATUS = "CDP: OFF";
      G_CDP_BADGE = "SIRUS v31.6";
      G_CDP_HEALTH_LINE = "HEALTH: dashboard polish disabled";
      G_CDP_RISK_BANNER = "RISK: hidden";
      G_CDP_MODE_ADVICE = "MODE: hidden";
      G_CDP_CONTACT_LINE = "CONTACT: hidden";
      G_CDP_DETAIL = "CDP DETAIL: disabled";
      G_CDP_READY = true;
      return;
   }

   string view = ClientDashMode();

   G_CDP_CLIENT_VIEW = (view != "INTERNAL");

   if(ClientDashShowReleaseBadge)
      G_CDP_BADGE = ClientDashReleaseBadge();
   else
      G_CDP_BADGE = "SIRUS v31.6";

   if(ClientDashShowRiskBanner)
      G_CDP_RISK_BANNER = ClientDashRiskBanner();
   else
      G_CDP_RISK_BANNER = "RISK: hidden";

   if(ClientDashShowHealthLine)
   {
      G_CDP_HEALTH_LINE = StringFormat("HEALTH: NIM=%d FSA=%d RLS=%s FPR=%s SGV=%s",
                                       G_NIM_SCORE,
                                       G_FSA_SCORE,
                                       BoolText(G_RLS_READY),
                                       BoolText(G_FPR_READY),
                                       BoolText(G_SGV_READY));
   }
   else
   {
      G_CDP_HEALTH_LINE = "HEALTH: hidden";
   }

   G_CDP_MODE_ADVICE = ClientDashModeAdvice();

   if(ClientDashShowContactLine)
      G_CDP_CONTACT_LINE = "CONTACT: CEO Farruh Zakiy | Telegram " + TelegramContact;
   else
      G_CDP_CONTACT_LINE = "CONTACT: hidden";

   if(G_NIM_ENTRY_BLOCK || G_FPR_ENTRY_BLOCK || G_SGV_ENTRY_BLOCK)
      G_CDP_STATUS = "CDP: BLOCK VIEW";
   else if(NIMScoreForDash() < ClientDashDefenseScore)
      G_CDP_STATUS = "CDP: DEFENSE VIEW";
   else if(NIMScoreForDash() < ClientDashWarnScore || G_FPR_WARNINGS > 0 || G_SGV_WARNINGS > 0)
      G_CDP_STATUS = "CDP: WARNING VIEW";
   else if(G_NIM_PRO_READY && G_FPR_PRO_READY)
      G_CDP_STATUS = "CDP: PRO VIEW";
   else
      G_CDP_STATUS = "CDP: READY VIEW";

   G_CDP_DETAIL = StringFormat("CDP DETAIL: view=%s clientView=%s compactDeep=%s reasonMax=%d badge=%s",
                               view,
                               BoolText(G_CDP_CLIENT_VIEW),
                               BoolText(ClientDashCompactDeepReasons),
                               MathMax(20, ClientDashReasonMaxChars),
                               G_CDP_BADGE);

   G_CDP_READY = true;

   string signature = G_CDP_STATUS + "|" + G_CDP_BADGE + "|" + G_CDP_RISK_BANNER + "|" + G_CDP_HEALTH_LINE + "|" + SafeIntText(G_BARS_SEEN);

   if(PrintClientDashboardPolishEvents && signature != G_CDP_LAST_SIGNATURE)
   {
      if(G_CDP_LAST_SIGNATURE == "" || NIMScoreForDash() < ClientDashWarnScore || G_FPR_WARNINGS > 0 || G_SGV_WARNINGS > 0 || G_NIM_PRO_READY)
      {
         G_CDP_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 24.3 CDP] %s | %s | %s | %s | source=%s",
                     G_CDP_STATUS,
                     G_CDP_BADGE,
                     G_CDP_RISK_BANNER,
                     G_CDP_HEALTH_LINE,
                     source);
      }

      G_CDP_LAST_SIGNATURE = signature;
   }
}


//==================================================================//
//  PHASE 24.6 LIVE VALIDATION PROBE / NO-TRADE DOCTOR
//==================================================================//
bool LiveProbeIsNewSignalBar()
{
   static datetime last_seen_bar = 0;
   datetime bar_time = iTime(_Symbol, SignalTF, 0);

   if(bar_time <= 0)
      return false;

   if(last_seen_bar == 0)
   {
      last_seen_bar = bar_time;
      return false;
   }

   if(bar_time != last_seen_bar)
   {
      last_seen_bar = bar_time;
      return true;
   }

   return false;
}


string LiveProbeScoreDecisionText()
{
   if(G_SCORE_DECISION == SCORE_DECISION_PASS)
      return "PASS";

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS)
      return "MICRO_PASS";

   if(G_SCORE_DECISION == SCORE_DECISION_WAIT)
      return "WAIT";

   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
      return "HARD_BLOCK";

   return "NONE";
}

void LiveProbeAddBlocker(const bool condition,
                         const string text,
                         int &blockers,
                         string &reason)
{
   if(!condition)
      return;

   blockers++;

   if(StringLen(reason) < 900)
      reason = reason + text + "; ";
}

string LiveProbeShort(const string text)
{
   return ShortText(text, MathMax(30, LiveProbeMaxReasonChars));
}

void UpdateLiveValidationProbe(const string source)
{
   G_LVP_READY = false;
   G_LVP_ENTRY_READY = false;
   G_LVP_GRID_READY = false;
   G_LVP_NO_TRADE = false;
   G_LVP_READY_SCORE = 0;
   G_LVP_BLOCKERS = 0;

   if(!UseLiveValidationProbe)
   {
      G_LVP_STATUS = "LVP: OFF";
      G_LVP_REASON = "live validation probe disabled";
      G_LVP_ENTRY_DOCTOR = "ENTRY DOCTOR: disabled";
      G_LVP_GRID_DOCTOR = "GRID DOCTOR: disabled";
      G_LVP_GATE_STACK = "GATE STACK: disabled";
      G_LVP_DETAIL = "LVP DETAIL: disabled";
      return;
   }

   RefreshGridDashboardStats();

   string reason = "";
   int blockers = 0;
   int score = 100;

   LiveProbeAddBlocker(!G_ENV_READY, "ENV not ready: " + G_ENV_BLOCK_REASON, blockers, reason);
   LiveProbeAddBlocker((TickAgeSeconds() > MaxTickAgeSeconds), "tick stale", blockers, reason);
   LiveProbeAddBlocker((G_BARS_SEEN < LiveProbeMinBarsForReady), StringFormat("warmup bars %d/%d", G_BARS_SEEN, LiveProbeMinBarsForReady), blockers, reason);
   LiveProbeAddBlocker(G_RISK_HARD_BLOCK, "risk hard block", blockers, reason);
   LiveProbeAddBlocker(G_PACK3_HARD_BLOCK, "news/broker hard block", blockers, reason);
   LiveProbeAddBlocker(G_NIM_ENTRY_BLOCK, "NIM entry block", blockers, reason);
   LiveProbeAddBlocker(G_FPR_ENTRY_BLOCK, "FPR entry block", blockers, reason);
   LiveProbeAddBlocker(G_SGV_ENTRY_BLOCK, "SGV entry block", blockers, reason);
   LiveProbeAddBlocker(G_DPH_ENTRY_BLOCK, "DPH entry block", blockers, reason);
   LiveProbeAddBlocker(G_FBL_ENTRY_BLOCK, "FBL entry block", blockers, reason);

   bool score_ok = (G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS);
   LiveProbeAddBlocker(!score_ok, "score not pass: " + LiveProbeScoreDecisionText(), blockers, reason);
   LiveProbeAddBlocker((G_OPP_DIR == OPP_DIR_NONE), "no opportunity direction", blockers, reason);

   if(blockers > 0)
      score -= blockers * 8;

   if(G_NIM_SCORE < 72)
      score -= 10;

   if(G_FSA_SCORE < 85)
      score -= 8;

   if(G_LAST_SPREAD_POINTS > ClientSafetySpreadLimit())
      score -= 5;

   if(score < 0)
      score = 0;

   if(score > 100)
      score = 100;

   G_LVP_READY_SCORE = score;
   G_LVP_BLOCKERS = blockers;
   G_LVP_ENTRY_READY = (blockers == 0 && score_ok);
   G_LVP_GRID_READY = (G_BASKET_ORDERS > 0 && !G_RISK_HARD_BLOCK && !G_NIM_GRID_BLOCK && !G_FPR_GRID_BLOCK && !G_SGV_GRID_BLOCK && !G_DPH_GRID_BLOCK && !G_FBL_GRID_BLOCK);
   G_LVP_READY = (G_LVP_ENTRY_READY || G_LVP_GRID_READY);
   G_LVP_NO_TRADE = (!G_LVP_ENTRY_READY && G_BASKET_ORDERS <= 0);

   if(reason == "")
      reason = "all live gates are clean";

   G_LVP_REASON = reason;

   G_LVP_ENTRY_DOCTOR = StringFormat("ENTRY DOCTOR: ready=%s blockers=%d score=%d scoreDecision=%s opp=%s mode=%s spread=%d bars=%d | %s",
                                     BoolText(G_LVP_ENTRY_READY),
                                     G_LVP_BLOCKERS,
                                     G_LVP_READY_SCORE,
                                     LiveProbeScoreDecisionText(),
                                     OpportunityDirToString(G_OPP_DIR),
                                     ModeToString(G_ACTIVE_MODE),
                                     G_LAST_SPREAD_POINTS,
                                     G_BARS_SEEN,
                                     LiveProbeShort(G_LVP_REASON));

   G_LVP_GRID_DOCTOR = StringFormat("GRID DOCTOR: ready=%s basketOrders=%d basketPts=%.0f DD=%.2f DRI=%s DPH=%s FBL=%s",
                                    BoolText(G_LVP_GRID_READY),
                                    G_BASKET_ORDERS,
                                    G_BASKET_POINTS,
                                    G_BASKET_DD_PERCENT,
                                    G_DRI_STATUS,
                                    G_DPH_STATUS,
                                    G_FBL_STATUS);

   G_LVP_GATE_STACK = StringFormat("GATE STACK: ENV=%s RISK=%s NIM=%s FPR=%s SGV=%s DPH=%s FBL=%s FSA=%d RLS=%s",
                                   BoolText(G_ENV_READY),
                                   BoolText(!G_RISK_HARD_BLOCK),
                                   G_NIM_STATUS,
                                   G_FPR_STATUS,
                                   G_SGV_STATUS,
                                   G_DPH_STATUS,
                                   G_FBL_STATUS,
                                   G_FSA_SCORE,
                                   BoolText(G_RLS_READY));

   G_LVP_DETAIL = StringFormat("LVP DETAIL: noTrade=%s ready=%s entryReady=%s gridReady=%s blockers=%d readyScore=%d doctorOnly=%s source=%s",
                               BoolText(G_LVP_NO_TRADE),
                               BoolText(G_LVP_READY),
                               BoolText(G_LVP_ENTRY_READY),
                               BoolText(G_LVP_GRID_READY),
                               G_LVP_BLOCKERS,
                               G_LVP_READY_SCORE,
                               BoolText(LiveProbeNoTradeDoctorOnly),
                               source);

   if(G_LVP_ENTRY_READY)
      G_LVP_STATUS = "LVP: ENTRY READY";
   else if(G_LVP_GRID_READY)
      G_LVP_STATUS = "LVP: GRID READY";
   else if(G_LVP_NO_TRADE)
      G_LVP_STATUS = "LVP: NO-TRADE DOCTOR";
   else if(G_LVP_BLOCKERS > 0)
      G_LVP_STATUS = "LVP: WAIT";
   else
      G_LVP_STATUS = "LVP: MONITOR";

   string signature = G_LVP_STATUS + "|" + G_LVP_ENTRY_DOCTOR + "|" + G_LVP_GRID_DOCTOR + "|" + SafeIntText(G_BARS_SEEN);

   bool should_print = false;

   if(PrintLiveProbeEvents)
   {
      if(LiveProbePrintOnChange && signature != G_LVP_LAST_SIGNATURE)
         should_print = true;

      if(LiveProbePrintEveryNewBar && LiveProbeIsNewSignalBar())
         should_print = true;
   }

   if(should_print)
   {
      G_LVP_EVENT_COUNT++;
      PrintFormat("[SIRUS v31.6 PHASE 24.6 LVP] %s | %s | %s",
                  G_LVP_STATUS,
                  G_LVP_ENTRY_DOCTOR,
                  G_LVP_GRID_DOCTOR);

      G_LVP_LAST_SIGNATURE = signature;
   }
}

//==================================================================//
//  PHASE 21.3 PREMIUM DASHBOARD / LOG ENGINE
//==================================================================//
string ShortText(const string text, const int max_len)
{
   if(max_len <= 0)
      return text;

   if(StringLen(text) <= max_len)
      return text;

   return StringSubstr(text, 0, max_len - 3) + "...";
}

string RiskStateShort()
{
   if(G_RISK_HARD_BLOCK)
      return "RISK BLOCK";

   if(G_RISK_READY)
      return "RISK OK";

   return "RISK WAIT";
}

string BasketDirectionShort()
{
   if(G_BASKET_DIRECTION == POSITION_TYPE_BUY)
      return "BUY";
   if(G_BASKET_DIRECTION == POSITION_TYPE_SELL)
      return "SELL";
   if(G_BASKET_DIRECTION == -2)
      return "MIXED";
   return "NONE";
}

string BuildNextAction()
{
   if(!G_ENV_READY)
      return "Fix environment: " + ShortText(G_ENV_BLOCK_REASON, 80);

   if(UseVPSLiveValidation && !G_VPS_OK)
      return "Check VPS/broker: " + ShortText(G_VPS_REASON, 90);

   if(G_LEGACY_HARD_BLOCK)
      return "Legacy module hard block: " + ShortText(G_LEGACY_REASON, 80);

   if(G_LEGACY_APPLIED)
      return "Legacy upgrade adjusted score: " + ShortText(G_LEGACY_REASON, 80);

   if(G_DLP_ENTRY_BLOCK || G_DLP_GRID_BLOCK)
      return "Deep parity strict block: " + ShortText(G_DLP_REASON, 90);

   if(G_DLP_APPLIED)
      return "Deep parity adjusted score: " + ShortText(G_DLP_DETAIL, 90);

   if(G_DBOS_ENTRY_BLOCK || G_DBOS_GRID_BLOCK)
      return "Deep BOS strict block: " + ShortText(G_DBOS_REASON, 90);

   if(G_DBOS_RETEST_READY)
      return "Deep BOS retest ready: " + ShortText(G_DBOS_DETAIL, 90);

   if(G_DBOS_APPLIED)
      return "Deep BOS adjusted score: " + ShortText(G_DBOS_DETAIL, 90);

   if(G_DTZ_ENTRY_BLOCK || G_DTZ_GRID_BLOCK)
      return "Deep top zone strict block: " + ShortText(G_DTZ_REASON, 90);

   if(G_DTZ_BREAKOUT_OK)
      return "Deep top zone breakout OK: " + ShortText(G_DTZ_DETAIL, 90);

   if(G_DTZ_APPLIED)
      return "Deep top zone adjusted score: " + ShortText(G_DTZ_DETAIL, 90);

   if(G_DNV_ENTRY_BLOCK || G_DNV_GRID_BLOCK)
      return "Deep news/vol strict block: " + ShortText(G_DNV_REASON, 90);

   if(G_DNV_NEWS_ACTIVE || G_DNV_SHOCK_ACTIVE || G_DNV_SPREAD_SHOCK)
      return "Deep news/volatility active: " + ShortText(G_DNV_DETAIL, 90);

   if(G_DNV_APPLIED)
      return "Deep news/vol adjusted score: " + ShortText(G_DNV_DETAIL, 90);

   if(G_DET_ENTRY_BLOCK || G_DET_GRID_BLOCK)
      return "Adaptive timing strict block: " + ShortText(G_DET_REASON, 90);

   if(G_DET_EARLY_BAR || G_DET_POST_SHOCK)
      return "Adaptive timing wait/caution: " + ShortText(G_DET_DETAIL, 90);

   if(G_DET_APPLIED)
      return "Adaptive timing adjusted score: " + ShortText(G_DET_DETAIL, 90);

   if(G_DRT_ENTRY_BLOCK || G_DRT_GRID_BLOCK)
      return "Regime auto-tune strict block: " + ShortText(G_DRT_REASON, 90);

   if(G_DRT_APPLIED || G_DRT_SHOCK_MODE || G_DRT_CHAOS_MODE)
      return "Regime auto-tune active: " + ShortText(G_DRT_DETAIL, 90);

   if(G_DRI_GRID_BLOCK)
      return "Adaptive recovery grid block: " + ShortText(G_DRI_REASON, 90);

   if(G_DRI_APPLIED)
      return "Adaptive recovery active: " + ShortText(G_DRI_DETAIL, 90);

   if(G_DXB_CLOSE_SENT)
      return "Smart exit executed: " + ShortText(G_DXB_REASON, 90);

   if(G_DXB_QUICK_PROFIT || G_DXB_PEAK_GIVEBACK || G_DXB_OPPOSITE_RISK || G_DXB_SHOCK_RISK)
      return "Smart exit protection: " + ShortText(G_DXB_DETAIL, 90);

   if(G_RC_CRITICAL_BLOCK)
      return "Stable RC block: " + ShortText(G_RC_REASON, 90);

   if(G_P4M_HARD_BLOCK)
      return "Pack4 Mini hard block: " + ShortText(G_P4M_REASON, 90);

   if(G_P4M_ENTRY_BLOCK || G_P4M_GRID_BLOCK)
      return "Pack4 Mini guard: " + ShortText(G_P4M_REASON, 90);

   if(G_P4L_ENTRY_BLOCK || G_P4L_GRID_BLOCK)
      return "Pack4 Lot guard: " + ShortText(G_P4L_REASON, 90);

   if(G_RCB_ENTRY_BLOCK || G_RCB_GRID_BLOCK)
      return "RC Settings strict block: " + ShortText(G_RCB_REASON, 90);

   if(G_RCB_WARNINGS > 0)
      return "RC Settings warning: " + ShortText(G_RCB_REASON, 90);

   if(G_FSA_ENTRY_BLOCK || G_FSA_GRID_BLOCK)
      return "Final audit strict block: " + ShortText(G_FSA_REASON, 90);

   if(!G_FSA_READY || G_FSA_WARNINGS > 0)
      return "Final audit warning: " + ShortText(G_FSA_DETAIL + " | " + G_FSA_REASON, 90);

   if(G_RLS_ENTRY_BLOCK || G_RLS_GRID_BLOCK)
      return "Release strict block: " + ShortText(G_RLS_REASON, 90);

   if(!G_RLS_READY)
      return "Release warning: " + ShortText(G_RLS_DETAIL + " | " + G_RLS_REASON, 90);

   if(G_DCS_ENTRY_BLOCK || G_DCS_GRID_BLOCK)
      return "Client safety strict block: " + ShortText(G_DCS_REASON, 90);

   if(G_DCS_APPLIED)
      return "Client safety active: " + ShortText(G_DCS_DETAIL, 90);

   if(G_NIM_ENTRY_BLOCK || G_NIM_GRID_BLOCK)
      return "Final intelligence block: " + ShortText(G_NIM_DETAIL + " | " + G_NIM_REASON, 90);

   if(G_NIM_SCORE < FinalMergeWarnScore || G_NIM_PRO_READY)
      return "Final intelligence: " + ShortText(G_NIM_STATUS + " | " + G_NIM_DETAIL + " | " + G_NIM_RECOMMENDATION, 90);

   if(G_FPR_ENTRY_BLOCK || G_FPR_GRID_BLOCK)
      return "PRO final release block: " + ShortText(G_FPR_DETAIL + " | " + G_FPR_REASON, 90);

   if(G_FPR_PRO_READY || G_FPR_WARNINGS > 0)
      return "PRO final release: " + ShortText(G_FPR_STATUS + " | " + G_FPR_DETAIL, 90);

   if(G_SGV_ENTRY_BLOCK || G_SGV_GRID_BLOCK)
      return "Settings governance block: " + ShortText(G_SGV_REASON, 90);

   if(G_SGV_WARNINGS > 0)
      return "Settings governance warning: " + ShortText(G_SGV_DETAIL + " | " + G_SGV_REASON, 90);

   if(UseClientDashboardPolish && G_CDP_STATUS != "")
      return ClientDashSafeReason(G_CDP_BADGE + " | " + G_CDP_RISK_BANNER + " | " + G_CDP_MODE_ADVICE);

   if(G_DPH_ENTRY_BLOCK || G_DPH_GRID_BLOCK)
      return "Preset hardening block: " + ShortText(G_DPH_REASON, 90);

   if(G_DPH_WARNINGS > 0 || G_DPH_CRITICAL_WARNINGS > 0)
      return "Preset hardening warning: " + ShortText(G_DPH_DETAIL, 90);

   if(G_FBL_ENTRY_BLOCK || G_FBL_GRID_BLOCK)
      return "Final build audit block: " + ShortText(G_FBL_REASON, 90);

   if(G_FBL_LOCKED || G_FBL_WARNINGS > 0)
      return "Final build audit: " + ShortText(G_FBL_STATUS + " | " + G_FBL_DETAIL, 90);

   if(G_PACK3_HARD_BLOCK)
      return "Pack3 hard block: " + ShortText(G_PACK3_REASON, 80);

   if(G_PACK3_NEWS_ACTIVE)
      return "News guard active: " + ShortText(G_PACK3_NEWS_STATUS, 90);

   if(G_PACK3_ENTRY_BLOCK || G_PACK3_GRID_BLOCK)
      return "Pack3 guard active: " + ShortText(G_PACK3_STATUS, 90);

   if(G_BASKET_TRAIL_ACTIVE)
      return "Basket trailing active: peak " + DoubleToString(G_BASKET_TRAIL_PEAK, 0) + " lock " + DoubleToString(G_BASKET_TRAIL_LOCK, 0);

   if(Pack2IsAftershockActive())
      return "Aftershock guard active until " + SafeTime(G_AFTERSHOCK_UNTIL);

   if(G_RISK_HARD_BLOCK)
      return "Risk lock active: " + ShortText(G_RISK_REASON, 80);

   if(G_BASKET_ORDERS > 0)
   {
      if(StringFind(G_GRID_STATUS, "SENT") >= 0)
         return "Grid order sent, monitoring basket TP/SL";

      if(StringFind(G_GRID_STATUS, "WAIT") >= 0)
         return "Basket active: " + ShortText(G_GRID_REASON, 90);

      return "Basket active: monitor recovery and basket exit";
   }

   if(G_SCORE_DECISION == SCORE_DECISION_HARD_BLOCK)
      return "Signal hard blocked: " + ShortText(G_SCORE_HARD_BLOCK, 80);

   if(G_SCORE_DECISION == SCORE_DECISION_PASS)
      return "Main entry signal passed, waiting entry execution";

   if(G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS)
   {
      if(G_MICRO_READY)
         return "Micro signal ready, waiting entry execution";
      return "Micro signal passed but guard waits: " + ShortText(G_MICRO_REASON, 80);
   }

   if(G_MEMORY_APPLIED)
      return "Missed trade memory boost applied: " + ShortText(G_MEMORY_SETUP_SIGNATURE, 70);

   if(G_QUEUE_ACTIVE)
      return "Signal queue holding: " + ShortText(G_QUEUE_REASON, 80);

   if(G_BLOCK_ACTIVE)
      return "Temporary block: " + TempBlockToString(G_BLOCK_TYPE) + " | " + ShortText(G_BLOCK_REASON, 70);

   if(G_OPP_GRADE != OPP_GRADE_NONE)
      return "Opportunity found but score waits: final " + IntegerToString(G_SCORE_FINAL) + "/" + IntegerToString(G_SCORE_MIN_REQUIRED);

   if(G_MARKET_STATE == MARKET_CHAOS)
      return "Wait: market chaos";

   if(G_MARKET_STATE == MARKET_DEAD)
      return "Wait: dead market / low movement";

   if(G_MARKET_STATE == MARKET_IMPULSE)
      return "Wait for pullback after impulse";

   return "Scanning for A+ / B / C Micro setup";
}

string BuildPremiumSummary()
{
   return StringFormat("%s | %s | %s | %s | Basket %d %s P/L %.2f | Score %s %d/%d",
                       RiskStateShort(),
                       ModeToString(G_ACTIVE_MODE),
                       MarketStateToString(G_MARKET_STATE),
                       OpportunityDirToString(G_OPP_DIR),
                       G_BASKET_ORDERS,
                       BasketDirectionShort(),
                       G_BASKET_PROFIT,
                       ScoreDecisionToString(G_SCORE_DECISION),
                       G_SCORE_FINAL,
                       G_SCORE_MIN_REQUIRED);
}

void UpdatePremiumLogEngine(const string source)
{
   G_NEXT_ACTION = BuildNextAction();
   G_PREMIUM_SUMMARY = BuildPremiumSummary();
   G_PREMIUM_STATUS = "PREMIUM: " + G_NEXT_ACTION;

   if(!UsePremiumLogEngine)
      return;

   datetime now = TimeLocal();

   string event_signature = G_RISK_STATUS + "|" + G_GRID_STATUS + "|" + G_ENTRY_STATUS + "|" + G_NEXT_ACTION;

   if(PrintPremiumNextAction && event_signature != G_LOG_LAST_SIGNATURE)
   {
      bool important = false;

      if(G_RISK_HARD_BLOCK)
         important = true;
      if(StringFind(G_ENTRY_STATUS, "SENT") >= 0 || StringFind(G_ENTRY_STATUS, "FAILED") >= 0)
         important = true;
      if(StringFind(G_GRID_STATUS, "SENT") >= 0 || StringFind(G_GRID_STATUS, "FAILED") >= 0 || StringFind(G_GRID_STATUS, "EXIT") >= 0)
         important = true;
      if(G_BLOCK_JUST_EXPIRED)
         important = true;
      if(G_REDIRECT_APPLIED || G_QUEUE_REPLAYED || G_MEMORY_APPLIED || G_LEGACY_APPLIED || G_PACK3_ENTRY_BLOCK || G_PACK3_GRID_BLOCK || G_PACK3_HARD_BLOCK || G_RC_CRITICAL_BLOCK)
         important = true;

      if(important)
      {
         G_LOG_EVENT_COUNT++;
         G_LAST_MAJOR_EVENT = G_NEXT_ACTION;

         PrintFormat("[SIRUS v31.6 PHASE 21.3 EVENT] %s | summary=%s | source=%s",
                     G_NEXT_ACTION,
                     G_PREMIUM_SUMMARY,
                     source);
      }

      G_LOG_LAST_SIGNATURE = event_signature;
   }

   if(PremiumLogSnapshotSeconds > 0 && (G_LOG_LAST_SNAPSHOT <= 0 || (now - G_LOG_LAST_SNAPSHOT) >= PremiumLogSnapshotSeconds))
   {
      G_LOG_LAST_SNAPSHOT = now;
      G_LOG_SNAPSHOT_COUNT++;

      PrintFormat("[SIRUS v31.6 PHASE 21.3 SNAPSHOT] %s | next=%s | env=%s | risk=%s | basketOrders=%d profit=%.2f points=%.0f | entries=%d/%d grid=%d/%d",
                  G_PREMIUM_SUMMARY,
                  G_NEXT_ACTION,
                  G_ENV_STATUS,
                  G_RISK_STATUS,
                  G_BASKET_ORDERS,
                  G_BASKET_PROFIT,
                  G_BASKET_POINTS,
                  G_ENTRY_SUCCESSES,
                  G_ENTRY_ATTEMPTS,
                  G_GRID_SUCCESSES,
                  G_GRID_ATTEMPTS);
   }
}

// ============================================================================
// V31.6z DEPENDENCY MAP - added during the "untangling" audit (professional review
// session). CoreUpdate is a SEQUENCE of ~54 calls; several bugs found this session
// (Brain Penalty Cap positioned before its own inputs, mode-freeze comment mismatch)
// were pure ORDERING bugs - each individual function was correct in isolation, the
// mistake was only visible by tracing the whole sequence. This map exists so the next
// person (including a future me) adding logic here checks the right layer, not just
// "does this line compile".
//
// LAYER 1 - FOUNDATION (must run first; everything else reads this state):
//   UpdateClockState, UpdateTickState, UpdateBarTracker, UpdateEconomicCalendarGuard,
//   UpdateKalmanTrendFilter, CheckNewsAutoFlat, UpdateEnvironmentEngine
//
// LAYER 2 - MODE / MARKET CLASSIFICATION (needs Layer 1; Layer 3+ needs this):
//   UpdateModeManager (Balanced/Hunter), UpdateMarketStateRouter (trend/range/impulse/
//   exhaustion/chaos) - G_ACTIVE_MODE and G_MARKET_STATE set here. NOTE: an OPEN
//   basket should read G_BASKET_FROZEN_MODE, not G_ACTIVE_MODE directly, for anything
//   that affects an in-progress basket (grid distance/lot) - see AutoGridHunterMode().
//
// LAYER 3 - OPPORTUNITY + SCORE (the entry decision core):
//   UpdateOpportunityScanner sets G_OPP_DIR/TYPE/SCORE first.
//   UpdateSignalScoreEngine computes G_SCORE_FINAL from it - MUST run after the scanner.
//   *** Inside UpdateSignalScoreEngine: the Brain Penalty Cap MUST be the LAST thing
//   before G_SCORE_FINAL is computed - it has to see every penalty source's total, or
//   it silently protects nothing (this exact bug shipped once already). ***
//   UpdateDirectionRedirectEngine may flip G_OPP_DIR - if it does (G_REDIRECT_APPLIED),
//   the score engine re-runs for the new direction (see the immediately following if-block).
//
// LAYER 4 - RISK GATES (must run before Grid/Entry actually place anything):
//   UpdateRiskEngine sets G_RISK_HARD_BLOCK and the daily/equity/emergency stop flags
//   that GridCanOpen and FirstEntryCanRun both check.
//
// LAYER 5 - EXECUTION (reads Layers 2-4; this is where orders actually get sent):
//   UpdateGridRecoveryEngine runs BEFORE UpdateFirstEntryEngine on purpose - if grid
//   already acted on an existing basket this tick, first-entry's OneBasketAtATime check
//   (further down that path) correctly still sees the basket as open either way, but
//   grid gets first opportunity to manage an existing position before a fresh entry is
//   even considered.
//
// LAYER 6 - POST-TRADE BOOKKEEPING / DIAGNOSTICS (order doesn't matter much here):
//   Dashboard, logging, license/rental checks, and diagnostic-only probes.
// ============================================================================
void CoreUpdate(const string source)
{
   G_UPDATE_COUNT++;

   // V31.6z23 NEW: runs FIRST, before anything else - a pure, independent safety net with
   // zero dependency on any other part of the bot's state (only reads live positions and
   // account balance directly). This is deliberately the very first thing checked every tick.
   EmergencyBasketForceCloseCheck();

   // FIX(timer-trades): OnTimer fires every CoreTimerSeconds (1s) whether or not a quote arrived, and it
   // used to run this whole pipeline - first entries and grid additions included - on the last known
   // price, a second time per second on top of the ticks. On a quiet or closed market that meant decisions
   // on a stale quote; in the Strategy Tester it doubled the work; and a new bar could be "consumed" by the
   // timer pass, so OnTick's per-bar work saw G_IS_NEW_BAR=false. The timer now does only what is driven by
   // the CLOCK rather than by price: the emergency net above, the clock/tick-age readout, the news calendar
   // window and the pre-news auto-flat. Everything that reads price runs on real ticks.
   if(source == "TIMER")
   {
      UpdateClockState();
      UpdateTickState();
      UpdateEconomicCalendarGuard();
      CheckNewsAutoFlat();
      return;
   }

   UpdateClockState();
   UpdateTickState();
   UpdateBarTracker(source);
   // Market Brain facts (engine plan, phases 1 / 1b). They only describe the market for now; each
   // timeframe is read once per new bar, the forming M1 candle on every tick.
   MBCandleEngineUpdate();
   MBEventEngineUpdate();
   MBBrainUpdate();
   MBPositionBrainUpdate();
   UpdateEconomicCalendarGuard();
   UpdateKalmanTrendFilter();
   UpdateDailyBias();   // FEATURE(daily-bias): compute PDH/PDL + prior-day bias before zones/scanner use them
   CheckNewsAutoFlat();
   UpdateEnvironmentEngine();
   UpdateModeManager(source);
   UpdateMarketStateRouter(source);
   // V142: append anything new to the event chain BEFORE the scanner and score engine run, so any
   // logic that reads the sequence sees this bar's events already in place.
   RegimeUpdate();      // V156: read the regime before anything that depends on its settings
   BlockAuditSettle();  // V157: judge any refused entries whose horizon has passed
   DailyStateUpdate();  // V169: roll the daily baseline over at the day boundary
   ExitQualitySettle(); // V169: judge where price went after the last basket closed
   ArmJudgeSettle();    // V197: judge what followed a confirmed wait
   CandleEventSettle(); // V209: grade the candles whose outcome is now known
   PatternJudgeSettle();// V211: grade the pattern whose horizon has passed
   CandleSourceSettle();// V216: grade each candle source by what followed its call

   // V217: write the records back periodically. Saving on every tick would be wasteful; saving
   // only on deinit loses everything if the terminal closes unexpectedly, which it does.
   {
      static int last_save_bar = -100000;
      if(last_save_bar > G_BARS_SEEN) last_save_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
      if((G_BARS_SEEN - last_save_bar) >= MathMax(10, CandleLearningSaveEveryBars))
      {
         CandleLearningSave();
         PatternRecordSave();
         FollowRecordSave();
         last_save_bar = G_BARS_SEEN;
      }
   }
   EventChainUpdate();
   UpdateOpportunityScanner(source);
   UpdateSignalScoreEngine(source);
   UpdateDirectionRedirectEngine(source);
   if(G_REDIRECT_APPLIED)
      UpdateSignalScoreEngine("REDIRECT_RESCORE");
   UpdateLegacyUpgradePack(source);
   UpdateLegacyDeepParityPack(source);
   UpdateDeepBOSChochRetest(source);
   UpdateDeepTopZoneTrapGuard(source);
   UpdateDeepNewsVolatilityBrain(source);
   UpdateAdaptiveEntryTimingBrain(source);
   UpdateMarketRegimeAutoTuningBrain(source);
   UpdateSignalQueueEngine(source);
   UpdateMissedTradeMemory(source);
   UpdateMicroScalpLayer(source);
   UpdateBlockExpiryEngine(source);
   if(G_BLOCK_JUST_EXPIRED && (G_SCORE_DECISION == SCORE_DECISION_PASS || G_SCORE_DECISION == SCORE_DECISION_MICRO_PASS))
      UpdateMicroScalpLayer("BLOCK_EXPIRY_RESCORE");
   UpdateRiskEngine(source);
   UpdateVPSLiveValidation(source);
   UpdateLegacyPack3(source);
   UpdatePack4MiniLicense(source);
   UpdatePack4MiniLotCaps(source);
   UpdateRCSettingsBalance(source);
   UpdateWarningCleanupPolish(source);
   UpdateSmartClientSafetyBrain(source);
   // UpdateClientDashboardPolish / UpdateLiveValidationProbe only build dashboard text (G_CDP_* / G_LVP_*,
   // read by nothing but DrawDashboard). They ran three times per tick; once, after the entry pass, is the
   // only result anyone ever saw.
   UpdateLegacyPack2(source);
   UpdateAdaptiveRecoveryIntelligence(source);
   UpdateProfitExtractionSmartExit(source);
   // FIX(init-bypasses-anti-churn): OnInit zeroes G_BARS_SEEN / G_TICK_COUNT / G_LAST_ENTRY_TIME and
   // sets G_LAST_ENTRY_BAR = -100000, then calls CoreUpdate("INIT"). Both anti-churn guards read as
   // "no recent entry" against that blank state - the cooldown test is skipped because
   // G_LAST_ENTRY_BAR fails its own `> -9999` sanity check, and seconds-since-entry evaluates to
   // 999999 - so a re-init seconds after a basket closed (any input change, recompile, or timeframe
   // switch) could re-enter immediately instead of serving MinSecondsBetweenEntries. The authors
   // already diagnosed and fixed exactly this for the per-scan reset path (see the note in
   // ResetOpportunity) and left the OnInit hole open. Nothing is lost by skipping one pass: the
   // engines run again on the very next tick, with real state.
   if(source != "INIT")
   {
      UpdateGridRecoveryEngine(source);
      UpdateLegacyPack2("POST_GRID");
      UpdateFirstEntryEngine(source);
   }
   UpdateLegacyPack3("POST_ENTRY");
   UpdatePack4MiniLicense("POST_ENTRY");
   UpdatePack4MiniLotCaps("POST_ENTRY");
   UpdateRCSettingsBalance("POST_ENTRY");
   UpdateWarningCleanupPolish("POST_ENTRY");
   UpdateSmartClientSafetyBrain("POST_ENTRY");
   UpdateClientDashboardPolish("POST_ENTRY");
   UpdateLiveValidationProbe("POST_ENTRY");
   UpdatePremiumVisualEngine(source);
   UpdatePremiumLogEngine(source);

   G_CORE_READY = (G_LAST_BAR_TIME > 0);
}

void PrintHeartbeat()
{
   if(!PrintExpertsHeartbeat)
      return;

   datetime now = TimeLocal();
   if(G_LAST_HEARTBEAT > 0 && (now - G_LAST_HEARTBEAT) < ExpertsHeartbeatSeconds)
      return;

   G_LAST_HEARTBEAT = now;

   PrintFormat("[SIRUS v31.6 PHASE 21.3 HEARTBEAT] summary=%s | next=%s | rc=%s | legacy=%s | pack2=%s | pack3=%s | vps=%s | noTrade=%s | memory=%s | status=%s | env=%s | risk=%s | grid=%s | entry=%s | symbol=%s | chartTF=%s | coreTF=%s | ticks=%I64u | timers=%I64u | bars_seen=%d | tick_age=%d | spread=%d",
               G_PREMIUM_SUMMARY,
               G_NEXT_ACTION,
               G_RC_STATUS,
               G_LEGACY_STATUS,
               G_PACK2_STATUS,
               G_PACK3_STATUS,
               G_VPS_STATUS,
               G_VPS_NO_TRADE_REASON,
               G_MEMORY_STATUS,
               G_LAST_STATUS,
               G_ENV_STATUS,
               G_RISK_STATUS,
               G_GRID_STATUS,
               G_ENTRY_STATUS,
               _Symbol,
               TFToString((ENUM_TIMEFRAMES)_Period),
               TFToString(CoreBarTF),
               G_TICK_COUNT,
               G_TIMER_COUNT,
               G_BARS_SEEN,
               TickAgeSeconds(),
               G_LAST_SPREAD_POINTS);
}

//==================================================================//
//  DASHBOARD
//==================================================================//
void DeleteDashboard()
{
   int max_rows = MathMax(40, DashboardMaxRows);
   for(int i=0; i<max_rows; i++)
   {
      string name = G_PREFIX + IntegerToString(i);
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }
}

// V29 (E-block): 3-tier severity color - green while safe, gold approaching the limit, red at/over it.
color DDSeverityColor(const double value, const double warn_threshold, const double danger_threshold)
{
   if(danger_threshold > 0.0 && value >= danger_threshold)
      return clrOrangeRed;
   if(warn_threshold > 0.0 && value >= warn_threshold)
      return clrGold;
   return clrLime;
}

void DrawDashLine(const int row, const string text, const color clr)
{
   string name = G_PREFIX + IntegerToString(row);

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DashboardY + row * (DashboardFontSize + DashboardLineSpacing));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, DashboardFontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DrawDashboard()
{
   if(!ShowDashboard)
   {
      DeleteDashboard();
      return;
   }

   datetime now = TimeLocal();
   if(G_LAST_DASHBOARD > 0 && (now - G_LAST_DASHBOARD) < DashboardRefreshSeconds)
      return;

   G_LAST_DASHBOARD = now;

   color env_color   = G_ENV_READY ? clrLime : clrOrangeRed;
   color risk_color  = G_RISK_HARD_BLOCK ? clrOrangeRed : clrLime;
   color score_color = (G_SCORE_DECISION==SCORE_DECISION_PASS || G_SCORE_DECISION==SCORE_DECISION_MICRO_PASS ? clrLime : (G_SCORE_DECISION==SCORE_DECISION_HARD_BLOCK ? clrOrangeRed : clrSilver));
   color entry_color = (StringFind(G_ENTRY_STATUS, "SENT")>=0 ? clrLime : (StringFind(G_ENTRY_STATUS, "FAILED")>=0 || StringFind(G_ENTRY_STATUS, "BLOCK")>=0 ? clrOrangeRed : clrSilver));
   color grid_color  = (StringFind(G_GRID_STATUS, "SENT")>=0 || StringFind(G_GRID_STATUS, "EXIT")>=0 ? clrLime : (StringFind(G_GRID_STATUS, "FAILED")>=0 ? clrOrangeRed : clrSilver));

   int row = 0;

   double dash_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dash_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dash_free    = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double dash_daily_profit = 0.0;
   if(G_RISK_DAY_START_EQUITY > 0.0)
      dash_daily_profit = dash_equity - G_RISK_DAY_START_EQUITY;

   // V29 (E-block): ACCOUNT / TODAY / RISK block - fixed-width labels so the "|" separators
   // line up across all three rows (font is Consolas, monospace, so padding renders exact).
   string dash_account_line = StringFormat("%-8s| Bal:%10.2f  Eq:%10.2f  Free:%10.2f",
                                           "ACCOUNT", dash_balance, dash_equity, dash_free);

   string dash_target_text = "off";
   if(EnableDailyProfitGovernor && DailyProfitTargetPercent > 0.0)
   {
      double today_pct = (G_RISK_DAY_START_EQUITY > 0.0) ? (dash_daily_profit / G_RISK_DAY_START_EQUITY * 100.0) : 0.0;
      dash_target_text = StringFormat("%.1f/%.1f%%", today_pct, DailyProfitTargetPercent);
   }
   string dash_today_line = StringFormat("%-8s| P/L:%+10.2f  DD:%6.2f%%  Target:%s",
                                         "TODAY", dash_daily_profit, G_RISK_DAILY_LOSS_PCT, dash_target_text);
   color dash_today_color = (dash_daily_profit < 0.0) ?
                            DDSeverityColor(G_RISK_DAILY_LOSS_PCT, DailyLossPercent * 0.6, DailyLossPercent) :
                            clrLime;

   string dash_risk_line = StringFormat("%-8s| Now:%6.2f%%  Worst:%6.2f%%  Basket:%6.2f%%",
                                        "RISK", G_RISK_EQUITY_DD_PCT, G_ALL_TIME_MAX_DD_PCT, G_BASKET_DD_PERCENT);
   color dash_risk_color = DDSeverityColor(G_RISK_EQUITY_DD_PCT, EmergencyDDPercent * 0.6, EmergencyDDPercent);

   if(UsePremiumDashboard)
   {
      DrawDashLine(row++, "SIRUS BY ZAKIY", clrDeepSkyBlue);
      // V261: both clocks, because the operator reads one and the EA works in the other.
      if(ShowBothTimesOnDash)
         DrawDashLine(row++, TimeBothZones(), clrSilver);
      DrawDashLine(row++, "WHY: " + ShortText(G_NEXT_ACTION, 110), (G_RISK_HARD_BLOCK ? clrOrangeRed : clrLime));
      DrawDashLine(row++, "SUMMARY: " + ShortText(G_PREMIUM_SUMMARY, 120), clrWhite);
      DrawDashLine(row++, dash_account_line, clrAqua);
      DrawDashLine(row++, dash_today_line, dash_today_color);
      DrawDashLine(row++, dash_risk_line, dash_risk_color);
      DrawDashLine(row++, "AUTO GRID: " + AutoGridProfileText() +
                         " | base=" + DoubleToString(AutoGridBaseDistance(), 0) +
                         " min=" + DoubleToString(AutoGridMinDistance(), 0) +
                         " max=" + DoubleToString(AutoGridMaxDistance(), 0) +
                         " DDtrig=" + DoubleToString(AutoGridRecoveryStartDD(), 1) + "%", clrGold);
      DrawDashLine(row++, "------------------------------------------------------------", clrSilver);

      DrawDashLine(row++, "MODE: " + ModeToString(NaviusMode) + " -> " + ModeToString(G_ACTIVE_MODE) + " | Reason: " + ShortText(G_MODE_REASON, 80), clrDeepSkyBlue);
      if(UseClientDashboardPolish && ClientDashShowReleaseBadge)
         DrawDashLine(row++, ShortText(G_CDP_BADGE, 130), (G_NIM_PRO_READY && G_FPR_PRO_READY ? clrLime : clrGold));
      if(UseClientDashboardPolish && ClientDashShowRiskBanner)
         DrawDashLine(row++, ShortText(G_CDP_RISK_BANNER, 130), (G_NIM_ENTRY_BLOCK || G_FPR_ENTRY_BLOCK || G_SGV_ENTRY_BLOCK ? clrOrangeRed : (NIMScoreForDash() < ClientDashWarnScore ? clrOrange : clrDeepSkyBlue)));
      if(UseClientDashboardPolish && ClientDashShowHealthLine)
         DrawDashLine(row++, ShortText(G_CDP_HEALTH_LINE, 130), clrSilver);
      DrawDashLine(row++, "ENV : " + G_ENV_STATUS + " | TickAge " + IntegerToString(TickAgeSeconds()) + "s | Spread " + IntegerToString(G_LAST_SPREAD_POINTS), env_color);
      if(DashboardFullDetail)
         DrawDashLine(row++, "VPS : " + ShortText(G_VPS_STATUS, 120), (G_VPS_OK ? clrLime : clrOrangeRed));
      DrawDashLine(row++, ShortText(G_VPS_NO_TRADE_REASON, 130), (StringFind(G_VPS_NO_TRADE_REASON, "TRADE READY")>=0 ? clrLime : clrSilver));
      DrawDashLine(row++, "RISK: " + G_RISK_STATUS, risk_color);
      DrawDashLine(row++, ShortText(G_RISK_DETAIL, 130), clrSilver);

      DrawDashLine(row++, "BASKET: orders=" + IntegerToString(G_BASKET_ORDERS) +
                         " dir=" + BasketDirectionShort() +
                         " vol=" + DoubleToString(G_BASKET_VOLUME, 2) +
                         " avg=" + DoubleToString(G_BASKET_AVG_PRICE, 2) +
                         " profit=" + DoubleToString(G_BASKET_PROFIT, 2) +
                         " points=" + DoubleToString(G_BASKET_POINTS, 0) +
                         " DD=" + DoubleToString(G_BASKET_DD_PERCENT, 2) + "%", clrWhite);

      if(DashboardFullDetail)
         DrawDashLine(row++, "GRID: " + ShortText(G_GRID_STATUS, 120), grid_color);
      if(!DashboardCompactMode)
      {
      DrawDashLine(row++, "DRI  : " + ShortText(G_DRI_STATUS + " | " + G_DRI_REASON, 115), (G_DRI_GRID_BLOCK ? clrOrangeRed : (G_DRI_APPLIED ? clrDeepSkyBlue : clrSilver)));
      if(DashboardFullDetail)
         DrawDashLine(row++, "DXB  : " + ShortText(G_DXB_STATUS + " | " + G_DXB_REASON, 115), (G_DXB_CLOSE_SENT ? clrLime : (G_DXB_PEAK_GIVEBACK || G_DXB_OPPOSITE_RISK || G_DXB_SHOCK_RISK ? clrOrange : clrSilver)));
      DrawDashLine(row++, "PACK2: " + ShortText(G_PACK2_STATUS, 115), (G_BASKET_TRAIL_ACTIVE ? clrLime : clrSilver));
      if(DashboardFullDetail)
         DrawDashLine(row++, "PACK3: " + ShortText(G_PACK3_STATUS, 115), (G_PACK3_HARD_BLOCK ? clrOrangeRed : (G_PACK3_ENTRY_BLOCK || G_PACK3_GRID_BLOCK ? clrOrange : clrSilver)));
      DrawDashLine(row++, "RC   : " + ShortText(G_RC_STATUS + " | " + G_RC_REASON, 115), (G_RC_READY ? clrLime : clrOrangeRed));
      if(DashboardFullDetail)
         DrawDashLine(row++, "P4M  : " + ShortText(G_P4M_STATUS, 115), (G_P4M_VALID ? clrLime : clrOrangeRed));
      DrawDashLine(row++, "P4L  : " + ShortText(G_P4L_STATUS, 115), (G_P4L_VALID ? clrLime : clrOrangeRed));
      if(DashboardFullDetail)
         DrawDashLine(row++, "RCB  : " + ShortText(G_RCB_STATUS + " | " + G_RCB_REASON, 115), (G_RCB_WARNINGS > 0 ? clrOrange : clrLime));
      DrawDashLine(row++, "FSA  : " + ShortText(G_FSA_STATUS + " | " + G_FSA_DETAIL, 115), (G_FSA_READY ? clrLime : clrOrange));
      if(ShowLegacyModuleLines)
         DrawDashLine(row++, "RLS  : " + ShortText(G_RLS_STATUS + " | " + G_RLS_DETAIL, 115), (G_RLS_READY ? clrLime : clrGold));
      if(DashboardFullDetail)
         DrawDashLine(row++, "DCS  : " + ShortText(G_DCS_STATUS + " | " + G_DCS_REASON, 115), (G_DCS_ENTRY_BLOCK || G_DCS_GRID_BLOCK ? clrOrangeRed : (G_DCS_APPLIED ? clrGold : clrSilver)));
      if(ShowLegacyModuleLines)
         DrawDashLine(row++, "NIM  : " + ShortText(G_NIM_STATUS + " | " + G_NIM_DETAIL, 115), (G_NIM_ENTRY_BLOCK || G_NIM_GRID_BLOCK ? clrOrangeRed : (G_NIM_PRO_READY ? clrLime : (G_NIM_SCORE < FinalMergeWarnScore ? clrOrange : clrDeepSkyBlue))));
      if(DashboardFullDetail)
         DrawDashLine(row++, "FPR  : " + ShortText(G_FPR_STATUS + " | " + G_FPR_DETAIL, 115), (G_FPR_ENTRY_BLOCK || G_FPR_GRID_BLOCK ? clrOrangeRed : (G_FPR_PRO_READY ? clrLime : (G_FPR_WARNINGS > 0 ? clrGold : clrDeepSkyBlue))));
      if(ShowLegacyModuleLines)
         DrawDashLine(row++, "SGV  : " + ShortText(G_SGV_STATUS + " | " + G_SGV_DETAIL, 115), (G_SGV_ENTRY_BLOCK || G_SGV_GRID_BLOCK ? clrOrangeRed : (G_SGV_WARNINGS > 0 ? clrGold : clrSilver)));
      if(DashboardFullDetail)
         DrawDashLine(row++, "CDP  : " + ShortText(G_CDP_STATUS + " | " + G_CDP_DETAIL, 115), (G_CDP_STATUS == "CDP: PRO VIEW" ? clrLime : clrSilver));
      if(ShowLegacyModuleLines)
         DrawDashLine(row++, "DPH  : " + ShortText(G_DPH_STATUS + " | " + G_DPH_DETAIL, 115), (G_DPH_ENTRY_BLOCK || G_DPH_GRID_BLOCK ? clrOrangeRed : (G_DPH_WARNINGS > 0 ? clrGold : clrSilver)));
      if(DashboardFullDetail)
         DrawDashLine(row++, "FBL  : " + ShortText(G_FBL_STATUS + " | " + G_FBL_DETAIL, 115), (G_FBL_ENTRY_BLOCK || G_FBL_GRID_BLOCK ? clrOrangeRed : (G_FBL_LOCKED ? clrLime : (G_FBL_WARNINGS > 0 ? clrGold : clrSilver))));
      if(ShowLegacyModuleLines)
         DrawDashLine(row++, "LVP  : " + ShortText(G_LVP_STATUS + " | " + G_LVP_DETAIL, 115), (G_LVP_ENTRY_READY ? clrLime : (G_LVP_NO_TRADE ? clrGold : clrSilver)));
      if(DashboardFullDetail)
         DrawDashLine(row++, "WCP  : " + ShortText(G_WCP_STATUS, 115), clrSilver);
      DrawDashLine(row++, "PV   : " + ShortText(G_PV_STATUS, 115), clrGold);
      }
      if(!DashboardCompactMode)
      {
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_GRID_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_DRI_DETAIL, 130), clrSilver);
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_DXB_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_PACK2_DETAIL, 130), clrSilver);
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_PACK3_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_RC_DETAIL, 130), clrSilver);
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_P4M_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_P4L_DETAIL, 130), clrSilver);
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_RCB_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_FSA_LEGACY_DETAIL, 130), clrSilver);
         DrawDashLine(row++, ShortText("FSA MISSING: " + G_FSA_REASON, 130), (G_FSA_READY ? clrSilver : clrOrange));
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_RLS_PRESET_DETAIL, 130), clrGold);
         DrawDashLine(row++, ShortText("RLS REASON: " + G_RLS_REASON, 130), (G_RLS_READY ? clrSilver : clrGold));
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_DCS_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_NIM_RECOMMENDATION, 130), clrGold);
         DrawDashLine(row++, ShortText(G_NIM_DEEP_SUMMARY, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText("NIM REASON: " + G_NIM_REASON, 130), (G_NIM_READY ? clrSilver : clrOrange));
         DrawDashLine(row++, ShortText(G_FPR_PRESET, 130), clrGold);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText("FPR REASON: " + G_FPR_REASON, 130), (G_FPR_READY ? clrSilver : clrGold));
         DrawDashLine(row++, ShortText(G_SGV_PROFILE_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText("SGV REASON: " + G_SGV_REASON, 130), (G_SGV_READY ? clrSilver : clrGold));
         DrawDashLine(row++, ShortText(G_CDP_MODE_ADVICE, 130), clrGold);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_CDP_CONTACT_LINE, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_DPH_PRESET_MAP, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText("DPH REASON: " + G_DPH_REASON, 130), (G_DPH_READY ? clrSilver : clrGold));
         DrawDashLine(row++, ShortText(G_FBL_PACKAGE, 130), clrGold);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_FBL_ROADMAP, 130), clrSilver);
         DrawDashLine(row++, ShortText("FBL REASON: " + G_FBL_REASON, 130), (G_FBL_READY ? clrSilver : clrGold));
         if(LiveProbeShowEntryDoctor)
            DrawDashLine(row++, ShortText(G_LVP_ENTRY_DOCTOR, 130), (G_LVP_ENTRY_READY ? clrLime : clrGold));
         if(LiveProbeShowGridDoctor)
            DrawDashLine(row++, ShortText(G_LVP_GRID_DOCTOR, 130), (G_LVP_GRID_READY ? clrLime : clrSilver));
         if(LiveProbeShowGateStack)
            DrawDashLine(row++, ShortText(G_LVP_GATE_STACK, 130), clrSilver);
         if(ShowLegacyModuleLines)
            DrawDashLine(row++, ShortText(G_WCP_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_PV_DETAIL, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_PV_CLEAN_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_PACK3_AUDIT_STATUS, 130), clrSilver);
      }

      if(ShowDashboardSignalBlock)
      {
         DrawDashLine(row++, "------------------------------------------------------------", clrSilver);
         DrawDashLine(row++, "MARKET: " + MarketStateToString(G_MARKET_STATE) + " | " + ShortText(G_MARKET_REASON, 90), clrAqua);
         DrawDashLine(row++, "OPP: " + OpportunityGradeToString(G_OPP_GRADE) + " " +
                            OpportunityDirToString(G_OPP_DIR) + " " +
                            OpportunityTypeToString(G_OPP_TYPE) +
                            " | score=" + IntegerToString(G_OPP_SCORE), (G_OPP_GRADE==OPP_GRADE_NONE ? clrSilver : clrLime));
         DrawDashLine(row++, "SCORE: " + ScoreDecisionToString(G_SCORE_DECISION) +
                            " final=" + IntegerToString(G_SCORE_FINAL) + "/" + IntegerToString(G_SCORE_MIN_REQUIRED) +
                            " | base=" + IntegerToString(G_SCORE_BASE) +
                            " bonus=" + IntegerToString(G_SCORE_BONUS) +
                            " penalty=" + IntegerToString(G_SCORE_PENALTY), score_color);

         if(!DashboardCompactMode)
         {
         DrawDashLine(row++, "LEGACY: " + ShortText(G_LEGACY_STATUS, 115), (G_LEGACY_HARD_BLOCK ? clrOrangeRed : (G_LEGACY_APPLIED ? clrLime : clrSilver)));
         if(DashboardFullDetail)
            DrawDashLine(row++, "DLP   : " + ShortText(G_DLP_STATUS + " | " + G_DLP_REASON, 115), (G_DLP_ENTRY_BLOCK || G_DLP_GRID_BLOCK ? clrOrangeRed : (G_DLP_APPLIED ? clrDeepSkyBlue : clrSilver)));
         DrawDashLine(row++, "DBOS  : " + ShortText(G_DBOS_STATUS + " | " + G_DBOS_REASON, 115), (G_DBOS_ENTRY_BLOCK || G_DBOS_GRID_BLOCK ? clrOrangeRed : (G_DBOS_RETEST_READY ? clrLime : (G_DBOS_APPLIED ? clrDeepSkyBlue : clrSilver))));
         if(DashboardFullDetail)
            DrawDashLine(row++, "DTZ   : " + ShortText(G_DTZ_STATUS + " | " + G_DTZ_REASON, 115), (G_DTZ_ENTRY_BLOCK || G_DTZ_GRID_BLOCK ? clrOrangeRed : (G_DTZ_BREAKOUT_OK ? clrLime : (G_DTZ_APPLIED ? clrDeepSkyBlue : clrSilver))));
         DrawDashLine(row++, "DNV   : " + ShortText(G_DNV_STATUS + " | " + G_DNV_REASON, 115), (G_DNV_ENTRY_BLOCK || G_DNV_GRID_BLOCK ? clrOrangeRed : (G_DNV_NEWS_ACTIVE || G_DNV_SHOCK_ACTIVE ? clrOrange : (G_DNV_APPLIED ? clrDeepSkyBlue : clrSilver))));
         if(DashboardFullDetail)
            DrawDashLine(row++, "DET   : " + ShortText(G_DET_STATUS + " | " + G_DET_REASON, 115), (G_DET_ENTRY_BLOCK || G_DET_GRID_BLOCK ? clrOrangeRed : (G_DET_EARLY_BAR || G_DET_POST_SHOCK ? clrOrange : (G_DET_APPLIED ? clrDeepSkyBlue : clrSilver))));
         DrawDashLine(row++, "DRT   : " + ShortText(G_DRT_STATUS + " | " + G_DRT_REASON, 115), (G_DRT_ENTRY_BLOCK || G_DRT_GRID_BLOCK ? clrOrangeRed : (G_DRT_SHOCK_MODE || G_DRT_CHAOS_MODE ? clrOrange : (G_DRT_APPLIED ? clrDeepSkyBlue : clrSilver))));
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_SCORE_DETAIL, 130), clrSilver);
            DrawDashLine(row++, ShortText(G_LEGACY_DETAIL, 130), clrSilver);
            if(DashboardFullDetail)
               DrawDashLine(row++, ShortText(G_DLP_DETAIL, 130), clrSilver);
            DrawDashLine(row++, ShortText(G_DBOS_DETAIL, 130), clrSilver);
            if(DashboardFullDetail)
               DrawDashLine(row++, ShortText(G_DTZ_DETAIL, 130), clrSilver);
            DrawDashLine(row++, ShortText(G_DNV_DETAIL, 130), clrSilver);
            if(DashboardFullDetail)
               DrawDashLine(row++, ShortText(G_DET_DETAIL, 130), clrSilver);
            DrawDashLine(row++, ShortText(G_DRT_DETAIL, 130), clrSilver);
         }

         if(DashboardFullDetail)
            DrawDashLine(row++, "MICRO: " + ShortText(G_MICRO_STATUS, 115), (G_MICRO_READY ? clrLime : clrSilver));
         DrawDashLine(row++, "QUEUE: " + ShortText(G_QUEUE_STATUS, 115), (G_QUEUE_REPLAYED ? clrLime : (G_QUEUE_ACTIVE ? clrDeepSkyBlue : clrSilver)));
         if(DashboardFullDetail)
            DrawDashLine(row++, "MEMORY: " + ShortText(G_MEMORY_STATUS, 115), (G_MEMORY_APPLIED ? clrLime : (G_MEMORY_REPEAT_COUNT>0 ? clrDeepSkyBlue : clrSilver)));
         DrawDashLine(row++, "REDIRECT: " + ShortText(G_REDIRECT_STATUS, 110), (G_REDIRECT_APPLIED ? clrLime : clrSilver));
         if(DashboardFullDetail)
            DrawDashLine(row++, "BLOCK: " + ShortText(G_BLOCK_STATUS, 115), (G_BLOCK_EXPIRED ? clrOrange : (G_BLOCK_ACTIVE ? clrDeepSkyBlue : clrSilver)));
      }

      DrawDashLine(row++, "------------------------------------------------------------", clrSilver);
      DrawDashLine(row++, "ENTRY: " + ShortText(G_ENTRY_STATUS, 120), entry_color);
      if(!DashboardCompactMode)
         DrawDashLine(row++, ShortText(G_ENTRY_DETAIL, 130), clrSilver);

      if(ShowDashboardCounters)
      {
         DrawDashLine(row++, "COUNTERS: entries " + IntegerToString(G_ENTRY_SUCCESSES) + "/" + IntegerToString(G_ENTRY_ATTEMPTS) +
                            " | grid " + IntegerToString(G_GRID_SUCCESSES) + "/" + IntegerToString(G_GRID_ATTEMPTS) +
                            " | queue save/replay/exp " + IntegerToString(G_QUEUE_SAVED_COUNT) + "/" + IntegerToString(G_QUEUE_REPLAY_COUNT) + "/" + IntegerToString(G_QUEUE_EXPIRED_COUNT) +
                            " | risk blocks " + IntegerToString(G_RISK_BLOCK_COUNT), clrWhite);
         if(DashboardFullDetail)
            DrawDashLine(row++, "LOG: snapshots=" + IntegerToString(G_LOG_SNAPSHOT_COUNT) +
                            " events=" + IntegerToString(G_LOG_EVENT_COUNT) +
                            " | last=" + ShortText(G_LAST_MAJOR_EVENT, 85), clrSilver);
      }

      if(ShowDashboardMarketBlock && !DashboardCompactMode)
      {
         DrawDashLine(row++, "------------------------------------------------------------", clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_TREND_DETAIL, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_RANGE_DETAIL, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_IMPULSE_DETAIL, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_EXHAUSTION_DETAIL, 130), clrSilver);
      }

      if(ShowDashboardEnvBlock && !DashboardCompactMode)
      {
         DrawDashLine(row++, "------------------------------------------------------------", clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_ENV_SYMBOL_STATUS, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_ENV_TRADE_STATUS, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_ENV_SPREAD_STATUS, 130), clrSilver);
         DrawDashLine(row++, ShortText(G_ENV_LEVEL_STATUS + " | " + G_ENV_LOT_STATUS, 130), clrSilver);
         if(DashboardFullDetail)
            DrawDashLine(row++, ShortText(G_ENV_HISTORY_STATUS, 130), clrSilver);
      }

      if(DashboardFullDetail)
         DrawDashLine(row++, "Core: " + TFToString(CoreBarTF) +
                         " | BarsSeen " + IntegerToString(G_BARS_SEEN) +
                         " | LastBar " + SafeTime(G_LAST_BAR_TIME) +
                         " | Updates " + IntegerToString((int)G_UPDATE_COUNT), clrSilver);
      if(DashboardFullDetail)
         DrawDashLine(row++, "Warning: " + G_LAST_WARNING, (G_LAST_WARNING=="none" ? clrSilver : clrOrange));
      // V226c: removed - a roadmap note on a live dashboard.
   }
   else
   {
      // V226c: removed - the title line above already names the EA, and a build-phase string is
      // developer bookkeeping rather than something to read while trading.
      // V226c: removed - the title line carries this now.
      DrawDashLine(row++, "WHY: " + G_NEXT_ACTION, clrLime);
      if(DashboardFullDetail)
         DrawDashLine(row++, "Mode: " + ModeToString(NaviusMode) + " -> " + ModeToString(G_ACTIVE_MODE), clrWhite);
      DrawDashLine(row++, "Environment: " + G_ENV_STATUS, env_color);
      if(DashboardFullDetail)
         DrawDashLine(row++, G_RISK_STATUS, risk_color);
      DrawDashLine(row++, G_MARKET_STATUS, clrAqua);
      // V110: show the structural reading so the trader can see what the bot understands about the
      // swing chain, not just its final score.
      // V117: the consensus line sits first - it is the EA's one-sentence summary of everything below.
      if(EnableMarketVerdict && StringLen(G_VERDICT_TXT) > 0)
         DrawDashLine(row++, G_VERDICT_TXT,
                      (G_VERDICT_DIR > 0 ? clrLime : (G_VERDICT_DIR < 0 ? clrOrangeRed : clrGold)));
      // V142: the event chain in plain language - what the market has actually done, in order.
      if(EnableEventChain && ShowEventChainOnDash)
         DrawDashLine(row++, EventChainText(5), clrSilver);
      // V143: and what that sequence implies about the next move.
      if(EnableChainExpectation)
      {
         double dash_conf = 0.0;
         string dash_detail = "";
         int dash_pat = CHAIN_PAT_NONE;
         int dash_dir = ChainExpectation(dash_conf, dash_detail, dash_pat);
         if(dash_dir != 0)
            DrawDashLine(row++, dash_detail,
                         (dash_dir > 0 ? clrLime : clrOrangeRed));
      }
      // V144: and how much the readings actually agree - a narrow split is a market with no owner.
      if(EnableScenarios && ShowScenariosOnDash)
      {
         double dsc_up = 0.0, dsc_dn = 0.0, dsc_no = 0.0;
         string dsc_detail = "";
         ScenarioProbabilities(dsc_up, dsc_dn, dsc_no, dsc_detail);
         if(StringLen(dsc_detail) > 0)
            DrawDashLine(row++, dsc_detail,
                         (MathAbs(dsc_up - dsc_dn) < ScenarioMinMargin ? clrGold
                          : (dsc_up > dsc_dn ? clrLime : clrOrangeRed)));
      }
      // V150: the unit the market itself is working in - thresholds adapt to this.
      if(EnableMarketScale && ShowMarketScaleOnDash)
      {
         double dms_ratio = 0.0;
         string dms_detail = "";
         double dms_scale = MarketStructureScale(dms_ratio, dms_detail);
         if(dms_scale > 0.0)
            DrawDashLine(row++, dms_detail, clrSilver);
      }

      // V153: and whether the score's own conviction ordering is holding up.
      if(EnableScoreCalibration && ShowCalibrationOnDash)
      {
         string cal_txt = ScoreCalibrationText();
         if(StringLen(cal_txt) > 0)
            DrawDashLine(row++, cal_txt, clrSilver);
      }

      // V154: and what this market actually did the last times it looked like this.
      if(EnablePatternMemory && ShowPatternMemoryOnDash)
      {
         int    dpm_samples = 0;
         double dpm_fit = 0.0;
         string dpm_detail = "";
         double dpm_bias = PatternMemoryBias(dpm_samples, dpm_fit, dpm_detail);
         if(StringLen(dpm_detail) > 0)
            DrawDashLine(row++, dpm_detail,
                         (MathAbs(dpm_bias) < PatternMemoryMinBias ? clrSilver
                          : (dpm_bias > 0 ? clrLime : clrOrangeRed)));
      }

      // V155: and which of the EA's own warnings have been earning their keep.
      if(EnableWarningLearning && ShowWarningStatsOnDash)
      {
         string wr_txt = WarningReliabilityText();
         if(StringLen(wr_txt) > 0)
            DrawDashLine(row++, wr_txt, clrSilver);
      }

      // V156: the regime currently in force - it sets targets, spacing and the score bar.
      if(EnableRegimeSwitching && ShowRegimeOnDash && StringLen(G_REGIME_TEXT) > 0)
         DrawDashLine(row++, G_REGIME_TEXT,
                      (G_REGIME == REGIME_TRENDING ? clrLime
                       : (G_REGIME == REGIME_VOLATILE ? clrOrangeRed
                          : (G_REGIME == REGIME_RANGING ? clrGold : clrSilver))));

      // V157: whether the blocks are earning their keep, and where this system actually works.
      if(EnableBlockAudit && ShowBlockAuditOnDash)
      {
         string ba_txt = BlockAuditText();
         if(StringLen(ba_txt) > 0)
            DrawDashLine(row++, ba_txt, clrSilver);
         string rp_txt = RegimePerfText();
         if(StringLen(rp_txt) > 0)
            DrawDashLine(row++, rp_txt, clrSilver);
      }

      // V159: what the current opportunity would commit to if it were taken.
      if(EnableBasketProjection && ShowProjectionOnDash && G_BASKET_ORDERS <= 0 &&
         G_OPP_DIR != OPP_DIR_NONE)
      {
         int    dpj_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : -1);
         double dpj_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dpj_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double dpj_entry = (dpj_dir > 0) ? dpj_ask : dpj_bid;
         if(dpj_entry > 0.0)
         {
            int    dpj_orders = 0;
            double dpj_lots = 0.0, dpj_dd = 0.0, dpj_margin = 0.0;
            string dpj_detail = "";
            double dpj_sev = ProjectBasketRisk(dpj_dir, dpj_entry, dpj_orders, dpj_lots,
                                               dpj_dd, dpj_margin, dpj_detail);
            if(StringLen(dpj_detail) > 0)
               DrawDashLine(row++, dpj_detail,
                            (dpj_sev >= ProjectionBlockSeverity ? clrOrangeRed
                             : (dpj_sev >= ProjectionCautionSeverity ? clrGold : clrSilver)));
         }
      }

      // V160: and how the basket that is already open is holding up.
      if(EnableBasketHealth && ShowBasketHealthOnDash && G_BASKET_ORDERS > 0)
      {
         string bh_detail = "";
         double bh = BasketHealthIndex(bh_detail);
         if(StringLen(bh_detail) > 0)
            DrawDashLine(row++, bh_detail,
                         (bh >= BasketHealthGood ? clrLime
                          : (bh <= BasketHealthPoor ? clrOrangeRed : clrGold)));
      }

      // V162: whether the market is going anywhere at all.
      if(EnableNoiseFilter && ShowNoiseOnDash)
      {
         double dnz_reach = 1.0;
         string dnz_detail = "";
         double dnz = MarketNoiseLevel(dnz_reach, dnz_detail);
         if(StringLen(dnz_detail) > 0)
            DrawDashLine(row++, dnz_detail,
                         (dnz >= NoiseBlockLevel ? clrOrangeRed
                          : (dnz >= NoiseCautionLevel || dnz_reach < NoiseMinReachability ? clrGold : clrSilver)));
      }

      // V163: who is actually winning the bars right now.
      if(EnablePressureReading && ShowPressureOnDash)
      {
         double dpr_trend = 0.0;
         bool   dpr_div = false;
         string dpr_detail = "";
         double dpr = DominantSidePressure(dpr_trend, dpr_div, dpr_detail);
         if(StringLen(dpr_detail) > 0)
            DrawDashLine(row++, dpr_detail,
                         (dpr_div ? clrGold : (dpr > 0 ? clrLime : (dpr < 0 ? clrOrangeRed : clrSilver))));
      }

      // V164: which session is running, and how long until it changes hands.
      if(EnableSessionContext && ShowSessionOnDash)
      {
         int    dsc_mins = 999;
         string dsc_detail = "";
         int    dsc_sess = SessionContext(dsc_mins, dsc_detail);
         if(StringLen(dsc_detail) > 0)
            DrawDashLine(row++, dsc_detail,
                         (dsc_sess == SESSION_DEAD ? clrOrangeRed
                          : (dsc_mins <= SessionChangeWarnMinutes ? clrGold
                             : (dsc_sess == SESSION_OVERLAP ? clrLime : clrSilver))));
      }

      // V165: and what this trade costs before it can earn anything.
      if(EnableSpreadEconomics && ShowSpreadCostOnDash)
      {
         string dsp_detail = "";
         double dsp = SpreadCostRatio(dsp_detail);
         if(StringLen(dsp_detail) > 0)
            DrawDashLine(row++, dsp_detail,
                         (dsp >= SpreadCostRefuse ? clrOrangeRed
                          : (dsp >= SpreadCostCaution ? clrGold : clrSilver)));
      }

      // V166: what recent history says - a run of losses, or losing repeatedly in one place.
      if(EnableStreakAwareness && ShowStreakOnDash && (G_LOSS_STREAK > 0 || G_WIN_STREAK > 0))
      {
         string stk = (G_LOSS_STREAK > 0)
                      ? StringFormat("streak: %d losses in a row", G_LOSS_STREAK)
                      : StringFormat("streak: %d wins in a row", G_WIN_STREAK);
         if(DashboardFullDetail)
            DrawDashLine(row++, stk,
                      (G_LOSS_STREAK >= StreakCautionLosses ? clrOrangeRed
                       : (G_WIN_STREAK > 0 ? clrLime : clrSilver)));
      }



      // V192: where setups are being lost. This is the line that answers "why is it not trading" -
      // each number is a different problem with a different fix, and without them the answer comes
      // from guessing which of thirty gates is responsible.
      if(ShowEntryFunnelOnDash)
      {
         DrawDashLine(row++, StringFormat("funnel: %d setups -> %d score-wait, %d blocked, %d gated -> %d entries",
                                          G_FUNNEL_SETUPS, G_FUNNEL_SCORE_WAIT, G_FUNNEL_HARD_BLOCK,
                                          G_FUNNEL_GATE_BLOCK, G_FUNNEL_ENTRIES),
                      (G_FUNNEL_ENTRIES > 0 ? clrLime : clrGold));
         if(StringLen(G_FUNNEL_LAST_GATE) > 0)
            DrawDashLine(row++, "last gate: " + G_FUNNEL_LAST_GATE, clrGold);
      }

      // V194: what the EA is currently holding and why.
      if(EnableSetupArming && ShowSetupArmOnDash)
      {
         string arm_txt = SetupArmText();
         if(StringLen(arm_txt) > 0)
            DrawDashLine(row++, arm_txt, clrGold);
      }

      // V196: and what the independent readings currently say about it.
      if(EnableSetupArming && EnableArmConsensus && ShowSetupArmOnDash && G_ARM_DIR != 0)
      {
         string cd = "";
         int cv = SetupArmConsensus(cd);
         if(StringLen(cd) > 0)
            DrawDashLine(row++, "  consensus: " + cd,
                         (cv > 0 ? clrLime : (cv < 0 ? clrOrangeRed : clrSilver)));
      }

      // V197: whether waiting has been worth it, by objection type.
      if(EnableArmAudit && ShowArmAuditOnDash)
      {
         string aa = ArmAuditText();
         if(StringLen(aa) > 0)
            DrawDashLine(row++, aa, clrSilver);
      }

      // V207: what the candles themselves are doing.
      if(EnableCandleSequence && ShowCandleStateOnDash)
      {
         int    dcs_dir = 0;
         double dcs_conf = 0.0;
         string dcs_detail = "";
         int    dcs_state = CandleSequenceRead(dcs_dir, dcs_conf, dcs_detail);
         if(StringLen(dcs_detail) > 0)
            DrawDashLine(row++, dcs_detail,
                         (dcs_state == CANDLE_STATE_REJECTION || dcs_state == CANDLE_STATE_ABSORPTION)
                          ? clrGold
                          : (dcs_dir > 0 ? clrLime : (dcs_dir < 0 ? clrOrangeRed : clrSilver)));
      }

      // V209: and how those readings have actually been resolving.
      if(EnableCandleFollowThrough && ShowCandleFollowOnDash && ShowDetailedDiagnostics)
      {
         double d_rel = CandleRejectionReliability();
         double d_brk = CandleBreakReliability();
         if(d_rel >= 0.0 || d_brk >= 0.0)
         {
            string ft = "follow: ";
            if(d_rel >= 0.0)
               ft += StringFormat("rejections %.0f%% hold (%.0f) ", d_rel * 100.0,
                                  G_CE_REJECT_HELD + G_CE_REJECT_FAILED);
            if(d_brk >= 0.0)
               ft += StringFormat("breaks %.0f%% hold (%.0f)", d_brk * 100.0,
                                  G_CE_BREAK_HELD + G_CE_BREAK_FAILED);
            if(DashboardFullDetail)
               DrawDashLine(row++, ft,
                         ((d_rel >= 0.0 && d_rel <= CandleFollowThroughPoorRate) ||
                          (d_brk >= 0.0 && d_brk <= CandleFollowThroughPoorRate))
                          ? clrGold : clrSilver);
         }
      }

      // V210: any recognised shape right now, and how much participation is behind it.
      if(EnableCandlePatterns && ShowCandlePatternOnDash && ShowDetailedDiagnostics)
      {
         int    dp_dir = 0;
         double dp_conf = 0.0;
         string dp_detail = "";
         int    dp_pat = CandlePatternRead(dp_dir, dp_conf, dp_detail);
         double dp_part = EnableCandleParticipation ? CandleParticipation(1) : 1.0;

         if(dp_pat != CPAT_NONE)
            DrawDashLine(row++, StringFormat("pattern: %s (%.0f%% clean, %.1fx volume)",
                                             dp_detail, dp_conf * 100.0, dp_part),
                         (dp_dir > 0 ? clrLime : clrOrangeRed));
         else if(EnableCandleParticipation &&
                 (dp_part >= CandleParticipationStrong || dp_part <= CandleParticipationThin))
            if(DashboardFullDetail)
               DrawDashLine(row++, StringFormat("participation: %.1fx %s", dp_part,
                                             (dp_part >= CandleParticipationStrong ? "- market showed up"
                                                                                   : "- thin book")),
                         clrGold);
      }

      // V211: which timeframe is speaking, and how the shapes have been resolving here.
      if(EnableCandleHTF && ShowCandlePatternOnDash && ShowDetailedDiagnostics)
      {
         double dh_body = 0.0;
         string dh_detail = "";
         int dh_dir = (G_OPP_DIR == OPP_DIR_BUY ? 1 : (G_OPP_DIR == OPP_DIR_SELL ? -1 : 0));
         if(dh_dir != 0)
         {
            int dh_agree = CandleHTFAgreement(dh_dir, dh_body, dh_detail);
            if(StringLen(dh_detail) > 0)
               DrawDashLine(row++, "htf: " + dh_detail,
                            (dh_agree > 0 ? clrLime : (dh_agree < 0 ? clrOrangeRed : clrSilver)));
         }
      }

      // V212: what the bar currently forming is doing.
      if(EnableLiveBarRead && ShowLiveBarOnDash)
      {
         int    dl_dir = 0;
         double dl_w = 0.0;
         string dl_detail = "";
         int    dl_state = LiveBarRead(dl_dir, dl_w, dl_detail);
         if(dl_state != CANDLE_STATE_NEUTRAL && StringLen(dl_detail) > 0)
            DrawDashLine(row++, dl_detail,
                         (dl_w >= 0.5 ? (dl_dir > 0 ? clrLime : (dl_dir < 0 ? clrOrangeRed : clrGold))
                                      : clrSilver));
      }

      // V213: and what changed within it.
      if(EnableLiveBarEvolution && ShowLiveEvolutionOnDash && ShowDetailedDiagnostics)
      {
         int    de_dir = 0;
         double de_w = 0.0;
         string de_detail = "";
         int    de = LiveBarEvolution(de_dir, de_w, de_detail);
         if(de != LIVE_EVO_NONE && StringLen(de_detail) > 0)
            DrawDashLine(row++, "  " + de_detail,
                         (de_dir > 0 ? clrLime : (de_dir < 0 ? clrOrangeRed : clrGold)));
      }

      // V214: what the candle layer contributed in total, after its own budget.
      if(ShowCandleStateOnDash && (G_CANDLE_BONUS > 0 || G_CANDLE_PENALTY > 0))
         DrawDashLine(row++, StringFormat("  candles net: +%d / -%d (cap %d)",
                                          G_CANDLE_BONUS, G_CANDLE_PENALTY, MaxCandlePenalty),
                      clrSilver);

      // V215: and whether the readings are telling one story or two.
      if(EnableCandleConflict && ShowCandleStateOnDash && ShowDetailedDiagnostics)
      {
         int    dcf_dir = 0;
         double dcf_w = 0.0;
         string dcf_detail = "";
         int    dcf = CandleConflictRead(dcf_dir, dcf_w, dcf_detail);
         if(dcf != CCONF_NONE && StringLen(dcf_detail) > 0)
            DrawDashLine(row++, "  " + dcf_detail,
                         (dcf == CCONF_SPLIT ? clrSilver
                          : (dcf_dir > 0 ? clrLime : clrOrangeRed)));
      }

      // V216: what each candle source has learned about itself.
      if(EnableCandleLearning && ShowCandleLearningOnDash && ShowDetailedDiagnostics)
      {
         string cl = CandleLearningText();
         if(StringLen(cl) > 0)
            DrawDashLine(row++, cl, clrSilver);
      }

      // V219: whether the layers are describing one situation, and which.
      if(EnableSituationRead && ShowCandleStateOnDash)
      {
         int    ds_dir = 0;
         double ds_w = 0.0;
         string ds_detail = "";
         int    ds = ReadSituation(ds_dir, ds_w, ds_detail);
         if(ds != SIT_NONE && StringLen(ds_detail) > 0)
            DrawDashLine(row++, StringFormat("situation: %s - %s (%.0f%%)",
                                             SituationName(ds), ds_detail, ds_w * 100.0),
                         (ds_dir > 0 ? clrLime : clrOrangeRed));
      }

      // V220: and the plan that situation implies.
      if(EnableSituationPlan && ShowCandleStateOnDash && G_SITUATION != SIT_NONE && G_SITUATION_DIR != 0)
      {
         string dp_detail = "";
         double dp_pts = SituationTargetPoints(G_SITUATION, G_SITUATION_DIR, dp_detail);
         if(dp_pts > 0.0)
            DrawDashLine(row++, StringFormat("  plan: %s | grid x%.2f | lot x%.2f",
                                             dp_detail,
                                             SituationGridFactor(G_SITUATION),
                                             SituationLotFactor(G_SITUATION)),
                         clrAqua);
      }

      // V221/V222: what the grid is thinking about its next addition.
      if(G_BASKET_ORDERS > 0 && (G_GRID_DIRECTION_DOUBT > 0.05 || G_GRID_SNAP_PRICE > 0.0))
      {
         string gtxt = "grid: ";
         if(G_GRID_DIRECTION_DOUBT > 0.05)
            gtxt += StringFormat("doubt %.0f%% ", G_GRID_DIRECTION_DOUBT * 100.0);
         if(G_GRID_SNAP_PRICE > 0.0)
            gtxt += StringFormat("| waiting for %.2f", G_GRID_SNAP_PRICE);
         if(DashboardFullDetail)
            DrawDashLine(row++, gtxt,
                      (G_GRID_DIRECTION_DOUBT >= GridDoubtBlockLevel ? clrOrangeRed : clrGold));
      }

      // V218: the shape of the recent swings on its own.
      if(EnableLocalSwingShape && ShowCandleStateOnDash && ShowDetailedDiagnostics)
      {
         int    dw_steps = 0;
         double dw_conv = 0.0;
         string dw_detail = "";
         int    dw_dir = LocalSwingShape(dw_steps, dw_conv, dw_detail);
         if(dw_dir != 0 && StringLen(dw_detail) > 0)
            DrawDashLine(row++, "swings: " + dw_detail,
                         (dw_dir > 0 ? clrLime : clrOrangeRed));
      }

      // V223: the measured structure - shape, step size, and the price that ends it.
      if(EnableLocalStructure && ShowLocalStructureOnDash)
      {
         LocalStructureUpdate();
         if(G_LS_STATE != LSTRUCT_NONE && StringLen(G_LS_DETAIL) > 0)
            DrawDashLine(row++, "structure: " + G_LS_DETAIL,
                         (G_LS_STATE == LSTRUCT_CHOPPY ? clrSilver
                          : (G_LS_DIR > 0 ? clrLime : clrOrangeRed)));
      }

      // V224: a recent break, and whether the structure ends where a zone sits.
      if(EnableStructureBreak && ShowLocalStructureOnDash)
      {
         double db_fresh = 0.0, db_price = 0.0;
         int db_dir = RecentStructureBreak(db_fresh, db_price);
         if(db_dir != 0)
            DrawDashLine(row++, StringFormat("  broke %.2f -> %s (%.0f%% fresh)",
                                             db_price, (db_dir > 0 ? "bullish" : "bearish"),
                                             db_fresh * 100.0),
                         (db_dir > 0 ? clrLime : clrOrangeRed));
      }
      // FIX(structure-dash-brace): this block used to stay open across all three sections below -
      // no closing brace after the confluence content - so EnableStructureMTF and
      // EnableStructureMaturity, despite each having their own enable flag, could only ever draw
      // when EnableStructureConfluence AND ShowDetailedDiagnostics were ALSO true. Closed here so
      // each of the three dashboard lines is gated only by its own documented flags.
      if(EnableStructureConfluence && ShowLocalStructureOnDash && ShowDetailedDiagnostics)
      {
         double dc_level = 0.0;
         string dc_detail = "";
         double dc_w = StructureLevelConfluence(dc_level, dc_detail);
         if(dc_w >= StructureConfluenceMinWeight && StringLen(dc_detail) > 0)
            DrawDashLine(row++, "  " + dc_detail, clrAqua);
      }

      // V225: the three-timeframe picture, and how far the structure has run.
      if(EnableStructureMTF && ShowLocalStructureOnDash)
      {
         int    da_dir = 0;
         double da_w = 0.0;
         string da_detail = "";
         int    da = StructureAlignment(da_dir, da_w, da_detail);
         if(da != TFALIGN_NONE && StringLen(da_detail) > 0)
            DrawDashLine(row++, "  " + da_detail,
                         (da == TFALIGN_FULL ? (da_dir > 0 ? clrLime : clrOrangeRed)
                          : (da == TFALIGN_TRANSITION ? clrGold : clrSilver)));
      }
      if(EnableStructureMaturity && ShowLocalStructureOnDash && ShowDetailedDiagnostics)
      {
         string dm_detail = "";
         double dm = StructureMaturity(dm_detail);
         if(dm >= StructureMatureFrom && StringLen(dm_detail) > 0)
            DrawDashLine(row++, StringFormat("  %s (%.0f%% mature)", dm_detail, dm * 100.0), clrGold);
      }

      if(EnablePatternGrading && ShowCandlePatternOnDash && ShowDetailedDiagnostics)
      {
         string pg = "";
         for(int pi = 1; pi < 8; pi++)
         {
            double wr = PatternWinRate(pi);
            if(wr >= 0.0)
               pg += StringFormat("%s %.0f%%(%.0f) ", CandlePatternName(pi), wr * 100.0,
                                  G_PAT_WON[pi] + G_PAT_LOST[pi]);
         }
         if(StringLen(pg) > 0)
            DrawDashLine(row++, "patterns: " + pg, clrSilver);
      }

      // V167: where the nearest zone actually reacts, as opposed to where it reaches.
      if(EnableZoneEdges && ShowZoneEdgesOnDash)
      {
         double dze_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dze_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double dze_mid = (dze_bid > 0.0 && dze_ask > 0.0) ? (dze_bid + dze_ask) / 2.0 : dze_bid;
         if(dze_mid > 0.0)
         {
            double dze_sup = ZoneMapNearestSupport(dze_mid);
            double dze_res = ZoneMapNearestResistance(dze_mid);
            double dze_o = 0.0, dze_i = 0.0;
            string dze_detail = "";
            if(dze_sup > 0.0 && ZoneEdgePrices(dze_sup, true, dze_o, dze_i, dze_detail))
               DrawDashLine(row++, dze_detail, clrSilver);
            else if(dze_res > 0.0 && ZoneEdgePrices(dze_res, false, dze_o, dze_i, dze_detail))
               if(DashboardFullDetail)
                  DrawDashLine(row++, dze_detail, clrSilver);
         }
      }

      // V169: whether the target is the right size, and what the fills are actually costing.
      if(ShowDiagnosticsOnDash)
      {
         string eq_txt = ExitQualityText();
         if(StringLen(eq_txt) > 0)
            DrawDashLine(row++, eq_txt, clrSilver);
         string sl_txt = SlippageText();
         if(StringLen(sl_txt) > 0)
            DrawDashLine(row++, sl_txt, clrSilver);
      }

      // V121: the two maturity readings side by side - one answers "how far has TODAY gone",
      // the other "how far has the whole move gone". Late entries usually fail one of them.
      if(EnableMoveExtension || EnableADRFilter)
      {
         string mat_txt = "maturity:";
         if(EnableMoveExtension)
         {
            int mat_dir = (G_STRUCTURE_DIR != 0) ? G_STRUCTURE_DIR : 1;
            double ext_now = MoveExtensionATR(mat_dir);
            mat_txt += StringFormat(" move %.1f ATR (mature %.1f)", ext_now, MoveExtensionMatureATR);
         }
         if(EnableADRFilter)
         {
            int adr_dir = 0;
            double adr_used = ADRUsedPercent(adr_dir);
            mat_txt += StringFormat(" | today %.0f%% of ADR (limit %.0f%%)", adr_used, ADRExhaustPercent);
         }
         if(DashboardFullDetail)
            DrawDashLine(row++, mat_txt, clrSilver);
      }
      if(EnableMarketStructure)
         DrawDashLine(row++, G_STRUCTURE_DETAIL,
                      (G_STRUCTURE_DIR > 0 ? clrLime : (G_STRUCTURE_DIR < 0 ? clrOrangeRed : clrSilver)));
      // V113: the staircase reading sits right under the structure line - together they are the
      // EA's account of what the market is doing, in the same words a trader would use.
      if(EnableBreakSequence && StringLen(G_BREAK_SEQ_TXT) > 0)
         DrawDashLine(row++, G_BREAK_SEQ_TXT,
                      (G_BREAK_SEQ_DIR > 0 ? clrLime : (G_BREAK_SEQ_DIR < 0 ? clrOrangeRed : clrSilver)));
      if(EnableDailyBias)
         DrawDashLine(row++, G_DAILY_BIAS_TXT,
                      (G_DAILY_BIAS > 0 ? clrLime : (G_DAILY_BIAS < 0 ? clrOrangeRed : clrSilver)));
      if(DashboardFullDetail)
         DrawDashLine(row++, G_OPP_STATUS, (G_OPP_GRADE==OPP_GRADE_NONE ? clrSilver : clrLime));
      DrawDashLine(row++, G_SCORE_STATUS, score_color);
      DrawDashLine(row++, G_GRID_STATUS, grid_color);
      DrawDashLine(row++, G_ENTRY_STATUS, entry_color);
   }

   ChartRedraw(0);

      // V228e: moved out to the top level of the dashboard. It had ended up inside an else branch,
      // so the health count only drew in one of the two layout paths - and the path it was missing
      // from is the one the EA uses. A number that appears sometimes is worse than one that never
      // does, because its absence reads as normal.

      // CONSENSUS: how many detectors on each side, and how clearly one won.
      if(EnableDirectionConsensus || EnableDirectionClarity)
      {
         if(G_OPP_VOICES_BUY > 0 || G_OPP_VOICES_SELL > 0)
            DrawDashLine(row++, StringFormat("voices: BUY %d (best %d) | SELL %d (best %d) | %.0f%% clear",
                         G_OPP_VOICES_BUY, G_OPP_BEST_BUY_SCORE,
                         G_OPP_VOICES_SELL, G_OPP_BEST_SELL_SCORE,
                         G_OPP_DIR_CLARITY * 100.0),
                         (G_OPP_DIR_CLARITY >= ClarityLowBelow) ? clrLime : clrGold);
      }

      // SCENARIO: what reactions at this kind of level have been doing.
      if(EnableScenario)
      {
         string sc_t = ScenarioText();
         if(StringLen(sc_t) > 0)
            DrawDashLine(row++, sc_t,
                         (G_SCEN_PROJ >= ScenGridMinATR) ? clrLime : clrGold);
      }

      // FAILED BREAK: a level reached through and taken back.
      if(EnableFailedBreakGuard && ShowFailedBreakOnDash)
      {
         string fb_t = FailedBreakText();
         if(StringLen(fb_t) > 0)
            DrawDashLine(row++, fb_t, clrGold);
      }

      // OLD LEVEL: the thing from weeks ago sitting in front of a breakout.
      if(EnableOldLevelGuard && ShowOldLevelOnDash)
      {
         string ol_t = OldLevelText();
         if(StringLen(ol_t) > 0)
            DrawDashLine(row++, ol_t, clrOrange);
      }

      // HTF BIAS: what the larger timeframes are doing, when they are doing anything.
      if(EnableHTFBias && ShowHTFOnDash)
      {
         string ht = HTFBiasText();
         if(StringLen(ht) > 0)
            DrawDashLine(row++, ht, clrAqua);
      }

      // ADAPT: what the recent record has added to the demand.
      if(EnableEvidenceTighten)
      {
         string at = AdaptText();
         if(StringLen(at) > 0)
            DrawDashLine(row++, at, (G_ADAPT_EXTRA > 0.0) ? clrGold : clrLime);
      }

      // SAFETY VALVE: which addition is standing down, if any.
      if(EnableSafetyValve)
      {
         string vt = ValveText();
         if(StringLen(vt) > 0)
            DrawDashLine(row++, vt, (G_VALVE_OFF != VALVE_NONE) ? clrOrange : clrSilver);
      }

      // QUIET ALARM: how long since anything opened, and which gate has been doing it.
      if(EnableQuietAlarm)
      {
         string qt = QuietText();
         if(StringLen(qt) > 0)
            DrawDashLine(row++, qt, (G_QUIET_BARS >= QuietAlarmBars) ? clrRed : clrLime);
      }

      // GATE REGISTRY: which gate refused, and how often today. The reason text says what happened;
      // this says which module to change.
      if(EnableGateRegistry && ShowGateTallyOnDash)
      {
         string gt = GateTallyText();
         if(StringLen(gt) > 0)
            DrawDashLine(row++, gt, clrSilver);
      }

      // LOCATION BRAIN: where price sits in the leg it would be joining, and why anything is being
      // held. One line - it is the question the two stops got wrong.
      if(EnableLocationBrain && ShowLocationBrainOnDash)
      {
         string lb_txt = LocationBrainText();
         if(StringLen(lb_txt) > 0)
            DrawDashLine(row++, lb_txt, (G_LB_VERDICT == LB_OK) ? clrLime : clrGold);
      }


      // V247: and whether the reason it was opened on still holds.
      if(EnableBasketThesis && G_BASKET_ORDERS > 0 && G_BASKET_INVALIDATION > 0.0)
      {
         string th_txt = "";
         bool dead = BasketPremiseDead(th_txt);
         DrawDashLine(row++, dead ? ("thesis: " + th_txt)
                                  : StringFormat("thesis: %s, wrong past %.2f",
                                                 G_BASKET_THESIS, G_BASKET_INVALIDATION),
                      dead ? clrOrangeRed : clrSilver);
      }


      // V244: and whether the open basket can still get where it needs to go.
      if(EnableBasketReach && ShowBasketReachOnDash && G_BASKET_ORDERS > 0)
      {
         double br_atr = 0.0;
         string br_detail = "";
         double br = BasketReachability(br_atr, br_detail);
         if(StringLen(br_detail) > 0)
            DrawDashLine(row++, "reach: " + br_detail,
                         (br >= 0.66 ? clrLime : (br >= 0.33 ? clrGold : clrOrangeRed)));
      }


      // V269: and which setups have been earning it.
      if(EnableSetupLearning && ShowSetupLearningOnDash)
      {
         string sl_txt = SetupLearningText();
         if(StringLen(sl_txt) > 0)
            DrawDashLine(row++, sl_txt, clrSilver);
      }


      // V242: and what all of it is actually earning. A win rate that keeps rising while expectancy
      // falls is the pattern that ends accounts, and nothing else on this dashboard would show it.
      if(EnableExpectancy && ShowExpectancyOnDash)
      {
         string ev_txt = ExpectancyText();
         if(StringLen(ev_txt) > 0)
         {
            double wr = 0.0, aw = 0.0, al = 0.0;
            double ev = ExpectancyPerBasket(wr, aw, al);
            DrawDashLine(row++, ev_txt,
                         (ev > 0.0 ? clrLime : (ev < 0.0 ? clrOrangeRed : clrSilver)));
         }
      }


      // V226: does the analysis layer actually work? One number, checked at a glance.
      if(EnableModuleHealth && ShowModuleHealthOnDash)
      {
         // V226d: refresh here too. The scan normally runs on tick, and a dashboard drawn while the
         // market is closed would otherwise show nothing at all - which is exactly when someone is
         // most likely to be looking at it to find out why nothing is happening.
         ModuleHealthUpdate();

         string silent = "";
         string mh = ModuleHealthLine(silent);
         if(StringLen(mh) > 0)
         {
            bool all_ok = (StringLen(silent) == 0);
            DrawDashLine(row++, mh, (all_ok ? clrLime : clrGold));
            if(!all_ok && ShowSilentModuleNames)
               DrawDashLine(row++, "  quiet: " + silent, clrGold);
         }
      }

   // V227b: how many lines this actually drew. The static analysis of which lines are visible kept
   // disagreeing with the screenshot, because the guards are nested three deep in places and a
   // regex cannot resolve them. The EA can simply count.
   if(ShowDashboardLineCount)
      DrawDashLine(row++, StringFormat("(%d lines - set DashboardFullDetail for the rest)", row), clrDimGray);
}
