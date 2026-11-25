@tool
class_name Strongman
extends Node3D
## The strongman's high striker, at the Game Stalls: slap the pad at the bottom and the puck shoots
## up the tower; hit it hard enough and it rings the bell at the top. A slap is as strong as the
## slapper is fast, so a sprinting slap rings it. Just for fun: nothing is scored.
##
## The slapper sends the strength to everyone (_strike, unreliable), so all see the same shot. The
## pad faces +Z. Its parts are internal children built in _ready.

const TOWER_HEIGHT: float = 7.0
## How far up the puck starts and the bell hangs.
const PUCK_START: float = 0.9
const BELL_HEIGHT: float = 6.4

var _puck: Node3D
var _bell: Node3D
var _shot: Tween


func _ready() -> void:
	_build()


func _on_pad_slapped(player: Player) -> void:
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var strength: float = clampf(0.45 + 0.55 * speed / player.sprint_speed + randf_range(-0.05, 0.08), 0.3, 1.0)
	_strike.rpc(strength)


@rpc("any_peer", "call_local", "unreliable")
func _strike(strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	if _shot != null:
		_shot.kill()
	var world: Node = Fx.world_for(self)
	var peak: float = lerpf(PUCK_START, BELL_HEIGHT - 0.35, strength)
	_puck.position.y = PUCK_START
	_shot = create_tween()
	_shot.tween_property(_puck, "position:y", peak, 0.25 + 0.35 * strength).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if strength >= 0.97:
		_shot.tween_callback(func() -> void:
			Sound.play_at(Sound.Sfx.COIN, world, _bell.global_position, 0.05, 4.0)
			Fx.burst(world, _bell.global_position, Palette.SUNBURST, 26, 6.0, 0.09, 0.6, -5.0)
			Fx.ring(world, _bell.global_position, Palette.SUNBURST, 2.0, 0.3)
			_bell.scale = Vector3.ONE * 1.35
			create_tween().tween_property(_bell, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC))
	_shot.tween_property(_puck, "position:y", PUCK_START, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sound.play_at(Sound.Sfx.SLAP, world, global_position + Vector3(0, 0.5, 0.6), 0.1, 1.0)


func _build() -> void:
	var tool: SurfaceTool = MidwayMeshes.begin()
	# The tower: a tall board with a strength scale up it (coloured bands, cool to hot), on a base.
	MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, -0.4)), Vector3(1.6, 0.6, 1.0), Palette.BERRY)
	MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, TOWER_HEIGHT * 0.5, -0.6)), Vector3(0.9, TOWER_HEIGHT, 0.3), Palette.CREAM)
	var bands: Array[Color] = [Palette.TEAL, Palette.SEAFOAM, Palette.MOSS, Palette.SUNBURST, Palette.CORAL, Palette.BERRY]
	for index: int in bands.size():
		var y: float = PUCK_START + (BELL_HEIGHT - PUCK_START) * (index + 0.5) / bands.size()
		MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, y, -0.44)), Vector3(0.7, (BELL_HEIGHT - PUCK_START) / bands.size() - 0.08, 0.04), bands[index], MidwayMeshes.SOFT)
	# The guide wire the puck rides, and a bulb either side up the whole way.
	MidwayMeshes.bar(tool, Vector3(0.0, PUCK_START, -0.3), Vector3(0.0, BELL_HEIGHT, -0.3), 0.03, Palette.SUNBURST)
	for side: float in [-1.0, 1.0]:
		MidwayMeshes.bulbs(tool, Vector3(side * 0.5, 0.8, -0.44), Vector3(side * 0.5, TOWER_HEIGHT - 0.2, -0.44), 0.5, 0.07, 1 if side > 0 else 3)
	# A star on top.
	MidwayMeshes.ball(tool, Vector3(0.0, TOWER_HEIGHT + 0.35, -0.6), 0.35, Palette.SUNBURST, MidwayMeshes.LIT)
	_add_part(MidwayMeshes.instance(tool))
	var tower: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.6, TOWER_HEIGHT, 1.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, TOWER_HEIGHT * 0.5, -0.5)
	tower.add_child(collision)
	_add_part(tower)

	# The bell, and the puck that flies up to it.
	_bell = Node3D.new()
	_bell.position = Vector3(0.0, BELL_HEIGHT, -0.25)
	var bell: SurfaceTool = MidwayMeshes.begin()
	MidwayMeshes.cylinder(bell, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.1), 0.4, 0.45, Palette.SUNBURST, MidwayMeshes.SOFT, 14, 0.15)
	_bell.add_child(MidwayMeshes.instance(bell))
	_add_part(_bell)
	_puck = Node3D.new()
	_puck.position = Vector3(0.0, PUCK_START, -0.25)
	var puck: SurfaceTool = MidwayMeshes.begin()
	MidwayMeshes.cylinder(puck, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.12), 0.22, 0.24, Palette.CORAL, MidwayMeshes.LIT, 10)
	_puck.add_child(MidwayMeshes.instance(puck))
	_add_part(_puck)

	# The pad to slap: a big red button on a stand in front.
	var pad: SlapTarget = SlapTarget.new()
	pad.position = Vector3(0.0, 0.0, 0.5)
	var look: SurfaceTool = MidwayMeshes.begin()
	MidwayMeshes.cylinder(look, Transform3D(Basis.IDENTITY, Vector3.ZERO), 0.35, 0.8, Palette.ABYSS.lightened(0.15), MidwayMeshes.PLAIN, 10)
	MidwayMeshes.cylinder(look, Transform3D(Basis.IDENTITY, Vector3.UP * 0.8), 0.55, 0.25, Palette.CORAL, MidwayMeshes.SOFT, 14)
	pad.add_child(MidwayMeshes.instance(look))
	var stand: CylinderShape3D = CylinderShape3D.new()
	stand.radius = 0.55
	stand.height = 1.05
	var volume: CollisionShape3D = CollisionShape3D.new()
	volume.shape = stand
	volume.position = Vector3.UP * 0.525
	pad.add_child(volume)
	if not Engine.is_editor_hint():
		pad.slapped.connect(_on_pad_slapped)
	_add_part(pad)


## For Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	return MidwayMeshes.faces_of(self)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
