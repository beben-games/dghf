extends RefCounted
## The crowd of the stress test (issue #3): plain arrays, no nodes.
## Throwaway code. It only measures what a crowd costs per tick.
##
## Enemies stand in 3 lanes of 2 staggered rows each, as proposed in
## docs/architecture.md section 2. Each keeps its row, walks toward the target's
## x, and stops behind whoever is in front of it. Each thinks every 6 ticks,
## offset from the others (section 6).

const LANES: int = 3
const ROWS_PER_LANE: int = 2
const ROWS: int = LANES * ROWS_PER_LANE
const THINK_EVERY: int = 6

const WALK_SPEED: float = 0.6  # pixels per tick
const REACH: float = 20.0  # stops this close to the target
const SPACING: float = 14.0  # gap an enemy keeps to the next one in its row

# The world is wider than the 480-pixel screen: most of a big crowd waits off screen.
const WORLD_MIN: float = -480.0
const WORLD_MAX: float = 960.0
const CELL: float = 16.0  # must be at least SPACING
const CELLS: int = int((WORLD_MAX - WORLD_MIN) / CELL) + 1

var count: int = 0
var x: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var facing: PackedFloat32Array = PackedFloat32Array()  # 1.0 right, -1.0 left

# Neighbour search: per row and cell, a linked list of the enemies in it.
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()


func setup(capacity: int) -> void:
	x.resize(capacity)
	vx.resize(capacity)
	facing.resize(capacity)
	_next.resize(capacity)
	_head.resize(ROWS * CELLS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12  # the same crowd on every machine
	for i in capacity:
		x[i] = rng.randf_range(WORLD_MIN, WORLD_MAX)
		vx[i] = 0.0
		facing[i] = 1.0


## The row never changes: enemy i is always in row i % ROWS.
static func row_of(i: int) -> int:
	return i % ROWS


func tick(target_x: float, tick_number: int) -> void:
	_head.fill(-1)
	for i in count:
		var cell: int = row_of(i) * CELLS + int((x[i] - WORLD_MIN) / CELL)
		_next[i] = _head[cell]
		_head[cell] = i
	for i in count:
		if (i + tick_number) % THINK_EVERY == 0:
			_think(i, target_x)
		x[i] = clampf(x[i] + vx[i], WORLD_MIN, WORLD_MAX)


func _think(i: int, target_x: float) -> void:
	var to_target: float = target_x - x[i]
	var want: float = 0.0
	if absf(to_target) > REACH:
		want = signf(to_target)
		facing[i] = want

	var push: float = 0.0
	var blocked: bool = false
	var row_start: int = row_of(i) * CELLS
	var cell_x: int = int((x[i] - WORLD_MIN) / CELL)
	for c in range(maxi(cell_x - 1, 0), mini(cell_x + 1, CELLS - 1) + 1):
		var j: int = _head[row_start + c]
		while j != -1:
			if j != i:
				var d: float = x[j] - x[i]
				if absf(d) < SPACING * 0.5:
					# Overlapping: step away. Equal positions split by index.
					if d > 0.0 or (d == 0.0 and i < j):
						push -= 1.0
					else:
						push += 1.0
				elif absf(d) < SPACING and signf(d) == want:
					blocked = true
			j = _next[j]

	if push != 0.0:
		vx[i] = signf(push) * WALK_SPEED
	elif blocked:
		vx[i] = 0.0
	else:
		vx[i] = want * WALK_SPEED
