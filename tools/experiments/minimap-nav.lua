-- Navigators in the real client (step 14): north-up rectangle with the zoom-nudge redraw, the
-- round rotating navigator, and the unlock grips. Keep walking during the run. Gallery hidden.
-- Run: tools/fk live run --file tools/experiments/minimap-nav.lua
local G = SlashCmdList.FKGALLERY
FKDev.Steps({
	{ 0, function() G("theme modern minimap") G("minimap navigator") G("") end },
	{ 2, function() Screenshot() end },                                        -- 1 north-up rectangle navigator
	{ 1, function() G("minimap unlock") end },
	{ 1.5, function() Screenshot() end },                                      -- 2 unlocked: handle and four grips
	{ 1, function() G("") G("minimap navigator round") G("") end },
	{ 2, function() FKDev.Note("round nav", "rotate", C_CVar.GetCVar("rotateMinimap"), "ring shown", MinimapCompassTexture and MinimapCompassTexture:IsShown()) Screenshot() end }, -- 3 round rotating navigator
	{ 1, function() G("minimap round none 300 300 center") end },
	{ 2, function() FKDev.Note("classic ring", "backdrop", MinimapBackdrop:GetSize()) Screenshot() end }, -- 4 classic ring scaled to 300
	{ 1, function() G("minimap reset") G("") end },
})
return "navigator experiment started"
