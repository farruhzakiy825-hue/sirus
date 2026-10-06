//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 19_Zone_Role_Engine                             |
//| Market Brain B: a zone's role from its history, not from price   |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

//=====================================================================
// ZONE ROLE ENGINE (engine plan, phase 2)
//---------------------------------------------------------------------
// The zone map decides a level's role from where price is RIGHT NOW: anything above price is
// "resistance". So when price dipped a few points under the 4125 support, 4125 became the
// "nearest resistance" and a SELL was taken at 4126 - although the support had never really
// broken: it was swept and reclaimed.
//
// This engine replays a zone's last two days on M5 and keeps the role the market actually gave it:
//   UNTOUCHED / APPROACHING / TOUCHED  - price has not done anything decisive there
//   SWEPT      - pierced through the far edge and closed back on its side (a liquidity grab)
//   REJECTED   - touched and turned away with a rejection candle
//   BROKEN     - a GENUINE break: closes beyond the far edge (a displacement break bar, or a
//                grind of several closes); the role flips
//   RECLAIMED  - a break that failed: price closed back on the original side (fake break), or a
//                sweep that was followed by closes back above / below
//   RETESTED   - after a genuine break, price came back from the new side and was rejected:
//                the flipped role is confirmed (e.g. broken support -> retest -> bearish rejection)
//   EXPIRED    - nothing has happened there for a long time
//
// Rules for the entry side (used by the veto in phase 4; here only reported):
//   SELL at a zone whose role is still SUPPORT (never genuinely broken, or swept and reclaimed)
//        -> not a sell zone.
//   SELL at a broken support -> only after the retest has been rejected.
//   BUY mirrors this.
// The replay is computed on demand for any level a detector uses, and cached per M5 bar.
//=====================================================================

input group "42 — MARKET BRAIN: ZONE ROLE ENGINE"
input bool   EnableZoneRoleEngine     = true;   // Zona rolini tarix bo'yicha aniqlash (hozircha faqat o'qiydi va Reason Code'ga yozadi)
input int    MBZoneLookbackM5         = 576;    // Zona tarixi: shuncha M5 bar (576 = 2 kun)
input double MBZoneBandATR            = 0.30;   // Zona kengligi: daraja ± ATR(M5) x shu
input int    MBZoneAcceptClosesM5     = 2;      // Haqiqiy break: shuncha M5 yopilish narigi tomonda ...
input double MBZoneAcceptATR          = 0.25;   // ... zona chetidan kamida ATR(M5) x shu narida
input double MBZoneBreakBodyATR       = 0.8;    // ... va break shamining tanasi >= ATR(M5) x shu
input int    MBZoneGrindCloses        = 4;      // Yoki displacement'siz shuncha yopilish ketma-ket narigi tomonda
input int    MBZoneExpireBarsM5       = 288;    // Shuncha M5 bar hech narsa bo'lmasa: EXPIRED

#define MB_ZS_UNTOUCHED     0
#define MB_ZS_APPROACHING   1
#define MB_ZS_TOUCHED       2
#define MB_ZS_SWEPT         3
#define MB_ZS_REJECTED      4
#define MB_ZS_BROKEN        5
#define MB_ZS_RECLAIMED     6
#define MB_ZS_RETESTED      7
#define MB_ZS_EXPIRED       8

#define MB_ZONE_CACHE       16

struct SMBZone
{
   double   level;
   double   lo;
   double   hi;
   int      role;            // +1 support (price above it), -1 resistance (price below it), 0 unknown
   int      origin_role;     // the role when the replay first saw it
   int      state;           // MB_ZS_*
   int      prev_state;      // the decisive state before the latest one
   int      touches;
   int      sweeps;
   int      fake_breaks;
   int      breaks;
   int      rejections;
   int      reclaims;
   bool     flipped;         // genuinely broken: role differs from origin
   bool     flip_confirmed;  // and retested from the new side
   bool     pending_break;   // closes beyond the far edge at the end of the window, not yet a break
   datetime last_time;       // bar of the latest state change
   int      last_age;        // M5 bars since then
   bool     valid;
};

SMBZone  G_MB_ZC[MB_ZONE_CACHE];
datetime G_MB_ZC_BAR[MB_ZONE_CACHE];
int      G_MB_ZC_NEXT = 0;

string MBZoneStateName(const int st)
{
   switch(st)
   {
      case MB_ZS_UNTOUCHED:   return "UNTOUCHED";
      case MB_ZS_APPROACHING: return "APPROACHING";
      case MB_ZS_TOUCHED:     return "TOUCHED";
      case MB_ZS_SWEPT:       return "SWEPT";
      case MB_ZS_REJECTED:    return "REJECTED";
      case MB_ZS_BROKEN:      return "BROKEN";
      case MB_ZS_RECLAIMED:   return "RECLAIMED";
      case MB_ZS_RETESTED:    return "RETESTED";
      case MB_ZS_EXPIRED:     return "EXPIRED";
   }
   return "?";
}

string MBZoneRoleName(const int role)
{
   if(role > 0) return "SUPPORT";
   if(role < 0) return "RESISTANCE";
   return "unknown";
}

void MBZoneSetState(SMBZone &z, const int st, const datetime t)
{
   if(z.state == MB_ZS_SWEPT || z.state == MB_ZS_REJECTED || z.state == MB_ZS_BROKEN ||
      z.state == MB_ZS_RECLAIMED || z.state == MB_ZS_RETESTED)
      z.prev_state = z.state;
   z.state = st;
   z.last_time = t;
}

// Replays the zone around `level` on the M5 series r[] (newest first).
void MBZoneReplay(const double level, const MqlRates &r[], const int n, const double atr, SMBZone &z)
{
   z.level = level;
   z.valid = false;
   z.role = 0;
   z.origin_role = 0;
   z.state = MB_ZS_UNTOUCHED;
   z.prev_state = MB_ZS_UNTOUCHED;
   z.touches = 0;
   z.sweeps = 0;
   z.fake_breaks = 0;
   z.breaks = 0;
   z.rejections = 0;
   z.reclaims = 0;
   z.flipped = false;
   z.flip_confirmed = false;
   z.pending_break = false;
   z.last_time = 0;
   z.last_age = 0;

   double hw = MathMax(MBZoneBandATR * atr, 2.0 * _Point);
   z.lo = level - hw;
   z.hi = level + hw;
   if(atr <= 0.0 || n < 30)
      return;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double min_pierce = MathMax(MBSweepMinATR * atr, spread);
   double accept = MBZoneAcceptATR * atr;
   int need_closes = MathMax(1, MBZoneAcceptClosesM5);
   int grind = MathMax(need_closes + 1, MBZoneGrindCloses);

   int side = 0;            // +1 price above the zone (support), -1 below (resistance)
   int pend = 0;            // closes beyond the far edge while a break is being decided
   bool pend_body = false;  // the first break bar was a real body
   int sweep_i = -1;
   int last_i = -1;
   bool in_band_prev = false;

   for(int i = n - 1; i >= 1; i--)
   {
      double o = r[i].open, h = r[i].high, l = r[i].low, c = r[i].close;
      double range = h - l;

      if(side == 0)
      {
         if(l > z.hi) side = 1;
         else if(h < z.lo) side = -1;
         z.origin_role = side;
         z.role = side;
         continue;
      }

      bool in_band = (l <= z.hi && h >= z.lo);

      // A break being decided: count closes beyond the far edge.
      if(pend > 0)
      {
         bool beyond = (side > 0) ? (c < z.lo - accept) : (c > z.hi + accept);
         bool back   = (side > 0) ? (c >= z.lo) : (c <= z.hi);
         if(beyond)
         {
            pend++;
            if((pend >= need_closes && pend_body) || pend >= grind)
            {
               int new_side = -side;
               side = new_side;
               z.role = side;
               pend = 0;
               last_i = i;
               if(side == z.origin_role)
               {
                  // Broken back to where it started: the earlier break failed.
                  z.reclaims++;
                  z.flipped = false;
                  z.flip_confirmed = false;
                  MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time);
               }
               else
               {
                  z.breaks++;
                  z.flipped = true;
                  z.flip_confirmed = false;
                  MBZoneSetState(z, MB_ZS_BROKEN, r[i].time);
               }
            }
         }
         else if(back)
         {
            // Closed beyond, then back before acceptance: a fake break, the role holds.
            z.fake_breaks++;
            z.reclaims++;
            pend = 0;
            last_i = i;
            MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time);
         }
         in_band_prev = in_band;
         continue;
      }

      if(side > 0)
      {
         if(c < z.lo - accept)
         {
            pend = 1;
            pend_body = ((o - c) >= MBZoneBreakBodyATR * atr);
            if(pend >= need_closes && pend_body)
            {
               // need_closes == 1: one decisive close is enough.
               side = -1; z.role = side; pend = 0; last_i = i;
               if(side == z.origin_role) { z.reclaims++; z.flipped = false; MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time); }
               else { z.breaks++; z.flipped = true; z.flip_confirmed = false; MBZoneSetState(z, MB_ZS_BROKEN, r[i].time); }
            }
         }
         else if(l < z.lo - min_pierce && c >= z.lo)
         {
            z.sweeps++;
            sweep_i = i;
            last_i = i;
            MBZoneSetState(z, MB_ZS_SWEPT, r[i].time);
         }
         else if(in_band)
         {
            if(!in_band_prev)
               z.touches++;
            bool rejection = (range > 0.0 && (MathMin(o, c) - l) >= MBRejectWickRatio * range && (c - l) >= 0.6 * range);
            if(rejection)
            {
               z.rejections++;
               last_i = i;
               if(z.flipped && !z.flip_confirmed)
               {
                  z.flip_confirmed = true;   // broken resistance retested from above and held
                  MBZoneSetState(z, MB_ZS_RETESTED, r[i].time);
               }
               else
                  MBZoneSetState(z, MB_ZS_REJECTED, r[i].time);
            }
            else if(z.state == MB_ZS_UNTOUCHED || z.state == MB_ZS_APPROACHING || z.state == MB_ZS_EXPIRED)
            {
               last_i = i;
               MBZoneSetState(z, MB_ZS_TOUCHED, r[i].time);
            }
         }
         // A sweep followed by two closes back above the zone is a reclaim.
         if(z.state == MB_ZS_SWEPT && sweep_i - i >= 2 && c > z.hi && r[i + 1].close > z.hi)
         {
            z.reclaims++;
            last_i = i;
            MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time);
         }
      }
      else // side < 0
      {
         if(c > z.hi + accept)
         {
            pend = 1;
            pend_body = ((c - o) >= MBZoneBreakBodyATR * atr);
            if(pend >= need_closes && pend_body)
            {
               side = 1; z.role = side; pend = 0; last_i = i;
               if(side == z.origin_role) { z.reclaims++; z.flipped = false; MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time); }
               else { z.breaks++; z.flipped = true; z.flip_confirmed = false; MBZoneSetState(z, MB_ZS_BROKEN, r[i].time); }
            }
         }
         else if(h > z.hi + min_pierce && c <= z.hi)
         {
            z.sweeps++;
            sweep_i = i;
            last_i = i;
            MBZoneSetState(z, MB_ZS_SWEPT, r[i].time);
         }
         else if(in_band)
         {
            if(!in_band_prev)
               z.touches++;
            bool rejection = (range > 0.0 && (h - MathMax(o, c)) >= MBRejectWickRatio * range && (h - c) >= 0.6 * range);
            if(rejection)
            {
               z.rejections++;
               last_i = i;
               if(z.flipped && !z.flip_confirmed)
               {
                  z.flip_confirmed = true;   // broken support retested from below and rejected
                  MBZoneSetState(z, MB_ZS_RETESTED, r[i].time);
               }
               else
                  MBZoneSetState(z, MB_ZS_REJECTED, r[i].time);
            }
            else if(z.state == MB_ZS_UNTOUCHED || z.state == MB_ZS_APPROACHING || z.state == MB_ZS_EXPIRED)
            {
               last_i = i;
               MBZoneSetState(z, MB_ZS_TOUCHED, r[i].time);
            }
         }
         if(z.state == MB_ZS_SWEPT && sweep_i - i >= 2 && c < z.lo && r[i + 1].close < z.lo)
         {
            z.reclaims++;
            last_i = i;
            MBZoneSetState(z, MB_ZS_RECLAIMED, r[i].time);
         }
      }
      in_band_prev = in_band;
   }

   if(side == 0)
      return;   // price never left the band in the whole window - no role to speak of

   z.valid = true;
   z.last_age = (last_i > 0) ? last_i : n;
   if(z.state == MB_ZS_UNTOUCHED || z.last_age > MBZoneExpireBarsM5)
   {
      double px = r[1].close;
      double dist = (side > 0) ? (px - z.hi) : (z.lo - px);
      if(z.state != MB_ZS_UNTOUCHED && z.last_age > MBZoneExpireBarsM5)
         z.state = MB_ZS_EXPIRED;
      else if(dist >= 0.0 && dist <= atr)
         z.state = MB_ZS_APPROACHING;
   }
   // A break still being decided at the end of the window: the role has not flipped yet.
   z.pending_break = (pend > 0);
}

// The zone around `level`, replayed (cached per M5 bar). false when it cannot be read.
// AUDIT FIX (speed): levels whose replay found no valid zone are remembered per M5 bar too - they
// were re-replayed (CopyRates 576 + full pass) on every tick, from the veto and the judge both.
double   G_MB_ZN_LV[MB_ZONE_CACHE];
datetime G_MB_ZN_BAR[MB_ZONE_CACHE];
int      G_MB_ZN_NEXT = 0;

bool MBZoneRead(const double level, SMBZone &z)
{
   if(!EnableZoneRoleEngine || level <= 0.0)
      return false;

   datetime bar = iTime(_Symbol, PERIOD_M5, 0);
   double atr_pts = (G_MB_ATR[1] > 0.0) ? G_MB_ATR[1] : ATRPointsManual(PERIOD_M5, 14, 1);
   if(atr_pts <= 0.0)
      return false;
   double atr = atr_pts * _Point;

   for(int i = 0; i < MB_ZONE_CACHE; i++)
      if(G_MB_ZC_BAR[i] == bar && G_MB_ZC[i].valid && MathAbs(G_MB_ZC[i].level - level) <= 0.05 * atr)
      {
         z = G_MB_ZC[i];
         return true;
      }

   for(int i = 0; i < MB_ZONE_CACHE; i++)
      if(G_MB_ZN_BAR[i] == bar && MathAbs(G_MB_ZN_LV[i] - level) <= 0.05 * atr)
         return false;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M5, 0, MathMax(60, MBZoneLookbackM5), r);
   if(n < 30)
      return false;

   MBZoneReplay(level, r, n, atr, z);
   if(!z.valid)
   {
      int ns = G_MB_ZN_NEXT % MB_ZONE_CACHE;
      G_MB_ZN_LV[ns] = level;
      G_MB_ZN_BAR[ns] = bar;
      G_MB_ZN_NEXT++;
      return false;
   }

   int slot = G_MB_ZC_NEXT % MB_ZONE_CACHE;
   G_MB_ZC[slot] = z;
   G_MB_ZC_BAR[slot] = bar;
   G_MB_ZC_NEXT++;
   return true;
}

string MBZoneText(const SMBZone &z)
{
   if(!z.valid)
      return "-";
   string hist = MBZoneStateName(z.state);
   if(z.prev_state != MB_ZS_UNTOUCHED && z.prev_state != z.state)
      hist = MBZoneStateName(z.prev_state) + " -> " + hist;
   string role = MBZoneRoleName(z.role);
   if(z.flipped)
   {
      role += (z.origin_role > 0 ? " (broken support" : " (broken resistance");
      role += (z.flip_confirmed ? ", retested)" : ", not retested)");
   }
   if(z.pending_break)
      role += " [break being decided]";
   return StringFormat("%s %s | %s | touches %d, sweeps %d, fake breaks %d, breaks %d, rejections %d | %d M5 bars ago",
                       DoubleToString(z.level, _Digits), role, hist,
                       z.touches, z.sweeps, z.fake_breaks, z.breaks, z.rejections, z.last_age);
}

// What the zone at `level` says about an entry in direction dir.
//   +1 allow, 0 wait (role about to be confirmed), -1 the zone does not support this entry.
int MBZoneEntryVerdict(const int dir, const double level, string &why)
{
   why = "";
   SMBZone z;
   if(!MBZoneRead(level, z))
   {
      why = "zone role unknown";
      return 1;
   }

   if(dir < 0)
   {
      if(z.role > 0)
      {
         why = StringFormat("zone %s is still SUPPORT%s - not a sell zone",
                            DoubleToString(level, _Digits),
                            ((z.state == MB_ZS_SWEPT || z.state == MB_ZS_RECLAIMED || z.prev_state == MB_ZS_SWEPT) ? " (swept and reclaimed)" : " (never genuinely broken)"));
         return -1;
      }
      if(z.flipped && !z.flip_confirmed)
      {
         why = StringFormat("broken support %s not yet retested with a bearish rejection", DoubleToString(level, _Digits));
         return 0;
      }
      why = StringFormat("zone %s is RESISTANCE (%s)", DoubleToString(level, _Digits), MBZoneStateName(z.state));
      return 1;
   }

   if(z.role < 0)
   {
      why = StringFormat("zone %s is still RESISTANCE%s - not a buy zone",
                         DoubleToString(level, _Digits),
                         ((z.state == MB_ZS_SWEPT || z.state == MB_ZS_RECLAIMED || z.prev_state == MB_ZS_SWEPT) ? " (swept and reclaimed)" : " (never genuinely broken)"));
      return -1;
   }
   if(z.flipped && !z.flip_confirmed)
   {
      why = StringFormat("broken resistance %s not yet retested with a bullish rejection", DoubleToString(level, _Digits));
      return 0;
   }
   why = StringFormat("zone %s is SUPPORT (%s)", DoubleToString(level, _Digits), MBZoneStateName(z.state));
   return 1;
}
