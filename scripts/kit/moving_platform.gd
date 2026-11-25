@tool
class_name MovingPlatform
extends AnimatableBody3D
## A kit platform that moves: MOVE travels back and forth to end_point, pausing at each end, and
## SPIN turns around its own up axis. It's a box sized and painted like a KitBox, or any level model
## (model): a spinner disc that spins, a sweeper bar that sweeps a floor, a platform that shuttles.
## Players standing on it ride along (an AnimatableBody3D carries character bodies, turning
## included). Its parts are internal children, and Level Tools makes it clickable and gives MOVE a
## handle on its far end.
##
## No networking: it's placed from NetClock, the host's clock, so it's in the same spot on every
## peer. Platforms with the same settings move in step; phase offsets one from another.

enum Motion { MOVE, SPIN }

## Saved by index, so only append.
@export var motion: Motion = Motion.MOVE:
	set(value):
		motion = value
		update_gizmos()
@export var size: Vector3 = Vector3(4, 0.5, 4):
	set(value):
		size = KitPiece.snap_vector(value)
		_queue_build()
@export var color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST:
	set(value):
		color = value
		_queue_build()
## A level model to move instead of the box: a spinner disc, a sweeper bar, a platform model. It
## collides with its exact shape, and Size and Color no longer apply.
@export var model: PackedScene:
	set(value):
		model = value
		_queue_build()
@export_group("Move")
## Where a MOVE platform travels to, from where it's placed (in its own space, like a zipline's).
@export var end_point: Vector3 = Vector3(0, 0, -8):
	set(value):
		end_point = value
		update_gizmos()
## Seconds to travel one way, and to wait at each end.
@export var travel_seconds: float = 4.0
@export var pause_seconds: float = 1.0
@export_group("Spin")
## Degrees per second; negative spins the other way.
@export var spin_speed: float = 45.0
@export_group("")
## Shifts this platform along its cycle (0-1), so neighbours don't all move together.
@export_range(0.0, 1.0) var phase: float = 0.0

var _parts: Array[Node] = []
var _build_queued: bool = false
var _start: Transform3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_start = transform
	sync_to_physics = true


func _physics_process(_delta: float) -> void:
	var time: float = NetClock.now()
	if motion == Motion.SPIN:
		var turn: float = deg_to_rad(spin_speed) * time + phase * TAU
		transform = Transform3D(_start.basis * Basis(Vector3.UP, turn), _start.origin)
		return
	var cycle: float = 2.0 * (travel_seconds + pause_seconds)
	var at: float = fposmod(time + phase * cycle, cycle)
	# Out, pause, back, pause; eased so riders aren't jolted at the ends.
	var progress: float = 1.0
	if at < travel_seconds:
		progress = at / travel_seconds
	elif at < travel_seconds + pause_seconds:
		progress = 1.0
	elif at < 2.0 * travel_seconds + pause_seconds:
		progress = 1.0 - (at - travel_seconds - pause_seconds) / travel_seconds
	else:
		progress = 0.0
	progress = smoothstep(0.0, 1.0, progress)
	transform = Transform3D(_start.basis, _start.origin + _start.basis * (end_point * progress))


## The middle of the platform's top now (global), for bots riding it.
func get_top() -> Vector3:
	return global_transform * (Vector3.UP * _top_height())


## The middle of the platform's top at its start and at its end (global), for bots riding a MOVE
## platform as a lift. In game only (the start is where it was placed).
func get_stop_tops() -> Array[Vector3]:
	var top: Vector3 = Vector3.UP * _top_height()
	return [_start * top, Transform3D(_start.basis, _start.origin + _start.basis * end_point) * top]


func _top_height() -> float:
	if model == null:
		return size.y
	var faces: PackedVector3Array = get_faces()
	var height: float = 0.0
	for point: Vector3 in faces:
		height = maxf(height, point.y)
	return height


## The platform's triangles in its own space (box or model), for Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for part: Node in _parts:
		if part is Node3D and not part is CollisionShape3D:
			LevelModel._gather_faces(part, (part as Node3D).transform, faces)
	return faces


func _queue_build() -> void:
	if is_inside_tree() and not _build_queued:
		_build_queued = true
		_build.call_deferred()


func _build() -> void:
	_build_queued = false
	for part: Node in _parts:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_parts.clear()
	var look: Node3D
	var collision: CollisionShape3D = CollisionShape3D.new()
	var instance: Node3D = model.instantiate() as Node3D if model != null else null
	if instance != null:
		look = instance
		var faces: PackedVector3Array = PackedVector3Array()
		LevelModel._gather_faces(instance, instance.transform, faces)
		var exact: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		exact.set_faces(faces)
		collision.shape = exact
	else:
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = KitPiece.material_for(color)
		mesh.position.y = size.y / 2.0
		look = mesh
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position.y = size.y / 2.0
	for part: Node in [look, collision]:
		add_child(part, false, Node.INTERNAL_MODE_BACK)
		_parts.append(part)
	if Engine.is_editor_hint():
		update_gizmos()
