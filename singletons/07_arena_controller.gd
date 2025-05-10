extends Node
# A singleton that controls arena gameplay.
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

signal game_started()
signal game_paused(is_paused)
signal overtime_start()
signal game_won(winning_player)
signal game_ended()
signal game_run_time_changed(new_time)
signal score_changed()
signal player_scored(scoring_player)
signal game_field_changed(old_index, new_index)
signal two_min_warning()
signal one_min_warning()
signal thirty_sec_warning()
signal bg_opacity_update(value)

enum GameState {
	PREGAME = 1
	IN_GAME = 2,
	GAME_OVER = 4,
	GAME_PAUSED = 8,
}
enum GameField {
	CLASSIC_GAME_FIELD,
	HOOP_GAME_FIELD,
	VOLLEY_GAME_FIELD,
	PIN_GAME_FIELD,
}
enum Background {
	CITY,
	BEACH,
	STADIUM,
	INFIELD,
	DESTINATION,
	GYM,
}

const START_GAME_SOUND: AudioStreamOGGVorbis = preload("res://Assets/GameScenes/GameArena/audio/game_start_whistle.ogg")
const PAUSE_GAME_SOUND: AudioStreamOGGVorbis = preload("res://Assets/GameScenes/GameArena/audio/game_paused.ogg")
const END_GAME_SOUND: AudioStreamOGGVorbis = preload("res://Assets/GameScenes/GameArena/audio/final_score.ogg")
const DEFAULT_BG_OPACITY: float = 0.0

var current_game_field_index: int = GameField.CLASSIC_GAME_FIELD setget set_current_game_field_index, get_current_game_field_index
var current_background_index: int = Background.BEACH setget set_current_background_index, get_current_background_index
var game_paused: bool = false setget set_game_paused, get_game_paused
var total_game_run_time: int = 0
var game_run_time: int = 0 setget , get_game_run_time
var player_one_score: int = 0 setget , get_player_one_score
var player_two_score: int = 0 setget , get_player_two_score
var game_in_overtime: bool = false
var bg_opacity: float = DEFAULT_BG_OPACITY setget set_bg_opacity, get_bg_opacity

var _current_game_state: int = 0
var _game_run_time_timer: Timer = null


func set_current_game_field_index(new_value: int) -> void:
	emit_signal("game_field_changed", current_game_field_index, new_value)
	current_game_field_index = new_value

func get_current_game_field_index() -> int:
	return current_game_field_index


func set_current_background_index(new_value: int) -> void:
	current_background_index = new_value
	if(GameplayController.gametype == GameplayController.Gametypes.TIMED_MATCH):
		game_run_time = GameplayController.time_limit
		self.emit_signal("game_run_time_changed", game_run_time)


func get_current_background_index() -> int:
	return current_background_index


func set_game_paused(new_value: bool) -> void:
	if new_value == game_paused:
		return

	game_paused = new_value

	Globals.get_tree().call_deferred("set_pause", game_paused)  # 'call_deferred' to allow for scene tree to update.

	if game_paused:
		self._add_game_state(GameState.GAME_PAUSED)
		AudioController.play_universal_sound(ArenaController.PAUSE_GAME_SOUND)
	else:
		self._remove_game_state(GameState.GAME_PAUSED)

	self.emit_signal("game_paused", game_paused)


func get_game_paused() -> bool:
	return game_paused


func get_game_run_time() -> int:
	return game_run_time


func get_player_one_score() -> int:
	return player_one_score


func get_player_two_score() -> int:
	return player_two_score


func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)

func _ready():
	pass

func player_score(target_player: int) -> int:
	return (
		player_one_score if target_player == 1 else
		player_two_score if target_player == 2 else
		-1
	)

func game_arena() -> GameArena:
	return self.get_tree().get_nodes_in_group(Globals.GAME_ARENA_GROUP)[-1] as GameArena  # There should only be one.


func game_arena_background() -> ArenaBackground:
	return self.get_tree().get_nodes_in_group(Globals.GAME_ARENA_BACKGROUND_GROUP)[-1] as ArenaBackground  # There should only be one.


func game_field() -> GameField:
	return self.get_tree().get_nodes_in_group(Globals.GAME_FIELD_GROUP)[-1] as GameField  # There should only be one.


func dudeling_row() -> DudelingRow:
	return self.get_tree().get_nodes_in_group(Globals.DUDELING_ROW_GROUP)[-1] as DudelingRow  # There should only be one.


func game_ball_spawner() -> GameBallSpawningArea:
	return self.get_tree().get_nodes_in_group(Globals.GAME_BALL_SPAWNER_GROUP)[-1] as GameBallSpawningArea  # There should only be one.


func arena_pickup_spawner() -> AreaPickupSpawningArea:
	return self.get_tree().get_nodes_in_group(Globals.ARENA_PICKUP_SPAWNER_GROUP)[-1] as AreaPickupSpawningArea  # There should only be one.


func player_hud() -> PlayerHUD:
	return self.get_tree().get_nodes_in_group(Globals.PLAYER_HUD_GROUP)[-1] as PlayerHUD  # There should only be one.


func current_game_state_contains(target_state: int) -> bool:
	return true if _current_game_state & target_state else false


func give_points(target_player: int, number_of_points: int) -> void:
	if target_player == 1:
		player_one_score += number_of_points
	elif target_player == 2:
		player_two_score += number_of_points

	self.emit_signal("player_scored", target_player)
	self.emit_signal("score_changed")

	if game_in_overtime:
		self.end_game(target_player)

	if( GameplayController.gametype == GameplayController.Gametypes.MATCH_POINT):
		if player_one_score >= GameplayController.get_points_to_win():
			self.end_game(1)
		elif player_two_score >= GameplayController.get_points_to_win():
			self.end_game(2)

func start_game() -> void:
	game_in_overtime = false;
	match(GameplayController.gametype):
		GameplayController.Gametypes.TIMED_MATCH:
			game_run_time = GameplayController.time_limit
		_:
			pass
	self._remove_game_state(GameState.PREGAME)
	self._add_game_state(GameState.IN_GAME)
	_game_run_time_timer.start()
	AudioController.play_universal_sound(START_GAME_SOUND, [1.0])
	self.emit_signal("game_started")


func end_game(winning_player: int = -1) -> void:
	AudioController.play_universal_sound(END_GAME_SOUND, [1.0])

	_game_run_time_timer.stop()
	self._remove_game_state(GameState.PREGAME | GameState.IN_GAME)
	self._add_game_state(GameState.GAME_OVER)

	self.emit_signal("game_ended")

	if winning_player > 0:
		self.emit_signal("game_won", winning_player)


func leave_game() -> void:
	self.end_game()
	self._change_current_game_state(0)


func reset_game_arena() -> void:
	self._change_current_game_state(GameState.PREGAME)

	game_run_time = 0

	if is_instance_valid(_game_run_time_timer):
		_game_run_time_timer.queue_free()

	_game_run_time_timer = self._make_game_run_time_timer()

	if GameplayController.gametype == GameplayController.Gametypes.TIMED_MATCH:
		self.emit_signal("game_run_time_changed", GameplayController.time_limit)
	else:
		self.emit_signal("game_run_time_changed", game_run_time)

	player_one_score = 0
	player_two_score = 0
	self.emit_signal("score_changed")


func find_goal_pos(controlling_player: int) -> Vector2:
	var arena_goals: Array = Globals.get_tree().get_nodes_in_group(Globals.ARENA_GOAL_GROUP)

	if arena_goals.size() == 1:
		return arena_goals[0].get_global_position()
	elif arena_goals.size() == 2:
		for arena_goal in arena_goals:
			if arena_goal.get_defending_player() == controlling_player:
				return arena_goal.get_global_position()
	else:
		var target_goal: ArenaGoal
		for peg_goal in arena_goals:
			if peg_goal.get_defending_player() == controlling_player && peg_goal.fractional_point_eligible:
				target_goal = peg_goal

		if not target_goal:
			print("`target_goal` was null!")
			return Vector2(0.0, 0.0)

		return target_goal.get_global_position()

	return Vector2(640.0, 360.0)  # Default if there are no goals.


func _change_current_game_state(new_value: int) -> void:
	if _current_game_state ^ new_value:
		_current_game_state = new_value


func _add_game_state(new_state: int) -> void:
	self._change_current_game_state(_current_game_state | new_state)


func _remove_game_state(target_state: int) -> void:
	self._change_current_game_state(_current_game_state & ~target_state)


func _make_game_run_time_timer() -> Timer:
	var run_timer := Timer.new()
	self.add_child(run_timer)
	run_timer.set_pause_mode(PAUSE_MODE_STOP)
	run_timer.set_wait_time(1.0)
	var _a = run_timer.connect("timeout", self, "_update_game_run_time")
	return run_timer


func _update_game_run_time() -> void:
	total_game_run_time += 1
	match(GameplayController.gametype):
		GameplayController.Gametypes.MATCH_POINT:
			game_run_time += 1
		GameplayController.Gametypes.TIMED_MATCH:
			game_run_time -= 1

	self.emit_signal("game_run_time_changed", game_run_time)

	if GameplayController.gametype == GameplayController.Gametypes.TIMED_MATCH:
		if(game_run_time == 2 * 60):
			self.emit_signal("two_min_warning")

		if(game_run_time == 60):
			self.emit_signal("one_min_warning")

		if(game_run_time == 30):
			self.emit_signal("thirty_sec_warning")


		if(game_run_time <= 0):
			_game_run_time_timer.stop()
			if(player_one_score > player_two_score):
				self.emit_signal("game_ended")
				self.emit_signal("game_won", 1)
			elif(player_one_score < player_two_score):
				self.emit_signal("game_ended")
				self.emit_signal("game_won", 2)
			else:
				self.emit_signal("overtime_start")
				game_in_overtime = true

func set_bg_opacity(value) -> void:
	bg_opacity = value
	self.emit_signal("bg_opacity_update", value)

func get_bg_opacity() -> float:
	return bg_opacity
