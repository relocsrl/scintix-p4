-- News dashboard (generalized): agent web_search on ANY topic + geo-IP local time.
-- Topic resolution: args.topic (one-shot) > /fatfs/scripts/news_topic.txt (persisted default) > built-in AI/TECH.
-- args: { topic = "<subject>", set_default = <bool> }
--   set_default=true persists the topic as the recurring default (used by the 15-min scheduler);
--   set_default=true with empty topic resets the recurring default back to AI/TECH.
local capability = require("capability")
local system     = require("system")
local bm         = require("board_manager")
local display    = require("display")
local delay      = require("delay")

local TAG="[news_dashboard]"; local MAX_ROWS=6; local TITLE_MAX=120
local FONT=24; local DURATION_MS=30000; local FRAME_MS=25; local SPEED_PPS=130
local GAP=90; local MARGIN=40; local PAD=14
local TZ_CACHE="/fatfs/scripts/tz_cache.txt"
local TOPIC_FILE="/fatfs/scripts/news_topic.txt"

local function rgb(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
local BG,GRAY,WHITE,AMBER=rgb(0x17,0x16,0x17),rgb(120,120,128),rgb(235,235,235),rgb(255,200,100)
local function trim(s) return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
local function ascii(s) return trim(tostring(s or ""):gsub("[^\032-\126]","")) end
local function shorten(s,n) s=ascii(s); if #s<=n then return s end return s:sub(1,n-1).."-" end
local function urlencode(s) return (tostring(s):gsub("[^%w]", function(c) return string.format("%%%02X", string.byte(c)) end)) end

-- timezone (autonomous via geo-IP, cached)
local function rd_cache() local ok,f=pcall(io.open,TZ_CACHE,"r"); if not ok or not f then return nil end
  local c=f:read("*a"); f:close(); local o=c and c:match("^(-?%d+)"); local z=c and c:match("|(.+)$")
  return o and tonumber(o) or nil, z and trim(z) or nil end
local function wr_cache(o,z) local ok,f=pcall(io.open,TZ_CACHE,"w"); if ok and f then f:write(tostring(o).."|"..tostring(z or "")); f:close() end end
local function get_tz()
  local ok,o=capability.call("http_request",{url="http://ip-api.com/json/?fields=status,offset,timezone"},{source_cap="news_dashboard"})
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

-- topic resolution
local function rd_topic() local ok,f=pcall(io.open,TOPIC_FILE,"r"); if not ok or not f then return nil end
  local c=f:read("*a"); f:close(); c=c and trim(c) or ""; if c=="" then return nil end return c end
local function wr_topic(t) local ok,f=pcall(io.open,TOPIC_FILE,"w"); if ok and f then f:write(t); f:close() end end
local function sanitize_topic(t) t=ascii(t or ""); t=t:gsub('["\\]'," "); t=trim(t); if #t>60 then t=t:sub(1,60) end return t end

local A = type(args)=="table" and args or {}
local req_topic = sanitize_topic(A.topic)
if A.set_default then
  if req_topic~="" then wr_topic(req_topic) else os.remove(TOPIC_FILE) end
end
local topic = req_topic
if topic=="" then topic = rd_topic() or "" end  -- "" => built-in AI/TECH default

local DEFAULT_QUERIES={
  "latest artificial intelligence news today",
  "latest technology industry news today",
  "OpenAI Anthropic Google Meta AI announcements",
}
local queries, header, rss_url
if topic=="" then
  queries=DEFAULT_QUERIES
  header="AI / TECH NEWS"
  rss_url="https://news.google.com/rss/search?q=AI%20technology&hl=en-US&gl=US&ceid=US:en"
else
  queries={
    "latest "..topic.." news today",
    topic.." breaking news today",
    topic.." latest updates",
  }
  header=shorten(topic:upper(),40)
  rss_url="https://news.google.com/rss/search?q="..urlencode(topic).."&hl=en-US&gl=US&ceid=US:en"
end

-- headlines: mine COMPLETE sentences from web_search snippets; drop truncated tails.
-- Tavily "basic" content is prose, often cut mid-sentence -> we keep only sentences
-- that end with . ! ? OR do not end on a dangling function/word (to, one, the, with...).
local STOP={}
for w in ("a an and or but the to of in on for at by from as with about after before between into over under is are was were be been being will would can could may might shall should must have has had do does did not no than then so such up out off down this that these those it its his her their our your my we you they he she one two three four five more most new latest via amp few many some several other another each own including"):gmatch("%S+") do STOP[w]=true end
local GEN={"latest news and top stories","news coverage","read the latest","top stories on",
 "news and analysis","headlines and developments","read latest news","top stories",
 "live feed","live text coverage","standings and results","videos standings","and more",
 "behind the scenes","the home of","practice and qualifying","analysis straight",
 "latest news, videos","photos, videos","driver interviews","get analysis",
 "the main race event","news, articles","results & schedule","live text"}
local function generic(low)
  local words=0; for _ in low:gmatch("%S+") do words=words+1 end
  if words<4 or #low<22 or #low>130 then return true end
  for _,b in ipairs(GEN) do if low:find(b,1,true) then return true end end
  return false
end
-- true if the raw segment looks like a complete thought (before we strip punctuation)
local function complete(seg)
  if seg:match("[%.%!%?][%s\"'%)]*$") then return true end
  local n=0; for _ in seg:gmatch("%S+") do n=n+1 end
  if n<5 then return false end
  local lastw=seg:match("(%a[%w'%-]*)%s*$")
  if not lastw then return false end
  return not STOP[lastw:lower()]
end
-- strip provider cruft, separators, trailing date/time stamps and terminal period
local function clean(seg)
  local t=seg
  t=t:gsub("^%s*#+%s*","")                                              -- markdown heading
  t=t:gsub("^[Ii]mage%s+thumbnail%s+for%s+article%s+titled%s+","")      -- keep the real title
  t=t:gsub("^[Ii]mage%s+for%s+article%s+titled%s+","")
  t=t:gsub("^[Tt]humbnail%s+for%s+article%s+titled%s+","")
  t=t:gsub("^[Ii]mage:%s*",""):gsub("^[Pp]hoto:%s*","")
  t=t:gsub("^%a+Category%s+","")
  t=t:gsub("^%s*[%-%*%d%.%)]+%s*","")
  t=t:gsub("%s*Read more.*$","")
  t=t:gsub("%s*%d+%s+%a+%s+ago%s*$","")
  t=t:gsub("%s*Today,?%s*%d%d?:%d%d%s*$","")
  t=t:gsub("%s*[|·]%s.*$","")
  t=ascii(t)
  t=t:gsub("[%.%s]+$","")
  return t
end
-- split a content line into sentences, keeping terminal punctuation with each sentence
local function sentences(line)
  local out={}
  local marked=(line.." "):gsub("([%.%!%?])(%s)","%1\1%2")
  marked=marked:gsub("%s*;%s*","\1"):gsub("\194\183","\1")  -- also break on ';' and middot
  for raw in (marked.."\1"):gmatch("(.-)\1") do
    local p=trim(raw); if p~="" then out[#out+1]=p end
  end
  return out
end
local function from_search()
  local items,seen={},{}
  for _,q in ipairs(queries) do
    if #items>=MAX_ROWS then break end
    local ok,o=capability.call("web_search",{query=q},{source_cap="news_dashboard"})
    if ok and type(o)=="string" then
      for line in (o.."\n"):gmatch("(.-)\n") do
        if not line:find("http",1,true) and not line:match("^%s*%d+%.%s") then
          for _,seg in ipairs(sentences(line)) do
            if complete(seg) then
              local t=clean(seg); local low=t:lower()
              if not generic(low) and not seen[low] then
                seen[low]=true; items[#items+1]=shorten(t,TITLE_MAX)
                if #items>=MAX_ROWS then break end
              end
            end
          end
        end
        if #items>=MAX_ROWS then break end
      end
    end
  end
  return items
end
-- fallback: Google News RSS (only if web_search yields nothing)
local function decode(s) return (s:gsub("&amp;","&"):gsub("&#39;","'"):gsub("&#x27;","'"):gsub("&quot;",'"'):gsub("&apos;","'"):gsub("&lt;","<"):gsub("&gt;",">")) end
local function from_rss()
  local items={}
  local ok,o=capability.call("http_request",{url=rss_url,max_body_bytes=9000},{source_cap="news_dashboard"})
  if not ok or type(o)~="string" then return items end
  local n=0
  for raw in o:gmatch("<title[^>]*>(.-)</title>") do
    n=n+1
    if n>1 then
      local t=raw:gsub("<!%[CDATA%[",""):gsub("%]%]>","")
      t=decode(t):gsub("%s%-%s[^%-]+$","")
      t=shorten(t,TITLE_MAX)
      if #t>=10 and t~="Google News" then items[#items+1]=t end
      if #items>=MAX_ROWS then break end
    end
  end
  return items
end

local heads=from_search(); local src="web_search"
if #heads==0 then heads=from_rss(); src="rss(fallback)" end
if #heads==0 then heads={"No headlines available"}; src="none" end
local stamp=now_str()

-- render: fixed numbers + horizontal scrolling titles
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
  local n=#heads
  local y0,y1=58,h-52
  local step=math.floor((y1-y0)/math.max(n,1)); if step>86 then step=86 end
  local rows={}
  for i=1,n do
    local prefix=i.."."
    local pw=display.measure_text(prefix,{font_size=FONT})
    local tw,th=display.measure_text(heads[i],{font_size=FONT})
    rows[i]={prefix=prefix, pw=pw, title=heads[i], tw=tw, th=th}
  end
  local t0=system.millis()
  local frames_ok,fails,last_err=0,0,nil
  while (system.millis()-t0) < DURATION_MS do
    local off=math.floor((system.millis()-t0)*SPEED_PPS/1000)
    local fok,ferr=pcall(function()
      display.begin_frame({clear=true,color=BG}); display.clear_clip_rect()
      display.draw_text_aligned(0,12,w,28,header,{color=GRAY,font_size=20,align="center",valign="middle"})
      for i=1,n do
        local r=rows[i]; local ry=y0+(i-1)*step; local ty=ry+math.floor((step-r.th)/2)
        display.draw_text(MARGIN,ty,r.prefix,{color=AMBER,font_size=FONT})
        local tx=MARGIN+r.pw+PAD; local tavail=w-tx-MARGIN
        if r.tw<=tavail then
          display.draw_text(tx,ty,r.title,{color=WHITE,font_size=FONT})
        else
          local span=r.tw+GAP; local x=tx-(off%span)
          display.set_clip_rect(tx,ry,tavail,step)
          display.draw_text(x,ty,r.title,{color=WHITE,font_size=FONT})
          display.draw_text(x+span,ty,r.title,{color=WHITE,font_size=FONT})
          display.clear_clip_rect()
        end
      end
      display.draw_text_aligned(0,h-46,w,32,stamp,{color=AMBER,font_size=18,align="center",valign="middle"})
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
print(TAG.." topic="..(topic~="" and topic or "(default AI/TECH)").." src="..src.." n="..#heads.." @ "..stamp)
for i=1,#heads do print(i..". "..heads[i]) end
