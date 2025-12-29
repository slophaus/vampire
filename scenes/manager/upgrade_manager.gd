extends Node

@export var experience_manager: ExperienceManager
@export var upgrade_screen_scene: PackedScene

var current_turn_player_number := 1
var current_upgrades_by_player: Dictionary = {}
var upgrade_pools_by_player: Dictionary = {}
var players_by_number: Dictionary = {}

var upgrade_boomerang := preload("res://resources/upgrades/boomerang.tres")
var upgrade_axe := preload("res://resources/upgrades/axe.tres")
var upgrade_axe_damage := preload("res://resources/upgrades/axe_damage.tres")
var upgrade_axe_level := preload("res://resources/upgrades/axe_level.tres")
var upgrade_fireball := preload("res://resources/upgrades/fireball.tres")
var upgrade_sword_rate := preload("res://resources/upgrades/sword_rate.tres")
var upgrade_sword_damage := preload("res://resources/upgrades/sword_damage.tres")
var upgrade_sword_level := preload("res://resources/upgrades/sword_level.tres")
var upgrade_fireball_level := preload("res://resources/upgrades/fireball_level.tres")
var upgrade_player_speed := preload("res://resources/upgrades/player_speed.tres")

var rng := RandomNumberGenerator.new()


func _ready():
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("get_player_action_suffix"):
			players_by_number[player.player_number] = player

	for player_number in players_by_number.keys():
		current_upgrades_by_player[player_number] = {}
		upgrade_pools_by_player[player_number] = create_upgrade_pool()

	experience_manager.level_up.connect(on_level_up)


func create_upgrade_pool() -> WeightedTable:
	var upgrade_pool: WeightedTable = WeightedTable.new()
	# axe damage는 axe 얻을 때 풀에 추가
	upgrade_pool.add_item(upgrade_axe, 10)
	upgrade_pool.add_item(upgrade_boomerang, 10)
	upgrade_pool.add_item(upgrade_fireball, 10)
	upgrade_pool.add_item(upgrade_sword_rate, 10)
	upgrade_pool.add_item(upgrade_sword_damage, 10)
	upgrade_pool.add_item(upgrade_sword_level, 10)
	upgrade_pool.add_item(upgrade_player_speed, 5)
	return upgrade_pool


func apply_upgrade(upgrade: AbilityUpgrade, player_number: int):
	var current_upgrades = current_upgrades_by_player[player_number]
	var upgrade_pool = upgrade_pools_by_player[player_number]
	var has_upgrade = current_upgrades.has(upgrade.id)
	if not has_upgrade:
		current_upgrades[upgrade.id] = {
			"resource": upgrade,
			"quantity": 1,
		}
	else:
		current_upgrades[upgrade.id]["quantity"] += 1
	
	# quantity check -> pool 에서 빼버림
	if upgrade.max_quantity > 0:
		var current_quantity = current_upgrades[upgrade.id]["quantity"]
		if current_quantity >= upgrade.max_quantity:
			upgrade_pool.remove_item(upgrade)

	update_upgrade_pool(upgrade, upgrade_pool)
	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades, player_number)


func update_upgrade_pool(chosen_upgrade: AbilityUpgrade, upgrade_pool: WeightedTable):
	if chosen_upgrade.id == upgrade_axe.id:
		upgrade_pool.add_item(upgrade_axe_damage, 10)
		upgrade_pool.add_item(upgrade_axe_level, 10)
	if chosen_upgrade.id == upgrade_fireball.id:
		upgrade_pool.add_item(upgrade_fireball_level, 10)


func pick_upgrades(player_number: int) -> Array[AbilityUpgrade]:
	var upgrade_pool = upgrade_pools_by_player[player_number]
	var chosen_upgrades: Array[AbilityUpgrade] = []
	for i in 2:
		if upgrade_pool.items.size() == chosen_upgrades.size():  # no more viable upgrade
			break

		var upgr = upgrade_pool.pick_item(chosen_upgrades)
		chosen_upgrades.append(upgr)

	return chosen_upgrades


## Get random upgrades from pool (up to 2), without duplicates
#func pick_upgrades() -> Array[AbilityUpgrade]:
	##assert(upgrade_pool.size() >= 2, "upgrade pool size should >= 2")
	#var picked := {}  # <index, null>
	#var next_idx: int
	#var max_pick_size: int = min(upgrade_pool.size(), 2)
	#if max_pick_size == 0:
		#return []
#
	#while true:
		#next_idx = rng.randi_range(0, upgrade_pool.size() - 1)
		#if picked.has(next_idx):
			#continue
		#
		#picked[next_idx] = null
		#
		#if picked.size() >= max_pick_size:
			#break
	#
	## https://github.com/godotengine/godot/issues/72566
	#var ret: Array[AbilityUpgrade]
	#ret.assign(picked.keys().map(func(i): return upgrade_pool[i]))
	#return ret


func on_level_up(current_level: int):
	var upgrade_player_number = get_upgrade_player_number()
	if upgrade_player_number == 0:
		return
	var upgrade_screen_instance = upgrade_screen_scene.instantiate()
	add_child(upgrade_screen_instance)
	upgrade_screen_instance.set_controlling_player(upgrade_player_number)
	var chosen_upgrades = pick_upgrades(upgrade_player_number)
	upgrade_screen_instance.set_ability_upgrades(chosen_upgrades, current_upgrades_by_player[upgrade_player_number])
	upgrade_screen_instance.upgrade_selected.connect(on_upgrade_selected.bind(upgrade_player_number))
	current_turn_player_number = get_next_player_number(current_turn_player_number)


func get_next_player_number(player_number: int) -> int:
	if players_by_number.size() < 2:
		return player_number
	var other_player_number = player_number
	for candidate in players_by_number.keys():
		if candidate != player_number:
			other_player_number = candidate
			break
	return other_player_number


func get_upgrade_player_number() -> int:
	if players_by_number.is_empty():
		return 0
	var current_player = players_by_number.get(current_turn_player_number, null)
	var other_player_number = get_next_player_number(current_turn_player_number)
	if current_player == null:
		return current_turn_player_number
	if current_player.is_regenerating:
		var other_player = players_by_number.get(other_player_number, null)
		if other_player != null:
			return other_player_number
	return current_turn_player_number


func on_upgrade_selected(upgrade: AbilityUpgrade, player_number: int):
	apply_upgrade(upgrade, player_number)
