extends Node2D
## Move preview (issue #8): steps through a move frame by frame, with its
## hitboxes and hurtbox drawn over the fighter and its timing on a timeline.
## It reloads a move when its file changes, so a move can be tuned in the
## editor's inspector, saved, and seen here at once, without writing code.
##
## Run: scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn
## or open this scene in the editor and press F6.

const SCREEN := Vector2(1920.0, 1080.0)
const GROUND_Y: float = 700.0
## The fighter stands on the right, clear of the text.
const FIGHTER_X: float = 1400.0
## How high an air move is shown.
const AIR_HEIGHT: float = 200.0
const LOCAL_SKIN: String = "res://local/skins/player"
const TIMELINE := Rect2(160.0, 840.0, 1600.0, 120.0)
## Ticks between two looks at the move files for changes.
const WATCH_EVERY: int = 20
const HELP: String = "Left, Right: step a frame    Space: play or pause    Up, Down: another move    F: face the other way    click the timeline: jump to a frame
Edit a move in the editor's inspector and save: it reloads here."
## The text keeps to the left of this, so it never covers the fighter.
const TEXT_WIDTH: float = 1000.0

const HIT_COLOUR := Color(1.0, 0.25, 0.2)
const CANCEL_COLOUR := Color(0.3, 0.85, 0.4)
const PROJECTILE_COLOUR := Color(1.0, 0.65, 0.15)

## The folder whose moves are shown.
var moves_dir: String = "res://data/moves/poc"

var paths: Array[String] = []
var index: int = 0
var frame: int = 0
var playing: bool = false
var move: Move
## What happened on the last reload, shown on screen.
var notice: String = ""

var _hashes: Dictionary[String, String] = {}
var _watch_ticks: int = 0
var _fighter: Fighter
var _view: FighterView
var _label: Label


func _ready() -> void:
	_fighter = Fighter.new()
	add_child(_fighter)
	_fighter.setup(PlayerInput.new(0, InputSource.new()), PackedFloat32Array([GROUND_Y]), 0, FIGHTER_X)
	_view = FighterView.new()
	_view.skin = FighterSkin.load_from(LOCAL_SKIN)
	_view.show_boxes = true
	_fighter.add_child(_view)

	_label = _text(Vector2(24.0, 16.0), 24)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = TEXT_WIDTH
	_text(Vector2(24.0, 1010.0), 20).text = HELP

	scan()
	select(0)


func _physics_process(_delta: float) -> void:
	_watch_ticks += 1
	if _watch_ticks >= WATCH_EVERY:
		_watch_ticks = 0
		watch()
	if playing and move != null:
		frame = (frame + 1) % move.total_frames
	_pose()
	_label.text = _describe()
	queue_redraw()


func _text(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label


## The tool's own keys and mouse, read directly on purpose: they are not a player's input.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_RIGHT:
				step(1)
			KEY_LEFT:
				step(-1)
			KEY_DOWN when not event.echo:
				select(index + 1)
			KEY_UP when not event.echo:
				select(index - 1)
			KEY_SPACE when not event.echo:
				playing = not playing
			KEY_F when not event.echo:
				_fighter.facing = -_fighter.facing
	elif event is InputEventMouse and event.button_mask & MOUSE_BUTTON_MASK_LEFT and move != null:
		if TIMELINE.grow(20.0).has_point(event.position):
			playing = false
			frame = clampi(int((event.position.x - TIMELINE.position.x) / _cell()), 0, move.total_frames - 1)


## Finds the move files in the folder. Called again by watch(), so new files appear.
func scan() -> void:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(moves_dir):
		# A built game lists "name.tres.remap".
		var path: String = moves_dir.path_join(file.trim_suffix(".remap"))
		if path.ends_with(".tres") and not found.has(path):
			found.append(path)
	found.sort()
	paths = found


func select(to: int) -> void:
	if paths.is_empty():
		move = null
		return
	index = posmod(to, paths.size())
	frame = 0
	notice = ""
	_load(false)


func step(by: int) -> void:
	if move == null:
		return
	playing = false
	frame = posmod(frame + by, move.total_frames)


## Looks for changed or new move files, and reloads the one shown if it changed.
func watch() -> void:
	var shown: String = paths[index] if not paths.is_empty() else ""
	scan()
	if paths.is_empty():
		move = null
		return
	index = maxi(paths.find(shown), 0)
	if FileAccess.get_md5(paths[index]) != _hashes.get(paths[index], ""):
		_load(true)


func _load(changed: bool) -> void:
	var path: String = paths[index]
	_hashes[path] = FileAccess.get_md5(path)
	# Read the file again, and the boxes and windows inside it, not the copy Godot keeps in memory.
	var loaded: Move = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as Move
	if loaded == null:
		notice = "%s can't be read as a move. Showing the last version that could." % path.get_file()
		return
	move = loaded
	frame = mini(frame, move.total_frames - 1)
	if changed:
		notice = "%s reloaded." % path.get_file()


func _cell() -> float:
	return TIMELINE.size.x / move.total_frames


## Puts the fighter in the move, on the frame shown, without running the game.
func _pose() -> void:
	_fighter.move = move
	_fighter.move_frame = frame
	_fighter.height = AIR_HEIGHT if move != null and move.air else 0.0
	_fighter.position = Vector2(FIGHTER_X, GROUND_Y - _fighter.height)
	if move == null:
		_fighter.state = Fighter.State.IDLE
	else:
		_fighter.state = Fighter.State.AIR_ATTACK if move.air else Fighter.State.ATTACK


## What the frame shown is: before, during or after the hit.
func phase() -> String:
	var first: int = move.total_frames
	var last: int = -1
	for box in move.hit_boxes:
		first = mini(first, box.first_frame)
		last = maxi(last, box.last_frame)
	if last < 0:
		return "no hitbox"
	if frame < first:
		return "startup"
	return "active" if frame <= last else "recovery"


func _describe() -> String:
	if move == null:
		return "No move files in %s." % moves_dir
	var lines: Array[String] = []
	lines.append("%s   (%d of %d: %s)%s" % [move.id, index + 1, paths.size(), paths[index], "   playing" if playing else ""])
	lines.append("frame %d of %d   %s   animation \"%s\"%s%s" % [
		frame, move.total_frames, phase(), move.animation,
		"   air move" if move.air else "", "   follow-up" if move.follow_up else "",
	])
	for box in move.hit_boxes:
		lines.append("hit on frames %d to %d: damage %d, hitstun %d, hitstop %d, knockback %s, launch %s, shake %s" % [
			box.first_frame, box.last_frame, box.damage, box.hitstun, box.hitstop, box.knockback, box.launch, box.shake,
		])
	for window in move.cancels:
		lines.append("cancel on frames %d to %d into %s%s" % [
			window.first_frame, window.last_frame, ", ".join(window.into), " (only on hit)" if window.on_hit_only else "",
		])
	if move.projectile_frame >= 0:
		lines.append("projectile leaves on frame %d" % move.projectile_frame)
	if notice != "":
		lines.append(notice)
	return "\n".join(lines)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.15, 0.165, 0.21))
	draw_rect(Rect2(0.0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color(0.305, 0.275, 0.243))
	_draw_ruler()
	if move == null:
		return
	if move.projectile_frame >= 0 and frame >= move.projectile_frame:
		# Where the projectile leaves from.
		var offset: Vector2 = move.projectile_offset
		offset.x *= _fighter.facing
		draw_arc(_fighter.position + offset, Projectiles.RADIUS, 0.0, TAU, 32, PROJECTILE_COLOUR, 3.0)
	_draw_timeline()


## Distances from the fighter's feet along the ground, every 50 pixels.
func _draw_ruler() -> void:
	var font: Font = ThemeDB.fallback_font
	for distance in range(-300, 451, 50):
		var x: float = FIGHTER_X + distance
		var tall: bool = distance % 100 == 0
		draw_line(Vector2(x, GROUND_Y), Vector2(x, GROUND_Y + (16.0 if tall else 8.0)), Color(0.7, 0.66, 0.6), 2.0)
		if tall:
			draw_string(font, Vector2(x - 30.0, GROUND_Y + 40.0), str(distance), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 18, Color(0.7, 0.66, 0.6))


## One cell per frame: hitboxes on the top row, cancel windows on the bottom
## row, the projectile as a mark, and the frame shown as a white outline.
func _draw_timeline() -> void:
	var font: Font = ThemeDB.fallback_font
	var cell: float = _cell()
	var row: float = TIMELINE.size.y / 2.0
	draw_rect(TIMELINE, Color(0.1, 0.11, 0.14))
	for box in move.hit_boxes:
		draw_rect(_span(box.first_frame, box.last_frame, 0.0, row), HIT_COLOUR)
	for window in move.cancels:
		var span: Rect2 = _span(window.first_frame, window.last_frame, row, row)
		draw_rect(span, CANCEL_COLOUR)
		draw_string(font, span.position + Vector2(6.0, row - 18.0), "into " + ", ".join(window.into), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.BLACK)
	if move.projectile_frame >= 0:
		draw_rect(_span(move.projectile_frame, move.projectile_frame, 0.0, TIMELINE.size.y).grow_individual(-cell * 0.3, 0.0, -cell * 0.3, 0.0), PROJECTILE_COLOUR)
	for i in move.total_frames + 1:
		var x: float = TIMELINE.position.x + i * cell
		draw_line(Vector2(x, TIMELINE.position.y), Vector2(x, TIMELINE.end.y), Color(0.0, 0.0, 0.0, 0.5), 1.0)
		if i % 5 == 0 and i < move.total_frames:
			draw_string(font, Vector2(x, TIMELINE.end.y + 24.0), str(i), HORIZONTAL_ALIGNMENT_CENTER, cell, 18, Color(0.8, 0.8, 0.8))
	draw_rect(_span(frame, frame, 0.0, TIMELINE.size.y), Color.WHITE, false, 4.0)
	draw_string(font, TIMELINE.position + Vector2(-140.0, row - 18.0), "hits", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, HIT_COLOUR)
	draw_string(font, TIMELINE.position + Vector2(-140.0, TIMELINE.size.y - 18.0), "cancels", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, CANCEL_COLOUR)


## The timeline rectangle covering frames `first` to `last`, on a row `height` tall starting `top` down.
func _span(first: int, last: int, top: float, height: float) -> Rect2:
	var cell: float = _cell()
	first = clampi(first, 0, move.total_frames - 1)
	last = clampi(last, first, move.total_frames - 1)
	return Rect2(TIMELINE.position.x + first * cell, TIMELINE.position.y + top, (last - first + 1) * cell, height)
