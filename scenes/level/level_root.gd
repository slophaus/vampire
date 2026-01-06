extends Node
class_name LevelRoot

@export var level_id: StringName = &""
@export var is_timeless := false
@export var spawn_marker_name: StringName = &"PlayerSpawn"
@export var spawn_rate_keyframes: Array[Vector2] = []
@export_group("Enemy Spawn Keyframes (x = arena difficulty, y = enemy id, z = weight)")
@export var enemy_spawn_keyframes: Array[Vector3] = []
