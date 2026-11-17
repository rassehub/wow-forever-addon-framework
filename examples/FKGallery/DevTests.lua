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

-- Registered after Gallery.lua's login handler, so the window exists: remember who hides it.
local hiddenBy
FK:OnLogin(function()
	ns.gallery.window:HookScript("OnHide", function()
		hiddenBy = hiddenBy or (("at %.2fs after load, %s"):format(GetTime() - ns.loadedAt, debugstack(2, 12, 0)))
	end)
end)
ns.loadedAt = GetTime()

-- The library's own art (Media/): the path FK.Media builds and whether the client loads the files.
FKDev.Test(ADDON, "the library's media path points into this addon", function(assert)
	assert(FK.mediaPath:lower():find("interface\\addons\\fkgallery\\libs\\foreverkit\\media\\", 1, true), "mediaPath = " .. FK.mediaPath)
end)

-- Whether the art itself loads cannot be checked in code: SetTexture returns true even for a
-- missing file (verified in game, step 13). Check it by eye: fk live run --shot with a theme set.

FKDev.Test(ADDON, "every theme switches without errors and keeps the window on screen", function(assert)
	local g = ns.gallery
	assert(g and g.window:IsShown(), "gallery window open; hidden " .. tostring(hiddenBy))
	local before = FK.Theme.name
	for _, name in ipairs(FK.Theme:Names()) do
		FK.Theme:Set(name)
		for _, id in ipairs({ "controls", "choices", "rows", "collections", "journal", "map", "minimap", "display" }) do g.tabs:Select(id) end
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

FKDev.Test(ADDON, "client art and APIs used by the layout kits exist", function(assert)
	for i = 1, 12 do
		local path = ("Interface\\WorldMap\\Azeroth\\Azeroth%d"):format(i)
		assert(GetFileIDFromPath(path) ~= nil, "world map tile " .. path)
	end
	assert(C_Map.GetAreaInfo and C_Map.GetAreaInfo(12) ~= nil, "C_Map.GetAreaInfo(12) = " .. tostring(C_Map.GetAreaInfo and C_Map.GetAreaInfo(12)))
	assert(type(Minimap.SetMaskTexture) == "function", "Minimap:SetMaskTexture")
	assert(type(Minimap.SetZoom) == "function" and type(Minimap.GetZoomLevels) == "function", "Minimap zoom API")
	assert(UIParent.SetHyperlinksEnabled ~= nil, "Frame:SetHyperlinksEnabled")
end)

FKDev.Test(ADDON, "the minimap button sits on the minimap edge", function(assert)
	local btn = FK.MinimapButton({ icon = 134400, title = "FKGallery" })
	local mx, my = Minimap:GetCenter()
	local bx, by = btn:GetCenter()
	local r = math.sqrt((bx - mx) ^ 2 + (by - my) ^ 2)
	assert(math.abs(r - (Minimap:GetWidth() / 2 + 10)) < 2, "distance from centre " .. r)
	btn:Hide()
end)
