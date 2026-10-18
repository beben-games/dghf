# Enemy variety: kinds of small fry as data, and a telegraphed guard breaker

**Date:** 2026-10-17. **Issue:** #61, step 4 of `docs/plans/2026-10-17-vertical-slices.md`. **Built by:** Ben's Claude from the plan, with Ben at the keyboard. Ben has not reviewed the numbers yet.

**Status: proposed.** The crowd body stays one pooled `CrowdBody`; a `CrowdKind` resource in `data/enemies/` says what it is when revived: health, speed, colour and size, reach, a shield, its swing and an occasional special. Four kinds to start, and the director mixes them into every wave. Every number is data to tune by playing.

## The kinds

| Kind | Health | Speed | What it does | Beat it with |
|---|---|---|---|---|
| **Small fry** (`small_fry.tres`) | 30 | 4 | The jab, as before. | Anything. |
| **Fast** (`fast.tres`) | 15 | 7.5 | Slighter, with a knife; closes in quickly and jabs. | A light; it dies in two. |
| **Shielded** (`shielded.tres`) | 40 | 3 | A shield of 40 stops hits from the front while it stands or walks, drained by their damage; the hit it can't take breaks it and launches the body. One swing in three is the **shield bash**: a 36-tick wind-up with a red mark over its head and the shield raised, then a hit that **breaks a raised guard**, so a player who blocks it is launched. | Two heavies, hits from behind, or a launcher. Dodge the bash, or step out of its reach: it travels. |
| **Thrower** (`thrower.tres`) | 20 | 3.5 | Stops 520 pixels away, backs off when the player comes within 320, and throws a rock: a small slow projectile for 8. | Close in: it backs off slowly. A fireball from range. |

A wave of ten is mostly plain, with every sixth from the second fast, every sixth from the fourth shielded, and every eighth from the seventh a thrower (`PocStage.wave_kind`): about two fast, one or two shielded and one thrower. In the sandbox, **3**, **4** and **5** put one of each in front of you.

## How it is built

- `CrowdKind` (`systems/enemies/crowd_kind.gd`): `max_health`, `walk_speed`, `body_color`, `scale`, `look` (how the plain figure is varied), `attack`, `special` and `special_one_in`, `reach`, `keep_away`, `shield`.
- `CrowdBody.revive` takes a kind and applies it; `CrowdDirector.spawn` takes a kind, the plain small fry when left out. The director asks each body its `reach()` and `keep_away()`, rolls the special one swing in `special_one_in` when it hands out a token, and gives bodies the stage's `Projectiles` for their rocks.
- **The shield** reuses the guard-bar rules on the crowd body: `blocks`, `blocks_hit`, `take_block` (drains, nudges back) and `take_hit` (breaks: the hit lands with at least an 18 launch, and `just_broke` shakes the screen).
- **The guard breaker** is one flag on hit data, `HitBox.breaks_guard`: no guard or shield stops it, and a raised guard breaks (the fighter's own break rule: bar emptied, launched). The bash has it; nothing else does yet.
- The telegraph is `CrowdBody.telegraphing()`: the wind-up of a special before its first hit frame. The figure leans back, raises its shield and shows a red mark; a skin can use the same test.

## Proposed: choices made while building, to confirm or change

- **The shield blocks until drained, not forever.** The issue said "needs a heavy or a grab"; there is no grab yet. Two heavies (22 each against 40) do it, as do four lights; a launcher breaks it on the hit that empties it.
- **The bash breaks the guard rather than ignoring it.** A guarding player is launched, as by a guard break; a dodging one is fine; a walking one just takes 12. It travels 6 pixels a tick during its hit so it reaches a player who backs up a little.
- **Throwers hold a token** like any attacker, so three throwers at range can keep the player busy with no melee pressure. They may need their own count.
- **Mixing by position in the wave**, not by data: the arena's waves are still counts. #62 (waves as data) can carry a kind list per wave.
