extends Node
class_name ArenaTimeManager

signal arena_difficulty_increased(arena_difficulty: int)
signal arena_time_completed

const DIFFICULTY_INTERVAL := 15

@export var end_screen_scene: PackedScene

@onready var timer = $Timer

var arena_difficulty = 1
var base_duration := 0.0
var total_duration := 0.0


func _ready():
	timer.timeout.connect(on_timer_timeout)
	base_duration = timer.wait_time
	total_duration = base_duration


func _process(delta):
	var next_time_target = total_duration - ((arena_difficulty + 1) * DIFFICULTY_INTERVAL)
	if timer.time_left <= next_time_target:
		arena_difficulty += 1
		arena_difficulty_increased.emit(arena_difficulty)
		#print("difficulty: %d, time_left: %f, next_time_target: %f" % [arena_difficulty, timer.time_left, next_time_target])


func get_time_elapsed():
	return total_duration - timer.time_left


func get_arena_difficulty() -> int:
	return arena_difficulty


func get_time_until_next_difficulty() -> float:
	var next_time_target = total_duration - ((arena_difficulty + 1) * DIFFICULTY_INTERVAL)
	return max(0.0, timer.time_left - next_time_target)


func get_state() -> Dictionary:
	return {
		"arena_difficulty": arena_difficulty,
		"time_left": timer.time_left,
		"total_duration": total_duration,
	}


func apply_state(state: Dictionary) -> void:
	arena_difficulty = int(state.get("arena_difficulty", 1))
	total_duration = float(state.get("total_duration", base_duration))
	var time_left = float(state.get("time_left", total_duration))
	timer.stop()
	timer.start(max(time_left, 0.0))


func reset_state() -> void:
	arena_difficulty = 1
	total_duration = base_duration
	timer.stop()
	timer.start(base_duration)


func on_timer_timeout():
	arena_time_completed.emit()
