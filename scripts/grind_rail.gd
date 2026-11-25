@tool
class_name GrindRail
extends Area3D
## A rail players land on from above and slide along standing up, faster downhill, jumping off
## anywhere. It has no solid collision (players would just stand on it): a thin zone along its top
## notices a player coming down onto it, and the player's own machine takes over
## (Player.try_grind()), so it needs no networking.
##
## The origin is the base of the first post; end_point is the base of the last (in this node's
## space). The rail runs rail_height above them, on posts about POST_SPACING apart. Level Tools
## gives the far end a drag handle. Its parts are internal, so scenes only store the exports.

## The far end's base, in this node's space.
@export var end_point: Vector3 = Vector3(0, 0, -12):
	set(value):
		end_point = value
		queue_build()
## How high the rail is above its posts' bases.
@export var rail_height: float = 1.0:
	set(value):
		rail_height = maxf(value, 0.3)
		queue_build()

const RAIL_RADIUS: float = 0.08
const POST_RADIUS: float = 0.06
const POST_SPACING: float = 3.0
## The zone over the rail that notices a player landing: how wide, and how far up from the rail.
const CATCH_WIDTH: float = 0.9
const CATCH_HEIGHT: float = 0.9

var _parts: Array[Node] = []
var _build_queued: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	build()


func queue_build() -> void:
	if is_inside_tree() and not _build_queued:
		_build_queued = true
		build.call_deferred()


## The rail's ends, global.
func get_start() -> Vector3:
	return global_transform * (Vector3.UP * rail_height)


func get_end() -> Vector3:
	return global_transform * (end_point + Vector3.UP * rail_height)


## How far along the rail (0 to 1) the point nearest [param point] is.
func closest_fraction(point: Vector3) -> float:
	var along: Vector3 = get_end() - get_start()
	return clampf((point - get_start()).dot(along) / along.length_squared(), 0.0, 1.0)


## The player's own machine hands any of its players coming down onto the rail to them.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player != null and player.is_multiplayer_authority():
			player.try_grind(self)


func build() -> void:
	_build_queued = false
	for part: Node in _parts:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_parts.clear()
	var start: Vector3 = Vector3.UP * rail_height
	var end: Vector3 = end_point + Vector3.UP * rail_height
	var length: float = start.distance_to(end)
	if length < 0.5:
		return
	var along: Basis = Zipline.basis_along(end - start)
	var rail: CylinderMesh = CylinderMesh.new()
	rail.top_radius = RAIL_RADIUS
	rail.bottom_radius = RAIL_RADIUS
	rail.height = length
	rail.radial_segments = 10
	rail.rings = 1
	_add_mesh(rail, Palette.BERRY, Transform3D(along, (start + end) * 0.5))
	var posts: int = maxi(ceili(length / POST_SPACING), 1)
	for index: int in posts + 1:
		var base: Vector3 = end_point * (float(index) / posts)
		var post: CylinderMesh = CylinderMesh.new()
		post.top_radius = POST_RADIUS
		post.bottom_radius = POST_RADIUS
		post.height = rail_height
		post.radial_segments = 8
		_add_mesh(post, Palette.SAND, Transform3D(Basis.IDENTITY, base + Vector3.UP * rail_height * 0.5))
	# The catching zone: a box along the rail, from just under its top to CATCH_HEIGHT above.
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(CATCH_WIDTH, length, CATCH_HEIGHT)
	var flat_side: Vector3 = (end - start).cross(Vector3.UP).normalized()
	var up: Vector3 = flat_side.cross((end - start).normalized())
	var catch_basis: Basis = Basis(flat_side, (end - start).normalized(), up)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = box
	collision.transform = Transform3D(catch_basis, (start + end) * 0.5 + up * (CATCH_HEIGHT * 0.5 - 0.15))
	_add_part(collision)
	if Engine.is_editor_hint():
		update_gizmos()


func _add_mesh(mesh: PrimitiveMesh, color: Color, at: Transform3D) -> void:
	mesh.material = Zipline.material_for(color)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = at
	_add_part(instance)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
	_parts.append(part)
