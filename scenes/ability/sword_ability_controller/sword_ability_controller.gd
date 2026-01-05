extends Node

const MAX_RANGE = 450
const PLAYER_HITBOX_LAYER = 4
const ENEMY_HITBOX_LAYER = 8

@export var sword_ability: PackedScene
@export var owner_group := "player"
@export var target_group := "enemy"

var base_damage = 5
var additional_damage_bonus: float = 0.0
var base_penetration := 3
var base_wait_time
var sword_level := 1
var multi_shot_delay := 0.1
var player_number := 1



func _ready():
	player_number = resolve_player_number()
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)


func on_timer_timeout() -> void:
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return
	if owner_actor.has_method("can_attack") and not owner_actor.can_attack():
		return

	if owner_group == "player":
		var aim_direction = get_aim_direction(owner_actor)
		if aim_direction != Vector2.ZERO:
			await fire_swords(owner_actor.global_position, owner_actor.global_position + (aim_direction * MAX_RANGE))
			return

	var targets = get_tree().get_nodes_in_group(target_group)
	targets = targets.filter(func(target: Node2D):
		if target == null or not is_instance_valid(target):
			return false
		if target.is_in_group("ghost"):
			return false
		if target.get("is_regenerating") == true:
			return false
		return target.global_position.distance_squared_to(owner_actor.global_position) < pow(MAX_RANGE, 2)
	)
	
	if targets.is_empty():
		return
	
	targets.sort_custom(func(a: Node2D, b: Node2D):
		var a_distance = a.global_position.distance_squared_to(owner_actor.global_position)
		var b_distance = b.global_position.distance_squared_to(owner_actor.global_position)
		
		return a_distance < b_distance
	)
	
	await fire_swords(owner_actor.global_position, targets[0].global_position)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if owner_group != "player":
		return
	if upgrade_player_number != player_number:
		return
	match upgrade.id:
		"sword_rate":
			var percent_reduction = current_upgrades["sword_rate"]["quantity"] * 0.2
			$Timer.wait_time = base_wait_time * (1 - percent_reduction)
			$Timer.start()
		"sword_damage":
			additional_damage_bonus = current_upgrades["sword_damage"]["quantity"] * 5.0
		"sword_level":
			sword_level = 1 + current_upgrades["sword_level"]["quantity"]


func get_owner_actor() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D && node.is_in_group(owner_group):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group(owner_group) as Node2D


func resolve_player_number() -> int:
	if owner_group != "player":
		return player_number
	var player = get_owner_actor()
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


func spawn_sword(start_position: Vector2, target_position: Vector2) -> void:
	var sword_instance = sword_ability.instantiate() as SwordAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(sword_instance)
	sword_instance.owner_actor = get_owner_actor()
	sword_instance.hitbox_component.damage = base_damage + additional_damage_bonus
	sword_instance.hitbox_component.knockback = 250.0
	sword_instance.hitbox_component.penetration = base_penetration
	if owner_group == "player":
		sword_instance.hitbox_component.collision_layer = PLAYER_HITBOX_LAYER
	else:
		sword_instance.hitbox_component.collision_layer = ENEMY_HITBOX_LAYER

	sword_instance.setup(start_position, target_position, MAX_RANGE)


func fire_swords(start_position: Vector2, target_position: Vector2) -> void:
	for shot_index in range(sword_level):
		spawn_sword(start_position, target_position)
		if shot_index < sword_level - 1:
			await get_tree().create_timer(multi_shot_delay).timeout


func set_active(active: bool) -> void:
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	if active:
		$Timer.start()
	else:
		$Timer.stop()
