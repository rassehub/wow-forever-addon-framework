local _, ns = ...
local FK = ns.FK

-- Flat, dark, one accent colour, 1px black borders. The look of ElvUI-style interfaces.
FK.Theme.Register("pixel", {
	extends = "base",
	label = "Pixel (flat dark)",
	font = {
		small = { "GameFontHighlightSmall" },
		title = { "GameFontHighlight", color = "title" },
		heading = { "GameFontHighlight", color = "accent" },
	},
})
