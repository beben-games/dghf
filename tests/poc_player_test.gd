extends SceneTree
## Checks the proof-of-concept fighter by feeding it scripted inputs, tick by tick.
## Run: godot --headless --path . -s tests/poc_player_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const L: int = Buttons.LEFT
const R: int = Buttons.RIGHT
const U: int = Buttons.UP
const D: int = Buttons.DOWN
const A: int = Buttons.LIGHT

var _failures: int = 0
var _projectiles: Projectiles


func _initialize() -> void:
	_test_walk()
	_test_jump()
	_test_crouch()
	_test_lane_change()
	_test_light_attack()
	_test_fireball()
	_test_fireball_facing_left()
	_test_buffered_press()
	_test_skin_timing()
	_projectiles.free()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


## A fighter in the middle lane at x 960 that will receive `samples`, one per tick.
func _fighter(samples: Array) -> Fighter:
	if _projectiles != null:
		_projectiles.free()
	var fighter := Fighter.new()
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.moves = [load("res://data/moves/poc/fireball.tres"), load("res://data/moves/poc/light.tres")]
	_projectiles = Projectiles.new()
	fighter.projectiles = _projectiles
	fighter.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, 960.0)
	return fighter


func _run(fighter: Fighter, ticks: int) -> void:
	for i in ticks:
		fighter.tick()
		_projectiles.tick()


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _repeat(mask: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(ticks)
	out.fill(mask)
	return out


func _test_walk() -> void:
	var f := _fighter(_repeat(R, 30) + _repeat(0, 2) + _repeat(L, 5))
	_run(f, 30)
	_check(f.state == Fighter.State.WALK, "walking right is the walk state")
	_check(is_equal_approx(f.x, 960.0 + 30 * f.walk_speed), "30 ticks right moves 30 walk steps")
	_run(f, 2)
	_check(f.state == Fighter.State.IDLE, "releasing the stick returns to idle")
	_run(f, 5)
	_check(f.facing == -1, "walking left faces left")
	f.free()


func _test_jump() -> void:
	var f := _fighter([U])
	_run(f, 1)
	_check(f.state == Fighter.State.JUMP, "up starts a jump")
	var peak: float = 0.0
	var ticks: int = 0
	while f.state == Fighter.State.JUMP and ticks < 200:
		_run(f, 1)
		peak = maxf(peak, f.height)
		ticks += 1
	_check(peak > 200.0, "the jump clears 200 pixels (got %.0f)" % peak)
	_check(ticks < 60, "the jump lands within a second (took %d ticks)" % ticks)
	_check(f.height == 0.0 and f.state == Fighter.State.IDLE, "landing returns to idle on the ground")
	_check(f.previous_state == Fighter.State.JUMP, "after landing, the state before idle is the jump")
	f.free()


func _test_crouch() -> void:
	var f := _fighter(_repeat(D, 5))
	_run(f, 5)
	_check(f.state == Fighter.State.CROUCH, "down crouches")
	_run(f, 1)
	_check(f.state == Fighter.State.IDLE, "releasing down stands up")
	f.free()


func _test_lane_change() -> void:
	var f := _fighter([Buttons.LANE_DOWN] + _repeat(0, 20) + [Buttons.LANE_DOWN] + _repeat(0, 20) + [Buttons.LANE_UP])
	_run(f, 1)
	_check(f.state == Fighter.State.LANE_CHANGE and f.lane == 2, "lane down heads for the front lane")
	_run(f, 20)
	_check(f.state == Fighter.State.IDLE and f.position.y == LANES[2], "the change ends on the front lane's line")
	_run(f, 21)
	_check(f.lane == 2 and f.state == Fighter.State.IDLE, "there is no lane below the front one")
	_run(f, 1)
	_check(f.lane == 1, "lane up goes back to the middle")
	f.free()


func _test_light_attack() -> void:
	var f := _fighter([A])
	_run(f, 1)
	_check(f.state == Fighter.State.ATTACK and f.move.animation == &"light", "attack alone is the light attack")
	_check(f.active_hit_rects().is_empty(), "the hitbox is not out on the first frame")
	_run(f, 9)
	var rects: Array[Rect2] = f.active_hit_rects()
	_check(rects.size() == 1 and rects[0].position.x > f.x, "the hitbox is out in front on frame 9")
	_run(f, 18)
	_check(f.state == Fighter.State.IDLE, "the light attack ends after its 27 frames")
	f.free()


func _test_fireball() -> void:
	var f := _fighter(_repeat(D, 3) + _repeat(D | R, 3) + _repeat(R, 2) + [R | A])
	_run(f, 9)
	_check(f.state == Fighter.State.ATTACK and f.move.animation == &"fireball", "down, down-forward, forward and attack is the fireball")
	_run(f, 20)
	_check(_projectiles.count() == 1, "the fireball spawns one projectile")
	_run(f, 200)
	_check(_projectiles.count() == 0, "the projectile is recycled once off screen")
	f.free()


func _test_fireball_facing_left() -> void:
	var f := _fighter(_repeat(L, 4) + _repeat(0, 30) + _repeat(D, 3) + _repeat(D | L, 3) + _repeat(L, 2) + [L | A])
	_run(f, 43)
	_check(f.move != null and f.move.animation == &"fireball", "the motion mirrors when facing left")
	# The same stick path while facing right is a backward motion: no fireball.
	var g := _fighter(_repeat(D, 3) + _repeat(D | L, 3) + [A])
	_run(g, 7)
	_check(g.move != null and g.move.animation == &"light", "a quarter circle backward gives the plain attack")
	f.free()
	g.free()


func _test_buffered_press() -> void:
	# Find how long a jump lasts, then press attack 4 ticks before landing.
	var probe := _fighter([U])
	var air: int = 0
	_run(probe, 1)
	while probe.state == Fighter.State.JUMP:
		_run(probe, 1)
		air += 1
	probe.free()
	var f := _fighter([U] + _repeat(0, air - 4) + [A])
	_run(f, 1 + air - 4 + 1)
	_check(f.state == Fighter.State.JUMP, "the attack is pressed while still in the air")
	_run(f, 6)
	_check(f.state == Fighter.State.ATTACK, "a press just before landing comes out on landing")
	f.free()


func _test_skin_timing() -> void:
	var skin := FighterSkin.new()
	skin.cell = Vector2(100.0, 50.0)
	skin.columns = 4
	skin.animations = {"land": {"frames": [5, 6], "ticks": 4, "loop": false}}
	_check(skin.duration(&"land") == 8, "an animation lasts its frames times its ticks")
	_check(skin.region(&"land", 0).position == Vector2(100.0, 50.0), "frame 5 of a 4-column sheet is the second cell of the second row")
	_check(skin.region(&"land", 100).position == Vector2(200.0, 50.0), "an animation that doesn't loop holds its last frame")
