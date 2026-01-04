extends CharacterBody2D

const ENEMY_TYPES = {
	0: {
		"max_health": 10.0,
		"max_speed": 30,
		"acceleration": 5.0,
		"facing_multiplier": -1,
		"contact_damage": 1
	},
	1: {
		"max_health": 10.0,
		"max_speed": 45,
		"acceleration": 2.0,
		"facing_multiplier": 1,
		"contact_damage": 1
	},
	2: {
		"max_health": 37.5,
		"max_speed": 105,
		"acceleration": 1.5,
		"facing_multiplier": -1,
		"contact_damage": 2
	},
	4: {
		"max_health": 6.0,
		"max_speed": 160,
		"acceleration": 10.0,
		"facing_multiplier": -1,
		"contact_damage": 1,
		"poison_contact_duration": 20.0
	}
}

const SEPARATION_RADIUS := 15.0
const SEPARATION_PUSH_STRENGTH := 5.0
const ELITE_CHANCE := 0.1
const ELITE_SCALE := 1.25
const ELITE_SPEED_MULTIPLIER := 1.25
const ELITE_ACCELERATION_MULTIPLIER := 1.2
const ELITE_HEALTH_MULTIPLIER := 1.5
const ELITE_DAMAGE_MULTIPLIER := 1.5
const ELITE_TINT_VALUE := 0.6
const STANDARD_TINT_VALUE := 1.0
const DRAGON_ENEMY_INDEX := 1
const RAT_ENEMY_INDEX := 2
const SPIDER_ENEMY_INDEX := 4
const SPIDER_BURST_DURATION := 0.3
const SPIDER_REST_DURATION := 1.2
const SPIDER_STOP_DECELERATION := 600.0
const SPIDER_JUMP_RANGE := 150.0
const SPIDER_JUMP_COOLDOWN := 1.1
const SPIDER_JUMP_FORCE := 400.0
@export var enemy_index := 0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var dig_ability_controller = $Abilities/DigAbilityController
@onready var mouse_sprite: AnimatedSprite2D = $Visuals/mouse_sprite
@onready var dragon_sprite: AnimatedSprite2D = $Visuals/dragon_sprite
@onready var rat_sprite: Sprite2D = $Visuals/RatSprite
@onready var spider_sprite: Sprite2D = $Visuals/SpiderSprite
@onready var mouse_color: ColorRect = $Visuals/mouse_sprite/enemy_color
@onready var dragon_color: ColorRect = $Visuals/dragon_sprite/enemy_color
@onready var rat_color: ColorRect = $Visuals/RatSprite/enemy_color
@onready var spider_color: ColorRect = $Visuals/SpiderSprite/enemy_color
@onready var rat_texture: Texture2D = rat_sprite.texture

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := 1.0
var poison_contact_duration := 0.0
var is_elite := false
var size_multiplier := 1.0
var spider_burst_time_left := 0.0
var spider_rest_time_left := 0.0
var spider_jump_cooldown := 0.0
func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	assign_elite_status()
	apply_enemy_type(enemy_index)
	apply_elite_stats()
	apply_random_tint()
	visuals.scale = Vector2(facing_multiplier * size_multiplier, size_multiplier)


func _physics_process(delta):
	if enemy_index == SPIDER_ENEMY_INDEX:
		update_spider_movement(delta)
	elif enemy_index == RAT_ENEMY_INDEX or enemy_index == DRAGON_ENEMY_INDEX:
		accelerate_to_player_with_pathfinding()
	else:
		velocity_component.accelerate_to_player()
	apply_enemy_separation()
	velocity_component.move(self)

	update_visual_facing()


func update_visual_facing() -> void:
	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign * facing_multiplier * size_multiplier, size_multiplier)


func update_spider_movement(delta: float) -> void:
	spider_jump_cooldown = max(spider_jump_cooldown - delta, 0.0)
	if spider_rest_time_left > 0.0:
		spider_rest_time_left = max(spider_rest_time_left - delta, 0.0)
		velocity_component.velocity = velocity_component.velocity.move_toward(
			Vector2.ZERO,
			SPIDER_STOP_DECELERATION * delta
		)
		return

	if spider_burst_time_left > 0.0:
		spider_burst_time_left = max(spider_burst_time_left - delta, 0.0)
		accelerate_to_player_with_pathfinding()
		if spider_burst_time_left <= 0.0:
			spider_rest_time_left = SPIDER_REST_DURATION
		return

	start_spider_burst()

func start_spider_burst() -> void:
	var target_player := velocity_component.cached_player
	if target_player == null:
		velocity_component.refresh_target_player(global_position)
		target_player = velocity_component.cached_player
	if target_player == null:
		spider_burst_time_left = SPIDER_BURST_DURATION
		return
	if can_spider_jump(target_player):
		var direction = (target_player.global_position - global_position).normalized()
		velocity_component.apply_knockback(direction, SPIDER_JUMP_FORCE)
		spider_jump_cooldown = SPIDER_JUMP_COOLDOWN
		spider_rest_time_left = SPIDER_REST_DURATION
		return
	spider_burst_time_left = SPIDER_BURST_DURATION


func can_spider_jump(target_player: Node2D) -> bool:
	if spider_jump_cooldown > 0.0:
		return false
	return global_position.distance_to(target_player.global_position) <= SPIDER_JUMP_RANGE


func accelerate_to_player_with_pathfinding() -> void:
	var target_player := velocity_component.cached_player
	if target_player == null:
		velocity_component.refresh_target_player(global_position)
		target_player = velocity_component.cached_player
	if target_player == null:
		return

	navigation_agent.target_position = target_player.global_position
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = next_path_position - global_position
	if direction.length_squared() <= 0.001:
		direction = target_player.global_position - global_position
	if direction.length_squared() <= 0.001:
		return
	velocity_component.accelerate_in_direction(direction.normalized())


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


func apply_enemy_type(index: int) -> void:
	enemy_index = index
	var enemy_data = ENEMY_TYPES.get(enemy_index, ENEMY_TYPES[0])

	facing_multiplier = enemy_data["facing_multiplier"]
	velocity_component.max_speed = enemy_data["max_speed"]
	velocity_component.acceleration = enemy_data["acceleration"]
	navigation_agent.max_speed = velocity_component.max_speed

	health_component.max_health = enemy_data["max_health"]
	health_component.current_health = enemy_data["max_health"]
	contact_damage = enemy_data["contact_damage"]
	poison_contact_duration = enemy_data.get("poison_contact_duration", 0.0)

	mouse_sprite.visible = enemy_index == 0
	dragon_sprite.visible = enemy_index == 1
	rat_sprite.visible = enemy_index == 2
	spider_sprite.visible = enemy_index == SPIDER_ENEMY_INDEX
	fireball_ability_controller.set_active(enemy_index == 1)
	dig_ability_controller.set_active(enemy_index == 0)
	apply_dig_level()

	rat_sprite.texture = rat_texture

	var active_sprite: CanvasItem = mouse_sprite
	if enemy_index == 1:
		active_sprite = dragon_sprite
	elif enemy_index == 2:
		active_sprite = rat_sprite
	elif enemy_index == SPIDER_ENEMY_INDEX:
		active_sprite = spider_sprite

	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = active_sprite


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tint_value := ELITE_TINT_VALUE if is_elite else STANDARD_TINT_VALUE
	enemy_tint = Color.from_hsv(rng.randf(), 0.25, tint_value, 1.0)
	apply_enemy_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, dragon_color, rat_color, spider_color]:
		if tint_rect == null:
			continue
		tint_rect.color = enemy_tint
		tint_rect.visible = true


func assign_elite_status() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	is_elite = rng.randf() < ELITE_CHANCE
	size_multiplier = ELITE_SCALE if is_elite else 1.0


func apply_elite_stats() -> void:
	if not is_elite:
		return
	velocity_component.max_speed *= ELITE_SPEED_MULTIPLIER
	velocity_component.acceleration *= ELITE_ACCELERATION_MULTIPLIER
	navigation_agent.max_speed = velocity_component.max_speed
	health_component.max_health *= ELITE_HEALTH_MULTIPLIER
	health_component.current_health = health_component.max_health
	contact_damage *= ELITE_DAMAGE_MULTIPLIER


func apply_dig_level() -> void:
	if enemy_index == 0 and is_elite:
		dig_ability_controller.set_dig_level(2)
	else:
		dig_ability_controller.set_dig_level(1)
