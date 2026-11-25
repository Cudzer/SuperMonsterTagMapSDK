@tool
class_name UpdraftFan
extends Area3D
## A fan that blows a column of wind up its own axis (tilt it to blow sideways). Players inside
## the column are pushed toward lift_speed along it: off the ground, up to the top and a little
## beyond, and anyone falling through it is slowed. It has no collision: place it on a surface.
##
## Movement is client-authoritative, so every peer tracks who's inside but only a player's own
## machine pushes them (Player.apply_updraft()). The blades and wind streaks are cosmetic.

## The column's height and radius (m). The trigger, the faint column and the streaks follow them,
## in the editor too.
@export var height: float = 8.0:
	set(value):
		height = maxf(value, 1.0)
		_resize()
@export var radius: float = 1.2:
	set(value):
		radius = maxf(value, 0.5)
		_resize()
## The speed the wind pushes toward along the axis, and how hard (m/s²; gravity is about 15.7).
@export var lift_speed: float = 10.0
@export var lift_acceleration: float = 45.0

const BLADE_SPIN: float = 12.0

var _inside: Array[Player] = []

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var column: MeshInstance3D = $Column
@onready var wind: CPUParticles3D = $Wind
@onready var blades: Node3D = $Blades


func _ready() -> void:
	_resize()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return
	body_entered.connect(func(body: Node3D) -> void:
		var player: Player = body as Player
		if player != null and not _inside.has(player):
			_inside.append(player))
	body_exited.connect(func(body: Node3D) -> void: _inside.erase(body as Player))


func _physics_process(_delta: float) -> void:
	var axis: Vector3 = global_basis.y.normalized()
	for player: Player in _inside:
		if is_instance_valid(player) and player.is_multiplayer_authority():
			player.apply_updraft(axis, lift_speed, lift_acceleration)


func _process(delta: float) -> void:
	blades.rotate_y(BLADE_SPIN * delta)


func _resize() -> void:
	if not is_node_ready():
		return
	var shape: CylinderShape3D = collision_shape.shape as CylinderShape3D
	shape.height = height
	shape.radius = radius
	collision_shape.position.y = height / 2.0
	var tube: CylinderMesh = column.mesh as CylinderMesh
	tube.height = height
	tube.top_radius = radius
	tube.bottom_radius = radius
	column.position.y = height / 2.0
	wind.emission_ring_radius = radius * 0.85
	wind.emission_ring_inner_radius = radius * 0.2
	# Streaks rise at about the lift speed and fade out at the top.
	wind.lifetime = height / maxf(lift_speed, 1.0)
	wind.initial_velocity_min = lift_speed * 0.85
	wind.initial_velocity_max = lift_speed * 1.15
