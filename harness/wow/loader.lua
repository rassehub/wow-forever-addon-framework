-- Loads addons the way the client does (TOC -> files with (name, namespace) -> SavedVariables
-- -> ADDON_LOADED -> login events) and simulates /reload.

local H = require("wow.state")
local io_open, loadstring_, realType = io.open, loadstring, type

local function read(path)
	local f = io_open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return (s:gsub("^\239\187\191", "")) -- UTF-8 BOM
end
H.ReadFile = read

local function dirname(path) return path:match("^(.*)/[^/]*$") or "." end

local function parseToc(text)
	local meta, files = {}, {}
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
		if key then
			meta[key:gsub("%s+$", "")] = value
		elseif not line:match("^%s*#") and line:match("%S") then
			-- "File.lua [AllowLoadGameType x, y]": honour the condition for this game type
			local file, cond = line:match("^%s*(.-)%s*%[(.-)%]%s*$")
			file = (file or line:match("^%s*(.-)%s*$")):gsub("\\", "/")
			local allowed = true
			if cond then
				local kind, list = cond:match("^(%a+)%s+(.*)$")
				local has = list and (list:lower():find("forever") or list:lower():find("camelot")) ~= nil
				if kind == "AllowLoadGameType" then allowed = has elseif kind == "ExcludeLoadGameType" then allowed = not has end
			end
			if allowed then files[#files + 1] = file end
		end
	end
	return meta, files
end

local loadFile

local function loadXml(path, name, ns)
	local text = read(path) or error("cannot read " .. path, 0)
	local dir = dirname(path)
	text = text:gsub("<!%-%-.-%-%->", "")
	for tag, file in text:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
		if tag == "Script" or tag == "Include" then
			loadFile(dir .. "/" .. file:gsub("\\", "/"), name, ns)
		end
	end
	if text:find("<Frame") or text:find("<Button") then
		H.warnings[#H.warnings + 1] = path .. ": XML frame definitions are not emulated (only <Script> and <Include>)"
	end
end

loadFile = function(path, name, ns)
	if path:lower():match("%.xml$") then return loadXml(path, name, ns) end
	local text = read(path) or error(("%s: file listed in the TOC does not exist: %s"):format(name, path), 0)
	local chunk, err = loadstring_(text, "@" .. path)
	if not chunk then error(err, 0) end
	chunk(name, ns)
end

local function findAddon(name)
	for _, dir in ipairs(H.addonPaths) do
		local path = dir .. "/" .. name
		for _, suffix in ipairs({ "_Forever", "_Camelot", "-Camelot", "" }) do
			if read(path .. "/" .. name .. suffix .. ".toc") then return path, path .. "/" .. name .. suffix .. ".toc" end
		end
	end
end

local function split(list)
	local out = {}
	for item in (list or ""):gmatch("[^,%s]+") do out[#out + 1] = item end
	return out
end

-- The file on disk behind a texture path inside a loaded addon ("Interface\\AddOns\\X\\a\\b.png"),
-- trying the client's extensions when there is none. Returns path, exists; nil for other paths.
function H.AddonFile(texture)
	if type(texture) ~= "string" then return nil end
	local addon, rest = texture:gsub("/", "\\"):match("^[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\]+)\\(.+)$")
	local a = addon and H.addons[addon]
	if not a then return nil end
	local base = a.dir .. "/" .. rest:gsub("\\", "/")
	local candidates = base:match("%.%w+$") and { base } or { base .. ".png", base .. ".tga", base .. ".blp" }
	for _, p in ipairs(candidates) do
		local f = io_open(p, "rb")
		if f then f:close() return p, true end
	end
	return candidates[1], false
end

-- Loads the addon in `dir` (and any dependency found on H.addonPaths). Returns its namespace.
function H.LoadAddon(dir)
	dir = dir:gsub("/+$", "")
	local name = dir:match("([^/]+)$")
	if H.addons[name] then return H.addons[name].ns end
	local parent = dirname(dir)
	local known = false
	for _, p in ipairs(H.addonPaths) do known = known or p == parent end
	if not known then table.insert(H.addonPaths, 1, parent) end
	local path, tocPath = findAddon(name)
	if not tocPath then error(("no TOC found for addon %s in %s"):format(name, dir), 0) end

	local meta, files = parseToc(read(tocPath))
	if not (meta.Interface or ""):find("16001") then
		H.warnings[#H.warnings + 1] = name .. ": ## Interface does not include 16001; the Forever client will flag it out of date"
	end
	for _, dep in ipairs(split(meta.RequiredDeps or meta.Dependencies or meta.RequiredDep)) do
		local depDir = findAddon(dep) or error(("%s requires %s, which is not on the addon path"):format(name, dep), 0)
		H.LoadAddon(depDir)
	end
	for _, dep in ipairs(split(meta.OptionalDeps)) do
		local depDir = H.loadOptionalDeps and findAddon(dep)
		if depDir then H.LoadAddon(depDir) end
	end

	local ns = {}
	local addon = { name = name, dir = path, meta = meta, ns = ns, globals = {},
		saved = split(meta.SavedVariables), savedPerChar = split(meta.SavedVariablesPerCharacter) }
	H.addons[name] = addon
	H.loadOrder[#H.loadOrder + 1] = path
	H.loading = addon
	for _, file in ipairs(files) do loadFile(path .. "/" .. file, name, ns) end
	H.loading = nil

	for _, var in ipairs(addon.saved) do rawset(_G, var, H.saved[var]) end
	for _, var in ipairs(addon.savedPerChar) do rawset(_G, var, H.saved[var]) end
	H.Fire("ADDON_LOADED", name)
	return ns
end

function H.Login()
	H.loggedIn = true
	H.Fire("PLAYER_LOGIN")
	H.Fire("PLAYER_ENTERING_WORLD", true, false)
	-- the default UI's own handler: CloseAllWindows() hides every UISpecialFrames window (seen in game)
	for _, name in ipairs(UISpecialFrames) do
		local f = _G[name]
		if f and f:IsShown() then f:Hide() end
	end
	H.Advance(0)
end

-- Load one addon and log in: the usual first line of a test. Returns the addon namespace.
function H.Start(dir)
	local ns = H.LoadAddon(dir)
	H.Login()
	return ns
end

-- What the client would write to the SavedVariables file. Unlike the client, which silently
-- drops them, functions/userdata/cycles are errors here: they are always a bug.
local function persist(v, path, seen)
	local t = realType(v)
	if t == "string" or t == "number" or t == "boolean" then return v end
	if t ~= "table" then error(("SavedVariables: %s is a %s, which cannot be saved"):format(path, t), 0) end
	if v[0] and realType(v[0]) == "table" and v[0].serial then error("SavedVariables: " .. path .. " is a frame", 0) end
	if seen[v] then error("SavedVariables: " .. path .. " contains a cycle", 0) end
	seen[v] = true
	local out = {}
	for k, x in pairs(v) do
		if realType(k) ~= "string" and realType(k) ~= "number" then error("SavedVariables: " .. path .. " has a " .. realType(k) .. " key", 0) end
		out[k] = persist(x, path .. "." .. tostring(k), seen)
	end
	seen[v] = nil
	return out
end

function H.CollectSaved()
	local out = {}
	for _, addon in pairs(H.addons) do
		for _, list in ipairs({ addon.saved, addon.savedPerChar }) do
			for _, var in ipairs(list) do
				local v = rawget(_G, var)
				if v ~= nil then out[var] = persist(v, var, {}) end
			end
		end
	end
	return out
end

-- /reload: PLAYER_LOGOUT, save variables, throw the whole Lua state away, load the same
-- addons again. Every frame and namespace a test still holds is stale afterwards.
-- Returns the new namespace of the last loaded addon.
function H.Reload()
	H.Fire("PLAYER_LOGOUT")
	local saved, order = H.CollectSaved(), H.loadOrder
	H.Reset()
	H.saved = saved
	local ns
	for _, dir in ipairs(order) do ns = H.LoadAddon(dir) end
	H.Login()
	return ns
end

return H
