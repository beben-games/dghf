# The fighting-game camera for boss fights

**Date:** 2026-10-18. **Issue:** #66, step 9 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan. Ben has not played it yet.

**Status: proposed.** In the boss fight the camera zooms and pans on the two fighters, pulling out as they separate, as Street Fighter does; the screen's edges hold both in. The lanes are untouched: the view changes, not the world, so the depth presets and everything built on the lanes stay as they are. Section 9 of `docs/architecture.md` proposed a fixed zoom for the melee; this is the boss fight's exception, and goes to the meeting with the rest of the camera.

## What it does

- **Zoom on the pair.** The view is as wide as the two fighters need plus a margin on each side, between the full screen and 1.6 times closer. Close together, the fighters fill the screen; as they separate the camera pulls out, until the whole screen shows and the edges stop them.
- **Pan on the pair.** The view centres on their midpoint, eased, and sits a little above their feet, so the fighters stand in the lower half with air above for jumps and launches; it never shows past the stage.
- **Both are held in.** The player and the boss get the view's edges as their bounds, less a margin, so neither walks out of frame, and a cornered fighter is a cornered fighter.
- **Everything else is as before:** the HUD stays on its layer, the shake is still the camera's offset, the backdrop drifts with the zoom. The melee and the sandbox keep the beat 'em up camera.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| Closest zoom | 1.6 (a view 1,200 by 675) | `StageCamera.max_zoom` |
| Margin beside the pair, at zoom 1 | 260 px each side | `StageCamera.fight_margin` |
| How fast the zoom follows | 0.06 of the gap a tick | `StageCamera.zoom_speed` |
| The view's centre above the fighters' feet | 320 px | `StageCamera.fight_lift` |
| Pan speed | the follow speed, 0.12 | `StageCamera.follow_speed` |
| The margin that holds a fighter in | 120 px, as in the melee | `PocStage.MARGIN` |

## How it is built

- `StageCamera.frame_fight(bodies)`: the span of the bodies' x plus two margins gives the wanted zoom, clamped; the zoom eases toward it; the centre eases toward the midpoint and toward the feet less the lift, both clamped so the view, at its current zoom, stays inside the limits and the screen. `left()`, `right()` and so `player_bounds()` read the zoomed view, so the stage's bounds, spawns and projectiles need nothing. `reset_view()` puts the zoom and the height back when the mode changes.
- The stage frames the living players and the big dummies in the boss fight, and gives the dummies the view's bounds there; elsewhere it follows the players as before.

## Proposed: choices made while building, to confirm or change

- **1.6 at the closest**, so a 280-pixel fighter stands 450 tall on screen: big, but the lanes 35 pixels apart in this mode still read. Street Fighter zooms less; a beat 'em up with huge sprites may want less too.
- **The view never tilts or looks ahead** in this mode: with two fighters the midpoint is the subject.
- **Lanes stay.** A boss in another lane still can't be hit; the camera does nothing about it. If the meeting drops lanes in boss fights, this camera needs no change.
- **The dummy is held in like a player.** A boss that should be able to leave the screen (to retreat and come back) would need its bounds freed in its own brain.
