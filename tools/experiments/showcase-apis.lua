-- Step 15: which client APIs the showcase addons can rely on (world map art, quest log, journal).
-- Run: tools/fk live run --file tools/experiments/showcase-apis.lua
local function has(path)
	local t = _G
	for part in path:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
	return t ~= nil
end
local names = { "C_Map.GetMapArtLayers", "C_Map.GetMapArtLayerTextures", "C_Map.GetMapChildrenInfo", "C_Map.GetMapInfo",
	"C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapInfoAtPosition", "C_Map.GetAreaInfo",
	"C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetInfo", "C_QuestLog.GetQuestObjectives", "C_QuestLog.IsComplete",
	"C_QuestLog.GetQuestIDForLogIndex", "C_QuestLog.GetLogIndexForQuestID", "GetQuestLogTitle", "GetNumQuestLeaderBoards",
	"GetQuestLogLeaderBoard", "C_QuestLog.SetSelectedQuest", "QuestMapFrame_OpenToQuestDetails", "QuestLogFrame",
	"EJ_GetNumTiers", "EJ_GetInstanceByIndex", "C_EncounterJournal", "C_Texture.GetAtlasInfo", "ObjectiveTrackerFrame", "QuestWatchFrame" }
local missing, present = {}, {}
for _, n in ipairs(names) do if has(n) then present[#present + 1] = n else missing[#missing + 1] = n end end
FKDev.Note("missing", unpack(missing))
FKDev.Note("present", unpack(present))
local map = C_Map.GetBestMapForUnit("player")
FKDev.Note("map", map, C_Map.GetMapInfo(map) and C_Map.GetMapInfo(map).name, C_Map.GetMapInfo(map) and C_Map.GetMapInfo(map).parentMapID)
if C_Map.GetMapArtLayers then
	local l = C_Map.GetMapArtLayers(map) and C_Map.GetMapArtLayers(map)[1]
	if l then FKDev.Note("art layer", l.layerWidth, l.layerHeight, l.tileWidth, l.tileHeight, l.minScale, l.maxScale) end
	local tex = C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(map, 1)
	if tex then FKDev.Note("art textures", #tex, tostring(tex[1]), tostring(tex[2])) end
end
local p = C_Map.GetPlayerMapPosition(map, "player")
if p then FKDev.Note("player pos", p:GetXY()) end
if C_Map.GetMapChildrenInfo then
	local kids = C_Map.GetMapChildrenInfo(map) or {}
	FKDev.Note("children", #kids, kids[1] and kids[1].name)
	local parent = C_Map.GetMapInfo(map).parentMapID
	local sib = parent and C_Map.GetMapChildrenInfo(parent) or {}
	FKDev.Note("parent's children", #sib, sib[1] and (sib[1].name .. " " .. sib[1].mapID .. " type " .. tostring(sib[1].mapType)))
end
local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or GetNumQuestLogEntries()
FKDev.Note("quests", n)
for i = 1, math.min(n, 4) do
	local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
	if info then
		local objs = info.questID and info.questID > 0 and C_QuestLog.GetQuestObjectives(info.questID) or {}
		local o = objs[1]
		FKDev.Note("quest " .. i, info.title, info.questID, tostring(info.isHeader), tostring(info.isCollapsed), info.level,
			o and (o.text .. " " .. tostring(o.numFulfilled) .. "/" .. tostring(o.numRequired) .. " " .. tostring(o.finished) .. " " .. tostring(o.type)) or "-")
	end
end
return "api probe done"
