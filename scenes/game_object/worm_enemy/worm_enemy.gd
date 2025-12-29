extends CharacterBody2D

const TILE_SIZE := 16.0
const MOVE_INTERVAL := 0.25
const TURN_CHANCE := 0.3

@export var turn_delay := 3.0

@onready var segment_container := $Visuals/Segments
@onready var collision_container := self
@onready var hurtbox_segments := $HurtboxComponent

var move_timer := 0.0
var segment_positions: Array[Vector2] = []
var direction := Vector2.RIGHT
var segment_sprites: Array[Sprite2D] = []
var segment_shapes: Array[CollisionShape2D] = []
var hurtbox_shapes: Array[CollisionShape2D] = []
var segment_count := 0
var time_alive := 0.0


func _ready() -> void:
	randomize()
	cache_segments()
	initialize_direction()
	initialize_segments()


func _physics_process(delta: float) -> void:
	time_alive += delta
	move_timer += delta
	if move_timer < MOVE_INTERVAL:
		return
	move_timer -= MOVE_INTERVAL

	maybe_turn()
	advance_segments()
	update_segments()


func cache_segments() -> void:
	segment_sprites.clear()
	segment_shapes.clear()
	hurtbox_shapes.clear()

	for child in segment_container.get_children():
		if child is Sprite2D:
			segment_sprites.append(child)
	for child in collision_container.get_children():
		if child is CollisionShape2D:
			segment_shapes.append(child)
	for child in hurtbox_segments.get_children():
		if child is CollisionShape2D:
			hurtbox_shapes.append(child)

	segment_count = min(segment_sprites.size(), min(segment_shapes.size(), hurtbox_shapes.size()))


func initialize_direction() -> void:
	var scene_center = get_scene_center()
	var to_center = scene_center - global_position

	if to_center == Vector2.ZERO:
		direction = Vector2.RIGHT
		return

	if abs(to_center.x) > abs(to_center.y):
		direction = Vector2(sign(to_center.x), 0)
	else:
		direction = Vector2(0, sign(to_center.y))


func initialize_segments() -> void:
	segment_positions.clear()

	for index in range(segment_count):
		segment_positions.append(global_position - (direction * TILE_SIZE * index))

	update_segments()


func maybe_turn() -> void:
	if time_alive < turn_delay:
		return
	if randf() > TURN_CHANCE:
		return
	var left = Vector2(-direction.y, direction.x)
	var right = Vector2(direction.y, -direction.x)
	direction = left if randf() < 0.5 else right


func advance_segments() -> void:
	if segment_positions.is_empty():
		return
	var new_head = segment_positions[0] + (direction * TILE_SIZE)
	segment_positions.insert(0, new_head)
	segment_positions.pop_back()
	global_position = new_head


func update_segments() -> void:
	for index in range(segment_count):
		var local_position = segment_positions[index] - global_position
		segment_sprites[index].position = local_position
		segment_shapes[index].position = local_position
		hurtbox_shapes[index].position = local_position


func get_scene_center() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_screen_center_position()
	return Vector2.ZERO
