class_name ArenaData
extends Resource
## One arena of a level (issue #62): the walls the camera locks between, and
## the waves to beat there, in order.

@export var left: float = 0.0
@export var right: float = 1920.0
@export var waves: Array[WaveData] = []
## Barrels standing in the arena (issue #64): x and lane each.
@export var props: Array[Vector2] = []
