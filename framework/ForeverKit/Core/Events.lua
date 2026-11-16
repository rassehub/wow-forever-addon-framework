local ADDON, ns = ...
local FK = ns.FK

-- One registry for game events (UPPER_SNAKE names) and the addon's own messages (any other
-- name, by convention "lower.dotted"):
--   local h = FK:On("BAG_UPDATE_DELAYED", fn)     FK:On("goals.changed", fn)
--   FK:Off(h)                                     FK:Emit("goals.changed", goal)
--   FK:Once("PLAYER_REGEN_ENABLED", fn)

local frame = CreateFrame("Frame")
local handlers = {}

local function isGameEvent(name) return name:match("^[A-Z][A-Z0-9_]+$") ~= nil end

function FK:On(name, fn)
	if type(name) ~= "string" or type(fn) ~= "function" then error("FK:On(name, function)", 2) end
	local list = handlers[name]
	if not list then
		list = {}
		handlers[name] = list
		if isGameEvent(name) then
			if not C_EventUtils.IsEventValid(name) then error("FK:On: the client has no event " .. name, 2) end
			frame:RegisterEvent(name)
		end
	end
	local handle = { name = name, fn = fn }
	list[#list + 1] = handle
	return handle
end

function FK:Once(name, fn)
	local handle
	handle = self:On(name, function(...)
		FK:Off(handle)
		fn(...)
	end)
	return handle
end

function FK:Off(handle)
	local list = handle and handlers[handle.name]
	if not list then return end
	for i, h in ipairs(list) do
		if h == handle then
			table.remove(list, i)
			break
		end
	end
	handle.off = true
	if #list == 0 then
		handlers[handle.name] = nil
		if isGameEvent(handle.name) then frame:UnregisterEvent(handle.name) end
	end
end

function FK:Emit(name, ...)
	local list = handlers[name]
	if not list then return end
	-- handlers may remove themselves or others while running
	for _, h in ipairs({ unpack(list) }) do
		if not h.off then h.fn(...) end
	end
end

frame:SetScript("OnEvent", function(_, event, ...) FK:Emit(event, ...) end)

-- Lifecycle. OnLoad: saved variables are readable (ADDON_LOADED of this addon).
-- OnLogin: the player is in the world enough to query (PLAYER_LOGIN). Both run immediately
-- when registered after the fact.
local onLoad, onLogin = {}, {}

function FK:OnLoad(fn)
	if self.loaded then fn() else onLoad[#onLoad + 1] = fn end
end
function FK:OnLogin(fn)
	if self.loggedIn then fn() else onLogin[#onLogin + 1] = fn end
end

local loadHandle
loadHandle = FK:On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	FK:Off(loadHandle)
	FK:Emit("fk.load") -- databases attach here, before user callbacks
	FK.loaded = true
	for _, fn in ipairs(onLoad) do fn() end
end)
FK:On("PLAYER_LOGIN", function()
	FK.loggedIn = true
	for _, fn in ipairs(onLogin) do fn() end
end)
