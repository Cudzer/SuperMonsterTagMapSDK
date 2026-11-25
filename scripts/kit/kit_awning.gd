@tool
class_name KitAwning
extends KitPiece
## A striped shop awning sticking out of a wall, and a bouncy one: drop onto it and it throws you
## up and back over the wall it hangs on, so it's a way up onto a roof (jump onto it from a crate,
## or drop onto it from above). Its origin is where it meets the wall, and it sticks out along +Z
## (face that away from the wall), sloping down to a scalloped edge.
##
## It has no solid collision, only a trigger over the canvas. Movement is client-authoritative, so
## like a spring pad it bounces players on their own machine; the squash and sound play everywhere.
## color and trim_color are its stripes.

const STRIPE_WIDTH: float = 0.5
const SLOPE_DROP: float = 0.6
const VALANCE: float = 0.3

@export var width: float = 4.0:
	set(value):
		width = maxf(KitPiece.snap(value), 1.0)
		queue_build()
## How far it sticks out from the wall.
@export var depth: float = 2.0:
	set(value):
		depth = maxf(KitPiece.snap(value), 1.0)
		queue_build()
@export var trim_color: Swatch = Swatch.CREAM:
	set(value):
		trim_color = value
		queue_build()
## How fast it throws a player up, and back toward the wall (m/s).
@export var bounce_speed: float = 11.0
@export var wall_push: float = 3.5
## How far above it the throw keeps carrying you toward the wall. The wall stops a player rising
## beside it, so without this they'd go straight up and miss a tall roof; this way they carry on over
## its edge once they clear it.
@export var carry_height: float = 6.5

## How long after a bounce the carry lasts (s), and how hard it eases you toward the wall.
const CARRY_SECONDS: float = 1.2
const CARRY_ACCELERATION: float = 60.0

var _canvas: MeshInstance3D
var _squash: Tween
## Owner only: players this awning has just thrown, and when.
var _carried: Dictionary[Player, float] = {}
## Physics time, for the carry (frame time, so hit-stop and fixed-rate tests count it right).
var _time: float = 0.0


func _init() -> void:
	color = Swatch.CORAL


func _add_parts() -> void:
	# Faceted, so each side of the two-sided canvas lights as itself.
	var tool: SurfaceTool = IslandMeshes.flat_tool()
	var stripes: int = maxi(roundi(width / STRIPE_WIDTH), 1)
	var colors: Array[Color] = [SWATCH_COLORS[color], SWATCH_COLORS[trim_color]]
	for stripe: int in stripes:
		var x0: float = -width * 0.5 + width * stripe / stripes
		var x1: float = -width * 0.5 + width * (stripe + 1) / stripes
		var stripe_color: Color = colors[stripe % 2]
		var back_left: Vector3 = Vector3(x0, 0.0, 0.0)
		var back_right: Vector3 = Vector3(x1, 0.0, 0.0)
		var front_left: Vector3 = Vector3(x0, -SLOPE_DROP, depth)
		var front_right: Vector3 = Vector3(x1, -SLOPE_DROP, depth)
		# The canvas, both sides.
		_two_sided(tool, [back_left, back_right, front_right, front_left], stripe_color)
		# The valance: a scallop hanging off the front edge.
		var middle: Vector3 = Vector3((x0 + x1) * 0.5, -SLOPE_DROP - VALANCE, depth)
		_two_sided(tool, [front_left, front_right, front_right + Vector3.DOWN * VALANCE * 0.45, middle, front_left + Vector3.DOWN * VALANCE * 0.45], stripe_color)
	_canvas = add_mesh(IslandMeshes.commit_flat(tool), color, Transform3D.IDENTITY, false)
	_canvas.material_override = IslandMeshes.material()
	# Brackets from the wall up to the front corners.
	for side: float in [-1.0, 1.0]:
		var bracket: CylinderMesh = CylinderMesh.new()
		bracket.top_radius = 0.035
		bracket.bottom_radius = 0.035
		bracket.height = Vector2(depth, 0.7).length()
		bracket.radial_segments = 6
		bracket.rings = 1
		var from: Vector3 = Vector3(side * (width * 0.5 - 0.1), -SLOPE_DROP - 0.7, 0.0)
		var to: Vector3 = Vector3(side * (width * 0.5 - 0.1), -SLOPE_DROP, depth)
		# Tilted from upright to run from the wall out to the corner.
		add_mesh(bracket, Swatch.ASPHALT, Transform3D(Basis(Vector3.RIGHT, atan2(depth, 0.7)), (from + to) * 0.5), false)

	var trigger: Area3D = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var volume: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, 0.6, depth)
	volume.shape = box
	volume.position = Vector3(0.0, -SLOPE_DROP * 0.5 + 0.2, depth * 0.5)
	trigger.add_child(volume)
	if not Engine.is_editor_hint():
		trigger.body_entered.connect(_on_body_entered)
	_add_part(trigger)


## A polygon (fanned from its first point) facing both ways.
static func _two_sided(tool: SurfaceTool, points: Array, color: Color) -> void:
	for index: int in range(1, points.size() - 1):
		for corners: Array in [[points[0], points[index], points[index + 1]], [points[0], points[index + 1], points[index]]]:
			IslandMeshes.triangle(tool, corners[0], corners[1], corners[2], color, IslandMeshes.PLAIN)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	# Only from above: someone walking underneath brushes the trigger with their head.
	if player.global_position.y < global_position.y - SLOPE_DROP - 0.35:
		return
	_bounce()
	# Only falling onto it, and only on the player's own machine.
	if not player.is_multiplayer_authority() or player.velocity.y > 1.0:
		return
	var back: Vector3 = -global_basis.z.normalized()
	var along: Vector3 = global_basis.x.normalized()
	var carried: Vector3 = along * player.velocity.dot(along)
	player.launch(carried + back * wall_push + Vector3.UP * bounce_speed)
	_carried[player] = _time


## Keeps easing just-thrown players toward the wall while they're still in front of it, below
## carry_height.
func _physics_process(delta: float) -> void:
	_time += delta
	if _carried.is_empty():
		return

	for player: Player in _carried.keys():
		if not is_instance_valid(player) or _time - _carried[player] > CARRY_SECONDS:
			_carried.erase(player)
			continue
		var local: Vector3 = to_local(player.global_position)
		if local.z > 0.0 and local.z < depth + 0.6 and local.y < carry_height and absf(local.x) < width * 0.5 + 0.6:
			player.apply_updraft(-global_basis.z.normalized(), wall_push, CARRY_ACCELERATION)


func _bounce() -> void:
	Sound.play_at(Sound.Sfx.JUMP_PAD, Fx.world_for(self), global_position)
	if _squash != null:
		_squash.kill()
	_canvas.scale = Vector3(1.0, 0.6, 1.0)
	_squash = create_tween()
	_squash.tween_property(_canvas, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
