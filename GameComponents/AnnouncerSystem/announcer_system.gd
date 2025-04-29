class_name AnnouncerSystem
extends Node
# A system that provides real time comments on gameplay. This system should check for--
# and dynamically load--announcers.
#
# Other improvements we need to implement include some kind of excitement state that the
# announcer is in. Where scoring within `n` seconds of another goal increases their
# excitement and more excited samples play as a result
#
# @author ethan_hewlett
# @copyright 2024 Heavy Element

enum AnnouncementType {  # 0 is highest priority.
	INTERRUPT,
	GAME_UNPAUSED,
	GAME_PAUSED,
	PLAYER_ONE_WON,
	PLAYER_TWO_WON,
	PLAYER_ONE_SCORED,
	PLAYER_TWO_SCORED,
	GAME_STARTED,
	TWO_MIN_WARNING,
	ONE_MIN_WARNING,
	THIRTY_SEC_WARNING,
	OVERTIME_START,
}

const EXCITED_GOAL_NUM: int = 5  # Make this greather than the num for goal scoring.

var _voice_clips: Array = []
var _last_used: Array = []
var _current_announcement_type: int = -1
var _inturrupt_announcement_type: int = 0  # 0 == NONE. Positive numbers are excited. Negative numbers are not.
var _audio_player := self._make_audio_player(AudioController.ANNOUNCER_BUS)

func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)
	self._change_voice(AudioController.get_announcer_voice())

	self.set_up_last_used()

	var _a = AudioController.connect("announcer_voice_changed", self, "_change_voice")
	var _b = ArenaController.connect("game_started", self, "_on_game_started")
	var _c = ArenaController.connect("game_paused", self, "_on_game_paused")
	var _d = ArenaController.connect("game_won", self, "_on_game_won")
	var _e = ArenaController.connect("player_scored", self, "_on_goal_scored")
	var _f = ArenaController.connect("two_min_warning", self, "_on_two_min_warning")
	var _g = ArenaController.connect("thirty_sec_warning", self, "_on_thirty_sec_warning")
	var _h = ArenaController.connect("overtime_start", self, "_on_overtime_start")
	var _i = ArenaController.connect("one_min_warning", self, "_on_one_min_warning")

func make_announcement(announcement_type: int, is_excited: bool = false, override_current: bool = false) -> void:
	# Don't play if a more important announcement is playing.
	if !override_current && _current_announcement_type > -1 && _current_announcement_type <= announcement_type:
		return

	# Play inturrupt if something else is already playing.
	# if _current_announcement_type > AnnouncementType.INTERRUPT:
	# 	_current_announcement_type = -1
	# 	_inturrupt_announcement_type = announcement_type * (1 if is_excited else -1)
	# 	self.make_announcement(AnnouncementType.INTERRUPT, is_excited)
	# 	return

	_current_announcement_type = announcement_type

	var voice_line_options: Array = (
		_voice_clips[_current_announcement_type][-1] if is_excited else
		_voice_clips[_current_announcement_type][0]
	)

	var candidate_line:int = self._random_choice(voice_line_options)

	if _last_used[announcement_type][0] == candidate_line:
		candidate_line = self._random_choice(voice_line_options)

	_last_used[announcement_type][0] = candidate_line

	_audio_player.set_stream(voice_line_options[candidate_line])
	_audio_player.play()


func _change_voice(announcer_index: int) -> void:
	_voice_clips = self._load_voice_clips(announcer_index)


func _on_announcement_finished() -> void:
	_current_announcement_type = -1

	if _inturrupt_announcement_type != 0:
		self.make_announcement(int(abs(_inturrupt_announcement_type)), _inturrupt_announcement_type > 0)
		_inturrupt_announcement_type = 0


func _on_game_started() -> void:
	self.make_announcement(AnnouncementType.GAME_STARTED)


func _on_game_paused(is_pausing: bool) -> void:
	if !ArenaController.current_game_state_contains(ArenaController.GameState.IN_GAME):
		return

	var is_excited: bool = ArenaController.get_player_one_score() > EXCITED_GOAL_NUM || ArenaController.get_player_two_score() > EXCITED_GOAL_NUM

	if is_pausing:
		self.make_announcement(AnnouncementType.GAME_PAUSED, is_excited)
	else:
		self.make_announcement(AnnouncementType.GAME_UNPAUSED, is_excited)


func _on_game_won(winning_player: int) -> void:
	if winning_player == 1:
		self.make_announcement(AnnouncementType.PLAYER_ONE_WON, true)
	elif winning_player ==2:
		self.make_announcement(AnnouncementType.PLAYER_TWO_WON, true)


func _on_goal_scored(scoring_player: int) -> void:
	if ArenaController.current_game_state_contains(ArenaController.GameState.GAME_OVER):
		return

	# Keep from adding interrupt to game won announcement.
	if ArenaController.player_score(scoring_player) == GameplayController.get_points_to_win():
		return

	var is_excited: bool = ArenaController.player_score(scoring_player) >= GameplayController.get_points_to_win() - EXCITED_GOAL_NUM

	if scoring_player == 1:
		self.make_announcement(AnnouncementType.PLAYER_ONE_SCORED, is_excited)
	elif scoring_player == 2:
		self.make_announcement(AnnouncementType.PLAYER_TWO_SCORED, is_excited)

func _on_two_min_warning() -> void:
	self.make_announcement(AnnouncementType.TWO_MIN_WARNING, false, true)

func _on_one_min_warning() -> void:
	self.make_announcement(AnnouncementType.ONE_MIN_WARNING, false, true)

func _on_thirty_sec_warning() -> void:
	self.make_announcement(AnnouncementType.THIRTY_SEC_WARNING, false, true)

func _on_overtime_start() -> void:
	self.make_announcement(AnnouncementType.OVERTIME_START, false, true)

func _make_audio_player(bus: String) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	self.add_child(audio_player)
	audio_player.set_bus(bus)
	var _a = audio_player.connect("finished", self, "_on_announcement_finished")
	return audio_player


func _random_choice(options: Array) -> int:
	return Globals.rng.randi_range(0, options.size() - 1)

func set_up_last_used():
	# Build out last_used array
	for num in AnnouncementType:
		_last_used.push_back([-1])


func _load_voice_clips(announcer_index: int) -> Array:
	match announcer_index:
		0: # Gardiner
			return [  # Math indexing to 'AnnouncementType'.
				# INTURRUPT.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/interrupt_6.ogg"),
					],
				],
				# GAME UNPAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_unpaused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_unpaused_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_unpaused_4.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_unpaused_6.ogg"),
					],
				],
				# GAME PAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_paused_2.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_game_paused_2.ogg"),
					],
				],
				# PLAYER ONE WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_victory_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_victory_home_2.ogg"),
					],
				],
				# PLAYER TWO WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_victory_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_victory_away_2.ogg"),
					],
				],
				# PLAYER ONE SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_home_3.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_home_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_home_5.ogg"),
					],
				],
				# PLAYER TWO SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/score_away_3.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_away_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_away_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/excited_score_away_5.ogg"),
					],
				],
				# GAME STARTED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/game_start_6.ogg"),
					],
				],
				# TWO MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/two-min-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/two-min-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/two-min-3.ogg"),
					]
				],
				# ONE MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/one-min-warning-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/one-min-warning-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/one-min-warning-3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/one-min-warning-4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/one-min-warning-5.ogg"),
					]
				],
				# THIRTY SEC WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/thirty-sec-warning-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/thirty-sec-warning-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/thirty-sec-warning-3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/thirty-sec-warning-4.ogg"),
					]
				],
				# OVERTIME ANNOUNCEMENT
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/ot-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/ot-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/ot-3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_GB/ot-4.ogg"),
					]
				]
			]
		1: # Emily
			return [  # Math indexing to 'AnnouncementType'.
				# INTURRUPT.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/interrupt_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/interrupt_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/interrupt_3.ogg"),
					],
				],
				# GAME UNPAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_unpaused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_unpaused_3.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_game_unpaused_2.ogg"),
					],
				],
				# GAME PAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_paused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_paused_3.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_game_paused_2.ogg"),
					],
				],
				# PLAYER ONE WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_6.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_7.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_home_8.ogg"),
					],
				],
				# PLAYER TWO WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_6.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_victory_away_7.ogg"),
					],
				],
				# PLAYER ONE SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_home_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_home_4.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_home_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_home_5.ogg"),
					],
				],
				# PLAYER TWO SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_away_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_away_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/score_away_5.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_away_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_away_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/excited_score_away_5.ogg"),
					],
				],
				# GAME STARTED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_start_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_start_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_start_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_start_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/game_start_5.ogg"),
					],
				],
				# TWO MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/two-min-warning-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/two-min-warning-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/two-min-warning-3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/two-min-warning-4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-two-min-left-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-two-min-left-2.ogg"),
					]
				],
				# ONE MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/one-min-remaining-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/sixty-seconds-remaining-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/sixty-seconds-remaining-2.ogg"),
					]
				],
				# THIRTY SEC WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/thirty-seconds-remaining-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/thirty-seconds-remaining-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-thirty-seconds-left-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-thirty-seconds-left-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-thirty-seconds-left-3.ogg"),
					]
				],
				# OVERTIME ANNOUNCEMENT
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-thirty-seconds-left-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/only-thirty-seconds-left-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/sudden-death-1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_ES/sudden-death-2.ogg"),
					]
				]
			]
		2: # Bill
			return [  # Math indexing to 'AnnouncementType'.
				# INTURRUPT.
				[
					[
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_2.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_5.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_6.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/interrupt/interrupt_7.ogg"),
					],
				],
				# GAME UNPAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_6.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_7.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/game_unpaused_8.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_6.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_7.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_unpaused/excited_game_unpaused_8.ogg"),
					],
				],
				# GAME PAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_5.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_5.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/game_paused_6.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_2.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_paused/excited_game_paused_6.ogg"),
					],
				],
				# PLAYER ONE WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/excited_victory_home_1.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/excited_victory_home_2.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/excited_victory_home_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/excited_victory_home_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/excited_victory_home_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/victory_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/victory_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/victory_home_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/victory_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_home/victory_home_5.ogg"),
					],
				],
				# PLAYER TWO WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_6.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/excited_victory_away_7.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/victory_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/victory_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/victory_away_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/victory_away/victory_away_4.ogg"),
					],
				],
				# PLAYER ONE SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_7.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_6.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/score_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_1.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_2.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_5.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_home/excited_score_home_6.ogg"),
					],
				],
				# PLAYER TWO SCORED.
				[
					[
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/score_away_6.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_4.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_5.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_6.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_7.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/score_away/excited_score_away_8.ogg"),
					],
				],
				# GAME STARTED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_5.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_6.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/game_start/game_start_7.ogg"),
					],
				],
				# TWO MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/two_min_warning/two_min_warning_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/two_min_warning/two_min_warning_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/two_min_warning/two_min_warning_3.ogg"),
						# load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/two_min_warning/two_min_warning_4.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/two_min_warning/two_min_warning_5.ogg"),
					]
				],
				# ONE MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/one_min_warning/one_min_warning_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/one_min_warning/one_min_warning_2.ogg"),

					]
				],
				# THIRTY SEC WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/thirty_second_warning/thirty_second_warning_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/thirty_second_warning/thirty_second_warning_2.ogg"),
					]
				],
				# OVERTIME ANNOUNCEMENT
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/overtime/overtime_1.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/overtime/overtime_2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/overtime/overtime_3.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_BF/overtime/overtime_4.ogg"),
					]
				]
			]
		3: # Rich
			return [  # Math indexing to 'AnnouncementType'.
				# INTURRUPT.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/interrupt/wait.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/interrupt/um.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/interrupt/uh.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/interrupt/oh.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/interrupt/huh.ogg"),
					],
				],
				# GAME UNPAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/unpause/lets-get-back-into-the-game.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/unpause/and-welcome-back.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/unpause/game-on.ogg"),
						load(""),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/unpause/alright-lets-get-back-into-the-game.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/unpause/okay-were-back.ogg"),
					],
				],
				# GAME PAUSED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/paused/it-looks-like-someones-called-a-timeout.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/paused/well-be-right-back.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/paused/well-be-right-back-2.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/pause/were-gonna-take-a-quick-break.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/pause/it-looks-like-theres-a-timeout-on-the-field.ogg"),
					],
				],
				# PLAYER ONE WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-a-hard-fought-victory-for-the-home-team-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-a-hard-fought-victory-for-the-home-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-thats-a-victory-for-the-home-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-thats-game-with-home-team-taking-the-trophy.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-the-home-team-clinches-it.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-with-that-point-home-team-has-won-the-match.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/that-was-an-easy-win-for-the-home-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/the-home-team-has-won-the-match.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/the-home-team-takes-it.ogg"),
					],
				],
				# PLAYER TWO WON.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-a-hard-fought-victory-for-the-away-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-thats-a-victory-for-the-away-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-thats-game-with-away-team-taking-the-trophy.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-the-away-team-clinches-it.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/and-with-that-point-the-away-team-has-won-the-match.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/that-was-an-easy-win-for-the-away-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/the-away-team-has-won-the-match.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/victory/the-away-team-takes-it.ogg"),
					],
				],
				# PLAYER ONE SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-home-team-scores.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-thats-a-point-for-the-home-team-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-thats-a-point-for-the-home-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/home-team-scores.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-another-point-for-the-home-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-the-home-team-scores.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/home-team-earns-another-point.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/home-team-scores-2.ogg"),
					],
				],
				# PLAYER TWO SCORED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-away-team-scores.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-thats-a-point-for-the-away-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/away-team-earns-another-point.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/away-team-scores-2-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/away-team-scores.ogg"),
					],
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-another-point-for-the-away-team.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-thats-a-point-for-the-away-team-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/and-the-away-team-scores.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/score/away-team-scores-2.ogg"),
					],
				],
				# GAME STARTED.
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/start/game-on-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/start/here-we-are-in-dudesville.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/start/in-todays-matchup.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/start/lets-get-right-into-the-actn.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/start/the-ball-is-in-play.ogg"),
					],
				],
				# TWO MIN WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/weve-only-got-two-min-left.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/two-min-warning-1.ogg"),
					]
				],
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/just-sixty-seconds-left-to-go.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/just-sixty-seconds-reminaing.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/one-min-remaining-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/one-min-remaining.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/one-min-remaining.ogg"),
					]
				],
				# THIRTY SEC WARNING
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/weve-only-got-30-seconds-left.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/weve-only-got-30-seconds-left-2.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/thirty-seconds-remaining.ogg"),
					]
				],
				# OVERTIME ANNOUNCEMENT
				[
					[
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/and-this-match-will-end-in-sudden-death.ogg"),
						load("res://Assets/GameComponents/AnnouncerSystem/audio/voice_R/time/looks-like-were-heading-into-overtime.ogg"),
					]
				]
			]
		_:
			return []
