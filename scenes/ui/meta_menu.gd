extends CanvasLayer
class_name MetaMenu

@export var upgrades: Array[MetaUpgrade] = []

@onready var grid_container: GridContainer = %GridContainer
@onready var back_button: Button = %BackButton

var meta_upgrade_card_scene = preload("res://scenes/ui/meta_upgrade_card.tscn")
var cards: Array[MetaUpgradeCard] = []
var selected_index := 0


func _ready():
	back_button.pressed.connect(on_back_pressed)
	
	# remove debug childrens
	for child in grid_container.get_children():
		child.queue_free()
	
	cards.clear()
	for u in upgrades:
		var meta_upgrade_card_instance = meta_upgrade_card_scene.instantiate() as MetaUpgradeCard
		grid_container.add_child(meta_upgrade_card_instance)
		meta_upgrade_card_instance.set_meta_upgrade(u)
		cards.append(meta_upgrade_card_instance)

	if not cards.is_empty():
		call_deferred("_focus_card", 0)
	else:
		call_deferred("_focus_back_button")


func _unhandled_input(event: InputEvent) -> void:
	_update_selected_index_from_focus()
	if event.is_action_pressed("ui_up"):
		if get_viewport().gui_get_focus_owner() == back_button:
			return
		if selected_index < grid_container.columns:
			_focus_back_button()
		else:
			_focus_card(selected_index - grid_container.columns)
	elif event.is_action_pressed("ui_down"):
		if get_viewport().gui_get_focus_owner() == back_button:
			_focus_card(0)
			return
		_focus_card(selected_index + grid_container.columns)
	elif event.is_action_pressed("ui_left"):
		if get_viewport().gui_get_focus_owner() != back_button:
			_focus_card(selected_index - 1)
	elif event.is_action_pressed("ui_right"):
		if get_viewport().gui_get_focus_owner() != back_button:
			_focus_card(selected_index + 1)


func _focus_back_button() -> void:
	back_button.grab_focus()


func _focus_card(index: int) -> void:
	if cards.is_empty():
		return

	selected_index = clampi(index, 0, cards.size() - 1)
	cards[selected_index].grab_focus()


func _update_selected_index_from_focus() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var card_index = cards.find(focused)
	if card_index != -1:
		selected_index = card_index


func on_back_pressed():
	ScreenTransition.transition_to_scene("res://scenes/ui/main_menu.tscn")
