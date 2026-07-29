---
{
  "name": "market_monitor",
  "description": "Show a live market price on the device display with a threshold alert: commodities (oil, gold, gas), equities, indices, crypto and FX. Do a one-off price check, change the monitored symbol or the alert thresholds, or manage the recurring monitor. Telegram/MCP friendly.",
  "metadata": {
    "cap_groups": [
      "cap_lua",
      "cap_scheduler"
    ],
    "manage_mode": "readonly"
  }
}
---

# Market price monitor

Show any market price on the device screen with a colour-coded threshold alert, and manage the recurring monitor.

## When to use
- The user asks to see / monitor / check a price: oil, Brent, WTI, gold, silver, gas, a stock, an index, a crypto, a currency pair.
- The user wants to change the monitored instrument, or set/change the alert thresholds.
- The user asks for a one-off ("quanto sta il Brent adesso?", "what's Apple at?").

## How it works
`/fatfs/skills/market_monitor/scripts/market_monitor_runner.lua` fetches the quote from the Yahoo Finance v8 chart API and renders: big price, daily change (green up / red down), and a state banner. A scheduler item `market_monitor` runs it every 15 minutes. It alerts by colour + blink: **red = at/above the high threshold, blue = at/below the low threshold, green = within range**. The symbol and thresholds are persisted, so the scheduled run reuses whatever was last set as default.

## Symbols
Any Yahoo Finance ticker works — the symbol is passed straight through. Map the user's words to a ticker:

| User says | Symbol |
|---|---|
| petrolio / Brent (Europe benchmark) | `BZ=F` |
| WTI (US benchmark) | `CL=F` |
| oro / gold · argento / silver | `GC=F` · `SI=F` |
| gas naturale · rame / copper | `NG=F` · `HG=F` |
| bitcoin · ethereum | `BTC-USD` · `ETH-USD` |
| euro/dollaro · sterlina/dollaro | `EURUSD=X` · `GBPUSD=X` |
| S&P 500 · Nasdaq · Dow Jones · FTSE MIB | `^GSPC` · `^IXIC` · `^DJI` · `FTSEMIB.MI` |
| Apple · Microsoft · Nvidia · Tesla | `AAPL` · `MSFT` · `NVDA` · `TSLA` |

For anything not listed, use the ordinary Yahoo ticker (e.g. `ENI.MI`, `SPY`, `SOL-USD`). If you are unsure a ticker exists, do a one-off check first and see whether a price comes back.

## One-off check NOW (does not change the recurring monitor)
Call `lua_run_script_async` with:
```json
{
  "path": "/fatfs/skills/market_monitor/scripts/market_monitor_runner.lua",
  "args": { "symbol": "BZ=F", "high": 85, "low": 70 },
  "exclusive": "display",
  "replace": true,
  "timeout_ms": 90000
}
```
- `symbol`, `high`, `low`, `label` are all optional. Omit them to use the current defaults.
- Setting only `high` or only `low` is allowed (the other side just won't alert).
- Thresholds are absolute price levels in the quote currency.
- The display shows for ~20 seconds. Report the outcome to the user in their language.

## Set the RECURRING monitor (persisted; used by the 15-min scheduler)
Same call, add `"set_default": true` inside `args`:
```json
{ "path": "/fatfs/skills/market_monitor/scripts/market_monitor_runner.lua",
  "args": { "symbol": "BTC-USD", "high": 100000, "low": 80000, "set_default": true },
  "exclusive": "display", "replace": true, "timeout_ms": 90000 }
```
- This makes the autonomous 15-min dashboard track that instrument with those thresholds.
- Only ONE instrument is monitored at a time: setting a new default replaces the previous one.
- The built-in default is Brent (`BZ=F`) with a 65–80 band.

## Push notifications when a threshold is crossed
The device can send a chat message when the price crosses a threshold (edge-triggered: one message when it enters ALERT above the high or below the low, one when it returns within range — never every cycle).

Because a proactive push needs a destination chat, the user opts in **from the chat where they want the alerts**:
- `/watchprice` — enable alerts on this chat (keeps current config).
- `/watchprice 85 70` — enable and set high=85, low=70.
- `/watchprice GC=F 2700 2400` — also set the instrument (plain words like `oro`, `bitcoin` work too).
- `/watchprice off` — stop alerts.

This works from any connected platform (Telegram, etc.): the command captures whatever chat it was sent from. The chat is also remembered automatically from any message, so alerts usually work even if the user never ran the command.

If the user asks in natural language to be notified (e.g. "avvisami quando il Brent supera 85"), set the thresholds with a `set_default` run and confirm that alerts will arrive in this chat.

## Other controls
- Force an immediate refresh of the recurring monitor: `scheduler_trigger_now` with `{ "id": "market_monitor" }`.
- Change the refresh interval: `scheduler_update` on the `market_monitor` item with a new `interval_ms` (900000 = 15 min, 300000 = 5 min).

## Notes
- One-off calls (no `set_default`) never change the recurring monitor.
- Decimals adapt to magnitude: 4 for FX, 2 for oil/equities, 0 for indices and crypto.
- The runner takes the screen exclusively. Launching it while another display script is still up is safe — it backs off and draws when the panel frees up — but it will take longer to come back, so prefer one at a time.
