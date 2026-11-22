-- Farmer Joe: live farm finder.
-- Prices every item in DropIndex.lua from your Auctionator scans, adds up what each mob's drops
-- are worth per kill, and lists the most profitable mobs in each bracket as extra farms. Because it
-- works from your latest scans, the list changes as prices move. Farms with an item selling well
-- above its usual price are tagged HOT.
local addonName, ns = ...

local MIN_PRICE = 300        -- copper; cheaper items are ignored
local MIN_GPH = 2            -- gold per hour for a mob to be listed
local PER_BRACKET = 5        -- best mobs listed per bracket
local EXTRA_HOT = 3          -- further mobs listed when they drop a spiking item
local KPH_NORMAL, KPH_ELITE = 80, 40 -- only when DropIndex.lua has no kill rate for the mob
-- Random world-drop greens share one roll per kill. About 2 in 100 kills give one, at least away
-- from dungeons (players report 1-3 an hour at ~100 kills); priced at the median auction price
-- of the greens that mobs of the same level drop.
local WORLD_GREEN_CHANCE = 0.02
ns.WORLD_GREEN_CHANCE = WORLD_GREEN_CHANCE

local byBracket = {}         -- bracket label -> { farm, ... }
local byKey = {}             -- "bracket|mob" -> farm (kept so selection survives a rebuild)
local dirty = true

function ns.MarkDynamicDirty() dirty = true end
function ns.DynamicDirty() return dirty end

local function GreenBracket(minL, maxL) return math.min(12, math.max(1, math.floor(((minL + maxL) / 2 - 1) / 5) + 1)) end

-- The random-green row for a farm: one shared roll per kill (see WORLD_GREEN_CHANCE).
local function GreenRow(kph, green)
  return { id = green.id, name = "Random green (any BoE)", quality = 2, chance = WORLD_GREEN_CHANCE * 100,
    perHour = kph * WORLD_GREEN_CHANCE, src = "est", value = WORLD_GREEN_CHANCE * green.price, pool = true }
end

-- Give the curated mob farms the same row (replacing last rebuild's), so they compare fairly.
local function AddGreensToCurated(greenByBracket)
  for _, f in ipairs(ns.data.farms) do
    local L = f.loot
    if L and L.items and L.kph and L.mobs and #L.mobs > 0 and not L.dynamic then
      for i = #L.items, 1, -1 do if L.items[i].pool then table.remove(L.items, i) end end
      local lo, hi = (f.mobLevels or ""):match("^(%d+)%-?(%d*)$")
      lo = tonumber(lo); hi = tonumber(hi) or lo
      if not lo then
        local b1, b2 = (f.bracket or ""):match("^(%d+)%-(%d+)$")
        lo, hi = tonumber(b1), tonumber(b2)
      end
      local green = lo and greenByBracket[GreenBracket(lo, hi)]
      if green then L.items[#L.items + 1] = GreenRow(L.kph, green) end
    end
  end
end

local function Plural(name)
  if name:find("s$") or name:find("[Mm]en$") then return name end
  if name:find("[^aeiou]y$") then return name:sub(1, -2) .. "ies" end
  if name:find("f$") then return name:sub(1, -2) .. "ves" end
  return name .. "s"
end
ns.Plural = Plural

local function Covered()
  local covered = {}
  for _, f in ipairs(ns.data.farms) do
    if f.loot and f.loot.mobs then
      covered[f.bracket] = covered[f.bracket] or {}
      for _, m in ipairs(f.loot.mobs) do covered[f.bracket][m] = true end
    end
  end
  return covered
end

local function BuildFarm(bracket, c)
  local n = c.n
  local name, minL, maxL, elite, zone, x, y = n[1], n[2], n[3], n[4] == 1, n[5], n[6], n[7]
  local key = bracket .. "|" .. name
  local f = byKey[key] or { dynamic = true }
  byKey[key] = f

  local items = {}
  for _, it in ipairs(c.items) do
    local rec = ns.drops.items[it.id]
    items[#items + 1] = { id = it.id, name = rec[1], quality = rec[2], chance = it.chance * 100,
      perHour = c.kph * it.chance, src = "db", value = it.chance * it.price }
  end
  table.sort(items, function(a, b) return a.value > b.value end)
  if c.green then items[#items + 1] = GreenRow(c.kph, c.green) end -- last, so it never becomes the main item

  f.bracket, f.name, f.zone = bracket, name, zone
  f.map = n[9] and { id = n[9], zone = zone, points = n[10] } or nil
  f.coords = x and string.format("%d, %d", x, y) or nil
  f.mobLevels = minL == maxL and tostring(minL) or (minL .. "-" .. maxL)
  f.difficulty = elite and 3 or 2
  f.rank = 90
  f.loot = { kph = c.kph, items = items, mobs = { name }, dynamic = true }
  local where = f.coords and string.format("around %s in %s", f.coords, zone) or ("in " .. zone)
  f.howTo = {
    string.format("Kill %s %s.", Plural(name), where),
    "Loot everything and post the items listed under Market.",
  }
  if elite then f.howTo[#f.howTo + 1] = "They're elite: bring a friend or pull them one at a time." end
  return f
end

function ns.RebuildDynamic()
  dirty = false
  wipe(byBracket)
  local a = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (ns.drops and a and a.GetAuctionPriceByItemID) then return end

  -- value per kill for every mob, from every priced item it drops
  local mobs = {}
  for id, rec in pairs(ns.drops.items) do
    local ok, price = pcall(a.GetAuctionPriceByItemID, addonName, id)
    if ok and price and price >= MIN_PRICE then
      for i = 3, #rec - 1, 2 do
        local npc, chance = rec[i], rec[i + 1] / 10000
        local v = mobs[npc]
        if not v then v = { value = 0, items = {} }; mobs[npc] = v end
        v.value = v.value + chance * price
        v.items[#v.items + 1] = { id = id, chance = chance, price = price }
      end
    end
  end

  -- a random green's value per level bracket: the median-priced green that mobs of that level drop
  local greenByBracket = {}
  for b, ids in pairs(ns.drops.greens or {}) do
    local priced = {}
    for _, id in ipairs(ids) do
      local ok, price = pcall(a.GetAuctionPriceByItemID, addonName, id)
      if ok and price and price > 0 then priced[#priced + 1] = { id = id, price = price } end
    end
    if #priced >= 3 then
      table.sort(priced, function(x, y) return x.price < y.price end)
      greenByBracket[b] = priced[math.floor((#priced + 1) / 2)]
    end
  end

  AddGreensToCurated(greenByBracket)

  -- best spawn of each mob name per bracket
  local cands = {}
  for npc, v in pairs(mobs) do
    local n = ns.drops.npcs[npc]
    if n then
      local kph = n[11] or (n[4] == 1 and KPH_ELITE or KPH_NORMAL)
      local green = greenByBracket[GreenBracket(n[2], n[3])]
      local value = v.value + (green and WORLD_GREEN_CHANCE * green.price or 0)
      local gph = value / 10000 * kph
      if gph >= MIN_GPH then
        local b = ns.data.brackets[ns.BracketIndexForLevel(math.floor((n[2] + n[3]) / 2))]
        cands[b] = cands[b] or {}
        local cur = cands[b][n[1]]
        if not cur or gph > cur.gph then cands[b][n[1]] = { n = n, gph = gph, kph = kph, items = v.items, green = green } end
      end
    end
  end

  local covered = Covered()
  for b, byName in pairs(cands) do
    local list = {}
    for name, c in pairs(byName) do
      if not (covered[b] and covered[b][name]) then list[#list + 1] = c end
    end
    table.sort(list, function(x, y) return x.gph > y.gph end)
    local out, hot = {}, 0
    for i, c in ipairs(list) do
      local f = BuildFarm(b, c)
      if i <= PER_BRACKET then
        out[#out + 1] = f
      elseif hot < EXTRA_HOT and #ns.FarmHotItems(f) > 0 then
        out[#out + 1] = f
        hot = hot + 1
      end
    end
    byBracket[b] = out
  end
end

-- Live farms for a bracket label (rebuilt lazily after prices change).
function ns.DynamicFarms(bracket)
  if FarmerJoeDB and FarmerJoeDB.filters and FarmerJoeDB.filters.showLive == false then return {} end
  if dirty then ns.RebuildDynamic() end
  return byBracket[bracket] or {}
end
