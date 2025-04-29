extends Node
# Handle user inputs with this singleton
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

enum ControllerType {
	KEYBOARD,
	XBOX,
	PLAYSTATION,
}
enum PlayerOptions {
	KEYBOARD,
	CONTROLLER_ONE,
	CONTROLLER_TWO,
	AI_EASY,
	AI_MEDIUM,
	AI_HARD,
	AI_IMPOSSIBLE,
}

const DEFAULT_CONTROLLER_VIBRATION_ENABLED: bool = true

var player_one_control_option: int = PlayerOptions.KEYBOARD setget set_player_one_control_option, get_player_one_control_option
var player_two_control_option: int = PlayerOptions.AI_EASY setget set_player_two_control_option, get_player_two_control_option
var controller_vibration_enabled: bool = DEFAULT_CONTROLLER_VIBRATION_ENABLED setget set_controller_vibration_enabled, get_controller_vibration_enabled

var _player_1_vibrate_cycle_timer: CycleTimer = self._make_vibrate_cycle_timer()
var _player_2_vibrate_cycle_timer: CycleTimer = self._make_vibrate_cycle_timer()


func set_player_one_control_option(new_value: int) -> void:
	player_one_control_option = new_value


func get_player_one_control_option() -> int:
	return player_one_control_option


func set_player_two_control_option(new_value: int) -> void:
	player_two_control_option = new_value


func get_player_two_control_option() -> int:
	return player_two_control_option


func set_controller_vibration_enabled(new_value: bool, save_data: bool = true) -> void:
	controller_vibration_enabled = new_value

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.INPUT_SECTION, "controller_vibration_enabled", controller_vibration_enabled)


func get_controller_vibration_enabled() -> bool:
	return controller_vibration_enabled


func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)


func _ready() -> void:
	GameSettingsData.load_game_settings(GameSettingsData.INPUT_SECTION)


func button_context_bar() -> ButtonContextBar:
	var context_bars: Array = self.get_tree().get_nodes_in_group(Globals.BUTTON_CONTEXT_BAR_GROUP)
	return context_bars[context_bars.size() - 1] as ButtonContextBar


func mouse_is_visible() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE || Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED


func reset_input_settings() -> void:
	GameSettingsData.reset_game_settings(GameSettingsData.INPUT_SECTION)
	GameSettingsData.load_game_settings(GameSettingsData.INPUT_SECTION)


func vibrate_controller(player: int, weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if !controller_vibration_enabled || self.controller_index(player) < 0:
		return

	Input.start_joy_vibration(self.controller_index(player), weak_magnitude, strong_magnitude, duration)


func pulse_controller(player: int, weak_magnitude: float, strong_magnitude: float, vibrate_duration: float, time_between: float, loop_count: int, pause_mode_process: bool) -> void:
	self.vibrate_controller(player, weak_magnitude, strong_magnitude, vibrate_duration)

	if player == 1:
		self._setup_controller_pulse(_player_1_vibrate_cycle_timer, player, weak_magnitude, strong_magnitude, vibrate_duration, time_between, loop_count, pause_mode_process)
	elif player ==2:
		self._setup_controller_pulse(_player_2_vibrate_cycle_timer, player, weak_magnitude, strong_magnitude, vibrate_duration, time_between, loop_count, pause_mode_process)


func _setup_controller_pulse(vibrate_timer: CycleTimer, player: int, weak_magnitude: float, strong_magnitude: float, vibrate_duration: float, time_between: float, loop_count: int, pause_mode_process: bool) -> void:
	if vibrate_timer.is_connected("interval_timeout", self, "vibrate_controller"):
		vibrate_timer.disconnect("interval_timeout", self, "vibrate_controller")

	var _a = vibrate_timer.connect("interval_timeout", self, "vibrate_controller", [player, weak_magnitude, strong_magnitude, vibrate_duration])

	vibrate_timer.set_pause_mode(pause_mode_process)

	var interval_time: float = vibrate_duration + time_between
	vibrate_timer.start_cycle(interval_time * loop_count, interval_time)


func stop_controller_vibration(player: int) -> void:
	if self.controller_index(player) < 0:
		return

	Input.stop_joy_vibration(self.controller_index(player))


func show_mouse_pointer(show_pointer: bool) -> void:
	if !DisplayController.is_fullscreen() || DisplayController.is_borderless():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if show_pointer else Input.MOUSE_MODE_HIDDEN)
		pass
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED if show_pointer else Input.MOUSE_MODE_CAPTURED)


func controller_index(target_player: int) -> int:
	if target_player == 1:
		if player_one_control_option == PlayerOptions.CONTROLLER_ONE:
			return 0
		elif player_one_control_option == PlayerOptions.CONTROLLER_TWO:
			return 1
	elif target_player == 2:
		if player_two_control_option == PlayerOptions.CONTROLLER_ONE:
			return 0
		elif player_two_control_option == PlayerOptions.CONTROLLER_TWO:
			return 1

	# No Controller.
	return -1


func guess_controller_type(device: int) -> int:
	if device < 0 || Input.get_connected_joypads().size() == 0:
		return InputController.ControllerType.KEYBOARD

	var xbox_strings: Array = [
		"xbox",
		"microsoft",
		"xinput gamepad",
	]
	var playstation_strings: Array = [
		"playstation",
		"sony",
		"dualsense",
		"dualshock",
		"ps4",
		"ps5",
	]

	var controller_name: String = SteamWrapper.getFriendlyControllerDeviceName(device).to_lower() # Input.get_joy_name(device).to_lower()
	for each in xbox_strings:
		if controller_name.find(each) != -1:
			return InputController.ControllerType.XBOX
	for each in playstation_strings:
		if controller_name.find(each) != -1:
			return InputController.ControllerType.PLAYSTATION

	return InputController.ControllerType.XBOX  # This is the default if there is an unknown controller.


func _make_vibrate_cycle_timer() -> CycleTimer:
	var cycle_timer := CycleTimer.new()
	self.add_child(cycle_timer)
	return cycle_timer
