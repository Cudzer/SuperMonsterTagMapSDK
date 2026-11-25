@tool
extends EditorNode3DGizmoPlugin
## Editor-only visuals for map markers: a ring for the spot's footprint, a post and a label, in
## the marker kind's color. A Marker3D is recognized by its parent group (GameMap's marker groups)
## or by being the map's PlayerSpawn. Gizmos never show in game or in captured thumbnails.

## Per kind: label, color, and ring radius (the base footprint, the spawn ring and so on).
const KINDS: Dictionary = {
	&"PlayerSpawn": {"label": "Player spawn", "color": Palette.BERRY, "radius": 4.0},
	GameMap.COIN_SPAWN_POINTS: {"label": "Coin", "color": Palette.SUNBURST, "radius": 0.5},
	GameMap.BUTTON_SPAWN_POINTS: {"label": "Button", "color": Palette.CORAL, "radius": 0.8},
	GameMap.BASE_SPAWN_POINTS: {"label": "Base spot", "color": Palette.SKY, "radius": 3.0},
}
const RING_SEGMENTS: int = 40
const POST_HEIGHT: float = 1.6

var _labels: Dictionary[StringName, TextMesh] = {}


func _init() -> void:
	for kind: StringName in KINDS:
		create_material(kind, KINDS[kind]["color"])
		create_material(_label_material(kind), KINDS[kind]["color"], true)
		var label: TextMesh = TextMesh.new()
		label.text = KINDS[kind]["label"]
		label.font_size = 40
		label.pixel_size = 0.01
		label.depth = 0.0
		_labels[kind] = label


func _get_gizmo_name() -> String:
	return "Map Markers"


func _has_gizmo(node: Node3D) -> bool:
	return node is Marker3D and kind_of(node) != &""


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node: Node3D = gizmo.get_node_3d()
	var kind: StringName = kind_of(node)
	if kind == &"":
		return
	var radius: float = KINDS[kind]["radius"]
	if kind == &"PlayerSpawn" and node.get_parent().get(&"spawn_radius") is float:
		radius = node.get_parent().get(&"spawn_radius")
	var lines: PackedVector3Array = PackedVector3Array()
	for index: int in RING_SEGMENTS:
		var from: float = TAU * index / RING_SEGMENTS
		var to: float = TAU * (index + 1) / RING_SEGMENTS
		lines.append(Vector3(cos(from) * radius, 0.05, sin(from) * radius))
		lines.append(Vector3(cos(to) * radius, 0.05, sin(to) * radius))
	lines.append(Vector3.ZERO)
	lines.append(Vector3.UP * POST_HEIGHT)
	gizmo.add_lines(lines, get_material(kind, gizmo))
	gizmo.add_collision_segments(lines)
	gizmo.add_mesh(_labels[kind], get_material(_label_material(kind), gizmo),
			Transform3D(Basis.IDENTITY, Vector3.UP * (POST_HEIGHT + 0.35)))


## The marker kind of [param node] (a KINDS key), or &"" if it isn't a map marker.
static func kind_of(node: Node) -> StringName:
	var parent: Node = node.get_parent()
	if parent == null:
		return &""
	if node.name == &"PlayerSpawn":
		return &"PlayerSpawn"
	if parent.name != &"PlayerSpawn" and KINDS.has(StringName(parent.name)):
		return StringName(parent.name)
	return &""


static func color_of(kind: StringName) -> Color:
	return KINDS[kind]["color"] if KINDS.has(kind) else Palette.MINT


static func _label_material(kind: StringName) -> String:
	return String(kind) + "_label"
