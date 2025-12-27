extends Node

const MAX_RANGE = 450

@export var boomerang_ability_scene: PackedScene

var base_damage = 4
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

	var aim_direction = get_aim_direction(player)
	if aim_direction != Vector2.ZERO:
		spawn_boomerang(player.global_position, player.global_position + (aim_direction * MAX_RANGE), player)
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

	spawn_boomerang(player.global_position, enemies[0].global_position, player)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	match upgrade.id:
		"boomerang_rate":
			var percent_reduction = current_upgrades["boomerang_rate"]["quantity"] * 0.1
			$Timer.wait_time = base_wait_time * (1 - percent_reduction)
			$Timer.start()
		"boomerang_damage":
			additional_damage_percent = 1 + (current_upgrades["boomerang_damage"]["quantity"] * 0.15)


func get_player() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D && node.is_in_group("player"):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group("player") as Node2D


func get_player_action_suffix(player: Node) -> String:
	if player != null && player.has_method("get_player_action_suffix"):
		return player.get_player_action_suffix()

	if player != null:
		var player_number = player.get("player_number")
		if typeof(player_number) == TYPE_INT && player_number > 1:
			return str(player_number)

	return ""


func get_aim_direction(player: Node2D) -> Vector2:
	var suffix = get_player_action_suffix(player)
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	var aim_vector = Vector2(x_aim, y_aim)

	if aim_vector.length() < 0.1:
		return Vector2.ZERO

	return aim_vector.normalized()


func spawn_boomerang(start_position: Vector2, target_position: Vector2, player: Node2D) -> void:
	var boomerang_instance = boomerang_ability_scene.instantiate() as BoomerangAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(boomerang_instance)
	boomerang_instance.hitbox_component.damage = base_damage * additional_damage_percent

	boomerang_instance.setup(start_position, target_position, MAX_RANGE, player)
