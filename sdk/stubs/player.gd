class_name Player
extends CharacterBody3D
## Stands in for the game's Player in the Map SDK. The kit pieces and toys name it, but no player
## ever exists in the editor (playtests run in the game itself), so this only declares what they
## use, doing nothing. The SDK build copies the declarations marked @copy from the real script.
## It fails if a toy names a constant, enum or class missing here (the compiler checks those); a
## missing method would only fail when called, which never happens in the editor, but add new ones
## anyway, with the game's signature, so the stub stays a true picture.

# Copied from res://player/player.gd when the SDK was built.
const DEFAULT_GRAVITY_SCALE: float = 1.6

@export var sprint_speed: float = 13.0
@export var gravity_scale: float = DEFAULT_GRAVITY_SCALE
var is_frozen: bool = false


func is_local() -> bool:
	return false


func launch(_new_velocity: Vector3) -> void:
	pass


func teleport(_feet: Vector3) -> void:
	pass


func apply_speed_boost(_multiplier: float, _duration: float) -> void:
	pass


func try_grind(_rail: GrindRail) -> void:
	pass


func is_action_held(_action: StringName) -> bool:
	return false


func apply_updraft(_axis: Vector3, _speed: float, _acceleration: float) -> void:
	pass


func enter_hiding() -> void:
	pass


func leave_hiding() -> void:
	pass


func is_hidden() -> bool:
	return false
