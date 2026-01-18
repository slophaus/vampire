extends Node2D
class_name EnemyRespawnMarker

@export var respawn_radius := 200.0

var enemy_index := -1
var enemy_scene_path := ""
var respawn_data: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_respawn_marker")

func configure_from_enemy(enemy: BaseEnemy) -> void:
	enemy_index = enemy.enemy_index
	enemy_scene_path = enemy.get_scene_file_path()
	respawn_data = enemy.get_respawn_data()


func _process(_delta: float) -> void:
	if _should_respawn():
		_respawn_enemy()


func _should_respawn() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var players = tree.get_nodes_in_group("player")
	if players.is_empty():
		return false
	for player in players:
		var player_node = player as Node2D
		if player_node == null:
			continue
		if global_position.distance_to(player_node.global_position) <= respawn_radius:
			return true
	return false


func _respawn_enemy() -> void:
	var packed_scene: PackedScene = null
	if enemy_scene_path != "":
		packed_scene = load(enemy_scene_path) as PackedScene
	if packed_scene == null and enemy_index >= 0:
		var manager = _find_enemy_manager()
		if manager != null:
			packed_scene = manager.get_enemy_scene(enemy_index)
	if packed_scene == null:
		return
	var enemy = packed_scene.instantiate() as Node2D
	if enemy == null:
		return
	var parent_node = get_parent()
	if parent_node == null:
		return
	if enemy is BaseEnemy:
		enemy.enemy_index = enemy_index
		enemy.set_respawn_data(respawn_data)
	parent_node.add_child(enemy)
	if enemy is BaseEnemy:
		var base_name = _get_enemy_base_name()
		NodeNameUtils.assign_unique_name(enemy, parent_node, base_name)
		enemy.wake_from_dormant()
	enemy.global_position = global_position
	queue_free()


func _find_enemy_manager() -> EnemyManager:
	var root := get_tree().get_root()
	if root == null:
		return null
	return root.find_child("EnemyManager", true, false) as EnemyManager


func _get_enemy_base_name() -> String:
	if enemy_scene_path != "":
		return NodeNameUtils.get_base_name_from_scene(enemy_scene_path, "enemy")
	return "enemy"
