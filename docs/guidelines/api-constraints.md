# API constraints on WoW Forever

Facts an addon must respect. Background and sources: research
[01](../research/01-client-and-api.md); verified in game where marked.

## Target

- `## Interface: 16001`, Lua 5.1, the modern client API (`C_*` namespaces). No Classic Era or
  retail compatibility code. Removed globals (`GetItemInfo`, `GetContainerItemInfo`,
  `UIDropDownMenu_*` for new code, `getglobal`) are lint errors *(checked)*.
- Pure Lua; no XML frames; no Blizzard widget templates except `BackdropTemplate`
  (ForeverKit widgets cover the rest).
- Code lives in the addon namespace: `local ADDON, ns = ...; local FK = ns.FK`. Globals only
  where the client requires a name (SavedVariables, `SLASH_*`, `## AddonCompartmentFunc`,
  override-binding buttons) *(checked: `global-leak`, `global-function`)*.

## Secret values (Midnight restrictions)

In combat, encounters, PvP matches and some instances, combat APIs return secret values.

| Allowed with a secret | Raises an error |
|---|---|
| store it, pass it to functions, `..`, `string.format`, `type()` | arithmetic, `<`/`>`/`==` comparison |
| truthiness of non-booleans | `#`, indexing it, using it as a table key, calling it |
| widget setters: `SetText`, `StatusBar:SetValue/SetMinMaxValues`, `SetAlpha`, `SetShown`, `Cooldown:SetCooldown` | boolean test of a secret boolean |

A widget that received a secret returns secrets from its getters. Detect with
`issecretvalue(v)` / `FK.Secret.Is(v)`; branch with `FK.Secret.Use(v, fn, fallback)`. Test
without combat: `/console addonCombatRestrictionsForced 1` (resets on restart); in the emulator
`H.SetCombat(true)`. Lint catches the common `UnitHealth(..) <` pattern, not every data flow.

## Combat lockdown

Protected actions are blocked in combat (`InCombatLockdown()`): showing/moving secure frames,
`SetOverrideBinding*`, `Settings.OpenToCategory`. Queue them with `FK:AfterCombat(fn, key)`.
ForeverKit's own windows are not secure and work in combat.

## Login and loading order (verified in game, step 10)

- Saved variables exist from `ADDON_LOADED` (`FK:OnLoad`), not at file load.
- `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD`; on the latter the default UI calls
  `CloseAllWindows()`, hiding every `UISpecialFrames` window. `FK.Window:Open()` handles it
  (`FK.inWorld`, `fk.world`); hand-made Escape-closable frames must show again after it.
- A newly added addon folder needs a game restart; changed files need `/reload`.

## Other facts

- Item data is asynchronous: `C_Item.GetItemInfo` is nil until cached (`FK.Items.Load`).
- `SendChatMessage` to SAY/YELL/EMOTE needs a hardware event outside instances.
- Addon messages: prefix ≤ 16 chars, message ≤ 255 bytes (`FK:Comm` handles both); trial
  accounts cannot send.
- GUIDs' server/spawn parts are obfuscated (stable within a session only).
- `GetFrameStrata` can return a secret; do not anchor to children of the reskinned
  player/target/minimap frames by name.
- Addon art (verified in game, step 13): PNG files shipped in an addon load, including files
  added to an existing addon folder with only a `/reload`. `Texture:SetTexture(path)` returns
  `true` even when the file does not exist, so loading cannot be checked in code — use the
  emulator's "texture file missing" layout check and look at an in-game screenshot.
- `C_Timer.After(s, fn)` rejects client (C) functions as `fn`: wrap them,
  `C_Timer.After(1, function() Screenshot() end)`.
- `debugstack()` names the running file's path (`Interface/AddOns/<Addon>/...`); `FK.Media`
  uses it to find the library wherever it is embedded.
- The minimap (measured in game, step 14; `FK.MinimapSkin` follows all of this):
  - It always renders as a square. `Minimap:SetSize(w, h)` with w ≠ h breaks the map, and a
    clipping parent does not cut it. Rectangles are a square map under a band mask; addon PNGs
    work as masks. Round mask: `Interface\Masks\CircleMaskScalable`; square: `WHITE8X8`.
  - With `rotateMinimap` on, the client turns the whole masked square: only round maps can rotate.
  - If part of the square is off screen, the client squeezes the map into the visible part: keep
    the whole square on screen (a wide band cannot reach the screen edge).
  - The map redraws only when the player moves; a zoom step and back redraws it at once.
  - The client's rings (`MinimapCompassTexture`, and `MinimapCompassTextureUnderlay` while
    rotating) fit only the default round map; the client resets their size. Textures have no
    `OnShow`: keep them hidden by hooking `Show`/`SetShown`.
  - Other addons' buttons (LibDBIcon) fade to alpha 0 when the mouse leaves the minimap.
  - Pins of other addons (Questie, gathering) are frames over the whole square: a band mask does not
    hide them; `FK.MinimapSkin` hides those outside the band.
- Verified present (1.60.1): `WorldMapFrame.ScrollContainer.Child` and `OnMapChanged` at login,
  `AddonCompartmentFrame`, `SetOverrideBindingClick`, `TooltipDataProcessor`, `C_EncodingUtil`,
  `UiMapPoint` / `C_SuperTrack` / `C_Map.SetUserWaypoint`, `GetFileIDFromPath`, every texture
  used by the built-in themes. Not yet verified: `C_Map.GetAreaInfo`.
