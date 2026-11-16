-- Options DSL: schema -> panel, bound to the db; profiles; appearance; Blizzard Settings entry.
local KIT = ROOT .. "/tests/fixtures/KitTest"

local DEFAULTS = { profile = {
	tracker = { shown = true, scale = 1 }, fade = { enabled = false, amount = 0.5 }, channel = "Party",
	sound = { enabled = true, name = "Bell", volume = 0.8 }, color = { 1, 0.82, 0 }, herbs = { Peacebloom = true, Silverleaf = false },
	rows = 4, name = "", order = { "Name", "Count" }, key = false,
	ui = { theme = "vanilla", opacity = 1, fontDelta = 0 },
} }

local function setup()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", FK.Copy(DEFAULTS))
	FK:BindAppearance(db, "profile.ui")
	local clicked = 0
	local options = FK:Options({ db = db, appearance = "profile.ui", profiles = true, pages = {
		{ id = "general", label = "General", options = {
			{ type = "header", label = "Tracker" },
			{ type = "toggle", key = "profile.tracker.shown", label = "Show the tracker", desc = "A small window." },
			{ type = "slider", key = "profile.tracker.scale", label = "Scale", min = 0.5, max = 1.5, step = 0.05, requires = "profile.tracker.shown" },
			{ type = "slider", key = "profile.fade.amount", toggleKey = "profile.fade.enabled", label = "Fade when idle", min = 0, max = 1, percent = true },
			{ type = "select", key = "profile.channel", label = "Announce to", items = { "Say", "Party", "Guild" } },
			{ type = "group", label = "Sounds", toggleKey = "profile.sound.enabled", children = {
				{ type = "select", key = "profile.sound.name", label = "Sound", items = { "Bell", "Horn" } },
				{ type = "slider", key = "profile.sound.volume", label = "Volume", min = 0, max = 1, percent = true },
			} },
			{ type = "color", key = "profile.color", label = "Text colour" },
			{ type = "stepper", key = "profile.rows", label = "Rows", min = 1, max = 12 },
			{ type = "input", key = "profile.name", label = "Name" },
			{ type = "button", label = "Test", onClick = function() clicked = clicked + 1 end },
		} },
		{ id = "lists", label = "Lists", options = {
			{ type = "checklist", key = "profile.herbs", label = "Herbs", items = { "Peacebloom", "Silverleaf" }, height = 100 },
			{ type = "reorder", key = "profile.order", label = "Columns", items = { "Name", "Count" } },
		} },
	} })
	options:Open()
	H.Advance(0)
	return FK, db, options
end

local function row(options, label)
	return H.Find(options.window, label) or error("no control labelled " .. label)
end

-- the OptionRow widget that owns a label
local function owner(fs)
	local f = fs:GetParent()
	while f and f.kind ~= "OptionRow" do f = f:GetParent() end
	return f
end

test("every option reads its value from the db and writes back", function()
	local FK, db, options = setup()
	local scale = owner(row(options, "Scale"))
	eq(scale:GetValue(), 1)
	H.Slide(scale.control.slider, 1.2)
	eq(db.profile.tracker.scale, 1.2)
	local shown = owner(row(options, "Show the tracker"))
	H.Click(shown.toggle.button)
	eq(db.profile.tracker.shown, false)
	ok(not scale:IsEnabled(), "requires: scale is disabled while the tracker is hidden")
	local fade = owner(row(options, "Fade when idle"))
	ok(not fade.control:IsEnabled())
	H.Click(fade.toggle.button)
	eq(db.profile.fade.enabled, true)
	H.Slide(fade.control.slider, 0.25)
	eq(db.profile.fade.amount, 0.25)
	eq(H.LayoutIssues(options.window), {})
	eq(FK.warnings, {})
end)

test("groups unfold with their switch; nested options are bound", function()
	local _, db, options = setup()
	local group = owner(row(options, "Sounds"))
	ok(group.body:IsShown())
	local volume = owner(row(options, "Volume"))
	H.Slide(volume.control.slider, 0.3)
	eq(db.profile.sound.volume, 0.3)
	H.Click(group.toggle.button)
	eq(db.profile.sound.enabled, false)
	ok(not group.body:IsShown())
end)

test("external db changes and the Defaults button refresh the controls", function()
	local _, db, options = setup()
	local scale = owner(row(options, "Scale"))
	db:Set("profile.tracker.scale", 0.7)
	eq(scale:GetValue(), 0.7)
	db:Set("profile.rows", 9)
	local defaults = H.Find(options.window, "Defaults"):GetParent()
	local area = defaults
	while area.kind ~= "ScrollArea" do area = area:GetParent() end
	area:ScrollTo(99999) -- the button is at the bottom of a page taller than the window
	H.Click(defaults)
	eq(db.profile.tracker.scale, 1)
	eq(db.profile.rows, 4)
	eq(scale:GetValue(), 1)
end)

test("checklist values are stored with explicit false", function()
	local _, db, options = setup()
	local tabs = options.window.content:GetChildren()
	tabs:Select("lists")
	H.Advance(0)
	local list = H.Find(options.window, "Herbs"):GetParent()
	eq(list:GetValue(), { Peacebloom = true })
	list.list:Refresh()
	H.Click(list.list.rows[1])
	eq(db.profile.herbs, { Peacebloom = false, Silverleaf = false })
	eq(H.LayoutIssues(options.window), {})
end)

test("appearance page switches theme and opacity live", function()
	local FK, db, options = setup()
	eq(FK.Theme.name, "vanilla")
	local tabs = options.window.content:GetChildren()
	tabs:Select("fk-appearance")
	H.Advance(0)
	local theme = owner(row(options, "Theme"))
	H.Click(theme.control.button)
	FK.Popup:Pick("Pixel (flat dark)")
	eq(db.profile.ui.theme, "pixel")
	eq(FK.Theme.name, "pixel")
	H.Advance(0)
	eq(H.LayoutIssues(options.window), {})
	db:Set("profile.ui.opacity", 0.5)
	eq(FK.Theme.opacity, 0.5)
end)

test("profiles page: new, switch, export and import", function()
	local FK, db, options = setup()
	db:Set("profile.rows", 7)
	local tabs = options.window.content:GetChildren()
	tabs:Select("fk-profiles")
	H.Advance(0)
	eq(H.LayoutIssues(options.window), {})
	H.Click(H.Find(options.window, "New"):GetParent())
	H.Type("Healer")
	H.Click(H.Find(H.Find("KitTestFKDialog"), "Accept"):GetParent())
	eq(db:GetProfile(), "Healer")
	eq(db.profile.rows, 4)
	local exported
	db:SetProfile("Default")
	exported = db:Export()
	ok(exported:find("rows"), exported)
	db:SetProfile("Healer")
	ok(db:Import(exported))
	eq(db.profile.rows, 7)
	local good, err = db:Import("print('hi')")
	ok(not good and err, "pasted code is rejected, not run")
end)

test("serialize round-trips nested data and refuses code", function()
	local FK = H.Start(KIT).FK
	local data = { a = 1, b = "two \"quoted\"\nline", c = { true, false, 3.5 }, [7] = { x = -2 } }
	eq(FK.Deserialize(FK.Serialize(data)), data)
	eq(FK.Deserialize("os.exit()"), nil)
	eq(FK.Deserialize("{[1]=function() end}"), nil)
end)

test("the game's Settings window gets a category that builds on first show", function()
	local _, _, options = setup()
	local category = H.settingsCategories[1]
	eq(category.name, "KitTest")
	ok(category.registered)
	Settings.OpenToCategory(category:GetID())
	H.Advance(0)
	ok(H.Find(SettingsPanel, "Show the tracker"), "the same options appear in the Blizzard panel")
	eq(H.LayoutIssues(SettingsPanel), {})
end)

test("a numeric select in a schema raises the slider warning", function()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = { range = "40 yd" } })
	FK:Options({ db = db, options = { { type = "select", key = "profile.range", label = "Range", items = { "20 yd", "40 yd", "60 yd", "80 yd" } } } }):Open()
	ok(FK.warnings[1] and FK.warnings[1]:find("ui%-enum%-should%-be%-slider"))
end)
