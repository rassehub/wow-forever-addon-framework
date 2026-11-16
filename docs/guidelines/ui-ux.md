# UI/UX guidelines

How ForeverKit addons should look and behave. The reasons come from what players of Forever
already use (research [02](../research/02-default-ui-look.md), [03](../research/03-popular-addons.md)).
`tools/fk lint` and the emulator's layout check enforce the parts marked *(checked)*.

## Choosing the control

| The setting is… | Use | Not |
|---|---|---|
| on/off, takes effect at once | `toggle` / `Toggle` | — |
| on/off in a list of many | `CheckBox`, `CheckList` (with All/None, search for long lists) | a dozen separate toggles |
| a number: scale, opacity, size, distance, duration, count | `slider` with `min/max/step`, `format` or `percent` *(checked: `ui-enum-should-be-slider`)* | a dropdown or buttons of preset numbers (`20 yd / 40 yd / 60 yd`) |
| a small whole count (rows, columns, stacks; < ~20 steps) | `stepper` | a slider with 3 positions |
| a range (level 20–35, price band) | `RangeSlider` | two separate sliders |
| one of 2–5 named options, all worth seeing | `segmented` | a dropdown hiding two choices |
| one of many named options | `select` (Dropdown) | a radio list longer than the screen |
| one option needing a longer explanation each | `RadioGroup` | — |
| several of a set | `multiselect` / `CheckList` | — |
| "enable X" + "how much X" | slider with `toggleKey` (`ToggleSliderRow`) | a toggle and an unrelated slider below it |
| "enable X" + "which X" (sound, channel) | select with `toggleKey` (`ToggleDropdownRow`) | — |
| a feature with its own block of settings | `group` with `toggleKey` (`ToggleListRow`) | a separate page per feature |
| an order (bars, columns, priority) | `reorder` (`ReorderList`) | numeric "position" sliders |
| colour | `color` (ColorSwatch, the game's picker) | RGB sliders |
| key combination | `keybind` + `FK.Keybind` | text input |
| money | `money` (MoneyInput) | a copper number box |

Rule of thumb: a numeric value is a slider unless it is a small count, and never a list of
preset numbers. If players would want "between two presets", it was a slider.

## Windows

- Every window is movable, remembers position and size (`saved = { db, "profile.window" }`),
  closes with Escape and has a close button. `FK.Window` does all of it.
- Default size fits 0.64 UI scale on 1080p: at most about 900×650 UI units. Resizable windows set
  `resizable = { minWidth, minHeight }` so content never collapses.
- Pair a full window with a compact `Tracker` for at-a-glance state; both movable and lockable.
- Content that can grow goes into `ScrollArea` / `ScrollList` / `Table`; nothing is clipped
  silently *(checked: "text truncated", "outside its window")*.
- Lists of more than a few dozen items use `ScrollList` or `Table` (virtualised), never one frame
  per item.
- Tabs along the top for up to ~5 peers; `SideNav` (or `Tabs` with `side = true`) beyond that.
- Journal-like content: `Tree` left, detail (`Table`/text) right.
- A window opened at login opens via `window:Open()` — the framework waits for the moment after
  the client's own close-all on entering the world.

## Settings

- Describe settings with `FK:Options` (data, not hand-placed frames). It builds the panel, the
  entry in the game's Settings window, an Appearance page (`appearance = "profile.ui"`) and a
  Profiles page (`profiles = true`).
- Every setting has a clear `label`; add `desc` when the label alone does not say what changes.
- Settings take effect live. When they cannot, set `requiresReload = true` (the panel offers the
  reload) — never silently wait for the next reload.
- Settings that only matter when another is on use `requires` or `toggleKey`, so they show as
  disabled instead of disappearing.
- Offer both a minimap button (hideable: `profile.minimap.hide`) and the addon compartment
  (`## AddonCompartmentFunc`), plus a slash command with `config`.

## Look

- Never hard-code colours, fonts or textures in an addon: use theme roles (`color = "good"`,
  `role = "heading"`). Themes `pixel`, `vanilla`, `glass`, `parchment` must all work; the
  player picks in Appearance.
- Text uses font objects through the theme *(checked: `hardcoded-font`)* so Korean, Chinese and
  Russian clients render.
- Item names in quality colour (`FK.Items.Colored`), players in class colour
  (`FK.Unit.Colored`), money with `FK.Money`.
- Item names arrive asynchronously: show "item:12345" or a placeholder, then refresh through
  `FK.Items.Load(id, refresh)`.
- Numbers keep their unit in the label or the slider's `format` ("%d yd", "%.1f s", percent).

## Text

- All user-visible strings go through `L["..."]` so they can be translated.
- Chat output goes through `FK:Print` (prefixed with the addon's name), once per event, never
  spammy; use `FK.Toast` for transient notices.
