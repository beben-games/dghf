# Local co-op: two to three pads

**Date:** 2026-10-17. **Issue:** #59, step 2 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan, not from a brainstorm. Ben has not reviewed the choices below yet.

**Status: proposed.** It builds the co-op parts of `docs/architecture.md` into the sandbox: section 5 (every input goes through a player index), section 6 (attack tokens per player), section 7 (no friendly fire, Ben's position) and section 9 (the camera follows the middle of all players and the screen's edges hold them together). Every number is a starting point to tune by playing. The lanes, the resolution and the sprite size are untouched and still wait for the meeting; the issue's own worry, that three 240-pixel characters plus a crowd is tight at the 50-pixel preset, is for playing to answer.

## What it does

- **Player 1 is always in**, on the keyboard and the first pad, as before. **Any button on an unused pad joins** the second and third players, in the melee and the sandbox, at any moment of the fight. The joining press is swallowed: it does not also swing. The new fighter appears a step behind the first living player, in its lane, facing the same way, with full health, and keeps the same moves. There is no leaving; R starts everyone over.
- **The boss fight stays one player.** It is the start of the 1v1 slice (steps 9 to 11), and a pad pressed there does nothing.
- **Each player has a colour**: blue, green, then gold. The plain figure is drawn in it; a skin is tinted toward it (player 1's skin is left as drawn). A **P1, P2 or P3** tag floats over each player's head, since three figures of one shape in a crowd are hard to tell apart.
- **The camera frames all living players**: it centres on their midpoint, and the screen's edges hold every player in. A player at an edge waits for the others: the screen does not scroll until the midpoint moves. The look-ahead is off while more than one player is alive, so no player is ever dragged along by the edge; alone, the camera follows as before.
- **A health bar each**, side by side at the top left in the player's colour, with its tag. The combo counter shows the best combo going, in the colour of the player who has it.
- **The crowd fights everyone.** Each small fry picks the nearest living player and keeps to it, switching only when another player is clearly nearer. Attack tokens are counted per player: up to three may swing at each player at once, so two players face up to six swings between them. When a player goes down the crowd turns to the others; when all are down it stands still, as before. The big dummies' brains pick the nearest living player the same way.
- **No friendly fire.** Every player is team 1, and hits and projectiles only land on another team, as they always have. A player's fireball counts toward that player's combo, not the first player's.
- **The fight ends when the last player is down**: DOWN and R to start over, which puts everyone who joined back on their feet, spread around the middle of the screen.

| Key | What |
|---|---|
| Any button on pad 2 or 3 | Join as player 2 or 3 (melee and sandbox) |
| R | Start over with everyone who joined |

## How it is built

- `systems/input/lobby.gd`, a `Lobby`: watches a `PlayerInput` per player who has not joined (the stage gives it a `Device` source per player index, so pad n is player n + 1, as `InputSource.Device` already maps), ticks them, and hands over the input of a player whose pad shows any button, with that press consumed. The fighter then owns the same `PlayerInput`, so its history already holds the press and nothing swings on the first tick. A test feeds it `Scripted` sources instead of pads.
- `StageCamera.follow(players, margin)`: the midpoint of the living players, the look-ahead only when one is alive, then every living player's bounds set to the view less the margin and its x clamped inside. The stage calls it in place of `tick`, which stays as the primitive the camera test drives.
- `CrowdDirector.targets`, an array in place of `target`. Each `CrowdBody` carries its own `target`; the director picks and re-picks it when the body thinks, counts tokens, sides and lane crowding against the body's own target, and treats a dead target as none. `FighterBrain.targets` does the same for the big dummies, picking at each decision.
- `Projectiles` remember the body that sent each projectile, and `Combat` credits a projectile's hit to it.
- `PocStage` keeps `players` and a `FighterView` each, a health bar each, and a `tick()` the physics process calls, so a headless test can load the stage, join scripted players and step it.

## Numbers to tune (proposed)

| What | Value | Where |
|---|---|---|
| Players at most | 3 | `PocStage.MAX_PLAYERS` |
| Where a joiner appears | 160 px behind the first living player | `PocStage.JOIN_GAP` |
| Where everyone stands after R | the middle of the screen, 220 px apart | `PocStage.START_GAP` |
| Attack tokens per player | 3 | `CrowdDirector.attack_tokens` |
| A small fry switches player when another is this much nearer | 300 px | `CrowdDirector.retarget_margin` |
| Player colours | blue, green, gold | `PocStage.PLAYER_COLORS` |
| How far a skin is tinted toward the colour | 0.45 | `PocStage.SKIN_TINT` |

## Proposed: choices made while building, to confirm or change

- **Join in the fight, not in the menu.** The menu is a keyboard menu for now; a pad that joins mid-fight gets a player in at once, which is how most beat 'em ups do it. A lobby screen can come with the character select, once there are characters to pick.
- **No leaving, and a down player stays down** until R. Beat 'em ups usually let a down player come back for a life or a credit; lives are not designed yet, so the fight goes on for the others and ends when the last one falls.
- **Tokens per player, not per crowd.** Section 6 says "for example 3 per player". The alternative, 3 over the whole crowd, would make two players twice as safe as one. To tune by playing: three per player may be too many when all three play.
- **Nearest player, with a margin.** A small fry stays on its player until another is 300 pixels nearer, so the crowd does not flicker between two players standing close. The alternative, switching to whoever hit it last, is a feel question for the crowd feel pass (#63).
- **No look-ahead with two or more players**, and a player at the screen's edge is blocked until the others catch up, as in Streets of Rage. The alternatives, a look-ahead the way most players face, or a camera that drags the lagging player, were tried on paper: both move a player who is standing still.
- **The keyboard stays player 1's**, with the first pad. Whether a keyboard shared by two players is a case to support is an open question of section 5 and is not answered here.
- **The boss fight stays 1v1.** A second pad there does nothing until the boss steps decide what co-op means against one boss.
