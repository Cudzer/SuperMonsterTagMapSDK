@tool
class_name SwingBar
extends Area3D
## A horizontal bar players swing around. The bar runs along local X, so only rotate the node
## around Y. Players grab it automatically when their hands touch it in the air (physics layer 4,
## "swing_bars"). Leave about 2 m of clearance all around it for the swing circle.

@export var length: float = 3.0:
	set(value):
		length = maxf(value, 0.1)
		_resize()

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_resize()


func get_axis() -> Vector3:
	return global_transform.basis.x.normalized()


## The point on the bar nearest to [param point], clamped to the bar's ends.
func closest_point(point: Vector3) -> Vector3:
	var axis: Vector3 = get_axis()
	var along: float = clampf((point - global_position).dot(axis), -length * 0.5, length * 0.5)
	return global_position + axis * along


func _resize() -> void:
	# The setter also runs while the scene loads, before the child nodes are ready.
	if not is_node_ready():
		return
	# Both resources are local to scene, so each bar resizes only its own copies.
	(collision_shape.shape as CylinderShape3D).height = length
	(mesh_instance.mesh as CylinderMesh).height = length
