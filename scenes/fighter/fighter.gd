class_name Fighter
extends Node2D
## A fighter's body: where it is, what state it is in, and which move it is
## playing. Driven one tick at a time by whoever owns the clock. It reads a
## PlayerInput and never a device, so an AI or a replay can drive it too.
##
## Position is x, a lane, and a height above the ground (docs/architecture.md,
## section 2, still proposed).

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, LANE_CHANGE, HITSTUN, LAUNCHED, KNOCKDOWN, GETUP, AIR_ATTACK, BLOCK }

const STATE_NAMES: Array[String] = [
	"idle", "walk", "crouch", "jump", "attack", "lane change", "hitstun", "launched", "knockdown", "getup", "air attack", "block",
]

# Tuning, in pixels and ticks. Starting points to tune by playing.
@export var walk_speed: float = 7.0
@export var jump_speed: float = 30.0
@export var gravity: float = 1.9
@export var lane_change_ticks: int = 10
## How high the hop between two lanes goes, in pixels.
@export var lane_hop: float = 40.0
## A hit only lands on a fighter of another team.
@export var team: int = 1

@export_group("Getting hit")
## Where the fighter can be hit, relative to the feet. Up is negative y.
@export var hurt_box: Rect2 = Rect2(-55.0, -260.0, 110.0, 260.0)
@export var crouch_hurt_box: Rect2 = Rect2(-55.0, -160.0, 110.0, 160.0)
## Share of the knockback speed kept each tick on the ground.
@export var knockback_friction: float = 0.85
## Upward speed when a hit with no launch lands on a fighter in the air.
@export var air_hit_pop: float = 14.0
## How much heavier the fighter falls for each hit of a juggle: 0.25 is a quarter more gravity per hit.
@export var juggle_gravity_growth: float = 0.25
@export var knockdown_ticks: int = 40
## Share of a blocked hit's knockback that pushes the blocker back.
@export var block_pushback: float = 0.6
## Share of a blocked hit's hitstop that both fighters freeze for (at least 2 ticks).
@export var block_hitstop: float = 0.5
@export var getup_ticks: int = 20

var input: PlayerInput
var projectiles: Projectiles
## Tried in order, so put moves with a motion before plain button moves.
var moves: Array[Move] = []
var lane_y: PackedFloat32Array = PackedFloat32Array()  # screen y of each lane, back to front
## How large each lane draws its fighters: smaller further back, for depth. 1 is full size.
var lane_scale: PackedFloat32Array = PackedFloat32Array()
## The fighter's size now, between two lanes' scales during a lane change.
var depth_scale: float = 1.0
var bounds: Vector2 = Vector2(0.0, 1920.0)  # x range the fighter stays in

var state: State = State.IDLE
## The state before this one, so the view can show how the fighter got here (a landing, for example).
var previous_state: State = State.IDLE
var x: float = 0.0
var lane: int = 0
var height: float = 0.0
var facing: int = 1  # 1 right, -1 left
var move: Move
var move_frame: int = 0
## Ticks spent in the current state, for the skin's animation.
var state_ticks: int = 0
var vertical_speed: float = 0.0

## Ticks left frozen by a hit, given or taken. A frozen fighter still records its input.
var hitstop: int = 0
## Ticks left drawn white after taking a hit.
var flash_ticks: int = 0
## Hits and damage taken in the current combo, or in the last one once it is over.
var combo_hits: int = 0
var combo_damage: int = 0
## Hits taken in the air since the launch, not counting the launch itself.
var juggle_hits: int = 0
## Who the current move has already hit, and whether it has frozen its user: a
## move hits each target once and freezes its user once. Kept by Combat.
var swing_targets: Array[Fighter] = []
var swing_froze: bool = false

var _stun_ticks: int = 0
var _blockstun: int = 0  # ticks left held in the guard by a blocked hit
var _knock_speed: float = 0.0
var _air_speed: float = 0.0
var _ground_y: float = 0.0
var _lane_from_y: float = 0.0
var _scale_from: float = 1.0


func setup(player_input: PlayerInput, lanes: PackedFloat32Array, start_lane: int, start_x: float) -> void:
	input = player_input
	lane_y = lanes
	lane = start_lane
	x = start_x
	set_lanes(lanes)


## Sets the lanes' screen y and, optionally, how large each lane draws its
## fighters (full size when left out). A fighter standing in a lane moves and
## resizes with it; one changing lane keeps heading for its new lane.
func set_lanes(lanes: PackedFloat32Array, scales: PackedFloat32Array = PackedFloat32Array()) -> void:
	lane_y = lanes
	lane_scale = scales
	if lane_scale.size() != lane_y.size():
		lane_scale.resize(lane_y.size())
		lane_scale.fill(1.0)
	if state != State.LANE_CHANGE:
		_ground_y = lane_y[lane]
		depth_scale = lane_scale[lane]
		_place()


func tick() -> void:
	input.tick()
	flash_ticks = maxi(flash_ticks - 1, 0)
	if hitstop > 0:
		hitstop -= 1
		input.hold_presses()
		return
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
		State.HITSTUN:
			_tick_hitstun()
		State.LAUNCHED:
			_tick_launched()
		State.KNOCKDOWN:
			if state_ticks >= knockdown_ticks:
				_enter(State.GETUP)
		State.GETUP:
			if state_ticks >= getup_ticks:
				_enter(State.IDLE)
		State.AIR_ATTACK:
			_tick_air_attack()
		State.BLOCK:
			_tick_block()
	_place()


## Playing a move, on the ground or in the air.
func is_attacking() -> bool:
	return state == State.ATTACK or state == State.AIR_ATTACK


## Off the ground under its own power: jumping, with or without an air move.
func is_jumping() -> bool:
	return state == State.JUMP or state == State.AIR_ATTACK


## A box of the current move in screen space.
func hit_rect(box: HitBox) -> Rect2:
	return _faced(box.rect)


## Where the fighter can be hit this tick, in screen space.
func hurt_rect() -> Rect2:
	return _faced(crouch_hurt_box if state == State.CROUCH else hurt_box)


## A fighter on the floor or getting up can't be hit.
func can_be_hit() -> bool:
	return state != State.KNOCKDOWN and state != State.GETUP


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


## Still reeling from a hit, so the next hit continues the combo.
func in_hit_reaction() -> bool:
	return state == State.HITSTUN or state == State.LAUNCHED


## Called by Combat when a hit lands. `direction` is the way the hit pushes: 1 right, -1 left.
func take_hit(hit: HitBox, direction: int) -> void:
	if not in_hit_reaction():
		combo_hits = 0
		combo_damage = 0
	combo_hits += 1
	combo_damage += hit.damage
	hitstop = hit.hitstop
	flash_ticks = hit.hitstop + 2
	facing = -direction
	move = null
	if state == State.LANE_CHANGE:
		# A hit ends a lane change on the lane it was heading for.
		_ground_y = lane_y[lane]
		depth_scale = lane_scale[lane]
		height = 0.0
	if hit.launch > 0.0 or is_jumping() or state == State.LAUNCHED:
		if state == State.LAUNCHED:
			juggle_hits += 1
		vertical_speed = hit.launch if hit.launch > 0.0 else air_hit_pop
		_air_speed = direction * hit.knockback
		_enter(State.LAUNCHED)
	else:
		_stun_ticks = hit.hitstun
		_knock_speed = direction * hit.knockback
		_enter(State.HITSTUN)
	_place()


## The hitboxes active this tick, in screen space.
func active_hit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not is_attacking():
		return rects
	for box in move.hit_boxes:
		if box.active_on(move_frame):
			rects.append(hit_rect(box))
	return rects


func _tick_standing() -> void:
	var direction: int = int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT))
	if direction != 0:
		facing = direction
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
	if _try_moves(false):
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
	elif not input.held(Buttons.GUARD):
		_enter(State.IDLE)


func _tick_hitstun() -> void:
	x = clampf(x + _knock_speed, bounds.x, bounds.y)
	_knock_speed *= knockback_friction
	if state_ticks >= _stun_ticks:
		_enter(State.IDLE)


func _tick_launched() -> void:
	height += vertical_speed
	# Each hit of a juggle makes the fall heavier, so combos end on their own.
	vertical_speed -= gravity * (1.0 + juggle_gravity_growth * juggle_hits)
	x = clampf(x + _air_speed, bounds.x, bounds.y)
	if height <= 0.0:
		height = 0.0
		vertical_speed = 0.0
		juggle_hits = 0
		_enter(State.KNOCKDOWN)


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


func _enter(new_state: State) -> void:
	previous_state = state
	state = new_state
	state_ticks = 0


func _place() -> void:
	position = Vector2(x, _ground_y - height)
	scale = Vector2(depth_scale, depth_scale)
	z_index = lane  # front lanes draw over back ones


## A box given for a full-size fighter facing right, as it is now in screen space.
func _faced(box: Rect2) -> Rect2:
	if facing < 0:
		box.position.x = -box.position.x - box.size.x
	box.position = box.position * depth_scale + position
	box.size *= depth_scale
	return box
