# Hits landing: a training dummy

**Date:** 2026-10-04. **Issue:** #9. **Built by:** Ben's Claude from the status page's next step, not from a brainstorm. Ben has not reviewed the choices below yet.

**This decides nothing new.** It builds the hit rules that are already **Decided** (`docs/design/2026-10-03-combat-core.md`, section 7 of `docs/architecture.md`) into the proof of concept, so the team can feel them. Every number is a starting point to tune by playing. The choices listed under "Proposed" are Claude's and are open to change.

## What it does

The proof-of-concept stage now has a training dummy (the red figure). The player's attacks land on it:

| Move | Keyboard | Gamepad | What it does |
|---|---|---|---|
| Light | J | X | A quick hit: hitstun and a push back. |
| Heavy | L | Y | A launcher: the dummy flies up, the screen shakes, and it lands knocked down. |
| Fireball | Down, down-forward, forward, then light | The same | Hits from a distance. It does not freeze its caster. |

A light attack right after a heavy catches the dummy on its way down: a two-hit juggle, and the combo counter appears. F1 shows hitboxes (red) and hurtboxes (blue).

## How it is built, following the decided rules

- **One system, once per tick, in a fixed order** (`systems/combat/combat.gd`). After everything has moved, `Combat` checks fighters in the order they were added, then projectiles. It finds every hit before applying any, so two attacks that connect on the same tick both land.
- **A move hits each target once.** The fighter remembers who its current swing has hit.
- **Hitstop.** The attacker freezes once per swing, for the longest hitstop among the hits it lands on that tick. Each target freezes on its own. A swing through six targets freezes the attacker once. A frozen fighter still records its input, so a press during the freeze is not lost.
- **Teams.** A hit only lands on a fighter of another team, in the same lane.
- **Drawn from a pool.** Hit sparks are one pooled system (`systems/combat/hit_sparks.gd`), not a node per hit. The white flash is a small shader on the fighter's own view.
- **Juggles.** No height limit. Each hit taken in the air adds a quarter to the target's gravity (`juggle_gravity_growth`), so it falls faster each time. Landing resets it.
- **Hit data** (`systems/combat/hit_box.gd`): `knockback`, `launch` and `shake` join damage, hitstun and hitstop. A projectile carries its own hit data (`projectile_hit` on the move).
- **Tuning in the editor.** The Player and Dummy are nodes in `poc_stage.tscn`, so walk speed, gravity, hurtboxes, knockdown time and the rest are in the inspector. Hit values are in the move files in `data/moves/poc/`.

New fighter states: hitstun, launched, knockdown and getup. A skin may add the animations `hurt`, `launched`, `knockdown` and `getup`, and one named after each new move (`heavy`). A state the skin has no animation for is drawn as the plain figure.

## Proposed: choices made while building, to confirm or change

- **A hit pushes the way the attacker faces**, and turns the target to face the attacker.
- **A fighter on the floor or getting up can't be hit.** The alternative is hits on downed enemies, as many beat 'em ups allow.
- **Any hit on a fighter in the air sends it into the launched state**, and it lands knocked down. There is no air recovery.
- **The combo counter counts hits on one target** while it is still reeling, like a fighting game, and shows from the second hit. With a crowd this needs rethinking: most beat 'em ups count every hit landed within a short time, whoever it lands on. This is for the team.
- **Screen shake** only on hits whose data asks for it.
- **A third button, heavy**, on L and gamepad Y. The button layout is still proposed (section 5).
- **The dummy is a full fighter** with no input, not the crowd body, which does not exist yet. The crowd body must take hits through `Combat` by the same rules when it is built.

## Air attacks (issue #23)

Asked for by Ben after playing the dummy. Light and heavy also work during a jump, as their own moves (`air_light.tres`, `air_heavy.tres`), marked `air` in the move data. A move is either an air move or a ground move.

- An air move follows the jump's arc. Landing ends it at once, and if it ends first the jump carries on, so a long jump has room for more than one.
- They hit through the same rules. An air light late in a jump, then a ground light pressed before landing, is a two-hit combo on a standing target. After a launcher, a jump and an air attack continue the juggle.
- A skin may add the animations `air_light` and `air_heavy`.

**Proposed, to confirm or change:** any number of air moves per jump, no turning around in the air, no special moves in the air, and an air heavy that is a plain strong hit: it does not spike the target into the ground.

**A side effect.** Attack pressed just before landing used to be kept and come out as a ground attack. It now starts an air attack. A press made during an air move is still kept for the landing.

## Cancels between moves (issue #8)

Asked for by Ben. A move can now be cut short by starting another one, which is what makes combos. This follows the decided design: cancel windows are part of a move's data (`docs/architecture.md`, section 3).

- **A cancel window** (`systems/combat/cancel_window.gd`) is a range of frames, the ids of the moves that can start during it, and whether the move must have hit first. A move has a list of them, and an `id` that other moves name.
- **A follow-up** is a move that never starts on its own, only as a cancel. The second light (`light_2.tres`) is one: pressing light again during a light that hit.
- **A press made during hitstop is kept** until the freeze ends, so the natural rhythm works: hit, press, and the next move comes out as the freeze lifts.
- **Since #80** (`docs/design/2026-10-17-combat-feel.md`, proposed) the windows only bind a whiff: a swing that has landed can be cut into anything.

The cancels in the proof of concept, all only on hit:

| From | Into |
|---|---|
| Light | Second light, heavy, fireball |
| Second light | Heavy, fireball |
| Heavy | A jump |
| Air light | Air heavy |

So light, light, heavy is a three-hit ground combo that launches, built entirely from data. Holding up, or up and forward, as the launcher lands jumps after the target, and air light then air heavy adds two more: five hits.

A jump is not a move, so a window allows it by listing the id `jump`. The jump comes out when the hitstop ends.

**Proposed, to confirm or change:** every cancel needs a hit, the heavy can only be cancelled by a jump, and the fireball cancel may or may not combo depending on distance: its values are untuned. The second light has its own animation name, `light_2`; a skin without it shows the plain figure.

## Guard (issue #41)

Asked for by Ben on 2026-10-11, once he and T had agreed on two attacks plus guard. The position "block and dodge" (section 4 of the architecture) is still proposed; this builds the block half so the team can feel it.

- **Hold K (B on a pad) on the ground to guard.** The fighter stops, keeps facing the way it faced, and blocks.
- **A hit from the front is blocked:** no damage, no flash, no combo count. The blocker is held in the guard for the hit's `blockstun` (move data, on the hitbox) and pushed back by part of its knockback (`block_pushback`, 0.6). Both fighters freeze for half the hit's hitstop, at least 2 ticks (`block_hitstop`). The spark is blue and small.
- **A hit from behind lands as usual.** A guard covers the front only.
- **A blocked launcher does not launch**, and a blocked hit does not shake the screen.
- **Letting go** during blockstun keeps the guard up until it ends; after that, the fighter stands.
- **F4** makes the training dummy guard, so the player can see all of this. A skin may add a `block` animation.

**Proposed, to confirm or change:** no chip damage; no guard in the air; guard with down held is the same standing guard (no low guard, no high and low mixing); guard beats launchers; the attacker is not pushed back on block; blockstun values (light 8, second light 10, heavy 14, air light 8, air heavy 12, fireball 10). How enemies beat a guard (grabs, attacks from behind, guard breaks) is enemy design for Milestone 2. Dodge is not built.

## Dodge (issue #43)

Asked for by Ben on 2026-10-11, the other half of "block and dodge".

- **Shift (the right trigger on a pad)** dashes along the lane: in the held direction, or a step back when neutral. The fighter keeps facing the way it faced.
- **Invincible in the middle:** nothing hits the fighter from its tick 2 to its tick 11 (`dodge_invincible_from`, `dodge_invincible_to`); it is drawn half transparent and without a hurtbox then. The dodge lasts 16 ticks (`dodge_ticks`) and covers 18 pixels a tick while invincible (`dodge_speed`), then slides to a stop. The last 5 ticks are the recovery: still dodging, but hittable, and nothing else can start.
- **Usable** from standing, walking, crouching, and out of a guard once its blockstun is over. Not in the air, and a press in the air is not kept for the landing.
- A skin may add a `dodge` animation.

**Proposed, to confirm or change:** the timing (16 ticks, 10 invincible, 5 of recovery), the distance (about 200 pixels), neutral means back, no cost and no cooldown, no cancel into or out of a dodge, and a dodge does not pass through fighters (there is no body collision yet, so today everything passes through everything).

## The first enemy that attacks (issue #45)

Asked for by Ben on 2026-10-11: guard and dodge needed something to guard and dodge.

- **F5** makes the training dummy fight back (since 2026-10-15 it starts and stops every enemy on the stage, the small fry included). It is the same full fighter, driven by a `FighterBrain` (`systems/enemies/fighter_brain.gd`) instead of a device: an input source that presses buttons, so the enemy moves, attacks, guards and gets hit exactly as a player does. This is the decided split of section 4 of the architecture. The crowd body and the enemy director are Milestone 2.
- **What it does:** follows the player to another lane only after the player has been there 45 ticks (`lane_follow_ticks`: a lane hop buys a moment, and the enemy doesn't shadow every hop), walks within reach (220 pixels), swings light or heavy (one heavy in three), rests 30 to 70 ticks between swings, turns to face the player, and guards for 24 ticks about half the time the player swings within reach. It thinks every 6 ticks, as section 6 proposes, with a seeded random so a fight replays.
- Its moves are the light, the second light and the heavy: no fireball, no air moves. Every number is a value on the brain.
- No health, no death: it fights until the player stops it or presses F5 again.

**Proposed, to confirm or change:** the reach, the rests, the guard chance, and that the enemy's moves are the player's. How it should beat a guard (today it can't: it has no grab and no attack from behind on purpose) is enemy design for Milestone 2. A player skin without `hurt`, `launched`, `knockdown` and `getup` animations shows the plain figure when hit.

## The crowd (issue #48)

The first piece of Milestone 2, from Ben's direction of 2026-10-13: one player against a large group of small fry that are a little dangerous when they gang up. Nothing here is decided; it is built to be played.

- **F6** brings ten small fry from the edges of the screen, spread over the three lanes, up to 48 (`CrowdDirector.capacity`). **R** starts over.
- **A `Body` base class** (`scenes/fighter/body.gd`) now holds what every body shares: x, lane, height, size by lane, team, health, and the whole of being hit: hitstop, flash, hitstun, launch, juggles, knockdown, getting up, death. The fighter extends it with its state machine, moves, cancels, jump, guard and dodge; the crowd body extends it with one attack. This is the "two bodies, one set of hit rules" of section 4 of the architecture, built as one base and two subclasses, pooled nodes rather than arrays (Ben's pick, 2026-10-13: 30 to 40 is the most wanted for now).
- **A `CrowdBody`** (`scenes/enemies/crowd_body.gd`): a Body with one attack from move data (`data/moves/crowd/jab.tres`: 34 frames, a hitbox on frames 16 to 20, 5 damage, 12 hitstun, 4 hitstop), 30 health (three lights), a walk, and a plain figure that draws itself with the fighter's flash shader and a shadow. It knows how to walk, wait and swing; the director says when.
- **A `CrowdDirector`** (`systems/enemies/crowd_director.gd`) owns a pool of 48 bodies, spawns and takes them back, ticks them, has each think every 6 ticks in turns, hands out 3 attack tokens so no more than three swing at once, rests a body 40 to 90 ticks after a swing, and pushes bodies in one lane apart so a crowd spreads along the lane instead of stacking. A body in another lane shadows the player's x and waits: following across lanes is issue #49.
- **Following and surrounding** (issue #49, Ben's direction): a body in another lane follows the player there after 45 ticks (`lane_follow_ticks`), one lane at a time, unless the player's lane already has 6 near it (`max_per_lane`); the rest wait in the lanes beside and shadow the player's x. In the player's lane, a body keeps to the side it arrived on; when that side has more than 3 (`max_per_side`) and the other has room, it goes around and attacks from the other side. It used to walk through the player; since #75 (`docs/design/2026-10-17-crowd-walls-and-flanks.md`) players are walls and it goes round through a side lane. Lane changes are the same hop as the fighter's, now in `Body`.
- **The player has 100 health** and goes down at 0 (the `dead` state: can't be hit, can't act). Small fry have 30 and fly off on the killing blow (`death_launch`), lie for a moment, and go back to the pool. The dummy has no health and can't die.
- **The combo counter** is now the player's: hits in a row on anyone, with no gap longer than 90 ticks (`Combat.combo_window`). One swing through six small fry counts six.
- 40 on screen run at 110 to 120 frames a second on Ben's MacBook Air with everything else on.

**Proposed, to confirm or change:** 5 damage a jab and 100 health (twenty jabs), 30 health a small fry, three attackers at once, the rests, the reach of 170 pixels, the spacing of 90, the 45-tick delay before following, 6 per lane and 3 per side, no chip or guard-breaking from small fry, and whether a swing through six should count six hits on the counter or one.

## The sandbox menu (issue #54)

Ben's direction, 2026-10-13. The game opens on a menu (`scenes/main/`) with two fights, both the same stage (`PocStage.mode`):

- **Boss fight:** the big dummy fights back from the start, and the lanes are at their closest (the 35-pixel preset: the camera "closer"). F2 still cycles the presets.
- **Melee:** no dummy; ten small fry to start, and a new wave of ten whenever fewer than ten are left, at least 240 ticks apart, endlessly, until the player is down.
- **Sandbox** (Ben, 2026-10-15): an empty stage, the 50-pixel preset. **1** adds a small fry 320 pixels in front of the player in a random lane, **2** a big dummy there in the player's lane, as many of each as wanted. Everything added stands still: the crowd director is passive and the big dummies have no brain. **F5 starts and stops every enemy at once**, big and small (it does that in every scene now); F4 makes the big dummies guard. F6 and R work too. The big dummies are made in code, so the Player is the only fighter left in the scene file for the inspector.
- **One help line** on screen: Tab opens the pause menu. The pause menu stops the clock and recaps every control and debug key; Tab or Esc closes it, M goes back to the main menu. R starts the fight over in either mode.

## Specials that scale with the button (issue #50)

Ben's direction, 2026-10-13: a spell's heavy version is twice as big and hits twice as hard, but asks a slightly harder timing. Every special is move data in `data/moves/poc/`; the heavy version is its own file.

| Motion | Light (J) | Heavy (L) |
|---|---|---|
| Fireball: down, down-forward, forward | `fireball`: 14 damage, leaves on frame 14 of 36 | `fireball_heavy`: 28 damage, twice the size, leaves on frame 22 of 46, slower, and the motion must fit in 16 ticks instead of 24 |
| Missiles: forward, then down-forward | `missiles_light`: one homing missile, 10 damage, finds the nearest enemy in any lane | `missiles_heavy`: three, 1.6 times the size, 18 damage each, launching, the motion in 18 ticks |
| Blast: down, down (two taps) | `blast_light`: a burst around the fighter that grows to about 220 pixels and hits every lane, 12 damage, pushes away from the centre. Since 2026-10-18 the get-off-me move: out at once, invincible, launches, 6 damage (`docs/design/2026-10-18-way-out-of-the-pile.md`) | `blast_heavy`: about 340 pixels, 24 damage, launches, the motion in 18 ticks |
| Super: the fireball motion twice, then L | | `super_fireball`: 40 damage, 2.6 times the size, pierces (hits everyone once), the motion in 40 ticks |

Ben's first pass (2026-10-13) had a dragon punch and a hurricane kick on the Street Fighter motions; he kept the idea and swapped the moves for the missiles and the blast, which reach across lanes and so matter against a crowd. Then the motions changed too: the quarter circle back turned the fighter around half the time (a beat 'em up fighter faces whichever way it walks, so "back" flips mid-motion and the reader saw a quarter circle forward the other way), and the full dragon punch motion was near impossible on a keyboard. So the fighter now turns only after the other way has been held 4 ticks (`turn_ticks`), the blast is two taps of down (the command reader reads a repeated direction as two taps, so holding down is not "down, down"), and the missiles are forward then down-forward.

What the moves needed, all as move data:

- **`motion_window`**: ticks the whole motion may take. The light versions keep 24; the heavy ones ask 16 or 18, which is the "harder timing".
- **Projectile kinds** (`projectile_kind`): a fireball flies along its lane; a burst stays where it leaves from, grows over its `projectile_lifetime` and hits every lane (`projectile_all_lanes`); a missile homes on the nearest enemy it can hit, turning by `projectile_homing` a tick, across lanes. `projectile_count` and `projectile_spread` fan several out. `projectile_size` and `projectile_pierce` as before.
- **Hit groups** (`HitBox.group`): a move hits each target once per group, for multi-hit moves.
- **Rising and travelling moves** (`rise`, `rise_frame`, `rise_forward`, `travel`) and **invincible frames** (`invincible_from`, `invincible_to`) are in the move data too, from the dragon punch and hurricane kick, for whoever wants a move like that.

The moves are tried in order: the super, then the heavy specials, then the light ones, then the normals. So a motion too slow for the heavy fireball with L gives the plain heavy, and the same motion with J still gives the light fireball.

**Proposed, to confirm or change:** every number above; fireballs listed before the missiles (so walking forward into a fireball motion gives a fireball); no charge moves yet (hold back, then forward), which the command reader does not read; no mana, so the super is free; the burst and the missiles are drawn in code until the team's effects arrive.

## The move preview tool (issue #8)

The decided design asks for a preview scene, so that someone who doesn't code can tune a move (`docs/design/2026-10-03-combat-core.md`). It is `scenes/tools/move_preview/`.

Run it with `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`, or open the scene in the editor and press F6.

- It shows one move from `data/moves/poc/` at a time, on one frame: the fighter in that pose, the hitboxes active on that frame in red, the hurtbox in blue, and where a projectile leaves from.
- A ruler on the ground gives distances from the feet, in pixels.
- A timeline has one cell per frame: hitboxes on the top row, cancel windows on the bottom row with the moves they lead to, and a mark where the projectile leaves.
- The text lists the move's values, and says whether the frame shown is startup, active or recovery.
- Left and right step a frame, space plays the move in a loop, up and down change move, F turns the fighter around, and a click on the timeline jumps to a frame.

**Tuning a move without code.** Leave the tool running. In the editor, double-click a move file in `data/moves/poc/`, change a number in the inspector and save. The tool notices the file changed and shows the new version within half a second. The game itself reads a move when it starts, so restart the game to play the change.

With no skin, the tool shows the plain figure, which has no pose for most frames: the boxes and the timeline are still right.

## Not built

Damage numbers and friendly fire (both proposed, for the meeting), health and death, walls or bounces, attacks from the dummy, and bodies blocking each other: the player can walk through the dummy.

## Checks

`godot --headless --path . -s tests/hits_test.gd` checks the rules above with scripted inputs: a hit and its hitstop, one hit per swing, lanes and teams, one freeze for many targets, a trade, the launch and the knockdown, the juggle and its heavier fall, the fireball, the crouching hurtbox, air moves, the jump-in combo, the air juggle, and cancels: the three-hit combo, no cancel on a miss or outside the window, the follow-up, the fireball cancel, the air cancel, the jump cancel, and the guard: from the front, from behind, against a launcher, pushback and release, not in the air; the dodge: through a hit, direction and recovery, out of a guard and not in the air; and the enemy: walking up and attacking, changing lane, and guarding sometimes.
