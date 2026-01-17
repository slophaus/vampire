extends Panel
class_name AbilityUpgradeCard

signal selected

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var focus_outline: OutlineRect = %FocusOutline

var disabled := false
var controlling_player_number := 1


func _ready():
	gui_input.connect(on_gui_input)
	mouse_entered.connect(on_mouse_entered)
	focus_entered.connect(on_focus_entered)
	focus_exited.connect(on_focus_exited)
	focus_mode = Control.FOCUS_ALL
	if focus_outline != null:
		focus_outline.visible = false


func play_in(delay: float = 0):
	modulate = Color.TRANSPARENT
	await get_tree().create_timer(delay).timeout
	$AnimationPlayer.play("in")


func play_discard():
	$AnimationPlayer.play("discard")


func set_ability_upgrade(upgrade: AbilityUpgrade, display_name: String = "", display_description: String = "") -> void:
	name_label.text = display_name if display_name != "" else upgrade.name
	description_label.text = display_description if display_description != "" else upgrade.description


func select_card():
	disabled = true
	$AnimationPlayer.play("selected")
	
	# make other cards disappear
	for other_card in get_tree().get_nodes_in_group("upgrade_card"):
		if other_card == self:
			continue
		(other_card as AbilityUpgradeCard).play_discard()
	
	await $AnimationPlayer.animation_finished
	selected.emit()


func on_gui_input(event: InputEvent):
	if disabled:
		return
	if not is_event_for_player(event):
		return

	if event.is_action_pressed("left_click") or event.is_action_pressed("ui_accept"):
		select_card()


func on_mouse_entered():
	if disabled:
		return true
	if controlling_player_number != 1:
		return

	grab_focus()
	$HoverAnimationPlayer.play("hover")


func on_focus_entered():
	if disabled:
		return

	if focus_outline != null:
		focus_outline.visible = true
	$HoverAnimationPlayer.play("hover")


func on_focus_exited():
	if disabled:
		return

	if focus_outline != null:
		focus_outline.visible = false


func set_controlling_player(player_number: int) -> void:
	controlling_player_number = player_number


func set_focus_color(color: Color) -> void:
	if focus_outline != null:
		focus_outline.set_outline_color(color)


func is_event_for_player(event: InputEvent) -> bool:
	var device_id = get_player_device_id(controlling_player_number)
	if controlling_player_number == 1:
		return event.device == -1 or event.device == device_id
	return event.device == device_id


func get_player_device_id(player_number: int) -> int:
	return max(player_number - 1, 0)
