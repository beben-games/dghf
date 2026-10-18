class_name StageCamera
extends Camera2D
## The beat 'em up camera (issue #58; docs/architecture.md, section 9, still
## proposed): follows the players along the stage, a little ahead of where
## they face, and never shows anything past its limits. The stage drives it
## once a tick, after everyone has moved, and reads the view's edges back as
## the players' bounds, so the screen's edges hold them in. The shake is its
## offset, so nothing else on the stage has to move.

const SCREEN := Vector2(1920.0, 1080.0)

## Share of the gap to the wanted spot closed each tick. 1 snaps.
@export var follow_speed: float = 0.12
## How far ahead of the players, the way the first one faces, the view centres.
@export var look_ahead: float = 120.0

## The x range the view may show. The stage sets it, or its arenas do.
var limit_left_x: float = 0.0
var limit_right_x: float = 1920.0
## The centre of the view, before the shake.
var x: float = 960.0


func _init() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = Vector2(x, SCREEN.y / 2.0)


func set_limits(left: float, right: float) -> void:
	limit_left_x = left
	limit_right_x = right
	x = _clamped(x)
	_place()


## Jumps to centre on `to_x`, within the limits.
func snap(to_x: float) -> void:
	x = _clamped(to_x)
	_place()


## One tick of following: toward the midpoint of `targets_x` plus the
## look-ahead the way `facing` points, then clamped.
func tick(targets_x: PackedFloat32Array, facing: int) -> void:
	if targets_x.is_empty():
		return
	var mid: float = 0.0
	for target_x in targets_x:
		mid += target_x
	mid /= targets_x.size()
	x = _clamped(lerpf(x, mid + facing * look_ahead, follow_speed))
	_place()


## The view's edges on the stage.
func left() -> float:
	return x - SCREEN.x / 2.0


func right() -> float:
	return x + SCREEN.x / 2.0


## The x range a player may stand in: the view, less a margin on each side.
func player_bounds(margin: float) -> Vector2:
	return Vector2(left() + margin, right() - margin)


## The screen shake: side to side on alternate ticks, `amount` pixels.
func shake(amount: float, tick: int) -> void:
	var side: float = 1.0 if tick % 2 == 0 else -1.0
	offset = Vector2(amount * side, -amount * 0.5 * side)


## A centre that keeps the view inside the limits. Limits narrower than the
## screen centre the view between them.
func _clamped(centre: float) -> float:
	var half: float = SCREEN.x / 2.0
	if limit_right_x - limit_left_x <= SCREEN.x:
		return (limit_left_x + limit_right_x) / 2.0
	return clampf(centre, limit_left_x + half, limit_right_x - half)


func _place() -> void:
	position = Vector2(x, SCREEN.y / 2.0)
