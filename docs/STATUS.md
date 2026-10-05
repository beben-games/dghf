# Status

**Updated 2026-10-04.** Where the project stands, for a person or a Claude starting a new session. Read it after `CLAUDE.md`. Update it at the end of a working session: it is a snapshot, and the issues, the game bible and the design specs stay the sources of truth.

## In one paragraph

Setup is done. Milestone 1 is under way. There is a playable proof of concept on `main`: one character on an empty 1080p stage who walks, jumps, crouches, changes lane, attacks on the ground and in the air, and throws a fireball, and a training dummy that takes the hits. The technical base of the combat core is decided, and everything a player feels (lanes, controls, screen and sprite size) is still proposed and waiting for a weekly meeting with all three. T was not available the week of 2026-10-04.

## What runs today

| What | Where | How |
|---|---|---|
| The proof of concept (the main scene) | `scenes/levels/poc_stage/` | `scripts/run.sh`, or F5 in the editor |
| The crowd stress test | `scenes/stress_test/` | `scripts/run.sh res://scenes/stress_test/stress_test.tscn` (add `-- --benchmark` for the timed table) |
| The fighter test | `tests/poc_player_test.gd` | `godot --headless --path . -s tests/poc_player_test.gd` prints `all passed` |
| The hits test | `tests/hits_test.gd` | `godot --headless --path . -s tests/hits_test.gd` prints `all passed` |
| Windows x64 and Linux x64 builds | `scripts/build.sh` | Zips land in `builds/` |

The controls are in `README.md`. The skin format is in `docs/design/2026-10-04-poc-1080p-player.md`. Hits and the training dummy are in `docs/design/2026-10-04-hits-landing.md`. How to draw or prepare character frames is in `docs/skins.md`.

## Decided, and still proposed

- **Decided** (see `docs/design/2026-10-03-combat-core.md`): 60 ticks a second with every duration in ticks, the game slows down and never skips ticks, moves are `.tres` data played by one move player, two kinds of body (full fighters and a light crowd body) with one set of hit rules, hits resolved once per tick in a fixed order. Godot 4.7.2.
- **Proposed, Ben's positions, for the meeting:** 3 lanes with thickness, motion inputs, Guardian Heroes buttons, block and dodge, fully unique move lists, damage numbers on every hit, no friendly fire. E has agreed to motion inputs in round three.
- **Proposed and being explored:** a 1920 by 1080 screen with large sprites, see the next section.
- **Open:** the three characters, the licence (MIT or GPL), the store, the title.

## The direction being explored: 1080p with large sprites

This is not decided, and it pulls against two things the game bible has as decided: pixel art made with PixelLab, and huge crowds.

- Ben compared sprite sizes from 38 to 278 pixels tall in mock-ups and preferred large sprites at 1080p native. The project's viewport was changed to 1920 by 1080 for the proof of concept, marked proposed.
- A hand-drawn sprite for the player is expected. Until then the repository draws a plain figure in code.
- PixelLab's character creator caps at a 256 by 256 canvas. A knight generated there (about 227 pixels tall) kept its look across a 9-frame idle. Walks and attacks at that size are untested.
- At this size the screen holds about 30 to 50 enemies with three lanes, against 100 or more with small sprites.
- The 1080p stress run held 1,000 large animated enemies at about 4% of a tick on a MacBook Air M4. The cost moved from logic to drawing, so weaker graphics hardware is the risk.

## Issues

| Issue | State |
|---|---|
| #2 Brainstorm and settle the combat core | Open. Sections 1, 3, 4 and 7 are decided. Sections 2, 5 and 9 wait for the meeting. |
| #3 Crowd stress test | Open. Merged and measured on Ben's Mac. Needs numbers from E, T and Ben's Windows PC. |
| #4 Placeholder art, #5 Placeholder stage | Not started. Written for small CC0 sprites at 480 by 270, so they need rethinking if the 1080p direction is kept. |
| #6 2.5D movement, #7 Input router and buffer, #8 Moves from data | Not started as issues, but the proof of concept already has a first slice of each: lanes, the input buffer and command reader, and moves as data. Missing: a second player, cancels, and a move preview tool. |
| #9 Hits that feel good | Open. Merged. A training dummy takes hits: hitstop, hitstun, knockback, a white flash, a launcher, juggles, knockdown and getting up, screen shake and a combo counter. Done when the team has played it and agrees the hits feel solid. Its spec lists choices to confirm. |
| #23 Air attacks | Open. Merged. Light and heavy work during a jump. Done when the team has played them. |
| #10 Milestone 1 build | Not started. The build script exists. |
| #11 Port the PixelLab art pipeline | Not started. Its style probe should compare sprite sizes, including a large one. |
| #17 1080p proof of concept | Open. Merged. Done when the three have played it and commented. |

## Waiting on people

- **T:** round three of the questionnaire (the "Game brainstorm" Google Doc), a GitHub account, Godot 4.7.2.
- **E** (GitHub `T13nou`): accept the repository invitation, finish round three, run the stress test and the Linux build.
- **Ben:** run the Windows build, answer the five newest round-three questions.
- **All three:** a weekly meeting to settle sections 2, 5 and 9 and the screen and sprite size.

## Working in this repository

- Follow `CLAUDE.md`: an issue, a branch named `<type>/<issue>-<name>`, a pull request. `main` is protected, for admins too. Ben merges, or asks his Claude to.
- New issues are not always added to the board automatically. Check, and add them by hand.
- `builds/` and `local/` are git-ignored. `local/` holds private placeholder art that must never be committed or shipped, and the export presets leave both folders out of builds. A built game therefore shows the plain figure.
- The "Game brainstorm" Google Doc opens with a "Where we are" recap. The `meeting-notes` skill refreshes it after a meeting. It was last written on 2026-10-03 and does not mention the proof of concept yet.

## Things that have bitten us

- macOS ships Bash 3.2: a heredoc inside `"$(...)"` breaks on apostrophes. BSD `sed` has no `\b`.
- Godot exits with code 0 even when a scene fails to load. Check its output for `ERROR` lines.
- A script run with `godot -s` that hits an error never quits. Add `--quit-after <frames>` as a safety.
- In a `Node` script, don't name a variable `_input`: it shadows the engine's callback.
- `draw_texture_rect_region` with a negative width mirrors the image in place. Don't also move the rectangle.
- A `SceneTree` script's `_physics_process` quits the game if it returns anything but false, and a function that uses `await` returns something. Put the `await` in a helper.
- Godot's movie writer records at a fixed frame rate, so a recording never shows real performance.

## Suggested next steps

1. Get play feedback on the proof of concept into issue #17, and stress-test numbers into issue #3.
2. Hold the meeting, then mark sections 2, 5 and 9 of `docs/architecture.md` and update the game bible.
3. If the 1080p direction is kept: rewrite issues #4 and #5, and run the PixelLab probe (#11) at the chosen size with a walk and an attack.
4. Play the training dummy (#9) and tune the hit values. Then cancels between moves and the move preview tool (#8), which is what makes real combos possible.
