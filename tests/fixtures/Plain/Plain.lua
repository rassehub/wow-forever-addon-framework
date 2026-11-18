local name, ns = ...

local f = CreateFrame("Frame", "PlainFrame", UIParent, "BackdropTemplate")
f:SetSize(300, 200)
f:SetPoint("CENTER")
f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
tinsert(UISpecialFrames, "PlainFrame")
ns.frame = f

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Plain")

local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
count:SetPoint("CENTER")
ns.count = count

local button = CreateFrame("Button", nil, f)
button:SetSize(100, 22)
button:SetPoint("BOTTOM", 0, 12)
button:SetText("Add")
button:SetScript("OnClick", function()
	PlainDB.clicks = PlainDB.clicks + 1
	count:SetText("Clicks: " .. PlainDB.clicks)
end)
ns.button = button

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, addon)
	-- the default UI closes UISpecialFrames windows on entering the world: show again after it
	if event == "PLAYER_ENTERING_WORLD" then C_Timer.After(0, function() f:Show() end) return end
	if addon ~= name then return end
	PlainDB = PlainDB or { clicks = 0 }
	count:SetText("Clicks: " .. PlainDB.clicks)
end)

SLASH_PLAIN1 = "/plain"
SlashCmdList.PLAIN = function() f:SetShown(not f:IsShown()) end

local Redraw
function Redraw() count:SetText("") end
