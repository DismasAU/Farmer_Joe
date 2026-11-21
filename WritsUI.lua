-- Farmer Joe: Craftsman's Writs, priced from your latest Auctionator scan.
-- A writ (a WoW: Forever item, "Craftsman's Writ: Earthen Silk Belt") starts a daily quest that is
-- handed in with the item in its title. This window prices every writ so the cheapest to fill is on
-- top: the item at the auction house (or its materials, when crafting is cheaper and that's turned
-- on), plus the writ itself when you don't already have one.
local addonName, ns = ...
local K = ns.Kit
local C, FS, Solid, Gradient, Edge = K.C, K.FS, K.Solid, K.Gradient, K.Edge
local FRIZ, NARROW, DOT = K.FRIZ, K.NARROW, K.DOT

local WW, WH = 530, 520
local PAD = 13
local ROW_H = 22
local LIST_Y = 150                       -- top of the list (below its column header)
local FOOT = 12 + 22 + 10
local NUM_ROWS = math.floor((WH - LIST_Y - FOOT - 4) / ROW_H)
local LIST_W = WW - PAD * 2
local ROW_W = LIST_W - 12                -- room for the slim scroll bar
local COL_TOTAL, COL_ITEM, COL_WRIT = 70, 64, 58
local TIER_COL = { C.custard, C.mustard, C.clay }
local TIER_SHORT = { "J", "E", "A" }

local win
local offset = 0

---------------------------------------------------------------- settings
local DEFAULTS = { tier = 0, withWrit = true, craft = false, mine = false, hideDone = false, sort = "total" }
local function Opt()
  FarmerJoeDB.writs = FarmerJoeDB.writs or {}
  local o = FarmerJoeDB.writs
  for k, v in pairs(DEFAULTS) do if o[k] == nil then o[k] = v end end
  return o
end

---------------------------------------------------------------- data
local list -- ns.WRITS unpacked into records, once
local function Writs()
  if list then return list end
  list = {}
  for _, t in ipairs(ns.WRITS or {}) do
    list[#list + 1] = {
      writ = t[1], quest = t[2], item = t[3], count = t[4], tier = t[5], name = t[6], quality = t[7],
      prof = t[8], skill = t[9], mats = t[10] or {}, title = "Craftsman's Writ: " .. (t[11] or t[6]),
    }
  end
  return list
end
ns.WritList = Writs

local function AH(id) local m = ns.ItemMarket(id); return m and m.price end

-- What a vendor charges for an item, as Auctionator saw it at a merchant (nil if never seen).
local function VendorBuy(id)
  local a = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (a and a.GetVendorPriceByItemID) then return nil end
  local ok, p = pcall(a.GetVendorPriceByItemID, addonName, id)
  if ok and type(p) == "number" and p > 0 then return p end
end

local function Count(id, bank)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id, bank) or 0 end
  return GetItemCount and GetItemCount(id, bank) or 0
end

local function DoneToday(quest)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(quest) end
  return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(quest) or false
end

-- Materials for one craft: total copper and whether every reagent had a price.
local function MatsCost(w)
  if #w.mats == 0 then return nil, false end
  local total, complete = 0, true
  for i = 1, #w.mats, 2 do
    local id, n = w.mats[i], w.mats[i + 1]
    local each = VendorBuy(id) or AH(id)
    if each then total = total + each * n else complete = false end
  end
  return total, complete
end

-- Price one writ. Fields: itemCost (buying the item), matsCost/matsComplete, fill (what the item
-- costs you: 0 if you have it, else the cheaper of buying or, with crafting on, its materials),
-- writCost (0 if you have the writ), total, perRep, have, haveItem, done.
function ns.PriceWrit(w, o)
  o = o or Opt()
  local r = { w = w }
  r.have = Count(w.writ, true)
  r.haveItem = Count(w.item, true) >= w.count
  r.done = DoneToday(w.quest)
  local each = AH(w.item)
  r.itemCost = each and each * w.count
  r.matsCost, r.matsComplete = MatsCost(w)
  local craft = o.craft and r.matsComplete and r.matsCost and r.matsCost * w.count
  if r.haveItem then
    r.fill, r.via = 0, "have"
  elseif r.itemCost and (not craft or r.itemCost <= craft) then
    r.fill, r.via = r.itemCost, "buy"
  elseif craft then
    r.fill, r.via = craft, "craft"
  end
  r.writPrice = AH(w.writ)
  if r.have > 0 or not o.withWrit then r.writCost = 0 else r.writCost = r.writPrice end
  if r.fill and r.writCost then
    r.total = r.fill + r.writCost
    local rep = ns.WRIT_REP and ns.WRIT_REP[w.tier]
    if rep and rep > 0 then r.perRep = r.total / rep * 100 end
  end
  return r
end

-- Every writ that passes the filters, cheapest first (unpriced last, done-today after the rest).
function ns.WritRows(o)
  o = o or Opt()
  local rows, held = {}, 0
  for _, w in ipairs(Writs()) do
    local r = ns.PriceWrit(w, o)
    if r.have > 0 then held = held + 1 end
    if (o.tier == 0 or w.tier == o.tier) and (not o.mine or r.have > 0) and not (o.hideDone and r.done) then
      rows[#rows + 1] = r
    end
  end
  local key = o.sort == "rep" and "perRep" or "total"
  table.sort(rows, function(a, b)
    if a.done ~= b.done then return not a.done end
    local x, y = a[key], b[key]
    if (x ~= nil) ~= (y ~= nil) then return x ~= nil end
    if x and y and x ~= y then return x < y end
    if a.w.tier ~= b.w.tier then return a.w.tier < b.w.tier end
    return a.w.writ < b.w.writ
  end)
  return rows, held
end

-- Ask Auctionator to search every writ and the item each needs (and the materials, with crafting on).
function ns.ScanWrits(rows)
  local a = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (a and a.MultiSearchExact) then return end
  local o, names, seen = Opt(), {}, {}
  local function Add(id, fallback)
    local n = (GetItemInfo and GetItemInfo(id)) or fallback
    if n and not seen[n] then seen[n] = true; names[#names + 1] = n end
  end
  for _, r in ipairs(rows) do
    local w = r.w
    Add(w.writ, w.title)
    Add(w.item, w.name)
    if o.craft then for i = 1, #w.mats, 2 do Add(w.mats[i]) end end
  end
  if #names == 0 then return end
  local ok, err = pcall(a.MultiSearchExact, addonName, names)
  if ok then
    ns.Print(string.format("Auctionator is searching %d item%s for your writs. Prices update when it finishes.", #names, #names == 1 and "" or "s"))
  else
    ns.Print("Auctionator couldn't start the search: " .. tostring(err))
  end
end

---------------------------------------------------------------- helpers
local function Gold(copper, size) return K.CoinIcons((copper or 0) / 10000, size or 12) end
local function FullMoney(copper)
  if GetCoinTextureString then return GetCoinTextureString(math.floor(copper + 0.5)) end
  return K.Money(copper)
end
local function Sub() return ns.Flat() and K.GREY or C.bronze end
local DASH = "|cff7D7457-|r"

local function SavePosition()
  local l, t = win:GetLeft(), win:GetTop()
  if not (l and t) then return end
  win:ClearAllPoints()
  win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  FarmerJoeDB.writsWindow = { x = l, y = t }
end

---------------------------------------------------------------- update
local function Update()
  if not win or not win:IsShown() then return end
  local o = Opt()
  local rows, held = ns.WritRows(o)
  win.rowsData = rows

  -- headline: the cheapest one you can hand in today
  local best
  for _, r in ipairs(rows) do if r.total and not r.done then best = r; break end end
  if best then
    local q = K.QUALITY[best.w.quality] or C.custard
    win.best:SetText(string.format("|cff%02x%02x%02x%s|r  %s", math.floor(q[1] * 255), math.floor(q[2] * 255), math.floor(q[3] * 255),
      best.w.name, Gold(best.total, 14)))
    win.bestSub:SetText(string.format("%s writ  %s  %s%s", ns.WRIT_TIERS[best.w.tier], DOT,
      best.via == "have" and "you have the item" or (best.via == "craft" and "cheapest to craft" or "buy the item"),
      best.have > 0 and ("  " .. DOT .. "  " .. K.Col("live", "writ in your bags")) or ""))
  elseif not ns.HasAuctionator() then
    win.best:SetText("Auctionator isn't loaded")
    win.bestSub:SetText("Writs are priced from your Auctionator scans.")
  elseif #rows == 0 then
    win.best:SetText("Nothing to show")
    win.bestSub:SetText("No writs match these filters.")
  elseif rows[1].total then
    win.best:SetText("All done for today")
    win.bestSub:SetText("Every writ shown has been handed in today. Writs reset daily.")
  else
    win.best:SetText("No prices yet")
    win.bestSub:SetText("Open the auction house and press Scan writs.")
  end

  -- tier tabs and sort
  for i, b in ipairs(win.tabs) do
    local on = o.tier == (i - 1)
    local c = on and C.mustard or K.GREY
    b.color = c; b.text:SetTextColor(c[1], c[2], c[3])
    b.under:SetShown(on)
  end
  win.sortBtn.label:SetText(o.sort == "rep" and "Sort: per 100 rep" or "Sort: total cost")
  win.sortBtn:SetWidth(math.ceil(win.sortBtn.label:GetStringWidth()) + 20)
  for _, cb in ipairs(win.checks) do cb:SetChecked(o[cb.key]) end
  win.totalHead:SetText(o.sort == "rep" and "PER 100" or "TOTAL")

  -- rows
  win.bar:SetRange(#rows, NUM_ROWS)
  offset = math.max(0, math.min(offset, math.max(0, #rows - NUM_ROWS)))
  win.bar:SetValue(offset)
  for i, row in ipairs(win.rows) do
    local r = rows[i + offset]
    row.data = r
    if r then
      local w = r.w
      row.icon:SetTexture(K.ItemIcon(w.item) or K.QUESTION)
      local q = K.QUALITY[w.quality] or C.custard
      row.name:SetText((w.count > 1 and (w.count .. "x ") or "") .. w.name)
      row.name:SetTextColor(q[1], q[2], q[3])
      local tc = TIER_COL[w.tier] or C.custard
      row.tier:SetText(TIER_SHORT[w.tier] or "?")
      row.tier:SetTextColor(tc[1], tc[2], tc[3])
      row.writ:SetText(r.have > 0 and K.Col("live", "have") or (r.writPrice and Gold(r.writPrice) or DASH))
      if not o.withWrit and r.have == 0 then row.writ:SetAlpha(0.45) else row.writ:SetAlpha(1) end
      local itemText = r.via == "have" and K.Col("live", "have") or (r.fill and Gold(r.fill) or DASH)
      if r.via == "craft" then itemText = itemText .. K.Col("clay", "*") end
      row.item:SetText(itemText)
      local v = o.sort == "rep" and r.perRep or r.total
      row.total:SetText(v == 0 and K.Col("live", "free") or (v and Gold(v) or DASH))
      row.held:SetShown(r.have > 0)
      row:SetAlpha(r.done and 0.4 or 1)
      row:Show()
    else
      row:Hide()
    end
  end

  if #rows == 0 then
    win.empty:SetText(o.mine and "You don't have any Craftsman's Writs. Untick |cffF7CE5BOnly writs I have|r to see them all."
      or "No writs match these filters.")
    win.empty:Show()
  else
    win.empty:Hide()
  end

  -- footer
  local priced = 0
  for _, r in ipairs(rows) do if r.total then priced = priced + 1 end end
  win.foot:SetText(string.format("%d writs  %s  %d priced  %s  %d in your bags", #rows, DOT, priced, DOT, held))
  local canScan = ns.ahOpen and Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.MultiSearchExact
  win.scan:SetShown(canScan and true or false)
end
ns.UpdateWritsWindow = Update

---------------------------------------------------------------- build
local function Chrome()
  if ns.Flat() then K.FlatChrome(win); return end
  local bg = win:CreateTexture(nil, "BACKGROUND", nil, -7)
  bg:SetAllPoints()
  Gradient(bg, "VERTICAL", C.frameTop, C.coffee)
  for i = 1, 6 do Edge(win, -i, 1, C.black, 0.32 * (1 - i / 7) ^ 1.5, "BACKGROUND", -8) end
  Edge(win, 0, 1, C.black, 1, "BORDER", 0)
  Edge(win, 1, 2, C.bronze, 1, "BORDER", 0)
  Edge(win, 3, 1, C.coffee, 1, "BORDER", 0)
end

local function Hide() win:Hide() end

local function TitleBar()
  local bar
  if ns.Flat() then
    bar = K.FlatTitle(win, "Craftsman's Writs", "Cheapest to fill", Hide, 13)
  else
    bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("TOPLEFT", 5, -5); bar:SetPoint("TOPRIGHT", -5, -5)
    bar:SetHeight(25)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Gradient(bg, "VERTICAL", C.titleTop, C.coffee)
    local line = Solid(bar, "BORDER", 0, C.bronze)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    local t = FS(bar, FRIZ, 13, C.mustard)
    t:SetJustifyV("MIDDLE"); t:SetPoint("CENTER", 0, 0)
    t:SetText("Craftsman's Writs")
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("CENTER", win, "TOPRIGHT", -17, -17)
    close:SetFrameLevel(bar:GetFrameLevel() + 5)
    close:SetScript("OnClick", Hide)
  end
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() win:StartMoving() end)
  bar:SetScript("OnDragStop", function() win:StopMovingOrSizing(); SavePosition() end)
end

local function Tip(self, title, text)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(title, 1, 1, 1)
  GameTooltip:AddLine(text, 0.78, 0.78, 0.78, true)
  GameTooltip:Show()
end

local function RowTooltip(self)
  local r = self.data
  if not r then return end
  local w, o = r.w, Opt()
  K.ShowItemTip(self, w.writ)
  local L, V = { 0.78, 0.78, 0.78 }, { 1, 1, 1 }
  local function Line(a, b) GameTooltip:AddDoubleLine(a, b, L[1], L[2], L[3], V[1], V[2], V[3]) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Farmer Joe", C.mustard[1], C.mustard[2], C.mustard[3])
  Line("Hand in", (w.count > 1 and (w.count .. "x ") or "") .. w.name)
  Line("Item at auction", r.itemCost and FullMoney(r.itemCost) or "no price")
  if w.prof then
    local mats = r.matsCost and (FullMoney(r.matsCost * w.count) .. (r.matsComplete and "" or " +?")) or "no prices"
    Line(string.format("Materials (%s %d)", w.prof, w.skill or 0), mats)
  end
  Line("Writ at auction", r.writPrice and FullMoney(r.writPrice) or "no price")
  local rep = ns.WRIT_REP and ns.WRIT_REP[w.tier]
  Line("Reputation", (ns.WRIT_TIERS[w.tier] or "?") .. (rep and (", about " .. rep) or ""))
  if r.total then
    Line("Cost to fill", FullMoney(r.total))
    if r.perRep then Line("Per 100 reputation", FullMoney(r.perRep)) end
  end
  if r.have > 0 then GameTooltip:AddLine(string.format("You have %d of this writ, so it costs nothing.", r.have), C.live[1], C.live[2], C.live[3], true) end
  if r.via == "have" then GameTooltip:AddLine("You already have the item it asks for.", C.live[1], C.live[2], C.live[3], true) end
  if r.via == "craft" then GameTooltip:AddLine("Crafting it from materials is cheaper than buying it.", C.clay[1], C.clay[2], C.clay[3], true) end
  if r.matsCost and not r.matsComplete then GameTooltip:AddLine("Some materials have no price yet (vendor items are priced once Auctionator sees them at a merchant).", 0.6, 0.6, 0.6, true) end
  if r.done then GameTooltip:AddLine("Already handed in today. Writs reset daily.", C.clay[1], C.clay[2], C.clay[3], true) end
  if not o.withWrit and r.have == 0 then GameTooltip:AddLine("The writ's price isn't counted (Include writ price is off).", 0.6, 0.6, 0.6, true) end
  GameTooltip:AddLine(ns.ahOpen and "Click to search the auction house for the writ and its item." or "Shift-click to link the item.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function Row(i)
  local row = CreateFrame("Button", nil, win.list)
  row:SetSize(ROW_W, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  if i % 2 == 0 then
    local z = Solid(row, "BACKGROUND", 0, ns.Flat() and C.white or C.bronze, ns.Flat() and 0.03 or 0.06)
    z:SetAllPoints()
  end
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  Gradient(hl, "HORIZONTAL", C.mustard, C.mustard, 0.16, 0.02)
  row.held = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.held:SetAllPoints()
  Gradient(row.held, "HORIZONTAL", C.live, C.live, 0.18, 0)

  local edge = Solid(row, "ARTWORK", 0, C.black)
  edge:SetPoint("LEFT", 3, 0); edge:SetSize(18, 18)
  row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
  row.icon:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1); row.icon:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.total = FS(row, NARROW, 12, C.mustard)
  row.total:SetJustifyH("RIGHT"); row.total:SetJustifyV("MIDDLE")
  row.total:SetPoint("RIGHT", -4, 0); row.total:SetWidth(COL_TOTAL)
  row.item = FS(row, NARROW, 12, C.custard)
  row.item:SetJustifyH("RIGHT"); row.item:SetJustifyV("MIDDLE")
  row.item:SetPoint("RIGHT", row.total, "LEFT", -6, 0); row.item:SetWidth(COL_ITEM)
  row.writ = FS(row, NARROW, 12, C.custard)
  row.writ:SetJustifyH("RIGHT"); row.writ:SetJustifyV("MIDDLE")
  row.writ:SetPoint("RIGHT", row.item, "LEFT", -6, 0); row.writ:SetWidth(COL_WRIT)
  row.tier = FS(row, FRIZ, 11, C.custard)
  row.tier:SetJustifyH("CENTER"); row.tier:SetJustifyV("MIDDLE")
  row.tier:SetPoint("RIGHT", row.writ, "LEFT", -4, 0); row.tier:SetWidth(16)
  row.name = FS(row, NARROW, 12, C.custard)
  row.name:SetJustifyV("MIDDLE")
  row.name:SetPoint("LEFT", edge, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.tier, "LEFT", -4, 0)

  row:SetScript("OnEnter", RowTooltip)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    local r = self.data
    if not r then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
      local _, link = GetItemInfo(r.w.item)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    elseif ns.ahOpen then
      ns.ScanWrits({ r })
    end
  end)
  row:Hide()
  return row
end

local function Build()
  win = CreateFrame("Frame", "FarmerJoeWritsFrame", UIParent)
  win:SetSize(WW, WH)
  win:SetFrameStrata("HIGH")
  win:SetToplevel(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:SetClampedToScreen(true)
  if win.SetDontSavePosition then win:SetDontSavePosition(true) end
  local p = FarmerJoeDB.writsWindow
  if p then win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y) else win:SetPoint("CENTER", 120, 20) end
  tinsert(UISpecialFrames, "FarmerJoeWritsFrame")

  Chrome()
  TitleBar()

  -- headline: cheapest writ
  local y = 36
  local lbl = FS(win, NARROW, 10, Sub())
  lbl:SetPoint("TOPLEFT", PAD, -y)
  lbl:SetText("CHEAPEST TO FILL TODAY")
  win.best = FS(win, FRIZ, 14, C.custard)
  win.best:SetPoint("TOPLEFT", PAD, -(y + 13))
  win.best:SetWidth(LIST_W)
  win.bestSub = FS(win, NARROW, 11, Sub())
  win.bestSub:SetPoint("TOPLEFT", PAD, -(y + 32))
  win.bestSub:SetWidth(LIST_W)

  -- tier tabs + sort
  y = 88
  win.tabs = {}
  local prev
  for i, label in ipairs({ "All", "Journeyman", "Expert", "Artisan" }) do
    local b = K.TextButton(win, label, 12, K.GREY, nil, 18)
    b:SetWidth(math.ceil(b.text:GetStringWidth()) + 12)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", PAD - 6, -y) end
    b.under = Solid(b, "ARTWORK", 0, C.mustard, 0.9)
    b.under:SetPoint("BOTTOMLEFT", 6, 0); b.under:SetPoint("BOTTOMRIGHT", -6, 0); b.under:SetHeight(1)
    b:SetScript("OnClick", function() Opt().tier = i - 1; offset = 0; Update() end)
    win.tabs[i] = b
    prev = b
  end
  win.sortBtn = K.ClayButton(win, "Sort: total cost", 11, nil, 18)
  win.sortBtn:SetPoint("TOPRIGHT", -PAD, -y)
  win.sortBtn:SetScript("OnClick", function()
    local o = Opt(); o.sort = o.sort == "rep" and "total" or "rep"; offset = 0; Update()
  end)
  win.sortBtn:SetScript("OnEnter", function(self)
    Tip(self, "Sort order", "Total cost puts the cheapest writ on top. Per 100 rep weighs it by the reputation its tier gives "
      .. "(about 75 Journeyman, 125 Expert, 200 Artisan), so a pricier Artisan writ can come out ahead.")
  end)
  win.sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- options
  y = 112
  win.checks = {}
  local opts = {
    { "withWrit", "Include writ price", "Add the writ's auction price for writs you don't have, for when you buy writs to fill." },
    { "craft", "Craft when cheaper", "Use the materials' cost when crafting the item costs less than buying it (marked *)." },
    { "mine", "Only writs I have", "Show only writs in your bags or bank." },
    { "hideDone", "Hide done today", "Each writ can be handed in once a day. Hide the ones you've done." },
  }
  prev = nil
  for _, d in ipairs(opts) do
    local cb = K.Checkbox(win, d[2], nil, function(on) Opt()[d[1]] = on; offset = 0; Update() end)
    cb.key = d[1]
    if prev then cb:SetPoint("LEFT", prev, "RIGHT", 12, 0) else cb:SetPoint("TOPLEFT", PAD, -y) end
    cb:SetScript("OnEnter", function(self) Tip(self, d[2], d[3]) end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.checks[#win.checks + 1] = cb
    prev = cb
  end

  -- column header
  y = LIST_Y - 20
  local head = CreateFrame("Frame", nil, win)
  head:SetPoint("TOPLEFT", PAD, -y); head:SetSize(LIST_W, 18)
  local hbg = head:CreateTexture(nil, "BACKGROUND")
  hbg:SetAllPoints()
  if ns.Flat() then hbg:SetColorTexture(1, 1, 1, 0.05) else Gradient(hbg, "VERTICAL", C.colTop, C.coffee) end
  local hl = Solid(head, "BORDER", 0, ns.Flat() and C.white or C.bronze, ns.Flat() and 0.12 or 0.6)
  hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
  local function H(text, right, w, tip)
    local f = CreateFrame("Frame", nil, head)
    f:SetPoint("RIGHT", -right, 0); f:SetSize(w, 18)
    local t = FS(f, NARROW, 10, Sub())
    t:SetAllPoints(); t:SetJustifyH("RIGHT"); t:SetJustifyV("MIDDLE")
    t:SetText(text)
    if tip then
      f:EnableMouse(true)
      f:SetScript("OnEnter", function(self) Tip(self, tip[1], tip[2]) end)
      f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return t
  end
  local nameHead = FS(head, NARROW, 10, Sub())
  nameHead:SetJustifyV("MIDDLE"); nameHead:SetPoint("LEFT", 6, 0)
  nameHead:SetText("HAND IN")
  win.totalHead = H("TOTAL", 12 + 4, COL_TOTAL, { "Total", "What filling the writ costs: the item plus, if you don't have one, the writ." })
  H("ITEM", 12 + 4 + COL_TOTAL + 6, COL_ITEM, { "Item", "The item the writ asks for, at your Auctionator price (or its materials, marked *)." })
  H("WRIT", 12 + 4 + COL_TOTAL + 6 + COL_ITEM + 6, COL_WRIT, { "Writ", "The writ's own auction price. \"have\" means it's in your bags or bank." })
  local tierHead = H("TIER", 12 + 4 + COL_TOTAL + 6 + COL_ITEM + 6 + COL_WRIT + 4 - 6, 28,
    { "Tier", "J Journeyman, E Expert, A Artisan. Higher tiers give more reputation." })
  tierHead:SetJustifyH("CENTER")

  local listFrame = CreateFrame("Frame", nil, win)
  listFrame:SetPoint("TOPLEFT", PAD, -(LIST_Y + 2))
  listFrame:SetSize(LIST_W, NUM_ROWS * ROW_H)
  win.list = listFrame
  win.rows = {}
  for i = 1, NUM_ROWS do win.rows[i] = Row(i) end
  win.bar = K.SlimBar(listFrame, function(v) offset = v; Update() end)
  win.bar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -1, 0)
  win.bar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -1, 0)
  win.bar.page = NUM_ROWS - 1
  listFrame:EnableMouseWheel(true)
  listFrame:SetScript("OnMouseWheel", function(_, delta) win.bar:Scroll(delta * 3) end)

  win.empty = FS(win, NARROW, 12, Sub())
  win.empty:SetWordWrap(true)
  win.empty:SetJustifyH("CENTER")
  win.empty:SetWidth(LIST_W - 60)
  win.empty:SetPoint("TOP", listFrame, "TOP", 0, -40)

  -- footer
  local rule = Solid(win, "BORDER", 0, ns.Flat() and C.white or C.bronze, ns.Flat() and 0.1 or 0.5)
  rule:SetPoint("BOTTOMLEFT", PAD, 12 + 22 + 7); rule:SetPoint("BOTTOMRIGHT", -PAD, 12 + 22 + 7); rule:SetHeight(1)
  win.foot = FS(win, NARROW, 11, Sub())
  win.foot:SetJustifyV("MIDDLE")
  win.foot:SetPoint("BOTTOMLEFT", PAD, 12 + 5)
  win.scan = K.ClayButton(win, "Scan writs", 11, nil, 22)
  win.scan:SetPoint("BOTTOMRIGHT", -PAD, 12)
  win.scan:SetScript("OnClick", function() ns.ScanWrits(win.rowsData or {}) end)
  win.scan:SetScript("OnEnter", function(self)
    Tip(self, "Scan writs", "Search the auction house for every writ shown and the item each asks for"
      .. " (and their materials, with Craft when cheaper on). It can take a minute.")
  end)
  win.scan:SetScript("OnLeave", function() GameTooltip:Hide() end)
  win.scan:Hide()

  win:SetScript("OnShow", Update)
  win:SetScript("OnHide", function() GameTooltip:Hide() end)
  win:Hide()
end

---------------------------------------------------------------- public
function ns.ShowWritsWindow()
  if not win then Build() end
  win:Show()
  Update()
end

function ns.ToggleWritsWindow()
  if win and win:IsShown() then win:Hide() else ns.ShowWritsWindow() end
end

-- keep it current: new prices (ns.Refresh runs after each Auctionator update), bags, hand-ins, the AH
if ns.Refresh then hooksecurefunc(ns, "Refresh", function() Update() end) end
local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local queued = false
ev:SetScript("OnEvent", function()
  if queued or not (win and win:IsShown()) then return end
  queued = true
  C_Timer.After(0.3, function() queued = false; Update() end)
end)
