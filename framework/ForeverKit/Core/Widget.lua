local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- Every ForeverKit widget is a plain Frame with methods mixed in, created by
--     local w = FK.<Kind>(parent, opts)
-- `opts` is one table. Keys every widget understands:
--     name      global frame name (rarely needed)
--     width, height
--     point     { "TOPLEFT", 10, -10 } passed to SetPoint (several: points = { {...}, {...} })
--     tooltip   text, or { title, text }
--     disabled  start disabled
--     hidden    start hidden
--     onChange  function(value, widget): called for USER changes only
-- Methods every widget has: SetEnabled(bool), IsEnabled(), SetTooltip(text | {title, text}),
-- and, where it holds a value, SetValue(v) (silent: does not call onChange) and GetValue().

local Widget = {}
FK.Widget = Widget

function Widget:SetEnabled(enabled)
	enabled = not not enabled
	if self.enabled == enabled then return end
	self.enabled = enabled
	if self.OnEnabled then self:OnEnabled(enabled) end
	self:Restyle()
end
function Widget:IsEnabled() return self.enabled end
function Widget:Restyle() end

function Widget:SetTooltip(tooltip) self.tooltip = tooltip end

-- Called by the widget's interactive parts on enter/leave.
function Widget:ShowTooltip(owner)
	local tip = self.tooltip
	if not tip then return end
	if type(tip) == "function" then tip = tip(self) end
	if not tip then return end
	GameTooltip:SetOwner(owner or self, "ANCHOR_RIGHT")
	if type(tip) == "table" then
		GameTooltip:SetText(tip[1], 1, 1, 1)
		if tip[2] then GameTooltip:AddLine(tip[2], nil, nil, nil, true) end
	else
		GameTooltip:SetText(tip, nil, nil, nil, nil, true)
	end
	GameTooltip:Show()
end
function Widget:HideTooltip()
	if GameTooltip:IsOwned(self) or self.tooltip then GameTooltip:Hide() end
end

-- Wires hover tooltip (and an optional hover callback) to an interactive child frame.
function Widget:Hoverable(frame, onHover)
	frame:SetScript("OnEnter", function()
		self.hover = true
		if onHover then onHover(true) end
		self:ShowTooltip(frame)
	end)
	frame:SetScript("OnLeave", function()
		self.hover = false
		if onHover then onHover(false) end
		GameTooltip:Hide()
	end)
end

function Widget:Fire(value)
	if self.opts.onChange then self.opts.onChange(value, self) end
end

-- A font string that follows the theme: role is a T.font key, color a T.color key (default:
-- the role's own colour). It greys out with the widget.
function Widget:Text(role, color, parent, layer)
	local fs = (parent or self):CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
	fs.fkRole, fs.fkColor = role or "normal", color
	self.fkTexts = self.fkTexts or {}
	self.fkTexts[#self.fkTexts + 1] = fs
	Theme.Font(fs, fs.fkRole, color)
	return fs
end

-- A Button child that keeps the widget's hover/down flags current, repaints on change, shows
-- the tooltip, and calls onClick(mouseButton) only while the widget is enabled. The native
-- button stays enabled so that a disabled control can still explain itself in its tooltip.
function Widget:Clickable(parent, onClick)
	local b = CreateFrame("Button", nil, parent or self, "BackdropTemplate")
	b:SetScript("OnEnter", function()
		self.hover = true
		self:Restyle()
		self:ShowTooltip(b)
	end)
	b:SetScript("OnLeave", function()
		self.hover = false
		self:Restyle()
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function()
		if self.enabled then
			self.down = true
			self:Restyle()
		end
	end)
	b:SetScript("OnMouseUp", function()
		self.down = false
		self:Restyle()
	end)
	b:SetScript("OnClick", function(_, button)
		if self.enabled and onClick then onClick(button) end
	end)
	return b
end

-- Optional caption above a control. Returns the vertical space it takes.
function Widget:Caption(text)
	if not text then return 0 end
	self.label = self:Text("normal")
	self.label:SetPoint("TOPLEFT")
	self.label:SetText(text)
	return 16
end

-- Tells the layout container holding this widget that its size changed.
function Widget:Changed()
	local container = self.fkContainer
	if container then container:Layout() end
end

-- FK.Define("Kind", methods, build) creates the constructor FK.Kind(parent, opts).
-- build(widget, opts) creates the parts; methods.Restyle applies the theme.
function FK.Define(kind, methods, build)
	methods.kind = kind
	FK[kind] = function(parent, opts)
		if type(parent) ~= "table" or not parent.GetObjectType then
			error(("FK.%s(parent, opts): parent must be a frame"):format(kind), 2)
		end
		if opts ~= nil and type(opts) ~= "table" then error(("FK.%s(parent, opts): opts must be a table"):format(kind), 2) end
		opts = opts or {}
		local w = CreateFrame("Frame", opts.name, parent, "BackdropTemplate")
		Mixin(w, Widget, methods)
		w.opts, w.enabled, w.tooltip = opts, true, opts.tooltip
		local restyle = methods.Restyle
		w.Restyle = function(self)
			for _, fs in ipairs(self.fkTexts or {}) do
				Theme.Font(fs, fs.fkRole, not self.enabled and "disabled" or fs.fkColor)
			end
			if restyle then restyle(self) end
		end
		-- size and anchors first, so build() can override them (a window restoring its saved place)
		if opts.width then w:SetWidth(opts.width) end
		if opts.height then w:SetHeight(opts.height) end
		if opts.point then w:SetPoint(unpack(opts.point)) end
		for _, p in ipairs(opts.points or {}) do w:SetPoint(unpack(p)) end
		build(w, opts)
		Theme.Track(w)
		w:Restyle()
		if opts.disabled then w:SetEnabled(false) end
		if opts.hidden then w:Hide() end
		return w
	end
end

-- A themed child frame that can be painted with FK.Theme.Paint.
function FK.Frame(frameType, parent, name)
	return CreateFrame(frameType or "Frame", name, parent, "BackdropTemplate")
end
