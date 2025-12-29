extends CharacterBody2D

const ENEMY_TYPES = {
	0: {
		"max_health": 10.0,
		"max_speed": 30,
		"acceleration": 5.0,
		"facing_multiplier": -1
	},
	1: {
		"max_health": 10.0,
		"max_speed": 45,
		"acceleration": 2.0,
		"facing_multiplier": 1
	},
	2: {
		"max_health": 50.0,
		"max_speed": 105,
		"acceleration": 1.5,
		"facing_multiplier": -1
	},
	3: {
		"max_health": 35.0,
		"max_speed": 20,
		"acceleration": 4.0,
		"facing_multiplier": 1
	}
}

@export var enemy_index := 0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var mouse_sprite: AnimatedSprite2D = $Visuals/mouse_sprite
@onready var wizard_sprite: AnimatedSprite2D = $Visuals/wizard_sprite
@onready var rat_sprite: Sprite2D = $Visuals/RatSprite
@onready var mouse_color: ColorRect = $Visuals/mouse_sprite/enemy_color
@onready var wizard_color: ColorRect = $Visuals/wizard_sprite/enemy_color
@onready var rat_color: ColorRect = $Visuals/RatSprite/enemy_color
@onready var worm_sprite: Sprite2D = $Visuals/WormSprite
@onready var worm_color: ColorRect = $Visuals/WormSprite/enemy_color
@onready var rat_texture: Texture2D = rat_sprite.texture

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var worm_direction := Vector2.RIGHT
var worm_turn_timer := 0.0
var worm_turn_interval := 1.5
var worm_rng := RandomNumberGenerator.new()


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	apply_random_tint()


func _physics_process(delta):
	if enemy_index == 3:
		update_worm_movement(delta)
		return

	velocity_component.accelerate_to_player()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign * facing_multiplier, 1)


func apply_enemy_type(index: int) -> void:
	enemy_index = index
	var enemy_data = ENEMY_TYPES.get(enemy_index, ENEMY_TYPES[0])

	facing_multiplier = enemy_data["facing_multiplier"]
	velocity_component.max_speed = enemy_data["max_speed"]
	velocity_component.acceleration = enemy_data["acceleration"]

	health_component.max_health = enemy_data["max_health"]
	health_component.current_health = enemy_data["max_health"]

	mouse_sprite.visible = enemy_index == 0
	wizard_sprite.visible = enemy_index == 1
	rat_sprite.visible = enemy_index == 2
	worm_sprite.visible = enemy_index == 3
	fireball_ability_controller.set_active(enemy_index == 1)

	rat_sprite.texture = rat_texture

	var active_sprite: CanvasItem = mouse_sprite
	if enemy_index == 1:
		active_sprite = wizard_sprite
	elif enemy_index == 2:
		active_sprite = rat_sprite
	elif enemy_index == 3:
		active_sprite = worm_sprite

	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = rat_sprite
	update_collision_profile()
	initialize_worm_state()


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	enemy_tint = Color.from_hsv(rng.randf(), .25, 1.0, 1.0)
	apply_enemy_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, wizard_color, rat_color, worm_color]:
		if tint_rect == null:
			continue
		tint_rect.color = enemy_tint
		tint_rect.visible = true


func update_worm_movement(delta: float) -> void:
	worm_turn_timer += delta
	if worm_turn_timer >= worm_turn_interval:
		worm_turn_timer = 0.0
		worm_turn_interval = worm_rng.randf_range(0.8, 1.6)
		var turn_direction = 1 if worm_rng.randi_range(0, 1) == 0 else -1
		worm_direction = worm_direction.rotated(deg_to_rad(90 * turn_direction)).normalized()

	velocity_component.accelerate_in_direction(worm_direction)
	velocity_component.move(self)

	if worm_direction.x != 0:
		visuals.scale = Vector2(sign(worm_direction.x) * facing_multiplier, 1)


func update_collision_profile() -> void:
	if enemy_index == 3:
		collision_layer = 1
		collision_mask = 9
	else:
		collision_layer = 8
		collision_mask = 9


func initialize_worm_state() -> void:
	if enemy_index != 3:
		return
	worm_rng.randomize()
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	worm_direction = directions[worm_rng.randi_range(0, directions.size() - 1)]
	worm_turn_interval = worm_rng.randf_range(0.8, 1.6)
	worm_turn_timer = worm_rng.randf_range(0.0, worm_turn_interval)
