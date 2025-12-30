extends Node2D

@export var radius := 4.0
@export var color := Color(1.0, 0.2, 0.2, 0.9)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
