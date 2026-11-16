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
