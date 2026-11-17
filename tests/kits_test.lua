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
