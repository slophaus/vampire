extends Node2D
class_name PoisonSpitAbility

const SPEED := 200.0
const BASE_PENETRATION := 1

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0
var hit_count := 0
var target_group := "enemy"
var owner_actor: Node2D


func _ready():
	animated_sprite.play()
	animated_sprite.modulate = Color(0.3, 1, 0.3)
	collision_shape.disabled = false
	if hitbox_component.penetration <= 0:
		hitbox_component.penetration = BASE_PENETRATION
	hitbox_component.hit_landed.connect(on_hit_landed)


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
	rotation = direction.angle() - (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= hitbox_component.penetration:
		queue_free()
