extends CharacterBody2D

const ENEMY_MOUSE_INDEX := 0
const ENEMY_WIZARD_INDEX := 1

@export var enemy_index := ENEMY_MOUSE_INDEX : set = set_enemy_index
@export var mouse_sprite_frames: SpriteFrames
@export var wizard_sprite_frames: SpriteFrames
@export var mouse_texture: Texture2D
@export var wizard_texture: Texture2D

@onready var visuals := $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_collision: CollisionShape2D = $HurtboxComponent/CollisionShape2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var death_component: Node = $DeathComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var flip_multiplier := -1


func _ready():
	apply_enemy_definition()
	$HurtboxComponent.hit.connect(on_hit)
	apply_random_tint()


func _physics_process(delta):
	velocity_component.accelerate_to_player()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign * flip_multiplier, 1)


func set_enemy_index(value: int) -> void:
	enemy_index = value
	if is_inside_tree():
		apply_enemy_definition()


func apply_enemy_definition() -> void:
	if not is_inside_tree():
		return

	var definition = get_enemy_definition(enemy_index)
	if definition.is_empty():
		return

	health_component.max_health = definition.max_health
	health_component.current_health = definition.max_health
	velocity_component.max_speed = definition.max_speed
	velocity_component.acceleration = definition.acceleration
	flip_multiplier = definition.flip_multiplier

	sprite.texture = definition.sprite_texture
	sprite.visible = definition.sprite_visible
	sprite.offset = definition.sprite_offset

	animated_sprite.sprite_frames = definition.sprite_frames
	animated_sprite.position = definition.animated_position
	animated_sprite.play()

	var hurtbox_shape = hurtbox_collision.shape as CircleShape2D
	if hurtbox_shape != null:
		hurtbox_shape.radius = definition.hurtbox_radius
	hurtbox_collision.position = definition.hurtbox_position
	body_collision.position = definition.body_collision_position

	if animation_player != null:
		animation_player.stop()

	if death_component != null and death_component.has_method("set_sprite"):
		death_component.set_sprite(sprite)


func get_enemy_definition(index: int) -> Dictionary:
	match index:
		ENEMY_WIZARD_INDEX:
			return {
				"max_health": 30.0,
				"max_speed": 45,
				"acceleration": 2.0,
				"flip_multiplier": 1,
				"sprite_texture": wizard_texture,
				"sprite_visible": true,
				"sprite_offset": Vector2.ZERO,
				"sprite_frames": wizard_sprite_frames,
				"animated_position": Vector2(1, -12),
				"hurtbox_position": Vector2(0, 1),
				"hurtbox_radius": 8.0,
				"body_collision_position": Vector2(0, -2)
			}
		_:
			return {
				"max_health": 10.0,
				"max_speed": 30,
				"acceleration": 5.0,
				"flip_multiplier": -1,
				"sprite_texture": mouse_texture,
				"sprite_visible": false,
				"sprite_offset": Vector2(0, -4),
				"sprite_frames": mouse_sprite_frames,
				"animated_position": Vector2(2, -15),
				"hurtbox_position": Vector2(0, -5),
				"hurtbox_radius": 13.0384,
				"body_collision_position": Vector2(0, -10)
			}


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	visuals.modulate = Color.from_hsv(rng.randf(), 0.2, 1.0)
