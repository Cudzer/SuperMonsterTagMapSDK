class_name BounceZone
extends Area3D
## A trampoline in Monster Midway: a bouncy castle's floor, the Big Top's safety net. An invisible
## box over something soft (its origin on the soft surface) that throws anyone landing on it back
## up at bounce_speed, keeping some of their run, like KitBed's mattress. Holding crouch lands.
##
## Like a spring pad, it bounces players on their own machine (launch() counts as a pad bounce for
## the onboarding checklist); the squash and sound play everywhere.

## The bouncy surface's footprint (x, z), and how far over it the zone reaches (y).
@export var size: Vector3 = Vector3(4.0, 1.6, 4.0)
## m/s upward: 11 is about 4 m.
@export var bounce_speed: float = 11.0
@export_range(0.0, 1.0) var keep_speed: float = 0.6
## Squashed on every bounce (the cushion's look), if set.
@export var soft: Node3D

var _squash: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var volume: CollisionShape3D = CollisionShape3D.new()
	volume.shape = shape
	volume.position = Vector3.UP * size.y * 0.5
	add_child(volume)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	# Only from above: someone walking into the side brushes the zone with their feet low.
	if player == null or player.global_position.y < global_position.y - 0.3:
		return
	_bounce(player.global_position)
	if not player.is_multiplayer_authority() or player.velocity.y > -1.0:
		return
	if player.is_action_held(&"crouch"):
		return
	var run: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z) * keep_speed
	player.launch(run + Vector3.UP * bounce_speed)


func _bounce(at: Vector3) -> void:
	Sound.play_at(Sound.Sfx.JUMP_PAD, Fx.world_for(self), at, 0.15, -4.0)
	if soft == null:
		return
	if _squash != null:
		_squash.kill()
	soft.scale = Vector3(1.0, 0.85, 1.0)
	_squash = create_tween()
	_squash.tween_property(soft, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
