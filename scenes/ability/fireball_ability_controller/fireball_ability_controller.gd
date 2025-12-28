extends Node

const MAX_RANGE = 450
const PLAYER_HITBOX_LAYER = 4
const ENEMY_HITBOX_LAYER = 2

@export var fireball_ability: PackedScene
@export var owner_group := "player"
@export var target_group := "enemy"

var base_damage = 2.5
var additional_damage_percent: float = 1.0
var base_wait_time := 0.0
var base_wait_time_multiplier := 1.0
var rate_reduction_percent := 0.0
var fireball_level := 1
var multi_shot_delay := 0.1
var player_number := 1


func _ready():
	player_number = resolve_player_number()
	base_wait_time = $Timer.wait_time
	update_timer_wait_time()
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)


func on_timer_timeout() -> void:
	var owner = get_owner_actor()
	if owner == null:
		return
	if owner.has_method("can_attack") and not owner.can_attack():
		return

	if owner_group == "player":
		var aim_direction = get_aim_direction(owner)
		if aim_direction != Vector2.ZERO:
			await fire_fireballs(owner.global_position, owner.global_position + (aim_direction * MAX_RANGE))
			return

	var targets = get_tree().get_nodes_in_group(target_group)
	targets = targets.filter(func(target: Node2D):
		return target.global_position.distance_squared_to(owner.global_position) < pow(MAX_RANGE, 2)
	)
	
	if targets.is_empty():
		return

	var selected_target = targets.pick_random()
	await fire_fireballs(owner.global_position, selected_target.global_position)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if owner_group != "player":
		return
	if upgrade_player_number != player_number:
		return
	match upgrade.id:
		"sword_rate":
			rate_reduction_percent = current_upgrades["sword_rate"]["quantity"] * 0.1
			update_timer_wait_time()
			$Timer.start()
		"sword_damage":
			additional_damage_percent = 1 + (current_upgrades["sword_damage"]["quantity"] * 0.15)
		"sword_level":
			fireball_level = 1 + current_upgrades["sword_level"]["quantity"]


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


func set_base_wait_time_multiplier(multiplier: float) -> void:
	base_wait_time_multiplier = multiplier
	update_timer_wait_time()


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


func spawn_fireball(start_position: Vector2, target_position: Vector2) -> void:
	var fireball_instance = fireball_ability.instantiate() as FireballAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(fireball_instance)
	fireball_instance.hitbox_component.damage = base_damage * additional_damage_percent
	fireball_instance.hitbox_component.knockback = 250.0
	if owner_group == "player":
		fireball_instance.hitbox_component.collision_layer = PLAYER_HITBOX_LAYER
	else:
		fireball_instance.hitbox_component.collision_layer = ENEMY_HITBOX_LAYER

	fireball_instance.setup(start_position, target_position, MAX_RANGE)


func fire_fireballs(start_position: Vector2, target_position: Vector2) -> void:
	for shot_index in range(fireball_level):
		spawn_fireball(start_position, target_position)
		if shot_index < fireball_level - 1:
			await get_tree().create_timer(multi_shot_delay).timeout


func set_active(active: bool) -> void:
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	if active:
		$Timer.start()
	else:
		$Timer.stop()


func update_timer_wait_time() -> void:
	$Timer.wait_time = base_wait_time * base_wait_time_multiplier * (1 - rate_reduction_percent)
