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

var _tick: int = 0
var _combo: Dictionary[Body, int] = {}
var _last_hit: Dictionary[Body, int] = {}


func resolve() -> void:
	_tick += 1
	shake = 0.0
	_resolve_moves()
	if projectiles != null:
		_resolve_projectiles()


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
		var stop: int = targets[i].blocked_hitstop(hits[i]) if targets[i].blocks(attackers[i].facing) else hits[i].hitstop
		freeze[attackers[i]] = maxi(freeze.get(attackers[i], 0), stop)
	for i in hits.size():
		_land(targets[i], hits[i], attackers[i].facing, points[i])
		if not targets[i].blocks(attackers[i].facing):
			_count(attackers[i])
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
				if not _can_hit(projectiles.team(i), projectiles.lane(i), target) or projectiles.has_hit(i, target):
					continue
				if box.intersects(target.hurt_rect()):
					_land(target, hit, projectiles.direction(i), box.intersection(target.hurt_rect()).get_center())
					for body in fighters:
						if body.team == projectiles.team(i) and not target.blocks(projectiles.direction(i)):
							_count(body)
							break
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
	if target.blocks(direction):
		target.take_block(hit, direction)
		if sparks != null:
			sparks.spawn(at, 20.0 + hit.hitstop * 3.0, true)
		return
	target.take_hit(hit, direction)
	shake = maxf(shake, hit.shake)
	if sparks != null:
		sparks.spawn(at, 30.0 + hit.hitstop * 6.0)
