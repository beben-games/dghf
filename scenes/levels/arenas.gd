class_name Arenas
extends RefCounted
## The arenas of a stage (issue #58): stretches where the camera locks until
## their waves are beaten, as in most beat 'em ups. Each is a dictionary with
## `left` and `right`, the walls in stage pixels, and `waves`, the waves to
## send one after the other: a `WaveData` each from a `Level` (issue #62), or
## plain counts of small fry. Once a tick the stage tells it where
## the view is and how many enemies stand, and it says where the camera may go
## and asks for the next wave when it is time. No arenas means a free camera.
## Waves as data and a results screen are step 5 of the plan (issue #62).

## The next wave comes when this many enemies or fewer are left.
var wave_low: int = 4
## At least this many ticks between two waves.
var wave_gap: int = 120

var stage_width: float = 1920.0
var arenas: Array[Dictionary] = []
## The arena the camera is locked in, or -1 between arenas.
var index: int = -1
var locked: bool = false
## Waves sent in the locked arena so far.
var waves_sent: int = 0
## Arenas beaten so far; the next one to lock.
var cleared: int = 0
## Every arena beaten. Never true without arenas.
var done: bool = false

var _last_wave_tick: int = -100000


func setup(width: float, list: Array) -> void:
	stage_width = width
	arenas.assign(list)
	reset()


## The arenas of a level, as data (issue #62).
func setup_level(level: Level) -> void:
	var list: Array = []
	for arena in level.arenas:
		list.append({"left": arena.left, "right": arena.right, "waves": arena.waves})
	setup(level.stage_width, list)


## Back to before the first arena.
func reset() -> void:
	index = -1
	locked = false
	waves_sent = 0
	cleared = 0
	done = false
	_last_wave_tick = -100000


## The x range the camera may show now: the locked arena's walls, or from the
## last beaten arena's left wall (the stage's start before any) to the next
## arena's right wall (the stage's end after the last).
func limits() -> Vector2:
	if locked:
		return Vector2(arenas[index]["left"], arenas[index]["right"])
	var left: float = 0.0 if cleared == 0 else arenas[cleared - 1]["left"]
	var right: float = stage_width if cleared >= arenas.size() else arenas[cleared]["right"]
	return Vector2(left, right)


## Between two arenas: the last one is beaten and the next has not locked yet.
func between() -> bool:
	return not locked and cleared > 0 and not done


## The waves of the locked arena, for a readout. 0 when not locked.
func wave_count() -> int:
	return (arenas[index]["waves"] as Array).size() if locked else 0


## Once a tick, after the camera moved. `view_left` and `view_right` are the
## view's edges, `alive` how many enemies stand, and `spawn` is called with the
## wave (a `WaveData`, or a count) when one is due.
func tick(tick: int, view_left: float, view_right: float, alive: int, spawn: Callable) -> void:
	if done or arenas.is_empty():
		return
	if not locked:
		var next: Dictionary = arenas[cleared]
		if view_left < float(next["left"]) - 0.5 or view_right > float(next["right"]) + 0.5:
			return
		locked = true
		index = cleared
		waves_sent = 0
		_last_wave_tick = -100000
	var waves: Array = arenas[index]["waves"]
	if waves_sent < waves.size():
		if alive <= wave_low and tick - _last_wave_tick >= wave_gap:
			spawn.call(waves[waves_sent])
			waves_sent += 1
			_last_wave_tick = tick
	elif alive == 0:
		locked = false
		index = -1
		cleared += 1
		done = cleared >= arenas.size()
