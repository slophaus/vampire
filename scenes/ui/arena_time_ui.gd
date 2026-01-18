extends CanvasLayer

@export var arena_time_manager: ArenaTimeManager
@export var enemy_manager: EnemyManager
@onready var label = %Label
@onready var stats_label = %StatsLabel
@onready var stats_container = %StatsContainer


func _ready() -> void:
	GameEvents.debug_mode_toggled.connect(_on_debug_mode_toggled)
	_on_debug_mode_toggled(GameEvents.debug_mode_enabled)

func _process(delta):
	if arena_time_manager == null:
		return

	var time_elapsed = arena_time_manager.get_time_elapsed()
	label.text = format_seconds_to_string(time_elapsed)
	var spawn_rate = 0.0
	var failed_spawns = 0
	var navigation_ms = 0.0
	var navigation_calls_per_second = 0.0
	var last_spawn_ms = 0.0
	if enemy_manager != null:
		spawn_rate = enemy_manager.get_spawn_rate()
		failed_spawns = enemy_manager.get_failed_spawn_count()
		navigation_ms = enemy_manager.get_last_navigation_ms()
		navigation_calls_per_second = enemy_manager.get_navigation_calls_per_second()
		last_spawn_ms = enemy_manager.get_last_spawn_ms()

	var process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	stats_label.text = "FPS: %d\nEnemies: %d\nDifficulty: %d\nNext Diff: %s\nSpawn Rate: %.2f/s\nFailed Spawns: %d\nNavigation: %.2f ms\nNav Calls: %.2f/s\nLast Spawn: %.2f ms\nProcess: %.2f ms\nPhysics: %.2f ms" % [
		Engine.get_frames_per_second(),
		get_tree().get_nodes_in_group("enemy").size(),
		arena_time_manager.get_arena_difficulty(),
		format_seconds_to_string(arena_time_manager.get_time_until_next_difficulty()),
		spawn_rate,
		failed_spawns,
		navigation_ms,
		navigation_calls_per_second,
		last_spawn_ms,
		process_ms,
		physics_ms
	]


func _on_debug_mode_toggled(enabled: bool) -> void:
	stats_container.visible = enabled


func format_seconds_to_string(seconds: float) -> String:
	var minutes = floor(seconds / 60)
	var remaining_seconds = floor(seconds - (minutes * 60))
	return "%d:%02d" % [minutes, remaining_seconds]
