extends Area2D


@export var target_scene: PackedScene
@export_file("*.tscn") var target_scene_path := ""
@export var exit_door_name: StringName = &"Door"
@export var preserve_current_level := false

var is_transitioning := false
const REENABLE_DELAY_FRAMES := 2
func _enter_tree() -> void:
	add_to_group("doors")


func _ready() -> void:
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
	_transition_to_target()


func _transition_to_target() -> void:
	var scene = target_scene
	if scene == null and not target_scene_path.is_empty():
		scene = load(target_scene_path) as PackedScene
	if scene == null:
		return
	is_transitioning = true
	var session = _get_game_session()
	if session != null:
		session.transition_to_level(scene, exit_door_name, preserve_current_level)


func _get_game_session() -> GameSession:
	return get_tree().get_first_node_in_group("game_session") as GameSession
