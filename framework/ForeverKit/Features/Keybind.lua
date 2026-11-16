local _, ns = ...
local FK = ns.FK

---@module Keybind  FK.Keybind(key, fn) binds a key combination ("CTRL-SHIFT-K", as KeybindButton records it) to fn while the addon is loaded, without touching the player's saved key bindings. FK.Keybind(key, nil) removes it. Bindings change after combat if set during it.
local ADDON = ...
local owner = CreateFrame("Frame")
local buttons, count = {}, 0

function FK.Keybind(key, fn)
	FK:AfterCombat(function()
		local old = buttons[key]
		if old then
			old.fn = nil
			ClearOverrideBindings(owner)
			for k, b in pairs(buttons) do if k ~= key and b.fn then SetOverrideBindingClick(owner, false, k, b:GetName()) end end
			buttons[key] = nil
		end
		if not fn then return end
		count = count + 1
		-- override bindings click a frame by global name: the one global name this needs
		local b = old or CreateFrame("Button", ADDON .. "FKKeybind" .. count, owner)
		b.fn = fn
		b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
		buttons[key] = b
		SetOverrideBindingClick(owner, false, key, b:GetName())
	end, "fk.keybind." .. key)
end
