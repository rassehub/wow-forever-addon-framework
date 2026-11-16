-- Prints a SavedVariables file as JSON: { "VarName": value, ... }. The file is run with an
-- empty environment and no functions available, so it can only build tables.
--   lua harness/sv2json.lua FILE
local f = assert(io.open(arg[1], "rb"))
local text = f:read("*a")
f:close()
local chunk = assert(loadstring(text, "=" .. arg[1]))
local env = {}
setfenv(chunk, env)
assert(pcall(chunk))

local function json(v)
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or ("\\u%04x"):format(c:byte())
		end) .. '"'
	end
	if t == "number" then return (v ~= v or v == math.huge or v == -math.huge) and "null" or tostring(v) end
	if t == "boolean" then return tostring(v) end
	if t ~= "table" then return "null" end
	local n = 0
	for _ in pairs(v) do n = n + 1 end
	local parts = {}
	if n == #v then
		for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	for k, x in pairs(v) do parts[#parts + 1] = json(tostring(k)) .. ":" .. json(x) end
	return "{" .. table.concat(parts, ",") .. "}"
end
io.write(json(env), "\n")
