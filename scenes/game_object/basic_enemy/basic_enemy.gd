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
	},
	5: {
		"max_health": 8.0,
		"max_speed": 28,
		"acceleration": 3.0,
		"facing_multiplier": -1,
		"contact_damage": 0
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
const GHOST_ENEMY_INDEX := 5
const SPIDER_BURST_DURATION := 0.3
const SPIDER_REST_DURATION := 1.2
const SPIDER_STOP_DECELERATION := 600.0
const SPIDER_JUMP_RANGE := 150.0
const SPIDER_JUMP_COOLDOWN := 1.1
const SPIDER_JUMP_FORCE := 400.0
const GHOST_WANDER_MIN_DURATION := 1.2
const GHOST_WANDER_MAX_DURATION := 2.4
const GHOST_FADE_SPEED := 1.0
const GHOST_POSSESSION_RADIUS := 28.0
const GHOST_POSSESSION_SEEK_RADIUS := 200.0
const GHOST_POSSESSION_DURATION := 8.0
const GHOST_POSSESSION_COOLDOWN := 1.0
const GHOST_POSSESSION_TINT := Color(0.2, 1.0, 0.6, 1.0)
const GHOST_OFFSCREEN_RESPAWN_DELAY := 2.5
const GHOST_RESPAWN_FADE_SPEED := 1.5
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
@onready var rat_sprite: AnimatedSprite2D = $Visuals/RatSprite
@onready var spider_sprite: Sprite2D = $Visuals/SpiderSprite
@onready var ghost_sprite: AnimatedSprite2D = $Visuals/GhostSprite
@onready var mouse_color: ColorRect = $Visuals/mouse_sprite/enemy_color
@onready var dragon_color: ColorRect = $Visuals/dragon_sprite/enemy_color
@onready var rat_color: ColorRect = $Visuals/RatSprite/enemy_color
@onready var spider_color: ColorRect = $Visuals/SpiderSprite/enemy_color
@onready var ghost_color: ColorRect = $Visuals/GhostSprite/enemy_color

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := 1.0
var poison_contact_duration := 0.0
var is_elite := false
var size_multiplier := 1.0
var spider_burst_time_left := 0.0
var spider_rest_time_left := 0.0
var spider_jump_cooldown := 0.0
var ghost_wander_time_left := 0.0
var ghost_wander_direction := Vector2.ZERO
var ghost_fade_time := 0.0
var ghost_offscreen_time := 0.0
var ghost_respawn_fade := 1.0
var ghost_possession_target: Node2D
var ghost_possession_time_left := 0.0
var ghost_possession_cooldown := 0.0
var is_possessed := false
var possessed_time_left := 0.0
var possessed_original_stats: Dictionary = {}
func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	assign_elite_status()
	apply_enemy_type(enemy_index)
	apply_elite_stats()
	apply_random_tint()
	update_visual_scale()


func _physics_process(delta):
	if enemy_index == GHOST_ENEMY_INDEX:
		update_ghost_state(delta)
	else:
		if enemy_index == SPIDER_ENEMY_INDEX:
			update_spider_movement(delta)
		elif enemy_index == RAT_ENEMY_INDEX or enemy_index == DRAGON_ENEMY_INDEX:
			accelerate_to_player_with_pathfinding()
		else:
			velocity_component.accelerate_to_player()
		apply_enemy_separation()
		velocity_component.move(self)
		update_visual_facing()
	update_possession_timer(delta)


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
	if enemy_index == GHOST_ENEMY_INDEX:
		return
	var separation_distance := SEPARATION_RADIUS * 2.0
	var separation_force := Vector2.ZERO

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if enemy.is_in_group("ghost"):
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
	ghost_sprite.visible = enemy_index == GHOST_ENEMY_INDEX
	fireball_ability_controller.set_active(enemy_index == 1)
	dig_ability_controller.set_active(enemy_index == 0)
	apply_dig_level()

	var active_sprite: CanvasItem = mouse_sprite
	if enemy_index == 1:
		active_sprite = dragon_sprite
	elif enemy_index == 2:
		active_sprite = rat_sprite
	elif enemy_index == SPIDER_ENEMY_INDEX:
		active_sprite = spider_sprite
	elif enemy_index == GHOST_ENEMY_INDEX:
		active_sprite = ghost_sprite

	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = active_sprite
	update_ghost_flags()
	update_visual_scale()


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tint_value := ELITE_TINT_VALUE if is_elite else STANDARD_TINT_VALUE
	enemy_tint = Color.from_hsv(rng.randf(), 0.25, tint_value, 1.0)
	apply_enemy_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, dragon_color, rat_color, spider_color, ghost_color]:
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


func apply_dig_level() -> void:
	if enemy_index == 0 and is_elite:
		dig_ability_controller.set_dig_level(2)
	else:
		dig_ability_controller.set_dig_level(1)


func update_ghost_state(delta: float) -> void:
	update_ghost_fade(delta)
	ghost_possession_cooldown = max(ghost_possession_cooldown - delta, 0.0)
	if ghost_possession_target != null:
		if not is_instance_valid(ghost_possession_target):
			end_ghost_possession(true, true)
			return
		ghost_possession_time_left = max(ghost_possession_time_left - delta, 0.0)
		global_position = ghost_possession_target.global_position
		if ghost_possession_time_left <= 0.0:
			end_ghost_possession()
		return

	update_ghost_offscreen(delta)
	if ghost_possession_cooldown > 0.0:
		update_ghost_wander(delta)
		velocity_component.move(self)
		update_visual_facing()
		return

	if try_start_ghost_possession():
		return

	update_ghost_seek(delta)
	velocity_component.move(self)
	update_visual_facing()


func update_ghost_fade(delta: float) -> void:
	if ghost_sprite == null:
		return
	if ghost_possession_target != null:
		visuals.modulate.a = 0.0
		return
	ghost_fade_time += delta * GHOST_FADE_SPEED
	var alpha = 0.3 + (sin(ghost_fade_time) * 0.3)
	if ghost_respawn_fade < 1.0:
		ghost_respawn_fade = min(ghost_respawn_fade + (delta * GHOST_RESPAWN_FADE_SPEED), 1.0)
	visuals.modulate.a = alpha * ghost_respawn_fade


func update_ghost_offscreen(delta: float) -> void:
	var view_rect := get_camera_view_rect()
	if view_rect.has_point(global_position):
		ghost_offscreen_time = 0.0
		return
	ghost_offscreen_time += delta
	if ghost_offscreen_time < GHOST_OFFSCREEN_RESPAWN_DELAY:
		return
	respawn_ghost_on_screen(view_rect)
	ghost_offscreen_time = 0.0


func respawn_ghost_on_screen(view_rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn_x = rng.randf_range(view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var spawn_y = rng.randf_range(view_rect.position.y, view_rect.position.y + view_rect.size.y)
	global_position = Vector2(spawn_x, spawn_y)
	ghost_fade_time = 0.0
	ghost_respawn_fade = 0.0


func get_camera_view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, viewport_size)
	var half_size := viewport_size * camera.zoom * 0.5
	var min_position := camera.global_position - half_size
	return Rect2(min_position, half_size * 2.0)


func update_ghost_wander(delta: float) -> void:
	ghost_wander_time_left = max(ghost_wander_time_left - delta, 0.0)
	if ghost_wander_time_left <= 0.0 or ghost_wander_direction == Vector2.ZERO:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var angle = rng.randf_range(0.0, TAU)
		ghost_wander_direction = Vector2(cos(angle), sin(angle))
		ghost_wander_time_left = rng.randf_range(GHOST_WANDER_MIN_DURATION, GHOST_WANDER_MAX_DURATION)
	velocity_component.accelerate_in_direction(ghost_wander_direction)

func update_ghost_seek(delta: float) -> void:
	var target = find_nearby_possession_target(GHOST_POSSESSION_SEEK_RADIUS)
	if target != null:
		var direction = target.global_position - global_position
		if direction.length_squared() > 0.001:
			velocity_component.accelerate_in_direction(direction.normalized())
		return
	update_ghost_wander(delta)


func try_start_ghost_possession() -> bool:
	if ghost_possession_cooldown > 0.0:
		return false
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= GHOST_POSSESSION_RADIUS:
		if player.has_method("start_ghost_possession"):
			player.call("start_ghost_possession", GHOST_POSSESSION_DURATION, velocity_component.max_speed)
			start_ghost_possession(player, GHOST_POSSESSION_DURATION)
			return true

	var nearest_enemy = find_nearby_enemy_to_possess()
	if nearest_enemy != null:
		nearest_enemy.call("start_enemy_possession", GHOST_POSSESSION_DURATION)
		start_ghost_possession(nearest_enemy, GHOST_POSSESSION_DURATION)
		return true
	return false


func find_nearby_enemy_to_possess() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance := GHOST_POSSESSION_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if enemy.is_in_group("ghost"):
			continue
		if enemy.has_method("can_be_possessed") and not enemy.call("can_be_possessed"):
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var distance = global_position.distance_to(enemy_node.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	return closest_enemy


func find_nearby_possession_target(radius: float) -> Node2D:
	var closest_target: Node2D
	var closest_distance := radius
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("start_ghost_possession"):
		var distance = global_position.distance_to(player.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_target = player

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if enemy.is_in_group("ghost"):
			continue
		if enemy.has_method("can_be_possessed") and not enemy.call("can_be_possessed"):
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_distance = global_position.distance_to(enemy_node.global_position)
		if enemy_distance <= closest_distance:
			closest_distance = enemy_distance
			closest_target = enemy_node
	return closest_target


func start_ghost_possession(target: Node2D, duration: float) -> void:
	ghost_possession_target = target
	ghost_possession_time_left = duration
	visuals.modulate.a = 0.0
	ghost_offscreen_time = 0.0


func end_ghost_possession(force_peak_visibility: bool = false, start_cooldown: bool = false) -> void:
	ghost_possession_target = null
	ghost_possession_time_left = 0.0
	if start_cooldown:
		ghost_possession_cooldown = GHOST_POSSESSION_COOLDOWN
	respawn_ghost_on_screen(get_camera_view_rect())
	ghost_offscreen_time = 0.0
	if force_peak_visibility:
		ghost_fade_time = PI * 0.5
		ghost_respawn_fade = 1.0
		update_ghost_fade(0.0)


func update_ghost_flags() -> void:
	if enemy_index == GHOST_ENEMY_INDEX:
		if not is_in_group("ghost"):
			add_to_group("ghost")
		collision_layer = 0
		collision_mask = 0
	else:
		if is_in_group("ghost"):
			remove_from_group("ghost")
		collision_layer = 8
		collision_mask = 9
	visuals.modulate = Color(1, 1, 1, 1)


func update_visual_scale() -> void:
	visuals.scale = Vector2(facing_multiplier * size_multiplier, size_multiplier)


func can_be_possessed() -> bool:
	return enemy_index != GHOST_ENEMY_INDEX and not is_possessed


func is_invulnerable() -> bool:
	return enemy_index == GHOST_ENEMY_INDEX and ghost_possession_target != null


func start_enemy_possession(duration: float) -> void:
	if enemy_index == GHOST_ENEMY_INDEX or is_possessed:
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
