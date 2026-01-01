extends Area2D


enum DoorMode {
	TO_BOSS,
	TO_MAIN,
}


@export var door_mode := DoorMode.TO_BOSS
@export var boss_arena_scene: PackedScene
@export var main_scene: PackedScene
@export var exit_door_name: StringName = &"Door"

var is_transitioning := false
const DOOR_EXIT_OFFSET := Vector2(0, 64)
const PLAYER_FORMATION_OFFSETS := {
	1: Vector2.ZERO,
	2: Vector2(32, 0),
	3: Vector2(-32, 0),
	4: Vector2(0, 32),
}
const REENABLE_DELAY_FRAMES := 2
const BOSS_ARENA_SCENE_PATH := "res://scenes/main/boss_arena.tscn"
const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"


func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)


func reset_transition_state() -> void:
	is_transitioning = false


func defer_reenable() -> void:
	monitoring = false
	for _frame in range(REENABLE_DELAY_FRAMES):
		await get_tree().process_frame
	monitoring = true


func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return
	if not body.is_in_group("player"):
		return
	match door_mode:
		DoorMode.TO_BOSS:
			_transition_to_boss_arena()
		DoorMode.TO_MAIN:
			_transition_to_main_scene()


func _transition_to_boss_arena() -> void:
	if boss_arena_scene == null:
		boss_arena_scene = load(BOSS_ARENA_SCENE_PATH)
	if boss_arena_scene == null:
		return
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("get_persisted_state"):
			GameEvents.store_player_state(player.player_number, player.get_persisted_state())
	var tree = get_tree()
	var current_scene = tree.current_scene
	var keep_current_scene := false
	if current_scene != null and not GameEvents.has_paused_scene():
		GameEvents.store_paused_scene(current_scene)
		current_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		keep_current_scene = true
	_transition_to_scene(boss_arena_scene.instantiate(), keep_current_scene)


func _transition_to_main_scene() -> void:
	if main_scene == null and not GameEvents.has_paused_scene():
		main_scene = load(MAIN_SCENE_PATH)
		if main_scene == null:
			return
	var destination_scene = GameEvents.take_paused_scene()
	if destination_scene == null:
		destination_scene = main_scene.instantiate()
	_transition_to_scene(destination_scene, false)


func _transition_to_scene(destination_scene: Node, keep_current_scene: bool) -> void:
	is_transitioning = true
	var tree = get_tree()
	var current_scene = tree.current_scene
	if current_scene != null:
		current_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	_transfer_scene_managers(current_scene, destination_scene)
	_remove_current_scene(current_scene, keep_current_scene)
	destination_scene.process_mode = Node.PROCESS_MODE_INHERIT
	tree.root.add_child(destination_scene)
	tree.current_scene = destination_scene
	_reset_door_states(destination_scene)
	_sync_persisted_states(destination_scene)
	_position_players_at_exit(destination_scene)


func _remove_current_scene(current_scene: Node, keep_current_scene: bool) -> void:
	if current_scene == null:
		return
	if current_scene.get_parent() != null:
		current_scene.get_parent().remove_child(current_scene)
	if not keep_current_scene:
		current_scene.queue_free()


func _transfer_scene_managers(current_scene: Node, destination_scene: Node) -> void:
	if current_scene == null or destination_scene == null:
		return
	var source_experience = current_scene.find_child("ExperienceManager", true, false)
	var source_upgrade = current_scene.find_child("UpgradeManager", true, false)
	if source_experience != null:
		_remove_destination_manager(destination_scene, "ExperienceManager", source_experience)
	if source_upgrade != null:
		_remove_destination_manager(destination_scene, "UpgradeManager", source_upgrade)
	if source_experience != null:
		source_experience.get_parent().remove_child(source_experience)
		destination_scene.add_child(source_experience)
	if source_upgrade != null:
		source_upgrade.get_parent().remove_child(source_upgrade)
		destination_scene.add_child(source_upgrade)
		if source_experience != null:
			source_upgrade.experience_manager = source_experience


func _remove_destination_manager(destination_scene: Node, name: String, source_manager: Node) -> void:
	var destination_manager = destination_scene.find_child(name, true, false)
	if destination_manager != null and destination_manager != source_manager:
		destination_manager.queue_free()


func _reset_door_states(scene_root: Node) -> void:
	for door in scene_root.find_children("", "Area2D", true, false):
		if door.has_method("reset_transition_state"):
			door.reset_transition_state()
		if door.has_method("defer_reenable"):
			door.defer_reenable()


func _sync_persisted_states(scene_root: Node) -> void:
	var experience_manager = scene_root.find_child("ExperienceManager", true, false)
	if experience_manager != null and experience_manager.has_method("restore_persisted_state"):
		experience_manager.restore_persisted_state()
	var upgrade_manager = scene_root.find_child("UpgradeManager", true, false)
	if upgrade_manager != null and upgrade_manager.has_method("restore_persisted_state"):
		upgrade_manager.restore_persisted_state()


func _position_players_at_exit(scene_root: Node) -> void:
	var tree = scene_root.get_tree()
	if tree == null:
		return
	var exit_door = scene_root.find_child(exit_door_name, true, false)
	if exit_door == null:
		return
	var base_position = exit_door.global_position + DOOR_EXIT_OFFSET
	for player in tree.get_nodes_in_group("player"):
		var player_number = player.get("player_number")
		if typeof(player_number) != TYPE_INT:
			continue
		player.global_position = base_position + PLAYER_FORMATION_OFFSETS.get(player_number, Vector2.ZERO)
