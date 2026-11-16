local _, ns = ...
local FK = ns.FK

---@module Unit  FK.Unit.FullName(unit) "Name-Realm" (the form addon messages and whispers use), FK.Unit.ClassColor(unitOrClassToken) -> r, g, b, hex, FK.Unit.Colored(unit). FK.Group.Units() list of unit tokens in the group including "player", FK.Group.Channel() "RAID" | "PARTY" | nil, FK.Group.Each(fn(unit)).
local Unit, Group = {}, {}
FK.Unit, FK.Group = Unit, Group

function Unit.FullName(unit)
	local name, realm = UnitFullName(unit)
	if not name then return nil end
	return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
end

function Unit.ClassColor(v)
	local class = RAID_CLASS_COLORS[v] and v or select(2, UnitClass(v))
	local c = class and RAID_CLASS_COLORS[class]
	if not c then return 1, 1, 1, "|cffffffff" end
	return c.r, c.g, c.b, "|c" .. (c.colorStr or "ffffffff")
end

function Unit.Colored(unit)
	local _, _, _, hex = Unit.ClassColor(unit)
	return hex .. (UnitName(unit) or "?") .. "|r"
end

function Group.Channel()
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
end

function Group.Units()
	local units, n = { "player" }, GetNumGroupMembers()
	if IsInRaid() then
		units = {}
		for i = 1, n do units[i] = "raid" .. i end -- raid units include the player
	else
		for i = 1, n - 1 do units[#units + 1] = "party" .. i end
	end
	return units
end

function Group.Each(fn)
	for _, unit in ipairs(Group.Units()) do
		if UnitExists(unit) then fn(unit) end
	end
end
