class_name PocStage
extends Node2D
## The sandbox stage (issues #17, #9, #48, #54): one playable character on an
## empty 1080p stage with three lanes, against the big dummy (the boss fight)
## or endless small fry (the melee). It tests positions that are still
## proposed. Nothing here is a decision.
##
## The Player and Dummy nodes are in the scene, so their values can be tuned in
## the editor's inspector.
##
## This scene owns the clock: everything is ticked from _physics_process, in a
## fixed order, 60 times a second.

enum Mode { BOSS_FIGHT, MELEE, SANDBOX }

## Which fight the menu picked. The menu sets it before changing scene.
static var mode: Mode = Mode.BOSS_FIGHT

const SCREEN := Vector2(1920.0, 1080.0)
## The melee keeps this many small fry coming: a new wave of ten whenever fewer are left,
## with at least `WAVE_GAP` ticks between waves.
const MELEE_WAVE: int = 10
const WAVE_GAP: int = 240
const MENU: String = "res://scenes/main/main.tscn"
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
const HELP: String = "Tab: pause menu, with every control and key"
const PAUSE_HELP: String = """PAUSED        Tab or Esc: back to the fight        M: main menu

Move: A, D or the stick         Jump: W, Space or (A)         Crouch: S         Change lane: Q, E or the shoulders
Light attack: J or (X)          Heavy attack, a launcher: L or (Y)          Both work in a jump
Guard: hold K or (B)            Dodge: Shift or the right trigger, with a direction or alone to step back
Specials, with J for the light version or L for the heavy one, twice as big and twice as hard but asking a cleaner motion:
Fireball: down, down-forward, forward        Missiles, homing across lanes: forward, then down-forward        Blast around you, every lane: tap down twice
Super fireball: the fireball motion twice, then L: huge, and goes through everyone
Combo: J, J, L, then hold W to jump after the launch, then J and L in the air

F1: hitboxes and hurtboxes      F2: lane spacing and depth      F3: shade the back lanes
F4: the big dummies guard       F5: every enemy fights back, or stands still       F6: ten more small fry      R: start over
1: a small fry in front of you          2: a big dummy in front of you"""

var _player_input: PlayerInput
var _view: FighterView
## The big dummies: full fighters of team 2, as many as the sandbox adds (one in the boss fight).
var _dummies: Array[Fighter] = []
var _dummy_views: Array[FighterView] = []
var _projectiles: Projectiles
var _sparks: HitSparks
var _combat: Combat = Combat.new()
var _label: Label
var _combo_label: Label
var _shake: float = 0.0
var _tick: int = 0
var _history: Array[int] = []  # recent stick positions, for the readout
## The preset the stage starts in: lanes 50 pixels apart with depth (Ben's pick, 2026-10-11). F2 cycles.
var _preset: int = 2  # index into PRESETS
var _shading: bool = false
## Whether the enemies, big and small alike, fight back or stand still (F5).
var _fighting: bool = false
## Whether the big dummies hold their guard (F4).
var _dummy_guards: bool = false
var _crowd: CrowdDirector
var _health_bar: ColorRect
var _health_back: ColorRect
var _dead_label: Label
var _pause_label: Label
var _paused: bool = false
var _wave_tick: int = -100000

@onready var _fighter: Fighter = $Player


func _ready() -> void:
	_player_input = PlayerInput.new(1, InputSource.Device.new(1))

	_fighter.bounds = Vector2(MARGIN, SCREEN.x - MARGIN)
	# Tried in order: the super first, then the specials (heavy before light, since the heavy
	# version asks for a cleaner motion), then the normals.
	_fighter.moves = [
		preload("res://data/moves/poc/super_fireball.tres"),
		preload("res://data/moves/poc/fireball_heavy.tres"),
		preload("res://data/moves/poc/fireball.tres"),
		preload("res://data/moves/poc/missiles_heavy.tres"),
		preload("res://data/moves/poc/missiles_light.tres"),
		preload("res://data/moves/poc/blast_heavy.tres"),
		preload("res://data/moves/poc/blast_light.tres"),
		preload("res://data/moves/poc/light_2.tres"), preload("res://data/moves/poc/light.tres"),
		preload("res://data/moves/poc/heavy.tres"),
		preload("res://data/moves/poc/air_light.tres"),
		preload("res://data/moves/poc/air_heavy.tres"),
	]
	_fighter.max_health = 100
	_fighter.setup(_player_input, lanes(), 1, SCREEN.x / 2.0)
	_fighter.set_lanes(lanes(), scales())

	_view = FighterView.new()
	_view.skin = _find_skin()
	_fighter.add_child(_view)

	_projectiles = Projectiles.new()
	_projectiles.bounds = Vector2(0.0, SCREEN.x)
	_projectiles.z_index = 3
	add_child(_projectiles)
	_fighter.projectiles = _projectiles

	_sparks = HitSparks.new()
	_sparks.z_index = 3
	add_child(_sparks)

	_crowd = CrowdDirector.new()
	_crowd.setup(lanes(), scales(), _fighter.bounds)
	_crowd.target = _fighter
	add_child(_crowd)
	_combat.fighters = [_fighter]
	_apply_mode()
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
	_health_back = ColorRect.new()
	_health_back.position = Vector2(24.0, 196.0)
	_health_back.size = Vector2(400.0, 22.0)
	_health_back.color = Color(0.1, 0.1, 0.12, 0.8)
	layer.add_child(_health_back)
	_health_bar = ColorRect.new()
	_health_bar.position = Vector2(26.0, 198.0)
	_health_bar.size = Vector2(396.0, 18.0)
	_health_bar.color = Color(0.85, 0.2, 0.2)
	layer.add_child(_health_bar)
	_dead_label = Label.new()
	_dead_label.position = Vector2(SCREEN.x / 2.0 - 260.0, 400.0)
	_dead_label.add_theme_font_size_override("font_size", 72)
	_dead_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_dead_label.add_theme_constant_override("outline_size", 14)
	_dead_label.text = "DOWN    R to start over"
	_dead_label.visible = false
	layer.add_child(_dead_label)
	_pause_label = Label.new()
	_pause_label.position = Vector2(120.0, 300.0)
	_pause_label.add_theme_font_size_override("font_size", 30)
	_pause_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_pause_label.add_theme_constant_override("outline_size", 10)
	_pause_label.text = PAUSE_HELP
	_pause_label.visible = false
	layer.add_child(_pause_label)


## The player's skin, or null for the plain figure. Run from the project it is
## the local folder. A built game looks beside its executable instead, so art
## can be tried in a build without being packed into it.
func _find_skin() -> FighterSkin:
	if OS.has_feature("template"):
		return FighterSkin.load_from(OS.get_executable_path().get_base_dir().path_join(BUILD_SKIN))
	return FighterSkin.load_from(LOCAL_SKIN)


## The boss fight: the dummy fights back and the lanes are closest (the camera "closer").
## The melee: no dummy, ten small fry to start and a wave of ten whenever fewer are left.
func _apply_mode() -> void:
	_clear_dummies()
	if mode == Mode.BOSS_FIGHT:
		_preset = 3
		_add_dummy(1, SCREEN.x * 0.7, -1)
	else:
		_preset = 2
	_set_fighting(mode != Mode.SANDBOX)
	_dummy_guards = false
	_fighter.set_lanes(lanes(), scales())
	for dummy in _dummies:
		dummy.set_lanes(lanes(), scales())
	_crowd.set_lanes(lanes(), scales())
	queue_redraw()


## Everyone fights back, or everyone stands still: the small fry through the
## director, the big dummies through a brain each.
func _set_fighting(on: bool) -> void:
	_fighting = on
	_crowd.passive = not on
	for dummy in _dummies:
		dummy.input.source = _brain(dummy) if on else InputSource.new()


## A big dummy on `dummy_lane` at `at_x`, facing `face`, standing still.
func _add_dummy(dummy_lane: int, at_x: float, face: int) -> Fighter:
	var dummy := Fighter.new()
	dummy.team = 2
	dummy.bounds = _fighter.bounds
	# Its moves, for when it fights back: the two attacks, no specials, no air moves.
	dummy.moves = [
		preload("res://data/moves/poc/light_2.tres"),
		preload("res://data/moves/poc/light.tres"),
		preload("res://data/moves/poc/heavy.tres"),
	]
	add_child(dummy)
	dummy.setup(PlayerInput.new(0, InputSource.new()), lanes(), dummy_lane, at_x)
	dummy.set_lanes(lanes(), scales())
	dummy.facing = face
	var view := FighterView.new()
	view.body_color = Color(0.75, 0.4, 0.3)
	view.show_boxes = _view.show_boxes
	dummy.add_child(view)
	_dummies.append(dummy)
	_dummy_views.append(view)
	if _fighting:
		dummy.input.source = _brain(dummy)
	return dummy


func _clear_dummies() -> void:
	for dummy in _dummies:
		dummy.queue_free()
	_dummies.clear()
	_dummy_views.clear()


func _physics_process(_delta: float) -> void:
	if _paused:
		return
	_tick += 1
	if mode == Mode.MELEE and _crowd.count() < MELEE_WAVE and _tick - _wave_tick >= WAVE_GAP and _fighter.state != Fighter.State.DEAD:
		_wave_tick = _tick
		_spawn_wave(MELEE_WAVE)
	_fighter.tick()
	for dummy in _dummies:
		dummy.tick()
	_crowd.tick()
	var bodies: Array[Body] = [_fighter]
	bodies.append_array(_dummies)
	bodies.append_array(_crowd.alive())
	_combat.fighters = bodies
	_projectiles.tick(bodies)
	_sparks.tick()
	_combat.resolve()
	_update_shake()
	_update_combo()
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	# A debug key, read directly on purpose: it is not a player's input.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_paused = not _paused
				_pause_label.visible = _paused
			KEY_ESCAPE:
				_paused = false
				_pause_label.visible = false
			KEY_M:
				if _paused:
					get_tree().change_scene_to_file(MENU)
			KEY_F1:
				_view.show_boxes = not _view.show_boxes
				for view in _dummy_views:
					view.show_boxes = _view.show_boxes
			KEY_F2:
				_preset = (_preset + 1) % PRESETS.size()
				for fighter in _combat.fighters:
					fighter.set_lanes(lanes(), scales())
				_crowd.set_lanes(lanes(), scales())
				queue_redraw()
			KEY_F3:
				_shading = not _shading
			KEY_F4:
				_dummy_guards = not _dummy_guards
				if _dummy_guards:
					_fighting = false
					_crowd.passive = true
				for dummy in _dummies:
					dummy.input.source = InputSource.Held.new(Buttons.GUARD) if _dummy_guards else InputSource.new()
			KEY_F5:
				_dummy_guards = false
				_set_fighting(not _fighting)
			KEY_F6:
				_spawn_wave(10)
			KEY_1:
				_crowd.spawn(_fighter.lane, _in_front(), -_fighter.facing)
			KEY_2:
				_add_dummy(_fighter.lane, _in_front(), -_fighter.facing)
			KEY_R:
				_start_over()


## A spot 320 pixels in front of the player, kept on the stage.
func _in_front() -> float:
	return clampf(_fighter.x + _fighter.facing * 320.0, MARGIN, SCREEN.x - MARGIN)


## Ten small fry at the edges of the screen, spread over the lanes, facing the player.
func _spawn_wave(how_many: int) -> void:
	for i in how_many:
		var from_left: bool = i % 2 == 0
		@warning_ignore("integer_division")
		var at_x: float = MARGIN + 40.0 * (i / 2) if from_left else SCREEN.x - MARGIN - 40.0 * (i / 2)
		_crowd.spawn(i % 3, at_x, 1 if from_left else -1)


## The player back on its feet with full health, the crowd gone, the dummy still.
func _start_over() -> void:
	_crowd.clear()
	_fighter.setup(_player_input, lanes(), 1, SCREEN.x / 2.0)
	_fighter.set_lanes(lanes(), scales())
	_fighter.state = Fighter.State.IDLE
	_fighter.move = null
	_fighter.hitstop = 0
	_fighter.height = 0.0
	_wave_tick = -100000
	_apply_mode()


## A brain for a big dummy, fighting the player.
func _brain(dummy: Fighter) -> FighterBrain:
	var brain := FighterBrain.new(_tick + _dummies.size())
	brain.fighter = dummy
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


## The counter shows the player's hits in a row, on anyone, from the second hit.
func _update_combo() -> void:
	var hits: int = _combat.combo_of(_fighter)
	_combo_label.visible = hits >= 2
	_combo_label.text = "%d HITS" % hits
	_health_bar.size.x = 396.0 * float(_fighter.health) / _fighter.max_health
	_dead_label.visible = _fighter.state == Fighter.State.DEAD


func _update_readout() -> void:
	for body in _combat.fighters:
		# The back lane is darkest: a cheap depth cue that keeps pixel art sharp.
		var shade: float = 1.0 - 0.12 * (2 - body.lane) if _shading else 1.0
		if body is CrowdBody:
			(body as CrowdBody).set_shade(shade)
		elif body == _fighter:
			_view.shade = shade
		else:
			_dummy_views[_dummies.find(body)].shade = shade
	var direction: int = _player_input.direction(_fighter.facing)
	if _history.is_empty() or _history[-1] != direction:
		_history.append(direction)
		if _history.size() > 12:
			_history.pop_front()
	var move_text: String = ""
	if _fighter.move != null:
		move_text = "   %s %d/%d" % [_fighter.move.animation, _fighter.move_frame, _fighter.move.total_frames]
	_label.text = "%s\n%s%s   lane %d   %s   stick %s   skin: %s   %d fps   lanes %d px apart, back %.2fx front %.2fx%s\nenemies: %d big, %d small, %s   health: %d" % [
		HELP, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1,
		"right" if _fighter.facing > 0 else "left", " ".join(_history),
		"from a folder" if _view.skin != null else "plain figure", Engine.get_frames_per_second(),
		int(PRESETS[_preset]["spacing"]), scales()[0], scales()[2], ", shaded" if _shading else "",
		_dummies.size(), _crowd.count(), "fighting back" if _fighting else "guarding" if _dummy_guards else "standing still", _fighter.health,
	]
