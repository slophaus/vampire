extends CanvasLayer
class_name EndScreen

@onready var panel_container := %PanelContainer
@onready var continue_button := %ContinueButton
var menu_buttons: Array[Button] = []
var selected_index := 0
var last_navigation_time := -1.0
const NAVIGATION_REPEAT_DELAY := 0.2
var continue_revealed := false
var is_defeat_screen := false


func _ready():
	panel_container.pivot_offset = panel_container.size / 2
	panel_container.scale = Vector2.ONE
	panel_container.modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property(panel_container, "modulate", Color.WHITE, 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	
	get_tree().paused = true
	continue_button.visible = false
	continue_button.pressed.connect(on_continue_button_pressed)
	%QuitButton.pressed.connect(on_quit_button_pressed)
	_rebuild_menu_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty():
		return

	if is_defeat_screen and not continue_revealed and event.is_action_pressed("select"):
		_reveal_continue_button()
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


func set_defeat():
	%TitleLabel.text = "Defeat"
	%DescriptionLabel.text = "You lost!"
	is_defeat_screen = true
	play_jingle(true)


func play_jingle(defeat: bool = false):
	if defeat:
		$DefeatStreamPlayer.play()
	else:
		$VictoryStreamPlayer.play()


func on_quit_button_pressed():
	GameEvents.reset_persisted_state()
	ScreenTransition.transition_to_scene("res://scenes/ui/main_menu.tscn")
	get_tree().paused = false
	await ScreenTransition.transitioned_halfway


func on_continue_button_pressed():
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.has_method("continue_from_defeat"):
		current_scene.continue_from_defeat()
	get_tree().paused = false
	queue_free()


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


func _can_navigate() -> bool:
	return _get_time() - last_navigation_time >= NAVIGATION_REPEAT_DELAY


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _reveal_continue_button() -> void:
	continue_revealed = true
	continue_button.visible = true
	_rebuild_menu_buttons()
	call_deferred("_focus_button", 0)


func _rebuild_menu_buttons() -> void:
	menu_buttons = []
	if is_defeat_screen and continue_revealed:
		menu_buttons.append(continue_button)
	menu_buttons.append(%QuitButton)
	if not menu_buttons.is_empty():
		call_deferred("_focus_button", 0)
