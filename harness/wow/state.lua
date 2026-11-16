-- Shared state of the emulated client, the virtual clock and the secret-value simulation.

local type = type -- the real one: api.lua later replaces the global with a secret-aware version

local H = {
	gen = 0,          -- layout generation: bumped by every geometry change, invalidates cached rects
	serial = 0,       -- creation order of objects
	frames = {},      -- every frame ever created (frames are never destroyed, as in the client)
	events = {},      -- event -> set of frames
	timers = {},
	clock = 1000,     -- GetTime()
	frameTime = 0.05, -- length of one simulated frame
	screenWidth = 1366, screenHeight = 768,
	mouseX = 0, mouseY = 0,
	log = {},         -- everything printed to chat
	modifiers = {},   -- SHIFT / CTRL / ALT held
	inCombat = false,
}

---------------------------------------------------------------------------------------------
-- Clock
---------------------------------------------------------------------------------------------

function H.After(delay, fn)
	local t = { at = H.clock + math.max(delay, 0), fn = fn }
	H.timers[#H.timers + 1] = t
	return t
end

local function runDueTimers()
	-- timers may schedule timers: keep draining until none is due
	while true do
		local due
		for i, t in ipairs(H.timers) do
			if t.at <= H.clock and (not due or t.at < H.timers[due].at) then due = i end
		end
		if not due then return end
		local t = table.remove(H.timers, due)
		if not t.cancelled then t.fn() end
	end
end

-- Runs the simulated client for `seconds`: timers, OnUpdate handlers, OnSizeChanged.
function H.Advance(seconds)
	local remaining = seconds or 0
	repeat
		local step = math.min(remaining, H.frameTime)
		H.clock = H.clock + step
		remaining = remaining - step
		runDueTimers()
		for _, f in ipairs({ unpack(H.frames) }) do
			local fn = f[0].scripts.OnUpdate
			if fn and f:IsVisible() then fn(f, step) end
		end
		H.FlushSizeChanged()
	until remaining <= 1e-9
end

function H.FlushSizeChanged()
	-- a handler may resize other frames: repeat until the layout is stable
	for _ = 1, 20 do
		local changed = false
		for _, f in ipairs({ unpack(H.frames) }) do
			local s = f[0]
			if s.scripts.OnSizeChanged then
				local w, h = f:GetSize()
				if s.lastW ~= w or s.lastH ~= h then
					s.lastW, s.lastH = w, h
					changed = true
					s.scripts.OnSizeChanged(f, w, h)
				end
			end
		end
		if not changed then return end
	end
	error("layout does not settle: OnSizeChanged handlers keep resizing each other", 0)
end

---------------------------------------------------------------------------------------------
-- Secret values
-- A secret is an opaque userdata. Arithmetic, ordering, indexing, calling and # raise, as in
-- the client. Limit of Lua 5.1: `secret == 5` cannot be intercepted and is simply false, and
-- `if secretBoolean then` cannot raise. `fk lint` covers those.
---------------------------------------------------------------------------------------------

local values = setmetatable({}, { __mode = "k" })

local function forbidden(what)
	return function() error("attempt to " .. what .. " a secret value (combat-restricted data)", 2) end
end

local function makeSecret(v)
	local u = newproxy(true)
	local mt = getmetatable(u)
	local arith = forbidden("perform arithmetic on")
	mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__mod, mt.__pow, mt.__unm = arith, arith, arith, arith, arith, arith, arith
	mt.__lt, mt.__le = forbidden("compare"), forbidden("compare")
	mt.__index, mt.__newindex = forbidden("index"), forbidden("index")
	mt.__call, mt.__len = forbidden("call"), forbidden("get the length of")
	mt.__concat = function(a, b) return makeSecret(tostring(H.Reveal(a)) .. tostring(H.Reveal(b))) end
	mt.__tostring = function() return "<secret>" end
	values[u] = v
	return u
end

function H.Secret(v)
	if v == nil or values[v] ~= nil then return v end
	return makeSecret(v)
end
function H.IsSecret(v) return type(v) == "userdata" and values[v] ~= nil end
function H.Reveal(v)
	if type(v) == "userdata" and values[v] ~= nil then return values[v] end
	return v
end

return H
