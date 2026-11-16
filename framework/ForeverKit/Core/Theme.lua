local _, ns = ...
local FK = ns.FK

-- Themes are token tables. Widgets never hard-code a colour, font, texture or size: they ask
-- the current theme. Switching theme re-skins every live widget.
--
--   FK.Theme.Register("mine", { extends = "pixel", color = { accent = { 0.2, 0.8, 0.4 } } })
--   FK.Theme:Set("mine")
--
-- Token groups (see Themes/Base.lua for every key):
--   color    named colours { r, g, b [, a] }
--   font     roles -> { "BlizzardFontObject", delta = sizeChange, flags = "OUTLINE", color = "role", shadow = false }
--   surface  how a part is painted, per state where the part has states
--   icon     small glyphs: { texture = path, coords = {...} } or { text = "x" }
--   metric   sizes and spacing in UI units
--
-- A surface spec is one of:
--   { bg = color }                          flat fill
--   { bg = color, border = color, edge = 1 } flat fill with a crisp border of `edge` pixels
--   { backdrop = <Blizzard backdrop table>, bg = color, border = color }
--   { texture = path, coords = { l, r, t, b }, color = color, blend = "ADD" }
--   { atlas = name, color = color }

local Theme = { themes = {}, live = setmetatable({}, { __mode = "k" }), fontDelta = 0, opacity = 1 }
FK.Theme = Theme

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- A value that replaces rather than merges: a colour/coords/font list, a backdrop, or a
-- surface/icon spec. Everything else is a group of named things and merges key by key.
local function isLeaf(v)
	return v[1] ~= nil or v.bgFile or v.bg or v.texture or v.atlas or v.backdrop or type(v.text) == "string" -- icon { text = "x" }; color.text is a colour
end

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and not isLeaf(v) and type(dst[k]) == "table" and not isLeaf(dst[k]) then
			merge(dst[k], v)
		else
			dst[k] = FK.Copy(v)
		end
	end
	return dst
end

function Theme.Register(name, def)
	local base = def.extends and Theme.themes[def.extends]
	if def.extends and not base then error("FK.Theme.Register: unknown base theme " .. tostring(def.extends), 2) end
	local theme = merge(base and FK.Copy(base) or {}, def)
	theme.name, theme.extends, theme.abstract = name, nil, def.abstract
	theme.label = def.label or name
	Theme.themes[name] = theme
	-- the first usable theme registered is the default
	if not Theme.current or Theme.current.abstract then Theme.current, Theme.name = theme, name end
end

function Theme:Names()
	local names = {}
	for name, t in pairs(self.themes) do
		if not t.abstract then names[#names + 1] = name end
	end
	table.sort(names)
	return names
end

function Theme:Set(name)
	local theme = self.themes[name] or error("FK.Theme:Set: unknown theme " .. tostring(name), 2)
	self.current, self.name = theme, name
	self:Refresh()
	FK:Emit("fk.theme", name)
end

-- Re-skins everything: after a theme change, or after fontDelta / opacity changed.
function Theme:Refresh()
	for widget in pairs(self.live) do widget:Restyle() end
end

function Theme.Track(widget) Theme.live[widget] = true end

function Theme.Color(role)
	local c = Theme.current.color[role] or error("FK.Theme: no colour named " .. tostring(role), 2)
	return c[1], c[2], c[3], c[4] or 1
end

function Theme.Font(fontString, role, colorRole)
	local T = Theme.current
	local spec = T.font[role] or error("FK.Theme: no font role " .. tostring(role), 2)
	-- a font object brings its own justification along: keep the one the widget chose
	local h, v = fontString:GetJustifyH(), fontString.GetJustifyV and fontString:GetJustifyV()
	fontString:SetFontObject(spec[1])
	fontString:SetJustifyH(h)
	if v then fontString:SetJustifyV(v) end
	local delta = (spec.delta or 0) + Theme.fontDelta
	if delta ~= 0 or spec.flags then
		-- the file comes from the locale's own font object, so CJK and Cyrillic keep working
		local file, size, flags = fontString:GetFont()
		fontString:SetFont(file, size + delta, spec.flags or flags)
	end
	fontString:SetTextColor(Theme.Color(colorRole or spec.color or "text"))
	-- set every time, so switching from a shadowless theme restores it; dark ink on light paper needs none
	fontString:SetShadowColor(0, 0, 0, spec.shadow == false and 0 or 1)
end

-- Paints `frame` (created with BackdropTemplate) according to a surface spec; nil clears it.
-- alphaScale multiplies the background alpha (window opacity setting).
function Theme.Paint(frame, spec, alphaScale)
	local tex = frame.fkFill
	if not spec then
		if frame.fkBackdrop then frame:SetBackdrop(nil) frame.fkBackdrop = nil end
		if tex then tex:Hide() end
		return
	end
	local bg, a = spec.bg or spec.color, alphaScale or 1
	local backdrop = spec.backdrop
	if spec.border and not backdrop then
		-- one shared table per edge width, so the SetBackdrop call below can be skipped when unchanged
		local edge = spec.edge or 1
		Theme.flat = Theme.flat or {}
		backdrop = Theme.flat[edge] or { bgFile = WHITE, edgeFile = WHITE, edgeSize = FK.Pixel(edge) }
		Theme.flat[edge] = backdrop
	end
	if backdrop then
		if tex then tex:Hide() end
		if frame.fkBackdrop ~= backdrop then
			frame:SetBackdrop(backdrop)
			frame.fkBackdrop = backdrop
		end
		if bg then frame:SetBackdropColor(bg[1], bg[2], bg[3], (bg[4] or 1) * a) end
		local b = spec.border or { 1, 1, 1, 1 }
		frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
		return
	end
	if frame.fkBackdrop then frame:SetBackdrop(nil) frame.fkBackdrop = nil end
	if not tex then
		tex = frame:CreateTexture(nil, "BACKGROUND")
		tex:SetAllPoints()
		frame.fkFill = tex
	end
	tex:Show()
	Theme.Texture(tex, spec, a)
end

-- Applies a texture-like spec ({ texture | atlas | bg/color, coords, blend }) to a Texture.
function Theme.Texture(tex, spec, alphaScale)
	local c = spec.color or spec.bg or { 1, 1, 1, 1 }
	local a = (c[4] or 1) * (alphaScale or 1)
	if spec.texture then
		tex:SetTexture(spec.texture)
		tex:SetVertexColor(c[1], c[2], c[3], a)
	elseif spec.atlas then
		tex:SetAtlas(spec.atlas)
		tex:SetVertexColor(c[1], c[2], c[3], a)
	else
		tex:SetColorTexture(c[1], c[2], c[3], a)
	end
	local co = spec.coords
	if co then tex:SetTexCoord(co[1], co[2], co[3], co[4]) else tex:SetTexCoord(0, 1, 0, 1) end
	tex:SetBlendMode(spec.blend or "BLEND")
end

-- A themed glyph (close cross, arrows, cog...): FK.Theme.Icon(parent, "close") -> frame with
-- :SetIcon(name) and :SetColor(role). Themes supply a texture or a text character per name.
function Theme.Icon(parent, name, size)
	local f = CreateFrame("Frame", nil, parent)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.text:SetPoint("CENTER")
	f.iconName, f.iconSize = name, size
	function f:SetIcon(icon) self.iconName = icon self:Restyle() end
	function f:SetColor(role) self.colorRole = role self:Restyle() end
	function f:Restyle()
		local T = Theme.current
		local spec = T.icon[self.iconName] or error("FK.Theme: no icon named " .. tostring(self.iconName), 2)
		local s = self.iconSize or spec.size or T.metric.icon
		self:SetSize(s, s)
		local r, g, b = 1, 1, 1
		if self.colorRole then r, g, b = Theme.Color(self.colorRole) end
		if spec.text then
			self.tex:Hide()
			self.text:Show()
			Theme.Font(self.text, spec.font or "normal", self.colorRole or spec.color or "text")
			self.text:SetText(spec.text)
		else
			self.text:Hide()
			self.tex:Show()
			Theme.Texture(self.tex, spec)
			if self.colorRole or spec.tint then
				if spec.tint then r, g, b = Theme.Color(self.colorRole or spec.tint) end
				self.tex:SetVertexColor(r, g, b)
			end
			self.tex:SetRotation(spec.rotation or 0)
		end
	end
	Theme.Track(f)
	f:Restyle()
	return f
end

local SOUNDS = {
	check = "IG_MAINMENU_OPTION_CHECKBOX_ON", uncheck = "IG_MAINMENU_OPTION_CHECKBOX_OFF",
	click = "IG_MAINMENU_OPTION", open = "IG_MAINMENU_OPEN", close = "IG_MAINMENU_CLOSE",
	tab = "IG_CHARACTER_INFO_TAB",
}
-- FK.Sound("click") (a role above), a SOUNDKIT name, a sound kit id, or a file path / file id
-- with a channel: FK.Sound("Interface\\AddOns\\Me\\ding.ogg", "Master"). FK.muted silences all.
function FK.Sound(name, channel)
	if FK.muted then return end
	if type(name) == "string" and name:find("[\\/]") then return PlaySoundFile(name, channel or "Master") end
	local id = type(name) == "number" and name or SOUNDKIT[SOUNDS[name] or name]
	if id then PlaySound(id, channel) end
end

-- Which of a stateful surface's specs applies to a widget right now.
function Theme.State(widget)
	return not widget.enabled and "disabled" or widget.down and "pressed" or widget.hover and "hover" or "normal"
end

-- Paints a stateful surface group ({ normal, hover, pressed, disabled, highlight }).
function Theme.PaintState(frame, group, state, alphaScale)
	Theme.Paint(frame, group[state] or group.normal, alphaScale)
	local hl = frame.fkHighlight
	if group.highlight then
		if not hl then
			hl = frame:CreateTexture(nil, "HIGHLIGHT") -- the client shows this layer on mouse-over
			hl:SetAllPoints()
			frame.fkHighlight = hl
		end
		hl:Show()
		Theme.Texture(hl, group.highlight)
	elseif hl then
		hl:Hide()
	end
end
