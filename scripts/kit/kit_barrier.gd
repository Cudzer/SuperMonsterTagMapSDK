@tool
class_name KitBarrier
extends KitPiece
## An invisible wall that keeps players inside a map. It blocks player bodies only: it's on its own
## physics layer (BOUNDARY_LAYER), which players add to their collision mask, while wall-run rays,
## vault rays and slap hitboxes all mask layer 1. So nobody wall-runs, vaults or stands on it; they
## just can't get past. Nothing is drawn in game; in the editor it's a see-through coral box.
##
## Put it round a map's edge, tall enough that no jump, pad or vent clears it.

## Physics layer for map boundaries (1-based, like Player.TAGGER_BARRIER_LAYER's 5).
const BOUNDARY_LAYER: int = 6

## Width, height and depth (m); its origin is the middle of its base.
@export var size: Vector3 = Vector3(10, 40, 1):
	set(value):
		size = KitPiece.snap_vector(value)
		queue_build()

static var _editor_material: StandardMaterial3D


func _add_parts() -> void:
	collision_layer = 1 << (BOUNDARY_LAYER - 1)
	collision_mask = 0
	var center: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0, 0))
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	add_shape(shape, center)
	if Engine.is_editor_hint():
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		var mesh: MeshInstance3D = add_mesh(box, Swatch.CORAL, center, false)
		mesh.material_override = _see_through()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _see_through() -> StandardMaterial3D:
	if _editor_material == null:
		_editor_material = StandardMaterial3D.new()
		_editor_material.albedo_color = Color(Palette.CORAL, 0.18)
		_editor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_editor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_editor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _editor_material
