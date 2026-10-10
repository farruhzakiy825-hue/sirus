//+------------------------------------------------------------------+
//| Sirus_Brain_V8 - 10_Basket_Stats_Context                         |
//| Lot caps, basket stats, market context readers                   |
//| Part of Sirus_Brain_V8.mq5. Include ORDER matters - do not       |
//| compile this file on its own; compile Sirus_Brain_V8.mq5.        |
//+------------------------------------------------------------------+

void UpdatePack4MiniLotCaps(const string source)
{
   G_P4L_ENTRY_BLOCK = false;
   G_P4L_GRID_BLOCK = false;
   G_P4L_VALID = true;

   if(!UsePack4MiniLotCaps)
   {
      G_P4L_STATUS = "P4L: OFF";
      G_P4L_REASON = "disabled";
      G_P4L_DETAIL = "P4L DETAIL: disabled";
      return;
   }

   string profile = "";
   double first_cap = 0.0;
   double grid_cap = 0.0;
   int max_orders = 0;
   double max_dd = 0.0;

   if(P4MiniUseProfileCaps)
      P4LotProfileValues(profile, first_cap, grid_cap, max_orders, max_dd);
   else
   {
      profile = "CUSTOM";
      first_cap = P4MiniHardCapFirstLot;
      grid_cap = P4MiniHardCapGridLot;
      max_orders = MaxOrders;
      max_dd = RecoveryMaxDDForNewGrid;
   }

   if(P4MiniHardCapFirstLot > 0.0)
      first_cap = MathMin(first_cap, P4MiniHardCapFirstLot);
   if(P4MiniHardCapGridLot > 0.0)
      grid_cap = MathMin(grid_cap, P4MiniHardCapGridLot);

   G_P4L_FIRST_CAP = first_cap;
   G_P4L_GRID_CAP = grid_cap;
   G_P4L_MAX_ORDERS = max_orders;
   G_P4L_MAX_DD = max_dd;

   if(P4MiniBlockGridAboveMaxOrders && max_orders > 0 && G_BASKET_ORDERS >= max_orders)
   {
      G_P4L_GRID_BLOCK = true;
      G_P4L_REASON = StringFormat("max orders %d/%d", G_BASKET_ORDERS, max_orders);
   }
   else if(P4MiniBlockGridAboveProfileDD && max_dd > 0.0 && G_BASKET_DD_PERCENT >= max_dd)
   {
      G_P4L_GRID_BLOCK = true;
      G_P4L_REASON = StringFormat("profile DD %.2f/%.2f%%", G_BASKET_DD_PERCENT, max_dd);
   }
   else
   {
      G_P4L_REASON = "valid";
   }

   G_P4L_VALID = (!G_P4L_ENTRY_BLOCK && !G_P4L_GRID_BLOCK);

   G_P4L_STATUS = StringFormat("P4L: profile=%s valid=%s firstCap=%.2f gridCap=%.2f maxOrders=%d maxDD=%.2f",
                               profile,
                               BoolText(G_P4L_VALID),
                               G_P4L_FIRST_CAP,
                               G_P4L_GRID_CAP,
                               G_P4L_MAX_ORDERS,
                               G_P4L_MAX_DD);

   G_P4L_DETAIL = StringFormat("P4L DETAIL: reason=%s basketOrders=%d basketDD=%.2f lastLot=%.2f",
                               G_P4L_REASON,
                               G_BASKET_ORDERS,
                               G_BASKET_DD_PERCENT,
                               G_P4L_LAST_ADJUSTED_LOT);

   string signature = G_P4L_STATUS + "|" + G_P4L_DETAIL + "|" + IntegerToString(G_BARS_SEEN);

   if(PrintPack4MiniLotEvents && signature != G_P4L_LAST_SIGNATURE)
   {
      if(!G_P4L_VALID || G_P4L_LAST_SIGNATURE == "")
      {
         G_P4L_EVENT_COUNT++;
         PrintFormat("[SIRUS v31.6 PHASE 22.2 P4L] %s | %s | source=%s",
                     G_P4L_STATUS,
                     G_P4L_DETAIL,
                     source);
      }

      G_P4L_LAST_SIGNATURE = signature;
   }
}

double Pack4MiniAdjustLot(const double lot, const bool grid_lot)
{
   if(!UsePack4MiniLotCaps)
      return lot;

   double cap = (grid_lot ? G_P4L_GRID_CAP : G_P4L_FIRST_CAP);

   if(cap <= 0.0)
      return lot;

   double adjusted = MathMin(lot, cap);
   G_P4L_LAST_ADJUSTED_LOT = adjusted;

   return adjusted;
}

bool Pack4MiniLotAllowsEntry(string &reason)
{
   if(!UsePack4MiniLotCaps)
   {
      reason = "P4L entry pass";
      return true;
   }

   if(G_P4L_ENTRY_BLOCK)
   {
      reason = "P4L entry block: " + G_P4L_REASON;
      return false;
   }

   reason = "P4L entry pass";
   return true;
}

bool Pack4MiniLotAllowsGrid(string &reason)
{
   if(!UsePack4MiniLotCaps)
   {
      reason = "P4L grid pass";
      return true;
   }

   if(G_P4L_GRID_BLOCK)
   {
      reason = "P4L grid block: " + G_P4L_REASON;
      return false;
   }

   reason = "P4L grid pass";
   return true;
}

//==================================================================//
//  PHASE 21.3 GRID / RECOVERY ENGINE
//==================================================================//
// FIX(dd-commission): basket profit and DD read POSITION_PROFIT + POSITION_SWAP only. On a commission
// account the entry commission is already charged, so every DD figure (Basket SL, emergency close) was
// understated by it. The entry commission of each position is looked up once from its deals and cached.
#define POS_COMM_CACHE 128
ulong  G_POS_COMM_TICKET[POS_COMM_CACHE];
double G_POS_COMM_VALUE[POS_COMM_CACHE];
int    G_POS_COMM_NEXT = 0;

double PositionCommissionCached(const ulong position_id)
{
   if(position_id == 0)
      return 0.0;
   for(int i = 0; i < POS_COMM_CACHE; i++)
      if(G_POS_COMM_TICKET[i] == position_id)
         return G_POS_COMM_VALUE[i];

   double comm = 0.0;
   if(HistorySelectByPosition(position_id))
   {
      int deals = HistoryDealsTotal();
      for(int d = 0; d < deals; d++)
      {
         ulong deal = HistoryDealGetTicket(d);
         if(deal == 0)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            comm += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      }
   }
   else
      return 0.0;   // history not available yet - do not cache a guess, ask again next time

   G_POS_COMM_TICKET[G_POS_COMM_NEXT] = position_id;
   G_POS_COMM_VALUE[G_POS_COMM_NEXT]  = comm;
   G_POS_COMM_NEXT = (G_POS_COMM_NEXT + 1) % POS_COMM_CACHE;
   return comm;
}

// Floating result of the currently selected position, commission included.
double SelectedPositionNetProfit()
{
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP)
        + PositionCommissionCached((ulong)PositionGetInteger(POSITION_IDENTIFIER));
}

bool GetSirusBasketStats(int &orders,
                          double &total_volume,
                          double &avg_price,
                          double &profit,
                          long &direction,
                          double &last_price,
                          double &last_lot,
                          datetime &last_time)
{
   orders = 0;
   total_volume = 0.0;
   avg_price = 0.0;
   profit = 0.0;
   direction = -1;
   last_price = 0.0;
   last_lot = 0.0;
   last_time = 0;

   double weighted_sum = 0.0;
   int total = PositionsTotal();

   for(int i=0; i<total; i++)
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

      long ptype = PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

      // V31.6z70 fix: real accounting bug found via audit of the trading path. This read
      // POSITION_PROFIT only - excluding SWAP - while CloseSirusBasket and the independent
      // Emergency Force-Close net both include it. So G_BASKET_PROFIT, the figure that drives
      // basket DD%, Basket SL, TP and every risk decision, systematically UNDER-reported the
      // real loss. That matters most in exactly the scenario this whole session has been about:
      // a basket held for days, where XAUUSD swap is typically negative and compounds nightly.
      // The bot could read DD as 45% while the true figure was 48%, firing the 50% stop late -
      // and it left the backup safety net more accurate than the primary system it backs up.
      double pprofit = SelectedPositionNetProfit();   // FIX(dd-commission)
      datetime ptime = (datetime)PositionGetInteger(POSITION_TIME);

      if(vol <= 0.0 || open_price <= 0.0)
         continue;

      if(direction == -1)
         direction = ptype;
      else if(GridSameDirectionOnly && direction != ptype)
      {
         // Mixed basket is not managed by grid in Phase 21.3.
         direction = -2;
      }

      orders++;
      total_volume += vol;
      weighted_sum += open_price * vol;
      profit += pprofit;

      if(ptime >= last_time)
      {
         last_time = ptime;
         last_price = open_price;
         last_lot = vol;
      }
   }

   if(total_volume > 0.0)
      avg_price = weighted_sum / total_volume;

   return (orders > 0 && total_volume > 0.0);
}

double AccountDDPercentApprox()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   // FIX(dd-equity-zero-reads-as-100pct): equity was unguarded. A transient equity==0 read while
   // balance is already populated - terminal starting, reconnecting, or CoreUpdate running from
   // OnTimer with no live quotes - produced dd = 100%, which now (since the loss tiers were moved
   // above the ENV/spread gates, deliberately) reaches the emergency close and would shut a
   // healthy basket at startup. An equity of exactly zero is never a real reading here.
   if(balance <= 0.0 || equity <= 0.0)
      return 0.0;

   double dd = (balance - equity) / balance * 100.0;
   if(dd < 0.0)
      dd = 0.0;
   return dd;
}

// V29 fix: the basket's OWN floating loss as % of balance, isolated from other symbols/positions
// on the same account. AccountDDPercentApprox() was previously (mis)used for basket-level decisions,
// which is wrong on any account running more than one symbol/instance - this is the correct scope.
double BasketDDPercentApprox(const double basket_profit)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0 || basket_profit >= 0.0)
      return 0.0;

   return MathAbs(basket_profit) / balance * 100.0;
}

// V30.2 fix: safe partial-close volume.
// Old code: NormalizeVolumeSafe(pos_vol * pct) rounds UP to broker vmin, so a
// vmin-sized position got FULLY closed instead of trimmed, and partials leaving
// a remainder below vmin were rejected by the broker. Returns 0.0 = do not trim.
double SafePartialVolume(const double pos_vol, const double percent)
{
   if(pos_vol <= 0.0 || percent <= 0.0 || percent >= 100.0)
      return 0.0;

   double vmin = 0.0, vstep = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, vmin);
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, vstep);
   if(vmin <= 0.0 || vstep <= 0.0)
      return 0.0;

   double close_vol = NormalizeVolumeSafe(pos_vol * percent / 100.0);

   // Must actually be a PARTIAL close.
   if(close_vol >= pos_vol)
      return 0.0;

   // Remainder must stay tradeable (>= vmin), else broker rejects or leaves dust.
   double remainder = pos_vol - close_vol;
   if(remainder < vmin - vstep * 0.5)
      return 0.0;

   return close_vol;
}

double CurrentBasketPoints(const long direction, const double avg_price)
{
   if(direction != POSITION_TYPE_BUY && direction != POSITION_TYPE_SELL)
      return 0.0;

   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);

   if(avg_price <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return 0.0;

   if(direction == POSITION_TYPE_BUY)
      return (bid - avg_price) / _Point;

   return (avg_price - ask) / _Point;
}

// ============================================================================
// V116: STRUCTURE vs THE OPEN BASKET.
// ----------------------------------------------------------------------------
// Everything the structure modules learned was being spent on ONE decision: whether
// to open a new trade. But the EA's worst losses come from baskets already open and
// sitting in drawdown - and during those the structure reader is watching the very
// turn that is hurting them, silently.
//
// This answers one question: has the market structure turned AGAINST the basket we
// are holding? Two ways that happens:
//   1. The structure that supported the basket just BROKE (CHoCH in the basket's
//      own direction) - the chain the position was riding has failed.
//   2. The OPPOSING structure just EXTENDED (BOS against us) - the other side is
//      actively taking ground.
// Either way the basket is now swimming upstream, and the sensible response is to
// take what the market offers sooner rather than wait for the original target.
// ============================================================================
// ============================================================================
// V117: MARKET VERDICT - how much do the independent readings agree?
// ----------------------------------------------------------------------------
// The EA now has several genuinely independent ways of reading direction:
//   - the M15 swing chain          (price structure)
//   - the H1 swing chain           (price structure, larger frame)
//   - the break staircase          (zone behaviour)
//   - the global trend confidence  (indicators, D1/H4/H1)
//   - the local trend confidence   (indicators, M5/M15/M30)
// Each already contributes its own bonus or penalty, but nothing ever asked the
// obvious question: DO THEY AGREE? "Four of five say bullish" and "two say bullish,
// two say bearish" produce similar scores today, yet they are completely different
// situations - one is a market with a clear owner, the other is a market that has
// not decided.
//
// The verdict measures agreement only. It does not re-judge direction (that would
// double-count what the individual modules already did); it reports how unanimous
// the readings are, so strong consensus can be rewarded and genuine disagreement
// can be treated as what it is: a market to stay out of.
// ============================================================================
// ============================================================================
// V118: ROOM TO TARGET - is there space for this trade to actually work?
// ----------------------------------------------------------------------------
// Every check so far asks WHICH WAY the market is going. None asks whether there
// is enough space in front of the entry for the target to be reached. On a scalper
// with a ~$2.50 basket target that omission matters: if the nearest opposing wall
// sits $1.00 away, the trade is being opened into a ceiling it cannot clear, and
// the most likely outcome is a stall followed by a reversal into the basket.
//
// Two things can stand in the way, and the nearer one is what counts:
//   - the closest opposing zone (resistance above a buy, support below a sell)
//   - the structure's own continuation level, which price must break to extend
// The result is compared against the basket target: a trade with less room than
// its own target is structurally unlikely to reach it.
//
// Returns the distance in points, or a large number when nothing is in the way.
// ============================================================================
// Zone-map swing cache dimensions. These are preprocessor defines, so unlike functions they must
// appear BEFORE the first line that uses them - the zone-band reader below is the earliest user.
// (SIRUS_ZM_CACHE_* defines live at the top of the file, with the other structural defines)

// ============================================================================
// V119: ZONE BANDS - group nearby swings into ONE zone, sized by the market.
// ----------------------------------------------------------------------------
// The EA treats every swing as its own level and decides a level's role purely by
// whether it sits above or below price. A real zone has thickness. On the user's
// chart the 4440-4455 band acted as resistance, broke, became support, then turned
// back into resistance - and inside that band there are swing highs AND swing lows.
//
// With price inside such a band the EA finds a swing high just above it (reads
// "resistance", wants to sell) and a swing low just below (reads "support", wants
// to buy) at the same moment. Both signals are born and the higher score wins by
// accident - the reported "selling in a buy zone, buying in a sell zone".
//
// Two things this must get right, both raised by the user:
//   1. Zones live on more than one timeframe. An M5 band, an M15 band and an H1
//      band are all real; price inside ANY of them has an undefined role.
//   2. Zone thickness is not a fixed number of dollars. Small zones and large
//      zones both exist, so the clustering tolerance is derived from that
//      timeframe's own ATR rather than hard-coded - the market sizes its zones,
//      and the resulting band is as thick as the swings inside it turn out to be.
// ============================================================================
// ============================================================================
// V140: LIQUIDITY MAP - where the stops are, and which way price is pulled.
// ----------------------------------------------------------------------------
// The EA already recognises a sweep AFTER it happens. That is the wrong end of the
// event: by the time the sweep is visible, the move it caused is half over.
//
// Stops cluster in one predictable place - just beyond swing extremes, and most
// heavily where several swings line up at the SAME level. Equal highs are a shelf
// of buy-stops; equal lows are a shelf of sell-stops. Price is drawn to those
// shelves because filling them is where the volume is, which is why a market so
// often runs to an obvious high, takes it, and reverses.
//
// This measures that pull BEFORE it happens: how many swings line up, how tight
// the alignment is, and how far away the pool sits. A pool sitting against the
// entry direction is a reason to wait - not because the entry is wrong, but
// because price will most likely visit the pool first and the entry can be had
// from a better price afterwards.
//
// Returns the pool's weight (0 = none). Direction and distance come back through
// the reference parameters.
// ============================================================================
// V142: EVENT CHAIN - the market as a sequence, not a snapshot.
// ----------------------------------------------------------------------------
// The EA sees every event in isolation: a zone broke, an impulse fired, structure
// changed, liquidity was swept. Each is scored the moment it appears and then
// forgotten. Nothing ever asks what came BEFORE it.
//
// But these events are not independent - they are links in a chain, and the chain
// is what a trader actually reads: "range broke, price ran to the highs, liquidity
// was taken, structure flipped" is a complete story that says what comes next. The
// same CHoCH means opposite things depending on whether a sweep preceded it or not.
//
// This records events in order with their bar, price and direction. On its own it
// only remembers; what it enables is the next step - reading the chain to anticipate
// the following link instead of reacting to each one after the fact.
// ============================================================================

#define SIRUS_EVENT_MAX 24

// (CHAIN_PAT_* defines live at the top of the file - see below #property block)

// Event kinds. Kept deliberately coarse - the chain is about SEQUENCE, and too many
// distinct kinds would make recurring patterns impossible to recognise.
#define EVT_NONE            0
#define EVT_ZONE_BREAK      1   // a level gave way
#define EVT_IMPULSE         2   // a thrust / spike ran
#define EVT_BOS             3   // structure extended in its own direction
#define EVT_CHOCH           4   // structure broke - character changing
#define EVT_SWEEP           5   // liquidity taken beyond an extreme
#define EVT_RANGE_BREAK     6   // a range gave way

int      G_EVT_KIND[SIRUS_EVENT_MAX];
int      G_EVT_DIR[SIRUS_EVENT_MAX];      // +1 up, -1 down
int      G_EVT_BAR[SIRUS_EVENT_MAX];      // G_BARS_SEEN when recorded
double   G_EVT_PRICE[SIRUS_EVENT_MAX];
int      G_EVT_COUNT = 0;                  // total recorded (may exceed the ring size)

string EventKindName(const int kind)
{
   switch(kind)
   {
      case EVT_ZONE_BREAK:  return "zone-break";
      case EVT_IMPULSE:     return "impulse";
      case EVT_BOS:         return "BOS";
      case EVT_CHOCH:       return "CHoCH";
      case EVT_SWEEP:       return "sweep";
      case EVT_RANGE_BREAK: return "range-break";
   }
   return "none";
}

// Newest event is index 0, older ones follow. Returns EVT_NONE past the end.
int EventAt(const int back, int &dir, int &bar, double &price)
{
   dir = 0; bar = 0; price = 0.0;
   if(back < 0 || back >= MathMin(G_EVT_COUNT, SIRUS_EVENT_MAX))
      return EVT_NONE;

   int idx = ((G_EVT_COUNT - 1 - back) % SIRUS_EVENT_MAX + SIRUS_EVENT_MAX) % SIRUS_EVENT_MAX;
   dir   = G_EVT_DIR[idx];
   bar   = G_EVT_BAR[idx];
   price = G_EVT_PRICE[idx];
   return G_EVT_KIND[idx];
}

void RecordEvent(const int kind, const int dir, const double price)
{
   if(!EnableEventChain || kind == EVT_NONE)
      return;

   // Collapse repeats: the same kind in the same direction within a few bars is one
   // event still developing, not a new link in the chain.
   int last_dir = 0, last_bar = 0; double last_price = 0.0;
   int last_kind = EventAt(0, last_dir, last_bar, last_price);
   if(last_kind == kind && last_dir == dir &&
      (G_BARS_SEEN - last_bar) < MathMax(1, EventChainDedupeBars))
      return;

   int idx = G_EVT_COUNT % SIRUS_EVENT_MAX;
   G_EVT_KIND[idx]  = kind;
   G_EVT_DIR[idx]   = dir;
   G_EVT_BAR[idx]   = G_BARS_SEEN;
   G_EVT_PRICE[idx] = price;
   G_EVT_COUNT++;

   if((EventChainPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v142 EVENT] %s %s at %.2f (chain length %d)",
                  EventKindName(kind), (dir > 0 ? "up" : (dir < 0 ? "down" : "-")),
                  price, MathMin(G_EVT_COUNT, SIRUS_EVENT_MAX));
}

// Scans the current state once per bar and appends anything new to the chain.
void EventChainUpdate()
{
   static int last_bar = -100000;
   if(last_bar > G_BARS_SEEN) last_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value
   if(!EnableEventChain || last_bar == G_BARS_SEEN)
      return;
   last_bar = G_BARS_SEEN;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   // 1. Structure events - the clearest statements the market makes.
   MarketStructureRead();
   if(G_STRUCTURE_EVENT == 1)
      RecordEvent(EVT_BOS, G_STRUCTURE_DIR, mid);
   else if(G_STRUCTURE_EVENT == -1)
      RecordEvent(EVT_CHOCH, -G_STRUCTURE_DIR, mid);   // a break points AGAINST the old chain

   // 2. A level giving way.
   string zb_detail = "";
   int zb_dir = RecentZoneBreakDirection(zb_detail);
   if(zb_dir != 0)
      RecordEvent(EVT_ZONE_BREAK, zb_dir, mid);

   // 3. A thrust running.
   int imp_dir = SpikeImpulseDir();
   if(imp_dir == 0)
      imp_dir = RecentThrustDir();
   if(imp_dir != 0)
      RecordEvent(EVT_IMPULSE, imp_dir, mid);

   // 4. Liquidity taken - detected as a sweep in the existing engine.
   string sw_detail = "";
   int sweep_dir = RecentMajorSweepDirection(sw_detail);
   if(sweep_dir != 0)
      RecordEvent(EVT_SWEEP, sweep_dir, mid);

   // V145: grade any prediction whose horizon has passed, then record the current one.
   // Settling first means a fresh prediction never overwrites one still being judged.
   ChainPatternSettle();

   if(EnableChainLearning)
   {
      double ec_conf = 0.0;
      string ec_detail = "";
      int ec_pat = CHAIN_PAT_NONE;
      int ec_dir = ChainExpectation(ec_conf, ec_detail, ec_pat);
      if(ec_dir != 0 && ec_pat != CHAIN_PAT_NONE)
         ChainPatternPredict(ec_pat, ec_dir, mid);
   }
}

// ============================================================================
// V145: PATTERN OUTCOMES - the chain grades its own predictions.
// ----------------------------------------------------------------------------
// The confidences attached to each chain pattern were set by hand. They are
// reasonable, but "reasonable" is a guess: nobody has checked whether a sweep-then-
// CHoCH on THIS symbol, in THIS session, actually resolves 80% of the time.
//
// So the EA checks. Every prediction is recorded with the price it was made at;
// a fixed number of bars later the outcome is scored - did price go the predicted
// way by a meaningful margin, or not? The tally per pattern then feeds back into
// the confidence.
//
// Two deliberate choices. Evidence is blended in gradually (shrinkage): a pattern
// with three samples should not overwrite a considered prior, while one with fifty
// should. And the tallies decay slowly, so a pattern that worked last year but has
// stopped working is allowed to lose its reputation.
// ============================================================================

// (CHAIN_PAT_* defines moved above their first use - preprocessor defines are not hoisted)

double G_CHAIN_PAT_WINS[CHAIN_PAT_COUNT];
double G_CHAIN_PAT_LOSSES[CHAIN_PAT_COUNT];

// The prediction currently awaiting its verdict.
int      G_CHAIN_PENDING_PAT   = CHAIN_PAT_NONE;
int      G_CHAIN_PENDING_DIR   = 0;
int      G_CHAIN_PENDING_BAR   = -100000;
double   G_CHAIN_PENDING_PRICE = 0.0;

string ChainPatGVKey(const string suffix, const int pat)
{
   return StringFormat("NAVIUS_CHAINPAT_%s_%d_%s_%d", _Symbol, MagicNumber, suffix, pat);
}

void ChainPatternSave()
{
   if(!EnableChainLearning)
      return;
   for(int i = 0; i < CHAIN_PAT_COUNT; i++)
   {
      GlobalVariableSet(ChainPatGVKey("W", i), G_CHAIN_PAT_WINS[i]);
      GlobalVariableSet(ChainPatGVKey("L", i), G_CHAIN_PAT_LOSSES[i]);
   }
}

void ChainPatternRestore()
{
   for(int i = 0; i < CHAIN_PAT_COUNT; i++)
   {
      G_CHAIN_PAT_WINS[i]   = 0.0;
      G_CHAIN_PAT_LOSSES[i] = 0.0;
   }
   if(!EnableChainLearning)
      return;

   int restored = 0;
   for(int i = 0; i < CHAIN_PAT_COUNT; i++)
   {
      string kw = ChainPatGVKey("W", i);
      string kl = ChainPatGVKey("L", i);
      if(GlobalVariableCheck(kw)) { G_CHAIN_PAT_WINS[i]   = GlobalVariableGet(kw); restored++; }
      if(GlobalVariableCheck(kl)) { G_CHAIN_PAT_LOSSES[i] = GlobalVariableGet(kl); }
   }
   if(restored > 0 && (ChainLearningPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v145 CHAIN LEARNING] restored outcome history for %d patterns", restored);
}

// Blend the configured confidence with the measured win rate. Shrinkage keeps a
// thin sample from overwriting the prior.
double ChainPatternAdjustedConfidence(const int pattern, const double base_conf)
{
   if(!EnableChainLearning || pattern <= CHAIN_PAT_NONE || pattern >= CHAIN_PAT_COUNT)
      return base_conf;

   double wins   = G_CHAIN_PAT_WINS[pattern];
   double losses = G_CHAIN_PAT_LOSSES[pattern];
   double total  = wins + losses;
   if(total < 1.0)
      return base_conf;

   double measured = wins / total;
   double k = MathMax(1.0, ChainLearningShrinkage);
   double weight = total / (total + k);          // 0 with no data, ->1 with plenty

   double blended = base_conf * (1.0 - weight) + measured * weight;
   return MathMax(0.05, MathMin(0.98, blended));
}

// Records a prediction so it can be graded later. One at a time - a new prediction
// while one is pending simply replaces it, since the newer chain supersedes it.
void ChainPatternPredict(const int pattern, const int dir, const double price)
{
   if(!EnableChainLearning || pattern <= CHAIN_PAT_NONE || dir == 0 || price <= 0.0)
      return;
   if(G_CHAIN_PENDING_PAT == pattern && G_CHAIN_PENDING_DIR == dir &&
      (G_BARS_SEEN - G_CHAIN_PENDING_BAR) < ChainLearningHorizonBars)
      return;                                    // same call still running

   G_CHAIN_PENDING_PAT   = pattern;
   G_CHAIN_PENDING_DIR   = dir;
   G_CHAIN_PENDING_BAR   = G_BARS_SEEN;
   G_CHAIN_PENDING_PRICE = price;
}

// Grades the pending prediction once its horizon has passed.
void ChainPatternSettle()
{
   if(!EnableChainLearning || G_CHAIN_PENDING_PAT == CHAIN_PAT_NONE || _Point <= 0.0)
      return;
   if((G_BARS_SEEN - G_CHAIN_PENDING_BAR) < MathMax(2, ChainLearningHorizonBars))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double moved_pts = (mid - G_CHAIN_PENDING_PRICE) / _Point * (double)G_CHAIN_PENDING_DIR;
   int pat = G_CHAIN_PENDING_PAT;

   // Only a meaningful move counts either way - noise around the entry price says
   // nothing about whether the pattern worked.
   if(moved_pts >= (double)ChainLearningWinPoints)
   {
      G_CHAIN_PAT_WINS[pat] += 1.0;
      if((ChainLearningPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v145 CHAIN LEARNING] pattern %d CORRECT (%.0f pts) | now %.0f/%.0f",
                     pat, moved_pts, G_CHAIN_PAT_WINS[pat], G_CHAIN_PAT_LOSSES[pat]);
   }
   else if(moved_pts <= -(double)ChainLearningWinPoints)
   {
      G_CHAIN_PAT_LOSSES[pat] += 1.0;
      if((ChainLearningPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v145 CHAIN LEARNING] pattern %d WRONG (%.0f pts) | now %.0f/%.0f",
                     pat, moved_pts, G_CHAIN_PAT_WINS[pat], G_CHAIN_PAT_LOSSES[pat]);
   }
   // Anything in between is discarded - an inconclusive outcome is not evidence.

   // Slow decay so a pattern that has stopped working can lose its reputation.
   double tally = G_CHAIN_PAT_WINS[pat] + G_CHAIN_PAT_LOSSES[pat];
   if(ChainLearningMaxSamples > 0 && tally > (double)ChainLearningMaxSamples)
   {
      double scale = (double)ChainLearningMaxSamples / tally;
      G_CHAIN_PAT_WINS[pat]   *= scale;
      G_CHAIN_PAT_LOSSES[pat] *= scale;
   }

   ChainPatternSave();

   G_CHAIN_PENDING_PAT   = CHAIN_PAT_NONE;
   G_CHAIN_PENDING_DIR   = 0;
   G_CHAIN_PENDING_BAR   = -100000;
   G_CHAIN_PENDING_PRICE = 0.0;
}

// ============================================================================
// V143: CHAIN READING - what the sequence says comes next.
// ----------------------------------------------------------------------------
// The chain records what happened. This reads it.
//
// Certain sequences carry a well-known meaning, and the meaning lives in the ORDER,
// not in any single link:
//
//   sweep -> CHoCH (opposite)   liquidity was taken, then structure broke against
//                               the move that took it. The classic reversal: the run
//                               existed to fill stops, and it is finished.
//   impulse -> CHoCH            the thrust ran out and structure gave way. The move
//                               is over even if price has not turned yet.
//   range-break -> impulse      a range released and got followed through. Expansion
//                               usually continues rather than snapping straight back.
//   zone-break -> BOS           a level gave way and structure confirmed it. Trend
//                               continuation, the cleanest version of it.
//   sweep -> BOS (same way)     liquidity became fuel rather than a turning point -
//                               continuation, NOT reversal. Same sweep, opposite
//                               conclusion, decided purely by what followed.
//
// The output is a direction plus a confidence, so it can inform a decision without
// dictating one. It is deliberately conservative: an unrecognised chain returns
// nothing rather than guessing.
// ============================================================================
int ChainExpectation(double &confidence, string &detail, int &pattern)
{
   confidence = 0.0;
   detail = "";
   pattern = CHAIN_PAT_NONE;

   if(!EnableChainExpectation || G_EVT_COUNT < 2)
      return 0;

   int d0 = 0, b0 = 0; double p0 = 0.0;
   int d1 = 0, b1 = 0; double p1 = 0.0;
   int k0 = EventAt(0, d0, b0, p0);   // newest
   int k1 = EventAt(1, d1, b1, p1);   // the one before it

   if(k0 == EVT_NONE || k1 == EVT_NONE)
      return 0;

   // A chain only speaks while it is fresh - an old sequence describes a market that
   // has since moved on.
   if((G_BARS_SEEN - b0) > MathMax(1, ChainExpectationMaxAgeBars))
   {
      detail = "chain too old to read";
      return 0;
   }

   int    dir = 0;
   double conf = 0.0;
   string label = "";

   // --- reversal: liquidity taken, then structure broke against that run -----------
   if(k1 == EVT_SWEEP && k0 == EVT_CHOCH && d0 == -d1)
   {
      dir = d0;
      conf = ChainConfSweepReversal;
      pattern = CHAIN_PAT_SWEEP_REV;
      label = "sweep then CHoCH against it - the run was for stops and is finished";
   }
   // --- continuation: liquidity became fuel, structure extended the same way -------
   else if(k1 == EVT_SWEEP && k0 == EVT_BOS && d0 == d1)
   {
      dir = d0;
      conf = ChainConfSweepContinuation;
      pattern = CHAIN_PAT_SWEEP_CONT;
      label = "sweep then BOS the same way - liquidity became fuel, not a turn";
   }
   // --- exhaustion: the thrust ran out and structure gave way ---------------------
   else if(k1 == EVT_IMPULSE && k0 == EVT_CHOCH && d0 == -d1)
   {
      dir = d0;
      conf = ChainConfImpulseExhaustion;
      pattern = CHAIN_PAT_IMP_EXH;
      label = "impulse then CHoCH - the thrust is spent";
   }
   // --- expansion: a range released and was followed through ----------------------
   else if(k1 == EVT_RANGE_BREAK && k0 == EVT_IMPULSE && d0 == d1)
   {
      dir = d0;
      conf = ChainConfExpansion;
      pattern = CHAIN_PAT_EXPANSION;
      label = "range break followed by impulse - expansion usually continues";
   }
   // --- trend continuation: a level gave way and structure confirmed it -----------
   else if(k1 == EVT_ZONE_BREAK && k0 == EVT_BOS && d0 == d1)
   {
      dir = d0;
      conf = ChainConfBreakConfirmed;
      pattern = CHAIN_PAT_BREAK_CONF;
      label = "zone break confirmed by BOS - continuation";
   }
   // --- new trend: structure broke, then extended the NEW way ---------------------
   else if(k1 == EVT_CHOCH && k0 == EVT_BOS && d0 == d1)
   {
      dir = d0;
      conf = ChainConfNewTrend;
      pattern = CHAIN_PAT_NEW_TREND;
      label = "CHoCH then BOS the same way - a new direction has confirmed itself";
   }

   if(dir == 0)
   {
      detail = "chain not a recognised sequence";
      return 0;
   }

   // A sequence that took a long time to form says less than a tight one - the links
   // are then only loosely related.
   int span = MathAbs(b0 - b1);
   if(span > MathMax(1, ChainExpectationTightBars))
   {
      double fade = (double)(span - ChainExpectationTightBars) / (double)MathMax(1, ChainExpectationTightBars);
      conf *= MathMax(0.3, 1.0 - MathMin(0.7, fade));
   }

   // V145: blend the configured confidence with what this pattern has ACTUALLY done. Until the
   // pattern has enough recorded outcomes the configured value dominates; as evidence accumulates
   // the measured win rate takes over. This is what turns the hand-set numbers above into
   // something earned rather than assumed.
   conf = ChainPatternAdjustedConfidence(pattern, conf);

   confidence = MathMax(0.0, MathMin(1.0, conf));
   detail = StringFormat("expects %s (%.0f%%): %s",
                         (dir > 0 ? "UP" : "DOWN"), confidence * 100.0, label);
   return dir;
}

// ============================================================================
// V144: SCENARIOS - how much do the independent readings actually agree?
// ----------------------------------------------------------------------------
// Every module ends up producing a direction, and the EA reduces them to one answer.
// But "45/30/25" and "80/10/10" are completely different situations even though the
// same side wins both: the first is a market with no owner, the second is a market
// with a clear one. Collapsing them into the same verdict throws away the single
// most useful thing about the reading - how much of it is agreement and how much is
// coincidence.
//
// This weighs each source's opinion into three buckets (up / down / neither), then
// reports the leader AND the margin over the runner-up. A narrow margin is not a
// weak signal to be traded smaller - it is a market that has not decided, and the
// honest response is to stand aside.
//
// Sources are weighted by how independent they are: the event chain reads sequence,
// structure reads swings, liquidity reads stop placement, trend reads indicators.
// Four different ways of looking, so agreement between them means something.
// ============================================================================
void ScenarioProbabilities(double &p_up, double &p_down, double &p_none, string &detail)
{
   p_up = 0.0; p_down = 0.0; p_none = 0.0;
   detail = "";

   if(!EnableScenarios)
      return;

   double w_up = 0.0, w_down = 0.0, w_none = 0.0;
   string parts = "";

   // 1. The event chain - the only source that reads SEQUENCE rather than state.
   if(EnableChainExpectation)
   {
      double ce_conf = 0.0;
      string ce_detail = "";
      int ce_pat = CHAIN_PAT_NONE;
      int ce_dir = ChainExpectation(ce_conf, ce_detail, ce_pat);
      double w = ScenarioWeightChain * ce_conf;
      if(ce_dir > 0)      { w_up += w;   parts += "chain^ "; }
      else if(ce_dir < 0) { w_down += w; parts += "chainv "; }
      else                { w_none += ScenarioWeightChain * 0.5; }
   }

   // 2. Swing structure, both frames.
   if(EnableMarketStructure)
   {
      MarketStructureRead();
      if(G_STRUCTURE_DIR > 0)      w_up   += ScenarioWeightStructure;
      else if(G_STRUCTURE_DIR < 0) w_down += ScenarioWeightStructure;
      else                         w_none += ScenarioWeightStructure * 0.5;

      if(EnableStructureHTF)
      {
         if(G_STRUCTURE_HTF_DIR > 0)      w_up   += ScenarioWeightStructure;
         else if(G_STRUCTURE_HTF_DIR < 0) w_down += ScenarioWeightStructure;
      }
   }

   // 3. Zone behaviour - the staircase of broken levels.
   if(EnableBreakSequence)
   {
      BreakSequenceRead();
      if(G_BREAK_SEQ_DIR > 0)      w_up   += ScenarioWeightStaircase;
      else if(G_BREAK_SEQ_DIR < 0) w_down += ScenarioWeightStaircase;
   }

   // 4. Indicator trend, both scales.
   string sg_detail = "", sl_detail = "";
   double gconf = GlobalTrendConfidence(1, sg_detail);
   double lconf = LocalTrendConfidence(1, sl_detail);
   if(gconf >= VerdictTrendMinConfidence)       w_up   += ScenarioWeightTrend;
   else if(gconf <= -VerdictTrendMinConfidence) w_down += ScenarioWeightTrend;
   if(lconf >= VerdictTrendMinConfidence)       w_up   += ScenarioWeightTrend;
   else if(lconf <= -VerdictTrendMinConfidence) w_down += ScenarioWeightTrend;

   // 5. Liquidity - a pool ahead argues price goes THERE first, whatever the trend says.
   if(EnableLiquidityMap)
   {
      int    lq_dir_up = 0, lq_dir_dn = 0;
      double lq_price = 0.0, lq_dist = 0.0;
      string lq_detail = "";
      double w_pool_up = LiquidityPoolAhead(1, lq_dir_up, lq_price, lq_dist, lq_detail);
      if(w_pool_up >= LiquidityMinWeight && lq_dist <= (double)LiquidityNearPoints)
      {
         w_up += ScenarioWeightLiquidity;   // stops above pull price up first
         parts += "pool^ ";
      }
      double w_pool_dn = LiquidityPoolAhead(-1, lq_dir_dn, lq_price, lq_dist, lq_detail);
      if(w_pool_dn >= LiquidityMinWeight && lq_dist <= (double)LiquidityNearPoints)
      {
         w_down += ScenarioWeightLiquidity;
         parts += "poolv ";
      }
   }

   double total = w_up + w_down + w_none;
   if(total <= 0.0001)
   {
      detail = "scenarios: no readable input";
      return;
   }

   p_up   = w_up   / total;
   p_down = w_down / total;
   p_none = w_none / total;

   double lead = MathMax(p_up, MathMax(p_down, p_none));
   double second = 0.0;
   if(lead == p_up)        second = MathMax(p_down, p_none);
   else if(lead == p_down) second = MathMax(p_up, p_none);
   else                    second = MathMax(p_up, p_down);

   string lead_name = (lead == p_up ? "UP" : (lead == p_down ? "DOWN" : "NEITHER"));
   detail = StringFormat("scenarios: UP %.0f%% / DOWN %.0f%% / neither %.0f%% -> %s by %.0f pts %s",
                         p_up * 100.0, p_down * 100.0, p_none * 100.0,
                         lead_name, (lead - second) * 100.0, parts);
}

// Human-readable chain for the dashboard: newest first.
string EventChainText(const int max_links)
{
   if(!EnableEventChain || G_EVT_COUNT <= 0)
      return "chain: (empty)";

   string out = "chain:";
   int shown = MathMin(MathMin(max_links, SIRUS_EVENT_MAX), G_EVT_COUNT);
   for(int b = shown - 1; b >= 0; b--)
   {
      int d = 0, bar = 0; double pr = 0.0;
      int k = EventAt(b, d, bar, pr);
      if(k == EVT_NONE)
         continue;
      out += StringFormat(" %s%s", EventKindName(k), (d > 0 ? "^" : (d < 0 ? "v" : "")));
      if(b > 0)
         out += " ->";
   }
   return out;
}

// ============================================================================
double LiquidityPoolAhead(const int entry_dir, int &pool_dir, double &pool_price,
                          double &pool_distance_pts, string &detail)
{
   pool_dir = 0; pool_price = 0.0; pool_distance_pts = 0.0; detail = "";

   if(!EnableLiquidityMap || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   // V170b: per-bar cache by direction - this scans the swing cache and sorts, and is called from
   // the score engine and the scenario weighting on the same tick.
   static int    lq_bar[3];
   static double lq_w[3], lq_price[3], lq_dist[3];
   static int    lq_dir_c[3];
   static string lq_det[3];
   static bool   lq_init = false;
   if(!lq_init) { for(int z = 0; z < 3; z++) lq_bar[z] = -100000; lq_init = true; }
   int lq_slot = (entry_dir > 0) ? 1 : 2;
   if(lq_bar[lq_slot] == G_BARS_SEEN)
   {
      pool_dir = lq_dir_c[lq_slot];
      pool_price = lq_price[lq_slot];
      pool_distance_pts = lq_dist[lq_slot];
      detail = lq_det[lq_slot];
      return lq_w[lq_slot];
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   ZoneMapRefreshSwingCache();

   int t = ZMTFIndex(LiquidityMapTF);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT)
      return 0.0;

   // V170f: what counts as "the same shelf" and how far ahead to look are both structural
   // distances - in a market swinging twice as wide, so are the pools.
   double tol   = ScaleAdjustedPoints(MathMax(1, LiquidityClusterPoints)) * _Point;
   double reach = ScaleAdjustedPoints(MathMax(1, LiquidityMapSearchPoints)) * _Point;

   // A pool that hurts a BUY sits ABOVE (buy-stops above equal highs, price runs up
   // to take them before turning); for a SELL it sits BELOW.
   bool look_up = (entry_dir > 0);

   // Dynamic so it can be trimmed to the collected count before sorting - MQL5's ArraySort
   // sorts the WHOLE array, and unused zero entries would sort to the front.
   double levels[];
   ArrayResize(levels, 80);
   int n = 0;

   if(look_up)
   {
      for(int k = 0; k < G_ZMC_HIGH_COUNT[t] && n < 80; k++)
      {
         double v = G_ZMC_HIGH_PRICE[t][k];
         if(v > mid && (v - mid) <= reach)
            levels[n++] = v;
      }
   }
   else
   {
      for(int k = 0; k < G_ZMC_LOW_COUNT[t] && n < 80; k++)
      {
         double v = G_ZMC_LOW_PRICE[t][k];
         if(v > 0.0 && v < mid && (mid - v) <= reach)
            levels[n++] = v;
      }
   }

   if(n < MathMax(2, LiquidityMinSwings))
   {
      lq_bar[lq_slot] = G_BARS_SEEN; lq_w[lq_slot] = 0.0; lq_dir_c[lq_slot] = 0;
      lq_price[lq_slot] = 0.0; lq_dist[lq_slot] = 0.0; lq_det[lq_slot] = "";
      return 0.0;
   }

   ArrayResize(levels, n);
   ArraySort(levels);

   // Find the tightest cluster of aligned extremes - that is the heaviest shelf.
   int    best_count = 0;
   double best_lo = 0.0, best_hi = 0.0;

   int    run_count = 1;
   double run_lo = levels[0], run_hi = levels[0];

   for(int i = 1; i <= n; i++)
   {
      bool extend = (i < n) && ((levels[i] - levels[i - 1]) <= tol);

      if(extend)
      {
         run_count++;
         run_hi = levels[i];
      }
      else
      {
         if(run_count >= MathMax(2, LiquidityMinSwings) && run_count > best_count)
         {
            best_count = run_count;
            best_lo = run_lo;
            best_hi = run_hi;
         }
         if(i < n)
         {
            run_count = 1;
            run_lo = levels[i];
            run_hi = levels[i];
         }
      }
   }

   if(best_count <= 0)
   {
      lq_bar[lq_slot] = G_BARS_SEEN; lq_w[lq_slot] = 0.0; lq_dir_c[lq_slot] = 0;
      lq_price[lq_slot] = 0.0; lq_dist[lq_slot] = 0.0; lq_det[lq_slot] = "";
      return 0.0;
   }

   // The stops sit just beyond the shelf, so the pull is toward its far edge.
   pool_price = look_up ? best_hi : best_lo;
   pool_dir   = look_up ? 1 : -1;
   pool_distance_pts = MathAbs(pool_price - mid) / _Point;

   // Weight: more aligned swings = heavier shelf; a tighter alignment is heavier
   // still, because a clean equal-high is far more obvious to the market than a
   // ragged one.
   double spread_pts = MathMax(1.0, (best_hi - best_lo) / _Point);
   double tightness  = MathMax(0.0, MathMin(1.0, 1.0 - (spread_pts / MathMax(1.0, (double)LiquidityClusterPoints))));
   double weight     = (double)best_count + tightness;

   detail = StringFormat("liquidity pool %s at %.2f (%d aligned swings, %.0f pts away, weight %.1f)",
                         (look_up ? "above" : "below"), pool_price, best_count, pool_distance_pts, weight);

   lq_bar[lq_slot] = G_BARS_SEEN; lq_w[lq_slot] = weight; lq_dir_c[lq_slot] = pool_dir;
   lq_price[lq_slot] = pool_price; lq_dist[lq_slot] = pool_distance_pts; lq_det[lq_slot] = detail;
   return weight;
}

bool ZoneBandOnTF(const ENUM_TIMEFRAMES tf, const double mid,
                  double &band_lo, double &band_hi, int &band_count)
{
   band_lo = 0.0; band_hi = 0.0; band_count = 0;

   int t = ZMTFIndex(tf);
   if(t < 0 || t >= SIRUS_ZM_CACHE_TF_COUNT || _Point <= 0.0)
      return false;

   // Tolerance from this timeframe's own volatility, clamped so a dead or wild
   // session can't produce a nonsense band.
   double atr_pts = ATRPointsManual(tf, ATRPeriod, 1);
   double tol_pts = atr_pts * MathMax(0.05, ZoneBandATRMult);
   tol_pts = MathMax((double)ZoneBandMinTolerancePoints,
                     MathMin((double)ZoneBandMaxTolerancePoints, tol_pts));

   // V150: the ATR-derived tolerance is adjusted by the market's own structural scale - ATR sizes
   // bars, this sizes the swings the bands are actually made of.
   double cluster_tol = ScaleAdjustedPoints(tol_pts) * _Point;
   double reach       = MathMax(1, ZoneBandSearchPoints) * _Point;

   // A band is made of highs AND lows together - that is exactly what makes its
   // role ambiguous once price is inside it.
   double levels[];
   ArrayResize(levels, 160);
   int n = 0;
   for(int k = 0; k < G_ZMC_HIGH_COUNT[t] && n < 160; k++)
   {
      double v = G_ZMC_HIGH_PRICE[t][k];
      if(v > 0.0 && MathAbs(v - mid) <= reach)
         levels[n++] = v;
   }
   for(int k = 0; k < G_ZMC_LOW_COUNT[t] && n < 160; k++)
   {
      double v = G_ZMC_LOW_PRICE[t][k];
      if(v > 0.0 && MathAbs(v - mid) <= reach)
         levels[n++] = v;
   }
   if(n < MathMax(2, ZoneBandMinTouches))
      return false;

   // MQL5's ArraySort takes only the array and sorts it ascending in full, so the buffer is
   // trimmed to the number of levels actually collected - otherwise the unused zero entries
   // would sort to the front and corrupt the clustering below.
   ArrayResize(levels, n);
   ArraySort(levels);

   // Grow a cluster while consecutive levels stay within tolerance. The band's final
   // width is whatever the swings produce - small clusters give small zones, dense
   // ones give large zones.
   int    best_count = 0;
   double best_lo = 0.0, best_hi = 0.0;

   int    run_count = 1;
   double run_lo = levels[0], run_hi = levels[0];

   for(int i = 1; i <= n; i++)
   {
      bool extend = (i < n) && ((levels[i] - levels[i - 1]) <= cluster_tol);

      if(extend)
      {
         run_count++;
         run_hi = levels[i];
      }
      else
      {
         if(run_count >= MathMax(2, ZoneBandMinTouches) &&
            mid >= run_lo && mid <= run_hi &&
            run_count > best_count)
         {
            best_count = run_count;
            best_lo = run_lo;
            best_hi = run_hi;
         }
         if(i < n)
         {
            run_count = 1;
            run_lo = levels[i];
            run_hi = levels[i];
         }
      }
   }

   if(best_count <= 0)
      return false;

   band_lo = best_lo;
   band_hi = best_hi;
   band_count = best_count;
   return true;
}

// Checks every enabled timeframe. Price inside a band on ANY of them means the
// support/resistance role is undefined there. Reports the widest one found.
bool ZonePriceInsideBand(double &band_lo, double &band_hi, string &detail)
{
   band_lo = 0.0; band_hi = 0.0; detail = "";
   if(!EnableZoneRoleCheck || _Point <= 0.0)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return false;

   ZoneMapRefreshSwingCache();

   ENUM_TIMEFRAMES tfs[3];
   bool enabled[3];
   tfs[0] = PERIOD_M5;  enabled[0] = ZoneBandUseM5;
   tfs[1] = PERIOD_M15; enabled[1] = ZoneBandUseM15;
   tfs[2] = PERIOD_H1;  enabled[2] = ZoneBandUseH1;

   double widest = 0.0;
   int    widest_count = 0;
   string widest_tf = "";

   for(int i = 0; i < 3; i++)
   {
      if(!enabled[i])
         continue;

      double lo = 0.0, hi = 0.0; int cnt = 0;
      if(!ZoneBandOnTF(tfs[i], mid, lo, hi, cnt))
         continue;

      double width = hi - lo;
      if(width > widest)
      {
         widest = width;
         widest_count = cnt;
         widest_tf = TFToString(tfs[i]);
         band_lo = lo;
         band_hi = hi;
      }
   }

   if(band_lo <= 0.0 || band_hi <= 0.0)
      return false;                  // not inside any band - role is well defined

   detail = StringFormat("price %.2f is INSIDE a %s band %.2f-%.2f (%.0f pts wide, %d swings) - role undefined",
                         mid, widest_tf, band_lo, band_hi, widest / _Point, widest_count);
   return true;
}

// ============================================================================
// V238: TRADING INTO A BAND, AND THE SWEEP THAT ALREADY HAPPENED
// ----------------------------------------------------------------------------
// Two live losses, and the same blind spot behind both.
//
// A BUY AT 4435 - into a band that had capped price on the 11th, 12th, 13th and 18th.
// Four rejections at the same shelf across a week, and the EA bought inside it. The
// counter-zone check measures distance to the NEAREST level, and once price is inside
// a band the nearest edge is a dollar away, so the check reads plenty of room while
// price sits in the middle of the thing that has been stopping it all week.
//
// A SELL AT 4345 - after 4325 was swept, price recovered, made a higher high at 4358,
// and never returned to the low. Liquidity taken, structure turned, the level held
// three times. Every one of those is a reason to buy, and the EA sold.
//
// The band case is a measurement error: distance to an edge is the wrong question
// when price is between the edges. The sweep case is a missing reading entirely -
// the EA has sweep DETECTORS, but nothing that notices a sweep completed, failed to
// continue, and left the structure pointing the other way.
// V239: did the candle actually get through the one before it?
//
// From the losing buy at 4435, annotated on M5 as "the candle did not break the previous body". That
// is the plainest possible statement of a push failing, and the EA had no way to express it. It
// measures body size, wick share, sequence direction and range expansion - none of which asks the
// simplest question: did this candle close beyond where the last one closed?
//
// A bullish candle that cannot close above the previous bullish candle's high is buyers arriving and
// not getting anywhere. The bar looks fine in isolation - decent body, right direction - and the
// sequence reader sees two candles pointing the same way. What it misses is that the second one
// achieved nothing, which is the whole signal.
//
// Returns 0..1 - how badly the candle failed to progress. Zero when it progressed normally.
double CandleFailedProgress(const int dir, string &detail)
{
   detail = "";
   if(!EnableCandleProgress || dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = CandleSequenceTF;
   double o1 = CandleOpen(tf, 1), c1 = CandleClose(tf, 1);
   double h1 = CandleHigh(tf, 1), l1 = CandleLow(tf, 1);
   double o2 = CandleOpen(tf, 2), c2 = CandleClose(tf, 2);
   double h2 = CandleHigh(tf, 2), l2 = CandleLow(tf, 2);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return 0.0;

   double r1 = h1 - l1;
   if(r1 <= 0.0)
      return 0.0;

   int d1 = (c1 > o1) ? 1 : ((c1 < o1) ? -1 : 0);
   int d2 = (c2 > o2) ? 1 : ((c2 < o2) ? -1 : 0);

   // Only meaningful when both candles point the way the trade wants to go. Two bars in the
   // entry's direction that made no progress is the failure worth naming; a single bar against
   // is already covered elsewhere.
   if(d1 != dir || d2 != dir)
      return 0.0;

   // The body it had to clear.
   double prev_body_end = (dir > 0) ? MathMax(o2, c2) : MathMin(o2, c2);
   double prev_extreme  = (dir > 0) ? h2 : l2;

   // Did it close beyond the previous body?
   bool cleared_body = (dir > 0) ? (c1 > prev_body_end) : (c1 < prev_body_end);
   bool cleared_high = (dir > 0) ? (c1 > prev_extreme)  : (c1 < prev_extreme);

   if(cleared_high)
      return 0.0;                    // full progress - nothing to report

   double severity = 0.0;

   if(!cleared_body)
   {
      // Did not even clear the previous body. Two candles in the same direction and the second
      // finished inside the first - that is effort meeting something.
      severity = 1.0;
      detail = StringFormat("second %s candle closed inside the previous body",
                            (dir > 0 ? "bullish" : "bearish"));
   }
   else
   {
      // Cleared the body but not the extreme. Partial - how far short it fell says how much.
      double gap = MathAbs(prev_extreme - c1);
      double reach = MathAbs(prev_extreme - prev_body_end);
      if(reach <= 0.0)
         return 0.0;
      severity = MathMin(1.0, gap / reach) * CandleProgressPartialWeight;
      detail = StringFormat("%s candle stalled below the previous high",
                            (dir > 0 ? "bullish" : "bearish"));
   }

   // A candle with a small body was never going to progress far - the failure means less when
   // there was little attempt behind it.
   double body_share = MathAbs(c1 - o1) / r1;
   severity *= (0.4 + 0.6 * body_share);

   return MathMax(0.0, MathMin(1.0, severity));
}

// ============================================================================
// V240: THE ASSUMPTION UNDER THE WHOLE LADDER
// ----------------------------------------------------------------------------
// Every grid rests on one premise: price comes back. Everything else - the 1.30
// multiplier, the spacing, the recovery arithmetic - only works if that holds.
//
// It holds in a range. It does not hold in a trend, and in a trend the ladder does
// the worst possible thing: it adds size in the direction price is leaving, at
// increasing volume, until the account decides the matter.
//
// The EA already classifies the market - MARKET_TREND_UP, MARKET_TREND_DOWN,
// MARKET_RANGE - and the grid has never read it. GridCanOpen checks one state,
// MARKET_IMPULSE, and nothing else. So the ladder builds identically whether price
// is oscillating around a mean or walking away from one, and the two live stop-outs
// were both the second case.
//
// This does not disable the grid in a trend. A ladder WITH the trend is fine - it is
// buying dips in an uptrend, which is what the arithmetic is for. What it stops is
// the ladder against a trend, where each addition is a larger bet on a premise the
// market is currently refusing.
// ============================================================================

// How badly does the current regime contradict this basket? 0..1
// ============================================================================
// V275: THE PRICE THE EA HAPPENS TO BE LOOKING AT
// ----------------------------------------------------------------------------
// Everything built today answers WHERE NOT to trade. What decides WHEN is still one
// question: has the score cleared its threshold. The moment it does, the order goes in
// at whatever price is on the screen.
//
// That price is arbitrary. A setup confirming at the top of an M5 bar and the same
// setup confirming at its low are the same trade taken a dollar apart, and the target
// is two-fifty. Nearly half the trade is decided by which tick the score happened to
// cross on.
//
// EntryBarPlacement measures this and charges for it, which is the wrong response to a
// timing problem. A bad fill is not a reason to refuse a good setup; it is a reason to
// wait a few minutes for a better one. The setup does not expire in three bars - the
// zone is still there, the structure has not changed - and the arming engine already
// knows how to hold a setup and re-check it.
//
// So this adds a fifth reason to wait: not the setup being unproven, but the price
// being poor. It holds for a few bars and takes the entry anyway when the window ends,
// because a good setup at a mediocre price still beats no trade at all.
// ============================================================================

// How poor is the current fill within the forming bar? Returns 0..1.
double FillQualityPenalty(const int dir, double &better_price, string &detail)
{
   better_price = 0.0;
   detail = "";

   if(!EnableFillTiming || dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = FillTimingTF;
   if(tf != PERIOD_M1 && tf != PERIOD_M5)
      return 0.0;

   double o = CandleOpen(tf, 0);
   double h = CandleHigh(tf, 0);
   double l = CandleLow(tf, 0);
   if(o <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0.0;

   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   // The bar has to be large enough for position within it to matter. In a bar worth
   // twenty points, waiting for a better fill gains twenty points at most.
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;
   double range_atr = (range / _Point) / atr;
   if(range_atr < FillTimingMinRangeATR)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px = (dir > 0) ? ask : bid;
   if(px <= 0.0)
      return 0.0;

   // Where in the bar would this fill land? A buy at the high of the bar is paying for
   // everything the bar has produced; at the low it is paying for none of it.
   double pos = (dir > 0) ? (px - l) / range : (h - px) / range;

   if(pos < FillTimingBadFrom)
      return 0.0;

   // What a better fill would be worth. Not the extreme - price rarely returns to it -
   // but the middle of the bar, which it often does.
   double mid_price = (h + l) / 2.0;
   better_price = mid_price;

   double gain_pts = MathAbs(px - mid_price) / _Point;
   double tp = BaseBasketTPPoints();

   // Only worth waiting when the improvement is material against the target. Ten points
   // on a two-hundred-and-fifty point target is not worth a delay.
   if(tp > 0.0 && (gain_pts / tp) < FillTimingMinGainShare)
      return 0.0;

   double severity = (pos - FillTimingBadFrom) / MathMax(0.01, 1.0 - FillTimingBadFrom);

   detail = StringFormat("fill sits %.0f%% up the bar - %.0f pts worse than its middle",
                         pos * 100.0, gain_pts);
   return MathMax(0.0, MathMin(1.0, severity));
}


// ============================================================================
// V291: DECIDING BEFORE PRICE ARRIVES
// ----------------------------------------------------------------------------
// Every reading in this EA starts when price is already somewhere. A level is reached,
// and only then does the work begin - structure, trend, session, candles, thirty
// modules - and by the time they agree, the reaction that made the level worth trading
// is several bars old.
//
// But the level was there the whole time. Price did not arrive unannounced; it walked
// toward a shelf that has been sitting on the chart for days, and everything the EA
// needs to know about whether that shelf is worth trading is knowable BEFORE price gets
// there. The monthly trend does not change in the seconds it takes price to cover the
// last dollar. Neither does the session, the thinness of the day, or the structure two
// timeframes up.
//
// So this does the slow half early. Each bar it looks ahead at the strongest levels
// within reach and asks what a trade there would score on everything that does not
// depend on price being there yet. Levels that clear are marked ready. When price
// arrives, the remaining work is the fast half - the candle at the level, the reaction
// - and the entry happens on the bar it should rather than three bars later.
//
// It is the opposite of the arming engine, which holds a setup that already exists.
// This prepares one that does not exist yet.
// ============================================================================

#define PREPARED_LEVEL_MAX 6

double   G_PREP_PRICE[PREPARED_LEVEL_MAX];
int      G_PREP_DIR[PREPARED_LEVEL_MAX];
double   G_PREP_SCORE[PREPARED_LEVEL_MAX];
string   G_PREP_NOTE[PREPARED_LEVEL_MAX];
int      G_PREP_COUNT = 0;
int      G_PREP_BAR   = -100000;

// The context part of a score: everything that is true about trading a level in a
// direction, before price is anywhere near it. Returns a rough point value.
double PreparedContextScore(const int dir, const double level, string &note)
{
   note = "";
   if(dir == 0 || level <= 0.0)
      return 0.0;

   double pts = 0.0;
   string parts = "";

   // The monthly trend. This is the slowest reading in the EA and the one least likely
   // to change while price covers the last dollar.
   if(EnableGlobalTrend)
   {
      double gs = 0.0;
      string gd = "";
      int gdir = GlobalTrendDirection(gs, gd);
      if(gdir == dir && gs >= GlobalTrendMinStrength)
      {
         pts += PrepTrendWeight * gs;
         parts += "trend; ";
      }
      else if(gdir == -dir && gs >= GlobalTrendMinStrength)
      {
         pts -= PrepTrendWeight * gs;
         parts += "trend against; ";
      }
   }

   // The larger scales. Same argument - an H4 structure does not turn over in a minute.
   if(EnableScaleHierarchy)
   {
      string hd = "";
      double conflict = HigherScaleConflict(dir, hd);
      if(conflict >= HierarchyMinConflict)
      {
         pts -= PrepHierarchyWeight * conflict;
         parts += "scales against; ";
      }
   }

   // The level itself. Its strength is a property of history, not of where price is.
   double strength = ZoneMapStrengthByTouches(level);
   if(strength >= PrepMinLevelStrength)
   {
      pts += PrepLevelWeight * MathMin(1.0, strength / MathMax(0.1, PrepFullLevelStrength));
      parts += StringFormat("level %.1f; ", strength);
   }
   else
      return 0.0;                 // not worth preparing for

   // Where the level sits in the range. Buying a level in discount and buying the same
   // level in premium are different trades, and the range does not move while price
   // travels within it.
   if(EnableEQZone)
   {
      double rp = 50.0;
      int eqd = EQZoneBias(rp);
      if(eqd == dir)      { pts += PrepRangeWeight; parts += "range; "; }
      else if(eqd == -dir){ pts -= PrepRangeWeight; parts += "range against; "; }
   }

   // Conditions that make any trade worse today, whatever the level.
   if(EnableCalendarThinness)
   {
      string ctd = "";
      double thin = CalendarThinness(ctd);
      if(thin >= ThinMinSeverity)
      {
         pts -= PrepThinWeight * thin;
         parts += "thin day; ";
      }
   }

   note = parts;
   return pts;
}

// Look ahead and mark the levels worth trading when price gets there.
void PreparedLevelsRefresh()
{
   if(!EnablePreparedLevels || _Point <= 0.0)
      return;

   if(G_PREP_BAR > -100000 && (G_BARS_SEEN - G_PREP_BAR) < MathMax(1, PrepRefreshBars))
      return;
   G_PREP_BAR = G_BARS_SEEN;
   G_PREP_COUNT = 0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double reach = ScaleAdjustedPoints(MathMax(1, PrepLookAheadPoints));

   // Candidates: the nearest support below and resistance above, plus whatever the
   // protected list holds within reach. A level being far away is exactly why there is
   // time to think about it.
   double cands[6];
   int    dirs[6];
   int n = 0;

   double sup = ZoneMapNearestSupport(mid);
   if(sup > 0.0 && (mid - sup) / _Point <= reach) { cands[n] = sup; dirs[n] = 1; n++; }

   double res = ZoneMapNearestResistance(mid);
   if(res > 0.0 && (res - mid) / _Point <= reach) { cands[n] = res; dirs[n] = -1; n++; }

   if(EnableProtectedZones)
   {
      double ps = 0.0; string pd = "";
      double pdn = ProtectedZoneNear(mid, -1, ps, pd);
      if(pdn > 0.0 && (mid - pdn) / _Point <= reach && n < 6) { cands[n] = pdn; dirs[n] = 1; n++; }

      double pup = ProtectedZoneNear(mid, 1, ps, pd);
      if(pup > 0.0 && (pup - mid) / _Point <= reach && n < 6) { cands[n] = pup; dirs[n] = -1; n++; }
   }

   for(int i = 0; i < n && G_PREP_COUNT < PREPARED_LEVEL_MAX; i++)
   {
      string note = "";
      double sc = PreparedContextScore(dirs[i], cands[i], note);

      if(sc < PrepMinScore)
         continue;

      // Skip duplicates - the protected list and the swing scan often name the same price.
      bool dup = false;
      for(int d = 0; d < G_PREP_COUNT && !dup; d++)
         if(MathAbs(G_PREP_PRICE[d] - cands[i]) / _Point < PrepMergePoints)
            dup = true;
      if(dup)
         continue;

      G_PREP_PRICE[G_PREP_COUNT] = cands[i];
      G_PREP_DIR[G_PREP_COUNT]   = dirs[i];
      G_PREP_SCORE[G_PREP_COUNT] = sc;
      G_PREP_NOTE[G_PREP_COUNT]  = note;
      G_PREP_COUNT++;

      if((PreparedLevelsPrintOnUse && G_VERBOSE))
         PrintFormat("[SIRUS v291 PREP] %.2f ready for %s (%.1f) - %s",
                     cands[i], (dirs[i] > 0 ? "BUY" : "SELL"), sc, note);
   }
}

// Is price now at a level that was prepared for this direction? Returns the context
// score that was computed while there was time to compute it.
double PreparedLevelHit(const int dir, string &detail)
{
   detail = "";
   if(!EnablePreparedLevels || dir == 0 || _Point <= 0.0 || G_PREP_COUNT <= 0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   double tol = ScaleAdjustedPoints(MathMax(1, PrepHitTolerance));

   for(int i = 0; i < G_PREP_COUNT; i++)
   {
      if(G_PREP_DIR[i] != dir)
         continue;
      if(MathAbs(mid - G_PREP_PRICE[i]) / _Point > tol)
         continue;

      detail = StringFormat("prepared at %.2f - %s", G_PREP_PRICE[i], G_PREP_NOTE[i]);
      return G_PREP_SCORE[i];
   }

   return 0.0;
}


// ============================================================================
// V288: WHERE IN THE MOVE, NOT HOW MANY POINTS OFF
// ----------------------------------------------------------------------------
// A live SELL was taken at 4307.98, at the low of a four-dollar decline, and price
// turned within two bars. Four separate modules had objected - the move was extended,
// the structure mature, the bodies shrinking, the range position in discount - and each
// of them answered by subtracting points.
//
// Subtracting points is the wrong answer to that problem. Nothing was wrong with the
// setup: the direction was right, the structure was right, the EA was correct that the
// market was falling. What was wrong was WHEN. Selling the bottom of a decline and
// selling a pullback within that decline are the same trade at different prices, and
// only one of them works.
//
// A penalty treats a timing problem as a quality problem, and the two need opposite
// responses. A poor setup should be refused. A good setup at a poor moment should be
// HELD - which is what the arming engine already does for zones and pullbacks, and was
// never asked to do for this.
//
// So: when the entry sits at the extreme of the move it wants to join, arm it and wait
// for the retrace. The setup survives, the entry improves, and no points change hands.
// ============================================================================

// How far through its own move is this entry? 0 = at the start, 1 = at the far end.
//   travelled_pts - how far the move has run
double EntryPositionInMove(const int entry_dir, double &travelled_pts, string &detail)
{
   travelled_pts = 0.0;
   detail = "";

   if(!EnableLateEntryHold || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = LateEntryTF;
   if(tf != PERIOD_M1 && tf != PERIOD_M5 && tf != PERIOD_M15)
      return 0.0;

   int look = MathMax(10, LateEntryLookback);

   // The swing this entry would be joining: the extreme in its own direction, and the
   // opposite extreme the move started from.
   double best_with = 0.0, best_against = 0.0;
   for(int k = 1; k <= look; k++)
   {
      double h = CandleHigh(tf, k), l = CandleLow(tf, k);
      if(h <= 0.0 || l <= 0.0) continue;

      if(entry_dir > 0)
      {
         if(best_with <= 0.0 || h > best_with) best_with = h;      // a BUY runs up
         if(best_against <= 0.0 || l < best_against) best_against = l;
      }
      else
      {
         if(best_with <= 0.0 || l < best_with) best_with = l;      // a SELL runs down
         if(best_against <= 0.0 || h > best_against) best_against = h;
      }
   }

   if(best_with <= 0.0 || best_against <= 0.0)
      return 0.0;

   double span = MathAbs(best_against - best_with);
   if(span <= 0.0)
      return 0.0;

   travelled_pts = span / _Point;

   // The move has to be worth calling one. Position within a twenty-point wiggle says
   // nothing about timing.
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0 || (travelled_pts / atr) < LateEntryMinSpanATR)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (entry_dir > 0) ? ask : bid;
   if(px <= 0.0)
      return 0.0;

   // Where the entry sits between the two ends. Near 1 means entering at the far end -
   // the price the move has already reached, with the whole of it behind.
   double pos = MathAbs(px - best_against) / span;
   pos = MathMax(0.0, MathMin(1.0, pos));

   detail = StringFormat("%.0f%% through a %.1f ATR move", pos * 100.0, travelled_pts / atr);
   return pos;
}

// The price a retrace would have to reach for this entry to be worth taking.
double LateEntryBetterPrice(const int entry_dir)
{
   double travelled = 0.0;
   string d = "";
   double pos = EntryPositionInMove(entry_dir, travelled, d);
   if(pos <= 0.0 || travelled <= 0.0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (entry_dir > 0) ? ask : bid;
   if(px <= 0.0)
      return 0.0;

   // A retrace of part of the move, against the entry direction. Not the whole way back
   // - that would be waiting for the move to fail - just enough that the entry is no
   // longer paying for what has already happened.
   double back = travelled * LateEntryRetraceShare * _Point;
   return (entry_dir > 0) ? (px - back) : (px + back);
}


// ============================================================================
// V273: THE TREND ABOVE EVERYTHING, AND WHAT A DISTANT LEVEL IS FOR
// ----------------------------------------------------------------------------
// HigherScaleConflict reads H4, H1 and M30 over eighty bars. On H4 that is thirteen
// days, and thirteen days is not a trend - it is a swing inside one. The EA has no
// reading of where the market has been going for months, which is the thing that
// decides whether a level will hold or be run straight through.
//
// This matters most at exactly the levels V272 just extended the EA's memory to reach.
// A daily level from four months ago is the strongest thing on the chart, and price
// arriving at it in a strong downtrend is not the same event as price arriving at it in
// a rising market. In the first case the level is something the trend has to get past
// and usually does; in the second it is where the trend stops. Trading the bounce is
// right in one and wrong in the other, and without a monthly reading the EA cannot tell
// which it is looking at.
//
// The second half is the streak. PostWinFastEntry already removes the WAIT after a
// winning basket in the same direction - what it does not do is raise the score. A
// direction that has just paid, twice, in this market, has earned more than the removal
// of a delay. The same applies in reverse and more strongly: three losses in a row is
// the market telling the EA its read is wrong, and that deserves more than a note on
// the dashboard.
// ============================================================================

// Where has the market been going, over a horizon that deserves the word trend?
//   strength - 0..1, how established it is
int GlobalTrendDirection(double &strength, string &detail)
{
   strength = 0.0;
   detail = "";

   if(!EnableGlobalTrend || _Point <= 0.0)
      return 0;

   static int    gt_day = -1;
   static int    gt_dir = 0;
   static double gt_str = 0.0;
   static string gt_detail = "";

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Daily. A monthly trend does not change within a session, and reading daily bars
   // on every tick would be expensive for an answer that cannot move.
   if(gt_day == dt.day_of_year)
   {
      strength = gt_str; detail = gt_detail;
      return gt_dir;
   }
   gt_day = dt.day_of_year;
   gt_dir = 0; gt_str = 0.0; gt_detail = "";

   ENUM_TIMEFRAMES tf = GlobalTrendTF;
   int look = MathMax(20, GlobalTrendLookback);

   double newest = CandleClose(tf, 1);
   double oldest = CandleClose(tf, look);
   if(newest <= 0.0 || oldest <= 0.0)
      return 0;

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0;

   // Net travel in ATR terms. On a daily chart a move of several ATR over months is a
   // trend; a fraction of one is a range that happens to be long.
   double net_atr = MathAbs(newest - oldest) / _Point / atr;
   if(net_atr < GlobalTrendMinATR)
   {
      gt_detail = StringFormat("no monthly trend (%.1f ATR over %d bars)", net_atr, look);
      detail = gt_detail;
      return 0;
   }

   int dir = (newest > oldest) ? 1 : -1;

   // Efficiency, the same measure V260 uses on the approach: a trend that walked
   // straight there is a different thing from one that arrived after months of
   // fighting, even where the endpoints match.
   double walked = 0.0;
   for(int i = 1; i <= look; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0) continue;
      walked += (h - l) / _Point;
   }

   double net_pts = MathAbs(newest - oldest) / _Point;
   double efficiency = (walked > 0.0) ? (net_pts / walked) : 0.0;

   gt_dir = dir;
   gt_str = MathMin(1.0, (net_atr / MathMax(0.1, GlobalTrendFullATR)) *
                         (0.5 + 0.5 * MathMin(1.0, efficiency / MathMax(0.05, GlobalTrendFullEfficiency))));
   gt_detail = StringFormat("monthly trend %s, %.1f ATR at %.0f%% efficiency",
                            (dir > 0 ? "up" : "down"), net_atr, efficiency * 100.0);

   strength = gt_str; detail = gt_detail;
   return gt_dir;
}

// Is this a counter-trend trade at a level that the trend will probably go through?
// Returns 0..1.
double CounterTrendAtLevel(const int entry_dir, string &detail)
{
   detail = "";
   if(!EnableGlobalTrend || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   double gt_str = 0.0;
   string gt_detail = "";
   int gt_dir = GlobalTrendDirection(gt_str, gt_detail);

   if(gt_dir == 0 || gt_dir == entry_dir || gt_str < GlobalTrendMinStrength)
      return 0.0;

   // The trade runs against the monthly trend. That alone is worth something; what
   // makes it worth more is where it is being taken.
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   double severity = gt_str * CounterTrendBaseWeight;
   string parts = gt_detail + "; ";

   // A level in the direction the trade is betting on. The stronger it is, the more
   // tempting the trade looks - and a level is exactly where a counter-trend entry
   // gets taken, which is why it needs saying.
   double pz_str = 0.0;
   string pz_detail = "";
   double pz_level = 0.0;

   if(EnableProtectedZones)
      pz_level = ProtectedZoneNear(mid, entry_dir, pz_str, pz_detail);

   if(pz_level <= 0.0)
   {
      double lvl = (entry_dir > 0) ? ZoneMapNearestSupport(mid) : ZoneMapNearestResistance(mid);
      if(lvl > 0.0)
      {
         pz_level = lvl;
         pz_str = ZoneMapStrengthByTouches(lvl);
      }
   }

   if(pz_level > 0.0 && pz_str >= CounterTrendLevelMinStrength)
   {
      double gap = MathAbs(pz_level - mid) / _Point;
      if(gap <= ScaleAdjustedPoints(MathMax(1, CounterTrendLevelReach)))
      {
         // A level standing against an established trend is not a wall; it is the next
         // thing the trend has to get through, and most of the time it does.
         severity += (1.0 - CounterTrendBaseWeight) *
                     MathMin(1.0, pz_str / MathMax(0.1, CounterTrendLevelFullStrength));
         parts += StringFormat("fading into %.2f; ", pz_level);
      }
   }

   detail = StringFormat("against the %s", parts);
   return MathMax(0.0, MathMin(1.0, severity));
}


// ============================================================================
// V270: THE DAY'S REFERENCE PRICE, AND EFFORT THAT PRODUCED NOTHING
// ----------------------------------------------------------------------------
// Two readings, both cheap, both absent.
//
// THE DAILY OPEN is the price every participant measures the day against. Above it the
// day is up and buyers are in profit; below it the day is down. It is the single most
// widely watched reference on the chart and the EA does not know where it is.
// GlobalPeriodLevels added the weekly open in V252 and stopped there.
//
// VOLUME AGAINST PROGRESS is the other one. CandleParticipation reads volume on a
// single bar - whether the market showed up for it. What it cannot see is effort
// against result across bars: price making a new high on less volume than the previous
// high took means fewer participants are required to move it, which is what a move
// running out looks like before it turns. A new high on MORE volume is the opposite.
//
// Tick volume is not real volume, and on gold it is a reasonable proxy - each tick is
// a price change someone transacted at. The comparison is between two readings of the
// same flawed measure, which is where a flawed measure is most usable.
// ============================================================================

// Where did the day open, and which side of it is price on?
double DailyOpenPrice(int &side, double &distance_pts)
{
   side = 0;
   distance_pts = 0.0;

   if(!EnableDailyOpen || _Point <= 0.0)
      return 0.0;

   static int    do_day = -1;
   static double do_price = 0.0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(do_day != dt.day_of_year)
   {
      do_day = dt.day_of_year;
      do_price = CandleOpen(PERIOD_D1, 0);
   }

   if(do_price <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return do_price;

   distance_pts = MathAbs(mid - do_price) / _Point;
   side = (mid > do_price) ? 1 : ((mid < do_price) ? -1 : 0);

   return do_price;
}

// Is price making progress on less participation than it used to need? Returns 0..1 -
// how clear the divergence is.
//   fading_dir - the direction that is running out
double VolumeDivergence(int &fading_dir, string &detail)
{
   fading_dir = 0;
   detail = "";

   if(!EnableVolumeDivergence || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = VolumeDivergenceTF;
   if(tf != PERIOD_M5 && tf != PERIOD_M15 && tf != PERIOD_M30)
      return 0.0;

   static int    vd_bar = -100000;
   static double vd_val = 0.0;
   static int    vd_dir = 0;
   static string vd_detail = "";
   if(vd_bar > G_BARS_SEEN) vd_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(vd_bar == G_BARS_SEEN)
   {
      fading_dir = vd_dir; detail = vd_detail;
      return vd_val;
   }
   vd_bar = G_BARS_SEEN;
   vd_val = 0.0; vd_dir = 0; vd_detail = "";

   int look = MathMax(12, VolumeDivergenceLookback);
   int depth = 2;

   // Find the two most recent confirmed swing highs and the two most recent lows, with
   // the volume that produced each.
   double hi_price[2], hi_vol[2];
   double lo_price[2], lo_vol[2];
   int nh = 0, nl = 0;

   for(int i = depth + 1; i <= look && (nh < 2 || nl < 2); i++)
   {
      if(nh < 2)
      {
         double hv = CandleHigh(tf, i);
         bool ok = (hv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleHigh(tf, i - k) >= hv || CandleHigh(tf, i + k) >= hv) ok = false;
         if(ok)
         {
            hi_price[nh] = hv;
            hi_vol[nh] = (double)iVolume(_Symbol, tf, i);
            nh++;
         }
      }
      if(nl < 2)
      {
         double lv = CandleLow(tf, i);
         bool ok = (lv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleLow(tf, i - k) <= lv || CandleLow(tf, i + k) <= lv) ok = false;
         if(ok)
         {
            lo_price[nl] = lv;
            lo_vol[nl] = (double)iVolume(_Symbol, tf, i);
            nl++;
         }
      }
   }

   // Bearish divergence: a higher high reached on less volume than the one before it.
   if(nh >= 2 && hi_vol[1] > 0.0 && hi_price[0] > hi_price[1])
   {
      double vol_ratio = hi_vol[0] / hi_vol[1];
      if(vol_ratio <= VolumeDivergenceRatio)
      {
         vd_dir = 1;                    // the up move is running out
         vd_val = MathMin(1.0, (VolumeDivergenceRatio - vol_ratio) /
                               MathMax(0.01, VolumeDivergenceRatio - VolumeDivergenceFull));
         vd_detail = StringFormat("higher high on %.0f%% of the previous high's volume",
                                  vol_ratio * 100.0);
      }
   }

   // Bullish: a lower low on less volume.
   if(vd_val <= 0.0 && nl >= 2 && lo_vol[1] > 0.0 && lo_price[0] < lo_price[1])
   {
      double vol_ratio = lo_vol[0] / lo_vol[1];
      if(vol_ratio <= VolumeDivergenceRatio)
      {
         vd_dir = -1;                   // the down move is running out
         vd_val = MathMin(1.0, (VolumeDivergenceRatio - vol_ratio) /
                               MathMax(0.01, VolumeDivergenceRatio - VolumeDivergenceFull));
         vd_detail = StringFormat("lower low on %.0f%% of the previous low's volume",
                                  vol_ratio * 100.0);
      }
   }

   fading_dir = vd_dir; detail = vd_detail;
   return MathMax(0.0, MathMin(1.0, vd_val));
}


// ============================================================================
// V269: WHICH SETUPS ACTUALLY WORK HERE
// ----------------------------------------------------------------------------
// The EA recognises sixteen setup types and treats all of them as equally likely to
// work. It has never counted which ones do.
//
// That is a significant thing not to know. NEAR_ZONE_REACTION and MOMENTUM_SCALP are
// different trades with different failure modes, and on a given account, symbol and
// broker one of them may be reliable while the other is not. There is no way to reason
// this out from first principles - the answer depends on the spread, the session the
// account trades, and how this particular symbol behaves. It has to be measured.
//
// The candle layer already learns this way: V216 grades each candle source and weights
// it by its own accuracy. That mechanism works and was never extended to the setups
// themselves, which is the level where the difference matters most.
//
// So each type keeps its own record. Once a type has enough baskets behind it, its
// score is adjusted by how it has actually performed - a type that wins two thirds of
// the time earns a little, one that wins a third loses a little, and a type with four
// samples earns nothing either way because four samples mean nothing.
//
// The adjustment is deliberately small. This is a nudge built on the account's own
// history, not a filter, and a run of bad luck should not disable a sound setup.
// ============================================================================

double G_OTS_WINS[SIRUS_OPP_TYPE_COUNT];
double G_OTS_LOSSES[SIRUS_OPP_TYPE_COUNT];
double G_OTS_PROFIT[SIRUS_OPP_TYPE_COUNT];

string OppTypeGVKey(const int t)
{
   return StringFormat("NAVIUS_OTS_%s_%d_%d", _Symbol, MagicNumber, t);
}

void OppTypeStatsSave()
{
   if(!EnableSetupLearning || !PersistSetupLearning)
      return;
   for(int t = 0; t < SIRUS_OPP_TYPE_COUNT; t++)
   {
      GlobalVariableSet(OppTypeGVKey(t) + "W", G_OTS_WINS[t]);
      GlobalVariableSet(OppTypeGVKey(t) + "L", G_OTS_LOSSES[t]);
      GlobalVariableSet(OppTypeGVKey(t) + "P", G_OTS_PROFIT[t]);
   }
}

void OppTypeStatsRestore()
{
   if(!EnableSetupLearning || !PersistSetupLearning)
      return;
   for(int t = 0; t < SIRUS_OPP_TYPE_COUNT; t++)
   {
      string k = OppTypeGVKey(t);
      if(GlobalVariableCheck(k + "W")) G_OTS_WINS[t]   = GlobalVariableGet(k + "W");
      if(GlobalVariableCheck(k + "L")) G_OTS_LOSSES[t] = GlobalVariableGet(k + "L");
      if(GlobalVariableCheck(k + "P")) G_OTS_PROFIT[t] = GlobalVariableGet(k + "P");
   }
}

// Called when a basket closes, with the type that opened it.
void OppTypeRecord(const int t, const double profit)
{
   if(!EnableSetupLearning || t <= 0 || t >= SIRUS_OPP_TYPE_COUNT)
      return;

   if(profit > 0.0)
      G_OTS_WINS[t] += 1.0;
   else if(IsMeaningfulLoss(profit))   // BOSQICH 1
      G_OTS_LOSSES[t] += 1.0;

   G_OTS_PROFIT[t] += profit;

   // Keep the window recent. A record covering a different market describes that
   // market rather than this one.
   double total = G_OTS_WINS[t] + G_OTS_LOSSES[t];
   if(total > (double)SetupLearningMaxSamples)
   {
      double sc = (double)SetupLearningMaxSamples / total;
      G_OTS_WINS[t] *= sc;
      G_OTS_LOSSES[t] *= sc;
      G_OTS_PROFIT[t] *= sc;
   }

   OppTypeStatsSave();
}

// How has this type performed? Returns a score adjustment, or 0 when there is not
// enough history to say.
int SetupTypeAdjustment(const int t, string &detail)
{
   detail = "";
   if(!EnableSetupLearning || t <= 0 || t >= SIRUS_OPP_TYPE_COUNT)
      return 0;

   double wins = G_OTS_WINS[t];
   double losses = G_OTS_LOSSES[t];
   double total = wins + losses;

   if(total < (double)SetupLearningMinSamples)
      return 0;

   double rate = wins / total;

   // Expectancy matters more than win rate for a grid - a type that wins often and
   // loses badly is worse than the rate suggests, and the profit total captures that
   // where a count cannot.
   double avg = G_OTS_PROFIT[t] / total;

   int adj = 0;

   if(rate >= SetupLearningGoodRate && avg > 0.0)
   {
      double over = (rate - SetupLearningGoodRate) / MathMax(0.01, 1.0 - SetupLearningGoodRate);
      adj = (int)MathRound(MathMin(1.0, over) * (double)SetupLearningMaxBonus);
      if(adj > 0)
         detail = StringFormat("%s has won %.0f%% of %.0f (avg %+.2f)",
                               OpportunityTypeToString((ENUM_OPPORTUNITY_TYPE)t), rate * 100.0, total, avg);
   }
   else if(rate <= SetupLearningPoorRate || avg < 0.0)
   {
      double under = (SetupLearningPoorRate - rate) / MathMax(0.01, SetupLearningPoorRate);
      if(avg < 0.0 && under < 0.3)
         under = 0.3;                    // losing money counts even at a decent win rate
      adj = -(int)MathRound(MathMin(1.0, under) * (double)SetupLearningMaxPenalty);
      if(adj < 0)
         detail = StringFormat("%s has won %.0f%% of %.0f (avg %+.2f)",
                               OpportunityTypeToString((ENUM_OPPORTUNITY_TYPE)t), rate * 100.0, total, avg);
   }

   return adj;
}

// A one-line summary of the best and worst performers, for the dashboard.
string SetupLearningText()
{
   if(!EnableSetupLearning)
      return "";

   int best = -1, worst = -1;
   double best_rate = 0.0, worst_rate = 2.0;
   double rated = 0.0;

   for(int t = 1; t < SIRUS_OPP_TYPE_COUNT; t++)
   {
      double total = G_OTS_WINS[t] + G_OTS_LOSSES[t];
      if(total < (double)SetupLearningMinSamples)
         continue;
      rated += 1.0;
      double rate = G_OTS_WINS[t] / total;
      if(best < 0 || rate > best_rate)  { best = t;  best_rate = rate; }
      if(worst < 0 || rate < worst_rate) { worst = t; worst_rate = rate; }
   }

   if(rated <= 0.0)
      return "setups: none rated yet";

   if(best == worst)
      return StringFormat("setups: %s %.0f%% (1 rated)",
                          OpportunityTypeToString((ENUM_OPPORTUNITY_TYPE)best), best_rate * 100.0);

   return StringFormat("setups: best %s %.0f%%, worst %s %.0f%% (%.0f rated)",
                       OpportunityTypeToString((ENUM_OPPORTUNITY_TYPE)best), best_rate * 100.0,
                       OpportunityTypeToString((ENUM_OPPORTUNITY_TYPE)worst), worst_rate * 100.0,
                       rated);
}


// ============================================================================
// V268: THE DAYS WHEN NOBODY IS THERE
// ----------------------------------------------------------------------------
// BrokerHolidayIsCautionActive exists and works, and it only works if someone types
// the dates in. BrokerHolidayDates is a manual list that has to be refreshed every
// year, and a list nobody updated is a guard that quietly stopped guarding.
//
// Most thin days do not need a list. They are calculable:
//
//   The fixed holidays - January 1st, December 25th and 26th - never move.
//   Late December is thin from about the 20th regardless of which days fall where.
//   August is the European holiday month; volume is structurally lower all month.
//   Month-end and quarter-end bring rebalancing flows that move price for reasons
//   that have nothing to do with anything the EA reads.
//
// None of that needs maintaining. What it needs is to be known, because a ladder built
// in a thin market is a ladder built on the assumption that someone will be there to
// take the other side of the recovery - and on these days there is a decent chance
// nobody is.
//
// The moving holidays (Thanksgiving, Easter, national days) still need the manual list.
// This covers the ones that do not.
// ============================================================================

// How thin is today likely to be, from the calendar alone? 0..1
double CalendarThinness(string &detail)
{
   detail = "";
   if(!EnableCalendarThinness)
      return 0.0;

   static int    ct_day = -1;
   static double ct_val = 0.0;
   static string ct_detail = "";

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Once a day is enough - none of these change within a session.
   if(ct_day == dt.day_of_year)
   {
      detail = ct_detail;
      return ct_val;
   }
   ct_day = dt.day_of_year;
   ct_val = 0.0; ct_detail = "";

   double thin = 0.0;
   string parts = "";

   // --- the fixed holidays ---------------------------------------------------
   bool fixed_holiday = (dt.mon == 1 && dt.day == 1) ||
                        (dt.mon == 12 && (dt.day == 25 || dt.day == 26));
   if(fixed_holiday)
   {
      thin += ThinFixedHolidayWeight;
      parts += "fixed holiday; ";
   }

   // --- the week around them -------------------------------------------------
   // Late December empties out regardless of where the weekend falls, and the first
   // days of January are not much better.
   if(dt.mon == 12 && dt.day >= ThinYearEndFromDay)
   {
      thin += ThinYearEndWeight;
      parts += "year end; ";
   }
   else if(dt.mon == 1 && dt.day <= ThinYearStartToDay)
   {
      thin += ThinYearEndWeight * 0.7;
      parts += "new year; ";
   }

   // --- August ---------------------------------------------------------------
   // The European holiday month. Volume is structurally lower for the whole of it,
   // which is different from a single quiet day.
   if(dt.mon == 8)
   {
      thin += ThinAugustWeight;
      parts += "August; ";
   }

   // --- month and quarter end ------------------------------------------------
   // Rebalancing moves price for reasons unrelated to anything readable here. Not
   // thin exactly - the flow is real - but it is flow the EA cannot anticipate.
   int days_in_month = 31;
   if(dt.mon == 2)                                      days_in_month = 28;
   else if(dt.mon == 4 || dt.mon == 6 ||
           dt.mon == 9 || dt.mon == 11)                 days_in_month = 30;

   if(dt.day >= days_in_month - ThinMonthEndDays)
   {
      bool quarter = (dt.mon == 3 || dt.mon == 6 || dt.mon == 9 || dt.mon == 12);
      thin += quarter ? ThinQuarterEndWeight : ThinMonthEndWeight;
      parts += quarter ? "quarter end; " : "month end; ";
   }

   ct_val = MathMax(0.0, MathMin(1.0, thin));
   if(ct_val > 0.0)
      ct_detail = StringFormat("thin day: %s", parts);

   detail = ct_detail;
   return ct_val;
}


// ============================================================================
// V266: WHEN THE LARGER SCALE DISAGREES, AND WHEN BOTH SIDES LOOK GOOD
// ----------------------------------------------------------------------------
// Every reading in this EA contributes points to one total. That means an M5 support
// and an H1 downtrend arrive as two numbers which are added together, and the sum can
// come out positive - so the EA buys the support inside the downtrend. Three live
// losses were exactly that trade.
//
// V250 addressed the specific case of a completed reversal pattern. This is the general
// one: the larger scale does not vote alongside the smaller, it decides what the
// smaller one MEANS. A support in an uptrend is a place to buy. The identical support
// in a downtrend is a step on the way down. Addition cannot express that difference,
// because addition treats both inputs as the same kind of thing.
//
// The second half is related and simpler. The scanner finds the best setup in one
// direction and scores it. It never asks what the OTHER direction would have scored.
// When both sides score well that is not two opportunities - it is a market that has
// not decided, and the honest reading of a market that has not decided is to wait. A
// score of 11 for a buy means something quite different when the sell also scores 9.
// ============================================================================

// How much does the higher timeframe contradict this direction? 0..1
double HigherScaleConflict(const int entry_dir, string &detail)
{
   detail = "";
   if(!EnableScaleHierarchy || entry_dir == 0)
      return 0.0;

   static int    hs_bar = -100000;
   static int    hs_dir = 0;
   static double hs_val = 0.0;
   static string hs_detail = "";
   if(hs_bar > G_BARS_SEEN) hs_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(hs_bar == G_BARS_SEEN && hs_dir == entry_dir)
   {
      detail = hs_detail;
      return hs_val;
   }
   hs_bar = G_BARS_SEEN;
   hs_dir = entry_dir;
   hs_val = 0.0; hs_detail = "";

   double against = 0.0;
   string parts = "";

   // The scales, weighted by how much authority each has over the others. An H4 trend
   // outranks an H1 one, and both outrank anything on M15.
   ENUM_TIMEFRAMES tfs[3];
   double weights[3];
   tfs[0] = HierarchyTF1; weights[0] = HierarchyWeight1;
   tfs[1] = HierarchyTF2; weights[1] = HierarchyWeight2;
   tfs[2] = HierarchyTF3; weights[2] = HierarchyWeight3;

   for(int i = 0; i < 3; i++)
   {
      double conv = 0.0, travelled = 0.0;
      int d = StructureDirOnTF(tfs[i], conv, travelled);
      if(d == 0)
         continue;

      if(d == -entry_dir)
      {
         // Weighted by how convincing that scale's structure is - a two-step sequence
         // on H4 is not the same authority as a five-step one.
         against += weights[i] * MathMax(0.35, conv);
         parts += StringFormat("%s against; ", EnumToString(tfs[i]));
      }
      else if(d == entry_dir)
      {
         // Agreement reduces the conflict rather than adding a bonus - the bonus side
         // is already covered by the alignment reading in V225.
         against -= weights[i] * 0.5 * MathMax(0.35, conv);
      }
   }

   hs_val = MathMax(0.0, MathMin(1.0, against));
   if(hs_val > 0.0)
      hs_detail = StringFormat("larger scales disagree (%s)", parts);

   detail = hs_detail;
   return hs_val;
}

// What would the opposite direction have scored? Returns its base-plus-bonus estimate.
// Deliberately cheap: this runs inside scoring, so it reads the cached verdicts the
// other modules have already produced rather than scoring the other side fully.
double OppositeSideStrength(const int entry_dir, string &detail)
{
   detail = "";
   if(!EnableAmbiguityCheck || entry_dir == 0)
      return 0.0;

   int opp = -entry_dir;
   double points = 0.0;
   string parts = "";

   // Structure on the entry timeframe.
   if(EnableLocalStructure)
   {
      LocalStructureUpdate();
      if(G_LS_DIR == opp && G_LS_STATE != LSTRUCT_CHOPPY)
      {
         points += AmbiguityStructureWeight;
         parts += "structure; ";
      }
   }

   // A named situation.
   if(EnableSituationRead && G_SITUATION != SIT_NONE && G_SITUATION_DIR == opp)
   {
      points += AmbiguitySituationWeight;
      parts += "situation; ";
   }

   // Timeframe alignment.
   if(EnableStructureMTF)
   {
      int    al_dir = 0;
      double al_w = 0.0;
      string al_d = "";
      int al = StructureAlignment(al_dir, al_w, al_d);
      if(al == TFALIGN_FULL && al_dir == opp)
      {
         points += AmbiguityAlignWeight;
         parts += "timeframes; ";
      }
   }

   // A level the opposite side would be trading away from.
   if(_Point > 0.0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
      if(mid > 0.0)
      {
         double behind = (opp > 0) ? ZoneMapNearestSupport(mid) : ZoneMapNearestResistance(mid);
         if(behind > 0.0)
         {
            double gap = MathAbs(mid - behind) / _Point;
            if(gap <= ScaleAdjustedPoints(MathMax(1, AmbiguityLevelReach)) &&
               ZoneMapStrengthByTouches(behind) >= AmbiguityLevelMinStrength)
            {
               points += AmbiguityLevelWeight;
               parts += "a level behind it; ";
            }
         }
      }
   }

   if(points <= 0.0)
      return 0.0;

   detail = StringFormat("the other side also has %s", parts);
   return points;
}


// ============================================================================
// V264: LEVELS THAT HAVE EARNED THE RIGHT TO BE REMEMBERED
// ----------------------------------------------------------------------------
// A shelf at 4305-4315 held on the 2nd and 3rd of September. Price returned to it on
// the 11th and the EA did not see it.
//
// It was never lost from the cache - the H1 lookback covers ten days and the shelf was
// inside it. What happened is subtler and worse: ZoneMapScanTFSupport returns the
// NEAREST support below price, and in nine days of trading there were dozens of newer
// swings between price and that shelf. Every one of them outranked it, because nearest
// is the only comparison the scan makes.
//
// So a level with three touches and a week of history loses to a swing that formed
// forty minutes ago and has never been tested. StrongZoneOverride exists to correct
// this and only fires when the two are already close together; across nine days they
// are not.
//
// The fix is to keep the levels that have earned it in a list of their own. Three or
// more touches, or a higher timeframe, or a break it survived - any of those and the
// level goes on a shelf that the nearest-swing scan cannot push it off. The list stays
// small because those conditions are rare, which is what makes it affordable.
// ============================================================================


double G_PZ_PRICE[PROTECTED_ZONE_MAX];
double G_PZ_STRENGTH[PROTECTED_ZONE_MAX];
int    G_PZ_TOUCHES[PROTECTED_ZONE_MAX];
datetime G_PZ_SEEN[PROTECTED_ZONE_MAX];
int    G_PZ_COUNT = 0;
int    G_PZ_BAR   = -100000;

// Rebuild the protected list. Runs on a slow cadence - these levels change over days,
// not bars, and the scan is the expensive part.
void ProtectedZonesRefresh()
{
   if(!EnableProtectedZones || _Point <= 0.0)
      return;

   if(G_PZ_BAR > -100000 && (G_BARS_SEEN - G_PZ_BAR) < MathMax(1, ProtectedZoneRefreshBars))
      return;
   G_PZ_BAR = G_BARS_SEEN;
   G_PZ_COUNT = 0;

   ZoneMapRefreshSwingCache();

   // Walk the cached swings from the higher timeframes down. A level qualifies on
   // touches, on the timeframe that drew it, or on having survived a break.
   // V272: D1 added at the front. A daily level is the strongest thing on the chart and it was the
   // one scale the protected list did not consult - so the levels least likely to be near price, and
   // therefore most likely to be outranked by a recent swing, were also the ones with no protection
   // at all.
   ENUM_TIMEFRAMES tfs[5];
   tfs[0] = PERIOD_D1; tfs[1] = PERIOD_H4; tfs[2] = PERIOD_H1;
   tfs[3] = PERIOD_M30; tfs[4] = PERIOD_M15;

   for(int t = 0; t < 5 && G_PZ_COUNT < PROTECTED_ZONE_MAX; t++)
   {
      int idx = ZMTFIndex(tfs[t]);
      if(idx < 0)
         continue;

      for(int side = 0; side < 2 && G_PZ_COUNT < PROTECTED_ZONE_MAX; side++)
      {
         int cnt = (side == 0) ? G_ZMC_HIGH_COUNT[idx] : G_ZMC_LOW_COUNT[idx];

         for(int k = 0; k < cnt && G_PZ_COUNT < PROTECTED_ZONE_MAX; k++)
         {
            double lvl = (side == 0) ? G_ZMC_HIGH_PRICE[idx][k] : G_ZMC_LOW_PRICE[idx][k];
            if(lvl <= 0.0)
               continue;

            // Already on the list? Levels repeat across timeframes, which is itself a
            // sign of quality - but one entry each is enough.
            bool dup = false;
            double dup_tol = ScaleAdjustedPoints(MathMax(1, ProtectedZoneMergeTolerance)) * _Point;
            for(int d = 0; d < G_PZ_COUNT && !dup; d++)
               if(MathAbs(G_PZ_PRICE[d] - lvl) <= dup_tol)
                  dup = true;
            if(dup)
               continue;

            int touches = (int)MathRound(ZoneMapConfluenceCount(lvl));
            double strength = ZoneMapStrengthByTouches(lvl);

            // The qualifying conditions. Any one is enough - they are all evidence the
            // market recognises this price, arrived at different ways.
            bool by_touches  = (touches >= ProtectedZoneMinTouches);
            bool by_tf       = (t <= 2);           // V272: D1, H4 or H1 drew it
            bool by_strength = (strength >= ProtectedZoneMinStrength);

            if(!by_touches && !by_tf && !by_strength)
               continue;

            G_PZ_PRICE[G_PZ_COUNT]    = lvl;
            G_PZ_STRENGTH[G_PZ_COUNT] = strength;
            G_PZ_TOUCHES[G_PZ_COUNT]  = touches;
            G_PZ_SEEN[G_PZ_COUNT]     = TimeCurrent();
            G_PZ_COUNT++;
         }
      }
   }

   if((ProtectedZonePrintOnUse && G_VERBOSE) && G_PZ_COUNT > 0)
      PrintFormat("[SIRUS v264 PROTECTED] %d levels held", G_PZ_COUNT);
}

// The nearest protected level in a direction, ignoring everything the ordinary scan
// would have preferred.
double ProtectedZoneNear(const double price, const int dir, double &strength, string &detail)
{
   strength = 0.0;
   detail = "";

   if(!EnableProtectedZones || price <= 0.0 || dir == 0)
      return 0.0;

   ProtectedZonesRefresh();
   if(G_PZ_COUNT <= 0)
      return 0.0;

   double best = 0.0, best_str = 0.0;
   int    best_touches = 0;

   for(int i = 0; i < G_PZ_COUNT; i++)
   {
      double lvl = G_PZ_PRICE[i];
      if(lvl <= 0.0)
         continue;

      bool ahead = (dir > 0) ? (lvl > price) : (lvl < price);
      if(!ahead)
         continue;

      if(best <= 0.0 || MathAbs(lvl - price) < MathAbs(best - price))
      {
         best = lvl;
         best_str = G_PZ_STRENGTH[i];
         best_touches = G_PZ_TOUCHES[i];
      }
   }

   if(best <= 0.0)
      return 0.0;

   strength = best_str;
   detail = StringFormat("protected %.2f (%d touches, %.1f strength)",
                         best, best_touches, best_str);
   return best;
}


// ============================================================================
// V262: WHICH END OF THE CANDLE CAME FIRST
// ----------------------------------------------------------------------------
// A bar with wicks on both sides tells you price visited two extremes. It does not
// tell you in what ORDER, and the order is most of the meaning.
//
//   Down first, then up: the lows were swept, sellers were cleared out, and buyers
//   took the bar back. Whatever happens next starts from a position where the selling
//   pressure has already been spent.
//
//   Up first, then down: the opposite. The rally was the trap.
//
// From open, high, low and close alone these are indistinguishable - the four numbers
// are identical either way. The close position hints at it and hints badly: a bar that
// swept its lows, rallied hard, and faded slightly at the end closes mid-range and
// looks balanced, when it was nothing of the kind.
//
// The sequence is recoverable from the timeframe below. An M5 bar is five M1 bars, and
// their order is not in doubt. This reads them and reports which extreme was reached
// first - the one piece of intra-bar information that OHLC genuinely cannot carry.
// ============================================================================

// Which extreme did this bar reach first? +1 high first, -1 low first, 0 unknown.
//   separation - 0..1, how clearly separated the two events were in time
int CandleExtremeOrder(const int shift, double &separation, string &detail)
{
   separation = 0.0;
   detail = "";

   if(!EnableWickOrder || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = WickOrderTF;
   ENUM_TIMEFRAMES sub = WickOrderSubTF;

   // Only pairs where the sub-timeframe genuinely divides the main one, and only on
   // the small scales where the reading is about a single event rather than a session.
   if(!((tf == PERIOD_M5  && sub == PERIOD_M1) ||
        (tf == PERIOD_M15 && sub == PERIOD_M1) ||
        (tf == PERIOD_M15 && sub == PERIOD_M5)))
      return 0;

   double h = CandleHigh(tf, shift), l = CandleLow(tf, shift);
   if(h <= 0.0 || l <= 0.0 || h <= l)
      return 0;

   // How many sub-bars make up one main bar, and where this bar's sub-bars start.
   int ratio = (int)(PeriodSeconds(tf) / PeriodSeconds(sub));
   if(ratio < 2)
      return 0;

   datetime bar_time = iTime(_Symbol, tf, shift);
   if(bar_time <= 0)
      return 0;

   int start = iBarShift(_Symbol, sub, bar_time, false);
   if(start < 0)
      return 0;

   // Walk the sub-bars from oldest to newest, noting when each extreme was first
   // touched. Sub-bar indices count backwards, so the oldest is the largest.
   int high_at = -1, low_at = -1;
   double tol = ScaleAdjustedPoints(MathMax(1, WickOrderTolerance)) * _Point;

   for(int k = 0; k < ratio; k++)
   {
      int idx = start - k;
      if(idx < 0)
         break;

      double sh = CandleHigh(sub, idx);
      double sl = CandleLow(sub, idx);
      if(sh <= 0.0 || sl <= 0.0)
         continue;

      int age = ratio - k;   // larger means earlier in the bar

      if(high_at < 0 && sh >= h - tol)
         high_at = age;
      if(low_at < 0 && sl <= l + tol)
         low_at = age;
   }

   if(high_at < 0 || low_at < 0 || high_at == low_at)
      return 0;

   // Separation: extremes touched in adjacent sub-bars are almost simultaneous and the
   // order means little. Several sub-bars apart is a genuine sequence.
   separation = MathMin(1.0, (double)MathAbs(high_at - low_at) /
                             MathMax(1.0, (double)ratio * WickOrderFullSeparation));

   int first = (high_at > low_at) ? 1 : -1;   // earlier = larger age

   detail = StringFormat("%s reached first, %d sub-bars apart",
                         (first > 0 ? "high" : "low"), MathAbs(high_at - low_at));
   return first;
}

// What does the order imply for direction? The side reached FIRST is the side that got
// cleared; the move that follows tends to run the other way.
int WickOrderBias(double &conviction, string &detail)
{
   conviction = 0.0;
   detail = "";

   if(!EnableWickOrder)
      return 0;

   static int    wo_bar = -100000;
   static int    wo_dir = 0;
   static double wo_conv = 0.0;
   static string wo_detail = "";
   if(wo_bar > G_BARS_SEEN) wo_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(wo_bar == G_BARS_SEEN)
   {
      conviction = wo_conv; detail = wo_detail;
      return wo_dir;
   }
   wo_bar = G_BARS_SEEN;
   wo_dir = 0; wo_conv = 0.0; wo_detail = "";

   ENUM_TIMEFRAMES tf = WickOrderTF;
   double o = CandleOpen(tf, 1), c = CandleClose(tf, 1);
   double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0;

   double range = h - l;
   if(range <= 0.0)
      return 0;

   // Both wicks have to exist, or there is no order to read.
   double upper = (h - MathMax(o, c)) / range;
   double lower = (MathMin(o, c) - l) / range;
   if(upper < WickOrderMinWick || lower < WickOrderMinWick)
      return 0;

   double sep = 0.0;
   string od = "";
   int first = CandleExtremeOrder(1, sep, od);
   if(first == 0 || sep < WickOrderMinSeparation)
      return 0;

   // The extreme reached first was the one being swept. What follows runs the other way.
   wo_dir = -first;
   wo_conv = sep * MathMin(1.0, (upper + lower) / MathMax(0.1, WickOrderFullWickTotal));
   wo_detail = StringFormat("%s - the %s side was taken first",
                            od, (first > 0 ? "upper" : "lower"));

   conviction = wo_conv; detail = wo_detail;
   return wo_dir;
}


// ============================================================================
// V261: THE HOUR NUMBERS ARE WRONG FOR HALF THE YEAR
// ----------------------------------------------------------------------------
// Every session boundary in this EA is a fixed hour: Asia ends at 7, London and NY run
// 7 to 21, the NY killzone is 15 to 17, Friday entries stop at 20. All of them are
// broker hours, and all of them assume the relationship between broker time and
// market time never changes.
//
// It changes twice a year. London moves to UTC+1 in late March and back in late
// October; New York moves to UTC-4 in early March and back in early November. The
// broker's clock does not move with them, so from March to November every one of those
// numbers is an hour late - the London open is missed, and the killzone covers the
// wrong sixty minutes.
//
// The two regions also switch on different dates, and for the two weeks between them
// London and New York overlap differently than they do for the rest of the year.
//
// Separately, and more mundanely: the operator reads the dashboard in local time while
// the EA works in broker time. A five-hour difference has already caused one wrong
// conclusion about why the EA stopped trading on a Friday. Showing both costs one line.
// ============================================================================

// Is European summer time in effect? Last Sunday of March to last Sunday of October.
bool IsEuropeanDST(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   if(dt.mon < 3 || dt.mon > 10)
      return false;
   if(dt.mon > 3 && dt.mon < 10)
      return true;

   // March and October: it depends on whether the last Sunday has passed. Work out
   // which day that is - the 31st minus its weekday gives the last Sunday's date.
   MqlDateTime last;
   TimeToStruct(t, last);
   last.day = 31;
   last.hour = 0; last.min = 0; last.sec = 0;
   datetime end_of_month = StructToTime(last);
   MqlDateTime eom;
   TimeToStruct(end_of_month, eom);
   int last_sunday = 31 - eom.day_of_week;

   if(dt.mon == 3)
      return (dt.day > last_sunday || (dt.day == last_sunday && dt.hour >= 1));
   return (dt.day < last_sunday || (dt.day == last_sunday && dt.hour < 1));
}

// And American: second Sunday of March to first Sunday of November.
bool IsAmericanDST(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   if(dt.mon < 3 || dt.mon > 11)
      return false;
   if(dt.mon > 3 && dt.mon < 11)
      return true;

   if(dt.mon == 3)
   {
      // Second Sunday. Find the first, add seven.
      MqlDateTime first;
      TimeToStruct(t, first);
      first.day = 1; first.hour = 0; first.min = 0; first.sec = 0;
      datetime d1 = StructToTime(first);
      MqlDateTime f;
      TimeToStruct(d1, f);
      int first_sunday = 1 + ((7 - f.day_of_week) % 7);
      int second_sunday = first_sunday + 7;
      return (dt.day > second_sunday || (dt.day == second_sunday && dt.hour >= 2));
   }

   // November - first Sunday.
   MqlDateTime first;
   TimeToStruct(t, first);
   first.day = 1; first.hour = 0; first.min = 0; first.sec = 0;
   datetime d1 = StructToTime(first);
   MqlDateTime f;
   TimeToStruct(d1, f);
   int first_sunday = 1 + ((7 - f.day_of_week) % 7);
   return (dt.day < first_sunday || (dt.day == first_sunday && dt.hour < 2));
}

// How many hours to shift a session boundary that was written for winter.
int SessionDSTShift(const bool american)
{
   if(!EnableDSTAdjust)
      return 0;

   datetime now = TimeCurrent();
   bool on = american ? IsAmericanDST(now) : IsEuropeanDST(now);

   // In summer the market opens an hour EARLIER in broker terms, so a boundary written
   // for winter has to move back by one.
   return on ? -1 : 0;
}

// A session hour corrected for the season.
int AdjustedSessionHour(const int winter_hour, const bool american)
{
   int h = winter_hour + SessionDSTShift(american);
   if(h < 0)  h += 24;
   if(h > 23) h -= 24;
   return h;
}

// Broker time and the operator's time, side by side.
string TimeBothZones()
{
   datetime bt = TimeCurrent();
   MqlDateTime b;
   TimeToStruct(bt, b);

   datetime lt = bt + (datetime)((long)LocalUTCOffsetHours * 3600);
   MqlDateTime l;
   TimeToStruct(lt, l);

   string season = "";
   if(EnableDSTAdjust)
      season = IsEuropeanDST(bt) ? " | EU summer" : " | EU winter";

   return StringFormat("%02d:%02d broker | %02d:%02d local%s",
                       b.hour, b.min, l.hour, l.min, season);
}


// ============================================================================
// V260: HOW PRICE ARRIVED
// ----------------------------------------------------------------------------
// CandleLocationWeight asks where a wick's tip landed. CandleRelevance asks how close
// price is to a level. Both are questions about POSITION, and position is only half of
// context.
//
// The other half is arrival. A rejection candle at support after a fast one-way drop
// and the same candle after forty minutes of grinding sideways into that support are
// opposite situations:
//
//   Arrived fast - the move overshot, the sellers who drove it are done, and the
//   level is being tested by exhaustion. These hold.
//
//   Arrived slowly - buyers have been absorbed steadily, each attempt to bounce has
//   been weaker than the last, and the level is being worn down. These break.
//
// Every candle reading in the EA treats them identically, because none of them looks
// at the bars BEFORE the one being read. The shape is the same; what produced it is
// not.
// ============================================================================

// How did price get to where it is? Returns 0..1, where 1 is a fast one-way approach
// and 0 is a slow grind.
//   toward_dir - the direction price travelled to arrive here
double ArrivalQuality(int &toward_dir, string &detail)
{
   toward_dir = 0;
   detail = "";

   if(!EnableArrivalRead || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = ArrivalTF;
   if(tf != PERIOD_M1 && tf != PERIOD_M5 && tf != PERIOD_M15)
      return 0.0;

   static int    ar_bar = -100000;
   static double ar_q = 0.0;
   static int    ar_dir = 0;
   static string ar_detail = "";
   if(ar_bar > G_BARS_SEEN) ar_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(ar_bar == G_BARS_SEEN)
   {
      toward_dir = ar_dir; detail = ar_detail;
      return ar_q;
   }
   ar_bar = G_BARS_SEEN;
   ar_q = 0.0; ar_dir = 0; ar_detail = "";

   int bars = MathMax(4, MathMin(20, ArrivalBars));

   double start = CandleOpen(tf, bars);
   double now   = CandleClose(tf, 1);
   if(start <= 0.0 || now <= 0.0)
      return 0.0;

   // Net distance covered, against the ground actually walked. A straight move covers
   // nearly all the distance it travels; a grind covers a fraction of it.
   double net = MathAbs(now - start) / _Point;

   double walked = 0.0;
   for(int i = 1; i <= bars; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0)
         continue;
      walked += (h - l) / _Point;
   }

   if(walked <= 0.0 || net <= 0.0)
      return 0.0;

   // This is the whole measurement: efficiency. Ninety percent means price went almost
   // straight there. Twenty percent means it spent the whole window fighting.
   double efficiency = net / walked;

   // The move also has to be worth calling a move. Ten points of perfectly efficient
   // drift is not an approach.
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;
   double net_atr = net / atr;
   if(net_atr < ArrivalMinNetATR)
      return 0.0;

   ar_dir = (now > start) ? 1 : -1;

   // Scale efficiency into the band that actually distinguishes the two cases. Below
   // the grind threshold everything is a grind; above the fast one, everything is fast.
   if(efficiency <= ArrivalGrindBelow)
      ar_q = 0.0;
   else if(efficiency >= ArrivalFastAbove)
      ar_q = 1.0;
   else
      ar_q = (efficiency - ArrivalGrindBelow) /
             MathMax(0.01, ArrivalFastAbove - ArrivalGrindBelow);

   ar_detail = StringFormat("price arrived %s (%.0f%% efficient over %.1f ATR)",
                            (ar_q >= 0.5 ? "fast" : "slowly"),
                            efficiency * 100.0, net_atr);

   toward_dir = ar_dir; detail = ar_detail;
   return MathMax(0.0, MathMin(1.0, ar_q));
}


// ============================================================================
// V258: SIZES THAT ARE GOING SOMEWHERE
// ----------------------------------------------------------------------------
// CandleSequenceRead compares the most recent candle to the average of the last five
// and calls the result expanding or contracting. That is a snapshot: one bar measured
// against a mean.
//
// A snapshot cannot distinguish between two very different things. One small candle
// after four large ones is a pause - buyers caught their breath and will probably
// continue. Four candles each smaller than the one before it is a move running out of
// people willing to pay, and the difference matters enormously to anything entering
// behind it.
//
// Both read as "contracting" to a comparison against the mean, because the mean does
// not know the order the candles arrived in.
//
// So this measures the PROGRESSION - whether each bar is smaller than its predecessor,
// or larger - and how consistently. Three consecutive steps in one direction is a
// statement; the same three sizes shuffled is noise.
// ============================================================================


string CandleProgressionName(const int p)
{
   if(p == CSEQ_FADING)   return "fading";
   if(p == CSEQ_BUILDING) return "building";
   return "flat";
}

// Are the candles progressively changing size? Returns 0..1 - how consistently.
//   progression - CSEQ_FADING, CSEQ_BUILDING or CSEQ_NONE
//   lean        - the direction the bodies point, when they agree
double CandleProgression(int &progression, int &lean, string &detail)
{
   progression = CSEQ_NONE;
   lean = 0;
   detail = "";

   if(!EnableCandleProgression || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = CandleProgressionTF;

   // Small timeframes only. On H1 and above, four consecutive shrinking bars span most
   // of a session and describe the session rather than a move losing steam.
   if(tf != PERIOD_M1 && tf != PERIOD_M5 && tf != PERIOD_M15)
      return 0.0;

   static int    cp_bar = -100000;
   static double cp_conv = 0.0;
   static int    cp_prog = CSEQ_NONE;
   static int    cp_lean = 0;
   static string cp_detail = "";
   if(cp_bar > G_BARS_SEEN) cp_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(cp_bar == G_BARS_SEEN)
   {
      progression = cp_prog; lean = cp_lean; detail = cp_detail;
      return cp_conv;
   }
   cp_bar = G_BARS_SEEN;
   cp_conv = 0.0; cp_prog = CSEQ_NONE; cp_lean = 0; cp_detail = "";

   int bars = MathMax(3, MathMin(6, CandleProgressionBars));

   double sizes[6];
   int    dirs[6];
   int n = 0;

   for(int i = 1; i <= bars; i++)
   {
      double o = CandleOpen(tf, i), c = CandleClose(tf, i);
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         break;

      // Body rather than range - the range includes wicks, and a shrinking body with
      // growing wicks is the clearest form of a move running out.
      sizes[n] = MathAbs(c - o) / _Point;
      dirs[n]  = (c > o) ? 1 : ((c < o) ? -1 : 0);
      n++;
   }

   if(n < 3)
      return 0.0;

   // Walk from oldest to newest counting consistent steps. sizes[0] is the most
   // recent, so the comparison runs backwards through the array.
   int shrink_steps = 0, grow_steps = 0;
   for(int k = n - 1; k > 0; k--)
   {
      if(sizes[k] <= 0.0)
         continue;
      double ratio = sizes[k - 1] / sizes[k];
      if(ratio <= CandleProgressionStepDown)
         shrink_steps++;
      else if(ratio >= CandleProgressionStepUp)
         grow_steps++;
      else
      {
         // A step that goes neither way breaks the run. A progression interrupted is
         // not a progression - that is the whole point of measuring order.
         shrink_steps = 0;
         grow_steps = 0;
      }
   }

   int steps = MathMax(shrink_steps, grow_steps);
   if(steps < MathMax(2, CandleProgressionMinSteps))
      return 0.0;

   cp_prog = (shrink_steps > grow_steps) ? CSEQ_FADING : CSEQ_BUILDING;

   // Which way were the bodies pointing? A fading sequence of bullish bars is buyers
   // running out; the same fade on bearish bars is sellers running out, and they lead
   // to opposite conclusions.
   int up = 0, down = 0;
   for(int k = 0; k < n; k++)
   {
      if(dirs[k] > 0) up++;
      else if(dirs[k] < 0) down++;
   }
   if(up >= n - 1)        cp_lean = 1;
   else if(down >= n - 1) cp_lean = -1;
   else                   cp_lean = 0;

   cp_conv = MathMin(1.0, (double)steps / MathMax(1.0, (double)CandleProgressionFullSteps));

   // A progression among bodies that disagree is weaker - the sizes are changing but
   // the market has not settled on a direction to change them in.
   if(cp_lean == 0)
      cp_conv *= CandleProgressionMixedFactor;

   cp_detail = StringFormat("%d bodies %s in a row%s", steps,
                            (cp_prog == CSEQ_FADING ? "shrinking" : "growing"),
                            (cp_lean != 0 ? (cp_lean > 0 ? " (bullish)" : " (bearish)") : ""));

   progression = cp_prog; lean = cp_lean; detail = cp_detail;
   return MathMax(0.0, MathMin(1.0, cp_conv));
}


// ============================================================================
// V257: THE WICK THAT WENT AND FETCHED SOMETHING
// ----------------------------------------------------------------------------
// CandleWickAuthorship already reads wicks, and it asks a different question: which
// side of this candle got rejected, measured against its own body. That is a reading
// about the bar.
//
// This one is about the CHART. A long wick that reaches a prior swing extreme and
// comes straight back has done something specific - it has collected the stop orders
// sitting just beyond that extreme, which is the only reason price goes there and
// does not stay. Every trader who bought the previous high had a stop below it; the
// wick took them, and the people who did the taking are now positioned the other way.
//
// The distinction matters because the same 60% wick means nothing in open space and a
// great deal when its tip lands on last week's low. Authorship cannot tell them apart,
// because it never looks at where the wick ENDED - only at how big it was.
//
// Scoped to M1 through M15. On H1 and above a long wick spans hours of two-way trade
// and reaching a prior extreme is unremarkable - that lesson cost a week of blocked
// trading when the sweep reader was left unbounded.
// ============================================================================

// Did a recent wick reach a prior extreme and come back? Returns 0..1 - how clearly.
//   swept_dir - which side was collected: +1 highs taken (bearish), -1 lows (bullish)
double LiquidityWickSweep(int &swept_dir, double &level, string &detail)
{
   swept_dir = 0;
   level = 0.0;
   detail = "";

   if(!EnableLiquidityWick || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = LiquidityWickTF;

   // Small timeframes only. Above M15 a long wick is hours of ordinary trade and
   // touching a prior extreme says nothing - the sweep reader was left unbounded once
   // and blocked trading for a week.
   if(tf != PERIOD_M1 && tf != PERIOD_M5 && tf != PERIOD_M15)
      return 0.0;

   static int    lw_bar = -100000;
   static double lw_conv = 0.0;
   static int    lw_dir = 0;
   static double lw_level = 0.0;
   static string lw_detail = "";
   if(lw_bar > G_BARS_SEEN) lw_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(lw_bar == G_BARS_SEEN)
   {
      swept_dir = lw_dir; level = lw_level; detail = lw_detail;
      return lw_conv;
   }
   lw_bar = G_BARS_SEEN;
   lw_conv = 0.0; lw_dir = 0; lw_level = 0.0; lw_detail = "";

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   double tol = ScaleAdjustedPoints(MathMax(1, LiquidityWickTolerance)) * _Point;
   int look = MathMax(3, LiquidityWickLookback);

   for(int i = 1; i <= look; i++)
   {
      double o = CandleOpen(tf, i), c = CandleClose(tf, i);
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;

      double range = h - l;
      if(range <= 0.0)
         continue;

      double upper = (h - MathMax(o, c)) / range;
      double lower = (MathMin(o, c) - l) / range;

      // The wick has to be long enough to be deliberate rather than noise.
      bool up_ok   = (upper >= LiquidityWickMinRatio);
      bool down_ok = (lower >= LiquidityWickMinRatio);
      if(!up_ok && !down_ok)
         continue;

      // And the bar has to have covered ground. A long wick on a tiny bar reached
      // nothing worth reaching.
      if((range / _Point) / atr < LiquidityWickMinRangeATR)
         continue;

      // Now the part authorship never asks: did the tip REACH a prior extreme? Look
      // back past this bar for a swing high or low it ran into.
      for(int j = i + 1; j <= look + LiquidityWickSearchExtra; j++)
      {
         double ph = CandleHigh(tf, j), pl = CandleLow(tf, j);
         if(ph <= 0.0 || pl <= 0.0)
            continue;

         // Upper wick reaching a prior high - the stops of everyone who sold it, and
         // the buy orders of everyone waiting for a break, are sitting just above.
         if(up_ok && MathAbs(h - ph) <= tol && h >= ph)
         {
            // It only counts if price came back. A wick that reached and stayed is a
            // breakout, which is the opposite situation.
            if(c < ph)
            {
               double conv = upper * MathMin(1.0, ((range / _Point) / atr) /
                                                  MathMax(0.1, LiquidityWickFullRangeATR));
               if(conv > lw_conv)
               {
                  lw_conv = conv;
                  lw_dir = 1;              // highs taken - the move that follows tends down
                  lw_level = ph;
                  lw_detail = StringFormat("the %.2f high was taken and given back %d bars ago",
                                           ph, i);
               }
            }
         }

         if(down_ok && MathAbs(l - pl) <= tol && l <= pl)
         {
            if(c > pl)
            {
               double conv = lower * MathMin(1.0, ((range / _Point) / atr) /
                                                  MathMax(0.1, LiquidityWickFullRangeATR));
               if(conv > lw_conv)
               {
                  lw_conv = conv;
                  lw_dir = -1;             // lows taken - the move that follows tends up
                  lw_level = pl;
                  lw_detail = StringFormat("the %.2f low was taken and given back %d bars ago",
                                           pl, i);
               }
            }
         }
      }

      // Fade with age - the traders cleared out by it are being replaced.
      if(lw_conv > 0.0)
      {
         double fade = 1.0 - ((double)(i - 1) / MathMax(1.0, (double)look));
         lw_conv *= MathMax(0.25, fade);
         break;
      }
   }

   swept_dir = lw_dir; level = lw_level; detail = lw_detail;
   return MathMax(0.0, MathMin(1.0, lw_conv));
}


// ============================================================================
// V254: SETTINGS THAT ARE EACH VALID AND WRONG TOGETHER, AND A MARKET THAT CHANGED
// ----------------------------------------------------------------------------
// The existing input validation checks values one at a time - StartLot above zero,
// MaxOrders at least one, MagicNumber positive. Every one of those can pass while the
// combination is unworkable.
//
//   StartLot 0.25, seven rungs at 1.30x, on a small account: each value is fine and
//   the ladder cannot be paid for. The EA discovers this at rung four.
//
//   A target of 250 points with a spread of 260: the trade is closed at a loss the
//   moment it opens, and nothing in the settings looks wrong.
//
// The second reading is about the market rather than the settings. Every distance in
// the EA - grid spacing, target, stop - was sized for the volatility that existed when
// the values were chosen. When ATR doubles, all of them are simultaneously too small,
// and none of them knows it. The EA reads ATR constantly and has never asked whether
// today's ATR resembles the one its settings assume.
// ============================================================================

// Do the settings work TOGETHER? Returns an empty string when they do.
string ValidateSettingsCombination()
{
   if(!EnableSettingsValidation)
      return "";

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0 || _Point <= 0.0)
      return "";

   // --- can the full ladder be paid for? -------------------------------------
   if(UseGridRecovery && MaxOrders > 1 && LotMultiplier > 0.0)
   {
      double total_lots = 0.0;
      double lot = StartLot;
      for(int k = 0; k < MaxOrders; k++)
      {
         total_lots += lot;
         lot *= LotMultiplier;
      }

      double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick_val > 0.0 && tick_sz > 0.0)
      {
         double per_point = tick_val / (tick_sz / _Point);
         // The span the ladder covers, with the average rung about halfway down it.
         double span = (double)(MaxOrders - 1) * (double)GridDistancePoints * 0.5;
         double projected = total_lots * span * per_point;
         double budget = balance * (BasketSLPercent / 100.0);

         if(budget > 0.0 && projected > budget * SettingsLadderMaxShare)
            return StringFormat("the %d-rung ladder projects %.2f against a %.2f stop budget - "
                                "reduce StartLot, MaxOrders or LotMultiplier",
                                MaxOrders, projected, budget);
      }
   }

   // --- is the target bigger than the cost of entering? ----------------------
   // A target that does not clear the spread by a sensible margin is a trade that
   // starts behind and has to make the difference up before it makes anything.
   double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_pts > 0.0)
   {
      double tp = BaseBasketTPPoints();
      if(tp > 0.0 && tp < spread_pts * SettingsMinTPSpreadRatio)
         return StringFormat("the %.0f point target is only %.1fx the current %.0f point spread - "
                             "raise the target or trade a tighter symbol",
                             tp, tp / spread_pts, spread_pts);
   }

   return "";
}

// Has the market's volatility moved away from what the settings assume? Returns a
// ratio: 1.0 means today matches the recent baseline, 2.0 means twice as wide.
double VolatilityShift(string &detail)
{
   detail = "";
   if(!EnableVolatilityShift)
      return 1.0;

   static int    vs_bar = -100000;
   static double vs_ratio = 1.0;
   static string vs_detail = "";
   if(vs_bar > G_BARS_SEEN) vs_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(vs_bar == G_BARS_SEEN)
   {
      detail = vs_detail;
      return vs_ratio;
   }
   vs_bar = G_BARS_SEEN;
   vs_ratio = 1.0; vs_detail = "";

   ENUM_TIMEFRAMES tf = LocalStructureTF;

   // Today's reading against a longer baseline. Both come from the same series, so
   // the comparison is of the same thing at two scales rather than two estimates.
   double now = ATRPointsManual(tf, ATRPeriod, 1);
   double base = ATRPointsManual(tf, MathMax(ATRPeriod * 4, VolatilityBaselinePeriod), 1);

   if(now <= 0.0 || base <= 0.0)
   {
      detail = vs_detail;
      return 1.0;
   }

   vs_ratio = now / base;

   if(vs_ratio >= VolatilityShiftHigh)
      vs_detail = StringFormat("volatility %.1fx its baseline - every distance in the settings is now small",
                               vs_ratio);
   else if(vs_ratio <= VolatilityShiftLow)
      vs_detail = StringFormat("volatility %.1fx its baseline - targets that assume normal range may not be reached",
                               vs_ratio);

   detail = vs_detail;
   return vs_ratio;
}


// ============================================================================
// V253: THE CANDLE THAT TOOK BOTH SIDES
// ----------------------------------------------------------------------------
// A bar with long wicks above AND below a small body is read by the EA as a doji -
// indecision, no information, ignore it. That is the wrong reading, and it is the
// wrong reading in the most expensive way.
//
// Price went up far enough to take out the stops of everyone short, came back down far
// enough to take out the stops of everyone long, and closed near where it started.
// Nobody is undecided. Both sides have been cleared out, and whoever did the clearing
// now has the market to themselves - which is why the move that follows one of these
// tends to be the real one.
//
// Two things separate it from an ordinary doji:
//
//   BOTH wicks have to be long. One long wick is a rejection - price tried a direction
//   and failed. Two is a sweep of both sides, which is a different event entirely.
//
//   The bar has to be LARGE. A small doji in a quiet hour is genuine indecision; a
//   doji spanning two ATR is a range that got traded through in both directions inside
//   a single bar, and that takes size to produce.
//
// Which side gets cleared LAST matters too - the final wick before the close is the
// side the market was still working on, and the move usually goes the other way.
// ============================================================================

// Did this bar take out both sides? Returns 0..1 - how clearly.
//   likely_dir - the direction the move that follows tends to take
double ManipulationCandle(const int shift, int &likely_dir, string &detail)
{
   likely_dir = 0;
   detail = "";

   if(!EnableManipulationRead || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = ManipulationTF;

   // V256: this reading only means anything on the small timeframes. Stop-clearing happens inside a
   // minute or two - on M1 and M5 that is one bar and the shape is unmistakable. Above M15 the same
   // shape appears for an entirely different reason: several hours of ordinary two-way trade
   // compressed into one candle. An H1 bar with wicks on both sides is not a sweep, it is a session.
   //
   // Left unbounded this blocks by the hour and then by the day, and the EA stops trading for a week
   // on readings that were never about manipulation at all. That happened live.
   if(tf != PERIOD_M1 && tf != PERIOD_M5)
      return 0.0;

   double o = CandleOpen(tf, shift), c = CandleClose(tf, shift);
   double h = CandleHigh(tf, shift), l = CandleLow(tf, shift);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0.0;

   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   double body = MathAbs(c - o);
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;

   double body_share  = body / range;
   double upper_share = upper / range;
   double lower_share = lower / range;

   // A small body is the first condition - price finished roughly where it started.
   if(body_share > ManipulationMaxBody)
      return 0.0;

   // BOTH wicks long is what separates this from a rejection. One long wick means
   // price tried a direction and failed; two means both sides were cleared.
   if(upper_share < ManipulationMinWick || lower_share < ManipulationMinWick)
      return 0.0;

   // And it has to be large. A small doji in a quiet hour is ordinary indecision; one
   // spanning two ATR is a range traded through in both directions inside one bar,
   // and that takes size to produce.
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;
   double range_atr = (range / _Point) / atr;
   if(range_atr < ManipulationMinRangeATR)
      return 0.0;

   // Which side was worked last? The close sitting in the lower half means the final
   // push was downward - sellers were the ones being cleared, and the move that
   // follows usually goes up.
   double close_pos = (c - l) / range;
   if(close_pos > 0.5 + ManipulationBiasMargin)
      likely_dir = 1;           // closed high after sweeping the low - upward
   else if(close_pos < 0.5 - ManipulationBiasMargin)
      likely_dir = -1;
   else
      likely_dir = 0;           // genuinely balanced - the sweep is real, the direction is not yet

   double size_f = MathMin(1.0, range_atr / MathMax(0.1, ManipulationFullRangeATR));
   double wick_f = MathMin(1.0, (upper_share + lower_share) / MathMax(0.1, ManipulationFullWickTotal));
   double conviction = size_f * wick_f * (1.0 - body_share);

   detail = StringFormat("both sides swept in one %.1f ATR bar (wicks %.0f%%/%.0f%%)",
                         range_atr, upper_share * 100.0, lower_share * 100.0);

   return MathMax(0.0, MathMin(1.0, conviction));
}

// Was one of these recent enough to still matter? The clearing it did lasts a few
// bars - after that the market has refilled.
double RecentManipulation(int &likely_dir, string &detail)
{
   likely_dir = 0;
   detail = "";

   if(!EnableManipulationRead)
      return 0.0;

   // V271: cached per bar. This loops six bars and each iteration reads four prices, which is cheap
   // on its own and not cheap on every tick of a busy session. The reading cannot change within a
   // bar anyway - it examines closed candles only.
   static int    rm_bar = -100000;
   static double rm_val = 0.0;
   static int    rm_dir = 0;
   static string rm_detail = "";
   if(rm_bar > G_BARS_SEEN) rm_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(rm_bar == G_BARS_SEEN)
   {
      likely_dir = rm_dir; detail = rm_detail;
      return rm_val;
   }
   rm_bar = G_BARS_SEEN;
   rm_val = 0.0; rm_dir = 0; rm_detail = "";

   // V256: and stay quiet during a release. A news bar has wicks on both sides for a reason that has
   // nothing to do with stop-clearing, and NewsInProgress already accounts for it - reading the same
   // bar twice charges the entry twice for one event.
   if(EnableLiveNewsRead)
   {
      string nw_d = "";
      if(NewsInProgress(nw_d) >= LiveNewsMinSeverity)
         return 0.0;
   }

   double best = 0.0;
   int    best_dir = 0;
   string best_detail = "";
   int    best_shift = 0;

   for(int i = 1; i <= MathMax(1, ManipulationLookback); i++)
   {
      int d = 0;
      string dt = "";
      double conv = ManipulationCandle(i, d, dt);
      if(conv > best)
      {
         best = conv; best_dir = d; best_detail = dt; best_shift = i;
      }
   }

   if(best <= 0.0)
      return 0.0;

   // Fade with age - the traders cleared out by it are being replaced.
   double fade = 1.0 - ((double)(best_shift - 1) / MathMax(1.0, (double)ManipulationLookback));
   best *= MathMax(0.2, fade);

   rm_val = best;
   rm_dir = best_dir;
   rm_detail = StringFormat("%s, %d bars ago", best_detail, best_shift);

   likely_dir = rm_dir;
   detail = rm_detail;
   return rm_val;
}


// ============================================================================
// V252: THE LEVELS THAT DO NOT COME FROM SWINGS
// ----------------------------------------------------------------------------
// A support at 4305-4315 held on the 2nd and 3rd of September. On the 11th price came
// back to it and the EA did not see it. Nine days is a long time in a swing cache -
// hundreds of newer swings had formed and pushed it out.
//
// But some levels do not need remembering, because they can be calculated. Round
// numbers, the monthly high and low, last week's range - these are not derived from
// price history, they ARE prices, and they matter precisely because everyone can see
// them without looking anything up.
//
// This matters most exactly when the swing cache is least useful: after a large move
// into territory price has not traded in recently. There are no recent swings there
// by definition. What there is, is 4300, and the low of the month, and the level the
// week opened at.
//
// Cheap to compute and impossible to lose - which is the opposite of everything else
// in the zone system.
// ============================================================================

// The round-number level nearest to a price, in the given direction.
double RoundLevelNear(const double price, const int dir, double &strength)
{
   strength = 0.0;
   if(!EnableGlobalLevels || price <= 0.0 || dir == 0)
      return 0.0;

   // Hundreds are the strongest, then fifties, then twenty-fives. Gold respects all
   // three, in that order.
   double steps[3];
   double weights[3];
   steps[0] = GlobalRoundMajor;   weights[0] = GlobalRoundMajorStrength;
   steps[1] = GlobalRoundMid;     weights[1] = GlobalRoundMidStrength;
   steps[2] = GlobalRoundMinor;   weights[2] = GlobalRoundMinorStrength;

   double best = 0.0;
   double best_w = 0.0;

   for(int i = 0; i < 3; i++)
   {
      if(steps[i] <= 0.0)
         continue;

      double lvl = (dir > 0) ? (MathCeil(price / steps[i]) * steps[i])
                             : (MathFloor(price / steps[i]) * steps[i]);

      // A level exactly at price is not ahead of it.
      if(MathAbs(lvl - price) < steps[2] * 0.05)
         continue;

      // The nearest one wins unless a stronger level sits only slightly further.
      bool take = (best <= 0.0);
      if(!take)
      {
         double d_new = MathAbs(lvl - price);
         double d_old = MathAbs(best - price);
         take = (d_new < d_old) || (weights[i] > best_w * 1.2 && d_new < d_old * 1.5);
      }

      if(take) { best = lvl; best_w = weights[i]; }
   }

   strength = best_w;
   return best;
}

// The monthly and weekly extremes, and where the week opened. Computed once per bar -
// they only change when a new period starts.
void GlobalPeriodLevels(double &month_high, double &month_low,
                        double &week_high, double &week_low, double &week_open)
{
   month_high = 0.0; month_low = 0.0;
   week_high = 0.0;  week_low = 0.0;  week_open = 0.0;

   if(!EnableGlobalLevels)
      return;

   static int    gp_bar = -100000;
   static double gp_mh = 0.0, gp_ml = 0.0, gp_wh = 0.0, gp_wl = 0.0, gp_wo = 0.0;
   if(gp_bar > G_BARS_SEEN) gp_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(gp_bar == G_BARS_SEEN)
   {
      month_high = gp_mh; month_low = gp_ml;
      week_high = gp_wh;  week_low = gp_wl;  week_open = gp_wo;
      return;
   }
   gp_bar = G_BARS_SEEN;

   // Daily bars are enough for both - a month is about 22 of them and a week is 5.
   double mh = 0.0, ml = 0.0, wh = 0.0, wl = 0.0;
   for(int i = 1; i <= 22; i++)
   {
      double h = CandleHigh(PERIOD_D1, i);
      double l = CandleLow(PERIOD_D1, i);
      if(h <= 0.0 || l <= 0.0) continue;
      if(mh <= 0.0 || h > mh) mh = h;
      if(ml <= 0.0 || l < ml) ml = l;
      if(i <= 5)
      {
         if(wh <= 0.0 || h > wh) wh = h;
         if(wl <= 0.0 || l < wl) wl = l;
      }
   }

   gp_mh = mh; gp_ml = ml; gp_wh = wh; gp_wl = wl;
   gp_wo = CandleOpen(PERIOD_W1, 0);
   if(gp_wo <= 0.0) gp_wo = CandleOpen(PERIOD_D1, 4);

   month_high = mh; month_low = ml;
   week_high = wh;  week_low = wl;  week_open = gp_wo;
}

// Is there a global level in front of this entry? Returns its strength, 0 if none.
double GlobalLevelAhead(const int entry_dir, double &level, string &detail)
{
   level = 0.0;
   detail = "";

   if(!EnableGlobalLevels || entry_dir == 0 || _Point <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return 0.0;

   double reach = ScaleAdjustedPoints(MathMax(1, GlobalLevelReach));
   double best = 0.0, best_str = 0.0;
   string best_name = "";

   // Round numbers.
   double rs = 0.0;
   double rl = RoundLevelNear(mid, entry_dir, rs);
   if(rl > 0.0 && MathAbs(rl - mid) / _Point <= reach)
   {
      best = rl; best_str = rs;
      best_name = StringFormat("round %.0f", rl);
   }

   // Period extremes. Only the ones AHEAD of the trade count - a monthly low below a
   // long is support the trade already has behind it.
   double mh = 0.0, ml = 0.0, wh = 0.0, wl = 0.0, wo = 0.0;
   GlobalPeriodLevels(mh, ml, wh, wl, wo);

   double cands[5];
   double strs[5];
   string names[5];
   cands[0] = mh; strs[0] = GlobalMonthStrength; names[0] = "monthly high";
   cands[1] = ml; strs[1] = GlobalMonthStrength; names[1] = "monthly low";
   cands[2] = wh; strs[2] = GlobalWeekStrength;  names[2] = "weekly high";
   cands[3] = wl; strs[3] = GlobalWeekStrength;  names[3] = "weekly low";
   cands[4] = wo; strs[4] = GlobalWeekOpenStrength; names[4] = "weekly open";

   for(int i = 0; i < 5; i++)
   {
      if(cands[i] <= 0.0)
         continue;
      bool ahead = (entry_dir > 0) ? (cands[i] > mid) : (cands[i] < mid);
      if(!ahead)
         continue;
      if(MathAbs(cands[i] - mid) / _Point > reach)
         continue;

      if(best <= 0.0 || strs[i] > best_str)
      {
         best = cands[i]; best_str = strs[i];
         best_name = StringFormat("%s %.2f", names[i], cands[i]);
      }
   }

   if(best <= 0.0)
      return 0.0;

   level = best;
   detail = StringFormat("%s ahead (%.0f pts)", best_name, MathAbs(best - mid) / _Point);
   return best_str;
}


// ============================================================================
// V250: THE BIGGER PICTURE OVERRULES THE LOCAL ONE
// ----------------------------------------------------------------------------
// Three live buys, all the same mistake: 4670.41, 4672.48, 4670.48. Each time a
// double top had formed above, price had broken down through the structure, and then
// come back to retest the neckline. The EA saw a support and bought it.
//
// A support inside a completed bearish reversal is not a support. It is the neckline
// of the pattern that just broke, and price returning to it is the retest that
// precedes the next leg down - which is exactly what happened all three times.
//
// The reading the EA lacks is hierarchy. Structure, situation, timeframes and zones
// all contribute points to one total, so an M5 support and an H1 reversal arrive as
// numbers that simply add up. They should not add up. The larger picture decides what
// the smaller one MEANS, and when the two disagree the larger one is right far more
// often than the arithmetic allows for.
//
// One more thing from the third case: "H2 and H4 never broke - H1 was fooled". The
// break confirmation added in V232 looks one step up. It needs to look two, because a
// break can be real on H1 and invisible on H4, and the H4 reading is the one that
// decides whether the move continues.
//
// This adds weight; it does not veto. A local setup inside a hostile larger context
// can still be taken when everything else about it is strong - it just has to be much
// stronger than the same setup with the bigger picture behind it.
// ============================================================================


int    G_REVCTX_STATE = REVCTX_NONE;
double G_REVCTX_NECK  = 0.0;    // the level the pattern broke through
string G_REVCTX_TEXT  = "";

// Has a reversal pattern completed on the higher timeframes? Looks for the shape all
// three losing buys shared: two highs at similar levels, a low between them, and a
// close beyond that low.
int MajorReversalContext(double &neckline, double &confidence, string &detail)
{
   neckline = 0.0;
   confidence = 0.0;
   detail = "";

   if(!EnableReversalContext || _Point <= 0.0)
      return REVCTX_NONE;

   static int    rc_bar = -100000;
   static int    rc_state = REVCTX_NONE;
   static double rc_neck = 0.0;
   static double rc_conf = 0.0;
   static string rc_detail = "";
   if(rc_bar > G_BARS_SEEN) rc_bar = -100000;   // FIX(reinit-bar-rewind): OnInit restarts G_BARS_SEEN at 0 but statics keep their value

   if(rc_bar == G_BARS_SEEN)
   {
      neckline = rc_neck; confidence = rc_conf; detail = rc_detail;
      return rc_state;
   }
   rc_bar = G_BARS_SEEN;
   rc_state = REVCTX_NONE; rc_neck = 0.0; rc_conf = 0.0; rc_detail = "";

   ENUM_TIMEFRAMES tf = ReversalContextTF;
   int look = MathMax(30, ReversalContextLookback);
   int depth = 2;

   // Collect confirmed swing highs and lows.
   double sh[8], sl[8];
   int    sh_shift[8], sl_shift[8];
   int nh = 0, nl = 0;

   for(int i = depth + 1; i <= look && (nh < 8 || nl < 8); i++)
   {
      if(nh < 8)
      {
         double hv = CandleHigh(tf, i);
         bool ok = (hv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleHigh(tf, i - k) >= hv || CandleHigh(tf, i + k) >= hv) ok = false;
         if(ok) { sh[nh] = hv; sh_shift[nh] = i; nh++; }
      }
      if(nl < 8)
      {
         double lv = CandleLow(tf, i);
         bool ok = (lv > 0.0);
         for(int k = 1; k <= depth && ok; k++)
            if(CandleLow(tf, i - k) <= lv || CandleLow(tf, i + k) <= lv) ok = false;
         if(ok) { sl[nl] = lv; sl_shift[nl] = i; nl++; }
      }
   }

   if(nh < 2 || nl < 1)
      return REVCTX_NONE;

   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return REVCTX_NONE;

   double last_close = CandleClose(tf, 1);
   if(last_close <= 0.0)
      return REVCTX_NONE;

   // --- bearish: two comparable highs with a low between them, then a break below ---
   for(int a = 0; a + 1 < nh; a++)
   {
      double h1 = sh[a], h2 = sh[a + 1];
      // The two peaks have to be at a similar level - that is what makes it one
      // pattern rather than two unrelated highs.
      double diff_atr = MathAbs(h1 - h2) / _Point / atr;
      if(diff_atr > ReversalPeakTolerance)
         continue;

      // Find the low between them - the neckline.
      double neck = 0.0;
      for(int b = 0; b < nl; b++)
         if(sl_shift[b] > sh_shift[a] && sl_shift[b] < sh_shift[a + 1])
            if(neck <= 0.0 || sl[b] < neck) neck = sl[b];

      if(neck <= 0.0)
         continue;

      // The pattern needs real height, or any two highs with a dip between them
      // qualify.
      double height_atr = ((h1 + h2) / 2.0 - neck) / _Point / atr;
      if(height_atr < ReversalMinHeightATR)
         continue;

      // And it only counts once price has closed through the neckline. Before that it
      // is a shape; after, it is an event.
      if(last_close >= neck)
         continue;

      rc_state = REVCTX_BEARISH;
      rc_neck = neck;
      rc_conf = MathMin(1.0, height_atr / MathMax(0.1, ReversalFullHeightATR));
      rc_detail = StringFormat("double top %.2f/%.2f broke %.2f on %s",
                               h1, h2, neck, EnumToString(tf));
      break;
   }

   // --- bullish: mirror ---
   if(rc_state == REVCTX_NONE && nl >= 2 && nh >= 1)
   {
      for(int a = 0; a + 1 < nl; a++)
      {
         double l1 = sl[a], l2 = sl[a + 1];
         double diff_atr = MathAbs(l1 - l2) / _Point / atr;
         if(diff_atr > ReversalPeakTolerance)
            continue;

         double neck = 0.0;
         for(int b = 0; b < nh; b++)
            if(sh_shift[b] > sl_shift[a] && sh_shift[b] < sl_shift[a + 1])
               if(neck <= 0.0 || sh[b] > neck) neck = sh[b];

         if(neck <= 0.0)
            continue;

         double height_atr = (neck - (l1 + l2) / 2.0) / _Point / atr;
         if(height_atr < ReversalMinHeightATR)
            continue;

         if(last_close <= neck)
            continue;

         rc_state = REVCTX_BULLISH;
         rc_neck = neck;
         rc_conf = MathMin(1.0, height_atr / MathMax(0.1, ReversalFullHeightATR));
         rc_detail = StringFormat("double bottom %.2f/%.2f broke %.2f on %s",
                                  l1, l2, neck, EnumToString(tf));
         break;
      }
   }

   G_REVCTX_STATE = rc_state;
   G_REVCTX_NECK  = rc_neck;
   G_REVCTX_TEXT  = rc_detail;

   neckline = rc_neck; confidence = rc_conf; detail = rc_detail;

   if(rc_state != REVCTX_NONE && (ReversalContextPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v250 REVERSAL] %s (%.0f%% confidence)", rc_detail, rc_conf * 100.0);

   return rc_state;
}

// Is this entry a retest of the broken neckline? That is the specific trade all three
// losses were - buying the level the pattern broke through, which is where the next
// leg starts rather than where price turns.
bool IsNecklineRetest(const int entry_dir, double &severity, string &detail)
{
   severity = 0.0;
   detail = "";

   double neck = 0.0, conf = 0.0;
   string rc_detail = "";
   int ctx = MajorReversalContext(neck, conf, rc_detail);

   if(ctx == REVCTX_NONE || neck <= 0.0 || _Point <= 0.0)
      return false;

   // Only a problem when the trade runs against the reversal.
   int ctx_dir = (ctx == REVCTX_BEARISH) ? -1 : 1;
   if(entry_dir == ctx_dir)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return false;

   // How close is price to the broken neckline? At it, this is the textbook retest.
   double gap = MathAbs(mid - neck) / _Point;
   double reach = ScaleAdjustedPoints(MathMax(1, NecklineRetestReach));

   if(gap > reach)
   {
      // Not at the neckline, but still inside a hostile context - worth something,
      // just less.
      severity = conf * ReversalContextBaseWeight;
      detail = StringFormat("against a %s context (%s)",
                            (ctx == REVCTX_BEARISH ? "bearish" : "bullish"), rc_detail);
      return (severity > 0.0);
   }

   double closeness = 1.0 - (gap / MathMax(1.0, reach));
   severity = conf * (ReversalContextBaseWeight + (1.0 - ReversalContextBaseWeight) * closeness);
   detail = StringFormat("retesting the broken neckline %.2f - %s", neck, rc_detail);
   return true;
}

// V250: does the break survive being looked at from TWO steps up? From the third loss:
// "H2 and H4 never broke - H1 was fooled". A break can be real on one timeframe and
// invisible on the one above it, and the larger reading is what decides whether the
// move continues.
bool BreakConfirmedTwoLevels(const double level, const int dir, string &detail)
{
   detail = "";
   if(!EnableDeepBreakConfirm || level <= 0.0 || dir == 0)
      return true;

   double c1 = CandleClose(DeepConfirmTF1, 1);
   double c2 = CandleClose(DeepConfirmTF2, 1);

   if(c1 > 0.0)
   {
      bool beyond1 = (dir > 0) ? (c1 > level) : (c1 < level);
      if(!beyond1)
      {
         detail = StringFormat("%s has not closed through %.2f",
                               EnumToString(DeepConfirmTF1), level);
         return false;
      }
   }

   if(c2 > 0.0)
   {
      bool beyond2 = (dir > 0) ? (c2 > level) : (c2 < level);
      if(!beyond2)
      {
         detail = StringFormat("%s has not closed through %.2f - the smaller timeframes are ahead of it",
                               EnumToString(DeepConfirmTF2), level);
         return false;
      }
   }

   return true;
}


// ============================================================================
// V249: HOW MUCH OF THE EA AGREES, AND WHAT ITS DISAGREEMENTS MEAN
// ----------------------------------------------------------------------------
// Two readings the score cannot express, both about the same weakness: a total hides
// the shape of what produced it.
//
// CONSENSUS. A score of 13 built from eleven modules each contributing one or two
// points is a different thing from a 13 built by two modules shouting while the rest
// say nothing. The first is broad agreement; the second is a narrow opinion that
// happened to be loud. They arrive at the EA as the same number and are acted on
// identically.
//
// CONTRADICTION BETWEEN LAYERS. V215 reads disagreement among the candle modules and
// names it. Nothing does that one level up, where structure, situation, zones and
// candles can point in opposite directions. Structure says +6 up, situation says -8
// down, the total is -2, and the EA takes a weak short. But -2 out of fourteen points
// of conflicting evidence does not mean "slightly bearish" - it means the layers are
// looking at the same chart and reaching opposite conclusions, and the honest response
// to that is to do nothing.
// ============================================================================

// How many separate modules contributed to this score, and how concentrated was it?
//   contributors - how many spoke at all
//   returns 0..1 - how broadly the score is supported
double ScoreConsensus(const string score_detail, int &contributors, string &detail)
{
   contributors = 0;
   detail = "";

   if(!EnableScoreConsensus)
      return 1.0;

   // The score detail string is built by each module appending its own contribution,
   // so counting those markers is the most direct measure of how many spoke - and it
   // needs no separate bookkeeping that could fall out of step with the scoring.
   int plus = 0, minus = 0;
   int len = StringLen(score_detail);
   for(int i = 0; i < len - 1; i++)
   {
      ushort ch = StringGetCharacter(score_detail, i);
      ushort nx = StringGetCharacter(score_detail, i + 1);
      // Contributions are written as " +N " or " -N " - a sign followed by a digit.
      if((ch == '+' || ch == '-') && nx >= '0' && nx <= '9')
      {
         if(ch == '+') plus++; else minus++;
      }
   }

   contributors = plus + minus;
   if(contributors <= 0)
      return 1.0;

   double breadth = MathMin(1.0, (double)contributors / MathMax(1.0, (double)ConsensusFullContributors));

   detail = StringFormat("%d modules spoke (%d for, %d against)", contributors, plus, minus);
   return breadth;
}

// Do the analysis layers contradict each other? Returns 0..1 - how badly.
double LayerContradiction(const int entry_dir, string &detail)
{
   detail = "";
   if(!EnableLayerConflict || entry_dir == 0)
      return 0.0;

   // Each layer's verdict on this direction: +1 supports, -1 opposes, 0 silent.
   int votes_for = 0, votes_against = 0;
   string parts = "";

   // Structure - the measured swing shape.
   if(EnableLocalStructure)
   {
      LocalStructureUpdate();
      if(G_LS_DIR != 0 && G_LS_STATE != LSTRUCT_CHOPPY)
      {
         if(G_LS_DIR == entry_dir) { votes_for++; parts += "structure+ "; }
         else                      { votes_against++; parts += "structure- "; }
      }
   }

   // Situation - zone, candle and structure read as one.
   if(EnableSituationRead && G_SITUATION != SIT_NONE && G_SITUATION_DIR != 0)
   {
      if(G_SITUATION_DIR == entry_dir) { votes_for++; parts += "situation+ "; }
      else                             { votes_against++; parts += "situation- "; }
   }

   // Timeframe alignment.
   if(EnableStructureMTF)
   {
      int    al_dir = 0;
      double al_w = 0.0;
      string al_d = "";
      int al = StructureAlignment(al_dir, al_w, al_d);
      if(al == TFALIGN_FULL && al_dir != 0)
      {
         if(al_dir == entry_dir) { votes_for++; parts += "timeframes+ "; }
         else                    { votes_against++; parts += "timeframes- "; }
      }
   }

   // The candle layer's net verdict.
   if(G_CANDLE_BONUS > 0 || G_CANDLE_PENALTY > 0)
   {
      if(G_CANDLE_BONUS > G_CANDLE_PENALTY)      { votes_for++; parts += "candles+ "; }
      else if(G_CANDLE_PENALTY > G_CANDLE_BONUS) { votes_against++; parts += "candles- "; }
   }

   int total = votes_for + votes_against;
   if(total < MathMax(2, ConflictMinLayers))
      return 0.0;

   // A split is worst when the layers are evenly divided - three against three is not
   // a weak signal, it is no signal. One dissenter among four is ordinary.
   double split = 1.0 - MathAbs((double)(votes_for - votes_against)) / (double)total;

   if(split < ConflictMinSplit)
      return 0.0;

   detail = StringFormat("layers split %d/%d (%s)", votes_for, votes_against, parts);
   return MathMax(0.0, MathMin(1.0, split));
}


// ============================================================================
// V248: THREE THINGS CHECKED TOO LATE, OR NOT AT ALL
// ----------------------------------------------------------------------------
// AFFORDABILITY, CHECKED AT THE WRONG TIME. GridEffectiveMaxOrders works out whether
// the account can pay for the remaining rungs - and it runs from inside GridCanOpen,
// which means it first executes at rung two. By then the basket exists. If the full
// ladder was never affordable, the EA discovers it halfway up and stops in the worst
// possible place: too deep to close cheaply, too shallow to recover. The question
// belongs at the FIRST entry, where the answer is still "do not open this".
//
// A MARKET WITH NOTHING IN IT. MARKET_DEAD is classified and then used for very
// little. A dead market is specifically dangerous for a grid: the range is too tight
// for the target, so the ladder fills quickly, and then the move that eventually
// comes finds a full basket waiting for it.
//
// NEWS, READ FROM THE MARKET RATHER THAN THE CALENDAR. The EA knows when releases are
// scheduled. It does not notice a release HAPPENING - volume several times normal,
// the spread widening, range expanding - which is what actually matters, and which
// arrives whether or not the event was on any calendar.
// ============================================================================

// Can the account pay for the whole ladder, before any of it is opened?
// V282: how many rungs the budget actually covers. Same arithmetic as LadderIsAffordable, walked
// one rung at a time until the projection passes the budget - the answer is the last depth that
// fitted. Used to cap the basket rather than refuse the entry.
// V285: the lot the balance can actually carry, rather than the lot the settings happen to name.
//
// StartLot is a fixed number and a balance is not. The same 0.25 that is conservative on a large
// account is the whole account on a small one, and the affordability check was comparing a fixed lot
// against a moving budget and refusing whenever the two did not line up. That is the wrong question.
// The right one is: at this balance, what lot does the full ladder fit in?
//
// So this solves for it. The ladder shape stays intact - all its rungs, its spacing, its multiplier
// - and the base lot shrinks until the projection fits the stop budget. A $100 account trades the
// same structure as a $10,000 one, in the size that structure costs at $100.
//
// Returns 0 when even the broker minimum will not fit, which is the one case where refusing is
// right: the account is too small for this symbol at this grid spacing, and no lot fixes that.
double AffordableStartLot(const int dir)
{
   if(!EnableEntryAffordability || dir == 0 || _Point <= 0.0)
      return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return 0.0;

   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_val <= 0.0 || tick_sz <= 0.0)
      return 0.0;
   double per_point = tick_val / (tick_sz / _Point);
   if(per_point <= 0.0)
      return 0.0;

   double budget = balance * (BasketSLPercent / 100.0) * EntryAffordabilityShare;
   if(budget <= 0.0)
      return 0.0;

   int n = MathMax(1, MathMin(16, MaxOrders));

   double base_step = MathMax(1.0, AutoGridBaseDistance());
   double g_mult = AutoGridMultiplier();
   double g_min  = AutoGridMinDistance();
   double g_max  = AutoGridMaxDistance();

   // Depth of each rung, and the total the ladder spans.
   double depth[16];
   double d_run = 0.0;
   for(int k = 0; k < n; k++)
   {
      depth[k] = d_run;
      double gap = base_step * ((g_mult > 0.0 && k >= 1) ? MathPow(g_mult, (double)k) : 1.0);
      if(g_min > 0.0) gap = MathMax(gap, g_min);
      if(g_max > 0.0) gap = MathMin(gap, g_max);
      d_run += gap;
   }
   double full_depth = depth[n - 1];

   // Cost of the whole ladder at one lot. Every rung's size is a multiple of the base, so the
   // projection is linear in it - which means the answer can be solved for directly rather than
   // searched.
   double pts_per_lot = 0.0;
   double mult = 1.0;
   for(int k = 0; k < n; k++)
   {
      pts_per_lot += mult * (full_depth - depth[k]);
      mult *= LotMultiplier;
   }

   if(pts_per_lot <= 0.0)
      return StartLot;              // single rung - nothing to project

   double lot = budget / (pts_per_lot * per_point);

   // Never larger than the configured size. This sizes DOWN for small accounts; it does not
   // silently trade bigger than asked on large ones.
   if(lot > StartLot)
      lot = StartLot;
   if(MaxLot > 0.0 && lot > MaxLot)
      lot = MaxLot;

   // Round to the broker's step, downward - rounding up would put the projection back over budget.
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(step > 0.0)
      lot = MathFloor(lot / step) * step;

   if(vmin > 0.0 && lot < vmin)
      return 0.0;                   // the smallest tradeable size still does not fit

   return lot;
}

int AffordableRungCount(const int dir)
{
   if(!EnableEntryAffordability || dir == 0 || _Point <= 0.0)
      return 0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return 0;

   double base_lot = StartLot;
   if(UseAutoLot)
   {
      double al = AutoLotBase();
      if(al > 0.0) base_lot = al;
   }
   if(MaxLot > 0.0 && base_lot > MaxLot)
      base_lot = MaxLot;

   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_val <= 0.0 || tick_sz <= 0.0)
      return 0;
   double per_point = tick_val / (tick_sz / _Point);

   double base_step = MathMax(1.0, AutoGridBaseDistance());
   double g_mult = AutoGridMultiplier();
   double g_min  = AutoGridMinDistance();
   double g_max  = AutoGridMaxDistance();

   // V284: a cent account reports its balance in cents, so the same $100 of real money reads as
   // 10000 here - and the check compares that against a projection computed from tick values in the
   // same units, so the two agree. What does not agree is a small DOLLAR account: $100 with a
   // fifty percent stop leaves a $50 budget, and one rung of the smallest tradeable lot can exceed
   // it. The EA then refuses every entry and looks broken when it is only poor.
   //
   // The floor below is not a way of ignoring the budget - it is an acknowledgement that a single
   // minimum-lot position is the smallest trade that exists. If that will not fit, no setting will
   // make it fit, and the honest answer is one rung rather than none.
   double budget = balance * (BasketSLPercent / 100.0) * EntryAffordabilityShare;
   if(budget <= 0.0)
      return 0;

   int cap = MathMin(MathMax(1, MaxOrders), 16);
   int best = 0;

   for(int n = 1; n <= cap; n++)
   {
      // Depth of each rung for a ladder of exactly n rungs.
      double depth[16];
      double d_run = 0.0;
      for(int k = 0; k < n; k++)
      {
         depth[k] = d_run;
         double gap = base_step * ((g_mult > 0.0 && k >= 1) ? MathPow(g_mult, (double)k) : 1.0);
         if(g_min > 0.0) gap = MathMax(gap, g_min);
         if(g_max > 0.0) gap = MathMin(gap, g_max);
         d_run += gap;
      }
      double full_depth = depth[n - 1];

      double pts = 0.0;
      double lot = base_lot;
      for(int k = 0; k < n; k++)
      {
         pts += lot * (full_depth - depth[k]);
         lot *= LotMultiplier;
      }

      if(pts * per_point <= budget)
         best = n;
      else
         break;
   }

   // V284: one rung always fits, by definition - a single position has no adverse excursion
   // between rungs to project, so its contribution to this arithmetic is zero. Returning zero here
   // would refuse a trade the account can obviously carry, which is what happens on small
   // balances where even two rungs exceed the budget.
   if(best <= 0)
      best = 1;

   return best;
}

bool LadderIsAffordable(const int dir, string &reason)
{
   reason = "";
   if(!EnableEntryAffordability || dir == 0 || _Point <= 0.0)
      return true;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0 || equity <= 0.0)
      return true;

   // FIX(affordability-stale-shape): this used LadderOrders()/LadderMultiplier(), which read
   // G_LADDER_ORDERS / G_LADDER_MULT - but ChooseLadderShape() only runs AFTER the first rung is
   // placed. So this gate was judging the shape of the PREVIOUS basket, not the one it is about to
   // authorise. Both directions were wrong, and one is dangerous: after a 3-rung "short" basket the
   // check would clear a new entry against 3 rungs, while the shaping engine could then pick a
   // 7-9 rung "long" ladder the account cannot fund - the exact mid-ladder trap this check exists
   // to prevent. Since the shape genuinely is not decided yet, every shape the engine could pick is
   // now evaluated and the WORST one has to fit.
   int    cand_rungs[4];
   double cand_mult[4];
   double cand_space[4];
   int    cand_n = 0;

   cand_rungs[cand_n] = MaxOrders;
   cand_mult[cand_n]  = LotMultiplier;
   cand_space[cand_n] = 1.0;
   cand_n++;

   if(EnableLadderShaping)
   {
      cand_rungs[cand_n] = MathMin(MaxOrders + LadderLongExtraOrders, LadderMaxOrdersCap);
      cand_mult[cand_n]  = MathMax(1.05, LotMultiplier - LadderLongMultReduction);
      cand_space[cand_n] = LadderLongSpacing;
      cand_n++;

      cand_rungs[cand_n] = MathMax(2, LadderShortOrders);
      cand_mult[cand_n]  = LotMultiplier;
      cand_space[cand_n] = LadderShortSpacing;
      cand_n++;

      cand_rungs[cand_n] = MathMax(2, MaxOrders - LadderCautiousFewerOrders);
      cand_mult[cand_n]  = MathMax(1.05, LotMultiplier - LadderCautiousMultReduction);
      cand_space[cand_n] = 1.0;
      cand_n++;
   }

   // FIX(affordability-basis): the projection used the raw StartLot input even when UseAutoLot
   // sizes the real first entry from balance - so with AutoLot on it judged a ladder the EA was
   // never going to open. Same class as the scale-in remainder fix. AutoLotBase() is a pure
   // calculation (no side effects), so it is safe to call from this check.
   double base_lot = StartLot;
   if(UseAutoLot)
   {
      double al = AutoLotBase();
      if(al > 0.0)
         base_lot = al;
   }
   if(MaxLot > 0.0 && base_lot > MaxLot)
      base_lot = MaxLot;

   // V285: and the size the balance actually carries, which is what will be traded. Projecting the
   // configured lot while the engine opens a smaller one meant this check refused ladders that were
   // never going to be that large.
   if(EnableBalanceSizedLot)
   {
      double fitted = AffordableStartLot(dir);
      if(fitted > 0.0 && fitted < base_lot)
         base_lot = fitted;
   }

   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_val <= 0.0 || tick_sz <= 0.0)
      return true;
   double per_point = tick_val / (tick_sz / _Point);

   // FIX(affordability-math): the old estimate was `total_lots * (span * 0.5)` - the WHOLE ladder's
   // volume multiplied by the AVERAGE adverse excursion. That shortcut is only valid when every
   // rung carries the same lot. In a martingale it is not: the SMALLEST lot (the first entry) sits
   // at the far end and travels the FULL span, while the LARGEST lots open last, near the bottom,
   // and travel almost nothing. Multiplying the big lots by the average distance charged them for
   // a move they never make, overstating the projected loss by ~50% at the default 1.30 multiplier
   // (volume-weighted average excursion is ~13k points, not the 19.5k the old line assumed) - so
   // the gate refused ladders the account could genuinely carry.
   // Now summed rung by rung: rung k opens at k steps down and is under water by the REMAINING
   // (rungs-1-k) steps once the ladder is complete.
   double base_step = MathMax(1.0, AutoGridBaseDistance());

   double projected  = 0.0;   // worst shape's projected loss
   double total_lots = 0.0;   // and the largest volume any shape would hold (for the margin test)
   int    worst_rungs = 0;

   // FIX(affordability-geometric-step): a first version of this used a UNIFORM gap,
   // `(rungs-1-k) * step`. The real ladder does not step uniformly - GridDistanceForNextOrder()
   // widens each successive gap by AutoGridMultiplier() (HunterGridDistanceMultiplier 1.20 /
   // BalancedGridDistanceMultiplier 1.20) and only then applies the min/max clamp, with the ladder
   // spacing factor on top. At 5 rungs from a 6500 base that is 6500+7800+9360+11232 = 34892 points
   // of real depth against 26000 assumed - so the uniform model UNDER-stated the worst case by
   // ~35-39%, in the dangerous direction: it would have cleared a ladder whose true excursion
   // exceeds the stop budget, which is the exact mid-ladder trap this gate exists to prevent.
   // Cumulative depth is now walked rung by rung with the same widening and clamps the live grid
   // uses. The live path also applies ATR/session/Pack/intelligence adjustments that cannot be
   // known before the basket exists; the geometric core plus the clamps is the structural term and
   // is what a pre-trade projection can honestly model.
   for(int c = 0; c < cand_n; c++)
   {
      int    c_rungs = cand_rungs[c];
      double c_mult  = cand_mult[c];
      if(c_rungs <= 1)
         continue;

      int n = MathMin(c_rungs, 16);          // LadderMaxOrdersCap is 9; 16 is headroom
      double depth[16];                       // cumulative depth of each rung, in points
      double d_run  = 0.0;
      double g_mult = AutoGridMultiplier();
      double g_min  = AutoGridMinDistance();
      double g_max  = AutoGridMaxDistance();
      for(int k = 0; k < n; k++)
      {
         depth[k] = d_run;
         double gap = base_step * ((g_mult > 0.0 && k >= 1) ? MathPow(g_mult, (double)k) : 1.0);
         if(g_min > 0.0) gap = MathMax(gap, g_min);
         if(g_max > 0.0) gap = MathMin(gap, g_max);
         gap *= MathMax(0.05, cand_space[c]);   // spacing applies after the clamp, as the live path does
         d_run += gap;
      }
      double full_depth = depth[n - 1];

      double c_total = 0.0;
      double c_pts   = 0.0;      // sum of (lot x its own adverse excursion)
      double lot = base_lot;
      for(int k = 0; k < n; k++)
      {
         c_total += lot;
         c_pts   += lot * (full_depth - depth[k]);
         lot *= c_mult;
      }

      double c_proj = c_pts * per_point;
      if(c_proj > projected)
      {
         projected   = c_proj;
         worst_rungs = c_rungs;
      }
      if(c_total > total_lots)
         total_lots = c_total;
   }

   if(worst_rungs <= 1 || total_lots <= 0.0)
      return true;

   int rungs = worst_rungs;   // reported in the refusal message below
   double budget = balance * (BasketSLPercent / 100.0);

   if(budget > 0.0 && projected > budget * EntryAffordabilityShare)
   {
      // V281: name the lot the projection was built from. StartLot is the obvious thing to reach for
      // when this refusal appears, and it is the wrong lever whenever UseAutoLot is on - the size
      // then comes from the balance and StartLot is not read at all. Without this line the refusal
      // looks identical either way, and lowering StartLot from 0.25 to 0.03 changes nothing while
      // appearing to be the fix.
      reason = StringFormat("the full %d-rung ladder from %.2f lots (%s) projects %.2f against a %.2f budget",
                            rungs, base_lot,
                            (UseAutoLot ? "auto" : "StartLot"),
                            projected, budget * EntryAffordabilityShare);
      return false;
   }

   // And the margin it would need. Running out of margin mid-ladder is worse than
   // running out of budget, because the broker decides what closes and when.
   double margin_needed = 0.0;
   if(!OrderCalcMargin((dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), _Symbol, total_lots,
                       SymbolInfoDouble(_Symbol, (dir > 0 ? SYMBOL_ASK : SYMBOL_BID)),
                       margin_needed))
      return true;

   if(margin_needed > 0.0 && equity > 0.0)
   {
      double margin_pct = (margin_needed / equity) * 100.0;
      if(margin_pct > EntryAffordabilityMaxMargin)
      {
         reason = StringFormat("the full ladder needs %.0f%% of equity as margin (limit %.0f%%)",
                               margin_pct, EntryAffordabilityMaxMargin);
         return false;
      }
   }

   return true;
}

// Is there simply nothing happening? Returns 0..1 - how dead the market looks.
double MarketIsDead(string &detail)
{
   detail = "";
   if(!EnableDeadMarketCheck || _Point <= 0.0)
      return 0.0;

   ENUM_TIMEFRAMES tf = LocalStructureTF;
   int look = MathMax(6, DeadMarketLookback);

   // Range covered over the window, against what one bar normally covers. A market
   // that has gone nowhere in twenty bars is not going to reach a target that needs
   // several bars of movement.
   double hi = 0.0, lo = 0.0;
   for(int i = 1; i <= look; i++)
   {
      double h = CandleHigh(tf, i), l = CandleLow(tf, i);
      if(h <= 0.0 || l <= 0.0) continue;
      if(hi <= 0.0 || h > hi) hi = h;
      if(lo <= 0.0 || l < lo) lo = l;
   }
   if(hi <= lo)
      return 0.0;

   double span_pts = (hi - lo) / _Point;
   double atr = ATRPointsManual(tf, ATRPeriod, 1);
   if(atr <= 0.0)
      return 0.0;

   // How many ATR of ground in the whole window? Twenty bars covering two ATR is a
   // market standing still.
   double span_atr = span_pts / atr;
   double expected = (double)look * DeadMarketExpectedATRPerBar;
   if(expected <= 0.0)
      return 0.0;

   double ratio = span_atr / expected;
   if(ratio >= DeadMarketRatio)
      return 0.0;

   double deadness = 1.0 - (ratio / MathMax(0.01, DeadMarketRatio));

   // The target has to fit inside what the market is actually producing.
   double tp = BaseBasketTPPoints();
   detail = StringFormat("%.0f pts of range in %d bars (%.1f ATR) against a %.0f pt target",
                         span_pts, look, span_atr, tp);
   return MathMax(0.0, MathMin(1.0, deadness));
}

// Is a release happening right now? Read from the market, not the calendar.
double NewsInProgress(string &detail)
{
   detail = "";
   if(!EnableLiveNewsRead)
      return 0.0;

   double score = 0.0;
   string parts = "";

   // Volume several times normal is the clearest sign - participants arriving at once.
   if(EnableCandleParticipation)
   {
      double part = CandleParticipation(1);
      if(part >= LiveNewsVolumeMultiple)
      {
         score += LiveNewsVolumeWeight;
         parts += StringFormat("%.1fx volume; ", part);
      }
   }

   // The spread widening is the broker's own reading of the same thing.
   // Against the normal spread for this symbol, which is the setting the risk engine
   // already uses as its baseline.
   if(G_LAST_SPREAD_POINTS > 0 && RiskMaxSpreadPoints > 0)
   {
      double sp_ratio = (double)G_LAST_SPREAD_POINTS / ((double)RiskMaxSpreadPoints * 0.5);
      if(sp_ratio >= LiveNewsSpreadMultiple)
      {
         score += LiveNewsSpreadWeight;
         parts += StringFormat("%.1fx spread; ", sp_ratio);
      }
   }

   // And range expanding well past normal.
   {
      ENUM_TIMEFRAMES tf = LocalStructureTF;
      double h = CandleHigh(tf, 1), l = CandleLow(tf, 1);
      double atr = ATRPointsManual(tf, ATRPeriod, 1);
      if(h > l && atr > 0.0)
      {
         double bar_atr = ((h - l) / _Point) / atr;
         if(bar_atr >= LiveNewsRangeMultiple)
         {
            score += LiveNewsRangeWeight;
            parts += StringFormat("%.1f ATR bar; ", bar_atr);
         }
      }
   }

   if(score <= 0.0)
      return 0.0;

   detail = "market reacting to something: " + parts;
   return MathMax(0.0, MathMin(1.0, score));
}


// ============================================================================
// V247: THE PRICE AT WHICH THE BASKET IS SIMPLY WRONG
// ----------------------------------------------------------------------------
// The EA has three ways to close a losing basket: the stop at 50%, an emergency
// drawdown trigger, and an equity stop. All three answer the same question - has the
// money run out - and none answers the one a trader asks first: is the reason I took
// this trade still true?
//
// From a live loss: two sells at 4470 and 4484 while price climbed to 4523. The
// second sell was placed ABOVE the first, into a rise, and then the basket sat there
// while drawdown accumulated toward a percentage threshold. Somewhere in that climb
// the case for being short stopped existing - and nothing in the EA was watching for
// that, because nothing had recorded what the case WAS.
//
// So the basket now stores its invalidation when it opens: the price above which
// (for a short) the reason no longer holds. That is usually the structure's high, the
// band it was selling into, or the sweep it was fading. When price closes through it,
// the premise is gone - not the money, the premise.
//
// What happens then is deliberately conservative. The basket is NOT closed - closing
// into a move that has just gone against it realises the loss at its worst point, and
// that has been the wrong answer every time it was tried. What stops is the ladder:
// no more rungs, no more size committed to a thesis that has already failed. The
// existing orders work out on their own terms.
// ============================================================================

double G_BASKET_INVALIDATION = 0.0;   // price above/below which the basket's reason is gone
string G_BASKET_THESIS       = "";    // what the basket was opened on, for the record
bool   G_BASKET_PREMISE_DEAD = false;

// Records what this basket is betting on, and the price that would disprove it.
void SetBasketThesis(const int dir)
{
   G_BASKET_INVALIDATION = 0.0;
   G_BASKET_THESIS = "";
   G_BASKET_PREMISE_DEAD = false;

   if(!EnableBasketThesis || dir == 0 || _Point <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : bid;
   if(mid <= 0.0)
      return;

   double invalid = 0.0;
   string why = "";

   // The strongest available invalidation, in order of how specific it is.

   // 1. The structure's own end price. A short taken inside a falling structure is
   //    wrong the moment that structure stops falling - which is a definition, not a
   //    threshold.
   if(EnableLocalStructure)
   {
      LocalStructureUpdate();
      if(G_LS_DIR == dir && G_LS_INVALIDATE > 0.0)
      {
         invalid = G_LS_INVALIDATE;
         why = StringFormat("structure ends at %.2f", invalid);
      }
   }

   // 2. The band being sold into or bought from. Above the top of a band a short was
   //    fading, the band did not hold and the trade's reason went with it.
   if(invalid <= 0.0)
   {
      double lo = 0.0, hi = 0.0;
      string bd = "";
      if(ZonePriceInsideBand(lo, hi, bd) && hi > lo)
      {
         invalid = (dir > 0) ? lo : hi;
         why = StringFormat("band edge %.2f", invalid);
      }
   }

   // 3. The nearest level in the direction the trade would be wrong. Weakest of the
   //    three because a level is a point rather than a case, but better than nothing.
   if(invalid <= 0.0)
   {
      double lvl = (dir > 0) ? ZoneMapNearestSupport(mid) : ZoneMapNearestResistance(mid);
      // FIX(thesis-wrong-side): the invalidation must sit on the side this trade would be WRONG
      // on - below price for a long, above it for a short. ZoneMapNearestSupport() can legitimately
      // return a level slightly ABOVE price (the V243 ZoneNearAboveTolerance case), and the
      // MathAbs() distance check below would hide that inversion: a "long invalidated above price"
      // is already breached, so BasketPremiseDead() would latch G_BASKET_PREMISE_DEAD on the very
      // next bar close and permanently stop the recovery ladder for that basket. Require the
      // correct side explicitly rather than relying on the level always being below/above.
      bool lvl_on_wrong_side = (dir > 0) ? (lvl < mid) : (lvl > mid);
      if(lvl > 0.0 && lvl_on_wrong_side)
      {
         invalid = lvl;
         why = StringFormat("level %.2f", invalid);
      }
   }

   if(invalid <= 0.0)
      return;

   // Keep it a sensible distance away. An invalidation two ticks from entry fires on
   // noise; one five dollars away is not an invalidation, it is a stop-loss.
   double dist = MathAbs(invalid - mid) / _Point;
   if(dist < (double)ThesisMinDistance || dist > (double)ThesisMaxDistance)
      return;

   G_BASKET_INVALIDATION = invalid;
   G_BASKET_THESIS = why;

   if((ThesisPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v247 THESIS] %s basket - wrong above/below %.2f (%s, %.0f pts away)",
                  (dir > 0 ? "long" : "short"), invalid, why, dist);
}

// Has price disproved the basket's reason? Checked once per bar on closes, not ticks -
// a wick through an invalidation is price testing it, a close through is price
// settling the question.
bool BasketPremiseDead(string &detail)
{
   detail = "";
   if(!EnableBasketThesis || G_BASKET_ORDERS <= 0 || G_BASKET_INVALIDATION <= 0.0)
      return false;

   if(G_BASKET_PREMISE_DEAD)
   {
      detail = StringFormat("premise gone - %s", G_BASKET_THESIS);
      return true;
   }

   double c = CandleClose(LocalStructureTF, 1);
   if(c <= 0.0)
      return false;

   int dir = (G_BASKET_DIRECTION == POSITION_TYPE_BUY) ? 1 : -1;
   double tol = ScaleAdjustedPoints(MathMax(1, ThesisTolerance)) * _Point;

   bool through = (dir > 0) ? (c < G_BASKET_INVALIDATION - tol)
                            : (c > G_BASKET_INVALIDATION + tol);

   if(!through)
      return false;

   G_BASKET_PREMISE_DEAD = true;
   detail = StringFormat("premise gone - closed through %.2f (%s)",
                         G_BASKET_INVALIDATION, G_BASKET_THESIS);

   if((ThesisPrintOnUse && G_VERBOSE))
      PrintFormat("[SIRUS v247 THESIS] %s - the ladder stops here", detail);

   return true;
}


// ============================================================================
// V246: THE LEVEL THAT WAS BROKEN AND TOOK ITSELF BACK
// ----------------------------------------------------------------------------
// ZoneMapIsPolarityFlip looks for one crossing: price was on one side, then it was on
// the other. That describes a level changing role, and it is the wrong shape for the
// thing that actually happens most often at a strong level.
//
// From the live chart: a band at 4492-4494 that price broke through TWICE and came
// straight back under both times. To the flip test that reads as a level whose role
// keeps changing - ambiguous, unreliable. In practice it is the opposite: a level
// that has defeated two attempts to break it is stronger than one that was never
// tested, because the attempts themselves are evidence.
//
// The difference is what happened AFTER the break. A break that holds is a level
// giving way. A break that is reclaimed within a few bars is a level absorbing an
// attack - and the traders who took that break are now trapped on the wrong side,
// which is what makes the next approach to it so reliable.
//
// So this counts failed breaks rather than crossings, and treats them as strength
// rather than confusion.
// ============================================================================

// How many attempts to break this level have failed? Returns the count, and how
// recently the last one was.
int FailedBreakCount(const double level, const bool as_resistance,
                     int &bars_since_last, string &detail)
{
   bars_since_last = -1;
   detail = "";

   if(!EnableFailedBreakRead || level <= 0.0 || _Point <= 0.0)
      return 0;

   ENUM_TIMEFRAMES tf = FailedBreakTF;
   int look = MathMax(20, FailedBreakLookback);
   double tol = ScaleAdjustedPoints(MathMax(1, FailedBreakTolerance)) * _Point;

   int failures = 0;
   int last_shift = -1;

   // Walk back looking for bars that closed BEYOND the level, then check whether price
   // came back within the reclaim window. A break that was never reclaimed is a real
   // break and does not count here - it means the level gave way.
   for(int i = 1; i <= look; i++)
   {
      double c = CandleClose(tf, i);
      if(c <= 0.0)
         continue;

      bool beyond = as_resistance ? (c > level + tol) : (c < level - tol);
      if(!beyond)
         continue;

      // Found a close through. Was it taken back? Look at the bars AFTER it - which
      // are the ones with smaller shift numbers.
      bool reclaimed = false;
      int window = MathMax(1, FailedBreakReclaimBars);
      int reclaim_from = i - 1;
      int reclaim_to   = MathMax(1, i - window);
      for(int j = reclaim_from; j >= reclaim_to; j--)
      {
         double cj = CandleClose(tf, j);
         if(cj <= 0.0)
            continue;
         bool back = as_resistance ? (cj < level) : (cj > level);
         if(back)
         {
            reclaimed = true;
            break;
         }
      }

      if(reclaimed)
      {
         failures++;
         if(last_shift < 0 || i < last_shift)
            last_shift = i;

         // Skip past this attempt so a three-bar excursion is not counted three times.
         i += window;
      }
      // FIX(failed-break-i1): for i==1 (the most recently closed bar) reclaim_from (i-1=0) is
      // always below reclaim_to (>=1), so the reclaim window is EMPTY - there simply hasn't been
      // a younger closed bar yet to show a reclaim. The old code treated that exactly like "checked
      // and found not reclaimed", took the else branch below, and stopped the whole scan right
      // there - discarding every genuine failed-break further back in history whenever the most
      // recent closed bar happened to sit beyond the level (i.e. right as a fresh break is in
      // progress, which is exactly when this level's defensive history matters most). Treat an
      // empty reclaim window as "not enough time yet to tell" and keep scanning older bars instead
      // of ending the scan on it.
      else if(reclaim_from < reclaim_to)
      {
         continue;
      }
      else
      {
         // A break that held. Whatever happened before it belongs to a different
         // level - price is on the other side now and the history stops meaning what
         // it meant.
         break;
      }
   }

   if(failures <= 0)
      return 0;

   bars_since_last = last_shift;
   detail = StringFormat("%d failed break%s, last %d bars ago",
                         failures, (failures > 1 ? "s" : ""), last_shift);
   return failures;
}
