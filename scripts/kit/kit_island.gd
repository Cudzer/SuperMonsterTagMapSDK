@tool
class_name KitIsland
extends KitPiece
## A floating island: a round walkable top with a rock cone hanging below the origin. Only the
## top collides, like the islands map's rocks. Small ones make stepping stones.
##
## With decor on (the default) it's dressed up, all decoration with no collision: a frosting lip
## dripping over the top's edge, a lumpy, layered rock with smaller rocks hanging beside it, and
## an IslandDecor of grass, flowers, pebbles, mushrooms and hanging vines, plus the extras it turns
## on (waterfall, crystals, floating rocks). It's random but the same on every peer (decor_seed).

## Lumps in the rock, as a fraction of its radius.
const ROCK_LUMPINESS: float = 0.12

@export var radius: float = 10.0:
	set(value):
		radius = KitPiece.snap(value)
		queue_build()
@export var thickness: float = 2.0:
	set(value):
		thickness = KitPiece.snap(value)
		queue_build()
## How far the rock hangs below the top; 0 for none.
@export var rock_depth: float = 10.0:
	set(value):
		rock_depth = maxf(snappedf(value, KitPiece.SNAP), 0.0)
		queue_build()
@export var rock_color: KitPiece.Swatch = KitPiece.Swatch.DEEP_TEAL:
	set(value):
		rock_color = value
		queue_build()
@export_range(6, 64) var sides: int = 32:
	set(value):
		sides = value
		queue_build()

@export_group("Decor")
## A cartoon propeller under the rock's tip (or under the top, with no rock), so the island looks
## like it's flying. It's sized from the radius.
@export var propeller: bool = false:
	set(value):
		propeller = value
		queue_build()
@export var propeller_color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST:
	set(value):
		propeller_color = value
		queue_build()
## The frosting edge, the layered rock and the details. Off for a plain island.
@export var decor: bool = true:
	set(value):
		decor = value
		queue_build()
## Which random variation; 0 picks one from where the island is.
@export var decor_seed: int = 0:
	set(value):
		decor_seed = value
		queue_build()
## How much grass, flowers and pebbles grow on top (an icy or muddy top grows none).
@export_range(0.0, 2.0, 0.05) var flora: float = 1.0:
	set(value):
		flora = value
		queue_build()
## Little groups of mushrooms toward the rim (islands of radius 4 and up).
@export var mushrooms: bool = true:
	set(value):
		mushrooms = value
		queue_build()
## A pool by the rim pouring over it, at waterfall_angle.
@export var waterfall: bool = false:
	set(value):
		waterfall = value
		queue_build()
## Where the waterfall pours off: degrees clockwise from -Z (north).
@export_range(0.0, 360.0, 5.0) var waterfall_angle: float = 0.0:
	set(value):
		waterfall_angle = value
		queue_build()
## Glowing crystals growing out of the rock.
@export var crystals: bool = false:
	set(value):
		crystals = value
		queue_build()
@export var crystal_color: KitPiece.Swatch = KitPiece.Swatch.SEAFOAM:
	set(value):
		crystal_color = value
		queue_build()
## Rocks floating round the underside, slowly circling.
@export var debris: bool = false:
	set(value):
		debris = value
		queue_build()
@export_group("")


func _add_parts() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed()
	var top_color: Color = SWATCH_COLORS[color]
	var rock_shade: Color = SWATCH_COLORS[rock_color]
	var dressed_top: bool = decor and surface == Surface.NORMAL
	var center: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, thickness / 2.0, 0))
	if dressed_top:
		_add_island_mesh(IslandMeshes.slab(radius, thickness, sides, top_color, rock_shade.lightened(0.2)))
		_add_island_mesh(IslandMeshes.frosting(radius, thickness, sides, top_color.darkened(0.1), rng))
	else:
		var top: CylinderMesh = CylinderMesh.new()
		top.top_radius = radius
		top.bottom_radius = radius
		top.height = thickness
		top.radial_segments = sides
		top.rings = 1
		add_mesh(top, color, center)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = thickness
	add_shape(shape, center)

	if propeller:
		var prop: IslandPropeller = IslandPropeller.new()
		prop.span = clampf(radius * 1.1, 3.0, 16.0)
		prop.color = propeller_color
		prop.position.y = -rock_depth
		prop.tip_radius = radius * 0.08
		# How fast the rock widens going up from its tip (its profile is steepest there).
		prop.rock_slope = 0.8 * radius * 0.84 / rock_depth if rock_depth > 0.0 else 0.0
		_add_part(prop)

	if rock_depth > 0.0:
		if decor:
			var shades: Array[Color] = [rock_shade, rock_shade.darkened(0.15), rock_shade.lightened(0.1)]
			var segments: int = maxi(sides / 2, 8)
			_add_island_mesh(IslandMeshes.rock(radius * 0.92, rock_depth, radius * 0.08, segments, shades, rng,
					not propeller, ROCK_LUMPINESS))
			# Smaller rocks hanging beside the main one, under the top.
			if radius >= 5.0:
				for index: int in rng.randi_range(1, 3):
					var size: float = radius * rng.randf_range(0.2, 0.32)
					var offset: Vector3 = IslandMeshes.around(rng.randf() * TAU) * minf(radius * rng.randf_range(0.35, 0.6), radius * 0.88 - size)
					var hanging: ArrayMesh = IslandMeshes.rock(size, rock_depth * rng.randf_range(0.35, 0.6), size * 0.1,
							maxi(segments / 2, 6), shades, rng, true, ROCK_LUMPINESS * 1.5)
					_add_island_mesh(hanging, Transform3D(Basis.IDENTITY, offset))
		else:
			var rock: CylinderMesh = CylinderMesh.new()
			rock.top_radius = radius * 0.92
			rock.bottom_radius = radius * 0.08
			rock.height = rock_depth
			rock.radial_segments = maxi(sides / 3, 6)
			rock.rings = 1
			add_mesh(rock, rock_color, Transform3D(Basis.IDENTITY, Vector3(0, -rock_depth / 2.0, 0)), false)

	if decor:
		var details: IslandDecor = IslandDecor.new()
		details.radius = radius
		details.thickness = thickness
		details.rock_depth = rock_depth
		details.top_color = top_color
		details.rock_color = rock_shade
		details.decor_seed = rng.randi()
		details.flora = flora if dressed_top else 0.0
		details.mushrooms = mushrooms and dressed_top
		details.waterfall = waterfall
		details.waterfall_angle = waterfall_angle
		details.crystals = crystals
		details.crystal_color = SWATCH_COLORS[crystal_color]
		details.debris = debris
		_add_part(details)


## The decor's seed: decor_seed, or one from where the island is (the same on every peer).
func _seed() -> int:
	if decor_seed != 0:
		return decor_seed
	var at: Vector3 = global_position if is_inside_tree() else position
	return hash(Vector3i(at.round())) | 1


func _add_island_mesh(mesh: Mesh, at: Transform3D = Transform3D.IDENTITY) -> void:
	var instance: MeshInstance3D = add_mesh(mesh, color, at, false)
	instance.material_override = IslandMeshes.material()
