extends SceneTree
## A way out of the pile (issue #94). First the sandbox test from the plan, run
## headless: six small fry placed in front of the player as the sandbox's 1 key
## does, F5, and the hop, the dash and the light blast tried in turn from the
## pile, each on the first tick the player can act. Then the blast's own rules:
## out at once, invincible while it comes out, launching everything around the
## player in every lane, a shove that no shield stops, free, and a boss that
## stands through it.
## Run: godot --headless --path . -s tests/way_out_test.gd --quit-after 8000
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [900.0, 950.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const D: int = Buttons.DOWN
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const X: int = Buttons.DODGE
const Q: int = Buttons.LANE_UP
const R: int = Buttons.RIGHT
## The blast's input: a tap of down, let go, down again with light (the reader
## needs the stick to leave down between the two taps).
const BLAST: Array[int] = [D, 0, D | A]
## Ticks the six take to surround a standing player, with a margin.
const PILE_TICKS: int = 400

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _crowd: CrowdDirector
var _player: Fighter
var _made: Array[Fighter] = []


## Presses `plan`, one sample a tick, from the first tick after `after` on
## which the fighter can act, and nothing before or after. `fired_at` is that tick.
class WhenFree:
	extends InputSource

	var fighter: Fighter
	var plan: Array[int]
	var after: int
	var fired_at: int = -1
	var _tick: int = 0
	var _next: int = 0

	func _init(for_fighter: Fighter, the_plan: Array[int], after_tick: int) -> void:
		fighter = for_fighter
		plan = the_plan
		after = after_tick

	func sample(_player: int) -> int:
		_tick += 1
		if fired_at < 0:
			var free: bool = fighter.hitstop == 0 and (fighter.state == Body.State.IDLE or fighter.state == Body.State.WALK)
			if _tick <= after or not free:
				return 0
			fired_at = _tick
		if _next < plan.size():
			_next += 1
			return plan[_next - 1]
		return 0


func _initialize() -> void:
	_test_the_pile()
	_test_the_hop_from_the_pile()
	_test_the_dash_from_the_pile()
	_test_the_blast_from_the_pile()
	_test_blast_out_at_once_under_a_swing()
	_test_blast_launches_every_lane_and_behind()
	_test_blast_shoves_a_shield_without_breaking_it()
	_test_blast_is_free()
	_test_a_boss_stands_through_the_light_blast()
	_test_heavy_blast_still_launches_a_boss()
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


## A player at `x` in the middle lane with the sandbox's kit and bars, driven by `source`
## (or by `samples`, one a tick), and a crowd aimed at it.
func _fight(source: InputSource = null, samples: Array = [], x: float = 960.0) -> Fighter:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_crowd = CrowdDirector.new()
	_crowd.setup(LANES, SCALES, Vector2(120.0, 1800.0))
	_player = _fighter(x, 1, source, samples)
	_player.max_health = 100
	_player.health = 100
	_crowd.targets = [_player]
	return _player


func _fighter(x: float, team: int, source: InputSource = null, samples: Array = [], lane: int = 1) -> Fighter:
	var fighter := Fighter.new()
	fighter.team = team
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.moves = [
		load("res://data/moves/poc/blast_heavy.tres"),
		load("res://data/moves/poc/blast_light.tres"),
		load("res://data/moves/poc/light_2.tres"), load("res://data/moves/poc/light.tres"),
		load("res://data/moves/poc/heavy.tres"),
	]
	fighter.projectiles = _projectiles
	fighter.max_mana = 100
	if source == null:
		source = InputSource.Scripted.new(PackedInt32Array(samples))
	fighter.setup(PlayerInput.new(team, source), LANES, lane, x)
	fighter.set_lanes(LANES, SCALES)
	fighter.mana = 50
	_made.append(fighter)
	return fighter


## Six small fry placed as the sandbox's 1 key places them: 320 pixels in front of the
## player, in the three lanes, facing it; then the fight is on (F5).
func _six_in_front() -> void:
	for i in 6:
		_crowd.spawn(i % 3, _player.x + 320.0, -1)


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


## How many bodies stand on each side of the player in its lane: [left, right].
func _sides() -> Array[int]:
	var sides: Array[int] = [0, 0]
	for body in _crowd.alive():
		if body.lane == _player.lane:
			sides[1 if body.x > _player.x else 0] += 1
	return sides


## The nearest body on its feet (standing, walking or swinging) in any lane, in pixels.
func _nearest_standing() -> float:
	var nearest: float = INF
	for body in _crowd.alive():
		if body.state in [Body.State.IDLE, Body.State.WALK, Body.State.ATTACK]:
			nearest = minf(nearest, absf(body.x - _player.x))
	return nearest


## Runs `ticks` after the escape input fires and reports how it went: hits taken, the
## ticks the player could act, and the longest run of them.
func _after_the_input(source: WhenFree, ticks: int) -> Dictionary:
	while source.fired_at < 0:
		_run(1)
	var hits_before: int = _player.hits_taken
	var free: int = 0
	var run: int = 0
	var longest: int = 0
	var first_hit: int = -1
	for i in ticks:
		_run(1)
		if _player.hits_taken > hits_before and first_hit < 0:
			first_hit = i + 1
		if _player.hitstop == 0 and (_player.state == Body.State.IDLE or _player.state == Body.State.WALK):
			free += 1
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return {"hits": _player.hits_taken - hits_before, "free": free, "longest": longest, "first_hit": first_hit}


func _test_the_pile() -> void:
	# No input: the six surround the player and chain it. This is the frustration from
	# Ben's play, measured: how often the player can act at all, and for how long at a stretch.
	var source := WhenFree.new(null, [], 1000000)
	_fight(source)
	source.fighter = _player
	_six_in_front()
	_run(PILE_TICKS)
	var sides: Array[int] = _sides()
	_check(sides[0] >= 1 and sides[1] >= 1, "the six surround a standing player (%d left, %d right in its lane)" % sides)
	var hits_before: int = _player.hits_taken
	var free: int = 0
	var run: int = 0
	var longest: int = 0
	var gaps: Array[int] = []
	for i in 600:
		_run(1)
		if _player.hitstop == 0 and (_player.state == Body.State.IDLE or _player.state == Body.State.WALK):
			free += 1
			run += 1
		else:
			if run > 0:
				gaps.append(run)
			longest = maxi(longest, run)
			run = 0
	var hits: int = _player.hits_taken - hits_before
	_check(hits >= 6, "and chain it: %d hits in ten seconds" % hits)
	print("the pile, no input: %d hits in 600 ticks, free to act on %d ticks, the longest stretch %d, gaps %s" % [hits, free, longest, gaps])


func _test_the_hop_from_the_pile() -> void:
	var source := WhenFree.new(null, [Q], PILE_TICKS)
	_fight(source)
	source.fighter = _player
	_six_in_front()
	var result: Dictionary = _after_the_input(source, 120)
	print("the hop: %d hits in the 120 ticks after it, free on %d, the first hit after %d ticks" % [result.hits, result.free, result.first_hit])


func _test_the_dash_from_the_pile() -> void:
	var source := WhenFree.new(null, [X | R], PILE_TICKS)
	_fight(source)
	source.fighter = _player
	_six_in_front()
	var result: Dictionary = _after_the_input(source, 120)
	print("the dash: %d hits in the 120 ticks after it, free on %d, the first hit after %d ticks" % [result.hits, result.free, result.first_hit])


func _test_the_blast_from_the_pile() -> void:
	# The way out: one input from the pile, and the player is clear.
	var source := WhenFree.new(null, BLAST, PILE_TICKS)
	_fight(source)
	source.fighter = _player
	_six_in_front()
	while source.fired_at < 0:
		_run(1)
	_run(4)
	_check(_player.move != null and _player.move.id == &"blast_light" or _player.state == Body.State.ATTACK, "the blast comes out from the pile (%s)" % Body.STATE_NAMES[_player.state])
	_run(6)
	var flying: int = 0
	for body in _crowd.alive():
		if body.state == Body.State.LAUNCHED or body.state == Body.State.KNOCKDOWN:
			flying += 1
	_check(flying == 6, "and every one of the six is in the air or down ten ticks later (%d of 6)" % flying)
	var hits_before: int = _player.hits_taken
	_run(50)
	_check(_player.hits_taken == hits_before, "the player takes no hit for a second after it (%d)" % (_player.hits_taken - hits_before))
	var nearest: float = _nearest_standing()
	_check(nearest > 250.0, "and nobody stands within 250 pixels a second later (nearest %d)" % nearest)
	print("the blast: %d hits in the 60 ticks after it, the nearest body on its feet at %s pixels" % [_player.hits_taken - hits_before, "none" if nearest == INF else str(int(nearest))])


func _test_blast_out_at_once_under_a_swing() -> void:
	# A light from the front lands on ticks 9 to 17; the blast starts on tick 9, right under it.
	_fight(null, [0, 0, 0, 0, 0, 0, D, 0, D | A])
	var enemy: Fighter = _fighter(1100.0, 2, null, [A])
	enemy.facing = -1
	_run(12)
	_check(_player.move != null and _player.move.id == &"blast_light" and _projectiles.count() == 1, "the burst is out one tick after the press (%s, %d bursts)" % [Body.STATE_NAMES[_player.state], _projectiles.count()])
	_check(_player.hits_taken == 0, "and the swing it started under does not land (%d hits taken)" % _player.hits_taken)
	_check(enemy.state == Body.State.LAUNCHED, "the swinger is launched on the same tick (%s)" % Body.STATE_NAMES[enemy.state])
	_run(20)
	_check(_player.hits_taken == 0 and _player.state != Body.State.HITSTUN, "nothing lands on the blast while it plays out")


func _test_blast_launches_every_lane_and_behind() -> void:
	_fight(null, BLAST)
	_crowd.passive = true
	var front: CrowdBody = _crowd.spawn(1, 1150.0, -1)
	var behind: CrowdBody = _crowd.spawn(1, 770.0, 1)
	var back_lane: CrowdBody = _crowd.spawn(0, 1050.0, -1)
	var front_lane: CrowdBody = _crowd.spawn(2, 870.0, 1)
	var far: CrowdBody = _crowd.spawn(1, 1300.0, -1)
	_run(4)
	for body: CrowdBody in [front, behind, back_lane, front_lane]:
		_check(body.state == Body.State.LAUNCHED, "a body at %d in lane %d is launched (%s)" % [int(body.x), body.lane, Body.STATE_NAMES[body.state]])
	_check(far.state == Body.State.IDLE, "one 340 pixels away is out of its reach")
	_run(40)
	_check(front.x > 1250.0 and behind.x < 670.0, "they fly away from the player and land out of the pile (front at %d, behind at %d)" % [int(front.x), int(behind.x)])
	_check(front.state == Body.State.KNOCKDOWN and front.health == 30 - _blast_damage(), "the blast's damage is a shove's, not a kill's (%d health left)" % front.health)


func _test_blast_shoves_a_shield_without_breaking_it() -> void:
	_fight(null, BLAST)
	_crowd.passive = true
	var shielded: CrowdBody = _crowd.spawn(1, 1150.0, -1, load("res://data/enemies/shielded.tres"))
	_run(4)
	_check(shielded.state == Body.State.LAUNCHED, "a shield bearer facing the blast is launched like the rest (%s)" % Body.STATE_NAMES[shielded.state])
	_check(shielded.shield == 40 and not shielded.just_broke, "and keeps its shield (%d)" % shielded.shield)


func _test_blast_is_free() -> void:
	_fight(null, BLAST)
	_crowd.passive = true
	for i in 6:
		_crowd.spawn(i % 3, 1100.0 + 40.0 * i, -1)
	_run(10)
	_check(_player.mana == 50, "the blast costs no mana and pays none back, six bodies hit or not (mana %d)" % _player.mana)


func _test_a_boss_stands_through_the_light_blast() -> void:
	_fight(null, BLAST)
	var boss: Fighter = _fighter(1150.0, 2)
	boss.launch_resist = load("res://data/bosses/captain.tres").launch_resist
	boss.max_health = 600
	boss.health = 600
	_run(4)
	_check(boss.state == Body.State.HITSTUN and boss.hits_taken == 1, "a boss takes the light blast standing: pushed, not launched (%s)" % Body.STATE_NAMES[boss.state])
	_run(30)
	_check(boss.state == Body.State.IDLE and boss.x > 1150.0, "and is back on its feet a moment later, a step back (%s at %d)" % [Body.STATE_NAMES[boss.state], int(boss.x)])


func _test_heavy_blast_still_launches_a_boss() -> void:
	_fight(null, [D, 0, D | H])
	_player.mana = 100
	var boss: Fighter = _fighter(1150.0, 2)
	boss.launch_resist = load("res://data/bosses/captain.tres").launch_resist
	boss.max_health = 600
	boss.health = 600
	_run(34)
	_check(_player.move != null and _player.move.id == &"blast_heavy", "the heavy blast comes out with heavy")
	_check(boss.state == Body.State.LAUNCHED, "and it launches the boss (%s)" % Body.STATE_NAMES[boss.state])


func _blast_damage() -> int:
	var blast: Move = load("res://data/moves/poc/blast_light.tres")
	return blast.projectile_hit.damage
