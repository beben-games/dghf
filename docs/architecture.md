# Combat core

**Status: partly decided.** Claude wrote this before any code existed, from the team's questionnaire answers. A first brainstorm on 2026-10-03 (`docs/design/2026-10-03-combat-core.md`) settled the technical parts of sections 1, 3, 4 and 7. Everything a player would feel in their hands stays **Proposed** until the team agrees at a weekly meeting: where a section says "Ben's position", that is one person's view, not a decision. Each section is marked.

The game needs three things a generic beat 'em up doesn't: fighting-game feel (frame-precise moves, combos, spell cancels), crowds of dozens of enemies, and up to three players on one screen. Every proposal below is aimed at one of those.

## 1. Time is counted in frames

**Decided (2026-10-03, Ben as build owner).** See `docs/design/2026-10-03-combat-core.md`.

- All combat logic runs in Godot's fixed physics tick at 60 ticks per second.
- Every duration is a whole number of ticks: startup, active, recovery, hitstun, hitstop, input buffer. Nothing in combat uses seconds or `delta`.
- On a machine that can't keep up, the game slows down. It never skips ticks.

**Why.** Fighting-game feel is tuned in frames ("this jab recovers in 9 frames"). Frame counts also make moves reproducible, so a bug can be replayed. Skipping ticks would let a short hitbox vanish.

**Alternatives considered.** Seconds and `delta` everywhere; 30 ticks per second for a lighter crowd and a more retro feel; 60 for fighters with the crowd on every other tick.

## 2. The world: lanes or free depth

**Proposed. Ben's position (2026-10-03): 3 lanes with thickness.** For the weekly meeting. See `docs/design/2026-10-03-combat-core.md`.

**Proposal.** The ground has 3 lanes, as in Guardian Heroes. Every fighter and enemy has a position `x`, a lane, and a `height` above the ground for jumps and launches. A hit lands when the boxes overlap on `x` and `height` and both are in the same lane. A lane has thickness for drawing only: crowd enemies stand in staggered rows inside it, so a lane looks like a mass and not a queue. Draw order follows lane, then row.

**Why.** Lanes leave up and down on the stick free for jump and crouch, so fighting-game motions work (see section 5). Hits and enemy AI get simpler. It is also a first version of E's "lanes" idea.

**Cost.** Lanes limit how many enemies fit on screen: about 18 per row at 480 pixels wide with sprites about 26 wide, so roughly 110 with three lanes of two rows. A crowd can't fully surround a player.

**Alternatives.**
- Free movement in depth (`x`, `depth`, `height`, with a depth tolerance for hits): more enemies fit and crowds surround the player, as in Dynasty Warriors. Up and down then walk the character, so jump needs a button, there is no crouch, and motion inputs get in the way of movement.
- 2 lanes, or 4 to 5 lanes.

**Questions to settle.**
- Lanes or free depth? This is one decision with the input style in section 5.
- How many lanes?

## 3. Moves are data

**Decided (2026-10-03, Ben as build owner):** the data format and the tools. See `docs/design/2026-10-03-combat-core.md`.

Each move is a Godot `Resource` file (`.tres`) in `data/moves/<character>/`:
- animation name, and total length in frames
- hitboxes: frame range, rectangle, damage, hitstun, hitstop, knockback, launch
- hurtbox changes: invincible frames, armor
- cancel windows: frame ranges where specific other moves can interrupt this one
- the input that triggers it, and the mana it costs
- effects and projectiles to spawn, and on which frame

One generic piece of code plays any move from its data. A preview scene steps through a move frame by frame with its boxes drawn over the sprite, and reloads when the file changes. Each character has its own move-list resource and may add its own script on top of the shared fighter.

**Why.** T and E can tune moves and make new ones without writing code, and so can their Claudes. A combo system is then just cancel windows between moves. Numbers in the inspector alone are too blind to tune, hence the preview scene.

**Alternatives considered.** Hitboxes on `AnimationPlayer` tracks (visual, but the data is scattered and hard to compare); resources with no preview tool; hard-coded moves.

**Proposed. Ben's position (2026-10-03): fully unique move lists.** Each character has its own list with its own structure (one may have stances, another charge moves). For the weekly meeting, since how each character fights is an open point in the game bible. The alternatives are the same slots for every character with different moves in them, or shared basic attacks with unique specials.

## 4. Fighter states

**Decided (2026-10-03, Ben as build owner):** two kinds of body with one set of hit rules. See `docs/design/2026-10-03-combat-core.md`.

- **Full fighter**, for players, bosses and elite enemies: an explicit state machine (Idle, Walk, Run, Jump, Attack, Hitstun, Launched, Knockdown, Getup, Dead), a move list and cancels. Players and these enemies differ in what drives them (input or AI), not in how they move or get hit.
- **Crowd body**, for ordinary enemies: run by the enemy director, with no input buffer or move list and one or two simple attacks.
- Both take hits through the same rules and hit data, so a crowd enemy can be stunned, launched, juggled and knocked down like a fighter.

**Why.** A full fighter for each of 100 or more foot soldiers is wasted work every tick. But combos on a crowd are only satisfying if the crowd reacts like real fighters.

**Proposed. Ben's position (2026-10-03): block and dodge.** Players can guard and dodge, as in Guardian Heroes, which adds Block, Blockstun and Dodge states. Enemies then need ways to beat a guard. For the weekly meeting. The alternatives are dodge only, block only, or neither.

## 5. Input

**Proposed. Ben's position (2026-10-03): motion inputs, Guardian Heroes buttons.** For the weekly meeting. See `docs/design/2026-10-03-combat-core.md`.

**Proposal.**
- An input router assigns each device to a player (1, 2 or 3). Game code asks "what did player 2 press", never "what did the keyboard press".
- Each player has an input buffer holding the last 30 frames of directions and buttons.
- A command reader recognises motions from the buffer (for example down, down-forward, forward plus attack), relative to the way the character faces, with a few frames of leniency.
- A button pressed up to 8 frames before a move can start is kept and used, so combos don't need perfect timing.
- Up jumps and down crouches. Buttons: light, medium, heavy, jump, guard, dodge, lane up, lane down. A motion plus an attack button gives a special or a spell, and the button's strength picks the version.

**Why.** Fighting-game controls need motions and buffering, and lanes (section 2) make room for them on the stick. Routing by player index from the first line makes co-op cheap later.

**Cost.** A third attack button means more normal moves to draw and tune per character.

**Alternatives.** Simple "direction plus button" specials (like Smash Bros. or modern beat 'em ups): easier to learn and to play on a keyboard, and the natural fit for free depth. Two attack buttons with a separate spell button. Hold back to guard.

**Questions to settle.**
- Motions or direction plus button? One decision with section 2.
- The button layout.
- Is a keyboard shared by two players a case we support, or do we require gamepads for co-op?

## 6. Crowds

**Proposed.** Decided after the stress test (issue #3).

**Proposal.**
- Ordinary enemies use the crowd body decided in section 4: a sprite and a script, no physics body. They are pooled: dead enemies are reset and reused, never freed.
- An enemy director moves them, keeps them from overlapping, and runs their AI in turns: each enemy thinks every 6 frames, offset from the others, rather than every frame.
- Attack tokens: only a few enemies (for example 3 per player) may attack at any moment. The rest circle, taunt and wait. Dynasty Warriors and most beat 'em ups do this: it keeps big fights readable and cuts the AI cost.
- A stress test early in Milestone 1 measures frame rate at 100, 200 and 500 enemies on each of our machines, before we commit to this.

**Why.** "Massive amounts of enemies" is the core of the game and the biggest technical risk. A scene with full physics for every enemy will likely not hold 60 frames per second with hundreds on screen.

**Alternatives.** If the stress test shows nodes are too slow: keep enemy data in plain arrays and draw them directly with Godot's `RenderingServer` or a `MultiMesh`. Much faster, but each enemy is no longer a scene you can open in the editor.

**Note.** If the team chooses lanes (section 2), about 110 enemies fit on screen at 480 pixels wide, which bounds the first question below.

**Questions to settle.**
- How many enemies on screen at once do we want: 30, 100, 300?
- On what is the slowest machine we must support?

## 7. Hits and feel

**Decided (2026-10-03, Ben as build owner):** how hits are resolved. See `docs/design/2026-10-03-combat-core.md`.

One combat system resolves every hit once per tick, in a fixed order, so results don't depend on which node happened to update first. A move hits each target once unless the move says otherwise. Every hit checks a team. On a hit:
- hitstop: the attacker freezes once per swing, for the longest hitstop among the hits it landed, and each target freezes on its own (4 to 8 frames, more for heavier hits)
- hitstun and knockback from the move's data
- a white flash on the target, and screen shake on heavy hits
- a combo counter for the player

Anything drawn per hit comes from a shared pool. Juggles have no hard height limit: gravity grows with each hit of a juggle. The numbers are starting points to tune by playing.

**Why.** Hitstop, flash and shake are most of what makes a hit feel solid. Building them in from the first punch is cheaper than adding them later. One hitstop per swing keeps wide attacks into a crowd from feeling like glue.

**Proposed. Ben's position (2026-10-03),** for the weekly meeting:
- Damage numbers on every hit. The alternatives are a combo counter only, or numbers on big hits only.
- No friendly fire in co-op. The alternatives are a setting to turn it on, or reactions without damage.

## 8. Spells and combos

**Proposed.** Can wait until Milestone 2.

**Proposal.** Spells are moves with a mana cost that spawn effects and projectiles from a pool. The basic chain is normal attacks, cancelled into a special, cancelled into a spell. Mana fills when you land hits, like a fighting-game super meter, so playing aggressively feeds the spells.

**Why.** It ties the two halves of the core together: beating up the crowd fuels the big spells, and big spells clear the crowd.

**Alternatives.** Mana that refills over time; cooldowns per spell like a MOBA; spells unlocked by combo length.

**Questions to settle.**
- How does mana fill: from hits, over time, or both?
- Can players combine spells in co-op (one player's spell triggers another's)? This is a later-version idea, but it changes how spells are built if we want it.

## 9. Camera and screen

**Proposed.** The resolution waits on the sprite size, which is in round three of the questionnaire.

**Proposal.**
- Internal resolution 480 by 270 pixels as a placeholder, scaled by whole numbers to the window (four times for 1080p), so pixel art stays sharp.
- The camera follows the middle of all active players. Players can't walk off screen: the screen edges hold them back, rather than the camera zooming out.
- Arenas: in some places the camera locks until the enemies there are cleared, as in most beat 'em ups.

**Why.** Zooming pixel art makes it blurry or uneven. A fixed zoom with edges that hold players together is the classic beat 'em up answer.

**Questions to settle.**
- The resolution, together with the sprite size. With lanes, width sets the crowd: 384 by 216 shows about 90 enemies with bigger-looking sprites, 480 by 270 about 110, and 640 by 360 about 150 with small-looking sprites.
- Is the fixed zoom acceptable once three players and a crowd share the screen?

## 10. Code layout

**Proposed.**

**Proposal.** Following `CLAUDE.md`:
- `systems/combat/`: frame clock, hit resolution, hitstop, move player
- `systems/input/`: device routing, input buffer, command reader
- `systems/camera/`
- `systems/enemies/`: director, pool, attack tokens
- `scenes/fighter/`: the shared fighter body and states
- `scenes/player/`, `scenes/enemies/`, `scenes/levels/`
- `data/moves/<character>/`: move resources
- a debug overlay, on a key, that shows hitboxes, hurtboxes, frame counters, the frame rate and the enemy count
