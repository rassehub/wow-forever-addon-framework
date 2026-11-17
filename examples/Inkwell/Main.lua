local ADDON, ns = ...
local FK = ns.FK
local L = FK.L

-- Showcase: a personal wiki on the Journal kit. Pages are markup (RichText); [label](page:Title)
-- links to another page, and a link to a page that does not exist yet creates it. A title with
-- slashes ("Professions/Herbalism") files the page in folders. Pages are account-wide.

local WELCOME = [[
# Welcome to Inkwell
Your notes, written in a small markup and linked like a wiki. Open the **Edit** tab to change a page.

## Writing
- # Title, ## Section
- **bold** shows in the accent colour
- - bullets (indent two spaces for sub items)
- > a note on the side
- [another page](page:Professions/Herbalism) links; a page that does not exist yet is created
- :herb: :ore: :skull: :star: icons from the library's set

## Folders
A slash in the title files a page in a folder: Professions/Herbalism.
]]

local ui = FK.Copy(FK.AppearanceDefaults)
ui.theme = "parchment"
ns.db = FK:NewDB("InkwellDB", {
	profile = { ui = ui, window = {}, minimap = {} },
	global = { pages = { ["Welcome"] = { text = WELCOME } } },
})
FK:BindAppearance(ns.db, "profile.ui")

local history = {}

-- Pages as journal nodes: folders from the slashes in the titles, sorted by name.
function ns.Nodes()
	local root = { children = {} }
	local titles = {}
	for title in pairs(ns.db.global.pages) do titles[#titles + 1] = title end
	table.sort(titles, function(a, b) return a:lower() < b:lower() end)
	for _, title in ipairs(titles) do
		local parent, path = root, ""
		local parts = { strsplit("/", title) }
		for i = 1, #parts - 1 do
			path = path .. parts[i] .. "/"
			local folder
			for _, c in ipairs(parent.children) do if c.value == path then folder = c end end
			if not folder then
				folder = { label = parts[i], value = path, icon = "book", children = {}, expanded = true }
				table.insert(parent.children, 1, folder) -- folders before pages
			end
			parent = folder
		end
		parent.children[#parent.children + 1] = { label = parts[#parts], value = title, icon = "scroll", subtitle = #parts > 1 and path:sub(1, -2) or L["Page"] }
	end
	return root.children
end

function ns.Open(title, section)
	if not ns.db.global.pages[title] then
		ns.db.global.pages[title] = { text = "# " .. title:match("[^/]+$") .. "\n" }
		ns.journal:SetNodes(ns.Nodes())
		section = "edit"
	end
	local cur = ns.journal:GetSelected()
	if cur and cur.value ~= title and ns.db.global.pages[cur.value] then history[#history + 1] = cur.value end
	ns.journal:Select(title, section)
end

function ns.Back()
	local title = table.remove(history)
	if title and ns.db.global.pages[title] then ns.journal:Select(title, "read") end
end

function ns.Save(title, text)
	ns.db.global.pages[title].text = text
	ns.journal:Refresh()
	ns.journal:Select(title, "read")
end

function ns.Delete(title)
	ns.db.global.pages[title] = nil
	ns.journal:SetNodes(ns.Nodes())
	if next(ns.db.global.pages) then ns.Open(next(ns.db.global.pages)) end
end

local function render(page, node, section)
	if node.children then
		local lines = { "# " .. node.label, "" }
		for _, c in ipairs(node.children) do lines[#lines + 1] = ("- :%s: [%s](page:%s)"):format(c.icon, c.label, c.value) end
		return table.concat(lines, "\n")
	end
	local entry = ns.db.global.pages[node.value]
	if section ~= "edit" then return entry.text end
	local editor = FK.TextArea(page.content, { height = 300, value = entry.text })
	page:Add(editor)
	page:Add((FK.Build(page.content, { "Row", children = {
		{ "Button", text = L["Save"], onClick = function() ns.Save(node.value, editor:GetValue()) end },
		{ "Button", text = L["Delete page"], onClick = function()
			FK.Confirm(L["Delete the page '%s'?"]:format(node.value), function() ns.Delete(node.value) end)
		end },
	} })))
	page.editor = editor
end

FK:OnLogin(function()
	ns.window = FK.Window(UIParent, { title = "Inkwell", width = 780, height = 540, resizable = { minWidth = 560, minHeight = 380 },
		saved = { ns.db, "profile.window" }, buttons = {
			{ icon = "back", tooltip = L["Back"], onClick = ns.Back },
			{ icon = "plus", tooltip = L["New page"], onClick = function()
				FK.Prompt(L["Title of the new page (a slash files it in a folder)"], "", function(t)
					t = t and t:match("^%s*(.-)%s*$")
					if t and t ~= "" then ns.Open(t) end
				end)
			end },
		} })
	ns.journal = FK.Journal(ns.window.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, title = "Inkwell", icon = "scroll",
		home = L["Pages"], nodes = ns.Nodes(), render = render,
		sections = function(node) if not node.children then return { { id = "read", label = L["Read"] }, { id = "edit", label = L["Edit"] } } end end,
		onLink = function(target)
			local title = target:match("^page:(.+)$")
			if title then ns.Open(title, "read") end
		end })
	ns.journal:Select("Welcome")
	ns.minimap = FK.MinimapButton({ icon = "Interface\\Icons\\INV_Misc_Book_09", title = "Inkwell", saved = { ns.db, "profile.minimap" },
		tooltip = { "Inkwell", L["Click: open your pages."] }, onClick = function() ns.window:Toggle() end })
	FK:Slash({ "/ink", "/inkwell" }, function(msg)
		if msg ~= "" then ns.window:Open() return ns.Open(msg, "read") end
		ns.window:Toggle()
	end)
end)

function Inkwell_OnCompartmentClick() ns.window:Toggle() end
