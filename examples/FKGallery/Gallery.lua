local _, ns = ...
local FK = ns.FK

-- Showcase of every ForeverKit widget, one page per family, with a live theme switcher.
-- Also the reference used for preview screenshots: `fk preview FKGallery --theme a,b --do "ns.gallery.tabs:Select('rows')"`.

local ITEMS = { "Say", "Party", "Raid", "Guild" }

local function page(children, after)
	return function(p)
		local _, refs = FK.Build(p, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, gap = 8, children = children })
		if after then after(refs) end
	end
end

local PAGES = {
	{ id = "controls", label = "Controls", build = page({
		{ "Heading", text = "Text" },
		{ "Label", text = "A Label wraps to the width it is given. Colours come from the theme." },
		{ "Label", role = "small", color = "dim", text = "Small, dim text for descriptions." },
		{ "Heading", text = "Buttons" },
		{ "Row", children = {
			{ "Button", text = "Button" },
			{ "Button", text = "Disabled", id = "off" },
			{ "IconButton", icon = "cog" },
			{ "IconButton", icon = "plus" },
		} },
		{ "Heading", text = "Switches" },
		{ "Grid", columns = 2, children = {
			{ "CheckBox", label = "CheckBox", value = true },
			{ "Toggle", label = "Toggle", value = true },
			{ "CheckBox", label = "Unticked" },
			{ "Toggle", label = "Off" },
		} },
		{ "Heading", text = "Numbers" },
		{ "Slider", label = "Range", min = 5, max = 80, value = 40, format = "%d yd" },
		{ "Slider", label = "Opacity", min = 0, max = 1, step = 0.05, percent = true, value = 0.85 },
		{ "RangeSlider", label = "Level range", min = 1, max = 60, value = { 20, 35 } },
		{ "Stepper", label = "Columns", min = 1, max = 8, value = 4 },
		{ "Heading", text = "Text input" },
		{ "EditBox", label = "EditBox", placeholder = "Type here" },
		{ "SearchBox" },
		{ "MoneyInput", label = "MoneyInput", value = 123456 },
		{ "ProgressBar", min = 0, max = 100, value = 64, format = "%d / 100" },
	}, function(refs) refs.off:SetEnabled(false) end) },
	{ id = "choices", label = "Choices", build = page({
		{ "Dropdown", label = "Dropdown", items = ITEMS, value = "Party" },
		{ "MultiDropdown", label = "MultiDropdown", items = ITEMS, value = { Say = true, Guild = true } },
		{ "Segmented", label = "Segmented", items = { "Left", "Center", "Right" }, value = "Center" },
		{ "RadioGroup", label = "RadioGroup", items = { "Only my own", "Everyone in the group", "Nobody" }, value = "Nobody" },
		{ "ColorSwatch", label = "ColorSwatch", value = { 0.2, 0.7, 1 } },
		{ "KeybindButton", label = "KeybindButton", value = "CTRL-SHIFT-K" },
	}) },
	{ id = "rows", label = "Settings rows", build = page({
		{ "ToggleRow", label = "ToggleRow", desc = "A switch with a description line.", value = true },
		{ "SliderRow", label = "SliderRow", min = 0.5, max = 1.5, step = 0.05, value = 1 },
		{ "ToggleSliderRow", label = "ToggleSliderRow", desc = "The amount only matters while it is on.", enabled = true, min = 0, max = 1, percent = true, value = 0.4 },
		{ "ToggleDropdownRow", label = "ToggleDropdownRow", enabled = false, items = ITEMS, value = "Party" },
		{ "ToggleListRow", label = "ToggleListRow", enabled = true, children = {
			{ "Dropdown", label = "Sound", items = { "Bell", "Horn" }, value = "Bell" },
			{ "Slider", label = "Volume", min = 0, max = 1, percent = true, value = 1 },
		} },
		{ "ReorderList", label = "ReorderList", items = { "Name", "Count", "Price" }, toggles = { Name = true, Count = true }, height = 90 },
		{ "CheckList", label = "CheckList", items = { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn" }, value = { Silverleaf = true }, search = true, height = 140 },
	}) },
	{ id = "collections", label = "Collections", build = function(p)
		local table = FK.Table(p, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, height = 130, columns = {
			{ key = "name", label = "Item", flex = 1 },
			{ key = "count", label = "Count", width = 60, align = "RIGHT" },
			{ key = "price", label = "Price", width = 110, align = "RIGHT", format = function(v) return FK.Money(v) end },
		}, items = {
			{ name = "Linen Cloth", count = 40, price = 1250 }, { name = "Copper Ore", count = 12, price = 3400 },
			{ name = "Peacebloom", count = 7, price = 95 }, { name = "Arcane Crystal", count = 1, price = 1850000 },
		}, sortKey = "price", sortDescending = true })
		local tree = FK.Tree(p, { height = 150, nodes = {
			{ label = "Elwynn Forest", expanded = true, children = { { label = "A Threat Within" }, { label = "Wolves Across the Border" } } },
			{ label = "Westfall", children = { { label = "The Defias Brotherhood" } } },
		} })
		tree:SetPoint("TOPLEFT", table, "BOTTOMLEFT", 0, -10)
		tree:SetPoint("RIGHT", p, "CENTER", -5, 0)
		local list = FK.ScrollList(p, { height = 150, selectable = true, striped = true, items = {
			"Ironforge", "Stormwind", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity", "Booty Bay", "Gadgetzan",
		} })
		list:SetPoint("TOPLEFT", tree, "TOPRIGHT", 10, 0)
		list:SetPoint("RIGHT", p)
		local ta = FK.TextArea(p, { label = "TextArea", value = "Multi-line notes.\nSecond line." , height = 70 })
		ta:SetPoint("TOPLEFT", tree, "BOTTOMLEFT", 0, -10)
		ta:SetPoint("RIGHT", p)
	end },
	{ id = "display", label = "Display", build = function(p)
		local _, refs = FK.Build(p, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, gap = 8, children = {
		{ "TimerBar", id = "timer", label = "TimerBar", duration = 30 },
		{ "BarList", id = "bars", height = 72 },
		{ "IconGrid", id = "icons", size = 32 },
		{ "Row", children = {
			{ "Button", text = "Dialog", onClick = function() FK.Confirm("Delete this goal?", function() end) end },
			{ "Button", text = "Menu", onClick = function(b) FK.Menu({ { label = "Edit" }, { label = "Delete" } }, b) end },
			{ "Button", text = "Toast", onClick = function() FK.Toast("Saved") end },
		} },
	} })
		refs.timer:Start(30)
		refs.bars:SetItems({ { label = "Mage", value = 1500 }, { label = "Rogue", value = 1100 }, { label = "Priest", value = 400 } })
		local icons = {}
		for i = 1, 12 do icons[i] = { icon = 134400, count = i % 4 == 0 and 20 or nil, quality = i % 5 } end
		refs.icons:SetItems(icons)
	end },
}

FK:OnLogin(function()
	local db = FK:NewDB("FKGalleryDB", { profile = { theme = "pixel", window = {} } })
	FK.Theme:Set(db.profile.theme)
	local win = FK.Window(UIParent, { title = "ForeverKit Gallery", width = 760, height = 560, resizable = true, saved = { db, "profile.window" } })
	local themes = {}
	for name, t in pairs(FK.Theme.themes) do
		if not t.abstract then themes[#themes + 1] = { value = name, label = t.label } end
	end
	table.sort(themes, function(a, b) return a.value < b.value end)
	local pick = FK.Dropdown(win.content, { items = themes, value = db.profile.theme, width = 200, onChange = function(v)
		FK.Theme:Set(v)
	end })
	pick:SetPoint("TOPRIGHT")
	FK:On("fk.theme", function(name) db.profile.theme = name pick:SetValue(name) end) -- also when set from elsewhere
	local tabs = FK.Tabs(win.content, { side = true, sideWidth = 120, tabs = PAGES })
	tabs:SetPoint("TOPLEFT", 0, -(pick:GetHeight() + 8))
	tabs:SetPoint("BOTTOMRIGHT")
	ns.gallery = { window = win, tabs = tabs, theme = pick }
	-- /fkgallery toggles; /fkgallery theme <name> [page] shows a theme and page (used by previews and FKDev runs)
	FK:Slash({ "/fkgallery" }, function(msg)
		local theme, page = msg:match("^theme%s+(%S+)%s*(%S*)")
		if not theme then return win:Toggle() end
		if FK.Theme.themes[theme] then FK.Theme:Set(theme) end
		if page ~= "" then tabs:Select(page) end
		win:Open()
	end)
	win:Open()
end)
