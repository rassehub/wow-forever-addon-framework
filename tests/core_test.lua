-- ForeverKit core: events, DB, timers, slash, locale, theme registry.
local KIT = ROOT .. "/tests/fixtures/KitTest"

test("lifecycle: OnLoad sees saved variables, OnLogin follows", function()
	H.saved.KitTestDB = { profiles = { Default = { range = 55 } }, profileKeys = {}, chars = {}, global = {} }
	local FK = H.LoadAddon(KIT).FK
	-- H.LoadAddon already fired ADDON_LOADED: a late OnLoad runs at once
	local order = {}
	local db = FK:NewDB("KitTestDB", { profile = { range = 40, scale = 1 } })
	FK:OnLoad(function() order[#order + 1] = "load:" .. db.profile.range end)
	FK:OnLogin(function() order[#order + 1] = "login" end)
	H.Login()
	eq(order, { "load:55", "login" })
	eq(db.profile.scale, 1, "missing keys are filled from defaults")
end)

test("events: game events, own messages, Once and Off", function()
	local FK = H.Start(KIT).FK
	local seen = {}
	local h = FK:On("BAG_UPDATE_DELAYED", function() seen[#seen + 1] = "bag" end)
	FK:Once("goals.changed", function(n) seen[#seen + 1] = "msg" .. n end)
	H.Fire("BAG_UPDATE_DELAYED")
	FK:Emit("goals.changed", 1)
	FK:Emit("goals.changed", 2)
	FK:Off(h)
	H.Fire("BAG_UPDATE_DELAYED")
	eq(seen, { "bag", "msg1" })
end)

test("db: defaults are not written to disk, changed values survive a reload", function()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = { range = 40, window = { scale = 1 } }, char = { goals = {} }, global = { seen = false } })
	db:Set("profile.range", 60)
	db.char.goals[1] = "x"
	H.Fire("PLAYER_LOGOUT")
	local sv = H.CollectSaved().KitTestDB
	eq(sv.profiles.Default, { range = 60 })
	eq(sv.global, {})
	eq(sv.chars["Tester - Emulated"], { goals = { "x" } })
end)

test("db: change listeners hear exact paths, children and resets", function()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = { range = 40, window = { scale = 1, alpha = 1 } } })
	local heard = {}
	db:OnChange("profile.window", function(_, path) heard[#heard + 1] = path end)
	db:Set("profile.window.scale", 1.2)
	db:Set("profile.range", 50)
	db:Set("profile.window.scale", 1.2) -- unchanged: silent
	db:Reset("profile.window")
	eq(heard, { "profile.window.scale", "profile.window" })
	eq(db.profile.window.scale, 1)
	raises(function() db:Set("range", 1) end, "must be profile")
end)

test("db: profiles switch, copy and delete", function()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = { range = 40 } })
	db:Set("profile.range", 70)
	db:SetProfile("Healer")
	eq(db.profile.range, 40)
	db:CopyProfile("Default")
	eq(db.profile.range, 70)
	eq(db:Profiles(), { "Default", "Healer" })
	raises(function() db:DeleteProfile("Healer") end, "active profile")
	db:SetProfile("Default")
	db:DeleteProfile("Healer")
	eq(db:Profiles(), { "Default" })
end)

test("db: migration runs once with the stored version", function()
	H.saved.KitTestDB = { version = 1, profiles = { Default = { distance = 30 } } }
	local FK = H.LoadAddon(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = { range = 40 } }, { version = 2, migrate = function(sv, from)
		eq(from, 1)
		for _, p in pairs(sv.profiles) do p.range, p.distance = p.distance, nil end
	end })
	eq(db.profile.range, 30)
	eq(KitTestDB.version, 2)
end)

test("db: an unversioned saved variable migrates from 0, a new one not at all", function()
	H.saved.KitTestDB = { distance = 30 } -- an addon's own flat table, before it used FK:NewDB
	local FK = H.LoadAddon(KIT).FK
	local froms = {}
	local migrate = function(sv, from)
		froms[#froms + 1] = from
		sv.profiles, sv.distance = { Default = { range = sv.distance } }, nil
	end
	local db = FK:NewDB("KitTestDB", { profile = { range = 40 } }, { version = 1, migrate = migrate })
	eq(db.profile.range, 30)
	eq(KitTestDB.distance, nil)
	H.saved.KitTestDB = nil
	FK = H.LoadAddon(KIT).FK
	FK:NewDB("KitTestDB", { profile = { range = 40 } }, { version = 1, migrate = migrate })
	eq(froms, { 0 })
end)

test("db: reading before load explains itself", function()
	local ns = H.LoadAddon(KIT)
	local FK = ns.FK
	FK.loaded = false
	local db = FK:NewDB("KitTestDB", { profile = {} })
	raises(function() return db.profile end, "FK:OnLoad")
end)

test("timers: debounce keeps the last call, throttle limits the rate", function()
	local FK = H.Start(KIT).FK
	local calls = {}
	local d = FK:Debounce(0.3, function(v) calls[#calls + 1] = v end)
	d(1) d(2) d(3)
	H.Advance(0.5)
	eq(calls, { 3 })
	local n = 0
	local t = FK:Throttle(1, function() n = n + 1 end)
	for _ = 1, 10 do t() H.Advance(0.1) end
	H.Advance(1)
	eq(n, 2)
end)

test("slash: subcommands, default and generated help", function()
	local FK = H.Start(KIT).FK
	local got = {}
	FK:Slash({ "/kit", "/kt" }, {
		[""] = function() got[#got + 1] = "toggle" end,
		scale = { "Set the scale", function(arg) got[#got + 1] = "scale=" .. arg end },
	})
	H.Slash("/kit")
	H.Slash("/kt scale 1.2")
	H.Slash("/kit nonsense")
	eq(got, { "toggle", "scale=1.2" })
	ok(H.log[#H.log]:find("Set the scale"), "unknown subcommand prints help")
end)

test("util: money, numbers, durations, rounding, paths", function()
	local FK = H.Start(KIT).FK
	eq(FK.Money(123456, true), "12g 34s 56c")
	eq(FK.Money(10000, true), "1g")
	eq(FK.Money(0, true), "0c")
	eq(FK.Number(1234567), "1,234,567")
	eq(FK.Number(1500, true), "1.5k")
	eq(FK.Duration(95), "1m 35s")
	eq(FK.Round(0.1 + 0.2, 0.05), 0.3)
	local t = {}
	FK.SetPath(t, "a.b.c", 5)
	eq(FK.GetPath(t, "a.b.c"), 5)
	eq(FK.GetPath(t, "a.x.c"), nil)
end)

test("locale: keys fall back to themselves", function()
	H.fixtures.locale = "deDE"
	local FK = H.Start(KIT).FK
	FK:Locale("deDE", { ["Search"] = "Suchen" })
	FK:Locale("frFR", { ["Search"] = "Rechercher" })
	eq(FK.L["Search"], "Suchen")
	eq(FK.L["Not translated"], "Not translated")
	H.fixtures.locale = nil
end)

test("themes: extending merges groups but replaces specs", function()
	local FK = H.Start(KIT).FK
	local vanilla, base = FK.Theme.themes.vanilla, FK.Theme.themes.base
	ok(vanilla.surface.button.normal.texture and not vanilla.surface.button.normal.border, "a spec replaces the base spec")
	eq(vanilla.metric.row, base.metric.row, "untouched keys are inherited")
	eq(vanilla.color.heading, { 1, 0.82, 0 })
	eq(FK.Theme:Names(), { "glass", "midnight", "modern", "parchment", "pixel", "vanilla" })
	eq(H.LeakedGlobals("KitTest"), {})
end)

test("themes: every theme has every colour, font, metric and surface of base", function()
	local FK = H.Start(KIT).FK
	local base = FK.Theme.themes.base
	for _, name in ipairs(FK.Theme:Names()) do
		local t = FK.Theme.themes[name]
		for _, group in ipairs({ "color", "font", "metric", "surface", "icon" }) do
			for k in pairs(base[group]) do ok(t[group][k] ~= nil, name .. "." .. group .. "." .. k) end
		end
	end
end)
