class_name SpeedBoostPad
extends Area3D
## Gives players a timed speed boost when they cross it, from any direction. Like the spring pad,
## only the player's own machine applies the boost; the flash plays on every peer.

## Multiplies the player's movement speeds while boosted.
@export var speed_multiplier: float = 1.5
@export var boost_duration: float = 3.0

var _flash_tween: Tween

@onready var surface: MeshInstance3D = $Surface


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_flash()
	if player.is_multiplayer_authority():
		player.apply_speed_boost(speed_multiplier, boost_duration)


func _flash() -> void:
	Fx.burst(Fx.world_for(self), global_position + Vector3.UP * 0.2, Palette.BERRY, 20, 5.0, 0.08, 0.35, 2.0, 25.0)
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(amount: float) -> void:
		surface.set_instance_shader_parameter(&"flash", amount), 1.0, 0.0, 0.5)
