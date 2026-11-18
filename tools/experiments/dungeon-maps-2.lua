-- GoalNotes 2.4/2.5, second run: the first found no map with mapType Dungeon in ids 1-3000.
-- Where are Deadmines' maps, what type are they, and does the encounter journal place bosses?
-- Run: tools/fk live run --file tools/experiments/dungeon-maps-2.lua
local function Note(key, value) FKDev.Note(key, tostring(value)) end

local byType, hits, highest = {}, {}, 0
for id = 1, 20000 do
	local info = C_Map.GetMapInfo(id)
	if info then
		highest = id
		byType[info.mapType or -1] = (byType[info.mapType or -1] or 0) + 1
		local name = info.name or ""
		if name:find("Deadmines") or name:find("Ironclad") or name:find("Wailing") then hits[#hits + 1] = id end
	end
end
local types = {}
for t, n in pairs(byType) do types[#types + 1] = t .. "=" .. n end
table.sort(types)
Note("maps by type", table.concat(types, " ") .. "  highest id " .. highest)
local enum = {}
for k, v in pairs(Enum.UIMapType or {}) do enum[#enum + 1] = k .. "=" .. tostring(v) end
table.sort(enum)
Note("Enum.UIMapType", table.concat(enum, " "))

local EJ = C_EncounterJournal
for _, id in ipairs(hits) do
	local info = C_Map.GetMapInfo(id)
	local group = C_Map.GetMapGroupID(id)
	local floors = {}
	for _, m in ipairs(group and C_Map.GetMapGroupMembersInfo(group) or {}) do
		floors[#floors + 1] = m.mapID .. "=" .. tostring(m.name) .. "@" .. tostring(m.relativeHeightIndex)
	end
	local layers = C_Map.GetMapArtLayers(id) or {}
	local parent = C_Map.GetMapInfo(info.parentMapID or 0)
	Note("map " .. id, ("%s type=%s parent=%s(%s) group=%s floors=[%s] layers=%d %sx%s flags=%s"):format(info.name,
		tostring(info.mapType), tostring(info.parentMapID), parent and parent.name or "-", tostring(group),
		table.concat(floors, "; "), #layers, tostring(layers[1] and layers[1].layerWidth),
		tostring(layers[1] and layers[1].layerHeight), tostring(info.flags)))
	local ok, list = pcall(EJ.GetEncountersOnMap, id)
	local parts = {}
	for _, e in ipairs(ok and list or {}) do
		local name = EJ_GetEncounterInfo and EJ_GetEncounterInfo(e.encounterID)
		parts[#parts + 1] = ("%s(%s) %.3f,%.3f"):format(tostring(name), tostring(e.encounterID), e.mapX or -1, e.mapY or -1)
	end
	Note("bosses on " .. id, ok and (#parts .. ": " .. table.concat(parts, "; ")) or ("error " .. tostring(list)))
end
Note("Deadmines-like maps", #hits)

-- recipes: the tooltip's "Already known" line, and what GetItemSpell says of a recipe item
Note("ITEM_SPELL_KNOWN", ITEM_SPELL_KNOWN)
Note("GetItemSpell(2406)", table.concat({ tostring((C_Item.GetItemSpell(2406))), tostring(select(2, C_Item.GetItemSpell(2406))) }, " "))
return "dungeon map experiment 2 done"
