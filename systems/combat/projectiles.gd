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


func _init() -> void:
	_x.resize(CAPACITY)
	_y.resize(CAPACITY)
	_vx.resize(CAPACITY)
	_age.resize(CAPACITY)


func count() -> int:
	return _count


func spawn(at: Vector2, velocity_x: float) -> void:
	if _count == CAPACITY:
		return
	_x[_count] = at.x
	_y[_count] = at.y
	_vx[_count] = velocity_x
	_age[_count] = 0
	_count += 1


func tick() -> void:
	var i: int = 0
	while i < _count:
		_x[i] += _vx[i]
		_age[i] += 1
		if _x[i] < bounds.x - RADIUS * 2.0 or _x[i] > bounds.y + RADIUS * 2.0:
			# Fill the hole with the last one: order doesn't matter.
			_count -= 1
			_x[i] = _x[_count]
			_y[i] = _y[_count]
			_vx[i] = _vx[_count]
			_age[i] = _age[_count]
		else:
			i += 1
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
