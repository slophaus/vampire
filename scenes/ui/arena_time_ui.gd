extends CanvasLayer

@export var arena_time_manager: ArenaTimeManager
@export var enemy_manager: EnemyManager
@onready var label = %Label
@onready var stats_label = %StatsLabel

func _process(delta):
	if arena_time_manager == null:
		return

	var time_elapsed = arena_time_manager.get_time_elapsed()
	label.text = format_seconds_to_string(time_elapsed)
	var spawn_rate = 0.0
	var failed_spawns = 0
	if enemy_manager != null:
		spawn_rate = enemy_manager.get_spawn_rate()
		failed_spawns = enemy_manager.get_failed_spawn_count()

	var process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	stats_label.text = "FPS: %d\nEnemies: %d\nDifficulty: %d\nNext Diff: %s\nSpawn Rate: %.2f/s\nFailed Spawns: %d\nProcess: %.2f ms\nPhysics: %.2f ms" % [
		Engine.get_frames_per_second(),
		get_tree().get_nodes_in_group("enemy").size(),
		arena_time_manager.get_arena_difficulty(),
		format_seconds_to_string(arena_time_manager.get_time_until_next_difficulty()),
		spawn_rate,
		failed_spawns,
		process_ms,
		physics_ms
	]


func format_seconds_to_string(seconds: float) -> String:
	var minutes = floor(seconds / 60)
	var remaining_seconds = floor(seconds - (minutes * 60))
	return "%d:%02d" % [minutes, remaining_seconds]
