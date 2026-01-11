extends CharacterBody2D

const TILE_SIZE := 16.0
const MOVE_INTERVAL := 0.8
const TURN_CHANCE := 0.3
const SEGMENT_EXPLOSION_DELAY := 0.08
const WORM_EATABLE_TILE_TYPES: Array[String] = ["dirt", "wall"]
const EXPLOSION_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/impactMining_000.ogg"),
	preload("res://assets/audio/impactMining_001.ogg"),
	preload("res://assets/audio/impactMining_002.ogg"),
	preload("res://assets/audio/impactMining_003.ogg"),
	preload("res://assets/audio/impactMining_004.ogg"),
]

@export var turn_delay := 4.0
@export_range(1, 64, 1) var segment_count := 15
@export_range(1, 128, 1) var max_segment_count := 25
@export_range(0.5, 30.0, 0.5) var growth_interval := 6.0
@export var head_tint := Color(0.85, 0.35, 0.55, 1.0)
@export var body_tint := Color(1.0, 0.65, 0.8, 1.0)
@export var poof_scene: PackedScene = preload("res://scenes/vfx/poof.tscn")
@export var dormant_enabled := true
@export var dormant_wake_radius := 150.0
@export var dormant_wake_timer_seconds := 0.0

@onready var segment_container := $Visuals/Segments
@onready var collision_container := self
@onready var hurtbox_segments := $HurtboxComponent
@onready var hit_flash_component = $HitFlashComponent
@onready var head_template: Sprite2D = $Visuals/Segments/HeadPrototype
@onready var body_template: Sprite2D = $Visuals/Segments/BodyPrototype
@onready var turn_template: Sprite2D = $Visuals/Segments/TurnPrototype
@onready var collision_template: CollisionShape2D = $Segment0
@onready var hurtbox_template: CollisionShape2D = $HurtboxComponent/Segment0
@onready var health_component: HealthComponent = $HealthComponent
var tile_eater: TileEater

@onready var body_texture: Texture2D = body_template.texture
@onready var body_region_rect: Rect2 = body_template.region_rect
@onready var turn_texture: Texture2D = turn_template.texture

var move_timer := 0.0
var segment_positions: Array[Vector2] = []
var direction := Vector2.RIGHT
var segment_sprites: Array[Sprite2D] = []
var segment_shapes: Array[CollisionShape2D] = []
var hurtbox_shapes: Array[CollisionShape2D] = []
var segment_tints: Array = []
var time_alive := 0.0
var is_dying := false
var growth_timer := 0.0
var is_dormant := false
var dormant_timer_left := 0.0

func _ready() -> void:
	randomize()
	visible = false
	if health_component != null:
		health_component.free_owner_on_death = false
		health_component.died.connect(_on_died)
	if dormant_enabled:
		is_dormant = true
		dormant_timer_left = dormant_wake_timer_seconds
	call_deferred("_finish_spawn")


func _finish_spawn() -> void:
	build_segments()
	cache_segments()
	global_position = snap_to_grid(global_position)
	initialize_direction()
	initialize_segments()
	tile_eater = TileEater.new(self)
	tile_eater.cache_walkable_tile()
	_update_occupied_tiles()
	apply_segment_tints()
	apply_hit_flash()
	visible = true


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if update_dormant_state(delta):
		return
	time_alive += delta
	_update_growth(delta)
	move_timer += delta
	if move_timer < MOVE_INTERVAL:
		return
	move_timer -= MOVE_INTERVAL

	direction = choose_direction()
	var next_head = snap_to_grid(segment_positions[0] + (direction * TILE_SIZE))
	if did_collide_with_worm_at(next_head):
		_handle_collision_death()
		return
	advance_segments()
	update_segments()


func _update_growth(delta: float) -> void:
	if growth_interval <= 0.0:
		return
	if segment_count >= max_segment_count:
		return
	growth_timer += delta
	if growth_timer < growth_interval:
		return
	growth_timer -= growth_interval
	_grow_segment()


func _grow_segment() -> void:
	if segment_count >= max_segment_count:
		return
	var tail_position = global_position
	if not segment_positions.is_empty():
		tail_position = segment_positions[segment_positions.size() - 1]
	segment_positions.append(tail_position)

	if body_template != null and not body_template.visible:
		body_template.show()
		segment_sprites.append(body_template)
		segment_tints.append(body_template.get_node_or_null("segment_color"))
	else:
		var sprite = body_template.duplicate()
		sprite.name = "BodySegment%s" % segment_count
		segment_container.add_child(sprite)
		segment_sprites.append(sprite)
		segment_tints.append(sprite.get_node_or_null("segment_color"))

	var shape = collision_template.duplicate()
	shape.name = "Segment%s" % segment_count
	collision_container.add_child(shape)
	segment_shapes.append(shape)
	segment_count += 1
	_apply_segment_tint(segment_tints.size() - 1)
	update_segments()


func cache_segments() -> void:
	segment_sprites.clear()
	segment_shapes.clear()
	hurtbox_shapes.clear()
	segment_tints.clear()

	if head_template != null and not head_template.is_queued_for_deletion():
		segment_sprites.append(head_template)
		segment_tints.append(head_template.get_node_or_null("segment_color"))
	for child in segment_container.get_children():
		if child == head_template or child == turn_template:
			continue
		if child == body_template and not body_template.visible:
			continue
		if child is Sprite2D and not child.is_queued_for_deletion():
			segment_sprites.append(child)
			segment_tints.append(child.get_node_or_null("segment_color"))
	for child in collision_container.get_children():
		if child is CollisionShape2D and not child.is_queued_for_deletion():
			segment_shapes.append(child)
	for child in hurtbox_segments.get_children():
		if child is CollisionShape2D and not child.is_queued_for_deletion():
			hurtbox_shapes.append(child)
	segment_count = min(segment_sprites.size(), segment_shapes.size(), segment_count)


func build_segments() -> void:
	segment_count = max(segment_count, 1)

	for child in segment_container.get_children():
		if child != head_template and child != body_template and child is Sprite2D:
			child.queue_free()
	for child in collision_container.get_children():
		if child != collision_template and child is CollisionShape2D:
			child.queue_free()

	var body_count = max(segment_count - 1, 0)
	if body_count == 0:
		body_template.hide()
	else:
		body_template.show()
		for index in range(1, body_count):
			var sprite = body_template.duplicate()
			sprite.name = "BodySegment%s" % index
			segment_container.add_child(sprite)
	for index in range(1, segment_count):
		var shape = collision_template.duplicate()
		shape.name = "Segment%s" % index
		collision_container.add_child(shape)


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


func choose_direction() -> Vector2:
	if segment_positions.is_empty():
		return direction

	var forward = direction
	var left = Vector2(-direction.y, direction.x)
	var right = Vector2(direction.y, -direction.x)
	var backward = -direction

	var should_turn = time_alive >= turn_delay and randf() <= TURN_CHANCE
	var ordered: Array[Vector2] = []
	if should_turn:
		if randf() < 0.5:
			ordered = [left, right, forward]
		else:
			ordered = [right, left, forward]
	else:
		ordered = [forward, left, right]
	ordered.append(backward)

	for candidate in ordered:
		var candidate_position = segment_positions[0] + (candidate * TILE_SIZE)
		if is_position_blocked(candidate_position):
			continue
		if not is_position_adjacent_to_body(candidate_position):
			return candidate

	for candidate in ordered:
		var candidate_position = segment_positions[0] + (candidate * TILE_SIZE)
		if not is_position_blocked(candidate_position):
			return candidate

	return ordered[0]


func advance_segments() -> void:
	if segment_positions.is_empty():
		return
	var new_head = snap_to_grid(segment_positions[0] + (direction * TILE_SIZE))
	segment_positions.insert(0, new_head)
	segment_positions.pop_back()
	global_position = new_head
	if tile_eater != null:
		tile_eater.try_convert_tile(new_head, WORM_EATABLE_TILE_TYPES)


func update_segments() -> void:
	for index in range(segment_count):
		var local_position = segment_positions[index] - global_position
		var sprite := segment_sprites[index]
		sprite.position = local_position
		if index == 0:
			sprite.rotation = get_segment_rotation(index)
		elif is_turn_segment(index):
			sprite.texture = turn_texture
			sprite.region_enabled = false
			sprite.rotation = get_turn_rotation(index)
		else:
			sprite.texture = body_texture
			sprite.region_enabled = body_template.region_enabled
			if body_template.region_enabled:
				sprite.region_rect = body_region_rect
			sprite.rotation = get_segment_rotation(index)
		segment_shapes[index].position = local_position
		if index == 0 and not hurtbox_shapes.is_empty():
			hurtbox_shapes[0].position = local_position
	_update_occupied_tiles()


func update_dormant_state(delta: float) -> bool:
	if not dormant_enabled:
		return false
	if not is_dormant:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= dormant_wake_radius:
		wake_from_dormant()
		return false
	if dormant_wake_timer_seconds > 0.0:
		dormant_timer_left = max(dormant_timer_left - delta, 0.0)
		if dormant_timer_left <= 0.0:
			wake_from_dormant()
			return false
	return true


func wake_from_dormant() -> void:
	is_dormant = false


func set_spawned_awake() -> void:
	dormant_enabled = false
	is_dormant = false


func _update_occupied_tiles() -> void:
	if tile_eater == null:
		return
	tile_eater.update_occupied_tiles(segment_positions)


func apply_hit_flash() -> void:
	if hit_flash_component == null:
		return
	if segment_sprites.is_empty():
		return
	hit_flash_component.set_sprite(segment_sprites[0])


func apply_segment_tints() -> void:
	for index in range(segment_tints.size()):
		_apply_segment_tint(index)


func _apply_segment_tint(index: int) -> void:
	if index < 0 or index >= segment_tints.size():
		return
	var tint_rect: ColorRect = segment_tints[index]
	if tint_rect == null:
		return
	if index == 0:
		tint_rect.color = head_tint
	else:
		tint_rect.color = body_tint
	tint_rect.visible = true


func get_segment_rotation(index: int) -> float:
	var segment_direction := direction
	if index > 0 and index < segment_positions.size():
		var search_index = index
		while search_index > 0:
			var delta = segment_positions[search_index - 1] - segment_positions[search_index]
			if delta != Vector2.ZERO:
				segment_direction = delta.normalized()
				break
			search_index -= 1
	return segment_direction.angle() + (PI / 2.0)


func is_turn_segment(index: int) -> bool:
	if index <= 0 or index >= segment_positions.size() - 1:
		return false
	var previous = segment_positions[index - 1]
	var next = segment_positions[index + 1]
	return previous.x != next.x and previous.y != next.y


func get_turn_rotation(index: int) -> float:
	var previous = segment_positions[index - 1]
	var current = segment_positions[index]
	var next = segment_positions[index + 1]
	var in_dir = (previous - current).normalized()
	var out_dir = (next - current).normalized()

	if (in_dir == Vector2.UP and out_dir == Vector2.RIGHT) or (in_dir == Vector2.RIGHT and out_dir == Vector2.UP):
		return 0.0
	if (in_dir == Vector2.RIGHT and out_dir == Vector2.DOWN) or (in_dir == Vector2.DOWN and out_dir == Vector2.RIGHT):
		return PI / 2.0
	if (in_dir == Vector2.DOWN and out_dir == Vector2.LEFT) or (in_dir == Vector2.LEFT and out_dir == Vector2.DOWN):
		return PI
	if (in_dir == Vector2.LEFT and out_dir == Vector2.UP) or (in_dir == Vector2.UP and out_dir == Vector2.LEFT):
		return -PI / 2.0
	return 0.0


func get_scene_center() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_screen_center_position()
	return Vector2.ZERO


func snap_to_grid(world_position: Vector2) -> Vector2:
	var offset := Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	return (world_position - offset).snapped(Vector2(TILE_SIZE, TILE_SIZE)) + offset


func is_position_blocked(candidate_position: Vector2) -> bool:
	for occupied in segment_positions:
		if occupied == candidate_position:
			return true

	for worm in get_tree().get_nodes_in_group("worm"):
		if worm == self:
			continue
		if not worm.has_method("get_occupied_positions"):
			continue
		for occupied in worm.get_occupied_positions():
			if occupied == candidate_position:
				return true

	for player in get_tree().get_nodes_in_group("player"):
		var player_node := player as Node2D
		if player_node == null:
			continue
		if snap_to_grid(player_node.global_position) == candidate_position:
			return true

	return false


func is_position_adjacent_to_body(candidate_position: Vector2) -> bool:
	for index in range(1, segment_positions.size()):
		if is_adjacent(candidate_position, segment_positions[index]):
			return true

	for worm in get_tree().get_nodes_in_group("worm"):
		if worm == self:
			continue
		if not worm.has_method("get_occupied_positions"):
			continue
		for occupied in worm.get_occupied_positions():
			if is_adjacent(candidate_position, occupied):
				return true

	return false


func is_adjacent(a: Vector2, b: Vector2) -> bool:
	var delta = a - b
	return abs(delta.x) + abs(delta.y) == TILE_SIZE


func did_collide_with_worm() -> bool:
	if segment_positions.is_empty():
		return false
	return did_collide_with_worm_at(segment_positions[0])


func did_collide_with_worm_at(head_position: Vector2) -> bool:
	if segment_positions.size() < 2:
		return false
	for index in range(1, segment_positions.size() - 1):
		if segment_positions[index] == head_position:
			return true
	for worm in get_tree().get_nodes_in_group("worm"):
		if worm == self:
			continue
		if not worm.has_method("get_occupied_positions"):
			continue
		for occupied in worm.get_occupied_positions():
			if occupied == head_position:
				return true
	return false


func _handle_collision_death() -> void:
	if is_dying:
		return
	if health_component != null:
		health_component.current_health = 0
		health_component.check_death()
	else:
		_on_died()


func get_occupied_positions() -> Array[Vector2]:
	return segment_positions.duplicate()


func _on_died() -> void:
	if is_dying:
		return
	is_dying = true
	set_physics_process(false)
	if tile_eater != null:
		tile_eater.clear_occupied_tiles()
	_start_segment_explosions()


func _start_segment_explosions() -> void:
	if segment_positions.is_empty():
		queue_free()
		return

	for index in range(segment_count):
		_explode_segment(index)
		var tree := get_tree()
		if tree == null:
			return
		await tree.create_timer(SEGMENT_EXPLOSION_DELAY).timeout

	queue_free()


func _explode_segment(index: int) -> void:
	var segment_position := segment_positions[index]
	if index < segment_sprites.size():
		segment_sprites[index].visible = false
	if index < segment_shapes.size():
		segment_shapes[index].disabled = true
	if index < hurtbox_shapes.size():
		hurtbox_shapes[index].disabled = true
	_spawn_poof(segment_position)
	_play_explosion_sound(segment_position)


func _spawn_poof(spawn_position: Vector2) -> void:
	if poof_scene == null:
		return
	var poof_instance = poof_scene.instantiate() as GPUParticles2D
	if poof_instance == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var effects_layer = tree.get_first_node_in_group("effects_layer")
	if effects_layer != null:
		effects_layer.add_child(poof_instance)
	else:
		add_child(poof_instance)
	poof_instance.global_position = spawn_position
	poof_instance.emitting = true
	poof_instance.restart()


func _play_explosion_sound(spawn_position: Vector2) -> void:
	if EXPLOSION_STREAMS.is_empty():
		return
	var audio_player := RandomAudioStreamPlayer2DComponent.new()
	audio_player.streams = EXPLOSION_STREAMS
	audio_player.bus = &"sfx"
	var tree := get_tree()
	if tree == null:
		return
	var effects_layer = tree.get_first_node_in_group("effects_layer")
	if effects_layer != null:
		effects_layer.add_child(audio_player)
	else:
		add_child(audio_player)
	audio_player.global_position = spawn_position
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play_random()


func can_be_possessed() -> bool:
	return false
