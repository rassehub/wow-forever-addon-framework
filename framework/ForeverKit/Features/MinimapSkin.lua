local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

---@module MinimapSkin  Re-styles the game's minimap (minimap addons): FK.MinimapSkin.Apply({ shape = "square"|"round", border = "metal"|"soft"|"double"|"none", borderColor = theme colour or {r,g,b}, scale (MinimapCluster), wheelZoom (default true), hide = { "ring", "header", "tracking", "calendar", "compartment" }, drawer = true (collect other addons' minimap buttons into a flyout) }); calling it again with other options re-applies; FK.MinimapSkin.Reset() puts everything back. Nothing is saved by the module: call Apply from your settings (e.g. on login and in onChange). Square sets the GetMinimapShape() convention so button libraries place buttons on the square edge. Blizzard pieces are found by the names the 1.60 client uses (dumped in game); missing ones are skipped.
local Skin = { hidden = {}, moved = {} }
FK.MinimapSkin = Skin

local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local PIECES = {
	ring = function() return MinimapCompassTexture end,
	header = function() return MinimapCluster and (MinimapCluster.ZoneTextButton or MinimapCluster.BorderTop) end,
	tracking = function() return MinimapCluster and MinimapCluster.Tracking end,
	calendar = function() return GameTimeFrame end,
	compartment = function() return type(AddonCompartmentFrame) == "table" and AddonCompartmentFrame.Hide and AddonCompartmentFrame end,
}

local function hidePiece(name)
	local f = PIECES[name] and PIECES[name]()
	if f and f.Hide and not Skin.hidden[f] then
		Skin.hidden[f] = f:IsShown()
		f:Hide()
		-- the client shows some pieces again on its own events: keep them hidden while skinned
		if f.HookScript and not f.fkSkinHooked then
			f.fkSkinHooked = true
			f:HookScript("OnShow", function(self) if Skin.hidden[self] ~= nil then self:Hide() end end)
		end
	end
end

-- Other addons' minimap buttons: LibDBIcon's and the common "...MinimapButton" naming.
local function isAddonButton(f)
	local name = f.GetName and f:GetName()
	return name and (name:find("^LibDBIcon10_") or name:find("MinimapButton$")) and f:GetObjectType() == "Button"
end

local function buildDrawer(color)
	local d = Skin.drawer
	if not d then
		d = CreateFrame("Button", nil, Minimap)
		d:SetSize(20, 20)
		d:SetFrameLevel(Minimap:GetFrameLevel() + 12)
		d.icon = d:CreateTexture(nil, "ARTWORK")
		d.icon:SetAllPoints()
		d.icon:SetTexture(FK.Media("Icons/grid"))
		d.flyout = FK.Frame("Frame", d)
		d.flyout:SetFrameStrata("DIALOG")
		d.flyout:Hide()
		d:SetScript("OnClick", function() d.flyout:SetShown(not d.flyout:IsShown()) end)
		d:SetScript("OnEnter", function(self) FK.Tooltip.Show(self, { FK.L["Addon buttons"], FK.L["Click to show the minimap buttons of your addons."] }, "ANCHOR_LEFT") end)
		d:SetScript("OnLeave", function() GameTooltip:Hide() end)
		Skin.drawer = d
	end
	d:ClearAllPoints()
	d:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
	d.icon:SetVertexColor(color[1], color[2], color[3])
	Theme.Paint(d.flyout, Theme.current.surface.menu)
	local buttons = {}
	for _, f in ipairs({ Minimap:GetChildren() }) do
		if isAddonButton(f) then buttons[#buttons + 1] = f end
	end
	for _, f in ipairs(Skin.moved) do if f:GetParent() == d.flyout then buttons[#buttons + 1] = f end end
	table.sort(buttons, function(a, b) return a:GetName() < b:GetName() end)
	local cols, size = 4, 34
	for i, f in ipairs(buttons) do
		if f:GetParent() ~= d.flyout then
			Skin.moved[#Skin.moved + 1] = f
			f.fkSkinParent = f:GetParent()
			f.fkSkinPoints = {}
			for p = 1, f:GetNumPoints() do f.fkSkinPoints[p] = { f:GetPoint(p) } end
			f:SetParent(d.flyout)
		end
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", d.flyout, "TOPLEFT", 6 + ((i - 1) % cols) * size, -6 - math.floor((i - 1) / cols) * size)
	end
	d.flyout:SetSize(12 + math.min(#buttons, cols) * size, 12 + math.ceil(math.max(#buttons, 1) / cols) * size)
	d.flyout:ClearAllPoints()
	d.flyout:SetPoint("TOPRIGHT", d, "BOTTOMLEFT", 0, -2)
	d:SetShown(#buttons > 0)
end

function Skin.Apply(o)
	o = o or {}
	Skin.Reset(true)
	Skin.options = o
	local square = o.shape == "square"
	Minimap:SetMaskTexture(square and SQUARE_MASK or ROUND_MASK)
	-- the convention minimap button libraries read to place buttons on the edge
	GetMinimapShape = square and function() return "SQUARE" end or nil
	local c = o.borderColor
	c = type(c) == "string" and { Theme.Color(c) } or c or { Theme.Color("accent") }
	if o.border and o.border ~= "none" then
		hidePiece("ring")
		local b = Skin.border
		if not b then
			b = CreateFrame("Frame", nil, Minimap)
			b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
			Skin.border = b
		end
		local pad = square and 4 or 6
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", -pad, pad)
		b:SetPoint("BOTTOMRIGHT", pad, -pad)
		local frame = o.border == "soft" and "soft" or o.border == "double" and "double" or "metal"
		Theme.Paint(b, { nineslice = "media:Frames/" .. frame, size = square and 14 or 30, color = (frame ~= "metal") and c or nil })
		b:Show()
	end
	for _, name in ipairs(o.hide or {}) do hidePiece(name) end
	if o.scale and MinimapCluster then
		Skin.oldScale = Skin.oldScale or MinimapCluster:GetScale()
		MinimapCluster:SetScale(o.scale)
	end
	if o.wheelZoom ~= false and not Skin.wheel then
		Skin.wheel = true
		Minimap:EnableMouseWheel(true)
		Minimap:HookScript("OnMouseWheel", function(_, delta)
			if not Skin.options or Skin.options.wheelZoom == false then return end
			local z = Minimap:GetZoom() + (delta > 0 and 1 or -1)
			Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, z)))
		end)
	end
	if o.drawer then buildDrawer(c) end
end

-- Back to the client's own minimap. keepHooks: used internally between two Apply calls.
function Skin.Reset(internal)
	Minimap:SetMaskTexture(ROUND_MASK)
	GetMinimapShape = nil
	if Skin.border then Skin.border:Hide() end
	for f, wasShown in pairs(Skin.hidden) do
		Skin.hidden[f] = nil
		if wasShown then f:Show() end
	end
	for _, f in ipairs(Skin.moved) do
		f:SetParent(f.fkSkinParent)
		f:ClearAllPoints()
		for _, p in ipairs(f.fkSkinPoints or {}) do f:SetPoint(unpack(p)) end
	end
	Skin.moved = {}
	if Skin.drawer then Skin.drawer:Hide() Skin.drawer.flyout:Hide() end
	if Skin.oldScale and MinimapCluster then MinimapCluster:SetScale(Skin.oldScale) Skin.oldScale = nil end
	if not internal then Skin.options = nil end
end
