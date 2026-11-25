@tool
## The Map tab's Export Package and Playtest. Exporting writes the open map as a map package
## (MapExporter, see MapFormat) into res://exports/<id>/, which has a .gdignore so the editor never
## imports the copies. Playtesting exports, then starts the game on it (see the game's Playtest).
## In the Map SDK that's the installed game, whose path is chosen once and kept in the editor
## settings; in the game's own project it's this project, run by this editor's Godot.

const MapFiles := preload("map_files.gd")
const EXPORTS_DIR: String = "res://exports"
const GAME_PATH_SETTING: String = "super_monster_tag/game_executable"
const METADATA_SECTION: String = "level_tools"
## Where Steam usually installs the game, tried until a path has been chosen.
const LIKELY_GAME_PATHS: PackedStringArray = [
	"C:/Program Files (x86)/Steam/steamapps/common/Super Monster Tag/SuperMonsterTag.exe",
	"C:/Program Files/Steam/steamapps/common/Super Monster Tag/SuperMonsterTag.exe",
]


## Exports the map rooted at [param root]. Returns {"folder" (absolute, "" if nothing was written),
## "message", "problems" (each "<node path>: what to change", from MapExporter)}.
static func export_map(root: Node3D) -> Dictionary:
	var result: Dictionary = {"folder": "", "message": "", "problems": []}
	if root == null or root.get_script() != MapFiles.GAME_MAP_SCRIPT:
		result["message"] = "Open a map scene first."
		return result
	if root.scene_file_path == "":
		result["message"] = "Save the map first."
		return result
	var info: Resource = MapFiles.find_info(root.scene_file_path)
	if info == null:
		result["message"] = "No MapInfo under res://maps points at this scene."
		return result
	var id: String = info.resource_path.get_file().get_basename()
	var exports: String = ProjectSettings.globalize_path(EXPORTS_DIR)
	var folder: String = exports.path_join(id)
	DirAccess.make_dir_recursive_absolute(exports)
	if not FileAccess.file_exists(exports.path_join(".gdignore")):
		FileAccess.open(exports.path_join(".gdignore"), FileAccess.WRITE).close()
	# A fresh folder, so files the map no longer uses don't linger in the package.
	_remove_folder(folder, exports)
	var excluded: Array = []
	for mode: Variant in info.get(&"excluded_modes"):
		excluded.append(int(mode))
	var listing: Dictionary = {
		"name": info.get(&"display_name"),
		"description": info.get(&"description"),
		"author": info.get(&"author"),
		"excluded_modes": excluded,
		"ambience": info.get(&"ambience"),
		"sort_order": info.get(&"sort_order"),
	}
	var exporter: MapExporter = MapExporter.new()
	var error: Error = exporter.save(root, listing, folder, info.get(&"thumbnail"))
	result["problems"] = exporter.problems
	if error != OK:
		result["message"] = "Couldn't write the package to %s (%s)." % [folder, error_string(error)]
		return result
	result["folder"] = folder
	var left_out: String = "" if exporter.problems.is_empty() else " %d part%s left out (listed above)." % [
			exporter.problems.size(), "" if exporter.problems.size() == 1 else "s"]
	result["message"] = "Exported to %s.%s" % [folder, left_out]
	# Modders publish from the game, which lists the exports folder once it's added.
	if MapFormat.is_sdk():
		result["message"] += " To publish it, open My Maps in the game and add %s." % exports
	return result


## Starts the game playtesting the package in [param folder], in mode [param mode_id] with
## [param bots] bots. Returns what happened, for the dock.
static func playtest(folder: String, mode_id: int, bots: int) -> String:
	var executable: String = OS.get_executable_path()
	var args: PackedStringArray = []
	if MapFormat.is_sdk():
		executable = game_path()
		if executable == "" or not FileAccess.file_exists(executable):
			return "Choose the game's SuperMonsterTag.exe first (Game, below). In Steam: right-click the game, Manage, Browse local files."
	else:
		# The game's own project: run it with this editor's Godot.
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--test-map", folder, "--test-mode", str(mode_id), "--test-bots", str(bots)])
	var process_id: int = OS.create_process(executable, args)
	if process_id <= 0:
		return "Couldn't start %s." % executable
	return "Playtesting. In the game, F5 reloads the map after you export again."


## The installed game's executable (Map SDK only): the one chosen, else the first likely one that
## exists, else "".
static func game_path() -> String:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.has_setting(GAME_PATH_SETTING) and str(settings.get_setting(GAME_PATH_SETTING)) != "":
		return str(settings.get_setting(GAME_PATH_SETTING))
	for path: String in LIKELY_GAME_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""


static func set_game_path(path: String) -> void:
	EditorInterface.get_editor_settings().set_setting(GAME_PATH_SETTING, path)


## A playtest choice kept for this project (mode, bots).
static func get_choice(key: String, default: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(METADATA_SECTION, key, default)


static func set_choice(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(METADATA_SECTION, key, value)


## Deletes [param folder] and everything in it, only if it's inside [param within].
static func _remove_folder(folder: String, within: String) -> void:
	if not folder.begins_with(within + "/") or not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub), within)
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
