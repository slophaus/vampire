extends CanvasLayer
class_name OptionsMenu

signal back_pressed

@onready var window_button: Button = %WindowButton
@onready var music_slider: Slider = %MusicSlider
@onready var sfx_slider: Slider = %SfxSlider
@onready var back_button: Button = %BackButton
var menu_controls: Array[Control] = []
var selected_index := 0


func _ready():
	back_button.pressed.connect(on_back_pressed)
	window_button.pressed.connect(on_window_button_pressed)
	music_slider.value_changed.connect(on_audio_slider_changed.bind("music"))
	sfx_slider.value_changed.connect(on_audio_slider_changed.bind("sfx"))
	update_display()
	menu_controls = [
		window_button,
		music_slider,
		sfx_slider,
		back_button,
	]
	for control in menu_controls:
		control.focus_mode = Control.FOCUS_ALL
	call_deferred("_focus_control", 0)


func _unhandled_input(event):
	if menu_controls.is_empty():
		return

	if event.is_action_pressed("ui_down"):
		_focus_control(selected_index + 1)
	elif event.is_action_pressed("ui_up"):
		_focus_control(selected_index - 1)


func _focus_control(index: int) -> void:
	selected_index = clampi(index, 0, menu_controls.size() - 1)
	menu_controls[selected_index].grab_focus()


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
