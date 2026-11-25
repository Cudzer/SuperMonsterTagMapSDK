@tool
class_name MapFormat
## A map package: a map saved as data, for maps made with the Map SDK and shared on the Workshop.
## It's a folder holding map.json (the node tree, every node's saved properties and the resources
## they use), a thumbnail, and the map's own models (GLB) and images, under files/.
##
## A package is never code. map.json names classes from the allowlists below, never a script or
## scene file, and its values decode with JSON.to_native() with objects refused. The game builds
## the map itself (MapBuilder), from its own scripts, so a package downloaded from anyone can't run
## anything on the machines that play it. MapExporter writes packages; both share these rules.
##
## The allowlists are a public contract: published maps name these classes and their exports, so
## only add to them, and keep every listed export's name and meaning.

## The package format. A package from a newer format is refused with a message to update.
const VERSION: int = 1
const MAP_FILE: String = "map.json"
const THUMBNAIL_FILE: String = "thumbnail.png"
## The map's own files sit under this folder in the package, by their path in the SDK project.
const FILES_DIR: String = "files"
## File types a package may carry, and what each loads as.
const MODEL_EXTENSIONS: PackedStringArray = ["glb"]
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

## Limits on what a package may ask the game to build.
const MAX_MAP_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_FILE_BYTES: int = 128 * 1024 * 1024
const MAX_NODES: int = 30000
const MAX_RESOURCES: int = 30000

## Scripted nodes a map may hold, by class name: the root, kit pieces, rails and the Midway rides.
const SCRIPTS: Dictionary[String, String] = {
	"GameMap": "res://scripts/game_map.gd",
	"KitBox": "res://scripts/kit/kit_box.gd",
	"KitCylinder": "res://scripts/kit/kit_cylinder.gd",
	"KitIsland": "res://scripts/kit/kit_island.gd",
	"KitRamp": "res://scripts/kit/kit_ramp.gd",
	"KitStairs": "res://scripts/kit/kit_stairs.gd",
	"KitBarrier": "res://scripts/kit/kit_barrier.gd",
	"KitBuilding": "res://scripts/kit/kit_building.gd",
	"KitAwning": "res://scripts/kit/kit_awning.gd",
	"KitBandstand": "res://scripts/kit/kit_bandstand.gd",
	"KitBed": "res://scripts/kit/kit_bed.gd",
	"KitFountain": "res://scripts/kit/kit_fountain.gd",
	"CollapsingPlatform": "res://scripts/kit/collapsing_platform.gd",
	"MovingPlatform": "res://scripts/kit/moving_platform.gd",
	"SpinningTop": "res://scripts/kit/spinning_top.gd",
	"LevelModel": "res://scripts/kit/level_model.gd",
	"StringLights": "res://scripts/kit/string_lights.gd",
	"TownClock": "res://scripts/kit/town_clock.gd",
	"Zipline": "res://scripts/zipline.gd",
	"GrindRail": "res://scripts/grind_rail.gd",
	"BounceZone": "res://scripts/midway/bounce_zone.gd",
	"Carousel": "res://scripts/midway/carousel.gd",
	"FerrisWheel": "res://scripts/midway/ferris_wheel.gd",
	"WhackAMonster": "res://scripts/midway/whack_a_monster.gd",
	"Strongman": "res://scripts/midway/strongman.gd",
}
## Toys that are scenes, by their root's class name.
const SCENES: Dictionary[String, String] = {
	"SpringPad": "res://scenes/spring_pad.tscn",
	"SpeedBoostPad": "res://scenes/speed_boost_pad.tscn",
	"SwingBar": "res://scenes/swing_bar.tscn",
	"Teleporter": "res://scenes/teleporter.tscn",
	"UpdraftFan": "res://scenes/updraft_fan.tscn",
	"HidingSpot": "res://scenes/hiding_spot.tscn",
}
## Engine nodes a map may hold as they are: structure, plain geometry, CSG, lights and effects.
const NODES: PackedStringArray = [
	"Node3D", "Marker3D", "Camera3D", "Path3D",
	"StaticBody3D", "CollisionShape3D", "MeshInstance3D",
	"CSGCombiner3D", "CSGBox3D", "CSGCylinder3D", "CSGSphere3D", "CSGTorus3D", "CSGPolygon3D", "CSGMesh3D",
	"WorldEnvironment", "DirectionalLight3D", "OmniLight3D", "SpotLight3D", "ReflectionProbe",
	"Decal", "Label3D", "Sprite3D", "FogVolume", "GPUParticles3D", "CPUParticles3D",
]
## Resources a map may build from its own data.
const RESOURCES: PackedStringArray = [
	"BoxMesh", "CylinderMesh", "SphereMesh", "CapsuleMesh", "PlaneMesh", "QuadMesh", "PrismMesh",
	"TorusMesh", "TextMesh", "PointMesh",
	"StandardMaterial3D", "ORMMaterial3D", "ShaderMaterial", "ParticleProcessMaterial", "FogMaterial",
	"BoxShape3D", "CylinderShape3D", "SphereShape3D", "CapsuleShape3D", "ConvexPolygonShape3D",
	"ConcavePolygonShape3D", "WorldBoundaryShape3D", "HeightMapShape3D",
	"Gradient", "GradientTexture1D", "GradientTexture2D", "NoiseTexture2D", "FastNoiseLite",
	"Curve", "CurveTexture", "Curve3D",
	"Environment", "Sky", "ProceduralSkyMaterial", "PhysicalSkyMaterial", "PanoramaSkyMaterial",
]
## The game's own files a map may use by path (models, skies, fonts, shaders, textures)...
const BASE_FOLDERS: PackedStringArray = [
	"res://assets/models/level/", "res://assets/environments/", "res://assets/fonts/",
	"res://assets/shaders/", "res://assets/textures/",
]
## ...as one of these. A ShaderMaterial can only use the game's shaders: none can be embedded.
const BASE_TYPES: PackedStringArray = ["PackedScene", "Environment", "Sky", "Font", "Shader", "Texture2D", "Material", "Mesh"]
## Never saved or set, on any node or resource.
const DENIED_PROPERTIES: PackedStringArray = ["script", "resource_path", "resource_name", "resource_local_to_scene"]

const RESOURCE_KEY: String = "res"
const RESOURCE_ARRAY_KEY: String = "res_array"
## In the Map SDK: every game file a map may use by path, written by the SDK's build. A file under
## BASE_FOLDERS that isn't listed is the modder's own (a model they added), so it's packaged.
const GAME_FILES_LIST: String = "res://sdk/game_files.txt"

## GAME_FILES_LIST's paths, read on first use.
static var _game_files: Dictionary[String, bool] = {}


## The properties of [param object] a map saves and may set: those the engine stores, less the
## denied ones and metadata.
static func saved_properties(object: Object) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_STORAGE == 0 or usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP) != 0:
			continue
		var property_name: String = property["name"]
		if property_name in DENIED_PROPERTIES or property_name.begins_with("metadata/"):
			continue
		found.append(property)
	return found


## Whether [param path] is one of the game's own files a map may use.
static func is_base_path(path: String) -> bool:
	if path.contains("::"):
		return false
	for folder: String in BASE_FOLDERS:
		if path.begins_with(folder) and path.simplify_path().begins_with(folder):
			return true
	return false


## Whether [param path] is a game file a map may use: in the game, any file under BASE_FOLDERS; in
## the Map SDK, only those GAME_FILES_LIST names.
static func is_game_file(path: String) -> bool:
	if not is_base_path(path):
		return false
	if not is_sdk():
		return true
	if _game_files.is_empty():
		for line: String in FileAccess.get_file_as_string(GAME_FILES_LIST).split("\n", false):
			_game_files[line.strip_edges()] = true
	return _game_files.has(path)


## Whether this is the Map SDK rather than the game.
static func is_sdk() -> bool:
	return FileAccess.file_exists(GAME_FILES_LIST)


static func is_base_type(resource: Resource) -> bool:
	for type: String in BASE_TYPES:
		if resource.is_class(type):
			return true
	return false


## Whether [param relative] is a safe path for one of a package's own files: under FILES_DIR,
## relative, without "..", and of a type a package may carry.
static func is_package_file(relative: String) -> bool:
	if not relative.begins_with(FILES_DIR + "/") or relative.contains("..") or relative.contains(":") \
			or relative.contains("\\") or relative.begins_with("/"):
		return false
	var extension: String = relative.get_extension().to_lower()
	return extension in MODEL_EXTENSIONS or extension in IMAGE_EXTENSIONS


## The integer values a PROPERTY_HINT_ENUM property allows ("A,B:5,C" allows 0, 5 and 6).
static func enum_values(hint_string: String) -> PackedInt32Array:
	var values: PackedInt32Array = []
	var next: int = 0
	for item: String in hint_string.split(","):
		if item.contains(":"):
			next = item.get_slice(":", 1).to_int()
		values.append(next)
		next += 1
	return values
