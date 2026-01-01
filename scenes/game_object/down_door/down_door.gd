extends Area2D


@export var boss_arena_scene: PackedScene = preload("res://scenes/main/boss_arena.tscn")
var is_transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return
	if not body.is_in_group("player"):
		return
	if boss_arena_scene == null:
		return
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("get_persisted_state"):
			GameEvents.store_player_state(player.player_number, player.get_persisted_state())
	is_transitioning = true
	ScreenTransition.transition_to_scene(boss_arena_scene.resource_path)
