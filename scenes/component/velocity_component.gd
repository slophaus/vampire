extends Node
class_name VelocityComponent

@export var max_speed: int = 30
@export var acceleration: float = 5
@export var damping: float = 2.0
@export var target_refresh_interval: float = 2.0
@export var sight_range: float = 400.0
 
var velocity := Vector2.ZERO
var cached_player: Node2D = null
var time_since_target_refresh := 0.0


func accelerate_to_player():
	var owner_node2d = owner as Node2D
	if owner_node2d == null:
		return

	if cached_player == null:
		refresh_target_player(owner_node2d.global_position)

	if cached_player == null:
		return
	if not is_target_in_sight(cached_player, owner_node2d.global_position):
		clear_target_player()
		return
	
	var direction = (cached_player.global_position - owner_node2d.global_position).normalized()
	accelerate_in_direction(direction)


func _ready() -> void:
	set_process(true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	time_since_target_refresh = rng.randf_range(0.0, target_refresh_interval)


func _process(delta: float) -> void:
	time_since_target_refresh += delta
	if time_since_target_refresh >= target_refresh_interval:
		time_since_target_refresh = 0.0
		var owner_node2d = owner as Node2D
		if owner_node2d == null:
			return
		refresh_target_player(owner_node2d.global_position)


func refresh_target_player(from_position: Vector2) -> void:
	cached_player = get_closest_player(from_position)

func clear_target_player() -> void:
	cached_player = null

func is_target_in_sight(target_player: Node2D, from_position: Vector2) -> bool:
	if target_player == null:
		return false
	if sight_range <= 0.0:
		return true
	return from_position.distance_squared_to(target_player.global_position) <= sight_range * sight_range

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
		if player_node.has_method("can_be_targeted") and not player_node.can_be_targeted():
			continue
		var distance = from_position.distance_squared_to(player_node.global_position)
		if sight_range > 0.0 and distance > sight_range * sight_range:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player_node
	return closest_player


func accelerate_in_direction(direction: Vector2):
	var desired_velocity = direction * max_speed
	velocity = velocity.lerp(desired_velocity, 1 - exp(-acceleration * get_physics_process_delta_time()))


func move(character_body: CharacterBody2D):
	if damping > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, damping * get_physics_process_delta_time())
	character_body.velocity = velocity
	character_body.move_and_slide()

	velocity = character_body.velocity


func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction == Vector2.ZERO or strength <= 0:
		return
	velocity += direction.normalized() * strength
