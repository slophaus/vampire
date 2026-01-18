extends Node
class_name VialDropComponent

@export_range(0, 1) var drop_rate: float = 1.0
@export_range(0, 1) var health_drop_chance: float = 0.05
@export var health_component: HealthComponent
@export var vial_scene: PackedScene
@export var health_vial_scene: PackedScene


func _ready():
	health_component.died.connect(on_died)


func on_died():
	if randf() > drop_rate:
		return

	var selected_vial_scene = vial_scene
	var drop_chance = health_drop_chance
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var player_health = player.get_node_or_null("HealthComponent") as HealthComponent
		if player_health != null:
			var near_death_threshold = player.get("near_death_hit_points")
			if typeof(near_death_threshold) in [TYPE_FLOAT, TYPE_INT]:
				if player_health.current_health <= float(near_death_threshold):
					drop_chance = min(drop_chance * 3.0, 1.0)
	if health_vial_scene != null and randf() < drop_chance:
		selected_vial_scene = health_vial_scene

	if selected_vial_scene == null:
		return
	
	if not owner is Node2D:
		return

	var spawn_position = (owner as Node2D).global_position
	var vial_instance = selected_vial_scene.instantiate() as Node2D
	var vials_layer = get_tree().get_first_node_in_group("vials_layer")
	if vials_layer == null:
		return
	vials_layer.add_child(vial_instance)
	var base_name = NodeNameUtils.get_base_name_from_scene(selected_vial_scene.resource_path, "vial")
	NodeNameUtils.assign_unique_name(vial_instance, vials_layer, base_name)
	vial_instance.global_position = spawn_position
