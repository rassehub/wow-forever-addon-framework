local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme

-- RichText: a small markup rendered into font strings and textures, for wiki pages, journal
-- text, help pages and notes. Every colour and font comes from the theme, so pages re-skin.
--
--   # Title                     large heading
--   ## Section                  heading with a rule under it
--   plain lines                 joined into one wrapped paragraph; a blank line starts the next
--   - item                      bullet (nest with two spaces: "  - sub item")
--   > note                      dim, indented aside
--   ---                         divider
--   ![32](media:Icons/map)      image on its own line: size (or WxH) and a texture path
--   **bold**                    emphasis (accent colour; one font per line in WoW)
--   [label](target)             link: onLink(target, mouseButton); targets are any text
--   :icon:                      inline icon from the library's set (FK.mediaIcons) or theme
--
-- Raw WoW escape codes (|cff..., item links |Hitem:...|h) pass through; clicking an item link
-- opens the game's item tooltip.

local function hex(role)
	local r, g, b = Theme.Color(role)
	return ("%02x%02x%02x"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
end

-- Inline markup -> a WoW escape string. size: the line height for inline icons.
local function inline(text, size)
	local r, g, b = Theme.Color("text")
	text = text:gsub(":([%w%-]+):", function(name)
		if not FK.mediaIcons[name] then return nil end
		return ("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(FK.Media("Icons/" .. name), size, size,
			r * 255, g * 255, b * 255)
	end)
	text = text:gsub("%*%*(.-)%*%*", function(s) return "|cff" .. hex("accent") .. s .. "|r" end)
	text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(label, target)
		return ("|Hfk:%s|h|cff%s%s|r|h"):format(target, hex("link"), label)
	end)
	return text
end
FK.RichInline = inline

-- Markup -> blocks { kind, text, level } (pure, testable).
function FK.ParseRichText(markup)
	local blocks, para = {}, nil
	local function flush()
		if para then blocks[#blocks + 1] = { kind = "p", text = table.concat(para, " ") } para = nil end
	end
	for line in (markup .. "\n"):gmatch("(.-)\r?\n") do
		local h1, h2 = line:match("^#%s+(.*)$"), line:match("^##%s+(.*)$")
		local indent, bullet = line:match("^(%s*)[-*]%s+(.*)$")
		local quote = line:match("^>%s?(.*)$")
		local size, path = line:match("^!%[([%dx]*)%]%((.-)%)%s*$")
		if line:match("^%s*$") then
			flush()
		elseif h2 then flush() blocks[#blocks + 1] = { kind = "h2", text = h2 }
		elseif h1 then flush() blocks[#blocks + 1] = { kind = "h1", text = h1 }
		elseif line:match("^%-%-%-+%s*$") then flush() blocks[#blocks + 1] = { kind = "hr" }
		elseif bullet then flush() blocks[#blocks + 1] = { kind = "li", text = bullet, level = math.floor(#indent / 2) }
		elseif quote then flush() blocks[#blocks + 1] = { kind = "quote", text = quote }
		elseif path then
			flush()
			local w, h = size:match("^(%d+)x(%d+)$")
			w = tonumber(w or size) or 64
			blocks[#blocks + 1] = { kind = "img", path = path, width = w, height = tonumber(h) or w }
		else
			para = para or {}
			para[#para + 1] = line:match("^%s*(.-)%s*$")
		end
	end
	flush()
	return blocks
end

---@widget RichText  Formatted text from a small markup (# headings, paragraphs, - bullets, > notes, ---, ![size](texture) images, **emphasis**, [label](target) links, :icon: icons): wiki pages, journal text, help. opts: text, onLink(target, mouseButton), linkTooltip(target) -> text or {title, line}, gap. Methods: SetText(markup). Height follows the content; give it a width.
FK.Define("RichText", {
	SetText = function(self, markup)
		self.markup = markup or ""
		self:Render()
	end,
	GetText = function(self) return self.markup end,
	Restyle = function(self) if self.markup then self:Render() end end,
	Render = function(self)
		local m = Theme.current.metric
		for _, r in ipairs(self.parts) do r:Hide() r:ClearAllPoints() end
		local nText, nTex, y = 0, 0, 0
		local function text(role, color)
			nText = nText + 1
			local fs = self.texts[nText]
			if not fs then
				fs = self:Text(role, color)
				fs:SetJustifyH("LEFT")
				fs:SetJustifyV("TOP")
				fs:SetWordWrap(true)
				self.texts[nText] = fs
				self.parts[#self.parts + 1] = fs
			end
			fs.fkRole, fs.fkColor = role, color
			Theme.Font(fs, role, color)
			fs:Show()
			return fs
		end
		local function tex()
			nTex = nTex + 1
			local t = self.textures[nTex]
			if not t then
				t = self:CreateTexture(nil, "ARTWORK")
				self.textures[nTex] = t
				self.parts[#self.parts + 1] = t
			end
			t:SetTexCoord(0, 1, 0, 1)
			t:SetVertexColor(1, 1, 1, 1)
			t:Show()
			return t
		end
		local lineH = 12
		local gap = self.opts.gap or m.gap
		-- Each block hangs from the bottom of the one above, so the client stacks them by the real
		-- text heights (font metrics and wrapping can differ from any measurement made earlier).
		-- `y` only estimates the total height; FitHeight corrects it from the real bottom edge.
		local prev, prevIndent
		local function place(region, indent, height, before)
			indent, before = indent or 0, before or 0
			if prev then
				region:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", indent - prevIndent, -(gap + before))
				y = y + gap + before
			else
				region:SetPoint("TOPLEFT", indent, -before)
				y = y + before
			end
			if region.SetWordWrap then region:SetPoint("RIGHT", self, "RIGHT") end
			prev, prevIndent = region, indent
			y = y + (height or region:GetStringHeight())
		end
		for i, b in ipairs(FK.ParseRichText(self.markup)) do
			if b.kind == "h1" then
				local fs = text("large", "heading")
				fs:SetText(inline(b.text, 16))
				place(fs, 0, nil, i > 1 and gap or 0)
			elseif b.kind == "h2" then
				local fs = text("heading", "heading")
				fs:SetText(inline(b.text, lineH))
				place(fs, 0, nil, i > 1 and gap / 2 or 0)
				local rule = tex()
				rule:SetColorTexture(Theme.Color("divider"))
				rule:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
				rule:SetPoint("RIGHT", self, "RIGHT")
				rule:SetHeight(FK.Pixel(1))
				prev, y = rule, y + 3 + FK.Pixel(1)
			elseif b.kind == "p" then
				local fs = text("normal")
				fs:SetText(inline(b.text, lineH))
				place(fs)
			elseif b.kind == "li" then
				local indent = 14 + b.level * 14
				local fs = text("normal")
				fs:SetText(inline(b.text, lineH))
				place(fs, indent)
				local dot = tex()
				dot:SetTexture(FK.Media("Frames/pill"))
				dot:SetVertexColor(Theme.Color("accent"))
				dot:SetSize(5, 5)
				dot:SetPoint("TOPLEFT", fs, "TOPLEFT", -9, -4)
			elseif b.kind == "quote" then
				local fs = text("normal", "dim")
				fs:SetText(inline(b.text, lineH))
				place(fs, 12)
				local bar = tex()
				bar:SetColorTexture(Theme.Color("accent"))
				bar:SetPoint("TOPLEFT", fs, "TOPLEFT", -10, 0)
				bar:SetPoint("BOTTOMLEFT", fs, "BOTTOMLEFT", -10, 0)
				bar:SetWidth(2)
			elseif b.kind == "hr" then
				local rule = tex()
				rule:SetColorTexture(Theme.Color("divider"))
				place(rule, 0, FK.Pixel(1), 3)
				rule:SetPoint("RIGHT", self, "RIGHT")
				rule:SetHeight(FK.Pixel(1))
			elseif b.kind == "img" then
				local t = tex()
				t:SetTexture(Theme.Resolve(b.path))
				-- the icon set is white: give it the heading colour so it shows on light themes too
				if b.path:find("^media:Icons/") then t:SetVertexColor(Theme.Color("heading")) end
				t:SetSize(b.width, b.height)
				place(t, 0, b.height)
			end
		end
		self.lastRegion = prev
		self:SetHeight(math.max(y, 1))
		self:Changed()
		-- next frame, when the client has laid the text out: the real height
		if not self.fitPending then
			self.fitPending = true
			C_Timer.After(0, function() self.fitPending = nil self:FitHeight() end)
		end
	end,
	FitHeight = function(self)
		local last, top = self.lastRegion, self:GetTop()
		local bottom = last and last:IsShown() and last:GetBottom()
		if not (top and bottom) then return end
		local h = math.max(top - bottom, 1)
		if math.abs(h - self:GetHeight()) > 0.5 then
			self:SetHeight(h)
			self:Changed()
		end
	end,
}, function(self, opts)
	self.parts, self.texts, self.textures = {}, {}, {}
	self:SetHyperlinksEnabled(true)
	self:SetScript("OnHyperlinkClick", function(_, link, text, button)
		local target = link:match("^fk:(.*)$")
		if target then
			if opts.onLink then opts.onLink(target, button) end
		elseif SetItemRef then
			SetItemRef(link, text, button)
		end
	end)
	self:SetScript("OnHyperlinkEnter", function(_, link)
		local target = link:match("^fk:(.*)$")
		local tip = target and opts.linkTooltip and opts.linkTooltip(target)
		if tip then FK.Tooltip.Show(self, tip, "ANCHOR_CURSOR") end
	end)
	self:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
	local lastWidth
	self:SetScript("OnSizeChanged", function(_, w)
		-- wrapping depends on the width: lay out again when it changes (not when only the height does)
		if self.markup and w and math.abs(w - (lastWidth or -1)) > 0.5 then
			lastWidth = w
			self:Render()
		end
	end)
	self.markup = opts.text or ""
	self:Render()
end)
