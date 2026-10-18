extends SceneTree
## Checks the camera and the arenas (issue #58): the follow and the look-ahead,
## the stage's ends, the player's bounds, and arenas that lock, send waves and
## open up when beaten.
## Run: godot --headless --path . -s tests/camera_test.gd
## Exits with 1 if any check fails.

const W: float = 1920.0

var _failures: int = 0
var _spawned: Array[int] = []


func _initialize() -> void:
	_test_follow_and_look_ahead()
	_test_stage_ends()
	_test_one_screen_stage_stands_still()
	_test_player_bounds_follow_the_view()
	_test_arenas_lock_send_waves_and_open()
	_test_no_arenas_is_a_free_camera()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _camera(width: float) -> StageCamera:
	var camera := StageCamera.new()
	camera.set_limits(0.0, width)
	camera.snap(W / 2.0)
	return camera


func _follow(camera: StageCamera, target_x: float, facing: int, ticks: int) -> void:
	for i in ticks:
		camera.tick(PackedFloat32Array([target_x]), facing)


func _spawn(how_many: int) -> void:
	_spawned.append(how_many)


func _test_follow_and_look_ahead() -> void:
	var camera := _camera(5760.0)
	_follow(camera, 2000.0, 1, 1)
	_check(camera.x > 960.0 and camera.x < 2120.0, "the camera eases toward the player rather than jumping (at %.0f after one tick)" % camera.x)
	_follow(camera, 2000.0, 1, 300)
	_check(absf(camera.x - 2120.0) < 1.0, "it settles on the player plus the look-ahead the way it faces (at %.0f)" % camera.x)
	_follow(camera, 2000.0, -1, 300)
	_check(absf(camera.x - 1880.0) < 1.0, "turning around moves the look-ahead to the other side (at %.0f)" % camera.x)
	_follow(camera, 3000.0, 1, 1)
	_check(absf(camera.position.x - camera.x) < 0.01 and camera.position.y == 540.0, "the node sits at the centre of the view")
	camera.free()


func _test_stage_ends() -> void:
	var camera := _camera(5760.0)
	_follow(camera, 100.0, -1, 300)
	_check(absf(camera.left()) < 0.01, "the view never shows past the stage's start (left edge at %.0f)" % camera.left())
	_follow(camera, 5700.0, 1, 600)
	_check(absf(camera.right() - 5760.0) < 0.01, "nor past its end (right edge at %.0f)" % camera.right())
	camera.free()


func _test_one_screen_stage_stands_still() -> void:
	var camera := _camera(W)
	_follow(camera, 1800.0, 1, 100)
	_check(camera.x == W / 2.0 and camera.left() == 0.0 and camera.right() == W, "a stage one screen wide keeps the camera still")
	camera.free()


func _test_player_bounds_follow_the_view() -> void:
	var camera := _camera(5760.0)
	camera.snap(3000.0)
	_check(camera.player_bounds(120.0) == Vector2(3000.0 - 960.0 + 120.0, 3000.0 + 960.0 - 120.0), "the player's bounds are the view less the margin")
	camera.snap(-500.0)
	_check(camera.x == 960.0, "a snap stays within the limits")
	camera.shake(10.0, 2)
	_check(camera.offset != Vector2.ZERO and camera.x == 960.0, "the shake is the camera's offset, not its place")
	camera.free()


func _test_arenas_lock_send_waves_and_open() -> void:
	var arenas := Arenas.new()
	arenas.setup(5760.0, [
		{"left": 0.0, "right": 2400.0, "waves": [10, 10]},
		{"left": 3360.0, "right": 5760.0, "waves": [5]},
	])
	var camera := _camera(5760.0)
	_spawned.clear()
	_check(arenas.limits() == Vector2(0.0, 2400.0), "before anything, the camera may go as far as the first arena's end")
	arenas.tick(1, camera.left(), camera.right(), 0, _spawn)
	_check(arenas.locked and arenas.index == 0, "the first arena locks as soon as the view is inside it")
	_check(_spawned == [10], "and sends its first wave at once (%s)" % [_spawned])
	_check(arenas.limits() == Vector2(0.0, 2400.0), "the camera's limits are the arena's walls")
	arenas.tick(2, camera.left(), camera.right(), 10, _spawn)
	_check(_spawned == [10], "no second wave while many stand")
	arenas.tick(3, camera.left(), camera.right(), 0, _spawn)
	_check(_spawned == [10] and arenas.locked, "an arena with waves left stays locked even when empty, and the next wave waits for the gap")
	arenas.tick(200, camera.left(), camera.right(), 4, _spawn)
	_check(_spawned == [10, 10], "the next wave comes when few are left (%s)" % [_spawned])
	arenas.tick(201, camera.left(), camera.right(), 7, _spawn)
	_check(arenas.locked, "the last wave keeps the lock while it stands")
	arenas.tick(400, camera.left(), camera.right(), 0, _spawn)
	_check(not arenas.locked and arenas.cleared == 1 and arenas.between(), "beaten, the arena opens")
	_check(arenas.limits() == Vector2(0.0, 5760.0), "up to the next arena's end (%s)" % arenas.limits())
	camera.set_limits(0.0, 5760.0)
	var locked_at: float = -1.0
	for t in range(401, 1000):
		_follow(camera, 5000.0, 1, 1)
		# Nobody stands until the second arena's wave has come.
		arenas.tick(t, camera.left(), camera.right(), 5 if _spawned.size() == 3 else 0, _spawn)
		if arenas.locked and locked_at < 0.0:
			locked_at = camera.left()
	_check(arenas.locked and arenas.index == 1, "the view inside the second arena locks it")
	_check(locked_at >= 3360.0 and locked_at < 3400.0, "right as the view's left edge passes its wall (at %.0f)" % locked_at)
	_check(_spawned == [10, 10, 5], "and its wave comes (%s)" % [_spawned])
	_check(arenas.limits() == Vector2(3360.0, 5760.0), "with the camera held within it")
	arenas.tick(1000, camera.left(), camera.right(), 0, _spawn)
	_check(arenas.done and not arenas.locked and not arenas.between(), "the stage is done once the last arena is beaten")
	arenas.reset()
	_check(not arenas.done and arenas.cleared == 0 and arenas.limits() == Vector2(0.0, 2400.0), "a reset starts over")
	camera.free()


func _test_no_arenas_is_a_free_camera() -> void:
	var arenas := Arenas.new()
	arenas.setup(5760.0, [])
	_spawned.clear()
	arenas.tick(1, 0.0, W, 0, _spawn)
	_check(not arenas.locked and not arenas.done and _spawned.is_empty() and arenas.limits() == Vector2(0.0, 5760.0), "with no arenas the whole stage is open and no wave comes")
