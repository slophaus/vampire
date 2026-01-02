extends RefCounted
class_name TileEater

const CUSTOM_DATA_KEY := "tile_type"
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


func _init(owner_node: Node2D) -> void:
	owner = owner_node
	arena_tilemap = _find_arena_tilemap()
	if arena_tilemap != null:
		dirt_border_layer = arena_tilemap.get_node_or_null(DIRT_BORDER_LAYER_NAME) as TileMapLayer


func cache_walkable_tile() -> void:
	if arena_tilemap == null or owner == null:
		return
	var sample_position := owner.global_position
	for player in owner.get_tree().get_nodes_in_group("player"):
		var player_node := player as Node2D
		if player_node != null:
			sample_position = player_node.global_position
			break
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(sample_position))
	var source_id = arena_tilemap.get_cell_source_id(0, cell)
	if source_id == -1:
		return
	walkable_tile_source_id = source_id
	walkable_tile_atlas = arena_tilemap.get_cell_atlas_coords(0, cell)
	walkable_tile_alternative = arena_tilemap.get_cell_alternative_tile(0, cell)
	_initialize_dirt_border()


func try_convert_tile(position: Vector2, allowed_types: Array[String]) -> void:
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
	_try_convert_tile_cell(cell, allowed_types)


func try_convert_tiles_in_radius(position: Vector2, radius: float, allowed_types: Array[String]) -> void:
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
	if tile_type == null or not allowed_types.has(tile_type):
		return
	if tile_data.get_collision_polygons_count(0) <= 0:
		return
	arena_tilemap.set_cell(0, cell, walkable_tile_source_id, walkable_tile_atlas, walkable_tile_alternative)
	_update_dirt_border(cell)
	var local_position = arena_tilemap.map_to_local(cell)
	var world_position = arena_tilemap.to_global(local_position)
	tile_converted.emit(world_position)


func _find_arena_tilemap() -> TileMap:
	if owner == null:
		return null
	for node in owner.get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			return tilemap
	return null


func _initialize_dirt_border() -> void:
	if arena_tilemap == null or dirt_border_layer == null:
		return
	if arena_tilemap.has_meta(DIRT_BORDER_META_KEY):
		return
	var floor_cells: Array[Vector2i] = []
	for cell in arena_tilemap.get_used_cells(0):
		if _is_walkable_cell(cell):
			floor_cells.append(cell)
	if not floor_cells.is_empty():
		dirt_border_layer.set_cells_terrain_connect(
			floor_cells,
			DIRT_BORDER_TERRAIN_SET,
			DIRT_BORDER_TERRAIN,
			false
		)
	arena_tilemap.set_meta(DIRT_BORDER_META_KEY, true)


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
	if arena_tilemap == null:
		return false
	if walkable_tile_source_id == -1:
		return false
	if arena_tilemap.get_cell_source_id(0, cell) != walkable_tile_source_id:
		return false
	if arena_tilemap.get_cell_atlas_coords(0, cell) != walkable_tile_atlas:
		return false
	return arena_tilemap.get_cell_alternative_tile(0, cell) == walkable_tile_alternative
