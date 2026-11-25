@tool
extends EditorNode3DGizmoPlugin
## A drag handle on the far end of ziplines, grind rails and moving platforms (their end_point):
## drag it onto a surface to move the far end there. Moving platforms also get a line along their
## path. One undo action per drag. Clicking them to select is the kit gizmo's job.

const LABEL: String = "Drag the far end"

var plugin: EditorPlugin
var _label: TextMesh


func _init(level_tools: EditorPlugin) -> void:
	plugin = level_tools
	create_handle_material("handle")
	create_material("label", Palette.SUNBURST, true)
	create_material("path", Palette.SUNBURST)
	_label = TextMesh.new()
	_label.text = LABEL
	_label.font_size = 40
	_label.pixel_size = 0.01
	_label.depth = 0.0


func _get_gizmo_name() -> String:
	return "Zipline, Rail And Platform Ends"


func _has_gizmo(node: Node3D) -> bool:
	return node is Zipline or node is GrindRail or node is MovingPlatform or node is StringLights


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node: Node3D = gizmo.get_node_3d()
	if not EditorInterface.get_selection().get_selected_nodes().has(node):
		return
	# Spinning platforms have no far end.
	if node is MovingPlatform and node.get(&"motion") != MovingPlatform.Motion.MOVE:
		return
	var end: Vector3 = node.get(&"end_point")
	if node is MovingPlatform:
		gizmo.add_lines(PackedVector3Array([Vector3.ZERO, end]), get_material("path", gizmo))
	gizmo.add_handles(PackedVector3Array([end]), get_material("handle", gizmo), PackedInt32Array([0]))
	gizmo.add_mesh(_label, get_material("label", gizmo), Transform3D(Basis.IDENTITY, end + Vector3.UP * 0.8))


func _get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Far end"


func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	return gizmo.get_node_3d().get(&"end_point")


## Moves the far end onto the surface under the mouse.
func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node: Node3D = gizmo.get_node_3d()
	var hit: Dictionary = plugin.call(&"surface_hit", camera.project_ray_origin(screen_pos),
			camera.project_ray_normal(screen_pos), 4000.0, node, false)
	if not hit.is_empty():
		node.set(&"end_point", node.to_local(hit["position"]))


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node: Node3D = gizmo.get_node_3d()
	if cancel:
		node.set(&"end_point", restore)
		return
	var undo: EditorUndoRedoManager = plugin.get_undo_redo()
	undo.create_action("Move %s End" % ("Zipline" if node is Zipline else "Rail" if node is GrindRail else "Lights" if node is StringLights else "Platform"))
	undo.add_do_property(node, &"end_point", _get_handle_value(gizmo, handle_id, secondary))
	undo.add_undo_property(node, &"end_point", restore)
	# Already applied while dragging.
	undo.commit_action(false)
