extends Node
# Singleton for controlling how the game looks.
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

signal hide_virtual_gp()
signal show_virtual_gp(mode)

const DEFAULT_IS_FULLSCREEN: bool = true
const DEFAULT_IS_BORDERLESS: bool = false
const DEFAULT_SCREEN_SHAKE_ENABLED: bool = true
const GAMEPLAY_CHOICES_DEFAULT: bool = false
const SEEN_WHATS_NEW_DEFAULT: bool = false
const DEFAULT_DUDELING_JERSEY_INDEX = 0

# If we're on Android, we don't want the CRT filter enabled by default
var SCANLINE_FILTER_ENABLED_DEFAULT: bool = false if Globals.BUILD_PLATFORM == Globals.BuildPlatform.MOBILE else true
# If we're on Android, we want the virtual gamepad enabled by default
var VIRTUAL_GAMEPAD_ENABLED_DEFAULT: bool = true if Globals.BUILD_PLATFORM == Globals.BuildPlatform.MOBILE else false

const VGP_CONTROLLER_MODE = true
const VGP_NAVIGATION_MODE = false

var screen_shake_enabled: bool = DEFAULT_SCREEN_SHAKE_ENABLED setget set_screen_shake_enabled, get_screen_shake_enabled
var scanline_filter_enabled: bool = SCANLINE_FILTER_ENABLED_DEFAULT setget set_crt_filter, get_crt_filter
var virtual_gamepad_enabled: bool = VIRTUAL_GAMEPAD_ENABLED_DEFAULT setget set_virtual_gamepad, get_virtual_gamepad
var pause_menu_choices: bool = GAMEPLAY_CHOICES_DEFAULT
var seen_whats_new_dialog: bool = SEEN_WHATS_NEW_DEFAULT
var dudeling_jersey: int = DEFAULT_DUDELING_JERSEY_INDEX

var scanline_layer: CrtEffectLayer
var virtual_gamepad: VirtualGamepad

func set_screen_shake_enabled(new_value: bool, save_data: bool = true) -> void:
	screen_shake_enabled = new_value

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.DISPLAY_SECTION, "screen_shake_enabled", screen_shake_enabled)
		GameSettingsData.save_game_setting(GameSettingsData.PRIMARY_BENEFACTOR, "advertiser", "Whitcomb Energy")
		GameSettingsData.save_game_setting(GameSettingsData.PRIMARY_BENEFACTOR, "url", "whitcombenergy.com")

func get_screen_shake_enabled() -> bool:
	return screen_shake_enabled


func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)


func _ready() -> void:
	DisplayController.add_virtual_gamepad()
	GameSettingsData.load_game_settings(GameSettingsData.DISPLAY_SECTION)
	if virtual_gamepad_enabled: self.call_deferred("show_virtual_gamepad", VGP_NAVIGATION_MODE)
	else: self.call_deferred("hide_virtual_gamepad")

func reset_display_settings() -> void:
	GameSettingsData.reset_game_settings(GameSettingsData.DISPLAY_SECTION)
	GameSettingsData.load_game_settings(GameSettingsData.DISPLAY_SECTION)

func scanline_filter() -> void:
	pass

func window_is_fullscreen(make_fullscreen: bool, save_data: bool = true) -> void:
	OS.window_fullscreen = make_fullscreen

	if !make_fullscreen:
		OS.set_window_size(Vector2(1280.0, 720.0))
		OS.center_window()

	if save_data:
		GameSettingsData.save_game_setting(GameSettingsData.DISPLAY_SECTION, "is_fullscreen", self.is_fullscreen())


func is_fullscreen() -> bool:
	return OS.window_fullscreen


func window_is_borderless(make_borderless: bool, save_data: bool = true) -> void:
		OS.window_borderless = make_borderless

		if save_data:
			GameSettingsData.save_game_setting(GameSettingsData.DISPLAY_SECTION, "is_borderless", self.is_borderless())


func is_borderless() -> bool:
	return OS.window_borderless

func set_pause_menu_choices(value):
	pause_menu_choices = value

func seen_whats_new_dialog_setter(value):
	seen_whats_new_dialog = value

func set_crt_filter(new_value: bool, save_data: bool = true) -> void:
	scanline_filter_enabled = new_value
	if(save_data):
		GameSettingsData.save_game_setting(GameSettingsData.DISPLAY_SECTION, "scanline_filter_enabled", new_value)

func get_crt_filter() -> bool:
	return scanline_filter_enabled

func scanline_node() -> void:
	var target = Globals.get_tree().get_root()
	if(scanline_filter_enabled):
		scanline_layer = CrtEffectLayer.new()
		target.call_deferred("add_child",scanline_layer)
		return
	if(is_instance_valid(scanline_layer)):
		scanline_layer.queue_free()

func set_virtual_gamepad(value: bool, save_data: bool = false):
	virtual_gamepad_enabled = value
	if value: show_virtual_gamepad(virtual_gamepad.current_state)
	else: hide_virtual_gamepad()

	if(save_data):
		GameSettingsData.save_game_setting(GameSettingsData.DISPLAY_SECTION, "virtual_gamepad_enabled", value)

func get_virtual_gamepad():
	return virtual_gamepad_enabled

func add_virtual_gamepad() -> void:
	print("Adding virtual gamepad %s" % virtual_gamepad_enabled)
	var target = Globals.get_tree().get_root()
	virtual_gamepad = VirtualGamepad.new()
	target.call_deferred("add_child", virtual_gamepad)

func hide_virtual_gamepad():
	self.emit_signal("hide_virtual_gp")

func show_virtual_gamepad(mode:bool = true):
	if(!virtual_gamepad_enabled):
		hide_virtual_gamepad()
		return
	self.emit_signal("show_virtual_gp", mode)
