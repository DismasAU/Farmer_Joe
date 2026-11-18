-- Farmer Joe: minimap button (no library needed; position saved in LibDBIcon's format)
-- Click toggles the window. Drag to move it around the minimap edge.
local addonName, ns = ...

local BRONZE = { 0xAF / 255, 0x9B / 255, 0x46 / 255 }
local MUSTARD = { 0xF7 / 255, 0xCE / 255, 0x5B / 255 }

local button

local function DB() return FarmerJoeDB.minimap end

local function UpdatePosition()
  local angle = math.rad(DB().minimapPos or 215)
  local x, y = math.cos(angle), math.sin(angle)
  local r = (Minimap:GetWidth() / 2) + 5
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  if shape == "SQUARE" then
    -- push out to the corners of a square minimap, then clamp to its edge
    x = math.max(-1, math.min(1, x * 1.4142))
    y = math.max(-1, math.min(1, y * 1.4142))
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  DB().minimapPos = math.deg(math.atan2(cy - my, cx - mx)) % 360
  UpdatePosition()
end

local function SetHover(on)
  local c = on and MUSTARD or BRONZE
  button.ring:SetVertexColor(c[1], c[2], c[3])
  button.glow:SetShown(on)
  button.iconHi:SetShown(on)
end

local function Tex(layer, sub, file, size)
  local t = button:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(ns.MEDIA .. file)
  t:SetSize(size, size)
  t:SetPoint("CENTER", 0, 0)
  return t
end

local function Create()
  button = CreateFrame("Button", "FarmerJoeMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  -- Layers, back to front: hover glow, black disc with Coffee Bean inner line and black outer
  -- line, the emblem crop, a brightening copy for hover, then the tinted 2px ring.
  button.glow = Tex("BACKGROUND", -1, "MinimapGlow64", 64)
  button.base = Tex("BACKGROUND", 0, "MinimapBase64", 33)
  button.icon = Tex("ARTWORK", 0, "MinimapIcon64", 24)
  button.iconHi = Tex("ARTWORK", 1, "MinimapIcon64", 24)
  button.iconHi:SetBlendMode("ADD")
  button.iconHi:SetAlpha(0.15)
  button.ring = Tex("OVERLAY", 0, "MinimapRing64", 33)
  SetHover(false)

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      if ns.ToggleSessionWindow then ns.ToggleSessionWindow() end
      return
    end
    if ns.ScanPlayer then ns.ScanPlayer() end
    if ns.Toggle then ns.Toggle() end
  end)
  button:SetScript("OnDragStart", function(self)
    self.dragging = true
    self:SetScript("OnUpdate", OnDragUpdate)
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    if not self:IsMouseOver() then SetHover(false) end
  end)
  button:SetScript("OnEnter", function(self)
    SetHover(true)
    if self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Farmer Joe", 1, 1, 1)
    GameTooltip:AddLine("Click to open/close", 0.78, 0.78, 0.78)
    GameTooltip:AddLine("Right-click: farming session", 0.78, 0.78, 0.78)
    local st = ns.SessionState and ns.SessionState()
    if st == "running" or st == "paused" then
      local t = ns.SessionTotals()
      GameTooltip:AddLine(string.format("Session %s: %s%s", st, ns.FormatDuration(t.elapsed),
        t.gph and (", " .. ns.FormatGold(t.gph / 10000) .. "/hr") or ""), 0.97, 0.81, 0.36)
    end
    GameTooltip:AddLine("Drag to move", 0.78, 0.78, 0.78)
    GameTooltip:AddLine("/fj minimap to hide", 0.78, 0.78, 0.78)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function(self)
    if not self.dragging then SetHover(false) end
    GameTooltip:Hide()
  end)

  UpdatePosition()
  if DB().hide then button:Hide() else button:Show() end
end

function ns.ToggleMinimapButton()
  local m = DB()
  m.hide = not m.hide
  if not button then Create() end
  if m.hide then
    button:Hide()
    ns.Print("Minimap button hidden. Type /fj minimap to show it again.")
  else
    button:Show()
    ns.Print("Minimap button shown.")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", Create)
