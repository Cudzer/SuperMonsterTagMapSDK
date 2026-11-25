@tool
class_name IslandMeshes
## Builders for the generated island meshes: KitIsland's slab, frosting and rock, and IslandDecor's
## details. Every one carries Palette colours as vertex colours and uses material(), so islands
## batch. UV2 is the look (assets/shaders/island.gdshader): x is how blotchy a surface is drawn, y
## how much it glows.
##
## Surfaces of revolution (slab, frosting, rock) are built from a profile running from the top
## (or the inside) outward and down, around increasing angle; that order faces them outward.

const SHADER: Shader = preload("res://assets/shaders/island.gdshader")

## Looks (UV2): blotchy ground, partly blotchy rock and soil, plain, glowing.
const GROUND: Vector2 = Vector2(1.0, 0.0)
const ROCK: Vector2 = Vector2(0.6, 0.0)
const PLAIN: Vector2 = Vector2.ZERO
const GLOW: Vector2 = Vector2(0.0, 0.8)

## The twelve corners and twenty faces of an icosahedron, for pebbles and floating rocks.
const ICO_T: float = 1.618034
const ICO_POINTS: Array[Vector3] = [
	Vector3(-1, ICO_T, 0), Vector3(1, ICO_T, 0), Vector3(-1, -ICO_T, 0), Vector3(1, -ICO_T, 0),
	Vector3(0, -1, ICO_T), Vector3(0, 1, ICO_T), Vector3(0, -1, -ICO_T), Vector3(0, 1, -ICO_T),
	Vector3(ICO_T, 0, -1), Vector3(ICO_T, 0, 1), Vector3(-ICO_T, 0, -1), Vector3(-ICO_T, 0, 1),
]
const ICO_FACES: Array[Vector3i] = [
	Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
	Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
	Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
	Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
]

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


static func flat_tool() -> SurfaceTool:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Faceted: every triangle gets its own normal.
	tool.set_smooth_group(-1)
	return tool


## Finishes a flat_tool() mesh (normals from its faces).
static func commit_flat(tool: SurfaceTool) -> ArrayMesh:
	tool.generate_normals()
	return tool.commit()


static func vertex(tool: SurfaceTool, at: Vector3, color: Color, look: Vector2) -> void:
	tool.set_color(color)
	tool.set_uv2(look)
	tool.add_vertex(at)


## A triangle facing the side it's clockwise from.
static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, look: Vector2) -> void:
	vertex(tool, a, color, look)
	vertex(tool, b, color, look)
	vertex(tool, c, color, look)


static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, look: Vector2) -> void:
	triangle(tool, a, b, c, color, look)
	triangle(tool, a, c, d, color, look)


## Out from the island's center at [param angle] (radians, around +Y from +X toward +Z).
static func around(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


## The walkable slab: a smooth disc on top in [param top_color] (blotchy), its side in
## [param side_color], and the underside.
static func slab(radius: float, thickness: float, sides: int, top_color: Color, side_color: Color) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = Vector3.UP * thickness
	for index: int in sides:
		var a: Vector3 = around(TAU * index / sides)
		var b: Vector3 = around(TAU * (index + 1) / sides)
		tool.set_normal(Vector3.UP)
		triangle(tool, top, top + a * radius, top + b * radius, top_color, GROUND)
		for corner: Array in [[a, top], [a, Vector3.ZERO], [b, Vector3.ZERO], [a, top], [b, Vector3.ZERO], [b, top]]:
			tool.set_normal(corner[0])
			vertex(tool, corner[0] * radius + corner[1], side_color, ROCK)
		tool.set_normal(Vector3.DOWN)
		triangle(tool, Vector3.ZERO, b * radius, a * radius, side_color, PLAIN)
	return tool.commit()


## The frosting: a rounded lip round the slab's top edge, standing a few centimeters proud and
## overhanging, that drips down its side in uneven drips (some past the slab).
static func frosting(radius: float, thickness: float, sides: int, color: Color, rng: RandomNumberGenerator) -> ArrayMesh:
	var segments: int = maxi(sides * 3, 48)
	var lengths: PackedFloat32Array = PackedFloat32Array()
	lengths.resize(segments)
	lengths.fill(0.16)
	for drip: int in int(radius * 1.4) + 4:
		var center: int = rng.randi_range(0, segments - 1)
		var half_width: int = rng.randi_range(1, 3)
		var extra: float = rng.randf_range(0.15, 0.5 + thickness * 0.6)
		for offset: int in range(-half_width, half_width + 1):
			var shape: float = cos(float(offset) / (half_width + 1) * PI * 0.5)
			var at: int = posmod(center + offset, segments)
			lengths[at] = maxf(lengths[at], 0.16 + extra * pow(shape, 1.5))
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROWS: int = 7
	for index: int in segments:
		var out: Vector3 = around(TAU * index / segments)
		var length: float = lengths[index]
		var profile: Array[Vector3] = [
			out * (radius - 0.4) + Vector3.UP * (thickness + 0.012),
			out * (radius - 0.1) + Vector3.UP * (thickness + 0.05),
			out * (radius + 0.08) + Vector3.UP * thickness,
			out * (radius + 0.13) + Vector3.UP * (thickness - 0.12),
			out * (radius + 0.11) + Vector3.UP * (thickness - length * 0.7),
			out * (radius + 0.06) + Vector3.UP * (thickness - length),
			out * radius + Vector3.UP * (thickness - length - 0.04),
		]
		for row: int in ROWS:
			vertex(tool, profile[row], color, GROUND if row < 3 else ROCK)
	for index: int in segments:
		var next: int = (index + 1) % segments
		for row: int in ROWS - 1:
			var a: int = index * ROWS + row
			var b: int = index * ROWS + row + 1
			var c: int = next * ROWS + row + 1
			var d: int = next * ROWS + row
			for corner: int in [a, b, c, a, c, d]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A hanging rock: faceted rings from [param top_radius] at y 0 down to [param tip_radius] at
## -[param depth], lumpy, in bands of [param colors] with a small ledge between bands. A
## [param pointed] rock ends in a point; otherwise in a flat cap (where a propeller's collar goes),
## with the last rings left smooth so the collar and band fit it.
static func rock(top_radius: float, depth: float, tip_radius: float, segments: int, colors: Array[Color],
		rng: RandomNumberGenerator, pointed: bool, lumpiness: float = 0.12) -> ArrayMesh:
	var ring_count: int = clampi(roundi(depth / 1.1), 3, 14)
	var band_count: int = clampi(roundi(depth / 2.5), 1, 6)
	# Each ring: [y, radius per segment, angle offset per segment, band].
	var rings: Array[Dictionary] = []
	for ring: int in ring_count + 1:
		var t: float = float(ring) / ring_count
		var radius: float = lerpf(top_radius, tip_radius, pow(t, 0.8))
		var band: int = mini(int(t * band_count), band_count - 1)
		var smooth: bool = ring == ring_count or (not pointed and ring >= ring_count - 1)
		var radii: PackedFloat32Array = PackedFloat32Array()
		var turns: PackedFloat32Array = PackedFloat32Array()
		for segment: int in segments:
			var lump: float = 0.0 if smooth else rng.randf_range(-lumpiness, lumpiness)
			# The top ring stays under the slab.
			radii.append(radius * (1.0 + (minf(lump, 0.0) - 0.04 if ring == 0 else lump)))
			turns.append(0.0 if smooth or ring == 0 else rng.randf_range(-0.25, 0.25))
		rings.append({"y": -depth * t, "radii": radii, "turns": turns, "band": band})
		# A ledge where a band starts: the next ring steps in a little, just below.
		var next_band: int = mini(int(float(ring + 1) / ring_count * band_count), band_count - 1)
		if ring > 0 and ring < ring_count - 1 and next_band != band and t < 0.8:
			var inset: PackedFloat32Array = PackedFloat32Array()
			for value: float in radii:
				inset.append(value * 0.88)
			rings.append({"y": -depth * t - 0.08, "radii": inset, "turns": turns, "band": next_band, "ledge": true})
	var tool: SurfaceTool = flat_tool()
	for ring: int in rings.size() - 1:
		var upper: Dictionary = rings[ring]
		var lower: Dictionary = rings[ring + 1]
		var color: Color = colors[(lower["band"] as int) % colors.size()]
		if lower.get("ledge", false):
			color = color.darkened(0.15)
		for segment: int in segments:
			var next: int = (segment + 1) % segments
			quad(tool, _ring_point(upper, segment, segments), _ring_point(lower, segment, segments),
					_ring_point(lower, next, segments), _ring_point(upper, next, segments), color, ROCK)
	var last: Dictionary = rings[rings.size() - 1]
	var bottom_color: Color = colors[(last["band"] as int) % colors.size()]
	var tip: Vector3 = Vector3.UP * ((last["y"] as float) - (tip_radius * 2.5 + 0.3 if pointed else 0.0))
	for segment: int in segments:
		var next: int = (segment + 1) % segments
		var a: Vector3 = _ring_point(last, segment, segments)
		var b: Vector3 = _ring_point(last, next, segments)
		triangle(tool, a, tip, b, bottom_color, ROCK)
	return commit_flat(tool)


static func _ring_point(ring: Dictionary, segment: int, segments: int) -> Vector3:
	var angle: float = TAU * (segment + (ring["turns"] as PackedFloat32Array)[segment]) / segments
	return around(angle) * (ring["radii"] as PackedFloat32Array)[segment] + Vector3.UP * (ring["y"] as float)


## A tube through [param points], [param start_radius] thick at the first and tapering to
## [param end_radius]; for vines and roots.
static func add_tube(tool: SurfaceTool, points: PackedVector3Array, start_radius: float, end_radius: float,
		color: Color, sides: int = 4) -> void:
	var rings: Array[PackedVector3Array] = []
	for index: int in points.size():
		var along: Vector3 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var side: Vector3 = along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
		# So that going round the ring and along the tube faces it outward.
		var up: Vector3 = along.cross(side)
		var radius: float = lerpf(start_radius, end_radius, float(index) / (points.size() - 1))
		var ring: PackedVector3Array = PackedVector3Array()
		for corner: int in sides:
			var angle: float = TAU * corner / sides
			ring.append(points[index] + (side * cos(angle) + up * sin(angle)) * radius)
		rings.append(ring)
	for index: int in rings.size() - 1:
		for corner: int in sides:
			var next: int = (corner + 1) % sides
			quad(tool, rings[index][corner], rings[index + 1][corner], rings[index + 1][next], rings[index][next], color, PLAIN)


## A flat leaf (both sides) at [param at], pointing along [param toward].
static func add_leaf(tool: SurfaceTool, at: Vector3, toward: Vector3, size: float, color: Color) -> void:
	var along: Vector3 = toward.normalized() * size
	var side: Vector3 = along.cross(Vector3.UP).normalized() * size * 0.35
	if side.length() < 0.001:
		side = Vector3.RIGHT * size * 0.35
	var tip: Vector3 = at + along
	var middle: Vector3 = at + along * 0.5
	for pair: Array in [[side, -side], [-side, side]]:
		triangle(tool, at, middle + (pair[0] as Vector3), tip, color, PLAIN)
		triangle(tool, at, tip, middle + (pair[1] as Vector3), color, PLAIN)


## A six-sided crystal growing from [param base] along [param toward]: a prism, then a point.
static func add_crystal(tool: SurfaceTool, base: Vector3, toward: Vector3, length: float, width: float, color: Color) -> void:
	var along: Vector3 = toward.normalized()
	var side: Vector3 = along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
	var up: Vector3 = along.cross(side)
	var shoulder: Vector3 = base + along * length * 0.72
	var tip: Vector3 = base + along * length
	for corner: int in 6:
		var angle_a: float = TAU * corner / 6.0
		var angle_b: float = TAU * (corner + 1) / 6.0
		var out_a: Vector3 = (side * cos(angle_a) + up * sin(angle_a)) * width
		var out_b: Vector3 = (side * cos(angle_b) + up * sin(angle_b)) * width
		# Alternate faces a shade apart, so the facets read.
		var shade: Color = color if corner % 2 == 0 else color.lightened(0.18)
		quad(tool, base + out_a, shoulder + out_a, shoulder + out_b, base + out_b, shade, GLOW)
		triangle(tool, shoulder + out_a, tip, shoulder + out_b, shade.lightened(0.1), GLOW)


## A faceted lump (a jittered icosahedron), for pebbles and floating rocks.
static func add_lump(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var points: Array[Vector3] = []
	for point: Vector3 in ICO_POINTS:
		points.append(center + point.normalized() * size * rng.randf_range(0.8, 1.15))
	for face: Vector3i in ICO_FACES:
		# Clockwise seen from outside.
		triangle(tool, points[face.x], points[face.z], points[face.y], color, ROCK)


## A grass tuft: a few thin blades fanning up and out from [param at], darker at the root (both
## sides, so it reads from any angle).
static func add_tuft(tool: SurfaceTool, at: Vector3, height: float, color: Color, rng: RandomNumberGenerator) -> void:
	var blades: int = rng.randi_range(4, 6)
	var root_color: Color = color.darkened(0.1)
	var turn: float = rng.randf() * TAU
	for blade: int in blades:
		var angle: float = turn + TAU * blade / blades + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = around(angle)
		var side: Vector3 = Vector3(-out.z, 0.0, out.x) * 0.055
		var base: Vector3 = at + out * 0.04
		var tip: Vector3 = at + out * rng.randf_range(0.08, 0.18) + Vector3.UP * height * rng.randf_range(0.7, 1.0)
		for pair: Array in [[side, -side], [-side, side]]:
			tool.set_color(root_color)
			tool.set_uv2(GROUND)
			tool.add_vertex(base + (pair[0] as Vector3))
			tool.set_color(color)
			tool.add_vertex(tip)
			tool.set_color(root_color)
			tool.add_vertex(base + (pair[1] as Vector3))


## A flower lying open on the ground: [param petals] in [param color] round a Sunburst middle, on
## a short stem.
static func add_flower(tool: SurfaceTool, at: Vector3, size: float, color: Color, stem_color: Color, rng: RandomNumberGenerator) -> void:
	var head: Vector3 = at + Vector3.UP * size * 0.9
	add_tube(tool, PackedVector3Array([at, at + Vector3.UP * size * 0.5, head]), size * 0.06, size * 0.05, stem_color, 3)
	var petals: int = 5
	var turn: float = rng.randf() * TAU
	for petal: int in petals:
		var out: Vector3 = around(turn + TAU * petal / petals)
		var side: Vector3 = Vector3(-out.z, 0.0, out.x) * size * 0.28
		var tip: Vector3 = head + out * size * 0.55 + Vector3.UP * size * 0.12
		var middle: Vector3 = head + out * size * 0.3
		for pair: Array in [[side, -side], [-side, side]]:
			triangle(tool, head, middle + (pair[0] as Vector3), tip, color, PLAIN)
			triangle(tool, head, tip, middle + (pair[1] as Vector3), color, PLAIN)
	add_lump(tool, head + Vector3.UP * size * 0.05, Vector3.ONE * size * 0.14, Palette.SUNBURST, rng)


## A surface of revolution round +Y: [param profile] points are (radius, height, wave), running
## from the top or inside outward and down, which faces it outward. A point's wave scallops its
## radius with angle ([param waves] lobes round), for petal rims and fluted columns. Each step
## between two points is its own band, in [param colors][step]: a Color, or an Array of two
## alternating round it (stripes, tiles). Smooth round, sharp between bands. [param start_angle]
## turns where the first segment starts (so few-sided shapes, like an octagon, can face a way).
static func lathe(tool: SurfaceTool, profile: PackedVector3Array, segments: int, colors: Array, look: Vector2,
		waves: int = 0, at: Vector3 = Vector3.ZERO, start_angle: float = 0.0) -> void:
	var rings: Array[PackedVector3Array] = []
	for point: Vector3 in profile:
		var ring: PackedVector3Array = PackedVector3Array()
		for segment: int in segments:
			var angle: float = start_angle + TAU * segment / segments
			var scallop: float = 1.0 + point.z * cos(angle * waves)
			ring.append(at + around(angle) * point.x * scallop + Vector3.UP * point.y)
		rings.append(ring)
	for band: int in rings.size() - 1:
		var upper: PackedVector3Array = rings[band]
		var lower: PackedVector3Array = rings[band + 1]
		var band_colors: Variant = colors[mini(band, colors.size() - 1)]
		# One normal per angle for the band: round it, crossed with down the profile.
		var normals: PackedVector3Array = PackedVector3Array()
		for segment: int in segments:
			var next: int = (segment + 1) % segments
			var previous: int = (segment + segments - 1) % segments
			var round_tangent: Vector3 = (upper[next] - upper[previous]) + (lower[next] - lower[previous])
			var normal: Vector3 = round_tangent.cross(lower[segment] - upper[segment]).normalized()
			normals.append(normal)
		for segment: int in segments:
			var next: int = (segment + 1) % segments
			var color: Color = band_colors[segment % 2] if band_colors is Array else band_colors
			for corner: Array in [[upper, segment], [lower, segment], [lower, next], [upper, segment], [lower, next], [upper, next]]:
				tool.set_normal(normals[corner[1]])
				vertex(tool, (corner[0] as PackedVector3Array)[corner[1]], color, look)


static var _water: ShaderMaterial
static var _puff: StandardMaterial3D


## Cartoon water (assets/shaders/waterfall.gdshader), shared by falls, pools, curtains and jets;
## each sets its own flow, fade and edges.
static func water_material() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = preload("res://assets/shaders/waterfall.gdshader")
	return _water


## A soft round puff, for mist and spray particles (tinted by the particles' colour ramp).
static func puff_material() -> StandardMaterial3D:
	if _puff == null:
		var soft: GradientTexture2D = GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.gradient = Gradient.new()
		soft.gradient.set_color(0, Color.WHITE)
		soft.gradient.set_color(1, Color(Color.WHITE, 0.0))
		_puff = StandardMaterial3D.new()
		_puff.albedo_texture = soft
		_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff.vertex_color_use_as_albedo = true
	return _puff


## A flat disc of water, its UV running out from the middle (a pool: the shader foams its edge
## and ripples drift outward).
static func water_disc(disc_radius: float, sides: int = 24) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for index: int in sides:
		var a: Vector3 = around(TAU * index / sides)
		var b: Vector3 = around(TAU * (index + 1) / sides)
		for point: Vector3 in [Vector3.ZERO, a, b]:
			var reach: float = point.length()
			tool.set_uv(Vector2(0.5 + reach * 0.5, reach))
			tool.add_vertex(point * disc_radius)
	return tool.commit()


## Water pouring over a round rim all the way round: a curtain from [param from_radius] at
## [param from_y] spreading to [param to_radius] at [param to_y], bowing outward. UV.y runs down
## it (the way it flows) and UV.x round it, about a unit per 1.5 m, so streaks keep their size.
static func water_curtain(from_radius: float, from_y: float, to_radius: float, to_y: float, segments: int = 32) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS: int = 6
	var repeats: float = maxf(roundf(TAU * from_radius / 1.5), 1.0)
	for step: int in STEPS + 1:
		var t: float = float(step) / STEPS
		var radius: float = lerpf(from_radius, to_radius, sqrt(t))
		var height: float = lerpf(from_y, to_y, t * t)
		for segment: int in segments + 1:
			var angle: float = TAU * segment / segments
			tool.set_uv(Vector2(repeats * segment / segments, t))
			tool.add_vertex(around(angle) * radius + Vector3.UP * height)
	var row: int = segments + 1
	for step: int in STEPS:
		for segment: int in segments:
			var a: int = step * row + segment
			for corner: int in [a, a + row, a + row + 1, a, a + row + 1, a + 1]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A round stream of water through [param points] (a jet, an arc from a spout), tapering from
## [param start_radius] to [param end_radius]. UV.y runs along it, the way it flows.
static func water_tube(points: PackedVector3Array, start_radius: float, end_radius: float, sides: int = 8) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in points.size():
		var along: Vector3 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var side: Vector3 = along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
		var up: Vector3 = along.cross(side)
		var t: float = float(index) / (points.size() - 1)
		var radius: float = lerpf(start_radius, end_radius, t)
		for corner: int in sides + 1:
			var angle: float = TAU * corner / sides
			tool.set_uv(Vector2(float(corner) / sides, t))
			tool.add_vertex(points[index] + (side * cos(angle) + up * sin(angle)) * radius)
	var row: int = sides + 1
	for index: int in points.size() - 1:
		for corner: int in sides:
			var a: int = index * row + corner
			for vertex_index: int in [a, a + row, a + row + 1, a, a + row + 1, a + 1]:
				tool.add_index(vertex_index)
	tool.generate_normals()
	return tool.commit()
