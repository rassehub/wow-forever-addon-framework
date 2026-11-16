-- Emulator tests: tools/fk test addons/__NAME__ (ADDON is this addon's folder).
-- QuestieDB is replaced by a stand-in with its public API, so the tests do not depend on what is
-- installed. Use `fk data item "<name>"` to see real values.

local function fakeQuestie()
	local rows = {
		Item = { [2589] = { name = "Linen Cloth", npcDrops = { 448 }, objectDrops = { 2039 } } },
		Npc = { [448] = { name = "Hogger" } },
		Object = { [2039] = { name = "Hidden Strongbox" } },
	}
	local Q = { RequireContract = function(n) return n == 4 end }
	for entity, byId in pairs(rows) do
		Q[entity] = {
			Exists = function(id) return byId[id] ~= nil end,
			Get = function(id, f) return byId[id][f] end,
			GetAll = function(id, fields) local o = {} for i, f in ipairs(fields) do o[i] = byId[id][f] end return o end,
			IdsByName = function(name) local o = {} for id, r in pairs(byId) do if r.name == name then o[#o + 1] = id end end return o end,
		}
	end
	return Q
end

test("lists an item's sources, and says so when QuestieDB is missing", function()
	local ns = H.Start(ADDON)
	eq(ns.Sources("Linen Cloth"), nil)
	H.Slash("/__SLUG__ Linen Cloth")
	ok(H.Find(ns.window, "QuestieDB is not installed or not enabled."), "says why the list is empty")
	rawset(_G, "LibQuestieDB", fakeQuestie())
	H.Slash("/__SLUG__ Linen Cloth")
	ok(ns.window:IsShown())
	local names = {}
	for _, r in ipairs(ns.Sources("Linen Cloth")) do names[#names + 1] = r.name end
	table.sort(names)
	eq(names, { "Hidden Strongbox", "Hogger" })
	eq(H.LayoutIssues(ns.window), {})
	eq(H.LeakedGlobals("__NAME__"), {})
end)
