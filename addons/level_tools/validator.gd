@tool
## Checks an open map against the map rules (CLAUDE.md "Maps" and the islands notes): the files a
## map needs, spots resting on the ground with headroom, base clearance, spots kept off pads,
## spring pad arcs, level swing bars, walkable slopes, and which modes the map can host. Ground
## and arc checks use the Level Tools plugin's surface_hit(), so they see the same surfaces the
## dock places onto.

enum Severity { ERROR, WARNING, INFO }

const MapFiles := preload("map_files.gd")
## A spot may sit this far above or below the surface under it.
const GROUND_TOLERANCE: float = 0.6
## Spots need this much clear space above them (a player's height).
const HEADROOM: float = 1.9
## Bases are this wide (TagBase), so their spot needs this radius of flat, open ground.
const BASE_CLEARANCE: float = 3.0
## Spots this close to a pad (horizontally) launch or boost whoever goes for them.
const PAD_CLEARANCE: float = 2.0
## Spots of the same kind (or a button and a coin) closer than this crowd each other.
const SPOT_SPACING: float = 1.5
## Steeper ramps are walls to the player (CharacterBody3D floor_max_angle).
const MAX_SLOPE_DEGREES: float = 45.0
const SPOT_LABELS: Dictionary = {
	&"PlayerSpawn": "Player spawn",
	GameMap.COIN_SPAWN_POINTS: "Coin spot",
	GameMap.BUTTON_SPAWN_POINTS: "Button spot",
	GameMap.BASE_SPAWN_POINTS: "Base spot",
}

var _plugin: EditorPlugin
var _pad_gizmos: EditorNode3DGizmoPlugin
var _issues: Array[Dictionary] = []


func _init(plugin: EditorPlugin, pad_gizmos: EditorNode3DGizmoPlugin) -> void:
	_plugin = plugin
	_pad_gizmos = pad_gizmos


## Every problem found in the map rooted at [param root], errors first: {"severity", "message",
## "node"} ("node" is what to select, or null).
func validate(root: Node3D) -> Array[Dictionary]:
	_issues.clear()
	if root == null or root.get_script() != MapFiles.GAME_MAP_SCRIPT:
		_add(Severity.ERROR, "The scene root isn't a GameMap (scripts/game_map.gd).", root)
		return _issues
	_check_files(root)
	var spots: Array[Dictionary] = _collect_spots(root)
	for spot: Dictionary in spots:
		var node: Node3D = spot["node"]
		_check_ground(node, spot["label"])
		if spot["group"] == GameMap.BASE_SPAWN_POINTS:
			_check_base_clearance(node, spot["label"])
	_check_player_spawn(root)
	_check_spacing(spots)
	_check_level_objects(root, spots)
	_check_modes(root)
	if root.get_node_or_null(^"SpectatorCamera") == null:
		_add(Severity.INFO, "No SpectatorCamera: spectators get a default view from above the spawn.", root)
	_issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["severity"] < b["severity"])
	return _issues


func _check_files(root: Node3D) -> void:
	if root.scene_file_path == "":
		_add(Severity.WARNING, "The map isn't saved yet.", root)
	elif MapFiles.find_info(root.scene_file_path) == null:
		_add(Severity.ERROR, "No MapInfo under res://maps points at this scene, so it isn't in the map picker.", root)


## The player spawn and every marker in the map's marker groups: {"node", "group", "label"}.
func _collect_spots(root: Node3D) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var spawn: Node3D = root.get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn != null:
		spots.append({"node": spawn, "group": &"PlayerSpawn", "label": SPOT_LABELS[&"PlayerSpawn"]})
	for group_name: StringName in GameMap.MARKER_GROUPS:
		var group: Node = root.get_node_or_null(NodePath(group_name))
		if group == null:
			continue
		for marker: Node in group.get_children():
			if marker is Node3D:
				spots.append({"node": marker, "group": group_name, "label": "%s \"%s\"" % [SPOT_LABELS[group_name], marker.name]})
	return spots


## Spots should rest on a surface (within GROUND_TOLERANCE) with a player's height clear above.
func _check_ground(node: Node3D, label: String) -> void:
	var at: Vector3 = node.global_position
	var below: Dictionary = _hit(at + Vector3.UP * GROUND_TOLERANCE, Vector3.DOWN, 200.0)
	if below.is_empty():
		_add(Severity.ERROR, "%s has nothing below it." % label, node)
		return
	var gap: float = at.y - (below["position"] as Vector3).y
	if gap > GROUND_TOLERANCE:
		_add(Severity.WARNING, "%s floats %.1f m above the ground." % [label, gap], node)
	# From above the tolerance, so a spot sunk slightly into the ground doesn't see the ground.
	var start: float = GROUND_TOLERANCE + 0.05
	var above: Dictionary = _hit(at + Vector3.UP * start, Vector3.UP, HEADROOM - start)
	if not above.is_empty():
		_add(Severity.WARNING, "%s has only %.1f m of headroom: it's inside or under %s." % [label, start + float(above["distance"]), _name(above["node"])], node)


func _check_base_clearance(node: Node3D, label: String) -> void:
	var center: Vector3 = node.global_position
	for index: int in 8:
		var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * index / 8.0)
		for height: float in [0.5, 1.5]:
			var blocked: Dictionary = _hit(center + Vector3.UP * height, direction, BASE_CLEARANCE)
			if not blocked.is_empty():
				_add(Severity.WARNING, "%s: %s is %.1f m away; bases need %.0f m of open ground." % [label, _name(blocked["node"]), blocked["distance"], BASE_CLEARANCE], node)
				return
		# Just inside the edge: a base exactly as wide as its platform is fine.
		for radius: float in [BASE_CLEARANCE * 0.5, BASE_CLEARANCE - 0.25]:
			var point: Vector3 = center + direction * radius
			var ground: Dictionary = _hit(point + Vector3.UP * GROUND_TOLERANCE, Vector3.DOWN, GROUND_TOLERANCE * 2.0)
			if ground.is_empty():
				_add(Severity.WARNING, "%s: the ground drops away within %.1f m; bases need %.0f m of flat ground." % [label, radius, BASE_CLEARANCE], node)
				return


## Players spawn in a ring of the map's Spawn Radius around the spawn; each spot should be ground.
func _check_player_spawn(root: Node3D) -> void:
	var spawn: Node3D = root.get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn == null:
		_add(Severity.ERROR, "No PlayerSpawn: players start at the map's origin.", root)
		return
	var radius: float = root.get(&"spawn_radius")
	var bad: int = 0
	for index: int in 16:
		var point: Vector3 = spawn.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * index / 16.0) * radius
		var ground: Dictionary = _hit(point + Vector3.UP * 1.0, Vector3.DOWN, 2.0)
		if ground.is_empty() or not _hit(point + Vector3.UP * 0.1, Vector3.UP, HEADROOM).is_empty():
			bad += 1
	if bad > 0:
		_add(Severity.WARNING, "%d of 16 start positions on the spawn ring (Spawn Radius %.1f m) are over a drop or inside something." % [bad, radius], spawn)


func _check_spacing(spots: Array[Dictionary]) -> void:
	for a: int in spots.size():
		for b: int in range(a + 1, spots.size()):
			var first: Dictionary = spots[a]
			var second: Dictionary = spots[b]
			var groups: Array = [first["group"], second["group"]]
			var crowded: bool = first["group"] == second["group"] \
					or (GameMap.BUTTON_SPAWN_POINTS in groups and GameMap.COIN_SPAWN_POINTS in groups)
			if not crowded:
				continue
			var distance: float = (first["node"] as Node3D).global_position.distance_to((second["node"] as Node3D).global_position)
			if distance < SPOT_SPACING:
				_add(Severity.WARNING, "%s and %s are only %.1f m apart." % [first["label"], second["label"], distance], second["node"])


func _check_level_objects(root: Node3D, spots: Array[Dictionary]) -> void:
	var pads: Array[Node3D] = []
	var teleporters: Array[Node3D] = []
	for node: Node in root.find_children("*", "Node3D", true, false):
		if node is SpringPad:
			pads.append(node)
			_check_spring_pad(node as SpringPad)
		elif node is SpeedBoostPad:
			pads.append(node)
			_check_resting(node as Node3D, "Boost pad \"%s\"" % node.name)
		elif node is Teleporter:
			pads.append(node)
			teleporters.append(node)
			_check_resting(node as Node3D, "Teleporter \"%s\"" % node.name)
		elif node is UpdraftFan:
			pads.append(node)
			_check_resting(node as Node3D, "Updraft fan \"%s\"" % node.name)
		elif node is HidingSpot:
			_check_resting(node as Node3D, "Hiding spot \"%s\"" % node.name)
		elif node is SwingBar:
			_check_swing_bar(node as SwingBar)
		elif node is KitRamp or node is KitStairs:
			var size: Vector3 = node.get(&"size")
			var slope: float = rad_to_deg(atan2(size.y, size.z))
			if slope > MAX_SLOPE_DEGREES:
				_add(Severity.ERROR, "\"%s\" slopes %.0f°: steeper than %.0f° is a wall to players. Lengthen it or lower it." % [node.name, slope, MAX_SLOPE_DEGREES], node)
	for teleporter: Node3D in teleporters:
		_check_teleporter(teleporter, root)
	for spot: Dictionary in spots:
		var at: Vector3 = (spot["node"] as Node3D).global_position
		for pad: Node3D in pads:
			var flat: Vector2 = Vector2(at.x - pad.global_position.x, at.z - pad.global_position.z)
			if flat.length() < PAD_CLEARANCE and absf(at.y - pad.global_position.y) < 1.5:
				_add(Severity.WARNING, "%s is on or next to the pad \"%s\"." % [spot["label"], pad.name], spot["node"])


func _check_spring_pad(pad: SpringPad) -> void:
	var label: String = "Spring pad \"%s\"" % pad.name
	_check_resting(pad, label)
	if pad.aimed and not pad.can_reach_target():
		_add(Severity.ERROR, "%s can't reach its target at %.0f°: raise its Launch Angle." % [label, pad.launch_angle], pad)
		return
	var traced: Dictionary = _pad_gizmos.call(&"trace", pad)
	if traced["landing"] == null:
		_add(Severity.ERROR if pad.aimed else Severity.WARNING, "%s launches players into the void." % label, pad)
	elif not traced["ok"]:
		_add(Severity.ERROR, "%s's arc hits %s before it lands on target." % [label, _name(traced["blocker"])], pad)


## Pads have no collision of their own, so they must sit on a surface. Tilted pads are usually
## raised a little so their low edge doesn't sink, so allow up to a meter of gap.
func _check_resting(node: Node3D, label: String) -> void:
	var below: Dictionary = _hit(node.global_position + Vector3.UP * 0.5, Vector3.DOWN, 1.5, node)
	if below.is_empty():
		_add(Severity.WARNING, "%s isn't resting on a surface." % label, node)


func _check_swing_bar(bar: SwingBar) -> void:
	if bar.global_basis.y.normalized().dot(Vector3.UP) < 0.999:
		_add(Severity.ERROR, "Swing bar \"%s\" is tilted: rotate swing bars only around Y." % bar.name, bar)
	if not bar.global_basis.get_scale().is_equal_approx(Vector3.ONE):
		_add(Severity.WARNING, "Swing bar \"%s\" is scaled: set its Length instead." % bar.name, bar)


func _check_modes(root: Node3D) -> void:
	var unavailable: PackedStringArray = PackedStringArray()
	for mode_id: int in GameModes.NAMES.size():
		var needed: Dictionary = GameModes.MARKERS_NEEDED[mode_id]
		for group_name: StringName in needed:
			var group: Node = root.get_node_or_null(NodePath(group_name))
			var count: int = group.get_child_count() if group != null else 0
			if count < needed[group_name]:
				unavailable.append("%s (needs %d %s, has %d)" % [GameModes.NAMES[mode_id], needed[group_name], String(group_name).capitalize().to_lower(), count])
	if unavailable.is_empty():
		_add(Severity.INFO, "Every mode can be played on this map.", null)
	else:
		_add(Severity.WARNING, "Not playable here: %s." % ", ".join(unavailable), root)
	if _count(root, GameMap.COIN_SPAWN_POINTS) == 0:
		_add(Severity.INFO, "No coin spots: no coins, so no tagger pings.", root)
	if _count(root, GameMap.BUTTON_SPAWN_POINTS) == 0:
		_add(Severity.INFO, "No button spots: no slap button.", root)


func _count(root: Node3D, group_name: StringName) -> int:
	var group: Node = root.get_node_or_null(NodePath(group_name))
	return group.get_child_count() if group != null else 0


func _hit(from: Vector3, direction: Vector3, distance: float, exclude: Node = null) -> Dictionary:
	return _plugin.call(&"surface_hit", from, direction, distance, exclude, false)


func _add(severity: Severity, message: String, node: Node) -> void:
	_issues.append({"severity": severity, "message": message, "node": node})


## The name of the scene node a surface belongs to: a kit piece for its generated parts, the
## instance (a pad, say) for a mesh inside an instanced scene.
static func _name(node: Node) -> String:
	if node == null:
		return "something"
	if node.owner == null and node.get_parent() is KitPiece:
		node = node.get_parent()
	elif node.owner != null and node.owner != EditorInterface.get_edited_scene_root():
		node = node.owner
	return "\"%s\"" % node.name


## Every teleporter needs exactly one other end. Partner can be set on either end.
func _check_teleporter(teleporter: Node3D, root: Node) -> void:
	var label: String = "Teleporter \"%s\"" % teleporter.name
	var path: NodePath = teleporter.get(&"partner")
	if not path.is_empty() and not teleporter.get_node_or_null(path) is Teleporter:
		_add(Severity.ERROR, "%s's Partner isn't a teleporter: pick the other end of the pair." % label, teleporter)
		return
	var other: Node3D = partner_of(teleporter, root)
	if other == null:
		_add(Severity.ERROR, "%s has no other end: place another teleporter (it pairs by itself) or set Partner." % label, teleporter)
		return
	var back: NodePath = other.get(&"partner")
	if not back.is_empty() and other.get_node_or_null(back) != teleporter:
		_add(Severity.WARNING, "%s's other end \"%s\" is paired with a third teleporter, so it won't send players back here." % [label, other.name], teleporter)


## The other end of [param teleporter] in [param root]: its Partner, or the teleporter whose
## Partner is it. Uses get() because Teleporter isn't a tool script. Null if unpaired.
static func partner_of(teleporter: Node3D, root: Node) -> Node3D:
	var linked: Node = teleporter.get_node_or_null(teleporter.get(&"partner"))
	if linked is Teleporter and linked != teleporter:
		return linked as Node3D
	for node: Node in root.find_children("*", "Area3D", true, false):
		if node is Teleporter and node != teleporter and node.get_node_or_null(node.get(&"partner")) == teleporter:
			return node as Node3D
	return null
