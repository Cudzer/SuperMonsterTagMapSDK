@tool
class_name SpinningTop
extends MovingPlatform
## A giant spinning top, balanced on its tip and turning for ever: jump onto its flat top and ride
## it round (it's a SPIN MovingPlatform, so it carries riders and needs no networking). A striped
## body, a rim, a cone down to the tip, and a knob on top. radius sizes it all; color and
## stripe_color are the stripes, accent_color the rim and knob.

@export var radius: float = 3.0:
	set(value):
		radius = maxf(KitPiece.snap(value), 1.5)
		_queue_build()
@export var stripe_color: KitPiece.Swatch = KitPiece.Swatch.CREAM:
	set(value):
		stripe_color = value
		_queue_build()
@export var accent_color: KitPiece.Swatch = KitPiece.Swatch.SUNBURST:
	set(value):
		accent_color = value
		_queue_build()


func _init() -> void:
	motion = Motion.SPIN
	spin_speed = 70.0
	color = KitPiece.Swatch.CORAL


## The height of its flat top.
func get_top_height() -> float:
	return radius * 0.85


func _build() -> void:
	_build_queued = false
	for part: Node in _parts:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_parts.clear()
	var r: float = radius
	var top: float = get_top_height()
	var main: Color = KitPiece.SWATCH_COLORS[color]
	var stripe: Color = KitPiece.SWATCH_COLORS[stripe_color]
	var accent: Color = KitPiece.SWATCH_COLORS[accent_color]
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var knob: float = 0.18 * r
	IslandMeshes.lathe(tool, PackedVector3Array([
		Vector3(0, top + 0.45 * r, 0), Vector3(knob * 0.8, top + 0.42 * r, 0), Vector3(knob, top + 0.32 * r, 0),
		Vector3(knob * 0.7, top + 0.05, 0), Vector3(knob * 1.4, top, 0), Vector3(r * 0.92, top, 0),
		Vector3(r, top - 0.06 * r, 0), Vector3(r, top - 0.22 * r, 0), Vector3(r * 0.9, top - 0.3 * r, 0),
		Vector3(r * 0.45, top * 0.35, 0), Vector3(0.08 * r, 0.04, 0), Vector3(0, 0, 0),
	]), 16, [accent, accent, accent, accent, [main, stripe], accent, accent.darkened(0.1), [main, stripe],
		[main.darkened(0.1), stripe.darkened(0.1)], main.darkened(0.25), main.darkened(0.3)], Vector2(0.25, 0.0))
	var look: MeshInstance3D = MeshInstance3D.new()
	look.mesh = tool.commit()
	look.material_override = IslandMeshes.material()
	# It collides as the body under the top (a cylinder), the cone to the tip and the knob.
	var body: CylinderShape3D = CylinderShape3D.new()
	body.radius = r
	body.height = 0.3 * r
	var body_collision: CollisionShape3D = CollisionShape3D.new()
	body_collision.shape = body
	body_collision.position.y = top - 0.15 * r
	var cone: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
	for corner: int in 12:
		points.append(IslandMeshes.around(TAU * corner / 12.0) * r * 0.9 + Vector3.UP * (top - 0.3 * r))
	cone.points = points
	var cone_collision: CollisionShape3D = CollisionShape3D.new()
	cone_collision.shape = cone
	var handle: CylinderShape3D = CylinderShape3D.new()
	handle.radius = knob
	handle.height = 0.45 * r
	var handle_collision: CollisionShape3D = CollisionShape3D.new()
	handle_collision.shape = handle
	handle_collision.position.y = top + 0.225 * r
	for part: Node in [look, body_collision, cone_collision, handle_collision]:
		add_child(part, false, Node.INTERNAL_MODE_BACK)
		_parts.append(part)
	if Engine.is_editor_hint():
		update_gizmos()
