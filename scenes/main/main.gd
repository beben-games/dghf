extends Node2D
## The sandbox's menu (issue #54): pick the boss fight or the melee. The game
## opens here. Keys read directly on purpose: it is a menu, not a player's input.

const STAGE: String = "res://scenes/levels/poc_stage/poc_stage.tscn"
const SCREEN := Vector2(1920.0, 1080.0)

const CHOICES: Array[String] = ["Boss fight", "Melee", "Sandbox"]

var _choice: int = 0  # index into CHOICES
var _labels: Array[Label] = []


func _ready() -> void:
	var title := _text(Vector2(0.0, 240.0), 84, "Hundred Years' War sandbox")
	title.size.x = SCREEN.x
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in CHOICES.size():
		_labels.append(_text(Vector2(0.0, 460.0 + 90.0 * i), 56, CHOICES[i]))
	for label in _labels:
		label.size.x = SCREEN.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := _text(Vector2(0.0, 760.0), 28, "Up and down, then Enter or Space.    In the fight, Tab opens the pause menu with every key.")
	help.size.x = SCREEN.x
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var what := _text(Vector2(0.0, 820.0), 24, "Boss fight: the big dummy fights back, with the camera closer.    Melee: the first level, two arenas of waves along a stage three screens wide, with results at the end.\nSandbox: an empty stage that scrolls freely; add the enemies you want, and they stand still until told.\nIn the melee and the sandbox, any button on a second or third gamepad joins a player.")
	what.size.x = SCREEN.x
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_show_choice()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.15, 0.165, 0.21))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_choice = posmod(_choice - 1, CHOICES.size())
			_show_choice()
		KEY_DOWN, KEY_S:
			_choice = posmod(_choice + 1, CHOICES.size())
			_show_choice()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J:
			_start()
		KEY_1:
			_choice = 0
			_start()
		KEY_2:
			_choice = 1
			_start()
		KEY_3:
			_choice = 2
			_start()


func _start() -> void:
	PocStage.mode = [PocStage.Mode.BOSS_FIGHT, PocStage.Mode.MELEE, PocStage.Mode.SANDBOX][_choice] as PocStage.Mode
	get_tree().change_scene_to_file(STAGE)


func _show_choice() -> void:
	for i in _labels.size():
		_labels[i].text = ("> %s <" if i == _choice else "%s") % CHOICES[i]
		_labels[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if i == _choice else Color.WHITE)


func _text(at: Vector2, size: int, text: String) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	add_child(label)
	return label
