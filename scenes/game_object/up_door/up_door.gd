extends Area2D


@export var main_scene: PackedScene = preload("res://scenes/main/main.tscn")
var is_transitioning := false
const DOOR_EXIT_OFFSET := Vector2(0, 32)
const PLAYER_FORMATION_OFFSETS := {
	1: Vector2.ZERO,
	2: Vector2(32, 0),
	3: Vector2(-32, 0),
	4: Vector2(0, 32),
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return
	if not body.is_in_group("player"):
		return
	if main_scene == null and not GameEvents.has_paused_scene():
		return
	is_transitioning = true
	var tree = get_tree()
	var current_scene = tree.current_scene
	if current_scene != null:
		current_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	if current_scene != null:
		tree.root.remove_child(current_scene)
		current_scene.queue_free()
	var restored_scene = GameEvents.take_paused_scene()
	if restored_scene == null:
		restored_scene = main_scene.instantiate()
	restored_scene.process_mode = Node.PROCESS_MODE_INHERIT
	for door in restored_scene.find_children("DownDoor", "", true, false):
		if door.has_method("reset_transition_state"):
			door.reset_transition_state()
	tree.root.add_child(restored_scene)
	tree.current_scene = restored_scene
	_position_players_at_exit(restored_scene)


func _position_players_at_exit(scene_root: Node) -> void:
	var tree = scene_root.get_tree()
	if tree == null:
		return
	var exit_door = scene_root.find_child("DownDoor", true, false)
	if exit_door == null:
		return
	var base_position = exit_door.global_position + DOOR_EXIT_OFFSET
	for player in tree.get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) != TYPE_INT:
			continue
		player.global_position = base_position + PLAYER_FORMATION_OFFSETS.get(player_number, Vector2.ZERO)
