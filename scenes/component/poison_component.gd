extends Node
class_name PoisonComponent

signal poison_started
signal poison_ended

@export var health_component: HealthComponent
@export var tick_rate := 1.0
@export var poison_damage_rate := 1.0

@onready var tick_timer: Timer = $TickTimer

var poison_level := 0.0
var poison_potency := 1.0
var is_poisoned := false


func _ready() -> void:
	if tick_timer != null:
		tick_timer.wait_time = tick_rate
		tick_timer.timeout.connect(_on_tick_timer_timeout)


func apply_poison(poison_damage: float = 0.0, potency: float = 1.0) -> void:
	if poison_damage <= 0.0:
		return
	poison_level = max(poison_level, poison_damage)
	if potency > 0.0:
		poison_potency = max(poison_potency, potency)
	if not is_poisoned:
		is_poisoned = true
		poison_started.emit()
		if tick_timer != null:
			tick_timer.start()


func clear_poison() -> void:
	_stop_poison()


func _on_tick_timer_timeout() -> void:
	if health_component == null or not is_poisoned:
		return
	var damage_per_tick := poison_damage_rate * max(poison_potency, 1.0)
	if damage_per_tick <= 0.0:
		_stop_poison()
		return
	var damage = min(poison_level, damage_per_tick)
	if damage > 0.0:
		health_component.damage(damage, Color(0.3, 1, 0.3))
	poison_level = max(poison_level - damage, 0.0)
	if poison_level <= 0.0:
		_stop_poison()
	elif tick_timer != null:
		tick_timer.start()


func _stop_poison() -> void:
	if not is_poisoned:
		return
	is_poisoned = false
	poison_level = 0.0
	poison_potency = 1.0
	poison_ended.emit()
	if tick_timer != null:
		tick_timer.stop()
