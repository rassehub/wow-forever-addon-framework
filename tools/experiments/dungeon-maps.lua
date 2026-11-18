-- GoalNotes 2.4/2.5 and phase 3: what the client knows about dungeon maps, boss positions on
-- them, and known recipes. Run: tools/fk live run --file tools/experiments/dungeon-maps.lua
-- then /reload in game and click the FKDev button; read with tools/fk live results -v.
local function Note(key, value) FKDev.Note(key, tostring(value)) end

-- 2.4: dungeon maps by name, and their floors
local found = {}
for id = 1, 3000 do
	local info = C_Map.GetMapInfo(id)
	if info and info.mapType == Enum.UIMapType.Dungeon and info.name and info.name:find("Deadmines") then found[#found + 1] = id end
end
Note("deadmines maps", table.concat(found, ","))
local count = 0
for id = 1, 3000 do
	local info = C_Map.GetMapInfo(id)
	if info and info.mapType == Enum.UIMapType.Dungeon then count = count + 1 end
end
Note("dungeon maps in client", count)
for _, id in ipairs(found) do
	local info = C_Map.GetMapInfo(id)
	local group = C_Map.GetMapGroupID and C_Map.GetMapGroupID(id)
	local floors = {}
	for _, m in ipairs(group and C_Map.GetMapGroupMembersInfo(group) or {}) do
		floors[#floors + 1] = m.mapID .. "=" .. tostring(m.name) .. "@" .. tostring(m.relativeHeightIndex)
	end
	local layers = C_Map.GetMapArtLayers(id) or {}
	Note("map " .. id, ("%s group=%s floors=[%s] layers=%d art=%sx%s"):format(info.name, tostring(group),
		table.concat(floors, "; "), #layers, tostring(layers[1] and layers[1].layerWidth), tostring(layers[1] and layers[1].layerHeight)))
end

-- 2.5: boss positions from the encounter journal
local EJ = C_EncounterJournal
Note("C_EncounterJournal", EJ and "present" or "missing")
Note("GetEncountersOnMap", EJ and type(EJ.GetEncountersOnMap) or "-")
for _, id in ipairs(found) do
	local ok, list = pcall(EJ and EJ.GetEncountersOnMap or error, id)
	local parts = {}
	for _, e in ipairs(ok and list or {}) do
		local name = EJ_GetEncounterInfo and EJ_GetEncounterInfo(e.encounterID)
		parts[#parts + 1] = ("%s(%s) %.3f,%.3f"):format(tostring(name), tostring(e.encounterID), e.mapX or -1, e.mapY or -1)
	end
	Note("bosses on " .. id, ok and (#parts .. ": " .. table.concat(parts, "; ")) or ("error " .. tostring(list)))
end

-- phase 3: can a recipe be checked as already known?
Note("IsSpellKnown", type(IsSpellKnown))
Note("IsPlayerSpell", type(IsPlayerSpell))
local keys = {}
for k in pairs(C_TradeSkillUI or {}) do keys[#keys + 1] = k end
table.sort(keys)
Note("C_TradeSkillUI", #keys .. ": " .. table.concat(keys, ","))

-- 1.5: the quest "!" texture used for difficulty icons
Note("AvailableQuestIcon file", GetFileIDFromPath("Interface\\GossipFrame\\AvailableQuestIcon"))
return "dungeon map experiment done"
