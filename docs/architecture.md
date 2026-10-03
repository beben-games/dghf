# Combat core: proposal

**Status: Proposed.** Claude wrote this before any code existed, from the team's questionnaire answers. Nothing here is decided. Each section gives a proposal, why, the alternatives, and the questions the team should settle. Brainstorm it, change it, throw parts out. When a section is settled, mark it **Decided** with the date and link the design spec that settled it.

The game needs three things a generic beat 'em up doesn't: fighting-game feel (frame-precise moves, combos, spell cancels), crowds of dozens of enemies, and up to three players on one screen. Every proposal below is aimed at one of those.

## 1. Time is counted in frames

**Proposal.** All combat logic runs in Godot's fixed physics tick at 60 ticks per second, and every duration is a number of frames: startup, active, recovery, hitstun, hitstop, input buffer. Nothing in combat uses seconds or `delta`.

**Why.** Fighting-game feel is tuned in frames ("this jab recovers in 9 frames"). Frame counts also make moves reproducible, so a bug can be replayed.

**Alternatives.** Seconds and `delta` everywhere: simpler to start with, but timing drifts with frame rate and is hard to tune precisely.

**Questions to settle.**
- Is 60 ticks per second right, or do we want 30 for a chunkier, more retro feel?
- What should happen on a slow machine: slow the game down, or skip frames?

## 2. A 2.5D world: x, depth and height

**Proposal.** Every fighter and enemy has a ground position (`x`, `depth`) and a `height` above the ground for jumps and launches. The screen position is `y = depth - height`, and draw order follows `depth`. A hit lands when the boxes overlap on `x` and `height`, and the two fighters are within a depth tolerance of each other (for example 12 pixels).

**Why.** In a beat 'em up you move up and down the screen as well as left and right. A jump changes height, not depth. Godot's 2D physics has no idea of depth, so a plain 2D overlap test would let you hit someone standing far behind you on screen.

**Alternatives.**
- Godot 2D physics and `Area2D`, faking depth with collision layers: quick, but jumps and depth get tangled.
- Discrete lanes like Guardian Heroes (2 or 3 depth planes you switch between): simpler hits and AI, and closer to E's "lanes" idea, but less free movement.

**Questions to settle.**
- Free movement in depth, or 2 to 3 lanes like Guardian Heroes?
- How high can characters be juggled?

## 3. Moves are data

**Proposal.** Each move is a Godot `Resource` file (`.tres`) that anyone can edit in the inspector without code:
- animation name, and total length in frames
- hitboxes: frame range, rectangle, damage, hitstun, hitstop, knockback, launch
- hurtbox changes: invincible frames, armor
- cancel windows: frame ranges where specific other moves can interrupt this one
- the input that triggers it, and the mana it costs
- effects and projectiles to spawn, and on which frame

One generic piece of code plays any move from its data.

**Why.** T and E can tune moves and make new ones without writing code, and so can their Claudes. A combo system is then just cancel windows between moves.

**Alternatives.**
- Drive hitboxes from `AnimationPlayer` tracks: common in Godot tutorials, and timing stays with the animation. But the data ends up spread across animation files and is harder to read and compare.
- Hard-code moves in scripts: fastest for the first move, slowest by the twentieth.

**Questions to settle.**
- Is the inspector enough for editing moves, or do we want a small editor that shows boxes over the sprite frame by frame?
- How do moves differ between the three characters: a shared basic set plus unique specials, or fully unique move lists?

## 4. Fighter states

**Proposal.** A small explicit state machine shared by players and enemies: Idle, Walk, Run, Jump, Attack (plays a move), Hitstun, Launched, Knockdown, Getup, Dead. Players and enemies differ in what drives them (input or AI), not in how they move or get hit.

**Why.** One shared body means a hit on a player and a hit on an enemy behave the same, and every enemy gets juggles and knockdowns for free.

**Questions to settle.**
- Do players and enemies really share everything, or do crowd enemies need a cut-down version for speed (see section 6)?

## 5. Input

**Proposal.**
- An input router assigns each device to a player (1, 2 or 3). Game code asks "what did player 2 press", never "what did the keyboard press".
- Each player has an input buffer holding the last 30 frames of directions and buttons.
- A command reader recognises motions from the buffer (for example down, down-forward, forward plus attack), relative to the way the character faces, with a few frames of leniency.
- A button pressed up to 8 frames before a move can start is kept and used, so combos don't need perfect timing.

**Why.** Fighting-game controls need motions and buffering. Routing by player index from the first line makes co-op cheap later.

**Alternatives.** Simple "direction plus button" specials (like Smash Bros. or modern beat 'em ups) instead of motions: easier to learn and to play on a keyboard, less fighting-game feel.

**Questions to settle.**
- Motion inputs (quarter circles), simple direction plus button, or both (motions for spells, simple for normal attacks)?
- How many buttons: attack, heavy, spell, jump, block?
- Is a keyboard shared by two players a case we support, or do we require gamepads for co-op?

## 6. Crowds

**Proposal.**
- Enemies are light scenes: a sprite and a script, no physics body. They are pooled: dead enemies are reset and reused, never freed.
- An enemy director moves them, keeps them from overlapping, and runs their AI in turns: each enemy thinks every 6 frames, offset from the others, rather than every frame.
- Attack tokens: only a few enemies (for example 3 per player) may attack at any moment. The rest circle, taunt and wait. Dynasty Warriors and most beat 'em ups do this: it keeps big fights readable and cuts the AI cost.
- A stress test early in Milestone 1 measures frame rate at 100, 200 and 500 enemies on each of our machines, before we commit to this.

**Why.** "Massive amounts of enemies" is the core of the game and the biggest technical risk. A scene with full physics for every enemy will likely not hold 60 frames per second with hundreds on screen.

**Alternatives.** If the stress test shows nodes are too slow: keep enemy data in plain arrays and draw them directly with Godot's `RenderingServer` or a `MultiMesh`. Much faster, but each enemy is no longer a scene you can open in the editor.

**Questions to settle.**
- How many enemies on screen at once do we want: 30, 100, 300?
- On what is the slowest machine we must support?

## 7. Hits and feel

**Proposal.** One combat system resolves every hit once per tick, in a fixed order, so results don't depend on which node happened to update first. A move hits each target once unless the move says otherwise. On a hit:
- hitstop: attacker and target freeze for 4 to 8 frames, more for heavier hits
- hitstun and knockback from the move's data
- a white flash on the target, and screen shake on heavy hits
- a combo counter for the player

These numbers are starting points to tune by playing.

**Why.** Hitstop, flash and shake are most of what makes a hit feel solid. Building them in from the first punch is cheaper than adding them later.

**Questions to settle.**
- Damage numbers on screen, or not?
- Can players hit each other in co-op (friendly fire)?

## 8. Spells and combos

**Proposal.** Spells are moves with a mana cost that spawn effects and projectiles from a pool. The basic chain is normal attacks, cancelled into a special, cancelled into a spell. Mana fills when you land hits, like a fighting-game super meter, so playing aggressively feeds the spells.

**Why.** It ties the two halves of the core together: beating up the crowd fuels the big spells, and big spells clear the crowd.

**Alternatives.** Mana that refills over time; cooldowns per spell like a MOBA; spells unlocked by combo length.

**Questions to settle.**
- How does mana fill: from hits, over time, or both?
- Can players combine spells in co-op (one player's spell triggers another's)? This is a later-version idea, but it changes how spells are built if we want it.

## 9. Camera and screen

**Proposal.**
- Internal resolution 480 by 270 pixels, scaled by whole numbers to the window (four times for 1080p), so pixel art stays sharp.
- The camera follows the middle of all active players. Players can't walk off screen: the screen edges hold them back, rather than the camera zooming out.
- Arenas: in some places the camera locks until the enemies there are cleared, as in most beat 'em ups.

**Why.** Zooming pixel art makes it blurry or uneven. A fixed zoom with edges that hold players together is the classic beat 'em up answer.

**Questions to settle.**
- 480 by 270, or smaller (384 by 216) for bigger-looking sprites?
- Is the fixed zoom acceptable once three players and a crowd share the screen?

## 10. Code layout

**Proposal.** Following `CLAUDE.md`:
- `systems/combat/`: frame clock, hit resolution, hitstop, move player
- `systems/input/`: device routing, input buffer, command reader
- `systems/camera/`
- `systems/enemies/`: director, pool, attack tokens
- `scenes/fighter/`: the shared fighter body and states
- `scenes/player/`, `scenes/enemies/`, `scenes/levels/`
- `data/moves/<character>/`: move resources
- a debug overlay, on a key, that shows hitboxes, hurtboxes, frame counters, the frame rate and the enemy count
