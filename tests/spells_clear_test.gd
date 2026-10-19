extends SceneTree
## Spells that clear (issue #95): the heavy spells hit hard, wide and launch,
## the super sweeps every lane, and a launched body carries the neighbours it
## flies into (the knock-ons of #63). The kills are checked against today's
## numbers (a heavy spell's damage against the first level's small fry), never
## as a rule: Ben's correction on the issue, 2026-10-18.
## Run: godot --headless --path . -s tests/spells_clear_test.gd --quit-after 8000
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [900.0, 950.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const D: int = Buttons.DOWN
const R: int = Buttons.RIGHT
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const QCF: Array[int] = [D, D, D | R, D | R, R]
const BLAST_H: Array[int] = [D, 0, D | H]

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _crowd: CrowdDirector
var _player: Fighter
var _made: Array[Fighter] = []


func _initialize() -> void:
	_test_heavy_fireball_goes_through_a_lane()
	_test_a_shield_stops_the_heavy_fireball()
	_test_heavy_blast_shoves_through_a_shield_and_kills_by_the_numbers()
	_test_heavy_missiles_launch_three()
	_test_super_sweeps_every_lane_in_front()
	_test_heavy_launches_lift_the_captain()
	_test_a_launched_body_carries_its_neighbours()
	_test_an_uppercut_carries_nobody()
	_test_a_carry_stays_in_its_lane_and_off_the_players()
	_test_combo_pays_a_heavy_spell()
	_free_all()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _free_all() -> void:
	for fighter in _made:
		fighter.free()
	_made.clear()
	if _crowd != null:
		_crowd.free()
	if _projectiles != null:
		_projectiles.free()
	_player = null
	_crowd = null
	_projectiles = null


## A player at `x` in the middle lane with every spell, a full bar, and a passive crowd.
func _fight(samples: Array = [], x: float = 960.0) -> Fighter:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_crowd = CrowdDirector.new()
	_crowd.setup(LANES, SCALES, Vector2(120.0, 1800.0))
	_crowd.passive = true
	_crowd.projectiles = _projectiles
	_player = _fighter(x, 1, samples)
	_player.max_health = 100
	_player.health = 100
	_crowd.targets = [_player]
	return _player


func _fighter(x: float, team: int, samples: Array = [], lane: int = 1) -> Fighter:
	var fighter := Fighter.new()
	fighter.team = team
	fighter.bounds = Vector2(120.0, 1800.0)
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
	fighter.max_mana = 100
	fighter.setup(PlayerInput.new(team, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, lane, x)
	fighter.set_lanes(LANES, SCALES)
	fighter.mana = 100
	_made.append(fighter)
	return fighter


func _run(ticks: int) -> void:
	for i in ticks:
		for fighter in _made:
			fighter.tick()
		_crowd.tick()
		_combat.fighters.assign(_made)
		_combat.fighters.append_array(_crowd.alive())
		_projectiles.tick(_combat.fighters)
		_combat.resolve()


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _move(id: String) -> Move:
	return load("res://data/moves/poc/%s.tres" % id)


func _kind(id: String) -> CrowdKind:
	return load("res://data/enemies/%s.tres" % id)


## In the air or down after a launch: hit by something that lifted it.
func _lifted(body: Body) -> bool:
	return body.state == Body.State.LAUNCHED or body.state == Body.State.KNOCKDOWN or body.state == Body.State.DEAD


func _test_heavy_fireball_goes_through_a_lane() -> void:
	_fight(QCF + [R | H])
	var line: Array[CrowdBody] = [_crowd.spawn(1, 1300.0, -1), _crowd.spawn(1, 1450.0, -1), _crowd.spawn(1, 1600.0, -1)]
	var beside: CrowdBody = _crowd.spawn(0, 1450.0, -1)
	_run(6)
	_check(_player.move != null and _player.move.id == &"fireball_heavy", "the fireball motion with heavy is the heavy fireball (got %s)" % (_player.move.id if _player.move else &"nothing"))
	_run(80)
	var damage: int = _move("fireball_heavy").projectile_hit.damage
	# The first one it launches flies faster than the fireball and bowls the next before the
	# fireball reaches it (the carries below), so a body may be hit more than once: by the
	# fireball at least.
	for body in line:
		_check(body.hits_taken >= 1 and _lifted(body), "a body at %d in its lane is hit and launched (%d hits, %s)" % [int(body.x), body.hits_taken, Body.STATE_NAMES[body.state]])
		_check(body.health <= maxi(_kind("small_fry").max_health - damage, 0), "and takes at least the heavy's %d (health %d)" % [damage, body.health])
	_check(line[0].hits_taken == 1 and line[0].health == maxi(_kind("small_fry").max_health - damage, 0), "the first takes the fireball alone, %d (health %d, %d hits)" % [damage, line[0].health, line[0].hits_taken])
	_check(line[0].is_dying() == (damage >= _kind("small_fry").max_health), "which kills a plain small fry today by the numbers, not by rule (%d against %d)" % [damage, _kind("small_fry").max_health])
	_check(beside.hits_taken == 0, "the lane beside is untouched")
	_check(_projectiles.count() == 1, "and the fireball flies on (%d left)" % _projectiles.count())
	_check(_player.mana == 100 - _move("fireball_heavy").mana_cost + 3 * line.size(), "it cost %d and paid 3 a body (mana %d)" % [_move("fireball_heavy").mana_cost, _player.mana])


func _test_a_shield_stops_the_heavy_fireball() -> void:
	_fight(QCF + [R | H])
	var shielded: CrowdBody = _crowd.spawn(1, 1300.0, -1, _kind("shielded"))
	_run(70)
	_check(shielded.hits_taken == 0 and shielded.health == _kind("shielded").max_health and not _lifted(shielded), "a raised shield stops what flies at it (%d hits, health %d, %s)" % [shielded.hits_taken, shielded.health, Body.STATE_NAMES[shielded.state]])
	_check(shielded.shield == _kind("shielded").shield - _move("fireball_heavy").projectile_hit.damage, "and the shield pays its damage (%d left)" % shielded.shield)


func _test_heavy_blast_shoves_through_a_shield_and_kills_by_the_numbers() -> void:
	_fight(BLAST_H)
	var shielded: CrowdBody = _crowd.spawn(1, 1150.0, -1, _kind("shielded"))
	var plain: CrowdBody = _crowd.spawn(1, 770.0, 1)
	var far_lane: CrowdBody = _crowd.spawn(2, 1250.0, -1)
	_run(40)
	var damage: int = _move("blast_heavy").projectile_hit.damage
	_check(_lifted(shielded) and shielded.shield == _kind("shielded").shield, "a shield bearer facing the heavy blast is launched and keeps its shield (%s, shield %d)" % [Body.STATE_NAMES[shielded.state], shielded.shield])
	_check(shielded.health == _kind("shielded").max_health - damage and not shielded.is_dying(), "and takes %d, alive (health %d)" % [damage, shielded.health])
	_check(_lifted(plain) and plain.is_dying() == (damage >= _kind("small_fry").max_health), "the plain one behind is launched, dying today by the numbers (%s, health %d)" % [Body.STATE_NAMES[plain.state], plain.health])
	_check(_lifted(far_lane), "the one in the lane beside, 290 pixels off, is in the blast's reach")
	_check(_player.mana == 100 - _move("blast_heavy").mana_cost + 3 * 3, "it cost %d and paid 3 a body (mana %d)" % [_move("blast_heavy").mana_cost, _player.mana])


func _test_heavy_missiles_launch_three() -> void:
	_fight([R, R, R | D, R | D, R | H])
	var targets: Array[CrowdBody] = [_crowd.spawn(0, 1500.0, -1), _crowd.spawn(1, 1500.0, -1), _crowd.spawn(2, 1500.0, -1)]
	_run(6)
	_check(_player.move != null and _player.move.id == &"missiles_heavy", "forward, down-forward and heavy is the heavy missiles (got %s)" % (_player.move.id if _player.move else &"nothing"))
	_run(150)
	var launched: int = 0
	for body in targets:
		if _lifted(body) and body.hits_taken == 1:
			launched += 1
	_check(launched == 3, "three missiles find three bodies across the lanes and launch each (%d)" % launched)
	_check(targets[1].health == _kind("small_fry").max_health - _move("missiles_heavy").projectile_hit.damage, "each taking a missile's %d (health %d)" % [_move("missiles_heavy").projectile_hit.damage, targets[1].health])


func _test_super_sweeps_every_lane_in_front() -> void:
	_fight(QCF + QCF + [R | H], 500.0)
	var ahead: Array[CrowdBody] = [_crowd.spawn(0, 900.0, -1), _crowd.spawn(1, 1200.0, -1), _crowd.spawn(2, 1500.0, -1), _crowd.spawn(1, 1700.0, -1)]
	var shielded: CrowdBody = _crowd.spawn(1, 1000.0, -1, _kind("shielded"))
	var behind: CrowdBody = _crowd.spawn(1, 300.0, 1)
	_run(11)
	_check(_player.move != null and _player.move.id == &"super_fireball", "the fireball motion twice with heavy is the super (got %s)" % (_player.move.id if _player.move else &"nothing"))
	_check(_player.mana == 0, "and empties the bar")
	_run(160)
	for body in ahead:
		_check(body.hits_taken == 1 and _lifted(body), "a body at %d in lane %d is swept (%d hits, %s)" % [int(body.x), body.lane, body.hits_taken, Body.STATE_NAMES[body.state]])
	_check(shielded.hits_taken == 1 and _lifted(shielded), "nothing stops it: the shield bearer is swept too (%d hits, %s)" % [shielded.hits_taken, Body.STATE_NAMES[shielded.state]])
	_check(behind.hits_taken == 0, "the one behind the knight is not")
	_check(ahead[1].x > 1200.0, "and it pushes along its flight, not back toward the knight (%d)" % int(ahead[1].x))


func _test_heavy_launches_lift_the_captain() -> void:
	var resist: float = load("res://data/bosses/captain.tres").launch_resist
	for id in ["fireball_heavy", "missiles_heavy", "blast_heavy", "super_fireball"]:
		_check(_move(id).projectile_hit.launch > resist, "%s launches above the Captain's resist of %d (%d)" % [id, resist, _move(id).projectile_hit.launch])
	_check(_move("blast_light").projectile_hit.launch <= resist, "the light blast still pushes it")
	_check(Combat.CARRY.launch <= resist, "and a body bowled into it never lifts it (carry launch %d)" % Combat.CARRY.launch)


func _test_a_launched_body_carries_its_neighbours() -> void:
	# The light blast launches the near one at 14 a tick; the two beyond its reach stand in the way.
	_fight([D, 0, D | A])
	var first: CrowdBody = _crowd.spawn(1, 1150.0, -1)
	var second: CrowdBody = _crowd.spawn(1, 1330.0, -1)
	var third: CrowdBody = _crowd.spawn(1, 1430.0, -1)
	_run(4)
	_check(first.state == Body.State.LAUNCHED and second.state == Body.State.IDLE, "the blast launches the near one and not the one 370 pixels off")
	var ticks: int = 0
	while second.state == Body.State.IDLE and ticks < 40:
		_run(1)
		ticks += 1
	_check(second.state == Body.State.LAUNCHED, "the flier carries the one it flies into (%s after %d ticks)" % [Body.STATE_NAMES[second.state], ticks])
	_check(second.health == _kind("small_fry").max_health - Combat.CARRY.damage and second.hits_taken == 1, "which takes a carry's %d (health %d)" % [Combat.CARRY.damage, second.health])
	_check(second.flight_speed() > 0.0, "and flies on with it (%d a tick)" % second.flight_speed())
	_run(12)
	_check(third.state == Body.State.LAUNCHED and third.hits_taken == 1, "and that one carries the next (%s)" % Body.STATE_NAMES[third.state])
	_check(_combat.combo_of(_player) == 3, "every carry counts in the player's combo (%d)" % _combat.combo_of(_player))
	_check(_player.mana == 100, "and pays no mana")
	_run(60)
	_check(first.hits_taken == 1, "the flier itself is hit once, by the blast")


func _test_an_uppercut_carries_nobody() -> void:
	# The heavy lifts 32 up and pushes 3: straight up. The one beside stands just past the
	# heavy's reach (its box ends 265 pixels out), where the flier drifts into it on its way down.
	_fight([H])
	var hit: CrowdBody = _crowd.spawn(1, 1100.0, -1)
	var beside: CrowdBody = _crowd.spawn(1, 1290.0, -1)
	_run(60)
	_check(hit.hits_taken == 1 and _lifted(hit) and hit.x > 1150.0, "the heavy launches the one in reach, which drifts into the next (%s at %d)" % [Body.STATE_NAMES[hit.state], int(hit.x)])
	_check(beside.hits_taken == 0 and beside.state == Body.State.IDLE, "the one beside it is not carried: the flier went up, not along (%d hits)" % beside.hits_taken)


func _test_a_carry_stays_in_its_lane_and_off_the_players() -> void:
	_fight([D, 0, D | A])
	var flier: CrowdBody = _crowd.spawn(1, 1150.0, -1)
	var other_lane: CrowdBody = _crowd.spawn(0, 1330.0, -1)
	var friend: Fighter = _fighter(1330.0, 1)
	friend.max_health = 100
	friend.health = 100
	_run(50)
	_check(flier.x > 1330.0, "the flier passes 1330 (%d)" % int(flier.x))
	_check(other_lane.hits_taken == 0, "a body in the lane beside is not carried")
	_check(friend.hits_taken == 0 and friend.health == 100, "and a player in the way is never bowled")


func _test_combo_pays_a_heavy_spell() -> void:
	var combo: int = _move("light").hit_boxes[0].mana + _move("light_2").hit_boxes[0].mana + _move("heavy").hit_boxes[0].mana
	for id in ["fireball_heavy", "missiles_heavy", "blast_heavy"]:
		_check(_move(id).mana_cost == combo, "the three-hit combo pays %d, a %s costs %d" % [combo, id, _move(id).mana_cost])
	_check(_move("super_fireball").mana_cost == 100, "the super costs the bar")
