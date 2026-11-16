# Research 03 — What popular addons do and contain

Status as reported by guide sites in early/mid November 2026 plus the local install. The point of
this file is the right-hand columns: which UI elements and features recur, because those are what
the component library has to provide.

## Addons with a Forever build

| Addon | Category | What it does | Recurring UI elements | Recurring features |
|---|---|---|---|---|
| Questie (+QuestieDB) | Quests | Quest givers/objectives on map & minimap, tracker, journal | Map pins, minimap pins, tracker frame, searchable journal (tree + detail pane), tooltip lines, big options panel with tabs | Static DB, map coordinates, tooltip hooks, per-char completed state, comms between players |
| Auctionator | Auction | Scan AH, price DB, shopping lists, fast posting | Tabs added to a Blizzard frame, sortable multi-column tables, search box with history, money inputs, shopping **lists of lists** | Price DB in SavedVariables, public API for other addons, tooltip price lines |
| Baganator / Bagnon | Bags | One-bag view, categories, search, alt inventories | Icon grid, search box, category headers (collapsible), character dropdown, drag reorder of categories | Bag scanning, offline alt cache (Syndicator), item search grammar, skins |
| Details! | Combat | Damage meter (Forever has a built-in one too) | Bar list (status bars with icon/left/right text), title bar with menu icons, breakdown window, resizable/lockable windows | Segments, profiles, skins, report-to-chat |
| DBM / BigWigs / LittleWigs | Encounters | Warnings, timer bars (no encounter timers on Forever) | Timer bars, big centre-screen text, movable anchors ("test mode"), nested option tree with **toggle + sound dropdown** rows | Per-ability toggle lists, test/preview mode, profiles |
| ElvUI | Full UI | Replaces unit frames, bars, bags, chat | Flat pixel style, movers ("toggle anchors"), huge option tree, install wizard, sliders everywhere with typed values | Profiles + import/export string, per-module enable toggles |
| Bartender4 | Action bars | Bar layout | Unlock/lock mode with draggable overlays, per-bar option pages built from **sliders** (scale, padding, alpha, rows) | Visibility state conditions, profiles |
| Plater | Nameplates | Nameplate styling | Tabbed options with dense grids of sliders/colour swatches, script list | Import/export, profiles |
| Leatrix Plus / Maps | QoL | Dozens of small toggles | Paged checkbox lists, each checkbox with an optional **cog button opening a sub-panel** of sliders | Feature toggles requiring reload, reload prompt |
| TomTom | Navigation | Waypoint arrow, coordinates | Movable arrow widget, coordinate block, context menus | Slash command parsing, waypoint persistence |
| GatherMate2 / GatherLite | Gathering | Records nodes on gather, shows on map | Map/minimap pins, filter checklists by node type | Record-on-event DB, import |
| Attune | Progress | Attunement checklists | Step tree with completion states, guild/alt views | Sharing via addon comms |
| LootAppraiser, TSM | Gold | Loot value, market ops | Compact tracker + full window pairs, money text everywhere | Reads Auctionator/TSM prices |
| WeakAuras forks (ForeverAuras, Musca Auras) | Displays | Custom displays, heavily limited by secrets | List of auras with enable toggles, option tabs, sliders with numeric entry | Import strings |
| BugSack/BugGrabber | Dev | Lua error capture | Minimap/LDB icon, error browser | Error log in SavedVariables |

Local, user-installed and Forever-only: GoalNotes (wiki + goal lists, autocomplete, column grips),
OpenMap (stitched world map), ForeverDungeonJournal (journal), RavenCouncil (guild achievements,
leaderboard, comms).

## Patterns that recur (→ what the framework must make trivial)

1. **Main window + compact tracker pair.** Full window for management, small always-on frame for
   at-a-glance state. Both movable, lockable, scalable, position saved.
2. **Options built from a declarative tree** (AceConfig is the de-facto standard): groups → rows
   of toggle / slider / dropdown / colour / keybind / button. Nobody hand-places options.
3. **Sliders for every continuous value** — scale, alpha, size, spacing, distance, duration,
   count — almost always with a typed numeric field beside it and often stepper arrows.
4. **Composite rows.** The most common non-trivial control is a *toggle that owns something*:
   toggle + slider (enable + amount), toggle + dropdown (enable + sound/channel),
   toggle + cog/sub-panel (Leatrix), toggle + expandable child list (DBM ability lists,
   Baganator categories). Followed by reorderable lists and check-lists with all/none.
5. **Virtualised lists and tables**: sortable columns, resizable columns, search filtering,
   row hover highlight, row tooltips, right-click context menu.
6. **Tree + detail pane** (journal layout): collapsible categories left, content right.
7. **Tabs**: top tabs for peers, left nav for many categories.
8. **Movers / unlock mode**: a "toggle anchors" command that shows draggable placeholders.
9. **Profiles**: default/char/class profiles, copy, reset, import/export string.
10. **Tooltip augmentation** on items/units, **minimap button + addon compartment entry**,
    **slash commands**, **chat output with coloured prefix**, **reload prompt** when needed.
11. **Bars**: timer bars and meter bars (icon, label, value, fill colour, spark).
12. **Static data + lazily cached game data**: item names arrive asynchronously; every list has to
    cope with "Item 12345" turning into a name later.
13. **Other-addon data as optional dependency**: detect at runtime, degrade gracefully.

## Anti-patterns seen in the wild (→ lint rules / guidelines)

- Dropdown or button row with discretised numeric choices (`20 yd / 40 yd / 60 yd / 80 yd`,
  `Small / Medium / Large` scale) where a slider is the honest control.
- Options that only apply after `/reload` without saying so.
- Windows that cannot be closed with Escape, forget their position, or open off-screen after a
  resolution/UI-scale change.
- Unthrottled `OnUpdate` / `BAG_UPDATE` handlers; rebuilding whole lists per event.
- Hard-coded fonts (breaks CJK/Cyrillic), hard-coded English strings.
- Creating a new frame per row per refresh instead of pooling.
- Global namespace pollution; un-prefixed frame names.

## Sources

- https://endgametools.com/en/wow-forever/news/wow-forever-addons
- https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch
- https://lfcarry.com/guides/wow-forever-addons, https://conquestcapped.com/guides/wow-forever/wow-forever-addons/, https://onlyfarms.gg/guides/wow-forever-best-addons-guide/ (search summaries)
- Local install TOC files and the user's own addon sources.
