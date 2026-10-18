# Status

**Updated 2026-10-18.** Where the project stands, for a person or a Claude starting a new session. To show someone what there is to play, go to "Showing someone around". Read it after `CLAUDE.md`. Update it at the end of a working session: it is a snapshot, and the issues, the game bible and the design specs stay the sources of truth.

## In one paragraph

Setup is done and Milestone 1 is built: one character on an empty 1080p stage who walks, jumps, crouches, changes lane, attacks on the ground and in the air, combos through cancels, guards, dodges and throws a fireball, a training dummy that takes or blocks the hits or fights back (F5), and a crowd of small fry (F6) against a player with health, with a move preview tool for tuning moves without code. T and E have played it; the stage now starts with lanes 50 pixels apart and fighters scaled by lane (Ben's pick; F2 cycles the other presets). The art pipeline is ported and the sprite-size probe is done (#11). **Milestone 2 starts with Ben's direction of 2026-10-13: nail the feel of one player against a large group of small-fry enemies that are dangerous when they gang up, before any big work on visuals.** The first two steps of the vertical-slice plan are built: a camera that follows, a stage three screens wide with a placeholder parallax backdrop, and arenas that lock the camera until their waves are beaten (#58, merged); and local co-op, where a button on a second or third pad joins a tinted player with a health bar, the camera frames everyone and the crowd fights them all (#59, in review). Placeholder art stays in each person's `local/` and in private builds until then. The technical base of the combat core is decided; lanes, controls, screen and sprite size are still proposed and wait for a weekly meeting with all three.

## The plan: two vertical slices (Ben, 2026-10-17)

Ben's Milestone 2 plan of 2026-10-13 (the crowd #48, smart following #49, spells that scale #50) is built. The next plan is `docs/plans/2026-10-17-vertical-slices.md`: eleven steps in order, each an issue (#58 to #68), toward a melee level (camera, mana, enemy variety, waves, feel, pickups, sound) and a boss fight (the fighting-game camera, a boss, rounds), with local co-op for three pads early. A fresh session takes the lowest-numbered open issue whose needs are done. #58 (the camera), #59 (co-op), #60 (mana) and #72 (the guard bar) are merged and #75 (the crowd as walls and flanks, from Ben's playing) is in review; next is **#61, enemy variety**, then #62 (waves and a results screen).

Visuals still wait: the plain figure and private placeholder skins carry the game until the feel is right. Ben supplies effects on request (asked: a missile, a blast ring, a fireball, hit sparks).

## What runs today

| What | Where | How |
|---|---|---|
| The sandbox (the main scene) | `scenes/main/` (the menu) and `scenes/levels/poc_stage/` (the stage), `systems/camera/` (the camera), `scenes/levels/arenas.gd` (the arenas), `systems/input/lobby.gd` (joining) | `scripts/run.sh`, or F5 in the editor. The menu offers the boss fight (one screen), the melee (two arenas of waves along a stage three screens wide) and a sandbox (the same stage, free; add enemies one by one, standing still until told); in the melee and the sandbox, any button on a second or third pad joins a player; in a fight, Tab lists every key |
| The crowd stress test | `scenes/stress_test/` | `scripts/run.sh res://scenes/stress_test/stress_test.tscn` (add `-- --benchmark` for the timed table) |
| The fighter test | `tests/poc_player_test.gd` | `godot --headless --path . -s tests/poc_player_test.gd` prints `all passed` |
| The move preview tool | `scenes/tools/move_preview/` | `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. Steps through a move frame by frame and reloads it when its file is saved |
| The move preview test | `tests/move_preview_test.gd` | `godot --headless --path . -s tests/move_preview_test.gd` prints `all passed` |
| The crowd test | `tests/crowd_test.gd` | `godot --headless --path . -s tests/crowd_test.gd` prints `all passed` |
| The hits test | `tests/hits_test.gd` | `godot --headless --path . -s tests/hits_test.gd` prints `all passed` |
| The camera test | `tests/camera_test.gd` | `godot --headless --path . -s tests/camera_test.gd` prints `all passed` |
| The guard bar test | `tests/guard_bar_test.gd` | `godot --headless --path . -s tests/guard_bar_test.gd` prints `all passed` |
| The mana test | `tests/mana_test.gd` | `godot --headless --path . -s tests/mana_test.gd` prints `all passed` |
| The co-op test | `tests/coop_test.gd` | `godot --headless --path . -s tests/coop_test.gd` prints `all passed`. It also loads the stage headless and joins two scripted pads |
| The art pipeline | `tools/art/`, `docs/art.md` | `python3 tools/art/pixellab.py balance` and `python3 tools/art/budget.py` report from this repository (Ben's key, in his keychain). `gen.py plan art/jobs/probe_sizes.json` lists the sprite-size probe |
| Windows x64 and Linux x64 builds | `scripts/build.sh` | Zips land in `builds/`. Add `--skin <folder>` for a playtest build with a skin beside the executable: its zips are named `-private` and must not be published |

The controls are in `README.md`. The skin format is in `docs/design/2026-10-04-poc-1080p-player.md`. Hits and the training dummy are in `docs/design/2026-10-04-hits-landing.md`. The camera and the arenas are in `docs/design/2026-10-17-camera-and-scrolling-stage.md`, co-op in `docs/design/2026-10-17-local-coop.md`. How to draw or prepare character frames is in `docs/skins.md`.

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
- **Proposed, Ben's positions, for the meeting:** 3 lanes with thickness, motion inputs, two attacks (light and heavy) plus guard with spells and later commands on their own pad buttons (Ben and T agree in writing, 2026-10-11; E to confirm), block and dodge, fully unique move lists, damage numbers on every hit, no friendly fire. E has agreed to motion inputs in round three.
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
| #41 Guard | Open. Merged. Hold K (B) to block hits from the front: blockstun and pushback instead of damage. F4 makes the dummy guard. Done when the team agrees on what a guard stops. |
| #45 The first enemy that attacks | Open. Merged. F5 makes the dummy fight back: a brain presses the buttons of the same full fighter. Walks up, swings light and heavy, rests, guards sometimes, follows a lane change after 45 ticks. No health. Done when the team has fought it. |
| #58 Camera and a scrolling stage | Open. Merged. A `StageCamera` follows the player with a look-ahead and holds it on screen; the melee and the sandbox are three screens wide with a two-layer placeholder backdrop; the melee is two arenas of waves (10 and 10, then 10 and 15) that lock the camera until beaten, then GO, then CLEAR. Spec: `docs/design/2026-10-17-camera-and-scrolling-stage.md`, proposed. Done when the melee scrolls through two arenas and the camera never loses the player: it does on Ben's Mac; the team has not played it. |
| #59 Local co-op | In review. Any button on pad 2 or 3 joins a player in the melee or the sandbox (a `Lobby` hands over its `PlayerInput` with the press swallowed): a green or gold figure with a P2 or P3 tag, a health bar each, the camera on the midpoint of the living players with the screen's edges holding them together (no look-ahead with company), the crowd on the nearest player with three attack tokens per player, the big dummies' brains the same, no friendly fire (one team), a player's fireball credited to its own combo. Spec: `docs/design/2026-10-17-local-coop.md`, proposed. Done when three pads play the melee together and nobody is lost off screen: three scripted pads do on Ben's Mac at 120 fps; nobody has played it with real pads yet. |
| #60 Mana | Merged, with Ben's follow-up (light specials free) merged too. A blue bar under each health bar; every clean hit pays its attacker the `mana` on its hit data (normals 6 to 10, a spell's own hits 2 to 3, the super 0). After playing, Ben made light specials free; heavy ones cost (35 to 40) and come out as their light version when the bar can't pay, with a red flash, and the super costs the whole bar. The melee starts empty, the other scenes full; F7 refills. Spec: `docs/design/2026-10-17-mana.md`, proposed. Done when the team agrees the economy makes crowd fighting feed the spells. |
| #72 Guard bar | Merged, with the taunt in review: while the knight holds its guard, small fry within 900 pixels fight it, converge on its lane past the cap, each after its own wait of 10 to 50 ticks per hop with a fifth straggling for 180 to 360, and pile on from their side with no going round (Ben, after playing). Ben wants an attracting-force animation on the guard later. Ben's design of 2026-10-17: a white bar under the mana bar, a blocked hit drains it by its damage, a hit landed refills 15, a quiet second starts a trickle, at zero the breaking hit lands in full as a launcher with a shake, below a quarter the guard can't be raised. F8 gives player 1 a tank's bar, three times bigger: bar sizes per character are how classes come about. Spec: `docs/design/2026-10-17-guard-bar.md`, proposed. Done when Ben has felt the tank preset against the melee; he has played the first version. |
| #75 The crowd can't walk through a player, and surrounds through the lanes | In review. Ben, after playing on 2026-10-17: players are walls in their lane, guarding or not, so a tank can pack a mob and protect the others. A small fry that walks or is pushed into a player stops 70 pixels short; when its side is full, or a wall has held it 20 ticks, it goes round through the side lane with the most room, 220 pixels past the target, and comes back in. Spec: `docs/design/2026-10-17-crowd-walls-and-flanks.md`, proposed. Done when a guarding player at a wall holds a wave on one side for as long as the guard lasts, and the crowd flanks: the crowd test checks it; Ben has not played it. |
| #61 to #68, the rest of the vertical-slice plan | Not started. See `docs/plans/2026-10-17-vertical-slices.md`. |
| #48 The crowd | Open. Merged. F6 adds ten small fry at a time, up to 48: a pooled crowd body with one jab and 30 health, a director with thinking in turns, three attack tokens and spacing, the player with 100 health and a death, R to start over. 40 on screen at 110 to 120 fps. Done when the team says it feels like a crowd. |
| #54 Sandbox menu | Open. Merged, plus a third scene in review: the sandbox, where 1 adds a small fry and 2 a big dummy, as many as wanted; F5 starts and stops every enemy at once in every scene. Tab is the pause menu with every key. |
| #49 Smart following | Open. Merged. Small fry follow a lane change after 45 ticks, at most 6 in the player's lane, and go around to the other side when theirs has more than 3: through a side lane since #75. |
| #50 Spells scale with the button | Open. Merged. Light and heavy fireball, homing missiles and an every-lane blast on the dragon punch and hurricane motions, and a piercing super: the heavy version twice as big and hard with a tighter motion window. All move data; effects drawn in code until Ben's arrive. |
| #43 Dodge | Open. Merged. Shift (right trigger) dashes along the lane with invincible ticks in the middle and a short recovery; neutral is a step back. Done when the team agrees on its timing. |
| #10 Milestone 1 build | Not started. The build script exists. |
| #11 Port the PixelLab art pipeline | In review. The tools are ported and report the balance from here; `docs/art.md` is the guide for T and E (asset kinds and sizes at both candidate resolutions, the character workflow, the tools; everyone may generate with their own stack and keys, following the same art direction and palette). The sprite-size probe ran on 2026-10-11 (about 150 generations): the Pro character creator caps at 168 pixels and gave a small, big-headed look that Ben rejected; `create-character-v3` at 256 gives a 240-pixel man-at-arms that matches Ben's knight, now the approved reference (`art/refs/`). Results in `docs/probes/2026-10-11-size-probe/` and on the issue. Attacks: `pixminimax` gives 12 frames of a sword slash at 256 for 2 generations, so custom animations are cheap. Done when the meeting has picked the look and size. |
| #17 1080p proof of concept | Open. Played by all three. The depth experiment (F2: lane spacing and fighter size by lane, F3: shading) is in. Done when the meeting has settled lanes, spacing and depth. |

## Waiting on people

- **T** (GitHub `pipochao`, invited to the repository and the board on 2026-10-11): accept the invitations, install Godot 4.7.2, take the tour above. T's round three is in: three lanes with a small perspective effect, 30 to 40 enemies at most, two attack buttons plus guard plus a spell button, block and dodge, combo counter only, no friendly fire.
- **E** (GitHub `T13nou`): finish round three, run the stress test and post its table on #3.
- **Ben:** run the Windows build, answer the five newest round-three questions, write up what T and E said about the hits and the combos on #9 and #8.
- **All three:** a weekly meeting to settle sections 2, 5 and 9 and the screen and sprite size. New for that agenda: the lane spacing and depth (F2 in the proof of concept), the resolution (the probe says 1080p native with characters about 240 pixels tall from `create-character-v3` at 256, in the look of Ben's knight: see `docs/probes/2026-10-11-size-probe/`), and the button layout, where Ben and T now agree on two attacks plus guard (both built) and E has to confirm. Also new: classes through the bars (Ben, 2026-10-17: a tank with a much bigger guard bar), to settle together with who the three characters are.

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
- A new `class_name` script is unknown to a headless test run until `godot --headless --path . --import` rebuilds the class cache. The first run after adding one fails to parse with "Could not find type".
- To capture the running stage, a `SceneTree` script run with a window (not headless) can `change_scene_to_file`, await some `physics_frame`s and save `root.get_viewport().get_texture().get_image()`.
- A scene added to `root` inside a `SceneTree` script's `_initialize` gets no `_ready` yet: `await process_frame` in a helper first, then add it (`tests/coop_test.gd` does).

## Suggested next steps

1. **Follow the plan** in `docs/plans/2026-10-17-vertical-slices.md`: with the camera (#58), co-op (#59), mana (#60) and the guard bar (#72) merged and the crowd walls (#75) in review, enemy variety (#61), waves (#62), and on. Design choices that a player feels go in a spec in `docs/design/` marked proposed. Ben plays the melee and says whether the smooth follow and the look-ahead feel right, or whether a dead zone would; with two pads, whether a player blocked at the screen's edge until the other catches up feels right, and whether three attack tokens per player is too many.
2. Hold the meeting: lanes and depth (the 50-pixel preset), the resolution (the probe says keep 1080p), E's confirmation of two attacks plus guard, what guard and dodge should stop, the enemy's feel, and bosses-then-playable (#33). Then mark sections 2, 5 and 9 of `docs/architecture.md` and update the game bible.
3. T and E take the tour ("Showing someone around"), fight the dummy (F5), and tune a move with the preview tool; that closes #8. E's stress-test numbers into #3.
4. After the meeting, rewrite issues #4 and #5 for the chosen size, and start the first character through the workflow in `docs/art.md`.
