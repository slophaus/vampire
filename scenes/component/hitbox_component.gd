extends Area2D
class_name HitboxComponent

var damage = 0
var knockback = 0.0
var penetration := 1
var poison_damage := 0.0
@export var hit_cooldown := 0.0
signal hit_landed(hit_count: int)

var hit_count := 0
var last_hit_times := {}


func can_hit(target: Node) -> bool:
	if hit_cooldown <= 0.0 or target == null:
		return true
	var target_id = target.get_instance_id()
	var now = Time.get_ticks_msec()
	var last_time = last_hit_times.get(target_id, -INF)
	return (now - last_time) >= hit_cooldown * 1000.0


func register_hit(target: Node = null) -> void:
	hit_count += 1
	if hit_cooldown > 0.0 and target != null:
		last_hit_times[target.get_instance_id()] = Time.get_ticks_msec()
	hit_landed.emit(hit_count)
