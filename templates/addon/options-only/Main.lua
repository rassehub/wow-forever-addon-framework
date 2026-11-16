local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- A settings-only addon: no window of its own, behaviour driven by options (here: a warning when
-- your bags are nearly full). /__SLUG__ opens the settings, also reachable from the game's
-- Settings window and the addon compartment.

ns.db = FK:NewDB("__NAME__DB", {
	profile = {
		ui = FK.Copy(FK.AppearanceDefaults),
		warn = { enabled = true, freeSlots = 4, sound = true },
	},
})
FK:BindAppearance(ns.db, "profile.ui")

local warned = false
function ns.Check()
	local w = ns.db.profile.warn
	local free = FK.Bags.Free()
	if not w.enabled or free > w.freeSlots then warned = false return end
	if warned then return end -- once per time the bags fill up
	warned = true
	FK:Print(L["Bags nearly full: %d free slot(s)."]:format(free))
	if w.sound then FK.Sound("RAID_WARNING") end
end

FK:OnLogin(function()
	ns.options = FK:Options({
		db = ns.db,
		pages = {
			{ id = "general", label = L["General"], options = {
				{ type = "header", label = L["Bag space"] },
				{ type = "slider", key = "profile.warn.freeSlots", toggleKey = "profile.warn.enabled",
					label = L["Warn at free slots"], desc = L["A chat message when your bags have this many free slots or fewer."],
					min = 0, max = 20, step = 1 },
				{ type = "toggle", key = "profile.warn.sound", label = L["Play a sound"], requires = "profile.warn.enabled" },
			} },
		},
		appearance = "profile.ui",
		profiles = true,
	})
	FK:On("fk.bags", ns.Check)
	FK:Slash({ "/__SLUG__" }, function() ns.options:Open() end)
	ns.Check()
end)

function __NAME___OnCompartmentClick() ns.options:Open() end
