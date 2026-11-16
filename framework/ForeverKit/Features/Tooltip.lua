local _, ns = ...
local FK = ns.FK

---@module Tooltip  FK.Tooltip.OnItem(fn(tooltip, itemID, data)) adds lines to every item tooltip (bags, links, auction house): call tooltip:AddLine / AddDoubleLine inside. FK.Tooltip.OnUnit(fn(tooltip, unitData)). FK.Tooltip.Show(owner, lines, anchor): lines is text, { title, line, ... } or function(tooltip). FK.Tooltip.Hide().
local Tooltip = {}
FK.Tooltip = Tooltip

local function postCall(dataType, fn)
	TooltipDataProcessor.AddTooltipPostCall(dataType, function(tip, data)
		-- the processor also runs for embedded/shopping tooltips the addon did not ask about
		if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
		fn(tip, data)
	end)
end

function Tooltip.OnItem(fn)
	postCall(Enum.TooltipDataType.Item, function(tip, data)
		if data and data.id then fn(tip, data.id, data) end
	end)
end

function Tooltip.OnUnit(fn) postCall(Enum.TooltipDataType.Unit, fn) end

function Tooltip.Show(owner, lines, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	if type(lines) == "function" then
		lines(GameTooltip)
	elseif type(lines) == "table" then
		GameTooltip:SetText(lines[1], 1, 1, 1)
		for i = 2, #lines do GameTooltip:AddLine(lines[i], nil, nil, nil, true) end
	else
		GameTooltip:SetText(lines, nil, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

function Tooltip.Hide() GameTooltip:Hide() end
