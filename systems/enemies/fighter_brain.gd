class_name FighterBrain
extends InputSource
## An input source that plays a full fighter: the first enemy that fights back
## (issue #45). It presses the same buttons a player would, so the fighter it
## drives moves, attacks, guards and gets hit exactly like a player's.
##
## It thinks every `think_every` ticks and holds its last decision in between
## (docs/architecture.md, section 6), with a seeded random so a fight replays.

## The fighter this brain drives, and who it fights.
var fighter: Fighter
var target: Fighter

## Ticks between two decisions.
var think_every: int = 6
## How close, in pixels, before it swings instead of walking.
var reach: float = 220.0
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


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func sample(_player: int) -> int:
	_tick += 1
	_rest = maxi(_rest - 1, 0)
	_guarding = maxi(_guarding - 1, 0)
	if fighter == null or target == null:
		return 0
	# A press is a one-tick thing; the rest of a decision is held until the next think.
	_mask &= ~(Buttons.LIGHT | Buttons.HEAVY | Buttons.LANE_UP | Buttons.LANE_DOWN)
	if _tick % think_every == 0:
		_mask = _decide()
	if _guarding > 0:
		return _mask | Buttons.GUARD
	return _mask


func _decide() -> int:
	var gap: float = target.x - fighter.x
	var toward: int = Buttons.RIGHT if gap > 0.0 else Buttons.LEFT
	if target.lane != fighter.lane:
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
