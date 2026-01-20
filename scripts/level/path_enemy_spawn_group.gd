extends Resource
class_name PathEnemySpawnGroup

@export_range(0.0, 1.0, 0.01) var path_percent := 0.5
@export var enemy_scene: PackedScene
@export_range(1, 50, 1) var count := 1
@export_range(0.0, 20.0, 0.5) var spread_tiles := 0.0
@export var constrain_to_reachable_ground := true
