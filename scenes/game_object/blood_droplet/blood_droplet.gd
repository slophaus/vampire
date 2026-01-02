extends Node2D
class_name BloodDroplet

@export var min_radius: float = 2.0
@export var max_radius: float = 3.5
@export var min_color: Color = Color(0.7, 0.02, 0.02)
@export var max_color: Color = Color(0.85, 0.1, 0.1)
@export var dry_up_seconds: float = 1.5

var radius: float
var color: Color


func _ready() -> void:
	var radius_min = min(min_radius, max_radius)
	var radius_max = max(min_radius, max_radius)
	radius = randf_range(radius_min, radius_max)
	color = min_color.lerp(max_color, randf())
	queue_redraw()
	if dry_up_seconds > 0.0:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, dry_up_seconds).from(1.0)
		tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
