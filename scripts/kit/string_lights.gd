@tool
class_name StringLights
extends Node3D
## A string of party lights between two points: a sagging cable hung with glowing bulbs in the
## warm colours. Decoration only (no collision). Like a zipline, the origin is one end and
## end_point the other (in its own space); Level Tools gives a selected string a handle on its far
## end, and the kit gizmo makes it clickable.

const BULB_COLORS: Array[Color] = [Palette.SUNBURST, Palette.CORAL, Palette.MINT, Palette.BERRY, Palette.SKY]

@export var end_point: Vector3 = Vector3(0, 0, -8):
	set(value):
		end_point = value
		_queue_build()
		update_gizmos()
## How far the middle of the cable hangs below a straight line (m).
@export var sag: float = 0.8:
	set(value):
		sag = maxf(value, 0.0)
		_queue_build()
## Meters between bulbs.
@export var spacing: float = 0.7:
	set(value):
		spacing = maxf(value, 0.2)
		_queue_build()

var _mesh: MeshInstance3D
var _build_queued: bool = false


func _ready() -> void:
	_build()


func get_start() -> Vector3:
	return global_position


func get_end() -> Vector3:
	return to_global(end_point)


## Triangles in its own space, for Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	return _mesh.mesh.get_faces() if _mesh != null and _mesh.mesh != null else PackedVector3Array()


## Where the cable is, [param t] (0 to 1) along it, in its own space.
func point_at(t: float) -> Vector3:
	return end_point * t + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


func _queue_build() -> void:
	if is_inside_tree() and not _build_queued:
		_build_queued = true
		_build.call_deferred()


func _build() -> void:
	_build_queued = false
	if _mesh != null:
		remove_child(_mesh)
		_mesh.queue_free()
	var tool: SurfaceTool = IslandMeshes.flat_tool()
	var length: float = end_point.length()
	var steps: int = maxi(ceili(length / 0.5), 2)
	var cable: PackedVector3Array = PackedVector3Array()
	for step: int in steps + 1:
		cable.append(point_at(float(step) / steps))
	IslandMeshes.add_tube(tool, cable, 0.025, 0.025, Palette.ASPHALT, 4)
	var bulbs: int = maxi(floori(length / spacing), 1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for bulb: int in bulbs:
		var at: Vector3 = point_at((bulb + 0.5) / bulbs) + Vector3.DOWN * 0.1
		var color: Color = BULB_COLORS[bulb % BULB_COLORS.size()]
		# A glowing bulb under a little dark cap.
		_add_bulb(tool, at, color, rng)
		IslandMeshes.add_lump(tool, at + Vector3.UP * 0.1, Vector3(0.07, 0.05, 0.07), Palette.ASPHALT, rng)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = IslandMeshes.commit_flat(tool)
	_mesh.material_override = IslandMeshes.material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
	if Engine.is_editor_hint():
		update_gizmos()


## A small glowing lump (island material's glow look).
static func _add_bulb(tool: SurfaceTool, at: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var points: Array[Vector3] = []
	for point: Vector3 in IslandMeshes.ICO_POINTS:
		points.append(at + point.normalized() * Vector3(0.1, 0.12, 0.1) * rng.randf_range(0.9, 1.1))
	for face: Vector3i in IslandMeshes.ICO_FACES:
		IslandMeshes.triangle(tool, points[face.x], points[face.z], points[face.y], color, IslandMeshes.GLOW)
