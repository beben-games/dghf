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

## Not built

Damage numbers and friendly fire (both proposed, for the meeting), health and death, cancels between moves (#8), walls or bounces, attacks from the dummy, and bodies blocking each other: the player can walk through the dummy.

## Checks

`godot --headless --path . -s tests/hits_test.gd` checks the rules above with scripted inputs: a hit and its hitstop, one hit per swing, lanes and teams, one freeze for many targets, a trade, the launch and the knockdown, the juggle and its heavier fall, the fireball, the crouching hurtbox, air moves, the jump-in combo and the air juggle.
