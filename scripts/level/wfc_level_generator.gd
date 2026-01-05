extends Node
class_name WFCLevelGenerator

@export var target_tilemap_path: NodePath
@export var sample_tilemap_path: NodePath
@export var generate_on_ready := true
@export var max_attempts := 5
@export var random_seed := 0
@export_range(1, 4, 1) var overlap_size := 2


func _ready() -> void:
	if generate_on_ready:
		generate_level()


func generate_level() -> void:
	print_debug("WFC: placeholder generator (implementation removed)")
