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
var _made_other: Fighter


func _initialize() -> void:
	_test_spawn_and_approach()
	_test_tokens_and_damage()
	_test_death_and_pool()
	_test_player_dies()
	_test_spacing()
	_test_follow_across_lanes()
	_test_surround()
	_test_passive_crowd()
	_test_players_are_walls()
	_test_surround_goes_through_the_lanes()
	_test_held_back_by_another_player_goes_round()
	_test_taunt_pulls_the_crowd_into_the_lane()
	_test_taunt_draws_targets_from_another_player()
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
	var facing_player: int = 0
	for body in _crowd.alive():
		if (body.x < _player.x) == (body.facing == 1) or absf(body.x - _player.x) <= 10.0:
			facing_player += 1
	_check(facing_player >= 12, "most bodies face the player; the rest are walking round to the other side (%d of 20)" % facing_player)


func _test_tokens_and_damage() -> void:
	_fight()
	for i in 12:
		_crowd.spawn(1, 600.0 + 30.0 * i if i % 2 == 0 else 1300.0 - 30.0 * i, 1)
	var most: int = 0
	for i in 600:
		_run(1)
		most = maxi(most, _attacking())
	_check(most <= _crowd.attack_tokens and most > 0, "at most %d of the crowd attack one player at once (saw %d)" % [_crowd.attack_tokens, most])
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
	_run(60)  # any swing in progress ends
	var swinging: int = 0
	var walking: int = 0
	for i in 200:
		_run(1)
		for body in _crowd.alive():
			if body.state == Body.State.ATTACK:
				swinging += 1
			if body.state == Body.State.WALK:
				walking += 1
	_check(swinging == 0 and walking == 0, "once the player is down the crowd stops attacking and stands still (%d attack ticks, %d walk ticks)" % [swinging, walking])


func _test_spacing() -> void:
	_fight()
	for i in 6:
		_crowd.spawn(1, 700.0, 1)
	_run(240)  # long enough for the ones that go around to have crossed
	var closest: float = 9999.0
	var alive: Array[CrowdBody] = _crowd.alive()
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			if alive[i].lane == alive[j].lane:
				closest = minf(closest, absf(alive[i].x - alive[j].x))
	var where: String = ""
	for body in alive:
		where += " [lane %d x %d %s blocked %d flank %d side %d]" % [body.lane, int(body.x), Body.STATE_NAMES[body.state], body.blocked, body.flank_lane, body.side]
	_check(closest > _crowd.spacing * 0.5, "bodies spawned on one spot spread out along their lane (closest pair %.0f apart:%s)" % [closest, where])


func _test_follow_across_lanes() -> void:
	_fight()
	# Ten in the front lane, the player in the back one.
	_player.lane = 0
	_player.set_lanes(LANES, SCALES)
	for i in 10:
		_crowd.spawn(2, 600.0 + 60.0 * i, 1)
	_run(30)
	var moved: int = 0
	for body in _crowd.alive():
		if body.lane != 2 or body.state == Body.State.LANE_CHANGE:
			moved += 1
	_check(moved == 0, "nobody follows a lane change at once")
	_run(400)
	var in_lane: int = 0
	var in_middle: int = 0
	for body in _crowd.alive():
		if body.lane == 0:
			in_lane += 1
		elif body.lane == 1:
			in_middle += 1
	_check(in_lane > 0 and in_lane <= _crowd.max_per_lane, "after a moment some follow to the player's lane, up to %d (%d did)" % [_crowd.max_per_lane, in_lane])
	_check(in_middle > 0, "the rest wait in the lane beside (%d in the middle lane)" % in_middle)


func _test_surround() -> void:
	_fight()
	# Six from the left only: some should end up on the player's right.
	for i in 6:
		_crowd.spawn(1, 300.0 + 50.0 * i, 1)
	_run(400)
	var right: int = 0
	for body in _crowd.alive():
		if body.x > _player.x:
			right += 1
	_check(right >= 2, "a crowd that arrives from one side goes around to both sides (%d of 6 on the right)" % right)


func _test_passive_crowd() -> void:
	_fight()
	_crowd.passive = true
	for i in 4:
		_crowd.spawn(1, 1200.0 + 100.0 * i, -1)
	_run(300)
	var still: bool = true
	for body in _crowd.alive():
		if body.state != Body.State.IDLE or body.x < 1200.0:
			still = false
	_check(still and _player.health == 100, "a passive crowd stands where it was put and never swings")
	_crowd.passive = false
	_run(300)
	_check(_player.health < 100, "told to fight, it walks up and swings")


## Whether any body in the player's lane, on its feet, is on the far side of the player from
## where it was last tick: a crossing. `last` is updated for the next tick.
func _crossed(last: Dictionary, player: Body) -> bool:
	var crossed: bool = false
	for body in _crowd.alive():
		var on_feet: bool = body.lane == player.lane and body.state != Body.State.LAUNCHED and body.state != Body.State.LANE_CHANGE and body.state != Body.State.DEAD
		var side: int = (1 if body.x >= player.x else -1) if on_feet else 0
		if side != 0 and last.get(body, 0) != 0 and last[body] != side:
			crossed = true
		last[body] = side
	return crossed


func _test_players_are_walls() -> void:
	_fight()
	_crowd.max_per_side = 100  # nobody goes round: the wall alone is tested
	_crowd.max_per_lane = 100
	for i in 6:
		_crowd.spawn(1, 300.0 + 50.0 * i, 1)
	var crossed: bool = false
	var last: Dictionary = {}
	for i in 400:
		_run(1)
		crossed = crossed or _crossed(last, _player)
	var right: int = 0
	var near: int = 0
	for body in _crowd.alive():
		if body.x > _player.x - _crowd.wall_gap + 0.5:
			right += 1
		if _player.x - body.x < _crowd.reach + 1.0:
			near += 1
	_check(not crossed and right == 0, "six from the left never cross the player nor come closer than the wall gap (%d did)" % right)
	_check(near >= 1, "but they still close in to swing (%d within reach)" % near)
	_check(_player.health < 100, "and hit the player from that side")


func _test_surround_goes_through_the_lanes() -> void:
	_fight()
	for i in 6:
		_crowd.spawn(1, 300.0 + 50.0 * i, 1)
	var crossed: bool = false
	var hopped: bool = false
	var last: Dictionary = {}
	for i in 500:
		_run(1)
		crossed = crossed or _crossed(last, _player)
		for body in _crowd.alive():
			hopped = hopped or body.state == Body.State.LANE_CHANGE
	var right: int = 0
	for body in _crowd.alive():
		if body.lane == _player.lane and body.x > _player.x:
			right += 1
	_check(right >= 2, "a crowd from one side ends up on both sides of the player in its lane (%d of 6 on the right)" % right)
	_check(hopped and not crossed, "and got there through the lanes, never through the player")


func _test_held_back_by_another_player_goes_round() -> void:
	_fight()
	# A second player further right, in the same lane, that the crowd is after; the first stands in the way.
	var other := Fighter.new()
	other.max_health = 100
	other.bounds = _player.bounds
	other.setup(PlayerInput.new(2, InputSource.new()), LANES, 1, 1500.0)
	other.set_lanes(LANES, SCALES)
	_made_other = other
	_crowd.targets = [_player, other]
	_crowd.retarget_margin = 5000.0  # a body keeps the target it has
	for i in 3:
		var body: CrowdBody = _crowd.spawn(1, 300.0 + 60.0 * i, 1)
		body.target = other
	var crossed: bool = false
	var last: Dictionary = {}
	for i in 700:
		for fighter: Fighter in [_player, other]:
			fighter.tick()
		_crowd.tick()
		_combat.fighters = [_player, other]
		_combat.fighters.append_array(_crowd.alive())
		_projectiles.tick(_combat.fighters)
		_combat.resolve()
		crossed = crossed or _crossed(last, _player)
	var reached: int = 0
	for body in _crowd.alive():
		if absf(body.x - other.x) < _crowd.reach + _crowd.spacing * 2.0 and body.lane == 1:
			reached += 1
	var where: String = ""
	for body in _crowd.alive():
		where += " [lane %d x %d %s blocked %d flank %d target %s]" % [body.lane, int(body.x), Body.STATE_NAMES[body.state], body.blocked, body.flank_lane, "P2" if body.target == other else "P1"]
	_check(reached >= 2, "bodies held back by the first player on their way to the second go round and reach it (%d of 3:%s)" % [reached, where])
	_check(not crossed, "without crossing the first player")
	_check(_player.health == 100 and other.health < 100, "the first player is untouched, the second is hit")
	other.free()
	_made_other = null


func _test_taunt_pulls_the_crowd_into_the_lane() -> void:
	# A knight in the back lane holding its guard; ten small fry in the front lane.
	_fight(960.0, _repeat(Buttons.GUARD, 800))
	_player.taunts = true
	_player.max_guard = 100
	_player.guard = 100
	_player.facing = -1  # toward the crowd, so the guard takes the hits
	_player.lane = 0
	_player.set_lanes(LANES, SCALES)
	for i in 10:
		_crowd.spawn(2, 300.0 + 60.0 * i, 1)
	_run(40)
	var moving: int = 0
	for body in _crowd.alive():
		if body.lane != 2 or body.state == Body.State.LANE_CHANGE:
			moving += 1
	_check(moving >= 2 and moving <= 8, "taunted, the crowd converges: some have started after 40 ticks, not all (%d of 10)" % moving)
	_run(80)
	var in_lane: int = 0
	for body in _crowd.alive():
		if body.lane == 0:
			in_lane += 1
	_check(in_lane >= 3 and in_lane < 10, "some are in the knight's lane after 120 ticks, with stragglers still coming (%d of 10)" % in_lane)
	_run(600)
	in_lane = 0
	for body in _crowd.alive():
		if body.lane == 0:
			in_lane += 1
	var where: String = ""
	for body in _crowd.alive():
		where += " [lane %d x %d %s wait %d flank %d]" % [body.lane, int(body.x), Body.STATE_NAMES[body.state], body.taunt_wait, body.flank_lane]
	_check(in_lane == 10, "and all ten end up in the knight's lane, past the cap of %d (%d did:%s)" % [_crowd.max_per_lane, in_lane, where])
	var right: int = 0
	for body in _crowd.alive():
		if body.lane == 0 and body.x > _player.x:
			right += 1
	_check(right == 0, "piled on the side they came from, nobody round behind (%d on the right)" % right)
	_check(_player.guard < _player.max_guard, "and they hit the guard")
	# The guard comes down at tick 800: the pile stays put for a while, then spreads out a few at a time.
	_run(100)
	in_lane = 0
	for body in _crowd.alive():
		if body.lane == 0:
			in_lane += 1
	_check(in_lane == 10 and not _player.taunting(), "letting go of the guard does not scatter the pile at once (%d still in the lane 20 ticks after)" % in_lane)
	var most_round: int = 0
	for i in 500:
		_run(1)
		var going_round: int = 0
		for body in _crowd.alive():
			if body.flank_lane >= 0 and body.flank_dist == _crowd.flank_past:
				going_round += 1
		most_round = maxi(most_round, going_round)
	right = 0
	for body in _crowd.alive():
		if body.lane == 0 and body.x > _player.x:
			right += 1
	_check(right >= 2 and most_round > 0 and most_round <= _crowd.max_flanking, "later some go round behind, at most %d at a time (%d on the right, %d at most going round)" % [_crowd.max_flanking, right, most_round])
	# Without the guard held, a taunter is followed like anyone else.
	_fight()
	_player.taunts = true
	_player.lane = 0
	_player.set_lanes(LANES, SCALES)
	for i in 10:
		_crowd.spawn(2, 500.0 + 60.0 * i, 1)
	_run(30)
	moving = 0
	for body in _crowd.alive():
		if body.lane != 2 or body.state == Body.State.LANE_CHANGE:
			moving += 1
	_check(moving == 0, "a knight not holding its guard draws nobody at once")
	# Letting go of the guard forgets the waits, so the next taunt starts fresh.
	_fight(960.0, _repeat(Buttons.GUARD, 20))
	_player.taunts = true
	_player.lane = 0
	_player.set_lanes(LANES, SCALES)
	var body: CrowdBody = _crowd.spawn(2, 500.0, 1)
	_run(12)
	_check(body.taunt_wait >= 0, "a taunted body rolls its wait")
	_run(40)
	_check(body.taunt_wait == -1, "and forgets it once the guard is down")


func _test_taunt_draws_targets_from_another_player() -> void:
	# The knight guards on the left; a second player stands nearer the crowd, on the right.
	_fight(900.0, _repeat(Buttons.GUARD, 500))
	_player.taunts = true
	_player.max_guard = 100
	_player.guard = 100
	var other := Fighter.new()
	other.max_health = 100
	other.bounds = _player.bounds
	other.setup(PlayerInput.new(2, InputSource.new()), LANES, 1, 1600.0)
	other.set_lanes(LANES, SCALES)
	_made_other = other
	_crowd.targets = [_player, other]
	for i in 3:
		_crowd.spawn(1, 1700.0 + 50.0 * i, -1)
	for i in 500:
		for fighter: Fighter in [_player, other]:
			fighter.tick()
		_crowd.tick()
		_combat.fighters = [_player, other]
		_combat.fighters.append_array(_crowd.alive())
		_projectiles.tick(_combat.fighters)
		_combat.resolve()
	var on_knight: int = 0
	for body in _crowd.alive():
		if body.target == _player:
			on_knight += 1
	_check(on_knight == 3, "the crowd nearer the other player goes for the taunting knight instead (%d of 3)" % on_knight)
	_check(_player.guard < _player.max_guard and other.health == 100, "hits the knight's guard and leaves the other alone")
	other.free()
	_made_other = null
