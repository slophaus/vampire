extends CanvasLayer
class_name OptionsMenu

signal back_pressed

@onready var window_button: Button = %WindowButton
@onready var music_slider: Slider = %MusicSlider
@onready var sfx_slider: Slider = %SfxSlider
@onready var back_button: Button = %BackButton
@onready var focus_controls: Array[Control] = [
	window_button,
	music_slider,
	sfx_slider,
	back_button,
]

var selected_index := 0
var menu_navigation := MenuNavigation.new()


func _ready():
	back_button.pressed.connect(on_back_pressed)
	window_button.pressed.connect(on_window_button_pressed)
	music_slider.value_changed.connect(on_audio_slider_changed.bind("music"))
	sfx_slider.value_changed.connect(on_audio_slider_changed.bind("sfx"))
	update_display()
	if not focus_controls.is_empty():
		call_deferred("_focus_control", 0)


func _unhandled_input(event: InputEvent) -> void:
	if focus_controls.is_empty():
		return

	_update_selected_index_from_focus()
	if event is InputEventJoypadMotion:
		var vertical_direction = menu_navigation.get_axis_direction(event, JOY_AXIS_LEFT_Y)
		if vertical_direction != 0:
			_focus_control(selected_index + vertical_direction)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_up"):
		if not menu_navigation.can_navigate():
			return
		menu_navigation.mark_navigated()
		_focus_control(selected_index - 1)
	elif event.is_action_pressed("ui_down"):
		if not menu_navigation.can_navigate():
			return
		menu_navigation.mark_navigated()
		_focus_control(selected_index + 1)


func _focus_control(index: int) -> void:
	selected_index = clampi(index, 0, focus_controls.size() - 1)
	focus_controls[selected_index].grab_focus()


func _update_selected_index_from_focus() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var control_index = focus_controls.find(focused)
	if control_index != -1:
		selected_index = control_index


func update_display():
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_button.text = "Fullscreen"
		_:
			window_button.text = "Windowed"
	music_slider.value = get_bus_volume_percent("music")
	sfx_slider.value = get_bus_volume_percent("sfx")


func get_bus_volume_percent(bus_name: String):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		# TODO: assert or warn
		return 0
	var volume_db = AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(volume_db)


func set_bus_volume_percent(bus_name: String, percent: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		# TODO: assert or warn
		return
	var volume_db = linear_to_db(percent)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func on_window_button_pressed():
	var mode := DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	update_display()


func on_audio_slider_changed(value: float, bus_name: String):
	set_bus_volume_percent(bus_name, value)



func on_back_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	back_pressed.emit()
