-- Test runner: lua harness/run.lua [--verbose] [--addons-path DIR]... TESTFILE
-- A test file sees the emulator as `H` plus: test(name, fn), eq, near, ok, raises.
-- The client is reset before every test, so each test starts with H.Start(...) or bare frames.

local traceback, exit, getenv, print = debug.traceback, os.exit, os.getenv, print
local H = require("wow")
local root = getenv("FK_ROOT") or "."

local files = {}
local i = 1
while arg[i] do
	if arg[i] == "--verbose" then H.verbose = true
	elseif arg[i] == "--addons-path" then i = i + 1; table.insert(H.addonPaths, arg[i])
	else files[#files + 1] = arg[i] end
	i = i + 1
end

local function show(v)
	if type(v) == "string" then return ("%q"):format(v) end
	if type(v) == "table" and not v[0] then
		local parts = {}
		for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. show(x) end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or a[0] or b[0] then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

local env = {
	H = H,
	ROOT = root,
	eq = function(got, want, msg)
		if not same(got, want) then error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", show(want), show(got)), 2) end
	end,
	near = function(got, want, tolerance, msg)
		if type(got) ~= "number" or math.abs(got - want) > (tolerance or 0.01) then
			error(("%sexpected about %s, got %s"):format(msg and (msg .. ": ") or "", show(want), show(got)), 2)
		end
	end,
	ok = function(v, msg) if not v then error(msg or "expected a true value", 2) end end,
	raises = function(fn, pattern)
		local good, err = pcall(fn)
		if good then error("expected an error" .. (pattern and (" matching " .. pattern) or ""), 2) end
		if pattern and not tostring(err):find(pattern) then error(("expected an error matching %q, got: %s"):format(pattern, tostring(err)), 2) end
		return err
	end,
}

local tests = {}
env.test = function(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local failed, passed = 0, 0
for _, file in ipairs(files) do
	tests = {}
	local chunk, err = loadstring(H.ReadFile(file) or error("cannot read " .. file, 0), "@" .. file)
	if not chunk then
		print("FAIL " .. file .. "\n  " .. err)
		failed = failed + 1
	else
		setfenv(chunk, setmetatable(env, { __index = _G }))
		local good, loadErr = xpcall(chunk, traceback)
		if not good then
			print("FAIL " .. file .. " (while loading)\n  " .. loadErr:gsub("\n", "\n  "))
			failed = failed + 1
		end
		for _, t in ipairs(tests) do
			H.Reset()
			setfenv(t.fn, setmetatable(env, { __index = _G }))
			local good2, testErr = xpcall(t.fn, traceback)
			if good2 then
				passed = passed + 1
				if H.verbose then print("ok   " .. t.name) end
			else
				failed = failed + 1
				-- keep the message and the frames inside test/addon code, drop harness internals
				local lines = {}
				for line in testErr:gmatch("[^\n]+") do
					if not line:find("harness/run.lua") and not line:find("%[C%]: in function 'xpcall'") then lines[#lines + 1] = line end
				end
				print("FAIL " .. file .. ": " .. t.name .. "\n  " .. table.concat(lines, "\n  "))
			end
		end
	end
end

print(("%d passed, %d failed"):format(passed, failed))
exit(failed == 0 and 0 or 1)
