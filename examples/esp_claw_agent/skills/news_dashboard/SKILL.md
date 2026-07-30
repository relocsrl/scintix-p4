---
{
  "name": "news_dashboard",
  "description": "Show the latest news headlines on the device display, on any topic the user asks for (tech/AI by default, or football, politics, a company, a country...). Also sets which topic the recurring 15-minute dashboard tracks. Telegram/MCP friendly.",
  "metadata": {
    "cap_groups": [
      "cap_lua",
      "cap_scheduler"
    ],
    "manage_mode": "readonly"
  }
}
---

# News dashboard

Fetch current headlines and show them on the device screen, for any subject.

## When to use
- The user asks to see news on the display: "mostra le notizie", "che novità ci sono sull'AI?", "fammi vedere le news sulla Formula 1".
- The user wants the recurring dashboard to follow a different topic from now on.
- The user asks to go back to the default tech/AI news.

## How it works
`/fatfs/skills/news_dashboard/scripts/news_dashboard_runner.lua` runs a few web searches for the topic and takes the titles the search backend marks as markdown headings (`### ...`), which are the article titles; if a result set carries no such listing it falls back to mining complete sentences out of the prose, and if search returns nothing at all to Google News RSS. It renders up to 6 numbered headlines with horizontal scrolling for long titles, plus the local date/time (timezone resolved via geo-IP and cached). A scheduler item `news_dashboard` runs it every 15 minutes.

The topic is resolved as: `args.topic` (one-shot) → persisted default (`/fatfs/scripts/news_topic.txt`) → built-in AI/TECH.

## Show news on a topic NOW (does not change the recurring topic)
Call `lua_run_script_async` with:
```json
{
  "path": "/fatfs/skills/news_dashboard/scripts/news_dashboard_runner.lua",
  "args": { "topic": "Formula 1" },
  "exclusive": "display",
  "replace": true,
  "timeout_ms": 120000
}
```
- Omit `topic` (or pass `""`) for the built-in AI/TECH headlines.
- **Translate the subject to English** for much better search recall, and keep it to a few words: user says "calcio" → `"topic": "football soccer"`; "borsa" → `"topic": "stock market"`; "elezioni francesi" → `"topic": "French elections"`.
- The display shows for ~30 seconds; fetching the headlines takes a while first, so allow a generous `timeout_ms`.
- Report the headlines back to the user in chat, in their language, and say which topic you searched.

## Change the RECURRING topic (persisted; used by the 15-min scheduler)
Same call, add `"set_default": true` inside `args`:
```json
{ "path": "/fatfs/skills/news_dashboard/scripts/news_dashboard_runner.lua",
  "args": { "topic": "climate policy", "set_default": true },
  "exclusive": "display", "replace": true, "timeout_ms": 120000 }
```
- To reset back to the built-in AI/TECH default, pass `set_default: true` with an empty topic:
  `{ "topic": "", "set_default": true }`.

## Other controls
- Force an immediate refresh: `scheduler_trigger_now` with `{ "id": "news_dashboard" }`.
- Change the refresh cadence: this item is a **cron** schedule, so `scheduler_update` it with a new `cron_expr` (`*/15 * * * *` = every 15 min, `*/5 * * * *` = every 5 min). Note each cron field accepts only `*`, `*/N` or a plain number — comma lists and ranges are rejected.

## Notes
- Only ONE recurring topic at a time; setting a new default replaces the previous one.
- Headlines come from the search results, so a site that marks its navigation as headings can contribute a section name instead of a story, and the prose fallback may reword a title.
- The dashboard shares the screen with the market monitor (offset by 7.5 minutes so they alternate); the runner takes the display exclusively. Starting it while another display script is still up is safe — it backs off and draws when the panel frees up — but it will take longer to come back.
