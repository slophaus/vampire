extends MenuNavigation


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var menu_buttons: Array[Button] = []
var selected_index := 0
var player_count_buttons: Array[Button] = []
var player_color_buttons: Array[Button] = []


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
	player_color_buttons = player_count_buttons.duplicate()
	%OnePlayerButton.button_pressed = true
	GameEvents.player_count = 1
	_update_player_count_selection(%OnePlayerButton)
	_refresh_player_count_button_colors()
	if not menu_buttons.is_empty():
		await get_tree().process_frame
		selected_index = focus_item(0, menu_buttons)


func _input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	selected_index = update_selected_index_from_focus(menu_buttons, selected_index)
	if should_navigate("ui_up"):
		selected_index = focus_item(selected_index - 1, menu_buttons)
	elif should_navigate("ui_down"):
		selected_index = focus_item(selected_index + 1, menu_buttons)
	elif should_navigate("ui_left"):
		_handle_player_count_horizontal(-1)
	elif should_navigate("ui_right"):
		_handle_player_count_horizontal(1)
	elif event.is_action_pressed("cycle_player_color") and event.device == 0:
		_cycle_active_player_color()


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


func _handle_player_count_horizontal(direction: int) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or focused not in player_color_buttons:
		return
	var current_index = player_color_buttons.find(focused)
	if current_index == -1:
		return
	var target_index = clampi(current_index + direction, 0, player_color_buttons.size() - 1)
	selected_index = focus_item(target_index, player_color_buttons)
	get_viewport().set_input_as_handled()


func _cycle_active_player_color() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or focused not in player_color_buttons:
		return
	var player_index = player_color_buttons.find(focused) + 1
	if player_index <= 0:
		return
	GameEvents.cycle_player_color(player_index)
	_refresh_player_count_button_colors()
	get_viewport().set_input_as_handled()


func _refresh_player_count_button_colors() -> void:
	for index in range(player_color_buttons.size()):
		var button = player_color_buttons[index]
		var color = GameEvents.get_player_color(index + 1)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.add_theme_color_override("font_disabled_color", color)


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
