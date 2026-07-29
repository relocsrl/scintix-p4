# scripts/

Writable working directory for Lua scripts (`CLAW_PATH_DATA/scripts`, exposed as
`lua_root_dir`). Nothing in the firmware creates it — the path is only computed —
so it ships as part of the storage image to make sure it exists on a freshly
flashed device.

Skills keep their small persistent state here, for example:

| File | Written by | Purpose |
| --- | --- | --- |
| `tz_cache.txt` | news dashboard, market monitor | Cached geo-IP timezone offset, so the local time survives reboots without re-querying. |
| `news_topic.txt` | news dashboard | The recurring news topic set from chat. |
| `market_state.txt` | market monitor | Monitored symbol and alert thresholds. |
| `market_notify.txt` | market monitor | Chat to push threshold alerts to, plus the last alert state for edge triggering. |

Without this directory those writes fail silently: the dashboards still render
with their built-in defaults, but nothing the user configures from chat would
persist and threshold notifications would never arm.
