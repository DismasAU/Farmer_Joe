-- Farmer Joe: farming sessions.
-- While a session runs, every item you loot and every coin you pick up is recorded. Each item gets
-- a sell call: auction it when the auction price, less the house's cut (AH_CUT), still beats the
-- vendor price; otherwise vendor it. Gold per hour = (coin + what the loot sells for) / time farmed.
-- The session lives in FarmerJoeDB.session, so it survives /reload and logging out (time spent
-- offline doesn't count).
local addonName, ns = ...

ns.AH_CUT = 0.20       -- share of the auction price lost to the house
ns.GREY_AH_MIN = 50000 -- copper (5g): grey items below this auction price are always vendored
local MIN_GPH_SECS = 60 -- don't project gold/hr from less than a minute of farming

local listeners = {}
function ns.OnSessionChanged(fn) listeners[#listeners + 1] = fn end
local function Changed() for _, fn in ipairs(listeners) do pcall(fn) end end
ns.SessionChanged = Changed

local function Now() return time() end
function ns.Session() return FarmerJoeDB and FarmerJoeDB.session end

function ns.SessionState(s)
  s = s or ns.Session()
  if not s then return nil end
  if s.stoppedAt then return "finished" end
  if s.pausedAt then return "paused" end
  return "running"
end

-- Seconds farmed (paused and offline time excluded).
function ns.SessionElapsed(s)
  s = s or ns.Session()
  if not s then return 0 end
  local stop = s.stoppedAt or s.pausedAt or Now()
  return math.max(0, stop - s.started - (s.pausedTotal or 0))
end

---------------------------------------------------------------- sell advice
-- Returns { action = "auction" | "vendor" | "keep" | "pending", value (copper each), vendor, ah, net, why }
function ns.LootAdvice(id)
  local name, _, quality, _, _, _, _, _, _, _, sell, classID, _, bind = GetItemInfo(id)
  local a = { vendor = sell or 0, quality = quality, name = name }
  if not name then a.action, a.value, a.why = "pending", 0, "Waiting for item info from the server."; return a end
  local bound = bind == 1 or bind == 4
  local quest = classID == 12
  if not bound and not quest and ns.HasAuctionator() then a.ah = ns.ItemMarket(id).price end
  if a.ah then a.net = math.floor(a.ah * (1 - ns.AH_CUT)) end
  -- grey items rarely sell: vendor trash unless the auction price is well above GREY_AH_MIN
  local greyTrash = quality == 0 and a.ah and a.ah < ns.GREY_AH_MIN

  if a.net and a.net > a.vendor and not greyTrash then
    a.action, a.value = "auction", a.net
    a.why = a.vendor > 0
      and string.format("Auction: it still beats the vendor by %d%% after the %d%% cut.", (a.net / a.vendor - 1) * 100, ns.AH_CUT * 100)
      or "Auction: vendors won't buy it."
  elseif a.vendor > 0 then
    a.action, a.value = "vendor", a.vendor
    if bound then a.why = "Vendor: it's soulbound, so it can't be auctioned."
    elseif quality == 0 then a.why = string.format("Vendor: grey items rarely sell at auction unless they're listed at %s or more.", ns.FormatGold(ns.GREY_AH_MIN / 10000))
    elseif a.ah then a.why = string.format("Vendor: after the %d%% cut the auction house pays less.", ns.AH_CUT * 100)
    elseif ns.HasAuctionator() then a.why = "Vendor: no auction price in your Auctionator scans."
    else a.why = "Vendor: Auctionator isn't loaded, so there's no auction price." end
  else
    a.action, a.value = "keep", 0
    a.why = quest and "Keep: quest item." or "Keep: no vendor or auction price."
  end
  return a
end

-- { coin, vendor, auction, total (copper), items (count), gph (copper/hr or nil), elapsed, rows }
-- rows: { id, count, advice, value (total copper) } sorted by value, best first
function ns.SessionTotals(s)
  s = s or ns.Session()
  local t = { coin = 0, vendor = 0, auction = 0, total = 0, items = 0, rows = {}, elapsed = 0 }
  if not s then return t end
  t.coin = s.copper or 0
  for id, n in pairs(s.items) do
    local adv = ns.LootAdvice(id)
    local v = adv.value * n
    if adv.action == "auction" then t.auction = t.auction + v elseif adv.action == "vendor" then t.vendor = t.vendor + v end
    t.items = t.items + n
    t.rows[#t.rows + 1] = { id = id, count = n, advice = adv, value = v, seen = s.seen and s.seen[id] or 0 }
  end
  table.sort(t.rows, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.seen < b.seen
  end)
  t.total = t.coin + t.vendor + t.auction
  t.elapsed = ns.SessionElapsed(s)
  if t.elapsed >= MIN_GPH_SECS then t.gph = t.total / (t.elapsed / 3600) end
  return t
end

---------------------------------------------------------------- control
-- Farm's expected gold/hr (gold, float) for comparison, from live prices or the bundled range.
local function FarmEstimate(f)
  if not f then return nil end
  local live = ns.FarmGPH and ns.FarmGPH(f)
  if live then return live end
  if f.gphLow and f.gphHigh then return (f.gphLow + f.gphHigh) / 2 end
  return f.gphHigh or f.gphLow
end

function ns.StartSession(farm)
  FarmerJoeDB.session = {
    started = Now(), pausedTotal = 0, copper = 0, items = {}, seen = {}, nseen = 0,
    farm = farm and farm.name, zone = farm and farm.zone, bracket = farm and farm.bracket,
    estimate = FarmEstimate(farm),
  }
  ns.Print(farm and ("Session started: " .. farm.name .. ". Loot away.") or "Session started. Loot away.")
  Changed()
  if ns.ShowSessionWindow then ns.ShowSessionWindow() end
end

function ns.PauseSession()
  local s = ns.Session()
  if ns.SessionState(s) ~= "running" then return end
  s.pausedAt = Now()
  Changed()
end

function ns.ResumeSession()
  local s = ns.Session()
  if ns.SessionState(s) ~= "paused" then return end
  s.pausedTotal = (s.pausedTotal or 0) + (Now() - s.pausedAt)
  s.pausedAt, s.autoPaused = nil, nil
  Changed()
end

local function Duration(secs)
  local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
  if h > 0 then return string.format("%dh %02dm", h, m) end
  return string.format("%dm %02ds", m, secs % 60)
end
ns.FormatDuration = Duration

local function Gold(copper) return ns.FormatGold(copper / 10000) or "0c" end

function ns.StopSession()
  local s = ns.Session()
  if not s or s.stoppedAt then return end
  if s.pausedAt then s.pausedTotal = (s.pausedTotal or 0) + (Now() - s.pausedAt); s.pausedAt = nil end
  s.stoppedAt, s.autoPaused = Now(), nil
  local t = ns.SessionTotals(s)
  ns.Print(string.format("Session over after %s: %s in total (%s coin, %s to vendor, %s from the auction house)%s.",
    Duration(t.elapsed), Gold(t.total), Gold(t.coin), Gold(t.vendor), Gold(t.auction),
    t.gph and (", " .. Gold(t.gph) .. " per hour") or ""))
  Changed()
end

function ns.ClearSession()
  FarmerJoeDB.session = nil
  Changed()
end

---------------------------------------------------------------- loot tracking
-- Turns a GlobalStrings format ("You receive loot: %sx%d.") into an anchored Lua pattern.
local function ToPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  fmt = fmt:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
  fmt = fmt:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  fmt = fmt:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
  return "^" .. fmt .. "$"
end
ns.ToPattern = ToPattern

local LOOT_MULTI = ToPattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")
local LOOT_ONE = ToPattern(LOOT_ITEM_SELF or "You receive loot: %s.")
local MONEY_PATS = { ToPattern(YOU_LOOT_MONEY or "You loot %s"), ToPattern(LOOT_MONEY_SPLIT or "Your share of the loot is %s.") }
local function CoinPat(fmt, word) return ((fmt or ("%d " .. word)):gsub("%%d", "(%%d+)")) end
local GOLD_PAT, SILVER_PAT, COPPER_PAT = CoinPat(GOLD_AMOUNT, "Gold"), CoinPat(SILVER_AMOUNT, "Silver"), CoinPat(COPPER_AMOUNT, "Copper")

local function ParseMoney(text)
  local g, s, c = text:match(GOLD_PAT), text:match(SILVER_PAT), text:match(COPPER_PAT)
  return (tonumber(g) or 0) * 10000 + (tonumber(s) or 0) * 100 + (tonumber(c) or 0)
end

function ns.SessionOnLoot(msg)
  local s = ns.Session()
  if ns.SessionState(s) ~= "running" then return end
  local link, n = msg:match(LOOT_MULTI)
  if not link then link = msg:match(LOOT_ONE); n = 1 end
  local id = link and tonumber(link:match("item:(%d+)"))
  if not id then return end
  s.items[id] = (s.items[id] or 0) + (tonumber(n) or 1)
  if not s.seen[id] then s.nseen = (s.nseen or 0) + 1; s.seen[id] = s.nseen end
  s.last, s.lastAt = id, Now()
  Changed()
end

function ns.SessionOnMoney(msg)
  local s = ns.Session()
  if ns.SessionState(s) ~= "running" then return end
  for _, p in ipairs(MONEY_PATS) do
    local amount = p and msg:match(p)
    if amount then
      local c = ParseMoney(amount)
      if c > 0 then s.copper = (s.copper or 0) + c; Changed() end
      return
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("CHAT_MSG_MONEY")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event, msg)
  if event == "CHAT_MSG_LOOT" then
    ns.SessionOnLoot(msg or "")
  elseif event == "CHAT_MSG_MONEY" then
    ns.SessionOnMoney(msg or "")
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if ns.Session() then Changed() end
  elseif event == "PLAYER_LOGOUT" then
    -- logging out or reloading: stop the clock; it starts again when you're back
    local s = ns.Session()
    if ns.SessionState(s) == "running" then s.pausedAt = Now(); s.autoPaused = true end
  elseif event == "PLAYER_LOGIN" then
    local s = ns.Session()
    if s and s.autoPaused and s.pausedAt then
      s.pausedTotal = (s.pausedTotal or 0) + (Now() - s.pausedAt)
      s.pausedAt, s.autoPaused = nil, nil
    end
    if ns.SessionState(s) and ns.SessionState(s) ~= "finished" and FarmerJoeDB.sessionShown ~= false
        and ns.ShowSessionWindow then
      ns.ShowSessionWindow()
    end
  end
end)
