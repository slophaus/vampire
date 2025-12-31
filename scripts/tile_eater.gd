extends RefCounted
class_name TileEater

const CUSTOM_DATA_KEY := "tile_type"

var owner: Node2D
var arena_tilemap: TileMap
var walkable_tile_source_id := -1
var walkable_tile_atlas := Vector2i.ZERO
var walkable_tile_alternative := 0


func _init(owner_node: Node2D) -> void:
	owner = owner_node
	arena_tilemap = _find_arena_tilemap()


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


func try_convert_tile(position: Vector2, allowed_types: Array[String]) -> void:
	if arena_tilemap == null:
		return
	if walkable_tile_source_id == -1:
		return
	var cell = arena_tilemap.local_to_map(arena_tilemap.to_local(position))
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


func _find_arena_tilemap() -> TileMap:
	if owner == null:
		return null
	for node in owner.get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			return tilemap
	return null
