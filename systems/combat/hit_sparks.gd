class_name HitSparks
extends Node2D
## The spark drawn where a hit lands. One pooled system with plain arrays and
## one draw call site, never a node per hit (docs/architecture.md, section 7).

const CAPACITY: int = 128
const LIFE: int = 9  # ticks a spark stays

var _count: int = 0
var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _age: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_x.resize(CAPACITY)
	_y.resize(CAPACITY)
	_size.resize(CAPACITY)
	_age.resize(CAPACITY)


func count() -> int:
	return _count


func spawn(at: Vector2, size: float) -> void:
	if _count == CAPACITY:
		return
	_x[_count] = at.x
	_y[_count] = at.y
	_size[_count] = size
	_age[_count] = 0
	_count += 1


func tick() -> void:
	var i: int = 0
	while i < _count:
		_age[i] += 1
		if _age[i] >= LIFE:
			# Fill the hole with the last one: order doesn't matter.
			_count -= 1
			_x[i] = _x[_count]
			_y[i] = _y[_count]
			_size[i] = _size[_count]
			_age[i] = _age[_count]
		else:
			i += 1
	queue_redraw()


## Placeholder look: a star that grows and thins out.
func _draw() -> void:
	for i in _count:
		var centre := Vector2(_x[i], _y[i])
		var t: float = float(_age[i]) / LIFE
		var reach: float = _size[i] * (0.5 + t)
		var colour := Color(1.0, 0.95, 0.7, 1.0 - t)
		for k in 4:
			var arm := Vector2.from_angle(k * PI / 4.0 + _size[i]) * reach
			draw_line(centre - arm, centre + arm, colour, maxf(2.0, 10.0 * (1.0 - t)))
		draw_circle(centre, _size[i] * 0.35 * (1.0 - t), Color(1.0, 1.0, 1.0, 1.0 - t))
