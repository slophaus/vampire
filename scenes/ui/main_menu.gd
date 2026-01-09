extends CanvasLayer


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var player_count_buttons: Array[Button] = []
var player_color_buttons: Array[Button] = []


func _ready():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	%OnePlayerButton.pressed.connect(on_player_count_selected.bind(1))
	%TwoPlayerButton.pressed.connect(on_player_count_selected.bind(2))
	%ThreePlayerButton.pressed.connect(on_player_count_selected.bind(3))
	%FourPlayerButton.pressed.connect(on_player_count_selected.bind(4))
	%PlayButton.pressed.connect(on_play_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%QuitButton.pressed.connect(on_quit_pressed)
	player_count_buttons = [
		%OnePlayerButton,
		%TwoPlayerButton,
		%ThreePlayerButton,
		%FourPlayerButton,
	]
	player_color_buttons = player_count_buttons.duplicate()
	_configure_focus_navigation()
	%OnePlayerButton.button_pressed = true
	GameEvents.player_count = 1
	_update_player_count_selection(%OnePlayerButton)
	_refresh_player_count_button_colors()
	%OnePlayerButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_player_color") and event.device == 0:
		_cycle_active_player_color(1)
	if event.is_action_pressed("cycle_player_color_reverse") and event.device == 0:
		_cycle_active_player_color(-1)


func on_play_pressed():
	GameEvents.reset_persisted_state()
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/main/game_session.tscn")

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


func _cycle_active_player_color(direction: int) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or focused not in player_color_buttons:
		return
	var player_index = player_color_buttons.find(focused) + 1
	if player_index <= 0:
		return
	GameEvents.cycle_player_color(player_index, direction)
	_refresh_player_count_button_colors()

func _configure_focus_navigation() -> void:
	%OnePlayerButton.focus_neighbor_right = %TwoPlayerButton.get_path()
	%TwoPlayerButton.focus_neighbor_left = %OnePlayerButton.get_path()
	%TwoPlayerButton.focus_neighbor_right = %ThreePlayerButton.get_path()
	%ThreePlayerButton.focus_neighbor_left = %TwoPlayerButton.get_path()
	%ThreePlayerButton.focus_neighbor_right = %FourPlayerButton.get_path()
	%FourPlayerButton.focus_neighbor_left = %ThreePlayerButton.get_path()
	%OnePlayerButton.focus_neighbor_bottom = %PlayButton.get_path()
	%TwoPlayerButton.focus_neighbor_bottom = %PlayButton.get_path()
	%ThreePlayerButton.focus_neighbor_bottom = %PlayButton.get_path()
	%FourPlayerButton.focus_neighbor_bottom = %PlayButton.get_path()
	%PlayButton.focus_neighbor_top = %OnePlayerButton.get_path()
	%OptionsButton.focus_neighbor_top = %PlayButton.get_path()
	%QuitButton.focus_neighbor_top = %OptionsButton.get_path()


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
	%OnePlayerButton.grab_focus()
