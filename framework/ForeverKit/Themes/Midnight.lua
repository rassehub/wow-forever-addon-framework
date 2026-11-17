local _, ns = ...
local FK = ns.FK

-- Deep blue-black glass with soft rounded edges and a violet glow accent: a contemporary,
-- non-Blizzard look for trackers, journals and maps. Built from the library's art (Media/Frames).

local ACCENT = { 0.62, 0.52, 1 }
local SOFT = "media:Frames/soft"
local BUTTON = "media:Frames/button"
local PILL = "media:Frames/pill"

FK.Theme.Register("midnight", {
	extends = "base",
	label = "Midnight",
	color = {
		text = { 0.9, 0.92, 1 }, dim = { 0.6, 0.63, 0.78 }, disabled = { 0.4, 0.42, 0.5 },
		heading = { 0.8, 0.74, 1 }, title = { 1, 1, 1 }, accent = ACCENT, buttonText = { 1, 1, 1 },
		link = { 0.55, 0.8, 1 }, divider = { 0.62, 0.52, 1, 0.18 },
	},
	surface = {
		window = { nineslice = SOFT, size = 16, bg = { 0.04, 0.05, 0.1, 0.9 }, inset = 6 },
		titlebar = false,
		panel = { nineslice = SOFT, size = 12, bg = { 1, 1, 1, 0.03 }, inset = 6, color = { 1, 1, 1, 0.6 } },
		inset = { bg = { 0, 0, 0, 0.3 } },
		menu = { nineslice = SOFT, size = 16, bg = { 0.06, 0.07, 0.13, 0.98 }, inset = 6 },
		button = {
			normal = { nineslice = PILL, size = 10, color = { 0.24, 0.2, 0.46, 1 } },
			hover = { nineslice = PILL, size = 10, color = { 0.36, 0.3, 0.66, 1 } },
			pressed = { nineslice = PILL, size = 10, color = { 0.18, 0.15, 0.36, 1 } },
			disabled = { nineslice = PILL, size = 10, color = { 0.16, 0.17, 0.22, 1 } },
		},
		input = {
			normal = { nineslice = PILL, size = 8, color = { 0.09, 0.1, 0.17, 1 } },
			focus = { nineslice = PILL, size = 8, color = { 0.14, 0.13, 0.27, 1 } },
			disabled = { nineslice = PILL, size = 8, color = { 0.07, 0.07, 0.1, 1 } },
		},
		check = {
			normal = { nineslice = PILL, size = 5, color = { 0.16, 0.17, 0.28, 1 } },
			hover = { nineslice = PILL, size = 5, color = { 0.28, 0.25, 0.5, 1 } },
			disabled = { nineslice = PILL, size = 5, color = { 0.1, 0.1, 0.14, 1 } },
		},
		radio = {
			normal = { nineslice = PILL, size = 8, color = { 0.16, 0.17, 0.28, 1 } },
			hover = { nineslice = PILL, size = 8, color = { 0.28, 0.25, 0.5, 1 } },
			disabled = { nineslice = PILL, size = 8, color = { 0.1, 0.1, 0.14, 1 } },
		},
		checkMark = { texture = "media:Icons/check", color = ACCENT, inset = 1 },
		radioMark = { texture = PILL, color = ACCENT, inset = 5 },
		toggle = {
			off = { nineslice = PILL, size = 8, color = { 0.16, 0.17, 0.28, 1 } },
			on = { nineslice = PILL, size = 8, color = { 0.45, 0.36, 0.9, 1 } },
		},
		knob = { texture = PILL, color = { 1, 1, 1, 1 } },
		track = { nineslice = PILL, size = 3, color = { 0.13, 0.14, 0.24, 1 } },
		fill = { bg = ACCENT },
		thumb = { normal = { texture = PILL, color = { 0.85, 0.82, 1, 1 } }, hover = { texture = PILL, color = { 1, 1, 1, 1 } }, disabled = { texture = PILL, color = { 0.35, 0.35, 0.42, 1 } } },
		tab = {
			normal = { nineslice = PILL, size = 10, color = { 0.1, 0.11, 0.19, 1 } },
			hover = { nineslice = PILL, size = 10, color = { 0.17, 0.16, 0.3, 1 } },
			selected = { nineslice = PILL, size = 10, color = { 0.3, 0.25, 0.6, 1 } },
		},
		row = {
			hover = { bg = { 0.62, 0.52, 1, 0.1 } },
			selected = { bg = { 0.62, 0.52, 1, 0.24 } },
			alt = { bg = { 1, 1, 1, 0.02 } },
		},
		scrollTrack = { bg = { 1, 1, 1, 0.03 } },
		scrollThumb = { normal = { nineslice = PILL, size = 4, color = { 0.3, 0.28, 0.5, 1 } }, hover = { nineslice = PILL, size = 4, color = { 0.5, 0.44, 0.85, 1 } } },
		barBackground = { bg = { 1, 1, 1, 0.05 } },
	},
	icon = FK.Theme.MediaIconSet("dim"),
	metric = { pad = 16, gap = 8, row = 26, control = 26, title = 32, tab = 28, windowInset = { 6, 6, 6, 6 } },
})
