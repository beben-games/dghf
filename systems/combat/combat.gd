class_name Combat
extends RefCounted
## Resolves every hit, once per tick and in a fixed order: fighters in the order
## they were added, then projectiles (docs/architecture.md, section 7). Call
## resolve() after everything has moved this tick.

var fighters: Array[Body] = []
var projectiles: Projectiles
var sparks: HitSparks
## The strongest shake asked for by this tick's hits, in pixels.
var shake: float = 0.0
## Ticks without landing a hit after which an attacker's combo count ends.
var combo_window: int = 90
## The shake a guard break gives (issue #72).
const BREAK_SHAKE: float = 12.0

var _tick: int = 0
var _combo: Dictionary[Body, int] = {}
var _last_hit: Dictionary[Body, int] = {}


func resolve() -> void:
	_tick += 1
	shake = 0.0
	_resolve_moves()
	if projectiles != null:
		_resolve_projectiles()


## The push a projectile gives: away from a burst's centre, along a missile's or fireball's flight.
func _projectile_direction(i: int, target: Body) -> int:
	if projectiles.hits_every_lane(i) and projectiles.hit(i) != null and projectiles.radius(i) > Projectiles.RADIUS:
		return 1 if target.x >= projectiles.rect(i).get_center().x else -1
	return projectiles.direction(i)


func _resolve_moves() -> void:
	# Find every hit before applying any, so two fighters who hit each other
	# on the same tick both land.
	var attackers: Array[Body] = []
	var targets: Array[Body] = []
	var hits: Array[HitBox] = []
	var points: PackedVector2Array = PackedVector2Array()
	for attacker in fighters:
		if not attacker.is_attacking():
			continue
		for target in fighters:
			if not _can_hit(attacker.team, attacker.lane, target):
				continue
			var hurt: Rect2 = target.hurt_rect()
			for box in attacker.move.hit_boxes:
				if attacker.has_hit(target, box.group):
					continue
				if box.active_on(attacker.move_frame) and attacker.hit_rect(box).intersects(hurt):
					attackers.append(attacker)
					targets.append(target)
					hits.append(box)
					points.append(attacker.hit_rect(box).intersection(hurt).get_center())
					break

	# The attacker freezes once per swing, for the longest hitstop it landed. A
	# blocked hit freezes for less.
	var freeze: Dictionary[Body, int] = {}
	for i in hits.size():
		attackers[i].mark_hit(targets[i], hits[i].group)
		var stop: int = targets[i].blocked_hitstop(hits[i]) if targets[i].blocks_hit(hits[i], attackers[i].facing) else hits[i].hitstop
		freeze[attackers[i]] = maxi(freeze.get(attackers[i], 0), stop)
	for i in hits.size():
		_land(targets[i], hits[i], attackers[i].facing, points[i])
		if not targets[i].blocks_hit(hits[i], attackers[i].facing):
			_count(attackers[i])
			attackers[i].on_hit_landed(hits[i])
	for attacker: Body in freeze:
		if not attacker.swing_froze:
			attacker.swing_froze = true
			attacker.hitstop = maxi(attacker.hitstop, freeze[attacker])


func _resolve_projectiles() -> void:
	var i: int = projectiles.count() - 1
	while i >= 0:
		var hit: HitBox = projectiles.hit(i)
		if hit != null:
			var box: Rect2 = projectiles.rect(i)
			var spent: bool = false
			for target in fighters:
				var in_lane: bool = projectiles.hits_every_lane(i) or target.lane == projectiles.lane(i)
				if target.team == projectiles.team(i) or not in_lane or not target.can_be_hit() or projectiles.has_hit(i, target):
					continue
				var after: Body = projectiles.target_of(i)
				if after != null and after != target:
					continue  # a missile flies through the others to the one it is after
				if box.intersects(target.hurt_rect()):
					var direction: int = _projectile_direction(i, target)
					_land(target, hit, direction, box.intersection(target.hurt_rect()).get_center())
					if not target.blocks_hit(hit, direction):
						var caster: Body = projectiles.owner_of(i)
						if caster == null:
							# A projectile with no owner (a test's) counts for the first body of its team.
							for body in fighters:
								if body.team == projectiles.team(i):
									caster = body
									break
						if caster != null:
							_count(caster)
							caster.on_hit_landed(hit)
					if projectiles.pierces(i):
						projectiles.mark_hit(i, target)  # and on it goes
					else:
						spent = true
						break
			if spent:
				projectiles.remove(i)
		i -= 1


## How many hits `attacker` has landed in a row, on any targets, with no gap
## longer than combo_window. 0 once the window has passed.
func combo_of(attacker: Body) -> int:
	if _tick - _last_hit.get(attacker, -combo_window * 2) > combo_window:
		return 0
	return _combo.get(attacker, 0)


func _count(attacker: Body) -> void:
	_combo[attacker] = 1 if _tick - _last_hit.get(attacker, -combo_window * 2) > combo_window else _combo.get(attacker, 0) + 1
	_last_hit[attacker] = _tick


func _can_hit(team: int, lane: int, target: Body) -> bool:
	return target.team != team and target.lane == lane and target.can_be_hit()


func _land(target: Body, hit: HitBox, direction: int, at: Vector2) -> void:
	if target.blocks_hit(hit, direction):
		target.take_block(hit, direction)
		if sparks != null:
			sparks.spawn(at, 20.0 + hit.hitstop * 3.0, true)
		return
	target.take_hit(hit, direction)
	shake = maxf(shake, BREAK_SHAKE if target.just_broke else hit.shake)
	if sparks != null:
		sparks.spawn(at, 30.0 + hit.hitstop * 6.0)
