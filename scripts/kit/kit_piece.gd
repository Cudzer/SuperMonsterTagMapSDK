@tool
@abstract
class_name KitPiece
extends StaticBody3D
## Base for the level kit: solid, collidable shapes in the Palette's colors, sized by a few
## exports that snap to SNAP meters. Each piece generates its meshes and collision shapes as
## internal children whenever it enters the tree (in the editor and in game), so map scenes only
## store the exports. A piece's origin is the center of its footprint, on its base; pieces that
## have a direction (ramps, stairs) rise toward their forward axis (-Z).

## Swatches a piece can be painted with. Saved in map scenes by index, so only append.
enum Swatch { TEAL, SEAFOAM, MINT, LAGOON, DEEP_TEAL, ABYSS, CORAL, SUNBURST, BERRY, SAND, MOSS, LILAC, FROST, SKY, BRICK, ASPHALT, CREAM }

const SWATCH_COLORS: Array[Color] = [
	Palette.TEAL, Palette.SEAFOAM, Palette.MINT, Palette.LAGOON, Palette.DEEP_TEAL, Palette.ABYSS,
	Palette.CORAL, Palette.SUNBURST, Palette.BERRY, Palette.SAND, Palette.MOSS, Palette.LILAC,
	Palette.FROST, Palette.SKY, Palette.BRICK, Palette.ASPHALT, Palette.CREAM,
]
## How a piece's top plays (Player reads it from the floor it stands on). ICE keeps your momentum
## and turns slowly, MUD slows you down. Saved by index, so only append.
enum Surface { NORMAL, ICE, MUD }
## How a piece's top is textured (assets/shaders/ground_finish.gdshader), in its swatch's colour;
## WALLPAPER papers its sides instead.
## Looks only: it plays like any NORMAL surface. Saved by index, so only append.
enum Finish { PLAIN, ASPHALT, GRASS, PAVING, SIDEWALK, DIRT, WOOD, RUG, WALLPAPER }

## Sizes snap to this many meters.
const SNAP: float = 0.5

@export var color: Swatch = Swatch.TEAL:
	set(value):
		color = value
		queue_build()
## ICE and MUD replace the swatch with their own look.
@export var surface: Surface = Surface.NORMAL:
	set(value):
		surface = value
		queue_build()
## Textures the top (ICE and MUD win over it).
@export var finish: Finish = Finish.PLAIN:
	set(value):
		finish = value
		queue_build()

const FINISH_SHADER: Shader = preload("res://assets/shaders/ground_finish.gdshader")

## One shared material per swatch, so pieces of a color batch together.
static var _materials: Dictionary[int, StandardMaterial3D] = {}
static var _surface_materials: Dictionary[int, StandardMaterial3D] = {}
static var _finish_materials: Dictionary[int, ShaderMaterial] = {}

var _parts: Array[Node] = []
var _build_queued: bool = false


func _ready() -> void:
	build()


## Rebuilds the meshes and shapes at the end of the frame, once per batch of export changes.
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
	_add_parts()
	# Level Tools' kit gizmo makes the new meshes clickable in the editor.
	if Engine.is_editor_hint():
		update_gizmos()


## Subclasses add their look and collision here with add_mesh() and add_shape().
@abstract func _add_parts() -> void


## [param surfaced] parts take the piece's ICE or MUD look or its finish; others (an island's rock)
## keep the swatch.
func add_mesh(mesh: Mesh, swatch: Swatch, at: Transform3D = Transform3D.IDENTITY, surfaced: bool = true) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	if surfaced and surface != Surface.NORMAL:
		instance.material_override = surface_material(surface)
	elif surfaced and finish != Finish.PLAIN:
		instance.material_override = finish_material(finish)
		var bounds: AABB = mesh.get_aabb()
		instance.set_instance_shader_parameter(&"base_color", SWATCH_COLORS[swatch])
		instance.set_instance_shader_parameter(&"box_center", bounds.get_center())
		instance.set_instance_shader_parameter(&"box_half", bounds.size * 0.5)
	else:
		instance.material_override = material_for(swatch)
	instance.transform = at
	_add_part(instance)
	return instance


func add_shape(shape: Shape3D, at: Transform3D = Transform3D.IDENTITY) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.transform = at
	_add_part(collision)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
	_parts.append(part)


static func material_for(swatch: Swatch) -> StandardMaterial3D:
	if not _materials.has(swatch):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = SWATCH_COLORS[swatch]
		_materials[swatch] = material
	return _materials[swatch]


## One shared material per surface: glossy Frost ice, and mud blotched with world-space noise.
static func surface_material(kind: Surface) -> StandardMaterial3D:
	if not _surface_materials.has(kind):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		if kind == Surface.ICE:
			material.albedo_color = Palette.FROST.lerp(Palette.SKY, 0.3)
			material.roughness = 0.08
			material.metallic_specular = 1.0
			material.clearcoat_enabled = true
			material.rim_enabled = true
			material.rim = 0.4
		else:
			var noise: FastNoiseLite = FastNoiseLite.new()
			noise.frequency = 0.05
			var blotches: NoiseTexture2D = NoiseTexture2D.new()
			blotches.noise = noise
			blotches.seamless = true
			var ramp: Gradient = Gradient.new()
			ramp.set_color(0, Palette.MUD.darkened(0.25))
			ramp.set_color(1, Palette.MUD.lightened(0.12))
			blotches.color_ramp = ramp
			material.albedo_texture = blotches
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
			material.uv1_scale = Vector3.ONE * 0.25
			material.roughness = 1.0
		_surface_materials[kind] = material
	return _surface_materials[kind]


## One shared material per finish; the colour and footprint are per instance.
static func finish_material(kind: Finish) -> ShaderMaterial:
	if not _finish_materials.has(kind):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FINISH_SHADER
		material.set_shader_parameter(&"finish", int(kind))
		_finish_materials[kind] = material
	return _finish_materials[kind]


static func snap(value: float) -> float:
	return maxf(snappedf(value, SNAP), SNAP)


static func snap_vector(value: Vector3) -> Vector3:
	return Vector3(snap(value.x), snap(value.y), snap(value.z))


## A flat-shaded mesh of a convex solid. [param faces] are lists of point indices around each
## face, in either order: each triangle is turned to face away from the solid's center, and
## faces that collapse to nothing (e.g. a ramp's zero-height front) are skipped.
static func polyhedron(points: PackedVector3Array, faces: Array[Array]) -> ArrayMesh:
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		center += point / points.size()
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces:
		for corner: int in range(1, face.size() - 1):
			var a: Vector3 = points[face[0]]
			var b: Vector3 = points[face[corner]]
			var c: Vector3 = points[face[corner + 1]]
			var normal: Vector3 = (b - a).cross(c - a)
			if normal.length_squared() < 0.000001:
				continue
			if normal.dot((a + b + c) / 3.0 - center) < 0.0:
				normal = -normal
				var swap: Vector3 = b
				b = c
				c = swap
			builder.set_normal(normal.normalized())
			# Godot's front faces are clockwise seen from outside, the reverse of the normal's winding.
			builder.add_vertex(a)
			builder.add_vertex(c)
			builder.add_vertex(b)
	return builder.commit()
