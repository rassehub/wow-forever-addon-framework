-- FKDev: the in-game half of the live test loop (docs/research/04-testing.md).
-- In: Queue.lua (written by `fk live run`, read at load). Out: FKDevDB (SavedVariables, written
-- by the client on /reload or logout, read by `fk live results`).
--
-- Addons register in-game tests with `## OptionalDeps: FKDev` and:
--     if FKDev then FKDev.Test("MyAddon", "window opens", function(assert) ... end) end
-- assert(cond, message) fails the test; an error fails it too.
-- This is a development tool, so it uses globals (FKDev, FKDEV_QUEUE) on purpose.

local ADDON = ...
local MAX_ERRORS = 200

FKDev = { tests = {} }
local session -- the record of this UI session in FKDevDB

local function now() return date("%Y-%m-%d %H:%M:%S") end

local function record(kind, message, stack)
	if not session then return end
	local list = session.errors
	for _, e in ipairs(list) do
		if e.message == message then e.count = e.count + 1 return end
	end
	if #list < MAX_ERRORS then
		list[#list + 1] = { kind = kind, message = tostring(message), stack = stack, count = 1, time = now() }
	end
end

-- Errors: keep the previous handler (BugSack, the default popup) working.
local previous = geterrorhandler()
seterrorhandler(function(message, ...)
	record("error", message, debugstack(3, 12, 0))
	if previous then return previous(message, ...) end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "LUA_WARNING", "ADDON_LOADED", "PLAYER_LOGIN" }) do
	if not C_EventUtils or C_EventUtils.IsEventValid(e) then events:RegisterEvent(e) end
end

function FKDev.Test(addon, name, fn)
	FKDev.tests[#FKDev.tests + 1] = { addon = addon, name = name, fn = fn }
end

-- Frame tree in the emulator's text format: `Type Name "text" [x,y wxh]`, top-left origin, UI units.
local function rect(r)
	local l, t, w, h = r:GetLeft(), r:GetTop(), r:GetWidth(), r:GetHeight()
	if not (l and t) then return "[no position]" end
	local s = r:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return ("[%d,%d %dx%d]"):format(l * s + 0.5, (UIParent:GetHeight() - t * s) + 0.5, w * s + 0.5, h * s + 0.5)
end
-- withTextures: also list texture regions with their file or atlas (exploring Blizzard frames).
function FKDev.Tree(root, maxDepth, withTextures)
	if type(root) == "string" then root = _G[root] end
	if not root then return { "no such frame" } end
	local out = {}
	local function walk(f, depth)
		if depth > (maxDepth or 12) or not f:IsVisible() then return end
		local text = f.GetText and f:GetText()
		out[#out + 1] = ("%s%s%s%s %s"):format(("  "):rep(depth), f:GetObjectType(), f:GetName() and (" " .. f:GetName()) or "",
			(type(text) == "string" and text ~= "") and (' "' .. text:gsub("\n", "\\n") .. '"') or "", rect(f))
		for _, r in ipairs({ f:GetRegions() }) do
			if r:GetObjectType() == "FontString" and r:IsVisible() and (r:GetText() or "") ~= "" then
				out[#out + 1] = ("%sFontString \"%s\" %s"):format(("  "):rep(depth + 1), r:GetText():gsub("\n", "\\n"), rect(r))
			elseif withTextures and r:GetObjectType() == "Texture" and r:IsShown() then
				local atlas = r.GetAtlas and r:GetAtlas()
				out[#out + 1] = ("%sTexture%s %s %s %s"):format(("  "):rep(depth + 1), r:GetName() and (" " .. r:GetName()) or "",
					atlas and ("atlas=" .. atlas) or ("file=" .. tostring(r:GetTexture())), r:GetDrawLayer() or "", rect(r))
			end
		end
		for _, c in ipairs({ f:GetChildren() }) do walk(c, depth + 1) end
		if withTextures and depth == 0 then
			-- named children of the root that are hidden, too: things a skin may want to show again
			for _, c in ipairs({ f:GetChildren() }) do
				if not c:IsVisible() and c:GetName() then out[#out + 1] = "  (hidden) " .. c:GetObjectType() .. " " .. c:GetName() end
			end
		end
	end
	walk(root, 0)
	return out
end

local function runTests()
	local results = {}
	for _, t in ipairs(FKDev.tests) do
		local failures = {}
		local function assert(cond, message)
			if not cond then failures[#failures + 1] = tostring(message or "assertion failed") end
			return cond
		end
		local ok, err = xpcall(function() t.fn(assert) end, function(e) return tostring(e) .. "\n" .. debugstack(2, 8, 0) end)
		if not ok then failures[#failures + 1] = err end
		results[#results + 1] = { addon = t.addon, name = t.name, ok = #failures == 0, failures = failures }
	end
	return results
end

-- A queue entry: { id, lua = { "code", ... }, tree = "FrameName", treeTextures = true, shot = true }
local function runQueue(q)
	local run = { id = q.id, time = now(), outputs = {} }
	for i, code in ipairs(q.lua or {}) do
		local chunk, err = loadstring(code, "=queue[" .. i .. "]")
		local out = { code = code }
		if not chunk then out.error = err
		else
			local results = { pcall(chunk) }
			if results[1] then
				out.ok = true
				for k = 2, #results do results[k] = tostring(results[k]) end
				out.returns = { select(2, unpack(results)) }
			else
				out.error = tostring(results[2])
			end
		end
		run.outputs[#run.outputs + 1] = out
	end
	if q.tree then run.tree = FKDev.Tree(q.tree, q.treeDepth, q.treeTextures) end
	if q.shot then C_Timer.After(1, function() Screenshot() end) end
	return run
end

local function reloadButton(text)
	local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
	b:SetSize(260, 40)
	b:SetPoint("TOP", 0, -120)
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
	b:SetBackdropBorderColor(1, 0.82, 0, 1)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER")
	fs:SetText(text)
	b:SetScript("OnClick", function() C_UI.Reload() end) -- a click is a hardware event: always allowed
	b:Show()
end

events:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" and a1 == ADDON then
		FKDevDB = FKDevDB or {}
		FKDevDB.sessions = FKDevDB.sessions or {}
		FKDevDB.done = FKDevDB.done or {}
		session = { started = now(), errors = {}, client = { (GetBuildInfo()) }, addons = {} }
		table.insert(FKDevDB.sessions, 1, session)
		while #FKDevDB.sessions > 5 do table.remove(FKDevDB.sessions) end
	elseif event == "ADDON_LOADED" and session then
		session.addons[#session.addons + 1] = a1
	elseif event == "PLAYER_LOGIN" then
		-- give addons their own login handlers first
		C_Timer.After(1, function()
			local queue = FKDEV_QUEUE -- set by Queue.lua; read now, after every addon loaded
			session.tests = runTests()
			local pending = queue and queue.id and not FKDevDB.done[queue.id]
			if pending then
				session.run = runQueue(queue)
				FKDevDB.done[queue.id] = true
			end
			local passed, failed = 0, 0
			for _, r in ipairs(session.tests) do if r.ok then passed = passed + 1 else failed = failed + 1 end end
			print(("|cff33ccffFKDev|r %d test(s) passed, %d failed%s, %d error(s) so far."):format(passed, failed,
				pending and (", queue " .. queue.id .. " ran") or "", #session.errors))
			if pending then reloadButton("FKDev: click to save results (reload)") end
		end)
	elseif event == "LUA_WARNING" then
		record("warning", a2 or a1)
	else
		record(event, ("%s tried to call %s"):format(tostring(a1), tostring(a2)))
	end
end)

SLASH_FKDEVRELOAD1 = "/rl"
SlashCmdList.FKDEVRELOAD = function() C_UI.Reload() end
SLASH_FKDEV1 = "/fkdev"
SlashCmdList.FKDEV = function(msg)
	if msg == "tree" then
		local f = GetMouseFoci and GetMouseFoci()[1] or GetMouseFocus and GetMouseFocus()
		for _, line in ipairs(FKDev.Tree(f and f:GetName() and f or (f and f:GetParent()) or UIParent, 4)) do print(line) end
	else
		print("|cff33ccffFKDev|r /rl reloads; /fkdev tree dumps the frame under the mouse. Results: `fk live results`.")
	end
end
