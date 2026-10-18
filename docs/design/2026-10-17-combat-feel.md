# Combat feel: a landed hit frees you, a dash with a running attack, lights that step forward

**Date:** 2026-10-17. **Issue:** #80. **Agreed with:** Ben, after playing the enemy kinds ("the feel is too clunky because our character can't move and hit at the same time") and a spike of this on a branch ("much better, a few minor quirks to fix"). The rule is Ben's and his Claude's together; the numbers are Claude's, to tune by playing.

**Status: proposed.** It changes how a swing ends, which section 3 of `docs/architecture.md` (cancel windows as data, proposed) and the "Cancels between moves" section of `docs/design/2026-10-04-hits-landing.md` describe. The windows stay; this is one rule on top of them. It is a feel change the whole team should play, so it goes to the weekly meeting before it counts as decided.

## Why

Guardian Heroes and Absolum, the references, never let you walk while swinging. They keep swings from feeling stuck in three ways: a hit that connects opens the next action at once, attacks carry you across the floor, and a dash with its own attack gets you around. Absolum leans on a dodge that cancels anything, which fits its free floor; on lanes the hop is the sidestep, so our cancel goes into the hop and the dash as much as into the next attack.

## The rule

**A landed hit frees you.** Once a swing has connected, anything can follow at once: the next attack (a chain's follow-up included), a special, a jump, a lane hop, the dash, or walking off. **A whiff commits you**: a swing that hits nothing keeps to its own cancel windows and its recovery. That is the one thing to learn, and what enemies punish.

## The dash and the running attack

Shift (the right trigger) with a direction is the dodge as before: a short dash along the lane with invincible ticks in the middle. Kept held past them, it is a **run** along the lane until let go, with no invincibility. Light or heavy during the dash or the run is a **running attack**: a lunge that carries the fighter on (`dash_light`, which chains into the second light, the heavy and the fireball on hit; `dash_heavy`, a launcher). Shift alone is still the step back, and never runs.

## Lights that step forward

The light and the second light carry the fighter forward a little during their hits, so a chain walks into the crowd on its own.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| Run speed | 12 px a tick | `Fighter.run_speed` |
| The dodge's speed and invincible ticks | 18, ticks 2 to 11 of 16, as before | `Fighter.dodge_*` |
| Light, second light step | 4, 5 px a tick during their hits | `travel` in `light.tres`, `light_2.tres` |
| Running light | 12 damage, hits frames 4 to 12 of 22, travels 12 a tick | `dash_light.tres` |
| Running heavy | 20 damage, a launch of 24, hits frames 8 to 16 of 30, travels 14 | `dash_heavy.tres` |

## How it is built

- `Fighter._tick_attack` computes `free` (the swing has hit someone) and passes it to `_try_moves` and `_can_start`, which then ignore the cancel windows; with `free`, a jump, the dash, a lane hop or a held direction also end the move. The hitstop of the hit still plays out first, so the rhythm is hit, freeze, go.
- `Move.from_dash` marks a running attack: `_try_moves` offers those only from the dash (`_tick_dodge` tries them first), and never elsewhere.
- `_tick_dodge` runs while the button is held after the invincible ticks (`_dodge_back` remembers a step back, which never runs); letting go slides to a stop as before.

## Proposed: choices made while building, to confirm or change

- **Follow-ups count as "anything".** A light pressed after a heavy that landed gives the second light (the faster one), since the heavy is "another move" to chain from. The alternative is to keep follow-ups to their chains.
- **The free cancel applies on the ground only.** Air attacks keep their windows; landing ends them anyway.
- **Walking off needs a held direction**, and happens on the tick after the hitstop; the active frames that remain are dropped. A multi-hit move cut this way loses its later hits.
- **No double-tap dash yet**, only the button. A double tap is a reading problem on the keyboard's A and D and can come later.
- **Ben's quirks from the spike are not fixed here**; they go on issue #80 as he lists them.
