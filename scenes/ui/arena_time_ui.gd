extends CanvasLayer

@export var arena_time_manager: Node
@onready var label = %Label
@onready var stats_label = %StatsLabel

func _process(delta):
	if arena_time_manager == null:
		return

	var time_elapsed = arena_time_manager.get_time_elapsed()
	label.text = format_seconds_to_string(time_elapsed)
	stats_label.text = "FPS: %d\nEnemies: %d" % [
		Engine.get_frames_per_second(),
		get_tree().get_nodes_in_group("enemy").size()
	]


func format_seconds_to_string(seconds: float) -> String:
	var minutes = floor(seconds / 60)
	var remaining_seconds = floor(seconds - (minutes * 60))
	return "%d:%02d" % [minutes, remaining_seconds]
