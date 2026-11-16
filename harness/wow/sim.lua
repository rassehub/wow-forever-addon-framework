-- Input simulation: what a player does with mouse and keyboard, with the same consequences as
-- in the client (hover scripts, focus, blocked clicks, dragging, Escape closing windows).

local H = require("wow.state")

local function order(f)
	return H.STRATA[f:GetFrameStrata()] * 1e9 + f:GetFrameLevel() * 1e5 + (f[0].raised or f[0].serial) / 1e3
end
H.order = order

-- Is (x, y) inside the frame and inside every clipping ancestor?
local function contains(f, x, y)
	local l, b, w, h = H.resolve(f)
	if not l then return false end
	local ins = f[0].hitInsets
	if ins then l, b, w, h = l + ins[1], b + ins[4], w - ins[1] - ins[2], h - ins[3] - ins[4] end
	if x < l or x > l + w or y < b or y > b + h then return false end
	local p = f[0].parent
	while p do
		if p[0].clips or p:IsObjectType("ScrollFrame") then
			local pl, pb, pw, ph = H.resolve(p)
			if not pl or x < pl or x > pl + pw or y < pb or y > pb + ph then return false end
		end
		p = p[0].parent
	end
	return true
end

-- Topmost visible frame at the point that satisfies `wants(frame)` (default: mouse enabled).
function H.HitTest(x, y, wants)
	local best, bestOrder
	for _, f in ipairs(H.frames) do
		local ok
		if wants then ok = wants(f) else ok = f[0].mouse end
		if ok and f:IsVisible() and contains(f, x, y) then
			local o = order(f)
			if not best or o >= bestOrder then best, bestOrder = f, o end
		end
	end
	return best
end

local function center(f)
	local l, b, w, h = H.resolve(f)
	if not l then error(H.debugname(f) .. " has no position (not anchored, or anchored to something unanchored)", 3) end
	return l + w / 2, b + h / 2
end

local function moveMouse(x, y)
	H.mouseX, H.mouseY = x, y
	local over = H.HitTest(x, y, function(f) return f[0].mouse or f[0].mouseMotion end)
	if over ~= H.hover then
		local old = H.hover
		H.hover = over
		if old and (old[0].disabled ~= true or old[0].motionWhileDisabled) then H.run(old, "OnLeave", true) end
		if over and (over[0].disabled ~= true or over[0].motionWhileDisabled) then H.run(over, "OnEnter", true) end
	end
end

local function target(f, action)
	if type(f) ~= "table" or not f[0] then error(action .. ": not a frame", 3) end
	if not f:IsVisible() then error(action .. ": " .. H.debugname(f) .. " is not visible", 3) end
	local x, y = center(f)
	moveMouse(x, y)
	local top = H.HitTest(x, y)
	if top ~= f then
		error(("%s: %s is %s"):format(action, H.debugname(f),
			top and ("covered by " .. H.debugname(top)) or "not mouse enabled"), 3)
	end
	return x, y
end

function H.Hover(f)
	if not f then return moveMouse(-1, -1) end
	target(f, "Hover")
end

function H.Click(f, button)
	button = button or "LeftButton"
	target(f, "Click")
	H.run(f, "OnMouseDown", button)
	if f:IsObjectType("EditBox") then f:SetFocus() end
	if f:IsObjectType("Button") and f:IsEnabled() then
		local clicks = f[0].clicks
		local accepted = not clicks and button == "LeftButton"
		for _, c in ipairs(clicks or {}) do
			if c:find("^Any") or c:find("^" .. button) then accepted = true end
		end
		if accepted then f:Click(button, false) end
	end
	H.run(f, "OnMouseUp", button)
	H.Advance(0)
end

function H.DoubleClick(f)
	H.Click(f)
	target(f, "DoubleClick")
	H.run(f, "OnDoubleClick", "LeftButton")
end

-- Press on the frame, move the mouse by (dx, dy) screen units, release.
function H.Drag(f, dx, dy, button)
	button = button or "LeftButton"
	local x, y = target(f, "Drag")
	H.run(f, "OnMouseDown", button)
	local drags = false
	for _, b in ipairs(f[0].drag or {}) do drags = drags or b == button end
	if drags then H.run(f, "OnDragStart", button) end
	local moving, l, b, w, h = H.moving
	if moving then l, b, w, h = H.resolve(moving.frame) end
	H.mouseX, H.mouseY = x + dx, y + dy
	if moving then
		local m, s = moving.frame, moving.frame[0]
		local es = m:GetEffectiveScale()
		if moving.mode == "move" then
			l, b = l + dx, b + dy
			if s.clamped then
				l = math.max(0, math.min(l, H.screenWidth - w))
				b = math.max(0, math.min(b, H.screenHeight - h))
			end
		else
			local p = moving.point
			local nw = w + (p:find("RIGHT") and dx or p:find("LEFT") and -dx or 0)
			local nh = h + (p:find("BOTTOM") and -dy or p:find("TOP") and dy or 0)
			local bounds = s.bounds or { 0, 0, 0, 0 }
			nw = math.max(nw, (bounds[1] or 0) * es)
			nh = math.max(nh, (bounds[2] or 0) * es)
			if (bounds[3] or 0) > 0 then nw = math.min(nw, bounds[3] * es) end
			if (bounds[4] or 0) > 0 then nh = math.min(nh, bounds[4] * es) end
			if p:find("LEFT") then l = l + w - nw end
			if not p:find("TOP") then b = b + h - nh end
			w, h = nw, nh
			m:SetSize(w / es, h / es)
		end
		-- as the client does after a user move: one anchor, relative to the screen (relativeTo nil)
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", nil, "TOPLEFT", l / es, (b + h - H.screenHeight) / es)
		s.userPlaced = true
	end
	H.Advance(0) -- one frame, so OnUpdate-driven drags see the new cursor position
	H.run(f, "OnMouseUp", button)
	if drags then H.run(f, "OnDragStop") end
	H.Advance(0)
end

-- The value a player drags the slider to: clamped, snapped when ObeyStepOnDrag, userInput = true.
function H.Slide(slider, value)
	target(slider, "Slide")
	if not slider:IsEnabled() then return end
	H.run(slider, "OnMouseDown", "LeftButton")
	slider:SetValue(value, true)
	H.run(slider, "OnMouseUp", "LeftButton")
	H.Advance(0)
end

function H.Wheel(f, delta)
	local x, y = center(f)
	moveMouse(x, y)
	local top = H.HitTest(x, y, function(o) return o[0].wheel end)
	if not top then error("Wheel: nothing under " .. H.debugname(f) .. " accepts the mouse wheel", 2) end
	H.run(top, "OnMouseWheel", delta)
	H.Advance(0)
	return top
end

-- Types into the focused edit box (click it first).
function H.Type(text)
	local box = H.focus
	if not box then error("Type: no edit box has focus", 2) end
	local s = box[0]
	for ch in text:gmatch(".") do
		if not s.numeric or ch:match("%d") then
			if not (s.maxLetters and s.maxLetters > 0 and #s.text >= s.maxLetters) then
				s.text = s.text .. ch
				s.cursor = #s.text
				H.run(box, "OnChar", ch)
				H.run(box, "OnTextChanged", true)
			end
		end
	end
	H.gen = H.gen + 1
	H.Advance(0)
end

-- Replaces the content of the focused edit box, as select-all + typing.
function H.Enter(box, text)
	H.Click(box)
	box[0].text = ""
	H.Type(text)
end

function H.Key(key)
	local box = H.focus
	if box then
		if key == "ENTER" then H.run(box, "OnEnterPressed")
		elseif key == "ESCAPE" then H.run(box, "OnEscapePressed")
		elseif key == "TAB" then H.run(box, "OnTabPressed")
		elseif key == "SPACE" then H.run(box, "OnSpacePressed")
		elseif key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then H.run(box, "OnArrowPressed", key)
		elseif key == "BACKSPACE" then
			box[0].text = box[0].text:sub(1, -2)
			H.run(box, "OnTextChanged", true)
		else H.run(box, "OnKeyDown", key) end
	else
		local handled = false
		for _, f in ipairs(H.frames) do
			if f[0].keyboard and f:IsVisible() and f[0].scripts.OnKeyDown then
				f[0].scripts.OnKeyDown(f, key)
				handled = handled or not f[0].propagateKeys
			end
		end
		if key == "ESCAPE" and not handled then
			-- CloseSpecialWindows: Escape hides the frames listed in UISpecialFrames
			for _, name in ipairs(UISpecialFrames) do
				local f = _G[name]
				if f and f:IsShown() then f:Hide() end
			end
		end
	end
	H.Advance(0)
end

function H.Fire(event, ...)
	local frames = {}
	for f in pairs(H.events[event] or {}) do frames[#frames + 1] = f end
	table.sort(frames, function(a, b) return a[0].serial < b[0].serial end)
	for _, f in ipairs(frames) do
		if H.events[event][f] then H.run(f, "OnEvent", event, ...) end
	end
	if H.eventHooks then
		for _, hook in ipairs(H.eventHooks) do hook(event, ...) end
	end
end

function H.SetCombat(inCombat)
	if H.inCombat == inCombat then return end
	H.inCombat = inCombat
	H.Fire(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

return H
