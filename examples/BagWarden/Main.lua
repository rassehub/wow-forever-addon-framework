local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- Example: a settings-heavy addon with no window of its own. It warns when your bags fill up;
-- almost everything about the warning is a setting, which shows most option types of FK:Options.
-- /bagwarden opens the settings (also in the game's Settings window and the addon compartment).

local BAGS = { { value = 0, label = L["Backpack"] } }
for i = 1, NUM_BAG_SLOTS do BAGS[#BAGS + 1] = { value = i, label = L["Bag %d"]:format(i) } end

ns.db = FK:NewDB("BagWardenDB", {
	profile = {
		ui = FK.Copy(FK.AppearanceDefaults),
		warn = { enabled = true, freeSlots = 4, repeatAfter = 0 },
		sound = { enabled = true, name = "RAID_WARNING" },
		message = { text = "Bags nearly full: %d free", color = { 1, 0.5, 0.1 }, where = "chat" },
		bags = { [0] = true, true, true, true, true },
		statusKey = nil,
	},
})
FK:BindAppearance(ns.db, "profile.ui")

-- Free slots in the bags the user chose to count.
function ns.Free()
	local n = 0
	for bag, counted in pairs(ns.db.profile.bags) do
		if counted then n = n + C_Container.GetContainerNumFreeSlots(bag) end
	end
	return n
end

local warnedAt -- GetTime() of the last warning while below the limit
function ns.Message(free)
	local m = ns.db.profile.message
	local ok, text = pcall(string.format, m.text, free) -- the text is user input: a bad % must not break it
	return FK.Colorize(ok and text or m.text, m.color[1], m.color[2], m.color[3])
end

function ns.Check()
	local p = ns.db.profile
	local free = ns.Free()
	if not p.warn.enabled or free > p.warn.freeSlots then warnedAt = nil return end
	local again = p.warn.repeatAfter > 0 and warnedAt and GetTime() - warnedAt >= p.warn.repeatAfter * 60
	if warnedAt and not again then return end
	warnedAt = GetTime()
	local text = ns.Message(free)
	if p.message.where == "toast" then FK.Toast(text) else FK:Print(text) end
	if p.sound.enabled then FK.Sound(p.sound.name) end
end

local function bindStatusKey(key)
	FK.Keybind(key, function() FK:Print(L["%d free slot(s) in counted bags."]:format(ns.Free())) end)
end

FK:OnLogin(function()
	ns.options = FK:Options({
		db = ns.db,
		pages = {
			{ id = "warning", label = L["Warning"], options = {
				{ type = "header", label = L["When to warn"] },
				{ type = "slider", key = "profile.warn.freeSlots", toggleKey = "profile.warn.enabled", label = L["Warn at free slots"],
					desc = L["Warn when the counted bags have this many free slots or fewer."], min = 0, max = 30 },
				{ type = "slider", key = "profile.warn.repeatAfter", label = L["Repeat every"], requires = "profile.warn.enabled",
					desc = L["0 = once each time the bags fill up."], min = 0, max = 30, format = function(v) return v == 0 and L["never"] or (v .. " min") end },
				{ type = "header", label = L["Sound"] },
				{ type = "select", key = "profile.sound.name", toggleKey = "profile.sound.enabled", label = L["Play a sound"],
					items = { { value = "RAID_WARNING", label = L["Raid warning"] }, { value = "READY_CHECK", label = L["Ready check"] },
						{ value = "TELL_MESSAGE", label = L["Whisper"] } } },
			} },
			{ id = "message", label = L["Message"], options = {
				{ type = "input", key = "profile.message.text", label = L["Text"], desc = L["%d is replaced by the number of free slots."] },
				{ type = "color", key = "profile.message.color", label = L["Colour"] },
				{ type = "segmented", key = "profile.message.where", label = L["Show in"],
					items = { { value = "chat", label = L["Chat"] }, { value = "toast", label = L["Toast"] } } },
				{ type = "button", label = L["Preview"], onClick = function() FK:Print(ns.Message(ns.Free())) end },
			} },
			{ id = "bags", label = L["Bags"], options = {
				{ type = "checklist", key = "profile.bags", label = L["Count these bags"], items = BAGS, height = 140 },
			} },
			{ id = "keys", label = L["Key binding"], options = {
				{ type = "keybind", key = "profile.statusKey", label = L["Print free slots"], onChange = bindStatusKey },
			} },
		},
		appearance = "profile.ui",
		profiles = true,
	})
	FK:On("fk.bags", ns.Check)
	ns.db:OnChange("profile", function() warnedAt = nil ns.Check() end)
	if ns.db.profile.statusKey then bindStatusKey(ns.db.profile.statusKey) end
	FK:Slash({ "/bagwarden" }, function() ns.options:Open() end)
	ns.Check()
end)

function BagWarden_OnCompartmentClick() ns.options:Open() end
