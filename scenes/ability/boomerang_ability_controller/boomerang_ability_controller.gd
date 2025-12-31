extends Node

const BASE_RANGE = 120
const RANGE_PER_LEVEL = 25
const BASE_PENETRATION = 10
const PENETRATION_PER_LEVEL = 3
const SIZE_PER_LEVEL = 0.2

@export var boomerang_ability_scene: PackedScene

var base_damage = 4
var damage_per_level = 2
var additional_damage_percent: float = 1.0
var base_wait_time
var boomerang_level := 1
var player_number := 1


func _ready():
	player_number = resolve_player_number()
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)


func on_timer_timeout():
	var player = get_player()
	if player == null:
		return
	if player.has_method("can_attack") and not player.can_attack():
		return

	var aim_direction = get_aim_direction(player)
	if aim_direction != Vector2.ZERO:
		spawn_boomerang(player.global_position, player.global_position + (aim_direction * get_boomerang_range()), player)
		return

	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < pow(get_boomerang_range(), 2)
	)

	if enemies.is_empty():
		return

	enemies.sort_custom(func(a: Node2D, b: Node2D):
		var a_distance = a.global_position.distance_squared_to(player.global_position)
		var b_distance = b.global_position.distance_squared_to(player.global_position)

		return a_distance < b_distance
	)

	spawn_boomerang(player.global_position, enemies[0].global_position, player)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if upgrade_player_number != player_number:
		return
	match upgrade.id:
		"boomerang_rate":
			var percent_reduction = current_upgrades["boomerang_rate"]["quantity"] * 0.1
			$Timer.wait_time = base_wait_time * (1 - percent_reduction)
			$Timer.start()
		"boomerang_damage":
			additional_damage_percent = 1 + (current_upgrades["boomerang_damage"]["quantity"] * 0.15)
		"boomerang_level":
			boomerang_level = 1 + current_upgrades["boomerang_level"]["quantity"]


func get_player() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D && node.is_in_group("player"):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group("player") as Node2D


func resolve_player_number() -> int:
	var player = get_player()
	if player != null and player.has_method("get_player_action_suffix"):
		return player.player_number
	return player_number


func set_player_number(new_player_number: int) -> void:
	player_number = new_player_number


func get_player_action_suffix(player: Node) -> String:
	if player != null && player.has_method("get_player_action_suffix"):
		return player.get_player_action_suffix()

	if player != null:
		var player_number_value = player.get("player_number")
		if typeof(player_number_value) == TYPE_INT && player_number_value > 1:
			return str(player_number_value)

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
	var level_damage = base_damage + (damage_per_level * (boomerang_level - 1))
	boomerang_instance.hitbox_component.damage = level_damage * additional_damage_percent
	boomerang_instance.hitbox_component.knockback = 80.0
	boomerang_instance.hitbox_component.penetration = BASE_PENETRATION + (PENETRATION_PER_LEVEL * (boomerang_level - 1))
	boomerang_instance.scale = Vector2.ONE * (1.0 + (SIZE_PER_LEVEL * (boomerang_level - 1)))

	boomerang_instance.setup(start_position, target_position, get_boomerang_range(), player)


func get_boomerang_range() -> float:
	return BASE_RANGE + (RANGE_PER_LEVEL * (boomerang_level - 1))
