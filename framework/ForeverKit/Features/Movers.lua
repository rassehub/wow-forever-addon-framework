local _, ns = ...
local FK = ns.FK

---@module Movers  Unlock mode for HUD frames. FK.Movers.Add(frame, { label, saved = { db, "profile.pos.bar" } }) restores the saved position now; FK.Movers.Unlock() covers every registered frame with a labelled handle that drags it, FK.Movers.Lock() saves and hides the handles, FK.Movers.Toggle(), FK.Movers.IsUnlocked(). Not in combat (frames may be protected).
local Movers = { list = {} }
FK.Movers = Movers
local unlocked = false

local function save(m)
	local s = m.opts.saved
	if not s then return end
	local point, _, relPoint, x, y = m.frame:GetPoint(1)
	s[1]:Set(s[2], { point = point, relPoint = relPoint, x = x, y = y })
end

local function restore(m)
	local s = m.opts.saved
	local p = s and s[1]:Get(s[2])
	if not (p and p.point) then return end
	m.frame:ClearAllPoints()
	m.frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
end

function Movers.Add(frame, opts)
	opts = opts or {}
	local m = { frame = frame, opts = opts }
	local handle = FK.Frame("Button", frame)
	handle:SetAllPoints()
	handle:SetFrameStrata("DIALOG")
	FK.Theme.Paint(handle, { bg = { FK.Theme.Color("accent") }, border = { 0, 0, 0, 1 } })
	handle:SetAlpha(0.6)
	local label = handle:CreateFontString(nil, "OVERLAY")
	FK.Theme.Font(label, "small")
	label:SetPoint("CENTER")
	label:SetText(opts.label or "")
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function() frame:SetMovable(true) frame:StartMoving() end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		save(m)
	end)
	handle:SetShown(unlocked)
	m.handle = handle
	Movers.list[#Movers.list + 1] = m
	if opts.saved then
		restore(m)
		opts.saved[1]:OnChange("profile", function() restore(m) end)
	end
	return m
end

function Movers.IsUnlocked() return unlocked end

local function set(state, force)
	if InCombatLockdown() and not force then FK:Print(FK.L["Cannot move frames in combat."]) return end
	unlocked = state
	for _, m in ipairs(Movers.list) do
		if not state then save(m) end
		m.handle:SetShown(state)
	end
	FK:Emit("fk.movers", state)
end

function Movers.Unlock() set(true) end
function Movers.Lock() set(false) end
function Movers.Toggle() set(not unlocked) end

FK:On("PLAYER_REGEN_DISABLED", function() if unlocked then set(false, true) end end) -- fires as lockdown begins
