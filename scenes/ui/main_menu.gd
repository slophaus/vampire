extends CanvasLayer


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var menu_buttons: Array[Control] = []
var selected_index := 0


func _ready():
	%PlayButton.pressed.connect(on_play_pressed)
	%UpgradesButton.pressed.connect(on_upgrades_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%QuitButton.pressed.connect(on_quit_pressed)
	menu_buttons = [
		%PlayButton,
		%UpgradesButton,
		%OptionsButton,
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


func on_play_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func on_upgrades_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/ui/meta_menu.tscn")


func on_options_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway

	var options_instance = options_scene.instantiate() as OptionsMenu
	add_child(options_instance)
	options_instance.back_pressed.connect(on_options_closed.bind(options_instance))

	
func on_quit_pressed():
	get_tree().quit()


func on_options_closed(options_instance: OptionsMenu):
	options_instance.queue_free()
