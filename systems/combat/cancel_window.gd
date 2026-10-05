class_name CancelWindow
extends Resource
## A stretch of a move during which it can be cut short by starting another
## move (docs/architecture.md, section 3). Combos are built from these.

## First and last frame of the move on which the cancel can happen (frame 0 is the first).
@export var first_frame: int = 0
@export var last_frame: int = 0
## The ids of the moves that can start during the window. The id "jump" allows
## a jump, which is not a move.
@export var into: Array[StringName] = []
## If on, the cancel is only allowed once this move has hit something.
@export var on_hit_only: bool = true


func allows(id: StringName, frame: int, has_hit: bool) -> bool:
	return frame >= first_frame and frame <= last_frame and (has_hit or not on_hit_only) and into.has(id)
