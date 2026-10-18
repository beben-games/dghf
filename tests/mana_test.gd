extends SceneTree
## Checks mana (issue #60): hits pay, blocked hits don't, spells cost and fall
## through to the next move when the bar can't pay, the super costs it all.
## Run: godot --headless --path . -s tests/mana_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const R: int = Buttons.RIGHT
const D: int = Buttons.DOWN
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _made: Array[Fighter] = []


func _initialize() -> void:
	_test_hits_pay()
	_test_blocked_hits_pay_nothing()
	_test_no_mana_no_fireball()
	_test_fireball_costs_and_pays_back()
	_test_super_costs_the_bar()
	_test_the_bar_is_capped()
	_free_all()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _free_all() -> void:
	for fighter in _made:
		fighter.free()
	_made.clear()
	if _projectiles != null:
		_projectiles.free()
	_projectiles = null
	_combat = null


func _clear() -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles


## A fighter with every move and a 100 bar holding `mana`, fed `samples` one per tick.
func _fighter(x: float, team: int, samples: Array = [], mana: int = 0) -> Fighter:
	var fighter := Fighter.new()
	fighter.team = team
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.max_mana = 100
	fighter.moves = [
		load("res://data/moves/poc/super_fireball.tres"),
		load("res://data/moves/poc/fireball_heavy.tres"),
		load("res://data/moves/poc/fireball.tres"),
		load("res://data/moves/poc/missiles_heavy.tres"),
		load("res://data/moves/poc/missiles_light.tres"),
		load("res://data/moves/poc/blast_heavy.tres"),
		load("res://data/moves/poc/blast_light.tres"),
		load("res://data/moves/poc/light_2.tres"), load("res://data/moves/poc/light.tres"),
		load("res://data/moves/poc/heavy.tres"),
	]
	fighter.projectiles = _projectiles
	fighter.setup(PlayerInput.new(team, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, x)
	fighter.mana = mana
	_combat.fighters.append(fighter)
	_made.append(fighter)
	return fighter


func _run(ticks: int) -> void:
	for i in ticks:
		for fighter in _combat.fighters:
			fighter.tick()
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


## Down, down-forward, forward: the fireball motion, without the button.
func _qcf() -> Array[int]:
	return _repeat(D, 3) + _repeat(D | R, 3) + _repeat(R, 2)


func _test_hits_pay() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	var target := _fighter(800.0, 2)
	_run(9)
	_check(attacker.mana == 6 and target.mana == 0, "a light that lands pays its attacker 6 (has %d), and the target nothing" % attacker.mana)
	_clear()
	attacker = _fighter(600.0, 1, [H])
	_fighter(800.0, 2)
	_run(30)
	_check(attacker.mana == 10, "a heavy pays 10 (has %d)" % attacker.mana)
	_clear()
	attacker = _fighter(600.0, 1, [A])
	_run(30)
	_check(attacker.mana == 0, "a swing that misses pays nothing")


func _test_blocked_hits_pay_nothing() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	var blocker := _fighter(800.0, 2, _repeat(Buttons.GUARD, 40))
	blocker.facing = -1
	_run(12)
	_check(blocker.state == Fighter.State.BLOCK and blocker.health == blocker.max_health, "the target blocks the light")
	_check(attacker.mana == 0, "a blocked hit pays nothing (has %d)" % attacker.mana)


func _test_no_mana_no_fireball() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, _qcf() + [R | A], 0)
	_run(9)
	_check(attacker.move != null and attacker.move.id == &"light", "with an empty bar the fireball motion gives the plain light (got %s)" % (attacker.move.id if attacker.move else &"nothing"))
	_check(_projectiles.count() == 0, "and no fireball leaves")
	_clear()
	attacker = _fighter(600.0, 1, _qcf() + [R | A], 19)
	_run(9)
	_check(attacker.move != null and attacker.move.id == &"light" and attacker.mana == 19, "one short of the cost is still too little, and nothing is taken")


func _test_fireball_costs_and_pays_back() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, _qcf() + [R | A], 20)
	var target := _fighter(1100.0, 2)
	_run(9)
	_check(attacker.move != null and attacker.move.id == &"fireball", "with 20 the fireball comes out")
	_check(attacker.mana == 0, "and costs 20 on starting (has %d)" % attacker.mana)
	var ticks: int = 0
	while target.combo_hits == 0 and ticks < 120:
		_run(1)
		ticks += 1
	_check(target.combo_hits == 1 and attacker.mana == 2, "its hit pays 2 back to the caster (has %d)" % attacker.mana)
	_clear()
	attacker = _fighter(600.0, 1, _qcf() + [R | H], 34)
	_run(9)
	_check(attacker.move != null and attacker.move.id == &"heavy" and attacker.mana == 34, "the heavy fireball's motion with 34 gives the plain heavy, since it costs 35 and the light fireball wants the other button (got %s, %d left)" % [attacker.move.id if attacker.move else &"nothing", attacker.mana])


func _test_super_costs_the_bar() -> void:
	_clear()
	var attacker := _fighter(400.0, 1, _qcf() + _qcf() + [R | H], 99)
	_run(18)
	_check(attacker.move != null and attacker.move.id == &"fireball_heavy" and attacker.mana == 64, "at 99 the super's motion gives the heavy fireball for 35 (got %s, %d left)" % [attacker.move.id if attacker.move else &"nothing", attacker.mana])
	_clear()
	attacker = _fighter(400.0, 1, _qcf() + _qcf() + [R | H], 100)
	var target := _fighter(900.0, 2)
	_run(18)
	_check(attacker.move != null and attacker.move.id == &"super_fireball" and attacker.mana == 0, "at 100 the super comes out and empties the bar (got %s, %d left)" % [attacker.move.id if attacker.move else &"nothing", attacker.mana])
	_run(200)
	_check(target.combo_hits == 1 and attacker.mana == 0, "the super's hit pays nothing back")


func _test_the_bar_is_capped() -> void:
	_clear()
	var fighter := _fighter(600.0, 1, [], 95)
	fighter.gain_mana(50)
	_check(fighter.mana == 100, "mana never goes past the bar")
	var enemy := _fighter(800.0, 2)
	enemy.max_mana = 0
	enemy.mana = 0
	enemy.gain_mana(50)
	_check(enemy.mana == 0, "a body with no bar gains nothing")
