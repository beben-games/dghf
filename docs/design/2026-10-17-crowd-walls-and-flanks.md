# The crowd can't walk through a player, and surrounds through the lanes

**Date:** 2026-10-17. **Issue:** #75. **Agreed with:** Ben, after playing the melee with mana and the guard bar. A rework of the going-around rule of #49 (`docs/design/2026-10-04-hits-landing.md`, "Following and surrounding").

**Status: proposed.** The rules are Ben's: a player is a wall in its lane, guarding or not, so a tank can pack a mob for the casters to blast into and protect the characters behind it; small fry get to the other side through the lanes, not through the player. The numbers are Claude's, to tune by playing.

## What it does

- **Players are walls.** A small fry in a player's lane never crosses the player's x: walking, pushed by its neighbours or knocked back, it stops a step short. Players walk through the crowd as before, and a launched body flies over.
- **Around through the lanes.** When a body's side of its target is full, or a player has held it back on its way for a moment, it changes to the side lane with the most room, walks along it past the target, and changes back in on the far side. While the target's lane is full it waits in the side lane, beside the target.
- **No more walking through.** The old going-around, where a body crossed through the player with nobody pushing it, is gone.

Seen from the player: a wave from the left piles up against a guard and spreads into the back and front lanes, and the first ones come round behind after a few seconds. A tank at a wall with the crowd on one side holds it there for as long as its guard bar lasts.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| A body stops this far from a player it can't pass | 70 px | `CrowdDirector.wall_gap` |
| A flanking body walks this far past the target before coming back in | 220 px | `CrowdDirector.flank_past` |
| Ticks held back by a wall on its way before a body flanks | 20 | `CrowdDirector.blocked_ticks` |
| Bodies per side, per lane near the target | 3, 6, as before | `max_per_side`, `max_per_lane` |
| Bodies going round behind a player at a time | 2 (added with the taunt, so a pile spreads out gradually) | `max_flanking` |

## How it is built

- Once a tick, after the players have moved, the director notes which side of each living player every body in that lane is on; after the bodies have moved and pushed each other, any body that ended up on the other side, or within `wall_gap`, is put back at `wall_gap` from the player. Launched, dead and lane-changing bodies are left alone. A body that was walking into the wall counts the ticks it has been held.
- `CrowdBody.flank_side` and `flank_dist` say where a flanking body is going, relative to its target, and `flank_lane` which lane it took. The goal follows the target, so a player who walks away is still flanked.
- The crowd test checks that six from the left never cross a passive player, that with flanking on they still end up on both sides without a single crossing, and that a body held back by one player on its way to another goes round.

## Proposed: choices made while building, to confirm or change

- **Launched bodies fly over.** A launcher throws a small fry over the tank's head and out of the pack. The alternative is to hold launched bodies at the wall too, which would keep the pack tighter but look odd.
- **Walls are the living players only.** A player who is down is not a wall. The big dummies are not walls either; enemies pass through each other as before.
- **A dead end is a wait.** A body whose both side lanes are full stands where it is until one clears; it does not try to push through.
