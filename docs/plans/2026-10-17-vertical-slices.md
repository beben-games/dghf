# Plan: from the sandbox to two vertical slices

**Date:** 2026-10-17. **Written by:** Ben's Claude, from Ben's question "what else can we add to get a full vertical slice or two", and his list: boss fights in 1v1 zoomed up like Street Fighter, big mass battles with dozens of enemies, local multiplayer with up to three controllers. **Status: proposed.** Ben set the order; the team can change it at a meeting. Each step is an issue; a fresh session picks the first open one in order.

## Where this starts from

On `main` as of 2026-10-17 (`docs/STATUS.md` has the detail): one playable character with normals, combos through cancels, guard, dodge, a fireball in two sizes, homing missiles, an every-lane blast and a piercing super, all as move data; a training dummy that fights back; a crowd of up to 48 small fry with a director (following across lanes, going around, attack tokens); player health and death; a menu with a boss fight, an endless melee and a sandbox; a pause menu; a move preview tool; an art pipeline and guide. The stage is one screen wide and does not scroll. There is no sound, no camera, one player, one kind of small fry, free spells.

## The slices

**Slice 1, the melee:** a level of arenas and waves against a mixed crowd, with mana feeding spells, pickups, sound and a result. The core of the game as decided: huge crowds and spell combos.

**Slice 2, the boss fight:** a 1v1 against a boss with patterns, under a fighting-game camera, in rounds.

**Across both:** local co-op for two to three pads.

## The steps, in order

Sizes are in sessions of the length of the ones that built the crowd and the specials (a day's work with Ben at the keyboard playing and steering).

| # | Step | Issue | Milestone | Size | Needs |
|---|---|---|---|---|---|
| 1 | **Camera and a scrolling stage.** A Camera2D that follows the players with the screen edges holding them in; a stage two or three screens wide with a locked arena per wave; a placeholder parallax background. The piece everything else needs. | #58 | 2 | 1 | nothing |
| 2 | **Local co-op, two to three pads.** Join on a button, a tinted fighter each, the camera framing all, a health bar each, the director sharing tokens between players, no friendly fire. Early because the camera, the director and the HUD are cheaper to build for three now than to retrofit. | #59 | 3 | 1 to 2 | 1 |
| 3 | **Mana.** Hits pay, specials cost, the super costs a full bar; a mana bar. Section 8 of the architecture. | #60 | 2 | 0.5 | nothing |
| 4 | **Enemy variety.** Three small fry on the same body as data (fast, shielded, thrower) and one guard-breaking enemy move, telegraphed. | #61 | 2 | 1 | nothing |
| 5 | **Waves, arenas, a results screen.** A level is a list of arenas, each a list of waves; clear, walk on; time, hits taken, best combo at the end. The melee becomes a level. | #62 | 2 | 0.5 | 1 |
| 6 | **Crowd feel pass.** Knock-ons between small fry, launches that carry neighbours, death effects, Ben's first VFX replacing the drawn placeholders. | #63 | 2 | 0.5 | Ben's effects |
| 7 | **Pickups and destructibles.** Barrels in three states that drop health. The first things T and E draw with `docs/art.md`. | #64 | 2 | 0.5 | nothing |
| 8 | **Placeholder sound.** CC0 hits, blocks, swings, a music loop, in `CREDITS.md`; pooled players. | #65 | 2 | 0.5 | nothing |
| 9 | **The fighting-game camera.** Zoom and pan on both fighters, pulling out as they separate; lanes stay. | #66 | 3 | 0.5 | 1 |
| 10 | **A boss.** A brain with patterns, telegraphs, a grab, two phases; a health bar with a name; the first real second character through the workflow, on the plain figure. | #67 | 3 | 1 to 2 | 4, 9 |
| 11 | ~~**Rounds.** KO, best of three, rematch.~~ Scrapped by Ben on 2026-10-18: boss fights are asymmetric, the boss much stronger and all three characters needed (issue #90 asks how). | #68 | 3 | 0 | |

About 8 to 10 sessions in all. Steps 3, 4, 7 and 8 need nothing and can be taken out of order when the camera work waits on something.

## What gates it that is not code

- **The weekly meeting:** lanes and depth (the 50-pixel preset), the resolution (the probe says keep 1080p), E's confirmation of two attacks plus guard, what guard and dodge should stop, the enemy's feel, the bosses that unlock (#33). Step 2 is where the lane and resolution decisions bite hardest: three 240-pixel characters plus a crowd is tight.
- **Ben's effects** for step 6: a missile, a blast ring, a fireball, hit sparks (asked for on 2026-10-15; sizes in the pull request of #56).
- **Round three of the questionnaire** for step 10: who the boss is comes from the team's characters.

## How a fresh session picks this up

1. Read `CLAUDE.md`, then `docs/STATUS.md`, then this plan.
2. Take the lowest-numbered open issue of the table whose "needs" are done, assign it, move it to In progress, branch `code/<issue>-<name>`.
3. Design choices a player feels go in `docs/design/` marked proposed, as the crowd's did in `docs/design/2026-10-04-hits-landing.md`. Every number is data to tune.
4. Tests in `tests/` for the rules; a capture of the running stage for the look; `docs/STATUS.md` updated; a pull request "Part of #n" unless the issue's "done when" is met.
5. Ben merges, and builds the private build himself (`scripts/build.sh --skin local/skins/player`).
