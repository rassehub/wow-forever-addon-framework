local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

---@widget Label  Text. opts: text, role = "normal"|"small"|"heading"|"large", color = theme colour name, align = "LEFT"|"CENTER"|"RIGHT", wrap (default true).
FK.Define("Label", {
	SetText = function(self, text)
		self.text:SetText(text)
		self:Fit()
		self:Changed()
	end,
	GetText = function(self) return self.text:GetText() end,
	-- Height follows the wrapped text; an unsized label takes its text's width.
	Fit = function(self)
		if self:GetWidth() <= 0 then self:SetWidth(self.text:GetStringWidth() + 1) end
		self:SetHeight(math.max(self.text:GetStringHeight(), 1))
	end,
	Restyle = function(self) self:Fit() end,
}, function(self, opts)
	self.text = self:Text(opts.role or "normal", opts.color)
	self.text:SetPoint("TOPLEFT")
	self.text:SetPoint("TOPRIGHT")
	self.text:SetJustifyH(opts.align or "LEFT")
	self.text:SetJustifyV("TOP")
	self.text:SetWordWrap(opts.wrap ~= false)
	self.text:SetText(opts.text or "")
end)

---@widget Heading  Section title with a rule under it. opts: text.
FK.Define("Heading", {
	SetText = function(self, text) self.text:SetText(text) end,
	Restyle = function(self)
		self.line:SetColorTexture(Theme.Color("divider"))
		self:SetHeight(self.text:GetStringHeight() + 6)
	end,
}, function(self, opts)
	self.text = self:Text("heading")
	self.text:SetPoint("TOPLEFT")
	self.text:SetText(opts.text or "")
	self.line = self:CreateTexture(nil, "ARTWORK")
	self.line:SetHeight(1)
	self.line:SetPoint("BOTTOMLEFT")
	self.line:SetPoint("BOTTOMRIGHT")
end)

---@widget Divider  Horizontal rule. opts: height (space it takes, default 9).
FK.Define("Divider", {
	Restyle = function(self) self.line:SetColorTexture(Theme.Color("divider")) end,
}, function(self, opts)
	self:SetHeight(opts.height or 9)
	self.line = self:CreateTexture(nil, "ARTWORK")
	self.line:SetHeight(1)
	self.line:SetPoint("LEFT")
	self.line:SetPoint("RIGHT")
end)

---@widget Spacer  Empty vertical space. opts: height.
FK.Define("Spacer", {}, function(self, opts) self:SetSize(1, opts.height or 8) end)

---@widget Button  Push button. opts: text, onClick(widget, mouseButton), width (default: fits the text, at least 80).
FK.Define("Button", {
	fill = false,
	SetText = function(self, text)
		self.text:SetText(text)
		if not self.opts.width then
			self:SetWidth(math.max(80, self.text:GetStringWidth() + Theme.current.metric.buttonPad * 2))
		end
	end,
	GetText = function(self) return self.text:GetText() end,
	Click = function(self) self.button:Click() end,
	Restyle = function(self)
		local T = Theme.current
		self:SetHeight(self.opts.height or T.metric.control)
		Theme.PaintState(self.button, T.surface.button, Theme.State(self))
		self.text:SetPoint("CENTER", 0, self.down and self.enabled and -1 or 0)
		self:SetText(self.text:GetText())
	end,
}, function(self, opts)
	self.button = self:Clickable(self, function(mouseButton)
		FK.Sound("click")
		if opts.onClick then opts.onClick(self, mouseButton) end
	end)
	self.button:SetAllPoints()
	self.text = self:Text("button", nil, self.button)
	self.text:SetPoint("CENTER")
	self.text:SetText(opts.text or "")
end)

---@widget IconButton  Small square button showing a theme icon or a texture. opts: icon (theme icon name, texture path or file id), size, onClick(widget, mouseButton), bare (no button surface).
FK.Define("IconButton", {
	fill = false,
	SetIcon = function(self, icon)
		self.opts.icon = icon
		self:Restyle()
	end,
	Click = function(self) self.button:Click() end,
	Restyle = function(self)
		local T = Theme.current
		local size = self.opts.size or T.metric.control
		self:SetSize(size, size)
		if self.opts.bare then
			Theme.Paint(self.button, nil)
		else
			Theme.PaintState(self.button, T.surface.button, Theme.State(self))
		end
		local icon = self.opts.icon
		if T.icon[icon] or FK.mediaIcons[icon] then -- theme glyph, or any icon of the library's set
			self.tex:Hide()
			self.glyph:Show()
			self.glyph.iconName = icon
			self.glyph.colorRole = not self.enabled and "disabled" or (self.opts.bare and self.hover and "accent") or nil
			self.glyph:Restyle()
		else
			self.glyph:Hide()
			self.tex:Show()
			self.tex:SetTexture(icon)
			self.tex:SetDesaturated(not self.enabled)
		end
	end,
}, function(self, opts)
	self.button = self:Clickable(self, function(mouseButton)
		FK.Sound("click")
		if opts.onClick then opts.onClick(self, mouseButton) end
	end)
	self.button:SetAllPoints()
	self.button:RegisterForClicks("AnyUp")
	self.glyph = Theme.Icon(self.button, "close")
	self.glyph:SetPoint("CENTER")
	self.tex = self.button:CreateTexture(nil, "ARTWORK")
	self.tex:SetPoint("TOPLEFT", 3, -3)
	self.tex:SetPoint("BOTTOMRIGHT", -3, 3)
end)

local function checkParts(self, opts, markKey)
	self.button = self:Clickable(self, function()
		self.value = not self.value
		FK.Sound(self.value and "check" or "uncheck")
		self:Restyle()
		self:Fire(self.value)
	end)
	self.button:SetPoint("TOPLEFT")
	self.button:SetPoint("BOTTOMLEFT")
	self.box = FK.Frame("Frame", self.button)
	self.box:SetPoint("LEFT")
	self.mark = self.box:CreateTexture(nil, "OVERLAY")
	self.text = self:Text("normal", nil, self.button)
	self.text:SetPoint("LEFT", self.box, "RIGHT", 6, 0)
	self.text:SetText(opts.label or opts.text or "")
	self.value = opts.value and true or false
	self.markKey = markKey
end

local Check = {
	fill = false,
	SetValue = function(self, v)
		self.value = v and true or false
		self:Restyle()
	end,
	GetValue = function(self) return self.value end,
	SetLabel = function(self, text)
		self.text:SetText(text)
		self:Restyle()
	end,
	Click = function(self) self.button:Click() end,
	Restyle = function(self)
		local T = Theme.current
		local size = T.metric.check
		self.box:SetSize(size, size)
		Theme.PaintState(self.box, T.surface.check, Theme.State(self))
		local mark = T.surface[self.markKey]
		local inset = mark.inset or 0
		self.mark:ClearAllPoints()
		self.mark:SetPoint("TOPLEFT", inset, -inset)
		self.mark:SetPoint("BOTTOMRIGHT", -inset, inset)
		Theme.Texture(self.mark, mark, self.enabled and 1 or 0.4)
		self.mark:SetShown(self.value)
		-- the click area covers the box and its label, not the whole row
		local width = size + 6 + self.text:GetStringWidth()
		self.button:SetWidth(width)
		self:SetHeight(math.max(size, T.metric.row))
		if not self.opts.width then self:SetWidth(width) end
	end,
}

---@widget CheckBox  Box with a tick and a label. opts: label, value (bool), onChange(bool).
FK.Define("CheckBox", Check, function(self, opts) checkParts(self, opts, "checkMark") end)

---@widget Toggle  On/off switch with a label: same behaviour as CheckBox, reads better for settings that take effect at once. opts: label, value (bool), onChange(bool).
FK.Define("Toggle", Mixin({}, Check, {
	Restyle = function(self)
		local T = Theme.current
		local h, w = T.metric.check, T.metric.toggleWidth
		self.box:SetSize(w, h)
		Theme.Paint(self.box, T.surface.toggle[self.value and "on" or "off"])
		self.box:SetAlpha(self.enabled and 1 or 0.5)
		self.mark:ClearAllPoints()
		self.mark:SetSize(h - 6, h - 6)
		self.mark:SetPoint(self.value and "RIGHT" or "LEFT", self.value and -3 or 3, 0)
		Theme.Texture(self.mark, T.surface.knob)
		local width = w + 6 + self.text:GetStringWidth()
		self.button:SetWidth(width)
		self:SetHeight(math.max(h, T.metric.row))
		if not self.opts.width then self:SetWidth(width) end
	end,
}), function(self, opts) checkParts(self, opts, "knob") end)

---@widget ProgressBar  Filled bar with centred text. opts: min, max, value, text or format (string or function(value, max)), color (theme colour or {r,g,b}). Accepts secret values: it passes them to the client without reading them.
FK.Define("ProgressBar", {
	SetValue = function(self, value, max)
		if max ~= nil then
			self.max = max
			self.bar:SetMinMaxValues(self.min, max)
		end
		self.value = value
		self.bar:SetValue(value)
		local fmt = self.opts.format
		if type(fmt) == "function" then
			self.text:SetText(fmt(value, self.max))
		elseif fmt then
			-- string.format accepts secret numbers and returns a secret string, which SetText may show
			self.text:SetText(fmt:format(value, self.max))
		end
	end,
	GetValue = function(self) return self.value end,
	SetText = function(self, text) self.text:SetText(text) end,
	SetColor = function(self, color)
		self.opts.color = color
		self:Restyle()
	end,
	Restyle = function(self)
		local T = Theme.current
		if not self.opts.height then self:SetHeight(T.metric.control - 4) end
		Theme.Paint(self, T.surface.barBackground)
		self.bar:SetStatusBarTexture(T.surface.bar.texture)
		local c = self.opts.color or "accent"
		if type(c) == "table" then self.bar:SetStatusBarColor(c[1], c[2], c[3]) else self.bar:SetStatusBarColor(Theme.Color(c)) end
	end,
}, function(self, opts)
	self.min, self.max = opts.min or 0, opts.max or 1
	self.bar = CreateFrame("StatusBar", nil, self)
	self.bar:SetPoint("TOPLEFT", 1, -1)
	self.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	self.bar:SetMinMaxValues(self.min, self.max)
	self.text = self:Text("small", nil, self.bar)
	self.text:SetPoint("CENTER")
	if opts.text then self.text:SetText(opts.text) end
	self:SetValue(opts.value or self.min)
end)
