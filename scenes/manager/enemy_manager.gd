extends Node
class_name EnemyManager

const OFFSCREEN_MARGIN = 10
const MAX_SPAWN_RADIUS_MULTIPLIER = 0.75
const MAX_ENEMIES = 500
const MAX_SPAWN_ATTEMPTS = 100

@export var enemy_scene: PackedScene
@export var worm_scene: PackedScene
@export var arena_time_manager: ArenaTimeManager
@export var arena_tilemap: TileMap
@export var spawn_rate_keyframes: Array[Vector2] = [Vector2(1, 1.0), Vector2(16, 2.0)]

@onready var timer = $Timer

var base_spawn_time = 0  # sec
var enemy_table = WeightedTable.new()


func _ready():
	enemy_table.add_item(0, 15)
	base_spawn_time = timer.wait_time
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)
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
	offscreen_cells.shuffle()
	for spawn_cell in offscreen_cells:
		if not is_spawn_cell_navigable_to_player(spawn_cell, player_position):
			continue
		var local_position = arena_tilemap.map_to_local(spawn_cell)
		return arena_tilemap.to_global(local_position)
	return Vector2.ZERO


func is_spawn_cell_navigable_to_player(spawn_cell: Vector2i, player_position: Vector2) -> bool:
	if arena_tilemap == null:
		return false
	var navigation_map := arena_tilemap.get_navigation_map(0)
	if not navigation_map.is_valid():
		return true
	var spawn_position = arena_tilemap.to_global(arena_tilemap.map_to_local(spawn_cell))
	var path = NavigationServer2D.map_get_path(navigation_map, spawn_position, player_position, false)
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
		return

	var enemy_index = enemy_table.pick_item()
	var enemy = get_enemy_scene(enemy_index).instantiate() as Node2D
	if enemy_index != 3:
		enemy.set("enemy_index", enemy_index)

	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	entities_layer.add_child(enemy)
	enemy.global_position = spawn_position


func get_spawn_rate() -> float:
	if timer.wait_time <= 0.0:
		return 0.0

	return 1.0 / timer.wait_time


func get_spawn_rate_for_difficulty(arena_difficulty: int) -> float:
	if spawn_rate_keyframes.is_empty():
		if base_spawn_time <= 0.0:
			return 0.0
		return 1.0 / base_spawn_time

	var keyframes = spawn_rate_keyframes.duplicate()
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
	if enemy_index == 3 and worm_scene != null:
		return worm_scene
	return enemy_scene


func on_arena_difficulty_increased(arena_difficulty: int):
	var spawn_rate = get_spawn_rate_for_difficulty(arena_difficulty)
	if spawn_rate > 0.0:
		timer.wait_time = 1.0 / spawn_rate
	
	if arena_difficulty == 2:
		enemy_table.add_item(3, 1)
	if arena_difficulty == 4:
		enemy_table.add_item(4, 6)
	if arena_difficulty == 8:
		enemy_table.add_item(1, 5)
	if arena_difficulty == 12:
		enemy_table.add_item(2, 4)
