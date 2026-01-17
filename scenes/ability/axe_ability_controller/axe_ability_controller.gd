extends Node

@export var axe_ability_scene: PackedScene

var base_damage = 10
var additional_damage_bonus: float = 0.0
var axe_scale_bonus: float = 0.0
var base_penetration := 3
var axe_level := 1
var multi_shot_span := 0.45
var player_number := 1


func _ready():
	player_number = resolve_player_number()
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)


func on_timer_timeout() -> void:
	var player = get_player()
	if player == null:
		return
	if player.has_method("can_attack") and not player.can_attack():
		return
	
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	await spawn_axes(player, foreground)


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if upgrade_player_number != player_number:
		return
	match upgrade.id:
		"axe_damage":
			additional_damage_bonus = current_upgrades["axe_damage"]["quantity"] * 5.0
			axe_scale_bonus = current_upgrades["axe_damage"]["quantity"] * 0.3
		"axe_level":
			axe_level = 1 + current_upgrades["axe_level"]["quantity"]


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


func spawn_axes(player: Node2D, foreground: Node2D) -> void:
	var multi_shot_delay = multi_shot_span
	if axe_level > 1:
		multi_shot_delay = multi_shot_span / float(axe_level - 1)
	for shot_index in range(axe_level):
		if not is_instance_valid(foreground) or not foreground.is_inside_tree():
			return
		var axe_instance = axe_ability_scene.instantiate() as AxeAbility
		foreground.add_child(axe_instance)
		axe_instance.start_angle = 0.0
		axe_instance.source_player = player
		axe_instance.global_position = player.global_position
		axe_instance.hitbox_component.damage = base_damage + additional_damage_bonus
		axe_instance.hitbox_component.knockback = 0.0
		axe_instance.hitbox_component.penetration = base_penetration
		axe_instance.scale *= 1.0 + axe_scale_bonus
		if shot_index < axe_level - 1:
			await get_tree().create_timer(multi_shot_delay).timeout
