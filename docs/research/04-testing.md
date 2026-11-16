# Research 04 — Testing: live against the real client, and emulated

## Options surveyed

| Approach | What it is | Verdict |
|---|---|---|
| **wowless** (github.com/wowless/wowless) | Headless client: real Blizzard FrameXML on a taint-aware Lua 5.1 fork | Highest fidelity, but pre-alpha, Docker-only, documents only retail (`wow`), and its own README says errors are probably wowless's. Not a base to build on; noted as an optional extra. |
| **Mechanic** (github.com/Falkicon/Mechanic) | In-game hub + desktop dashboard + sandbox with generated API stubs; TOC targets 120100 and 16001 | Confirms the workable live loop: results leave the game through **SavedVariables on /reload**; commands enter the game as queued Lua executed after reload. We reuse the idea, not the code. |
| WoWUnit / wowUnit | In-game unit test frameworks | In-game only; fine but needs the client for every run. |
| busted + hand mocks | Standard Lua test runner with a mocked `_G` | Common. Needs luarocks; mocks are per-project. |
| WoWBench, rilua | Old emulator / Rust Lua 5.1 port | Abandoned / too low-level. |

## Decision: two loops

### 1. Emulated loop (fast, runs anywhere, no game) — `harness/`

A purpose-built emulator in plain Lua 5.1 (compiled locally by `tools/setup.sh`, no packages):

- Loads an addon exactly as the client does: parse the `.toc`, run each Lua file with
  `(addonName, namespace)`, then fire `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`.
- Implements the **widget primitives** (Frame, Button, CheckButton, Slider, EditBox, ScrollFrame,
  StatusBar, Texture, FontString, GameTooltip) including anchors and a real layout pass, so tests
  can assert on rectangles, visibility, text and overflow.
- This is why **ForeverKit builds every widget from primitives** and never inherits Blizzard XML
  templates: the emulator then covers 100% of the library, and themes control every pixel.
- Virtual clock (`C_Timer`, `GetTime`, `OnUpdate`), event injection, simulated clicks, drags,
  typing, mouse wheel; SavedVariables round-trip (write, reload, read).
- **Secret-value simulation**: opaque values that raise on arithmetic/indexing/ordering and taint
  widget getters, to catch combat-restriction bugs offline. Limit: Lua 5.1 cannot intercept `==`
  between a secret and a plain number, so equality tests on secrets are caught by lint, not by
  the emulator.
- Output for humans and agents: a **text frame tree** (cheap for an AI to read) and an **HTML
  render** (flat colours exact, Blizzard art approximated from a lookup table) that can be
  screenshotted with headless Firefox (`/usr/bin/firefox --screenshot`, present locally).

What it cannot tell you: real texture art, real font metrics (width is estimated), taint and
protected-function behaviour, the real timing of async item data. Those need loop 2.

### 2. Live loop (real client) — `FKDev` addon + `tools/fk live`

Facts that shape it:

- The client reads addon Lua files at login and on `/reload`. A brand-new addon folder needs a
  client restart (or at least a return to character select) to be listed. Whether a changed file
  list in an existing TOC is picked up by `/reload` alone is **to be verified in step 10**.
- A Windows client under Wine follows Linux **symlinks**, so `fk link <addon>` symlinks the working
  copy into `_forever_/Interface/AddOns/`. (Local setup: Lutris/Wine prefix at
  `/mnt/data/BattleNet`, Wayland/KDE.)
- The only file channel out of the game is SavedVariables, flushed on `/reload`/logout. The only
  channel in is Lua files loaded at `/reload`.
- Under Wayland there is no reliable way to type `/reload` for the user (`xdotool`/`ydotool` not
  installed), and injecting input into a live game session is intrusive. **A human presses the
  reload key**; everything else is automated.

Loop:

1. `fk live run <addon> [--lua "<snippet>"]` writes `FKDev/Queue.lua` (commands to run after
   load) and prints "reload the UI now".
2. Human: `/reload` (FKDev binds it to a key and adds `/rl`).
3. On load FKDev installs an error handler (`seterrorhandler` + `ADDON_ACTION_BLOCKED`,
   `ADDON_ACTION_FORBIDDEN`, `LUA_WARNING`), runs the addon's registered in-game tests and the
   queue, records results, frame dumps and errors into `FKDevDB`.
4. Human: `/reload` again (or FKDev does it itself via `C_UI.Reload()` right after the run — a
   reload triggered from the same execution path as the user's hardware event is allowed; if it is
   blocked FKDev prints "reload once more").
5. `fk live results` parses `WTF/Account/*/SavedVariables/FKDev.lua` and prints errors, test
   results and the frame dump in the same text format as the emulator → **emulated and live
   output can be diffed**.
6. Screenshots: the in-game `Screenshot()` API writes to `_forever_/Screenshots/`; `fk live shot`
   returns the newest file. FKDev can call `Screenshot()` after opening a window.

Built-in client tools worth using in the live loop: `/fstack` (frame stack), `/etrace` (event
trace), `/api` (API docs browser), `/tinspect`, `/dump`, `/console scriptErrors 1`,
`/console taintLog 1` (writes `Logs/taint.log`), the secret-restriction CVars from
[01](01-client-and-api.md), and BugSack if installed.

## Test pyramid for an addon built with the framework

1. `fk lint` — static: TOC sanity, globals leak, forbidden APIs, secret-unsafe patterns, UI rules
   (e.g. enumerated numeric choices that should be a slider).
2. `fk test` — emulator: logic + UI behaviour, SavedVariables migration, every option round-trips.
3. `fk preview` — emulator render per theme, checked by eye (or by the agent via screenshot).
4. `fk live` — the real client: art, fonts, taint, combat restrictions (forced CVars), async data.

## Sources

- https://github.com/wowless/wowless
- https://github.com/Falkicon/Mechanic
- https://warcraft.wiki.gg/wiki/Secret_Values (restriction CVars)
- Local environment inspection (2026-11-16).
