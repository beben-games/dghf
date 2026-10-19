class_name PocStage
extends Node2D
## The sandbox stage (issues #17, #9, #48, #54, #58, #59): one to three
## players on a 1080p stage with three lanes, against the big dummy (the boss
## fight) or waves of small fry in arenas along a stage three screens wide
## (the melee), under a camera that follows them all. It tests positions that
## are still proposed. Nothing here is a decision.
##
## The Player node is in the scene, so its values can be tuned in the editor's
## inspector; players 2 and 3 are made from the same script when their pad
## joins (docs/design/2026-10-17-local-coop.md, proposed).
##
## This scene owns the clock: everything is ticked from _physics_process, in a
## fixed order, 60 times a second. A test calls tick() itself.

enum Mode { BOSS_FIGHT, MELEE, SANDBOX }

## Which fight the menu picked. The menu sets it before changing scene.
static var mode: Mode = Mode.BOSS_FIGHT

const SCREEN := Vector2(1920.0, 1080.0)
## The melee and the sandbox are this wide; the boss fight stays one screen
## (docs/design/2026-10-17-camera-and-scrolling-stage.md, proposed).
const STAGE_WIDTH: float = SCREEN.x * 3.0
## The melee is the first level (issue #62): arenas of waves as data.
const MELEE_LEVEL: Level = preload("res://data/levels/melee.tres")
## A wave comes in from this far past the view's edges.
const SPAWN_GAP: float = 100.0
## The backdrop repeats every this many pixels.
const BACKDROP_SPAN: float = 2400.0
const MENU: String = "res://scenes/main/main.tscn"
## The kinds of small fry (issue #61) and how a wave mixes them: every sixth from the second is
## fast, every sixth from the fourth shielded, every eighth from the seventh a thrower.
const KIND_FAST: CrowdKind = preload("res://data/enemies/fast.tres")
const KIND_SHIELDED: CrowdKind = preload("res://data/enemies/shielded.tres")
const KIND_THROWER: CrowdKind = preload("res://data/enemies/thrower.tres")
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
## Co-op (issue #59): how many may play, their colours, and where they stand.
const MAX_PLAYERS: int = 3
const PLAYER_COLORS: Array[Color] = [Color(0.35, 0.55, 0.85), Color(0.35, 0.75, 0.4), Color(0.9, 0.75, 0.3)]
## How far a skin is tinted toward the player's colour. Player 1's skin is left as drawn.
const SKIN_TINT: float = 0.45
## A joining player appears this far behind the first living player.
const JOIN_GAP: float = 160.0
## After R, the players stand this far apart around the middle of the screen.
const START_GAP: float = 220.0
## The mana bar's colours (issue #60): filling, full, and just short of a heavy spell.
const MANA_COLOR := Color(0.3, 0.55, 1.0)
const MANA_FULL_COLOR := Color(0.7, 0.85, 1.0)
const MANA_SHORT_COLOR := Color(0.9, 0.35, 0.3)
## The guard bar (issue #72): its size, the tank preset's (F8), and its colours above and below the floor.
const GUARD_BAR: int = 100
const TANK_GUARD: int = 300
const GUARD_COLOR := Color(0.92, 0.9, 0.82)
const GUARD_LOW_COLOR := Color(0.9, 0.4, 0.3)
## Private art goes here. The folder is git-ignored and hidden from Godot's importer.
const LOCAL_SKIN: String = "res://local/skins/player"
## A built game has no local folder. It looks for a skin in this folder beside its executable.
const BUILD_SKIN: String = "skins/player"
const HELP: String = "Tab: pause menu, with every control and key"
const JOIN_HELP: String = "        Any button on another pad joins, up to 3 players"
const PAUSE_HELP: String = """PAUSED        Tab or Esc: back to the fight        M: main menu

Move: A, D or the stick         Jump: W, Space or (A)         Crouch: S         Change lane: Q, E or the shoulders
Light attack: J or (X)          Heavy attack, a launcher: L or (Y)          Both work in a jump
Guard: hold K or (B)            Dash: Shift or the right trigger with a direction, held to keep running; alone, a step back
A landed hit frees you: after a swing connects, anything can follow at once. A miss commits you to the swing.
J or L while dashing is a running attack. Lights step you forward.
Specials, with J for the light version or L for the heavy one, twice as big and twice as hard but asking a cleaner motion:
Fireball: down, down-forward, forward        Missiles, homing across lanes: forward, then down-forward        Blast around you, every lane: tap down twice
Super fireball: the fireball motion twice, then L: huge, and goes through everyone
Mana: hits fill the blue bar. Light specials are free; heavy ones cost some of it and the super all of it.
A heavy you can't pay for comes out as its light version, and the bar flashes red. The melee starts empty.
Guard: blocking drains the white bar by the hit's damage; hits you land refill it, and a quiet moment too, slowly.
At zero the guard breaks: the hit launches you. Below a quarter the guard can't be raised.
The knight is a tank: holding the guard taunts, and small fry nearby converge on your lane, a few dawdling, and pile on from their side.
Combo: J, J, L, then hold W to jump after the launch, then J and L in the air

F1: hitboxes and hurtboxes      F2: lane spacing and depth      F3: shade the back lanes
F4: the big dummies guard       F5: every enemy fights back, or stands still       F6: ten more small fry      R: start over
F7: refill mana      F8: a tank's guard bar for player 1, three times bigger      F9: mute
1: a small fry in front of you          2: a big dummy          3: a fast one          4: a shielded one          5: a thrower          6: a barrel
Barrels break in two hits and drop a potion that heals 25: walk over it. The melee's arenas have a few.
Small fry: the fast one is weak and quick. The shielded one blocks from the front until the shield breaks (two heavies),
and winds up a shield bash with a red mark over its head that breaks your guard: dodge it. The thrower keeps back and throws rocks.
Co-op (melee and sandbox): any button on a second or third pad joins. The screen's edges hold the players together."""

## The players in the fight, player 1 first, and a view each. Everyone is team 1.
var players: Array[Fighter] = []
var views: Array[FighterView] = []
## The same players as bodies, shared with the crowd's director and the dummies' brains as their targets.
var _party: Array[Body] = []
## Where pads 2 and 3 wait to join. Ticked outside the boss fight.
var lobby: Lobby = Lobby.new()
## The big dummies: full fighters of team 2, as many as the sandbox adds (one in the boss fight).
var _dummies: Array[Fighter] = []
var _dummy_views: Array[FighterView] = []
var _projectiles: Projectiles
var _sparks: HitSparks
var _combat: Combat = Combat.new()
var camera: StageCamera
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
var crowd: CrowdDirector
## Barrels and potions (issue #64).
var props: Props
## The boss of the boss fight (issue #67), one of the big dummies, and its bar.
const BOSS: BossKind = preload("res://data/bosses/captain.tres")
var boss: Fighter
var _boss_bar: ColorRect
var _boss_back: ColorRect
var _boss_name: Label
var _boss_phase: ColorRect
## Ticks left of the intro banner at the start of a boss fight.
var _intro_ticks: int = 0
const INTRO_TICKS: int = 120
## A health bar per player, in its colour, with its tag, and a mana bar under it.
var health_bars: Array[ColorRect] = []
var mana_bars: Array[ColorRect] = []
var guard_bars: Array[ColorRect] = []
## Whether player 1 has the tank's guard bar (F8).
var _tank: bool = false
var _health_tags: Array[Label] = []
var _layer: CanvasLayer
## The big line in the middle: DOWN, or LEVEL CLEAR, and the results under it.
var _message: Label
var _results: Label
## The level's clock and the best combo seen, for the results (issue #62).
var _level_ticks: int = 0
var _best_combo: int = 0
var _pause_label: Label
var _pause_back: ColorRect
var _paused: bool = false

## Player 1, the node in the scene. The readout and the debug keys speak of it.
@onready var _fighter: Fighter = $Player
## The moves every player has. Tried in order: the super first, then the specials (heavy before
## light, since the heavy version asks for a cleaner motion), then the normals.
var _player_moves: Array[Move] = [
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
	preload("res://data/moves/poc/dash_light.tres"),
	preload("res://data/moves/poc/dash_heavy.tres"),
]
var _skin: FighterSkin


func _ready() -> void:
	camera = StageCamera.new()
	add_child(camera)
	camera.make_current()
	_add_backdrop(0.2, true, -2)
	_add_backdrop(0.5, false, -1)

	_projectiles = Projectiles.new()
	_projectiles.bounds = Vector2(0.0, SCREEN.x)
	_projectiles.z_index = 3
	add_child(_projectiles)

	_sparks = HitSparks.new()
	_sparks.z_index = 3
	add_child(_sparks)

	_layer = CanvasLayer.new()
	add_child(_layer)

	_skin = _find_skin()
	# Player 1 is always in, on the keyboard and the first pad. The other pads wait in the lobby.
	_add_player(PlayerInput.new(1, InputSource.Device.new(1)), _fighter, 1, SCREEN.x / 2.0, _start_lane())
	for index in range(2, MAX_PLAYERS + 1):
		lobby.add(index, InputSource.Device.new(index))

	props = Props.new()
	props.setup(lanes(), scales())
	add_child(props)

	add_child(Sounds.new())
	Sounds.music(true)

	crowd = CrowdDirector.new()
	crowd.projectiles = _projectiles
	crowd.setup(lanes(), scales(), _fighter.bounds)
	crowd.targets = _party
	add_child(crowd)
	_combat.fighters = [_fighter]
	_apply_mode()
	_combat.projectiles = _projectiles
	_combat.sparks = _sparks

	var layer: CanvasLayer = _layer
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
	_message = Label.new()
	_message.position = Vector2(0.0, 400.0)
	_message.size.x = SCREEN.x
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 72)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 14)
	_message.visible = false
	layer.add_child(_message)
	_results = Label.new()
	_results.position = Vector2(0.0, 500.0)
	_results.size.x = SCREEN.x
	_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results.add_theme_font_size_override("font_size", 40)
	_results.add_theme_color_override("font_outline_color", Color.BLACK)
	_results.add_theme_constant_override("outline_size", 10)
	_results.visible = false
	layer.add_child(_results)
	_go_label = Label.new()
	_go_label.position = Vector2(SCREEN.x - 420.0, 440.0)
	_go_label.add_theme_font_size_override("font_size", 96)
	_go_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_go_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_go_label.add_theme_constant_override("outline_size", 16)
	_go_label.text = "GO  >>"
	_go_label.visible = false
	layer.add_child(_go_label)
	# The boss's bar, top centre, with its name and the second phase's mark (issue #67).
	_boss_back = ColorRect.new()
	_boss_back.position = Vector2(SCREEN.x / 2.0 - 400.0, 110.0)
	_boss_back.size = Vector2(800.0, 26.0)
	_boss_back.color = Color(0.1, 0.1, 0.12, 0.8)
	_boss_back.visible = false
	layer.add_child(_boss_back)
	_boss_bar = ColorRect.new()
	_boss_bar.position = Vector2(SCREEN.x / 2.0 - 398.0, 112.0)
	_boss_bar.size = Vector2(796.0, 22.0)
	_boss_bar.color = Color(0.8, 0.25, 0.25)
	_boss_bar.visible = false
	layer.add_child(_boss_bar)
	_boss_phase = ColorRect.new()
	_boss_phase.position = Vector2(SCREEN.x / 2.0 - 400.0 + 800.0 * BOSS.phase_two_at - 2.0, 106.0)
	_boss_phase.size = Vector2(4.0, 34.0)
	_boss_phase.color = Color(1.0, 0.9, 0.6)
	_boss_phase.visible = false
	layer.add_child(_boss_phase)
	_boss_name = Label.new()
	_boss_name.position = Vector2(SCREEN.x / 2.0 - 400.0, 68.0)
	_boss_name.size.x = 800.0
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 32)
	_boss_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_boss_name.add_theme_constant_override("outline_size", 10)
	_boss_name.visible = false
	layer.add_child(_boss_name)
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


## A fighter for player `index`, driven by `input`, on `start_lane` at `start_x`:
## team 1 with full health and every move, a view in the player's colour, and a
## health bar. `fighter` is the scene's node for player 1, or null to make one.
func _add_player(input: PlayerInput, fighter: Fighter, index: int, start_x: float, start_lane: int) -> Fighter:
	if fighter == null:
		fighter = Fighter.new()
		add_child(fighter)
	var color: Color = PLAYER_COLORS[(index - 1) % PLAYER_COLORS.size()]
	fighter.team = 1
	fighter.bounds = camera.player_bounds(MARGIN)
	fighter.moves = _player_moves
	fighter.max_health = 100
	fighter.max_mana = 100
	fighter.max_guard = TANK_GUARD if _tank and fighter == _fighter else GUARD_BAR
	fighter.taunts = true  # the knight is a tank (Ben, 2026-10-17): its guard taunts
	fighter.projectiles = _projectiles
	fighter.setup(input, lanes(), start_lane, start_x)
	fighter.mana = _starting_mana(fighter)
	fighter.set_lanes(lanes(), scales())
	var view := FighterView.new()
	view.skin = _skin
	view.body_color = color
	view.tint = Color.WHITE if index == 1 else Color.WHITE.lerp(color, SKIN_TINT)
	view.show_boxes = views[0].show_boxes if not views.is_empty() else false
	fighter.add_child(view)
	players.append(fighter)
	views.append(view)
	_party.append(fighter)
	_add_health_bar(players.size() - 1, color)
	# With company, everyone wears a tag.
	for i in views.size():
		views[i].tag = "P%d" % players[i].input.player if players.size() > 1 else ""
	return fighter


## Where the bar starts (issue #60, proposed): empty in the melee, since hits
## fill it; full in the boss fight and the sandbox, so motions can be tried at once.
func _starting_mana(fighter: Fighter) -> int:
	return 0 if mode == Mode.MELEE else fighter.max_mana


## Player `slot`'s health bar (0 first), side by side at the top left, in `color`, with its tag,
## and its mana bar below.
func _add_health_bar(slot: int, color: Color) -> void:
	var left: float = 24.0 + 440.0 * slot
	var back := ColorRect.new()
	back.position = Vector2(left, 196.0)
	back.size = Vector2(400.0, 22.0)
	back.color = Color(0.1, 0.1, 0.12, 0.8)
	_layer.add_child(back)
	var bar := ColorRect.new()
	bar.position = Vector2(left + 2.0, 198.0)
	bar.size = Vector2(396.0, 18.0)
	bar.color = color
	_layer.add_child(bar)
	health_bars.append(bar)
	var mana_back := ColorRect.new()
	mana_back.position = Vector2(left, 222.0)
	mana_back.size = Vector2(400.0, 14.0)
	mana_back.color = Color(0.1, 0.1, 0.12, 0.8)
	_layer.add_child(mana_back)
	var mana_bar := ColorRect.new()
	mana_bar.position = Vector2(left + 2.0, 224.0)
	mana_bar.size = Vector2(396.0, 10.0)
	mana_bar.color = MANA_COLOR
	_layer.add_child(mana_bar)
	mana_bars.append(mana_bar)
	var guard_back := ColorRect.new()
	guard_back.position = Vector2(left, 240.0)
	guard_back.size = Vector2(400.0, 14.0)
	guard_back.color = Color(0.1, 0.1, 0.12, 0.8)
	_layer.add_child(guard_back)
	var guard_bar := ColorRect.new()
	guard_bar.position = Vector2(left + 2.0, 242.0)
	guard_bar.size = Vector2(396.0, 10.0)
	guard_bar.color = GUARD_COLOR
	_layer.add_child(guard_bar)
	guard_bars.append(guard_bar)
	var tag := Label.new()
	tag.position = Vector2(left, 160.0)
	tag.text = "P%d" % players[slot].input.player
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", color.lightened(0.3))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 8)
	tag.visible = players.size() > 1
	_layer.add_child(tag)
	_health_tags.append(tag)
	for t in _health_tags:
		t.visible = players.size() > 1


## A player joins with `input`, a step behind the first living player, in its
## lane, facing its way. The lobby hands the input over with the joining press
## already swallowed; a test may call this directly.
func join(input: PlayerInput) -> Fighter:
	var leader: Fighter = _leader()
	var at_x: float = clampf(leader.x - leader.facing * JOIN_GAP, leader.bounds.x, leader.bounds.y)
	var fighter: Fighter = _add_player(input, null, input.player, at_x, leader.lane)
	fighter.facing = leader.facing
	return fighter


## Where a fight starts: the front lane for the boss fight (Ben, 2026-10-17), the middle one otherwise.
func _start_lane() -> int:
	return 2 if mode == Mode.BOSS_FIGHT else 1


## The first living player, or player 1 when everyone is down.
func _leader() -> Fighter:
	for player in players:
		if player.state != Fighter.State.DEAD:
			return player
	return _fighter


func _anyone_alive() -> bool:
	for player in players:
		if player.state != Fighter.State.DEAD:
			return true
	return false


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
	if mode == Mode.MELEE:
		_arenas.setup_level(MELEE_LEVEL)
		width = _arenas.stage_width
	else:
		_arenas.setup(width, [])
	_level_ticks = 0
	_best_combo = 0
	props.clear()
	if mode == Mode.MELEE:
		for arena in MELEE_LEVEL.arenas:
			for spot in arena.props:
				props.spawn(Prop.Kind.BARREL, int(spot.y), spot.x)
	camera.reset_view()
	camera.set_limits(0.0, width)
	camera.snap(SCREEN.x / 2.0)
	_update_bounds()
	boss = null
	if mode == Mode.BOSS_FIGHT:
		_preset = 3
		boss = _add_boss(BOSS, _start_lane(), SCREEN.x * 0.7)
		_intro_ticks = INTRO_TICKS
	else:
		_preset = 2
	_set_fighting(mode != Mode.SANDBOX)
	_dummy_guards = false
	for player in players:
		player.set_lanes(lanes(), scales())
	for dummy in _dummies:
		dummy.set_lanes(lanes(), scales())
	crowd.set_lanes(lanes(), scales())
	props.set_lanes(lanes(), scales())
	queue_redraw()


## Everyone fights back, or everyone stands still: the small fry through the
## director, the big dummies through a brain each.
func _set_fighting(on: bool) -> void:
	_fighting = on
	crowd.passive = not on
	for dummy in _dummies:
		dummy.input.source = _brain(dummy) if on else InputSource.new()


## The boss (issue #67): a big dummy of `kind`'s size, health and moves, driven by a BossBrain
## when the enemies fight back.
func _add_boss(kind: BossKind, boss_lane: int, at_x: float) -> Fighter:
	var fighter: Fighter = _add_dummy(boss_lane, at_x, -1)
	fighter.max_health = kind.max_health
	fighter.health = kind.max_health
	fighter.size = kind.size
	fighter.walk_speed = kind.walk_speed
	fighter.moves = kind.moves
	fighter.set_lanes(lanes(), scales())
	_dummy_views[_dummies.find(fighter)].body_color = kind.body_color
	if _fighting:
		fighter.input.source = _brain(fighter)
	return fighter


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
	view.show_boxes = views[0].show_boxes
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
	tick()


## One tick of the fight, in a fixed order: pads join, everyone moves, hits
## land, the camera follows and the arenas lock it or let it go.
func tick() -> void:
	_tick += 1
	if mode != Mode.BOSS_FIGHT:
		for input in lobby.tick():
			if players.size() < MAX_PLAYERS:
				join(input)
	for player in players:
		player.tick()
	for dummy in _dummies:
		dummy.tick()
	crowd.tick()
	props.tick(players)
	var bodies: Array[Body] = []
	bodies.append_array(players)
	bodies.append_array(_dummies)
	bodies.append_array(crowd.alive())
	bodies.append_array(props.alive())
	_combat.fighters = bodies
	_projectiles.tick(bodies)
	_sparks.tick()
	_combat.resolve()
	# The camera follows the players, the arenas lock it or let it go, and the bounds follow the view.
	# In the boss fight it frames the two fighters instead (issue #66).
	if mode == Mode.BOSS_FIGHT:
		camera.frame_fight(_fighting_bodies())
	else:
		camera.follow(players, MARGIN)
	if _anyone_alive():
		if not _arenas.done:
			_level_ticks += 1
		_arenas.tick(_tick, camera.left(), camera.right(), crowd.count(), _spawn_level_wave)
	var limits: Vector2 = _arenas.limits()
	camera.set_limits(limits.x, limits.y)
	_update_bounds()
	_update_shake()
	_update_combo()
	_update_readout()


## The living players and the big dummies: what the fighting-game camera frames.
func _fighting_bodies() -> Array:
	var bodies: Array = []
	for player in players:
		if player.state != Fighter.State.DEAD:
			bodies.append(player)
	for dummy in _dummies:
		if dummy.state != Fighter.State.DEAD:
			bodies.append(dummy)
	return bodies


## Where everyone may stand: the living players inside the view, the crowd and
## the big dummies anywhere on the stage (a wave walks in from off screen, and
## one left behind follows), projectiles a little past the view.
func _update_bounds() -> void:
	for player in players:
		if player.state != Fighter.State.DEAD:
			player.bounds = camera.player_bounds(MARGIN)
			player.keep_in_bounds()
	if mode == Mode.BOSS_FIGHT:
		# The boss is held in by the edges too: a cornered fighter is a cornered fighter.
		for dummy in _dummies:
			dummy.bounds = camera.player_bounds(MARGIN)
			dummy.keep_in_bounds()
	crowd.set_bounds(Vector2(0.0, _arenas.stage_width))
	_projectiles.bounds = Vector2(camera.left() - 400.0, camera.right() + 400.0)


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
				var on: bool = not views[0].show_boxes
				for view in views:
					view.show_boxes = on
				for view in _dummy_views:
					view.show_boxes = on
			KEY_F2:
				_preset = (_preset + 1) % PRESETS.size()
				for fighter in _combat.fighters:
					fighter.set_lanes(lanes(), scales())
				crowd.set_lanes(lanes(), scales())
				props.set_lanes(lanes(), scales())
				queue_redraw()
			KEY_F3:
				_shading = not _shading
			KEY_F4:
				_dummy_guards = not _dummy_guards
				if _dummy_guards:
					_fighting = false
					crowd.passive = true
				for dummy in _dummies:
					dummy.input.source = InputSource.Held.new(Buttons.GUARD) if _dummy_guards else InputSource.new()
			KEY_F5:
				_dummy_guards = false
				_set_fighting(not _fighting)
			KEY_F6:
				spawn_wave(10)
			KEY_F7:
				for player in players:
					player.mana = player.max_mana
			KEY_F9:
				var sounds: Sounds = Sounds.instance()
				if sounds != null:
					sounds.muted = not sounds.muted
			KEY_F8:
				_tank = not _tank
				_fighter.max_guard = TANK_GUARD if _tank else GUARD_BAR
				_fighter.guard = _fighter.max_guard
			KEY_1:
				crowd.spawn(randi_range(0, 2), _in_front(), -_leader().facing)
			KEY_2:
				_add_dummy(_leader().lane, _in_front(), -_leader().facing)
			KEY_3:
				crowd.spawn(_leader().lane, _in_front(), -_leader().facing, KIND_FAST)
			KEY_4:
				crowd.spawn(_leader().lane, _in_front(), -_leader().facing, KIND_SHIELDED)
			KEY_5:
				crowd.spawn(_leader().lane, _in_front(), -_leader().facing, KIND_THROWER)
			KEY_6:
				props.spawn(Prop.Kind.BARREL, _leader().lane, _in_front())
			KEY_R:
				_start_over()


## A spot 320 pixels in front of the first living player, kept on screen.
func _in_front() -> float:
	var leader: Fighter = _leader()
	return clampf(leader.x + leader.facing * 320.0, leader.bounds.x, leader.bounds.y)


## What the arenas send: a level's wave, or a plain count of small fry.
func _spawn_level_wave(what: Variant) -> void:
	if what is WaveData:
		spawn_wave((what as WaveData).total(), what)
	else:
		spawn_wave(int(what))


## A wave of small fry from just off screen on both sides, spread over the
## lanes, facing in. A side at the stage's end sends its share from the other
## side; with no room on either side (a one-screen stage) they stand at the edges.
## `wave` says which kinds; without it, the sandbox's mix.
func spawn_wave(how_many: int, wave: WaveData = null) -> void:
	var open_left: bool = camera.left() - SPAWN_GAP > 0.0
	var open_right: bool = camera.right() + SPAWN_GAP < _arenas.stage_width
	for i in how_many:
		var from_left: bool = i % 2 == 0
		if open_left != open_right:
			from_left = open_left
		@warning_ignore("integer_division")
		var step: float = 40.0 * (i / 2)
		var at_x: float
		if from_left:
			at_x = camera.left() - SPAWN_GAP - step if open_left else camera.left() + MARGIN + step
		else:
			at_x = camera.right() + SPAWN_GAP + step if open_right else camera.right() - MARGIN - step
		crowd.spawn(i % 3, at_x, 1 if from_left else -1, wave.kind_at(i) if wave != null else wave_kind(i))


## The results of the level so far (issue #62): ticks on the clock, hits taken per player, the best combo.
func results() -> Dictionary:
	var taken: PackedInt32Array = PackedInt32Array()
	for player in players:
		taken.append(player.hits_taken)
	return {"ticks": _level_ticks, "hits_taken": taken, "best_combo": _best_combo}


## The kind of the `i`th small fry of F6's wave: mostly plain, with a fast one, a shielded one and
## a thrower mixed in. A level's waves say their own kinds.
func wave_kind(i: int) -> CrowdKind:
	if i % 8 == 7:
		return KIND_THROWER
	if i % 6 == 4:
		return KIND_SHIELDED
	if i % 6 == 2:
		return KIND_FAST
	return null


## Everyone who joined back on their feet with full health, spread around the
## middle of the screen, the crowd gone, the dummy still.
func _start_over() -> void:
	crowd.clear()
	for i in players.size():
		var player: Fighter = players[i]
		player.setup(player.input, lanes(), _start_lane(), SCREEN.x / 2.0 + START_GAP * (i - (players.size() - 1) / 2.0))
		player.mana = _starting_mana(player)
		player.set_lanes(lanes(), scales())
		player.state = Fighter.State.IDLE
		player.move = null
		player.hitstop = 0
		player.height = 0.0
		player.facing = 1
	_apply_mode()


## A brain for a big dummy, fighting the nearest player: the boss's own for the boss.
func _brain(dummy: Fighter) -> InputSource:
	if dummy == boss:
		var boss_brain := BossBrain.new(_tick + 7)
		boss_brain.fighter = dummy
		boss_brain.kind = BOSS
		boss_brain.targets = _party
		return boss_brain
	var brain := FighterBrain.new(_tick + _dummies.size())
	brain.fighter = dummy
	brain.targets = _party
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
	camera.shake(_shake, _tick)


## The counter shows the best combo going, in the colour of the player who has
## it, from the second hit. The health bars follow their players; the fight is
## over when the last player is down.
func _update_combo() -> void:
	var hits: int = 0
	var best: int = 0
	for i in players.size():
		health_bars[i].size.x = 396.0 * float(players[i].health) / players[i].max_health
		mana_bars[i].size.x = 396.0 * float(players[i].mana) / players[i].max_mana
		if players[i].mana_short_ticks > 0:
			mana_bars[i].color = MANA_SHORT_COLOR
		else:
			mana_bars[i].color = MANA_FULL_COLOR if players[i].mana >= players[i].max_mana else MANA_COLOR
		guard_bars[i].size.x = 396.0 * float(players[i].guard) / players[i].max_guard
		guard_bars[i].color = GUARD_COLOR if players[i].can_guard() else GUARD_LOW_COLOR
		var combo: int = _combat.combo_of(players[i])
		if combo > hits:
			hits = combo
			best = i
	_best_combo = maxi(_best_combo, hits)
	_combo_label.visible = hits >= 2
	_combo_label.text = "%d HITS" % hits
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if players.size() == 1 else PLAYER_COLORS[best].lightened(0.3))
	var all_down: bool = not _anyone_alive()
	var boss_down: bool = boss != null and boss.state == Fighter.State.DEAD
	_intro_ticks = maxi(_intro_ticks - 1, 0)
	if all_down:
		_message.text = "DOWN    R to start over"
	elif boss_down:
		_message.text = "K.O.    R for a rematch"
	elif _arenas.done:
		_message.text = "LEVEL CLEAR"
	elif _intro_ticks > 0:
		_message.text = BOSS.title.to_upper() if _intro_ticks > INTRO_TICKS / 3 else "FIGHT"
	_message.visible = all_down or boss_down or _arenas.done or _intro_ticks > 0
	_results.visible = _arenas.done and not all_down
	var show_boss: bool = boss != null and not boss_down
	_boss_back.visible = show_boss
	_boss_bar.visible = show_boss
	_boss_phase.visible = show_boss
	_boss_name.visible = show_boss
	if show_boss:
		_boss_bar.size.x = 796.0 * float(boss.health) / boss.max_health
		_boss_name.text = BOSS.title
	if _results.visible:
		_results.text = _results_text()
	# Between arenas the arrow flashes until the next one locks.
	_go_label.visible = _arenas.between() and (_tick / 20) % 2 == 0


## The results screen's lines: the time, the hits each player took, the best combo, and the keys.
func _results_text() -> String:
	var r: Dictionary = results()
	var seconds: int = int(r["ticks"]) / 60
	var taken: String = ""
	var hits: PackedInt32Array = r["hits_taken"]
	for i in hits.size():
		taken += ("P%d %d" % [players[i].input.player, hits[i]]) if players.size() > 1 else str(hits[i])
		if i < hits.size() - 1:
			taken += ", "
	return "time %d:%02d        hits taken %s        best combo %d\n\nR to go again        Tab, then M for the menu" % [seconds / 60, seconds % 60, taken, r["best_combo"]]


func _update_readout() -> void:
	for body in _combat.fighters:
		# The back lane is darkest: a cheap depth cue that keeps pixel art sharp.
		var shade: float = 1.0 - 0.12 * (2 - body.lane) if _shading else 1.0
		if body is CrowdBody:
			(body as CrowdBody).set_shade(shade)
		elif body is Prop:
			body.modulate = Color(shade, shade, shade, body.modulate.a)
		elif players.has(body):
			views[players.find(body)].shade = shade
		else:
			_dummy_views[_dummies.find(body)].shade = shade
	# The readout: what the player is doing, who is on the stage, and the frame rate.
	var move_text: String = ""
	if _fighter.move != null:
		move_text = " %s %d/%d" % [_fighter.move.id, _fighter.move_frame, _fighter.move.total_frames]
	var where: String = "x %d" % int(_fighter.x)
	if _fighter.mana_short_ticks > 0:
		where = "no mana for the heavy   " + where
	if _arenas.locked:
		where += "   arena %d of %d, wave %d of %d" % [_arenas.index + 1, _arenas.arenas.size(), _arenas.waves_sent, _arenas.wave_count()]
	elif _arenas.between():
		where += "   walk on"
	var help: String = HELP + (JOIN_HELP if mode != Mode.BOSS_FIGHT and players.size() < MAX_PLAYERS else "")
	_label.text = "%s\n%s%s   lane %d   mana %d   guard %d/%d   %s   %d fps   enemies %s   players %d" % [
		help, Fighter.STATE_NAMES[_fighter.state], move_text, _fighter.lane + 1, _fighter.mana, _fighter.guard, _fighter.max_guard, where, Engine.get_frames_per_second(),
		"fighting back" if _fighting else "guarding" if _dummy_guards else "standing still", players.size(),
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
