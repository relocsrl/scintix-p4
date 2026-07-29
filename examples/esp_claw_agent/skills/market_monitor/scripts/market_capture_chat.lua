-- market_capture_chat.lua
-- Remembers the chat the user talks from, so threshold alerts have somewhere to go
-- even when the user set the thresholds through the agent instead of /watchprice.
-- Invoked by a NON-consuming router rule on any inbound text message, with
-- args {channel, chat_id}. Only ever creates the target -- never overwrites an
-- existing one, so an explicit "/watchprice off" stays off until re-enabled.
local A=type(args)=="table" and args or {}
local ch=tostring(A.channel or "")
local id=tostring(A.chat_id or "")
if ch=="" or id=="" then return end

local NOTIFY="/fatfs/scripts/market_notify.txt"
local LEGACY_NOTIFY="/fatfs/scripts/oil_notify.txt"

-- already configured (either file) -> leave the existing edge state alone
local f=io.open(NOTIFY,"r"); if f then f:close(); return end
local lf=io.open(LEGACY_NOTIFY,"r"); if lf then lf:close(); return end

local w=io.open(NOTIFY,"w")
if w then
  w:write(ch.."|"..id.."|")
  w:close()
  print("market_capture_chat: alert target set to "..ch.."/"..id)
end
