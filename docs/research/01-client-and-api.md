# Research 01 — The WoW Forever client and its addon API

Gathered 2026-11-16 from the web and from a local install (build `1.60.1.70938`, product `wowf`).
Anything marked **(local)** was observed on disk in addons that only target interface 16001, which
is the strongest evidence available that an API works on Forever.

## What the client is

- Vanilla-style game on the **modern (Mainline) client**. Blizzard: Forever "shares Mainline WoW's UI
  architecture, including the vast majority of APIs available in 12.1.5".
- Game version `1.60.1`, **`## Interface: 16001`**. Classic Era addons (`11509`) do not load.
- Game type is internally `Camelot`; `Forever` is an accepted alias. TOC suffixes
  `MyAddon_Forever.toc` / `MyAddon_Camelot.toc` both work **(local: Questie ships both)**.
- Install folder: `World of Warcraft/_forever_/Interface/AddOns/<Addon>/<Addon>.toc`.
- SavedVariables: `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/<Addon>.lua` (account) and
  `.../<ACCOUNT>/<Realm>/<Character>/SavedVariables/<Addon>.lua` (per character). Written on
  `/reload`, logout and exit only.
- Lua is 5.1-based. `require` was renamed `import` in 1.60.1 (irrelevant for addons, do not use either).
- `/dump select(4, GetBuildInfo())` prints the interface number in game.

## The addon restrictions inherited from Midnight ("secret values")

This is the single biggest difference from Classic addon development.

- In combat, encounters, PvP matches and some instances, combat APIs (`UnitHealth`, aura data,
  cast info, some unit names, cooldowns…) return **secret values** to addon code.
- Allowed with a secret: store it, pass it to Lua functions, concatenate (`..`), `string.format`,
  `type()`, truthiness test of non-booleans, and **pass it to widget setters that accept secrets**
  (`FontString:SetText`, `StatusBar:SetValue/SetMinMaxValues`, `SetAlpha`, `SetShown`,
  `Cooldown:SetCooldown`…).
- Immediate Lua error: arithmetic, comparison (`==`, `<`), `#`, using it as a table key, indexing
  it, calling it, boolean test of a secret boolean.
- A widget that received a secret gets a *secret aspect*: its getters (`GetText`, `GetValue`,
  `IsShown`…) return secrets too, and layout that depends on it becomes secret.
- Detection: `issecretvalue(v)`, `canaccessvalue(v)`, `issecrettable(t)`, `canaccesstable(t)`.
- Display helpers that work on secrets without reading them: `C_CurveUtil.CreateCurve()`,
  `C_CurveUtil.CreateColorCurve()`, `C_DurationUtil.CreateDuration()`,
  `StatusBar:SetTimerDuration()`.
- Test without being in combat: CVars `addonCombatRestrictionsForced`,
  `addonEncounterRestrictionsForced`, `addonMapRestrictionsForced`,
  `addonChatRestrictionsForced`, `addonPvPMatchRestrictionsForced` (not saved across restarts).

Design consequence: **an addon may display combat data but may not decide on it.** Rotation
helpers, "warn me when buff X drops" and computed combat stats are not buildable. Quest, map,
bag, auction, profession, social, collection and configuration addons are unaffected.

Other 1.60.1 changes relevant to authors:

- `SendChatMessage` with `EMOTE` needs a hardware event outside instances (as `SAY`/`YELL`).
- Creature/object GUID server and spawn parts are obfuscated (stable within a session only).
- Addons cannot read minimap rotation during encounters; player reports say minimap gathering
  nodes are no longer readable (record nodes on gather instead).
- `GetFrameStrata` can return a secret.
- Player/target/pet/focus frames and the minimap header were reskinned: do not anchor to their
  child regions by name.
- Trial accounts cannot send addon messages.
- Beta reports of settings not surviving restarts: keep SavedVariables small and valid.

## APIs confirmed in Forever-only addons (local)

| Area | Confirmed |
|---|---|
| Frame types | `Frame`, `Button`, `CheckButton`, `EditBox`, `ScrollFrame`, `Slider`, `StatusBar`, `GameTooltip`, `PlayerModel` |
| Templates | `BackdropTemplate` (by far the most used), `UIPanelButtonTemplate`, `InputBoxTemplate`, `UIPanelCloseButton`, `UIPanelScrollFrameTemplate`, `UICheckButtonTemplate`, `SearchBoxTemplate`, `OptionsSliderTemplate`, `MinimalSliderWithSteppersTemplate`, `ButtonFrameTemplate`, `PanelTabButtonTemplate`, `SecureActionButtonTemplate` |
| Options | `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory` |
| Menus | `MenuUtil.CreateContextMenu` (modern), `UIDropDownMenu_*` (legacy, still present) |
| Tooltips | `TooltipDataProcessor.AddTooltipPostCall`, `C_TooltipInfo.GetItemByID` |
| Items | `C_Item.GetItemInfo`, `GetItemInfoInstant`, `GetItemIconByID`, `GetItemNameByID`, `GetItemCount`, `RequestLoadItemDataByID`, `IsItemDataCachedByID` |
| Bags | `C_Container.GetContainerNumSlots` (and the rest of `C_Container`) |
| Maps | `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition`, `GetMapInfo`, `SetUserWaypoint`, `OpenWorldMap` |
| Quests | `C_QuestLog.*` (`GetInfo`, `IsQuestFlaggedCompleted`, `GetQuestObjectives`, …) |
| Misc | `C_Timer.After/NewTicker`, `C_AddOns.IsAddOnLoaded/GetAddOnMetadata`, `C_ChatInfo.SendAddonMessage/RegisterAddonMessagePrefix`, `C_Texture.GetAtlasInfo`, `SetAtlas`, `C_CVar.SetCVar`, `C_EncodingUtil.DecompressString`, `hooksecurefunc`, `InCombatLockdown`, `StaticPopup_Show`, `ColorPickerFrame:SetupColorPickerAndShow`, `EventRegistry`, `issecretvalue`, `canaccessvalue` |
| TOC | `## IconTexture`, `## AddonCompartmentFunc` (+`OnEnter`/`OnLeave`), `## Category`, `## OptionalDeps`, `## LoadSavedVariablesFirst`, `[AllowLoadGameType …]` conditions |

Not present / different: War Mode (`C_PvP.IsWarModeFeatureEnabled()` is false), most retail-only
systems (talent trees UI, Mythic+). Check with `C_EventUtils.IsEventValid(event)` before
registering an event that may not exist.

## Classic art still ships

Forever-only addons use the old texture files successfully **(local)**:
`Interface\DialogFrame\UI-DialogBox-Background`, `UI-DialogBox-Border`, `UI-DialogBox-Header`,
`Interface\Tooltips\UI-Tooltip-Border`, `Interface\Buttons\WHITE8X8`, `Interface\Icons\*`.
The framework's Vanilla theme is built on these.

## Sources

- https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- https://warcraft.wiki.gg/wiki/Secret_Values
- https://endgametools.com/en/wow-forever/news/wow-forever-addons
- https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch
- Local install, addons targeting only `16001`: GoalNotes, OpenMap, GatherLite, ForeverDungeonJournal, RavenCouncil, QuestieTrace.
