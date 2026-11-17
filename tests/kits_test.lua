-- Layout kits (step 14): RichText, Journal.
local KIT = ROOT .. "/tests/fixtures/KitTest"

local function kit(theme, w, h)
	local FK = H.Start(KIT).FK
	if theme then FK.Theme:Set(theme) end
	local win = FK.Window(UIParent, { title = "Kit", width = w or 640, height = h or 460 })
	win:Open()
	H.Advance(0)
	return FK, win
end

local PAGE = [[
# The Deadmines
A hideout of the **Defias Brotherhood** below Moonbrook. See [Edwin VanCleef](npc:639).
Joined line of the same paragraph.

## Bosses
- Rhahk'Zor :skull:
- Sneed
  - Sneed's Shredder
> Bring a group of five.
---
![24](media:Icons/dungeon)
]]

test("rich text: markup parses into blocks", function()
	local FK = H.Start(KIT).FK
	local b = FK.ParseRichText(PAGE)
	local kinds = {}
	for i, x in ipairs(b) do kinds[i] = x.kind end
	eq(kinds, { "h1", "p", "h2", "li", "li", "li", "quote", "hr", "img" })
	eq(b[2].text, "A hideout of the **Defias Brotherhood** below Moonbrook. See [Edwin VanCleef](npc:639). Joined line of the same paragraph.")
	eq(b[6].level, 1)
	eq({ b[9].width, b[9].height, b[9].path }, { 24, 24, "media:Icons/dungeon" })
	ok(FK.RichInline("[x](y)", 12):find("|Hfk:y|h", 1, true))
	ok(FK.RichInline(":skull:", 12):find("Media\\Icons\\skull.png", 1, true))
	eq(FK.RichInline(":not-an-icon:", 12), ":not-an-icon:", "unknown names stay text")
end)

for _, theme in ipairs({ "pixel", "vanilla", "glass", "parchment", "modern", "midnight" }) do
	test(theme .. ": rich text lays out, links click, height follows content", function()
		local FK, win = kit(theme)
		local clicked
		local rt = FK.RichText(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, text = PAGE,
			onLink = function(target, button) clicked = target .. "/" .. button end })
		H.Advance(0)
		ok(rt:GetHeight() > 120, "height " .. rt:GetHeight())
		H.ClickLink(rt, "npc:639", "RightButton")
		eq(clicked, "npc:639/RightButton")
		eq(H.LayoutIssues(win), {})
	end)
end

-- a visible font string containing `text`
local function shows(root, text)
	return H.FindAll(root, function(o)
		return o[0].type == "FontString" and H.plain(o[0].text or ""):find(text, 1, true) ~= nil and o:IsVisible()
	end)[1]
end

local function nodes()
	return {
		{ label = "Dungeons", icon = "dungeon", value = "dungeons", subtitle = "Five-player instances", children = {
			{ label = "The Deadmines", value = "dm", icon = "skull", subtitle = "Westfall, level 17-26" },
			{ label = "The Stockade", value = "stocks", subtitle = "Stormwind, level 22-30" },
		} },
		{ label = "Raids", icon = "flag", value = "raids", children = {
			{ label = "Molten Core", value = "mc" },
		} },
	}
end

for _, theme in ipairs({ "modern", "vanilla", "midnight" }) do
	test(theme .. ": journal selects, shows header, breadcrumb, sections, cached pages", function()
		local FK, win = kit(theme, 760, 520)
		local renders = 0
		local j = FK.Journal(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, title = "Codex", icon = "book",
			nodes = nodes(),
			sections = function(node) if not node.children then return { { id = "overview", label = "Overview" }, { id = "loot", label = "Loot" } } end end,
			render = function(page, node, section)
				renders = renders + 1
				return ("# %s\n%s page of **%s**."):format(node.label, section or "summary", node.label)
			end })
		H.Advance(0)
		j:Select("dm")
		H.Advance(0)
		eq(j.header.title:GetText(), "The Deadmines")
		eq(j.header.subtitle:GetText(), "Westfall, level 17-26")
		ok(j.crumb.text:GetText():find("Dungeons", 1, true))
		ok(shows(win, "overview page of"), "first section shown")
		j:Select("dm", "loot")
		H.Advance(0)
		ok(shows(win, "loot page of"))
		ok(not shows(win, "overview page of"), "the other section is hidden")
		j:Select("stocks")
		local before = renders
		j:Select("dm")
		eq(select(2, j:GetSelected()), "loot", "the section is remembered")
		eq(renders, before, "going back shows the cached page, nothing is rebuilt")
		-- breadcrumb: back to the category
		H.ClickLink(j.crumb, "crumb:1")
		eq(j:GetSelected().value, "dungeons")
		eq(H.LayoutIssues(win), {})
	end)
end

test("journal: search filters the tree and keeps parents", function()
	local FK, win = kit("pixel", 760, 520)
	local j = FK.Journal(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, title = "Codex", nodes = nodes(),
		render = function(_, node) return node.label end })
	H.Advance(0)
	H.Enter(j.search.box, "molten")
	H.Advance(1)
	local shown = {}
	for _, n in ipairs(j.tree.list.items) do shown[#shown + 1] = n.label end
	eq(shown, { "Raids", "Molten Core" })
	H.Click(H.Find(j.tree, "Molten Core"):GetParent())
	eq(j:GetSelected().value, "mc", "a filtered row selects the real node")
	eq(H.LeakedGlobals("KitTest"), {})
end)

local function mapKit(theme)
	local FK, win = kit(theme, 640, 480)
	local clicks = {}
	local map = FK.MapCanvas(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, contentWidth = 1000, contentHeight = 500,
		tiles = { { texture = "media:Frames/soft", x = 0, y = 0, w = 500, h = 500 }, { texture = "media:Frames/metal", x = 500, y = 0, w = 500, h = 500 } },
		onClick = function(x, y, button) clicks[#clicks + 1] = { x, y, button } end })
	H.Advance(0)
	return FK, win, map, clicks
end

test("map canvas: fits, zooms around a point, pans by dragging, clamps to the content", function()
	local FK, win, map, clicks = mapKit("modern")
	local s1 = map:Scale()
	near(s1, map:GetWidth() / 1000, 0.001, "zoom 1 fits the width")
	-- the point under a screen spot stays there when zooming
	map:SetZoom(2, 0.25, 0.5)
	local cl, ct = map.canvas:GetLeft(), map.canvas:GetTop()
	local sx = (0.25 * 1000 - map.panX) * map:Scale()
	near(sx, (0.25 * 1000) * s1, 0.6, "x of the zoom point unchanged on screen")
	eq(map:GetZoom(), 2)
	-- drag pans the opposite way of the mouse
	local px = map.panX
	H.Drag(map, -100, 0)
	ok(map.panX > px, "dragging left moves the view right: " .. px .. " -> " .. map.panX)
	eq(#clicks, 0, "a drag is not a click")
	-- clamped: cannot pan past the edge
	map:CenterOn(1, 1)
	local s = map:Scale()
	near(map.panX + map:GetWidth() / s, 1000, 0.6, "right edge")
	eq(H.LayoutIssues(win), {})
end)

test("map canvas: click reports content coordinates; pins keep their size and follow", function()
	local FK, win, map, clicks = mapKit("midnight")
	H.Click(map)
	eq(#clicks, 1)
	near(clicks[1][1], 0.5, 0.01) near(clicks[1][2], 0.5, 0.06)
	local tipped
	local pin = map:AddPin(0.6, 0.5, { icon = "skull", size = 18, tooltip = "Boss", onClick = function() tipped = true end })
	H.Advance(0)
	local w1 = pin:GetWidth()
	local x1 = pin:GetCenter()
	map:SetZoom(3, 0.5, 0.5)
	eq(pin:GetWidth(), w1, "pins do not scale")
	ok(pin:GetCenter() > x1, "a pin right of the zoom point moves right")
	H.Click(pin)
	ok(tipped)
	H.Hover(pin)
	eq(H.TooltipLines(), { "Boss" })
	pin:Remove()
	ok(not pin:IsShown())
	H.Wheel(map, 1)
	near(map:GetZoom(), 3.75, 0.01)
	eq(H.LeakedGlobals("KitTest"), {})
end)

local QUESTS = {
	{ id = "q1", title = "Wolves Across the Border", icon = "quest", lines = {
		{ text = "Tough Wolf Meat", value = "6/8", progress = 0.75 },
		{ text = "Talk to Eagan Peltskinner", done = true },
	} },
	{ id = "q2", title = "A Threat Within", icon = "quest-turnin", lines = { { text = "Report to Marshal McBride", done = true } } },
}

for _, theme in ipairs({ "pixel", "vanilla", "glass", "parchment", "modern", "midnight" }) do
	test(theme .. ": section tracker shows sections, counts, collapses and remembers", function()
		local FK = H.Start(KIT).FK
		FK.Theme:Set(theme)
		local db = FK:NewDB("KitTestDB", { profile = { tracker = {} } })
		local t = FK.SectionTracker(UIParent, { title = "Quests", saved = { db, "profile.tracker" } })
		t:SetSections(QUESTS)
		H.Advance(0)
		ok(H.Find(t, "Wolves Across the Border"))
		ok(H.Find(t, "1/2"), "header counter from done lines")
		ok(H.Find(t, "Tough Wolf Meat"))
		local h1 = t:GetHeight()
		H.Click(H.Find(t, "Wolves Across the Border"):GetParent())
		ok(not H.Find(t, "Tough Wolf Meat"), "collapsed")
		ok(t:GetHeight() < h1)
		eq(db.profile.tracker.collapsed, { q1 = true })
		eq(H.LayoutIssues(t), {})
	end)
end
