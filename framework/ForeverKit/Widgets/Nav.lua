local ADDON, ns = ...
local FK = ns.FK
local Theme = FK.Theme

---@widget Tabs  Pages switched by tabs along the top, or by a list down the left side for many pages (opts.side = true). opts: tabs = { { id, label, build = function(page) ... end } } (build runs once, the first time the page is shown; page is a frame filling the page area), value (initial tab id), side, sideWidth (default 140), onChange(id). Methods: Select(id), GetValue(), GetPage(id).
FK.Define("Tabs", {
	GetValue = function(self) return self.value end,
	SetValue = function(self, id) self:Select(id, true) end,
	GetPage = function(self, id) return self.pages[id] end,
	Select = function(self, id, silent)
		local tab
		for _, t in ipairs(self.opts.tabs) do if t.id == id then tab = t end end
		if not tab then error("FK.Tabs: no tab with id " .. tostring(id), 2) end
		self.value = id
		for pageId, page in pairs(self.pages) do page:SetShown(pageId == id) end
		if not self.pages[id] then
			local page = CreateFrame("Frame", nil, self.area)
			page:SetAllPoints()
			self.pages[id] = page
			if tab.build then tab.build(page, self) end
		end
		self:Restyle()
		if not silent then self:Fire(id) end
	end,
	Restyle = function(self)
		local T = Theme.current
		local m = T.metric
		local side = self.opts.side
		local x, y = 0, 0
		for i, b in ipairs(self.buttons) do
			local selected = self.opts.tabs[i].id == self.value
			Theme.Paint(b, T.surface.tab[selected and "selected" or b.hover and "hover" or "normal"])
			Theme.Font(b.text, "normal", selected and "heading" or nil)
			b:ClearAllPoints()
			if side then
				b:SetPoint("TOPLEFT", 0, -y)
				b:SetSize(self.opts.sideWidth or 140, m.tab)
				b.text:SetJustifyH("LEFT")
				y = y + m.tab + 1
			else
				b:SetPoint("TOPLEFT", x, 0)
				b:SetSize(b.text:GetStringWidth() + 24, m.tab)
				x = x + b:GetWidth() + 1
			end
		end
		self.area:ClearAllPoints()
		if side then
			self.area:SetPoint("TOPLEFT", (self.opts.sideWidth or 140) + m.gap + 2, 0)
		else
			self.area:SetPoint("TOPLEFT", 0, -m.tab - m.gap)
		end
		self.area:SetPoint("BOTTOMRIGHT")
	end,
}, function(self, opts)
	if type(opts.tabs) ~= "table" or #opts.tabs == 0 then error("FK.Tabs: opts.tabs is required", 3) end
	self.pages, self.buttons = {}, {}
	self.area = CreateFrame("Frame", nil, self)
	for i, tab in ipairs(opts.tabs) do
		local b = FK.Frame("Button", self)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		b.text:SetPoint("LEFT", 8, 0)
		b.text:SetPoint("RIGHT", -8, 0)
		b.text:SetWordWrap(false)
		b.text:SetText(tab.label or tab.id)
		b:SetScript("OnEnter", function() b.hover = true self:Restyle() end)
		b:SetScript("OnLeave", function() b.hover = false self:Restyle() end)
		b:SetScript("OnClick", function()
			if self.value == tab.id then return end
			FK.Sound("tab")
			self:Select(tab.id)
		end)
		self.buttons[i] = b
	end
	if not opts.height then self:SetHeight(300) end
	self:Select(opts.value or opts.tabs[1].id, true)
end)

---@widget SideNav  Tabs with the list on the left: for more than about five pages. Same opts as Tabs.
function FK.SideNav(parent, opts)
	opts.side = true
	return FK.Tabs(parent, opts)
end

---------------------------------------------------------------------------------------------
-- Dialogs
---------------------------------------------------------------------------------------------

local dialog

---@module Dialog  Modal question in the theme's style. FK.Dialog({ title, text, input = "default text" (adds a text box), buttons = { { text, onClick(inputText), primary } } }); shortcuts FK.Confirm(text, onYes, onNo), FK.Prompt(text, default, onAccept(text)), FK.ReloadPrompt(reason). Escape cancels.
function FK.Dialog(opts)
	if not dialog then
		dialog = FK.Window(UIParent, { name = ADDON .. "FKDialog", width = 340, height = 140, strata = "DIALOG" })
		dialog.text = FK.Label(dialog.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, align = "CENTER" })
		dialog.input = FK.EditBox(dialog.content, {})
		dialog.row = FK.Row(dialog.content, { points = { { "BOTTOMLEFT" }, { "BOTTOMRIGHT" } } })
	end
	local d = dialog
	d:SetTitle(opts.title or FK.title)
	d.text:SetText(opts.text or "")
	d.text:Fit()
	d.input:SetShown(opts.input ~= nil)
	d.input:ClearAllPoints()
	d.input:SetPoint("TOP", d.text, "BOTTOM", 0, -8)
	d.input:SetWidth(240)
	d.input:SetValue(opts.input or "")
	d.row:Clear()
	local buttons = opts.buttons or { { text = OKAY or "Okay" } }
	d.row:Batch(function(row)
		for _, b in ipairs(buttons) do
			row:Add(FK.Button(row, { text = b.text, width = 100, onClick = function()
				d.accepted = true
				local text = d.input:GetText()
				d:Hide()
				if b.onClick then b.onClick(text) end
			end }))
		end
	end)
	-- centre the buttons
	local total = #buttons * 100 + (#buttons - 1) * Theme.current.metric.gap
	d.row.opts.padding = 0
	d.row:ClearAllPoints()
	d.row:SetPoint("BOTTOM")
	d.row:SetWidth(total)
	local m = Theme.current.metric
	d:SetHeight(d.text:GetHeight() + (opts.input ~= nil and 34 or 0) + 2 * m.pad + m.title + m.control + 34)
	d.accepted = false
	d.opts.onHide = function() if not d.accepted and opts.onCancel then opts.onCancel() end end
	d:ClearAllPoints()
	d:SetPoint("CENTER", 0, 120)
	d:Show()
	d:Raise()
	if opts.input ~= nil then d.input:Focus() end
	return d
end

function FK.Confirm(text, onYes, onNo)
	return FK.Dialog({ text = text, onCancel = onNo, buttons = { { text = YES or "Yes", onClick = onYes }, { text = NO or "No", onClick = onNo } } })
end

function FK.Prompt(text, default, onAccept)
	return FK.Dialog({ text = text, input = default or "", buttons = { { text = ACCEPT or "Accept", onClick = onAccept }, { text = CANCEL or "Cancel" } } })
end

-- For settings that only apply after reloading the interface.
function FK.ReloadPrompt(reason)
	return FK.Dialog({ text = (reason and (reason .. "\n\n") or "") .. FK.L["Reload the interface now?"],
		buttons = { { text = FK.L["Reload"], onClick = function() C_UI.Reload() end }, { text = FK.L["Later"] } } })
end

---@module Menu  Context menu at the cursor: FK.Menu({ { label = "Delete", onClick = fn }, { divider = true }, { header = "Move to" }, { label = "Bank", onClick = fn, disabled = true } }, anchor). Ticks: { label, checked = bool | fn(item), onClick } (the menu stays open and redraws); radio buttons: add radio = true; submenus: { label, children = items | fn() } open beside the row on hover or click, as deep as needed. items (and children) may be a function, evaluated when the menu opens: it returns the list, or builds it MenuUtil style on the builder it receives: m:Header(text), m:Divider(), m:Item(label, onClick), m:Check(label, checked, onClick), m:Radio(label, checked, onClick), each returning a builder for that entry's submenu. Tests: FK.Popup:Pick("Move to", "Bank") follows the path. Typical trigger: a row's right-click.
function FK.Menu(items, anchor)
	FK.Popup:Open(anchor or UIParent, items, { atCursor = anchor == nil })
end

---------------------------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------------------------

local toasts = {}

local function arrangeToasts()
	local y = -120
	for _, t in ipairs(toasts) do
		t:ClearAllPoints()
		t:SetPoint("TOP", UIParent, "TOP", 0, y)
		y = y - t:GetHeight() - 6
	end
end

---@module Toast  Short notice at the top of the screen that fades by itself: FK.Toast("Goal complete: 20 Linen Cloth", { icon = texture, duration = 4, color = "good" }). For events worth a glance, not for errors that need action.
function FK.Toast(text, opts)
	opts = opts or {}
	local t = FK.Frame("Frame", UIParent)
	t:SetFrameStrata("HIGH")
	local T = Theme.current
	Theme.Paint(t, T.surface.menu)
	t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	Theme.Font(t.text, "normal", opts.color)
	t.text:SetText(text)
	local x = 12
	if opts.icon then
		t.icon = t:CreateTexture(nil, "ARTWORK")
		t.icon:SetSize(20, 20)
		t.icon:SetPoint("LEFT", 8, 0)
		t.icon:SetTexture(opts.icon)
		x = 34
	end
	t.text:SetPoint("LEFT", x, 0)
	t:SetSize(math.min(t.text:GetStringWidth() + x + 14, 500), 32)
	toasts[#toasts + 1] = t
	arrangeToasts()
	FK:After(opts.duration or 4, function()
		for i, other in ipairs(toasts) do
			if other == t then table.remove(toasts, i) break end
		end
		t:Hide()
		arrangeToasts()
	end)
	return t
end

---@module Autocomplete  Suggestions under an FK.EditBox while typing: FK.Autocomplete(editBox, { search = function(text) -> items, onPick = function(item) end, minChars = 2 }). Enter or a click picks; the first suggestion is picked by Enter.
function FK.Autocomplete(edit, opts)
	local results = {}
	local function close() if FK.Popup:IsOpenFor(edit.holder) then FK.Popup:Close() end end
	local function pick(item)
		close()
		edit:SetValue(item.label)
		opts.onPick(item)
	end
	local search = FK:Debounce(opts.delay or 0.15, function(text)
		if #text < (opts.minChars or 2) or not edit.box:HasFocus() then return close() end
		results = FK.ResolveItems(opts.search(text))
		if #results == 0 then return close() end
		FK.Popup:Open(edit.holder, results, { onPick = pick, maxRows = opts.maxRows or 8 })
	end)
	edit.opts.onInput = function(text) search(text) end
	edit.opts.onEnter = function()
		if FK.Popup:IsOpenFor(edit.holder) and results[1] then pick(results[1]) end
	end
	return edit
end
