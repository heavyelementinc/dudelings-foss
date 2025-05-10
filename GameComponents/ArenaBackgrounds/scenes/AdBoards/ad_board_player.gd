class_name AdBoardPlayer
extends Node
# This script allows ad boards to play ads on a timer system.
#
# @author ethan_hewlett
# @copyright 2024 Heavy Element

var _showing_random_ads: bool = true
var _ad_cycle_timer: CycleTimer = self._make_ad_cycle_timer()


func play_home_scores(loop: bool = false) -> void:
	_showing_random_ads = false

	for ad_board in self._get_ad_boards():
		ad_board.change_ad_sheet(ad_board.get_home_team_sheet(), 4)
		ad_board.change_ad(0)

	_ad_cycle_timer.start_cycle(-1.0 if loop else 3.0, 0.75)


func play_away_scores(loop: bool = false) -> void:
	_showing_random_ads = false

	for ad_board in self._get_ad_boards():
		ad_board.change_ad_sheet(ad_board.get_away_team_sheet(), 4)
		ad_board.change_ad(0)

	_ad_cycle_timer.start_cycle(-1.0 if loop else 3.0, 0.75)


func play_random_ads() -> void:
	_showing_random_ads = true

	for ad_board in self._get_ad_boards():
		ad_board.change_ad_sheet(ad_board.get_one_off_ads_sheet(), 15)

	self._change_ads()

	_ad_cycle_timer.start_cycle(-1.0, 10.0)


func _get_ad_boards() -> Array:
	var ad_boards: Array = self.get_children()
	for ad in ad_boards:
		if !ad is AdBoard:
			ad_boards.erase(ad)

	return ad_boards


func _change_ads() -> void:
	if _showing_random_ads:
		var choices: Array = range(self._get_ad_boards()[0].num_ads())  # Note: 'num_ads' should be the same for all ad boards.
		for ad_board in self._get_ad_boards():
			ad_board.change_ad(choices.pop_at(Globals.rng.randi_range(0, choices.size() - 1)))
	else:
		for ad_board in self._get_ad_boards():
			ad_board.change_ad(wrapi(int(ad_board.frame_coords.y) + 1, 0, ad_board.get_vframes()))


func _make_ad_cycle_timer() -> CycleTimer:
	var cycle_timer := CycleTimer.new()
	self.add_child(cycle_timer)
	var _a = cycle_timer.connect("timeout", self, "play_random_ads")
	var _b = cycle_timer.connect("interval_timeout", self, "_change_ads")
	return cycle_timer
