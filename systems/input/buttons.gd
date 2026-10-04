class_name Buttons
## The inputs a player has, as bits of one integer per tick.

const LEFT: int = 1
const RIGHT: int = 2
const UP: int = 4
const DOWN: int = 8
const LIGHT: int = 16
const JUMP: int = 32
const LANE_UP: int = 64
const LANE_DOWN: int = 128

## Action name suffix for each bit, used by the device source ("p1_left", ...).
const NAMES: Dictionary[int, String] = {
	LEFT: "left", RIGHT: "right", UP: "up", DOWN: "down",
	LIGHT: "light", JUMP: "jump", LANE_UP: "lane_up", LANE_DOWN: "lane_down",
}
