local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Composite list items: a label line that can own a switch, a control on the right, and an
-- expandable block of child widgets. These are the building blocks of settings lists.

---@widget OptionRow  General settings row: [toggle] label + description ....... [control] [expand arrow], with children shown underneath when expanded. opts: label, desc, toggle (bool: adds a switch with this initial state; nil: none), control = widget spec for the right side ({ "Slider", min = .., max = .. } etc.), controlWidth (default 190), children = { widget specs } shown when expanded, expanded, cog (use a cog instead of an arrow), linkExpand (default true: switching on expands, switching off collapses), onToggle(bool), onChange(value) for the control. Turning the switch off disables the control and children. Methods: SetToggle, GetToggle, SetValue, GetValue (the control's), SetExpanded, .control, .refs (children with an id).
FK.Define("OptionRow", {
	ownsChildren = true, -- FK.Build: opts.children are this row's own, already built
	SetToggle = function(self, on)
		if self.toggle then self.toggle:SetValue(on) end
		self:Apply()
	end,
	GetToggle = function(self) return self.toggle == nil or self.toggle:GetValue() end,
	SetValue = function(self, v) if self.control then self.control:SetValue(v) end end,
	GetValue = function(self) return self.control and self.control:GetValue() end,
	SetExpanded = function(self, expanded)
		if not self.body then return end
		self.expanded = expanded and true or false
		self:Arrange()
	end,
	-- Dependent parts follow the switch and the row's own enabled state.
	Apply = function(self)
		local on = self.enabled and self:GetToggle()
		if self.control then self.control:SetEnabled(on) end
		if self.toggle then self.toggle:SetEnabled(self.enabled) end
		for _, child in ipairs(self.body and self.body.items or {}) do
			if child.SetEnabled then child:SetEnabled(on) end
		end
	end,
	OnEnabled = function(self) self:Apply() end,
	Arrange = function(self)
		if self.arranging then return end -- the body reports back while we lay it out
		self.arranging = true
		local T = Theme.current
		local headHeight = math.max(T.metric.row, self.control and self.control:GetHeight() or 0, self.toggle and self.toggle:GetHeight() or 0)
		local descHeight = self.desc and (self.desc:GetStringHeight() + 2) or 0
		self.head:SetHeight(headHeight)
		local height = headHeight + descHeight
		if self.body then
			self.body:SetShown(self.expanded)
			self.arrow:SetIcon(self.opts.cog and "cog" or (self.expanded and "arrowDown" or "arrowRight"))
			if self.expanded then
				self.body:ClearAllPoints()
				self.body:SetPoint("TOPLEFT", 20, -height - 4)
				self.body:SetPoint("RIGHT")
				self.body:Layout()
				height = height + 4 + self.body:GetHeight()
			end
		end
		self:SetHeight(height)
		self.arranging = nil
		self:Changed()
	end,
	Layout = function(self) self:Arrange() end, -- the body stack reports height changes here
	Fit = function(self) self:Arrange() end,
	Restyle = function(self) self:Arrange() end,
}, function(self, opts)
	self.head = CreateFrame("Frame", nil, self)
	self.head:SetPoint("TOPLEFT")
	self.head:SetPoint("TOPRIGHT")
	local right = 0
	if opts.children then
		self.arrowButton = FK.IconButton(self.head, { icon = opts.cog and "cog" or "arrowRight", size = 18, bare = true,
			tooltip = opts.cog and FK.L["More settings"] or nil,
			onClick = function() self:SetExpanded(not self.expanded) end })
		self.arrowButton:SetPoint("RIGHT")
		self.arrow = self.arrowButton
		right = 22
	end
	if opts.control then
		local spec = FK.Copy(opts.control)
		spec.onChange = opts.onChange or spec.onChange
		spec.width = nil
		self.control = FK.Build(self.head, spec)
		self.control:SetWidth(opts.controlWidth or 190)
		self.control:SetPoint("RIGHT", -right, 0)
		right = right + (opts.controlWidth or 190) + 8
	end
	if opts.toggle ~= nil then
		self.toggle = FK.Toggle(self.head, { label = opts.label, value = opts.toggle, tooltip = opts.tooltip, onChange = function(on)
			self:Apply()
			if self.body and opts.linkExpand ~= false then self:SetExpanded(on) end
			if opts.onToggle then opts.onToggle(on, self) end
		end })
		self.toggle:SetPoint("LEFT")
	else
		self.label = self:Text("normal", nil, self.head)
		self.label:SetPoint("LEFT")
		self.label:SetPoint("RIGHT", -right, 0)
		self.label:SetJustifyH("LEFT")
		self.label:SetWordWrap(false)
		self.label:SetText(opts.label or "")
	end
	if opts.desc then
		self.desc = self:Text("small", "dim")
		self.desc:SetPoint("TOPLEFT", self.head, "BOTTOMLEFT", opts.toggle ~= nil and (Theme.current.metric.toggleWidth + 6) or 0, 0)
		self.desc:SetPoint("RIGHT", -right, 0)
		self.desc:SetJustifyH("LEFT")
		self.desc:SetText(opts.desc)
	end
	if opts.children then
		self.body = FK.Stack(self, {})
		self.body.fkContainer = self
		self.refs = {}
		self.body:Batch(function(body)
			for _, spec in ipairs(opts.children) do body:Add(FK.Build(body, spec, self.refs)) end
		end)
		self.expanded = opts.expanded
		if self.expanded == nil then self.expanded = opts.toggle == true and opts.linkExpand ~= false end
	end
	self:Apply()
end)

-- Named shortcuts for the common shapes, so intent is visible at the call site.

---@widget ToggleRow  Switch with a label and an optional description line. opts: label, desc, value, onChange(bool).
function FK.ToggleRow(parent, opts)
	return FK.OptionRow(parent, { label = opts.label, desc = opts.desc, tooltip = opts.tooltip, toggle = opts.value and true or false, onToggle = opts.onChange, disabled = opts.disabled })
end

---@widget SliderRow  Label on the left, slider on the right, on one line. opts: label, desc, plus every Slider option (min, max, step, value, format, percent, live), onChange(value).
function FK.SliderRow(parent, opts)
	local spec = FK.Copy(opts)
	spec[1], spec.label, spec.desc, spec.onChange = "Slider", nil, nil, nil
	return FK.OptionRow(parent, { label = opts.label, desc = opts.desc, control = spec, controlWidth = opts.controlWidth or 220, onChange = opts.onChange, disabled = opts.disabled })
end

---@widget ToggleSliderRow  "Enable X" switch plus the amount of X: the slider is disabled while the switch is off. opts: label, desc, enabled (bool), onToggle(bool), plus every Slider option, onChange(value).
function FK.ToggleSliderRow(parent, opts)
	local spec = FK.Copy(opts)
	spec[1], spec.label, spec.desc, spec.onChange, spec.onToggle, spec.enabled = "Slider", nil, nil, nil, nil, nil
	return FK.OptionRow(parent, { label = opts.label, desc = opts.desc, toggle = opts.enabled and true or false, onToggle = opts.onToggle,
		control = spec, controlWidth = opts.controlWidth or 220, onChange = opts.onChange, linkExpand = false })
end

---@widget ToggleDropdownRow  Switch plus a choice that only matters while it is on (play sound + which sound; announce + channel). opts: label, desc, enabled, onToggle(bool), items, value, onChange(value).
function FK.ToggleDropdownRow(parent, opts)
	return FK.OptionRow(parent, { label = opts.label, desc = opts.desc, toggle = opts.enabled and true or false, onToggle = opts.onToggle,
		control = { "Dropdown", items = opts.items, value = opts.value, placeholder = opts.placeholder }, controlWidth = opts.controlWidth or 160, onChange = opts.onChange, linkExpand = false })
end

---@widget ToggleListRow  Switch that owns a block of further settings: switching it on unfolds them, off folds and disables them. opts: label, desc, enabled, onToggle(bool), children = { widget specs }, cog (keep folded until the cog is clicked).
function FK.ToggleListRow(parent, opts)
	return FK.OptionRow(parent, { label = opts.label, desc = opts.desc, toggle = opts.enabled and true or false, onToggle = opts.onToggle,
		children = opts.children, cog = opts.cog, linkExpand = not opts.cog, expanded = opts.expanded })
end

---@widget CheckList  Many on/off items in a scrolling list with All / None buttons and an optional filter box (which node types to show, which abilities to announce). opts: label, items, value = { [itemValue] = true }, search (bool), onChange(valueSet). Needs a height.
FK.Define("CheckList", {
	SetValue = function(self, set)
		self.value = FK.Copy(set or {})
		self.list:Refresh()
	end,
	GetValue = function(self) return FK.Copy(self.value) end,
	SetItems = function(self, items)
		self.opts.items = items
		self:Filter()
	end,
	SetAll = function(self, on)
		for _, item in ipairs(self.shown) do self.value[item.value] = on or nil end
		self.list:Refresh()
		self:Fire(self:GetValue())
	end,
	Filter = function(self, text)
		text = (text or self.filter or ""):lower()
		self.filter = text
		self.shown = {}
		for _, item in ipairs(FK.ResolveItems(self.opts.items)) do
			if text == "" or tostring(item.label):lower():find(text, 1, true) then self.shown[#self.shown + 1] = item end
		end
		self.list:SetItems(self.shown)
	end,
	Restyle = function(self)
		Theme.Paint(self.frame, Theme.current.surface.inset)
		self.list:Refresh()
	end,
}, function(self, opts)
	self.value, self.shown = FK.Copy(opts.value or {}), {}
	local top = self:Caption(opts.label)
	self.none = FK.Button(self, { text = FK.L["None"], width = 60, height = 18, onClick = function() self:SetAll(false) end })
	self.none:SetPoint("TOPRIGHT")
	self.all = FK.Button(self, { text = FK.L["All"], width = 60, height = 18, onClick = function() self:SetAll(true) end })
	self.all:SetPoint("RIGHT", self.none, "LEFT", -4, 0)
	top = math.max(top, 22)
	if opts.search then
		self.searchBox = FK.SearchBox(self, { onSearch = function(text) self:Filter(text) end, delay = 0.1 })
		self.searchBox:SetPoint("TOPLEFT", 0, -top)
		self.searchBox:SetPoint("RIGHT")
		top = top + self.searchBox:GetHeight() + 4
	end
	self.frame = FK.Frame("Frame", self)
	self.frame:SetPoint("TOPLEFT", 0, -top)
	self.frame:SetPoint("BOTTOMRIGHT")
	self.list = FK.ScrollList(self.frame, {
		create = function(row)
			row.box = FK.Frame("Frame", row)
			row.box:SetPoint("LEFT", 4, 0)
			row.mark = row.box:CreateTexture(nil, "OVERLAY")
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
		end,
		update = function(row, item)
			local T = Theme.current
			local size = math.min(T.metric.check, T.metric.row - 4)
			row.box:SetSize(size, size)
			Theme.PaintState(row.box, T.surface.check, row.hover and "hover" or "normal")
			local mark = T.surface.checkMark
			local inset = math.min(mark.inset or 0, 3)
			row.mark:ClearAllPoints()
			row.mark:SetPoint("TOPLEFT", inset, -inset)
			row.mark:SetPoint("BOTTOMRIGHT", -inset, inset)
			Theme.Texture(row.mark, mark)
			row.mark:SetShown(self.value[item.value] == true)
			local x = size + 10
			row.icon:SetShown(item.icon ~= nil)
			if item.icon then
				row.icon:SetTexture(item.icon)
				row.icon:SetSize(size, size)
				row.icon:SetPoint("LEFT", x, 0)
				x = x + size + 4
			end
			row.text:SetPoint("LEFT", x, 0)
			Theme.Font(row.text, "normal")
			row.text:SetText(item.label)
		end,
		onClick = function(item)
			self.value[item.value] = not self.value[item.value] or nil
			FK.Sound(self.value[item.value] and "check" or "uncheck")
			self:Fire(self:GetValue())
		end,
	})
	self.list:SetPoint("TOPLEFT", 3, -3)
	self.list:SetPoint("BOTTOMRIGHT", -3, 3)
	if not opts.height then self:SetHeight(top + 160) end
	self:Filter("")
end)

---@widget ReorderList  Ordered items the user can rearrange with up/down arrows, each optionally with its own on/off switch (bar order, category order, priority lists). opts: label, items, value = ordered list of item values (default: the items' order), toggles = { [itemValue] = bool } (omit for no switches), onChange(orderList, togglesSet). Needs a height.
FK.Define("ReorderList", {
	GetValue = function(self) return { unpack(self.order) }, self.toggles and FK.Copy(self.toggles) or nil end,
	SetValue = function(self, order, toggles)
		self.order = { unpack(order) }
		if toggles then self.toggles = FK.Copy(toggles) end
		self:Refresh()
	end,
	Move = function(self, value, delta)
		for i, v in ipairs(self.order) do
			if v == value then
				local j = i + delta
				if j < 1 or j > #self.order then return end
				self.order[i], self.order[j] = self.order[j], self.order[i]
				break
			end
		end
		self:Refresh()
		self:Report()
	end,
	-- two values (order, toggles), so not through the one-value Fire
	Report = function(self)
		if self.opts.onChange then self.opts.onChange(self:GetValue()) end
	end,
	Refresh = function(self)
		local byValue, rows = {}, {}
		for _, item in ipairs(FK.ResolveItems(self.opts.items)) do byValue[item.value] = item end
		for i, v in ipairs(self.order) do
			if byValue[v] then rows[#rows + 1] = { item = byValue[v], position = i } end
		end
		self.list:SetItems(rows)
	end,
	Restyle = function(self)
		Theme.Paint(self.frame, Theme.current.surface.inset)
		self.list:Refresh()
	end,
}, function(self, opts)
	local top = self:Caption(opts.label)
	self.order = {}
	for _, item in ipairs(opts.value or FK.ResolveItems(opts.items)) do
		self.order[#self.order + 1] = type(item) == "table" and item.value or item
	end
	self.toggles = opts.toggles and FK.Copy(opts.toggles) or nil
	self.frame = FK.Frame("Frame", self)
	self.frame:SetPoint("TOPLEFT", 0, -top)
	self.frame:SetPoint("BOTTOMRIGHT")
	self.list = FK.ScrollList(self.frame, {
		create = function(row)
			row.down = FK.IconButton(row, { icon = "arrowDown", size = 16, bare = true, tooltip = FK.L["Move down"], onClick = function() self:Move(row.item.item.value, 1) end })
			row.down:SetPoint("RIGHT", -2, 0)
			row.up = FK.IconButton(row, { icon = "arrowUp", size = 16, bare = true, tooltip = FK.L["Move up"], onClick = function() self:Move(row.item.item.value, -1) end })
			row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
			row.number = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.number:SetPoint("LEFT", 4, 0)
			row.number:SetWidth(18)
			if self.toggles then
				row.toggle = FK.CheckBox(row, { label = "", onChange = function(on)
					self.toggles[row.item.item.value] = on
					self.list:Refresh()
					self:Report()
				end })
				row.toggle:SetPoint("LEFT", 24, 0)
			end
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetPoint("RIGHT", row.up, "LEFT", -4, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
		end,
		update = function(row, entry)
			local on = not self.toggles or self.toggles[entry.item.value] ~= false
			Theme.Font(row.number, "small", "dim")
			row.number:SetText(entry.position)
			row.text:SetPoint("LEFT", self.toggles and 24 + Theme.current.metric.check + 6 or 26, 0)
			Theme.Font(row.text, "normal", not on and "disabled" or nil)
			row.text:SetText(entry.item.label)
			if row.toggle then row.toggle:SetValue(on) end
			row.up:SetEnabled(entry.position > 1)
			row.down:SetEnabled(entry.position < #self.order)
		end,
	})
	self.list:SetPoint("TOPLEFT", 3, -3)
	self.list:SetPoint("BOTTOMRIGHT", -3, 3)
	if not opts.height then self:SetHeight(top + 6 + Theme.current.metric.row * math.min(#self.order, 8)) end
	self:Refresh()
end)

---@widget MoneyInput  Amount of money as gold / silver / copper boxes. opts: label, value (copper), onChange(copper).
FK.Define("MoneyInput", {
	fill = false,
	SetValue = function(self, copper)
		self.value = math.max(0, math.floor(copper or 0))
		self.gold:SetValue(math.floor(self.value / 10000))
		self.silver:SetValue(math.floor(self.value / 100) % 100)
		self.copper:SetValue(self.value % 100)
	end,
	GetValue = function(self) return self.value end,
	Read = function(self)
		local function n(box) return tonumber(box:GetText()) or 0 end
		local v = n(self.gold) * 10000 + math.min(n(self.silver), 99) * 100 + math.min(n(self.copper), 99)
		if v ~= self.value then
			self:SetValue(v)
			self:Fire(v)
		else
			self:SetValue(v)
		end
	end,
	OnEnabled = function(self, enabled)
		for _, box in ipairs({ self.gold, self.silver, self.copper }) do box:SetEnabled(enabled) end
	end,
	Restyle = function(self) self:SetHeight(self.top + Theme.current.metric.control) end,
}, function(self, opts)
	self.top = self:Caption(opts.label)
	self:SetWidth(opts.width or 200)
	local x = 0
	local function box(width, unit, color, max)
		local b = FK.EditBox(self, { width = width, numeric = true, maxLetters = max, onChange = function() self:Read() end })
		b:SetPoint("BOTTOMLEFT", x, 0)
		local u = self:Text("normal")
		u:SetPoint("LEFT", b, "RIGHT", 3, 0)
		u:SetText("|cff" .. color .. unit .. "|r")
		x = x + width + 18
		return b
	end
	self.gold, self.silver, self.copper = box(70, "g", "ffd100", 7), box(36, "s", "c7c7cf", 2), box(36, "c", "eda55f", 2)
	self:SetValue(opts.value or 0)
end)
