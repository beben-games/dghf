class_name CommandReader
## Recognises motion commands in a player's input history.

const QUARTER_CIRCLE_FORWARD: PackedInt32Array = [2, 3, 6]
const DEFAULT_WINDOW: int = 24  # ticks the whole motion may take


## True if the stick went through `motion` (numpad directions, relative to
## `facing`) in order within the last `window` ticks. Other positions in
## between are allowed. The same direction twice in a row in the motion means
## two separate taps: the stick has to leave it in between, so holding down
## is not "down, down".
static func matches(input: PlayerInput, motion: PackedInt32Array, facing: int, window: int = DEFAULT_WINDOW) -> bool:
	if motion.is_empty():
		return true
	var step: int = 0
	var left_it: bool = true  # whether the stick has left the previous step's direction
	for ago in range(mini(window, PlayerInput.HISTORY) - 1, -1, -1):
		var direction: int = input.direction(facing, ago)
		if step > 0 and direction != motion[step - 1]:
			left_it = true
		if direction == motion[step] and (step == 0 or motion[step] != motion[step - 1] or left_it):
			step += 1
			left_it = false
			if step == motion.size():
				return true
	return false
