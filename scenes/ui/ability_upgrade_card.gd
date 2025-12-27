extends PanelContainer
class_name AbilityUpgradeCard

signal selected

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel

var disabled := false
var normal_style: StyleBox
var highlighted_style: StyleBox


func _ready():
	gui_input.connect(on_gui_input)
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)
	focus_entered.connect(on_focus_entered)
	focus_exited.connect(on_focus_exited)
	focus_mode = Control.FOCUS_ALL
	_setup_styles()


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
	_clear_highlight()
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

	if event.is_action_pressed("left_click") or event.is_action_pressed("ui_accept"):
		select_card()


func on_mouse_entered():
	if disabled:
		return true

	grab_focus()
	$HoverAnimationPlayer.play("hover")


func on_focus_entered():
	if disabled:
		return

	$HoverAnimationPlayer.play("hover")
	_apply_highlight()


func on_mouse_exited():
	if disabled:
		return

	if not has_focus():
		_clear_highlight()


func on_focus_exited():
	if disabled:
		return

	_clear_highlight()


func _setup_styles():
	var theme_style = get_theme_stylebox("panel")
	if theme_style:
		normal_style = theme_style.duplicate()
	else:
		normal_style = StyleBoxFlat.new()

	highlighted_style = normal_style.duplicate()
	if highlighted_style is StyleBoxFlat:
		var style = highlighted_style as StyleBoxFlat
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(1.0, 0.9, 0.25)

	add_theme_stylebox_override("panel", normal_style)


func _apply_highlight():
	if highlighted_style:
		add_theme_stylebox_override("panel", highlighted_style)


func _clear_highlight():
	if normal_style:
		add_theme_stylebox_override("panel", normal_style)
