extends CharacterBody2D

const MAX_HEALTH := 150.0
const MAX_SPEED := 70.0
const ACCELERATION := 2.5
const FACING_MULTIPLIER := 1
const CONTACT_DAMAGE := 5.0

const SEPARATION_RADIUS := 15.0
const SEPARATION_PUSH_STRENGTH := 5.0
const MINION_SPAWN_COUNT := 4
const MINION_SPAWN_RADIUS := 32.0
@export var minion_scene: PackedScene = preload("res://scenes/game_object/basic_enemy/basic_enemy.tscn")
@export var minion_spawn_interval_range := Vector2(6.0, 10.0)

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HealthBar
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var minion_spawn_timer: Timer = $MinionSpawnTimer
@onready var dragon_sprite: AnimatedSprite2D = $Visuals/dragon_sprite
@onready var dragon_color: ColorRect = $Visuals/dragon_sprite/enemy_color

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := CONTACT_DAMAGE

func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_stats()
	fireball_ability_controller.fireball_level = 3
	fireball_ability_controller.set_active(true)
	apply_random_tint()
	health_component.health_changed.connect(update_health_display)
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


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	enemy_tint = Color.from_hsv(rng.randf(), .25, 1.0, 1.0)
	apply_enemy_tint()


func apply_enemy_tint() -> void:
	if dragon_color == null:
		return
	dragon_color.color = enemy_tint
	dragon_color.visible = true


func update_health_display() -> void:
	if health_bar == null:
		return
	health_bar.value = health_component.get_health_percent()


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
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	var spawn_parent: Node = entities_layer if entities_layer != null else get_parent()
	if spawn_parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(MINION_SPAWN_COUNT):
		var minion = minion_scene.instantiate() as Node2D
		minion.set("enemy_index", 1)
		spawn_parent.add_child(minion)
		var angle = rng.randf_range(0.0, TAU)
		var offset = Vector2(cos(angle), sin(angle)) * MINION_SPAWN_RADIUS
		minion.global_position = global_position + offset
