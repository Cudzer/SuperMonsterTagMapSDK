@tool
extends EditorNode3DGizmoPlugin
## Makes kit pieces, level models, ziplines, grind rails and moving platforms clickable in the 3D view. Their meshes
## are generated internal children the edited scene doesn't own (so maps only store their exports),
## and the editor only selects nodes the edited scene owns, so clicking one would select nothing.
## This gizmo gives each collision triangles matching its meshes, so clicks and box selection pick
## it, and outlines it while selected (the editor's own selection box skips internal meshes).


func _init() -> void:
	create_material("outline", Palette.SUNBURST)


func _get_gizmo_name() -> String:
	return "Kit Piece"


func _has_gizmo(node: Node3D) -> bool:
	return node is KitPiece or node is LevelModel or node is Zipline or node is GrindRail or node is MovingPlatform or node is StringLights \
			or node is Carousel or node is FerrisWheel or node is WhackAMonster or node is Strongman


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var piece: Node3D = gizmo.get_node_3d()
	var faces: PackedVector3Array = PackedVector3Array()
	if piece.has_method(&"get_faces"):
		# Models (a LevelModel, or a moving platform carrying one) nest their meshes anywhere inside.
		faces = piece.call(&"get_faces")
	else:
		for part: Node in piece.get_children(true):
			var mesh_part: MeshInstance3D = part as MeshInstance3D
			if mesh_part != null and mesh_part.owner == null and mesh_part.mesh != null:
				faces.append_array(mesh_part.transform * mesh_part.mesh.get_faces())
	if faces.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var collision: ArrayMesh = ArrayMesh.new()
	collision.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	gizmo.add_collision_triangles(collision.generate_triangle_mesh())
	if EditorInterface.get_selection().get_selected_nodes().has(piece):
		gizmo.add_lines(_box_lines(collision.get_aabb().grow(0.02)), get_material("outline", gizmo))


## The twelve edges of [param box], as line pairs: every pair of AABB.get_endpoint() corners whose
## indices differ in one bit (one axis).
static func _box_lines(box: AABB) -> PackedVector3Array:
	var lines: PackedVector3Array = PackedVector3Array()
	for corner: int in 8:
		for axis_bit: int in [1, 2, 4]:
			if corner & axis_bit == 0:
				lines.append(box.get_endpoint(corner))
				lines.append(box.get_endpoint(corner | axis_bit))
	return lines
