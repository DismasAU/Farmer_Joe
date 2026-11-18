-- Farmer Joe: show a farm's mobs on the world map.
-- Opens the world map on the farm's zone, drops a Farmer Joe pin at the main spot and small dots
-- at the other spawn points, and sets the client's own waypoint (minimap / supertrack) when it can.
-- World map pins use a data provider and pin pool registered on WorldMapFrame without XML, the same
-- way HereBeDragons-Pins does on this client.
local addonName, ns = ...

local TEMPLATE = "FarmerJoeWorldMapPin"
local MUSTARD = { 0xF7 / 255, 0xCE / 255, 0x5B / 255 }

local active      -- { mapID, zone, points = { {x, y}, ... } (0-1), main = index, farm }
local provider    -- world map data provider (nil if the map API isn't available)
local hiddenForMap = false

---------------------------------------------------------------- location
-- Returns uiMapID, zone, { {x, y} ... } (0-1 coords), index of the main point; or nil.
function ns.FarmLocation(f)
  local m = f.map
  if not (m and m.id and m.points and #m.points >= 2) then return nil end
  local pts, sx, sy = {}, 0, 0
  for i = 1, #m.points - 1, 2 do
    local x, y = m.points[i] / 1000, m.points[i + 1] / 1000
    pts[#pts + 1] = { x, y }
    sx, sy = sx + x, sy + y
  end
  -- main pin: the spawn point nearest the middle of the group
  local cx, cy = sx / #pts, sy / #pts
  local best, bestD = 1, math.huge
  for i, p in ipairs(pts) do
    local d = (p[1] - cx) ^ 2 + (p[2] - cy) ^ 2
    if d < bestD then best, bestD = i, d end
  end
  return m.id, m.zone, pts, best
end

function ns.HasLocation(f) return ns.FarmLocation(f) ~= nil end

---------------------------------------------------------------- pins
local pinMixin

local function PinOnEnter(self)
  if not active then return end
  local f = active.farm
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(f.name, 1, 1, 1)
  local lv = f.mobLevels and (" " .. "\194\183" .. " mobs " .. f.mobLevels) or ""
  GameTooltip:AddLine((active.zone or "") .. lv, 0.78, 0.78, 0.78)
  GameTooltip:AddLine(self.isMain and "Farmer Joe: main spot" or "Farmer Joe: spawn point", MUSTARD[1], MUSTARD[2], MUSTARD[3])
  GameTooltip:AddLine("Right-click to clear the pins", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function BuildProvider()
  if provider ~= nil then return provider end
  provider = false
  local map = WorldMapFrame
  if not (map and map.AddDataProvider and map.pinPools and map.GetCanvas
      and MapCanvasDataProviderMixin and MapCanvasPinMixin and CreateFromMixins) then
    return provider
  end

  pinMixin = CreateFromMixins(MapCanvasPinMixin)
  function pinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
  end
  function pinMixin:OnAcquired(x, y, isMain)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetPosition(x, y)
    self.isMain = isMain
    -- main spot: emblem pin; other spawn points: small Mustard rings
    self:SetSize(isMain and 26 or 11, isMain and 26 or 11)
    self.icon:SetShown(isMain)
    self:Show()
  end
  function pinMixin:OnReleased() self.isMain = nil end
  -- The map canvas installs the pin's OnEnter/OnLeave/OnMouseUp scripts itself (and asserts that
  -- new pins have none), then calls these methods.
  pinMixin.OnMouseEnter = PinOnEnter
  function pinMixin:OnMouseLeave() GameTooltip:Hide() end
  function pinMixin:OnClick(button) if button == "RightButton" then ns.ClearMapPins() end end
  pinMixin.SetPassThroughButtons = function() end -- avoids an in-combat error on newer map code

  local pool = CreateUnsecuredRegionPoolInstance and CreateUnsecuredRegionPoolInstance(TEMPLATE) or CreateFramePool("FRAME")
  pool.parent = map:GetCanvas()
  pool.createFunc = function()
    local pin = CreateFrame("Frame", nil, map:GetCanvas())
    pin:SetSize(26, 26)
    local function Tex(layer, file, size)
      local t = pin:CreateTexture(nil, layer)
      t:SetTexture(ns.MEDIA .. file)
      t:SetPoint("CENTER")
      if size then t:SetSize(size, size) else t:SetAllPoints() end
      return t
    end
    pin.base = Tex("BACKGROUND", "MinimapBase64")
    pin.icon = Tex("ARTWORK", "MinimapIcon64")
    pin.icon:ClearAllPoints()
    pin.icon:SetPoint("TOPLEFT", 4, -4)
    pin.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    pin.ring = Tex("OVERLAY", "MinimapRing64")
    pin.ring:SetVertexColor(MUSTARD[1], MUSTARD[2], MUSTARD[3])
    pin:EnableMouse(true) -- makes the canvas wire up mouse motion and clicks for this pin
    return Mixin(pin, pinMixin)
  end
  pool.resetFunc = function(_, pin)
    pin:Hide()
    pin:ClearAllPoints()
    pin:OnReleased()
    pin.pinTemplate = nil
    pin.owningMap = nil
  end
  pool.creationFunc, pool.resetterFunc = pool.createFunc, pool.resetFunc
  map.pinPools[TEMPLATE] = pool

  local p = CreateFromMixins(MapCanvasDataProviderMixin)
  function p:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(TEMPLATE) end
  function p:RefreshAllData()
    self:RemoveAllData()
    if not active or self:GetMap():GetMapID() ~= active.mapID then return end
    for i, pt in ipairs(active.points) do
      if i ~= active.main then self:GetMap():AcquirePin(TEMPLATE, pt[1], pt[2], false) end
    end
    local m = active.points[active.main]
    self:GetMap():AcquirePin(TEMPLATE, m[1], m[2], true)
  end
  local ok = pcall(map.AddDataProvider, map, p)
  provider = ok and p or false

  map:HookScript("OnHide", function()
    if hiddenForMap and ns.Reopen then
      hiddenForMap = false
      ns.Reopen() -- bring Farmer Joe back, on the same farm, once the map closes
    end
  end)
  return provider
end

---------------------------------------------------------------- waypoint (minimap / supertrack)
local function SetWaypoint(mapID, x, y)
  local map = C_Map
  if not (map and map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
  if map.CanSetUserWaypointOnMap then
    local ok, can = pcall(map.CanSetUserWaypointOnMap, mapID)
    if ok and can == false then return false end
  end
  local ok, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
  if not ok or not point then return false end
  if not pcall(map.SetUserWaypoint, point) then return false end
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  return true
end

---------------------------------------------------------------- public
function ns.ShowFarmOnMap(f)
  local mapID, zone, pts, main = ns.FarmLocation(f)
  if not mapID then
    ns.Print("No map location recorded for " .. (f.name or "this farm") .. ".")
    return
  end
  active = { mapID = mapID, zone = zone, points = pts, main = main, farm = f }

  if not WorldMapFrame and UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_WorldMap") end
  BuildProvider()

  local fjFrame = _G.FarmerJoeFrame
  if fjFrame and fjFrame:IsShown() then
    fjFrame:Hide()
    hiddenForMap = true
  end
  if WorldMapFrame then
    if not WorldMapFrame:IsShown() then
      if OpenWorldMap then pcall(OpenWorldMap, mapID) else ShowUIPanel(WorldMapFrame) end
    end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
  end
  if provider then provider:RefreshAllData() end

  local m = pts[main]
  local wp = SetWaypoint(mapID, m[1], m[2])
  ns.Print(string.format("%s: %s (%.0f, %.0f)%s", f.name, zone or "?", m[1] * 100, m[2] * 100,
    wp and " - waypoint set" or ""))
end

function ns.ClearMapPins()
  active = nil
  if provider then provider:RemoveAllData() end
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end
