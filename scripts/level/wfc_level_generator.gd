extends Node
class_name WFCLevelGenerator

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0
@export_range(1, 4, 1) var overlap_size := 2

const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


func _ready() -> void:
	if generate_on_ready:
		generate_level()


func generate_level() -> void:
	var target_tilemap := get_node_or_null(target_tilemap_path) as TileMap
	var sample_tilemap := get_node_or_null(sample_tilemap_path) as TileMap
	if target_tilemap == null or sample_tilemap == null:
		print_debug("WFC: missing tilemap references.")
		return

	var target_rect := target_tilemap.get_used_rect()
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		print_debug("WFC: target tilemap has no used tiles to define bounds.")
		return

	var sample_rect := sample_tilemap.get_used_rect()
	if sample_rect.size.x < overlap_size or sample_rect.size.y < overlap_size:
		print_debug("WFC: sample tilemap too small for overlap size.")
		return

	var rng := RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	var patterns_data := _build_patterns(sample_tilemap, sample_rect, overlap_size)
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
	var result := {}
	while attempt < max_attempts:
		attempt += 1
		if attempt == 1 or attempt % 50 == 0:
			print_debug("WFC: attempt %d/%d" % [attempt, max_attempts])

		result = _run_wfc(
			patterns_data.patterns,
			patterns_data.weights,
			patterns_data.adjacency,
			pattern_grid_size,
			rng
		)

		if result.success:
			break

	if not result.success:
		print_debug("WFC: failed after %d attempts." % max_attempts)
		return

	var output_tiles := _build_output_tiles(
		patterns_data.patterns,
		patterns_data.tiles,
		result.grid,
		pattern_grid_size,
		target_rect,
		overlap_size
	)

	target_tilemap.clear()
	for tile_pos in output_tiles.keys():
		var tile := output_tiles[tile_pos]
		target_tilemap.set_cell(
			0,
			tile_pos,
			tile.source_id,
			tile.atlas_coords,
			tile.alternative_tile
		)

	print_debug("WFC: generation complete.")


func _build_patterns(sample_tilemap: TileMap, sample_rect: Rect2i, pattern_size: int) -> Dictionary:
	var pattern_map := {}
	var patterns := []
	var weights := []
	var tile_data := {}
	var pattern_limit := Vector2i(
		sample_rect.size.x - pattern_size + 1,
		sample_rect.size.y - pattern_size + 1
	)

	for y_offset in range(pattern_limit.y):
		for x_offset in range(pattern_limit.x):
			var tiles := []
			var valid := true
			for dy in range(pattern_size):
				for dx in range(pattern_size):
					var cell_pos := sample_rect.position + Vector2i(x_offset + dx, y_offset + dy)
					var source_id := sample_tilemap.get_cell_source_id(0, cell_pos)
					if source_id == -1:
						valid = false
						break
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
				var index := pattern_map[signature]
				weights[index] += 1

	var adjacency := _build_adjacency(patterns, pattern_size)

	return {
		"patterns": patterns,
		"weights": weights,
		"tiles": tile_data,
		"adjacency": adjacency,
	}


func _build_adjacency(patterns: Array, pattern_size: int) -> Array:
	var adjacency := []
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
	rng: RandomNumberGenerator
) -> Dictionary:
	var total_cells := grid_size.x * grid_size.y
	var wave := []
	var all_patterns := []
	for index in range(patterns.size()):
		all_patterns.append(index)

	for _i in range(total_cells):
		wave.append(all_patterns.duplicate())

	var stack := []

	while true:
		var next_index := _find_lowest_entropy(wave, rng)
		if next_index == -1:
			return {"success": true, "grid": wave}

		if wave[next_index].is_empty():
			return {"success": false}

		var chosen := _weighted_choice(wave[next_index], weights, rng)
		wave[next_index] = [chosen]
		stack.append(next_index)

		while not stack.is_empty():
			var current_index := stack.pop_back()
			var current_pos := Vector2i(current_index % grid_size.x, current_index / grid_size.x)
			var current_patterns := wave[current_index]

			for dir_index in range(DIRECTIONS.size()):
				var neighbor_pos := current_pos + DIRECTIONS[dir_index]
				if neighbor_pos.x < 0 or neighbor_pos.y < 0:
					continue
				if neighbor_pos.x >= grid_size.x or neighbor_pos.y >= grid_size.y:
					continue

				var neighbor_index := neighbor_pos.y * grid_size.x + neighbor_pos.x
				var allowed := {}
				for pattern_index in current_patterns:
					for allowed_index in adjacency[pattern_index][dir_index]:
						allowed[allowed_index] = true

				var neighbor_patterns := wave[neighbor_index]
				var reduced := false
				for candidate in neighbor_patterns.duplicate():
					if not allowed.has(candidate):
						neighbor_patterns.erase(candidate)
						reduced = true

				if neighbor_patterns.is_empty():
					return {"success": false}

				if reduced:
					stack.append(neighbor_index)

	return {"success": false}


func _find_lowest_entropy(wave: Array, rng: RandomNumberGenerator) -> int:
	var best_entropy := INF
	var best_indices := []
	for i in range(wave.size()):
		var entropy := wave[i].size()
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
	var total := 0.0
	for option in options:
		total += float(weights[option])

	var pick := rng.randf() * total
	var cumulative := 0.0
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
	var output_tiles := {}
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pattern_index := grid[y * grid_size.x + x][0]
			var pattern_tiles := patterns[pattern_index]
			for dy in range(pattern_size):
				for dx in range(pattern_size):
					var tile_key := pattern_tiles[dy * pattern_size + dx]
					var tile_pos := target_rect.position + Vector2i(x + dx, y + dy)
					if output_tiles.has(tile_pos):
						if output_tiles[tile_pos]["key"] != tile_key:
							print_debug("WFC: tile conflict at %s." % tile_pos)
						continue
					var data := tile_data[tile_key]
					output_tiles[tile_pos] = {
						"key": tile_key,
						"source_id": data["source_id"],
						"atlas_coords": data["atlas_coords"],
						"alternative_tile": data["alternative_tile"],
					}

	return output_tiles


func _tile_key(source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%s:%s:%s:%s" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]
