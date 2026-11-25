@tool
class_name KitFountain
extends KitPiece
## A tiered cartoon fountain: a stone basin, a fluted column through scalloped bowls, and a jet
## spraying from a knob on top. Water spills from bowl to bowl in curtains, spouts round the rim
## arc water into the basin, spray and mist fly where it lands, and it babbles (a synthesized
## loop) to anyone close by.
##
## Like every kit piece it builds its parts when it enters the tree, so scenes store only the
## exports. It's an obstacle, not a play area: one invisible shape round the whole fountain, a
## low wall at the rim then a slope too steep to stand on, so players can't vault in or climb
## it. The water, spray and sound are cosmetic and need no networking. Everything is sized from
## radius (the basin's), and color paints the basin.

## The basin at radius 2.5: the sizes below are for that, and scale with radius.
const BASE_RADIUS: float = 2.5
const SEGMENTS: int = 48
## How see-through the curtains spilling between bowls are, so the stone shows through them.
const CURTAIN_OPACITY: float = 0.4

## The basin's radius; everything else scales with it.
@export var radius: float = 2.5:
	set(value):
		radius = maxf(KitPiece.snap(value), 1.5)
		queue_build()
## Bowls stacked up: 1 is the basin alone, 3 adds a middle and a top bowl.
@export_range(1, 3) var tiers: int = 3:
	set(value):
		tiers = value
		queue_build()
@export var trim_color: KitPiece.Swatch = KitPiece.Swatch.MINT:
	set(value):
		trim_color = value
		queue_build()
@export var column_color: KitPiece.Swatch = KitPiece.Swatch.FROST:
	set(value):
		column_color = value
		queue_build()
@export var accent_color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST:
	set(value):
		accent_color = value
		queue_build()
## Spouts round the rim arcing water into the basin.
@export_range(0, 12) var spouts: int = 6:
	set(value):
		spouts = value
		queue_build()
## Off for a dry fountain: just the stone.
@export var water: bool = true:
	set(value):
		water = value
		queue_build()

## The collision shape's slope: rise per meter in, steeper than a player can stand on (45 degrees)
## or vault onto.
const SLOPE_RISE: float = 1.15
## The fountain babbles this loud, at full volume within SOUND_UNIT_SIZE meters and silent past
## SOUND_RANGE: only round the fountain itself.
const SOUND_VOLUME_DB: float = -6.0
const SOUND_UNIT_SIZE: float = 2.0
const SOUND_RANGE: float = 14.0


func _scale() -> float:
	return radius / BASE_RADIUS


func _add_parts() -> void:
	var s: float = _scale()
	var basin: Color = SWATCH_COLORS[color]
	var trim: Color = SWATCH_COLORS[trim_color]
	var column: Color = SWATCH_COLORS[column_color]
	var accent: Color = SWATCH_COLORS[accent_color]
	var tiles: Array[Color] = [Palette.TEAL, Palette.TEAL.lightened(0.12)]
	var stone: SurfaceTool = SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STONE_LOOK: Vector2 = Vector2(0.4, 0.0)

	# The basin: a tiled floor, the inner wall, a rounded rim, striped outer panels and a plinth.
	IslandMeshes.lathe(stone, _scaled([
		Vector3(0.0, 0.15, 0.0), Vector3(2.18, 0.15, 0.0), Vector3(2.18, 0.42, 0.0), Vector3(2.24, 0.5, 0.0),
		Vector3(2.36, 0.54, 0.0), Vector3(2.5, 0.51, 0.0), Vector3(2.55, 0.43, 0.0), Vector3(2.47, 0.38, 0.0),
		Vector3(2.47, 0.12, 0.0), Vector3(2.6, 0.08, 0.0), Vector3(2.6, 0.0, 0.0),
	], s), SEGMENTS, [tiles, trim.darkened(0.08), trim, trim, trim, trim, trim.darkened(0.15),
		[basin, basin.lightened(0.15)], basin.darkened(0.15), basin.darkened(0.15)], STONE_LOOK)

	# The knob (and the jet) sit on the highest water: the basin's floor, or a bowl's.
	var top_floor: float = 0.15
	if tiers >= 2:
		_add_column(stone, 0.15, 1.3, 0.22, trim, column, s)
		_add_bowl(stone, 1.25, 1.3, 1.62, trim, column, accent, s)
		top_floor = 1.62
	if tiers >= 3:
		_add_column(stone, 1.62, 2.48, 0.14, trim, column, s)
		_add_bowl(stone, 0.55, 2.48, 2.6, trim, column, accent, s)
		top_floor = 2.6
	IslandMeshes.lathe(stone, _scaled([
		Vector3(0.0, top_floor + 0.42, 0.0), Vector3(0.07, top_floor + 0.39, 0.0), Vector3(0.13, top_floor + 0.3, 0.0),
		Vector3(0.14, top_floor + 0.2, 0.0), Vector3(0.1, top_floor + 0.08, 0.0), Vector3(0.09, top_floor, 0.0),
	], s), 16, [accent, accent, accent, accent.darkened(0.1), accent.darkened(0.1)], STONE_LOOK)
	# Spout knobs round the rim.
	var spout_tool: SurfaceTool = IslandMeshes.flat_tool()
	var knob_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	knob_rng.seed = 3
	for spout: int in spouts:
		var out: Vector3 = IslandMeshes.around(TAU * (spout + 0.5) / spouts)
		IslandMeshes.add_lump(spout_tool, out * 2.36 * s + Vector3.UP * 0.58 * s, Vector3(0.11, 0.09, 0.11) * s, accent, knob_rng)

	var stone_mesh: ArrayMesh = stone.commit()
	var stone_instance: MeshInstance3D = add_mesh(stone_mesh, color, Transform3D.IDENTITY, false)
	stone_instance.material_override = IslandMeshes.material()
	add_shape(_collision_shape(top_floor, s))
	if spouts > 0:
		var knobs: MeshInstance3D = add_mesh(IslandMeshes.commit_flat(spout_tool), color, Transform3D.IDENTITY, false)
		knobs.material_override = IslandMeshes.material()

	if water:
		_add_water(top_floor, s)


## One convex shape round the whole fountain: up the basin's outside to its rim, then a slope
## (SLOPE_RISE, too steep to stand on or vault onto) in to the highest bowl's rim, and up to the
## knob. Anyone landing on it slides off, so nobody gets into the water.
func _collision_shape(top_floor: float, s: float) -> ConvexPolygonShape3D:
	const OUTER: float = 2.6
	const RIM: float = 0.54
	# The highest bowl's rim (its scallops included), or the knob with no bowls.
	var top_radius: float = 0.15
	var top_height: float = top_floor + 0.42
	if tiers >= 3:
		top_radius = 0.64
		top_height = 2.77
	elif tiers >= 2:
		top_radius = 1.44
		top_height = 1.85
	top_height = maxf(top_height, RIM + (OUTER - top_radius) * SLOPE_RISE)
	var points: PackedVector3Array = PackedVector3Array()
	const SIDES: int = 24
	for side: int in SIDES:
		var out: Vector3 = IslandMeshes.around(TAU * side / SIDES)
		points.append(out * OUTER * s)
		points.append(out * OUTER * s + Vector3.UP * RIM * s)
		points.append(out * top_radius * s + Vector3.UP * top_height * s)
	points.append(Vector3.UP * maxf(top_floor + 0.42, top_height) * s)
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## A fluted column from [param bottom] to [param top], [param thickness] round its shaft.
func _add_column(tool: SurfaceTool, bottom: float, top: float, thickness: float, trim: Color, column: Color, s: float) -> void:
	var r: float = thickness
	IslandMeshes.lathe(tool, _scaled([
		Vector3(r * 1.35, top, 0.0), Vector3(r * 1.1, top - 0.08, 0.0), Vector3(r, top - 0.18, 0.1),
		Vector3(r, bottom + 0.19, 0.1), Vector3(r * 1.1, bottom + 0.11, 0.0), Vector3(r * 1.55, bottom + 0.07, 0.0),
		Vector3(r * 1.65, bottom, 0.0),
	], s), SEGMENTS, [trim, column, column, column, trim, trim], Vector2(0.4, 0.0), 10)


## A scalloped bowl of [param bowl_radius], hung from [param underside] with its floor at
## [param floor_height].
func _add_bowl(tool: SurfaceTool, bowl_radius: float, underside: float, floor_height: float, trim: Color,
		column: Color, accent: Color, s: float) -> void:
	var r: float = bowl_radius
	var rim: float = floor_height + 0.18 * minf(r, 1.0) + 0.05
	IslandMeshes.lathe(tool, _scaled([
		Vector3(0.0, floor_height, 0.0), Vector3(r - 0.15 * r, floor_height, 0.0), Vector3(r - 0.12 * r, rim - 0.05, 0.0),
		Vector3(r - 0.05 * r, rim + 0.02, 0.06), Vector3(r + 0.05 * r, rim, 0.08), Vector3(r + 0.06 * r, rim - 0.09, 0.08),
		Vector3(r * 0.8, floor_height - 0.1, 0.05), Vector3(r * 0.48, underside + 0.08, 0.02), Vector3(r * 0.24, underside, 0.0),
	], s), SEGMENTS, [trim.lightened(0.1), trim, accent, accent, accent.darkened(0.1),
		[column, column.darkened(0.08)], [column, column.darkened(0.08)], column.darkened(0.08)], Vector2(0.4, 0.0), 8)


## The pools, the curtains between them, the jet and the spout arcs, the spray and mist, and the
## sound.
func _add_water(top_floor: float, s: float) -> void:
	var basin_water: float = 0.4 * s
	_add_water_part(IslandMeshes.water_disc(2.18 * s, SEGMENTS), Vector3.UP * basin_water, 0.15, 0.0, 1.0)
	if tiers >= 2:
		_add_water_part(IslandMeshes.water_disc(1.08 * s, 32), Vector3.UP * 1.75 * s, 0.2, 0.0, 1.0)
		_add_water_part(IslandMeshes.water_curtain(1.33 * s, 1.83 * s, 1.75 * s, basin_water), Vector3.ZERO, 1.2, 1.0, 0.0, CURTAIN_OPACITY)
		_add_mist_ring(1.72 * s, basin_water, s)
	if tiers >= 3:
		_add_water_part(IslandMeshes.water_disc(0.47 * s, 24), Vector3.UP * 2.72 * s, 0.2, 0.0, 1.0)
		_add_water_part(IslandMeshes.water_curtain(0.59 * s, 2.77 * s, 0.85 * s, 1.75 * s, 24), Vector3.ZERO, 1.2, 1.0, 0.0, CURTAIN_OPACITY)
		_add_mist_ring(0.85 * s, 1.75 * s, s * 0.6)
	# The jet: up out of the knob, fading at the top, with spray falling back.
	var jet_bottom: float = (top_floor + 0.4) * s
	var jet_top: float = jet_bottom + 0.85 * s
	_add_water_part(IslandMeshes.water_tube(PackedVector3Array([Vector3.UP * jet_bottom, Vector3.UP * jet_top]), 0.08 * s, 0.04 * s, 10),
			Vector3.ZERO, 1.6, 1.0, 0.0, 0.75)
	_add_spray(Vector3.UP * jet_top, s)
	# Spout arcs, up and over into the basin.
	for spout: int in spouts:
		var out: Vector3 = IslandMeshes.around(TAU * (spout + 0.5) / spouts)
		var from: Vector3 = out * 2.3 * s + Vector3.UP * 0.62 * s
		var to: Vector3 = out * 0.8 * s + Vector3.UP * basin_water
		var points: PackedVector3Array = PackedVector3Array()
		for step: int in 11:
			var t: float = step / 10.0
			points.append(from.lerp(to, t) + Vector3.UP * 4.0 * 0.75 * s * t * (1.0 - t))
		_add_water_part(IslandMeshes.water_tube(points, 0.05 * s, 0.035 * s, 8), Vector3.ZERO, 1.6, 0.4, 0.0, 0.8)

	if Engine.is_editor_hint():
		return
	var babble: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	babble.stream = Sound.fountain_stream()
	babble.position = Vector3.UP * 1.2 * s
	babble.unit_size = SOUND_UNIT_SIZE
	babble.max_distance = SOUND_RANGE
	babble.volume_db = SOUND_VOLUME_DB
	babble.bus = &"SFX"
	_add_part(babble)
	babble.play()


func _add_water_part(mesh: Mesh, at: Vector3, flow: float, fade: float, edges: float, opacity: float = 0.95) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = IslandMeshes.water_material()
	instance.set_instance_shader_parameter(&"flow", flow)
	instance.set_instance_shader_parameter(&"fade", fade)
	instance.set_instance_shader_parameter(&"edges", edges)
	instance.set_instance_shader_parameter(&"opacity", opacity)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_part(instance)


## Droplets thrown up from the jet's top and falling back into the top bowl.
func _add_spray(at: Vector3, s: float) -> void:
	var spray: GPUParticles3D = GPUParticles3D.new()
	spray.amount = 28
	spray.lifetime = 0.9
	spray.position = at
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 1.2 * s
	process.initial_velocity_max = 2.2 * s
	process.gravity = Vector3.DOWN * 9.8 * s
	process.scale_min = 0.6
	process.scale_max = 1.0
	process.color_ramp = _fade_ramp(Palette.FROST, 0.9)
	spray.process_material = process
	spray.draw_pass_1 = _puff_quad(0.12 * s)
	_add_part(spray)


## Mist puffing up all round where a curtain lands.
func _add_mist_ring(ring_radius: float, height: float, s: float) -> void:
	var mist: GPUParticles3D = GPUParticles3D.new()
	mist.amount = 24
	mist.lifetime = 0.9
	mist.position = Vector3.UP * height
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = ring_radius
	process.emission_ring_inner_radius = ring_radius * 0.92
	process.emission_ring_height = 0.02
	process.direction = Vector3.UP
	process.spread = 30.0
	process.initial_velocity_min = 0.3 * s
	process.initial_velocity_max = 0.6 * s
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.2
	process.color_ramp = _fade_ramp(Palette.FROST, 0.5)
	mist.process_material = process
	mist.draw_pass_1 = _puff_quad(0.35 * s)
	_add_part(mist)


static func _puff_quad(size: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = IslandMeshes.puff_material()
	return quad


## [param tint] at [param alpha], fading to nothing over a particle's life.
static func _fade_ramp(tint: Color, alpha: float) -> GradientTexture1D:
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.set_color(0, Color(tint, alpha))
	ramp.gradient.set_color(1, Color(tint, 0.0))
	return ramp



static func _scaled(points: Array[Vector3], s: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(point.x * s, point.y * s, point.z))
	return result
