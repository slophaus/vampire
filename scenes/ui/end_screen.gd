extends CanvasLayer
class_name EndScreen

@onready var panel_container := %PanelContainer
var menu_buttons: Array[Button] = []
var selected_index := 0
var menu_navigation := MenuNavigation.new()


func _ready():
	panel_container.pivot_offset = panel_container.size / 2
	panel_container.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	
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
	if event is InputEventJoypadMotion:
		var vertical_direction = menu_navigation.get_axis_direction(event, JOY_AXIS_LEFT_Y)
		if vertical_direction != 0:
			_focus_button(selected_index + vertical_direction)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_up"):
		if not menu_navigation.can_navigate():
			return
		menu_navigation.mark_navigated()
		_focus_button(selected_index - 1)
	elif event.is_action_pressed("ui_down"):
		if not menu_navigation.can_navigate():
			return
		menu_navigation.mark_navigated()
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
