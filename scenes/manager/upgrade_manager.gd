extends Node

@export var experience_manager: ExperienceManager
@export var upgrade_screen_scene: PackedScene
@export var upgrade_option_count := 4

var current_turn_player_number := 1
var current_upgrades_by_player: Dictionary = {}
var upgrade_pools_by_player: Dictionary = {}
var players_by_number: Dictionary = {}

var upgrade_boomerang := preload("res://resources/upgrades/boomerang.tres")
var upgrade_boomerang_level := preload("res://resources/upgrades/boomerang_level.tres")
var upgrade_axe := preload("res://resources/upgrades/axe.tres")
var upgrade_axe_damage := preload("res://resources/upgrades/axe_damage.tres")
var upgrade_axe_level := preload("res://resources/upgrades/axe_level.tres")
var upgrade_fireball := preload("res://resources/upgrades/fireball.tres")
var upgrade_sword_rate := preload("res://resources/upgrades/sword_rate.tres")
var upgrade_sword_damage := preload("res://resources/upgrades/sword_damage.tres")
var upgrade_sword_level := preload("res://resources/upgrades/sword_level.tres")
var upgrade_fireball_level := preload("res://resources/upgrades/fireball_level.tres")
var upgrade_player_speed := preload("res://resources/upgrades/player_speed.tres")
var upgrade_player_health := preload("res://resources/upgrades/health.tres")
var upgrade_dig := preload("res://resources/upgrades/dig.tres")
var upgrade_dig_level := preload("res://resources/upgrades/dig_level.tres")

var rng := RandomNumberGenerator.new()


func _ready():
	current_turn_player_number = GameEvents.persisted_turn_player_number
	refresh_players()
	call_deferred("refresh_players")
	call_deferred("_reapply_current_upgrades")

	experience_manager.level_up.connect(on_level_up)


func restore_persisted_state() -> void:
	current_turn_player_number = GameEvents.persisted_turn_player_number
	for player_number in GameEvents.persisted_upgrades_by_player.keys():
		current_upgrades_by_player[player_number] = GameEvents.persisted_upgrades_by_player[player_number].duplicate(true)
	for player_number in GameEvents.persisted_upgrade_pools_by_player.keys():
		upgrade_pools_by_player[player_number] = GameEvents.persisted_upgrade_pools_by_player[player_number]
	_reapply_current_upgrades()


func create_upgrade_pool() -> WeightedTable:
	var upgrade_pool: WeightedTable = WeightedTable.new()
	# axe damage는 axe 얻을 때 풀에 추가
	upgrade_pool.add_item(upgrade_axe, 10)
	upgrade_pool.add_item(upgrade_boomerang, 10)
	upgrade_pool.add_item(upgrade_fireball, 10)
	upgrade_pool.add_item(upgrade_sword_rate, 10)
	upgrade_pool.add_item(upgrade_sword_damage, 10)
	upgrade_pool.add_item(upgrade_sword_level, 10)
	upgrade_pool.add_item(upgrade_dig, 8)
	upgrade_pool.add_item(upgrade_player_speed, 5)
	upgrade_pool.add_item(upgrade_player_health, 5)
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
	_store_persistent_state(player_number)
	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades, player_number)


func update_upgrade_pool(chosen_upgrade: AbilityUpgrade, upgrade_pool: WeightedTable):
	if chosen_upgrade.id == upgrade_boomerang.id:
		upgrade_pool.add_item(upgrade_boomerang_level, 10)
	if chosen_upgrade.id == upgrade_axe.id:
		upgrade_pool.add_item(upgrade_axe_damage, 10)
		upgrade_pool.add_item(upgrade_axe_level, 10)
	if chosen_upgrade.id == upgrade_fireball.id:
		upgrade_pool.add_item(upgrade_fireball_level, 10)
	if chosen_upgrade.id == upgrade_dig.id:
		upgrade_pool.add_item(upgrade_dig_level, 10)


func pick_upgrades(player_number: int) -> Array[AbilityUpgrade]:
	var upgrade_pool = upgrade_pools_by_player[player_number]
	var chosen_upgrades: Array[AbilityUpgrade] = []
	for i in upgrade_option_count:
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
	refresh_players()
	var upgrade_player_number = get_upgrade_player_number()
	if upgrade_player_number == 0:
		return
	var upgrade_screen_instance = upgrade_screen_scene.instantiate()
	add_child(upgrade_screen_instance)
	upgrade_screen_instance.set_controlling_player(upgrade_player_number)
	var chosen_upgrades = pick_upgrades(upgrade_player_number)
	upgrade_screen_instance.set_ability_upgrades(chosen_upgrades, current_upgrades_by_player[upgrade_player_number])
	upgrade_screen_instance.upgrade_selected.connect(on_upgrade_selected.bind(upgrade_player_number))
	current_turn_player_number = get_next_player_number(upgrade_player_number)


func get_next_player_number(player_number: int) -> int:
	var player_numbers = get_player_numbers()
	if player_numbers.is_empty():
		return player_number
	if player_numbers.size() == 1:
		return player_numbers[0]
	var current_index = player_numbers.find(player_number)
	if current_index == -1:
		return player_numbers[0]
	return player_numbers[(current_index + 1) % player_numbers.size()]


func get_upgrade_player_number() -> int:
	var player_numbers = get_player_numbers()
	if player_numbers.is_empty():
		return 0
	var start_index = player_numbers.find(current_turn_player_number)
	if start_index == -1:
		start_index = 0
	for offset in player_numbers.size():
		var candidate_number = player_numbers[(start_index + offset) % player_numbers.size()]
		var candidate_player = players_by_number.get(candidate_number, null)
		if candidate_player != null and not candidate_player.is_regenerating:
			return candidate_number
	return player_numbers[start_index]


func on_upgrade_selected(upgrade: AbilityUpgrade, player_number: int):
	apply_upgrade(upgrade, player_number)


func get_player_numbers() -> Array:
	var player_numbers = players_by_number.keys()
	player_numbers.sort()
	return player_numbers


func refresh_players() -> void:
	var scene_tree = get_tree()
	if scene_tree == null:
		return
	for player in scene_tree.get_nodes_in_group("player"):
		if not player.has_method("get_player_action_suffix"):
			continue
		var player_number = player.player_number
		if players_by_number.has(player_number):
			continue
		players_by_number[player_number] = player
		if GameEvents.persisted_upgrades_by_player.has(player_number):
			current_upgrades_by_player[player_number] = GameEvents.persisted_upgrades_by_player[player_number].duplicate(true)
		else:
			current_upgrades_by_player[player_number] = {}
		if GameEvents.persisted_upgrade_pools_by_player.has(player_number):
			upgrade_pools_by_player[player_number] = GameEvents.persisted_upgrade_pools_by_player[player_number]
		else:
			upgrade_pools_by_player[player_number] = create_upgrade_pool()
		_store_persistent_state(player_number)

	var player_numbers = get_player_numbers()
	if player_numbers.is_empty():
		return
	if not player_numbers.has(current_turn_player_number):
		current_turn_player_number = player_numbers[0]
	GameEvents.persisted_turn_player_number = current_turn_player_number


func _store_persistent_state(player_number: int) -> void:
	GameEvents.persisted_upgrades_by_player[player_number] = current_upgrades_by_player[player_number].duplicate(true)
	GameEvents.persisted_upgrade_pools_by_player[player_number] = upgrade_pools_by_player[player_number]
	GameEvents.persisted_turn_player_number = current_turn_player_number


func _reapply_current_upgrades() -> void:
	for player_number in current_upgrades_by_player.keys():
		var current_upgrades = current_upgrades_by_player[player_number]
		for upgrade_data in current_upgrades.values():
			if typeof(upgrade_data) != TYPE_DICTIONARY:
				continue
			if not upgrade_data.has("resource"):
				continue
			GameEvents.emit_ability_upgrade_added(upgrade_data["resource"], current_upgrades, player_number)
