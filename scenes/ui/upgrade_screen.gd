extends CanvasLayer

signal upgrade_selected(upgrade: AbilityUpgrade)

@export var upgrade_card_scene: PackedScene
@onready var card_container: HBoxContainer = %CardContainer

var cards: Array[AbilityUpgradeCard] = []
var selected_index := 0


func _ready():
	get_tree().paused = true


func set_ability_upgrades(upgrades: Array[AbilityUpgrade]):
	var delay := 0.0
	cards.clear()
	for upgrade in upgrades:
		var card_instance = upgrade_card_scene.instantiate()
		card_container.add_child(card_instance)
		card_instance.set_ability_upgrade(upgrade)
		card_instance.play_in(delay)
		card_instance.selected.connect(on_upgrade_selected.bind(upgrade))
		cards.append(card_instance)
		delay += 0.2
	if not cards.is_empty():
		call_deferred("_focus_card", 0)


func _unhandled_input(event: InputEvent) -> void:
	if cards.is_empty():
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
