class_name PinField
extends GameField
# A script that controls which the Pin gametype
#
# @author gbryant
# @copyright 2024 Heavy Element

signal fractional_point(player, score, ball)

const MAX_PARTIAL_SCORE:int = 6;
var partial_score_tracker:Array = [0, 0]
var allowed_to_spawn_new_balls = true;

onready var pin_reset_sfx: AudioStreamOGGVorbis = preload("res://Assets/GameComponents/ArenaGoals/audio/pin-reset.ogg")
var _pin_retract_sounds: = [
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-a.ogg"),
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-b.ogg"),
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-c.ogg"),
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-d.ogg"),
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-e.ogg"),
	preload("res://Assets/GameComponents/ArenaGoals/audio/pin-retract-f.ogg"),
]

func _ready():
	allowed_to_spawn_new_balls = true;
	var _a = ArenaController.connect("game_ended", self, "_clean_up_balls")
	var _pin_container = $PinGoals
	for goal in _pin_container.get_children():
		goal.connect("fractional_point", self, "_on_fractional_point")
	ArenaController.bg_opacity = 0.2
	AudioController.play_game_sound(pin_reset_sfx, 0, AudioController.PITCH_SHIFT_FREQUENT)

func _on_fractional_point(team, ball) -> void:
	if(!team): return
	var index = team - 1;
	partial_score_tracker[index] += 1
	_award_score(partial_score_tracker[index], team, ball)
	self.emit_signal("fractional_point", team, partial_score_tracker[index], ball)

func _award_score(team_score, team, ball) -> void:
	if(team_score <= MAX_PARTIAL_SCORE):
		for child in $PinGoals.get_children():
			if(child.defending_player == team):
				continue
			# Set the audio stream to the correct pitch based on the fractional score of the player
			child.find_node("PinRetractSFX").stream = _pin_retract_sounds[team_score - 1]
			pass

	if team_score < MAX_PARTIAL_SCORE:
		return
	# Reset partial score to 0
	partial_score_tracker[team - 1] = 0

	ArenaController.give_points(team, 1)
	var _pin_goal = $PinGoals.get_child(0)
	_pin_goal._play_goal_scored_anim(ball)
	# var camera = Globals.get_tree().get_nodes_in_group(Globals.GAME_CAMERA_GROUP)
	# if camera[0]:
	# 	camera[0].shake_screen(0.5)
	_despawn_all_gameballs(ball)

	yield(Globals.get_tree().create_timer(1.25, true), "timeout")
	_reset_pins(team)

	yield(Globals.get_tree().create_timer(.3), "timeout")
	if allowed_to_spawn_new_balls: var _a = ArenaController.game_ball_spawner().spawn_game_ball()
	pass

func _reset_pins(player) -> void:
	AudioController.play_game_sound(pin_reset_sfx, player, AudioController.PITCH_SHIFT_MEDIUM)
	var _pin_container = $PinGoals
	for goal in _pin_container.get_children():
		if(goal.defending_player != player):
			goal.reset_pin()

func _despawn_all_gameballs(scoring_ball = null) -> void:
	var balls = get_tree().get_nodes_in_group(Globals.GAME_BALL_GROUP)
	for ball in balls:
		if ball == scoring_ball: continue
		var audio_player = ball.get_node("DespawnSound")
		audio_player.volume_db = -20
		ball._despawn()
	pass

func _clean_up_balls() -> void:
	allowed_to_spawn_new_balls = false
	pass
