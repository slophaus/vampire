extends CanvasLayer
class_name PauseMenu

@onready var panel_container = %PanelContainer

var options_scene = preload("res://scenes/ui/options_menu.tscn")
var is_closing := false
var menu_buttons: Array[Button] = []
var selected_index := 0
var menu_navigation := MenuNavigation.new()


func _ready():
	get_tree().paused = true
	panel_container.pivot_offset = panel_container.size / 2
	
	%ResumeButton.pressed.connect(on_resume_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%QuitButton.pressed.connect(on_quit_pressed)
	menu_buttons = [
		%ResumeButton,
		%OptionsButton,
		%QuitButton,
	]
	
	$AnimationPlayer.play("default")
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	if not menu_buttons.is_empty():
		call_deferred("_focus_button", 0)


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		close()
		get_tree().root.set_input_as_handled()
		return
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


func close():
	if is_closing:
		return
	is_closing = true
	
	$AnimationPlayer.play_backwards("default")
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0)
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0.3) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_BACK)
	await tween.finished
	
	get_tree().paused = false
	queue_free()


func on_resume_pressed():
	close()


func on_options_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	var options_instance = options_scene.instantiate() as OptionsMenu
	add_child(options_instance)
	options_instance.back_pressed.connect(on_options_closed.bind(options_instance))


func on_options_closed(options_instance: OptionsMenu):
	options_instance.queue_free()


func on_quit_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


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
