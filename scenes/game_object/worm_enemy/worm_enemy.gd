extends CharacterBody2D

const SEGMENT_COUNT := 7
const TILE_SIZE := 16.0
const MOVE_INTERVAL := 0.25
const TURN_CHANCE := 0.3

@onready var visuals := $Visuals
@onready var hurtbox_component := $HurtboxComponent

var move_timer := 0.0
var segment_positions: Array[Vector2] = []
var direction := Vector2.RIGHT
var segment_sprites: Array[Sprite2D] = []
var segment_shapes: Array[CollisionShape2D] = []
var hurtbox_shapes: Array[CollisionShape2D] = []


func _ready() -> void:
	randomize()
	initialize_direction()
	initialize_segments()


func _physics_process(delta: float) -> void:
	move_timer += delta
	if move_timer < MOVE_INTERVAL:
		return
	move_timer -= MOVE_INTERVAL

	maybe_turn()
	advance_segments()
	update_segments()


func initialize_direction() -> void:
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	direction = directions[randi() % directions.size()]


func initialize_segments() -> void:
	segment_positions.clear()
	segment_sprites.clear()
	segment_shapes.clear()
	hurtbox_shapes.clear()

	for index in range(SEGMENT_COUNT):
		segment_positions.append(global_position - (direction * TILE_SIZE * index))

		var sprite = Sprite2D.new()
		sprite.texture = preload("res://sprites/fireball.png")
		sprite.modulate = Color(0.2, 1.0, 0.2, 1.0)
		visuals.add_child(sprite)
		segment_sprites.append(sprite)

		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(TILE_SIZE, TILE_SIZE)
		add_child(shape)
		segment_shapes.append(shape)

		var hurtbox_shape = CollisionShape2D.new()
		hurtbox_shape.shape = RectangleShape2D.new()
		hurtbox_shape.shape.size = Vector2(TILE_SIZE, TILE_SIZE)
		hurtbox_component.add_child(hurtbox_shape)
		hurtbox_shapes.append(hurtbox_shape)

	update_segments()


func maybe_turn() -> void:
	if randf() > TURN_CHANCE:
		return
	var left = Vector2(-direction.y, direction.x)
	var right = Vector2(direction.y, -direction.x)
	direction = left if randf() < 0.5 else right


func advance_segments() -> void:
	var new_head = segment_positions[0] + (direction * TILE_SIZE)
	segment_positions.insert(0, new_head)
	segment_positions.pop_back()
	global_position = new_head


func update_segments() -> void:
	for index in range(SEGMENT_COUNT):
		var local_position = segment_positions[index] - global_position
		segment_sprites[index].position = local_position
		segment_shapes[index].position = local_position
		hurtbox_shapes[index].position = local_position
