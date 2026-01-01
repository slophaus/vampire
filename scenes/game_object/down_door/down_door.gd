extends Area2D


@export var boss_arena_scene: PackedScene = preload("res://scenes/main/boss_arena.tscn")
var is_transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func reset_transition_state() -> void:
	is_transitioning = false


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
	var tree = get_tree()
	var current_scene = tree.current_scene
	if current_scene != null and not GameEvents.has_paused_scene():
		GameEvents.store_paused_scene(current_scene)
		current_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	is_transitioning = true
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	if current_scene != null and current_scene.get_parent() != null:
		tree.root.remove_child(current_scene)
	var boss_instance = boss_arena_scene.instantiate()
	tree.root.add_child(boss_instance)
	tree.current_scene = boss_instance
