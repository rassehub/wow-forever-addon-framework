-- Renders the emulated screen as a standalone HTML page.
-- Exact: geometry, flat colours, text content, z-order, clipping, alpha.
-- Approximate: Blizzard texture files (drawn from the ART table below, by file name) and
-- fonts (the game's Friz Quadrata is not available; a system font stands in).

local H = require("wow.state")

-- CSS stand-ins for Blizzard art, matched against the lower-cased file path.
-- { pattern, css [, glyph] }: css styles the box, glyph is drawn centred in it.
local ART = {
	{ "white8x8", "background:#fff" },
	{ "ui%-dialogbox%-background", "background:#1b1410" },
	{ "chatframebackground", "background:#fff" },
	{ "ui%-dialogbox%-header", "background:linear-gradient(#3a2a1a,#1e150d);border:2px solid #c9a55a;border-radius:6px;clip-path:inset(15% 14% 38% 14% round 6px)" },
	{ "ui%-panel%-button%-up", "background:linear-gradient(#8e1a12,#5a0d08);border:1px solid #d4b062;border-radius:4px" },
	{ "ui%-panel%-button%-down", "background:linear-gradient(#4f0b07,#7a150e);border:1px solid #d4b062;border-radius:4px" },
	{ "ui%-panel%-button%-disabled", "background:linear-gradient(#4a4a4a,#2e2e2e);border:1px solid #777;border-radius:4px" },
	{ "ui%-panel%-button%-highlight", "background:rgba(255,220,120,.25);border-radius:4px" },
	{ "ui%-checkbox%-up", "background:radial-gradient(#141414 55%,#0000 56%),linear-gradient(#d8bd72,#8a6d2a);border-radius:5px;clip-path:inset(12%)" },
	{ "ui%-checkbox%-highlight", "background:rgba(255,230,140,.3);border-radius:5px;clip-path:inset(12%)" },
	{ "ui%-checkbox%-check", "", "<span style='color:#ffd100;font-weight:bold;font-size:120%'>&#10003;</span>" },
	{ "ui%-radiobutton", "background:#ffd100;border-radius:50%" },
	{ "ui%-sliderbar%-background", "background:#2a2018" },
	{ "ui%-sliderbar%-button%-horizontal", "background:linear-gradient(135deg,#f3dc8c,#a47d2c);clip-path:polygon(50% 18%,72% 50%,50% 82%,28% 50%)" },
	{ "ui%-panel%-minimizebutton", "background:linear-gradient(#8e1a12,#5a0d08);border:1px solid #d4b062;border-radius:4px;clip-path:inset(18%)", "<span style='color:#ffd100;font-weight:bold'>&#10005;</span>" },
	{ "ui%-plusbutton", "background:#3a2a1a;border:1px solid #c9a55a", "<span style='color:#ffd100'>+</span>" },
	{ "ui%-minusbutton", "background:#3a2a1a;border:1px solid #c9a55a", "<span style='color:#ffd100'>&minus;</span>" },
	{ "ui%-questtitlehighlight", "background:linear-gradient(90deg,rgba(90,140,255,0),rgba(90,140,255,.45),rgba(90,140,255,0))" },
	{ "ui%-statusbar", "background:linear-gradient(#fff,#bbb 45%,#888)" },
	{ "ui%-scrollbar%-knob", "background:linear-gradient(#e6cb7c,#8a6d2a);border-radius:3px" },
	{ "chatframeexpandarrow", "", "<span>&#9656;</span>" },
	{ "ui%-optionsbutton", "", "<span>&#9881;</span>" },
	{ "ui%-searchbox%-icon", "", "<span>&#9906;</span>" },
	{ "sizegrabber", "background:linear-gradient(135deg,#0000 50%,#999 50%,#999 60%,#0000 60%,#0000 70%,#999 70%,#999 80%,#0000 80%)" },
	{ "questbg", "background:linear-gradient(#e8d6ab,#d2bc8a)" },
	{ "parchment", "background:linear-gradient(#e8d6ab,#d2bc8a)" },
	{ "interface\\icons\\", "background:repeating-linear-gradient(45deg,#555,#555 3px,#3d3d3d 3px,#3d3d3d 6px);border:1px solid #111" },
}
local EDGES = {
	{ "white8x8", function(size, c) return ("border:%.2fpx solid %s"):format(math.max(size, 1), c) end },
	{ "ui%-dialogbox%-border", function(_, c) return "border:5px ridge #c9a55a;border-radius:9px;outline:1px solid #2a1c0a;outline-offset:-7px" end },
	{ "ui%-tooltip%-border", function(size, c) return ("border:1px solid %s;border-radius:%dpx;box-shadow:inset 0 0 0 1px rgba(0,0,0,.6)"):format(c, size >= 14 and 5 or 3) end },
	{ "ui%-sliderbar%-border", function(_, c) return "border:1px solid #9a8a6a;border-radius:3px" end },
}

local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

local function rgba(c, alphaScale)
	c = c or { 1, 1, 1, 1 }
	return ("rgba(%d,%d,%d,%.3f)"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5, (c[4] or 1) * (alphaScale or 1))
end

local function art(file)
	if type(file) == "number" then return ART[#ART][2], nil end -- file ids are icons
	local name = tostring(file):lower()
	for _, entry in ipairs(ART) do
		if name:find(entry[1]) then return entry[2], entry[3] end
	end
	return "outline:1px dashed #f0f;background:rgba(255,0,255,.08)", nil -- unknown art: visible on purpose
end

-- WoW text escapes -> HTML
local function markup(text)
	text = esc(tostring(text))
	text = text:gsub("|T.-|t", "<span class=inl></span>"):gsub("|A.-|a", "<span class=inl></span>")
	text = text:gsub("|H.-|h", ""):gsub("|h", ""):gsub("|n", "<br>")
	local out, open = {}, 0
	local pos = 1
	while true do
		local s, e, hex = text:find("|c%x%x(%x%x%x%x%x%x)", pos)
		local rs, re = text:find("|r", pos, true)
		if not s and not rs then break end
		if s and (not rs or s < rs) then
			out[#out + 1] = text:sub(pos, s - 1) .. "<span style='color:#" .. hex .. "'>"
			open, pos = open + 1, e + 1
		else
			out[#out + 1] = text:sub(pos, rs - 1) .. (open > 0 and "</span>" or "")
			open, pos = math.max(open - 1, 0), re + 1
		end
	end
	out[#out + 1] = text:sub(pos) .. ("</span>"):rep(open)
	return (table.concat(out):gsub("\n", "<br>"):gsub("||", "|"))
end

-- opts.crop: frame to crop the page to (with a margin); opts.title
function H.Render(opts)
	opts = opts or {}
	local out, z = {}, 0
	local W, Ht, screenH = H.screenWidth, H.screenHeight, H.screenHeight
	local ox, oy = 0, 0 -- page origin when cropped
	if opts.crop then
		local l, b, w, h = H.resolve(opts.crop)
		if l then
			local m = opts.margin or 24
			ox, oy = l - m, screenH - (b + h) - m
			W, Ht = w + m * 2, h + m * 2
		end
	end

	-- page rectangle: x, y of the top-left corner, width, height
	local function rect(o)
		local l, b, w, h = H.resolve(o)
		if not l then return nil end
		return l - ox, screenH - (b + h) - oy, w, h
	end

	local function clipOf(o)
		-- intersection of all clipping ancestors, in page coordinates
		local cl, ct, cr, cb
		local p = o[0].parent
		while p do
			if p[0].clips or p:IsObjectType("ScrollFrame") then
				local x, y, w, h = rect(p)
				if x then
					cl, ct = math.max(cl or x, x), math.max(ct or y, y)
					cr, cb = math.min(cr or (x + w), x + w), math.min(cb or (y + h), y + h)
				end
			end
			p = p[0].parent
		end
		return cl, ct, cr, cb
	end

	local function emit(o, x, y, w, h, style, inner, title)
		local cl, ct, cr, cb = clipOf(o)
		local clip = ""
		if cl then
			if cr <= x or cl >= x + w or cb <= y or ct >= y + h then return end
			clip = ("clip-path:inset(%.1fpx %.1fpx %.1fpx %.1fpx);"):format(math.max(0, ct - y), math.max(0, x + w - cr), math.max(0, y + h - cb), math.max(0, cl - x))
		end
		z = z + 1
		out[#out + 1] = ("<div style='left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;z-index:%d;%s%s'%s>%s</div>")
			:format(x, y, w, h, z, clip, style, title and (" title='" .. esc(title):gsub("'", "&#39;") .. "'") or "", inner or "")
	end

	local function fontCss(o)
		local f = o[0].font
		local size = f.size * o:GetEffectiveScale()
		local css = ("font-size:%.1fpx;line-height:%.1fpx;color:%s;"):format(size, size + (f.spacing or 0), rgba(f.color))
		if not (f.shadowColor and f.shadowColor[4] == 0) then -- the game's fonts carry a drop shadow
			css = css .. "text-shadow:1px 1px 1px rgba(0,0,0,.9);"
		end
		if (f.flags or ""):find("OUTLINE") then css = css .. "text-shadow:-1px 0 #000,1px 0 #000,0 -1px #000,0 1px #000;" end
		return css
	end

	local function drawRegion(r, alpha, hovered)
		local s = r[0]
		if not s.shown or (s.layer == "HIGHLIGHT" and not hovered) then return end
		local x, y, w, h = rect(r)
		if not x then return end
		local a = alpha * s.alpha
		if s.type == "FontString" then
			if (s.text or "") == "" then return end
			local align = (s.font.justifyH or "CENTER"):lower()
			-- line breaks are the emulator's, never the browser's: the stand-in font has other widths
			local css = fontCss(r) .. ("text-align:%s;opacity:%.3f;white-space:nowrap;"):format(align, a)
			if r:IsTruncated() then css = css .. "overflow:hidden;text-overflow:ellipsis;" end
			-- each line carries the width the emulator measured; the page script squeezes or
			-- stretches the stand-in font to it, so what overflows here overflows in the emulator
			local lines = {}
			for i, line in ipairs(H.TextLines(r)) do
				lines[i] = ("<span class=ln data-w='%.1f'>%s</span>"):format(H.textWidth(H.plain(line), s.font.size) * r:GetEffectiveScale(), markup(line))
			end
			emit(r, x, y, w, h, "display:block;" .. css, table.concat(lines, "<br>"), s.secretText and "SECRET" or nil)
		elseif s.type == "Texture" then
			if w <= 0 or h <= 0 then return end
			local css, glyph
			if s.color then
				css = "background:" .. rgba(s.color, a)
			elseif s.texture or s.atlas then
				css, glyph = art(s.texture or ("atlas:" .. s.atlas))
				if tostring(s.texture):lower():find("ui%-radiobutton") then
					local left = s.texCoord and s.texCoord[1] or 0
					css = left < 0.2 and "border:2px solid #b89a50;border-radius:50%;background:#111"
						or left < 0.45 and "background:radial-gradient(#ffd100 38%,#0000 42%)"
						or "background:radial-gradient(rgba(255,230,140,.35) 60%,#0000 62%)"
				end
				css = css .. (";opacity:%.3f"):format(a * (s.vertex and s.vertex[4] or 1))
				local v = s.vertex
				if s.barOf then v = s.barOf[0].barColor or v end -- StatusBar:SetStatusBarColor
				if v and glyph then
					glyph = glyph:gsub("<span", ("<span style='color:%s' data-v"):format(rgba(v)), 1)
				elseif v and (v[1] < 0.99 or v[2] < 0.99 or v[3] < 0.99) then
					-- tint: multiply the stand-in with the vertex colour
					css = css .. (";box-shadow:inset 0 0 0 100vmax rgba(%d,%d,%d,.55)"):format(v[1] * 255, v[2] * 255, v[3] * 255)
				end
				if s.rotation and s.rotation ~= 0 then css = css .. (";transform:rotate(%.3frad)"):format(-s.rotation) end
			else
				return
			end
			if s.blend == "ADD" then css = css .. ";mix-blend-mode:screen" end
			if glyph then css = css .. (";font-size:%.1fpx;line-height:%.1fpx;color:#ddd"):format(h * 0.95, h) end
			emit(r, x, y, w, h, "display:flex;align-items:center;justify-content:center;" .. css, glyph, tostring(s.texture or s.atlas or ""))
		end
	end

	local function drawFrame(f)
		local s = f[0]
		local x, y, w, h = rect(f)
		if not x then return end
		local alpha = f:GetEffectiveAlpha()
		local bd = s.backdrop
		if bd and w > 0 and h > 0 then
			local es = f:GetEffectiveScale()
			local bgc = s.backdropColor or { 1, 1, 1, 1 }
			if bd.bgFile then
				local ins = bd.insets or {}
				local il, ir, it, ib = (ins.left or 0) * es, (ins.right or 0) * es, (ins.top or 0) * es, (ins.bottom or 0) * es
				local name = tostring(bd.bgFile):lower()
				local css
				if name:find("white8x8") or name:find("chatframebackground") or name:find("ui%-tooltip%-background") then -- plain tiles: the backdrop colour is the colour
					css = "background:" .. rgba(bgc, alpha)
				else
					-- textured background: the backdrop colour multiplies it (grey = darker)
					local lum = (bgc[1] + bgc[2] + bgc[3]) / 3
					css = (art(bd.bgFile)) .. (";opacity:%.3f;filter:brightness(%.2f)"):format((bgc[4] or 1) * alpha, lum)
				end
				emit(f, x + il, y + it, w - il - ir, h - it - ib, css, nil, s.name)
			end
			if bd.edgeFile then
				local name = tostring(bd.edgeFile):lower()
				for _, e in ipairs(EDGES) do
					if name:find(e[1]) then
						emit(f, x, y, w, h, ("opacity:%.3f;"):format(alpha) .. e[2]((bd.edgeSize or 1) * es, rgba(s.backdropBorderColor)))
						break
					end
				end
			end
		end
		local regions = { unpack(s.regions) }
		local function key(r) return H.LAYERS[r[0].layer or "ARTWORK"] * 100 + (r[0].sublayer or 0) + r[0].serial / 1e7 end
		table.sort(regions, function(a, b) return key(a) < key(b) end)
		for _, r in ipairs(regions) do drawRegion(r, alpha, H.hover == f) end
		if s.type == "EditBox" and (s.text or "") ~= "" then
			local align = (s.font.justifyH or "LEFT"):lower()
			local shown = s.password and ("*"):rep(#s.text) or s.text
			local multi = s.multiLine -- top-aligned and wrapping; one-line boxes centre vertically
			emit(f, x, y, w, h, ("display:flex;align-items:%s;justify-content:%s;white-space:%s;overflow:hidden;opacity:%.3f;%s")
				:format(multi and "flex-start" or "center", align == "center" and "center" or align == "right" and "flex-end" or "flex-start",
					multi and "pre-wrap" or "nowrap", alpha, fontCss(f)), esc(shown))
		end
		if s.type == "GameTooltip" and #(s.lines or {}) > 0 then
			local rows = {}
			for _, line in ipairs(s.lines) do
				rows[#rows + 1] = ("<div style='color:%s'>%s%s</div>"):format(rgba(line.color), markup(line.left or ""),
					line.right and ("<span style='float:right;margin-left:12px'>" .. markup(line.right) .. "</span>") or "")
			end
			emit(f, x, y, w, h, "box-sizing:border-box;background:rgba(8,10,24,.95);border:1px solid #aaa;border-radius:5px;padding:7px 9px;font-size:12px;line-height:14px;display:block;height:auto;min-height:" .. h .. "px;white-space:nowrap", table.concat(rows))
		end
	end

	local frames = {}
	for _, f in ipairs(H.frames) do
		if f ~= UIParent and f ~= WorldFrame and f:IsVisible() then frames[#frames + 1] = f end
	end
	table.sort(frames, function(a, b) return H.order(a) < H.order(b) end)
	for _, f in ipairs(frames) do drawFrame(f) end

	return ([[<!doctype html>
<html><head><meta charset="utf-8"><title>%s</title>
<style>
html,body{margin:0;background:#111}
#screen{position:relative;width:%dpx;height:%dpx;overflow:hidden;
 background:radial-gradient(ellipse at 30%% 20%%,#3f5a48,#1d2b26 60%%,#141c1a);
 font-family:"Friz Quadrata TT","Friz Quadrata","Arial","Liberation Sans","DejaVu Sans",sans-serif}
#screen div{position:absolute;box-sizing:border-box}
#screen div div{position:static}
.ln{display:inline-block;white-space:nowrap}
.inl{display:inline-block;width:1em;height:1em;background:#666;vertical-align:-0.15em}
</style></head><body><div id="screen">
%s
</div>
<script>
// squeeze or stretch each text line to the width the emulator measured for it
for (const el of document.querySelectorAll(".ln")) {
  const want = parseFloat(el.dataset.w), have = el.getBoundingClientRect().width;
  if (want > 0 && have > 0) {
    const k = Math.min(1.3, Math.max(0.7, want / have));
    el.innerHTML = "<span style='display:inline-block;white-space:nowrap;transform-origin:left;transform:scaleX(" + k + ")'>" + el.innerHTML + "</span>";
    el.style.width = want + "px";
    el.style.textAlign = "left";
  }
}
</script></body></html>
]]):format(esc(opts.title or "ForeverKit preview"), W, Ht, table.concat(out, "\n"))
end

return H
