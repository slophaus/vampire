extends Node2D
class_name WhipAbility

@export var segment_count := 14
@export var segment_length := 16.0
@export var constraint_iterations := 6
@export var angle_limit_degrees := 150.0
@export var angle_correction_strength := 0.35
@export var point_radius := 2.8
@export var point_color := Color(1.0, 0.85, 0.4, 0.9)
@export var tip_follow_strength := 12.0
@export var point_damping := 0.92
@export var external_force_scale := 1.0

var anchor_position := Vector2.ZERO
var tip_target := Vector2.ZERO
var driver_velocity := Vector2.ZERO
var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []


func _ready() -> void:
	reset_chain(anchor_position)


func reset_chain(start_position: Vector2) -> void:
	points.clear()
	previous_points.clear()
	var count = max(segment_count, 2)
	var current = start_position
	for index in range(count):
		points.append(current)
		previous_points.append(current)
		current += Vector2.RIGHT * segment_length
	tip_target = current
	update()


func set_anchor_position(position: Vector2) -> void:
	anchor_position = position
	if points.is_empty():
		reset_chain(anchor_position)


func set_tip_target(position: Vector2) -> void:
	tip_target = position


func set_driver_velocity(velocity: Vector2) -> void:
	driver_velocity = velocity


func get_total_length() -> float:
	return float(max(segment_count - 1, 1)) * segment_length


func _physics_process(delta: float) -> void:
	if points.is_empty():
		reset_chain(anchor_position)
	points[0] = anchor_position
	previous_points[0] = anchor_position
	for index in range(1, points.size()):
		var current = points[index]
		var previous = previous_points[index]
		var velocity = (current - previous) * point_damping
		previous_points[index] = current
		points[index] = current + velocity
	var tip_index = points.size() - 1
	if tip_index >= 0:
		var to_target = tip_target - points[tip_index]
		points[tip_index] += to_target * tip_follow_strength * delta
		points[tip_index] += driver_velocity * external_force_scale * delta

	for _iteration in range(constraint_iterations):
		points[0] = anchor_position
		for index in range(1, points.size()):
			var prev_point = points[index - 1]
			var current_point = points[index]
			var delta_vec = current_point - prev_point
			var distance = delta_vec.length()
			if distance == 0:
				continue
			var correction = delta_vec * ((distance - segment_length) / distance)
			if index == 1:
				points[index] -= correction
			else:
				points[index] -= correction * 0.5
				points[index - 1] += correction * 0.5
		_apply_angle_constraints()

	update()


func _apply_angle_constraints() -> void:
	if points.size() < 3:
		return
	var min_angle = deg_to_rad(angle_limit_degrees)
	for index in range(1, points.size() - 1):
		var prev_point = points[index - 1]
		var current_point = points[index]
		var next_point = points[index + 1]
		var v1 = prev_point - current_point
		var v2 = next_point - current_point
		if v1 == Vector2.ZERO or v2 == Vector2.ZERO:
			continue
		var v1n = v1.normalized()
		var v2n = v2.normalized()
		var angle = acos(clamp(v1n.dot(v2n), -1.0, 1.0))
		if angle < min_angle:
			var cross = v1n.cross(v2n)
			var sign_direction = 1.0 if cross >= 0.0 else -1.0
			var desired_dir = v1n.rotated(sign_direction * min_angle)
			var desired_next = current_point + desired_dir * segment_length
			points[index + 1] = points[index + 1].lerp(desired_next, angle_correction_strength)


func _draw() -> void:
	for point in points:
		draw_circle(to_local(point), point_radius, point_color)
