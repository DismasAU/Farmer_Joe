-- Farmer Joe: main window (design handoff option 4a, "Coffee"; polished pass)
local addonName, ns = ...

---------------------------------------------------------------- design tokens
local FRIZ = "Fonts\\FRIZQT__.TTF"
local NARROW = "Fonts\\ARIALN.TTF"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Hex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local C = {
  custard = Hex("DFD6A7"), mustard = Hex("F7CE5B"), clay = Hex("F7B05B"),
  bronze = Hex("AF9B46"), coffee = Hex("1F1300"), black = { 0, 0, 0 },
  frameTop = Hex("2B1C03"), titleTop = Hex("4A330B"), colTop = Hex("36260A"),
  paneLine = Hex("5E4F22"), detailTop = Hex("1A1000"), detailBottom = Hex("0E0800"),
  cantDo = Hex("7D7457"), cantRank = Hex("5A5A5A"), checkEdge = Hex("8A7A4A"),
  clayBottom = Hex("C27A2C"), clayHi = Hex("FBD29A"), clayEdge = Hex("5A3006"),
  bronzeDark = Hex("6E5F27"), white = Hex("F4EFD8"),
  green = Hex("1EFF00"), live = Hex("8EDB5A"), red = Hex("FF4A3A"),
  poor = Hex("9D9D9D"), uncommon = Hex("1EFF00"), rare = Hex("0070DD"), epic = Hex("A335EE"),
}
local DIFF = { Hex("1EFF00"), Hex("9ACD32"), Hex("FFD100"), Hex("FF8000"), Hex("FF2020") }
local DIFF_WORD = { "Easy", "Steady", "Tricky", "Hard", "Brutal" }

local HEX = { -- for inline |c escapes
  custard = "ffDFD6A7", mustard = "ffF7CE5B", clay = "ffF7B05B", bronze = "ffAF9B46",
  green = "ff1EFF00", live = "ff8EDB5A", red = "ffFF4A3A",
}
local function Col(key, text) return "|c" .. HEX[key] .. text .. "|r" end
local DOT = "\194\183"     -- ·
local APPROX = "\226\137\136" -- ≈

-- Layout (frame-relative, top-left origin)
local W, H = 840, 520
local EDGE = 5                     -- 1 black + 2 bronze + 1 coffee + 1 black
local PAD = 15
local TITLE_H = 26
local HEADER_Y = EDGE + TITLE_H + 1 + 8
local HEADER_H = 30
local BODY_Y = HEADER_Y + HEADER_H + 8
local FOOT_H = 24
local BODY_BOTTOM = 1 + 6 + FOOT_H + 1 + 4  -- distance from frame bottom
local LIST_W = 470
local GAP = 10
local DETAIL_W = W - PAD * 2 - LIST_W - GAP -- 330
local ROW_H = 30
local COLHEAD_H = 22
local NUM_ROWS = math.floor((H - BODY_Y - BODY_BOTTOM - 2 - COLHEAD_H - 1) / ROW_H)
local BAR_ROOM = 12                -- slim scroll bar + gap

-- list columns, measured from the row's right edge
local COL_FLAGS_R, COL_FLAGS_W = 8, 44
local COL_DIFF_R, COL_DIFF_W = COL_FLAGS_R + COL_FLAGS_W + 10, 47
local COL_GOLD_R, COL_GOLD_W = COL_DIFF_R + COL_DIFF_W + 12, 76
local COL_NAME_R = COL_GOLD_R + COL_GOLD_W + 10
local COL_NAME_X = 60

local frame
local state = { bracket = nil, selected = nil, list = {}, info = nil, shownDetail = nil, offset = 0 }

---------------------------------------------------------------- primitives
local function FS(parent, font, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(font, size, "")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(false)
  return fs
end

local function Solid(parent, layer, sub, color, alpha)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  return t
end

-- c1 = top (VERTICAL) or left (HORIZONTAL); colours are {r,g,b} with optional alphas
local function Gradient(tex, orient, c1, c2, a1, a2)
  tex:SetColorTexture(1, 1, 1, 1)
  local lo, hi, loA, hiA = c2, c1, a2 or 1, a1 or 1
  if orient == "HORIZONTAL" then lo, hi, loA, hiA = c1, c2, a1 or 1, a2 or 1 end
  if tex.SetGradientAlpha then
    tex:SetGradientAlpha(orient, lo[1], lo[2], lo[3], loA, hi[1], hi[2], hi[3], hiA)
  else
    tex:SetGradient(orient, CreateColor(lo[1], lo[2], lo[3], loA), CreateColor(hi[1], hi[2], hi[3], hiA))
  end
end

-- A 1px-style rectangle outline drawn `inset` px inside `f` (negative = outside).
local function Edge(f, inset, size, color, alpha, layer, sub)
  local t = {}
  for i = 1, 4 do t[i] = Solid(f, layer or "BORDER", sub, color, alpha) end
  t[1]:SetPoint("TOPLEFT", inset, -inset); t[1]:SetPoint("TOPRIGHT", -inset, -inset); t[1]:SetHeight(size)
  t[2]:SetPoint("BOTTOMLEFT", inset, inset); t[2]:SetPoint("BOTTOMRIGHT", -inset, inset); t[2]:SetHeight(size)
  t[3]:SetPoint("TOPLEFT", inset, -inset - size); t[3]:SetPoint("BOTTOMLEFT", inset, inset + size); t[3]:SetWidth(size)
  t[4]:SetPoint("TOPRIGHT", -inset, -inset - size); t[4]:SetPoint("BOTTOMRIGHT", -inset, inset + size); t[4]:SetWidth(size)
  return t
end

local function Media(name) return ns.MEDIA .. name end

---------------------------------------------------------------- flat look (quest tracker style)
local GREY = { 0.72, 0.72, 0.72 }
local DIM = { 0.45, 0.45, 0.45 }
local FLAT_BG_A = 0.74 -- window background opacity in the flat look

-- Translucent black panel with a thin accent line (and faint glow) along the top.
local function FlatChrome(f, accent, alpha)
  local ch = CreateFrame("Frame", nil, f)
  ch:SetAllPoints()
  ch:SetFrameLevel(f:GetFrameLevel())
  local bg = Solid(ch, "BACKGROUND", -7, C.black, alpha or FLAT_BG_A)
  bg:SetAllPoints()
  accent = accent or C.mustard
  ch.line = Solid(ch, "BORDER", 0, accent, 0.9)
  ch.line:SetPoint("TOPLEFT"); ch.line:SetPoint("TOPRIGHT"); ch.line:SetHeight(1)
  ch.glow = ch:CreateTexture(nil, "BACKGROUND", nil, -6)
  ch.glow:SetPoint("TOPLEFT", 0, -1); ch.glow:SetPoint("TOPRIGHT", 0, -1); ch.glow:SetHeight(14)
  Gradient(ch.glow, "VERTICAL", accent, accent, 0.10, 0)
  return ch
end

-- Plain text button ("x", "+", "<"): dim until hovered.
local function TextButton(parent, label, size, color, w, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 18, h or 18)
  b.text = FS(b, FRIZ, size, color)
  b.text:SetJustifyH("CENTER"); b.text:SetJustifyV("MIDDLE")
  b.text:SetPoint("CENTER", 0, 0)
  b.text:SetText(label)
  b.color = color
  b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
  b:SetScript("OnLeave", function(self) local c = self.color; self.text:SetTextColor(c[1], c[2], c[3]); GameTooltip:Hide() end)
  b:SetScript("OnDisable", function(self) self:SetAlpha(0.3) end)
  b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
  return b
end

-- Flat title row: name on the left in the accent colour, subtitle after it, "x" on the right.
local function FlatTitle(parent, title, sub, onClose, size, icon)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetPoint("TOPLEFT", 0, 0); bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetHeight(26)
  local t = FS(bar, FRIZ, size or 14, C.mustard)
  t:SetJustifyV("MIDDLE")
  if icon then
    local e = bar:CreateTexture(nil, "ARTWORK")
    e:SetTexture(icon)
    e:SetSize(26, 26)
    e:SetPoint("LEFT", 5, 0)
    t:SetPoint("LEFT", e, "RIGHT", 4, 0)
  else
    t:SetPoint("LEFT", 10, 0)
  end
  t:SetText(title)
  if sub then
    local s = FS(bar, NARROW, 12, GREY)
    s:SetJustifyV("MIDDLE")
    s:SetPoint("LEFT", t, "RIGHT", 10, -1)
    s:SetText(sub)
    bar.sub = s
  end
  local rule = Solid(bar, "BORDER", 0, C.white, 0.08)
  rule:SetPoint("BOTTOMLEFT", 8, 0); rule:SetPoint("BOTTOMRIGHT", -8, 0); rule:SetHeight(1)
  local close = TextButton(bar, "x", 12, { 0.55, 0.55, 0.55 }, 22, 22)
  close:SetPoint("RIGHT", -4, 0)
  close:SetScript("OnClick", onClose)
  bar.close, bar.title = close, t
  return bar
end

-- Sunlit Clay button: gradient fill, 1px black border, #5A3006 inner edge, #FBD29A top highlight.
local function FlatButton(parent, text, size, width, height)
  local b = CreateFrame("Button", nil, parent)
  local fill = Solid(b, "BACKGROUND", 0, C.white, 0.07)
  fill:SetAllPoints()
  local line = Solid(b, "BORDER", 0, C.mustard, 0.7)
  line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(C.mustard[1], C.mustard[2], C.mustard[3], 0.14)
  local label = FS(b, FRIZ, size, C.mustard)
  label:SetJustifyV("MIDDLE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  b.label = label
  b:SetSize(width or math.ceil(label:GetStringWidth()) + 22, height or 22)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 1, -1) end end)
  b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
  b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
  return b
end

local function ClayButton(parent, text, size, width, height)
  if ns.Flat() then return FlatButton(parent, text, size, width, height) end
  local b = CreateFrame("Button", nil, parent)
  local fill = b:CreateTexture(nil, "BACKGROUND")
  fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMRIGHT", -1, 1)
  Gradient(fill, "VERTICAL", C.clay, C.clayBottom)
  Edge(b, 0, 1, C.black, 1, "BORDER", 0)
  Edge(b, 1, 1, C.clayEdge, 1, "BORDER", 1)
  local hiLine = Solid(b, "BORDER", 2, C.clayHi)
  hiLine:SetPoint("TOPLEFT", 1, -1); hiLine:SetPoint("TOPRIGHT", -1, -1); hiLine:SetHeight(1)

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 1, 1, 0.16)
  hl:SetBlendMode("ADD")

  local label = FS(b, FRIZ, size, C.coffee)
  label:SetShadowColor(1, 0.88, 0.67, 0.55)
  label:SetShadowOffset(0, -1)
  label:SetJustifyV("MIDDLE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  b.label = label

  b:SetSize(width or math.ceil(label:GetStringWidth()) + 22, height or 22)
  b:SetScript("OnMouseDown", function(self)
    if self:IsEnabled() then self.label:SetPoint("CENTER", 1, -1) end
  end)
  b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
  b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
  return b
end

-- Round gold page-arrow button (stock spellbook art).
local function ArrowButton(parent, dir)
  if ns.Flat() then
    local b = TextButton(parent, dir == "Prev" and "<" or ">", 15, C.mustard, 22, 24)
    local bg = Solid(b, "BACKGROUND", 0, C.white, 0.06)
    bg:SetAllPoints()
    return b
  end
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-"
  b:SetNormalTexture(base .. "Up")
  b:SetPushedTexture(base .. "Down")
  b:SetDisabledTexture(base .. "Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  return b
end

-- 15x15 checkbox: black fill, 1px #8A7A4A border, gold check, Arial Narrow 12 Custard label.
-- key: a FarmerJoeDB.filters field; or pass onClick(checked) to handle it yourself.
local function Checkbox(parent, text, key, onClick)
  local b = CreateFrame("CheckButton", nil, parent)
  local box = CreateFrame("Frame", nil, b)
  box:SetSize(15, 15)
  box:SetPoint("LEFT", 0, 0)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  if ns.Flat() then
    bg:SetColorTexture(0, 0, 0, 0.5)
    Edge(box, 0, 1, C.white, 0.22, "BORDER")
  else
    Gradient(bg, "VERTICAL", C.black, C.coffee)
    Edge(box, 0, 1, C.checkEdge, 1, "BORDER")
  end

  b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local ct = b:GetCheckedTexture()
  ct:ClearAllPoints(); ct:SetSize(21, 21); ct:SetPoint("CENTER", box, "CENTER", 1, 0)
  ct:SetDrawLayer("OVERLAY")
  b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  local ht = b:GetHighlightTexture()
  ht:ClearAllPoints(); ht:SetSize(21, 21); ht:SetPoint("CENTER", box, "CENTER", 0, 0)

  local label = FS(b, NARROW, 12, ns.Flat() and GREY or C.custard)
  label:SetJustifyV("MIDDLE")
  label:SetPoint("LEFT", box, "RIGHT", 5, 0)
  label:SetText(text)
  b:SetSize(15 + 5 + math.ceil(label:GetStringWidth()), 18)

  b:SetScript("OnClick", function(self)
    if onClick then onClick(self:GetChecked() and true or false); return end
    FarmerJoeDB.filters[key] = self:GetChecked() and true or false
    ns.Refresh()
  end)
  b.key = key
  return b
end

-- Small uppercase pill. filled = solid colour with dark text; otherwise a tinted outline.
local function MakePill(parent, height, size)
  local p = CreateFrame("Frame", nil, parent)
  p:SetHeight(height or 14)
  p.bg = p:CreateTexture(nil, "BACKGROUND")
  p.bg:SetPoint("TOPLEFT", 1, -1); p.bg:SetPoint("BOTTOMRIGHT", -1, 1)
  p.edges = Edge(p, 0, 1, C.clay, 1, "BORDER")
  p.text = FS(p, NARROW, size or 10, C.clay)
  p.text:SetJustifyH("CENTER"); p.text:SetJustifyV("MIDDLE")
  p.text:SetPoint("CENTER", 0, 0)
  p:Hide()
  return p
end

local function SetPill(p, label, color, filled)
  p.text:SetText(label:upper())
  if filled then
    Gradient(p.bg, "VERTICAL", color, { color[1] * 0.78, color[2] * 0.78, color[3] * 0.78 })
    p.text:SetTextColor(C.coffee[1], C.coffee[2], C.coffee[3])
    p.text:SetShadowColor(1, 1, 1, 0.25)
    for _, e in ipairs(p.edges) do e:SetColorTexture(0, 0, 0, 0.9) end
  else
    p.bg:SetColorTexture(color[1], color[2], color[3], 0.13)
    p.text:SetTextColor(color[1], color[2], color[3])
    p.text:SetShadowColor(0, 0, 0, 1)
    for _, e in ipairs(p.edges) do e:SetColorTexture(color[1], color[2], color[3], 0.7) end
  end
  local w = math.ceil(p.text:GetStringWidth()) + 10
  p:SetWidth(w)
  p:Show()
  return w
end

-- Five difficulty diamonds.
local function MakePips(parent)
  local p = CreateFrame("Frame", nil, parent)
  p.pips = {}
  for i = 1, 5 do
    local t = p:CreateTexture(nil, "ARTWORK")
    t:SetTexture(Media("Diamond32"))
    p.pips[i] = t
  end
  p:Hide()
  return p
end

local function SetPips(p, n, color, size, gap)
  size, gap = size or 9, gap or 1
  for i, t in ipairs(p.pips) do
    t:ClearAllPoints()
    t:SetSize(size, size)
    t:SetPoint("LEFT", p, "LEFT", (i - 1) * (size + gap), 0)
    if n and i <= n then
      t:SetVertexColor(color[1], color[2], color[3], 1)
    else
      t:SetVertexColor(C.bronze[1], C.bronze[2], C.bronze[3], 0.22)
    end
  end
  p:SetSize(5 * size + 4 * gap, size)
  p:Show()
end

local function Capitalise(s) return (s:gsub("^%l", string.upper)) end

---------------------------------------------------------------- money
local COIN = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:2:0|t",
}
-- gold (float) -> "5.2" + gold coin, "78" + silver coin ...
local function CoinIcons(g, size)
  if not g then return nil end
  size = size or 12
  if g >= 10 then return string.format("%.0f", g) .. COIN.g:format(size, size) end
  if g >= 1 then return string.format("%.1f", g) .. COIN.g:format(size, size) end
  local s = math.floor(g * 100 + 0.5)
  if s >= 1 then return s .. COIN.s:format(size, size) end
  return math.floor(g * 10000 + 0.5) .. COIN.c:format(size, size)
end
-- "1s 30c" with the unit letters tinted like the default money display
local function Coins(str)
  if not str then return nil end
  str = str:gsub("(%d)c", "%1|cffEDA55Fc|r")
  str = str:gsub("(%d)s", "%1|cffC7C7CFs|r")
  str = str:gsub("(%d)g", "%1|cffFFD100g|r")
  return str
end
local function Money(copper) return copper and Coins(ns.FormatGold(copper / 10000)) end

---------------------------------------------------------------- items
local function ItemIcon(id)
  if not id then return nil end
  local icon
  if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
  if not icon and GetItemIcon then icon = GetItemIcon(id) end
  if not icon and GetItemInfo then icon = select(10, GetItemInfo(id)) end
  return icon
end

local QUALITY = { [0] = C.poor, [1] = C.custard, [2] = C.uncommon, [3] = C.rare, [4] = C.epic }
local function QualityColor(it)
  local q = it.quality
  if not q and (it.itemId or it.id) and GetItemInfo then q = select(3, GetItemInfo(it.itemId or it.id)) end
  return QUALITY[q or 1] or C.custard
end

local function ShowItemTip(owner, id)
  if not id then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:SetHyperlink("item:" .. id) end
  GameTooltip:Show()
end

---------------------------------------------------------------- farm field accessors
-- Accept both the build_data.py field names and the handoff's farm record names.
local function MobLevels(f) return f.mobLevels or f.mobs end
local function ZoneLine(f)
  local m = MobLevels(f)
  return (f.zone or "") .. (f.coords and (" (" .. f.coords .. ")") or "") .. (m and (" " .. DOT .. " mobs " .. m) or "")
end
local function SubLine(f)
  local m = MobLevels(f)
  return (f.zone or "") .. (m and ("  " .. DOT .. "  Lv " .. m) or "")
end
local function GoldSource(f)
  local live = ns.LiveFarm(f)
  if live then
    if not ns.HasAuctionator() then return "Auctionator isn't loaded, so there are no live prices." end
    if live.priced == 0 then return "No prices for this farm's items in your Auctionator scans yet." end
    return string.format("From your Auctionator scans: %d of %d items priced", live.priced, live.counted)
  end
  if f.goldSource then return f.goldSource end
  if f.method and f.sourceType then return f.method .. " (" .. f.sourceType .. ")" end
  return f.method or f.sourceType
end
local function HowToSteps(f)
  local h = f.howTo
  if type(h) == "table" then return h end
  if not h or h == "" then return {} end
  local steps = {}
  for line in tostring(h):gmatch("[^\n]+") do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" then steps[#steps + 1] = line end
  end
  if #steps == 1 and steps[1]:match("^1[%.%)]%s") then -- "1. foo 2. bar" on one line
    local s, out = steps[1]:gsub("%s+(%d+[%.%)]%s)", "\n%1"), {}
    for line in s:gmatch("[^\n]+") do out[#out + 1] = line end
    steps = out
  end
  for i, s in ipairs(steps) do steps[i] = s:gsub("^%d+[%.%)]%s*", "") end
  return steps
end
local function Flags(f) return ns.FarmFlags(f) end
local function Market(f)
  local m = f.market
  if m then
    return { item = m.item, itemId = m.itemId, listed = m.listed, perDay = m.soldPerDay, change = m.change7d and m.change7d * 100 }
  end
  if f.itemName or f.listed or f.volume or f.change7d then
    return { item = f.itemName, itemId = f.itemId, listed = f.listed, perDay = f.volume, change = f.change7d }
  end
end
local function Container(f)
  local c = f.container
  if not c then return nil end
  if type(c) == "table" then
    return { name = c.name, ev = c.ev and c.ev / 10000, perHour = c.perHour, loot = c.loot or {}, pools = c.pools or {}, caveat = c.caveat }
  end
  local ref = ns.data.containers and ns.data.containers[c] or {}
  local loot = {}
  for _, it in ipairs(ref.items or {}) do
    loot[#loot + 1] = { itemId = it.id, name = it.name, chance = it.chance and it.chance / 100, qty = it.qty, quality = it.quality }
  end
  local pools, seen = {}, {}
  for _, p in ipairs(ns.data.pools or {}) do
    if p.container == c and p.pool and not seen[p.pool] then
      seen[p.pool] = true
      local v = ns.FormatGold(p.value)
      pools[#pools + 1] = { name = p.pool, value = v and ("~" .. v .. " per pool") or "?" }
    end
  end
  return { name = c, ev = f.containerEV or ref.ev, perHour = f.containersPerHour, loot = loot, pools = pools, caveat = ref.caveat }
end

-- The farm's headline item (the one that earns the most), its record and icon.
local function MainItem(f)
  local live = ns.LiveFarm(f)
  local items = f.loot and f.loot.items or {}
  local id = live and live.main or (items[1] and items[1].id)
  if not id then local m = Market(f); id = m and m.itemId end
  local rec
  for _, it in ipairs(items) do if it.id == id then rec = it end end
  return id, rec
end

local function FarmIcon(f)
  local id, rec = MainItem(f)
  local icon = ItemIcon(id)
  if icon then return icon, id, rec end
  for _, p in ipairs(f.profReq or {}) do
    if p:lower() == "fishing" then return "Interface\\Icons\\Trade_Fishing", id, rec end
  end
  return QUESTION, id, rec
end

-- Display value for the list's Gold/hr column, plus a number for the meter.
local function GoldCell(f)
  local live = ns.FarmGPH(f)
  if live then return CoinIcons(live, 12), live end
  local s = ns.FormatGPH(f)
  return s and Coins(s), f.gphHigh or f.gphLow
end

---------------------------------------------------------------- slim scroll bar
-- onChange(value) fires for user scrolling (wheel, drag, track clicks); SetValue(v) alone is silent.
local function SlimBar(parent, onChange)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetWidth(6)
  local track = Solid(bar, "BACKGROUND", 0, C.black, 0.55)
  track:SetAllPoints()
  local trackHi = Solid(bar, "BACKGROUND", 1, C.paneLine, 0.35)
  trackHi:SetPoint("TOPLEFT"); trackHi:SetPoint("BOTTOMLEFT"); trackHi:SetWidth(1)

  local thumb = CreateFrame("Button", nil, bar)
  thumb:SetWidth(6)
  local tt = thumb:CreateTexture(nil, "ARTWORK")
  tt:SetAllPoints()
  if ns.Flat() then
    tt:SetColorTexture(1, 1, 1, 0.28)
    track:SetColorTexture(1, 1, 1, 0.05)
    trackHi:Hide()
  else
    Gradient(tt, "HORIZONTAL", C.bronze, C.bronzeDark)
  end
  local tl = Solid(thumb, "OVERLAY", 0, C.clayHi, 0.35)
  tl:SetPoint("TOPLEFT"); tl:SetPoint("TOPRIGHT"); tl:SetHeight(1)
  local th = thumb:CreateTexture(nil, "HIGHLIGHT")
  th:SetAllPoints()
  th:SetColorTexture(C.mustard[1], C.mustard[2], C.mustard[3], 0.5)
  th:SetBlendMode("ADD")
  bar.thumb = thumb

  bar.value, bar.max, bar.ratio, bar.page, bar.travel = 0, 0, 1, 1, 0
  function bar:Layout()
    local trackH = self:GetHeight()
    local h = math.max(20, math.floor(trackH * self.ratio))
    thumb:SetHeight(h)
    self.travel = math.max(0, trackH - h)
    local y = self.max > 0 and self.travel * self.value / self.max or 0
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", self, "TOP", 0, -math.floor(y + 0.5))
  end
  function bar:SetRange(total, visible)
    self.max = math.max(0, total - visible)
    self.ratio = total > 0 and math.min(1, visible / total) or 1
    if self.value > self.max then self.value = self.max end
    self:SetShown(self.max > 0)
    self:Layout()
  end
  function bar:SetValue(v, notify)
    v = math.max(0, math.min(self.max, v))
    local changed = v ~= self.value
    self.value = v
    self:Layout()
    if notify and changed then onChange(v) end
  end
  function bar:Scroll(delta) self:SetValue(self.value - delta * self.step, true) end
  bar.step = 1

  local function CursorY() local _, y = GetCursorPosition(); return y / bar:GetEffectiveScale() end
  thumb:SetScript("OnMouseDown", function(self) self.drag = { y = CursorY(), v = bar.value } end)
  thumb:SetScript("OnMouseUp", function(self) self.drag = nil end)
  thumb:SetScript("OnHide", function(self) self.drag = nil end)
  thumb:SetScript("OnUpdate", function(self)
    local d = self.drag
    if not d then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.drag = nil; return end
    if bar.travel <= 0 then return end
    bar:SetValue(d.v + (d.y - CursorY()) / bar.travel * bar.max, true)
  end)
  bar:EnableMouse(true)
  bar:SetScript("OnMouseDown", function(self) -- click the track: page toward the cursor
    local _, ty = thumb:GetCenter()
    if ty then self:SetValue(self.value + (CursorY() > ty and -1 or 1) * self.page, true) end
  end)
  bar:Hide()
  return bar
end

-- Shared with SessionUI.lua so the session window matches the main one.
ns.Kit = {
  C = C, FRIZ = FRIZ, NARROW = NARROW, QUESTION = QUESTION, DOT = DOT, APPROX = APPROX, QUALITY = QUALITY,
  Col = Col, FS = FS, Solid = Solid, Gradient = Gradient, Edge = Edge, Media = Media,
  ClayButton = ClayButton, MakePill = MakePill, SetPill = SetPill, SlimBar = SlimBar,
  CoinIcons = CoinIcons, Coins = Coins, Money = Money, ItemIcon = ItemIcon, ShowItemTip = ShowItemTip,
  GREY = GREY, DIM = DIM, FlatChrome = FlatChrome, FlatTitle = FlatTitle, TextButton = TextButton,
  Checkbox = Checkbox,
}

---------------------------------------------------------------- list
local function ScrollListTop()
  state.offset = 0
  if frame and frame.listBar then frame.listBar:SetValue(0) end
end

local function UpdateList()
  local list = state.list
  local bar = frame.listBar
  local maxOff = math.max(0, #list - NUM_ROWS)
  if state.offset > maxOff then state.offset = maxOff end
  bar:SetRange(#list, NUM_ROWS)
  bar:SetValue(state.offset)
  local offset = state.offset
  local right = bar:IsShown() and -(1 + BAR_ROOM) or -1
  frame.cols:SetPoint("TOPRIGHT", frame.list, "TOPRIGHT", right, -1)

  -- meter scale: best gold/hr on this page of the bracket
  local best = 0
  for _, f in ipairs(list) do
    local _, v = GoldCell(f)
    if v and v > best then best = v end
  end

  for i = 1, NUM_ROWS do
    local row = frame.rows[i]
    local idx = i + offset
    local f = list[idx]
    row:SetPoint("TOPRIGHT", frame.list, "TOPRIGHT", right, -(1 + COLHEAD_H + 1) - (i - 1) * ROW_H)
    if f then
      local ok = ns.CanDo(f)
      local sel = f == state.selected
      local rank = f.displayRank or f.rank
      row.rank:SetText(rank or "")
      row.rank:SetTextColor(unpack(not ok and C.cantRank or ((rank and rank <= 3) and C.mustard or C.bronze)))

      local icon = FarmIcon(f)
      row.icon:SetTexture(icon)
      row.icon:SetDesaturated(not ok)
      row.icon:SetAlpha(ok and 1 or 0.55)

      row.name:SetText(f.name or "?")
      row.name:SetTextColor(unpack(not ok and C.cantDo or (sel and C.white or C.custard)))

      local tag = ns.FarmTag(f)
      row.sub:ClearAllPoints()
      if tag then
        SetPill(row.tag, tag, tag == "HOT" and C.clay or C.live, true)
        row.sub:SetPoint("LEFT", row.tag, "RIGHT", 5, 0)
      else
        row.tag:Hide()
        row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", COL_NAME_X, -17)
      end
      row.sub:SetPoint("RIGHT", row, "RIGHT", -COL_NAME_R, 0)
      row.sub:SetText(SubLine(f))
      row.sub:SetTextColor(unpack(ok and C.bronze or C.cantRank))

      local text, value = GoldCell(f)
      row.gold:SetText(text or "?")
      row.gold:SetTextColor(unpack(not ok and C.cantDo or (text and C.custard or C.bronze)))
      if value and best > 0 then
        row.meter:SetWidth(math.max(2, math.floor((COL_GOLD_W - 2) * math.min(1, value / best))))
        row.meter:Show(); row.meterBg:Show()
        row.meter:SetAlpha(ok and 1 or 0.35)
      else
        row.meter:Hide(); row.meterBg:Hide()
      end

      local d = f.difficulty
      SetPips(row.pips, d, not ok and C.cantDo or (DIFF[d or 0] or C.bronze), 7, 3)
      row.pips:SetAlpha(ok and 1 or 0.6)

      local thin, crashing = Flags(f)
      row.thin:ClearAllPoints(); row.crash:ClearAllPoints()
      if thin then SetPill(row.thin, "thin", C.clay) else row.thin:Hide() end
      if crashing then SetPill(row.crash, "crash", C.red) else row.crash:Hide() end
      if thin and crashing then
        row.thin:SetPoint("TOPRIGHT", row, "TOPRIGHT", -COL_FLAGS_R, -2)
        row.crash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -COL_FLAGS_R, 2)
      else
        row.thin:SetPoint("RIGHT", row, "RIGHT", -COL_FLAGS_R, 0)
        row.crash:SetPoint("RIGHT", row, "RIGHT", -COL_FLAGS_R, 0)
      end
      row.flagText = (thin and "thin " or "") .. (crashing and "crashing" or "")

      row.zebra:SetShown(idx % 2 == 0)
      row.sel:SetShown(sel); row.selBar:SetShown(sel); row.selTop:SetShown(sel); row.selBottom:SetShown(sel)
      row.farm = f
      row:Show()
    else
      row.farm = nil
      row:Hide()
    end
  end
end

local function RowOnEnter(self)
  local f = self.farm
  if not f then return end
  GameTooltip:SetOwner(self, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 14, 0)
  GameTooltip:AddLine(f.name or "?", 1, 1, 1)
  GameTooltip:AddLine(ZoneLine(f), 0.78, 0.78, 0.78)
  local gph = ns.FarmGPH(f)
  if gph then GameTooltip:AddLine("About " .. ns.FormatGold(gph) .. " an hour at your scanned prices", C.custard[1], C.custard[2], C.custard[3]) end
  if f.difficulty then
    local dc = DIFF[f.difficulty] or C.custard
    GameTooltip:AddLine("Difficulty: " .. f.difficulty .. "/5 (" .. (DIFF_WORD[f.difficulty] or "?") .. ")", dc[1], dc[2], dc[3])
  end
  local ok, reasons = ns.CanDo(f)
  if not ok then
    local r = {}
    for _, s in ipairs(reasons) do r[#r + 1] = Capitalise(s) end
    GameTooltip:AddLine(table.concat(r, ", "), C.red[1], C.red[2], C.red[3], true)
  end
  local thin, crashing = Flags(f)
  if thin then GameTooltip:AddLine("Thin market: few listed in your latest scan", C.clay[1], C.clay[2], C.clay[3]) end
  if crashing then GameTooltip:AddLine("Crashing: main item's price fell 40%+ this week", C.red[1], C.red[2], C.red[3]) end
  if f.dynamic then GameTooltip:AddLine("Live find from your Auctionator scans", C.live[1], C.live[2], C.live[3]) end
  for i, h in ipairs(ns.FarmHotItems(f)) do
    if i > 3 then break end
    GameTooltip:AddLine(string.format("%s: %d%% above usual", h.item.name, (h.market.spike - 1) * 100), C.clay[1], C.clay[2], C.clay[3])
  end
  GameTooltip:Show()
end

---------------------------------------------------------------- empty list state
local function UpdateEmpty()
  local e = frame.empty
  local info = state.info
  if #state.list > 0 then e:Hide(); return end
  local bracket = ns.data.brackets[state.bracket] or "?"
  if info.total == 0 then
    e.title:SetText("No farms listed yet")
    e.body:SetText("Nobody has reported a farm for Levels " .. bracket .. " yet. Try a nearby bracket.")
    e.button:Hide()
  else
    local parts = {}
    local a, b = info.hiddenCan, info.hiddenFlag
    if a > 0 then parts[#parts + 1] = a .. (a == 1 and " needs" or " need") .. " a class or profession you don't have" end
    if b > 0 then parts[#parts + 1] = b .. (b == 1 and " is" or " are") .. " thin or crashing" end
    e.title:SetText("No farms match your filters")
    e.body:SetText(string.format("All %d farms for Levels %s are hidden: %s.", info.total, bracket, table.concat(parts, ", ")))
    e.button:Show()
  end
  -- centre the block vertically: emblem 56, 10px, title, 8px, body[, 14px, button]
  local th, bh = e.title:GetStringHeight(), e.body:GetStringHeight()
  local total = 56 + 10 + th + 8 + bh + (e.button:IsShown() and (14 + 22) or 0)
  e.emblem:SetPoint("TOP", e, "TOP", 0, -math.floor((e:GetHeight() - total) / 2))
  e:Show()
end

---------------------------------------------------------------- detail panel
-- A small vertical layout engine over pooled font strings, textures, pills and hit boxes.
local Doc = { y = 0, fs = {}, nfs = 0, pools = {} }
local DOC_X = 12
local CHILD_W = DETAIL_W - 4 - BAR_ROOM
local DOC_W = CHILD_W - DOC_X * 2

function Doc:Acquire(kind, make)
  local p = self.pools[kind]
  if not p then p = { n = 0 }; self.pools[kind] = p end
  p.n = p.n + 1
  local o = p[p.n]
  if not o then o = make(); p[p.n] = o end
  o:ClearAllPoints()
  o:Show()
  return o
end

function Doc:Begin()
  for i = 1, self.nfs do self.fs[i]:Hide(); self.fs[i]:ClearAllPoints() end
  for _, p in pairs(self.pools) do
    for i = 1, p.n do p[i]:Hide(); p[i]:ClearAllPoints() end
    p.n = 0
  end
  self.nfs = 0
  self.y = 12
end

function Doc:At(o, x, y) o:SetPoint("TOPLEFT", self.child, "TOPLEFT", DOC_X + x, -y) end

-- opts: font, size, color, top, x, w, justify, wrap, spacing, advance(false = don't move cursor), y, shadow
function Doc:Text(text, o)
  o = o or {}
  self.nfs = self.nfs + 1
  local fs = self.fs[self.nfs]
  if not fs then fs = FS(self.child, NARROW, 12, C.custard); self.fs[self.nfs] = fs end
  fs:SetFont(o.font or NARROW, o.size or 13, "")
  local c = o.color or C.custard
  fs:SetTextColor(c[1], c[2], c[3])
  if o.shadow then fs:SetShadowColor(o.shadow[1], o.shadow[2], o.shadow[3], o.shadow[4] or 1)
  else fs:SetShadowColor(0, 0, 0, 1) end
  fs:SetJustifyH(o.justify or "LEFT")
  local wrap = o.wrap ~= false
  fs:SetWordWrap(wrap)
  fs:SetNonSpaceWrap(o.nonSpace and true or false)
  fs:SetSpacing(wrap and (o.spacing or 3) or 0)
  fs:SetWidth(o.w or (DOC_W - (o.x or 0)))
  fs:SetText(text)
  local y = o.y or (self.y + (o.top or 0))
  fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", DOC_X + (o.x or 0), -y)
  fs:Show()
  local h = fs:GetStringHeight()
  if o.advance ~= false then self.y = y + h end
  return fs, h, y
end

function Doc:Rect(x, y, w, h, color, alpha, layer, sub)
  local t = self:Acquire("rect", function() return self.child:CreateTexture(nil, "BACKGROUND") end)
  t:SetDrawLayer(layer or "BACKGROUND", sub or 0)
  t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  self:At(t, x, y)
  t:SetSize(w, h)
  return t
end

function Doc:Grad(x, y, w, h, orient, c1, c2, a1, a2, layer, sub)
  local t = self:Acquire("grad", function() return self.child:CreateTexture(nil, "BORDER") end)
  t:SetDrawLayer(layer or "BORDER", sub or 1)
  Gradient(t, orient, c1, c2, a1, a2)
  self:At(t, x, y)
  t:SetSize(w, h)
  return t
end

-- Panel/tile: fill, 1px edge, optional top highlight and left accent bar.
function Doc:Box(x, y, w, h, o)
  o = o or {}
  if o.fill2 then
    self:Grad(x, y, w, h, "VERTICAL", o.bg or C.black, o.fill2, o.bgA or 0.4, o.fill2A or 0.4, "BACKGROUND", 1)
  else
    self:Rect(x, y, w, h, o.bg or C.black, o.bgA or 0.35, "BACKGROUND", 1)
  end
  local e, ea = o.edge or C.paneLine, o.edgeA or 1
  if ns.Flat() then
    if not o.accent then self:Rect(x, y, w, 1, C.white, 0.09, "BORDER", 2) end
  else
    self:Rect(x, y, w, 1, e, ea, "BORDER", 2)
    self:Rect(x, y + h - 1, w, 1, e, ea, "BORDER", 2)
    self:Rect(x, y + 1, 1, h - 2, e, ea, "BORDER", 2)
    self:Rect(x + w - 1, y + 1, 1, h - 2, e, ea, "BORDER", 2)
  end
  if o.hi and not ns.Flat() then self:Rect(x + 1, y + 1, w - 2, 1, o.hi, o.hiA or 0.2, "BORDER", 3) end
  if o.accent then self:Rect(x, y, 2, h, o.accent, 1, "BORDER", 4) end
end

function Doc:Icon(file, x, y, size, o)
  o = o or {}
  self:Rect(x - 1, y - 1, size + 2, size + 2, o.edge or C.black, 1, "ARTWORK", 0)
  local t = self:Acquire("icon", function() return self.child:CreateTexture(nil, "ARTWORK", nil, 1) end)
  t:SetDrawLayer("ARTWORK", 1)
  t:SetTexture(file or QUESTION)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t:SetDesaturated(o.desat and true or false)
  t:SetAlpha(o.alpha or 1)
  self:At(t, x, y)
  t:SetSize(size, size)
  return t
end

function Doc:Diamond(x, y, size, color, alpha)
  local t = self:Acquire("diamond", function()
    local d = self.child:CreateTexture(nil, "ARTWORK", nil, 2)
    d:SetTexture(Media("Diamond32"))
    return d
  end)
  t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  self:At(t, x, y)
  t:SetSize(size, size)
  return t
end

-- Returns the pill and its width; position it with Doc:At.
function Doc:Pill(label, color, filled)
  local p = self:Acquire("pill", function() return MakePill(self.child, 15, 10) end)
  return p, SetPill(p, label, color, filled)
end

function Doc:Pips(n, color, x, y, size, gap)
  local p = self:Acquire("pips", function() return MakePips(self.child) end)
  SetPips(p, n, color, size, gap)
  self:At(p, x, y)
  return p
end

-- Invisible hover box that shows an item's tooltip.
function Doc:ItemHit(id, x, y, w, h)
  if not id then return end
  local b = self:Acquire("hit", function()
    local hb = CreateFrame("Button", nil, self.child)
    hb:SetScript("OnEnter", function(s) ShowItemTip(s, s.itemID) end)
    hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hb:SetScript("OnClick", function(s)
      if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
        local _, link = GetItemInfo(s.itemID)
        if link then ChatEdit_InsertLink(link) end
      end
    end)
    return hb
  end)
  b.itemID = id
  self:At(b, x, y)
  b:SetSize(w, h)
  return b
end

-- Section heading: diamond, uppercase title, rule fading out to the right.
function Doc:Heading(text)
  local y = self.y + 16
  local flat = ns.Flat()
  local tx = flat and 0 or 14
  if not flat then self:Diamond(0, y + 1, 9, C.mustard) end
  local fs, h = self:Text(flat and text or text:upper(), { font = FRIZ, size = flat and 12 or 11, color = C.mustard, x = tx, y = y, wrap = false, advance = false })
  local tw = math.ceil(fs:GetStringWidth())
  local lx = tx + tw + 8
  if lx < DOC_W then
    if flat then self:Grad(lx, y + 6, DOC_W - lx, 1, "HORIZONTAL", C.white, C.white, 0.14, 0)
    else self:Grad(lx, y + 5, DOC_W - lx, 1, "HORIZONTAL", C.bronze, C.bronze, 0.75, 0) end
  end
  self.y = y + h + 8
end

-- Tinted callout box with a left accent bar.
function Doc:Callout(text, color, o)
  o = o or {}
  local y = self.y + (o.top or 6)
  local _, h = self:Text(text, { x = 12, w = DOC_W - 20, y = y + 7, color = o.textColor or C.custard, size = o.size or 13, advance = false })
  local bh = h + 14
  self:Box(0, y, DOC_W, bh, { bg = color, bgA = 0.1, edge = color, edgeA = 0.3, accent = color })
  self.y = y + bh
end

-- Row of equal tiles: { label, value text | draw(x, y, w) }, height h.
function Doc:Tiles(tiles, h, o)
  o = o or {}
  local n = #tiles
  local gap = 6
  local tw = math.floor((DOC_W - gap * (n - 1)) / n)
  local y = self.y + (o.top or 8)
  for i, t in ipairs(tiles) do
    local x = (i - 1) * (tw + gap)
    if ns.Flat() then
      self:Box(x, y, tw, h, { bg = C.white, bgA = 0.05 })
    else
      self:Box(x, y, tw, h, { bg = C.black, bgA = 0.45, fill2 = C.coffee, fill2A = 0.55, hi = C.bronze, hiA = 0.22 })
    end
    self:Text(t[1]:upper(), { size = 10, color = ns.Flat() and GREY or C.bronze, x = x + 8, w = tw - 12, y = y + 7, wrap = false, advance = false })
    local vy = y + (o.valueY or 20)
    if type(t[2]) == "function" then
      t[2](x + 8, vy, tw - 12)
    else
      self:Text(t[2] or "?", { font = o.valueFont or FRIZ, size = o.valueSize or 15, color = t[2] and (t[3] or C.custard) or C.bronze,
        x = x + 8, w = tw - 12, y = vy, wrap = false, advance = false })
    end
  end
  self.y = y + h
end

-- Table: cols = { {label}, {label, w}, ... } (first column flexes; the rest right-aligned).
-- rows = { { cell1, cell2, ..., icon =, itemID =, color =, nameColor =, dim = } }
function Doc:Table(cols, rows, o)
  o = o or {}
  local xs, right = {}, DOC_W - 4
  for i = #cols, 2, -1 do right = right - cols[i][2]; xs[i] = right; right = right - 6 end
  local firstW = right
  local y = self.y + (o.top or 8)
  self:Rect(0, y, DOC_W, 18, C.black, 0.5, "BACKGROUND", 1)
  self:Rect(0, y + 18, DOC_W, 1, C.bronze, 0.4, "BORDER", 1)
  for i, c in ipairs(cols) do
    self:Text(c[1]:upper(), { size = 10, color = C.bronze, x = i == 1 and 4 or xs[i], w = i == 1 and (firstW - 4) or c[2],
      y = y + 5, wrap = false, justify = i == 1 and "LEFT" or "RIGHT", advance = false })
  end
  y = y + 19
  local rh = 19
  for r, row in ipairs(rows) do
    if r % 2 == 0 then self:Rect(0, y, DOC_W, rh, C.custard, 0.045, "BACKGROUND", 1) end
    local nx = 4
    if row.icon then
      self:Icon(row.icon, 4, y + 2, 15, { desat = row.dim, alpha = row.dim and 0.55 or 1 })
      nx = 25
    end
    if row.itemID then self:ItemHit(row.itemID, 0, y, firstW, rh) end
    for i = 1, #cols do
      local col = i == 1 and (row.nameColor or row.color) or row.color
      self:Text(row[i] or "", { size = 12, color = col or C.custard, x = i == 1 and nx or xs[i], w = i == 1 and (firstW - nx) or cols[i][2],
        y = y + 4, wrap = false, justify = i == 1 and "LEFT" or "RIGHT", advance = false })
    end
    y = y + rh
  end
  self:Rect(0, y, DOC_W, 1, C.bronze, 0.4, "BORDER", 1)
  self.y = y + 1
end

local function FormatQty(q)
  if type(q) == "string" then return q end
  if not q then return "1" end
  if q == math.floor(q) then return tostring(q) end
  return string.format("%.1f", q)
end

local function FormatChance(c) -- fraction 0-1
  if not c then return "?" end
  local p = c * 100
  if p < 10 and p ~= math.floor(p) then return string.format("%.1f%%", p) end
  return string.format("%.0f%%", p)
end

local function AgeText(days)
  if not days then return nil end
  if days <= 0 then return "today" elseif days == 1 then return "1 day old" end
  return days .. " days old"
end

-- Main item header for the Market section: icon, name, flag pills.
local function MarketItemHeader(name, id, quality, thin, crashing)
  local y = Doc.y + 2
  Doc:Icon(ItemIcon(id) or QUESTION, 1, y + 1, 20, { edge = quality and QUALITY[quality] or C.black })
  local fs, h = Doc:Text(name or "Main item", { size = 14, color = C.mustard, x = 28, y = y + 4, wrap = false, advance = false })
  local x = 28 + math.ceil(fs:GetStringWidth()) + 8
  Doc:ItemHit(id, 0, y, x, 22)
  if thin then local p, w = Doc:Pill("thin", C.clay); Doc:At(p, x, y + 4); x = x + w + 4 end
  if crashing then local p = Doc:Pill("crashing", C.red); Doc:At(p, x, y + 4) end
  Doc.y = y + 22
end

-- Market section for farms with Loot.lua data, priced from your Auctionator scans.
local function MarketLive(f)
  local L, live = f.loot, ns.LiveFarm(f)
  local hasAH = ns.HasAuctionator()
  local thin, crashing = Flags(f)

  -- main item: name, badges, live price / listed / 7-day change
  local mainIt
  for _, it in ipairs(L.items) do if it.id == live.main then mainIt = it end end
  if mainIt then
    MarketItemHeader(mainIt.name, mainIt.id, mainIt.quality, thin, crashing)
    local m = hasAH and ns.ItemMarket(mainIt.id) or {}
    local changeText, changeColor
    if m.change then
      changeText = string.format("%+.0f%%", m.change)
      changeColor = crashing and C.red or (m.change > 0 and C.live or C.custard)
    end
    Doc:Tiles({
      { "Your price", Money(m.price) },
      { "Listed", ns.FormatInt(m.listed), (thin and C.clay) or nil },
      { "7-day", changeText, changeColor },
    }, 40, { top = 6, valueFont = NARROW, valueSize = 14, valueY = 19 })
    if m.usual then
      Doc:Text(Col("bronze", "Usual price (14-day average): ") .. Money(m.usual), { size = 12, top = 5 })
    end
  end

  -- loot table: Item | /hr | Price | g/hr
  local rows, anyEst, missingProf = {}, false, {}
  for _, it in ipairs(L.items) do
    local counts = ns.LootCounts(f, it)
    local m = hasAH and ns.ItemMarket(it.id) or {}
    local name = it.name
    if it.src == "est" then name = name .. Col("bronze", "*"); anyEst = true end
    local perHr = it.perHour >= 10 and string.format("%.0f", it.perHour) or string.format("%.1f", it.perHour)
    local gph = (m.price and counts) and Coins(ns.FormatGold(m.price / 10000 * it.perHour)) or "-"
    local row = { name, perHr, Money(m.price) or "-", gph, icon = ItemIcon(it.id) or QUESTION, itemID = it.id }
    if counts then
      row.color, row.nameColor = C.custard, QualityColor(it)
    else
      missingProf[ns.TitleCase(it.prof)] = true
      row[4] = "-"
      row.color, row.nameColor, row.dim = C.cantDo, C.cantDo, true
    end
    rows[#rows + 1] = row
  end
  Doc:Table({ { "Loot" }, { "/hr", 30 }, { "Price", 50 }, { "g/hr", 48 } }, rows, { top = 10 })

  -- totals and notes
  if not hasAH then
    Doc:Callout("Install Auctionator to price these items from your own AH scans.", C.clay, { top = 8 })
  elseif live.priced == 0 then
    Doc:Callout("None of these items are in your Auctionator scans yet. Open the auction house and scan them.", C.clay, { top = 8 })
  else
    local y = Doc.y + 6
    Doc:Text("Gold / hr", { font = FRIZ, size = 11, color = C.bronze, y = y + 3, wrap = false, advance = false })
    local _, vh = Doc:Text(APPROX .. " " .. CoinIcons(live.gph, 14), { font = FRIZ, size = 15, color = C.mustard, y = y,
      wrap = false, justify = "RIGHT", advance = false })
    Doc.y = y + vh
    local age = live.oldest or 0
    local ageColor = age <= 1 and C.live or (age <= 3 and C.custard or C.clay)
    local ageText = live.newest == live.oldest and AgeText(age) or (AgeText(live.newest) .. " to " .. AgeText(age))
    local ay = Doc.y + 4
    Doc:Diamond(0, ay + 2, 8, ageColor)
    Doc:Text(string.format("Prices %s  " .. DOT .. "  %d of %d items priced", ageText, live.priced, live.counted),
      { size = 12, color = ageColor, x = 13, y = ay, advance = true })
  end
  local notes = {}
  if L.staticGold then
    notes[#notes + 1] = string.format("Includes %s %s per hour of %s.", APPROX, ns.FormatGold(L.staticGold), L.staticGoldLabel or "estimated extras")
    notes[#notes + 1] = string.format("Assumes %d pools per hour; fish per pool from pools.csv.", L.poolsPerHour or 15)
  elseif L.kph then
    notes[#notes + 1] = string.format("Assumes %d kills per hour. Drop rates from classic-db and Wowhead.", L.kph)
  end
  if anyEst then notes[#notes + 1] = "* No recorded drop rate; the amount is an estimate." end
  local need = {}
  for p in pairs(missingProf) do need[#need + 1] = p end
  if #need > 0 then notes[#notes + 1] = "Greyed rows need " .. table.concat(need, ", ") .. " and aren't counted." end
  notes[#notes + 1] = "AH loot only: coin and vendor greys are extra."
  Doc:Text(table.concat(notes, " "), { size = 11, color = C.bronze, top = 6 })

  -- scan button (auction house open)
  local b = frame.scanButton
  if ns.CanScan() then
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", Doc.child, "TOPLEFT", DOC_X, -(Doc.y + 8))
    b.farm = f
    b:Show()
    Doc.y = Doc.y + 8 + b:GetHeight()
  else
    b:Hide()
  end
end

local function MarketLegacy(f, m)
  local thin, crashing = Flags(f)
  MarketItemHeader(m.item, m.itemId, nil, thin, crashing)
  local changeColor, changeText = C.custard, nil
  if m.change then
    changeText = string.format("%+.0f%%", m.change)
    if crashing then changeColor = C.red elseif m.change > 0 then changeColor = C.live end
  end
  Doc:Tiles({
    { "Listed", ns.FormatInt(m.listed) },
    { "Sold / day", m.perDay and ("~" .. ns.FormatInt(m.perDay)) },
    { "7-day", changeText, changeColor },
  }, 40, { top = 6, valueFont = NARROW, valueSize = 14, valueY = 19 })
  local scan = ns.ItemMarket(m.itemId).price
  if scan then Doc:Text("Your Auctionator scan: " .. Money(scan), { color = C.live, top = 6 }) end
  Doc:Text(string.format("Community AH snapshot, %s. Your own scan is used when it's newer.", ns.data.meta.market or "US Normal Alliance"),
    { size = 11, color = C.bronze, top = 5 })
end

-- Wrapping row of pills / labels.
local Flow = {}
function Flow:Start(y) self.x, self.y, self.lineH, self.used = 0, y, 15, false end
function Flow:Place(obj, w, dy)
  if self.x > 0 and self.x + w > DOC_W then self.x = 0; self.y = self.y + self.lineH + 5 end
  obj:ClearAllPoints()
  Doc:At(obj, self.x, self.y + (dy or 0))
  self.x = self.x + w + 5
  self.used = true
end
function Flow:Label(text)
  local fs = Doc:Text(text, { size = 11, color = C.bronze, wrap = false, advance = false, y = self.y })
  self:Place(fs, math.ceil(fs:GetStringWidth()), 1)
end
function Flow:Pill(label, color, filled)
  local p, w = Doc:Pill(label, color, filled)
  self:Place(p, w)
end
function Flow:Finish() if self.used then Doc.y = self.y + self.lineH end end

local function BuildDetail(f)
  Doc:Begin()
  frame.scanButton:Hide()
  local ok, reasons = ns.CanDo(f)

  -- hero: icon, name (map button beside it), zone
  local y0 = Doc.y
  local icon, iconID, rec = FarmIcon(f)
  Doc:Icon(icon, 1, y0 + 1, 38, { edge = rec and QUALITY[rec.quality or 1] or C.bronze, desat = not ok })
  Doc:Grad(1, y0 + 1, 38, 14, "VERTICAL", C.white, C.white, 0.14, 0, "ARTWORK", 3) -- glossy top
  Doc:ItemHit(iconID, 0, y0, 40, 40)
  local hasLoc = ns.HasLocation(f)
  local mb = frame.mapButton
  mb.farm = f
  if hasLoc then
    mb:ClearAllPoints()
    mb:SetPoint("TOPRIGHT", Doc.child, "TOPLEFT", DOC_X + DOC_W, -y0)
    mb:Show()
  else
    mb:Hide()
  end
  local nameW = DOC_W - 50 - (hasLoc and (mb:GetWidth() + 6) or 0)
  local _, nh = Doc:Text(f.name or "?", { font = FRIZ, size = 14, color = C.mustard, x = 50, w = nameW, y = y0, spacing = 2, advance = false })
  local _, zh = Doc:Text(ZoneLine(f), { size = 12, color = C.bronze, x = 50, w = DOC_W - 50, y = y0 + nh + 3, advance = false })
  Doc.y = y0 + math.max(40, nh + 3 + zh)

  -- chips: live/hot tag, requirements, class
  Flow:Start(Doc.y + 9)
  local tag = ns.FarmTag(f)
  if tag then Flow:Pill(tag == "HOT" and "Price spike" or "Live find", tag == "HOT" and C.clay or C.live, true) end
  local req = f.profReq or f.requires or {}
  if #req > 0 then
    Flow:Label(f.profReqMode == "any" and "Needs one of" or "Requires")
    for _, p in ipairs(req) do
      local have = ns.HasProf(p) or (f.profReqMode == "any" and ns.ProfsOK(f))
      Flow:Pill(ns.TitleCase(p), have and C.live or C.red)
    end
  end
  local bonus = f.profOpt or f.bonusWith or {}
  if #bonus > 0 then
    Flow:Label("Bonus with")
    for _, p in ipairs(bonus) do Flow:Pill(ns.TitleCase(p), ns.HasProf(p) and C.live or C.bronze) end
  end
  local cls = f.classText or f.class
  if cls then
    Flow:Label("Class")
    Flow:Pill(cls, ns.ClassOK(f) and C.live or C.red)
  end
  Flow:Finish()

  -- stat tiles
  local gphText
  local live = ns.FarmGPH(f)
  if live then gphText = CoinIcons(live, 14) else local s = ns.FormatGPH(f); gphText = s and Coins(s) end
  local d = f.difficulty
  local score = ns.FarmScore(f)
  Doc:Tiles({
    { "Gold / hr", gphText, C.mustard },
    { "Difficulty", function(x, y, w)
        if d then
          Doc:Pips(d, DIFF[d] or C.custard, x, y + 2, 9, 2)
          Doc:Text(DIFF_WORD[d] or "", { size = 11, color = DIFF[d] or C.custard, x = x, w = w, y = y + 14, wrap = false, advance = false })
        else
          Doc:Text("?", { font = FRIZ, size = 15, color = C.bronze, x = x, w = w, y = y, wrap = false, advance = false })
        end
      end },
    { "Score", score and string.format("%.1f", score) },
  }, 50, { top = 10 })
  local src = GoldSource(f)
  if src then Doc:Text(src, { size = 11, color = C.bronze, top = 5 }) end

  -- farming session: start one here, or jump to the one already running on this farm
  do
    local b, s = frame.sessionButton, ns.Session()
    local st = ns.SessionState(s)
    local here = st and st ~= "finished" and s.farm == f.name and s.bracket == f.bracket
    b.farm, b.here = f, here
    b.label:SetText(here and "Session running: open tracker" or "Start farming session")
    b:SetWidth(math.ceil(b.label:GetStringWidth()) + 24)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", Doc.child, "TOPLEFT", DOC_X, -(Doc.y + 10))
    b:Show()
    Doc.y = Doc.y + 10 + 22
  end

  if not ok then Doc:Callout("You can't run this yet: " .. table.concat(reasons, ", ") .. ".", C.red, { top = 8 }) end

  -- live find / price spikes
  local hot = ns.FarmHotItems(f)
  if f.dynamic or #hot > 0 then
    Doc:Heading(#hot > 0 and "Price spike" or "Live find")
    if f.dynamic then
      Doc:Text(string.format("Picked from your latest Auctionator scans: what %s drop is worth about %s per hour at today's prices.",
        ns.Plural(f.name), Money((ns.FarmGPH(f) or 0) * 10000)))
    end
    for i, h in ipairs(hot) do
      local m = h.market
      Doc:Callout(string.format("%s sells at %s, %s%d%%|r above its 14-day average of %s%s.",
        Col("mustard", h.item.name), Money(m.price), "|c" .. HEX.clay .. "+", (m.spike - 1) * 100, Money(m.usual),
        m.listed and string.format(" (%s listed)", ns.FormatInt(m.listed)) or ""), C.clay, { top = (i == 1 and not f.dynamic) and 0 or 6 })
    end
    if #hot > 0 then
      Doc:Text("Spikes often fade once more people post. Check how many are listed before committing.",
        { size = 11, color = C.bronze, top = 5 })
    end
  end

  -- how to: numbered steps
  local steps = HowToSteps(f)
  if #steps > 0 then
    Doc:Heading("How to")
    for i, s in ipairs(steps) do
      local y = Doc.y + (i == 1 and 0 or 7)
      Doc:Rect(0, y, 18, 18, C.black, 1, "BORDER", 0)
      Doc:Grad(1, y + 1, 16, 16, "VERTICAL", C.clay, C.clayBottom, 1, 1, "BORDER", 1)
      Doc:Rect(1, y + 1, 16, 1, C.clayHi, 1, "BORDER", 2)
      Doc:Text(tostring(i), { font = FRIZ, size = 10, color = C.coffee, x = 0, w = 18, y = y + 4, wrap = false,
        justify = "CENTER", advance = false, shadow = { 1, 0.88, 0.67, 0.5 } })
      local _, h = Doc:Text(s, { x = 26, y = y + 2, advance = false })
      Doc.y = y + math.max(18, h + 2)
    end
  end
  -- notes
  if f.notes and f.notes ~= "" then
    Doc:Heading("Notes")
    Doc:Text(f.notes)
  end
  -- market
  Doc:Heading("Market")
  local m = Market(f)
  if f.loot and f.loot.items and #f.loot.items > 0 then
    MarketLive(f)
  elseif m then
    MarketLegacy(f, m)
  else
    Doc:Text("No market data for this farm yet.", { color = C.bronze })
  end
  -- container (fishing)
  local c = Container(f)
  if c then
    Doc:Heading("Container")
    Doc:Text(c.name or "?", { size = 14, color = C.mustard })
    local ev = {}
    if c.ev then ev[#ev + 1] = Col("bronze", "Expected value ") .. Col("custard", APPROX .. " ") .. Coins(ns.FormatGold(c.ev)) end
    if c.perHour then ev[#ev + 1] = Col("custard", string.format("~%s", FormatQty(c.perHour))) .. Col("bronze", " per hour") end
    if #ev > 0 then Doc:Text(table.concat(ev, Col("bronze", "  " .. DOT .. "  ")), { top = 2 }) end
    if #c.loot > 0 then
      local rows = {}
      for _, it in ipairs(c.loot) do
        local name = it.name or (it.itemId and GetItemInfo and GetItemInfo(it.itemId)) or ("item " .. tostring(it.itemId or "?"))
        rows[#rows + 1] = { name, FormatChance(it.chance), FormatQty(it.qty), icon = it.itemId and ItemIcon(it.itemId) or nil,
          itemID = it.itemId, nameColor = QualityColor(it) }
      end
      Doc:Table({ { "Loot" }, { "Chance", 44 }, { "Qty", 30 } }, rows)
    end
    if #c.pools > 0 then
      local rows = {}
      for _, p in ipairs(c.pools) do rows[#rows + 1] = { p.name or "?", p.value or "?" } end
      Doc:Table({ { "Pools" }, { "Value", 110 } }, rows, { top = 10 })
    end
    Doc:Text(c.caveat or "Drop chances use Classic Era data and may differ on WoW Forever.", { size = 11, color = C.bronze, top = 6 })
  end
  -- source URL (click to copy)
  local url = f.sourceUrl
  if url then
    local _, h, y = Doc:Text(url, { size = 11, color = C.bronze, top = 12, nonSpace = true })
    local b = frame.urlButton
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", Doc.child, "TOPLEFT", DOC_X, -y)
    b:SetSize(DOC_W, h)
    b.url = url
    b:Show()
  else
    frame.urlButton:Hide()
  end

  Doc.child:SetHeight(Doc.y + 14)
end

local function UpdateDetail()
  local f = state.selected
  local scroll, bar = frame.detailScroll, frame.detailBar
  if not f then
    Doc:Begin()
    frame.urlButton:Hide()
    frame.scanButton:Hide()
    frame.mapButton:Hide()
    frame.sessionButton:Hide()
    Doc.child:SetHeight(1)
    frame.noSel:Show()
    state.shownDetail = nil
  else
    frame.noSel:Hide()
    BuildDetail(f)
  end
  if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
  local viewH = scroll:GetHeight()
  bar:SetRange(Doc.child:GetHeight(), viewH)
  bar.page = math.max(20, viewH - 40)
  if f and state.shownDetail ~= f then bar:SetValue(0) end
  scroll:SetVerticalScroll(bar.value)
  state.shownDetail = f
end

---------------------------------------------------------------- header / footer
local function UpdateHeader()
  local data = ns.data
  local mine = ns.BracketIndexForLevel(ns.player.level) == state.bracket
  frame.bracketLabel:SetText("Levels " .. (data.brackets[state.bracket] or "?"))
  frame.prev:SetEnabled(state.bracket > 1)
  frame.next:SetEnabled(state.bracket < #data.brackets)
  if mine then
    frame.myLevel:Hide()
    SetPill(frame.youPill, "Your level " .. ns.player.level, C.live)
  else
    frame.youPill:Hide()
    frame.myLevel:Show()
  end
  frame.onlyCheck:SetChecked(FarmerJoeDB.filters.onlyCanDo)
  frame.hideCheck:SetChecked(FarmerJoeDB.filters.hideFlagged)
end

local function UpdateFooter()
  local info = state.info
  local hot = 0
  for _, f in ipairs(state.list) do if ns.FarmTag(f) == "HOT" then hot = hot + 1 end end
  local parts = { Col("custard", #state.list .. (#state.list == 1 and " farm" or " farms")) }
  if (info.live or 0) > 0 then parts[#parts + 1] = Col("live", info.live .. " live") end
  if hot > 0 then parts[#parts + 1] = Col("clay", hot .. " hot") end
  if info.hidden > 0 then parts[#parts + 1] = Col("bronze", info.hidden .. " hidden by filters") end
  frame.footLeft:SetText(table.concat(parts, Col("bronze", "  " .. DOT .. "  ")))

  local hasAH = ns.HasAuctionator()
  local dc = hasAH and C.live or C.cantRank
  frame.ahDot:SetVertexColor(dc[1], dc[2], dc[3])
  frame.ahText:SetText(hasAH and (ns.ahOpen and "Auctionator  " .. DOT .. "  auction house open" or "Prices: your Auctionator scans")
    or "Auctionator not loaded: no live prices")

  frame.footScan:SetShown(ns.CanScan() and #state.list > 0)
  frame.ahText:ClearAllPoints()
  if frame.footScan:IsShown() then
    frame.ahText:SetPoint("RIGHT", frame.footScan, "LEFT", -10, 0)
  else
    frame.ahText:SetPoint("RIGHT", frame.footScan:GetParent(), "RIGHT", 0, -1)
  end
  frame.footRight:SetShown(info.anySeed)
end

---------------------------------------------------------------- refresh
function ns.Refresh()
  if not frame or not frame:IsShown() then return end
  if not state.bracket then state.bracket = ns.BracketIndexForLevel(ns.player.level) end
  state.list, state.info = ns.FarmsForBracket(state.bracket)

  local keep = false
  for _, f in ipairs(state.list) do if f == state.selected then keep = true break end end
  if not keep then state.selected = state.list[1] end

  UpdateHeader()
  UpdateList()
  UpdateEmpty()
  UpdateDetail()
  UpdateFooter()
end

local function SetBracket(i)
  state.bracket = math.max(1, math.min(#ns.data.brackets, i))
  state.selected = nil
  state.shownDetail = nil
  ScrollListTop()
  ns.Refresh()
end

function ns.OnPlayerChanged(levelChanged)
  ns.Refresh()
end

---------------------------------------------------------------- build
local function SavePosition()
  local point, _, relPoint, x, y = frame:GetPoint(1)
  FarmerJoeDB.window = { point = point, relativePoint = relPoint, x = x, y = y }
end

local function RestorePosition()
  local w = FarmerJoeDB.window or {}
  frame:ClearAllPoints()
  frame:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or w.point or "CENTER", w.x or 0, w.y or 0)
end

StaticPopupDialogs.FARMERJOE_COPY_URL = {
  text = "Press Ctrl+C to copy the link.",
  button1 = CLOSE or "Close",
  hasEditBox = true,
  editBoxWidth = 280,
  OnShow = function(self, data)
    local eb = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    if eb then eb:SetText(data or self.data or ""); eb:HighlightText(); eb:SetFocus() end
  end,
  EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs.FARMERJOE_NEW_SESSION = {
  text = "End your current session (%s) and start a new one?",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function(self, farm)
    ns.StopSession()
    ns.StartSession(farm or self.data)
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function BuildChrome()
  if ns.Flat() then FlatChrome(frame); return end
  -- soft drop shadow outside the frame
  for i = 1, 8 do Edge(frame, -i, 1, C.black, 0.32 * (1 - i / 9) ^ 1.5, "BACKGROUND", -8) end

  -- background: gradient, grain, vignette
  local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
  bg:SetAllPoints()
  Gradient(bg, "VERTICAL", C.frameTop, C.coffee)
  local grain = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  grain:SetPoint("TOPLEFT", EDGE, -EDGE); grain:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
  grain:SetTexture(Media("Grain128"), "REPEAT", "REPEAT")
  grain:SetTexCoord(0, (W - EDGE * 2) / 128, 0, (H - EDGE * 2) / 128)
  if grain.SetHorizTile then grain:SetHorizTile(true); grain:SetVertTile(true) end
  grain:SetAlpha(0.7)
  local vig = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
  vig:SetPoint("TOPLEFT", EDGE, -EDGE); vig:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
  vig:SetTexture(Media("Vignette256"))

  -- border (outside in: 1 black, 2 Golden Bronze, 1 Coffee Bean, 1 black) + a faint inner glint
  Edge(frame, 0, 1, C.black, 1, "BORDER", 0)
  Edge(frame, 1, 2, C.bronze, 1, "BORDER", 0)
  local glint = Solid(frame, "BORDER", 1, C.clayHi, 0.45)
  glint:SetPoint("TOPLEFT", 1, -1); glint:SetPoint("TOPRIGHT", -1, -1); glint:SetHeight(1)
  Edge(frame, 3, 1, C.coffee, 1, "BORDER", 0)
  Edge(frame, 4, 1, C.black, 1, "BORDER", 0)

  -- corner filigree (bottom corners; the portrait and close button own the top ones)
  local function Corner(point, l, r, t, b)
    local c = frame:CreateTexture(nil, "OVERLAY")
    c:SetTexture(Media("Corner64"))
    c:SetSize(34, 34)
    c:SetPoint(point, 0, 0)
    c:SetTexCoord(l, r, t, b)
    c:SetVertexColor(C.bronze[1], C.bronze[2], C.bronze[3], 0.95)
  end
  Corner("BOTTOMLEFT", 0, 1, 1, 0)
  Corner("BOTTOMRIGHT", 1, 0, 1, 0)
end

local function BuildTitleBar()
  if ns.Flat() then
    local bar = FlatTitle(frame, "Farmer Joe", "Gold farms for your level", function() frame:Hide() end, 15, Media("Emblem128"))
    bar:SetHeight(EDGE + TITLE_H)
    bar:SetFrameLevel(frame:GetFrameLevel() + 5)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition() end)
    local writs = FlatButton(bar, "Writs", 11, nil, 18)
    writs:SetPoint("RIGHT", bar.close, "LEFT", -6, 0)
    writs:SetScript("OnClick", function() if ns.ToggleWritsWindow then ns.ToggleWritsWindow() end end)
    writs:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine("Craftsman's Writs", 1, 1, 1)
      GameTooltip:AddLine("Every writ priced from your Auctionator scans, cheapest to fill first.", 0.78, 0.78, 0.78, true)
      GameTooltip:Show()
    end)
    writs:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.writsButton = writs
    return
  end
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetPoint("TOPLEFT", EDGE, -EDGE)
  bar:SetPoint("TOPRIGHT", -EDGE, -EDGE)
  bar:SetHeight(TITLE_H + 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT"); bg:SetPoint("BOTTOMRIGHT", 0, 1)
  Gradient(bg, "VERTICAL", C.titleTop, C.coffee)
  local shine = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
  shine:SetPoint("TOPLEFT"); shine:SetPoint("TOPRIGHT"); shine:SetHeight(1)
  shine:SetColorTexture(C.clayHi[1], C.clayHi[2], C.clayHi[3], 0.18)
  local line = Solid(bar, "BORDER", 0, C.bronze)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
  local under = Solid(bar, "BORDER", 0, C.black, 0.6)
  under:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0); under:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0); under:SetHeight(2)

  local title = FS(bar, FRIZ, 15, C.mustard)
  title:SetJustifyH("CENTER"); title:SetJustifyV("MIDDLE")
  title:SetPoint("CENTER", 0, 0)
  title:SetText("Farmer Joe")
  title:SetShadowOffset(1, -1)

  -- ornaments: diamond + rule fading outward on each side of the title
  local tw = math.ceil(title:GetStringWidth())
  for _, side in ipairs({ -1, 1 }) do
    local d = bar:CreateTexture(nil, "ARTWORK")
    d:SetTexture(Media("Diamond32"))
    d:SetSize(8, 8)
    d:SetPoint("CENTER", bar, "CENTER", side * (tw / 2 + 12), 0)
    d:SetVertexColor(C.mustard[1], C.mustard[2], C.mustard[3])
    local rule = bar:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetWidth(120)
    if side < 0 then
      rule:SetPoint("RIGHT", d, "LEFT", -4, 0)
      Gradient(rule, "HORIZONTAL", C.bronze, C.bronze, 0, 0.9)
    else
      rule:SetPoint("LEFT", d, "RIGHT", 4, 0)
      Gradient(rule, "HORIZONTAL", C.bronze, C.bronze, 0.9, 0)
    end
  end

  local sub = FS(bar, NARROW, 11, C.bronze)
  sub:SetJustifyV("MIDDLE")
  sub:SetPoint("LEFT", bar, "LEFT", 70, 0)
  sub:SetText("Gold farms for your level")

  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() frame:StartMoving() end)
  bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition() end)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetSize(26, 26)
  close:SetPoint("CENTER", frame, "TOPRIGHT", -18, -18)
  close:SetFrameLevel(bar:GetFrameLevel() + 5)
  close:SetScript("OnClick", function() frame:Hide() end)

  local writs = ClayButton(frame, "Writs", 11, nil, 18)
  writs:SetPoint("RIGHT", close, "LEFT", -2, 0)
  writs:SetFrameLevel(bar:GetFrameLevel() + 5)
  writs:SetScript("OnClick", function() if ns.ToggleWritsWindow then ns.ToggleWritsWindow() end end)
  writs:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Craftsman's Writs", 1, 1, 1)
    GameTooltip:AddLine("Every writ priced from your Auctionator scans, cheapest to fill first.", 0.78, 0.78, 0.78, true)
    GameTooltip:Show()
  end)
  writs:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.writsButton = writs
end

local function BuildPortrait()
  if ns.Flat() then return end
  -- 66px emblem circle, top-left at (-16, -18), drawn above the border. The texture carries a 72px
  -- design area (outline + shadow), so it sits 3px further out.
  local p = CreateFrame("Frame", nil, frame)
  p:SetSize(72, 72)
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", -19, 18 + 2)
  p:SetFrameLevel(frame:GetFrameLevel() + 20)
  local t = p:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture(Media("Emblem128"))
end

local function BuildHeader()
  local hdr = CreateFrame("Frame", nil, frame)
  hdr:SetPoint("TOPLEFT", ns.Flat() and PAD or (1 + 58), -HEADER_Y)
  hdr:SetPoint("TOPRIGHT", -PAD, -HEADER_Y)
  hdr:SetHeight(HEADER_H)
  hdr:SetFrameLevel(frame:GetFrameLevel() + 4)

  frame.prev = ArrowButton(hdr, "Prev")
  frame.prev:SetPoint("LEFT", 0, 0)
  frame.prev:SetScript("OnClick", function() SetBracket(state.bracket - 1) end)

  -- inset plate holding the bracket name
  local plate = CreateFrame("Frame", nil, hdr)
  plate:SetSize(132, 24)
  plate:SetPoint("LEFT", frame.prev, "RIGHT", 2, 0)
  local pbg = plate:CreateTexture(nil, "BACKGROUND")
  pbg:SetPoint("TOPLEFT", 1, -1); pbg:SetPoint("BOTTOMRIGHT", -1, 1)
  if ns.Flat() then
    pbg:SetAllPoints()
    pbg:SetColorTexture(1, 1, 1, 0.06)
  else
    Gradient(pbg, "VERTICAL", C.black, C.coffee, 0.75, 0.55)
    Edge(plate, 0, 1, C.paneLine, 1, "BORDER")
    local pin = Solid(plate, "BORDER", 1, C.black, 0.8)
    pin:SetPoint("TOPLEFT", 1, -1); pin:SetPoint("TOPRIGHT", -1, -1); pin:SetHeight(1)
  end

  frame.bracketLabel = FS(plate, FRIZ, 13, C.mustard)
  frame.bracketLabel:SetJustifyH("CENTER"); frame.bracketLabel:SetJustifyV("MIDDLE")
  frame.bracketLabel:SetAllPoints()

  frame.next = ArrowButton(hdr, "Next")
  frame.next:SetPoint("LEFT", plate, "RIGHT", 2, 0)
  frame.next:SetScript("OnClick", function() SetBracket(state.bracket + 1) end)

  frame.myLevel = ClayButton(hdr, "My level", 11)
  frame.myLevel:SetPoint("LEFT", frame.next, "RIGHT", 8, 0)
  frame.myLevel:SetScript("OnClick", function()
    ns.ScanPlayer()
    SetBracket(ns.BracketIndexForLevel(ns.player.level))
  end)
  frame.youPill = MakePill(hdr, 18, 10)
  frame.youPill:SetPoint("LEFT", frame.next, "RIGHT", 8, 0)

  frame.hideCheck = Checkbox(hdr, "Hide thin/crashing", "hideFlagged")
  frame.hideCheck:SetPoint("RIGHT", 0, 0)
  frame.onlyCheck = Checkbox(hdr, "Only farms I can do", "onlyCanDo")
  frame.onlyCheck:SetPoint("RIGHT", frame.hideCheck, "LEFT", -16, 0)
end

-- Inset panel background shared by the list and the detail pane.
local function Inset(panel, top, bottom)
  if ns.Flat() then
    local bg = Solid(panel, "BACKGROUND", 0, C.black, 0.32)
    bg:SetAllPoints()
    return bg
  end
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
  Gradient(bg, "VERTICAL", top, bottom, 0.82, 0.9)
  Edge(panel, 0, 1, C.paneLine, 1, "BORDER", 0)
  Edge(panel, 1, 1, C.black, 0.55, "BORDER", 1)
  local outer = Edge(panel, -1, 1, C.custard, 0.05, "BORDER", 0) -- faint lip outside the pane
  return bg, outer
end

local function BuildList()
  local list = CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", PAD, -BODY_Y)
  list:SetPoint("BOTTOMLEFT", PAD, BODY_BOTTOM)
  list:SetWidth(LIST_W)
  frame.list = list
  Inset(list, C.black, C.black)

  -- column header
  local colBg = list:CreateTexture(nil, "BACKGROUND", nil, 1)
  colBg:SetPoint("TOPLEFT", 1, -1); colBg:SetPoint("TOPRIGHT", -1, -1); colBg:SetHeight(COLHEAD_H)
  if ns.Flat() then colBg:SetColorTexture(1, 1, 1, 0.05) else Gradient(colBg, "VERTICAL", C.colTop, C.coffee) end
  local colLine = Solid(list, "BORDER", 2, ns.Flat() and C.white or C.bronze, ns.Flat() and 0.12 or 0.6)
  colLine:SetPoint("TOPLEFT", 1, -1 - COLHEAD_H); colLine:SetPoint("TOPRIGHT", -1, -1 - COLHEAD_H); colLine:SetHeight(1)
  local shade = list:CreateTexture(nil, "BACKGROUND", nil, 2) -- soft shadow under the header
  shade:SetPoint("TOPLEFT", 1, -2 - COLHEAD_H); shade:SetPoint("TOPRIGHT", -1, -2 - COLHEAD_H); shade:SetHeight(8)
  Gradient(shade, "VERTICAL", C.black, C.black, 0.45, 0)
  shade:SetShown(not ns.Flat())

  -- `cols` tracks the rows' width so headers stay aligned when the scroll bar shows.
  local cols = CreateFrame("Frame", nil, list)
  cols:SetPoint("TOPLEFT", 1, -1)
  cols:SetPoint("TOPRIGHT", -1, -1)
  cols:SetHeight(COLHEAD_H)
  frame.cols = cols
  local function Head(text, justify, w)
    local fs = FS(cols, FRIZ, 10, ns.Flat() and GREY or C.mustard)
    fs:SetJustifyV("MIDDLE"); fs:SetJustifyH(justify or "LEFT")
    fs:SetHeight(COLHEAD_H)
    if w then fs:SetWidth(w) end
    fs:SetText(text)
    return fs
  end
  Head("#", "RIGHT", 18):SetPoint("LEFT", cols, "LEFT", 4, 0)
  Head("FARM"):SetPoint("LEFT", cols, "LEFT", COL_NAME_X, 0)
  Head("GOLD / HR", "RIGHT", COL_GOLD_W):SetPoint("RIGHT", cols, "RIGHT", -COL_GOLD_R, 0)
  Head("DIFFICULTY", "LEFT", COL_DIFF_W + 20):SetPoint("LEFT", cols, "RIGHT", -COL_DIFF_R - COL_DIFF_W, 0)
  Head("FLAGS", "RIGHT", COL_FLAGS_W):SetPoint("RIGHT", cols, "RIGHT", -COL_FLAGS_R, 0)

  -- scrolling
  frame.listBar = SlimBar(list, function(v)
    state.offset = math.floor(v + 0.5)
    UpdateList()
  end)
  frame.listBar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -(1 + COLHEAD_H + 5))
  frame.listBar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -4, 5)
  frame.listBar.page = NUM_ROWS - 1
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta)
    frame.listBar:SetValue(state.offset - delta * 2, true)
  end)

  frame.rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -(1 + COLHEAD_H + 1) - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -(1 + COLHEAD_H + 1) - (i - 1) * ROW_H)
    row:SetFrameLevel(list:GetFrameLevel() + 2)

    row.zebra = Solid(row, "BACKGROUND", 0, C.custard, 0.035)
    row.zebra:SetAllPoints()
    row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.sel:SetAllPoints()
    Gradient(row.sel, "HORIZONTAL", C.mustard, C.mustard, 0.24, 0.03)
    row.selBar = Solid(row, "BORDER", 1, C.mustard, 1)
    row.selBar:SetPoint("TOPLEFT"); row.selBar:SetPoint("BOTTOMLEFT"); row.selBar:SetWidth(3)
    row.selTop = Solid(row, "BORDER", 0, C.mustard, 0.35)
    row.selTop:SetPoint("TOPLEFT"); row.selTop:SetPoint("TOPRIGHT"); row.selTop:SetHeight(1)
    row.selBottom = Solid(row, "BORDER", 0, C.mustard, 0.35)
    row.selBottom:SetPoint("BOTTOMLEFT"); row.selBottom:SetPoint("BOTTOMRIGHT"); row.selBottom:SetHeight(1)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Gradient(hl, "HORIZONTAL", C.custard, C.custard, 0.10, 0.02)

    row.rank = FS(row, FRIZ, 12, C.bronze)
    row.rank:SetJustifyH("RIGHT"); row.rank:SetJustifyV("MIDDLE")
    row.rank:SetSize(18, ROW_H)
    row.rank:SetPoint("LEFT", row, "LEFT", 4, 0)

    local iconEdge = Solid(row, "ARTWORK", 0, C.black, 1)
    iconEdge:SetSize(26, 26)
    iconEdge:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("CENTER", iconEdge, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = FS(row, NARROW, 13, C.custard)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", COL_NAME_X, -3)
    row.name:SetPoint("RIGHT", row, "RIGHT", -COL_NAME_R, 0)
    row.name:SetHeight(14)

    row.tag = MakePill(row, 11, 9)
    row.tag:SetPoint("TOPLEFT", row, "TOPLEFT", COL_NAME_X, -17)
    row.sub = FS(row, NARROW, 11, C.bronze)
    row.sub:SetJustifyV("MIDDLE")
    row.sub:SetHeight(11)

    row.gold = FS(row, NARROW, 13, C.custard)
    row.gold:SetJustifyH("RIGHT")
    row.gold:SetSize(COL_GOLD_W, 14)
    row.gold:SetPoint("TOPRIGHT", row, "TOPRIGHT", -COL_GOLD_R, -4)
    row.meterBg = Solid(row, "ARTWORK", 0, C.black, 0.6)
    row.meterBg:SetSize(COL_GOLD_W, 4)
    row.meterBg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -COL_GOLD_R, -21)
    row.meter = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.meter:SetHeight(2)
    row.meter:SetPoint("LEFT", row.meterBg, "LEFT", 1, 0)
    Gradient(row.meter, "HORIZONTAL", C.clayBottom, C.mustard)

    row.pips = MakePips(row)
    row.pips:SetPoint("LEFT", row, "RIGHT", -COL_DIFF_R - COL_DIFF_W, 0)

    row.thin = MakePill(row, 12, 9)
    row.crash = MakePill(row, 12, 9)

    row:SetScript("OnClick", function(self)
      if not self.farm then return end
      state.selected = self.farm
      UpdateList(); UpdateDetail()
    end)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.rows[i] = row
  end

  -- empty state (covers the rows area)
  local e = CreateFrame("Frame", nil, list)
  e:SetPoint("TOPLEFT", 1, -(1 + COLHEAD_H + 1))
  e:SetPoint("BOTTOMRIGHT", -1, 1)
  e:SetFrameLevel(list:GetFrameLevel() + 6)
  e.emblem = e:CreateTexture(nil, "ARTWORK")
  e.emblem:SetTexture(Media("Emblem128"))
  e.emblem:SetSize(56, 56)
  e.emblem:SetAlpha(0.45)
  e.emblem:SetDesaturated(true)
  e.title = FS(e, FRIZ, 14, C.mustard)
  e.title:SetJustifyH("CENTER")
  e.title:SetWidth(LIST_W - 2 - 96)
  e.title:SetPoint("TOP", e.emblem, "BOTTOM", 0, -10)
  e.body = FS(e, NARROW, 13, C.custard)
  e.body:SetJustifyH("CENTER")
  e.body:SetWordWrap(true)
  e.body:SetSpacing(5)
  e.body:SetWidth(LIST_W - 2 - 96)
  e.body:SetPoint("TOP", e.title, "BOTTOM", 0, -8)
  e.button = ClayButton(e, "Show all farms", 11)
  e.button:SetSize(math.ceil(e.button.label:GetStringWidth()) + 26, 22)
  e.button:SetPoint("TOP", e.body, "BOTTOM", 0, -14)
  e.button:SetScript("OnClick", function()
    FarmerJoeDB.filters.onlyCanDo = false
    FarmerJoeDB.filters.hideFlagged = false
    ns.Refresh()
  end)
  e:Hide()
  frame.empty = e
end

local function BuildDetailPanel()
  local panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", PAD + LIST_W + GAP, -BODY_Y)
  panel:SetPoint("BOTTOMRIGHT", -PAD, BODY_BOTTOM)
  Inset(panel, C.detailTop, C.detailBottom)
  -- warm light at the top of the pane
  local glow = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOPLEFT", 2, -2); glow:SetPoint("TOPRIGHT", -2, -2); glow:SetHeight(70)
  Gradient(glow, "VERTICAL", C.bronze, C.bronze, 0.10, 0)
  glow:SetShown(not ns.Flat())

  local scroll = CreateFrame("ScrollFrame", "FarmerJoeDetailScroll", panel)
  scroll:SetPoint("TOPLEFT", 2, -2)
  scroll:SetPoint("BOTTOMRIGHT", -(2 + BAR_ROOM), 2)
  frame.detailScroll = scroll

  local bar = SlimBar(panel, function(v) scroll:SetVerticalScroll(v) end)
  bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -6)
  bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 6)
  bar.step = 40
  frame.detailBar = bar
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, delta) bar:Scroll(delta) end)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(CHILD_W, 1)
  scroll:SetScrollChild(child)
  Doc.child = child

  local url = CreateFrame("Button", nil, child)
  url:SetScript("OnClick", function(self) StaticPopup_Show("FARMERJOE_COPY_URL", nil, nil, self.url) end)
  url:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Click to copy the link", 1, 1, 1)
    GameTooltip:Show()
  end)
  url:SetScript("OnLeave", function() GameTooltip:Hide() end)
  url:Hide()
  frame.urlButton = url

  -- map button: a small map picture; opens the world map with pins on the farm's mobs
  local mb = CreateFrame("Button", nil, child)
  mb:SetSize(30, 30)
  local mbBg = Solid(mb, "BACKGROUND", 0, C.black, 1)
  mbBg:SetAllPoints()
  local mbIcon = mb:CreateTexture(nil, "ARTWORK")
  mbIcon:SetPoint("TOPLEFT", 2, -2); mbIcon:SetPoint("BOTTOMRIGHT", -2, 2)
  mbIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local mbEdge = Edge(mb, 0, 1, C.bronze, 1, "OVERLAY")
  local mbGloss = mb:CreateTexture(nil, "OVERLAY", nil, 1)
  mbGloss:SetPoint("TOPLEFT", 2, -2); mbGloss:SetPoint("TOPRIGHT", -2, -2); mbGloss:SetHeight(11)
  Gradient(mbGloss, "VERTICAL", C.white, C.white, 0.18, 0)
  local mbHl = mb:CreateTexture(nil, "HIGHLIGHT")
  mbHl:SetPoint("TOPLEFT", 2, -2); mbHl:SetPoint("BOTTOMRIGHT", -2, 2)
  mbHl:SetColorTexture(1, 1, 1, 0.2)
  mbHl:SetBlendMode("ADD")
  mb:SetScript("OnMouseDown", function() mbIcon:SetPoint("TOPLEFT", 3, -3); mbIcon:SetPoint("BOTTOMRIGHT", -1, 1) end)
  mb:SetScript("OnMouseUp", function() mbIcon:SetPoint("TOPLEFT", 2, -2); mbIcon:SetPoint("BOTTOMRIGHT", -2, 2) end)
  mb:SetScript("OnClick", function(self) if self.farm then ns.ShowFarmOnMap(self.farm) end end)
  mb:SetScript("OnEnter", function(self)
    for _, e in ipairs(mbEdge) do e:SetColorTexture(C.mustard[1], C.mustard[2], C.mustard[3], 1) end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Show on the world map", 1, 1, 1)
    local _, zone, pts = ns.FarmLocation(self.farm)
    if zone then GameTooltip:AddLine(string.format("%s, %d spawn points", zone, #pts), 0.78, 0.78, 0.78) end
    GameTooltip:Show()
  end)
  mb:SetScript("OnLeave", function()
    for _, e in ipairs(mbEdge) do e:SetColorTexture(C.bronze[1], C.bronze[2], C.bronze[3], 1) end
    GameTooltip:Hide()
  end)
  mb:Hide()
  frame.mapButton = mb

  local scan = ClayButton(child, "Scan these items", 11, nil, 20)
  scan:SetScript("OnClick", function(self) if self.farm then ns.ScanItems(ns.FarmItemIDs({ self.farm })) end end)
  scan:Hide()
  frame.scanButton = scan

  local sb = ClayButton(child, "Start farming session", 11, nil, 22)
  sb:SetScript("OnClick", function(self)
    if self.here then ns.ShowSessionWindow(); return end
    local st = ns.SessionState()
    if st == "running" or st == "paused" then
      StaticPopup_Show("FARMERJOE_NEW_SESSION", ns.Session().farm or "free farming", nil, self.farm)
    else
      ns.StartSession(self.farm)
    end
  end)
  sb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(self.here and "Open the session tracker" or "Track a farming session here", 1, 1, 1)
    GameTooltip:AddLine("Records what you loot, your gold per hour, and whether to vendor or auction each item.", 0.78, 0.78, 0.78, true)
    GameTooltip:Show()
  end)
  sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  sb:Hide()
  frame.sessionButton = sb

  local noSel = CreateFrame("Frame", nil, panel)
  noSel:SetAllPoints()
  local nsText = FS(noSel, NARROW, 13, C.bronze)
  nsText:SetWordWrap(true)
  nsText:SetJustifyH("CENTER")
  nsText:SetWidth(DETAIL_W - 40)
  nsText:SetPoint("CENTER", 0, -20)
  nsText:SetText("Pick a farm on the left to see how to run it.")
  local ne = noSel:CreateTexture(nil, "ARTWORK")
  ne:SetTexture(Media("Emblem128"))
  ne:SetSize(64, 64)
  ne:SetPoint("BOTTOM", nsText, "TOP", 0, 12)
  ne:SetAlpha(0.4)
  ne:SetDesaturated(true)
  noSel:Hide()
  frame.noSel = noSel
end

local function BuildFooter()
  local foot = CreateFrame("Frame", nil, frame)
  foot:SetPoint("BOTTOMLEFT", PAD, 1 + 6)
  foot:SetPoint("BOTTOMRIGHT", -PAD, 1 + 6)
  foot:SetHeight(FOOT_H + 1)
  -- rule that fades in from the left and out to the right
  local left = foot:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT"); left:SetPoint("TOPRIGHT", foot, "TOP", 0, 0); left:SetHeight(1)
  if ns.Flat() then left:SetColorTexture(1, 1, 1, 0.08) else Gradient(left, "HORIZONTAL", C.bronze, C.bronze, 0, 0.6) end
  local right = foot:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPLEFT", foot, "TOP", 0, 0); right:SetPoint("TOPRIGHT"); right:SetHeight(1)
  if ns.Flat() then right:SetColorTexture(1, 1, 1, 0.08) else Gradient(right, "HORIZONTAL", C.bronze, C.bronze, 0.6, 0) end

  frame.footScan = ClayButton(foot, "Scan this bracket", 11, nil, 18)
  frame.footScan:SetPoint("RIGHT", 0, -1)
  frame.footScan:SetScript("OnClick", function() ns.ScanItems(ns.FarmItemIDs(state.list)) end)
  frame.footScan:Hide()

  frame.ahText = FS(foot, NARROW, 12, C.bronze)
  frame.ahText:SetJustifyV("MIDDLE")
  frame.ahText:SetPoint("RIGHT", 0, -1)
  frame.ahDot = foot:CreateTexture(nil, "ARTWORK")
  frame.ahDot:SetTexture(Media("Diamond32"))
  frame.ahDot:SetSize(8, 8)
  frame.ahDot:SetPoint("RIGHT", frame.ahText, "LEFT", -5, 0)

  frame.footRight = FS(foot, NARROW, 12, C.clay)
  frame.footRight:SetJustifyV("MIDDLE")
  frame.footRight:SetPoint("RIGHT", frame.ahDot, "LEFT", -12, 0)
  frame.footRight:SetText("Seed data: names only")

  frame.footLeft = FS(foot, NARROW, 12, C.bronze)
  frame.footLeft:SetJustifyV("MIDDLE")
  frame.footLeft:SetPoint("LEFT", ns.Flat() and 0 or 26, -1)
end

local function Build()
  frame = CreateFrame("Frame", "FarmerJoeFrame", UIParent)
  frame:SetSize(W, H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  if not ns.Flat() then frame:SetClampRectInsets(-19, 0, 20, 0) end -- keep the overhanging portrait on screen
  if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
  RestorePosition()
  tinsert(UISpecialFrames, "FarmerJoeFrame") -- Esc closes

  BuildChrome()
  BuildTitleBar()
  BuildHeader()
  BuildList()
  BuildDetailPanel()
  BuildFooter()
  BuildPortrait()

  frame:SetScript("OnShow", function()
    ns.ScanPlayer()
    if state.keep then
      state.keep = false -- reopened after the world map: stay on the same bracket and farm
    else
      state.bracket = ns.BracketIndexForLevel(ns.player.level)
      state.selected = nil
      state.shownDetail = nil
      ScrollListTop()
    end
    ns.Refresh()
  end)
  frame:SetScript("OnHide", function() GameTooltip:Hide() end)
  frame:Hide()

  -- redraw when a session starts or ends (the detail pane's session button changes)
  local lastKey
  ns.OnSessionChanged(function()
    local s = ns.Session()
    local key = tostring(ns.SessionState(s)) .. "|" .. tostring(s and s.farm) .. "|" .. tostring(s and s.started)
    if key ~= lastKey then lastKey = key; ns.Refresh() end
  end)

  -- item icons and names arrive from the server after first use: redraw once they do
  local pending = false
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  ev:SetScript("OnEvent", function()
    if pending or not frame:IsShown() then return end
    pending = true
    C_Timer.After(0.3, function() pending = false; ns.Refresh() end)
  end)
end

function ns.Toggle()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

function ns.Reopen()
  if not frame or frame:IsShown() then return end
  state.keep = true
  frame:Show()
end

function ns.ResetPosition()
  if not frame then Build() end
  FarmerJoeDB.window = { point = "CENTER", x = 0, y = 0 }
  RestorePosition()
  frame:Show()
end
