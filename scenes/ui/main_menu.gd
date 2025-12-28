extends CanvasLayer


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var menu_buttons: Array[Button] = []
var selected_index := 0


func _ready():
	%PlayButton.pressed.connect(on_play_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%QuitButton.pressed.connect(on_quit_pressed)
	menu_buttons = [
		%PlayButton,
		%OptionsButton,
		%QuitButton,
	]
	if not menu_buttons.is_empty():
		call_deferred("_focus_button", 0)


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	_update_selected_index_from_focus()
	if event.is_action_pressed("ui_up"):
		_focus_button(selected_index - 1)
	elif event.is_action_pressed("ui_down"):
		_focus_button(selected_index + 1)


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


func on_play_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

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
