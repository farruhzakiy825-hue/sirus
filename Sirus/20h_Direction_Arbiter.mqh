//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 20h_Direction_Arbiter                           |
//| One direction authority for a FIRST entry: H1/H4 say whether a    |
//| side can cost a grid, M15 picks the side, M5/M1 the moment.       |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+
//
// WHY (audit 2026-10-09): the global bias was built from M15 structure alone (20_Market_Brain
// `bias = s15`); H1 and H4 only moved its confidence by -10..+8, and the D1/H4 trend was asked only
// when the bias was neutral - which never happened in the shadow data. But this robot asks two
// different questions, of two different sizes:
//
//   1. Will the TP be paid?   TP ~224 points - smaller than one M1 ATR. M1/M5 answer it.
//   2. If wrong, does the first entry cost a grid?   The grid step ~5500 points is about one H1 ATR.
//      H1/H4 answer it - whether the market can run an H1 ATR against the entry.
//
// M15 fits neither; and the shadow ledger agrees: entries WITH the M15 bias needed the grid 12.2% of
// the time, entries against it 8.3% - M15 does not predict the grid. Only a strongly opposed bias
// (-3) did (18% vs 6-8%).
//
// THE ARBITER, for each side:
//   DENY     H1 and H4 both against (one of them established, |state| >= 2) and no confirmed H1/H4/KEY
//            liquidity reversal toward the side since their last break - or one of them against while
//            H1 AND M15 candle pressure still push against it.
//   CAUTION  one of H1 / H4 against (or both, answered by a reversal, or price at the side's own fresh
//            HTF zone with M15 structure already turned): the entry needs M5 structure or the local leg
//            its way AND a trigger now.
//   OK       neither against.
// And M15 becomes the middle layer (21 V0): inside an H1+H4 trend a weak M15 counter-move (bias -1/-2)
// does not forbid the trend side once M5 / the local leg has turned back and a trigger fires.
//
// Every first entry asks it (21 veto "VH", the candidates through MBCandOk's veto probe). The legacy
// HTF readers that trimmed lot and scored the grid from a different source (Kalman H1, legacy BOS)
// read it too when it is on (11, 13). It never touches an open basket or a grid add.

input group "BRAIN ▸ Direction arbiter (H1/H4 > M15 > M5/M1)"
// EnableDirectionArbiter: Yo'nalish hakami: H1/H4 grid xavfini, M15 tomonni, M5/M1 vaqtni hal qiladi (birinchi kirish uchun)
input bool   EnableDirectionArbiter   = true;   // Direction arbiter: H1/H4 grid risk, M15 side, M5/M1 timing
input bool   ArbiterPrintOnUse        = true;   // Arbiter print on use (on/off)

#define ARB_OK      0
#define ARB_CAUTION 1
#define ARB_DENY    2

int      G_ARB_LVL[2];          // 0 = SELL, 1 = BUY
string   G_ARB_WHY[2];
int      G_ARB_TICK = -1;       // memo: once per tick (the probes ask it for every candidate)

bool MBArbiterOn()
{
   return (EnableDirectionArbiter && EnableMarketBrain && EnableMarketBrainEngines && G_MB_BRAIN_PRIMED);
}

int MBBiasSignNow() { return MBSign(G_MB_BIAS); }
int MBTFStateSign(const int tfi) { return (tfi >= 0 && tfi < MB_TF_COUNT) ? MBSign(G_MB_TF_STATE[tfi]) : 0; }

// How many of H1 / H4 stand against / with dir (0..2).
int MBArbiterHTFAgainst(const int dir)
{
   if(dir == 0) return 0;
   return ((MBSign(G_MB_TF_STATE[3]) == -dir) ? 1 : 0) + ((MBSign(G_MB_TF_STATE[4]) == -dir) ? 1 : 0);
}

// H1 and H4 both with dir, at least one of them established.
bool MBArbiterHTFWithStrong(const int dir)
{
   if(dir == 0) return false;
   int h1 = G_MB_TF_STATE[3], h4 = G_MB_TF_STATE[4];
   return (MBSign(h1) == dir && MBSign(h4) == dir && (MathAbs(h1) >= 2 || MathAbs(h4) >= 2));
}

string MBArbStateTxt(const int s)
{
   if(s >= 3) return "UP";
   if(s == 2) return "up";
   if(s == 1) return "turn-up";
   if(s == -1) return "turn-dn";
   if(s == -2) return "dn";
   if(s <= -3) return "DN";
   return "flat";
}

int MBArbiterEval(const int dir, string &why)
{
   why = "";
   int h1 = G_MB_TF_STATE[3], h4 = G_MB_TF_STATE[4];
   bool h1a = (MBSign(h1) == -dir), h4a = (MBSign(h4) == -dir);
   if(!h1a && !h4a)
      return ARB_OK;
   bool strong = (h1a && MathAbs(h1) >= 2) || (h4a && MathAbs(h4) >= 2);

   // The answer that cancels it: a confirmed H1 / H4 / KEY liquidity reversal toward dir after the bar
   // of the newest H1 / H4 break against dir had closed.
   datetime since = 0;
   for(int tfi = 3; tfi <= 4; tfi++)
   {
      int le = MBLastStructureEvent(tfi);
      if(le >= 0 && G_MB_EV[le].dir == -dir)
         since = MathMax(since, G_MB_EV[le].time + PeriodSeconds(MBEventTF(tfi)));
   }
   string rw = "";
   datetime rt = 0;
   bool rev = MBReversalAfter(dir, 3, 4, true, since, rw, rt);

   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool own_zone = EnableHTFZones && px > 0.0 && MBHTFZoneAgainst(-dir, px) >= 0;   // inside / at the side's own fresh HTF zone
   bool m15_with = (MBSign(G_MB_TF_STATE[2]) == dir);
   bool push = (MBPressureSide(3) == -dir && MBPressureSide(2) == -dir);
   string st = StringFormat("H4 %s, H1 %s", MBArbStateTxt(h4), MBArbStateTxt(h1));

   if(h1a && h4a && strong && !rev)
   {
      if(own_zone && m15_with && !push)
      {
         why = st + " against - but at its own HTF zone with M15 turned";
         return ARB_CAUTION;
      }
      why = st + " against, no HTF reversal - a wrong first entry here is a grid";
      return ARB_DENY;
   }
   if(push && !rev)
   {
      why = st + StringFormat(" - %s against and H1 + M15 still pushing against", (h1a ? "H1" : "H4"));
      return ARB_DENY;
   }
   why = st + (rev ? " against, answered by " + rw : StringFormat(" - %s against", (h1a && h4a) ? "H1+H4" : (h1a ? "H1" : "H4")));
   return ARB_CAUTION;
}

int MBArbiterLevel(const int dir, string &why)
{
   why = "";
   if(!MBArbiterOn() || dir == 0)
      return ARB_OK;
   if(G_ARB_TICK != G_TICK_COUNT)
   {
      G_ARB_TICK = G_TICK_COUNT;
      for(int k = 0; k <= 1; k++)
         G_ARB_LVL[k] = MBArbiterEval((k == 1) ? 1 : -1, G_ARB_WHY[k]);
   }
   int k = (dir > 0) ? 1 : 0;
   why = G_ARB_WHY[k];
   return G_ARB_LVL[k];
}

// The veto rule (21, "VH"): DENY refuses; CAUTION refuses unless M5 / the local leg and a trigger agree.
bool MBArbiterBlocks(const int dir, string &why)
{
   why = "";
   string w = "";
   int lv = MBArbiterLevel(dir, w);
   if(lv == ARB_OK)
      return false;
   string side = (dir > 0) ? "BUY" : "SELL";
   if(lv == ARB_DENY)
   {
      why = StringFormat("VH arbiter: no %s - %s", side, w);
   }
   else
   {
      bool m5 = (MBM5StructDir() == dir || MBLayerLocal() == dir);
      bool trig = MBHasTriggerNow(dir);
      if(m5 && trig)
         return false;
      why = StringFormat("VH arbiter caution: %s - %s needs M5 structure / local leg (%s) and a trigger (%s)",
                         w, side, (m5 ? "yes" : "no"), (trig ? "yes" : "no"));
   }
   static string last_print = "";
   static datetime last_t = 0;
   if((ArbiterPrintOnUse && G_VERBOSE) && !G_MB_VETO_PROBE && (why != last_print || TimeCurrent() - last_t >= 300))
   {
      last_print = why;
      last_t = TimeCurrent();
      PrintFormat("[SIRUS ARBITER] %s", why);
   }
   return true;
}

// Panel: what each timeframe says and the verdict per side.
string MBArbiterText()
{
   if(!EnableDirectionArbiter)
      return "";
   string wb = "", ws = "";
   int lb = MBArbiterLevel(1, wb), ls = MBArbiterLevel(-1, ws);
   string v[3] = {"ochiq", "ehtiyot", "TAQIQ"};
   return StringFormat("Hakam: H4 %s · H1 %s · M15 %s · M5 %s | BUY %s · SELL %s",
                       MBArbStateTxt(G_MB_TF_STATE[4]), MBArbStateTxt(G_MB_TF_STATE[3]),
                       MBArbStateTxt(G_MB_TF_STATE[2]), MBArbStateTxt(G_MB_TF_STATE[1]),
                       v[MathMax(0, MathMin(2, lb))], v[MathMax(0, MathMin(2, ls))]);
}
