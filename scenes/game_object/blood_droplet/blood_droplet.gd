extends Node2D
class_name BloodDroplet

@export var radius: float = 4.0
@export var color: Color = Color(0.75, 0.05, 0.05)
@export var dry_up_seconds: float = 0.0


func _ready() -> void:
	queue_redraw()
	if dry_up_seconds > 0.0:
		get_tree().create_timer(dry_up_seconds).timeout.connect(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
