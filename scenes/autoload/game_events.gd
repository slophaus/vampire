extends Node

signal experience_vial_collected(number: float)
signal ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player: Node)
signal upgrade_turn_changed(player_number: int)
signal player_damaged


func emit_experience_vial_collected(number: float):
	experience_vial_collected.emit(number)


func emit_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, player: Node):
	ability_upgrade_added.emit(upgrade, current_upgrades, player)


func emit_upgrade_turn_changed(player_number: int):
	upgrade_turn_changed.emit(player_number)


func emit_player_damaged():
	player_damaged.emit()
