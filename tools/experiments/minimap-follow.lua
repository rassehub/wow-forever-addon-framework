-- Minimap (step 14): pins stay inside a rectangle's band, and the cluster pieces (zone name,
-- clock, buttons) follow a moved map. Walk past quest givers / nodes during the run.
-- Run: tools/fk live run --file tools/experiments/minimap-follow.lua
local G = SlashCmdList.FKGALLERY
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("") G("minimap navigator") end },
	{ 2, function() Screenshot() end },  -- 1 navigator: pins only inside the band, header above it
	{ 3, function() Screenshot() end },  -- 2 a few seconds later, after walking
	{ 1, function() G("minimap round thin 260 260 center") end },
	{ 2, function() Screenshot() end },  -- 3 round map moved to the middle: header, clock, buttons around it
})
return "follow experiment started"
