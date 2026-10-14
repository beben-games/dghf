class_name Body
extends Node2D
## What every body in a fight shares: where it is (x, a lane, a height), its
## size by lane, its team and health, and how it takes a hit. Full fighters and
## crowd enemies both extend it, so one set of hit rules serves both
## (docs/architecture.md, section 4). Driven one tick at a time by whoever
## owns the clock.

enum State {
	IDLE, WALK, CROUCH, JUMP, ATTACK, LANE_CHANGE, HITSTUN, LAUNCHED, KNOCKDOWN, GETUP, AIR_ATTACK, BLOCK, DODGE, DEAD,
}

const STATE_NAMES: Array[String] = [
	"idle", "walk", "crouch", "jump", "attack", "lane change", "hitstun", "launched", "knockdown", "getup",
	"air attack", "block", "dodge", "dead",
]

## A hit only lands on a body of another team.
@export var team: int = 1
## Health at the start, and the most a body can have. 0 means it can't die.
@export var max_health: int = 0
@export var gravity: float = 1.9
@export var lane_change_ticks: int = 10
## How high the hop between two lanes goes, in pixels.
@export var lane_hop: float = 40.0

@export_group("Getting hit")
## Where the body can be hit, relative to the feet. Up is negative y.
@export var hurt_box: Rect2 = Rect2(-55.0, -260.0, 110.0, 260.0)
## Share of the knockback speed kept each tick on the ground.
@export var knockback_friction: float = 0.85
## Upward speed when a hit with no launch lands on a body in the air.
@export var air_hit_pop: float = 14.0
## How much heavier the body falls for each hit of a juggle: 0.25 is a quarter more gravity per hit.
@export var juggle_gravity_growth: float = 0.25
@export var knockdown_ticks: int = 40
@export var getup_ticks: int = 20
## The push a killing blow gives, so a body that dies flies a little.
@export var death_launch: float = 14.0

var lane_y: PackedFloat32Array = PackedFloat32Array()  # screen y of each lane, back to front
## How large each lane draws its bodies: smaller further back, for depth. 1 is full size.
var lane_scale: PackedFloat32Array = PackedFloat32Array()
## The body's size now, between two lanes' scales during a lane change.
var depth_scale: float = 1.0
var bounds: Vector2 = Vector2(0.0, 1920.0)  # x range the body stays in

var state: State = State.IDLE
## The state before this one, so a view can show how the body got here.
var previous_state: State = State.IDLE
var x: float = 0.0
var lane: int = 0
var height: float = 0.0
var facing: int = 1  # 1 right, -1 left
var health: int = 0
## The move being played, if any, and its frame. Combat reads the hitboxes from here.
var move: Move
var move_frame: int = 0
## Ticks spent in the current state, for animation.
var state_ticks: int = 0
var vertical_speed: float = 0.0

## Ticks left frozen by a hit, given or taken.
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
var swing_targets: Array[Body] = []
var swing_froze: bool = false

var _stun_ticks: int = 0
var _knock_speed: float = 0.0
var _air_speed: float = 0.0
var _ground_y: float = 0.0
var _lane_from_y: float = 0.0
var _scale_from: float = 1.0


## Puts the body on a lane at an x. Subclasses add what drives them.
func place_on(lanes: PackedFloat32Array, start_lane: int, start_x: float) -> void:
	lane_y = lanes
	lane = start_lane
	x = start_x
	health = max_health
	set_lanes(lanes)


## Sets the lanes' screen y and, optionally, how large each lane draws its
## bodies (full size when left out). A body standing in a lane moves and
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
	flash_ticks = maxi(flash_ticks - 1, 0)
	if hitstop > 0:
		hitstop -= 1
		_tick_frozen()
		return
	state_ticks += 1
	_tick_state()
	_place()


## What a subclass does on a tick spent frozen (a fighter keeps its input buffer).
func _tick_frozen() -> void:
	pass


## One tick of the current state. Subclasses handle their own states and call
## this for the ones every body shares.
func _tick_state() -> void:
	match state:
		State.LANE_CHANGE:
			_tick_lane_change()
		State.HITSTUN:
			_tick_hitstun()
		State.LAUNCHED:
			_tick_launched()
		State.KNOCKDOWN:
			if state_ticks >= knockdown_ticks:
				_enter(State.DEAD if is_dying() else State.GETUP)
		State.GETUP:
			if state_ticks >= getup_ticks:
				_enter(State.IDLE)
		State.DEAD:
			pass


## Playing a move. Combat checks the move's boxes against other bodies.
func is_attacking() -> bool:
	return state == State.ATTACK and move != null


## Off the ground under its own power. Launched bodies are airborne but not jumping.
func is_jumping() -> bool:
	return false


## Out of health: it falls on the next knockdown and stays down.
func is_dying() -> bool:
	return max_health > 0 and health <= 0


## A box of the current move in screen space.
func hit_rect(box: HitBox) -> Rect2:
	return _faced(box.rect)


## Where the body can be hit this tick, in screen space.
func hurt_rect() -> Rect2:
	return _faced(hurt_box)


## A body on the floor, getting up, dead, or otherwise untouchable can't be hit.
func can_be_hit() -> bool:
	return state != State.KNOCKDOWN and state != State.GETUP and state != State.DEAD and not is_invincible()


func is_invincible() -> bool:
	return false


## Whether a hit pushing in `direction` is stopped by a guard. Bodies that can't guard never block.
func blocks(_direction: int) -> bool:
	return false


## Called by Combat for a hit a guard stopped. Only bodies that block get this.
func take_block(_hit: HitBox, _direction: int) -> void:
	pass


## The freeze a blocked hit gives both bodies.
func blocked_hitstop(hit: HitBox) -> int:
	return maxi(2, int(hit.hitstop * 0.5))


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
	if max_health > 0:
		health = maxi(health - hit.damage, 0)
	hitstop = hit.hitstop
	flash_ticks = hit.hitstop + 2
	facing = -direction
	_interrupted()
	move = null
	var launch: float = hit.launch
	if is_dying() and launch <= 0.0 and not in_hit_reaction() and not is_jumping():
		launch = death_launch  # the killing blow sends the body flying
	if launch > 0.0 or is_jumping() or state == State.LAUNCHED:
		if state == State.LAUNCHED:
			juggle_hits += 1
		vertical_speed = launch if launch > 0.0 else air_hit_pop
		_air_speed = direction * hit.knockback
		_enter(State.LAUNCHED)
	else:
		_stun_ticks = hit.hitstun
		_knock_speed = direction * hit.knockback
		_enter(State.HITSTUN)
	_place()


## What a subclass drops when a hit lands. A hit ends a lane change on the lane it was heading for.
func _interrupted() -> void:
	if state == State.LANE_CHANGE:
		_ground_y = lane_y[lane]
		depth_scale = lane_scale[lane]
		height = 0.0


## Hops to `to_lane`: the ground line and the size slide to the new lane's
## while the body rises and lands.
func start_lane_change(to_lane: int) -> void:
	_lane_from_y = _ground_y
	_scale_from = depth_scale
	lane = to_lane
	_enter(State.LANE_CHANGE)


func _tick_lane_change() -> void:
	var t: float = minf(float(state_ticks) / lane_change_ticks, 1.0)
	_ground_y = lerpf(_lane_from_y, lane_y[lane], t)
	depth_scale = lerpf(_scale_from, lane_scale[lane], t)
	height = sin(t * PI) * lane_hop
	if state_ticks >= lane_change_ticks:
		height = 0.0
		_enter(State.IDLE)


## The hitboxes active this tick, in screen space.
func active_hit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not is_attacking():
		return rects
	for box in move.hit_boxes:
		if box.active_on(move_frame):
			rects.append(hit_rect(box))
	return rects


func _tick_hitstun() -> void:
	x = clampf(x + _knock_speed, bounds.x, bounds.y)
	_knock_speed *= knockback_friction
	if state_ticks >= _stun_ticks:
		_enter(State.KNOCKDOWN if is_dying() else State.IDLE)


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


func _enter(new_state: State) -> void:
	previous_state = state
	state = new_state
	state_ticks = 0


func _place() -> void:
	position = Vector2(x, _ground_y - height)
	scale = Vector2(depth_scale, depth_scale)
	z_index = lane  # front lanes draw over back ones


## A box given for a full-size body facing right, as it is now in screen space.
func _faced(box: Rect2) -> Rect2:
	if facing < 0:
		box.position.x = -box.position.x - box.size.x
	box.position = box.position * depth_scale + position
	box.size *= depth_scale
	return box
