extends Node2D
## Proof of concept (issues #17 and #9): one playable character and a training
## dummy on an empty 1080p stage with three lanes. It tests positions that are
## still proposed. Nothing here is a decision.
##
## The Player and Dummy nodes are in the scene, so their values can be tuned in
## the editor's inspector.
##
## This scene owns the clock: everything is ticked from _physics_process, in a
## fixed order, 60 times a second.

const SCREEN := Vector2(1920.0, 1080.0)
const LANE_Y: PackedFloat32Array = [760.0, 880.0, 1000.0]  # back to front
const MARGIN: float = 120.0
## Private art goes here. The folder is git-ignored and hidden from Godot's importer.
const LOCAL_SKIN: String = "res://local/skins/player"
const HELP: String = "Move: A D or stick    Jump: W, K or (B)    Crouch: S    Lane: Q E or shoulders
Attack: J or (X)    Heavy: L or (Y)    Both work in a jump    Fireball: down, down-forward, forward + attack    F1: boxes"
## How long the combo counter stays after a combo ends, in ticks.
const COMBO_LINGER: int = 60

var _player_input: PlayerInput
var _view: FighterView
var _dummy_view: FighterView
var _projectiles: Projectiles
var _sparks: HitSparks
var _combat: Combat = Combat.new()
var _label: Label
var _combo_label: Label
var _combo_linger: int = 0
var _shake: float = 0.0
var _tick: int = 0
var _history: Array[int] = []  # recent stick positions, for the readout

@onready var _fighter: Fighter = $Player
@onready var _dummy: Fighter = $Dummy


func _ready() -> void:
	_player_input = PlayerInput.new(1, InputSource.Device.new(1))

	_fighter.bounds = Vector2(MARGIN, SCREEN.x - MARGIN)
	_fighter.moves = [
		preload("res://data/moves/poc/fireball.tres"),
		preload("res://data/moves/poc/light.tres"),
		preload("res://data/moves/poc/heavy.tres"),
		preload("res://data/moves/poc/air_light.tres"),
		preload("res://data/moves/poc/air_heavy.tres"),
	]
	_fighter.setup(_player_input, LANE_Y, 1, SCREEN.x / 2.0)

	_view = FighterView.new()
	_view.skin = FighterSkin.load_from(LOCAL_SKIN)
	_fighter.add_child(_view)

	# The dummy never presses anything: the plain input source is always empty.
	_dummy.bounds = _fighter.bounds
	_dummy.setup(PlayerInput.new(0, InputSource.new()), LANE_Y, 1, SCREEN.x * 0.7)
	_dummy.facing = -1
	_dummy_view = FighterView.new()
	_dummy_view.body_color = Color(0.75, 0.4, 0.3)
	_dummy.add_child(_dummy_view)

	_projectiles = Projectiles.new()
	_projectiles.bounds = Vector2(0.0, SCREEN.x)
	_projectiles.z_index = LANE_Y.size()
	add_child(_projectiles)
	_fighter.projectiles = _projectiles

	_sparks = HitSparks.new()
	_sparks.z_index = LANE_Y.size()
	add_child(_sparks)

	_combat.fighters = [_fighter, _dummy]
	_combat.projectiles = _projectiles
	_combat.sparks = _sparks

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0, 16.0)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	_combo_label = Label.new()
	_combo_label.position = Vector2(SCREEN.x - 520.0, 180.0)
	_combo_label.add_theme_font_size_override("font_size", 96)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_label.add_theme_constant_override("outline_size", 16)
	layer.add_child(_combo_label)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_fighter.tick()
	_dummy.tick()
	_projectiles.tick()
	_sparks.tick()
	_combat.resolve()
	_update_shake()
	_update_combo()
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	# A debug key, read directly on purpose: it is not a player's input.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_view.show_boxes = not _view.show_boxes
		_dummy_view.show_boxes = _view.show_boxes


func _draw() -> void:
	# Drawn wider than the screen, so a shake never shows an edge.
	var bleed: float = 64.0
	draw_rect(Rect2(Vector2.ZERO, SCREEN).grow(bleed), Color(0.15, 0.165, 0.21))
	draw_rect(Rect2(-bleed, 640.0, SCREEN.x + bleed * 2.0, SCREEN.y - 640.0 + bleed), Color(0.305, 0.275, 0.243))
	for y in LANE_Y:
		draw_line(Vector2(-bleed, y), Vector2(SCREEN.x + bleed, y), Color(0.42, 0.385, 0.34), 3.0)


## Shakes the whole stage, side to side on alternate ticks, fading out. The
## readout is on its own layer and stays still.
func _update_shake() -> void:
	_shake = maxf(_shake * 0.8, _combat.shake)
	if _shake < 0.5:
		_shake = 0.0
	var side: float = 1.0 if _tick % 2 == 0 else -1.0
	position = Vector2(_shake * side, -_shake * 0.5 * side)


## The counter shows the dummy's combo from the second hit, and lingers a moment.
func _update_combo() -> void:
	_combo_linger = COMBO_LINGER if _dummy.in_hit_reaction() else maxi(_combo_linger - 1, 0)
	_combo_label.visible = _dummy.combo_hits >= 2 and _combo_linger > 0
	_combo_label.text = "%d HITS" % _dummy.combo_hits


func _update_readout() -> void:
	var direction: int = _player_input.direction(_fighter.facing)
	if _history.is_empty() or _history[-1] != direction:
		_history.append(direction)
		if _history.size() > 12:
			_history.pop_front()
	var move_text: String = ""
	if _fighter.move != null:
		move_text = "   %s %d/%d" % [_fighter.move.animation, _fighter.move_frame, _fighter.move.total_frames]
	_label.text = "%s\n%s%s   lane %d   %s   stick %s   skin: %s   %d fps\ndummy: %s   last combo %d hits, %d damage" % [
		HELP, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1,
		"right" if _fighter.facing > 0 else "left", " ".join(_history),
		"local" if _view.skin != null else "plain figure", Engine.get_frames_per_second(),
		Fighter.STATE_NAMES[_dummy.state], _dummy.combo_hits, _dummy.combo_damage,
	]
