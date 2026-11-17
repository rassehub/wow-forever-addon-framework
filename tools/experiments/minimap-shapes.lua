-- Minimap shapes in the real client (step 14): screenshots of the variants FK.MinimapSkin makes,
-- ending in the navigator preset with the drawer open. /reload restores the normal minimap.
-- Run: tools/fk live run --file tools/experiments/minimap-shapes.lua
local G = SlashCmdList.FKGALLERY
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("minimap round thin") end },
	{ 1.5, function() Screenshot() end },                                      -- 1 round, thin ring
	{ 1, function() G("minimap round metal") end },
	{ 1.5, function() Screenshot() end },                                      -- 2 round, metal ring
	{ 1, function() G("minimap square double") G("minimap drawer") end },
	{ 1.5, function() Screenshot() end },                                      -- 3 square, double, drawer open
	{ 1, function() G("minimap navigator") G("minimap drawer") end },
	{ 2, function() FKDev.Note("navigator", "size", Minimap:GetSize(), "mask", tostring(Minimap.GetMaskTexture and Minimap:GetMaskTexture() or "?")) Screenshot() end }, -- 4 navigator
})
return "shapes started"
