class_name MapBuilder
extends RefCounted
## Builds a GameMap from a package (see MapFormat) that anyone may have made, so it trusts
## nothing in it. Every node is a class from MapFormat's allowlists, made by the game; every
## property is one the class saves, of the right type; every resource is one the game builds,
## one of its own files, or one of the package's own GLBs or images, loaded as data. Node paths
## that point outside the map are cleared.
##
## Parts it can't use (an unknown property, a bad value) are skipped and listed in problems. A
## node class it doesn't know means the map is from a newer game, so nothing is built and error
## says so.

## Why the map couldn't be built, or "" if it was.
var error: String = ""
## What was skipped, one line each.
var problems: Array[String] = []

var _folder: String
var _resource_data: Array = []
## Built resources by index; null until first used.
var _resources: Array = []
## Indices of resources being built, to catch loops.
var _building: Dictionary[int, bool] = {}
## [node, property] pairs holding node paths, checked once the tree is built.
var _node_paths: Array[Array] = []
## Each class's saved properties, read once (property lists are slow to build).
var _known_by_type: Dictionary[String, Dictionary] = {}


func _init(folder: String) -> void:
	_folder = folder


## The package's map.json in [param folder], parsed, or {} if it's missing, too big or not JSON.
static func read_map_file(folder: String) -> Dictionary:
	var path: String = folder.path_join(MapFormat.MAP_FILE)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MapFormat.MAX_MAP_FILE_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## The files of the package in [param folder] that the game reads, relative to it and sorted: the
## map file, the thumbnail and the files under files/ that a package may carry. Anything else in the
## folder is left out (and never uploaded to the Workshop).
static func package_files(folder: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for relative: String in [MapFormat.MAP_FILE, MapFormat.THUMBNAIL_FILE]:
		if FileAccess.file_exists(folder.path_join(relative)):
			files.append(relative)
	_list_package_files(folder, MapFormat.FILES_DIR, files)
	files.sort()
	return files


## A fingerprint of the package in [param folder]: the path and contents of its map file and of
## every file under files/ (not the thumbnail, which doesn't change how it plays). Two copies that
## play the same have the same hash, so a lobby can tell whether everyone has the host's version.
static func package_hash(folder: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for relative: String in package_files(folder):
		if relative == MapFormat.THUMBNAIL_FILE:
			continue
		var digest: String = FileAccess.get_sha256(folder.path_join(relative))
		context.update(("%s\n%s\n" % [relative, digest]).to_utf8_buffer())
	return context.finish().hex_encode()


static func _list_package_files(folder: String, relative: String, into: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(folder.path_join(relative))
	if directory == null or into.size() > MapFormat.MAX_RESOURCES:
		return
	for file_name: String in directory.get_files():
		var path: String = relative.path_join(file_name)
		if MapFormat.is_package_file(path):
			into.append(path)
	for sub: String in directory.get_directories():
		_list_package_files(folder, relative.path_join(sub), into)


## The map, not yet in the tree, or null (see error).
func build() -> GameMap:
	error = ""
	problems.clear()
	var data: Dictionary = read_map_file(_folder)
	if data.is_empty():
		return _fail("Its map file is missing or damaged.")
	var format: Variant = data.get("format")
	if not (format is float or format is int):
		return _fail("Its map file is damaged.")
	if int(format) > MapFormat.VERSION:
		return _fail("It was made for a newer version of Super Monster Tag. Update the game to play it.")
	var nodes: Variant = data.get("nodes")
	_resource_data = data.get("resources", []) if data.get("resources", []) is Array else []
	if not nodes is Array or (nodes as Array).is_empty() or (nodes as Array).size() > MapFormat.MAX_NODES \
			or _resource_data.size() > MapFormat.MAX_RESOURCES:
		return _fail("Its map file is damaged or too big.")
	_resources.clear()
	_resources.resize(_resource_data.size())
	_building.clear()
	_node_paths.clear()
	var built: Array[Node] = []
	for index: int in (nodes as Array).size():
		var entry: Variant = nodes[index]
		var node: Node = _build_node(entry, index, built) if entry is Dictionary else null
		if node == null:
			_free_all(built)
			if error == "":
				error = "Its map file is damaged."
			return null
		built.append(node)
	_check_node_paths(built[0])
	return built[0] as GameMap


func _fail(message: String) -> GameMap:
	error = message
	return null


func _free_all(built: Array[Node]) -> void:
	for node: Node in built:
		if node.get_parent() == null:
			node.free()


func _build_node(entry: Dictionary, index: int, built: Array[Node]) -> Node:
	var type: String = str(entry.get("class", ""))
	if (index == 0) != (type == "GameMap"):
		error = "Its map file is damaged (the GameMap must be the root, and only the root)."
		return null
	var parent_index: int = -1
	if index > 0:
		var parent: Variant = entry.get("parent")
		parent_index = int(parent) if parent is float or parent is int else -1
		if parent_index < 0 or parent_index >= index:
			error = "Its map file is damaged (a node with no parent)."
			return null
	var node: Node = _make_node(type)
	if node == null:
		error = "It uses a %s, which this version of the game doesn't have. Update the game to play it." % type
		return null
	var node_name: String = str(entry.get("name", "")).validate_node_name()
	node.name = node_name if node_name != "" else "%s%d" % [type, index]
	_apply(node, entry.get("props", {}), node_name)
	if index > 0:
		built[parent_index].add_child(node)
		node.owner = built[0]
	return node


func _make_node(type: String) -> Node:
	if MapFormat.SCENES.has(type):
		return (load(MapFormat.SCENES[type]) as PackedScene).instantiate()
	if MapFormat.SCRIPTS.has(type):
		return (load(MapFormat.SCRIPTS[type]) as Script).new() as Node
	if type in MapFormat.NODES:
		return ClassDB.instantiate(type) as Node
	return null


## Sets [param props] on [param object], each only if the object saves a property by that name
## and the value fits it.
func _apply(object: Object, props: Variant, where: String) -> void:
	if not props is Dictionary:
		problems.append("%s: unreadable properties, skipped." % where)
		return
	var type: String = object.get_script().get_global_name() if object.get_script() != null else object.get_class()
	if not _known_by_type.has(type):
		_known_by_type[type] = _known_properties(object)
	var known: Dictionary[String, Dictionary] = _known_by_type[type]
	var later: Array = []
	for key: Variant in props:
		if not key is String:
			problems.append("%s: no property %s, skipped." % [where, key])
		elif not known.has(key):
			later.append(key)
		else:
			_apply_one(object, key, props[key], known[key], where)
	# Some properties only exist once others are set (a mesh's surface_material_override/0).
	if not later.is_empty():
		known = _known_properties(object)
		for key: String in later:
			if known.has(key):
				_apply_one(object, key, props[key], known[key], where)
			else:
				problems.append("%s: no property %s, skipped." % [where, key])


func _known_properties(object: Object) -> Dictionary[String, Dictionary]:
	var known: Dictionary[String, Dictionary] = {}
	for property: Dictionary in MapFormat.saved_properties(object):
		known[property["name"]] = property
	return known


func _apply_one(object: Object, key: String, raw: Variant, property: Dictionary, where: String) -> void:
	var decoded: Array = _decode(raw, property, "%s.%s" % [where, key])
	if decoded.is_empty():
		return
	var value: Variant = decoded[0]
	var current: Variant = object.get(key)
	if value is Array and current is Array and (current as Array).is_typed():
		var typed: Array = (current as Array).duplicate()
		typed.clear()
		if not _fits_typed(value, typed):
			problems.append("%s.%s: wrong kind of list, skipped." % [where, key])
			return
		typed.assign(value)
		value = typed
	if object is Node and (value is NodePath or value is Array):
		_node_paths.append([object, key])
	object.set(key, value)


## [param raw] as the value of [param property], in a one-item array, or [] (with a problem) if
## it doesn't fit.
func _decode(raw: Variant, property: Dictionary, where: String) -> Array:
	var type: int = property["type"]
	if raw is Dictionary and (raw as Dictionary).has(MapFormat.RESOURCE_KEY):
		var resource: Resource = _resource(raw[MapFormat.RESOURCE_KEY], where)
		if resource == null:
			return []
		if (type != TYPE_OBJECT and type != TYPE_NIL) or not _fits_resource(resource, property):
			problems.append("%s: a %s doesn't fit here, skipped." % [where, resource.get_class()])
			return []
		return [resource]
	if raw is Dictionary and (raw as Dictionary).has(MapFormat.RESOURCE_ARRAY_KEY):
		var indices: Variant = raw[MapFormat.RESOURCE_ARRAY_KEY]
		if type != TYPE_ARRAY or not indices is Array:
			problems.append("%s: unreadable list, skipped." % where)
			return []
		var list: Array = []
		for index: Variant in indices:
			list.append(_resource(index, where) if (index is float or index is int) and int(index) >= 0 else null)
		return [list]
	var value: Variant = JSON.to_native(raw, false)
	if value == null and raw != null:
		problems.append("%s: unreadable value, skipped." % where)
		return []
	if type == TYPE_NIL:
		return [value]
	if type == TYPE_OBJECT:
		if value != null:
			problems.append("%s: unreadable value, skipped." % where)
			return []
		return [null]
	if typeof(value) != type:
		if type == TYPE_FLOAT and value is int:
			return [float(value)]
		problems.append("%s: expected a %s, skipped." % [where, type_string(type)])
		return []
	if type == TYPE_INT and property["hint"] == PROPERTY_HINT_ENUM and not int(value) in MapFormat.enum_values(property["hint_string"]):
		problems.append("%s: %d isn't one of its choices, skipped." % [where, value])
		return []
	return [value]


func _fits_resource(resource: Resource, property: Dictionary) -> bool:
	if property["type"] == TYPE_NIL or property["hint"] != PROPERTY_HINT_RESOURCE_TYPE or property["hint_string"] == "":
		return true
	for type: String in (property["hint_string"] as String).split(","):
		if resource.is_class(type):
			return true
	return false


func _fits_typed(items: Array, typed: Array) -> bool:
	var builtin: int = typed.get_typed_builtin()
	for item: Variant in items:
		if builtin == TYPE_OBJECT:
			if item != null and not (item as Object).is_class(typed.get_typed_class_name()):
				return false
		elif typeof(item) != builtin and not (builtin == TYPE_FLOAT and item is int):
			return false
	return true


## The resource at [param raw_index] in the package's table, built the first time, or null
## (with a problem).
func _resource(raw_index: Variant, where: String) -> Resource:
	if not (raw_index is float or raw_index is int) or int(raw_index) < 0 or int(raw_index) >= _resource_data.size():
		problems.append("%s: missing resource, skipped." % where)
		return null
	var index: int = int(raw_index)
	if _resources[index] != null:
		return _resources[index]
	if _building.has(index):
		problems.append("%s: resources that contain themselves, skipped." % where)
		return null
	var entry: Variant = _resource_data[index]
	if not entry is Dictionary:
		problems.append("%s: unreadable resource, skipped." % where)
		return null
	_building[index] = true
	var resource: Resource = null
	if entry.has("base"):
		resource = _load_base(str(entry["base"]), where)
	elif entry.has("file"):
		resource = _load_file(str(entry["file"]), where)
	elif entry.has("class"):
		var type: String = str(entry["class"])
		if type in MapFormat.RESOURCES:
			resource = ClassDB.instantiate(type) as Resource
			_resources[index] = resource
			_apply(resource, entry.get("props", {}), "%s (%s)" % [where, type])
		else:
			problems.append("%s: a %s can't be in a map, skipped." % [where, type])
	_building.erase(index)
	_resources[index] = resource
	return resource


## One of the game's own files, if a map may use it.
func _load_base(path: String, where: String) -> Resource:
	if not MapFormat.is_base_path(path) or not ResourceLoader.exists(path):
		problems.append("%s: %s isn't one of the game's files a map can use, skipped." % [where, path])
		return null
	var resource: Resource = load(path)
	if resource == null or not MapFormat.is_base_type(resource):
		problems.append("%s: %s can't be used in a map, skipped." % [where, path])
		return null
	return resource


## One of the package's own files: a GLB as a PackedScene, or an image as a texture.
func _load_file(relative: String, where: String) -> Resource:
	var path: String = _folder.path_join(relative)
	if not MapFormat.is_package_file(relative) or not FileAccess.file_exists(path):
		problems.append("%s: missing file %s, skipped." % [where, relative])
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MapFormat.MAX_FILE_BYTES:
		problems.append("%s: %s is unreadable or too big, skipped." % [where, relative])
		return null
	file.close()
	var extension: String = relative.get_extension().to_lower()
	if extension in MapFormat.MODEL_EXTENSIONS:
		var document: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		if document.append_from_file(path, state) != OK:
			problems.append("%s: %s isn't a model the game can read, skipped." % [where, relative])
			return null
		var scene_root: Node = document.generate_scene(state)
		if scene_root == null:
			problems.append("%s: %s has nothing in it, skipped." % [where, relative])
			return null
		var scene: PackedScene = PackedScene.new()
		var packed: Error = scene.pack(scene_root)
		scene_root.free()
		if packed != OK:
			problems.append("%s: %s couldn't be read, skipped." % [where, relative])
			return null
		# Copies of a model share their collision through its path (LevelModel), and the file may
		# have changed since it was last loaded (a playtest's reload).
		scene.take_over_path(path)
		LevelModel.forget_shapes(path)
		return scene
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		problems.append("%s: %s isn't an image the game can read, skipped." % [where, relative])
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Clears node paths that point outside the map (or at nothing), so a package can't reach the
## match, the HUD or the game through a toy that follows a path.
func _check_node_paths(root: Node) -> void:
	for pair: Array in _node_paths:
		var node: Node = pair[0]
		var key: String = pair[1]
		var value: Variant = node.get(key)
		if value is NodePath:
			if not _inside(node, value, root):
				problems.append("%s.%s: points outside the map, cleared." % [root.get_path_to(node), key])
				node.set(key, NodePath())
		elif value is Array:
			var list: Array = (value as Array).duplicate()
			var changed: bool = false
			for index: int in list.size():
				if list[index] is NodePath and not _inside(node, list[index], root):
					list[index] = NodePath()
					changed = true
			if changed:
				problems.append("%s.%s: points outside the map, cleared." % [root.get_path_to(node), key])
				node.set(key, list)


func _inside(node: Node, path: NodePath, root: Node) -> bool:
	if path.is_empty():
		return true
	if path.is_absolute():
		return false
	var target: Node = node.get_node_or_null(path)
	return target != null and (target == root or root.is_ancestor_of(target))
