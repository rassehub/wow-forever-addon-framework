# Feature guidelines

What to build with which module, and what not to build. See [COMPONENTS.md](../COMPONENTS.md)
for signatures.

## Buildable on Forever (and how)

| Need | Use |
|---|---|
| Saved settings, profiles, per-character data | `FK:NewDB` (declare `## SavedVariables`), `FK:Options` |
| Extra lines on item tooltips (price, count, source) | `FK.Tooltip.OnItem(fn(tooltip, itemID))` |
| Item names, icons, quality (async) | `FK.Items.Info/Load/Colored` |
| Bag contents and change notifications | `FK.Bags.Scan/Count/Free`, `FK:On("fk.bags", fn)` (throttled) |
| Talking to the same addon on other players | `FK:Comm(prefix, fn)` → `comm:Send(table, channel)` (split, rate-limited, parsed safely) |
| Minimap button + compartment | `FK.MinimapButton`, `FK.Compartment` / `## AddonCompartmentFunc` |
| A key that runs a function | `FK.Keybind(key, fn)` (override binding; applies after combat) |
| An action in the game's Key Bindings menu | `FK.Binding(name, label, fn)`; `tools/fk sync` writes the `Bindings.xml` the client needs |
| Right-click menus (ticks, radio choices, submenus) | `FK.Menu(items)` or built MenuUtil style: `FK.Menu(function(m) m:Check(...) end)` |
| Movable HUD frames | `FK.Movers.Add(frame, { label, saved })`, unlock/lock commands |
| World map icons, waypoints | `FK.MapPins.Add(mapID, x, y, opts)`, `FK.MapPins.Waypoint` |
| Something protected while in combat (show secure frames, bindings) | `FK:AfterCombat(fn, key)` |
| Quest/NPC/item/object facts | `FK.Questie` (QuestieDB optional dependency) |
| Auction prices | `FK.Auction` (Auctionator optional dependency) |
| Group membership, class colours | `FK.Group`, `FK.Unit` |

## Not buildable (Midnight "secret values")

In combat, encounters and PvP, combat APIs (health, power, auras, casts, cooldowns, some unit
names) return secret values: an addon may **display** them but not **decide** on them. So:
rotation helpers, "warn when buff X drops", computed DPS/HPS, health-threshold alerts,
auto-targeting logic are out. Pass secrets straight to widgets (`ProgressBar`, `SetText`) and
use `FK.Secret.Use` for code that should only run when the value is readable. Details:
[api-constraints.md](api-constraints.md).

Also redundant on Forever (built into the client): damage meter, cooldown manager, aggro
display, click casting, raid frames.

## Third-party data

QuestieDB (GPL-3.0) and Auctionator (All Rights Reserved) are runtime optional dependencies:
`## OptionalDeps: QuestieDB` and the `FK.Questie` / `FK.Auction` bridges. Never copy their code or
data into an addon. Every answer can be nil (not installed, never scanned, unknown id) — show
why ("QuestieDB is not installed") instead of an empty list. Use `tools/fk data` to look up real
values while designing.

## Performance

- React to events, not `OnUpdate`. Bursty events go through `FK:Debounce` / `FK:Throttle`
  (`fk.bags` already is).
- Refresh lists by `SetItems` on a virtualised list; never create frames per refresh
  (`FK.Pool` for custom repeated frames).
- Expensive one-time work (name indexes, big scans) after login and spread out, not at file load.
