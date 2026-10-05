class_name Projectiles
extends Node2D
## Every projectile on the stage, in one pooled system: plain arrays and one
## draw call site, never a node per projectile.

const CAPACITY: int = 64
const RADIUS: float = 34.0

var bounds: Vector2 = Vector2(0.0, 1920.0)  # they die outside this x range

var _count: int = 0
var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()  # screen y of the centre
var _vx: PackedFloat32Array = PackedFloat32Array()
var _age: PackedInt32Array = PackedInt32Array()
var _lane: PackedInt32Array = PackedInt32Array()
var _team: PackedInt32Array = PackedInt32Array()
var _hit: Array[HitBox] = []  # null for a projectile that can't hit


func _init() -> void:
	_x.resize(CAPACITY)
	_y.resize(CAPACITY)
	_vx.resize(CAPACITY)
	_age.resize(CAPACITY)
	_lane.resize(CAPACITY)
	_team.resize(CAPACITY)
	_hit.resize(CAPACITY)


func count() -> int:
	return _count


## `hit` is what it does to a target of another team in its lane, or null for none.
func spawn(at: Vector2, velocity_x: float, in_lane: int = 0, of_team: int = 0, hit: HitBox = null) -> void:
	if _count == CAPACITY:
		return
	_x[_count] = at.x
	_y[_count] = at.y
	_vx[_count] = velocity_x
	_age[_count] = 0
	_lane[_count] = in_lane
	_team[_count] = of_team
	_hit[_count] = hit
	_count += 1


func tick() -> void:
	var i: int = 0
	while i < _count:
		_x[i] += _vx[i]
		_age[i] += 1
		if _x[i] < bounds.x - RADIUS * 2.0 or _x[i] > bounds.y + RADIUS * 2.0:
			remove(i)
		else:
			i += 1
	queue_redraw()


## The box projectile `i` hits with, in screen space.
func rect(i: int) -> Rect2:
	return Rect2(_x[i] - RADIUS, _y[i] - RADIUS, RADIUS * 2.0, RADIUS * 2.0)


func lane(i: int) -> int:
	return _lane[i]


func team(i: int) -> int:
	return _team[i]


func hit(i: int) -> HitBox:
	return _hit[i]


## 1 if it flies right, -1 if left.
func direction(i: int) -> int:
	return 1 if _vx[i] >= 0.0 else -1


func remove(i: int) -> void:
	# Fill the hole with the last one: order doesn't matter.
	_count -= 1
	_x[i] = _x[_count]
	_y[i] = _y[_count]
	_vx[i] = _vx[_count]
	_age[i] = _age[_count]
	_lane[i] = _lane[_count]
	_team[i] = _team[_count]
	_hit[i] = _hit[_count]
	_hit[_count] = null
	queue_redraw()


## Placeholder look: a fireball with a short tail.
func _draw() -> void:
	for i in _count:
		var centre := Vector2(_x[i], _y[i])
		var back: float = -signf(_vx[i])
		var flicker: float = 1.0 + 0.12 * sin(_age[i] * 0.9)
		for k in range(4, 0, -1):
			draw_circle(centre + Vector2(back * k * 20.0, 0.0), RADIUS * (1.0 - k * 0.18), Color(0.85, 0.25, 0.08, 0.5))
		draw_circle(centre, RADIUS * flicker, Color(0.95, 0.45, 0.1))
		draw_circle(centre, RADIUS * 0.6 * flicker, Color(1.0, 0.85, 0.35))
