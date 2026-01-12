extends Node
class_name WFCLevelGenerator

@export_category("Tilemaps")
@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath

@export_category("Generation")
@export var generate_on_ready := true
@export_range(1, 4, 1) var overlap_size := 2
@export var periodic_input := true
@export var use_chunked_wfc := true
@export_range(4, 256, 1) var chunk_size := 10
@export var ignore_chunk_borders := false
@export var max_attempts_per_solve := 1 # Attempts per chunk (or per full solve when not chunked).

@export_category("Randomness")
@export var use_fixed_seed := true
@export var fixed_seed := 6

@export_category("Time Budget")
@export var time_budget_seconds := 30.0
@export_enum("dirt", "most_common", "least_common", "random_tile", "random_same", "random_top_three") var time_budget_timeout_tile := "dirt"
@export var enable_backtracking := true
@export_range(0, 10000, 1) var max_backtracks := 50

@export_category("Debug")
@export var debug := true
const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
const DEBUG_DOOR_PATH_NAME := "DoorDebugPath"
const DEBUG_DOOR_PATH_WIDTH := 4.0
const DEBUG_DOOR_PATH_Z_INDEX := 10
const DEBUG_DOOR_PATH_COLOR := Color(1, 0, 0, 1)
const DEBUG_CONTRADICTION_DOTS_NAME := "WFCContradictionDots"
const DEBUG_CONTRADICTION_COLOR := Color(1, 0, 0, 1)
var _largest_walkable_cells: Dictionary = {}


class DebugContradictionDots:
	extends Node2D

	var points: Array[Vector2] = []
	var radius := 2.0
	var color := Color(1, 0, 0, 1)

	func set_points(new_points: Array[Vector2]) -> void:
		points = new_points
		queue_redraw()

	func clear_points() -> void:
		points.clear()
		queue_redraw()

	func _draw() -> void:
		for point in points:
			draw_circle(point, radius, color)


func _debug_log(message: String) -> void:
	if not debug:
		return
	print(message)


func _report_generation_failure(message: String) -> void:
	_debug_log(message)
	print("generation fail")


func _elapsed_seconds(start_ms: int) -> float:
	return float(Time.get_ticks_msec() - start_ms) / 1000.0


func _ready() -> void:
	set_process_unhandled_input(true)
	if GameEvents != null:
		GameEvents.debug_mode_toggled.connect(_on_debug_mode_toggled)
		_on_debug_mode_toggled(GameEvents.debug_mode_enabled)
	if generate_on_ready:
		generate_level()


func generate_level(use_new_seed: bool = false) -> void:
	var total_start_ms := Time.get_ticks_msec()
	var phase_start_ms := total_start_ms
	var patterns_seconds := 0.0
	var solve_seconds := 0.0
	var output_seconds := 0.0
	var finalize_seconds := 0.0
	var total_seconds := 0.0
	var solve_backtracks := 0
	var chunk_total := 0
	var chunk_solved := 0
	var target_tilemap := get_node_or_null(target_tilemap_path) as TileMap
	var sample_tilemap := get_node_or_null(sample_tilemap_path) as TileMap
	if target_tilemap == null or sample_tilemap == null:
		_report_generation_failure("WFC: missing tilemap references.")
		return
	_reset_debug_contradiction_dots()
	sample_tilemap.visible = false
	target_tilemap.visible = true

	var target_rect := target_tilemap.get_used_rect()
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		_report_generation_failure("WFC: target tilemap has no used tiles to define bounds.")
		return

	var sample_rect := sample_tilemap.get_used_rect()
	if sample_rect.size.x < overlap_size or sample_rect.size.y < overlap_size:
		_report_generation_failure("WFC: sample tilemap too small for overlap size.")
		return

	var rng := RandomNumberGenerator.new()
	if use_new_seed or not use_fixed_seed:
		rng.randomize()
	elif fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()

	var patterns_data: Dictionary = _build_patterns(sample_tilemap, sample_rect, overlap_size, periodic_input)
	patterns_seconds = _elapsed_seconds(phase_start_ms)
	_debug_log("WFC: phase patterns %.3f s" % patterns_seconds)
	phase_start_ms = Time.get_ticks_msec()
	if patterns_data.patterns.is_empty():
		_report_generation_failure("WFC: no patterns extracted from sample.")
		return

	var pattern_grid_size := Vector2i(
		target_rect.size.x - overlap_size + 1,
		target_rect.size.y - overlap_size + 1
	)
	if pattern_grid_size.x <= 0 or pattern_grid_size.y <= 0:
		_report_generation_failure("WFC: target bounds smaller than overlap size.")
		return

	var output_tiles: Dictionary = {}
	var timed_out := false
	var contradiction_cells: Array[Vector2i] = []
	var sample_tiles := _build_sample_tiles(patterns_data.tiles)
	if use_chunked_wfc:
		var chunk_result := await _run_chunked_wfc(
			patterns_data.patterns,
			patterns_data.weights,
			patterns_data.adjacency,
			target_rect,
			rng,
			time_budget_seconds,
			enable_backtracking,
			max_backtracks,
			sample_tiles,
			patterns_data.tiles,
			patterns_data.tile_counts
		)
		if not chunk_result.success:
			_report_generation_failure("WFC: chunked solve failed.")
			return
		output_tiles = chunk_result.output_tiles
		timed_out = chunk_result.timed_out
		contradiction_cells = _as_vector2i_array(chunk_result.get("contradiction_cells", []))
		solve_backtracks = chunk_result.get("backtracks", 0)
		chunk_total = chunk_result.get("chunk_total", 0)
		chunk_solved = chunk_result.get("chunk_solved", 0)
		if chunk_result.get("partial", false):
			_debug_log("WFC: chunked solve incomplete; using solved chunks only.")
	else:
		var attempt := 0
		var result: Dictionary = {}
		var last_contradiction_cells: Array[Vector2i] = []
		while attempt < max_attempts_per_solve:
			attempt += 1
			if attempt == 1 or attempt % 50 == 0:
				_debug_log("WFC: attempt %d/%d" % [attempt, max_attempts_per_solve])
			var attempt_start_ms := Time.get_ticks_msec()

			result = await _run_wfc(
				patterns_data.patterns,
				patterns_data.weights,
				patterns_data.adjacency,
				pattern_grid_size,
				rng,
				time_budget_seconds,
				enable_backtracking,
				max_backtracks
			)
			var attempt_seconds := _elapsed_seconds(attempt_start_ms)
			var attempt_status: String = str(result.get("status", "unknown"))
			_debug_log("WFC: attempt %d result %s in %.3f s (total %.3f s)." % [
				attempt,
				attempt_status,
				attempt_seconds,
				_elapsed_seconds(total_start_ms)
			])

			timed_out = result.get("timed_out", false)
			if timed_out:
				_debug_log("WFC: time budget exceeded after %.3f s." % result.get("elapsed_seconds", 0.0))
				break

			if result.success:
				break
			if attempt_status == "contradiction":
				last_contradiction_cells = _as_vector2i_array(result.get("contradiction_cells", []))

		if not result.success and not timed_out:
			contradiction_cells = _offset_cells(last_contradiction_cells, target_rect.position)
			_update_debug_contradiction_dots(target_tilemap, contradiction_cells)
			_report_generation_failure("WFC: failed after %d attempts." % max_attempts_per_solve)
			return
		if timed_out:
			output_tiles = _build_output_tiles_partial(
				patterns_data.patterns,
				patterns_data.tiles,
				result.grid,
				pattern_grid_size,
				target_rect,
				overlap_size
			)
			var timeout_mode := time_budget_timeout_tile
			_fill_missing_tiles_with_timeout_mode(
				target_tilemap,
				target_rect,
				output_tiles,
				sample_tiles,
				patterns_data.tiles,
				patterns_data.tile_counts,
				rng,
				timeout_mode
			)
		else:
			output_tiles = _build_output_tiles(
				patterns_data.patterns,
				patterns_data.tiles,
				result.grid,
				pattern_grid_size,
				target_rect,
				overlap_size
			)
		solve_backtracks = result.get("backtracks", 0)
	if not contradiction_cells.is_empty():
		_update_debug_contradiction_dots(target_tilemap, contradiction_cells)
	solve_seconds = _elapsed_seconds(phase_start_ms)
	_debug_log("WFC: phase solve %.3f s" % solve_seconds)
	phase_start_ms = Time.get_ticks_msec()

	if timed_out:
		_debug_log("WFC: time budget exceeded; filled remaining tiles with fallback mode.")
	output_seconds = _elapsed_seconds(phase_start_ms)
	_debug_log("WFC: phase output tiles %.3f s" % output_seconds)
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

	_set_border_tiles_to_wall(target_tilemap, target_rect)
	_refresh_largest_walkable_cells(target_tilemap)
	_position_level_doors(target_tilemap, rng)
	if target_tilemap.has_meta(TileEater.DIRT_BORDER_META_KEY):
		target_tilemap.remove_meta(TileEater.DIRT_BORDER_META_KEY)
	TileEater.initialize_dirt_border_for_tilemap(target_tilemap)

	finalize_seconds = _elapsed_seconds(phase_start_ms)
	total_seconds = _elapsed_seconds(total_start_ms)
	_debug_log("WFC: phase finalize %.3f s" % finalize_seconds)
	var summary_parts: Array[String] = [
		"patterns %.3f s" % patterns_seconds,
		"solve %.3f s" % solve_seconds,
		"output %.3f s" % output_seconds,
		"finalize %.3f s" % finalize_seconds
	]
	if use_chunked_wfc and chunk_total > 0:
		summary_parts.append("chunks %d/%d" % [chunk_solved, chunk_total])
	if enable_backtracking:
		summary_parts.append("backtracks %d" % solve_backtracks)
	_debug_log("WFC: summary %s." % ", ".join(summary_parts))
	_debug_log("WFC: generation complete.")
	print("generation time: %.3f sec" % total_seconds)


func _unhandled_input(event: InputEvent) -> void:
	if not GameEvents.debug_mode_enabled:
		return
	if event.is_action_pressed("debug_regen_wfc"):
		generate_level(true)


func _on_debug_mode_toggled(enabled: bool) -> void:
	debug = enabled
	if not debug:
		_reset_debug_door_path()
		_reset_debug_contradiction_dots()


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
	var walkable_cells := _largest_walkable_cells
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
	_debug_log("WFC: door placement choosing cells %s (start) and %s." % [
		start_cell,
		farthest_cell
	])
	_debug_log("WFC: door placement path length %d." % max(path_cells.size() - 1, 0))
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


func _refresh_largest_walkable_cells(target_tilemap: TileMap) -> void:
	_largest_walkable_cells.clear()
	if target_tilemap == null:
		return
	var walkable_cells := _get_walkable_cells(target_tilemap)
	if walkable_cells.is_empty():
		return
	var visited: Dictionary = {}
	var largest_component: Dictionary = {}
	for cell in walkable_cells.keys():
		if visited.has(cell):
			continue
		var component: Dictionary = {}
		var queue: Array[Vector2i] = [cell]
		visited[cell] = true
		component[cell] = true
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front() as Vector2i
			for direction in DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if not walkable_cells.has(neighbor):
					continue
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				component[neighbor] = true
				queue.append(neighbor)
		if component.size() > largest_component.size():
			largest_component = component
	_largest_walkable_cells = largest_component


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
	var debug_line := _get_or_create_debug_door_path_line()
	if debug_line == null:
		return
	debug_line.clear_points()
	debug_line.visible = false


func _reset_debug_contradiction_dots() -> void:
	var dots := _get_or_create_debug_contradiction_dots()
	if dots == null:
		return
	dots.clear_points()
	dots.visible = false


func _update_debug_door_path(
	target_tilemap: TileMap,
	path_cells: Array[Vector2i]
) -> void:
	var debug_line := _get_or_create_debug_door_path_line()
	if debug_line == null:
		return
	debug_line.clear_points()
	if not debug:
		debug_line.visible = false
		return
	if path_cells.is_empty():
		debug_line.visible = false
		return
	for cell in path_cells:
		debug_line.add_point(target_tilemap.map_to_local(cell))
	debug_line.visible = true


func _update_debug_contradiction_dots(
	target_tilemap: TileMap,
	contradiction_cells: Array[Vector2i]
) -> void:
	var dots := _get_or_create_debug_contradiction_dots()
	if dots == null:
		return
	dots.clear_points()
	if not debug:
		dots.visible = false
		return
	if contradiction_cells.is_empty():
		dots.visible = false
		return
	var positions: Array[Vector2] = []
	for cell in contradiction_cells:
		positions.append(target_tilemap.map_to_local(cell))
	dots.set_points(positions)
	dots.visible = true


func _get_or_create_debug_door_path_line() -> Line2D:
	var blood_layer := get_parent().get_node_or_null("LayerBlood")
	if blood_layer == null:
		return null
	var debug_line := blood_layer.get_node_or_null(DEBUG_DOOR_PATH_NAME) as Line2D
	if debug_line != null:
		return debug_line
	debug_line = Line2D.new()
	debug_line.name = DEBUG_DOOR_PATH_NAME
	debug_line.visible = false
	debug_line.z_index = DEBUG_DOOR_PATH_Z_INDEX
	debug_line.width = DEBUG_DOOR_PATH_WIDTH
	debug_line.default_color = DEBUG_DOOR_PATH_COLOR
	blood_layer.add_child(debug_line)
	return debug_line


func _get_or_create_debug_contradiction_dots() -> DebugContradictionDots:
	var blood_layer := get_parent().get_node_or_null("LayerBlood")
	if blood_layer == null:
		return null
	var dots := blood_layer.get_node_or_null(DEBUG_CONTRADICTION_DOTS_NAME) as DebugContradictionDots
	if dots != null:
		return dots
	dots = DebugContradictionDots.new()
	dots.name = DEBUG_CONTRADICTION_DOTS_NAME
	dots.visible = false
	dots.z_index = DEBUG_DOOR_PATH_Z_INDEX
	dots.radius = DEBUG_DOOR_PATH_WIDTH * 0.5
	dots.color = DEBUG_CONTRADICTION_COLOR
	blood_layer.add_child(dots)
	return dots


func _cells_to_lookup(cells: Array[Vector2i]) -> Dictionary:
	var lookup: Dictionary = {}
	for cell in cells:
		lookup[cell] = true
	return lookup


func _as_vector2i_array(values: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for value in values:
		typed.append(value)
	return typed


func _offset_cells(cells: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	var offset_cells: Array[Vector2i] = []
	for cell in cells:
		offset_cells.append(cell + offset)
	return offset_cells


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
		"tile_counts": _build_tile_counts(sample_tilemap, sample_rect),
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


func _run_chunked_wfc(
	patterns: Array,
	weights: Array,
	adjacency: Array,
	target_rect: Rect2i,
	rng: RandomNumberGenerator,
	time_budget_seconds: float,
	allow_backtracking: bool,
	max_backtracks: int,
	sample_tiles: Array[Dictionary],
	tile_data: Dictionary,
	tile_counts: Dictionary
) -> Dictionary:
	var adjusted_chunk_size: int = max(chunk_size, overlap_size)
	var chunk_rects := _build_chunk_rects(target_rect, adjusted_chunk_size, overlap_size)
	if chunk_rects.is_empty():
		_debug_log("WFC: chunked solve found no chunks.")
		return {"success": false}
	var chunk_coords: Array[Vector2i] = []
	for key in chunk_rects.keys():
		chunk_coords.append(key)
	chunk_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	var chunk_index_by_coord: Dictionary = {}
	for i in range(chunk_coords.size()):
		chunk_index_by_coord[chunk_coords[i]] = i + 1
	var total_chunks := chunk_coords.size()
	var remaining: Array[Vector2i] = []
	for key in chunk_coords:
		remaining.append(key)
	var solved: Dictionary = {}
	var output_tiles: Dictionary = {}
	var timed_out := false
	var failed: Array[Vector2i] = []
	var solved_count := 0
	var solved_with_borders := 0
	var timed_out_with_borders := 0
	var backtracks_total := 0
	var contradiction_cells: Array[Vector2i] = []

	while not remaining.is_empty():
		var next_coord := _pick_next_chunk_coord(remaining, solved, rng)
		var chunk_rect: Rect2i = chunk_rects[next_coord]
		var chunk_index: int = chunk_index_by_coord[next_coord]
		var chunk_label := "chunk %d/%d" % [chunk_index, total_chunks]
		_debug_log("WFC: %s at %s." % [chunk_label, chunk_rect])
		var grid_size := Vector2i(
			chunk_rect.size.x - overlap_size + 1,
			chunk_rect.size.y - overlap_size + 1
		)
		if grid_size.x <= 0 or grid_size.y <= 0:
			_debug_log("WFC: chunk too small for overlap size at %s." % chunk_rect)
			return {"success": false}

		var attempt := 0
		var result: Dictionary = {}
		var chunk_timed_out := false
		var constraints_invalid := false
		var chunk_contradiction_cells: Array[Vector2i] = []
		while attempt < max_attempts_per_solve:
			attempt += 1
			var initial_wave: Array = []
			if not ignore_chunk_borders:
				var known_tiles := _collect_known_tiles(output_tiles, chunk_rect)
				initial_wave = _build_constrained_wave(
					patterns,
					chunk_rect,
					grid_size,
					overlap_size,
					known_tiles
				)
				if initial_wave.is_empty():
					_debug_log("WFC: chunked constraints invalid for %s; marking for border-ignored retry." % chunk_rect)
					constraints_invalid = true
					break
			result = await _run_wfc(
				patterns,
				weights,
				adjacency,
				grid_size,
				rng,
				time_budget_seconds,
				allow_backtracking,
				max_backtracks,
				initial_wave
			)
			if result.get("status", "") == "contradiction":
				chunk_contradiction_cells = _as_vector2i_array(result.get("contradiction_cells", []))
			chunk_timed_out = result.get("timed_out", false)
			backtracks_total += result.get("backtracks", 0)
			if chunk_timed_out or result.success:
				break
		if constraints_invalid:
			failed.append(next_coord)
			solved[next_coord] = false
			remaining.erase(next_coord)
			continue
		if not result.success and not chunk_timed_out:
			if not chunk_contradiction_cells.is_empty():
				contradiction_cells.append_array(_offset_cells(chunk_contradiction_cells, chunk_rect.position))
			_debug_log("WFC: %s solve failed after %d attempts at %s; marking for border-ignored retry." % [
				chunk_label,
				max_attempts_per_solve,
				chunk_rect
			])
			failed.append(next_coord)
			solved[next_coord] = false
			remaining.erase(next_coord)
			continue

		if chunk_timed_out:
			timed_out = true
			timed_out_with_borders += 1
			var partial_tiles := _build_output_tiles_partial(
				patterns,
				tile_data,
				result.grid,
				grid_size,
				chunk_rect,
				overlap_size
			)
			_merge_output_tiles(output_tiles, partial_tiles, chunk_label, contradiction_cells)
			_fill_missing_tiles_with_timeout_mode(
				get_node_or_null(target_tilemap_path) as TileMap,
				chunk_rect,
				output_tiles,
				sample_tiles,
				tile_data,
				tile_counts,
				rng,
				time_budget_timeout_tile
			)
		else:
			solved_with_borders += 1
			var chunk_tiles := _build_output_tiles(
				patterns,
				tile_data,
				result.grid,
				grid_size,
				chunk_rect,
				overlap_size
			)
			_merge_output_tiles(output_tiles, chunk_tiles, chunk_label, contradiction_cells)
		solved_count += 1

		solved[next_coord] = true
		remaining.erase(next_coord)

	_debug_log("WFC: chunked pass complete: %d/%d solved with borders, %d timed out, %d queued for border-ignored retry." % [
		solved_with_borders,
		total_chunks,
		timed_out_with_borders,
		failed.size()
	])

	if not failed.is_empty():
		var retry_solved := 0
		var retry_timed_out := 0
		var retry_failed := 0
		var retry_conflict_total := 0
		var retry_conflict_chunks := 0
		_debug_log("WFC: retrying %d failed chunks with ignored borders." % failed.size())
		for chunk_coord in failed:
			var chunk_rect: Rect2i = chunk_rects[chunk_coord]
			var chunk_index: int = chunk_index_by_coord[chunk_coord]
			var chunk_label := "chunk %d/%d" % [chunk_index, total_chunks]
			_debug_log("WFC: %s retrying with ignored borders at %s." % [chunk_label, chunk_rect])
			var grid_size := Vector2i(
				chunk_rect.size.x - overlap_size + 1,
				chunk_rect.size.y - overlap_size + 1
			)
			if grid_size.x <= 0 or grid_size.y <= 0:
				_debug_log("WFC: chunk too small for overlap size at %s." % chunk_rect)
				return {
					"success": true,
					"output_tiles": output_tiles,
					"timed_out": timed_out,
					"partial": true,
					"chunk_total": total_chunks,
					"chunk_solved": solved_count,
					"backtracks": backtracks_total
				}

			var attempt := 0
			var result: Dictionary = {}
			var chunk_timed_out := false
			var chunk_contradiction_cells: Array[Vector2i] = []
			while attempt < max_attempts_per_solve:
				attempt += 1
				result = await _run_wfc(
					patterns,
					weights,
					adjacency,
					grid_size,
					rng,
					time_budget_seconds,
					allow_backtracking,
					max_backtracks
				)
				if result.get("status", "") == "contradiction":
					chunk_contradiction_cells = _as_vector2i_array(result.get("contradiction_cells", []))
				chunk_timed_out = result.get("timed_out", false)
				backtracks_total += result.get("backtracks", 0)
				if chunk_timed_out or result.success:
					break

			if not result.success and not chunk_timed_out:
				if not chunk_contradiction_cells.is_empty():
					contradiction_cells.append_array(_offset_cells(chunk_contradiction_cells, chunk_rect.position))
				retry_failed += 1
				_debug_log("WFC: %s solve still failed with ignored borders at %s." % [chunk_label, chunk_rect])
				_debug_log("WFC: border-ignored retry halted: %d/%d solved, %d timed out, %d failed, %d tile conflicts across %d chunks." % [
					retry_solved,
					failed.size(),
					retry_timed_out,
					retry_failed,
					retry_conflict_total,
					retry_conflict_chunks
				])
				return {
					"success": true,
					"output_tiles": output_tiles,
					"timed_out": timed_out,
					"partial": true,
					"contradiction_cells": contradiction_cells,
					"chunk_total": total_chunks,
					"chunk_solved": solved_count,
					"backtracks": backtracks_total
				}

			if chunk_timed_out:
				timed_out = true
				retry_timed_out += 1
				var partial_tiles := _build_output_tiles_partial(
					patterns,
					tile_data,
					result.grid,
					grid_size,
					chunk_rect,
					overlap_size
				)
				var conflict_count := _merge_output_tiles(output_tiles, partial_tiles, chunk_label, contradiction_cells)
				if conflict_count > 0:
					retry_conflict_total += conflict_count
					retry_conflict_chunks += 1
				_fill_missing_tiles_with_timeout_mode(
					get_node_or_null(target_tilemap_path) as TileMap,
					chunk_rect,
					output_tiles,
					sample_tiles,
					tile_data,
					tile_counts,
					rng,
					time_budget_timeout_tile
				)
			else:
				retry_solved += 1
				var chunk_tiles := _build_output_tiles(
					patterns,
					tile_data,
					result.grid,
					grid_size,
					chunk_rect,
					overlap_size
				)
				var conflict_count := _merge_output_tiles(output_tiles, chunk_tiles, chunk_label, contradiction_cells)
				if conflict_count > 0:
					retry_conflict_total += conflict_count
					retry_conflict_chunks += 1
			solved_count += 1

		_debug_log("WFC: border-ignored retry complete: %d/%d solved, %d timed out, %d failed, %d tile conflicts across %d chunks." % [
			retry_solved,
			failed.size(),
			retry_timed_out,
			retry_failed,
			retry_conflict_total,
			retry_conflict_chunks
		])

	return {
		"success": true,
		"output_tiles": output_tiles,
		"timed_out": timed_out,
		"contradiction_cells": contradiction_cells,
		"chunk_total": total_chunks,
		"chunk_solved": solved_count,
		"backtracks": backtracks_total
	}


func _build_chunk_rects(target_rect: Rect2i, size: int, pattern_size: int) -> Dictionary:
	var x_starts := _build_chunk_axis_starts(target_rect.position.x, target_rect.size.x, size, pattern_size)
	var y_starts := _build_chunk_axis_starts(target_rect.position.y, target_rect.size.y, size, pattern_size)
	var rects: Dictionary = {}
	var x_end := target_rect.position.x + target_rect.size.x
	var y_end := target_rect.position.y + target_rect.size.y
	for x_index in range(x_starts.size()):
		var start_x := x_starts[x_index]
		var width: int = min(size, x_end - start_x)
		for y_index in range(y_starts.size()):
			var start_y := y_starts[y_index]
			var height: int = min(size, y_end - start_y)
			rects[Vector2i(x_index, y_index)] = Rect2i(start_x, start_y, width, height)
	return rects


func _build_chunk_axis_starts(
	start_pos: int,
	length: int,
	size: int,
	pattern_size: int
) -> Array[int]:
	var adjusted_size: int = max(size, pattern_size)
	if length <= adjusted_size:
		return [start_pos]
	var starts: Array[int] = []
	var end_pos := start_pos + length
	var pos := start_pos
	while pos < end_pos:
		if end_pos - pos < adjusted_size:
			pos = end_pos - adjusted_size
		if not starts.is_empty() and pos <= starts.back():
			break
		starts.append(pos)
		pos += adjusted_size
	return starts


func _pick_next_chunk_coord(
	remaining: Array[Vector2i],
	solved: Dictionary,
	rng: RandomNumberGenerator
) -> Vector2i:
	if solved.is_empty():
		return remaining[rng.randi_range(0, remaining.size() - 1)]
	var candidates: Array[Vector2i] = []
	for coord in remaining:
		if _has_solved_neighbor(coord, solved):
			candidates.append(coord)
	if candidates.is_empty():
		return remaining[rng.randi_range(0, remaining.size() - 1)]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _has_solved_neighbor(coord: Vector2i, solved: Dictionary) -> bool:
	for dir in DIRECTIONS:
		if solved.has(coord + dir):
			return true
	return false


func _collect_known_tiles(output_tiles: Dictionary, rect: Rect2i) -> Dictionary:
	var known: Dictionary = {}
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var pos := Vector2i(x, y)
			if output_tiles.has(pos):
				known[pos] = output_tiles[pos]
	return known


func _build_constrained_wave(
	patterns: Array,
	target_rect: Rect2i,
	grid_size: Vector2i,
	pattern_size: int,
	known_tiles: Dictionary
) -> Array:
	var total_cells: int = grid_size.x * grid_size.y
	var wave: Array = []
	wave.resize(total_cells)
	var pattern_count := patterns.size()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var allowed: Array = []
			for pattern_index in range(pattern_count):
				var pattern_tiles: Array = patterns[pattern_index]
				var valid := true
				for dy in range(pattern_size):
					for dx in range(pattern_size):
						var tile_pos := target_rect.position + Vector2i(x + dx, y + dy)
						if known_tiles.has(tile_pos):
							var tile_key: String = pattern_tiles[dy * pattern_size + dx]
							if known_tiles[tile_pos]["key"] != tile_key:
								valid = false
								break
					if not valid:
						break
				if valid:
					allowed.append(pattern_index)
			if allowed.is_empty():
				return []
			wave[y * grid_size.x + x] = allowed
	return wave


func _merge_output_tiles(
	output_tiles: Dictionary,
	new_tiles: Dictionary,
	chunk_label: String = "",
	conflict_cells: Array[Vector2i] = []
) -> int:
	var conflict_count := 0
	for tile_pos in new_tiles.keys():
		if output_tiles.has(tile_pos):
			if output_tiles[tile_pos]["key"] != new_tiles[tile_pos]["key"] and not ignore_chunk_borders:
				conflict_count += 1
				conflict_cells.append(tile_pos)
			continue
		output_tiles[tile_pos] = new_tiles[tile_pos]
	if conflict_count > 0 and not ignore_chunk_borders:
		var prefix := "WFC: tile conflicts during chunk merge"
		if not chunk_label.is_empty():
			prefix = "WFC: %s tile conflicts during chunk merge" % chunk_label
		_debug_log("%s (%d)." % [prefix, conflict_count])
	return conflict_count


func _run_wfc(
	patterns: Array,
	weights: Array,
	adjacency: Array,
	grid_size: Vector2i,
	rng: RandomNumberGenerator,
	time_budget_seconds: float = 0.0,
	allow_backtracking: bool = false,
	max_backtracks: int = 0,
	initial_wave: Array = []
) -> Dictionary:
	var init_start_ms := Time.get_ticks_msec()
	var start_ms := Time.get_ticks_msec()
	var total_cells: int = grid_size.x * grid_size.y
	var wave: Array = []
	if initial_wave.is_empty():
		var all_patterns: Array = []
		for index in range(patterns.size()):
			all_patterns.append(index)
		for _i in range(total_cells):
			wave.append(all_patterns.duplicate())
	else:
		wave = _clone_wave(initial_wave)

	var stack: Array = []
	if not initial_wave.is_empty():
		for index in range(total_cells):
			if wave[index].size() < patterns.size():
				stack.append(index)
	var allowed_mask := PackedByteArray()
	allowed_mask.resize(patterns.size())
	var init_seconds := _elapsed_seconds(init_start_ms)
	var entropy_seconds := 0.0
	var propagate_seconds := 0.0
	var entropy_picks := 0
	var propagation_steps := 0
	var backtracks := 0
	var decision_stack: Array = []

	while true:
		if time_budget_seconds > 0.0 and _elapsed_seconds(start_ms) > time_budget_seconds:
			_log_wfc_solve_timing("timeout", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
			return {
				"success": false,
				"status": "timeout",
				"timed_out": true,
				"grid": wave,
				"timeout_reason": "time_budget",
				"elapsed_seconds": _elapsed_seconds(start_ms),
				"backtracks": backtracks
			}
		var entropy_start_ms := Time.get_ticks_msec()
		var next_index := _find_lowest_entropy(wave, rng)
		entropy_seconds += _elapsed_seconds(entropy_start_ms)
		entropy_picks += 1
		if next_index == -1:
			_log_wfc_solve_timing("success", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
			return {"success": true, "status": "success", "grid": wave, "backtracks": backtracks}

		var selection_done := false
		while not selection_done:
			if wave[next_index].is_empty():
				if allow_backtracking:
					var backtrack_result := await _perform_backtrack(
						decision_stack,
						weights,
						rng,
						stack,
						backtracks,
						max_backtracks
					)
					backtracks = backtrack_result.backtracks
					if backtrack_result.success:
						wave = backtrack_result.wave
						selection_done = true
						break
				_log_wfc_solve_timing("contradiction", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
				return {
					"success": false,
					"status": "contradiction",
					"backtracks": backtracks,
					"contradiction_cells": [Vector2i(next_index % grid_size.x, next_index / grid_size.x)]
				}

			var chosen: int = _weighted_choice(wave[next_index], weights, rng)
			if allow_backtracking:
				var remaining: Array = wave[next_index].duplicate()
				remaining.erase(chosen)
				if not remaining.is_empty():
					decision_stack.append({
						"wave": _clone_wave(wave),
						"index": next_index,
						"remaining": remaining
					})
			wave[next_index] = [chosen]
			stack.append(next_index)
			selection_done = true

		while not stack.is_empty():
			var propagate_start_ms := Time.get_ticks_msec()
			if time_budget_seconds > 0.0 and _elapsed_seconds(start_ms) > time_budget_seconds:
				propagate_seconds += _elapsed_seconds(propagate_start_ms)
				propagation_steps += 1
				_log_wfc_solve_timing("timeout", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
				return {
					"success": false,
					"status": "timeout",
					"timed_out": true,
					"grid": wave,
					"timeout_reason": "time_budget",
					"elapsed_seconds": _elapsed_seconds(start_ms),
					"backtracks": backtracks
				}
			var current_index: int = stack.pop_back()
			var current_pos: Vector2i = Vector2i(current_index % grid_size.x, current_index / grid_size.x)
			var current_patterns: Array = wave[current_index]
			var restart_propagation := false

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
					propagate_seconds += _elapsed_seconds(propagate_start_ms)
					propagation_steps += 1
					if allow_backtracking:
						var backtrack_result := await _perform_backtrack(
							decision_stack,
							weights,
							rng,
							stack,
							backtracks,
							max_backtracks
						)
						backtracks = backtrack_result.backtracks
						if backtrack_result.success:
							wave = backtrack_result.wave
							restart_propagation = true
							break
					_log_wfc_solve_timing("contradiction", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
					return {
						"success": false,
						"status": "contradiction",
						"backtracks": backtracks,
						"contradiction_cells": [neighbor_pos]
					}

				if reduced:
					stack.append(neighbor_index)
			propagate_seconds += _elapsed_seconds(propagate_start_ms)
			propagation_steps += 1
			if restart_propagation:
				continue

	_log_wfc_solve_timing("failed", init_seconds, entropy_seconds, propagate_seconds, entropy_picks, propagation_steps)
	return {"success": false, "status": "failed", "backtracks": backtracks}


func _perform_backtrack(
	decision_stack: Array,
	weights: Array,
	rng: RandomNumberGenerator,
	stack: Array,
	backtracks: int,
	max_backtracks: int
) -> Dictionary:
	while not decision_stack.is_empty():
		if max_backtracks > 0 and backtracks >= max_backtracks:
			return {"success": false, "backtracks": backtracks}
		var decision: Dictionary = decision_stack.pop_back()
		var remaining: Array = decision.get("remaining", [])
		if remaining.is_empty():
			continue
		backtracks += 1
		_debug_log("WFC: backtrack %d/%d." % [backtracks, max_backtracks])
		var wave: Array = decision["wave"]
		var chosen: int = _weighted_choice(remaining, weights, rng)
		remaining.erase(chosen)
		if not remaining.is_empty():
			decision_stack.append({
				"wave": _clone_wave(wave),
				"index": decision["index"],
				"remaining": remaining
			})
		wave[decision["index"]] = [chosen]
		stack.clear()
		stack.append(decision["index"])
		return {"success": true, "wave": wave, "backtracks": backtracks}
	return {"success": false, "backtracks": backtracks}


func _clone_wave(wave: Array) -> Array:
	var cloned: Array = []
	cloned.resize(wave.size())
	for i in range(wave.size()):
		cloned[i] = wave[i].duplicate()
	return cloned


func _log_wfc_solve_timing(
	status: String,
	init_seconds: float,
	entropy_seconds: float,
	propagate_seconds: float,
	entropy_picks: int,
	propagation_steps: int
) -> void:
	_debug_log("WFC: solve timing (%s) init %.3f s, entropy %.3f s (%d picks), propagate %.3f s (%d steps)." % [
		status,
		init_seconds,
		entropy_seconds,
		entropy_picks,
		propagate_seconds,
		propagation_steps
	])


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
	var conflict_count := 0
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
							conflict_count += 1
						continue
					var data: Dictionary = tile_data[tile_key]
					output_tiles[tile_pos] = {
						"key": tile_key,
						"source_id": data["source_id"],
						"atlas_coords": data["atlas_coords"],
						"alternative_tile": data["alternative_tile"],
					}

	if conflict_count > 0:
		_debug_log("WFC: tile conflicts while building output tiles for %s (%d)." % [
			target_rect,
			conflict_count
		])
	return output_tiles


func _build_output_tiles_partial(
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
			var cell_patterns: Array = grid[y * grid_size.x + x]
			if cell_patterns.size() != 1:
				continue
			var pattern_index: int = cell_patterns[0]
			var pattern_tiles: Array = patterns[pattern_index]
			for dy in range(pattern_size):
				for dx in range(pattern_size):
					var tile_key: String = pattern_tiles[dy * pattern_size + dx]
					var tile_pos := target_rect.position + Vector2i(x + dx, y + dy)
					if output_tiles.has(tile_pos):
						continue
					var data: Dictionary = tile_data[tile_key]
					output_tiles[tile_pos] = {
						"key": tile_key,
						"source_id": data["source_id"],
						"atlas_coords": data["atlas_coords"],
						"alternative_tile": data["alternative_tile"],
					}

	return output_tiles


func _build_sample_tiles(tile_data: Dictionary) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for key in tile_data.keys():
		var entry: Dictionary = tile_data[key]
		if entry["source_id"] == -1:
			continue
		tiles.append({
			"key": key,
			"source_id": entry["source_id"],
			"atlas_coords": entry["atlas_coords"],
			"alternative_tile": entry["alternative_tile"],
		})
	return tiles


func _fill_missing_tiles_with_timeout_mode(
	target_tilemap: TileMap,
	target_rect: Rect2i,
	output_tiles: Dictionary,
	sample_tiles: Array[Dictionary],
	tile_data: Dictionary,
	tile_counts: Dictionary,
	rng: RandomNumberGenerator,
	timeout_mode: String
) -> void:
	if sample_tiles.is_empty():
		_debug_log("WFC: time budget exceeded but no sample tiles found.")
		return
	var shared_tile := _resolve_timeout_tile(
		timeout_mode,
		sample_tiles,
		tile_data,
		tile_counts,
		target_tilemap,
		rng
	)
	if shared_tile.is_empty():
		shared_tile = _resolve_timeout_tile(
			"random_tile",
			sample_tiles,
			tile_data,
			tile_counts,
			target_tilemap,
			rng
		)
	if shared_tile.is_empty():
		_debug_log("WFC: timeout fill failed to resolve any tile.")
		return
	for y in range(target_rect.position.y, target_rect.position.y + target_rect.size.y):
		for x in range(target_rect.position.x, target_rect.position.x + target_rect.size.x):
			var tile_pos := Vector2i(x, y)
			if output_tiles.has(tile_pos):
				continue
			var fallback_tile := shared_tile
			if timeout_mode == "random_tile" or timeout_mode == "random_top_three":
				fallback_tile = _resolve_timeout_tile(
					timeout_mode,
					sample_tiles,
					tile_data,
					tile_counts,
					target_tilemap,
					rng
				)
			output_tiles[tile_pos] = {
				"key": fallback_tile["key"],
				"source_id": fallback_tile["source_id"],
				"atlas_coords": fallback_tile["atlas_coords"],
				"alternative_tile": fallback_tile["alternative_tile"],
			}


func _build_tile_counts(sample_tilemap: TileMap, sample_rect: Rect2i) -> Dictionary:
	var counts: Dictionary = {}
	for y in range(sample_rect.position.y, sample_rect.position.y + sample_rect.size.y):
		for x in range(sample_rect.position.x, sample_rect.position.x + sample_rect.size.x):
			var cell_pos := Vector2i(x, y)
			var source_id := sample_tilemap.get_cell_source_id(0, cell_pos)
			if source_id == -1:
				continue
			var atlas_coords := sample_tilemap.get_cell_atlas_coords(0, cell_pos)
			var alternative_tile := sample_tilemap.get_cell_alternative_tile(0, cell_pos)
			var tile_key := _tile_key(source_id, atlas_coords, alternative_tile)
			counts[tile_key] = int(counts.get(tile_key, 0)) + 1
	return counts


func _resolve_timeout_tile(
	timeout_mode: String,
	sample_tiles: Array[Dictionary],
	tile_data: Dictionary,
	tile_counts: Dictionary,
	target_tilemap: TileMap,
	rng: RandomNumberGenerator
) -> Dictionary:
	match timeout_mode:
		"dirt":
			var dirt_tile := _find_tile_by_type(target_tilemap, "dirt")
			if dirt_tile.is_empty():
				return {}
			var dirt_key := _tile_key(dirt_tile["source_id"], dirt_tile["atlas_coords"], dirt_tile["alternative"])
			return {
				"key": dirt_key,
				"source_id": dirt_tile["source_id"],
				"atlas_coords": dirt_tile["atlas_coords"],
				"alternative_tile": dirt_tile["alternative"],
			}
		"most_common":
			return _pick_common_tile(tile_counts, tile_data, false)
		"least_common":
			return _pick_common_tile(tile_counts, tile_data, true)
		"random_tile", "random_same":
			if sample_tiles.is_empty():
				return {}
			return sample_tiles[rng.randi_range(0, sample_tiles.size() - 1)]
		"random_top_three":
			return _pick_random_from_top_common(tile_counts, tile_data, rng, 3)
	return {}


func _pick_common_tile(
	tile_counts: Dictionary,
	tile_data: Dictionary,
	pick_least: bool
) -> Dictionary:
	var best_key := ""
	var best_count: float = INF if pick_least else -1.0
	for key in tile_counts.keys():
		var count: int = int(tile_counts[key])
		if pick_least:
			if count < best_count:
				best_count = count
				best_key = key
		else:
			if count > best_count:
				best_count = count
				best_key = key
	if best_key == "":
		return {}
	var data: Dictionary = tile_data.get(best_key, {})
	if data.is_empty():
		return {}
	return {
		"key": best_key,
		"source_id": data["source_id"],
		"atlas_coords": data["atlas_coords"],
		"alternative_tile": data["alternative_tile"],
	}


func _pick_random_from_top_common(
	tile_counts: Dictionary,
	tile_data: Dictionary,
	rng: RandomNumberGenerator,
	top_count: int
) -> Dictionary:
	if tile_counts.is_empty():
		return {}
	var pairs: Array = []
	for key in tile_counts.keys():
		pairs.append({
			"key": key,
			"count": int(tile_counts[key]),
		})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["count"] > b["count"]
	)
	var limit: int = min(top_count, pairs.size())
	if limit <= 0:
		return {}
	var chosen: String = pairs[rng.randi_range(0, limit - 1)]["key"]
	var data: Dictionary = tile_data.get(chosen, {})
	if data.is_empty():
		return {}
	return {
		"key": chosen,
		"source_id": data["source_id"],
		"atlas_coords": data["atlas_coords"],
		"alternative_tile": data["alternative_tile"],
	}


func _tile_key(source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%s:%s:%s:%s" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]


func _empty_tile_key() -> String:
	return "empty"
