# Camera and a scrolling stage

**Date:** 2026-10-17. **Issue:** #58, step 1 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan, not from a brainstorm. Ben has not reviewed the choices below yet.

**Status: proposed.** It builds section 9 of `docs/architecture.md` (proposed) into the sandbox: a camera that follows the players and holds them on screen, a stage wider than the screen, and arenas that lock the camera until they are cleared. Every number is a starting point to tune by playing. The lanes, the resolution and the sprite size are untouched and still wait for the meeting.

## What it does

- **The stage is three screens wide** (5,760 pixels) in the melee and the sandbox, with a placeholder background in two parallax layers (hills and a castle far away, tents and trees nearer) that drift slower than the ground. The boss fight keeps a one-screen stage, so its camera stands still as before.
- **The camera follows the player** along the stage, a little ahead of where it faces, and never shows anything past the stage's ends. The screen's edges hold the player in: it can't walk off screen. There is no vertical scrolling and no zoom; the lanes stay where they are, and F2 still cycles the depth presets.
- **The melee is two arenas.** Each locks the camera within its own walls until its waves are beaten, then a flashing **GO** arrow points right and the player walks on. Walls are the arena's edges, so the player can fight back and forth inside the arena. The second arena is the end of the stage: clearing it shows **CLEAR** (a results screen is step 5, issue #62).
- **The sandbox scrolls freely** over the whole stage: no arenas, no walls but the stage's ends. It is the place to feel the camera.
- **Waves come in from off screen.** Small fry spawn just outside the view on both sides and walk in, unless a side is the stage's end: then they all come from the other side.

| Key | What |
|---|---|
| A, D | Walk; the camera follows |
| R | Start over: back to the first arena |

## How it is built

- `systems/camera/stage_camera.gd`, a `Camera2D`. Once a tick the stage hands it the players' x and the facing of the first; it moves a share of the way to the midpoint plus a look-ahead, then clamps so the view stays within its limits. It gives back the view's edges, which the stage uses as the player's `bounds`, and takes the screen shake as its `offset`, so the readout layer stays still and the stage node never moves.
- `scenes/levels/arenas.gd`, the arenas of a stage: a list of `{left, right, waves}` with the waves as counts of small fry. It locks the camera's limits to an arena once the whole view is inside it, asks the stage to spawn the next wave when few enemies are left, and opens the limits to the next arena when the last wave is dead. No arenas means a free camera.
- The crowd and the big dummies may stand anywhere on the stage, so a wave walks in from off screen and an enemy left behind follows on its own. Projectiles die 400 pixels past the view.
- The parallax is two `Parallax2D` nodes drawing plain shapes in code, repeating every 2,400 pixels. Art replaces them later.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| Stage width | 3 screens | `PocStage.STAGE_WIDTH` |
| Camera follow, share of the gap closed each tick | 0.12 | `StageCamera.follow_speed` |
| Look-ahead in the facing direction | 120 px | `StageCamera.look_ahead` |
| Margin that holds the player inside the view | 120 px | `PocStage.MARGIN` |
| Arenas of the melee | 0 to 2,400 with waves of 10 and 10; 3,360 to 5,760 with waves of 10 and 15 | `PocStage.MELEE_ARENAS` |
| The next wave comes when this many or fewer are left | 4 | `Arenas.wave_low` |
| At least this many ticks between two waves | 120 | `Arenas.wave_gap` |
| Off-screen spawn distance | 100 px, plus 40 per pair | `PocStage.SPAWN_GAP` |

## Proposed: choices made while building, to confirm or change

- **A smooth follow with a look-ahead**, not a dead zone. The camera is always moving a little when the player walks; a dead zone would feel steadier for pixel art and may be wanted once the art is in.
- **No backtracking rule between arenas.** Once an arena is cleared the player can still walk back into it until the view is fully inside the next one. Most beat 'em ups never scroll back.
- **An arena locks when the whole view is inside it**, so arenas must be at least a screen wide. The melee's are 2,400 pixels, a screen and a quarter, so the camera still scrolls a little during the fight.
- **The boss fight stays one screen** and never scrolls. The fighting-game camera for it is step 9 (#66).
- **Enemies roam the whole stage.** A small fry left off screen follows the player and comes back on its own (the director already follows across the stage). The alternative, bounds that follow the view, was tried first: passive small fry in the sandbox got dragged along by the screen's edge, which looked wrong.
- **Arena wall posts.** A dark post stands 30 pixels inside each wall, so the player sees why the screen stops. The melee's first wave comes from the right only, since the stage's start has no room off screen.
- **Midpoint of all players** is the follow target already, with the edges holding them together, ready for co-op (#59). With one player it is just the player.
