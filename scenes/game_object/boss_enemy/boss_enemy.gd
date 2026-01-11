extends CharacterBody2D

const MAX_HEALTH := 150.0
const MAX_SPEED := 50
const ACCELERATION := 4.0
const FACING_MULTIPLIER := 1
const CONTACT_DAMAGE := 5.0

const SEPARATION_RADIUS := 15.0
const SEPARATION_PUSH_STRENGTH := 5.0
const MINION_SPAWN_COUNT := 4
const MINION_SPAWN_RADIUS := 32.0
@export var minion_scene: PackedScene = preload("res://scenes/game_object/basic_enemy/dragon_enemy.tscn")
@export var minion_spawn_interval_range := Vector2(6.0, 10.0)
@export var explosion_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
@export var boss_explosion_duration_multiplier := 5.0
@export var experience_vial_scene: PackedScene = preload("res://scenes/game_object/experience_vial/experience_vial.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/game_object/health_pickup/health_pickup.tscn")
@export var experience_vial_count := 5
@export var experience_vial_drop_radius := 24.0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HealthBar
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var sword_ability_controller = $Abilities/SwordAbilityController
@onready var minion_spawn_timer: Timer = $MinionSpawnTimer
@onready var dragon_sprite: AnimatedSprite2D = $Visuals/dragon_sprite

var facing_multiplier := -1
var contact_damage := CONTACT_DAMAGE

func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_stats()
	fireball_ability_controller.fireball_level = 3
	fireball_ability_controller.set_active(true)
	sword_ability_controller.sword_level = 1
	sword_ability_controller.set_active(true)
	health_component.health_changed.connect(update_health_display)
	health_component.died.connect(on_died)
	update_health_display()
	minion_spawn_timer.timeout.connect(on_minion_spawn_timer_timeout)
	schedule_next_minion_spawn()


func _physics_process(delta):
	velocity_component.accelerate_to_player()
	apply_enemy_separation()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign * facing_multiplier, 1)


func apply_enemy_separation() -> void:
	var separation_distance := SEPARATION_RADIUS * 2.0
	var separation_force := Vector2.ZERO

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var offset = global_position - enemy_node.global_position
		var distance = offset.length()
		if distance == 0.0 or distance >= separation_distance:
			continue
		var push_strength = (separation_distance - distance) / separation_distance
		separation_force += offset.normalized() * push_strength

	if separation_force != Vector2.ZERO:
		velocity_component.velocity += separation_force.normalized() * SEPARATION_PUSH_STRENGTH


func apply_enemy_stats() -> void:
	facing_multiplier = FACING_MULTIPLIER
	velocity_component.max_speed = MAX_SPEED
	velocity_component.acceleration = ACCELERATION

	health_component.max_health = MAX_HEALTH
	health_component.current_health = MAX_HEALTH
	contact_damage = CONTACT_DAMAGE

	dragon_sprite.visible = true
	hit_flash_component.set_sprite(dragon_sprite)
	death_component.sprite = dragon_sprite


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func update_health_display() -> void:
	if health_bar == null:
		return
	health_bar.value = health_component.get_health_percent()


func on_died() -> void:
	spawn_explosion()
	spawn_boss_drops()


func spawn_explosion() -> void:
	if explosion_scene == null:
		return
	var explosion_instance = explosion_scene.instantiate() as GPUParticles2D
	if explosion_instance == null:
		return
	explosion_instance.lifetime *= boss_explosion_duration_multiplier
	explosion_instance.global_position = global_position
	explosion_instance.emitting = true
	explosion_instance.finished.connect(explosion_instance.queue_free)
	var tree := get_tree()
	if tree == null:
		return
	var effects_layer = tree.get_first_node_in_group("effects_layer")
	var spawn_parent = effects_layer if effects_layer != null else tree.current_scene
	if spawn_parent == null:
		return
	spawn_parent.add_child(explosion_instance)


func spawn_boss_drops() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var vials_layer = tree.get_first_node_in_group("vials_layer")
	var spawn_parent: Node = vials_layer if vials_layer != null else get_parent()
	if spawn_parent == null:
		return
	if health_pickup_scene != null:
		var health_pickup = health_pickup_scene.instantiate() as Node2D
		if health_pickup != null:
			spawn_parent.add_child(health_pickup)
			health_pickup.global_position = global_position
	if experience_vial_scene == null or experience_vial_count <= 0:
		return
	for i in range(experience_vial_count):
		var vial = experience_vial_scene.instantiate() as Node2D
		if vial == null:
			continue
		spawn_parent.add_child(vial)
		var angle = TAU * float(i) / float(experience_vial_count)
		var offset = Vector2(cos(angle), sin(angle)) * experience_vial_drop_radius
		vial.global_position = global_position + offset


func on_minion_spawn_timer_timeout() -> void:
	spawn_minions()
	schedule_next_minion_spawn()


func schedule_next_minion_spawn() -> void:
	if minion_spawn_timer == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var min_interval = minion_spawn_interval_range.x
	var max_interval = max(minion_spawn_interval_range.x, minion_spawn_interval_range.y)
	minion_spawn_timer.wait_time = rng.randf_range(min_interval, max_interval)
	minion_spawn_timer.start()


func spawn_minions() -> void:
	if minion_scene == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var entities_layer = tree.get_first_node_in_group("entities_layer")
	var spawn_parent: Node = entities_layer if entities_layer != null else get_parent()
	if spawn_parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(MINION_SPAWN_COUNT):
		var minion = minion_scene.instantiate() as Node2D
		spawn_parent.add_child(minion)
		var angle = rng.randf_range(0.0, TAU)
		var offset = Vector2(cos(angle), sin(angle)) * MINION_SPAWN_RADIUS
		minion.global_position = global_position + offset
