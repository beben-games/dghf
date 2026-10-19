extends SceneTree
## Checks placeholder sound (issue #65): the cues' files exist, the pool never
## grows, a hit, a block, a break, a kill, a swing, a barrel and a potion each
## play their cue, and nothing breaks without a Sounds node.
## Run: godot --headless --path . -s tests/sounds_test.gd
## Exits with 1 if any check fails.

const LANES: PackedFloat32Array = [760.0, 880.0, 1000.0]
const SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const A: int = Buttons.LIGHT
const H: int = Buttons.HEAVY
const G: int = Buttons.GUARD
const R: int = Buttons.RIGHT
const X: int = Buttons.DODGE

var _failures: int = 0
var _sounds: Sounds
var _made: Array[Node] = []


func _initialize() -> void:
	_test_no_node_no_trouble()
	_after_first_frame()


func _after_first_frame() -> void:
	await process_frame
	_sounds = Sounds.new()
	root.add_child(_sounds)
	_made.append(_sounds)
	_test_the_cues_load()
	_test_the_pool_never_grows()
	_test_fights_play_their_cues()
	_test_props_play_their_cues()
	_test_music_and_mute()
	for node in _made:
		node.free()
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func _repeat(mask: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(ticks)
	out.fill(mask)
	return out


func _test_no_node_no_trouble() -> void:
	Sounds.play(&"hit")
	Sounds.music(true)
	_check(Sounds.instance() == null, "without a Sounds node, playing is a no-op")


func _test_the_cues_load() -> void:
	for cue: StringName in Sounds.CUES:
		_check(ResourceLoader.exists(Sounds.CUES[cue][0]), "the file of the %s cue exists" % cue)
	_check(ResourceLoader.exists(Sounds.MUSIC), "the music loop exists")
	_check(Sounds.instance() == _sounds, "the node in the tree is the one that plays")


func _test_the_pool_never_grows() -> void:
	for i in 30:
		Sounds.play(&"hit")
	_check(_sounds.playing_count() <= Sounds.CAPACITY, "thirty hits at once use at most %d players (%d)" % [Sounds.CAPACITY, _sounds.playing_count()])
	_check(_sounds.get_child_count() == Sounds.CAPACITY + 1, "and nothing is made per hit")
	_sounds.played.clear()
	Sounds.play(&"not_a_cue")
	_check(_sounds.played.is_empty(), "an unknown cue is ignored")


## A fight of a few ticks: an attacker fed `samples` against a target fed `target_samples`.
func _fight(samples: Array, target_samples: Array = [], ticks: int = 40, target_health: int = 100) -> Array[Fighter]:
	var projectiles := Projectiles.new()
	var combat := Combat.new()
	combat.projectiles = projectiles
	var attacker := Fighter.new()
	attacker.bounds = Vector2(120.0, 1800.0)
	attacker.moves = [load("res://data/moves/poc/fireball.tres"), load("res://data/moves/poc/light.tres"), load("res://data/moves/poc/heavy.tres")]
	attacker.projectiles = projectiles
	attacker.setup(PlayerInput.new(1, InputSource.Scripted.new(PackedInt32Array(samples))), LANES, 1, 600.0)
	var target := Fighter.new()
	target.team = 2
	target.max_health = target_health
	target.max_guard = 100
	target.bounds = attacker.bounds
	target.setup(PlayerInput.new(2, InputSource.Scripted.new(PackedInt32Array(target_samples))), LANES, 1, 800.0)
	target.facing = -1
	combat.fighters = [attacker, target]
	_sounds.played.clear()
	for i in ticks:
		attacker.tick()
		target.tick()
		projectiles.tick(combat.fighters)
		combat.resolve()
	projectiles.free()
	_made.append(attacker)
	_made.append(target)
	return [attacker, target]


func _test_fights_play_their_cues() -> void:
	_fight([A])
	_check(_sounds.played.has(&"swing") and _sounds.played.has(&"hit"), "a light that lands plays a swing and a hit (%s)" % [_sounds.played])
	_fight([H])
	_check(_sounds.played.has(&"hit_heavy"), "a launcher plays the heavy hit (%s)" % [_sounds.played])
	_fight([A], _repeat(G, 40))
	_check(_sounds.played.has(&"block") and not _sounds.played.has(&"hit"), "a blocked light plays a block and no hit (%s)" % [_sounds.played])
	var pair: Array[Fighter] = _fight([A], _repeat(G, 40), 1, 100)
	pair[1].guard = 5
	_sounds.played.clear()
	for i in 20:
		pair[0].tick()
		pair[1].tick()
	# A break needs the combat to resolve: do it by hand with the light's hit.
	var light: Move = load("res://data/moves/poc/light.tres")
	var combat := Combat.new()
	combat.fighters = [pair[0], pair[1]]
	combat._land(pair[1], light.hit_boxes[0], 1, Vector2.ZERO)
	_check(_sounds.played.has(&"guard_break"), "a guard break plays the break (%s)" % [_sounds.played])
	_fight([A], [], 40, 5)
	_check(_sounds.played.has(&"death"), "the killing blow plays the death (%s)" % [_sounds.played])
	_fight(_repeat(X | R, 3))
	_check(_sounds.played.has(&"dash"), "the dash plays its cue (%s)" % [_sounds.played])
	_fight(_repeat(Buttons.DOWN, 3) + _repeat(Buttons.DOWN | R, 3) + _repeat(R, 2) + [R | A], [], 12)
	_check(_sounds.played.has(&"fireball"), "a fireball plays its cue (%s)" % [_sounds.played])


func _test_props_play_their_cues() -> void:
	var props := Props.new()
	props.setup(LANES, SCALES)
	root.add_child(props)
	_made.append(props)
	var barrel: Prop = props.spawn(Prop.Kind.BARREL, 1, 800.0)
	var hit := HitBox.new()
	hit.hitstop = 4
	_sounds.played.clear()
	barrel.take_hit(hit, 1)
	_check(_sounds.played == [&"hit"], "cracking a barrel plays a hit (%s)" % [_sounds.played])
	barrel.take_hit(hit, 1)
	_check(_sounds.played.has(&"barrel"), "breaking it plays the barrel (%s)" % [_sounds.played])
	var player := Fighter.new()
	player.max_health = 100
	player.bounds = Vector2(120.0, 1800.0)
	player.setup(PlayerInput.new(1, InputSource.new()), LANES, 1, 800.0)
	player.health = 50
	_made.append(player)
	_sounds.played.clear()
	props.tick([player])
	props.tick([player])
	_check(_sounds.played.has(&"pickup") and player.health == 75, "taking the potion plays the pick-up (%s, health %d)" % [_sounds.played, player.health])


func _test_music_and_mute() -> void:
	Sounds.music(true)
	_check(_sounds.music_playing(), "the loop plays when asked")
	_sounds.muted = true
	_check(_sounds.muted, "F9's mute is a switch on the node")
	_sounds.muted = false
	Sounds.music(false)
	_check(not _sounds.music_playing(), "and stops when asked")
