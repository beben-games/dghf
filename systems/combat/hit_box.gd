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


func active_on(frame: int) -> bool:
	return frame >= first_frame and frame <= last_frame
