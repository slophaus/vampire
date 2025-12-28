extends Node
class_name VelocityComponent

@export var max_speed: int = 30
@export var acceleration: float = 5
 
var velocity := Vector2.ZERO


func accelerate_to_player():
	var owner_node2d = owner as Node2D
	if owner_node2d == null:
		return
	
	var player = get_closest_player(owner_node2d.global_position)
	if player == null:
		return
	
	var direction = (player.global_position - owner_node2d.global_position).normalized()
	accelerate_in_direction(direction)

func get_closest_player(from_position: Vector2) -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	var closest_player: Node2D = null
	var closest_distance = INF
	for player in players:
		var player_node = player as Node2D
		if player_node == null:
			continue
		if player_node.has_method("can_attack") and not player_node.can_attack():
			continue
		var distance = from_position.distance_squared_to(player_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player_node
	return closest_player


func accelerate_in_direction(direction: Vector2):
	var desired_velocity = direction * max_speed
	velocity = velocity.lerp(desired_velocity, 1 - exp(-acceleration * get_process_delta_time()))


func move(character_body: CharacterBody2D):
	character_body.velocity = velocity
	character_body.move_and_slide()

	velocity = character_body.velocity


func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction == Vector2.ZERO or strength <= 0:
		return
	velocity += direction.normalized() * strength
