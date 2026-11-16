local ADDON, ns = ...
local FK = ns.FK

---@module Slash  FK:Slash({ "/myaddon", "/ma" }, { [""] = fn, config = { "help text", fn(arg) } }) with "help" listing subcommands, or FK:Slash(cmds, fn(msg)) for the raw argument string.

-- FK:Slash({ "/goals", "/gn" }, {
--     [""]   = function() ns.window:Toggle() end,          -- no argument
--     config = { "Open the settings", function() ... end },
--     scale  = { "Set the window scale: /goals scale 1.2", function(arg) ... end },
-- })
-- "help" (and any unknown word) lists the subcommands. A plain function instead of the table
-- receives the whole argument string.
function FK:Slash(commands, handlers)
	if type(commands) == "string" then commands = { commands } end
	local key = ADDON:upper():gsub("[^A-Z0-9]", "") .. (self.slashCount or "")
	self.slashCount = (self.slashCount or 1) + 1
	for i, cmd in ipairs(commands) do
		if cmd:sub(1, 1) ~= "/" then error("FK:Slash: commands start with /", 2) end
		_G["SLASH_" .. key .. i] = cmd
	end
	local function help()
		local names = {}
		for name, h in pairs(handlers) do
			if name ~= "" then names[#names + 1] = name end
		end
		table.sort(names)
		FK:Print("commands:")
		for _, name in ipairs(names) do
			local h = handlers[name]
			print(("  |cffffd100%s %s|r  %s"):format(commands[1], name, type(h) == "table" and h[1] or ""))
		end
	end
	SlashCmdList[key] = function(msg)
		msg = strtrim(msg or "")
		if type(handlers) == "function" then return handlers(msg) end
		local word, rest = msg:match("^(%S*)%s*(.-)$")
		local h = handlers[word:lower()]
		if type(h) == "table" then h = h[2] end
		if h then h(rest) else help() end
	end
end
