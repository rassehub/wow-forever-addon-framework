-- Widgets II: lists, tables, trees, composite rows, navigation, dialogs, displays.
local KIT = ROOT .. "/tests/fixtures/KitTest"

local function kit(theme, w, h)
	local FK = H.Start(KIT).FK
	if theme then FK.Theme:Set(theme) end
	local win = FK.Window(UIParent, { title = "Test", width = w or 460, height = h or 420 })
	win:Open()
	H.Advance(0)
	return FK, win
end

local function countFrames() return #H.frames end

test("scroll list: 10 000 items use a bounded number of frames", function()
	local FK, win = kit()
	local items = {}
	for i = 1, 10000 do items[i] = "Item " .. i end
	local before = countFrames()
	local list = FK.ScrollList(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, items = items })
	H.Advance(0)
	list:Refresh()
	ok(countFrames() - before < 40, "frames created: " .. (countFrames() - before))
	eq(list.rows[1].text:GetText(), "Item 1")
	H.Wheel(list, -1)
	eq(list.rows[1].text:GetText(), "Item 4")
	list:ScrollToIndex(9999)
	ok(H.Find(list, "Item 10000"), "the end of the list is reachable")
	eq(H.LayoutIssues(win), {})
end)

test("scroll list: selection, click callback and scroll bar drag", function()
	local FK, win = kit()
	local items, clicked = {}, nil
	for i = 1, 100 do items[i] = { label = "Row " .. i } end
	local list = FK.ScrollList(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, items = items, selectable = true, onClick = function(item) clicked = item end })
	H.Advance(0)
	list:Refresh()
	H.Click(list.rows[3])
	eq(clicked, items[3])
	eq(list:GetSelected(), items[3])
	H.Drag(list.bar.thumb, 0, -list.bar:GetHeight())
	eq(list.rows[#list.rows].item, items[100])
end)

test("table: sorts by column, toggles direction, stable, formats cells", function()
	local FK, win = kit()
	local t = FK.Table(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, columns = {
		{ key = "name", label = "Name" },
		{ key = "price", label = "Price", width = 90, align = "RIGHT", format = function(v) return FK.Money(v, true) end },
	}, items = { { name = "Wool", price = 300 }, { name = "Linen", price = 120 }, { name = "Silk", price = 300 } } })
	H.Advance(0)
	t:Restyle()
	H.Click(t.headers[2])
	eq(t.list.rows[1].cells[1]:GetText(), "Linen")
	eq(t.list.rows[1].cells[2]:GetText(), "1s 20c")
	H.Click(t.headers[2])
	eq(t.list.rows[1].cells[1]:GetText(), "Wool", "descending keeps the original order of equal rows")
	eq(t.list.rows[3].cells[1]:GetText(), "Linen")
	local before = t.headers[1]:GetWidth()
	H.Drag(t.headers[1].grip, -60, 0)
	near(t.headers[1]:GetWidth(), before - 60, 1)
	eq(H.LayoutIssues(win), {})
end)

test("tree: branches fold, leaves select", function()
	local FK, win = kit()
	local picked
	local tree = FK.Tree(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, onSelect = function(n) picked = n.label end, nodes = {
		{ label = "Elwynn Forest", children = { { label = "Wolves Across the Border" }, { label = "Kobold Camp Cleanup" } } },
		{ label = "Westfall", expanded = true, children = { { label = "The Killing Fields" } } },
	} })
	H.Advance(0)
	tree.list:Refresh()
	eq(#tree.list:GetItems(), 3)
	H.Click(tree.list.rows[1])
	eq(#tree.list:GetItems(), 5)
	H.Click(tree.list.rows[2])
	eq(picked, "Wolves Across the Border")
	tree:CollapseAll()
	eq(#tree.list:GetItems(), 2)
end)

test("scroll area: tall content scrolls and stays clipped", function()
	local FK, win = kit()
	local area = FK.ScrollArea(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } } })
	area:Batch(function()
		for i = 1, 40 do area:Add(FK.CheckBox(area, { label = "Option " .. i })) end
	end)
	H.Advance(0)
	ok(area.bar:IsShown())
	eq(H.LayoutIssues(win), {})
	H.Wheel(area, -1)
	eq(area.scroll:GetVerticalScroll(), 40)
	area:ScrollTo(99999)
	ok(H.Find(area, "Option 40"):GetBottom() >= area:GetBottom() - 1)
end)

test("option row: the switch enables its slider", function()
	local FK, win = kit()
	local stack = FK.Stack(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } } })
	local toggled, value
	local row = stack:Add(FK.ToggleSliderRow(stack, { label = "Fade when idle", enabled = false, min = 0, max = 1, percent = true, value = 0.5,
		onToggle = function(on) toggled = on end, onChange = function(v) value = v end }))
	H.Advance(0)
	ok(not row.control:IsEnabled())
	H.Click(row.toggle.button)
	eq(toggled, true)
	ok(row.control:IsEnabled())
	H.Slide(row.control.slider, 0.8)
	eq(value, 0.8)
	eq(H.LayoutIssues(win), {})
end)

test("toggle list row: switching on unfolds the children and pushes later rows down", function()
	local FK, win = kit()
	local stack = FK.Stack(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } } })
	local row = stack:Add(FK.ToggleListRow(stack, { label = "Announce kills", desc = "Tell your group when a rare dies.", enabled = false, children = {
		{ "Dropdown", id = "channel", label = "Channel", items = { "Say", "Party", "Guild" }, value = "Party" },
		{ "Slider", id = "delay", label = "Delay", min = 0, max = 10, format = "%d s" },
	} }))
	local after = stack:Add(FK.CheckBox(stack, { label = "After" }))
	H.Advance(0)
	local collapsedTop = after:GetTop()
	ok(not row.body:IsShown())
	H.Click(row.toggle.button)
	H.Advance(0)
	ok(row.body:IsShown() and row.refs.delay:IsEnabled())
	ok(after:GetTop() < collapsedTop - 60, "the row below moved down")
	eq(H.LayoutIssues(win), {})
	H.Click(row.toggle.button)
	H.Advance(0)
	eq(after:GetTop(), collapsedTop)
end)

test("slider row and dropdown row place the control on the label's line", function()
	local FK, win = kit("vanilla")
	local stack = FK.Stack(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } } })
	local s = stack:Add(FK.SliderRow(stack, { label = "Window scale", min = 0.5, max = 1.5, step = 0.05, value = 1, live = false }))
	local d = stack:Add(FK.ToggleDropdownRow(stack, { label = "Play a sound", enabled = true, items = { "Bell", "Horn" }, value = "Bell" }))
	local c = stack:Add(FK.ToggleListRow(stack, { label = "Minimap button", enabled = true, cog = true, children = { { "Slider", label = "Angle", min = 0, max = 360 } } }))
	H.Advance(0)
	eq(s:GetValue(), 1)
	eq(d:GetValue(), "Bell")
	ok(not c.body:IsShown(), "a cog row stays folded until the cog is clicked")
	H.Click(c.arrow.button)
	ok(c.body:IsShown())
	eq(H.LayoutIssues(win), {})
end)

test("check list: toggling, all/none and filter", function()
	local FK, win = kit()
	local got
	local list = FK.CheckList(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, label = "Herbs", search = true,
		items = { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal" }, onChange = function(v) got = v end })
	H.Advance(0)
	list.list:Refresh()
	H.Click(list.list.rows[2])
	eq(got, { Silverleaf = true })
	H.Click(list.all.button)
	eq(got, { Peacebloom = true, Silverleaf = true, Earthroot = true, Mageroyal = true })
	list:Filter("root")
	H.Click(list.none.button)
	eq(got.Earthroot, nil)
	eq(got.Mageroyal, true, "None only clears what the filter shows")
	eq(H.LayoutIssues(win), {})
end)

test("reorder list: arrows move items, switches toggle them", function()
	local FK, win = kit()
	local order, toggles
	local list = FK.ReorderList(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, label = "Columns",
		items = { "Name", "Count", "Price" }, toggles = { Name = true, Count = true, Price = false },
		onChange = function(o, t) order, toggles = o, t end })
	H.Advance(0)
	list.list:Refresh()
	H.Click(list.list.rows[1].down.button)
	eq(order, { "Count", "Name", "Price" })
	ok(not list.list.rows[1].up:IsEnabled())
	H.Click(list.list.rows[3].toggle.button)
	eq(toggles.Price, true)
	eq(H.LayoutIssues(win), {})
end)

test("money input reads gold, silver and copper", function()
	local FK, win = kit()
	local got
	local m = FK.MoneyInput(win.content, { point = { "TOPLEFT" }, label = "Max price", value = 12345, onChange = function(v) got = v end })
	eq(m.silver:GetValue(), "23")
	H.Enter(m.gold.box, "5")
	H.Key("ENTER")
	eq(got, 52345)
	eq(H.LayoutIssues(win), {})
end)

test("tabs: pages build lazily and switch", function()
	for _, side in ipairs({ false, true }) do
		local FK, win = kit()
		local built = {}
		local tabs = FK.Tabs(win.content, { points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, side = side, tabs = {
			{ id = "a", label = "General", build = function(page) built.a = page FK.Label(page, { point = { "TOPLEFT" }, text = "Page A", width = 100 }):Fit() end },
			{ id = "b", label = "Appearance", build = function(page) built.b = page end },
		} })
		H.Advance(0)
		ok(built.a and not built.b)
		H.Click(tabs.buttons[2])
		ok(built.b:IsShown() and not built.a:IsShown())
		eq(tabs:GetValue(), "b")
		eq(H.LayoutIssues(win), {})
	end
end)

test("dialogs: confirm, prompt, cancel with escape", function()
	local FK = H.Start(KIT).FK
	local answer
	local d = FK.Confirm("Delete the goal list?", function() answer = "yes" end, function() answer = "no" end)
	H.Advance(0)
	eq(H.LayoutIssues(d), {})
	H.Click(H.Find(d, "Yes"):GetParent())
	eq(answer, "yes")
	FK.Confirm("Again?", function() answer = "yes" end, function() answer = "no" end)
	H.Key("ESCAPE")
	eq(answer, "no")
	local name
	d = FK.Prompt("Profile name", "Healer", function(text) name = text end)
	H.Advance(0)
	eq(H.LayoutIssues(d), {})
	H.Type("2")
	H.Click(H.Find(d, "Accept"):GetParent())
	eq(name, "Healer2")
end)

test("context menu opens at the cursor and runs the item", function()
	local FK = H.Start(KIT).FK
	local did
	FK.Menu({ { header = "Goal" }, { label = "Delete", onClick = function() did = "delete" end }, { divider = true }, { label = "Locked", disabled = true, onClick = function() did = "bad" end } })
	FK.Popup:Pick("Locked")
	eq(did, nil)
	FK.Popup:Pick("Delete")
	eq(did, "delete")
	ok(not FK.Popup.frame:IsShown())
end)

test("context menu: ticks and radios stay open and redraw; submenus cascade and close together", function()
	local FK = H.Start(KIT).FK
	local show, size, moved = { bags = true }, "small", nil
	FK.Menu({
		{ header = "Columns" },
		{ label = "Bags", checked = function() return show.bags end, onClick = function() show.bags = not show.bags end },
		{ label = "Small", radio = true, checked = function() return size == "small" end, onClick = function() size = "small" end },
		{ label = "Large", radio = true, checked = function() return size == "large" end, onClick = function() size = "large" end },
		{ label = "Move to", children = function()
			return { { label = "Bank", onClick = function() moved = "bank" end },
				{ label = "Deeper", children = { { label = "Vault", onClick = function() moved = "vault" end } } } }
		end },
	})
	local function row(level, label)
		for _, r in ipairs(level.rows) do if r:IsShown() and r.item.label == label then return r end end
	end
	ok(row(FK.Popup, "Bags").check:IsShown())
	FK.Popup:Pick("Bags")
	eq(show.bags, false)
	ok(FK.Popup.frame:IsShown(), "a tick keeps the menu open")
	ok(not row(FK.Popup, "Bags").check:IsShown(), "and the tick is redrawn")
	FK.Popup:Pick("Large")
	eq(size, "large")
	ok(row(FK.Popup, "Large").check:IsShown() and not row(FK.Popup, "Small").check:IsShown())
	H.Hover(row(FK.Popup, "Move to"))
	ok(FK.Popup.child.frame:IsShown(), "hovering a submenu row opens it")
	ok(FK.Popup.child.frame:GetLeft() >= FK.Popup.frame:GetRight(), "beside the menu")
	H.Hover(row(FK.Popup, "Bags"))
	ok(not FK.Popup.child.frame:IsShown(), "another row closes it")
	FK.Popup:Pick("Move to", "Deeper", "Vault")
	eq(moved, "vault")
	ok(not FK.Popup.frame:IsShown() and not FK.Popup.child.child.frame:IsVisible(), "a pick closes every level")
end)

test("context menu: built MenuUtil style, a tick box can carry its own submenu", function()
	local FK = H.Start(KIT).FK
	local on, picked = { herbs = true }, nil
	FK.Menu(function(m)
		m:Header("Nodes")
		local herbs = m:Check("Herbs", function() return on.herbs end, function() on.herbs = not on.herbs end)
		herbs:Item("Peacebloom", function() picked = "peacebloom" end)
		m:Item("More"):Radio("Big", function() return false end, function() picked = "big" end)
	end)
	FK.Popup:Pick("Herbs")
	eq(on.herbs, false) -- clicking the box ticks it...
	ok(FK.Popup.frame:IsShown())
	FK.Popup:Pick("Herbs", "Peacebloom") -- ...and its submenu still opens
	eq(picked, "peacebloom")
	FK.Menu(function(m) m:Item("More"):Radio("Big", function() return false end, function() picked = "big" end) end)
	FK.Popup:Pick("More", "Big")
	eq(picked, "big")
end)

test("toasts stack and expire", function()
	local FK = H.Start(KIT).FK
	local a = FK.Toast("First")
	local b = FK.Toast("Second", { duration = 10, color = "good" })
	ok(b:GetTop() < a:GetBottom())
	H.Advance(5)
	ok(not a:IsShown() and b:IsShown())
	eq(b:GetTop(), UIParent:GetTop() - 120)
end)

test("autocomplete suggests while typing and picks", function()
	local FK, win = kit()
	local picked
	local edit = FK.EditBox(win.content, { point = { "TOPLEFT" }, width = 200 })
	FK.Autocomplete(edit, { search = function(text)
		local out = {}
		for _, name in ipairs({ "Linen Cloth", "Linen Bandage", "Wool Cloth" }) do
			if name:lower():find(text:lower(), 1, true) then out[#out + 1] = { value = name, label = name } end
		end
		return out
	end, onPick = function(item) picked = item.value end })
	H.Click(edit.box)
	H.Type("lin")
	H.Advance(0.3)
	ok(FK.Popup.frame:IsShown())
	eq(#FK.Popup.items, 2)
	FK.Popup:Pick("Linen Bandage")
	eq(picked, "Linen Bandage")
	eq(edit:GetValue(), "Linen Bandage")
end)

test("timer bar counts down and finishes", function()
	local FK, win = kit()
	local done
	local bar = FK.TimerBar(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, label = "Auction ends", duration = 10, onFinish = function() done = true end })
	H.Advance(4)
	near(bar.bar:GetValue(), 6, 0.1)
	eq(bar.time:GetText(), "6.0")
	H.Advance(7)
	ok(done)
end)

test("bar list ranks by value", function()
	local FK, win = kit()
	local list = FK.BarList(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, height = 80 })
	list:SetItems({ { label = "Mage", value = 500 }, { label = "Rogue", value = 1500 }, { label = "Priest", value = 100 } })
	H.Advance(0)
	eq(list.rows[1].label:GetText(), "1. Rogue")
	eq(list.rows[1].value:GetText(), "1.5k")
	near(list.rows[2].bar:GetStatusBarTexture():GetWidth() / list.rows[1].bar:GetStatusBarTexture():GetWidth(), 1 / 3, 0.01)
	eq(H.LayoutIssues(win), {})
end)

test("icon grid wraps and shows item tooltips", function()
	local FK, win = kit()
	local items = {}
	for i = 1, 30 do items[i] = { icon = 134400, count = i, quality = i % 5, itemID = 2589 } end
	local grid = FK.IconGrid(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, items = items })
	H.Advance(0)
	ok(grid.buttons[30]:GetTop() < grid.buttons[1]:GetBottom(), "wrapped onto more rows")
	H.Hover(grid.buttons[2])
	eq(H.TooltipLines()[1], "Linen Cloth")
	eq(H.LayoutIssues(win), {})
end)

test("tracker: lines, progress, drag saves position, lock", function()
	local FK = H.Start(KIT).FK
	local db = FK:NewDB("KitTestDB", { profile = {} })
	local t = FK.Tracker(UIParent, { title = "Goals", saved = { db, "profile.tracker" } })
	t:SetLines({ { text = "Linen Cloth", value = "12/20", progress = 0.6 }, { text = "Wool Cloth", value = "done", color = "good" } })
	H.Advance(0)
	eq(H.LayoutIssues(t), {})
	H.Drag(t.head, -200, 50)
	eq(db.profile.tracker.point, "TOPLEFT")
	t:SetLocked(true)
	raises(function() H.Drag(t.head, 10, 10) end, "not mouse enabled")
end)

test("text area holds multi-line text", function()
	local FK, win = kit()
	local got
	local area = FK.TextArea(win.content, { points = { { "TOPLEFT" }, { "TOPRIGHT" } }, label = "Notes", onChange = function(v) got = v end })
	H.Advance(0)
	area:Focus()
	H.Type("line")
	area.box:ClearFocus()
	eq(got, "line")
end)

for _, theme in ipairs({ "pixel", "vanilla" }) do
	test(theme .. ": a settings page of composite rows has no layout issues", function()
		local FK, win = kit(theme, 520, 560)
		local _, refs = FK.Build(win.content, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, children = {
			{ "Heading", text = "Tracker" },
			{ "ToggleRow", label = "Show the tracker", desc = "A small window with your active goals.", value = true },
			{ "SliderRow", label = "Scale", min = 0.5, max = 1.5, step = 0.05, value = 1 },
			{ "ToggleSliderRow", label = "Fade out of combat", enabled = true, min = 0, max = 1, percent = true, value = 0.4 },
			{ "ToggleDropdownRow", label = "Announce completion", enabled = false, items = { "Say", "Party", "Guild" }, value = "Party" },
			{ "ToggleListRow", id = "list", label = "Sounds", enabled = true, children = {
				{ "Dropdown", label = "Sound", items = { "Bell", "Horn" }, value = "Bell" },
				{ "Slider", label = "Volume", min = 0, max = 1, percent = true, value = 1 },
			} },
			{ "Heading", text = "Lists" },
			{ "ReorderList", label = "Column order", items = { "Name", "Count", "Price" }, toggles = {} },
			{ "CheckList", label = "Tracked herbs", items = { "Peacebloom", "Silverleaf", "Earthroot" }, height = 120 },
		} })
		H.Advance(0)
		eq(H.LayoutIssues(win), {})
		eq(FK.warnings, {})
		ok(refs.list.body:IsShown())
	end)
end
