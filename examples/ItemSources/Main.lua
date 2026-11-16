local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- Example: a data browser over QuestieDB (an optional dependency, GPL-3.0: read at runtime,
-- never copied). Type an exact item name; the tree lists where it comes from (drops,
-- containers, vendors), selecting a source lists its spawn points in the table.

ns.db = FK:NewDB("ItemSourcesDB", {
	profile = { ui = FK.Copy(FK.AppearanceDefaults), window = {}, last = "" },
})
FK:BindAppearance(ns.db, "profile.ui")

local GROUPS = {
	{ field = "npcs", entity = "Npc", label = L["Dropped by"] },
	{ field = "objects", entity = "Object", label = L["Found in"] },
	{ field = "vendors", entity = "Npc", label = L["Sold by"] },
}

-- Tree nodes for an item name: one branch per kind of source. nil when QuestieDB is missing.
function ns.Nodes(itemName)
	local ids = FK.Questie.Find("Item", itemName)
	if not ids then return nil end
	local nodes = {}
	for _, g in ipairs(GROUPS) do
		local children = {}
		for _, id in ipairs(ids) do
			local sources = FK.Questie.ItemSources(id) or {}
			for _, sid in ipairs(sources[g.field] or {}) do
				local name = FK.Questie.Get(g.entity, sid, "name") or ("#" .. sid)
				children[#children + 1] = { label = name, value = { entity = g.entity, id = sid } }
			end
		end
		table.sort(children, function(a, b) return a.label < b.label end)
		if #children > 0 then
			nodes[#nodes + 1] = { label = ("%s (%d)"):format(g.label, #children), children = children, expanded = #nodes == 0 }
		end
	end
	return nodes
end

-- Table rows: the spawn points of a source, with the zone's name from the client.
function ns.Spawns(entity, id)
	local spawns = FK.Questie.Get(entity, id, "spawns") or {}
	local rows = {}
	for zone, points in pairs(spawns) do
		local zoneName = C_Map.GetAreaInfo(zone) or ("#" .. zone)
		for _, p in ipairs(points) do
			rows[#rows + 1] = { zone = zoneName, x = p[1], y = p[2] }
		end
	end
	return rows
end

local function show(text)
	ns.db.profile.last = text
	local nodes = {}
	if text ~= "" then nodes = ns.Nodes(text) end -- nil: QuestieDB missing
	ns.tree:SetNodes(nodes or {})
	ns.table:SetItems({})
	if not nodes then
		ns.status:SetText(L["QuestieDB is not installed or not enabled."])
	elseif text ~= "" and #nodes == 0 then
		ns.status:SetText(L["No item with that exact name, or no known source."])
	else
		ns.status:SetText(L["Select a source to see where it is."])
	end
end

FK:OnLogin(function()
	local win = FK.Window(UIParent, { title = "Item Sources", width = 620, height = 420, resizable = { minWidth = 480, minHeight = 300 },
		saved = { ns.db, "profile.window" } })
	ns.window = win
	ns.search = FK.SearchBox(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, placeholder = L["Exact item name, e.g. Linen Cloth"],
		value = ns.db.profile.last, onSearch = show })
	ns.status = FK.Label(win.content, { points = { { "BOTTOMLEFT" }, { "BOTTOMRIGHT" } }, role = "small", color = "dim" })
	ns.tree = FK.Tree(win.content, { onSelect = function(node)
		local v = node.value
		if v then ns.table:SetItems(ns.Spawns(v.entity, v.id)) end
	end })
	ns.tree:SetPoint("TOPLEFT", ns.search, "BOTTOMLEFT", 0, -8)
	ns.tree:SetPoint("BOTTOMRIGHT", ns.status, "TOP", -5, 6)
	ns.table = FK.Table(win.content, { emptyText = L["No spawn points."], columns = {
		{ key = "zone", label = L["Zone"], flex = 1 },
		{ key = "x", label = "X", width = 56, align = "RIGHT", format = function(v) return ("%.1f"):format(v) end },
		{ key = "y", label = "Y", width = 56, align = "RIGHT", format = function(v) return ("%.1f"):format(v) end },
	} })
	ns.table:SetPoint("TOPLEFT", ns.tree, "TOPRIGHT", 10, 0)
	ns.table:SetPoint("BOTTOMRIGHT", ns.status, "TOPRIGHT", 0, 6)
	FK:Slash({ "/itemsources" }, function(arg)
		win:Open()
		if arg ~= "" then ns.search:SetValue(arg) show(arg) end
	end)
	show(ns.db.profile.last)
end)

function ItemSources_OnCompartmentClick() ns.window:Toggle() end
