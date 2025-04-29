extends Node
# A global handler for achievement state tracking. This should be refactored to address the issue
# where platform (Steam) achievements are awarded, but toast is not properly triggered. We should
# also display our own toast in the event that players are playing through itch or their own
# builds of the game.
#
# @author gbryant
# @copyright 2025 Heavy Element

# signal endgame_achievements()

# Achievement states
var state: Dictionary = {
	'COMPLETE_REGULATION': false, # Play 50 matches on any game type, each lasting 10 minutes
	'COMPLETE_VS': false, # Both players must register at least one goal
	'COMPLETE_CUSTOM': false, # Change at least one of the following settings and then play the game to completion: match point, min balls, ball type, pickup rate, or enabled pickups
	'WIN_EASY_3': false, # Beat an easy AI three times in a row
	'WIN_MED_3': false, # Beat a medium AI three times in a row
	'WIN_HARD_3': false, # Beat a hard AI three times in a row
	'WIN_IMP_3': false, # Beat an impossible AI three times in a row
	'TOTAL_MATCHES_100': false, # Win 100 matches. Any kind. Any rules. Against any type of opponent.
	'TOTAL_PICKUP_100': false, # Activate 100 pickups across all games
	'TOTAL_PICKUP_REMOVE': false, # Cancel 100 pickups
	'TOTAL_GET_PUNCH_100': false, # Get punched at least 100 times
	'TOTAL_GIVE_PUNCH_100': false, # Land 100 punches. Only punches landed on a Dudeling controlled by the opposing team counts
	'TOTAL_SCORE_100': false, # Score 100 goals of any kind
	'TOTAL_DASH_SCORE_100': false, # Score 100 goals using the dash ability
	'TOTAL_SCORE_1000': false, # Score 1000 points in any “Classic” game with default rules
	#'ACTION_CLUTCH_SAV: false, # Save the ball from entering the goal. Ball must be opposing color, second Dudeling must touch the ball on it’s “wrong side” to convert it and then the ball must hit the force field
	#'ACTION_SLAM_DUN: false, # On any ‘hoop’ game, score a point using a normal ball through the top of the hoop
	#'ACTION_POTENT_SERVE: false, # In an "Volley” game, use your goalie to score a point, Left- or right-most Dudeling must be the last Dudeling to touch the ball and it must score on “Volley”
	#'COMPLETE_FRENZ: false, # Play 12 matches of Frenzy mode
	#'COMPLETE_POSSESSIO: false, # Play 12 matches of Possession mode
	#'ACTION_KILL_SEAGUL: false, # Kill Stephen on any map at any time
	'ACTION_PICKUP_20': false, # Activate 20 pickups in a standard match (if the game rules match the “reset to default” rules)
	'ACTION_CANCEL_20': false,
	'DESTINATION_UNLOCKED': false,
}

# const TOTAL_PICKUP_100: Dictionary = {
# 	"name": "TOTAL_PICKUP_100",
# 	"value": 100
# }

# Called when the node enters the scene tree for the first time.
func _ready():
	# var _a = PlayerStats.connect("endgame_achievements", self, "_award_endgame")
	var _b = PlayerStats.connect("award_endgame", self, "_on_award_endgame")
	print("Achievement handler is ready")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_award_endgame() -> void:
	_play_fifty_games()
	_play_fifty_custom_games()
	_play_fifty_games_against_human()
	_complete_one_hundred_games()
	_ai_hattrick_checker()
	pass

func _award_achievement(achievement_id):
	print("Awarding Steam achievement \"%s\"" % achievement_id)
	# Pass the value to Steam then fire it
	SteamWrapper.setAchievement(achievement_id)
	var _a = SteamWrapper.storeStats()

# Regular Dudeling
func _play_fifty_games() -> void:
	if(PlayerStats.achievement_progression.regulation_games < 50): return
	_award_achievement("COMPLETE_REGULATION")

# Competitve Dude-mance
func _play_fifty_games_against_human() -> void:
	if(PlayerStats.achievement_progression.vs_human < 50): return
	_award_achievement("COMPLETE_VS")

# House Rules
func _play_fifty_custom_games() -> void:
	if(PlayerStats.achievement_progression.custom_games < 50): return
	_award_achievement("COMPLETE_CUSTOM")

# Heisendude Trophy
func _complete_one_hundred_games() -> void:
	var games_won = PlayerStats.achievement_progression.games_won
	if(games_won < 100): return
	_award_achievement("TOTAL_MATCHES_100")

# Minor Leagues/Major's Circuit/Gentleman's Cup/Elite's Club
func _ai_hattrick_checker() -> void:
	var key = PlayerStats._ai_player_hattrick_key
	if(!key): return
	if(PlayerStats.achievement_progression[key] < 3): return

	var difficulty = "";
	# Decide which achivement to award
	match PlayerStats._current_opponent:
		InputController.PlayerOptions.AI_EASY:
			difficulty = "EASY"
		InputController.PlayerOptions.AI_MEDIUM:
			difficulty = "MED"
		InputController.PlayerOptions.AI_HARD:
			difficulty = "HARD"
		InputController.PlayerOptions.AI_IMPOSSIBLE:
			difficulty = "IMP"

	_award_achievement("WIN_%s_3" % difficulty)

# Souvenir Collector
func _total_pickup_100(pickup_count) -> void:
	if(pickup_count < 100): return
	_award_achievement("TOTAL_PICKUP_100")

# Cleanup Crew
func _total_pickup_remove(pickup_count) -> void:
	if(pickup_count < 100): return
	_award_achievement("TOTAL_PICKUP_REMOVE")

# School of Hard Knocks
func _get_punched_100(knockout_count) -> void:
	if(knockout_count < 100): return
	_award_achievement("TOTAL_GET_PUNCH_100")


# Fighting Centurion
func _give_punch_100(knockout_count) -> void:
	if(knockout_count < 100): return
	_award_achievement("TOTAL_GIVE_PUNCH_100")

# Score King / Career Sportsman
func _score_based_achievements(career_score) -> void:
	if(career_score >= 1000):
		_award_achievement("TOTAL_SCORE_1000")
	elif(career_score >= 100):
		_award_achievement("TOTAL_SCORE_100")

# Advantage
func _action_pickup_20(pickup_count) -> void:
	if(pickup_count < 20): return
	_award_achievement("ACTION_PICKUP_20")

# Equalizer
func _action_cancel_20(pickup_count) -> void:
	if(pickup_count < 20): return
	_award_achievement("ACTION_CANCEL_20")

func _destination_unlocked() -> void:
	_award_achievement("DESTINATION_UNLOCKED")

######### HELPER FUNCTIONS #########
func _get_player_types(row: Dictionary) -> Dictionary:
	var easy_ai = InputController.PlayerOptions.AI_EASY;
	var home = row['player_home']
	var away = row['player_away']

	# We will initialize these as null so that we can later tell if both players
	# were the same type (AI v. AI or human v. human)
	var ai_player = null
	var human_player = null
	# Let's determine which player is an AI opponent
	if(home >= easy_ai):
		ai_player = "player_home"
	else:
		human_player = "player_home"

	# Let's check that we're not playing AI v. AI
	if(away >= easy_ai):
		ai_player = "player_away"
	else:
		human_player = "player_away"

	return {
		"human_player": human_player,
		"ai_player": ai_player
	}
