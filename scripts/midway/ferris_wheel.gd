@tool
class_name FerrisWheel
extends Node3D
## Monster Midway's Ferris wheel: twin rims of bulbs on spokes round a hub, on an A-frame either
## side, turning slowly with its cabins hanging level. The wheel is for looking at: only the
## A-frame legs collide (the Sky Ride deck beside it is what players climb).
##
## The wheel stands in its own XY plane (the axle along Z), its hub hub_height up. It turns with
## NetClock, so it's at the same angle on every peer. Its parts are internal children built in
## _ready.

@export var radius: float = 11.0
@export var hub_height: float = 13.0
## Degrees per second.
@export var spin_speed: float = 5.0

const CABINS: int = 12
## Half the gap between the two rims (along the axle).
const HALF_DEPTH: float = 1.1
const CABIN_COLORS: Array[Color] = [Palette.CORAL, Palette.SKY, Palette.SUNBURST, Palette.BERRY, Palette.MOSS, Palette.TEAL]

var _wheel: Node3D
var _cabins: Array[Node3D] = []


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		set_process(false)


func _process(_delta: float) -> void:
	_turn(deg_to_rad(spin_speed) * NetClock.now())


func _turn(angle: float) -> void:
	_wheel.rotation.z = angle
	for index: int in _cabins.size():
		var at: float = TAU * index / CABINS + angle
		_cabins[index].position = Vector3(sin(at), -cos(at), 0.0) * radius + Vector3.UP * hub_height


func _build() -> void:
	var frame: SurfaceTool = MidwayMeshes.begin()
	# The A-frames: two legs each side of the wheel, splayed, with a cross brace and a bulb strip.
	for depth: float in [-1.0, 1.0]:
		var hub: Vector3 = Vector3(0.0, hub_height, depth * (HALF_DEPTH + 0.6))
		for side: float in [-1.0, 1.0]:
			var foot: Vector3 = Vector3(side * radius * 0.55, 0.0, depth * (HALF_DEPTH + 1.6))
			MidwayMeshes.bar(frame, foot, hub, 0.32, Palette.CREAM.darkened(0.1))
			MidwayMeshes.bulbs(frame, foot.lerp(hub, 0.08) + Vector3(0, 0, depth * 0.34), hub.lerp(foot, 0.08) + Vector3(0, 0, depth * 0.34), 0.9, 0.1, 2)
			_add_leg_shape(foot, hub)
		var brace_y: float = hub_height * 0.4
		MidwayMeshes.bar(frame, Vector3(-radius * 0.55 * 0.6, brace_y, depth * (HALF_DEPTH + 1.2)), Vector3(radius * 0.55 * 0.6, brace_y, depth * (HALF_DEPTH + 1.2)), 0.16, Palette.CREAM.darkened(0.1))
	# The axle between the frames.
	MidwayMeshes.bar(frame, Vector3(0, hub_height, -(HALF_DEPTH + 0.9)), Vector3(0, hub_height, HALF_DEPTH + 0.9), 0.4, Palette.SUNBURST, MidwayMeshes.SOFT)
	_add_part(MidwayMeshes.instance(frame))

	# The wheel: two rims of bulbs, spokes, a star of a hub, and the rods the cabins hang from.
	_wheel = Node3D.new()
	_wheel.position = Vector3.UP * hub_height
	var wheel: SurfaceTool = MidwayMeshes.begin()
	var turned: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for depth: float in [-HALF_DEPTH, HALF_DEPTH]:
		MidwayMeshes.ring(wheel, Transform3D(turned, Vector3(0, 0, depth)), radius, 0.16, Palette.CORAL, MidwayMeshes.SOFT, 64, 6)
		MidwayMeshes.ring(wheel, Transform3D(turned, Vector3(0, 0, depth)), radius * 0.62, 0.1, Palette.SUNBURST, MidwayMeshes.SOFT, 48, 6)
		for index: int in CABINS * 3:
			var at: float = TAU * index / (CABINS * 3)
			var bulb_colors: Array[Color] = MidwayMeshes.BULB_COLORS
			MidwayMeshes.ball(wheel, Vector3(sin(at), -cos(at), 0.0) * radius + Vector3(0, 0, depth * 1.12), 0.16, bulb_colors[index % bulb_colors.size()], MidwayMeshes.LIT, 4, 6)
		for index: int in CABINS:
			var at: float = TAU * (index + 0.5) / CABINS
			MidwayMeshes.bar(wheel, Vector3(0, 0, depth), Vector3(sin(at), -cos(at), 0.0) * radius + Vector3(0, 0, depth), 0.09, Palette.CREAM)
	for index: int in CABINS:
		var at: float = TAU * index / CABINS
		var rim: Vector3 = Vector3(sin(at), -cos(at), 0.0) * radius
		MidwayMeshes.bar(wheel, rim + Vector3(0, 0, -HALF_DEPTH), rim + Vector3(0, 0, HALF_DEPTH), 0.08, Palette.CREAM)
	MidwayMeshes.ball(wheel, Vector3.ZERO, 1.2, Palette.BERRY, MidwayMeshes.SOFT, 8, 12)
	for index: int in 8:
		var at: float = TAU * index / 8.0
		MidwayMeshes.ball(wheel, Vector3(sin(at), -cos(at), 0.0) * 1.6, 0.25, Palette.SUNBURST, MidwayMeshes.LIT, 4, 6)
	_wheel.add_child(MidwayMeshes.instance(wheel, false))
	_add_part(_wheel)

	# The cabins: round tubs with a striped roof, hanging from the rim rods.
	_cabins.clear()
	for index: int in CABINS:
		var cabin: Node3D = Node3D.new()
		var tub: SurfaceTool = MidwayMeshes.begin()
		var color: Color = CABIN_COLORS[index % CABIN_COLORS.size()]
		MidwayMeshes.bar(tub, Vector3.ZERO, Vector3.DOWN * 0.9, 0.05, Palette.CREAM)
		MidwayMeshes.cylinder(tub, Transform3D(Basis.IDENTITY, Vector3.DOWN * 2.4), 0.95, 1.0, color, MidwayMeshes.PLAIN, 14, 1.1)
		MidwayMeshes.ring(tub, Transform3D(Basis.IDENTITY, Vector3.DOWN * 1.4), 1.1, 0.07, Palette.SUNBURST, MidwayMeshes.PLAIN, 20, 5)
		MidwayMeshes.striped_cone(tub, Vector3.DOWN * 0.9, 1.15, 0.55, [color.lightened(0.35), Palette.CREAM], Palette.SUNBURST, 12)
		for side: float in [-1.0, 1.0]:
			MidwayMeshes.bar(tub, Vector3(side * 0.9, -1.4, 0.0), Vector3(side * 0.9, -0.95, 0.0), 0.04, Palette.CREAM)
		cabin.add_child(MidwayMeshes.instance(tub, false))
		_add_part(cabin)
		_cabins.append(cabin)
	_turn(0.0)


## A solid leg, so nobody runs through the A-frame.
func _add_leg_shape(foot: Vector3, top: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = foot.distance_to(top)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(MidwayMeshes.along(top - foot), (foot + top) * 0.5)
	body.add_child(collision)
	_add_part(body)


## For Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	return MidwayMeshes.faces_of(self)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
