extends Node
## Stands in for the game's Sound autoload in the Map SDK: the toys play sounds in game, never in
## the editor, so this declares what they call and plays nothing. The SDK ships none of the game's
## sounds. The Sfx list is copied from the real script when the SDK is built.

# Copied from res://globals/sound.gd when the SDK was built.
enum Sfx {
	SLAP, TAGGED, COIN, FOOTSTEP, JUMP_PAD, STUNNED, EMOTE_1, EMOTE_2, EMOTE_3, EMOTE_4, LANDING, ZIPLINE,
	TELEPORT_CHARGE, TELEPORT,
	DOUBLE_JUMP, DASH, SLIDE, VAULT, WALL_STEP, POOF, FREEZE, THAW, HIVE, BASE_SCORE, BUTTON, BOOST,
}


func play_at(_sound: Sfx, _parent: Node, _at: Vector3, _pitch_spread: float = 0.08,
		_volume_offset_db: float = 0.0, _pitch: float = 1.0, _from: float = 0.0) -> AudioStreamPlayer3D:
	return null


func caption(_text: String, _at: Vector3) -> void:
	pass


func fade_out(_sound: Variant, _seconds: float = 0.15) -> void:
	pass


func rustle_stream() -> AudioStreamWAV:
	return null


func fountain_stream() -> AudioStreamWAV:
	return null
