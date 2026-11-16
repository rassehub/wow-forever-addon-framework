local _, ns = ...
local FK = ns.FK

function FK.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Rounds to the nearest multiple of step (default 1), without float noise like 0.30000000004.
function FK.Round(v, step)
	step = step or 1
	local r = math.floor(v / step + 0.5) * step
	local decimals = tostring(step):match("%.(%d+)$")
	return decimals and tonumber(("%." .. #decimals .. "f"):format(r)) or r
end

function FK.Copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = FK.Copy(x) end
	return out
end

function FK.Equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not FK.Equal(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

-- Reads "a.b.c" from a table; nil when any step is missing.
function FK.GetPath(t, path)
	for key in path:gmatch("[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[tonumber(key) or key]
	end
	return t
end

function FK.SetPath(t, path, value)
	local keys = {}
	for key in path:gmatch("[^%.]+") do keys[#keys + 1] = tonumber(key) or key end
	for i = 1, #keys - 1 do
		if type(t[keys[i]]) ~= "table" then t[keys[i]] = {} end
		t = t[keys[i]]
	end
	t[keys[#keys]] = value
end

function FK.Hex(r, g, b)
	if type(r) == "table" then r, g, b = r[1] or r.r, r[2] or r.g, r[3] or r.b end
	return ("ff%02x%02x%02x"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
end

function FK.Colorize(text, r, g, b)
	return "|c" .. FK.Hex(r, g, b) .. tostring(text) .. "|r"
end

-- 123456 -> "12g 34s 56c" with coloured unit letters; zero leading units are dropped.
function FK.Money(copper, plain)
	copper = math.floor(copper + 0.5)
	local sign = copper < 0 and "-" or ""
	copper = math.abs(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	local function add(n, unit, color)
		parts[#parts + 1] = plain and (n .. unit) or (n .. "|cff" .. color .. unit .. "|r")
	end
	if g > 0 then add(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, "g", "ffd100") end
	if s > 0 or (g > 0 and c > 0) then add(s, "s", "c7c7cf") end
	if c > 0 or #parts == 0 then add(c, "c", "eda55f") end
	return sign .. table.concat(parts, " ")
end

-- 1234 -> "1,234"; with short = true 1234 -> "1.2k", 3400000 -> "3.4m"
function FK.Number(n, short)
	if short then
		if math.abs(n) >= 1e6 then return ("%.1fm"):format(n / 1e6) end
		if math.abs(n) >= 1e3 then return ("%.1fk"):format(n / 1e3) end
		return tostring(math.floor(n + 0.5))
	end
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (n < 0 and "-" or "") .. out
end

-- 95 -> "1m 35s", 3700 -> "1h 1m", 4 -> "4s"
function FK.Duration(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 86400 then return ("%dd %dh"):format(seconds / 86400, seconds % 86400 / 3600) end
	if seconds >= 3600 then return ("%dh %dm"):format(seconds / 3600, seconds % 3600 / 60) end
	if seconds >= 60 then return ("%dm %ds"):format(seconds / 60, seconds % 60) end
	return seconds .. "s"
end

function FK:Print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	print("|cff" .. (self.chatColor or "ffd100") .. self.title .. "|r: " .. table.concat(parts, " "))
end

-- One physical screen pixel expressed in UI units, for crisp 1px borders at any UI scale.
function FK.Pixel(n)
	local _, physicalHeight = GetPhysicalScreenSize()
	return (n or 1) * 768 / physicalHeight / UIParent:GetEffectiveScale()
end

-- Reuses objects instead of creating new ones: local pool = FK.Pool(create, reset);
-- pool:Get() -> object, pool:Release(object), pool:ReleaseAll().
function FK.Pool(create, reset)
	local pool = { free = {}, used = {}, count = 0 }
	function pool:Get()
		local o = table.remove(self.free)
		if not o then
			self.count = self.count + 1
			o = create(self.count)
		end
		self.used[o] = true
		return o
	end
	function pool:Release(o)
		if not self.used[o] then return end
		self.used[o] = nil
		if reset then reset(o) end
		self.free[#self.free + 1] = o
	end
	function pool:ReleaseAll()
		for o in pairs(self.used) do
			if reset then reset(o) end
			self.free[#self.free + 1] = o
		end
		self.used = {}
	end
	return pool
end
