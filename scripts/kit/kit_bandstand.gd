@tool
class_name KitBandstand
extends KitPiece
## A cartoon bandstand for a town square. An octagonal stage (plank deck, trim, a striped skirt) with
## two steps up at the front and back (+Z and -Z) and eight fluted columns, and turned railings on
## the six sides between the entrances. Over it, a curved, striped octagonal canopy with a cream
## ceiling, a scalloped valance and glowing bulbs round the eave, and a gold finial with a pennant on
## top. On stage, a drum and music stands (the middle stays clear, for a coin).
##
## It all shares the island material (vertex colours). It collides as the stage, steps, columns,
## railings, drum and roof: walk up the steps, vault the railing from inside, stand on the roof if
## you drop onto it. Its origin is the middle of its base. color paints the deck, trim_color the
## woodwork and ceiling, roof_color the canopy stripes and accent_color the gold.

## Sizes below are for a stage of radius 4.5 (to its corners); they scale with radius.
const BASE_RADIUS: float = 4.5
const STAGE_HEIGHT: float = 0.5
const BULB_COLORS: Array[Color] = [Palette.SUNBURST, Palette.CORAL, Palette.MINT, Palette.SKY]
## The faces with steps instead of railings (face n looks out at n * 45 degrees): +Z and -Z.
const ENTRANCES: Array[int] = [2, 6]
const LOOK: Vector2 = Vector2(0.3, 0.0)
## Octagon corners sit at 22.5 + 45n degrees, so a flat face looks each way along X and Z.
const TURN: float = PI / 8.0

@export var radius: float = 4.5:
	set(value):
		radius = maxf(KitPiece.snap(value), 2.5)
		queue_build()
## From the stage to the eave.
@export var column_height: float = 3.4:
	set(value):
		column_height = maxf(value, 2.4)
		queue_build()
@export var trim_color: Swatch = Swatch.CREAM:
	set(value):
		trim_color = value
		queue_build()
@export var roof_color: Swatch = Swatch.BERRY:
	set(value):
		roof_color = value
		queue_build()
@export var accent_color: Swatch = Swatch.SUNBURST:
	set(value):
		accent_color = value
		queue_build()
## The drum and music stands on stage.
@export var instruments: bool = true:
	set(value):
		instruments = value
		queue_build()


func _init() -> void:
	color = Swatch.SAND


func _add_parts() -> void:
	var s: float = radius / BASE_RADIUS
	var r: float = radius
	# Varnished: darker than the swatch, so a Sand deck stands out on Sand paving.
	var deck: Color = SWATCH_COLORS[color].darkened(0.22)
	var trim: Color = SWATCH_COLORS[trim_color]
	var roof: Color = SWATCH_COLORS[roof_color]
	var accent: Color = SWATCH_COLORS[accent_color]
	var turn: float = TURN
	var apothem: float = r * cos(turn)
	var eave: float = STAGE_HEIGHT + column_height
	var solid: SurfaceTool = SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faceted: SurfaceTool = IslandMeshes.flat_tool()

	# The stage: plank wedges, a trim edge, a fascia, and a skirt in alternating panels.
	IslandMeshes.lathe(solid, PackedVector3Array([
		Vector3(0, STAGE_HEIGHT, 0), Vector3(r - 0.3, STAGE_HEIGHT, 0), Vector3(r, STAGE_HEIGHT, 0),
		Vector3(r, STAGE_HEIGHT - 0.14, 0), Vector3(r - 0.08, STAGE_HEIGHT - 0.14, 0), Vector3(r - 0.08, 0.06, 0),
		Vector3(r + 0.04, 0.0, 0),
	]), 8, [[deck, deck.lightened(0.12)], trim, trim.darkened(0.1), trim.darkened(0.2),
		[roof.darkened(0.15), trim.darkened(0.15)], trim.darkened(0.2)], LOOK, 0, Vector3.ZERO, turn)
	var stage_shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	stage_shape.points = _prism(r, 0.0, STAGE_HEIGHT, turn)
	add_shape(stage_shape)
	# Steps at the entrances: two, a third of the stage's height each. A carpet runs from one
	# entrance to the other, up and over the steps.
	var carpet: Color = roof.darkened(0.1)
	_add_box(solid, Vector3.UP * (STAGE_HEIGHT + 0.015), Basis.IDENTITY, Vector3(1.2 * s, 0.03, apothem * 2.0), carpet)
	for face: int in ENTRANCES:
		var out: Vector3 = IslandMeshes.around(face * TAU / 8.0)
		for step: int in 2:
			var top: float = STAGE_HEIGHT * (2 - step) / 3.0
			var size: Vector3 = Vector3(2.4 * s, top, 0.4)
			var center: Vector3 = out * (apothem + 0.2 + 0.4 * step) + Vector3.UP * top * 0.5
			_add_box(solid, center, _facing(out), size, trim.darkened(0.05 * step))
			_add_box(solid, center + Vector3.UP * (top * 0.5 + 0.015), _facing(out), Vector3(1.2 * s, 0.03, 0.4), carpet)
			add_shape(_box_shape(size), Transform3D(_facing(out), center))

	# Columns at the corners, fluted, with a base and a gold-banded capital.
	var column_at: float = r - 0.35 * s
	var c: float = 0.17 * s
	for corner: int in 8:
		var at: Vector3 = IslandMeshes.around(turn + corner * TAU / 8.0) * column_at
		IslandMeshes.lathe(solid, PackedVector3Array([
			Vector3(c * 1.9, eave, 0), Vector3(c * 1.9, eave - 0.1, 0), Vector3(c * 1.5, eave - 0.18, 0),
			Vector3(c * 1.35, eave - 0.24, 0), Vector3(c, eave - 0.32, 0.1), Vector3(c, STAGE_HEIGHT + 0.28, 0.1),
			Vector3(c * 1.4, STAGE_HEIGHT + 0.2, 0), Vector3(c * 1.7, STAGE_HEIGHT + 0.08, 0), Vector3(c * 1.7, STAGE_HEIGHT, 0),
		]), 12, [trim, accent, accent, trim, trim, trim, trim, trim.darkened(0.1)], LOOK, 8, at)
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = c * 1.3
		shape.height = column_height
		add_shape(shape, Transform3D(Basis.IDENTITY, at + Vector3.UP * (STAGE_HEIGHT + column_height * 0.5)))

	# Railings between the columns, except at the entrances: two rails and turned spindles.
	for face: int in 8:
		if face in ENTRANCES:
			continue
		var a: Vector3 = IslandMeshes.around(turn + (face - 1) * TAU / 8.0) * column_at
		var b: Vector3 = IslandMeshes.around(turn + face * TAU / 8.0) * column_at
		var middle: Vector3 = (a + b) * 0.5
		var along: Vector3 = (b - a).normalized()
		var basis: Basis = _facing(IslandMeshes.around(face * TAU / 8.0))
		var length: float = a.distance_to(b) - 0.3 * s
		for rail: Array in [[STAGE_HEIGHT + 0.9, 0.09], [STAGE_HEIGHT + 0.14, 0.07]]:
			_add_box(solid, middle + Vector3.UP * rail[0], basis, Vector3(length, rail[1], 0.14), trim)
		var spindles: int = int(length / (0.32 * s))
		var low: float = STAGE_HEIGHT + 0.16
		for spindle: int in spindles:
			var at: Vector3 = middle + along * (length * ((spindle + 0.5) / spindles - 0.5))
			IslandMeshes.lathe(solid, PackedVector3Array([
				Vector3(0.035, low + 0.7, 0), Vector3(0.05, low + 0.57, 0), Vector3(0.035, low + 0.47, 0),
				Vector3(0.065, low + 0.27, 0), Vector3(0.035, low + 0.07, 0), Vector3(0.05, low, 0),
			]), 6, [trim], LOOK, 0, at)
		add_shape(_box_shape(Vector3(length, 0.95, 0.16)), Transform3D(basis, middle + Vector3.UP * (STAGE_HEIGHT + 0.48)))

	# The canopy: a curved octagonal roof striped face by face, over a cream ceiling that's flat
	# above the columns and then rises into the roof.
	var lip: float = r + 0.8 * s
	var roof_profile: PackedVector3Array = PackedVector3Array([
		Vector3(0.22 * s, eave + 3.0 * s, 0), Vector3(0.6 * s, eave + 2.5 * s, 0), Vector3(1.5 * s, eave + 1.75 * s, 0),
		Vector3(2.8 * s, eave + 1.0 * s, 0), Vector3(4.2 * s, eave + 0.45 * s, 0), Vector3(lip, eave + 0.15, 0),
		Vector3(lip + 0.05, eave, 0),
	])
	IslandMeshes.lathe(solid, roof_profile, 8, [[roof, trim]], Vector2(0.15, 0.0), 0, Vector3.ZERO, turn)
	# The ceiling's rise is striped like the canopy, in paler colours, with gold ribs up the corners
	# to a lantern hanging in the middle.
	var ceiling: PackedVector3Array = PackedVector3Array([
		Vector3(lip + 0.05, eave, 0), Vector3(r - 0.8 * s, eave, 0), Vector3(2.8 * s, eave + 0.7 * s, 0),
		Vector3(1.2 * s, eave + 1.5 * s, 0), Vector3(0.0, eave + 1.8 * s, 0),
	])
	var pale: Array = [trim.lightened(0.1), roof.lightened(0.55)]
	IslandMeshes.lathe(solid, ceiling, 8, [trim.lightened(0.1), pale, pale, pale], LOOK, 0, Vector3.ZERO, turn)
	for corner: int in 8:
		var out: Vector3 = IslandMeshes.around(turn + corner * TAU / 8.0)
		for point: int in range(1, ceiling.size() - 1):
			var from: Vector3 = out * ceiling[point].x + Vector3.UP * ceiling[point].y
			var to: Vector3 = out * ceiling[point + 1].x + Vector3.UP * ceiling[point + 1].y
			var z: Vector3 = (to - from).normalized()
			var x: Vector3 = Vector3.UP.cross(out)
			var y: Vector3 = z.cross(x)
			var below: Vector3 = -y if y.y > 0.0 else y
			_add_box(solid, (from + to) * 0.5 + below * 0.04, Basis(x, y, z), Vector3(0.1, 0.07, from.distance_to(to) + 0.05), accent)
	_add_lantern(solid, eave + 1.8 * s, eave + 0.55 * s, s, accent)
	# The roof collides as stacked frustums, each from one ring of the profile up to the next, so
	# its curve isn't bridged over.
	for ring: int in range(roof_profile.size() - 2, 0, -1):
		var hull: PackedVector3Array = PackedVector3Array()
		var lower: Vector3 = roof_profile[ring]
		var upper: Vector3 = roof_profile[ring - 1]
		for corner: int in 8:
			var out: Vector3 = IslandMeshes.around(turn + corner * TAU / 8.0)
			hull.append(out * lower.x + Vector3.UP * eave)
			hull.append(out * lower.x + Vector3.UP * lower.y)
			hull.append(out * upper.x + Vector3.UP * upper.y)
		var roof_shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		roof_shape.points = hull
		add_shape(roof_shape)
	_add_valance(faceted, lip, eave, turn, s, accent)

	# Bulbs round the eave, at each corner and each face's middle, on short cords.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	for bulb: int in 16:
		var angle: float = turn + bulb * TAU / 16.0
		var reach: float = lip * (1.0 if bulb % 2 == 0 else cos(turn)) - 0.2
		var at: Vector3 = IslandMeshes.around(angle) * reach
		var size: float = 0.11 * s
		_add_box(solid, at + Vector3.UP * (eave - 0.15), Basis.IDENTITY, Vector3(0.025, 0.3, 0.025), SWATCH_COLORS[Swatch.ASPHALT])
		_add_bulb(faceted, at + Vector3.UP * (eave - 0.3 - size * 1.3), BULB_COLORS[bulb % BULB_COLORS.size()], size, rng)

	# The finial, and a pennant flying off it.
	var top: float = eave + 3.0 * s
	IslandMeshes.lathe(solid, PackedVector3Array([
		Vector3(0.0, top + 1.25 * s, 0), Vector3(0.05 * s, top + 0.9 * s, 0), Vector3(0.2 * s, top + 0.5 * s, 0),
		Vector3(0.3 * s, top + 0.3 * s, 0), Vector3(0.2 * s, top + 0.12 * s, 0), Vector3(0.32 * s, top, 0),
	]), 12, [accent, accent, accent, accent.darkened(0.1), accent.darkened(0.15)], Vector2(0.0, 0.2))
	var flag_base: Vector3 = Vector3.UP * (top + 0.8 * s)
	var tip: Vector3 = flag_base + Vector3(0.75 * s, 0.12 * s, 0)
	var flag_low: Vector3 = flag_base + Vector3(0, -0.12 * s, 0)
	var flag_high: Vector3 = flag_base + Vector3(0, 0.36 * s, 0)
	IslandMeshes.triangle(faceted, flag_high, tip, flag_low, SWATCH_COLORS[Swatch.CORAL], IslandMeshes.PLAIN)
	IslandMeshes.triangle(faceted, flag_high, flag_low, tip, SWATCH_COLORS[Swatch.CORAL], IslandMeshes.PLAIN)

	if instruments:
		_add_instruments(solid, s, trim, accent)

	var solid_mesh: MeshInstance3D = add_mesh(solid.commit(), color, Transform3D.IDENTITY, false)
	solid_mesh.material_override = IslandMeshes.material()
	var faceted_mesh: MeshInstance3D = add_mesh(IslandMeshes.commit_flat(faceted), color, Transform3D.IDENTITY, false)
	faceted_mesh.material_override = IslandMeshes.material()


## A drum at the back right and three music stands in an arc at the back left, facing the middle.
## The stands don't collide.
func _add_instruments(tool: SurfaceTool, s: float, trim: Color, accent: Color) -> void:
	var coral: Color = SWATCH_COLORS[Swatch.CORAL]
	var dark: Color = SWATCH_COLORS[Swatch.ASPHALT]
	var drum_at: Vector3 = IslandMeshes.around(deg_to_rad(-55.0)) * 2.4 * s
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.0, STAGE_HEIGHT + 0.62, 0), Vector3(0.42, STAGE_HEIGHT + 0.62, 0), Vector3(0.46, STAGE_HEIGHT + 0.58, 0),
		Vector3(0.46, STAGE_HEIGHT + 0.52, 0), Vector3(0.44, STAGE_HEIGHT + 0.08, 0), Vector3(0.46, STAGE_HEIGHT + 0.04, 0),
		Vector3(0.46, STAGE_HEIGHT, 0),
	]), 16, [trim.lightened(0.15), accent, accent, [coral, coral.lightened(0.15)], accent, accent], Vector2.ZERO, 0, drum_at)
	var drum_shape: CylinderShape3D = CylinderShape3D.new()
	drum_shape.radius = 0.46
	drum_shape.height = 0.62
	add_shape(drum_shape, Transform3D(Basis.IDENTITY, drum_at + Vector3.UP * (STAGE_HEIGHT + 0.31)))
	for stand: int in 3:
		var at: Vector3 = IslandMeshes.around(deg_to_rad(-125.0 - stand * 25.0)) * 2.5 * s
		var facing: Basis = _facing(-at.normalized())
		_add_box(tool, at + Vector3.UP * (STAGE_HEIGHT + 0.5), facing, Vector3(0.04, 1.0, 0.04), dark)
		var board: Basis = facing.rotated(facing.x, -0.5)
		_add_box(tool, at + Vector3.UP * (STAGE_HEIGHT + 1.05), board, Vector3(0.5, 0.36, 0.03), dark)
		_add_box(tool, at + Vector3.UP * (STAGE_HEIGHT + 1.05) + board.z * 0.02, board, Vector3(0.42, 0.28, 0.01), trim.lightened(0.2))


## A glowing lantern hanging on a cord from [param from] (the ceiling's peak) to [param bottom].
func _add_lantern(tool: SurfaceTool, from: float, bottom: float, s: float, accent: Color) -> void:
	var cap: float = bottom + 0.55 * s
	_add_box(tool, Vector3.UP * (from + cap) * 0.5, Basis.IDENTITY, Vector3(0.03, from - cap + 0.05, 0.03), SWATCH_COLORS[Swatch.ASPHALT])
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.0, cap + 0.1 * s, 0), Vector3(0.12 * s, cap + 0.06 * s, 0), Vector3(0.3 * s, cap - 0.06 * s, 0),
		Vector3(0.22 * s, cap - 0.1 * s, 0),
	]), 8, [accent, accent, accent.darkened(0.15)], LOOK, 0, Vector3.ZERO, TURN)
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.2 * s, cap - 0.1 * s, 0), Vector3(0.24 * s, bottom + 0.25 * s, 0), Vector3(0.18 * s, bottom + 0.08 * s, 0),
	]), 8, [Palette.SUNBURST.lightened(0.3)], IslandMeshes.GLOW, 0, Vector3.ZERO, TURN)
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.2 * s, bottom + 0.1 * s, 0), Vector3(0.12 * s, bottom, 0), Vector3(0.0, bottom - 0.06 * s, 0),
	]), 8, [accent.darkened(0.15)], LOOK, 0, Vector3.ZERO, TURN)


## The valance: a band hanging under the eave, scalloped along its bottom edge, both sides.
func _add_valance(tool: SurfaceTool, lip: float, eave: float, turn: float, s: float, color: Color) -> void:
	const SCALLOPS: int = 4
	const STEPS: int = 6
	for face: int in 8:
		var a: Vector3 = IslandMeshes.around(turn + face * TAU / 8.0) * lip + Vector3.UP * eave
		var b: Vector3 = IslandMeshes.around(turn + (face + 1) * TAU / 8.0) * lip + Vector3.UP * eave
		for scallop: int in SCALLOPS:
			var shade: Color = color if scallop % 2 == 0 else color.darkened(0.12)
			for step: int in STEPS:
				var p0: Vector3 = a.lerp(b, (scallop + float(step) / STEPS) / SCALLOPS)
				var p1: Vector3 = a.lerp(b, (scallop + float(step + 1) / STEPS) / SCALLOPS)
				var q0: Vector3 = p0 + Vector3.DOWN * (0.14 + 0.18 * sin(PI * step / STEPS)) * s
				var q1: Vector3 = p1 + Vector3.DOWN * (0.14 + 0.18 * sin(PI * (step + 1) / STEPS)) * s
				IslandMeshes.quad(tool, p0, p1, q1, q0, shade, IslandMeshes.PLAIN)
				IslandMeshes.quad(tool, p0, q0, q1, p1, shade, IslandMeshes.PLAIN)


## A glowing bulb under a small dark cap.
static func _add_bulb(tool: SurfaceTool, at: Vector3, color: Color, size: float, rng: RandomNumberGenerator) -> void:
	var points: Array[Vector3] = []
	for point: Vector3 in IslandMeshes.ICO_POINTS:
		points.append(at + point.normalized() * size * rng.randf_range(0.9, 1.1))
	for face: Vector3i in IslandMeshes.ICO_FACES:
		IslandMeshes.triangle(tool, points[face.x], points[face.z], points[face.y], color, IslandMeshes.GLOW)
	IslandMeshes.add_lump(tool, at + Vector3.UP * size, Vector3(size * 0.7, size * 0.5, size * 0.7), Palette.ASPHALT, rng)


## A basis whose z looks along [param out] (flat), y up and x across.
static func _facing(out: Vector3) -> Basis:
	var z: Vector3 = Vector3(out.x, 0.0, out.z).normalized()
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


## A box centred at [param center], turned by [param basis], with its own flat normals.
static func _add_box(tool: SurfaceTool, center: Vector3, basis: Basis, size: Vector3, color: Color) -> void:
	var half: Vector3 = size * 0.5
	for axis: int in 3:
		for side: float in [-1.0, 1.0]:
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = side
			var u: Vector3 = Vector3.ZERO
			var v: Vector3 = Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var middle: Vector3 = normal * half
			var corners: Array[Vector3] = [middle - u - v, middle + u - v, middle + u + v, middle - u + v]
			# Clockwise seen from outside.
			if side > 0.0:
				corners.reverse()
			var world_normal: Vector3 = (basis * normal).normalized()
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(world_normal)
				IslandMeshes.vertex(tool, center + basis * corners[index], color, LOOK)


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	return shape


## The corners of an octagonal prism from [param bottom] to [param top].
static func _prism(prism_radius: float, bottom: float, top: float, turn: float) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for corner: int in 8:
		var out: Vector3 = IslandMeshes.around(turn + corner * TAU / 8.0) * prism_radius
		points.append(out + Vector3.UP * bottom)
		points.append(out + Vector3.UP * top)
	return points
