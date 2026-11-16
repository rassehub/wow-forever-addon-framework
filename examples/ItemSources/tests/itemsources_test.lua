-- Emulator tests. QuestieDB is replaced by a stand-in with its public API (shapes as recorded in
-- docs/research/05-game-data.md), so the tests do not depend on what is installed.

local function fakeQuestie()
	local rows = {
		Item = { [2589] = { name = "Linen Cloth", npcDrops = { 448 }, objectDrops = { 2039, 2844 } } },
		Npc = { [448] = { name = "Hogger", spawns = { [12] = { { 25.02, 92.9 } } } } },
		Object = {
			[2039] = { name = "Hidden Strongbox", spawns = { [36] = { { 12.8, 76.49 }, { 18.39, 76.95 } } } },
			[2844] = { name = "Battered Chest", spawns = {} },
		},
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

test("without QuestieDB the window says so", function()
	local ns = H.Start(ADDON)
	H.Slash("/itemsources Linen Cloth")
	ok(ns.window:IsShown())
	ok(ns.status.text:GetText():find("QuestieDB"))
end)

test("sources in the tree, spawn points in the table", function()
	H.fixtures = nil
	local ns = H.Start(ADDON)
	rawset(_G, "LibQuestieDB", fakeQuestie())
	H.Slash("/itemsources Linen Cloth")
	local nodes = ns.Nodes("Linen Cloth")
	eq(nodes[1].label, "Dropped by (1)")
	eq(nodes[2].label, "Found in (2)")
	eq(nodes[2].children[2].label, "Hidden Strongbox")
	eq(ns.Spawns("Object", 2039), { { zone = "Area 36", x = 12.8, y = 76.49 }, { zone = "Area 36", x = 18.39, y = 76.95 } })
	H.Advance(0)
	H.Click(H.Find(ns.window, "Hogger"):GetParent())
	eq(#ns.table.items, 1)
	eq(H.LayoutIssues(ns.window), {})
	eq(ns.db.profile.last, "Linen Cloth")
	eq(H.LeakedGlobals("ItemSources"), {})
end)
