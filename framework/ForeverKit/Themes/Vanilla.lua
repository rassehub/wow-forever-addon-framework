local _, ns = ...
local FK = ns.FK

-- The 2004 interface: gold dialog borders, title plaque, red buttons, yellow headings.
-- Built only from texture files that have shipped with the client since the beginning.

local GOLD = { 1, 0.82, 0 }
local BTN = { 0, 0.625, 0, 0.6875 } -- the used part of the 128x32 panel button textures
local DIALOG = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local TOOLTIP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local THIN = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local SLIDER = {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 },
}
local GREY = { 0.6, 0.6, 0.6, 1 }

FK.Theme.Register("vanilla", {
	extends = "base",
	label = "Vanilla",
	color = {
		text = { 1, 1, 1 }, dim = { 0.75, 0.75, 0.75 }, disabled = { 0.5, 0.5, 0.5 },
		heading = GOLD, title = GOLD, accent = GOLD, buttonText = GOLD,
		good = { 0.1, 1, 0.1 }, bad = { 1, 0.1, 0.1 }, divider = { 1, 0.82, 0, 0.25 },
	},
	font = {
		heading = { "GameFontNormal", color = "heading" },
		title = { "GameFontNormal", color = "title" },
		button = { "GameFontNormal", color = "buttonText" },
	},
	surface = {
		window = { backdrop = DIALOG, bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 } },
		titlebar = false,
		plaque = { texture = "Interface\\DialogFrame\\UI-DialogBox-Header", width = 300, height = 64, offset = 12, titleOffset = -2 },
		panel = { backdrop = TOOLTIP, bg = { 0, 0, 0, 0.4 }, border = GREY },
		inset = { backdrop = TOOLTIP, bg = { 0, 0, 0, 0.6 }, border = GREY },
		menu = { backdrop = TOOLTIP, bg = { 0.05, 0.05, 0.05, 1 }, border = { 1, 1, 1, 1 } },
		button = {
			normal = { texture = "Interface\\Buttons\\UI-Panel-Button-Up", coords = BTN },
			hover = { texture = "Interface\\Buttons\\UI-Panel-Button-Up", coords = BTN },
			pressed = { texture = "Interface\\Buttons\\UI-Panel-Button-Down", coords = BTN },
			disabled = { texture = "Interface\\Buttons\\UI-Panel-Button-Disabled", coords = BTN },
			highlight = { texture = "Interface\\Buttons\\UI-Panel-Button-Highlight", coords = BTN, blend = "ADD" },
		},
		input = {
			normal = { backdrop = THIN, bg = { 0, 0, 0, 0.7 }, border = GREY },
			focus = { backdrop = THIN, bg = { 0, 0, 0, 0.7 }, border = GOLD },
			disabled = { backdrop = THIN, bg = { 0.2, 0.2, 0.2, 0.5 }, border = { 0.4, 0.4, 0.4, 1 } },
		},
		check = {
			normal = { texture = "Interface\\Buttons\\UI-CheckBox-Up" },
			hover = { texture = "Interface\\Buttons\\UI-CheckBox-Up" },
			disabled = { texture = "Interface\\Buttons\\UI-CheckBox-Up", color = { 0.5, 0.5, 0.5, 1 } },
			highlight = { texture = "Interface\\Buttons\\UI-CheckBox-Highlight", blend = "ADD" },
		},
		checkMark = { texture = "Interface\\Buttons\\UI-CheckBox-Check", inset = 0 },
		radioMark = { texture = "Interface\\Buttons\\UI-RadioButton", coords = { 0.25, 0.5, 0, 1 }, inset = 2 },
		toggle = {
			off = { backdrop = THIN, bg = { 0, 0, 0, 0.7 }, border = GREY },
			on = { backdrop = THIN, bg = { 0.45, 0.33, 0, 0.9 }, border = GOLD },
		},
		knob = { texture = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal", coords = { 0.2, 0.8, 0.2, 0.8 } },
		track = { backdrop = SLIDER, bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 } },
		fill = false,
		thumb = {
			normal = { texture = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal" },
			hover = { texture = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal" },
			disabled = { texture = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal", color = { 0.5, 0.5, 0.5, 1 } },
		},
		tab = {
			normal = { backdrop = THIN, bg = { 0, 0, 0, 0.6 }, border = GREY },
			hover = { backdrop = THIN, bg = { 0.2, 0.15, 0, 0.7 }, border = GREY },
			selected = { backdrop = THIN, bg = { 0.35, 0.25, 0, 0.8 }, border = GOLD },
		},
		row = {
			hover = { texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD" },
			selected = { texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 0.82, 0, 1 } },
			alt = { bg = { 1, 1, 1, 0.03 } },
		},
		scrollTrack = { bg = { 0, 0, 0, 0.4 } },
		scrollThumb = {
			normal = { texture = "Interface\\Buttons\\UI-ScrollBar-Knob", coords = { 0.2, 0.8, 0.125, 0.875 } },
			hover = { texture = "Interface\\Buttons\\UI-ScrollBar-Knob", coords = { 0.2, 0.8, 0.125, 0.875 } },
		},
		bar = { texture = "Interface\\TargetingFrame\\UI-StatusBar" },
	},
	icon = {
		close = { texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", size = 28 },
		plus = { texture = "Interface\\Buttons\\UI-PlusButton-Up", size = 16 },
		minus = { texture = "Interface\\Buttons\\UI-MinusButton-Up", size = 16 },
	},
	metric = {
		pad = 12, gap = 8, control = 22, title = 30, check = 24,
		slider = 17, thumbWidth = 32, thumbHeight = 32, scroll = 14,
		windowInset = { 11, 12, 12, 11 },
	},
})
