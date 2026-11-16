local _, ns = ...
local FK = ns.FK

---@module Questie  Read-only bridge to the QuestieDB addon (runtime optional dependency: add `## OptionalDeps: QuestieDB` to the TOC; GPL-3.0, so never copy its data). FK.Questie.Available() -> bool. FK.Questie.Get(entity, id, field) with entity "Item" | "Npc" | "Object" | "Quest". FK.Questie.GetAll(entity, id, { fields }) -> { field = value }. FK.Questie.Find(entity, exactName) -> ids (builds a name index on first use: not at login). FK.Questie.ItemSources(itemID) -> { npcs, objects, items, vendors } id lists. FK.Questie.Spawns(npcID) -> { { zoneID, x, y } } with x, y in 0..100. Every call returns nil when QuestieDB is missing or raises.
local Questie = {}
FK.Questie = Questie
local CONTRACT = 4
local checked, usable

local function db()
	if checked then return usable end
	local Q = LibQuestieDB
	if not (Q and Q.RequireContract) then return nil end -- not loaded (yet): ask again next time
	checked = true
	local ok, fits, why = pcall(Q.RequireContract, CONTRACT)
	if ok and fits then usable = Q
	else FK:Warn("questie-contract", "QuestieDB contract " .. CONTRACT .. " not available: " .. tostring(why or fits)) end
	return usable
end

-- A third-party API can change: one failure is reported, the call answers nil.
local function safe(fn, ...)
	local ok, a = pcall(fn, ...)
	if ok then return a end
	FK:Warn("questie-error", "QuestieDB call failed: " .. tostring(a))
end

function Questie.Available() return db() ~= nil end

function Questie.Get(entity, id, field)
	local Q = db()
	if not Q then return nil end
	return safe(function()
		local E = Q[entity] or error("unknown entity " .. tostring(entity))
		if not E.Exists(id) then return nil end
		return E.Get(id, field)
	end)
end

function Questie.GetAll(entity, id, fields)
	local Q = db()
	if not Q then return nil end
	return safe(function()
		local E = Q[entity] or error("unknown entity " .. tostring(entity))
		if not E.Exists(id) then return nil end
		local values, out = E.GetAll(id, fields), {}
		for i, f in ipairs(fields) do out[f] = values[i] end
		return out
	end)
end

function Questie.Find(entity, name)
	local Q = db()
	if not Q then return nil end
	return safe(function() return Q[entity].IdsByName(name) or {} end)
end

function Questie.ItemSources(itemID)
	local t = Questie.GetAll("Item", itemID, { "npcDrops", "objectDrops", "itemDrops", "vendors" })
	if not t then return nil end
	return { npcs = t.npcDrops or {}, objects = t.objectDrops or {}, items = t.itemDrops or {}, vendors = t.vendors or {} }
end

function Questie.Spawns(npcID)
	local spawns = Questie.Get("Npc", npcID, "spawns")
	if not spawns then return nil end
	local out = {}
	for zone, points in pairs(spawns) do
		for _, p in ipairs(points) do out[#out + 1] = { zoneID = zone, x = p[1], y = p[2] } end
	end
	return out
end
