-- Emulator tests: tools/fk test addons/__NAME__ (ADDON is this addon's folder).

test("warns once when the bags fill up past the setting", function()
	local ns = H.Start(ADDON)
	local function warnings()
		local n = 0
		for _, line in ipairs(H.log) do if line:find("nearly full") then n = n + 1 end end
		return n
	end
	eq(warnings(), 0)
	ns.db:Set("profile.warn.freeSlots", 14)
	ns.Check()
	eq(warnings(), 1)
	ns.Check()
	eq(warnings(), 1, "not repeated")
	ns.db:Set("profile.warn.enabled", false)
	ns.Check()
	ns.db:Set("profile.warn.enabled", true)
	ns.Check()
	eq(warnings(), 2, "warns again after it was cleared")
end)

test("the settings page opens and lays out cleanly", function()
	local ns = H.Start(ADDON)
	H.Slash("/__SLUG__")
	ok(ns.options.window:IsShown())
	eq(H.LayoutIssues(ns.options.window), {})
	eq(H.LeakedGlobals("__NAME__"), {})
end)
