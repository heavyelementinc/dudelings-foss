class_name ActivePickupIndicator
extends HBoxContainer
# A HUD element that shows what pickups are currently active for the target player.
#
# @author ethan_hewlett
# @copyright 2023 Heavy Element
const MIN_PICKUP_DISPLAY_TIME: float = 3.0

export(int, 0, 2) var target_player: int = 0 setget set_target_player, get_target_player


func set_target_player(new_value: int) -> void:
	target_player = new_value

	if target_player == 2:
		self.set_alignment(ALIGN_END)
		self.set_h_grow_direction(Control.GROW_DIRECTION_BEGIN)


func get_target_player() -> int:
	return target_player


func _init() -> void:
	self.add_constant_override('separation', 5)
	var _a = ArenaController.arena_pickup_spawner().connect("pickup_spawned", self, "_on_pickup_spawned")


func _on_pickup_spawned(arena_pickup: ArenaPickup) -> void:
	var display_time: float = (
		arena_pickup.effect_time() if arena_pickup.effect_time() > MIN_PICKUP_DISPLAY_TIME else
		MIN_PICKUP_DISPLAY_TIME
	)
	var _a = arena_pickup.connect("pickup_activated", self, "_add_pickup_to_queue", [display_time])


func _add_pickup_to_queue(pickup_type: int, player: int, display_time: float) -> void:
	if target_player != player:
		return

	if pickup_type == ArenaPickup.PickupType.MYSTERY:
		return

	var pickup_icon := TextureRect.new()
	pickup_icon.set_texture(AreaPickupSpawningArea.PICKUP_ICONS[pickup_type])

	self.add_child(pickup_icon)

	var timer: SceneTreeTimer = Globals.get_tree().create_timer(display_time, false)
	var _a = timer.connect("timeout", pickup_icon, "queue_free")
