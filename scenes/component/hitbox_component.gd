extends Area2D
class_name HitboxComponent

var damage = 0
var knockback = 0.0
var penetration := 1
signal hit_landed(hit_count: int)

var hit_count := 0


func register_hit() -> void:
	hit_count += 1
	hit_landed.emit(hit_count)
