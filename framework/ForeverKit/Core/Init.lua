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

---@module FK  The library object, in the addon's namespace: local ADDON, ns = ...; local FK = ns.FK. FK.addon (folder name), FK.title (TOC title), FK.version, FK.dev (true: design warnings print in chat), FK:Warn(code, message) records a design warning in FK.warnings, FK.Media("Icons/cog") is the path of the library's own art (Media/: 54 icons, nine-slice frames).

-- The library's own art (Media/). The client's stack names this file's real path, so the art is
-- found wherever the addon embeds the library; the conventional Libs\ForeverKit is the fallback.
do
	local here = debugstack and debugstack(1, 1, 0) or ""
	local base = here:match("(Interface[/\\][Aa]dd[Oo]ns[/\\].-)[/\\]Core[/\\]Init%.lua")
	FK.mediaPath = (base or ("Interface\\AddOns\\" .. ADDON .. "\\Libs\\ForeverKit")):gsub("/", "\\") .. "\\Media\\"
end
-- FK.Media("Icons/cog") -> full texture path of Media/Icons/cog.png
function FK.Media(name) return FK.mediaPath .. name:gsub("/", "\\") .. ".png" end

-- A mistake in how the library is used that is not fatal: wrong control for the data, missing
-- label, and so on. Recorded always, printed once each in dev mode.
function FK:Warn(code, message)
	local key = code .. ": " .. message
	if self.warnings[key] then return end
	self.warnings[key] = true
	self.warnings[#self.warnings + 1] = key
	if self.dev then print("|cffff8040[" .. ADDON .. " dev]|r " .. key) end
end
