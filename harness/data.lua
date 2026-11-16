-- Used by `fk data`: loads an installed QuestieDB into the emulator and queries it through its
-- public API, for looking things up while designing an addon. QuestieDB is GPL-3.0: this prints
-- what the installed copy says; it does not store or ship any of it.
--   lua harness/data.lua QUESTIEDB_DIR ENTITY QUERY [--json] [--fields a,b] [--raw]
-- ENTITY: item | npc | object | quest. QUERY: an id, or an exact name (all ids with that name).
-- Id lists in drop/vendor/quest fields are shown with the names they point to unless --raw.

local write, stderr, exit = io.write, io.stderr, os.exit
local H = require("wow")

local dir, entityArg, query = arg[1], arg[2], arg[3]
local opts, i = {}, 4
while arg[i] do
	local a = arg[i]
	if a == "--json" then opts.json = true
	elseif a == "--raw" then opts.raw = true
	elseif a == "--fields" then i = i + 1; opts.fields = arg[i]
	else stderr:write("unknown argument " .. a .. "\n") exit(2) end
	i = i + 1
end

local ENTITIES = { item = "Item", npc = "Npc", object = "Object", quest = "Quest" }
local entity = ENTITIES[(entityArg or ""):lower()]
if not (dir and entity and query) then
	stderr:write("usage: data.lua QUESTIEDB_DIR item|npc|object|quest ID|NAME [--json] [--fields a,b] [--raw]\n")
	exit(2)
end

H.Start(dir)
local Q = LibQuestieDB
if not Q then stderr:write("QuestieDB did not create LibQuestieDB\n") exit(1) end
local okContract, why = Q.RequireContract(4)
if not okContract then stderr:write("QuestieDB contract: " .. tostring(why) .. "\n") exit(1) end

local E = Q[entity]
local keys = Q.Meta[entity .. "Meta"][entity:lower() .. "Keys"]
local fields = {}
if opts.fields then
	for f in opts.fields:gmatch("[^,%s]+") do
		if not keys[f] then stderr:write(("%s has no field %q\n"):format(entity, f)) exit(2) end
		fields[#fields + 1] = f
	end
else
	for name in pairs(keys) do fields[#fields + 1] = name end
	table.sort(fields, function(a, b) return keys[a] < keys[b] end)
end

-- Fields holding lists of other entities' ids: show "id (Name)" so the output reads on its own.
local LINKS = {
	npcDrops = "Npc", objectDrops = "Object", itemDrops = "Item", vendors = "Npc", startQuest = "Quest",
	questRewards = "Quest", relatedQuests = "Quest", questStarts = "Quest", questEnds = "Quest",
	childQuests = "Quest", preQuestGroup = "Quest", preQuestSingle = "Quest", inGroupWith = "Quest",
	exclusiveTo = "Quest", nextQuestInChain = "Quest", parentQuest = "Quest", breadcrumbs = "Quest",
	breadcrumbForQuestId = "Quest", sourceItemId = "Item", requiredSourceItems = "Item",
}
local LINK = {} -- metatable marking an "id (Name)" entry
local function label(kind, id)
	local name = type(id) == "number" and Q[kind].Exists(id) and Q[kind].name(id)
	return name and setmetatable({ id = id, name = name }, LINK) or id
end
local function resolve(field, v)
	local kind = not opts.raw and LINKS[field]
	if not kind then return v end
	if type(v) == "number" then return label(kind, v) end
	if type(v) == "table" then
		local out = {}
		for k, x in pairs(v) do out[k] = type(x) == "number" and label(kind, x) or x end
		return out
	end
	return v
end

local ids = {}
if tonumber(query) then
	ids[1] = tonumber(query)
	if not E.Exists(ids[1]) then stderr:write(("no %s with id %d\n"):format(entityArg, ids[1])) exit(1) end
else
	ids = E.IdsByName(query) or {}
	if #ids == 0 then stderr:write(("no %s named %q (names are exact and case-sensitive)\n"):format(entityArg, query)) exit(1) end
end

local results = {}
for _, id in ipairs(ids) do
	local row = { id = id }
	local values = E.GetAll(id, fields)
	for n, f in ipairs(fields) do
		if values[n] ~= nil then row[f] = resolve(f, values[n]) end
	end
	results[#results + 1] = row
end

-- Output. JSON: a list of rows (arrays stay arrays, sparse/keyed tables become objects).
local function isArray(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	for k = 1, n do if t[k] == nil then return false end end
	return true
end
local function sortedKeys(t)
	local ks = {}
	for k in pairs(t) do ks[#ks + 1] = k end
	table.sort(ks, function(a, b)
		if a == "id" then return b ~= "id" end
		if b == "id" then return false end
		if type(a) == type(b) then
			if type(a) == "string" and keys[a] and keys[b] then return keys[a] < keys[b] end
			return a < b
		end
		return type(a) == "number"
	end)
	return ks
end
local function json(v)
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t" })[c] or ("\\u%04x"):format(c:byte())
		end) .. '"'
	end
	if t == "number" then return v ~= v and "null" or tostring(v) end
	if t == "boolean" then return tostring(v) end
	if t ~= "table" then return "null" end
	local parts = {}
	if isArray(v) then
		for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	for _, k in ipairs(sortedKeys(v)) do parts[#parts + 1] = json(tostring(k)) .. ":" .. json(v[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function lua(v, indent)
	if type(v) == "string" then return ("%q"):format(v) end
	if type(v) ~= "table" then return tostring(v) end
	if getmetatable(v) == LINK then return ("%d --[[ %s ]]"):format(v.id, v.name) end
	local inner, flat = indent .. "  ", true
	for _, x in pairs(v) do if type(x) == "table" then flat = false end end
	local parts = {}
	if isArray(v) then
		for _, x in ipairs(v) do parts[#parts + 1] = lua(x, inner) end
	else
		for _, k in ipairs(sortedKeys(v)) do
			local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. lua(k, inner) .. "]")
			parts[#parts + 1] = key .. " = " .. lua(v[k], inner)
		end
	end
	if #parts == 0 then return "{}" end
	if flat and #table.concat(parts, ", ") < 90 then return "{ " .. table.concat(parts, ", ") .. " }" end
	return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
end

if opts.json then
	write(json(results), "\n")
else
	for _, row in ipairs(results) do write(lua(row, ""), "\n") end
end
