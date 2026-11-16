---
name: fk-test
description: Test WoW Forever addons built with ForeverKit — emulator tests (tools/fk test, the H.* vocabulary, fixtures, stubs, layout checks), lint, previews, and the live loop against the running game client through FKDev (fk link, fk live run/results). Use whenever writing or fixing tests for an addon in this repo, debugging a failing fk test, checking something "works in game", or when an addon behaves differently in the real client than in the emulator.
---

# Testing ForeverKit addons

Two loops: the Lua 5.1 emulator in `harness/` (fast, no game) and the real client via the
`FKDev` addon (truth, needs the human). Details and the full helper list:
[docs/guidelines/testing.md](../../../docs/guidelines/testing.md).

## Emulator tests

- Files: `<addon>/tests/*_test.lua`; run `tools/fk test <addon>/tests` (or `tools/fk test` for
  everything). One Lua process per file; every `test()` starts with a fresh client and fixtures.
- `local ns = H.Start(ADDON)` loads the addon and logs in; `ADDON` is the addon's folder.
- Drive it like a player: `H.Slash`, `H.Click`, `H.Enter(box, text)`, `H.Key("ESCAPE")`,
  `H.Drag`, `H.Hover` + `H.TooltipLines()`. Change the world: `H.SetBag`, `H.Fire(event, …)`,
  `H.SetCombat(true)`, `H.fixtures.*`, `H.Receive` (addon message). Time: `H.Advance(seconds)`.
- Persist: `ns = H.Reload()` keeps SavedVariables and fixtures, like `/reload`.
- Always: `eq(H.LayoutIssues(window), {})` for each window/page (in each theme if the addon has an
  Appearance page) and `eq(H.LeakedGlobals("MyAddon"), {})`.
- Optional dependencies (QuestieDB, Auctionator): put a stand-in with the public API shape in the
  test (`rawset(_G, "LibQuestieDB", fake)`); never depend on what is installed. Also test the
  "not installed" path.

The emulator is deliberately strict: unknown APIs, invisible or covered click targets, undeclared
SavedVariables and anchor cycles raise. When it says "X is not emulated", the honest fixes are
`H.Stub("C_X.Fn", fn)` in the test, or adding the API to `harness/wow/api.lua` with behaviour
you are sure of — not working around it in the addon. When a test fails, read the message first:
"covered by", "not visible", "text truncated" usually describe a real UI bug.

## Lint and previews

`tools/fk lint <addon>` (static rules + an emulator pass that runs every slash command) and
`tools/fk preview <addon> --theme … --do "…"` (PNG per theme: open and look). Both belong in
every change.

## Live loop (real client)

Needs the user at the game. Never kill the game, send it input, or delete under the WoW folder.

1. `tools/fk link MyAddon FKDev` — then the user restarts the game (new addon folders are only
   seen after a restart; changed files only need `/reload`).
2. In-game checks in the addon (with `## OptionalDeps: FKDev`):
   `if FKDev then FKDev.Test(ADDON, "name", function(assert) assert(cond, "why") end) end`.
   Good targets: `GetFileIDFromPath(path) ~= nil` for art, existence of client APIs the emulator
   only assumes, state right after login.
3. `tools/fk live run --lua "return Something()" [--tree FrameName] [--shot]`; ask the user to
   `/reload` and click the gold FKDev button (that reload writes the results).
4. `tools/fk live results -v` (errors with stacks, tests, queue output, frame dump),
   `tools/fk live shot` (newest screenshot path — open it).

When live and emulator disagree, the client wins: fix the addon or framework, then teach the
emulator the same behaviour so a test catches it next time (that is how the login
`CloseAllWindows` behaviour got into `H.Login`).
