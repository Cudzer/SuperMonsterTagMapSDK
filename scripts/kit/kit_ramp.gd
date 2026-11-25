@tool
class_name KitRamp
extends KitPiece
## A solid wedge that rises toward its forward axis (-Z): [member size] is width, rise and run.
## The top surface runs edge to edge, so it meets a platform of the same height flush. Keep
## slopes under the player's floor_max_angle (45 degrees) or it becomes a wall.

## Faces of wedge_points(). Corners: 0-3 the base (back-left, back-right, front-right,
## front-left; back is -Z), 4-5 the high edge over the back, 6-7 the low edge over the front.
const WEDGE_FACES: Array[Array] = [
	[0, 3, 2, 1], # bottom
	[0, 1, 5, 4], # back
	[3, 7, 6, 2], # front
	[4, 5, 6, 7], # slope
	[0, 4, 7, 3], # left
	[1, 2, 6, 5], # right
]

@export var size: Vector3 = Vector3(4, 3, 8):
	set(value):
		size = KitPiece.snap_vector(value)
		queue_build()


func _add_parts() -> void:
	var points: PackedVector3Array = wedge_points(size, 0.0)
	add_mesh(KitPiece.polyhedron(points, WEDGE_FACES), color)
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	add_shape(shape)


## The wedge's corners (see WEDGE_FACES), with the front edge at [param low_height].
static func wedge_points(box: Vector3, low_height: float) -> PackedVector3Array:
	var x: float = box.x / 2.0
	var z: float = box.z / 2.0
	return PackedVector3Array([
		Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z),
		Vector3(-x, box.y, -z), Vector3(x, box.y, -z), Vector3(x, low_height, z), Vector3(-x, low_height, z),
	])
