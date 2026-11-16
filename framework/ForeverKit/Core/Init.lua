-- ForeverKit: embedded UI and feature library for WoW Forever addons.
-- It lives in the host addon's private namespace: `local ADDON, ns = ...; local FK = ns.FK`.
-- Nothing is written to _G except what the host asks for (saved variables, slash commands).

local ADDON, ns = ...

local FK = {
	version = "0.1.0",
	addon = ADDON,
	title = C_AddOns.GetAddOnMetadata(ADDON, "Title") or ADDON,
	dev = false,   -- set true while developing: turns design warnings into chat messages
	warnings = {}, -- every design warning raised so far, for tests and FKDev
}
ns.FK = FK

-- A mistake in how the library is used that is not fatal: wrong control for the data, missing
-- label, and so on. Recorded always, printed once each in dev mode.
function FK:Warn(code, message)
	local key = code .. ": " .. message
	if self.warnings[key] then return end
	self.warnings[key] = true
	self.warnings[#self.warnings + 1] = key
	if self.dev then print("|cffff8040[" .. ADDON .. " dev]|r " .. key) end
end
