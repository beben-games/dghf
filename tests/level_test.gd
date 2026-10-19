extends SceneTree
## Checks levels as data and the results (issue #62): the melee level loads
## with its arenas and waves, a wave's kinds are spread through it, hits taken
## count hits and not blocks, and the stage plays the level through to the
## results screen.
## Run: godot --headless --path . -s tests/level_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const A: int = Buttons.LIGHT
const G: int = Buttons.GUARD

var _failures: int = 0
var _made: Array[Node] = []


func _initialize() -> void:
	_test_the_melee_level_loads()
	_test_a_wave_spreads_its_kinds()
	_test_hits_taken_counts_hits_not_blocks()
	_stage_tests()


## The stage needs the tree running for its _ready, so this waits for the first frame.
func _stage_tests() -> void:
	await process_frame
	_test_the_level_plays_through_to_the_results()
	for node in _made:
		node.free()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _repeat(mask: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(ticks)
	out.fill(mask)
	return out


func _test_the_melee_level_loads() -> void:
	var level: Level = load("res://data/levels/melee.tres")
	_check(level != null and level.arenas.size() == 2 and level.stage_width == 5760.0, "the melee level loads with two arenas on a stage three screens wide")
	var totals: Array[int] = []
	for arena in level.arenas:
		for wave in arena.waves:
			totals.append(wave.total())
	_check(totals == [10, 10, 10, 15], "its waves are 10, 10, 10 and 15 small fry (%s)" % [totals])
	_check(level.arenas[0].right == 2400.0 and level.arenas[1].left == 3360.0, "with the arenas' walls where the melee had them")
	var arenas := Arenas.new()
	arenas.setup_level(level)
	_check(arenas.arenas.size() == 2 and arenas.stage_width == 5760.0 and arenas.limits() == Vector2(0.0, 2400.0), "the arenas take their walls and waves from the level")


func _test_a_wave_spreads_its_kinds() -> void:
	var level: Level = load("res://data/levels/melee.tres")
	var first: WaveData = level.arenas[0].waves[0]
	var fast: CrowdKind = load("res://data/enemies/fast.tres")
	var where: Array[int] = []
	for i in first.total():
		if first.kind_at(i) == fast:
			where.append(i)
	_check(where == [2, 7], "the two fast ones of a wave of ten come third and eighth, not last (%s)" % [where])
	var last: WaveData = level.arenas[1].waves[1]
	var counts: Dictionary = {}
	for i in last.total():
		var id: StringName = last.kind_at(i).id
		counts[id] = counts.get(id, 0) + 1
	_check(counts.get(&"small_fry", 0) == 8 and counts.get(&"fast", 0) == 3 and counts.get(&"shielded", 0) == 2 and counts.get(&"thrower", 0) == 2, "every body of a wave gets its kind, in the wave's counts (%s)" % [counts])
	_check(last.kind_at(0).id != last.kind_at(1).id or last.kind_at(1).id != last.kind_at(2).id, "and they are mixed from the start")


func _test_hits_taken_counts_hits_not_blocks() -> void:
	var projectiles := Projectiles.new()
	var combat := Combat.new()
	combat.projectiles = projectiles
	var attacker := Fighter.new()
	attacker.bounds = Vector2(120.0, 1800.0)
	attacker.moves = [load("res://data/moves/poc/light.tres")]
	attacker.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array([A] + _repeat(0, 40) + [A]))), LANES, 1, 600.0)
	var target := Fighter.new()
	target.team = 2
	target.max_health = 100
	target.bounds = attacker.bounds
	target.setup(PlayerInput.new(2, InputSource.Scripted.new(PackedInt32Array(_repeat(0, 20) + _repeat(G, 60)))), LANES, 1, 800.0)
	target.facing = -1
	combat.fighters = [attacker, target]
	for i in 70:
		attacker.tick()
		target.tick()
		projectiles.tick(combat.fighters)
		combat.resolve()
	_check(target.hits_taken == 1 and target.health == 90, "the first light lands and counts; the second, blocked, does not (taken %d, health %d)" % [target.hits_taken, target.health])
	target.setup(target.input, LANES, 1, 800.0)
	_check(target.hits_taken == 0, "placing the body again resets the count")
	attacker.free()
	target.free()
	projectiles.free()


func _test_the_level_plays_through_to_the_results() -> void:
	PocStage.mode = PocStage.Mode.MELEE
	var stage: PocStage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(stage)
	_made.append(stage)
	stage.players[0].input.source = InputSource.Held.new(Buttons.RIGHT)
	stage.tick()
	var kinds: Dictionary = {}
	for body in stage.crowd.alive():
		kinds[body.kind.id] = kinds.get(body.kind.id, 0) + 1
	_check(kinds.get(&"small_fry", 0) == 8 and kinds.get(&"fast", 0) == 2, "the melee's first wave is the level's: 8 plain and 2 fast (%s)" % [kinds])
	# Beat every wave by clearing the crowd now and then while walking right.
	var t: int = 1
	while not stage.results()["ticks"] == 0 and t < 4000 and not stage._arenas.done:
		t += 1
		if t % 150 == 0:
			stage.crowd.clear()
		stage.tick()
	_check(stage._arenas.done, "clearing the waves and walking on beats the level (after %d ticks)" % t)
	var r: Dictionary = stage.results()
	_check(r["ticks"] > 0 and r["ticks"] <= t and r["hits_taken"].size() == 1 and r["best_combo"] >= 0, "the results have the time, the hits each player took and the best combo (%s)" % [r])
	var clock: int = r["ticks"]
	for i in 30:
		stage.tick()
	_check(stage.results()["ticks"] == clock, "the clock stops on the clear")
	_check(stage._message.visible and stage._message.text == "LEVEL CLEAR" and stage._results.visible and "best combo" in stage._results.text, "and the results screen shows (%s)" % stage._results.text.replace("\\n", " / "))
