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

---@module Binding  FK.Binding(name, label, fn) puts an action in the game's Key Bindings menu (under the addon's title), where players bind it like any other: FK.Binding("MYADDON_TOGGLE", "Toggle My Addon", fn). The client only lists actions from a Bindings.xml, so `tools/fk sync` (and build) writes that file from these calls; never edit it by hand. Call it at file load. name: capitals, digits and _ (keep it once players have bound it: the binding is saved by name).
local actions
function FK.Binding(name, label, fn)
	if type(name) ~= "string" or not name:match("^[A-Z][A-Z0-9_]*$") or type(fn) ~= "function" then
		error('FK.Binding("NAME_IN_CAPITALS", label, function)', 2)
	end
	if not actions then
		actions = {}
		-- the generated Bindings.xml calls this by name: the one global a binding needs
		_G["FKBinding_" .. ADDON] = function(action) if actions[action] then actions[action]() end end
		_G["BINDING_HEADER_" .. ADDON:upper():gsub("[^%w]", "_")] = FK.title
	end
	actions[name] = fn
	_G["BINDING_NAME_" .. name] = label
end
