class_name MidwayMeshes
extends RefCounted
## Shapes for Monster Midway (the lobby), drawn on the island material (IslandMeshes.material()):
## colours are vertex colours and each part says how much it glows (UV2.y), so a whole attraction
## is one batched mesh and its bulbs and neon light up without lights of their own.
##
## Everything goes into a plain SurfaceTool (begin(), then these, then commit()) with its own
## normals; the IslandMeshes builders that set normals (lathe()) mix in fine. Shapes take a
## Transform3D, so they can be scaled, turned and squashed (a squashed sphere is a monster's body).

const PLAIN: Vector2 = Vector2.ZERO
## Bulbs and neon: bright enough to bloom under the night environment's glow.
const LIT: Vector2 = Vector2(0.0, 2.4)
## A soft glow (signs, painted panels catching the lights).
const SOFT: Vector2 = Vector2(0.0, 0.7)

## A lit bulb's colours round the fair, cycled.
const BULB_COLORS: Array[Color] = [Palette.SUNBURST, Palette.CREAM, Palette.CORAL, Palette.SUNBURST, Palette.MINT]


static func begin() -> SurfaceTool:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## The finished mesh on the shared island material, as a MeshInstance3D with no shadow (most of
## the fair is lit by its own bulbs, and its moon shadows come from the solid parts).
static func instance(tool: SurfaceTool, casts_shadow: bool = true) -> MeshInstance3D:
	# Shared corners (round shapes have many) become one vertex.
	tool.index()
	var mesh: ArrayMesh = tool.commit()
	mesh.surface_set_material(0, IslandMeshes.material())
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _vertex(tool: SurfaceTool, xform: Transform3D, normal_basis: Basis, at: Vector3, normal: Vector3,
		color: Color, look: Vector2) -> void:
	tool.set_normal((normal_basis * normal).normalized())
	tool.set_color(color)
	tool.set_uv2(look)
	tool.add_vertex(xform * at)


static func _normal_basis(xform: Transform3D) -> Basis:
	return xform.basis.inverse().transposed()


## A box of [param size] centred on [param xform]'s origin.
static func box(tool: SurfaceTool, xform: Transform3D, size: Vector3, color: Color, look: Vector2 = PLAIN) -> void:
	var half: Vector3 = size * 0.5
	var normals: Basis = _normal_basis(xform)
	for axis: int in 3:
		for side: float in [-1.0, 1.0]:
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = side
			var u: Vector3 = Vector3.ZERO
			var v: Vector3 = Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			v[(axis + 2) % 3] = 1.0
			if side < 0.0:
				u = -u
			var center: Vector3 = normal * half
			var du: Vector3 = u * half
			var dv: Vector3 = v * half
			var corners: Array[Vector3] = [center - du - dv, center + du - dv, center + du + dv, center - du + dv]
			# Clockwise seen from outside (Godot's front faces).
			for index: int in [0, 2, 1, 0, 3, 2]:
				_vertex(tool, xform, normals, corners[index], normal, color, look)


## A sphere of radius 1 shaped by [param xform] (scale its basis for an ellipsoid).
static func blob(tool: SurfaceTool, xform: Transform3D, color: Color, look: Vector2 = PLAIN, rings: int = 8, segments: int = 12) -> void:
	var normals: Basis = _normal_basis(xform)
	for ring: int in rings:
		var a0: float = PI * ring / rings
		var a1: float = PI * (ring + 1) / rings
		for segment: int in segments:
			var b0: float = TAU * segment / segments
			var b1: float = TAU * (segment + 1) / segments
			var p00: Vector3 = _on_sphere(a0, b0)
			var p01: Vector3 = _on_sphere(a0, b1)
			var p10: Vector3 = _on_sphere(a1, b0)
			var p11: Vector3 = _on_sphere(a1, b1)
			for point: Vector3 in [p00, p11, p10, p00, p01, p11]:
				_vertex(tool, xform, normals, point, point, color, look)


static func _on_sphere(polar: float, around: float) -> Vector3:
	return Vector3(sin(polar) * sin(around), cos(polar), sin(polar) * cos(around))


## A sphere of [param radius] at [param center].
static func ball(tool: SurfaceTool, center: Vector3, radius: float, color: Color, look: Vector2 = PLAIN, rings: int = 6, segments: int = 10) -> void:
	blob(tool, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), center), color, look, rings, segments)


## A cylinder up [param xform]'s y from 0 to [param height], capped at both ends.
static func cylinder(tool: SurfaceTool, xform: Transform3D, radius: float, height: float, color: Color,
		look: Vector2 = PLAIN, segments: int = 12, top_radius: float = -1.0) -> void:
	var top: float = radius if top_radius < 0.0 else top_radius
	var normals: Basis = _normal_basis(xform)
	var slope: float = (radius - top) / maxf(height, 0.001)
	for segment: int in segments:
		var b0: float = TAU * segment / segments
		var b1: float = TAU * (segment + 1) / segments
		var d0: Vector3 = Vector3(sin(b0), 0.0, cos(b0))
		var d1: Vector3 = Vector3(sin(b1), 0.0, cos(b1))
		var n0: Vector3 = (d0 + Vector3.UP * slope).normalized()
		var n1: Vector3 = (d1 + Vector3.UP * slope).normalized()
		var low0: Vector3 = d0 * radius
		var low1: Vector3 = d1 * radius
		var high0: Vector3 = d0 * top + Vector3.UP * height
		var high1: Vector3 = d1 * top + Vector3.UP * height
		for pair: Array in [[low0, n0], [high0, n0], [high1, n1], [low0, n0], [high1, n1], [low1, n1]]:
			_vertex(tool, xform, normals, pair[0], pair[1], color, look)
		for corner: Vector3 in [Vector3.UP * height, high1, high0]:
			_vertex(tool, xform, normals, corner, Vector3.UP, color, look)
		for corner: Vector3 in [Vector3.ZERO, low0, low1]:
			_vertex(tool, xform, normals, corner, Vector3.DOWN, color, look)


## A round bar from [param from] to [param to].
static func bar(tool: SurfaceTool, from: Vector3, to: Vector3, radius: float, color: Color, look: Vector2 = PLAIN, segments: int = 8) -> void:
	var length: float = from.distance_to(to)
	if length < 0.001:
		return
	cylinder(tool, Transform3D(along(to - from), from), radius, length, color, look, segments)


## A basis whose y runs along [param direction].
static func along(direction: Vector3) -> Basis:
	var up: Vector3 = direction.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.9 else up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up))


## A ring (a torus) round [param xform]'s y axis: [param radius] to the middle of its tube.
static func ring(tool: SurfaceTool, xform: Transform3D, radius: float, thickness: float, color: Color,
		look: Vector2 = PLAIN, segments: int = 32, sides: int = 8) -> void:
	var normals: Basis = _normal_basis(xform)
	for segment: int in segments:
		var b0: float = TAU * segment / segments
		var b1: float = TAU * (segment + 1) / segments
		for side: int in sides:
			var s0: float = TAU * side / sides
			var s1: float = TAU * (side + 1) / sides
			var corners: Array = [[b0, s0], [b0, s1], [b1, s1], [b0, s0], [b1, s1], [b1, s0]]
			for corner: Array in corners:
				var out: Vector3 = Vector3(sin(corner[0]), 0.0, cos(corner[0]))
				var normal: Vector3 = out * cos(corner[1]) + Vector3.UP * sin(corner[1])
				_vertex(tool, xform, normals, out * radius + normal * thickness, normal, color, look)


## Bulbs every [param spacing] from [param from] to [param to], in cycling colours.
static func bulbs(tool: SurfaceTool, from: Vector3, to: Vector3, spacing: float, radius: float = 0.12, offset: int = 0) -> void:
	var count: int = maxi(int(from.distance_to(to) / spacing), 1)
	for index: int in count + 1:
		ball(tool, from.lerp(to, float(index) / count), radius, BULB_COLORS[(index + offset) % BULB_COLORS.size()], LIT, 4, 6)


## Bulbs round a circle of [param radius] about [param center]'s up axis.
static func bulb_ring(tool: SurfaceTool, center: Vector3, radius: float, count: int, bulb_radius: float = 0.12, offset: int = 0) -> void:
	for index: int in count:
		ball(tool, center + IslandMeshes.around(TAU * index / count) * radius, bulb_radius, BULB_COLORS[(index + offset) % BULB_COLORS.size()], LIT, 4, 6)


## A striped cone (a tent roof or a canopy), [param stripes] colours alternating round it, with a
## scalloped valance hanging from its rim.
static func striped_cone(tool: SurfaceTool, base: Vector3, radius: float, height: float, stripes: Array, valance: Color,
		segments: int = 24, start_angle: float = 0.0) -> void:
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0.0, height, 0.0), Vector3(radius * 0.55, height * 0.42, 0.0), Vector3(radius, 0.0, 0.0),
	]), segments, [stripes], PLAIN, 0, base, start_angle)
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(radius, 0.02, 0.0), Vector3(radius * 1.01, -0.55, 0.12),
	]), segments * 2, [valance], PLAIN, segments, base, start_angle)


## A painted sign's face: a flat board with a glowing border, facing +Z of [param xform].
static func sign_board(tool: SurfaceTool, xform: Transform3D, size: Vector2, color: Color, border: Color) -> void:
	box(tool, xform, Vector3(size.x, size.y, 0.2), color, SOFT)
	var edge: float = 0.18
	for side: float in [-1.0, 1.0]:
		box(tool, xform * Transform3D(Basis.IDENTITY, Vector3(side * (size.x + edge) * 0.5, 0.0, 0.05)), Vector3(edge, size.y + edge * 2.0, 0.24), border, LIT)
		box(tool, xform * Transform3D(Basis.IDENTITY, Vector3(0.0, side * (size.y + edge) * 0.5, 0.05)), Vector3(size.x, edge, 0.24), border, LIT)


## A flat four-sided face, a b c d clockwise seen from the side it faces.
static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, look: Vector2 = PLAIN) -> void:
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	for corner: Vector3 in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.set_uv2(look)
		tool.add_vertex(corner)


## Every triangle of [param node]'s generated meshes, in its own space, for Level Tools' click gizmo
## (the meshes are unowned internal children, which the editor can't select by themselves).
static func faces_of(node: Node3D) -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in node.get_children(true):
		var part: Node3D = child as Node3D
		if part != null:
			LevelModel._gather_faces(part, part.transform, faces)
	return faces
