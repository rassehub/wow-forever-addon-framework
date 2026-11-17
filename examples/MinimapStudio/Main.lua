local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- Showcase: a minimap customiser. All of it is FK.MinimapSkin driven by saved settings; the
-- settings window is the whole interface (no window of its own). /mms opens it.

local SKIN = { enabled = true, shape = "round", border = "thin", color = { 0.85, 0.7, 0.3 }, width = 0, height = 180, scale = 1,
	rotate = false, wheelZoom = true, drawer = true, attach = true, hide = {}, position = nil }

ns.db = FK:NewDB("MinimapStudioDB", { profile = { ui = FK.Copy(FK.AppearanceDefaults), skin = FK.Copy(SKIN) } })
FK:BindAppearance(ns.db, "profile.ui")

local unlocked, saving = false, false

-- The settings as MinimapSkin options. width 0 = the client's own size.
function ns.Options()
	local s = ns.db.profile.skin
	local hide = {}
	for name, on in pairs(s.hide) do if on then hide[#hide + 1] = name end end
	return { shape = s.shape, border = s.border, borderColor = s.color, width = s.width > 0 and s.width or nil,
		height = s.height, scale = s.scale, rotate = s.shape == "round" and s.rotate, wheelZoom = s.wheelZoom,
		drawer = s.drawer, attach = s.attach, hide = hide, position = s.position and FK.Copy(s.position), unlock = unlocked, -- the skin moves its own copy
		onLayout = function(l)
			-- the handles moved or resized the map: save it without applying again
			saving = true
			ns.db:Set("profile.skin.position", l.position)
			ns.db:Set("profile.skin.width", math.floor(l.width + 0.5))
			ns.db:Set("profile.skin.height", math.floor((l.height or l.width) + 0.5))
			saving = false
			if ns.options then ns.options:Refresh() end
		end }
end

function ns.Apply()
	if saving or not FK.inWorld then return end
	if ns.db.profile.skin.enabled then FK.MinimapSkin.Apply(ns.Options()) else FK.MinimapSkin.Reset() end
end

function ns.Unlock(on)
	unlocked = on and true or false
	ns.Apply()
end

-- Presets set several settings at once; each is an ordinary saved layout afterwards.
ns.PRESETS = {
	classic = { shape = "round", border = "none", width = 0, rotate = false, position = false, hide = {} },
	modern = { shape = "square", border = "thin", width = 220, rotate = false, position = false, hide = { ring = true } },
	navigator = { shape = "rect", border = "thin", width = 460, height = 230, rotate = false, drawer = true, hide = { header = true },
		position = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 150 } },
	compass = { shape = "round", border = "thin", width = 300, rotate = true, drawer = true, hide = { header = true },
		position = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -60, y = 140 } },
}
function ns.Preset(name)
	local skin = FK.Copy(ns.db.profile.skin) -- a new table: setting the same one is not a change
	for k, v in pairs(ns.PRESETS[name]) do
		if v == false then v = nil end
		skin[k] = type(v) == "table" and FK.Copy(v) or v
	end
	skin.enabled = true
	ns.db:Set("profile.skin", skin) -- one notification: apply once
	if ns.options then ns.options:Refresh() end
end

local function notRect() return ns.db.profile.skin.shape ~= "rect" end
local function notRound() return ns.db.profile.skin.shape ~= "round" end

FK:OnLogin(function()
	ns.options = FK:Options({
		db = ns.db,
		pages = {
			{ id = "shape", label = L["Shape"], options = {
				{ type = "toggle", key = "profile.skin.enabled", label = L["Restyle the minimap"], desc = L["Off: the game's own minimap."] },
				{ type = "header", label = L["Presets"] },
				{ type = "button", label = L["Classic"], onClick = function() ns.Preset("classic") end, requires = "profile.skin.enabled" },
				{ type = "button", label = L["Modern square"], onClick = function() ns.Preset("modern") end, requires = "profile.skin.enabled" },
				{ type = "button", label = L["Navigator bar"], onClick = function() ns.Preset("navigator") end, requires = "profile.skin.enabled" },
				{ type = "button", label = L["Compass"], onClick = function() ns.Preset("compass") end, requires = "profile.skin.enabled" },
				{ type = "header", label = L["Shape and border"] },
				{ type = "segmented", key = "profile.skin.shape", label = L["Shape"], requires = "profile.skin.enabled",
					items = { { value = "round", label = L["Round"] }, { value = "square", label = L["Square"] }, { value = "rect", label = L["Rectangle"] } } },
				{ type = "select", key = "profile.skin.border", label = L["Border"], requires = "profile.skin.enabled", items = {
					{ value = "none", label = L["Game ring (round, default size)"] }, { value = "thin", label = L["Thin line"] },
					{ value = "metal", label = L["Metal"] }, { value = "soft", label = L["Soft"] }, { value = "double", label = L["Double line"] } } },
				{ type = "color", key = "profile.skin.color", label = L["Border colour"], requires = "profile.skin.enabled" },
				{ type = "slider", key = "profile.skin.width", label = L["Size"], min = 0, max = 700, step = 2, live = false, requires = "profile.skin.enabled",
					format = function(v) return v == 0 and L["game default"] or tostring(v) end },
				{ type = "slider", key = "profile.skin.height", label = L["Height"], min = 100, max = 700, step = 2, live = false,
					requires = "profile.skin.enabled", hidden = notRect },
				{ type = "slider", key = "profile.skin.scale", label = L["Scale of the whole cluster"], min = 0.6, max = 2, step = 0.05, percent = true,
					live = false, requires = "profile.skin.enabled" },
			} },
			{ id = "layout", label = L["Layout"], options = {
				{ type = "toggle", label = L["Unlock: drag the map, resize from its corners"], requires = "profile.skin.enabled",
					get = function() return unlocked end, set = ns.Unlock },
				{ type = "button", label = L["Back to the default place"], requires = "profile.skin.enabled",
					onClick = function() ns.db:Set("profile.skin.position", nil) end },
				{ type = "toggle", key = "profile.skin.attach", label = L["Zone name, clock and buttons follow the map"], requires = "profile.skin.enabled" },
				{ type = "toggle", key = "profile.skin.rotate", label = L["Rotate with the player"], desc = L["Round maps only: the game turns the whole map square."],
					requires = "profile.skin.enabled", disabled = notRound },
				{ type = "toggle", key = "profile.skin.wheelZoom", label = L["Zoom with the mouse wheel"], requires = "profile.skin.enabled" },
			} },
			{ id = "buttons", label = L["Buttons"], options = {
				{ type = "toggle", key = "profile.skin.drawer", label = L["Collect addon buttons into a drawer"], requires = "profile.skin.enabled" },
				{ type = "checklist", key = "profile.skin.hide", label = L["Hide"], height = 130, requires = "profile.skin.enabled", items = {
					{ value = "ring", label = L["Round ring"] }, { value = "header", label = L["Zone name header"] },
					{ value = "tracking", label = L["Tracking button"] }, { value = "calendar", label = L["Calendar"] },
					{ value = "compartment", label = L["Addon compartment"] } } },
			} },
		},
		appearance = "profile.ui",
		profiles = true,
	})
	ns.db:OnChange("profile", ns.Apply)
	FK:Slash({ "/mms", "/minimapstudio" }, {
		[""] = function() ns.options:Open() end,
		unlock = { L["Unlock or lock the map"], function() ns.Unlock(not unlocked) end },
		preset = { L["classic | modern | navigator | compass"], function(name) if ns.PRESETS[name] then ns.Preset(name) end end },
		reset = { L["The game's own minimap"], function() ns.db:Set("profile.skin.enabled", false) end },
	})
	if FK.inWorld then ns.Apply() else FK:Once("fk.world", ns.Apply) end
end)

function MinimapStudio_OnCompartmentClick() ns.options:Open() end
