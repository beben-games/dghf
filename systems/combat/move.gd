class_name Move
extends Resource
## A move as data (docs/architecture.md, section 3). Durations are in ticks.
## This is the first slice: hurtbox changes and costs come later.

## The name other moves use for this one in their cancel windows.
@export var id: StringName = &""
## The skin animation to show while the move plays.
@export var animation: StringName = &""
@export var total_frames: int = 1

@export_group("Input")
## The Buttons bit that starts the move.
@export var button: int = Buttons.LIGHT
## Stick motion needed before the button, in numpad notation relative to the
## way the fighter faces. Empty means the button alone.
@export var motion: PackedInt32Array = PackedInt32Array()
## An air move starts during a jump and ends on landing. Other moves start on the ground.
@export var air: bool = false
## A follow-up never starts on its own, only as a cancel from another move.
@export var follow_up: bool = false

@export_group("Hits")
@export var hit_boxes: Array[HitBox] = []

@export_group("Cancels")
## When this move can be cut short, and by which moves.
@export var cancels: Array[CancelWindow] = []

@export_group("Projectile")
## Frame on which a projectile leaves, or -1 for none.
@export var projectile_frame: int = -1
## Where it starts, relative to the feet, for a fighter facing right.
@export var projectile_offset: Vector2 = Vector2.ZERO
@export var projectile_speed: float = 0.0  # pixels per tick
## What the projectile does to a target. Its damage, hitstun, hitstop, knockback,
## launch and shake are used. The projectile has its own shape, so the rectangle
## and the frames are not.
@export var projectile_hit: HitBox


## Whether `other` can start now, cutting this move short on `frame`.
func can_cancel_into(other: Move, frame: int, has_hit: bool) -> bool:
	for window in cancels:
		if window.allows(other.id, frame, has_hit):
			return true
	return false
