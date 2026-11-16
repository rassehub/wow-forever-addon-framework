---
name: fk-gamedata
description: Use World of Warcraft Forever game data in ForeverKit addons — QuestieDB (quests, NPCs, items, objects, spawns, drops, vendors) through FK.Questie, auction prices through Auctionator via FK.Auction, item/bag/map data from the client, and offline lookups with `tools/fk data`. Use whenever an addon needs to know where something drops, who sells it, quest givers or objectives, NPC locations, coordinates, or prices, or the user asks "what does QuestieDB say about X" — and always before relying on a data shape from memory.
---

# Game data for ForeverKit addons

Background, licences and verified value shapes: [docs/research/05-game-data.md](../../../docs/research/05-game-data.md).

## Licences decide the architecture

QuestieDB is GPL-3.0; Auctionator is All Rights Reserved and asks AI agents not to use its
source. So both are **runtime optional dependencies** used through their public APIs only:
`## OptionalDeps: QuestieDB, Auctionator` in the TOC and the `FK.Questie` / `FK.Auction`
bridges. Never copy their code or data (including `fk data` output) into an addon, and don't read
Auctionator's source.

## Look before you code

```sh
tools/fk data item "Linen Cloth"          # exact, case-sensitive name or an id
tools/fk data npc 448 --fields spawns,zoneID
tools/fk data quest 33 --raw --json
```

This loads the installed QuestieDB in the emulator (~1 s) and prints real rows, with linked ids
named. Check the actual shape before writing code that walks it; several fields are not what
their names suggest:

- `spawns`: `{ [zoneID] = { { x, y }, … } }`, x/y 0–100; zoneID is an area id (name via
  `C_Map.GetAreaInfo`), not a uiMapID.
- Drop/vendor/quest lists are flat id lists, **nil when empty**; empty scalars read as `0`.
- Quest `startedBy`/`finishedBy` = `{ npcIds, objectIds, itemIds }`; `objectives` is sparse
  `{ [1] = creatures, [2] = objects, [3] = items }`.
- Common items can have no `npcDrops` at all: answers can be incomplete by design — say so in the UI.

## Runtime API

```lua
if FK.Questie.Available() then
    local ids = FK.Questie.Find("Item", "Linen Cloth")          -- exact name; builds an index on first use
    local src = FK.Questie.ItemSources(ids[1])                    -- { npcs, objects, items, vendors }
    local name = FK.Questie.Get("Npc", src.npcs[1], "name")
    local pts = FK.Questie.Spawns(448)                            -- { { zoneID, x, y } }
end
local copper = FK.Auction.Price(itemIDOrLink)                     -- nil: not installed or never scanned
```

Every call returns nil when the addon is missing, the id is unknown or its API changed (calls are
`pcall`ed and warn once). Design for nil: show "QuestieDB is not installed or not enabled" rather
than an empty list. Avoid `Find` at login on large data; call it on demand.

Client data: `FK.Items.Info/Load` (item data arrives asynchronously — refresh when it does),
`FK.Bags.*`, `C_Map.*`. In tests, replace QuestieDB/Auctionator with small stand-ins of the same
public shape (see `examples/ItemSources/tests`).
