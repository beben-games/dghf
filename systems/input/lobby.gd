class_name Lobby
extends RefCounted
## Where players join (issue #59): one PlayerInput per player index not yet in
## the fight, ticked every tick. A pad that shows any button joins its player,
## and its PlayerInput is handed over with that press already swallowed, so the
## fighter that takes it does not swing on its first tick. The game only ever
## sees player indices here, never devices: the stage gives it a Device source
## per index, a test gives it Scripted ones.

var _waiting: Dictionary[int, PlayerInput] = {}


## Watches `source` for player `player`, until it joins.
func add(player: int, source: InputSource) -> void:
	_waiting[player] = PlayerInput.new(player, source)


## The player indices still waited for, lowest first.
func waiting() -> Array[int]:
	var players: Array[int] = []
	players.assign(_waiting.keys())
	players.sort()
	return players


## Once a tick. Returns the inputs of the players who joined this tick, lowest
## index first, and stops waiting for them.
func tick() -> Array[PlayerInput]:
	var joined: Array[PlayerInput] = []
	for player in waiting():
		var input: PlayerInput = _waiting[player]
		input.tick()
		if input.mask() == 0:
			continue
		for bit: int in Buttons.NAMES:
			input.consume(bit)
		joined.append(input)
		_waiting.erase(player)
	return joined
