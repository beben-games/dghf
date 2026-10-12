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
## The front lane's screen y. The other two sit above it, `spacing` apart.
const FRONT_LANE_Y: float = 1000.0
## Ways of showing depth to try, cycled with F2 (issue #17: T and E asked for a lower camera and
## more overlap between lanes, and Ben for fighters that get smaller further back rather than higher).
## `spacing` is the distance between lanes in pixels; `scales` is the size of a fighter in each lane,
## back to front, with the middle lane at full size.
const PRESETS: Array[Dictionary] = [
	{"spacing": 120.0, "scales": [1.0, 1.0, 1.0]},
	{"spacing": 70.0, "scales": [0.88, 1.0, 1.12]},
	{"spacing": 50.0, "scales": [0.8, 1.0, 1.2]},
	{"spacing": 35.0, "scales": [0.72, 1.0, 1.28]},
]
const MARGIN: float = 120.0
## Private art goes here. The folder is git-ignored and hidden from Godot's importer.
const LOCAL_SKIN: String = "res://local/skins/player"
## A built game has no local folder. It looks for a skin in this folder beside its executable.
const BUILD_SKIN: String = "skins/player"
const HELP: String = "Move: A D or stick    Jump: W, Space or (A)    Crouch: S    Lane: Q E or shoulders
Attack: J or (X)    Heavy: L or (Y)    Both work in a jump    Guard: hold K or (B)    Dodge: Shift or (RT), with a direction or back    Fireball: down, down-forward, forward + attack
F1: boxes    F2: lane spacing and depth    F3: shade the back lanes    F4: the dummy guards    F5: the dummy fights back"
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
var _preset: int = 0  # index into PRESETS
var _shading: bool = false
var _dummy_guards: bool = false
var _dummy_fights: bool = false

@onready var _fighter: Fighter = $Player
@onready var _dummy: Fighter = $Dummy


func _ready() -> void:
	_player_input = PlayerInput.new(1, InputSource.Device.new(1))

	_fighter.bounds = Vector2(MARGIN, SCREEN.x - MARGIN)
	_fighter.moves = [
		preload("res://data/moves/poc/fireball.tres"),
		preload("res://data/moves/poc/light_2.tres"), preload("res://data/moves/poc/light.tres"),
		preload("res://data/moves/poc/heavy.tres"),
		preload("res://data/moves/poc/air_light.tres"),
		preload("res://data/moves/poc/air_heavy.tres"),
	]
	_fighter.setup(_player_input, lanes(), 1, SCREEN.x / 2.0)
	_fighter.set_lanes(lanes(), scales())

	_view = FighterView.new()
	_view.skin = _find_skin()
	_fighter.add_child(_view)

	# The dummy never presses anything: the plain input source is always empty.
	_dummy.bounds = _fighter.bounds
	_dummy.setup(PlayerInput.new(0, InputSource.new()), lanes(), 1, SCREEN.x * 0.7)
	# Its moves, for when it fights back (F5): the two attacks, no fireball, no air moves.
	_dummy.moves = [
		preload("res://data/moves/poc/light_2.tres"),
		preload("res://data/moves/poc/light.tres"),
		preload("res://data/moves/poc/heavy.tres"),
	]
	_dummy.set_lanes(lanes(), scales())
	_dummy.facing = -1
	_dummy_view = FighterView.new()
	_dummy_view.body_color = Color(0.75, 0.4, 0.3)
	_dummy.add_child(_dummy_view)

	_projectiles = Projectiles.new()
	_projectiles.bounds = Vector2(0.0, SCREEN.x)
	_projectiles.z_index = 3
	add_child(_projectiles)
	_fighter.projectiles = _projectiles

	_sparks = HitSparks.new()
	_sparks.z_index = 3
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


## The player's skin, or null for the plain figure. Run from the project it is
## the local folder. A built game looks beside its executable instead, so art
## can be tried in a build without being packed into it.
func _find_skin() -> FighterSkin:
	if OS.has_feature("template"):
		return FighterSkin.load_from(OS.get_executable_path().get_base_dir().path_join(BUILD_SKIN))
	return FighterSkin.load_from(LOCAL_SKIN)


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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_view.show_boxes = not _view.show_boxes
				_dummy_view.show_boxes = _view.show_boxes
			KEY_F2:
				_preset = (_preset + 1) % PRESETS.size()
				for fighter in _combat.fighters:
					fighter.set_lanes(lanes(), scales())
				queue_redraw()
			KEY_F3:
				_shading = not _shading
			KEY_F4:
				_dummy_guards = not _dummy_guards
				_dummy_fights = false
				_dummy.input.source = InputSource.Held.new(Buttons.GUARD if _dummy_guards else 0)
			KEY_F5:
				_dummy_fights = not _dummy_fights
				_dummy_guards = false
				_dummy.input.source = _brain() if _dummy_fights else InputSource.new()


## A brain for the dummy, fighting the player.
func _brain() -> FighterBrain:
	var brain := FighterBrain.new(_tick)
	brain.fighter = _dummy
	brain.target = _fighter
	return brain


## The three lanes' screen y, back to front, in the preset being tried.
func lanes() -> PackedFloat32Array:
	var spacing: float = PRESETS[_preset]["spacing"]
	return PackedFloat32Array([FRONT_LANE_Y - 2.0 * spacing, FRONT_LANE_Y - spacing, FRONT_LANE_Y])


## How large a fighter is in each lane, back to front, in the preset being tried.
func scales() -> PackedFloat32Array:
	return PackedFloat32Array(PRESETS[_preset]["scales"])


func _draw() -> void:
	# Drawn wider than the screen, so a shake never shows an edge.
	var bleed: float = 64.0
	draw_rect(Rect2(Vector2.ZERO, SCREEN).grow(bleed), Color(0.15, 0.165, 0.21))
	# The ground starts a little above the back lane, so a lower camera also lowers the horizon.
	var horizon: float = lanes()[0] - 120.0
	draw_rect(Rect2(-bleed, horizon, SCREEN.x + bleed * 2.0, SCREEN.y - horizon + bleed), Color(0.305, 0.275, 0.243))
	for y in lanes():
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
	for fighter in _combat.fighters:
		var view: FighterView = _view if fighter == _fighter else _dummy_view
		# The back lane is darkest: a cheap depth cue that keeps pixel art sharp.
		view.shade = 1.0 - 0.12 * (2 - fighter.lane) if _shading else 1.0
	var direction: int = _player_input.direction(_fighter.facing)
	if _history.is_empty() or _history[-1] != direction:
		_history.append(direction)
		if _history.size() > 12:
			_history.pop_front()
	var move_text: String = ""
	if _fighter.move != null:
		move_text = "   %s %d/%d" % [_fighter.move.animation, _fighter.move_frame, _fighter.move.total_frames]
	_label.text = "%s\n%s%s   lane %d   %s   stick %s   skin: %s   %d fps   lanes %d px apart, back %.2fx front %.2fx%s\ndummy (%s): %s   last combo %d hits, %d damage" % [
		HELP, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1,
		"right" if _fighter.facing > 0 else "left", " ".join(_history),
		"from a folder" if _view.skin != null else "plain figure", Engine.get_frames_per_second(),
		int(PRESETS[_preset]["spacing"]), scales()[0], scales()[2], ", shaded" if _shading else "",
		"fighting back" if _dummy_fights else "guarding" if _dummy_guards else "still",
		Fighter.STATE_NAMES[_dummy.state], _dummy.combo_hits, _dummy.combo_damage,
	]
