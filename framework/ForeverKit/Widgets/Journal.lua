local _, ns = ...
local FK = ns.FK
local Theme = FK.Theme
local L = FK.L

-- Journal: the encyclopedia layout (dungeon journal, bestiary, wiki, codex) as one widget.
--
--   +--------------------------------------------------------------+
--   | [icon]  Title of the selected entry                           |  header (banner art optional)
--   |         subtitle                                              |
--   | Home > Dungeons > The Deadmines                               |  breadcrumb (clickable)
--   +----------------+---------------------------------------------+
--   | [search      ] | [Overview] [Loot] [Abilities]                |  section tabs (optional)
--   | v Dungeons     |                                             |
--   |   > Deadmines  |   page content: markup or widgets           |
--   |   > Stockades  |                                             |
--   +----------------+---------------------------------------------+
--
-- A node is a Tree node ({ label, icon, children, value, subtitle }). Content comes from
-- opts.render(page, node, sectionId): return markup (shown with RichText) or add widgets to
-- `page` (a ScrollArea: page:Add(widget)). Pages are built once per node and section and kept,
-- so browsing back is instant and frames are not created again.

local function filterNodes(nodes, needle)
	local out = {}
	for _, n in ipairs(nodes) do
		local kids = n.children and filterNodes(n.children, needle)
		local hit = tostring(n.label):lower():find(needle, 1, true)
		if hit or (kids and #kids > 0) then
			local copy = setmetatable({ children = (kids and #kids > 0) and kids or (hit and n.children) or nil, expanded = true, original = n }, { __index = n })
			out[#out + 1] = copy
		end
	end
	return out
end

local function pathTo(nodes, target, trail)
	for _, n in ipairs(nodes) do
		local here = { unpack(trail) }
		here[#here + 1] = n
		if n == target then return here end
		if n.children then
			local found = pathTo(n.children, target, here)
			if found then return found end
		end
	end
end

---@widget Journal  Encyclopedia layout in one widget: header with icon, title, subtitle and banner art, clickable breadcrumb, searchable tree navigation, section tabs, cached content pages (dungeon journals, bestiaries, codexes, wikis). opts: title, subtitle, icon (icon-set name or texture), banner (texture shown faintly behind the header), nodes (Tree nodes, may carry subtitle and icon), sections = list of { id, label } or function(node) -> list, render(page, node, sectionId) -> markup or nil (add widgets to the ScrollArea `page`), onLink(target, button) for links in markup, navWidth (default 210), search (default true), home (label of the breadcrumb root, default the title). Methods: SetNodes(nodes), Select(nodeOrValue, sectionId), GetSelected(), Refresh() (rebuild the current page).
FK.Define("Journal", {
	SetNodes = function(self, nodes)
		self.nodes = nodes or {}
		self.pages = {}
		self:Filter(self.search and self.search:GetValue() or "")
	end,
	Filter = function(self, text)
		local needle = (text or ""):lower()
		self.tree:SetNodes(needle == "" and self.nodes or filterNodes(self.nodes, needle))
		if self.selected then self.tree:Select(self.selected) end
	end,
	GetSelected = function(self) return self.selected, self.section end,
	Select = function(self, v, section)
		local node = v
		if type(v) ~= "table" or not v.label then
			local function find(nodes)
				for _, n in ipairs(nodes) do
					if n.value == v then return n end
					local hit = n.children and find(n.children)
					if hit then return hit end
				end
			end
			node = find(self.nodes)
		end
		node = node and (rawget(node, "original") or node)
		if not node then return end
		self.selected = node
		self.tree:Select(node)
		self:ShowNode(node, section)
	end,
	Refresh = function(self)
		if not self.selected then return end
		local cache = self.pages[self.selected]
		if cache then
			for _, p in pairs(cache.pages or {}) do p:Hide() end
			if cache.tabs then cache.tabs:Hide() end
		end
		self.pages[self.selected] = nil
		self:ShowNode(self.selected, self.section)
	end,
	-- Header, breadcrumb and the page for a node.
	ShowNode = function(self, node, section)
		local opts = self.opts
		self.header.title:SetText(node.label or opts.title or "")
		self.header.subtitle:SetText(node.subtitle or "")
		self:SetHeaderIcon(node.icon or opts.icon)
		-- breadcrumb
		local trail = pathTo(self.nodes, node, {}) or { node }
		local r, g, b = Theme.Color("link")
		local link = ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
		local parts = { ("|Hfk:crumb:0|h%s%s|r|h"):format(link, opts.home or opts.title or L["Home"]) }
		self.crumbs = trail
		for i, n in ipairs(trail) do
			parts[#parts + 1] = i < #trail and ("|Hfk:crumb:%d|h%s%s|r|h"):format(i, link, n.label) or n.label
		end
		self.crumb.text:SetText(table.concat(parts, "  |cff888888>|r  "))
		-- page(s)
		for n, cache in pairs(self.pages) do
			if cache.tabs then cache.tabs:Hide() end
			for _, p in pairs(cache.pages) do p:Hide() end
		end
		local cache = self.pages[node]
		if not cache then
			cache = { pages = {} }
			self.pages[node] = cache
			local sections = opts.sections
			if type(sections) == "function" then sections = sections(node) end -- may be nil: no tabs
			if sections and #sections > 1 then
				cache.ids = {}
				local tabs = {}
				for i, sec in ipairs(sections) do
					cache.ids[sec.id] = true
					tabs[i] = { id = sec.id, label = sec.label, build = function(holder)
						cache.pages[sec.id] = self:BuildPage(holder, node, sec.id)
					end }
				end
				cache.tabs = FK.Tabs(self.body, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, tabs = tabs,
					onChange = function(id) self.section = id end })
			else
				local sid = sections and sections[1] and sections[1].id
				cache.single = self:BuildPage(self.body, node, sid)
				cache.pages[sid or 1] = cache.single
			end
		end
		if cache.tabs then
			cache.tabs:Show()
			local sid = section or self.section
			cache.tabs:Select(cache.ids[sid] and sid or cache.tabs:GetValue())
			self.section = cache.tabs:GetValue()
			for _, p in pairs(cache.pages) do p:Show() end
		else
			cache.single:Show()
		end
		if opts.onSelect then opts.onSelect(node, self.section) end
	end,
	BuildPage = function(self, holder, node, sectionId)
		local page = FK.ScrollArea(holder, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, padding = 4 })
		local markup = self.opts.render and self.opts.render(page, node, sectionId)
		if type(markup) == "string" then
			page:Add(FK.RichText(page.content, { text = markup, onLink = function(target, button)
				local crumb = target:match("^journal:(.+)$")
				if crumb then return self:Select(tonumber(crumb) or crumb) end
				if self.opts.onLink then self.opts.onLink(target, button) end
			end }))
		end
		return page
	end,
	SetHeaderIcon = function(self, icon)
		local t = self.header.icon
		t:SetShown(icon ~= nil)
		if not icon then return end
		local named = type(icon) == "string" and FK.mediaIcons[icon]
		t:SetTexture(named and FK.Media("Icons/" .. icon) or icon)
		if named then t:SetVertexColor(Theme.Color("heading")) else t:SetVertexColor(1, 1, 1) end
	end,
	Restyle = function(self)
		local s = Theme.current.surface
		Theme.Paint(self.header, s.inset)
		Theme.Paint(self.nav, s.inset)
		self.banner:SetAlpha(0.35)
		if self.selected then self:SetHeaderIcon(self.selected.icon or self.opts.icon) end
	end,
}, function(self, opts)
	local m = Theme.current.metric
	local navWidth = opts.navWidth or 210
	-- header
	local header = FK.Frame("Frame", self)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(58)
	self.header = header
	self.banner = header:CreateTexture(nil, "BORDER")
	self.banner:SetPoint("TOPLEFT", 2, -2)
	self.banner:SetPoint("BOTTOMRIGHT", -2, 2)
	if opts.banner then self.banner:SetTexture(Theme.Resolve(opts.banner)) else self.banner:Hide() end
	header.icon = header:CreateTexture(nil, "ARTWORK")
	header.icon:SetSize(36, 36)
	header.icon:SetPoint("LEFT", 12, 0)
	header.title = self:Text("large", "heading", header)
	header.title:SetPoint("TOPLEFT", header.icon, "TOPRIGHT", 12, -1)
	header.title:SetPoint("RIGHT", -12, 0)
	header.title:SetJustifyH("LEFT")
	header.title:SetWordWrap(false)
	header.subtitle = self:Text("normal", "dim", header)
	header.subtitle:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -4)
	header.subtitle:SetPoint("RIGHT", -12, 0)
	header.subtitle:SetJustifyH("LEFT")
	header.subtitle:SetWordWrap(false)
	header.title:SetText(opts.title or "")
	header.subtitle:SetText(opts.subtitle or "")
	-- breadcrumb
	local crumb = CreateFrame("Frame", nil, self)
	crumb:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -6)
	crumb:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -2, -6)
	crumb:SetHeight(14)
	crumb.text = self:Text("small", "dim", crumb)
	crumb.text:SetAllPoints()
	crumb.text:SetJustifyH("LEFT")
	crumb.text:SetWordWrap(false)
	crumb:SetHyperlinksEnabled(true)
	crumb:SetScript("OnHyperlinkClick", function(_, link)
		local i = tonumber(link:match("^fk:crumb:(%d+)$"))
		if i == 0 then
			self.selected = nil
			self:Filter(self.search and self.search:GetValue() or "")
			if opts.onHome then opts.onHome() end
		elseif i and self.crumbs and self.crumbs[i] then
			self:Select(self.crumbs[i])
		end
	end)
	self.crumb = crumb
	-- navigation
	local nav = FK.Frame("Frame", self)
	nav:SetPoint("TOPLEFT", crumb, "BOTTOMLEFT", -2, -6)
	nav:SetPoint("BOTTOMLEFT")
	nav:SetWidth(navWidth)
	self.nav = nav
	local top = 4
	if opts.search ~= false then
		self.search = FK.SearchBox(nav, { points = { { "TOPLEFT", 4, -4 }, { "TOPRIGHT", -4, -4 } },
			onSearch = function(text) self:Filter(text) end })
		top = top + self.search:GetHeight() + 4
	end
	self.tree = FK.Tree(nav, { selectBranches = true, onSelect = function(node)
		self:Select(rawget(node, "original") or node)
	end })
	self.tree:SetPoint("TOPLEFT", 4, -top)
	self.tree:SetPoint("BOTTOMRIGHT", -4, 4)
	-- content
	local body = CreateFrame("Frame", nil, self)
	body:SetPoint("TOPLEFT", nav, "TOPRIGHT", m.gap + 4, 0)
	body:SetPoint("BOTTOMRIGHT")
	self.body = body
	self.pages = {}
	self.nodes = opts.nodes or {}
	self:Restyle()
	self:SetNodes(self.nodes)
	if opts.value ~= nil then self:Select(opts.value) end
end)
