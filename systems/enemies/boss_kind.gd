class_name BossKind
extends Resource
## A boss as data (issue #67): who it is on screen, how big and tough, its
## moves, and the patterns its brain plays in each phase. Files live in
## data/bosses/. Who the bosses are comes from the team's characters (#33);
## the title here is a placeholder until then.

@export var title: String = "The Captain"
@export var max_health: int = 600
## Drawn and hit this many times the size of the plain fighter.
@export var size: float = 1.3
@export var body_color: Color = Color(0.6, 0.25, 0.25)
@export var walk_speed: float = 5.0
## How close it comes before it fights, and from how far it shoots.
@export var reach: float = 260.0
@export var shot_range: float = 620.0
## How likely it is, each think from beyond shot_range, to shoot rather than close in.
@export var shot_chance: float = 0.25

@export_group("Moves")
@export var moves: Array[Move] = []
## The strings it plays, by move id, one per line; a random one each time it is in reach.
@export var patterns: Array[String] = ["boss_light boss_light boss_heavy", "boss_grab", "boss_light boss_heavy"]
@export var patterns_two: Array[String] = ["boss_light boss_light boss_heavy", "boss_grab", "boss_lunge", "boss_heavy", "boss_lunge boss_light"]
## The second phase starts at this share of its health.
@export var phase_two_at: float = 0.5
## Ticks it rests after a string, in each phase.
@export var rest_min: int = 40
@export var rest_max: int = 80
@export var rest_min_two: int = 18
@export var rest_max_two: int = 45
## How likely it is to guard when the target swings within reach.
@export var guard_chance: float = 0.35
