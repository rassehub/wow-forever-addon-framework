local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

---@module MinimapSkin  Re-styles and re-shapes the game's minimap (minimap and navigator addons). FK.MinimapSkin.Apply({ shape = "round"|"square"|"rect", width, height (rect: any ratio 1:4..4:1; square/round use width), border = "thin"|"metal"|"soft"|"double"|"none" (rings when round; "none" keeps the client's ring, which only fits a round map at the default size: otherwise there is no border), borderColor (theme colour or {r,g,b}), scale (whole cluster), position = { point, relPoint, x, y } (detaches the map from the cluster, e.g. bottom centre for a navigator), rotate (the map turns with you; round only: the client turns a masked square as a whole, seen in game), wheelZoom (default true), hide = { "ring", "header", "tracking", "calendar", "compartment" }, drawer = true (other addons' minimap buttons in a flyout list with names), unlock = true (drag handle and corner grips; report changes to onLayout({ position, width, height }) and save them), attach (the zone name, clock, buttons and other cluster pieces follow the map; default on when position is set) }). Calling Apply again re-applies; FK.MinimapSkin.Reset() restores everything. Nothing is saved by the module. How the client renders the minimap was measured in game (step 14): it is always square, so rectangles are a square map under a band mask.
local Skin = { hidden = {}, moved = {} }
FK.MinimapSkin = Skin
local OWN = {} -- frames this module puts on the minimap (never culled)

-- ours: hard edge at any size (the client's CircleMaskScalable fades over several pixels, seen in game)
local ROUND_MASK = FK.Media("Masks/circle")
local DEFAULT_MASK = "Textures\\MinimapMask" -- the client's, when GetMaskTexture tells nothing
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local PIECES = {
	-- the classic ring, and the underlay the client adds while the map rotates (seen in game)
	ring = function() return MinimapCompassTexture, MinimapCompassTextureUnderlay end,
	header = function() return MinimapCluster and (MinimapCluster.ZoneTextButton or MinimapCluster.BorderTop) end,
	tracking = function() return MinimapCluster and MinimapCluster.Tracking end,
	calendar = function() return GameTimeFrame end,
	compartment = function() return type(AddonCompartmentFrame) == "table" and AddonCompartmentFrame.Hide and AddonCompartmentFrame end,
}

local hideOne
local function hidePiece(name)
	if not PIECES[name] then return end
	for _, f in ipairs({ PIECES[name]() }) do hideOne(f) end
end
function hideOne(f)
	if f and f.Hide and Skin.hidden[f] == nil then
		Skin.hidden[f] = f:IsShown()
		f:Hide()
		-- the client shows some pieces again on its own events (the compass ring when rotating,
		-- seen in game): keep them hidden while skinned. Textures have no OnShow: hook Show itself.
		if not f.fkSkinHooked then
			f.fkSkinHooked = true
			local function again(self) if Skin.hidden[self] ~= nil and self:IsShown() then self:Hide() end end
			hooksecurefunc(f, "Show", again)
			hooksecurefunc(f, "SetShown", again)
		end
	end
end

-- A readable name from a button's frame name: LibDBIcon10_ForeverDungeonJournal -> "Forever Dungeon Journal".
function Skin.ButtonName(f)
	local name = (f:GetName() or "?"):gsub("^LibDBIcon10_", "")
	for _, suffix in ipairs({ "MinimapButton", "MinimapIcon", "Minimap", "Button", "Icon" }) do
		local cut = name:gsub(suffix .. "$", "")
		if cut ~= "" and cut ~= name then name = cut break end
	end
	return (name:gsub("(%l)(%u)", "%1 %2"):gsub("[_%-]", " "))
end

-- Other addons' minimap buttons: LibDBIcon's and the common "...MinimapButton" naming.
local function isAddonButton(f)
	local name = f.GetName and f:GetName()
	return name and (name:find("^LibDBIcon10_") or name:find("MinimapButton$")) and f:GetObjectType() == "Button"
end

-- The mask for a width:height band, and the square size that holds it.
function Skin.RectMask(w, h)
	if w >= h then
		local n = math.max(8, math.min(32, math.floor(h / w * 32 + 0.5)))
		return FK.Media("Masks/rect-h" .. n), w, w, w * n / 32
	end
	local n = math.max(8, math.min(32, math.floor(w / h * 32 + 0.5)))
	return FK.Media("Masks/rect-w" .. n), h, h * n / 32, h
end

local function buildDrawer(color)
	local d = Skin.drawer
	if not d then
		d = CreateFrame("Button", nil, Minimap)
		OWN[d] = true
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
		-- button libraries fade their buttons out when the mouse leaves the minimap: not in here
		d.flyout:SetScript("OnShow", function() for _, f in ipairs(Skin.moved) do f:SetAlpha(1) end end)
		Skin.drawer = d
	end
	d:ClearAllPoints()
	d:SetPoint("BOTTOMLEFT", Skin.view, "BOTTOMLEFT", 2, 2)
	d.icon:SetVertexColor(color[1], color[2], color[3])
	Theme.Paint(d.flyout, Theme.current.surface.menu)
	local buttons = {}
	for _, f in ipairs({ Minimap:GetChildren() }) do
		if isAddonButton(f) then buttons[#buttons + 1] = f end
	end
	table.sort(buttons, function(a, b) return Skin.ButtonName(a) < Skin.ButtonName(b) end)
	local size = 32
	d.labels = d.labels or {}
	for _, l in ipairs(d.labels) do l:Hide() end
	for i, f in ipairs(buttons) do
		Skin.moved[#Skin.moved + 1] = f
		f.fkSkinParent = f:GetParent()
		f.fkSkinPoints = {}
		for p = 1, f:GetNumPoints() do f.fkSkinPoints[p] = { f:GetPoint(p) } end
		f:SetParent(d.flyout)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", d.flyout, "TOPLEFT", 4, -6 - (i - 1) * size)
		f:SetAlpha(1)
		if not f.fkSkinAlpha then
			f.fkSkinAlpha = true
			hooksecurefunc(f, "SetAlpha", function(self, a)
				if a < 1 and Skin.drawer and self:GetParent() == Skin.drawer.flyout then self:SetAlpha(1) end
			end)
		end
		local label = d.labels[i]
		if not label then
			label = d.flyout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetJustifyH("LEFT")
			label:SetWordWrap(false)
			d.labels[i] = label
		end
		Theme.Font(label, "normal")
		label:ClearAllPoints()
		label:SetPoint("LEFT", d.flyout, "TOPLEFT", 4 + 34, -6 - (i - 1) * size - 16)
		label:SetPoint("RIGHT", d.flyout, "RIGHT", -8, 0)
		label:SetText(Skin.ButtonName(f))
		label:Show()
	end
	d.flyout:SetSize(200, 12 + math.max(#buttons, 1) * size)
	d.flyout:ClearAllPoints()
	d.flyout:SetPoint("TOPRIGHT", d, "BOTTOMLEFT", 0, -2)
	d:SetShown(#buttons > 0)
end

-- Drag handle and resize grip over the visible map (unlock mode).
local function buildHandles(o)
	local h = Skin.handle
	if not h then
		h = FK.Frame("Frame", UIParent)
		h:SetFrameStrata("DIALOG")
		h:EnableMouse(true)
		h:RegisterForDrag("LeftButton")
		h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		h.label:SetPoint("CENTER")
		h:SetScript("OnDragStart", function()
			Minimap:SetMovable(true)
			Minimap:SetClampedToScreen(true) -- the client keeps the square on screen while moving
			Minimap:StartMoving()
		end)
		h:SetScript("OnDragStop", function()
			Minimap:StopMovingOrSizing()
			local point, _, relPoint, x, y = Minimap:GetPoint(1)
			Skin.options.position = { point = point, relPoint = relPoint, x = x, y = y }
			Skin.Apply(Skin.options)
			Skin.Report()
		end)
		-- a grip on each corner; dragging one resizes around the opposite corner, which stays put
		h.grips = {}
		local OPPOSITE = { TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT" }
		local ROTATION = { BOTTOMRIGHT = 0, BOTTOMLEFT = -math.pi / 2, TOPLEFT = math.pi, TOPRIGHT = math.pi / 2 }
		for corner, opposite in pairs(OPPOSITE) do
			local g = CreateFrame("Button", nil, h)
			g:SetSize(18, 18)
			g:SetPoint(corner, corner:find("LEFT") and 2 or -2, corner:find("TOP") and -2 or 2)
			g.icon = g:CreateTexture(nil, "ARTWORK")
			g.icon:SetAllPoints()
			g.icon:SetTexture(FK.Media("Icons/grip"))
			g.icon:SetRotation(ROTATION[corner])
			g:RegisterForDrag("LeftButton")
			g:SetScript("OnDragStart", function()
				-- the opposite corner in UIParent units
				local v, k = Skin.view, Skin.view:GetEffectiveScale() / UIParent:GetEffectiveScale()
				local ox = (opposite:find("LEFT") and v:GetLeft() or v:GetRight()) * k
				local oy = (opposite:find("TOP") and v:GetTop() or v:GetBottom()) * k
				local ax = (corner:find("LEFT") and v:GetLeft() or v:GetRight()) * k
				local ay = (corner:find("TOP") and v:GetTop() or v:GetBottom()) * k
				local ui = UIParent:GetEffectiveScale()
				local cx, cy = GetCursorPosition()
				-- where on the grip it was taken: the corner keeps that distance to the cursor
				g.sizing = { ox = ox, oy = oy, dx = cx / ui - ax, dy = cy / ui - ay }
			end)
			g:SetScript("OnUpdate", function()
				local sz = g.sizing
				if not sz then return end
				local ui = UIParent:GetEffectiveScale()
				local cx, cy = GetCursorPosition()
				cx, cy = cx / ui - sz.dx, cy / ui - sz.dy
				local o2 = Skin.options
				local toMap = ui / Minimap:GetEffectiveScale() -- UIParent units -> the map's own units
				local w = math.max(80, math.min(900, math.abs(cx - sz.ox) * toMap))
				local hh = math.max(80, math.min(900, math.abs(cy - sz.oy) * toMap))
				if o2.shape ~= "rect" then w = math.max(w, hh) hh = w end
				-- the far corner follows the cursor (clamped), the centre sits between the two corners
				local fx = sz.ox + (cx >= sz.ox and 1 or -1) * w / toMap
				local fy = sz.oy + (cy >= sz.oy and 1 or -1) * hh / toMap
				o2.width, o2.height = math.floor(w + 0.5), math.floor(hh + 0.5)
				o2.position = { point = "CENTER", relPoint = "BOTTOMLEFT", x = (sz.ox + fx) / 2 * toMap, y = (sz.oy + fy) / 2 * toMap }
				Skin.Shape(o2)
				Minimap:ClearAllPoints()
				Minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", o2.position.x, o2.position.y)
				Skin.KeepOnScreen()
				if Skin.attached then Skin.Attach() end
			end)
			g:SetScript("OnDragStop", function()
				g.sizing = nil
				Skin.Apply(Skin.options)
				Skin.Report()
			end)
			h.grips[corner] = g
		end
		Skin.handle = h
	end
	local c = { Theme.Color("accent") }
	Theme.Paint(h, { nineslice = "media:Frames/thin", size = 6, color = c, bg = { c[1], c[2], c[3], 0.12 } })
	Theme.Font(h.label, "normal", "accent")
	h.label:SetText(FK.L["Drag to move  ·  corners to resize"])
	for _, g in pairs(h.grips) do g.icon:SetVertexColor(c[1], c[2], c[3]) end
	h:ClearAllPoints()
	h:SetAllPoints(Skin.view)
	h:Show()
	-- the whole square the client draws: why a wide rectangle cannot go closer to a screen edge
	local sq = h.square
	if not sq then
		sq = FK.Frame("Frame", h)
		sq:SetFrameStrata("DIALOG")
		sq.label = sq:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		sq.label:SetPoint("TOP", 0, -4)
		h.square = sq
	end
	sq:ClearAllPoints()
	sq:SetAllPoints(Minimap)
	Theme.Paint(sq, { nineslice = "media:Frames/thin", size = 6, color = { c[1], c[2], c[3], 0.35 } })
	Theme.Font(sq.label, "small", "dim")
	sq.label:SetText(o.shape == "rect" and FK.L["The game draws the map as this square: it has to stay on screen"] or "")
	sq:SetShown(o.shape == "rect")
end

function Skin.Report()
	local o = Skin.options
	if o and o.onLayout then o.onLayout({ position = o.position, width = o.width, height = o.height }) end
end

-- Pins of other addons (Questie, gathering addons...) are frames placed over the whole square map;
-- the band mask only cuts the map picture. While the map is a rectangle, pins whose centre is outside
-- the band are made invisible (alpha 0) and given back their alpha when the band reaches them again.
local function cullPins()
	local view = Skin.view
	local l, r, t, b = view:GetLeft(), view:GetRight(), view:GetTop(), view:GetBottom()
	if not l then return end
	for _, f in ipairs({ Minimap:GetChildren() }) do
		if not OWN[f] and f:IsShown() then
			local x, y = f:GetCenter()
			local outside = x and (x < l or x > r or y < b or y > t)
			if outside and not f.fkCulled then
				f.fkCulled = f:GetAlpha()
				f:SetAlpha(0)
				-- their addon keeps setting the alpha (Questie fades by distance, seen in game): while
				-- culled, any alpha it sets is remembered and the pin stays invisible
				if not f.fkCullHook then
					f.fkCullHook = true
					hooksecurefunc(f, "SetAlpha", function(self, a)
						if self.fkCulled and a > 0 then self.fkCulled = a self:SetAlpha(0) end
					end)
				end
			elseif not outside and f.fkCulled then
				local a = f.fkCulled
				f.fkCulled = nil -- first, so the alpha hook lets this through
				f:SetAlpha(a)
			end
		end
	end
end
local function uncullPins()
	for _, f in ipairs({ Minimap:GetChildren() }) do
		if f.fkCulled then
			local a = f.fkCulled
			f.fkCulled = nil
			f:SetAlpha(a)
		end
	end
end
Skin.CullPins = cullPins

-- The pieces around the map (zone name, tracking, calendar, compartment, clock, coordinates and
-- whatever other addons put in the cluster) follow it when it moves: each keeps its side of the
-- map and its distance from that edge. Found generically: the cluster's other children, and the
-- map container's other children.
local function pieces()
	local list, container = {}, Minimap:GetParent()
	local function add(parent, except)
		for _, f in ipairs({ parent:GetChildren() }) do
			if f ~= except and not OWN[f] and f ~= Skin.handle then list[#list + 1] = f end
		end
	end
	if MinimapCluster then add(MinimapCluster, container ~= MinimapCluster and container or Minimap) end
	if container and container ~= MinimapCluster and container ~= UIParent then add(container, Minimap) end
	return list
end

-- Where each piece sits relative to the client's own map: measured once, before anything moves.
local function measurePieces()
	local orig = Skin.original
	do
		local l, r, t, b = Minimap:GetLeft(), Minimap:GetRight(), Minimap:GetTop(), Minimap:GetBottom()
		local cx, cy = (l + r) / 2, (t + b) / 2
		orig.pieces = {}
		for _, f in ipairs(pieces()) do
			local x, y = f:GetCenter()
			if x then
				local pts = {}
				for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
				local k = f:GetEffectiveScale() / Minimap:GetEffectiveScale()
				x, y = x * k, y * k
				local side = y > t and "TOP" or y < b and "BOTTOM" or x < l and "LEFT" or x > r and "RIGHT" or "CENTER"
				local dx = (side == "LEFT" and x - l) or (side == "RIGHT" and x - r) or (x - cx) / (r - l)
				local dy = (side == "TOP" and y - t) or (side == "BOTTOM" and y - b) or (y - cy) / (t - b)
				orig.pieces[#orig.pieces + 1] = { frame = f, points = pts, side = side, dx = dx, dy = dy }
			end
		end
	end
end

function Skin.Attach()
	local orig, view = Skin.original, Skin.view
	if not orig.pieces then return end
	for _, p in ipairs(orig.pieces) do
		local f, side = p.frame, p.side
		local k = Minimap:GetEffectiveScale() / f:GetEffectiveScale()
		-- along the edge: the same fraction of the map's width or height; across it: the same gap
		local x = (side == "LEFT" or side == "RIGHT") and p.dx or p.dx * view:GetWidth()
		local y = (side == "TOP" or side == "BOTTOM") and p.dy or p.dy * view:GetHeight()
		f:ClearAllPoints()
		f:SetPoint("CENTER", view, side, x * k, y * k)
	end
	Skin.attached = true
end

local function detach()
	local orig = Skin.original
	if not (Skin.attached and orig and orig.pieces) then return end
	for _, p in ipairs(orig.pieces) do
		p.frame:ClearAllPoints()
		for _, pt in ipairs(p.points) do p.frame:SetPoint(unpack(pt)) end
	end
	Skin.attached = nil
end

-- Keeps the whole square map on screen. The client always renders the minimap as a square; when
-- part of that square is off screen it squeezes the map into what is left while our border stays
-- (seen in game, step 14). A rectangle is a band of a bigger square, so its edges cannot reach the
-- screen edge closer than the hidden part of the square.
function Skin.KeepOnScreen()
	local l, r, t, b = Minimap:GetLeft(), Minimap:GetRight(), Minimap:GetTop(), Minimap:GetBottom()
	if not l then return end
	local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	local dx = math.max(0, -l * k) - math.max(0, r * k - W)
	local dy = math.max(0, -b * k) - math.max(0, t * k - H)
	if dx == 0 and dy == 0 then return end
	local point, rel, relPoint, x, y = Minimap:GetPoint(1)
	Minimap:ClearAllPoints()
	Minimap:SetPoint(point, rel, relPoint, x + dx / k, y + dy / k)
	local o = Skin.options
	if o and o.position then o.position.x, o.position.y = x + dx / k, y + dy / k end
end

-- Size, mask and border for the current shape (also used live while resizing).
function Skin.Shape(o)
	local shape = o.shape or "round"
	local w = o.width or Skin.original.width
	local h = shape == "rect" and (o.height or w) or w
	local mask, side, vw, vh = SQUARE_MASK, w, w, w
	if shape == "rect" then mask, side, vw, vh = Skin.RectMask(w, h)
	elseif shape == "round" then mask = ROUND_MASK end
	Minimap:SetSize(side, side)
	Minimap:SetMaskTexture(mask)
	-- the client redraws the map only when the player moves; a zoom nudge redraws it now
	local z = Minimap:GetZoom()
	Minimap:SetZoom(z > 0 and z - 1 or z + 1)
	Minimap:SetZoom(z)
	-- the visible part of the map: what borders, the drawer and the handle frame
	local view = Skin.view
	if not view then
		view = CreateFrame("Frame", nil, Minimap)
		Skin.view = view
		OWN[view] = true
		local elapsed = 0
		view:SetScript("OnUpdate", function(_, dt)
			elapsed = elapsed + dt
			if elapsed < 0.03 then return end
			elapsed = 0
			if Skin.options and Skin.options.shape == "rect" then cullPins() end
		end)
	end
	if shape ~= "rect" then uncullPins() end
	view:ClearAllPoints()
	view:SetPoint("CENTER", Minimap, "CENTER")
	view:SetSize(vw, vh)
	-- border
	local b, r = Skin.border, Skin.ring
	if b then b:Hide() end
	if r then r:Hide() end
	if o.border and o.border ~= "none" then
		local c = o.borderColor
		c = type(c) == "string" and { Theme.Color(c) } or c or { Theme.Color("accent") }
		local style = ({ thin = "thin", soft = "soft", double = "double" })[o.border] or "metal"
		local tint = style ~= "metal" and c or { 1, 1, 1 }
		if shape == "round" then
			if not r then
				r = CreateFrame("Frame", nil, Minimap)
				OWN[r] = true
				r:SetFrameLevel(Minimap:GetFrameLevel() + 10)
				r.tex = r:CreateTexture(nil, "OVERLAY")
				r.tex:SetAllPoints()
				Skin.ring = r
			end
			local pad = style == "thin" and 2 or 6
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", view, "TOPLEFT", -pad, pad)
			r:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", pad, -pad)
			r.tex:SetTexture(FK.Media("Frames/ring-" .. style))
			r.tex:SetVertexColor(tint[1], tint[2], tint[3], 1)
			r:Show()
		else
			if not b then
				b = CreateFrame("Frame", nil, Minimap)
				OWN[b] = true
				b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
				Skin.border = b
			end
			local pad = style == "thin" and 2 or 4
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", view, "TOPLEFT", -pad, pad)
			b:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", pad, -pad)
			Theme.Paint(b, { nineslice = "media:Frames/" .. style, size = style == "thin" and 6 or 14, color = style ~= "metal" and c or nil })
			b:Show()
		end
	end
end

function Skin.Apply(o)
	o = o or {}
	Skin.Reset(true)
	Skin.options = o
	if not Skin.original then
		local pts = {}
		for i = 1, Minimap:GetNumPoints() do pts[i] = { Minimap:GetPoint(i) } end
		Skin.original = { width = Minimap:GetWidth(), points = pts, mask = Minimap:GetMaskTexture() or DEFAULT_MASK, rotate = C_CVar and (C_CVar.GetCVar("rotateMinimap") or "0") }
		measurePieces()
	end
	local shape = o.shape or "round"
	if o.rotate and shape ~= "round" then
		-- the client rotates the whole masked square (seen in game): only a round map can turn
		FK:Warn("minimap-rotate", "only a round minimap can rotate; rotation is off for " .. shape)
		o.rotate = false
	end
	-- the convention minimap button libraries read to place buttons on the edge
	GetMinimapShape = shape ~= "round" and function() return "SQUARE" end or nil
	Skin.Shape(o)
	if o.border and o.border ~= "none" then hidePiece("ring") end
	for _, name in ipairs(o.hide or {}) do hidePiece(name) end
	-- the client's ring fits only its own round map at its own size: the client puts it back to that
	-- size whatever we do (seen in game), so at any other size or shape it goes
	if shape ~= "round" or math.abs(Minimap:GetWidth() - Skin.original.width) > 0.5 then hidePiece("ring") end
	Minimap:ClearAllPoints()
	if o.position then
		local p = o.position
		Minimap:SetPoint(p.point or "CENTER", UIParent, p.relPoint or p.point or "CENTER", p.x or 0, p.y or 0)
		Skin.KeepOnScreen()
	else
		for _, p in ipairs(Skin.original.points) do Minimap:SetPoint(unpack(p)) end
	end
	-- the pieces around the map follow it when it is moved (or asked to)
	if o.attach or (o.attach == nil and o.position) then Skin.Attach() end
	if o.scale and MinimapCluster then
		Skin.oldScale = Skin.oldScale or MinimapCluster:GetScale()
		MinimapCluster:SetScale(o.scale)
	end
	if o.rotate ~= nil and C_CVar then C_CVar.SetCVar("rotateMinimap", o.rotate and "1" or "0") end
	if o.wheelZoom ~= false and not Skin.wheel then
		Skin.wheel = true
		Minimap:EnableMouseWheel(true)
		Minimap:HookScript("OnMouseWheel", function(_, delta)
			if not Skin.options or Skin.options.wheelZoom == false then return end
			local z = Minimap:GetZoom() + (delta > 0 and 1 or -1)
			Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, z)))
		end)
	end
	local c = o.borderColor
	c = type(c) == "string" and { Theme.Color(c) } or c or { Theme.Color("accent") }
	if o.drawer then buildDrawer(c) end
	if o.unlock then buildHandles(o) end
end

-- Back to the client's own minimap. internal: between two Apply calls (keeps the options).
function Skin.Reset(internal)
	local orig = Skin.original
	if orig then Minimap:SetMaskTexture(orig.mask) end
	GetMinimapShape = nil
	if Skin.border then Skin.border:Hide() end
	if Skin.ring then Skin.ring:Hide() end
	if Skin.handle then Skin.handle:Hide() end
	for f, wasShown in pairs(Skin.hidden) do
		Skin.hidden[f] = nil
		if wasShown then f:Show() end
	end
	uncullPins()
	detach()
	for _, f in ipairs(Skin.moved) do
		f:SetParent(f.fkSkinParent)
		f:ClearAllPoints()
		for _, p in ipairs(f.fkSkinPoints or {}) do f:SetPoint(unpack(p)) end
	end
	Skin.moved = {}
	if Skin.drawer then Skin.drawer:Hide() Skin.drawer.flyout:Hide() end
	if Skin.oldScale and MinimapCluster then MinimapCluster:SetScale(Skin.oldScale) Skin.oldScale = nil end
	if not internal and orig then
		Minimap:SetSize(orig.width, orig.width)
		Minimap:ClearAllPoints()
		for _, p in ipairs(orig.points) do Minimap:SetPoint(unpack(p)) end
		if orig.rotate and C_CVar then C_CVar.SetCVar("rotateMinimap", orig.rotate) end
		Skin.original = nil
	end
	if not internal then Skin.options = nil end
end
