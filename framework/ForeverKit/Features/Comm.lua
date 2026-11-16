local _, ns = ...
local FK = ns.FK

---@module Comm  Addon-to-addon messages. local comm = FK:Comm("MyAddon", function(data, sender, channel) ... end) registers the prefix (max 16 chars); comm:Send(data, channel, target) sends any table/string/number (serialized, split into 250-byte parts, rate-limited to 10 parts per second with bursts of 10). Received data is parsed, never executed; malformed messages are dropped. Your own messages are ignored unless opts.self = true. Trial accounts cannot send.
local PART = 250 -- 255 byte limit minus the 1-byte part marker, with room to spare
local RATE, BURST = 10, 10

local Comm = {}
Comm.__index = Comm

local queue, tokens, last, draining = {}, BURST, nil, false

local function drain()
	local now = GetTime()
	tokens = math.min(BURST, tokens + (now - (last or now)) * RATE)
	last = now
	while queue[1] and tokens >= 1 do
		local m = table.remove(queue, 1)
		tokens = tokens - 1
		C_ChatInfo.SendAddonMessage(m[1], m[2], m[3], m[4])
	end
	draining = queue[1] ~= nil
	if draining then FK:After(1 / RATE, drain) end
end

-- Part markers: "S" single, "F" first, "M" middle, "L" last.
function Comm:Send(data, channel, target)
	channel = channel or FK.Group.Channel()
	if not channel then return false end
	local text = FK.Serialize(data)
	if #text <= PART then
		queue[#queue + 1] = { self.prefix, "S" .. text, channel, target }
	else
		for i = 1, #text, PART do
			local marker = i == 1 and "F" or (i + PART > #text and "L" or "M")
			queue[#queue + 1] = { self.prefix, marker .. text:sub(i, i + PART - 1), channel, target }
		end
	end
	if not draining then drain() end
	return true
end

function FK:Comm(prefix, onMessage, opts)
	if #prefix > 16 then error("FK:Comm: prefix longer than 16 characters", 2) end
	C_ChatInfo.RegisterAddonMessagePrefix(prefix)
	local comm = setmetatable({ prefix = prefix, opts = opts or {}, partial = {} }, Comm)
	FK:On("CHAT_MSG_ADDON", function(p, msg, channel, sender)
		if p ~= prefix then return end
		-- asked here, not at creation: the realm is not known before login
		if sender == FK.Unit.FullName("player") and not comm.opts.self then return end
		local marker, body = msg:sub(1, 1), msg:sub(2)
		local key = sender .. channel
		if marker == "F" then comm.partial[key] = { body } return end
		if marker == "M" or marker == "L" then
			local parts = comm.partial[key]
			if not parts then return end -- missed the first part
			parts[#parts + 1] = body
			if marker == "M" then return end
			comm.partial[key], body = nil, table.concat(parts)
		elseif marker ~= "S" then
			return
		end
		local data = FK.Deserialize(body)
		if data ~= nil then onMessage(data, sender, channel) end
	end)
	return comm
end
