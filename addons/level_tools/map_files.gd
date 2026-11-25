@tool
## Map files for the Level Tools dock: creating a new map (scene plus MapInfo) and finding the
## MapInfo of an open map. GameMap and MapInfo aren't tool scripts, so in the editor their nodes
## and resources are placeholders: set their exports with set(), never call their methods.

const GAME_MAP_SCRIPT: Script = preload("res://scripts/game_map.gd")
const MAP_INFO_SCRIPT: Script = preload("res://scripts/map_info.gd")
const KIT_ISLAND_SCRIPT: Script = preload("res://scripts/kit/kit_island.gd")
const ENVIRONMENT: Environment = preload("res://assets/environments/sky.tres")
const THUMBNAIL_SIZE: Vector2i = Vector2i(640, 360)


## A map id from a display name: "Sky Fort 2" becomes "sky_fort_2".
static func id_for(display_name: String) -> String:
	var id: String = ""
	for character: String in display_name.strip_edges().to_snake_case():
		if character == "_" or character.is_valid_identifier() or character.is_valid_int():
			id += character
	return id.trim_prefix("_").trim_suffix("_")


static func scene_path_for(id: String) -> String:
	return "%s/%s/%s.tscn" % [MapInfo.MAPS_DIR, id, id]


## Creates res://maps/<id>/ with a starter map (an island, spawn, sky, sun and
## spectator camera) and its MapInfo. Returns an error message, or "" on success.
static func create_map(display_name: String) -> String:
	var id: String = id_for(display_name)
	if id == "":
		return "Give the map a name with letters or numbers."
	var folder: String = "%s/%s" % [MapInfo.MAPS_DIR, id]
	if DirAccess.dir_exists_absolute(folder):
		return "%s already exists." % folder
	DirAccess.make_dir_recursive_absolute(folder)

	var root: Node3D = Node3D.new()
	root.name = display_name.to_pascal_case()
	root.set_script(GAME_MAP_SCRIPT)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = ENVIRONMENT
	_add(root, root, environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-50), deg_to_rad(30), 0)), Vector3(0, 10, 0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	_add(root, root, sun)
	var geometry: Node3D = Node3D.new()
	geometry.name = "Geometry"
	_add(root, root, geometry)
	var island: Node3D = KIT_ISLAND_SCRIPT.new()
	island.name = "StartIsland"
	island.set(&"color", KitPiece.Swatch.LAGOON)
	island.position = Vector3(0, -2, 0)
	_add(root, geometry, island)
	var camera: Camera3D = Camera3D.new()
	camera.name = "SpectatorCamera"
	camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0, -40, -40)).translated(Vector3(0, 40, 40))
	camera.fov = 55.0
	_add(root, root, camera)
	var spawn: Marker3D = Marker3D.new()
	spawn.name = "PlayerSpawn"
	_add(root, root, spawn)
	for group_name: StringName in GameMap.MARKER_GROUPS:
		var group: Node3D = Node3D.new()
		group.name = group_name
		_add(root, root, group)

	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(root)
	root.free()
	if error == OK:
		error = ResourceSaver.save(scene, scene_path_for(id))
	if error != OK:
		return "Couldn't save the map scene (%s)." % error_string(error)

	var info: Resource = Resource.new()
	info.set_script(MAP_INFO_SCRIPT)
	info.set(&"display_name", display_name.strip_edges())
	info.set(&"scene", scene_path_for(id))
	info.set(&"sort_order", 10)
	error = ResourceSaver.save(info, "%s/%s.tres" % [folder, id])
	if error != OK:
		return "Couldn't save the map info (%s)." % error_string(error)
	return ""


## The MapInfo whose scene is [param scene_path], or null.
static func find_info(scene_path: String, directory: String = MapInfo.MAPS_DIR) -> Resource:
	for entry: String in ResourceLoader.list_directory(directory):
		var path: String = directory.path_join(entry)
		if entry.ends_with("/"):
			var found: Resource = find_info(scene_path, path.trim_suffix("/"))
			if found != null:
				return found
		elif entry.get_extension() == "tres":
			var info: Resource = load(path)
			if info != null and info.get_script() == MAP_INFO_SCRIPT and _resolve(info.get(&"scene")) == scene_path:
				return info
	return null


## A res:// path for [param path], which may be a uid:// path (the inspector saves those).
static func _resolve(path: String) -> String:
	if path.begins_with("uid://"):
		return ResourceUID.get_id_path(ResourceUID.text_to_id(path))
	return path


static func _add(root: Node, parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = root
