class_name Move
extends Resource
## A move as data (docs/architecture.md, section 3). Durations are in ticks.
## This is the first slice: hurtbox changes come later.

## The id a cancel window lists to allow a jump.
const JUMP: StringName = &"jump"

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
## Ticks the whole motion may take. Shorter is stricter: a heavy special can ask for a cleaner input.
@export var motion_window: int = 24
## An air move starts during a jump and ends on landing. Other moves start on the ground.
@export var air: bool = false
## A follow-up never starts on its own, only as a cancel from another move.
@export var follow_up: bool = false
## A running attack: only starts during a dash (issue #80, spike).
@export var from_dash: bool = false

@export_group("Hits")
@export var hit_boxes: Array[HitBox] = []

@export_group("Cost")
## Mana the move takes to start (issue #60). A fighter that can't pay does `fallback` instead.
@export var mana_cost: int = 0
## The id of the move to do instead when the fighter can't pay: a heavy spell's light version. Empty for none.
@export var fallback: StringName = &""

@export_group("Movement")
## Frames during which nothing can hit the user (a rising uppercut's start-up). Last below first means none.
@export var invincible_from: int = 1
@export var invincible_to: int = 0
## On `rise_frame` the user leaves the ground at this upward speed (a rising uppercut), drifting
## `rise_forward` pixels a tick. The move keeps playing in the air and after landing; if it ends
## before the landing, the fall carries on as a jump.
@export var rise: float = 0.0
@export var rise_frame: int = 0
@export var rise_forward: float = 0.0
## Pixels a tick, at full speed, the user moves forward during the move (a spinning kick that
## travels; a light that steps). Eased (issue #80, Ben's quirk): it rises over the hit frames
## and settles to nothing over `travel_settle` frames after them, so the fighter never
## starts or stops in one tick. A running attack sets `travel_ease_in` false to keep the
## run's pace into the hit.
@export var travel: float = 0.0
@export var travel_settle: int = 0
@export var travel_ease_in: bool = true

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
## How large the projectile is, against the plain fireball. 2 is twice as wide and tall.
@export var projectile_size: float = 1.0
## A piercing projectile goes through everything it hits, hitting each body once.
@export var projectile_pierce: bool = false
## A fireball flies along the lane; a burst grows around the point it leaves from and
## hits every lane; a missile homes on the nearest enemy, across lanes.
@export var projectile_kind: Projectiles.Kind = Projectiles.Kind.FIREBALL
## Ticks it lasts, or 0 for until it leaves the screen.
@export var projectile_lifetime: int = 0
@export var projectile_all_lanes: bool = false
## How hard a missile turns toward its target each tick (pixels a tick of speed change). 0 flies straight.
@export var projectile_homing: float = 0.0
## How many leave, one every `projectile_interval` ticks from `projectile_frame`, fanned out
## vertically by `projectile_spread` pixels a tick each.
@export var projectile_count: int = 1
@export var projectile_spread: float = 0.0
@export var projectile_interval: int = 0
## Ticks a missile flies straight before it starts to home, so a fan opens before it closes in.
@export var projectile_homing_delay: int = 0


## How far the user moves on `frame` of this move: the travel eased over the hit frames and
## the settle after them. 0 outside that window or for a move that does not travel.
func travel_speed(frame: int) -> float:
	if travel <= 0.0 or hit_boxes.is_empty():
		return 0.0
	var from: int = hit_boxes[0].first_frame
	var to: int = hit_boxes[0].last_frame
	for box in hit_boxes:
		from = mini(from, box.first_frame)
		to = maxi(to, box.last_frame)
	if frame < from or frame > to + travel_settle:
		return 0.0
	if frame <= to:
		if not travel_ease_in:
			return travel
		return travel * sin(0.5 * PI * float(frame - from + 1) / float(to - from + 1))
	return travel * cos(0.5 * PI * float(frame - to) / float(travel_settle + 1))


## Whether `other` can start now, cutting this move short on `frame`.
func can_cancel_into(other: Move, frame: int, has_hit: bool) -> bool:
	return can_cancel_into_id(other.id, frame, has_hit)


func can_cancel_into_id(other_id: StringName, frame: int, has_hit: bool) -> bool:
	for window in cancels:
		if window.allows(other_id, frame, has_hit):
			return true
	return false
