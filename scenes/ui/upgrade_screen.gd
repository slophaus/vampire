extends CanvasLayer

signal upgrade_selected(upgrade: AbilityUpgrade)

@export var upgrade_card_scene: PackedScene
@onready var card_container: HBoxContainer = %CardContainer

var cards: Array[AbilityUpgradeCard] = []
var selected_index := 0
var controlling_player_number := 1
var highlight_color := Color.RED


func _ready():
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if cards.is_empty():
		return
	if is_event_for_player(event):
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()


func set_ability_upgrades(upgrades: Array[AbilityUpgrade], current_upgrades: Dictionary):
	var delay := 0.0
	cards.clear()
	for upgrade in upgrades:
		var card_instance = upgrade_card_scene.instantiate()
		card_container.add_child(card_instance)
		card_instance.set_controlling_player(controlling_player_number)
		card_instance.set_focus_color(highlight_color)
		var display_name = get_display_name(upgrade, current_upgrades)
		var display_description = get_display_description(upgrade)
		card_instance.set_ability_upgrade(upgrade, display_name, display_description)
		card_instance.play_in(delay)
		card_instance.selected.connect(on_upgrade_selected.bind(upgrade))
		cards.append(card_instance)
		delay += 0.1
	if not cards.is_empty():
		call_deferred("_focus_card", 0)


func get_display_name(upgrade: AbilityUpgrade, current_upgrades: Dictionary) -> String:
	if upgrade.id == "fireball":
		return "Fireball Level 1"
	if upgrade.id in ["sword_level", "axe_level", "fireball_level", "boomerang_level", "dig_level"]:
		var base_name = upgrade.name.replace(" Level", "")
		var current_quantity = 0
		if current_upgrades.has(upgrade.id):
			current_quantity = current_upgrades[upgrade.id]["quantity"]
		var next_level = current_quantity + 2
		return "%s Level %d" % [base_name, next_level]
	return upgrade.name


func get_display_description(upgrade: AbilityUpgrade) -> String:
	return upgrade.description


func _unhandled_input(event: InputEvent) -> void:
	if cards.is_empty():
		return
	if not is_event_for_player(event):
		return

	if event.is_action_pressed("ui_left"):
		_focus_card(selected_index - 1)
	elif event.is_action_pressed("ui_right"):
		_focus_card(selected_index + 1)


func _focus_card(index: int) -> void:
	if cards.is_empty():
		return

	selected_index = clampi(index, 0, cards.size() - 1)
	cards[selected_index].grab_focus()


func on_upgrade_selected(upgrade: AbilityUpgrade):
	upgrade_selected.emit(upgrade)
	$AnimationPlayer.play("out")
	await $AnimationPlayer.animation_finished
	get_tree().paused = false
	queue_free()


func set_controlling_player(player_number: int) -> void:
	controlling_player_number = player_number
	highlight_color = get_player_highlight_color(player_number)
	for card in cards:
		card.set_controlling_player(controlling_player_number)
		card.set_focus_color(highlight_color)


func is_event_for_player(event: InputEvent) -> bool:
	var device_id = get_player_device_id(controlling_player_number)
	if controlling_player_number == 1:
		return event.device == -1 or event.device == device_id
	return event.device == device_id


func get_player_device_id(player_number: int) -> int:
	return max(player_number - 1, 0)


func get_player_highlight_color(player_number: int) -> Color:
	return GameEvents.get_player_color(player_number)
