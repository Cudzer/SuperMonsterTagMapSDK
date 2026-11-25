class_name Fx
## One-shot cosmetic effects: particle bursts, expanding rings, afterimages and hit-stop. Purely
## local: callers trigger them on every peer from replicated state or events, so nothing here is
## networked. Effects add themselves under [param parent] (usually the level, see world_for()) and
## free themselves when done.

## Dust puffs and landing clouds.
const DUST_COLOR: Color = Color(0.82, 0.94, 0.92, 0.85)
## Freezing and thawing in Stuck in the Mud.
const ICE_COLOR: Color = Color(0.55, 0.82, 1.0, 1.0)

static var _particle_material: StandardMaterial3D
static var _meshes: Dictionary = {}
static var _fade_ramp: Gradient
static var _hit_stops: int = 0


## The node effects for [param node] should live under: its Level, or the current scene. Levels
## are found by duck typing because Level preloads the player scene, which uses Fx; naming the
## class here would make a load cycle.
static func world_for(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current is Node3D and current.has_method(&"get_wrap_position"):
			return current
		current = current.get_parent()
	return node.get_tree().current_scene if node.is_inside_tree() else null


## A burst of small spheres flying out from [param at]. [param gravity] is the vertical pull
## (negative falls), [param spread] the cone in degrees around [param direction].
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 24, speed: float = 5.0,
		size: float = 0.12, lifetime: float = 0.5, gravity: float = -9.0, spread: float = 180.0,
		direction: Vector3 = Vector3.UP) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.mesh = _sphere(size)
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, gravity, 0)
	particles.damping_min = 1.0
	particles.damping_max = 3.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.color = color
	particles.color_ramp = _fade()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _added(parent, particles):
		return
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)



## Adds [param effect] under [param parent], or frees it if that failed: a parent busy with its
## children (a level being swapped out) refuses it, and the effect, never in the tree, was left
## over for good (the long session found bursts from bushes left this way).
static func _added(parent: Node, effect: Node) -> bool:
	parent.add_child(effect)
	if effect.is_inside_tree():
		return true
	effect.free()
	return false

## A flat ring that expands from [param at] to [param radius] and fades out.
static func ring(parent: Node, at: Vector3, color: Color, radius: float = 3.0, duration: float = 0.45) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 6
	torus.material = material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = torus
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _added(parent, mesh):
		return
	mesh.global_position = at
	mesh.scale = Vector3(0.2, 0.4, 0.2)
	var tween: Tween = mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3(radius, 0.4, radius), duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


## A see-through copy of the character's body at [param body_transform] that fades out.
static func afterimage(parent: Node, body_transform: Transform3D, color: Color, duration: float = 0.3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.45)
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	capsule.radial_segments = 16
	capsule.rings = 4
	capsule.material = material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _added(parent, mesh):
		return
	mesh.global_transform = body_transform
	var tween: Tween = mesh.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(mesh.queue_free)


## Nearly freezes time for [param duration] real seconds, for the impact of a big hit. Overlapping
## hit-stops extend each other rather than ending early. Off when the player has turned
## Settings.hit_pause off.
static func hit_stop(tree: SceneTree, duration: float = 0.07, time_scale: float = 0.05) -> void:
	if not Settings.hit_pause:
		return
	_hit_stops += 1
	Engine.time_scale = time_scale
	await tree.create_timer(duration, true, false, true).timeout
	_hit_stops -= 1
	if _hit_stops == 0:
		Engine.time_scale = 1.0


static func _sphere(size: float) -> SphereMesh:
	if _meshes.has(size):
		return _meshes[size]
	if _particle_material == null:
		_particle_material = StandardMaterial3D.new()
		_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Particle color and fade arrive as vertex colors.
		_particle_material.vertex_color_use_as_albedo = true
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _particle_material
	_meshes[size] = sphere
	return sphere


static func _fade() -> Gradient:
	if _fade_ramp == null:
		_fade_ramp = Gradient.new()
		_fade_ramp.set_color(0, Color.WHITE)
		_fade_ramp.set_color(1, Color(1, 1, 1, 0))
	return _fade_ramp
