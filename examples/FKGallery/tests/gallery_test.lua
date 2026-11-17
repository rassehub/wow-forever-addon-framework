local GALLERY = ROOT .. "/examples/FKGallery"

test("gallery: every page in every theme lays out cleanly", function()
	local ns = H.Start(GALLERY)
	local g = ns.gallery
	ok(g.window:IsShown(), "opens on login")
	for _, theme in ipairs(ns.FK.Theme:Names()) do
		ns.FK.Theme:Set(theme)
		eq(g.theme:GetValue(), theme, "dropdown follows the theme")
		for _, id in ipairs({ "controls", "choices", "rows", "collections", "journal", "display" }) do
			g.tabs:Select(id)
			H.Advance(0)
			eq(H.LayoutIssues(g.window), {}, theme .. "/" .. id)
		end
	end
	eq(H.LeakedGlobals("FKGallery"), {})
end)

test("gallery: the theme choice is saved", function()
	local ns = H.Start(GALLERY)
	ns.FK.Theme:Set("parchment")
	ns = H.Reload()
	eq(ns.FK.Theme.name, "parchment")
end)
