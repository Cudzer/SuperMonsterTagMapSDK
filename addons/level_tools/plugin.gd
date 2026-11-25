@tool
extends EditorPlugin
## Level Tools: building maps (see GameMap and res://maps). Arm a kit piece or gameplay item in
## the dock, and a see-through preview follows the mouse in the 3D view; click to drop it onto
## the surface under the mouse, with undo. Pieces and pads go under Geometry, spots into their
## marker group (both created if missing). Also draws marker visuals (map_gizmos.gd) and spring
## pad arcs with a landing handle for aiming (pad_gizmos.gd), validates maps (validator.gd, also
## on every save), creates maps and captures picker thumbnails.

const Dock := preload("dock.gd")
const MapGizmos := preload("map_gizmos.gd")
const Catalog := preload("catalog.gd")
const MapFiles := preload("map_files.gd")
const PadGizmos := preload("pad_gizmos.gd")
const SpanGizmos := preload("span_gizmos.gd")
const Validator := preload("validator.gd")
const KitGizmos := preload("kit_gizmos.gd")
const PackageTools := preload("package_tools.gd")

## How see-through the placement preview is.
const GHOST_TRANSPARENCY: float = 0.55
## Rays that hit nothing land on a level plane at the last placement's height.
const RAY_LENGTH: float = 4000.0
## Drop to ground looks for the surface starting this far above a node, so a node sunk into the
## ground a little finds its top rather than the ground's underside.
const DROP_START_HEIGHT: float = 0.5
## Thumbnail cameras see layers 1-20 only, so editor gizmos and the grid stay out.
const SCENE_LAYERS: int = 0xFFFFF

var dock: Dock
var _gizmos: MapGizmos
var _pad_gizmos: PadGizmos
var _span_gizmos: SpanGizmos
var _validator: Validator
var _kit_gizmos: KitGizmos
var _armed: Dictionary = {}
var _ghost: Node3D
## Extra yaw from the R key, in radians.
var _turn: float = 0.0
## Extra height from Q/E while placing, in meters (dock.height_step() a press).
var _height_offset: float = 0.0
var _last_height: float = 0.0
var _last_camera: Camera3D
var _last_mouse: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	dock = Dock.new()
	dock.plugin = self
	dock.armed_changed.connect(_on_armed_changed)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	_gizmos = MapGizmos.new()
	add_node_3d_gizmo_plugin(_gizmos)
	_pad_gizmos = PadGizmos.new(self)
	add_node_3d_gizmo_plugin(_pad_gizmos)
	_span_gizmos = SpanGizmos.new(self)
	add_node_3d_gizmo_plugin(_span_gizmos)
	_validator = Validator.new(self, _pad_gizmos)
	_kit_gizmos = KitGizmos.new()
	add_node_3d_gizmo_plugin(_kit_gizmos)
	set_input_event_forwarding_always_enabled()
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	_on_scene_changed(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	_clear_ghost()
	remove_node_3d_gizmo_plugin(_gizmos)
	remove_node_3d_gizmo_plugin(_pad_gizmos)
	remove_node_3d_gizmo_plugin(_span_gizmos)
	remove_node_3d_gizmo_plugin(_kit_gizmos)
	remove_control_from_docks(dock)
	dock.queue_free()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _scene_root() == null:
		return AFTER_GUI_INPUT_PASS
	if _armed.is_empty():
		return _selection_key(event)
	if event is InputEventMouseMotion:
		_last_camera = camera
		_last_mouse = (event as InputEventMouseMotion).position
		_update_ghost()
		return AFTER_GUI_INPUT_PASS
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var hit: Dictionary = surface_hit(camera.project_ray_origin(button.position), camera.project_ray_normal(button.position))
		if not hit.is_empty():
			place(_armed, placement_transform(camera, hit["position"]))
		return AFTER_GUI_INPUT_STOP
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		# Q/E repeat while held; the rest act once per press.
		if key.keycode == KEY_Q or key.keycode == KEY_E:
			_height_offset += dock.height_step() * (1.0 if key.keycode == KEY_E else -1.0)
			dock.show_hint(true, _height_offset)
			_update_ghost()
			return AFTER_GUI_INPUT_STOP
		if key.echo:
			return AFTER_GUI_INPUT_PASS
		if key.keycode == KEY_ESCAPE:
			dock.disarm()
			return AFTER_GUI_INPUT_STOP
		if key.keycode == KEY_R:
			_turn += -PI / 4.0 if key.shift_pressed else PI / 4.0
			_update_ghost()
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


## With nothing armed: Page Up / Page Down nudge the selection a height step, End drops it to
## the ground. Plain keys only, so the editor's own modified shortcuts still work.
func _selection_key(event: InputEvent) -> int:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed:
		return AFTER_GUI_INPUT_PASS
	if key.keycode not in [KEY_PAGEUP, KEY_PAGEDOWN, KEY_END] or _selected_nodes().is_empty():
		return AFTER_GUI_INPUT_PASS
	if key.keycode == KEY_END:
		if not key.echo:
			drop_selection()
	else:
		nudge_selection(1 if key.keycode == KEY_PAGEUP else -1)
	return AFTER_GUI_INPUT_STOP


## Moves the selected nodes up (1) or down (-1) one height step. Repeated nudges merge into one
## undo action, so holding the key undoes in one go.
func nudge_selection(direction: int) -> void:
	var nodes: Array[Node3D] = _selected_nodes()
	if nodes.is_empty():
		return
	var offset: Vector3 = Vector3.UP * dock.height_step() * signf(direction)
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Raise Selection" if direction > 0 else "Lower Selection", UndoRedo.MERGE_ENDS, _scene_root())
	for node: Node3D in nodes:
		undo.add_do_property(node, &"global_position", node.global_position + offset)
		undo.add_undo_property(node, &"global_position", node.global_position)
	undo.commit_action()


## Drops each selected node straight down onto the first surface under it (its own meshes
## ignored), as one undo action. Starts the ray a little above the node, so a node sunk slightly
## into the ground comes up to its surface instead of falling through.
func drop_selection() -> void:
	var nodes: Array[Node3D] = _selected_nodes()
	if nodes.is_empty():
		return
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Drop Selection to Ground", UndoRedo.MERGE_DISABLE, _scene_root())
	for node: Node3D in nodes:
		var at: Vector3 = node.global_position
		var hit: Dictionary = surface_hit(at + Vector3.UP * DROP_START_HEIGHT, Vector3.DOWN, RAY_LENGTH, node, false)
		if hit.is_empty():
			continue
		undo.add_do_property(node, &"global_position", Vector3(at.x, (hit["position"] as Vector3).y, at.z))
		undo.add_undo_property(node, &"global_position", at)
	undo.commit_action()


## The selected 3D nodes in the edited scene (not its root), leaving out any whose ancestor is
## also selected so nothing moves twice. Filters get_selected_nodes() itself: the editor's
## get_top_selected_nodes() lags behind a selection made the same frame.
func _selected_nodes() -> Array[Node3D]:
	var root: Node3D = _scene_root()
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var nodes: Array[Node3D] = []
	for node: Node in selected:
		if not node is Node3D or node == root or root == null or not root.is_ancestor_of(node):
			continue
		if not selected.any(func(other: Node) -> bool: return other != node and other.is_ancestor_of(node)):
			nodes.append(node as Node3D)
	return nodes


## The first visible surface of the edited scene within [param max_distance] along the ray:
## {"position", "normal", "node", "distance"}, ignoring [param exclude] and its children.
## Without one, the point on the level plane at the last placement height ("node" null) if
## [param plane_fallback], else {}. Tests the meshes' triangles rather than physics: the editor
## never steps physics, so ray queries miss bodies whose shapes changed since the scene loaded
## (every new kit piece). [param direction] must be normalized.
func surface_hit(from: Vector3, direction: Vector3, max_distance: float = RAY_LENGTH, exclude: Node = null,
		plane_fallback: bool = true) -> Dictionary:
	var root: Node3D = _scene_root()
	if root == null:
		return {}
	var best: Dictionary = {}
	var best_distance: float = max_distance
	var to: Vector3 = from + direction * max_distance
	for id: int in RenderingServer.instances_cull_ray(from, to, root.get_world_3d().scenario):
		var geometry: GeometryInstance3D = instance_from_id(id) as GeometryInstance3D
		if geometry == null or not root.is_ancestor_of(geometry) or not geometry.is_visible_in_tree():
			continue
		if _ghost != null and is_instance_valid(_ghost) and (_ghost == geometry or _ghost.is_ancestor_of(geometry)):
			continue
		if exclude != null and (exclude == geometry or exclude.is_ancestor_of(geometry)):
			continue
		if _is_never_a_surface(geometry):
			continue
		var to_local: Transform3D = geometry.global_transform.affine_inverse()
		var local_from: Vector3 = to_local * from
		var local_direction: Vector3 = to_local.basis * direction
		var faces: PackedVector3Array = _faces_of(geometry)
		for index: int in range(0, faces.size() - 2, 3):
			var point: Variant = Geometry3D.ray_intersects_triangle(local_from, local_direction, faces[index], faces[index + 1], faces[index + 2])
			if point == null:
				continue
			var at: Vector3 = geometry.global_transform * (point as Vector3)
			var distance: float = from.distance_to(at)
			if distance < best_distance:
				var normal: Vector3 = (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index])
				normal = (geometry.global_basis * normal).normalized()
				best = {"position": at, "normal": normal if normal.dot(direction) < 0.0 else -normal,
						"node": geometry, "distance": distance}
				best_distance = distance
	if not best.is_empty() or not plane_fallback:
		return best
	var plane_point: Variant = Plane(Vector3.UP, _last_height).intersects_ray(from, direction)
	if plane_point == null:
		return {}
	return {"position": plane_point, "normal": Vector3.UP, "node": null, "distance": from.distance_to(plane_point)}


## Where an item dropped at [param at] goes: snapped to the dock's grid horizontally, raised by
## its "lift" and the Q/E height offset, and turned to face away from the camera in 90 degree
## steps (plus R turns).
func placement_transform(camera: Camera3D, at: Vector3) -> Transform3D:
	var grid: float = dock.grid_size()
	if grid > 0.0:
		at.x = snappedf(at.x, grid)
		at.z = snappedf(at.z, grid)
	at.y += _armed.get("lift", 0.0) + _height_offset
	var forward: Vector3 = -camera.global_basis.z
	var yaw: float = snappedf(atan2(-forward.x, -forward.z), PI / 2.0) + _turn
	return Transform3D(Basis(Vector3.UP, yaw), at)


## Adds [param item] to the edited scene at [param at] (global) as one undoable action, and
## selects it. The player spawn is moved rather than duplicated.
func place(item: Dictionary, at: Transform3D) -> Node3D:
	var root: Node3D = _scene_root()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Place %s" % item["name"], UndoRedo.MERGE_DISABLE, root)
	var node: Node3D
	if item["kind"] == Catalog.Kind.PLAYER_SPAWN and root.get_node_or_null(^"PlayerSpawn") is Node3D:
		node = root.get_node(^"PlayerSpawn")
		undo.add_do_property(node, &"global_transform", at)
		undo.add_undo_property(node, &"global_transform", node.global_transform)
	else:
		var parent: Node3D = _parent_for(item, root, undo)
		var parent_transform: Transform3D = parent.global_transform if parent.is_inside_tree() else root.global_transform
		node = _make_node(item)
		node.transform = parent_transform.affine_inverse() * at
		undo.add_do_method(parent, &"add_child", node, true)
		undo.add_do_method(node, &"set_owner", root)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, &"remove_child", node)
	undo.commit_action()
	_last_height = at.origin.y - item.get("lift", 0.0) - _height_offset
	if node is Teleporter:
		_pair_teleporter(node, root)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	return node


## A teleporter just placed pairs with one still waiting for its other end, as its own undo step.
func _pair_teleporter(placed: Node3D, root: Node3D) -> void:
	for node: Node in root.find_children("*", "Area3D", true, false):
		if node is Teleporter and node != placed and Validator.partner_of(node as Node3D, root) == null:
			var undo: EditorUndoRedoManager = get_undo_redo()
			undo.create_action("Pair Teleporters", UndoRedo.MERGE_DISABLE, root)
			undo.add_do_property(placed, &"partner", placed.get_path_to(node))
			undo.add_undo_property(placed, &"partner", NodePath())
			undo.commit_action()
			return


## Checks the open map and lists the problems in the dock's Map tab. Returns them too.
func validate_map() -> Array[Dictionary]:
	var issues: Array[Dictionary] = _validator.validate(_scene_root())
	dock.show_issues(issues)
	return issues


## The Map tab's Export Package. Lists what the package left out against the nodes it's about.
## Returns the package's folder, or "" if nothing was written.
func export_package() -> String:
	var root: Node3D = _scene_root()
	var result: Dictionary = PackageTools.export_map(root)
	var issues: Array[Dictionary] = []
	for problem: String in result["problems"]:
		var colon: int = problem.find(": ")
		var node: Node = root.get_node_or_null(NodePath(problem.left(colon))) if root != null and colon > 0 else null
		issues.append({"severity": 1, "message": problem, "node": node})
	# A clean export leaves the validator's results in place.
	if not issues.is_empty():
		dock.show_issues(issues)
	dock.show_map_message(result["message"])
	return result["folder"]


## The Map tab's Playtest: exports, then starts the game on the package.
func playtest_package(mode_id: int, bots: int) -> void:
	var folder: String = export_package()
	if folder != "":
		dock.show_map_message(PackageTools.playtest(folder, mode_id, bots))


## Revalidates a saved map, so the Map tab's problem count stays current.
func _on_scene_saved(path: String) -> void:
	var root: Node3D = _scene_root()
	if root != null and root.scene_file_path == path and root.get_script() == MapFiles.GAME_MAP_SCRIPT:
		validate_map()


## Renders the current 3D editor view into maps/<id>/thumbnail.png and sets it on the map's
## MapInfo. Reports to the dock.
func capture_thumbnail() -> void:
	var root: Node3D = _scene_root()
	if root == null or root.get_script() != MapFiles.GAME_MAP_SCRIPT:
		dock.show_map_message("Open a map scene first.")
		return
	if root.scene_file_path == "":
		dock.show_map_message("Save the map first.")
		return
	var info: Resource = MapFiles.find_info(root.scene_file_path)
	if info == null:
		dock.show_map_message("No MapInfo under res://maps points at this scene.")
		return
	_clear_ghost()
	# The editor only redraws when something changes; the capture needs a few frames drawn.
	var low_processor: bool = OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	var editor_viewport: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	var editor_camera: Camera3D = editor_viewport.get_camera_3d()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = MapFiles.THUMBNAIL_SIZE
	viewport.world_3d = editor_viewport.find_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera: Camera3D = Camera3D.new()
	camera.fov = editor_camera.fov
	camera.near = editor_camera.near
	camera.far = editor_camera.far
	camera.cull_mask = SCENE_LAYERS
	viewport.add_child(camera)
	EditorInterface.get_base_control().add_child(viewport)
	camera.global_transform = editor_camera.global_transform
	camera.current = true
	for frame: int in 3:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	OS.low_processor_usage_mode = low_processor

	var path: String = root.scene_file_path.get_base_dir().path_join("thumbnail.png")
	var error: Error = image.save_png(path)
	if error != OK:
		dock.show_map_message("Couldn't save %s (%s)." % [path, error_string(error)])
		return
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.update_file(path)
	file_system.reimport_files(PackedStringArray([path]))
	info.set(&"thumbnail", ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE))
	error = ResourceSaver.save(info)
	dock.show_map_message("Thumbnail saved to %s." % path if error == OK else "Couldn't save the MapInfo (%s)." % error_string(error))


## Whether [param node] is never a surface to place on or measure from: part of an island's
## decoration (grass, mushrooms, waterfalls, the propeller), or a barrier (invisible in game).
static func _is_never_a_surface(node: Node) -> bool:
	var at: Node = node.get_parent()
	# Barriers are invisible in game: never a surface either.
	if at is KitBarrier:
		return true
	while at != null and not at is KitPiece:
		if at is IslandDecor or at is IslandPropeller:
			return true
		at = at.get_parent()
	return false


## The triangles of a mesh or CSG shape, in its local space. CSG children are merged into their
## root shape, which is the only one with a mesh.
func _faces_of(geometry: GeometryInstance3D) -> PackedVector3Array:
	var mesh: Mesh
	var offset: Transform3D = Transform3D.IDENTITY
	if geometry is MeshInstance3D:
		mesh = (geometry as MeshInstance3D).mesh
	elif geometry is CSGShape3D and (geometry as CSGShape3D).is_root_shape():
		var meshes: Array = (geometry as CSGShape3D).get_meshes()
		if meshes.size() >= 2:
			offset = meshes[0]
			mesh = meshes[1]
	if mesh == null:
		return PackedVector3Array()
	var faces: PackedVector3Array = mesh.get_faces()
	if offset != Transform3D.IDENTITY:
		faces = offset * faces
	return faces


func _on_armed_changed(item: Dictionary) -> void:
	_armed = item
	_turn = 0.0
	_height_offset = 0.0
	dock.show_hint(not item.is_empty(), 0.0)
	_clear_ghost()
	_update_ghost()


func _on_scene_changed(root: Node) -> void:
	_clear_ghost()
	if not _armed.is_empty():
		dock.disarm()
	dock.set_scene_root(root)


func _scene_root() -> Node3D:
	return EditorInterface.get_edited_scene_root() as Node3D


## The node [param item] goes under: Geometry, or its marker group, or the root for the player
## spawn. A missing one is created as part of the undo action.
func _parent_for(item: Dictionary, root: Node3D, undo: EditorUndoRedoManager) -> Node3D:
	if item["kind"] == Catalog.Kind.PLAYER_SPAWN:
		return root
	var parent_name: StringName = item.get("group", &"Geometry")
	var parent: Node3D = root.get_node_or_null(NodePath(parent_name)) as Node3D
	if parent != null:
		return parent
	parent = Node3D.new()
	parent.name = parent_name
	undo.add_do_method(root, &"add_child", parent, true)
	undo.add_do_method(parent, &"set_owner", root)
	undo.add_do_reference(parent)
	undo.add_undo_method(root, &"remove_child", parent)
	return parent


func _make_node(item: Dictionary) -> Node3D:
	var node: Node3D
	match item["kind"]:
		Catalog.Kind.PIECE:
			node = (item["script"] as Script).new()
			var props: Dictionary = item["props"]
			for property: StringName in props:
				node.set(property, props[property])
			if dock.piece_color() >= 0:
				node.set(&"color", dock.piece_color())
		Catalog.Kind.SCENE:
			node = (load(item["scene"]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			var scene_props: Dictionary = item.get("props", {})
			for property: StringName in scene_props:
				node.set(property, scene_props[property])
		Catalog.Kind.MODEL:
			node = LevelModel.new()
			node.set(&"model", load(item["model"]))
			var model_props: Dictionary = item.get("props", {})
			for property: StringName in model_props:
				node.set(property, model_props[property])
		Catalog.Kind.PLAYER_SPAWN:
			node = Marker3D.new()
			node.name = "PlayerSpawn"
			return node
		_:
			node = Marker3D.new()
	node.name = String(item["name"]).to_pascal_case()
	return node


## The see-through preview under the mouse. Markers preview as a ring in their gizmo color.
func _update_ghost() -> void:
	var root: Node3D = _scene_root()
	if _armed.is_empty() or root == null or _last_camera == null:
		return
	if _ghost == null or not is_instance_valid(_ghost) or not root.is_ancestor_of(_ghost):
		_clear_ghost()
		_ghost = _make_ghost(_armed)
		# Unowned, so it isn't saved or shown in the Scene dock.
		root.add_child(_ghost)
		_make_see_through(_ghost)
	var hit: Dictionary = surface_hit(_last_camera.project_ray_origin(_last_mouse), _last_camera.project_ray_normal(_last_mouse))
	_ghost.visible = not hit.is_empty()
	if not hit.is_empty():
		_ghost.global_transform = placement_transform(_last_camera, hit["position"])
	_update_ghost_stem()


## A thin post from the preview down (or up) to the surface it was dropped on, while Q/E have
## moved it off that surface, so the height reads at a glance.
func _update_ghost_stem() -> void:
	var stem: MeshInstance3D = _ghost.get_node_or_null(^"HeightStem") as MeshInstance3D
	if is_zero_approx(_height_offset):
		if stem != null:
			stem.visible = false
		return
	if stem == null:
		stem = MeshInstance3D.new()
		stem.name = "HeightStem"
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Palette.SUNBURST
		var post: CylinderMesh = CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.05
		post.height = 1.0
		post.material = material
		stem.mesh = post
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(stem)
	stem.visible = true
	# The ghost only ever turns around Y, so local down is world down.
	stem.position = Vector3.DOWN * _height_offset / 2.0
	stem.scale = Vector3(1.0, absf(_height_offset), 1.0)


func _make_ghost(item: Dictionary) -> Node3D:
	if item["kind"] != Catalog.Kind.MARKER and item["kind"] != Catalog.Kind.PLAYER_SPAWN:
		return _make_node(item)
	var kind: StringName = &"PlayerSpawn" if item["kind"] == Catalog.Kind.PLAYER_SPAWN else StringName(item["group"])
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MapGizmos.color_of(kind)
	ring.material = material
	var ghost: MeshInstance3D = MeshInstance3D.new()
	ghost.mesh = ring
	var radius: float = MapGizmos.KINDS[kind]["radius"]
	ghost.scale = Vector3(radius, 1.0, radius)
	var holder: Node3D = Node3D.new()
	holder.add_child(ghost)
	return holder


## Makes every mesh under [param node] see-through and every body ignore rays (so the preview
## can't hit itself). Includes kit pieces' internal parts.
func _make_see_through(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = GHOST_TRANSPARENCY
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
	for child: Node in node.get_children(true):
		_make_see_through(child)


func _clear_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
