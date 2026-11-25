@tool
## What the Level Tools dock can place. Each item is a dictionary: "name" (button text), "kind",
## "tip" (tooltip), plus per kind: PIECE "script" and "props" (exports to set), SCENE "scene" (and
## optional "props"),
## MARKER "group" (a GameMap marker group), MODEL "model" (a GLB path, placed as a LevelModel).
## Optional "lift" raises it above the clicked surface. Models aren't listed here: model_items()
## finds them in LevelModel.MODELS_DIR.

enum Kind { PIECE, SCENE, MARKER, PLAYER_SPAWN, MODEL }

const MODEL_EXTENSIONS: Array[String] = ["glb", "gltf"]

const PIECES: Array[Dictionary] = [
	{"name": "Platform", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(8, 1, 8), "color": KitPiece.Swatch.TEAL},
			"tip": "A box to stand on. Set its Size in the inspector."},
	{"name": "Island", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_island.gd"),
			"props": {"radius": 12.0, "thickness": 2.0, "rock_depth": 10.0, "color": KitPiece.Swatch.LAGOON, "propeller": true},
			"tip": "A round island top with a rock cone below and a propeller under it (Propeller in the inspector). Its top is Thickness above where you click."},
	{"name": "Stepping Stone", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_island.gd"),
			"props": {"radius": 1.5, "thickness": 0.5, "rock_depth": 2.0, "color": KitPiece.Swatch.SEAFOAM},
			"tip": "A small island. A single jump climbs about 1.4 m between stones."},
	{"name": "Ramp", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_ramp.gd"),
			"props": {"size": Vector3(4, 3, 8), "color": KitPiece.Swatch.BERRY},
			"tip": "A solid slope rising away from the camera. Keep it under 45 degrees."},
	{"name": "Stairs", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_stairs.gd"),
			"props": {"size": Vector3(4, 3, 6), "color": KitPiece.Swatch.BERRY},
			"tip": "Steps rising away from the camera. They walk like a ramp."},
	{"name": "Fountain", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_fountain.gd"),
			"props": {"radius": 2.5, "color": KitPiece.Swatch.SAND},
			"tip": "A tiered fountain with running water. It is solid: players walk round it. Set Radius, Tiers and Spouts in the inspector."},
	{"name": "Bandstand", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_bandstand.gd"),
			"props": {"radius": 4.5, "color": KitPiece.Swatch.SAND},
			"tip": "An octagonal bandstand with steps front and back, railings, a striped canopy and bulbs. Set Radius, colours and Instruments in the inspector."},
	{"name": "Building", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_building.gd"),
			"props": {"size": Vector3(10, 8, 10), "color": KitPiece.Swatch.BRICK},
			"tip": "A town building: painted windows, a storefront, a low parapet round the roof and roof props. Set its Size, colours and roof props in the inspector."},
	{"name": "Barrier", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_barrier.gd"),
			"props": {"size": Vector3(10, 40, 1)},
			"tip": "An invisible wall that only stops players (no wall runs or vaults on it). Ring a map with it so nobody gets out. See-through in the editor, invisible in game."},
	{"name": "Bridge", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(4, 0.5, 12), "color": KitPiece.Swatch.BERRY},
			"tip": "A long slab running away from the camera. Paths and ramps are berry."},
	{"name": "Wall", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(1, 6, 12), "color": KitPiece.Swatch.TEAL},
			"tip": "A tall wall running away from the camera, for wall runs."},
	{"name": "Pillar", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_cylinder.gd"),
			"props": {"radius": 1.0, "height": 6.0, "color": KitPiece.Swatch.SEAFOAM},
			"tip": "A round column."},
	{"name": "Block", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(2, 2, 2), "color": KitPiece.Swatch.LAGOON},
			"tip": "Cover to break line of sight, or a step up."},
	{"name": "Ice Floor", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(8, 0.5, 8), "surface": KitPiece.Surface.ICE},
			"tip": "Slippery: players keep their momentum and turn slowly, and slides go far. Any kit piece can be icy (Surface in the inspector)."},
	{"name": "Mud Patch", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(6, 0.5, 6), "surface": KitPiece.Surface.MUD},
			"tip": "Sticky: slower running, lower jumps, and slides stop short. Any kit piece can be muddy (Surface in the inspector)."},
	{"name": "Grass Patch", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(6, 0.5, 6), "color": KitPiece.Swatch.MOSS, "finish": KitPiece.Finish.GRASS},
			"tip": "A lawn: mowing stripes, clumps and a few flowers. Any kit piece can take a ground look (Finish in the inspector); it plays like a normal floor."},
	{"name": "Paving", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(8, 0.5, 8), "color": KitPiece.Swatch.SAND, "finish": KitPiece.Finish.PAVING},
			"tip": "Flagstones with a border of small stones. Looks only; it plays like a normal floor."},
	{"name": "Sidewalk", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(8, 0.5, 8), "color": KitPiece.Swatch.CREAM, "finish": KitPiece.Finish.SIDEWALK},
			"tip": "Concrete slabs with a kerb round the edge. Looks only; it plays like a normal floor."},
	{"name": "Asphalt", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(8, 0.5, 8), "color": KitPiece.Swatch.ASPHALT, "finish": KitPiece.Finish.ASPHALT},
			"tip": "Road surface: grit, repair patches, cracks and manhole covers. Looks only; it plays like a normal floor."},
	{"name": "Dirt Patch", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(6, 0.5, 6), "color": KitPiece.Swatch.SAND, "finish": KitPiece.Finish.DIRT},
			"tip": "Bare earth with damp patches and pebbles. Looks only (Mud Patch is the slow one)."},
	{"name": "Floorboards", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(12, 0.5, 12), "color": KitPiece.Swatch.SAND, "finish": KitPiece.Finish.WOOD},
			"tip": "Wooden planks along the piece's width, with grain and the odd knot. Looks only."},
	{"name": "Rug", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(16, 0.5, 11), "color": KitPiece.Swatch.BERRY, "finish": KitPiece.Finish.RUG},
			"tip": "A patterned rug: fringed ends, a border and a medallion. Place it 2 cm proud of a floor. Looks only."},
	{"name": "Wallpaper Wall", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_box.gd"),
			"props": {"size": Vector3(12, 12, 1), "color": KitPiece.Swatch.SEAFOAM, "finish": KitPiece.Finish.WALLPAPER},
			"tip": "A wall papered on its sides: stripes over a panelled dado and a skirting board, lined up with the floor at height 0."},
	{"name": "Bed", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_bed.gd"), "props": {},
			"tip": "A giant bed, and a trampoline: landing on it bounces you back up (hold crouch to land). There's a crawl space underneath; add a hiding spot to hide in it."},
]

const GAMEPLAY: Array[Dictionary] = [
	{"name": "Player Spawn", "kind": Kind.PLAYER_SPAWN,
			"tip": "Where players start, in a ring of the map's Spawn Radius. A map has one: placing it again moves it."},
	{"name": "Coin Spot", "kind": Kind.MARKER, "group": GameMap.COIN_SPAWN_POINTS,
			"tip": "A place a coin can appear."},
	{"name": "Button Spot", "kind": Kind.MARKER, "group": GameMap.BUTTON_SPAWN_POINTS,
			"tip": "A place the slap button can appear. It faces the way the spot faces."},
	{"name": "Base Spot", "kind": Kind.MARKER, "group": GameMap.BASE_SPAWN_POINTS,
			"tip": "A place Base Tag can put a base; it picks two far apart. Needs 3 m of clear ground. Base Tag needs at least 2."},
	{"name": "Spring Pad", "kind": Kind.SCENE, "scene": "res://scenes/spring_pad.tscn",
			"tip": "Launches players straight up. Tilt it to aim."},
	{"name": "Boost Pad", "kind": Kind.SCENE, "scene": "res://scenes/speed_boost_pad.tscn",
			"tip": "A burst of speed for 3 seconds."},
	{"name": "Swing Bar", "kind": Kind.SCENE, "scene": "res://scenes/swing_bar.tscn", "lift": 4.0,
			"tip": "A bar to swing around, 4 m above where you click. Rotate it only around Y."},
	{"name": "Teleporter", "kind": Kind.SCENE, "scene": "res://scenes/teleporter.tscn",
			"tip": "Place two: the second pairs with the first by itself. Standing in one for 2 seconds sends a player to the other."},
	{"name": "Zipline", "kind": Kind.PIECE, "script": preload("res://scripts/zipline.gd"), "props": {},
			"tip": "A cable to grab from the air and ride, faster downhill. Select it and drag its far end onto where the second post goes."},
	{"name": "Grind Rail", "kind": Kind.PIECE, "script": preload("res://scripts/grind_rail.gd"), "props": {},
			"tip": "A rail to land on and slide along. Select it and drag its far end into place; slopes speed players up."},
	{"name": "Collapsing Platform", "kind": Kind.PIECE, "script": preload("res://scripts/kit/collapsing_platform.gd"),
			"props": {"size": Vector3(3, 0.5, 3)},
			"tip": "Shakes for a second once someone stands on it, then drops away; back after 5 seconds."},
	{"name": "Moving Platform", "kind": Kind.PIECE, "script": preload("res://scripts/kit/moving_platform.gd"),
			"props": {"motion": MovingPlatform.Motion.MOVE},
			"tip": "Travels back and forth, carrying whoever stands on it. Select it and drag its far end to where it goes."},
	{"name": "Spinning Platform", "kind": Kind.PIECE, "script": preload("res://scripts/kit/moving_platform.gd"),
			"props": {"motion": MovingPlatform.Motion.SPIN, "size": Vector3(8, 0.5, 2.5)},
			"tip": "Turns in place, carrying riders round. Set Spin Speed in the inspector."},
	{"name": "Spinning Top", "kind": Kind.PIECE, "script": preload("res://scripts/kit/spinning_top.gd"), "props": {},
			"tip": "A giant top spinning on its tip. Jump onto it and ride it round. Set Radius and Spin Speed in the inspector."},
	{"name": "Updraft Fan", "kind": Kind.SCENE, "scene": "res://scenes/updraft_fan.tscn",
			"tip": "Blows players up its column (Height in the inspector) and a little beyond. Tilt it to blow sideways."},
	{"name": "Bush", "kind": Kind.SCENE, "scene": "res://scenes/hiding_spot.tscn", "props": {"style": HidingSpot.Style.BUSH},
			"tip": "Anyone inside is hidden from other players, but can still be tagged, and it rustles when someone goes in or out."},
	{"name": "Haystack", "kind": Kind.SCENE, "scene": "res://scenes/hiding_spot.tscn", "props": {"style": HidingSpot.Style.HAYSTACK},
			"tip": "A hiding spot, like the bush."},
	{"name": "Awning", "kind": Kind.PIECE, "script": preload("res://scripts/kit/kit_awning.gd"), "props": {}, "lift": 3.0,
			"tip": "A bouncy shop awning: dropping onto it throws you up and back over the wall it hangs on. Place it against a wall, facing out."},
	{"name": "String Lights", "kind": Kind.PIECE, "script": preload("res://scripts/kit/string_lights.gd"), "props": {}, "lift": 4.0,
			"tip": "Party lights strung between two points (drag the far end). Decoration only."},
	{"name": "Town Clock", "kind": Kind.PIECE, "script": preload("res://scripts/kit/town_clock.gd"), "props": {}, "lift": 6.0,
			"tip": "A clock face for a tower wall, facing away from it. Its hands keep the same time for everyone."},
]


## Every model under LevelModel.MODELS_DIR as a MODEL item, by category: the subfolder it's in
## ("" for the folder itself), sorted.
static func model_items() -> Dictionary[String, Array]:
	var found: Dictionary[String, Array] = {}
	_scan_models(LevelModel.MODELS_DIR, "", found)
	var sorted: Dictionary[String, Array] = {}
	var categories: Array[String] = found.keys()
	categories.sort()
	for category: String in categories:
		sorted[category] = found[category]
	return sorted


static func _scan_models(dir: String, category: String, found: Dictionary[String, Array]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	for file: String in files:
		if file.get_extension().to_lower() not in MODEL_EXTENSIONS:
			continue
		if not found.has(category):
			found[category] = []
		# Stairs are walked up a smooth slope, like kit stairs, rather than vaulted step by step.
		var stairs: bool = "stair" in file.to_lower()
		found[category].append({
			"name": file.get_basename().capitalize(),
			"kind": Kind.MODEL,
			"model": dir.path_join(file),
			"props": {"collision": LevelModel.Collision.SLOPE if stairs else LevelModel.Collision.MESH},
			"tip": "%s\n%s; change Collision or Model Scale in the inspector." % [file,
					"Collides as a smooth slope, so players walk up it" if stairs else "Collides with its exact shape"],
		})
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_scan_models(dir.path_join(sub), sub if category == "" else category.path_join(sub), found)
