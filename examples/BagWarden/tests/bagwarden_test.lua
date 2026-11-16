-- Emulator tests for the settings-heavy example.

local function warnings()
	local n = 0
	for _, line in ipairs(H.log) do if line:find("free") and not line:find("slot%(s%) in counted") then n = n + 1 end end
	return n
end

test("warns once when the counted bags fill up, repeats when asked", function()
	local ns = H.Start(ADDON)
	eq(ns.Free(), 14)
	eq(warnings(), 0)
	ns.db:Set("profile.warn.freeSlots", 14)
	eq(warnings(), 1)
	ns.Check()
	eq(warnings(), 1, "not repeated")
	ns.db:Set("profile.warn.repeatAfter", 1)
	eq(warnings(), 2, "a changed setting checks again at once")
	ns.Check()
	eq(warnings(), 2)
	H.Advance(61)
	ns.Check()
	eq(warnings(), 3, "repeated after a minute")
	eq(#H.sounds > 0, true)
end)

test("bag choice, message text and colour, and a broken format string", function()
	local ns = H.Start(ADDON)
	ns.db:Set("profile.bags", { [0] = false, true, true, true, true })
	eq(ns.Free(), 0, "only the backpack has slots in the fixtures")
	ns.db:Set("profile.message.text", "only %d left")
	ok(ns.Message(3):find("only 3 left"))
	ns.db:Set("profile.message.text", "100% full %s %d")
	ok(ns.Message(3):find("100%% full"), "bad format: the raw text is shown, no error")
end)

test("a saved key binding prints the status after a reload", function()
	local ns = H.Start(ADDON)
	ns.db:Set("profile.statusKey", "CTRL-B")
	H.Reload()
	H.PressBinding("CTRL-B")
	ok(H.log[#H.log]:find("14 free slot"))
end)

test("every settings page lays out cleanly in every theme", function()
	local ns = H.Start(ADDON)
	H.Slash("/bagwarden")
	for _, theme in ipairs(ns.FK.Theme:Names()) do
		ns.FK.Theme:Set(theme)
		for _, page in ipairs({ "warning", "message", "bags", "keys" }) do
			ns.options:Open(page)
			H.Advance(0)
			eq(ns.options.tabs:GetValue(), page)
			eq(H.LayoutIssues(ns.options.window), {}, theme .. "/" .. page)
		end
	end
	eq(H.LeakedGlobals("BagWarden"), {})
end)
