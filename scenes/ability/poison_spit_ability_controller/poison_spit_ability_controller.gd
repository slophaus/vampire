extends Node

const MAX_RANGE = 450
const PLAYER_ATTACK_LAYER = 4
const ENEMY_ATTACK_LAYER = 8
const BASE_PENETRATION = 1
const PENETRATION_PER_LEVEL = 0
const BASE_SCALE = 1.0
const SCALE_PER_LEVEL = 0.1

@export var poison_spit_ability: PackedScene
@export var owner_group := "player"
@export var target_group := "enemy"

var base_damage = 0.0
var damage_per_level = 0.0
var base_poison_damage := 12.5
var poison_damage_per_level := 2.5
var additional_damage_percent: float = 1.0
var base_wait_time := 0.0
var rate_reduction_percent := 0.0
var poison_spit_level := 1
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

	var selected_target = targets.pick_random()
	fire_spit(owner_actor.global_position, selected_target.global_position)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if owner_group != "player":
		return
	if upgrade_player_number != player_number:
		return
	if upgrade.id == "poison_spit_level":
		poison_spit_level = 1 + current_upgrades["poison_spit_level"]["quantity"]


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


func spawn_spit(start_position: Vector2, target_position: Vector2) -> void:
	var spit_instance = poison_spit_ability.instantiate() as PoisonSpitAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(spit_instance)
	spit_instance.owner_actor = get_owner_actor()
	var level_damage = base_damage + (damage_per_level * (poison_spit_level - 1))
	spit_instance.hitbox_component.damage = level_damage * additional_damage_percent
	spit_instance.hitbox_component.poison_damage = base_poison_damage + (poison_damage_per_level * (poison_spit_level - 1))
	spit_instance.hitbox_component.knockback = 150.0
	spit_instance.hitbox_component.penetration = BASE_PENETRATION + (PENETRATION_PER_LEVEL * (poison_spit_level - 1))
	spit_instance.target_group = target_group
	spit_instance.scale = Vector2.ONE * (BASE_SCALE + (SCALE_PER_LEVEL * (poison_spit_level - 1)))
	if target_group == "player":
		spit_instance.hitbox_component.collision_layer = ENEMY_ATTACK_LAYER
	else:
		spit_instance.hitbox_component.collision_layer = PLAYER_ATTACK_LAYER

	spit_instance.setup(start_position, target_position, MAX_RANGE)


func fire_spit(start_position: Vector2, target_position: Vector2) -> void:
	spawn_spit(start_position, target_position)


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
