local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Layout containers. Add children with container:Add(widget); the container positions them
-- and sizes itself to fit, so containers nest and can be put in a scroll area.
-- A child's own opts steer its placement:
--     fill = false     keep its natural width instead of stretching (Stack)
--     indent = 16      shift right (Stack)
--     flex = 1         share of the leftover width (Row)
-- Call container:Layout() after showing/hiding children or changing their size by hand;
-- widgets that resize themselves do it for you.

local function metric(self, key, default)
	local v = self.opts[key]
	if v ~= nil then return v end
	return default or Theme.current.metric[key]
end

local Container = {}

function Container:Add(widget)
	widget:SetParent(self)
	widget.fkContainer = self
	self.items[#self.items + 1] = widget
	self:Layout()
	return widget
end

function Container:Remove(widget)
	for i, w in ipairs(self.items) do
		if w == widget then table.remove(self.items, i) break end
	end
	widget.fkContainer = nil
	widget:Hide()
	self:Layout()
end

function Container:Clear()
	for _, w in ipairs(self.items) do
		w.fkContainer = nil
		w:Hide()
	end
	self.items = {}
	self:Layout()
end

-- Runs fn with layout suspended, then lays out once: for adding many children.
function Container:Batch(fn)
	self.suspended = true
	fn(self)
	self.suspended = nil
	self:Layout()
end

function Container:Layout()
	if self.suspended or self.laying then return end
	local width = self:GetWidth()
	if width <= 0 then return end -- not sized yet; OnSizeChanged calls back
	self.laying = true
	self:Arrange(width)
	self.laying = nil
	self:Changed()
end

function Container:Restyle() self:Layout() end
Container.Fit = Container.Layout -- a parent container that just set our width asks us to re-flow

local function build(self)
	self.items = {}
	self:SetHeight(1)
	self:SetScript("OnSizeChanged", function(_, w)
		if w ~= self.lastWidth then
			self.lastWidth = w
			self:Layout()
		end
	end)
end

local function wantsFill(w)
	local fill = w.opts and w.opts.fill
	if fill == nil then fill = w.fill end
	return fill ~= false
end

---@widget Stack  Vertical list of children, each on its own line. opts: gap, padding.
local Stack = Mixin({}, Container)
function Stack:Arrange(width)
	local pad, gap = metric(self, "padding", 0), metric(self, "gap")
	local y = pad
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			local indent = w.opts and w.opts.indent or 0
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", self, "TOPLEFT", pad + indent, -y)
			if wantsFill(w) then w:SetWidth(width - pad * 2 - indent) end
			if w.Fit then w:Fit() end
			y = y + w:GetHeight() + gap
		end
	end
	self:SetHeight(math.max(y - gap + pad, 1))
end
FK.Define("Stack", Stack, build)

---@widget Row  Children side by side, vertically centred. opts: gap, padding, align = "LEFT"|"RIGHT". Children with opts.flex share the leftover width.
local Row = Mixin({}, Container)
function Row:Arrange(width)
	local pad, gap = metric(self, "padding", 0), metric(self, "gap")
	local fixed, flex, height, shown = 0, 0, 1, 0
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			shown = shown + 1
			local f = w.opts and w.opts.flex
			if f then flex = flex + f else fixed = fixed + w:GetWidth() end
		end
	end
	local free = math.max(0, width - pad * 2 - fixed - gap * math.max(shown - 1, 0))
	local x = pad
	if flex == 0 and self.opts.align == "RIGHT" then x = pad + free end
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			local f = w.opts and w.opts.flex
			if f then w:SetWidth(free * f / flex) end
			if w.Fit then w:Fit() end
			height = math.max(height, w:GetHeight())
		end
	end
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", self, "TOPLEFT", x, -pad - (height - w:GetHeight()) / 2)
			x = x + w:GetWidth() + gap
		end
	end
	self:SetHeight(height + pad * 2)
end
FK.Define("Row", Row, build)

---@widget Grid  Equal-width columns, filled row by row. opts: columns (default 2), gap, padding.
local Grid = Mixin({}, Container)
function Grid:Arrange(width)
	local pad, gap, columns = metric(self, "padding", 0), metric(self, "gap"), self.opts.columns or 2
	local colWidth = (width - pad * 2 - gap * (columns - 1)) / columns
	local y, col, rowHeight = pad, 0, 0
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			if col == columns then
				y, col, rowHeight = y + rowHeight + gap, 0, 0
			end
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", self, "TOPLEFT", pad + col * (colWidth + gap), -y)
			if wantsFill(w) then w:SetWidth(colWidth) end
			if w.Fit then w:Fit() end
			rowHeight = math.max(rowHeight, w:GetHeight())
			col = col + 1
		end
	end
	self:SetHeight(math.max(y + rowHeight + pad, 1))
end
FK.Define("Grid", Grid, build)

---@widget Flow  Children left to right, wrapping to new lines (icon grids, tag lists). opts: gap, padding.
local Flow = Mixin({}, Container)
function Flow:Arrange(width)
	local pad, gap = metric(self, "padding", 0), metric(self, "gap")
	local x, y, rowHeight = pad, pad, 0
	for _, w in ipairs(self.items) do
		if w:IsShown() then
			local ww = w:GetWidth()
			if x > pad and x + ww > width - pad then
				x, y, rowHeight = pad, y + rowHeight + gap, 0
			end
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + ww + gap
			rowHeight = math.max(rowHeight, w:GetHeight())
		end
	end
	self:SetHeight(math.max(y + rowHeight + pad, 1))
end
FK.Define("Flow", Flow, build)

-- Builds a tree of widgets from data:
--   local root, refs = FK.Build(parent, { "Stack", gap = 8, children = {
--       { "Heading", text = "Range" },
--       { "Slider", id = "range", min = 5, max = 40, step = 1, format = "%d yd" },
--   } })
--   refs.range:SetValue(20)
-- spec[1] is the widget kind, `children` are added with :Add, `id` names the widget in refs.
function FK.Build(parent, spec, refs)
	refs = refs or {}
	local kind = spec[1]
	local make = FK[kind]
	if type(make) ~= "function" then error("FK.Build: unknown widget kind " .. tostring(kind), 2) end
	local w = make(parent, spec)
	if spec.id then refs[spec.id] = w end
	if spec.children then
		if not w.Add then error("FK.Build: " .. kind .. " cannot hold children", 2) end
		local function addAll()
			for _, child in ipairs(spec.children) do w:Add(FK.Build(w.content or w, child, refs)) end
		end
		if w.Batch then w:Batch(addAll) else addAll() end
	end
	return w, refs
end
