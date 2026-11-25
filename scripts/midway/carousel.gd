@tool
class_name Carousel
extends AnimatableBody3D
## Monster Midway's carousel, in the middle of the plaza: a low round deck that turns, with a
## mirrored column in the middle, a striped canopy ringed with bulbs, and monster "horses" on gold
## poles that bob up and down. Hop on and it carries you round (an AnimatableBody3D carries
## character bodies). The deck is low enough to step onto.
##
## No networking: it turns with NetClock, like MovingPlatform, so it's at the same angle on every
## peer; the horses' bob is cosmetic. Its parts are internal children built in _ready.

## The deck's radius; everything else scales with it.
@export var radius: float = 5.0
## Degrees per second.
@export var spin_speed: float = 16.0

const DECK_HEIGHT: float = 0.35
const CANOPY_HEIGHT: float = 4.6
const HORSES: int = 8
const HORSE_COLORS: Array[Color] = [Palette.CORAL, Palette.SKY, Palette.SUNBURST, Palette.MOSS, Palette.BERRY, Palette.TEAL, Palette.LILAC, Palette.MINT]

var _horses: Array[Node3D] = []
var _start: Transform3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return
	_start = transform
	sync_to_physics = true


func _physics_process(_delta: float) -> void:
	var turn: float = deg_to_rad(spin_speed) * NetClock.now()
	transform = Transform3D(_start.basis * Basis(Vector3.UP, turn), _start.origin)


func _process(_delta: float) -> void:
	var time: float = NetClock.now()
	for index: int in _horses.size():
		_horses[index].position.y = DECK_HEIGHT + 1.0 + 0.35 * sin(time * 1.8 + index * TAU / HORSES * 2.0)


func _build() -> void:
	var r: float = radius
	var tool: SurfaceTool = MidwayMeshes.begin()
	# The deck: boards in two shades, a gold rim, a skirt of panels with a bulb on each.
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.0, DECK_HEIGHT, 0.0), Vector3(r - 0.25, DECK_HEIGHT, 0.0), Vector3(r, DECK_HEIGHT, 0.0),
		Vector3(r, 0.05, 0.0), Vector3(r - 0.1, 0.0, 0.0),
	]), 32, [[Palette.SAND.darkened(0.25), Palette.SAND.darkened(0.1)], Palette.SUNBURST, [Palette.BERRY, Palette.CORAL], Palette.BERRY.darkened(0.3)], MidwayMeshes.PLAIN)
	MidwayMeshes.bulb_ring(tool, Vector3.UP * DECK_HEIGHT * 0.5, r + 0.02, 32, 0.08)
	# The column: mirror panels between gold bands, up to the canopy.
	var column: float = r * 0.24
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(column, CANOPY_HEIGHT, 0.0), Vector3(column, CANOPY_HEIGHT - 0.4, 0.0), Vector3(column * 0.92, CANOPY_HEIGHT - 0.4, 0.0),
		Vector3(column * 0.92, DECK_HEIGHT + 0.4, 0.0), Vector3(column, DECK_HEIGHT + 0.4, 0.0), Vector3(column, DECK_HEIGHT, 0.0),
	]), 12, [Palette.SUNBURST, Palette.SUNBURST, [Palette.SEAFOAM, Palette.FROST], Palette.SUNBURST, Palette.SUNBURST], MidwayMeshes.SOFT)
	# The canopy: a striped cone with a scalloped valance, bulbs round its rim and a finial on top.
	var rim: float = r + 0.4
	MidwayMeshes.striped_cone(tool, Vector3.UP * CANOPY_HEIGHT, rim, 2.6, [Palette.CORAL, Palette.CREAM], Palette.SUNBURST, 24)
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(rim - 0.02, CANOPY_HEIGHT - 0.01, 0.0), Vector3(column, CANOPY_HEIGHT - 0.01, 0.0),
	]), 24, [[Palette.BERRY.darkened(0.2), Palette.LILAC.darkened(0.2)]], MidwayMeshes.SOFT)
	MidwayMeshes.bulb_ring(tool, Vector3.UP * (CANOPY_HEIGHT - 0.45), rim + 0.06, 24, 0.13, 1)
	MidwayMeshes.ball(tool, Vector3.UP * (CANOPY_HEIGHT + 2.75), 0.35, Palette.SUNBURST, MidwayMeshes.LIT)
	# Poles: from the deck to the canopy, one through each horse.
	for index: int in HORSES:
		var at: Vector3 = IslandMeshes.around(TAU * index / HORSES) * r * 0.68
		MidwayMeshes.bar(tool, at + Vector3.UP * DECK_HEIGHT, at + Vector3.UP * (CANOPY_HEIGHT - 0.2), 0.05, Palette.SUNBURST, MidwayMeshes.SOFT)
	_add_part(MidwayMeshes.instance(tool))
	# A light under the canopy, so the plaza glows round it.
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3.UP * (CANOPY_HEIGHT - 0.8)
	light.light_color = Palette.SUNBURST.lerp(Palette.CREAM, 0.5)
	light.light_energy = 2.2
	light.omni_range = r * 3.6
	light.omni_attenuation = 1.2
	_add_part(light)

	# The horses, built facing round the ride (tangent), each its own node so it can bob.
	_horses.clear()
	for index: int in HORSES:
		var angle: float = TAU * index / HORSES
		var horse: Node3D = Node3D.new()
		horse.position = IslandMeshes.around(angle) * r * 0.68 + Vector3.UP * (DECK_HEIGHT + 1.0)
		horse.rotation.y = angle + PI * 0.5
		var body: SurfaceTool = MidwayMeshes.begin()
		_monster(body, HORSE_COLORS[index % HORSE_COLORS.size()], index)
		horse.add_child(MidwayMeshes.instance(body))
		_add_part(horse)
		_horses.append(horse)

	# Collision: the deck, the column and the poles (the horses and canopy are out of reach).
	var deck: CylinderShape3D = CylinderShape3D.new()
	deck.radius = r
	deck.height = DECK_HEIGHT
	_add_shape(deck, Vector3.UP * DECK_HEIGHT * 0.5)
	var pillar: CylinderShape3D = CylinderShape3D.new()
	pillar.radius = column
	pillar.height = CANOPY_HEIGHT - DECK_HEIGHT
	_add_shape(pillar, Vector3.UP * (DECK_HEIGHT + CANOPY_HEIGHT) * 0.5)
	for index: int in HORSES:
		var pole: CylinderShape3D = CylinderShape3D.new()
		pole.radius = 0.08
		pole.height = CANOPY_HEIGHT - DECK_HEIGHT
		_add_shape(pole, IslandMeshes.around(TAU * index / HORSES) * r * 0.68 + Vector3.UP * (DECK_HEIGHT + CANOPY_HEIGHT) * 0.5)


## A round monster to ride, facing -Z in its own space: a squashed egg body, a head with big eyes
## and a pair of horns or ears, stubby legs, a curly tail, and a saddle.
func _monster(tool: SurfaceTool, color: Color, index: int) -> void:
	var dark: Color = color.darkened(0.3)
	MidwayMeshes.blob(tool, Transform3D(Basis.IDENTITY.scaled(Vector3(0.42, 0.42, 0.7)), Vector3.ZERO), color)
	MidwayMeshes.blob(tool, Transform3D(Basis.IDENTITY.scaled(Vector3(0.36, 0.34, 0.36)), Vector3(0.0, 0.45, -0.68)), color)
	for side: float in [-1.0, 1.0]:
		MidwayMeshes.ball(tool, Vector3(side * 0.15, 0.58, -0.98), 0.11, Palette.CREAM)
		MidwayMeshes.ball(tool, Vector3(side * 0.15, 0.58, -1.07), 0.05, Palette.ABYSS)
		if index % 2 == 0:
			# Little horns.
			MidwayMeshes.cylinder(tool, Transform3D(Basis(Vector3.BACK, side * -0.35), Vector3(side * 0.2, 0.72, -0.62)), 0.07, 0.3, Palette.CREAM, MidwayMeshes.PLAIN, 6, 0.0)
		else:
			# Floppy ears.
			MidwayMeshes.blob(tool, Transform3D(Basis(Vector3.BACK, side * 0.9).scaled(Vector3(0.08, 0.2, 0.12)), Vector3(side * 0.32, 0.62, -0.62)), dark)
		for end: float in [-1.0, 1.0]:
			MidwayMeshes.cylinder(tool, Transform3D(Basis(Vector3.RIGHT, end * 0.4), Vector3(side * 0.22, -0.25, end * 0.42)), 0.09, 0.45, dark, MidwayMeshes.PLAIN, 6)
	# A smile, the saddle and a curly tail.
	MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.36, -1.02)), Vector3(0.22, 0.05, 0.04), Palette.ABYSS)
	MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.4, 0.05)), Vector3(0.55, 0.12, 0.6), Palette.BERRY)
	MidwayMeshes.ring(tool, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 0.14), Vector3(0.0, 0.25, 0.78)), 1.0, 0.35, dark, MidwayMeshes.PLAIN, 10, 6)


## For Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	return MidwayMeshes.faces_of(self)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)


func _add_shape(shape: Shape3D, at: Vector3) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	_add_part(collision)
