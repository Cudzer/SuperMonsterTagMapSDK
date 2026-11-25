@tool
class_name KitBuilding
extends KitPiece
## A town building: a box whose walls are painted with rows of windows (some lit, a storefront
## along the ground floor, trim bands; assets/shaders/building.gdshader), a flat roof with a low
## parapet you just step over, and props on the roof: AC units and a roof hut you can climb, a
## chimney, an antenna, and a water tower.
##
## The walls are one box, so a building collides as one: wall-run its sides, vault onto it, run
## across its roof. color paints the walls and trim_color the trim. Like every kit piece it builds
## its parts on entering the tree; the props come from prop_seed (or where it stands), so every peer
## and the editor build the same roof.

## The parapet: low enough to step over (Player.vault_step_height is 0.4).
const PARAPET_HEIGHT: float = 0.3
const PARAPET_THICKNESS: float = 0.3

const SHADER: Shader = preload("res://assets/shaders/building.gdshader")
static var _material: ShaderMaterial

## Width, height and depth (m).
@export var size: Vector3 = Vector3(8, 8, 8):
	set(value):
		size = KitPiece.snap_vector(value)
		queue_build()
@export var trim_color: Swatch = Swatch.CREAM:
	set(value):
		trim_color = value
		queue_build()
## Shop windows along the ground floor.
@export var storefront: bool = true:
	set(value):
		storefront = value
		queue_build()
@export var parapet: bool = true:
	set(value):
		parapet = value
		queue_build()
## AC units, a chimney, an antenna and (on a big enough roof) a roof hut. Turn off for a clear roof.
@export var roof_props: bool = true:
	set(value):
		roof_props = value
		queue_build()
@export var water_tower: bool = false:
	set(value):
		water_tower = value
		queue_build()
## Which arrangement of roof props; 0 picks one from where the building stands.
@export var prop_seed: int = 0:
	set(value):
		prop_seed = value
		queue_build()


func _init() -> void:
	color = Swatch.BRICK


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


func _add_parts() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed()
	var walls: BoxMesh = BoxMesh.new()
	walls.size = size
	var center: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0, 0))
	var wall_instance: MeshInstance3D = add_mesh(walls, color, center, false)
	wall_instance.material_override = material()
	wall_instance.set_instance_shader_parameter(&"wall_color", SWATCH_COLORS[color])
	wall_instance.set_instance_shader_parameter(&"trim_color", SWATCH_COLORS[trim_color])
	wall_instance.set_instance_shader_parameter(&"size", size)
	wall_instance.set_instance_shader_parameter(&"seed", float(rng.randi() % 1000))
	wall_instance.set_instance_shader_parameter(&"storefront", 1.0 if storefront else 0.0)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	add_shape(shape, center)

	if parapet:
		var half: Vector2 = Vector2(size.x, size.z) * 0.5
		var y: float = size.y + PARAPET_HEIGHT * 0.5
		var t: float = PARAPET_THICKNESS
		for side: Array in [
			[Vector3(size.x, PARAPET_HEIGHT, t), Vector3(0, y, -half.y + t * 0.5)],
			[Vector3(size.x, PARAPET_HEIGHT, t), Vector3(0, y, half.y - t * 0.5)],
			[Vector3(t, PARAPET_HEIGHT, size.z - t * 2.0), Vector3(-half.x + t * 0.5, y, 0)],
			[Vector3(t, PARAPET_HEIGHT, size.z - t * 2.0), Vector3(half.x - t * 0.5, y, 0)],
		]:
			_add_box(side[0], side[1], trim_color, true)

	if roof_props and size.x >= 5.0 and size.z >= 5.0:
		_add_roof_props(rng)


## A box of [param box_size] centered at [param at], painted [param swatch], solid if [param solid].
func _add_box(box_size: Vector3, at: Vector3, swatch: Swatch, solid: bool) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	add_mesh(box, swatch, Transform3D(Basis.IDENTITY, at), false)
	if solid:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		add_shape(shape, Transform3D(Basis.IDENTITY, at))


func _add_cylinder(radius: float, height: float, at: Vector3, swatch: Swatch, solid: bool, top_radius: float = -1.0) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.bottom_radius = radius
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	add_mesh(cylinder, swatch, Transform3D(Basis.IDENTITY, at), false)
	if solid:
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		add_shape(shape, Transform3D(Basis.IDENTITY, at))


## Props in the roof's corners, each corner used once: AC units, a chimney, a roof hut, and the
## water tower if there is one; an antenna on one of them.
func _add_roof_props(rng: RandomNumberGenerator) -> void:
	var roof: float = size.y
	var margin: float = PARAPET_THICKNESS + 0.9
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	# Shuffle the corners the same way every time.
	for index: int in range(corners.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Vector2 = corners[index]
		corners[index] = corners[other]
		corners[other] = swap
	var reach: Vector2 = Vector2(size.x, size.z) * 0.5 - Vector2.ONE * margin
	var next: int = 0
	if water_tower and size.x >= 6.0 and size.z >= 6.0:
		var at: Vector2 = corners[next] * (reach - Vector2.ONE * 0.6)
		next += 1
		for leg: Vector2 in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)]:
			_add_cylinder(0.08, 2.4, Vector3(at.x + leg.x, roof + 1.2, at.y + leg.y), Swatch.ASPHALT, false)
		_add_cylinder(1.25, 2.0, Vector3(at.x, roof + 3.4, at.y), Swatch.SAND, true)
		_add_cylinder(1.35, 0.9, Vector3(at.x, roof + 4.85, at.y), Swatch.BERRY, false, 0.1)
	# AC units: a row of one to three along the roof edge.
	var ac_corner: Vector2 = corners[next]
	next += 1
	for unit: int in rng.randi_range(1, 3):
		var at: Vector2 = ac_corner * reach - Vector2(ac_corner.x * unit * 1.5, 0.0)
		_add_box(Vector3(1.2, 0.9, 1.0), Vector3(at.x, roof + 0.45, at.y), Swatch.FROST, true)
		_add_cylinder(0.35, 0.05, Vector3(at.x, roof + 0.92, at.y), Swatch.ASPHALT, false)
	# A chimney with a cap.
	var chimney: Vector2 = corners[next] * reach
	next += 1
	_add_box(Vector3(0.8, 1.6, 0.8), Vector3(chimney.x, roof + 0.8, chimney.y), color, true)
	_add_box(Vector3(1.0, 0.15, 1.0), Vector3(chimney.x, roof + 1.67, chimney.y), trim_color, true)
	# A roof hut (the stairs down) on a big enough roof, else an antenna.
	var last: Vector2 = corners[next]
	if size.x >= 9.0 and size.z >= 9.0:
		var hut: Vector2 = last * (reach - Vector2.ONE * 0.6)
		_add_box(Vector3(2.4, 2.2, 2.4), Vector3(hut.x, roof + 1.1, hut.y), trim_color, true)
		_add_box(Vector3(2.6, 0.2, 2.6), Vector3(hut.x, roof + 2.3, hut.y), color, true)
		# Its door faces the middle of the roof.
		var facing: Vector3 = Vector3(-last.x, 0, 0) if absf(hut.x) > absf(hut.y) else Vector3(0, 0, -last.y)
		_add_box(Vector3(0.9 if facing.x == 0.0 else 0.05, 1.7, 0.05 if facing.x == 0.0 else 0.9),
				Vector3(hut.x, roof + 0.85, hut.y) + facing * 1.21, Swatch.ASPHALT, false)
	else:
		var mast: Vector2 = last * reach
		_add_cylinder(0.05, 3.0, Vector3(mast.x, roof + 1.5, mast.y), Swatch.ASPHALT, false)
		_add_box(Vector3(1.0, 0.05, 0.05), Vector3(mast.x, roof + 2.6, mast.y), Swatch.ASPHALT, false)
		_add_box(Vector3(0.6, 0.05, 0.05), Vector3(mast.x, roof + 2.9, mast.y), Swatch.ASPHALT, false)


## The props' seed: prop_seed, or one from where the building stands.
func _seed() -> int:
	if prop_seed != 0:
		return prop_seed
	var at: Vector3 = global_position if is_inside_tree() else position
	return hash(Vector3i(at.round())) | 1
