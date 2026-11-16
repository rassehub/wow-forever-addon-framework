local _, ns = ...
local FK = ns.FK

---@module Minimap  FK.MinimapButton({ icon, title, tooltip = text | {lines} | function(tooltip), onClick(button, mouseButton), saved = { db, "profile.minimap" } }) -> round button on the minimap edge; drag to move it around the edge; saved stores { angle, hide }. button:SetHidden(bool). FK.Compartment({ text, icon, onClick(mouseButton), tooltip }) adds the addon to the minimap's addon compartment list (also possible through the TOC's ## AddonCompartmentFunc).
local RADIUS_PAD = 10

local function place(btn)
	local a = math.rad(btn.angle)
	local r = Minimap:GetWidth() / 2 + RADIUS_PAD
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function save(btn)
	local s = btn.opts.saved
	if s then s[1]:Set(s[2], { angle = btn.angle, hide = not btn:IsShown() }) end
end

function FK.MinimapButton(opts)
	local saved = opts.saved and opts.saved[1]:Get(opts.saved[2]) or {}
	local btn = CreateFrame("Button", nil, Minimap)
	btn.opts, btn.angle = opts, saved.angle or 225
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	btn.icon = btn:CreateTexture(nil, "BACKGROUND")
	btn.icon:SetSize(20, 20)
	btn.icon:SetPoint("CENTER")
	btn.icon:SetTexture(opts.icon or 134400)
	btn.border = btn:CreateTexture(nil, "OVERLAY")
	btn.border:SetSize(53, 53)
	btn.border:SetPoint("TOPLEFT")
	btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	btn:RegisterForClicks("AnyUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnClick", function(self, mouseButton) if opts.onClick then opts.onClick(self, mouseButton) end end)
	btn:SetScript("OnEnter", function(self)
		FK.Tooltip.Show(self, opts.tooltip or opts.title or "", "ANCHOR_LEFT")
	end)
	btn:SetScript("OnLeave", FK.Tooltip.Hide)
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			self.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			place(self)
		end)
	end)
	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		save(self)
	end)
	function btn:SetHidden(hide)
		self:SetShown(not hide)
		save(self)
	end
	place(btn)
	btn:SetShown(not saved.hide)
	return btn
end

function FK.Compartment(opts)
	if not AddonCompartmentFrame then return end -- the client has no compartment
	AddonCompartmentFrame:RegisterAddon({
		text = opts.text, icon = opts.icon, notCheckable = true,
		func = function(_, input) if opts.onClick then opts.onClick(input and input.buttonName or "LeftButton") end end,
		funcOnEnter = opts.tooltip and function(button) FK.Tooltip.Show(button, opts.tooltip, "ANCHOR_LEFT") end,
		funcOnLeave = opts.tooltip and FK.Tooltip.Hide,
	})
end
