class_name Prop
extends Body
## A thing on the stage that is not a fighter (issue #64): a barrel that
## breaks in three states under anyone's hits, or the health potion it drops.
## A Body of team 3, so hits from either side land on it, with no health of
## its own: a barrel counts hits, a potion can't be hit. Pooled by Props.

enum Kind { BARREL, HEALTH }

## Ticks a broken barrel lies there before it goes.
const GONE_AFTER: int = 90

## Hits a barrel takes: whole, cracked, broken.
@export var barrel_hits: int = 2

var kind: Kind = Kind.BARREL
## Hits left before a barrel breaks.
var hits_left: int = 0
## Whether this barrel has dropped its potion yet.
var dropped: bool = false
## Whether a player has taken this potion.
var taken: bool = false
## Ticks since the barrel broke.
var broken_ticks: int = 0

static var _flash_shader: Shader


func _ready() -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FighterView.FLASH_SHADER
	var flash := ShaderMaterial.new()
	flash.shader = _flash_shader
	material = flash


## Brings a pooled prop back as `new_kind` on a lane at an x.
func revive(lanes: PackedFloat32Array, scales: PackedFloat32Array, start_lane: int, start_x: float, new_kind: Kind) -> void:
	kind = new_kind
	team = 3
	hurt_box = Rect2(-40.0, -110.0, 80.0, 110.0)
	state = State.IDLE
	previous_state = State.IDLE
	state_ticks = 0
	height = 0.0
	hitstop = 0
	flash_ticks = 0
	hits_left = barrel_hits
	dropped = false
	taken = false
	broken_ticks = 0
	move = null
	facing = 1
	place_on(lanes, start_lane, start_x)
	set_lanes(lanes, scales)
	modulate.a = 1.0
	visible = true


func is_barrel() -> bool:
	return kind == Kind.BARREL


func broken() -> bool:
	return is_barrel() and state == State.DEAD


## A barrel that has lain broken long enough, or a potion that was taken: the pool takes it back.
func is_done() -> bool:
	if is_barrel():
		return broken() and broken_ticks >= GONE_AFTER
	return taken


## Not a fighter: no combo count, no pay, and missiles pass it by.
func fights() -> bool:
	return false


## Only a whole or cracked barrel can be hit.
func can_be_hit() -> bool:
	return is_barrel() and state != State.DEAD


## A hit knocks the barrel to its next state; the last one breaks it. No knockback, no launch.
func take_hit(hit: HitBox, _direction: int) -> void:
	hits_left -= 1
	hitstop = hit.hitstop
	flash_ticks = hit.hitstop + 2
	if hits_left <= 0:
		hits_left = 0
		previous_state = state
		state = State.DEAD
		state_ticks = 0
		broken_ticks = 0


func _tick_state() -> void:
	if state == State.DEAD:
		broken_ticks += 1


func _physics_process(_delta: float) -> void:
	(material as ShaderMaterial).set_shader_parameter(&"flash", 1.0 if flash_ticks > 0 else 0.0)
	queue_redraw()


## Placeholder looks until T and E draw them (docs/art.md: a destructible prop
## in three states, and a pickup): a barrel with bands that cracks, then lies
## in planks; a red potion that bobs.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 46.0 if is_barrel() else 22.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var wood := Color(0.5, 0.36, 0.22)
	var band := Color(0.3, 0.3, 0.32)
	if not is_barrel():
		var bob: float = sin(state_ticks * 0.1) * 4.0
		draw_rect(Rect2(-14.0, -44.0 + bob, 28.0, 36.0), Color(0.85, 0.2, 0.25))
		draw_rect(Rect2(-7.0, -58.0 + bob, 14.0, 16.0), Color(0.75, 0.7, 0.6))
		draw_rect(Rect2(-9.0, -40.0 + bob, 6.0, 20.0), Color(1.0, 0.6, 0.65))
		return
	if broken():
		var fade: float = clampf(1.0 - float(broken_ticks - GONE_AFTER / 2) / (GONE_AFTER / 2.0), 0.0, 1.0)
		modulate.a = fade
		# Planks on the ground, and the bands.
		draw_set_transform(Vector2(-30.0, -8.0), -0.15)
		draw_rect(Rect2(0.0, -10.0, 60.0, 12.0), wood)
		draw_set_transform(Vector2(10.0, -6.0), 0.25)
		draw_rect(Rect2(0.0, -10.0, 56.0, 12.0), wood.darkened(0.15))
		draw_set_transform(Vector2(-20.0, -14.0), 0.05)
		draw_rect(Rect2(0.0, -14.0, 40.0, 8.0), band)
		draw_set_transform(Vector2.ZERO)
		return
	var cracked: bool = hits_left < barrel_hits
	var body_color: Color = wood.darkened(0.2) if cracked else wood
	draw_rect(Rect2(-36.0, -104.0, 72.0, 104.0), body_color)
	draw_rect(Rect2(-40.0, -98.0, 80.0, 92.0), body_color)
	draw_rect(Rect2(-40.0, -84.0, 80.0, 8.0), band)
	draw_rect(Rect2(-40.0, -30.0, 80.0, 8.0), band)
	draw_rect(Rect2(-6.0, -98.0, 4.0, 92.0), body_color.darkened(0.25))
	draw_rect(Rect2(14.0, -98.0, 4.0, 92.0), body_color.darkened(0.25))
	if cracked:
		# A crack down the side, and a stave sprung loose.
		draw_polyline(PackedVector2Array([Vector2(-12.0, -98.0), Vector2(-2.0, -70.0), Vector2(-14.0, -48.0), Vector2(-4.0, -12.0)]), Color(0.12, 0.08, 0.05), 4.0)
		draw_set_transform(Vector2(30.0, -90.0), 0.3)
		draw_rect(Rect2(0.0, 0.0, 10.0, 60.0), wood)
		draw_set_transform(Vector2.ZERO)
