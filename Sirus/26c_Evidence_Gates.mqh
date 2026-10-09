//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 26c_Evidence_Gates                              |
//| Every quality filter proves its place on the robot's own numbers. |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// WHY. The basket targets ~224 points against a ~5500-point grid step, so almost every entry reaches
// its TP - the owner's shadow files (06..09-Oct, 2065 setups): taken trades 90% TP, refused ones 91%.
// What separates a good entry from a bad one here is whether the basket NEEDED THE GRID: taken 10.4%,
// refused by the score 7.1%, refused by the brain on the bias side 7.1%, refused by the brain AGAINST the
// bias 16.1%. So most quality filters cut the trade count tenfold without making entries better, and
// the direction veto against the bias really does keep bad entries out.
//
// WHAT. Each quality filter (evidence key) keeps two tallies - on the side with / neutral to the global
// bias and on the side against it - of how often the setups it refused needed the grid, and compares
// that with the trades actually taken on that side:
//   refused need the grid no more often than taken        -> the filter stands aside on that side
//   refused need it EGKeepMargin more often than taken      -> the filter works again
//   fewer than EGMinSamples results                         -> the filter works (no proof, no change)
// A filter that stands aside still learns: the result of every entry it let through is its sample.
//
// NEVER RELAXED: the direction gates (V0 permission, LOCK, the council's structure rules, V1 reversal,
// V4 acceleration), news, spread, risk, anomaly, re-entry after a dead idea.
//
// SAFETY. Nothing relaxes while the market is abnormal (news window, tick-velocity pause, anomaly, a
// spread over 1.5x this hour's normal). Circuit breaker: when EGBreakerGridBaskets of the last four
// baskets entered with a filter standing aside needed the grid, every relaxation stops for
// EGBreakerMinutes. The tallies survive a restart (terminal variables) and fade (halved at 300).

input group "BRAIN ▸ Evidence gates (self-calibrating filters)"
// EnableEvidenceGates: Har bir sifat filtri o'z o'rnini raqam bilan isbotlaydi - to'sganlari olinganlardan ko'proq gridga bormasa, o'sha tomonda to'smaydi
input bool   EnableEvidenceGates     = true;   // Evidence gates: each quality filter proves its place
// EGMinSamples: Filtr baholanishi uchun kamida shuncha natija (har tomon uchun)
input int    EGMinSamples            = 30;   // Results a filter needs before it is judged
// EGBaseBadRate: Olingan savdolar yetarli o'lchanguncha ularning grid ulushi (egasining fayllari: 10%)
input double EGBaseBadRate           = 0.10;   // Grid share of taken trades until measured
// EGKeepMargin: Bo'shatilgan filtr qaytadi - to'sganlari olinganlardan shuncha ko'p gridga borsa
input double EGKeepMargin            = 0.03;   // A relaxed filter returns at this much worse
// EGBreakerGridBaskets: Bo'sh filtr bilan ochilgan oxirgi 4 savatdan shunchasi gridga borsa ...
input int    EGBreakerGridBaskets    = 2;   // Breaker: grid baskets of the last 4 ...
// EGBreakerMinutes: ... barcha yumshatish shuncha daqiqa to'xtaydi
input int    EGBreakerMinutes        = 60;   // ... stop every relaxation for (min)
// EGSeedFromOwnerFiles: Birinchi ishga tushishda egasining soya fayllaridan (06-09 Oct) boshlang'ich dalil - kichraytirilgan, yangi natijalar tez almashtiradi
input bool   EGSeedFromOwnerFiles    = true;   // Start from the owner's measured shadow files (first run)
input bool   EGPrintOnUse            = true;   // Evidence gates print on use (on/off)

int      G_EG_N[EG_COUNT][2];          // refused results per key and side (0 with / neutral, 1 against)
int      G_EG_BAD[EG_COUNT][2];        // ... of them that needed the grid (or timed out)
int      G_EG_TK_N[2];                 // taken results per side
int      G_EG_TK_BAD[2];
bool     G_EG_RELAXED[EG_COUNT][2];
bool     G_EG_LOADED = false;
bool     G_EG_DIRTY  = false;
datetime G_EG_SAVE_BAR = 0;

string MBEGName(const int k)
{
   switch(k)
   {
      case EG_SCORE:     return "ball";
      case EG_JUDGE:     return "hakam";
      case EG_LOCATION:  return "joy";
      case EG_DRIFT:     return "drift";
      case EG_LATE:      return "kech";
      case EG_TAKEN:     return "olingan likv.";
      case EG_EXHAUST:   return "charchash";
      case EG_ZONEFRONT: return "oldidagi zona";
      case EG_NETEDGE:   return "TP joyi";
   }
   return "?";
}

string MBEGKey(const string f, const int k, const int a)
{
   return StringFormat("SIRUS_EG_%s_%I64d_%s%d_%d", _Symbol, MagicNumber, f, k, a);
}

void MBEGEvaluate(const int k, const int a)
{
   if(k < 0 || k >= EG_COUNT || a < 0 || a > 1)
      return;
   int n = G_EG_N[k][a];
   bool was = G_EG_RELAXED[k][a];
   bool now = false;
   if(n >= MathMax(10, EGMinSamples))
   {
      double r = (double)G_EG_BAD[k][a] / n;
      double base = (G_EG_TK_N[a] >= 20) ? (double)G_EG_TK_BAD[a] / G_EG_TK_N[a] : EGBaseBadRate;
      now = was ? (r <= base + EGKeepMargin) : (r <= base);
   }
   if(now != was)
   {
      G_EG_RELAXED[k][a] = now;
      if(EGPrintOnUse && G_EG_LOADED)
      {
         double base = (G_EG_TK_N[a] >= 20) ? (double)G_EG_TK_BAD[a] / G_EG_TK_N[a] : EGBaseBadRate;
         PrintFormat("[SIRUS EVIDENCE] %s (%s side): %s - its refusals needed the grid %.0f%% vs taken %.0f%% (n=%d)",
                     MBEGName(k), (a == 0 ? "bias" : "against-bias"), (now ? "STANDS ASIDE" : "WORKS AGAIN"),
                     (n > 0 ? 100.0 * G_EG_BAD[k][a] / n : 0.0), base * 100.0, n);
      }
   }
}

void MBEGLoad()
{
   if(G_EG_LOADED)
      return;
   bool persist = !MQLInfoInteger(MQL_TESTER);
   for(int a = 0; a < 2; a++)
   {
      G_EG_TK_N[a] = 0; G_EG_TK_BAD[a] = 0;
      if(persist && GlobalVariableCheck(MBEGKey("TN", 0, a))) G_EG_TK_N[a] = (int)GlobalVariableGet(MBEGKey("TN", 0, a));
      if(persist && GlobalVariableCheck(MBEGKey("TB", 0, a))) G_EG_TK_BAD[a] = (int)GlobalVariableGet(MBEGKey("TB", 0, a));
      for(int k = 0; k < EG_COUNT; k++)
      {
         G_EG_N[k][a] = 0; G_EG_BAD[k][a] = 0; G_EG_RELAXED[k][a] = false;
         if(persist && GlobalVariableCheck(MBEGKey("N", k, a))) G_EG_N[k][a] = (int)GlobalVariableGet(MBEGKey("N", k, a));
         if(persist && GlobalVariableCheck(MBEGKey("B", k, a))) G_EG_BAD[k][a] = (int)GlobalVariableGet(MBEGKey("B", k, a));
      }
   }
   // First run ever (nothing stored): start from the owner's shadow files of 06..09-Oct, scaled down to at
   // most 60 results per tally so the first new day of data outweighs them. Measured there:
   //   taken:          bias side 74 -> 12.2% needed the grid,  against-bias 60 -> 8.3%
   //   score refusals: bias side 452 -> 7.7%,                  against-bias 368 -> 9.2%
   //   location-family refusals, against-bias 64 -> 10.9%
   // Only the bias-side score filter starts aside; everything else is either worse than taken or unproven.
   if(EGSeedFromOwnerFiles && (!persist || !GlobalVariableCheck(MBEGKey("TN", 0, 0))))
   {
      G_EG_TK_N[0] = 60; G_EG_TK_BAD[0] = 7;
      G_EG_TK_N[1] = 60; G_EG_TK_BAD[1] = 5;
      G_EG_N[EG_SCORE][0] = 60;    G_EG_BAD[EG_SCORE][0] = 5;
      G_EG_N[EG_SCORE][1] = 60;    G_EG_BAD[EG_SCORE][1] = 6;
      G_EG_N[EG_LOCATION][1] = 60; G_EG_BAD[EG_LOCATION][1] = 7;
      G_EG_DIRTY = true;
   }
   for(int a = 0; a < 2; a++)
      for(int k = 0; k < EG_COUNT; k++)
         MBEGEvaluate(k, a);   // silent - G_EG_LOADED is still false
   G_EG_LOADED = true;
}

void MBEGSave()
{
   if(!G_EG_DIRTY || MQLInfoInteger(MQL_TESTER))
      return;
   G_EG_DIRTY = false;
   for(int a = 0; a < 2; a++)
   {
      GlobalVariableSet(MBEGKey("TN", 0, a), G_EG_TK_N[a]);
      GlobalVariableSet(MBEGKey("TB", 0, a), G_EG_TK_BAD[a]);
      for(int k = 0; k < EG_COUNT; k++)
      {
         GlobalVariableSet(MBEGKey("N", k, a), G_EG_N[k][a]);
         GlobalVariableSet(MBEGKey("B", k, a), G_EG_BAD[k][a]);
      }
   }
}

// Called where a quality filter WOULD block: true = it stands aside for this side now.
bool MBEGSkip(const int k, const int dir)
{
   if(!EnableEvidenceGates || k < 0 || k >= EG_COUNT || dir == 0)
      return false;
   if(TimeCurrent() < G_EG_BREAK_UNTIL || !G_EG_MKT_OK)
      return false;
   MBEGLoad();
   int a = (dir * G_MB_BIAS < 0) ? 1 : 0;
   if(!G_EG_RELAXED[k][a])
      return false;
   if(G_EG_RECORD)
      G_EG_SKIP_MASK |= (1 << k);
   return true;
}

// The evidence key of a refusal reason, -1 for a direction / hard gate (never relaxed).
int MBEGKeyOf(const string reason)
{
   if(StringLen(reason) == 0)
      return -1;
   if(StringFind(reason, "market brain veto: ") == 0)
   {
      string w = StringSubstr(reason, 19);
      if(StringFind(w, "V5 exhausted") == 0)                                   return EG_EXHAUST;
      if(StringFind(w, "V2 zone role") == 0 || StringFind(w, "V3 no room") == 0) return EG_ZONEFRONT;
      if(StringFind(w, "taken liquidity") == 0)                                return EG_TAKEN;
      if(StringFind(w, "exhaustion ") == 0)                                    return EG_EXHAUST;
      if(StringFind(w, "late entry") == 0)                                     return EG_LATE;
      if(StringFind(w, "net edge") == 0)                                       return EG_NETEDGE;
      if(StringFind(w, "council:") == 0 && StringFind(w, "holds right in front") >= 0) return EG_ZONEFRONT;
      return -1;
   }
   if(StringFind(reason, "entry judge") == 0)
      return EG_JUDGE;
   int g = GateClassify(reason);
   if(g == GATE_SCORE)                                              return EG_SCORE;
   if(g == GATE_LOCATION || g == GATE_ZONE || g == GATE_REGIME)     return EG_LOCATION;
   if(g == GATE_DRIFT)                                              return EG_DRIFT;
   return -1;
}

// A shadow resolved (26_Measure): refused under key ek, or taken with the keys in mask standing aside.
void MBEGFeed(const bool taken, const int ek, const int al, const int mask, const int outcome)
{
   if(!EnableEvidenceGates || outcome < 0)
      return;
   MBEGLoad();
   bool bad = (outcome == MB_SH_GRID || outcome == MB_SH_TIMEOUT);
   int a = (al == 1) ? 1 : 0;
   if(taken)
   {
      G_EG_TK_N[a]++;
      if(bad) G_EG_TK_BAD[a]++;
      if(G_EG_TK_N[a] >= 300) { G_EG_TK_N[a] /= 2; G_EG_TK_BAD[a] /= 2; }
      // The filters that stood aside for this entry: its result is exactly what their refusal would
      // have prevented - a relaxed filter keeps being measured.
      for(int k = 0; k < EG_COUNT; k++)
      {
         if((mask & (1 << k)) == 0)
            continue;
         G_EG_N[k][a]++;
         if(bad) G_EG_BAD[k][a]++;
         if(G_EG_N[k][a] >= 300) { G_EG_N[k][a] /= 2; G_EG_BAD[k][a] /= 2; }
      }
      for(int k = 0; k < EG_COUNT; k++)
         MBEGEvaluate(k, a);   // the baseline moved
   }
   else if(ek >= 0 && ek < EG_COUNT)
   {
      G_EG_N[ek][a]++;
      if(bad) G_EG_BAD[ek][a]++;
      if(G_EG_N[ek][a] >= 300) { G_EG_N[ek][a] /= 2; G_EG_BAD[ek][a] /= 2; }
      MBEGEvaluate(ek, a);
   }
   else
      return;
   G_EG_DIRTY = true;
}

// Every tick (a few comparisons): the market check, the open basket's depth, the save once per M1 bar.
void MBEGTick()
{
   if(!EnableEvidenceGates)
   {
      G_EG_MKT_OK = false;
      return;
   }
   MBEGLoad();
   string an = "";
   double norm = MBNormalSpread();
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   G_EG_MKT_OK = !(EnableEconomicCalendarGuard && G_CAL_ACTIVE) &&
                 TimeCurrent() > G_VEL_BLOCK_UNTIL &&
                 !MBAnomalyBlocks(an) &&
                 !(norm > 0.0 && spr > 1.5 * norm);
   if(G_EG_BASKET && G_BASKET_ORDERS > G_EG_BASKET_MAXORD)
      G_EG_BASKET_MAXORD = G_BASKET_ORDERS;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 > 0 && m1 != G_EG_SAVE_BAR)
   {
      G_EG_SAVE_BAR = m1;
      MBEGSave();
   }
}

// Circuit breaker - called by the Position Brain when a basket ends.
void MBEGBasketClosed()
{
   if(!G_EG_BASKET)
      return;
   G_EG_HIST[G_EG_HIST_POS] = (G_EG_BASKET_MAXORD >= 2) ? 1 : 0;
   G_EG_HIST_POS = (G_EG_HIST_POS + 1) % 4;
   G_EG_BASKET = false;
   G_EG_BASKET_MAXORD = 0;
   int bad = 0;
   for(int i = 0; i < 4; i++)
      if(G_EG_HIST[i] == 1) bad++;
   if(EnableEvidenceGates && bad >= MathMax(1, EGBreakerGridBaskets))
   {
      G_EG_BREAK_UNTIL = TimeCurrent() + MathMax(1, EGBreakerMinutes) * 60;
      G_EG_BREAK_WHY = StringFormat("oxirgi 4 savatdan %d tasi gridga bordi", bad);
      for(int i = 0; i < 4; i++) G_EG_HIST[i] = -1;
      PrintFormat("[SIRUS EVIDENCE] BREAKER: %d of the last 4 baskets entered with a relaxed filter needed the grid - every relaxation off for %d min",
                  bad, EGBreakerMinutes);
   }
}

// Panel line: which filters stand aside, per side.
string MBEGPanelText()
{
   if(!EnableEvidenceGates)
      return "";
   MBEGLoad();
   if(TimeCurrent() < G_EG_BREAK_UNTIL)
      return StringFormat("Filtr dalili: yumshatish to'xtatildi %d daq (%s)", (int)((G_EG_BREAK_UNTIL - TimeCurrent()) / 60) + 1, G_EG_BREAK_WHY);
   string side[2] = {"", ""};
   int learning = 0;
   for(int a = 0; a < 2; a++)
      for(int k = 0; k < EG_COUNT; k++)
      {
         if(G_EG_RELAXED[k][a])
            side[a] += (StringLen(side[a]) > 0 ? ", " : "") + MBEGName(k);
         else if(G_EG_N[k][a] > 0 && G_EG_N[k][a] < MathMax(10, EGMinSamples))
            learning++;
      }
   double base0 = (G_EG_TK_N[0] >= 20) ? 100.0 * G_EG_TK_BAD[0] / G_EG_TK_N[0] : EGBaseBadRate * 100.0;
   string t = StringFormat("Filtr dalili (olingan gridga %.0f%%): bias tomoni bo'sh: %s  ·  qarshi bo'sh: %s",
                           base0, (StringLen(side[0]) > 0 ? side[0] : "-"), (StringLen(side[1]) > 0 ? side[1] : "-"));
   if(learning > 0)
      t += StringFormat("  ·  o'rganilmoqda %d", learning);
   if(!G_EG_MKT_OK)
      t += "  ·  bozor noodatiy - yumshatish yo'q";
   return t;
}
