extends MenuNavigation
class_name EndScreen

@onready var panel_container := %PanelContainer
var menu_buttons: Array[Button] = []
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
	%QuitButton.pressed.connect(on_quit_button_pressed)
	menu_buttons = [
		%QuitButton,
	]
	if not menu_buttons.is_empty():
		await get_tree().process_frame
		selected_index = focus_item(0, menu_buttons)


func _input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	selected_index = update_selected_index_from_focus(menu_buttons, selected_index)
	if should_navigate("ui_up", event):
		selected_index = focus_item(selected_index - 1, menu_buttons)
	elif should_navigate("ui_down", event):
		selected_index = focus_item(selected_index + 1, menu_buttons)


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
