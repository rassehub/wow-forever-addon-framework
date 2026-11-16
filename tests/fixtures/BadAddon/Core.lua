local ADDON, ns = ...
local FK = ns.FK

LeakedTable = {}

function GlobalHelper() end

local db = FK:NewDB("WrongNameDB", { profile = { range = "40 yd" } })

local options = FK:Options({ db = db, options = {
	{ type = "select", key = "profile.range", label = "Range", items = { "20 yd", "40 yd", "60 yd", "80 yd" } },
} })
FK:Slash("/badaddon", function() options:Open() end)

local function Unsafe()
	local name = GetItemInfo(2589)
	if UnitHealth("player") < 100 then print(name) end
	local f = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
	f.text:SetFont("Fonts\\FRIZQT__.TTF", 12)
end
ns.Unsafe = Unsafe
