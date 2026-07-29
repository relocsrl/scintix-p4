-- market_watch_set.lua
-- Opt in/out of market price push alerts for the calling chat, and optionally set
-- the monitored symbol and thresholds in one go. Invoked by a router rule on
-- "/watchprice ..." with args {channel, chat_id, spec} where spec="{{match.remainder}}".
--
-- spec forms:
--   ""                      -> enable alerts on this chat, keep current config
--   "off"                   -> disable alerts
--   "85 70"                 -> enable + set high=85, low=70
--   "GC=F 2700 2400"        -> enable + set symbol and thresholds
--   "bitcoin 100000 80000"  -> aliases are accepted for common symbols
local A=type(args)=="table" and args or {}
local channel=tostring(A.channel or "")
local chat=tostring(A.chat_id or "")
local spec=tostring(A.spec or "")
local STATE="/fatfs/scripts/market_state.txt"
local NOTIFY="/fatfs/scripts/market_notify.txt"
local LEGACY_STATE="/fatfs/scripts/oil_state.txt"
local function trim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
spec=trim(spec)

if chat=="" then print("watchprice: missing chat_id"); return end

if spec:lower()=="off" then
  os.remove(NOTIFY)
  os.remove("/fatfs/scripts/oil_notify.txt")  -- also clear the pre-generalisation target
  print("watchprice: alerts OFF for "..channel.."/"..chat)
  return
end

-- Plain-word aliases so the command is usable without knowing Yahoo tickers.
local ALIAS={
  brent="BZ=F", petrolio="BZ=F", oil="BZ=F", wti="CL=F",
  oro="GC=F", gold="GC=F", argento="SI=F", silver="SI=F",
  gas="NG=F", rame="HG=F", copper="HG=F",
  bitcoin="BTC-USD", btc="BTC-USD", ethereum="ETH-USD", eth="ETH-USD",
  eurusd="EURUSD=X", eurodollaro="EURUSD=X",
  sp500="^GSPC", nasdaq="^IXIC", dowjones="^DJI", ftsemib="FTSEMIB.MI",
  apple="AAPL", microsoft="MSFT", nvidia="NVDA", tesla="TSLA",
  alphabet="GOOGL", google="GOOGL", amazon="AMZN",
}

local toks={}
for w in spec:gmatch("%S+") do toks[#toks+1]=w end
local i=1; local sym,hi,lo
if toks[i] and not tonumber(toks[i]) then
  local raw=toks[i]
  sym=ALIAS[raw:lower()] or raw:upper()
  i=i+1
end
hi=tonumber(toks[i]); lo=tonumber(toks[i+1])

if sym or hi or lo then
  local function rd()
    local function parse(c)
      c=c or ""
      local s=c:match("^([^|]*)"); if s=="" then s=nil end
      return s, tonumber(c:match("^[^|]*|([^|]*)")), tonumber(c:match("|([^|]*)$"))
    end
    local ok,f=pcall(io.open,STATE,"r")
    if ok and f then local c=f:read("*a"); f:close(); return parse(c) end
    local ok2,f2=pcall(io.open,LEGACY_STATE,"r")
    if ok2 and f2 then local c=f2:read("*a"); f2:close(); return parse(c) end
    return nil,nil,nil
  end
  local cs,chh,cll=rd()
  sym=sym or cs; hi=hi or chh; lo=lo or cll
  local f=io.open(STATE,"w")
  if f then f:write((sym or "").."|"..(hi and tostring(hi) or "").."|"..(lo and tostring(lo) or "")); f:close() end
end

-- enable alerts for this chat; reset the edge state ("") so the next threshold cross notifies
local f=io.open(NOTIFY,"w")
if f then f:write(channel.."|"..chat.."|"); f:close() end
print("watchprice: alerts ON for "..channel.."/"..chat
  .." sym="..tostring(sym).." hi="..tostring(hi).." lo="..tostring(lo))
