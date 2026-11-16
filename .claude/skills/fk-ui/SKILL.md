---
name: fk-ui
description: Choose and lay out ForeverKit UI for WoW Forever addons — which control fits a setting (slider vs dropdown vs toggle rows), window/tracker/settings structure, themes, and how to verify the result visually with fk preview. Use whenever designing or reviewing an addon's window, settings panel, list, table, tracker or any FK widget code, or when the user complains that an addon UI looks wrong, cramped, inconsistent or "not like WoW".
---

# ForeverKit UI

The full rules with reasons are in [docs/guidelines/ui-ux.md](../../../docs/guidelines/ui-ux.md); widget
signatures in [docs/COMPONENTS.md](../../../docs/COMPONENTS.md). This skill is the working summary.

## Pick the control from the data, not from habit

- Number (scale, opacity, distance, size, duration, count) → `slider` with `min/max/step` and a
  `format` ("%d yd") or `percent = true`. Small whole counts → `stepper`. A choice between preset
  numbers is wrong even if it looks tidy: players always want the value in between, and lint
  rejects it (`ui-enum-should-be-slider`).
- "Enable X" + "how much / which X" → one composite row: `toggleKey` on the slider or select
  (`ToggleSliderRow`, `ToggleDropdownRow`). A feature owning several settings → `group` with
  `toggleKey`. These read as one decision, and the dependent control greys out when off.
- 2–5 named options → `segmented`; many → `select`; several at once → `multiselect`/`checklist`;
  order → `reorder`; colour → `color`; key → `keybind`; money → `money`.

## Structure

- Settings are data in `FK:Options({ db, pages = {...}, appearance = "profile.ui", profiles = true })`.
  Pages are tabs; more than ~5 become a side list automatically. `options:Open("pageId")` jumps.
- Windows: `FK.Window(UIParent, { title, width, height, resizable = {...}, saved = { db, "profile.window" } })`,
  content in `win.content`. Keep default size within ~900×650 UI units.
- Build content declaratively where possible:

```lua
local _, refs = FK.Build(win.content, { "ScrollArea", points = { { "TOPLEFT" }, { "BOTTOMRIGHT" } }, children = {
    { "Heading", text = L["Goals"] },
    { "Slider", id = "range", label = L["Range"], min = 5, max = 80, value = 40, format = "%d yd",
      onChange = function(v) ns.db:Set("profile.range", v) end },
} })
```

- Long or growing content: `ScrollArea` (stacked widgets), `ScrollList` (virtualised rows),
  `Table` (sortable columns), `Tree` (+ detail pane for journal layouts).
- At-a-glance state: `Tracker` (+ the full window for management).
- Anchor to siblings (`SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)`) and to the content's
  edges; fixed pixel offsets from the window's corner break when the theme's padding changes.

## Look

Use theme roles (`color = "dim"`, `role = "heading"`), never literal colours or font files, so all
four themes (`pixel`, `vanilla`, `glass`, `parchment`) work and the player's Appearance choice
applies. Quality/class colours via `FK.Items.Colored` / `FK.Unit.Colored`.

## Verify by looking

```sh
tools/fk preview MyAddon --theme pixel,vanilla,glass,parchment --do "H.Slash('/myaddon')"
tools/fk tree MyAddon --do "..."     # text dump + layout issues (exit 1 if any)
```

Read the PNGs. Check: text truncated or overlapping, controls touching edges, empty space that
looks like a bug, contrast in `parchment` (light) and `glass` (translucent) especially. In tests,
`eq(H.LayoutIssues(window), {})` for every page in every theme catches clipping regressions.
Art in previews is approximated; only the real client (`fk-test` live loop) shows true textures.
