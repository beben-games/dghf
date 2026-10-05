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

The cancels in the proof of concept, all only on hit:

| From | Into |
|---|---|
| Light | Second light, heavy, fireball |
| Second light | Heavy, fireball |
| Heavy | A jump |
| Air light | Air heavy |

So light, light, heavy is a three-hit ground combo that launches, built entirely from data. Holding up, or up and forward, as the launcher lands jumps after the target, and air light then air heavy adds two more: five hits.

A jump is not a move, so a window allows it by listing the id `jump`. The jump comes out when the hitstop ends.

**Proposed, to confirm or change:** every cancel needs a hit, the heavy can only be cancelled by a jump, and the fireball cancel may or may not combo depending on distance: its values are untuned. The second light has no drawing of its own and reuses the light's.

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

`godot --headless --path . -s tests/hits_test.gd` checks the rules above with scripted inputs: a hit and its hitstop, one hit per swing, lanes and teams, one freeze for many targets, a trade, the launch and the knockdown, the juggle and its heavier fall, the fireball, the crouching hurtbox, air moves, the jump-in combo, the air juggle, and cancels: the three-hit combo, no cancel on a miss or outside the window, the follow-up, the fireball cancel, the air cancel and the jump cancel.
