extends CanvasLayer

@export var experience_manager: ExperienceManager
@onready var progress_bar = %ProgressBar
@onready var fill_style_box: StyleBoxFlat = null

const PLAYER_ONE_COLOR = Color(1, 0, 0)
const PLAYER_TWO_COLOR = Color(0, 0.4, 1)


func _ready():
	progress_bar.value = 0
	var base_style = progress_bar.get_theme_stylebox("fill", "ProgressBar")
	if base_style is StyleBoxFlat:
		fill_style_box = base_style.duplicate() as StyleBoxFlat
		progress_bar.add_theme_stylebox_override("fill", fill_style_box)
	set_turn_highlight(1)
	experience_manager.experience_updated.connect(on_experience_updated)
	GameEvents.upgrade_turn_changed.connect(on_upgrade_turn_changed)


func on_experience_updated(current_experience: float, target_experience: float):
	if target_experience == 0:
		return

	var percent = current_experience / target_experience
	progress_bar.value = percent


func on_upgrade_turn_changed(player_number: int):
	set_turn_highlight(player_number)


func set_turn_highlight(player_number: int):
	if fill_style_box == null:
		return

	fill_style_box.bg_color = PLAYER_ONE_COLOR if player_number == 1 else PLAYER_TWO_COLOR
