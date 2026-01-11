extends CharacterBody2D
class_name BaseEnemy

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
const GHOST_POSSESSION_TINT := Color(0.2, 1.0, 0.6, 1.0)
const NAVIGATION_UPDATE_MIN := 0.4
const NAVIGATION_UPDATE_MAX := 0.7
const AIR_ENEMY_GROUP := "air_enemy"

@export var max_health := 10.0
@export var max_speed := 30.0
@export var acceleration := 5.0
@export var facing_multiplier := -1.0
@export var contact_damage := 1.0
@export var poison_contact_damage := 0.0

@onready var visuals: Node2D = get_node_or_null("Visuals")
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var dig_ability_controller = $Abilities/DigAbilityController
@onready var poison_spit_ability_controller = $Abilities/PoisonSpitAbilityController
@onready var mouse_sprite: AnimatedSprite2D = get_node_or_null("Visuals/mouse_sprite")
@onready var dragon_sprite: AnimatedSprite2D = get_node_or_null("Visuals/dragon_sprite")
@onready var rat_sprite: AnimatedSprite2D = get_node_or_null("Visuals/RatSprite")
@onready var spider_sprite: AnimatedSprite2D = get_node_or_null("Visuals/SpiderSprite")
@onready var ghost_sprite: AnimatedSprite2D = get_node_or_null("Visuals/GhostSprite")
@onready var scorpion_sprite: AnimatedSprite2D = get_node_or_null("Visuals/ScorpionSprite")
@onready var wasp_sprite: AnimatedSprite2D = get_node_or_null("Visuals/WaspSprite")
@onready var mouse_color: ColorRect = get_node_or_null("Visuals/mouse_sprite/enemy_color")
@onready var dragon_color: ColorRect = get_node_or_null("Visuals/dragon_sprite/enemy_color")
@onready var rat_color: ColorRect = get_node_or_null("Visuals/RatSprite/enemy_color")
@onready var spider_color: ColorRect = get_node_or_null("Visuals/SpiderSprite/enemy_color")
@onready var ghost_color: ColorRect = get_node_or_null("Visuals/GhostSprite/enemy_color")
@onready var scorpion_color: ColorRect = get_node_or_null("Visuals/ScorpionSprite/enemy_color")
@onready var wasp_color: ColorRect = get_node_or_null("Visuals/WaspSprite/enemy_color")

var enemy_tint := Color.WHITE
var is_elite := false
var size_multiplier := 1.0
var is_possessed := false
var possessed_time_left := 0.0
var possessed_original_stats: Dictionary = {}
var next_navigation_update_time := 0.0
var navigation_rng := RandomNumberGenerator.new()

func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	assign_elite_status()
	apply_enemy_stats()
	apply_elite_stats()
	apply_random_tint()
	update_visual_scale()
	navigation_rng.randomize()
	_schedule_next_navigation_update()
	GameEvents.debug_mode_toggled.connect(_on_debug_mode_toggled)
	_on_debug_mode_toggled(GameEvents.debug_mode_enabled)


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_enemy_stats() -> void:
	velocity_component.max_speed = max_speed
	velocity_component.acceleration = acceleration
	navigation_agent.max_speed = velocity_component.max_speed

	health_component.max_health = max_health
	health_component.current_health = max_health


func set_active_sprite(active_sprite: CanvasItem) -> void:
	if active_sprite == null:
		return
	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = active_sprite


func set_sprite_visibility(visible_sprite: CanvasItem) -> void:
	for sprite in [mouse_sprite, dragon_sprite, rat_sprite, spider_sprite, ghost_sprite, scorpion_sprite, wasp_sprite]:
		if sprite == null:
			continue
		sprite.visible = sprite == visible_sprite


func update_visual_facing() -> void:
	var move_sign = sign(velocity.x)
	if move_sign != 0:
		if visuals != null:
			visuals.scale = Vector2(move_sign * facing_multiplier * size_multiplier, size_multiplier)


func accelerate_to_player_with_pathfinding() -> void:
	var target_player := velocity_component.cached_player
	if target_player == null:
		velocity_component.refresh_target_player(global_position)
		target_player = velocity_component.cached_player
	if target_player == null:
		return

	if is_in_group(AIR_ENEMY_GROUP) or GameEvents.navigation_debug_disabled or navigation_agent == null:
		var direct_direction = target_player.global_position - global_position
		if direct_direction.length_squared() <= 0.001:
			return
		velocity_component.accelerate_in_direction(direct_direction.normalized())
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now >= next_navigation_update_time:
		navigation_agent.target_position = target_player.global_position
		_schedule_next_navigation_update()
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = next_path_position - global_position
	if direction.length_squared() <= 0.001:
		direction = target_player.global_position - global_position
	if direction.length_squared() <= 0.001:
		return
	velocity_component.accelerate_in_direction(direction.normalized())


func _schedule_next_navigation_update() -> void:
	var interval = navigation_rng.randf_range(NAVIGATION_UPDATE_MIN, NAVIGATION_UPDATE_MAX)
	next_navigation_update_time = (Time.get_ticks_msec() / 1000.0) + interval


func apply_enemy_separation() -> void:
	var separation_distance := SEPARATION_RADIUS * 2.0
	var separation_force := Vector2.ZERO
	var is_air_enemy := is_in_group(AIR_ENEMY_GROUP)

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_is_air := enemy_node.is_in_group(AIR_ENEMY_GROUP)
		if is_air_enemy != enemy_is_air:
			continue
		var offset = global_position - enemy_node.global_position
		var distance = offset.length()
		if distance == 0.0 or distance >= separation_distance:
			continue
		var push_strength = (separation_distance - distance) / separation_distance
		separation_force += offset.normalized() * push_strength

	if separation_force != Vector2.ZERO:
		velocity_component.velocity += separation_force.normalized() * SEPARATION_PUSH_STRENGTH


func apply_random_tint() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tint_value := ELITE_TINT_VALUE if is_elite else STANDARD_TINT_VALUE
	enemy_tint = Color.from_hsv(rng.randf(), 0.25, tint_value, 1.0)
	apply_enemy_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, dragon_color, rat_color, spider_color, ghost_color, scorpion_color, wasp_color]:
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
	update_visual_scale()


func _on_debug_mode_toggled(enabled: bool) -> void:
	if navigation_agent != null:
		navigation_agent.debug_enabled = enabled


func apply_dig_level() -> void:
	if is_elite:
		dig_ability_controller.set_dig_level(2)
	else:
		dig_ability_controller.set_dig_level(1)


func update_visual_scale() -> void:
	if visuals != null:
		visuals.scale = Vector2(facing_multiplier * size_multiplier, size_multiplier)


func can_be_possessed() -> bool:
	return not is_possessed


func is_invulnerable() -> bool:
	return false


func configure_air_enemy() -> void:
	add_to_group(AIR_ENEMY_GROUP)
	collision_layer = 8
	collision_mask = 0


func start_enemy_possession(duration: float) -> void:
	if is_possessed:
		return
	is_possessed = true
	possessed_time_left = duration
	possessed_original_stats = {
		"is_elite": is_elite,
		"size_multiplier": size_multiplier,
		"max_speed": velocity_component.max_speed,
		"acceleration": velocity_component.acceleration,
		"max_health": health_component.max_health,
		"current_health": health_component.current_health,
		"contact_damage": contact_damage,
		"enemy_tint": enemy_tint
	}
	if not is_elite:
		is_elite = true
		size_multiplier = ELITE_SCALE
		velocity_component.max_speed *= ELITE_SPEED_MULTIPLIER
		velocity_component.acceleration *= ELITE_ACCELERATION_MULTIPLIER
		navigation_agent.max_speed = velocity_component.max_speed
		health_component.max_health *= ELITE_HEALTH_MULTIPLIER
		health_component.current_health = min(health_component.current_health, health_component.max_health)
		contact_damage *= ELITE_DAMAGE_MULTIPLIER
	enemy_tint = GHOST_POSSESSION_TINT
	apply_enemy_tint()
	update_visual_scale()


func update_possession_timer(delta: float) -> void:
	if not is_possessed:
		return
	possessed_time_left = max(possessed_time_left - delta, 0.0)
	if possessed_time_left <= 0.0:
		end_enemy_possession()


func end_enemy_possession() -> void:
	if not is_possessed:
		return
	is_possessed = false
	if not possessed_original_stats.is_empty():
		is_elite = bool(possessed_original_stats.get("is_elite", false))
		size_multiplier = float(possessed_original_stats.get("size_multiplier", 1.0))
		velocity_component.max_speed = float(possessed_original_stats.get("max_speed", velocity_component.max_speed))
		velocity_component.acceleration = float(possessed_original_stats.get("acceleration", velocity_component.acceleration))
		navigation_agent.max_speed = velocity_component.max_speed
		health_component.max_health = float(possessed_original_stats.get("max_health", health_component.max_health))
		health_component.current_health = float(possessed_original_stats.get("current_health", health_component.current_health))
		contact_damage = float(possessed_original_stats.get("contact_damage", contact_damage))
		enemy_tint = possessed_original_stats.get("enemy_tint", enemy_tint)
	apply_enemy_tint()
	update_visual_scale()
