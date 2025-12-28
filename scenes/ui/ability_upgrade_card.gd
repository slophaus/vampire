extends PanelContainer
class_name AbilityUpgradeCard

signal selected

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel

var disabled := false
var focus_stylebox: StyleBoxFlat
var focus_color := Color(1, 0.87, 0.2)
var allowed_devices: PackedInt32Array = PackedInt32Array()
var allow_mouse := true


func _ready():
	gui_input.connect(on_gui_input)
	mouse_entered.connect(on_mouse_entered)
	focus_entered.connect(on_focus_entered)
	focus_exited.connect(on_focus_exited)
	focus_mode = Control.FOCUS_ALL
	_setup_focus_stylebox()


func set_focus_color(color: Color) -> void:
	focus_color = color
	_setup_focus_stylebox()
	focus_stylebox.border_color = focus_color
	if has_focus():
		add_theme_stylebox_override("panel", focus_stylebox)


func set_allowed_devices(devices: PackedInt32Array) -> void:
	allowed_devices = devices
	allow_mouse = devices.is_empty() or devices.has(-1)
	mouse_filter = Control.MOUSE_FILTER_STOP if allow_mouse else Control.MOUSE_FILTER_IGNORE


func play_in(delay: float = 0):
	modulate = Color.TRANSPARENT
	await get_tree().create_timer(delay).timeout
	$AnimationPlayer.play("in")


func play_discard():
	$AnimationPlayer.play("discard")


func set_ability_upgrade(upgrade: AbilityUpgrade) -> void:
	name_label.text = upgrade.name
	description_label.text = upgrade.description


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
	if not _is_event_allowed(event):
		return

	if event.is_action_pressed("left_click") or event.is_action_pressed("ui_accept"):
		select_card()


func on_mouse_entered():
	if disabled or not allow_mouse:
		return

	grab_focus()
	$HoverAnimationPlayer.play("hover")


func on_focus_entered():
	if disabled:
		return

	add_theme_stylebox_override("panel", focus_stylebox)
	$HoverAnimationPlayer.play("hover")


func on_focus_exited():
	if disabled:
		return

	remove_theme_stylebox_override("panel")


func _setup_focus_stylebox() -> void:
	if focus_stylebox == null:
		focus_stylebox = StyleBoxFlat.new()
	focus_stylebox.bg_color = Color(0, 0, 0, 0)
	focus_stylebox.border_color = focus_color
	focus_stylebox.set_border_width_all(4)


func _is_event_allowed(event: InputEvent) -> bool:
	if allowed_devices.is_empty():
		return true
	return allowed_devices.has(event.device)
