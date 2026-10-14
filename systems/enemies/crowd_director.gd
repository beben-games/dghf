class_name CrowdDirector
extends Node2D
## Owns the crowd (docs/architecture.md, section 6): a pool of CrowdBody nodes
## it spawns from and takes back, their thinking in turns, the attack tokens
## that let only a few swing at once, and the spacing that keeps them from
## standing in one another. Tick it after the players and before Combat.

## How many bodies the pool holds. Never more than this on stage.
@export var capacity: int = 48
## Ticks between two thinks of the same body; bodies take turns.
@export var think_every: int = 6
## How many may attack at the same time, over the whole crowd.
@export var attack_tokens: int = 3
## How close a body walks before it stops and waits, in pixels.
@export var reach: float = 170.0
## The gap bodies keep between each other along a lane.
@export var spacing: float = 90.0
## Ticks a body waits after a swing before it may swing again, between these two.
@export var rest_min: int = 40
@export var rest_max: int = 90
## Ticks the target has to be in another lane before a body follows it there (issue #49).
@export var lane_follow_ticks: int = 45
## How many bodies may crowd the target's lane near it; the rest wait in the lanes beside.
@export var max_per_lane: int = 6
## How far from the target's x a body counts as crowding its lane.
@export var crowd_width: float = 500.0
## How many bodies may stand on one side of the target in its lane before the next one goes around.
@export var max_per_side: int = 3

var lane_y: PackedFloat32Array = PackedFloat32Array()
var lane_scale: PackedFloat32Array = PackedFloat32Array()
var bounds: Vector2 = Vector2(0.0, 1920.0)
## Who the crowd fights. Set by the stage.
var target: Body
## The attack data every body uses.
var attack: Move = preload("res://data/moves/crowd/jab.tres")

var _pool: Array[CrowdBody] = []
var _alive: Array[CrowdBody] = []
var _tick: int = 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7


func setup(lanes: PackedFloat32Array, scales: PackedFloat32Array, stage_bounds: Vector2) -> void:
	lane_y = lanes
	lane_scale = scales
	bounds = stage_bounds
	for i in capacity:
		var body := CrowdBody.new()
		body.team = 2
		body.max_health = 30
		body.attack = attack
		body.bounds = bounds
		body.think_slot = i % think_every
		body.visible = false
		add_child(body)
		_pool.append(body)


## The bodies alive right now, in the order they are ticked.
func alive() -> Array[CrowdBody]:
	return _alive


func count() -> int:
	return _alive.size()


## Brings one body from the pool to a lane at an x, facing `face`. Null if the pool is empty.
func spawn(spawn_lane: int, at_x: float, face: int) -> CrowdBody:
	if _pool.is_empty():
		return null
	var body: CrowdBody = _pool.pop_back()
	body.revive(lane_y, lane_scale, spawn_lane, at_x, face)
	_alive.append(body)
	return body


## Takes every body back.
func clear() -> void:
	for body in _alive:
		body.visible = false
		_pool.append(body)
	_alive.clear()


func set_lanes(lanes: PackedFloat32Array, scales: PackedFloat32Array) -> void:
	lane_y = lanes
	lane_scale = scales
	for body in _alive:
		body.set_lanes(lanes, scales)


func tick() -> void:
	_tick += 1
	var tokens_out: int = 0
	for body in _alive:
		if body.state == Body.State.ATTACK or body.has_token:
			tokens_out += 1
	for body in _alive:
		if body.state == Body.State.ATTACK and body.move_frame >= body.move.total_frames - 1 and body.has_token:
			# The swing is over: the token goes back, and the body rests.
			body.has_token = false
			tokens_out -= 1
			body.rest = _rng.randi_range(rest_min, rest_max)
		if target != null:
			body.off_lane_ticks = body.off_lane_ticks + 1 if body.lane != target.lane else 0
		if _tick % think_every == body.think_slot and target != null:
			tokens_out += _think(body, tokens_out)
		body.tick()
	_keep_apart()
	# The dead go back to the pool once they have lain there a moment.
	var i: int = _alive.size() - 1
	while i >= 0:
		var body: CrowdBody = _alive[i]
		if body.is_done():
			body.visible = false
			body.has_token = false
			_alive.remove_at(i)
			_pool.append(body)
		i -= 1


## One body's decision. Returns 1 if it took an attack token.
func _think(body: CrowdBody, tokens_out: int) -> int:
	if body.state != Body.State.IDLE and body.state != Body.State.WALK:
		return 0
	var gap: float = target.x - body.x
	body.wanted_direction = 0
	body.wants_attack = false
	if target.state == Body.State.DEAD:
		# The fight is over: stand where you are.
		body.crossing = false
		return 0
	if body.lane != target.lane:
		# Follow across lanes after a moment, one lane at a time, unless the target's lane is full.
		# Meanwhile shadow the target's x from this lane.
		if body.off_lane_ticks >= lane_follow_ticks and _in_target_lane() < max_per_lane:
			body.start_lane_change(body.lane + (1 if target.lane > body.lane else -1))
			return 0
		if absf(gap) > reach:
			body.wanted_direction = 1 if gap > 0.0 else -1
		if absf(gap) > 10.0:
			body.facing = 1 if gap > 0.0 else -1
		return 0
	# In the target's lane. A body keeps to the side of the target it arrived on, unless that
	# side is full and the other has room: then it goes around, walking through the target
	# (there is no body collision) with nobody pushing it on the way. Then it closes in and
	# swings from its side.
	var here: int = 1 if body.x > target.x else -1
	if body.side == 0:
		body.side = here
	if body.side == here and _on_side(here) > max_per_side and _on_side(-here) < max_per_side and _room(-here):
		body.side = -here
	body.crossing = body.side != here
	if body.crossing:
		body.wanted_direction = body.side
		return 0
	if absf(gap) > reach:
		body.wanted_direction = 1 if gap > 0.0 else -1
		return 0
	body.facing = 1 if gap > 0.0 else -1
	if body.rest == 0 and not body.has_token and tokens_out < attack_tokens and target.can_be_hit():
		body.has_token = true
		body.wants_attack = true
		return 1
	return 0


## How many bodies stand on `side` of the target in its lane, near it.
func _on_side(side: int) -> int:
	var n: int = 0
	for body in _alive:
		if body.lane == target.lane and not body.crossing and (body.x - target.x) * side > 0.0 and absf(body.x - target.x) < crowd_width:
			n += 1
	return n


## Whether there is stage on `side` of the target for a body to stand on.
func _room(side: int) -> bool:
	var there: float = target.x + side * reach
	return there > bounds.x and there < bounds.y


## How many bodies are in the target's lane within crowd_width of it.
func _in_target_lane() -> int:
	var n: int = 0
	for body in _alive:
		if body.lane == target.lane and absf(body.x - target.x) < crowd_width:
			n += 1
	return n


## Bodies in the same lane that stand too close push each other apart a little,
## so a crowd spreads along the lane instead of stacking in one spot.
func _keep_apart() -> void:
	for i in _alive.size():
		var a: CrowdBody = _alive[i]
		if a.state == Body.State.LAUNCHED or a.state == Body.State.DEAD or a.crossing:
			continue
		for j in range(i + 1, _alive.size()):
			var b: CrowdBody = _alive[j]
			if b.lane != a.lane or b.state == Body.State.LAUNCHED or b.state == Body.State.DEAD or b.crossing:
				continue
			var gap: float = b.x - a.x
			if absf(gap) < spacing:
				var push: float = (spacing - absf(gap)) * 0.25
				var sign_gap: float = 1.0 if gap >= 0.0 else -1.0
				a.x = clampf(a.x - sign_gap * push, bounds.x, bounds.y)
				b.x = clampf(b.x + sign_gap * push, bounds.x, bounds.y)
