class_name CrowdBody
extends Body
## A small-fry enemy: the crowd body of docs/architecture.md, section 4. A Body
## with one or two simple moves and no input buffer or move list. The director
## tells it what to do (walk, wait, attack); it only knows how. Pooled: a dead
## one is reset and reused, never freed, as whatever kind of small fry is
## wanted (issue #61, a CrowdKind: health, speed, look, reach, shield, moves).
## It draws itself: a small figure, the flash shader and a shadow, like the
## fighter's view.

const SKIN_TONE := Color(0.88, 0.72, 0.58)
const STEEL := Color(0.78, 0.8, 0.84)
## The push a broken shield's hit gives when it has no launch of its own.
const SHIELD_BREAK_LAUNCH: float = 18.0

@export var walk_speed: float = 4.0
## The one attack, as move data like a fighter's.
@export var attack: Move
## The plain figure's colour.
@export var body_color: Color = Color(0.55, 0.42, 0.3)

## What this body is right now. Null means the plain small fry with the values above.
var kind: CrowdKind
## The shield left: blocks hits from the front while it is more than their damage.
var shield: int = 0
## Where a thrower's rocks go. Set by the director.
var projectiles: Projectiles

## Set by the director each think: where to walk (0 to stand), and whether to swing, and with what.
var wanted_direction: int = 0
var wants_attack: bool = false
var use_special: bool = false
## True while the director has handed it an attack token.
var has_token: bool = false
## Ticks until this body may attack again, set by the director after a swing.
var rest: int = 0
## Which think turn this body is on: it thinks when the director's tick matches.
var think_slot: int = 0
## The side of the target this body tries to stand on: 1 for its right, -1 for its left, 0 not chosen yet.
var side: int = 0
## Going round through a side lane (issue #75): the lane it took, or -1; where it is heading, as a
## side of the target and a distance from it; and how long a player's wall has held it on its way.
var flank_lane: int = -1
var flank_side: int = 0
var flank_dist: float = 0.0
var blocked: int = 0
## Ticks before this body answers a taunt by hopping a lane (issue #72): -1 means not rolled yet.
var taunt_wait: int = -1
## Ticks the target has been in another lane, counted by the director.
var off_lane_ticks: int = 0
## The player this body fights, picked by the director among its targets (issue #59). Null until it thinks.
var target: Body

static var _flash_shader: Shader
var _shade: float = 1.0


func _ready() -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FighterView.FLASH_SHADER
	var flash := ShaderMaterial.new()
	flash.shader = _flash_shader
	material = flash


## Makes this body a `new_kind` of small fry: its health, speed, colour and moves.
func apply_kind(new_kind: CrowdKind) -> void:
	kind = new_kind
	if kind == null:
		return
	max_health = kind.max_health
	walk_speed = kind.walk_speed
	body_color = kind.body_color
	attack = kind.attack


## How close it walks before it swings, and how near is too near for it.
func reach() -> float:
	return kind.reach if kind != null else 170.0


func keep_away() -> float:
	return kind.keep_away if kind != null else 0.0


## Brings a pooled body back to life on a lane, as `new_kind` (null for the plain small fry).
func revive(lanes: PackedFloat32Array, scales: PackedFloat32Array, start_lane: int, start_x: float, face: int, new_kind: CrowdKind = null) -> void:
	apply_kind(new_kind)
	state = State.IDLE
	previous_state = State.IDLE
	state_ticks = 0
	height = 0.0
	vertical_speed = 0.0
	hitstop = 0
	flash_ticks = 0
	juggle_hits = 0
	combo_hits = 0
	combo_damage = 0
	move = null
	rest = 0
	has_token = false
	wants_attack = false
	use_special = false
	wanted_direction = 0
	off_lane_ticks = 0
	side = 0
	flank_lane = -1
	flank_side = 0
	flank_dist = 0.0
	blocked = 0
	taunt_wait = -1
	target = null
	shield = kind.shield if kind != null else 0
	facing = face
	place_on(lanes, start_lane, start_x)
	set_lanes(lanes, scales)
	visible = true


## Dead and finished lying there: the director can take it back.
func is_done() -> bool:
	return state == State.DEAD and state_ticks >= knockdown_ticks


## A shield stops hits from the front while the body stands or walks.
func blocks(direction: int) -> bool:
	return shield > 0 and (state == State.IDLE or state == State.WALK) and facing == -direction


## The shield holds a hit it can take; a heavier one, or a guard breaker, goes through.
func blocks_hit(hit: HitBox, direction: int) -> bool:
	return blocks(direction) and not hit.breaks_guard and not hit.grab and not hit.unblockable and shield > hit.damage


## A blocked hit drains the shield and nudges the body back.
func take_block(hit: HitBox, direction: int) -> void:
	shield -= hit.damage
	hitstop = blocked_hitstop(hit)
	flash_ticks = 2
	x = clampf(x + direction * hit.knockback * 0.5, bounds.x, bounds.y)
	_place()


## A hit on a raised shield that it can't take breaks it: the hit lands in full and launches.
func take_hit(hit: HitBox, direction: int) -> void:
	if blocks(direction) and not hit.grab and not hit.unblockable:
		shield = 0
		just_broke = true
		var breaking: HitBox = hit.duplicate()
		breaking.launch = maxf(hit.launch, SHIELD_BREAK_LAUNCH)
		super(breaking, direction)
		return
	super(hit, direction)


## In the telegraph of a special: the wind-up before its first hit frame, for the player to read.
func telegraphing() -> bool:
	if state != State.ATTACK or move == null or move.hit_boxes.is_empty():
		return false
	return move != attack and move_frame < move.hit_boxes[0].first_frame


func _tick_state() -> void:
	rest = maxi(rest - 1, 0)
	match state:
		State.IDLE, State.WALK:
			if wants_attack and attack != null:
				wants_attack = false
				move = kind.special if use_special and kind != null and kind.special != null else attack
				use_special = false
				move_frame = 0
				start_swing()
				_enter(State.ATTACK)
				Sounds.play(&"fireball" if move.projectile_frame >= 0 else &"swing")
			elif wanted_direction != 0:
				facing = wanted_direction
				x = clampf(x + wanted_direction * walk_speed, bounds.x, bounds.y)
				if state != State.WALK:
					_enter(State.WALK)
			elif state != State.IDLE:
				_enter(State.IDLE)
		State.ATTACK:
			if projectiles != null and move.projectile_frame == move_frame:
				var offset: Vector2 = move.projectile_offset * depth_scale
				offset.x *= facing
				projectiles.spawn_from(move, position + offset, lane, team, facing, depth_scale, 0, self)
			x = clampf(x + facing * move.travel_speed(move_frame), bounds.x, bounds.y)
			move_frame += 1
			if move_frame >= move.total_frames:
				move = null
				_enter(State.IDLE)
		_:
			super()


func _physics_process(_delta: float) -> void:
	(material as ShaderMaterial).set_shader_parameter(&"flash", 1.0 if flash_ticks > 0 else 0.0)
	queue_redraw()


## Darkens the figure, for back lanes. 1 is unchanged.
func set_shade(shade: float) -> void:
	_shade = shade
	modulate = Color(shade, shade, shade)


## The plain figure: about 190 pixels tall, a hood and a club; the kinds vary
## it (a slighter figure with a knife, a shield, a sling and a rock). The
## wind-up of an attack leans back, the swing leans in; the telegraph of a
## special raises a red mark over the head.
func _draw() -> void:
	var shrink: float = clampf(1.0 - height / 900.0, 0.5, 1.0)
	draw_set_transform(Vector2(0.0, height), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 50.0 * shrink, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var f: float = facing
	var back: float = -f
	var lean: float = 0.0
	var size: float = kind.scale if kind != null else 1.0
	var look: CrowdKind.Look = kind.look if kind != null else CrowdKind.Look.PLAIN
	match state:
		State.ATTACK:
			var t: float = float(move_frame) / move.total_frames
			lean = f * (-0.25 if t < 0.45 else 0.3)
			if telegraphing():
				lean = f * -0.4
		State.HITSTUN:
			lean = back * 0.3
		State.LAUNCHED:
			lean = back * minf(0.3 + state_ticks * 0.08, 1.4)
		State.KNOCKDOWN, State.DEAD:
			draw_set_transform(Vector2(0.0, -30.0), back * PI / 2.0, Vector2(size, size))
		State.GETUP:
			var left: float = 1.0 - float(state_ticks) / getup_ticks
			draw_set_transform(Vector2(0.0, -30.0 * left), back * PI / 2.0 * left, Vector2(size, size))
	if lean != 0.0 or (size != 1.0 and state != State.KNOCKDOWN and state != State.DEAD and state != State.GETUP):
		draw_set_transform(Vector2.ZERO, lean, Vector2(size, size))
	var dark: Color = body_color.darkened(0.35)
	var stride: float = sin(state_ticks * 0.4) * 14.0 if state == State.WALK else 0.0
	var slim: float = 0.75 if look == CrowdKind.Look.FAST else 1.0
	draw_rect(Rect2(-24.0 * slim + stride, -90.0, 20.0 * slim, 90.0), dark)
	draw_rect(Rect2(4.0 * slim - stride, -90.0, 20.0 * slim, 90.0), dark)
	draw_rect(Rect2(-30.0 * slim, -165.0, 60.0 * slim, 78.0), body_color)
	draw_rect(Rect2(-20.0, -200.0, 40.0, 38.0), SKIN_TONE)
	draw_rect(Rect2(-24.0, -206.0, 48.0, 14.0), dark)  # hood
	var t_swing: float = float(move_frame) / move.total_frames if state == State.ATTACK else 0.0
	match look:
		CrowdKind.Look.FAST:
			# A knife: short, quick.
			var knife := Rect2(22.0, -140.0, 36.0 + 50.0 * sin(t_swing * PI), 8.0)
			draw_rect(_faced_rect(knife, f), STEEL)
		CrowdKind.Look.SHIELD:
			# The shield in front, raised high through the bash's wind-up; dented away as it drains.
			var raised: float = -40.0 if telegraphing() else 0.0
			var left: float = float(shield) / maxf(kind.shield, 1.0) if kind != null else 0.0
			var board := Rect2(26.0, -185.0 + raised, 16.0, 40.0 + 60.0 * left)
			draw_rect(_faced_rect(board, f), STEEL.darkened(0.15))
			var club := Rect2(26.0, -150.0, 60.0 + 70.0 * sin(t_swing * PI), 12.0)
			draw_rect(_faced_rect(club, f), dark.lightened(0.2))
		CrowdKind.Look.THROWER:
			# A rock in hand until it leaves, and a sling.
			var thrown: bool = state == State.ATTACK and move.projectile_frame >= 0 and move_frame >= move.projectile_frame
			var arm := Rect2(20.0, -150.0 - 60.0 * sin(t_swing * PI), 40.0, 10.0)
			draw_rect(_faced_rect(arm, f), SKIN_TONE)
			if not thrown:
				var rock_x: float = 50.0
				draw_circle(Vector2(rock_x * f, arm.position.y + 4.0), 12.0, Color(0.5, 0.48, 0.45))
		_:
			var club := Rect2(26.0, -150.0, 60.0 + 70.0 * sin(t_swing * PI), 12.0)
			draw_rect(_faced_rect(club, f), dark.lightened(0.2))
	if telegraphing():
		# The tell: a red mark over the head.
		draw_colored_polygon(PackedVector2Array([Vector2(-14.0, -250.0), Vector2(14.0, -250.0), Vector2(0.0, -222.0)]), Color(1.0, 0.25, 0.2))
	draw_set_transform(Vector2.ZERO)
	if state == State.DEAD:
		modulate.a = clampf(1.0 - float(state_ticks - knockdown_ticks / 2) / (knockdown_ticks / 2.0), 0.0, 1.0) * 1.0


static func _faced_rect(rect: Rect2, f: float) -> Rect2:
	if f < 0.0:
		rect.position.x = -rect.position.x - rect.size.x
	return rect
