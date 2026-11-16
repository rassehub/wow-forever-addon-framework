local _, ns = ...
local FK = ns.FK

---@module Bags  FK.Bags.Count(itemID) (bags only; the client's own count), FK.Bags.Scan() -> { [itemID] = count }, FK.Bags.Free() -> free slots, FK.Bags.Each(fn(bag, slot, info)). Event "fk.bags" fires at most once per 0.5 s after the bags change: FK:On("fk.bags", fn).
local Bags = {}
FK.Bags = Bags
local LAST = NUM_BAG_SLOTS or 4

function Bags.Each(fn)
	for bag = 0, LAST do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info then fn(bag, slot, info) end
		end
	end
end

function Bags.Scan()
	local counts = {}
	Bags.Each(function(_, _, info) counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount end)
	return counts
end

function Bags.Count(id) return C_Item.GetItemCount(id) end

function Bags.Free()
	local n = 0
	for bag = 0, LAST do n = n + C_Container.GetContainerNumFreeSlots(bag) end
	return n
end

-- BAG_UPDATE_DELAYED already batches one move; looting a stack of items still fires it in bursts
FK:On("BAG_UPDATE_DELAYED", FK:Throttle(0.5, function() FK:Emit("fk.bags") end))
