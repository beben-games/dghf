class_name FighterSkin
extends RefCounted
## A fighter's art: one sprite sheet of equal cells and a skin.json that names
## the animations. Loaded from a folder at run time, so art can be swapped by
## replacing files. The format is described in docs/design/2026-10-04-poc-1080p-player.md.

var texture: Texture2D
var cell: Vector2 = Vector2.ZERO
## The point of a cell that sits on the fighter's position: the feet.
var feet: Vector2 = Vector2.ZERO
var columns: int = 1
var faces_left: bool = false
## name -> {"frames": Array of cell numbers, "ticks": ticks per frame, "loop": bool}
var animations: Dictionary = {}


## Returns null if the folder has no skin, or the skin can't be read.
static func load_from(folder: String) -> FighterSkin:
	var json_path: String = folder.path_join("skin.json")
	if not FileAccess.file_exists(json_path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not data is Dictionary:
		push_warning("Skin %s: skin.json is not valid." % folder)
		return null
	var image := Image.new()
	# Read the bytes ourselves: the folder may be hidden from Godot's importer.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(folder.path_join(data.get("sheet", "sheet.png")))
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		push_warning("Skin %s: the sheet can't be read." % folder)
		return null
	var skin := FighterSkin.new()
	skin.texture = ImageTexture.create_from_image(image)
	skin.cell = Vector2(data["cell"][0], data["cell"][1])
	skin.feet = Vector2(data["feet"][0], data["feet"][1])
	skin.columns = int(data["columns"])
	skin.faces_left = data.get("faces", "right") == "left"
	skin.animations = data["animations"]
	return skin


func has(animation: StringName) -> bool:
	return animations.has(String(animation))


## How long an animation plays once through, in ticks.
func duration(animation: StringName) -> int:
	var entry: Dictionary = animations[String(animation)]
	return (entry["frames"] as Array).size() * int(entry.get("ticks", 6))


## The sheet region for an animation. `ticks` is how long it has played.
## With `progress` from 0 to 1 the frame follows that instead, which is how a
## move of any length shows its whole animation.
func region(animation: StringName, ticks: int, progress: float = -1.0) -> Rect2:
	var entry: Dictionary = animations[String(animation)]
	var frames: Array = entry["frames"]
	var index: int
	if progress >= 0.0:
		index = mini(int(progress * frames.size()), frames.size() - 1)
	else:
		@warning_ignore("integer_division")
		index = ticks / int(entry.get("ticks", 6))
		index = index % frames.size() if entry.get("loop", true) else mini(index, frames.size() - 1)
	var number: int = int(frames[index])
	@warning_ignore("integer_division")
	return Rect2(Vector2(number % columns, number / columns) * cell, cell)
