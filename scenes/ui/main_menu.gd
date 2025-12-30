extends CanvasLayer


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var menu_buttons: Array[Button] = []
var selected_index := 0
var player_count_buttons: Array[Button] = []


func _ready():
	%OnePlayerButton.pressed.connect(on_player_count_selected.bind(1))
	%TwoPlayerButton.pressed.connect(on_player_count_selected.bind(2))
	%ThreePlayerButton.pressed.connect(on_player_count_selected.bind(3))
	%FourPlayerButton.pressed.connect(on_player_count_selected.bind(4))
	%PlayButton.pressed.connect(on_play_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%QuitButton.pressed.connect(on_quit_pressed)
	menu_buttons = [
		%OnePlayerButton,
		%TwoPlayerButton,
		%ThreePlayerButton,
		%FourPlayerButton,
		%PlayButton,
		%OptionsButton,
		%QuitButton,
	]
	player_count_buttons = [
		%OnePlayerButton,
		%TwoPlayerButton,
		%ThreePlayerButton,
		%FourPlayerButton,
	]
	%OnePlayerButton.button_pressed = true
	GameEvents.player_count = 1
	_update_player_count_selection(%OnePlayerButton)
	if not menu_buttons.is_empty():
		call_deferred("_focus_button", 0)


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	_update_selected_index_from_focus()
	if event.is_action_pressed("ui_left"):
		if _handle_player_count_horizontal(-1):
			return
	elif event.is_action_pressed("ui_right"):
		if _handle_player_count_horizontal(1):
			return
	elif event.is_action_pressed("ui_up"):
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

func on_player_count_selected(player_count: int) -> void:
	GameEvents.player_count = player_count
	var selected_button = _get_player_count_button(player_count)
	if selected_button != null:
		_update_player_count_selection(selected_button)

func _update_player_count_selection(selected_button: Button) -> void:
	if player_count_buttons.is_empty():
		return
	for button in player_count_buttons:
		var selection_border = button.get_node_or_null("SelectionBorder")
		if selection_border is CanvasItem:
			selection_border.visible = button == selected_button


func _handle_player_count_horizontal(direction: int) -> bool:
	if player_count_buttons.is_empty():
		return false
	var focused = get_viewport().gui_get_focus_owner()
	var current_index = player_count_buttons.find(focused)
	if current_index == -1:
		return false
	var next_index = wrapi(current_index + direction, 0, player_count_buttons.size())
	var next_button = player_count_buttons[next_index]
	next_button.grab_focus()
	next_button.button_pressed = true
	on_player_count_selected(next_index + 1)
	get_viewport().set_input_as_handled()
	return true

func _get_player_count_button(player_count: int) -> Button:
	match player_count:
		1:
			return %OnePlayerButton
		2:
			return %TwoPlayerButton
		3:
			return %ThreePlayerButton
		4:
			return %FourPlayerButton
	return null

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
