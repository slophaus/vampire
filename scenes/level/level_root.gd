extends Node
class_name LevelRoot

@export var level_id: StringName = &""
@export var is_timeless := false
@export var spawn_marker_name: StringName = &"PlayerSpawn"
@export var spawn_rate_keyframes: Array[Vector2] = []
@export var enemy_spawn_keyframes: Array[EnemySpawnKeyframe] = []
