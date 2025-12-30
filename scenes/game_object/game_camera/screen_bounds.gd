extends Node2D

@onready var left_shape: WorldBoundaryShape2D = $LeftBoundary/CollisionShape2D.shape
@onready var right_shape: WorldBoundaryShape2D = $RightBoundary/CollisionShape2D.shape
@onready var top_shape: WorldBoundaryShape2D = $TopBoundary/CollisionShape2D.shape
@onready var bottom_shape: WorldBoundaryShape2D = $BottomBoundary/CollisionShape2D.shape


func _ready() -> void:
	update_bounds()
	get_viewport().size_changed.connect(update_bounds)


func update_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	var half_width := viewport_size.x * 0.5
	var half_height := viewport_size.y * 0.5

	left_shape.normal = Vector2(1, 0)
	left_shape.distance = -half_width

	right_shape.normal = Vector2(-1, 0)
	right_shape.distance = -half_width

	top_shape.normal = Vector2(0, 1)
	top_shape.distance = -half_height

	bottom_shape.normal = Vector2(0, -1)
	bottom_shape.distance = -half_height
