class_name FighterBrain
extends InputSource
## An input source that plays a full fighter: the first enemy that fights back
## (issue #45). It presses the same buttons a player would, so the fighter it
## drives moves, attacks, guards and gets hit exactly like a player's.
##
## It thinks every `think_every` ticks and holds its last decision in between
## (docs/architecture.md, section 6), with a seeded random so a fight replays.

## The fighter this brain drives, and who it fights. With several `targets`
## (co-op, issue #59) it picks the nearest living one itself; a test may set
## `target` alone.
var fighter: Fighter
var target: Body
var targets: Array[Body] = []
## It switches to another target when that one is this much nearer, in pixels.
var retarget_margin: float = 300.0

## Ticks between two decisions.
var think_every: int = 6
## How close, in pixels, before it swings instead of walking.
var reach: float = 220.0
## Ticks the target has to be in another lane before the enemy follows it there:
## a player who hops lanes gets a moment, and the enemy doesn't shadow every hop.
var lane_follow_ticks: int = 45
## Ticks to wait after a swing before the next, picked between these two.
var rest_min: int = 30
var rest_max: int = 70
## How likely it is to guard when the target swings within reach (0 to 1), and for how long.
var guard_chance: float = 0.5
var guard_ticks: int = 24
## One heavy in this many attacks, on average.
var heavy_one_in: int = 3

var _rng := RandomNumberGenerator.new()
var _tick: int = 0
var _mask: int = 0
var _rest: int = 0
var _guarding: int = 0
var _other_lane_ticks: int = 0


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func sample(_player: int) -> int:
	_tick += 1
	_rest = maxi(_rest - 1, 0)
	_guarding = maxi(_guarding - 1, 0)
	if fighter != null:
		_pick_target()
	if fighter == null or target == null:
		return 0
	_other_lane_ticks = _other_lane_ticks + 1 if target.lane != fighter.lane else 0
	# A press is a one-tick thing; the rest of a decision is held until the next think.
	_mask &= ~(Buttons.LIGHT | Buttons.HEAVY | Buttons.LANE_UP | Buttons.LANE_DOWN)
	if _tick % think_every == 0:
		_mask = _decide()
	if _guarding > 0:
		return _mask | Buttons.GUARD
	return _mask


## The nearest living target, unless the current one is still close to as near.
## With everyone down the last target is kept, and its death ends the fight.
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


func _decide() -> int:
	if target.state == Body.State.DEAD:
		return 0  # the fight is over
	var gap: float = target.x - fighter.x
	var toward: int = Buttons.RIGHT if gap > 0.0 else Buttons.LEFT
	if target.lane != fighter.lane:
		if _other_lane_ticks < lane_follow_ticks:
			# Not yet: close the distance along the lane meanwhile, and wait.
			return toward if absf(gap) > reach else 0
		return Buttons.LANE_UP if target.lane < fighter.lane else Buttons.LANE_DOWN
	if absf(gap) > reach:
		return toward
	# In reach. Guard against a swing coming our way, sometimes.
	if target.is_attacking() and _guarding == 0 and _rng.randf() < guard_chance:
		_guarding = guard_ticks
		return 0
	if _rest > 0 or _guarding > 0:
		# Face the target while waiting: one tick of walking turns the fighter.
		return toward if (gap > 0.0) != (fighter.facing > 0) else 0
	_rest = _rng.randi_range(rest_min, rest_max)
	return Buttons.HEAVY if _rng.randi_range(1, heavy_one_in) == 1 else Buttons.LIGHT
