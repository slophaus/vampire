extends Node

@export var experience_manager: ExperienceManager
@export var upgrade_screen_scene: PackedScene

var player_upgrades := {}
var player_upgrade_pools := {}
var players: Array = []
var current_player_index := 0

var upgrade_boomerang := preload("res://resources/upgrades/boomerang.tres")
var upgrade_axe := preload("res://resources/upgrades/axe.tres")
var upgrade_axe_damage := preload("res://resources/upgrades/axe_damage.tres")
var upgrade_sword_rate := preload("res://resources/upgrades/sword_rate.tres")
var upgrade_sword_damage := preload("res://resources/upgrades/sword_damage.tres")
var upgrade_player_speed := preload("res://resources/upgrades/player_speed.tres")

var rng := RandomNumberGenerator.new()


func _ready():
	players = get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a, b):
		return a.player_number < b.player_number
	)
	for player in players:
		player_upgrades[player] = {}
		player_upgrade_pools[player] = create_upgrade_pool()

	if not players.is_empty():
		GameEvents.emit_upgrade_turn_changed(players[current_player_index].player_number)

	experience_manager.level_up.connect(on_level_up)


func create_upgrade_pool() -> WeightedTable:
	var upgrade_pool: WeightedTable = WeightedTable.new()
	# axe damage는 axe 얻을 때 풀에 추가
	upgrade_pool.add_item(upgrade_axe, 10)
	upgrade_pool.add_item(upgrade_boomerang, 10)
	upgrade_pool.add_item(upgrade_sword_rate, 10)
	upgrade_pool.add_item(upgrade_sword_damage, 10)
	upgrade_pool.add_item(upgrade_player_speed, 5)
	return upgrade_pool


func apply_upgrade(upgrade: AbilityUpgrade, player: Node):
	var current_upgrades = player_upgrades.get(player, {})
	var upgrade_pool = player_upgrade_pools.get(player)
	if upgrade_pool == null:
		return

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
	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades, player)


func update_upgrade_pool(chosen_upgrade: AbilityUpgrade, upgrade_pool: WeightedTable):
	if chosen_upgrade.id == upgrade_axe.id:
		upgrade_pool.add_item(upgrade_axe_damage, 10)


func pick_upgrades(player: Node) -> Array[AbilityUpgrade]:
	var upgrade_pool = player_upgrade_pools.get(player)
	if upgrade_pool == null:
		return []

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
	if players.is_empty():
		return

	var player = players[current_player_index]
	var should_award_upgrade = true
	if player.has_method("is_regenerating_state") and player.is_regenerating_state():
		should_award_upgrade = false

	if should_award_upgrade:
		var upgrade_screen_instance = upgrade_screen_scene.instantiate()
		add_child(upgrade_screen_instance)
		upgrade_screen_instance.set_player_number(player.player_number)
		var chosen_upgrades = pick_upgrades(player)
		upgrade_screen_instance.set_ability_upgrades(chosen_upgrades)
		upgrade_screen_instance.upgrade_selected.connect(on_upgrade_selected.bind(player))

	advance_turn()


func on_upgrade_selected(upgrade: AbilityUpgrade, player: Node):
	apply_upgrade(upgrade, player)


func advance_turn():
	if players.is_empty():
		return

	current_player_index = (current_player_index + 1) % players.size()
	GameEvents.emit_upgrade_turn_changed(players[current_player_index].player_number)
