-- Entry point of the emulator: `local H = require("wow")`.
-- H.Reset() gives a pristine client; H.Start(addonDir) loads an addon and logs in.

local H = require("wow.state")
require("wow.objects")
require("wow.sim")
require("wow.api")
require("wow.loader")
require("wow.tree")
require("wow.render")

local G = _G
local baseline = {}
for k in pairs(G) do baseline[k] = true end
-- not available to addon code in the client
local HIDDEN = { "io", "os", "require", "dofile", "loadfile", "package", "debug", "module" }
local hidden = {}
for _, k in ipairs(HIDDEN) do hidden[k] = G[k] end
H.lua = hidden -- for harness code that still needs them

local IGNORED_GLOBAL = { "^SLASH_", "^BINDING_", "^_$" }

function H.Reset()
	setmetatable(G, nil)
	for k in pairs(G) do
		if not baseline[k] then rawset(G, k, nil) end
	end
	for _, k in ipairs(HIDDEN) do rawset(G, k, nil) end
	H.gen, H.serial, H.frames, H.events, H.timers = 0, 0, {}, {}, {}
	H.clock, H.mouseX, H.mouseY, H.hover, H.focus, H.moving = 1000, 0, 0, nil, nil, nil
	H.log, H.modifiers, H.inCombat, H.forceSecrets, H.loggedIn = {}, {}, false, false, false
	H.addons, H.loadOrder, H.saved, H.warnings, H.undefined = {}, {}, {}, {}, {}
	H.eventHooks, H.popup, H.colorPicker, H.reloadRequested, H.compartment = nil, nil, nil, nil, nil
	H.addonPaths = H.addonPaths or {}
	H.Install()
	-- Track globals: writes while an addon file is loading are leaks unless declared in its TOC;
	-- reads of undefined names are remembered so a typo'd API shows up in the test report.
	setmetatable(G, {
		__newindex = function(t, k, v)
			rawset(t, k, v)
			local addon = H.loading
			if addon and type(k) == "string" then
				for _, pat in ipairs(IGNORED_GLOBAL) do
					if k:find(pat) then return end
				end
				addon.globals[k] = true
			end
		end,
		__index = function(_, k)
			if type(k) == "string" then H.undefined[k] = true end
			return nil
		end,
	})
end

-- Globals an addon created that are neither its SavedVariables nor named frames.
function H.LeakedGlobals(addonName)
	local addon = H.addons[addonName]
	local declared, out = {}, {}
	for _, v in ipairs(addon.saved) do declared[v] = true end
	for _, v in ipairs(addon.savedPerChar) do declared[v] = true end
	for k in pairs(addon.globals) do
		local v = rawget(G, k)
		local isFrame = type(v) == "table" and type(rawget(v, 0)) == "table"
		if not declared[k] and not isFrame and k ~= addon.meta.AddonCompartmentFunc
			and k ~= addon.meta.AddonCompartmentFuncOnEnter and k ~= addon.meta.AddonCompartmentFuncOnLeave then
			out[#out + 1] = k
		end
	end
	table.sort(out)
	return out
end

H.Reset()
return H
