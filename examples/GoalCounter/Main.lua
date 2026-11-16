local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- A tracker addon: a small always-visible frame that follows game state (here: how many of an
-- item you carry against a goal). Add goals with /goalcounter add <item link or id> <count>.

ns.db = FK:NewDB("GoalCounterDB", {
	profile = {
		ui = FK.Copy(FK.AppearanceDefaults),
		tracker = {},
		shown = true,
		locked = false,
		hideDone = false,
		goals = {}, -- [itemID] = target count
	},
})
FK:BindAppearance(ns.db, "profile.ui")

function ns.Lines()
	local lines = {}
	for id, target in pairs(ns.db.profile.goals) do
		local have = FK.Bags.Count(id)
		if not (ns.db.profile.hideDone and have >= target) then
			local info = FK.Items.Info(id)
			lines[#lines + 1] = {
				text = info and info.name or ("item:" .. id), icon = info and info.icon,
				value = ("%d/%d"):format(have, target), progress = math.min(have / target, 1),
				color = have >= target and "good" or nil,
			}
		end
	end
	table.sort(lines, function(a, b) return a.text < b.text end)
	return lines
end

function ns.Refresh()
	if not ns.tracker then return end
	ns.tracker:SetLines(ns.Lines())
	ns.tracker:SetShown(ns.db.profile.shown)
	ns.tracker:SetLocked(ns.db.profile.locked)
end

function ns.AddGoal(item, count)
	local id = FK.Items.ID(item)
	if not id or not count or count < 1 then return false end
	ns.db:Set("profile.goals." .. id, count)
	FK.Items.Load(id, ns.Refresh) -- the name arrives once the item data is cached
	ns.Refresh()
	return true
end

FK:OnLogin(function()
	ns.tracker = FK.Tracker(UIParent, { title = "GoalCounter", saved = { ns.db, "profile.tracker" } })
	ns.options = FK:Options({
		db = ns.db,
		pages = {
			{ id = "general", label = L["General"], options = {
				{ type = "toggle", key = "profile.shown", label = L["Show the tracker"], onChange = ns.Refresh },
				{ type = "toggle", key = "profile.locked", label = L["Lock position"], onChange = ns.Refresh },
				{ type = "toggle", key = "profile.hideDone", label = L["Hide finished goals"], onChange = ns.Refresh },
			} },
		},
		appearance = "profile.ui",
		profiles = true,
	})
	FK:On("fk.bags", ns.Refresh)
	ns.db:OnChange("profile", ns.Refresh)
	FK:Slash({ "/goalcounter" }, {
		[""] = function() ns.db:Set("profile.shown", not ns.db.profile.shown) ns.Refresh() end,
		add = { L["Track an item: /goalcounter add <item> <count>"], function(arg)
			local item, count = arg:match("^(.-)%s+(%d+)$")
			if not ns.AddGoal(tonumber(item) or item, tonumber(count)) then FK:Print(L["Usage: /goalcounter add <item link or id> <count>"]) end
		end },
		clear = { L["Remove all goals"], function() ns.db:Set("profile.goals", {}) ns.Refresh() end },
		config = { L["Open the settings"], function() ns.options:Open() end },
	})
	for id in pairs(ns.db.profile.goals) do FK.Items.Load(id, ns.Refresh) end
	ns.Refresh()
end)

function GoalCounter_OnCompartmentClick() ns.options:Open() end
