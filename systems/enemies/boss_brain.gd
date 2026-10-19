class_name BossBrain
extends InputSource
## The brain of a boss (issue #67): an input source like FighterBrain for the
## walking, the facing and the guard, but its attacks are patterns, strings of
## moves by id from its BossKind, started by name on the fighter: a string
## chains on hit as a player's would and breaks on a whiff. Two phases on
## health, with their own patterns and rests. Seeded, so a fight replays.

var fighter: Fighter
var kind: BossKind
var targets: Array[Body] = []
var target: Body
var retarget_margin: float = 300.0

var think_every: int = 4
var lane_follow_ticks: int = 30
var guard_ticks: int = 20

## The string being played and the step in it; empty between strings.
var pattern: Array[StringName] = []
var step: int = 0
## The moves this brain has started, oldest first, for tests and the readout.
var started: Array[StringName] = []

var _rng := RandomNumberGenerator.new()
var _tick: int = 0
var _mask: int = 0
var _rest: int = 0
var _guarding: int = 0
var _other_lane_ticks: int = 0
var _was_phase_two: bool = false


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


## 1 or 2, by the fighter's health.
func phase() -> int:
	if fighter == null or fighter.max_health == 0:
		return 1
	return 2 if float(fighter.health) <= kind.phase_two_at * fighter.max_health else 1


func sample(_player: int) -> int:
	_tick += 1
	_rest = maxi(_rest - 1, 0)
	_guarding = maxi(_guarding - 1, 0)
	if fighter != null:
		_pick_target()
	if fighter == null or target == null or kind == null:
		return 0
	if phase() == 2 and not _was_phase_two:
		# The turn: a breath, then the second phase's strings.
		_was_phase_two = true
		pattern.clear()
		_rest = 30
	_other_lane_ticks = _other_lane_ticks + 1 if target.lane != fighter.lane else 0
	_mask &= ~(Buttons.LANE_UP | Buttons.LANE_DOWN)
	_play_pattern()
	if _tick % think_every == 0:
		_mask = _decide()
	if _guarding > 0:
		return _mask | Buttons.GUARD
	return _mask


func _pick_target() -> void:
	var best: Body = null
	var best_gap: float = INF
	for candidate in targets:
		if candidate.state == Body.State.DEAD:
			continue
		var gap: float = absf(candidate.x - fighter.x)
		if gap < best_gap:
			best = candidate
			best_gap = gap
	if best == null:
		return
	if target == null or target.state == Body.State.DEAD or absf(target.x - fighter.x) > best_gap + retarget_margin:
		target = best


## The next step of the string, when the fighter can take it: at once when it
## is free, or chaining on a hit. A move that ended without hitting breaks the
## string. Every step is started by name, not by a button.
func _play_pattern() -> void:
	if pattern.is_empty():
		return
	if fighter.state == Body.State.HITSTUN or fighter.state == Body.State.LAUNCHED or fighter.state == Body.State.KNOCKDOWN or fighter.state == Body.State.GETUP or fighter.state == Body.State.DEAD:
		_drop_pattern()
		return
	if step >= pattern.size():
		if not fighter.is_attacking():
			_drop_pattern()
		return
	if fighter.is_attacking():
		if fighter.swing_targets.is_empty():
			return  # not landed yet; a whiff is found out when the move ends
		if fighter.start_move(fighter.move_by_id(pattern[step])):
			started.append(pattern[step])
			step += 1
		return
	if step > 0 and fighter.move == null and fighter.swing_targets.is_empty():
		_drop_pattern()  # the last step whiffed
		return
	if fighter.state == Body.State.IDLE or fighter.state == Body.State.WALK:
		if fighter.start_move(fighter.move_by_id(pattern[step])):
			started.append(pattern[step])
			step += 1


func _drop_pattern() -> void:
	pattern.clear()
	step = 0
	var two: bool = phase() == 2
	_rest = _rng.randi_range(kind.rest_min_two if two else kind.rest_min, kind.rest_max_two if two else kind.rest_max)


func _decide() -> int:
	if target.state == Body.State.DEAD or fighter.state == Body.State.DEAD:
		return 0
	if not pattern.is_empty():
		return 0  # no walking in the middle of a string
	var gap: float = target.x - fighter.x
	var toward: int = Buttons.RIGHT if gap > 0.0 else Buttons.LEFT
	if target.lane != fighter.lane:
		if _other_lane_ticks < lane_follow_ticks:
			return toward if absf(gap) > kind.reach else 0
		return Buttons.LANE_UP if target.lane < fighter.lane else Buttons.LANE_DOWN
	if _rest > 0 or _guarding > 0:
		return toward if (gap > 0.0) != (fighter.facing > 0) else 0
	if absf(gap) > kind.reach:
		# Far: shoot now and then, else close in.
		if absf(gap) > kind.shot_range and fighter.move_by_id(&"boss_shot") != null and _rng.randf() < kind.shot_chance:
			_start_pattern(["boss_shot"])
			return 0
		return toward
	# In reach. Guard against a swing coming our way, sometimes.
	if target.is_attacking() and _guarding == 0 and _rng.randf() < kind.guard_chance:
		_guarding = guard_ticks
		return 0
	if (gap > 0.0) != (fighter.facing > 0):
		return toward  # face it first
	var choices: Array[String] = kind.patterns_two if phase() == 2 else kind.patterns
	_start_pattern(choices[_rng.randi_range(0, choices.size() - 1)].split(" "))
	return 0


func _start_pattern(ids: Array) -> void:
	pattern.clear()
	for id in ids:
		pattern.append(StringName(id))
	step = 0
