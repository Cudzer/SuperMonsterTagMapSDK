@tool
class_name KitBed
extends KitPiece
## A giant's bed, and a trampoline: land on the mattress and it throws you back up at bounce_speed,
## keeping most of your run, again and again until you hold crouch as you land. Underneath is a
## crawl space (under_height tall) behind a short valance, dark enough to hide in with a hiding spot.
##
## size is the footprint (x across, z long) and the mattress top's height (y). The headboard is at
## the back (-Z), the footboard at the front, and the origin is the middle of the footprint on the
## floor. color is the blanket, trim_color the wooden frame, sheet_color the sheet and pillows.
##
## Like a spring pad, it bounces players on their own machine; the squash and sound play everywhere.

@export var size: Vector3 = Vector3(13, 6, 24):
	set(value):
		size = Vector3(maxf(KitPiece.snap(value.x), 4.0), maxf(KitPiece.snap(value.y), 3.0), maxf(KitPiece.snap(value.z), 6.0))
		queue_build()
@export var trim_color: Swatch = Swatch.SAND:
	set(value):
		trim_color = value
		queue_build()
@export var sheet_color: Swatch = Swatch.CREAM:
	set(value):
		sheet_color = value
		queue_build()
## The crawl space under the frame.
@export var under_height: float = 3.0:
	set(value):
		under_height = clampf(value, 2.0, size.y - 1.5)
		queue_build()
## How fast the mattress throws a player up (m/s): 17 is about 9 m.
@export var bounce_speed: float = 17.0
## How much of a player's run carries through a bounce.
@export_range(0.0, 1.0) var keep_speed: float = 0.8

const FRAME: float = 0.8
const LEG: float = 1.2
const PILLOW_HEIGHT: float = 1.2
const DRAPE: float = 0.3

var _soft: Node3D
var _squash: Tween


func _init() -> void:
	color = Swatch.SKY


func _add_parts() -> void:
	var w: float = size.x
	var l: float = size.z
	var top: float = size.y
	var frame_top: float = under_height + FRAME
	var trim: Swatch = trim_color
	# Legs at the corners, the frame on them, and the head and foot boards.
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_solid_box(Vector3(x * (w - LEG) * 0.5, under_height * 0.5, z * (l - LEG) * 0.5), Vector3(LEG, under_height, LEG), trim)
	_solid_box(Vector3(0, under_height + FRAME * 0.5, 0), Vector3(w, FRAME, l), trim)
	var head_top: float = top + 5.0
	var foot_top: float = top + 1.5
	for x: float in [-1.0, 1.0]:
		_solid_box(Vector3(x * (w - LEG) * 0.5, head_top * 0.5, -l * 0.5 - LEG * 0.5), Vector3(LEG, head_top, LEG), trim)
		_solid_box(Vector3(x * (w - LEG) * 0.5, foot_top * 0.5, l * 0.5 + LEG * 0.5), Vector3(LEG, foot_top, LEG), trim)
		_add_cap(Vector3(x * (w - LEG) * 0.5, head_top, -l * 0.5 - LEG * 0.5), trim)
		_add_cap(Vector3(x * (w - LEG) * 0.5, foot_top, l * 0.5 + LEG * 0.5), trim)
	var head_bottom: float = under_height
	_solid_box(Vector3(0, (head_bottom + head_top - 0.8) * 0.5, -l * 0.5 - LEG * 0.5), Vector3(w - LEG * 2.0, head_top - 0.8 - head_bottom, 0.6), trim)
	_solid_box(Vector3(0, (head_bottom + foot_top - 0.4) * 0.5, l * 0.5 + LEG * 0.5), Vector3(w - LEG * 2.0, foot_top - 0.4 - head_bottom, 0.6), trim)
	# The valance: a short skirt round the sides and foot, with the crawl space open below it.
	var skirt_bottom: float = under_height - 1.0
	var skirt: Swatch = sheet_color
	for x: float in [-1.0, 1.0]:
		# Up to the frame's underside: above that the blanket hangs over the frame's side.
		_box(Vector3(x * (w * 0.5 + 0.1), (skirt_bottom + under_height) * 0.5, 0), Vector3(0.2, under_height - skirt_bottom, l - LEG * 2.0), skirt)
	# The soft parts (mattress, blanket, pillows) squash together when someone bounces.
	_soft = Node3D.new()
	_soft.position.y = frame_top
	_add_part(_soft)
	var mattress_top: float = top - 0.6
	_soft_box(Vector3(0, (mattress_top - frame_top) * 0.5, 0), Vector3(w - 0.6, mattress_top - frame_top, l - 0.6), sheet_color)
	# The blanket over the front two thirds, hanging over the sides and foot, its top edge folded back.
	var blanket_length: float = l * 0.68
	var blanket_center: float = l * 0.5 - blanket_length * 0.5
	_soft_box(Vector3(0, top - 0.3 - frame_top, blanket_center), Vector3(w, 0.6, blanket_length), color)
	for x: float in [-1.0, 1.0]:
		_soft_box(Vector3(x * (w * 0.5 + DRAPE * 0.5), top - 0.3 - frame_top - 1.2, blanket_center), Vector3(DRAPE, 3.0, blanket_length), color)
	# Down over the foot, just past the mattress end, between the footboard posts.
	_soft_box(Vector3(0, top - 1.5 - frame_top, l * 0.5 + DRAPE * 0.5), Vector3(w - LEG * 2.0, 3.0, DRAPE), color)
	_soft_box(Vector3(0, top + 0.15 - frame_top, blanket_center - blanket_length * 0.5 + 0.9), Vector3(w + 0.1, 0.3, 1.8), sheet_color)
	# Pillows against the headboard.
	var pillow_width: float = (w - 1.8) * 0.5
	for x: float in [-1.0, 1.0]:
		_soft_box(Vector3(x * (pillow_width * 0.5 + 0.3), mattress_top - frame_top + PILLOW_HEIGHT * 0.5, -l * 0.5 + 2.4), Vector3(pillow_width, PILLOW_HEIGHT, 3.6), sheet_color)
	# It collides as the blanketed part, the bare sheet by the pillows (lower), and the pillows.
	var blanketed: BoxShape3D = BoxShape3D.new()
	blanketed.size = Vector3(w, top - frame_top, blanket_length)
	add_shape(blanketed, Transform3D(Basis.IDENTITY, Vector3(0, (top + frame_top) * 0.5, blanket_center)))
	var sheet: BoxShape3D = BoxShape3D.new()
	sheet.size = Vector3(w, mattress_top - frame_top, l - blanket_length)
	add_shape(sheet, Transform3D(Basis.IDENTITY, Vector3(0, (mattress_top + frame_top) * 0.5, -l * 0.5 + (l - blanket_length) * 0.5)))
	var pillows: BoxShape3D = BoxShape3D.new()
	pillows.size = Vector3(w - 1.2, PILLOW_HEIGHT - 0.6, 3.6)
	add_shape(pillows, Transform3D(Basis.IDENTITY, Vector3(0, top + (PILLOW_HEIGHT - 0.6) * 0.5, -l * 0.5 + 2.4)))
	# The bounce: a trigger over the top.
	var trigger: Area3D = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var volume: CollisionShape3D = CollisionShape3D.new()
	var zone: BoxShape3D = BoxShape3D.new()
	# Low enough that a jump on the bed leaves it, so landing again bounces.
	zone.size = Vector3(w - 0.4, 1.6, l - 0.4)
	volume.shape = zone
	volume.position = Vector3(0, top + 0.5, 0)
	trigger.add_child(volume)
	if not Engine.is_editor_hint():
		trigger.body_entered.connect(_on_body_entered)
	_add_part(trigger)


## The bed's triangles, for Level Tools' click gizmo (the soft parts sit inside their own node).
func get_faces() -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for part: Node in _parts:
		if part is Node3D and not part is CollisionShape3D and not part is Area3D:
			LevelModel._gather_faces(part, (part as Node3D).transform, faces)
	return faces


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	# Only from above: someone climbing up the side brushes the trigger with their feet low.
	if player == null or player.global_position.y < global_position.y + size.y - 1.0:
		return
	_bounce(player.global_position)
	# Only falling onto it, on the player's own machine; holding crouch lands instead.
	if not player.is_multiplayer_authority() or player.velocity.y > -1.0:
		return
	if player.is_action_held(&"crouch"):
		return
	var run: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z) * keep_speed
	player.launch(run + Vector3.UP * bounce_speed)


func _bounce(at: Vector3) -> void:
	Sound.play_at(Sound.Sfx.JUMP_PAD, Fx.world_for(self), at)
	if _squash != null:
		_squash.kill()
	_soft.scale = Vector3(1.0, 0.8, 1.0)
	_squash = create_tween()
	_squash.tween_property(_soft, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _box(center: Vector3, box_size: Vector3, swatch: Swatch) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	return add_mesh(mesh, swatch, Transform3D(Basis.IDENTITY, center), false)


func _solid_box(center: Vector3, box_size: Vector3, swatch: Swatch) -> void:
	_box(center, box_size, swatch)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	add_shape(shape, Transform3D(Basis.IDENTITY, center))


## A box in the soft group (positions relative to the frame's top).
func _soft_box(center: Vector3, box_size: Vector3, swatch: Swatch) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material_for(swatch)
	instance.position = center
	_soft.add_child(instance)


## A round knob on a bedpost.
func _add_cap(at: Vector3, swatch: Swatch) -> void:
	var knob: SphereMesh = SphereMesh.new()
	knob.radius = LEG * 0.65
	knob.height = LEG * 1.3
	add_mesh(knob, swatch, Transform3D(Basis.IDENTITY, at + Vector3.UP * LEG * 0.45), false)
