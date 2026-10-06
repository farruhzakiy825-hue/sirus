//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 22_Memory                                       |
//| Market Brain H: Entry DNA and bounded evidence learning          |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// MEMORY (engine plan, phase 8)
//---------------------------------------------------------------------
// Every first entry leaves a fingerprint - the Entry DNA: how aligned the bias was, which kinds of
// location and trigger evidence were present, whether a liquidity reversal stood behind it, the
// timing, the decision. When the basket ends, its result is written next to that fingerprint:
//   - one row in MQL5/Files/Sirus_EntryDNA_<symbol>_<magic>.csv (the full history), and
//   - win / loss counts per evidence kind in terminal GlobalVariables (they survive restarts).
//
// Learning (bounded): once an evidence kind has MBLearnMinSamples results, its weight in the
// Entry Judge's quality moves with how its win rate compares to the overall win rate - never
// more than MBLearnMaxShift (30%) either way. Example: "sweep + displacement" seen 40 times,
// won 32 (80%) against a 60% average -> weight x1.30 (capped). Hard vetoes never learn: they
// stay exactly as written.
//=====================================================================

input group "47 — MARKET BRAIN: MEMORY (ENTRY DNA)"
input bool   EnableMBMemory           = true;   // Har kirish "barmoq izi" (Entry DNA) va savat natijasi saqlanadi (CSV + statistika)
input bool   EnableMBLearning         = true;   // Yetarli misol yig'ilgach Entry Judge og'irliklarini natijaga qarab moslash (±MBLearnMaxShift)
input int    MBLearnMinSamples        = 30;     // O'rganish shuncha natijadan keyin boshlanadi
input double MBLearnMaxShift          = 0.30;   // Og'irlik o'zgarishi chegarasi (0.30 = ±30%)
input bool   MBMemoryPrintOnUse       = true;   // Savat natijasi va DNA'ni jurnalga yozish ([SIRUS MEMORY])

#define MB_DNA_ALIGN_STRONG   0
#define MB_DNA_ALIGN_WEAK     1
#define MB_DNA_TRANS_TOWARD   2
#define MB_DNA_NEUTRAL        3
#define MB_DNA_COUNTER        4
#define MB_DNA_LOC_DISCOUNT   5
#define MB_DNA_LOC_ZONE       6
#define MB_DNA_LOC_PULLBACK   7
#define MB_DNA_TRIG_CANDLE    8
#define MB_DNA_TRIG_LIVE      9
#define MB_DNA_TRIG_EVENT    10
#define MB_DNA_REVERSAL      11
#define MB_DNA_LATE          12
#define MB_DNA_CAUTION       13
#define MB_DNA_HTF_SWEEP     14
#define MB_DNA_TYPE_REVERSAL 15
#define MB_DNA_COUNT         16

// Filled by the Entry Judge on every judgement; copied to the basket when an entry fills.
bool     G_MB_DNA_PENDING[MB_DNA_COUNT];
int      G_MB_DNA_PENDING_QUALITY = 0;
string   G_MB_DNA_PENDING_TEXT = "";

bool     G_MB_DNA[MB_DNA_COUNT];           // the open basket's DNA
int      G_MB_DNA_QUALITY = 0;
string   G_MB_DNA_TEXT    = "";
int      G_MB_DNA_DIR     = 0;
double   G_MB_DNA_PRICE   = 0.0;
datetime G_MB_DNA_TIME    = 0;              // 0 = no basket DNA recorded

// Win / loss counts per evidence kind, plus the overall pair at index MB_DNA_COUNT.
double   G_MB_LEARN_W[MB_DNA_COUNT + 1];
double   G_MB_LEARN_L[MB_DNA_COUNT + 1];
bool     G_MB_LEARN_LOADED = false;

string MBDNAName(const int k)
{
   switch(k)
   {
      case MB_DNA_ALIGN_STRONG:   return "align-strong";
      case MB_DNA_ALIGN_WEAK:     return "align-weak";
      case MB_DNA_TRANS_TOWARD:   return "transition-toward";
      case MB_DNA_NEUTRAL:        return "neutral";
      case MB_DNA_COUNTER:        return "counter-bias";
      case MB_DNA_LOC_DISCOUNT:   return "discount/premium";
      case MB_DNA_LOC_ZONE:       return "zone-holds";
      case MB_DNA_LOC_PULLBACK:   return "young-impulse";
      case MB_DNA_TRIG_CANDLE:    return "candle-trigger";
      case MB_DNA_TRIG_LIVE:      return "live-trigger";
      case MB_DNA_TRIG_EVENT:     return "event-trigger";
      case MB_DNA_REVERSAL:       return "liquidity-reversal";
      case MB_DNA_LATE:           return "late";
      case MB_DNA_CAUTION:        return "caution";
      case MB_DNA_HTF_SWEEP:      return "htf-sweep";
      case MB_DNA_TYPE_REVERSAL:  return "reversal-detector";
   }
   return "all";
}

string MBLearnKey(const string wl, const int k)
{
   return StringFormat("SIRUS_%I64d_%s_DNA_%s_%d", MagicNumber, _Symbol, wl, k);
}

void MBLearnLoad()
{
   if(G_MB_LEARN_LOADED)
      return;
   for(int k = 0; k <= MB_DNA_COUNT; k++)
   {
      G_MB_LEARN_W[k] = GlobalVariableCheck(MBLearnKey("W", k)) ? GlobalVariableGet(MBLearnKey("W", k)) : 0.0;
      G_MB_LEARN_L[k] = GlobalVariableCheck(MBLearnKey("L", k)) ? GlobalVariableGet(MBLearnKey("L", k)) : 0.0;
   }
   G_MB_LEARN_LOADED = true;
}

// Weight multiplier for evidence kind k: 1.0 until it has enough results, then within ±shift.
double MBLearnFactor(const int k)
{
   if(!EnableMBLearning || !EnableMBMemory || k < 0 || k >= MB_DNA_COUNT)
      return 1.0;
   MBLearnLoad();
   double n = G_MB_LEARN_W[k] + G_MB_LEARN_L[k];
   double n_all = G_MB_LEARN_W[MB_DNA_COUNT] + G_MB_LEARN_L[MB_DNA_COUNT];
   if(n < MathMax(1, MBLearnMinSamples) || n_all <= 0.0)
      return 1.0;
   double wr = G_MB_LEARN_W[k] / n;
   double wr_all = G_MB_LEARN_W[MB_DNA_COUNT] / n_all;
   double shift = MathMax(0.0, MathMin(0.9, MBLearnMaxShift));
   return MathMax(1.0 - shift, MathMin(1.0 + shift, 1.0 + 2.0 * (wr - wr_all)));
}

// Average factor over the kinds that are present (1.0 when none).
double MBLearnFactorOf(const int k1, const bool on1, const int k2, const bool on2, const int k3, const bool on3)
{
   double s = 0.0;
   int c = 0;
   if(on1) { s += MBLearnFactor(k1); c++; }
   if(on2) { s += MBLearnFactor(k2); c++; }
   if(on3) { s += MBLearnFactor(k3); c++; }
   return (c > 0) ? s / c : 1.0;
}

string MBDNAString(const bool &dna[])
{
   string t = "";
   for(int k = 0; k < MB_DNA_COUNT; k++)
      if(dna[k])
         t += (StringLen(t) > 0 ? " " : "") + MBDNAName(k);
   return (StringLen(t) > 0) ? t : "-";
}

// Called by the first-entry engine when an entry has filled.
void MBMemoryOnEntry(const int dir, const double price)
{
   if(!EnableMBMemory)
      return;
   for(int k = 0; k < MB_DNA_COUNT; k++)
      G_MB_DNA[k] = G_MB_DNA_PENDING[k];
   G_MB_DNA_QUALITY = G_MB_DNA_PENDING_QUALITY;
   G_MB_DNA_TEXT = G_MB_DNA_PENDING_TEXT;
   G_MB_DNA_DIR = dir;
   G_MB_DNA_PRICE = price;
   G_MB_DNA_TIME = TimeCurrent();
}

// Result of the basket that opened at `opened`, from the deal history (profit + swap + commission).
double MBBasketResult(const datetime opened, int &deals_out)
{
   deals_out = 0;
   double total = 0.0;
   if(!HistorySelect(opened - 60, TimeCurrent() + 60))
      return 0.0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != MagicNumber) continue;
      if((datetime)HistoryDealGetInteger(d, DEAL_TIME) < opened) continue;
      total += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         deals_out++;
   }
   return total;
}

// Called by the Position Brain when the watched basket has gone flat.
void MBMemoryOnBasketClosed(const datetime opened)
{
   if(!EnableMBMemory || G_MB_DNA_TIME <= 0 || opened <= 0)
   {
      G_MB_DNA_TIME = 0;
      return;
   }

   int outs = 0;
   double result = MBBasketResult(opened, outs);
   bool win = (result > 0.0);

   MBLearnLoad();
   for(int k = 0; k <= MB_DNA_COUNT; k++)
   {
      bool present = (k == MB_DNA_COUNT) ? true : G_MB_DNA[k];
      if(!present) continue;
      if(win) G_MB_LEARN_W[k] += 1.0; else G_MB_LEARN_L[k] += 1.0;
      GlobalVariableSet(MBLearnKey("W", k), G_MB_LEARN_W[k]);
      GlobalVariableSet(MBLearnKey("L", k), G_MB_LEARN_L[k]);
   }

   string dna = MBDNAString(G_MB_DNA);
   int minutes = (int)((TimeCurrent() - opened) / 60);
   if((MBMemoryPrintOnUse && VerboseLogs))
      PrintFormat("[SIRUS MEMORY] basket %s %s %.2f after %d min | quality %d | DNA: %s | record %.0f W / %.0f L",
                  (G_MB_DNA_DIR > 0 ? "BUY" : "SELL"), (win ? "WIN" : "LOSS"), result, minutes,
                  G_MB_DNA_QUALITY, dna, G_MB_LEARN_W[MB_DNA_COUNT], G_MB_LEARN_L[MB_DNA_COUNT]);

   string name = StringFormat("Sirus_EntryDNA_%s_%I64d.csv", _Symbol, MagicNumber);
   int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h != INVALID_HANDLE)
   {
      if(FileSize(h) == 0)
         FileWriteString(h, "opened;closed;dir;entry_price;result;win;minutes;quality;dna;judge\r\n");
      FileSeek(h, 0, SEEK_END);
      string judge = G_MB_DNA_TEXT;
      StringReplace(judge, ";", ",");
      FileWriteString(h, StringFormat("%s;%s;%s;%s;%.2f;%d;%d;%d;%s;%s\r\n",
                                      TimeToString(opened, TIME_DATE | TIME_SECONDS),
                                      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                      (G_MB_DNA_DIR > 0 ? "BUY" : "SELL"),
                                      DoubleToString(G_MB_DNA_PRICE, _Digits),
                                      result, (win ? 1 : 0), minutes, G_MB_DNA_QUALITY, dna, judge));
      FileClose(h);
   }
   G_MB_DNA_TIME = 0;
}

string MBMemoryText()
{
   if(!EnableMBMemory)
      return "off";
   MBLearnLoad();
   double n_all = G_MB_LEARN_W[MB_DNA_COUNT] + G_MB_LEARN_L[MB_DNA_COUNT];
   if(n_all <= 0.0)
      return "no results yet";
   return StringFormat("%.0f baskets, win rate %.0f%%%s", n_all, 100.0 * G_MB_LEARN_W[MB_DNA_COUNT] / n_all,
                       (n_all >= MBLearnMinSamples && EnableMBLearning ? ", learning on" : ", learning after " + IntegerToString(MBLearnMinSamples)));
}
