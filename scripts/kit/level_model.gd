@tool
class_name LevelModel
extends StaticBody3D
## One of your own models (a GLB under res://assets/models/level/) placed in a level. Like a kit
## piece, it builds its parts as internal children whenever it enters the tree, in the editor and
## in game: the model itself, untouched (it keeps its own materials), and collision made from its
## meshes. Level scenes only store the exports, so re-exporting a GLB updates every copy.
##
## The model's origin is the node's origin: model it with the origin at the center of its base,
## like kit pieces, so it sits on whatever it's placed on. If the GLB brings its own collision,
## set collision to NONE.

## How the model collides. MESH follows its shape exactly (arches, holes and ledges work); HULL
## wraps it in one convex shape (fills in gaps, smoother to run along); BOX is its bounding box;
## NONE is decoration only; SLOPE is for stairs: a smooth slope from the foot of the bottom step
## to the top step's front edge, then flat, so players walk up instead of vaulting each step
## (kit stairs collide the same way). Saved by index, so only append.
enum Collision { MESH, HULL, BOX, NONE, SLOPE }

## Where Level Tools lists models from; subfolders are its categories.
const MODELS_DIR: String = "res://assets/models/level"

@export var model: PackedScene:
	set(value):
		model = value
		queue_build()
## Uniform size. The collision is built at this size (physics bodies shouldn't be scaled).
@export_range(0.1, 10.0, 0.05, "or_greater") var model_scale: float = 1.0:
	set(value):
		model_scale = maxf(value, 0.01)
		queue_build()
@export var collision: Collision = Collision.MESH:
	set(value):
		collision = value
		queue_build()

## Collision shared by every copy of a model at the same size and collision type:
## {"shape": Shape3D, "transform": Transform3D}, keyed by _shape_key().
static var _shapes: Dictionary[String, Dictionary] = {}

var _parts: Array[Node] = []
var _build_queued: bool = false


func _ready() -> void:
	build()


## Forgets the shared collision of the model at [param path], which has been loaded again (a map
## package's own GLB, rebuilt by a playtest's reload) and may have changed.
static func forget_shapes(path: String) -> void:
	for key: String in _shapes.keys():
		if key.begins_with(path + "|"):
			_shapes.erase(key)


## Rebuilds at the end of the frame, once per batch of export changes.
func queue_build() -> void:
	if is_inside_tree() and not _build_queued:
		_build_queued = true
		build.call_deferred()


func build() -> void:
	_build_queued = false
	for part: Node in _parts:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_parts.clear()
	if model != null:
		var instance: Node3D = model.instantiate() as Node3D
		if instance != null:
			instance.scale *= model_scale
			_add_part(instance)
			if collision != Collision.NONE:
				var built: Dictionary = _collision_for(instance)
				if not built.is_empty():
					var shape: CollisionShape3D = CollisionShape3D.new()
					shape.shape = built["shape"]
					shape.transform = built["transform"]
					_add_part(shape)
	# Level Tools' kit gizmo makes the model clickable in the editor.
	if Engine.is_editor_hint():
		update_gizmos()


## The model's triangles in this node's space (scale included), for collision and the editor's
## click gizmo.
func get_faces() -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for part: Node in _parts:
		if part is Node3D and not part is CollisionShape3D:
			_gather_faces(part, (part as Node3D).transform, faces)
	return faces


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
	_parts.append(part)


func _collision_for(instance: Node3D) -> Dictionary:
	var key: String = "%s|%s|%d" % [model.resource_path, model_scale, collision]
	# Only shared in game: in the editor a re-exported model must rebuild its collision.
	var shared: bool = not Engine.is_editor_hint() and model.resource_path != ""
	if shared and _shapes.has(key):
		return _shapes[key]
	var faces: PackedVector3Array = PackedVector3Array()
	_gather_faces(instance, instance.transform, faces)
	if faces.is_empty():
		return {}
	var built: Dictionary = {"transform": Transform3D.IDENTITY}
	match collision:
		Collision.MESH:
			var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
			concave.set_faces(faces)
			built["shape"] = concave
		Collision.HULL:
			var convex: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			convex.points = faces
			built["shape"] = convex
		Collision.BOX:
			var bounds: AABB = AABB(faces[0], Vector3.ZERO)
			for point: Vector3 in faces:
				bounds = bounds.expand(point)
			var box: BoxShape3D = BoxShape3D.new()
			box.size = bounds.size.max(Vector3.ONE * 0.05)
			built["shape"] = box
			built["transform"] = Transform3D(Basis.IDENTITY, bounds.get_center())
		Collision.SLOPE:
			var slope: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			slope.points = _slope_points(faces)
			built["shape"] = slope
	if shared:
		_shapes[key] = built
	return built


## The corners of a stairs model's SLOPE: a wedge across its full width, rising along whichever
## flat axis its top climbs most, from the bottom at the low end to full height where the top step
## starts. Something that doesn't climb gets its hull instead.
static func _slope_points(faces: PackedVector3Array) -> PackedVector3Array:
	var bounds: AABB = AABB(faces[0], Vector3.ZERO)
	for point: Vector3 in faces:
		bounds = bounds.expand(point)
	var center: Vector3 = bounds.get_center()
	# Which way it climbs: the flat axis (and sign) with the biggest rise from one end to the other.
	var along: Vector3 = Vector3.ZERO
	var best_rise: float = 0.0
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var half: float = (bounds.size * axis).length() * 0.4
		var rise: float = _top_at(faces, center + axis * half) - _top_at(faces, center - axis * half)
		if absf(rise) > absf(best_rise):
			best_rise = rise
			along = axis * signf(rise)
	if absf(best_rise) < 0.1:
		return faces
	var length: float = (bounds.size * along).length()
	var across: Vector3 = Vector3.UP.cross(along)
	var width: float = (bounds.size * across).length()
	var low_end: Vector3 = Vector3(center.x, 0.0, center.z) - along * length * 0.5
	var bottom: float = bounds.position.y
	var top: float = bounds.end.y
	# Where the top step starts: the first point along the climb that reaches full height.
	var top_start: float = length
	const SAMPLES: int = 40
	for sample: int in SAMPLES + 1:
		var distance: float = length * sample / SAMPLES
		if _top_at(faces, low_end + along * distance) >= top - 0.05:
			top_start = maxf(distance, 0.05)
			break
	var points: PackedVector3Array = PackedVector3Array()
	for side: float in [-0.5, 0.5]:
		var edge: Vector3 = low_end + across * width * side
		points.append(edge + Vector3.UP * bottom)
		points.append(edge + along * top_start + Vector3.UP * top)
		points.append(edge + along * length + Vector3.UP * top)
		points.append(edge + along * length + Vector3.UP * bottom)
	return points


## The height of the highest triangle in [param faces] straight below a point high above
## [param at] (only x and z count), or -INF where there's none.
static func _top_at(faces: PackedVector3Array, at: Vector3) -> float:
	var best: float = -INF
	var from: Vector3 = Vector3(at.x, 1000.0, at.z)
	for index: int in range(0, faces.size() - 2, 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			best = maxf(best, (hit as Vector3).y)
	return best


## Every mesh's triangles under [param node], which sits at [param at] in this node's space.
static func _gather_faces(node: Node, at: Transform3D, faces: PackedVector3Array) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		faces.append_array(at * mesh_instance.mesh.get_faces())
	for child: Node in node.get_children(true):
		var child_3d: Node3D = child as Node3D
		if child_3d != null:
			_gather_faces(child_3d, at * child_3d.transform, faces)
