class_name PlayerInput
extends RefCounted
## One player's inputs: this tick's buttons, and a short history for buffering
## and motion commands. Everything is counted in ticks.

const HISTORY: int = 30  # ticks of input kept
const PRESS_BUFFER: int = 8  # a press this old still counts

var player: int
var source: InputSource

var _history: PackedInt32Array = PackedInt32Array()  # newest last
var _tick: int = 0
var _last_press: Dictionary[int, int] = {}  # bit -> tick of its last unused press


func _init(player_index: int, input_source: InputSource) -> void:
	player = player_index
	source = input_source
	_history.resize(HISTORY)


## Call once per tick, before anything reads the input.
func tick() -> void:
	var previous: int = _history[HISTORY - 1]
	var now: int = source.sample(player)
	for i in HISTORY - 1:
		_history[i] = _history[i + 1]
	_history[HISTORY - 1] = now
	_tick += 1
	var pressed_now: int = now & ~previous
	for bit: int in Buttons.NAMES:
		if pressed_now & bit:
			_last_press[bit] = _tick


func held(bit: int) -> bool:
	return _history[HISTORY - 1] & bit != 0


## True if the button went down within the last PRESS_BUFFER ticks and that
## press has not been used yet.
func pressed(bit: int) -> bool:
	return _tick - _last_press.get(bit, -1000) < PRESS_BUFFER


## Call on a tick the fighter spends frozen by a hit, after tick(): the freeze
## does not use up the buffer, so a press made during hitstop still counts after it.
func hold_presses() -> void:
	for bit: int in _last_press:
		_last_press[bit] += 1


## Marks the buffered press as used, so one press starts one thing.
func consume(bit: int) -> void:
	_last_press.erase(bit)


## The buttons held `ago` ticks back (0 is this tick).
func mask(ago: int = 0) -> int:
	return _history[HISTORY - 1 - ago]


## The stick position `ago` ticks back in fighting-game numpad notation
## (5 neutral, 6 forward, 2 down, 3 down-forward ...), relative to `facing`.
func direction(facing: int, ago: int = 0) -> int:
	var m: int = mask(ago)
	var horizontal: int = (int(m & Buttons.RIGHT != 0) - int(m & Buttons.LEFT != 0)) * facing
	var vertical: int = int(m & Buttons.UP != 0) - int(m & Buttons.DOWN != 0)
	return 5 + horizontal + 3 * vertical
