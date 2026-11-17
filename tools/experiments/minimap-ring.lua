-- Minimap (step 14): the rectangle placed at the top edge (should be pushed down, not squeezed),
-- what draws the extra ring while rotating (texture dump), and the classic ring scaled to 300.
-- Keep walking during the run. Run: tools/fk live run --file tools/experiments/minimap-ring.lua
local G = SlashCmdList.FKGALLERY
local function dump(root, depth)
	local lines = FKDev.Tree(root, depth, true)
	for i = 1, math.min(#lines, 60) do FKDev.Note("tree " .. i, lines[i]) end
end
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("") G("minimap rect thin 460 230") end },
	{ 2, function() FKDev.Note("top", "minimap top", Minimap:GetTop(), "screen", UIParent:GetTop()) Screenshot() end }, -- 1 navigator at the top
	{ 1, function() G("minimap round thin 300 300 rotate center") end },
	{ 2, function() dump(Minimap, 3) Screenshot() end },                                               -- 2 rotating round: dump
	{ 1, function() G("minimap round none 300 300 center") end },
	{ 2, function() FKDev.Note("ring", "shown", MinimapCompassTexture:IsShown(), "backdrop", MinimapBackdrop:GetSize()) Screenshot() end }, -- 3 classic ring at 300
	{ 1, function() G("minimap reset") G("") end },
})
return "ring experiment started"
