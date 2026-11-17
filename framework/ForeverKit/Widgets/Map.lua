local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- MapCanvas: a pannable, zoomable canvas of textures (map tiles, a floor plan, a talent board)
-- with pins that keep their size while zooming. Coordinates given to and reported by the
-- canvas are fractions 0..1 of the content (multiply by 100 for map percent).

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

---@widget MapCanvas  Pannable, zoomable texture canvas with pins (world maps, floor plans, boards). Drag to pan, wheel to zoom around the cursor, +/- buttons, cursor coordinates. opts: contentWidth, contentHeight (canvas units, e.g. 1002x668 for a world map), tiles = { { texture, x, y, w, h, coords } } in canvas units, zoom (1 = fit), maxZoom (default 6), controls (default true), showCoords (default true), onClick(x, y, mouseButton) with x, y in 0..1, onZoom(zoom). Methods: SetTiles(tiles), AddPin(x, y, { icon (texture or icon-set name), size, color, tooltip, onClick(pin, button) }) -> pin with :Remove() and :SetPosition(x, y), ClearPins(), SetZoom(zoom, x, y) (keeps the point x, y under the same spot), CenterOn(x, y), GetZoom(), CursorPosition() -> x, y or nil.
FK.Define("MapCanvas", {
	SetTiles = function(self, tiles)
		for _, t in ipairs(self.tileTextures) do t:Hide() end
		for i, tile in ipairs(tiles or {}) do
			local t = self.tileTextures[i]
			if not t then
				t = self.canvas:CreateTexture(nil, "BACKGROUND")
				self.tileTextures[i] = t
			end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", tile.x or 0, -(tile.y or 0))
			t:SetSize(tile.w or self.cw, tile.h or self.ch)
			t:SetTexture(Theme.Resolve(tile.texture))
			local co = tile.coords
			if co then t:SetTexCoord(co[1], co[2], co[3], co[4]) else t:SetTexCoord(0, 1, 0, 1) end
			t:Show()
		end
	end,
	-- Screen scale of one canvas unit: the fit scale times the zoom.
	Scale = function(self)
		local w, h = self:GetWidth(), self:GetHeight()
		if w <= 0 or h <= 0 then return self.zoom end
		return math.min(w / self.cw, h / self.ch) * self.zoom
	end,
	GetZoom = function(self) return self.zoom end,
	Clamp = function(self)
		local s = self:Scale()
		local vw, vh = self:GetWidth() / s, self:GetHeight() / s -- view size in canvas units
		self.panX = vw >= self.cw and (self.cw - vw) / 2 or clamp(self.panX, 0, self.cw - vw)
		self.panY = vh >= self.ch and (self.ch - vh) / 2 or clamp(self.panY, 0, self.ch - vh)
	end,
	Apply = function(self)
		self:Clamp()
		local s = self:Scale()
		self.canvas:SetScale(math.max(s, 0.01))
		self.canvas:ClearAllPoints()
		-- offsets are in the canvas's own (scaled) units
		self.canvas:SetPoint("TOPLEFT", self, "TOPLEFT", -self.panX, self.panY)
		for pin in pairs(self.pins) do self:PlacePin(pin) end
	end,
	PlacePin = function(self, pin)
		local s = self:Scale()
		local x, y = (pin.x * self.cw - self.panX) * s, (pin.y * self.ch - self.panY) * s
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", self, "TOPLEFT", x, -y)
		pin:SetShown(x >= -pin:GetWidth() and y >= -pin:GetHeight() and x <= self:GetWidth() + pin:GetWidth() and y <= self:GetHeight() + pin:GetHeight())
	end,
	SetZoom = function(self, zoom, x, y)
		local old = self:Scale()
		x, y = x or (self.panX + self:GetWidth() / old / 2) / self.cw, y or (self.panY + self:GetHeight() / old / 2) / self.ch
		-- where the point sits on screen now, so it stays there
		local sx, sy = (x * self.cw - self.panX) * old, (y * self.ch - self.panY) * old
		self.zoom = clamp(zoom, 1, self.opts.maxZoom or 6)
		local s = self:Scale()
		self.panX, self.panY = x * self.cw - sx / s, y * self.ch - sy / s
		self:Apply()
		if self.zoomLabel then self.zoomLabel:SetText(("%d%%"):format(self.zoom * 100 + 0.5)) end
		if self.opts.onZoom then self.opts.onZoom(self.zoom) end
	end,
	CenterOn = function(self, x, y)
		local s = self:Scale()
		self.panX = x * self.cw - self:GetWidth() / s / 2
		self.panY = y * self.ch - self:GetHeight() / s / 2
		self:Apply()
	end,
	-- Cursor position in content fractions, or nil when the cursor is outside the canvas.
	CursorPosition = function(self)
		local cx, cy = GetCursorPosition()
		local es = self:GetEffectiveScale()
		local l, t = self:GetLeft(), self:GetTop()
		if not l then return nil end
		local lx, ly = cx / es - l, t - cy / es
		if lx < 0 or ly < 0 or lx > self:GetWidth() or ly > self:GetHeight() then return nil end
		local s = self:Scale()
		return (lx / s + self.panX) / self.cw, (ly / s + self.panY) / self.ch
	end,
	AddPin = function(self, x, y, o)
		o = o or {}
		local pin = CreateFrame("Button", nil, self.overlay)
		local size = o.size or 16
		pin:SetSize(size, size)
		pin.x, pin.y, pin.opts = x, y, o
		pin.icon = pin:CreateTexture(nil, "ARTWORK")
		pin.icon:SetAllPoints()
		local named = type(o.icon) == "string" and FK.mediaIcons[o.icon]
		pin.icon:SetTexture(named and FK.Media("Icons/" .. o.icon) or Theme.Resolve(o.icon or "media:Icons/pin"))
		local c = o.color or (named or not o.icon) and { Theme.Color("accent") } or { 1, 1, 1 }
		pin.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		pin:RegisterForClicks("AnyUp")
		pin:SetScript("OnClick", function(p, button) if o.onClick then o.onClick(p, button) end end)
		pin:SetScript("OnEnter", function(p) if o.tooltip then FK.Tooltip.Show(p, o.tooltip) end end)
		pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
		local canvas = self
		function pin:Remove() self:Hide() canvas.pins[self] = nil end
		function pin:SetPosition(nx, ny) self.x, self.y = nx, ny canvas:PlacePin(self) end
		self.pins[pin] = true
		self:PlacePin(pin)
		return pin
	end,
	ClearPins = function(self)
		for pin in pairs(self.pins) do pin:Remove() end
	end,
	Restyle = function(self)
		Theme.Paint(self.frame, Theme.current.surface.inset)
	end,
}, function(self, opts)
	self.cw, self.ch = opts.contentWidth or 1000, opts.contentHeight or 667
	self.zoom, self.panX, self.panY = opts.zoom or 1, 0, 0
	self.pins, self.tileTextures = {}, {}
	-- the border/background, behind the clipped view
	self.frame = FK.Frame("Frame", self)
	self.frame:SetAllPoints()
	self.frame:SetFrameLevel(self:GetFrameLevel())
	self:SetClipsChildren(true)
	self.canvas = CreateFrame("Frame", nil, self)
	self.canvas:SetSize(self.cw, self.ch)
	self.canvas:SetFrameLevel(self:GetFrameLevel() + 1)
	self.overlay = CreateFrame("Frame", nil, self)
	self.overlay:SetAllPoints()
	self.overlay:SetFrameLevel(self:GetFrameLevel() + 5)
	-- pan by dragging, click when the mouse did not move
	self:EnableMouse(true)
	self:EnableMouseWheel(true)
	local drag
	self:SetScript("OnMouseDown", function(_, button)
		local cx, cy = GetCursorPosition()
		drag = { x = cx, y = cy, panX = self.panX, panY = self.panY, button = button, moved = false }
	end)
	self:SetScript("OnUpdate", function()
		if drag then
			local cx, cy = GetCursorPosition()
			local d = self:GetEffectiveScale() * self:Scale()
			local dx, dy = (cx - drag.x) / d, (cy - drag.y) / d
			if math.abs(cx - drag.x) + math.abs(cy - drag.y) > 3 then drag.moved = true end
			if drag.moved then
				self.panX, self.panY = drag.panX - dx, drag.panY + dy
				self:Apply()
			end
		end
		if self.coords and self:IsMouseOver() then
			local x, y = self:CursorPosition()
			self.coords:SetText(x and ("%.1f, %.1f"):format(x * 100, y * 100) or "")
		end
	end)
	self:SetScript("OnMouseUp", function(_, button)
		local d = drag
		drag = nil
		if d and not d.moved and opts.onClick then
			local x, y = self:CursorPosition()
			if x then opts.onClick(x, y, button) end
		end
	end)
	self:SetScript("OnMouseWheel", function(_, delta)
		local x, y = self:CursorPosition()
		self:SetZoom(self.zoom * (delta > 0 and 1.25 or 0.8), x, y)
	end)
	self:SetScript("OnSizeChanged", function() self:Apply() end)
	-- controls
	if opts.controls ~= false then
		local plus = FK.IconButton(self.overlay, { icon = "plus", size = 22, onClick = function() self:SetZoom(self.zoom * 1.5) end })
		plus:SetPoint("TOPRIGHT", -6, -6)
		local minus = FK.IconButton(self.overlay, { icon = "minus", size = 22, onClick = function() self:SetZoom(self.zoom / 1.5) end })
		minus:SetPoint("TOP", plus, "BOTTOM", 0, -4)
		self.zoomLabel = self:Text("small", "dim", self.overlay)
		self.zoomLabel:SetPoint("TOP", minus, "BOTTOM", 0, -4)
		self.zoomLabel:SetText(("%d%%"):format(self.zoom * 100))
	end
	if opts.showCoords ~= false then
		self.coords = self:Text("small", "dim", self.overlay)
		self.coords:SetPoint("BOTTOMLEFT", 8, 6)
	end
	self:SetTiles(opts.tiles)
	self:Restyle()
	self:Apply()
end)
