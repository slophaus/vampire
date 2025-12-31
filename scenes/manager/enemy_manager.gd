extends Node
class_name EnemyManager

const OFFSCREEN_MARGIN = 10
const MAX_SPAWN_ATTEMPTS = 16
const MAX_ENEMIES = 500

@export var enemy_scene: PackedScene
@export var worm_scene: PackedScene
@export var arena_time_manager: ArenaTimeManager
@export var arena_tilemap: TileMap

@onready var timer = $Timer

var base_spawn_time = 0  # sec
var enemy_table = WeightedTable.new()


func _ready():
	enemy_table.add_item(0, 15)
	base_spawn_time = timer.wait_time
	timer.wait_time = base_spawn_time
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)
	if arena_time_manager != null and arena_time_manager.get_arena_difficulty() > 0:
		on_arena_difficulty_increased(arena_time_manager.get_arena_difficulty())


func get_spawn_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO

	var arena_rect = get_arena_rect()
	if arena_rect == Rect2():
		return Vector2.ZERO

	var view_rect = get_camera_view_rect()
	var offscreen_rect = view_rect.grow(OFFSCREEN_MARGIN)
	var spawn_areas = get_spawn_areas(arena_rect, offscreen_rect)
	if spawn_areas.is_empty():
		return Vector2.ZERO

	for i in MAX_SPAWN_ATTEMPTS:
		var area = spawn_areas[randi_range(0, spawn_areas.size() - 1)]
		var spawn_position = get_random_point_in_rect(area)
		if offscreen_rect.has_point(spawn_position):
			continue
		if not is_spawn_tile_walkable(spawn_position):
			continue
		if is_spawn_path_clear(player.global_position, spawn_position):
			return spawn_position

	return Vector2.ZERO


func get_arena_rect() -> Rect2:
	if arena_tilemap == null or arena_tilemap.tile_set == null:
		return Rect2()
	var used_rect: Rect2i = arena_tilemap.get_used_rect()
	if used_rect == Rect2i():
		return Rect2()
	var tile_size = arena_tilemap.tile_set.tile_size
	var rect = Rect2(used_rect.position * tile_size, used_rect.size * tile_size)
	rect.position += arena_tilemap.global_position
	return rect


func get_camera_view_rect() -> Rect2:
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size = get_viewport().get_visible_rect().size
	var center = camera.get_screen_center_position()
	return Rect2(center - (viewport_size * 0.5), viewport_size)


func get_spawn_areas(arena_rect: Rect2, view_rect: Rect2) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	if arena_rect == Rect2():
		return areas
	if view_rect == Rect2():
		areas.append(arena_rect)
		return areas
	var intersection = arena_rect.intersection(view_rect)
	if intersection == Rect2():
		areas.append(arena_rect)
		return areas

	var top_height = intersection.position.y - arena_rect.position.y
	if top_height > 0:
		areas.append(Rect2(arena_rect.position, Vector2(arena_rect.size.x, top_height)))

	var bottom_y = intersection.position.y + intersection.size.y
	var bottom_height = (arena_rect.position.y + arena_rect.size.y) - bottom_y
	if bottom_height > 0:
		areas.append(Rect2(Vector2(arena_rect.position.x, bottom_y), Vector2(arena_rect.size.x, bottom_height)))

	var left_width = intersection.position.x - arena_rect.position.x
	if left_width > 0:
		areas.append(Rect2(Vector2(arena_rect.position.x, intersection.position.y), Vector2(left_width, intersection.size.y)))

	var right_x = intersection.position.x + intersection.size.x
	var right_width = (arena_rect.position.x + arena_rect.size.x) - right_x
	if right_width > 0:
		areas.append(Rect2(Vector2(right_x, intersection.position.y), Vector2(right_width, intersection.size.y)))

	return areas


func get_random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)


func is_spawn_path_clear(start_position: Vector2, end_position: Vector2) -> bool:
	var direction = end_position - start_position
	if direction.length() == 0:
		return false
	var additional_check_offset = direction.normalized() * 20  # prevent stuck in a wall
	var query_parameters = PhysicsRayQueryParameters2D.create(
		start_position,
		end_position + additional_check_offset,
		1 << 0
	)
	var result = get_tree().root.world_2d.direct_space_state.intersect_ray(query_parameters)
	return result.is_empty()


func is_spawn_tile_walkable(spawn_position: Vector2) -> bool:
	if arena_tilemap == null:
		return true
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(spawn_position))
	var tile_data = arena_tilemap.get_cell_tile_data(0, cell)
	if tile_data == null:
		return false
	return tile_data.get_collision_polygons_count(0) == 0


func on_timer_timeout():
	timer.start()

	if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
		return

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	
	var enemy_index = enemy_table.pick_item()
	var enemy = get_enemy_scene(enemy_index).instantiate() as Node2D
	if enemy_index != 3:
		enemy.set("enemy_index", enemy_index)
	
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	entities_layer.add_child(enemy)
	enemy.global_position = get_spawn_position()


func get_spawn_rate() -> float:
	if timer.wait_time <= 0.0:
		return 0.0

	return 1.0 / timer.wait_time


func get_enemy_scene(enemy_index: int) -> PackedScene:
	if enemy_index == 3 and worm_scene != null:
		return worm_scene
	return enemy_scene


func on_arena_difficulty_increased(arena_difficulty: int):
	var time_off = (0.1 / 12) * arena_difficulty
	time_off = min(time_off, 0.7)
	timer.wait_time = base_spawn_time - time_off
	
	if arena_difficulty == 6:
		enemy_table.add_item(3, 1)
	if arena_difficulty == 8:
		enemy_table.add_item(1, 5)
	if arena_difficulty == 12:
		enemy_table.add_item(2, 4)
