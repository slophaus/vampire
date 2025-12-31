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
const DIRT_ATLAS_X := 0
const DIRT_ATLAS_Y_RANGE := 2
const WALL_ATLAS_X_RANGE := Vector2i(1, 3)
const WALL_ATLAS_Y_RANGE := 2

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
@onready var rat_texture: Texture2D = rat_sprite.texture
@onready var arena_tilemap := _find_arena_tilemap()

var facing_multiplier := -1
var enemy_tint := Color.WHITE
var contact_damage := 1.0
var walkable_tile_source_id := -1
var walkable_tile_atlas := Vector2i.ZERO
var walkable_tile_alternative := 0


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_enemy_type(enemy_index)
	apply_random_tint()
	cache_walkable_tile()


func _physics_process(delta):
	velocity_component.accelerate_to_player()
	apply_enemy_separation()
	velocity_component.move(self)
	if enemy_index == 0:
		convert_dirt_at_position(global_position)

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


func apply_enemy_tint() -> void:
	for tint_rect in [mouse_color, wizard_color, rat_color]:
		if tint_rect == null:
			continue
		tint_rect.color = enemy_tint
		tint_rect.visible = true


func _find_arena_tilemap() -> TileMap:
	for node in get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			return tilemap
	return null


func cache_walkable_tile() -> void:
	if arena_tilemap == null:
		return
	var sample_position := global_position
	for player in get_tree().get_nodes_in_group("player"):
		var player_node := player as Node2D
		if player_node != null:
			sample_position = player_node.global_position
			break
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(sample_position))
	var source_id = arena_tilemap.get_cell_source_id(0, cell)
	if source_id == -1:
		return
	walkable_tile_source_id = source_id
	walkable_tile_atlas = arena_tilemap.get_cell_atlas_coords(0, cell)
	walkable_tile_alternative = arena_tilemap.get_cell_alternative_tile(0, cell)


func convert_dirt_at_position(position: Vector2) -> void:
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
	var source_id = arena_tilemap.get_cell_source_id(0, cell)
	if source_id == -1:
		return
	if source_id == walkable_tile_source_id:
		if arena_tilemap.get_cell_atlas_coords(0, cell) == walkable_tile_atlas \
				and arena_tilemap.get_cell_alternative_tile(0, cell) == walkable_tile_alternative:
			return
	var atlas_coords := arena_tilemap.get_cell_atlas_coords(0, cell)
	if not _is_dirt_tile(atlas_coords):
		return
	if _is_wall_tile(atlas_coords):
		return
	var tile_data := arena_tilemap.get_cell_tile_data(0, cell)
	if tile_data == null:
		return
	if tile_data.get_collision_polygons_count(0) <= 0:
		return
	arena_tilemap.set_cell(0, cell, walkable_tile_source_id, walkable_tile_atlas, walkable_tile_alternative)


func _is_dirt_tile(atlas_coords: Vector2i) -> bool:
	return atlas_coords.x == DIRT_ATLAS_X and atlas_coords.y >= 0 and atlas_coords.y <= DIRT_ATLAS_Y_RANGE


func _is_wall_tile(atlas_coords: Vector2i) -> bool:
	return atlas_coords.x >= WALL_ATLAS_X_RANGE.x and atlas_coords.x <= WALL_ATLAS_X_RANGE.y \
		and atlas_coords.y >= 0 and atlas_coords.y <= WALL_ATLAS_Y_RANGE
