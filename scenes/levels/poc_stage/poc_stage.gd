extends Node2D
## Proof of concept (issue #17): one playable character on an empty 1080p stage
## with three lanes. It tests positions that are still proposed. Nothing here
## is a decision.
##
## This scene owns the clock: everything is ticked from _physics_process, in a
## fixed order, 60 times a second.

const SCREEN := Vector2(1920.0, 1080.0)
const LANE_Y: PackedFloat32Array = [760.0, 880.0, 1000.0]  # back to front
const MARGIN: float = 120.0
## Private art goes here. The folder is git-ignored and hidden from Godot's importer.
const LOCAL_SKIN: String = "res://local/skins/player"
const HELP: String = "Move: A D or stick    Jump: W, K or (B)    Crouch: S    Lane: Q E or shoulders
Attack: J or (X)    Fireball: down, down-forward, forward + attack    F1: boxes"

var _player_input: PlayerInput
var _fighter: Fighter
var _view: FighterView
var _projectiles: Projectiles
var _label: Label
var _history: Array[int] = []  # recent stick positions, for the readout


func _ready() -> void:
	_player_input = PlayerInput.new(1, InputSource.Device.new(1))

	_fighter = Fighter.new()
	_fighter.bounds = Vector2(MARGIN, SCREEN.x - MARGIN)
	_fighter.moves = [
		preload("res://data/moves/poc/fireball.tres"),
		preload("res://data/moves/poc/light.tres"),
	]
	add_child(_fighter)
	_fighter.setup(_player_input, LANE_Y, 1, SCREEN.x / 2.0)

	_view = FighterView.new()
	_view.skin = FighterSkin.load_from(LOCAL_SKIN)
	_fighter.add_child(_view)

	_projectiles = Projectiles.new()
	_projectiles.bounds = Vector2(0.0, SCREEN.x)
	add_child(_projectiles)
	_fighter.projectiles = _projectiles

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0, 16.0)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)


func _physics_process(_delta: float) -> void:
	_fighter.tick()
	_projectiles.tick()
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	# A debug key, read directly on purpose: it is not a player's input.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_view.show_boxes = not _view.show_boxes


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.15, 0.165, 0.21))
	draw_rect(Rect2(0.0, 640.0, SCREEN.x, SCREEN.y - 640.0), Color(0.305, 0.275, 0.243))
	for y in LANE_Y:
		draw_line(Vector2(0.0, y), Vector2(SCREEN.x, y), Color(0.42, 0.385, 0.34), 3.0)


func _update_readout() -> void:
	var direction: int = _player_input.direction(_fighter.facing)
	if _history.is_empty() or _history[-1] != direction:
		_history.append(direction)
		if _history.size() > 12:
			_history.pop_front()
	var move_text: String = ""
	if _fighter.move != null:
		move_text = "   %s %d/%d" % [_fighter.move.animation, _fighter.move_frame, _fighter.move.total_frames]
	_label.text = "%s\n%s%s   lane %d   %s   stick %s   skin: %s   %d fps" % [
		HELP, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1,
		"right" if _fighter.facing > 0 else "left", " ".join(_history),
		"local" if _view.skin != null else "plain figure", Engine.get_frames_per_second(),
	]
