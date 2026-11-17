local _, ns = ...
local FK = ns.FK

-- The complete token set, with flat dark values. Every other theme extends this one and
-- overrides only what differs, so this file is also the reference of what a theme can set.

local ACCENT = { 0.25, 0.62, 1 }
local BLACK = { 0, 0, 0, 1 }
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"

-- The theme icon names widgets use, drawn with the library's own icon set (Media/Icons) and
-- tinted with `tint` (a colour role). Themes that want the modern look use this as their icons.
function FK.Theme.MediaIconSet(tint)
	local function m(name, size) return { texture = "media:Icons/" .. name, tint = tint or "text", size = size } end
	return {
		close = m("close", 14), arrowRight = m("arrow-right"), arrowDown = m("arrow-down"), arrowUp = m("arrow-up"),
		arrowLeft = m("arrow-left"), plus = m("plus"), minus = m("minus"), cog = m("cog"), search = m("search"),
		grip = m("grip"), handle = m("handle"),
	}
end

FK.Theme.Register("base", {
	abstract = true,
	color = {
		text = { 0.9, 0.9, 0.9 }, dim = { 0.62, 0.62, 0.62 }, disabled = { 0.42, 0.42, 0.42 },
		heading = { 1, 1, 1 }, title = { 1, 1, 1 }, accent = ACCENT, buttonText = { 0.92, 0.92, 0.92 },
		good = { 0.3, 0.9, 0.35 }, bad = { 1, 0.3, 0.3 }, warn = { 1, 0.65, 0.15 }, link = { 0.45, 0.72, 1 },
		divider = { 1, 1, 1, 0.12 },
	},
	font = {
		normal = { "GameFontHighlight" },
		small = { "GameFontHighlightSmall" },
		heading = { "GameFontNormal", color = "heading" },
		large = { "GameFontNormalLarge", color = "heading" },
		title = { "GameFontNormal", color = "title" },
		button = { "GameFontHighlight", color = "buttonText" },
		number = { "GameFontHighlightSmall" },
	},
	surface = {
		window = { bg = { 0.07, 0.07, 0.08, 0.96 }, border = BLACK },
		titlebar = { bg = { 0.13, 0.13, 0.15, 1 } }, -- strip behind the title; false for none
		plaque = false,                             -- vanilla's title plaque texture
		panel = { bg = { 1, 1, 1, 0.035 }, border = BLACK },
		inset = { bg = { 0, 0, 0, 0.35 }, border = BLACK },
		menu = { bg = { 0.1, 0.1, 0.11, 0.98 }, border = BLACK },
		button = {
			normal = { bg = { 0.19, 0.19, 0.21, 1 }, border = BLACK },
			hover = { bg = { 0.26, 0.26, 0.29, 1 }, border = ACCENT },
			pressed = { bg = { 0.13, 0.13, 0.15, 1 }, border = ACCENT },
			disabled = { bg = { 0.14, 0.14, 0.15, 1 }, border = BLACK },
			highlight = false, -- additive overlay while hovered
		},
		input = {
			normal = { bg = { 0.04, 0.04, 0.05, 1 }, border = BLACK },
			focus = { bg = { 0.04, 0.04, 0.05, 1 }, border = ACCENT },
			disabled = { bg = { 0.1, 0.1, 0.1, 1 }, border = BLACK },
		},
		check = {
			normal = { bg = { 0.04, 0.04, 0.05, 1 }, border = BLACK },
			hover = { bg = { 0.04, 0.04, 0.05, 1 }, border = ACCENT },
			disabled = { bg = { 0.1, 0.1, 0.1, 1 }, border = BLACK },
			highlight = false,
		},
		radio = {
			normal = { bg = { 0.04, 0.04, 0.05, 1 }, border = BLACK },
			hover = { bg = { 0.04, 0.04, 0.05, 1 }, border = ACCENT },
			disabled = { bg = { 0.1, 0.1, 0.1, 1 }, border = BLACK },
			highlight = false,
		},
		checkMark = { bg = ACCENT, inset = 3 },
		radioMark = { bg = ACCENT, inset = 4 },
		toggle = {
			off = { bg = { 0.04, 0.04, 0.05, 1 }, border = BLACK },
			on = { bg = { 0.12, 0.3, 0.5, 1 }, border = BLACK },
		},
		knob = { bg = { 0.82, 0.82, 0.82, 1 } },
		track = { bg = { 0.04, 0.04, 0.05, 1 }, border = BLACK },
		fill = { bg = ACCENT }, -- false: no fill (vanilla sliders)
		thumb = {
			normal = { bg = { 0.75, 0.75, 0.75, 1 } },
			hover = { bg = { 1, 1, 1, 1 } },
			disabled = { bg = { 0.35, 0.35, 0.35, 1 } },
		},
		tab = {
			normal = { bg = { 0.12, 0.12, 0.13, 1 }, border = BLACK },
			hover = { bg = { 0.2, 0.2, 0.22, 1 }, border = BLACK },
			selected = { bg = { 0.24, 0.24, 0.27, 1 }, border = ACCENT },
		},
		row = {
			hover = { bg = { 1, 1, 1, 0.08 } },
			selected = { bg = { ACCENT[1], ACCENT[2], ACCENT[3], 0.25 } },
			alt = { bg = { 1, 1, 1, 0.03 } },
		},
		scrollTrack = { bg = { 0, 0, 0, 0.3 } },
		scrollThumb = { normal = { bg = { 0.36, 0.36, 0.4, 1 } }, hover = { bg = { 0.55, 0.55, 0.6, 1 } } },
		bar = { texture = "Interface\\Buttons\\WHITE8X8" }, -- status bar fill
		barBackground = { bg = { 0, 0, 0, 0.45 } },
	},
	icon = {
		close = { text = "x", font = "normal" },
		arrowRight = { texture = ARROW },
		arrowDown = { texture = ARROW, rotation = -math.pi / 2 },
		arrowUp = { texture = ARROW, rotation = math.pi / 2 },
		arrowLeft = { texture = ARROW, rotation = math.pi },
		plus = { text = "+", font = "normal" },
		minus = { text = "-", font = "normal" },
		cog = { texture = "Interface\\Buttons\\UI-OptionsButton" },
		search = { texture = "Interface\\Common\\UI-Searchbox-Icon" },
		grip = { texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" },
		handle = { text = "=", font = "small", color = "dim" },
	},
	metric = {
		pad = 10,        -- inner padding of windows and panels
		gap = 6,         -- space between stacked controls
		row = 22,        -- list row height
		control = 22,    -- height of buttons, inputs, dropdowns
		title = 26,      -- title bar height
		icon = 14,
		check = 16,
		radio = 16,
		toggleWidth = 30,
		slider = 6,      -- track thickness
		thumbWidth = 10, thumbHeight = 16,
		scroll = 10,     -- scroll bar width
		tab = 24,
		buttonPad = 12,  -- horizontal padding around button text
		windowInset = { 1, 1, 1, 1 }, -- left, right, top, bottom border thickness of the window surface
	},
})
