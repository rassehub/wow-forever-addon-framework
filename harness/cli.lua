-- Used by `fk tree` and `fk preview`:
--   lua harness/cli.lua (tree|html) ADDON_DIR [--do LUA] [--theme NAME] [--out FILE] [--full]
--       [--addons-path DIR]... [--textures]
-- Loads the addon, logs in, runs the --do snippet (it sees H and ns), then prints the frame
-- tree with layout issues, or writes the HTML render.

local open, exit, stderr = io.open, os.exit, io.stderr
local realPrint = print
local H = require("wow")

local mode, dir = arg[1], arg[2]
local opts, i = { snippets = {} }, 3
while arg[i] do
	local a = arg[i]
	if a == "--do" then i = i + 1; opts.snippets[#opts.snippets + 1] = arg[i]
	elseif a == "--theme" then i = i + 1; opts.theme = arg[i]
	elseif a == "--out" then i = i + 1; opts.out = arg[i]
	elseif a == "--addons-path" then i = i + 1; table.insert(H.addonPaths, arg[i])
	elseif a == "--full" then opts.full = true
	elseif a == "--textures" then opts.textures = true
	else stderr:write("unknown argument " .. a .. "\n") exit(2) end
	i = i + 1
end

local ns = H.Start(dir)
if opts.theme then
	if not (ns.FK and ns.FK.Theme) then stderr:write("--theme: this addon does not embed ForeverKit\n") exit(2) end
	ns.FK.Theme:Set(opts.theme)
end
for _, code in ipairs(opts.snippets) do
	local chunk, err = loadstring(code, "=--do")
	if not chunk then stderr:write(err .. "\n") exit(2) end
	setfenv(chunk, setmetatable({ H = H, ns = ns, FK = ns.FK }, { __index = _G }))
	chunk()
end
H.Advance(0.1)

-- the frame to focus on: the largest visible top-level window
local function mainWindow()
	local best, area
	for _, f in ipairs(H.frames) do
		if f[0].parent == UIParent and f:IsVisible() and f ~= Minimap and f[0].type ~= "GameTooltip" then
			local _, _, w, h = H.resolve(f)
			if w and w * h > (area or 0) and w * h < H.screenWidth * H.screenHeight then best, area = f, w * h end
		end
	end
	return best
end

if mode == "tree" then
	realPrint(H.Tree(nil, { textures = opts.textures }))
	local issues = H.LayoutIssues()
	realPrint(("\n-- %d layout issue(s)"):format(#issues))
	for _, issue in ipairs(issues) do realPrint("   " .. issue) end
	for _, w in ipairs(H.warnings) do realPrint("-- warning: " .. w) end
	if ns.FK then
		for _, w in ipairs(ns.FK.warnings) do realPrint("-- design warning: " .. w) end
	end
	exit(#issues == 0 and 0 or 1)
elseif mode == "html" then
	local html = H.Render({ crop = not opts.full and mainWindow() or nil, title = dir })
	local f = assert(open(opts.out, "w"))
	f:write(html)
	f:close()
else
	stderr:write("usage: cli.lua (tree|html) ADDON_DIR ...\n")
	exit(2)
end
