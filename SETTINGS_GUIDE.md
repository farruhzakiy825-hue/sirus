# SIRUS — Settings Guide

The settings window opens with **SIRUS ▸ Quick Setup**. These are the only settings an operator normally changes. Everything under **ADVANCED ▸**, **BRAIN ▸**, **DISPLAY ▸** and **DIAGNOSTICS ▸** is tuned already, so leave it as it is unless you know exactly why you are changing it.

| Section | Setting | What it does |
|---|---|---|
| **1 · General** | EA version | Name shown on the panel |
| | Order comment brand | Start of every order comment (`SIRUS by Zakiy \| TREND`) |
| | Trading mode | AUTO (adaptive), BALANCED or HIGH HUNTER (aggressive) |
| | AUTO fallback mode | Mode used when AUTO is unsure |
| | Magic number | Separates this EA's orders from others |
| | Allow live trading | Main switch for trading |
| **2 · Lot size** | Start lot (first order) | Lot of every basket's first order |
| | Auto lot from balance | On: the lot is calculated from *Auto lot: risk per entry (%)* |
| | Min first-entry lot factor | 1.0 = the first order always opens at the full lot |
| **3 · Grid recovery** | Grid recovery | Main switch for the grid |
| | Max orders per basket | Includes the first order |
| | Grid step (points) / multiplier | Distance to the next grid order, and how much each step widens |
| | Grid lot multiplier | Each grid order is this many times bigger than the last |
| | Adaptive grid step (ATR) | The step follows volatility |
| | Grid rescue guarantee | Soft holds never freeze the grid. Every rung still needs confirmation: *steps + slowdown*, or deeper *steps + pause* |
| **4 · Take profit & exit** | Basket take profit / scale / minimum | Fixed basket take profit (normal mode) |
| | Smart runner | Normal mode only: the right baskets trail past the take profit (*start at* / *locked profit*) |
| **5 · Cashback mode** | Cashback mode | Fixed take profit built from the spread: TP = spread × multiple + extra. No trailing |
| | Cashback fast tempo | Faster re-entries in cashback mode |
| **6 · Protection** | Basket stop loss (% of balance) | Main stop: closes the whole basket |
| | Daily loss limit / Close basket at daily loss limit | Daily cap, and whether to close the open basket when it is hit |
| | Equity stop / Emergency close | Account-level protection |
| | Smart early exit | Optional exit before the basket stop (off by default) |
| | Max spread / News filter / Weekend protection / Free margin check | Entry guards |
| **7 · Display & alerts** | Show dashboard / Push notifications / Detailed journal logs | Panel, phone alerts and log detail |

Groups marked **(inactive)** under ADVANCED are not connected to any logic; they remain only so that old presets still load.

Every setting keeps its technical explanation as a comment in the source code, on the line directly above the setting.
