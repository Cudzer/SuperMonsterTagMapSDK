@tool
class_name CollapsingPlatform
extends KitBox
## A platform that gives way: once a player stands on it, it shakes for shake_seconds, then
## drops away (no collision, so whoever's on it falls), and comes back respawn_seconds later. A
## kit box otherwise: sized and colored the same way, clickable in Level Tools.
##
## The host decides, since it sees everyone, and tells every peer through _set_phase, so it falls
## at the same moment for everyone. It never comes back while someone is inside its space. Peers
## who join while it's down see it up until it next changes.

enum Phase { SOLID, SHAKING, FALLEN }

@export var shake_seconds: float = 1.0
@export var respawn_seconds: float = 5.0

## How far it drops (m) and how long that takes, fading out as it goes.
const FALL_DISTANCE: float = 4.0
const FALL_SECONDS: float = 0.6
## How far it rattles while shaking.
const SHAKE_AMOUNT: float = 0.06
## Standing on it: feet no lower than this below its top.
const STAND_TOLERANCE: float = 0.15

var _phase: Phase = Phase.SOLID
var _phase_left: float = 0.0
var _trigger: Area3D
var _tween: Tween


func _init() -> void:
	color = KitPiece.Swatch.CORAL


func _add_parts() -> void:
	super()
	# Covers the box and a little above it: who's standing on it, and whether it's clear to return.
	_trigger = Area3D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 1
	_trigger.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x, size.y + 0.6, size.z)
	shape.shape = box
	shape.position = Vector3.UP * (size.y + 0.6) * 0.5
	_trigger.add_child(shape)
	_add_part(_trigger)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _trigger == null:
		return
	if _phase == Phase.SHAKING:
		var jitter: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE_AMOUNT
		for mesh: MeshInstance3D in _meshes():
			mesh.position = _rest_position(mesh) + jitter
	_phase_left = maxf(_phase_left - delta, 0.0)
	if not multiplayer.is_server():
		return
	match _phase:
		Phase.SOLID:
			if _someone_standing():
				_set_phase.rpc(Phase.SHAKING)
		Phase.SHAKING:
			if _phase_left <= 0.0:
				_set_phase.rpc(Phase.FALLEN)
		Phase.FALLEN:
			if _phase_left <= 0.0 and _trigger.get_overlapping_bodies().filter(func(body: Node3D) -> bool: return body is Player).is_empty():
				_set_phase.rpc(Phase.SOLID)


@rpc("authority", "call_local", "reliable")
func _set_phase(phase: Phase) -> void:
	_phase = phase
	if _tween != null:
		_tween.kill()
	match phase:
		Phase.SHAKING:
			_phase_left = shake_seconds
		Phase.FALLEN:
			_phase_left = respawn_seconds
			_set_solid(false)
			Fx.burst(Fx.world_for(self), global_position + Vector3.UP * size.y, Palette.SAND, 16, 4.0, 0.12, 0.5, -6.0)
			_tween = create_tween().set_parallel()
			for mesh: MeshInstance3D in _meshes():
				_tween.tween_property(mesh, "position", _rest_position(mesh) + Vector3.DOWN * FALL_DISTANCE, FALL_SECONDS) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_tween.tween_property(mesh, "transparency", 1.0, FALL_SECONDS)
		Phase.SOLID:
			_set_solid(true)
			_tween = create_tween().set_parallel()
			for mesh: MeshInstance3D in _meshes():
				mesh.position = _rest_position(mesh)
				mesh.scale = Vector3.ONE * 0.6
				_tween.tween_property(mesh, "transparency", 0.0, 0.25)
				_tween.tween_property(mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _someone_standing() -> bool:
	var top: float = global_position.y + size.y
	for body: Node3D in _trigger.get_overlapping_bodies():
		if body is Player and body.global_position.y >= top - STAND_TOLERANCE:
			return true
	return false


func _set_solid(solid: bool) -> void:
	for part: Node in get_children(true):
		if part is CollisionShape3D:
			(part as CollisionShape3D).set_deferred(&"disabled", not solid)


func _meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for part: Node in get_children(true):
		if part is MeshInstance3D:
			meshes.append(part as MeshInstance3D)
	return meshes


## A box mesh's resting place: KitBox centers it half its height up.
func _rest_position(_mesh: MeshInstance3D) -> Vector3:
	return Vector3.UP * size.y * 0.5
