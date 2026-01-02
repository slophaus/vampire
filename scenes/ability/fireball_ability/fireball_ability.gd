extends Node2D
class_name FireballAbility

const SPEED := 150.0
const BASE_PENETRATION := 1
const BASE_SPLASH_RADIUS := 48.0
const SPLASH_STROKE_WIDTH := 2.0
const SPLASH_ARC_POINTS := 48
const SPLASH_COLOR := Color(1.0, 0.45, 0.2, 0.5)
const SPLASH_VISUAL_DURATION := 0.15

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D
@export var explosion_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
@export var dust_poof_scene: PackedScene = preload("res://scenes/vfx/poof.tscn")

var direction := Vector2.ZERO
var max_distance := 0.0
var distance_traveled := 0.0
var hit_count := 0
var target_group := "enemy"
var has_exploded := false
var last_hit_target: Node2D
var show_splash_indicator := false
var splash_radius_bonus := 0.0
var owner_actor: Node2D


func _ready():
	animated_sprite.play()
	collision_shape.disabled = false
	queue_redraw()
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
		spawn_dust()
		queue_free()


func setup(start_position: Vector2, target_position: Vector2, range_limit: float) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	rotation = direction.angle() - (PI / 2.0)
	max_distance = range_limit
	distance_traveled = 0.0
	show_splash_indicator = false


func refresh_splash_visual() -> void:
	queue_redraw()


func _draw() -> void:
	if not show_splash_indicator:
		return
	var splash_radius = (BASE_SPLASH_RADIUS * scale.x) + splash_radius_bonus
	draw_arc(Vector2.ZERO, splash_radius, 0.0, TAU, SPLASH_ARC_POINTS, SPLASH_COLOR, SPLASH_STROKE_WIDTH)


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= hitbox_component.penetration:
		explode(last_hit_target)


func on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox_component = area as HurtboxComponent
		var parent_node = hurtbox_component.get_parent() as Node2D
		if parent_node != null:
			last_hit_target = parent_node


func on_body_entered(body: Node) -> void:
	if body is Node2D and body.is_in_group(target_group):
		last_hit_target = body as Node2D


func explode(excluded_target: Node2D = null) -> void:
	if has_exploded:
		return
	has_exploded = true
	spawn_explosion()
	show_splash_indicator = true
	direction = Vector2.ZERO
	collision_shape.disabled = true
	refresh_splash_visual()

	var splash_radius = (BASE_SPLASH_RADIUS * scale.x) + splash_radius_bonus
	var splash_radius_squared = pow(splash_radius, 2)
	var splash_targets: Array = []
	splash_targets.append_array(get_tree().get_nodes_in_group("player"))
	splash_targets.append_array(get_tree().get_nodes_in_group("enemy"))
	for target in splash_targets:
		if target == null or not is_instance_valid(target):
			continue
		if owner_actor != null and owner_actor.is_in_group("player") and target == owner_actor:
			continue
		if target == excluded_target:
			continue
		if target.get("is_regenerating") == true:
			continue
		var target_node = target as Node2D
		if target_node == null:
			continue
		if target_node.global_position.distance_squared_to(global_position) > splash_radius_squared:
			continue
		apply_splash_damage(target_node)

	await get_tree().create_timer(SPLASH_VISUAL_DURATION).timeout
	queue_free()


func spawn_explosion() -> void:
	if explosion_scene == null:
		return
	var explosion_instance = explosion_scene.instantiate() as GPUParticles2D
	if explosion_instance == null:
		return
	explosion_instance.global_position = global_position
	explosion_instance.emitting = true
	explosion_instance.finished.connect(explosion_instance.queue_free)
	get_tree().current_scene.add_child(explosion_instance)


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


func apply_splash_damage(target: Node2D) -> void:
	var hurtbox_component = target.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox_component != null and hurtbox_component.health_component != null:
		var splash_hitbox := HitboxComponent.new()
		splash_hitbox.damage = hitbox_component.damage
		splash_hitbox.knockback = hitbox_component.knockback
		splash_hitbox.global_position = global_position
		hurtbox_component.on_area_entered(splash_hitbox)
		return

	var health_component = target.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		return

	health_component.damage(hitbox_component.damage)

	var velocity_component = target.get_node_or_null("VelocityComponent") as VelocityComponent
	if velocity_component == null or hitbox_component.knockback <= 0:
		return

	var knockback_direction = (target.global_position - global_position).normalized()
	velocity_component.apply_knockback(knockback_direction, hitbox_component.knockback)
