extends SceneTree
## Checks the crowd (issue #48): the director's pool, spacing and attack
## tokens, the small fry's walk and jab, their deaths, and the player's health.
## Run: godot --headless --path . -s tests/crowd_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [900.0, 950.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const A: int = Buttons.LIGHT

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _crowd: CrowdDirector
var _player: Fighter


func _initialize() -> void:
	_test_spawn_and_approach()
	_test_tokens_and_damage()
	_test_death_and_pool()
	_test_player_dies()
	_test_spacing()
	_free_all()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _free_all() -> void:
	if _player != null:
		_player.free()
	if _crowd != null:
		_crowd.free()
	if _projectiles != null:
		_projectiles.free()
	_player = null
	_crowd = null
	_projectiles = null


## A player in the middle lane at `x`, fed `samples`, and an empty crowd aimed at it.
func _fight(x: float = 960.0, samples: Array = []) -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_player = Fighter.new()
	_player.max_health = 100
	_player.bounds = Vector2(120.0, 1800.0)
	_player.moves = [load("res://data/moves/poc/light.tres"), load("res://data/moves/poc/heavy.tres")]
	_player.projectiles = _projectiles
	_player.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, x)
	_player.set_lanes(LANES, SCALES)
	_crowd = CrowdDirector.new()
	_crowd.setup(LANES, SCALES, _player.bounds)
	_crowd.target = _player


func _run(ticks: int) -> void:
	for i in ticks:
		_player.tick()
		_crowd.tick()
		_combat.fighters = [_player]
		_combat.fighters.append_array(_crowd.alive())
		_projectiles.tick()
		_combat.resolve()


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _repeat(mask: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(ticks)
	out.fill(mask)
	return out


func _attacking() -> int:
	var n: int = 0
	for body in _crowd.alive():
		if body.state == Body.State.ATTACK:
			n += 1
	return n


func _test_spawn_and_approach() -> void:
	_fight()
	for i in 20:
		_crowd.spawn(i % 3, 200.0 + 60.0 * i if i % 2 == 0 else 1700.0 - 60.0 * i, 1)
	_check(_crowd.count() == 20, "twenty bodies spawn from the pool")
	_run(200)
	var near: int = 0
	for body in _crowd.alive():
		if absf(body.x - _player.x) < _crowd.reach + _crowd.spacing * 4:
			near += 1
	_check(near >= 15, "after 200 ticks most of the crowd has walked up to the player (%d of 20 near)" % near)
	var facing_right: bool = true
	for body in _crowd.alive():
		if (body.x < _player.x) != (body.facing == 1) and absf(body.x - _player.x) > 10.0:
			facing_right = false
	_check(facing_right, "each body faces the player")


func _test_tokens_and_damage() -> void:
	_fight()
	for i in 12:
		_crowd.spawn(1, 600.0 + 30.0 * i if i % 2 == 0 else 1300.0 - 30.0 * i, 1)
	var most: int = 0
	for i in 600:
		_run(1)
		most = maxi(most, _attacking())
	_check(most <= _crowd.attack_tokens and most > 0, "at most %d of the crowd attack at once (saw %d)" % [_crowd.attack_tokens, most])
	_check(_player.health < 100, "an idle player loses health to the jabs (%d left after 600 ticks)" % _player.health)


func _test_death_and_pool() -> void:
	# A player who swings every 40 ticks at one body standing in front.
	var presses: Array[int] = []
	for i in 12:
		presses.append(A)
		presses.append_array(_repeat(0, 39))
	_fight(600.0, presses)
	var body: CrowdBody = _crowd.spawn(1, 780.0, -1)
	body.rest = 10000  # it never swings back here
	_run(1)
	_run(60)
	_check(body.health < body.max_health, "a light hit takes health off a small fry (%d of %d)" % [body.health, body.max_health])
	var ticks: int = 0
	while _crowd.count() > 0 and ticks < 480:
		_run(1)
		ticks += 1
	_check(_crowd.count() == 0, "a few hits kill it and the director takes it back into the pool (after %d ticks)" % ticks)
	_check(_crowd.spawn(1, 900.0, -1) != null, "the pool hands it out again")


func _test_player_dies() -> void:
	_fight()
	for i in 6:
		_crowd.spawn(1, 700.0 + 100.0 * i, 1)
	_run(2400)
	_check(_player.health == 0 and _player.state == Fighter.State.DEAD, "a player who does nothing against six is beaten and ends dead (health %d, %s)" % [_player.health, Fighter.STATE_NAMES[_player.state]])
	_check(not _player.can_be_hit(), "a dead player can't be hit any more")


func _test_spacing() -> void:
	_fight()
	for i in 6:
		_crowd.spawn(1, 700.0, 1)
	_run(60)
	var closest: float = 9999.0
	var alive: Array[CrowdBody] = _crowd.alive()
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			closest = minf(closest, absf(alive[i].x - alive[j].x))
	_check(closest > _crowd.spacing * 0.5, "bodies spawned on one spot spread out along the lane (closest pair %.0f apart)" % closest)
