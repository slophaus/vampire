extends Node

const MAX_RANGE = 450
const PLAYER_ATTACK_LAYER = 4
const ENEMY_ATTACK_LAYER = 8
const BASE_PENETRATION = 1
const PENETRATION_PER_LEVEL = 0
const BASE_SCALE = 1.0
const SCALE_PER_LEVEL = 0.15

@export var fireball_ability: PackedScene
@export var owner_group := "player"
@export var target_group := "enemy"

var base_damage = 2.0
var damage_per_level = 2.0
var additional_damage_percent: float = 1.0
var base_wait_time := 0.0
var rate_reduction_percent := 0.0
var fireball_level := 1
var multi_shot_delay := 0.3
var player_number := 1


func _ready():
	player_number = resolve_player_number()
	base_wait_time = $Timer.wait_time
	update_timer_wait_time()
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
			await fire_fireballs(owner_actor.global_position, owner_actor.global_position + (aim_direction * MAX_RANGE))
			return

	var targets = get_tree().get_nodes_in_group(target_group)
	targets = targets.filter(func(target: Node2D):
		if target == null or not is_instance_valid(target):
			return false
		if target.get("is_regenerating") == true:
			return false
		return target.global_position.distance_squared_to(owner_actor.global_position) < pow(MAX_RANGE, 2)
	)
	
	if targets.is_empty():
		return

	var selected_target = targets.pick_random()
	await fire_fireballs(owner_actor.global_position, selected_target.global_position)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if owner_group != "player":
		return
	if upgrade_player_number != player_number:
		return
	match upgrade.id:
		"fireball_level":
			fireball_level = 1 + current_upgrades["fireball_level"]["quantity"]


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


func spawn_fireball(start_position: Vector2, target_position: Vector2) -> void:
	var fireball_instance = fireball_ability.instantiate() as FireballAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(fireball_instance)
	var level_damage = base_damage + (damage_per_level * (fireball_level - 1))
	fireball_instance.hitbox_component.damage = level_damage * additional_damage_percent
	fireball_instance.hitbox_component.knockback = 250.0
	fireball_instance.hitbox_component.penetration = BASE_PENETRATION + (PENETRATION_PER_LEVEL * (fireball_level - 1))
	fireball_instance.target_group = target_group
	fireball_instance.scale = Vector2.ONE * (BASE_SCALE + (SCALE_PER_LEVEL * (fireball_level - 1)))
	fireball_instance.refresh_splash_visual()
	if target_group == "player":
		fireball_instance.hitbox_component.collision_layer = ENEMY_ATTACK_LAYER
	else:
		fireball_instance.hitbox_component.collision_layer = PLAYER_ATTACK_LAYER

	fireball_instance.setup(start_position, target_position, MAX_RANGE)


func fire_fireballs(start_position: Vector2, target_position: Vector2) -> void:
	spawn_fireball(start_position, target_position)


func set_active(active: bool) -> void:
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	if active:
		$Timer.start()
	else:
		$Timer.stop()


func update_timer_wait_time() -> void:
	$Timer.wait_time = base_wait_time * (1 - rate_reduction_percent)
