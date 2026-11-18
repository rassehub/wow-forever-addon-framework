local ADDON, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Choosing among named options: Dropdown, MultiDropdown, Segmented, RadioGroup, and the
-- shared popup list they (and context menus) open.
--
-- `items` is an ordered list. An item is a string (value and label at once) or a table:
--   { value = "raid", label = "Raid", icon = texture, color = {r,g,b}, disabled = true,
--     tooltip = "...", checked = bool | fn(item) (a tick; the list stays open when clicked),
--     radio = true (a round mark instead of a tick), children = items (a submenu) }
--   also { header = "Title" } and { divider = true }
-- `items` may be a function returning that list, evaluated each time the list opens.

-- Menus can also be built the way the client's MenuUtil builds them: a function receives a
-- builder; every Add* returns a builder for that entry's submenu.
--   FK.Menu(function(m)
--       m:Header("Columns")
--       m:Check("Bags", function() return show.bags end, function() show.bags = not show.bags end)
--       local move = m:Item("Move to")              -- an entry that only opens a submenu
--       move:Item("Bank", function() ... end)
--   end)
local Builder = {}
Builder.__index = Builder
function Builder:List()
	if not self.list then
		self.item.children = self.item.children or {}
		self.list = self.item.children
	end
	return self.list
end
function Builder:Add(item)
	local list = self:List()
	list[#list + 1] = item
	return setmetatable({ item = item }, Builder)
end
function Builder:Header(text) return self:Add({ header = text }) end
function Builder:Divider() return self:Add({ divider = true }) end
function Builder:Item(label, onClick) return self:Add({ label = label, onClick = onClick }) end
function Builder:Check(label, checked, onClick) return self:Add({ label = label, checked = checked, onClick = onClick }) end
function Builder:Radio(label, checked, onClick) return self:Add({ label = label, radio = true, checked = checked, onClick = onClick }) end

local function resolveItems(items)
	if type(items) == "function" then
		local builder = setmetatable({ list = {} }, Builder)
		local returned = items(builder) -- a list, or nothing when it used the builder
		items = type(returned) == "table" and returned or builder.list
	end
	local out = {}
	for i, item in ipairs(items or {}) do
		if type(item) ~= "table" then item = { value = item, label = tostring(item) } end
		if item.label == nil and item.value ~= nil then item.label = tostring(item.value) end
		out[i] = item
	end
	return out
end
FK.ResolveItems = resolveItems

-- Decision 5 of the plan: preset numbers are a slider's job.
local function warnIfNumeric(kind, items)
	if #items < 3 then return end
	local unit
	for _, item in ipairs(items) do
		-- "40", "40 yd", "1.5x": a number followed by the same unit in every item
		local number, u = tostring(item.label or ""):match("^%s*(%-?%d[%d%.,]*)%s*(.-)%s*$")
		if not number or (unit ~= nil and u ~= unit) then return end
		unit = u
	end
	FK:Warn("ui-enum-should-be-slider", ("%s offers only numbers (%s ... %s): use FK.Slider with min/max/step so any value can be chosen")
		:format(kind, tostring(items[1].label), tostring(items[#items].label)))
end

---------------------------------------------------------------------------------------------
-- Popup list (one per addon, reused). FK.Popup is the first level; an item with children
-- opens the next level beside it (FK.Popup.child), and so on.
---------------------------------------------------------------------------------------------

local Level = {}
Level.__index = Level
local Popup = setmetatable({ rows = {}, offset = 0, depth = 1 }, Level)
Popup.root = Popup
FK.Popup = Popup

-- A ticked state: item.checked is a value or a function called each time the list draws.
local function isChecked(level, item)
	if item.checked ~= nil then
		if type(item.checked) == "function" then return item.checked(item) and true or false end
		return item.checked and true or false
	end
	local o = level.opts
	return o.isChecked and not item.header and not item.divider and o.isChecked(item) and true or false
end
local function checkable(level, item) return item.checked ~= nil or (level.opts.isChecked ~= nil and not item.header and not item.divider) end
local function inert(item) return item.header or item.divider or item.disabled end

function Level:Create()
	local root = self.root
	if not root.catcher then
		local catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:RegisterForClicks("AnyUp")
		catcher:SetScript("OnClick", function() root:Close() end)
		catcher:Hide()
		root.catcher = catcher
	end
	-- deeper levels sit on the level before them, so closing one closes everything after it
	local parentFrame = self.parent and self.parent.frame or root.catcher
	local f = FK.Frame("Frame", parentFrame, self == root and (ADDON .. "FKPopup") or nil)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(parentFrame:GetFrameLevel() + 5)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-delta * 3) end)
	if self == root then
		f:SetScript("OnHide", function() root.catcher:Hide() end)
		tinsert(UISpecialFrames, ADDON .. "FKPopup") -- Escape closes it
	end
	f.more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.more:SetPoint("BOTTOM", 0, 4)
	self.frame = f
end

function Level:CreateRow()
	local row = CreateFrame("Button", nil, self.frame)
	row.hl = row:CreateTexture(nil, "BACKGROUND")
	row.hl:SetAllPoints()
	row.hl:Hide()
	row.check = row:CreateTexture(nil, "ARTWORK")
	row.check:SetPoint("LEFT", 5, 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	row.arrow = Theme.Icon(row, "arrowRight", 10)
	row.arrow:SetPoint("RIGHT", -5, 0)
	row.line = row:CreateTexture(nil, "ARTWORK")
	row.line:SetHeight(1)
	row.line:SetPoint("LEFT", 4, 0)
	row.line:SetPoint("RIGHT", -4, 0)
	row:SetScript("OnEnter", function(r)
		local item = r.item
		if inert(item) then return self:CloseChild() end
		r.hl:Show()
		if item.children then self:OpenChild(r) else self:CloseChild() end
		if item.tooltip then
			GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
			GameTooltip:SetText(item.tooltip, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(r)
		if not (self.child and self.child.from == r and self.child.frame:IsShown()) then r.hl:Hide() end
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(r)
		local item = r.item
		if inert(item) then return end
		-- a row that only opens a submenu; a tick box with a submenu still ticks
		if item.children and item.checked == nil then return self:OpenChild(r) end
		FK.Sound("click")
		local o = self.opts
		-- ticking a box or a radio leaves the menu open, as the client's menus do
		if not (o.keepOpen or item.keepOpen or item.checked ~= nil) then self.root:Close() end
		if item.onClick then item.onClick(item) end
		if o.onPick then o.onPick(item) end
		for level in self.root:Levels() do
			if level.frame:IsShown() then level:Render() end
		end
	end)
	return row
end

-- The open levels, first to last.
function Level:Levels()
	local level, started = nil, false
	return function()
		if started then level = level and level.child else level, started = self.root, true end
		if level and level.frame and level.frame:IsShown() then return level end
	end
end

function Level:OpenChild(row)
	if not self.child then
		self.child = setmetatable({ rows = {}, offset = 0, parent = self, root = self.root, depth = self.depth + 1 }, Level)
	end
	local child = self.child
	if child.from == row and child.frame and child.frame:IsShown() then return end
	child:Open(row, row.item.children, { submenu = true })
	child.from = row
	for _, r in ipairs(self.rows) do r.hl:SetShown(r == row) end
end

function Level:CloseChild()
	local child = self.child
	if child and child.frame and child.frame:IsShown() then
		child.frame:Hide()
		child.from = nil
		for _, r in ipairs(self.rows) do r.hl:Hide() end
	end
end

function Level:Render()
	local T, o, items = Theme.current, self.opts, self.items
	local rowH, maxRows = T.metric.row, o.maxRows or 12
	local visible = math.min(#items, maxRows)
	self.offset = FK.Clamp(self.offset, 0, math.max(0, #items - maxRows))
	local anyCheck = o.isChecked ~= nil
	for _, item in ipairs(items) do anyCheck = anyCheck or item.checked ~= nil end
	for i = 1, math.max(visible, #self.rows) do
		local row = self.rows[i]
		local item = i <= visible and items[self.offset + i]
		if item then
			row = row or self:CreateRow()
			self.rows[i] = row
			row.item = item
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 3, -3 - (i - 1) * rowH)
			row:SetPoint("RIGHT", -3, 0)
			row:SetHeight(rowH)
			Theme.Texture(row.hl, T.surface.row.hover)
			row.line:SetShown(item.divider == true)
			row.line:SetColorTexture(Theme.Color("divider"))
			local checked = checkable(self, item) and isChecked(self, item)
			row.check:SetShown(checked)
			local mark = item.radio and T.surface.radioMark or T.surface.checkMark
			row.check:SetSize(item.radio and 8 or 10, item.radio and 8 or 10)
			Theme.Texture(row.check, mark)
			row.arrow:SetShown(item.children ~= nil)
			row.arrow:Restyle()
			local x = anyCheck and 20 or 6
			row.icon:SetShown(item.icon ~= nil)
			if item.icon then
				row.icon:SetTexture(item.icon)
				row.icon:SetSize(rowH - 6, rowH - 6)
				row.icon:SetPoint("LEFT", x, 0)
				x = x + rowH - 2
			end
			row.text:ClearAllPoints()
			row.text:SetPoint("LEFT", x, 0)
			row.text:SetPoint("RIGHT", item.children and -18 or -6, 0)
			Theme.Font(row.text, item.header and "heading" or "normal", item.disabled and "disabled" or nil)
			if item.color and not item.disabled then row.text:SetTextColor(item.color[1], item.color[2], item.color[3]) end
			row.text:SetText(item.divider and "" or item.header or item.label)
			row:Show()
		elseif row then
			row:Hide()
		end
	end
	local more = #items > maxRows
	self.frame.more:SetShown(more)
	if more then
		self.frame.more:SetText(("%d-%d / %d"):format(self.offset + 1, self.offset + visible, #items))
	end
	self.frame:SetHeight(visible * rowH + 6 + (more and 14 or 0))
end

function Level:Scroll(delta)
	self.offset = self.offset + delta
	self:CloseChild()
	self:Render()
end

-- FK.Popup:Open(anchor, items, { onPick = fn(item), isChecked = fn(item), keepOpen, width, maxRows, atCursor })
function Level:Open(anchor, items, opts)
	if not self.frame then self:Create() end
	opts = opts or {}
	self:CloseChild()
	self.items, self.opts, self.anchor, self.offset = resolveItems(items), opts, anchor, 0
	local f = self.frame
	Theme.Paint(f, Theme.current.surface.menu)
	local width = opts.width or 0
	if not opts.width then
		local probe = f.more
		for _, item in ipairs(self.items) do
			probe:SetText(item.header or item.label or "")
			width = math.max(width, probe:GetStringWidth() * 1.25 + 40 + (item.icon and 20 or 0) + (item.children and 14 or 0))
		end
		-- a dropdown is at least as wide as its button; a cursor menu's anchor is UIParent, not a button
		width = math.max(width, not opts.submenu and not opts.atCursor and anchor and anchor.GetWidth and anchor:GetWidth() or 0, 100)
	end
	f:SetWidth(width)
	f:ClearAllPoints()
	if opts.submenu then
		f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 3)
	elseif opts.atCursor then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	else
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	end
	if self == self.root then self.catcher:Show() end
	f:Show()
	self:Render()
end

function Level:Close()
	local root = self.root
	if root.frame then root.frame:Hide() end
	root.anchor = nil
end

function Level:IsOpenFor(anchor) return self.frame ~= nil and self.frame:IsShown() and self.anchor == anchor end

-- Test and automation helper: picks the visible item with this label. More labels follow a
-- path through submenus: FK.Popup:Pick("Move to", "Bank"). Labels match as seen (colour codes ignored).
function Level:Pick(label, ...)
	for i, item in ipairs(self.items or {}) do
		if item.label == label or item.label and FK.Chat.Strip(item.label) == label then
			self.offset = FK.Clamp(i - 1, 0, math.max(0, #self.items - (self.opts.maxRows or 12)))
			self:Render()
			for _, row in ipairs(self.rows) do
				if row:IsShown() and row.item == item then
					if select("#", ...) == 0 then return row:Click() end
					if not item.children then error("FK.Popup:Pick: " .. tostring(label) .. " has no submenu", 2) end
					self:OpenChild(row)
					return self.child:Pick(...)
				end
			end
		end
	end
	error("FK.Popup:Pick: no item labelled " .. tostring(label), 2)
end

---------------------------------------------------------------------------------------------
-- Dropdown, MultiDropdown
---------------------------------------------------------------------------------------------

local function dropdownParts(self, opts)
	self.top = self:Caption(opts.label)
	if not opts.width then self:SetWidth(160) end
	self.button = self:Clickable(self, function()
		if Popup:IsOpenFor(self.button) then return Popup:Close() end
		self:Open()
	end)
	self.button:SetPoint("TOPLEFT", 0, -self.top)
	self.button:SetPoint("RIGHT")
	self.arrow = Theme.Icon(self.button, "arrowDown", 12)
	self.arrow:SetPoint("RIGHT", -5, 0)
	self.text = self:Text("normal", nil, self.button)
	self.text:SetPoint("LEFT", 7, 0)
	self.text:SetPoint("RIGHT", self.arrow, "LEFT", -4, 0)
	self.text:SetJustifyH("LEFT")
	self.text:SetWordWrap(false)
end

local function dropdownStyle(self)
	local T = Theme.current
	self:SetHeight(self.top + T.metric.control)
	self.button:SetHeight(T.metric.control)
	-- keep the text and arrow inside the button art's bevel (wider in vanilla)
	local inset = T.metric.controlInset or 7
	self.text:SetPoint("LEFT", inset, 0)
	self.arrow:SetPoint("RIGHT", -(inset - 2), 0)
	Theme.PaintState(self.button, T.surface.button, Theme.State(self))
	self.arrow.colorRole = not self.enabled and "disabled" or nil
	self.arrow:Restyle()
	self:Refresh()
end

---@widget Dropdown  Pick one of several named options. For numbers use Slider. opts: label, items, value, placeholder, onChange(value). Methods: SetItems(items).
FK.Define("Dropdown", {
	fill = false,
	SetValue = function(self, v)
		self.value = v
		self:Refresh()
	end,
	GetValue = function(self) return self.value end,
	SetItems = function(self, items)
		self.opts.items = items
		self:Refresh()
	end,
	Open = function(self)
		Popup:Open(self.button, self.opts.items, {
			isChecked = function(item) return item.value == self.value end,
			onPick = function(item)
				if item.value == self.value then return end
				self.value = item.value
				self:Refresh()
				self:Fire(item.value)
			end,
		})
	end,
	Refresh = function(self)
		local label
		for _, item in ipairs(resolveItems(self.opts.items)) do
			if item.value == self.value and item.value ~= nil then label = item.label end
		end
		self.text:SetText(label or self.opts.placeholder or FK.L["Select..."])
		self.text.fkColor = not label and "dim" or nil
		Theme.Font(self.text, "normal", not self.enabled and "disabled" or self.text.fkColor)
	end,
	Restyle = dropdownStyle,
}, function(self, opts)
	dropdownParts(self, opts)
	self.value = opts.value
	warnIfNumeric("FK.Dropdown", resolveItems(opts.items))
end)

---@widget MultiDropdown  Pick any number of named options; the list stays open while ticking. opts: label, items, value = { [itemValue] = true }, placeholder, onChange(valueSet).
FK.Define("MultiDropdown", {
	fill = false,
	SetValue = function(self, set)
		self.value = FK.Copy(set or {})
		self:Refresh()
	end,
	GetValue = function(self) return FK.Copy(self.value) end,
	SetItems = function(self, items)
		self.opts.items = items
		self:Refresh()
	end,
	Open = function(self)
		Popup:Open(self.button, self.opts.items, {
			keepOpen = true,
			isChecked = function(item) return self.value[item.value] == true end,
			onPick = function(item)
				self.value[item.value] = not self.value[item.value] or nil
				self:Refresh()
				self:Fire(self:GetValue())
			end,
		})
	end,
	Refresh = function(self)
		local names = {}
		for _, item in ipairs(resolveItems(self.opts.items)) do
			if item.value ~= nil and self.value[item.value] then names[#names + 1] = item.label end
		end
		local text = table.concat(names, ", ")
		if #names == 0 then text = self.opts.placeholder or FK.L["None"] end
		if #names > 2 then text = FK.L["%d selected"]:format(#names) end
		self.text:SetText(text)
	end,
	Restyle = dropdownStyle,
}, function(self, opts)
	dropdownParts(self, opts)
	self.value = FK.Copy(opts.value or {})
end)

---------------------------------------------------------------------------------------------
-- Segmented, RadioGroup
---------------------------------------------------------------------------------------------

---@widget Segmented  Two to five named options as a row of buttons, all visible at once. opts: label, items, value, onChange(value).
FK.Define("Segmented", {
	SetValue = function(self, v)
		self.value = v
		self:Restyle()
	end,
	GetValue = function(self) return self.value end,
	Restyle = function(self)
		local T = Theme.current
		self:SetHeight(self.top + T.metric.control)
		local n = #self.segments
		local width = self:GetWidth() / math.max(n, 1)
		for i, seg in ipairs(self.segments) do
			seg:ClearAllPoints()
			seg:SetPoint("TOPLEFT", (i - 1) * width, -self.top)
			seg:SetSize(math.max(width - (i < n and 1 or 0), 1), T.metric.control)
			local state = not self.enabled and "normal" or seg.item.value == self.value and "selected" or seg.hover and "hover" or "normal"
			Theme.Paint(seg, T.surface.tab[state])
			Theme.Font(seg.text, "normal", not self.enabled and "disabled" or seg.item.value == self.value and "heading" or nil)
		end
	end,
}, function(self, opts)
	self.top = self:Caption(opts.label)
	self.value = opts.value
	self.segments = {}
	local items = resolveItems(opts.items)
	warnIfNumeric("FK.Segmented", items)
	for i, item in ipairs(items) do
		local seg = FK.Frame("Button", self)
		seg.item = item
		seg.text = seg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		seg.text:SetPoint("CENTER")
		seg.text:SetText(item.label)
		seg:SetScript("OnEnter", function() seg.hover = true self:Restyle() end)
		seg:SetScript("OnLeave", function() seg.hover = false self:Restyle() end)
		seg:SetScript("OnClick", function()
			if not self.enabled or self.value == item.value then return end
			FK.Sound("tab")
			self.value = item.value
			self:Restyle()
			self:Fire(item.value)
		end)
		self.segments[i] = seg
	end
	self:SetScript("OnSizeChanged", function() self:Restyle() end)
end)

---@widget RadioGroup  Named options listed vertically, one selected; use when each option needs room for a longer label. opts: label, items, value, onChange(value).
FK.Define("RadioGroup", {
	SetValue = function(self, v)
		self.value = v
		self:Restyle()
	end,
	GetValue = function(self) return self.value end,
	Restyle = function(self)
		local T = Theme.current
		local size, rowH = T.metric.radio, T.metric.row
		for i, radio in ipairs(self.radios) do
			radio:ClearAllPoints()
			radio:SetPoint("TOPLEFT", 0, -self.top - (i - 1) * rowH)
			radio:SetSize(size + 6 + radio.text:GetStringWidth(), rowH)
			radio.box:SetSize(size, size)
			Theme.PaintState(radio.box, T.surface.radio, not self.enabled and "disabled" or radio.hover and "hover" or "normal")
			local mark = T.surface.radioMark
			local inset = mark.inset or 0
			radio.mark:ClearAllPoints()
			radio.mark:SetPoint("TOPLEFT", inset, -inset)
			radio.mark:SetPoint("BOTTOMRIGHT", -inset, inset)
			Theme.Texture(radio.mark, mark, self.enabled and 1 or 0.4)
			radio.mark:SetShown(radio.item.value == self.value)
			Theme.Font(radio.text, "normal", not self.enabled and "disabled" or nil)
		end
		self:SetHeight(self.top + #self.radios * rowH)
	end,
}, function(self, opts)
	self.top = self:Caption(opts.label)
	self.value = opts.value
	self.radios = {}
	local items = resolveItems(opts.items)
	warnIfNumeric("FK.RadioGroup", items)
	for i, item in ipairs(items) do
		local radio = CreateFrame("Button", nil, self)
		radio.item = item
		radio.box = FK.Frame("Frame", radio)
		radio.box:SetPoint("LEFT")
		radio.mark = radio.box:CreateTexture(nil, "OVERLAY")
		radio.text = radio:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		radio.text:SetPoint("LEFT", radio.box, "RIGHT", 6, 0)
		radio.text:SetText(item.label)
		radio:SetScript("OnEnter", function() radio.hover = true self:Restyle() end)
		radio:SetScript("OnLeave", function() radio.hover = false self:Restyle() end)
		radio:SetScript("OnClick", function()
			if not self.enabled or self.value == item.value then return end
			FK.Sound("check")
			self.value = item.value
			self:Restyle()
			self:Fire(item.value)
		end)
		self.radios[i] = radio
	end
end)

---------------------------------------------------------------------------------------------
-- ColorSwatch, KeybindButton
---------------------------------------------------------------------------------------------

---@widget ColorSwatch  Colour setting: a swatch that opens the game's colour picker. opts: label, value = { r, g, b [, a] }, hasAlpha, onChange({ r, g, b [, a] }). Cancelling the picker restores the previous colour.
FK.Define("ColorSwatch", {
	fill = false,
	SetValue = function(self, c)
		self.value = { c[1], c[2], c[3], self.opts.hasAlpha and (c[4] or 1) or nil }
		self.color:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	end,
	GetValue = function(self) return { unpack(self.value) } end,
	Pick = function(self)
		local old = self:GetValue()
		local function apply(c)
			self:SetValue(c)
			self:Fire(self:GetValue())
		end
		local function read()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			apply({ r, g, b, self.opts.hasAlpha and ColorPickerFrame:GetColorAlpha() or nil })
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = old[1], g = old[2], b = old[3], opacity = old[4], hasOpacity = self.opts.hasAlpha and true or false,
			swatchFunc = read, opacityFunc = read,
			cancelFunc = function() apply(old) end,
		})
	end,
	Restyle = function(self)
		local T = Theme.current
		local size = T.metric.check
		self.button:SetSize(size, size)
		self.border:SetColorTexture(Theme.Color(self.hover and self.enabled and "accent" or "dim"))
		self.color:SetAlpha(self.enabled and 1 or 0.4)
		self:SetHeight(math.max(size, T.metric.row))
		if not self.opts.width then self:SetWidth(size + 6 + self.text:GetStringWidth()) end
	end,
}, function(self, opts)
	self.button = self:Clickable(self, function() self:Pick() end)
	self.button:SetPoint("LEFT")
	self.border = self.button:CreateTexture(nil, "BACKGROUND")
	self.border:SetAllPoints()
	self.color = self.button:CreateTexture(nil, "ARTWORK")
	self.color:SetPoint("TOPLEFT", 1, -1)
	self.color:SetPoint("BOTTOMRIGHT", -1, 1)
	self.text = self:Text("normal")
	self.text:SetPoint("LEFT", self.button, "RIGHT", 6, 0)
	self.text:SetText(opts.label or "")
	self:SetValue(opts.value or { 1, 1, 1, 1 })
end)

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }

---@widget KeybindButton  Captures a key combination ("CTRL-SHIFT-K"). Click, then press the keys; Escape cancels, right-click clears. opts: label, value, onChange(keyOrNil). The widget only records the key: bind it with FK.Keybind (Features).
FK.Define("KeybindButton", {
	fill = false,
	SetValue = function(self, key)
		self.value = key
		self:Refresh()
	end,
	GetValue = function(self) return self.value end,
	Refresh = function(self)
		self.text:SetText(self.listening and FK.L["Press a key..."] or self.value or FK.L["Not bound"])
	end,
	Listen = function(self, on)
		self.listening = on
		self.button:EnableKeyboard(on)
		self:Restyle()
	end,
	Restyle = function(self)
		local T = Theme.current
		self:SetHeight(self.top + T.metric.control)
		self.button:SetHeight(T.metric.control)
		Theme.PaintState(self.button, T.surface.button, self.listening and "pressed" or Theme.State(self))
		self:Refresh()
	end,
}, function(self, opts)
	self.top = self:Caption(opts.label)
	if not opts.width then self:SetWidth(140) end
	self.value = opts.value
	self.button = self:Clickable(self, function(mouseButton)
		if mouseButton == "RightButton" then
			self:Listen(false)
			if self.value ~= nil then
				self.value = nil
				self:Refresh()
				self:Fire(nil)
			end
		else
			self:Listen(not self.listening)
		end
	end)
	self.button:RegisterForClicks("AnyUp")
	self.button:SetPoint("TOPLEFT", 0, -self.top)
	self.button:SetPoint("RIGHT")
	self.text = self:Text("button", nil, self.button)
	self.text:SetPoint("CENTER")
	self.button:SetScript("OnKeyDown", function(_, key)
		if MODIFIER_KEYS[key] then return end
		self:Listen(false)
		if key == "ESCAPE" then return end
		local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
		self.value = combo
		self:Refresh()
		self:Fire(combo)
	end)
	self.button:SetScript("OnHide", function() self:Listen(false) end)
end)
