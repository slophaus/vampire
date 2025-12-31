class_name MenuNavigation
extends CanvasLayer

const NAVIGATION_REPEAT_DELAY := 0.35

var last_navigation_time := -1.0
var navigation_hold := {}


func should_navigate(action: StringName, event: InputEvent) -> bool:
	if not navigation_hold.has(action):
		navigation_hold[action] = false
	if event.is_action_released(action):
		navigation_hold[action] = false
		return false
	if not event.is_action_pressed(action):
		return false
	if not navigation_hold[action]:
		navigation_hold[action] = true
		last_navigation_time = _get_time()
		return true
	if _get_time() - last_navigation_time >= NAVIGATION_REPEAT_DELAY:
		last_navigation_time = _get_time()
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
