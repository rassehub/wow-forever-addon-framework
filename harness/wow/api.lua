-- The global environment an addon sees: Lua extensions of the client, base frames, and the
-- commonly used parts of the game API backed by fixtures (H.fixtures).
-- Anything not listed here is absent: calling it fails loudly, which is the point.

local H = require("wow.state")
require("wow.objects")
require("wow.sim")
local Encoding = require("wow.encoding")

local realType, realFormat, realPrint, osdate = type, string.format, print, os.date
local G = _G

-- An API namespace whose missing members explain themselves instead of "attempt to call nil".
local function namespace(name, t)
	return setmetatable(t, { __index = function(_, k)
		error(("%s.%s is not emulated. Stub it in the test: H.Stub(%q, function(...) ... end)")
			:format(name, tostring(k), name .. "." .. tostring(k)), 2)
	end })
end

function H.Stub(path, fn)
	local t, last = G, nil
	for part in path:gmatch("[^%.]+") do
		if last then
			if rawget(t, last) == nil then rawset(t, last, {}) end
			t = rawget(t, last)
		end
		last = part
	end
	rawset(t, last, fn)
end

local function color(r, g, b, a)
	local c = { r = r, g = g, b = b, a = a or 1 }
	function c:GetRGB() return self.r, self.g, self.b end
	function c:GetRGBA() return self.r, self.g, self.b, self.a end
	function c:GenerateHexColor() return ("ff%02x%02x%02x"):format(self.r * 255, self.g * 255, self.b * 255) end
	function c:WrapTextInColorCode(text) return "|c" .. self:GenerateHexColor() .. text .. "|r" end
	c.colorStr = c:GenerateHexColor()
	c.hex = "|c" .. c.colorStr
	return c
end

function H.Install()
	H.fixtures = H.fixtures or {
		player = { name = "Tester", realm = "Emulated", class = "MAGE", className = "Mage", classId = 8,
			level = 60, race = "Human", faction = "Alliance", money = 123456, health = 3000, healthMax = 4000 },
		items = {
			[2589] = { name = "Linen Cloth", quality = 1, icon = 132889, sellPrice = 13, stack = 200, type = "Trade Goods", classID = 7, subclassID = 5 },
			[2592] = { name = "Wool Cloth", quality = 1, icon = 132911, sellPrice = 33, stack = 200, type = "Trade Goods", classID = 7, subclassID = 5 },
			[6948] = { name = "Hearthstone", quality = 1, icon = 134414, sellPrice = 0, stack = 1, type = "Miscellaneous", classID = 15, subclassID = 0 },
			[19019] = { name = "Thunderfury, Blessed Blade of the Windseeker", quality = 5, icon = 134585, sellPrice = 255355, stack = 1, type = "Weapon", classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON", level = 80, minLevel = 60 },
		},
		spells = { [133] = { name = "Fireball", icon = 135812 } },
		bags = { [0] = { size = 16, [1] = { id = 6948, count = 1 }, [2] = { id = 2589, count = 20 } } },
		cvars = { uiScale = "1" },
		completedQuests = {},
	}
	local fx = H.fixtures

	-----------------------------------------------------------------------------------------
	-- Lua extensions
	-----------------------------------------------------------------------------------------
	G.type = function(v) return realType(H.Reveal(v)) end
	local function fmt(f, ...)
		local secret, args = false, { ... }
		for i = 1, select("#", ...) do
			if H.IsSecret(args[i]) then secret, args[i] = true, H.Reveal(args[i]) end
		end
		local out = realFormat(f, unpack(args, 1, select("#", ...)))
		return secret and H.Secret(out) or out
	end
	string.format, G.format = fmt, fmt
	G.strsub, G.strlen, G.strlower, G.strupper = string.sub, string.len, string.lower, string.upper
	G.strfind, G.strmatch, G.strrep, G.strbyte, G.strchar = string.find, string.match, string.rep, string.byte, string.char
	G.gsub, G.gmatch, G.strrev = string.gsub, string.gmatch, string.reverse
	G.floor, G.ceil, G.abs, G.min, G.max, G.random, G.sqrt, G.mod = math.floor, math.ceil, math.abs, math.min, math.max, math.random, math.sqrt, math.fmod
	G.tinsert, G.tremove, G.sort, G.tconcat = table.insert, table.remove, table.sort, table.concat
	G.strtrim = function(s, chars)
		chars = chars or "%s"
		return (s:gsub("^[" .. chars .. "]+", ""):gsub("[" .. chars .. "]+$", ""))
	end
	G.strsplit = function(sep, s, limit)
		local out, pos = {}, 1
		while true do
			local at = (not limit or #out < limit - 1) and s:find("[" .. sep:gsub("%p", "%%%0") .. "]", pos)
			if not at then
				out[#out + 1] = s:sub(pos)
				break
			end
			out[#out + 1] = s:sub(pos, at - 1)
			pos = at + 1
		end
		return unpack(out)
	end
	G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
	G.strsplittable = function(sep, s, limit) return { G.strsplit(sep, s, limit) } end
	G.strconcat = function(...) return table.concat({ ... }) end
	G.strlenutf8 = function(s) return select(2, s:gsub("[^\128-\191]", "")) end
	string.split, string.join, string.trim, string.concat = G.strsplit, G.strjoin, G.strtrim, G.strconcat
	G.tostringall = function(...)
		local out = {}
		for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
		return unpack(out, 1, select("#", ...))
	end
	G.wipe = function(t)
		for k in pairs(t) do t[k] = nil end
		return t
	end
	table.wipe = G.wipe
	G.tContains = function(t, v)
		for _, x in ipairs(t) do if x == v then return true end end
		return false
	end
	G.tIndexOf = function(t, v)
		for i, x in ipairs(t) do if x == v then return i end end
	end
	G.tDeleteItem = function(t, v)
		for i = #t, 1, -1 do if t[i] == v then table.remove(t, i) end end
	end
	G.CopyTable = function(t, shallow)
		local out = {}
		for k, v in pairs(t) do out[k] = (realType(v) == "table" and not shallow) and G.CopyTable(v) or v end
		return out
	end
	G.Mixin = function(obj, ...)
		for i = 1, select("#", ...) do
			for k, v in pairs((select(i, ...))) do obj[k] = v end
		end
		return obj
	end
	G.CreateFromMixins = function(...) return G.Mixin({}, ...) end
	G.GenerateClosure = function(fn, ...)
		local bound, n = { ... }, select("#", ...)
		return function(...)
			local args = { unpack(bound, 1, n) }
			for i = 1, select("#", ...) do args[n + i] = (select(i, ...)) end
			return fn(unpack(args, 1, n + select("#", ...)))
		end
	end
	G.Clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
	G.Lerp = function(a, b, t) return a + (b - a) * t end
	G.Round = function(v) return math.floor(v + 0.5) end
	G.nop = function() end

	local function bitop(fn)
		return function(a, b)
			local out, p = 0, 1
			for _ = 1, 32 do
				local x, y = a % 2, (b or 0) % 2
				if fn(x, y) then out = out + p end
				a, b, p = (a - x) / 2, ((b or 0) - y) / 2, p * 2
			end
			return out
		end
	end
	G.bit = {
		band = bitop(function(x, y) return x == 1 and y == 1 end),
		bor = bitop(function(x, y) return x == 1 or y == 1 end),
		bxor = bitop(function(x, y) return x ~= y end),
		lshift = function(a, n) return (a * 2 ^ n) % 2 ^ 32 end,
		rshift = function(a, n) return math.floor(a / 2 ^ n) end,
	}
	G.bit.bnot = function(a) return 4294967295 - a end

	G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		local line = table.concat(parts, " ")
		H.log[#H.log + 1] = line
		if H.verbose then realPrint("[chat] " .. H.plain(line)) end
	end
	local errorHandler = function(msg) error(msg, 0) end
	G.geterrorhandler = function() return errorHandler end
	G.seterrorhandler = function(fn) errorHandler = fn end
	G.debugstack = function() return "" end
	G.debugprofilestop = function() return H.clock * 1000 end
	G.securecall = function(fn, ...) if realType(fn) == "string" then fn = G[fn] end return fn(...) end
	G.securecallfunction = G.securecall
	G.issecure = function() return false end
	G.issecurevariable = function() return true end
	G.hooksecurefunc = function(a, b, c)
		local t, name, hook = G, a, b
		if realType(a) == "table" then t, name, hook = a, b, c end
		local orig = t[name]
		if realType(orig) ~= "function" then error("hooksecurefunc: " .. tostring(name) .. " is not a function", 2) end
		rawset(t, name, function(...)
			local r = { orig(...) }
			hook(...)
			return unpack(r)
		end)
	end
	G.issecretvalue = H.IsSecret
	G.canaccessvalue = function(v) return not H.IsSecret(v) end
	G.issecrettable = function() return false end
	G.canaccesstable = function() return true end

	G.GetTime = function() return H.clock end
	G.GetServerTime = function() return 1794839000 + math.floor(H.clock - 1000) end
	G.time = G.GetServerTime
	G.date = function(f, t) return osdate(f or "%c", t or G.GetServerTime()) end
	G.GetFramerate = function() return 1 / H.frameTime end
	G.GetLocale = function() return fx.locale or "enUS" end
	G.GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
	G.IsLoggedIn = function() return H.loggedIn == true end
	G.InCombatLockdown = function() return H.inCombat end
	G.ReloadUI = function() H.reloadRequested = true end
	G.Screenshot = function() H.screenshots = (H.screenshots or 0) + 1 end
	G.SOUNDKIT = setmetatable({}, { __index = function(_, k) return k end })
	H.sounds = {}
	G.PlaySound = function(id) H.sounds[#H.sounds + 1] = id return true end
	G.PlaySoundFile = G.PlaySound
	G.SetCursor, G.ResetCursor = function() end, function() end
	G.GetCursorPosition = function() return H.mouseX, H.mouseY end
	G.GetScreenWidth = function() return H.screenWidth / G.UIParent:GetScale() end
	G.GetScreenHeight = function() return H.screenHeight / G.UIParent:GetScale() end
	G.GetPhysicalScreenSize = function() return H.screenWidth, H.screenHeight end
	G.IsShiftKeyDown = function() return H.modifiers.SHIFT == true end
	G.IsControlKeyDown = function() return H.modifiers.CTRL == true end
	G.IsAltKeyDown = function() return H.modifiers.ALT == true end
	G.IsModifierKeyDown = function() return next(H.modifiers) ~= nil end
	G.IsMouseButtonDown = function() return false end
	G.GetMouseFoci = function() return { H.hover } end

	-----------------------------------------------------------------------------------------
	-- Base frames and fonts
	-----------------------------------------------------------------------------------------
	G.CreateFrame = H.CreateFrame
	G.CreateFont = H.CreateFont
	local fonts = {
		GameFontNormal = { 12, 1, 0.82, 0 }, GameFontNormalSmall = { 10, 1, 0.82, 0 },
		GameFontNormalLarge = { 16, 1, 0.82, 0 }, GameFontNormalHuge = { 20, 1, 0.82, 0 },
		GameFontHighlight = { 12, 1, 1, 1 }, GameFontHighlightSmall = { 10, 1, 1, 1 },
		GameFontHighlightLarge = { 16, 1, 1, 1 }, GameFontHighlightHuge = { 20, 1, 1, 1 },
		GameFontDisable = { 12, 0.5, 0.5, 0.5 }, GameFontDisableSmall = { 10, 0.5, 0.5, 0.5 },
		GameFontDisableLarge = { 16, 0.5, 0.5, 0.5 },
		GameFontWhite = { 12, 1, 1, 1 }, GameFontWhiteSmall = { 10, 1, 1, 1 }, GameFontBlack = { 12, 0, 0, 0 },
		GameFontRed = { 12, 1, 0.1, 0.1 }, GameFontRedSmall = { 10, 1, 0.1, 0.1 },
		GameFontGreen = { 12, 0.1, 1, 0.1 }, GameFontGreenSmall = { 10, 0.1, 1, 0.1 },
		NumberFontNormal = { 14, 1, 1, 1 }, NumberFontNormalSmall = { 12, 1, 1, 1 }, NumberFontNormalLarge = { 16, 1, 1, 1 },
		ChatFontNormal = { 14, 1, 1, 1 }, ChatFontSmall = { 12, 1, 1, 1 },
		GameTooltipText = { 12, 1, 1, 1 }, GameTooltipHeaderText = { 14, 1, 1, 1 }, GameTooltipTextSmall = { 10, 1, 1, 1 },
		QuestFont = { 13, 0.18, 0.12, 0.06 }, QuestTitleFont = { 18, 0.18, 0.12, 0.06 }, QuestFontNormalSmall = { 12, 0.18, 0.12, 0.06 },
		SystemFont_Small = { 10, 1, 1, 1 }, SystemFont_Med1 = { 12, 1, 1, 1 }, SystemFont_Large = { 16, 1, 1, 1 },
		SystemFont_Shadow_Small = { 10, 1, 1, 1 }, SystemFont_Shadow_Med1 = { 12, 1, 1, 1 }, SystemFont_Shadow_Large = { 16, 1, 1, 1 },
		SystemFont_Outline_Small = { 10, 1, 1, 1 }, SystemFont_Tiny = { 9, 1, 1, 1 },
	}
	for name, f in pairs(fonts) do
		local font = H.CreateFont(name)
		font:SetFont("Fonts\\FRIZQT__.TTF", f[1], "")
		font:SetTextColor(f[2], f[3], f[4])
	end
	G.STANDARD_TEXT_FONT, G.UNIT_NAME_FONT, G.DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF"

	local ui = H.CreateFrame("Frame", "UIParent")
	ui:SetScale(tonumber(fx.cvars.uiScale) or 1)
	ui:SetAllPoints(nil)
	H.CreateFrame("Frame", "WorldFrame"):SetAllPoints(nil)
	local mm = H.CreateFrame("Frame", "Minimap", ui)
	mm:SetSize(140, 140)
	mm:SetPoint("TOPRIGHT", -20, -30)
	G.GetMinimapShape = nil
	local tip = H.CreateFrame("GameTooltip", "GameTooltip", ui)
	tip:SetFrameStrata("TOOLTIP")
	H.CreateFrame("GameTooltip", "ItemRefTooltip", ui)
	G.UISpecialFrames = {}
	G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) G.print(msg) end }
	G.ChatFrame1 = G.DEFAULT_CHAT_FRAME
	G.UIErrorsFrame = { AddMessage = function(_, msg) H.log[#H.log + 1] = "[error frame] " .. tostring(msg) end }
	G.GameTooltip_SetDefaultAnchor = function(tooltip, parent) tooltip:SetOwner(parent, "ANCHOR_NONE") end
	G.GameTooltip_Hide = function() tip:Hide() end

	-- The Blizzard colour picker: record the request, tests answer with H.PickColor/H.CancelColor.
	G.ColorPickerFrame = {
		SetupColorPickerAndShow = function(self, info) H.colorPicker = info; self.r, self.g, self.b, self.a = info.r, info.g, info.b, info.opacity end,
		GetColorRGB = function(self) return self.r, self.g, self.b end,
		GetColorAlpha = function(self) return self.a or 1 end,
		Hide = function() H.colorPicker = nil end,
		IsShown = function() return H.colorPicker ~= nil end,
	}
	function H.PickColor(r, g, b, a)
		local info = assert(H.colorPicker, "PickColor: the colour picker is not open")
		local cp = G.ColorPickerFrame
		cp.r, cp.g, cp.b, cp.a = r, g, b, a
		if info.swatchFunc then info.swatchFunc() end
		if a and info.opacityFunc then info.opacityFunc() end
		H.colorPicker = nil
	end
	function H.CancelColor()
		local info = assert(H.colorPicker, "CancelColor: the colour picker is not open")
		H.colorPicker = nil
		if info.cancelFunc then info.cancelFunc({ r = info.r, g = info.g, b = info.b, a = info.opacity }) end
	end

	-- Blizzard Settings window: categories with a canvas frame each.
	local panel = H.CreateFrame("Frame", "SettingsPanel", ui)
	panel:SetSize(920, 724)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("HIGH")
	panel:Hide()
	local canvas = H.CreateFrame("Frame", nil, panel)
	canvas:SetPoint("TOPLEFT", 252, -60)
	canvas:SetPoint("BOTTOMRIGHT", -24, 48)
	H.settingsCategories = {}
	local function category(frame, name, parent)
		local c = { ID = name, name = name, frame = frame, parent = parent, GetID = function(self) return self.ID end, GetName = function(self) return self.name end }
		frame:SetParent(canvas)
		frame:SetAllPoints(canvas)
		frame:Hide()
		H.settingsCategories[#H.settingsCategories + 1] = c
		return c, { AddAnchorPoint = function() end }
	end
	G.Settings = namespace("Settings", {
		RegisterCanvasLayoutCategory = function(frame, name) return category(frame, name) end,
		RegisterCanvasLayoutSubcategory = function(parent, frame, name) return category(frame, name, parent) end,
		RegisterAddOnCategory = function(c) c.registered = true end,
		OpenToCategory = function(id)
			for _, c in ipairs(H.settingsCategories) do
				c.frame:SetShown(c.ID == id)
				if c.ID == id then H.settingsOpen = c end
			end
			if InCombatLockdown() then error("Settings.OpenToCategory is blocked in combat", 2) end
			panel:Show()
		end,
	})

	G.StaticPopupDialogs = {}
	G.StaticPopup_Show = function(which, a, b, data)
		local d = G.StaticPopupDialogs[which] or error("StaticPopup_Show: unknown dialog " .. tostring(which), 2)
		H.popup = { which = which, dialog = d, data = data, text = (d.text or ""):format(a or "", b or "") }
		return H.popup
	end
	G.StaticPopup_Hide = function() H.popup = nil end
	function H.PopupAccept(text)
		local p = assert(H.popup, "PopupAccept: no StaticPopup is shown")
		H.popup = nil
		if p.dialog.OnAccept then p.dialog.OnAccept({ data = p.data, editBox = { GetText = function() return text or "" end } }, p.data) end
	end

	-----------------------------------------------------------------------------------------
	-- Timers, addons, CVars
	-----------------------------------------------------------------------------------------
	local function timer(delay, fn, iterations)
		local t = { iterations = iterations }
		function t:Cancel() self.cancelled = true; if self.handle then self.handle.cancelled = true end end
		function t:IsCancelled() return self.cancelled == true end
		local function schedule()
			t.handle = H.After(delay, function()
				if t.cancelled then return end
				if t.iterations then t.iterations = t.iterations - 1 end
				local again = iterations ~= 1 and (not t.iterations or t.iterations > 0)
				if again and iterations ~= 1 then schedule() end
				fn(t)
			end)
		end
		schedule()
		return t
	end
	G.C_Timer = namespace("C_Timer", {
		After = function(delay, fn)
			if realType(fn) ~= "function" then error("C_Timer.After(seconds, function)", 2) end
			H.After(delay, fn)
		end,
		NewTimer = function(delay, fn) return timer(delay, fn, 1) end,
		NewTicker = function(delay, fn, iterations) return timer(delay, fn, iterations or false) end,
	})

	H.addons = H.addons or {}
	G.C_AddOns = namespace("C_AddOns", {
		IsAddOnLoaded = function(name) return H.addons[name] ~= nil, H.addons[name] ~= nil end,
		GetAddOnMetadata = function(name, field) return H.addons[name] and H.addons[name].meta[field] end,
		GetNumAddOns = function() local n = 0 for _ in pairs(H.addons) do n = n + 1 end return n end,
		DoesAddOnExist = function(name) return H.addons[name] ~= nil end,
		GetAddOnEnableState = function(name) return H.addons[name] and 2 or 0 end,
		LoadAddOn = function(name) return H.addons[name] ~= nil end,
	})
	G.C_CVar = namespace("C_CVar", {
		GetCVar = function(name) return fx.cvars[name] end,
		SetCVar = function(name, value) fx.cvars[name] = tostring(value) return true end,
		GetCVarBool = function(name) return fx.cvars[name] == "1" end,
		RegisterCVar = function(name, value) if fx.cvars[name] == nil then fx.cvars[name] = value end end,
	})
	G.GetCVar, G.SetCVar, G.GetCVarBool = G.C_CVar.GetCVar, G.C_CVar.SetCVar, G.C_CVar.GetCVarBool
	G.C_EventUtils = namespace("C_EventUtils", { IsEventValid = function(e) return not H.validEvents or H.validEvents[e] == true end })
	G.C_UI = namespace("C_UI", { Reload = G.ReloadUI })
	G.C_Texture = namespace("C_Texture", { GetAtlasInfo = function() return { width = 16, height = 16 } end })

	local callbacks = {}
	G.EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = callbacks[event] or {}
			callbacks[event][owner or fn] = fn
		end,
		UnregisterCallback = function(_, event, owner) if callbacks[event] then callbacks[event][owner] = nil end end,
		TriggerEvent = function(_, event, ...)
			for owner, fn in pairs(callbacks[event] or {}) do fn(owner, ...) end
		end,
	}
	G.EventRegistry.RegisterFrameEventAndCallback = function(self, event, fn, owner)
		self:RegisterCallback(event, fn, owner)
		H.eventHooks = H.eventHooks or {}
		H.eventHooks[#H.eventHooks + 1] = function(e, ...) if e == event then fn(owner, ...) end end
	end

	-----------------------------------------------------------------------------------------
	-- Slash commands, chat, addon messages
	-----------------------------------------------------------------------------------------
	G.SlashCmdList = {}
	function H.Slash(line)
		local cmd, rest = line:match("^(/%S+)%s*(.*)$")
		if not cmd then error("Slash: expected '/command args'", 2) end
		for name, fn in pairs(G.SlashCmdList) do
			local i = 1
			while rawget(G, "SLASH_" .. name .. i) do
				if rawget(G, "SLASH_" .. name .. i):lower() == cmd:lower() then
					fn(rest, { GetText = function() return line end })
					H.Advance(0)
					return true
				end
				i = i + 1
			end
		end
		error("Slash: no addon registered " .. cmd, 2)
	end

	H.sent, H.chat, H.prefixes = {}, {}, {}
	G.C_ChatInfo = namespace("C_ChatInfo", {
		RegisterAddonMessagePrefix = function(prefix)
			if #prefix > 16 then error("addon message prefix longer than 16 characters", 2) end
			H.prefixes[prefix] = true
			return true
		end,
		IsAddonMessagePrefixRegistered = function(prefix) return H.prefixes[prefix] == true end,
		SendAddonMessage = function(prefix, msg, channel, target)
			if #prefix > 16 then error("addon message prefix longer than 16 characters", 2) end
			if #msg > 255 then error("addon message longer than 255 bytes", 2) end
			H.sent[#H.sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
			-- you receive your own group/guild messages
			if H.prefixes[prefix] then
				H.Fire("CHAT_MSG_ADDON", prefix, msg, channel, fx.player.name .. "-" .. fx.player.realm, fx.player.name)
			end
			return 0
		end,
		SendChatMessage = function(msg, channel, lang, target) H.chat[#H.chat + 1] = { msg = msg, channel = channel, target = target } end,
	})
	G.SendChatMessage = G.C_ChatInfo.SendChatMessage
	-- An addon message from another player.
	function H.Receive(prefix, msg, channel, sender)
		if H.prefixes[prefix] then H.Fire("CHAT_MSG_ADDON", prefix, msg, channel or "GUILD", sender or "Other-Emulated", (sender or "Other"):match("^[^-]+")) end
	end

	-----------------------------------------------------------------------------------------
	-- Player and units
	-----------------------------------------------------------------------------------------
	local p = fx.player
	local function combatSecret(v) return (H.inCombat or H.forceSecrets) and H.Secret(v) or v end
	-- other units: fx.units = { party1 = { name, realm, class, className } }, fx.group = { "party1", ... }
	local function other(unit) return fx.units and fx.units[unit] end
	G.UnitName = function(unit)
		if unit == "player" then return p.name, nil end
		local u = other(unit)
		if u then return u.name, u.realm end
	end
	G.UnitFullName = function(unit)
		if unit == "player" then return p.name, p.realm end
		local u = other(unit)
		if u then return u.name, u.realm or p.realm end
	end
	G.UnitNameUnmodified = G.UnitName
	G.GetUnitName = function(unit) return (G.UnitName(unit)) end
	G.UnitClass = function(unit)
		local u = unit == "player" and p or other(unit)
		if u then return u.className, u.class, u.classId end
	end
	G.UnitClassBase = function(unit) if unit == "player" then return p.class, p.classId end end
	G.UnitLevel = function(unit) return unit == "player" and p.level or 0 end
	G.UnitRace = function(unit) if unit == "player" then return p.race, p.race end end
	G.UnitFactionGroup = function(unit) if unit == "player" then return p.faction, p.faction end end
	G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	G.UnitExists = function(unit) return unit == "player" or (fx.units and fx.units[unit] ~= nil) or false end
	G.UnitIsPlayer = function(unit) return unit == "player" end
	G.UnitIsDeadOrGhost = function() return false end
	G.UnitAffectingCombat = function(unit) return unit == "player" and H.inCombat end
	G.UnitHealth = function(unit) return combatSecret(unit == "player" and p.health or 0) end
	G.UnitHealthMax = function(unit) return combatSecret(unit == "player" and p.healthMax or 0) end
	G.UnitPower = function() return combatSecret(p.power or 100) end
	G.UnitPowerMax = function() return combatSecret(p.powerMax or 100) end
	G.GetRealmName = function() return p.realm end
	G.GetNormalizedRealmName = function() return (p.realm:gsub("[%s%-]", "")) end
	G.GetMoney = function() return p.money end
	G.IsInGroup, G.IsInRaid = function() return fx.group ~= nil end, function() return fx.raid == true end
	G.IsInGuild = function() return fx.guild ~= nil end
	G.GetGuildInfo = function(unit) if unit == "player" and fx.guild then return fx.guild, "Member", 1 end end
	G.GetNumGroupMembers = function() return fx.group and #fx.group or 0 end

	G.NORMAL_FONT_COLOR, G.HIGHLIGHT_FONT_COLOR = color(1, 0.82, 0), color(1, 1, 1)
	G.RED_FONT_COLOR, G.GREEN_FONT_COLOR = color(1, 0.13, 0.13), color(0.1, 1, 0.1)
	G.GRAY_FONT_COLOR, G.DISABLED_FONT_COLOR, G.YELLOW_FONT_COLOR = color(0.5, 0.5, 0.5), color(0.5, 0.5, 0.5), color(1, 1, 0)
	G.ORANGE_FONT_COLOR, G.WHITE_FONT_COLOR = color(1, 0.5, 0.25), color(1, 1, 1)
	G.CreateColor = color
	local quality = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 }, { 0, 0.8, 1 } }
	G.ITEM_QUALITY_COLORS = {}
	for q, c in pairs(quality) do
		G.ITEM_QUALITY_COLORS[q] = color(c[1], c[2], c[3])
		G.ITEM_QUALITY_COLORS[q].color = G.ITEM_QUALITY_COLORS[q]
	end
	G.GetItemQualityColor = function(q) local c = G.ITEM_QUALITY_COLORS[q] or G.ITEM_QUALITY_COLORS[1] return c.r, c.g, c.b, c.colorStr end
	G.RAID_CLASS_COLORS = {}
	for class, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 } }) do
		G.RAID_CLASS_COLORS[class] = color(c[1], c[2], c[3])
	end
	G.Enum = namespace("Enum", {
		TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
		ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 },
		CompressionMethod = { Deflate = 0, Zlib = 1 },
	})

	-----------------------------------------------------------------------------------------
	-- Items, bags, spells, money
	-----------------------------------------------------------------------------------------
	local function itemId(v)
		if realType(v) == "number" then return v end
		local id = tostring(v):match("item:(%d+)")
		if id then return tonumber(id) end
		for i, item in pairs(fx.items) do if item.name == v then return i end end
	end
	local function itemLink(id)
		local it = fx.items[id]
		return ("|c%s|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(G.ITEM_QUALITY_COLORS[it.quality].colorStr, id, it.name)
	end
	local function cached(id) return fx.items[id] and not fx.items[id].uncached end
	-- Makes an `uncached = true` fixture item available, as the server answering the request.
	function H.CacheItem(id)
		fx.items[id].uncached = nil
		H.Fire("GET_ITEM_INFO_RECEIVED", id, true)
		H.Fire("ITEM_DATA_LOAD_RESULT", id, true)
	end
	function H.LinkName(link)
		local id = itemId(link)
		return id and fx.items[id] and fx.items[id].name or link
	end
	G.C_Item = namespace("C_Item", {
		GetItemInfo = function(v)
			local id = itemId(v)
			if not id or not cached(id) then return nil end
			local it = fx.items[id]
			return it.name, itemLink(id), it.quality, it.level or 1, it.minLevel or 0, it.type or "Miscellaneous", it.subType or "",
				it.stack or 1, it.equipLoc or "", it.icon, it.sellPrice or 0, it.classID or 15, it.subclassID or 0
		end,
		GetItemInfoInstant = function(v)
			local id = itemId(v)
			local it = id and fx.items[id]
			if not it then return nil end
			return id, it.type or "Miscellaneous", it.subType or "", it.equipLoc or "", it.icon, it.classID or 15, it.subclassID or 0
		end,
		GetItemIconByID = function(id) return fx.items[id] and fx.items[id].icon or 134400 end,
		GetItemNameByID = function(id) return cached(id) and fx.items[id].name or nil end,
		GetItemQualityByID = function(id) return cached(id) and fx.items[id].quality or nil end,
		IsItemDataCachedByID = function(id) return cached(id) == true end,
		DoesItemExistByID = function(id) return fx.items[id] ~= nil end,
		RequestLoadItemDataByID = function(id)
			if fx.items[id] then H.After(0.1, function() H.CacheItem(id) end) end
		end,
		GetItemCount = function(v, includeBank)
			local id, n = itemId(v), 0
			for _, bag in pairs(fx.bags) do
				for slot, it in pairs(bag) do
					if realType(slot) == "number" and it.id == id then n = n + it.count end
				end
			end
			return n + (includeBank and fx.bank and fx.bank[id] or 0)
		end,
	})
	G.Item = {
		CreateFromItemID = function(_, id)
			local o = {}
			function o:GetItemID() return id end
			function o:IsItemEmpty() return fx.items[id] == nil end
			function o:IsItemDataCached() return cached(id) == true end
			function o:GetItemName() return cached(id) and fx.items[id].name or nil end
			function o:GetItemLink() return cached(id) and itemLink(id) or nil end
			function o:GetItemIcon() return fx.items[id] and fx.items[id].icon end
			function o:GetItemQuality() return cached(id) and fx.items[id].quality or nil end
			function o:ContinueOnItemLoad(fn)
				if not fx.items[id] then error("ContinueOnItemLoad: item " .. tostring(id) .. " does not exist (the client raises here too)", 2) end
				if cached(id) then fn() else
					H.After(0.1, function() H.CacheItem(id) fn() end)
				end
			end
			return o
		end,
	}
	G.NUM_BAG_SLOTS, G.BACKPACK_CONTAINER = 4, 0
	G.C_Container = namespace("C_Container", {
		GetContainerNumSlots = function(bag) return fx.bags[bag] and fx.bags[bag].size or 0 end,
		GetContainerNumFreeSlots = function(bag)
			local b, used = fx.bags[bag], 0
			if not b then return 0 end
			for slot in pairs(b) do if realType(slot) == "number" then used = used + 1 end end
			return b.size - used
		end,
		GetContainerItemInfo = function(bag, slot)
			local it = fx.bags[bag] and fx.bags[bag][slot]
			if not it then return nil end
			local def = fx.items[it.id] or {}
			return { itemID = it.id, stackCount = it.count, iconFileID = def.icon, quality = def.quality, hyperlink = fx.items[it.id] and itemLink(it.id), isLocked = false }
		end,
		GetContainerItemID = function(bag, slot) local it = fx.bags[bag] and fx.bags[bag][slot] return it and it.id end,
		GetContainerItemLink = function(bag, slot) local it = fx.bags[bag] and fx.bags[bag][slot] return it and itemLink(it.id) end,
	})
	-- Puts `count` of an item into a bag slot (nil id empties it) and fires the bag events.
	function H.SetBag(bag, slot, id, count)
		fx.bags[bag] = fx.bags[bag] or { size = 16 }
		fx.bags[bag][slot] = id and { id = id, count = count or 1 } or nil
		H.Fire("BAG_UPDATE", bag)
		H.Fire("BAG_UPDATE_DELAYED")
	end
	G.C_Spell = namespace("C_Spell", {
		GetSpellName = function(id) return fx.spells[id] and fx.spells[id].name end,
		GetSpellTexture = function(id) return fx.spells[id] and fx.spells[id].icon end,
		GetSpellInfo = function(id) local s = fx.spells[id] return s and { name = s.name, iconID = s.icon, spellID = id } end,
	})
	G.C_QuestLog = namespace("C_QuestLog", {
		IsQuestFlaggedCompleted = function(id) return fx.completedQuests[id] == true end,
	})
	G.C_Map = namespace("C_Map", {
		GetBestMapForUnit = function() return fx.mapID or 1453 end,
		GetMapInfo = function(id) return { mapID = id, name = fx.maps and fx.maps[id] or ("Map " .. id), mapType = 3, parentMapID = 0 } end,
		SetUserWaypoint = function(point) H.waypoint = point end,
		GetUserWaypoint = function() return H.waypoint end,
		GetPlayerMapPosition = function()
			local pos = fx.position or { 0.5, 0.5 }
			return { x = pos[1], y = pos[2], GetXY = function(self) return self.x, self.y end }
		end,
	})
	local enc = {}
	for k, v in pairs(Encoding) do enc[k] = v end -- a fresh table: namespace() sets a metatable on it
	G.C_EncodingUtil = namespace("C_EncodingUtil", enc)
	G.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, position = { x = x, y = y } } end }
	G.C_SuperTrack = namespace("C_SuperTrack", { SetSuperTrackedUserWaypoint = function(v) H.superTracked = v end })
	local function coins(copper)
		local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
		local out = {}
		if g > 0 then out[#out + 1] = g .. "g" end
		if s > 0 or g > 0 then out[#out + 1] = s .. "s" end
		out[#out + 1] = c .. "c"
		return table.concat(out, " ")
	end
	G.GetCoinTextureString, G.GetMoneyString, G.GetCoinText = coins, coins, coins
	G.C_CurrencyInfo = namespace("C_CurrencyInfo", { GetCoinTextureString = coins })

	local postCalls = {}
	G.TooltipDataProcessor = namespace("TooltipDataProcessor", {
		AddTooltipPostCall = function(dataType, fn) postCalls[#postCalls + 1] = { dataType, fn } end,
	})
	-- Shows the item's tooltip as hovering the item would, running addon post-calls.
	function H.ShowItemTooltip(id, owner)
		tip:SetOwner(owner or ui, "ANCHOR_RIGHT")
		tip:SetHyperlink("item:" .. id)
		for _, pc in ipairs(postCalls) do
			if pc[1] == G.Enum.TooltipDataType.Item then pc[2](tip, { id = id, type = pc[1] }) end
		end
		tip:Show()
	end

	local bindings = {}
	G.SetBinding = function(key, command) bindings[key] = command return true end
	G.GetBindingKey = function(command)
		for k, c in pairs(bindings) do if c == command then return k end end
	end
	G.GetBindingAction = function(key) return bindings[key] or "" end
	G.SaveBindings, G.GetCurrentBindingSet = function() end, function() return 1 end
	H.overrides = {} -- key -> { owner, button name }
	G.SetOverrideBindingClick = function(owner, _, key, buttonName, mouseButton)
		if H.inCombat then error("SetOverrideBindingClick is protected in combat", 2) end
		H.overrides[key] = { owner = owner, button = buttonName, mouseButton = mouseButton }
	end
	G.ClearOverrideBindings = function(owner)
		if H.inCombat then error("ClearOverrideBindings is protected in combat", 2) end
		for k, o in pairs(H.overrides) do if o.owner == owner then H.overrides[k] = nil end end
	end
	-- Presses a key as the client would: an override binding clicks its button.
	function H.PressBinding(key)
		local o = H.overrides[key] or error("no override binding on " .. key, 2)
		local b = G[o.button] or error("binding target " .. o.button .. " does not exist", 2)
		H.run(b, "OnClick", o.mouseButton or "LeftButton", true)
	end
	-- World map: the canvas child pins attach to, and the map id it shows.
	local wm = H.CreateFrame("Frame", "WorldMapFrame", ui)
	wm:SetSize(1002, 668)
	wm:SetPoint("CENTER")
	wm:Hide()
	wm.ScrollContainer = H.CreateFrame("Frame", nil, wm)
	wm.ScrollContainer:SetAllPoints()
	wm.ScrollContainer.Child = H.CreateFrame("Frame", nil, wm.ScrollContainer)
	wm.ScrollContainer.Child:SetAllPoints()
	wm.mapID = fx.mapID or 1453
	function wm:GetMapID() return self.mapID end
	function wm:OnMapChanged() end
	function wm:SetMapID(id) self.mapID = id self:OnMapChanged() end
	G.AddonCompartmentFrame = { RegisterAddon = function(_, info) H.compartment = H.compartment or {} table.insert(H.compartment, info) end }
end

function H.TooltipLines()
	local out = {}
	for _, line in ipairs(GameTooltip[0].lines or {}) do
		out[#out + 1] = H.plain(tostring(line.left or "")) .. (line.right and ("  " .. H.plain(tostring(line.right))) or "")
	end
	return out
end

return H
