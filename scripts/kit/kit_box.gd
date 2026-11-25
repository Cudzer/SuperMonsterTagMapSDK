@tool
class_name KitBox
extends KitPiece
## A box: platforms, bridges, wall-run walls and cover blocks.

@export var size: Vector3 = Vector3(4, 1, 4):
	set(value):
		size = KitPiece.snap_vector(value)
		queue_build()


func _add_parts() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var center: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0, 0))
	add_mesh(box, color, center)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	add_shape(shape, center)
