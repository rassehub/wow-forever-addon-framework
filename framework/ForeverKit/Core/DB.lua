local _, ns = ...
local FK = ns.FK

-- Saved settings with defaults, profiles and per-character data in ONE account-wide
-- SavedVariable (declare it in the TOC: ## SavedVariables: MyAddonDB).
--
--   ns.db = FK:NewDB("MyAddonDB", {
--       profile = { scale = 1, range = 40 },   -- switchable profiles
--       global  = { seenIntro = false },       -- account wide
--       char    = { goals = {} },              -- this character only
--   }, { version = 2, migrate = function(sv, from) ... end })
--
--   FK:OnLoad(function() print(ns.db.profile.range) end)   -- tables exist from OnLoad on
--   ns.db:Set("profile.range", 60)   ns.db:Get("profile.range")
--   ns.db:OnChange("profile.range", function(value, path) ... end)   -- nil path: everything
--
-- Values equal to their default are not written to disk, so changing a default in a new
-- version reaches everyone who never touched that setting. A default that is a list
-- ({ "a", "b" }) is treated as one value.

local DB = {}
local SCOPES = { profile = true, global = true, char = true }

local function isList(t) return t[1] ~= nil end

local function fill(dst, defaults)
	for k, v in pairs(defaults or {}) do
		if type(v) == "table" and not isList(v) then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = FK.Copy(v)
		end
	end
	return dst
end

local function strip(t, defaults)
	for k, v in pairs(defaults or {}) do
		if type(v) == "table" and not isList(v) and type(t[k]) == "table" then
			strip(t[k], v)
			if next(t[k]) == nil then t[k] = nil end
		elseif FK.Equal(t[k], v) then
			t[k] = nil
		end
	end
end

function FK:NewDB(svName, defaults, opts)
	if type(svName) ~= "string" then error("FK:NewDB(savedVariableName, defaults, opts)", 2) end
	local db = setmetatable({ svName = svName, defaults = defaults or {}, opts = opts or {}, listeners = {} }, {
		__index = function(_, k)
			if DB[k] ~= nil then return DB[k] end
			if SCOPES[k] then
				error(("%s.%s is not available yet: saved variables load after the addon's files. Read it inside FK:OnLoad(function() ... end)."):format(svName, k), 2)
			end
		end,
	})
	if self.loaded then db:Load() else self:Once("fk.load", function() db:Load() end) end
	self:On("PLAYER_LOGOUT", function() db:Strip() end)
	return db
end

function DB:Load()
	local sv = _G[self.svName]
	if type(sv) ~= "table" then
		sv = {}
		_G[self.svName] = sv
	end
	rawset(self, "sv", sv)
	local version = self.opts.version
	if version and sv.version and sv.version < version and self.opts.migrate then
		self.opts.migrate(sv, sv.version)
	end
	sv.version = version
	sv.profiles, sv.profileKeys, sv.chars, sv.global = sv.profiles or {}, sv.profileKeys or {}, sv.chars or {}, sv.global or {}
	local key = UnitName("player") .. " - " .. GetRealmName()
	rawset(self, "charKey", key)
	sv.chars[key] = sv.chars[key] or {}
	rawset(self, "global", fill(sv.global, self.defaults.global))
	rawset(self, "char", fill(sv.chars[key], self.defaults.char))
	self:SetProfile(sv.profileKeys[key] or self.opts.defaultProfile or "Default")
end

-- Before the client writes the file: drop values that equal their defaults.
function DB:Strip()
	local sv = self.sv
	if not sv then return end
	for _, profile in pairs(sv.profiles) do strip(profile, self.defaults.profile) end
	for _, char in pairs(sv.chars) do strip(char, self.defaults.char) end
	strip(sv.global, self.defaults.global)
end

function DB:Get(path)
	local scope = path:match("^[^%.]+")
	if not SCOPES[scope] then error(("db:Get(%q): the path must start with profile., global. or char."):format(path), 2) end
	return FK.GetPath(self, path)
end

function DB:Notify(path, value)
	for _, l in ipairs({ unpack(self.listeners) }) do
		-- a listener on "profile.window" hears "profile.window.scale" and "profile" resets
		if not l.path or l.path == path or path:sub(1, #l.path + 1) == l.path .. "." or l.path:sub(1, #path + 1) == path .. "." then
			l.fn(value, path)
		end
	end
end

function DB:Set(path, value)
	local scope = path:match("^[^%.]+")
	if not SCOPES[scope] or scope == path then error(("db:Set(%q): the path must be profile.<key>, global.<key> or char.<key>"):format(path), 2) end
	if FK.Equal(FK.GetPath(self, path), value) then return end
	FK.SetPath(self, path, value)
	self:Notify(path, value)
end

function DB:OnChange(path, fn)
	if type(path) == "function" then path, fn = nil, path end
	local l = { path = path, fn = fn }
	self.listeners[#self.listeners + 1] = l
	return l
end

-- Puts a setting, a group of settings or a whole scope back to its defaults.
function DB:Reset(path)
	local default = FK.GetPath(self.defaults, path)
	if type(default) == "table" and not isList(default) then
		local t = FK.GetPath(self, path)
		wipe(t)
		fill(t, default)
		self:Notify(path, t)
	else
		self:Set(path, FK.Copy(default))
	end
end

function DB:GetProfile() return self.sv.profileKeys[self.charKey] or self.opts.defaultProfile or "Default" end

function DB:Profiles()
	local names = {}
	for name in pairs(self.sv.profiles) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function DB:SetProfile(name)
	if type(name) ~= "string" or name == "" then error("db:SetProfile(name)", 2) end
	local sv = self.sv
	sv.profiles[name] = fill(sv.profiles[name] or {}, self.defaults.profile)
	sv.profileKeys[self.charKey] = name
	rawset(self, "profile", sv.profiles[name])
	self:Notify("profile", self.profile)
end

-- Overwrites the current profile with a copy of another one.
function DB:CopyProfile(from)
	local src = self.sv.profiles[from] or error("db:CopyProfile: no profile named " .. tostring(from), 2)
	wipe(self.profile)
	fill(self.profile, FK.Copy(src))
	fill(self.profile, self.defaults.profile)
	self:Notify("profile", self.profile)
end

function DB:DeleteProfile(name)
	if name == self:GetProfile() then error("db:DeleteProfile: cannot delete the active profile", 2) end
	self.sv.profiles[name] = nil
	for key, profile in pairs(self.sv.profileKeys) do
		if profile == name then self.sv.profileKeys[key] = nil end
	end
end
