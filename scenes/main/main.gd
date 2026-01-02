extends Node


@export var end_screen_scene: PackedScene

var paused_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var player_scene = preload("res://scenes/game_object/player/player.tscn")
var player_regenerating := {}
var game_over := false
const DEFEAT_MENU_DELAY := 0.6


func _ready():
	_initialize_dirt_border()
	_apply_player_count()
	for player in get_tree().get_nodes_in_group("player"):
		player.regenerate_started.connect(on_player_regenerate_started.bind(player))
		player.regenerate_finished.connect(on_player_regenerate_finished.bind(player))



func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		add_child(paused_menu_scene.instantiate())
		get_tree().root.set_input_as_handled()


func _initialize_dirt_border() -> void:
	for node in get_tree().get_nodes_in_group("arena_tilemap"):
		var tilemap := node as TileMap
		if tilemap != null:
			TileEater.initialize_dirt_border_for_tilemap(tilemap)


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
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	if entities_layer == null:
		return
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


func continue_from_defeat() -> void:
	game_over = false
	player_regenerating.clear()
	for player in get_tree().get_nodes_in_group("player"):
		player_regenerating[player] = false
		if player.has_method("continue_from_defeat"):
			player.continue_from_defeat()
