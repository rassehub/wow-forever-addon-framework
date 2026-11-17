local _, ns = ...
local FK = ns.FK

-- Light paper with dark brown ink, tan leather controls and red accents, like a quest log page.
-- The paper is a flat colour (no texture file to go missing); edges reuse the tooltip border.

local INK = { 0.24, 0.15, 0.07 }
local RED = { 0.55, 0.12, 0.05 }
local BROWN = { 0.42, 0.28, 0.13, 1 }
local EDGE = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local THIN = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local PAPER = { 0.87, 0.79, 0.62, 1 }
local SHADE = { 0.78, 0.68, 0.5, 1 }

FK.Theme.Register("parchment", {
	extends = "base",
	label = "Parchment",
	color = {
		text = INK, dim = { 0.43, 0.33, 0.2 }, disabled = { 0.6, 0.53, 0.42 },
		heading = RED, title = RED, accent = RED, buttonText = INK, link = { 0.1, 0.25, 0.55 },
		good = { 0.1, 0.45, 0.1 }, bad = { 0.7, 0.08, 0.05 }, warn = { 0.65, 0.35, 0 },
		divider = { 0.4, 0.27, 0.12, 0.35 },
	},
	font = { -- no drop shadow: dark ink on light paper
		normal = { "GameFontHighlight", shadow = false },
		small = { "GameFontHighlightSmall", shadow = false },
		heading = { "GameFontNormal", color = "heading", shadow = false },
		large = { "GameFontNormalLarge", color = "heading", shadow = false },
		title = { "GameFontNormal", color = "title", shadow = false },
		button = { "GameFontHighlight", color = "buttonText", shadow = false },
		number = { "GameFontHighlightSmall", shadow = false },
	},
	surface = {
		window = { backdrop = EDGE, bg = PAPER, border = BROWN },
		titlebar = false,
		panel = { backdrop = THIN, bg = { 0.4, 0.27, 0.12, 0.08 }, border = BROWN },
		inset = { backdrop = THIN, bg = { 0.4, 0.27, 0.12, 0.14 }, border = BROWN },
		menu = { backdrop = EDGE, bg = { 0.92, 0.85, 0.7, 1 }, border = BROWN },
		button = {
			normal = { backdrop = THIN, bg = { 0.76, 0.62, 0.4, 1 }, border = BROWN },
			hover = { backdrop = THIN, bg = { 0.84, 0.71, 0.49, 1 }, border = RED },
			pressed = { backdrop = THIN, bg = { 0.68, 0.54, 0.34, 1 }, border = RED },
			disabled = { backdrop = THIN, bg = SHADE, border = BROWN },
		},
		input = {
			normal = { backdrop = THIN, bg = { 1, 0.97, 0.88, 0.7 }, border = BROWN },
			focus = { backdrop = THIN, bg = { 1, 0.97, 0.88, 0.9 }, border = RED },
			disabled = { backdrop = THIN, bg = SHADE, border = BROWN },
		},
		check = {
			normal = { bg = { 1, 0.97, 0.88, 0.7 }, border = BROWN },
			hover = { bg = { 1, 0.97, 0.88, 0.9 }, border = RED },
			disabled = { bg = SHADE, border = BROWN },
		},
		radio = {
			normal = { bg = { 1, 0.97, 0.88, 0.7 }, border = BROWN },
			hover = { bg = { 1, 0.97, 0.88, 0.9 }, border = RED },
			disabled = { bg = SHADE, border = BROWN },
		},
		checkMark = { bg = RED, inset = 3 },
		radioMark = { bg = RED, inset = 4 },
		toggle = {
			off = { bg = SHADE, border = BROWN },
			on = { bg = { 0.55, 0.12, 0.05, 0.85 }, border = { 0.3, 0.06, 0.02, 1 } },
		},
		knob = { bg = { 1, 0.96, 0.85, 1 } },
		track = { bg = SHADE, border = BROWN },
		fill = { bg = RED },
		thumb = {
			normal = { bg = { 0.42, 0.26, 0.12, 1 } },
			hover = { bg = { 0.55, 0.12, 0.05, 1 } },
			disabled = { bg = { 0.6, 0.53, 0.42, 1 } },
		},
		tab = {
			normal = { backdrop = THIN, bg = SHADE, border = BROWN },
			hover = { backdrop = THIN, bg = { 0.92, 0.85, 0.7, 1 }, border = BROWN },
			selected = { backdrop = THIN, bg = { 0.96, 0.9, 0.76, 1 }, border = RED },
		},
		row = {
			hover = { bg = { 0.4, 0.27, 0.12, 0.12 } },
			selected = { bg = { 0.55, 0.12, 0.05, 0.18 } },
			alt = { bg = { 0.4, 0.27, 0.12, 0.05 } },
		},
		scrollTrack = { bg = { 0.4, 0.27, 0.12, 0.12 } },
		scrollThumb = { normal = { bg = { 0.42, 0.26, 0.12, 0.8 } }, hover = { bg = { 0.55, 0.12, 0.05, 1 } } },
		barBackground = { bg = { 0.4, 0.27, 0.12, 0.2 } },
	},
	icon = FK.Theme.MediaIconSet("dim"),
	metric = { pad = 12, gap = 7, windowInset = { 4, 4, 4, 4 } },
})
