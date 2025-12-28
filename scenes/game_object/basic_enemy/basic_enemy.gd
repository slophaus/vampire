extends CharacterBody2D

const ENEMY_TYPES = {
	0: {
		"max_health": 10.0,
		"max_speed": 30,
		"acceleration": 5.0,
		"facing_multiplier": -1
	},
	1: {
		"max_health": 30.0,
		"max_speed": 45,
		"acceleration": 2.0,
		"facing_multiplier": 1
	},
	2: {
		"max_health": 50.0,
		"max_speed": 105,
		"acceleration": 1.5,
		"facing_multiplier": -1
	}
}

@export var enemy_index := 0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var sword_ability_controller = $Abilities/SwordAbilityController
@onready var mouse_sprite: AnimatedSprite2D = $Visuals/mouse_sprite
@onready var wizard_sprite: AnimatedSprite2D = $Visuals/wizard_sprite
@onready var rat_sprite: Sprite2D = $Visuals/RatSprite
@onready var rat_texture: Texture2D = rat_sprite.texture

var facing_multiplier := -1


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	apply_random_tint()


func _physics_process(delta):
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
	sword_ability_controller.set_active(enemy_index == 1)

	rat_sprite.texture = rat_texture

	var active_sprite: CanvasItem = mouse_sprite
	if enemy_index == 1:
		active_sprite = wizard_sprite
	elif enemy_index == 2:
		active_sprite = rat_sprite

	hit_flash_component.set_sprite(active_sprite)
	death_component.sprite = rat_sprite


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	visuals.modulate = Color.from_hsv(rng.randf(), 0.2, 1.0)
