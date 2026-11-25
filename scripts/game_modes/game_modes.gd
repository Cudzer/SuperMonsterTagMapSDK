class_name GameModes
## Registry of the game modes the host can pick. Mode ids are saved in Settings and replicated to
## clients, so only append new modes and never reorder them. Only data: the Map SDK copies this
## file as it is, so it mustn't name game classes (TagMatch.create_mode() makes the modes).

enum Id { FREE_TAG, ELIMINATION, TEAM_TAG, BASE_TAG, STUCK_IN_THE_MUD, HIVEMIND }

const NAMES: Array[String] = ["Free Tag", "Elimination", "Team Tag", "Base Tag", "Stuck in the Mud", "Hivemind"]
const DESCRIPTIONS: Array[String] = [
	"Classic tag with no time limit. The host ends the match.",
	"When the round timer runs out, whoever is it is eliminated. The last player standing wins.",
	"Two teams, one tagger each. A tag scores a point for your team and makes the tagged player a "
			+ "tagger for their own team. Taggers can't be tagged. Most points when time runs out wins.",
	"Run between the two bases to score. Taggers can't enter the bases or score. Reach the max "
			+ "score, or have the most points when time runs out, to win.",
	"Tagged runners are stuck in place until another runner slides into them. The taggers win "
			+ "if everyone is stuck; the runners win if they last until time runs out.",
	"One tagger starts the hive, and every runner they tag joins it. The taggers win if everyone "
			+ "joins the hive; the runners win if anyone is still free when time runs out.",
]
## The Start Match settings each mode uses (Settings names; see game.gd MATCH_OPTIONS, plus the No
## Tag-Backs switch, for modes where a tag passes "it" on). Modes that don't use a setting keep
## TagMatch's default for it.
const SETTINGS_USED: Array[Array] = [
	[&"no_tag_backs"],
	[&"round_length", &"immunity_time", &"no_tag_backs"],
	[&"round_length", &"immunity_time", &"no_tag_backs"],
	[&"round_length", &"immunity_time", &"tagger_count", &"max_score", &"no_tag_backs"],
	[&"round_length", &"immunity_time", &"tagger_count"],
	[&"round_length", &"immunity_time"],
]
## The map markers each mode needs, as {GameMap group: minimum count}. Maps without them can't
## host the mode (MapInfo.supports()).
const MARKERS_NEEDED: Array[Dictionary] = [
	{},
	{},
	{},
	{GameMap.BASE_SPAWN_POINTS: 2},
	{},
	{},
]


static func uses(id: int, setting: StringName) -> bool:
	return setting in SETTINGS_USED[id]
