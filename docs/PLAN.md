# Execution plan — ForeverKit

A framework for building WoW Forever (interface 16001) addons quickly and consistently, mostly
by AI. This file is the single source of truth for *what is done and what is next*.

**To resume after a context reset: read this file, find the first step not marked `[x]`, read
its section and the "Notes from earlier steps" at the bottom, do it, verify it, tick it, add
notes, commit.** Research that the decisions rest on is in [`research/`](research/).

## Status

- [x] **Step 0** — Research, plan, repo skeleton
- [x] **Step 1** — Toolchain: local Lua 5.1, `fk` CLI skeleton, local config
- [x] **Step 2** — Emulator (`harness/`): frames, layout, TOC loader, events, clock, input, tree dump, test runner
- [x] **Step 3** — ForeverKit core: namespace, events, DB, slash, timers, locale, theme engine
- [x] **Step 4** — Widgets I (controls): window, panel, text, button, checkbox, toggle, slider family, edit boxes, dropdowns, colour, keybind, progress
- [x] **Step 5** — Widgets II (collections): scroll list, table, tree, composite rows (toggle+slider, toggle+list…), reorder list, checklist, tabs, dialogs, menu, toast, bars, icon grid, money
- [x] **Step 6** — Options DSL: declarative settings → generated panel, Settings-panel registration, profiles; UI lint rules
- [x] **Step 7** — Themes (`vanilla`, `pixel`, `glass`, `parchment`), HTML preview renderer, `FKGallery` showcase addon
- [ ] **Step 8** — Feature modules ("hooks"): tooltips, items, bags, minimap button + compartment, comms, combat queue, secrets helpers, movers, map pins, chat
- [ ] **Step 9** — Game data: QuestieDB + Auctionator runtime bridges, offline `fk data` tools
- [ ] **Step 10** — Live testing: `fk link`, `FKDev` in-game addon, `fk live`, verified against the real client
- [ ] **Step 11** — Scaffold (`fk new`), `fk build`, three example addons of different kinds
- [ ] **Step 12** — Claude skills (with skill-creator), generated component catalog, UI/UX + feature guidelines
- [ ] **Step 13** — Human operation guide, README, full QA pass, in-game checklist

## Decisions (do not re-litigate without a reason)

1. **Target**: WoW Forever only, `## Interface: 16001`, modern Mainline API with secret-value
   restrictions. No Classic Era / retail compatibility layers.
2. **Pure Lua, primitives only.** ForeverKit widgets are built from `Frame`, `Button`,
   `CheckButton`, `Slider`, `EditBox`, `ScrollFrame`, `StatusBar`, `Texture`, `FontString`. No XML,
   no Blizzard widget templates except `BackdropTemplate`. Reasons: themes control every pixel;
   the emulator can cover the whole library; no dependency on templates Blizzard reskins.
   Blizzard systems used through their Lua API only: `GameTooltip`, `ColorPickerFrame`,
   `Settings.RegisterCanvasLayoutCategory`, `UISpecialFrames`, addon compartment (TOC field).
3. **Embedded, private copy.** The library lives in the addon at `Libs/ForeverKit/` and attaches
   to the addon's private namespace (`local _, ns = ...; local FK = ns.FK`). No globals, no
   LibStub, no version skew between addons. Cost: a few hundred KB of duplicated Lua per addon.
4. **Declarative first.** Settings and most windows are described as data (`FK.Options`), the
   library builds the UI. Hand-placed frames are the exception. This is what makes AI generation
   fast and consistent, and what lets lint enforce UI rules.
5. **Sliders over enumerations.** A continuous or evenly stepped numeric setting is a slider with
   a typed value field. `20 yd / 40 yd / 60 yd / 80 yd` as a dropdown is a lint error
   (`ui-enum-should-be-slider`) and a dev-mode runtime warning.
6. **Themes are token tables** (colours, fonts, metrics, backdrops, textures per role). Widgets
   read tokens only. Switching theme re-skins live.
7. **Two test loops** (see research/04): the Lua 5.1 emulator in `harness/` for everything fast,
   and the real client through `FKDev` + SavedVariables for the truth. Same text dump format in
   both.
8. **Tooling**: one Python 3 stdlib CLI (`tools/fk`); Lua 5.1 compiled from lua.org source into
   `.tools/` by `tools/setup.sh`. No luarocks, no npm, no Docker.
9. **Third-party data is a runtime optional dependency.** QuestieDB (GPL-3.0) and Auctionator
   (All Rights Reserved, and its repo asks AI agents not to use its source) are called through
   their public APIs only; nothing of theirs is copied into this repo.
10. **Branch**: work happens on `build/foreverkit`; one commit (or a few) per step; nothing is
    pushed unless the user asks.

## Repository layout (target)

```
CLAUDE.md                  agent entry point (map + rules + "next step" protocol)
README.md                  what this is, quick start
docs/PLAN.md               this file
docs/HUMAN-GUIDE.md        operating guide for the human
docs/research/             step 0 findings
docs/guidelines/           ui-ux.md, features.md, testing.md, api-constraints.md
docs/COMPONENTS.md         generated catalog: every widget and module, one line + signature
framework/ForeverKit/      the library (Core/, Widgets/, Themes/, Features/, Data/)
harness/                   emulator, test runner, renderer
tools/fk                   CLI: setup, new, sync, lint, test, tree, preview, docs, data, link, live, build
tools/FKDev/               in-game dev addon (errors, in-game tests, queue, dumps)
templates/addon/           scaffold used by `fk new`
examples/                  FKGallery + three example addons
tests/                     framework tests run by `fk test`
.claude/skills/            fk-addon, fk-ui, fk-test, fk-gamedata, fk-api
```

## Steps

Every step ends with: tests green (`tools/fk test`), this file updated (tick + notes), commit.

### Step 1 — Toolchain
- `tools/setup.sh`: download lua-5.1.5 from lua.org, verify checksum, build to `.tools/lua`.
- `tools/fk`: argparse CLI with subcommands stubbed as they arrive; `fk doctor` prints Lua path,
  WoW path, account folders. Config in `.fk.local.json` (gitignored): `wow_dir`.
- Done when: `tools/fk doctor` is green on this machine.

### Step 2 — Emulator
- `harness/wow/*.lua`: object model (ScriptObject → Region → Frame → subclasses, Texture,
  FontString), anchors + layout pass, strata/level ordering, shown/visible propagation, scripts,
  events, `C_Timer` + virtual clock + `OnUpdate`, input simulation (click, drag, wheel, type,
  hover), `GameTooltip`, `ColorPickerFrame`, `Settings`, `UISpecialFrames`, SavedVariables
  (serialise/load), TOC loader, slash commands, a stub layer for common `C_*` namespaces with
  overridable fixtures, secret-value simulation.
- Unknown globals: accessing an unimplemented WoW API raises a clear "not emulated: X" error, so
  gaps surface instead of silently returning nil.
- `harness/run.lua`: load addon(s), run test files (`tests/*.lua` with `test("name", fn)`),
  print results; `harness/tree.lua`: text dump of visible frame tree.
- Done when: a hand-written 30-line addon using only primitives loads, a test clicks its button,
  asserts the text changed, and the tree dump shows correct rectangles.

### Step 3 — Core
- `Core/Init.lua` (namespace, version, dev flag), `Events.lua` (frame events + internal
  callbacks), `DB.lua` (defaults, account/char scopes, profiles, migrations, change callbacks),
  `Slash.lua`, `Timer.lua` (after, ticker, debounce, throttle), `Locale.lua`, `Util.lua`
  (colour, money, table helpers, safe calls), `Theme.lua` (token registry, `FK.Theme:Apply`,
  skin functions per role, live switch).
- Done when: emulator tests cover DB defaults/migration/profile switching and event dispatch.

### Step 4 — Widgets I
Base widget contract (constructor signature, `:SetEnabled`, `:SetValue/GetValue`, `OnChange`,
tooltip, theme hook, label). Then: `Window` (move, resize, close, Esc, saved position, lock,
scale), `Panel`/`Section`, `Label`/`Heading`/`Divider`, `Button`/`IconButton`, `CheckBox`,
`Toggle`, `Slider` (label, value edit box, steppers, format, snap, commit-on-release),
`RangeSlider` (two thumbs), `Stepper`, `EditBox`, `SearchBox`, `TextArea`, `Dropdown`,
`MultiDropdown`, `Segmented`, `RadioGroup`, `ColorSwatch`, `KeybindButton`, `ProgressBar`,
layout helpers (`Stack`, `Row`, `Grid`, `Flow`).
- Done when: each has an emulator test for value round-trip, disabled state and layout bounds.

### Step 5 — Widgets II
`ScrollList` (virtualised, pooled rows, variable or fixed height), `Table` (sortable, resizable
columns, selection), `Tree` (collapsible, lazy), composite rows — `ToggleRow`,
`ToggleSliderRow`, `ToggleDropdownRow`, `ToggleListRow` (toggle + expandable child list),
`ToggleConfigRow` (toggle + cog sub-panel), `SliderRow`, `ItemRow` — `ReorderList`, `CheckList`
(all/none/filter), `Tabs`, `SideNav`, `Dialog` (confirm, input, reload prompt), `Menu` (context),
`Toast`, `TimerBar`, `MeterBar`/`BarList`, `IconGrid`, `MoneyText`, `MoneyInput`, `Autocomplete`,
`Tooltip` helpers, `Tracker` (compact always-on frame).
- Done when: tests cover virtualisation (1 000 rows → bounded frame count), sorting, expand/
  collapse, reorder, and composite rows' enabled-state coupling.

### Step 6 — Options DSL
- `FK.Options:Register(schema)` → window and/or Blizzard Settings canvas; types map to step 4/5
  widgets; `get/set` default to DB paths; `disabled`/`hidden` predicates; `requiresReload`;
  search; reset to defaults; profiles page.
- Lint (`tools/fk lint`): TOC checks, leaked globals, UI rules incl.
  `ui-enum-should-be-slider`, secret-unsafe comparisons on known secret-returning APIs,
  hard-coded fonts, missing locale use.
- Done when: a 20-option schema renders, every option round-trips through the DB in a test, and
  lint flags a fixture containing the yard-list anti-pattern.

### Step 7 — Themes and preview
- Four themes; `harness/render.lua` → standalone HTML; `fk preview <addon> [--theme] [--shot]`
  (PNG via headless Firefox); `examples/FKGallery` showing every widget, with a theme switcher.
- Done when: gallery screenshots exist for all four themes and have been looked at.

### Step 8 — Feature modules
`Tooltip` (item/unit post-call lines), `Items` (async info cache, quality colour, links),
`Bags` (scan, counts, throttled change event), `Minimap` (button, drag around edge, hide option)
+ compartment glue, `Comm` (prefix, chunking, throttling), `Combat` (run-after-combat queue),
`Secret` (is/guard/safe display helpers), `Movers` (unlock mode), `MapPins` (world map pins),
`Chat` (prefixed print, links, slash help), `Keybind`, `Unit`/`Group` helpers, `Sound`.
- Done when: each module has an emulator test against fixtures.

### Step 9 — Game data
- `Data/Questie.lua`, `Data/Auction.lua` runtime bridges (optional-dependency safe, `pcall`ed).
- `fk data`: load installed QuestieDB into the emulator, query by id/name, print JSON/Lua;
  document real value shapes back into research/05.
- Done when: `fk data item "Linen Cloth"` prints drops/vendors from the local install.

### Step 10 — Live testing
- `fk link/unlink`, `tools/FKDev` addon (error capture, in-game tests, queue, tree dump,
  screenshot), `fk live run|results|shot|errors`.
- Verify on the running client with a human `/reload`; record what was verified.
- Done when: an injected deliberate error and a passing in-game test both appear in
  `fk live results`. **Needs the human for /reload.**

### Step 11 — Scaffold and examples
- `fk new <Name> [--kind window|tracker|options-only|data]`, `fk sync`, `fk build` (zip).
- Examples: a tracker (bags/goal counter), a data browser (QuestieDB tree + table), a
  settings-heavy QoL addon. Each with tests and a preview.

### Step 12 — Skills and docs
- Use the skill-creator skill. Skills: `fk-addon` (brief → working addon workflow), `fk-ui`
  (component choice + UX rules), `fk-test` (both loops), `fk-gamedata`, `fk-api` (Forever
  constraints, secrets, combat lockdown).
- `fk docs` generates `docs/COMPONENTS.md` from `---@widget` / `---@module` comment headers.
- `docs/guidelines/*.md`.

### Step 13 — Wrap-up
- `docs/HUMAN-GUIDE.md`, `README.md`, `CLAUDE.md` final pass, full test run, in-game checklist.

## Notes from earlier steps

### Step 0 (2026-11-16)
- Local WoW: `/mnt/data/BattleNet/drive_c/Program Files (x86)/World of Warcraft/_forever_`
  (Lutris/Wine, Wayland/KDE, UI scale 0.66). Installed: Questie, QuestieDB, Auctionator,
  Baganator, Syndicator, OpenMap, GatherLite, ForeverDungeonJournal, RavenCouncil, QuestieTrace,
  and the user's own **GoalNotes** (a good reference for the user's taste: classic gold dialog,
  slim-border option, opacity/scale/font sliders, column grips, autocomplete).
- Machine has gcc, make, curl, python3, node, firefox, wine. No lua, luarocks, xdotool.
- Never write the Battle.net account folder name (under `WTF/Account/`) into the repo.

### Steps 1–2 (2026-11-16)
- `tools/setup.sh` builds Lua 5.1.5 into `.tools/lua` (checksum verified). `tools/fk doctor`,
  `tools/fk test [paths] [-v]` (one Lua process per test file).
- Emulator is `harness/wow/` (`state`, `objects`, `sim`, `api`, `loader`, `tree`, `init`);
  `harness/run.lua` is the test runner. Test files get `H`, `ROOT`, `test`, `eq`, `near`, `ok`,
  `raises`; the client is reset before each test.
- Test vocabulary: `H.Start(dir)` → ns, `H.Reload()` → new ns, `H.Click/Hover/Drag/Slide/Wheel`,
  `H.Enter(box, text)`, `H.Type`, `H.Key`, `H.Slash`, `H.Fire(event, …)`, `H.Advance(seconds)`,
  `H.SetCombat(bool)`, `H.SetBag`, `H.CacheItem`, `H.ShowItemTooltip`, `H.TooltipLines()`,
  `H.PickColor/CancelColor`, `H.Receive` (addon message), `H.Stub("C_X.Fn", fn)`,
  `H.Tree(root)`, `H.LayoutIssues(root)`, `H.Find(root, textOrName)`, `H.LeakedGlobals(addon)`,
  `H.fixtures` (player, items, bags, spells, cvars).
- Deliberately strict: unknown templates, unknown `C_*` members, wrong script names, unsaveable
  SavedVariables, clicks on covered/hidden frames and anchor cycles all raise.
- Known limits: text width is estimated; `secret == x` cannot raise in Lua 5.1 (lint must catch
  it); a region with no anchors is treated as not drawn; animations only fire `OnFinished`.
- `tests/fixtures/Plain` is a primitives-only addon used by `tests/harness_test.lua`.

### Steps 3–4 (2026-11-16)
- Library lives in `framework/ForeverKit/`, loaded through `ForeverKit.xml` (a list of
  `<Script>` tags; add every new file there). Test host addon: `tests/fixtures/KitTest`
  (`Libs/ForeverKit` is a symlink to the library).
- Core API: `FK:On/Once/Off/Emit`, `FK:OnLoad/OnLogin`, `FK:NewDB(sv, defaults, opts)` →
  `db.profile/global/char`, `db:Get/Set/OnChange/Reset`, profiles; `FK:After/Every/Debounce/
  Throttle`, `FK:Slash`, `FK.L`/`FK:Locale`, `FK:Print`, `FK:Warn(code, msg)` (→ `FK.warnings`),
  utilities `FK.Money/Number/Duration/Round/Clamp/Copy/Equal/GetPath/SetPath/Pool/Pixel`.
- Widget contract (`Core/Widget.lua`): `FK.Define(kind, methods, build)` creates
  `FK.<Kind>(parent, opts)`; a widget is a plain Frame + mixed-in methods; `SetValue` is silent,
  user changes call `opts.onChange(value, widget)`; `Restyle()` re-applies the theme;
  `self:Text(role, color, parent)` for themed font strings; `self:Clickable(parent, onClick)`
  for themed buttons; `self:Caption(label)`; `self:Changed()` tells the parent container.
  Each widget definition carries a `---@widget Name  description. opts: ...` comment: step 12
  generates the catalog from these.
- Themes (`Core/Theme.lua`, `Themes/`): `base` (abstract, full token reference), `pixel`,
  `vanilla`. `Theme.Paint(frame, spec)`, `Theme.PaintState`, `Theme.Texture`, `Theme.Font`,
  `Theme.Icon`, `Theme:Set(name)`, `Theme.opacity`, `Theme.fontDelta`.
- Widgets so far: Stack, Row, Grid, Flow, `FK.Build`; Label, Heading, Divider, Spacer, Button,
  IconButton, CheckBox, Toggle, ProgressBar; Slider, RangeSlider, Stepper; EditBox, SearchBox;
  Dropdown, MultiDropdown, Segmented, RadioGroup, ColorSwatch, KeybindButton, `FK.Popup`;
  Window, Panel.
- Dev warning `ui-enum-should-be-slider` fires at runtime when Dropdown/Segmented/RadioGroup
  get three or more items that are all numbers with the same unit.
- Escape closes every frame in `UISpecialFrames` at once (client behaviour): an open dropdown
  list and its window close together. Left as is; a keyboard-capturing popup would need
  `SetPropagateKeyboardInput`, which I believe is restricted in combat (unverified).
- **To verify in step 10 (in game):** every texture path used by `Themes/Vanilla.lua` and the
  icon paths in `Themes/Base.lua` exist in the Forever client; they were chosen from memory of
  the classic art set.
- Emulator additions: slider thumb and status-bar textures are positioned as the engine does;
  `H.LayoutIssues` also reports frames outside their window.

### Step 5 (2026-11-16) — and the preview renderer from step 7, done early
- `fk tree <addon> [--do LUA] [--theme T]` prints the frame tree + layout issues (exit 1 if
  any); `fk preview <addon> [--do LUA] [--theme a,b] [--name suffix] [--full]` writes
  `.preview/<addon>-<theme>-<suffix>.html/.png` (headless Firefox). `--do` snippets see `H`,
  `ns`, `FK`. Renderer: `harness/wow/render.lua`; Blizzard art is drawn from its `ART` table
  (unknown files show as a magenta dashed box: add a stand-in there).
- New widgets: `Widgets/Scroll.lua` (ScrollArea, ScrollList, Table, Tree, TextArea,
  `FK.ScrollBar`), `Widgets/Rows.lua` (OptionRow and its named shapes ToggleRow, SliderRow,
  ToggleSliderRow, ToggleDropdownRow, ToggleListRow; CheckList, ReorderList, MoneyInput),
  `Widgets/Nav.lua` (Tabs, SideNav, `FK.Dialog/Confirm/Prompt/ReloadPrompt`, `FK.Menu`,
  `FK.Toast`, `FK.Autocomplete`), `Widgets/Display.lua` (TimerBar, BarList, IconGrid, Tracker).
- Skipped on purpose: drag-and-drop reordering (ReorderList uses up/down arrows), keyboard
  navigation inside popup lists, column resize persistence (the Table mutates
  `opts.columns[i].width`; save that table if persistence is wanted).
- `FK.Build` leaves `children` alone for widgets with `ownsChildren` (OptionRow family).
- Layout rule learned: a widget that lays out an inner container and is itself told about that
  container's size changes needs a re-entrancy guard (see OptionRow.Arrange, ScrollArea.Layout).

### Step 6 (2026-11-16)
- `Widgets/Options.lua`: `FK:Options({ db, pages = {{ id, label, options = {...} }}, appearance =
  "profile.ui", profiles = true })` → `:Open()/:Toggle()/:Refresh()`; also registers a category
  in the game's Settings window (canvas built on first show; `blizzard = false` to skip).
  Option types: header, text, toggle, slider, stepper, select, multiselect, segmented, color,
  keybind, input, money, checklist, reorder, button, group. Modifiers: `requires`, `disabled`,
  `hidden`, `toggleKey`, `requiresReload`, `onChange`, `get/set`.
- `FK:BindAppearance(db, key)` + `FK.AppearanceDefaults`; `db:Export()/Import()` through
  `FK.Serialize/Deserialize` (own parser, pasted text is never executed).
- Sets (multiselect, checklist) are stored as `{ key = true/false }` so a default `true` can be
  switched off; the binding converts.
- `fk lint <addon>`: static rules live in `LINT_RULES` in `tools/fk` (toc-*, deprecated-api,
  legacy-dropdown, blizzard-template, secret-compute, hardcoded-font, global-function,
  getglobal, combat-settings, savedvariable-undeclared, ui-enum-should-be-slider) plus an
  emulator pass (`harness/cli.lua lint`: loads, logs in, runs every slash command, reports
  global-leak, layout issues, FK design warnings). `tests/fixtures/BadAddon` trips them all;
  `tests/lint_test.sh` checks that (run by `fk test`).
- Not done: search across options; the secret-value lint is a regex over four unit functions,
  not data-flow analysis.

### Step 7 (2026-11-16)
- Themes: `glass` (translucent flat colours, no texture files) and `parchment` (paper colour,
  tooltip-border edges, tan buttons, red accents, shadowless dark ink) join `pixel` and `vanilla`.
  Font roles accept `shadow = false`; `Theme.Font` sets the shadow every time so switching back
  restores it.
- Bug fixed: the theme merge treated any group with a `text` key as a leaf, so overriding
  `color.text` dropped every other base colour (vanilla had lost `warn` and `link`). New test:
  every theme carries every base colour/font/metric/surface/icon key.
- Renderer: `UI-Tooltip-Background` is drawn as a tinted flat tile (as in game); multi-line
  edit boxes render top-aligned and wrapping; text shadow follows `SetShadowColor`.
- `examples/FKGallery`: one window, side tabs Controls / Choices / Settings rows / Collections /
  Display, theme dropdown (saved; follows `fk.theme`), `/fkgallery`. Exposes `ns.gallery` for
  previews: `fk preview FKGallery --theme pixel,vanilla,glass,parchment --name rows --do
  "ns.gallery.tabs:Select('rows')"`. All 20 page×theme screenshots were rendered and looked at.
  Its test checks every page in every theme for layout issues.
- Known, left: `FK.Money` coin colours (gold/silver/copper) are faint on parchment; pixel
  BarList labels are white on a light-blue fill (low contrast). Glass/parchment colours are
  untested in game (step 10).
