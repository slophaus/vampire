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
	}
}

const SEPARATION_RADIUS := 15.0
const SEPARATION_PUSH_STRENGTH := 5.0
const MOUSE_DIG_LEVEL_TWO_TINT := Color(0.25, 0.25, 1)
const ELITE_CHANCE := 0.1
const ELITE_SCALE_MULTIPLIER := 1.35
const ELITE_SPEED_MULTIPLIER := 1.35
const ELITE_ACCELERATION_MULTIPLIER := 1.35
const ELITE_HEALTH_MULTIPLIER := 1.6
const ELITE_DAMAGE_MULTIPLIER := 1.5
const ELITE_TINT_BRIGHTNESS := 0.6
const BASE_TINT_BRIGHTNESS := 1.0
const DRAGON_ENEMY_INDEX := 1
const RAT_ENEMY_INDEX := 2
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
@onready var mouse_color: ColorRect = $Visuals/mouse_sprite/enemy_color
@onready var dragon_color: ColorRect = $Visuals/dragon_sprite/enemy_color
@onready var rat_color: ColorRect = $Visuals/RatSprite/enemy_color
@onready var rat_texture: Texture2D = rat_sprite.texture

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := 1.0
var mouse_has_dig_level_two := false
var is_elite := false
var visual_scale_multiplier := 1.0
func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	assign_mouse_dig_level()
	assign_elite_status()
	apply_elite_modifiers()
	apply_enemy_tint_for_type()
	visuals.scale = Vector2(facing_multiplier, 1) * visual_scale_multiplier


func _physics_process(delta):
	if enemy_index == RAT_ENEMY_INDEX or enemy_index == DRAGON_ENEMY_INDEX:
		accelerate_to_player_with_pathfinding()
	else:
		velocity_component.accelerate_to_player()
	apply_enemy_separation()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign * facing_multiplier, 1) * visual_scale_multiplier


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

	mouse_sprite.visible = enemy_index == 0
	dragon_sprite.visible = enemy_index == 1
	rat_sprite.visible = enemy_index == 2
	fireball_ability_controller.set_active(enemy_index == 1)
	dig_ability_controller.set_active(enemy_index == 0)

	rat_sprite.texture = rat_texture

	var active_sprite: CanvasItem = mouse_sprite
	if enemy_index == 1:
		active_sprite = dragon_sprite
	elif enemy_index == 2:
		active_sprite = rat_sprite

	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = active_sprite


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var brightness = ELITE_TINT_BRIGHTNESS if is_elite else BASE_TINT_BRIGHTNESS
	var saturation = 0.35 if is_elite else 0.25
	enemy_tint = Color.from_hsv(rng.randf(), saturation, brightness, 1.0)
	apply_enemy_tint()

func apply_enemy_tint_for_type() -> void:
	if enemy_index == 0 and mouse_has_dig_level_two:
		enemy_tint = MOUSE_DIG_LEVEL_TWO_TINT
		apply_enemy_tint()
		return
	apply_random_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, dragon_color, rat_color]:
		if tint_rect == null:
			continue
		tint_rect.color = enemy_tint
		tint_rect.visible = true


func assign_mouse_dig_level() -> void:
	if enemy_index != 0:
		mouse_has_dig_level_two = false
		dig_ability_controller.set_dig_level(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	mouse_has_dig_level_two = rng.randf() < 0.1
	dig_ability_controller.set_dig_level(2 if mouse_has_dig_level_two else 1)


func assign_elite_status() -> void:
	if enemy_index == 0:
		is_elite = mouse_has_dig_level_two
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	is_elite = rng.randf() < ELITE_CHANCE


func apply_elite_modifiers() -> void:
	if not is_elite:
		visual_scale_multiplier = 1.0
		return
	visual_scale_multiplier = ELITE_SCALE_MULTIPLIER
	velocity_component.max_speed *= ELITE_SPEED_MULTIPLIER
	velocity_component.acceleration *= ELITE_ACCELERATION_MULTIPLIER
	navigation_agent.max_speed = velocity_component.max_speed
	health_component.max_health *= ELITE_HEALTH_MULTIPLIER
	health_component.current_health = health_component.max_health
	contact_damage *= ELITE_DAMAGE_MULTIPLIER
