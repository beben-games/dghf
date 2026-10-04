class_name CommandReader
## Recognises motion commands in a player's input history.

const QUARTER_CIRCLE_FORWARD: PackedInt32Array = [2, 3, 6]
const DEFAULT_WINDOW: int = 24  # ticks the whole motion may take


## True if the stick went through `motion` (numpad directions, relative to
## `facing`) in order within the last `window` ticks. Other positions in
## between are allowed.
static func matches(input: PlayerInput, motion: PackedInt32Array, facing: int, window: int = DEFAULT_WINDOW) -> bool:
	if motion.is_empty():
		return true
	var step: int = 0
	for ago in range(mini(window, PlayerInput.HISTORY) - 1, -1, -1):
		if input.direction(facing, ago) == motion[step]:
			step += 1
			if step == motion.size():
				return true
	return false
