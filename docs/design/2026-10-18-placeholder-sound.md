# Placeholder sound

**Date:** 2026-10-18. **Issue:** #65, step 8 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan. Ben has not heard it yet.

**Status: proposed.** The melee has sound: ten short cues and a music loop, played through one pool of players with nothing made per hit. The cues are placeholders made by the team's own script, so no licence is involved; the game bible's decided direction for music (energetic orchestral and gothic, Castlevania and The Witcher) is for the real music, not these.

## What it does

| Cue | When |
|---|---|
| swing | a fighter or a small fry starts a move without a projectile |
| fireball | a move with a projectile starts: a spell, a thrower's rock |
| dash | the dash or the step back starts |
| hit, hit_heavy | a hit lands on a fighter or a small fry; heavy when it launches or does 18 or more |
| block | a guard or a shield stops a hit |
| guard_break | a guard or a shield breaks |
| death | the hit that empties a body's health |
| barrel | a barrel breaks (a hit that only cracks it plays `hit`) |
| pickup | a potion is taken |

A sixteen-second loop in A minor plays in every scene of the stage. **F9** mutes everything.

## How it is built

- `Sounds` (`systems/audio/sounds.gd`) is one node in the stage with twelve `AudioStreamPlayer`s and one for the music. `Sounds.play(&"hit")` from anywhere takes a free player, or the oldest, sets the cue's volume and a random pitch within its wander, and plays; without a `Sounds` node in the tree it is a no-op, so tests and tools need nothing. The cues' files, volumes and wander are one table, `Sounds.CUES`: data to tune, files to swap.
- The calls are in `Combat._land` (hits, blocks, breaks, kills), `Fighter` (swings, spells, the dash), `CrowdBody` (swings and rocks), `Prop` and `Props` (barrels and potions).
- `tools/audio/make_placeholders.py` synthesizes every cue and the loop in pure Python and encodes them to OGG with `oggenc` (or ffmpeg). Rerun it to change a cue.

## What comes next

Ben, after hearing it: good enough for now. The real sounds are E's: the list of every cue and track the game needs, with what each has to say and how to deliver, is `docs/audio.md` (issue #87).

## Proposed: choices made while building, to confirm or change

- **Team-made placeholders rather than a CC0 pack.** The issue asked for CC0 sounds; a synthesized set needs no download, no credits row and no licence check, and is as easy to replace. A CC0 pack can still come in through `CREDITS.md`.
- **No panning or distance.** Every cue plays at its volume wherever it happens; with the camera framing everyone, that is near enough for now.
- **The oldest player is taken over** when twelve cues sound at once, which a crowd can reach. Cues that matter (a break, a death) could get a reserved player later.
- **One loop for every scene.** The boss fight and the menu could have their own.
