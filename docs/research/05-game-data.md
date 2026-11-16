# Research 05 — Game data sources: QuestieDB, Auctionator, the client

## QuestieDB (local: v1.0.13, contract 4, `X-Flavor: Forever`, mode `baked`)

Standalone addon that Questie consumes; "nothing here assumes Questie". GPL-3.0 — **depend on it
at runtime (`## OptionalDeps: QuestieDB`), never copy its data or code into an addon** unless that
addon is GPL-3.0 too.

Runtime surface (global `LibQuestieDB`, plus shorthand globals `QuestDB`, `NpcDB`, `ItemDB`,
`ObjectDB`):

```lua
local Q = LibQuestieDB
if Q and Q.RequireContract(4) then            -- range check, returns ok, message
  local name   = Q.Item.name(itemId)          -- one accessor per field
  local drops  = Q.Item.npcDrops(itemId)      -- NpcId[]
  local vendors= Q.Item.vendors(itemId)
  local ids    = Q.Item.IdsByName("Linen Cloth")  -- exact name → ids (builds an index on first use)
  local a, b   = unpack(Q.Item.GetAll(itemId, { "name", "itemLevel" }))
  local exists = Q.Npc.Exists(npcId)
end
```

- Entities: `Item`, `Npc`, `Object`, `Quest`. Each has per-field accessors, `Get(id, key)`,
  `GetAll(id, keys)`, `GetRaw`, `Exists`, `IdsByName`, `BuildNameIndex[Async]`.
- Item fields: `name, npcDrops, objectDrops, itemDrops, startQuest, questRewards, flags, foodType,
  itemLevel, requiredLevel, ammoType, class, subClass, vendors, relatedQuests, teachesSpell`.
- Npc fields: `name, minLevel, maxLevel, rank, spawns, waypoints, zoneID, questStarts, questEnds,
  factionID, friendlyToFaction, subName, npcFlags`.
- Object fields: `name, questStarts, questEnds, spawns, zoneID, factionID, waypoints`.
- Quest fields: `name, startedBy, finishedBy, requiredLevel, questLevel, requiredRaces,
  requiredClasses, objectivesText, triggerEnd, objectives, sourceItemId, preQuestGroup,
  preQuestSingle, childQuests, inGroupWith, exclusiveTo, zoneOrSort, requiredSkill,
  requiredMinRep, requiredMaxRep, requiredSourceItems, nextQuestInChain, questFlags,
  specialFlags, parentQuest, reputationReward, breadcrumbForQuestId, breadcrumbs,
  extraObjectives, requiredSpell, requiredMaxLevel, …`.
  The authoritative list is `QuestieDB/Types/*.t.lua` and `LibQuestieDB.Meta.<Entity>Meta`.
- Spawn/zone value shapes are **not yet verified here** — step 9 of the plan loads the DB in the
  emulator and documents the real shapes. `Q.EraToForever(areaId, x, y)` converts Era-sourced
  zone percentages (0–100) and must never be applied to points that are already Forever's.
- `BuildNameIndex` is a full pass over all names: run `BuildNameIndexAsync` in a coroutine, not
  at login.
- Baked mode stores rows in TOC metadata; they are only readable through the accessors.

Offline use (designing an addon, generating a static table): the framework loads the installed
QuestieDB into the emulator and queries the same accessors — `fk data item|npc|quest|object …`.
The output is for *looking things up*; shipping extracted rows inside a non-GPL addon is not OK.

## Auctionator (local: v347; licence: All Rights Reserved)

Its repository carries an `AGENTS.md` asking AI agents not to use the source as a reference, and
the licence does not permit copying. The framework therefore touches **only the documented public
API**, at runtime, as an optional dependency:

```lua
local A = Auctionator and Auctionator.API and Auctionator.API.v1
local copper = A and A.GetAuctionPriceByItemID("MyAddon", itemId)     -- nil if never scanned
local copper = A and A.GetAuctionPriceByItemLink("MyAddon", itemLink)
A.MultiSearch("MyAddon", { "Linen Cloth", "Wool Cloth" })              -- AH must be open
```

Its v1 folder also has files for disenchant price, "is the price exact", DB-update registration
and shopping lists; the README documents only the three calls above, so treat the rest as
unverified and read that README before using them.

- `callerID` is your addon's name (a string); calls error without it.
- Prices are per realm/faction, as old as the user's last scan; always handle `nil`.
- Wrap calls in `pcall` — a third-party API can change.
- Offline: prices live in the user's `SavedVariables/Auctionator.lua` in an internal encoding.
  We do not parse it; for offline design work use an in-game dump through the live loop
  (`fk live run --lua` calling the API for a list of item ids).
- TradeSkillMaster alternative: `TSM_API.GetCustomPriceValue("dbmarket", "i:"..id)` (from
  memory of TSM's public API, not verified on Forever).

## The client itself

- Items: `C_Item.GetItemInfo(id)` returns nil until cached. Use
  `Item:CreateFromItemID(id):ContinueOnItemLoad(fn)` or `C_Item.RequestLoadItemDataByID` +
  `GET_ITEM_INFO_RECEIVED` / `ITEM_DATA_LOAD_RESULT`. Instant, always available:
  `C_Item.GetItemInfoInstant` (class, subclass, equip slot, icon).
- Vendor price: 11th return of `GetItemInfo`. Tooltip text: `C_TooltipInfo.GetItemByID`.
- Spells: `C_Spell.GetSpellName/GetSpellTexture/GetSpellInfo`.
- Maps: `C_Map.*`; quests: `C_QuestLog.*`; professions: `C_TradeSkillUI.*`; bags: `C_Container.*`.
- `/api` in game browses Blizzard's generated API documentation, including which functions return
  secrets (`SecretReturns`, `SecretArguments`).
- `ExportInterfaceFiles code` / `art` at the login-screen console (`-console` launch flag) dump
  Blizzard's FrameXML source and art to `_forever_/BlizzardInterfaceCode|Art` — the authoritative
  reference for templates and atlases when needed.

## Sources

- Local: `QuestieDB/src/api.lua`, `QuestieDB/Types/*.t.lua`, `Auctionator/Source/API/v1/README.md`, `Auctionator/LICENSE`.
- https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
