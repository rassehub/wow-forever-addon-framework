-- Minimap experiment (step 14): which round mask exists, whether the minimap can be non-square
-- (resized, or cut by a clipping parent), and what other addons' buttons do after the drawer
-- takes them. Takes four screenshots ~2 s apart; /reload afterwards restores everything.
-- Run: tools/fk live run --file tools/experiments/minimap.lua
local function where(name)
	local f = _G[name]
	if not f then return name .. ": missing" end
	local p = f:GetParent()
	local pt, rel, _, x, y = f:GetPoint(1)
	return ("%s parent=%s visible=%s point=%s %s %.0f,%.0f"):format(name, p and (p:GetName() or "unnamed") or "nil",
		tostring(f:IsVisible()), tostring(pt), rel and rel.GetName and (rel:GetName() or "unnamed") or tostring(rel), x or 0, y or 0)
end
local probe = { "LibDBIcon10_Questie", "GoalNotesMinimapButton" }
local function note(key) local t = {} for i, n in ipairs(probe) do t[i] = where(n) end FKDev.Note(key, unpack(t)) end

FKDev.Note("masks", "CircleMaskScalable=" .. tostring(GetFileIDFromPath("Interface\\Masks\\CircleMaskScalable")),
	"TempPortraitAlphaMask=" .. tostring(GetFileIDFromPath("Interface\\CharacterFrame\\TempPortraitAlphaMask")),
	"Textures\\MinimapMask=" .. tostring(GetFileIDFromPath("Textures\\MinimapMask")),
	"SquareMask=" .. tostring(GetFileIDFromPath("Interface\\Masks\\SquareMask")))
FKDev.Note("minimap", "size", Minimap:GetSize(), "parent", Minimap:GetParent():GetName() or "unnamed", "rotate", C_CVar.GetCVar("rotateMinimap"))
note("buttons before")
local parent, points = Minimap:GetParent(), {}
for i = 1, Minimap:GetNumPoints() do points[i] = { Minimap:GetPoint(i) } end
local w, h = Minimap:GetSize()

FKDev.Steps({
	{ 0, function() SlashCmdList.FKGALLERY("minimap square metal") note("drawer +0s") end },
	{ 0.2, function() SlashCmdList.FKGALLERY("minimap drawer") end },
	{ 2, function() note("drawer +2s") Screenshot() end },                                   -- 1: square, metal, drawer open
	{ 2, function() SlashCmdList.FKGALLERY("minimap reset") Minimap:SetMaskTexture("Interface\\Masks\\CircleMaskScalable") end },
	{ 1, function() Screenshot() end },                                                      -- 2: CircleMaskScalable
	{ 1, function() Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8") Minimap:SetSize(340, 200) end },
	{ 1.5, function() FKDev.Note("resized", Minimap:GetSize()) Screenshot() end },           -- 3: non-square by SetSize
	{ 1, function()
		Minimap:SetSize(w, h)
		local clip = CreateFrame("Frame", nil, UIParent)
		clip:SetSize(340, 200)
		clip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -260)
		clip:SetClipsChildren(true)
		Minimap:SetParent(clip)
		Minimap:ClearAllPoints()
		Minimap:SetPoint("CENTER")
		Minimap:SetSize(340, 340)
	end },
	{ 1.5, function() Screenshot() end },                                                    -- 4: square minimap cut by a clipping parent
	{ 1, function()
		Minimap:SetParent(parent)
		Minimap:ClearAllPoints()
		for _, p in ipairs(points) do Minimap:SetPoint(unpack(p)) end
		Minimap:SetSize(w, h)
		Minimap:SetMaskTexture("Interface\\Masks\\CircleMaskScalable")
		FKDev.Note("restored", Minimap:GetSize())
	end },
})
return "experiment started"
