extends CanvasLayer
class_name EndScreen

@onready var panel_container := %PanelContainer
var menu_buttons: Array[Button] = []
var selected_index := 0
var last_navigation_time := -1.0
const NAVIGATION_REPEAT_DELAY := 0.2


func _ready():
	panel_container.pivot_offset = panel_container.size / 2
	panel_container.scale = Vector2.ONE
	panel_container.modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property(panel_container, "modulate", Color.WHITE, 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	
	get_tree().paused = true
	%QuitButton.pressed.connect(on_quit_button_pressed)
	menu_buttons = [
		%QuitButton,
	]
	if not menu_buttons.is_empty():
		call_deferred("_focus_button", 0)


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	_update_selected_index_from_focus()
	if event.is_action_pressed("ui_up"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_focus_button(selected_index - 1)
	elif event.is_action_pressed("ui_down"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_focus_button(selected_index + 1)


func set_defeat():
	%TitleLabel.text = "Defeat"
	%DescriptionLabel.text = "You lost!"
	play_jingle(true)


func play_jingle(defeat: bool = false):
	if defeat:
		$DefeatStreamPlayer.play()
	else:
		$VictoryStreamPlayer.play()


func on_quit_button_pressed():
	ScreenTransition.transition_to_scene("res://scenes/ui/main_menu.tscn")
	get_tree().paused = false
	await ScreenTransition.transitioned_halfway


func _focus_button(index: int) -> void:
	selected_index = clampi(index, 0, menu_buttons.size() - 1)
	menu_buttons[selected_index].grab_focus()


func _update_selected_index_from_focus() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var button_index = menu_buttons.find(focused)
	if button_index != -1:
		selected_index = button_index


func _can_navigate() -> bool:
	return _get_time() - last_navigation_time >= NAVIGATION_REPEAT_DELAY


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0
