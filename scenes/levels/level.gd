class_name Level
extends Resource
## A level as data (issue #62): a stage of some width with arenas along it,
## each a list of waves. The melee is the first one, data/levels/melee.tres.

@export var title: String = ""
@export var stage_width: float = 5760.0
@export var arenas: Array[ArenaData] = []
