extends Node

@export var whip_ability_scene: PackedScene
@export var base_damage := 6
@export var knockback := 120.0

var player_number := 1
var whip_instance: WhipAbility


func _ready() -> void:
	player_number = resolve_player_number()
	_spawn_whip()


func _physics_process(_delta: float) -> void:
	var player = get_player()
	if player == null:
		return
	if whip_instance == null:
		_spawn_whip()
		return
	var aim_direction = get_aim_direction(player)
	var movement_velocity = get_move_velocity(player)
	whip_instance.set_control(aim_direction, movement_velocity)


func _spawn_whip() -> void:
	if whip_ability_scene == null:
		return
	var player = get_player()
	if player == null:
		return
	whip_instance = whip_ability_scene.instantiate() as WhipAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	var spawn_parent = foreground_layer if foreground_layer != null else get_tree().current_scene
	spawn_parent.add_child(whip_instance)
	whip_instance.setup(player)
	whip_instance.hitbox_component.damage = base_damage
	whip_instance.hitbox_component.knockback = knockback


func resolve_player_number() -> int:
	var player = get_player()
	if player != null and player.has_method("get_player_action_suffix"):
		return player.player_number
	return player_number


func set_player_number(new_player_number: int) -> void:
	player_number = new_player_number


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
		var player_number_value = player.get("player_number")
		if typeof(player_number_value) == TYPE_INT && player_number_value > 1:
			return str(player_number_value)

	return ""


func get_aim_direction(player: Node2D) -> Vector2:
	if player.has_method("get_aim_direction"):
		return player.get_aim_direction()
	var suffix = get_player_action_suffix(player)
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	var aim_vector = Vector2(x_aim, y_aim)
	if aim_vector.length() < 0.1:
		return Vector2.ZERO
	return aim_vector.normalized()


func get_move_velocity(player: Node2D) -> Vector2:
	if player.has_node("VelocityComponent"):
		var velocity_component = player.get_node("VelocityComponent") as VelocityComponent
		if velocity_component != null:
			return velocity_component.velocity
	var velocity_value = player.get("velocity")
	if typeof(velocity_value) == TYPE_VECTOR2:
		return velocity_value
	if player.has_method("get_movement_vector"):
		return player.get_movement_vector() * 100.0
	return Vector2.ZERO
