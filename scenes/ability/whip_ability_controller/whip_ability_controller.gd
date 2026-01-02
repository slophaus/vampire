extends Node2D

@export var segment_count := 14
@export var segment_length := 12.0
@export var constraint_iterations := 6
@export var damping := 0.12
@export var base_offset := 20.0
@export var aim_influence := 1.0
@export var movement_influence := 0.6
@export var anchor_follow_strength := 0.6
@export var angle_constraint_strength := 0.35
@export var parent_angle_alignment_strength := 0.2
@export var point_radius := 4.0
@export var point_oval_scale := Vector2(1.5, 0.7)
@export var point_color := Color(0.95, 0.9, 1.0, 0.9)

var player_number := 1
var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var last_direction := Vector2.RIGHT


func _ready() -> void:
	player_number = resolve_player_number()
	segment_count = max(segment_count, 2)
	var owner_actor = get_owner_actor()
	if owner_actor != null and owner_actor.has_method("get_player_tint"):
		point_color = owner_actor.get_player_tint()
		point_color.a = 0.9
	_initialize_points()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return

	var aim_direction = get_aim_direction(owner_actor)
	var movement_direction = _get_movement_direction(owner_actor)
	var desired_direction = (aim_direction * aim_influence) + (movement_direction * movement_influence)
	if desired_direction.length_squared() <= 0.0001:
		desired_direction = last_direction
	else:
		desired_direction = desired_direction.normalized()
		last_direction = desired_direction

	var anchor_position = owner_actor.global_position + (desired_direction * base_offset)
	var anchor_delta = anchor_position - points[0]
	points[0] = anchor_position
	previous_points[0] = anchor_position

	for index in range(1, segment_count):
		var current_position = points[index]
		var velocity = (points[index] - previous_points[index]) * (1.0 - damping)
		points[index] += velocity
		points[index] += anchor_delta * anchor_follow_strength * (1.0 - float(index) / float(segment_count))
		previous_points[index] = current_position

	for iteration in range(constraint_iterations):
		points[0] = anchor_position
		_apply_distance_constraints()
		_apply_angle_constraints()

	queue_redraw()


func _draw() -> void:
	for index in range(points.size()):
		var point = points[index]
		var local_point = to_local(point)
		var direction = Vector2.RIGHT
		if points.size() > 1:
			if index < points.size() - 1:
				direction = (to_local(points[index + 1]) - local_point).normalized()
			else:
				direction = (local_point - to_local(points[index - 1])).normalized()
			if direction.length_squared() <= 0.0001:
				direction = Vector2.RIGHT
		draw_set_transform(local_point, direction.angle(), point_oval_scale)
		draw_circle(Vector2.ZERO, point_radius, point_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_distance_constraints() -> void:
	for index in range(segment_count - 1):
		var current = points[index]
		var next = points[index + 1]
		var delta = next - current
		var distance = delta.length()
		if distance == 0:
			continue
		var difference = (distance - segment_length) / distance
		if index == 0:
			points[index + 1] -= delta * difference
		else:
			points[index] += delta * difference * 0.5
			points[index + 1] -= delta * difference * 0.5


func _apply_angle_constraints() -> void:
	if segment_count < 3:
		return
	for index in range(1, segment_count - 1):
		var target = (points[index - 1] + points[index + 1]) * 0.5
		points[index] = points[index].lerp(target, angle_constraint_strength)
		if parent_angle_alignment_strength > 0.0:
			var parent_delta = points[index] - points[index - 1]
			if parent_delta.length_squared() > 0.0001:
				var parent_direction = parent_delta.normalized()
				var desired_child = points[index] + (parent_direction * segment_length)
				points[index + 1] = points[index + 1].lerp(desired_child, parent_angle_alignment_strength)


func _initialize_points() -> void:
	points.clear()
	previous_points.clear()
	var owner_actor = get_owner_actor()
	var anchor_position = Vector2.ZERO
	if owner_actor != null:
		anchor_position = owner_actor.global_position
	var direction = last_direction
	for index in range(segment_count):
		var position = anchor_position - (direction * segment_length * index)
		points.append(position)
		previous_points.append(position)


func get_owner_actor() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D && node.is_in_group("player"):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group("player") as Node2D


func resolve_player_number() -> int:
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


func _get_movement_direction(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	if player is CharacterBody2D:
		var velocity = (player as CharacterBody2D).velocity
		if velocity.length() <= 0.1:
			return Vector2.ZERO
		return velocity.normalized()
	return Vector2.ZERO
