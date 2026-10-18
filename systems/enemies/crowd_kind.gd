class_name CrowdKind
extends Resource
## A kind of small fry, as data (issue #61): what a crowd body is when it is
## revived as this kind. The body stays the same pooled CrowdBody; the kind
## gives it its health, speed, look, reach, shield and moves. Files live in
## data/enemies/.

enum Look { PLAIN, FAST, SHIELD, THROWER }

@export var id: StringName = &"small_fry"
@export var max_health: int = 30
@export var walk_speed: float = 4.0
## The plain figure's colour, and its drawn size against the plain small fry.
@export var body_color: Color = Color(0.55, 0.42, 0.3)
@export var scale: float = 1.0
@export var look: Look = Look.PLAIN

@export_group("Fighting")
## The usual swing.
@export var attack: Move
## An occasional second move, used one swing in `special_one_in` (0 never): the shield bash.
@export var special: Move
@export var special_one_in: int = 0
## How close it walks before it stops and swings. A thrower's is long.
@export var reach: float = 170.0
## A thrower backs off when the target is nearer than this. 0 never backs off.
@export var keep_away: float = 0.0
## A shield that stops hits from the front, drained by their damage until it breaks. 0 none.
@export var shield: int = 0
