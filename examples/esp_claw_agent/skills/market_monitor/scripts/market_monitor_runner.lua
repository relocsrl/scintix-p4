-- market_monitor_runner.lua
-- Monitor ANY Yahoo Finance symbol on the device display, with a threshold alert
-- and an edge-triggered chat notification.
--
-- Data source: Yahoo Finance v8 chart API (small, clean JSON):
--   https://query1.finance.yahoo.com/v8/finance/chart/<SYMBOL>?interval=1d&range=1d
-- Works for commodities (BZ=F, GC=F), equities (AAPL), indices (^GSPC),
-- crypto (BTC-USD) and FX (EURUSD=X) alike -- the symbol is just interpolated.
--
-- args:
--   symbol      = <yahoo symbol>   (default: persisted, else BZ=F / Brent)
--   label       = <title override> (default: friendly name, else Yahoo shortName, else the symbol)
--   high, low   = <numbers>        absolute price levels for the alert band
--   set_default = <bool>           persist symbol/high/low for the scheduled run
--
-- Alert: screen colour + blink when the price crosses a threshold (red above
-- high, blue below low, green within range). The daily change is always shown
-- (green up / red down). Push notifications fire only on state CHANGES, and only
-- for the scheduled/default run (no explicit symbol/high/low args).
local capability = require("capability")
local system     = require("system")
local bm         = require("board_manager")
local display    = require("display")
local delay      = require("delay")

local TAG="[market_monitor]"
local DURATION_MS=20000; local FRAME_MS=25; local BLINK_MS=450
local TZ_CACHE="/fatfs/scripts/tz_cache.txt"
local STATE_FILE="/fatfs/scripts/market_state.txt"     -- persisted config: symbol|high|low
local NOTIFY_FILE="/fatfs/scripts/market_notify.txt"   -- push target + edge state: channel|chat_id|last_state
-- pre-generalisation filenames, migrated on first run
local LEGACY_STATE="/fatfs/scripts/oil_state.txt"
local LEGACY_NOTIFY="/fatfs/scripts/oil_notify.txt"

local DEFAULT_SYM="BZ=F"        -- Brent: the European crude benchmark
local DEFAULT_HIGH,DEFAULT_LOW=80.0,65.0

-- Friendly display names. Unknown symbols fall back to the Yahoo shortName and
-- finally to the raw symbol, so ANY symbol still renders sensibly.
local SYM_NAMES={
  ["BZ=F"]="BRENT CRUDE OIL", ["CL=F"]="WTI CRUDE OIL",
  ["GC=F"]="GOLD",            ["SI=F"]="SILVER",
  ["NG=F"]="NATURAL GAS",     ["HG=F"]="COPPER",
  ["BTC-USD"]="BITCOIN",      ["ETH-USD"]="ETHEREUM",
  ["EURUSD=X"]="EUR / USD",   ["GBPUSD=X"]="GBP / USD",
  ["^GSPC"]="S&P 500",        ["^IXIC"]="NASDAQ COMPOSITE",
  ["^DJI"]="DOW JONES",       ["FTSEMIB.MI"]="FTSE MIB",
  ["AAPL"]="APPLE",           ["MSFT"]="MICROSOFT",
  ["NVDA"]="NVIDIA",          ["TSLA"]="TESLA",
  ["GOOGL"]="ALPHABET",       ["AMZN"]="AMAZON",
}

local function rgb(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
local BG=rgb(0x12,0x14,0x18)
local GRAY=rgb(140,145,155)
local WHITE=rgb(235,238,242)
local GREEN=rgb(70,215,130)
local RED=rgb(255,80,72)
local BLUE=rgb(90,180,255)
local function trim(s) return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
local function ascii(s) return trim(tostring(s or ""):gsub("[^\032-\126]","")) end

-- Decimals scale with magnitude: FX needs 4, oil/equities 2, indices/crypto 0.
local function decs(v)
  if type(v)~="number" then return 2 end
  local a=math.abs(v)
  if a<10 then return 4 elseif a<2000 then return 2 else return 0 end
end
local function fmt(v,d) return string.format("%."..tostring(d).."f", v) end

-- timezone (autonomous via geo-IP, cached) -- shared with the news dashboard
local function rd_cache() local ok,f=pcall(io.open,TZ_CACHE,"r"); if not ok or not f then return nil end
  local c=f:read("*a"); f:close(); local o=c and c:match("^(-?%d+)"); local z=c and c:match("|(.+)$")
  return o and tonumber(o) or nil, z and trim(z) or nil end
local function wr_cache(o,z) local ok,f=pcall(io.open,TZ_CACHE,"w"); if ok and f then f:write(tostring(o).."|"..tostring(z or "")); f:close() end end
local function get_tz()
  local ok,o=capability.call("http_request",{url="http://ip-api.com/json/?fields=status,offset,timezone"},{source_cap="market_monitor"})
  if ok and type(o)=="string" then local off=o:match('"offset"%s*:%s*(-?%d+)'); local tz=o:match('"timezone"%s*:%s*"([^"]+)"')
    if off then wr_cache(tonumber(off),tz); return tonumber(off),tz end end
  return rd_cache()
end
local function now_str()
  local off,tz=get_tz(); local u=os.time()
  -- SNTP can take ~20 s after boot; until it lands the clock reads as the
  -- epoch, so say so instead of putting "1970-01-01" on the screen.
  if type(u)~="number" or u < 1600000000 then return "clock not synced yet" end
  if off then return os.date("!%Y-%m-%d %H:%M", u+off)..(tz and ("  "..tz) or "") end
  return os.date("!%Y-%m-%d %H:%M", u).."  UTC"
end

-- persisted state (symbol|high|low), reused by the scheduled run (args empty)
local function parse_state(c)
  c=c or ""
  local sym=c:match("^([^|]*)"); if sym=="" then sym=nil end
  return sym, tonumber(c:match("^[^|]*|([^|]*)")), tonumber(c:match("|([^|]*)$"))
end
local function wr_state(sym,hi,lo) local ok,f=pcall(io.open,STATE_FILE,"w"); if ok and f then
  f:write((sym or "").."|"..(hi and tostring(hi) or "").."|"..(lo and tostring(lo) or "")); f:close() end end
local function rd_state()
  local ok,f=pcall(io.open,STATE_FILE,"r")
  if ok and f then local c=f:read("*a"); f:close(); return parse_state(c) end
  -- migrate from the pre-generalisation file, once
  local ok2,f2=pcall(io.open,LEGACY_STATE,"r")
  if ok2 and f2 then
    local c=f2:read("*a"); f2:close()
    local s,h,l=parse_state(c)
    wr_state(s,h,l)
    print(TAG.." migrated state from "..LEGACY_STATE)
    return s,h,l
  end
  return nil,nil,nil
end

-- push notification target (edge-triggered) -- channel|chat_id|last_state
local function parse_notify(c)
  c=c or ""
  local ch=c:match("^([^|]*)"); local id=c:match("^[^|]*|([^|]*)"); local ls=c:match("|([^|]*)$")
  if ch=="" then ch=nil end; if id=="" then id=nil end
  return ch,id,ls
end
local function wr_notify(ch,id,ls) local ok,f=pcall(io.open,NOTIFY_FILE,"w"); if ok and f then
  f:write((ch or "").."|"..(id or "").."|"..(ls or "")); f:close() end end
local function rd_notify()
  local ok,f=pcall(io.open,NOTIFY_FILE,"r")
  if ok and f then local c=f:read("*a"); f:close(); return parse_notify(c) end
  local ok2,f2=pcall(io.open,LEGACY_NOTIFY,"r")
  if ok2 and f2 then
    local c=f2:read("*a"); f2:close()
    local ch,id,ls=parse_notify(c)
    if id then wr_notify(ch,id,ls); print(TAG.." migrated notify target from "..LEGACY_NOTIFY) end
    return ch,id,ls
  end
  return nil,nil,nil
end

local A=type(args)=="table" and args or {}
-- only the scheduled/default run (no explicit config args) drives push notifications
local DO_NOTIFY=(A.high==nil and A.low==nil and A.symbol==nil)
local psym,phi,plo=rd_state()
local SYM=(A.symbol and trim(tostring(A.symbol))~="" and trim(tostring(A.symbol))) or psym or DEFAULT_SYM
local HIGH=tonumber(A.high); if HIGH==nil then HIGH=phi end
local LOW=tonumber(A.low);   if LOW==nil then LOW=plo end
if HIGH==nil and LOW==nil then HIGH,LOW=DEFAULT_HIGH,DEFAULT_LOW end
if A.set_default then wr_state(SYM,HIGH,LOW) end

-- fetch the quote from the Yahoo v8 chart API
local price, prev, cur, name
do
  local url="https://query1.finance.yahoo.com/v8/finance/chart/"..SYM.."?interval=1d&range=1d"
  local ok,o=capability.call("http_request",{url=url,max_body_bytes=3000,headers={["User-Agent"]="Mozilla/5.0"}},{source_cap="market_monitor"})
  if ok and type(o)=="string" then
    price=tonumber(o:match('"regularMarketPrice":%s*([%d%.]+)'))
    prev =tonumber(o:match('"chartPreviousClose":%s*([%d%.]+)') or o:match('"previousClose":%s*([%d%.]+)'))
    cur  =o:match('"currency":"(%u+)"')
    name =o:match('"shortName":"([^"]+)"')
  end
end
local LABEL=ascii(A.label and A.label~="" and A.label or SYM_NAMES[SYM] or name or SYM)
if #LABEL>30 then LABEL=LABEL:sub(1,30) end
local unit=(cur=="USD" or cur==nil) and "$" or (cur.." ")
local D=decs(price)

-- day change
local chg, chgpct
if price and prev and prev>0 then chg=price-prev; chgpct=chg/prev*100 end

-- state (threshold alert)
local state, scolor, banner
if price==nil then
  state="NODATA"; scolor=GRAY; banner="PRICE UNAVAILABLE"
elseif HIGH and price>=HIGH then
  state="HIGH"; scolor=RED; banner="ALERT  ABOVE "..fmt(HIGH,decs(HIGH))
elseif LOW and price<=LOW then
  state="LOW"; scolor=BLUE; banner="ALERT  BELOW "..fmt(LOW,decs(LOW))
else
  state="OK"; scolor=GREEN; banner="WITHIN RANGE"
end
local alert=(state=="HIGH" or state=="LOW")
local pstr = price and (unit..fmt(price,D)) or "--.--"
local chgstr = "--"
local chgcol = GRAY
if chg then
  local arrow = chg>=0 and "+" or "-"
  -- indices/crypto print the price with no decimals, but the daily change still
  -- deserves two, otherwise a +1.20 move renders as "+1"
  local CD = (D > 0) and D or 2
  chgstr = string.format("%s%s  (%s%.2f%%)", arrow, fmt(math.abs(chg),CD), arrow, math.abs(chgpct))
  chgcol = chg>=0 and GREEN or RED
end
local bandstr = string.format("alert range   %s  -  %s",
  LOW and fmt(LOW,decs(LOW)) or "--", HIGH and fmt(HIGH,decs(HIGH)) or "--")
local stamp=now_str()

-- proactive push notification (edge-triggered: only when the alert state changes)
if DO_NOTIFY then
  local nch,nid,last=rd_notify()
  if nid and nid~="" and state~="NODATA" then
    if state~=last and (state=="HIGH" or state=="LOW" or last=="HIGH" or last=="LOW") then
      local msg
      if state=="HIGH" then msg="ALERT  "..LABEL.." "..pstr.." ABOVE "..fmt(HIGH,decs(HIGH)).."   ("..chgstr..")"
      elseif state=="LOW" then msg="ALERT  "..LABEL.." "..pstr.." BELOW "..fmt(LOW,decs(LOW)).."   ("..chgstr..")"
      else msg=LABEL.." "..pstr.." back within range "..bandstr:gsub("^alert range%s+","") end
      if nch=="telegram" then capability.call("tg_send_message",{chat_id=nid,message=msg},{source_cap="market_monitor"})
      else capability.call("local_send_message",{channel=(nch or "local"),chat_id=nid,message=msg},{source_cap="market_monitor"}) end
      print(TAG.." NOTIFY "..(nch or "?").." "..nid.." :: "..msg)
    end
    if state~=last then wr_notify(nch,nid,state) end
  end
end

-- render
local panel,io_h,w,h,pif=bm.get_display_lcd_params("display_lcd")
if not panel then error("display_lcd not available: "..tostring(io_h)) end
-- display.init can fail transiently when another script has just released the
-- screen (back-to-back runs); give it a couple of retries before giving up.
local init_ok=false
for attempt=1,3 do
  init_ok=pcall(display.init,panel,io_h,w,h,pif)
  if init_ok then break end
  delay.delay_ms(300)
end
if not init_ok then error("display.init failed after retries") end
w,h=display.width,display.height
local run_ok,run_err=xpcall(function()
  -- shrink the price font until it fits (crypto/indices are much wider than oil)
  local PFONT=140
  local pw,ph=display.measure_text(pstr,{font_size=PFONT})
  while pw > (w-80) and PFONT > 60 do
    PFONT=PFONT-10
    pw,ph=display.measure_text(pstr,{font_size=PFONT})
  end
  local py=math.floor(h*0.30)
  local t0=system.millis()
  local frames_ok,fails,last_err=0,0,nil
  while (system.millis()-t0) < DURATION_MS do
    local el=system.millis()-t0
    local phase=(alert and (math.floor(el/BLINK_MS)%2==1)) and true or false
    local bg = phase and rgb(math.floor(scolor.r*0.30),math.floor(scolor.g*0.30),math.floor(scolor.b*0.30)) or BG
    local num_col = phase and WHITE or (alert and scolor or WHITE)
    local fok,ferr=pcall(function()
      display.begin_frame({clear=true,color=bg}); display.clear_clip_rect()
      display.draw_text_aligned(0,30,w,32,LABEL,{color=GRAY,font_size=28,align="center",valign="middle"})
      display.draw_text_aligned(0,py,w,ph,pstr,{color=num_col,font_size=PFONT,align="center",valign="middle"})
      display.draw_text_aligned(0,py+ph+4,w,44,chgstr,{color=chgcol,font_size=38,align="center",valign="middle"})
      display.draw_text_aligned(0,py+ph+56,w,44,banner,{color=scolor,font_size=34,align="center",valign="middle"})
      display.draw_text_aligned(0,h-92,w,30,bandstr,{color=GRAY,font_size=24,align="center",valign="middle"})
      display.draw_text_aligned(0,h-52,w,30,stamp,{color=GRAY,font_size=22,align="center",valign="middle"})
      display.present(); display.end_frame()
    end)
    if fok then
      frames_ok=frames_ok+1; fails=0
      delay.delay_ms(FRAME_MS)
    else
      -- The display service can still own the panel (system UI handing over,
      -- or another script just released it): begin_frame then fails with
      -- ESP_ERR_INVALID_STATE. Close any half-open frame, back off, retry.
      last_err=ferr; fails=fails+1
      pcall(display.end_frame)
      if fails > 40 then error(ferr) end
      delay.delay_ms(100)
    end
  end
  -- Never report success without having drawn: an all-failed loop would
  -- otherwise look like a clean run that simply showed nothing.
  if frames_ok == 0 then error(last_err or "no frame rendered") end
end,debug.traceback)
pcall(display.deinit)
if not run_ok then error(run_err) end
print(TAG.." sym="..SYM.." label="..LABEL.." shown="..pstr.." ("..chgstr..")"
  .." prev="..tostring(prev).." state="..state
  .." high="..tostring(HIGH).." low="..tostring(LOW).." @ "..stamp)
