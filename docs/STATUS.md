# Status

**Updated 2026-10-18, evening.** Where the project stands, for a person or a Claude starting a new session. Read it after `CLAUDE.md`. To show someone what there is to play, go to "Showing someone around". Update it at the end of a working session: it is a snapshot, and the issues, the game bible and the design specs stay the sources of truth.

## In one paragraph

Both vertical slices of `docs/plans/2026-10-17-vertical-slices.md` exist. **The melee** is a level: the knight (the player's character, a tank) fights two arenas of mixed small fry along a stage three screens wide, with a camera that follows, mana that hits pay and heavy spells cost, a guard bar that breaks, a guard that taunts the crowd into the knight's lane, a crowd that can't walk through a player and flanks through the lanes, four kinds of small fry including a shield bearer with a telegraphed guard-breaking bash and a thrower, barrels that drop potions, placeholder sound, and a results screen. **The boss fight** is a 1v1 against the Captain, a placeholder boss with strings, telegraphed heavies, an unblockable grab and a second phase, under a fighting-game camera. **Local co-op** for three pads runs in the melee. **The combat feel** changed on 2026-10-17 after Ben played: a landed hit frees you into anything, a dash with a running attack, lights that step. All of it is built on the plain figure and the private placeholder skin; visuals wait until the feel is right (Ben, 2026-10-13). Every design choice since Milestone 1 is **proposed** and waits for the weekly meeting; nobody but Ben has played any of it. Ben played both slices for the review of 2026-10-18 (#92): the shapes are right, the core loop of crowd into spells does not pay off yet, and the next work is the core-loop feel pass of `docs/plans/2026-10-18-core-loop-feel-pass.md`.

## The next session's first job: the core-loop feel pass

Ben played both slices end to end on 2026-10-18 (issue #92; his words are quoted on the issues each thing belongs to). **The shapes pass:** the boss fight is the right size and feel, only too weak for now; the level and the kinds are nice; the swing is reactive enough. **The core loop does not pay off yet:** being surrounded is too hard to get out of, the spells neither clear a pile nor cast easily in one, the throwers flee out of the knight's short reach, and the knight's tank kit (guard, taunt) has no answer to a crowd when played alone. The plan that follows is `docs/plans/2026-10-18-core-loop-feel-pass.md`: a feel pass on the loop, not a new slice and not a change of direction. Its steps, in order:

1. **A way out of the pile** (#94): the light blast as the free, instant get-off-me move; a cap on the crowd's chain and invincible hop ticks if that isn't enough. Built on `code/94-way-out` on 2026-10-18 (`docs/design/2026-10-18-way-out-of-the-pile.md`, proposed): the headless sandbox test found the crowd leaves gaps and the kit had nothing to clear with; the blast now comes out at once, invincible, launching everything around the knight in every lane, a shove through shields, 6 damage, free. Ben played it on 2026-10-18: he gets out every time with one input, and the melee no longer frustrates when the crowd closes in. Merged as pull request #100 on 2026-10-18.
2. **Spells that clear** (#95): the heavy spells hit hard, wide and launch, the super sweeps every lane, mana retuned so a three-hit combo pays one heavy spell; with the knock-ons and carried launches of #63 that need no effects. Damage stays plain move data that today happens to kill the first level's plain small fry with a heavy spell: a number, not a rule (Ben's correction on #95, 2026-10-18; stronger mobs and character stats come later). Built on `code/95-spells-clear` on 2026-10-18 (`docs/design/2026-10-18-spells-that-clear.md`, proposed): the heavy fireball pierces its lane, the heavy blast shoves through shields, the super flies in every lane, every heavy launches the Captain, all heavies cost 30 and the combo pays 30, and a launched small fry bowls over the ones it flies into, credited to the player's combo. Waiting for Ben to play it on the branch.
3. **Spells on buttons** (#96), motions kept. For the meeting once built: the layout is the team's.
4. **Throwers** (#97): back off less, within the knight's reach. Numbers only.

A fresh session takes the lowest-numbered open one whose needs are done. For the meeting, not the plan: every character must work solo, so the knight's crowd control or the caster next (#98, with #33); the spell economy after step 2; the boss's strength after #90.

What is known to be missing or pending: Ben's effects for the crowd feel pass (#63: a missile, a blast ring, a fireball, hit sparks, and the taunt's attracting force); the real sounds (E, #87); any play by T or E since the first proof of concept; the weekly meeting with its agenda below.

## What runs today

| What | Where | How |
|---|---|---|
| The game: the menu and the stage | `scenes/main/` (the menu), `scenes/levels/poc_stage/` (the stage), `scenes/levels/` (levels, arenas, waves), `systems/camera/`, `systems/enemies/` (the crowd director, kinds, brains, the boss), `scenes/props/`, `systems/audio/`, `systems/input/lobby.gd` (joining) | `scripts/run.sh`, or F5 in the editor. The menu offers the **boss fight**, the **melee** (the first level, "The camp") and a **sandbox** (the melee's stage, free; add enemies and barrels one by one, standing still until told). In the melee and the sandbox any button on a second or third pad joins. In a fight, Tab lists every key |
| The crowd stress test | `scenes/stress_test/` | `scripts/run.sh res://scenes/stress_test/stress_test.tscn` (add `-- --benchmark` for the timed table) |
| The move preview tool | `scenes/tools/move_preview/` | `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. Steps through a move frame by frame and reloads it when its file is saved |
| The tests, fifteen scripts | `tests/*_test.gd` | `godot --headless --path . -s tests/<name>.gd --quit-after 8000` prints `all passed`. `poc_player`, `move_preview`, `hits`, `crowd`, `camera`, `coop`, `mana`, `guard_bar`, `enemies`, `level`, `props`, `sounds`, `boss`, `way_out` (the sandbox pile, run headless, with the numbers for the hop, the dash and the blast), `spells_clear` (the heavy spells, the super, the carries). After adding a `class_name`, run `godot --headless --path . --import` first |
| The placeholder sounds | `tools/audio/make_placeholders.py` | `python3 tools/audio/make_placeholders.py` remakes `assets/sfx/` and `assets/music/` (needs `oggenc` or ffmpeg) |
| The art pipeline | `tools/art/`, `docs/art.md` | `python3 tools/art/pixellab.py balance` and `python3 tools/art/budget.py` report from this repository (Ben's key, in his keychain). `gen.py plan art/jobs/probe_sizes.json` lists the sprite-size probe |
| Windows x64 and Linux x64 builds | `scripts/build.sh` | Zips land in `builds/`. Add `--skin <folder>` for a playtest build with a skin beside the executable: its zips are named `-private` and must not be published |

The controls are in `README.md`. The specs, all proposed, are in `docs/design/`: the combat core (decided) and the setup (2026-10-03); hits, the dummy, air attacks, cancels, guard, dodge and the crowd (2026-10-04, `hits-landing`); the proof of concept and the skin format (`poc-1080p-player`); the camera and arenas, co-op, mana, the guard bar and taunt, the crowd walls and flanks, enemy kinds, the combat feel (2026-10-17); levels and results, props and pickups, placeholder sound, the boss camera, the boss (2026-10-18). The sounds and music the game needs are listed for E in `docs/audio.md`; the art guide is `docs/art.md`; character frames follow `docs/skins.md`.

## Showing someone around

For a Claude whose person asks what there is to see or try, or says "show me around", and for the review above. Go one step at a time, run the commands yourself, and wait for their reaction before the next step. The same tour, written for a person, is in `README.md` under "Try it".

1. **Check the setup.** `source scripts/godot.sh && "$GODOT_BIN" --version` must print 4.7.2. If Godot is missing or another version, stop and help them install 4.7.2 (see `SETUP.md`). Pull `main` first.
2. **Run the game:** `scripts/run.sh`. The menu: pick **Melee**. Tell them what they will see: the knight (a plain blue figure unless a skin is present; a build Ben sent may show a drawn character, which is private and not in the repository), a camp with hills and a castle behind, and a wave of small fry walking in from the right.
3. **The basics:** walk (A, D), the three lanes (Q and E), a light (J), a heavy (L), the combo J, J, L, hold W as the L lands, then J and L in the air. **The new feel (#80):** after a hit lands, hop (Q or E) or dash (Shift) straight out of the swing; hold Shift with a direction to run and press J or L for the lunge. Lights step forward on their own.
4. **The guard and the taunt (#72):** hold K as a wave arrives. The white bar drains, the crowd converges on your lane and piles on your side (the knight is a tank), and it breaks into a launch at zero. Let go and hit back to refill it. F8 makes the bar three times bigger.
5. **Mana and spells (#60, #50):** the blue bar fills as hits land. The fireball (down, down-forward, forward, J) is free; with L it costs 30 (one three-hit combo) and falls back to the light one with a red flash when short; missiles (forward, down-forward), the blast (down twice) and the super (the fireball motion twice, L) likewise. Since #95 the heavies launch and clear: the heavy fireball through a lane, the heavy blast the pile around you, the super every lane; a launched small fry bowls the ones it flies into.
6. **The kinds (#61):** the yellow slim one is fast and weak, the blue one blocks from the front until two heavies break its shield and winds up a bash under a red mark that breaks your guard (dodge it), the green one keeps back and throws rocks. Barrels (#64) break in two hits and drop a potion.
7. **Through the level (#62, #58):** beat both arenas, walk on at GO, read the results. R goes again. With a second pad, any button joins player 2 (#59).
8. **The boss fight (#67, #66):** from the menu. The Captain: strings, a red mark before its heavies, its grab and its shot, a second phase at half health, the camera zooming on the two of you. K.O. ends it either way.
9. **The sandbox:** 1 to 6 place a small fry, a big dummy, a fast one, a shielded one, a thrower or a barrel in front of you; F5 sets them going; F6 adds a wave. F1 shows the boxes, F2 cycles the lane presets, F3 shades the back lanes, F7 refills mana, F9 mutes.
10. **The move preview tool:** `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. The red and green rows of the timeline: when the move can hit, and when it can be cancelled. Have them change a number in the inspector ("Tuning a move without code" in `README.md`); that is the check that closes #8. Keep the change through an issue and a branch, or throw it away with `git checkout -- data/moves/poc`.
11. **The stress test on their machine:** `scripts/run.sh res://scenes/stress_test/stress_test.tscn -- --benchmark`. Post the table, with their processor and graphics card, on issue #3.
12. **Collect their reactions.** Ask what felt good and what felt off, then offer to post their words as comments on the matching issue. Show them the comment before posting it.

| What they talk about | Issue |
|---|---|
| The feel of a swing: cancels, the dash, the step | #80 |
| Hits: hitstop, knockback, launchers, juggles, the shake | #9 |
| The guard, the guard bar, the taunt, the tank | #72, #41 |
| Mana, spells, the super | #60, #50 |
| The crowd: how it gangs up, walls, flanking | #75, #48, #49 |
| The kinds of small fry, the shield bash | #61 |
| The level, its waves and arenas, the results | #62, #58 |
| Barrels and potions | #64 |
| The boss, its strings and tells; the camera on the pair | #67, #66 |
| Co-op with pads | #59 |
| Sound | #65, #87 |
| Lanes, the controls, the screen and sprite size | #17 |
| Frame rate with a crowd | #3 |

Everything they react to is **proposed**. Don't defend it: their reaction is what the weekly meeting needs. Someone with no GitHub account yet can give their reactions to Ben, or write them in the "Game brainstorm" Google Doc.

## Decided, and still proposed

- **Decided** (see `docs/design/2026-10-03-combat-core.md`): 60 ticks a second with every duration in ticks, the game slows down and never skips ticks, moves are `.tres` data played by one move player, two kinds of body (full fighters and a light crowd body) with one set of hit rules, hits resolved once per tick in a fixed order. Godot 4.7.2.
- **Proposed, Ben's positions, for the meeting:** 3 lanes with thickness, motion inputs, two attacks (light and heavy) plus guard with spells and later commands on their own pad buttons (Ben and T agree in writing, 2026-10-11; E to confirm), block and dodge, fully unique move lists, damage numbers on every hit, no friendly fire. E has agreed to motion inputs in round three.
- **Proposed, Ben's directions of 2026-10-17 and 2026-10-18, built and for the meeting:** the combat feel (a landed hit frees you, a dash with a running attack, lights that step; `docs/design/2026-10-17-combat-feel.md`); classes through the bars, the knight a tank whose guard taunts; boss fights asymmetric, the boss much stronger and all three characters needed (how is Open, #90).
- **Proposed and being explored:** a 1920 by 1080 screen with large sprites, see the next section.
- **Open:** the three characters and who the bosses are (#33), how the three take part in a boss fight (#90), the licence (MIT or GPL), the store, the title.

## The direction being explored: 1080p with large sprites

This is not decided, and it pulls against two things the game bible has as decided: pixel art made with PixelLab, and huge crowds.

- Ben compared sprite sizes from 38 to 278 pixels tall in mock-ups and preferred large sprites at 1080p native. The project's viewport was changed to 1920 by 1080 for the proof of concept, marked proposed.
- A hand-drawn sprite for the player is expected. Until then the repository draws a plain figure in code.
- PixelLab's character creator caps at a 256 by 256 canvas. A knight generated there (about 227 pixels tall) kept its look across a 9-frame idle. Walks and attacks at that size are untested.
- At this size the screen holds about 30 to 50 enemies with three lanes, against 100 or more with small sprites.
- The 1080p stress run held 1,000 large animated enemies at about 4% of a tick on a MacBook Air M4. The cost moved from logic to drawing, so weaker graphics hardware is the risk.

## Issues

**Built, merged, proposed, waiting on the team's play.** Each has a spec in `docs/design/` and is done when the team has played it and agrees.

| Issue | What is there |
|---|---|
| #9 Hits, #23 Air attacks, #8 Cancels and the move preview tool, #41 Guard, #43 Dodge, #45 The first enemy that attacks | The proof of concept's fighter: hitstop, hitstun, knockback, launchers, juggles, knockdown and get-up, shake, a combo counter; air moves; cancel windows as data; a guard; a dash with invincible ticks; a dummy with a brain. #8 closes when someone who doesn't code has changed a move with the tool. |
| #48 The crowd, #49 Smart following, #50 Spells that scale | Pooled small fry with a director (tokens, spacing, lane following); the fireball, missiles, the blast and the super in light and heavy versions, all move data. |
| #58 Camera and stage, #59 Co-op, #62 Level and results | A camera that follows with a look-ahead; a stage three screens wide with a parallax backdrop; arenas that lock the camera; three pads joining, the camera framing everyone, the crowd fighting them all; the melee as a `Level` of waves of kinds, with the time, hits taken and best combo at the end. |
| #60 Mana, #72 Guard bar and taunt | Hits pay, heavy spells cost and fall back to light when short; a guard bar drained by blocked hits, refilled by hits landed, breaking into a launch at zero, a tank preset on F8; the knight's guard taunts the crowd into its lane, converging with stragglers, lingering after. |
| #75 Crowd walls and flanks, #61 Enemy kinds | Players are walls in their lane; the crowd goes round through the side lanes, a couple at a time; four kinds as data (plain, fast, shielded with a telegraphed guard-breaking bash, thrower). |
| #80 Combat feel | A landed hit frees you into anything, a whiff commits you; Shift held runs, with a running light and heavy; lights step forward, eased. Ben: "much better"; his quirks are not listed yet. |
| #64 Barrels and potions, #65 Placeholder sound | Barrels in three states that drop a potion; ten synthesized cues and a loop through one pool, F9 mutes. |
| #66 The boss camera, #67 The boss | Zoom and pan on the pair, pulling out as they separate; the Captain with strings by name, tells, a grab that holds then throws, two phases, a named bar, an intro and K.O. |
| #54 Sandbox menu, #17 1080p proof of concept | The menu's three scenes and the pause menu; the depth presets (F2) and shading (F3), played by all three. |

**Open questions and the rest.**

| Issue | State |
|---|---|
| #94 A way out of the pile | Done: pull request #100 merged on 2026-10-18. Ben gets out every time with one input; the melee no longer frustrates when the crowd closes in. |
| #95 Spells that clear | In progress: built on `code/95-spells-clear` (see the plan's step 2 above). Done when Ben plays the melee on the branch and says the spells clear a pile satisfyingly; then the pull request. |
| #96 Spells on buttons, #97 Throwers | The core-loop feel pass, above, in that order after #95. Not started. |
| #98 Every character must work solo | For the meeting with #33: the knight's crowd control, or the caster next. |
| #92 Find the fun | Done on 2026-10-18: Ben's reactions are on the issues, the plan is `docs/plans/2026-10-18-core-loop-feel-pass.md`. |
| #2 The combat core | Sections 1, 3, 4 and 7 are decided. Sections 2, 5 and 9 wait for the meeting. |
| #90 Boss fights: tag team, 3v1 or something else? | For the meeting, with #33 (characters appear as bosses, then unlock). |
| #63 Crowd feel pass | Its knock-ons and carried launches are built on #95's branch (a launched small fry carries the ones it flies into); the death effects and VFX wait on Ben's effects (a missile, a blast ring, a fireball, hit sparks, the taunt's pull). |
| #87 Sound effects and music | E's, from `docs/audio.md`. |
| #3 Crowd stress test | Measured on Ben's Mac. Needs numbers from E, T and Ben's Windows PC. |
| #11 Port the PixelLab art pipeline | In review. The tools report the balance from here; `docs/art.md` is the guide; the size probe of 2026-10-11 found `create-character-v3` at 256 matches Ben's knight (`art/refs/`). Done when the meeting has picked the look and size. |
| #4 Placeholder art, #5 Placeholder stage, #10 Milestone 1 build | Not started. #4 and #5 were written for small sprites and need rethinking if 1080p is kept. The build script exists. |
| #68 Rounds | Scrapped by Ben on 2026-10-18 for the asymmetric boss fight. |

## Waiting on people

- **T** (GitHub `pipochao`, invited to the repository and the board on 2026-10-11): accept the invitations, install Godot 4.7.2, take the tour. T's round three is in: three lanes with a small perspective effect, 30 to 40 enemies at most, two attack buttons plus guard plus a spell button, block and dodge, combo counter only, no friendly fire.
- **E** (GitHub `T13nou`): finish round three, take the tour, run the stress test and post its table on #3; the sound effects and music from `docs/audio.md` (#87).
- **Ben:** list the quirks from the combat-feel spike on #80; the effects for #63; play co-op with real pads; run the Windows build; answer the five newest round-three questions; write up what T and E said about the hits and the combos on #9 and #8.
- **All three:** a weekly meeting. Its agenda: sections 2, 5 and 9 of the architecture (lanes and depth, the 50-pixel preset; the resolution, where the probe says 1080p native with characters about 240 pixels tall in the look of Ben's knight; the button layout, where Ben and T agree on two attacks plus guard and E has to confirm; what guard and dodge should stop); the combat feel of #80; classes through the bars and who the three characters are; the shape of boss fights (#90) and bosses that unlock (#33); every character working solo, the knight's crowd control or the caster next (#98); spells on buttons once built (#96); the spell economy (#60) after #95; the enemy's feel.

## Working in this repository

- Follow `CLAUDE.md`: an issue, a branch named `<type>/<issue>-<name>`, a pull request. `main` is protected, for admins too. Ben merges, or asks his Claude to, one request each.
- "Who does what" in `CLAUDE.md` (2026-10-11): code changes come from Ben or from issues Ben assigned; T's and E's sessions run, test, QA, try assets and propose values, in this repository and never a fork.
- Ben's way of working on 2026-10-17 and 18: a step is built on a branch with a proposed spec and tests, Ben plays it on that branch and says what feels off, the fix goes on the same pull request, then he asks for the merge. A spike on a throwaway branch came first for the combat feel.
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
- To capture the running stage, a `SceneTree` script run with a window (not headless) can `change_scene_to_file`, await some `physics_frame`s and save `root.get_viewport().get_texture().get_image()`. Drive the player with an `InputSource.Held`.
- Headless Godot's dummy audio driver reports every stream that was ever played as "still in use at exit" (and leaked ObjectDB instances), however it was stopped or freed. In a window the same run reports nothing. Ignore those lines in test output; a test fails only on `failed`.
- A scene added to `root` inside a `SceneTree` script's `_initialize` gets no `_ready` yet: `await process_frame` in a helper first, then add it (`tests/coop_test.gd` does).
- Fighters in tests have no mana or guard bar unless given one (`max_mana`, `max_guard` of 0 mean free spells and an unbreakable guard), and a move list in the order the fighter tries them: a move with a motion goes before the plain button.

## Suggested next steps

1. **The core-loop feel pass** (`docs/plans/2026-10-18-core-loop-feel-pass.md`): #94, #95, #96, #97 in order, each played by Ben on its branch.
2. **Hold the meeting** with the agenda under "Waiting on people". Then mark sections 2, 5 and 9 of `docs/architecture.md` and update the game bible.
3. **T and E take the tour**, post their reactions on the issues, tune a move with the preview tool (closes #8), and put their stress-test numbers on #3.
4. **After the meeting:** the knight's solo tool or the next character (#98), the crowd's effects (#63) when Ben's arrive, the boss fight's shape (#90), the characters through the workflow in `docs/art.md`, and #4 and #5 rewritten for the chosen size.
