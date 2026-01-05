extends Node
class_name WFCLevelGenerator

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0
@export_range(1, 4, 1) var overlap_size := 2

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if generate_on_ready:
		generate_level()


func generate_level() -> void:
	print_debug("WFC: starting level generation")
	var tilemap = _get_tilemap(target_tilemap_path)
	if tilemap == null:
		print_debug("WFC: no target tilemap found (assign target_tilemap_path on the generator)")
		return
	var target_cells = tilemap.get_used_cells(0)
	if target_cells.is_empty():
		print_debug("WFC: target tilemap has no used cells")
		return
	var pattern_size = max(1, overlap_size)
	var target_rect = tilemap.get_used_rect()
	var pattern_cells = _collect_pattern_cells(pattern_size, target_rect)
	if pattern_cells.is_empty():
		print_debug("WFC: target tilemap has no cells that fit pattern size %d" % pattern_size)
		return
	var sample_tilemap = _get_tilemap(sample_tilemap_path)
	if sample_tilemap == null:
		print_debug("WFC: no sample tilemap provided; using target tilemap")
		sample_tilemap = tilemap
	var sample_cells = sample_tilemap.get_used_cells(0)
	if sample_cells.is_empty():
		print_debug("WFC: sample tilemap has no used cells")
		return
	var sample_rect = sample_tilemap.get_used_rect()
	var sample_data = _collect_sample_data(sample_tilemap, sample_cells, pattern_size, sample_rect)
	var tile_patterns: Array = sample_data["patterns"]
	var tile_frequencies: Array = sample_data["frequencies"]
	var adjacency = sample_data["adjacency"]
	if tile_patterns.is_empty():
		print_debug("WFC: sample tilemap has no patterns for size %d" % pattern_size)
		return
	var attempt = 0
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	while attempt < max_attempts:
		var collapsed = _run_wave_function_collapse(pattern_cells, tile_patterns.size(), tile_frequencies, adjacency)
		if not collapsed.is_empty():
			print_debug("WFC: collapsed %d tiles" % collapsed.size())
			_apply_collapsed_tiles(tilemap, collapsed, tile_patterns, pattern_size)
			TileEater.initialize_dirt_border_for_tilemap(tilemap)
			print_debug("WFC: generation complete after %d attempts" % [attempt + 1])
			return
		attempt += 1
	print_debug("WFC: failed to generate after %d attempts" % max_attempts)


func _collect_sample_data(sample_tilemap: TileMap, sample_cells: Array[Vector2i], pattern_size: int, sample_rect: Rect2i) -> Dictionary:
	var pattern_index_by_key: Dictionary = {}
	var tile_patterns: Array = []
	var tile_frequencies: Array = []
	var pattern_cells = _collect_pattern_cells(pattern_size, sample_rect)
	for cell in pattern_cells:
		var pattern = _pattern_from_cell(sample_tilemap, cell, pattern_size)
		var pattern_key = _pattern_key(pattern)
		if not pattern_index_by_key.has(pattern_key):
			pattern_index_by_key[pattern_key] = tile_patterns.size()
			tile_patterns.append(pattern)
			tile_frequencies.append(0)
		var index = pattern_index_by_key[pattern_key]
		tile_frequencies[index] += 1
	var adjacency: Array = []
	for _dir_index in range(DIRECTIONS.size()):
		adjacency.append([])
	for _pattern_index in range(tile_patterns.size()):
		for dir_index in range(DIRECTIONS.size()):
			adjacency[dir_index].append({})
	for pattern_index in range(tile_patterns.size()):
		for neighbor_index in range(tile_patterns.size()):
			for dir_index in range(DIRECTIONS.size()):
				if _patterns_match_overlap(tile_patterns[pattern_index], tile_patterns[neighbor_index], DIRECTIONS[dir_index], pattern_size):
					adjacency[dir_index][pattern_index][neighbor_index] = true
	return {
		"patterns": tile_patterns,
		"frequencies": tile_frequencies,
		"adjacency": adjacency,
	}


func _run_wave_function_collapse(cells: Array[Vector2i], tile_count: int, frequencies: Array, adjacency: Array) -> Dictionary:
	var possibilities: Dictionary = {}
	for cell in cells:
		possibilities[cell] = _make_full_possibilities(tile_count)
	var collapsed: Dictionary = {}
	while collapsed.size() < cells.size():
		var next_cell = _find_lowest_entropy_cell(cells, possibilities)
		if next_cell == null:
			break
		var options = possibilities[next_cell] as Array
		if options.is_empty():
			return {}
		var chosen = _choose_weighted_tile(options, frequencies)
		possibilities[next_cell] = [chosen]
		collapsed[next_cell] = chosen
		if not _propagate_constraints(next_cell, possibilities, adjacency):
			return {}
	if collapsed.size() < cells.size():
		for cell in cells:
			if collapsed.has(cell):
				continue
			var options = possibilities[cell] as Array
			if options.size() == 1:
				collapsed[cell] = options[0]
	return collapsed


func _propagate_constraints(start_cell: Vector2i, possibilities: Dictionary, adjacency: Array) -> bool:
	var stack: Array[Vector2i] = [start_cell]
	while not stack.is_empty():
		var current = stack.pop_back()
		var current_options = possibilities[current] as Array
		for dir_index in range(DIRECTIONS.size()):
			var neighbor = current + DIRECTIONS[dir_index]
			if not possibilities.has(neighbor):
				continue
			var neighbor_options = possibilities[neighbor] as Array
			if neighbor_options.is_empty():
				return false
			var allowed = _collect_allowed_neighbors(current_options, adjacency, dir_index)
			var filtered: Array = []
			for option in neighbor_options:
				if allowed.has(option):
					filtered.append(option)
			if filtered.size() == neighbor_options.size():
				continue
			if filtered.is_empty():
				return false
			possibilities[neighbor] = filtered
			stack.append(neighbor)
	return true


func _collect_allowed_neighbors(current_options: Array, adjacency: Array, dir_index: int) -> Dictionary:
	var allowed: Dictionary = {}
	for option in current_options:
		var neighbor_set = adjacency[dir_index][option]
		for neighbor_index in neighbor_set.keys():
			allowed[neighbor_index] = true
	return allowed


func _find_lowest_entropy_cell(cells: Array[Vector2i], possibilities: Dictionary) -> Variant:
	var best_cell = null
	var best_entropy = INF
	for cell in cells:
		var options = possibilities[cell] as Array
		var entropy = options.size()
		if entropy <= 1:
			continue
		if entropy < best_entropy:
			best_entropy = entropy
			best_cell = cell
	return best_cell


func _choose_weighted_tile(options: Array, frequencies: Array) -> int:
	var total_weight = 0
	for option in options:
		total_weight += int(frequencies[option])
	if total_weight <= 0:
		return options[_rng.randi_range(0, options.size() - 1)]
	var roll = _rng.randi_range(1, total_weight)
	for option in options:
		roll -= int(frequencies[option])
		if roll <= 0:
			return option
	return options[options.size() - 1]


func _make_full_possibilities(tile_count: int) -> Array:
	var options: Array = []
	options.resize(tile_count)
	for i in range(tile_count):
		options[i] = i
	return options


func _apply_collapsed_tiles(tilemap: TileMap, collapsed: Dictionary, tile_patterns: Array, pattern_size: int) -> void:
	tilemap.clear()
	for cell in collapsed.keys():
		var pattern = tile_patterns[collapsed[cell]]
		for y in range(pattern_size):
			for x in range(pattern_size):
				var variant = pattern["variants"][y * pattern_size + x]
				if variant.source_id == -1:
					continue
				var target_cell = cell + Vector2i(x, y)
				tilemap.set_cell(0, target_cell, variant.source_id, variant.atlas_coords, variant.alternative)


func _tile_key(tilemap: TileMap, cell: Vector2i) -> String:
	var source_id = tilemap.get_cell_source_id(0, cell)
	if source_id == -1:
		return "empty"
	var tile_data := tilemap.get_cell_tile_data(0, cell)
	if tile_data != null and tile_data.terrain_set >= 0:
		return "%s:terrain:%s:%s" % [source_id, tile_data.terrain_set, tile_data.terrain]
	var atlas_coords = tilemap.get_cell_atlas_coords(0, cell)
	var alternative = tilemap.get_cell_alternative_tile(0, cell)
	return "%s:%s:%s" % [source_id, atlas_coords, alternative]


func _tile_variant_from_cell(tilemap: TileMap, cell: Vector2i) -> Dictionary:
	return {
		"source_id": tilemap.get_cell_source_id(0, cell),
		"atlas_coords": tilemap.get_cell_atlas_coords(0, cell),
		"alternative": tilemap.get_cell_alternative_tile(0, cell),
	}


func _pattern_from_cell(tilemap: TileMap, cell: Vector2i, pattern_size: int) -> Dictionary:
	var keys: Array = []
	var variants: Array = []
	keys.resize(pattern_size * pattern_size)
	variants.resize(pattern_size * pattern_size)
	for y in range(pattern_size):
		for x in range(pattern_size):
			var offset = Vector2i(x, y)
			var index = y * pattern_size + x
			keys[index] = _tile_key(tilemap, cell + offset)
			variants[index] = _tile_variant_from_cell(tilemap, cell + offset)
	return {
		"keys": keys,
		"variants": variants,
	}


func _pattern_key(pattern: Dictionary) -> String:
	return "|".join(pattern["keys"])


func _patterns_match_overlap(pattern_a: Dictionary, pattern_b: Dictionary, direction: Vector2i, pattern_size: int) -> bool:
	var keys_a: Array = pattern_a["keys"]
	var keys_b: Array = pattern_b["keys"]
	for y in range(pattern_size):
		for x in range(pattern_size):
			var bx = x - direction.x
			var by = y - direction.y
			if bx < 0 or bx >= pattern_size or by < 0 or by >= pattern_size:
				continue
			if keys_a[y * pattern_size + x] != keys_b[by * pattern_size + bx]:
				return false
	return true

func _collect_pattern_cells(pattern_size: int, used_rect: Rect2i) -> Array[Vector2i]:
	var pattern_cells: Array[Vector2i] = []
	if used_rect.size.x < pattern_size or used_rect.size.y < pattern_size:
		return pattern_cells
	var min_pos = used_rect.position
	var max_pos = used_rect.position + used_rect.size - Vector2i(pattern_size, pattern_size)
	for y in range(min_pos.y, max_pos.y + 1):
		for x in range(min_pos.x, max_pos.x + 1):
			pattern_cells.append(Vector2i(x, y))
	return pattern_cells


func _get_tilemap(path: NodePath) -> TileMap:
	if path == NodePath(""):
		return null
	var node = get_node_or_null(path)
	if node is TileMap:
		return node as TileMap
	return null
