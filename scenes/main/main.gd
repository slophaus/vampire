extends Node


@export var end_screen_scene: PackedScene

var paused_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var player_regenerating := {}
var game_over := false


func _ready():
	for player in get_tree().get_nodes_in_group("player"):
		player.regenerate_started.connect(on_player_regenerate_started.bind(player))
		player.regenerate_finished.connect(on_player_regenerate_finished.bind(player))



func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		add_child(paused_menu_scene.instantiate())
		get_tree().root.set_input_as_handled()


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
	var end_screen_instance = end_screen_scene.instantiate() as EndScreen
	add_child(end_screen_instance)
	end_screen_instance.set_defeat()
