extends Node
class_name ExperienceManager

signal experience_updated(current_experience: float, target_experience: float)
signal level_up(new_level: int)

const TARGET_EXPERIENCE_GROWTH = 2;

var current_experience = 0
var current_level = 1
#var target_experience = 5
var target_experience = 1  # just for debug

func _ready():
	if not GameEvents.experience_vial_collected.is_connected(on_experience_vial_collected):
		GameEvents.experience_vial_collected.connect(on_experience_vial_collected)
	restore_persisted_state()


func increment_experience(number: float):
	current_experience = min(current_experience + number, target_experience)
	experience_updated.emit(current_experience, target_experience)
	if current_experience == target_experience:
		current_level += 1
		current_experience = 0
		target_experience += TARGET_EXPERIENCE_GROWTH
		experience_updated.emit(current_experience, target_experience)
		level_up.emit(current_level)
	_store_persisted_state()


func on_experience_vial_collected(number: float):
	increment_experience(number)


func restore_persisted_state() -> void:
	var persisted_state = GameEvents.get_experience_state()
	if persisted_state.is_empty():
		_store_persisted_state()
		return
	if persisted_state.has("current_experience"):
		current_experience = float(persisted_state["current_experience"])
	if persisted_state.has("target_experience"):
		target_experience = float(persisted_state["target_experience"])
	if persisted_state.has("current_level"):
		current_level = int(persisted_state["current_level"])
	experience_updated.emit(current_experience, target_experience)


func _store_persisted_state() -> void:
	GameEvents.store_experience_state({
		"current_experience": current_experience,
		"target_experience": target_experience,
		"current_level": current_level,
	})
