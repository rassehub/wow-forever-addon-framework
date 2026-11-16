# Testing guidelines

Two loops (research [04](../research/04-testing.md)): the emulator for everything fast, the real
client through FKDev for what only the client knows.

## The pyramid, in order

1. `tools/fk lint <addon>` — TOC, removed APIs, secret-value misuse, UI rules, global leaks,
   layout. Errors must be fixed; `fk build` refuses to package with errors.
2. `tools/fk test <addon>/tests` — emulator tests (one Lua process per file).
3. `tools/fk preview <addon> --theme pixel,vanilla,glass,parchment --do "<lua>"` — PNG per theme;
   look at them.
4. `tools/fk link <addon>` + `tools/fk live run|results` — the real client (needs the human).

## Writing emulator tests

Files are `<addon>/tests/*_test.lua`. Each `test(name, fn)` starts from a fresh client.

```lua
test("goal counts follow the bags", function()
    local ns = H.Start(ADDON)               -- load the addon, log in; returns its namespace
    H.Slash("/goals add 2589 30")            -- slash commands
    H.SetBag(0, 3, 2589, 10)                 -- change fixture bags (fires the bag events)
    H.Advance(1)                             -- virtual time: timers, throttles, OnUpdate
    eq(ns.Lines()[1].value, "30/30")
    eq(H.LayoutIssues(ns.window), {})        -- nothing clipped, overflowing or off screen
    ns = H.Reload()                          -- SavedVariables round-trip
    eq(H.LeakedGlobals("MyAddon"), {})
end)
```

Vocabulary: `H.Click/Hover/Drag/Wheel`, `H.Enter(box, text)`, `H.Type`, `H.Key("ESCAPE")`,
`H.Slash`, `H.Fire(event, ...)`, `H.Advance(s)`, `H.SetCombat(bool)` (secrets on),
`H.SetBag`, `H.CacheItem`, `H.ShowItemTooltip(id)` + `H.TooltipLines()`, `H.Receive` (addon
message), `H.PressBinding(key)`, `H.Find(root, text)`, `H.Tree(root)`, `H.Stub("C_X.Fn", fn)`,
`H.fixtures` (player, items, bags, units, group). Assertions: `eq`, `near`, `ok`, `raises`.

What to test for every addon: each slash command; each window lays out cleanly in every theme;
settings round-trip through `H.Reload()`; behaviour in combat (`H.SetCombat(true)`) if it shows
combat data; missing optional dependencies (stand-in tables with the public API shape, never the
installed addon).

The emulator is strict on purpose: unknown APIs raise "not emulated" — stub them in the test with
`H.Stub` and note it, rather than guessing their behaviour in the addon.

## Live loop

1. `tools/fk link MyAddon FKDev` once (then restart the game; new folders need a restart).
2. In the addon: `## OptionalDeps: FKDev` and in-game checks:
   `if FKDev then FKDev.Test(ADDON, "name", function(assert) assert(cond, "message") end) end`.
3. `tools/fk live run --lua "return Something()" [--tree FrameName] [--shot]`, ask the human to
   `/reload` and click the FKDev button, then `tools/fk live results` (errors, tests, queue
   output, frame dump in the emulator's format).

Use the live loop for: texture paths (`GetFileIDFromPath`), client APIs the emulator only
assumes, timing of real events, taint/combat lockdown, how a theme really looks.
