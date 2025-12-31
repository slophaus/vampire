class_name MenuNavigation
extends CanvasLayer

const NAVIGATION_REPEAT_DELAY := 0.35
const NAVIGATION_AXIS_THRESHOLD := 0.6
const NAVIGATION_AXIS_RELEASE := 0.45

var last_navigation_time := {}
var navigation_hold := {}
var last_navigation_frame := -1


func should_navigate(action: StringName) -> bool:
	if Engine.get_process_frames() == last_navigation_frame:
		return false
	if not navigation_hold.has(action):
		navigation_hold[action] = false
	if not last_navigation_time.has(action):
		last_navigation_time[action] = -1.0
	if _is_action_released(action):
		navigation_hold[action] = false
		return false
	if not _is_action_down(action):
		return false
	var now = _get_time()
	if not navigation_hold[action]:
		navigation_hold[action] = true
		last_navigation_time[action] = now
		last_navigation_frame = Engine.get_process_frames()
		get_viewport().set_input_as_handled()
		return true
	if now - last_navigation_time[action] >= NAVIGATION_REPEAT_DELAY:
		last_navigation_time[action] = now
		last_navigation_frame = Engine.get_process_frames()
		get_viewport().set_input_as_handled()
		return true
	return false


func focus_item(index: int, items: Array) -> int:
	if items.is_empty():
		return -1
	var clamped_index = clampi(index, 0, items.size() - 1)
	var control = items[clamped_index]
	if control is Control:
		control.grab_focus()
	return clamped_index


func update_selected_index_from_focus(items: Array, current_index: int) -> int:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return current_index
	var control_index = items.find(focused)
	if control_index != -1:
		return control_index
	return current_index


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _is_action_down(action: StringName) -> bool:
	return Input.get_action_strength(action) >= NAVIGATION_AXIS_THRESHOLD


func _is_action_released(action: StringName) -> bool:
	return Input.get_action_strength(action) <= NAVIGATION_AXIS_RELEASE
