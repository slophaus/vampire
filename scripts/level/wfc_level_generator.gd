extends Node
class_name WFCLevelGenerator

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0
@export var seeded_mode := true
@export_range(1, 4, 1) var overlap_size := 2
@export var use_chunked_generation := true
@export_range(16, 256, 1) var chunk_size := 64
@export var periodic_input := false
@export var show_step_by_step := false
@export_range(0.0, 5.0, 0.05) var step_delay_seconds := 0.0
@export var debug_logs := false
@export var debug_path_line_path: NodePath

const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


func _debug_log(message: String) -> void:
	if not debug_logs:
		return
	print_debug(message)


func _ready() -> void:
	set_process_unhandled_input(true)
	if generate_on_ready:
		generate_level()


func generate_level(use_new_seed: bool = false) -> void:
	var total_start_ms := Time.get_ticks_msec()
	var phase_start_ms := total_start_ms
	var target_tilemap := get_node_or_null(target_tilemap_path) as TileMap
	var sample_tilemap := get_node_or_null(sample_tilemap_path) as TileMap
	if target_tilemap == null or sample_tilemap == null:
		_debug_log("WFC: missing tilemap references.")
		return
	sample_tilemap.visible = false
	target_tilemap.visible = true

	var target_rect := target_tilemap.get_used_rect()
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		_debug_log("WFC: target tilemap has no used tiles to define bounds.")
		return

	var sample_rect := sample_tilemap.get_used_rect()
	if sample_rect.size.x < overlap_size or sample_rect.size.y < overlap_size:
		_debug_log("WFC: sample tilemap too small for overlap size.")
		return

	var rng := RandomNumberGenerator.new()
	if use_new_seed or not seeded_mode:
		rng.randomize()
	elif random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	var patterns_data: Dictionary = _build_patterns(sample_tilemap, sample_rect, overlap_size, periodic_input)
	_debug_log("WFC: phase patterns %d ms" % (Time.get_ticks_msec() - phase_start_ms))
	phase_start_ms = Time.get_ticks_msec()
	if patterns_data.patterns.is_empty():
		_debug_log("WFC: no patterns extracted from sample.")
		return

	if use_chunked_generation:
		if show_step_by_step:
			_debug_log("WFC: step preview disabled in chunked mode.")
		var chunk_success := await _generate_chunked_level(
			target_tilemap,
			target_rect,
			patterns_data,
			rng
		)
		if not chunk_success:
			_debug_log("WFC: failed after %d attempts." % max_attempts)
			return
		_debug_log("WFC: phase solve %d ms" % (Time.get_ticks_msec() - phase_start_ms))
		phase_start_ms = Time.get_ticks_msec()
	else:
		var pattern_grid_size := Vector2i(
			target_rect.size.x - overlap_size + 1,
			target_rect.size.y - overlap_size + 1
		)
		if pattern_grid_size.x <= 0 or pattern_grid_size.y <= 0:
			_debug_log("WFC: target bounds smaller than overlap size.")
			return

		var attempt := 0
		var result: Dictionary = {}
		while attempt < max_attempts:
			attempt += 1
			if attempt == 1 or attempt % 50 == 0:
				_debug_log("WFC: attempt %d/%d" % [attempt, max_attempts])

			var step_callback := Callable()
			if show_step_by_step:
				target_tilemap.clear()
				step_callback = func(cell_index: int, chosen_pattern: int) -> void:
					_apply_step_preview(
						target_tilemap,
						patterns_data.patterns,
						patterns_data.tiles,
						pattern_grid_size,
						target_rect,
						overlap_size,
						cell_index,
						chosen_pattern
					)

			result = await _run_wfc(
				patterns_data.patterns,
				patterns_data.weights,
				patterns_data.adjacency,
				pattern_grid_size,
				rng,
				step_callback,
				step_delay_seconds
			)

			if result.success:
				break

		if not result.success:
			_debug_log("WFC: failed after %d attempts." % max_attempts)
			return
		_debug_log("WFC: phase solve %d ms" % (Time.get_ticks_msec() - phase_start_ms))
		phase_start_ms = Time.get_ticks_msec()

		var output_tiles: Dictionary = _build_output_tiles(
			patterns_data.patterns,
			patterns_data.tiles,
			result.grid,
			pattern_grid_size,
			target_rect,
			overlap_size
		)
		_debug_log("WFC: phase output tiles %d ms" % (Time.get_ticks_msec() - phase_start_ms))
		phase_start_ms = Time.get_ticks_msec()

		target_tilemap.clear()
		for tile_pos in output_tiles.keys():
			var tile: Dictionary = output_tiles[tile_pos]
			if tile.source_id == -1:
				continue
			target_tilemap.set_cell(
				0,
				tile_pos,
				tile.source_id,
				tile.atlas_coords,
				tile.alternative_tile
			)

	_position_level_doors(target_tilemap, rng)
	_set_border_tiles_to_wall(target_tilemap, target_rect)
	if target_tilemap.has_meta(TileEater.DIRT_BORDER_META_KEY):
		target_tilemap.remove_meta(TileEater.DIRT_BORDER_META_KEY)
	TileEater.initialize_dirt_border_for_tilemap(target_tilemap)
	_move_entities_to_nearest_floor(target_tilemap)

	_debug_log("WFC: phase finalize %d ms" % (Time.get_ticks_msec() - phase_start_ms))
	_debug_log("WFC: total time %d ms" % (Time.get_ticks_msec() - total_start_ms))
	_debug_log("WFC: generation complete.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		generate_level(true)


func _move_entities_to_nearest_floor(target_tilemap: TileMap) -> void:
	if target_tilemap == null:
		return
	var floor_positions := _get_floor_positions(target_tilemap)
	if floor_positions.is_empty():
		return
	_move_nodes_in_group_to_nearest_floor("player", floor_positions)
	_move_nodes_in_group_to_nearest_floor("enemy", floor_positions)
	_move_props_to_nearest_floor(floor_positions)


func _set_border_tiles_to_wall(target_tilemap: TileMap, target_rect: Rect2i) -> void:
	if target_tilemap == null:
		return
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		return
	var wall_tile := _find_tile_by_type(target_tilemap, "wall")
	if wall_tile.is_empty():
		return
	var min_x := target_rect.position.x
	var min_y := target_rect.position.y
	var max_x := target_rect.position.x + target_rect.size.x - 1
	var max_y := target_rect.position.y + target_rect.size.y - 1
	for x in range(min_x, max_x + 1):
		_set_cell_to_tile(target_tilemap, Vector2i(x, min_y), wall_tile)
		_set_cell_to_tile(target_tilemap, Vector2i(x, max_y), wall_tile)
	for y in range(min_y + 1, max_y):
		_set_cell_to_tile(target_tilemap, Vector2i(min_x, y), wall_tile)
		_set_cell_to_tile(target_tilemap, Vector2i(max_x, y), wall_tile)


func _position_level_doors(target_tilemap: TileMap, rng: RandomNumberGenerator) -> void:
	_reset_debug_door_path()
	if target_tilemap == null:
		_debug_log("WFC: door placement skipped (missing target tilemap).")
		return
	var door_group := get_parent().get_node_or_null("LayerProps/DoorGroup")
	if door_group == null:
		_debug_log("WFC: door placement skipped (missing LayerProps/DoorGroup).")
		return
	var door_nodes: Array[Node2D] = []
	for child in door_group.get_children():
		var node_2d := child as Node2D
		if node_2d == null:
			_debug_log("WFC: door placement ignored non-Node2D child %s." % child.name)
			continue
		door_nodes.append(node_2d)
	if door_nodes.size() < 2:
		_debug_log("WFC: door placement skipped (found %d doors)." % door_nodes.size())
		return
	var walkable_cells := _get_walkable_cells(target_tilemap)
	if walkable_cells.is_empty():
		_debug_log("WFC: door placement skipped (no walkable cells).")
		return
	var door_cells := _filter_cells_min_distance_from_bottom(target_tilemap, walkable_cells, 8)
	if door_cells.is_empty():
		_debug_log("WFC: door placement skipped (no walkable cells far enough from bottom).")
		return
	door_cells = _filter_cells_min_distance_from_top_and_sides(target_tilemap, door_cells, 3)
	if door_cells.is_empty():
		_debug_log("WFC: door placement skipped (no walkable cells far enough from top/sides).")
		return
	var start_cell := _find_near_corner_floor_cell(target_tilemap, door_cells, rng)
	var distances := _build_walkable_distance_field(walkable_cells, start_cell)
	var door_distances := _filter_distances(distances, door_cells)
	var farthest_cell := _find_distance_percentile_cell(door_distances, start_cell, 0.9)
	var path_cells := _build_path_from_distances(distances, start_cell, farthest_cell)
	_debug_log("WFC: door placement choosing cells %s (start) and %s (~90%% farthest)." % [
		start_cell,
		farthest_cell
	])
	_debug_log("WFC: door placement doors %s -> %s, %s -> %s." % [
		door_nodes[0].name,
		_cell_to_world(target_tilemap, start_cell),
		door_nodes[1].name,
		_cell_to_world(target_tilemap, farthest_cell)
	])
	door_nodes[0].global_position = _cell_to_world(target_tilemap, start_cell)
	door_nodes[1].global_position = _cell_to_world(target_tilemap, farthest_cell)
	_update_debug_door_path(target_tilemap, path_cells)
	var floor_tile := _find_tile_by_type(target_tilemap, "floor")
	if floor_tile.is_empty():
		_debug_log("WFC: door placement skipped floor conversion (no floor tile found).")
		return
	var wall_tile := _find_tile_by_type(target_tilemap, "wall")
	var path_lookup := _cells_to_lookup(path_cells)
	_apply_door_clearance(target_tilemap, start_cell, floor_tile, wall_tile, path_lookup)
	_apply_door_clearance(target_tilemap, farthest_cell, floor_tile, wall_tile, path_lookup)


func _get_walkable_cells(target_tilemap: TileMap) -> Dictionary:
	var walkable_cells: Dictionary = {}
	for cell in target_tilemap.get_used_cells(0):
		var tile_data := target_tilemap.get_cell_tile_data(0, cell)
		if tile_data == null:
			continue
		var tile_type = tile_data.get_custom_data(TileEater.CUSTOM_DATA_KEY)
		if tile_type != null and TileEater.WALKABLE_TILE_TYPES.has(tile_type):
			walkable_cells[cell] = true
	return walkable_cells


func _find_near_corner_floor_cell(
	target_tilemap: TileMap,
	walkable_cells: Dictionary,
	rng: RandomNumberGenerator
) -> Vector2i:
	var used_rect := target_tilemap.get_used_rect()
	var corner := Vector2i(used_rect.position.x, used_rect.position.y + used_rect.size.y - 1)
	var best_cell: Vector2i = walkable_cells.keys()[0] as Vector2i
	var best_distance := INF
	var nearby_candidates: Array[Vector2i] = []
	var min_distance_squared := 100
	var max_distance_squared := 300
	for cell in walkable_cells.keys():
		var distance := corner.distance_squared_to(cell)
		if distance >= min_distance_squared and distance <= max_distance_squared:
			nearby_candidates.append(cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	if not nearby_candidates.is_empty():
		return nearby_candidates[rng.randi_range(0, nearby_candidates.size() - 1)]
	if best_distance > 0:
		return best_cell
	return best_cell


func _build_walkable_distance_field(walkable_cells: Dictionary, start_cell: Vector2i) -> Dictionary:
	var distances: Dictionary = {}
	var queue: Array[Vector2i] = []
	queue.append(start_cell)
	distances[start_cell] = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front() as Vector2i
		var current_distance: int = distances[current]
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not walkable_cells.has(neighbor):
				continue
			if distances.has(neighbor):
				continue
			distances[neighbor] = current_distance + 1
			queue.append(neighbor)
	return distances


func _build_path_from_distances(
	distances: Dictionary,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not distances.has(end_cell):
		return path
	var current := end_cell
	path.append(current)
	while current != start_cell:
		var current_distance: int = distances[current]
		var next_cell := current
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if distances.has(neighbor) and distances[neighbor] == current_distance - 1:
				next_cell = neighbor
				break
		if next_cell == current:
			break
		current = next_cell
		path.append(current)
	path.reverse()
	return path


func _filter_cells_min_distance_from_bottom(
	target_tilemap: TileMap,
	walkable_cells: Dictionary,
	min_distance: int
) -> Dictionary:
	var filtered: Dictionary = {}
	var used_rect := target_tilemap.get_used_rect()
	var bottom_y := used_rect.position.y + used_rect.size.y - 1
	for cell in walkable_cells.keys():
		if bottom_y - cell.y >= min_distance:
			filtered[cell] = true
	return filtered


func _filter_cells_min_distance_from_top_and_sides(
	target_tilemap: TileMap,
	walkable_cells: Dictionary,
	min_distance: int
) -> Dictionary:
	var filtered: Dictionary = {}
	var used_rect := target_tilemap.get_used_rect()
	var top_y := used_rect.position.y
	var left_x := used_rect.position.x
	var right_x := used_rect.position.x + used_rect.size.x - 1
	for cell in walkable_cells.keys():
		if cell.y - top_y < min_distance:
			continue
		if cell.x - left_x < min_distance:
			continue
		if right_x - cell.x < min_distance:
			continue
		filtered[cell] = true
	return filtered


func _filter_distances(distances: Dictionary, allowed_cells: Dictionary) -> Dictionary:
	var filtered: Dictionary = {}
	for cell in allowed_cells.keys():
		if distances.has(cell):
			filtered[cell] = distances[cell]
	return filtered


func _find_farthest_cell(distances: Dictionary, fallback: Vector2i) -> Vector2i:
	if distances.is_empty():
		return fallback
	var farthest_cell := fallback
	var farthest_distance := -1
	for cell in distances.keys():
		var distance: int = distances[cell]
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_cell = cell
	return farthest_cell


func _find_distance_percentile_cell(
	distances: Dictionary,
	fallback: Vector2i,
	percent: float
) -> Vector2i:
	if distances.is_empty():
		return fallback
	var farthest_distance := -1
	for distance in distances.values():
		farthest_distance = max(farthest_distance, int(distance))
	if farthest_distance <= 0:
		return fallback
	var target_distance := int(round(farthest_distance * clampf(percent, 0.0, 1.0)))
	var closest_cell := fallback
	var closest_delta := INF
	for cell in distances.keys():
		var distance: int = distances[cell]
		var delta: int = absi(distance - target_distance)
		if delta < closest_delta:
			closest_delta = delta
			closest_cell = cell
	return closest_cell


func _find_tile_by_type(target_tilemap: TileMap, tile_type: String) -> Dictionary:
	if target_tilemap == null:
		return {}
	for cell in target_tilemap.get_used_cells(0):
		var tile_data := target_tilemap.get_cell_tile_data(0, cell)
		if _tile_data_has_type(tile_data, tile_type):
			return {
				"source_id": target_tilemap.get_cell_source_id(0, cell),
				"atlas_coords": target_tilemap.get_cell_atlas_coords(0, cell),
				"alternative": target_tilemap.get_cell_alternative_tile(0, cell),
			}
	var tile_set = target_tilemap.tile_set
	if tile_set == null:
		return {}
	for source_index in range(tile_set.get_source_count()):
		var source_id = tile_set.get_source_id(source_index)
		var source = tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas := source as TileSetAtlasSource
			for tile_index in range(atlas.get_tiles_count()):
				var tile_id = atlas.get_tile_id(tile_index)
				if _tile_data_has_type(atlas.get_tile_data(tile_id, 0), tile_type):
					return {
						"source_id": source_id,
						"atlas_coords": tile_id,
						"alternative": 0,
					}
				var alt_count = atlas.get_alternative_tiles_count(tile_id)
				for alt_index in range(alt_count):
					var alt_id = atlas.get_alternative_tile_id(tile_id, alt_index)
					if _tile_data_has_type(atlas.get_tile_data(tile_id, alt_id), tile_type):
						return {
							"source_id": source_id,
							"atlas_coords": tile_id,
							"alternative": alt_id,
						}
	return {}


func _tile_data_has_type(tile_data: TileData, tile_type: String) -> bool:
	if tile_data == null:
		return false
	var custom_type = tile_data.get_custom_data(TileEater.CUSTOM_DATA_KEY)
	return custom_type != null and custom_type == tile_type


func _apply_door_clearance(
	target_tilemap: TileMap,
	door_cell: Vector2i,
	floor_tile: Dictionary,
	wall_tile: Dictionary,
	path_lookup: Dictionary
) -> void:
	if floor_tile.is_empty():
		return
	var min_x := door_cell.x - 1
	var max_x := door_cell.x + 1
	var min_y := door_cell.y - 1
	var max_y := door_cell.y + 4
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			_set_cell_to_tile(target_tilemap, Vector2i(x, y), floor_tile)
	if wall_tile.is_empty():
		return
	for x in range(min_x - 1, max_x + 2):
		for y in range(min_y - 1, max_y + 2):
			if x >= min_x and x <= max_x and y >= min_y and y <= max_y:
				continue
			var cell := Vector2i(x, y)
			if path_lookup.has(cell):
				continue
			_set_cell_to_tile(target_tilemap, cell, wall_tile)


func _reset_debug_door_path() -> void:
	var debug_line := get_node_or_null(debug_path_line_path) as Line2D
	if debug_line == null:
		return
	debug_line.clear_points()
	debug_line.visible = false


func _update_debug_door_path(
	target_tilemap: TileMap,
	path_cells: Array[Vector2i]
) -> void:
	var debug_line := get_node_or_null(debug_path_line_path) as Line2D
	if debug_line == null:
		return
	debug_line.clear_points()
	if not debug_logs:
		debug_line.visible = false
		return
	if path_cells.is_empty():
		debug_line.visible = false
		return
	for cell in path_cells:
		var world_position := _cell_to_world(target_tilemap, cell)
		debug_line.add_point(debug_line.to_local(world_position))
	debug_line.visible = true


func _cells_to_lookup(cells: Array[Vector2i]) -> Dictionary:
	var lookup: Dictionary = {}
	for cell in cells:
		lookup[cell] = true
	return lookup


func _set_cell_to_tile(target_tilemap: TileMap, cell: Vector2i, tile_info: Dictionary) -> void:
	if target_tilemap == null:
		return
	if not tile_info.has("source_id"):
		return
	target_tilemap.set_cell(
		0,
		cell,
		tile_info["source_id"],
		tile_info["atlas_coords"],
		tile_info["alternative"]
	)


func _cell_to_world(target_tilemap: TileMap, cell: Vector2i) -> Vector2:
	var local_position = target_tilemap.map_to_local(cell)
	return target_tilemap.to_global(local_position)


func _get_floor_positions(target_tilemap: TileMap) -> Array[Vector2]:
	var floor_positions: Array[Vector2] = []
	for cell in target_tilemap.get_used_cells(0):
		var tile_data := target_tilemap.get_cell_tile_data(0, cell)
		if tile_data == null:
			continue
		var tile_type = tile_data.get_custom_data(TileEater.CUSTOM_DATA_KEY)
		if tile_type != null and TileEater.WALKABLE_TILE_TYPES.has(tile_type):
			var local_position = target_tilemap.map_to_local(cell)
			floor_positions.append(target_tilemap.to_global(local_position))
	return floor_positions


func _move_nodes_in_group_to_nearest_floor(group_name: String, floor_positions: Array[Vector2]) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		node_2d.global_position = _find_closest_floor_position(node_2d.global_position, floor_positions)


func _move_props_to_nearest_floor(floor_positions: Array[Vector2]) -> void:
	var props_layer := get_parent().get_node_or_null("LayerProps")
	if props_layer == null:
		return
	var door_group := props_layer.get_node_or_null("DoorGroup")
	for child in props_layer.get_children():
		var node_2d := child as Node2D
		if node_2d == null:
			continue
		if door_group != null and node_2d == door_group:
			continue
		node_2d.global_position = _find_closest_floor_position(node_2d.global_position, floor_positions)


func _find_closest_floor_position(
	start_position: Vector2,
	floor_positions: Array[Vector2]
) -> Vector2:
	var closest_position := floor_positions[0]
	var closest_distance := INF
	for floor_position in floor_positions:
		var distance := start_position.distance_squared_to(floor_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_position = floor_position
	return closest_position


func _build_patterns(
	sample_tilemap: TileMap,
	sample_rect: Rect2i,
	pattern_size: int,
	use_periodic_input: bool
) -> Dictionary:
	var pattern_map: Dictionary = {}
	var patterns: Array = []
	var weights: Array = []
	var tile_data: Dictionary = {}
	var pattern_limit := Vector2i(
		sample_rect.size.x if use_periodic_input else sample_rect.size.x - pattern_size + 1,
		sample_rect.size.y if use_periodic_input else sample_rect.size.y - pattern_size + 1
	)

	for y_offset in range(pattern_limit.y):
		for x_offset in range(pattern_limit.x):
			var tiles: Array = []
			var valid: bool = true
			for dy in range(pattern_size):
				for dx in range(pattern_size):
					var cell_pos := sample_rect.position + Vector2i(x_offset + dx, y_offset + dy)
					if use_periodic_input:
						cell_pos = sample_rect.position + Vector2i(
							(x_offset + dx) % sample_rect.size.x,
							(y_offset + dy) % sample_rect.size.y
						)
					var source_id := sample_tilemap.get_cell_source_id(0, cell_pos)
					if source_id == -1:
						tiles.append(_empty_tile_key())
						continue
					var atlas_coords := sample_tilemap.get_cell_atlas_coords(0, cell_pos)
					var alternative_tile := sample_tilemap.get_cell_alternative_tile(0, cell_pos)
					var tile_key := _tile_key(source_id, atlas_coords, alternative_tile)
					if not tile_data.has(tile_key):
						tile_data[tile_key] = {
							"source_id": source_id,
							"atlas_coords": atlas_coords,
							"alternative_tile": alternative_tile,
						}
					tiles.append(tile_key)
				if not valid:
					break

			if not valid:
				continue

			var signature := "|".join(tiles)
			if not pattern_map.has(signature):
				pattern_map[signature] = patterns.size()
				patterns.append(tiles)
				weights.append(1)
			else:
				var index: int = int(pattern_map[signature])
				weights[index] += 1

	var adjacency: Array = _build_adjacency(patterns, pattern_size)

	if not tile_data.has(_empty_tile_key()):
		tile_data[_empty_tile_key()] = {
			"source_id": -1,
			"atlas_coords": Vector2i.ZERO,
			"alternative_tile": 0,
		}

	return {
		"patterns": patterns,
		"weights": weights,
		"tiles": tile_data,
		"adjacency": adjacency,
	}


func _build_allowed_patterns_by_tile(patterns: Array, pattern_size: int) -> Dictionary:
	var allowed: Dictionary = {}
	for pattern_index in range(patterns.size()):
		var pattern_tiles: Array = patterns[pattern_index]
		for dy in range(pattern_size):
			for dx in range(pattern_size):
				var tile_key: String = pattern_tiles[dy * pattern_size + dx]
				if not allowed.has(tile_key):
					var grid: Array = []
					grid.resize(pattern_size)
					for row_index in range(pattern_size):
						var row: Array = []
						row.resize(pattern_size)
						for col_index in range(pattern_size):
							row[col_index] = []
						grid[row_index] = row
					allowed[tile_key] = grid
				allowed[tile_key][dy][dx].append(pattern_index)
	return allowed


func _build_adjacency(patterns: Array, pattern_size: int) -> Array:
	var adjacency: Array = []
	for _pattern in patterns:
		var entry := []
		for _dir in DIRECTIONS:
			entry.append([])
		adjacency.append(entry)

	for i in range(patterns.size()):
		for j in range(patterns.size()):
			for dir_index in range(DIRECTIONS.size()):
				if _patterns_compatible(patterns[i], patterns[j], pattern_size, dir_index):
					adjacency[i][dir_index].append(j)

	return adjacency


func _patterns_compatible(pattern_a: Array, pattern_b: Array, pattern_size: int, dir_index: int) -> bool:
	if dir_index == 0:
		for dy in range(pattern_size - 1):
			for dx in range(pattern_size):
				if pattern_a[dy * pattern_size + dx] != pattern_b[(dy + 1) * pattern_size + dx]:
					return false
	elif dir_index == 1:
		for dy in range(pattern_size):
			for dx in range(pattern_size - 1):
				if pattern_a[dy * pattern_size + dx + 1] != pattern_b[dy * pattern_size + dx]:
					return false
	elif dir_index == 2:
		for dy in range(pattern_size - 1):
			for dx in range(pattern_size):
				if pattern_a[(dy + 1) * pattern_size + dx] != pattern_b[dy * pattern_size + dx]:
					return false
	else:
		for dy in range(pattern_size):
			for dx in range(pattern_size - 1):
				if pattern_a[dy * pattern_size + dx] != pattern_b[dy * pattern_size + dx + 1]:
					return false
	return true


func _run_wfc(
	patterns: Array,
	weights: Array,
	adjacency: Array,
	grid_size: Vector2i,
	rng: RandomNumberGenerator,
	step_callback: Callable = Callable(),
	step_delay: float = 0.0
) -> Dictionary:
	var total_cells: int = grid_size.x * grid_size.y
	var wave: Array = []
	var all_patterns: Array = []
	for index in range(patterns.size()):
		all_patterns.append(index)

	for _i in range(total_cells):
		wave.append(all_patterns.duplicate())

	var stack: Array = []
	var allowed_mask := PackedByteArray()
	allowed_mask.resize(patterns.size())

	while true:
		var next_index := _find_lowest_entropy(wave, rng)
		if next_index == -1:
			return {"success": true, "grid": wave}

		if wave[next_index].is_empty():
			return {"success": false}

		var chosen: int = _weighted_choice(wave[next_index], weights, rng)
		wave[next_index] = [chosen]
		stack.append(next_index)
		if step_callback.is_valid():
			step_callback.call(next_index, chosen)
			if step_delay > 0.0:
				await get_tree().create_timer(step_delay).timeout

		if not _propagate_constraints(wave, adjacency, grid_size, stack, allowed_mask):
			return {"success": false}

	return {"success": false}


func _run_wfc_with_constraints(
	patterns: Array,
	weights: Array,
	adjacency: Array,
	grid_size: Vector2i,
	rng: RandomNumberGenerator,
	allowed_patterns: Dictionary,
	global_tiles: Dictionary,
	solve_origin: Vector2i,
	constraint_rects: Array[Rect2i],
	step_callback: Callable = Callable(),
	step_delay: float = 0.0
) -> Dictionary:
	var total_cells: int = grid_size.x * grid_size.y
	var wave: Array = []
	var all_patterns: Array = []
	for index in range(patterns.size()):
		all_patterns.append(index)

	for _i in range(total_cells):
		wave.append(all_patterns.duplicate())

	var stack: Array = []
	var stack_lookup: Dictionary = {}
	var allowed_mask := PackedByteArray()
	allowed_mask.resize(patterns.size())

	for rect in constraint_rects:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var tile_pos := Vector2i(x, y)
				if not global_tiles.has(tile_pos):
					continue
				var tile_key: String = global_tiles[tile_pos]
				if not allowed_patterns.has(tile_key):
					return {"success": false}
				var local_x := x - solve_origin.x
				var local_y := y - solve_origin.y
				var min_ax := maxi(0, local_x - (overlap_size - 1))
				var max_ax := mini(grid_size.x - 1, local_x)
				var min_ay := maxi(0, local_y - (overlap_size - 1))
				var max_ay := mini(grid_size.y - 1, local_y)
				for ay in range(min_ay, max_ay + 1):
					for ax in range(min_ax, max_ax + 1):
						var dx := local_x - ax
						var dy := local_y - ay
						var allowed_list: Array = allowed_patterns[tile_key][dy][dx]
						if allowed_list.is_empty():
							return {"success": false}
						var wave_index := ay * grid_size.x + ax
						var current_patterns: Array = wave[wave_index]
						allowed_mask.fill(0)
						for allowed_index in allowed_list:
							allowed_mask[allowed_index] = 1
						var filtered_patterns: Array = []
						filtered_patterns.resize(current_patterns.size())
						var filtered_count := 0
						for candidate in current_patterns:
							if allowed_mask[candidate] != 0:
								filtered_patterns[filtered_count] = candidate
								filtered_count += 1
						filtered_patterns.resize(filtered_count)
						if filtered_patterns.is_empty():
							return {"success": false}
						if filtered_count != current_patterns.size():
							wave[wave_index] = filtered_patterns
							if not stack_lookup.has(wave_index):
								stack.append(wave_index)
								stack_lookup[wave_index] = true

	if not _propagate_constraints(wave, adjacency, grid_size, stack, allowed_mask):
		return {"success": false}

	while true:
		var next_index := _find_lowest_entropy(wave, rng)
		if next_index == -1:
			return {"success": true, "grid": wave}

		if wave[next_index].is_empty():
			return {"success": false}

		var chosen: int = _weighted_choice(wave[next_index], weights, rng)
		wave[next_index] = [chosen]
		stack.append(next_index)
		if step_callback.is_valid():
			step_callback.call(next_index, chosen)
			if step_delay > 0.0:
				await get_tree().create_timer(step_delay).timeout

		if not _propagate_constraints(wave, adjacency, grid_size, stack, allowed_mask):
			return {"success": false}

	return {"success": false}


func _propagate_constraints(
	wave: Array,
	adjacency: Array,
	grid_size: Vector2i,
	stack: Array,
	allowed_mask: PackedByteArray
) -> bool:
	while not stack.is_empty():
		var current_index: int = stack.pop_back()
		var current_pos: Vector2i = Vector2i(current_index % grid_size.x, current_index / grid_size.x)
		var current_patterns: Array = wave[current_index]

		for dir_index in range(DIRECTIONS.size()):
			var neighbor_pos: Vector2i = current_pos + DIRECTIONS[dir_index]
			if neighbor_pos.x < 0 or neighbor_pos.y < 0:
				continue
			if neighbor_pos.x >= grid_size.x or neighbor_pos.y >= grid_size.y:
				continue

			var neighbor_index: int = neighbor_pos.y * grid_size.x + neighbor_pos.x
			allowed_mask.fill(0)
			for pattern_index in current_patterns:
				for allowed_index in adjacency[pattern_index][dir_index]:
					allowed_mask[allowed_index] = 1

			var neighbor_patterns: Array = wave[neighbor_index]
			var filtered_patterns: Array = []
			filtered_patterns.resize(neighbor_patterns.size())
			var filtered_count := 0
			for candidate in neighbor_patterns:
				if allowed_mask[candidate] != 0:
					filtered_patterns[filtered_count] = candidate
					filtered_count += 1
			filtered_patterns.resize(filtered_count)
			var reduced: bool = filtered_count != neighbor_patterns.size()
			if reduced:
				wave[neighbor_index] = filtered_patterns
				neighbor_patterns = wave[neighbor_index]

			if neighbor_patterns.is_empty():
				return false

			if reduced:
				stack.append(neighbor_index)
	return true


func _generate_chunked_level(
	target_tilemap: TileMap,
	target_rect: Rect2i,
	patterns_data: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	if chunk_size <= 0:
		return false
	var radius := overlap_size - 1
	var chunks_x := int(ceil(float(target_rect.size.x) / float(chunk_size)))
	var chunks_y := int(ceil(float(target_rect.size.y) / float(chunk_size)))
	var allowed_patterns := _build_allowed_patterns_by_tile(patterns_data.patterns, overlap_size)
	var global_tiles: Dictionary = {}
	target_tilemap.clear()

	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var chunk_origin := target_rect.position + Vector2i(cx * chunk_size, cy * chunk_size)
			var interior_size := Vector2i(
				mini(chunk_size, target_rect.size.x - cx * chunk_size),
				mini(chunk_size, target_rect.size.y - cy * chunk_size)
			)
			var solve_origin := chunk_origin - Vector2i(radius, radius)
			var solve_size := Vector2i(chunk_size + 2 * radius, chunk_size + 2 * radius)
			var pattern_grid_size := Vector2i(
				solve_size.x - overlap_size + 1,
				solve_size.y - overlap_size + 1
			)
			if pattern_grid_size.x <= 0 or pattern_grid_size.y <= 0:
				return false

			var constraint_rects: Array[Rect2i] = []
			if cx > 0 and radius > 0:
				constraint_rects.append(Rect2i(solve_origin, Vector2i(radius, solve_size.y)))
			if cy > 0 and radius > 0:
				constraint_rects.append(Rect2i(solve_origin, Vector2i(solve_size.x, radius)))

			var attempt := 0
			var chunk_result: Dictionary = {}
			var chunk_success := false
			while attempt < max_attempts and not chunk_success:
				attempt += 1
				var local_rng := RandomNumberGenerator.new()
				local_rng.seed = rng.randi()
				chunk_result = await _run_wfc_with_constraints(
					patterns_data.patterns,
					patterns_data.weights,
					patterns_data.adjacency,
					pattern_grid_size,
					local_rng,
					allowed_patterns,
					global_tiles,
					solve_origin,
					constraint_rects
				)
				chunk_success = chunk_result.success

			if not chunk_success:
				return false

			var interior_rect := Rect2i(chunk_origin, interior_size)
			_commit_chunk_output(
				target_tilemap,
				patterns_data.patterns,
				patterns_data.tiles,
				chunk_result.grid,
				pattern_grid_size,
				solve_origin,
				interior_rect,
				global_tiles
			)
	return true


func _commit_chunk_output(
	target_tilemap: TileMap,
	patterns: Array,
	tile_data: Dictionary,
	grid: Array,
	grid_size: Vector2i,
	solve_origin: Vector2i,
	interior_rect: Rect2i,
	global_tiles: Dictionary
) -> void:
	var output_tiles: Dictionary = {}
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pattern_index: int = grid[y * grid_size.x + x][0]
			var pattern_tiles: Array = patterns[pattern_index]
			for dy in range(overlap_size):
				for dx in range(overlap_size):
					var tile_key: String = pattern_tiles[dy * overlap_size + dx]
					var tile_pos := solve_origin + Vector2i(x + dx, y + dy)
					if not interior_rect.has_point(tile_pos):
						continue
					if output_tiles.has(tile_pos):
						if output_tiles[tile_pos]["key"] != tile_key:
							_debug_log("WFC: tile conflict at %s." % tile_pos)
						continue
					var data: Dictionary = tile_data[tile_key]
					output_tiles[tile_pos] = {
						"key": tile_key,
						"source_id": data["source_id"],
						"atlas_coords": data["atlas_coords"],
						"alternative_tile": data["alternative_tile"],
					}

	for tile_pos in output_tiles.keys():
		var tile: Dictionary = output_tiles[tile_pos]
		global_tiles[tile_pos] = tile.key
		if tile.source_id == -1:
			target_tilemap.erase_cell(0, tile_pos)
			continue
		target_tilemap.set_cell(
			0,
			tile_pos,
			tile.source_id,
			tile.atlas_coords,
			tile.alternative_tile
		)


func _find_lowest_entropy(wave: Array, rng: RandomNumberGenerator) -> int:
	var best_entropy: float = INF
	var best_indices: Array = []
	for i in range(wave.size()):
		var entropy: int = wave[i].size()
		if entropy <= 1:
			continue
		if entropy < best_entropy:
			best_entropy = entropy
			best_indices.clear()
			best_indices.append(i)
		elif entropy == best_entropy:
			best_indices.append(i)

	if best_indices.is_empty():
		return -1
	return best_indices[rng.randi_range(0, best_indices.size() - 1)]


func _weighted_choice(options: Array, weights: Array, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for option in options:
		total += float(weights[option])

	var pick: float = rng.randf() * total
	var cumulative: float = 0.0
	for option in options:
		cumulative += float(weights[option])
		if pick <= cumulative:
			return option
	return options.back()


func _build_output_tiles(
	patterns: Array,
	tile_data: Dictionary,
	grid: Array,
	grid_size: Vector2i,
	target_rect: Rect2i,
	pattern_size: int
) -> Dictionary:
	var output_tiles: Dictionary = {}
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pattern_index: int = grid[y * grid_size.x + x][0]
			var pattern_tiles: Array = patterns[pattern_index]
			for dy in range(pattern_size):
				for dx in range(pattern_size):
					var tile_key: String = pattern_tiles[dy * pattern_size + dx]
					var tile_pos := target_rect.position + Vector2i(x + dx, y + dy)
					if output_tiles.has(tile_pos):
						if output_tiles[tile_pos]["key"] != tile_key:
							_debug_log("WFC: tile conflict at %s." % tile_pos)
						continue
					var data: Dictionary = tile_data[tile_key]
					output_tiles[tile_pos] = {
						"key": tile_key,
						"source_id": data["source_id"],
						"atlas_coords": data["atlas_coords"],
						"alternative_tile": data["alternative_tile"],
					}

	return output_tiles


func _apply_step_preview(
	target_tilemap: TileMap,
	patterns: Array,
	tile_data: Dictionary,
	grid_size: Vector2i,
	target_rect: Rect2i,
	pattern_size: int,
	cell_index: int,
	chosen_pattern: int
) -> void:
	var cell_pos := Vector2i(cell_index % grid_size.x, cell_index / grid_size.x)
	var pattern_tiles: Array = patterns[chosen_pattern]
	for dy in range(pattern_size):
		for dx in range(pattern_size):
			var tile_key: String = pattern_tiles[dy * pattern_size + dx]
			var tile_pos := target_rect.position + Vector2i(cell_pos.x + dx, cell_pos.y + dy)
			var data: Dictionary = tile_data[tile_key]
			if data["source_id"] == -1:
				target_tilemap.erase_cell(0, tile_pos)
				continue
			target_tilemap.set_cell(
				0,
				tile_pos,
				data["source_id"],
				data["atlas_coords"],
				data["alternative_tile"]
			)


func _tile_key(source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%s:%s:%s:%s" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]


func _empty_tile_key() -> String:
	return "empty"
