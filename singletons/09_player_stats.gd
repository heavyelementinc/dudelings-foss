extends Node
# Handle player stat tracking, reading/writing of stats, etc.
#
# @author gbryant
# @copyright 2025 Heavy Element

signal destination_unlocked()
signal award_endgame(database)

enum MatchMode {
	MATCH_POINT,
	MATCH_TIME,
}

enum Outcome {
	GAME_QUIT,
	MATCH_POINT,
	MATCH_TIME,
	OVERTIME_POINT,
}

enum ItemUnlocks {
	UNLOCK_ARENA_DESTINATION = 0b0001,
	UNLOCK_JERSEY_HOCKEY = 0b0010,
	UNLOCK_JERSEY_TENNIS = 0b0100,
	UNLOCK_JERSEY_BOWLING = 0b1000,
}

const HOME_TEAM = 1
const AWAY_TEAM = 2
const NULL_TEAM = 0

const GAME_MODE_NAME = "game_type_victories"
const MIN_GAME_TYPE = 3


var settings = GameSettingsData.new()

var _is_in_match: bool = false;

# Will be set to InputController.PlayerOptions enum
var _current_human_player: int = -1
# Will be set to InputController.PlayerOptions enum
var _current_opponent: int = -1
var _is_this_a_custom_game: bool = false

# Will be set to 1 for HOME or 2 for AWAY
var team_to_track_stats: int = 0
var _ai_player_hattrick_key: String = ""

var game_stats : Dictionary = {
	"give_punch": 0,
	"get_punched": 0,
	"knocked_out": 0,
	"pickups_activated": 0,
	"pickups_cancelled": 0,
}

var achievement_progression : Dictionary = {
	"total_score": 0, # working
	"mode_0": 0, # Number of times you've played each mode
	"mode_1": 0,
	"mode_2": 0,
	"mode_3": 0,
	"vs_human": 0,
	"regulation_games": 0, # working
	"custom_games": 0, # working
	"remote_games": 0,
	"games_won": 0, # working
	"games_played": 0, # working
	"games_quit": 0, # working
	"give_punch": 0, # Number of punches thrown, regardless of if you knocked out an opponent-controlled Dudeling or not
	"get_punched": 0, # Number of times a Dudeling you're controlling has been knocked out
	"knocked_out": 0, # Number of times you've knocked out an opponent-controlled Dudeling
	"pickups_activated": 0, # Number of pickups your team has activated
	"pickups_cancelled": 0, # Number of pickups your team has cancelled/removed from the field
	"hattrick_0": 0, # AI Difficulty hattrick
	"hattrick_1": 0,
	"hattrick_2": 0,
	"hattrick_3": 0,
	"%s_0" % GAME_MODE_NAME: 0,
	"%s_1" % GAME_MODE_NAME: 0,
	"%s_2" % GAME_MODE_NAME: 0,
	"%s_3" % GAME_MODE_NAME: 0,
}

func save_stats() -> void:
	if(Globals._allow_stats_and_achievements() == false):
		for stat in achievement_progression:
			achievement_progression[stat] = 0
		_reset_game_stats()
		return

	# We need to add whatever game stats
	_sum_achievement_progress()
	_reset_game_stats()
	for stat_name in achievement_progression:
		settings.save_game_setting(settings.STATS_SECTION, stat_name, achievement_progression[stat_name])

func _init():
	_reset_game_stats()

# Called when the node enters the scene tree for the first time.
func _ready():
	var _a = ArenaController.connect("game_started", self, "_on_game_started")
	# var _b = ArenaController.connect("score_changed", self, "_on_score_changed")
	var _b = ArenaController.connect("player_scored", self, "_on_player_scored")
	var _c = ArenaController.connect("game_ended", self, "_on_game_ended")
	var _d = ArenaController.connect("game_won", self, "_on_game_won")
	settings.load_game_settings(settings.STATS_SECTION)
	print("Player stats have been loaded")


func _on_game_started() -> void:
	# Reset our in-memory tracking for this singleton when a new game starts
	_reset_game_stats()

	print("### START ACHIEVEMENT PROGRESS ###")
	for stat in achievement_progression:
		_debug_stats(stat, achievement_progression[stat])
	print("### END ACHIEVEMENT PROGRESS ###")
	var _d = get_first_team()
	var dudeling_row = ArenaController.dudeling_row();
	var _a = dudeling_row.connect("punch_thrown", self, "_on_punch_thrown")
	# var _b = dudeling_row.connect("dash_triggered", self, "_on_dash_triggered")
	var _c = ArenaController.arena_pickup_spawner().connect("pickup_spawned", self, "_on_pickup_spawn")

	_is_in_match = true;
	var _allowed_pickups: int = 0;

	achievement_progression["games_played"] += 1
	var game_type = "mode_%s" % ArenaController.get_current_game_field_index()
	achievement_progression[game_type] += 1
	_is_this_a_custom_game = _is_custom_game()
	if !_is_this_a_custom_game:
		achievement_progression['regulation_games'] += 1
		_debug_stats('regulation_games', achievement_progression['regulation_games'])
	else:
		achievement_progression['custom_games'] += 1
		_debug_stats('custom_games', achievement_progression['custom_games'])

	var hattrick_trackers: Array = ["hattrick_0","hattrick_1","hattrick_2","hattrick_3",]

	for key in hattrick_trackers:
		# always reset the hattrick keys
		if(_ai_player_hattrick_key != key): achievement_progression[key] = 0
	var sessions = SteamWrapper.getSessionCount()
	if(sessions != 0):
		achievement_progression['remote_games'] += 1

	print("Steam remote play sessions: %s" % sessions)
	save_stats()
	return

func _on_game_ended() -> void:
	cleanup_signals()

	var scores : Array = [
		ArenaController.player_one_score >= GameplayController.get_points_to_win(),
		ArenaController.player_two_score >= GameplayController.get_points_to_win(),
	]
	var human_player_wins: bool = (
		scores[0] if team_to_track_stats == 1 else
		scores[1] if team_to_track_stats == 2 else
		false
	)
	# award_endgame will ONLY EMIT when the appropriate player wins
	if(human_player_wins):
		achievement_progression["games_won"] += 1
		if(is_human(_current_opponent)): achievement_progression["vs_human"] += 1
		else:
			achievement_progression[_ai_player_hattrick_key] += 1

		yield(get_tree().create_timer(2), "timeout")
		self.emit_signal("award_endgame")
	else:
		achievement_progression["games_quit"] += 1
		# Reset the hattrick tracker on game quit
		achievement_progression[_ai_player_hattrick_key] = 0

	save_stats()

func check_destination_unlocked() -> void:
	if GameplayController.destination_unlocked: return
	achievement_progression["%s_%s" % [GAME_MODE_NAME, ArenaController.current_game_field_index]] += 1
	var mode_classic = "%s_0" % GAME_MODE_NAME
	var mode_hoop = "%s_1" % GAME_MODE_NAME
	var mode_volley = "%s_2" % GAME_MODE_NAME
	var mode_pins = "%s_3" % GAME_MODE_NAME

	var classic_satisfied = achievement_progression[mode_classic] >= MIN_GAME_TYPE
	var hoop_satisfied = achievement_progression[mode_hoop] >= MIN_GAME_TYPE
	var volley_satisfied = achievement_progression[mode_volley] >= MIN_GAME_TYPE
	var pins_satisfied = achievement_progression[mode_pins] >= MIN_GAME_TYPE

	if classic_satisfied && hoop_satisfied && volley_satisfied && pins_satisfied:
		GameSettingsData.save_game_setting(GameSettingsData.STATS_SECTION, "destination_unlocked", true)
		Achievements._destination_unlocked()
		if !GameplayController.destination_unlocked: emit_signal("destination_unlocked")
		else: GameplayController.destination_unlocked = true

	save_stats()

func _on_game_won(_detail) -> void:
	pass

func _on_player_scored(player:int) -> void:
	if(player != 1): return
	achievement_progression["total_score"] += 1
	_debug_stats("total_score", achievement_progression['total_score'])


func _on_punch_thrown(team:int, _target_dudeling, is_hit_dudeling_other_team:bool) -> void:
	if(team != 1 && is_hit_dudeling_other_team):
		game_stats["get_punched"] += 1
		Achievements._get_punched_100(game_stats['get_punched'] + achievement_progression['get_punched'])
		_debug_stats("get_punched", game_stats['get_punched'])
		return
	if(team != 1): return
	game_stats["give_punch"] += 1
	_debug_stats("give_punch", game_stats['give_punch'])
	if(is_hit_dudeling_other_team):
		game_stats["knocked_out"] += 1
		Achievements._get_punched_100(game_stats['knocked_out'] + achievement_progression['knocked_out'])
		_debug_stats("knocked_out", game_stats['knocked_out'])

# func _on_dash_triggered(team) -> void:
# 	if(team == 1):
# 		game_stats[]


# PICKUP HANDLERS

func _on_pickup_spawn(pickup) -> void:
	# When a pickup is spawned, we want to connect to its signals
	pickup.connect("pickup_activated", self, "_on_pickup_activated")
	pickup.connect("pickup_canceled", self, "_on_pickup_canceled")

func _on_pickup_activated(_pickup, _activating_player) -> void:
	if(_activating_player != 1): return
	game_stats["pickups_activated"] += 1
	Achievements._action_pickup_20(game_stats["pickups_activated"])
	Achievements._total_pickup_100(game_stats["pickups_activated"] + achievement_progression["pickups_activated"])
	_debug_stats("pickups_activated", game_stats['pickups_activated'])

func _on_pickup_canceled(_pickup, _activating_player) -> void:
	if(_activating_player != 1): return
	game_stats["pickups_cancelled"] += 1
	Achievements._action_cancel_20(game_stats["pickups_cancelled"])
	Achievements._total_pickup_remove(game_stats["pickups_cancelled"] + achievement_progression["pickups_cancelled"])
	_debug_stats("pickups_cancelled", game_stats['pickups_cancelled'])

func _debug_stats(name, value) -> void:
	print("[STATS] %s: %s" % [name, value])

######## HELPER FUNCTIONS ############

# Let's clean up. I don't know if any of this is strictly necessary, but it
# feels like the right thing to do. I know ArenaController is a singleton and it
# exists whether we're in game or not, so we're only removing signals we add at
# match startup.
func cleanup_signals() -> void:
	var dudeling_row = ArenaController.dudeling_row();
	dudeling_row.disconnect("punch_thrown", self, "_on_punch_thrown")
	dudeling_row.disconnect("dash_triggered", self, "_on_dash_triggered")
	ArenaController.arena_pickup_spawner().disconnect("pickup_spawned", self, "_on_pickup_spawn")

func _reset_game_stats() -> void:
	game_stats['give_punch'] = 0
	game_stats['knocked_out'] = 0
	game_stats['pickups_activated'] = 0
	game_stats['pickups_cancelled'] = 0
	return

func _sum_achievement_progress() -> void:
	for stats in game_stats:
		_debug_stats(stats, "WAS: %s, IS: %d" % [achievement_progression[stats], achievement_progression[stats] + game_stats[stats]])
		achievement_progression[stats] += game_stats[stats]

func _is_custom_game() -> bool:
	var default_game_rules = GameplayController.field_rules[ArenaController.current_game_field_index]
	for key in default_game_rules:
		if GameplayController[key] != default_game_rules[key]: return true
	return false;

func get_team_string(team: int):
	if(team == 1): return "home"
	return "away"

func get_first_team() -> int:
	var home_team = InputController.player_one_control_option
	var away_team = InputController.player_two_control_option

	## If there are two players, only the HOME TEAM (team = 1) should have their stats tracked
	if(is_human(home_team) && is_human(away_team)):
		_current_human_player = home_team
		_current_opponent = away_team
		team_to_track_stats = HOME_TEAM
		_ai_player_hattrick_key = ""
		return HOME_TEAM

	## If the game is AI vs. AI, no stats should be tracked (return 0)
	var human_player := NULL_TEAM

	## If the game is HUMAN vs. AI, then the human player's stats should be tracked
	if(is_human(home_team) && !is_human(away_team)):
		human_player = HOME_TEAM
		_current_human_player = home_team
		_current_opponent = away_team

	elif(is_human(away_team) && !is_human(home_team)):
		human_player = AWAY_TEAM
		_current_human_player = away_team
		_current_opponent = home_team

	_ai_player_hattrick_key = "hattrick_%s" % abs(_current_opponent - InputController.PlayerOptions.AI_EASY)
	team_to_track_stats = human_player
	return human_player

func is_human(team:int):
	if(team < InputController.PlayerOptions.AI_EASY): return true
	return false
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

