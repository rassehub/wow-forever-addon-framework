---
name: fk-api
description: The WoW Forever client's addon API rules for ForeverKit code — Interface 16001, Lua 5.1, C_* namespaces instead of removed globals, Midnight "secret values" (what you may and may not do with combat data), combat lockdown and protected actions, login/loading order, globals, addon messages, async item data. Use whenever writing or reviewing WoW addon Lua for Forever, when an addon errors in combat or right after login, when deciding whether a feature is possible at all, or when lint reports deprecated-api, secret-compute, global-leak or similar.
---

# Forever API rules

Full list with sources: [docs/guidelines/api-constraints.md](../../../docs/guidelines/api-constraints.md).

## The ones that bite

1. **Secret values.** In combat, encounters and PvP, `UnitHealth`, power, auras, casts, cooldowns
   (and more) return secrets. Arithmetic, comparison, `#`, indexing, table keys and boolean tests
   on them raise errors. You may store, pass, concatenate, `string.format`, and hand them to widget
   setters (`SetText`, `StatusBar:SetValue`, `SetAlpha`, `SetShown`). So: display yes, decide no.

   ```lua
   bar:SetValue(UnitHealth("target"))                              -- fine, even in combat
   if UnitHealth("target") < 1000 then … end                       -- raises in combat (lint: secret-compute)
   FK.Secret.Use(UnitHealth("target"), function(hp) … end, nil)    -- runs only when readable
   ```

   If a feature needs to decide on combat data, it is not buildable; say so instead of hiding the
   check behind a pcall.

2. **Combat lockdown.** Protected actions (secure frames, override bindings, Settings panel
   navigation) fail in combat. Use `FK:AfterCombat(fn, key)`; ForeverKit windows themselves are
   not protected.

3. **Loading order.** SavedVariables exist from `FK:OnLoad`; the world from `FK:OnLogin`. On
   entering the world the default UI closes every Escape-closable window (verified in game) —
   `FK.Window:Open()` already waits for that; hand-made frames in `UISpecialFrames` must show
   again after `PLAYER_ENTERING_WORLD`.

4. **Modern API only.** `C_Item`, `C_Container`, `C_AddOns`, `C_Spell`, `C_ChatInfo`, `Settings.*`;
   the old globals are gone (lint: deprecated-api). Item info is nil until cached:
   `FK.Items.Load(id, fn)`.

5. **No globals.** `local ADDON, ns = ...; local FK = ns.FK`. Only the names the client looks up
   are global: SavedVariables, slash command tables (`FK:Slash` makes them), the
   `## AddonCompartmentFunc` function, override-binding buttons (`FK.Keybind` makes them).
   Tests check `H.LeakedGlobals`.

6. **Pure Lua, primitives.** No XML frames and no Blizzard templates except `BackdropTemplate`;
   use ForeverKit widgets (they are themed and emulated).

## When unsure whether an API exists on Forever

Check the table in api-constraints.md; if it is not there, don't assume. Add an in-game check via
the `fk-test` skill's live loop (`FKDev.Test` asserting the function exists) and say it is
unverified until the user runs it.
