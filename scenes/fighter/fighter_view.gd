class_name FighterView
extends Node2D
## Draws a Fighter. With a skin it shows the sheet's frames. Without one it
## draws a plain figure, so the game always runs with no art at all.
## Add it as a child of the Fighter.

const SKIN_TONE := Color(0.9, 0.75, 0.6)
const STEEL := Color(0.8, 0.82, 0.86)

## Turns everything this view draws white, for the flash when a hit lands.
const FLASH_SHADER: String = "shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}"

static var _flash_shader: Shader

var skin: FighterSkin
var show_boxes: bool = false
## The plain figure's colour, to tell fighters apart.
var body_color: Color = Color(0.35, 0.55, 0.85)

@onready var _fighter: Fighter = get_parent()


func _ready() -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER
	var flash := ShaderMaterial.new()
	flash.shader = _flash_shader
	material = flash


func _physics_process(_delta: float) -> void:
	(material as ShaderMaterial).set_shader_parameter(&"flash", 1.0 if _fighter.flash_ticks > 0 else 0.0)
	queue_redraw()


func _draw() -> void:
	if skin != null and skin.has(_animation()):
		_draw_skin()
	else:
		_draw_figure()
	draw_set_transform(Vector2.ZERO)
	if show_boxes:
		draw_circle(Vector2.ZERO, 6.0, Color.YELLOW)
		if _fighter.can_be_hit():
			var hurt: Rect2 = _fighter.hurt_rect()
			hurt.position -= _fighter.position
			draw_rect(hurt, Color(0.2, 0.5, 1.0), false, 3.0)
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
		Fighter.State.ATTACK, Fighter.State.AIR_ATTACK:
			return _fighter.move.animation
		Fighter.State.HITSTUN:
			return &"hurt"
		Fighter.State.LAUNCHED:
			return &"launched"
		Fighter.State.KNOCKDOWN:
			return &"knockdown"
		Fighter.State.GETUP:
			return &"getup"
	if _is_landing():
		return &"land"
	return &"idle"


## Just back on the ground after a jump, and still standing there. This is only
## a look: the fighter is already idle and can act at once, which ends it.
func _is_landing() -> bool:
	return (
		_fighter.state == Fighter.State.IDLE
		and _fighter.previous_state in [Fighter.State.JUMP, Fighter.State.AIR_ATTACK]
		and skin != null and skin.has(&"land")
		and _fighter.state_ticks < skin.duration(&"land")
	)


func _draw_skin() -> void:
	var progress: float = -1.0
	if _fighter.is_attacking():
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
	var airborne: bool = _fighter.is_jumping()
	var leg: float = 60.0 if crouched or airborne else 130.0
	_tilt_figure()
	var torso_top: float = -leg - 100.0
	var stride: float = sin(_fighter.state_ticks * 0.35) * 22.0 if state in [Fighter.State.WALK, Fighter.State.LANE_CHANGE] else 0.0
	# legs
	draw_rect(Rect2(-34.0 + stride, -leg, 28.0, leg), body_color.darkened(0.35))
	draw_rect(Rect2(6.0 - stride, -leg, 28.0, leg), body_color.darkened(0.35))
	# torso and head
	draw_rect(Rect2(-40.0, torso_top, 80.0, 100.0), body_color)
	draw_rect(Rect2(-24.0, torso_top - 50.0, 48.0, 48.0), SKIN_TONE)
	draw_rect(_faced(Rect2(20.0, torso_top - 34.0, 12.0, 10.0), f), SKIN_TONE.darkened(0.2))  # nose
	# arm and sword
	var arm := Rect2(10.0, torso_top + 24.0, 50.0, 18.0)
	var sword := Rect2(50.0, torso_top - 40.0, 10.0, 80.0)
	if _fighter.is_attacking():
		var t: float = float(_fighter.move_frame) / _fighter.move.total_frames
		var reach: float = sin(t * PI)
		arm = Rect2(10.0, torso_top + 24.0, 50.0 + 60.0 * reach, 18.0)
		if _fighter.move.projectile_frame >= 0:
			sword = Rect2(arm.end.x - 8.0, torso_top - 10.0, 10.0, 90.0)
		else:
			sword = Rect2(arm.end.x - 6.0, torso_top + 26.0, 150.0 * reach + 20.0, 12.0)
	draw_rect(_faced(arm, f), SKIN_TONE)
	draw_rect(_faced(sword, f), STEEL)


## Leans the plain figure back when it is hit, and lays it down when it falls.
## A hit turns the fighter to face it, so "back" is away from `facing`.
func _tilt_figure() -> void:
	var back: float = -_fighter.facing
	var ticks: float = _fighter.state_ticks
	match _fighter.state:
		Fighter.State.HITSTUN:
			draw_set_transform(Vector2.ZERO, back * 0.3)
		Fighter.State.LAUNCHED:
			draw_set_transform(Vector2.ZERO, back * minf(0.3 + ticks * 0.08, 1.4))
		Fighter.State.KNOCKDOWN:
			draw_set_transform(Vector2(0.0, -40.0), back * PI / 2.0)
		Fighter.State.GETUP:
			var left: float = 1.0 - ticks / _fighter.getup_ticks
			draw_set_transform(Vector2(0.0, -40.0 * left), back * PI / 2.0 * left)


static func _faced(rect: Rect2, facing: float) -> Rect2:
	if facing < 0.0:
		rect.position.x = -rect.position.x - rect.size.x
	return rect
