---
name: fk-addon
description: Build a complete World of Warcraft Forever addon (Interface 16001) with the ForeverKit framework in this repo, from a short brief to a tested, linted, previewed, zipped addon. Use this whenever the user wants a new WoW addon, an addon idea turned into code, a feature added to an addon in addons/ or examples/, or asks to "make an addon that…", even if they don't mention ForeverKit, Forever, or this repo's tools by name.
---

# Building a ForeverKit addon

ForeverKit is an embedded Lua 5.1 UI + feature library; `tools/fk` scaffolds, tests, lints,
previews and packages. The fastest route to a good addon is to start from the scaffold, keep
everything declarative, and let the tools find problems before the player does.

## 1. Read the brief against what Forever allows

Before writing code, check the idea against [docs/guidelines/features.md](../../../docs/guidelines/features.md):
combat data can be *shown* but not *computed on* (secret values), so rotation helpers, "warn when
buff X drops", DPS maths are not buildable; damage meter, cooldown manager, raid frames are
already in the client. If the brief needs one of those, stop before building: explain in plain
words why it cannot work as asked, offer two or three buildable alternatives (say which you would
pick and which depend on APIs not yet verified on Forever), and let the user choose. Building a
substitute they did not ask for wastes their time and hides the limitation; the user prefers to
decide. If the brief needs quest/NPC/item facts or prices, read the `fk-gamedata` skill too.

## 2. Pick the kind and scaffold

| The addon mainly… | Kind |
|---|---|
| has a window you open to manage or read things | `window` |
| shows a small always-visible frame with live state | `tracker` |
| changes behaviour, configured only through settings | `options-only` |
| looks things up in QuestieDB / game data | `data` |

```sh
tools/fk new MyAddon --kind tracker --notes "One line saying what it does."
```

This creates `addons/MyAddon/` (TOC, `Main.lua`, `tests/`, `Libs/ForeverKit` linked) that already
passes its tests. Read the generated `Main.lua` and test before changing them — they show the
house style. Bigger worked examples: `examples/GoalCounter` (tracker), `examples/ItemSources`
(QuestieDB tree + table), `examples/BagWarden` (settings-heavy), `examples/FKGallery` (every widget).

## 3. Write the addon

- Look up widgets and modules in [docs/COMPONENTS.md](../../../docs/COMPONENTS.md) (generated from the
  source; trust it over memory). Choose controls with the `fk-ui` skill; the short version: every
  numeric setting is a slider (or a stepper for small counts), never a list of preset numbers.
- Settings: add defaults to `FK:NewDB(...)` and options to `FK:Options({...})`; never hand-place
  settings controls. New SavedVariables names go in the TOC.
- Read saved settings in `FK:OnLoad`/`FK:OnLogin`, not at file load.
- Strings through `L["..."]`; colours/fonts through theme roles; no globals except what the
  client calls by name (see the `fk-api` skill for these rules and secret values).
- Keep testable logic in plain functions on `ns` (`ns.Lines()`, `ns.Check()`), so tests can call
  them without clicking through the UI.

## 4. Prove it works — in this order

```sh
tools/fk test addons/MyAddon/tests          # extend the generated tests for every new behaviour
tools/fk lint MyAddon                        # fix every error; read every warning
tools/fk preview MyAddon --theme pixel,vanilla,glass,parchment --do "H.Slash('/myaddon')"
```

Open the PNGs it prints (Read tool) and look at them: overlapping text, cramped rows, an empty
window, unreadable colours in one theme. Fix and re-render. Tests and lint don't see taste. The
`fk-test` skill has the test vocabulary and the live loop.

## 5. Optional: the real client

Only with the user present (they must restart/reload the game): `tools/fk link MyAddon FKDev`,
then `tools/fk live run …` / `tools/fk live results`. Never kill the game, send it input, or
delete anything under the WoW folder.

## 6. Package

```sh
tools/fk build MyAddon      # lints, then build/MyAddon-<Version>.zip with ForeverKit embedded
```

## Report back

Tell the user what the addon does in game (commands, where the window/settings are), what was
verified (tests, lint, which previews you looked at) and what was not (anything only the real
client can confirm). Mention design decisions they might want to change.
