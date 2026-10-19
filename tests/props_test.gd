extends SceneTree
## Checks barrels and potions (issue #64): two hits break a barrel through its
## states and drop a potion, hitting it counts for nothing, a player walking
## over the potion heals, a broken barrel can't be hit and goes back to the
## pool, and the melee's arenas have barrels.
## Run: godot --headless --path . -s tests/props_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const A: int = Buttons.LIGHT
const R: int = Buttons.RIGHT

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _props: Props
var _player: Fighter
var _made: Array[Node] = []


func _initialize() -> void:
	_test_two_hits_break_a_barrel_and_drop_a_potion()
	_test_the_potion_heals_the_player_who_walks_over_it()
	_test_a_broken_barrel_goes_back_to_the_pool()
	_stage_tests()


func _stage_tests() -> void:
	await process_frame
	_test_the_melee_has_barrels()
	_free_all()
	for node in _made:
		node.free()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _free_all() -> void:
	if _player != null:
		_player.free()
	if _props != null:
		_props.free()
	if _projectiles != null:
		_projectiles.free()
	_player = null
	_props = null
	_projectiles = null


## A player at `x` with a 100 bar of health holding `health`, fed `samples`, and the props pool.
func _fight(x: float, samples: Array = [], health: int = 100) -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_player = Fighter.new()
	_player.max_health = 100
	_player.max_mana = 100
	_player.bounds = Vector2(120.0, 1800.0)
	_player.moves = [load("res://data/moves/poc/light.tres")]
	_player.projectiles = _projectiles
	_player.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, x)
	_player.set_lanes(LANES, SCALES)
	_player.health = health
	_player.mana = 0
	_props = Props.new()
	_props.setup(LANES, SCALES)


func _run(ticks: int) -> void:
	for i in ticks:
		_player.tick()
		_props.tick([_player])
		_combat.fighters = [_player]
		_combat.fighters.append_array(_props.alive())
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


func _test_two_hits_break_a_barrel_and_drop_a_potion() -> void:
	_fight(600.0, [A] + _repeat(0, 34) + [A])
	var barrel: Prop = _props.spawn(Prop.Kind.BARREL, 1, 800.0)
	_run(12)
	_check(barrel.hits_left == 1 and not barrel.broken() and barrel.flash_ticks > 0, "the first light cracks the barrel (hits left %d)" % barrel.hits_left)
	_check(_combat.combo_of(_player) == 0 and _player.mana == 0, "and counts for nothing: no combo, no mana")
	_check(_props.count() == 1, "no potion yet")
	_run(40)
	_check(barrel.broken(), "the second light breaks it")
	var potion: Prop = null
	for prop in _props.alive():
		if not prop.is_barrel():
			potion = prop
	_check(potion != null and potion.x == 800.0 and potion.lane == 1, "and a potion drops where it stood")
	_check(not barrel.can_be_hit(), "a broken barrel can't be hit")


func _test_the_potion_heals_the_player_who_walks_over_it() -> void:
	_fight(600.0, _repeat(R, 60), 60)
	_props.spawn(Prop.Kind.HEALTH, 1, 800.0)
	var other_lane: Prop = _props.spawn(Prop.Kind.HEALTH, 0, 700.0)
	_run(60)
	_check(_player.health == 85, "walking over the potion heals 25 (health %d)" % _player.health)
	_check(_props.count() == 1 and _props.alive()[0] == other_lane, "the potion is gone, the one in another lane stays")
	_fight(780.0, [], 100)
	_props.spawn(Prop.Kind.HEALTH, 1, 800.0)
	_run(2)
	_check(_player.health == 100 and _props.count() == 0, "a full player picks it up too, capped at full")


func _test_a_broken_barrel_goes_back_to_the_pool() -> void:
	_fight(600.0)
	var barrel: Prop = _props.spawn(Prop.Kind.BARREL, 1, 800.0)
	var hit := HitBox.new()
	hit.hitstop = 4
	barrel.take_hit(hit, 1)
	barrel.take_hit(hit, 1)
	_run(1)
	_check(barrel.broken() and _props.count() == 2, "broken by hand it still drops its potion")
	_run(Prop.GONE_AFTER + 5)
	_check(_props.count() == 1 and not _props.alive().has(barrel), "after a moment the broken barrel is gone and back in the pool")
	for i in 30:
		_props.spawn(Prop.Kind.BARREL, 1, 300.0 + 40.0 * i)
	_check(_props.count() == _props.capacity, "the pool never gives out more than it holds")


func _test_the_melee_has_barrels() -> void:
	PocStage.mode = PocStage.Mode.MELEE
	var stage: PocStage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(stage)
	_made.append(stage)
	_check(stage.props.barrels() == 5, "the melee's arenas place five barrels from the level data (%d)" % stage.props.barrels())
	stage.tick()
	_check(stage._combat.fighters.has(stage.props.alive()[0]), "and the barrels are among the bodies hits resolve against")
	PocStage.mode = PocStage.Mode.SANDBOX
	var sandbox: PocStage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(sandbox)
	_made.append(sandbox)
	_check(sandbox.props.count() == 0, "the sandbox starts with none")
