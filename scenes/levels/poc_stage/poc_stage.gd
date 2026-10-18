class_name PocStage
extends Node2D
## The sandbox stage (issues #17, #9, #48, #54, #58): one playable character
## on a 1080p stage with three lanes, against the big dummy (the boss fight)
## or waves of small fry in arenas along a stage three screens wide (the
## melee), under a camera that follows. It tests positions that are still
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
## The melee and the sandbox are this wide; the boss fight stays one screen
## (docs/design/2026-10-17-camera-and-scrolling-stage.md, proposed).
const STAGE_WIDTH: float = SCREEN.x * 3.0
## The melee's arenas: the camera locks in each until its waves are beaten, then the player walks on.
const MELEE_ARENAS: Array[Dictionary] = [
	{"left": 0.0, "right": 2400.0, "waves": [10, 10]},
	{"left": 3360.0, "right": 5760.0, "waves": [10, 15]},
]
## A wave comes in from this far past the view's edges.
const SPAWN_GAP: float = 100.0
## The backdrop repeats every this many pixels.
const BACKDROP_SPAN: float = 2400.0
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
var _camera: StageCamera
var _arenas: Arenas = Arenas.new()
var _label: Label
var _combo_label: Label
var _go_label: Label
var _shake: float = 0.0
var _tick: int = 0
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
## The big line in the middle: DOWN, or CLEAR.
var _message: Label
var _pause_label: Label
var _pause_back: ColorRect
var _paused: bool = false

@onready var _fighter: Fighter = $Player


func _ready() -> void:
	_player_input = PlayerInput.new(1, InputSource.Device.new(1))

	_camera = StageCamera.new()
	add_child(_camera)
	_camera.make_current()
	_add_backdrop(0.2, true, -2)
	_add_backdrop(0.5, false, -1)

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
	_message = Label.new()
	_message.position = Vector2(0.0, 400.0)
	_message.size.x = SCREEN.x
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 72)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 14)
	_message.visible = false
	layer.add_child(_message)
	_go_label = Label.new()
	_go_label.position = Vector2(SCREEN.x - 420.0, 440.0)
	_go_label.add_theme_font_size_override("font_size", 96)
	_go_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_go_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_go_label.add_theme_constant_override("outline_size", 16)
	_go_label.text = "GO  >>"
	_go_label.visible = false
	layer.add_child(_go_label)
	_pause_back = ColorRect.new()
	_pause_back.position = Vector2(80.0, 260.0)
	_pause_back.size = Vector2(SCREEN.x - 160.0, 440.0)
	_pause_back.color = Color(0.05, 0.05, 0.07, 0.88)
	_pause_back.visible = false
	layer.add_child(_pause_back)
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


## The boss fight: one screen, the dummy fights back and the lanes are closest (the camera "closer").
## The melee: a stage three screens wide with two arenas of waves. The sandbox: the same stage, free.
func _apply_mode() -> void:
	_clear_dummies()
	var width: float = SCREEN.x if mode == Mode.BOSS_FIGHT else STAGE_WIDTH
	_arenas.setup(width, MELEE_ARENAS if mode == Mode.MELEE else [])
	_camera.set_limits(0.0, width)
	_camera.snap(SCREEN.x / 2.0)
	_update_bounds()
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
	# The whole stage: a dummy left behind walks back on its own.
	dummy.bounds = Vector2(MARGIN, _arenas.stage_width - MARGIN)
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
	# The camera follows, the arenas lock it or let it go, and the bounds follow the view.
	_camera.tick(PackedFloat32Array([_fighter.x]), _fighter.facing)
	if _fighter.state != Fighter.State.DEAD:
		_arenas.tick(_tick, _camera.left(), _camera.right(), _crowd.count(), _spawn_wave)
	var limits: Vector2 = _arenas.limits()
	_camera.set_limits(limits.x, limits.y)
	_update_bounds()
	_update_shake()
	_update_combo()
	_update_readout()


## Where everyone may stand: the player inside the view, the crowd and the
## big dummies anywhere on the stage (a wave walks in from off screen, and
## one left behind follows), projectiles a little past the view.
func _update_bounds() -> void:
	_fighter.bounds = _camera.player_bounds(MARGIN)
	_crowd.set_bounds(Vector2(0.0, _arenas.stage_width))
	_projectiles.bounds = Vector2(_camera.left() - 400.0, _camera.right() + 400.0)


func _unhandled_input(event: InputEvent) -> void:
	# A debug key, read directly on purpose: it is not a player's input.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_paused = not _paused
				_pause_label.visible = _paused
				_pause_back.visible = _paused
			KEY_ESCAPE:
				_paused = false
				_pause_label.visible = false
				_pause_back.visible = false
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
				_crowd.spawn(randi_range(0, 2), _in_front(), -_fighter.facing)
			KEY_2:
				_add_dummy(_fighter.lane, _in_front(), -_fighter.facing)
			KEY_R:
				_start_over()


## A spot 320 pixels in front of the player, kept on screen.
func _in_front() -> float:
	return clampf(_fighter.x + _fighter.facing * 320.0, _fighter.bounds.x, _fighter.bounds.y)


## A wave of small fry from just off screen on both sides, spread over the
## lanes, facing in. A side at the stage's end sends its share from the other
## side; with no room on either side (a one-screen stage) they stand at the edges.
func _spawn_wave(how_many: int) -> void:
	var open_left: bool = _camera.left() - SPAWN_GAP > 0.0
	var open_right: bool = _camera.right() + SPAWN_GAP < _arenas.stage_width
	for i in how_many:
		var from_left: bool = i % 2 == 0
		if open_left != open_right:
			from_left = open_left
		@warning_ignore("integer_division")
		var step: float = 40.0 * (i / 2)
		var at_x: float
		if from_left:
			at_x = _camera.left() - SPAWN_GAP - step if open_left else _camera.left() + MARGIN + step
		else:
			at_x = _camera.right() + SPAWN_GAP + step if open_right else _camera.right() - MARGIN - step
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


## The ground, the whole stage long. The sky and what stands on the horizon are the backdrop's.
func _draw() -> void:
	# Drawn past the stage's ends, so a shake never shows an edge.
	var bleed: float = 64.0
	var width: float = _arenas.stage_width
	# The ground starts a little above the back lane, so a lower camera also lowers the horizon.
	var horizon: float = lanes()[0] - 120.0
	draw_rect(Rect2(-bleed, horizon, width + bleed * 2.0, SCREEN.y - horizon + bleed), Color(0.305, 0.275, 0.243))
	for y in lanes():
		draw_line(Vector2(-bleed, y), Vector2(width + bleed, y), Color(0.42, 0.385, 0.34), 3.0)
	# A post just inside each arena wall, so the player sees where the camera holds.
	for arena in _arenas.arenas:
		for wall in [[arena["left"], 1.0], [arena["right"], -1.0]]:
			var wall_x: float = wall[0]
			if wall_x > 0.0 and wall_x < width:
				draw_rect(Rect2(wall_x + wall[1] * 30.0 - 8.0, horizon - 60.0, 16.0, SCREEN.y - horizon + 60.0), Color(0.22, 0.19, 0.17))


## A placeholder backdrop layer that scrolls at `speed` times the camera's,
## repeating along the stage. Art replaces it.
func _add_backdrop(speed: float, far: bool, z: int) -> void:
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(speed, 0.0)
	layer.repeat_size = Vector2(BACKDROP_SPAN, 0.0)
	layer.repeat_times = 3
	layer.z_index = z
	var art := Backdrop.new()
	art.far = far
	layer.add_child(art)
	add_child(layer)


## Shakes the camera, side to side on alternate ticks, fading out. The
## readout is on its own layer and stays still.
func _update_shake() -> void:
	_shake = maxf(_shake * 0.8, _combat.shake)
	if _shake < 0.5:
		_shake = 0.0
	_camera.shake(_shake, _tick)


## The counter shows the player's hits in a row, on anyone, from the second hit.
func _update_combo() -> void:
	var hits: int = _combat.combo_of(_fighter)
	_combo_label.visible = hits >= 2
	_combo_label.text = "%d HITS" % hits
	_health_bar.size.x = 396.0 * float(_fighter.health) / _fighter.max_health
	if _fighter.state == Fighter.State.DEAD:
		_message.text = "DOWN    R to start over"
	elif _arenas.done:
		_message.text = "CLEAR    R to start over"
	_message.visible = _fighter.state == Fighter.State.DEAD or _arenas.done
	# Between arenas the arrow flashes until the next one locks.
	_go_label.visible = _arenas.between() and (_tick / 20) % 2 == 0


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
	# The readout: what the player is doing, who is on the stage, and the frame rate.
	var move_text: String = ""
	if _fighter.move != null:
		move_text = " %s %d/%d" % [_fighter.move.id, _fighter.move_frame, _fighter.move.total_frames]
	var where: String = "x %d" % int(_fighter.x)
	if _arenas.locked:
		where += "   arena %d of %d, wave %d of %d" % [_arenas.index + 1, _arenas.arenas.size(), _arenas.waves_sent, _arenas.wave_count()]
	elif _arenas.between():
		where += "   walk on"
	_label.text = "%s\n%s%s   lane %d   %s   %d fps   enemies %s" % [
		HELP, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1, where, Engine.get_frames_per_second(),
		"fighting back" if _fighting else "guarding" if _dummy_guards else "standing still",
	]


## Plain shapes until the art arrives: the far layer is the sky with hills and
## a castle on the horizon, the near one tents and trees. Everything stands on
## a base below the lowest horizon, so the ground covers its feet at any preset.
class Backdrop:
	extends Node2D

	const SPAN: float = 2400.0
	const BASE: float = 1080.0

	var far: bool = false

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 if far else 23
		if far:
			# The sky, darker up high, in bands down to the horizon; the lowest band goes to the base.
			var bands: int = 8
			for i in bands:
				var top: float = -200.0 + i * 120.0
				var bottom: float = top + 120.0 if i < bands - 1 else BASE + 200.0
				draw_rect(Rect2(0.0, top, SPAN, bottom - top), Color(0.36, 0.44, 0.6).lerp(Color(0.52, 0.58, 0.7), float(i) / (bands - 1)))
			for i in 7:
				var cx: float = i * SPAN / 7.0 + rng.randf_range(0.0, 200.0)
				var r: float = rng.randf_range(260.0, 460.0)
				draw_circle(Vector2(cx, 660.0 + r * 0.55), r, Color(0.3, 0.36, 0.48))
			# A castle: a wall and three towers.
			var castle_x: float = 1500.0
			draw_rect(Rect2(castle_x, 560.0, 420.0, BASE - 560.0), Color(0.25, 0.28, 0.38))
			for tower_x: float in [castle_x - 40.0, castle_x + 180.0, castle_x + 400.0]:
				draw_rect(Rect2(tower_x, 470.0, 70.0, BASE - 470.0), Color(0.25, 0.28, 0.38))
				for k in 3:
					draw_rect(Rect2(tower_x + k * 26.0, 452.0, 16.0, 20.0), Color(0.25, 0.28, 0.38))
		else:
			for i in 5:
				var cx: float = i * SPAN / 5.0 + rng.randf_range(40.0, 300.0)
				if rng.randf() < 0.5:
					# A tent: a triangle on a tall base.
					var top: float = rng.randf_range(540.0, 600.0)
					var w: float = rng.randf_range(140.0, 220.0)
					draw_colored_polygon(PackedVector2Array([Vector2(cx, top), Vector2(cx + w, 690.0), Vector2(cx - w, 690.0)]), Color(0.3, 0.27, 0.33))
					draw_rect(Rect2(cx - w, 688.0, w * 2.0, BASE - 688.0), Color(0.3, 0.27, 0.33))
				else:
					# A tree: a trunk and a round top.
					var top: float = rng.randf_range(420.0, 520.0)
					draw_rect(Rect2(cx - 18.0, top, 36.0, BASE - top), Color(0.24, 0.2, 0.2))
					draw_circle(Vector2(cx, top), rng.randf_range(80.0, 120.0), Color(0.22, 0.3, 0.26))
