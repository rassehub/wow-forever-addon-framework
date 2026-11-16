-- Text dump of the visible UI and automatic layout diagnostics.
-- Coordinates are printed as x,y of the top-left corner measured from the top-left of the
-- screen, then width x height, in screen units.

local H = require("wow.state")

local function box(o)
	local l, b, w, h = H.resolve(o)
	if not l then return nil end
	return l, H.screenHeight - (b + h), w, h
end

local function fmtBox(o)
	local x, y, w, h = box(o)
	if not x then return "[unanchored]" end
	return ("[%d,%d %dx%d]"):format(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5))
end

local function sortedChildren(f)
	local kids = { unpack(f[0].children) }
	table.sort(kids, function(a, b) return H.order(a) < H.order(b) end)
	return kids
end

local function describe(o)
	local s = o[0]
	local parts = { s.type }
	if s.name then parts[#parts + 1] = s.name end
	if s.type == "FontString" then
		parts[#parts + 1] = ("%q"):format(H.plain(s.text or ""))
	elseif s.type == "EditBox" then
		parts[#parts + 1] = ("text=%q"):format(s.text or "")
	elseif s.type == "Texture" then
		if s.color then parts[#parts + 1] = ("rgba(%.2f,%.2f,%.2f,%.2f)"):format(unpack(s.color))
		elseif s.atlas then parts[#parts + 1] = "atlas:" .. s.atlas
		elseif s.texture then parts[#parts + 1] = tostring(s.texture):gsub("^[Ii]nterface\\", "") end
	end
	parts[#parts + 1] = fmtBox(o)
	if s.type == "CheckButton" then parts[#parts + 1] = s.checked and "checked" or "unchecked" end
	if s.type == "Slider" or s.type == "StatusBar" then
		parts[#parts + 1] = ("value=%s (%s..%s)"):format(tostring(s.value), tostring(s.min), tostring(s.max))
	end
	if s.disabled then parts[#parts + 1] = "disabled" end
	if s.strata then parts[#parts + 1] = "strata=" .. s.strata end
	if s.scale ~= 1 then parts[#parts + 1] = "scale=" .. s.scale end
	if s.secretText or s.secretValue then parts[#parts + 1] = "SECRET" end
	if H.focus == o then parts[#parts + 1] = "focus" end
	return table.concat(parts, " ")
end

-- opts.textures: also list textures; opts.hidden: also list hidden objects
function H.Tree(root, opts)
	opts = opts or {}
	local out = {}
	local function walk(o, depth)
		if not opts.hidden and not o[0].shown then return end
		out[#out + 1] = ("  "):rep(depth) .. describe(o) .. (o[0].shown and "" or " hidden")
		for _, r in ipairs(o[0].regions) do
			if (r[0].shown or opts.hidden) and (opts.textures or r[0].type == "FontString") then
				if r[0].type ~= "FontString" or (r[0].text or "") ~= "" then
					out[#out + 1] = ("  "):rep(depth + 1) .. describe(r) .. (r[0].shown and "" or " hidden")
				end
			end
		end
		for _, child in ipairs(sortedChildren(o)) do walk(child, depth + 1) end
	end
	if root then
		walk(root, 0)
	else
		for _, child in ipairs(sortedChildren(UIParent)) do walk(child, 0) end
	end
	return table.concat(out, "\n")
end

local INTERACTIVE = { Button = true, CheckButton = true, Slider = true, EditBox = true }

-- Problems a player would see: text spilling out of its container, controls on top of each
-- other, windows partly off screen, things that were shown but never positioned.
function H.LayoutIssues(root)
	local issues = {}
	local function add(o, what) issues[#issues + 1] = what .. ": " .. describe(o) end
	local function clipped(o)
		local p = o[0].parent
		while p do
			if p[0].clips or p:IsObjectType("ScrollFrame") then return true end
			p = p[0].parent
		end
		return false
	end
	local wx, wy, ww, wh -- the top-level window being walked
	local function walk(f)
		if not f[0].shown then return end
		local fx, fy, fw, fh = box(f)
		if f[0].parent == UIParent then wx, wy, ww, wh = fx, fy, fw, fh end
		-- minimap buttons sit on the minimap's edge on purpose
		if fx and wx and f[0].parent ~= UIParent and f[0].parent ~= rawget(_G, "Minimap") and fw > 0 and fh > 0 and not clipped(f)
			and (fx < wx - 2 or fy < wy - 2 or fx + fw > wx + ww + 2 or fy + fh > wy + wh + 2) then
			add(f, "outside its window")
		end
		if not fx then
			if f ~= UIParent then add(f, "unanchored frame") end
		elseif f[0].parent == UIParent and fw > 0 and fh > 0 and f[0].type ~= "GameTooltip" then
			if fx < -1 or fy < -1 or fx + fw > H.screenWidth + 1 or fy + fh > H.screenHeight + 1 then add(f, "partly off screen") end
		end
		for _, r in ipairs(f[0].regions) do
			if r[0].shown then
				local x, y, w, h = box(r)
				if not x then
					add(r, "unanchored region")
				elseif r[0].type == "FontString" and (r[0].text or "") ~= "" and fx and not clipped(r) then
					if x < fx - 1 or x + w > fx + fw + 1 or y < fy - 1 or y + h > fy + fh + 1 then
						-- text outside its own frame is fine when it still sits inside the frame's parent
						-- (labels beside a checkbox); report only when it leaves that as well
						local p = f[0].parent
						local px, py, pw, ph = 0, 0, H.screenWidth, H.screenHeight
						if p and p ~= UIParent then px, py, pw, ph = box(p) end
						if px and (x < px - 1 or x + w > px + pw + 1 or y < py - 1 or y + h > py + ph + 1) then
							add(r, "text overflows its container")
						end
					end
					if r:IsTruncated() then add(r, "text truncated") end
				end
			end
		end
		local kids = {}
		for _, child in ipairs(f[0].children) do
			if child[0].shown then
				kids[#kids + 1] = child
				walk(child)
			end
		end
		for i = 1, #kids do
			for j = i + 1, #kids do
				local a, b = kids[i], kids[j]
				if INTERACTIVE[a[0].type] and INTERACTIVE[b[0].type] then
					local ax, ay, aw, ah = box(a)
					local bx, by, bw, bh = box(b)
					if ax and bx and aw > 0 and bw > 0 then
						local ow = math.min(ax + aw, bx + bw) - math.max(ax, bx)
						local oh = math.min(ay + ah, by + bh) - math.max(ay, by)
						if ow > 1 and oh > 1 and ow * oh > 0.25 * math.min(aw * ah, bw * bh) then
							add(a, "controls overlap (" .. describe(b) .. ")")
						end
					end
				end
			end
		end
	end
	if root then
		walk(root)
	else
		for _, child in ipairs(UIParent[0].children) do walk(child) end
	end
	return issues
end

-- Finds visible frames/regions under root by text, name or predicate. Handy in tests:
--   H.Find(window, "Save")  -> the first object whose text or name is "Save"
function H.FindAll(root, what)
	local found = {}
	local match = type(what) == "function" and what or function(o)
		local s = o[0]
		if s.name == what then return true end
		if s.type == "FontString" then return H.plain(s.text or "") == what end
		if s.fontString then return H.plain(s.fontString[0].text or "") == what end
		return false
	end
	local function walk(o)
		if not o[0].shown then return end
		if match(o) then found[#found + 1] = o end
		for _, r in ipairs(o[0].regions) do
			if r[0].shown and match(r) then found[#found + 1] = r end
		end
		for _, child in ipairs(o[0].children) do walk(child) end
	end
	walk(root or UIParent)
	return found
end
function H.Find(root, what)
	if what == nil then root, what = nil, root end
	return H.FindAll(root, what)[1]
end

return H
