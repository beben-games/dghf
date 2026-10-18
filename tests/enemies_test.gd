extends SceneTree
## Checks the kinds of small fry (issue #61): a fast one is quick and weak, a
## shielded one blocks from the front until its shield breaks, the shield bash
## is telegraphed and breaks a raised guard, a thrower keeps back and throws,
## and a wave mixes them.
## Run: godot --headless --path . -s tests/enemies_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [900.0, 950.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const G: int = Buttons.GUARD

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _crowd: CrowdDirector
var _player: Fighter
var _stage: PocStage


func _initialize() -> void:
	_test_kinds_load()
	_test_fast_is_quick_and_weak()
	_test_shield_blocks_from_the_front_until_it_breaks()
	_test_bash_is_telegraphed_and_breaks_a_guard()
	_test_thrower_keeps_back_and_throws()
	_stage_tests()


## The stage needs the tree running for its _ready, so this waits for the first frame.
func _stage_tests() -> void:
	await process_frame
	_test_waves_mix_the_kinds()
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
	if _stage != null:
		_stage.free()
	_player = null
	_crowd = null
	_projectiles = null
	_stage = null


## A player in the middle lane at `x` with a guard bar, fed `samples`, facing `face`, and an empty crowd aimed at it.
func _fight(x: float = 960.0, samples: Array = [], face: int = 1) -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_player = Fighter.new()
	_player.max_health = 100
	_player.max_guard = 100
	_player.bounds = Vector2(120.0, 1800.0)
	_player.moves = [load("res://data/moves/poc/light.tres"), load("res://data/moves/poc/heavy.tres")]
	_player.projectiles = _projectiles
	_player.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, x)
	_player.set_lanes(LANES, SCALES)
	_player.facing = face
	_crowd = CrowdDirector.new()
	_crowd.projectiles = _projectiles
	_crowd.setup(LANES, SCALES, _player.bounds)
	_crowd.targets = [_player]


func _run(ticks: int) -> void:
	for i in ticks:
		_player.tick()
		_crowd.tick()
		_combat.fighters = [_player]
		_combat.fighters.append_array(_crowd.alive())
		_projectiles.tick(_combat.fighters)
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


func _kind(name: String) -> CrowdKind:
	return load("res://data/enemies/%s.tres" % name)


func _test_kinds_load() -> void:
	var plain: CrowdKind = _kind("small_fry")
	var fast: CrowdKind = _kind("fast")
	var shielded: CrowdKind = _kind("shielded")
	var thrower: CrowdKind = _kind("thrower")
	_check(plain != null and fast != null and shielded != null and thrower != null, "the four kinds load")
	_check(fast.walk_speed > plain.walk_speed and fast.max_health < plain.max_health, "the fast one is quicker and weaker than the plain one")
	_check(shielded.shield > 0 and shielded.special != null and shielded.special.hit_boxes[0].breaks_guard, "the shielded one has a shield and a guard-breaking special")
	_check(thrower.attack.projectile_frame >= 0 and thrower.reach > plain.reach and thrower.keep_away > 0.0, "the thrower throws and keeps back")
	_check(shielded.special.hit_boxes[0].first_frame >= 30, "the bash is telegraphed: %d ticks of wind-up" % shielded.special.hit_boxes[0].first_frame)


func _test_fast_is_quick_and_weak() -> void:
	_fight()
	_crowd.passive = true
	var plain: CrowdBody = _crowd.spawn(0, 300.0, 1)
	var fast: CrowdBody = _crowd.spawn(2, 300.0, 1, _kind("fast"))
	_crowd.passive = false
	_run(60)
	_check(fast.x - 300.0 > (plain.x - 300.0) * 1.5, "the fast one covers much more ground in a second (%d against %d)" % [int(fast.x - 300.0), int(plain.x - 300.0)])
	_check(fast.max_health == 15 and fast.health == 15 and plain.health == 30, "and has half the health")


func _test_shield_blocks_from_the_front_until_it_breaks() -> void:
	# Lights from the front: blocked, the shield drains 10 a hit, health untouched.
	_fight(600.0, [A] + _repeat(0, 32) + [A])
	var shielded: CrowdBody = _crowd.spawn(1, 800.0, -1, _kind("shielded"))
	_crowd.passive = true
	_run(12)
	_check(shielded.health == 40 and shielded.shield == 30 and shielded.state != Body.State.HITSTUN, "a light from the front is blocked: no damage, the shield drains 10 (health %d, shield %d, %s)" % [shielded.health, shielded.shield, Body.STATE_NAMES[shielded.state]])
	_run(40)
	_check(shielded.shield == 20 and shielded.health == 40, "and again (shield %d)" % shielded.shield)
	# From behind it lands.
	_fight(1000.0, [A], -1)
	shielded = _crowd.spawn(1, 800.0, -1, _kind("shielded"))
	_crowd.passive = true
	_run(12)
	_check(shielded.health < 40 and shielded.shield == 40, "a hit in the back lands and leaves the shield alone (health %d)" % shielded.health)
	# Two heavies: the first is held with 18 left, the second breaks the shield and launches.
	_fight(600.0, [H] + _repeat(0, 50) + [H])
	shielded = _crowd.spawn(1, 800.0, -1, _kind("shielded"))
	_crowd.passive = true
	_run(30)
	_check(shielded.shield == 18 and shielded.health == 40, "a heavy is held with 18 of the shield left (shield %d, health %d)" % [shielded.shield, shielded.health])
	var ticks: int = 0
	while shielded.state != Body.State.LAUNCHED and ticks < 80:
		_run(1)
		ticks += 1
	_check(shielded.state == Body.State.LAUNCHED and shielded.shield == 0 and shielded.health == 18, "the second heavy breaks it: launched, shield gone, 22 taken (%s, shield %d, health %d)" % [Body.STATE_NAMES[shielded.state], shielded.shield, shielded.health])


func _test_bash_is_telegraphed_and_breaks_a_guard() -> void:
	# A shielded body that always bashes, against a player holding its guard toward it.
	_fight(800.0, _repeat(G, 400), 1)
	var kind: CrowdKind = _kind("shielded").duplicate()
	kind.special_one_in = 1
	var basher: CrowdBody = _crowd.spawn(1, 960.0, -1, kind)
	var saw_tell: int = 0
	var ticks: int = 0
	_run(2)
	_check(_player.state == Fighter.State.BLOCK, "the player raises its guard")
	while _player.state == Fighter.State.BLOCK and ticks < 400:
		_run(1)
		ticks += 1
		if basher.telegraphing():
			saw_tell += 1
	_check(saw_tell >= 30, "the bash shows its tell for at least 30 ticks first (%d)" % saw_tell)
	_check(_player.state == Fighter.State.LAUNCHED and _player.guard == 0 and _player.health == 88, "and breaks the raised guard: the player is launched with the bar emptied and 12 taken (%s, guard %d, health %d)" % [Fighter.STATE_NAMES[_player.state], _player.guard, _player.health])
	# The same bash on a player who dodges through it misses.
	_fight(800.0, _repeat(0, 40) + [Buttons.DODGE | Buttons.LEFT] + _repeat(Buttons.LEFT, 10), 1)
	basher = _crowd.spawn(1, 960.0, -1, kind)
	_run(70)
	_check(_player.health == 100 or _player.state != Fighter.State.LAUNCHED, "a player who reads the tell and dodges is not broken (health %d, %s)" % [_player.health, Fighter.STATE_NAMES[_player.state]])


func _test_thrower_keeps_back_and_throws() -> void:
	_fight(600.0)
	var thrower: CrowdBody = _crowd.spawn(1, 1500.0, -1, _kind("thrower"))
	var nearest: float = INF
	var rocks: int = 0
	for i in 400:
		_run(1)
		nearest = minf(nearest, thrower.x - _player.x)
		rocks = maxi(rocks, _projectiles.count())
	_check(nearest >= 400.0, "the thrower never comes nearer than its reach (nearest %d)" % int(nearest))
	_check(rocks > 0 and _player.health < 100, "and its rocks fly and hit (%d in the air at most, health %d)" % [rocks, _player.health])
	# Walk up to it: it backs off.
	_fight(600.0, _repeat(Buttons.RIGHT, 150))
	thrower = _crowd.spawn(1, 1000.0, -1, _kind("thrower"))
	_run(150)
	_check(thrower.x > 1000.0, "a player closing in makes it back off (to %d)" % int(thrower.x))


func _test_waves_mix_the_kinds() -> void:
	_free_all()
	PocStage.mode = PocStage.Mode.SANDBOX
	_stage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(_stage)
	_check(_stage.camera != null and _stage.crowd != null, "the stage is ready once added (camera %s, crowd %s)" % [_stage.camera, _stage.crowd])
	_stage.spawn_wave(10)
	var ids: Dictionary = {}
	for body in _stage.crowd.alive():
		ids[body.kind.id] = ids.get(body.kind.id, 0) + 1
	_check(ids.get(&"small_fry", 0) >= 5 and ids.get(&"fast", 0) >= 1 and ids.get(&"shielded", 0) >= 1 and ids.get(&"thrower", 0) >= 1, "a wave of ten is mostly plain with the three others mixed in (%s)" % [ids])
	for body in _stage.crowd.alive():
		_check(body.projectiles != null, "every body has somewhere to throw")
		break
