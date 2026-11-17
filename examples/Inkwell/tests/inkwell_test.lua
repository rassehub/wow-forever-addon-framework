-- Emulator tests for the wiki showcase.

local function shows(root, text)
	return H.FindAll(root, function(o)
		return o[0].type == "FontString" and H.plain(o[0].text or ""):find(text, 1, true) ~= nil and o:IsVisible()
	end)[1]
end

test("the welcome page shows; a link to a missing page creates it in a folder and opens the editor", function()
	local ns = H.Start(ADDON)
	H.Slash("/ink")
	ok(ns.window:IsShown())
	ok(shows(ns.window, "Welcome to Inkwell"))
	H.ClickLink(shows(ns.window, "another page"):GetParent(), "page:Professions/Herbalism")
	ok(ns.db.global.pages["Professions/Herbalism"], "page created")
	eq(select(2, ns.journal:GetSelected()), "edit")
	eq(ns.journal.tree.list.items[1].label, "Professions", "folders come first")
	eq(H.LayoutIssues(ns.window), {})
end)

test("edit and save renders the markup; back returns to the previous page; saved across reload", function()
	local ns = H.Start(ADDON)
	H.Slash("/ink Herbs")
	local page = ns.journal.pages[ns.journal:GetSelected()].pages.edit
	H.Enter(page.editor.box, "# Herbs\nPeacebloom grows **everywhere**. See [the welcome](page:Welcome).")
	H.Click(H.Find(page, "Save"):GetParent())
	ok(shows(ns.window, "Peacebloom grows"), "the read tab shows the new text")
	eq(select(2, ns.journal:GetSelected()), "read")
	H.ClickLink(shows(ns.window, "the welcome"):GetParent(), "page:Welcome")
	eq(ns.journal:GetSelected().value, "Welcome")
	ns.Back()
	eq(ns.journal:GetSelected().value, "Herbs")
	ns = H.Reload()
	ok(ns.db.global.pages.Herbs.text:find("everywhere"))
end)

test("new page from the title bar, delete with confirmation", function()
	local ns = H.Start(ADDON)
	H.Slash("/ink")
	ns.Open("Scratch")
	ok(ns.db.global.pages.Scratch)
	local page = ns.journal.pages[ns.journal:GetSelected()].pages.edit
	H.Click(H.Find(page, "Delete page"):GetParent())
	H.Click(H.Find(UIParent, "Yes"):GetParent())
	ok(not ns.db.global.pages.Scratch)
	ok(ns.journal:GetSelected(), "another page is shown")
end)

test("lays out in every theme, read and edit; no leaked globals", function()
	local ns = H.Start(ADDON)
	H.Slash("/ink")
	for _, theme in ipairs(ns.FK.Theme:Names()) do
		ns.FK.Theme:Set(theme)
		for _, section in ipairs({ "read", "edit" }) do
			ns.journal:Select("Welcome", section)
			H.Advance(0)
			eq(H.LayoutIssues(ns.window), {}, theme .. "/" .. section)
		end
	end
	eq(H.LeakedGlobals("Inkwell"), {})
end)
