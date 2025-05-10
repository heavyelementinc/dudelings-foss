extends Node2D
# A notification system for the game which reaches out to heavyelement.com for news and updates
#
# @author gbryant
# @copyright 2025 Heavy Element

signal notification_updated()
const HEAVY_ELEMENT_NEWS_ENDPOINT = "https://heavyelement.com/api/v1/game-announcements/"
#const HEAVY_ELEMENT_NEWS_ENDPOINT = "https://next.heavyelement.cloud/api/v1/game-announcements/"
const CONFIRM_MESSAGE_SCENE: PackedScene = preload("res://GameUI/Menus/SubMenus/ConfirmMessage/ConfirmMessageLanding.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	self.add_to_group(Globals.HE_NOTIFICATION_GROUP)
	if !Globals.ident: GameSettingsData.load_game_settings(GameSettingsData.NOTIFICATION)
	var _a = $HTTPRequest.connect("request_completed", self, "_http_request_completed")
	_dispatch_request_if_necessary();

func _dispatch_request() -> void:
	if Globals.telemetry == null:
		var confirm_message: ConfirmMessage = CONFIRM_MESSAGE_SCENE.instance()
		var timer = get_tree().create_timer(0.5)
		yield(timer, "timeout")
		var parent = self.get_parent()
		parent.add_child(confirm_message)
		var _a = confirm_message.connect("confirmed", self, "_telem_confirm", [true])
		var _b = confirm_message.connect("cancled", self, "_telem_confirm", [false])
		confirm_message.cancel_button_label("NO, THANKS")
		confirm_message.confirm_button_label("I'D LIKE TO HELP")

		confirm_message.show_message("IMPROVING DUDELINGS", "We've started collecting anonymous usage stats to help us improve Dudelings, but we wanted your permission first.\n\nNote that you can change this at any time in Settings → Miscellaneous → Submit Usage Statistics.\n\nFor more info, please read our Privacy Policy at [url=https://heavyelement.com/privacy]https://heavyelement.com/privacy[/url]")

		return
	var _b = $HTTPRequest.request(HEAVY_ELEMENT_NEWS_ENDPOINT, ["Content-Type: application/json","X-Client-Ident: %s" % Globals.ident], true, HTTPClient.METHOD_POST, JSON.print(_get_request_body()))

func _telem_confirm(state):
	GameSettingsData.save_game_setting(GameSettingsData.NOTIFICATION, "telemetry", state)
	Globals.telemetry = state
	_dispatch_request()

func _dispatch_request_if_necessary() -> void:
	var now: float = Time.get_unix_time_from_system()
	var delta: float = now - Globals.hE_announce_last
	var min_query_time: int = 60 * 60 * 6; # Six hours in seconds
	if delta > min_query_time: _dispatch_request()

func _http_request_completed(_result, _response_code, headers, body):
	print("hE News Response Code: %s" % _response_code)
	if _response_code != HTTPClient.RESPONSE_OK:
		print("hE News Error: %s" % _result)
		return

	var parsed_headers = process_headers(headers)
	if parsed_headers.has('x-client-ident-set'):
		print("Setting client ident to %s" % parsed_headers['x-client-ident-set'])
		Globals.ident = parsed_headers['x-client-ident-set']
		GameSettingsData.save_game_setting(GameSettingsData.NOTIFICATION, 'ident', parsed_headers['x-client-ident-set']);
		print("hE News Setting Assigned Client Ident: %s" % parsed_headers['x-client-ident-set'])
	Globals.hE_announcements = JSON.parse(body.get_string_from_utf8()).result
	Globals.hE_announce_last = Time.get_unix_time_from_system()
	print("hE News got %s news items at %s" % [Globals.hE_announcements.size(), Globals.hE_announce_last])
	emit_signal("notification_updated")

func _get_request_body() -> Dictionary:
	var titleId = "das"
	if Globals.IS_DEMO: titleId = "das-demo"
	if Globals.telemetry:
		return {
			"title": titleId,
			"platform": SteamWrapper.this_platform,
			"steam_deck": SteamWrapper.is_on_steam_deck,
			"steam_id": SteamWrapper.steam_id,
			"stats": PlayerStats.achievement_progression
		}
	else:
		return {
			"title": titleId,
			"platform": null,
			"steam_deck": null,
			"steam_id": null,
			"stats": []
		}

func process_headers(headers) -> Dictionary:
	var dict: Dictionary = {}
	for i in headers:
		var split = i.rsplit(":", true)
		dict[split[0]] = split[1].trim_prefix(" ").trim_suffix(";")

	return dict
