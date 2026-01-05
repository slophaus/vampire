extends Node
class_name WFCLevelGenerator

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if generate_on_ready:
		generate_level()


func generate_level() -> void:
	print_debug("WFC: starting level generation")
	var tilemap = _get_tilemap(target_tilemap_path)
	if tilemap == null:
		print_debug("WFC: no target tilemap found (assign target_tilemap_path or add a TileMap to the 'arena_tilemap' group)")
		return
	var sample_tilemap = _get_tilemap(sample_tilemap_path)
	if sample_tilemap == null:
		print_debug("WFC: no sample tilemap provided; using target tilemap")
		sample_tilemap = tilemap
	var sample_cells = sample_tilemap.get_used_cells(0)
	if sample_cells.is_empty():
		print_debug("WFC: sample tilemap has no used cells")
		return
	var cell_set: Dictionary = {}
	for cell in sample_cells:
		cell_set[cell] = true
	var sample_data = _collect_sample_data(sample_tilemap, sample_cells)
	var tile_variants: Array = sample_data["variants"]
	var tile_frequencies: Array = sample_data["frequencies"]
	var adjacency = sample_data["adjacency"]
	var attempt = 0
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	while attempt < max_attempts:
		print_debug("WFC: attempt %d/%d" % [attempt + 1, max_attempts])
		var collapsed = _run_wave_function_collapse(sample_cells, tile_variants.size(), tile_frequencies, adjacency)
		if not collapsed.is_empty():
			print_debug("WFC: collapsed %d tiles" % collapsed.size())
			_apply_collapsed_tiles(tilemap, collapsed, tile_variants)
			TileEater.initialize_dirt_border_for_tilemap(tilemap)
			print_debug("WFC: generation complete")
			return
		attempt += 1
	print_debug("WFC: failed to generate after %d attempts" % max_attempts)


func _collect_sample_data(sample_tilemap: TileMap, sample_cells: Array[Vector2i]) -> Dictionary:
	var tile_index_by_key: Dictionary = {}
	var tile_variants: Array = []
	var tile_frequencies: Array = []
	var adjacency: Array = []
	for _dir_index in range(DIRECTIONS.size()):
		adjacency.append([])
	for cell in sample_cells:
		var tile_key = _tile_key(sample_tilemap, cell)
		if not tile_index_by_key.has(tile_key):
			var variant = _tile_variant_from_cell(sample_tilemap, cell)
			tile_index_by_key[tile_key] = tile_variants.size()
			tile_variants.append(variant)
			tile_frequencies.append(0)
			for dir_index in range(DIRECTIONS.size()):
				adjacency[dir_index].append({})
		var index = tile_index_by_key[tile_key]
		tile_frequencies[index] += 1
	var cell_set: Dictionary = {}
	for cell in sample_cells:
		cell_set[cell] = true
	for cell in sample_cells:
		var tile_key = _tile_key(sample_tilemap, cell)
		var tile_index = tile_index_by_key[tile_key]
		for dir_index in range(DIRECTIONS.size()):
			var neighbor = cell + DIRECTIONS[dir_index]
			if not cell_set.has(neighbor):
				continue
			var neighbor_key = _tile_key(sample_tilemap, neighbor)
			var neighbor_index = tile_index_by_key[neighbor_key]
			adjacency[dir_index][tile_index][neighbor_index] = true
	return {
		"variants": tile_variants,
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
		if not _propagate_constraints(next_cell, possibilities, adjacency, tile_count):
			return {}
	if collapsed.size() < cells.size():
		for cell in cells:
			if collapsed.has(cell):
				continue
			var options = possibilities[cell] as Array
			if options.size() == 1:
				collapsed[cell] = options[0]
	return collapsed


func _propagate_constraints(start_cell: Vector2i, possibilities: Dictionary, adjacency: Array, tile_count: int) -> bool:
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
			var allowed = _collect_allowed_neighbors(current_options, adjacency, dir_index, tile_count)
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


func _collect_allowed_neighbors(current_options: Array, adjacency: Array, dir_index: int, tile_count: int) -> Dictionary:
	var allowed: Dictionary = {}
	for option in current_options:
		var neighbor_set = adjacency[dir_index][option]
		if neighbor_set.is_empty():
			for tile_index in range(tile_count):
				allowed[tile_index] = true
			return allowed
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


func _apply_collapsed_tiles(tilemap: TileMap, collapsed: Dictionary, tile_variants: Array) -> void:
	tilemap.clear()
	for cell in collapsed.keys():
		var variant = tile_variants[collapsed[cell]]
		tilemap.set_cell(0, cell, variant.source_id, variant.atlas_coords, variant.alternative)


func _tile_key(tilemap: TileMap, cell: Vector2i) -> String:
	var source_id = tilemap.get_cell_source_id(0, cell)
	var atlas_coords = tilemap.get_cell_atlas_coords(0, cell)
	var alternative = tilemap.get_cell_alternative_tile(0, cell)
	return "%s:%s:%s" % [source_id, atlas_coords, alternative]


func _tile_variant_from_cell(tilemap: TileMap, cell: Vector2i) -> Dictionary:
	return {
		"source_id": tilemap.get_cell_source_id(0, cell),
		"atlas_coords": tilemap.get_cell_atlas_coords(0, cell),
		"alternative": tilemap.get_cell_alternative_tile(0, cell),
	}


func _get_tilemap(path: NodePath) -> TileMap:
	if path == NodePath(""):
		for node in get_tree().get_nodes_in_group("arena_tilemap"):
			var tilemap := node as TileMap
			if tilemap != null and tilemap.is_inside_tree():
				return tilemap
		var fallback = _find_first_tilemap(get_tree().get_root())
		if fallback != null:
			return fallback
		return null
	var node = get_node_or_null(path)
	if node is TileMap:
		return node as TileMap
	return null


func _find_first_tilemap(root: Node) -> TileMap:
	if root is TileMap:
		return root as TileMap
	for child in root.get_children():
		var found = _find_first_tilemap(child)
		if found != null:
			return found
	return null
