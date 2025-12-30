extends Node2D

@export var radius := 4.0
@export var color := Color(0.95, 0.2, 0.2, 0.85)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
