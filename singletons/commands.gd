extends Node
# An in-game console handler that needs a lot of attention. This allows for basic command
# execution, but we need to refactor how the game handles inputs before this can be fully
# and properly implemented!
#
# @author gbryant
# @copyright 2025 Heavy Element

const CLI_SCENE:PackedScene = preload("res://GameUI/CommandLine/CommandLine.tscn")

var scene:Node
var command_input: LineEdit
var output_terminal: TextEdit
var enable_cheats: bool = false
var allow_achievements: bool = true
var command_history: Array = [""]
var buffer_pointer: int = 0

func _ready() -> void:
	scene = CLI_SCENE.instance()
	scene.visible = false
	Globals.debug_layer.add_child(scene)
	command_input = scene.find_node("LineEdit")
	var _a = command_input.connect("text_entered", self, "_on_text_entered")
	var _b = command_input.connect("text_changed", self, "_on_text_changed")
	output_terminal = scene.find_node("TextEdit")

func set_buffer_pointer(value):
	var bfr = command_history.size() - 1
	if value >= bfr: value = bfr
	if value <= 0: value = 0
	buffer_pointer = value

func add_to_root() -> void:
	if !Globals.get_tree().get_root().has_node("CommandLineScene"):
		Globals.get_tree().get_root().add_child(scene)

func _input(_event) -> void:
	var visible = scene.visible
	if(Input.is_action_just_pressed("ui_command_prompt")):
		if(!scene): return
		if visible:
			scene.visible = false
		else:
			scene.visible = true
			command_input.call_deferred("grab_focus")
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if visible && _event.get_class() == "InputEventKey":
		if _event.scancode == KEY_UP && _event.pressed == true:
			command_input.text = command_history[buffer_pointer]
			set_buffer_pointer(buffer_pointer - 1)
		if _event.scancode == KEY_DOWN && _event.pressed == true:
			command_input.text = command_history[buffer_pointer]
			set_buffer_pointer(buffer_pointer + 1)
		# Globals.get_tree().set_input_as_handled()
		pass


func close_panel():
	scene.visible = false

func _on_text_entered(text) -> void:
	# Push the command to history
	command_history.push_back(text)
	# Update the pointer to the size of the history
	set_buffer_pointer(command_history.size() - 1)
	# Erase the command from the input
	command_input.text = ""
	# Process the final command
	parse_command(text)
	pass

func _on_text_changed(text) -> void:
	if(scene.visible):
		Globals.get_tree().set_input_as_handled()

func parse_command(text) -> void:
	var operands = text.split(" ") as Array
	var command = "_command_%s" % operands.pop_at(0)
	if self.has_method(command):
		if operands.empty():
			self.call(command)
		else:
			self.call(command, operands)
	else: write("Command not recognized")
	pass

func write(text) -> void:
	output_terminal.text += "\n" + text
	var line_count = output_terminal.get_line_count()
	output_terminal.scroll_vertical = line_count

func _command_help():
	write("  help - Prints this document")
	write("  ai_details - Details on AI players")
	write("  heutils - Toggles cheats")
	if OS.is_debug_build():
		write("  notifications - Fetch notifications");
		write("  ai_debug - Enables AI debugging features")
		write("  achievement - <string> <0 or 1> Grant or remove a Steam achievement")
	if !enable_cheats: return
	write("  set_score - <team> <score> sets the given team's score")
	write("  set_time - <float> sets the game clock to the value provided (value is in minutes)")
	write("  mod_time - <float> adds the value (in minutes) to the game time (use negative numbers to subtract time)")
	write("  add_ball - spawns a game ball")
	return true

func _is_debug():
	return OS.is_debug_build()

func _command_ai_details():
	if(!_is_debug()):
		return
	var ai_players = Globals.get_tree().get_nodes_in_group(Globals.AI_PLAYERS)
	if(ai_players.size() == 0):
		write("There are no players to report on.")
		return
	for ai in ai_players:
		var details: String = "Player #%s\n" % ai._controlling_player
		details += "  Personality: %s\n" % ai._ai_type
		details += "  Difficulty: %s\n" % ai._ai_difficulty
		details += "  Target Goal: %s\n" % ai._opponent_goal_pos
		details += "  Think Tick Rate: %s\n" % ai.DO_STUFF_SPEED[ai._ai_difficulty]
		# details += "  "

		write(details)

	pass

func _command_ai_debug():
	Globals.ai_debug_state = !Globals.ai_debug_state
	write("AI debug state: %s" % Globals.ai_debug_state)

func _command_despawn_balls():
	var balls = self.get_tree().get_nodes_in_group(Globals.ACTIVE_GAME_BALL_GROUP)
	for ball in balls:
		ball._despawn()
	close_panel()

func _command_bg_opacity(value) -> void:
	var val = int(value[0])
	if val < 0: val = 0
	if val > 1: val = 1
	ArenaController.bg_opacity = val
	GameSettingsData.save_game_setting(GameSettingsData.GAME_SETTINGS_FILE_PATH, "arena_bg_opacity", val)

func _command_heutils():
	enable_cheats = !enable_cheats
	write("Utility status: %s" % enable_cheats)
	write("Stats are no longer being tracked. Restart the game to re-enable stats & achievements!")

func _command_set_score(arr):
	if !enable_cheats: return
	var team = int(arr[0])
	var score = int(arr[1])
	if team <= 0 || team > 2:
		write("Invalid team range")
		return
	ArenaController.give_points(team, score)
	close_panel()

# func _command_set_fractional(arr):
#     if !enable_cheats: return
#     var team = int(arr[0])
#     var score = int(arr[1])
#     if team <= 0 || team > 2:
#         write("Invalid team range")
#         return
#     ArenaController

func _command_set_time(arr):
	if !enable_cheats: return
	var time = floor(float(arr[0]) * 60)
	ArenaController.game_run_time = int(time)
	close_panel()

func _command_mod_time(arr):
	var time = float(arr[0]) * 60
	ArenaController.game_run_time += int(time)
	close_panel()

func _command_achievement(arr):
	if(!_is_debug()):
		print("Command not found")
		return
	var achievement_name = arr[0]
	var state = 0
#	if(arr[1] == "1") state = 1

func _command_notifications():
	if(!_is_debug()):
		print("Command not found")
		return
	var http = get_tree().get_nodes_in_group(Globals.HE_NOTIFICATION_GROUP)
	if http.empty():
		print("Cannot execute command: incorrect context (try the Main Menu)")
		return
	http[0]._dispatch_request()
	print("Dispatching request to %s" % http[0].HEAVY_ELEMENT_NEWS_ENDPOINT)

func _command_add_ball() -> void:
	ArenaController.game_ball_spawner().spawn_game_ball()
	pass
