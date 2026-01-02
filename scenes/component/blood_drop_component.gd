extends Node
class_name BloodDropComponent

@export var health_component: HealthComponent
@export var blood_droplet_scene: PackedScene
@export var droplet_count_range := Vector2i(2, 4)
@export var spawn_radius := 12.0


func _ready() -> void:
	if health_component != null:
		health_component.died.connect(on_died)


func on_died() -> void:
	if blood_droplet_scene == null:
		return
	if not owner is Node2D:
		return

	var spawn_parent: Node = get_tree().get_first_node_in_group("blood_layer")
	if spawn_parent == null:
		spawn_parent = owner.get_parent()
	if spawn_parent == null:
		return

	var min_count = min(droplet_count_range.x, droplet_count_range.y)
	var max_count = max(droplet_count_range.x, droplet_count_range.y)
	var droplet_count = randi_range(min_count, max_count)
	var base_position = (owner as Node2D).global_position

	for index in range(droplet_count):
		var droplet = blood_droplet_scene.instantiate() as Node2D
		if droplet == null:
			continue
		spawn_parent.add_child(droplet)
		var offset = Vector2.RIGHT.rotated(randf() * TAU) * randf() * spawn_radius
		droplet.global_position = base_position + offset
