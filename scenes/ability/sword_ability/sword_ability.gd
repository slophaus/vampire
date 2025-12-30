extends Node2D
class_name SwordAbility

const SPEED := 450.0
const MAX_HITS := 3
const WORM_COLLISION_LAYER := 1

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0
var hit_count := 0


func _ready():
	animation_player.stop()
	sprite.scale = Vector2.ONE
	collision_shape.disabled = false
	hitbox_component.collision_mask = WORM_COLLISION_LAYER
	hitbox_component.hit_landed.connect(on_hit_landed)
	hitbox_component.body_entered.connect(on_body_entered)


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


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= MAX_HITS:
		queue_free()


func on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("worm"):
		queue_free()
