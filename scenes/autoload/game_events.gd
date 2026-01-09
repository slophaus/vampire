extends Node

signal experience_vial_collected(number: float)
signal ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int)
signal player_damaged
signal navigation_debug_toggled(enabled: bool)

var player_count := 1
var player_color_indices := [0, 1, 2, 3]
var persisted_upgrades_by_player: Dictionary = {}
var persisted_upgrade_pools_by_player: Dictionary = {}
var persisted_turn_player_number := 1
var persisted_experience_state: Dictionary = {}
var paused_main_scene: Node = null
var navigation_debug_disabled := false

const PLAYER_COLOR_OPTIONS := [
	Color(1, 0, 0),
	Color(0.3, 0.6, 0.9),
	Color(0, 0.6, 0),
	Color(0.3, 0.3, 0.3),
	Color(1, 1, 0),
	Color(1, 0.5, 0),
	Color(0.6, 0, 0.8),
	Color(0, 1, 1),
	Color(1, 0, 1),
	Color(1, 1, 1),
	Color(0.5, 0.5, 0.5),
	Color(0.6, 0.3, 0.1),
]


func emit_experience_vial_collected(number: float):
	experience_vial_collected.emit(number)


func emit_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int):
	ability_upgrade_added.emit(upgrade, current_upgrades, player_number)


func emit_player_damaged():
	player_damaged.emit()


func toggle_navigation_debug_disabled() -> void:
	navigation_debug_disabled = not navigation_debug_disabled
	navigation_debug_toggled.emit(navigation_debug_disabled)


func get_player_color(player_number: int) -> Color:
	var player_index = player_number - 1
	if player_index < 0 or player_index >= player_color_indices.size():
		return Color.WHITE
	return PLAYER_COLOR_OPTIONS[player_color_indices[player_index]]


func cycle_player_color(player_number: int, direction: int = 1) -> void:
	var player_index = player_number - 1
	if player_index < 0 or player_index >= player_color_indices.size():
		return
	var current_index = player_color_indices[player_index]
	var total_colors = PLAYER_COLOR_OPTIONS.size()
	var step = 1 if direction >= 0 else -1
	var attempts = 0
	var next_index = current_index
	while attempts < total_colors:
		next_index = (next_index + step + total_colors) % total_colors
		if not _is_player_color_taken(next_index, player_index):
			player_color_indices[player_index] = next_index
			return
		attempts += 1


func _is_player_color_taken(color_index: int, current_player_index: int) -> bool:
	for index in range(player_color_indices.size()):
		if index == current_player_index:
			continue
		if player_color_indices[index] == color_index:
			return true
	return false


func store_experience_state(state: Dictionary) -> void:
	persisted_experience_state = state.duplicate(true)


func get_experience_state() -> Dictionary:
	return persisted_experience_state


func store_paused_scene(scene: Node) -> void:
	paused_main_scene = scene


func has_paused_scene() -> bool:
	return paused_main_scene != null


func take_paused_scene() -> Node:
	var stored_scene = paused_main_scene
	paused_main_scene = null
	return stored_scene


func reset_persisted_state() -> void:
	persisted_upgrades_by_player.clear()
	persisted_upgrade_pools_by_player.clear()
	persisted_turn_player_number = 1
	persisted_experience_state.clear()
	paused_main_scene = null
