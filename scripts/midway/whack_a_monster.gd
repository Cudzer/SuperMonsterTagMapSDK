@tool
class_name WhackAMonster
extends Node3D
## Whack-a-Monster, at the Game Stalls: a counter with a row of holes, and monster heads popping up
## out of them. Slap one (either hand) and it gets bonked back down with a puff of stars. Just for
## fun while waiting: nothing is scored.
##
## No networking for the heads: which are up comes from NetClock, so every peer sees the same ones.
## A bonk is sent to everyone by the slapper (_bonk, unreliable), so all see it go down. The counter
## faces +Z (players stand in front of it). Its parts are internal children built in _ready.

const HOLES: int = 4
const SPACING: float = 1.3
const COUNTER_HEIGHT: float = 1.1
## Each head's chance of being up, re-rolled every PERIOD seconds.
const PERIOD: float = 1.1
const UP_CHANCE: float = 0.45
const HEAD_COLORS: Array[Color] = [Palette.MOSS, Palette.BERRY, Palette.SKY, Palette.CORAL]

var _heads: Array[SlapTarget] = []
## Per head: the period it was bonked in (it stays down for the rest of it).
var _bonked_in: PackedInt64Array = PackedInt64Array()
var _height: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		set_process(false)


func _process(delta: float) -> void:
	var cycle: int = floori(NetClock.now() / PERIOD)
	for index: int in _heads.size():
		var up: bool = _is_up(index, cycle)
		_height[index] = move_toward(_height[index], 1.0 if up else 0.0, delta * 7.0)
		var head: SlapTarget = _heads[index]
		head.position.y = COUNTER_HEIGHT - 0.55 + 0.85 * _height[index]
		# Only a head that's up can be slapped.
		head.collision_layer = 1 if _height[index] > 0.6 else 0


func _is_up(index: int, cycle: int) -> bool:
	if _bonked_in[index] == cycle:
		return false
	var roll: float = fposmod(sin(float(cycle * 31 + index * 17)) * 43758.5453, 1.0)
	return roll < UP_CHANCE


func _on_head_slapped(_player: Player, index: int) -> void:
	if _height[index] > 0.6:
		_bonk.rpc(index, floori(NetClock.now() / PERIOD))


@rpc("any_peer", "call_local", "unreliable")
func _bonk(index: int, cycle: int) -> void:
	if index < 0 or index >= _heads.size():
		return
	_bonked_in[index] = cycle
	_height[index] = minf(_height[index], 0.4)
	var at: Vector3 = _heads[index].global_position + Vector3.UP * 0.3
	Fx.burst(Fx.world_for(self), at, Palette.SUNBURST, 14, 4.0, 0.07, 0.4, -6.0)
	Fx.ring(Fx.world_for(self), at, Palette.CREAM, 0.9, 0.25)
	Sound.play_at(Sound.Sfx.SLAP, Fx.world_for(self), at, 0.2, 2.0)


func _build() -> void:
	var width: float = HOLES * SPACING + 0.6
	var tool: SurfaceTool = MidwayMeshes.begin()
	# The counter: striped front panels, a top with a dark hole for each head, and a gold edge.
	for index: int in HOLES:
		var x: float = (index - (HOLES - 1) * 0.5) * SPACING
		var stripe: Color = Palette.CORAL if index % 2 == 0 else Palette.CREAM
		MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(x, COUNTER_HEIGHT * 0.5, 0.0)), Vector3(SPACING, COUNTER_HEIGHT, 1.2), stripe)
		MidwayMeshes.cylinder(tool, Transform3D(Basis.IDENTITY, Vector3(x, COUNTER_HEIGHT, 0.0)), 0.42, 0.02, Palette.ABYSS)
	MidwayMeshes.box(tool, Transform3D(Basis.IDENTITY, Vector3(0.0, COUNTER_HEIGHT - 0.04, 0.66)), Vector3(width, 0.12, 0.12), Palette.SUNBURST, MidwayMeshes.SOFT)
	MidwayMeshes.bulbs(tool, Vector3(-width * 0.5, COUNTER_HEIGHT * 0.5, 0.64), Vector3(width * 0.5, COUNTER_HEIGHT * 0.5, 0.64), 0.6, 0.08)
	_add_part(MidwayMeshes.instance(tool))
	var counter: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(HOLES * SPACING, COUNTER_HEIGHT, 1.2)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3.UP * COUNTER_HEIGHT * 0.5
	counter.add_child(collision)
	_add_part(counter)

	_heads.clear()
	_bonked_in.resize(HOLES)
	_bonked_in.fill(-1)
	_height.resize(HOLES)
	_height.fill(0.0)
	for index: int in HOLES:
		var head: SlapTarget = SlapTarget.new()
		head.position = Vector3((index - (HOLES - 1) * 0.5) * SPACING, COUNTER_HEIGHT - 0.55, 0.0)
		var look: SurfaceTool = MidwayMeshes.begin()
		var color: Color = HEAD_COLORS[index % HEAD_COLORS.size()]
		MidwayMeshes.blob(look, Transform3D(Basis.IDENTITY.scaled(Vector3(0.34, 0.4, 0.34)), Vector3.UP * 0.3), color)
		for side: float in [-1.0, 1.0]:
			MidwayMeshes.ball(look, Vector3(side * 0.13, 0.45, 0.27), 0.1, Palette.CREAM)
			MidwayMeshes.ball(look, Vector3(side * 0.13, 0.45, 0.35), 0.045, Palette.ABYSS)
			MidwayMeshes.cylinder(look, Transform3D(Basis(Vector3.BACK, side * -0.4), Vector3(side * 0.18, 0.62, 0.0)), 0.06, 0.24, Palette.CREAM, MidwayMeshes.PLAIN, 6, 0.0)
		MidwayMeshes.box(look, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.24, 0.32)), Vector3(0.18, 0.08, 0.04), Palette.ABYSS)
		head.add_child(MidwayMeshes.instance(look))
		var ball: SphereShape3D = SphereShape3D.new()
		ball.radius = 0.38
		var volume: CollisionShape3D = CollisionShape3D.new()
		volume.shape = ball
		volume.position = Vector3.UP * 0.3
		head.add_child(volume)
		if not Engine.is_editor_hint():
			head.slapped.connect(_on_head_slapped.bind(index))
		_add_part(head)
		_heads.append(head)


## For Level Tools' click gizmo.
func get_faces() -> PackedVector3Array:
	return MidwayMeshes.faces_of(self)


func _add_part(part: Node) -> void:
	add_child(part, false, Node.INTERNAL_MODE_BACK)
