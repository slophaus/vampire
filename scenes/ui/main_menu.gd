extends CanvasLayer


var options_scene = preload("res://scenes/ui/options_menu.tscn")
var menu_buttons: Array[Button] = []
var selected_index := 0
var player_count_buttons: Array[Button] = []
var player_color_buttons: Array[Button] = []
var last_navigation_time := -1.0
const NAVIGATION_REPEAT_DELAY := 0.2


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
		call_deferred("_focus_button", 0)


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	_update_selected_index_from_focus()
	if event.is_action_pressed("ui_up"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_focus_button(selected_index - 1)
	elif event.is_action_pressed("ui_down"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_focus_button(selected_index + 1)
	elif event.is_action_pressed("ui_left"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_handle_player_count_horizontal(-1)
	elif event.is_action_pressed("ui_right"):
		if not _can_navigate():
			return
		last_navigation_time = _get_time()
		_handle_player_count_horizontal(1)
	elif event.is_action_pressed("cycle_player_color") and event.device == 0:
		_cycle_active_player_color()


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
	selected_index = target_index
	player_color_buttons[target_index].grab_focus()
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


func _can_navigate() -> bool:
	return _get_time() - last_navigation_time >= NAVIGATION_REPEAT_DELAY


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0

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
