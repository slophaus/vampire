extends Node2D

@export var segment_count := 14
@export var segment_length := 12.0
@export var constraint_iterations := 6
@export var damping := 0.2
@export var base_offset := 20.0
@export var power_build_speed := 40.0
@export var power_loose_falloff_speed := 6.0
@export var power_steady_falloff_speed := 2.0
@export var anchor_follow_strength := 0.3
@export var loose_anchor_follow_strength := 0.02
@export var angle_strength := 0.05
@export var loose_angle_strength := 0.0
@export var parent_alignment_strength := 0.15
@export var loose_parent_alignment_strength := 0.005
@export var segment_scale := 1.0
@export var tip_speed_damage := 0.007
@export var point_color := Color(0.95, 0.9, 1.0, 0.9)
@export var segment_scene: PackedScene = preload("res://scenes/ability/whip_ability_controller/whip_segment.tscn")

var player_number := 1
var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var point_angles: Array[float] = []
var segment_nodes: Array[Node2D] = []
var last_direction := Vector2.RIGHT
var base_alignment_direction := Vector2.RIGHT
var tip_hitbox: HitboxComponent
var current_base_offset := 0.0
var current_anchor_follow_strength := 0.0
var current_angle_strength := 0.0
var current_parent_alignment_strength := 0.0
var current_power := 0.0
var last_aim_direction := Vector2.ZERO
const AIM_INFLUENCE := 1.0
const MOVEMENT_INFLUENCE := 0.0
const STEADY_AIM_ANGLE_THRESHOLD := 0.02


func _ready() -> void:
	player_number = resolve_player_number()
	segment_count = max(segment_count, 2)
	var owner_actor = get_owner_actor()
	if owner_actor != null and owner_actor.has_method("get_player_tint"):
		point_color = owner_actor.get_player_tint()
		point_color.a = 0.9
	_initialize_points()
	_initialize_segments()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return
	if segment_nodes.size() != segment_count:
		_initialize_points()
		_initialize_segments()

	var aim_direction = get_aim_direction(owner_actor)
	var has_aim_input = aim_direction.length_squared() > 0.0001
	var steady_aim = false
	if has_aim_input:
		if last_aim_direction.length_squared() > 0.0001:
			var angle_delta = abs(aim_direction.angle_to(last_aim_direction))
			steady_aim = angle_delta <= STEADY_AIM_ANGLE_THRESHOLD
		last_aim_direction = aim_direction
	var movement_direction = _get_movement_direction(owner_actor)
	var desired_direction = (aim_direction * AIM_INFLUENCE) + (movement_direction * MOVEMENT_INFLUENCE)
	if desired_direction.length_squared() <= 0.0001:
		desired_direction = last_direction
	else:
		desired_direction = desired_direction.normalized()
		last_direction = desired_direction
	base_alignment_direction = desired_direction

	var target_power := 0.0
	var power_speed := power_loose_falloff_speed
	if has_aim_input and not steady_aim:
		target_power = 1.0
		power_speed = power_build_speed
	elif has_aim_input and steady_aim:
		target_power = 0.0
		power_speed = power_steady_falloff_speed
	current_power = lerp(current_power, target_power, clamp(power_speed * delta, 0.0, 1.0))

	current_base_offset = lerp(0.0, base_offset, current_power)
	current_anchor_follow_strength = lerp(loose_anchor_follow_strength, anchor_follow_strength, current_power)
	current_angle_strength = lerp(loose_angle_strength, angle_strength, current_power)
	current_parent_alignment_strength = lerp(loose_parent_alignment_strength, parent_alignment_strength, current_power)

	var anchor_position = owner_actor.global_position + (desired_direction * current_base_offset)
	var anchor_delta = anchor_position - points[0]
	points[0] = anchor_position
	previous_points[0] = anchor_position

	for index in range(1, segment_count):
		var current_position = points[index]
		var velocity = (points[index] - previous_points[index]) * (1.0 - damping)
		points[index] += velocity
		points[index] += anchor_delta * current_anchor_follow_strength * (1.0 - float(index) / float(segment_count))
		previous_points[index] = current_position

	for iteration in range(constraint_iterations):
		points[0] = anchor_position
		_apply_distance_constraints()
		_apply_angle_constraints()

	_update_point_angles()
	_sync_segments()
	_update_tip_damage(delta)


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
	if segment_count < 2:
		return
	if current_parent_alignment_strength > 0.0:
		var desired_base = points[0] + (base_alignment_direction * segment_length)
		points[1] = points[1].lerp(desired_base, current_parent_alignment_strength)
	if segment_count < 3:
		return
	for index in range(1, segment_count - 1):
		var target = (points[index - 1] + points[index + 1]) * 0.5
		points[index] = points[index].lerp(target, current_angle_strength)
		if current_parent_alignment_strength > 0.0:
			var parent_delta = points[index] - points[index - 1]
			if parent_delta.length_squared() > 0.0001:
				var parent_direction = parent_delta.normalized()
				var desired_child = points[index] + (parent_direction * segment_length)
				points[index + 1] = points[index + 1].lerp(desired_child, current_parent_alignment_strength)


func _initialize_points() -> void:
	points.clear()
	previous_points.clear()
	point_angles.clear()
	var owner_actor = get_owner_actor()
	var anchor_position = Vector2.ZERO
	if owner_actor != null:
		anchor_position = owner_actor.global_position
	var direction = last_direction
	for index in range(segment_count):
		var position = anchor_position - (direction * segment_length * index)
		points.append(position)
		previous_points.append(position)
		point_angles.append(direction.angle())


func _initialize_segments() -> void:
	for segment in segment_nodes:
		if segment != null:
			segment.queue_free()
	segment_nodes.clear()
	tip_hitbox = null
	if segment_scene == null:
		return
	for index in range(segment_count):
		var segment = segment_scene.instantiate() as Node2D
		if segment == null:
			continue
		add_child(segment)
		segment_nodes.append(segment)
		if segment is CanvasItem:
			(segment as CanvasItem).modulate = point_color
		_configure_segment_hitbox(segment, index)


func _update_point_angles() -> void:
	point_angles.resize(points.size())
	for index in range(points.size()):
		var direction = Vector2.RIGHT
		if points.size() > 1:
			if index < points.size() - 1:
				direction = points[index + 1] - points[index]
			else:
				direction = points[index] - points[index - 1]
			if direction.length_squared() > 0.0001:
				direction = direction.normalized()
			else:
				direction = Vector2.RIGHT
		point_angles[index] = direction.angle()


func _sync_segments() -> void:
	if segment_nodes.size() != points.size():
		return
	for index in range(points.size()):
		var segment = segment_nodes[index]
		if segment == null:
			continue
		segment.global_position = points[index]
		segment.rotation = point_angles[index] - (PI * 0.5)
		segment.scale = Vector2.ONE * segment_scale
		if segment is CanvasItem:
			var power_color = point_color.lerp(Color.WHITE, current_power)
			power_color.a = point_color.a
			(segment as CanvasItem).modulate = power_color


func _configure_segment_hitbox(segment: Node2D, index: int) -> void:
	var hitbox = segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		return
	var collision_shape = hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var is_tip = index == segment_count - 1
	hitbox.monitoring = is_tip
	hitbox.monitorable = is_tip
	if collision_shape != null:
		collision_shape.disabled = not is_tip
	if is_tip:
		tip_hitbox = hitbox


func _update_tip_damage(delta: float) -> void:
	if tip_hitbox == null:
		return
	var tip_index = points.size() - 1
	if tip_index < 0:
		return
	var tip_velocity = points[tip_index] - previous_points[tip_index]
	var tip_speed = tip_velocity.length() / max(delta, 0.0001)
	var scaled_damage = tip_speed * tip_speed_damage
	tip_hitbox.damage = int(round(scaled_damage))


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
