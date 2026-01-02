extends Node

@export var whip_scene: PackedScene
@export var owner_group := "player"

var player_number := 1
var whip_instance: WhipAbility
var last_aim_direction := Vector2.RIGHT


func _ready() -> void:
	player_number = resolve_player_number()
	spawn_whip()


func _physics_process(_delta: float) -> void:
	if whip_instance == null:
		return
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return
	var aim_direction = get_aim_direction(owner_actor)
	var movement_velocity = get_owner_velocity(owner_actor)
	if aim_direction == Vector2.ZERO:
		if movement_velocity.length() > 0.1:
			aim_direction = movement_velocity.normalized()
		else:
			aim_direction = last_aim_direction
	else:
		last_aim_direction = aim_direction

	var anchor = owner_actor.global_position
	var tip_target = anchor + (aim_direction * whip_instance.get_total_length())
	whip_instance.set_anchor_position(anchor)
	whip_instance.set_tip_target(tip_target)
	whip_instance.set_driver_velocity(movement_velocity)


func spawn_whip() -> void:
	if whip_scene == null:
		return
	whip_instance = whip_scene.instantiate() as WhipAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	if foreground_layer != null:
		foreground_layer.add_child(whip_instance)
	else:
		add_child(whip_instance)


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


func get_aim_direction(player: Node2D) -> Vector2:
	if player != null and player.has_method("get_aim_direction"):
		return player.get_aim_direction()
	var suffix = get_player_action_suffix(player)
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	var aim_vector = Vector2(x_aim, y_aim)
	if aim_vector.length() < 0.1:
		return Vector2.ZERO
	return aim_vector.normalized()


func get_player_action_suffix(player: Node) -> String:
	if player != null && player.has_method("get_player_action_suffix"):
		return player.get_player_action_suffix()
	if player != null:
		var player_number_value = player.get("player_number")
		if typeof(player_number_value) == TYPE_INT && player_number_value > 1:
			return str(player_number_value)
	return ""


func get_owner_velocity(owner_actor: Node2D) -> Vector2:
	if owner_actor is CharacterBody2D:
		return owner_actor.velocity
	if owner_actor.has_method("get_velocity"):
		return owner_actor.get_velocity()
	return Vector2.ZERO
