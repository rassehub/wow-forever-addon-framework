local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Sliders are the control for every numeric setting: distance, scale, opacity, size, count,
-- duration. They show the exact value, accept a typed value, and step with the arrows, so
-- there is never a reason to offer a list of preset numbers instead.

local function decimals(step)
	local d = tostring(step):match("%.(%d+)$")
	return d and #d or 0
end

-- opts.format: "%d yd" | function(value) -> string | nil (plain number with the step's decimals)
-- opts.percent: value 0..1 shown as 0%..100%
local function display(opts, v)
	if opts.percent then return ("%d%%"):format(v * 100 + 0.5) end
	local f = opts.format
	if type(f) == "function" then return f(v) end
	if f then return f:format(v) end
	return ("%." .. decimals(opts.step or 1) .. "f"):format(v)
end
FK.FormatValue = display

local function parse(opts, text)
	local n = tonumber((text:gsub(",", "."):match("-?%d*%.?%d+")))
	if n and opts.percent then n = n / 100 end
	return n
end

local function normalize(opts, v)
	return FK.Clamp(opts.min + FK.Round(v - opts.min, opts.step or 1), opts.min, opts.max)
end

-- The small box that shows the value and takes a typed one.
local function valueBox(self, width)
	local holder = FK.Frame("Frame", self)
	holder:SetSize(width or 52, 18)
	local box = CreateFrame("EditBox", nil, holder)
	box:SetPoint("TOPLEFT", 4, 0)
	box:SetPoint("BOTTOMRIGHT", -4, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	box:SetScript("OnEditFocusGained", function(b)
		self.editing = true
		self:Restyle()
		b:HighlightText()
	end)
	box:SetScript("OnEditFocusLost", function(b)
		self.editing = false
		b:HighlightText(0, 0)
		self:Restyle()
		self:Refresh() -- whatever was typed, show the real value again
	end)
	box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
	box:SetScript("OnEnterPressed", function(b)
		local n = parse(self.opts, b:GetText())
		b:ClearFocus()
		if n then self:Commit(n) end
	end)
	self.fkTexts = self.fkTexts or {}
	box.fkRole = "number"
	self.fkTexts[#self.fkTexts + 1] = box
	return holder, box
end

---@widget Slider  Numeric setting. opts: label, min, max, step (default 1), value, format ("%d yd" or function), percent (0..1 shown as %), live (default true; false = onChange only when the drag ends, for values that are expensive or disorienting to apply mid-drag such as UI scale), editable (default true: typed value), steppers (default true: arrow buttons), onChange(value).
FK.Define("Slider", {
	SetValue = function(self, v)
		self.value = normalize(self.opts, v)
		self.slider:SetValue(self.value)
		self:Refresh()
	end,
	GetValue = function(self) return self.value end,
	SetRange = function(self, min, max)
		self.opts.min, self.opts.max = min, max
		self.slider:SetMinMaxValues(min, max)
		self:SetValue(self.value)
	end,
	-- A user change from the value box or the arrows.
	Commit = function(self, v)
		v = normalize(self.opts, v)
		if v == self.value then return self:Refresh() end
		self:SetValue(v)
		self:Fire(v)
	end,
	Refresh = function(self)
		if not self.editing then self.box:SetText(display(self.opts, self.value)) end
	end,
	OnEnabled = function(self, enabled)
		self.slider:SetEnabled(enabled)
		self.box:SetEnabled(enabled and self.opts.editable ~= false)
		if not enabled then self.box:ClearFocus() end
	end,
	Restyle = function(self)
		local T = Theme.current
		local m, s = T.metric, T.surface
		local lineHeight = math.max(m.thumbHeight, 18)
		self:SetHeight(self.top + lineHeight)
		self.line:SetHeight(lineHeight)
		self.track:SetHeight(m.slider)
		Theme.Paint(self.track, s.track)
		self.fill:SetShown(s.fill and true or false)
		if s.fill then Theme.Texture(self.fill, s.fill, self.enabled and 1 or 0.4) end
		self.thumb:SetSize(m.thumbWidth, m.thumbHeight)
		Theme.Texture(self.thumb, s.thumb[Theme.State(self)] or s.thumb.normal)
		Theme.Paint(self.boxHolder, s.input[not self.enabled and "disabled" or self.editing and "focus" or "normal"])
		if self.minus then
			self.minus:SetEnabled(self.enabled)
			self.plus:SetEnabled(self.enabled)
		end
	end,
}, function(self, opts)
	if type(opts.min) ~= "number" or type(opts.max) ~= "number" or opts.min >= opts.max then
		error("FK.Slider: opts.min and opts.max must be numbers with min < max", 3)
	end
	opts.step = opts.step or (opts.percent and 0.01 or 1)
	self.top = self:Caption(opts.label)
	self.boxHolder, self.box = valueBox(self)
	if opts.editable == false then self.box:SetEnabled(false) end

	-- the control line: [-] track [+] and, without a caption, the value box at the right
	self.line = CreateFrame("Frame", nil, self)
	self.line:SetPoint("TOPLEFT", 0, -self.top)
	if opts.label then
		self.boxHolder:SetPoint("TOPRIGHT", 0, 2)
		self.line:SetPoint("RIGHT")
	else
		self.boxHolder:SetPoint("RIGHT")
		self.line:SetPoint("RIGHT", self.boxHolder, "LEFT", -6, 0)
	end
	local left, right = 0, 0
	if opts.steppers ~= false then
		local function stepper(icon, direction, point)
			local b = FK.IconButton(self.line, { icon = icon, size = 16, bare = true, onClick = function()
				self:Commit(self.value + direction * opts.step)
			end })
			b:SetPoint(point)
			return b
		end
		self.minus, self.plus = stepper("arrowLeft", -1, "LEFT"), stepper("arrowRight", 1, "RIGHT")
		left, right = 18, -18
	end

	self.track = FK.Frame("Frame", self.line)
	self.track:SetPoint("LEFT", left, 0)
	self.track:SetPoint("RIGHT", right, 0)

	local slider = CreateFrame("Slider", nil, self.line)
	self.slider = slider
	slider:SetPoint("TOPLEFT", left, 0)
	slider:SetPoint("BOTTOMRIGHT", right, 0)
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(opts.min, opts.max)
	slider:SetValueStep(opts.step)
	slider:SetObeyStepOnDrag(true)
	self.thumb = slider:CreateTexture(nil, "OVERLAY")
	slider:SetThumbTexture(self.thumb)
	self.fill = self.track:CreateTexture(nil, "ARTWORK")
	self.fill:SetPoint("TOPLEFT", 1, -1)
	self.fill:SetPoint("BOTTOMLEFT", 1, 1)
	self.fill:SetPoint("RIGHT", self.thumb, "CENTER")

	self.value = normalize(opts, opts.value or opts.min)
	slider:SetValue(self.value)
	slider:SetScript("OnValueChanged", function(_, v, userInput)
		if not userInput then return end
		v = normalize(opts, v)
		if v == self.value then return end
		self.value = v
		self:Refresh()
		if opts.live ~= false then self:Fire(v) else self.pending = true end
	end)
	slider:SetScript("OnMouseUp", function()
		if self.pending then
			self.pending = nil
			self:Fire(self.value)
		end
	end)
	self:Hoverable(slider, function() self:Restyle() end)
	self:Refresh()
end)

---@widget RangeSlider  Two thumbs on one track for a minimum and a maximum (level range, price range). opts: label, min, max, step, value = { low, high }, format, onChange({ low, high }).
FK.Define("RangeSlider", {
	SetValue = function(self, v)
		local o = self.opts
		local low, high = normalize(o, v[1]), normalize(o, v[2])
		if low > high then low, high = high, low end
		self.value = { low, high }
		self:Refresh()
	end,
	GetValue = function(self) return { self.value[1], self.value[2] } end,
	Refresh = function(self)
		local o, width = self.opts, self.track:GetWidth() - Theme.current.metric.thumbWidth
		local function x(v) return (v - o.min) / (o.max - o.min) * math.max(width, 0) end
		self.low:SetPoint("LEFT", self.track, "LEFT", x(self.value[1]), 0)
		self.high:SetPoint("LEFT", self.track, "LEFT", x(self.value[2]), 0)
		self.text:SetText(display(o, self.value[1]) .. " - " .. display(o, self.value[2]))
	end,
	Restyle = function(self)
		local T = Theme.current
		local m, s = T.metric, T.surface
		local lineHeight = math.max(m.thumbHeight, 18)
		self:SetHeight(self.top + lineHeight)
		self.track:SetHeight(m.slider)
		self.track:ClearAllPoints()
		self.track:SetPoint("LEFT", self, "TOPLEFT", 0, -self.top - lineHeight / 2)
		self.track:SetPoint("RIGHT", self, "TOPRIGHT", 0, -self.top - lineHeight / 2)
		Theme.Paint(self.track, s.track)
		self.fill:SetShown(s.fill and true or false)
		if s.fill then Theme.Texture(self.fill, s.fill, self.enabled and 1 or 0.4) end
		for _, thumb in ipairs({ self.low, self.high }) do
			thumb:SetSize(m.thumbWidth, m.thumbHeight)
			Theme.Texture(thumb.tex, s.thumb[not self.enabled and "disabled" or thumb.hover and "hover" or "normal"] or s.thumb.normal)
		end
		self:Refresh()
	end,
}, function(self, opts)
	if type(opts.min) ~= "number" or type(opts.max) ~= "number" or opts.min >= opts.max then
		error("FK.RangeSlider: opts.min and opts.max must be numbers with min < max", 3)
	end
	opts.step = opts.step or 1
	self.top = self:Caption(opts.label or "")
	self.text = self:Text("number")
	self.text:SetPoint("TOPRIGHT")
	self.track = FK.Frame("Frame", self)
	self.fill = self.track:CreateTexture(nil, "ARTWORK")

	local function thumb(index)
		local b = CreateFrame("Button", nil, self)
		b.tex = b:CreateTexture(nil, "OVERLAY")
		b.tex:SetAllPoints()
		b:SetScript("OnEnter", function() b.hover = true self:Restyle() self:ShowTooltip(b) end)
		b:SetScript("OnLeave", function() b.hover = false self:Restyle() GameTooltip:Hide() end)
		b:SetScript("OnMouseDown", function()
			if not self.enabled then return end
			b:SetScript("OnUpdate", function()
				local scale = self.track:GetEffectiveScale()
				local m = Theme.current.metric
				local width = self.track:GetWidth() - m.thumbWidth
				local pos = GetCursorPosition() / scale - self.track:GetLeft() - m.thumbWidth / 2
				local v = normalize(opts, opts.min + FK.Clamp(pos / math.max(width, 1), 0, 1) * (opts.max - opts.min))
				-- a thumb cannot pass the other one
				if index == 1 then v = math.min(v, self.value[2]) else v = math.max(v, self.value[1]) end
				if v ~= self.value[index] then
					self.value[index] = v
					self:Refresh()
					self:Fire(self:GetValue())
				end
			end)
		end)
		b:SetScript("OnMouseUp", function() b:SetScript("OnUpdate", nil) end)
		return b
	end
	self.low, self.high = thumb(1), thumb(2)
	self.fill:SetPoint("TOP", self.track, "TOP", 0, -1)
	self.fill:SetPoint("BOTTOM", self.track, "BOTTOM", 0, 1)
	self.fill:SetPoint("LEFT", self.low, "CENTER")
	self.fill:SetPoint("RIGHT", self.high, "CENTER")
	self.value = { opts.min, opts.max }
	if opts.value then self:SetValue(opts.value) end
	self:SetScript("OnSizeChanged", function() self:Refresh() end)
end)

---@widget Stepper  Compact whole-number input with - and + buttons, for small counts (rows, columns, stacks). For ranges wider than about 20 steps use Slider. opts: label, min, max, step, value, format, onChange(value).
FK.Define("Stepper", {
	fill = false,
	SetValue = function(self, v)
		self.value = normalize(self.opts, v)
		self:Refresh()
	end,
	GetValue = function(self) return self.value end,
	Commit = function(self, v)
		v = normalize(self.opts, v)
		if v == self.value then return self:Refresh() end
		self:SetValue(v)
		self:Fire(v)
	end,
	Refresh = function(self)
		if not self.editing then self.box:SetText(display(self.opts, self.value)) end
		self.minus:SetEnabled(self.enabled and self.value > self.opts.min)
		self.plus:SetEnabled(self.enabled and self.value < self.opts.max)
	end,
	OnEnabled = function(self, enabled) self.box:SetEnabled(enabled) end,
	Restyle = function(self)
		local T = Theme.current
		local h = T.metric.control
		self:SetHeight(self.top + h)
		self.boxHolder:SetHeight(h)
		Theme.Paint(self.boxHolder, T.surface.input[not self.enabled and "disabled" or self.editing and "focus" or "normal"])
		self:Refresh()
	end,
}, function(self, opts)
	opts.min, opts.max, opts.step = opts.min or 0, opts.max or 100, opts.step or 1
	self.top = self:Caption(opts.label)
	self:SetWidth(opts.width or 110)
	local size = Theme.current.metric.control
	local function button(icon, direction, point)
		local b = FK.IconButton(self, { icon = icon, size = size, onClick = function() self:Commit(self.value + direction * opts.step) end })
		b:SetPoint(point)
		return b
	end
	self.minus, self.plus = button("minus", -1, "BOTTOMLEFT"), button("plus", 1, "BOTTOMRIGHT")
	self.boxHolder, self.box = valueBox(self)
	self.boxHolder:ClearAllPoints()
	self.boxHolder:SetPoint("BOTTOMLEFT", self.minus, "BOTTOMRIGHT", 2, 0)
	self.boxHolder:SetPoint("BOTTOMRIGHT", self.plus, "BOTTOMLEFT", -2, 0)
	self.value = normalize(opts, opts.value or opts.min)
end)
