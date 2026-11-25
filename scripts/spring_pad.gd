@tool
class_name SpringPad
extends Area3D
## Launches players along the pad's up axis when they step or land on it, so tilting the pad
## launches at an angle. The pad has no collision of its own: place it on a surface. Movement is
## client-authoritative, so only the player's own machine launches them; the bounce animation
## plays on every peer.
##
## Aimed pads (set up in the editor, usually by dragging the Level Tools landing handle) tilt
## themselves toward aim_target and work out launch_speed from launch_angle, and re-aim when moved.
## Launched players fly a plain ballistic arc (no air drag), and in game an aimed pad solves the
## throw from where the player actually touched it, so they land on target from anywhere on the pad.

## Speed along the pad's up axis. 18 reaches about 10 m straight up (with Player.gravity_scale 1.6).
@export var launch_speed: float = 18.0
## Keep the player's speed across the pad, so running onto it carries them forward. Aimed pads
## turn it off so every launch flies the same arc.
@export var keep_momentum: bool = true

@export_group("Aim")
## Editor only: keep the pad pointed at aim_target with the speed to land there.
@export var aimed: bool = false:
	set(value):
		aimed = value
		_reaim()
## Where launched players should land (their feet), in the parent's space like position.
@export var aim_target: Vector3 = Vector3.ZERO:
	set(value):
		aim_target = value
		_reaim()
## Launch elevation above horizontal. Higher arcs clear more but take longer.
@export_range(15.0, 85.0, 1.0, "degrees") var launch_angle: float = 55.0:
	set(value):
		launch_angle = value
		_reaim()

var _top_rest_y: float = 0.0
var _bounce_tween: Tween

@onready var top: MeshInstance3D = $Top


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_reaim()
		return
	_top_rest_y = top.position.y
	body_entered.connect(_on_body_entered)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_reaim()


## Whether an aimed pad can reach its target at its launch angle (too high a target can't be).
func can_reach_target() -> bool:
	return not aimed or not solve_aim(global_position, get_target_global(), launch_angle).is_empty()


func get_target_global() -> Vector3:
	var parent: Node3D = get_parent() as Node3D
	return parent.to_global(aim_target) if parent != null else aim_target


## Where a player launched from the pad's center is every [param step] seconds, from the pad
## until [param max_time] or [param max_drop] meters below it. Assumes they stepped on standing
## still, so momentum pads carry nothing extra.
func flight_path(step: float = 0.05, max_time: float = 8.0, max_drop: float = 40.0) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var start: Vector3 = global_position
	var velocity: Vector3 = global_basis.y.normalized() * launch_speed
	var gravity: Vector3 = Vector3.DOWN * player_gravity()
	var time: float = 0.0
	while time <= max_time:
		var point: Vector3 = start + velocity * time + gravity * (0.5 * time * time)
		points.append(point)
		if point.y < start.y - max_drop:
			break
		time += step
	return points


## The pad's tilt (a basis whose up axis is the launch direction) and speed that throw a player
## from [param from] to [param to] at [param angle_degrees] above horizontal:
## {"basis", "speed"}. Empty if the target is too high for that angle or straight overhead.
static func solve_aim(from: Vector3, to: Vector3, angle_degrees: float) -> Dictionary:
	var offset: Vector3 = to - from
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var distance: float = flat.length()
	var angle: float = deg_to_rad(angle_degrees)
	var denominator: float = 2.0 * pow(cos(angle), 2.0) * (distance * tan(angle) - offset.y)
	if distance < 0.5 or denominator <= 0.0:
		return {}
	var heading: Vector3 = flat / distance
	var up: Vector3 = heading * cos(angle) + Vector3.UP * sin(angle)
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	return {
		"basis": Basis(right, up, right.cross(up)),
		"speed": sqrt(player_gravity() * distance * distance / denominator),
	}


## The downward acceleration on players: the project's gravity times Player.gravity_scale. It
## reads the constant, because exported builds can't look up a script's property defaults.
static func player_gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * Player.DEFAULT_GRAVITY_SCALE


## Editor only. Points an aimed pad at its target; leaves it alone if the target is unreachable.
## Compares first, because each change sends another transform notification.
func _reaim() -> void:
	if not Engine.is_editor_hint() or not aimed or not is_inside_tree():
		return
	var solution: Dictionary = solve_aim(global_position, get_target_global(), launch_angle)
	if solution.is_empty():
		return
	var aim_basis: Basis = solution["basis"]
	if not global_basis.is_equal_approx(aim_basis):
		global_basis = aim_basis
	if not is_equal_approx(launch_speed, solution["speed"]):
		launch_speed = solution["speed"]
	keep_momentum = false
	update_gizmos()


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_bounce()
	if not player.is_multiplayer_authority():
		return
	# Aimed pads throw from wherever the player touched the trigger, so every launch lands on target.
	if aimed:
		var solution: Dictionary = solve_aim(player.global_position, get_target_global(), launch_angle)
		if not solution.is_empty():
			player.launch((solution["basis"] as Basis).y * float(solution["speed"]))
			return
	var up: Vector3 = global_transform.basis.y.normalized()
	var carried: Vector3 = player.velocity.slide(up) if keep_momentum else Vector3.ZERO
	player.launch(carried + up * launch_speed)


func _bounce() -> void:
	Sound.play_at(Sound.Sfx.JUMP_PAD, Fx.world_for(self), global_position)
	Fx.ring(Fx.world_for(self), global_position + global_transform.basis.y * 0.2, Palette.SUNBURST, 2.2, 0.35)
	if _bounce_tween != null:
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(top, "position:y", _top_rest_y - 0.04, 0.05)
	_bounce_tween.tween_property(top, "position:y", _top_rest_y + 0.15, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(top, "position:y", _top_rest_y, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
