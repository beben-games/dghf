extends SceneTree
## Checks hits landing (issue #9): an attacker fed scripted inputs, targets that
## never press anything, and the combat system resolving every tick.
## Run: godot --headless --path . -s tests/hits_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const R: int = Buttons.RIGHT
const D: int = Buttons.DOWN
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const U: int = Buttons.UP

var _failures: int = 0
var _combat: Combat
var _projectiles: Projectiles
var _made: Array[Fighter] = []


func _initialize() -> void:
	_test_light_hit()
	_test_hits_once_and_freezes_the_attacker()
	_test_lane_and_team()
	_test_one_freeze_for_many_targets()
	_test_trade()
	_test_launch_and_knockdown()
	_test_juggle()
	_test_combo_ends_on_recovery()
	_test_fireball_hit()
	_test_crouching_hurtbox()
	_test_air_attack()
	_test_air_attack_ends_on_landing()
	_test_jump_in_combo()
	_test_air_juggle()
	_test_three_hit_combo()
	_test_no_cancel_on_a_miss()
	_test_no_cancel_outside_the_window()
	_test_follow_up_needs_a_cancel()
	_test_cancel_into_fireball()
	_test_air_cancel()
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


## Starts a new fight with nobody in it.
func _clear() -> void:
	_free_all()
	_projectiles = Projectiles.new()
	_combat = Combat.new()
	_combat.projectiles = _projectiles


## A fighter added to the fight. It receives `samples`, one per tick, then nothing.
func _fighter(x: float, team: int, samples: Array = [], lane: int = 1) -> Fighter:
	var fighter := Fighter.new()
	fighter.team = team
	fighter.bounds = Vector2(120.0, 1800.0)
	fighter.moves = [
		load("res://data/moves/poc/fireball.tres"),
		load("res://data/moves/poc/light_2.tres"), load("res://data/moves/poc/light.tres"),
		load("res://data/moves/poc/heavy.tres"),
		load("res://data/moves/poc/air_light.tres"),
		load("res://data/moves/poc/air_heavy.tres"),
	]
	fighter.projectiles = _projectiles
	fighter.setup(PlayerInput.new(team, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, lane, x)
	_combat.fighters.append(fighter)
	_made.append(fighter)
	return fighter


## One tick of the stage: everything moves, then hits are resolved.
func _run(ticks: int) -> void:
	for i in ticks:
		for fighter in _combat.fighters:
			fighter.tick()
		_projectiles.tick()
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


func _test_light_hit() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	var target := _fighter(800.0, 2)
	_run(8)
	_check(target.state == Fighter.State.IDLE, "nothing lands before the hitbox is out")
	_run(1)
	_check(target.state == Fighter.State.HITSTUN, "the light attack puts the target in hitstun on its first active frame")
	_check(target.combo_hits == 1 and target.combo_damage == 10, "the hit counts 1 hit and 10 damage")
	_check(target.hitstop == 5 and attacker.hitstop == 5, "both freeze for the hit's hitstop")
	_check(target.flash_ticks > 0, "the target flashes")
	_check(target.facing == -1, "the target turns to face the hit")
	_run(5)
	_check(is_equal_approx(target.x, 800.0), "a frozen target does not move")
	_run(14)
	_check(target.state == Fighter.State.IDLE, "the target recovers after its 14 ticks of hitstun")
	_check(target.x > 840.0, "knockback pushed the target away (to %.0f)" % target.x)


func _test_hits_once_and_freezes_the_attacker() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	var target := _fighter(800.0, 2)
	# Without a hit the swing is over on tick 28 (see poc_player_test.gd).
	_run(28 + 4)
	_check(attacker.state == Fighter.State.ATTACK, "hitstop makes the swing last 5 ticks longer")
	_run(1)
	_check(attacker.state == Fighter.State.IDLE, "and no more than 5")
	_check(target.combo_hits == 1, "a swing hits a target once, though its box is out for 9 frames")


func _test_lane_and_team() -> void:
	_clear()
	_fighter(600.0, 1, [A])
	var other_lane := _fighter(800.0, 2, [], 0)
	var friend := _fighter(800.0, 1)
	_run(27)
	_check(other_lane.combo_hits == 0, "a hit does not reach another lane")
	_check(friend.combo_hits == 0, "a hit does not land on the same team")


func _test_one_freeze_for_many_targets() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	var targets: Array[Fighter] = []
	for i in 6:
		targets.append(_fighter(760.0 + i * 20.0, 2))
	_run(9)
	var all_hit: bool = true
	for target in targets:
		all_hit = all_hit and target.state == Fighter.State.HITSTUN
	_check(all_hit, "one swing hits all six targets in its box")
	_check(attacker.hitstop == 5, "and freezes the attacker once, not six times (got %d)" % attacker.hitstop)
	# A target that walks into the box later in the same swing is hit, with no second freeze.
	_clear()
	attacker = _fighter(600.0, 1, [A])
	_fighter(800.0, 2)
	var late := _fighter(1000.0, 2, _repeat(Buttons.LEFT, 40))
	_run(9)
	var frozen_until: int = attacker.hitstop
	_run(frozen_until)
	while attacker.state == Fighter.State.ATTACK and late.combo_hits == 0:
		_run(1)
	_check(late.combo_hits == 1, "a target that walks into the box mid-swing is hit")
	_check(attacker.hitstop == 0, "the attacker is not frozen a second time in the same swing")


func _test_trade() -> void:
	_clear()
	var left := _fighter(700.0, 1, [A])
	var right := _fighter(900.0, 2, [A])
	right.facing = -1
	_run(9)
	_check(left.state == Fighter.State.HITSTUN and right.state == Fighter.State.HITSTUN, "two attacks that connect on the same tick both land")


func _test_launch_and_knockdown() -> void:
	_clear()
	_fighter(600.0, 1, [H])
	var target := _fighter(800.0, 2)
	_run(13)
	_check(target.state == Fighter.State.LAUNCHED, "the heavy attack launches")
	_check(_combat.shake > 0.0, "and asks for a screen shake")
	_run(1)
	_check(_combat.shake == 0.0, "the shake is asked for on the tick of the hit only")
	_run(20)
	_check(target.height > 150.0, "the target is in the air (height %.0f)" % target.height)
	var ticks: int = 0
	while target.state == Fighter.State.LAUNCHED and ticks < 200:
		_run(1)
		ticks += 1
	_check(target.state == Fighter.State.KNOCKDOWN and target.height == 0.0, "it lands knocked down")
	_check(not target.can_be_hit(), "a fighter on the floor can't be hit")
	_run(target.knockdown_ticks)
	_check(target.state == Fighter.State.GETUP, "then it gets up")
	_run(target.getup_ticks)
	_check(target.state == Fighter.State.IDLE, "and stands")


func _test_juggle() -> void:
	_clear()
	# Heavy, then a light as soon as the heavy has recovered: it catches the target on the way down.
	var attacker := _fighter(600.0, 1, [H] + _repeat(0, 40) + [A])
	var target := _fighter(800.0, 2)
	_run(13)
	var first_fall: float = target.gravity
	while target.combo_hits < 2 and target.state == Fighter.State.LAUNCHED:
		_run(1)
	_check(target.combo_hits == 2, "a light after the launcher juggles: 2 hits (got %d)" % target.combo_hits)
	_check(target.combo_damage == 32, "the combo adds up its damage")
	_check(target.juggle_hits == 1 and target.state == Fighter.State.LAUNCHED, "a hit in the air keeps the target in the air")
	var before: float = target.vertical_speed
	_run(target.hitstop + 1)
	var fall: float = before - target.vertical_speed
	_check(fall > first_fall * 1.2, "after a juggle hit the target falls faster (%.2f against %.2f)" % [fall, first_fall])
	while target.state == Fighter.State.LAUNCHED:
		_run(1)
	_check(target.juggle_hits == 0, "landing ends the juggle")


func _test_combo_ends_on_recovery() -> void:
	_clear()
	_fighter(600.0, 1, [A] + _repeat(0, 60) + [A])
	var target := _fighter(800.0, 2)
	_run(110)
	_check(target.combo_hits == 1 and target.combo_damage == 10, "a hit after the target recovered starts a new combo")


func _test_fireball_hit() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, _repeat(D, 3) + _repeat(D | R, 3) + _repeat(R, 2) + [R | A])
	var target := _fighter(1100.0, 2)
	var missed := _fighter(900.0, 2, [], 2)
	_run(9)
	_check(attacker.move != null and attacker.move.animation == &"fireball", "the fireball comes out")
	var ticks: int = 0
	while target.combo_hits == 0 and ticks < 120:
		_run(1)
		ticks += 1
	_check(target.state == Fighter.State.HITSTUN and target.combo_damage == 14, "the fireball hits the target in its lane")
	_check(missed.combo_hits == 0, "and flies past a target in another lane")
	_check(_projectiles.count() == 0, "the fireball is used up by the hit")
	_check(attacker.hitstop == 0, "a projectile hit does not freeze its caster")


func _test_crouching_hurtbox() -> void:
	_clear()
	var croucher := _fighter(800.0, 2, _repeat(D, 10))
	var standing: Rect2 = croucher.hurt_rect()
	_run(5)
	_check(croucher.hurt_rect().size.y < standing.size.y, "crouching makes the hurtbox shorter")
	_check(croucher.hurt_rect().end.y == standing.end.y, "and keeps it on the ground")


func _test_air_attack() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [U, 0, A])
	_run(2)
	_check(attacker.state == Fighter.State.JUMP, "up jumps")
	_run(1)
	_check(attacker.state == Fighter.State.AIR_ATTACK and attacker.move.animation == &"air_light", "attack in a jump is the air light")
	var height: float = attacker.height
	_run(1)
	_check(attacker.height > height, "the jump carries on during the air move")
	_run(18)
	_check(attacker.state == Fighter.State.JUMP and attacker.move == null, "when the air move ends first, the jump carries on")
	_clear()
	attacker = _fighter(600.0, 1, [U, 0, H])
	_run(3)
	_check(attacker.move != null and attacker.move.animation == &"air_heavy", "heavy in a jump is the air heavy")
	_clear()
	attacker = _fighter(600.0, 1, [A])
	_run(1)
	_check(attacker.move.animation == &"light", "on the ground, attack is still the ground light")


func _test_air_attack_ends_on_landing() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [U] + _repeat(0, 24) + [H])
	_run(26)
	_check(attacker.state == Fighter.State.AIR_ATTACK, "an air heavy late in the jump starts")
	var ticks: int = 0
	while attacker.height > 0.0 and ticks < 60:
		_run(1)
		ticks += 1
	_check(ticks < 26, "the fighter lands before the move's 26 frames are over (after %d)" % ticks)
	_check(attacker.state == Fighter.State.IDLE and attacker.move == null, "landing ends the air move")
	_check(attacker.active_hit_rects().is_empty(), "and its hitbox")


func _test_jump_in_combo() -> void:
	_clear()
	# Jump forward, air light late on the way down, then a ground light pressed
	# before landing, which comes out on landing.
	var attacker := _fighter(560.0, 1, [U | R] + _repeat(0, 24) + [A] + _repeat(0, 9) + [A])
	var target := _fighter(900.0, 2)
	var ticks: int = 0
	while target.combo_hits < 2 and ticks < 90:
		_run(1)
		ticks += 1
		if target.combo_hits == 1 and target.state == Fighter.State.IDLE:
			break
	_check(target.combo_hits == 2 and target.state == Fighter.State.HITSTUN, "an air light into a ground light is a 2-hit combo on a standing target (got %d)" % target.combo_hits)


func _test_air_juggle() -> void:
	_clear()
	# Launch, jump forward after the target, and kick it in the air. The kick is short, so the jump has to close in.
	var attacker := _fighter(660.0, 1, [H] + _repeat(0, 42) + _repeat(U | R, 3) + [A])
	var target := _fighter(800.0, 2)
	var ticks: int = 0
	while target.combo_hits < 2 and ticks < 120:
		_run(1)
		ticks += 1
	_check(target.combo_hits == 2 and attacker.height > 0.0, "a launcher, then a jump and an air light: 2 hits, the second from the air (got %d)" % target.combo_hits)


func _test_three_hit_combo() -> void:
	_clear()
	# Light, a second light pressed during the first one's hitstop, then heavy pressed during the second's.
	var attacker := _fighter(620.0, 1, [A] + _repeat(0, 9) + [A] + _repeat(0, 11) + [H])
	var target := _fighter(800.0, 2)
	_run(9)
	_check(target.combo_hits == 1 and attacker.hitstop == 5, "the light lands")
	_run(5)
	_check(attacker.move.id == &"light", "a press during hitstop waits for the freeze to end")
	_run(1)
	_check(attacker.move.id == &"light_2" and attacker.move_frame == 0, "then the light is cut short by its follow-up")
	var ticks: int = 0
	while target.combo_hits < 3 and target.in_hit_reaction() and ticks < 80:
		_run(1)
		ticks += 1
	_check(target.combo_hits == 3 and target.state == Fighter.State.LAUNCHED, "light, light, heavy is a 3-hit combo that launches (got %d hits)" % target.combo_hits)
	_check(target.combo_damage == 10 + 12 + 22, "and adds up its damage")
	_check(ticks < 30, "the cancels make it quick (%d ticks after the first cancel)" % ticks)


func _test_no_cancel_on_a_miss() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A] + _repeat(0, 9) + [A])
	_run(20)
	_check(attacker.move != null and attacker.move.id == &"light" and attacker.move_frame == 19, "a light that hits nothing can't be cancelled")


func _test_no_cancel_outside_the_window() -> void:
	_clear()
	# The light's window closes on frame 20. With 5 ticks of hitstop that is tick 26: press on tick 28.
	var attacker := _fighter(620.0, 1, [A] + _repeat(0, 26) + [H] + _repeat(0, 3))
	var target := _fighter(800.0, 2)
	_run(30)
	_check(target.combo_hits == 1 and attacker.move != null and attacker.move.id == &"light", "a press after the window has closed does not cancel")


func _test_follow_up_needs_a_cancel() -> void:
	_clear()
	var attacker := _fighter(600.0, 1, [A])
	_run(1)
	_check(attacker.move.id == &"light", "from standing, attack is the first light, never the follow-up")


func _test_cancel_into_fireball() -> void:
	_clear()
	# Light, then the fireball motion finished during the light's hitstop.
	var attacker := _fighter(620.0, 1, [A] + _repeat(0, 7) + _repeat(D, 2) + _repeat(D | R, 2) + [R, R | A])
	var target := _fighter(800.0, 2)
	_run(15)
	_check(attacker.move != null and attacker.move.id == &"fireball", "a light that hits can be cancelled into the fireball")
	_check(attacker.facing == 1, "holding forward during the cancel does not turn or walk the fighter")


func _test_air_cancel() -> void:
	_clear()
	# Launch, jump forward, air light, and heavy pressed during the air light's hitstop.
	var attacker := _fighter(660.0, 1, [H] + _repeat(0, 42) + _repeat(U | R, 3) + [A] + _repeat(0, 6) + [H])
	var target := _fighter(800.0, 2)
	var ticks: int = 0
	while target.combo_hits < 3 and target.state == Fighter.State.LAUNCHED or ticks < 14:
		_run(1)
		ticks += 1
		if ticks > 150:
			break
	_check(target.combo_hits == 3, "launcher, air light cancelled into air heavy: 3 hits (got %d)" % target.combo_hits)
	_check(target.juggle_hits == 2, "both air hits count as juggle hits")
