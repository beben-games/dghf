extends SceneTree
## Checks the guard bar (issue #72): blocked hits drain it, hits landed and a
## quiet moment refill it, the hit that empties it breaks through as a
## launcher, the guard can't be raised below the floor, and a fighter with no
## bar blocks forever.
## Run: godot --headless --path . -s tests/guard_bar_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const G: int = Buttons.GUARD

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _made: Array[Fighter] = []


func _initialize() -> void:
	_test_a_blocked_hit_drains_the_bar()
	_test_hits_landed_refill_it()
	_test_a_quiet_moment_refills_it_slowly()
	_test_the_emptying_hit_breaks_through()
	_test_no_guard_below_the_floor()
	_test_no_bar_never_breaks()
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


## A fighter with the normals and a guard bar of `bar` holding `guard`, fed `samples` one per tick.
func _fighter(x: float, team: int, samples: Array = [], bar: int = 100, guard: int = -1) -> Fighter:
	var fighter := Fighter.new()
	fighter.team = team
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.max_guard = bar
	fighter.max_health = 100
	fighter.moves = [load("res://data/moves/poc/light.tres"), load("res://data/moves/poc/heavy.tres")]
	fighter.projectiles = _projectiles
	fighter.setup(PlayerInput.new(team, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, x)
	if guard >= 0:
		fighter.guard = guard
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


## A blocker facing the attacker on its left, guard held for `ticks`.
func _blocker(samples: Array, bar: int = 100, guard: int = -1) -> Fighter:
	var blocker := _fighter(800.0, 2, samples, bar, guard)
	blocker.facing = -1
	return blocker


func _test_a_blocked_hit_drains_the_bar() -> void:
	_clear()
	_fighter(600.0, 1, [A])
	var blocker := _blocker(_repeat(G, 40))
	_run(12)
	_check(blocker.state == Fighter.State.BLOCK and blocker.health == blocker.max_health, "the light is blocked and does no damage")
	_check(blocker.guard == 90, "and drains the guard bar by its damage, 10 (bar at %d)" % blocker.guard)


func _test_hits_landed_refill_it() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A], 100, 50)
	_fighter(800.0, 2)
	_run(12)
	_check(attacker.guard == 65, "a hit landed pays 15 guard back (bar at %d)" % attacker.guard)
	_clear()
	attacker = _fighter(600.0, 1, [A], 100, 95)
	_fighter(800.0, 2)
	_run(12)
	_check(attacker.guard == 100, "and never past the bar")
	_clear()
	attacker = _fighter(600.0, 1, [A], 100, 50)
	_blocker(_repeat(G, 40))
	_run(12)
	_check(attacker.guard == 50, "a blocked hit pays nothing back")


func _test_a_quiet_moment_refills_it_slowly() -> void:
	_clear()
	var fighter := _fighter(600.0, 1, [], 100, 50)
	_run(60)
	_check(fighter.guard == 50, "nothing comes back during the first 60 quiet ticks (bar at %d)" % fighter.guard)
	_run(40)
	_check(fighter.guard == 60, "then 1 every 4 ticks (bar at %d after 40 more)" % fighter.guard)
	# Taking a hit starts the wait again.
	_clear()
	_fighter(600.0, 1, [A])
	fighter = _fighter(800.0, 2, [], 100, 50)
	_run(9)
	_run(60)
	_check(fighter.guard == 50, "a hit taken starts the wait over")


func _test_the_emptying_hit_breaks_through() -> void:
	# Three lights, each after the one before has recovered. The guard holds two and breaks on the third.
	_clear()
	var attacker := _fighter(600.0, 1, [A] + _repeat(0, 32) + [A] + _repeat(0, 32) + [A])
	var blocker := _blocker(_repeat(G, 200), 100, 30)
	_run(50)
	_check(blocker.state == Fighter.State.BLOCK and blocker.guard == 10 and blocker.health == 100, "two lights are blocked, leaving 10 (bar at %d, %s)" % [blocker.guard, Fighter.STATE_NAMES[blocker.state]])
	var ticks: int = 0
	while blocker.state == Fighter.State.BLOCK and ticks < 60:
		_run(1)
		ticks += 1
	_check(blocker.state == Fighter.State.LAUNCHED, "the third light breaks the guard: the blocker is launched (is %s)" % Fighter.STATE_NAMES[blocker.state])
	_check(blocker.health == 90 and blocker.guard == 0, "the hit lands in full and the bar is empty (health %d, guard %d)" % [blocker.health, blocker.guard])
	_check(blocker.just_broke and _combat.shake >= Combat.BREAK_SHAKE, "the break shakes the screen")
	_check(attacker.hitstop == 5, "the attacker freezes for the hit's full hitstop, not a block's (%d)" % attacker.hitstop)
	_run(1)
	_check(blocker.can_be_hit() and blocker.in_hit_reaction(), "in the air it can be juggled")
	_run(40)
	_check(blocker.state == Fighter.State.KNOCKDOWN, "and it lands knocked down (is %s)" % Fighter.STATE_NAMES[blocker.state])
	# One more point and the third light holds too.
	_clear()
	_fighter(600.0, 1, [A] + _repeat(0, 32) + [A] + _repeat(0, 32) + [A])
	blocker = _blocker(_repeat(G, 200), 100, 31)
	_run(100)
	_check(blocker.state == Fighter.State.BLOCK and blocker.guard == 1 and blocker.health == 100, "with 31 the third light is held, with 1 left (bar at %d, %s)" % [blocker.guard, Fighter.STATE_NAMES[blocker.state]])


func _test_no_guard_below_the_floor() -> void:
	_clear()
	_fighter(600.0, 1, [A])
	var blocker := _blocker(_repeat(G, 40), 100, 20)
	_run(5)
	_check(blocker.state != Fighter.State.BLOCK, "with 20 of 100 the guard can't be raised (is %s)" % Fighter.STATE_NAMES[blocker.state])
	_run(4)
	_check(blocker.state == Fighter.State.HITSTUN and blocker.health == 90, "and the light lands as a plain hit")
	_clear()
	blocker = _blocker(_repeat(G, 40), 100, 25)
	_run(5)
	_check(blocker.state == Fighter.State.BLOCK, "at the floor, 25, it can")


func _test_no_bar_never_breaks() -> void:
	_clear()
	_fighter(600.0, 1, [A])
	var blocker := _blocker(_repeat(G, 40), 0)
	_run(12)
	_check(blocker.state == Fighter.State.BLOCK and blocker.health == blocker.max_health and blocker.guard == 0, "a fighter with no bar blocks as before and never breaks")
