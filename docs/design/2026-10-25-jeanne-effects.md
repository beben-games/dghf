# Jeanne's first effects

**Date:** 2026-10-25. **Issue:** #63. **Written by:** Ben's Claude, from a brainstorm with Ben on 2026-10-25. **Status: proposed.** Ben set the effects for the knight; the character's identity touches #33 (who the three characters are), which is Open and for the meeting. The group judges the look of the sword hits.

## Intent

The game's placeholder effects are circles and lines drawn in code (`systems/combat/projectiles.gd`, `systems/combat/hit_sparks.gd`), and the crowd feel pass (#63) has been waiting on real ones. PixelLab added an effects generator (`POST /v2/vfx`) in October 2026, and the project's share of Ben's October generations expires at the renewal on the 27th. So the first effects are generated now, with Ben's own PixelLab account, as the project's own assets, and Ben picks from the candidates before any is wired into the game.

This changes a line of `docs/art.md` (proposed): effects were to be code first, generated only if code can't. Ben's choice on 2026-10-25 is generated effects for the spells, hits and deaths, with code for what joins points (the taunt's streaks) and for the blink of a death.

## The character behind the effects

The knight is Jeanne d'Arc in her knight version, with fire magic and a holy side (Ben, 2026-10-25). Her effects come in two flavours, fire and holy light. The same mechanic will look different on each character later: these effects are Jeanne's, not the spells'.

## The effects

| Effect | What it is | Where it plays | Generated as |
|---|---|---|---|
| **The sun** | A bright sun-like explosion bursting outward from Jeanne, shoving enemies away as it burns them | The blast, light and heavy: the same sun at two sizes, with less force and damage on the light (shortcut) version. Scales up to screen-wide once her magic stat is maxed and she casts with the double-down motion | One effect at its largest size (512 canvas), scaled down by the game |
| **The sword of flame** | A sword made of fire flying point first down the lane | The fireball, free and heavy; it pierces, which is why it is a sword | A looping flight, 256 by 128 |
| **The super's swords** | Bigger swords of holy light and fire, one per lane | The super (the fireball motion twice with heavy) | A separate, bigger looping flight, 512 by 192 |
| **The light darts** | Small darts of holy light, several at once | The missiles, homing across lanes | A looping flight, 96 by 48 |
| **Hits** | Blood as the placeholder for a landed sword blow; a small white-blue clang for a blocked one (Claude's default). A fire impact for the sword of flame, a light impact for the darts | Where a hit lands (`hit_sparks.gd`) | One-shot bursts, 96 to 128 |
| **The taunt** | A golden holy aura on Jeanne, and streaks of light flowing from the crowd toward her | While her guard taunts (#72) | The aura generated around Ben's approved knight frame; the streaks tried generated (a converging effect) and planned in code, since they run from each enemy to her |
| **Deaths** | The old-school blink out of existence, plus a blood or fire burst when appropriate | A small fry's death | The blink in code; one-shot bursts for blood (192) and fire (192 by 288) |

The sword hits are a placeholder: the group decides the look of a landed blow (blood or not) at a meeting.

## How they were made

- **Tool:** PixelLab's `POST /v2/vfx`, through `tools/art/gen.py` with the job file `art/jobs/vfx_jeanne.json`, so every call is in `art/ledger.jsonl` with its prompt, cost, effect id and edit link. The pipeline learned on 2026-10-25 to save a VFX result's files (a GIF, a spritesheet PNG with a JSON of frame durations and the anchor, and a game-pack ZIP of one sheet per part with a manifest).
- **Artist:** the pro artist for every effect, with two variants of most, and the lite artist on the main ones for comparison. A new pro effect costs 6 generations (8 with a description of 400 characters or more), lite 1; around a 256 sprite, 14 and 3. The batch was estimated at 122 generations.
- **Style sentence** in every prompt: pixel art for a 1080p beat 'em up with 230 px tall characters, lit from the top left, transparent background. The description also sets the canvas, frame count, fps and whether it loops; the result reports what it chose.
- **Tweaking is free:** every effect is saved to "My effects" on PixelLab's website, where sliders change its parts without a new generation. A change through the API with the effect's `conversation` costs 1 (lite) or 4 (pro).
- **Licence:** Ben's own PixelLab output under his subscription, publishable in this repository.

## Ben's review of the first batch (2026-10-25)

Twenty-three candidates (`art/jobs/vfx_jeanne.json`, 122 generations). Ben's words are on issue #63. **Picked, in `assets/vfx/`:** the sun (pro B, "looks great"), the sword of flame (pro B, "misshapen but looks decent"), the super's swords (pro A, "slightly misshapen, good enough for placeholder"), the light darts (pro A, "by far the better looking"), the light hit ("OK"), the block hit (pro, "much better than lite"), the blood death ("looks good"). **Kept in PixelLab's library for later, not committed:** the fire death (too much fire for a death, a spell effect later: a mob dying by fire gets a fire aura instead), the taunt aura (pro: "very basic", for a heal, a buff or the guard's glow), the pull (good but not directional: a spell that attracts, or a heal). **Lite loses** on every effect Ben compared.

**The second batch** (`art/jobs/vfx_jeanne2.json`, about 64 generations) follows from the review: a fire aura for a mob burning to death; a blood burst and a slash flash as separate one-shot effects, combined in code, the slash in one direction and rotated or flipped for the others, so no set of directional blood hits is generated; a smaller, flamier fire hit, one fresh and one as a change to the first through its `conversation`; two more tries at a taunt aura that reads as a taunt. The fire hit's size is judged in the wiring step, in action, as Ben asked.

## Ben's review of the second batch (2026-10-25)

Eight candidates (`art/jobs/vfx_jeanne2.json`, 64 generations); Ben's words are on issue #63. **Picked, in `assets/vfx/`:** the blood burst (`hit_blood`, "OK"), the small fire hit (`jeanne_fire_hit`, the fresh 96-pixel one, "OK"; the change to the first stays in the library) and taunt aura C (`jeanne_taunt_aura`, "unhinged, but lowkey good"; D was "the same vein as before"). **Library:** the slash flash, which "might still need more love" since slashes come from any direction, and may only serve a cutting spell later. **Wrong:** the two mob fire auras: the goal is the enemy sprite itself catching fire, not flames around it, so a burning death is generated around the enemy's own sprite once a small fry has one (or done as a shader on the sprite, in code). **To fix later:** the taunt aura is a perfect circle and sits off the player's centre. Its JSON carries the anchor the artist placed at the knight's feet (`kind: feet`), which the wiring uses to line it up; the shape is a slider on PixelLab.

## What is left to the next step

1. Ben picks a variant of each effect from the contact sheets and GIFs (`art/raw/vfx_jeanne/`, git-ignored), or tweaks one on the website first.
2. The chosen sheets are in `assets/vfx/` as the API's spritesheet strip with its JSON (frame durations, pivot, and a `source` block with the effect id, the call and the canvas), named `<subject>_<action>.png` as `CLAUDE.md` asks; the prompts are in the job files and the ledger.
3. Wiring (a later pull request on #63): the projectile and spark systems draw the sheets instead of circles, one shared drawing site per kind as `docs/architecture.md` section 7 asks; the sun scaled by the move's size; the blink and the taunt streaks in code; the death bursts picked by what killed the body.
4. The effects need a size check on the real stage next to the plain figure before they are called done: a 512 sun at screen-wide is a 4x upscale, which may want a bigger generation or a shader.

## A design note that fell out of the brainstorm, for #96

Ben, 2026-10-25: the buttons are light, heavy, special and guard. Pressing special alone casts a spell in its less potent form; specific motions with the special button cast the stronger versions of the spell set. That is the design for #96 (spells on buttons), and it changes the layout the team agreed in writing (two attacks plus guard), so it goes to the meeting with the build.
