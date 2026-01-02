extends Node2D
class_name WhipAbility

@export var segment_count := 12
@export var segment_length := 10.0
@export var constraint_iterations := 8
@export var angle_limit_degrees := 55.0
@export var angle_stiffness := 0.6
@export var point_radius := 2.5
@export var tip_radius := 6.0
@export var point_color := Color(0.95, 0.9, 0.8)
@export var base_offset := 8.0
@export var base_follow_strength := 14.0
@export var damping := 0.12
@export var aim_force := 28.0
@export var movement_force := 0.65
@export var crack_speed_threshold := 130.0
@export var crack_alignment_threshold := 0.8
@export var crack_impulse := 280.0
@export var crack_cooldown := 0.25

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var player: Node2D
var aim_direction := Vector2.RIGHT
var movement_velocity := Vector2.ZERO
var crack_timer := 0.0


func setup(player_node: Node2D) -> void:
	player = player_node
	_initialize_chain()


func set_control(aim_dir: Vector2, move_velocity: Vector2) -> void:
	if aim_dir != Vector2.ZERO:
		aim_direction = aim_dir
	movement_velocity = move_velocity


func _ready() -> void:
	if segment_count < 2:
		segment_count = 2
	_update_collision_shape()


func _physics_process(delta: float) -> void:
	if player == null:
		queue_free()
		return

	crack_timer = max(crack_timer - delta, 0.0)

	var aim_dir = aim_direction if aim_direction != Vector2.ZERO else Vector2.RIGHT
	var base_target = player.global_position + (aim_dir * base_offset)
	_integrate_points(delta, aim_dir)
	_anchor_base(base_target, delta)
	_apply_crack_impulse(aim_dir)
	_apply_constraints()
	_update_hitbox()
	queue_redraw()


func _integrate_points(delta: float, aim_dir: Vector2) -> void:
	var control_force = (aim_dir * aim_force) + (movement_velocity * movement_force)
	for i in range(1, points.size()):
		var current = points[i]
		var previous = previous_points[i]
		var velocity = (current - previous) * (1.0 - damping)
		previous_points[i] = current
		points[i] = current + velocity + (control_force * delta)


func _anchor_base(base_target: Vector2, delta: float) -> void:
	var base_position = points[0]
	points[0] = points[0].lerp(base_target, 1.0 - exp(-base_follow_strength * delta))
	previous_points[0] = base_position


func _apply_crack_impulse(aim_dir: Vector2) -> void:
	if movement_velocity.length() < crack_speed_threshold:
		return
	if crack_timer > 0.0:
		return
	var movement_dir = movement_velocity.normalized()
	var alignment = movement_dir.dot(aim_dir.normalized())
	if alignment < crack_alignment_threshold:
		return
	var tip_index = points.size() - 1
	points[tip_index] += aim_dir.normalized() * crack_impulse * get_physics_process_delta_time()
	crack_timer = crack_cooldown


func _apply_constraints() -> void:
	for _i in range(constraint_iterations):
		_apply_distance_constraints()
		_apply_angle_constraints()


func _apply_distance_constraints() -> void:
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		var delta = p2 - p1
		var distance = delta.length()
		if distance == 0.0:
			continue
		var diff = (distance - segment_length) / distance
		if i == 0:
			points[i + 1] -= delta * diff
		else:
			points[i] += delta * diff * 0.5
			points[i + 1] -= delta * diff * 0.5


func _apply_angle_constraints() -> void:
	if angle_limit_degrees <= 0.0:
		return
	var min_angle = deg_to_rad(180.0 - angle_limit_degrees)
	for i in range(1, points.size() - 1):
		var prev_point = points[i - 1]
		var current = points[i]
		var next_point = points[i + 1]
		var v1 = prev_point - current
		var v2 = next_point - current
		if v1 == Vector2.ZERO or v2 == Vector2.ZERO:
			continue
		var angle = v1.angle_to(v2)
		if angle >= min_angle:
			continue
		var correction = (min_angle - angle) * angle_stiffness
		var rotation_sign = signf(v1.cross(v2))
		if rotation_sign == 0.0:
			rotation_sign = 1.0
		var rotation = correction * rotation_sign
		var new_v1 = v1.normalized().rotated(-rotation * 0.5) * v1.length()
		var new_v2 = v2.normalized().rotated(rotation * 0.5) * v2.length()
		if i != 1:
			points[i - 1] = current + new_v1
		if i + 1 < points.size():
			points[i + 1] = current + new_v2


func _update_collision_shape() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is CircleShape2D:
		var circle = collision_shape.shape as CircleShape2D
		circle.radius = tip_radius


func _update_hitbox() -> void:
	if points.is_empty() or hitbox_component == null:
		return
	hitbox_component.position = to_local(points[points.size() - 1])


func _initialize_chain() -> void:
	points.clear()
	previous_points.clear()
	var start = player.global_position
	var direction = aim_direction if aim_direction != Vector2.ZERO else Vector2.RIGHT
	for i in range(segment_count):
		var position = start - (direction * segment_length * i)
		points.append(position)
		previous_points.append(position)
	_update_hitbox()
	queue_redraw()


func _draw() -> void:
	for point in points:
		draw_circle(to_local(point), point_radius, point_color)
	if points.size() >= 2:
		draw_circle(to_local(points[points.size() - 1]), tip_radius, point_color)
