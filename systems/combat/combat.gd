class_name Combat
extends RefCounted
## Resolves every hit, once per tick and in a fixed order: fighters in the order
## they were added, then projectiles (docs/architecture.md, section 7). Call
## resolve() after everything has moved this tick.

var fighters: Array[Fighter] = []
var projectiles: Projectiles
var sparks: HitSparks
## The strongest shake asked for by this tick's hits, in pixels.
var shake: float = 0.0


func resolve() -> void:
	shake = 0.0
	_resolve_moves()
	if projectiles != null:
		_resolve_projectiles()


func _resolve_moves() -> void:
	# Find every hit before applying any, so two fighters who hit each other
	# on the same tick both land.
	var attackers: Array[Fighter] = []
	var targets: Array[Fighter] = []
	var hits: Array[HitBox] = []
	var points: PackedVector2Array = PackedVector2Array()
	for attacker in fighters:
		if attacker.state != Fighter.State.ATTACK:
			continue
		for target in fighters:
			if not _can_hit(attacker.team, attacker.lane, target) or attacker.swing_targets.has(target):
				continue
			var hurt: Rect2 = target.hurt_rect()
			for box in attacker.move.hit_boxes:
				if box.active_on(attacker.move_frame) and attacker.hit_rect(box).intersects(hurt):
					attackers.append(attacker)
					targets.append(target)
					hits.append(box)
					points.append(attacker.hit_rect(box).intersection(hurt).get_center())
					break

	# The attacker freezes once per swing, for the longest hitstop it landed.
	var freeze: Dictionary[Fighter, int] = {}
	for i in hits.size():
		attackers[i].swing_targets.append(targets[i])
		freeze[attackers[i]] = maxi(freeze.get(attackers[i], 0), hits[i].hitstop)
	for i in hits.size():
		_land(targets[i], hits[i], attackers[i].facing, points[i])
	for attacker: Fighter in freeze:
		if not attacker.swing_froze:
			attacker.swing_froze = true
			attacker.hitstop = maxi(attacker.hitstop, freeze[attacker])


func _resolve_projectiles() -> void:
	var i: int = projectiles.count() - 1
	while i >= 0:
		var hit: HitBox = projectiles.hit(i)
		if hit != null:
			var box: Rect2 = projectiles.rect(i)
			for target in fighters:
				if _can_hit(projectiles.team(i), projectiles.lane(i), target) and box.intersects(target.hurt_rect()):
					_land(target, hit, projectiles.direction(i), box.intersection(target.hurt_rect()).get_center())
					projectiles.remove(i)
					break
		i -= 1


func _can_hit(team: int, lane: int, target: Fighter) -> bool:
	return target.team != team and target.lane == lane and target.can_be_hit()


func _land(target: Fighter, hit: HitBox, direction: int, at: Vector2) -> void:
	target.take_hit(hit, direction)
	shake = maxf(shake, hit.shake)
	if sparks != null:
		sparks.spawn(at, 30.0 + hit.hitstop * 6.0)
