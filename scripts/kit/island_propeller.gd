@tool
class_name IslandPropeller
extends Node3D
## The cartoon propeller a KitIsland hangs under its rock (KitIsland.propeller), so the island looks
## like it's flying: a collar on the rock's tip, a shaft, a motor pod with a band, and a three-blade
## rotor with a faint blur disc. Decoration only: no collision, no networking, and the rotor turns by
## itself in game (each peer's own, so it needn't match). Everything is sized from span (the rotor's
## width), with the origin where it meets the rock and the rest hanging below.

const BLADES: int = 3
## Blade pitch, for the look of a real prop.
const BLADE_PITCH_DEGREES: float = 18.0

## The rotor's width (m).
var span: float = 5.0
var color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST
## Turns per second.
var spin_speed: float = 2.2
## The rock it's bolted to: its radius at the tip, and how much wider it gets per meter up, so
## the brass band hugs it.
var tip_radius: float = 0.4
var rock_slope: float = 0.8
## How many rivets round the band.
const RIVETS: int = 10

## Shared by every propeller's blur disc.
static var _blur_material: StandardMaterial3D

var _rotor: Node3D


func _ready() -> void:
	_build()
	# Spinning is for the game; in the editor it would redraw the viewport every frame.
	set_process(not Engine.is_editor_hint())
	# Not every propeller in step.
	if _rotor != null:
		_rotor.rotation.y = randf() * TAU


func _process(delta: float) -> void:
	_rotor.rotate_y(spin_speed * TAU * delta)


func _build() -> void:
	var s: float = span
	# A riveted brass band round the rock just above the tip, so the propeller's bolted on.
	var band_height: float = 0.1 * s
	var band_bottom: float = tip_radius + 0.015 * s
	var band_top: float = band_bottom + rock_slope * band_height
	_add_cylinder(self, band_top, band_bottom, band_height, band_height * 0.5, KitPiece.Swatch.SAND)
	var rivet: SphereMesh = SphereMesh.new()
	rivet.radius = 0.014 * s
	rivet.height = 0.028 * s
	rivet.radial_segments = 8
	rivet.rings = 4
	var rivet_radius: float = (band_bottom + band_top) * 0.5 + 0.004 * s
	for index: int in RIVETS:
		var out: Vector3 = Vector3(cos(TAU * index / RIVETS), 0.0, sin(TAU * index / RIVETS))
		_add(self, rivet, Transform3D(Basis.IDENTITY, out * rivet_radius + Vector3.UP * band_height * 0.5), KitPiece.Swatch.FROST)
	_add_steam_pipe(band_bottom + rock_slope * band_height * 0.3, band_height * 0.3)
	# Collar where it meets the rock, then the shaft down to the pod.
	_add_cylinder(self, 0.11 * s, 0.11 * s, 0.08 * s, -0.04 * s, KitPiece.Swatch.ABYSS)
	_add_cylinder(self, 0.035 * s, 0.035 * s, 0.14 * s, -0.15 * s, KitPiece.Swatch.FROST)
	# The motor pod, with a band round its middle.
	var pod: CapsuleMesh = CapsuleMesh.new()
	pod.radius = 0.09 * s
	pod.height = 0.32 * s
	pod.radial_segments = 16
	pod.rings = 4
	_add(self, pod, Transform3D(Basis.IDENTITY, Vector3(0, -0.36 * s, 0)), color)
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 0.085 * s
	band.outer_radius = 0.11 * s
	band.rings = 16
	band.ring_segments = 6
	_add(self, band, Transform3D(Basis.IDENTITY, Vector3(0, -0.36 * s, 0)), KitPiece.Swatch.CORAL)

	# The rotor: hub, nose cone and blades, turning together under the pod.
	_rotor = Node3D.new()
	_rotor.position.y = -0.56 * s
	add_child(_rotor)
	_add_cylinder(_rotor, 0.06 * s, 0.06 * s, 0.06 * s, 0.0, KitPiece.Swatch.CORAL)
	_add_cylinder(_rotor, 0.05 * s, 0.0, 0.1 * s, -0.08 * s, KitPiece.Swatch.CORAL)
	var length: float = 0.44 * s
	for index: int in BLADES:
		var turn: Basis = Basis(Vector3.UP, TAU * index / BLADES)
		# Blades run along -Z, so they pitch around it.
		var pitch: Basis = Basis(Vector3.BACK, deg_to_rad(BLADE_PITCH_DEGREES))
		var blade: BoxMesh = BoxMesh.new()
		blade.size = Vector3(0.16 * s, 0.035 * s, length)
		_add(_rotor, blade, Transform3D(turn * pitch, turn * Vector3(0, 0, -(0.06 * s + length * 0.5))), KitPiece.Swatch.MINT)
		var tip: BoxMesh = BoxMesh.new()
		tip.size = Vector3(0.165 * s, 0.04 * s, 0.06 * s)
		_add(_rotor, tip, Transform3D(turn * pitch, turn * Vector3(0, 0, -(0.06 * s + length - 0.03 * s))), KitPiece.Swatch.CORAL)

	# A faint disc where the blades sweep, so the spin reads as fast.
	var blur: CylinderMesh = CylinderMesh.new()
	blur.top_radius = 0.5 * s
	blur.bottom_radius = 0.5 * s
	blur.height = 0.004 * s
	blur.radial_segments = 32
	blur.rings = 1
	var disc: MeshInstance3D = _add(self, blur, Transform3D(Basis.IDENTITY, Vector3(0, -0.56 * s, 0)), KitPiece.Swatch.MINT)
	disc.material_override = _blur()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A little exhaust pipe out of the band ([param out_radius] from the middle, [param height] up)
## that bends down and puffs steam now and then.
func _add_steam_pipe(out_radius: float, height: float) -> void:
	var s: float = span
	var pipe_radius: float = 0.02 * s
	var reach: float = 0.12 * s
	var pipe: Node3D = Node3D.new()
	pipe.position = Vector3(out_radius - pipe_radius, height, 0.0)
	add_child(pipe)
	var along: CylinderMesh = CylinderMesh.new()
	along.top_radius = pipe_radius
	along.bottom_radius = pipe_radius
	along.height = reach
	along.radial_segments = 10
	along.rings = 1
	_add(pipe, along, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(reach * 0.5, 0.0, 0.0)), KitPiece.Swatch.SAND)
	_add_cylinder(pipe, pipe_radius, pipe_radius * 1.4, 0.08 * s, -0.04 * s, KitPiece.Swatch.SAND)
	(pipe.get_child(pipe.get_child_count() - 1) as Node3D).position.x = reach
	var puffs: GPUParticles3D = GPUParticles3D.new()
	puffs.amount = 4
	puffs.lifetime = 1.6
	puffs.position = Vector3(reach, -0.09 * s, 0.0)
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0.4, -1.0, 0.0)
	process.spread = 15.0
	process.initial_velocity_min = 0.25 * s
	process.initial_velocity_max = 0.35 * s
	process.gravity = Vector3.ZERO
	process.damping_min = 0.15 * s
	process.damping_max = 0.2 * s
	process.scale_min = 0.6
	process.scale_max = 1.0
	var grow: CurveTexture = CurveTexture.new()
	grow.curve = Curve.new()
	grow.curve.add_point(Vector2(0.0, 0.3))
	grow.curve.add_point(Vector2(1.0, 1.0))
	process.scale_curve = grow
	var fade: GradientTexture1D = GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(Palette.FROST, 0.8))
	fade.gradient.set_color(1, Color(Palette.FROST, 0.0))
	process.color_ramp = fade
	puffs.process_material = process
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.04 * s
	puff.height = 0.08 * s
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = _steam()
	puffs.draw_pass_1 = puff
	pipe.add_child(puffs)


static var _steam_material: StandardMaterial3D


static func _steam() -> StandardMaterial3D:
	if _steam_material == null:
		_steam_material = StandardMaterial3D.new()
		_steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_steam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_steam_material.vertex_color_use_as_albedo = true
	return _steam_material


func _add_cylinder(parent: Node3D, top: float, bottom: float, height: float, center_y: float, swatch: KitPiece.Swatch) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 16
	cylinder.rings = 1
	_add(parent, cylinder, Transform3D(Basis.IDENTITY, Vector3(0, center_y, 0)), swatch)


func _add(parent: Node3D, mesh: Mesh, at: Transform3D, swatch: KitPiece.Swatch) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = KitPiece.material_for(swatch)
	instance.transform = at
	parent.add_child(instance)
	return instance


static func _blur() -> StandardMaterial3D:
	if _blur_material == null:
		_blur_material = StandardMaterial3D.new()
		_blur_material.albedo_color = Color(Palette.MINT, 0.18)
		_blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blur_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blur_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _blur_material
