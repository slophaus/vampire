extends RefCounted
class_name TileEater

const CUSTOM_DATA_KEY := "tile_type"
const DIG_FLOOR_CUSTOM_DATA_KEY := "dig_floor"
const WALKABLE_TILE_TYPES := ["floor"]
const OCCUPIED_TILE_TYPE := "occupied"
const DIRT_BORDER_LAYER_NAME := "dirt_border"
const DIRT_BORDER_META_KEY := "_dirt_border_initialized"
const DIRT_BORDER_TERRAIN_SET := 0
const DIRT_BORDER_TERRAIN := 0

signal tile_converted(world_position: Vector2)

var owner: Node2D
var arena_tilemap: TileMap
var dirt_border_layer: TileMapLayer
var walkable_tile_source_id := -1
var walkable_tile_atlas := Vector2i.ZERO
var walkable_tile_alternative := 0
var occupied_tile_source_id := -1
var occupied_tile_atlas := Vector2i.ZERO
var occupied_tile_alternative := 0
var occupied_cells: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init(owner_node: Node2D) -> void:
	owner = owner_node
	rng.randomize()
	arena_tilemap = _find_arena_tilemap()
	if arena_tilemap != null:
		dirt_border_layer = arena_tilemap.get_node_or_null(DIRT_BORDER_LAYER_NAME) as TileMapLayer


func cache_walkable_tile() -> void:
	_cache_walkable_tile()


func _cache_walkable_tile() -> void:
	if arena_tilemap == null or owner == null:
		return
	var tile_info = _find_random_dig_floor_tile()
	if tile_info.is_empty():
		tile_info = _find_tile_by_type(WALKABLE_TILE_TYPES[0])
	if tile_info.is_empty():
		return
	walkable_tile_source_id = tile_info.source_id
	walkable_tile_atlas = tile_info.atlas_coords
	walkable_tile_alternative = tile_info.alternative
	_cache_occupied_tile()
	_initialize_dirt_border()


func try_convert_tile(position: Vector2, allowed_types: Array[String]) -> void:
	_ensure_arena_tilemap()
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
	_try_convert_tile_cell(cell, allowed_types)


func try_convert_tiles_in_radius(position: Vector2, radius: float, allowed_types: Array[String]) -> void:
	_ensure_arena_tilemap()
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	if radius <= 0.0:
		return
	var tile_size := arena_tilemap.tile_set.tile_size
	if tile_size.x <= 0 or tile_size.y <= 0:
		return
	var center_cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
	var radius_x = int(ceil(radius / float(tile_size.x)))
	var radius_y = int(ceil(radius / float(tile_size.y)))
	for offset_y in range(-radius_y, radius_y + 1):
		for offset_x in range(-radius_x, radius_x + 1):
			var cell = center_cell + Vector2i(offset_x, offset_y)
			_try_convert_tile_cell(cell, allowed_types)


func update_occupied_tiles(world_positions: Array[Vector2]) -> void:
	_ensure_arena_tilemap()
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	if occupied_tile_source_id == -1:
		_cache_occupied_tile()
		if occupied_tile_source_id == -1:
			return
	var next_cells: Dictionary = {}
	for position in world_positions:
		var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
		next_cells[cell] = true
	for cell in occupied_cells.keys():
		if not next_cells.has(cell):
			_set_walkable_cell(cell)
	for cell in next_cells.keys():
		if not occupied_cells.has(cell):
			_set_occupied_cell(cell)
	occupied_cells = next_cells


func clear_occupied_tiles() -> void:
	update_occupied_tiles([])


func _try_convert_tile_cell(cell: Vector2i, allowed_types: Array[String]) -> void:
	var source_id = arena_tilemap.get_cell_source_id(0, cell)
	if source_id == -1:
		return
	if source_id == walkable_tile_source_id:
		if arena_tilemap.get_cell_atlas_coords(0, cell) == walkable_tile_atlas \
				and arena_tilemap.get_cell_alternative_tile(0, cell) == walkable_tile_alternative:
			return
	var tile_data := arena_tilemap.get_cell_tile_data(0, cell)
	if tile_data == null:
		return
	var tile_type = tile_data.get_custom_data(CUSTOM_DATA_KEY)
	if tile_type == "metal":
		return
	if tile_type == null or not allowed_types.has(tile_type):
		return
	arena_tilemap.set_cell(0, cell, walkable_tile_source_id, walkable_tile_atlas, walkable_tile_alternative)
	_update_dirt_border(cell)
	var local_position = arena_tilemap.map_to_local(cell)
	var world_position = arena_tilemap.to_global(local_position)
	tile_converted.emit(world_position)


func _set_walkable_cell(cell: Vector2i) -> void:
	if walkable_tile_source_id == -1:
		return
	arena_tilemap.set_cell(0, cell, walkable_tile_source_id, walkable_tile_atlas, walkable_tile_alternative)
	_update_dirt_border(cell)


func _set_occupied_cell(cell: Vector2i) -> void:
	if occupied_tile_source_id == -1:
		return
	arena_tilemap.set_cell(0, cell, occupied_tile_source_id, occupied_tile_atlas, occupied_tile_alternative)
	_update_dirt_border(cell)


func _find_arena_tilemap() -> TileMap:
	if owner == null:
		return null
	for node in owner.get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			return tilemap
	return null


func _ensure_arena_tilemap() -> void:
	if owner == null:
		return
	if arena_tilemap != null and arena_tilemap.is_inside_tree():
		return
	var next_tilemap = _find_arena_tilemap()
	if next_tilemap == null:
		return
	arena_tilemap = next_tilemap
	dirt_border_layer = arena_tilemap.get_node_or_null(DIRT_BORDER_LAYER_NAME) as TileMapLayer
	walkable_tile_source_id = -1
	walkable_tile_atlas = Vector2i.ZERO
	walkable_tile_alternative = 0
	occupied_tile_source_id = -1
	occupied_tile_atlas = Vector2i.ZERO
	occupied_tile_alternative = 0
	_cache_walkable_tile()


func _initialize_dirt_border() -> void:
	initialize_dirt_border_for_tilemap(arena_tilemap)


func _update_dirt_border(center_cell: Vector2i) -> void:
	if dirt_border_layer == null:
		return
	var floor_cells: Array[Vector2i] = []
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var cell = center_cell + Vector2i(offset_x, offset_y)
			if _is_walkable_cell(cell):
				floor_cells.append(cell)
	if floor_cells.is_empty():
		return
	dirt_border_layer.set_cells_terrain_connect(
		floor_cells,
		DIRT_BORDER_TERRAIN_SET,
		DIRT_BORDER_TERRAIN,
		false
	)


func _is_walkable_cell(cell: Vector2i) -> bool:
	return _is_walkable_cell_in_tilemap(arena_tilemap, cell)


static func initialize_dirt_border_for_tilemap(arena_tilemap: TileMap) -> void:
	if arena_tilemap == null:
		return
	if arena_tilemap.has_meta(DIRT_BORDER_META_KEY):
		return
	var dirt_border_layer = arena_tilemap.get_node_or_null(DIRT_BORDER_LAYER_NAME) as TileMapLayer
	if dirt_border_layer == null:
		return
	dirt_border_layer.clear()
	var floor_cells: Array[Vector2i] = []
	for cell in arena_tilemap.get_used_cells(0):
		if _is_walkable_cell_in_tilemap(arena_tilemap, cell):
			floor_cells.append(cell)
	if not floor_cells.is_empty():
		dirt_border_layer.set_cells_terrain_connect(
			floor_cells,
			DIRT_BORDER_TERRAIN_SET,
			DIRT_BORDER_TERRAIN,
			false
		)
	arena_tilemap.set_meta(DIRT_BORDER_META_KEY, true)


static func _is_walkable_cell_in_tilemap(arena_tilemap: TileMap, cell: Vector2i) -> bool:
	if arena_tilemap == null:
		return false
	var tile_data := arena_tilemap.get_cell_tile_data(0, cell)
	if tile_data == null:
		return false
	var tile_type = tile_data.get_custom_data(CUSTOM_DATA_KEY)
	return tile_type != null and WALKABLE_TILE_TYPES.has(tile_type)


func _cache_occupied_tile() -> void:
	if arena_tilemap == null:
		return
	var tile_info = _find_tile_by_type(OCCUPIED_TILE_TYPE)
	if tile_info.is_empty():
		return
	occupied_tile_source_id = tile_info.source_id
	occupied_tile_atlas = tile_info.atlas_coords
	occupied_tile_alternative = tile_info.alternative


func _find_tile_by_type(tile_type: String) -> Dictionary:
	if arena_tilemap == null:
		return {}
	for cell in arena_tilemap.get_used_cells(0):
		var tile_data := arena_tilemap.get_cell_tile_data(0, cell)
		if _tile_data_has_type(tile_data, tile_type):
			return {
				"source_id": arena_tilemap.get_cell_source_id(0, cell),
				"atlas_coords": arena_tilemap.get_cell_atlas_coords(0, cell),
				"alternative": arena_tilemap.get_cell_alternative_tile(0, cell),
			}
	var tile_set = arena_tilemap.tile_set
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


func _find_random_dig_floor_tile() -> Dictionary:
	if arena_tilemap == null or arena_tilemap.tile_set == null:
		return {}
	var candidates: Array[Dictionary] = []
	var tile_set = arena_tilemap.tile_set
	for source_index in range(tile_set.get_source_count()):
		var source_id = tile_set.get_source_id(source_index)
		var source = tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas := source as TileSetAtlasSource
			for tile_index in range(atlas.get_tiles_count()):
				var tile_id = atlas.get_tile_id(tile_index)
				if _tile_data_has_custom_bool(atlas.get_tile_data(tile_id, 0), DIG_FLOOR_CUSTOM_DATA_KEY):
					candidates.append({
						"source_id": source_id,
						"atlas_coords": tile_id,
						"alternative": 0,
					})
				var alt_count = atlas.get_alternative_tiles_count(tile_id)
				for alt_index in range(alt_count):
					var alt_id = atlas.get_alternative_tile_id(tile_id, alt_index)
					if _tile_data_has_custom_bool(atlas.get_tile_data(tile_id, alt_id), DIG_FLOOR_CUSTOM_DATA_KEY):
						candidates.append({
							"source_id": source_id,
							"atlas_coords": tile_id,
							"alternative": alt_id,
						})
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _tile_data_has_type(tile_data: TileData, tile_type: String) -> bool:
	if tile_data == null:
		return false
	var custom_type = tile_data.get_custom_data(CUSTOM_DATA_KEY)
	return custom_type != null and custom_type == tile_type


func _tile_data_has_custom_bool(tile_data: TileData, custom_key: String) -> bool:
	if tile_data == null:
		return false
	return tile_data.get_custom_data(custom_key) == true
