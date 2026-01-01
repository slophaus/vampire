extends Node2D
class_name SwordAbility

const SPEED := 450.0
const BASE_PENETRATION := 3
const WORM_COLLISION_LAYER := 1
const PLAYER_ATTACK_LAYER := 4
const ENEMY_ATTACK_LAYER := 8

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D
@export var dust_poof_scene: PackedScene

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0
var hit_count := 0


func _ready():
	animation_player.stop()
	sprite.scale = Vector2.ONE
	collision_shape.disabled = false
	hitbox_component.collision_mask = WORM_COLLISION_LAYER | PLAYER_ATTACK_LAYER | ENEMY_ATTACK_LAYER
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
		despawn()


func setup(start_position: Vector2, target_position: Vector2, range_limit: float) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	rotation = direction.angle() + (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= hitbox_component.penetration:
		despawn()


func on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("worm"):
		despawn()


func on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		var parent_node = area.get_parent()
		if parent_node is FireballAbility:
			(parent_node as FireballAbility).explode()


func despawn() -> void:
	spawn_dust()
	queue_free()


func spawn_dust() -> void:
	if dust_poof_scene == null:
		return

	var dust_instance = dust_poof_scene.instantiate() as GPUParticles2D
	if dust_instance == null:
		return

	dust_instance.global_position = global_position
	dust_instance.emitting = true
	dust_instance.finished.connect(dust_instance.queue_free)
	get_tree().current_scene.add_child(dust_instance)
