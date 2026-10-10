//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 12_Exits_Trailing                               |
//| Warnings, audits, basket close, exits, cashback trailing         |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

double HurstExponent()
{
   if(!EnableConfidenceScore)
      return 0.5;

   int lookback = MathMax(20, HurstLookbackBars);
   double returns[];
   ArrayResize(returns, lookback);

   int got = 0;
   for(int i = 0; i < lookback; i++)
   {
      double c1 = CandleClose(ConfidenceATRTF, i + 1);
      double c2 = CandleClose(ConfidenceATRTF, i + 2);
      if(c1 <= 0.0 || c2 <= 0.0)
         break;
      returns[i] = (c1 - c2) / c2 * 100.0;
      got++;
   }

   if(got < HurstMinChunkSize * 2)
      return 0.5;

   ArrayResize(returns, got);

   int n1 = MathMax(HurstMinChunkSize, got / 4);
   int n2 = MathMax(n1 + 1, got / 2);

   double rs1 = HurstRSForChunkSize(returns, got, n1);
   double rs2 = HurstRSForChunkSize(returns, got, n2);

   if(rs1 <= 0.0 || rs2 <= 0.0 || n1 == n2)
      return 0.5;

   double h = (MathLog(rs2) - MathLog(rs1)) / (MathLog((double)n2) - MathLog((double)n1));

   if(h < 0.0) h = 0.0;
   if(h > 1.0) h = 1.0;

   return h;
}

double HurstScore()
{
   double h = HurstExponent();
   double deviation = MathAbs(h - 0.5);
   double score = (deviation / 0.5) * 2.0 - 1.0;
   return MathMax(-1.0, MathMin(1.0, score));
}

// --- D2: Bayes per-detector performance. Tracks each opportunity type's own recent win rate,
// ============================================================================
// V153: CONFIDENCE CALIBRATION - does a "12" actually behave like a 12?
// ----------------------------------------------------------------------------
// The score engine states a conviction on every entry, and the lot sizing now acts
// on it. But nothing has ever checked whether the number means what it claims: if
// setups scoring 12 win 55% of the time while setups scoring 8 win 54%, then "12"
// is not conviction, it is decoration - and sizing up on it is sizing up on noise.
//
// This groups closed baskets by the score that opened them and tracks the outcome
// per band. The result answers a question the EA could not previously ask: is a
// higher score actually a better trade HERE, on this symbol, in this market?
//
// Two uses follow. The honest one is diagnostic - the dashboard can show whether
// the score is calibrated at all. The active one is sizing: conviction that the
// record does not support should not be backed with more capital.
// ============================================================================
// V155: WARNING RELIABILITY - which of the EA's own cautions are actually right?
// ----------------------------------------------------------------------------
// The EA now issues a dozen different warnings: late entry, no room, undefined
// zone role, structure against, liquidity ahead, crowded path, retail level,
// forced flow, chain disagrees, scenarios split, history disagrees. Each carries a
// penalty I chose by hand.
//
// Nobody has ever checked which of them are right. If baskets opened despite the
// "crowded path" warning lose 70% of the time, that warning is under-weighted and
// should be stopping more trades. If "retail level" baskets win as often as any
// other, that penalty is costing trades for nothing.
//
// So the EA records which warnings were present at entry, and when the basket
// closes, credits or discredits each one. Over time the penalties re-weight
// themselves toward the warnings this market actually respects.
//
// This is the mechanism behind three separate ideas: knowing WHY losses happen,
// remembering a pattern that has hurt before, and reviewing each basket after it
// closes. They are the same question asked once.
// ============================================================================

// (WARN_* defines live at the top of the file with the other structural defines)

// (G_ENTRY_WARNINGS is declared beside the other score-engine state, above its first use)
int    G_BASKET_WARNINGS     = 0;    // snapshot of the above, taken when a basket opens
int    G_BASKET_REGIME       = 0;    // V157: regime the current basket was opened in
// (G_NOISE_TP_FACTOR / G_PROJECTION_LOT_FACTOR / G_PROJECTION_MEASURING declared with the other
// score-engine state above, since the score engine and the lot engine both read them well before
// this point in the file.)
// V161: scale-in state. The first entry can be taken at part size and completed only once the
// market confirms it - so the EA is not fully committed to a setup it has no evidence for yet.
double G_WARN_RIGHT[WARN_COUNT];     // basket lost while this warning was present - the warning was right
double G_WARN_WRONG[WARN_COUNT];     // basket won despite it - the warning was wrong

string WarningName(const int w)
{
   switch(w)
   {
      case WARN_LATE_ENTRY:   return "late-entry";
      case WARN_NO_ROOM:      return "no-room";
      case WARN_ZONE_ROLE:    return "zone-role";
      case WARN_STRUCTURE:    return "structure";
      case WARN_LIQUIDITY:    return "liquidity";
      case WARN_PATH_CROWDED: return "crowded-path";
      case WARN_RETAIL_LEVEL: return "retail-level";
      case WARN_FORCED_FLOW:  return "forced-flow";
      case WARN_CHAIN:        return "chain";
      case WARN_UNDECIDED:    return "undecided";
      case WARN_HISTORY:      return "history";
   }
   return "?";
}

void MarkWarning(const int w)
{
   if(w >= 0 && w < WARN_COUNT)
      G_ENTRY_WARNINGS |= (1 << w);
}

string WarnGVKey(const string suffix, const int w)
{
   return StringFormat("NAVIUS_WARN_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, w);
}

void WarningStatsSave()
{
   if(!EnableWarningLearning)
      return;
   for(int w = 0; w < WARN_COUNT; w++)
   {
      GlobalVariableSet(WarnGVKey("R", w), G_WARN_RIGHT[w]);
      GlobalVariableSet(WarnGVKey("X", w), G_WARN_WRONG[w]);
   }
}

void WarningStatsRestore()
{
   for(int w = 0; w < WARN_COUNT; w++)
   {
      G_WARN_RIGHT[w] = 0.0;
      G_WARN_WRONG[w] = 0.0;
   }
   if(!EnableWarningLearning)
      return;
   for(int w = 0; w < WARN_COUNT; w++)
   {
      string kr = WarnGVKey("R", w);
      string kx = WarnGVKey("X", w);
      if(GlobalVariableCheck(kr)) G_WARN_RIGHT[w] = GlobalVariableGet(kr);
      if(GlobalVariableCheck(kx)) G_WARN_WRONG[w] = GlobalVariableGet(kx);
   }
}

// Credits every warning that was present when this basket opened.
void WarningRecordOutcome(const int warnings_mask, const bool won)
{
   if(!EnableWarningLearning || warnings_mask == 0)
      return;

   string touched = "";
   for(int w = 0; w < WARN_COUNT; w++)
   {
      if((warnings_mask & (1 << w)) == 0)
         continue;

      if(won) G_WARN_WRONG[w] += 1.0;    // we traded past it and it worked out
      else    G_WARN_RIGHT[w] += 1.0;    // we traded past it and paid for it

      double total = G_WARN_RIGHT[w] + G_WARN_WRONG[w];
      if(WarningLearningMaxSamples > 0 && total > (double)WarningLearningMaxSamples)
      {
         double scale = (double)WarningLearningMaxSamples / total;
         G_WARN_RIGHT[w] *= scale;
         G_WARN_WRONG[w] *= scale;
      }
      touched += WarningName(w) + " ";
   }

   WarningStatsSave();

   if((WarningLearningPrintOnUse && G_VERBOSE) && StringLen(touched) > 0)
      PrintFormat("[SIRUS v155 WARNINGS] basket %s - credited: %s",
                  (won ? "WON" : "LOST"), touched);
}

// Multiplier for a warning's penalty, based on how often it has been right.
// Returns 1.0 until there is enough evidence to justify moving it.
double WarningWeight(const int w)
{
   if(!EnableWarningLearning || w < 0 || w >= WARN_COUNT)
      return 1.0;

   double right = G_WARN_RIGHT[w];
   double wrong = G_WARN_WRONG[w];
   double total = right + wrong;
   if(total < (double)WarningLearningMinSamples)
      return 1.0;

   double accuracy = right / total;     // share of times trading past it hurt

   // Below the neutral point the warning has been crying wolf; above it, it has
   // been catching real trouble. Scale gently - this adjusts emphasis, it does not
   // hand the warning system over to a small sample.
   double delta = (accuracy - WarningNeutralAccuracy) / MathMax(0.01, 1.0 - WarningNeutralAccuracy);
   double mult = 1.0 + delta * MathMax(0.0, WarningWeightRange);
   return MathMax(WarningWeightMin, MathMin(WarningWeightMax, mult));
}

// Applies a warning's learned weight to its configured penalty.
int WeightedPenalty(const int w, const int base_penalty)
{
   if(!EnableWarningLearning)
      return base_penalty;
   MarkWarning(w);
   return (int)MathRound((double)base_penalty * WarningWeight(w));
}

string WarningReliabilityText()
{
   if(!EnableWarningLearning)
      return "";
   string out = "warnings:";
   bool any = false;
   for(int w = 0; w < WARN_COUNT; w++)
   {
      double total = G_WARN_RIGHT[w] + G_WARN_WRONG[w];
      if(total < 1.0)
         continue;
      any = true;
      out += StringFormat(" %s=%.0f%%(%.0f)", WarningName(w),
                          (G_WARN_RIGHT[w] / total) * 100.0, total);
   }
   return any ? out : "warnings: no history yet";
}

// ============================================================================
// V157: BLOCKED-TRADE AUDIT + REGIME PERFORMANCE
// ----------------------------------------------------------------------------
// Two blind spots, both about evidence the EA throws away.
//
// FIRST - every hard block is an untested hypothesis. Thirteen of them now refuse
// entries, and nobody knows which are right. A block that would have been a losing
// trade saved money; a block that would have won cost money. Both look identical
// from inside the EA, because the trade never existed. Recording the refusal and
// checking where price went afterwards is the only way to find out.
//
// SECOND - the EA can now name its regime, which makes a question askable that was
// not before: is there a market state where this system simply does not work? Not
// "which entry was bad" but "should I be trading at all right now". A strategy that
// loses consistently in one regime and wins in the others should stand aside there,
// and the record is what proves it.
//
// Neither changes behaviour on its own. They produce the evidence a later decision
// can rest on - and, more immediately, they replace guesswork with numbers on the
// dashboard.
// ============================================================================

// (BLOCK_AUDIT_SLOTS lives at the top of the file with the other structural defines)

int      G_BA_DIR[BLOCK_AUDIT_SLOTS];
int      G_BA_BAR[BLOCK_AUDIT_SLOTS];
double   G_BA_PRICE[BLOCK_AUDIT_SLOTS];
int      G_BA_ACTIVE = 0;                 // pending refusals awaiting a verdict
double   G_BA_SAVED = 0.0;                // blocks where price went against the refused entry
double   G_BA_COST  = 0.0;                // blocks where the refused entry would have worked

// Regime performance: closed-basket outcomes per regime.
double   G_REGIME_WINS[5];
double   G_REGIME_LOSSES[5];

string BlockAuditGVKey(const string suffix)
{
   return StringFormat("NAVIUS_BLOCKAUDIT_%s_%d_%s", _Symbol, MagicNumber, suffix);
}

string RegimePerfGVKey(const string suffix, const int r)
{
   return StringFormat("NAVIUS_REGIMEPERF_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, r);
}

void BlockAuditSave()
{
   if(!EnableBlockAudit)
      return;
   GlobalVariableSet(BlockAuditGVKey("SAVED"), G_BA_SAVED);
   GlobalVariableSet(BlockAuditGVKey("COST"),  G_BA_COST);
}

void RegimePerfSave()
{
   if(!EnableRegimePerformance)
      return;
   for(int r = 0; r < 5; r++)
   {
      GlobalVariableSet(RegimePerfGVKey("W", r), G_REGIME_WINS[r]);
      GlobalVariableSet(RegimePerfGVKey("L", r), G_REGIME_LOSSES[r]);
   }
}

void BlockAuditRestore()
{
   G_BA_SAVED = 0.0;
   G_BA_COST  = 0.0;
   G_BA_ACTIVE = 0;
   for(int i = 0; i < BLOCK_AUDIT_SLOTS; i++)
   {
      G_BA_DIR[i] = 0; G_BA_BAR[i] = 0; G_BA_PRICE[i] = 0.0;
   }
   for(int r = 0; r < 5; r++)
   {
      G_REGIME_WINS[r] = 0.0;
      G_REGIME_LOSSES[r] = 0.0;
   }

   if(EnableBlockAudit)
   {
      if(GlobalVariableCheck(BlockAuditGVKey("SAVED"))) G_BA_SAVED = GlobalVariableGet(BlockAuditGVKey("SAVED"));
      if(GlobalVariableCheck(BlockAuditGVKey("COST")))  G_BA_COST  = GlobalVariableGet(BlockAuditGVKey("COST"));
   }
   if(EnableRegimePerformance)
   {
      for(int r = 0; r < 5; r++)
      {
         string kw = RegimePerfGVKey("W", r);
         string kl = RegimePerfGVKey("L", r);
         if(GlobalVariableCheck(kw)) G_REGIME_WINS[r]   = GlobalVariableGet(kw);
         if(GlobalVariableCheck(kl)) G_REGIME_LOSSES[r] = GlobalVariableGet(kl);
      }
   }
}

// Records a refused entry so it can be judged later.
void BlockAuditRecord(const int dir, const double price)
{
   if(!EnableBlockAudit || dir == 0 || price <= 0.0)
      return;
   if(G_BA_ACTIVE >= BLOCK_AUDIT_SLOTS)
      return;                                  // queue full - skip rather than overwrite

   // Ignore a repeat of a refusal already pending: the same setup being refused on
   // consecutive bars is one decision, not several.
   for(int i = 0; i < G_BA_ACTIVE; i++)
      if(G_BA_DIR[i] == dir && (G_BARS_SEEN - G_BA_BAR[i]) < MathMax(1, BlockAuditDedupeBars))
         return;

   G_BA_DIR[G_BA_ACTIVE]   = dir;
   G_BA_BAR[G_BA_ACTIVE]   = G_BARS_SEEN;
   G_BA_PRICE[G_BA_ACTIVE] = price;
   G_BA_ACTIVE++;
}

// Judges refusals whose horizon has passed.
void BlockAuditSettle()
{
   if(!EnableBlockAudit || G_BA_ACTIVE <= 0 || _Point <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   int write = 0;
   for(int i = 0; i < G_BA_ACTIVE; i++)
   {
      if((G_BARS_SEEN - G_BA_BAR[i]) < MathMax(2, BlockAuditHorizonBars))
      {
         // still pending - keep it
         G_BA_DIR[write]   = G_BA_DIR[i];
         G_BA_BAR[write]   = G_BA_BAR[i];
         G_BA_PRICE[write] = G_BA_PRICE[i];
         write++;
         continue;
      }

      double moved = (mid - G_BA_PRICE[i]) / _Point * (double)G_BA_DIR[i];

      if(moved <= -(double)BlockAuditDecisivePoints)
      {
         G_BA_SAVED += 1.0;      // the refused entry would have gone straight into loss
         if((BlockAuditPrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v157 BLOCK AUDIT] block was RIGHT (%.0f pts against) | saved=%.0f cost=%.0f",
                        -moved, G_BA_SAVED, G_BA_COST);
      }
      else if(moved >= (double)BlockAuditDecisivePoints)
      {
         G_BA_COST += 1.0;       // it would have worked - the block cost us
         if((BlockAuditPrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v157 BLOCK AUDIT] block was WRONG (%.0f pts in favour) | saved=%.0f cost=%.0f",
                        moved, G_BA_SAVED, G_BA_COST);
      }
      // Inconclusive moves teach nothing and are discarded.
   }
   G_BA_ACTIVE = write;

   double total = G_BA_SAVED + G_BA_COST;
   if(BlockAuditMaxSamples > 0 && total > (double)BlockAuditMaxSamples)
   {
      double scale = (double)BlockAuditMaxSamples / total;
      G_BA_SAVED *= scale;
      G_BA_COST  *= scale;
   }

   BlockAuditSave();
}

void RegimeRecordOutcome(const int regime, const bool won)
{
   if(!EnableRegimePerformance || regime < 0 || regime >= 5)
      return;

   if(won) G_REGIME_WINS[regime]   += 1.0;
   else    G_REGIME_LOSSES[regime] += 1.0;

   double total = G_REGIME_WINS[regime] + G_REGIME_LOSSES[regime];
   if(RegimePerfMaxSamples > 0 && total > (double)RegimePerfMaxSamples)
   {
      double scale = (double)RegimePerfMaxSamples / total;
      G_REGIME_WINS[regime]   *= scale;
      G_REGIME_LOSSES[regime] *= scale;
   }
   RegimePerfSave();
}

// Win rate in a regime, or -1 without enough evidence.
double RegimeWinRate(const int regime, int &samples)
{
   samples = 0;
   if(!EnableRegimePerformance || regime < 0 || regime >= 5)
      return -1.0;
   double total = G_REGIME_WINS[regime] + G_REGIME_LOSSES[regime];
   samples = (int)MathRound(total);
   if(total < (double)RegimePerfMinSamples)
      return -1.0;
   return G_REGIME_WINS[regime] / total;
}

string BlockAuditText()
{
   if(!EnableBlockAudit)
      return "";
   double total = G_BA_SAVED + G_BA_COST;
   if(total < 1.0)
      return "blocks: no verdicts yet";
   return StringFormat("blocks: %.0f%% right (%.0f saved / %.0f cost)",
                       (G_BA_SAVED / total) * 100.0, G_BA_SAVED, G_BA_COST);
}

string RegimePerfText()
{
   if(!EnableRegimePerformance)
      return "";
   string out = "by regime:";
   bool any = false;
   // FIX(regime-0-hidden): was `r = 1`, skipping regime 0 (REGIME_UNKNOWN). RegimeRecordOutcome()
   // and RegimeWinRate() both accept and track regime 0 like any other (their guard is
   // `regime < 0 || regime >= 5`), and RegimeName(0) already returns a real label ("UNKNOWN") for
   // it - so outcomes were being recorded into a bucket the dashboard could never actually show.
   for(int r = 0; r < 5; r++)
   {
      double total = G_REGIME_WINS[r] + G_REGIME_LOSSES[r];
      if(total < 1.0)
         continue;
      any = true;
      out += StringFormat(" %s=%.0f%%(%.0f)", RegimeName(r),
                          (G_REGIME_WINS[r] / total) * 100.0, total);
   }
   return any ? out : "by regime: no closed baskets yet";
}

// ============================================================================

// (SCORE_BAND_COUNT lives at the top of the file with the other structural defines)

double G_SCORE_BAND_WINS[SCORE_BAND_COUNT];
double G_SCORE_BAND_LOSSES[SCORE_BAND_COUNT];
int    G_BASKET_OPENING_SCORE = 0;   // score that opened the current basket
int    G_BASKET_OPENING_MARGIN = 0;  // V249fix(auto-mode): and how far ABOVE its bar it was - the mode-invariant quality measure the score bands learn from

// Bands are coarse on purpose: fine buckets would take years to fill, and the
// question is whether the score ORDERS trades correctly, not its exact value.
// V249fix(auto-mode): banded by MARGIN ABOVE THE BAR, not by absolute score.
// AUTO moves the bar itself (MinScoreHighHunter 2 vs MinScoreBalanced 4) and Hunter also collects a
// mode bonus, so an absolute score meant two different things depending on which mode produced it -
// and both were recorded in the SAME bucket. Band 0 held Hunter trades that scraped past a bar of 2
// alongside Balanced trades that cleared a bar of 4 with room: two unrelated populations averaged
// into one win rate, which then fed BACK into both modes through EnableCalibratedLotSizing and
// ScaleInAdaptiveFraction. Under AUTO that cross-contamination is guaranteed, not incidental.
// Margin is mode-invariant by construction, so one set of buckets stays valid for both modes and
// learns twice as fast as a mode-keyed split would. Boundaries chosen to reproduce the old
// granularity at the Balanced bar (bar 5: old <=6 == margin <=1, 7-9 == 2-4, and so on).
int ScoreBandIndex(const int margin_above_bar)
{
   if(margin_above_bar <  0)  return -1;
   if(margin_above_bar <= 1)  return 0;   // scraped in
   if(margin_above_bar <= 4)  return 1;
   if(margin_above_bar <= 7)  return 2;
   if(margin_above_bar <= 10) return 3;
   return 4;                              // exceptional
}

string ScoreBandName(const int band)
{
   switch(band)
   {
      case 0: return "+0-1";
      case 1: return "+2-4";
      case 2: return "+5-7";
      case 3: return "+8-10";
      case 4: return "+11 and up";
   }
   return "?";
}

string ScoreBandGVKey(const string suffix, const int band)
{
   // V249fix(auto-mode): key version bumped to M2 - the bands now hold MARGIN, not absolute
   // score, so previously stored counts describe a different scale and must not be reused.
   return StringFormat("NAVIUS_SCOREBANDM2_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, band);
}

void ScoreBandSave()
{
   if(!EnableScoreCalibration)
      return;
   for(int b = 0; b < SCORE_BAND_COUNT; b++)
   {
      GlobalVariableSet(ScoreBandGVKey("W", b), G_SCORE_BAND_WINS[b]);
      GlobalVariableSet(ScoreBandGVKey("L", b), G_SCORE_BAND_LOSSES[b]);
   }
}

void ScoreBandRestore()
{
   for(int b = 0; b < SCORE_BAND_COUNT; b++)
   {
      G_SCORE_BAND_WINS[b]   = 0.0;
      G_SCORE_BAND_LOSSES[b] = 0.0;
   }
   if(!EnableScoreCalibration)
      return;

   for(int b = 0; b < SCORE_BAND_COUNT; b++)
   {
      string kw = ScoreBandGVKey("W", b);
      string kl = ScoreBandGVKey("L", b);
      if(GlobalVariableCheck(kw)) G_SCORE_BAND_WINS[b]   = GlobalVariableGet(kw);
      if(GlobalVariableCheck(kl)) G_SCORE_BAND_LOSSES[b] = GlobalVariableGet(kl);
   }
}

void ScoreBandRecordOutcome(const int score, const bool won)
{
   if(!EnableScoreCalibration)
      return;
   int band = ScoreBandIndex(score);
   if(band < 0)
      return;

   if(won) G_SCORE_BAND_WINS[band]   += 1.0;
   else    G_SCORE_BAND_LOSSES[band] += 1.0;

   // Decay so the record reflects how the score behaves NOW, not how it behaved
   // under a different set of filters months ago.
   double total = G_SCORE_BAND_WINS[band] + G_SCORE_BAND_LOSSES[band];
   if(ScoreCalibrationMaxSamples > 0 && total > (double)ScoreCalibrationMaxSamples)
   {
      double scale = (double)ScoreCalibrationMaxSamples / total;
      G_SCORE_BAND_WINS[band]   *= scale;
      G_SCORE_BAND_LOSSES[band] *= scale;
   }

   ScoreBandSave();

   if((ScoreCalibrationPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v153 CALIBRATION] band %s: %s | now %.0f/%.0f",
                  ScoreBandName(band), (won ? "WIN" : "LOSS"),
                  G_SCORE_BAND_WINS[band], G_SCORE_BAND_LOSSES[band]);
}

// Measured win rate for a score, or -1 when there is not enough evidence yet.
double ScoreBandWinRate(const int score, int &samples)
{
   samples = 0;
   if(!EnableScoreCalibration)
      return -1.0;
   int band = ScoreBandIndex(score);
   if(band < 0)
      return -1.0;

   double total = G_SCORE_BAND_WINS[band] + G_SCORE_BAND_LOSSES[band];
   samples = (int)MathRound(total);
   if(total < (double)ScoreCalibrationMinSamples)
      return -1.0;

   return G_SCORE_BAND_WINS[band] / total;
}

// Dashboard summary: whether higher scores are actually performing better.
string ScoreCalibrationText()
{
   if(!EnableScoreCalibration)
      return "";

   string out = "calibration:";
   bool any = false;
   for(int b = 0; b < SCORE_BAND_COUNT; b++)
   {
      double total = G_SCORE_BAND_WINS[b] + G_SCORE_BAND_LOSSES[b];
      if(total < 1.0)
         continue;
      any = true;
      out += StringFormat(" %s=%.0f%%(%.0f)", ScoreBandName(b),
                          (G_SCORE_BAND_WINS[b] / total) * 100.0, total);
   }
   return any ? out : "calibration: no closed baskets yet";
}

// with older outcomes fading out via a rolling-window decay (no per-trade array needed). ---
void BayesRecordOutcome(const int opp_type, const bool won)
{
   if(opp_type < 0 || opp_type >= SIRUS_OPP_TYPE_COUNT)
      return;

   if(won)
      G_BAYES_WINS[opp_type] += 1.0;
   else
      G_BAYES_LOSSES[opp_type] += 1.0;

   double total = G_BAYES_WINS[opp_type] + G_BAYES_LOSSES[opp_type];
   if(total > BayesMaxSampleWindow)
   {
      double scale = (double)BayesMaxSampleWindow / total;
      G_BAYES_WINS[opp_type]   *= scale;
      G_BAYES_LOSSES[opp_type] *= scale;
   }

   BayesSaveState(); // V30.2 new: persist learning across restarts/recompiles
}

// --- V30.2 new: BAYES PERSISTENCE ---
// Old behaviour: G_BAYES_WINS/LOSSES lived only in memory, so every restart,
// recompile or VPS reboot wiped everything the EA had learned about which
// detectors actually win. Terminal GlobalVariables survive all of those.
string BayesGVKey(const string suffix, const int idx)
{
   return StringFormat("NAVIUS_%I64d_%s_%s_%d", MagicNumber, _Symbol, suffix, idx);
}

void BayesSaveState()
{
   if(!EnablePersistentState)
      return;
   for(int i = 0; i < SIRUS_OPP_TYPE_COUNT; i++)
   {
      GlobalVariableSet(BayesGVKey("BW", i), G_BAYES_WINS[i]);
      GlobalVariableSet(BayesGVKey("BL", i), G_BAYES_LOSSES[i]);
   }
}

void BayesLoadState()
{
   if(!EnablePersistentState)
      return;
   int restored = 0;
   for(int i = 0; i < SIRUS_OPP_TYPE_COUNT; i++)
   {
      string kw = BayesGVKey("BW", i);
      string kl = BayesGVKey("BL", i);
      if(GlobalVariableCheck(kw)) { G_BAYES_WINS[i]   = GlobalVariableGet(kw); restored++; }
      if(GlobalVariableCheck(kl)) { G_BAYES_LOSSES[i] = GlobalVariableGet(kl); restored++; }
   }

   // V31.6b: restore worst-DD statistics and Smart Zone Recovery state, so a VPS reboot or
   // recompile can neither wipe the dashboard's "Worst" stat nor re-arm the SZR one-shot.
   string k_maxdd  = StringFormat("NAVIUS_%I64d_%s_MAXDD",  MagicNumber, _Symbol);
   string k_maxddd = StringFormat("NAVIUS_%I64d_%s_MAXDDD", MagicNumber, _Symbol);
   string k_szru   = StringFormat("NAVIUS_%I64d_%s_SZRUSED", MagicNumber, _Symbol);
   string k_szre   = StringFormat("NAVIUS_%I64d_%s_SZRESC",  MagicNumber, _Symbol);
   if(GlobalVariableCheck(k_maxdd))  { G_ALL_TIME_MAX_DD_PCT       = GlobalVariableGet(k_maxdd);  restored++; }
   if(GlobalVariableCheck(k_maxddd)) { G_ALL_TIME_MAX_DAILY_DD_PCT = GlobalVariableGet(k_maxddd); restored++; }
   if(GlobalVariableCheck(k_szru))   { G_SZR_USES_THIS_EPISODE = (int)MathMax(0.0, MathRound(GlobalVariableGet(k_szru))); restored++; }
   if(GlobalVariableCheck(k_szre))   { G_SZR_ESCAPE_MODE       = (GlobalVariableGet(k_szre) > 0.5); restored++; }

   if(restored > 0)
      PrintFormat("[SIRUS v30.2 PERSIST] Bayes state restored: %d values", restored);
}

// V30.2 new: persist post-loss cooldown so a restart cannot be used to skip it.
void PostLossCooldownSave()
{
   if(!EnablePersistentState)
      return;
   GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_PLC", MagicNumber, _Symbol),
                     (double)G_POST_LOSS_COOLDOWN_UNTIL);
}

void PostLossCooldownLoad()
{
   if(!EnablePersistentState)
      return;
   string key = StringFormat("NAVIUS_%I64d_%s_PLC", MagicNumber, _Symbol);
   if(!GlobalVariableCheck(key))
      return;
   datetime until = (datetime)GlobalVariableGet(key);
   if(until > TimeCurrent())
   {
      G_POST_LOSS_COOLDOWN_UNTIL = until;
      PrintFormat("[SIRUS v30.2 PERSIST] Post-loss cooldown restored until %s", TimeToString(until));
   }
}

double BayesWinRate(const int opp_type)
{
   if(opp_type < 0 || opp_type >= SIRUS_OPP_TYPE_COUNT)
      return 0.5;

   double total = G_BAYES_WINS[opp_type] + G_BAYES_LOSSES[opp_type];
   if(total < BayesMinSamples)
      return 0.5;

   double raw_wr = G_BAYES_WINS[opp_type] / total;

   // V31.6z48 fix: real statistical weakness found via deep audit - despite the name, this was
   // NOT Bayesian at all. Sample count acted as a pure on/off gate: hit BayesMinSamples and the
   // raw win rate was trusted at 100% face value, one sample short and it was ignored entirely.
   // So 10 samples at 70% and 200 samples at 70% were treated as EQUALLY reliable, and 9
   // samples at 90% counted for nothing. This applies genuine Bayesian shrinkage: pull the
   // observed rate toward the 0.5 prior in proportion to how little evidence backs it, so
   // confidence grows smoothly and honestly with sample size instead of jumping at a cliff.
   if(!EnableBayesShrinkage)
      return raw_wr;

   double k = MathMax(1.0, BayesShrinkageStrength);
   double shrunk = (G_BAYES_WINS[opp_type] + 0.5 * k) / (total + k);

   return MathMax(0.0, MathMin(1.0, shrunk));
}

double BayesScore(const int opp_type)
{
   double wr = BayesWinRate(opp_type);
   double score = (wr - 0.5) * 4.0;
   return MathMax(-1.0, MathMin(1.0, score));
}

// FEATURE(bayes-auto-disable): total closed-trade sample count for a detector type.
double BayesSampleCount(const int opp_type)
{
   if(opp_type < 0 || opp_type >= SIRUS_OPP_TYPE_COUNT)
      return 0.0;
   return G_BAYES_WINS[opp_type] + G_BAYES_LOSSES[opp_type];
}

// FEATURE(bayes-auto-disable): true if this detector type has PROVEN itself a loser over a
// real sample and should stop trading. Deliberately conservative - it needs both a large
// enough sample AND a win rate clearly on the wrong side of 0.5 before it silences a detector.
// This raises overall quality; it never adds trades. Reuses the same shrunk win rate the rest
// of the Bayes system trusts, so it can't be fooled by a tiny lucky/unlucky streak.
bool BayesDetectorDisabled(const int opp_type)
{
   if(!EnableBayesAutoDisable)
      return false;
   if(opp_type <= 0 || opp_type >= SIRUS_OPP_TYPE_COUNT)   // never disable OPP_TYPE_NONE(0)
      return false;

   double samples = BayesSampleCount(opp_type);
   if(samples < BayesAutoDisableMinSamples)
      return false;   // not enough evidence yet - let it keep trading and learning

   double wr = BayesWinRate(opp_type);
   return (wr <= BayesAutoDisableWinrate);
}

// --- Combined: one averaged score, one final lot multiplier. ---
double MarketConfidenceLotAdjust(const double lot, const int opp_type)
{
   if(!EnableConfidenceScore)
      return lot;

   double vol_score    = VolatilityRegimeScore();
   double bayes_score  = BayesScore(opp_type);
   double hurst_score  = HurstScore();
   double avg_score    = (vol_score + bayes_score + hurst_score) / 3.0;

   double mid        = (ConfidenceMaxLotMultiplier + ConfidenceMinLotMultiplier) / 2.0;
   double half_range = (ConfidenceMaxLotMultiplier - ConfidenceMinLotMultiplier) / 2.0;
   double multiplier = mid + avg_score * half_range;

   if((ConfidencePrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v29 CONFIDENCE] vol=%.2f bayes=%.2f hurst=%.2f avg=%.2f -> lot x%.2f",
                  vol_score, bayes_score, hurst_score, avg_score, multiplier);

   return lot * multiplier;
}


// V31.6z23 NEW: INDEPENDENT EMERGENCY FORCE-CLOSE. Found via user report - a basket exceeded
// 50% DD (confirmed by the user's own manual calculation) yet did NOT close, despite BOTH
// existing safety layers (BasketSL via CheckBasketExit/GetSirusBasketStats, and Emergency/
// Equity DD via UpdateRiskEngine/RiskHardBlockCheck) appearing structurally correct on review.
// Rather than continue chasing a possibly rare, hard-to-reproduce edge case in either chain,
// this is a genuinely INDEPENDENT, minimal-dependency safety net: it scans positions directly
// (no reliance on GetSirusBasketStats' aggregation logic or on G_RISK_EQUITY_DD_PCT being
// fresh from a separate function), includes swap, and force-closes on its own. Designed to be
// the simplest possible correct implementation - the last line of defense.
void EmergencyBasketForceCloseCheck()
{
   if(!EnableEmergencyForceClose)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return;

   double total_floating = 0.0;
   int position_count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      total_floating += SelectedPositionNetProfit();   // FIX(dd-commission)
      position_count++;
   }

   // FIX(dd-warning-not-reset): G_LAST_DD_WARNING_LEVEL used to only reset on a full basket-state
   // reset (basket close / OnInit), never here when the SAME open basket floats back to profit or
   // breakeven and then drops into drawdown again. That meant a real, later DD episode that only
   // reached a threshold already notified earlier in this basket's life (even after a full
   // recovery in between) fired no push at all - exactly the "DD climbing toward danger while it's
   // happening" case this feature exists to catch. Reset it here so a fresh slide into drawdown
   // after a real recovery starts warning again from the lowest threshold.
   if(position_count <= 0 || total_floating >= 0.0)
   {
      G_LAST_DD_WARNING_LEVEL = 0.0;
      return;
   }

   double dd_pct = MathAbs(total_floating) / balance * 100.0;

   // V31.6z45 NEW: real operational gap found via due-diligence review, directly connected to
   // a real incident earlier this session - the ONLY push notification that existed fired when
   // a basket CLOSED. Nothing proactively told the operator that DD was climbing toward danger
   // WHILE it was still happening - exactly the situation where the user only found out by
   // manually checking. Fires ONCE per threshold crossed (not every tick), reusing the same
   // cheap DD computation this function already does independently every tick.
   if(EnableDDWarningPush && dd_pct > 0.0)
   {
      double thresholds[3] = {DDWarningThreshold3, DDWarningThreshold2, DDWarningThreshold1};
      for(int wi = 0; wi < 3; wi++)
      {
         if(thresholds[wi] > 0.0 && dd_pct >= thresholds[wi] && G_LAST_DD_WARNING_LEVEL < thresholds[wi])
         {
            SirusNotify(StringFormat("DD WARNING: basket at %.1f%% (crossed %.0f%% threshold, floating=%.2f)",
                                      dd_pct, thresholds[wi], total_floating));
            G_LAST_DD_WARNING_LEVEL = thresholds[wi];
            break;
         }
      }
   }

   if(dd_pct >= EmergencyForceCloseDDPercent)
   {
      PrintFormat("[SIRUS v31.6z23 EMERGENCY FORCE CLOSE] Independent safety net triggered: DD=%.2f%% >= %.2f%% (floating=%.2f, balance=%.2f, positions=%d)",
                  dd_pct, EmergencyForceCloseDDPercent, total_floating, balance, position_count);
      CloseSirusBasket(StringFormat("EMERGENCY FORCE CLOSE (independent) DD %.2f%%/%.2f%%", dd_pct, EmergencyForceCloseDDPercent));
   }
}

// FEATURE(close-markers): turn a verbose close reason into a short, human-readable tag for the
// chart marker and deal comment. Order matters - the more specific words are checked first.
string BasketCloseTag(const string reason)
{
   string r = reason;
   StringToLower(r);

   if(StringFind(r, "trail") >= 0)               return "TRAIL";
   if(StringFind(r, "break-even") >= 0 ||
      StringFind(r, "breakeven") >= 0 ||
      StringFind(r, "be lock") >= 0 ||
      StringFind(r, "be+") >= 0)                  return "BE";
   if(StringFind(r, "smart zone") >= 0 ||
      StringFind(r, "szr") >= 0)                  return "SZR";
   if(StringFind(r, "emergency") >= 0)            return "EMERG";
   if(StringFind(r, "disaster") >= 0)             return "DISASTER";
   if(StringFind(r, "news") >= 0)                 return "NEWS";
   if(StringFind(r, "weekend") >= 0)              return "WEEKEND";
   if(StringFind(r, "smart exit") >= 0)           return "EXIT";
   if(StringFind(r, "risk") >= 0)                 return "RISK";
   if(StringFind(r, "sl") >= 0 ||
      StringFind(r, "stop") >= 0)                 return "SL";
   if(StringFind(r, "tp") >= 0 ||
      StringFind(r, "take profit") >= 0 ||
      StringFind(r, "target") >= 0)               return "TP";
   return "CLOSE";
}

// FEATURE(close-markers): draw a chart arrow (check for a win, cross for a loss) plus a small text
// tag at the price the basket closed. Objects use a dedicated prefix so they are NOT removed by the
// dashboard cleanup or on OnDeinit, leaving a permanent visual trail of every basket outcome.
void DrawBasketCloseMarker(const string reason, const double profit)
{
   if(!EnableCloseMarkers || TesterHeadless())   // TESTER: markers pile up with no chart to show them
      return;

   bool win = (profit >= 0.0);
   string tag = BasketCloseTag(reason);
   datetime t = TimeCurrent();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
      return;

   string base = G_PREFIX + "CLOSE_" + IntegerToString((int)t);
   string arrow_name = base + "_M";
   string text_name  = base + "_T";
   color  col = win ? CloseMarkerProfitColor : CloseMarkerLossColor;

   // Wingdings 252 = check mark, 251 = cross.
   if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, t, price))
   {
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, win ? 252 : 251);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrow_name, OBJPROP_ANCHOR, win ? ANCHOR_BOTTOM : ANCHOR_TOP);
      ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, arrow_name, OBJPROP_HIDDEN, true);
   }

   string label = StringFormat("%s %.0f$", tag, profit);
   if(ObjectCreate(0, text_name, OBJ_TEXT, 0, t, price))
   {
      ObjectSetString(0, text_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, MathMax(6, CloseMarkerFontSize));
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, win ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
   }
}

// FIX(partial-close-deviation): partial closes inherited the 50-point ENTRY deviation from the shared
// CTrade object and their result was never checked - a requote silently trimmed nothing (or only some
// positions) while the stage counter moved on. They are exits, so they use the exit allowance, and a
// refusal is logged.
bool BasketPartialClose(const ulong ticket, const double volume)
{
   G_TRADE.SetExpertMagicNumber(MagicNumber);
   G_TRADE.SetTypeFillingBySymbol(_Symbol);
   G_TRADE.SetDeviationInPoints((ulong)MathMax(OrderSendDeviationPoints, CloseDeviationPoints));
   bool sent = G_TRADE.PositionClosePartial(ticket, volume);
   uint rc = G_TRADE.ResultRetcode();
   G_TRADE.SetDeviationInPoints((ulong)MathMax(0, OrderSendDeviationPoints));   // restore the entry cap
   bool ok = sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED);
   if(!ok)
      PrintFormat("[SIRUS PARTIAL CLOSE FAILED] ticket=%I64u vol=%.2f | ret=%d %s",
                  ticket, volume, (int)rc, G_TRADE.ResultRetcodeDescription());
   return ok;
}

// Which close refusals are worth another attempt within the same call.
bool CloseRetcodeIsRetryable(const uint rc)
{
   switch(rc)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_REJECT:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_ERROR:
      case TRADE_RETCODE_LOCKED:
      case TRADE_RETCODE_DONE_PARTIAL:
      case TRADE_RETCODE_INVALID_FILL:
         return true;
   }
   return false;
}

bool CloseSirusBasket(const string reason)
{
   MBNoteCloseReason(reason);   // plan stage 4: the re-entry logic reads how the basket ended
   bool all_ok = true;
   int closed = 0;

   // V29 new (D-block): capture the basket's total floating profit BEFORE closing, so the
   // outcome can be attributed back to whichever detector opened the first order.
   double pre_close_profit = 0.0;
   // V166: the volume-weighted entry is captured here, before the positions are closed - once they
   // are gone there is no way to ask where this basket was actually built.
   double pre_close_weighted = 0.0;
   double pre_close_volume   = 0.0;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong pt = PositionGetTicket(p);
      if(pt == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      pre_close_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      double pv = PositionGetDouble(POSITION_VOLUME);
      double po = PositionGetDouble(POSITION_PRICE_OPEN);
      if(pv > 0.0 && po > 0.0)
      {
         pre_close_weighted += po * pv;
         pre_close_volume   += pv;
      }
   }
   double pre_close_avg = (pre_close_volume > 0.0) ? (pre_close_weighted / pre_close_volume) : 0.0;

   // FIX(bayes-double-count): capture the detector type BUT do NOT record the outcome or clear
   // the type yet. The old code recorded Bayes and zeroed G_BASKET_OPENING_TYPE here, BEFORE the
   // close loop. If any PositionClose() below failed (requote/no-connection), the basket stayed
   // open, the next tick called CloseSirusBasket() again - and with the type already zeroed it
   // recorded a SECOND outcome, wrongly attributed to OPP_TYPE_NONE (0). One basket could poison
   // two Bayes buckets. Now the outcome is recorded only once the basket is confirmed fully gone.
   int opening_type_snapshot = G_BASKET_OPENING_TYPE;
   int opening_margin_snapshot = G_BASKET_OPENING_MARGIN; // V249fix(auto-mode): and its margin above the bar
   int warnings_snapshot = G_BASKET_WARNINGS;             // V155: cautions live at entry
   int regime_snapshot   = G_BASKET_REGIME;               // V157: regime at entry
   int open_bar_snapshot = G_BASKET_OPEN_BAR;             // V160b: bar it opened on

   // FIX(close-no-retry) + FIX(exit-slippage-cap): an exit had ONE attempt, at the same 50-point
   // ($0.05) deviation used for entries. A stop that does not execute is far worse than one that
   // fills badly: a single requote during the volatility that triggered the stop left part of the
   // basket open, and the next tick's RefreshGridDashboardStats() then reported the remnant as a
   // healthy small basket - fresh DD%, a wider TP, and the grid free to build a NEW martingale
   // ladder on the worst rung of the basket that had just been stopped out. Exits now get several
   // passes and a much wider slippage allowance; entries keep their tight cap.
   G_TRADE.SetExpertMagicNumber(MagicNumber);
   G_TRADE.SetTypeFillingBySymbol(_Symbol);
   G_TRADE.SetDeviationInPoints((ulong)MathMax(OrderSendDeviationPoints, CloseDeviationPoints));

   bool fatal = false;
   for(int pass = 0; pass < MathMax(1, CloseRetryPasses); pass++)
   {
      bool pass_ok = true;

      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;

         if(!PositionSelectByTicket(ticket))
            continue;

         string sym = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);

         if(sym != _Symbol || magic != MagicNumber)
            continue;

         // NOTE: CTrade in this build has no SetComment(), and PositionClose() takes no comment
         // argument, so the close reason cannot be stamped onto the closing deal from here. The chart
         // close marker (green check / red cross + tag) still records the reason visibly, so nothing
         // is lost operationally. CloseMarkerWriteComment is kept only to gate this intent.
         bool sent = G_TRADE.PositionClose(ticket);
         uint rc = G_TRADE.ResultRetcode();
         // FIX(close-retcode): "sent" alone is not "closed". A partial fill leaves volume behind, and a
         // position the broker already closed (its own SL/TP a moment earlier) is not a failure.
         if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED))
         {
            closed++;
         }
         else if(rc == TRADE_RETCODE_POSITION_CLOSED || (!sent && !PositionSelectByTicket(ticket)))
         {
            // already gone - nothing left to do for this ticket
         }
         else
         {
            pass_ok = false;
            if(!CloseRetcodeIsRetryable(rc))
               fatal = true;
            PrintFormat("[SIRUS v31.6 PHASE 21.3 BASKET CLOSE FAILED] pass=%d ticket=%I64u | reason=%s | ret=%d %s%s",
                        pass + 1,
                        ticket,
                        reason,
                        (int)rc,
                        G_TRADE.ResultRetcodeDescription(),
                        (CloseRetcodeIsRetryable(rc) ? "" : " | not retryable now"));
         }
      }

      all_ok = pass_ok;
      if(pass_ok)
         break;      // everything that matched is gone - later passes would find nothing

      // FIX(close-retry-same-quote): the passes used to run back to back inside one tick, so a requote or
      // off-quotes was simply met again at the same price - three identical failures. Give the server a
      // moment so the next pass meets a fresh quote. A market-closed / trade-disabled / no-money
      // style refusal will not change in a few hundred milliseconds, so it waits for the remnant retry on
      // a later tick instead (G_BASKET_CLOSE_PENDING below).
      if(fatal)
         break;
      // CTrade prices every close from the quote current at the moment it is sent, so the pause is enough.
      if(pass + 1 < MathMax(1, CloseRetryPasses) && !(bool)MQLInfoInteger(MQL_TESTER) && CloseRetryDelayMs > 0)
         Sleep(MathMin(2000, CloseRetryDelayMs));
   }

   G_TRADE.SetDeviationInPoints((ulong)MathMax(0, OrderSendDeviationPoints));   // restore the entry cap

   // FIX(close-remnant-becomes-new-basket): latch the failure. Until the remnant is confirmed flat
   // the grid must not treat it as a fresh basket and start adding to it.
   G_BASKET_CLOSE_PENDING = !all_ok;
   // AUDIT FIX (A6): the post-loss cooldown and the re-entry memory are written on the next tick
   // (they see the basket gone then) - no new basket may open in the tick that closed this one.
   if(closed > 0)
      G_BASKET_CLOSED_TICK = G_TICK_COUNT;
   if(!all_ok)
      PrintFormat("[SIRUS BASKET CLOSE INCOMPLETE] %d closed, positions remain | %s - grid additions held until flat",
                  closed, reason);

   // FIX(bayes-double-count): only record the learning outcome and clear the type once the
   // basket is actually, fully closed. all_ok guarantees every position was closed this call.
   if(all_ok && closed > 0 && EnableConfidenceScore)
   {
      BayesRecordOutcome(opening_type_snapshot, pre_close_profit > 0.0);
      // V153: record the same outcome against the SCORE that opened it, so the EA can find out
      // whether its own conviction ordering means anything.
      ScoreBandRecordOutcome(opening_margin_snapshot, pre_close_profit > 0.0);
      WarningRecordOutcome(warnings_snapshot, pre_close_profit > 0.0);   // V155: credit each warning that was present
      RegimeRecordOutcome(regime_snapshot, pre_close_profit > 0.0);      // V157: and credit the regime it ran in
      // V160b: learn what a normal lifetime looks like from the baskets that worked.
      if(open_bar_snapshot > 0)
         BasketAgeRecord(G_BARS_SEEN - open_bar_snapshot, pre_close_profit > 0.0);

      // V166: streak and, when it lost, where it lost.
      StreakRecordOutcome(pre_close_profit > 0.0);
      EVRecord(pre_close_profit);   // V242: what this basket was actually worth
      OppTypeRecord((int)G_BASKET_OPP_TYPE, pre_close_profit);   // V269: and which setup produced it

      // V247: and the thesis it was opened on.
      G_BASKET_INVALIDATION = 0.0;
      G_BASKET_THESIS = "";
      G_BASKET_PREMISE_DEAD = false;

      // V228: the basket is gone - so is the context it was built for.
      G_BASKET_OPEN_SESSION = -1;
      G_BASKET_TARGET_LEVEL = 0.0;
      G_BASKET_STALENESS = 0.0;

      // V199: remember a winning direction - it opens a short window where the same direction does
      // not have to prove itself again.
      if(pre_close_profit > 0.0)
      {
         G_LAST_WIN_DIR = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
         G_LAST_WIN_BAR = G_BARS_SEEN;
         G_AFFORD_RUNG_CAP = 0;        // V282: the next basket is sized from scratch
      }

      // LOCATION BRAIN: a losing close leaves a price behind. Taking the same direction again at
      // no better a price is the first mistake repeating itself with a bigger lot behind it, and
      // that is how two stops became two stops instead of one.
      if(EnableLocationBrain)
      {
         int cb_dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
         double cb_px = (cb_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         // LOCK FIX: a -$0.01 break-even close is not a stop.
         if(pre_close_profit < -0.05 * MathMax(1.0, AccountInfoDouble(ACCOUNT_BALANCE)) / 100.0) LocationBrainRecordStop(cb_dir, cb_px);
         else                       LocationBrainClearStop(cb_dir);
      }

      // And the record that decides whether entries need to be better placed than they are.
      if(EnableEvidenceTighten)
      {
         AdaptRecord(pre_close_profit > 0.0);
      }

      // V169: remember where and which way this basket closed, so what follows can be judged.
      {
         double eq_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double eq_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double eq_mid = (eq_bid > 0.0 && eq_ask > 0.0) ? (eq_bid + eq_ask) / 2.0 : eq_bid;
         int    eq_dir = (pre_close_avg > 0.0 && eq_mid > 0.0)
                         ? ((G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1) : 0;
         if(eq_dir != 0)
            ExitQualityArm(eq_dir, eq_mid);
      }
      if(IsMeaningfulLoss(pre_close_profit) && pre_close_avg > 0.0)   // BOSQICH 1: 0.0 va arzimagan minus - "zarar joyi" emas
         RecordLossLevel(pre_close_avg);
      G_BASKET_OPENING_TYPE = 0;
      ScaleInReset();                 // V161: nothing left to complete
      G_SCALEIN_EXTRA_ORDERS = 0;
   }

   PrintFormat("[SIRUS v31.6 PHASE 21.3 BASKET CLOSE] closed=%d | ok=%s | reason=%s",
               closed,
               BoolText(all_ok),
               reason);

   // FEATURE(close-markers): leave a permanent chart marker (green check = win, red cross = loss)
   // with the reason tag, using the floating profit captured before the close loop.
   if(closed > 0)
      DrawBasketCloseMarker(reason, pre_close_profit);

   if(PushOnBasketClose && closed > 0)
      SirusNotify(StringFormat("BASKET CLOSED x%d | profit=%.2f | %s", closed, pre_close_profit, reason)); // V30.4

   return all_ok;
}

// V29 new (C-block): fully closes the basket ahead of a major calendar event, but only if it's
// currently in profit (banks the gain, avoids gap risk) - never forces a loss-taking close.
// Does not reopen automatically afterward; the bot simply waits for its normal signal flow.
void CheckNewsAutoFlat()
{
   if(!EnableNewsAutoFlat || !EnableEconomicCalendarGuard)
      return;

   // FIX(calendar-window): read the upcoming event straight from the calendar cache instead of the
   // active-window globals, so auto-flat works even when NewsAutoFlatMinutesBefore is larger than
   // EconomicCalendarPreMinutes, and is not hidden by an earlier release still in its post window.
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();
   int ev = -1;
   for(int i = 0; i < G_CAL_EV_COUNT; i++)
   {
      long diff = (long)(G_CAL_EV_TIME[i] - now);
      if(diff < 0 || diff > (long)MathMax(0, NewsAutoFlatMinutesBefore) * 60)
         continue;
      if(ev < 0 || G_CAL_EV_TIME[i] < G_CAL_EV_TIME[ev])
         ev = i;
   }
   if(ev < 0)
      return;

   if(G_NEWS_FLAT_LAST_EVENT == G_CAL_EV_ID[ev])
      return;

   string ev_name = G_CAL_EV_NAME[ev];
   int    ev_min  = (int)((long)(G_CAL_EV_TIME[ev] - now) / 60);

   int orders = 0;
   double vol = 0.0, avg = 0.0, profit = 0.0, last_price = 0.0, last_lot = 0.0;
   long direction = -1;
   datetime last_time = 0;

   if(!GetSirusBasketStats(orders, vol, avg, profit, direction, last_price, last_lot, last_time))
      return;

   if(NewsAutoFlatOnlyIfProfit && profit <= 0.0)
      return;

   if(CloseSirusBasket(StringFormat("Auto-flat before news: %s (%d min)", ev_name, ev_min)))
   {
      G_NEWS_FLAT_LAST_EVENT = G_CAL_EV_ID[ev];
      if((NewsAutoFlatPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v29 NEWS AUTO-FLAT] closed basket before %s (%d min, profit=%.2f)",
                     ev_name, ev_min, profit);
   }
}

//=====================================================================
// CASHBACK TRAILING + BROKER-SIDE LOCK
//---------------------------------------------------------------------
// Rebate mode closes a basket the moment it reaches its target - a target built from the spread, a
// few hundred points at most. The ordinary basket trailing cannot help there (its 2300/300/2000 points
// are ten times the target, which is why it never runs in rebate mode). So in rebate mode the target
// becomes the point where trailing ARMS instead of where the basket closes: a reversal right after it
// still closes in profit (at least TP x RebateTrailLockFraction), and a move that keeps going is
// followed instead of being cut at the target.
//
// Every trailing lock - this one, and the ordinary basket trailing - is also written to the broker as a
// real stop-loss on every basket position, at the price where the basket result equals the lock. The
// grid keeps no stop-loss while it is recovering (that is the design), but once a basket is in profit
// the lock no longer depends on the EA staying alive: if the VPS or terminal goes down, the broker still
// closes the basket at the locked profit.
//=====================================================================
double NormalizePriceSafe(const double price);   // defined further down, with the entry price helpers

bool     G_RB_TRAIL_ACTIVE      = false;
double   G_RB_TRAIL_PEAK        = 0.0;
double   G_RB_TRAIL_LOCK        = 0.0;
datetime G_BROKER_TRAIL_LAST    = 0;
double   G_BROKER_TRAIL_LAST_LOCK = 0.0;

bool RebateTrailingOn()
{
   return (EnableRebateMode && EnableRebateTrailingMode && RebateTargetPoints() > 0.0);
}

void RebateTrailReset()
{
   G_RB_TRAIL_ACTIVE = false;
   G_RB_TRAIL_PEAK = 0.0;
   G_RB_TRAIL_LOCK = 0.0;
   G_BROKER_TRAIL_LAST_LOCK = 0.0;
}

// Runs in place of the plain "close at TP" check while rebate trailing is on. True when it closed.
bool RebateTrailManage(const double basket_points, const double tp_points, const int orders)
{
   if(tp_points <= 0.0)
      return false;

   if(!G_RB_TRAIL_ACTIVE && basket_points < tp_points)
      return false;

   double lock_floor = tp_points * MathMax(0.10, MathMin(0.95, RebateTrailLockFraction));
   double step = MathMax((double)MathMax(0, RebateTrailMinStepPoints), tp_points * MathMax(0.05, RebateTrailStepFraction));

   if(!G_RB_TRAIL_ACTIVE)
   {
      G_RB_TRAIL_ACTIVE = true;
      G_RB_TRAIL_PEAK = basket_points;
      G_RB_TRAIL_LOCK = MathMax(lock_floor, basket_points - step);
      if((BrokerTrailPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS REBATE TRAIL] armed at %.0f pts (TP %.0f, orders=%d) | lock %.0f | step %.0f",
                     basket_points, tp_points, orders, G_RB_TRAIL_LOCK, step);
   }

   // A trail never moves backwards.
   if(basket_points > G_RB_TRAIL_PEAK)
   {
      G_RB_TRAIL_PEAK = basket_points;
      double want = MathMax(lock_floor, G_RB_TRAIL_PEAK - step);
      if(want > G_RB_TRAIL_LOCK)
         G_RB_TRAIL_LOCK = want;
   }

   if(basket_points <= G_RB_TRAIL_LOCK)
   {
      return CloseSirusBasket(StringFormat("Rebate trailing lock %.0f <= %.0f peak %.0f (TP %.0f, orders=%d)",
                                            basket_points, G_RB_TRAIL_LOCK, G_RB_TRAIL_PEAK, tp_points, orders));
   }
   return false;
}

// The lock (in basket points) that is currently armed, from whichever trailing owns this basket. 0 = none.
double ActiveTrailLockPoints()
{
   if(RebateTrailingOn())
      return (G_RB_TRAIL_ACTIVE ? G_RB_TRAIL_LOCK : 0.0);
   if(G_BASKET_TRAIL_ACTIVE && G_BASKET_TRAIL_LOCK > 0.0)
      return G_BASKET_TRAIL_LOCK;
   return 0.0;
}

// Writes the armed lock to the broker as a stop-loss on every basket position. Only ever tightens.
void BrokerTrailSync(const long direction, const double avg_price)
{
   if(!EnableBrokerTrailSL)
      return;
   if(direction != POSITION_TYPE_BUY && direction != POSITION_TYPE_SELL)
      return;
   if(avg_price <= 0.0 || _Point <= 0.0)
      return;

   double lock_pts = ActiveTrailLockPoints();
   if(lock_pts <= 0.0)
      return;   // only a basket in locked profit gets a broker stop - the recovering grid never does

   // Throttle: the first stop goes on at once; after that, only when the lock has moved enough and not
   // more often than every few seconds, so the server is not flooded with modifications.
   datetime now = TimeCurrent();
   bool first = (G_BROKER_TRAIL_LAST_LOCK <= 0.0);
   if(!first)
   {
      if((lock_pts - G_BROKER_TRAIL_LAST_LOCK) < (double)MathMax(1, BrokerTrailMinMovePoints))
         return;
      if(G_BROKER_TRAIL_LAST > 0 && (now - G_BROKER_TRAIL_LAST) < MathMax(0, BrokerTrailMinIntervalSec) && now >= G_BROKER_TRAIL_LAST)
         return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
      return;

   long stops_level = 0, freeze_level = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);
   double min_gap = (double)MathMax(stops_level, freeze_level) + 2.0;   // points, small pad

   bool is_buy = (direction == POSITION_TYPE_BUY);
   double sl = is_buy ? avg_price + lock_pts * _Point : avg_price - lock_pts * _Point;
   // A buy stop fires on the bid, a sell stop on the ask: keep it at least the broker minimum away.
   if(is_buy)
      sl = MathMin(sl, tick.bid - min_gap * _Point);
   else
      sl = MathMax(sl, tick.ask + min_gap * _Point);
   sl = NormalizePriceSafe(sl);

   // Never place a "lock" that would close the basket at a loss.
   if(is_buy ? (sl <= avg_price) : (sl >= avg_price))
      return;

   int modified = 0, failed = 0;
   G_TRADE.SetExpertMagicNumber(MagicNumber);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double cur_sl = PositionGetDouble(POSITION_SL);
      double cur_tp = PositionGetDouble(POSITION_TP);
      bool improves = (cur_sl <= 0.0) ||
                      (is_buy ? (sl > cur_sl + 0.5 * _Point) : (sl < cur_sl - 0.5 * _Point));
      if(!improves)
         continue;

      if(G_TRADE.PositionModify(ticket, sl, cur_tp) &&
         (G_TRADE.ResultRetcode() == TRADE_RETCODE_DONE || G_TRADE.ResultRetcode() == TRADE_RETCODE_NO_CHANGES))
         modified++;
      else
      {
         failed++;
         if((BrokerTrailPrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS BROKER TRAIL] modify failed ticket=%I64u sl=%s | ret=%d %s",
                        ticket, DoubleToString(sl, _Digits),
                        (int)G_TRADE.ResultRetcode(), G_TRADE.ResultRetcodeDescription());
      }
   }

   G_BROKER_TRAIL_LAST = now;
   if(failed == 0)
      G_BROKER_TRAIL_LAST_LOCK = lock_pts;   // a failed pass is retried on the next tick
   if(modified > 0 && (BrokerTrailPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS BROKER TRAIL] stop-loss %s on %d position(s) | lock %.0f pts over avg %s",
                  DoubleToString(sl, _Digits), modified, lock_pts, DoubleToString(avg_price, _Digits));
}

bool CheckBasketExit()
{
   int orders = 0;
   double vol = 0.0;
   double avg = 0.0;
   double profit = 0.0;
   long direction = -1;
   double last_price = 0.0;
   double last_lot = 0.0;
   datetime last_time = 0;

   if(!GetSirusBasketStats(orders, vol, avg, profit, direction, last_price, last_lot, last_time))
   {
      if(G_TRAIL_PEAK_POINTS > 0.0 && EnablePersistentState)
         GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_TRAILPEAK", MagicNumber, _Symbol), 0.0); // V30.4
      G_TRAIL_PEAK_POINTS = 0.0;
      G_PARTIAL_CLOSE_STAGE = 0;
      RebateTrailReset();
      // FIX(scalein-orphan): this "the basket is gone" branch already clears the other per-basket
      // lifecycle state, but scale-in was never wired into it - ScaleInReset() was only reachable
      // from inside CloseSirusBasket(), so a basket closed by the broker's own TP, by hand, or by
      // a stop-out left an armed completion behind. Cleared here, where every ending is seen.
      // Same in-flight guard as ScaleInDueLot(): an entry that is PLACED but not yet visible in
      // PositionsTotal() must not be mistaken for a basket that has ended.
      if(G_LAST_ENTRY_TIME <= 0 || (TimeCurrent() - G_LAST_ENTRY_TIME) > 3)
      {
         ScaleInReset();
         G_SCALEIN_EXTRA_ORDERS = 0;
      }
      // FIX(close-remnant-becomes-new-basket): the remnant is confirmed flat - release the latch.
      G_BASKET_CLOSE_PENDING = false;
      if(G_SZR_ESCAPE_MODE)
      {
         G_SZR_ESCAPE_MODE = false;   // V31.6b: basket gone - escape mission over
         GlobalVariableSet(StringFormat("NAVIUS_%I64d_%s_SZRESC", MagicNumber, _Symbol), 0.0);
      }
      return false;
   }

   double basket_points = CurrentBasketPoints(direction, avg);
   double tp_points = BasketTPForOrderCount(orders);

   // V31.6b SZR ESCAPE MODE: a smart-zone recovery add fired earlier, meaning the basket
   // average was improved AT a strong wall during a counter-trend. The mission now is a fast
   // release from DD, not a full profit run - close the WHOLE basket as soon as it reaches
   // a small positive result. No loss is ever taken here; this only fires in profit.
   if(EnableSZREscapeMode && G_SZR_ESCAPE_MODE && basket_points >= (double)SZREscapePlusPoints && profit > 0.0)
   {
      CloseSirusBasket(StringFormat("SZR escape: fast DD release at +%.0f pts", basket_points));
      return true;
   }

   if(UseBasketTPMoney && BasketTPMoney > 0.0 && profit >= BasketTPMoney)
   {
      CloseSirusBasket(StringFormat("Basket TP money %.2f/%.2f", profit, BasketTPMoney));
      return true;
   }

   if(UseBasketSLMoney && BasketSLMoney > 0.0 && profit <= -MathAbs(BasketSLMoney))
   {
      CloseSirusBasket(StringFormat("Basket SL money %.2f/%.2f", profit, -MathAbs(BasketSLMoney)));
      return true;
   }

   // Position Brain (phase 7): once the basket's thesis is dead, the first return to break-even closes it.
   {
      string be_why = "";
      if(MBBasketBreakEvenExit(basket_points, profit, be_why))
      {
         CloseSirusBasket(be_why);
         return true;
      }
      // Stage 16 (E6): a basket the Recovery Judge gave up on, closed at its exit moment.
      if(MBRecoveryExit(be_why))
      {
         CloseSirusBasket(be_why);
         return true;
      }
      // Local basket: a short visit against the global bias, closed at break-even or better.
      if(MBLocalBasketExit(profit, be_why))
      {
         CloseSirusBasket(be_why);
         return true;
      }
   }

   // Smart runner (normal mode): the right baskets trail past the TP toward a far target.
   {
      string run_why = "";
      if(!RebateTrailingOn() && MBRunnerManage(basket_points, tp_points, run_why))
      {
         CloseSirusBasket(run_why);
         return true;
      }
   }

   if(RebateTrailingOn())
   {
      // Rebate trailing: the target arms the trail instead of closing the basket.
      if(RebateTrailManage(basket_points, tp_points, orders))
         return true;
   }
   else if(UseBasketTPPoints && basket_points >= tp_points && !MBRunnerActive())
   {
      CloseSirusBasket(StringFormat("Basket TP points %.0f/%.0f orders=%d", basket_points, tp_points, orders));
      return true;
   }

   // Whatever trailing has armed, put it on the broker's books as well.
   BrokerTrailSync(direction, avg);

   if(UseBasketSL && BasketSLPercent > 0.0)
   {
      double dd = BasketDDPercentApprox(profit);
      if(dd >= BasketSLPercent)
      {
         CloseSirusBasket(StringFormat("Basket SL percent DD %.2f/%.2f", dd, BasketSLPercent));
         return true;
      }
   }

   // V31.6z41 NEW: Smart Early Exit - conservative, multi-signal-confirmed exit well before
   // the hard BasketSLPercent above. Only fires when DD is already meaningfully elevated AND
   // multiple independent signals persistently confirm there's no sign of the adverse move
   // letting up. The hard SL above remains completely untouched as the ultimate backstop.
   if(EnableSmartEarlyExit)
   {
      string see_reason = "";
      if(SmartEarlyExitShouldTrigger(see_reason))
      {
         CloseSirusBasket(see_reason);
         return true;
      }
   }

   // V29 ported: Smart Partial Close - Stage 1. Never blocks entries; trims part of the basket, banks profit early.
   if(EnableSmartPartialClose && G_PARTIAL_CLOSE_STAGE < 1 && orders >= PartialCloseMinOrders &&
      basket_points >= (double)PartialCloseAtProfitPoints)
   {
      int trimmed = 0;
      int total_pos = PositionsTotal();
      for(int i = total_pos - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;

         double pos_vol = PositionGetDouble(POSITION_VOLUME);
         double close_vol = SafePartialVolume(pos_vol, PartialClosePercent); // V30.2 fix
         if(close_vol <= 0.0)
            continue;

         if(BasketPartialClose(ticket, close_vol))
            trimmed++;
      }

      if(trimmed > 0)
      {
         G_PARTIAL_CLOSE_STAGE = 1;
         if((PartialClosePrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v29 PARTIAL CLOSE] stage 1: trimmed %d position(s) by %.1f%% at basket profit %.0f pts (orders=%d)",
                        trimmed, PartialClosePercent, basket_points, orders);
      }
   }

   // V29 new: Laddered Partial Close - Stage 2. Only after stage 1 has already fired, and only
   // once profit reaches the further stage-2 threshold. Trims another slice, the rest rides on
   // with the Trailing Profit Lock below.
   if(EnableSmartPartialClose && EnableLadderedPartialClose && G_PARTIAL_CLOSE_STAGE == 1 &&
      orders >= PartialCloseMinOrders && basket_points >= (double)LadderStage2ProfitPoints)
   {
      int trimmed2 = 0;
      int total_pos2 = PositionsTotal();
      for(int i = total_pos2 - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;

         double pos_vol = PositionGetDouble(POSITION_VOLUME);
         double close_vol = SafePartialVolume(pos_vol, LadderStage2Percent); // V30.2 fix
         if(close_vol <= 0.0)
            continue;

         if(BasketPartialClose(ticket, close_vol))
            trimmed2++;
      }

      if(trimmed2 > 0)
      {
         G_PARTIAL_CLOSE_STAGE = 2;
         if((PartialClosePrintOnUse && G_VERBOSE))
            PrintFormat("[SIRUS v29 PARTIAL CLOSE] stage 2: trimmed %d position(s) by %.1f%% at basket profit %.0f pts (orders=%d)",
                        trimmed2, LadderStage2Percent, basket_points, orders);
      }
   }

   // V31.6e cleanup: removed the old, dormant "Trailing Profit Lock" block that used to sit
   // here (UseTrailingStop/TrailingStartPoints/TrailingStepPoints). It was inactive by default
   // (UseTrailingStop=false) and duplicated Pack2CheckBasketBreakEvenOrTrail - the ACTUAL
   // active trailing system (UseAdvancedBasketTrailing/BasketTrailStartPoints/etc, tuned this
   // session). Two parallel trailing systems with different default values was a real risk if
   // someone ever toggled the old one on without realizing it duplicated the new one.

   return false;
}

bool AutoGridHunterMode()
{
   ENUM_SIRUS_MODE effective_mode = (G_BASKET_MODE_FROZEN ? G_BASKET_FROZEN_MODE : G_ACTIVE_MODE);

   if(effective_mode == SIRUS_MODE_HIGH_HUNTER)
      return true;

   return false;
}

double AutoGridBaseDistance()
{
   // V286: rebate mode needs its own spacing. The ordinary grid is spaced for a $2.50 target - rungs
   // $6.50 apart, so a basket that goes two rungs deep is recovering a move several times its own
   // target. With a break-even target of about $0.33 that ratio becomes absurd: price would have to
   // give back almost the entire excursion before the basket could close.
   //
   // Spacing has to scale with the target it serves. Here it is a multiple of the same spread the
   // target is built from, which keeps the ladder proportionate to what it is trying to recover.
   if(EnableRebateMode && RebateGridSpacingMultiple > 0.0)
   {
      double rebate_tp = RebateTargetPoints();
      if(rebate_tp > 0.0)
         return MathMax(1.0, rebate_tp * RebateGridSpacingMultiple);
   }

   if(!UseAutoGridByMode)
      return (double)GridDistancePoints;

   if(AutoGridHunterMode())
      return (double)HunterGridDistancePoints;

   return (double)BalancedGridDistancePoints;
}

double AutoGridMinDistance()
{
   if(!UseAutoGridByMode)
      return (double)GridMinDistancePoints;

   if(AutoGridHunterMode())
      return (double)HunterGridMinDistancePoints;

   return (double)BalancedGridMinDistancePoints;
}

double AutoGridMaxDistance()
{
   if(!UseAutoGridByMode)
      return (double)GridMaxDistancePoints;

   if(AutoGridHunterMode())
      return (double)HunterGridMaxDistancePoints;

   return (double)BalancedGridMaxDistancePoints;
}

double AutoGridMultiplier()
{
   if(!UseAutoGridByMode)
      return GridDistanceMultiplier;

   if(AutoGridHunterMode())
      return HunterGridDistanceMultiplier;

   return BalancedGridDistanceMultiplier;
}

double AutoGridATRMult()
{
   if(!UseAutoGridByMode)
      return AdaptiveGridATRMult;

   if(AutoGridHunterMode())
      return HunterAdaptiveGridATRMult;

   return BalancedAdaptiveGridATRMult;
}

double AutoGridRecoveryStartDD()
{
   if(!UseAutoGridByMode)
      return RecoveryStartDDPercent;

   if(AutoGridHunterMode())
      return HunterRecoveryStartDDPercent;

   return BalancedRecoveryStartDDPercent;
}

string AutoGridProfileText()
{
   if(!UseAutoGridByMode)
      return "MANUAL";

   if(AutoGridHunterMode())
      return "HIGH_HUNTER";

   return "BALANCED";
}

bool GridSafetyDangerNow(string &reason)
{
   if(!UseGridSafetyGuard)
      return false;

   double dd = MathMax(G_BASKET_DD_PERCENT, G_RISK_EQUITY_DD_PCT);

   if(GridSafetyBlockDDRisk && GridSafetyMaxDDForNewGrid > 0.0 && dd >= GridSafetyMaxDDForNewGrid)
   {
      reason = StringFormat("auto grid safety: DD too high %.2f/%.2f", dd, GridSafetyMaxDDForNewGrid);
      return true;
   }

   if(GridSafetyMinHealthScore > 0 && G_DRI_HEALTH_SCORE > 0 && G_DRI_HEALTH_SCORE < GridSafetyMinHealthScore)
   {
      reason = StringFormat("auto grid safety: recovery health low %d/%d", G_DRI_HEALTH_SCORE, GridSafetyMinHealthScore);
      return true;
   }

   if(GridSafetyBlockOnNews && G_DNV_NEWS_ACTIVE)
   {
      reason = "auto grid safety: news active";
      return true;
   }

   if(GridSafetyBlockOnShock && (G_DNV_SHOCK_ACTIVE || G_DNV_SPREAD_SHOCK || G_DET_POST_SHOCK || G_DRT_SHOCK_MODE))
   {
      reason = "auto grid safety: shock/post-shock risk";
      return true;
   }

   if(GridSafetyBlockOnChaos && (G_MARKET_STATE == MARKET_CHAOS || G_DRT_CHAOS_MODE))
   {
      reason = "auto grid safety: chaos market";
      return true;
   }

   if(GridSafetyBlockTrendAgainst && G_DRI_TREND_AGAINST)
   {
      reason = "auto grid safety: HTF/structure against basket";
      return true;
   }

   if(GridSafetyBlockZoneDanger && G_DRI_ZONE_DANGER)
   {
      reason = "auto grid safety: opposite zone/trap danger";
      return true;
   }

   if(GridSafetyBlockSpreadRisk && G_DCS_SPREAD_RISK)
   {
      reason = "auto grid safety: spread risk";
      return true;
   }

   return false;
}

// V31.6e new: session-adaptive grid distance factor.
double SessionGridDistanceFactor()
{
   if(!EnableSessionGridDistance)
      return 1.0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   // V261: the settings are written for winter, when broker time and London time agree. From late
   // March to late October London runs an hour ahead and the broker's clock does not move with it,
   // so an unadjusted boundary is an hour late for half the year.
   int asia_end   = AdjustedSessionHour(AsiaSessionEndHour, false);
   int ln_start   = AdjustedSessionHour(LondonNYSessionStartHour, false);
   int ln_end     = AdjustedSessionHour(LondonNYSessionEndHour, false);

   if(asia_end > AsiaSessionStartHour && hour >= AsiaSessionStartHour && hour < asia_end)
      return AsiaGridDistanceFactor;

   if(ln_end > ln_start && hour >= ln_start && hour < ln_end)
      return LondonNYGridDistanceFactor;

   return 1.0;
}

// V31.6z24 NEW: SESSION TRANSITION GUARD. Real gap found via outside-evaluator review: the
// first few minutes after a major session opens (London, New York) are classically the most
// volatile, spread-prone window of the trading day - institutional order flow floods in,
// spreads can spike, and price can whipsaw before settling into the session's real character.
// The bot had general spread/volatility checks but nothing specifically aware of WHICH minutes
// these are. This flags the window around each session open by name, for extra caution.
bool IsInSessionTransitionWindow(string &detail)
{
   detail = "";
   if(!EnableSessionTransitionGuard)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int minutes_now = dt.hour * 60 + dt.min;
   int window = MathMax(1, SessionTransitionWindowMinutes);

   int london_open_minutes = LondonNYSessionStartHour * 60;
   int diff_london = MathAbs(minutes_now - london_open_minutes);
   if(diff_london <= window)
   {
      detail = StringFormat("London/NY session open transition (%d min)", diff_london);
      return true;
   }

   if(EnableAsiaTransitionGuard)
   {
      int asia_open_minutes = AsiaSessionStartHour * 60;
      int diff_asia = MathAbs(minutes_now - asia_open_minutes);
      if(diff_asia <= window)
      {
         detail = StringFormat("Asia session open transition (%d min)", diff_asia);
         return true;
      }
   }

   return false;
}

// V31.6z25 NEW: WEEKEND GAP GUARD (prevention). If the market gaps significantly over the
// weekend close, an open basket "wakes up" Monday with a sudden, unexpected P/L shift that
// none of our trailing/zone/TP logic had any chance to react to in between - price simply
// wasn't tradeable during the gap. This discourages FRESH entries in the hours approaching
// Friday's close, when weekend gap risk is being taken on with no offsetting benefit.
bool IsApproachingWeeklyClose(string &detail)
{
   detail = "";
   if(!EnableWeekendGapGuard)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_week != 5)   // 5 = Friday
      return false;

   int minutes_now = dt.hour * 60 + dt.min;
   int close_minutes = WeeklyCloseHour * 60;
   int window = MathMax(1, WeekendGapGuardWindowMinutes);
   int minutes_until_close = close_minutes - minutes_now;

   if(minutes_until_close >= 0 && minutes_until_close <= window)
   {
      detail = StringFormat("approaching weekly close (%d min left, Friday)", minutes_until_close);
      return true;
   }

   return false;
}

// V31.6z25 NEW: GAP DETECTION (recognition). Compares the time gap between the last two bars
// to the timeframe's normal spacing - a gap much larger than expected means the market was
// closed between them (weekend, holiday). Returns the PRICE gap size in points if a genuine
// time-gap is detected, so downstream logic can recognize "we just woke up into a different
// price" rather than treating a fresh gap open like any other bar.
double DetectRecentGapPoints(const ENUM_TIMEFRAMES tf)
{
   if(!EnableGapDetection)
      return 0.0;

   datetime time_recent = iTime(_Symbol, tf, 1);
   datetime time_prior = iTime(_Symbol, tf, 2);

   if(time_recent <= 0 || time_prior <= 0)
      return 0.0;

   long time_diff_seconds = (long)(time_recent - time_prior);
   long expected_seconds = (long)PeriodSeconds(tf);

   if(expected_seconds <= 0 || time_diff_seconds < expected_seconds * GapDetectionTimeMultiplier)
      return 0.0;

   double open_recent = CandleOpen(tf, 1);
   double close_prior = CandleClose(tf, 2);

   if(open_recent <= 0.0 || close_prior <= 0.0)
      return 0.0;

   return MathAbs(open_recent - close_prior) / _Point;
}

// Shared per-bar cache - same pattern as every other sense today.
double RecentGapPointsCached(const ENUM_TIMEFRAMES tf)
{
   static int    gap_cache_bar = -1;
   static double gap_cache_value = 0.0;
   if(gap_cache_bar > G_BARS_SEEN) gap_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(gap_cache_bar != G_BARS_SEEN)
   {
      gap_cache_value = DetectRecentGapPoints(tf);
      gap_cache_bar = G_BARS_SEEN;
   }

   return gap_cache_value;
}

// V31.6e new: total basket exposure cap. Uses MARGIN as % of equity rather than a hardcoded
// lot number, so this scales correctly whether the account is $30 or $2000 - the same
// percentage protects proportionally at any size. Previously the only exposure controls were
// MaxOrders (a count) and a per-order margin check - nothing capped the AGGREGATE.
// V31.6k new: Broker Margin Level Guard - completely independent from our own equity-DD stops.
// The broker enforces ITS OWN stop-out based on Margin Level% (Equity/Used Margin), and will
// forcibly close positions at whatever price is available if it's breached - none of our
// trailing/zone/TP logic gets a say once that happens. This tracks it directly so WE act first.
double CurrentMarginLevel()
{
   return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
}

bool MarginLevelAllowsGrid(string &reason)
{
   if(!EnableMarginLevelGuard)
   {
      reason = "margin level guard off";
      return true;
   }

   double level = CurrentMarginLevel();
   if(level <= 0.0)
   {
      reason = "margin level n/a (no margin in use)";
      return true;
   }

   if(level < MarginLevelDangerPercent)
   {
      reason = StringFormat("margin level %.0f%% below danger floor %.0f%%", level, MarginLevelDangerPercent);
      if((MarginLevelPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v31.6k MARGIN LEVEL] grid BLOCKED - %s", reason);
      return false;
   }

   reason = "margin level ok";
   return true;
}

double MarginLevelLotAdjust(const double lot)
{
   if(!EnableMarginLevelGuard)
      return lot;

   double level = CurrentMarginLevel();
   if(level <= 0.0 || level >= MarginLevelWarnPercent)
      return lot;

   if((MarginLevelPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v31.6k MARGIN LEVEL] caution %.0f%% < %.0f%% - lot trimmed x%.2f",
                  level, MarginLevelWarnPercent, MarginLevelLotFactor);

   return lot * MarginLevelLotFactor;
}

// ============================================================================
// V31.6n UPGRADE: GRID INTELLIGENCE SCORE - now SIX weighted senses instead of three. Grid
// is the primary rescue mechanism when a basket is losing - it deserves the fullest possible
// awareness, not a subset of what first-entry gets. Each sense contributes 0.0-1.0, weighted
// by how directly relevant it is to "is THIS specific addition, right now, a good idea":
//   1. Reversal confidence (weight 2.0) - the most direct "don't add here" signal
//   2. Zone quality + historical reliability (weight 2.0) - is price at a real, track-recorded level
//   3. Multi-TF alignment against (weight 1.5) - structural confirmation across timeframes
//   4. Order Flow conviction (weight 1.0) - real-time tick-volume confirmation
//   5. DXY proxy alignment (weight 1.0) - gold-specific macro driver
//   6. Volatility Regime (weight 0.5) - general market-quality context, least specific
// ============================================================================
// V31.6q new: how strong is the CURRENT, ongoing trend against a given direction, regardless
// of whether it's a fresh reversal or plain continuation? ADX measures strength directly;
// +DI vs -DI gives the direction. This is what catches a sustained fall with no "change of
// character" for Trend Reversal to latch onto - exactly the gap live testing exposed.
double TrendStrengthAgainst(const int dir_i)
{
   if(!EnableTrendStrength)
      return 0.0;

   // V31.6w speed fix: SirusADX's handle is cached, but CopyBuffer itself still ran every
   // call - and this function is called from both Grid Intelligence (twice per grid cycle)
   // and First Entry (every tick). Cache the raw indicator reads per bar, same pattern as
   // ADR/DXY/TrendReversal established earlier - direction comparison below stays live/cheap.
   static int    ts_cache_bar = -1;
   static double ts_adx = 0.0, ts_plus_di = 0.0, ts_minus_di = 0.0;
   if(ts_cache_bar > G_BARS_SEEN) ts_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ts_cache_bar != G_BARS_SEEN)
   {
      ts_adx      = SirusADX(TrendStrengthTF, TrendStrengthPeriod, 0, 1);
      ts_plus_di  = SirusADX(TrendStrengthTF, TrendStrengthPeriod, 1, 1);
      ts_minus_di = SirusADX(TrendStrengthTF, TrendStrengthPeriod, 2, 1);
      ts_cache_bar = G_BARS_SEEN;
   }

   if(ts_adx <= 0.0 || ts_plus_di <= 0.0 || ts_minus_di <= 0.0)
      return 0.0;

   int adx_dir = (ts_plus_di > ts_minus_di) ? 1 : ((ts_minus_di > ts_plus_di) ? -1 : 0);
   if(adx_dir == 0 || adx_dir != -dir_i)
      return 0.0;   // no meaningful directional bias, or it's not against dir_i

   double range = MathMax(1.0, TrendStrengthStrongADX - TrendStrengthMinADX);
   double strength = (ts_adx - TrendStrengthMinADX) / range;
   return MathMax(0.0, MathMin(1.0, strength));
}

// V31.6r NEW: Recovery Path Zone Search. Every other sense reacts to CURRENT conditions -
// this is the first genuinely FORWARD-LOOKING one. It searches the actual PATH between where
// price is now and the basket's break-even average for a real, strong waypoint the market is
// likely to respect. A strong zone sitting partway along that path is a genuine reason for
// confidence recovery can happen "naturally"; finding NOTHING along the whole path is a real
// reason for extra caution, not just a neutral shrug. Reuses ZoneMapNearestSupport/Resistance
// with cascading (same pattern as SZR) to scan multiple candidate waypoints, not just one.
// V31.6t NEW: Major Sweep Awareness. The existing Sweep detector only checks the CURRENT bar
// as its own entry signal type - this scans the last few bars for ANY strong, zone-confirmed
// sweep-rejection that already happened, usable as a general sense feeding grid/entry
// decisions rather than only firing as its own standalone opportunity. Classic idea: price
// wicking through a significant prior high/low and closing back is where stops cluster and
// liquidity gets taken - a real signal of likely direction, not just noise.
int RecentMajorSweepDirectionRaw(string &detail)
{
   detail = "";
   if(!EnableMajorSweepAwareness)
      return 0;

   int lookback = MathMax(1, MajorSweepLookbackBars);
   double tol = MathMax(1, MajorSweepZoneSearchPoints) * _Point;

   for(int shift = 1; shift <= lookback; shift++)
   {
      double h = CandleHigh(SignalTF, shift);
      double l = CandleLow(SignalTF, shift);
      double c = CandleClose(SignalTF, shift);

      if(h <= 0.0 || l <= 0.0 || c <= 0.0)
         continue;

      // Bullish: this bar's low pierced a strong support level, then closed back above it.
      double sup = ZoneMapNearestSupport(c + tol);
      if(sup > 0.0 && l < sup && c > sup)
      {
         double str = ZoneMapStrength(sup);
         if(str >= MajorSweepMinZoneStrength)
         {
            // FREE(sweep): recognise the sweep on the core pattern (pierced + closed back above);
            // note whether it was a clean wick sweep as extra info, but don't require it.
            bool ws = IsWickSweepLow(SignalTF, shift, sup);
            detail = StringFormat("bullish major sweep @%.2f(str=%.1f,%dbars,%s) ", sup, str, shift, (ws ? "wick" : "body"));
            return 1;
         }
      }

      // Bearish: this bar's high pierced a strong resistance level, then closed back below it.
      double res = ZoneMapNearestResistance(c - tol);
      if(res > 0.0 && h > res && c < res)
      {
         double str = ZoneMapStrength(res);
         if(str >= MajorSweepMinZoneStrength)
         {
            bool ws = IsWickSweepHigh(SignalTF, shift, res);
            detail = StringFormat("bearish major sweep @%.2f(str=%.1f,%dbars,%s) ", res, str, shift, (ws ? "wick" : "body"));
            return -1;
         }
      }
   }

   return 0;
}

// V31.6w speed fix: shared per-bar cache - this loop does multiple zone lookups per candidate
// bar and was being called from Grid Intelligence (twice) AND First Entry (every tick) with
// zero caching, same pattern already fixed for ADR/DXY/TrendReversal earlier.
int RecentMajorSweepDirection(string &detail)
{
   static int    ms_cache_bar = -1;
   static int    ms_cache_dir = 0;
   static string ms_cache_detail = "";
   if(ms_cache_bar > G_BARS_SEEN) ms_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ms_cache_bar != G_BARS_SEEN)
   {
      ms_cache_dir = RecentMajorSweepDirectionRaw(ms_cache_detail);
      ms_cache_bar = G_BARS_SEEN;
   }

   detail = ms_cache_detail;
   return ms_cache_dir;
}

// V31.6u NEW: Equilibrium (EQ) / Premium-Discount Zone. Classic SMC concept we never had: the
// midpoint (50%) of the current significant range splits it into Premium (upper half - price
// is relatively expensive, favors SELL setups) and Discount (lower half - relatively cheap,
// favors BUY setups). A BUY grid adding while price sits deep in Premium is buying "high
// within its own recent range" even if other senses look fine - a genuinely different
// dimension none of the other 9 senses capture (they look at levels/trend/momentum, not
// WHERE within the broader range price currently sits).
double EquilibriumLevel(const ENUM_TIMEFRAMES tf, const int lookback, double &range_high, double &range_low)
{
   range_high = HighestHigh(tf, lookback, 1);
   range_low  = LowestLow(tf, lookback, 1);
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return 0.0;
   return (range_high + range_low) / 2.0;
}

// Returns +1 = Discount (favors BUY), -1 = Premium (favors SELL), 0 = near Equilibrium/neutral.
// range_position_pct: 0 = at range low, 50 = at EQ, 100 = at range high.
int EQZoneBias(double &range_position_pct)
{
   range_position_pct = 50.0;
   if(!EnableEQZone)
      return 0;

   // V31.6w speed fix: HighestHigh/LowestLow scan only changes per bar - cache that part,
   // but keep the live bid/ask position calculation fresh every call (correctly tick-live).
   static int    eq_cache_bar = -1;
   static double eq_range_high = 0.0, eq_range_low = 0.0;
   if(eq_cache_bar > G_BARS_SEEN) eq_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(eq_cache_bar != G_BARS_SEEN)
   {
      EquilibriumLevel(EQZoneTF, EQZoneLookbackBars, eq_range_high, eq_range_low);
      eq_cache_bar = G_BARS_SEEN;
   }

   if(eq_range_high <= 0.0 || eq_range_low <= 0.0 || eq_range_high <= eq_range_low)
      return 0;

   double range = eq_range_high - eq_range_low;

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0;

   range_position_pct = (mid - eq_range_low) / range * 100.0;

   if(range_position_pct >= EQZonePremiumThreshold)
      return -1;
   if(range_position_pct <= EQZoneDiscountThreshold)
      return 1;
   return 0;
}

// V31.6v NEW: Engulfing pattern - classic two-candle price action: the current candle's body
// completely engulfs the prior candle's body in the opposite direction, showing a decisive
// shift in control between buyers and sellers. Quality-gated the same way we upgraded Sweep:
// prefer an engulfing that happens AT a real, zone-confirmed level over one in open space.
// +1 = bullish engulfing, -1 = bearish engulfing, 0 = none at this shift.
int DetectEngulfingAt(const ENUM_TIMEFRAMES tf, const int shift)
{
   double o1 = CandleOpen(tf, shift),     c1 = CandleClose(tf, shift);       // more recent candle
   double o2 = CandleOpen(tf, shift + 1), c2 = CandleClose(tf, shift + 1);   // prior candle

   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return 0;

   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   if(body1 <= 0.0 || body2 <= 0.0 || body1 <= body2)
      return 0;

   bool prior_bearish   = (c2 < o2);
   bool prior_bullish   = (c2 > o2);
   bool current_bullish = (c1 > o1);
   bool current_bearish = (c1 < o1);

   if(prior_bearish && current_bullish && o1 <= c2 && c1 >= o2)
      return 1;

   if(prior_bullish && current_bearish && o1 >= c2 && c1 <= o2)
      return -1;

   return 0;
}

// FEATURE(candlestick-models): Pin Bar (Hammer / Shooting Star). A small body sitting at one end
// of the candle with a long rejection wick on the other end - the market pushed one way and got
// firmly rejected. Hammer (long LOWER wick, body up top) = bullish rejection of lower prices.
// Shooting Star (long UPPER wick, body at bottom) = bearish rejection of higher prices. Returns
// +1 bullish / -1 bearish / 0 none. Thresholds are inputs so the shape can be tuned.
int DetectPinBarAt(const ENUM_TIMEFRAMES tf, const int shift)
{
   double o = CandleOpen(tf, shift), c = CandleClose(tf, shift);
   double range = CandleRangePoints(tf, shift);
   double body  = CandleBodyPoints(tf, shift);
   double upper = UpperWickPoints(tf, shift);
   double lower = LowerWickPoints(tf, shift);

   if(o <= 0.0 || c <= 0.0 || range <= 0.0)
      return 0;

   // Body must be small relative to the whole range (a pin bar is mostly wick).
   double body_frac = body / range;
   if(body_frac > PinBarMaxBodyFraction)
      return 0;

   // Hammer: long lower wick, tiny/absent upper wick -> bullish rejection.
   if((lower / range) >= PinBarMinWickFraction && upper <= lower * PinBarOppositeWickMax)
      return 1;

   // Shooting Star: long upper wick, tiny/absent lower wick -> bearish rejection.
   if((upper / range) >= PinBarMinWickFraction && lower <= upper * PinBarOppositeWickMax)
      return -1;

   return 0;
}

// FEATURE(candlestick-models): Morning Star (bullish) / Evening Star (bearish) - a 3-candle
// reversal. Candle A: a strong push in the old direction. Candle B: a small-bodied "star" (pause /
// indecision). Candle C: a strong push the OTHER way that closes well into candle A's body. Very
// reliable because it needs a full 3-bar sequence, not one candle. shift points to the most recent
// (C) candle; A is shift+2, B is shift+1. Returns +1 morning (bullish) / -1 evening (bearish) / 0.
int DetectStarAt(const ENUM_TIMEFRAMES tf, const int shift)
{
   double oA = CandleOpen(tf, shift + 2), cA = CandleClose(tf, shift + 2);
   double oB = CandleOpen(tf, shift + 1), cB = CandleClose(tf, shift + 1);
   double oC = CandleOpen(tf, shift),     cC = CandleClose(tf, shift);

   if(oA <= 0.0 || cA <= 0.0 || oB <= 0.0 || cB <= 0.0 || oC <= 0.0 || cC <= 0.0)
      return 0;

   double bodyA = MathAbs(cA - oA);
   double bodyB = MathAbs(cB - oB);
   double bodyC = MathAbs(cC - oC);
   if(bodyA <= 0.0 || bodyC <= 0.0)
      return 0;

   // Candle B is the "star": its body must be small vs candle A (a genuine pause).
   if(bodyB > bodyA * StarMiddleMaxBodyFraction)
      return 0;

   double midA = (oA + cA) / 2.0;

   // Morning Star (bullish): A bearish, C bullish and closing back above the midpoint of A.
   if(cA < oA && cC > oC && cC >= midA)
      return 1;

   // Evening Star (bearish): A bullish, C bearish and closing back below the midpoint of A.
   if(cA > oA && cC < oC && cC <= midA)
      return -1;

   return 0;
}

// FEATURE(tweezer): Tweezer top/bottom - two adjacent candles that hit almost the SAME high (top)
// or SAME low (bottom) and reverse. The market tested a level twice and got rejected both times,
// so the level is defended. Tweezer Bottom (two matching lows, turning up) = bullish; Tweezer Top
// (two matching highs, turning down) = bearish. Returns +1 / -1 / 0. Simple but reliable at zones.
int DetectTweezerAt(const ENUM_TIMEFRAMES tf, const int shift)
{
   double h1 = CandleHigh(tf, shift),     l1 = CandleLow(tf, shift);
   double h2 = CandleHigh(tf, shift + 1), l2 = CandleLow(tf, shift + 1);
   double o1 = CandleOpen(tf, shift),     c1 = CandleClose(tf, shift);
   double o2 = CandleOpen(tf, shift + 1), c2 = CandleClose(tf, shift + 1);

   if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return 0;

   double tol = MathMax(1, TweezerTolerancePoints) * _Point;

   // Tweezer Bottom: two near-equal lows, prior candle bearish, current candle bullish (turn up).
   if(MathAbs(l1 - l2) <= tol && c2 < o2 && c1 > o1)
      return 1;

   // Tweezer Top: two near-equal highs, prior candle bullish, current candle bearish (turn down).
   if(MathAbs(h1 - h2) <= tol && c2 > o2 && c1 < o1)
      return -1;

   return 0;
}

// FEATURE(order-block): Morning/Evening Star helper is above; this is the institutional Order
// Block. An order block is the LAST opposite-colour candle before a strong impulse move - the
// footprint of big players loading positions. Price often returns to that candle's zone and
// reacts (bounces) because unfilled institutional orders sit there. We detect: (1) a strong
// impulse move over the last few bars, (2) the last opposite candle before it = the order block
// zone, (3) price has now returned INTO that zone. Returns +1 (bullish OB, expect up) / -1
// (bearish OB, expect down) / 0. This is a higher-grade zone signal than a plain candle pattern.
int DetectOrderBlockReaction(const ENUM_TIMEFRAMES tf)
{
   if(!EnableOrderBlockAwareness)
      return 0;

   double atr = ATRPointsManual(tf, 14, 1);
   if(atr <= 0.0)
      return 0;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
      return 0;

   int look = MathMax(3, OrderBlockLookbackBars);
   double impulse_min = atr * OrderBlockImpulseATRMult;

   // Scan recent bars for a strong impulse leg, then find the last opposite candle before it.
   for(int s = 2; s <= look; s++)
   {
      double move_close = CandleClose(tf, s - 1);
      double move_open  = CandleOpen(tf, s);
      if(move_close <= 0.0 || move_open <= 0.0)
         continue;

      double leg_pts = MathAbs(move_close - move_open) / _Point;
      if(leg_pts < impulse_min)
         continue;   // not a strong enough impulse leg

      bool bullish_impulse = (move_close > move_open);

      // The order block is the last candle of the OPPOSITE colour just before the impulse (at s).
      bool ob_is_opposite = bullish_impulse ? IsBearishCandle(tf, s) : IsBullishCandle(tf, s);
      if(!ob_is_opposite)
         continue;

      double ob_high = CandleHigh(tf, s);
      double ob_low  = CandleLow(tf, s);
      if(ob_high <= 0.0 || ob_low <= 0.0)
         continue;

      double pad = MathMax(1, OrderBlockZonePadPoints) * _Point;

      // Has price returned into the order block zone now?
      if(bullish_impulse)
      {
         // Bullish OB: zone is the down-candle before an up-move. Expect price to bounce UP from it.
         if(price <= ob_high + pad && price >= ob_low - pad)
            return 1;
      }
      else
      {
         // Bearish OB: zone is the up-candle before a down-move. Expect price to drop from it.
         if(price >= ob_low - pad && price <= ob_high + pad)
            return -1;
      }
   }

   return 0;
}

int RecentEngulfingDirectionRaw(string &detail)
{
   detail = "";
   if(!EnableEngulfingAwareness)
      return 0;

   int lookback = MathMax(1, EngulfingLookbackBars);
   double tol = MathMax(1, EngulfingZoneSearchPoints) * _Point;

   for(int shift = 1; shift <= lookback; shift++)
   {
      int eng = DetectEngulfingAt(SignalTF, shift);
      if(eng == 0)
         continue;

      if(!EngulfingRequireZoneConfirm)
      {
         detail = StringFormat("%s engulfing (%dbars ago) ", eng > 0 ? "bullish" : "bearish", shift);
         return eng;
      }

      double c = CandleClose(SignalTF, shift);
      double zone = (eng > 0) ? ZoneMapNearestSupport(c + tol) : ZoneMapNearestResistance(c - tol);
      if(zone <= 0.0)
         continue;

      double dist_pts = MathAbs(c - zone) / _Point;
      if(dist_pts > EngulfingZoneSearchPoints)
         continue;

      double zstr = ZoneMapStrength(zone);
      if(zstr < EngulfingMinZoneStrength)
         continue;

      detail = StringFormat("%s engulfing@zone %.2f(str=%.1f,%dbars) ",
                            eng > 0 ? "bullish" : "bearish", zone, zstr, shift);
      return eng;
   }

   return 0;
}

// V31.6w speed fix: shared per-bar cache, same reasoning as Major Sweep above.
int RecentEngulfingDirection(string &detail)
{
   static int    eg_cache_bar = -1;
   static int    eg_cache_dir = 0;
   static string eg_cache_detail = "";
   if(eg_cache_bar > G_BARS_SEEN) eg_cache_bar = -1;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(eg_cache_bar != G_BARS_SEEN)
   {
      eg_cache_dir = RecentEngulfingDirectionRaw(eg_cache_detail);
      eg_cache_bar = G_BARS_SEEN;
   }

   detail = eg_cache_detail;
   return eg_cache_dir;
}

// ============================================================================
// V31.6z10 NEW: RECENT ZONE BREAK. Zone Polarity Flip already exists but lives quietly
// INSIDE ZoneMapStrength as a background +0.6 nudge - it never gets its own spotlight. This
// makes a FRESH, confirmed zone break (price closing decisively through a strong level,
// compared to the prior bar) its own prominent, standalone sense - same "recent event"
// pattern as Major Sweep and Engulfing, giving zone-break awareness the direct visibility it
// deserves rather than being buried inside another metric.
// ============================================================================
int RecentZoneBreakDirectionRaw(string &detail)
{
   detail = "";
   if(!EnableRecentZoneBreak)
      return 0;

   int lookback = MathMax(1, ZoneBreakLookbackBars);
   double tol = MathMax(1, ZoneBreakSearchPoints) * _Point;

   for(int shift = 1; shift <= lookback; shift++)
   {
      double c = CandleClose(ZoneBreakTF, shift);
      double c_prior = CandleClose(ZoneBreakTF, shift + 1);

      if(c <= 0.0 || c_prior <= 0.0)
         continue;

      // Bullish break: a strong resistance (relative to the PRIOR close) just got closed
      // above, and the prior close was still at/below it.
      double res = ZoneMapNearestResistance(c_prior - tol);
      if(res > 0.0 && c > res + tol && c_prior <= res + tol)
      {
         double str = ZoneMapStrength(res);
         if(str >= ZoneBreakMinStrength)
         {
            detail = StringFormat("bullish zone break @%.2f(str=%.1f,%dbars) ", res, str, shift);
            return 1;
         }
      }

      // Bearish break: a strong support just got closed below.
      double sup = ZoneMapNearestSupport(c_prior + tol);
      if(sup > 0.0 && c < sup - tol && c_prior >= sup - tol)
      {
         double str = ZoneMapStrength(sup);
         if(str >= ZoneBreakMinStrength)
         {
            detail = StringFormat("bearish zone break @%.2f(str=%.1f,%dbars) ", sup, str, shift);
            return -1;
         }
      }
   }

   return 0;
}
