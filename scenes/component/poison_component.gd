extends Node
class_name PoisonComponent

signal poison_started
signal poison_ended

@export var health_component: HealthComponent
@export var tick_rate := 1.0
@export var damage_per_tick := 1.0
@export var default_duration := 3.0

@onready var tick_timer: Timer = $TickTimer

var poison_time_left := 0.0
var is_poisoned := false


func _ready() -> void:
	if tick_timer != null:
		tick_timer.wait_time = tick_rate
		tick_timer.timeout.connect(_on_tick_timer_timeout)


func _process(delta: float) -> void:
	if not is_poisoned:
		return
	poison_time_left = max(poison_time_left - delta, 0.0)
	if poison_time_left <= 0.0:
		_stop_poison()


func apply_poison(duration: float = 0.0) -> void:
	var resolved_duration = duration if duration > 0.0 else default_duration
	if resolved_duration <= 0.0:
		return
	poison_time_left = max(poison_time_left, resolved_duration)
	if not is_poisoned:
		is_poisoned = true
		poison_started.emit()
		if tick_timer != null:
			tick_timer.start()


func _on_tick_timer_timeout() -> void:
	if health_component == null or not is_poisoned:
		return
	health_component.damage(damage_per_tick, Color(0.3, 1, 0.3))
	if tick_timer != null:
		tick_timer.start()


func _stop_poison() -> void:
	if not is_poisoned:
		return
	is_poisoned = false
	poison_ended.emit()
	if tick_timer != null:
		tick_timer.stop()
