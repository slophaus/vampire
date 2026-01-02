extends Node
class_name GameSession

@export var starting_level_scene: PackedScene
@export var end_screen_scene: PackedScene

var paused_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var player_scene = preload("res://scenes/game_object/player/player.tscn")
var player_regenerating := {}
var game_over := false
var is_transitioning := false

const DEFEAT_MENU_DELAY := 0.6
const DOOR_EXIT_OFFSET := Vector2(0, 64)
const PLAYER_FORMATION_OFFSETS := {
	1: Vector2.ZERO,
	2: Vector2(32, 0),
	3: Vector2(-32, 0),
	4: Vector2(0, 32),
}

@onready var level_container: Node = $LevelContainer
@onready var players_container: Node = $Players
@onready var arena_time_ui: CanvasLayer = $ArenaTimeUI
@onready var arena_time_manager: ArenaTimeManager = $ArenaTimeManager
@onready var enemy_manager: EnemyManager = $EnemyManager

var current_level: LevelRoot


func _ready():
	add_to_group("game_session")
	_set_timed_systems_active(false)
	_apply_player_count()
	_connect_player_signals()
	if starting_level_scene != null:
		_load_level(starting_level_scene, &"")


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		add_child(paused_menu_scene.instantiate())
		get_tree().root.set_input_as_handled()


func transition_to_level(level_scene: PackedScene, exit_door_name: StringName = &"Door") -> void:
	if is_transitioning:
		return
	if level_scene == null:
		return
	is_transitioning = true
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	_load_level(level_scene, exit_door_name)
	is_transitioning = false


func _load_level(level_scene: PackedScene, exit_door_name: StringName) -> void:
	if level_scene == null:
		return
	_detach_players_from_level()
	if current_level != null:
		current_level.queue_free()
	var level_instance = level_scene.instantiate()
	if not (level_instance is LevelRoot):
		push_error("Level scene is missing a LevelRoot root node: %s" % level_scene.resource_path)
		if level_instance != null:
			level_instance.queue_free()
		return
	current_level = level_instance
	level_container.add_child(current_level)
	_attach_players_to_level(current_level)
	_initialize_dirt_border(current_level)
	_apply_level_settings(current_level)
	_position_players(current_level, exit_door_name)


func _apply_level_settings(level: LevelRoot) -> void:
	var tilemap = _get_level_tilemap(level)
	enemy_manager.arena_tilemap = tilemap
	var should_run_timers = not level.is_timeless
	_set_timed_systems_active(should_run_timers)


func _set_timed_systems_active(active: bool) -> void:
	arena_time_manager.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	enemy_manager.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var arena_timer = arena_time_manager.get_node_or_null("Timer") as Timer
	if arena_timer != null:
		arena_timer.paused = not active
	var enemy_timer = enemy_manager.get_node_or_null("Timer") as Timer
	if enemy_timer != null:
		enemy_timer.paused = not active
	arena_time_ui.visible = active


func _get_level_tilemap(level: Node) -> TileMap:
	for candidate in level.find_children("", "TileMap", true, false):
		if candidate.is_in_group("arena_tilemap"):
			return candidate as TileMap
	return null


func _initialize_dirt_border(level: Node) -> void:
	for node in level.get_tree().get_nodes_in_group("arena_tilemap"):
		if level.is_ancestor_of(node):
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

	if not players_by_number.has(1):
		var player_instance = player_scene.instantiate()
		player_instance.player_number = 1
		player_instance.position = Vector2.ZERO
		player_instance.name = "Player1"
		players_container.add_child(player_instance)
		players_by_number[1] = player_instance

	for player in get_tree().get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) == TYPE_INT and player_number > desired_count:
			player.queue_free()

	var base_player = players_by_number.get(1, null)
	var base_position = Vector2.ZERO
	if base_player != null:
		base_position = base_player.position
	for player_number in range(2, desired_count + 1):
		if players_by_number.has(player_number):
			continue
		var player_instance = player_scene.instantiate()
		player_instance.player_number = player_number
		player_instance.position = base_position + PLAYER_FORMATION_OFFSETS.get(player_number, Vector2.ZERO)
		player_instance.name = "Player%d" % player_number
		players_container.add_child(player_instance)


func _connect_player_signals() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not player.regenerate_started.is_connected(on_player_regenerate_started.bind(player)):
			player.regenerate_started.connect(on_player_regenerate_started.bind(player))
		if not player.regenerate_finished.is_connected(on_player_regenerate_finished.bind(player)):
			player.regenerate_finished.connect(on_player_regenerate_finished.bind(player))
		player_regenerating[player] = false


func _attach_players_to_level(level: Node) -> void:
	var entities_layer = level.get_tree().get_first_node_in_group("entities_layer")
	if entities_layer == null:
		return
	for player in get_tree().get_nodes_in_group("player"):
		if player.get_parent() != entities_layer:
			player.reparent(entities_layer)


func _detach_players_from_level() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player.get_parent() != players_container:
			player.reparent(players_container)


func _position_players(level: LevelRoot, exit_door_name: StringName) -> void:
	var spawn_position = _get_spawn_position(level, exit_door_name)
	for player in get_tree().get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) != TYPE_INT:
			continue
		player.global_position = spawn_position + PLAYER_FORMATION_OFFSETS.get(player_number, Vector2.ZERO)


func _get_spawn_position(level: LevelRoot, exit_door_name: StringName) -> Vector2:
	var exit_door = level.find_child(exit_door_name, true, false)
	if exit_door != null:
		return exit_door.global_position + DOOR_EXIT_OFFSET
	var spawn_marker = level.find_child(level.spawn_marker_name, true, false)
	if spawn_marker != null:
		return spawn_marker.global_position
	return Vector2.ZERO


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
