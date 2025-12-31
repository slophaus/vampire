extends RefCounted
class_name MenuNavigation

var navigation_repeat_delay := 0.2
var joystick_threshold := 0.6
var last_navigation_time := -1.0
var axis_active := {}


func _init() -> void:
	axis_active[JOY_AXIS_LEFT_Y] = false
	axis_active[JOY_AXIS_LEFT_X] = false


func can_navigate() -> bool:
	return _get_time() - last_navigation_time >= navigation_repeat_delay


func mark_navigated() -> void:
	last_navigation_time = _get_time()


func get_axis_direction(event: InputEventJoypadMotion, axis: int) -> int:
	if event.axis != axis:
		return 0
	var value := event.axis_value
	if abs(value) < joystick_threshold:
		axis_active[axis] = false
		return 0
	if axis_active.get(axis, false):
		return 0
	axis_active[axis] = true
	if not can_navigate():
		return 0
	mark_navigated()
	return -1 if value < 0.0 else 1


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0
