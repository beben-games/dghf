class_name FighterView
extends Node2D
## Draws a Fighter. With a skin it shows the sheet's frames. Without one it
## draws a plain figure, so the game always runs with no art at all.
## Add it as a child of the Fighter.

const BODY := Color(0.35, 0.55, 0.85)
const BODY_DARK := Color(0.22, 0.36, 0.6)
const SKIN_TONE := Color(0.9, 0.75, 0.6)
const STEEL := Color(0.8, 0.82, 0.86)

var skin: FighterSkin
var show_boxes: bool = false

@onready var _fighter: Fighter = get_parent()


func _physics_process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if skin != null and skin.has(_animation()):
		_draw_skin()
	else:
		_draw_figure()
	if show_boxes:
		draw_circle(Vector2.ZERO, 6.0, Color.YELLOW)
		for rect in _fighter.active_hit_rects():
			rect.position -= _fighter.position
			draw_rect(rect, Color(1.0, 0.1, 0.1, 0.35))
			draw_rect(rect, Color(1.0, 0.1, 0.1), false, 3.0)


## The skin animation name for the fighter's state.
func _animation() -> StringName:
	match _fighter.state:
		Fighter.State.WALK, Fighter.State.LANE_CHANGE:
			return &"walk"
		Fighter.State.CROUCH:
			return &"crouch"
		Fighter.State.JUMP:
			return &"jump"
		Fighter.State.ATTACK:
			return _fighter.move.animation
	return &"idle"


func _draw_skin() -> void:
	var progress: float = -1.0
	if _fighter.state == Fighter.State.ATTACK:
		progress = float(_fighter.move_frame) / _fighter.move.total_frames
	elif _fighter.state == Fighter.State.JUMP:
		# Rising, then falling: follow the vertical speed across the animation.
		progress = clampf(0.5 - _fighter.vertical_speed / (2.0 * _fighter.jump_speed), 0.0, 0.999)
	var region: Rect2 = skin.region(_animation(), _fighter.state_ticks, progress)
	var flip: bool = (_fighter.facing < 0) != skin.faces_left
	var feet_x: float = skin.cell.x - skin.feet.x if flip else skin.feet.x
	var target := Rect2(Vector2(-feet_x, -skin.feet.y), skin.cell)
	if flip:
		# A negative width draws the region mirrored, in the same place.
		target.size.x = -target.size.x
	draw_texture_rect_region(skin.texture, target, region)


## The plain figure: about 280 pixels tall, facing by `facing`.
func _draw_figure() -> void:
	var f: float = _fighter.facing
	var state: Fighter.State = _fighter.state
	var crouched: bool = state == Fighter.State.CROUCH
	var airborne: bool = state == Fighter.State.JUMP
	var leg: float = 60.0 if crouched or airborne else 130.0
	var torso_top: float = -leg - 100.0
	var stride: float = sin(_fighter.state_ticks * 0.35) * 22.0 if state in [Fighter.State.WALK, Fighter.State.LANE_CHANGE] else 0.0
	# legs
	draw_rect(Rect2(-34.0 + stride, -leg, 28.0, leg), BODY_DARK)
	draw_rect(Rect2(6.0 - stride, -leg, 28.0, leg), BODY_DARK)
	# torso and head
	draw_rect(Rect2(-40.0, torso_top, 80.0, 100.0), BODY)
	draw_rect(Rect2(-24.0, torso_top - 50.0, 48.0, 48.0), SKIN_TONE)
	draw_rect(_faced(Rect2(20.0, torso_top - 34.0, 12.0, 10.0), f), SKIN_TONE.darkened(0.2))  # nose
	# arm and sword
	var arm := Rect2(10.0, torso_top + 24.0, 50.0, 18.0)
	var sword := Rect2(50.0, torso_top - 40.0, 10.0, 80.0)
	if state == Fighter.State.ATTACK:
		var t: float = float(_fighter.move_frame) / _fighter.move.total_frames
		var reach: float = sin(t * PI)
		arm = Rect2(10.0, torso_top + 24.0, 50.0 + 60.0 * reach, 18.0)
		if _fighter.move.projectile_frame >= 0:
			sword = Rect2(arm.end.x - 8.0, torso_top - 10.0, 10.0, 90.0)
		else:
			sword = Rect2(arm.end.x - 6.0, torso_top + 26.0, 150.0 * reach + 20.0, 12.0)
	draw_rect(_faced(arm, f), SKIN_TONE)
	draw_rect(_faced(sword, f), STEEL)


static func _faced(rect: Rect2, facing: float) -> Rect2:
	if facing < 0.0:
		rect.position.x = -rect.position.x - rect.size.x
	return rect
