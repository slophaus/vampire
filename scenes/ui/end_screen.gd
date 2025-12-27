extends CanvasLayer
class_name EndScreen

@onready var panel_container := %PanelContainer
var menu_buttons: Array[Control] = []
var selected_index := 0


func _ready():
	panel_container.pivot_offset = panel_container.size / 2
	panel_container.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	
	get_tree().paused = true
	%ContinueButton.pressed.connect(on_continue_button_pressed)
	%QuitButton.pressed.connect(on_quit_button_pressed)
	menu_buttons = [
		%ContinueButton,
		%QuitButton,
	]
	for button in menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	call_deferred("_focus_button", 0)


func _unhandled_input(event):
	if menu_buttons.is_empty():
		return

	if event.is_action_pressed("ui_down"):
		_focus_button(selected_index + 1)
	elif event.is_action_pressed("ui_up"):
		_focus_button(selected_index - 1)


func _focus_button(index: int) -> void:
	selected_index = clampi(index, 0, menu_buttons.size() - 1)
	menu_buttons[selected_index].grab_focus()


func set_defeat():
	%TitleLabel.text = "Defeat"
	%DescriptionLabel.text = "You lost!"
	play_jingle(true)


func play_jingle(defeat: bool = false):
	if defeat:
		$DefeatStreamPlayer.play()
	else:
		$VictoryStreamPlayer.play()


func on_continue_button_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/meta_menu.tscn")


func on_quit_button_pressed():
	ScreenTransition.transition_to_scene("res://scenes/ui/main_menu.tscn")
	get_tree().paused = false
	await ScreenTransition.transitioned_halfway
