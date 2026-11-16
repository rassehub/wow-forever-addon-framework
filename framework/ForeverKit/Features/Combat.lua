local _, ns = ...
local FK = ns.FK

---@module Combat  FK:AfterCombat(fn, key): runs fn now, or when combat ends if in combat lockdown (protected actions: showing secure frames, bindings, Settings). A key replaces an earlier queued call with the same key. FK:InCombat().
local queue, keyed = {}, {}

function FK:InCombat() return InCombatLockdown() end

function FK:AfterCombat(fn, key)
	if not InCombatLockdown() then return fn() end
	if key then
		if not keyed[key] then queue[#queue + 1] = key end
		keyed[key] = fn
	else
		queue[#queue + 1] = fn
	end
end

FK:On("PLAYER_REGEN_ENABLED", function()
	local run = queue
	queue = {}
	for _, item in ipairs(run) do
		local fn = item
		if type(item) ~= "function" then fn, keyed[item] = keyed[item], nil end
		fn()
	end
end)
