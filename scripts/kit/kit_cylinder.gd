@tool
class_name KitCylinder
extends KitPiece
## An upright cylinder: pillars and round platforms.

@export var radius: float = 1.0:
	set(value):
		radius = KitPiece.snap(value)
		queue_build()
@export var height: float = 6.0:
	set(value):
		height = KitPiece.snap(value)
		queue_build()
@export_range(6, 64) var sides: int = 24:
	set(value):
		sides = value
		queue_build()


func _add_parts() -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	var center: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, height / 2.0, 0))
	add_mesh(cylinder, color, center)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	add_shape(shape, center)
