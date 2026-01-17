extends Node2D
class_name AxeAbility

const MAX_RADIUS := 100
const MAX_ROTATION := 2
const BASE_PENETRATION := 3

@onready var hitbox_component := $HitboxComponent


var base_rotation: Vector2
var base_rotation_angle := 0.0
var source_player: Node2D
var hit_count := 0
@export var spiral_duration := 2.0


func _ready():
	base_rotation = Vector2.RIGHT.rotated(base_rotation_angle)
	if hitbox_component.penetration <= 0:
		hitbox_component.penetration = BASE_PENETRATION
	hitbox_component.hit_landed.connect(on_hit_landed)
	
	var tween = create_tween()
	tween.tween_method(tween_method, 0.0, float(MAX_ROTATION), spiral_duration)
	tween.tween_callback(queue_free)


func set_base_rotation_angle(angle: float) -> void:
	base_rotation_angle = angle


func tween_method(rotations: float):
	var percent = rotations / MAX_ROTATION
	var current_radius = percent * MAX_RADIUS
	var current_direction = base_rotation.rotated(rotations * TAU)
	
	var player = source_player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	global_position = player.global_position + (current_direction * current_radius)


func on_hit_landed(current_hits: int) -> void:
	hit_count = current_hits
	if hit_count >= hitbox_component.penetration:
		queue_free()
