extends Node
# The Globals class hosts constants, variables, and methods that are used throughout
# the game. This includes things like collection/physics enums, version numbers,
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

enum GamePhysicsLayerBit {
	ARENA = 0,
	DUDELING = 1,
	GAME_BALL = 2,
	ARENA_GOAL = 3,
	ARENA_PICKUP = 4,
	BACKGROUND = 5,
	SEAGULL = 6,
}
enum GamePhysicsLayerValue {
	ARENA = 1,
	DUDELING = 2,
	GAME_BALL = 4,
	ARENA_GOAL = 8,
	ARENA_PICKUP = 16,
	BACKGROUND = 32,
	SEAGULL = 64,
}
enum GameCanvasLayer {
	BACKGROUND = -1,
	MAIN = 0,
	HUD = 1,
	UI = 2,
	SHADER = 3,
	SCENE_SWITCHER = 4,  # Always on top.
	VIRTUAL_GAMEPAD = 5,
}

enum BuildPlatform {
	STEAM = 0,
	PC = 1,
	MOBILE = 32
}

const DUDELINGS_VERSION_NUMBER = "v1.2.1"
const IS_DEMO: bool = false
const BUILD_PLATFORM: int = BuildPlatform.STEAM
const SEEN_WHATS_NEW_KEY: String = "seen_whats_new_dialog_%s" % DUDELINGS_VERSION_NUMBER
const LEFT: int = -1
const RIGHT: int = 1
const GAME_ARENA_GROUP: String = "game_arena"
const GAME_ARENA_BACKGROUND_GROUP: String = "game_arena_background"
const GAME_FIELD_GROUP: String = "game_field"
const GAME_CAMERA_GROUP: String = "game_camera"
const AI_PLAYERS: String = "ai_players"
const DUDELING_GROUP: String = "dudelings"
const DUDELING_ROW_GROUP: String = "dudeling_row"
const GAME_BALL_GROUP: String = "game_balls"
const ACTIVE_GAME_BALL_GROUP: String = "active_game_balls"
const GAME_BALL_SPAWNER_GROUP: String = "game_ball_spawner"
const ARENA_GOAL_GROUP: String = "arena_goals"
const ARENA_PICKUP_GROUP: String = "arena_pickups"
const ARENA_PICKUP_SPAWNER_GROUP: String = "arena_pickup_spawner"
const CROWD_GROUP: String = "crowds"
const HOME_CROWD_GROUP: String = "home_crowds"
const AWAY_CROWD_GROUP: String = "away_crowds"
const PLAYER_HUD_GROUP: String = "player_hud"
const MENU_GROUP: String = "menus"
const BUTTON_CONTEXT_BAR_GROUP: String = "button_context_bar"
const HE_NOTIFICATION_GROUP: String = "he_notification"

const SEAGULL_SPAWN_CHANCE: float = 0.01;
const SEAGULL_SPAWN_MIM_DELAY: float = 1.0
const SEAGULL_SPAWN_MAX_DELAY: float = 60.0

var rng := RandomNumberGenerator.new()
var debug_layer: CanvasLayer
var ai_debug_state: bool = false
var ident: String = ""
var telemetry = null
var hE_announcements
var hE_announce_last: float = 0.0
var notifications:Array = []

func _init() -> void:
	print("====================================================================")
	print("Launching Dudelings: Arcade Sportsball %s" % DUDELINGS_VERSION_NUMBER)
	print("====================================================================")
	rng.randomize()


func _ready() -> void:
	self._make_debug_layer()


func focused_menu() -> Control:
	var all_menus: Array = self.get_tree().get_nodes_in_group(Globals.MENU_GROUP)
	return null if all_menus.empty() else all_menus[-1]


func other_player(target_player: int) -> int:
	if (target_player == 1): return 2
	if (target_player == 2): return 1
	return 0

func min_dudeling_index() -> int:
	return 0


func center_dudeling_index() -> int:
	return 11


func max_dudeling_index() -> int:
	if(ArenaController.get_current_game_field_index() == ArenaController.GameField.VOLLEY_GAME_FIELD): return 21
	return 22;
	# return(
	# 	21 if  else
	# 	22
	# )


func capitalize(string: String) -> String:
	return string[0].to_upper() + string.substr(1, -1).replace("_", " ").to_lower()


func uppercase(string: String) -> String:
	return string.replace("_", " ").to_upper()


func quit_application() -> void:
	Globals.get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)

static func int_in_range(value: int, range_min: int, range_max: int) -> bool:
	return value > range_min && value < range_max


static func int_out_of_range(value: int, range_min: int, range_max: int) -> bool:
	return value < range_min || value > range_max


static func float_in_range(value: float, range_min: float, range_max: float) -> bool:
	return value > range_min && value < range_max


static func float_out_of_range(value: float, range_min: float, range_max: float) -> bool:
	return value < range_min || value > range_max

# REMOVE THIS IN GAME BUILDS.
func _make_debug_layer() -> void:
	debug_layer = CanvasLayer.new()
	self.add_child(debug_layer)
	debug_layer.set_layer(GameCanvasLayer.SCENE_SWITCHER + 1)

	var performance_panel: PerformancePanel = load("res://GameUI/PerformancePanel/PerformancePanel.tscn").instance()
	debug_layer.add_child(performance_panel)

func _allow_stats_and_achievements() -> bool:
	if Commands.enable_cheats == true: return false
	if Commands.allow_achievements == false: return false
	return true

func mark_announcement_as_seen(_id) -> void:
	notifications.push_back(_id)
	GameSettingsData.save_game_setting(GameSettingsData.NOTIFICATION, "notification", notifications)

func dictionary_merge(dict_1: Dictionary, dict_2: Dictionary, deep_merge: bool = false) -> Dictionary:
	var new_dictionary: Dictionary = dict_1.duplicate(true)
	for key in dict_2:
		if key in new_dictionary:
			if deep_merge and dict_1[key] is Dictionary and dict_2[key] is Dictionary:
				new_dictionary[key] = dictionary_merge(dict_1[key], dict_2[key])
			elif deep_merge and dict_1[key] is Array and dict_2[key] is Array:
				new_dictionary[key] = array_merge(dict_1[key], dict_2[key])
			else:
				new_dictionary[key] = dict_2[key]
		else:
			new_dictionary[key] = dict_2[key]
	return new_dictionary

func array_merge(array_1: Array, array_2: Array, deep_merge: bool = false) -> Array:
	var new_array = array_1.duplicate(true)
	var compare_array = new_array
	var item_exists

	if deep_merge:
		compare_array = []
		for item in new_array:
			if item is Dictionary or item is Array:
				compare_array.append(JSON.print(item))
			else:
				compare_array.append(item)

	for item in array_2:
		item_exists = item
		if item is Dictionary or item is Array:
			item = item.duplicate(true)
			if deep_merge:
				item_exists = JSON.print(item)

		if not item_exists in compare_array:
			new_array.append(item)
	return new_array


func _demo_check() -> bool:
	if Globals.IS_DEMO:
		var demo_nag_scene = load("res://GameUI/Menus/SubMenus/FullGamePopup/FullGamePopup.tscn").instance()
		get_tree().root.add_child(demo_nag_scene)
		return true
	return false
