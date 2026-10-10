//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 26d_Trace                                        |
//| Decision trace: one CSV row per first-entry decision - what the   |
//| scanner said, who changed it, which exact rule refused it and     |
//| what every timeframe said at that moment.                         |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// WHY (audit 2026-10-09): the shadow ledger files every veto under "brainVeto" and many other refusals
// under "score", and nothing recorded which of the ten score up-graders turned a WAIT into a PASS. Fixes
// were then made from screenshots, not data. This file is the evidence: MQL5\Files\
// Sirus_Trace_<symbol>_<magic>.csv, appended, one row per side per M1 bar per refusing gate (a new row
// when the gate changes) and one row per order sent. No effect on trading.
//
// Columns:
//   time; bid; spread; dir; type; result (BLOCK / READY / SENT); gate; rule (the exact rule: V0, VH, V8,
//   council text...); score; min; arm (side + reason of a held setup); arb_buy; arb_sell (arbiter verdict:
//   OK / CAUTION / DENY); h4; h1; m15; m5 (structure state -3..+3); bias; local; m5struct; scan (the scan
//   steps that changed the decision); tick (this tick's verdicts: relief, evidence, fast, hold, veto...);
//   reason (the full refusal text)

input group "MEASURE ▸ Decision trace"
// EnableDecisionTrace: Har bir qaror uchun CSV qatori (Sirus_Trace_...csv): kim o'zgartirdi, qaysi qoida to'sdi, har TF nima dedi
input bool   EnableDecisionTrace      = true;   // Decision trace CSV (who changed the decision, which rule refused)

string   G_TRC_BUF = "";
int      G_TRC_LAST_BAR[2] = {-100000, -100000};
int      G_TRC_LAST_GATE[2] = {-1, -1};
datetime G_TRC_FLUSH_T = 0;

string TraceFileName() { return StringFormat("Sirus_Trace_%s_%I64d.csv", _Symbol, MagicNumber); }

void TraceFlush()
{
   if(StringLen(G_TRC_BUF) == 0)
      return;
   int h = FileOpen(TraceFileName(), FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) == 0)
      FileWriteString(h, "time;bid;spread;dir;type;result;gate;rule;score;min;arm;arb_buy;arb_sell;h4;h1;m15;m5;bias;local;m5struct;scan;tick;reason\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, G_TRC_BUF);
   FileClose(h);
   G_TRC_BUF = "";
   G_TRC_FLUSH_T = TimeCurrent();
}

string TraceClean(const string s)
{
   string t = s;
   StringReplace(t, ";", ",");
   StringReplace(t, "\r", " ");
   StringReplace(t, "\n", " ");
   return t;
}

// The exact rule inside a refusal: "VH", "V0", "V8"... for the veto, the judge's first words, else the gate.
string TraceRule(const string reason)
{
   string t = reason;
   int p = StringFind(t, "market brain veto: ");
   if(p == 0)
      t = StringSubstr(t, 19);
   else if(StringFind(t, "entry judge: wait - ") == 0)
      return "judge:" + StringSubstr(t, 20, 28);
   else
      return StringSubstr(t, 0, 28);
   int sp = StringFind(t, " ");
   if(StringFind(t, "V") == 0 && sp > 1 && sp <= 3)
      return StringSubstr(t, 0, sp);                 // V0 .. V11, VH
   if(StringFind(t, "council: ") == 0)
      return "council:" + StringSubstr(t, 9, 28);
   return StringSubstr(t, 0, 28);                    // lock, late entry, taken liquidity, re-entry, cost, anomaly
}

string TraceArbTxt(const int dir)
{
   string w = "";
   int lv = MBArbiterLevel(dir, w);
   return (lv == ARB_DENY) ? "DENY" : ((lv == ARB_CAUTION) ? "CAUTION" : "OK");
}

void TraceRow(const int dir, const string result, const int gate, const string reason)
{
   string arm = (G_ARM_DIR != 0) ? StringFormat("%s/%d", (G_ARM_DIR > 0 ? "BUY" : "SELL"), G_ARM_REASON) : "-";
   G_TRC_BUF += StringFormat("%s;%s;%d;%s;%s;%s;%s;%s;%d;%d;%s;%s;%s;%d;%d;%d;%d;%d;%d;%d;%s;%s;%s\r\n",
                             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                             DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
                             (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
                             (dir > 0 ? "BUY" : (dir < 0 ? "SELL" : "-")),
                             OpportunityTypeToString(G_OPP_TYPE), result, GateName(gate),
                             TraceClean(TraceRule(reason)), G_SCORE_FINAL, G_SCORE_MIN_REQUIRED, arm,
                             TraceArbTxt(1), TraceArbTxt(-1),
                             G_MB_TF_STATE[4], G_MB_TF_STATE[3], G_MB_TF_STATE[2], G_MB_TF_STATE[1], G_MB_BIAS,
                             MBLayerLocal(), MBM5StructDir(),
                             TraceClean(G_TR_SCAN), TraceClean(G_TR_TICK), TraceClean(reason));
   if(StringLen(G_TRC_BUF) > 30000 || TimeCurrent() - G_TRC_FLUSH_T >= 60)
      TraceFlush();
}

void TraceDecision(const bool ready, const string reason)
{
   if(!EnableDecisionTrace || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   int dir = OppDirSign();
   if(dir == 0)
      return;
   int gate = ready ? GATE_NONE : GateClassify(reason);
   if(gate == GATE_POSITIONS)
      return;                                   // a basket is open - not a first-entry decision
   int sl = (dir > 0) ? 1 : 0;
   if(G_TRC_LAST_BAR[sl] > G_BARS_SEEN) G_TRC_LAST_BAR[sl] = -100000;   // re-init rewinds the bar count
   if(G_TRC_LAST_BAR[sl] == G_BARS_SEEN && G_TRC_LAST_GATE[sl] == gate)
      return;                                   // one row per side per M1 bar per refusing gate
   G_TRC_LAST_BAR[sl] = G_BARS_SEEN;
   G_TRC_LAST_GATE[sl] = gate;
   TraceRow(dir, (ready ? "READY" : "BLOCK"), gate, (ready ? "entry allowed" : reason));
}

void TraceSent(const int dir, const double price)
{
   if(!EnableDecisionTrace || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   TraceRow(dir, "SENT", GATE_NONE, StringFormat("sent @ %s", DoubleToString(price, _Digits)));
   TraceFlush();
}
