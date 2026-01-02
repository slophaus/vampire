extends Node2D
class_name BloodDroplet

@export var radius: float = 2.5
@export var color: Color = Color(0.75, 0.05, 0.05)
@export var dry_up_seconds: float = 1.5


func _ready() -> void:
	queue_redraw()
	if dry_up_seconds > 0.0:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, dry_up_seconds).from(1.0)
		tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
