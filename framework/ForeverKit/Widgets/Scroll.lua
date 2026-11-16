local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Scroll bar used by the widgets below: bar:Set(total, visible, offset), calls onScroll(offset).
local function scrollBar(owner, onScroll)
	local bar = FK.Frame("Frame", owner)
	bar.thumb = FK.Frame("Button", bar)
	bar.total, bar.visible, bar.offset = 0, 1, 0
	function bar:Set(total, visible, offset)
		self.total, self.visible, self.offset = total, visible, offset
		local needed = total > visible
		self:SetShown(needed)
		if not needed then return end
		local h = self:GetHeight()
		local th = math.max(18, h * visible / total)
		self.thumb:SetHeight(th)
		self.thumb:ClearAllPoints()
		self.thumb:SetPoint("TOPLEFT", 0, -(h - th) * offset / (total - visible))
		self.thumb:SetPoint("RIGHT")
	end
	function bar:Restyle()
		local T = Theme.current
		self:SetWidth(T.metric.scroll)
		Theme.Paint(self, T.surface.scrollTrack)
		Theme.Paint(self.thumb, T.surface.scrollThumb[self.thumb.hover and "hover" or "normal"])
	end
	bar.thumb:SetScript("OnEnter", function(t) t.hover = true bar:Restyle() end)
	bar.thumb:SetScript("OnLeave", function(t) t.hover = false bar:Restyle() end)
	bar.thumb:SetScript("OnMouseDown", function(t)
		local scale = bar:GetEffectiveScale()
		local _, startY = GetCursorPosition()
		local startOffset = bar.offset
		t:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			local travel = bar:GetHeight() - t:GetHeight()
			if travel <= 0 then return end
			local range = bar.total - bar.visible
			onScroll(FK.Clamp(startOffset + (startY - y) / scale / travel * range, 0, range))
		end)
	end)
	bar.thumb:SetScript("OnMouseUp", function(t) t:SetScript("OnUpdate", nil) end)
	bar:Hide()
	return bar
end

---@widget ScrollArea  Scrolling container for content taller than its space (long settings pages). Children stack vertically: area:Add(widget). opts: gap, padding. Needs a height (opts.height or two anchors).
FK.Define("ScrollArea", {
	Add = function(self, widget) return self.content:Add(widget) end,
	Clear = function(self) self.content:Clear() end,
	Batch = function(self, fn) self.content:Batch(function() fn(self) end) end,
	ScrollTo = function(self, offset)
		local range = math.max(0, self.content:GetHeight() - self.scroll:GetHeight())
		self.offset = FK.Clamp(offset, 0, range)
		self.scroll:SetVerticalScroll(self.offset)
		self.bar:Set(self.content:GetHeight(), self.scroll:GetHeight(), self.offset)
	end,
	-- Called by the content stack when its height changes.
	Layout = function(self)
		if self.laying then return end
		self.laying = true
		local barWidth = Theme.current.metric.scroll
		-- two passes: the scroll bar takes width, which can change the content's height
		for _ = 1, 2 do
			local needed = self.content:GetHeight() > self.scroll:GetHeight() + 0.5
			self.content:SetWidth(math.max(self:GetWidth() - (needed and barWidth + 4 or 0), 1))
			self.content:Layout()
		end
		self.laying = nil
		self:ScrollTo(self.offset)
	end,
	Restyle = function(self)
		self.bar:Restyle()
		self:Layout()
	end,
}, function(self, opts)
	self.offset = 0
	self.scroll = CreateFrame("ScrollFrame", nil, self)
	self.scroll:SetAllPoints()
	self.bar = scrollBar(self, function(offset) self:ScrollTo(offset) end)
	self.bar:SetPoint("TOPRIGHT")
	self.bar:SetPoint("BOTTOMRIGHT")
	self.content = FK.Stack(self.scroll, { gap = opts.gap, padding = opts.padding })
	self.content:SetWidth(1)
	self.scroll:SetScrollChild(self.content)
	self.content.fkContainer = self
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseWheel", function(_, delta) self:ScrollTo(self.offset - delta * 40) end)
	self:SetScript("OnSizeChanged", function() self:Layout() end)
end)

---@widget ScrollList  Virtualised list: only the visible rows exist, so 10 000 items cost the same as 20. opts: rowHeight, items, create(row) builds a row's parts once, update(row, item, index) fills them (default: item.icon + item.label or the item as text), onClick(item, mouseButton, row), onEnter(item, row) for tooltips, selectable, striped, emptyText. Methods: SetItems, Refresh, ScrollToIndex, GetSelected, SetSelected.
FK.Define("ScrollList", {
	SetItems = function(self, items)
		self.items = items or {}
		self.offset = FK.Clamp(self.offset, 0, math.max(0, #self.items - self:VisibleCount()))
		self:Refresh()
	end,
	GetItems = function(self) return self.items end,
	GetSelected = function(self) return self.selected end,
	SetSelected = function(self, item)
		self.selected = item
		self:Refresh()
	end,
	VisibleCount = function(self) return math.max(1, math.floor(self:GetHeight() / self.rowHeight)) end,
	ScrollToIndex = function(self, index)
		self.offset = FK.Clamp(index - 1, 0, math.max(0, #self.items - self:VisibleCount()))
		self:Refresh()
	end,
	Scroll = function(self, delta) self:ScrollToIndex(self.offset + 1 + delta) end,
	Refresh = function(self)
		local T = Theme.current
		local visible, items = self:VisibleCount(), self.items
		local scrolls = #items > visible
		self.bar:Set(#items, visible, self.offset)
		for i = 1, math.max(visible, #self.rows) do
			local row = self.rows[i]
			local item = i <= visible and items[self.offset + i]
			if item ~= nil and item ~= false then
				if not row then
					row = self:CreateRow(i)
					self.rows[i] = row
				end
				row.item, row.index = item, self.offset + i
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowHeight)
				row:SetPoint("RIGHT", scrolls and -(T.metric.scroll + 2) or 0, 0)
				row:SetHeight(self.rowHeight)
				local state = item == self.selected and "selected" or row.hover and "hover" or (self.opts.striped and row.index % 2 == 0 and "alt") or nil
				row.bg:SetShown(state ~= nil)
				if state then Theme.Texture(row.bg, T.surface.row[state]) end
				self.update(row, item, row.index)
				row:Show()
			elseif row then
				row:Hide()
			end
		end
		self.empty:SetShown(#items == 0)
	end,
	CreateRow = function(self)
		local row = CreateFrame("Button", nil, self)
		row:RegisterForClicks("AnyUp")
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		row:SetScript("OnEnter", function()
			row.hover = true
			self:Refresh()
			if self.opts.onEnter then self.opts.onEnter(row.item, row) end
		end)
		row:SetScript("OnLeave", function()
			row.hover = false
			self:Refresh()
			GameTooltip:Hide()
		end)
		row:SetScript("OnClick", function(_, button)
			if self.opts.selectable and button == "LeftButton" then self.selected = row.item end
			if self.opts.onClick then self.opts.onClick(row.item, button, row) end
			self:Refresh()
		end)
		self.create(row)
		return row
	end,
	Restyle = function(self)
		self.rowHeight = self.opts.rowHeight or Theme.current.metric.row
		self.bar:Restyle()
		self:Refresh()
	end,
}, function(self, opts)
	self.items, self.rows, self.offset = opts.items or {}, {}, 0
	self.rowHeight = opts.rowHeight or Theme.current.metric.row
	self.create = opts.create or function(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("LEFT", 2, 0)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.text:SetPoint("RIGHT", -4, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
	end
	self.update = opts.update or function(row, item)
		local icon = type(item) == "table" and item.icon
		local size = self.rowHeight - 4
		row.icon:SetShown(icon ~= nil)
		row.icon:SetSize(size, size)
		row.icon:SetTexture(icon)
		row.text:SetPoint("LEFT", icon and size + 6 or 4, 0)
		Theme.Font(row.text, "normal")
		row.text:SetText(type(item) == "table" and (item.label or item.name) or tostring(item))
	end
	self.bar = scrollBar(self, function(offset) self:ScrollToIndex(math.floor(offset + 0.5) + 1) end)
	self.bar:SetPoint("TOPRIGHT")
	self.bar:SetPoint("BOTTOMRIGHT")
	self.empty = self:Text("normal", "dim")
	self.empty:SetPoint("CENTER")
	self.empty:SetText(opts.emptyText or "")
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-delta * 3) end)
	self:SetScript("OnSizeChanged", function() self:Refresh() end)
	if not opts.height then self:SetHeight(self.rowHeight * 8) end
end)

---@widget Table  Sortable multi-column list (auction results, rosters, loot). opts: columns = { { key, label, width or flex = 1, align = "LEFT"|"RIGHT"|"CENTER", format = function(value, item) -> text, sort = function(a, b) or false, color = function(item) -> r, g, b } }, items, sortKey, sortDescending, resizableColumns (default true: drag a header's right edge), onClick(item, mouseButton), onEnter(item, row), selectable, rowHeight. Methods: SetItems, Sort(key, descending), GetSelected.
FK.Define("Table", {
	SetItems = function(self, items)
		self.items = items or {}
		self:Sort(self.sortKey, self.descending)
	end,
	GetSelected = function(self) return self.list:GetSelected() end,
	Sort = function(self, key, descending)
		self.sortKey, self.descending = key, descending and true or false
		local sorted = { unpack(self.items) }
		local col
		for _, c in ipairs(self.opts.columns) do if c.key == key then col = c end end
		if col and col.sort ~= false then
			local cmp = col.sort or function(a, b)
				local x, y = a[key], b[key]
				if x == y then return false end
				if x == nil then return false end
				if y == nil then return true end
				if type(x) ~= type(y) then x, y = tostring(x), tostring(y) end
				return x < y
			end
			-- decorate with the original position: equal rows keep their order (table.sort is unstable)
			local index = {}
			for i, item in ipairs(sorted) do index[item] = i end
			table.sort(sorted, function(a, b)
				local lt, gt = cmp(a, b), cmp(b, a)
				if lt == gt then return index[a] < index[b] end
				if descending then return gt end
				return lt
			end)
		end
		self.list:SetItems(sorted)
		self:Restyle()
	end,
	-- Column widths: fixed ones as given, flex ones share what is left.
	Widths = function(self)
		local cols, total, flex = self.opts.columns, self:GetWidth() - Theme.current.metric.scroll - 2, 0
		local fixed = 0
		for _, c in ipairs(cols) do
			if c.width then fixed = fixed + c.width else flex = flex + (c.flex or 1) end
		end
		local widths = {}
		for i, c in ipairs(cols) do
			widths[i] = c.width or math.max(20, (total - fixed) * (c.flex or 1) / math.max(flex, 1))
		end
		return widths
	end,
	Restyle = function(self)
		local T = Theme.current
		local widths, x = self:Widths(), 0
		self.header:SetHeight(T.metric.row)
		for i, h in ipairs(self.headers) do
			local c = self.opts.columns[i]
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", x, 0)
			h:SetSize(widths[i], T.metric.row)
			Theme.Paint(h, T.surface.tab[h.hover and "hover" or "normal"])
			Theme.Font(h.text, "small", self.sortKey == c.key and "accent" or "dim")
			h.text:SetText((c.label or "") .. (self.sortKey == c.key and (self.descending and " v" or " ^") or ""))
			x = x + widths[i]
		end
		self.list:Refresh()
	end,
}, function(self, opts)
	if type(opts.columns) ~= "table" or #opts.columns == 0 then error("FK.Table: opts.columns is required", 3) end
	self.items, self.headers = {}, {}
	self.sortKey, self.descending = opts.sortKey, opts.sortDescending and true or false
	self.header = CreateFrame("Frame", nil, self)
	self.header:SetPoint("TOPLEFT")
	self.header:SetPoint("TOPRIGHT")
	for i, c in ipairs(opts.columns) do
		local h = FK.Frame("Button", self.header)
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		h.text:SetPoint("LEFT", 4, 0)
		h.text:SetPoint("RIGHT", -4, 0)
		h.text:SetJustifyH(c.align or "LEFT")
		h.text:SetWordWrap(false)
		h:SetScript("OnEnter", function() h.hover = true self:Restyle() end)
		h:SetScript("OnLeave", function() h.hover = false self:Restyle() end)
		h:SetScript("OnClick", function()
			if c.sort == false then return end
			FK.Sound("click")
			self:Sort(c.key, self.sortKey == c.key and not self.descending)
		end)
		if opts.resizableColumns ~= false and i < #opts.columns then
			local grip = CreateFrame("Button", nil, h)
			grip:SetPoint("TOPRIGHT", 3, 0)
			grip:SetPoint("BOTTOMRIGHT", 3, 0)
			grip:SetWidth(6)
			grip:SetFrameLevel(h:GetFrameLevel() + 3)
			grip:SetScript("OnEnter", function() SetCursor("UI_RESIZE_CURSOR") end)
			grip:SetScript("OnLeave", function() ResetCursor() end)
			grip:SetScript("OnMouseDown", function()
				local scale = self:GetEffectiveScale()
				local startX, startWidth = GetCursorPosition() / scale, h:GetWidth()
				grip:SetScript("OnUpdate", function()
					c.width = FK.Clamp(startWidth + GetCursorPosition() / scale - startX, 24, 600)
					self:Restyle()
				end)
			end)
			grip:SetScript("OnMouseUp", function() grip:SetScript("OnUpdate", nil) end)
			h.grip = grip
		end
		self.headers[i] = h
	end
	self.list = FK.ScrollList(self, {
		rowHeight = opts.rowHeight, selectable = opts.selectable, striped = opts.striped ~= false,
		emptyText = opts.emptyText, onClick = opts.onClick, onEnter = opts.onEnter,
		create = function(row)
			row.cells = {}
			for i, c in ipairs(opts.columns) do
				local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				cell:SetJustifyH(c.align or "LEFT")
				cell:SetWordWrap(false)
				row.cells[i] = cell
			end
		end,
		update = function(row, item)
			local widths, x = self:Widths(), 0
			for i, c in ipairs(opts.columns) do
				local cell, value = row.cells[i], item[c.key]
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", x + 4, 0)
				cell:SetWidth(widths[i] - 8)
				Theme.Font(cell, "normal")
				if c.color then
					local r, g, b = c.color(item)
					if r then cell:SetTextColor(r, g, b) end
				end
				if c.format then value = c.format(value, item) end
				cell:SetText(value == nil and "" or tostring(value))
				x = x + widths[i]
			end
		end,
	})
	self.list:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -1)
	self.list:SetPoint("BOTTOMRIGHT")
	if not opts.height then self:SetHeight(220) end
	self:SetScript("OnSizeChanged", function() self:Restyle() end)
	if opts.items then self:SetItems(opts.items) end
end)

---@widget Tree  Collapsible hierarchy (journal categories, zone > quest lists). opts: nodes = { { label, icon, children = {...}, expanded, value, color } }, onSelect(node), onEnter(node, row), indent (default 14). Clicking a branch folds it; leaves are selected. Methods: SetNodes, ExpandAll, CollapseAll, GetSelected.
FK.Define("Tree", {
	SetNodes = function(self, nodes)
		self.nodes = nodes or {}
		self:Flatten()
	end,
	GetSelected = function(self) return self.list:GetSelected() end,
	ExpandAll = function(self) self:SetExpanded(self.nodes, true) self:Flatten() end,
	CollapseAll = function(self) self:SetExpanded(self.nodes, false) self:Flatten() end,
	SetExpanded = function(self, nodes, expanded)
		for _, n in ipairs(nodes) do
			if n.children then
				n.expanded = expanded
				self:SetExpanded(n.children, expanded)
			end
		end
	end,
	Flatten = function(self)
		local flat = {}
		local function walk(nodes, depth)
			for _, n in ipairs(nodes) do
				n.depth = depth
				flat[#flat + 1] = n
				if n.children and n.expanded then walk(n.children, depth + 1) end
			end
		end
		walk(self.nodes, 0)
		self.list:SetItems(flat)
	end,
	Restyle = function(self) self.list:Refresh() end,
}, function(self, opts)
	local indent = opts.indent or 14
	self.list = FK.ScrollList(self, {
		selectable = false, onEnter = opts.onEnter,
		create = function(row)
			row.arrow = Theme.Icon(row, "arrowRight", 10)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
		end,
		update = function(row, node)
			local x = 4 + node.depth * indent
			row.arrow:SetShown(node.children ~= nil)
			row.arrow:ClearAllPoints()
			row.arrow:SetPoint("LEFT", x, 0)
			row.arrow:SetIcon(node.expanded and "arrowDown" or "arrowRight")
			x = x + 14
			row.icon:SetShown(node.icon ~= nil)
			if node.icon then
				row.icon:SetTexture(node.icon)
				row.icon:SetSize(16, 16)
				row.icon:ClearAllPoints()
				row.icon:SetPoint("LEFT", x, 0)
				x = x + 20
			end
			row.text:SetPoint("LEFT", x, 0)
			Theme.Font(row.text, "normal", node.children and "heading" or nil)
			if node.color then row.text:SetTextColor(node.color[1], node.color[2], node.color[3]) end
			row.text:SetText(node.label)
		end,
		onClick = function(node)
			if node.children then
				node.expanded = not node.expanded
				self:Flatten()
			else
				self.list.selected = node
				if opts.onSelect then opts.onSelect(node) end
			end
		end,
	})
	self.list:SetAllPoints()
	if not opts.height then self:SetHeight(220) end
	self:SetNodes(opts.nodes)
end)

---@widget TextArea  Multi-line text input with scrolling (notes, import/export strings). opts: label, value, readOnly (select-and-copy only), onChange(text) when focus is lost.
FK.Define("TextArea", {
	SetValue = function(self, text)
		self.value = tostring(text or "")
		self.box:SetText(self.value)
	end,
	GetValue = function(self) return self.box:GetText() end,
	Focus = function(self) self.box:SetFocus() self.box:HighlightText() end,
	Restyle = function(self)
		Theme.Paint(self.holder, Theme.current.surface.input[self.focused and "focus" or "normal"])
		self.box:SetWidth(math.max(self.scroll:GetWidth(), 1))
	end,
}, function(self, opts)
	self.top = self:Caption(opts.label)
	self.holder = FK.Frame("Frame", self)
	self.holder:SetPoint("TOPLEFT", 0, -self.top)
	self.holder:SetPoint("BOTTOMRIGHT")
	self.scroll = CreateFrame("ScrollFrame", nil, self.holder)
	self.scroll:SetPoint("TOPLEFT", 6, -4)
	self.scroll:SetPoint("BOTTOMRIGHT", -6, 4)
	local box = CreateFrame("EditBox", nil, self.scroll)
	self.box = box
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetSize(100, 400)
	box.fkRole = "normal"
	self.fkTexts = self.fkTexts or {}
	self.fkTexts[#self.fkTexts + 1] = box
	self.scroll:SetScrollChild(box)
	self.value = tostring(opts.value or "")
	box:SetText(self.value)
	box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function() self.focused = true self:Restyle() end)
	box:SetScript("OnEditFocusLost", function()
		self.focused = false
		self:Restyle()
		if box:GetText() ~= self.value then
			self.value = box:GetText()
			self:Fire(self.value)
		end
	end)
	box:SetScript("OnTextChanged", function(b, userInput)
		if opts.readOnly and userInput then b:SetText(self.value) b:HighlightText() end
	end)
	self.scroll:EnableMouseWheel(true)
	self.scroll:SetScript("OnMouseWheel", function(s, delta)
		s:SetVerticalScroll(FK.Clamp(s:GetVerticalScroll() - delta * 30, 0, s:GetVerticalScrollRange()))
	end)
	self.holder:EnableMouse(true)
	self.holder:SetScript("OnMouseDown", function() box:SetFocus() end)
	self:SetScript("OnSizeChanged", function() self:Restyle() end)
	if not opts.height then self:SetHeight(self.top + 100) end
end)

FK.ScrollBar = scrollBar
