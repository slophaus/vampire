extends Node
class_name HealthComponent

signal died
signal health_changed

@export var max_health: float = 10
@export var free_owner_on_death := true
var current_health: float
var last_damage_color: Color = Color(1, 0.3, 0.3)


func _ready():
	current_health = max_health


func damage(damage_amount: float, damage_color: Color = Color(1, 0.3, 0.3)):
	# clamping
	var resolved_damage = ceil(damage_amount)
	current_health = max(current_health - resolved_damage, 0)
	last_damage_color = damage_color
	health_changed.emit()
	Callable(check_death).call_deferred()

func heal(heal_amount: float):
	current_health = min(current_health + heal_amount, max_health)
	health_changed.emit()


func get_health_percent() -> float:
	if max_health <= 0:
		return 0
	return min(current_health / max_health, 1)


func check_death():
	if current_health == 0:
		died.emit()
		if free_owner_on_death && owner != null:
			owner.queue_free()
