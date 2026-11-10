# Jeanne the paladin, and skins built from the game's data

**Date:** 2026-11-09. **Issue:** #104. **Written by:** Ben's Claude, from a brainstorm with Ben on 2026-11-09. **Status: proposed.** Ben set the direction and the character's brief; what touches the team's agreements (the sprite size and resolution, the art direction, who the characters are in #33) goes to the weekly meeting before it counts as decided.

## Intent

The project sat untouched from 2026-10-26 to 2026-11-09. Ben's direction on his return: dghf is now his main project and gets most of every tool's credits; October ended with about 3,600 of 5,000 PixelLab generations unused; the goal is **a working vertical slice of combat with dynamically generated art**. "Dynamically generated" means the art is built from the game's own data by the pipeline (Ben, 2026-11-09), not generated while the game runs: the move list and the enemy kinds say which animations exist, one command generates them and bakes the skin, and a new or retimed move regenerates only its own animation.

This moves on from "gameplay feel before visuals" (Ben, 2026-10-13). The feel pass is not finished (#96, #97 are open), but the art no longer waits for it.

## Jeanne

The knight of the melee becomes Jeanne d'Arc. The final release has two versions of her: **a paladin of fire and light**, and **a witch of dark fire and darkness**. The slice does only the paladin. Ben's brief for her, in his words:

> The paladin version should be a somewhat historically accurate version of Jeanne, done in subtle anime style (similar to guilty gear or last blade aesthetic).
>
> * Her head is uncovered and her face visible
> * Her plate armor is French, slightly more epic/stylish than historically accurate but not over the top
> * A fleur-de-lys emblem would be nice
> * Let's try with a one handed spear and shield as her weapon
>
> For the rest, we can play around with haircut, hair color, eye color, facial features, etc.

The prompts describe that aesthetic in words (a 1990s 2D fighting game sprite: expressive face, slender realistic proportions, clean cel shading) and name no game, since nothing in this repository comes from another game.

**What this changes, for Ben or the meeting:**

- The art direction in `docs/art.md` was Ben's realistic knight (`art/refs/user/knight_idle_frame.png`). A subtle anime style replaces it once a concept is picked: the pick becomes the approved reference for every character after her.
- A one-handed spear and shield replace the two-handed sword. Her moves are data and keep their timing, but their animations are thrusts and shield blows, and the tank's guard has a shield to show. The "sword of flame" spell may want another shape (a spear of flame); Ben's call when he sees it.

## The concept round (2026-11-09)

Eighteen candidates across eight looks (`art/jobs/jeanne_concepts.json`, 188 generations), varying hair, eyes, face and tabard, all at the 256 canvas. Three methods side by side:

- **Stills with the Pro image model** (`generate-image-v2`, 10 generations each, one 256 image): the brief held on all ten. A side stance facing right, the spear levelled, the shield forward with its fleur-de-lys, the face visible, realistic proportions with an anime face. Two of them took Ben's knight as the style image (its outline, detail and shading, not its colours): more mail and grit, less anime.
- **Characters with v3 from scratch** (9 generations, eight rotations): bigger heads and a stronger anime look, but three of six came out holding a sword with the spear on the back, and the east views are stiff.
- **Characters with Pro Flash** (17 generations): the weapons are right and the proportions realistic, but the figure is small on the canvas (about 170 pixels tall) and stands with the spear upright.

**What it means for the pipeline:** the stills are already the in-game sprite: the side view, the stance, the size. A side-scroller needs one facing, so the approved still can be animated directly as the first frame (`animate-pixminimax`, up to 40 frames at 256) with no eight-direction character in between. The recipe below names a still rather than a character id; the three-animation proof decides whether that holds.

Ben's picks: pending.

## Goals, non-goals, anti-goals

- **Goal:** Jeanne playable in the melee with a generated skin, every animation the game asks for, feet steady on the ground. Then the small fry, the effects of #63 wired in, and the rest of the slice in that order.
- **Goal:** the skin is rebuilt by one command from files in the repository, so anyone on the team can regenerate or extend it and every call is in the ledger.
- **Non-goal for the slice:** the witch version, the other two characters, final art. These are placeholders in the right look and size.
- **Anti-goal:** a set generated in bulk that nobody looked at. The team judges the look (`docs/art.md`): Ben approves the still before any animation, and three animations before the rest.
- **Anti-goal:** letting the period's generations expire again. `python3 tools/art/budget.py` shows the pace; this project's share is 0.8 since 2026-11-09.

## The pipeline: a skin from a recipe

**A recipe per character**, `art/skins/<name>.json`, committed:

- who they are: the subject sentence and the style sentence used in every prompt;
- the approved still that every animation starts from (a file under `art/refs/`, approved in `refs.json`), facing the way the game mirrors from; or a PixelLab character id and its in-game direction, if the proof shows a character animates better;
- the canvas (`cell`) and the feet point;
- one entry per animation: its name as the game asks for it, the motion in words, whether it loops, the frame count, and optionally the start or end pose.

**One command**, `python3 tools/art/skin.py build <name>` (and `plan`, which spends nothing):

1. Reads the recipe, and the move files of the character's folder (`data/moves/<folder>/*.tres`) for each move's `animation` and `total_frames`. A move whose animation the recipe lacks is reported; an attack's frame count comes from its length (a multiple of 4, about one frame per two or three ticks) unless the recipe sets it.
2. Generates what is missing or changed (a hash of the prompt, the frames and the still) with `animate-pixminimax` from the still, optionally toward an end pose: up to 40 frames at 256; the 12-frame slash of October's probe cost 2 generations. Template walks and hit reactions where a template exists (1 generation). Everything through `gen.py`, so the ledger and the allowance apply.
3. Bakes: every frame onto the recipe's fixed cell with the feet point on one pixel (`docs/skins.md`), the sheet as a grid, `skin.json` in the format `FighterSkin` already loads. Into `assets/sprites/<name>/`.
4. Writes a review page (the frames, a GIF per animation at game speed, the feet line drawn) for the person to approve or reroll an animation by name.

**The game** loads a character's skin from `assets/sprites/<name>/` (today it looks only in the private `local/skins/player/`, which stays as an override for trying art). Nothing else in `FighterView` changes.

**The risk, proved first.** PixelLab gives an animation its own canvas when the motion needs room, and the game needs the feet on one pixel of a fixed cell. The bake has to realign frames (the planted foot for ground moves, the body's centre in the air, as `docs/skins.md` describes for art without anchors). So the pipeline is proved on idle, walk and one attack, played in the game with F1 showing the feet point, before the other animations are generated.

## The slice, in order

1. **Jeanne** (#104): concepts, a pick, the character, three animations proved, then the rest (17 in all: idle, walk, crouch, jump, land, block, dodge, hurt, launched, knockdown, getup, light, light_2, heavy, air_light, air_heavy, and the cast the spells share).
2. **The small fry.** Four kinds (`data/enemies/`): plain, fast, shielded, thrower. They are rectangles drawn in `scenes/enemies/crowd_body.gd` today, so this needs code: one shared sheet per kind, drawn from the pooled bodies without a node or a texture per enemy, and the frame rate checked with a large crowd (`CLAUDE.md`, Crowds). About six animations each (idle, walk, the attack, hurt, launched and down, getup); recolours and character states for variety.
3. **The effects** of #63 (pull request #103) wired in, and the burning death generated around the small fry's own sprite.
4. **The Captain, the camp's floor and backdrop, the barrel and the potion.**

Each step is its own issue and pull request. The cost is small beside the allowance: a character is about 9 generations and a custom animation 2 to 6, so a full character with rerolls is 50 to 100.

## Claude's calls, to check

- **The 256 canvas for the 1080p screen**, matching the knight's size (about 230 pixels tall). The sprite size and the resolution are proposed and for the meeting; the slice commits art to that direction.
- **PixelLab's low top-down view, east rotation** as the in-game sprite: October's probe found it gives the three-quarter look, where the strict side view is a flat profile.
- **One recipe file per character** rather than prompts in the move files: the moves stay pure gameplay data, and two characters can share a move with different art.
- **The cast animation shared by every spell**, as today (`fireball`), until a spell wants its own.

## What is left to the builder

The recipe's exact fields, the `.tres` reading, the frame-count rule, the realignment method and the review page's layout: settled while proving the three animations, and written back here.
