# Scintix P4 — ESP-Claw (on-device AI agent)

> Target: **ESP32-P4 + ESP32-C6** · Tested on **ESP-IDF v5.5.4** · Verified against esp-claw `ac2a2ec` and `6476658`
>
> 🚀 **SCINTIX P4 is coming to Crowd Supply!** [**Follow our pre-launch page**](https://www.crowdsupply.com/reloc/scintix-p4) to be notified the moment the campaign goes live.
>
[ESP-Claw](https://github.com/espressif/esp-claw) is Espressif's "chat-coding" **AI-agent runtime** for ESP32: the full sense → reason → decide → act loop runs on the chip, talking to an LLM over the network and acting through local Lua scripts (its *skills*). This example runs ESP-Claw on the **Scintix P4** — Wi-Fi comes from the on-board ESP32-C6, and the agent's face is shown on the MIPI-DSI display.

On top of the plain agent it adds **two autonomous dashboards** that take turns on the panel every 15 minutes with no LLM involved, plus a demo skill the agent (or Claude over MCP) can call on demand:

| Skill | What it does |
| ----- | ------------ |
| [`news_dashboard`](skills/news_dashboard) | Up to 6 current headlines on any subject, with local date/time. Tracks a topic you set from chat; defaults to AI/tech. |
| [`market_monitor`](skills/market_monitor) | Any Yahoo Finance instrument — commodities, equities, indices, crypto, FX — as a big price with daily change and a colour-coded threshold alert. Can push a chat message when a threshold is crossed. Defaults to Brent (`BZ=F`). |
| [`scintix_display`](skills/scintix_display) | Writes a full-screen message on the panel. The "hello world" for driving the device from Claude over MCP. |

> **This is not a self-contained project.** ESP-Claw lives in its own repository and is built with the **ESP Board Manager**. What this folder ships is the Scintix-specific *overlay*: the board definition, the skills, the seed router rules and schedules that wire the dashboards up, and one optional patch to the ESP-Claw C code. [`install.py`](install.py) drops it all into your `esp-claw` checkout, and you build from there.

## Hardware

* A **Scintix P4** module (ESP32-P4 + on-board ESP32-C6 for Wi-Fi).
* A **7" 1024×600 MIPI-DSI panel (EK79007)** + **GT911 touch**, on a **Waveshare CM4-to-Pi4 adapter** — same display setup as the [`esp_brookesia_phone`](../esp_brookesia_phone) example.
* A 2.4 GHz Wi-Fi network with internet access (to reach the news/quote APIs, and the LLM endpoint if you configure one).
* **Flashing & serial console: use the [Espressif ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html) (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html)) on the 6-pin header next to the ESP32-P4** (the board has a second 6-pin header next to the ESP32-C6, for the Wi-Fi firmware — see [which header is which](../../esp32c6_wifi_firmware/README.md#which-6-pin-header)). On the Waveshare carrier the module's USB-C is **power-only** (same as the Brookesia example) — to flash over the module's native USB-C you'd have to detach the Scintix from the carrier first.

Audio, the SD card and the camera are **not** included in this board definition — the carrier provides neither a codec nor a slot, and nothing here uses a camera. Add them in the board YAML if you need them.

## The Scintix P4 board definition

[`board/scintix_p4/`](board/scintix_p4) is derived from the upstream `espressif/esp32_p4_function_ev` board, changed only where the Scintix hardware differs:

| Item | EV board | Scintix P4 |
| ---- | -------- | ---------- |
| Backlight (`ledc_backlight.gpio_num`) | GPIO 26 | **GPIO 3** (Waveshare 40-pin header GPIO27) |
| LCD reset (`display_lcd.reset_gpio_num`) | GPIO 27 | **GPIO 4** (Waveshare 40-pin header GPIO22) |
| Display driver (`esp_lcd_ek79007`) | `^1.0.0` | **`2.0.*`** (1.0.x lacks `disp_on_off` → black screen on this panel) |
| Flash size | 16 MB | **32 MB** |
| PSRAM speed | 200 MHz | **250 MHz** |
| `ESP32P4_SELECTS_REV_LESS_V3` | enabled | **disabled** (Scintix is silicon rev v3.1) |
| Devices in the board YAML | display, touch, audio, SD, camera | **display + touch + backlight** |

The three devices are `display_lcd` (EK79007 DSI, 1024×600, RGB565, 2 data lanes), `lcd_touch` (GT911 over I2C at `0xba`/`0x28`, mirrored on both axes) and `lcd_brightness` (LEDC backlight). Nothing here uses a camera, so the board YAML does not declare one.

[`sdkconfig.defaults.board`](board/scintix_p4/sdkconfig.defaults.board) also enables the MCP server (for the Claude demo) and configures the ESP32-C6 Wi-Fi over SDIO. That C6 wiring is **not** Scintix-specific — it's the **standard Function-EV-Board reference layout** (slot 1: CLK 18 / CMD 19 / D0–D3 14–17, reset 54); the board file just sets it explicitly. I2C (SDA 7 / SCL 8), the MIPI LDO and the DSI bus are identical to the reference design too.

## ESP32-C6 Wi-Fi firmware (usually pre-flashed)

Wi-Fi on the Scintix P4 is provided by the on-board **ESP32-C6**, which runs the esp_hosted *slave* firmware — separate from the ESP-Claw application you flash to the P4. **Scintix P4 modules ship with it pre-flashed, so you normally don't need to touch it.** If you start from a blank C6 (or want to restore/update it), the binaries and full flashing instructions are in [`esp32c6_wifi_firmware/`](../../esp32c6_wifi_firmware) — flash them with the [Espressif ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html) (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html)) on the 6-pin header **next to the ESP32-C6**.

## Build and flash

You need **ESP-IDF v5.5.4** (the same toolchain as the Brookesia example), with its export script sourced so `idf.py` is on your PATH.

```bash
# 1. Get ESP-Claw
git clone https://github.com/espressif/esp-claw.git
cd esp-claw/application/edge_agent

# 2. Install the ESP Board Manager idf.py extension INTO THE ACTIVE IDF VENV
python -m pip install esp-bmgr-assist

# 3. Resolve and download the managed components (needs network).
#    Do this BEFORE bmgr: the `bmgr` action itself ships inside
#    managed_components/espressif__esp_board_manager (as idf_ext.py).
idf.py set-target esp32p4

# 4. Install this overlay into the checkout (adjust the path to this example)
python /path/to/scintix-p4/examples/esp_claw_agent/install.py --target .

# 5. Select the board: generates components/gen_bmgr_codes from the board YAML
#    and emits board_manager.defaults
idf.py bmgr -c ./boards -b scintix_p4

# 6. Build the app plus the system.bin / storage.bin filesystem images
idf.py build
idf.py -p <PORT> flash monitor
```

This sequence was verified end to end from a fresh clone, flashed onto a board and checked on the running device: the resulting `sdkconfig` carries the board defaults (32 MB flash, `partitions_32MB.csv`, 250 MHz PSRAM, `esp_hosted`) and the three skills are present under `build/fatfs_image/skills/`. After flashing, both dashboards ran and rendered, the seeded rules and schedules were in place, and the skills persisted their state — see [First boot](#first-boot).

### What `install.py` does

Most of it is copying folders into place:

| From (this example) | To (in `esp-claw/application/edge_agent`) |
| ------------------- | ----------------------------------------- |
| `board/scintix_p4/` | `boards/reloc/scintix_p4/` |
| `skills/<name>/` | `fatfs_image/storage/skills/<name>/` |
| `scripts/` | `fatfs_image/storage/scripts/` |

`scripts/` looks pointless — it holds only a README — but it is not. It is the writable working directory where the skills persist the topic, the monitored symbol, the thresholds and the alert target chat. **Nothing in the firmware creates it**, so without it those writes fail silently: the dashboards still render with their built-in defaults, but nothing you configure from chat survives and threshold alerts never arm.

The part you should not do by hand is the **seeds**. [`seeds/router_rules.json`](seeds/router_rules.json) and [`seeds/schedules.json`](seeds/schedules.json) are fragments that have to be **merged** into files ESP-Claw already ships under `fatfs_image/system/.recovery/`, and for the router rules **the position matters**: they must be inserted *before* the `im_*` rules, because `im_any_message_agent` consumes every text message and anything after it would never be evaluated. `install.py` inserts them at the right index and skips entries whose `id` is already present, so re-running it is safe.

What the seeds add:

* schedules `news_dashboard` (cron `*/15 * * * *`) and `market_monitor` (15-minute interval, anchored so it lands 7.5 minutes out of phase with the news) — this is what makes the two dashboards alternate on the screen.
* rules `news_dashboard` / `market_monitor` mapping those schedule events to the runner scripts, plus `market_watch_command` (`/watchprice`) and `market_capture_chat` (remembers which chat to push alerts to).

`recover_missing_files()` copies the seeds into `/fatfs` at boot, but **only entries missing there** — a device that already carries its own `router_rules.json` is deliberately left untouched. So the seeds take effect on a virgin partition; to change an already-provisioned device, go through the router/scheduler capabilities instead of editing the seed files.

### The optional C patch

The two dashboards need **no changes to the ESP-Claw C code**. [`patches/`](patches) holds one commit that is useful anyway, applied with `--patches mcp` (or `--patches all`):

| Patch | Why |
| ----- | --- |
| `0001-edge_agent-bring-up-the-MCP-server-on-boot` | **Needed for the MCP demo below.** `edge_agent` never calls `cap_mcp_server_start()` upstream (only the separate `mcp_server_point` app does), so enabling the MCP capability in sdkconfig is not enough to get a listening server. Adds `main/mcp_bringup.c` and a hook in `main.c`. |

`install.py --patches` runs `git apply` from the esp-claw repository root, checks first, and skips a patch that is already applied. If your checkout has drifted from `ac2a2ec` and the patch no longer applies, the diff is small — 12 lines in `main.c` plus two new files — so apply it by hand. `main/CMakeLists.txt` uses `SRC_DIRS "."`, so `mcp_bringup.c` is picked up with no CMake edit.

### If you change the board YAML or `sdkconfig.defaults.board` later

ESP-IDF does **not** re-apply defaults to an existing `sdkconfig`. They are injected only when `sdkconfig` is absent, so after editing them:

```bash
idf.py bmgr -c ./boards -b scintix_p4   # regenerate from the YAML
rm sdkconfig                            # let the defaults be applied again
idf.py reconfigure
```

Back up `sdkconfig` first if it holds manual tweaks you want to keep.

### Reflashing without wiping device data

`idf.py flash` writes `storage.bin` too, which **erases `/fatfs`** — every skill, Lua script, router rule and schedule the device has accumulated at runtime. That is what you want for a virgin board. To update only the firmware and keep the data partition:

```bash
cd build
python -m esptool --chip esp32p4 -p <PORT> -b 460800 \
  --before default_reset --after hard_reset write_flash \
  --flash_mode dio --flash_size 32MB --flash_freq 40m \
  0x10000 ota_data_initial.bin 0x20000 edge_agent.bin
```

Note that opening the serial port resets the ESP32-P4, which restarts the app and blanks the display — avoid attaching a monitor when you want the screen to keep showing something.

## First boot

The image carries no settings of its own: Wi-Fi credentials and API tokens live in NVS, so a freshly flashed board comes up **unprovisioned**. The C6 starts a Wi-Fi **access point** (`esp-claw-<mac>`) and ESP-Claw serves a **web-config** UI:

* Connect to the device's AP, then open **`http://192.168.4.1/`** — later, on your network, `http://esp-claw.local/` or `http://<device-ip>/`.
* Enter your **Wi-Fi** credentials and, if you want the conversational agent, the LLM **profile / Base URL / API key / model**. These are stored in NVS and persist across reboots.
* The optional **MCP server** field is the URL of an *external* MCP server whose tools the agent should use — leave it empty for a first run.

No `menuconfig` and no registration step for the skills: they are discovered by scanning `/fatfs/skills`, and the rules and schedules are seeded from `.recovery` during boot.

What each demo actually needs at runtime:

| Demo | Requirement |
| ---- | ----------- |
| `market_monitor` | **Network only.** It reads the Yahoo Finance v8 chart API through `http_request`; no LLM is involved. |
| `news_dashboard` | Network. Uses the `web_search` capability when a search backend is configured, and falls back to Google News RSS over `http_request` when it is not. |
| Threshold push alerts | A configured IM channel (e.g. Telegram). Without one the monitor just renders on screen and skips the notification. |
| `scintix_display` on demand | An LLM (to ask in natural language) **or** an MCP client **or** the serial console. |

So the two dashboards start alternating on the display as soon as the board has network, whether or not an LLM has been configured.

Between refreshes the panel shows ESP-Claw's own idle screen — on recent revisions that is the LVGL **system UI** (a clock), which replaced the older animated emote face (ESP-Claw's own `APP_CLAW_SYSTEM_UI_ENABLE`, on by default). The dashboards take the display exclusively and draw over it, then hand it back.

This was checked on a board flashed from scratch with this overlay:

| Check | Result |
| ----- | ------ |
| `/fatfs/skills/` | `market_monitor`, `news_dashboard`, `scintix_display` discovered by the registry scan. |
| Seeded rules | 12 rules loaded, ours at indices 1–4, ahead of the first `im_*` rule at index 5. |
| Seeded schedules | 5 entries loaded, `news_dashboard` (cron `*/15`) and `market_monitor` (900 s interval) enabled. |
| `market_monitor` | Rendered `BRENT CRUDE OIL $86.45 (-2.16%) state=HIGH`, with the local time resolved through geo-IP. |
| `news_dashboard` | Rendered 6 headlines. Checked both ways: with **no** search backend configured it came through the Google News RSS fallback, and with one configured through `web_search`. |
| Both at once | Starting one while the other holds the panel is handled: the second backs off and renders when the display frees up, instead of failing. |
| `/fatfs/scripts/` | `tz_cache.txt` and `market_notify.txt` appear on the first run, `market_state.txt` as soon as a symbol or threshold is set — the state really does persist. |
| MCP server | 6 `lua.*` tools registered, endpoint answering on port 18791. |

## Using the dashboards

Both keep **one** subject at a time, persisted, and both can also be run one-off without disturbing the recurring setting. Full details in [`skills/news_dashboard/SKILL.md`](skills/news_dashboard/SKILL.md) and [`skills/market_monitor/SKILL.md`](skills/market_monitor/SKILL.md); the short version:

* **From chat, in natural language** (needs an LLM): *"mostra le notizie sulla Formula 1"*, *"quanto sta il Brent?"*, *"da ora monitora il bitcoin, avvisami sopra 100000"*. The agent picks the skill and passes `set_default: true` when you asked for a lasting change.
* **Threshold alerts, no LLM needed** — from the chat where you want them:
  `/watchprice` · `/watchprice 85 70` · `/watchprice GC=F 2700 2400` · `/watchprice off`
  (plain words work too: `/watchprice oro 2700 2400`). Alerts are **edge-triggered**: one message when the price enters the alert band, one when it comes back, never every cycle.
* **Force a refresh now:** `scheduler_trigger_now` with `{"id": "market_monitor"}` (or `news_dashboard`).
* **Change the cadence:** `scheduler_update` on that item — `interval_ms` for `market_monitor` (an interval schedule), `cron_expr` for `news_dashboard` (a cron one).

The market monitor takes any Yahoo ticker (`BZ=F`, `CL=F`, `GC=F`, `BTC-USD`, `EURUSD=X`, `^GSPC`, `AAPL`, `ENI.MI`, …) and adapts decimals to magnitude: 4 for FX, 2 for oil and equities, 0 for indices and crypto. For the news dashboard, **searching in English** gives markedly better recall — the skill instructs the agent to translate the subject first ("calcio" → `football soccer`).

## Demo: write on the screen (agent / Claude over MCP)

[`skills/scintix_display`](skills/scintix_display) shows a full-screen message on the panel ([`show_text.lua`](skills/scintix_display/scripts/show_text.lua)), on a dark background (`0x171617`) with amber text, shown for ~8 s before the idle screen returns. The colours were picked to match the animated emote face of older ESP-Claw revisions; on current ones the idle screen is the system UI clock instead. Parameters: `text`, `font_size`, `hold_ms` (see [`SKILL.md`](skills/scintix_display/SKILL.md)).

Three ways to trigger it:

1. **On-device agent** — say it in natural language (serial console or a chat channel):
   `ask write on the screen: Hello from Claude` → the agent picks the `scintix_display` skill.
2. **Directly from the console** (no LLM):
   ```
   lua --run --path /fatfs/skills/scintix_display/scripts/show_text.lua --args-json "{\"text\":\"Hello\"}" --timeout-ms 12000
   ```
3. **From Claude over MCP** (needs patch `0001`). The device advertises an MCP server (mDNS `_mcp._tcp`, host `esp-claw.local`) on **`http://esp-claw.local:18791/mcp`** (or `http://<device-ip>:18791/mcp`). Bridge Claude Desktop to it with `mcp-remote` in `claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "scintix-p4": {
         "command": "npx",
         "args": ["-y", "mcp-remote", "http://esp-claw.local:18791/mcp"]
       }
     }
   }
   ```
   Then ask: *"On the Scintix P4 screen, show: Hello from Claude"*.

   The server exposes six tools: `lua.run_script`, `lua.run_script_async`,
   `lua.get_async_job`, `lua.list_async_jobs`, `lua.stop_async_job`,
   `lua.stop_all_async_jobs`. If you drive them from your own client rather than
   a proper MCP one, note that **every declared property has to be present** in
   `arguments` — omit one and the call comes back `-32602 Invalid params`
   (`expected params.arguments`), which reads like a malformed request but is
   really a missing field. Pass empty strings for the ones you don't need.

## Troubleshooting (gotchas we hit)

* **Black screen, but the boot log shows the display initialized and the emote assets loaded** → the `esp_lcd_ek79007` driver resolved to **1.0.x**, which lacks `disp_on_off`, so this EK79007 panel never turns on (`esp_lcd_panel_disp_on_off … not supported` in the log). This board pins the driver to **`2.0.*`** in [`board/scintix_p4/board_devices.yaml`](board/scintix_p4/board_devices.yaml). After changing it, delete `managed_components/` + `dependencies.lock` and rebuild so 2.0.x is actually fetched.
* **`idf.py bmgr` shows no options / "Execute targets that are not explicitly known"** → the `esp-bmgr-assist` package isn't installed in the **active IDF venv**. Run `python -m pip install esp-bmgr-assist` there. If it is installed but `bmgr` still fails, you likely skipped `idf.py set-target esp32p4`, so `managed_components/` (which carries the extension) doesn't exist yet.
* **The dashboards render but nothing you set from chat sticks** — the monitored symbol reverts to Brent, the news topic resets, `/watchprice` never delivers → `/fatfs/scripts/` is missing. Check that `build/fatfs_image/scripts/` exists before flashing; that directory comes from this overlay, not from ESP-Claw.
* **The dashboards never appear at all** → the seeds were not merged, or were merged into a device that already had its own `/fatfs/system/.recovery` state. Check the schedule list and the rule order on the device (`router_rules.json`): our rules must precede `im_any_message_agent`.
* **A Lua script returns just `false`** → that is an *error*, not a return value. Wrap it to see the reason: `xpcall(function() dofile(path) end, debug.traceback)`.

## Links

* [ESP-Claw repository](https://github.com/espressif/esp-claw) · [docs](https://esp-claw.com/) · [build from source](https://esp-claw.com/en/reference-project/build-from-source/)
* [ESP Board Manager — customize a board](https://github.com/espressif/esp-gmf/blob/main/packages/esp_board_manager/docs/how_to_customize_board.md)
