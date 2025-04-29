extends Node
# Singleton that controls all game audio.
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

signal announcer_voice_changed(new_voice_index)
signal stop_music()

enum AudioBus {MASTER, MUSIC, UI, SOUND, ANNOUNCER}

const BUS_LAYOUT: AudioBusLayout = preload("res://audio_bus_layout.tres")
const MUSIC_BUS: String = "Music"
const UI_BUS: String = "UI"
const SOUND_BUS: String = "Sound"
const ANNOUNCER_BUS: String = "Announcer"
const MIN_VOLUME_DB: float = -25.0
const MAX_VOLUME_DB: float = 0.0

# Not all volume values should default to 100%.
const DEFAULT_MASTER_VOLUME_DB: float = MAX_VOLUME_DB
const DEFAULT_MUSIC_VOLUME_DB: float = MIN_VOLUME_DB * (1.0 - 0.8)
const DEFAULT_UI_VOLUME_DB: float = MIN_VOLUME_DB * (1.0 - 0.7)
const DEFAULT_SOUND_VOLUME_DB: float = MAX_VOLUME_DB
const DEFAULT_ANNOUNCER_VOLUME_DB: float = MAX_VOLUME_DB
const DEFAULT_ANNOUNCER_VOICE: int = 2 # Default to Bill because his voice performance is better than Gardiner's
const PITCH_SHIFT_INDEX: int = 0;
const PITCH_SHIFT_FREQUENT: Array = [0.85, 1.15]
const PITCH_SHIFT_MEDIUM: Array = [0.9, 1.1]
const PITCH_SHIFT_INFREQUENT: Array = [0.95, 1.05]
const PITCH_SHIFT_TONAL: Array = [0.98, 1.08]

const MAIN_THEME_MUSIC: String = "res://Assets/GameMusic/main_theme.ogg"
const BEACH_ARENA_MUSIC: String = "res://Assets/GameMusic/beach_day.ogg"
const CITY_ARENA_MUSIC: String = "res://Assets/GameMusic/city_streets.ogg"
const STADIUM_ARENA_MUSIC: String = "res://Assets/GameMusic/stadium.ogg"
const INFIELD_MUSIC: String = "res://Assets/GameMusic/infield.ogg"
const DESTINATION_MUSIC: String = "res://Assets/GameMusic/destination.ogg"
const GYM_ARENA_MUSIC: String = "res://Assets/GameMusic/workout_montage.ogg"
# const PAUSE_MENU_MUSIC: String = "res://Assets/GameMusic/takin_a_break.ogg"
const RESULTS_SCREEN_MUSIC: String = "res://Assets/GameMusic/racing_heart.ogg"
const YOU_LOST_MUSIC: String = "res://Assets/GameMusic/you_lost.ogg"
const YOU_WON_MUSIC: String = "res://Assets/GameMusic/you_won.ogg"

var master_volume_db: float = DEFAULT_MASTER_VOLUME_DB setget set_master_volume_db, get_master_volume_db
var music_volume_db: float = DEFAULT_MUSIC_VOLUME_DB setget set_music_volume_db, get_music_volume_db
var ui_volume_db: float = DEFAULT_UI_VOLUME_DB setget set_ui_volume_db, get_ui_volume_db
var sound_volume_db: float = DEFAULT_SOUND_VOLUME_DB setget set_sound_volume_db, get_sound_volume_db
var announcer_volume_db: float = DEFAULT_ANNOUNCER_VOLUME_DB setget set_announcer_volume_db, get_announcer_volume_db
var announcer_voice: int = DEFAULT_ANNOUNCER_VOICE setget set_announcer_voice, get_announcer_voice

var _game_music_options: Array = self._looping_music_options()
var _music_player := self._make_audio_player(MUSIC_BUS)
var _ui_sound_player := self._make_audio_player(UI_BUS)
var _player_one_sound_player := self._make_audio_player(SOUND_BUS)
var _player_two_sound_player := self._make_audio_player(SOUND_BUS)
var _universal_sound_player := self._make_audio_player(SOUND_BUS)

onready var announcer_system := self._make_announcer_system() setget , get_announcer_system

var loop_current_song:bool = false
var current_song_to_loop := MAIN_THEME_MUSIC

var currently_playing_song: AudioStreamOGGVorbis

static func db_to_percent(db: float) -> float:
	return 1.0 - (db / MIN_VOLUME_DB)


static func percent_to_db(percent: float) -> float:
	return MIN_VOLUME_DB * (1.0 - percent)


func set_master_volume_db(new_value: float, save_data: bool = true) -> void:
	master_volume_db = clamp(new_value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	self._update_audio_server_volume(AudioBus.MASTER, master_volume_db)

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "master_volume_db", master_volume_db)


func get_master_volume_db() -> float:
	return master_volume_db


func set_music_volume_db(new_value: float, save_data: bool = true) -> void:
	music_volume_db = clamp(new_value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	self._update_audio_server_volume(AudioBus.MUSIC, music_volume_db)

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "music_volume_db", music_volume_db)


func get_music_volume_db() -> float:
	return music_volume_db


func set_ui_volume_db(new_value: float, save_data: bool = true) -> void:
	ui_volume_db = clamp(new_value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	self._update_audio_server_volume(AudioBus.UI, ui_volume_db)

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "ui_volume_db", ui_volume_db)


func get_ui_volume_db() -> float:
	return ui_volume_db


func set_sound_volume_db(new_value: float, save_data: bool = true) -> void:
	sound_volume_db = clamp(new_value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	self._update_audio_server_volume(AudioBus.SOUND, sound_volume_db)

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "sound_volume_db", sound_volume_db)


func get_sound_volume_db() -> float:
	return sound_volume_db


func set_announcer_volume_db(new_value: float, save_data: bool = true) -> void:
	announcer_volume_db = clamp(new_value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	self._update_audio_server_volume(AudioBus.ANNOUNCER, announcer_volume_db)

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "announcer_volume_db", announcer_volume_db)


func get_announcer_volume_db() -> float:
	return announcer_volume_db


func set_announcer_voice(new_value: int, save_data: bool = true) -> void:
	announcer_voice = new_value

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.AUDIO_SECTION, "announcer_voice", announcer_voice)

	self.emit_signal("announcer_voice_changed", announcer_voice)


func get_announcer_voice() -> int:
	return announcer_voice


func get_announcer_system() -> AnnouncerSystem:
	return announcer_system


func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)
	AudioServer.set_bus_layout(BUS_LAYOUT)


func _ready() -> void:
	GameSettingsData.load_game_settings(GameSettingsData.AUDIO_SECTION)


func reset_audio_settings() -> void:
	GameSettingsData.reset_game_settings(GameSettingsData.AUDIO_SECTION)
	GameSettingsData.load_game_settings(GameSettingsData.AUDIO_SECTION)


func play_song(target_song: String, loop: bool = true) -> void:
	var new_song = load_music(target_song)

	if !is_instance_valid(new_song): # Is this necessary? Might be vestigial now that we're loading in real time
		return

	# Make the song loop
	new_song.set_loop(loop)
	self._play_audio(new_song, _music_player)
	currently_playing_song = new_song

func load_music(target_song: String) -> AudioStreamOGGVorbis:
	# If the target song doesn't exist, then we should just return
	if ResourceLoader.exists(target_song) == false:
		target_song = MAIN_THEME_MUSIC

	# Let's load our song
	var new_song: AudioStreamOGGVorbis = load(target_song)
	return new_song

func play_music(target_song: String, loop: bool = false) -> void:
	var new_song: AudioStreamOGGVorbis = load_music(target_song)
	# Enumerate _game_music_options
	_game_music_options = self._looping_music_options()

	# Check if target_song is an invalid music track
	if !is_instance_valid(new_song):
		# If it's invalid, play a random song
		self._play_random_music_track()
		return

	# Connect to the music player and listen for a "finished" signal
	if loop && !_music_player.is_connected("finished", self, "_play_audio"):
		var _a = _music_player.connect("finished", self, "_play_audio", [new_song, _music_player])

	# Remove the target song from the valid game_music_options
	_game_music_options.erase(new_song)
	# Play the song
	self._play_audio(new_song, _music_player)  # This will trigger '_loop_music' when finished.


func stop_music() -> void:
	if _music_player.is_connected("finished", self, "_loop_music"):
		_music_player.disconnect("finished", self, "_loop_music")

	_music_player.stop()


func play_ui_sound(target_sound: AudioStreamOGGVorbis) -> void:
	if !is_instance_valid(target_sound):
		return

	self._play_audio(target_sound, _ui_sound_player)


func play_player_one_sound(target_sound: AudioStreamOGGVorbis, variation = [1.0]) -> void:
	if !is_instance_valid(target_sound):
		return

	self._play_audio(target_sound, _player_one_sound_player, variation)


func play_player_two_sound(target_sound: AudioStreamOGGVorbis, variation = [1.0]) -> void:
	if !is_instance_valid(target_sound):
		return

	self._play_audio(target_sound, _player_two_sound_player, variation)


func play_universal_sound(target_sound: AudioStreamOGGVorbis, variation = [1.0]) -> void:
	if !is_instance_valid(target_sound):
		return

	self._play_audio(target_sound, _universal_sound_player, variation)


func play_game_sound(sound: AudioStreamOGGVorbis, player: int, variation: Array = [1.0]) -> void:
	if player == 1:
		self.play_player_one_sound(sound, variation)
	elif player == 2:
		self.play_player_two_sound(sound, variation)
	else:
		self.play_universal_sound(sound, variation)


func _play_audio(audio_stream: AudioStreamOGGVorbis, audio_player: AudioStreamPlayer, variation: Array = [1.0]) -> void:
	if !is_instance_valid(audio_stream) || !is_instance_valid(audio_player):
		return

	audio_player.set_stream(audio_stream)
	var minimum: float = variation.min()
	var maximum: float = variation.max()
	audio_player.pitch_scale = Globals.rng.randf_range(minimum, maximum)
	audio_player.play()


func _play_random_music_track() -> void:
	var new_song: AudioStreamOGGVorbis = _game_music_options.pop_at(Globals.rng.randi_range(0, _game_music_options.size() - 1))

	self._play_audio(new_song, _music_player)

	if _game_music_options.empty():
		_game_music_options = self._looping_music_options()

func _loop_music(track_to_loop) -> void:
	pass

func _looping_music_options() -> Array:
	return [
		MAIN_THEME_MUSIC,
		BEACH_ARENA_MUSIC,
		CITY_ARENA_MUSIC,
		STADIUM_ARENA_MUSIC,
		INFIELD_MUSIC,
		GYM_ARENA_MUSIC,
		DESTINATION_MUSIC,
		# PAUSE_MENU_MUSIC,
	]


func _update_audio_server_volume(bus_index: int, new_volume_db: float) -> void:
	AudioServer.set_bus_volume_db(bus_index, new_volume_db)
	AudioServer.set_bus_mute(bus_index, new_volume_db <= MIN_VOLUME_DB)


func _make_audio_player(bus: String) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	self.add_child(audio_player)
	audio_player.set_bus(bus)
	return audio_player


func _make_announcer_system() -> AnnouncerSystem:
	var announcer := AnnouncerSystem.new()
	self.add_child(announcer)
	return announcer
