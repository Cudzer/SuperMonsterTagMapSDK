class_name SlapTarget
extends AnimatableBody3D
## Something solid to slap for fun (Whack-a-Monster's heads, the strongman's pad). A slap hitbox
## that touches it calls on_slapped() on the slapper's machine, and this passes it on; the owner
## decides what happens and tells everyone (nothing here changes the game).
##
## An AnimatableBody3D, because slap hitboxes (areas) never detect static bodies.

## On the slapper's machine only.
signal slapped(player: Player)


func _init() -> void:
	sync_to_physics = false


func on_slapped(player: Player) -> void:
	slapped.emit(player)
