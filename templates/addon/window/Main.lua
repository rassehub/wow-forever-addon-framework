local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- A window addon: a main window, settings, a minimap button and a slash command.
-- Start here: replace the content built in buildWindow and the settings in ns.options.

ns.db = FK:NewDB("__NAME__DB", {
	profile = {
		ui = FK.Copy(FK.AppearanceDefaults),
		window = {},
		minimap = {},
		note = "",
		showOnLogin = false,
	},
})
FK:BindAppearance(ns.db, "profile.ui")

local function buildWindow()
	local win = FK.Window(UIParent, {
		title = "__NAME__", width = 420, height = 300, resizable = true, saved = { ns.db, "profile.window" },
		buttons = { { icon = "cog", tooltip = L["Settings"], onClick = function() ns.options:Open() end } },
	})
	local _, refs = FK.Build(win.content, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, children = {
		{ "Heading", text = L["Notes"] },
		{ "TextArea", id = "note", height = 160, value = ns.db.profile.note,
			onChange = function(text) ns.db:Set("profile.note", text) end },
	} })
	ns.refs = refs
	return win
end

FK:OnLogin(function()
	ns.window = buildWindow()
	ns.options = FK:Options({
		db = ns.db,
		pages = {
			{ id = "general", label = L["General"], options = {
				{ type = "toggle", key = "profile.showOnLogin", label = L["Open the window at login"] },
				{ type = "toggle", key = "profile.minimap.hide", label = L["Hide the minimap button"],
					onChange = function(hide) ns.minimap:SetHidden(hide) end },
			} },
		},
		appearance = "profile.ui",
		profiles = true,
	})
	ns.minimap = FK.MinimapButton({
		icon = "Interface\\Icons\\INV_Misc_Note_01", title = "__NAME__", saved = { ns.db, "profile.minimap" },
		tooltip = { "__NAME__", L["Left-click: open. Right-click: settings."] },
		onClick = function(_, button) if button == "RightButton" then ns.options:Open() else ns.window:Toggle() end end,
	})
	FK:Slash({ "/__SLUG__" }, {
		[""] = function() ns.window:Toggle() end,
		config = { L["Open the settings"], function() ns.options:Open() end },
	})
	if ns.db.profile.showOnLogin then ns.window:Open() end
end)

-- Named in the TOC (## AddonCompartmentFunc): the one global this addon defines.
function __NAME___OnCompartmentClick() ns.window:Toggle() end
