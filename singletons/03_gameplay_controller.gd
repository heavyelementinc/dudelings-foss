extends Node
# Singleton that controls the gameplay options.
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element

signal dudeling_jersey_index_changed(jersey_index)

const MAX_GAME_BALL_COUNT: int = 10
const MIN_POINTS_TO_WIN: int = 5  # This is for randomizing. SpinBox max is set to 1.
const MAX_POINTS_TO_WIN: int = 20  # This is for randomizing. SpinBox max is set to 99.
const DEFAULT_DUDELING_JERSEY_INDEX: int = 0
const NUM_JERSEYS: int = 3
const DEFAULT_GAME_BALL_TYPE: int = GameBall.GameBallType.BASIC_BALL
const DEFAULT_MIN_GAME_BALLS: int = 1
const DEFAULT_POINTS_TO_WIN: int = 10
const DEFAULT_GAME_BALL_SIZE: int = GameBall.GameBallSize.REGULAR
const DEFAULT_ARENA_PICKUP_SPAWN_RATE: int = AreaPickupSpawningArea.PickupSpawnRate.NORMAL
const DEFAULT_TIME_LIMIT: int = 5 * 60 # Five min
const DEFAULT_TIME_GAME: int = 0

enum Gametypes {
	MATCH_POINT,
	TIMED_MATCH,
}

var dudeling_jersey_index: int = DEFAULT_DUDELING_JERSEY_INDEX setget set_dudeling_jersey_index, get_dudeling_jersey_index
var base_game_ball_type: int = DEFAULT_GAME_BALL_TYPE setget set_base_game_ball_type, get_base_game_ball_type
var min_game_balls: int = DEFAULT_MIN_GAME_BALLS setget set_min_game_balls, get_min_game_balls
var points_to_win: int = DEFAULT_POINTS_TO_WIN setget set_points_to_win, get_points_to_win
var base_game_ball_size: int = DEFAULT_GAME_BALL_SIZE setget set_base_game_ball_size, get_base_game_ball_size
var arena_pickup_spawn_rate: int = DEFAULT_ARENA_PICKUP_SPAWN_RATE setget set_arena_pickup_spawn_rate, get_arena_pickup_spawn_rate
var allowed_pickups: Array = ArenaPickup.PickupType.values() setget , get_allowed_pickups
var gametype: int = DEFAULT_TIME_GAME
var time_limit: int = DEFAULT_TIME_LIMIT

var destination_unlocked: int = false

var rule_defaults: Dictionary = {
	# dudeling_jersey_index = DEFAULT_DUDELING_JERSEY_INDEX,
	base_game_ball_type = DEFAULT_GAME_BALL_TYPE,
	min_game_balls = DEFAULT_MIN_GAME_BALLS,
	points_to_win  = DEFAULT_POINTS_TO_WIN,
	base_game_ball_size = DEFAULT_GAME_BALL_SIZE,
	arena_pickup_spawn_rate = DEFAULT_ARENA_PICKUP_SPAWN_RATE,
	allowed_pickups = ArenaPickup.PickupType.values(),
	gametype = DEFAULT_TIME_GAME,
	time_limit = DEFAULT_TIME_LIMIT,
}

onready var field_rules: Array = [
	rule_defaults, # Classic
	Globals.dictionary_merge(rule_defaults,	{ # Hoop
		base_game_ball_type = GameBall.GameBallType.BOWLING_BALL,
	}),
	Globals.dictionary_merge(rule_defaults, { # Volley
		base_game_ball_type = GameBall.GameBallType.BEACH_BALL,
		gametype = Gametypes.TIMED_MATCH,
		time_limit = 3 * 60, # 3 min time limit
	}),
	Globals.dictionary_merge(rule_defaults, { # Pins
		base_game_ball_type = GameBall.GameBallType.BEACH_BALL,
		points_to_win = 5,
		arena_pickup_spawn_rate = AreaPickupSpawningArea.PickupSpawnRate.NONE,
	})
]

func set_dudeling_jersey_index(new_value: int) -> void:
	dudeling_jersey_index = new_value
	self.emit_signal("dudeling_jersey_index_changed", dudeling_jersey_index)


func get_dudeling_jersey_index() -> int:
	return dudeling_jersey_index


func set_base_game_ball_type(new_value: int) -> void:
	base_game_ball_type = int(clamp(new_value, 0, GameBall.GameBallType.size() - 1))


func get_base_game_ball_type() -> int:
	return base_game_ball_type


func set_min_game_balls(new_value: int) -> void:
	min_game_balls = int(clamp(new_value, 1, MAX_GAME_BALL_COUNT))


func get_min_game_balls() -> int:
	return min_game_balls


func set_points_to_win(new_value: int) -> void:
	points_to_win = int(clamp(new_value, 1, 100))


func get_points_to_win() -> int:
	return points_to_win


func set_base_game_ball_size(new_value: int) -> void:
	base_game_ball_size = int(clamp(new_value, 0, GameBall.GameBallSize.size() - 1))


func get_base_game_ball_size() -> int:
	return base_game_ball_size


func set_arena_pickup_spawn_rate(new_value: int) -> void:
	arena_pickup_spawn_rate = int(clamp(new_value, 0, AreaPickupSpawningArea.PickupSpawnRate.size() - 1))


func get_arena_pickup_spawn_rate() -> int:
	return arena_pickup_spawn_rate


func get_allowed_pickups() -> Array:
	return allowed_pickups


func _init() -> void:
	self.set_pause_mode(PAUSE_MODE_PROCESS)

func _ready():
	var _a = ArenaController.connect("game_field_changed", self, "_on_game_field_changed")
	pass

func _on_game_field_changed(old_index, new_index) -> void:
	if(old_index == new_index): return
	var rules = field_rules[new_index];
	for rule in rules:
		var value = rules[rule]
		self[rule] = value

func add_allowed_pickup(new_pickup: int) -> void:
	if allowed_pickups.size() < 2 && new_pickup == ArenaPickup.PickupType.MYSTERY:
		return

	allowed_pickups.append(new_pickup)


func remove_allowed_pickup(target_pickup: int) -> void:
	allowed_pickups.erase(target_pickup)

	if allowed_pickups.size() < 3 && self.allowed_pickups_contains(ArenaPickup.PickupType.MYSTERY):
		self.remove_allowed_pickup(ArenaPickup.PickupType.MYSTERY)


func change_allowed_pickup(pickup: int, is_allowed: bool) -> void:
	if is_allowed:
		self.add_allowed_pickup(pickup)
	else:
		self.remove_allowed_pickup(pickup)


func allowed_pickups_contains(target_pickup: int) -> bool:
	return false if allowed_pickups.find(target_pickup) == -1 else true


func randomize_gameplay_options() -> void:
	# self.set_dudeling_jersey_index(Globals.rng.randi_range(0, NUM_JERSEYS - 1))
	self.set_base_game_ball_type(Globals.rng.randi_range(0, GameBall.GameBallType.size() - 1))
	self.set_min_game_balls(Globals.rng.randi_range(0, MAX_GAME_BALL_COUNT))
	self.set_points_to_win(Globals.rng.randi_range(MIN_POINTS_TO_WIN, MAX_POINTS_TO_WIN))
	self.set_base_game_ball_size(Globals.rng.randi_range(0, GameBall.GameBallSize.size() - 1))
	self.set_arena_pickup_spawn_rate(Globals.rng.randi_range(0, AreaPickupSpawningArea.PickupSpawnRate.size() - 1))
	allowed_pickups = ArenaPickup.PickupType.values()
	gametype = Globals.rng.randi_range(Gametypes.MATCH_POINT, Gametypes.TIMED_MATCH)
	time_limit = Globals.rng.randi_range(1, 10)
	for option in ArenaPickup.PickupType.values():
		if Globals.rng.randf() <= 0.5:
			self.remove_allowed_pickup(option)


func reset_gameplay_options() -> void:
	var rules = field_rules[ArenaController.current_game_field_index]
	# self.set_dudeling_jersey_index(DEFAULT_DUDELING_JERSEY_INDEX)
	self.set_base_game_ball_type(rules.base_game_ball_type)
	self.set_min_game_balls(rules.min_game_balls)
	self.set_points_to_win(rules.points_to_win)
	self.set_base_game_ball_size(rules.base_game_ball_size)
	self.set_arena_pickup_spawn_rate(rules.arena_pickup_spawn_rate)
	allowed_pickups = rules.allowed_pickups
	gametype = rules.gametype
	time_limit = rules.time_limit
