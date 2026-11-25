@tool
class_name Zipline
extends Area3D
## A cable between two posts that players grab from the air and ride, faster downhill. Like swing
## bars, it sits on physics layer 4 ("swing_bars") so the player's BarDetector finds it, and needs
## no networking: each player rides on their own machine (Player.start_zipline()).
##
## The origin is the base of the first post; end_point is the base of the other (in this node's
## space, so it turns with the node). The cable runs between the post tops, cable_height up. Level
## Tools gives the far post a drag handle. The posts and cable are built as internal parts, so
## scenes only store the exports.

## The far post's base, in this node's space.
@export var end_point: Vector3 = Vector3(0, -2, -14):
	set(value):
		end_point = value
		queue_build()
## How high the cable hangs above each post's base.
@export var cable_height: float = 4.0:
	set(value):
		cable_height = maxf(value, 2.5)
		queue_build()

const CABLE_RADIUS: float = 0.04
const POST_RADIUS: float = 0.15
## How close to the cable a hand has to come to grab it.
const GRAB_RADIUS: float = 0.6

## One shared material per color, so every zipline and rail batches together.
static var _materials: Dictionary[Color, StandardMaterial3D] = {}

var _parts: Array[Node] = []
var _build_queued: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	build()


func queue_build() -> void:
	if is_inside_tree() and not _build_queued:
		_build_queued = true
		build.call_deferred()


## The cable's ends, global.
func get_start() -> Vector3:
	return global_transform * (Vector3.UP * cable_height)


func get_end() -> Vector3:
	return global_transform * (end_point + Vector3.UP * cable_height)


## How far along the cable (0 to 1) the point nearest [param point] is.
func closest_fraction(point: Vector3) -> float:
	var along: Vector3 = get_end() - get_start()
	return clampf((point - get_start()).dot(along) / along.length_squared(), 0.0, 1.0)


func build() -> void:
	_build_queued = false
	for part: Node in _parts:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_parts.clear()
	var start: Vector3 = Vector3.UP * cable_height
	var end: Vector3 = end_point + Vector3.UP * cable_height
	var length: float = start.distance_to(end)
	if length < 0.5:
		return
	var along: Basis = basis_along(end - start)
	var middle: Transform3D = Transform3D(along, (start + end) * 0.5)
	var cable: CylinderMesh = CylinderMesh.new()
	cable.top_radius = CABLE_RADIUS
	cable.bottom_radius = CABLE_RADIUS
	cable.height = length
	cable.radial_segments = 8
	cable.rings = 1
	_add_mesh(cable, Palette.ABYSS, middle)
	for base: Vector3 in [Vector3.ZERO, end_point]:
		var post: CylinderMesh = CylinderMesh.new()
		post.top_radius = POST_RADIUS
		post.bottom_radius = POST_RADIUS * 1.3
		post.height = cable_height + 0.3
		post.radial_segments = 12
		_add_mesh(post, Palette.SAND, Transform3D(Basis.IDENTITY, base + Vector3.UP * (cable_height + 0.3) * 0.5))
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = GRAB_RADIUS
	shape.height = length + GRAB_RADIUS * 2.0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.transform = middle
	_add_part(collision)
	if Engine.is_editor_hint():
		update_gizmos()


func _add_mesh(mesh: PrimitiveMesh, color: Color, at: Transform3D) -> void:
	mesh.material = material_for(color)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = at
	_add_part(instance)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
	_parts.append(part)


## A basis whose Y axis runs along [param direction] (cylinders and capsules are Y-up).
static func basis_along(direction: Vector3) -> Basis:
	var y: Vector3 = direction.normalized()
	var helper: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x: Vector3 = helper.cross(y).normalized()
	return Basis(x, y, x.cross(y))


static func material_for(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]
