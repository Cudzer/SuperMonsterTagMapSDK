@tool
class_name IslandDecor
extends Node3D
## A KitIsland's details (KitIsland.decor): grass tufts, flowers, pebbles and mushrooms on top,
## vines and roots hanging off the edge, and the extras an island can turn on: glowing crystals
## in the rock, a waterfall pouring off the edge, and rocks floating round the underside.
##
## Decoration only: no collision, no networking. It's random but repeatable (seed), so every peer
## grows the same island. Things on top keep clear of whatever stands on the island (the pieces,
## pads and models beside it in Geometry) and of the map's marker spots, so nothing hides a coin
## or crowds a base. That's worked out once the scene's nodes are ready, so it's built a frame
## late; move things on an island in the editor and the island catches up when it next rebuilds.
## Level Tools' surface picking and Level.get_geometry_bounds() both skip it.

const MUSHROOM_SCENES: Array[String] = [
	"res://assets/models/level/extras/Mushroom_1.glb",
	"res://assets/models/level/extras/Mushroom_2.glb",
	"res://assets/models/level/extras/Mushroom_3.glb",
]
## Tufts, flowers and pebbles per square meter at flora 1.
const TUFT_DENSITY: float = 0.3
const FLOWER_DENSITY: float = 0.07
const PEBBLE_DENSITY: float = 0.025
## How far (m) things on top keep from marker spots: bases need their 3 m clear.
const BASE_CLEARANCE: float = 3.6
const SPOT_CLEARANCE: float = 1.3
const FLOWER_COLORS: Array[Color] = [Palette.SUNBURST, Palette.CORAL, Palette.BERRY, Palette.FROST, Palette.LILAC]

## Set by KitIsland before it's added.
var radius: float = 10.0
var thickness: float = 2.0
var rock_depth: float = 10.0
var top_color: Color = Palette.LAGOON
var rock_color: Color = Palette.DEEP_TEAL
var decor_seed: int = 1
var flora: float = 1.0
var mushrooms: bool = true
var waterfall: bool = false
var waterfall_angle: float = 0.0
var crystals: bool = false
var crystal_color: Color = Palette.SEAFOAM
var debris: bool = false

## Keep-clear areas on top, in global space: {"to_local": Transform3D, "rect": Rect2} (a footprint
## in that node's own x/z) or {"center": Vector2, "radius": float}.
var _zones: Array[Dictionary] = []
var _floaters: Node3D
var _time: float = 0.0


func _ready() -> void:
	_build.call_deferred()
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_floaters.rotation.y = _time * 0.06
	for floater: Node3D in _floaters.get_children():
		var phase: float = floater.get_meta(&"phase", 0.0)
		floater.position.y = (floater.get_meta(&"height", 0.0) as float) + sin(_time * 0.7 + phase) * 0.35
		floater.rotate_y(0.004)


func _build() -> void:
	if not is_inside_tree():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = decor_seed
	var tool: SurfaceTool = IslandMeshes.flat_tool()
	_add_hanging(tool, rng)
	if crystals and rock_depth > 0.0:
		_add_crystals(tool, rng)
	_gather_zones()
	if waterfall:
		_add_waterfall()
	if flora > 0.0:
		_add_flora(tool, rng)
	if mushrooms and radius >= 4.0:
		_add_mushrooms(rng)
	var details: MeshInstance3D = MeshInstance3D.new()
	details.name = "Details"
	details.mesh = IslandMeshes.commit_flat(tool)
	details.material_override = IslandMeshes.material()
	add_child(details)
	if debris and rock_depth > 0.0:
		_add_floaters(rng)


## Vines and roots hanging from under the frosting, a few with leaves.
func _add_hanging(tool: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var vine_color: Color = Palette.MOSS.darkened(0.2)
	var root_color: Color = Palette.MUD
	var leaf_color: Color = Palette.MOSS.lightened(0.1)
	for strand: int in clampi(roundi(radius * 0.9), 2, 16):
		var angle: float = rng.randf() * TAU
		var out: Vector3 = IslandMeshes.around(angle)
		var sideways: Vector3 = Vector3(-out.z, 0.0, out.x)
		var length: float = rng.randf_range(1.0, 2.0 + rock_depth * 0.2)
		var is_root: bool = rng.randf() < 0.4
		var points: PackedVector3Array = PackedVector3Array()
		var sway: float = 0.0
		for step: int in 6:
			var t: float = step / 5.0
			sway += rng.randf_range(-0.12, 0.12)
			points.append(out * (radius + 0.05 + sin(t * PI) * 0.2) + sideways * sway + Vector3.UP * (thickness * 0.5 - length * t))
		var thick: float = 0.11 if is_root else 0.08
		IslandMeshes.add_tube(tool, points, thick, thick * 0.4, root_color if is_root else vine_color)
		if not is_root:
			for leaf: int in rng.randi_range(1, 3):
				var at: Vector3 = points[rng.randi_range(1, 4)]
				IslandMeshes.add_leaf(tool, at, out + sideways * rng.randf_range(-1.0, 1.0) + Vector3.DOWN * 0.4, 0.28, leaf_color)


## Clusters of crystals poking out of the rock, pointing out and down.
func _add_crystals(tool: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var size: float = clampf(radius / 7.0, 0.8, 1.8)
	for cluster: int in clampi(roundi(radius * 0.6), 3, 8):
		var angle: float = rng.randf() * TAU
		var t: float = rng.randf_range(0.15, 0.6)
		var rock_radius: float = lerpf(radius * 0.92, radius * 0.08, pow(t, 0.8))
		var out: Vector3 = IslandMeshes.around(angle)
		var base: Vector3 = out * (rock_radius - 0.1 * size) + Vector3.DOWN * rock_depth * t
		for crystal: int in rng.randi_range(3, 5):
			# Mostly outward, so they stand clear of the rock.
			var toward: Vector3 = out + Vector3.DOWN * rng.randf_range(0.1, 0.6) \
					+ Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.35, 0.35))
			IslandMeshes.add_crystal(tool, base, toward, rng.randf_range(1.2, 2.6) * size, rng.randf_range(0.22, 0.34) * size, crystal_color)


## Grass, flowers and pebbles over the top, kept off the frosting band and every keep-clear area.
func _add_flora(tool: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var inner: float = radius - 0.5
	if inner <= 0.3:
		return
	var area: float = PI * inner * inner * flora
	var tuft_colors: Array[Color] = [top_color.lightened(0.18), top_color.lightened(0.28), top_color.lightened(0.08)]
	var stem_color: Color = Palette.MOSS.darkened(0.15)
	for tuft: int in int(area * TUFT_DENSITY):
		var at: Vector3 = _spot_on_top(rng, inner)
		if _is_clear(at):
			IslandMeshes.add_tuft(tool, at, rng.randf_range(0.3, 0.5), tuft_colors[rng.randi() % tuft_colors.size()], rng)
	for flower: int in int(area * FLOWER_DENSITY):
		var at: Vector3 = _spot_on_top(rng, inner)
		if _is_clear(at):
			IslandMeshes.add_flower(tool, at, rng.randf_range(0.22, 0.34), FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()], stem_color, rng)
	for pebble: int in int(area * PEBBLE_DENSITY):
		var at: Vector3 = _spot_on_top(rng, inner)
		if _is_clear(at):
			var size: float = rng.randf_range(0.1, 0.28)
			IslandMeshes.add_lump(tool, at + Vector3.UP * size * 0.3, Vector3(size, size * 0.6, size * rng.randf_range(0.8, 1.2)),
					rock_color.lightened(rng.randf_range(0.15, 0.35)), rng)


## Little groups of mushrooms toward the rim.
func _add_mushrooms(rng: RandomNumberGenerator) -> void:
	var scenes: Array[PackedScene] = []
	for path: String in MUSHROOM_SCENES:
		# Null until imported: a project opened for the first time (the Map SDK) builds islands
		# before its models are in.
		var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene != null:
			scenes.append(scene)
	if scenes.is_empty():
		return
	for group: int in clampi(int(radius / 4.0), 1, 4):
		var angle: float = rng.randf() * TAU
		var center: Vector3 = IslandMeshes.around(angle) * radius * rng.randf_range(0.55, 0.85) + Vector3.UP * thickness
		for mushroom: int in rng.randi_range(1, 3):
			var at: Vector3 = center + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
			if Vector2(at.x, at.z).length() > radius - 0.6 or not _is_clear(at, 0.5):
				continue
			var instance: Node3D = scenes[rng.randi() % scenes.size()].instantiate() as Node3D
			instance.position = at
			instance.rotation.y = rng.randf() * TAU
			# The models are 0.85 m tall: knee to thigh height on a player.
			instance.scale = Vector3.ONE * rng.randf_range(0.4, 0.7)
			add_child(instance)


## A pool near the rim pouring over it in a fall that fades out far below, with mist round its
## foot.
func _add_waterfall() -> void:
	var angle: float = deg_to_rad(waterfall_angle)
	# Degrees clockwise from -Z (north), like the lobby's stations.
	var out: Vector3 = Vector3(sin(angle), 0.0, -cos(angle))
	var sideways: Vector3 = Vector3(-out.z, 0.0, out.x)
	var pool_radius: float = clampf(radius * 0.18, 0.9, 1.8)
	var pool_center: Vector3 = out * (radius - pool_radius + 0.1) + Vector3.UP * (thickness + 0.025)
	_zones.append({"center": _flat(global_transform * pool_center), "radius": pool_radius + 0.4})

	var pool_mesh: ArrayMesh = IslandMeshes.water_disc(pool_radius)
	var pool: MeshInstance3D = MeshInstance3D.new()
	pool.mesh = pool_mesh
	pool.position = pool_center
	pool.material_override = IslandMeshes.water_material()
	pool.set_instance_shader_parameter(&"flow", 0.15)
	pool.set_instance_shader_parameter(&"fade", 0.0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)

	var drop: float = thickness + rock_depth * 0.6 + 6.0
	var width: float = pool_radius * 1.2
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS: int = 16
	var bottom: Vector3 = Vector3.ZERO
	for step: int in STEPS + 1:
		var t: float = float(step) / STEPS
		var fallen: float = drop * t * t
		var reach: float = radius + 0.05 + 1.8 * (1.0 - exp(-fallen / 2.0))
		var middle: Vector3 = out * reach + Vector3.UP * (thickness + 0.04 - fallen)
		var half: float = width * (1.0 + 0.6 * t) * 0.5
		for side: float in [-1.0, 1.0]:
			tool.set_uv(Vector2(0.5 + side * 0.5, t))
			tool.add_vertex(middle + sideways * half * side)
		bottom = middle
		if step > 0:
			var base: int = step * 2
			for corner: int in [base - 2, base, base + 1, base - 2, base + 1, base - 1]:
				tool.add_index(corner)
	tool.generate_normals()
	var fall: MeshInstance3D = MeshInstance3D.new()
	fall.mesh = tool.commit()
	fall.material_override = IslandMeshes.water_material()
	fall.set_instance_shader_parameter(&"flow", 1.4)
	fall.set_instance_shader_parameter(&"fade", 1.0)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	_add_mist(bottom + Vector3.UP * drop * 0.15, width)


func _add_mist(at: Vector3, width: float) -> void:
	var mist: GPUParticles3D = GPUParticles3D.new()
	mist.amount = 10
	mist.lifetime = 2.6
	mist.position = at
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(width, 1.5, width)
	process.direction = Vector3.DOWN
	process.spread = 30.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.0
	process.gravity = Vector3.ZERO
	process.scale_min = 1.2
	process.scale_max = 2.2
	var grow: CurveTexture = CurveTexture.new()
	grow.curve = Curve.new()
	grow.curve.add_point(Vector2(0.0, 0.5))
	grow.curve.add_point(Vector2(1.0, 1.0))
	process.scale_curve = grow
	var fade: GradientTexture1D = GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(Palette.FROST, 0.0))
	fade.gradient.set_color(1, Color(Palette.FROST, 0.0))
	fade.gradient.add_point(0.3, Color(Palette.FROST, 0.55))
	process.color_ramp = fade
	mist.process_material = process
	var puff: QuadMesh = QuadMesh.new()
	puff.size = Vector2.ONE * 1.4
	puff.material = IslandMeshes.puff_material()
	mist.draw_pass_1 = puff
	add_child(mist)


## Rocks floating round the underside, slowly circling and bobbing (in game).
func _add_floaters(rng: RandomNumberGenerator) -> void:
	_floaters = Node3D.new()
	_floaters.name = "Floaters"
	add_child(_floaters)
	var shades: Array[Color] = [rock_color, rock_color.darkened(0.15), rock_color.lightened(0.1)]
	for index: int in clampi(roundi(radius * 0.4), 3, 7):
		var tool: SurfaceTool = IslandMeshes.flat_tool()
		var size: float = rng.randf_range(0.4, 1.0) * clampf(radius / 8.0, 0.6, 1.5)
		IslandMeshes.add_lump(tool, Vector3.ZERO, Vector3(size, size * 0.8, size * rng.randf_range(0.8, 1.2)), shades[index % shades.size()], rng)
		# A cap of the island's own top, like a chunk that broke away.
		IslandMeshes.add_lump(tool, Vector3.UP * size * 0.55, Vector3(size * 0.75, size * 0.2, size * 0.75), top_color, rng)
		var floater: MeshInstance3D = MeshInstance3D.new()
		floater.mesh = IslandMeshes.commit_flat(tool)
		floater.material_override = IslandMeshes.material()
		var height: float = -rock_depth * rng.randf_range(0.15, 0.65)
		var angle: float = TAU * index / 5.0 + rng.randf_range(-0.4, 0.4)
		floater.position = IslandMeshes.around(angle) * radius * rng.randf_range(0.75, 1.05) + Vector3.UP * height
		floater.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		floater.set_meta(&"height", height)
		floater.set_meta(&"phase", rng.randf() * TAU)
		_floaters.add_child(floater)
	set_process(not Engine.is_editor_hint())


## A random point on the top (island space), uniform over the disc of [param within] radius.
func _spot_on_top(rng: RandomNumberGenerator, within: float) -> Vector3:
	return IslandMeshes.around(rng.randf() * TAU) * within * sqrt(rng.randf()) + Vector3.UP * thickness


## Whether nothing that stands on the island (or a marker spot) is within [param margin] of
## [param at] (island space).
func _is_clear(at: Vector3, margin: float = 0.0) -> bool:
	var point: Vector3 = global_transform * at
	var flat: Vector2 = _flat(point)
	for zone: Dictionary in _zones:
		if zone.has("rect"):
			var local: Vector3 = (zone["to_local"] as Transform3D) * point
			if (zone["rect"] as Rect2).grow(margin).has_point(Vector2(local.x, local.z)):
				return false
		elif flat.distance_to(zone["center"]) < (zone["radius"] as float) + margin:
			return false
	return true


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## The keep-clear areas: everything beside the island in its parent (Geometry) standing about at
## the island's top, and the scene's marker spots and spawn ring.
func _gather_zones() -> void:
	_zones.clear()
	var island: Node3D = get_parent() as Node3D
	if island == null:
		return
	var top: float = island.global_position.y + thickness
	var parent: Node = island.get_parent()
	if parent != null:
		for node: Node in parent.get_children():
			if node != island and node is Node3D:
				_add_zone(node as Node3D, top)
	var root: Node = island.owner if island.owner != null else island.get_tree().current_scene
	if root == null:
		return
	for group_name: String in ["CoinSpawnPoints", "ButtonSpawnPoints", "BaseSpawnPoints"]:
		var group: Node = root.get_node_or_null(group_name)
		if group == null:
			continue
		for marker: Node in group.get_children():
			if marker is Node3D:
				var clearance: float = BASE_CLEARANCE if group_name == "BaseSpawnPoints" else SPOT_CLEARANCE
				_zones.append({"center": _flat((marker as Node3D).global_position), "radius": clearance})
	# The spawn ring: a map's PlayerSpawn, or a Level's own spawn_center.
	var ring_radius: Variant = root.get("spawn_radius")
	var spawn_radius: float = (ring_radius as float) if ring_radius is float else 4.0
	var spawn: Node3D = root.get_node_or_null("PlayerSpawn") as Node3D
	var center: Variant = root.get("spawn_center")
	if spawn != null:
		_zones.append({"center": _flat(spawn.global_position), "radius": spawn_radius + 1.2})
	elif center is Vector3 and root is Node3D:
		_zones.append({"center": _flat((root as Node3D).global_transform * (center as Vector3)), "radius": spawn_radius + 1.2})


func _add_zone(node: Node3D, top: float) -> void:
	# Spans (ziplines, rails): their posts, wherever they stand.
	if node.has_method(&"get_start") and node.has_method(&"get_end"):
		for end: Vector3 in [node.call(&"get_start"), node.call(&"get_end")]:
			if absf(end.y - top) < 2.0:
				_zones.append({"center": _flat(end), "radius": 1.2})
		return
	if node.global_position.y < top - 1.5 or node.global_position.y > top + 3.0:
		return
	var to_local: Transform3D = node.global_transform.affine_inverse()
	var size: Variant = node.get("size")
	var piece_radius: Variant = node.get("radius")
	if node.has_method(&"get_faces"):
		var faces: PackedVector3Array = node.call(&"get_faces")
		if not faces.is_empty():
			var bounds: AABB = AABB(faces[0], Vector3.ZERO)
			for point: Vector3 in faces:
				bounds = bounds.expand(point)
			_zones.append({"to_local": to_local, "rect": Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z).grow(0.3)})
			return
	if size is Vector3:
		var box: Vector3 = size
		_zones.append({"to_local": to_local, "rect": Rect2(-box.x * 0.5, -box.z * 0.5, box.x, box.z).grow(0.3)})
	elif piece_radius is float:
		_zones.append({"center": _flat(node.global_position), "radius": (piece_radius as float) + 0.3})
	else:
		# Pads, teleporters, fans, hiding spots, consoles...
		_zones.append({"center": _flat(node.global_position), "radius": 1.6})
