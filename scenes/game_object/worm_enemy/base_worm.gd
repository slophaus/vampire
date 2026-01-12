extends CharacterBody2D

const TILE_SIZE := 16.0
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
@export_range(0.05, 5.0, 0.05) var move_interval := 0.8
@export_range(0.0, 1.0, 0.05) var targeted_move_chance := 0.6
@export var target_group: StringName = &"player"
@export var target_node_path: NodePath
@export var contact_damage := 1.0
@export var max_health := 20.0
@export_range(1, 64, 1) var segment_count := 15
@export_range(1, 128, 1) var max_segment_count := 25
@export_range(0.5, 30.0, 0.5) var growth_interval := 6.0
@export_range(0.25, 8.0, 0.25) var step_tile_multiplier := 1.0
@export_range(1.0, 8.0, 0.25) var footprint_tiles := 1.0
@export var head_tint := Color(0.85, 0.35, 0.55, 1.0)
@export var body_tint := Color(1.0, 0.65, 0.8, 1.0)
@export var poof_scene: PackedScene = preload("res://scenes/vfx/poof.tscn")
@export var can_dig := true
@export var occupies_tiles := true:
	set(value):
		if field == value:
			return
		field = value
		_update_collision_state()
		_update_occupied_tiles()
@export var baby_worm_scene: PackedScene
@export_range(0.0, 30.0, 0.1) var baby_spawn_interval := 0.0
@export_range(1, 10, 1) var baby_spawn_count := 1
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
var spawn_target_segment_count := 0
var spawn_growth_remaining := 0
var baby_spawn_timer := 0.0

func _ready() -> void:
	randomize()
	visible = false
	if health_component != null:
		health_component.max_health = max_health
		health_component.current_health = max_health
		health_component.free_owner_on_death = false
		health_component.died.connect(_on_died)
	if dormant_enabled:
		is_dormant = true
		dormant_timer_left = dormant_wake_timer_seconds
	call_deferred("_finish_spawn")


func _finish_spawn() -> void:
	spawn_target_segment_count = max(segment_count, 1)
	segment_count = 1
	spawn_growth_remaining = max(spawn_target_segment_count - segment_count, 0)
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
	_update_baby_spawns(delta)
	time_alive += delta
	_update_growth(delta)
	move_timer += delta
	if move_timer < move_interval:
		return
	move_timer -= move_interval

	direction = choose_direction()
	var next_head = snap_to_grid(segment_positions[0] + (direction * get_step_size()))
	if did_collide_with_worm_at(next_head):
		_handle_collision_death()
		return
	advance_segments()
	update_segments()


func _update_growth(delta: float) -> void:
	if spawn_growth_remaining > 0:
		return
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
	_update_collision_state()


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
	var spawn_position = get_spawn_marker_position()
	if spawn_position == Vector2.ZERO:
		spawn_position = get_scene_center()
	var to_center = spawn_position - global_position

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
		segment_positions.append(global_position - (direction * get_step_size() * index))

	update_segments()


func choose_direction() -> Vector2:
	if segment_positions.is_empty():
		return direction

	var forward = direction
	var left = Vector2(-direction.y, direction.x)
	var right = Vector2(direction.y, -direction.x)
	var backward = -direction

	var target_position = get_target_position()
	if target_position != null and randf() <= targeted_move_chance:
		return choose_targeted_direction(target_position, forward, left, right, backward)

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

	return choose_ordered_direction(ordered)


func choose_targeted_direction(
	target_position: Vector2,
	forward: Vector2,
	left: Vector2,
	right: Vector2,
	backward: Vector2
) -> Vector2:
	var head_position = segment_positions[0]
	var delta = snap_to_grid(target_position) - head_position
	if delta == Vector2.ZERO:
		return direction

	var primary = Vector2.ZERO
	var secondary = Vector2.ZERO
	if abs(delta.x) >= abs(delta.y):
		if delta.x != 0.0:
			primary = Vector2(sign(delta.x), 0)
		if delta.y != 0.0:
			secondary = Vector2(0, sign(delta.y))
	else:
		if delta.y != 0.0:
			primary = Vector2(0, sign(delta.y))
		if delta.x != 0.0:
			secondary = Vector2(sign(delta.x), 0)

	var ordered: Array[Vector2] = []
	if primary != Vector2.ZERO:
		ordered.append(primary)
	if secondary != Vector2.ZERO and secondary != primary:
		ordered.append(secondary)

	for candidate in [forward, left, right, backward]:
		if candidate != Vector2.ZERO and not ordered.has(candidate):
			ordered.append(candidate)

	return choose_ordered_direction(ordered)


func choose_ordered_direction(ordered: Array[Vector2]) -> Vector2:
	for candidate in ordered:
		var candidate_position = segment_positions[0] + (candidate * get_step_size())
		if is_position_blocked(candidate_position):
			continue
		if not is_position_adjacent_to_body(candidate_position):
			return candidate

	for candidate in ordered:
		var candidate_position = segment_positions[0] + (candidate * get_step_size())
		if not is_position_blocked(candidate_position):
			return candidate

	return ordered[0]


func get_target_position() -> Variant:
	if target_node_path != NodePath():
		var target_node = get_node_or_null(target_node_path)
		if target_node is Node2D:
			return target_node.global_position
	if target_group.is_empty():
		return null
	var group_target := get_tree().get_first_node_in_group(target_group) as Node2D
	if group_target != null:
		return group_target.global_position
	return null


func advance_segments() -> void:
	if segment_positions.is_empty():
		return
	var new_head = snap_to_grid(segment_positions[0] + (direction * get_step_size()))
	segment_positions.insert(0, new_head)
	segment_positions.pop_back()
	global_position = new_head
	if tile_eater != null and can_dig:
		_convert_tiles_for_footprint(new_head)
	if spawn_growth_remaining > 0:
		_grow_segment()
		spawn_growth_remaining = max(spawn_growth_remaining - 1, 0)


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
	_update_collision_state()
	if not occupies_tiles:
		tile_eater.clear_occupied_tiles()
		return
	tile_eater.update_occupied_tiles(get_occupied_positions())


func _update_collision_state() -> void:
	var collisions_enabled := occupies_tiles
	for shape in segment_shapes:
		if shape != null:
			shape.disabled = not collisions_enabled


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


func get_spawn_marker_position() -> Vector2:
	var scene_root = get_tree().current_scene
	var level_root := scene_root as LevelRoot
	var marker_name := &"PlayerSpawn"
	if level_root != null:
		marker_name = level_root.spawn_marker_name
	if scene_root == null:
		return Vector2.ZERO
	var marker = scene_root.find_child(marker_name, true, false)
	if marker is Node2D:
		return marker.global_position
	return Vector2.ZERO


func snap_to_grid(world_position: Vector2) -> Vector2:
	var step_size = get_step_size()
	var offset := Vector2(step_size / 2.0, step_size / 2.0)
	return (world_position - offset).snapped(Vector2(step_size, step_size)) + offset


func snap_to_tile_grid(world_position: Vector2) -> Vector2:
	var offset := Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	return (world_position - offset).snapped(Vector2(TILE_SIZE, TILE_SIZE)) + offset


func get_step_size() -> float:
	return TILE_SIZE * step_tile_multiplier


func is_position_blocked(candidate_position: Vector2) -> bool:
	if tile_eater != null and not _is_position_occupiable_for_footprint(candidate_position):
		return true

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
	return abs(delta.x) + abs(delta.y) == get_step_size()


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
	if not occupies_tiles:
		return []
	var occupied: Dictionary = {}
	var footprint_tile_count = int(max(1.0, ceil(footprint_tiles)))
	for position in segment_positions:
		if footprint_tile_count <= 1:
			occupied[snap_to_tile_grid(position)] = true
		else:
			for footprint_position in _get_footprint_positions(position, footprint_tile_count):
				occupied[footprint_position] = true
	var positions: Array[Vector2] = []
	for position in occupied.keys():
		positions.append(position)
	return positions


func _get_footprint_positions(center_position: Vector2, footprint_tile_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if footprint_tile_count <= 1:
		positions.append(snap_to_tile_grid(center_position))
		return positions
	var tile_span = footprint_tile_count * TILE_SIZE
	var start = center_position - Vector2(tile_span * 0.5 - (TILE_SIZE * 0.5), tile_span * 0.5 - (TILE_SIZE * 0.5))
	for y in range(footprint_tile_count):
		for x in range(footprint_tile_count):
			positions.append(start + Vector2(x * TILE_SIZE, y * TILE_SIZE))
	return positions


func _is_position_occupiable_for_footprint(candidate_position: Vector2) -> bool:
	if tile_eater == null:
		return true
	var footprint_tile_count = int(max(1.0, ceil(footprint_tiles)))
	if footprint_tile_count <= 1:
		return tile_eater.is_world_position_occupiable(candidate_position)
	for position in _get_footprint_positions(candidate_position, footprint_tile_count):
		if not tile_eater.is_world_position_occupiable(position):
			return false
	return true


func _convert_tiles_for_footprint(center_position: Vector2) -> void:
	if tile_eater == null:
		return
	var footprint_tile_count = int(max(1.0, ceil(footprint_tiles)))
	if footprint_tile_count <= 1:
		tile_eater.try_convert_tile(center_position, WORM_EATABLE_TILE_TYPES)
		return
	for position in _get_footprint_positions(center_position, footprint_tile_count):
		tile_eater.try_convert_tile(position, WORM_EATABLE_TILE_TYPES)


func _update_baby_spawns(delta: float) -> void:
	if baby_worm_scene == null or baby_spawn_interval <= 0.0:
		return
	baby_spawn_timer += delta
	if baby_spawn_timer < baby_spawn_interval:
		return
	baby_spawn_timer -= baby_spawn_interval
	for index in range(baby_spawn_count):
		_spawn_baby_worm()


func _spawn_baby_worm() -> void:
	if baby_worm_scene == null:
		return
	var baby = baby_worm_scene.instantiate() as Node2D
	if baby == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var target_layer = tree.get_first_node_in_group("entities_layer")
	if target_layer != null:
		target_layer.add_child(baby)
	else:
		add_child(baby)
	var spawn_position = global_position
	if not segment_positions.is_empty():
		spawn_position = segment_positions[segment_positions.size() - 1]
	if baby.has_method("snap_to_grid"):
		spawn_position = baby.call("snap_to_grid", spawn_position)
	baby.global_position = spawn_position
	if baby.has_method("set_spawned_awake"):
		baby.call("set_spawned_awake")


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
