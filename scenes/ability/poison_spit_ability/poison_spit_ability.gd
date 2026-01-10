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
var last_hit_target: Node2D
var poison_duration := 2.5
var owner_actor: Node2D


func _ready():
	animated_sprite.play()
	collision_shape.disabled = false
	if hitbox_component.penetration <= 0:
		hitbox_component.penetration = BASE_PENETRATION
	hitbox_component.hit_landed.connect(on_hit_landed)
	hitbox_component.area_entered.connect(on_area_entered)
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
	rotation = direction.angle() - (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if last_hit_target != null:
		apply_poison(last_hit_target)
	if hit_count >= hitbox_component.penetration:
		queue_free()


func on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox_component = area as HurtboxComponent
		var parent_node = hurtbox_component.get_parent() as Node2D
		if parent_node != null:
			last_hit_target = parent_node


func on_body_entered(body: Node) -> void:
	if body is Node2D and body.is_in_group(target_group):
		last_hit_target = body as Node2D


func apply_poison(target: Node2D) -> void:
	if target == null:
		return
	var poison_component = target.get_node_or_null("PoisonComponent") as PoisonComponent
	if poison_component == null:
		return
	poison_component.apply_poison(poison_duration)
