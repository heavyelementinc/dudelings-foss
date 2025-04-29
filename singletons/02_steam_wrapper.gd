extends Node
# A wrapper for the Steam platform. This was built to allow the game to ship
# without the Steamworks library and still provide a functional experience
# without having to modify the game's code to strip out the references to Steam.
#
# @author gbryant
# @copyright 2025 Heavy Element

var steam
var initialize_response

var initialized = false
var this_platform: String = "itch"
var is_online: bool = false
var is_owned: bool = false
var steam_app_id: int = 1905160
var steam_id: int = 0
var steam_username: String = ""
var is_on_steam_deck: bool = false
var is_free_weekend: bool = false

var current_stats: bool = false

var _overlay_open: bool = false

var _stats: Dictionary = {}

enum SteamInputTypes {
	INPUT_TYPE_UNKNOWN = 0,
	INPUT_TYPE_STEAM_CONTROLLER = 1,
	INPUT_TYPE_XBOX360_CONTROLLER = 2,
	INPUT_TYPE_XBOXONE_CONTROLLER = 3,
	INPUT_TYPE_GENERIC_XINPUT = 4,
	INPUT_TYPE_PS4_CONTROLLER = 5,
	INPUT_TYPE_APPLE_MFI_CONTROLLER = 6,
	INPUT_TYPE_ANDROID_CONTROLLER = 7,
	INPUT_TYPE_SWITCH_JOYCON_PAIR = 8,
	INPUT_TYPE_SWITCH_JOYCON_SINGLE = 9,
	INPUT_TYPE_SWITCH_PRO_CONTROLLER = 10,
	INPUT_TYPE_MOBILE_TOUCH = 11,
	INPUT_TYPE_PS3_CONTROLLER = 12,
	INPUT_TYPE_PS5_CONTROLLER = 13,
	INPUT_TYPE_STEAM_DECK_CONTROLLER = 14,
	INPUT_TYPE_COUNT = 15,
	INPUT_TYPE_MAXIMUM_POSSIBLE_VALUE = 255,
}

# Set your game's Steam app IP
func _init() -> void:
	print("Initializing Steam...")
	var _a = OS.set_environment("SteamAppId", str(steam_app_id))
	var _b = OS.set_environment("SteamGameId", str(steam_app_id))
	# Initialize Steam

func _ready():
	if (Steam):
		steam = Steam
		initialize_response = steam.steamInitEx(false, steam_app_id) # .steamInitEx(false)
		print("[STEAM] Did Steam initialize?: %s" % initialize_response)
		if initialize_response['status'] != 0:
			# If Steam fails to start up, shut down the app
			print("[STEAM] Failed to initialize Steam: %s" % initialize_response['verbal'])
			#get_tree().quit()

		# Some example functions to run after initializing.
		# These can be deleted or commented out if not needed.
		#############################################
		#Is the user online?
		is_online = steam.loggedOn()

		# Get the user's Stean name and ID
		steam_id = steam.getSteamID()
		steam_username = steam.getPersonaName()

		# Is this app owned or is it a free weekend?
		is_owned = steam.isSubscribed()
		is_free_weekend = steam.isSubscribedFromFreeWeekend()

		# Is the game running on the Steam Deck
		is_on_steam_deck = steam.isSteamRunningOnSteamDeck()
		steam_ready()
	else:
		print("[STEAM] Did Steam initialize?: %s" % initialize_response)
		steam_failed()
	initialized = true

func _process(_delta: float) -> void:
	# Get callbacks
	steam.run_callbacks()

func steam_ready():
	# Set platform identifier to "steam"
	this_platform = "steam"
	# Store the initialization response
	var response = initialize_response

	var _a = steam.connect("current_stats_received", self, "_on_steam_stats_ready", [], CONNECT_ONESHOT)
	#current_stats = steam.requestCurrentStats()

	# In case it does fail, let's find out why and null the steam_api object
	if response['status'] > 0:
		print("Failed to initialize Steam, disabling all Steamworks functionality: %s" % initialized)
	else:
		print("SteamWrapper has initialized")

	# Set the notification position
	setOverlayNotificationPosition(1)
	# Is the user online?
	# is_online = Steam.is_online
	# steam_id = Steam.steam_id
	# steam_username = Steam.steam_username
	# is_owned = Steam.is_owned
	# is_free_weekend = Steam.is_free_weekend
	# is_on_steam_deck = Steam.is_on_steam_deck

func steam_failed():
	this_platform = "itch" # Could be anything else really like a console, etc.
	steam_id = 0
	steam_username = "You"
	print("SteamWrapper has NOT initialized. Continuing.")

#func _process(_delta):
#	if(!is_steam_enabled()): return
#	var is_overlay_open = Steam.isOverlayEnabled()
#	if(_overlay_open == false && is_overlay_open):
#		ArenaController.set_game_paused(true)
#		_overlay_open = true
#	if(_overlay_open == true && !is_overlay_open):
#		ArenaController.set_game_paused(false)
#		_overlay_open = false

func _on_steam_stats_ready(game: int, result: int, user: int):
	print("Stats for game %s ready" % game)
	print("Call result: %s" % result)
	print("User ID: %s" % user)
	for state in Achievements.state.keys():
		get_achievement(state)
	print("Achievement states synchronized")
	return

func get_achievement(value: String) -> void:
	var this_achievement: Dictionary = steam.getAchievement(value)

	# Achievement exists
	if this_achievement['ret']:

		# Achievement is unlocked
		if this_achievement['achieved']:
			Achievements.state[value] = true

		# Achievement is locked
		else:
			Achievements.state[value] = false

	# Achievement does not exist
	else:
		Achievements.state[value] = false

# Check if Steam has been initialized
func is_steam_enabled() -> bool:
	if this_platform == "steam":
		return true
	return false

func setOverlayNotificationPosition(position: int) -> void:
	if (!is_steam_enabled()): return
	steam.setOverlayNotificationPosition(position)

# Steam rich presence causes a segmentation fault. Let's just stub this out for now.
func setRichPresence(token: String) -> void:
	if(!is_steam_enabled()): return
	return
	# var _setting_presence = steam.setRichPresence("steam_display", token)
	# print("Setting presence to token: %s" % token)
	# pass

func setStatsInt(name: String, value: int) -> bool:
	if (!is_steam_enabled()): return false
	var result = steam.setStatInt(name, value)
	return result

func storeStats() -> bool:
	if (!is_steam_enabled()): return false
	return steam.storeStats()

func setAchievement(id) -> void:
	if (!is_steam_enabled()):
		print("Steam environment not detected, aborting.")
		return
	if (Achievements.state[id]):
		print("Player already has achievement \"%s\" set, aborting" % id)
		return
	steam.setAchievement(id)
	return

func RemotePlayTogetherSetup(session_start) -> void:
	if (!is_steam_enabled()): return
	# if(getSessionCount() == 0):
	# 	Steam.activateGameOverlay("Friends")
	steam.startRemotePlayTogether(session_start)

func getSessionCount() -> int:
	if (!is_steam_enabled()): return 0
	return steam.getSessionCount()

func getFriendlyControllerDeviceName(device) -> String:
	if (!is_steam_enabled()): return Input.get_joy_name(device)
	var device_handle: int = steam.getControllerForGamepadIndex(device - 1)
	if (device_handle == 0): return "Xbox"
	var device_type = steam.getInputTypeForHandle(device_handle)
	match (device_type):
		SteamInputTypes.INPUT_TYPE_STEAM_CONTROLLER:
			return "Xbox"
		SteamInputTypes.INPUT_TYPE_XBOX360_CONTROLLER:
			return "Xbox"
		SteamInputTypes.INPUT_TYPE_XBOXONE_CONTROLLER:
			return "Xbox"
		SteamInputTypes.INPUT_TYPE_GENERIC_XINPUT:
			return "Xinput"
		SteamInputTypes.INPUT_TYPE_PS4_CONTROLLER:
			return "PS4"
		SteamInputTypes.INPUT_TYPE_PS5_CONTROLLER:
			return "PS5"
		SteamInputTypes.INPUT_TYPE_SWITCH_PRO_CONTROLLER:
			return "Switch Pro"
		SteamInputTypes.INPUT_TYPE_STEAM_DECK_CONTROLLER:
			return "Xbox"
		_:
			return "Xbox"

func is_player(team: int) -> bool:
	match team:
		InputController.PlayerOptions.KEYBOARD:
			return true
		InputController.PlayerOptions.CONTROLLER_ONE:
			return true
		InputController.PlayerOptions.CONTROLLER_TWO:
			return true

	return false
