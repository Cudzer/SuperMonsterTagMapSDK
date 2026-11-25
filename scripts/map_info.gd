class_name MapInfo
extends Resource
## A playable map as the Start Match picker lists it: name, scene and thumbnail. Every MapInfo
## saved anywhere under res://maps/ is picked up automatically. The file's name is the map's id,
## which is saved in Settings and replicated to clients, so don't rename a shipped one.

const MAPS_DIR: String = "res://maps"

@export var display_name: String = ""
@export_multiline var description: String = ""
## The map scene, rooted in a GameMap.
@export_file("*.tscn") var scene: String = ""
@export var thumbnail: Texture2D
## Modes this map shouldn't host even though it has the markers they need.
@export var excluded_modes: Array[GameModes.Id] = []
## Maps are listed by this, then by name.
@export var sort_order: int = 0
## Who made the map (a Map SDK map's package says so).
@export var author: String = ""
## A Map SDK map's ambient sound, borrowed from one of the game's maps (its id in Sound.AMBIENCE),
## or none. The game's own maps play their own. Keep the choices in step with Sound.AMBIENCE.
@export_enum("none", "islands") var ambience: String = "none"

## Package maps' ids start with this (then the package's folder name), so they never clash with the
## game's own maps.
const PACKAGE_PREFIX: String = "pkg:"
## Steam Workshop maps' ids are this plus the item's published file id (see Workshop).
const WORKSHOP_PREFIX: String = "ws:"

## Every registered map, sorted for the picker. Filled on first use.
static var _maps: Array[MapInfo] = []
## Package maps registered this session (register_package()).
static var _packages: Array[MapInfo] = []

## For a map from a package (see MapFormat) rather than the game's files: its folder.
var package_folder: String = ""
var _package_id: String = ""
## For a Workshop map: its published file id, and whether the player subscribes to it (only those
## are offered in Start Match; others were downloaded to play in someone else's lobby).
var workshop_id: int = 0
var subscribed: bool = false
## The package's hash (MapBuilder.package_hash()), worked out on first use.
var _package_hash: String = ""

## Marker counts per group in the map scene, read once from the packed scene.
var _marker_counts: Dictionary[StringName, int] = {}


## The map's id: its file name without the extension, or PACKAGE_PREFIX plus its folder's name.
func get_id() -> String:
	return _package_id if is_package() else resource_path.get_file().get_basename()


func is_package() -> bool:
	return package_folder != ""


## Whether it's a map from the Steam Workshop.
func is_community() -> bool:
	return workshop_id != 0


## A package's fingerprint (MapBuilder.package_hash()), "" for a game map. Worked out once.
func get_package_hash() -> String:
	if is_package() and _package_hash == "":
		_package_hash = MapBuilder.package_hash(package_folder)
	return _package_hash


## The display name of the map with [param id], for screens that list past matches: "Community
## map" for a Workshop map that isn't here any more, [param unknown] for anything else.
static func name_of(id: String, unknown: String = "?") -> String:
	var info: MapInfo = find(id)
	if info != null:
		return info.display_name
	return "Community map" if is_community_id(id) else unknown


## Whether [param id] names a Workshop map.
static func is_community_id(id: String) -> bool:
	return id.begins_with(WORKSHOP_PREFIX)


## The map's id in Sound.AMBIENCE: its own, or the game map a package borrows it from.
func get_ambience_id() -> String:
	if not is_package():
		return get_id()
	return "" if ambience == "none" else ambience


## A new copy of the map, not yet in the tree, or null if a package can't be built (the reason is
## printed).
func instantiate_map() -> GameMap:
	if not is_package():
		return (load(scene) as PackedScene).instantiate() as GameMap
	var builder: MapBuilder = MapBuilder.new(package_folder)
	var map: GameMap = builder.build()
	if map == null:
		push_error("Couldn't build the map %s: %s" % [display_name, builder.error])
	elif not builder.problems.is_empty():
		push_warning("The map %s skipped %d parts:\n%s" % [display_name, builder.problems.size(), "\n".join(builder.problems)])
	return map


## Why [param mode_id] can't be played on this map, or "" if it can.
func get_unsupported_reason(mode_id: int) -> String:
	if mode_id in excluded_modes:
		return "Not available on this map"
	var needed: Dictionary = GameModes.MARKERS_NEEDED[mode_id]
	for group: StringName in needed:
		if count_markers(group) < needed[group]:
			return "Needs %d %s" % [needed[group], String(group).capitalize().to_lower()]
	return ""


func supports(mode_id: int) -> bool:
	return get_unsupported_reason(mode_id) == ""


## How many markers the map scene has under its [param group] node (see GameMap's groups).
## Reads the packed scene's node list rather than instancing the map.
func count_markers(group: StringName) -> int:
	if _marker_counts.is_empty() and not is_package():
		var state: SceneState = (load(scene) as PackedScene).get_state()
		for index: int in state.get_node_count():
			var parent: StringName = StringName(String(state.get_node_path(index, true)).trim_prefix("./"))
			if parent in GameMap.MARKER_GROUPS:
				_marker_counts[parent] = _marker_counts.get(parent, 0) + 1
	return _marker_counts.get(group, 0)


static func get_all() -> Array[MapInfo]:
	if _maps.is_empty():
		_scan(MAPS_DIR)
		_maps.sort_custom(func(a: MapInfo, b: MapInfo) -> bool:
			return a.display_name < b.display_name if a.sort_order == b.sort_order else a.sort_order < b.sort_order)
	return _maps


## The registered map with [param id], or null. Only registered maps can be found, so a
## replicated id can't make a peer load an arbitrary scene.
static func find(id: String) -> MapInfo:
	for info: MapInfo in get_all() + _packages:
		if info.get_id() == id:
			return info
	return null


## The listing of the package in [param folder], with the id [param id], or null if it has no
## readable map file. Everything read is clamped: a package's text comes from anyone.
static func from_package(folder: String, id: String) -> MapInfo:
	var data: Dictionary = MapBuilder.read_map_file(folder)
	if data.is_empty():
		return null
	var info: MapInfo = MapInfo.new()
	info.package_folder = folder
	info._package_id = id
	var listing: Dictionary = data.get("info", {}) if data.get("info", {}) is Dictionary else {}
	info.display_name = str(listing.get("name", folder.get_file())).strip_edges().left(48)
	if info.display_name == "":
		info.display_name = folder.get_file()
	info.description = str(listing.get("description", "")).left(400)
	info.ambience = str(listing.get("ambience", "none"))
	info.author = str(listing.get("author", "")).strip_edges().left(48)
	var sort: Variant = listing.get("sort_order", 0)
	info.sort_order = int(sort) if sort is float or sort is int else 0
	var excluded: Variant = listing.get("excluded_modes", [])
	for mode: Variant in excluded if excluded is Array else []:
		if (mode is float or mode is int) and int(mode) >= 0 and int(mode) < GameModes.NAMES.size():
			info.excluded_modes.append(int(mode) as GameModes.Id)
	var thumbnail_path: String = folder.path_join(MapFormat.THUMBNAIL_FILE)
	if FileAccess.file_exists(thumbnail_path):
		var image: Image = Image.load_from_file(thumbnail_path)
		if image != null and not image.is_empty():
			info.thumbnail = ImageTexture.create_from_image(image)
	info._count_package_markers(data.get("nodes", []))
	return info


## Makes [param info] (a package map) findable by its id this session, replacing one with the
## same id.
static func register_package(info: MapInfo) -> void:
	unregister_package(info.get_id())
	_packages.append(info)


static func unregister_package(id: String) -> void:
	_packages = _packages.filter(func(other: MapInfo) -> bool: return other.get_id() != id)


## The Workshop maps the player subscribes to, by name, for Start Match's Community section.
static func get_community() -> Array[MapInfo]:
	var maps: Array[MapInfo] = []
	for info: MapInfo in _packages:
		if info.is_community() and info.subscribed:
			maps.append(info)
	maps.sort_custom(func(a: MapInfo, b: MapInfo) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return maps


## Every Workshop map registered this session, subscribed or not.
static func get_registered_community() -> Array[MapInfo]:
	return _packages.filter(func(info: MapInfo) -> bool: return info.is_community())


## Counts markers from a package's node list: children of the marker groups under the root.
func _count_package_markers(nodes: Variant) -> void:
	if not nodes is Array:
		return
	var groups: Dictionary[int, StringName] = {}
	for index: int in (nodes as Array).size():
		var entry: Variant = nodes[index]
		if not entry is Dictionary:
			continue
		var parent: Variant = entry.get("parent")
		var parent_index: int = int(parent) if parent is float or parent is int else -1
		var node_name: StringName = StringName(str(entry.get("name", "")))
		if parent_index == 0 and node_name in GameMap.MARKER_GROUPS:
			groups[index] = node_name
		elif groups.has(parent_index):
			_marker_counts[groups[parent_index]] = _marker_counts.get(groups[parent_index], 0) + 1


## The map with [param id], or the first map if there's none by that id (e.g. an unset setting).
static func find_or_default(id: String) -> MapInfo:
	var info: MapInfo = find(id)
	if info == null and not get_all().is_empty():
		info = get_all()[0]
	return info


static func _scan(directory: String) -> void:
	for entry: String in ResourceLoader.list_directory(directory):
		var path: String = directory.path_join(entry)
		if entry.ends_with("/"):
			_scan(path.trim_suffix("/"))
		elif entry.get_extension() == "tres":
			var info: MapInfo = load(path) as MapInfo
			if info != null and info.scene != "":
				_maps.append(info)
