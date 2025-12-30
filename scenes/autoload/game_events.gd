extends Node

signal experience_vial_collected(number: float)
signal ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int)
signal player_damaged

var player_count := 1


func emit_experience_vial_collected(number: float):
	experience_vial_collected.emit(number)


func emit_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player_number: int):
	ability_upgrade_added.emit(upgrade, current_upgrades, player_number)


func emit_player_damaged():
	player_damaged.emit()
