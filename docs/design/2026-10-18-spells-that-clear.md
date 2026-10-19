# Spells that clear: heavy spells that launch a pile, a super that sweeps the lanes

**Date:** 2026-10-18. **Issue:** #95, step 2 of `docs/plans/2026-10-18-core-loop-feel-pass.md`. **Built by:** Ben's Claude from the plan, after Ben's play of the melee for #92: spells should be "more powerful or at least wide, to help clear up in a satisfying way", and his correction on the issue the same day: a heavy spell must not kill outright as a rule.

**Status: proposed.** Ben has not played it yet. Every number is move data in `data/moves/poc/`, a hit resource in `data/moves/crowd/`, or a value on `Combat`, to tune by playing. Nothing decided changes: the spells keep their motions (`docs/design/2026-10-04-hits-landing.md`), mana keeps its rules (`docs/design/2026-10-17-mana.md`, with new numbers below), the light blast stays the free get-off-me move (`docs/design/2026-10-18-way-out-of-the-pile.md`), and the crowd keeps its walls and flanks.

## Damage is a number, not a rule

Ben, 2026-10-18, on "a heavy spell kills a plain small fry outright": "It shouldn't kill outright all the time. Later levels will have stronger mobs, and damage should eventually depend on character stats and how the player chooses to increase them during levelling. I guess a level 1 character being able to kill a level 1 mob with the strong version of the blast makes sense, but let's not make it a rule."

So the heavy spells do 30 damage, and the first level's plain small fry has 30 health (`data/enemies/small_fry.tres`): today a heavy spell happens to kill it, and a fast one dies to a light fireball or missile. That is how the numbers fall for a level-1 knight against level-1 small fry, not a rule the code knows. Nothing in the code says "a heavy spell kills": damage is the plain `damage` field on each hit, health the plain `max_health` on each kind, and a later level's stronger mob or a character stat (RPG progression, decided for later versions in the game bible, 2026-09-27) changes one number or multiplies the other. When stats arrive, the place for them is a multiplier on the fighter applied where `Combat` lands a hit, not a change to the move files.

## What it does

**A heavy spell hits hard, wide, and launches.** Each heavy spell is the light one's shape made big: twice the damage, a launch strong enough to lift the Captain (above its `launch_resist` of 20), and a reach that takes a pile rather than a body.

- **The heavy fireball** flies along the lane and goes through everyone in it: a line of small fry in your lane is launched one after the other as it passes. 30 damage, a launch of 24, two and a half times the plain fireball's size. A raised shield stops it from the front (the shield bearer keeps its feet and loses most of its shield): what flies at a shield is blocked, what comes from the ground is not.
- **The heavy missiles** are three, each 30 damage, launching, twice the plain missile's size, homing on three different bodies across the lanes: three kills on a spread-out crowd, or three hits on a boss. They fly faster than they push (16 a tick against 10), so the second and third catch a body the first one launched; at the old speed of 11 a launched body outran them.
- **The heavy blast** is the pile clearer: everything within about 340 pixels around you, in every lane, takes 30 and is launched. A shove through shields like the light blast, so a shield bearer in the pile flies with the rest and keeps its shield (it has 40 health, so it lands alive). It still grows from the knight outward over its first 17 ticks, so the ring is seen to carry the pile.
- **The light fireball and missile** do 16 and 15: enough for a fast one (15 health). Free, as before.

**The super sweeps the screen's lanes.** The super fireball now flies in every lane at once, three and a half times the plain fireball's size, through everyone it meets: 40 damage and a launch of 26 to each body on screen in front of you. Nothing blocks it. Bodies behind you are not hit (turn around, or blast). It costs the whole bar, as before.

**A combo into a heavy spell is the loop.** The three-hit combo (light, light, heavy) pays 30 mana; every heavy spell costs 30. So the melee's rhythm is: a combo on the first body in reach, then the heavy spell of your choice on the pile it drew. The spells' own hits pay a little back (3 a body for a heavy, 2 for a light), so a heavy blast on four bodies leaves you a third of the way to the next. The super at 100 is about three combos, or two with the spells' pay-back: about one a wave if you save for it, none if you spend on heavies.

**A launched body carries the neighbours it flies into** (from #63). A small fry launched along its lane, by a spell, a running heavy, or the killing blow of a combo, bowls over every standing small fry it flies into: each one takes a jab's damage, is launched with it, and carries the next in turn. So a blast at the edge of a pile sends the first row through the second, a heavy fireball's launches pile up ahead of it, and the dead fly into the living. The carried hits count in the combo counter, credited to the player whose hit launched the first body. A body thrown straight up (the heavy's uppercut) carries nobody: only one flying along the lane does. Players are never bowled, and never bowl each other.

In the melee: jab, jab, heavy into the first one in reach; the bar is at 30; tap down twice and L; the pile around you flies, the back row carries the rows behind, and the two left standing at the far end die to a light fireball each. A wave later, with the bar full, the fireball motion twice and L sweeps what is left of the screen.

## Numbers to tune (proposed)

Spells. Every value is on the move file in `data/moves/poc/`; a hit's values are on its `projectile_hit`.

| Move | Damage | Launch | Push | Size (against the plain fireball) | Reach | Costs | Pays per body | Changed |
|---|---|---|---|---|---|---|---|---|
| `fireball` (light) | 16 | 0 | 10 | 1 | its lane, one body | 0 | 2 | damage 14 to 16 |
| `fireball_heavy` | 30 | 24 | 14 | 2.5 | its lane, through everyone (`projectile_pierce`) | 30 | 3 | damage 28 to 30, launches, pierces, size 2 to 2.5, cost 35 to 30, shake 8 to 10 |
| `missiles_light` | 15 | 0 | 8 | 1 | one homing missile, any lane | 0 | 2 | damage 10 to 15 |
| `missiles_heavy` | 30 each | 22 | 10 | 2 | three homing missiles, any lane, flying at 16 a tick | 30 | 3 | damage 18 to 30, launch 16 to 22, size 1.6 to 2, speed 11 to 16, cost 35 to 30, shake 4 to 6 |
| `blast_light` | 6 | 18 | 14 | 7 (about 240 px) | every lane around you | 0 | 0 | unchanged (#94) |
| `blast_heavy` | 30 | 22 | 14 | 10 (about 340 px) | every lane around you, a shove through shields (`unblockable`) | 30 | 3 | damage 24 to 30, unblockable, cost 40 to 30 |
| `super_fireball` | 40 | 26 | 14 | 3.5 | every lane (`projectile_all_lanes`), through everyone, nothing blocks it | 100 | 0 | every lane, unblockable, size 2.6 to 3.5, speed 10 to 14, push 12 to 14 |

Mana. On the hits in `data/moves/poc/` (`mana`) and the moves (`mana_cost`); the bar on `Fighter.max_mana`.

| What | Value | Was |
|---|---|---|
| Light, second light, air light, running light pay | 8 | 6 |
| Heavy, air heavy, running heavy pay | 14 | 10 |
| The three-hit combo pays | 30 | 22 |
| The full combo with the two air hits | 52 | 38 |
| A heavy spell costs | 30 | 35 (fireball, missiles), 40 (blast) |
| The super costs | 100 | 100 |
| The bar | 100 | 100 |

The crowd (`data/enemies/`): plain small fry 30 health, fast 15, thrower 20, shielded 40 with a shield of 40, unchanged. The Captain's `launch_resist` of 20 is unchanged: every heavy spell's launch is above it, the light blast's 18 and the carry's 16 below.

Carries. The hit a flying body gives the one it lands in is `data/moves/crowd/carry.tres`, a `HitBox`; the rest is on `Combat`.

| What | Value | Where |
|---|---|---|
| Damage | 5, a jab's | `damage` in `carry.tres` |
| Launch | 16 (below the Captain's resist: a boss is never bowled by its own small fry) | `launch` |
| Push | the flier's own speed along the lane, times `Combat.carry_share` (1: they fly together) | `Combat.carry_share` |
| Hitstop, for both | 3 | `hitstop` |
| Shake | 2 | `shake` |
| A shove | yes: a shield is kept | `unblockable` |
| Pays | 0 | `mana` |
| A flier carries only when flying at least | 6 pixels a tick along the lane (the heavy's uppercut pushes 3 and carries nobody; a light's killing blow pushes 9 and does) | `Combat.carry_min_speed` |
| Who | a body in the air after a launch, moving and not frozen, into a small fry of its own team in its lane, ahead of it, whose hurt box it overlaps; each body once per flight | `Combat._resolve_carries`, `Body.can_be_carried` (true for `CrowdBody`) |

## How it is built

- **The spells are data.** Seven move files changed and nothing in the fighter. The heavy fireball sets `projectile_pierce`; the super sets `projectile_all_lanes` and its hit `unblockable`; the heavy blast's hit `unblockable`. The push of a projectile that hits every lane was "away from the centre" for any wide one, a rule meant for the bursts; it now asks the projectile's kind (`Projectiles.kind`), so the super pushes along its flight and the heavy missiles along theirs.
- **The carries live in `Combat`,** which already resolves every hit in a fixed order: moves, then projectiles, then `_resolve_carries`. For each body in the air after a launch (`Body.State.LAUNCHED`), flying at `Body.flight_speed` of at least `carry_min_speed` and not frozen, it finds the bodies of the same team in its lane that `can_be_carried`, stand ahead of it and overlap its hurt box, and lands `carry.tres` on each with the flier's speed as its push. `Body.carried` remembers who this flight has hit; it is cleared on each new launch. `Body.hit_by`, set by `Combat` on every landed hit, says whose hit launched the flier, and that player is credited the carry in the combo counter (no mana: a carry pays nothing). The flier freezes for the carry's hitstop too, so the two crunch together before they fly on.
- **Nothing per enemy.** The carries are a loop over the launched bodies, few at a time, against the bodies in their lane; no node, no area, no signal. The pooled `CrowdBody` resets `carried` and `hit_by` on revive.

## Proposed: choices made while building, to confirm or change

- **All three heavy spells cost the same, 30,** one combo each, so the choice between them is about shape (a lane, three targets, the pile around you) and never about price. The mana spec had the blast dearer; that made it the spell the loop needed and the one you could least afford.
- **The heavy fireball pierces and the light does not.** The heavy is meant to clear a lane; the light is the free poke. The alternative, a bigger non-piercing fireball, hit one body harder, which is not what a crowd needs.
- **A raised shield stops the heavy fireball and the missiles, not the blasts.** The rule "a shield stops what flies at it; a blast comes from the ground" is easy to read on screen and gives the shield bearer a job: it is the body you blast, not the one you shoot.
- **The super is unblockable and hits every lane, in front only.** A super that a guard stops would feel broken; one that also swept behind the knight would be a screen wipe with no aim.
- **A heavy spell kills the first level's plain small fry today**, by the numbers above and not by rule (Ben's correction, quoted at the top). Keep that in mind when tuning: raising small fry health to 35 makes the heavies launchers instead of killers, with no code change.
- **Carries hit only small fry** (`CrowdBody.can_be_carried`). A launched big dummy or boss bowls small fry; nothing bowls a player, and a launched player bowls nobody, so co-op friendly fire stays off the table (proposed, for the meeting).
- **A carry does a jab's damage and pays no mana.** Carries are free hits; if they paid, launching a pile would fill the bar on its own. Their damage stacks with the spell's, so a carried body that was also in the blast takes 35.
- **The combo counter counts carries**, credited to whoever launched the flier, so a blast through a pile of eight reads "12 hits" when it carried four more. The results screen counts hits the same way.
- **The boss fight gets easier**: every heavy spell now launches the Captain, and the heavy fireball goes through it, so three missiles are 90 of 600. The boss's strength waits on the shape of boss fights (#90); nothing here is tuned for it.

## Checks

`godot --headless --path . -s tests/spells_clear_test.gd --quit-after 8000`: the heavy fireball through a line of three in its lane and not one in the next, launched and dying by today's numbers; stopped by a raised shield from the front; the heavy blast through a shield, shield kept, 30 taken; the heavy missiles' three launches; the super through three lanes and not behind; every heavy launch above the Captain's resist and the light blast's and the carry's below; a launched body carrying the one it flies into and that one the next, each a jab's damage, credited to the player; no carry from an uppercut, across lanes, or onto a player. `tests/mana_test.gd` has the new pays and costs; `tests/hits_test.gd` the new damages and the piercing heavy fireball.
