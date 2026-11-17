local _, ns = ...
local FK = ns.FK

-- Charcoal panels with thin bevelled metal edges, gold headings and dark red buttons: the look of
-- the client's own modern Settings window, built from the library's art (Media/Frames).

local GOLD = { 1, 0.82, 0 }
local METAL = "media:Frames/metal"
local BUTTON = "media:Frames/button"
local PILL = "media:Frames/pill"
local LINE = { 0.32, 0.32, 0.35, 1 }

FK.Theme.Register("modern", {
	extends = "base",
	label = "Modern",
	color = {
		text = { 0.93, 0.93, 0.93 }, dim = { 0.66, 0.66, 0.7 }, disabled = { 0.45, 0.45, 0.47 },
		heading = GOLD, title = GOLD, accent = GOLD, buttonText = GOLD, link = { 0.45, 0.72, 1 },
		divider = { 1, 1, 1, 0.1 },
	},
	font = {
		heading = { "GameFontNormal", color = "heading" },
		title = { "GameFontNormal", color = "title" },
		button = { "GameFontNormal", color = "buttonText" },
	},
	surface = {
		window = { nineslice = METAL, size = 14, bg = { 0.1, 0.1, 0.11, 0.97 }, inset = 3 },
		titlebar = { bg = { 1, 1, 1, 0.045 } },
		panel = { bg = { 1, 1, 1, 0.03 }, border = { 1, 1, 1, 0.08 } },
		inset = { bg = { 0, 0, 0, 0.35 }, border = { 1, 1, 1, 0.08 } },
		menu = { nineslice = METAL, size = 12, bg = { 0.08, 0.08, 0.09, 0.98 }, inset = 3 },
		button = {
			normal = { nineslice = BUTTON, size = 8, color = { 0.5, 0.07, 0.05, 1 } },
			hover = { nineslice = BUTTON, size = 8, color = { 0.66, 0.11, 0.07, 1 } },
			pressed = { nineslice = BUTTON, size = 8, color = { 0.38, 0.05, 0.03, 1 } },
			disabled = { nineslice = BUTTON, size = 8, color = { 0.3, 0.3, 0.31, 1 } },
		},
		input = {
			normal = { bg = { 0.04, 0.04, 0.05, 1 }, border = LINE },
			focus = { bg = { 0.04, 0.04, 0.05, 1 }, border = GOLD },
			disabled = { bg = { 0.1, 0.1, 0.1, 1 }, border = { 0.2, 0.2, 0.2, 1 } },
		},
		check = {
			normal = { bg = { 0.04, 0.04, 0.05, 1 }, border = LINE },
			hover = { bg = { 0.04, 0.04, 0.05, 1 }, border = GOLD },
			disabled = { bg = { 0.1, 0.1, 0.1, 1 }, border = { 0.2, 0.2, 0.2, 1 } },
		},
		radio = {
			normal = { nineslice = PILL, size = 8, color = { 0.3, 0.3, 0.32, 1 } },
			hover = { nineslice = PILL, size = 8, color = { 0.5, 0.42, 0.15, 1 } },
			disabled = { nineslice = PILL, size = 8, color = { 0.18, 0.18, 0.18, 1 } },
		},
		checkMark = { bg = GOLD, inset = 3 },
		radioMark = { texture = PILL, color = GOLD, inset = 4 },
		toggle = {
			off = { nineslice = PILL, size = 8, color = { 0.24, 0.24, 0.26, 1 } },
			on = { nineslice = PILL, size = 8, color = { 0.72, 0.55, 0.08, 1 } },
		},
		knob = { texture = PILL, color = { 0.95, 0.95, 0.95, 1 } },
		track = { nineslice = PILL, size = 3, color = { 0.04, 0.04, 0.05, 1 } },
		fill = { bg = GOLD },
		thumb = { normal = { texture = PILL, color = { 0.85, 0.85, 0.85, 1 } }, hover = { texture = PILL, color = { 1, 1, 1, 1 } }, disabled = { texture = PILL, color = { 0.35, 0.35, 0.35, 1 } } },
		tab = {
			normal = { nineslice = BUTTON, size = 8, color = { 0.2, 0.2, 0.22, 1 } },
			hover = { nineslice = BUTTON, size = 8, color = { 0.28, 0.28, 0.3, 1 } },
			selected = { nineslice = BUTTON, size = 8, color = { 0.42, 0.34, 0.12, 1 } },
		},
		row = {
			hover = { bg = { 1, 1, 1, 0.07 } },
			selected = { bg = { 1, 0.82, 0, 0.16 } },
			alt = { bg = { 1, 1, 1, 0.025 } },
		},
		scrollTrack = { bg = { 0, 0, 0, 0.25 } },
		scrollThumb = { normal = { nineslice = PILL, size = 4, color = { 0.4, 0.4, 0.42, 1 } }, hover = { nineslice = PILL, size = 4, color = { 0.6, 0.6, 0.62, 1 } } },
		bar = { texture = "Interface\\Buttons\\WHITE8X8" },
		barBackground = { bg = { 0, 0, 0, 0.45 } },
	},
	icon = FK.Theme.MediaIconSet("dim"),
	metric = { pad = 14, gap = 8, row = 24, control = 24, title = 30, tab = 26, windowInset = { 3, 3, 3, 3 } },
})
