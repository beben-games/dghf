extends SceneTree
## Checks the boss (issue #67): its data, a bigger body, moves started by name
## that chain on hit, the grab that holds then throws through a guard, the
## tells, the brain's strings and its second phase, and the boss fight's bar,
## intro and K.O.
## Run: godot --headless --path . -s tests/boss_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [930.0, 965.0, 1000.0]
const SCALES: PackedFloat32Array = [0.72, 1.0, 1.28]
const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const G: int = Buttons.GUARD
const A: int = Buttons.LIGHT

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _made: Array[Node] = []


func _initialize() -> void:
	_test_the_kind_loads()
	_test_size_scales_the_body()
	_test_moves_start_by_name_and_chain_on_hit()
	_test_the_grab_holds_then_throws_through_a_guard()
	_test_tells()
	_test_the_brain_plays_strings_and_turns_at_half_health()
	_stage_tests()


func _stage_tests() -> void:
	await process_frame
	_test_the_boss_fight()
	_free_all()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _free_all() -> void:
	for node in _made:
		node.free()
	_made.clear()
	if _projectiles != null:
		_projectiles.free()
	_projectiles = null


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _repeat(mask: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(ticks)
	out.fill(mask)
	return out


func _kind() -> BossKind:
	return load("res://data/bosses/captain.tres")


## A fresh fight: a boss of the kind at `boss_x` facing left, and a knight at `knight_x` with a guard bar, fed `samples`.
func _fight(boss_x: float, knight_x: float, samples: Array = []) -> Array[Fighter]:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	var kind: BossKind = _kind()
	var boss := Fighter.new()
	boss.team = 2
	boss.max_health = kind.max_health
	boss.size = kind.size
	boss.walk_speed = kind.walk_speed
	boss.moves = kind.moves
	boss.bounds = Vector2(120.0, 1800.0)
	boss.projectiles = _projectiles
	boss.setup(PlayerInput.new(0, InputSource.new()), LANES, 2, boss_x)
	boss.set_lanes(LANES, SCALES)
	boss.facing = -1
	var knight := Fighter.new()
	knight.max_health = 100
	knight.max_guard = 100
	knight.bounds = boss.bounds
	knight.moves = [load("res://data/moves/poc/light.tres"), load("res://data/moves/poc/heavy.tres")]
	knight.projectiles = _projectiles
	knight.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 2, knight_x)
	knight.set_lanes(LANES, SCALES)
	_combat.fighters = [knight, boss]
	_made.append(boss)
	_made.append(knight)
	return [boss, knight]


func _run(pair: Array[Fighter], ticks: int) -> void:
	for i in ticks:
		for fighter in pair:
			fighter.tick()
		_projectiles.tick(_combat.fighters)
		_combat.resolve()


func _test_the_kind_loads() -> void:
	var kind: BossKind = _kind()
	_check(kind != null and kind.max_health == 600 and kind.size > 1.0 and kind.moves.size() == 5, "the Captain loads with its health, size and five moves")
	var ids: Array[StringName] = []
	for move in kind.moves:
		ids.append(move.id)
	_check(ids.has(&"boss_grab") and ids.has(&"boss_lunge") and ids.has(&"boss_shot"), "among them the grab, the lunge and the shot (%s)" % [ids])
	_check(kind.patterns.size() >= 2 and kind.patterns_two.size() >= 2, "with strings for both phases")


func _test_size_scales_the_body() -> void:
	var pair: Array[Fighter] = _fight(1300.0, 800.0)
	var boss: Fighter = pair[0]
	var knight: Fighter = pair[1]
	_check(boss.hurt_rect().size.y > knight.hurt_rect().size.y * 1.2, "the boss's hurtbox is bigger than the knight's (%.0f against %.0f)" % [boss.hurt_rect().size.y, knight.hurt_rect().size.y])
	_check(is_equal_approx(boss.depth_scale, SCALES[2] * boss.size), "its drawn size is the lane's times its own")


func _test_moves_start_by_name_and_chain_on_hit() -> void:
	var pair: Array[Fighter] = _fight(1000.0, 800.0)
	var boss: Fighter = pair[0]
	var knight: Fighter = pair[1]
	_check(not boss.start_move(boss.move_by_id(&"nothing")), "an unknown move does not start")
	_check(boss.start_move(boss.move_by_id(&"boss_light")) and boss.move.id == &"boss_light", "a move starts by name")
	_check(not boss.start_move(boss.move_by_id(&"boss_heavy")), "another can't start before the first has hit")
	var ticks: int = 0
	while knight.combo_hits == 0 and ticks < 40:
		_run(pair, 1)
		ticks += 1
	_check(knight.combo_hits == 1, "the light lands")
	_run(pair, boss.hitstop + 1)
	_check(boss.start_move(boss.move_by_id(&"boss_heavy")) and boss.move.id == &"boss_heavy", "and the heavy chains on the hit")


func _test_the_grab_holds_then_throws_through_a_guard() -> void:
	# The knight holds its guard toward the boss; the grab is not stopped, not a break: a hold, then a throw.
	var pair: Array[Fighter] = _fight(960.0, 800.0, _repeat(G, 200))
	var boss: Fighter = pair[0]
	var knight: Fighter = pair[1]
	_run(pair, 3)
	_check(knight.state == Fighter.State.BLOCK, "the knight guards")
	boss.start_move(boss.move_by_id(&"boss_grab"))
	var ticks: int = 0
	while not knight.held() and ticks < 60:
		_run(pair, 1)
		ticks += 1
	_check(knight.held() and knight.health == 80 and knight.guard == 100, "the grab goes through the guard without breaking it and holds the knight (health %d, guard %d, %s)" % [knight.health, knight.guard, Fighter.STATE_NAMES[knight.state]])
	var held_x: float = knight.x
	_run(pair, 20)
	_check(knight.held() and knight.x == held_x, "held where it stands")
	ticks = 0
	while knight.held() and ticks < 60:
		_run(pair, 1)
		ticks += 1
	_run(pair, 2)
	_check(knight.state == Fighter.State.LAUNCHED and knight.x < held_x, "then thrown: launched away (%s, %.0f from %.0f)" % [Fighter.STATE_NAMES[knight.state], knight.x, held_x])
	_run(pair, 60)
	_check(knight.state == Fighter.State.KNOCKDOWN or knight.state == Fighter.State.GETUP or knight.state == Fighter.State.IDLE, "and it lands as from any launch")


func _test_tells() -> void:
	var pair: Array[Fighter] = _fight(1500.0, 300.0)
	var boss: Fighter = pair[0]
	for id in [&"boss_heavy", &"boss_grab", &"boss_lunge", &"boss_shot"]:
		boss.state = Fighter.State.IDLE
		boss.move = null
		boss.start_move(boss.move_by_id(id))
		var tell: int = 0
		for i in 80:
			if boss.telegraphing():
				tell += 1
			_run(pair, 1)
		_check(tell >= 20, "the %s shows its tell for at least 20 ticks (%d)" % [id, tell])
	boss.state = Fighter.State.IDLE
	boss.move = null
	boss.start_move(boss.move_by_id(&"boss_light"))
	_check(not boss.telegraphing(), "the light has no tell")


func _test_the_brain_plays_strings_and_turns_at_half_health() -> void:
	var pair: Array[Fighter] = _fight(1400.0, 700.0)
	var boss: Fighter = pair[0]
	var knight: Fighter = pair[1]
	var brain := BossBrain.new(3)
	brain.fighter = boss
	brain.kind = _kind()
	brain.targets = [knight]
	boss.input.source = brain
	_run(pair, 600)
	_check(knight.health < 100, "the brain closes in and lands hits (health %d)" % knight.health)
	_check(brain.started.size() >= 2 and not brain.started.has(&"boss_lunge"), "it has played strings, with no lunge in the first phase (%s)" % [brain.started])
	_check(brain.phase() == 1, "still the first phase at full health")
	boss.health = int(boss.max_health * 0.4)
	knight.health = 100
	knight.x = boss.x - 200.0
	brain.started.clear()
	_run(pair, 900)
	_check(brain.phase() == 2, "at under half health the second phase")
	_check(brain.started.has(&"boss_lunge"), "with the lunge among its strings (%s)" % [brain.started])


func _test_the_boss_fight() -> void:
	PocStage.mode = PocStage.Mode.BOSS_FIGHT
	var stage: PocStage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(stage)
	_made.append(stage)
	_check(stage.boss != null and stage.boss.max_health == 600 and stage.boss.size > 1.0 and stage.boss.input.source is BossBrain, "the boss fight has the boss, with its brain")
	stage.tick()
	_check(stage._boss_bar.visible and stage._boss_name.text == PocStage.BOSS.title and stage._message.visible and stage._message.text == PocStage.BOSS.title.to_upper(), "its bar, its name and the intro show")
	for i in 130:
		stage.tick()
	_check(not stage._message.visible or stage._message.text != "FIGHT", "the intro ends")
	var hit := HitBox.new()
	hit.damage = 1000
	hit.hitstop = 2
	stage.boss.take_hit(hit, -1)
	for i in 80:
		stage.tick()
	_check(stage.boss.state == Fighter.State.DEAD and stage._message.visible and stage._message.text.begins_with("K.O.") and not stage._boss_bar.visible, "when it falls: K.O., and the bar goes (%s)" % stage._message.text)
