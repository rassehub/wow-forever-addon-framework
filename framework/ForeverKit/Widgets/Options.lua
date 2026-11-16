local ADDON, ns = ...
local FK = ns.FK
local Theme = FK.Theme
local L = FK.L

---@module Options  Settings described as data; the library builds the panel, binds every control to the saved settings, adds profile management and an entry in the game's Settings window.
--
--   ns.options = FK:Options({
--       db = ns.db,
--       pages = {
--           { id = "general", label = "General", options = {
--               { type = "header", label = "Tracker" },
--               { type = "toggle", key = "profile.tracker.shown", label = "Show the tracker", desc = "..." },
--               { type = "slider", key = "profile.tracker.scale", label = "Scale", min = 0.5, max = 1.5, step = 0.05, live = false,
--                 requires = "profile.tracker.shown" },
--               { type = "slider", key = "profile.fade.amount", toggleKey = "profile.fade.enabled", label = "Fade when idle", min = 0, max = 1, percent = true },
--               { type = "select", key = "profile.channel", label = "Announce to", items = { "Say", "Party", "Guild" } },
--               { type = "group", label = "Sounds", toggleKey = "profile.sound.enabled", children = { ...more options... } },
--           } },
--       },
--       appearance = "profile.ui",   -- adds an Appearance page bound to FK:BindAppearance
--       profiles = true,             -- adds a Profiles page
--   })
--   ns.options:Open()          -- or :Open("general") to show a given page
--
-- Option types: header, text, toggle, slider, stepper, select, multiselect, segmented, color,
-- keybind, input, money, checklist, reorder, button, group.
-- Keys of every option: key ("profile.x.y" in the db), label, desc, requires (db key that must be
-- true for this option to be enabled), disabled (function -> bool), hidden (function -> bool),
-- onChange(value), requiresReload, get/set (replace the db binding), toggleKey (slider/select:
-- a switch in front that enables it; group: the switch that unfolds it).
-- A numeric setting is a slider or stepper. A select whose items are all numbers is a lint error.

local Options = {}
Options.__index = Options

FK.AppearanceDefaults = { theme = "vanilla", opacity = 1, fontDelta = 0 }

-- Applies the saved look (theme, window opacity, font size) now and whenever it changes.
-- Put `ui = FK.Copy(FK.AppearanceDefaults)` in the profile defaults and call
-- FK:BindAppearance(ns.db, "profile.ui") once.
function FK:BindAppearance(db, key)
	local function apply()
		local ui = db:Get(key) or FK.AppearanceDefaults
		Theme.opacity, Theme.fontDelta = ui.opacity or 1, ui.fontDelta or 0
		Theme:Set(Theme.themes[ui.theme] and ui.theme or FK.AppearanceDefaults.theme)
	end
	FK:OnLoad(function()
		apply()
		db:OnChange(key, apply)
	end)
end

local WIDGET = {
	select = "Dropdown", multiselect = "MultiDropdown", segmented = "Segmented", keybind = "KeybindButton",
	input = "EditBox", stepper = "Stepper", slider = "Slider",
}
local PASS = { "min", "max", "step", "format", "percent", "live", "items", "placeholder", "numeric", "hasAlpha", "search", "height", "editable", "steppers" }

function Options:Binding(o)
	local db = self.db
	local isSet = o.type == "multiselect" or o.type == "checklist"
	local get = o.get or function()
		local v = db:Get(o.key)
		if isSet then
			-- stored with explicit false so a default of true can be switched off
			local set = {}
			for k, on in pairs(v or {}) do if on then set[k] = true end end
			return set
		end
		return v
	end
	local function set(v)
		if isSet and not o.set then
			local stored = {}
			for _, item in ipairs(FK.ResolveItems(o.items)) do stored[item.value] = v[item.value] == true end
			v = stored
		end
		if o.set then o.set(v) else db:Set(o.key, v) end
		if o.onChange then o.onChange(v) end
		if o.requiresReload then FK.ReloadPrompt(o.label) end
		self:Refresh()
	end
	return get, set
end

-- Turns one option into a widget spec for FK.Build and remembers how to refresh it.
function Options:Spec(o, bound)
	self.count = self.count + 1
	local id = "o" .. self.count
	local t = o.type
	local spec
	local label = o.label
	if o.requiresReload and label then label = label .. " |cff808080(" .. L["reload"] .. ")|r" end

	if t == "header" then
		return { "Heading", text = o.label }
	elseif t == "text" then
		return { "Label", text = o.text or o.label, color = "dim" }
	elseif t == "button" then
		spec = { "Button", text = o.label, onClick = o.onClick, tooltip = o.desc }
	elseif t == "group" then
		-- the group is refreshed before its children, so their own `requires` has the last word
		local entry = { id = id, o = o }
		bound[#bound + 1] = entry
		local children = {}
		for _, child in ipairs(o.children or {}) do children[#children + 1] = self:Spec(child, bound) end
		spec = { "OptionRow", label = label, desc = o.desc, children = children, cog = o.cog, expanded = o.expanded }
		if o.toggleKey then
			local toggle = { type = "toggle", key = o.toggleKey, onChange = o.onChange }
			local get, set = self:Binding(toggle)
			spec.toggle, spec.onToggle, spec.linkExpand = get() and true or false, set, not o.cog
			entry.apply = function(w) w:SetToggle(get()) end
		elseif spec.expanded == nil then
			spec.expanded = true
		end
		spec.id = id
		return spec
	else
		if not o.key and not (o.get and o.set) then
			error(("FK:Options: option %q (%s) needs a key, or get and set"):format(tostring(o.label), tostring(t)), 0)
		end
		local get, set = self:Binding(o)
		local apply
		if t == "toggle" then
			spec = { "OptionRow", label = label, desc = o.desc, toggle = get() and true or false, onToggle = set }
			apply = function(w) w:SetToggle(get()) end
		elseif t == "color" then
			spec = { "ColorSwatch", label = label, tooltip = o.desc, hasAlpha = o.hasAlpha, value = get(), onChange = set }
		elseif t == "money" then
			spec = { "MoneyInput", label = label, value = get(), onChange = set }
		elseif t == "checklist" then
			spec = { "CheckList", label = label, items = o.items, search = o.search, height = o.height, value = get(), onChange = set }
		elseif t == "reorder" then
			spec = { "ReorderList", label = label, items = o.items, height = o.height, value = get(), onChange = set }
		elseif WIDGET[t] then
			local control = { WIDGET[t], value = get() }
			for _, k in ipairs(PASS) do control[k] = o[k] end
			spec = { "OptionRow", label = label, desc = o.desc, control = control, onChange = set, linkExpand = false,
				controlWidth = o.controlWidth or (t == "slider" and 220 or t == "stepper" and 110 or 170) }
			if o.toggleKey then
				local tget, tset = self:Binding({ type = "toggle", key = o.toggleKey })
				spec.toggle, spec.onToggle = tget() and true or false, tset
				apply = function(w)
					w:SetToggle(tget())
					w:SetValue(get())
				end
			end
		else
			error("FK:Options: unknown option type " .. tostring(t), 0)
		end
		spec.id = id
		bound[#bound + 1] = { id = id, o = o, apply = apply or function(w) w:SetValue(get()) end }
		return spec
	end
	spec.id = id
	bound[#bound + 1] = { id = id, o = o }
	return spec
end

local function resetKeys(options, keys)
	for _, o in ipairs(options) do
		if o.key then keys[#keys + 1] = o.key end
		if o.toggleKey then keys[#keys + 1] = o.toggleKey end
		if o.children then resetKeys(o.children, keys) end
	end
	return keys
end

function Options:BuildPage(page, frame)
	local bound = {}
	local children = {}
	for _, o in ipairs(page.options) do children[#children + 1] = self:Spec(o, bound) end
	if page.defaults ~= false and #resetKeys(page.options, {}) > 0 then
		children[#children + 1] = { "Spacer", height = 6 }
		children[#children + 1] = { "Button", text = L["Defaults"], tooltip = L["Reset the settings on this page"], onClick = function()
			for _, key in ipairs(resetKeys(page.options, {})) do self.db:Reset(key) end
			self:Refresh()
		end }
	end
	local _, refs = FK.Build(frame, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, children = children })
	local view = { bound = bound, refs = refs }
	self.views[#self.views + 1] = view
	self:RefreshView(view)
end

function Options:RefreshView(view)
	local db = self.db
	for _, b in ipairs(view.bound) do
		local w, o = view.refs[b.id], b.o
		if b.apply then b.apply(w) end
		local disabled = (o.requires and not db:Get(o.requires)) or (o.disabled and o.disabled()) or false
		w:SetEnabled(not disabled)
		if o.hidden then
			local hide = o.hidden() and true or false
			if w:IsShown() == hide then
				w:SetShown(not hide)
				w:Changed()
			end
		end
	end
end

-- Re-reads every visible control from the db (after a profile switch, reset or import).
function Options:Refresh()
	if self.refreshing then return end
	self.refreshing = true
	for _, view in ipairs(self.views) do self:RefreshView(view) end
	self.refreshing = nil
end

local function themeItems()
	local items = {}
	for _, name in ipairs(Theme:Names()) do items[#items + 1] = { value = name, label = Theme.themes[name].label } end
	return items
end

function Options:Pages()
	local pages = {}
	for _, p in ipairs(self.def.pages or { { id = "main", label = L["General"], options = self.def.options or {} } }) do pages[#pages + 1] = p end
	local ui = self.def.appearance
	if ui then
		pages[#pages + 1] = { id = "fk-appearance", label = L["Appearance"], options = {
			{ type = "select", key = ui .. ".theme", label = L["Theme"], items = themeItems },
			{ type = "slider", key = ui .. ".opacity", label = L["Background opacity"], min = 0.2, max = 1, percent = true },
			{ type = "slider", key = ui .. ".fontDelta", label = L["Font size"], min = -2, max = 6, step = 1, format = function(v) return (v > 0 and "+" or "") .. v end },
		} }
	end
	if self.def.profiles then pages[#pages + 1] = { id = "fk-profiles", label = L["Profiles"], profiles = true } end
	return pages
end

function Options:BuildProfiles(frame)
	local db = self.db
	local function names() return db:Profiles() end
	local stack = FK.Stack(frame, { points = { { "TOPLEFT" }, { "TOPRIGHT" } } })
	local current
	stack:Batch(function()
		stack:Add(FK.Label(stack, { color = "dim", text = L["Profiles are complete sets of settings. Each character uses one; several characters can share one."] }))
		current = stack:Add(FK.OptionRow(stack, { label = L["Active profile"], control = { "Dropdown", items = names, value = db:GetProfile() }, onChange = function(name)
			db:SetProfile(name)
		end }))
		local row = stack:Add(FK.Row(stack, {}))
		row:Add(FK.Button(row, { text = L["New"], onClick = function()
			FK.Prompt(L["Name of the new profile"], "", function(name)
				name = strtrim(name)
				if name ~= "" then db:SetProfile(name) end
			end)
		end }))
		row:Add(FK.Button(row, { text = L["Reset"], tooltip = L["Put every setting of this profile back to its default"], onClick = function()
			FK.Confirm(L["Reset the profile '%s' to defaults?"]:format(db:GetProfile()), function() db:Reset("profile") end)
		end }))
		row:Add(FK.Button(row, { text = L["Delete"], onClick = function()
			local name = db:GetProfile()
			if name == "Default" then return FK:Print(L["The Default profile cannot be deleted."]) end
			FK.Confirm(L["Delete the profile '%s'?"]:format(name), function()
				db:SetProfile("Default")
				db:DeleteProfile(name)
			end)
		end }))
		stack:Add(FK.OptionRow(stack, { label = L["Copy settings from"], control = { "Dropdown", items = names, placeholder = L["Choose a profile"] }, onChange = function(name, w)
			if name ~= db:GetProfile() then db:CopyProfile(name) end
			w:SetValue(nil)
		end }))
		stack:Add(FK.Heading(stack, { text = L["Share"] }))
		local text = stack:Add(FK.TextArea(stack, { height = 90 }))
		local share = stack:Add(FK.Row(stack, {}))
		share:Add(FK.Button(share, { text = L["Export"], tooltip = L["Show this profile as text to copy (Ctrl+C)"], onClick = function()
			text:SetValue(db:Export())
			text:Focus()
		end }))
		share:Add(FK.Button(share, { text = L["Import"], tooltip = L["Replace this profile with the pasted text"], onClick = function()
			local ok, err = db:Import(text:GetValue())
			FK:Print(ok and L["Profile imported."] or (L["Import failed: "] .. tostring(err)))
		end }))
	end)
	self.views[#self.views + 1] = { bound = {}, refs = {} }
	db:OnChange("profile", function() current:SetValue(db:GetProfile()) end)
end

-- Builds the whole options UI into a frame (the own window, or the Blizzard Settings canvas).
function Options:BuildInto(frame)
	local pages = self:Pages()
	local function build(page)
		return function(pageFrame)
			if page.profiles then self:BuildProfiles(pageFrame) else self:BuildPage(page, pageFrame) end
		end
	end
	if #pages == 1 then
		build(pages[1])(frame)
		return
	end
	local tabs = {}
	for i, p in ipairs(pages) do tabs[i] = { id = p.id or ("page" .. i), label = p.label, build = build(p) } end
	return FK.Tabs(frame, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, side = #pages > 4, tabs = tabs })
end

-- page: optional page id to show (e.g. "keys"); default the last shown page.
function Options:Open(page)
	if not self.window then
		self.window = FK.Window(UIParent, { name = ADDON .. "FKOptions", title = self.def.title or (FK.title .. " - " .. L["Settings"]),
			width = self.def.width or 560, height = self.def.height or 480, resizable = { minWidth = 420, minHeight = 300 }, strata = "HIGH" })
		self.tabs = self:BuildInto(self.window.content)
	end
	if page and self.tabs then self.tabs:Select(page) end
	self:Refresh()
	self.window:Open()
	self.window:Raise()
end
function Options:Close() if self.window then self.window:Close() end end
function Options:Toggle()
	if self.window and self.window:IsShown() then self:Close() else self:Open() end
end

function FK:Options(def)
	if type(def) ~= "table" or not def.db then error("FK:Options({ db = ..., pages = ... }): db is required", 2) end
	local self_ = setmetatable({ def = def, db = def.db, views = {}, count = 0 }, Options)
	FK:OnLoad(function()
		def.db:OnChange(function() self_:Refresh() end)
		if def.blizzard ~= false then
			-- an entry under Options > AddOns; built when first shown
			local canvas = CreateFrame("Frame")
			canvas:Hide()
			canvas:SetScript("OnShow", function(f)
				f:SetScript("OnShow", function() self_:Refresh() end)
				local inner = CreateFrame("Frame", nil, f)
				inner:SetPoint("TOPLEFT", 12, -12)
				inner:SetPoint("BOTTOMRIGHT", -12, 12)
				self_:BuildInto(inner)
			end)
			local category = Settings.RegisterCanvasLayoutCategory(canvas, FK.title)
			Settings.RegisterAddOnCategory(category)
			self_.category = category
		end
	end)
	return self_
end
