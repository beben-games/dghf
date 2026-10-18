class_name CrowdBody
extends Body
## A small-fry enemy: the crowd body of docs/architecture.md, section 4. A Body
## with one simple attack and no input buffer or move list. The director tells
## it what to do (walk, wait, attack); it only knows how. Pooled: a dead one is
## reset and reused, never freed. It draws itself: a small figure, the flash
## shader and a shadow, like the fighter's view.

const SKIN_TONE := Color(0.88, 0.72, 0.58)

@export var walk_speed: float = 4.0
## The one attack, as move data like a fighter's.
@export var attack: Move
## The plain figure's colour.
@export var body_color: Color = Color(0.55, 0.42, 0.3)

## Set by the director each think: where to walk (0 to stand), and whether to swing.
var wanted_direction: int = 0
var wants_attack: bool = false
## True while the director has handed it an attack token.
var has_token: bool = false
## Ticks until this body may attack again, set by the director after a swing.
var rest: int = 0
## Which think turn this body is on: it thinks when the director's tick matches.
var think_slot: int = 0
## The side of the target this body tries to stand on: 1 for its right, -1 for its left, 0 not chosen yet.
var side: int = 0
## Walking through to the other side of the target: others don't push it while it crosses.
var crossing: bool = false
## Ticks the target has been in another lane, counted by the director.
var off_lane_ticks: int = 0
## The player this body fights, picked by the director among its targets (issue #59). Null until it thinks.
var target: Body

static var _flash_shader: Shader
var _shade: float = 1.0


func _ready() -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FighterView.FLASH_SHADER
	var flash := ShaderMaterial.new()
	flash.shader = _flash_shader
	material = flash


## Brings a pooled body back to life on a lane.
func revive(lanes: PackedFloat32Array, scales: PackedFloat32Array, start_lane: int, start_x: float, face: int) -> void:
	state = State.IDLE
	previous_state = State.IDLE
	state_ticks = 0
	height = 0.0
	vertical_speed = 0.0
	hitstop = 0
	flash_ticks = 0
	juggle_hits = 0
	combo_hits = 0
	combo_damage = 0
	move = null
	rest = 0
	has_token = false
	wants_attack = false
	wanted_direction = 0
	off_lane_ticks = 0
	side = 0
	crossing = false
	target = null
	facing = face
	place_on(lanes, start_lane, start_x)
	set_lanes(lanes, scales)
	visible = true


## Dead and finished lying there: the director can take it back.
func is_done() -> bool:
	return state == State.DEAD and state_ticks >= knockdown_ticks


func _tick_state() -> void:
	rest = maxi(rest - 1, 0)
	match state:
		State.IDLE, State.WALK:
			if wants_attack and attack != null:
				wants_attack = false
				move = attack
				move_frame = 0
				start_swing()
				_enter(State.ATTACK)
			elif wanted_direction != 0:
				facing = wanted_direction
				x = clampf(x + wanted_direction * walk_speed, bounds.x, bounds.y)
				if state != State.WALK:
					_enter(State.WALK)
			elif state != State.IDLE:
				_enter(State.IDLE)
		State.ATTACK:
			move_frame += 1
			if move_frame >= move.total_frames:
				move = null
				_enter(State.IDLE)
		_:
			super()


func _physics_process(_delta: float) -> void:
	(material as ShaderMaterial).set_shader_parameter(&"flash", 1.0 if flash_ticks > 0 else 0.0)
	queue_redraw()


## Darkens the figure, for back lanes. 1 is unchanged.
func set_shade(shade: float) -> void:
	_shade = shade
	modulate = Color(shade, shade, shade)


## The plain figure: about 190 pixels tall, a hood and a club. The wind-up of
## the attack leans back, the swing leans in.
func _draw() -> void:
	var shrink: float = clampf(1.0 - height / 900.0, 0.5, 1.0)
	draw_set_transform(Vector2(0.0, height), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 50.0 * shrink, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var f: float = facing
	var back: float = -f
	var lean: float = 0.0
	match state:
		State.ATTACK:
			var t: float = float(move_frame) / move.total_frames
			lean = f * (-0.25 if t < 0.45 else 0.3)
		State.HITSTUN:
			lean = back * 0.3
		State.LAUNCHED:
			lean = back * minf(0.3 + state_ticks * 0.08, 1.4)
		State.KNOCKDOWN, State.DEAD:
			draw_set_transform(Vector2(0.0, -30.0), back * PI / 2.0)
		State.GETUP:
			var left: float = 1.0 - float(state_ticks) / getup_ticks
			draw_set_transform(Vector2(0.0, -30.0 * left), back * PI / 2.0 * left)
	if lean != 0.0:
		draw_set_transform(Vector2.ZERO, lean)
	var dark: Color = body_color.darkened(0.35)
	var stride: float = sin(state_ticks * 0.4) * 14.0 if state == State.WALK else 0.0
	draw_rect(Rect2(-24.0 + stride, -90.0, 20.0, 90.0), dark)
	draw_rect(Rect2(4.0 - stride, -90.0, 20.0, 90.0), dark)
	draw_rect(Rect2(-30.0, -165.0, 60.0, 78.0), body_color)
	draw_rect(Rect2(-20.0, -200.0, 40.0, 38.0), SKIN_TONE)
	draw_rect(Rect2(-24.0, -206.0, 48.0, 14.0), dark)  # hood
	var club := Rect2(26.0, -150.0, 60.0, 12.0)
	if state == State.ATTACK:
		var t: float = float(move_frame) / move.total_frames
		club = Rect2(26.0, -150.0, 60.0 + 70.0 * sin(t * PI), 12.0)
	if f < 0.0:
		club.position.x = -club.position.x - club.size.x
	draw_rect(club, dark.lightened(0.2))
	draw_set_transform(Vector2.ZERO)
	if state == State.DEAD:
		modulate.a = clampf(1.0 - float(state_ticks - knockdown_ticks / 2) / (knockdown_ticks / 2.0), 0.0, 1.0) * 1.0
