extends Node
# Singleton that controls transitioning to different scenes.
#
# @author ethan_hewlett
# @copyright 2025 Heavy Element

signal fade_out
signal fade_out_complete()
signal entered_new_scene()

const FADE_TIME: float = 0.3
const WAIT_TIME: float = 1.0
const GAME_SCENES: Array = [  # Match indexing to 'GameSceneId'.
	preload("res://GameScenes/SplashScreen/SplashScreen.tscn"),
	preload("res://GameScenes/MainMenu/MainMenu.tscn"),
	preload("res://GameScenes/SelectionScreen/SelectionScreen.tscn"),
	preload("res://GameScenes/GameArena/GameArena.tscn")
]

enum GameSceneId {
	SPLASH_SCREEN,
	MAIN_MENU,
	GAME_OPTIONS,
	GAME_ARENA,
}

var last_scene_id: int = -1 setget , get_last_scene_id
var current_scene_id: int = GameSceneId.SPLASH_SCREEN setget , get_current_scene_id

var _is_switching_scenes: bool = false
var _current_scene: Node = null
var _fade_layer: SceneSwitchingOverlay = null

var _steam_rich_presence: Dictionary = {
	GameSceneId.SPLASH_SCREEN: "#mainmenu",
	GameSceneId.MAIN_MENU: "#mainmenu",
	GameSceneId.GAME_OPTIONS: "#configuring",
	GameSceneId.GAME_ARENA: "#playing",
}


func get_last_scene_id() -> int:
	return last_scene_id


func get_current_scene_id() -> int:
	return current_scene_id


func _init() -> void:
	print("Initializing SceneController")
	self.set_pause_mode(PAUSE_MODE_PROCESS)


func is_switching_scenes() -> bool:
	return _is_switching_scenes


func go_to_scene(target_scene_id: int) -> void:
	print("Switching to scene: \"%s\"" % target_scene_id)
	last_scene_id = current_scene_id
	current_scene_id = target_scene_id
	_is_switching_scenes = true

	self._fade_in()
#	if(SteamWrapper.initialized == false):
#		SteamWrapper.initialize()
	SteamWrapper.setRichPresence(_steam_rich_presence[current_scene_id])
	self.emit_signal("entered_new_scene")

func _fade_in() -> void:
	if is_instance_valid(_fade_layer):
		return

	_fade_layer = SceneSwitchingOverlay.new()
	var _a = _fade_layer.connect("fade_in_complete", self, "_load_scene")
	var _b = _fade_layer.connect("fade_out_complete", self, "_on_fade_out_complete")
	Globals.get_tree().get_root().add_child(_fade_layer)
	_fade_layer.fade_in(FADE_TIME)


func _load_scene() -> void:
	if is_instance_valid(_current_scene):
		var _a = _current_scene.connect("tree_exited", self, "_load_scene")  # Allow all old nodes to exit the tree. This prevents scene overlap when connecting signals and such on '_ready'.
		_current_scene.queue_free()
		_current_scene = null
		return

	ArenaController.set_game_paused(false)  # This is a catch all.

	_current_scene = GAME_SCENES[current_scene_id].instance()
	Globals.get_tree().get_root().add_child(_current_scene)
	# DisplayController.scanline_node()


func fade_out() -> void:
	_is_switching_scenes = false
	_fade_layer.fade_out(FADE_TIME)
	self.emit_signal("fade_out")


func _on_fade_out_complete() -> void:
	_fade_layer.queue_free()
	_fade_layer = null
	self.emit_signal("fade_out_complete")
