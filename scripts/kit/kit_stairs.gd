@tool
class_name KitStairs
extends KitPiece
## Steps that climb toward the forward axis (-Z): [member size] is width, rise and run. Players
## can't step up boxes, so the collision is a smooth slope through the middle of the steps.

@export var size: Vector3 = Vector3(4, 3, 6):
	set(value):
		size = KitPiece.snap_vector(value)
		queue_build()
## Number of steps; 0 picks about one per 35 cm of rise.
@export_range(0, 40) var steps: int = 0:
	set(value):
		steps = value
		queue_build()


func _add_parts() -> void:
	var count: int = steps if steps > 0 else maxi(roundi(size.y / 0.35), 1)
	var step_rise: float = size.y / count
	var step_run: float = size.z / count
	for index: int in count:
		var step: BoxMesh = BoxMesh.new()
		var height: float = step_rise * (index + 1)
		step.size = Vector3(size.x, height, step_run)
		var z: float = size.z / 2.0 - step_run * (index + 0.5)
		add_mesh(step, color, Transform3D(Basis.IDENTITY, Vector3(0, height / 2.0, z)))
	# A slope from the bottom edge to the top edge. Raising it to the treads would leave a lip at
	# the bottom that players can't step over; this way feet dip at most a step into the stairs.
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = KitRamp.wedge_points(size, 0.0)
	add_shape(shape)
