extends Node


@export var end_screen_scene: PackedScene

var paused_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var player_scene = preload("res://scenes/game_object/player/player.tscn")
var player_regenerating := {}
var game_over := false
const DEFEAT_MENU_DELAY := 0.6
const CUSTOM_DATA_KEY := "tile_type"
const FLOOR_TILE_TYPE := "dirt"

@onready var arena_tilemap: TileMap = $BG/TileMap
@onready var dirt_border: TileMapLayer = $BG/dirt_border

var _pending_dirt_border_sync := false
var _cached_floor_cells := {}


func _ready():
	_apply_player_count()
	if arena_tilemap != null:
		arena_tilemap.changed.connect(_queue_dirt_border_sync)
	if not GameEvents.arena_tilemap_changed.is_connected(_sync_dirt_border):
		GameEvents.arena_tilemap_changed.connect(_queue_dirt_border_sync)
	_queue_dirt_border_sync()
	for player in get_tree().get_nodes_in_group("player"):
		player.regenerate_started.connect(on_player_regenerate_started.bind(player))
		player.regenerate_finished.connect(on_player_regenerate_finished.bind(player))



func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		add_child(paused_menu_scene.instantiate())
		get_tree().root.set_input_as_handled()


func _apply_player_count() -> void:
	var desired_count = clampi(GameEvents.player_count, 1, 4)
	var players_by_number := {}
	for player in get_tree().get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) == TYPE_INT:
			players_by_number[player_number] = player

	for player in get_tree().get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) == TYPE_INT and player_number > desired_count:
			player.queue_free()

	var base_player = players_by_number.get(1, null)
	if base_player == null:
		return
	var base_position = base_player.position
	var spawn_offsets = {
		2: Vector2(80, 40),
		3: Vector2(-80, 40),
		4: Vector2(0, -80),
	}
	var entities_layer = get_node("Entities")
	for player_number in range(2, desired_count + 1):
		if players_by_number.has(player_number):
			continue
		var player_instance = player_scene.instantiate()
		player_instance.player_number = player_number
		player_instance.position = base_position + spawn_offsets.get(player_number, Vector2.ZERO)
		player_instance.name = "Player%d" % player_number
		entities_layer.add_child(player_instance)


func on_player_regenerate_started(player):
	if game_over:
		return
	player_regenerating[player] = true
	if are_all_players_regenerating():
		trigger_defeat()


func on_player_regenerate_finished(player):
	player_regenerating[player] = false


func are_all_players_regenerating() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	for player in players:
		if not player_regenerating.get(player, false):
			return false
	return true


func trigger_defeat():
	game_over = true
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("trigger_defeat_visuals"):
			player.trigger_defeat_visuals()
	await get_tree().create_timer(DEFEAT_MENU_DELAY).timeout
	var end_screen_instance = end_screen_scene.instantiate() as EndScreen
	add_child(end_screen_instance)
	end_screen_instance.set_defeat()

func _queue_dirt_border_sync() -> void:
	if _pending_dirt_border_sync:
		return
	_pending_dirt_border_sync = true
	call_deferred("_sync_dirt_border")


func _sync_dirt_border() -> void:
	_pending_dirt_border_sync = false
	if arena_tilemap == null or dirt_border == null:
		return
	var floor_cells: Array[Vector2i] = []
	var floor_cell_set := {}
	for cell in arena_tilemap.get_used_cells(0):
		var tile_data = arena_tilemap.get_cell_tile_data(0, cell)
		if tile_data == null:
			continue
		var tile_type = tile_data.get_custom_data(CUSTOM_DATA_KEY)
		if tile_type == FLOOR_TILE_TYPE:
			floor_cells.append(cell)
			floor_cell_set[cell] = true
	if _cached_floor_cells.size() == floor_cell_set.size():
		var unchanged := true
		for cell in floor_cell_set.keys():
			if not _cached_floor_cells.has(cell):
				unchanged = false
				break
		if unchanged:
			return
	_cached_floor_cells = floor_cell_set
	dirt_border.clear()
	if floor_cells.is_empty():
		return
	dirt_border.set_cells_terrain_connect(floor_cells, 0, 0)
