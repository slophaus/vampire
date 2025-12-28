extends Node2D
class_name BoomerangAbility

const SPEED := 210.0
const MAX_HITS := 10
const RETURN_DISTANCE := 24.0
const SPIN_SPEED := 10.0

@onready var hitbox_component := $HitboxComponent

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0
var return_distance_traveled := 0.0
var returning := false
var source_player: Node2D
var hit_count := 0


func _ready():
	hitbox_component.hit_landed.connect(on_hit_landed)


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	rotation += SPIN_SPEED * delta

	var target_speed := SPEED

	if returning:
		var player = source_player
		if player == null:
			queue_free()
			return
		var desired_direction = (player.global_position - global_position).normalized()
		direction = direction.lerp(desired_direction, 6.0 * delta).normalized()
		if global_position.distance_to(player.global_position) <= RETURN_DISTANCE:
			queue_free()
			return
		return_distance_traveled += SPEED * delta
		var return_progress = clamp(return_distance_traveled / max_distance, 0.0, 1.0)
		target_speed = SPEED * sin(PI * return_progress)
	else:
		var travel_progress = clamp(distance_traveled / max_distance, 0.0, 1.0)
		target_speed = SPEED * cos((PI / 2.0) * travel_progress)

	var movement = direction * target_speed * delta
	global_position += movement

	if not returning:
		distance_traveled += movement.length()
		if distance_traveled >= max_distance:
			returning = true
			return_distance_traveled = 0.0


func setup(start_position: Vector2, target_position: Vector2, range_limit: float, player: Node2D) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	rotation = direction.angle() + (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0
	return_distance_traveled = 0.0
	returning = false
	source_player = player


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= MAX_HITS:
		queue_free()
