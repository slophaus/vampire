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
@export var enemy_index := 0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var dig_ability_controller = $Abilities/DigAbilityController
@onready var mouse_sprite: AnimatedSprite2D = $Visuals/mouse_sprite
@onready var wizard_sprite: AnimatedSprite2D = $Visuals/wizard_sprite
@onready var rat_sprite: Sprite2D = $Visuals/RatSprite
@onready var mouse_color: ColorRect = $Visuals/mouse_sprite/enemy_color
@onready var wizard_color: ColorRect = $Visuals/wizard_sprite/enemy_color
@onready var rat_color: ColorRect = $Visuals/RatSprite/enemy_color
@onready var rat_texture: Texture2D = rat_sprite.texture

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := 1.0
var mouse_has_dig_level_two := false
func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	assign_mouse_dig_level()
	apply_enemy_tint_for_type()


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


func apply_enemy_type(index: int) -> void:
	enemy_index = index
	var enemy_data = ENEMY_TYPES.get(enemy_index, ENEMY_TYPES[0])

	facing_multiplier = enemy_data["facing_multiplier"]
	velocity_component.max_speed = enemy_data["max_speed"]
	velocity_component.acceleration = enemy_data["acceleration"]

	health_component.max_health = enemy_data["max_health"]
	health_component.current_health = enemy_data["max_health"]
	contact_damage = enemy_data["contact_damage"]

	mouse_sprite.visible = enemy_index == 0
	wizard_sprite.visible = enemy_index == 1
	rat_sprite.visible = enemy_index == 2
	fireball_ability_controller.set_active(enemy_index == 1)
	dig_ability_controller.set_active(enemy_index == 0)

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
	enemy_tint = Color.from_hsv(rng.randf(), .25, 1.0, 1.0)
	apply_enemy_tint()

func apply_enemy_tint_for_type() -> void:
	if enemy_index == 0 and mouse_has_dig_level_two:
		enemy_tint = MOUSE_DIG_LEVEL_TWO_TINT
		apply_enemy_tint()
		return
	apply_random_tint()


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, wizard_color, rat_color]:
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
