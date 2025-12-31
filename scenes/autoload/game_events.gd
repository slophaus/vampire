extends Node

signal experience_vial_collected(number: float)
signal ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int)
signal player_damaged

var player_count := 1
var player_color_indices := [0, 1, 2, 3]

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


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func emit_experience_vial_collected(number: float):
	experience_vial_collected.emit(number)


func emit_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int):
	ability_upgrade_added.emit(upgrade, current_upgrades, player_number)


func emit_player_damaged():
	player_damaged.emit()


func get_player_color(player_number: int) -> Color:
	var player_index = player_number - 1
	if player_index < 0 or player_index >= player_color_indices.size():
		return Color.WHITE
	return PLAYER_COLOR_OPTIONS[player_color_indices[player_index]]


func cycle_player_color(player_number: int) -> void:
	var player_index = player_number - 1
	if player_index < 0 or player_index >= player_color_indices.size():
		return
	var current_index = player_color_indices[player_index]
	player_color_indices[player_index] = (current_index + 1) % PLAYER_COLOR_OPTIONS.size()
