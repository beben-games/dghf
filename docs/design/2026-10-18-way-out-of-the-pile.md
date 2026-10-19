# A way out of the pile: the light blast as the get-off-me move

**Date:** 2026-10-18. **Issue:** #94, step 1 of `docs/plans/2026-10-18-core-loop-feel-pass.md`. **Built by:** Ben's Claude from the plan, after Ben's play of the melee for #92: "it's a little too difficult and frustrating to get out once you're surrounded."

**Status: proposed.** Ben played it on 2026-10-18: surrounded by six in the sandbox he gets out every time with one input, and the melee no longer frustrates when the crowd closes in. Every number is move data in `data/moves/poc/blast_light.tres`, or a value on the boss kind, to tune by playing. Nothing decided changes: the blast keeps its motion (two taps of down, then J), mana keeps its rules (`docs/design/2026-10-17-mana.md`), the crowd keeps its walls and flanks (`docs/design/2026-10-17-crowd-walls-and-flanks.md`).

## The sandbox test first: the kit, not the chaining

The plan asked for the test the review skipped: six small fry placed in front of the player (1 six times), F5, and the hop, the dash and the light blast tried in turn from the pile, to settle whether being stuck is the kit's fault or the crowd's chaining. `tests/way_out_test.gd` runs it headless, pressing each escape on the first tick the player can act once the six have surrounded it. With the kit as it was on 2026-10-18:

| Escape | Hits taken in the two seconds after it | First hit after |
|---|---|---|
| Nothing, ten seconds | 9 hits; the player can act on 118 of 600 ticks, in stretches of 5 to 29 ticks | |
| The lane hop | 4 | 72 ticks |
| The dash (right, with the pile on both sides) | 5 | 28 ticks |
| The light blast | 1 (the blast's wind-up got hit; nobody launched; the pile 70 pixels away afterwards) | |

So the crowd's chaining leaves gaps: a 3-tick input fits in every one of them, and the player is free a fifth of the time. What is missing is a move that uses the gap to clear the space: the hop buys a second before the crowd follows across the lane, the dash lands in the other half of the pile, and the old blast had ten frames of wind-up to be hit out of, no launch, and a push of about 80 pixels. It is the kit. The cap on the crowd's chain and the invincible hop ticks from the plan are not built; they stay the fallback if Ben still gets stuck.

## What it does

**The light blast is the get-off-me move.** Two taps of down, then J, from standing, walking, crouching, or out of a landed hit:

- **Out at once.** The burst leaves on the move's first frame, at its full size, and hits on the next tick. There is no wind-up to be hit out of.
- **Invincible while it comes out.** Nothing hits the knight from the first frame to the tenth: a swing that was about to land is launched instead of landing. The knight is drawn half transparent then, as in a dodge.
- **Launches everything around the knight, in every lane.** Every body within about 240 pixels, in front, behind and in the lanes beside, flies up and away from the knight, lands knocked down about 270 pixels further out, and takes a moment to get up and walk back: the space is clear for two to three seconds.
- **A shove, not a hit.** No shield or guard stops it and none breaks: a shield bearer facing it is launched like the rest and keeps its shield. It does a jab's damage, 6, so it clears the pile without killing it, and it pays no mana and costs none. The heavy blast, with L, is unchanged and stays the damage version (24, launches, 40 mana): step 2 of the plan (#95) makes it kill.
- **A boss stands through it.** The Captain takes the light blast standing, pushed back a step, so the boss fight can't be won by blasting over and over. The heavy blast and the heavies still launch it.

In the melee: surrounded, tap down twice and J. Everyone flies, the knight is clear, and the next wave of the pile is two seconds away.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| The burst leaves on | frame 0 (the move's first frame) | `projectile_frame` in `data/moves/poc/blast_light.tres` |
| Invincible | frames 0 to 10 | `invincible_from`, `invincible_to` |
| The move lasts | 24 frames | `total_frames` |
| Reach, in every lane | 7 times the plain fireball: about 240 pixels in the middle lane (the heavy is 10, about 340) | `projectile_size`, `projectile_all_lanes` |
| Full size from | its first tick | `projectile_grow` (1; 0 is the old growth over 60 percent of its life, as the heavy still grows) |
| The ring shows for | 24 ticks, the whole move (12 until #95: Ben found it too quick to see) | `projectile_lifetime` |
| Launch | 18 pixels a tick up (about 19 ticks in the air at the crowd's gravity) | `launch` on `projectile_hit` |
| Push | 14 pixels a tick away from the knight (about 270 pixels by the landing) | `knockback` |
| Damage | 6, a jab's | `damage` |
| Hitstun, hitstop, blockstun | 16, 4, 10 | the same |
| Screen shake | 6 pixels | `shake` |
| Mana cost, mana paid per body | 0, 0 | `mana_cost` on the move, `mana` on the hit |
| A shove | yes | `unblockable` on the hit |
| A boss stands through a launch up to | 20 (the light blast's 18 pushes it; the heavy blast's 22, the heavy's 32 and the dash heavy's 24 launch it) | `BossKind.launch_resist` in `data/bosses/captain.tres`, copied to `Body.launch_resist` |

A small fry it launches lands about 270 pixels further out, lies 40 ticks (`knockdown_ticks`), gets up in 20 (`getup_ticks`) and walks back at 4 pixels a tick: about two and a half seconds before it is in reach again.

## How it is built

- `Move.projectile_grow` says how many ticks a burst takes to reach its full size; `Projectiles` keeps it per projectile and the burst's radius follows it. The light blast asks for 1; the heavy blast is untouched.
- `HitBox.unblockable` is the shove: `Fighter.blocks_hit` and `CrowdBody.blocks_hit` let it through, and their `take_hit` does not treat it as a break, so the guard bar and the shield stay.
- `Body.launch_resist`: in `take_hit`, a launch at or below it becomes a plain hit with its knockback. `BossKind.launch_resist` sets it on the boss when the stage adds one. Players and small fry keep 0: anything lifts them.
- The invincible frames, the instant burst and the rest are the move data above. Nothing new in the fighter: `invincible_from` and `invincible_to` existed for a rising uppercut, and the burst already hit every lane and pierced.

## Proposed: choices made while building, to confirm or change

- **The light blast does less than it did** (6 damage, down from 12, and pays no mana, down from 2 a body). A free, instant, invincible move that also hurt and paid would be the only move worth pressing, and a mana farm. If the melee wants it to hurt, the number is `damage`; if the spells should pay, `mana` on the hit.
- **It shoves through shields.** The alternative is that the shield bearer stands through it as the counter to blasting, which breaks "always works": a pile with a shield bearer on each side would hold.
- **The boss stands through it** rather than being launched (a free knockdown loop) or being immune (a get-off-me that does nothing against a boss would feel broken). Pushed back a step, the Captain is out of grab range for a moment, which is what a get-off-me should buy.
- **The big dummies of the sandbox are launched** like small fry: they have no `launch_resist`.
- **No blast from a held guard.** The guard is let go of first; a motion during blockstun is read as before. Letting moves start out of a guard is a bigger change to the guard's feel, for its own issue.
- **The blast's own hits do not free the knight** the way a landed swing does (#80): the burst is a projectile, so the knight plays the 24 frames out. It is invincible for the first 10 and everything nearby is in the air for the rest.
- **The crowd's chain and the hop's invincible ticks are not changed.** The test above says the chain leaves gaps; if Ben still gets stuck, they go on this branch.

## Checks

`godot --headless --path . -s tests/way_out_test.gd --quit-after 8000`: the sandbox test above (the pile with no input, then the hop, the dash and the blast from it, printing their numbers; the blast must leave the player unhit for a second with nobody standing within 250 pixels), and the blast's rules: out one tick after the press and not hit out of by a swing landing that tick, every lane and behind launched and landing out of the pile, a shield shoved and kept, no mana paid or gained, a boss pushed by the light blast and launched by the heavy. `tests/hits_test.gd` keeps its blast check with the new damage.
