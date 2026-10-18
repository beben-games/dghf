class_name CrowdDirector
extends Node2D
## Owns the crowd (docs/architecture.md, section 6): a pool of CrowdBody nodes
## it spawns from and takes back, their thinking in turns, the attack tokens
## that let only a few swing at once, and the spacing that keeps them from
## standing in one another. Tick it after the players and before Combat.
## With several players (issue #59) each body fights the nearest living one and
## the tokens are counted per player. Players are walls in their lane (issue
## #75): bodies go round through the other lanes, never through a player.

## How many bodies the pool holds. Never more than this on stage.
@export var capacity: int = 48
## Ticks between two thinks of the same body; bodies take turns.
@export var think_every: int = 6
## How many may attack the same player at the same time.
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
## A body switches to another player when that one is this much nearer, in pixels.
@export var retarget_margin: float = 300.0
## Players are walls in their lane (issue #75): a body stops this far from one it can't pass.
@export var wall_gap: float = 70.0
## How far past the target a body walks along a side lane before it comes back in on the other side.
@export var flank_past: float = 220.0
## Ticks a body has to be held by a wall on its way before it goes round through another lane.
@export var blocked_ticks: int = 20
## A taunting player (a tank holding its guard, issue #72) draws every body within this range.
@export var taunt_range: float = 900.0
## Taunted bodies converge rather than all hop at once: each waits its own time before each hop,
## between these two; and some, stragglers, wait between the long two instead.
@export var taunt_wait_min: int = 10
@export var taunt_wait_max: int = 50
@export var straggler_chance: float = 0.2
@export var straggler_wait_min: int = 180
@export var straggler_wait_max: int = 360

var lane_y: PackedFloat32Array = PackedFloat32Array()
var lane_scale: PackedFloat32Array = PackedFloat32Array()
var bounds: Vector2 = Vector2(0.0, 1920.0)
## Who the crowd fights: the players. Set by the stage. Each body picks the nearest living one.
var targets: Array[Body] = []
## Passive bodies stand where they are and never think: for a sandbox where enemies wait to be hit.
var passive: bool = false
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
	body.bounds = bounds
	body.revive(lane_y, lane_scale, spawn_lane, at_x, face)
	_alive.append(body)
	return body


## Takes every body back.
func clear() -> void:
	for body in _alive:
		body.visible = false
		_pool.append(body)
	_alive.clear()


## Where the bodies may stand. The stage moves it with the camera: a little
## past the view on each side, so a wave can walk in from off screen but
## nobody wanders far.
func set_bounds(stage_bounds: Vector2) -> void:
	bounds = stage_bounds
	for body in _alive:
		body.bounds = bounds


func set_lanes(lanes: PackedFloat32Array, scales: PackedFloat32Array) -> void:
	lane_y = lanes
	lane_scale = scales
	for body in _alive:
		body.set_lanes(lanes, scales)


func tick() -> void:
	_tick += 1
	var walls: Array[Body] = _walls()
	var sides: PackedInt32Array = _sides_of(walls)
	for body in _alive:
		if body.state == Body.State.ATTACK and body.move_frame >= body.move.total_frames - 1 and body.has_token:
			# The swing is over: the token goes back, and the body rests.
			body.has_token = false
			body.rest = _rng.randi_range(rest_min, rest_max)
		if body.target != null:
			body.off_lane_ticks = body.off_lane_ticks + 1 if body.lane != body.target.lane else 0
		if body.taunt_wait > 0:
			body.taunt_wait -= 1
		if _tick % think_every == body.think_slot and not targets.is_empty() and not passive:
			_think(body)
		body.tick()
	_keep_apart()
	_hold_at_walls(walls, sides)
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


## One body's decision: whom to fight, then where to go and whether to swing.
func _think(body: CrowdBody) -> void:
	if body.state != Body.State.IDLE and body.state != Body.State.WALK:
		return
	body.wanted_direction = 0
	body.wants_attack = false
	var target: Body = _pick_target(body)
	if target == null:
		# The fight is over: stand where you are.
		body.flank_lane = -1
		return
	if target != body.target:
		body.target = target
		body.side = 0
		body.off_lane_ticks = 0
		body.flank_lane = -1
	var gap: float = target.x - body.x
	if body.lane != target.lane:
		# Taunted: into the target's lane, one hop at a time, cap or no cap, each body after its
		# own wait, so the crowd converges rather than jumps. A body going round behind gives it
		# up; one going round another player in its way carries on.
		if not target.taunting():
			body.taunt_wait = -1
		elif body.flank_lane < 0 or body.flank_dist == flank_past:
			if body.taunt_wait < 0:
				body.taunt_wait = _taunt_wait()
			elif body.taunt_wait == 0:
				body.flank_lane = -1
				body.taunt_wait = -1
				body.start_lane_change(body.lane + (1 if target.lane > body.lane else -1))
				return
			# Meanwhile, close in along this lane.
			if absf(gap) > reach:
				body.wanted_direction = 1 if gap > 0.0 else -1
			if absf(gap) > 10.0:
				body.facing = 1 if gap > 0.0 else -1
			return
		if body.flank_lane >= 0:
			_flank(body, target)
			return
		# Follow across lanes after a moment, one lane at a time, unless the target's lane is full.
		# Meanwhile shadow the target's x from this lane.
		if body.off_lane_ticks >= lane_follow_ticks and _in_target_lane(target) < max_per_lane:
			body.start_lane_change(body.lane + (1 if target.lane > body.lane else -1))
			return
		if absf(gap) > reach:
			body.wanted_direction = 1 if gap > 0.0 else -1
		if absf(gap) > 10.0:
			body.facing = 1 if gap > 0.0 else -1
		return
	# In the target's lane. A body keeps to the side of the target it arrived on. When that side
	# is full and the other has room, or a player's wall has held it on its way for a while, it
	# goes round through a side lane (issue #75): never through a player.
	body.flank_lane = -1
	var here: int = 1 if body.x > target.x else -1
	if body.side == 0:
		body.side = here
	var goal_side: int = here
	var goal_dist: float = reach
	# A taunting target is piled on from this side: no going round behind it.
	if not target.taunting() and _on_side(target, here) > max_per_side and _on_side(target, -here) < max_per_side and _room(target, -here):
		goal_side = -here
		goal_dist = flank_past
	if goal_side != here or body.blocked >= blocked_ticks:
		var side_lane: int = _flank_lane(target)
		if side_lane >= 0:
			body.side = goal_side
			body.flank_side = goal_side
			body.flank_dist = goal_dist
			body.flank_lane = side_lane
			body.blocked = 0
			body.start_lane_change(side_lane)
			return
	if absf(gap) > reach:
		body.wanted_direction = 1 if gap > 0.0 else -1
		return
	body.facing = 1 if gap > 0.0 else -1
	if body.rest == 0 and not body.has_token and _tokens_on(target) < attack_tokens and target.can_be_hit():
		body.has_token = true
		body.wants_attack = true


## Along the side lane to the goal, which follows the target, then back into the
## target's lane when it has room; waiting beside the target meanwhile.
func _flank(body: CrowdBody, target: Body) -> void:
	var goal_x: float = clampf(target.x + body.flank_side * body.flank_dist, bounds.x, bounds.y)
	var to_goal: float = goal_x - body.x
	if absf(to_goal) > 12.0:
		body.wanted_direction = 1 if to_goal > 0.0 else -1
		body.facing = body.wanted_direction
		return
	body.facing = 1 if target.x > body.x else -1
	if _in_target_lane(target) < max_per_lane:
		body.flank_lane = -1
		body.start_lane_change(body.lane + (1 if target.lane > body.lane else -1))


## How long a body waits before its next hop toward a taunting target: a short while, or a
## long one for a straggler.
func _taunt_wait() -> int:
	if _rng.randf() < straggler_chance:
		return _rng.randi_range(straggler_wait_min, straggler_wait_max)
	return _rng.randi_range(taunt_wait_min, taunt_wait_max)


## The lane beside the target's with the most room, or -1 when both are full.
func _flank_lane(target: Body) -> int:
	var best: int = -1
	var fewest: int = max_per_lane
	for side_lane in [target.lane - 1, target.lane + 1]:
		if side_lane < 0 or side_lane >= lane_y.size():
			continue
		var n: int = _in_lane_near(side_lane, target)
		if n < fewest:
			fewest = n
			best = side_lane
	return best


## The living players: nobody walks through them in their lane (issue #75).
func _walls() -> Array[Body]:
	var walls: Array[Body] = []
	for wall in targets:
		if wall.state != Body.State.DEAD:
			walls.append(wall)
	return walls


## Which side of each wall every body is on, before it moves: 1 right, -1 left, 0 when the
## wall is not in its lane or the body is in the air. One entry per body and wall.
func _sides_of(walls: Array[Body]) -> PackedInt32Array:
	var sides: PackedInt32Array = PackedInt32Array()
	sides.resize(_alive.size() * walls.size())
	for i in _alive.size():
		var body: CrowdBody = _alive[i]
		for j in walls.size():
			var wall: Body = walls[j]
			var on_feet: bool = body.state != Body.State.LAUNCHED and body.state != Body.State.DEAD and body.state != Body.State.LANE_CHANGE
			sides[i * walls.size() + j] = (1 if body.x >= wall.x else -1) if on_feet and _wall_holds(wall, body) else 0
	return sides


## After everyone has moved: a body that crossed a wall, or came closer than
## wall_gap, is put back a step short of it. One walking into the wall counts
## how long it has been held, so it can go round.
func _hold_at_walls(walls: Array[Body], sides: PackedInt32Array) -> void:
	for i in _alive.size():
		var body: CrowdBody = _alive[i]
		var held: bool = false
		for j in walls.size():
			var side: int = sides[i * walls.size() + j]
			if side == 0 or body.state == Body.State.LAUNCHED or body.state == Body.State.DEAD or body.state == Body.State.LANE_CHANGE:
				continue
			var wall: Body = walls[j]
			if _wall_holds(wall, body) and (body.x - wall.x) * side < wall_gap:
				body.x = clampf(wall.x + side * wall_gap, bounds.x, bounds.y)
				# Held by a player in the way, not by the one it is after: that is where it wants to be.
				held = held or (body.wanted_direction == -side and wall != body.target)
		body.blocked = body.blocked + 1 if held else 0


## Whether `wall` holds `body`: in its lane, or in every lane while it taunts the body
## (issue #72), so a crowd converging on a tank stays on its side of it.
func _wall_holds(wall: Body, body: CrowdBody) -> bool:
	return body.lane == wall.lane or (wall.taunting() and body.target == wall)


## The nearest taunting player in range, else the living target nearest to
## `body`, unless the one it has is still close to as near: the crowd does not
## flicker between two players standing together. Null when everyone is down.
func _pick_target(body: CrowdBody) -> Body:
	var best: Body = null
	var best_gap: float = INF
	for candidate in targets:
		if candidate.state == Body.State.DEAD:
			continue
		var gap: float = absf(candidate.x - body.x)
		if candidate.taunting() and gap <= taunt_range and (best == null or not best.taunting() or gap < best_gap):
			best = candidate
			best_gap = gap
		elif gap < best_gap and (best == null or not best.taunting()):
			best = candidate
			best_gap = gap
	if best != null and best.taunting():
		return best
	var current: Body = body.target
	if best == null or current == null or current.state == Body.State.DEAD:
		return best
	return current if absf(current.x - body.x) <= best_gap + retarget_margin else best


## How many bodies hold an attack token on `target`, or are swinging at it.
func _tokens_on(target: Body) -> int:
	var n: int = 0
	for body in _alive:
		if body.target == target and (body.has_token or body.state == Body.State.ATTACK):
			n += 1
	return n


## How many bodies stand on `side` of the target in its lane, near it.
func _on_side(target: Body, side: int) -> int:
	var n: int = 0
	for body in _alive:
		if body.lane == target.lane and (body.x - target.x) * side > 0.0 and absf(body.x - target.x) < crowd_width:
			n += 1
	return n


## Whether there is stage on `side` of the target for a body to stand on.
func _room(target: Body, side: int) -> bool:
	var there: float = target.x + side * reach
	return there > bounds.x and there < bounds.y


## How many bodies are in the target's lane within crowd_width of it.
func _in_target_lane(target: Body) -> int:
	return _in_lane_near(target.lane, target)


## How many bodies are in `which_lane` within crowd_width of the target.
func _in_lane_near(which_lane: int, target: Body) -> int:
	var n: int = 0
	for body in _alive:
		if body.lane == which_lane and absf(body.x - target.x) < crowd_width:
			n += 1
	return n


## Bodies in the same lane that stand too close push each other apart a little,
## so a crowd spreads along the lane instead of stacking in one spot.
func _keep_apart() -> void:
	for i in _alive.size():
		var a: CrowdBody = _alive[i]
		if a.state == Body.State.LAUNCHED or a.state == Body.State.DEAD:
			continue
		for j in range(i + 1, _alive.size()):
			var b: CrowdBody = _alive[j]
			if b.lane != a.lane or b.state == Body.State.LAUNCHED or b.state == Body.State.DEAD:
				continue
			var gap: float = b.x - a.x
			if absf(gap) < spacing:
				var push: float = (spacing - absf(gap)) * 0.25
				var sign_gap: float = 1.0 if gap >= 0.0 else -1.0
				a.x = clampf(a.x - sign_gap * push, bounds.x, bounds.y)
				b.x = clampf(b.x + sign_gap * push, bounds.x, bounds.y)
