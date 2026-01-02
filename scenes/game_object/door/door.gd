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
const REENABLE_DELAY_FRAMES := 2
const BOSS_ARENA_SCENE_PATH := "res://scenes/level/boss_arena_level.tscn"
const MAIN_SCENE_PATH := "res://scenes/level/main_level.tscn"


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
	is_transitioning = true
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("get_persisted_state"):
			GameEvents.store_player_state(player.player_number, player.get_persisted_state())
	var session = _get_game_session()
	if session != null:
		session.transition_to_level(boss_arena_scene, exit_door_name, true)


func _transition_to_main_scene() -> void:
	if main_scene == null:
		main_scene = load(MAIN_SCENE_PATH)
		if main_scene == null:
			return
	is_transitioning = true
	var session = _get_game_session()
	if session != null:
		session.transition_to_level(main_scene, exit_door_name)


func _get_game_session() -> GameSession:
	return get_tree().get_first_node_in_group("game_session") as GameSession
