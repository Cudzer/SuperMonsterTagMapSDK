@tool
extends EditorNode3DGizmoPlugin
## Spring pad aiming in the 3D view: the flight arc of a player launched from the pad (sunburst,
## coral when it hits something before landing where it should), a ring where it lands, and a
## handle on the landing point. Dragging the handle aims the pad there (SpringPad.aimed), starting
## from the pad's current tilt as its launch angle; each drag is one undo action. A pad whose arc
## comes back down on itself (an untilted one) gets its handle a few meters in front instead, where
## it isn't hidden under the pad, and a selected pad labels its handle.

## A hit this close to the aim target counts as landing on it.
const LANDING_TOLERANCE: float = 1.5
## Hits on surfaces steeper than this (walls, undersides) block the arc rather than land it.
const MIN_FLOOR_NORMAL_Y: float = 0.7
## The player's collision capsule (player.tscn), swept along the arc.
const PLAYER_RADIUS: float = 0.4
const PLAYER_HEIGHT: float = 1.8
const RING_RADIUS: float = 1.2
const RING_SEGMENTS: int = 32
## An arc landing closer than this (horizontally) to its own pad puts the handle AIM_START_DISTANCE
## in front of the pad instead.
const SELF_LANDING_DISTANCE: float = 2.5
const AIM_START_DISTANCE: float = 5.0
## Starting launch angle when aiming a pad that's (nearly) flat, since its tilt says nothing.
const FLAT_PAD_ANGLE: float = 55.0
## The properties a drag changes, restored together on undo or cancel.
const AIM_PROPERTIES: Array[StringName] = [&"aimed", &"aim_target", &"launch_angle", &"transform", &"launch_speed", &"keep_momentum"]

## The Level Tools plugin, for surface_hit() and undo.
var plugin: EditorPlugin

var _labels: Dictionary[String, TextMesh] = {}


func _init(level_tools: EditorPlugin) -> void:
	plugin = level_tools
	create_material("arc", Palette.SUNBURST)
	create_material("blocked", Palette.CORAL)
	create_material("target", Palette.MINT)
	create_handle_material("handle")
	create_material("label", Palette.SUNBURST, true)
	for text: String in ["Drag to aim", "Landing"]:
		var label: TextMesh = TextMesh.new()
		label.text = text
		label.font_size = 40
		label.pixel_size = 0.01
		label.depth = 0.0
		_labels[text] = label


func _get_gizmo_name() -> String:
	return "Spring Pad Aim"


func _has_gizmo(node: Node3D) -> bool:
	return node is SpringPad


## Follows the pad's flight until the player's body first meets a surface: {"points" (the feet's
## path, global), "landing" (Vector3, or null if it falls into the void), "blocker" (the node it
## wrongly hit, or null), "ok"}. Not ok when the body hits a wall or ceiling on the way, an aimed
## pad misses its target or can't reach it, or players fall into the void.
func trace(pad: SpringPad) -> Dictionary:
	var path: PackedVector3Array = pad.flight_path()
	var points: PackedVector3Array = PackedVector3Array([path[0]])
	var result: Dictionary = {"points": points, "landing": null, "blocker": null, "ok": false}
	var body_offsets: Array[Vector3] = _body_offsets(pad)
	for index: int in range(1, path.size()):
		var from: Vector3 = path[index - 1]
		var segment: Vector3 = path[index] - from
		var length: float = segment.length()
		var direction: Vector3 = segment / length
		var feet: Dictionary = plugin.call(&"surface_hit", from, direction, length, pad, false)
		# The launch starts on the surface the pad sits on; ignore that touch.
		if not feet.is_empty() and not (index == 1 and feet["distance"] < 0.05):
			points.append(feet["position"])
			return _finish(result, pad, feet, feet["position"])
		for offset: Vector3 in body_offsets:
			var body: Dictionary = plugin.call(&"surface_hit", from + offset, direction, length, pad, false)
			if body.is_empty() or (index == 1 and body["distance"] < 0.05):
				continue
			# A side of the body touching floor is the player landing there.
			var landing: Vector3 = from + direction * float(body["distance"])
			points.append(landing)
			return _finish(result, pad, body, landing)
		points.append(path[index])
	return result


## Fills in a trace's result for the first surface the body met.
func _finish(result: Dictionary, pad: SpringPad, hit: Dictionary, landing: Vector3) -> Dictionary:
	result["landing"] = landing
	var floor_hit: bool = (hit["normal"] as Vector3).y >= MIN_FLOOR_NORMAL_Y
	var on_target: bool = not pad.aimed or landing.distance_to(pad.get_target_global()) <= LANDING_TOLERANCE
	result["ok"] = floor_hit and on_target and pad.can_reach_target()
	if not result["ok"]:
		result["blocker"] = hit["node"]
	return result


## Rays besides the feet that stand in for the player's capsule (radius PLAYER_RADIUS, PLAYER_HEIGHT
## tall, standing on its feet): the head, and both sides at knee and chest height.
func _body_offsets(pad: SpringPad) -> Array[Vector3]:
	var launch: Vector3 = pad.global_basis.y
	var side: Vector3 = Vector3(launch.z, 0.0, -launch.x)
	side = side.normalized() if side.length() > 0.01 else pad.global_basis.x.normalized()
	return [
		Vector3.UP * (PLAYER_HEIGHT - 0.05),
		Vector3.UP * 0.3 + side * PLAYER_RADIUS, Vector3.UP * 0.3 - side * PLAYER_RADIUS,
		Vector3.UP * (PLAYER_HEIGHT * 0.5) + side * PLAYER_RADIUS, Vector3.UP * (PLAYER_HEIGHT * 0.5) - side * PLAYER_RADIUS,
	]


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var pad: SpringPad = gizmo.get_node_3d() as SpringPad
	if pad == null or not pad.is_inside_tree():
		return
	var traced: Dictionary = trace(pad)
	var to_local: Transform3D = pad.global_transform.affine_inverse()
	var points: PackedVector3Array = traced["points"]
	var lines: PackedVector3Array = PackedVector3Array()
	for index: int in points.size() - 1:
		lines.append(to_local * points[index])
		lines.append(to_local * points[index + 1])
	var landing: Variant = traced["landing"]
	if landing != null:
		lines.append_array(_ring(to_local, landing))
	gizmo.add_lines(lines, get_material("arc" if traced["ok"] else "blocked", gizmo))

	var handle: Vector3 = points[points.size() - 1]
	if pad.aimed:
		handle = pad.get_target_global()
		gizmo.add_lines(_ring(to_local, handle), get_material("target", gizmo))
	elif landing != null:
		handle = landing
	var flat_offset: Vector3 = handle - pad.global_position
	if not pad.aimed and Vector2(flat_offset.x, flat_offset.z).length() < SELF_LANDING_DISTANCE:
		# The arc comes back down on the pad, where the handle would hide under it.
		handle = _aim_start(pad)
		gizmo.add_lines(_ring(to_local, handle), get_material("target", gizmo))
	gizmo.add_handles(PackedVector3Array([to_local * handle]), get_material("handle", gizmo), PackedInt32Array([0]))
	if EditorInterface.get_selection().get_selected_nodes().has(pad):
		gizmo.add_mesh(_labels["Landing" if pad.aimed else "Drag to aim"], get_material("label", gizmo),
				Transform3D(Basis.IDENTITY, to_local * (handle + Vector3.UP * 0.8)))


func _get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Landing"


func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var pad: Node3D = gizmo.get_node_3d()
	var values: Dictionary = {}
	for property: StringName in AIM_PROPERTIES:
		values[property] = pad.get(property)
	return values


## Aims the pad at the surface under the mouse. A pad being aimed for the first time keeps its
## current tilt as the launch angle.
func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var pad: SpringPad = gizmo.get_node_3d() as SpringPad
	var hit: Dictionary = plugin.call(&"surface_hit", camera.project_ray_origin(screen_pos),
			camera.project_ray_normal(screen_pos), 4000.0, pad, false)
	if hit.is_empty():
		return
	if not pad.aimed:
		var elevation: float = rad_to_deg(asin(clampf(pad.global_basis.y.normalized().y, -1.0, 1.0)))
		pad.launch_angle = FLAT_PAD_ANGLE if elevation > 80.0 else clampf(elevation, 15.0, 85.0)
	var parent: Node3D = pad.get_parent() as Node3D
	pad.aim_target = parent.to_local(hit["position"]) if parent != null else hit["position"]
	pad.aimed = true


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var pad: Node3D = gizmo.get_node_3d()
	var before: Dictionary = restore
	if cancel:
		for property: StringName in AIM_PROPERTIES:
			pad.set(property, before[property])
		return
	var after: Dictionary = _get_handle_value(gizmo, handle_id, secondary)
	var undo: EditorUndoRedoManager = plugin.get_undo_redo()
	undo.create_action("Aim Spring Pad")
	for property: StringName in AIM_PROPERTIES:
		undo.add_do_property(pad, property, after[property])
		undo.add_undo_property(pad, property, before[property])
	# Already applied while dragging.
	undo.commit_action(false)


## Where an unaimed pad's handle starts when its arc lands back on itself: AIM_START_DISTANCE
## ahead of the pad (the way it leans, or its forward axis if it's flat), on the surface there.
func _aim_start(pad: SpringPad) -> Vector3:
	var heading: Vector3 = Vector3(pad.global_basis.y.x, 0.0, pad.global_basis.y.z)
	if heading.length() < 0.1:
		heading = Vector3(-pad.global_basis.z.x, 0.0, -pad.global_basis.z.z)
	if heading.length() < 0.1:
		heading = Vector3.FORWARD
	var point: Vector3 = pad.global_position + heading.normalized() * AIM_START_DISTANCE
	var ground: Dictionary = plugin.call(&"surface_hit", point + Vector3.UP * 3.0, Vector3.DOWN, 20.0, pad, false)
	return ground["position"] if not ground.is_empty() else point


## A flat ring of RING_RADIUS around [param center] (global), as line pairs in the gizmo's space.
func _ring(to_local: Transform3D, center: Vector3) -> PackedVector3Array:
	var lines: PackedVector3Array = PackedVector3Array()
	for index: int in RING_SEGMENTS:
		var from: float = TAU * index / RING_SEGMENTS
		var to: float = TAU * (index + 1) / RING_SEGMENTS
		lines.append(to_local * (center + Vector3(cos(from), 0.05, sin(from)) * RING_RADIUS))
		lines.append(to_local * (center + Vector3(cos(to), 0.05, sin(to)) * RING_RADIUS))
	return lines
