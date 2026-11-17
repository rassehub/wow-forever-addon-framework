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

-- Journal page: a small codex with original sample text, rendered from markup.
local CODEX = {
	{ label = "Dungeons", icon = "dungeon", subtitle = "Instances for a group of five", value = "dungeons", children = {
		{ label = "The Deadmines", icon = "skull", value = "dm", subtitle = "Westfall  ·  levels 17-26" },
		{ label = "The Stockade", icon = "lock", value = "stocks", subtitle = "Stormwind City  ·  levels 22-30" },
	} },
	{ label = "Professions", icon = "herb", value = "profs", children = {
		{ label = "Herbalism", icon = "herb", value = "herb", subtitle = "Gathering" },
		{ label = "Mining", icon = "ore", value = "mining", subtitle = "Gathering" },
	} },
}
local function codexPage(_, node, section)
	if node.children then
		local lines = { "# " .. node.label, node.subtitle or "", "" }
		for _, c in ipairs(node.children) do lines[#lines + 1] = ("- :%s: [%s](journal:%s)"):format(c.icon or "book", c.label, c.value) end
		return table.concat(lines, "\n")
	end
	if section == "notes" then
		return "## Notes\n> Example text: write your own findings here.\n- :star: Worth a visit\n- :clock: About 45 minutes"
	end
	return ("# %s\n%s\n\n## Overview\nA **sample entry** rendered with RichText. Links like [the category](journal:%s) jump inside the journal.\n\n- :pin: Entrance marked on the map\n- :chest: Several chests inside\n---\n![32](media:Icons/%s)"):format(
		node.label, node.subtitle or "", (node.value == "dm" or node.value == "stocks") and "dungeons" or "profs", node.icon or "book")
end

-- Map page: the client's Eastern Kingdoms world map, 4x3 tiles of 256 px (1002x668 used).
local function worldTiles(zone)
	local tiles = {}
	for i = 1, 12 do
		tiles[i] = { texture = ("Interface\\WorldMap\\%s\\%s%d"):format(zone, zone, i), x = ((i - 1) % 4) * 256, y = math.floor((i - 1) / 4) * 256, w = 256, h = 256 }
	end
	return tiles
end

local QUESTS = {
	{ id = "q1", title = "Wolves Across the Border", icon = "quest", lines = {
		{ text = "Tough Wolf Meat", value = "6/8", progress = 0.75 },
		{ text = "Talk to the hunter", done = true },
	} },
	{ id = "q2", title = "The Fargodeep Mine", icon = "quest", lines = { { text = "Explore the mine" } } },
	{ id = "q3", title = "A Threat Within", icon = "quest-turnin", lines = { { text = "Report to the marshal", done = true } } },
}

-- Minimap page: every MinimapSkin option as a live control. Not saved: /reload or Reset restores.
local skin = { shape = "round", border = "none", width = 198, height = 198, scale = 1, wheelZoom = true, drawer = false, rotate = false, unlock = false, hide = {} }
local minimapRefs
local function applySkin()
	local hide = {}
	for name, on in pairs(skin.hide) do if on then hide[#hide + 1] = name end end
	FK.MinimapSkin.Apply({ shape = skin.shape, border = skin.border, width = skin.width, height = skin.height, scale = skin.scale,
		wheelZoom = skin.wheelZoom, drawer = skin.drawer, rotate = skin.rotate, unlock = skin.unlock, position = skin.position,
		hide = hide, borderColor = "accent",
		onLayout = function(l)
			skin.position, skin.width, skin.height = l.position, l.width, l.height
			if minimapRefs then minimapRefs.width:SetValue(l.width) minimapRefs.height:SetValue(l.height) end
		end })
end
local function set(key) return function(v) skin[key] = v applySkin() end end
function ns.navigator()
	skin.shape, skin.border, skin.width, skin.height, skin.rotate, skin.drawer = "rect", "thin", 460, 230, true, true
	skin.hide = { header = true, ring = true }
	skin.position = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 150 }
	applySkin()
	local r = minimapRefs
	r.shape:SetValue("rect") r.border:SetValue("thin") r.width:SetValue(460) r.height:SetValue(230)
	r.rotate:SetValue(true) r.drawer:SetValue(true) r.hide:SetValue(skin.hide)
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
	{ id = "journal", label = "Journal", build = function(p)
		ns.journal = FK.Journal(p, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, title = "Codex", subtitle = "A sample journal", icon = "book",
			nodes = CODEX, render = codexPage,
			sections = function(node) if not node.children then return { { id = "overview", label = "Overview" }, { id = "notes", label = "Notes" } } end end })
		ns.journal:Select("dm")
	end },
	{ id = "map", label = "Map", build = function(p)
		local map = FK.MapCanvas(p, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, contentWidth = 1002, contentHeight = 668, tiles = worldTiles("Azeroth") })
		map:AddPin(0.43, 0.70, { icon = "skull", tooltip = { "The Deadmines", "Dungeon" } })
		map:AddPin(0.46, 0.57, { icon = "flag", tooltip = "Stormwind" })
		map:AddPin(0.52, 0.38, { icon = "ore", tooltip = "Mining route" })
		ns.map = map
	end },
	{ id = "minimap", label = "Minimap", build = page({
		{ "Label", role = "small", color = "dim", text = "Changes the game's minimap live (FK.MinimapSkin). Nothing is saved: /reload or Reset puts it back." },
		{ "Row", children = {
			{ "Button", text = "Navigator preset", onClick = function() ns.navigator() end },
			{ "Button", text = "Reset", onClick = function() FK.MinimapSkin.Reset() skin.position = nil end },
		} },
		{ "Segmented", id = "shape", label = "Shape", value = "round", onChange = set("shape"),
			items = { { value = "round", label = "Round" }, { value = "square", label = "Square" }, { value = "rect", label = "Rectangle" } } },
		{ "Dropdown", id = "border", label = "Border", value = "none", onChange = set("border"), items = {
			{ value = "none", label = "Game default" }, { value = "thin", label = "Thin (modern)" }, { value = "metal", label = "Metal" },
			{ value = "soft", label = "Soft" }, { value = "double", label = "Double line" } } },
		{ "Slider", id = "width", label = "Width", min = 100, max = 700, step = 2, value = 198, format = "%d", live = false, onChange = set("width") },
		{ "Slider", id = "height", label = "Height (rectangle)", min = 100, max = 700, step = 2, value = 198, format = "%d", live = false, onChange = set("height") },
		{ "Slider", label = "Scale (whole cluster)", min = 0.6, max = 2, step = 0.05, percent = true, value = 1, live = false, onChange = set("scale") },
		{ "Toggle", id = "unlock", label = "Unlock: drag the map to move it, its corner to resize", value = false, onChange = set("unlock") },
		{ "Toggle", id = "rotate", label = "Rotate the map with the player", value = false, onChange = set("rotate") },
		{ "Toggle", label = "Zoom with the mouse wheel", value = true, onChange = set("wheelZoom") },
		{ "Toggle", id = "drawer", label = "Collect addon buttons into a drawer", value = false, onChange = set("drawer") },
		{ "CheckList", id = "hide", label = "Hide", height = 130, value = {}, onChange = function(v) skin.hide = v applySkin() end, items = {
			{ value = "ring", label = "Round ring" }, { value = "header", label = "Zone name header" }, { value = "tracking", label = "Tracking button" },
			{ value = "calendar", label = "Calendar" }, { value = "compartment", label = "Addon compartment" } } },
	}, function(refs) minimapRefs = refs end) },
	{ id = "display", label = "Display", build = function(p)
		local _, refs = FK.Build(p, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, gap = 8, children = {
		{ "TimerBar", id = "timer", label = "TimerBar", duration = 30 },
		{ "BarList", id = "bars", height = 72 },
		{ "IconGrid", id = "icons", size = 32 },
		{ "Row", children = {
			{ "Button", text = "Dialog", onClick = function() FK.Confirm("Delete this goal?", function() end) end },
			{ "Button", text = "Menu", onClick = function(b) FK.Menu({ { label = "Edit" }, { label = "Delete" } }, b) end },
			{ "Button", text = "Toast", onClick = function() FK.Toast("Saved") end },
			{ "Button", text = "Quest tracker", onClick = function() ns.quests:SetShown(not ns.quests:IsShown()) end },
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
	local db = FK:NewDB("FKGalleryDB", { profile = { theme = "pixel", window = {}, quests = {} } })
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
	ns.quests = FK.SectionTracker(UIParent, { title = "Quests", saved = { db, "profile.quests" } })
	ns.quests:SetSections(QUESTS)
	ns.quests:Hide()
	ns.gallery = { window = win, tabs = tabs, theme = pick }
	-- /fkgallery toggles; /fkgallery theme <name> [page] shows a theme and page (used by previews and FKDev runs)
	FK:Slash({ "/fkgallery" }, function(msg)
		-- /fkgallery dialog: the confirm dialog; /fkgallery minimap square metal | round soft | reset
		if msg == "dialog" then return FK.Confirm("Delete this goal?", function() end) end
		local shape, border = msg:match("^minimap%s+(%S+)%s*(%S*)")
		if shape == "reset" then return FK.MinimapSkin.Reset() end
		if shape == "drawer" then return FK.MinimapSkin.drawer and FK.MinimapSkin.drawer.flyout:Show() end
		if shape == "navigator" then ns.gallery.tabs:Select("minimap") return ns.navigator() end
		if shape then
			return FK.MinimapSkin.Apply({ shape = shape, border = border ~= "" and border or "metal", drawer = true, hide = { "ring" } })
		end
		local theme, page = msg:match("^theme%s+(%S+)%s*(%S*)")
		if not theme then return win:Toggle() end
		if FK.Theme.themes[theme] then FK.Theme:Set(theme) end
		if page ~= "" then tabs:Select(page) end
		win:Open()
	end)
	win:Open()
end)
