local _, ns = ...
local FK = ns.FK

---@module MapPins  Icons on the world map. local pin = FK.MapPins.Add(mapID, x, y, { icon, size (default 16), color, tooltip = text | {lines} | function(tooltip), onClick(pin, mouseButton) }) with x, y in 0..1 map coordinates; shown while the world map shows that map. pin:Remove(). FK.MapPins.Clear(). FK.MapPins.Waypoint(mapID, x, y) sets the game's own map waypoint.
local MapPins = { pins = {} }
FK.MapPins = MapPins
local layer, hooked

local function canvas() return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child end

local function refresh()
	local child = canvas()
	if not child then return end
	local map, w, h = WorldMapFrame:GetMapID(), child:GetWidth(), child:GetHeight()
	for pin in pairs(MapPins.pins) do
		local show = pin.mapID == map
		pin:SetShown(show)
		if show then
			pin:ClearAllPoints()
			pin:SetPoint("CENTER", child, "TOPLEFT", pin.x * w, -pin.y * h)
		end
	end
end

local function setup()
	if hooked or not canvas() then return end
	hooked = true
	layer = CreateFrame("Frame", nil, canvas())
	layer:SetAllPoints()
	layer:SetFrameLevel(canvas():GetFrameLevel() + 20)
	hooksecurefunc(WorldMapFrame, "OnMapChanged", refresh)
	WorldMapFrame:HookScript("OnShow", refresh)
	canvas():HookScript("OnSizeChanged", refresh)
end

function MapPins.Add(mapID, x, y, opts)
	opts = opts or {}
	setup()
	if not layer then error("FK.MapPins.Add: the world map is not loaded yet; add pins after login", 2) end
	local pin = CreateFrame("Button", nil, layer)
	-- shortcut: pins scale with the map zoom like the canvas does; counter-scale if that looks wrong in game
	pin:SetSize(opts.size or 16, opts.size or 16)
	pin.mapID, pin.x, pin.y, pin.opts = mapID, x, y, opts
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin.icon:SetTexture(opts.icon or "Interface\\Minimap\\ObjectIcons")
	if opts.color then pin.icon:SetVertexColor(unpack(opts.color)) end
	pin:SetScript("OnEnter", function(self) if opts.tooltip then FK.Tooltip.Show(self, opts.tooltip) end end)
	pin:SetScript("OnLeave", FK.Tooltip.Hide)
	pin:SetScript("OnClick", function(self, button) if opts.onClick then opts.onClick(self, button) end end)
	function pin:Remove() self:Hide() MapPins.pins[self] = nil end
	MapPins.pins[pin] = true
	refresh()
	return pin
end

function MapPins.Clear()
	for pin in pairs(MapPins.pins) do pin:Remove() end
end

function MapPins.Waypoint(mapID, x, y)
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
	C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end
