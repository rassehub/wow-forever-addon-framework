local _, ns = ...
local FK = ns.FK

-- Translucent dark-blue panels with thin light edges: the game world shows through.
-- Flat colours only, so it needs no texture files.

local EDGE = { 1, 1, 1, 0.18 }
local ACCENT = { 0.45, 0.85, 1 }
local SOFT = { 1, 1, 1, 0.08 }

FK.Theme.Register("glass", {
	extends = "base",
	label = "Glass (translucent)",
	color = {
		text = { 0.93, 0.96, 1 }, dim = { 0.66, 0.74, 0.82 }, heading = ACCENT, title = { 1, 1, 1 },
		accent = ACCENT, link = ACCENT, divider = { 1, 1, 1, 0.14 },
	},
	surface = {
		window = { bg = { 0.04, 0.08, 0.14, 0.72 }, border = EDGE },
		titlebar = { bg = { 1, 1, 1, 0.06 } },
		panel = { bg = { 1, 1, 1, 0.05 }, border = { 1, 1, 1, 0.1 } },
		inset = { bg = { 0, 0, 0, 0.25 }, border = { 1, 1, 1, 0.1 } },
		menu = { bg = { 0.05, 0.1, 0.17, 0.94 }, border = EDGE },
		button = {
			normal = { bg = { 1, 1, 1, 0.1 }, border = EDGE },
			hover = { bg = { 1, 1, 1, 0.18 }, border = ACCENT },
			pressed = { bg = { 1, 1, 1, 0.05 }, border = ACCENT },
			disabled = { bg = { 1, 1, 1, 0.04 }, border = SOFT },
		},
		input = {
			normal = { bg = { 0, 0, 0, 0.3 }, border = EDGE },
			focus = { bg = { 0, 0, 0, 0.4 }, border = ACCENT },
			disabled = { bg = { 0, 0, 0, 0.15 }, border = SOFT },
		},
		check = {
			normal = { bg = { 0, 0, 0, 0.3 }, border = EDGE },
			hover = { bg = { 0, 0, 0, 0.3 }, border = ACCENT },
			disabled = { bg = { 0, 0, 0, 0.15 }, border = SOFT },
		},
		radio = {
			normal = { bg = { 0, 0, 0, 0.3 }, border = EDGE },
			hover = { bg = { 0, 0, 0, 0.3 }, border = ACCENT },
			disabled = { bg = { 0, 0, 0, 0.15 }, border = SOFT },
		},
		toggle = {
			off = { bg = { 0, 0, 0, 0.3 }, border = EDGE },
			on = { bg = { ACCENT[1], ACCENT[2], ACCENT[3], 0.45 }, border = ACCENT },
		},
		knob = { bg = { 1, 1, 1, 0.95 } },
		track = { bg = { 0, 0, 0, 0.35 }, border = SOFT },
		tab = {
			normal = { bg = { 1, 1, 1, 0.04 }, border = SOFT },
			hover = { bg = { 1, 1, 1, 0.1 }, border = EDGE },
			selected = { bg = { 1, 1, 1, 0.16 }, border = ACCENT },
		},
		row = {
			hover = { bg = { 1, 1, 1, 0.08 } },
			selected = { bg = { ACCENT[1], ACCENT[2], ACCENT[3], 0.22 } },
			alt = { bg = { 1, 1, 1, 0.025 } },
		},
		scrollTrack = { bg = { 0, 0, 0, 0.2 } },
		scrollThumb = { normal = { bg = { 1, 1, 1, 0.25 } }, hover = { bg = { 1, 1, 1, 0.45 } } },
		barBackground = { bg = { 0, 0, 0, 0.3 } },
	},
	icon = FK.Theme.MediaIconSet("dim"),
	metric = { pad = 12, gap = 7, row = 24, control = 24, title = 28 },
})
