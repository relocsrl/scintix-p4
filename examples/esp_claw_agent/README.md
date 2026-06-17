# Scintix P4 — ESP-Claw (on-device AI agent)

> Target: **ESP32-P4 + ESP32-C6** · Tested on **ESP-IDF v5.5.4**

[ESP-Claw](https://github.com/espressif/esp-claw) is Espressif's "chat-coding" **AI-agent runtime** for ESP32: the full sense → reason → decide → act loop runs on the chip, talking to an LLM over the network and executing local Lua. This example runs ESP-Claw on the **Scintix P4** — Wi-Fi is provided by the on-board ESP32-C6, and the agent's animated face is shown on the MIPI-DSI display. It also ships a small demo skill, **`scintix_display`**, that lets the agent (or Claude over MCP) write a full-screen message on the panel.

> **This is not a self-contained project.** ESP-Claw lives in its own repository and is built with the **ESP Board Manager**. What this folder ships is the **Scintix P4 board definition** ([`board/scintix_p4/`](board/scintix_p4)) and a demo **skill** ([`skills/scintix_display/`](skills/scintix_display)). You drop these into your `esp-claw` checkout and build from there.

## Hardware

* A **Scintix P4** module (ESP32-P4 + on-board ESP32-C6 for Wi-Fi).
* A **7" 1024×600 MIPI-DSI panel (EK79007)** + **GT911 touch**, on a **Waveshare CM4-to-Pi4 adapter** — same display setup as the [`esp_brookesia_phone`](../esp_brookesia_phone) example.
* A 2.4 GHz Wi-Fi network with internet access (to reach the LLM endpoint).
* **Flashing & serial console: use the Espressif 6-pin programmer on the Scintix P4 header.** On the Waveshare carrier the module's USB-C is **power-only** (same as the Brookesia example) — to flash over the module's native USB-C you'd have to detach the Scintix from the carrier first.

Audio, SD card and camera are **not** included in this board definition. Add them in the board YAML if your carrier provides them.

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
| Devices in the board YAML | display, touch, audio, SD, camera | **display + touch only** |

[`sdkconfig.defaults.board`](board/scintix_p4/sdkconfig.defaults.board) also enables the MCP server (for the Claude demo) and configures the ESP32-C6 Wi-Fi over SDIO. That C6 wiring is **not** Scintix-specific — it's the **standard Function-EV-Board reference layout** (slot 1: CLK 18 / CMD 19 / D0–D3 14–17, reset 54); the board file just sets it explicitly. I2C (SDA 7 / SCL 8), the MIPI LDO and the DSI bus are identical to the reference design too.

## Build and flash

You need **ESP-IDF v5.5.4** (the same toolchain as the Brookesia example).

```powershell
# 1. Get ESP-Claw
git clone https://github.com/espressif/esp-claw.git
cd esp-claw/application/edge_agent

# 2. Install the ESP Board Manager idf.py extension into the IDF Python venv
python -m pip install esp-bmgr-assist

# 3. Copy the two Scintix folders into THIS checkout (see "Installing the files"
#    below) — you build inside esp-claw, NOT in the scintix-p4 repo.

# 4. Select the board (sets the esp32p4 target automatically)
idf.py bmgr -c ./boards -b scintix_p4

# 5. Build and flash (the agent is configured at runtime — see below)
idf.py build flash monitor
```

### Installing the files (step 3)

`examples/esp_claw_agent/` is **not** a standalone IDF project — it only holds the two Scintix-specific pieces. Copy each folder into your `esp-claw/application/edge_agent` checkout, keeping these exact destinations (create `boards/reloc/` if it doesn't exist):

| From (this example) | To (in `esp-claw/application/edge_agent`) |
| ------------------- | ----------------------------------------- |
| `board/scintix_p4/` | `boards/reloc/scintix_p4/` |
| `skills/scintix_display/` | `fatfs_image/storage/skills/scintix_display/` |

### Configuring the agent

No `menuconfig` step is required — ESP-Claw is configured **at runtime**. On the first boot the C6 starts a Wi-Fi **access point** and ESP-Claw serves a **web-config** UI:

* Connect to the device's AP, then open **`http://esp-claw.local/`** (or `http://<device-ip>/`).
* Enter your **Wi-Fi** credentials and the LLM **profile / Base URL / API key / model**. These values are stored in NVS, so they persist across reboots.
* The optional **MCP server** field is the URL of an *external* MCP server whose tools the agent should use — leave it empty for a first run.

## Demo: write on the screen (agent / Claude over MCP)

The bundled [`skills/scintix_display`](skills/scintix_display) skill shows a full-screen message on the panel ([`show_text.lua`](skills/scintix_display/scripts/show_text.lua)), styled to match the agent's face screen — same dark background (`0x171617`), amber message text, shown for ~8 s before the face returns. Parameters: `text`, `font_size`, `hold_ms` (see [`SKILL.md`](skills/scintix_display/SKILL.md)).

Three ways to trigger it:

1. **On-device agent** — say it in natural language (serial console or a chat channel):
   `ask write on the screen: Hello from Claude` → the agent picks the `scintix_display` skill.
2. **Directly from the console** (no LLM):
   ```
   lua --run --path /fatfs/skills/scintix_display/scripts/show_text.lua --args-json "{\"text\":\"Hello\"}" --timeout-ms 12000
   ```
3. **From Claude over MCP.** The device advertises an MCP server (mDNS `_mcp._tcp`, host `esp-claw.local`) on **`http://esp-claw.local:18791/mcp`** (or `http://<device-ip>:18791/mcp`). Bridge Claude Desktop to it with `mcp-remote` in `claude_desktop_config.json`:
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

## Troubleshooting (gotchas we hit)

* **Black screen, but the boot log shows the display initialized and the emote assets loaded** → the `esp_lcd_ek79007` driver resolved to **1.0.x**, which lacks `disp_on_off`, so this EK79007 panel never turns on (`esp_lcd_panel_disp_on_off … not supported` in the log). This board pins the driver to **`2.0.*`** in [`board/scintix_p4/board_devices.yaml`](board/scintix_p4/board_devices.yaml). After changing it, delete `managed_components/` + `dependencies.lock` and rebuild so 2.0.x is actually fetched.
* **`idf.py bmgr` shows no options / "Execute targets that are not explicitly known"** → the `esp-bmgr-assist` package isn't installed in the **active IDF venv**. Run `python -m pip install esp-bmgr-assist` there.

## Links

* [ESP-Claw repository](https://github.com/espressif/esp-claw) · [docs](https://esp-claw.com/) · [build from source](https://esp-claw.com/en/reference-project/build-from-source/)
* [ESP Board Manager — customize a board](https://github.com/espressif/esp-gmf/blob/main/packages/esp_board_manager/docs/how_to_customize_board.md)
