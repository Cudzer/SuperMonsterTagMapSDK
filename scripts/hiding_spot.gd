@tool
class_name HidingSpot
extends Area3D
## A bush or haystack anyone can duck into. Players inside are hidden: other players don't see
## them, their name tag or their talk badge, and a hidden tagger doesn't set off threat sense
## (Player.is_hidden()). It's a gamble, not a safe zone: the hidden body is still solid and can be
## slapped, so a tagger who swipes into the bush still tags whoever's in it, and the bush rustles
## (a shake, a puff of leaves or straw, and a sound) whenever someone goes in or comes out.
##
## No networking: every peer sees every player's body (positions are replicated), so each one
## works out who's inside by itself.

## NONE draws nothing: the cover is something else in the level (a toy box, the dark under a bed),
## and the hiding space is hide_box.
enum Style { BUSH, HAYSTACK, NONE }

## Saved by index, so only append.
@export var style: Style = Style.BUSH:
	set(value):
		style = value
		_show_style()
## For NONE: the box anyone inside is hidden in, standing on the spot's origin.
@export var hide_box: Vector3 = Vector3(4, 2, 4):
	set(value):
		hide_box = value
		_show_style()

const PUFF_COLORS: Array[Color] = [Palette.MOSS, Palette.SAND, Palette.CREAM]

var _shake_tween: Tween
var _bush_shape: Shape3D
## Between _exit_tree() and leaving: the bodies inside go without a rustle.
var _leaving: bool = false

@onready var bush: Node3D = $Bush
@onready var haystack: Node3D = $Haystack
@onready var rustle: AudioStreamPlayer3D = $Rustle
@onready var volume: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_show_style()
	if Engine.is_editor_hint():
		return
	rustle.stream = Sound.rustle_stream()
	body_entered.connect(func(body: Node3D) -> void:
		var player: Player = body as Player
		if player != null:
			player.enter_hiding()
			_rustle())
	body_exited.connect(func(body: Node3D) -> void:
		var player: Player = body as Player
		if player != null:
			player.leave_hiding()
			# Leaving the tree (the level swapped out under a hider) lets them go quietly: the burst
			# couldn't join a level being taken apart, and was left over (the long session found it).
			if not _leaving:
				_rustle())



func _enter_tree() -> void:
	_leaving = false


## Before the Area3D's own exit, which lets go of the bodies inside (body_exited).
func _exit_tree() -> void:
	_leaving = true


func _show_style() -> void:
	if not is_node_ready():
		return
	bush.visible = style == Style.BUSH
	haystack.visible = style == Style.HAYSTACK
	if _bush_shape == null:
		_bush_shape = volume.shape
	if style == Style.NONE:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = hide_box
		volume.shape = box
		volume.position = Vector3.UP * hide_box.y * 0.5
	else:
		volume.shape = _bush_shape
		volume.position = Vector3.UP


func _rustle() -> void:
	if style != Style.NONE:
		var visual: Node3D = bush if style == Style.BUSH else haystack
		if _shake_tween != null:
			_shake_tween.kill()
		visual.rotation = Vector3.ZERO
		_shake_tween = create_tween()
		for angle: float in [0.09, -0.07, 0.05, -0.03, 0.0]:
			_shake_tween.tween_property(visual, "rotation:z", angle, 0.06)
	Fx.burst(Fx.world_for(self), global_position + Vector3.UP * 1.3, PUFF_COLORS[style], 10, 3.0, 0.07, 0.5, -5.0)
	rustle.pitch_scale = randf_range(0.85, 1.15)
	Sound.caption("Rustling", global_position)
	rustle.play()
