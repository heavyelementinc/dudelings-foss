class_name SplashScreen
extends Node
# This is the intro scene for the game.
#
# @author ethan_hewlett
# @copyright 2024 Heavy Element

const HE_LOGO_VIDEO: VideoStreamTheora = preload("res://Assets/GameScenes/SplashScreen/resources/he_logo_intro.ogv")
const DUDELINGS_LOGO_VIDEO: VideoStreamTheora = preload("res://Assets/GameScenes/SplashScreen/resources/dudelings_logo_intro.ogv")


func _init() -> void:
	print("SplashScreen started initialization")
	SceneController._current_scene = self  # Needed for proper initialization.
	InputController.show_mouse_pointer(false)


func _ready() -> void:
	print("SplashScreen ready")
	var _a = $VideoPlayer.connect("finished", self, "_on_VideoPlayer_finished")

	DisplayController.scanline_node()
	$VideoPlayer.set_stream(HE_LOGO_VIDEO)
	$VideoPlayer.play()


func _process(_delta: float) -> void:
	if SceneController.is_switching_scenes():
		return

	if Input.is_action_just_pressed("ui_accept") || Input.is_action_just_pressed("ui_left_click"):
		Globals.get_tree().set_input_as_handled()

		if(OS.is_debug_build()):
			$VideoPlayer.set_paused(true)
			self._on_VideoPlayer_finished()
			return

		if $VideoPlayer.get_stream() == DUDELINGS_LOGO_VIDEO:
			$VideoPlayer.set_paused(true)
			self._on_VideoPlayer_finished()


func _on_VideoPlayer_finished() -> void:
	match $VideoPlayer.get_stream():
		HE_LOGO_VIDEO:
			$VideoPlayer.set_stream(DUDELINGS_LOGO_VIDEO)
			$VideoPlayer.play()
		DUDELINGS_LOGO_VIDEO:
			AudioController.play_song(AudioController.MAIN_THEME_MUSIC, true)
			SceneController.go_to_scene(SceneController.GameSceneId.MAIN_MENU)
