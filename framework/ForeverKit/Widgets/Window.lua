local ADDON, ns = ...
local FK = ns.FK
local Theme = FK.Theme

local windowCount = 0

-- Keeps a top-level frame on screen (after a resolution or UI scale change a saved position
-- can be outside it).
local function onScreen(f)
	local l, b, w, h = f:GetRect()
	if not l then return false end
	local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	return l * scale >= -1 and b * scale >= -1 and (l + w) * scale <= sw + 1 and (b + h) * scale <= sh + 1
end

---@widget Window  Movable top-level window: title, close button, Escape closes it, remembers position/size. opts: title, width, height, resizable = { minWidth, minHeight, maxWidth, maxHeight } or true, saved = { db, "profile.window" } (where position, size and scale are stored), escClose (default true), strata, buttons = { { icon, tooltip, onClick } } extra title-bar buttons, onShow, onHide. Put children in window.content. Methods: Toggle, Open, Close, SetTitle, SetLocked, ResetPosition, SetWindowScale.
FK.Define("Window", {
	Open = function(self)
		if FK.inWorld then return self:Show() end
		-- opened during login: the client's CloseAllWindows would hide it right away
		if not self.openPending then
			self.openPending = true
			FK:Once("fk.world", function() if self.openPending then self.openPending = nil self:Show() end end)
		end
	end,
	Close = function(self) self.openPending = nil self:Hide() end,
	Toggle = function(self) self:SetShown(not self:IsShown()) end,
	SetTitle = function(self, text) self.title:SetText(text) end,
	-- A locked window cannot be moved or resized.
	SetLocked = function(self, locked)
		self.locked = locked and true or false
		self:Restyle()
	end,
	SetWindowScale = function(self, scale)
		self:SetScale(scale)
		self:Store()
		if not onScreen(self) then self:ResetPosition() end
	end,
	ResetPosition = function(self)
		self:ClearAllPoints()
		self:SetPoint("CENTER")
		self:SetSize(self.opts.width or 400, self.opts.height or 300)
		self:Store()
	end,
	-- Writes position, size and scale to the saved settings.
	Store = function(self)
		local saved = self.opts.saved
		if not saved then return end
		local point, _, relPoint, x, y = self:GetPoint(1)
		saved[1]:Set(saved[2], { point = point, relPoint = relPoint, x = x, y = y,
			width = self:GetWidth(), height = self:GetHeight(), scale = self:GetScale() })
	end,
	Restore = function(self)
		local saved = self.opts.saved
		local s = saved and saved[1]:Get(saved[2])
		if type(s) ~= "table" or not s.point then return end
		self:SetScale(s.scale or 1)
		self:ClearAllPoints()
		self:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
		if self.opts.resizable and s.width then self:SetSize(s.width, s.height) end
		if not onScreen(self) then self:ResetPosition() end
	end,
	Restyle = function(self)
		local T = Theme.current
		local m, s = T.metric, T.surface
		Theme.Paint(self, s.window, Theme.opacity)
		local inset = m.windowInset
		local top = inset[3]
		self.bar:ClearAllPoints()
		if s.titlebar then
			self.bar:SetPoint("TOPLEFT", inset[1], -inset[3])
			self.bar:SetPoint("TOPRIGHT", -inset[2], -inset[3])
			self.bar:SetHeight(m.title)
			Theme.Paint(self.bar, s.titlebar)
			self.title:ClearAllPoints()
			self.title:SetPoint("LEFT", self.bar, "LEFT", m.pad, 0)
			self.plaque:Hide()
			top = top + m.title
		else
			-- no title strip: the whole top edge is the drag area and the title sits on a plaque
			self.bar:SetPoint("TOPLEFT", 0, 0)
			self.bar:SetPoint("TOPRIGHT", 0, 0)
			self.bar:SetHeight(m.title)
			Theme.Paint(self.bar, nil)
			local p = s.plaque
			self.plaque:SetShown(p and true or false)
			self.title:ClearAllPoints()
			if p then
				Theme.Texture(self.plaque, p)
				self.plaque:SetSize(p.width, p.height)
				self.plaque:ClearAllPoints()
				self.plaque:SetPoint("TOP", 0, p.offset)
				self.title:SetPoint("TOP", 0, p.titleOffset)
			else
				self.title:SetPoint("TOP", 0, -inset[3] - 4)
			end
			top = top + (m.plaqueGap or 14)
		end
		self.close:ClearAllPoints()
		self.close:SetPoint("TOPRIGHT", s.titlebar and -inset[2] - 2 or -3, s.titlebar and -inset[3] - 2 or -3)
		local prev = self.close
		for _, b in ipairs(self.extra) do
			b:ClearAllPoints()
			b:SetPoint("RIGHT", prev, "LEFT", -2, 0)
			prev = b
		end
		self.content:ClearAllPoints()
		self.content:SetPoint("TOPLEFT", inset[1] + m.pad, -top - m.pad)
		self.content:SetPoint("BOTTOMRIGHT", -inset[2] - m.pad, inset[4] + m.pad)
		self.grip:SetShown(self.opts.resizable and not self.locked and true or false)
	end,
}, function(self, opts)
	windowCount = windowCount + 1
	local name = opts.name or (ADDON .. "Window" .. windowCount)
	_G[name] = self -- UISpecialFrames works by global name
	self:SetParent(UIParent)
	self:SetFrameStrata(opts.strata or "MEDIUM")
	self:SetToplevel(true)
	self:SetClampedToScreen(true)
	self:EnableMouse(true)
	self:SetMovable(true)
	self:SetSize(opts.width or 400, opts.height or 300)
	if self:GetNumPoints() == 0 then self:SetPoint("CENTER") end
	if opts.escClose ~= false then tinsert(UISpecialFrames, name) end

	self.bar = FK.Frame("Frame", self)
	self.bar:EnableMouse(true)
	self.bar:RegisterForDrag("LeftButton")
	self.bar:SetScript("OnDragStart", function() if not self.locked then self:StartMoving() end end)
	self.bar:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		self:Store()
	end)
	self.plaque = self:CreateTexture(nil, "ARTWORK")
	self.title = self:Text("title", nil, self.bar)
	self.title:SetText(opts.title or ADDON)

	self.close = FK.IconButton(self, { icon = "close", size = 20, bare = true, onClick = function() self:Hide() end })
	self.close:SetFrameLevel(self.bar:GetFrameLevel() + 2)
	self.extra = {}
	for i, b in ipairs(opts.buttons or {}) do
		self.extra[i] = FK.IconButton(self, { icon = b.icon, size = 20, bare = true, tooltip = b.tooltip, onClick = b.onClick })
		self.extra[i]:SetFrameLevel(self.bar:GetFrameLevel() + 2)
	end

	self.content = CreateFrame("Frame", nil, self)

	self.grip = CreateFrame("Button", nil, self)
	self.grip:SetSize(16, 16)
	self.grip:SetPoint("BOTTOMRIGHT", -2, 2)
	self.grip:SetFrameLevel(self:GetFrameLevel() + 10)
	local gripIcon = Theme.Icon(self.grip, "grip", 16)
	gripIcon:SetAllPoints()
	if opts.resizable then
		local r = type(opts.resizable) == "table" and opts.resizable or {}
		self:SetResizable(true)
		self:SetResizeBounds(r.minWidth or 200, r.minHeight or 120, r.maxWidth or 1200, r.maxHeight or 900)
		self.grip:SetScript("OnMouseDown", function() if not self.locked then self:StartSizing("BOTTOMRIGHT") end end)
		self.grip:SetScript("OnMouseUp", function()
			self:StopMovingOrSizing()
			self:Store()
		end)
	end

	self:Hide() -- before the scripts exist: creating a window makes no sound
	self:SetScript("OnShow", function()
		FK.Sound("open")
		if opts.onShow then opts.onShow(self) end
	end)
	self:SetScript("OnHide", function()
		FK.Sound("close")
		if opts.onHide then opts.onHide(self) end
	end)
	if opts.saved then
		FK:OnLoad(function()
			self:Restore()
			opts.saved[1]:OnChange("profile", function() self:Restore() end) -- profile switched
		end)
	end
end)

---@widget Panel  Bordered box that stacks its children; optional title. opts: title, surface = "panel"|"inset"|false, gap, padding. Add children with panel:Add(widget).
FK.Define("Panel", {
	Add = function(self, widget) return self.stack:Add(widget) end,
	Fit = function(self) self.stack:Layout() end,
	Clear = function(self) self.stack:Clear() end,
	Batch = function(self, fn) self.stack:Batch(function() fn(self) end) end,
	Layout = function(self)
		local m = Theme.current.metric
		local pad = self.opts.padding or (self.opts.surface == false and 0 or m.pad)
		local top = pad + (self.title and (self.title:GetStringHeight() + 6) or 0)
		self.stack:ClearAllPoints()
		self.stack:SetPoint("TOPLEFT", pad, -top)
		self.stack:SetPoint("RIGHT", -pad, 0)
		self:SetHeight(top + self.stack:GetHeight() + pad)
		self:Changed()
	end,
	Restyle = function(self)
		local surface = self.opts.surface
		if surface == nil then surface = "panel" end
		Theme.Paint(self, surface and Theme.current.surface[surface] or nil)
		self:Layout()
	end,
}, function(self, opts)
	if opts.title then
		self.title = self:Text("heading")
		local pad = opts.padding or (opts.surface == false and 0 or Theme.current.metric.pad)
		self.title:SetPoint("TOPLEFT", pad, -pad)
		self.title:SetText(opts.title)
	end
	self.stack = FK.Stack(self, { gap = opts.gap })
	self.stack.fkContainer = self
	self.content = self.stack
end)
