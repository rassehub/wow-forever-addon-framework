local _, ns = ...
local FK = ns.FK

---@module Locale  local L = FK.L; L["English text"] returns the translation or the key. FK:Locale("deDE", { ["English text"] = "Deutscher Text" }) adds a translation for that client language.

-- local L = FK.L;  L["Reset position"]  -> the translation, or the key itself (English).
-- FK:Locale("deDE", { ["Reset position"] = "Position zurücksetzen" })
FK.L = setmetatable({}, { __index = function(_, key) return key end })

function FK:Locale(locale, strings)
	if GetLocale() ~= locale then return end
	for key, text in pairs(strings) do rawset(self.L, key, text) end
end
