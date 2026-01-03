extends Node2D

@export var segment_count := 14
@export var segment_length := 8.0
@export var constraint_iterations := 6
@export var damping := 0.2
@export var base_offset := 20.0
@export var power_released_falloff_speed := 6.0
@export var power_steady_falloff_speed := 1.0
@export var power_direction_change_strength := 15.0
@export var power_direction_change_speed := 100.0
@export var anchor_follow_strength := 0.3
@export var loose_anchor_follow_strength := 0.02
@export var parent_alignment_strength := 0.15
@export var loose_parent_alignment_strength := 0.005
@export var segment_scale := 0.6666667
@export var tip_speed_damage := 0.007
@export var point_color := Color(0.95, 0.9, 1.0, 0.9)
@export var segment_scene: PackedScene = preload("res://scenes/ability/whip_ability_controller/whip_segment.tscn")

var player_number := 1
var whip_level := 1
var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var point_angles: Array[float] = []
var segment_nodes: Array[Node2D] = []
var last_direction := Vector2.RIGHT
var base_alignment_direction := Vector2.RIGHT
var tip_hitbox: HitboxComponent
var current_base_offset := 0.0
var current_anchor_follow_strength := 0.0
var current_base_alignment_strength := 0.0
var current_parent_alignment_strength := 0.0
var current_power := 0.0
var last_aim_direction := Vector2.ZERO
var is_owner_regenerating := false
const AIM_MIN_DIRECTION_STRENGTH := 0.02
const AIM_POWER_CURVE := 2.0
const BASE_SEGMENT_LENGTH := 12.0
const BASE_SEGMENT_SCALE := 1.0
const MAX_WHIP_LEVEL := 3
const LEVEL_SEGMENT_LENGTHS := {
	1: 8.0,
	2: BASE_SEGMENT_LENGTH,
	3: 16.0,
}


func _ready() -> void:
	player_number = resolve_player_number()
	segment_count = max(segment_count, 2)
	var owner_actor = get_owner_actor()
	if owner_actor != null and owner_actor.has_method("get_player_tint"):
		point_color = owner_actor.get_player_tint()
		point_color.a = 0.9
	_apply_whip_level(whip_level)
	_initialize_segments()
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return
	if segment_nodes.size() != segment_count:
		_initialize_points()
		_initialize_segments()

	is_owner_regenerating = owner_actor.get("is_regenerating") == true
	var aim_vector = Vector2.ZERO if is_owner_regenerating else get_aim_vector(owner_actor)
	var aim_strength = clamp(aim_vector.length(), 0.0, 1.0)
	var has_aim_input = aim_strength > AIM_MIN_DIRECTION_STRENGTH
	var aim_direction = last_aim_direction
	if has_aim_input:
		aim_direction = aim_vector.normalized()
	var angle_delta := 0.0
	if has_aim_input and last_aim_direction.length_squared() > 0.0001:
		angle_delta = abs(aim_direction.angle_to(last_aim_direction))
	if has_aim_input:
		last_aim_direction = aim_direction
	var desired_direction = aim_direction
	if desired_direction.length_squared() <= 0.0001:
		desired_direction = last_direction
	else:
		desired_direction = desired_direction.normalized()
		last_direction = desired_direction
	base_alignment_direction = desired_direction

	var target_power := 0.0
	var power_speed := power_released_falloff_speed
	if has_aim_input and not is_owner_regenerating:
		var direction_change = clamp(angle_delta / PI, 0.0, 1.0)
		var direction_change_speed = angle_delta / max(delta, 0.0001)
		var quick_turn_factor = clamp(direction_change_speed / max(power_direction_change_speed, 0.0001), 0.0, 1.0)
		var curved_strength = pow(aim_strength, AIM_POWER_CURVE)
		target_power = clamp(direction_change * quick_turn_factor * curved_strength * power_direction_change_strength, 0.0, 1.0)
		power_speed = power_steady_falloff_speed
	if is_owner_regenerating:
		target_power = 0.0
	if target_power >= current_power:
		current_power = target_power
	else:
		current_power = lerp(current_power, target_power, clamp(power_speed * delta, 0.0, 1.0))

	current_base_offset = lerp(0.0, base_offset, current_power)
	current_anchor_follow_strength = lerp(loose_anchor_follow_strength, anchor_follow_strength, current_power)
	current_base_alignment_strength = lerp(0.0, parent_alignment_strength, current_power)
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


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int) -> void:
	if upgrade_player_number != player_number:
		return
	if upgrade.id == "whip_level":
		var next_level = 1 + current_upgrades["whip_level"]["quantity"]
		_apply_whip_level(next_level)


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
	if current_parent_alignment_strength <= 0.0 and current_base_alignment_strength <= 0.0:
		return
	var desired_base = points[0] + (base_alignment_direction * segment_length)
	points[1] = points[1].lerp(desired_base, current_base_alignment_strength)
	if segment_count < 3:
		return
	for index in range(1, segment_count - 1):
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


func _apply_whip_level(new_level: int) -> void:
	whip_level = clampi(new_level, 1, MAX_WHIP_LEVEL)
	var new_length = LEVEL_SEGMENT_LENGTHS.get(whip_level, BASE_SEGMENT_LENGTH)
	segment_length = new_length
	segment_scale = BASE_SEGMENT_SCALE * (segment_length / BASE_SEGMENT_LENGTH)
	_initialize_points()
	_update_point_angles()
	_sync_segments()


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
			var base_color = point_color
			if is_owner_regenerating:
				base_color = Color.BLACK
				base_color.a = point_color.a
			var power_color = base_color.lerp(Color.WHITE, current_power)
			power_color.a = base_color.a
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


func get_aim_vector(player: Node2D) -> Vector2:
	var suffix = get_player_action_suffix(player)
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	return Vector2(x_aim, y_aim)
