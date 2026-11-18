-- Farmer Joe: core logic (player state, filtering, prices, slash commands)
local addonName, ns = ...

local data = ns.data or { farms = {}, brackets = {}, containers = {}, pools = {}, meta = {} }
ns.data = data
data.meta = data.meta or {}

ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

ns.player = { level = 1, class = nil, className = nil, profs = {} }

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffF7CE5BFarmer Joe:|r " .. tostring(msg))
end
ns.Print = Print

---------------------------------------------------------------- saved variables
-- FarmerJoeDB = {
--   minimap = { hide = false, minimapPos = 215 },   -- LibDBIcon format
--   filters = { onlyCanDo = false, hideFlagged = false },
--   window  = { point = "CENTER", x = 0, y = 0 },
-- }
local function InitDB()
  FarmerJoeDB = FarmerJoeDB or {}
  local db = FarmerJoeDB

  db.minimap = db.minimap or {}
  if db.minimap.minimapPos == nil then db.minimap.minimapPos = db.minimap.angle or 215 end
  if db.minimap.hide == nil then db.minimap.hide = false end
  db.minimap.angle = nil

  db.filters = db.filters or {}
  if db.filters.onlyCanDo == nil then db.filters.onlyCanDo = false end
  if db.filters.hideFlagged == nil then db.filters.hideFlagged = db.hideFlagged or false end
  if db.filters.showLive == nil then db.filters.showLive = true end
  db.onlyMine, db.hideFlagged = nil, nil -- pre-0.2 keys

  db.window = db.window or { point = "CENTER", x = 0, y = 0 }
end

---------------------------------------------------------------- player state
local function ScanProfessions()
  local profs = {}
  if GetProfessions and GetProfessionInfo then
    for _, idx in pairs({ GetProfessions() }) do
      if idx then
        local name = GetProfessionInfo(idx)
        if name then profs[name:lower()] = true end
      end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader = GetSkillLineInfo(i)
      if name and not isHeader then profs[name:lower()] = true end
    end
  end
  ns.player.profs = profs
end

local function ScanPlayer()
  ns.player.level = UnitLevel("player") or 1
  ns.player.className, ns.player.class = UnitClass("player")
  ScanProfessions()
end
ns.ScanPlayer = ScanPlayer

---------------------------------------------------------------- brackets / farms
local function BracketRange(b)
  local lo, hi = b:match("^(%d+)%-(%d+)$")
  return tonumber(lo), tonumber(hi)
end

function ns.BracketIndexForLevel(level)
  for i, b in ipairs(data.brackets) do
    local lo, hi = BracketRange(b)
    if lo and level >= lo and level <= hi then return i end
  end
  return #data.brackets
end

-- "first aid" -> "First Aid"
function ns.TitleCase(s)
  return (tostring(s):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function ns.HasProf(p) return ns.player.profs[p:lower()] and true or false end

function ns.ClassOK(farm)
  local classes = farm.classes or {}
  if #classes == 0 or not ns.player.class then return true end
  for _, c in ipairs(classes) do if c == ns.player.class then return true end end
  return false
end

-- Required professions satisfied? (profReqMode "any" = one of them is enough)
function ns.ProfsOK(farm)
  local req = farm.profReq or {}
  if #req == 0 then return true end
  if farm.profReqMode == "any" then
    for _, p in ipairs(req) do if ns.HasProf(p) then return true end end
    return false
  end
  for _, p in ipairs(req) do if not ns.HasProf(p) then return false end end
  return true
end

-- Returns ok (bool) and reasons like "needs Skinning", "Mage only".
function ns.CanDo(farm)
  local reasons = {}
  local req = farm.profReq or {}
  if not ns.ProfsOK(farm) then
    if farm.profReqMode == "any" then
      local names = {}
      for _, p in ipairs(req) do names[#names + 1] = ns.TitleCase(p) end
      reasons[#reasons + 1] = "needs " .. table.concat(names, " or ")
    else
      for _, p in ipairs(req) do
        if not ns.HasProf(p) then reasons[#reasons + 1] = "needs " .. ns.TitleCase(p) end
      end
    end
  end
  if not ns.ClassOK(farm) then
    reasons[#reasons + 1] = (farm.classText or table.concat(farm.classes, "/")) .. " only"
  end
  return #reasons == 0, reasons
end

function ns.IsFlagged(f)
  local thin, crashing = ns.FarmFlags(f)
  return thin or crashing
end

-- Seed farms carry names only. Per-farm `seed` wins; a farm with Loot.lua data isn't seed.
function ns.IsSeed(f)
  if f.seed ~= nil then return f.seed end
  if f.loot then return false end
  return data.meta.seed and true or false
end

-- Returns the visible farms (rank order) and a summary:
--   { total, hiddenCan, hiddenFlag, hidden, anySeed }
-- hiddenFlag only counts farms not already hidden by the can-do filter.
function ns.FarmsForBracket(bracketIndex)
  local bracket = data.brackets[bracketIndex]
  local filters = FarmerJoeDB.filters
  local out = {}
  local info = { total = 0, hiddenCan = 0, hiddenFlag = 0, hidden = 0, anySeed = false }
  local all = {}
  for _, f in ipairs(data.farms) do
    if f.bracket == bracket then all[#all + 1] = f end
  end
  info.live = 0
  for _, f in ipairs(ns.DynamicFarms(bracket)) do
    all[#all + 1] = f
    info.live = info.live + 1
  end
  ns.RankBracket(all)
  for _, f in ipairs(all) do
    do
      info.total = info.total + 1
      if ns.IsSeed(f) then info.anySeed = true end
      if filters.onlyCanDo and not ns.CanDo(f) then
        info.hiddenCan = info.hiddenCan + 1
      elseif filters.hideFlagged and ns.IsFlagged(f) then
        info.hiddenFlag = info.hiddenFlag + 1
      else
        out[#out + 1] = f
      end
    end
  end
  info.hidden = info.hiddenCan + info.hiddenFlag
  table.sort(out, function(a, b) return (a.displayRank or a.rank or 99) < (b.displayRank or b.rank or 99) end)
  return out, info
end

---------------------------------------------------------------- formatting
-- Live gold/hr from your Auctionator scans when available, else the bundled range.
function ns.FormatGPH(f)
  local live = ns.FarmGPH(f)
  if live then
    if live >= 10 then return string.format("~%.0fg", live) end
    if live >= 1 then return string.format("~%.1fg", live) end
    return "~" .. ns.FormatGold(live)
  end
  local lo, hi = f.gphLow, f.gphHigh
  if f.goldUpTo and hi then return string.format("up to %dg", hi) end
  if lo and hi then
    if lo == hi then return string.format("%dg", lo) end
    return string.format("%d-%dg", lo, hi)
  elseif hi then
    return string.format("up to %dg", hi)
  elseif lo then
    return string.format("%dg+", lo)
  end
  return nil -- unknown; callers show "?"
end

-- Gold amount (float) -> "12g", "1.2g", "38s", "4s 80c"
function ns.FormatGold(g)
  if not g then return nil end
  if g >= 10 then return string.format("%.0fg", g) end
  if g >= 1 then return string.format("%.1fg", g) end
  local copper = math.floor(g * 10000 + 0.5)
  local s, c = math.floor(copper / 100), copper % 100
  if s >= 10 or c == 0 then return string.format("%ds", s) end
  if s == 0 then return string.format("%dc", c) end
  return string.format("%ds %dc", s, c)
end

function ns.FormatInt(n)
  if not n then return nil end
  local s = tostring(math.floor(n + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

---------------------------------------------------------------- events / slash
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    ScanPlayer()
  elseif event == "PLAYER_LEVEL_UP" then
    ScanPlayer()
    ns.player.level = arg1 or ns.player.level
    if ns.OnPlayerChanged then ns.OnPlayerChanged(true) end
  elseif event == "SKILL_LINES_CHANGED" then
    ScanProfessions()
    if ns.InvalidatePrices then ns.InvalidatePrices() end -- skinning etc. change what counts
    if ns.OnPlayerChanged then ns.OnPlayerChanged(false) end
  end
end)

SLASH_FARMERJOE1 = "/fj"
SLASH_FARMERJOE2 = "/farmerjoe"
SlashCmdList.FARMERJOE = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "build" then
    local version, build, date, toc = GetBuildInfo()
    Print(string.format("client %s (build %s, %s). TOC ## Interface: |cffffff00%s|r", version, build, date, tostring(toc)))
  elseif msg == "info" then
    local m = data.meta
    Print(string.format("%d farms, prices %s (%s), data generated %s%s",
      #data.farms, m.priceSnapshot or "?", m.market or "?", m.generated or "?",
      m.seed and " |cffF7B05B[seed data: names only]|r" or ""))
    Print("Auctionator overlay: " .. (ns.HasAuctionator() and "on" or "off (Auctionator not loaded)"))
  elseif msg == "reset" then
    if ns.ResetPosition then ns.ResetPosition() end
  elseif msg == "minimap" then
    if ns.ToggleMinimapButton then ns.ToggleMinimapButton() end
  elseif msg == "clearpins" or msg == "pins" then
    if ns.ClearMapPins then ns.ClearMapPins() end
    Print("Map pins cleared.")
  elseif msg == "live" then
    local fl = FarmerJoeDB.filters
    fl.showLive = not fl.showLive
    Print("Live finds from your Auctionator scans: " .. (fl.showLive and "shown" or "hidden"))
    if ns.Refresh then ns.Refresh() end
  elseif msg == "scan" then
    if not ns.CanScan() then
      Print("Open the auction house first (Auctionator must be loaded).")
    else
      local farms = {}
      for _, f in ipairs(data.farms) do
        if f.bracket == data.brackets[ns.BracketIndexForLevel(ns.player.level)] then farms[#farms + 1] = f end
      end
      ns.ScanItems(ns.FarmItemIDs(farms))
    end
  elseif msg == "session" then
    if ns.ToggleSessionWindow then ns.ToggleSessionWindow() end
  elseif msg == "start" then
    ns.StartSession(nil)
  elseif msg == "stop" then
    if ns.Session() then ns.StopSession() else Print("No session running.") end
  elseif msg == "pause" then
    if ns.SessionState() == "paused" then ns.ResumeSession() else ns.PauseSession() end
  elseif msg == "help" then
    Print("/fj - toggle window | /fj scan - scan your bracket's items at the AH | /fj session - session tracker | /fj start, /fj pause, /fj stop - farming session | /fj live - show/hide live finds | /fj clearpins - remove map pins | /fj minimap - show/hide minimap button | /fj build | /fj info | /fj reset - recenter window")
  else
    ScanPlayer()
    if ns.Toggle then ns.Toggle() end
  end
end
