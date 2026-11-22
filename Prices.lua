-- Farmer Joe: live prices from Auctionator scans.
-- Merges Loot.lua into the farm records, then works out per farm:
--   gold/hr  = sum(your lowest buyout x expected amount per hour) + static extras (fishing trunks)
--   thin     = main item had fewer than THIN_LISTED units listed in your latest scan
--   crashing = main item's price fell CRASH_PCT% or more over about 7 days of your scans
--   ranking  = gold/hr / difficulty, best first (farms without prices keep their listed order)
local addonName, ns = ...

local THIN_LISTED = 100
local CRASH_PCT = -40
local MIN_USUAL_DAYS = 3     -- days of history needed before "usual price" means anything
ns.SPIKE_RATIO = 1.5         -- HOT when an item sells 50%+ above its usual price

---------------------------------------------------------------- merge Loot.lua
local function Merge()
  local loot = ns.loot or {}
  for _, f in ipairs(ns.data.farms) do
    local L = loot[f.bracket .. "|" .. f.name]
    if L then
      f.loot = L
      for _, k in ipairs({ "mobLevels", "difficulty", "howTo", "notes", "classText" }) do
        if f[k] == nil then f[k] = L[k] end
      end
      if (not f.profReq or #f.profReq == 0) and L.profReq then f.profReq = L.profReq; f.profReqMode = "all" end
      if (not f.profOpt or #f.profOpt == 0) and L.profOpt then f.profOpt = L.profOpt end
      if (not f.classes or #f.classes == 0) and L.classes then f.classes = L.classes end
      if L.elite and f.notes == nil then f.notes = "Elite mobs." end
      f.map = f.map or L.map
    end
  end
end
Merge()

---------------------------------------------------------------- Auctionator access
local API = function() return Auctionator and Auctionator.API and Auctionator.API.v1 end

function ns.HasAuctionator()
  local a = API()
  return a and a.GetAuctionPriceByItemID and true or false
end

local cache = {}       -- itemID -> market table
local farmCache = {}   -- farm -> live table

function ns.InvalidatePrices()
  wipe(cache)
  wipe(farmCache)
  if ns.MarkDynamicDirty then ns.MarkDynamicDirty() end
end

local function Call(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, addonName, ...)
  if ok then return a end
end

-- Price history straight from Auctionator's database (not part of its public API, so guarded).
local function History(itemID)
  local db = Auctionator and Auctionator.Database
  if not db or not db.GetPriceHistory then return nil end
  local ok, h = pcall(db.GetPriceHistory, db, tostring(itemID))
  if ok and type(h) == "table" and #h > 0 then return h end
end

-- { price (copper), age (days), listed, change (percent over ~7 days), exact }
function ns.ItemMarket(itemID)
  if not itemID then return {} end
  local m = cache[itemID]
  if m then return m end
  m = {}
  local a = API()
  if a then
    m.price = Call(a.GetAuctionPriceByItemID, itemID)
    m.age = Call(a.GetAuctionAgeByItemID, itemID)
    m.exact = Call(a.IsAuctionDataExactByItemID, itemID)
    local h = History(itemID) -- newest first
    if h then
      local latest = h[1]
      local day = tonumber(latest.rawDay)
      m.listed = latest.available
      if day and latest.minSeen then
        -- compare with the newest scan at least 7 days older; failing that, the oldest scan if
        -- it's at least 5 days older
        local base
        for i = 2, #h do
          local d = tonumber(h[i].rawDay)
          if d and h[i].minSeen and h[i].minSeen > 0 then
            if day - d >= 7 then base = h[i]; break end
            if day - d >= 5 then base = h[i] end
          end
        end
        if base then m.change = (latest.minSeen - base.minSeen) / base.minSeen * 100 end
        -- usual price: average daily lowest price over the previous 14 days (today excluded)
        local sum, n = 0, 0
        for i = 2, #h do
          local d = tonumber(h[i].rawDay)
          if d and day - d <= 14 and h[i].minSeen and h[i].minSeen > 0 then sum = sum + h[i].minSeen; n = n + 1 end
        end
        if n >= MIN_USUAL_DAYS then
          m.usual = sum / n
          if m.price and m.usual > 0 then m.spike = m.price / m.usual end
        end
      end
    end
  end
  cache[itemID] = m
  return m
end

---------------------------------------------------------------- per-farm live values
local function Counts(f, it)
  if not it.prof then return true end
  if ns.HasProf(it.prof) then return true end
  for _, p in ipairs(f.profReq or {}) do if p:lower() == it.prof then return true end end
  return false
end
ns.LootCounts = Counts

-- Returns nil when the farm has no loot data. Otherwise:
-- { gph, priced, counted, oldest (days), newest, static, main = itemID }
function ns.LiveFarm(f)
  local L = f.loot
  if not L then return nil end
  -- the live finder also refreshes the curated farms' random-green rows; bring them up to date first
  if ns.DynamicDirty and ns.DynamicDirty() and ns.RebuildDynamic then ns.RebuildDynamic() end
  local live = farmCache[f]
  if live then return live end
  live = { priced = 0, counted = 0, static = L.staticGold }
  local gold = L.staticGold or 0
  local hasAH = ns.HasAuctionator()
  for _, it in ipairs(L.items or {}) do
    if Counts(f, it) then
      live.counted = live.counted + 1
      live.main = live.main or it.id
      local m = hasAH and ns.ItemMarket(it.id) or {}
      if m.price then
        gold = gold + m.price / 10000 * it.perHour
        live.priced = live.priced + 1
        local age = m.age or 0
        live.oldest = math.max(live.oldest or 0, age)
        live.newest = math.min(live.newest or age, age)
      end
    end
  end
  if live.priced > 0 or L.staticGold then live.gph = gold end
  farmCache[f] = live
  return live
end

function ns.FarmGPH(f)
  local live = ns.LiveFarm(f)
  return live and live.gph
end

function ns.FarmScore(f)
  local g = ns.FarmGPH(f)
  if g and f.difficulty and f.difficulty > 0 then return g / f.difficulty end
  return f.score
end

-- thin, crashing (live from your scans when there's history; otherwise the bundled flags)
function ns.FarmFlags(f)
  local fl = f.flags or {}
  local thin, crashing = (f.thin or fl.thin) and true or false, (f.crashing or fl.crashing) and true or false
  local live = ns.LiveFarm(f)
  if live and live.main and ns.HasAuctionator() then
    local m = ns.ItemMarket(live.main)
    if m.listed then thin = m.listed < THIN_LISTED end
    if m.change then crashing = m.change <= CRASH_PCT end
  end
  return thin, crashing
end

-- Items in this farm's (counted) loot that sell well above their usual price, best spike first.
function ns.FarmHotItems(f)
  local out = {}
  if not (f.loot and ns.HasAuctionator()) then return out end
  for _, it in ipairs(f.loot.items or {}) do
    if Counts(f, it) then
      local m = ns.ItemMarket(it.id)
      if m.spike and m.spike >= ns.SPIKE_RATIO then out[#out + 1] = { item = it, market = m } end
    end
  end
  table.sort(out, function(a, b) return a.market.spike > b.market.spike end)
  return out
end

-- "HOT" (an item is spiking), "LIVE" (found from your scans), or nil
function ns.FarmTag(f)
  if #ns.FarmHotItems(f) > 0 then return "HOT" end
  if f.dynamic then return "LIVE" end
end

-- Assigns f.displayRank for every farm in a bracket: score desc, unscored last (easiest first),
-- ties by the listed rank. Ranks are over the whole bracket, so filtered views keep their numbers.
function ns.RankBracket(farms)
  local sorted = {}
  for i, f in ipairs(farms) do sorted[i] = f end
  table.sort(sorted, function(a, b)
    local sa, sb = ns.FarmScore(a), ns.FarmScore(b)
    if (sa ~= nil) ~= (sb ~= nil) then return sa ~= nil end
    if sa and sb and sa ~= sb then return sa > sb end
    local da, db = a.difficulty or 99, b.difficulty or 99
    if not sa and da ~= db then return da < db end
    return (a.rank or 99) < (b.rank or 99)
  end)
  for i, f in ipairs(sorted) do f.displayRank = i end
end

---------------------------------------------------------------- scanning
ns.ahOpen = false

function ns.CanScan()
  local a = API()
  return ns.ahOpen and a and a.MultiSearchExact and true or false
end

function ns.ScanItems(ids)
  local a = API()
  if not (a and a.MultiSearchExact) then return end
  local names, seen = {}, {}
  for _, id in ipairs(ids) do
    local name = GetItemInfo and GetItemInfo(id)
    if not name then
      for _, f in ipairs(ns.data.farms) do
        for _, it in ipairs(f.loot and f.loot.items or {}) do if it.id == id then name = it.name end end
      end
    end
    if name and not seen[name] then seen[name] = true; names[#names + 1] = name end
  end
  if #names == 0 then return end
  local ok, err = pcall(a.MultiSearchExact, addonName, names)
  if ok then
    ns.Print(string.format("Auctionator is searching %d item%s. Prices update here when it finishes.", #names, #names == 1 and "" or "s"))
  else
    ns.Print("Auctionator couldn't start the search: " .. tostring(err))
  end
end

function ns.FarmItemIDs(farms)
  local ids, seen = {}, {}
  for _, f in ipairs(farms) do
    for _, it in ipairs(f.loot and f.loot.items or {}) do
      if Counts(f, it) and not seen[it.id] then seen[it.id] = true; ids[#ids + 1] = it.id end
    end
  end
  return ids
end

---------------------------------------------------------------- events
local pending = false
local function OnDBUpdate()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = false
    ns.InvalidatePrices()
    if ns.Refresh then ns.Refresh() end
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    local a = API()
    if a and a.RegisterForDBUpdate then pcall(a.RegisterForDBUpdate, addonName, OnDBUpdate) end
  elseif event == "AUCTION_HOUSE_SHOW" then
    ns.ahOpen = true
    if ns.Refresh then ns.Refresh() end
  elseif event == "AUCTION_HOUSE_CLOSED" then
    ns.ahOpen = false
    if ns.Refresh then ns.Refresh() end
  end
end)
