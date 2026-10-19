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
## Ticks the other way must be held before the fighter turns around. A quick tap, as in
## a motion input, does not turn it, so a motion read relative to the facing holds up.
@export var turn_ticks: int = 4
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
## Pixels per tick of the run that follows while the dodge button is held (issue #80, spike).
@export var run_speed: float = 12.0

## How long the mana bar shows that a spell fell back, in ticks.
const MANA_SHORT_TICKS: int = 24

@export_group("Mana")
## The mana bar (issue #60): hits pay, spells cost. 0 means no bar: every move is free, as for a dummy or a test.
@export var max_mana: int = 0

@export_group("Guard")
## The guard bar (issue #72): a blocked hit drains it by its damage, hits landed refill it, and
## at zero the guard breaks. 0 means no bar: the guard never breaks, as for a dummy or a test.
@export var max_guard: int = 0
## Guard a hit landed pays back.
@export var guard_per_hit: int = 15
## Ticks without taking or blocking a hit before the bar trickles back, by `guard_regen` every
## `guard_regen_every` ticks.
@export var guard_regen_delay: int = 60
@export var guard_regen: int = 1
@export var guard_regen_every: int = 4
## Below this the guard can't be raised: a broken guard has to come back first.
@export var guard_floor: int = 25
## The upward speed the breaking hit gives the fighter when it has no launch of its own.
@export var break_launch: float = 22.0
## A tank's guard taunts (issue #72, Ben): while held, the crowd nearby fights this fighter and comes to its lane.
@export var taunts: bool = false
## Share of a blocked hit's knockback that pushes the blocker back.
@export var block_pushback: float = 0.6
## Share of a blocked hit's hitstop that both fighters freeze for (at least 2 ticks).
@export var block_hitstop: float = 0.5

var input: PlayerInput
var projectiles: Projectiles
## Tried in order, so put moves with a motion before plain button moves.
var moves: Array[Move] = []

var mana: int = 0
var guard: int = 0
## Ticks left showing that a spell fell back to its light version for want of mana (issue #60).
var mana_short_ticks: int = 0

var _blockstun: int = 0  # ticks left held in the guard by a blocked hit
var _quiet_ticks: int = 0  # ticks since the fighter last took or blocked a hit
var _turning: int = 0  # ticks the other way has been held
## The way the current dodge goes: 1 right, -1 left; and whether it was the neutral step back.
var dodge_direction: int = 1
var _dodge_back: bool = false


func setup(player_input: PlayerInput, lanes: PackedFloat32Array, start_lane: int, start_x: float) -> void:
	input = player_input
	place_on(lanes, start_lane, start_x)
	mana = max_mana
	guard = max_guard


## A clean hit pays mana and guard back.
func on_hit_landed(hit: HitBox) -> void:
	gain_mana(hit.mana)
	gain_guard(guard_per_hit)


func gain_mana(amount: int) -> void:
	mana = clampi(mana + amount, 0, max_mana)


func gain_guard(amount: int) -> void:
	guard = clampi(guard + amount, 0, max_guard)


## Whether the guard can be raised: with a bar, only from the floor up.
func can_guard() -> bool:
	return max_guard == 0 or guard >= guard_floor


## Reads the input first: a frozen fighter still records it. The guard bar
## trickles back after a quiet moment, frozen or not.
func tick() -> void:
	input.tick()
	_quiet_ticks += 1
	mana_short_ticks = maxi(mana_short_ticks - 1, 0)
	if max_guard > 0 and _quiet_ticks > guard_regen_delay and _quiet_ticks % guard_regen_every == 0:
		gain_guard(guard_regen)
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


## In the invincible ticks of a dodge, or of a move that has some (a rising uppercut's start-up).
func is_invincible() -> bool:
	if is_attacking() and move_frame >= move.invincible_from and move_frame <= move.invincible_to:
		return true
	return state == State.DODGE and state_ticks >= dodge_invincible_from and state_ticks <= dodge_invincible_to


## Whether a hit pushing in `direction` is stopped by the guard: the fighter is
## blocking and faces the hit. Hits from behind are never blocked.
func blocks(direction: int) -> bool:
	return state == State.BLOCK and facing == -direction


func taunting() -> bool:
	return taunts and state == State.BLOCK


## A guarded hit is stopped while the bar can take its damage; the one that would empty it breaks through.
func blocks_hit(hit: HitBox, direction: int) -> bool:
	return blocks(direction) and not hit.breaks_guard and not hit.grab and (max_guard == 0 or guard > hit.damage)


## Called by Combat for a hit the guard stopped: no damage, blockstun and a push instead; the bar pays.
func take_block(hit: HitBox, direction: int) -> void:
	_quiet_ticks = 0
	if max_guard > 0:
		guard -= hit.damage
	hitstop = blocked_hitstop(hit)
	_blockstun = maxi(_blockstun, hit.blockstun)
	_knock_speed = direction * hit.knockback * block_pushback
	state_ticks = 0


## A hit on a raised guard that the bar can't take is the break (issue #72): the
## bar empties and the hit lands in full, as a launcher.
func take_hit(hit: HitBox, direction: int) -> void:
	_quiet_ticks = 0
	if state == State.BLOCK and max_guard > 0 and facing == -direction and not hit.grab:
		guard = 0
		just_broke = true
		var breaking: HitBox = hit.duplicate()
		breaking.launch = maxf(hit.launch, break_launch)
		super(breaking, direction)
		return
	super(hit, direction)


## The freeze a blocked hit gives both fighters: shorter than a clean hit's.
func blocked_hitstop(hit: HitBox) -> int:
	return maxi(2, int(hit.hitstop * block_hitstop))


func _tick_standing() -> void:
	var direction: int = int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT))
	if direction != 0 and direction != facing:
		_turning += 1
		if _turning >= turn_ticks:
			facing = direction
	else:
		_turning = 0
	if _try_dodge():
		return
	if input.held(Buttons.GUARD) and can_guard():
		_blockstun = 0
		_knock_speed = 0.0
		_enter(State.BLOCK)
		return
	if _try_moves(false):
		return
	if input.pressed(Buttons.LANE_UP) and lane > 0:
		input.consume(Buttons.LANE_UP)
		start_lane_change(lane - 1)
	elif input.pressed(Buttons.LANE_DOWN) and lane < lane_y.size() - 1:
		input.consume(Buttons.LANE_DOWN)
		start_lane_change(lane + 1)
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
	# A landed hit frees you (issue #80, spike): once the swing has connected, anything can
	# follow. A whiff keeps to the move's own cancel windows.
	var free: bool = not swing_targets.is_empty()
	if _try_moves(false, free):
		return
	if _wants_jump() and (free or move.can_cancel_into_id(Move.JUMP, move_frame, not swing_targets.is_empty())):
		move = null
		_start_jump(int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT)))
		return
	if free:
		if _try_dodge():
			move = null
			return
		if input.pressed(Buttons.LANE_UP) and lane > 0:
			input.consume(Buttons.LANE_UP)
			move = null
			start_lane_change(lane - 1)
			return
		if input.pressed(Buttons.LANE_DOWN) and lane < lane_y.size() - 1:
			input.consume(Buttons.LANE_DOWN)
			move = null
			start_lane_change(lane + 1)
			return
		if int(input.held(Buttons.RIGHT)) - int(input.held(Buttons.LEFT)) != 0:
			move = null
			_enter(State.WALK)
			return
	if projectiles != null and move.projectile_frame >= 0:
		# Several projectiles leave one after the other, projectile_interval ticks apart.
		for i in maxi(move.projectile_count, 1):
			if move_frame == move.projectile_frame + i * move.projectile_interval:
				var offset: Vector2 = move.projectile_offset * depth_scale
				offset.x *= facing
				projectiles.spawn_from(move, position + offset, lane, team, facing, depth_scale, i, self)
	if move.rise > 0.0 and move_frame == move.rise_frame:
		vertical_speed = move.rise
		_air_speed = facing * move.rise_forward
	if height > 0.0 or vertical_speed > 0.0:
		_fall()  # a rising move follows its arc; landing just carries on with the move's recovery
	else:
		x = clampf(x + facing * move.travel_speed(move_frame), bounds.x, bounds.y)
	move_frame += 1
	if move_frame >= move.total_frames:
		move = null
		# A rising move that is still in the air when it ends falls as a jump.
		_enter(State.JUMP if height > 0.0 else State.IDLE)


## Whether any hitbox of the current move is out on this frame.
func _boxes_active() -> bool:
	for box in move.hit_boxes:
		if box.active_on(move_frame):
			return true
	return false


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
	_dodge_back = direction == 0
	_knock_speed = 0.0
	_enter(State.DODGE)
	Sounds.play(&"dash")
	return true


## The dash: invincible at the start, then a run for as long as the button is
## held (issue #80, spike), with a running attack on light or heavy; letting go
## slides to a stop. The neutral step back never runs.
func _tick_dodge() -> void:
	if _try_moves(false, false, true):
		return
	if state_ticks <= dodge_invincible_to:
		x = clampf(x + dodge_direction * dodge_speed, bounds.x, bounds.y)
	elif input.held(Buttons.DODGE) and not _dodge_back:
		facing = dodge_direction
		x = clampf(x + dodge_direction * run_speed, bounds.x, bounds.y)
		return
	else:
		# The recovery: a quick slide to a stop.
		var left: float = clampf(float(dodge_ticks - state_ticks) / maxf(dodge_ticks - dodge_invincible_to, 1.0), 0.0, 1.0)
		x = clampf(x + dodge_direction * dodge_speed * 0.5 * left, bounds.x, bounds.y)
	if state_ticks >= dodge_ticks:
		_enter(State.IDLE)


## Starts `candidate` by name rather than by a press (a boss's brain, a test),
## under the same rules: the cancel windows unless a landed hit frees the
## fighter, the mana bar, the fall-backs. False when it can't start now.
func start_move(candidate: Move) -> bool:
	if candidate == null or candidate.air or is_jumping():
		return false
	if state != State.IDLE and state != State.WALK and state != State.ATTACK and state != State.CROUCH:
		return false
	var free: bool = state == State.ATTACK and not swing_targets.is_empty()
	if not _can_start(candidate, free):
		return false
	var chosen: Move = _affordable(candidate, free)
	if chosen == null:
		return false
	mana -= chosen.mana_cost
	move = chosen
	move_frame = 0
	start_swing()
	_enter(State.ATTACK)
	Sounds.play(&"fireball" if chosen.projectile_frame >= 0 else &"swing")
	return true


## In the wind-up of a telegraphed move (issue #67), before its first hit frame: the tell.
func telegraphing() -> bool:
	if not is_attacking() or not move.telegraphed or move.hit_boxes.is_empty():
		return move != null and move.telegraphed and is_attacking() and move.projectile_frame >= 0 and move_frame < move.projectile_frame
	return move_frame < move.hit_boxes[0].first_frame


## `candidate`, or the move it falls back to when the bar can't pay for it (a
## heavy spell's light version, and the super's heavy fireball, then its light),
## or null when nothing affordable can start now.
func _affordable(candidate: Move, free: bool = false) -> Move:
	var chosen: Move = candidate
	while max_mana > 0 and chosen.mana_cost > mana:
		chosen = _move_by_id(chosen.fallback)
		if chosen == null or chosen.air != candidate.air or not _can_start(chosen, free):
			return null
	return chosen


func move_by_id(id: StringName) -> Move:
	return _move_by_id(id)


func _move_by_id(id: StringName) -> Move:
	if id.is_empty():
		return null
	for candidate in moves:
		if candidate.id == id:
			return candidate
	return null


## Starts the first move whose input is there, among air moves or ground moves,
## or running attacks during a dash. During a move, only the moves its cancel
## windows allow right now can start, unless `free` (a landed hit, issue #80).
func _try_moves(in_air: bool, free: bool = false, dashing: bool = false) -> bool:
	for candidate in moves:
		if candidate.air != in_air or candidate.from_dash != dashing or not _can_start(candidate, free):
			continue
		if input.pressed(candidate.button) and CommandReader.matches(input, candidate.motion, facing, candidate.motion_window):
			var chosen: Move = _affordable(candidate, free)
			if chosen == null:
				continue  # can't pay and nothing to fall back on: a move further down the list may answer the same press
			input.consume(candidate.button)
			mana -= chosen.mana_cost
			if chosen != candidate:
				mana_short_ticks = MANA_SHORT_TICKS
			move = chosen
			move_frame = 0
			start_swing()
			_enter(State.AIR_ATTACK if in_air else State.ATTACK)
			Sounds.play(&"fireball" if chosen.projectile_frame >= 0 else &"swing")
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


func _can_start(candidate: Move, free: bool = false) -> bool:
	if move == null:
		return not candidate.follow_up
	if free:
		return true
	return move.can_cancel_into(candidate, move_frame, not swing_targets.is_empty())
