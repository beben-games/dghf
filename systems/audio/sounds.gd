class_name Sounds
extends Node
## Placeholder sound (issue #65): one pool of players for every cue, nothing
## made per hit, and a music loop. Anything in the game says
## `Sounds.play(&"hit")`; with no Sounds node in the tree (a test) that is a
## no-op. The cues, their files, volumes and pitch wander are the table below:
## data to tune, and the files to replace when the team's sounds arrive.

## Cue: file, volume in dB, how far the pitch wanders each time (0.1 is ten percent).
const CUES: Dictionary = {
	&"swing": ["res://assets/sfx/swing.ogg", -12.0, 0.15],
	&"dash": ["res://assets/sfx/dash.ogg", -10.0, 0.1],
	&"hit": ["res://assets/sfx/hit.ogg", -5.0, 0.12],
	&"hit_heavy": ["res://assets/sfx/hit_heavy.ogg", -2.0, 0.08],
	&"block": ["res://assets/sfx/block.ogg", -6.0, 0.1],
	&"guard_break": ["res://assets/sfx/guard_break.ogg", 0.0, 0.05],
	&"fireball": ["res://assets/sfx/fireball.ogg", -6.0, 0.1],
	&"death": ["res://assets/sfx/death.ogg", -6.0, 0.15],
	&"pickup": ["res://assets/sfx/pickup.ogg", -6.0, 0.0],
	&"barrel": ["res://assets/sfx/barrel.ogg", -4.0, 0.1],
}
const MUSIC: String = "res://assets/music/placeholder_loop.ogg"
const MUSIC_DB: float = -14.0
## How many cues can sound at once. The oldest player is taken over past that.
const CAPACITY: int = 12
## How many of the last cues are remembered, for tests and the readout.
const REMEMBER: int = 32

static var _instance: Sounds

## The last cues played, oldest first.
var played: Array[StringName] = []
var muted: bool = false:
	set(value):
		muted = value
		for player in _players:
			player.volume_db = -80.0 if muted else player.volume_db
		_music.volume_db = -80.0 if muted else MUSIC_DB

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _next: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	_instance = self
	for cue: StringName in CUES:
		var path: String = CUES[cue][0]
		if ResourceLoader.exists(path):
			_streams[cue] = load(path)
	for i in CAPACITY:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	if ResourceLoader.exists(MUSIC):
		var loop: AudioStream = load(MUSIC)
		if loop is AudioStreamOggVorbis:
			(loop as AudioStreamOggVorbis).loop = true
		_music.stream = loop


## Leaving the tree stops every player, so nothing is left sounding (or held) at exit.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	_music.stop()
	_music.stream = null
	_streams.clear()
	if _instance == self:
		_instance = null


## Plays a cue on a free player, or the oldest one. Nothing happens without a Sounds node.
static func play(cue: StringName) -> void:
	if _instance != null:
		_instance._play(cue)


## Starts or stops the music loop.
static func music(on: bool) -> void:
	if _instance != null:
		_instance._music_on(on)


static func instance() -> Sounds:
	return _instance


func _play(cue: StringName) -> void:
	if not CUES.has(cue):
		return
	played.append(cue)
	if played.size() > REMEMBER:
		played.remove_at(0)
	var stream: AudioStream = _streams.get(cue)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _players[_next]
		_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = -80.0 if muted else float(CUES[cue][1])
	var wander: float = CUES[cue][2]
	player.pitch_scale = 1.0 + randf_range(-wander, wander)
	player.play()


func _music_on(on: bool) -> void:
	if on and _music.stream != null and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


func music_playing() -> bool:
	return _music.playing


## How many cue players are sounding right now.
func playing_count() -> int:
	var n: int = 0
	for player in _players:
		if player.playing:
			n += 1
	return n
