class_name CityBackground
extends ArenaBackground
# An arena background that looks like a city block.
#
# @author ethan_hewlett
# @copyright 2024 Heavy Element


func _ready() -> void:
	$CityBuildingLeft.turn_lights_off()
	$CityBuildingRight.turn_lights_off()

	# DEBUG ONLY.
	# self._game_started()
	# $Seagull/AnimationPlayer.get_animation("fly_into_scene").set_loop(true)
	# $Seagull/AnimationPlayer.play("fly_into_scene")


func get_default_song() -> String:
	return AudioController.CITY_ARENA_MUSIC


func _game_started() -> void:
	$CityBuildingLeft.turn_lights_on()
	$CityBuildingRight.turn_lights_on()

	if Globals.rng.randf() <= Globals.SEAGULL_SPAWN_CHANCE:
		var seagull_timer: SceneTreeTimer = Globals.get_tree().create_timer(Globals.rng.randf_range(Globals.SEAGULL_SPAWN_MIM_DELAY, Globals.SEAGULL_SPAWN_MAX_DELAY), false)
		var _a = seagull_timer.connect("timeout", $Seagull/AnimationPlayer, "play", ["fly_into_scene"])
	else:
		$Seagull.queue_free()


func _goal_scored(scoring_player: int) -> void:
	if scoring_player == 1:
		$CityBuildingLeft.start_flashing_lights(4.0)
	else:
		$CityBuildingRight.start_flashing_lights(4.0)


func _game_over(winning_player: int) -> void:
	$GameWonFireworks.start_launching()
	$CityStadium.start_flashing_lights()

	if winning_player == 1:
		$CityBuildingLeft.start_flashing_lights()
	else:
		$CityBuildingRight.start_flashing_lights()
