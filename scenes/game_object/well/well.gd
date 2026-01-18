extends Area2D
class_name Well

@export var experience_vial_scene: PackedScene = preload("res://scenes/game_object/experience_vial/experience_vial.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
@export_range(0.05, 10.0, 0.05) var emission_interval := 1.0
@export_range(1, 999, 1) var capacity := 5
@export_range(0.0, 512.0, 1.0) var experience_vial_drop_radius := 32.0

@onready var emission_timer: Timer = $EmissionTimer

var _started := false
var _emitted_count := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	emission_timer.timeout.connect(_on_emission_timeout)
	emission_timer.wait_time = emission_interval
	emission_timer.stop()


func _on_body_entered(body: Node) -> void:
	if _started:
		return
	if body == null or not body.is_in_group("player"):
		return
	_started = true
	_emit_vial()
	if _emitted_count < capacity:
		emission_timer.start(emission_interval)
	else:
		_explode_and_despawn()


func _on_emission_timeout() -> void:
	_emit_vial()
	if _emitted_count >= capacity:
		emission_timer.stop()
		_explode_and_despawn()


func _emit_vial() -> void:
	if _emitted_count >= capacity:
		return
	if experience_vial_scene == null:
		return
	var vial_instance = experience_vial_scene.instantiate() as Node2D
	if vial_instance == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var vials_layer = tree.get_first_node_in_group("vials_layer")
	if vials_layer == null:
		vials_layer = tree.current_scene
	if vials_layer == null:
		return
	vials_layer.add_child(vial_instance)
	var base_name = NodeNameUtils.get_base_name_from_scene(experience_vial_scene.resource_path, "experience_vial")
	NodeNameUtils.assign_unique_name(vial_instance, vials_layer, base_name)
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * sqrt(randf()) * experience_vial_drop_radius
	vial_instance.global_position = global_position + offset
	vial_instance.z_index = z_index + 1
	_emitted_count += 1


func _explode_and_despawn() -> void:
	if explosion_scene != null:
		var explosion_instance = explosion_scene.instantiate() as GPUParticles2D
		if explosion_instance != null:
			explosion_instance.global_position = global_position
			explosion_instance.emitting = true
			explosion_instance.finished.connect(explosion_instance.queue_free)
			var tree := get_tree()
			if tree == null:
				return
			var effects_layer = tree.get_first_node_in_group("effects_layer")
			var spawn_parent = effects_layer if effects_layer != null else tree.current_scene
			if spawn_parent == null:
				return
			spawn_parent.add_child(explosion_instance)
	queue_free()
