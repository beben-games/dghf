class_name InputSource
extends RefCounted
## Where a player's inputs come from. One sample per tick, as Buttons bits.
## The game only ever sees this, never a device.


func sample(_player: int) -> int:
	return 0


## Reads the keyboard and one gamepad through input actions named "p<player>_<button>".
class Device:
	extends InputSource

	func _init(player: int) -> void:
		_register(player)

	func sample(player: int) -> int:
		var mask: int = 0
		for bit: int in Buttons.NAMES:
			if Input.is_action_pressed("p%d_%s" % [player, Buttons.NAMES[bit]]):
				mask |= bit
		return mask

	## Gamepad number player - 1, and for player 1 the keyboard as well.
	static func _register(player: int) -> void:
		var pad: int = player - 1
		var keys: Dictionary[int, Array] = {
			Buttons.LEFT: [KEY_A, KEY_LEFT], Buttons.RIGHT: [KEY_D, KEY_RIGHT],
			Buttons.UP: [KEY_W, KEY_UP], Buttons.DOWN: [KEY_S, KEY_DOWN],
			Buttons.LIGHT: [KEY_J], Buttons.JUMP: [KEY_K, KEY_SPACE],
			Buttons.LANE_UP: [KEY_Q], Buttons.LANE_DOWN: [KEY_E],
		}
		var pad_buttons: Dictionary[int, JoyButton] = {
			Buttons.LEFT: JOY_BUTTON_DPAD_LEFT, Buttons.RIGHT: JOY_BUTTON_DPAD_RIGHT,
			Buttons.UP: JOY_BUTTON_DPAD_UP, Buttons.DOWN: JOY_BUTTON_DPAD_DOWN,
			Buttons.LIGHT: JOY_BUTTON_X, Buttons.JUMP: JOY_BUTTON_B,
			Buttons.LANE_UP: JOY_BUTTON_LEFT_SHOULDER, Buttons.LANE_DOWN: JOY_BUTTON_RIGHT_SHOULDER,
		}
		# Left stick: axis and the direction that counts as pressed.
		var stick: Dictionary[int, Vector2i] = {
			Buttons.LEFT: Vector2i(JOY_AXIS_LEFT_X, -1), Buttons.RIGHT: Vector2i(JOY_AXIS_LEFT_X, 1),
			Buttons.UP: Vector2i(JOY_AXIS_LEFT_Y, -1), Buttons.DOWN: Vector2i(JOY_AXIS_LEFT_Y, 1),
		}
		for bit: int in Buttons.NAMES:
			var action: String = "p%d_%s" % [player, Buttons.NAMES[bit]]
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action, 0.5)
			var button := InputEventJoypadButton.new()
			button.device = pad
			button.button_index = pad_buttons[bit]
			InputMap.action_add_event(action, button)
			if stick.has(bit):
				var motion := InputEventJoypadMotion.new()
				motion.device = pad
				motion.axis = stick[bit].x as JoyAxis
				motion.axis_value = stick[bit].y
				InputMap.action_add_event(action, motion)
			if player == 1:
				for keycode: Key in keys[bit]:
					var key := InputEventKey.new()
					key.physical_keycode = keycode
					InputMap.action_add_event(action, key)


## Plays back a fixed list of samples, one per tick. For tests and replays.
class Scripted:
	extends InputSource

	var samples: PackedInt32Array = PackedInt32Array()
	var _next: int = 0

	func _init(script_samples: PackedInt32Array = PackedInt32Array()) -> void:
		samples = script_samples

	func sample(_player: int) -> int:
		var mask: int = samples[_next] if _next < samples.size() else 0
		_next += 1
		return mask
