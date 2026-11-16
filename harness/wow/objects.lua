-- Widget object model of the emulator: regions, frames and their subclasses, anchors and layout.
-- Internal state of an object lives in obj[0] (the real client keeps a userdata there), so
-- addon code is free to put any other field on a frame.

local H = require("wow.state")

local function dirty() H.gen = H.gen + 1 end

---------------------------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------------------------

local classes = {}

local function class(name, parent, scripts)
	local c = setmetatable({}, { __index = parent })
	c.__index = c
	c._type = name
	c._parent = parent
	c._scripts = setmetatable({}, { __index = parent and parent._scripts })
	for s in (scripts or ""):gmatch("%S+") do c._scripts[s] = true end
	classes[name] = c
	return c
end

local Object = class("Object")
local Region = class("Region", Object, "OnShow OnHide OnEnter OnLeave OnMouseDown OnMouseUp OnMouseWheel OnSizeChanged")
local Layered = class("LayeredRegion", Region)
local Texture = class("Texture", Layered)
local FontString = class("FontString", Layered)
local Frame = class("Frame", Region,
	"OnEvent OnUpdate OnLoad OnDragStart OnDragStop OnReceiveDrag OnKeyDown OnKeyUp OnChar OnAttributeChanged OnEnable OnDisable OnHyperlinkClick OnHyperlinkEnter OnHyperlinkLeave")
local Button = class("Button", Frame, "OnClick OnDoubleClick PreClick PostClick")
local CheckButton = class("CheckButton", Button)
local Slider = class("Slider", Frame, "OnValueChanged OnMinMaxChanged")
local StatusBar = class("StatusBar", Frame, "OnValueChanged OnMinMaxChanged")
local EditBox = class("EditBox", Frame,
	"OnTextChanged OnEnterPressed OnEscapePressed OnTabPressed OnSpacePressed OnEditFocusGained OnEditFocusLost OnArrowPressed OnCursorChanged OnTextSet OnInputLanguageChanged")
local ScrollFrame = class("ScrollFrame", Frame, "OnVerticalScroll OnHorizontalScroll OnScrollRangeChanged")
local GameTooltip = class("GameTooltip", Frame, "OnTooltipCleared OnTooltipSetDefaultAnchor")
local Cooldown = class("Cooldown", Frame, "OnCooldownDone")
local FontObject = class("Font", Object)

local function debugname(o)
	local s = o[0]
	return ("%s%s"):format(s.type, s.name and (' "' .. s.name .. '"') or "")
end
H.debugname = debugname

local function new(c, name, parent)
	local o = setmetatable({}, c)
	H.serial = H.serial + 1
	o[0] = {
		type = c._type, name = name, parent = parent, points = {}, shown = true, alpha = 1, scale = 1,
		scripts = {}, serial = H.serial, children = {}, regions = {},
	}
	return o
end

---------------------------------------------------------------------------------------------
-- Object
---------------------------------------------------------------------------------------------

function Object:GetName() return self[0].name end
function Object:GetDebugName() return self[0].name or debugname(self) end
function Object:GetObjectType() return self[0].type end
function Object:GetParent() return self[0].parent end
function Object:IsForbidden() return false end

function Object:IsObjectType(t)
	local c = getmetatable(self)
	while c do
		if c._type == t then return true end
		c = c._parent
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Region: visibility
---------------------------------------------------------------------------------------------

local function run(o, script, ...)
	local fn = o[0].scripts[script]
	if fn then return fn(o, ...) end
end
H.run = run

function Region:IsShown() return self[0].shown end

function Region:IsVisible()
	local o = self
	while o do
		if not o[0].shown then return false end
		o = o[0].parent
	end
	return true
end

local function visibilityChanged(o, script)
	run(o, script)
	for _, child in ipairs(o[0].children) do
		if child[0].shown then visibilityChanged(child, script) end
	end
end

function Region:SetShown(shown)
	shown = not not shown
	local s = self[0]
	if s.shown == shown then return end
	s.shown = shown
	dirty()
	local parent = s.parent
	if not parent or parent:IsVisible() then
		visibilityChanged(self, shown and "OnShow" or "OnHide")
	end
end
function Region:Show() self:SetShown(true) end
function Region:Hide() self:SetShown(false) end

function Region:SetAlpha(a) self[0].alpha = a end
function Region:GetAlpha() return self[0].alpha end
function Region:GetEffectiveAlpha()
	local a, o = 1, self
	while o do a, o = a * o[0].alpha, o[0].parent end
	return a
end
function Region:SetIgnoreParentAlpha(v) self[0].ignoreParentAlpha = v end
function Region:SetIgnoreParentScale(v) self[0].ignoreParentScale = v end

---------------------------------------------------------------------------------------------
-- Region: scripts
---------------------------------------------------------------------------------------------

local function checkScript(o, script)
	if not getmetatable(o)._scripts[script] then
		error(('%s doesn\'t have a "%s" script'):format(debugname(o), tostring(script)), 3)
	end
end

function Region:SetScript(script, fn)
	checkScript(self, script)
	if fn ~= nil and type(fn) ~= "function" then error("SetScript: handler must be a function or nil", 2) end
	self[0].scripts[script] = fn
end
function Region:GetScript(script)
	checkScript(self, script)
	return self[0].scripts[script]
end
function Region:HasScript(script) return getmetatable(self)._scripts[script] == true end
function Region:HookScript(script, fn)
	checkScript(self, script)
	local old = self[0].scripts[script]
	self[0].scripts[script] = old and function(...)
		old(...)
		fn(...)
	end or fn
end

---------------------------------------------------------------------------------------------
-- Region: size, anchors, layout
---------------------------------------------------------------------------------------------

local function effscale(o)
	local sc = 1
	while o do
		local s = o[0]
		sc = sc * s.scale
		if s.ignoreParentScale then break end
		o = s.parent
	end
	return sc
end

function Region:SetScale(scale)
	if not (type(scale) == "number" and scale > 0) then error("SetScale: scale must be > 0", 2) end
	self[0].scale = scale
	dirty()
end
function Region:GetScale() return self[0].scale end
function Region:GetEffectiveScale() return effscale(self) end

function Region:SetWidth(w) self[0].width = w ~= 0 and w or nil; dirty() end
function Region:SetHeight(h) self[0].height = h ~= 0 and h or nil; dirty() end
function Region:SetSize(w, h) self:SetWidth(w); self:SetHeight(h or w) end

local POINTS = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local SCREEN = {} -- sentinel: anchored to the screen (relativeTo explicitly nil)

function Region:SetPoint(point, a, b, c, d)
	if not POINTS[point] then error("SetPoint: unknown point " .. tostring(point), 2) end
	local s = self[0]
	local rel, relPoint, x, y = s.parent or SCREEN, point, 0, 0
	local argc = select("#", a, b, c, d)
	if type(a) == "number" then
		x, y = a, b or 0
	elseif a ~= nil or b ~= nil then
		if type(a) == "string" then
			rel = _G[a]
			if not rel then error("SetPoint: no frame named " .. a, 2) end
		elseif a == nil then
			rel = SCREEN
		else
			rel = a
		end
		if type(b) == "string" then
			relPoint, x, y = b, c or 0, d or 0
		elseif type(b) == "number" then
			x, y = b, c or 0
		end
	end
	if not POINTS[relPoint] then error("SetPoint: unknown relative point " .. tostring(relPoint), 2) end
	if rel == self then error("SetPoint: cannot anchor a region to itself", 2) end
	if rel ~= SCREEN and (type(rel) ~= "table" or not rel[0]) then error("SetPoint: relativeTo is not a region", 2) end
	local entry = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
	for i, p in ipairs(s.points) do
		if p.point == point then
			s.points[i] = entry
			entry = nil
			break
		end
	end
	if entry then s.points[#s.points + 1] = entry end
	dirty()
end

function Region:ClearAllPoints() self[0].points = {}; dirty() end
function Region:ClearPoint(point)
	local pts = self[0].points
	for i = #pts, 1, -1 do
		if pts[i].point == point then table.remove(pts, i) end
	end
	dirty()
end
function Region:SetAllPoints(rel)
	self:ClearAllPoints()
	rel = rel or self[0].parent
	self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
	self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end
function Region:GetNumPoints() return #self[0].points end
function Region:GetPoint(i)
	local p = self[0].points[i or 1]
	if not p then return nil end
	return p.point, p.rel ~= SCREEN and p.rel or nil, p.relPoint, p.x, p.y
end
function Region:GetPointByName(point)
	for i, p in ipairs(self[0].points) do
		if p.point == point then return self:GetPoint(i) end
	end
end

local naturalSize -- (o) -> width, height in the object's own units; set by FontString below

-- Screen rectangle (left, bottom, width, height) in screen units, or nil when unanchored.
local function resolve(o)
	local s = o[0]
	if s.rgen == H.gen then return s.rl, s.rb, s.rw, s.rh end
	if s.resolving then
		s.resolving = nil
		error("anchor cycle through " .. debugname(o), 0)
	end
	s.resolving = true
	local es = effscale(o)
	local w, h = s.width and s.width * es, s.height and s.height * es
	local l, b

	if s.thumbOf then
		-- a slider's thumb texture is placed by the engine according to the value
		local sl, sb, sw, sh = resolve(s.thumbOf)
		local so = s.thumbOf[0]
		if sl then
			w, h = w or 16 * es, h or 16 * es
			local span = (so.max or 0) - (so.min or 0)
			local pct = span > 0 and ((so.value or so.min or 0) - so.min) / span or 0
			if so.orientation == "VERTICAL" or so.orientation == nil then
				l, b = sl + (sw - w) / 2, sb + sh - h - pct * (sh - h)
			else
				l, b = sl + pct * (sw - w), sb + (sh - h) / 2
			end
		end
	elseif s.barOf then
		-- a status bar's texture is stretched by the engine to the filled part
		local sl, sb, sw, sh = resolve(s.barOf)
		local so = s.barOf[0]
		if sl then
			local min, max, value = so.min or 0, so.max or 1, so.value or 0
			local pct = max > min and math.max(0, math.min(1, (value - min) / (max - min))) or 0
			l, b, w, h = sl, sb, sw * pct, sh
			if so.orientation == "VERTICAL" then w, h = sw, sh * pct end
		end
	elseif s.scrollOwner then
		-- a scroll child sits at its scroll frame's top-left, shifted by the scroll offsets
		local ol, ob, _, oh = resolve(s.scrollOwner)
		if ol then
			local so = s.scrollOwner[0]
			w, h = w or 0, h or 0
			l, b = ol - (so.hscroll or 0) * es, ob + oh + (so.vscroll or 0) * es - h
		end
	else
		local L, R, CX, T, B, CY
		local anchored = #s.points > 0
		for _, p in ipairs(s.points) do
			local rl, rb, rw, rh
			if p.rel == SCREEN then
				rl, rb, rw, rh = 0, 0, H.screenWidth, H.screenHeight
			else
				rl, rb, rw, rh = resolve(p.rel)
			end
			if not rl then anchored = false break end
			local f = POINTS[p.relPoint]
			local ax, ay = rl + rw * f[1] + p.x * es, rb + rh * f[2] + p.y * es
			local me = POINTS[p.point]
			if me[1] == 0 then L = ax elseif me[1] == 1 then R = ax else CX = ax end
			if me[2] == 0 then B = ay elseif me[2] == 1 then T = ay else CY = ay end
		end
		if anchored then
			if L and R then w = R - L end
			if T and B then h = T - B end
			if naturalSize and (not w or not h) and s.type == "FontString" then
				local nw, nh = naturalSize(o, w and w / es)
				w, h = w or nw * es, h or nh * es
			end
			w, h = w or 0, h or 0
			l = L or (R and R - w) or (CX and CX - w / 2)
			b = B or (T and T - h) or (CY and CY - h / 2)
			if not l or not b then
				-- anchored on one axis only (e.g. just TOP): centre the other axis on the anchor
				l, b = l or 0, b or 0
			end
		end
	end

	s.resolving = nil
	s.rgen = H.gen
	if l then
		s.rl, s.rb, s.rw, s.rh = l, b, math.max(w, 0), math.max(h, 0)
	else
		s.rl, s.rb, s.rw, s.rh = nil, nil, nil, nil
	end
	return s.rl, s.rb, s.rw, s.rh
end
H.resolve = resolve

function Region:GetWidth()
	local _, _, w = resolve(self)
	return w and w / effscale(self) or self[0].width or 0
end
function Region:GetHeight()
	local _, _, _, h = resolve(self)
	return h and h / effscale(self) or self[0].height or 0
end
function Region:GetSize() return self:GetWidth(), self:GetHeight() end
function Region:GetRect()
	local l, b, w, h = resolve(self)
	if not l then return nil end
	local es = effscale(self)
	return l / es, b / es, w / es, h / es
end
function Region:GetLeft() return (self:GetRect()) end
function Region:GetBottom() return (select(2, self:GetRect())) end
function Region:GetRight()
	local l, _, w = self:GetRect()
	return l and l + w
end
function Region:GetTop()
	local _, b, _, h = self:GetRect()
	return b and b + h
end
function Region:GetCenter()
	local l, b, w, h = self:GetRect()
	if l then return l + w / 2, b + h / 2 end
end
function Region:IsRectValid() return (resolve(self)) ~= nil end

function Region:IsMouseOver()
	local l, b, w, h = resolve(self)
	return l ~= nil and H.mouseX >= l and H.mouseX <= l + w and H.mouseY >= b and H.mouseY <= b + h
end

function Region:EnableMouse(v) self[0].mouse = v ~= false end
function Region:IsMouseEnabled() return self[0].mouse == true end
function Region:SetMouseClickEnabled(v) self[0].mouse = v ~= false end
function Region:SetMouseMotionEnabled(v) self[0].mouseMotion = v ~= false end
function Region:EnableMouseWheel(v) self[0].wheel = v ~= false end
function Region:IsMouseWheelEnabled() return self[0].wheel == true end
function Region:SetPassThroughButtons() end
function Region:SetPropagateMouseClicks() end
function Region:SetPropagateMouseMotion() end

function Region:SetParent(parent)
	if type(parent) == "string" then parent = _G[parent] end
	local s = self[0]
	local list = self:IsObjectType("Frame") and "children" or "regions"
	if s.parent then
		local siblings = s.parent[0][list]
		for i, o in ipairs(siblings) do
			if o == self then table.remove(siblings, i) break end
		end
	end
	s.parent = parent
	if parent then table.insert(parent[0][list], self) end
	dirty()
end

---------------------------------------------------------------------------------------------
-- LayeredRegion, Texture
---------------------------------------------------------------------------------------------

local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
H.LAYERS = LAYERS

function Layered:SetDrawLayer(layer, sub)
	if not LAYERS[layer] then error("SetDrawLayer: unknown layer " .. tostring(layer), 2) end
	self[0].layer, self[0].sublayer = layer, sub or 0
end
function Layered:GetDrawLayer() return self[0].layer, self[0].sublayer end
function Layered:SetVertexColor(r, g, b, a) self[0].vertex = { r, g, b, a or 1 } end
function Layered:GetVertexColor() return unpack(self[0].vertex or { 1, 1, 1, 1 }) end

function Texture:SetTexture(tex)
	local s = self[0]
	s.texture, s.color, s.atlas = tex, nil, nil
end
function Texture:GetTexture() return self[0].texture end
function Texture:SetColorTexture(r, g, b, a)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		error("SetColorTexture: r, g, b must be numbers", 2)
	end
	local s = self[0]
	s.color, s.texture, s.atlas = { r, g, b, a or 1 }, nil, nil
end
function Texture:SetAtlas(atlas, useAtlasSize)
	local s = self[0]
	s.atlas, s.texture, s.color = atlas, nil, nil
	-- shortcut: atlas sizes are unknown offline; a region sized only by its atlas gets 16x16
	if useAtlasSize and not s.width then s.width, s.height = 16, 16 dirty() end
end
function Texture:GetAtlas() return self[0].atlas end
function Texture:SetTexCoord(...) self[0].texCoord = { ... } end
function Texture:GetTexCoord() return unpack(self[0].texCoord or { 0, 0, 0, 1, 1, 0, 1, 1 }) end
function Texture:SetBlendMode(mode) self[0].blend = mode end
function Texture:GetBlendMode() return self[0].blend or "BLEND" end
function Texture:SetDesaturated(v) self[0].desaturated = v end
function Texture:IsDesaturated() return self[0].desaturated == true end
function Texture:SetRotation(r) self[0].rotation = r end
function Texture:SetGradient(orientation, from, to) self[0].gradient = { orientation, from, to } end
function Texture:SetHorizTile(v) self[0].htile = v end
function Texture:SetVertTile(v) self[0].vtile = v end
function Texture:SetTexelSnappingBias() end
function Texture:SetSnapToPixelGrid() end
function Texture:AddMaskTexture() end
function Texture:SetMask() end

---------------------------------------------------------------------------------------------
-- Fonts and FontString
---------------------------------------------------------------------------------------------

local function fontState(o) return o[0].font end

local function setFontFrom(o, src)
	if type(src) == "string" then
		local name = src
		src = _G[name]
		if not src then error("unknown font object " .. name, 3) end
	end
	local f, of = fontState(src), fontState(o)
	of.file, of.size, of.flags, of.object = f.file, f.size, f.flags, src
	of.color = { unpack(f.color) }
	of.justifyH = f.justifyH
	dirty()
end

local FontMethods = {}
function FontMethods:SetFont(file, size, flags)
	if type(file) ~= "string" or type(size) ~= "number" then error("SetFont(file, size [, flags])", 2) end
	local f = fontState(self)
	f.file, f.size, f.flags = file, size, flags or ""
	dirty()
	return true
end
function FontMethods:GetFont()
	local f = fontState(self)
	return f.file, f.size, f.flags
end
function FontMethods:SetFontObject(font) setFontFrom(self, font) end
function FontMethods:GetFontObject() return fontState(self).object end
function FontMethods:SetTextColor(r, g, b, a) fontState(self).color = { r, g, b, a or 1 } end
function FontMethods:GetTextColor() return unpack(fontState(self).color) end
function FontMethods:SetJustifyH(j) fontState(self).justifyH = j end
function FontMethods:GetJustifyH() return fontState(self).justifyH or (self[0].type == "EditBox" and "LEFT" or "CENTER") end
function FontMethods:SetJustifyV(j) fontState(self).justifyV = j end
function FontMethods:GetJustifyV() return fontState(self).justifyV or "MIDDLE" end
function FontMethods:SetShadowOffset(x, y) fontState(self).shadow = { x, y } end
function FontMethods:SetShadowColor() end
function FontMethods:SetSpacing(v) fontState(self).spacing = v; dirty() end
function FontMethods:GetSpacing() return fontState(self).spacing or 0 end
function FontMethods:SetTextScale() end

for k, v in pairs(FontMethods) do
	FontObject[k], FontString[k], EditBox[k] = v, v, v
end
function FontObject:CopyFontObject(src) setFontFrom(self, src) end

local function newFontState()
	return { file = "Fonts\\FRIZQT__.TTF", size = 12, flags = "", color = { 1, 1, 1, 1 } }
end

function H.CreateFont(name)
	if _G[name] then return _G[name] end
	local o = new(FontObject, name)
	o[0].font = newFontState()
	rawset(_G, name, o)
	return o
end

-- Text measurement. Real glyph metrics are not available offline; widths are an estimate
-- (about right for Friz Quadrata), good enough to catch overflow, not for pixel work.
local NARROW, WIDE = "[iIl%.,:;'!|%s%[%]%(%)tfjr]", "[mwMWAGOQ%%@]"
local function plain(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "\1")
		:gsub("|A.-|a", "\1"):gsub("|H.-|h", ""):gsub("|h", ""):gsub("|n", "\n"):gsub("||", "|"))
end
H.plain = plain

local function textWidth(text, size)
	local w = 0
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if ch == "\1" then w = w + 1 -- inline texture: one em
		elseif #ch > 1 then w = w + 0.6
		elseif ch:match(NARROW) then w = w + 0.3
		elseif ch:match(WIDE) then w = w + 0.72
		elseif ch:match("%u") then w = w + 0.62
		else w = w + 0.5 end
	end
	return w * size
end
H.textWidth = textWidth

-- Break text into lines no wider than maxWidth (nil: only explicit newlines).
local function wrap(text, size, maxWidth)
	local lines = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		if not maxWidth or textWidth(para, size) <= maxWidth then
			lines[#lines + 1] = para
		else
			local line = ""
			for word in para:gmatch("%S+") do
				local try = line == "" and word or (line .. " " .. word)
				if line ~= "" and textWidth(try, size) > maxWidth then
					lines[#lines + 1] = line
					line = word
				else
					line = try
				end
			end
			lines[#lines + 1] = line
		end
	end
	return lines
end

local function fsLines(o, boxWidth)
	local s = o[0]
	local text = plain(s.text or "")
	local lines = wrap(text, s.font.size, (s.wordWrap ~= false) and boxWidth or nil)
	if s.maxLines and s.maxLines > 0 then
		while #lines > s.maxLines do table.remove(lines) end
	end
	return lines
end

-- The text as the emulator laid it out: raw text (colour codes kept) with its line breaks.
function H.TextLines(o)
	local s = o[0]
	local raw = tostring(s.text or ""):gsub("|n", "\n")
	local boxWidth = (s.wordWrap ~= false) and o:GetWidth() > 0 and o:GetWidth() or nil
	local lines = {}
	for para in (raw .. "\n"):gmatch("(.-)\n") do
		if not boxWidth or textWidth(plain(para), s.font.size) <= boxWidth then
			lines[#lines + 1] = para
		else
			local line = ""
			for word in para:gmatch("%S+") do
				local try = line == "" and word or (line .. " " .. word)
				if line ~= "" and textWidth(plain(try), s.font.size) > boxWidth then
					lines[#lines + 1] = line
					line = word
				else
					line = try
				end
			end
			lines[#lines + 1] = line
		end
	end
	return lines
end

naturalSize = function(o, boxWidth)
	local s = o[0]
	if not s.text or s.text == "" then return 0, s.font.size end
	local lines, w = fsLines(o, boxWidth), 0
	for _, line in ipairs(lines) do w = math.max(w, textWidth(line, s.font.size)) end
	return w, #lines * s.font.size + (#lines - 1) * (s.font.spacing or 0)
end

function FontString:SetText(text)
	local s = self[0]
	-- a secret is displayed normally but taints the getter (the "Text" secret aspect)
	if H.IsSecret(text) then s.secretText, text = true, H.Reveal(text) end
	s.text = text ~= nil and tostring(text) or nil
	dirty()
end
function FontString:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
function FontString:GetText()
	local s = self[0]
	if s.secretText then return H.Secret(s.text) end
	return s.text
end
function FontString:GetStringWidth() return (naturalSize(self, self[0].width)) end
function FontString:GetUnboundedStringWidth() return textWidth(plain(self[0].text or ""), self[0].font.size) end
function FontString:GetWrappedWidth() return self:GetStringWidth() end
function FontString:GetStringHeight()
	local _, h = naturalSize(self, self:GetWidth() > 0 and self:GetWidth() or nil)
	return h
end
function FontString:GetLineHeight() return self[0].font.size end
function FontString:GetNumLines() return #fsLines(self, self:GetWidth() > 0 and self:GetWidth() or nil) end
function FontString:SetWordWrap(v) self[0].wordWrap = v; dirty() end
function FontString:CanWordWrap() return self[0].wordWrap ~= false end
function FontString:SetNonSpaceWrap() end
function FontString:SetMaxLines(n) self[0].maxLines = n; dirty() end
function FontString:GetMaxLines() return self[0].maxLines or 0 end
function FontString:SetIndentedWordWrap() end
function FontString:SetRotation() end
function FontString:IsTruncated()
	local w = self:GetWidth()
	return w > 0 and self:GetUnboundedStringWidth() > w + 0.5 and (self[0].wordWrap == false or self[0].maxLines == 1)
end

---------------------------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------------------------

local STRATA = {
	WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
	FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
H.STRATA = STRATA

local function newRegion(parent, c, name, layer, inherits)
	if name and name ~= "" then name = name:gsub("%$parent", parent[0].name or "") else name = nil end
	local o = new(c, name, parent)
	o[0].layer, o[0].sublayer = layer or "ARTWORK", 0
	if layer and not LAYERS[layer] then error("unknown draw layer " .. tostring(layer), 3) end
	table.insert(parent[0].regions, o)
	if name then rawset(_G, name, o) end
	return o
end

function Frame:CreateTexture(name, layer, inherits, sublevel)
	local t = newRegion(self, Texture, name, layer)
	t[0].sublayer = sublevel or 0
	return t
end
function Frame:CreateMaskTexture(name, layer) return newRegion(self, Texture, name, layer) end
function Frame:CreateFontString(name, layer, inherits)
	local fs = newRegion(self, FontString, name, layer)
	fs[0].font = newFontState()
	setFontFrom(fs, inherits or "GameFontNormal")
	if inherits == nil then fs[0].font.object = nil end
	return fs
end

function Frame:GetChildren() return unpack(self[0].children) end
function Frame:GetNumChildren() return #self[0].children end
function Frame:GetRegions() return unpack(self[0].regions) end
function Frame:GetNumRegions() return #self[0].regions end

function Frame:RegisterEvent(event)
	if type(event) ~= "string" then error("RegisterEvent(event)", 2) end
	if H.validEvents and not H.validEvents[event] then
		error(('Attempt to register unknown event "%s"'):format(event), 2)
	end
	H.events[event] = H.events[event] or {}
	H.events[event][self] = true
	return true
end
function Frame:RegisterUnitEvent(event, ...)
	self:RegisterEvent(event)
	self[0].unitEvents = self[0].unitEvents or {}
	self[0].unitEvents[event] = { ... }
end
function Frame:UnregisterEvent(event)
	if H.events[event] then H.events[event][self] = nil end
end
function Frame:UnregisterAllEvents()
	for _, frames in pairs(H.events) do frames[self] = nil end
end
function Frame:IsEventRegistered(event) return H.events[event] ~= nil and H.events[event][self] == true end

function Frame:SetFrameStrata(strata)
	if not STRATA[strata] then error("SetFrameStrata: unknown strata " .. tostring(strata), 2) end
	self[0].strata = strata
end
function Frame:GetFrameStrata()
	local o = self
	while o do
		if o[0].strata then return o[0].strata end
		o = o[0].parent
	end
	return "MEDIUM"
end
function Frame:SetFixedFrameStrata() end
function Frame:SetFixedFrameLevel() end
function Frame:SetFrameLevel(level) self[0].level = level end
function Frame:GetFrameLevel()
	local s = self[0]
	if s.level then return s.level end
	return s.parent and s.parent:GetFrameLevel() + 1 or 0
end
function Frame:Raise() H.serial = H.serial + 1; self[0].raised = H.serial end
function Frame:Lower() self[0].raised = nil end
function Frame:SetToplevel(v) self[0].toplevel = v end
function Frame:IsToplevel() return self[0].toplevel == true end

function Frame:SetMovable(v) self[0].movable = v ~= false end
function Frame:IsMovable() return self[0].movable == true end
function Frame:SetResizable(v) self[0].resizable = v ~= false end
function Frame:IsResizable() return self[0].resizable == true end
function Frame:SetResizeBounds(minW, minH, maxW, maxH) self[0].bounds = { minW, minH, maxW, maxH } end
function Frame:GetResizeBounds() return unpack(self[0].bounds or { 0, 0, 0, 0 }) end
function Frame:SetClampedToScreen(v) self[0].clamped = v end
function Frame:IsClampedToScreen() return self[0].clamped == true end
function Frame:SetClampRectInsets() end
function Frame:SetUserPlaced(v) self[0].userPlaced = v end
function Frame:IsUserPlaced() return self[0].userPlaced == true end
function Frame:SetDontSavePosition() end
function Frame:RegisterForDrag(...) self[0].drag = { ... } end
function Frame:StartMoving()
	if not self[0].movable then error("StartMoving: frame is not movable", 2) end
	H.moving = { frame = self, mode = "move" }
end
function Frame:StartSizing(point)
	if not self[0].resizable then error("StartSizing: frame is not resizable", 2) end
	H.moving = { frame = self, mode = "size", point = point or "BOTTOMRIGHT" }
end
function Frame:StopMovingOrSizing()
	if H.moving and H.moving.frame == self then H.moving = nil end
end

function Frame:EnableKeyboard(v) self[0].keyboard = v ~= false end
function Frame:IsKeyboardEnabled() return self[0].keyboard == true end
function Frame:SetPropagateKeyboardInput(v) self[0].propagateKeys = v end
function Frame:SetID(id) self[0].id = id end
function Frame:GetID() return self[0].id or 0 end
function Frame:SetAttribute(k, v)
	self[0].attributes = self[0].attributes or {}
	self[0].attributes[k] = v
	run(self, "OnAttributeChanged", k, v)
end
function Frame:GetAttribute(k) return self[0].attributes and self[0].attributes[k] end
function Frame:SetClipsChildren(v) self[0].clips = v end
function Frame:DoesClipChildren() return self[0].clips == true end
function Frame:SetHitRectInsets(l, r, t, b) self[0].hitInsets = { l, r, t, b } end
function Frame:SetFlattensRenderLayers() end
function Frame:SetIsFrameBuffer() end

-- Animations are not simulated frame by frame: Play() finishes after the group's duration on
-- the virtual clock and fires OnFinished, which is what fade-out code depends on.
local Anim = {}
Anim.__index = function(t, k)
	return Anim[k] or function() end -- setters such as SetFromAlpha, SetOffset, SetSmoothing
end
function Anim:SetDuration(d) self.duration = d end
function Anim:SetStartDelay(d) self.delay = d end
function Anim:SetScript(script, fn) self.scripts = self.scripts or {}; self.scripts[script] = fn end
local AnimGroup = {}
AnimGroup.__index = AnimGroup
function AnimGroup:CreateAnimation(kind)
	local a = setmetatable({ kind = kind, duration = 0, delay = 0 }, Anim)
	self.anims[#self.anims + 1] = a
	return a
end
function AnimGroup:SetScript(script, fn) self.scripts[script] = fn end
function AnimGroup:SetLooping(mode) self.looping = mode end
function AnimGroup:SetToFinalAlpha() end
function AnimGroup:IsPlaying() return self.playing == true end
function AnimGroup:Play()
	local total = 0
	for _, a in ipairs(self.anims) do total = math.max(total, a.delay + a.duration) end
	self.playing = true
	self.token = {}
	local token = self.token
	if self.scripts.OnPlay then self.scripts.OnPlay(self) end
	if self.looping and self.looping ~= "NONE" then return end
	H.After(total, function()
		if self.token ~= token then return end
		self.playing = false
		if self.scripts.OnFinished then self.scripts.OnFinished(self) end
	end)
end
function AnimGroup:Stop()
	self.playing, self.token = false, nil
	if self.scripts.OnStop then self.scripts.OnStop(self) end
end
AnimGroup.Finish, AnimGroup.Pause, AnimGroup.Restart = AnimGroup.Stop, AnimGroup.Stop, AnimGroup.Play
function Frame:CreateAnimationGroup()
	return setmetatable({ anims = {}, scripts = {}, parent = self }, AnimGroup)
end
Texture.CreateAnimationGroup, FontString.CreateAnimationGroup = Frame.CreateAnimationGroup, Frame.CreateAnimationGroup

-- BackdropTemplate
local Backdrop = {}
function Backdrop:SetBackdrop(info)
	if info ~= nil and type(info) ~= "table" then error("SetBackdrop(table or nil)", 2) end
	self[0].backdrop = info
	self[0].backdropColor = self[0].backdropColor or { 1, 1, 1, 1 }
	self[0].backdropBorderColor = self[0].backdropBorderColor or { 1, 1, 1, 1 }
end
function Backdrop:GetBackdrop() return self[0].backdrop end
function Backdrop:ClearBackdrop() self[0].backdrop = nil end
function Backdrop:ApplyBackdrop() end
function Backdrop:SetBackdropColor(r, g, b, a) self[0].backdropColor = { r, g, b, a or 1 } end
function Backdrop:GetBackdropColor() return unpack(self[0].backdropColor or { 1, 1, 1, 1 }) end
function Backdrop:SetBackdropBorderColor(r, g, b, a) self[0].backdropBorderColor = { r, g, b, a or 1 } end
function Backdrop:GetBackdropBorderColor() return unpack(self[0].backdropBorderColor or { 1, 1, 1, 1 }) end

---------------------------------------------------------------------------------------------
-- Button, CheckButton
---------------------------------------------------------------------------------------------

function Button:SetEnabled(v)
	v = not not v
	local s = self[0]
	if (s.disabled ~= true) == v then return end
	s.disabled = not v
	run(self, v and "OnEnable" or "OnDisable")
end
function Button:Enable() self:SetEnabled(true) end
function Button:Disable() self:SetEnabled(false) end
function Button:IsEnabled() return self[0].disabled ~= true end
function Button:RegisterForClicks(...) self[0].clicks = { ... } end
function Button:SetMotionScriptsWhileDisabled(v) self[0].motionWhileDisabled = v end
function Button:SetButtonState(state, locked) self[0].buttonState = state end
function Button:GetButtonState() return self[0].buttonState or (self[0].disabled and "DISABLED" or "NORMAL") end
function Button:LockHighlight() self[0].highlightLocked = true end
function Button:UnlockHighlight() self[0].highlightLocked = nil end
function Button:SetPushedTextOffset() end

function Button:GetFontString() return self[0].fontString end
function Button:SetFontString(fs) self[0].fontString = fs end
function Button:SetText(text)
	local s = self[0]
	if not s.fontString then
		s.fontString = self:CreateFontString(nil, "ARTWORK", s.normalFont or "GameFontNormal")
		s.fontString:SetPoint("CENTER")
	end
	s.fontString:SetText(text)
end
function Button:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
function Button:GetText() return self[0].fontString and self[0].fontString:GetText() end
function Button:GetTextWidth() return self[0].fontString and self[0].fontString:GetStringWidth() or 0 end
function Button:GetTextHeight() return self[0].fontString and self[0].fontString:GetStringHeight() or 0 end
function Button:SetNormalFontObject(font)
	self[0].normalFont = font
	if self[0].fontString then self[0].fontString:SetFontObject(font) end
end
function Button:SetHighlightFontObject(font) self[0].highlightFont = font end
function Button:SetDisabledFontObject(font) self[0].disabledFont = font end
function Button:GetNormalFontObject() return self[0].normalFont end

for _, kind in ipairs({ "Normal", "Pushed", "Highlight", "Disabled", "Checked", "DisabledChecked" }) do
	local key = kind:lower() .. "Texture"
	local owner = (kind == "Checked" or kind == "DisabledChecked") and CheckButton or Button
	owner["Set" .. kind .. "Texture"] = function(self, tex)
		if type(tex) == "table" then
			self[0][key] = tex
		else
			local t = self[0][key] or self:CreateTexture(nil, kind == "Highlight" and "HIGHLIGHT" or "ARTWORK")
			t:SetTexture(tex)
			if t:GetNumPoints() == 0 then t:SetAllPoints(self) end
			self[0][key] = t
		end
	end
	owner["Get" .. kind .. "Texture"] = function(self) return self[0][key] end
	owner["Set" .. kind .. "Atlas"] = function(self, atlas)
		owner["Set" .. kind .. "Texture"](self, "")
		self[0][key]:SetAtlas(atlas)
	end
end
function Button:ClearNormalTexture() self[0].normalTexture = nil end
function Button:ClearPushedTexture() self[0].pushedTexture = nil end
function Button:ClearHighlightTexture() self[0].highlightTexture = nil end
function Button:ClearDisabledTexture() self[0].disabledTexture = nil end

-- Programmatic click, as Button:Click() in the client: runs the handlers even when hidden.
function Button:Click(button, down)
	if self[0].disabled then return end
	button = button or "LeftButton"
	run(self, "PreClick", button, down or false)
	if self:IsObjectType("CheckButton") then self[0].checked = not self[0].checked end
	run(self, "OnClick", button, down or false)
	run(self, "PostClick", button, down or false)
end

function CheckButton:SetChecked(v) self[0].checked = not not v end
function CheckButton:GetChecked() return self[0].checked == true end

---------------------------------------------------------------------------------------------
-- Slider, StatusBar
---------------------------------------------------------------------------------------------

local function snap(s, v)
	if s.step and s.step > 0 then v = s.min + math.floor((v - s.min) / s.step + 0.5) * s.step end
	return math.max(s.min, math.min(s.max, v))
end

function Slider:SetMinMaxValues(min, max)
	if type(min) ~= "number" or type(max) ~= "number" then error("SetMinMaxValues(min, max)", 2) end
	if min > max then error("SetMinMaxValues: min must be <= max", 2) end
	local s = self[0]
	s.min, s.max = min, max
	run(self, "OnMinMaxChanged", min, max)
	if s.value then self:SetValue(s.value) end
end
function Slider:GetMinMaxValues() return self[0].min or 0, self[0].max or 0 end
function Slider:SetValueStep(step) self[0].step = step end
function Slider:GetValueStep() return self[0].step or 0 end
function Slider:SetObeyStepOnDrag(v) self[0].obeyStep = v end
function Slider:GetObeyStepOnDrag() return self[0].obeyStep == true end
function Slider:SetStepsPerPage(n) self[0].stepsPerPage = n end
function Slider:GetStepsPerPage() return self[0].stepsPerPage or 0 end
function Slider:SetOrientation(o) self[0].orientation = o end
function Slider:GetOrientation() return self[0].orientation or "VERTICAL" end
function Slider:SetThumbTexture(tex)
	if type(tex) ~= "table" then
		local t = self:CreateTexture(nil, "OVERLAY")
		t:SetTexture(tex)
		t:SetSize(16, 16)
		tex = t
	end
	self[0].thumb = tex
	tex[0].thumbOf = self
	dirty()
end
function Slider:GetThumbTexture() return self[0].thumb end
-- userInput is true only for values that come from H.SetSliderByUser / drags.
function Slider:SetValue(value, treatAsMouseEvent)
	if type(value) ~= "number" then error("Slider:SetValue(number)", 2) end
	local s = self[0]
	s.min, s.max = s.min or 0, s.max or 0
	-- the client clamps but only snaps to the step on drags when ObeyStepOnDrag is set
	value = math.max(s.min, math.min(s.max, value))
	if treatAsMouseEvent and s.obeyStep then value = snap(s, value) end
	if s.value == value then return end
	s.value = value
	dirty()
	run(self, "OnValueChanged", value, treatAsMouseEvent == true)
end
function Slider:GetValue() return self[0].value or self[0].min or 0 end
function Slider:SetEnabled(v) self[0].disabled = not v end
function Slider:Enable() self[0].disabled = nil end
function Slider:Disable() self[0].disabled = true end
function Slider:IsEnabled() return self[0].disabled ~= true end
H.snap = snap

function StatusBar:SetMinMaxValues(min, max)
	local s = self[0]
	if H.IsSecret(min) or H.IsSecret(max) then s.secretValue = true end
	s.min, s.max = H.Reveal(min), H.Reveal(max)
end
function StatusBar:GetMinMaxValues()
	local s = self[0]
	if s.secretValue then return H.Secret(s.min), H.Secret(s.max) end
	return s.min or 0, s.max or 1
end
function StatusBar:SetValue(v)
	local s = self[0]
	if H.IsSecret(v) then s.secretValue = true end
	s.value = H.Reveal(v)
	dirty()
	if not s.secretValue then run(self, "OnValueChanged", v) end
end
function StatusBar:GetValue()
	local s = self[0]
	if s.secretValue then return H.Secret(s.value) end
	return s.value or 0
end
function StatusBar:SetStatusBarTexture(tex)
	if type(tex) ~= "table" then
		local t = self[0].barTexture or self:CreateTexture(nil, "ARTWORK")
		t:SetTexture(tex)
		tex = t
	end
	self[0].barTexture = tex
	tex[0].barOf = self
	dirty()
end
function StatusBar:GetStatusBarTexture() return self[0].barTexture end
function StatusBar:SetStatusBarColor(r, g, b, a) self[0].barColor = { r, g, b, a or 1 } end
function StatusBar:GetStatusBarColor() return unpack(self[0].barColor or { 1, 1, 1, 1 }) end
function StatusBar:SetOrientation(o) self[0].orientation = o end
function StatusBar:SetReverseFill(v) self[0].reverse = v end
function StatusBar:SetFillStyle(v) self[0].fillStyle = v end
function StatusBar:SetRotatesTexture() end
function StatusBar:SetTimerDuration(duration) self[0].timerDuration = duration end

---------------------------------------------------------------------------------------------
-- EditBox
---------------------------------------------------------------------------------------------

function EditBox:SetText(text)
	local s = self[0]
	text = tostring(text or "")
	if s.maxLetters and s.maxLetters > 0 then text = text:sub(1, s.maxLetters) end
	local changed = s.text ~= text
	s.text, s.cursor = text, #text
	dirty()
	run(self, "OnTextSet")
	if changed then run(self, "OnTextChanged", false) end
end
function EditBox:GetText() return self[0].text or "" end
function EditBox:GetDisplayText() return self[0].text or "" end
function EditBox:GetNumLetters() return #(self[0].text or "") end
function EditBox:SetNumeric(v) self[0].numeric = v end
function EditBox:IsNumeric() return self[0].numeric == true end
function EditBox:GetNumber() return tonumber(self[0].text) or 0 end
function EditBox:SetNumber(n) self:SetText(tostring(n)) end
function EditBox:SetMaxLetters(n) self[0].maxLetters = n end
function EditBox:GetMaxLetters() return self[0].maxLetters or 0 end
function EditBox:SetMaxBytes() end
function EditBox:SetMultiLine(v) self[0].multiLine = v end
function EditBox:IsMultiLine() return self[0].multiLine == true end
function EditBox:SetAutoFocus(v) self[0].autoFocus = v end
function EditBox:SetCursorPosition(p) self[0].cursor = p end
function EditBox:GetCursorPosition() return self[0].cursor or 0 end
function EditBox:HighlightText(from, to) self[0].highlight = { from or 0, to or -1 } end
function EditBox:ClearHighlightText() self[0].highlight = nil end
function EditBox:Insert(text) self:SetText(self:GetText() .. text) end
function EditBox:SetTextInsets(l, r, t, b) self[0].insets = { l, r, t, b } end
function EditBox:GetTextInsets() return unpack(self[0].insets or { 0, 0, 0, 0 }) end
function EditBox:SetPassword(v) self[0].password = v end
function EditBox:SetCountInvisibleLetters() end
function EditBox:SetHistoryLines() end
function EditBox:AddHistoryLine() end
function EditBox:SetAltArrowKeyMode() end
function EditBox:SetBlinkSpeed() end
function EditBox:SetEnabled(v) self[0].disabled = not v; if not v then self:ClearFocus() end end
function EditBox:Enable() self:SetEnabled(true) end
function EditBox:Disable() self:SetEnabled(false) end
function EditBox:IsEnabled() return self[0].disabled ~= true end
function EditBox:HasFocus() return H.focus == self end
function EditBox:SetFocus()
	if H.focus == self or self[0].disabled then return end
	if H.focus then H.focus:ClearFocus() end
	H.focus = self
	run(self, "OnEditFocusGained")
end
function EditBox:ClearFocus()
	if H.focus ~= self then return end
	H.focus = nil
	run(self, "OnEditFocusLost")
end

---------------------------------------------------------------------------------------------
-- ScrollFrame
---------------------------------------------------------------------------------------------

function ScrollFrame:SetScrollChild(child)
	local s = self[0]
	if s.scrollChild then s.scrollChild[0].scrollOwner = nil end
	s.scrollChild = child
	if child then
		child:SetParent(self)
		child[0].scrollOwner = self
	end
	dirty()
end
function ScrollFrame:GetScrollChild() return self[0].scrollChild end
function ScrollFrame:UpdateScrollChildRect() end
function ScrollFrame:GetVerticalScrollRange()
	local child = self[0].scrollChild
	return child and math.max(0, child:GetHeight() - self:GetHeight()) or 0
end
function ScrollFrame:GetHorizontalScrollRange()
	local child = self[0].scrollChild
	return child and math.max(0, child:GetWidth() - self:GetWidth()) or 0
end
function ScrollFrame:SetVerticalScroll(v)
	if self[0].vscroll == v then return end
	self[0].vscroll = v
	dirty()
	run(self, "OnVerticalScroll", v)
end
function ScrollFrame:GetVerticalScroll() return self[0].vscroll or 0 end
function ScrollFrame:SetHorizontalScroll(v)
	self[0].hscroll = v
	dirty()
	run(self, "OnHorizontalScroll", v)
end
function ScrollFrame:GetHorizontalScroll() return self[0].hscroll or 0 end

---------------------------------------------------------------------------------------------
-- GameTooltip, Cooldown
---------------------------------------------------------------------------------------------

function GameTooltip:SetOwner(owner, anchor, x, y)
	if type(owner) ~= "table" or not owner[0] then error("GameTooltip:SetOwner(owner, anchor)", 2) end
	local s = self[0]
	s.owner, s.anchor, s.lines = owner, anchor or "ANCHOR_TOPRIGHT", {}
	self:ClearAllPoints()
	if anchor ~= "ANCHOR_NONE" then self:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", x or 0, y or 0) end
	run(self, "OnTooltipCleared")
end
function GameTooltip:GetOwner() return self[0].owner end
function GameTooltip:IsOwned(owner) return self[0].owner == owner end
function GameTooltip:SetAnchorType(anchor) self[0].anchor = anchor end
function GameTooltip:ClearLines() self[0].lines = {} end
function GameTooltip:NumLines() return #(self[0].lines or {}) end
local function addLine(self, left, right, r, g, b, wrapText)
	local s = self[0]
	s.lines = s.lines or {}
	s.lines[#s.lines + 1] = { left = left, right = right, color = { r or 1, g or 0.82, b or 0 }, wrap = wrapText }
	local w = 0
	for _, line in ipairs(s.lines) do
		w = math.max(w, textWidth(plain(tostring(line.left or "")) .. "  " .. plain(tostring(line.right or "")), 12))
	end
	self:SetSize(math.max(s.minWidth or 0, w + 20), #s.lines * 14 + 16)
end
function GameTooltip:AddLine(text, r, g, b, wrapText) addLine(self, text, nil, r, g, b, wrapText) end
function GameTooltip:AddDoubleLine(left, right, r, g, b) addLine(self, left, right, r, g, b) end
function GameTooltip:SetText(text, r, g, b, a, wrapText)
	self[0].lines = {}
	addLine(self, text, nil, r, g, b, wrapText)
	self:Show()
end
function GameTooltip:AddTexture() end
function GameTooltip:SetMinimumWidth(w) self[0].minWidth = w end
function GameTooltip:SetPadding() end
function GameTooltip:SetHyperlink(link)
	self[0].lines = {}
	addLine(self, H.LinkName and H.LinkName(link) or link, nil, 1, 1, 1)
	self:Show()
end
function GameTooltip:SetItemByID(id) self:SetHyperlink("item:" .. id) end
function GameTooltip:SetSpellByID(id) self:SetHyperlink("spell:" .. id) end
function GameTooltip:SetBagItem(bag, slot) self:SetHyperlink(("bag:%d:%d"):format(bag, slot)) end
function GameTooltip:SetUnit(unit) self:SetHyperlink("unit:" .. unit) end
function GameTooltip:GetItem() end
function GameTooltip:FadeOut() self:Hide() end

function Cooldown:SetCooldown(start, duration) self[0].cooldown = { start, duration } end
function Cooldown:SetCooldownFromExpirationTime(expiration, duration) self[0].cooldown = { expiration - duration, duration } end
function Cooldown:GetCooldownTimes() return unpack(self[0].cooldown or { 0, 0 }) end
function Cooldown:Clear() self[0].cooldown = nil end
for _, m in ipairs({ "SetDrawEdge", "SetDrawSwipe", "SetDrawBling", "SetSwipeColor", "SetReverse", "SetHideCountdownNumbers", "SetSwipeTexture", "SetUseCircularEdge" }) do
	Cooldown[m] = function() end
end

---------------------------------------------------------------------------------------------
-- CreateFrame
---------------------------------------------------------------------------------------------

local FRAME_TYPES = {
	Frame = Frame, Button = Button, CheckButton = CheckButton, Slider = Slider, StatusBar = StatusBar,
	EditBox = EditBox, ScrollFrame = ScrollFrame, GameTooltip = GameTooltip, Cooldown = Cooldown,
	EventFrame = Frame,
}

local TEMPLATES = {
	BackdropTemplate = function(f)
		for k, v in pairs(Backdrop) do f[k] = v end
	end,
	GameTooltipTemplate = function() end,
	SecureHandlerBaseTemplate = function() end,
}
H.TEMPLATES = TEMPLATES

function H.CreateFrame(frameType, name, parent, template, id)
	local c = FRAME_TYPES[frameType]
	if not c then
		-- the client accepts type names case-insensitively
		for k, v in pairs(FRAME_TYPES) do
			if type(frameType) == "string" and k:lower() == frameType:lower() then c = v end
		end
	end
	if not c then error(("CreateFrame: frame type %q is not emulated"):format(tostring(frameType)), 2) end
	if type(parent) == "string" then parent = _G[parent] end
	if parent ~= nil and (type(parent) ~= "table" or not parent[0]) then error("CreateFrame: parent is not a frame", 2) end
	if name and parent then name = name:gsub("%$parent", parent[0].name or "") end
	local f = new(c, name, parent)
	if frameType == "EditBox" then
		f[0].font, f[0].text, f[0].autoFocus = newFontState(), "", true
	end
	if frameType == "GameTooltip" then f[0].shown, f[0].lines = false, {} end
	if c == Button or c == CheckButton or c == EditBox or c == Slider then f[0].mouse = true end
	if parent then table.insert(parent[0].children, f) end
	for t in (template or ""):gmatch("[^,%s]+") do
		local apply = TEMPLATES[t]
		if not apply then
			error(("CreateFrame: template %q is not emulated. ForeverKit builds widgets from primitives; "
				.. "Blizzard templates other than BackdropTemplate are not available offline."):format(t), 2)
		end
		apply(f)
	end
	if id then f[0].id = id end
	if name then rawset(_G, name, f) end
	H.frames[#H.frames + 1] = f
	dirty()
	return f
end

H.classes = classes
return H
