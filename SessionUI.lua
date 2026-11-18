-- Farmer Joe: farming session tracker window.
local addonName, ns = ...
local K = ns.Kit
local C, FS, Solid, Gradient, Edge, Media = K.C, K.FS, K.Solid, K.Gradient, K.Edge, K.Media
local FRIZ, NARROW, DOT = K.FRIZ, K.NARROW, K.DOT

local SW, SH = 320, 456
local EDGE, PAD, TITLE_H = 5, 13, 24
local ROW_H = 22
local LIST_Y = 222                       -- top of the loot list (below its column header)
local FOOT = 12 + 22 + 10                -- buttons + margins at the bottom
local NUM_ROWS = math.floor((SH - LIST_Y - FOOT - 4) / ROW_H)
local LIST_W = SW - PAD * 2
local ROW_W = LIST_W - 12                -- room for the slim scroll bar
local PILL_W = 52

local win
local offset = 0

local ACTION = {
  auction = { "Auction", C.clay, true },
  vendor = { "Vendor", C.bronze, false },
  keep = { "Keep", C.poor, false },
  pending = { "...", C.poor, false },
}

local function Gold(copper, size) return K.CoinIcons((copper or 0) / 10000, size or 12) end
-- copper -> "1g 23s 4c" with coin icons, for tooltips
local function FullMoney(copper)
  if GetCoinTextureString then return GetCoinTextureString(math.floor(copper + 0.5)) end
  return K.Money(copper)
end

local function Clock(secs)
  local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), math.floor(secs % 60)
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function SavePosition()
  local point, _, relPoint, x, y = win:GetPoint(1)
  FarmerJoeDB.sessionWindow = { point = point, relativePoint = relPoint, x = x, y = y }
end

---------------------------------------------------------------- update
local function UpdateRows(t, s)
  local rows = t.rows
  win.bar:SetRange(#rows, NUM_ROWS)
  offset = math.max(0, math.min(offset, math.max(0, #rows - NUM_ROWS)))
  win.bar:SetValue(offset)
  local fresh = s and s.last and s.lastAt and (time() - s.lastAt) < 4
  for i, row in ipairs(win.rows) do
    local r = rows[i + offset]
    row.data = r
    if r then
      local adv = r.advice
      row.icon:SetTexture(K.ItemIcon(r.id) or K.QUESTION)
      local q = K.QUALITY[adv.quality or 1] or C.custard
      row.name:SetText(adv.name or ("item " .. r.id))
      row.name:SetTextColor(q[1], q[2], q[3])
      row.count:SetText("x" .. r.count)
      row.value:SetText(r.value > 0 and Gold(r.value) or "|cff7D7457-|r")
      local a = ACTION[adv.action] or ACTION.pending
      K.SetPill(row.pill, a[1], a[2], a[3])
      row.pill:SetWidth(PILL_W)
      row.flash:SetShown(fresh and s.last == r.id)
      row:Show()
    else
      row:Hide()
    end
  end
end

local function Update()
  if not win or not win:IsShown() then return end
  local s = ns.Session()
  local st = ns.SessionState(s)
  local t = ns.SessionTotals(s)

  -- hero
  win.farm:SetText(s and (s.farm or "Free farming") or "No session running")
  win.zone:SetText(s and (s.zone and (s.zone .. (s.bracket and ("  " .. DOT .. "  levels " .. s.bracket) or "")) or "Tracking everything you loot")
    or "Start one to track loot and gold per hour")
  if st == "running" then K.SetPill(win.status, "Running", C.live, true)
  elseif st == "paused" then K.SetPill(win.status, "Paused", C.clay, true)
  elseif st == "finished" then K.SetPill(win.status, "Finished", C.bronze, false)
  else win.status:Hide() end

  -- clock panel
  win.time:SetText(Clock(t.elapsed))
  win.time:SetTextColor(unpack(st == "running" and C.white or C.bronze))
  win.total:SetText(Gold(t.total, 14))
  win.gph:SetText(t.gph and Gold(t.gph, 14) or "|cff7D7457" .. (s and "after 1 min" or "-") .. "|r")

  local est = s and s.estimate
  if est and t.gph then
    local pct = t.gph / 10000 / est * 100
    local col = pct >= 100 and "live" or (pct >= 70 and "mustard" or "clay")
    win.compare:SetText(K.Col("bronze", "Farm estimate ") .. K.CoinIcons(est, 11) .. K.Col("bronze", " per hour  " .. DOT .. "  you're at ")
      .. K.Col(col, string.format("%d%%", pct)))
  elseif est then
    win.compare:SetText(K.Col("bronze", "Farm estimate ") .. K.CoinIcons(est, 11) .. K.Col("bronze", " per hour"))
  elseif s then
    win.compare:SetText(K.Col("bronze", "Gold per hour counts coin plus what your loot sells for."))
  else
    win.compare:SetText("")
  end

  -- tiles
  win.coin:SetText(Gold(t.coin))
  win.vendor:SetText(Gold(t.vendor))
  win.auction:SetText(Gold(t.auction))
  win.lootHead:SetText(string.format("LOOT  |cffDFD6A7%d|r", t.items))

  UpdateRows(t, s)
  if not s then
    win.empty:SetText("Pick a farm in Farmer Joe and press |cffF7CE5BStart farming session|r, or start one here to track whatever you farm.")
    win.empty:Show()
  elseif #t.rows == 0 then
    win.empty:SetText(st == "running" and "Nothing looted yet. Go kill something." or "Nothing was looted.")
    win.empty:Show()
  else
    win.empty:Hide()
  end

  -- buttons
  local primary, secondary = win.primary, win.secondary
  if st == "running" then primary.label:SetText("Pause")
  elseif st == "paused" then primary.label:SetText("Resume")
  else primary.label:SetText(st == "finished" and "New session" or "Start session") end
  primary.action = st
  secondary.label:SetText(st == "finished" and "Clear" or "Stop")
  secondary:SetShown(st ~= nil)
  for _, b in ipairs({ primary, secondary }) do b:SetWidth(math.ceil(b.label:GetStringWidth()) + 24) end
end
ns.UpdateSessionWindow = Update

---------------------------------------------------------------- build
local function Chrome()
  for i = 1, 6 do Edge(win, -i, 1, C.black, 0.32 * (1 - i / 7) ^ 1.5, "BACKGROUND", -8) end
  local bg = win:CreateTexture(nil, "BACKGROUND", nil, -7)
  bg:SetAllPoints()
  Gradient(bg, "VERTICAL", C.frameTop, C.coffee)
  local grain = win:CreateTexture(nil, "BACKGROUND", nil, -6)
  grain:SetPoint("TOPLEFT", EDGE, -EDGE); grain:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
  grain:SetTexture(Media("Grain128"), "REPEAT", "REPEAT")
  grain:SetTexCoord(0, (SW - EDGE * 2) / 128, 0, (SH - EDGE * 2) / 128)
  if grain.SetHorizTile then grain:SetHorizTile(true); grain:SetVertTile(true) end
  grain:SetAlpha(0.7)
  local vig = win:CreateTexture(nil, "BACKGROUND", nil, -5)
  vig:SetPoint("TOPLEFT", EDGE, -EDGE); vig:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
  vig:SetTexture(Media("Vignette256"))

  Edge(win, 0, 1, C.black, 1, "BORDER", 0)
  Edge(win, 1, 2, C.bronze, 1, "BORDER", 0)
  local glint = Solid(win, "BORDER", 1, C.clayHi, 0.45)
  glint:SetPoint("TOPLEFT", 1, -1); glint:SetPoint("TOPRIGHT", -1, -1); glint:SetHeight(1)
  Edge(win, 3, 1, C.coffee, 1, "BORDER", 0)
  Edge(win, 4, 1, C.black, 1, "BORDER", 0)
  for _, c in ipairs({ { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
    local t = win:CreateTexture(nil, "OVERLAY")
    t:SetTexture(Media("Corner64"))
    t:SetSize(28, 28)
    t:SetPoint(c[1], 0, 0)
    t:SetTexCoord(c[2], c[3], c[4], c[5])
    t:SetVertexColor(C.bronze[1], C.bronze[2], C.bronze[3], 0.95)
  end
end

local function TitleBar()
  local bar = CreateFrame("Frame", nil, win)
  bar:SetPoint("TOPLEFT", EDGE, -EDGE); bar:SetPoint("TOPRIGHT", -EDGE, -EDGE)
  bar:SetHeight(TITLE_H + 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT"); bg:SetPoint("BOTTOMRIGHT", 0, 1)
  Gradient(bg, "VERTICAL", C.titleTop, C.coffee)
  local line = Solid(bar, "BORDER", 0, C.bronze)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
  local under = Solid(bar, "BORDER", 0, C.black, 0.6)
  under:SetPoint("TOPLEFT", bar, "BOTTOMLEFT"); under:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT"); under:SetHeight(2)

  local title = FS(bar, FRIZ, 13, C.mustard)
  title:SetJustifyH("CENTER"); title:SetJustifyV("MIDDLE")
  title:SetPoint("CENTER", 0, 0)
  title:SetText("Farming Session")
  local tw = math.ceil(title:GetStringWidth())
  for _, side in ipairs({ -1, 1 }) do
    local d = bar:CreateTexture(nil, "ARTWORK")
    d:SetTexture(Media("Diamond32"))
    d:SetSize(7, 7)
    d:SetPoint("CENTER", bar, "CENTER", side * (tw / 2 + 10), 0)
    d:SetVertexColor(C.mustard[1], C.mustard[2], C.mustard[3])
    local rule = bar:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1); rule:SetWidth(50)
    if side < 0 then
      rule:SetPoint("RIGHT", d, "LEFT", -4, 0)
      Gradient(rule, "HORIZONTAL", C.bronze, C.bronze, 0, 0.9)
    else
      rule:SetPoint("LEFT", d, "RIGHT", 4, 0)
      Gradient(rule, "HORIZONTAL", C.bronze, C.bronze, 0.9, 0)
    end
  end

  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() win:StartMoving() end)
  bar:SetScript("OnDragStop", function() win:StopMovingOrSizing(); SavePosition() end)

  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetSize(24, 24)
  close:SetPoint("CENTER", win, "TOPRIGHT", -17, -17)
  close:SetFrameLevel(bar:GetFrameLevel() + 5)
  close:SetScript("OnClick", function() FarmerJoeDB.sessionShown = false; win:Hide() end)
end

-- Dark inset box at (x, y) from the window's top-left.
local function Inset(x, y, w, h)
  local f = CreateFrame("Frame", nil, win)
  f:SetPoint("TOPLEFT", x, -y)
  f:SetSize(w, h)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
  Gradient(bg, "VERTICAL", C.black, C.coffee, 0.62, 0.42)
  Edge(f, 0, 1, C.paneLine, 1, "BORDER")
  local shade = Solid(f, "BORDER", 1, C.black, 0.8)
  shade:SetPoint("TOPLEFT", 1, -1); shade:SetPoint("TOPRIGHT", -1, -1); shade:SetHeight(1)
  return f
end

-- A labelled stat in a box: small caps label above a value.
local function Stat(parent, x, w, label, size, color)
  local l = FS(parent, NARROW, 10, C.bronze)
  l:SetPoint("TOPLEFT", x, -7); l:SetWidth(w); l:SetJustifyH("CENTER")
  l:SetText(label:upper())
  local v = FS(parent, FRIZ, size, color)
  v:SetPoint("TOPLEFT", x, -21); v:SetWidth(w); v:SetJustifyH("CENTER")
  return v
end

local function Row(i)
  local row = CreateFrame("Button", nil, win.list)
  row:SetSize(ROW_W, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row:RegisterForClicks("LeftButtonUp")
  if i % 2 == 0 then
    local z = Solid(row, "BACKGROUND", 0, C.bronze, 0.06)
    z:SetAllPoints()
  end
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  Gradient(hl, "HORIZONTAL", C.mustard, C.mustard, 0.16, 0.02)
  row.flash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.flash:SetAllPoints()
  Gradient(row.flash, "HORIZONTAL", C.live, C.live, 0.22, 0)
  row.flash:Hide()

  local edge = Solid(row, "ARTWORK", 0, C.black)
  edge:SetPoint("LEFT", 3, 0); edge:SetSize(18, 18)
  row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
  row.icon:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1); row.icon:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.pill = K.MakePill(row, 14, 9)
  row.pill:SetPoint("RIGHT", -2, 0)
  row.value = FS(row, NARROW, 12, C.custard)
  row.value:SetJustifyH("RIGHT"); row.value:SetJustifyV("MIDDLE")
  row.value:SetPoint("RIGHT", row.pill, "LEFT", -8, 0)
  row.value:SetWidth(60)
  row.count = FS(row, NARROW, 12, C.bronze)
  row.count:SetJustifyH("RIGHT"); row.count:SetJustifyV("MIDDLE")
  row.count:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
  row.count:SetWidth(30)
  row.name = FS(row, NARROW, 12, C.custard)
  row.name:SetJustifyV("MIDDLE")
  row.name:SetPoint("LEFT", edge, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)

  row:SetScript("OnEnter", function(self)
    local r = self.data
    if not r then return end
    K.ShowItemTip(self, r.id)
    local a = r.advice
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Farmer Joe", C.mustard[1], C.mustard[2], C.mustard[3])
    GameTooltip:AddDoubleLine("Looted this session", tostring(r.count), 0.78, 0.78, 0.78, 1, 1, 1)
    GameTooltip:AddDoubleLine("Vendor price (each)", a.vendor > 0 and FullMoney(a.vendor) or "none", 0.78, 0.78, 0.78, 1, 1, 1)
    if a.ah then
      GameTooltip:AddDoubleLine("Auction price (each)", FullMoney(a.ah), 0.78, 0.78, 0.78, 1, 1, 1)
      GameTooltip:AddDoubleLine(string.format("After the %d%% cut", ns.AH_CUT * 100), FullMoney(a.net), 0.78, 0.78, 0.78, 1, 1, 1)
    end
    local col = a.action == "auction" and C.clay or C.custard
    GameTooltip:AddLine(a.why, col[1], col[2], col[3], true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    local r = self.data
    if r and IsModifiedClick and IsModifiedClick("CHATLINK") then
      local _, link = GetItemInfo(r.id)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end
  end)
  row:Hide()
  return row
end

local function Build()
  win = CreateFrame("Frame", "FarmerJoeSessionFrame", UIParent)
  win:SetSize(SW, SH)
  win:SetFrameStrata("MEDIUM")
  win:SetToplevel(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:SetClampedToScreen(true)
  if win.SetDontSavePosition then win:SetDontSavePosition(true) end
  local p = FarmerJoeDB.sessionWindow or {}
  win:SetPoint(p.point or "RIGHT", UIParent, p.relativePoint or p.point or "RIGHT", p.x or -80, p.y or 40)

  Chrome()
  TitleBar()

  -- hero: farm, zone, status
  local y = EDGE + TITLE_H + 10
  win.status = K.MakePill(win, 16, 10)
  win.status:SetPoint("TOPRIGHT", -PAD - 26, -y)
  win.farm = FS(win, FRIZ, 13, C.mustard)
  win.farm:SetPoint("TOPLEFT", PAD, -y)
  win.farm:SetPoint("RIGHT", win.status, "LEFT", -8, 0)
  win.zone = FS(win, NARROW, 11, C.bronze)
  win.zone:SetPoint("TOPLEFT", PAD, -(y + 18))
  win.zone:SetWidth(SW - PAD * 2)

  -- clock panel: time, total, gold/hr
  y = y + 38
  local panel = Inset(PAD, y, LIST_W, 46)
  local third = math.floor(LIST_W / 3)
  win.time = Stat(panel, 0, third, "Time", 15, C.white)
  win.total = Stat(panel, third, third, "Total", 14, C.custard)
  win.gph = Stat(panel, third * 2, LIST_W - third * 2, "Gold / hr", 14, C.mustard)
  for i = 1, 2 do
    local d = Solid(panel, "BORDER", 2, C.paneLine, 0.8)
    d:SetPoint("TOPLEFT", third * i, -8); d:SetSize(1, 30)
  end
  win.compare = FS(win, NARROW, 11, C.bronze)
  win.compare:SetPoint("TOPLEFT", PAD, -(y + 52))
  win.compare:SetWidth(LIST_W)

  -- tiles: where the money comes from
  y = y + 72
  local tw = math.floor((LIST_W - 12) / 3)
  local function Tile(i, label, color, tip)
    local f = Inset(PAD + (i - 1) * (tw + 6), y, tw, 40)
    local v = Stat(f, 0, tw, label, 12, color)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(label, 1, 1, 1)
      GameTooltip:AddLine(tip, 0.78, 0.78, 0.78, true)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return v
  end
  win.coin = Tile(1, "Coin", C.custard, "Gold, silver and copper picked up from corpses.")
  win.vendor = Tile(2, "Vendor", C.custard, "What the items marked VENDOR fetch at a merchant.")
  win.auction = Tile(3, "Auction", C.clay, string.format(
    "What the items marked AUCTION fetch at your Auctionator prices, less the %d%% auction house cut. "
    .. "An item is marked AUCTION only when that still beats its vendor price.", ns.AH_CUT * 100))

  -- loot list
  y = y + 48
  local head = CreateFrame("Frame", nil, win)
  head:SetPoint("TOPLEFT", PAD, -y); head:SetSize(LIST_W, 18)
  local hbg = head:CreateTexture(nil, "BACKGROUND")
  hbg:SetAllPoints()
  Gradient(hbg, "VERTICAL", C.colTop, C.coffee)
  local hl = Solid(head, "BORDER", 0, C.bronze, 0.6)
  hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
  win.lootHead = FS(head, NARROW, 10, C.bronze)
  win.lootHead:SetJustifyV("MIDDLE"); win.lootHead:SetPoint("LEFT", 6, 0)
  local sellHead = FS(head, NARROW, 10, C.bronze)
  sellHead:SetJustifyV("MIDDLE"); sellHead:SetJustifyH("CENTER")
  sellHead:SetPoint("RIGHT", -(12 + 2), 0); sellHead:SetWidth(PILL_W)
  sellHead:SetText("SELL AT")
  local valHead = FS(head, NARROW, 10, C.bronze)
  valHead:SetJustifyV("MIDDLE"); valHead:SetJustifyH("RIGHT")
  valHead:SetPoint("RIGHT", sellHead, "LEFT", -8, 0); valHead:SetWidth(60)
  valHead:SetText("WORTH")

  local list = CreateFrame("Frame", nil, win)
  list:SetPoint("TOPLEFT", PAD, -(y + 18 + 2))
  list:SetSize(LIST_W, NUM_ROWS * ROW_H)
  win.list = list
  win.rows = {}
  for i = 1, NUM_ROWS do win.rows[i] = Row(i) end
  win.bar = K.SlimBar(list, function(v) offset = v; Update() end)
  win.bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, 0)
  win.bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -1, 0)
  win.bar.page = NUM_ROWS - 1
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta) win.bar:Scroll(delta * 2) end)

  win.empty = FS(win, NARROW, 12, C.bronze)
  win.empty:SetWordWrap(true)
  win.empty:SetJustifyH("CENTER")
  win.empty:SetWidth(LIST_W - 40)
  win.empty:SetPoint("TOP", list, "TOP", 0, -40)

  -- buttons
  local foot = Solid(win, "BORDER", 0, C.bronze, 0.5)
  foot:SetPoint("BOTTOMLEFT", PAD, 12 + 22 + 7); foot:SetPoint("BOTTOMRIGHT", -PAD, 12 + 22 + 7); foot:SetHeight(1)
  win.primary = K.ClayButton(win, "Pause", 11, nil, 22)
  win.primary:SetPoint("BOTTOMLEFT", PAD, 12)
  win.primary:SetScript("OnClick", function(self)
    if self.action == "running" then ns.PauseSession()
    elseif self.action == "paused" then ns.ResumeSession()
    else ns.StartSession(nil) end
  end)
  win.secondary = K.ClayButton(win, "Stop", 11, nil, 22)
  win.secondary:SetPoint("LEFT", win.primary, "RIGHT", 6, 0)
  win.secondary:SetScript("OnClick", function()
    if ns.SessionState() == "finished" then ns.ClearSession() else ns.StopSession() end
  end)
  local cut = FS(win, NARROW, 11, C.bronze)
  cut:SetJustifyV("MIDDLE")
  cut:SetPoint("BOTTOMRIGHT", -PAD - 4, 12 + 5)
  cut:SetText(string.format("AH cut %d%%", ns.AH_CUT * 100))

  local elapsed = 0
  win:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    Update()
  end)
  win:SetScript("OnShow", function() FarmerJoeDB.sessionShown = true; Update() end)
  win:SetScript("OnHide", function() GameTooltip:Hide() end)
  win:Hide()
end

---------------------------------------------------------------- public
function ns.ShowSessionWindow()
  if not win then Build() end
  win:Show()
  Update()
end

function ns.ToggleSessionWindow()
  if win and win:IsShown() then
    FarmerJoeDB.sessionShown = false
    win:Hide()
  else
    ns.ShowSessionWindow()
  end
end

ns.OnSessionChanged(Update)
