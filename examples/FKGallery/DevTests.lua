local ADDON, ns = ...
local FK = ns.FK

-- In-game checks run by FKDev (tools/FKDev) when it is installed: the things the emulator
-- cannot know about the real client. Without FKDev this file does nothing.
if not FKDev then return end

local function texturePaths()
	local paths, seen = {}, {}
	local function walk(v)
		if type(v) == "string" and v:find("^Interface\\") and not seen[v] then
			seen[v] = true
			paths[#paths + 1] = v
		elseif type(v) == "table" then
			for _, x in pairs(v) do walk(x) end
		end
	end
	walk(FK.Theme.themes)
	-- art used by feature modules
	for _, p in ipairs({ "Interface\\Minimap\\MiniMap-TrackingBorder", "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
		"Interface\\Minimap\\ObjectIcons" }) do walk(p) end
	table.sort(paths)
	return paths
end

FKDev.Test(ADDON, "every texture path in themes and features exists", function(assert)
	for _, path in ipairs(texturePaths()) do
		assert(GetFileIDFromPath(path) ~= nil, "missing texture: " .. path)
	end
end)

FKDev.Test(ADDON, "every theme switches without errors and keeps the window on screen", function(assert)
	local g = ns.gallery
	assert(g and g.window:IsShown(), "gallery window open")
	local before = FK.Theme.name
	for _, name in ipairs(FK.Theme:Names()) do
		FK.Theme:Set(name)
		for _, id in ipairs({ "controls", "choices", "rows", "collections", "display" }) do g.tabs:Select(id) end
		local l, t = g.window:GetLeft(), g.window:GetTop()
		assert(l and t and l >= 0 and t <= UIParent:GetTop() + 1, name .. ": window off screen")
	end
	g.tabs:Select("controls")
	FK.Theme:Set(before)
end)

FKDev.Test(ADDON, "client APIs the feature modules rely on exist", function(assert)
	assert(WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child, "WorldMapFrame canvas at login")
	assert(WorldMapFrame and type(WorldMapFrame.OnMapChanged) == "function", "WorldMapFrame:OnMapChanged")
	assert(AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon, "addon compartment")
	assert(type(SetOverrideBindingClick) == "function", "SetOverrideBindingClick")
	assert(TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall, "TooltipDataProcessor")
	assert(C_EncodingUtil and C_EncodingUtil.DeserializeCBOR, "C_EncodingUtil")
	assert(UiMapPoint and C_SuperTrack and C_Map.SetUserWaypoint, "map waypoints")
	for _, kit in ipairs({ "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_MAINMENU_OPTION_CHECKBOX_OFF", "IG_MAINMENU_OPTION",
		"IG_MAINMENU_OPEN", "IG_MAINMENU_CLOSE", "IG_CHARACTER_INFO_TAB" }) do
		assert(SOUNDKIT[kit], "SOUNDKIT." .. kit)
	end
	for _, font in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormalLarge" }) do
		assert(_G[font] and _G[font].GetFont, "font object " .. font)
	end
end)

FKDev.Test(ADDON, "the minimap button sits on the minimap edge", function(assert)
	local btn = FK.MinimapButton({ icon = 134400, title = "FKGallery" })
	local mx, my = Minimap:GetCenter()
	local bx, by = btn:GetCenter()
	local r = math.sqrt((bx - mx) ^ 2 + (by - my) ^ 2)
	assert(math.abs(r - (Minimap:GetWidth() / 2 + 10)) < 2, "distance from centre " .. r)
	btn:Hide()
end)
