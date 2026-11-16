local _, ns = ...
local FK = ns.FK

---@module Items  FK.Items.Load(idOrLink, fn(info)) calls fn once the item data is cached (immediately if it already is); info = { id, name, link, quality, icon, level, minLevel, type, subType, stack, equipLoc, sellPrice, classID, subclassID }. FK.Items.Info(id) same table or nil if not cached yet. FK.Items.ID(link). FK.Items.QualityColor(q) -> r, g, b, hex. FK.Items.Colored(text, quality).
local Items = {}
FK.Items = Items
local cache = {}

function Items.ID(v)
	if type(v) == "number" then return v end
	return tonumber(tostring(v):match("item:(%d+)"))
end

function Items.Info(v)
	local id = Items.ID(v)
	if not id then return nil end
	if cache[id] then return cache[id] end
	local name, link, quality, level, minLevel, type_, subType, stack, equipLoc, icon, sellPrice, classID, subclassID = C_Item.GetItemInfo(id)
	if not name then return nil end
	local info = { id = id, name = name, link = link, quality = quality, level = level, minLevel = minLevel, type = type_,
		subType = subType, stack = stack, equipLoc = equipLoc, icon = icon, sellPrice = sellPrice, classID = classID, subclassID = subclassID }
	cache[id] = info
	return info
end

function Items.Load(v, fn)
	local id = Items.ID(v) or error("FK.Items.Load: not an item id or link: " .. tostring(v), 2)
	local info = Items.Info(id)
	if info then return fn(info) end
	if not C_Item.DoesItemExistByID(id) then return end -- ContinueOnItemLoad raises on unknown ids
	Item:CreateFromItemID(id):ContinueOnItemLoad(function() fn(Items.Info(id)) end)
end

function Items.QualityColor(q)
	local c = ITEM_QUALITY_COLORS[q] or ITEM_QUALITY_COLORS[1]
	return c.r, c.g, c.b, c.hex
end

function Items.Colored(text, quality)
	local _, _, _, hex = Items.QualityColor(quality)
	return hex .. text .. "|r"
end
