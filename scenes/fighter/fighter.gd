class_name Fighter
extends Node2D
## A fighter's body: where it is, what state it is in, and which move it is
## playing. Driven one tick at a time by whoever owns the clock. It reads a
## PlayerInput and never a device, so an AI or a replay can drive it too.
##
## Position is x, a lane, and a height above the ground (docs/architecture.md,
## section 2, still proposed).

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, LANE_CHANGE }

const STATE_NAMES: Array[String] = ["idle", "walk", "crouch", "jump", "attack", "lane change"]

# Tuning, in pixels and ticks. Starting points to tune by playing.
@export var walk_speed: float = 7.0
@export var jump_speed: float = 30.0
@export var gravity: float = 1.9
@export var lane_change_ticks: int = 10

var input: PlayerInput
var projectiles: Projectiles
## Tried in order, so put moves with a motion before plain button moves.
var moves: Array[Move] = []
var lane_y: PackedFloat32Array = PackedFloat32Array()  # screen y of each lane, back to front
var bounds: Vector2 = Vector2(0.0, 1920.0)  # x range the fighter stays in

var state: State = State.IDLE
var x: float = 0.0
var lane: int = 0
var height: float = 0.0
var facing: int = 1  # 1 right, -1 left
var move: Move
var move_frame: int = 0
## Ticks spent in the current state, for the skin's animation.
var state_ticks: int = 0
var vertical_speed: float = 0.0

var _air_speed: float = 0.0
var _ground_y: float = 0.0
var _lane_from_y: float = 0.0


func setup(player_input: PlayerInput, lanes: PackedFloat32Array, start_lane: int, start_x: float) -> void:
	input = player_input
	lane_y = lanes
	lane = start_lane
	x = start_x
	_ground_y = lane_y[lane]
	_place()


func tick() -> void:
	input.tick()
	state_ticks += 1
	match state:
		State.IDLE, State.WALK:
			_tick_standing()
		State.CROUCH:
			_tick_crouch()
		State.JUMP:
			_tick_jump()
		State.ATTACK:
			_tick_attack()
		State.LANE_CHANGE:
			_tick_lane_change()
	_place()


## The hitboxes active this tick, in screen space.
func active_hit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if state != State.ATTACK:
		return rects
	for box in move.hit_boxes:
		if box.active_on(move_frame):
			var r: Rect2 = box.rect
			if facing < 0:
				r.position.x = -r.position.x - r.size.x
			r.position += position
			rects.append(r)
	return rects


func _tick_standing() -> void:
	var direction: int = int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT))
	if direction != 0:
		facing = direction
	if _try_moves():
		return
	if input.pressed(Buttons.LANE_UP) and lane > 0:
		input.consume(Buttons.LANE_UP)
		_start_lane_change(lane - 1)
	elif input.pressed(Buttons.LANE_DOWN) and lane < lane_y.size() - 1:
		input.consume(Buttons.LANE_DOWN)
		_start_lane_change(lane + 1)
	elif input.held(Buttons.UP) or input.pressed(Buttons.JUMP):
		input.consume(Buttons.JUMP)
		vertical_speed = jump_speed
		_air_speed = direction * walk_speed
		_enter(State.JUMP)
	elif input.held(Buttons.DOWN):
		_enter(State.CROUCH)
	elif direction != 0:
		x = clampf(x + direction * walk_speed, bounds.x, bounds.y)
		if state != State.WALK:
			_enter(State.WALK)
	elif state != State.IDLE:
		_enter(State.IDLE)


func _tick_crouch() -> void:
	# A motion such as down, down-forward, forward passes through a crouch,
	# so moves must be able to start from here.
	if _try_moves():
		return
	if not input.held(Buttons.DOWN):
		_enter(State.IDLE)


func _tick_jump() -> void:
	height += vertical_speed
	vertical_speed -= gravity
	x = clampf(x + _air_speed, bounds.x, bounds.y)
	if height <= 0.0:
		height = 0.0
		vertical_speed = 0.0
		_enter(State.IDLE)


func _tick_attack() -> void:
	if move_frame == move.projectile_frame and projectiles != null:
		var offset: Vector2 = move.projectile_offset
		offset.x *= facing
		projectiles.spawn(position + offset, move.projectile_speed * facing)
	move_frame += 1
	if move_frame >= move.total_frames:
		move = null
		_enter(State.IDLE)


func _tick_lane_change() -> void:
	var t: float = float(state_ticks) / lane_change_ticks
	_ground_y = lerpf(_lane_from_y, lane_y[lane], minf(t, 1.0))
	if state_ticks >= lane_change_ticks:
		_enter(State.IDLE)


func _try_moves() -> bool:
	for candidate in moves:
		if input.pressed(candidate.button) and CommandReader.matches(input, candidate.motion, facing):
			input.consume(candidate.button)
			move = candidate
			move_frame = 0
			_enter(State.ATTACK)
			return true
	return false


func _start_lane_change(to_lane: int) -> void:
	_lane_from_y = _ground_y
	lane = to_lane
	_enter(State.LANE_CHANGE)


func _enter(new_state: State) -> void:
	state = new_state
	state_ticks = 0


func _place() -> void:
	position = Vector2(x, _ground_y - height)
