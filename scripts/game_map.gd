class_name GameMap
extends Node3D
## The world a match is played in: environment, geometry and gameplay markers. A map has no
## networking or match logic of its own. TagMatch (scenes/match.tscn) instances the host's chosen
## map on every peer, so node paths inside it match everywhere, and reads the marker groups below.
## A map is listed in the Start Match picker through its MapInfo (see map_info.gd).

## Marker group names. Each is an optional child Node3D whose Marker3D children are the spots;
## missing groups are created empty. Modes can require a minimum number of some (GameModes.MARKERS_NEEDED).
const COIN_SPAWN_POINTS: StringName = &"CoinSpawnPoints"
const BUTTON_SPAWN_POINTS: StringName = &"ButtonSpawnPoints"
const BASE_SPAWN_POINTS: StringName = &"BaseSpawnPoints"
const MARKER_GROUPS: Array[StringName] = [COIN_SPAWN_POINTS, BUTTON_SPAWN_POINTS, BASE_SPAWN_POINTS]

## Players spawn in a ring of this radius around PlayerSpawn.
@export var spawn_radius: float = 4.0
## Falling wraps around (see Level.fall_distance): players who fall this far below the map's
## lowest geometry reappear wrap_clearance above its highest, still falling.
@export var fall_distance: float = 25.0
@export var wrap_clearance: float = 15.0

## Where players start; the map's origin without it.
@onready var player_spawn: Node3D = get_node_or_null(^"PlayerSpawn")
@onready var coin_spawn_points: Node3D = _group(COIN_SPAWN_POINTS)
## The spots the slap button moves between.
@onready var button_spawn_points: Node3D = _group(BUTTON_SPAWN_POINTS)
## Candidate base spots for Base Tag; the mode picks two far apart.
@onready var base_spawn_points: Node3D = _group(BASE_SPAWN_POINTS)
## The overhead view for spectators. Without one, a camera looking down at the map is added.
@onready var spectator_camera: Camera3D = get_node_or_null(^"SpectatorCamera")


func _ready() -> void:
	if spectator_camera == null:
		spectator_camera = Camera3D.new()
		spectator_camera.name = "SpectatorCamera"
		add_child(spectator_camera)
		spectator_camera.look_at_from_position(get_spawn_position() + Vector3(0, 60, 60), get_spawn_position())


func get_spawn_position() -> Vector3:
	return player_spawn.global_position if player_spawn != null else global_position


func _group(group_name: StringName) -> Node3D:
	var group: Node3D = get_node_or_null(NodePath(group_name))
	if group == null:
		group = Node3D.new()
		group.name = group_name
		add_child(group)
	return group
