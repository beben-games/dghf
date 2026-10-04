# Combat core: first brainstorm

**Date:** 2026-10-03. **Brainstormed with:** Ben. **Settles part of:** `docs/architecture.md`, sections 1, 3, 4 and 7. **Issue:** #2, which stays open until the team settles sections 2, 5 and 9.

## Who decides what

Round two of the questionnaire recorded that Ben owns the Godot project and the build, and that design areas have no single owner and are decided by agreement. This spec follows that:

- **Decided** below means a technical choice, made by Ben as build owner on 2026-10-03.
- **Ben's position** means a choice a player would feel in their hands. It stays **Proposed** until T and E agree at the weekly meeting.

## Decided

### Time (section 1)

- Combat logic runs in Godot's fixed physics tick at 60 ticks per second.
- Every combat duration is a whole number of ticks: startup, active, recovery, hitstun, hitstop, input buffer. Nothing in combat uses seconds or `delta`.
- When a machine can't keep up, the game slows down. It never skips ticks or runs logic with a larger step, so a hitbox that is active for 2 ticks always gets its 2 ticks. This is Godot's default behaviour (at most 8 ticks per drawn frame), so nothing has to be built.

### Moves as data (section 3)

- Each move is a Godot `Resource` saved as a `.tres` file in `data/moves/<character>/`, with the fields listed in `docs/architecture.md`, section 3.
- One generic move player plays any move from its data.
- A preview scene steps through a move tick by tick and draws its hitboxes and hurtboxes over the sprite. It reloads when the move file changes. This is how someone who doesn't code tunes a move, and it is part of Milestone 1.
- Each character has its own move-list resource that maps inputs to moves, and may have its own script on top of the shared fighter. Shared code must not assume that every character has the same set of moves.

### Two bodies, one set of hit rules (section 4)

- **Full fighter:** players, bosses and elite enemies. It has the state machine, a move list, cancels and, for players, an input buffer.
- **Crowd body:** ordinary enemies. It is run by the enemy director, has no input buffer or move list, and has one or two simple attacks.
- Both take hits through the same rules and the same hit data. A crowd enemy can be stunned, launched, juggled and knocked down exactly like a fighter.
- The crowd stress test (issue #3) measures the crowd body, with only a few full fighters on screen.

### Hit resolution (section 7)

- One combat system resolves every hit once per tick, in a fixed order, so results don't depend on which node updated first.
- A move hits each target once, unless its data says otherwise.
- Hitstop: the attacker freezes once per swing, for the longest hitstop among the hits that swing landed. Each target freezes on its own. A swing that hits twelve enemies must not freeze the attacker twelve times.
- Every hit checks a team, so who can hit whom is data, not code.
- Anything drawn per hit (flashes, numbers) comes from a shared pool drawn by one system, never a node per hit.
- Juggles have no hard height limit. Gravity grows with each hit of a juggle, so combos end on their own. The values are tuned by playing.

## Ben's position, for the weekly meeting

| Topic | Position | Section |
|---|---|---|
| Depth | 3 lanes. Players and hits treat a lane as one line. Crowd enemies stand in staggered rows inside a lane, so it looks like a mass. | 2 |
| Special moves | Fighting-game motions. Up jumps and down crouches. | 5 |
| Buttons | Guardian Heroes style: light, medium, heavy, a jump button, guard, dodge, lane up and lane down. | 5 |
| Defence | Block and dodge. | 4 |
| Move lists | Fully unique per character: each may have its own structure. | 3 |
| Damage numbers | Shown on every hit. | 7 |
| Friendly fire | None. | 7 |
| Resolution | No position until the team settles sprite size. 480 by 270 is the placeholder. | 9 |

### Why depth and input are one decision

With free movement in depth, up and down on the stick walk the character into and out of the screen. Jump then needs a button, there is no crouch, and a quarter circle moves the character while the player is trying to cast. With lanes, up and down are free for jump and crouch, motions work as in a fighting game, and changing lane is a button. So choosing lanes largely chooses motion inputs, and choosing free depth largely chooses direction plus button.

### Costs the team should see

- **Crowd size.** Lanes limit how many enemies fit on screen. At 480 pixels wide with sprites about 26 wide, a row holds about 18 enemies. Three lanes of two staggered rows show roughly 110. "300 on screen" is out of reach unless the screen gets wider or the sprites smaller. The crowd reads as deep ranks arriving in waves.
- **Art workload.** Three attack buttons and fully unique move lists multiply the animations each character needs, and nobody has claimed art and animation.
- **Guarding.** With a block, enemies need a way to beat it (grabs, attacks from behind), or guarding is too safe. That is enemy design for Milestone 2.

## What can start, and what waits

- **Can start:** the crowd stress test (#3). Move data, the move player and the preview scene (#8), and hit resolution (#9), built against a single line as a stand-in for a lane.
- **Waits for the meeting:** movement (#6) and input (#7), which depend on lanes and the button layout.
