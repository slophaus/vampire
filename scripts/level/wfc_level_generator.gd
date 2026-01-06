extends Node
class_name WFCLevelGenerator

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0
@export_range(1, 4, 1) var overlap_size := 2
@export var periodic_input := false
@export var show_step_by_step := false
@export_range(0.0, 5.0, 0.05) var step_delay_seconds := 0.0

const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


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
		print_debug("WFC: missing tilemap references.")
		return
	sample_tilemap.visible = false
	target_tilemap.visible = true

	var target_rect := target_tilemap.get_used_rect()
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		print_debug("WFC: target tilemap has no used tiles to define bounds.")
		return

	var sample_rect := sample_tilemap.get_used_rect()
	if sample_rect.size.x < overlap_size or sample_rect.size.y < overlap_size:
		print_debug("WFC: sample tilemap too small for overlap size.")
		return

	var rng := RandomNumberGenerator.new()
	if use_new_seed:
		rng.randomize()
	elif random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	var patterns_data: Dictionary = _build_patterns(sample_tilemap, sample_rect, overlap_size, periodic_input)
	print_debug("WFC: phase patterns %d ms" % (Time.get_ticks_msec() - phase_start_ms))
	phase_start_ms = Time.get_ticks_msec()
	if patterns_data.patterns.is_empty():
		print_debug("WFC: no patterns extracted from sample.")
		return

	var pattern_grid_size := Vector2i(
		target_rect.size.x - overlap_size + 1,
		target_rect.size.y - overlap_size + 1
	)
	if pattern_grid_size.x <= 0 or pattern_grid_size.y <= 0:
		print_debug("WFC: target bounds smaller than overlap size.")
		return

	var attempt := 0
	var result: Dictionary = {}
	while attempt < max_attempts:
		attempt += 1
		if attempt == 1 or attempt % 50 == 0:
			print_debug("WFC: attempt %d/%d" % [attempt, max_attempts])

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
		print_debug("WFC: failed after %d attempts." % max_attempts)
		return
	print_debug("WFC: phase solve %d ms" % (Time.get_ticks_msec() - phase_start_ms))
	phase_start_ms = Time.get_ticks_msec()

	var output_tiles: Dictionary = _build_output_tiles(
		patterns_data.patterns,
		patterns_data.tiles,
		result.grid,
		pattern_grid_size,
		target_rect,
		overlap_size
	)
	print_debug("WFC: phase output tiles %d ms" % (Time.get_ticks_msec() - phase_start_ms))
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

	if target_tilemap.has_meta(TileEater.DIRT_BORDER_META_KEY):
		target_tilemap.remove_meta(TileEater.DIRT_BORDER_META_KEY)
	TileEater.initialize_dirt_border_for_tilemap(target_tilemap)
	_move_entities_to_nearest_floor(target_tilemap)
	_position_level_doors(target_tilemap)

	print_debug("WFC: phase finalize %d ms" % (Time.get_ticks_msec() - phase_start_ms))
	print_debug("WFC: total time %d ms" % (Time.get_ticks_msec() - total_start_ms))
	print_debug("WFC: generation complete.")


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


func _position_level_doors(target_tilemap: TileMap) -> void:
	if target_tilemap == null:
		return
	var props_layer := get_parent().get_node_or_null("LayerProps")
	if props_layer == null:
		return
	var door_nodes: Array[Node2D] = []
	for child in props_layer.get_children():
		var node_2d := child as Node2D
		if node_2d == null:
			continue
		if not node_2d.is_in_group("doors"):
			continue
		door_nodes.append(node_2d)
	if door_nodes.size() < 2:
		return
	var walkable_cells := _get_walkable_cells(target_tilemap)
	if walkable_cells.is_empty():
		return
	var start_cell := _find_near_corner_floor_cell(target_tilemap, walkable_cells)
	var distances := _build_walkable_distance_field(walkable_cells, start_cell)
	var farthest_cell := _find_farthest_cell(distances, start_cell)
	door_nodes[0].global_position = _cell_to_world(target_tilemap, start_cell)
	door_nodes[1].global_position = _cell_to_world(target_tilemap, farthest_cell)


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


func _find_near_corner_floor_cell(target_tilemap: TileMap, walkable_cells: Dictionary) -> Vector2i:
	var used_rect := target_tilemap.get_used_rect()
	var corner := Vector2i(used_rect.position.x, used_rect.position.y + used_rect.size.y - 1)
	var best_cell: Vector2i = walkable_cells.keys()[0] as Vector2i
	var best_distance := INF
	for cell in walkable_cells.keys():
		var distance := corner.distance_squared_to(cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
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
	for child in props_layer.get_children():
		var node_2d := child as Node2D
		if node_2d == null:
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
					return {"success": false}

				if reduced:
					stack.append(neighbor_index)

	return {"success": false}


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
							print_debug("WFC: tile conflict at %s." % tile_pos)
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
