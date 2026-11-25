class_name Teleporter
extends Area3D
## One end of a teleporter pair. Standing in its column for charge_seconds sends the player to the
## other end; staying in the other end's column that long again sends them back.
##
## Pair two teleporters by setting partner on either one (the other finds it either way). Movement
## is client-authoritative, so every peer counts how long each player has been inside (for the
## charge ring everyone sees) but only the player's own machine teleports them.

## The other end of the pair. Set it on one end; the other end finds this one by itself.
@export var partner: NodePath
## Seconds a player must stay inside to be sent.
@export var charge_seconds: float = 2.0

## The charge sound starts once a player has been inside this long, so walking through is quiet.
const CHARGE_SOUND_DELAY: float = 0.3
## Where Sfx.TELEPORT_CHARGE's build-up peaks (seconds in). It starts far enough in to peak as the
## player goes.
const CHARGE_SOUND_PEAK: float = 3.0

## Seconds each player has been inside (every peer, for the visuals).
var _charge: Dictionary[Player, float] = {}
var _shown_charge: float = -1.0
## The charge sound for each player charging (every peer). Untyped values: they free themselves.
var _charge_sounds: Dictionary[Player, Variant] = {}

@onready var surface: MeshInstance3D = $Surface
@onready var beam: MeshInstance3D = $Beam


func _ready() -> void:
	add_to_group(&"teleporters")
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body: Node3D) -> void: _stop_charging(body as Player))


## The other end: partner, or the teleporter whose partner is this one.
func get_partner() -> Teleporter:
	var linked: Teleporter = get_node_or_null(partner) as Teleporter
	if linked != null:
		return linked
	for node: Node in get_tree().get_nodes_in_group(&"teleporters"):
		var other: Teleporter = node as Teleporter
		if other != self and other.get_node_or_null(other.partner) == self:
			return other
	return null


## Where arriving players stand.
func get_arrival_position() -> Vector3:
	return global_position + Vector3.UP * 0.05


func _physics_process(delta: float) -> void:
	var most: float = 0.0
	for player: Player in _charge.keys():
		if not is_instance_valid(player):
			_charge.erase(player)
			Sound.fade_out(_charge_sounds.get(player))
			_charge_sounds.erase(player)
			continue
		# A frozen player (Stuck in the Mud) can't use it; the charge waits.
		if not player.is_frozen:
			_charge[player] += delta
		if _charge[player] >= CHARGE_SOUND_DELAY and not _charge_sounds.has(player):
			var from: float = maxf(CHARGE_SOUND_PEAK - charge_seconds + _charge[player], 0.0)
			_charge_sounds[player] = Sound.play_at(Sound.Sfx.TELEPORT_CHARGE, self, global_position + Vector3.UP, 0.0, 0.0, 1.0, from)
		if player.is_multiplayer_authority() and _charge[player] >= charge_seconds:
			_send(player)
			continue
		most = maxf(most, _charge[player] / charge_seconds)
	if not is_equal_approx(most, _shown_charge):
		_shown_charge = most
		surface.set_instance_shader_parameter(&"charge", most)
		beam.set_instance_shader_parameter(&"charge", most)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		_charge[player] = 0.0


## Every peer: [param player] left the column (or was sent), so their count and its sound end.
func _stop_charging(player: Player) -> void:
	_charge.erase(player)
	Sound.fade_out(_charge_sounds.get(player))
	_charge_sounds.erase(player)


## Owner's machine only. A quick blink hides the jump; the player arrives at a standstill in the
## other end's column, which starts its own count to send them back.
func _send(player: Player) -> void:
	var destination: Teleporter = get_partner()
	if destination == null:
		return
	# Until they step out and back in, this end is done with them.
	_stop_charging(player)
	_play_burst.rpc()
	destination._play_burst.rpc()
	# The blink is for the person teleporting; a bot (on the host) just goes.
	if not player.is_local():
		player.teleport(destination.get_arrival_position())
		return
	Transition.blink(func() -> void:
		if is_instance_valid(player):
			player.teleport(destination.get_arrival_position()))


## A puff and the teleport's zap at this end, on every peer (any peer, because whoever teleports
## asks for it).
@rpc("any_peer", "call_local", "unreliable")
func _play_burst() -> void:
	var world: Node = Fx.world_for(self)
	Sound.play_at(Sound.Sfx.TELEPORT, world, global_position + Vector3.UP, 0.06)
	Fx.burst(world, global_position + Vector3.UP, Palette.LILAC, 24, 5.0, 0.1, 0.5, 1.0)
	Fx.ring(world, global_position + Vector3.UP * 0.1, Palette.MINT, 2.4, 0.35)
