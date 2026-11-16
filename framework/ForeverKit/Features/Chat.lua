local _, ns = ...
local FK = ns.FK

---@module Chat  FK:Print(...) (prefixed, in Core). FK.Chat.Send(text, channel, target): chat message, split at 255 bytes on word boundaries; SAY/YELL/EMOTE only from a click or key press. FK.Chat.Color(text, themeColourOr{r,g,b}). FK.Chat.ItemLink(id) (nil until cached). FK.Chat.Strip(text) removes colour codes and links.
local Chat = {}
FK.Chat = Chat

function Chat.Color(text, color)
	local c = type(color) == "table" and color or { FK.Theme.Color(color) }
	return FK.Colorize(text, c[1], c[2], c[3])
end

function Chat.ItemLink(id)
	local info = FK.Items.Info(id)
	return info and info.link
end

function Chat.Strip(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- Splits on spaces; a link (|H...|h) is never cut in half because it contains no space in its code part.
function Chat.Split(text, size)
	size = size or 255
	local parts, line = {}, ""
	for word in text:gmatch("%S+") do
		if line ~= "" and #line + 1 + #word > size then parts[#parts + 1], line = line, word
		else line = line == "" and word or (line .. " " .. word) end
		while #line > size do parts[#parts + 1], line = line:sub(1, size), line:sub(size + 1) end
	end
	if line ~= "" then parts[#parts + 1] = line end
	return parts
end

function Chat.Send(text, channel, target)
	local send = C_ChatInfo.SendChatMessage or SendChatMessage
	for _, part in ipairs(Chat.Split(text)) do send(part, channel or "SAY", nil, target) end
end
