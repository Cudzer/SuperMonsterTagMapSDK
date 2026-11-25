@tool
class_name TownClock
extends Node3D
## A clock face for a tower: a cream face in a trim ring with hour marks and two hands, facing +Z.
## Decoration only. The minute hand goes round once a minute (and the hour hand once in twelve), on
## NetClock, so every player's clock shows the same time. In the editor it stops at ten past ten.

@export var radius: float = 1.6:
	set(value):
		radius = maxf(value, 0.3)
		_queue_build()
@export var face_color: KitPiece.Swatch = KitPiece.Swatch.CREAM:
	set(value):
		face_color = value
		_queue_build()
@export var trim_color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST:
	set(value):
		trim_color = value
		_queue_build()

var _parts: Array[Node] = []
var _minute_hand: Node3D
var _hour_hand: Node3D
var _build_queued: bool = false


func _ready() -> void:
	_build()
	set_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	var minutes: float = NetClock.now() / 60.0
	_minute_hand.rotation.z = -fposmod(minutes, 1.0) * TAU
	_hour_hand.rotation.z = -fposmod(minutes / 12.0, 1.0) * TAU


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
	var r: float = radius
	# The ring and the face: discs facing +Z.
	var facing: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	_add(_disc(r * 1.12, 0.12), Transform3D(facing, Vector3.ZERO), trim_color)
	_add(_disc(r, 0.06), Transform3D(facing, Vector3(0, 0, 0.07)), face_color)
	for hour: int in 12:
		var angle: float = TAU * hour / 12.0
		var mark: BoxMesh = BoxMesh.new()
		mark.size = Vector3(r * 0.06, r * (0.16 if hour % 3 == 0 else 0.1), 0.02)
		var at: Vector3 = Vector3(sin(angle), cos(angle), 0.0) * r * 0.82 + Vector3(0, 0, 0.11)
		_add(mark, Transform3D(Basis(Vector3.BACK, -angle), at), KitPiece.Swatch.ASPHALT)
	_hour_hand = _hand(r * 0.5, r * 0.09, 0.13)
	_minute_hand = _hand(r * 0.78, r * 0.06, 0.15)
	_hour_hand.rotation.z = -TAU * (10.17 / 12.0)
	_minute_hand.rotation.z = -TAU * (10.0 / 60.0)
	var pin: CylinderMesh = _disc(r * 0.08, 0.06)
	_add(pin, Transform3D(facing, Vector3(0, 0, 0.17)), trim_color)


## A hand pointing up from the middle, [param length] long, turning about Z.
func _hand(length: float, thickness: float, out: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(0, 0, out)
	add_child(pivot, false, Node.INTERNAL_MODE_BACK)
	_parts.append(pivot)
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(thickness, length, 0.02)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = bar
	instance.position = Vector3(0, length * 0.4, 0)
	instance.material_override = KitPiece.material_for(KitPiece.Swatch.ASPHALT)
	pivot.add_child(instance)
	return pivot


func _add(mesh: Mesh, at: Transform3D, swatch: KitPiece.Swatch) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = at
	instance.material_override = KitPiece.material_for(swatch)
	add_child(instance, false, Node.INTERNAL_MODE_BACK)
	_parts.append(instance)


static func _disc(disc_radius: float, thickness: float) -> CylinderMesh:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = disc_radius
	disc.bottom_radius = disc_radius
	disc.height = thickness
	disc.radial_segments = 32
	disc.rings = 1
	return disc
