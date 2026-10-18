extends SceneTree
## Checks local co-op (issue #59): joining from a pad, the camera framing
## several players, the crowd and the brains fighting the nearest player with
## tokens per player, no friendly fire, and the stage with two players in it.
## Run: godot --headless --path . -s tests/coop_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [900.0, 950.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const R: int = Buttons.RIGHT
const L: int = Buttons.LEFT
const D: int = Buttons.DOWN
const A: int = Buttons.LIGHT

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _crowd: CrowdDirector
var _made: Array[Node] = []


func _initialize() -> void:
	_test_lobby_joins_on_a_press()
	_test_camera_frames_two_players()
	_test_edge_holds_the_players_together()
	_test_dead_player_leaves_the_frame()
	_test_crowd_fights_the_nearest_player()
	_test_tokens_per_player()
	_test_crowd_turns_to_the_living()
	_test_brain_picks_the_nearest()
	_test_no_friendly_fire()
	_test_projectile_credits_its_caster()
	_stage_tests()


## The stage needs the tree running for its _ready, so these wait for the first frame.
func _stage_tests() -> void:
	await process_frame
	_test_stage_with_two_players()
	_test_boss_fight_stays_one_player()
	_free_all()
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


func _free_all() -> void:
	for node in _made:
		node.free()
	_made.clear()
	_crowd = null
	_projectiles = null
	_combat = null


## A new, empty fight: a combat, projectiles and a crowd with no targets yet.
func _fight() -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_made.append(_projectiles)
	_combat = Combat.new()
	_combat.projectiles = _projectiles
	_crowd = CrowdDirector.new()
	_crowd.setup(LANES, SCALES, Vector2(120.0, 1800.0))
	_made.append(_crowd)


## A player of team 1 at `x`, fed `samples` then nothing, with a light attack and a fireball.
func _player(index: int, x: float, samples: Array = [], lane: int = 1) -> Fighter:
	var fighter := Fighter.new()
	fighter.max_health = 100
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.moves = [load("res://data/moves/poc/fireball.tres"), load("res://data/moves/poc/light.tres")]
	fighter.projectiles = _projectiles
	fighter.setup(PlayerInput.new(index, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, lane, x)
	fighter.set_lanes(LANES, SCALES)
	_made.append(fighter)
	return fighter


## One tick of a fight: the players, the crowd, the projectiles, then the hits.
func _run(players: Array[Fighter], ticks: int) -> void:
	for i in ticks:
		for player in players:
			player.tick()
		_crowd.tick()
		var bodies: Array[Body] = []
		bodies.append_array(players)
		bodies.append_array(_crowd.alive())
		_combat.fighters = bodies
		_projectiles.tick(bodies)
		_combat.resolve()


func _attacking(target: Body = null) -> int:
	var n: int = 0
	for body in _crowd.alive():
		if body.state == Body.State.ATTACK and (target == null or body.target == target):
			n += 1
	return n


func _targeting(target: Body) -> int:
	var n: int = 0
	for body in _crowd.alive():
		if body.target == target:
			n += 1
	return n


func _test_lobby_joins_on_a_press() -> void:
	var lobby := Lobby.new()
	lobby.add(2, InputSource.Scripted.new(PackedInt32Array([0, 0, A, A, 0])))
	lobby.add(3, InputSource.Scripted.new(PackedInt32Array([0, 0, 0, 0, 0, 0, R])))
	_check(lobby.tick().is_empty() and lobby.tick().is_empty(), "nobody joins while no pad shows a button")
	var joined: Array[PlayerInput] = lobby.tick()
	_check(joined.size() == 1 and joined[0].player == 2, "a button on pad 2 joins player 2 (%d joined)" % joined.size())
	_check(not joined[0].pressed(A) and joined[0].held(A), "the joining press is swallowed, and the button is seen as held")
	_check(lobby.tick().is_empty(), "the same pad does not join twice")
	_check(lobby.waiting() == [3], "only player 3 is still waited for (%s)" % [lobby.waiting()])
	for i in 2:
		lobby.tick()
	joined = lobby.tick()
	_check(joined.size() == 1 and joined[0].player == 3, "a direction on pad 3 joins player 3 too")
	_check(lobby.waiting().is_empty() and lobby.tick().is_empty(), "with everyone in, the lobby has nothing to do")


func _camera() -> StageCamera:
	var camera := StageCamera.new()
	camera.set_limits(0.0, 5760.0)
	camera.snap(960.0)
	_made.append(camera)
	return camera


func _follow(camera: StageCamera, players: Array[Fighter], ticks: int) -> void:
	for i in ticks:
		for player in players:
			player.tick()
		camera.follow(players, 120.0)


func _test_camera_frames_two_players() -> void:
	_fight()
	var camera := _camera()
	var one := _player(1, 1400.0)
	var two := _player(2, 1800.0)
	_follow(camera, [one, two], 300)
	_check(absf(camera.x - 1600.0) < 1.0, "with two players the camera settles on their midpoint, no look-ahead (at %.0f)" % camera.x)
	_check(one.bounds == camera.player_bounds(120.0) and two.bounds == one.bounds, "both players' bounds are the view less the margin")
	_follow(camera, [one], 300)
	_check(absf(camera.x - 1520.0) < 1.0, "alone, the look-ahead is back (at %.0f)" % camera.x)


func _test_edge_holds_the_players_together() -> void:
	_fight()
	var camera := _camera()
	var walker := _player(1, 960.0, _repeat(R, 600))
	var idler := _player(2, 800.0)
	var lost: bool = false
	for i in 600:
		_follow(camera, [walker, idler], 1)
		for player: Fighter in [walker, idler]:
			if player.x < camera.left() or player.x > camera.right():
				lost = true
	_check(not lost, "nobody is ever off screen")
	_check(idler.x == 800.0, "the player who stands still is never dragged (at %.0f)" % idler.x)
	_check(walker.x > 2400.0 and walker.x <= 2480.5, "the walker is held at the screen's edge until the other moves (at %.0f)" % walker.x)
	_check(absf(camera.left() + 120.0 - idler.x) < 1.0, "with the idler at the left edge of the view (view from %.0f)" % camera.left())


func _test_dead_player_leaves_the_frame() -> void:
	_fight()
	var camera := _camera()
	var one := _player(1, 1400.0)
	var two := _player(2, 2200.0)
	two.health = 0
	two.state = Fighter.State.DEAD
	_follow(camera, [one, two], 300)
	_check(absf(camera.x - 1520.0) < 1.0, "a dead player no longer counts: the camera follows the living one alone (at %.0f)" % camera.x)
	_check(two.x == 2200.0, "and lies where it fell")


func _test_crowd_fights_the_nearest_player() -> void:
	_fight()
	var one := _player(1, 600.0)
	var two := _player(2, 1400.0)
	_crowd.targets = [one, two]
	for i in 5:
		_crowd.spawn(1, 300.0 + 40.0 * i, 1)
		_crowd.spawn(1, 1700.0 - 40.0 * i, -1)
	# Long enough for both sides to walk up and swing, short enough that nobody is beaten yet.
	_run([one, two], 240)
	_check(one.state != Fighter.State.DEAD and two.state != Fighter.State.DEAD, "both players still stand")
	var wrong: int = 0
	for body in _crowd.alive():
		var nearest: Body = one if absf(body.x - one.x) < absf(body.x - two.x) else two
		if body.target != nearest:
			wrong += 1
	_check(wrong == 0, "every small fry fights the player nearest to it (%d did not)" % wrong)
	_check(_targeting(one) == 5 and _targeting(two) == 5, "five on each (%d and %d)" % [_targeting(one), _targeting(two)])
	_check(one.health < 100 and two.health < 100, "and both players take hits (%d and %d left)" % [one.health, two.health])


func _test_tokens_per_player() -> void:
	_fight()
	var one := _player(1, 600.0)
	var two := _player(2, 1400.0)
	_crowd.targets = [one, two]
	for i in 6:
		_crowd.spawn(1, 500.0 + 30.0 * i, 1)
		_crowd.spawn(1, 1500.0 - 30.0 * i, -1)
	var most_on_one: int = 0
	var most_at_once: int = 0
	for i in 900:
		_run([one, two], 1)
		most_on_one = maxi(most_on_one, maxi(_attacking(one), _attacking(two)))
		most_at_once = maxi(most_at_once, _attacking())
	_check(most_on_one <= _crowd.attack_tokens and most_on_one > 0, "at most %d swing at one player at once (saw %d)" % [_crowd.attack_tokens, most_on_one])
	_check(most_at_once > _crowd.attack_tokens, "the tokens are per player, so more swing over the whole crowd (saw %d at once)" % most_at_once)


func _test_crowd_turns_to_the_living() -> void:
	_fight()
	var one := _player(1, 600.0)
	var two := _player(2, 1400.0)
	_crowd.targets = [one, two]
	for i in 6:
		_crowd.spawn(1, 300.0 + 40.0 * i, 1)
	_run([one, two], 120)
	_check(_targeting(one) == 6, "six on the near player")
	one.health = 0
	one.state = Fighter.State.DEAD
	_run([one, two], 600)
	_check(_targeting(two) == 6, "when it goes down they all turn to the other (%d did)" % _targeting(two))
	_check(two.health < 100, "and reach it (%d left)" % two.health)
	two.health = 0
	two.state = Fighter.State.DEAD
	_run([one, two], 60)
	var moving: int = 0
	for i in 120:
		_run([one, two], 1)
		for body in _crowd.alive():
			if body.state == Body.State.ATTACK or body.state == Body.State.WALK:
				moving += 1
	_check(moving == 0, "with everyone down the crowd stands still (%d ticks of moving)" % moving)


func _test_brain_picks_the_nearest() -> void:
	_fight()
	var far := _player(1, 1500.0)
	var near := _player(2, 800.0)
	var enemy := Fighter.new()
	enemy.team = 2
	_made.append(enemy)
	var brain := FighterBrain.new(1)
	brain.fighter = enemy
	brain.targets = [far, near]
	enemy.setup(PlayerInput.new(0, brain), LANES, 1, 600.0)
	for i in 6:
		brain.sample(0)
	_check(brain.target == near, "a brain goes for the nearest living player")
	near.health = 0
	near.state = Fighter.State.DEAD
	for i in 6:
		brain.sample(0)
	_check(brain.target == far, "and for the other once that one is down")


func _test_no_friendly_fire() -> void:
	_fight()
	var swinger := _player(1, 600.0, [A])
	var friend := _player(2, 760.0)
	var foe: CrowdBody = _crowd.spawn(1, 760.0, -1)
	_crowd.passive = true
	_run([swinger, friend], 30)
	_check(friend.health == 100 and friend.combo_hits == 0, "a player's swing never hurts another player (%d left)" % friend.health)
	_check(foe.health < foe.max_health, "while the enemy standing in the same spot takes it")


func _test_projectile_credits_its_caster() -> void:
	_fight()
	var one := _player(1, 300.0)
	var two := _player(2, 600.0, _repeat(D, 3) + _repeat(D | R, 3) + _repeat(R, 2) + [R | A])
	var foe: CrowdBody = _crowd.spawn(1, 1100.0, -1)
	_crowd.passive = true
	_run([one, two], 9)
	_check(two.move != null and two.move.animation == &"fireball", "player 2 throws a fireball")
	var ticks: int = 0
	while foe.combo_hits == 0 and ticks < 120:
		_run([one, two], 1)
		ticks += 1
	_check(foe.combo_hits == 1, "it lands")
	_check(_combat.combo_of(two) == 1 and _combat.combo_of(one) == 0, "and counts for player 2's combo, not player 1's (%d and %d)" % [_combat.combo_of(two), _combat.combo_of(one)])


## The stage itself, headless, in `mode`, with its pads replaced by scripted sources.
func _stage(mode: PocStage.Mode) -> PocStage:
	PocStage.mode = mode
	var stage: PocStage = (load(STAGE) as PackedScene).instantiate()
	root.add_child(stage)
	_made.append(stage)
	return stage


func _test_stage_with_two_players() -> void:
	_free_all()
	var stage := _stage(PocStage.Mode.MELEE)
	_check(stage.players.size() == 1, "the melee starts with player 1")
	# Pad 2 presses light on its third tick, then walks left for a while.
	stage.lobby.add(2, InputSource.Scripted.new(PackedInt32Array([0, 0, A] + _repeat(L, 150))))
	for i in 4:
		stage.tick()
	_check(stage.players.size() == 2 and stage.players[1].input.player == 2, "a button on pad 2 joins player 2 (%d players)" % stage.players.size())
	var two: Fighter = stage.players[1]
	_check(two.state != Fighter.State.ATTACK, "without swinging on the way in (%s)" % Fighter.STATE_NAMES[two.state])
	_check(two.team == stage.players[0].team and two.health == two.max_health and two.max_health == 100, "on the players' team with full health")
	_check(stage.views.size() == 2 and stage.views[1].body_color != stage.views[0].body_color, "with a figure of its own colour")
	var lost: bool = false
	var saw_two_targeted: bool = false
	var saw_one_targeted: bool = false
	for i in 900:
		stage.tick()
		for player in stage.players:
			if player.x < stage.camera.left() or player.x > stage.camera.right():
				lost = true
		saw_one_targeted = saw_one_targeted or _stage_targeting(stage, stage.players[0]) > 0
		saw_two_targeted = saw_two_targeted or _stage_targeting(stage, two) > 0
	_check(not lost, "the camera never loses a player")
	_check(saw_one_targeted and saw_two_targeted, "the wave fights both players (one %s, two %s)" % [saw_one_targeted, saw_two_targeted])
	_check(two.x < stage.players[0].x, "player 2 walked left, within the view (at %.0f, player 1 at %.0f)" % [two.x, stage.players[0].x])
	_check(stage.players[0].health < 100 or two.health < 100, "someone has taken a hit")
	_check(stage.health_bars.size() == 2, "a health bar each")


func _stage_targeting(stage: PocStage, target: Body) -> int:
	var n: int = 0
	for body in stage.crowd.alive():
		if body.target == target:
			n += 1
	return n


func _test_boss_fight_stays_one_player() -> void:
	_free_all()
	var stage := _stage(PocStage.Mode.BOSS_FIGHT)
	stage.lobby.add(2, InputSource.Scripted.new(PackedInt32Array([A, A, A])))
	for i in 10:
		stage.tick()
	_check(stage.players.size() == 1, "a pad pressed in the boss fight joins nobody (%d players)" % stage.players.size())
