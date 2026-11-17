-- Emulator tests for the minimap customiser.

test("the saved style is applied once in the world, settings re-apply it, off restores the game's map", function()
	local ns = H.Start(ADDON)
	eq({ Minimap:GetSize() }, { 140, 140 }, "width 0: the game's own size")
	ok(ns.FK.MinimapSkin.ring:IsShown(), "default: round with a thin ring")
	ns.db:Set("profile.skin.shape", "square")
	ok(ns.FK.MinimapSkin.border:IsShown() and not ns.FK.MinimapSkin.ring:IsShown())
	ns.db:Set("profile.skin.width", 240)
	eq({ Minimap:GetSize() }, { 240, 240 })
	ns.db:Set("profile.skin.enabled", false)
	eq({ Minimap:GetSize() }, { 140, 140 })
	ok(not ns.FK.MinimapSkin.border:IsShown())
end)

test("presets: navigator bar is a rectangle at the bottom; saved across a reload", function()
	local ns = H.Start(ADDON)
	H.Slash("/mms preset navigator")
	eq({ ns.FK.MinimapSkin.view:GetSize() }, { 460, 230 })
	eq(select(1, Minimap:GetPoint(1)), "BOTTOM")
	ns = H.Reload()
	eq({ ns.FK.MinimapSkin.view:GetSize() }, { 460, 230 }, "the layout comes back after /reload")
	H.Slash("/mms preset classic")
	eq({ Minimap:GetSize() }, { 140, 140 })
	eq(select(1, Minimap:GetPoint(1)), "TOPRIGHT", "classic goes back to the game's place")
end)

test("unlock: dragging and resizing are saved without re-applying in the middle", function()
	local ns = H.Start(ADDON)
	H.Slash("/mms preset modern")
	ns.Unlock(true)
	local h = ns.FK.MinimapSkin.handle
	ok(h:IsShown())
	H.Drag(h, -200, -100)
	local pos = ns.db.profile.skin.position
	ok(pos and pos.point, "position saved")
	H.Drag(h.grips.BOTTOMLEFT, -40, -40)
	eq(ns.db.profile.skin.width, 260)
	ns.Unlock(false)
	ok(not h:IsShown())
	local x = ns.db.profile.skin.position.x
	ns = H.Reload()
	eq({ Minimap:GetSize() }, { 260, 260 })
	eq(ns.db.profile.skin.position.x, x)
end)

test("every settings page lays out cleanly in every theme; no globals leak", function()
	local ns = H.Start(ADDON)
	H.Slash("/mms")
	ok(ns.options.window:IsShown())
	for _, theme in ipairs(ns.FK.Theme:Names()) do
		ns.FK.Theme:Set(theme)
		for _, page in ipairs({ "shape", "layout", "buttons" }) do
			ns.options:Open(page)
			H.Advance(0)
			eq(H.LayoutIssues(ns.options.window), {}, theme .. "/" .. page)
		end
	end
	eq(H.LeakedGlobals("MinimapStudio"), {})
end)
