# Props and pickups: barrels in three states that drop health

**Date:** 2026-10-18. **Issue:** #64, step 7 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan, with Ben at the keyboard. Ben has not reviewed the numbers yet.

**Status: proposed.** Barrels stand on the stage, break in three states under anyone's hits, and drop a health potion the player walks over. They are the first things T and E can draw with `docs/art.md` (a destructible prop: whole, damaged, broken, plus debris; a pickup); until then they are drawn in code.

## What it does

- **Barrels** stand in a lane at an x. A hit from anyone, players or enemies, projectiles too, knocks them to the next state: whole, cracked, broken. The breaking hit drops a **health potion** where the barrel stood; the broken barrel lies there a second and a half, then goes.
- **The potion** bobs on the ground. A living player who walks over it in its lane picks it up and heals 25, capped at full health; a full player picks it up too.
- **Hitting a barrel is free:** it doesn't count toward the combo, pays no mana or guard, and missiles never home on it. The hit's hitstop plays as on anything.
- **The melee's arenas have barrels**, placed by the level data: two in the first, three in the second. In the sandbox, **6** puts one in front of you; F2's presets move them with the lanes.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| Hits a barrel takes | 2 (whole, cracked, broken) | `Prop.barrel_hits` |
| A potion heals | 25 | `Props.heal` |
| Pick-up reach, along the lane | 70 px | `Props.pickup_reach` |
| A broken barrel lies there | 90 ticks | `Prop.GONE_AFTER` |
| Barrels in the melee | arena 1: x 1,900 front lane, x 2,200 back lane; arena 2: x 3,700 middle, x 4,600 back, x 5,300 front | `data/levels/melee.tres`, `ArenaData.props` |
| The pool | 24 props | `Props.capacity` |

## How it is built

- `Prop` (`scenes/props/prop.gd`) is a `Body` of team 3 with no health of its own: a barrel counts hits, a potion can't be hit. `Body.fights()` is false for it, which `Combat` reads to skip the combo count and the pay, and `Projectiles` to skip it when a missile picks a target. `Props` (`scenes/props/props.gd`) is the pool, ticked by the stage after the crowd: it drops the potion when a barrel breaks, hands potions to players who walk over them, and takes done props back. The stage adds the live props to the bodies `Combat` resolves.
- `ArenaData.props` is a list of (x, lane) for the barrels of an arena, placed when the level starts.

## Proposed: choices made while building, to confirm or change

- **Only barrels for now.** Crates and anything else are a `kind` on the same prop; the issue's "room for power-ups later" is a new kind that does something else on pick-up.
- **Enemies break barrels too.** A crowd that jabs through a barrel at the player breaks it, and a thrower's rock does. The alternative is props that only players can hit.
- **A full player still picks the potion up.** Simpler, and it clears the floor; a potion that waits for a hurt player is the alternative.
- **No debris flying, no sound.** The broken state is planks on the ground; the crowd feel pass (#63) and the sound pass (#65) can add to it.
