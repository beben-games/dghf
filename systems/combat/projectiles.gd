class_name Projectiles
extends Node2D
## Everything a move sends out, in one pooled system: plain arrays and one
## draw call site, never a node per projectile. Three kinds: a fireball that
## flies along its lane, a burst that grows around a point and reaches every
## lane, and a missile that homes on the nearest enemy across lanes.

enum Kind { FIREBALL, BURST, MISSILE }

const CAPACITY: int = 64
const RADIUS: float = 34.0

var bounds: Vector2 = Vector2(0.0, 1920.0)  # they die outside this x range

var _count: int = 0
var _kind: PackedInt32Array = PackedInt32Array()
var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()  # screen y of the centre
var _vx: PackedFloat32Array = PackedFloat32Array()
var _vy: PackedFloat32Array = PackedFloat32Array()
var _age: PackedInt32Array = PackedInt32Array()
var _life: PackedInt32Array = PackedInt32Array()  # ticks it lasts; 0 means until off screen
var _lane: PackedInt32Array = PackedInt32Array()
var _team: PackedInt32Array = PackedInt32Array()
var _hit: Array[HitBox] = []  # null for a projectile that can't hit
var _scale: PackedFloat32Array = PackedFloat32Array()  # drawn size: the move's size times the lane's depth
var _pierce: PackedByteArray = PackedByteArray()  # 1 for one that goes through what it hits
var _all_lanes: PackedByteArray = PackedByteArray()  # 1 for one that hits in every lane
var _homing: PackedFloat32Array = PackedFloat32Array()  # how hard a missile turns toward its target, 0 for none
var _target: Array[Body] = []  # what a missile homes on
var _already_hit: Array[PackedInt64Array] = []  # the bodies a piercing one has hit, by instance id


func _init() -> void:
	for arr in [_kind, _age, _life, _lane, _team]:
		arr.resize(CAPACITY)
	for arr in [_x, _y, _vx, _vy, _scale, _homing]:
		arr.resize(CAPACITY)
	_hit.resize(CAPACITY)
	_target.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_all_lanes.resize(CAPACITY)
	_already_hit.resize(CAPACITY)
	for i in CAPACITY:
		_already_hit[i] = PackedInt64Array()


func count() -> int:
	return _count


## Sends out what `move` describes from `at`, for a body of `team` in `lane`
## facing `facing` and drawn at `depth`. A move with several projectiles fans
## them out vertically.
func spawn_from(move: Move, at: Vector2, lane: int, team: int, facing: int, depth: float) -> void:
	var n: int = maxi(move.projectile_count, 1)
	for i in n:
		var vy: float = (i - (n - 1) / 2.0) * move.projectile_spread
		spawn(at, move.projectile_speed * facing, lane, team, move.projectile_hit, depth * move.projectile_size,
				move.projectile_pierce, move.projectile_kind, move.projectile_lifetime, move.projectile_all_lanes,
				move.projectile_homing, vy)


## `hit` is what it does to a target of another team in its lane, or null for none.
func spawn(at: Vector2, velocity_x: float, in_lane: int = 0, of_team: int = 0, hit: HitBox = null, size: float = 1.0,
		pierce: bool = false, kind: Kind = Kind.FIREBALL, life: int = 0, all_lanes: bool = false, homing: float = 0.0,
		velocity_y: float = 0.0) -> void:
	if _count == CAPACITY:
		return
	_kind[_count] = kind
	_x[_count] = at.x
	_y[_count] = at.y
	_vx[_count] = velocity_x
	_vy[_count] = velocity_y
	_age[_count] = 0
	_life[_count] = life
	_lane[_count] = in_lane
	_team[_count] = of_team
	_hit[_count] = hit
	_scale[_count] = size
	_pierce[_count] = 1 if pierce else 0
	_all_lanes[_count] = 1 if all_lanes else 0
	_homing[_count] = homing
	_target[_count] = null
	_already_hit[_count] = PackedInt64Array()
	_count += 1


## `bodies` are everyone on the stage this tick, for missiles to find a target.
func tick(bodies: Array[Body] = []) -> void:
	var i: int = 0
	while i < _count:
		if _homing[i] > 0.0:
			_home(i, bodies)
		if _kind[i] != Kind.BURST:
			_x[i] += _vx[i]
			_y[i] += _vy[i]
		_age[i] += 1
		var gone: bool = _x[i] < bounds.x - RADIUS * 2.0 or _x[i] > bounds.y + RADIUS * 2.0
		if _life[i] > 0 and _age[i] >= _life[i]:
			gone = true
		if gone:
			remove(i)
		else:
			i += 1
	queue_redraw()


## A missile keeps its speed and turns toward the nearest enemy body it can hit.
func _home(i: int, bodies: Array[Body]) -> void:
	var target: Body = _target[i]
	if target == null or not is_instance_valid(target) or not target.can_be_hit() or _already_hit[i].has(target.get_instance_id()):
		target = null
		var best: float = INF
		for body in bodies:
			if body.team == _team[i] or not body.can_be_hit() or _already_hit[i].has(body.get_instance_id()):
				continue
			if not _all_lanes[i] and body.lane != _lane[i]:
				continue
			var d: float = Vector2(_x[i], _y[i]).distance_to(body.hurt_rect().get_center())
			if d < best:
				best = d
				target = body
		_target[i] = target
	if target == null:
		return
	var speed: float = Vector2(_vx[i], _vy[i]).length()
	var wanted: Vector2 = (target.hurt_rect().get_center() - Vector2(_x[i], _y[i])).normalized() * speed
	var v: Vector2 = Vector2(_vx[i], _vy[i]).move_toward(wanted, _homing[i])
	v = v.normalized() * speed
	_vx[i] = v.x
	_vy[i] = v.y


## The box projectile `i` hits with, in screen space. A burst grows over its life.
func rect(i: int) -> Rect2:
	var r: float = radius(i)
	return Rect2(_x[i] - r, _y[i] - r, r * 2.0, r * 2.0)


func radius(i: int) -> float:
	var r: float = RADIUS * _scale[i]
	if _kind[i] == Kind.BURST and _life[i] > 0:
		r *= minf(float(_age[i] + 1) / (_life[i] * 0.6), 1.0)
	return r


func lane(i: int) -> int:
	return _lane[i]


func team(i: int) -> int:
	return _team[i]


func hit(i: int) -> HitBox:
	return _hit[i]


func hits_every_lane(i: int) -> bool:
	return _all_lanes[i] == 1


## Whether projectile `i` goes on after a hit, and whether it has hit `body` already.
func pierces(i: int) -> bool:
	return _pierce[i] == 1


func has_hit(i: int, body: Node) -> bool:
	return _already_hit[i].has(body.get_instance_id())


func mark_hit(i: int, body: Node) -> void:
	_already_hit[i].append(body.get_instance_id())


## 1 if it flies right, -1 if left. A burst pushes away from its centre, so it says 1.
func direction(i: int) -> int:
	return 1 if _vx[i] >= 0.0 else -1


func remove(i: int) -> void:
	# Fill the hole with the last one: order doesn't matter.
	_count -= 1
	for arr in [_kind, _age, _life, _lane, _team]:
		arr[i] = arr[_count]
	for arr in [_x, _y, _vx, _vy, _scale, _homing]:
		arr[i] = arr[_count]
	_hit[i] = _hit[_count]
	_hit[_count] = null
	_target[i] = _target[_count]
	_target[_count] = null
	_pierce[i] = _pierce[_count]
	_all_lanes[i] = _all_lanes[_count]
	_already_hit[i] = _already_hit[_count]
	_already_hit[_count] = PackedInt64Array()
	queue_redraw()


## Placeholder looks until the team's effects arrive: a fireball with a short
## tail, a burst as a growing ring, a missile as a dart with a tail.
func _draw() -> void:
	for i in _count:
		var centre := Vector2(_x[i], _y[i])
		match _kind[i]:
			Kind.FIREBALL:
				var back: float = -signf(_vx[i])
				var flicker: float = 1.0 + 0.12 * sin(_age[i] * 0.9)
				var r: float = RADIUS * _scale[i]
				for k in range(4, 0, -1):
					draw_circle(centre + Vector2(back * k * 20.0 * _scale[i], 0.0), r * (1.0 - k * 0.18), Color(0.85, 0.25, 0.08, 0.5))
				draw_circle(centre, r * flicker, Color(0.95, 0.45, 0.1))
				draw_circle(centre, r * 0.6 * flicker, Color(1.0, 0.85, 0.35))
			Kind.BURST:
				var r: float = radius(i)
				var fade: float = 1.0 - float(_age[i]) / maxi(_life[i], 1)
				draw_circle(centre, r, Color(1.0, 0.6, 0.2, 0.25 * fade))
				draw_arc(centre, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, fade), 10.0)
				draw_arc(centre, r * 0.7, 0.0, TAU, 48, Color(1.0, 0.95, 0.8, fade * 0.6), 4.0)
			Kind.MISSILE:
				var v := Vector2(_vx[i], _vy[i])
				var dir: Vector2 = v.normalized() if v.length() > 0.0 else Vector2.RIGHT
				var r: float = RADIUS * 0.5 * _scale[i]
				for k in range(5, 0, -1):
					draw_circle(centre - dir * k * 14.0 * _scale[i], r * (1.0 - k * 0.15), Color(0.9, 0.5, 0.15, 0.4))
				draw_circle(centre, r, Color(1.0, 0.8, 0.3))
				draw_line(centre, centre + dir * r * 2.2, Color(1.0, 0.95, 0.7), r * 0.8)
