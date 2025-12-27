extends Node

const MAX_RANGE = 150

@export var sword_ability: PackedScene

var base_damage = 5
var additional_damage_percent: float = 1.0
var base_wait_time



func _ready():
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)


func on_timer_timeout():
	var player = get_player()
	if player == null:
		return

	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_RANGE, 2)
	)
	
	if enemies.is_empty():
		return
	
	enemies.sort_custom(func(a: Node2D, b: Node2D):
		var a_distance = a.global_position.distance_squared_to(player.global_position)
		var b_distance = b.global_position.distance_squared_to(player.global_position)
		
		return a_distance < b_distance
	)
	
	var sword_instance = sword_ability.instantiate() as SwordAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(sword_instance)
	sword_instance.hitbox_component.damage = base_damage * additional_damage_percent

	sword_instance.setup(player.global_position, enemies[0].global_position, MAX_RANGE)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	match upgrade.id:
		"sword_rate":
			var percent_reduction = current_upgrades["sword_rate"]["quantity"] * 0.1
			$Timer.wait_time = base_wait_time * (1 - percent_reduction)
			$Timer.start()
		"sword_damage":
			additional_damage_percent = 1 + (current_upgrades["sword_damage"]["quantity"] * 0.15)


func get_player() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D && node.is_in_group("player"):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group("player") as Node2D
