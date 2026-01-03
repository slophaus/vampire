extends Node
class_name LevelRoot

const NAVIGATION_REGION_NAME := "NavigationRegion2D"
const WALKABLE_COLLISION_LAYER := 0

@export var level_id: StringName = &""
@export var is_timeless := false
@export var spawn_marker_name: StringName = &"PlayerSpawn"


func _ready() -> void:
	_build_navigation_region()


func _build_navigation_region() -> void:
	var tilemap := _find_arena_tilemap()
	if tilemap == null:
		return
	var navigation_polygon := _build_navigation_polygon(tilemap)
	if navigation_polygon == null:
		return
	var navigation_region = tilemap.get_node_or_null(NAVIGATION_REGION_NAME) as NavigationRegion2D
	if navigation_region == null:
		navigation_region = NavigationRegion2D.new()
		navigation_region.name = NAVIGATION_REGION_NAME
		tilemap.add_child(navigation_region)
	navigation_region.navigation_polygon = navigation_polygon


func _build_navigation_polygon(tilemap: TileMap) -> NavigationPolygon:
	if tilemap.tile_set == null:
		return null
	var tile_size := tilemap.tile_set.tile_size
	if tile_size.x <= 0 or tile_size.y <= 0:
		return null
	var navigation_polygon := NavigationPolygon.new()
	var has_outline := false
	for cell in tilemap.get_used_cells(0):
		var tile_data = tilemap.get_cell_tile_data(0, cell)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(WALKABLE_COLLISION_LAYER) > 0:
			continue
		var cell_center = tilemap.map_to_local(cell)
		var cell_origin = cell_center - (tile_size * 0.5)
		var outline = PackedVector2Array([
			cell_origin,
			cell_origin + Vector2(tile_size.x, 0.0),
			cell_origin + tile_size,
			cell_origin + Vector2(0.0, tile_size.y)
		])
		navigation_polygon.add_outline(outline)
		has_outline = true
	if not has_outline:
		return null
	navigation_polygon.make_polygons_from_outlines()
	return navigation_polygon


func _find_arena_tilemap() -> TileMap:
	for node in get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			return tilemap
	return null
