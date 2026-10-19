# Levels as data, waves of kinds, and a results screen

**Date:** 2026-10-18. **Issue:** #62, step 5 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan, with Ben at the keyboard. Ben has not reviewed the numbers yet.

**Status: proposed.** It makes the melee the first level: a `Level` resource is a stage width and a list of arenas, each a list of waves, each a count of every kind of small fry. The arenas of #58 (`docs/design/2026-10-17-camera-and-scrolling-stage.md`) take their waves from it, and a results screen closes the level. Every number is data to tune by playing.

## What it does

- **A level is data** (`data/levels/melee.tres`, "The camp"): three screens wide, two arenas. Arena one, 0 to 2,400: a wave of 8 plain and 2 fast, then 6 plain, 2 fast, a shielded one and a thrower. Arena two, 3,360 to 5,760: 6 plain, 3 fast and a thrower, then 8 plain, 3 fast, 2 shielded and 2 throwers. A wave's kinds are spread through it, rarest first, so the thrower and the shield never arrive last or sorted.
- **Clear, walk on, as before:** the camera locks in an arena until its waves are beaten, GO points on, the next arena locks.
- **A results screen** when the last arena is beaten: **LEVEL CLEAR**, then the time (the clock runs while someone is alive and stops on the clear), the hits each player took (blocked hits don't count), the best combo seen, and the keys: R to go again, Tab then M for the menu. Going down shows DOWN as before, with no results.
- The menu's Melee starts it. F6 still adds a sandbox wave of ten with its own mix.

## How it is built

- `Level`, `ArenaData` and `WaveData` (`scenes/levels/`) are resources. `WaveData.kind_at(i)` spreads the kinds. `Arenas.setup_level` turns a level into its arena list, and sends the wave itself to the stage's spawn callable, which places each body as its kind.
- `Body.hits_taken` counts hits that land, reset when the body is placed; the stage keeps the level's ticks and the best combo, and `PocStage.results()` returns the three.

## Proposed: choices made while building, to confirm or change

- **Hits taken counts hits, not damage.** A jab and a bash count the same. Damage taken, or health left, could be shown too.
- **The best combo is the counter's best**, the attacker's hits in a row on anyone, as the combo counter counts.
- **No rating or score yet.** The three numbers are what the plan asked for; a rank from them is a later choice.
- **Spawn positions and gaps stay the arenas'**: a wave comes when four or fewer stand, at least two seconds after the last, from off screen.
- **One level.** The menu goes straight to it; a level select comes with a second level.
