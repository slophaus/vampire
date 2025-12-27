extends CanvasLayer
class_name MetaMenu

@export var upgrades: Array[MetaUpgrade] = []

@onready var grid_container: GridContainer = %GridContainer
@onready var back_button: Button = %BackButton

var meta_upgrade_card_scene = preload("res://scenes/ui/meta_upgrade_card.tscn")
var upgrade_buttons: Array[Button] = []
var selected_index := 0


func _ready():
	back_button.pressed.connect(on_back_pressed)
	back_button.focus_mode = Control.FOCUS_ALL
	
	# remove debug childrens
	for child in grid_container.get_children():
		child.queue_free()
	
	for u in upgrades:
		var meta_upgrade_card_instance = meta_upgrade_card_scene.instantiate() as MetaUpgradeCard
		grid_container.add_child(meta_upgrade_card_instance)
		meta_upgrade_card_instance.set_meta_upgrade(u)
		meta_upgrade_card_instance.purchase_button.focus_mode = Control.FOCUS_ALL
		upgrade_buttons.append(meta_upgrade_card_instance.purchase_button)
	if not upgrade_buttons.is_empty():
		call_deferred("_focus_button", 0)
	else:
		call_deferred("_focus_back_button")


func _unhandled_input(event):
	if back_button.has_focus():
		if event.is_action_pressed("ui_up") and not upgrade_buttons.is_empty():
			_focus_button(upgrade_buttons.size() - 1)
		return

	if upgrade_buttons.is_empty():
		return

	if event.is_action_pressed("ui_left"):
		_move_focus(0, -1)
	elif event.is_action_pressed("ui_right"):
		_move_focus(0, 1)
	elif event.is_action_pressed("ui_up"):
		_move_focus(-1, 0)
	elif event.is_action_pressed("ui_down"):
		if selected_index + grid_container.columns >= upgrade_buttons.size():
			_focus_back_button()
		else:
			_move_focus(1, 0)


func _move_focus(row_delta: int, col_delta: int) -> void:
	var columns = max(1, grid_container.columns)
	var row = selected_index / columns
	var col = selected_index % columns
	var next_row = row + row_delta
	var next_col = col + col_delta
	if next_row < 0 or next_col < 0:
		return
	var next_index = (next_row * columns) + next_col
	if next_index >= upgrade_buttons.size():
		return
	_focus_button(next_index)


func _focus_button(index: int) -> void:
	selected_index = clampi(index, 0, upgrade_buttons.size() - 1)
	upgrade_buttons[selected_index].grab_focus()


func _focus_back_button() -> void:
	back_button.grab_focus()


func on_back_pressed():
	ScreenTransition.transition_to_scene("res://scenes/ui/main_menu.tscn")
