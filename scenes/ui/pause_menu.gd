extends CanvasLayer
class_name PauseMenu

@onready var panel_container = %PanelContainer

var options_scene = preload("res://scenes/ui/options_menu.tscn")
var is_closing := false
var menu_buttons: Array[Control] = []
var selected_index := 0


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
	for button in menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	call_deferred("_focus_button", 0)
	
	$AnimationPlayer.play("default")
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		close()
		get_tree().root.set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_button(selected_index + 1)
	elif event.is_action_pressed("ui_up"):
		_focus_button(selected_index - 1)


func _focus_button(index: int) -> void:
	if menu_buttons.is_empty():
		return

	selected_index = clampi(index, 0, menu_buttons.size() - 1)
	menu_buttons[selected_index].grab_focus()


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
