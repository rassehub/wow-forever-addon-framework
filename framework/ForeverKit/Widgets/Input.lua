local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

local function inputParts(self, opts)
	self.top = self:Caption(opts.label)
	self.holder = FK.Frame("Frame", self)
	self.holder:SetPoint("TOPLEFT", 0, -self.top)
	self.holder:SetPoint("RIGHT")
	local box = CreateFrame("EditBox", nil, self.holder)
	self.box = box
	box:SetPoint("TOPLEFT", 6, 0)
	box:SetPoint("BOTTOMRIGHT", -6, 0)
	box:SetAutoFocus(false)
	if opts.numeric then box:SetNumeric(true) end
	if opts.maxLetters then box:SetMaxLetters(opts.maxLetters) end
	box.fkRole = opts.small and "small" or "normal"
	self.fkTexts = self.fkTexts or {}
	self.fkTexts[#self.fkTexts + 1] = box
	self.placeholder = self:Text(box.fkRole, "disabled", self.holder)
	self.placeholder:SetPoint("LEFT", 6, 0)
	self.placeholder:SetText(opts.placeholder or "")
	self.value = tostring(opts.value or "")
	box:SetText(self.value)

	box:SetScript("OnEditFocusGained", function()
		self.focused = true
		self:Restyle()
	end)
	box:SetScript("OnEditFocusLost", function()
		self.focused = false
		self:Restyle()
		self:Commit()
	end)
	box:SetScript("OnEnterPressed", function(b)
		self:Commit()
		if opts.onEnter then opts.onEnter(self.value, self) end
		b:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(b)
		b:SetText(self.value) -- Escape discards the edit
		b:ClearFocus()
	end)
	box:SetScript("OnTextChanged", function(b, userInput)
		self.placeholder:SetShown(b:GetText() == "")
		if userInput and opts.onInput then opts.onInput(b:GetText(), self) end
		if self.OnText then self:OnText(b:GetText(), userInput) end
	end)
	self:Hoverable(box)
end

local Input = {
	SetValue = function(self, v)
		self.value = tostring(v or "")
		self.box:SetText(self.value)
	end,
	GetValue = function(self) return self.value end,
	-- The text as typed so far, before it is committed.
	GetText = function(self) return self.box:GetText() end,
	Focus = function(self) self.box:SetFocus() end,
	Commit = function(self)
		local text = self.box:GetText()
		if text == self.value then return end
		self.value = text
		self:Fire(self.opts.numeric and (tonumber(text) or 0) or text)
	end,
	OnEnabled = function(self, enabled) self.box:SetEnabled(enabled) end,
	Restyle = function(self)
		local T = Theme.current
		local h = T.metric.control - (self.opts.small and 4 or 0)
		self:SetHeight(self.top + h)
		self.holder:SetHeight(h)
		Theme.Paint(self.holder, T.surface.input[not self.enabled and "disabled" or self.focused and "focus" or "normal"])
		self.placeholder:SetShown(self.box:GetText() == "")
	end,
}

---@widget EditBox  One-line text input. opts: label, value, placeholder, numeric, maxLetters, small (small text, lower box), onChange(text) when committed (Enter or focus lost; Escape discards), onInput(text) on every keystroke, onEnter(text).
FK.Define("EditBox", Mixin({ fill = false }, Input), function(self, opts)
	if not opts.width then self:SetWidth(160) end
	inputParts(self, opts)
end)

---@widget SearchBox  Text input with a search icon and a clear button; reports while typing, debounced. opts: placeholder (default "Search"), value, delay (default 0.2s), small, onSearch(text).
FK.Define("SearchBox", Mixin({}, Input, {
	Clear = function(self)
		self.box:SetText("")
		self.value = ""
		if self.opts.onSearch then self.opts.onSearch("", self) end
	end,
	OnText = function(self, text, userInput)
		self.clear:SetShown(text ~= "")
		if userInput then self.search(text) end
	end,
	Commit = function(self) self.value = self.box:GetText() end,
}), function(self, opts)
	opts.placeholder = opts.placeholder or FK.L["Search"]
	self.search = FK:Debounce(opts.delay or 0.2, function(text)
		if opts.onSearch then opts.onSearch(text, self) end
	end)
	inputParts(self, opts)
	self.icon = Theme.Icon(self.holder, "search", 12)
	self.icon:SetPoint("LEFT", 5, 0)
	self.box:SetPoint("TOPLEFT", 22, 0)
	self.box:SetPoint("BOTTOMRIGHT", -22, 0)
	self.placeholder:SetPoint("LEFT", 22, 0)
	self.clear = FK.IconButton(self.holder, { icon = "close", size = 16, bare = true, onClick = function() self:Clear() end })
	self.clear:SetPoint("RIGHT", -3, 0)
	self.clear:SetShown(self.value ~= "")
end)
