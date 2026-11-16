-- The in-game half of the live loop (tools/FKDev), run in the emulator with FKGallery's dev tests.
local FKDEV, GALLERY = ROOT .. "/tools/FKDev", ROOT .. "/examples/FKGallery"

local function boot(queue)
	H.LoadAddon(FKDEV)
	if queue then rawset(_G, "FKDEV_QUEUE", queue) end
	return H.Start(GALLERY)
end

test("fkdev: runs registered tests, records errors, runs the queue once", function()
	H.missingFiles = { ["Interface\\Minimap\\ObjectIcons"] = true }
	local q = { id = "q1", lua = { "return 1 + 1", "error('queued failure')", "C_Timer.After(0, function() error('FKDev deliberate error') end)" }, tree = "Minimap", shot = true }
	local ns = boot(q)
	H.Advance(3)
	local s = FKDevDB.sessions[1]
	local byName = {}
	for _, t in ipairs(s.tests) do byName[t.name] = t end
	ok(byName["every theme switches without errors and keeps the window on screen"].ok)
	ok(byName["client APIs the feature modules rely on exist"].ok)
	ok(byName["the minimap button sits on the minimap edge"].ok)
	local tex = byName["every texture path in themes and features exists"]
	ok(not tex.ok and tex.failures[1]:find("ObjectIcons"), "a missing file is reported")
	eq(s.run.outputs[1].returns, { "2" })
	ok(s.run.outputs[2].error:find("queued failure"))
	ok(s.errors[1] and s.errors[1].message:find("FKDev deliberate error"), "global error handler caught it")
	ok(s.run.tree[1]:find("^Frame Minimap"))
	eq(H.screenshots, 1)
	ok(FKDevDB.done.q1)
	-- after the reload the same queue does not run again
	H.Reload()
	H.Advance(2)
	ok(FKDevDB.sessions[1].run == nil)
	eq(#FKDevDB.sessions, 2)
	H.missingFiles = nil
end)
