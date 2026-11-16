# ForeverKit — WoW Forever addon framework

Framework + tooling + skills for building World of Warcraft **Forever** addons
(`## Interface: 16001`, modern client API, Midnight "secret value" restrictions).

## Building the framework itself: "next step"

When asked to "pick up the next step" / "continue":

1. Read `docs/PLAN.md`. The first unticked step in **Status** is the job; its section says what
   to deliver and when it is done. Read **Decisions** and **Notes from earlier steps**.
2. Work on branch `build/foreverkit`. Do the step. Run `tools/fk test`.
3. Tick the step, append a short dated note (what exists, what was learned, what was skipped),
   commit. Then continue with the following step unless told otherwise.

Do not redo research: `docs/research/` holds what was found and where.

## Rules that always apply

- Target is Forever only. Lua 5.1. No XML, no Blizzard widget templates except
  `BackdropTemplate` (PLAN decision 2).
- Library code attaches to the addon namespace (`local _, ns = ...; local FK = ns.FK`), never
  to `_G`.
- A numeric setting is a slider, not a list of preset numbers (PLAN decision 5).
- Combat data may be displayed but not computed on (secret values) — see
  `docs/research/01-client-and-api.md`.
- QuestieDB and Auctionator are runtime optional dependencies used through their public API.
  Never copy their code or data into this repo.
- Never write the Battle.net account folder name or character names into tracked files.
- The game may be running. Never kill it, never send it input, never delete anything under the
  WoW directory. Only `fk link` (symlinks) and `fk live` (files inside `FKDev/`) write there.
