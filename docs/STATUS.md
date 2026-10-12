# Status

**Updated 2026-10-11.** Where the project stands, for a person or a Claude starting a new session. To show someone what there is to play, go to "Showing someone around". Read it after `CLAUDE.md`. Update it at the end of a working session: it is a snapshot, and the issues, the game bible and the design specs stay the sources of truth.

## In one paragraph

Setup is done. Milestone 1 is under way. There is a playable proof of concept on `main`: one character on an empty 1080p stage who walks, jumps, crouches, changes lane, attacks on the ground and in the air, and throws a fireball, and a training dummy that takes the hits. T and E have played it. They want more overlap between the lanes, a lower camera and more depth; a depth experiment is in the proof of concept (F2 cycles lane spacing and fighter size by lane, F3 shades the back lanes). They also want to know how to make floors, backgrounds, destructibles and pickups, which is the art pipeline (#11). The technical base of the combat core is decided, and everything a player feels (lanes, controls, screen and sprite size) is still proposed and waiting for a weekly meeting with all three.

## What runs today

| What | Where | How |
|---|---|---|
| The proof of concept (the main scene) | `scenes/levels/poc_stage/` | `scripts/run.sh`, or F5 in the editor |
| The crowd stress test | `scenes/stress_test/` | `scripts/run.sh res://scenes/stress_test/stress_test.tscn` (add `-- --benchmark` for the timed table) |
| The fighter test | `tests/poc_player_test.gd` | `godot --headless --path . -s tests/poc_player_test.gd` prints `all passed` |
| The move preview tool | `scenes/tools/move_preview/` | `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. Steps through a move frame by frame and reloads it when its file is saved |
| The move preview test | `tests/move_preview_test.gd` | `godot --headless --path . -s tests/move_preview_test.gd` prints `all passed` |
| The hits test | `tests/hits_test.gd` | `godot --headless --path . -s tests/hits_test.gd` prints `all passed` |
| The art pipeline | `tools/art/`, `docs/art.md` | `python3 tools/art/pixellab.py balance` and `python3 tools/art/budget.py` report from this repository (Ben's key, in his keychain). `gen.py plan art/jobs/probe_sizes.json` lists the sprite-size probe |
| Windows x64 and Linux x64 builds | `scripts/build.sh` | Zips land in `builds/`. Add `--skin <folder>` for a playtest build with a skin beside the executable: its zips are named `-private` and must not be published |

The controls are in `README.md`. The skin format is in `docs/design/2026-10-04-poc-1080p-player.md`. Hits and the training dummy are in `docs/design/2026-10-04-hits-landing.md`. How to draw or prepare character frames is in `docs/skins.md`.

## Showing someone around

For a Claude whose person asks what there is to see or try, or says "show me around". Go one step at a time, run the commands yourself, and wait for their reaction before the next step. The same tour, written for a person, is in `README.md` under "Try it".

1. **Check the setup.** `source scripts/godot.sh && "$GODOT_BIN" --version` must print 4.7.2. If Godot is missing or another version, stop and help them install 4.7.2 (see `SETUP.md`). Pull `main` first.
2. **Run the game:** `scripts/run.sh`. It opens a window and returns when they close it. Tell them before you start what they will see: one character and a red training dummy, and a plain blue figure for the character unless a skin is present. A build that Ben sent them may show a drawn character: that art is private and is not in the repository.
3. **Give them things to try, in this order:** walking and the three lanes (Q and E), a light attack (J), a heavy (L), a fireball (down, down-forward, forward, then J), F1 for the boxes, then the combo: J, J, L, hold W as the L lands, then J and L in the air. The full controls table is in `README.md`.
4. **Show the move preview tool:** `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. Explain the red and green rows of the timeline: when the move can hit, and when it can be cancelled into another move.
5. **Have them change a move themselves.** Follow "Tuning a move without code" in `README.md`: they edit a number in the Godot editor's inspector, not you in the file. This is the check that closes issue #8, so note in that issue whether it worked for them. Afterwards, ask whether to keep the change (then it needs an issue and a branch) or throw it away with `git checkout -- data/moves/poc`.
6. **Run the stress test on their machine:** `scripts/run.sh res://scenes/stress_test/stress_test.tscn -- --benchmark`. Post the table it prints, with their processor and graphics card, as a comment on issue #3.
7. **Collect their reactions.** Ask what felt good and what felt off, then offer to post their words as comments on the matching issue. Show them the comment before posting it.

| What they talk about | Issue |
|---|---|
| Lanes, the controls, the screen and sprite size | #17 |
| How hits feel: hitstop, knockback, the launcher, the shake | #9 |
| Air attacks | #23 |
| Combos, cancels, the move preview tool | #8 |
| Frame rate with a crowd | #3 |

Most of what they will react to is still **Proposed**. Don't defend it: their reaction is what the weekly meeting needs. Someone with no GitHub account yet can give their reactions to Ben, or write them in the "Game brainstorm" Google Doc.

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
| #6 2.5D movement, #7 Input router and buffer, #8 Moves from data | Not started as issues, but the proof of concept already has a first slice of each: lanes, the input buffer and command reader, and moves as data. Missing: a second player. Under #8, cancels are merged (light, light, heavy is a three-hit combo from data) and the move preview tool is in review. #8 is done when someone who doesn't code has changed a move with it. |
| #9 Hits that feel good | Open. Merged. A training dummy takes hits: hitstop, hitstun, knockback, a white flash, a launcher, juggles, knockdown and getting up, screen shake and a combo counter. Done when the team has played it and agrees the hits feel solid. Its spec lists choices to confirm. |
| #23 Air attacks | Open. Merged. Light and heavy work during a jump. Done when the team has played them. |
| #10 Milestone 1 build | Not started. The build script exists. |
| #11 Port the PixelLab art pipeline | In review. The tools are ported and report the balance from here; `docs/art.md` is the guide for T and E (asset kinds and sizes at both candidate resolutions, the character workflow, the tools; everyone may generate with their own stack and keys, following the same art direction and palette). The sprite-size probe ran on 2026-10-11 (about 150 generations): the Pro character creator caps at 168 pixels and gave a small, big-headed look that Ben rejected; `create-character-v3` at 256 gives a 240-pixel man-at-arms that matches Ben's knight, now the approved reference (`art/refs/`). Results in `docs/probes/2026-10-11-size-probe/` and on the issue. Attacks: `pixminimax` gives 12 frames of a sword slash at 256 for 2 generations, so custom animations are cheap. Done when the meeting has picked the look and size. |
| #17 1080p proof of concept | Open. Played by all three. The depth experiment (F2: lane spacing and fighter size by lane, F3: shading) is in. Done when the meeting has settled lanes, spacing and depth. |

## Waiting on people

- **T** (GitHub `pipochao`, invited to the repository and the board on 2026-10-11): accept the invitations, install Godot 4.7.2, take the tour above. T's round three is in: three lanes with a small perspective effect, 30 to 40 enemies at most, two attack buttons plus guard plus a spell button, block and dodge, combo counter only, no friendly fire.
- **E** (GitHub `T13nou`): finish round three, run the stress test and post its table on #3.
- **Ben:** run the Windows build, answer the five newest round-three questions, write up what T and E said about the hits and the combos on #9 and #8.
- **All three:** a weekly meeting to settle sections 2, 5 and 9 and the screen and sprite size. New for that agenda: the lane spacing and depth (F2 in the proof of concept), the resolution (the probe says 1080p native with characters about 240 pixels tall from `create-character-v3` at 256, in the look of Ben's knight: see `docs/probes/2026-10-11-size-probe/`), and the button layout: T wants two attacks plus guard plus a spell button, and the proof of concept has light and heavy.

## Working in this repository

- Follow `CLAUDE.md`: an issue, a branch named `<type>/<issue>-<name>`, a pull request. `main` is protected, for admins too. Ben merges, or asks his Claude to.
- "Who does what" in `CLAUDE.md` (2026-10-11): code changes come from Ben or from issues Ben assigned; T's and E's sessions run, test, QA, try assets and propose values, in this repository and never a fork.
- New issues are not always added to the board automatically. Check, and add them by hand.
- `builds/` and `local/` are git-ignored. `local/` holds private placeholder art that must never be committed or shipped, and the export presets leave both folders out of builds. A built game therefore shows the plain figure, unless a skin sits in `skins/player/` beside its executable (see `scripts/build.sh --skin`). That lookup has not been tried on a real Windows or Linux machine yet.
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

1. T and E try the depth presets (F2) and say which one reads best, on #17. E's stress-test numbers into issue #3.
2. Hold the meeting, then mark sections 2, 5 and 9 of `docs/architecture.md` and update the game bible.
3. The meeting picks the resolution and the character look from the probe (#11). Then rewrite issues #4 and #5 for the chosen size, and start the first character through the workflow in `docs/art.md`.
4. Play the training dummy (#9) and the combos (#8), and tune the hit values with the move preview tool. T or E changing a move with it closes #8.
