extends CharacterBody2D

const ENEMY_TYPES = {
	0: {
		"max_health": 150.0,
		"max_speed": 70,
		"acceleration": 2.5,
		"facing_multiplier": 1,
		"contact_damage": 4
	},
	1: {
		"max_health": 150.0,
		"max_speed": 70,
		"acceleration": 2.5,
		"facing_multiplier": 1,
		"contact_damage": 5
	},
	2: {
		"max_health": 150.0,
		"max_speed": 70,
		"acceleration": 2.5,
		"facing_multiplier": 1,
		"contact_damage": 4
	}
}

const SEPARATION_RADIUS := 15.0
const SEPARATION_PUSH_STRENGTH := 5.0
const MOUSE_DIG_LEVEL_TWO_TINT := Color(0.25, 0.25, 1)
const MINION_SPAWN_COUNT := 4
const MINION_SPAWN_RADIUS := 32.0
@export var enemy_index := 1
@export var minion_scene: PackedScene = preload("res://scenes/game_object/basic_enemy/basic_enemy.tscn")
@export var minion_spawn_interval_range := Vector2(6.0, 10.0)

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HealthBar
@onready var hit_flash_component = $HitFlashComponent
@onready var death_component = $DeathComponent
@onready var fireball_ability_controller = $Abilities/FireballAbilityController
@onready var dig_ability_controller = $Abilities/DigAbilityController
@onready var sword_ability_controller = $Abilities/SwordAbilityController
@onready var minion_spawn_timer: Timer = $MinionSpawnTimer
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
func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	fireball_ability_controller.fireball_level = 3
	sword_ability_controller.sword_level = 2
	assign_mouse_dig_level()
	apply_enemy_tint_for_type()
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
	dragon_sprite.visible = enemy_index == 1
	rat_sprite.visible = enemy_index == 2
	fireball_ability_controller.set_active(enemy_index == 1)
	dig_ability_controller.set_active(enemy_index == 0)
	sword_ability_controller.set_active(enemy_index == 1)
	if enemy_index == 1:
		schedule_next_minion_spawn()
	else:
		minion_spawn_timer.stop()

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
	enemy_tint = Color.from_hsv(rng.randf(), .25, 1.0, 1.0)
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


func update_health_display() -> void:
	if health_bar == null:
		return
	health_bar.value = health_component.get_health_percent()


func on_minion_spawn_timer_timeout() -> void:
	if enemy_index != 1:
		return
	spawn_minions()
	schedule_next_minion_spawn()


func schedule_next_minion_spawn() -> void:
	if minion_spawn_timer == null or enemy_index != 1:
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
