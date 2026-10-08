//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20b_Structure_Lock                              |
//| Plan stage 1: structure memory, MSS quality, direction lock and  |
//| reversal maturity.                                               |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// The event engine already sees every BOS / MSS on every timeframe, but it forgot them one by one:
// it did not know that two bearish breaks came in a row after an H1 high was swept, which level the
// bearish structure is protecting, or how far a bounce has got toward really turning it. So a small
// bounce inside a falling market read as a reversal (4157.88 BUY), and the real reversal at 4070
// (sweep -> displacement -> MSS -> retest) looked no different from that bounce.
//
//  STRUCTURE MEMORY  per M5 / M15 / H1: the run of same-way breaks (only breaks that closed through
//                    with a real body count), the level the structure protects (the lower high a
//                    bearish break came from, the higher low a bullish one came from) and the quality
//                    of the last break - WEAK (tiny body), VALID (closed through), STRONG (displacement
//                    body), CONFIRMED (the next bar held it), FAILED (the next bar closed back: a trap).
//  DIRECTION LOCK    an M15+ liquidity sweep, a displacement and two breaks in a row the same way
//                    (on M15, or on M5 with M15 already that way) lock the direction: entries the
//                    other way are refused - reaching a support is not a reason to buy into it. Ends
//                    when M15 closes beyond the protected level, when the reversal reaches stage 6,
//                    or after LockMaxHours without a new break the lock's way.
//  REVERSAL MATURITY against the structure (the lock, or the M15 trend), stages 0..6:
//                    1 liquidity swept the new way, 2 displacement, 3 MSS on M5+, 4 retest of the
//                    MSS level held, 5 higher low (lower high), 6 a new break the new way. Stage 1 is
//                    never taken for stage 6. A close back beyond the sweep extreme is a trap: back
//                    to 0. From LockUnlockStage (4) an entry the new way is allowed - and the brain
//                    takes it (BRAIN REVERSAL).
//
// Speed: breaks are recorded where the event engine finds them (per bar of their timeframe); the
// lock is judged once per M5 bar and the maturity once per M1 bar. Nothing here runs per tick.

input group "BRAIN ▸ Structure memory & direction lock"
// EnableStructureLock: YO'NALISH LOCK: M15+ sweep + displacement + ketma-ket 2 buzilish bo'lsa - qarshi tomonga kirish yo'q, burilish 4-bosqichga yetguncha (support'ga kelgani BUY sababi emas)
input bool   EnableStructureLock      = true;   // Enable structure lock
// LockSweepHours: Lock uchun M15+ sweep shuncha soat ichida bo'lgan bo'lishi kerak
input int    LockSweepHours           = 12;   // Lock sweep hours
// LockMaxHours: Lock tomoniga yangi buzilish shuncha soat bo'lmasa - lock tugaydi
input int    LockMaxHours             = 8;   // Lock max hours
// LockUnlockStage: Lock'ka qarshi kirish uchun burilish shu bosqichga yetishi kerak (4 = sweep + displacement + MSS + retest ushlandi)
input int    LockUnlockStage          = 4;   // Lock unlock stage
// EnableReversalEntry: Burilish LockUnlockStage+ bosqichda: miya yangi tomonga kiradi (BRAIN REVERSAL)
input bool   EnableReversalEntry      = true;   // Enable reversal entry
// StructurePrintOnUse: Lock / burilish bosqichlari / soxta buzilishlarni jurnalga yozish ([SIRUS STRUCTURE])
input bool   StructurePrintOnUse      = true;   // Structure print on use (on/off)

#define ST_Q_FAILED     0
#define ST_Q_WEAK       1
#define ST_Q_VALID      2
#define ST_Q_STRONG     3
#define ST_Q_CONFIRMED  4

int      G_ST_SEQ[MB_TF_COUNT];          // signed run of same-way breaks (VALID+): -2 = two bearish in a row
datetime G_ST_SEQ_START[MB_TF_COUNT];    // first break of the run
double   G_ST_PROT_HI[MB_TF_COUNT];      // the lower high the last bearish break came from
double   G_ST_PROT_LO[MB_TF_COUNT];      // the higher low the last bullish break came from
int      G_ST_LB_DIR[MB_TF_COUNT];       // last break
double   G_ST_LB_LVL[MB_TF_COUNT];
datetime G_ST_LB_TIME[MB_TF_COUNT];
int      G_ST_LB_Q[MB_TF_COUNT];
bool     G_ST_LB_CHECKED[MB_TF_COUNT];   // follow-through judged

int      G_ST_LOCK_DIR     = 0;          // -1 bearish lock, +1 bullish lock
datetime G_ST_LOCK_SINCE   = 0;
datetime G_ST_LOCK_REFRESH = 0;
double   G_ST_LOCK_PROT    = 0.0;        // M15 close beyond it ends the lock
string   G_ST_LOCK_WHY     = "";
string   G_ST_LOCK_END     = "";         // why the last lock ended (panel)
datetime G_ST_LOCK_USED[2];              // the sweep that armed the last lock each way (0 SELL-lock, 1 BUY-lock)

int      G_ST_REV_DIR   = 0;             // direction of the developing reversal
int      G_ST_REV_STAGE = 0;             // 0..6
double   G_ST_REV_EXT   = 0.0;           // sweep extreme
double   G_ST_REV_MSS   = 0.0;           // level the reversal MSS broke
string   G_ST_REV_TRAP  = "";            // last failed reversal (panel)
datetime G_ST_BAR_M1    = 0;
datetime G_ST_BAR_M5    = 0;

string MBStQName(const int q)
{
   switch(q)
   {
      case ST_Q_FAILED:    return "soxta";
      case ST_Q_WEAK:      return "zaif";
      case ST_Q_VALID:     return "yopilish";
      case ST_Q_STRONG:    return "kuchli";
      case ST_Q_CONFIRMED: return "tasdiq";
   }
   return "-";
}

// Called by the event engine (18) on every BOS / MSS it finds - in the replay too, so the memory is
// rebuilt after a restart. r[] is series-ordered; s = the breaking bar, sw = the swing it broke.
void MBStructBreakRecord(const int tfi, const int dir, const int type, const double lvl,
                         const MqlRates &r[], const int n, const int s, const int sw, const double atr)
{
   if(tfi < 1 || tfi >= MB_TF_COUNT || dir == 0 || atr <= 0.0 || s < 0 || s >= n)
      return;
   double body = MathAbs(r[s].close - r[s].open);
   int q = (body < 0.3 * atr) ? ST_Q_WEAK : ((body >= 0.8 * atr) ? ST_Q_STRONG : ST_Q_VALID);

   // The protected level: the extreme of the leg that made the break, between the broken swing and
   // the breaking bar (a bearish break comes down from a lower high - that high is what it protects).
   double ext = (dir < 0) ? r[s].high : r[s].low;
   for(int j = s; j <= sw && j < n; j++)
      ext = (dir < 0) ? MathMax(ext, r[j].high) : MathMin(ext, r[j].low);
   if(dir < 0) G_ST_PROT_HI[tfi] = ext;
   else        G_ST_PROT_LO[tfi] = ext;

   if(q >= ST_Q_VALID)
   {
      if(MBSign(G_ST_SEQ[tfi]) == dir)
         G_ST_SEQ[tfi] += dir;
      else
      {
         G_ST_SEQ[tfi] = dir;
         G_ST_SEQ_START[tfi] = r[s].time;
      }
   }
   else if(MBSign(G_ST_SEQ[tfi]) != dir)
      G_ST_SEQ[tfi] = 0;   // a weak break against the run ends it, but does not start one

   G_ST_LB_DIR[tfi] = dir;
   G_ST_LB_LVL[tfi] = lvl;
   G_ST_LB_TIME[tfi] = r[s].time;
   G_ST_LB_Q[tfi] = q;
   G_ST_LB_CHECKED[tfi] = false;
   // In the replay the next bar is already known.
   if(s >= 2)
   {
      double c_next = r[s - 1].close;
      G_ST_LB_CHECKED[tfi] = true;
      if(dir * (c_next - lvl) > 0.0)
      {
         if(q >= ST_Q_VALID) G_ST_LB_Q[tfi] = ST_Q_CONFIRMED;
      }
      else if(dir * (c_next - lvl) < -0.1 * atr)
      {
         G_ST_LB_Q[tfi] = ST_Q_FAILED;
         // AUDIT FIX: only a break the run counted can be taken back from it (a WEAK one never was).
         if(q >= ST_Q_VALID && MBSign(G_ST_SEQ[tfi]) == dir) G_ST_SEQ[tfi] -= dir;
      }
   }
   if(!G_MB_EV_REPLAYING && tfi >= 2 && StructurePrintOnUse && VerboseLogs)
      PrintFormat("[SIRUS STRUCTURE] %s %s %s @ %s (%s) | run %+d | protects %s",
                  MBTFName(tfi), (type == MB_EV_MSS ? "MSS" : "BOS"), (dir > 0 ? "BULLISH" : "BEARISH"),
                  DoubleToString(lvl, _Digits), MBStQName(q), G_ST_SEQ[tfi], DoubleToString(ext, _Digits));
}

// Follow-through of a live break, judged when the next bar of its timeframe has closed.
void MBStructFollowThrough()
{
   for(int tfi = 1; tfi < MB_TF_COUNT; tfi++)
   {
      if(G_ST_LB_TIME[tfi] <= 0 || G_ST_LB_CHECKED[tfi] || G_ST_LB_Q[tfi] <= ST_Q_FAILED)
         continue;
      ENUM_TIMEFRAMES tf = MBTF(tfi);
      int sh = iBarShift(_Symbol, tf, G_ST_LB_TIME[tfi], false);
      if(sh < 2)
         continue;   // the bar after the break is still forming
      double c_next = iClose(_Symbol, tf, sh - 1);
      double atr = G_MB_ATR[tfi] * _Point;
      int d = G_ST_LB_DIR[tfi];
      G_ST_LB_CHECKED[tfi] = true;
      if(c_next <= 0.0 || atr <= 0.0)
         continue;
      if(d * (c_next - G_ST_LB_LVL[tfi]) > 0.0)
      {
         if(G_ST_LB_Q[tfi] >= ST_Q_VALID) G_ST_LB_Q[tfi] = ST_Q_CONFIRMED;
      }
      else if(d * (c_next - G_ST_LB_LVL[tfi]) < -0.1 * atr)
      {
         bool counted = (G_ST_LB_Q[tfi] >= ST_Q_VALID);   // AUDIT FIX: a WEAK break was never in the run
         G_ST_LB_Q[tfi] = ST_Q_FAILED;
         if(counted && MBSign(G_ST_SEQ[tfi]) == d) G_ST_SEQ[tfi] -= d;
         if(StructurePrintOnUse && VerboseLogs)
            PrintFormat("[SIRUS STRUCTURE] %s %s break @ %s FAILED - the next bar closed back through it (trap)",
                        MBTFName(tfi), (d > 0 ? "bullish" : "bearish"), DoubleToString(G_ST_LB_LVL[tfi], _Digits));
      }
   }
}

// Latest (or earliest) event of a kind: 1 = break (BOS / MSS), 2 = sweep (sweep / fake break),
// 3 = displacement - with dir, a timeframe rank range (KEY ranks 4) and a start time.
datetime MBStFind(const int kind, const int dir, const int min_rank, const int max_rank, const datetime since,
                  const bool earliest, double &level)
{
   datetime best = 0;
   level = 0.0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dir || G_MB_EV[idx].time < since)
         continue;
      int ty = G_MB_EV[idx].type;
      bool ok = (kind == 1) ? (ty == MB_EV_BOS || ty == MB_EV_MSS) :
                ((kind == 2) ? (ty == MB_EV_LIQ_SWEEP || ty == MB_EV_FAKE_BREAK) : (ty == MB_EV_DISPLACEMENT));
      if(!ok)
         continue;
      int rk = MBEventRank(G_MB_EV[idx].tfi);
      if(rk < min_rank || rk > max_rank)
         continue;
      if(best == 0 || (earliest ? G_MB_EV[idx].time < best : G_MB_EV[idx].time > best))
      {
         best = G_MB_EV[idx].time;
         level = G_MB_EV[idx].level;
      }
   }
   return best;
}

int MBStCount(const int kind, const int dir, const int min_rank, const int max_rank, const datetime since)
{
   int c = 0;
   for(int idx = 0; idx < MB_EV_MAX; idx++)
   {
      if(G_MB_EV[idx].time <= 0 || G_MB_EV[idx].dir != dir || G_MB_EV[idx].time < since)
         continue;
      int ty = G_MB_EV[idx].type;
      bool ok = (kind == 1) ? (ty == MB_EV_BOS || ty == MB_EV_MSS) :
                ((kind == 2) ? (ty == MB_EV_LIQ_SWEEP || ty == MB_EV_FAKE_BREAK) : (ty == MB_EV_DISPLACEMENT));
      int rk = MBEventRank(G_MB_EV[idx].tfi);
      if(ok && rk >= min_rank && rk <= max_rank)
         c++;
   }
   return c;
}

void MBLockRelease(const string why)
{
   if(G_ST_LOCK_DIR == 0)
      return;
   if(StructurePrintOnUse && VerboseLogs)
      PrintFormat("[SIRUS STRUCTURE] %s LOCK released - %s", (G_ST_LOCK_DIR > 0 ? "BULLISH" : "BEARISH"), why);
   G_ST_LOCK_END = why;
   G_ST_LOCK_DIR = 0;
   G_ST_LOCK_PROT = 0.0;
   G_ST_LOCK_WHY = "";
}

// Once per M5 bar.
void MBLockEvaluate()
{
   if(G_ST_LOCK_DIR != 0)
   {
      int d = G_ST_LOCK_DIR;
      // A new break the lock's way on M15 renews it and moves the protected level.
      if(G_ST_LB_DIR[2] == d && G_ST_LB_TIME[2] > G_ST_LOCK_REFRESH && G_ST_LB_Q[2] >= ST_Q_VALID)
      {
         G_ST_LOCK_REFRESH = G_ST_LB_TIME[2];
         double p = (d < 0) ? G_ST_PROT_HI[2] : G_ST_PROT_LO[2];
         if(p > 0.0) G_ST_LOCK_PROT = p;
      }
      double c15 = iClose(_Symbol, PERIOD_M15, 1);
      if(G_ST_LOCK_PROT > 0.0 && c15 > 0.0 && d * (c15 - G_ST_LOCK_PROT) < 0.0)
         MBLockRelease(StringFormat("M15 closed beyond the protected level %s", DoubleToString(G_ST_LOCK_PROT, _Digits)));
      else if(G_ST_REV_DIR == -d && G_ST_REV_STAGE >= 6)
         MBLockRelease("the reversal completed (stage 6)");
      else if((TimeCurrent() - G_ST_LOCK_REFRESH) > (long)MathMax(1, LockMaxHours) * 3600)
         MBLockRelease(StringFormat("no new break its way for %d h", LockMaxHours));
   }

   for(int d = -1; d <= 1; d += 2)
   {
      if(G_ST_LOCK_DIR == d)
         continue;
      double lv = 0.0;
      // 1. M15+ (or a key level) liquidity taken the lock's way.
      datetime swt = MBStFind(2, d, 2, 4, TimeCurrent() - (long)MathMax(1, LockSweepHours) * 3600, false, lv);
      // Plan stage 3: or a MAJOR+ sweep on the liquidity map (H1 / H4 / previous-day level, multi-TF).
      datetime lt = 0;
      int lc = 0, lq = 0;
      double le = 0.0;
      if(MBLqSweepFor(d, 3, MathMax(1, LockSweepHours) * 3600, lt, lc, le, lq) && lt > swt)
      {
         swt = lt;
         lv = le;
      }
      if(swt <= 0)
         continue;
      // AUDIT FIX: the sweep that armed a lock already released cannot arm it again - a new sweep is
      // needed (otherwise a released lock re-armed on the very next M5 bar from the same evidence).
      if(swt <= G_ST_LOCK_USED[d > 0 ? 1 : 0])
         continue;
      // 2. A displacement the lock's way after it (M5+).
      double dl = 0.0;
      if(MBStFind(3, d, 1, 4, swt, false, dl) <= 0)
         continue;
      // 3. Two breaks in a row its way, the run started after the sweep.
      bool runs = (G_ST_SEQ[2] * d >= 2 && G_ST_SEQ_START[2] >= swt - PeriodSeconds(PERIOD_M15)) ||
                  (G_ST_SEQ[1] * d >= 2 && G_ST_SEQ_START[1] >= swt - PeriodSeconds(PERIOD_M5) && G_MB_TREND[2] == d);
      if(!runs)
         continue;
      double prot = (d < 0) ? G_ST_PROT_HI[2] : G_ST_PROT_LO[2];
      if(prot <= 0.0 || (d < 0 ? prot <= SymbolInfoDouble(_Symbol, SYMBOL_BID) : prot >= SymbolInfoDouble(_Symbol, SYMBOL_BID)))
         prot = (d < 0) ? G_ST_PROT_HI[1] : G_ST_PROT_LO[1];
      if(G_ST_LOCK_DIR == -d)
         MBLockRelease("the other way locked");
      G_ST_LOCK_DIR = d;
      G_ST_LOCK_USED[d > 0 ? 1 : 0] = swt;
      G_ST_LOCK_SINCE = TimeCurrent();
      G_ST_LOCK_REFRESH = TimeCurrent();
      G_ST_LOCK_PROT = prot;
      G_ST_LOCK_WHY = StringFormat("%s sweep @ %s, displacement, %d breaks in a row", (d < 0 ? "buy-side" : "sell-side"),
                                   DoubleToString(lv, _Digits), MathMax(MathAbs(G_ST_SEQ[2]), MathAbs(G_ST_SEQ[1])));
      if(StructurePrintOnUse && VerboseLogs)
         PrintFormat("[SIRUS STRUCTURE] %s LOCK on: %s | protected %s | %s entries wait for a reversal to stage %d",
                     (d > 0 ? "BULLISH" : "BEARISH"), G_ST_LOCK_WHY, DoubleToString(prot, _Digits),
                     (d > 0 ? "SELL" : "BUY"), LockUnlockStage);
      break;
   }
}

// Once per M1 bar: how far the reversal against the structure has got (stateless - recomputed from
// the events and the bars, so it also survives a restart).
void MBReversalCompute()
{
   int P = (G_ST_LOCK_DIR != 0) ? G_ST_LOCK_DIR : G_MB_TREND[2];
   G_ST_REV_STAGE = 0;
   G_ST_REV_DIR = -P;
   G_ST_REV_EXT = 0.0;
   G_ST_REV_MSS = 0.0;
   double atr5 = G_MB_ATR[1] * _Point;
   if(P == 0 || atr5 <= 0.0)
      return;
   int rd = -P;
   double lv = 0.0;

   // The structure's latest push (M5 / M15 break its way) - the reversal must come after it.
   datetime base = MBStFind(1, P, 1, 2, 0, false, lv);
   // 1. Liquidity taken the reversal's way (M5+, key levels, or a live M5+ sweep).
   datetime swt = MBStFind(2, rd, 1, 4, base, true, lv);
   if(G_MB_LSW_DIR == rd && G_MB_LSW_TFI >= 1 && G_MB_LSW_TIME >= base && (swt <= 0 || G_MB_LSW_TIME < swt))
      swt = G_MB_LSW_TIME;
   // Plan stage 3: a sweep on the liquidity map counts too (any class, not a trap).
   datetime lt = 0;
   int lc = 0, lq = 0;
   double le = 0.0;
   if(MBLqSweepFor(rd, 1, 43200, lt, lc, le, lq) && lt >= base && (swt <= 0 || lt < swt))
      swt = lt;
   if(swt <= 0)
      return;
   G_ST_REV_STAGE = 1;

   // The sweep extreme: from the sweep bar to the displacement (or to now).
   double dl = 0.0;
   datetime tdisp = MBStFind(3, rd, 1, 4, swt, true, dl);
   if(tdisp <= 0 && MBStCount(3, rd, 0, 0, swt) >= 2)
      tdisp = MBStFind(3, rd, 0, 0, swt, false, dl);   // two M1 displacements stand in for one on M5
   datetime ext_to = (tdisp > 0) ? tdisp : TimeCurrent();
   int s_from = iBarShift(_Symbol, PERIOD_M5, swt, false);
   int s_to = iBarShift(_Symbol, PERIOD_M5, ext_to, false);
   if(s_from < 0) return;
   if(s_to < 0) s_to = 0;
   double ext = (rd > 0) ? DBL_MAX : -DBL_MAX;
   for(int s = MathMin(s_from + 1, 300); s >= s_to; s--)
   {
      double h = iHigh(_Symbol, PERIOD_M5, s), l = iLow(_Symbol, PERIOD_M5, s);
      if(h <= 0.0) continue;
      ext = (rd > 0) ? MathMin(ext, l) : MathMax(ext, h);
   }
   if(ext == DBL_MAX || ext == -DBL_MAX) return;
   G_ST_REV_EXT = ext;
   if(tdisp <= 0)
      return;
   // Trap: an M5 close back beyond the sweep extreme after the displacement - the reversal failed.
   int s_d = iBarShift(_Symbol, PERIOD_M5, tdisp, false);
   for(int s = MathMax(1, s_d - 1); s >= 1; s--)
   {
      double c = iClose(_Symbol, PERIOD_M5, s);
      if(c > 0.0 && rd * (c - ext) < -0.1 * atr5)
      {
         string trap = StringFormat("%s reversal failed: M5 closed beyond the sweep extreme %s", (rd > 0 ? "bullish" : "bearish"),
                                    DoubleToString(ext, _Digits));
         if(trap != G_ST_REV_TRAP && StructurePrintOnUse && VerboseLogs)
            PrintFormat("[SIRUS STRUCTURE] TRAP - %s", trap);
         G_ST_REV_TRAP = trap;
         G_ST_REV_STAGE = 0;
         return;
      }
   }
   G_ST_REV_STAGE = 2;

   // 3. MSS / BOS the reversal's way on M5+ after the sweep.
   double mss = 0.0;
   datetime tm = MBStFind(1, rd, 1, 4, swt, true, mss);
   if(tm <= 0)
      return;
   G_ST_REV_STAGE = 3;
   G_ST_REV_MSS = mss;

   // 4. Retest: price came back toward the MSS level (or pulled back 38% of the new leg) and held -
   //    no M5 close back through the level - and is above it again.
   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   // From the close of the MSS bar: the M1 bars inside it are the break itself, not a retest.
   datetime t_after = tm + PeriodSeconds(PERIOD_M5);
   int n1 = CopyRates(_Symbol, PERIOD_M1, t_after, TimeCurrent(), m1);
   if(n1 < 2)
      return;
   int s_m = iBarShift(_Symbol, PERIOD_M5, tm, false);
   // The deepest pullback after the MSS bar (closed M1 bars), and the high of the leg before it -
   // sticky: a later run to new highs does not erase a retest that already held.
   double low = (rd > 0) ? DBL_MAX : -DBL_MAX;
   int low_i = -1;
   for(int i = n1 - 1; i >= 1; i--)
   {
      if(rd > 0 ? (m1[i].low < low) : (m1[i].high > low))
      {
         low = (rd > 0) ? m1[i].low : m1[i].high;
         low_i = i;
      }
   }
   if(low_i < 0)
      return;
   double peak = (s_m >= 0) ? ((rd > 0) ? iHigh(_Symbol, PERIOD_M5, s_m) : iLow(_Symbol, PERIOD_M5, s_m)) : ((rd > 0) ? -DBL_MAX : DBL_MAX);
   for(int i = n1 - 1; i >= low_i; i--)
      peak = (rd > 0) ? MathMax(peak, m1[i].high) : MathMin(peak, m1[i].low);
   double leg = MathAbs(peak - ext);
   bool touched = (rd * (low - mss) <= 0.35 * atr5) || (leg > 0.0 && MathAbs(peak - low) >= 0.38 * leg);
   bool held = true;
   for(int s = MathMax(1, s_m - 1); s >= 1 && held; s--)
   {
      double c = iClose(_Symbol, PERIOD_M5, s);
      if(c > 0.0 && rd * (c - mss) < -0.25 * atr5) held = false;
   }
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!(touched && held && rd * (px - mss) > 0.0))
      return;
   G_ST_REV_STAGE = 4;

   // 5. Higher low (lower high): the pullback low stayed clear of the sweep extreme, is at least three
   //    M1 bars old, and price has left it.
   if(rd * (low - ext) > 0.2 * atr5 && low_i >= 3 && rd * (px - low) >= 0.3 * atr5)
      G_ST_REV_STAGE = 5;
   else
      return;

   // 6. A new break the reversal's way after the pullback low.
   datetime t_low = m1[low_i].time;
   if(MBStFind(1, rd, 1, 4, t_low + 1, false, lv) > 0)
      G_ST_REV_STAGE = 6;
}

void MBReversalEvaluate()
{
   int prev_stage = G_ST_REV_STAGE, prev_dir = G_ST_REV_DIR;
   MBReversalCompute();
   if((G_ST_REV_STAGE != prev_stage || G_ST_REV_DIR != prev_dir) && G_ST_REV_STAGE >= 3 && StructurePrintOnUse && VerboseLogs)
      PrintFormat("[SIRUS STRUCTURE] %s reversal stage %d/6 | sweep extreme %s | MSS %s",
                  (G_ST_REV_DIR > 0 ? "bullish" : "bearish"), G_ST_REV_STAGE, DoubleToString(G_ST_REV_EXT, _Digits),
                  DoubleToString(G_ST_REV_MSS, _Digits));
}

void MBStructUpdate()
{
   if(!EnableMarketBrain || !EnableMarketBrainEngines)
   {
      G_ST_LOCK_DIR = 0;      // AUDIT FIX: a lock must not keep blocking while its engine is off
      G_ST_REV_STAGE = 0;
      return;
   }
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 <= 0 || m1 == G_ST_BAR_M1)
      return;
   G_ST_BAR_M1 = m1;
   MBStructFollowThrough();
   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 > 0 && m5 != G_ST_BAR_M5)
   {
      G_ST_BAR_M5 = m5;
      if(EnableStructureLock)
         MBLockEvaluate();
      else
         G_ST_LOCK_DIR = 0;
   }
   MBReversalEvaluate();
}

// How far the reversal toward dir has got (0 when the reversal under way is the other way).
int MBStructStageFor(const int dir)
{
   if(dir == 0 || G_ST_REV_DIR != dir)
      return 0;
   // AUDIT FIX (A5): the stage is computed once per M1 bar - stages 4+ need price beyond the MSS, so a
   // fall back through it mid-minute must not keep the lock open / the reversal entry armed for the
   // rest of the minute. Read live: back through the MSS = stage 3.
   if(G_ST_REV_STAGE >= 4 && G_ST_REV_MSS > 0.0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0 && dir * (bid - G_ST_REV_MSS) <= 0.0)
         return 3;
   }
   return G_ST_REV_STAGE;
}

// Structure damage of the side being reversed, 0..100.
int MBStructDamage()
{
   int map[7] = {0, 15, 30, 55, 70, 85, 100};
   return map[MathMax(0, MathMin(6, G_ST_REV_STAGE))];
}

// The lock refuses this direction (true) until the reversal toward it reaches LockUnlockStage.
bool MBLockBlocks(const int dir, string &why)
{
   why = "";
   if(!EnableStructureLock || dir == 0 || G_ST_LOCK_DIR != -dir)
      return false;
   int st = MBStructStageFor(dir);
   if(st >= MathMax(1, LockUnlockStage))
      return false;
   why = StringFormat("%s LOCK (%s) - %s waits for a reversal: stage %d/%d", (G_ST_LOCK_DIR > 0 ? "BULLISH" : "BEARISH"),
                      G_ST_LOCK_WHY, (dir > 0 ? "BUY" : "SELL"), st, LockUnlockStage);
   return true;
}

string MBStructPanelText()
{
   string arrows = "";
   string tfn[3] = {"M5", "M15", "H1"};
   for(int k = 0; k < 3; k++)
   {
      int tfi = k + 1;
      int sq = G_ST_SEQ[tfi];
      string a = (sq > 0) ? "▲" : ((sq < 0) ? "▼" : "•");
      arrows += StringFormat("%s%s %s%s", (k > 0 ? " · " : ""), tfn[k], a, (MathAbs(sq) >= 2 ? StringFormat("×%d", MathAbs(sq)) : ""));
   }
   return "Tuzilma: " + arrows + StringFormat(" (oxirgi M15: %s)", MBStQName(G_ST_LB_Q[2]));
}

string MBLockPanelText()
{
   string t = "";
   if(G_ST_LOCK_DIR != 0)
      t = StringFormat("LOCK %s · himoya %s", (G_ST_LOCK_DIR > 0 ? "▲" : "▼"), DoubleToString(G_ST_LOCK_PROT, _Digits));
   else
      t = "LOCK yo'q";
   if(G_ST_REV_DIR != 0 && G_ST_REV_STAGE > 0)
      t += StringFormat("  ·  burilish %s %d/6%s", (G_ST_REV_DIR > 0 ? "▲" : "▼"), G_ST_REV_STAGE,
                        (G_ST_REV_MSS > 0.0 ? StringFormat(" (MSS %s)", DoubleToString(G_ST_REV_MSS, _Digits)) : ""));
   else if(StringLen(G_ST_REV_TRAP) > 0)
      t += "  ·  burilish yo'q (oxirgisi tuzoq)";
   return t;
}
