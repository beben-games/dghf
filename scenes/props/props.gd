class_name Props
extends Node2D
## The props of a stage (issue #64), pooled like the crowd: barrels that break
## and the potions they drop. Tick it after the crowd and before Combat, with
## the players, so potions are picked up; add alive() to the bodies Combat
## resolves, so hits land on the barrels.

## How many props the pool holds, barrels and potions together.
@export var capacity: int = 24
## What a potion heals.
@export var heal: int = 25
## How near along the lane a player has to be to pick a potion up.
@export var pickup_reach: float = 70.0

var lane_y: PackedFloat32Array = PackedFloat32Array()
var lane_scale: PackedFloat32Array = PackedFloat32Array()

var _pool: Array[Prop] = []
var _alive: Array[Prop] = []


func setup(lanes: PackedFloat32Array, scales: PackedFloat32Array) -> void:
	lane_y = lanes
	lane_scale = scales
	for i in capacity:
		var prop := Prop.new()
		prop.visible = false
		add_child(prop)
		_pool.append(prop)


func alive() -> Array[Prop]:
	return _alive


func count() -> int:
	return _alive.size()


## Barrels standing right now.
func barrels() -> int:
	var n: int = 0
	for prop in _alive:
		if prop.is_barrel() and not prop.broken():
			n += 1
	return n


## A prop of `kind` on a lane at an x, from the pool. Null if the pool is empty.
func spawn(kind: Prop.Kind, spawn_lane: int, at_x: float) -> Prop:
	if _pool.is_empty():
		return null
	var prop: Prop = _pool.pop_back()
	prop.revive(lane_y, lane_scale, spawn_lane, at_x, kind)
	_alive.append(prop)
	return prop


func clear() -> void:
	for prop in _alive:
		prop.visible = false
		_pool.append(prop)
	_alive.clear()


func set_lanes(lanes: PackedFloat32Array, scales: PackedFloat32Array) -> void:
	lane_y = lanes
	lane_scale = scales
	for prop in _alive:
		prop.set_lanes(lanes, scales)


## One tick: props age, a barrel that just broke drops its potion, potions go to
## the players standing on them, and done props go back to the pool.
func tick(players: Array[Fighter]) -> void:
	for prop in _alive:
		prop.tick()
	for prop in _alive.duplicate():
		if prop.broken() and not prop.dropped:
			prop.dropped = true
			spawn(Prop.Kind.HEALTH, prop.lane, prop.x)
	for prop in _alive:
		if prop.is_barrel() or prop.taken:
			continue
		for player in players:
			if player.state != Body.State.DEAD and player.lane == prop.lane and absf(player.x - prop.x) <= pickup_reach:
				player.health = mini(player.health + heal, player.max_health)
				prop.taken = true
				break
	var i: int = _alive.size() - 1
	while i >= 0:
		var prop: Prop = _alive[i]
		if prop.is_done():
			prop.visible = false
			_alive.remove_at(i)
			_pool.append(prop)
		i -= 1
