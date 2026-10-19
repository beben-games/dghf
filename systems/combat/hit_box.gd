class_name HitBox
extends Resource
## One hitbox of a move: where it is and on which frames it is active.

## First and last frame of the move on which the box can hit (frame 0 is the first).
@export var first_frame: int = 0
@export var last_frame: int = 0
## Relative to the fighter's feet, for a fighter facing right. Up is negative y.
@export var rect: Rect2 = Rect2()
@export var damage: int = 0
@export var hitstun: int = 0  # ticks
@export var hitstop: int = 0  # ticks
## Ticks a blocking target is held in its guard by this hit. Blocked hits do no damage.
@export var blockstun: int = 0
## Speed the target is pushed away at, in pixels per tick. On the ground it fades out.
@export var knockback: float = 0.0
## Upward speed given to the target, in pixels per tick. Above 0 the hit launches.
@export var launch: float = 0.0
## Screen shake in pixels. Leave at 0 for all but heavy hits.
@export var shake: float = 0.0
## Mana the hit pays its attacker when it lands (issue #60). A blocked hit pays nothing.
@export var mana: int = 0
## A guard breaker (issue #61): no guard or shield stops it, and a raised guard breaks.
@export var breaks_guard: bool = false
## A grab (issue #67): no guard stops it (and none breaks); the target is held for `hitstun`
## ticks where it stands, then thrown with `launch` and `knockback`.
@export var grab: bool = false
## A move hits each target once per group: boxes in different groups are separate hits
## (a spinning kick that hits twice has two boxes in groups 0 and 1).
@export var group: int = 0


func active_on(frame: int) -> bool:
	return frame >= first_frame and frame <= last_frame
