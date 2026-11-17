-- Minimap (step 14): the round edge is hard (own circle mask) under a thin border, and reset
-- gives back the client's own mask. Run: tools/fk live run --file tools/experiments/minimap-edge.lua
local G = SlashCmdList.FKGALLERY
FKDev.Note("mask at login", tostring(Minimap:GetMaskTexture()), "MinimapMask id", tostring(GetFileIDFromPath("Textures\\MinimapMask")))
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("") G("minimap round thin 260 260 center") end },
	{ 2, function() Screenshot() end },  -- 1 round 260 in the middle, thin border: edge must be sharp
	{ 1, function() G("minimap reset") FKDev.Note("mask after reset", tostring(Minimap:GetMaskTexture())) end },
	{ 2, function() Screenshot() end },  -- 2 reset: must look like the untouched client minimap
})
return "edge experiment started"
