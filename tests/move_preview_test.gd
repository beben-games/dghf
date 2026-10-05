extends SceneTree
## Checks the move preview tool's logic on a copy of a move in a scratch folder:
## finding move files, stepping, the phase of a frame, and reloading a changed file.
## Run: godot --headless --path . -s tests/move_preview_test.gd
## Exits with 1 if any check fails.

const PREVIEW: Script = preload("res://scenes/tools/move_preview/move_preview.gd")

var _failures: int = 0


func _initialize() -> void:
	var folder: String = "user://move_preview_test"
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("light.tres")
	var text: String = FileAccess.get_file_as_string("res://data/moves/poc/light.tres")
	_write(path, text)
	_write(folder.path_join("notes.txt"), "not a move")

	var preview: Node2D = PREVIEW.new()
	preview.moves_dir = folder
	preview.scan()
	_check(preview.paths == [path], "only the .tres files in the folder are listed")
	preview.select(0)
	_check(preview.move != null and preview.move.id == &"light" and preview.frame == 0, "the first move is shown on frame 0")
	_check(preview.phase() == "startup", "frame 0 of the light is startup")
	preview.step(8)
	_check(preview.frame == 8 and preview.phase() == "active", "frame 8 is active")
	preview.step(9)
	_check(preview.phase() == "recovery", "frame 17 is recovery")
	preview.step(10)
	_check(preview.frame == 0, "stepping past the last frame wraps to the first")
	preview.step(-1)
	_check(preview.frame == 26, "and stepping back from the first goes to the last")

	preview.watch()
	_check(preview.notice == "", "a file that has not changed is not reloaded")
	_write(path, text.replace("total_frames = 27", "total_frames = 12").replace("first_frame = 8\nlast_frame = 16", "first_frame = 3\nlast_frame = 5"))
	preview.watch()
	_check(preview.move.total_frames == 12, "a changed file is reloaded: the new length shows")
	_check(preview.move.hit_boxes[0].first_frame == 3, "and so do the boxes inside it")
	_check(preview.frame == 11, "the frame shown stays inside the shorter move")
	_check(preview.notice.contains("reloaded"), "the tool says it reloaded")

	_write(folder.path_join("heavy.tres"), FileAccess.get_file_as_string("res://data/moves/poc/heavy.tres"))
	preview.watch()
	_check(preview.paths.size() == 2 and preview.move.id == &"light", "a new file appears in the list without changing the move shown")
	_check(preview.index == 1, "the list is in alphabetical order: heavy, then light")
	preview.select(preview.index + 1)
	_check(preview.index == 0 and preview.move.id == &"heavy", "selecting past the last move wraps to the first")

	preview.free()
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("%d failed" % _failures if _failures else "all passed")
	quit(1 if _failures else 0)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)
