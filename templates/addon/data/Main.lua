local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- A data addon: looks things up in QuestieDB (an optional dependency, GPL-3.0: read it at
-- runtime, never copy its data) and shows the result. Here: where an item comes from.

ns.db = FK:NewDB("__NAME__DB", {
	profile = { ui = FK.Copy(FK.AppearanceDefaults), window = {} },
})
FK:BindAppearance(ns.db, "profile.ui")

-- Rows for the table: one per source of the item.
function ns.Sources(itemName)
	local ids = FK.Questie.Find("Item", itemName)
	if not ids then return nil end -- QuestieDB missing
	local rows = {}
	for _, id in ipairs(ids) do
		local s = FK.Questie.ItemSources(id) or {}
		for kind, list in pairs({ [L["Drop"]] = s.npcs, [L["Container"]] = s.objects, [L["Vendor"]] = s.vendors }) do
			local entity = list == s.objects and "Object" or "Npc"
			for _, sid in ipairs(list) do
				rows[#rows + 1] = { kind = kind, name = FK.Questie.Get(entity, sid, "name") or ("#" .. sid), id = sid }
			end
		end
	end
	return rows
end

FK:OnLogin(function()
	local win = FK.Window(UIParent, { title = "__NAME__", width = 460, height = 380, resizable = true, saved = { ns.db, "profile.window" } })
	ns.window = win
	local status = FK.Label(win.content, { points = { { "BOTTOMLEFT" }, { "BOTTOMRIGHT" } }, role = "small", color = "dim" })
	ns.table = FK.Table(win.content, { columns = {
		{ key = "kind", label = L["Source"], width = 100 },
		{ key = "name", label = L["Name"], flex = 1 },
		{ key = "id", label = "ID", width = 70, align = "RIGHT" },
	}, emptyText = L["Type an exact item name."] })
	local search = FK.SearchBox(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, placeholder = L["Item name"],
		onSearch = function(text)
			local rows = {}
			if text ~= "" then rows = ns.Sources(text) end -- nil: QuestieDB missing
			ns.table:SetItems(rows or {})
			status:SetText(rows and L["%d source(s)"]:format(#rows) or L["QuestieDB is not installed or not enabled."])
		end })
	ns.search = search
	ns.table:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
	ns.table:SetPoint("BOTTOMRIGHT", status, "TOPRIGHT", 0, 6)
	FK:Slash({ "/__SLUG__" }, function(arg)
		win:Open()
		if arg ~= "" then search:SetValue(arg) search.opts.onSearch(arg) end
	end)
end)

function __NAME___OnCompartmentClick() ns.window:Toggle() end
