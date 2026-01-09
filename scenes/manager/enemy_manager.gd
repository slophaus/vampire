extends Node
class_name EnemyManager

const OFFSCREEN_MARGIN = 10
const MAX_SPAWN_RADIUS_MULTIPLIER = 0.75
const MAX_ENEMIES = 500
const MAX_SPAWN_ATTEMPTS = 1
const GHOST_ENEMY_INDEX := 5

@export var enemy_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = []
@export var arena_time_manager: ArenaTimeManager
@export var arena_tilemap: TileMap

@onready var timer = $Timer

var enemy_table = WeightedTable.new()
var failed_spawn_count := 0
var last_navigation_ms := 0.0
var applied_enemy_keyframes: Dictionary = {}
var level_spawn_rate_keyframes: Array[Vector2] = []
var level_enemy_spawn_keyframes: Array[Vector3] = []
var spawning_enabled := true


func _ready():
	timer.timeout.connect(on_timer_timeout)
	if arena_time_manager != null:
		arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)
		arena_time_manager.arena_time_completed.connect(on_arena_time_completed)
	_reset_enemy_progression()
	if arena_time_manager != null and arena_time_manager.get_arena_difficulty() > 0:
		on_arena_difficulty_increased(arena_time_manager.get_arena_difficulty())


func get_spawn_position(player_position: Vector2) -> Vector2:
	var view_rect = get_camera_view_rect()
	if view_rect == Rect2():
		return Vector2.ZERO

	var max_spawn_radius = max(view_rect.size.x, view_rect.size.y) * MAX_SPAWN_RADIUS_MULTIPLIER
	var offscreen_rect = view_rect.grow(OFFSCREEN_MARGIN)
	var blocked_cells = get_worm_occupied_cells()
	var offscreen_cells = get_offscreen_walkable_cells(offscreen_rect, view_rect.get_center(), max_spawn_radius, blocked_cells)
	if offscreen_cells.is_empty():
		return Vector2.ZERO
	var spawn_cell = offscreen_cells.pick_random()
	if not is_spawn_cell_navigable_to_player(spawn_cell, player_position):
		return Vector2.ZERO
	var local_position = arena_tilemap.map_to_local(spawn_cell)
	return arena_tilemap.to_global(local_position)
	return Vector2.ZERO


func is_spawn_cell_navigable_to_player(spawn_cell: Vector2i, player_position: Vector2) -> bool:
	if arena_tilemap == null:
		return false
	if GameEvents.navigation_debug_disabled:
		return true
	var navigation_map := arena_tilemap.get_navigation_map(0)
	if not navigation_map.is_valid():
		return true
	var spawn_position = arena_tilemap.to_global(arena_tilemap.map_to_local(spawn_cell))
	var navigation_start_usec = Time.get_ticks_usec()
	var path = NavigationServer2D.map_get_path(navigation_map, spawn_position, player_position, false)
	last_navigation_ms = float(Time.get_ticks_usec() - navigation_start_usec) / 1000.0
	if path.is_empty():
		return false
	var last_point = path[path.size() - 1]
	return last_point.distance_to(player_position) <= 1.0


func get_camera_view_rect() -> Rect2:
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size = get_viewport().get_visible_rect().size
	var center = camera.get_screen_center_position()
	return Rect2(center - (viewport_size * 0.5), viewport_size)


func get_offscreen_walkable_cells(offscreen_rect: Rect2, view_center: Vector2, max_spawn_radius: float, blocked_cells: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if arena_tilemap == null:
		return cells
	for cell in arena_tilemap.get_used_cells(0):
		var tile_data = arena_tilemap.get_cell_tile_data(0, cell)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(0) > 0:
			continue
		if blocked_cells.has(cell):
			continue
		var world_position = arena_tilemap.to_global(arena_tilemap.map_to_local(cell))
		if offscreen_rect.has_point(world_position):
			continue
		if world_position.distance_to(view_center) > max_spawn_radius:
			continue
		cells.append(cell)
	return cells


func get_worm_occupied_cells() -> Dictionary:
	var occupied: Dictionary = {}
	if arena_tilemap == null:
		return occupied
	for worm in get_tree().get_nodes_in_group("worm"):
		if not worm.has_method("get_occupied_positions"):
			continue
		for position in worm.get_occupied_positions():
			var local_position = arena_tilemap.to_local(position)
			var cell = arena_tilemap.local_to_map(local_position)
			occupied[cell] = true
	return occupied


func on_timer_timeout():
	if not spawning_enabled:
		return
	timer.start()

	if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
		return

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var spawn_position := Vector2.ZERO
	for attempt in range(MAX_SPAWN_ATTEMPTS):
		spawn_position = get_spawn_position(player.global_position)
		if spawn_position != Vector2.ZERO:
			break
	if spawn_position == Vector2.ZERO:
		failed_spawn_count += 1
		return

	if enemy_table.items.is_empty():
		return

	var enemy_index = enemy_table.pick_item()
	if enemy_index == GHOST_ENEMY_INDEX and not can_spawn_ghost():
		enemy_index = pick_non_ghost_enemy()
	var enemy = get_enemy_scene(enemy_index).instantiate() as Node2D

	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	entities_layer.add_child(enemy)
	enemy.global_position = spawn_position


func get_failed_spawn_count() -> int:
	return failed_spawn_count


func get_last_navigation_ms() -> float:
	return last_navigation_ms


func get_spawn_rate() -> float:
	if timer.wait_time <= 0.0:
		return 0.0

	return 1.0 / timer.wait_time


func get_spawn_rate_for_difficulty(arena_difficulty: int) -> float:
	var active_keyframes = _get_active_spawn_rate_keyframes()
	if active_keyframes.is_empty():
		return 0.0

	var keyframes = active_keyframes.duplicate()
	keyframes.sort_custom(func(a, b): return a.x < b.x)

	if arena_difficulty <= int(keyframes[0].x):
		return keyframes[0].y

	var last = keyframes[keyframes.size() - 1]
	if arena_difficulty >= int(last.x):
		return last.y

	for index in range(keyframes.size() - 1):
		var start = keyframes[index]
		var end = keyframes[index + 1]
		if arena_difficulty <= int(end.x):
			var span = end.x - start.x
			var t = 0.0
			if span != 0.0:
				t = (float(arena_difficulty) - start.x) / span
			return lerp(start.y, end.y, clamp(t, 0.0, 1.0))

	return last.y


func get_enemy_scene(enemy_index: int) -> PackedScene:
	if enemy_index >= 0 and enemy_index < enemy_scenes.size():
		var scene = enemy_scenes[enemy_index]
		if scene != null:
			return scene
	return enemy_scene


func can_spawn_ghost() -> bool:
	return get_tree().get_nodes_in_group("ghost").is_empty()


func pick_non_ghost_enemy() -> int:
	for attempt in range(10):
		var enemy_index = enemy_table.pick_item()
		if enemy_index != GHOST_ENEMY_INDEX:
			return enemy_index
	return 0


func on_arena_difficulty_increased(arena_difficulty: int):
	var spawn_rate = get_spawn_rate_for_difficulty(arena_difficulty)
	if spawn_rate > 0.0:
		timer.wait_time = 1.0 / spawn_rate

	_apply_enemy_keyframes_for_difficulty(arena_difficulty)


func apply_level_settings(level: LevelRoot) -> void:
	if level != null:
		level_spawn_rate_keyframes = level.spawn_rate_keyframes
		level_enemy_spawn_keyframes = level.enemy_spawn_keyframes
	else:
		level_spawn_rate_keyframes = []
		level_enemy_spawn_keyframes = []
	set_spawning_enabled(true)
	_reset_enemy_progression()
	if arena_time_manager != null:
		on_arena_difficulty_increased(arena_time_manager.get_arena_difficulty())


func set_spawning_enabled(enabled: bool) -> void:
	spawning_enabled = enabled
	if timer == null:
		return
	if spawning_enabled:
		if timer.is_stopped():
			timer.start()
	else:
		timer.stop()


func on_arena_time_completed() -> void:
	set_spawning_enabled(false)


func _reset_enemy_progression() -> void:
	enemy_table = WeightedTable.new()
	applied_enemy_keyframes.clear()


func _get_active_spawn_rate_keyframes() -> Array[Vector2]:
	return level_spawn_rate_keyframes


func _get_active_enemy_spawn_keyframes() -> Array[Vector3]:
	return level_enemy_spawn_keyframes


func _apply_enemy_keyframes_for_difficulty(arena_difficulty: int) -> void:
	var keyframes = _get_active_enemy_spawn_keyframes()
	if keyframes.is_empty():
		return
	var sorted = keyframes.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x)
	for keyframe in sorted:
		var keyframe_difficulty = int(keyframe.x)
		if arena_difficulty < keyframe_difficulty:
			continue
		var keyframe_id = Vector3i(keyframe_difficulty, int(keyframe.y), int(keyframe.z))
		if applied_enemy_keyframes.has(keyframe_id):
			continue
		_apply_enemy_keyframe(keyframe)
		applied_enemy_keyframes[keyframe_id] = true


func _apply_enemy_keyframe(keyframe: Vector3) -> void:
	var enemy_index = int(keyframe.y)
	var weight = int(keyframe.z)
	if weight <= 0:
		return
	enemy_table.add_item(enemy_index, weight)
