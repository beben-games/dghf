extends Node2D
## Crowd stress test (issue #3). Throwaway code: nothing gets built on top of it.
##
## Draws the same crowd two ways, to choose how enemies are built
## (docs/architecture.md, section 6):
##   NODES      one pooled Sprite2D per enemy, no physics body
##   MULTIMESH  no node per enemy: one MultiMesh per row
##
## Keys: 1 to 5 set the enemy count, Tab switches the way they are drawn.
## Run with "-- --benchmark" to measure every combination and print a table.
## The keys are read straight from the keyboard because this is a debug scene;
## game input goes through a player index.

const CrowdSim := preload("res://scenes/stress_test/crowd_sim.gd")

enum Mode { NODES, MULTIMESH }

const MODE_NAMES: Array[String] = ["nodes", "multimesh"]
const COUNTS: Array[int] = [100, 200, 300, 500, 1000]
const MAX_COUNT: int = 1000
const SPRITE_SIZE := Vector2i(26, 38)  # the proposed character size
const SCREEN_WIDTH: float = 480.0
const LANE_Y: Array[float] = [170.0, 205.0, 240.0]  # feet of each lane's back row
const ROW_GAP: float = 9.0  # a lane's second row stands this much lower
const TARGET_SPEED: float = 1.2  # pixels per tick
const TICK_BUDGET_MS: float = 1000.0 / 60.0

const BENCH_WARMUP_TICKS: int = 60
const BENCH_MEASURE_TICKS: int = 240

var _sim: CrowdSim = CrowdSim.new()
var _mode: Mode = Mode.NODES
var _tick: int = 0
var _target_x: float = SCREEN_WIDTH / 2.0
var _target_dir: float = 1.0

var _sprites: Array[Sprite2D] = []
var _node_rows: Array[Node2D] = []
var _multimeshes: Array[MultiMesh] = []
var _mesh_rows: Array[MultiMeshInstance2D] = []
var _target_sprite: Sprite2D
var _label: Label

# Measured over the current window (one second, or one benchmark run).
var _sim_usec: int = 0
var _sim_usec_max: int = 0
var _sync_usec: int = 0
var _ticks: int = 0
var _frames: int = 0
var _window_start_usec: int = 0

var _benchmark: bool = false
var _bench_runs: Array[Vector2i] = []  # (mode, count) still to measure
var _bench_ticks: int = 0
var _bench_lines: Array[String] = []


func _ready() -> void:
	_sim.setup(MAX_COUNT)
	_build_rows(_make_texture(Color(0.75, 0.2, 0.2)))
	_target_sprite = Sprite2D.new()
	_target_sprite.texture = _make_texture(Color(0.2, 0.5, 0.9))
	_target_sprite.centered = false
	_target_sprite.offset = Vector2(-SPRITE_SIZE.x / 2.0, -SPRITE_SIZE.y)
	_target_sprite.position.y = LANE_Y[1] + ROW_GAP / 2.0
	add_child(_target_sprite)
	_build_label()

	_benchmark = OS.get_cmdline_user_args().has("--benchmark")
	if _benchmark:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for mode: int in [Mode.NODES, Mode.MULTIMESH]:
			for count in COUNTS:
				_bench_runs.append(Vector2i(mode, count))
		_start_next_run()
	else:
		_apply(Mode.NODES, COUNTS[0])


func _unhandled_input(event: InputEvent) -> void:
	if _benchmark or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_TAB:
		_apply(Mode.MULTIMESH if _mode == Mode.NODES else Mode.NODES, _sim.count)
	elif key >= KEY_1 and key < KEY_1 + COUNTS.size():
		_apply(_mode, COUNTS[key - KEY_1])


func _physics_process(_delta: float) -> void:
	_target_x += _target_dir * TARGET_SPEED
	if _target_x < 40.0 or _target_x > SCREEN_WIDTH - 40.0:
		_target_dir = -_target_dir
	_target_sprite.position.x = _target_x

	var t0: int = Time.get_ticks_usec()
	_sim.tick(_target_x, _tick)
	var t1: int = Time.get_ticks_usec()
	_sync()
	var t2: int = Time.get_ticks_usec()

	_tick += 1
	_ticks += 1
	_sim_usec += t1 - t0
	_sim_usec_max = maxi(_sim_usec_max, t1 - t0)
	_sync_usec += t2 - t1

	if _benchmark:
		_bench_ticks += 1
		if _bench_ticks == BENCH_WARMUP_TICKS:
			_reset_window()
		elif _bench_ticks == BENCH_WARMUP_TICKS + BENCH_MEASURE_TICKS:
			_bench_lines.append(_report())
			_start_next_run()
	elif _ticks >= 60:
		_label.text = _report()
		_reset_window()


func _process(_delta: float) -> void:
	_frames += 1


## Copies the crowd's positions to whatever draws it.
func _sync() -> void:
	var count: int = _sim.count
	if _mode == Mode.NODES:
		for i in count:
			var sprite: Sprite2D = _sprites[i]
			sprite.position.x = _sim.x[i]
			sprite.flip_h = _sim.facing[i] < 0.0
	else:
		for i in count:
			var row: int = CrowdSim.row_of(i)
			var facing: float = _sim.facing[i]
			var transform := Transform2D(Vector2(facing, 0.0), Vector2(0.0, 1.0), Vector2(_sim.x[i], _row_y(row)))
			@warning_ignore("integer_division")
			_multimeshes[row].set_instance_transform_2d(i / CrowdSim.ROWS, transform)


func _apply(mode: Mode, count: int) -> void:
	_mode = mode
	_sim.count = count
	for i in MAX_COUNT:
		_sprites[i].visible = mode == Mode.NODES and i < count
	for row in CrowdSim.ROWS:
		_mesh_rows[row].visible = mode == Mode.MULTIMESH
		# Enemies 0..count-1 fill the rows in turn, so row r holds this many.
		@warning_ignore("integer_division")
		_multimeshes[row].visible_instance_count = (count + CrowdSim.ROWS - 1 - row) / CrowdSim.ROWS
	_reset_window()


func _start_next_run() -> void:
	if _bench_runs.is_empty():
		print("mode, enemies, frames per second, crowd logic ms per tick (average), (worst), drawing sync ms per tick, share of the 16.7 ms tick")
		for line in _bench_lines:
			print(line)
		get_tree().quit()
		return
	var run: Vector2i = _bench_runs.pop_front()
	_bench_ticks = 0
	_apply(run.x as Mode, run.y)


func _reset_window() -> void:
	_sim_usec = 0
	_sim_usec_max = 0
	_sync_usec = 0
	_ticks = 0
	_frames = 0
	_window_start_usec = Time.get_ticks_usec()


func _report() -> String:
	var seconds: float = (Time.get_ticks_usec() - _window_start_usec) / 1_000_000.0
	var sim_ms: float = _sim_usec / 1000.0 / _ticks
	var sync_ms: float = _sync_usec / 1000.0 / _ticks
	return "%s, %d, %.0f, %.2f, %.2f, %.2f, %.0f%%" % [
		MODE_NAMES[_mode], _sim.count, _frames / seconds,
		sim_ms, _sim_usec_max / 1000.0, sync_ms,
		(sim_ms + sync_ms) / TICK_BUDGET_MS * 100.0,
	]


func _row_y(row: int) -> float:
	@warning_ignore("integer_division")
	return LANE_Y[row / CrowdSim.ROWS_PER_LANE] + (row % CrowdSim.ROWS_PER_LANE) * ROW_GAP


## Rows are added back to front, so a lower row draws over the one behind it.
func _build_rows(texture: Texture2D) -> void:
	var quad := _make_quad()
	@warning_ignore("integer_division")
	var per_row: int = (MAX_COUNT + CrowdSim.ROWS - 1) / CrowdSim.ROWS
	for row in CrowdSim.ROWS:
		var node_row := Node2D.new()
		node_row.position.y = _row_y(row)
		add_child(node_row)
		_node_rows.append(node_row)

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.mesh = quad
		multimesh.instance_count = per_row
		multimesh.visible_instance_count = 0
		_multimeshes.append(multimesh)
		var mesh_row := MultiMeshInstance2D.new()
		mesh_row.multimesh = multimesh
		mesh_row.texture = texture
		add_child(mesh_row)
		_mesh_rows.append(mesh_row)

	# The pool: every sprite exists from the start and is only shown or hidden.
	for i in MAX_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = Vector2(-SPRITE_SIZE.x / 2.0, -SPRITE_SIZE.y)
		sprite.visible = false
		_node_rows[CrowdSim.row_of(i)].add_child(sprite)
		_sprites.append(sprite)


## A quad with its origin at the feet, like the sprites.
func _make_quad() -> ArrayMesh:
	var half: float = SPRITE_SIZE.x / 2.0
	var height: float = SPRITE_SIZE.y
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-half, -height), Vector2(half, -height), Vector2(half, 0.0), Vector2(-half, 0.0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A placeholder figure drawn in code, so the test needs no art file.
## It has a nose, so the facing direction shows.
func _make_texture(body: Color) -> ImageTexture:
	var image := Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(7, 12, 12, 16), body)  # torso
	image.fill_rect(Rect2i(7, 28, 5, 10), body.darkened(0.3))  # legs
	image.fill_rect(Rect2i(14, 28, 5, 10), body.darkened(0.3))
	image.fill_rect(Rect2i(9, 2, 9, 9), Color(0.9, 0.75, 0.6))  # head
	image.fill_rect(Rect2i(18, 6, 2, 2), Color(0.9, 0.75, 0.6))  # nose, facing right
	image.fill_rect(Rect2i(19, 16, 6, 3), body.lightened(0.3))  # arm, facing right
	return ImageTexture.create_from_image(image)


func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(4.0, 2.0)
	_label.add_theme_font_size_override("font_size", 8)
	_label.text = "measuring..."
	layer.add_child(_label)
	var help := Label.new()
	help.position = Vector2(4.0, 14.0)
	help.add_theme_font_size_override("font_size", 8)
	help.text = "1-5: enemies   Tab: nodes / multimesh\nmode, enemies, fps, logic ms, worst, sync ms, share of tick"
	layer.add_child(help)
