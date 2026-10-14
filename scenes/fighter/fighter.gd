class_name Fighter
extends Body
## A full fighter: a Body with a state machine, a move list, cancels, a jump,
## a guard and a dodge. Driven one tick at a time by whoever owns the clock. It
## reads a PlayerInput and never a device, so an AI or a replay can drive it too.
##
## Position is x, a lane, and a height above the ground (docs/architecture.md,
## section 2, still proposed). Being hit is the Body's business.

# Tuning, in pixels and ticks. Starting points to tune by playing.
@export var walk_speed: float = 7.0
@export var jump_speed: float = 30.0
@export var lane_change_ticks: int = 10
## How high the hop between two lanes goes, in pixels.
@export var lane_hop: float = 40.0
## Where the fighter can be hit while crouching, relative to the feet.
@export var crouch_hurt_box: Rect2 = Rect2(-55.0, -160.0, 110.0, 160.0)

@export_group("Dodge")
## How long a dodge lasts, in ticks. The last ticks after the invincible ones are the recovery.
@export var dodge_ticks: int = 16
## The ticks of the dodge during which nothing can hit the fighter (the first tick is 1).
@export var dodge_invincible_from: int = 2
@export var dodge_invincible_to: int = 11
## Pixels per tick while the invincible part lasts; the recovery slides to a stop.
@export var dodge_speed: float = 18.0

@export_group("Guard")
## Share of a blocked hit's knockback that pushes the blocker back.
@export var block_pushback: float = 0.6
## Share of a blocked hit's hitstop that both fighters freeze for (at least 2 ticks).
@export var block_hitstop: float = 0.5

var input: PlayerInput
var projectiles: Projectiles
## Tried in order, so put moves with a motion before plain button moves.
var moves: Array[Move] = []

var _blockstun: int = 0  # ticks left held in the guard by a blocked hit
## The way the current dodge goes: 1 right, -1 left.
var dodge_direction: int = 1


func setup(player_input: PlayerInput, lanes: PackedFloat32Array, start_lane: int, start_x: float) -> void:
	input = player_input
	place_on(lanes, start_lane, start_x)


## Reads the input first: a frozen fighter still records it.
func tick() -> void:
	input.tick()
	super()


func _tick_frozen() -> void:
	input.hold_presses()


func _tick_state() -> void:
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
		State.AIR_ATTACK:
			_tick_air_attack()
		State.BLOCK:
			_tick_block()
		State.DODGE:
			_tick_dodge()
		_:
			super()


## Playing a move, on the ground or in the air.
func is_attacking() -> bool:
	return (state == State.ATTACK or state == State.AIR_ATTACK) and move != null


## Off the ground under its own power: jumping, with or without an air move.
func is_jumping() -> bool:
	return state == State.JUMP or state == State.AIR_ATTACK


## Where the fighter can be hit this tick, in screen space: shorter while crouching.
func hurt_rect() -> Rect2:
	return _faced(crouch_hurt_box if state == State.CROUCH else hurt_box)


## In the invincible ticks of a dodge.
func is_invincible() -> bool:
	return state == State.DODGE and state_ticks >= dodge_invincible_from and state_ticks <= dodge_invincible_to


## Whether a hit pushing in `direction` is stopped by the guard: the fighter is
## blocking and faces the hit. Hits from behind are never blocked.
func blocks(direction: int) -> bool:
	return state == State.BLOCK and facing == -direction


## Called by Combat for a hit the guard stopped: no damage, blockstun and a push instead.
func take_block(hit: HitBox, direction: int) -> void:
	hitstop = blocked_hitstop(hit)
	_blockstun = maxi(_blockstun, hit.blockstun)
	_knock_speed = direction * hit.knockback * block_pushback
	state_ticks = 0


## The freeze a blocked hit gives both fighters: shorter than a clean hit's.
func blocked_hitstop(hit: HitBox) -> int:
	return maxi(2, int(hit.hitstop * block_hitstop))


## A hit ends a lane change on the lane it was heading for.
func _interrupted() -> void:
	if state == State.LANE_CHANGE:
		_ground_y = lane_y[lane]
		depth_scale = lane_scale[lane]
		height = 0.0


func _tick_standing() -> void:
	var direction: int = int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT))
	if direction != 0:
		facing = direction
	if _try_dodge():
		return
	if input.held(Buttons.GUARD):
		_blockstun = 0
		_knock_speed = 0.0
		_enter(State.BLOCK)
		return
	if _try_moves(false):
		return
	if input.pressed(Buttons.LANE_UP) and lane > 0:
		input.consume(Buttons.LANE_UP)
		_start_lane_change(lane - 1)
	elif input.pressed(Buttons.LANE_DOWN) and lane < lane_y.size() - 1:
		input.consume(Buttons.LANE_DOWN)
		_start_lane_change(lane + 1)
	elif _wants_jump():
		_start_jump(direction)
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
	if _try_dodge() or _try_moves(false):
		return
	if not input.held(Buttons.DOWN):
		_enter(State.IDLE)


func _tick_jump() -> void:
	_try_moves(true)
	if _fall():
		move = null
		_enter(State.IDLE)


## An air move follows the jump's arc. Landing ends it, and if it ends first
## the jump carries on.
func _tick_air_attack() -> void:
	var cancelled: bool = _try_moves(true)
	if _fall():
		move = null
		_enter(State.IDLE)
		return
	if cancelled:
		return
	move_frame += 1
	if move_frame >= move.total_frames:
		move = null
		_enter(State.JUMP)


## One tick of the jump's arc. True on the tick it lands.
func _fall() -> bool:
	height += vertical_speed
	vertical_speed -= gravity
	x = clampf(x + _air_speed, bounds.x, bounds.y)
	if height > 0.0:
		return false
	height = 0.0
	vertical_speed = 0.0
	return true


func _tick_attack() -> void:
	if _try_moves(false):
		return
	if _wants_jump() and move.can_cancel_into_id(Move.JUMP, move_frame, not swing_targets.is_empty()):
		move = null
		_start_jump(int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT)))
		return
	if move_frame == move.projectile_frame and projectiles != null:
		var offset: Vector2 = move.projectile_offset * depth_scale
		offset.x *= facing
		projectiles.spawn(position + offset, move.projectile_speed * facing, lane, team, move.projectile_hit, depth_scale)
	move_frame += 1
	if move_frame >= move.total_frames:
		move = null
		_enter(State.IDLE)


## A hop from one lane to the next: the ground line and the size slide to the
## new lane's while the fighter rises and lands.
func _tick_lane_change() -> void:
	var t: float = minf(float(state_ticks) / lane_change_ticks, 1.0)
	_ground_y = lerpf(_lane_from_y, lane_y[lane], t)
	depth_scale = lerpf(_scale_from, lane_scale[lane], t)
	height = sin(t * PI) * lane_hop
	if state_ticks >= lane_change_ticks:
		height = 0.0
		_enter(State.IDLE)


## Holding the guard. A blocked hit holds the fighter in it for its blockstun
## and slides it back; letting go after that stands the fighter up.
func _tick_block() -> void:
	x = clampf(x + _knock_speed, bounds.x, bounds.y)
	_knock_speed *= knockback_friction
	if _blockstun > 0:
		_blockstun -= 1
	elif _try_dodge():
		return
	elif not input.held(Buttons.GUARD):
		_enter(State.IDLE)


## A dash along the lane: the held direction, or a step back when neutral.
## Invincible in the middle, vulnerable while it slides to a stop.
func _try_dodge() -> bool:
	if not input.pressed(Buttons.DODGE):
		return false
	input.consume(Buttons.DODGE)
	var direction: int = int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT))
	dodge_direction = direction if direction != 0 else -facing
	_knock_speed = 0.0
	_enter(State.DODGE)
	return true


func _tick_dodge() -> void:
	if state_ticks <= dodge_invincible_to:
		x = clampf(x + dodge_direction * dodge_speed, bounds.x, bounds.y)
	else:
		# The recovery: a quick slide to a stop.
		var left: float = float(dodge_ticks - state_ticks) / maxf(dodge_ticks - dodge_invincible_to, 1.0)
		x = clampf(x + dodge_direction * dodge_speed * 0.5 * left, bounds.x, bounds.y)
	if state_ticks >= dodge_ticks:
		_enter(State.IDLE)


## Starts the first move whose input is there, among air moves or ground moves.
## During a move, only the moves its cancel windows allow right now can start.
func _try_moves(in_air: bool) -> bool:
	for candidate in moves:
		if candidate.air != in_air or not _can_start(candidate):
			continue
		if input.pressed(candidate.button) and CommandReader.matches(input, candidate.motion, facing):
			input.consume(candidate.button)
			move = candidate
			move_frame = 0
			swing_targets.clear()
			swing_froze = false
			_enter(State.AIR_ATTACK if in_air else State.ATTACK)
			return true
	return false


func _wants_jump() -> bool:
	return input.held(Buttons.UP) or input.pressed(Buttons.JUMP)


## Leaves the ground. `direction` is the way the jump drifts: -1, 0 or 1.
func _start_jump(direction: int) -> void:
	input.consume(Buttons.JUMP)
	vertical_speed = jump_speed
	_air_speed = direction * walk_speed
	_enter(State.JUMP)


func _can_start(candidate: Move) -> bool:
	if move == null:
		return not candidate.follow_up
	return move.can_cancel_into(candidate, move_frame, not swing_targets.is_empty())


func _start_lane_change(to_lane: int) -> void:
	_lane_from_y = _ground_y
	_scale_from = depth_scale
	lane = to_lane
	_enter(State.LANE_CHANGE)
