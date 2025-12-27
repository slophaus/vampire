extends Node2D
class_name SpellAbility

const SPEED := 450.0

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0


func _ready():
	animation_player.stop()
	sprite.scale = Vector2.ONE
	collision_shape.disabled = false


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var movement = direction * SPEED * delta
	global_position += movement
	distance_traveled += movement.length()

	if distance_traveled >= max_distance:
		queue_free()


func setup(start_position: Vector2, target_position: Vector2, range_limit: float) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	rotation = direction.angle() + (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0
