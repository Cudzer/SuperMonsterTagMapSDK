@tool
class_name MapExporter
extends RefCounted
## Writes a map scene as a package (see MapFormat): map.json, the thumbnail, and copies of the
## map's own GLBs and images. The Map SDK runs it; so do the tests, on the game's own maps.
##
## Only nodes the map scene owns are saved, never the parts kit pieces and toys build for
## themselves, and of each, only the properties that differ from a fresh one. Anything a package
## can't hold (a script of the modder's own, a node type that isn't allowed) is listed in
## problems instead, worded as what to change.

## What's wrong, one line each. A package with problems still saves, without those parts.
var problems: Array[String] = []

var _root: Node
var _nodes: Array[Dictionary] = []
var _resources: Array[Dictionary] = []
## Resource instance id -> index in _resources.
var _resource_ids: Dictionary[int, int] = {}
## Package-relative path -> the SDK project's file it's copied from.
var _files: Dictionary[String, String] = {}
## A fresh node or resource per class, to tell which properties were changed.
var _templates: Dictionary[String, Object] = {}


## The package's map.json for the map rooted at [param root]. [param info] is the listing: name,
## description, author, excluded_modes (GameModes ids), ambience (a game map's id) and
## sort_order.
func build_data(root: Node, info: Dictionary) -> Dictionary:
	problems.clear()
	_nodes.clear()
	_resources.clear()
	_resource_ids.clear()
	_files.clear()
	_root = root
	if root.get_script() == null or root.get_script().get_global_name() != &"GameMap":
		problems.append("The scene's root must be a GameMap (made with Level Tools' New Map).")
	_add_node(root, -1)
	for template: Object in _templates.values():
		if template is Node:
			(template as Node).free()
	_templates.clear()
	return {
		"format": MapFormat.VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"info": info,
		"resources": _resources,
		"nodes": _nodes,
	}


## Writes the package for [param root] into [param folder] (made if missing): map.json, the
## files it uses and [param thumbnail] if given. Returns an error code; problems lists what was
## left out.
func save(root: Node, info: Dictionary, folder: String, thumbnail: Texture2D = null) -> Error:
	var data: Dictionary = build_data(root, info)
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(folder.path_join(MapFormat.MAP_FILE), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# Full precision, so every value builds back exactly.
	file.store_string(JSON.stringify(data, "\t", false, true))
	file.close()
	for relative: String in _files:
		var target: String = folder.path_join(relative)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_files[relative])
		if bytes.is_empty():
			problems.append("Couldn't read %s to copy it into the package." % _files[relative])
			continue
		var out: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			return FileAccess.get_open_error()
		out.store_buffer(bytes)
		out.close()
	if thumbnail != null and thumbnail.get_image() != null:
		thumbnail.get_image().save_png(folder.path_join(MapFormat.THUMBNAIL_FILE))
	return OK


func _add_node(node: Node, parent_index: int) -> void:
	var type: String = _type_of(node)
	if type == "":
		return
	var index: int = _nodes.size()
	var entry: Dictionary = {"name": String(node.name), "parent": parent_index, "class": type}
	_nodes.append(entry)
	var props: Dictionary = _changed_properties(node, _template_for(type))
	if not props.is_empty():
		entry["props"] = props
	for child: Node in node.get_children():
		if child.owner == _root:
			_add_node(child, index)
		elif _owns_any(child):
			problems.append("%s: nodes added inside a toy's own parts aren't saved. Move them out." % _root.get_path_to(child))


## The class a map saves [param node] as, or "" (with a problem) if a package can't hold it.
func _type_of(node: Node) -> String:
	var where: String = String(_root.get_path_to(node)) if node != _root else String(node.name)
	if node != _root and node.scene_file_path != "":
		for type: String in MapFormat.SCENES:
			if MapFormat.SCENES[type] == node.scene_file_path:
				return type
		if node.scene_file_path.get_extension().to_lower() in MapFormat.MODEL_EXTENSIONS:
			problems.append("%s: a model placed as a scene isn't saved. Place it as a LevelModel (Level Tools' Models tab)." % where)
		else:
			problems.append("%s: scenes of your own aren't saved (%s). Build it from kit pieces and models in the map." % [where, node.scene_file_path])
		return ""
	var script: Script = node.get_script() as Script
	if script != null:
		var type: String = script.get_global_name()
		if MapFormat.SCRIPTS.get(type, "") == script.resource_path:
			return type
		problems.append("%s: scripts of your own can't be in a map (%s). Use the kit pieces and toys." % [where, script.resource_path])
		return ""
	if node.get_class() in MapFormat.NODES:
		return node.get_class()
	problems.append("%s: a %s can't be in a map." % [where, node.get_class()])
	return ""


func _owns_any(node: Node) -> bool:
	for child: Node in node.get_children():
		if child.owner == _root or _owns_any(child):
			return true
	return false


func _template_for(type: String) -> Object:
	if not _templates.has(type):
		var template: Object
		if MapFormat.SCENES.has(type):
			template = (load(MapFormat.SCENES[type]) as PackedScene).instantiate()
		elif MapFormat.SCRIPTS.has(type):
			template = (load(MapFormat.SCRIPTS[type]) as Script).new()
		else:
			template = ClassDB.instantiate(type)
		_templates[type] = template
	return _templates[type]


## [param object]'s saved properties that differ from [param template]'s, encoded.
func _changed_properties(object: Object, template: Object) -> Dictionary:
	var props: Dictionary = {}
	for property: Dictionary in MapFormat.saved_properties(object):
		var property_name: String = property["name"]
		var value: Variant = object.get(property_name)
		if template != null and _same(value, template.get(property_name)):
			continue
		var encoded: Variant = _encode(value, property_name)
		if encoded != null or value == null:
			props[property_name] = encoded
	return props


func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


## A property value as map.json holds it: resources as {"res": index}, arrays of them as
## {"res_array": [...]}, anything else through JSON.from_native(). Null if it can't be saved.
func _encode(value: Variant, property_name: String) -> Variant:
	if typeof(value) == TYPE_OBJECT:
		if value == null:
			return null
		if not value is Resource:
			problems.append("%s: only resources can be saved, not a %s." % [property_name, (value as Object).get_class()])
			return null
		var index: int = _resource_index(value as Resource, property_name)
		return {MapFormat.RESOURCE_KEY: index} if index >= 0 else null
	if value is Array and (value as Array).any(func(item: Variant) -> bool: return typeof(item) == TYPE_OBJECT):
		var indices: Array = []
		for item: Variant in value:
			indices.append(_resource_index(item as Resource, property_name) if item is Resource else -1)
		return {MapFormat.RESOURCE_ARRAY_KEY: indices}
	if value is Dictionary and _holds_objects(value):
		problems.append("%s: a dictionary of resources can't be saved." % property_name)
		return null
	return JSON.from_native(value)


func _holds_objects(dictionary: Dictionary) -> bool:
	for key: Variant in dictionary:
		if key is Object or dictionary[key] is Object:
			return true
	return false


## [param resource]'s index in the resource table, adding it the first time, or -1 if a package
## can't hold it. The game's own files are named by path, the map's own GLBs and images are
## copied into the package, and everything else is saved property by property.
func _resource_index(resource: Resource, property_name: String) -> int:
	if resource == null:
		return -1
	var id: int = resource.get_instance_id()
	if _resource_ids.has(id):
		return _resource_ids[id]
	var path: String = resource.resource_path
	var entry: Dictionary = {}
	var extension: String = path.get_extension().to_lower()
	if MapFormat.is_game_file(path) and MapFormat.is_base_type(resource):
		entry = {"base": path}
	elif path.begins_with("res://") and not path.contains("::") \
			and (extension in MapFormat.MODEL_EXTENSIONS or extension in MapFormat.IMAGE_EXTENSIONS):
		var relative: String = MapFormat.FILES_DIR.path_join(path.trim_prefix("res://"))
		_files[relative] = path
		entry = {"file": relative}
	elif resource.get_script() == null and resource.get_class() in MapFormat.RESOURCES:
		entry = {"class": resource.get_class()}
	else:
		problems.append("%s: a %s (%s) can't be saved in a map." % [property_name, resource.get_class(), path if path != "" else "built in"])
		return -1
	var index: int = _resources.size()
	_resources.append(entry)
	_resource_ids[id] = index
	if entry.has("class"):
		var props: Dictionary = _changed_properties(resource, _template_for(entry["class"]))
		if not props.is_empty():
			entry["props"] = props
	return index
