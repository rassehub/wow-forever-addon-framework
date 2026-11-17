-- Rectangles and rotation in the real client (step 14): does an addon PNG work as a minimap
-- mask, and what does rotation do to a masked map? The gallery is hidden during the shots.
-- Run: tools/fk live run --file tools/experiments/minimap-rect.lua
local G = SlashCmdList.FKGALLERY
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("") G("minimap rect thin 460 230 center") end },
	{ 1.5, function() FKDev.Note("rect", "size", Minimap:GetSize(), "rotate", C_CVar.GetCVar("rotateMinimap")) Screenshot() end }, -- 1 band mask, no rotation
	{ 1, function() G("minimap rect thin 460 230 rotate center") end },
	{ 1.5, function() FKDev.Note("rect+rotate", "rotate", C_CVar.GetCVar("rotateMinimap"), "facing", GetPlayerFacing and GetPlayerFacing()) Screenshot() end }, -- 2 band + rotation
	{ 1, function() G("minimap square thin 300 300 rotate center") end },
	{ 1.5, function() Screenshot() end },                                                         -- 3 square + rotation
	{ 1, function() G("minimap round thin 300 300 rotate center") end },
	{ 1.5, function() Screenshot() end },                                                         -- 4 round + rotation (reference)
	{ 1, function() G("minimap reset") G("") end },
})
return "rect experiment started"
