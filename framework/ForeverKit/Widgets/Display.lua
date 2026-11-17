local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

---@widget TimerBar  Bar that drains over a duration (cooldowns you started yourself, auction timers, buff reminders out of combat). opts: label, icon, duration, color (theme colour or {r,g,b}), onFinish(bar). Methods: Start(duration, label), Stop().
FK.Define("TimerBar", {
	Start = function(self, duration, label)
		self.duration, self.ends = duration, GetTime() + duration
		if label then self.label:SetText(label) end
		self.bar:SetMinMaxValues(0, duration)
		self:Show()
		self:SetScript("OnUpdate", function()
			local left = self.ends - GetTime()
			if left <= 0 then
				self:Stop()
				if self.opts.onFinish then self.opts.onFinish(self) end
				return
			end
			self.bar:SetValue(left)
			self.time:SetText(left >= 60 and FK.Duration(left) or ("%.1f"):format(left))
		end)
	end,
	Stop = function(self)
		self:SetScript("OnUpdate", nil)
		self.bar:SetValue(0)
		self.time:SetText("")
	end,
	Restyle = function(self)
		local T = Theme.current
		local h = self.opts.height or T.metric.row
		self:SetHeight(h)
		self.icon:SetSize(h, h)
		Theme.Paint(self.holder, T.surface.barBackground)
		self.bar:SetStatusBarTexture(T.surface.bar.texture)
		local c = self.opts.color or "accent"
		if type(c) == "table" then self.bar:SetStatusBarColor(c[1], c[2], c[3]) else self.bar:SetStatusBarColor(Theme.Color(c)) end
	end,
}, function(self, opts)
	self.icon = self:CreateTexture(nil, "ARTWORK")
	self.icon:SetPoint("LEFT")
	self.icon:SetTexture(opts.icon)
	self.icon:SetShown(opts.icon ~= nil)
	self.holder = FK.Frame("Frame", self)
	self.holder:SetPoint("TOPLEFT", opts.icon and (opts.height or Theme.current.metric.row) + 2 or 0, 0)
	self.holder:SetPoint("BOTTOMRIGHT")
	self.bar = CreateFrame("StatusBar", nil, self.holder)
	self.bar:SetAllPoints()
	self.bar:SetMinMaxValues(0, 1)
	self.bar:SetValue(0)
	self.label = self:Text("small", nil, self.bar)
	self.label:SetPoint("LEFT", 4, 0)
	self.label:SetText(opts.label or "")
	self.time = self:Text("small", nil, self.bar)
	self.time:SetPoint("RIGHT", -4, 0)
	if opts.duration then self:Start(opts.duration) end
end)

---@widget BarList  Ranked bars, longest first (meters, top lists, contribution). opts: rowHeight, max rows shown = what fits. SetItems({ { label, value, text (right side; default the value), color = {r,g,b}, icon } }): sorted by value, bar length relative to the largest.
FK.Define("BarList", {
	SetItems = function(self, items)
		local sorted = { unpack(items or {}) }
		table.sort(sorted, function(a, b) return a.value > b.value end)
		self.items = sorted
		self:Refresh()
	end,
	Refresh = function(self)
		local T = Theme.current
		local h = self.opts.rowHeight or T.metric.row
		local top = self.items[1] and self.items[1].value or 0
		local fits = math.max(1, math.floor((self:GetHeight() + 1) / (h + 1)))
		for i = 1, math.max(#self.rows, math.min(#self.items, fits)) do
			local item = i <= fits and self.items[i]
			local row = self.rows[i]
			if item then
				if not row then
					row = FK.Frame("Frame", self)
					row.bar = CreateFrame("StatusBar", nil, row)
					row.bar:SetAllPoints()
					row.icon = row.bar:CreateTexture(nil, "OVERLAY")
					row.icon:SetPoint("LEFT")
					row.label = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					row.value = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					row.value:SetPoint("RIGHT", -4, 0)
					self.rows[i] = row
				end
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -(i - 1) * (h + 1))
				row:SetPoint("RIGHT")
				row:SetHeight(h)
				Theme.Paint(row, T.surface.barBackground)
				row.bar:SetStatusBarTexture(T.surface.bar.texture)
				local c = item.color or T.color.accent
				row.bar:SetStatusBarColor(c[1], c[2], c[3], 0.85)
				row.bar:SetMinMaxValues(0, top > 0 and top or 1)
				row.bar:SetValue(item.value)
				row.icon:SetShown(item.icon ~= nil)
				row.icon:SetSize(h, h)
				row.icon:SetTexture(item.icon)
				row.label:SetPoint("LEFT", item.icon and h + 4 or 4, 0)
				Theme.Font(row.label, "small")
				Theme.Font(row.value, "small")
				row.label:SetText(("%d. %s"):format(i, item.label))
				row.value:SetText(item.text or FK.Number(item.value, true))
				row:Show()
			elseif row then
				row:Hide()
			end
		end
	end,
	Restyle = function(self) self:Refresh() end,
}, function(self, opts)
	self.items, self.rows = {}, {}
	if not opts.height then self:SetHeight(120) end
	self:SetScript("OnSizeChanged", function() self:Refresh() end)
	if opts.items then self:SetItems(opts.items) end
end)

---@widget IconGrid  Wrapping grid of icon buttons with count and quality border (bags, loot, collections). opts: size (default 36), gap. SetItems({ { icon, count, quality, itemID, tooltip, dim } }); onClick(item, mouseButton), onEnter(item, button) (default: the item's game tooltip when itemID is set, else item.tooltip).
FK.Define("IconGrid", {
	SetItems = function(self, items)
		self.items = items or {}
		self:Layout()
	end,
	Layout = function(self)
		local size, gap = self.opts.size or 36, self.opts.gap or 4
		local width = self:GetWidth()
		if width <= 0 then return end
		local perRow = math.max(1, math.floor((width + gap) / (size + gap)))
		for i = 1, math.max(#self.items, #self.buttons) do
			local item, b = self.items[i], self.buttons[i]
			if item then
				if not b then
					b = FK.Frame("Button", self)
					b:RegisterForClicks("AnyUp")
					b.icon = b:CreateTexture(nil, "ARTWORK")
					b.icon:SetPoint("TOPLEFT", 1, -1)
					b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
					b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
					b.count:SetPoint("BOTTOMRIGHT", -2, 2)
					b.hl = b:CreateTexture(nil, "HIGHLIGHT")
					b.hl:SetAllPoints()
					b.hl:SetColorTexture(1, 1, 1, 0.2)
					b:SetScript("OnClick", function(_, button) if self.opts.onClick then self.opts.onClick(b.item, button, b) end end)
					b:SetScript("OnEnter", function()
						if self.opts.onEnter then return self.opts.onEnter(b.item, b) end
						if b.item.itemID then
							GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
							GameTooltip:SetItemByID(b.item.itemID)
							GameTooltip:Show()
						elseif b.item.tooltip then
							GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
							GameTooltip:SetText(b.item.tooltip, nil, nil, nil, nil, true)
							GameTooltip:Show()
						end
					end)
					b:SetScript("OnLeave", function() GameTooltip:Hide() end)
					self.buttons[i] = b
				end
				b.item = item
				b:SetSize(size, size)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", ((i - 1) % perRow) * (size + gap), -math.floor((i - 1) / perRow) * (size + gap))
				local q = item.quality and ITEM_QUALITY_COLORS[item.quality]
				Theme.Paint(b, { bg = { 0, 0, 0, 0.6 }, border = q and item.quality > 1 and { q.r, q.g, q.b, 1 } or { 0, 0, 0, 1 } })
				b.icon:SetTexture(item.icon)
				b.icon:SetDesaturated(item.dim and true or false)
				b.icon:SetAlpha(item.dim and 0.5 or 1)
				b.count:SetText(item.count and item.count > 1 and item.count or "")
				b:Show()
			elseif b then
				b:Hide()
			end
		end
		self:SetHeight(math.max(1, math.ceil(#self.items / perRow) * (size + gap) - gap))
		self:Changed()
	end,
	Fit = function(self) self:Layout() end,
}, function(self, opts)
	self.items, self.buttons = {}, {}
	self:SetHeight(1)
	self:SetScript("OnSizeChanged", function(_, w)
		if w ~= self.lastWidth then
			self.lastWidth = w
			self:Layout()
		end
	end)
	if opts.items then self:SetItems(opts.items) end
end)

---@widget Tracker  Small always-visible frame listing a few lines of state (goals, timers, counts), the companion of a main window. opts: title, width (default 220), saved = { db, "profile.tracker" } (position), locked, background (default true), onClick(line, mouseButton). SetLines({ { text, value (right-aligned), color = theme colour or {r,g,b}, progress = 0..1, icon } }). Drag it by the title when unlocked; SetLocked(bool) hides the title bar's drag behaviour and makes the frame click-through.
FK.Define("Tracker", {
	SetLocked = function(self, locked)
		self.locked = locked and true or false
		self.head:EnableMouse(not self.locked)
	end,
	SetLines = function(self, lines)
		self.lines = lines or {}
		self:Refresh()
	end,
	ResetPosition = function(self)
		self:ClearAllPoints()
		self:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
		self:Store()
	end,
	Store = function(self)
		local saved = self.opts.saved
		if not saved then return end
		local point, _, relPoint, x, y = self:GetPoint(1)
		saved[1]:Set(saved[2], { point = point, relPoint = relPoint, x = x, y = y })
	end,
	Restore = function(self)
		local saved = self.opts.saved
		local s = saved and saved[1]:Get(saved[2])
		if type(s) ~= "table" or not s.point then return end
		self:ClearAllPoints()
		self:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
	end,
	Refresh = function(self)
		local T = Theme.current
		local rowH, y = 16, self.opts.title and 20 or 4
		for i = 1, math.max(#self.lines, #self.rows) do
			local line, row = self.lines[i], self.rows[i]
			if line then
				if not row then
					row = CreateFrame("Button", nil, self)
					row:RegisterForClicks("AnyUp")
					row.bar = row:CreateTexture(nil, "BACKGROUND")
					row.bar:SetPoint("TOPLEFT")
					row.bar:SetPoint("BOTTOMLEFT")
					row.icon = row:CreateTexture(nil, "ARTWORK")
					row.icon:SetSize(rowH - 2, rowH - 2)
					row.icon:SetPoint("LEFT", 2, 0)
					row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					row.value:SetPoint("RIGHT", -4, 0)
					row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					row.text:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
					row.text:SetJustifyH("LEFT")
					row.text:SetWordWrap(false)
					row:SetScript("OnClick", function(_, button) if self.opts.onClick then self.opts.onClick(row.line, button) end end)
					self.rows[i] = row
				end
				row.line = line
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 4, -y)
				row:SetPoint("RIGHT", -4, 0)
				row:SetHeight(rowH)
				row:EnableMouse(self.opts.onClick ~= nil)
				row.icon:SetShown(line.icon ~= nil)
				row.icon:SetTexture(line.icon)
				row.text:SetPoint("LEFT", line.icon and rowH + 2 or 4, 0)
				Theme.Font(row.text, "small", type(line.color) == "string" and line.color or nil)
				Theme.Font(row.value, "small", type(line.color) == "string" and line.color or nil)
				if type(line.color) == "table" then
					row.text:SetTextColor(line.color[1], line.color[2], line.color[3])
					row.value:SetTextColor(line.color[1], line.color[2], line.color[3])
				end
				row.text:SetText(line.text)
				row.value:SetText(line.value or "")
				row.bar:SetShown(line.progress ~= nil)
				if line.progress then
					local r, g, b = Theme.Color("accent")
					row.bar:SetColorTexture(r, g, b, 0.3)
					row.bar:SetWidth(math.max(1, (self:GetWidth() - 8) * FK.Clamp(line.progress, 0, 1)))
				end
				row:Show()
				y = y + rowH + 1
			elseif row then
				row:Hide()
			end
		end
		self:SetHeight(y + 4)
	end,
	Restyle = function(self)
		local T = Theme.current
		Theme.Paint(self, self.opts.background ~= false and T.surface.menu or nil, Theme.opacity)
		self:Refresh()
	end,
}, function(self, opts)
	self.lines, self.rows = {}, {}
	self:SetParent(UIParent)
	self:SetWidth(opts.width or 220)
	self:SetClampedToScreen(true)
	self:SetMovable(true)
	if self:GetNumPoints() == 0 then self:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0) end
	self.head = CreateFrame("Frame", nil, self)
	self.head:SetPoint("TOPLEFT")
	self.head:SetPoint("TOPRIGHT")
	self.head:SetHeight(20)
	self.head:EnableMouse(true)
	self.head:RegisterForDrag("LeftButton")
	self.head:SetScript("OnDragStart", function() if not self.locked then self:StartMoving() end end)
	self.head:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		self:Store()
	end)
	if opts.title then
		self.title = self:Text("heading", nil, self.head)
		self.title:SetPoint("LEFT", 6, 0)
		self.title:SetText(opts.title)
	end
	if opts.saved then
		FK:OnLoad(function()
			self:Restore()
			opts.saved[1]:OnChange("profile", function() self:Restore() end)
		end)
	end
	self:SetLocked(opts.locked)
end)

---@widget SectionTracker  Quest-tracker style frame: collapsible sections (header with arrow, icon, title, counter) of objective lines (bullet or tick, text, value, thin progress bar). Movable by its title, lockable, position saved, collapsed state remembered. opts: title, width (default 250), saved = { db, "profile.tracker" }, locked, background (default true), maxHeight (rows beyond it are cut with "+N more"). SetSections({ { id, title, icon (texture or icon-set name), color, collapsed, onClick(section, button), lines = { { text, value, done, progress = 0..1, color, onClick(line, button) } } } }). Methods: SetLocked, ResetPosition, Toggle(id).
FK.Define("SectionTracker", {
	SetLocked = function(self, locked)
		self.locked = locked and true or false
		self.head:EnableMouse(not self.locked)
	end,
	ResetPosition = function(self)
		self:ClearAllPoints()
		self:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
		self:Store()
	end,
	Store = function(self)
		local saved = self.opts.saved
		if not saved then return end
		local point, _, relPoint, x, y = self:GetPoint(1)
		local old = saved[1]:Get(saved[2])
		saved[1]:Set(saved[2], { point = point, relPoint = relPoint, x = x, y = y, collapsed = type(old) == "table" and old.collapsed or nil })
	end,
	Restore = function(self)
		local saved = self.opts.saved
		local s = saved and saved[1]:Get(saved[2])
		if type(s) ~= "table" then return end
		self.collapsed = s.collapsed and FK.Copy(s.collapsed) or self.collapsed
		if not s.point then return end
		self:ClearAllPoints()
		self:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
	end,
	SetSections = function(self, sections)
		self.sections = sections or {}
		for _, sec in ipairs(self.sections) do
			if sec.id ~= nil and self.collapsed[sec.id] == nil and sec.collapsed then self.collapsed[sec.id] = true end
		end
		self:Refresh()
	end,
	Toggle = function(self, id)
		self.collapsed[id] = not self.collapsed[id] or nil
		local saved = self.opts.saved
		if saved then
			local s = FK.Copy(saved[1]:Get(saved[2]) or {})
			s.collapsed = next(self.collapsed) and FK.Copy(self.collapsed) or nil
			saved[1]:Set(saved[2], s)
		end
		self:Refresh()
	end,
	Row = function(self, i)
		local row = self.rows[i]
		if row then return row end
		row = CreateFrame("Button", nil, self)
		row:RegisterForClicks("AnyUp")
		row.arrow = Theme.Icon(row, "arrowRight", 10)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(14, 14)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.value:SetPoint("RIGHT", -2, 0)
		row.value:SetJustifyH("RIGHT")
		row.text:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
		row.bar = row:CreateTexture(nil, "ARTWORK")
		row.bar:SetHeight(2)
		row.barBg = row:CreateTexture(nil, "BORDER")
		row.barBg:SetHeight(2)
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row:SetScript("OnClick", function(r, button)
			local item = r.item
			if not item then return end
			if r.isHeader then
				if item.onClick and button == "RightButton" then item.onClick(item, button) else self:Toggle(item.id) end
			elseif item.onClick then
				item.onClick(item, button)
			end
		end)
		self.rows[i] = row
		return row
	end,
	Refresh = function(self)
		local T = Theme.current
		local y = self.opts.title and 22 or 4
		local n, maxH = 0, self.opts.maxHeight
		local hidden = 0
		for _, r in ipairs(self.rows) do r:Hide() end
		local function add(item, isHeader, depth)
			if maxH and y + 18 > maxH then hidden = hidden + 1 return end
			n = n + 1
			local row = self:Row(n)
			row.item, row.isHeader = item, isHeader
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 6, -y)
			row:SetPoint("RIGHT", -6, 0)
			local h = isHeader and 18 or (item.progress and 18 or 15)
			row:SetHeight(h)
			Theme.Texture(row.hl, T.surface.row.hover)
			local x = 0
			row.arrow:SetShown(isHeader)
			if isHeader then
				row.arrow:ClearAllPoints()
				row.arrow:SetPoint("LEFT", 0, 0)
				row.arrow:SetIcon(self.collapsed[item.id] and "arrowRight" or "arrowDown")
				x = 14
			end
			local icon = isHeader and item.icon or (not isHeader and (item.done and "check" or nil))
			row.icon:SetShown(icon ~= nil or not isHeader)
			row.icon:ClearAllPoints()
			if icon then
				local named = type(icon) == "string" and FK.mediaIcons[icon]
				row.icon:SetTexture(named and FK.Media("Icons/" .. icon) or icon)
				row.icon:SetSize(isHeader and 14 or 10, isHeader and 14 or 10)
				if named then row.icon:SetVertexColor(Theme.Color(item.done and "good" or "heading")) else row.icon:SetVertexColor(1, 1, 1) end
			elseif not isHeader then
				row.icon:SetTexture(FK.Media("Frames/pill"))
				row.icon:SetSize(4, 4)
				row.icon:SetVertexColor(Theme.Color("dim"))
			end
			row.icon:SetPoint(isHeader and "LEFT" or "TOPLEFT", x + (isHeader and 0 or 6), isHeader and 0 or -4)
			x = x + (isHeader and 18 or 18)
			row.text:ClearAllPoints()
			row.text:SetPoint(isHeader and "LEFT" or "TOPLEFT", x, isHeader and 0 or -1)
			row.text:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
			Theme.Font(row.text, isHeader and "heading" or "small", isHeader and "heading" or (item.done and "dim" or nil))
			Theme.Font(row.value, "small", item.done and "good" or "dim")
			local c = item.color
			if type(c) == "table" then row.text:SetTextColor(c[1], c[2], c[3]) end
			row.text:SetText(item.text or item.title or "")
			local value = item.value
			if isHeader and value == nil and item.lines then
				local done = 0
				for _, l in ipairs(item.lines) do if l.done then done = done + 1 end end
				value = ("%d/%d"):format(done, #item.lines)
			end
			row.value:SetText(value or "")
			local p = not isHeader and item.progress
			row.bar:SetShown(p and true or false)
			row.barBg:SetShown(p and true or false)
			if p then
				row.barBg:ClearAllPoints()
				row.barBg:SetPoint("BOTTOMLEFT", x, 1)
				row.barBg:SetPoint("BOTTOMRIGHT", -2, 1)
				Theme.Texture(row.barBg, T.surface.barBackground)
				row.bar:ClearAllPoints()
				row.bar:SetPoint("BOTTOMLEFT", row.barBg, "BOTTOMLEFT")
				local w = math.max((self:GetWidth() - 12 - x - 2) * math.min(math.max(p, 0), 1), 0.01)
				row.bar:SetWidth(w)
				row.bar:SetColorTexture(Theme.Color(item.done and "good" or "accent"))
			end
			row:Show()
			y = y + h + (isHeader and 2 or 1)
		end
		for _, sec in ipairs(self.sections or {}) do
			add(sec, true, 0)
			if not self.collapsed[sec.id] then
				for _, line in ipairs(sec.lines or {}) do add(line, false, 1) end
			end
			y = y + 4
		end
		if hidden > 0 then
			add({ text = ("+%d more"):format(hidden), color = { Theme.Color("dim") } }, false, 1)
		end
		self:SetHeight(math.max(y + 2, 26))
		Theme.Paint(self, self.opts.background ~= false and T.surface.panel or nil, Theme.opacity)
	end,
	Restyle = function(self)
		if self.title then Theme.Font(self.title, "title") end
		self:Refresh()
	end,
}, function(self, opts)
	self.sections, self.rows, self.collapsed = {}, {}, {}
	self:SetParent(UIParent)
	self:SetWidth(opts.width or 250)
	self:SetClampedToScreen(true)
	self:SetMovable(true)
	if self:GetNumPoints() == 0 then self:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60) end
	self.head = CreateFrame("Frame", nil, self)
	self.head:SetPoint("TOPLEFT")
	self.head:SetPoint("TOPRIGHT")
	self.head:SetHeight(20)
	self.head:EnableMouse(true)
	self.head:RegisterForDrag("LeftButton")
	self.head:SetScript("OnDragStart", function() if not self.locked then self:StartMoving() end end)
	self.head:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		self:Store()
	end)
	if opts.title then
		self.title = self:Text("title", nil, self.head)
		self.title:SetPoint("LEFT", 8, -1)
		self.title:SetText(opts.title)
	end
	if opts.saved then
		FK:OnLoad(function()
			self:Restore()
			self:Refresh()
			opts.saved[1]:OnChange("profile", function() self:Restore() self:Refresh() end)
		end)
	end
	self:SetLocked(opts.locked)
end)
