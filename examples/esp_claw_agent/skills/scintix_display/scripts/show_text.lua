-- --------------------------------------------------------------
-- Full-screen message on the Scintix P4 LCD, styled to match the ESP-Claw
-- idle screen (same dark background) so the transition isn't jarring.
-- Invoked via the scintix_display skill (lua_run_script) or directly:
--   lua --run --path /fatfs/skills/scintix_display/scripts/show_text.lua \
--       --args-json "{\"text\":\"Hello\"}"
-- --------------------------------------------------------------

local bm = require("board_manager")
local display = require("display")
local delay = require("delay")

local TAG = "[scintix_display]"

local function rgb(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 255 }
end

-- Match the emote screen so it looks like the same UI, not a different one.
local EMOTE_BG = rgb(0x17, 0x16, 0x17)   -- CONFIG_EMOTE_DEF_BG_COLOR

local text = "Hello from Scintix P4"
local font_size = 24   -- the display module's only built-in bitmap font size
local hold_ms = 8000   -- how long the overlay stays before the face returns
if type(args) == "table" then
    if type(args.text) == "string" and #args.text > 0 then
        text = args.text
    end
    if type(args.font_size) == "number" then
        font_size = math.floor(args.font_size)
    end
    if type(args.hold_ms) == "number" then
        hold_ms = math.floor(args.hold_ms)
    end
end
if font_size < 8 then font_size = 8 elseif font_size > 96 then font_size = 96 end
if hold_ms < 0 then hold_ms = 0 elseif hold_ms > 30000 then hold_ms = 30000 end

local panel_handle, io_handle, width, height, panel_if = bm.get_display_lcd_params("display_lcd")
if not panel_handle then
    print(TAG .. " ERROR: get_display_lcd_params(display_lcd) failed: " .. tostring(io_handle))
    error("display_lcd not available")
end

local ok_init, init_err = pcall(display.init, panel_handle, io_handle, width, height, panel_if)
if not ok_init then
    print(TAG .. " ERROR: display.init failed: " .. tostring(init_err))
    error(init_err)
end

width = display.width
height = display.height

local run_ok, run_err = xpcall(function()
    display.begin_frame({ clear = true, color = EMOTE_BG })

    -- Subtle header in the emote's muted palette (no jarring colored bar).
    display.draw_text_aligned(0, 22, width, 24, "ESP-Claw", {
        color = rgb(120, 120, 128),
        font_size = 16,
        align = "center",
        valign = "middle",
    })

    -- The message, centered, in a warm amber accent (distinct from the white UI font).
    display.draw_text_aligned(24, 0, width - 48, height, text, {
        color = rgb(255, 200, 100),
        font_size = font_size,
        align = "center",
        valign = "middle",
    })

    display.present()
    display.end_frame()

    if hold_ms > 0 then
        delay.delay_ms(hold_ms)
    end
end, debug.traceback)

pcall(display.deinit)

if not run_ok then
    print(TAG .. " ERROR: " .. tostring(run_err))
    error(run_err)
end

print(TAG .. " shown: " .. text)
